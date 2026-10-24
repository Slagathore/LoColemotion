"""Verify all forty-eight committed-feedback trials and the finite healthy-body screen."""
import argparse
import json
import math
from pathlib import Path
import re

from cpu_committed_feedback_task import ROOT, declaration, trial_plan, assess, sha, FLAGS
from run_cpu_committed_feedback import GATES as STAGES
from audit_cpu_committed_feedback import audit, influence
from committed_feedback_control import ROLES
from adaptation_provider.retrieval import flat_v2 as learner
from motor_effectiveness_task import condition_inputs, expected_actuator_arrays
from body_height_diagnostic import physical_violation
from audit_gpu_repertoire_negative_closure import verify_frozen_sources
from audit_gpu_batch_execution import read_jsonl, timing_summary, same_bits
from adaptation_provider.retrieval.first_response_features_v1 import features as context_features, STEPS as PROBE_STEPS
from portable_search_control import bridge
from itertools import islice
from audit_gpu_portable_search import require

GATES = dict([(name, count) for name, _, count in STAGES] + [("provider", 2), ("containment", 1)])
AUTHORITY_FLAGS = [*FLAGS, "controller_selection_authority", "adaptive_provider_benefit",
    "statistical_superiority_authority", "noninferiority_authority", "population_inference"]


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def finite_summary(observed):
    return dict(eligible=observed["eligible_episodes"], negative=observed["negative_episodes"], denominator=48,
        trials=[dict(trial_id=t["trial_id"], condition_id=t["condition_id"], start_id=t["start_id"], role=t["role"],
            selection_role_index=t["selection_role_index"], fixed_candidate_index=t["fixed_candidate_index"],
            action_sequence_kind=t["action_sequence_kind"], ordered_actions_sha256=t["episodes"][0]["ordered_actions_sha256"],
            outcome=t["episodes"][0]["outcome"], failure_code=t["episodes"][0]["failure_code"],
            native_metrics=t["metrics"][0], episode_metrics=t["episodes"][0]["metrics"],
            eligible_window_count=len(t["episodes"][0]["windows"]), influence=t["influence"]) for t in observed["trials"]],
        repertoire=assess(observed["trials"], declaration()), groups=observed["groups"],
        training_data_authority=True, controller_selection_authority=True, adaptation_benefit=False,
        population_inference=False, qualification_or_release_authority=False)


def verify_episode(checked, c):
    """Keep physical failures censored and recompute every eligible quality window."""
    metric, episode = checked["metrics"][0], checked["episodes"][0]
    require(episode["schema_version"] == "locolemotion_dynamic_policy_episode_v1"
        and episode["policy_role_id"] == checked["role"] and "action_id" not in episode
        and "candidate_indices" not in checked, "Dynamic policy episode identity")
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


def verify_finite_outcomes(record, observed, c):
    """Recompute the frozen screen without promoting censored failures."""
    eligible = sum(t["episodes"][0]["outcome"] == "positive" for t in observed["trials"])
    require(len(observed["trials"]) == 48 and observed["eligible_episodes"] == eligible
        and observed["negative_episodes"] == 48-eligible, "Outcome denominator")
    summary = finite_summary(observed)
    require(summary == record["finite_outcomes"] and summary["repertoire"] == observed["repertoire"],
        "Finite training selection changed")
    selection = summary["repertoire"]
    require(len(selection["roles"]) == 6 and len(selection["contrasts"]) == 56,
        "Complete conditioned role/contrast denominator")
    require(all(contrast["quality_difference_m_s"] is None
        for contrast in selection["contrasts"] if not contrast["both_eligible"]),
        "Failed paired contrasts must remain censored")
    for role in selection["roles"]:
        require(role["denominator"] == 8 and len(role["nominal_preservation"]) == 4,
            "Complete condition/start preservation denominator")
        for preserved in role["nominal_preservation"]:
            rows = {t["role"]:t["episodes"][0] for t in observed["trials"]
                if t["condition_id"] == "nominal" and t["start_id"] == preserved["start_id"]}
            left, right = rows[role["role_id"]], rows["baseline"]
            both = left["outcome"] == right["outcome"] == "positive"
            difference = left["metrics"]["quality_m_s"]-right["metrics"]["quality_m_s"] if both else None
            require(preserved["both_eligible"] is both and preserved["quality_difference_m_s"] == difference
                and preserved["observed_quality_preserved"] is bool(both and
                    difference >= -c["challenge"]["nominal_quality_loss_margin_m_s"]),
                "Nominal preservation interpretation changed")
        require(role["nominal_observed_quality_preserved"] is
            all(p["observed_quality_preserved"] for p in role["nominal_preservation"])
            and role["selection_eligible"] is
            (role["complete_eligible_group"] and role["nominal_observed_quality_preserved"]),
            "Conditioned preservation screen changed")
    return summary


def verify_prefix(directory, checked, core):
    """Rejoin the one-command feature to actual observations and issued commands."""
    rows=list(islice(read_jsonl(directory/"controller.jsonl"), PROBE_STEPS+1))
    require(len(rows) == PROBE_STEPS+1, "Incomplete causal prefix")
    request=rows[PROBE_STEPS]["resolution_request"]["provider_request"]
    entries=request["history"]["ordered_entries"]
    require(len(entries) == PROBE_STEPS, "Causal prefix entry denominator")
    for step,(entry,row) in enumerate(zip(entries,rows[:PROBE_STEPS],strict=True)):
        actual=row["resolution"]; original=row["resolution_request"]["provider_request"]
        require(row["outer_step"] == step and entry["semantic_step"] == step
            and entry["state"] == original["state"] == row["request"]["state"]
            and entry["command"] == original["command"] == row["request"]["command"]
            and entry["deterministic_baseline"] == original["deterministic_baseline"]
            and entry["provider_status"] == actual["provider_status"] == "no_proposal"
            and entry["adaptation_applied"] is actual["adaptation_applied"] is False,
            "Causal prefix state/action/status join changed")
        require(entry["request_sha256"] == actual["request_sha256"]
            and entry["resolution_receipt_sha256"] == learner.digest(core,actual)
            and entry["ordered_applied_corrections"] == [dict(actuator_id=r["actuator_id"],
                canonical_velocity_delta_rad_s=r["applied_correction_rad_s"]) for r in actual["ordered_commands"]],
            "Causal prefix original receipt join changed")
    features=context_features(request)
    require(same_bits(features,checked["probe_features"]), "Causal feature values changed")
    if checked["role"] != "baseline":
        row=rows[PROBE_STEPS]; response=row["resolution_request"]["provider_response"]
        require(response is not None and row["selection"]["provider_error"] is None
            and same_bits(response["next_memory"]["opaque_state"]["context"]["feature"], features),
            "First-response private memory join changed")
    return features


def verify_actions(rows, checked, result, c, core):
    """Keep a dynamic policy's exact action sequence distinct from fixed experts."""
    require(len(rows) == c["outer_steps"] and all(r["outer_step"] == i and r["cell"] == 0
        for i,r in enumerate(rows)), "Dynamic action sequence denominator")
    for row in rows:
        require(row["selection"]["role"] == ROLES[checked["selection_role_index"]], "Committed selection role changed")
        response = row["resolution_request"]["provider_response"]
        if response is not None:
            require(same_bits(response["next_memory"], row["resolution"]["next_memory"]),
                "Committed comparison resolver memory join changed")
    sequence=[dict(step=i,selection=r["selection"],ordered_commands=r["resolution"]["ordered_commands"])
        for i,r in enumerate(rows)]
    sequence_sha=learner.digest(core,sequence)
    episode=checked["episodes"][0]; first=rows[0]["resolution_request"]
    raw=dict(group_id=checked["group_id"], condition_id=checked["condition_id"], partition=checked["partition"],
        policy_role_id=checked["role"], fixed_candidate_index=checked["fixed_candidate_index"],
        ordered_actions_sha256=sequence_sha, cell=0, seed=checked["seed"], hashes=result["hashes"],
        provider_request_sha256=learner.digest(core,first["provider_request"]),
        provider_response_sha256=learner.digest(core,first["provider_response"]),
        resolution_receipt_sha256=learner.digest(core,rows[0]["resolution"]), descriptor_sha256=c["descriptor_sha256"],
        expected_outer_rows=c["outer_steps"], expected_internal_rows=c["outer_steps"]*5)
    require(episode["ordered_actions_sha256"] == sequence_sha and checked["raw_bindings"] == [raw]
        and episode["raw_episode_sha256"] == learner.digest(core,raw), "Dynamic action/raw sequence binding changed")
    require(influence(rows) == checked["influence"], "Actual selection influence changed")


def header(record, evidence_root):
    require(record["schema_version"] == "locolemotion_cpu_committed_feedback_closure_v1"
        and record["status"] == "complete_native_cpu_committed_feedback"
        and record["synthetic"] is False and all(record[k] is (k in {"training_data_authority", "controller_selection_authority"}) for k in AUTHORITY_FLAGS)
        and record["training_data_scope"] == "development_committed_feedback_discovery_only"
        and record["discovery_scope"] == "exposed_committed_feedback_training_groups_only", "Closure identity/authority")
    require(record["trial_count"] == record["constructed_cpu_worlds"] == 48
        and record["constructed_gpu_worlds"] == record["evaluation_worlds"] == record["calibration_worlds"] == 0
        and record["controller_rows"] == 69120 and record["internal_rows"] == 345600
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


READER_PATHS = [
    "sdk/discovery/audit_cpu_committed_feedback_closure.py",
    "sdk/discovery/cpu_committed_feedback_task.py", "sdk/discovery/cpu_committed_feedback_v1.json",
    "sdk/discovery/run_cpu_committed_feedback.py", "sdk/discovery/audit_cpu_committed_feedback.py",
    "sdk/discovery/audit_committed_feedback.py", "sdk/discovery/committed_feedback_control.py",
    "sdk/adaptation_provider/retrieval/committed_feedback_v1.py",
    "sdk/adaptation_provider/retrieval/committed_feedback_v1.json",
    "sdk/discovery/audit_conditioned_feedback.py", "sdk/discovery/conditioned_feedback_control.py",
    "sdk/discovery/conditioned_feedback_dense_control.py", "sdk/discovery/audit_gpu_batch_execution.py",
    "sdk/discovery/audit_gpu_repertoire_negative_closure.py", "sdk/discovery/body_height_diagnostic.py",
    "sdk/discovery/motor_effectiveness_task.py", "sdk/discovery/portable_search_control.py",
    "sdk/adaptation_provider/retrieval/first_response_features_v1.py",
    "sdk/adaptation_provider/retrieval/conditioned_feedback_v1.py",
    "sdk/adaptation_provider/retrieval/conditioned_feedback_v1.json",
    "sdk/adaptation_provider/retrieval/conditioned_feedback_v2.py",
    "sdk/adaptation_provider/retrieval/conditioned_feedback_v2.json",
    "sdk/adaptation_provider/retrieval/feedback_dense_v1.py",
    "sdk/adaptation_provider/retrieval/feedback_dense_contract_v1.json",
    "sdk/adaptation_provider/retrieval/flat_v2.py", "sdk/adaptation_provider/retrieval/causal_history_v1.py",
    "sdk/discovery/command_resolution_repertoire_closure_v1.json"]


def verify_current_readers(record):
    """Refuse changed executable closure dependencies before scanning streams."""
    require(set(record["reader_bindings"]) == set(READER_PATHS), "Closure reader binding population")
    for name,digest in record["reader_bindings"].items():
        require(digest == sha(ROOT/name), "Closure reader dependency changed: "+name)


def verify_record(path, evidence_root, core, baseline, *, replay=False):
    record = read(path)
    _, attempt, paths = header(record, evidence_root)
    verify_current_readers(record)
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
        and receipt["synthetic"] is False and receipt["safety_controls"] == GATES and sum(GATES.values()) == 388, "Incomplete execution/gate")
    require(declared["planned_worlds"] == receipt["planned_worlds"] == consumed["planned_worlds"] == dict(gpu=0, cpu=48)
        and declared["planned_trials"] == receipt["planned_trials"] == consumed["planned_trials"] == plans, "Prospective population")
    require(all(receipt[k] is c[k] for k in FLAGS) and receipt["training_data_scope"] == "development_committed_feedback_discovery_only", "Receipt authority")
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
        planned_cpu_worlds=48, planned_gpu_worlds=0, planned_controller_rows=69120,
        planned_internal_rows=345600, evaluation_worlds=0), "Preflight population")
    observed = read(attempt/"independent-audit.json")
    require(sha(attempt/"independent-audit.json") == receipt["audit_sha256"] == record["audit_sha256"], "Original audit binding")
    require(observed["ok"] is True and observed["synthetic"] is False
        and observed["reader_world_build_count"] == observed["constructed_gpu_worlds"] == 0
        and observed["constructed_cpu_worlds"] == 48 and observed["controller_rows"] == 69120
        and observed["internal_rows"] == 345600 and len(observed["trials"]) == 48
        and observed["ledger_scope"] == c["ledger_scope"] and all(observed[k] is c[k] for k in FLAGS)
        and observed["training_data_scope"] == "development_committed_feedback_discovery_only"
        and observed["population_inference"] is False and observed["controller_selection_authority"] is True, "Reader population/authority")
    require(read(attempt/"independent-reader/stdout.log") == {k: observed[k] for k in ["ok", "controller_rows",
        "internal_rows", "eligible_episodes", "negative_episodes", "reader_world_build_count"]}, "Reader terminal")
    physical = attempt/"physical"
    worker = read(physical/"worker-result.json")
    require(worker["ok"] is True and worker["controller_sessions_closed"] is True and worker["synthetic"] is False
        and worker["status"] == record["status"] and worker["ledger_scope"] == c["ledger_scope"]
        and worker["constructed_cpu_worlds"] == 48 and worker["constructed_gpu_worlds"] == 0
        and len(worker["trials"]) == 48 and all(worker[k] is False for k in FLAGS), "Worker status/population")
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
    probes={};oracle=bridge.LocomotionCore(baseline)
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
        verify_episode(checked, c)
        first = None
        for row in read_jsonl(directory/"trace.jsonl"):
            first = physical_violation(row, c["selection"])
            if first is not None: break
        require(first == metric["first_physical_violation"], "First physical violation changed")
        verify_actions(list(read_jsonl(directory/"controller.jsonl")), checked, result, c, oracle)
        probes[plan["trial_id"]]=verify_prefix(directory,checked,oracle)
    summary = verify_finite_outcomes(record, observed, c)
    groups=[]
    for group_id in dict.fromkeys(p["group_id"] for p in plans):
        rows=[t for t in observed["trials"] if t["group_id"] == group_id]
        require(len(rows) == 6 and [t["selection_role_index"] for t in rows] == list(range(6)), "Matched selection role group")
        features=[probes[t["trial_id"]] for t in rows]
        require(features[0] is not None and all(same_bits(features[0],f) for f in features[1:]), "Matched baseline prefix changed")
        groups.append(dict(group_id=group_id,condition_id=rows[0]["condition_id"],partition="training",features=features[0],
            matching_baseline_prefixes=6,all_roles_have_baseline_prefix=True))
    require(len(groups) == 8 and same_bits(groups,observed["groups"]), "Matched causal training group/feature join changed")
    require(record["native_worker_wall_s"] == observed["native_worker_wall_s"] == worker["total_wall_s"]
        and record["independent_audit_wall_s"] == receipt["audit_wall_s"], "Closure timing changed")
    if replay:
        require(audit(physical, core, baseline) == observed, "Full independent replay differs")
    return dict(ok=True, artifact_count=len(paths), artifact_bytes=record["artifact_bytes"],
        source_binding_count=record["source_binding_count"], runtime_binding_count=record["runtime_binding_count"],
        original_independent_reader_controller_rows=69120, original_independent_reader_internal_rows=345600,
        reader_world_build_count=0, full_controller_replay_performed=replay,
        finite_outcomes=summary, training_data_authority=True, controller_selection_authority=True,
        qualification_or_release_authority=False)


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--record", type=Path, default=Path(__file__).with_name("cpu_committed_feedback_closure_v1.json"))
    p.add_argument("--evidence-root", type=Path, default=ROOT.parent/"SporeSpore_Evidence")
    p.add_argument("--core", type=Path, required=True)
    p.add_argument("--baseline-core", type=Path, required=True)
    p.add_argument("--replay", action="store_true")
    a = p.parse_args()
    print(json.dumps(verify_record(a.record, a.evidence_root, a.core, a.baseline_core, replay=a.replay), indent=2))
