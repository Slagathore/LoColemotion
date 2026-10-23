"""Owned full-capture motor-effectiveness worlds; distinct development lineage."""
import argparse
from contextlib import ExitStack
import hashlib
import json
import math
from pathlib import Path
import sys
import time
from unittest.mock import patch
import mujoco
import numpy as np

from gpu_quadruped_model import ROOT, FLAGS, sha
from gpu_measurement_probe import write_new
from gpu_portable_search import bind_contact_compatibility_view, verify_view, observation_native
from portable_search_control import bridge
from repertoire_control import RepertoireController, ScalarRepertoireController
from gpu_batch_execution import SubstepHistory, integration_sequence, read_snapshot, trace_rows, preflight as execution_preflight
sys.path.insert(0, str(ROOT / "sdk"))
from adaptation_provider.retrieval import flat_v2 as learner

from motor_effectiveness_task import CONTRACT, declaration, trial_plan, condition_inputs, condition_robot_view, validate_native_profile, validate_gpu_profile, select_profiles

def initial_arrays(spec, plan):
    positions = np.asarray([spec["initial_qpos"]] * plan["nworld"], np.float32)
    half = plan["initial_native_roll_rad"] / 2
    positions[:, 3:7] = [math.cos(half), math.sin(half), 0., 0.]
    velocities = np.zeros((plan["nworld"], 14), np.float32)
    velocities[:, 1] = plan["initial_native_lateral_velocity_m_s"]
    return positions, velocities


def preflight(core_path, baseline_path):
    execution_preflight(core_path, baseline_path)
    c = declaration()
    with patch.object(mujoco, "MjModel", side_effect=AssertionError("Preflight world")), \
            patch.object(mujoco, "MjData", side_effect=AssertionError("Preflight data")):
        core = bridge.LocomotionCore(core_path)
        for condition in c["conditions"]:
            cid = condition["condition_id"]
            compiled, xml, spec = condition_inputs(core_path, c, cid)
            learner.require(hashlib.sha256(xml.encode()).hexdigest() == c["condition_model_sha256"][cid], "Condition XML pin")
            for p in [p for p in trial_plan(c, "discovery") if p["condition_id"] == cid]:
                batch = RepertoireController(core, compiled, dict(c, seed=p["seed"]), p["candidate_indices"])
                batch.close()
                qpos, qvel = initial_arrays(spec, p)
                learner.require(qpos.shape == (9, 15) and qvel.shape == (9, 14)
                    and np.all(np.isfinite(qpos)) and np.all(np.isfinite(qvel)), "Initial arrays")
    return dict(ok=True, world_build_count=0, solver_steps=0, planned_gpu_worlds=120,
        discovery_worlds=90, confirmation_worlds=30, planned_controller_rows=57600,
        planned_internal_rows=288000, evaluation_worlds=0)


def load_selection(path, c):
    learner.require(path is not None and path.is_file(), "Confirmation requires retained selection")
    record = json.loads(path.read_text())
    audit_path = path.parent / "discovery-audit.json"
    audit = json.loads(audit_path.read_text())
    learner.require(set(record) == {"selection", "discovery_audit_sha256"}
        and record["discovery_audit_sha256"] == sha(audit_path)
        and audit["synthetic"] is False and record["selection"] == select_profiles(audit, c), "Selection replay/binding")
    return record["selection"]


def run(folder, permit, core_path, baseline_path, phase, condition_id, selection_path):
    sys.path.insert(0, str(ROOT / "sdk/conformance"))
    import r10v_windows_job as jobs
    if not permit.is_file() or not jobs.current_in_job():
        raise ValueError("Owned contained execution required")
    preflight(core_path, baseline_path)
    import warp as wp
    import mujoco_warp as mjw
    from actuation_measurement import named_force_samples
    from audit_gpu_portable_search import validate_observation
    c = declaration()
    selection = load_selection(selection_path, c) if phase == "confirmation" else None
    learner.require(phase == "confirmation" or selection_path is None, "Discovery cannot consume a selection")
    plans = [p for p in trial_plan(c, phase, selection) if p["condition_id"] == condition_id]
    learner.require(len(plans) == 2, "Condition trial population")
    c = dict(c, training_data_authority=phase == "discovery")
    compiled, xml, spec = condition_inputs(core_path, c, condition_id)
    learner.require(hashlib.sha256(xml.encode()).hexdigest() == c["condition_model_sha256"][condition_id], "Condition XML pin")
    for name, value in [("compiled", compiled), ("inputs", spec)]:
        write_new(folder / (name + ".json"), value)
    (folder / "model.xml").write_text(xml, encoding="utf-8", newline="\n")
    result = dict(ok=False, synthetic=False, ledger_scope=c["ledger_scope"], phase=phase, condition_id=condition_id, trials=[],
                  constructed_gpu_worlds=0, stepped_cpu_worlds=0, cpu_readback_views=0,
                  **{key: c[key] for key in FLAGS})
    started = time.perf_counter()
    stage = "model"
    batch = None
    scalars = []
    try:
        model = mujoco.MjModel.from_xml_string(xml)
        native_profile = validate_native_profile(model, spec)
        initial = mujoco.MjData(model)
        if ((model.nq, model.nv, model.nu, model.nbody, model.ngeom, model.nsensordata) != (15, 14, 8, 10, 10, 16)
                or model.qpos0.tolist() != spec["initial_qpos"]):
            raise ValueError("Native model identity")
        for i, (motor, joint) in enumerate(zip(spec["ordered_actuators"], spec["ordered_joints"], strict=True)):
            named_force_samples(model, initial, motor, joint)
            if ([int(model.sensor_adr[model.sensor(motor + "_force").id]),
                 int(model.sensor_adr[model.sensor(joint + "_actuator_force").id])] != [2 * i, 2 * i + 1]):
                raise ValueError("Named force sampling order")
        metadata = dict(model_sha256=sha(folder / "model.xml"), inputs_sha256=sha(folder / "inputs.json"),
            compiled_sha256=sha(folder / "compiled.json"), actuator_profile=native_profile, condition_id=condition_id, ordered_bodies=[model.body(i).name for i in range(model.nbody)],
            body_rootid=model.body_rootid.tolist(), force_ranges=model.actuator_forcerange.tolist(),
            observation_stage="prepared_before_control", force_stage="completed_step_before_next_prepare")
        write_new(folder / "native-model.json", metadata)
        tick = time.perf_counter()
        wp.config.kernel_cache_dir = str(folder.parent.parent / "warp-cache")
        wp.init()
        device = wp.get_device(c["device"])
        if not device.is_cuda:
            raise ValueError("CUDA required")
        wp.set_device(device)
        wm = mjw.put_model(model)
        write_new(folder / "gpu-actuator-profile.json", validate_gpu_profile(wm, spec))
        result["runtime_setup_s"] = time.perf_counter() - tick
        result["device"] = dict(name=device.name, architecture=device.arch)
        core = bridge.LocomotionCore(core_path)
        with ExitStack() as trap:
            for name in ["mj_step", "mj_step1", "mj_step2", "mj_forward"]:
                trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("CPU dynamics during GPU work")))
            for plan in plans:
                stage = plan["trial_id"]
                trial_dir = folder / stage
                trial_dir.mkdir()
                nworld = plan["nworld"]
                cfg = dict(c, naconmax=nworld * c["naconmax_per_world"])
                tick = time.perf_counter()
                # Every trial has fresh native state and explicit host memory.
                wd = mjw.put_data(model, initial, nworld=nworld, naconmax=cfg["naconmax"],
                    njmax=c["njmax"], njmax_nnz=c["njmax_nnz"], nvmax=c["nvmax"])
                result["constructed_gpu_worlds"] += nworld
                views = [mujoco.MjData(model) for _ in range(nworld)]
                result["cpu_readback_views"] += nworld
                group_c = dict(c, seed=plan["seed"])
                robots = [condition_robot_view(core, compiled, model, view, spec) for view in views]
                if plan["arm"] == "batch_graph":
                    batch = RepertoireController(core, compiled, group_c, plan["candidate_indices"])
                else:
                    scalars = [ScalarRepertoireController(core, compiled, group_c, i) for i in plan["candidate_indices"]]
                positions, velocities = initial_arrays(spec, plan)
                wp.copy(wd.qpos, wp.array(positions, dtype=wp.float32, device=device))
                wp.copy(wd.qvel, wp.array(velocities, dtype=wp.float32, device=device))
                trial = dict(plan, setup_s=time.perf_counter() - tick, graph_capture_s=0.,
                             outer_rows=0, internal_rows=0, completed=False)
                result["trials"].append(trial)
                write_new(trial_dir / "plan.json", plan)
                history = None
                prepare_graph = integrate_graph = None
                if batch is not None:
                    tick = time.perf_counter()
                    history = SubstepHistory(wp, wd)
                    # Capturing CUDA operations does not execute a warm-up world.
                    # Cold JIT/capture cost is reported separately, never discarded.
                    with wp.ScopedCapture(device=device) as prepare:
                        mjw.step1(wm, wd)
                    with wp.ScopedCapture(device=device) as integrate:
                        integration_sequence(mjw, wm, wd, history)
                    prepare_graph, integrate_graph = prepare.graph, integrate.graph
                    wp.synchronize_device(device)
                    if (not np.array_equal(wd.qpos.numpy(), positions)
                            or not np.array_equal(wd.qvel.numpy(), velocities) or any(wd.time.numpy())):
                        raise ValueError("Graph capture changed initial world")
                    trial["graph_capture_s"] = time.perf_counter() - tick
                streams = {}
                with ExitStack() as outputs:
                    for name in ["controller", "trace", "timing"]:
                        streams[name] = outputs.enter_context((trial_dir / (name + ".jsonl")).open("x", encoding="utf-8", newline="\n"))
                    def append(name, row):
                        stream = streams[name]
                        stream.write(json.dumps(row, allow_nan=False, separators=(",", ":")) + "\n")
                        if stream.tell() > c["maximum_trace_bytes_per_trial"]:
                            raise ValueError("Declared evidence byte bound")
                    for outer in range(c["outer_steps"]):
                        stage = plan["trial_id"] + f"_outer_{outer}"
                        if outer % 120 == 0:
                            print(json.dumps(dict(trial=plan["trial_id"], outer_step=outer)), flush=True)
                        whole = time.perf_counter()
                        timing = dict(outer_step=outer, measured=outer >= c["warmup_outer_steps"])
                        tick = time.perf_counter()
                        if prepare_graph is None:
                            mjw.step1(wm, wd)
                        else:
                            wp.capture_launch(prepare_graph)
                        wp.synchronize_device(device)
                        timing["prepare_s"] = time.perf_counter() - tick
                        tick = time.perf_counter()
                        snapshot = read_snapshot(wd, cfg, nworld, observations=True)
                        copies = []
                        observations = []
                        for cell, (view, robot) in enumerate(zip(views, robots, strict=True)):
                            mjw.get_data_into(view, model, wd, cell)
                            copies.append(bind_contact_compatibility_view(view, snapshot["contacts"][cell]))
                            verify_view(view, snapshot, cell, snapshot["contacts"][cell])
                            state = robot.state_frame(outer, bridge._mujoco_to_canonical(spec["initial_qpos"][:3]))
                            stability = robot.stability_state(outer)
                            observations.append((state, stability, robot.endpoint_kinematics(stability)))
                        timing["observation_readback_s"] = time.perf_counter() - tick
                        tick = time.perf_counter()
                        rows = batch.step(observations) if batch is not None else [
                            controller.step(*obs) for controller, obs in zip(scalars, observations, strict=True)]
                        timing["portable_control_s"] = time.perf_counter() - tick
                        tick = time.perf_counter()
                        for cell, row in enumerate(rows):
                            row.update(backend="gpu", cell=cell, outer_step=outer,
                                native_observation=observation_native(views[cell], snapshot["contacts"][cell]))
                            row["native_observation"]["contact_compatibility_copy"] = copies[cell]
                            validate_observation(row, metadata, compiled)
                            append("controller", row)
                            trial["outer_rows"] += 1
                        targets = np.asarray([row["native_targets"] for row in rows], np.float32)
                        wp.copy(wd.ctrl, wp.array(targets, dtype=wp.float32, device=device))
                        wp.synchronize_device(device)
                        timing["controller_capture_and_control_transfer_s"] = time.perf_counter() - tick
                        integration_s = capture_s = 0.
                        snapshots = []
                        if integrate_graph is not None:
                            tick = time.perf_counter()
                            wp.capture_launch(integrate_graph)
                            wp.synchronize_device(device)
                            integration_s += time.perf_counter() - tick
                            tick = time.perf_counter()
                            snapshots = history.read(cfg, nworld)
                            capture_s += time.perf_counter() - tick
                        else:
                            for sub in range(5):
                                tick = time.perf_counter()
                                if sub:
                                    mjw.step1(wm, wd)
                                    wp.synchronize_device(device)
                                integration_s += time.perf_counter() - tick
                                tick = time.perf_counter()
                                before_pos, before_vel = wd.qpos.numpy(), wd.qvel.numpy()
                                capture_s += time.perf_counter() - tick
                                tick = time.perf_counter()
                                mjw.step2(wm, wd)
                                wp.synchronize_device(device)
                                integration_s += time.perf_counter() - tick
                                tick = time.perf_counter()
                                snap = read_snapshot(wd, cfg, nworld)
                                snap.update(before_qpos=before_pos, before_qvel=before_vel)
                                snapshots.append(snap)
                                capture_s += time.perf_counter() - tick
                        tick = time.perf_counter()
                        for sub, snap in enumerate(snapshots):
                            if not np.array_equal(snap["ctrl"], targets):
                                raise ValueError("Held solver input changed")
                            for row in trace_rows(snap, cfg, spec, outer, sub, nworld):
                                append("trace", row)
                                trial["internal_rows"] += 1
                        streams["controller"].flush()
                        streams["trace"].flush()
                        capture_s += time.perf_counter() - tick
                        timing["integration_and_device_history_s"] = integration_s
                        timing["internal_readback_and_capture_s"] = capture_s
                        timing["outer_total_s"] = time.perf_counter() - whole
                        append("timing", timing)
                if batch is not None:
                    batch.close()
                    batch = None
                for controller in scalars:
                    controller.close()
                scalars = []
                trial.update(completed=True, hashes={name: sha(trial_dir / (name + ".jsonl"))
                    for name in ["controller", "trace", "timing"]})
                write_new(trial_dir / "result.json", trial)
                print(json.dumps(dict(trial=plan["trial_id"], complete=True, outer_rows=trial["outer_rows"])), flush=True)
                # Release graph references before replacing their data allocation.
                prepare_graph = integrate_graph = history = None
        result.update(ok=True, status="complete_motor_effectiveness_condition")
    except BaseException as exc:
        result.update(error=f"{type(exc).__name__}: {exc}", failed_stage=stage, status="incomplete_or_refused_execution")
    finally:
        if batch is not None:
            batch.close()
        for controller in scalars:
            controller.close()
        result.update(total_wall_s=time.perf_counter() - started, controller_sessions_closed=True)
        write_new(folder / "worker-result.json", result)
    if not result["ok"]:
        raise RuntimeError(result["error"])


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--core", type=Path, required=True)
    p.add_argument("--baseline-core", type=Path, required=True)
    p.add_argument("--check-only", action="store_true")
    p.add_argument("--output", type=Path)
    p.add_argument("--permit", type=Path)
    p.add_argument("--phase", choices=["discovery", "confirmation"])
    p.add_argument("--condition")
    p.add_argument("--selection", type=Path)
    a = p.parse_args()
    if a.check_only:
        print(json.dumps(preflight(a.core, a.baseline_core)))
    elif a.output is None or a.permit is None or a.phase is None or a.condition is None:
        p.error("Use the contained supervisor with a declared phase and condition")
    else:
        run(a.output, a.permit, a.core, a.baseline_core, a.phase, a.condition, a.selection)
