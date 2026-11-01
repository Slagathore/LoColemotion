"""Replay every fixed shortlist world and assess full and prefix outcomes."""
import argparse
import itertools
import json
from pathlib import Path
from unittest.mock import patch

import mujoco
import numpy as np

from population_shortlist_task_v1 import FLAGS, declaration, synthetic_contract, plans, summarize, assess, require, sha
from motor_effectiveness_task import condition_inputs, expected_actuator_arrays
from portable_search_control import bridge
from audit_gpu_batch_execution import read_jsonl, same_bits, timing_summary
from audit_gpu_motor_effectiveness import audit_trial as full_audit
from audit_population_discovery_v2 import verify_full_projection
from gpu_measurement_probe import write_new


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def full_trial(folder, plan, c, spec, compiled, metadata, core):
    result = read(folder / "result.json")
    require(plan["capture_mode"] == "full" and read(folder / "plan.json") == plan
        and all(result[k] == v for k, v in plan.items()) and result["completed"] is True,
        "Shortlist full trial plan or completion")
    names = {"compact", "timing", "controller", "trace"}
    require(set(result["hashes"]) == set(result["stream_bytes"]) == names
        and {p.stem for p in folder.glob("*.jsonl")} == names, "Shortlist full streams required")
    for name in names:
        path = folder / (name + ".jsonl")
        require(sha(path) == result["hashes"][name] and path.stat().st_size == result["stream_bytes"][name]
            and 0 < path.stat().st_size <= c["maximum_trace_bytes_per_trial"], "Shortlist raw binding or byte budget")
    require(result["outer_rows"] == plan["nworld"]*plan["outer_steps"]
        and result["internal_rows"] == 5*result["outer_rows"], "Shortlist complete native horizon")
    cfg = dict(c, seed=plan["seed"], outer_steps=plan["outer_steps"])
    episodes = summarize(read_jsonl(folder / "compact.jsonl"), cfg, plan, spec)
    require(same_bits(episodes, result["episodes"]), "Shortlist whole outcome reconstruction")
    full = full_audit(folder, plan, cfg, spec, compiled, metadata, core)
    verify_full_projection(folder, plan)
    require(same_bits(full["metrics"], [e["metrics"] for e in episodes]), "Shortlist raw/reduced metric disagreement")
    count = c["challenge"]["prefix_outer_steps"]
    prefix_plan = dict(plan, outer_steps=count)
    prefix = summarize(itertools.islice(read_jsonl(folder / "compact.jsonl"), count*plan["nworld"]),
        dict(cfg, outer_steps=count), prefix_plan, spec)
    return dict(plan=plan, episodes=episodes, prefix_episodes=prefix,
        hashes=result["hashes"], stream_bytes=result["stream_bytes"],
        timings=timing_summary(list(read_jsonl(folder / "timing.jsonl")), cfg),
        setup_s=result["setup_s"], graph_capture_s=result["graph_capture_s"],
        full_replay=dict(controller_rows=full["controller_rows"], internal_rows=full["internal_rows"],
            maximum_force_error_nm=full["maximum_force_error_nm"], projection_verified=True))


def audit(folder, core_path, baseline_path, allow_synthetic=False):
    c = declaration()
    owner = read(folder.parent / "declaration.json")
    synthetic = owner["synthetic"]
    require(type(synthetic) is bool and (not synthetic or allow_synthetic), "Synthetic shortlist is not native evidence")
    if synthetic:
        c = synthetic_contract(c, owner["contract"]["outer_steps"])
    require(owner["contract"] == c and all(owner[k] is False for k in FLAGS), "Shortlist owner declaration")
    require(sha(core_path) == c["core_sha256"] and sha(baseline_path) == c["baseline_core_sha256"], "Shortlist core bindings")
    worker = read(folder / "worker-result.json")
    planned = plans(c)
    cells = sum(p["nworld"] for p in planned)
    worlds = 0 if synthetic else cells
    require(worker["ok"] is True and worker["phase"] == "challenge" and worker["synthetic"] is synthetic
        and worker["constructed_gpu_worlds"] == worker["cpu_readback_views"] == worlds
        and worker["stepped_cpu_worlds"] == 0 and worker["controller_sessions_closed"] is True
        and len(worker["trials"]) == len(planned) and all(worker[k] is False for k in FLAGS), "Shortlist worker lifecycle")
    conditions = {x["condition_id"] for x in c["conditions"]}
    require({p.name for p in folder.iterdir() if p.is_dir() and p.name != "warp-cache"} == conditions,
        "Shortlist complete condition directories")
    observed = []
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
                and sha(directory / "model.xml") == c["condition_model_sha256"][cid], "Shortlist model identity")
            metadata = read(directory / "native-model.json")
            require(metadata["actuator_profile"] == expected_actuator_arrays(spec)
                and metadata["gpu_actuator_profile"] == {k: np.asarray([expected_actuator_arrays(spec)[k]], np.float32).tolist()
                    for k in ("gainprm", "biasprm", "forcerange")}
                and metadata["condition_id"] == cid and metadata["force_ranges"] == spec["force_ranges"]
                and metadata["observation_stage"] == "prepared_before_control"
                and metadata["force_stage"] == "completed_step_before_next_prepare", "Shortlist native model profile")
            for name in ("model", "inputs", "compiled"):
                require(metadata[name + "_sha256"] == sha(directory / (name + (".xml" if name == "model" else ".json"))),
                    "Shortlist model artifact digest")
            require({p.name for p in directory.iterdir() if p.is_dir()} == {p["trial_id"] for p in planned if p["condition_id"] == cid},
                "Shortlist complete trial directories")
            for plan in planned:
                if plan["condition_id"] != cid:
                    continue
                trial_dir = directory / plan["trial_id"]
                require(worker["trials"][len(observed)] == read(trial_dir / "result.json"), "Shortlist worker/trial join")
                marker = dict(native_gpu_worlds=0 if synthetic else plan["nworld"], trial_id=plan["trial_id"])
                require(read(trial_dir / "worlds-opened.json") == marker, "Shortlist native world marker")
                observed.append(full_trial(trial_dir, plan, c, spec, compiled, metadata, core))
    require(len(observed) == 4 and cells == 20, "Shortlist full population denominator")
    return dict(ok=True, synthetic=synthetic, phase="challenge", ledger_scope=c["ledger_scope"],
        trials=observed, assessment=assess(observed, c), full_trials_replayed=len(observed),
        full_capture_native_evidence_verified=not synthetic, audited_cells=cells,
        constructed_gpu_worlds=worlds, reader_world_build_count=0,
        controller_rows=sum(t["full_replay"]["controller_rows"] for t in observed),
        internal_rows=sum(t["full_replay"]["internal_rows"] for t in observed),
        calibration_worlds=0, evaluation_worlds=0, **{key: False for key in FLAGS})


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--phase", choices=["challenge"], required=True)
    parser.add_argument("--folder", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = audit(args.folder, args.core, args.baseline_core)
    write_new(args.output, result)
    print(json.dumps(dict(ok=True, full_trials_replayed=result["full_trials_replayed"],
        controller_rows=result["controller_rows"], internal_rows=result["internal_rows"])))
