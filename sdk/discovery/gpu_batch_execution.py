"""Full-capture GPU execution comparison; no training or physical acceptance.

The graph records each completed internal step before the next prepare clears
force sensors. Host readback happens only after all five snapshots are retained.
"""
import argparse
from contextlib import ExitStack
import hashlib
import importlib.metadata
import json
import math
from pathlib import Path
import sys
import time
from unittest.mock import patch

import mujoco
import numpy as np

from gpu_measurement_probe import write_new
from gpu_quadruped_model import ROOT, FLAGS, sha, build_inputs, split_contacts
from gpu_quadruped_probe import check_capture
from gpu_portable_search import (
    bind_contact_compatibility_view, verify_view, observation_native,
)
from portable_search_control import Controller, robot_view, bridge, VIEW_FIELDS
from portable_batch_control import BatchController

HERE = Path(__file__).resolve().parent
CONTRACT = HERE / "gpu_batch_execution_v1.json"
ARMS = ["scalar_direct", "batch_graph"]
CAPTURE_FIELDS = ["qpos", "qvel", "ctrl", "sensordata", "time", "nacon", "nefc", "overflow",
                  "contact.worldid", "contact.geom", "contact.dist", "contact.pos", "contact.frame"]


def declaration():
    c = json.loads(CONTRACT.read_text())
    if (c["schema_version"] != "locolemotion_gpu_batch_execution_v1"
            or c["batch_sizes"] != [1, 4, 16] or c["repeats"] != 3
            or c["outer_steps"] != 120 or c["warmup_outer_steps"] != 24
            or c["internal_steps_per_outer"] != 5 or c["arms"] != ARMS
            or c["naconmax_per_world"] != 64 or any(c[k] is not False for k in FLAGS)):
        raise ValueError("GPU batch declaration")
    return c


def trial_plan(c):
    rows = []
    for repeat in range(c["repeats"]):
        for size_index, count in enumerate(c["batch_sizes"]):
            order = ARMS if (repeat + size_index) % 2 == 0 else ARMS[::-1]
            for arm in order:
                rows.append(dict(trial_id=f"r{repeat}_n{count}_{arm}", repeat=repeat,
                                 nworld=count, arm=arm,
                                 candidate_indices=[i % 4 for i in range(count)]))
    return rows


def array_at(data, name):
    value = data
    for part in name.split("."):
        value = getattr(value, part)
    return value


def checked_snapshot(arrays, c, nworld):
    count = int(arrays["nacon"][0])
    nefc = arrays["nefc"]
    overflow = arrays["overflow"]
    if (len(nefc) != nworld or len(overflow) != nworld or any(overflow)
            or any(nefc < 0) or any(nefc > c["njmax"])):
        raise ValueError("GPU constraint capacity before readback")
    contacts = split_contacts(count, arrays["contact.worldid"], arrays["contact.geom"],
        arrays["contact.dist"], arrays["contact.pos"], nworld=nworld, capacity=c["naconmax"])
    frames = arrays["contact.frame"]
    for rows in contacts:
        for row in rows:
            row["frame"] = frames[row["native_index"]].reshape(-1).tolist()
    return dict(arrays, contacts=contacts, batch_contacts=count)


def read_snapshot(data, c, nworld, *, observations=False):
    fields = list(dict.fromkeys(CAPTURE_FIELDS + (VIEW_FIELDS if observations else [])))
    return checked_snapshot({name: array_at(data, name).numpy() for name in fields}, c, nworld)


class SubstepHistory:
    """Preallocated device history, with no host reads during graph capture."""

    def __init__(self, wp, data):
        self.wp = wp
        self.sources = {name: array_at(data, name) for name in CAPTURE_FIELDS}
        self.sources.update(before_qpos=data.qpos, before_qvel=data.qvel)
        self.buffers = {name: wp.empty((5, *source.shape), dtype=source.dtype, device=source.device)
                        for name, source in self.sources.items()}
        # Create aliases before capture; keep them alive as long as the graph.
        self.slots = [{name: buffer[sub] for name, buffer in self.buffers.items()} for sub in range(5)]

    def before(self, sub):
        for name in ("before_qpos", "before_qvel"):
            self.wp.copy(self.slots[sub][name], self.sources[name])

    def after(self, sub):
        for name in CAPTURE_FIELDS:
            self.wp.copy(self.slots[sub][name], self.sources[name])

    def read(self, c, nworld):
        arrays = {name: buffer.numpy() for name, buffer in self.buffers.items()}
        return [checked_snapshot({name: value[sub] for name, value in arrays.items()}, c, nworld)
                for sub in range(5)]


def integration_sequence(mjw, model, data, history):
    """Outer step1 precedes the host decision; each force snapshot precedes step1."""
    for sub in range(5):
        if sub:
            mjw.step1(model, data)
        history.before(sub)
        mjw.step2(model, data)
        history.after(sub)


def preflight(core_path, baseline_path):
    import mujoco_warp as mjw
    import warp as wp
    c = declaration()
    if sha(core_path) != c["core_sha256"] or sha(baseline_path) != c["baseline_core_sha256"]:
        raise ValueError("Prospective runtime binding")
    if {p: importlib.metadata.version(p) for p in c["runtime"]} != c["runtime"]:
        raise ValueError("Pinned runtime changed")
    if any(not callable(getattr(mjw, name, None)) for name in ["step1", "step2", "get_data_into"]):
        raise ValueError("Missing split/readback API")
    if any(not callable(getattr(wp, name, None)) for name in ["ScopedCapture", "capture_launch", "copy", "empty"]):
        raise ValueError("Missing graph/buffer API")
    with patch.object(mujoco, "MjModel", side_effect=AssertionError("World in preflight")), \
            patch.object(mujoco, "MjData", side_effect=AssertionError("Data in preflight")):
        core = bridge.LocomotionCore(core_path)
        compiled, xml, spec = build_inputs(core_path, c)
        if (hashlib.sha256(xml.encode()).hexdigest() != c["model_xml_sha256"]
                or compiled["descriptor_sha256"] != c["descriptor_sha256"]):
            raise ValueError("Compiled identity")
        old_c = dict(c, core_sha256=c["baseline_core_sha256"])
        old_compiled, old_xml, old_spec = build_inputs(baseline_path, old_c)
        if (compiled, xml, spec) != (old_compiled, old_xml, old_spec):
            raise ValueError("Scalar/batch model inputs differ")
        for count in c["batch_sizes"]:
            batch = BatchController(core, compiled, c, [i % 4 for i in range(count)])
            batch.close()
    return dict(ok=True, world_build_count=0, solver_steps=0,
                runtime=c["runtime"], planned_trials=len(trial_plan(c)),
                planned_gpu_worlds=sum(r["nworld"] for r in trial_plan(c)))


def trace_rows(snapshot, c, spec, outer, sub, nworld):
    """Produce the same full internal evidence for both execution routes."""
    caps = np.asarray(spec["force_ranges"], np.float32).tolist()
    for cell in range(nworld):
        sensors = snapshot["sensordata"][cell]
        forces = list(map(float, sensors[::2]))
        row = dict(backend="gpu", cell=cell, step=5 * outer + sub + 1,
            before_qpos=snapshot["before_qpos"][cell].tolist(), before_qvel=snapshot["before_qvel"][cell].tolist(),
            qpos=snapshot["qpos"][cell].tolist(), qvel=snapshot["qvel"][cell].tolist(),
            ctrl=snapshot["ctrl"][cell].tolist(), actuator_force_nm=forces,
            joint_force_nm=list(map(float, sensors[1::2])),
            on_force_cap=[f <= lo or f >= hi for f, (lo, hi) in zip(forces, caps, strict=True)],
            time_s=float(snapshot["time"][cell]), contacts=snapshot["contacts"][cell],
            batch_contacts=int(snapshot["batch_contacts"]), nefc=int(snapshot["nefc"][cell]),
            overflow=int(snapshot["overflow"][cell]), warnings=[])
        check_capture(row, c, caps)
        yield row


def run(folder, permit, core_path, baseline_path):
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
    compiled, xml, spec = build_inputs(core_path, c)
    spec["initial_lateral_velocities"] = [spec["initial_lateral_velocities"][0]] * 4
    for name, value in [("compiled", compiled), ("inputs", spec)]:
        write_new(folder / (name + ".json"), value)
    (folder / "model.xml").write_text(xml, encoding="utf-8", newline="\n")
    result = dict(ok=False, synthetic=False, ledger_scope=c["ledger_scope"], trials=[],
                  constructed_gpu_worlds=0, stepped_cpu_worlds=0, cpu_readback_views=0,
                  **{key: False for key in FLAGS})
    started = time.perf_counter()
    stage = "model"
    batch = None
    scalars = []
    try:
        model = mujoco.MjModel.from_xml_string(xml)
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
            compiled_sha256=sha(folder / "compiled.json"), ordered_bodies=[model.body(i).name for i in range(model.nbody)],
            body_rootid=model.body_rootid.tolist(), force_ranges=model.actuator_forcerange.tolist(),
            observation_stage="prepared_before_control", force_stage="completed_step_before_next_prepare")
        write_new(folder / "native-model.json", metadata)
        tick = time.perf_counter()
        wp.config.kernel_cache_dir = str(folder / "warp-cache")
        wp.init()
        device = wp.get_device(c["device"])
        if not device.is_cuda:
            raise ValueError("CUDA required")
        wp.set_device(device)
        wm = mjw.put_model(model)
        result["runtime_setup_s"] = time.perf_counter() - tick
        result["device"] = dict(name=device.name, architecture=device.arch)
        cores = {"batch_graph": bridge.LocomotionCore(core_path), "scalar_direct": bridge.LocomotionCore(baseline_path)}
        with ExitStack() as trap:
            for name in ["mj_step", "mj_step1", "mj_step2", "mj_forward"]:
                trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("CPU dynamics during GPU work")))
            for plan in trial_plan(c):
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
                core = cores[plan["arm"]]
                robots = [robot_view(core, compiled, model, view) for view in views]
                if plan["arm"] == "batch_graph":
                    batch = BatchController(core, compiled, c, plan["candidate_indices"])
                else:
                    scalars = [Controller(core, compiled, c, i) for i in plan["candidate_indices"]]
                velocities = np.zeros((nworld, 14), np.float32)
                velocities[:, 1] = spec["initial_lateral_velocities"][0]
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
                    if (not np.array_equal(wd.qpos.numpy(), np.asarray([spec["initial_qpos"]] * nworld, np.float32))
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
        result.update(ok=True, status="complete_full_capture_execution_comparison")
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
    a = p.parse_args()
    if a.check_only:
        print(json.dumps(preflight(a.core, a.baseline_core)))
    elif a.output is None or a.permit is None:
        p.error("Use the contained supervisor")
    else:
        run(a.output, a.permit, a.core, a.baseline_core)
