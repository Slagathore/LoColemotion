"""Rehash and rejoin the complete matched diagnostic; optional full replay."""
import argparse
import json
from pathlib import Path
import re

from motor_batch_diagnostic_task import ROOT, declaration, trial_plan, sha, FLAGS
from run_motor_batch_diagnostic import GATES as STAGES
from audit_motor_batch_diagnostic import audit, compare
from audit_gpu_repertoire_negative_closure import verify_frozen_sources
from audit_gpu_batch_execution import read_jsonl, timing_summary
from audit_gpu_portable_search import require

GATES = dict([(name, count) for name, _, count in STAGES] + [("provider", 2), ("containment", 1)])


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def finite_summary(observed):
    trials = []
    action6 = {}
    for trial in observed["trials"]:
        episodes = trial["episodes"]
        trials.append(dict(trial_id=trial["trial_id"], layout=trial["layout"], start_id=trial["start_id"],
            eligible=sum(e["outcome"] == "positive" for e in episodes), denominator=len(episodes),
            focus_action_index=trial["candidate_indices"][1], focus_outcome=episodes[1]["outcome"],
            focus_metrics=trial["metrics"][1],
            positive_action_indices=[a for a,e in zip(trial["candidate_indices"], episodes, strict=True) if e["outcome"] == "positive"]))
        count = action6.setdefault(trial["start_id"], dict(eligible=0, negative=0, denominator=0))
        for action, episode in zip(trial["candidate_indices"], episodes, strict=True):
            if action == 6:
                count["denominator"] += 1
                count["eligible" if episode["outcome"] == "positive" else "negative"] += 1
    comparisons = observed["comparisons"]
    return dict(eligible=observed["eligible_episodes"], negative=observed["negative_episodes"], denominator=48,
        trials=trials, action6_by_start=action6,
        start_change_comparisons=sum(p["kind"] == "start_state" for p in comparisons),
        start_change_eligibility_disagreements=sum(p["kind"] == "start_state" and p["eligibility_disagreement"] for p in comparisons),
        other_comparisons=sum(p["kind"] != "start_state" for p in comparisons),
        other_eligibility_disagreements=sum(p["kind"] != "start_state" and p["eligibility_disagreement"] for p in comparisons),
        trajectory_identity_established=False, population_inference=False,
        training_data_authority=False, adaptation_benefit=False, qualification_or_release_authority=False)


def header(record, evidence_root):
    require(record["schema_version"] == "locolemotion_motor_batch_closure_v1"
        and record["status"] == "complete_native_matched_motor_diagnostic"
        and record["synthetic"] is False
        and all(record[k] is False for k in [*FLAGS, "controller_selection_authority", "adaptive_provider_benefit",
            "statistical_superiority_authority", "noninferiority_authority"]), "Closure identity/authority")
    require(record["trial_count"] == 8 and record["constructed_gpu_worlds"] == 48
        and record["stepped_cpu_worlds"] == record["evaluation_worlds"] == 0
        and record["controller_rows"] == 23040 and record["internal_rows"] == 115200
        and record["complete_zero_world_gate"] == GATES, "Closure population/gate")
    root = evidence_root.resolve(strict=True)
    attempt = (root/record["attempt_id"]).resolve(strict=True)
    require(attempt.parent == root and attempt.name == record["attempt_id"], "Attempt path escaped")
    entries = record["artifacts"]
    require(len(entries) == record["artifact_count"] and bool(entries), "Artifact count")
    paths = []
    for item in entries:
        path = (root/item["evidence_relative_path"]).resolve(strict=True)
        require(path.is_relative_to(attempt) and path.is_file(), "Artifact path escaped")
        require(type(item["byte_length"]) is int and item["byte_length"] >= 0
            and re.fullmatch("[0-9a-f]{64}", item["sha256"]) is not None, "Artifact binding shape")
        paths.append(path)
    require(len(paths) == len(set(paths))
        and set(paths) == {p.resolve() for p in attempt.rglob("*") if p.is_file()}, "Incomplete/duplicate artifact inventory")
    return root, attempt, paths


def verify_record(path, evidence_root, core, baseline, *, replay=False):
    record = read(path)
    root, attempt, paths = header(record, evidence_root)
    require(record["closure_reader_sha256"] == sha(Path(__file__)), "Closure reader changed")
    for item, target in zip(record["artifacts"], paths, strict=True):
        require(target.stat().st_size == item["byte_length"] and sha(target) == item["sha256"], "Retained artifact changed")
    declared, receipt, consumed = [read(attempt/name) for name in ["declaration.json", "receipt.json", "consumed.json"]]
    c = declaration(); plans = trial_plan(c)
    require(declared["contract"] == receipt["contract"] == c and record["ledger_scope"] == c["ledger_scope"], "Frozen declaration changed")
    require(declared["source_commit"] == receipt["source_commit"] == consumed["source_commit"] == record["source_commit"]
        and consumed["attempt_id"] == record["attempt_id"] and declared["binding"] == receipt["binding"], "Crossed source/attempt")
    require(receipt["ok"] is True and receipt["zero_world_gate_passed"] is True and receipt["physical_started"] is True
        and receipt["synthetic"] is False and receipt["safety_controls"] == GATES and sum(GATES.values()) == 81, "Incomplete execution/gate")
    require(declared["planned_worlds"] == receipt["planned_worlds"] == consumed["planned_worlds"] == dict(gpu=48, cpu=0)
        and declared["planned_trials"] == receipt["planned_trials"] == consumed["planned_trials"] == plans, "Prospective population")
    require(all(receipt[k] is False for k in FLAGS) and receipt["training_data_scope"] == "diagnostic_only", "Receipt authority")
    require(sha(core) == c["core_sha256"] == record["core_sha256"]
        and sha(baseline) == c["baseline_core_sha256"] == record["baseline_core_sha256"], "Core identity")
    binding = declared["binding"]
    require(verify_frozen_sources(record["source_commit"], binding["source"]) == record["source_binding_count"], "Source denominator")
    require(len(binding["runtime"]) == record["runtime_binding_count"], "Runtime denominator")
    for name, digest in binding["runtime"].items():
        require(sha(Path(name)) == digest, "Runtime bytes changed")
    for name, count in GATES.items():
        log = (attempt/(name+"-gate")/"stderr.log").read_text()
        require(re.findall(r"(?m)^Ran ([0-9]+) tests? in ", log) == [str(count)] and log.rstrip().endswith("OK"), "Safety terminal/count")
    preflight = read(attempt/"runtime-gate/stdout.log")
    require(preflight == receipt["preflight"] == dict(ok=True, world_build_count=0, solver_steps=0,
        planned_gpu_worlds=48, planned_controller_rows=23040, planned_internal_rows=115200, evaluation_worlds=0), "Preflight population")
    observed = read(attempt/"independent-audit.json")
    require(sha(attempt/"independent-audit.json") == receipt["audit_sha256"] == record["audit_sha256"], "Original audit binding")
    require(observed["ok"] is True and observed["synthetic"] is False and observed["phase"] == "matched_diagnostic"
        and observed["reader_world_build_count"] == observed["stepped_cpu_worlds"] == 0
        and observed["constructed_gpu_worlds"] == 48 and observed["controller_rows"] == 23040
        and observed["internal_rows"] == 115200 and len(observed["trials"]) == 8
        and observed["ledger_scope"] == c["ledger_scope"]
        and all(observed[k] is False for k in FLAGS)
        and observed["population_inference"] is observed["controller_selection_authority"] is False, "Reader population/authority")
    require(read(attempt/"independent-reader/stdout.log") == {k: observed[k] for k in ["ok", "controller_rows",
        "internal_rows", "eligible_episodes", "negative_episodes", "reader_world_build_count"]}, "Reader terminal")
    physical = attempt/"physical"
    workers = {}
    require(len(observed["workers"]) == 4, "Worker denominator")
    for layout, checked in zip(c["diagnostic"]["layouts"], observed["workers"], strict=True):
        worker_path = physical/layout["id"]/"worker-result.json"
        worker = read(worker_path); workers[layout["id"]] = worker
        require(worker["ok"] is True and worker["controller_sessions_closed"] is True and worker["stepped_cpu_worlds"] == 0
            and worker["constructed_gpu_worlds"] == worker["cpu_readback_views"] == 2*len(layout["actions"])
            and all(worker[k] is False for k in FLAGS), "Worker status/population")
        require(checked == dict(condition_id="left_075", layout=layout["id"], total_wall_s=worker["total_wall_s"],
            worker_result_sha256=sha(worker_path)), "Worker audit join")
    for plan, checked in zip(plans, observed["trials"], strict=True):
        directory = physical/plan["layout"]/plan["trial_id"]
        result = read(directory/"result.json")
        require(read(directory/"plan.json") == plan and all(checked[k] == v and result[k] == v for k,v in plan.items())
            and result in workers[plan["layout"]]["trials"] and result["completed"] is True, "Trial identity")
        require(checked["controller_rows"] == result["outer_rows"] == plan["nworld"]*480
            and checked["internal_rows"] == result["internal_rows"] == plan["nworld"]*2400
            and len(checked["episodes"]) == len(checked["metrics"]) == plan["nworld"], "Trial denominator")
        require(all(sha(directory/(name+".jsonl")) == result["hashes"][name] for name in ["controller", "trace", "timing"]), "Trial raw binding")
        require(timing_summary(list(read_jsonl(directory/"timing.jsonl")), c) == checked["timings"], "Timing replay")
    require(observed["eligible_episodes"] == sum(e["outcome"] == "positive" for t in observed["trials"] for e in t["episodes"])
        and observed["negative_episodes"] == sum(e["outcome"] == "negative" for t in observed["trials"] for e in t["episodes"])
        and observed["eligible_episodes"]+observed["negative_episodes"] == 48, "Outcome denominator")
    require(compare(physical, observed["trials"], c) == observed["comparisons"] == record["comparisons"], "Matched comparisons changed")
    summary = finite_summary(observed)
    require(summary == record["finite_outcomes"], "Finite outcomes changed")
    require(record["native_worker_wall_s"] == sum(w["total_wall_s"] for w in workers.values())
        and record["independent_audit_wall_s"] == receipt["audit_wall_s"], "Closure timing changed")
    if replay:
        require(audit(physical, core, baseline) == observed, "Full independent replay differs")
    return dict(ok=True, artifact_count=len(paths), source_binding_count=record["source_binding_count"],
        runtime_binding_count=record["runtime_binding_count"], original_independent_reader_controller_rows=23040,
        original_independent_reader_internal_rows=115200, reader_world_build_count=0,
        full_controller_replay_performed=replay, finite_outcomes=summary, qualification_or_release_authority=False)


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--record", type=Path, default=Path(__file__).with_name("gpu_motor_batch_closure_v1.json"))
    p.add_argument("--evidence-root", type=Path, default=ROOT.parent/"SporeSpore_Evidence")
    p.add_argument("--core", type=Path, required=True)
    p.add_argument("--baseline-core", type=Path, required=True)
    p.add_argument("--replay", action="store_true")
    a = p.parse_args()
    print(json.dumps(verify_record(a.record, a.evidence_root, a.core, a.baseline_core, replay=a.replay), indent=2))
