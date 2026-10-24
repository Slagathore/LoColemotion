"""Post-hoc switching, case-support and outcome-window audit of all forty trials.

A prediction describes a fixed training expert's short window. A mixed runtime
trajectory is not that expert's counterfactual outcome. Failed episodes retain
null official quality; pre-failure window diagnostics never relabel them.
"""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path

from audit_cpu_conditioned_feedback_closure import verify_record as verify_parent
from audit_cpu_conditioned_feedback_closure import read, declaration, trial_plan, physical_violation, learner
from audit_gpu_batch_execution import read_jsonl
from cpu_conditioned_feedback_task import ROOT, require

PARENT = ROOT/"sdk/discovery/cpu_conditioned_feedback_closure_v1.json"
PARENT_SHA = "9727d866d7f1ca81f18c12b2b568e6918cb0be24ad40d0bc8c045bb63246e6c9"
WINDOW = 30
DT = 1/120
SUBSTEPS = 5
AUTHORITY = dict(training_data_authority=False, selection_authority=False,
    causal_authority=False, counterfactual_performance_authority=False,
    recoverability_authority=False, physical_acceptance_authority=False,
    release_authority=False, population_inference=False)
RULES = dict(post_hoc=True, all_roles_and_starts_retained=True,
    pre_failure_command="all five substeps strictly precede the first recorded physical violation",
    diagnostic_window_commands=WINDOW,
    diagnostic_window="starts before first violation; quality only if its complete future strictly precedes that violation",
    right_censoring="fewer than thirty future commands remain",
    mixed_window="proposed expert changes or withdraws within the thirty held commands",
    prediction="prediction associated with the proposed expert, not the shuffled logical label",
    uninfluenced_proposals="disabled or rejected proposals are counted separately and receive no prediction-error score",
    short_window_quality_is_official_failed_episode_quality=False,
    predicted_quality_is_survival_probability=False,
    action_switches_establish_causation=False)


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def check_population(parent):
    c = declaration()
    rows = parent["finite_outcomes"]["trials"]
    plans = trial_plan(c)
    require(len(rows) == len(plans) == 40 and
        all(all(row[k] == plan[k] for k in ["trial_id", "condition_id", "start_id", "role", "selection_role_index"])
            for row, plan in zip(rows, plans, strict=True)), "Selection diagnostic complete population")
    require((parent["finite_outcomes"]["eligible"], parent["finite_outcomes"]["negative"]) == (26, 14)
        and sum(t["outcome"] == "positive" for t in rows) == 26
        and all(t["episode_metrics"]["quality_m_s"] is None for t in rows if t["outcome"] == "negative")
        and parent["finite_outcomes"]["repertoire"]["ranked_role_indices"] == [],
        "Selection diagnostic original outcomes/authority")
    return rows, c


def describe(row, role, step):
    require(row["outer_step"] == step and row["backend"] == "cpu" and row["cell"] == 0
        and row["request"]["state"]["semantic_step"] == step
        and row["request"]["state"]["sample_time_s"] == step*DT,
        "Selection diagnostic controller order/clock")
    require(row["selection"]["role"]["id"] == role, "Selection diagnostic crossed role")
    state = row["request"]["state"]
    require(state == row["resolution_request"]["provider_request"]["state"],
        "Selection diagnostic provider state join")
    native = row["native_observation"]
    position = state["base_pose_world"]["position_m"]
    require([position["x"], position["y"], position["z"]] ==
        [native["qpos"][0], native["qpos"][2], -native["qpos"][1]],
        "Selection diagnostic canonical position")
    commands = row["resolution"]["ordered_commands"]
    require(len(commands) == 8, "Selection diagnostic actuator denominator")
    correction = [item["applied_correction_rad_s"] for item in commands]
    require(all(type(v) in (int, float) and math.isfinite(v) for v in correction),
        "Selection diagnostic finite corrections")
    decision = row["selection"]["decision"]
    if decision is None:
        require(role in ["baseline", "phase_reference"], "Selection diagnostic missing decision")
        proposed, logical = (0 if role == "baseline" else 2), None
        reason, predictions, query = "fixed_"+role, {}, None
    else:
        require(role in ["disabled", "frozen", "shuffled"] and decision["mode"] == role
            and decision["step"] == step, "Selection diagnostic decision identity")
        proposed, logical = decision["proposed_action_index"], decision["logical_action_index"]
        reason, query = decision["selection_reason"], decision["query"]
        predictions = {p["action_index"]: p for p in decision["predictions"]}
        require(len(predictions) == len(decision["predictions"]), "Selection diagnostic duplicate prediction")
        require((proposed is None and logical is None) or
            (type(logical) is int and logical in range(3) and
             proposed == ([0, 2, 1][logical] if role == "shuffled" else logical)),
            "Selection diagnostic shuffled association")
    require(role != "disabled" or not any(correction), "Selection diagnostic disabled influence")
    predicted = predictions.get(proposed)
    if predicted is not None:
        require(math.isfinite(predicted["quality_m_s"]) and math.isfinite(predicted["support_distance"])
            and 0 <= predicted["support_distance"] <= 1.5, "Selection diagnostic prediction domain")
    contacts = state["ordered_contact_observations"]
    require(len(contacts) == 4 and all(c["normal_load_n"] is None for c in contacts),
        "Selection diagnostic contact availability")
    return dict(step=step, position=[position["x"], position["z"]],
        native_qpos=native["qpos"], native_qvel=native["qvel"], targets=row["native_targets"],
        proposed=proposed, logical=logical, reason=reason,
        proposal_applied=role in ["frozen", "shuffled"] and row["resolution"]["provider_status"] == "applied",
        support_count=sum(c["presence"] and c["bears_support"] for c in contacts),
        nonzero=any(correction), correction=correction,
        slew_clamps=sum(c["slew_clamped"] for c in commands),
        absolute_clamps=sum(c["absolute_correction_clamped"] for c in commands),
        speed_clamps=sum(c["final_speed_clamped"] for c in commands),
        prediction=None if predicted is None else predicted["quality_m_s"],
        support_distance=None if predicted is None else predicted["support_distance"],
        query_phase=None if query is None else query["phase"])


def summarize_frames(frames):
    transitions = Counter()
    switches = []
    jumps = []
    for before, after in zip(frames, frames[1:]):
        if before["proposed"] != after["proposed"]:
            transitions[str(before["proposed"])+"->"+str(after["proposed"])] += 1
        if before["proposed"] in [1, 2] and after["proposed"] in [1, 2] and before["proposed"] != after["proposed"]:
            switches.append(after["step"])
            jumps.append(sum(abs(b-a) for a, b in zip(before["correction"], after["correction"], strict=True)))
    actions = Counter(str(f["proposed"]) for f in frames)
    reasons = Counter(f["reason"] for f in frames)
    return dict(commands=len(frames), proposed_expert_counts=dict(sorted(actions.items())),
        reasons=dict(sorted(reasons.items())), direct_expert_switches=len(switches),
        first_expert_switch_step=switches[0] if switches else None,
        mean_switch_applied_correction_l1_rad_s=sum(jumps)/len(jumps) if jumps else None,
        transitions=dict(sorted(transitions.items())),
        correction_nonzero_commands=sum(f["nonzero"] for f in frames),
        slew_clamped_actuator_commands=sum(f["slew_clamps"] for f in frames),
        absolute_clamped_actuator_commands=sum(f["absolute_clamps"] for f in frames),
        speed_clamped_actuator_commands=sum(f["speed_clamps"] for f in frames),
        support_count_histogram={str(n): sum(f["support_count"] == n for f in frames) for n in range(5)})


def summarize_windows(frames, final_position, first_internal_step, plan):
    """Describe actual windows without assigning their outcome to a fixed expert."""
    counts = Counter()
    errors = {"constant_proposal": [], "mixed_or_withdrawn": []}
    support = []
    for start, frame in enumerate(frames):
        if frame["prediction"] is None or frame["proposed"] not in [1, 2]:
            continue
        counts["predicted_correction_starts"] += 1
        if not frame["proposal_applied"]:
            counts["proposal_not_applied"] += 1
            continue
        if first_internal_step is not None and start*SUBSTEPS >= first_internal_step:
            counts["starts_after_first_violation"] += 1
            continue
        if start+WINDOW > len(frames):
            counts["right_censored"] += 1
            continue
        if first_internal_step is not None and (start+WINDOW)*SUBSTEPS >= first_internal_step:
            counts["crosses_first_violation"] += 1
            continue
        future = frames[start:start+WINDOW]
        label = "constant_proposal" if all(f["proposed"] == frame["proposed"] and f["proposal_applied"] for f in future) else "mixed_or_withdrawn"
        end = frames[start+WINDOW]["position"] if start+WINDOW < len(frames) else final_position
        actual = learner.quality(frame["position"], end, WINDOW*DT, plan)
        errors[label].append(frame["prediction"]-actual)
        support.append(frame["support_distance"])
        counts["complete_pre_failure_windows"] += 1
    result = dict(counts={k: counts[k] for k in ["predicted_correction_starts",
        "proposal_not_applied", "starts_after_first_violation", "right_censored", "crosses_first_violation", "complete_pre_failure_windows"]})
    require(sum(result["counts"][k] for k in result["counts"] if k != "predicted_correction_starts") ==
        result["counts"]["predicted_correction_starts"], "Selection diagnostic window denominator")
    result["prediction_minus_actual_window_quality_m_s"] = {
        label: dict(count=len(values), mean=sum(values)/len(values) if values else None,
            mean_absolute=sum(abs(v) for v in values)/len(values) if values else None,
            optimistic_count=sum(v > 0 for v in values))
        for label, values in errors.items()}
    result["maximum_used_support_distance"] = max(support) if support else None
    return result


def analyze_trial(directory, trial, selection, plan):
    result = read(directory/"result.json")
    require(result["trial_id"] == trial["trial_id"] and result["completed"] is True,
        "Selection diagnostic trial identity")
    for name in ["controller", "trace"]:
        require(sha(directory/(name+".jsonl")) == result["hashes"][name],
            "Selection diagnostic original raw bytes changed")
    frames = [describe(row, trial["role"], i) for i, row in enumerate(read_jsonl(directory/"controller.jsonl"))]
    require(len(frames) == result["outer_rows"] == 1440, "Selection diagnostic controller denominator")
    first, previous, final_position, trace_count = None, None, None, 0
    for index, sample in enumerate(read_jsonl(directory/"trace.jsonl"), 1):
        require(index <= 7200 and sample["step"] == index and sample["cell"] == 0 and sample["backend"] == "cpu",
            "Selection diagnostic internal order")
        outer = (index-1)//SUBSTEPS
        frame = frames[outer]
        require(sample["ctrl"] == frame["targets"], "Selection diagnostic held command")
        if (index-1)%SUBSTEPS == 0:
            require(sample["before_qpos"] == frame["native_qpos"] and sample["before_qvel"] == frame["native_qvel"],
                "Selection diagnostic prepared native join")
        if previous is not None:
            require(sample["before_qpos"] == previous["qpos"] and sample["before_qvel"] == previous["qvel"],
                "Selection diagnostic internal continuity")
        if first is None:
            first = physical_violation(sample, selection)
        previous = sample
        final_position = [sample["qpos"][0], -sample["qpos"][1]]
        trace_count = index
    require(trace_count == result["internal_rows"] == 7200 and first == trial["native_metrics"]["first_physical_violation"],
        "Selection diagnostic first violation/denominator")
    boundary = None if first is None else first["internal_step"]
    before = [f for f in frames if boundary is None or (f["step"]+1)*SUBSTEPS < boundary]
    events = {}
    for name, predicate in [
        ("first_no_case_support", lambda f: f["reason"] == "no_current_case_support"),
        ("first_posture_refusal", lambda f: f["reason"].startswith("unsupported_current_observation: Outside posture domain")),
        ("first_zero_support", lambda f: f["support_count"] == 0)]:
        found = next((f for f in frames if f["step"] > 0 and predicate(f)), None)
        events[name] = None if found is None else dict(step=found["step"], time_s=found["step"]*DT,
            before_first_violation=boundary is None or found["step"]*SUBSTEPS < boundary,
            proposed_expert=found["proposed"], support_count=found["support_count"])
    return dict(trial_id=trial["trial_id"], condition_id=trial["condition_id"], start_id=trial["start_id"],
        role=trial["role"], original_outcome=trial["outcome"], official_quality_m_s=trial["episode_metrics"]["quality_m_s"],
        first_physical_violation=first, events=events, full=summarize_frames(frames),
        complete_commands_before_violation=summarize_frames(before),
        diagnostic_windows=summarize_windows(frames, final_position, boundary, plan),
        raw_bindings={name: result["hashes"][name] for name in ["controller", "trace"]})


def analyze(evidence_root):
    require(sha(PARENT) == PARENT_SHA, "Selection diagnostic parent closure changed")
    parent = read(PARENT)
    trials, c = check_population(parent)
    root = Path(evidence_root).resolve(strict=True)
    require(root == Path(parent["evidence_root"]).resolve(strict=True), "Selection diagnostic evidence root")
    physical = root/parent["attempt_id"]/"physical"
    plan = learner.contract()
    require(plan["decision_window_steps"] == WINDOW and plan["controller_dt_s"] == DT,
        "Selection diagnostic window changed")
    rows = [analyze_trial(physical/t["trial_id"], t, c["selection"], plan) for t in trials]
    bindings = [dict(path=p, sha256=sha(ROOT/p)) for p in [
        "sdk/discovery/conditioned_selection_diagnostic.py",
        "sdk/discovery/audit_cpu_conditioned_feedback_closure.py",
        "sdk/discovery/body_height_diagnostic.py",
        "sdk/adaptation_provider/retrieval/learner.py"]]
    return dict(schema_version="locolemotion_conditioned_selection_diagnostic_v1",
        ledger_scope=dict(subsystem="adaptation", engine_scope="mujoco_cpu",
            authority_mode="retained_evidence_diagnostic", question_class="development"),
        parent_closure=dict(path=PARENT.relative_to(ROOT).as_posix(), sha256=PARENT_SHA),
        original_source_commit=parent["source_commit"], source_attempt=parent["attempt_id"],
        rules=RULES, source_trials=40, controller_rows=57600, internal_samples=288000,
        original_eligible=26, original_negative=14, implementation_bindings=bindings,
        world_build_count=0, solver_steps=0, trials=rows, **AUTHORITY)


def verify_record(path, evidence_root, core, baseline):
    verify_parent(PARENT, evidence_root, core, baseline)
    computed = analyze(evidence_root)
    require(read(path) == computed, "Selection diagnostic record changed")
    return dict(ok=True, source_trials=40, controller_rows=57600, internal_samples=288000,
        world_build_count=0, solver_steps=0, **AUTHORITY)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record", type=Path, required=True)
    parser.add_argument("--evidence-root", type=Path, default=ROOT.parent/"SporeSpore_Evidence")
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    if args.write:
        verify_parent(PARENT, args.evidence_root, args.core, args.baseline_core)
        record = analyze(args.evidence_root)
        with args.record.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(record, stream, indent=2, allow_nan=False)
            stream.write("\n")
        print(json.dumps(dict(ok=True, source_trials=40, controller_rows=57600, internal_samples=288000,
            world_build_count=0, solver_steps=0)), flush=True)
    else:
        print(json.dumps(verify_record(args.record, args.evidence_root, args.core, args.baseline_core)), flush=True)
