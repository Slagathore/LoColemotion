"""Full scalar/native replay and predeclared matched-trajectory comparisons."""
import argparse
import json
import math
from pathlib import Path
from unittest.mock import patch
import mujoco
import numpy as np
from motor_batch_diagnostic_task import declaration, trial_plan, comparison_pairs
from motor_effectiveness_task import condition_inputs, expected_actuator_arrays
from gpu_quadruped_model import FLAGS, sha
from portable_search_control import bridge
from audit_gpu_motor_effectiveness import audit_trial
from audit_gpu_batch_execution import same_bits, read_jsonl
from audit_gpu_portable_search import require


def selected_trace(path, cell):
    return [r for r in read_jsonl(path) if r["cell"] == cell]


def trajectory_difference(left, right):
    require(len(left) == len(right) and len(left) > 0, "Matched trace denominator")
    fields = {k: dict(first_differing_step=None, maximum_absolute_difference=0.)
              for k in ["qpos", "qvel", "ctrl", "actuator_force_nm"]}
    for a, b in zip(left, right, strict=True):
        require(a["step"] == b["step"], "Matched trace clock")
        for key, record in fields.items():
            require(len(a[key]) == len(b[key]) and all(math.isfinite(x) for x in a[key]+b[key]), "Matched finite vector")
            delta = max(abs(x-y) for x, y in zip(a[key], b[key], strict=True))
            if not same_bits(a[key], b[key]) and record["first_differing_step"] is None:
                record["first_differing_step"] = a["step"]
            record["maximum_absolute_difference"] = max(record["maximum_absolute_difference"], delta)
    return fields


def compare(folder, trials, c):
    plans = trial_plan(c)
    require(len(trials) == len(plans) and all(all(t[k] == v for k,v in p.items())
        for t,p in zip(trials, plans, strict=True)), "Comparison trial population")
    indexed = {t["trial_id"]: t for t in trials}
    result = []
    # Only the predeclared cells are compared. Negative episodes remain present.
    for pair in comparison_pairs(c):
        a, b = indexed[pair["left"]], indexed[pair["right"]]
        ac, bc = pair["left_cell"], pair["right_cell"]
        require(a["candidate_indices"][ac] == b["candidate_indices"][bc] == 6, "Matched controller identity")
        traces = [selected_trace(folder/t["layout"]/t["trial_id"]/"trace.jsonl", cell)
                  for t, cell in [(a, ac), (b, bc)]]
        require(all(len(rows) == c["outer_steps"]*5 for rows in traces), "Comparison complete horizon")
        outcomes = [t["episodes"][cell]["outcome"] for t,cell in [(a,ac), (b,bc)]]
        result.append(dict(pair, left_outcome=outcomes[0], right_outcome=outcomes[1],
            eligibility_disagreement=outcomes[0] != outcomes[1],
            left_metrics=a["metrics"][ac], right_metrics=b["metrics"][bc],
            trajectory=trajectory_difference(*traces)))
    return result


def audit(folder, core_path, baseline_path):
    phase = "matched_diagnostic"
    declared = json.loads((folder.parent/"declaration.json").read_text())
    c = declared["contract"]
    synthetic = declared.get("synthetic", False)
    expected = declaration()
    require(type(synthetic) is bool, "Synthetic identity")
    if synthetic:
        require(1 <= c["outer_steps"] <= 480, "Synthetic horizon")
        expected.update(outer_steps=c["outer_steps"], synthetic=True, training_data_authority=False)
    require(c == expected, "Prospective motor contract changed")
    require(sha(core_path) == c["core_sha256"] and sha(baseline_path) == c["baseline_core_sha256"], "Core identity")
    plans = trial_plan(c)
    layouts = [r["id"] for r in c["diagnostic"]["layouts"]]
    require(set(p.name for p in folder.iterdir() if p.is_dir() and p.name != "warp-cache") == set(layouts), "Condition folder population")
    observed, workers = [], []
    core = bridge.LocomotionCore(baseline_path)
    phase_contract = dict(c, training_data_authority=False)
    with patch.object(mujoco, "MjModel", side_effect=AssertionError("Audit world")), \
            patch.object(mujoco, "MjData", side_effect=AssertionError("Audit data")), \
            patch.object(mujoco, "mj_step", side_effect=AssertionError("Audit physics")):
        for layout in layouts:
            cid = "left_075"
            directory = folder/layout
            worker = json.loads((directory/"worker-result.json").read_text())
            require(worker["ok"] is True and worker["synthetic"] is synthetic
                and worker["phase"] == phase and worker["condition_id"] == cid and worker["layout"] == layout
                and worker["status"] == "complete_motor_batch_diagnostic_layout"
                and worker["controller_sessions_closed"] is True
                and type(worker["total_wall_s"]) in (int, float) and math.isfinite(worker["total_wall_s"])
                and worker["total_wall_s"] >= 0
                and all(worker[k] is phase_contract[k] for k in FLAGS), "Incomplete/crossed condition worker")
            expected_compiled, xml, expected_spec = condition_inputs(core_path, c, cid)
            require((directory/"model.xml").read_text() == xml
                and sha(directory/"model.xml") == c["condition_model_sha256"][cid], "Condition XML binding")
            compiled = json.loads((directory/"compiled.json").read_text())
            spec = json.loads((directory/"inputs.json").read_text())
            require(compiled == expected_compiled and spec == expected_spec, "Condition compiler/input binding")
            metadata = json.loads((directory/"native-model.json").read_text())
            for name in ["model", "compiled", "inputs"]:
                require(metadata[name+"_sha256"] == sha(directory/(name+(".xml" if name == "model" else ".json"))), "Native input digest")
            require(metadata["condition_id"] == cid and metadata["actuator_profile"] == expected_actuator_arrays(spec)
                and metadata["force_ranges"] == spec["force_ranges"]
                and metadata["observation_stage"] == "prepared_before_control"
                and metadata["force_stage"] == "completed_step_before_next_prepare", "Condition native profile/sampling")
            gpu = json.loads((directory/"gpu-actuator-profile.json").read_text())
            expected_gpu = {k: [np.asarray(expected_actuator_arrays(spec)[k], np.float32).tolist()]
                for k in ["gainprm", "biasprm", "forcerange"]}
            require(same_bits(gpu, expected_gpu), "Condition GPU profile binding")
            condition_plans = [p for p in plans if p["layout"] == layout]
            require(len(worker["trials"]) == len(condition_plans) == 2
                and worker["constructed_gpu_worlds"] == worker["cpu_readback_views"] == sum(p["nworld"] for p in condition_plans)
                and worker["stepped_cpu_worlds"] == 0, "Condition world population")
            for plan, recorded in zip(condition_plans, worker["trials"], strict=True):
                require(json.loads((directory/plan["trial_id"]/"result.json").read_text()) == recorded, "Worker trial index")
                observed.append(audit_trial(directory/plan["trial_id"], plan, phase_contract, spec, compiled, metadata, core))
            workers.append(dict(condition_id=cid, layout=layout, total_wall_s=worker["total_wall_s"],
                worker_result_sha256=sha(directory/"worker-result.json")))
    require([r["trial_id"] for r in observed] == [p["trial_id"] for p in plans], "Full phase trial order")
    result = dict(ok=True, phase=phase, synthetic=synthetic, ledger_scope=c["ledger_scope"], trials=observed,
        workers=workers, controller_rows=sum(r["controller_rows"] for r in observed),
        internal_rows=sum(r["internal_rows"] for r in observed),
        constructed_gpu_worlds=sum(p["nworld"] for p in plans), stepped_cpu_worlds=0, reader_world_build_count=0,
        eligible_episodes=sum(e["outcome"] == "positive" for r in observed for e in r["episodes"]),
        negative_episodes=sum(e["outcome"] == "negative" for r in observed for e in r["episodes"]),
        training_data_scope="diagnostic_only", **{k: phase_contract[k] for k in FLAGS})

    result["comparisons"] = compare(folder, observed, c)
    result["population_inference"] = False
    result["controller_selection_authority"] = False
    return result


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--folder", type=Path, required=True)
    p.add_argument("--core", type=Path, required=True)
    p.add_argument("--baseline-core", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    result = audit(a.folder, a.core, a.baseline_core)
    with a.output.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(result, stream, indent=2, allow_nan=False)
        stream.write("\n")
    print(json.dumps({k: result[k] for k in ["ok", "controller_rows", "internal_rows",
        "eligible_episodes", "negative_episodes", "reader_world_build_count"]}))
