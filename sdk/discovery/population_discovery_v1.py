"""Contained GPU population with full live checks and compact retained records."""
import argparse
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
import sys
import time
from unittest.mock import patch

import mujoco
import numpy as np

from population_discovery_task_v1 import ROOT, HERE, CONTRACT, FLAGS, declaration, plans, LiveBlock, summarize, require, sha
from gpu_measurement_probe import write_new
from gpu_batch_execution import SubstepHistory, integration_sequence, read_snapshot, trace_rows, preflight as batch_preflight
from gpu_repertoire_v2 import initial_arrays
from motor_effectiveness_task import condition_inputs, condition_robot_view, validate_native_profile, validate_gpu_profile
from portable_search_control import bridge
from repertoire_control import RepertoireController
from gpu_portable_search import bind_contact_compatibility_view, verify_view, observation_native
from audit_gpu_portable_search import validate_observation
from audit_gpu_motor_effectiveness import validate_proposal
from actuation_measurement import named_force_samples


def preflight(core_path, baseline_path):
    batch_preflight(core_path, baseline_path)
    c = declaration()
    with patch.object(mujoco, "MjModel", side_effect=AssertionError("Preflight world")), \
            patch.object(mujoco, "MjData", side_effect=AssertionError("Preflight data")):
        core = bridge.LocomotionCore(core_path)
        for condition in c["conditions"]:
            cid = condition["condition_id"]
            compiled, xml, spec = condition_inputs(core_path, c, cid)
            require(hashlib.sha256(xml.encode()).hexdigest() == c["condition_model_sha256"][cid], "Population model pin")
            for plan in plans(c, "canaries") + plans(c, "population"):
                if plan["condition_id"] != cid:
                    continue
                batch = RepertoireController(core, compiled, dict(c, seed=plan["seed"]), plan["candidate_indices"])
                batch.close()
                positions, velocities = initial_arrays(spec, plan)
                require(positions.shape == (plan["nworld"], 15) and velocities.shape == (plan["nworld"], 14)
                    and np.all(np.isfinite(positions)) and np.all(np.isfinite(velocities)), "Population initial arrays")
    return dict(ok=True, world_build_count=0, solver_steps=0, planned_population_worlds=256,
        planned_canary_worlds=16, calibration_worlds=0, evaluation_worlds=0,
        native_reads_reduced=False, physical_acceptance_authority=False)


def run(folder, permit, core_path, baseline_path, phase):
    sys.path.insert(0, str(ROOT / "sdk/conformance"))
    import r10v_windows_job as jobs
    require(permit.is_file() and jobs.current_in_job(), "Owned contained execution required")
    c = declaration()
    owner = json.loads((folder.parent / "declaration.json").read_text(encoding="utf-8"))
    gate = json.loads((folder.parent / "gate-receipt.json").read_text(encoding="utf-8"))
    consumed = json.loads((folder.parent / "consumed.json").read_text(encoding="utf-8"))
    require(owner["contract"] == c and gate["ok"] is True and
        consumed["gate_receipt_sha256"] == sha(folder.parent / "gate-receipt.json") and
        consumed["contract_sha256"] == sha(CONTRACT), "Prospective population gate binding")
    if phase == "population":
        canaries = json.loads((folder.parent / "canary-audit.json").read_text(encoding="utf-8"))
        require(canaries["ok"] is True and canaries["phase"] == "canaries"
            and canaries["compact_pairs_match"] is True and canaries["full_canaries_replayed"] == 2,
            "Population requires completed full/compact canaries")
    preflight(core_path, baseline_path)
    import warp as wp
    import mujoco_warp as mjw
    result = dict(ok=False, synthetic=False, phase=phase, ledger_scope=c["ledger_scope"],
        trials=[], constructed_gpu_worlds=0, cpu_readback_views=0, stepped_cpu_worlds=0,
        **{key: False for key in FLAGS})
    started, stage, batch = time.perf_counter(), "runtime", None
    try:
        tick = time.perf_counter()
        wp.config.kernel_cache_dir = str(folder / "warp-cache")
        wp.init()
        device = wp.get_device(c["device"])
        require(device.is_cuda, "CUDA required")
        wp.set_device(device)
        result["runtime_setup_s"] = time.perf_counter() - tick
        result["device"] = dict(name=device.name, architecture=device.arch)
        core = bridge.LocomotionCore(core_path)
        for condition in c["conditions"]:
            cid = condition["condition_id"]
            directory = folder / cid
            directory.mkdir()
            compiled, xml, spec = condition_inputs(core_path, c, cid)
            write_new(directory / "compiled.json", compiled)
            write_new(directory / "inputs.json", spec)
            with (directory / "model.xml").open("x", encoding="utf-8", newline="\n") as stream:
                stream.write(xml)
            model = mujoco.MjModel.from_xml_string(xml)
            profile = validate_native_profile(model, spec)
            initial = mujoco.MjData(model)
            require(model.qpos0.tolist() == spec["initial_qpos"], "Native initial pose")
            for i, (motor, joint) in enumerate(zip(spec["ordered_actuators"], spec["ordered_joints"], strict=True)):
                named_force_samples(model, initial, motor, joint)
                require([int(model.sensor_adr[model.sensor(motor + "_force").id]),
                    int(model.sensor_adr[model.sensor(joint + "_actuator_force").id])] == [2*i, 2*i + 1], "Named sensor order")
            wm = mjw.put_model(model)
            metadata = dict(model_sha256=sha(directory / "model.xml"), inputs_sha256=sha(directory / "inputs.json"),
                compiled_sha256=sha(directory / "compiled.json"), condition_id=cid, actuator_profile=profile,
                gpu_actuator_profile=validate_gpu_profile(wm, spec),
                ordered_bodies=[model.body(i).name for i in range(model.nbody)], body_rootid=model.body_rootid.tolist(),
                force_ranges=model.actuator_forcerange.tolist(), observation_stage="prepared_before_control",
                force_stage="completed_step_before_next_prepare")
            write_new(directory / "native-model.json", metadata)
            with ExitStack() as trap:
                for name in ["mj_step", "mj_step1", "mj_step2", "mj_forward"]:
                    trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("CPU dynamics in GPU discovery")))
                for plan in plans(c, phase):
                    if plan["condition_id"] != cid:
                        continue
                    stage = plan["trial_id"]
                    trial_dir = directory / stage
                    trial_dir.mkdir()
                    write_new(trial_dir / "plan.json", plan)
                    nworld = plan["nworld"]
                    cfg = dict(c, naconmax=nworld*c["naconmax_per_world"], outer_steps=plan["outer_steps"], seed=plan["seed"])
                    tick = time.perf_counter()
                    wd = mjw.put_data(model, initial, nworld=nworld, naconmax=cfg["naconmax"],
                        njmax=c["njmax"], njmax_nnz=c["njmax_nnz"], nvmax=c["nvmax"])
                    result["constructed_gpu_worlds"] += nworld
                    write_new(trial_dir / "worlds-opened.json", dict(native_gpu_worlds=nworld, trial_id=stage))
                    views = [mujoco.MjData(model) for _ in range(nworld)]
                    result["cpu_readback_views"] += nworld
                    robots = [condition_robot_view(core, compiled, model, view, spec) for view in views]
                    batch = RepertoireController(core, compiled, cfg, plan["candidate_indices"])
                    positions, velocities = initial_arrays(spec, plan)
                    wp.copy(wd.qpos, wp.array(positions, dtype=wp.float32, device=device))
                    wp.copy(wd.qvel, wp.array(velocities, dtype=wp.float32, device=device))
                    trial = dict(plan, setup_s=time.perf_counter()-tick, graph_capture_s=0.,
                                 outer_rows=0, internal_rows=0, completed=False)
                    result["trials"].append(trial)
                    tick = time.perf_counter()
                    history = SubstepHistory(wp, wd)
                    with wp.ScopedCapture(device=device) as prepare:
                        mjw.step1(wm, wd)
                    with wp.ScopedCapture(device=device) as integrate:
                        integration_sequence(mjw, wm, wd, history)
                    prepare_graph, integrate_graph = prepare.graph, integrate.graph
                    wp.synchronize_device(device)
                    require(np.array_equal(wd.qpos.numpy(), positions) and np.array_equal(wd.qvel.numpy(), velocities)
                        and not any(wd.time.numpy()), "Graph capture mutated fresh world")
                    trial["graph_capture_s"] = time.perf_counter()-tick
                    validator = LiveBlock(cfg, plan, spec)
                    previous = [[0.]*8 for _ in range(nworld)]
                    names = ["compact", "timing"] + (["controller", "trace"] if plan["capture_mode"] == "full" else [])
                    with ExitStack() as outputs:
                        streams = {name: outputs.enter_context((trial_dir / (name + ".jsonl")).open("x", encoding="utf-8", newline="\n")) for name in names}
                        def append(name, row):
                            streams[name].write(json.dumps(row, allow_nan=False, separators=(",", ":")) + "\n")
                            require(streams[name].tell() <= c["maximum_trace_bytes_per_trial"], "Population stream byte budget")
                        for outer in range(plan["outer_steps"]):
                            stage = plan["trial_id"] + f"_outer_{outer}"
                            if outer % 120 == 0:
                                print(json.dumps(dict(trial=plan["trial_id"], outer=outer, worlds=nworld)), flush=True)
                            whole = time.perf_counter()
                            timing = dict(outer_step=outer, measured=True)
                            tick = time.perf_counter()
                            wp.capture_launch(prepare_graph)
                            wp.synchronize_device(device)
                            timing["prepare_s"] = time.perf_counter()-tick
                            tick = time.perf_counter()
                            snapshot = read_snapshot(wd, cfg, nworld, observations=True)
                            observations, copies = [], []
                            for cell, (view, robot) in enumerate(zip(views, robots, strict=True)):
                                mjw.get_data_into(view, model, wd, cell)
                                copies.append(bind_contact_compatibility_view(view, snapshot["contacts"][cell]))
                                verify_view(view, snapshot, cell, snapshot["contacts"][cell])
                                state = robot.state_frame(outer, bridge._mujoco_to_canonical(spec["initial_qpos"][:3]))
                                stability = robot.stability_state(outer)
                                observations.append((state, stability, robot.endpoint_kinematics(stability)))
                            timing["observation_readback_s"] = time.perf_counter()-tick
                            tick = time.perf_counter()
                            rows = batch.step(observations)
                            timing["portable_control_s"] = time.perf_counter()-tick
                            tick = time.perf_counter()
                            for cell, row in enumerate(rows):
                                row.update(backend="gpu", cell=cell, outer_step=outer,
                                    native_observation=observation_native(views[cell], snapshot["contacts"][cell]))
                                row["native_observation"]["contact_compatibility_copy"] = copies[cell]
                                validate_observation(row, metadata, compiled)
                                validate_proposal(row, cfg, plan["candidate_indices"][cell], previous[cell])
                                previous[cell] = [r["applied_correction_rad_s"] for r in row["resolution"]["ordered_commands"]]
                                if "controller" in streams:
                                    append("controller", row)
                                trial["outer_rows"] += 1
                            targets = np.asarray([row["native_targets"] for row in rows], np.float32)
                            wp.copy(wd.ctrl, wp.array(targets, dtype=wp.float32, device=device))
                            wp.synchronize_device(device)
                            timing["controller_capture_and_control_transfer_s"] = time.perf_counter()-tick
                            tick = time.perf_counter()
                            wp.capture_launch(integrate_graph)
                            wp.synchronize_device(device)
                            timing["integration_and_device_history_s"] = time.perf_counter()-tick
                            tick = time.perf_counter()
                            snapshots = history.read(cfg, nworld)
                            raw = []
                            for sub, snap in enumerate(snapshots):
                                require(np.array_equal(snap["ctrl"], targets), "Held GPU control changed")
                                raw.extend(trace_rows(snap, cfg, spec, outer, sub, nworld))
                            compact = validator.reduce(rows, raw)
                            for row in compact:
                                append("compact", row)
                            if "trace" in streams:
                                for row in raw:
                                    append("trace", row)
                            trial["internal_rows"] += len(raw)
                            for name, stream in streams.items():
                                if name != "timing":
                                    stream.flush()
                            timing["internal_readback_and_capture_s"] = time.perf_counter()-tick
                            timing["outer_total_s"] = time.perf_counter()-whole
                            append("timing", timing)
                    batch.close()
                    batch = None
                    from audit_gpu_batch_execution import read_jsonl
                    trial.update(completed=True, hashes={name: sha(trial_dir / (name + ".jsonl")) for name in names},
                        stream_bytes={name: (trial_dir / (name + ".jsonl")).stat().st_size for name in names},
                        episodes=summarize(read_jsonl(trial_dir / "compact.jsonl"), cfg, plan, spec))
                    write_new(trial_dir / "result.json", trial)
                    print(json.dumps(dict(trial=plan["trial_id"], complete=True,
                        eligible=sum(e["eligible"] for e in trial["episodes"]), total=nworld)), flush=True)
                    prepare_graph = integrate_graph = history = None
        result.update(ok=True, status="complete_development_population_phase")
    except BaseException as exc:
        result.update(error=f"{type(exc).__name__}: {exc}", failed_stage=stage, status="invalid_or_incomplete_phase")
    finally:
        if batch is not None:
            batch.close()
        result.update(total_wall_s=time.perf_counter()-started, controller_sessions_closed=True)
        write_new(folder / "worker-result.json", result)
    require(result["ok"], result.get("error", "Population worker failed"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--phase", choices=["canaries", "population"])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--permit", type=Path)
    args = parser.parse_args()
    if args.check_only:
        print(json.dumps(preflight(args.core, args.baseline_core)))
    elif args.output is None or args.permit is None or args.phase is None:
        parser.error("Use the contained owner")
    else:
        run(args.output, args.permit, args.core, args.baseline_core, args.phase)
