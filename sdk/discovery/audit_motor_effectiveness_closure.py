"""Verify the consumed two-stage motor pilot without upgrading its result.

Default mode rehashes retained bytes and rejoins the original complete audits.
--replay also repeats every scalar-controller and internal-state check.
"""
import argparse
import json
import math
from pathlib import Path
import re

from motor_effectiveness_task import ROOT, CONTRACT, declaration, trial_plan, select_profiles, sha
from audit_gpu_motor_effectiveness import audit_phase, compare_confirmation
from audit_gpu_repertoire_negative_closure import verify_frozen_sources
from audit_gpu_batch_execution import read_jsonl, timing_summary
from audit_gpu_portable_search import require
from gpu_quadruped_model import FLAGS


GATES = dict(measurement=7, quadruped=10, portable=11, **{
    "host-batch": 7, "graph-execution": 7, "repertoire": 6, "corpus": 3,
    "retrieval": 9, "motor-task": 7, "motor-route": 5, "provider": 2, "containment": 1})
COUNTS = dict(discovery=dict(worlds=90, controller_rows=43200, internal_rows=216000),
              confirmation=dict(worlds=30, controller_rows=14400, internal_rows=72000))


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def finite_summary(discovery, confirmation, comparison):
    roles = {name: dict(eligible=0, negative=0, denominator=0)
             for name in ["baseline", "condition_known", "shared_profile"]}
    failures = []
    for trial in confirmation["trials"]:
        for role, action, episode, metric in zip(trial["role_order"], trial["candidate_indices"],
                                                trial["episodes"], trial["metrics"], strict=True):
            roles[role]["denominator"] += 1
            roles[role]["eligible" if episode["outcome"] == "positive" else "negative"] += 1
            if episode["outcome"] == "negative":
                failures.append(dict(group_id=trial["group_id"], condition_id=trial["condition_id"],
                    role=role, action_index=action, failure_code=episode["failure_code"],
                    minimum_height_m=metric["minimum_height_m"], maximum_tilt_rad=metric["maximum_tilt_rad"],
                    torso_contact_steps=metric["torso_contact_steps"]))
    return dict(discovery_eligible=discovery["eligible_episodes"], discovery_negative=discovery["negative_episodes"],
        discovery_denominator=90, confirmation_eligible=confirmation["eligible_episodes"],
        confirmation_negative=confirmation["negative_episodes"], confirmation_denominator=30,
        confirmation_roles=roles, confirmation_failures=failures,
        finite_conditioning_value=comparison["finite_conditioning_value"],
        healthy_guard_passed=comparison["healthy_guard_passed"],
        oracle_baseline_gain_groups=comparison["oracle_baseline_gain_groups"],
        degraded_group_denominator=comparison["degraded_group_denominator"],
        adaptive_provider_benefit=False, qualification_or_release_authority=False)


def header(record, evidence_root):
    require(record["schema_version"] == "locolemotion_motor_effectiveness_closure_v1"
        and record["status"] == "complete_native_motor_effectiveness_comparison"
        and record["synthetic"] is False and record["training_data_authority"] is True
        and record["training_scope"] == "complete_independently_verified_development_discovery_only"
        and all(record[k] is False for k in [*([k for k in FLAGS if k != "training_data_authority"]),
            "confirmation_training_authority", "provider_promotion_authority", "history_inference",
            "adaptive_provider_benefit", "statistical_superiority_authority", "noninferiority_authority"]),
        "Closure identity/authority")
    require(record["trial_count"] == 20 and record["constructed_gpu_worlds"] == 120
        and record["stepped_cpu_worlds"] == record["evaluation_worlds"] == 0
        and record["controller_rows"] == 57600 and record["internal_rows"] == 288000
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


def verify_record(path, evidence_root, core_path, baseline_path, *, replay=False):
    record = read(path)
    root, attempt, paths = header(record, evidence_root)
    require(sha(Path(__file__)) == record["closure_reader_sha256"], "Closure reader changed")
    for item, target in zip(record["artifacts"], paths, strict=True):
        require(target.stat().st_size == item["byte_length"] and sha(target) == item["sha256"], "Retained artifact changed")
    declared, receipt, consumed = [read(attempt/name) for name in ["declaration.json", "receipt.json", "consumed.json"]]
    c = declaration()
    require(declared["contract"] == receipt["contract"] == c and record["ledger_scope"] == c["ledger_scope"], "Frozen declaration changed")
    require(declared["source_commit"] == receipt["source_commit"] == consumed["source_commit"] == record["source_commit"]
        and consumed["attempt_id"] == record["attempt_id"] and declared["binding"] == receipt["binding"], "Crossed source/attempt")
    require(receipt["ok"] is True and receipt["zero_world_gate_passed"] is True
        and receipt["physical_started"] is True and receipt["synthetic"] is False
        and receipt["safety_controls"] == GATES and sum(GATES.values()) == 75, "Incomplete execution/gate")
    require(declared["planned_worlds"] == receipt["planned_worlds"] == consumed["planned_worlds"]
        == dict(discovery=90, confirmation=30, cpu=0)
        and consumed["discovery_trials"] == trial_plan(c, "discovery")
        and consumed["confirmation_profile_selection"] == "prospective_discovery_selector_only", "Prospective population/selection")
    require(all(receipt[k] is c[k] for k in FLAGS)
        and receipt["training_data_scope"] == "development_discovery_only", "Receipt authority")
    require(sha(core_path) == c["core_sha256"] == record["core_sha256"]
        and sha(baseline_path) == c["baseline_core_sha256"] == record["baseline_core_sha256"], "Core identity")
    bindings = declared["binding"]
    require(verify_frozen_sources(record["source_commit"], bindings["source"]) == record["source_binding_count"], "Source denominator")
    require(len(bindings["runtime"]) == record["runtime_binding_count"], "Runtime denominator")
    for name, digest in bindings["runtime"].items():
        require(sha(Path(name)) == digest, "Runtime bytes changed")
    for name, count in GATES.items():
        log = (attempt/(name+"-gate")/"stderr.log").read_text()
        require(re.findall(r"(?m)^Ran ([0-9]+) tests? in ", log) == [str(count)]
            and log.rstrip().endswith("OK"), "Safety gate terminal/count")
    preflight = read(attempt/"runtime-gate/stdout.log")
    require(preflight == receipt["preflight"] and preflight["ok"] is True
        and preflight["world_build_count"] == preflight["solver_steps"] == preflight["evaluation_worlds"] == 0
        and preflight["planned_gpu_worlds"] == 120 and preflight["discovery_worlds"] == 90
        and preflight["confirmation_worlds"] == 30 and preflight["planned_controller_rows"] == 57600
        and preflight["planned_internal_rows"] == 288000, "Preflight population")
    audits = {phase: read(attempt/(phase+"-audit.json")) for phase in COUNTS}
    selection_record = read(attempt/"selection.json")
    selected = select_profiles(audits["discovery"], c)
    require(selection_record == dict(selection=selected, discovery_audit_sha256=sha(attempt/"discovery-audit.json"))
        and selected == record["selection"]
        and sha(attempt/"selection.json") == receipt["selection_sha256"] == record["selection_sha256"], "Discovery selection changed")
    worker_times, audit_times = {}, {}
    for phase, population in COUNTS.items():
        observed = audits[phase]
        selected_phase = None if phase == "discovery" else selected
        plans = trial_plan(c, phase, selected_phase)
        require(observed["ok"] is True and observed["synthetic"] is False and observed["phase"] == phase
            and observed["reader_world_build_count"] == observed["stepped_cpu_worlds"] == 0
            and observed["constructed_gpu_worlds"] == population["worlds"]
            and observed["controller_rows"] == population["controller_rows"]
            and observed["internal_rows"] == population["internal_rows"]
            and observed["eligible_episodes"] + observed["negative_episodes"] == population["worlds"]
            and len(observed["trials"]) == 10 and len(observed["workers"]) == 5
            and observed["ledger_scope"] == c["ledger_scope"], "Reader population/identity")
        require(all(observed[k] is (phase == "discovery" if k == "training_data_authority" else False) for k in FLAGS)
            and observed["training_data_scope"] == "development_discovery_only", "Reader authority")
        require(observed["eligible_episodes"] == sum(e["outcome"] == "positive" for t in observed["trials"] for e in t["episodes"])
            and observed["negative_episodes"] == sum(e["outcome"] == "negative" for t in observed["trials"] for e in t["episodes"]),
            "Reader outcome denominator")
        require(sha(attempt/(phase+"-audit.json")) == receipt[phase+"_audit_sha256"] == record[phase+"_audit_sha256"], "Original audit binding")
        stdout = read(attempt/(phase+"-reader")/"stdout.log")
        require(stdout == {k: observed[k] for k in ["ok", "phase", "controller_rows", "internal_rows",
            "eligible_episodes", "negative_episodes", "reader_world_build_count"]}, "Reader terminal")
        phase_dir = attempt/"physical"/phase
        require({p.name for p in phase_dir.iterdir() if p.is_dir()} == {r["condition_id"] for r in c["conditions"]}, "Condition population")
        workers = {}
        for condition, checked in zip(c["conditions"], observed["workers"], strict=True):
            cid = condition["condition_id"]
            worker_path = phase_dir/cid/"worker-result.json"
            w = read(worker_path); workers[cid] = w
            require(w["ok"] is True and w["synthetic"] is False and w["phase"] == phase
                and w["condition_id"] == cid and w["status"] == "complete_motor_effectiveness_condition"
                and w["controller_sessions_closed"] is True and w["stepped_cpu_worlds"] == 0
                and w["constructed_gpu_worlds"] == w["cpu_readback_views"] == population["worlds"]//5
                and len(w["trials"]) == 2 and all(w[k] is observed[k] for k in FLAGS), "Worker identity/population")
            require(checked == dict(condition_id=cid, total_wall_s=w["total_wall_s"], worker_result_sha256=sha(worker_path))
                and math.isfinite(w["total_wall_s"]) and w["total_wall_s"] >= 0, "Worker timing binding")
        for plan, checked in zip(plans, observed["trials"], strict=True):
            directory = phase_dir/plan["condition_id"]/plan["trial_id"]
            result = read(directory/"result.json")
            worker = workers[plan["condition_id"]]
            require(read(directory/"plan.json") == plan and all(checked[k] == v and result[k] == v for k, v in plan.items())
                and result in worker["trials"] and result["completed"] is True, "Trial identity")
            require(checked["controller_rows"] == result["outer_rows"] == plan["nworld"]*480
                and checked["internal_rows"] == result["internal_rows"] == plan["nworld"]*2400
                and len(checked["episodes"]) == len(checked["metrics"]) == plan["nworld"], "Trial denominator")
            require(all(sha(directory/(name+".jsonl")) == result["hashes"][name] for name in ["controller", "trace", "timing"]), "Trial raw binding")
            require(timing_summary(list(read_jsonl(directory/"timing.jsonl")), c) == checked["timings"], "Trial timing replay")
        worker_times[phase] = sum(w["total_wall_s"] for w in workers.values())
        audit_times[phase] = receipt[phase+"_audit_wall_s"]
        require(math.isfinite(audit_times[phase]) and audit_times[phase] >= 0, "Audit timing")
        if replay:
            require(audit_phase(phase_dir, core_path, baseline_path, phase, selected_phase) == observed, "Full audit replay differs")
    comparison = compare_confirmation(audits["confirmation"], selected, c)
    require(read(attempt/"comparison.json") == receipt["comparison"] == record["comparison"] == comparison, "Finite comparison changed")
    summary = finite_summary(audits["discovery"], audits["confirmation"], comparison)
    require(record["finite_outcomes"] == summary, "Finite outcome accounting changed")
    require(worker_times == record["native_worker_wall_s"] and audit_times == record["independent_audit_wall_s"], "Closure timing changed")
    return dict(ok=True, artifact_count=len(paths), source_binding_count=record["source_binding_count"],
        runtime_binding_count=record["runtime_binding_count"], original_independent_reader_controller_rows=57600,
        original_independent_reader_internal_rows=288000, constructed_gpu_worlds=120,
        reader_world_build_count=0, full_controller_replay_performed=replay,
        finite_outcomes=summary, training_scope=record["training_scope"],
        confirmation_training_authority=False, qualification_or_release_authority=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record", type=Path, default=Path(__file__).with_name("gpu_motor_effectiveness_closure_v1.json"))
    parser.add_argument("--evidence-root", type=Path, default=ROOT.parent/"SporeSpore_Evidence")
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--replay", action="store_true")
    args = parser.parse_args()
    print(json.dumps(verify_record(args.record, args.evidence_root, args.core, args.baseline_core, replay=args.replay), indent=2))
