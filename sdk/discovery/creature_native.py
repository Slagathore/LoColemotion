"""Shared full-capture mixed-creature GPU execution and independent scalar reader."""
import argparse
from contextlib import ExitStack
import copy
import importlib.metadata
import json
import math
from pathlib import Path
import sys
import time
from unittest.mock import patch

import mujoco
import numpy as np

from creature_batch import CreatureBatch, CreatureController, bridge, require, identifier
from creature_native_model import (pack_models, model_snapshot, verify_transport, robot_view,
                                   native_metadata, validate_model_evidence)
from gpu_quadruped_model import ROOT, FLAGS, sha, f32
from gpu_batch_execution import SubstepHistory, integration_sequence, read_snapshot, trace_rows
from gpu_portable_search import bind_contact_compatibility_view, verify_view, observation_native
from gpu_measurement_probe import write_new
from audit_gpu_portable_search import validate_observation
from audit_gpu_batch_execution import same_bits
from actuation_measurement import named_force_samples

HERE = Path(__file__).resolve().parent
MODEL_SOURCES = ["creature_batch.py", "creature_native_model.py", "creature_native.py",
                 "run_creature_native.py", "test_creature_batch.py", "test_creature_native.py",
                 "gpu_batch_execution.py"]
GATES = [
    ("measurement", "test_actuation_measurement", 7),
    ("quadruped", "test_gpu_quadruped_probe", 10),
    ("portable", "test_portable_search", 11),
    ("host-batch", "test_portable_batch", 7),
    ("graph-execution", "test_gpu_batch_execution", 7),
    ("motor-task", "test_motor_effectiveness_task", 7),
    ("motor-route", "test_gpu_motor_effectiveness", 5),
    ("stage-lifecycle", "test_contained_stage_owner_v2", 17),
    ("containment", "test_contact_sequence_containment_v2", 1),
    ("provider", "adaptation_provider.test_conformance", 2),
    ("creature-controller", "test_creature_batch", 14),
    ("creature-native", "test_creature_native", 18),
]


def declaration(path):
    require(path.resolve().is_relative_to(ROOT), "Creature declaration outside repository")
    c = json.loads(path.read_text(encoding="utf-8"))
    require(c["schema_version"] == "locolemotion_creature_native_v1"
            and identifier(c["campaign_id"])
            and c["mode"] in ("route_ghost", "development_discovery")
            and c["capture_mode"] == "full" and c["native_reads_reduced"] is False
            and all(c[key] is False for key in FLAGS), "Creature declaration scope")
    require(type(c["cells"]) is list and 1 <= len(c["cells"]) <= 256
            and type(c["outer_steps"]) is int and 1 <= c["outer_steps"] <= 1440
            and type(c["seed"]) is int and 0 <= c["seed"] <= 2147483647
            and c["internal_steps_per_outer"] == 5 and c["timestep_s"] == bridge.INTERNAL_DT_S,
            "Creature dimensions or clocks")
    require(c["device"] == "cuda:0" and c["njmax"] == 128 and c["njmax_nnz"] == 1792
            and c["nvmax"] == 14 and c["naconmax_per_world"] == 64
            and c["safety_controls"] == [dict(name=n, module=m, count=k) for n, m, k in GATES],
            "Creature capacity or complete gate")
    require(c["runtime"] == {"mujoco": "3.11.0", "mujoco-warp": "3.11.0", "warp-lang": "1.16.0", "numpy": "2.4.6"}
            and c["ledger_scope"] == dict(subsystem="discovery", engine_scope="mujoco_warp",
                authority_mode="development_route_ghost" if c["mode"] == "route_ghost" else "development_discovery",
                question_class="development"), "Creature runtime or ledger scope")
    require(len(c["initial_lateral_velocities_m_s"]) == len(c["cells"])
            and all(type(v) in (int, float) and math.isfinite(v) and abs(v) <= .005
                    for v in c["initial_lateral_velocities_m_s"]), "Creature initial velocities")
    require(c["maximum_trace_bytes_per_stream"] == 268435456
            and 60 <= c["maximum_worker_wall_seconds"] <= 3600
            and 60 <= c["maximum_reader_wall_seconds"] <= 3600
            and c["minimum_free_storage_bytes"] >= 2**30, "Creature resource bounds")
    parent = ROOT / c["controller_component"]["path"]
    require(sha(parent) == c["controller_component"]["sha256"], "Creature controller predecessor")
    c["naconmax"] = len(c["cells"]) * c["naconmax_per_world"]
    return c


def initial_arrays(creatures, c):
    positions = np.asarray([v["spec"]["initial_qpos"] for v in creatures], np.float32)
    velocities = np.zeros((len(creatures), 14), np.float32)
    velocities[:, 1] = c["initial_lateral_velocities_m_s"]
    return positions, velocities


def preflight(c, core_path):
    import mujoco_warp as mjw
    require(sha(core_path) == c["core_sha256"], "Creature core binding")
    require({name: importlib.metadata.version(name) for name in c["runtime"]} == c["runtime"],
            "Creature runtime versions")
    require(all(callable(getattr(mjw, name, None)) for name in ("put_model", "put_data", "step1", "step2", "get_data_into")),
            "Creature native interfaces")
    with ExitStack() as trap:
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in creature preflight")))
        core = bridge.LocomotionCore(core_path)
        batch = CreatureBatch(core, c["cells"], seed=c["seed"])
        try:
            creatures = [cell.creature for cell in batch.controllers]
            positions, velocities = initial_arrays(creatures, c)
            require(positions.shape == (len(creatures), 15) and velocities.shape == (len(creatures), 14),
                    "Creature initial population")
            return dict(ok=True, world_build_count=0, solver_steps=0, planned_gpu_worlds=len(creatures),
                        distinct_body_shapes=len({v["binding"]["body_shape_sha256"] for v in creatures}),
                        bindings=batch.bindings)
        finally:
            batch.close()


def validate_launch(folder, c, contract_path):
    owner = json.loads((folder.parent / "declaration.json").read_text())
    gate = json.loads((folder.parent / "gate-receipt.json").read_text())
    claim = json.loads((folder.parent / "consumed.json").read_text())
    require(owner["contract"] == c and owner["source_status"] == []
            and owner["synthetic"] is False and all(owner[key] is False for key in FLAGS),
            "Creature clean native owner")
    require(gate["ok"] is True and gate["source_commit"] == owner["source_commit"] == claim["source_commit"]
            and gate["declaration_sha256"] == sha(folder.parent / "declaration.json")
            and gate["safety_controls"] == {n:k for n, _, k in GATES}
            and gate["preflight"]["world_build_count"] == gate["preflight"]["solver_steps"] == 0
            and gate["preflight"]["planned_gpu_worlds"] == len(c["cells"]),
            "Creature complete native gate")
    require(claim["attempt_id"] == folder.parent.name and claim["contract_sha256"] == sha(contract_path)
            and claim["gate_receipt_sha256"] == sha(folder.parent / "gate-receipt.json"),
            "Creature single-use native claim")


def run(folder, permit, c, contract_path, core_path):
    from contained_stage_owner_v2 import jobs
    require(permit.is_file() and jobs.current_in_job(), "Creature execution requires job containment")
    validate_launch(folder, c, contract_path)
    preflight(c, core_path)
    import warp as wp
    import mujoco_warp as mjw
    result = dict(schema_version="locolemotion_creature_worker_v1", ok=False, synthetic=False,
        ledger_scope=c["ledger_scope"], constructed_gpu_worlds=0, native_model_constructions=0,
        stepped_cpu_worlds=0, controller_rows=0, native_rows=0, **{k: False for k in FLAGS})
    batch, started, stage = None, time.perf_counter(), "setup"
    try:
        wp.config.kernel_cache_dir = str(folder / "warp-cache")
        wp.init()
        device = wp.get_device(c["device"])
        require(device.is_cuda, "Creature native GPU device")
        wp.set_device(device)
        core = bridge.LocomotionCore(core_path)
        batch = CreatureBatch(core, c["cells"], seed=c["seed"])
        creatures = [cell.creature for cell in batch.controllers]
        models, views, originals, metadatas = [], [], [], []
        for index, creature in enumerate(creatures):
            directory = folder / ("cell_" + str(index))
            directory.mkdir()
            write_new(directory / "creature.json", creature)
            with (directory / "model.xml").open("x", encoding="utf-8", newline="\n") as stream:
                stream.write(creature["model_xml"])
            # The marker precedes construction so even a constructor failure is retained.
            write_new(directory / "model-construction-started.json", dict(cell=index, binding=creature["binding"]))
            model = mujoco.MjModel.from_xml_string(creature["model_xml"])
            result["native_model_constructions"] += 1
            view = mujoco.MjData(model)
            for i, (motor, joint) in enumerate(zip(creature["spec"]["ordered_actuators"], creature["spec"]["ordered_joints"], strict=True)):
                named_force_samples(model, view, motor, joint)
                require([int(model.sensor_adr[model.sensor(motor + "_force").id]),
                         int(model.sensor_adr[model.sensor(joint + "_actuator_force").id])] == [2*i, 2*i+1],
                        "Creature named force order")
            models.append(model); views.append(view)
            originals.append(mjw.put_model(model))
            metadatas.append(native_metadata(model, creature))
            write_new(directory / "native-model.json", metadatas[-1])
        stage = "model_transport"
        packed, transport = pack_models(originals)
        for creature, metadata, snapshot in zip(creatures, metadatas, transport["source_models"], strict=True):
            validate_model_evidence(creature, metadata, snapshot)
        write_new(folder / "model-transport.json", transport)
        robots = [robot_view(core, v, m, d) for v, m, d in zip(creatures, models, views, strict=True)]
        nworld = len(creatures)
        write_new(folder / "world-construction-started.json", dict(planned_gpu_worlds=nworld))
        wd = mjw.put_data(models[0], views[0], nworld=nworld, naconmax=c["naconmax"],
                          njmax=c["njmax"], njmax_nnz=c["njmax_nnz"], nvmax=c["nvmax"])
        result["constructed_gpu_worlds"] = nworld
        write_new(folder / "worlds-opened.json", dict(native_gpu_worlds=nworld))
        positions, velocities = initial_arrays(creatures, c)
        wp.copy(wd.qpos, wp.array(positions, dtype=wp.float32, device=device))
        wp.copy(wd.qvel, wp.array(velocities, dtype=wp.float32, device=device))
        history = SubstepHistory(wp, wd)
        stage = "graph"
        with ExitStack() as trap:
            for name in ("mj_step", "mj_step1", "mj_step2", "mj_forward"):
                trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("CPU dynamics in creature route")))
            with wp.ScopedCapture(device=device) as prepare:
                mjw.step1(packed, wd)
            with wp.ScopedCapture(device=device) as integrate:
                integration_sequence(mjw, packed, wd, history)
            wp.synchronize_device(device)
            require(np.array_equal(wd.qpos.numpy(), positions) and np.array_equal(wd.qvel.numpy(), velocities)
                    and not any(wd.time.numpy()), "Creature graph mutated fresh world")
            validator = StreamValidator(c, creatures, metadatas)
            with ExitStack() as output:
                streams = {name: output.enter_context((folder / (name + ".jsonl")).open("x", encoding="utf-8", newline="\n"))
                           for name in ("controller", "trace", "timing")}
                def append(name, row):
                    streams[name].write(json.dumps(row, allow_nan=False, separators=(",", ":")) + "\n")
                    require(streams[name].tell() <= c["maximum_trace_bytes_per_stream"], "Creature capture budget")
                for outer in range(c["outer_steps"]):
                    stage = "outer_" + str(outer)
                    timing = dict(outer_step=outer)
                    whole = tick = time.perf_counter()
                    wp.capture_launch(prepare.graph)
                    wp.synchronize_device(device)
                    timing["prepare_s"] = time.perf_counter() - tick
                    tick = time.perf_counter()
                    snapshot = read_snapshot(wd, c, nworld, observations=True)
                    observations, copies = [], []
                    for index, (model, view, robot, cell) in enumerate(zip(models, views, robots, batch.controllers, strict=True)):
                        mjw.get_data_into(view, model, wd, index)
                        copies.append(bind_contact_compatibility_view(view, snapshot["contacts"][index]))
                        verify_view(view, snapshot, index, snapshot["contacts"][index])
                        state = robot.state_frame(outer, bridge._mujoco_to_canonical(cell.creature["spec"]["initial_qpos"][:3]))
                        stability = robot.stability_state(outer)
                        observations.append(dict(cell_id=cell.cell_id,
                            descriptor_sha256=cell.binding["descriptor_sha256"], model_xml_sha256=cell.binding["model_xml_sha256"],
                            state=state, stability=stability, kinematics=robot.endpoint_kinematics(stability)))
                    timing["observation_readback_s"] = time.perf_counter() - tick
                    tick = time.perf_counter()
                    rows = batch.step(observations)
                    timing["controller_s"] = time.perf_counter() - tick
                    tick = time.perf_counter()
                    for index, row in enumerate(rows):
                        row.update(cell=index, outer_step=outer,
                            native_observation=observation_native(views[index], snapshot["contacts"][index]),
                            contact_compatibility_copy=copies[index])
                        validator.control(row)
                        append("controller", row)
                        result["controller_rows"] += 1
                    targets = np.asarray([r["native_targets"] for r in rows], np.float32)
                    wp.copy(wd.ctrl, wp.array(targets, dtype=wp.float32, device=device))
                    timing["controller_capture_transfer_s"] = time.perf_counter() - tick
                    tick = time.perf_counter()
                    wp.capture_launch(integrate.graph)
                    wp.synchronize_device(device)
                    timing["integration_s"] = time.perf_counter() - tick
                    tick = time.perf_counter()
                    for sub, snap in enumerate(history.read(c, nworld)):
                        block = []
                        for index, creature in enumerate(creatures):
                            # The shared capture formatter gets this cell's actual caps.
                            row = next(trace_rows(snap, c, creature["spec"], outer, sub, nworld, cell_indices=[index]))
                            block.append(row)
                        validator.native(block)
                        for row in block:
                            append("trace", row)
                            result["native_rows"] += 1
                    timing["capture_validation_write_s"] = time.perf_counter() - tick
                    timing["outer_total_s"] = time.perf_counter() - whole
                    append("timing", timing)
            result["metrics"] = validator.finish()
        require(model_snapshot(packed) == transport["packed_model"], "Native model changed during execution")
        write_new(folder / "model-after.json", model_snapshot(packed))
        result.update(ok=True, model_unchanged=True, stream_sha256={name: sha(folder / (name + ".jsonl"))
            for name in ("controller", "trace", "timing")})
    except BaseException as exc:
        result.update(error=type(exc).__name__ + ": " + str(exc), stage=stage)
    finally:
        if batch is not None:
            batch.close()
        result["wall_s"] = time.perf_counter() - started
        write_new(folder / "worker-result.json", result)
    require(result["ok"], "Creature worker failed: " + result.get("error", "unknown"))
    return result


class StreamValidator:
    """Per-creature observation/solver joins, reused live and by the independent reader."""
    def __init__(self, c, creatures, metadata):
        self.c, self.creatures, self.metadata = c, creatures, metadata
        self.nworld = len(creatures)
        self.controls, self.previous = {}, [None] * self.nworld
        self.control_counts, self.native_counts = [0] * self.nworld, [0] * self.nworld
        self.positions, self.velocities = initial_arrays(creatures, c)
        self.metrics = [dict(minimum_height_m=math.inf, maximum_tilt_rad=0., torso_contact_steps=0,
                             safe_no_actuation_steps=0, forward_displacement_m=0.) for _ in creatures]

    def control(self, row):
        cell, outer = row["cell"], row["outer_step"]
        require(type(cell) is int and 0 <= cell < self.nworld and outer == self.control_counts[cell]
                and outer < self.c["outer_steps"], "Creature controller order or denominator")
        expected_binding = dict(self.creatures[cell]["binding"], cell_id=self.c["cells"][cell]["cell_id"],
                                candidate_id=self.c["cells"][cell]["profile"]["id"])
        require(row["binding"] == expected_binding, "Crossed creature controller binding")
        validate_observation(row, self.metadata[cell], self.creatures[cell]["compiled"])
        contacts = row["native_observation"]["contacts"]
        require(all(contact["world"] == cell for contact in contacts), "Crossed prepared contact world")
        compatibility = row["contact_compatibility_copy"]
        require(compatibility["unstepped_host_copy_only"] is True
                and compatibility["legacy_geometry_after"] == compatibility["native_geometry"] == [r["geom"] for r in contacts],
                "Creature contact compatibility")
        previous = self.previous[cell]
        require(row["native_observation"]["qpos"] == (previous["qpos"] if previous else self.positions[cell].tolist())
                and row["native_observation"]["qvel"] == (previous["qvel"] if previous else self.velocities[cell].tolist()),
                "Creature prepared state continuity")
        self.controls[cell] = row
        self.control_counts[cell] += 1
        self.metrics[cell]["safe_no_actuation_steps"] += int(row["resolution"]["safe_no_actuation"])

    def native(self, rows):
        from gpu_quadruped_probe import check_capture
        require(len(rows) == self.nworld and [r["cell"] for r in rows] == list(range(self.nworld)),
                "Creature native block population")
        require(len({r["step"] for r in rows}) == 1 and len({r["batch_contacts"] for r in rows}) == 1
                and sorted(hit["native_index"] for r in rows for hit in r["contacts"]) == list(range(rows[0]["batch_contacts"])),
                "Creature global contact population")
        for cell, row in enumerate(rows):
            step = row["step"]
            require(step == self.native_counts[cell] + 1 and step <= self.c["outer_steps"] * 5,
                    "Creature native step order")
            control = self.controls[cell]
            require(control["outer_step"] == (step-1)//5, "Creature controller/native clock join")
            caps = [[f32(v) for v in pair] for pair in self.creatures[cell]["spec"]["force_ranges"]]
            check_capture(row, self.c, caps)
            prior = self.previous[cell]
            require(row["backend"] == "gpu" and row["before_qpos"] == (prior["qpos"] if prior else self.positions[cell].tolist())
                    and row["before_qvel"] == (prior["qvel"] if prior else self.velocities[cell].tolist())
                    and row["ctrl"] == [f32(v) for v in control["native_targets"]], "Creature solver input join")
            require(len(row["qpos"]) == 15 and len(row["qvel"]) == 14
                    and abs(sum(v*v for v in row["qpos"][3:7])-1.) <= 128*2**-23
                    and abs(row["time_s"] - step*self.c["timestep_s"]) <= 4*2**-23*step*step*self.c["timestep_s"],
                    "Creature native pose or clock")
            require(row["on_force_cap"] == [v <= lo or v >= hi for v, (lo, hi) in zip(row["actuator_force_nm"], caps, strict=True)],
                    "Creature force-cap labels")
            for hit in row["contacts"]:
                require(type(hit["native_index"]) is int and hit["world"] == cell and len(hit["geom"]) == 2 and 0 in hit["geom"]
                        and hit["geom"][0] != hit["geom"][1] and all(type(v) is int and 0 <= v < 10 for v in hit["geom"])
                        and len(hit["position_m"]) == 3 and len(hit["frame"]) == 9, "Creature contact binding")
            m = self.metrics[cell]
            m["minimum_height_m"] = min(m["minimum_height_m"], row["qpos"][2])
            m["maximum_tilt_rad"] = max(m["maximum_tilt_rad"], math.acos(max(-1., min(1., 1-2*(row["qpos"][4]**2+row["qpos"][5]**2)))))
            m["torso_contact_steps"] += int(any(1 in hit["geom"] for hit in row["contacts"]))
            m["forward_displacement_m"] = row["qpos"][0] - self.creatures[cell]["spec"]["initial_qpos"][0]
            self.previous[cell] = row
            self.native_counts[cell] += 1

    def finish(self):
        require(self.control_counts == [self.c["outer_steps"]] * self.nworld
                and self.native_counts == [self.c["outer_steps"]*5] * self.nworld, "Incomplete creature streams")
        return copy.deepcopy(self.metrics)


def audit(folder, c, core_path, *, synthetic=False):
    require(sha(core_path) == c["core_sha256"], "Creature reader runtime binding")
    result = json.loads((folder / "worker-result.json").read_text())
    nworld = len(c["cells"])
    require(result["schema_version"] == "locolemotion_creature_worker_v1" and result["ledger_scope"] == c["ledger_scope"]
            and result["ok"] is True and result["synthetic"] is synthetic and result["model_unchanged"] is True
            and all(result[k] is False for k in FLAGS) and result["constructed_gpu_worlds"] == nworld
            and result["native_model_constructions"] == nworld and result["stepped_cpu_worlds"] == 0,
            "Incomplete creature native worker")
    with ExitStack() as trap:
        for name in ("MjModel", "MjData", "mj_step", "mj_step1", "mj_step2", "mj_forward"):
            trap.enter_context(patch.object(mujoco, name, side_effect=AssertionError("Physics in creature reader")))
        core = bridge.LocomotionCore(core_path)
        controllers = []
        try:
            controllers = [CreatureController(core, cell, seed=c["seed"]) for cell in c["cells"]]
            creatures = [controller.creature for controller in controllers]
            metadata = [json.loads((folder / ("cell_" + str(i)) / "native-model.json").read_text()) for i in range(nworld)]
            transport = json.loads((folder / "model-transport.json").read_text())
            differing = verify_transport(transport, nworld)
            require(json.loads((folder / "model-after.json").read_text()) == transport["packed_model"], "Final native model changed")
            for index, (creature, m, snapshot) in enumerate(zip(creatures, metadata, transport["source_models"], strict=True)):
                directory = folder / ("cell_" + str(index))
                require(json.loads((directory / "creature.json").read_text()) == creature
                        and (directory / "model.xml").read_bytes() == creature["model_xml"].encode(), "Creature compile reconstruction")
                validate_model_evidence(creature, m, snapshot)
            validator = StreamValidator(c, creatures, metadata)
            require(set(result["stream_sha256"]) == {"controller", "trace", "timing"}, "Creature stream binding population")
            for name, digest in result["stream_sha256"].items():
                require(sha(folder / (name + ".jsonl")) == digest, "Creature original stream changed")
            with (folder / "controller.jsonl").open() as control, (folder / "trace.jsonl").open() as trace:
                for outer in range(c["outer_steps"]):
                    for cell, controller in enumerate(controllers):
                        row = json.loads(next(control))
                        require(row["cell"] == cell and row["outer_step"] == outer, "Crossed creature controller stream")
                        validator.control(row)
                        observation = dict(cell_id=controller.cell_id,
                            descriptor_sha256=controller.binding["descriptor_sha256"], model_xml_sha256=controller.binding["model_xml_sha256"],
                            state=row["request"]["state"], stability=row["stability"], kinematics=row["kinematics"])
                        replay = controller.step(observation)
                        require(same_bits(replay, {key: row[key] for key in replay}), "Creature scalar replay differs")
                    for _ in range(5):
                        validator.native([json.loads(next(trace)) for _ in range(nworld)])
                require(not control.read() and not trace.read(), "Extra creature stream rows")
            metrics = validator.finish()
            timing = validate_timing([json.loads(line) for line in (folder / "timing.jsonl").read_text().splitlines()], c)
            require(metrics == result["metrics"] and result["controller_rows"] == nworld*c["outer_steps"]
                    and result["native_rows"] == nworld*c["outer_steps"]*5, "Creature result summary")
            return dict(schema_version="locolemotion_creature_native_audit_v1", ledger_scope=c["ledger_scope"],
                ok=True, synthetic=synthetic, reader_world_build_count=0, gpu_worlds=nworld,
                distinct_body_shapes=len({v["binding"]["body_shape_sha256"] for v in creatures}),
                controller_rows_replayed=result["controller_rows"], native_rows_verified=result["native_rows"],
                differing_model_fields=differing, metrics=metrics, timing_seconds=timing, **{key: False for key in FLAGS})
        finally:
            for controller in controllers:
                controller.close()


def validate_timing(rows, c):
    sections = ["prepare_s", "observation_readback_s", "controller_s", "controller_capture_transfer_s",
                "integration_s", "capture_validation_write_s"]
    require(len(rows) == c["outer_steps"], "Creature timing denominator")
    totals = {key: 0. for key in [*sections, "outer_total_s"]}
    for index, row in enumerate(rows):
        require(set(row) == {"outer_step", *totals} and row["outer_step"] == index
                and all(type(row[key]) in (int, float) and math.isfinite(row[key]) and row[key] >= 0 for key in totals)
                and row["outer_total_s"] + 1e-9 >= sum(row[key] for key in sections), "Creature timing fields or accounting")
        for key in totals:
            totals[key] += row[key]
    return totals


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--audit", action="store_true")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--folder", type=Path)
    parser.add_argument("--permit", type=Path)
    args = parser.parse_args()
    c = declaration(args.contract)
    if args.check_only:
        print(json.dumps(preflight(c, args.core)))
    elif args.audit:
        write_new(args.output, audit(args.folder, c, args.core))
    else:
        run(args.output, args.permit, c, args.contract, args.core)


if __name__ == "__main__":
    main()
