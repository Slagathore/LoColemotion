"""Read every compact trial; replay only the prospectively named full canaries."""
import argparse
import json
import math
from pathlib import Path
from unittest.mock import patch

import mujoco
import numpy as np

from population_discovery_task_v1 import ROOT, FLAGS, declaration, plans, summarize, select, require, sha, f32
from motor_effectiveness_task import condition_inputs, expected_actuator_arrays
from portable_search_control import bridge
from audit_gpu_batch_execution import read_jsonl, same_bits, timing_summary
from audit_gpu_motor_effectiveness import audit_trial as full_audit
from gpu_measurement_probe import write_new


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def compact_trial(folder, plan, c, spec):
    result = read(folder / "result.json")
    require(read(folder / "plan.json") == plan and all(result[k] == v for k, v in plan.items())
        and result["completed"] is True, "Compact trial plan or completion")
    names = {"compact", "timing"} | ({"controller", "trace"} if plan["capture_mode"] == "full" else set())
    require(set(result["hashes"]) == set(result["stream_bytes"]) == names
        and {p.stem for p in folder.glob("*.jsonl")} == names, "Compact capture profile")
    for name in names:
        path = folder / (name + ".jsonl")
        require(sha(path) == result["hashes"][name] and path.stat().st_size == result["stream_bytes"][name]
            and 0 < path.stat().st_size <= c["maximum_trace_bytes_per_trial"], "Compact raw binding or byte budget")
    require(result["outer_rows"] == plan["nworld"] * plan["outer_steps"]
        and result["internal_rows"] == plan["nworld"] * plan["outer_steps"] * 5, "Compact observed population")
    cfg = dict(c, outer_steps=plan["outer_steps"], seed=plan["seed"])
    episodes = summarize(read_jsonl(folder / "compact.jsonl"), cfg, plan, spec)
    require(same_bits(episodes, result["episodes"]), "Compact outcome reconstruction")
    return dict(plan=plan, episodes=episodes, compact_sha256=result["hashes"]["compact"],
        timings=timing_summary(list(read_jsonl(folder / "timing.jsonl")), cfg),
        stream_bytes=result["stream_bytes"], setup_s=result["setup_s"], graph_capture_s=result["graph_capture_s"])


def verify_full_projection(folder, plan):
    """Compare every retained compact field directly with independent raw inputs.

    This is deliberately separate from LiveBlock.reduce: a projection bug shared
    by both recording modes must still be visible in a full canary.
    """
    controls = iter(read_jsonl(folder / "controller.jsonl"))
    traces = iter(read_jsonl(folder / "trace.jsonl"))
    compact = iter(read_jsonl(folder / "compact.jsonl"))
    nworld = plan["nworld"]
    for outer in range(plan["outer_steps"]):
        control = [next(controls) for _ in range(nworld)]
        raw = [[next(traces) for _ in range(nworld)] for _ in range(5)]
        for cell in range(nworld):
            row = next(compact)
            source = control[cell]
            native = source["native_observation"]
            require(row["native_targets"] == list(map(f32, source["native_targets"]))
                and row["prepared_time_s"] == native["time_s"]
                and row["prepared_qpos"] == native["qpos"] and row["prepared_qvel"] == native["qvel"]
                and row["completed_qpos"] == raw[-1][cell]["qpos"]
                and row["completed_qvel"] == raw[-1][cell]["qvel"]
                and row["safe_no_actuation"] is source["output"]["actuation"]["safe_no_actuation"],
                "Full/compact solver input or boundary projection")
            for sub, actual in enumerate(row["samples"]):
                sample = raw[sub][cell]
                x, y = sample["qpos"][4:6]
                expected = dict(time_s=sample["time_s"], height_m=sample["qpos"][2],
                    tilt_rad=math.acos(max(-1., min(1., 1 - 2*(x*x + y*y)))),
                    torso_contact=any(1 in contact["geom"] for contact in sample["contacts"]),
                    ground_contact=bool(sample["contacts"]),
                    nonzero_force=any(force != 0. for force in sample["actuator_force_nm"]),
                    force_cap_count=sum(sample["on_force_cap"]))
                require(same_bits(actual, expected), "Full/compact internal sample projection")
    sentinel = object()
    require(all(next(stream, sentinel) is sentinel for stream in (controls, traces, compact)), "Full projection denominator")


def audit(folder, core_path, baseline_path, phase):
    c = declaration()
    owner = read(folder.parent / "declaration.json")
    require(owner["contract"] == c and owner["synthetic"] is False, "Population owner declaration")
    require(sha(core_path) == c["core_sha256"] and sha(baseline_path) == c["baseline_core_sha256"], "Population core bindings")
    worker = read(folder / "worker-result.json")
    planned = plans(c, phase)
    worlds = sum(p["nworld"] for p in planned)
    require(worker["ok"] is True and worker["phase"] == phase and worker["synthetic"] is False
        and worker["constructed_gpu_worlds"] == worker["cpu_readback_views"] == worlds
        and worker["stepped_cpu_worlds"] == 0 and worker["controller_sessions_closed"] is True
        and len(worker["trials"]) == len(planned) and all(worker[k] is False for k in FLAGS), "Population worker lifecycle")
    observed, full_count = [], 0
    core = bridge.LocomotionCore(baseline_path)
    with patch.object(mujoco, "MjModel", side_effect=AssertionError("Reader world")), \
            patch.object(mujoco, "MjData", side_effect=AssertionError("Reader data")), \
            patch.object(mujoco, "mj_step", side_effect=AssertionError("Reader physics")):
        for condition in c["conditions"]:
            cid = condition["condition_id"]
            directory = folder / cid
            compiled, xml, spec = condition_inputs(core_path, c, cid)
            require(read(directory / "compiled.json") == compiled and read(directory / "inputs.json") == spec
                and (directory / "model.xml").read_text(encoding="utf-8") == xml
                and sha(directory / "model.xml") == c["condition_model_sha256"][cid], "Population model identity")
            metadata = read(directory / "native-model.json")
            require(metadata["actuator_profile"] == expected_actuator_arrays(spec)
                and metadata["gpu_actuator_profile"] == {k: np.asarray([expected_actuator_arrays(spec)[k]], np.float32).tolist()
                    for k in ("gainprm", "biasprm", "forcerange")}
                and metadata["condition_id"] == cid and metadata["force_ranges"] == spec["force_ranges"]
                and metadata["observation_stage"] == "prepared_before_control"
                and metadata["force_stage"] == "completed_step_before_next_prepare", "Population native model profile")
            for name in ("model", "inputs", "compiled"):
                require(metadata[name + "_sha256"] == sha(directory / (name + (".xml" if name == "model" else ".json"))), "Population model artifact digest")
            expected_dirs = {p["trial_id"] for p in planned if p["condition_id"] == cid}
            require({p.name for p in directory.iterdir() if p.is_dir()} == expected_dirs, "Population trial directories")
            for plan in planned:
                if plan["condition_id"] != cid:
                    continue
                trial_dir = directory / plan["trial_id"]
                require(worker["trials"][len(observed)] == read(trial_dir / "result.json"), "Population worker/trial join")
                require(read(trial_dir / "worlds-opened.json") == dict(native_gpu_worlds=plan["nworld"], trial_id=plan["trial_id"]), "Population world marker")
                row = compact_trial(trial_dir, plan, c, spec)
                if plan["capture_mode"] == "full":
                    full = full_audit(trial_dir, plan, dict(c, outer_steps=plan["outer_steps"]), spec, compiled, metadata, core)
                    verify_full_projection(trial_dir, plan)
                    require(same_bits(full["metrics"], [e["metrics"] for e in row["episodes"]]), "Full/compact metric disagreement")
                    # The independent full reader proves controller replay, native
                    # continuity, force/clock/contact joins for these canaries.
                    row["full_replay"] = dict(controller_rows=full["controller_rows"], internal_rows=full["internal_rows"],
                        maximum_force_error_nm=full["maximum_force_error_nm"])
                    full_count += 1
                observed.append(row)
    result = dict(ok=True, phase=phase, trials=observed, reader_world_build_count=0,
        full_canaries_replayed=full_count, compact_pairs_match=False, telemetry_comparisons=[],
        constructed_gpu_worlds=worlds, calibration_worlds=0, evaluation_worlds=0,
        compact_records_are_full_evidence=False, **{key: False for key in FLAGS})
    if phase == "canaries":
        require(full_count == 2, "Full canary population")
        for cid in c["challenge"]["conditions"]:
            pair = {r["plan"]["capture_mode"]: r for r in observed if r["plan"]["condition_id"] == cid}
            require(set(pair) == {"full", "compact"} and pair["full"]["compact_sha256"] == pair["compact"]["compact_sha256"],
                "Full/compact canary native records differ")
            result["telemetry_comparisons"].append(dict(condition_id=cid,
                retained_bytes={mode: sum(r["stream_bytes"].values()) for mode, r in pair.items()},
                measured_sections_s={mode: r["timings"]["measured"] for mode, r in pair.items()},
                cold_setup_s={mode: r["setup_s"] + r["graph_capture_s"] for mode, r in pair.items()},
                limited_to_one_pair_per_condition=True, native_readback_reduction_claim=False))
        result["compact_pairs_match"] = True
    else:
        require(full_count == 0 and len(observed) == 16, "Reduced population denominator")
        result["selection"] = select(observed, c)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--phase", choices=["canaries", "population"], required=True)
    parser.add_argument("--folder", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = audit(args.folder, args.core, args.baseline_core, args.phase)
    write_new(args.output, result)
    print(json.dumps(dict(ok=True, phase=args.phase, trials=len(result["trials"]), full_canaries_replayed=result["full_canaries_replayed"])))
