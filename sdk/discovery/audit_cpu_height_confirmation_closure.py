"""Verify fixed-candidate duration/nominal confirmation, including failures and quality costs."""
import argparse
import json
import math
from pathlib import Path
import re

from cpu_height_confirmation_task import ROOT, declaration, trial_plan, assess, sha, FLAGS
from run_cpu_body_height_confirmation import GATES as STAGES
from audit_cpu_body_height_confirmation import audit
from adaptation_provider.retrieval import flat_v2 as learner
from motor_effectiveness_task import condition_inputs, expected_actuator_arrays
from body_height_diagnostic import physical_violation, control_activity
from audit_gpu_repertoire_negative_closure import verify_frozen_sources
from audit_gpu_batch_execution import read_jsonl, timing_summary
from audit_gpu_portable_search import require

GATES = dict([(name, count) for name, _, count in STAGES] + [("provider", 2), ("containment", 1)])
AUTHORITY_FLAGS = [*FLAGS, "controller_selection_authority", "adaptive_provider_benefit",
    "statistical_superiority_authority", "noninferiority_authority", "population_inference"]


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def finite_summary(observed):
    return dict(eligible=observed["eligible_episodes"], negative=observed["negative_episodes"], denominator=12,
        trials=[dict(trial_id=t["trial_id"], condition_id=t["condition_id"], start_id=t["start_id"], role=t["role"],
            action_index=t["candidate_indices"][0], outcome=t["episodes"][0]["outcome"],
            failure_code=t["episodes"][0]["failure_code"], native_metrics=t["metrics"][0],
            episode_metrics=t["episodes"][0]["metrics"], eligible_window_count=len(t["episodes"][0]["windows"]),
            pre_violation_activity=t["pre_violation_activity"]) for t in observed["trials"]],
        confirmation=assess(observed["trials"], declaration()),
        training_data_authority=False, controller_selection_authority=False, adaptation_benefit=False,
        population_inference=False, qualification_or_release_authority=False)


def header(record, evidence_root):
    require(record["schema_version"] == "locolemotion_cpu_body_height_confirmation_closure_v1"
        and record["status"] == "complete_native_cpu_body_height_confirmation"
        and record["synthetic"] is False and all(record[k] is False for k in AUTHORITY_FLAGS)
        and record["training_data_scope"] == "development_confirmation_no_fitting"
        and record["confirmation_scope"] == "exposed_fixed_candidate_duration_and_nominal", "Closure identity/authority")
    require(record["trial_count"] == record["constructed_cpu_worlds"] == 12
        and record["constructed_gpu_worlds"] == record["evaluation_worlds"] == 0
        and record["controller_rows"] == 17280 and record["internal_rows"] == 86400
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
    require(record["artifact_bytes"] == sum(e["byte_length"] for e in entries), "Artifact byte denominator")
    return root, attempt, paths


def verify_record(path, evidence_root, core, baseline, *, replay=False):
    record = read(path)
    _, attempt, paths = header(record, evidence_root)
    require(record["closure_reader_sha256"] == sha(Path(__file__)), "Closure reader changed")
    for item, target in zip(record["artifacts"], paths, strict=True):
        require(target.stat().st_size == item["byte_length"] and sha(target) == item["sha256"], "Retained artifact changed")
    declared, receipt, consumed = [read(attempt/name) for name in ["declaration.json", "receipt.json", "consumed.json"]]
    c = declaration(); plans = trial_plan(c)
    require(declared["contract"] == receipt["contract"] == c
        and declared["ledger_scope"] == receipt["ledger_scope"] == record["ledger_scope"] == c["ledger_scope"], "Frozen declaration changed")
    require(declared["source_commit"] == receipt["source_commit"] == consumed["source_commit"] == record["source_commit"]
        and consumed["attempt_id"] == record["attempt_id"] and declared["binding"] == receipt["binding"], "Crossed source/attempt")
    require(sha(attempt/"receipt.json") == record["receipt_sha256"], "Original receipt binding")
    require(receipt["ok"] is True and receipt["zero_world_gate_passed"] is True and receipt["physical_started"] is True
        and receipt["synthetic"] is False and receipt["safety_controls"] == GATES and sum(GATES.values()) == 169, "Incomplete execution/gate")
    require(declared["planned_worlds"] == receipt["planned_worlds"] == consumed["planned_worlds"] == dict(gpu=0, cpu=12)
        and declared["planned_trials"] == receipt["planned_trials"] == consumed["planned_trials"] == plans, "Prospective population")
    require(all(receipt[k] is c[k] for k in FLAGS) and receipt["training_data_scope"] == "development_confirmation_no_fitting", "Receipt authority")
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
        planned_cpu_worlds=12, planned_gpu_worlds=0, planned_controller_rows=17280,
        planned_internal_rows=86400, evaluation_worlds=0), "Preflight population")
    observed = read(attempt/"independent-audit.json")
    require(sha(attempt/"independent-audit.json") == receipt["audit_sha256"] == record["audit_sha256"], "Original audit binding")
    require(observed["ok"] is True and observed["synthetic"] is False
        and observed["reader_world_build_count"] == observed["constructed_gpu_worlds"] == 0
        and observed["constructed_cpu_worlds"] == 12 and observed["controller_rows"] == 17280
        and observed["internal_rows"] == 86400 and len(observed["trials"]) == 12
        and observed["ledger_scope"] == c["ledger_scope"] and all(observed[k] is c[k] for k in FLAGS)
        and observed["training_data_scope"] == "development_confirmation_no_fitting"
        and observed["population_inference"] is False and observed["controller_selection_authority"] is False, "Reader population/authority")
    require(read(attempt/"independent-reader/stdout.log") == {k: observed[k] for k in ["ok", "controller_rows",
        "internal_rows", "eligible_episodes", "negative_episodes", "reader_world_build_count"]}, "Reader terminal")
    physical = attempt/"physical"
    worker = read(physical/"worker-result.json")
    require(worker["ok"] is True and worker["controller_sessions_closed"] is True and worker["synthetic"] is False
        and worker["status"] == record["status"] and worker["ledger_scope"] == c["ledger_scope"]
        and worker["constructed_cpu_worlds"] == 12 and worker["constructed_gpu_worlds"] == 0
        and len(worker["trials"]) == 12 and all(worker[k] is c[k] for k in FLAGS), "Worker status/population")
    require({p.name for p in (physical/"models").iterdir() if p.is_dir()} == set(c["challenge"]["conditions"]), "Condition model population")
    for condition in c["challenge"]["conditions"]:
        directory=physical/"models"/condition
        compiled,xml,spec=condition_inputs(core,c,condition)
        require((directory/"model.xml").read_text() == xml
            and sha(directory/"model.xml") == c["condition_model_sha256"][condition], "Condition XML binding")
        require(read(directory/"compiled.json") == compiled and read(directory/"inputs.json") == spec, "Condition input binding")
        metadata=read(directory/"native-model.json")
        require(all(metadata[name+"_sha256"] == sha(directory/(name+(".xml" if name == "model" else ".json")))
            for name in ["model","compiled","inputs"]), "Condition native input digest")
        require(metadata["condition_id"] == condition and metadata["actuator_profile"] == expected_actuator_arrays(spec)
            and metadata["force_ranges"] == spec["force_ranges"] and metadata["dynamics_dtype"] == "float64"
            and metadata["initial_values"] == c["challenge"]["initial_values"]
            and metadata["observation_stage"] == "prepared_before_control"
            and metadata["force_stage"] == "completed_step_before_next_prepare", "Condition native profile")
    expected_log = []
    for plan in plans:
        expected_log.extend(dict(trial=plan["trial_id"], outer_step=step) for step in range(0, 1440, 120))
        expected_log.append(dict(trial=plan["trial_id"], complete=True, outer_rows=1440))
    require(list(read_jsonl(physical/"stdout.log")) == expected_log, "Worker progress/terminal")
    for plan, checked, saved in zip(plans, observed["trials"], worker["trials"], strict=True):
        directory = physical/plan["trial_id"]
        result = read(directory/"result.json")
        require(read(directory/"plan.json") == plan and all(checked[k] == v and result[k] == v for k,v in plan.items())
            and result == saved and result["completed"] is True, "Trial identity")
        require(checked["controller_rows"] == result["outer_rows"] == 1440
            and checked["internal_rows"] == result["internal_rows"] == 7200
            and len(checked["episodes"]) == len(checked["metrics"]) == 1, "Trial denominator")
        require(all(sha(directory/(name+".jsonl")) == result["hashes"][name]
            for name in ["controller", "trace", "timing"]), "Trial raw binding")
        require(timing_summary(list(read_jsonl(directory/"timing.jsonl")), c) == checked["timings"], "Timing replay")
        metric, episode = checked["metrics"][0], checked["episodes"][0]
        failures = [name for name, failed in [
            ("height", metric["minimum_height_m"] < c["selection"]["minimum_height_m"]),
            ("tilt", metric["maximum_tilt_rad"] > c["selection"]["maximum_tilt_rad"]),
            ("torso_contact", metric["torso_contact_steps"] > c["selection"]["maximum_torso_contact_steps"]),
            ("safe_no_actuation", metric["safe_no_actuation_steps"] > 0)] if failed]
        if failures:
            require(episode["outcome"] == "negative" and episode["failure_code"] == ";".join(failures)
                and episode["windows"] == [] and episode["metrics"]["quality_m_s"] is None, "Failed episode interpretation changed")
        else:
            windows = episode["windows"]; lp = learner.contract()
            require(episode["outcome"] == "positive" and episode["failure_code"] is None
                and [w["start_step"] for w in windows] == list(range(0, c["outer_steps"], lp["decision_window_steps"]))
                and len(windows) == 48, "Eligible window denominator")
            for window in windows:
                quality = learner.quality(window["start_position_xz_m"], window["end_position_xz_m"],
                    lp["decision_window_steps"]*lp["controller_dt_s"], lp)
                require(math.isfinite(quality) and quality == window["quality_m_s"], "Eligible tracking quality changed")
            require(episode["metrics"]["quality_m_s"] == sum(w["quality_m_s"] for w in windows)/len(windows), "Eligible mean quality changed")
        first = None
        for row in read_jsonl(directory/"trace.jsonl"):
            first = physical_violation(row, c["selection"])
            if first is not None: break
        require(first == metric["first_physical_violation"], "First physical violation changed")
        require(control_activity(read_jsonl(directory/"controller.jsonl"), first) == checked["pre_violation_activity"], "Prospective activity changed")
    eligible=sum(t["episodes"][0]["outcome"] == "positive" for t in observed["trials"])
    require(observed["eligible_episodes"] == eligible == 9
        and observed["negative_episodes"] == 12-eligible == 3, "Outcome denominator")
    summary = finite_summary(observed)
    require(summary == record["finite_outcomes"] and summary["confirmation"] == observed["confirmation"], "Finite confirmation changed")
    confirmation=summary["confirmation"]
    require(confirmation["selected_candidate_index"] == 2 and confirmation["selection_changed"] is False
        and confirmation["pair_count"] == 8 and confirmation["nominal_quality_at_least_baseline_on_both"] is False,
        "Fixed selection, contrast population or nominal cost changed")
    require(record["comparison_reader_sha256"] == sha(Path(__file__).with_name("cpu_height_confirmation_task.py")), "Comparison reader changed")
    require(record["native_worker_wall_s"] == observed["native_worker_wall_s"] == worker["total_wall_s"]
        and record["independent_audit_wall_s"] == receipt["audit_wall_s"], "Closure timing changed")
    if replay:
        require(audit(physical, core, baseline) == observed, "Full independent replay differs")
    return dict(ok=True, artifact_count=len(paths), artifact_bytes=record["artifact_bytes"],
        source_binding_count=record["source_binding_count"], runtime_binding_count=record["runtime_binding_count"],
        original_independent_reader_controller_rows=17280, original_independent_reader_internal_rows=86400,
        reader_world_build_count=0, full_controller_replay_performed=replay,
        finite_outcomes=summary, training_data_authority=False, controller_selection_authority=False,
        qualification_or_release_authority=False)


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--record", type=Path, default=Path(__file__).with_name("cpu_body_height_confirmation_closure_v1.json"))
    p.add_argument("--evidence-root", type=Path, default=ROOT.parent/"SporeSpore_Evidence")
    p.add_argument("--core", type=Path, required=True)
    p.add_argument("--baseline-core", type=Path, required=True)
    p.add_argument("--replay", action="store_true")
    a = p.parse_args()
    print(json.dumps(verify_record(a.record, a.evidence_root, a.core, a.baseline_core, replay=a.replay), indent=2))
