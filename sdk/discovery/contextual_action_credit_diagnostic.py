"""Diagnose action credit from retained contextual development trajectories.

The observed return belongs only to the action actually executed. Comparisons
between diverged worlds describe association, never a counterfactual action
effect. This reader does not fit, select, regrade or construct physical worlds.
"""
import argparse
import copy
import json
import math
from pathlib import Path
import statistics

from audit_gpu_contextual_influence_closure import verify_record
from audit_gpu_contextual_influence import same_bits
from gpu_contextual_influence import ROOT, declaration, trial_plan
from gpu_quadruped_model import sha
from portable_search_control import bridge
from retrieval_shadow_control import load_candidate
from adaptation_provider.retrieval import contextual_v1 as contextual

require = contextual.require
MODES = ("frozen", "episodic", "episodic_shuffled")


def distribution(values):
    """Keep empty populations explicit; frames are not independent episodes."""
    require(all(type(v) in (int, float) and math.isfinite(v) for v in values), "Nonfinite diagnostic value")
    return dict(count=len(values), mean=statistics.mean(values) if values else None,
                median=statistics.median(values) if values else None,
                minimum=min(values) if values else None, maximum=max(values) if values else None)


def correlation(pairs):
    if len(pairs) < 2:
        return None
    xs, ys = zip(*pairs, strict=True)
    mx, my = statistics.mean(xs), statistics.mean(ys)
    xx = sum((x-mx)**2 for x in xs)
    yy = sum((y-my)**2 for y in ys)
    return sum((x-mx)*(y-my) for x, y in pairs)/math.sqrt(xx*yy) if xx and yy else None


def score_summary(windows):
    return dict(completed_observed_windows=len(windows),
        positive_prediction_errors=sum(w["prediction_error_m_s"] > 0 for w in windows),
        negative_prediction_errors=sum(w["prediction_error_m_s"] < 0 for w in windows),
        error_exceeds_top_two_gap=sum(abs(w["prediction_error_m_s"]) > w["top_two_prediction_gap_m_s"]
            for w in windows if w["top_two_prediction_gap_m_s"] is not None),
        windows_with_two_predictions=sum(w["top_two_prediction_gap_m_s"] is not None for w in windows),
        prediction_error_m_s=distribution([w["prediction_error_m_s"] for w in windows]),
        absolute_prediction_error_m_s=distribution([abs(w["prediction_error_m_s"]) for w in windows]),
        top_two_prediction_gap_m_s=distribution([w["top_two_prediction_gap_m_s"] for w in windows
            if w["top_two_prediction_gap_m_s"] is not None]))


def decision_summary(decisions):
    changed = [d for d in decisions if d["changed"]]
    one_sided = [d for d in changed if d["selected_feedback_offset_m_s"] is None
        and d["frozen_feedback_offset_m_s"] is not None and d["frozen_feedback_offset_m_s"] < 0]
    return dict(action_selections=len(decisions), changed_selections=len(changed),
        selections_with_matching_context_feedback=sum(bool(d["all_feedback_actions"]) for d in decisions),
        selections_with_two_or_more_supported_feedback_actions=sum(len(d["supported_feedback_actions"]) >= 2 for d in decisions),
        changed_with_feedback_for_both_choices=sum(d["selected_feedback_offset_m_s"] is not None
            and d["frozen_feedback_offset_m_s"] is not None for d in changed),
        changed_from_negative_feedback_to_unobserved_action=len(one_sided))


def paired_errors(left, right, plan):
    """Pair equal start clocks, while recording that the states can differ."""
    lhs = {w["start_step"]: w for w in left}
    rhs = {w["start_step"]: w for w in right}
    rows = []
    for step in sorted(lhs.keys() & rhs.keys()):
        a, b = lhs[step], rhs[step]
        distance = contextual.context_distance(a["cue"], b["cue"], plan)
        rows.append(dict(start_step=step, left_action=a["applied_action"], right_action=b["applied_action"],
            same_action=a["applied_action"] == b["applied_action"], matching_context=distance is not None,
            context_distance=distance, left_error_m_s=a["prediction_error_m_s"], right_error_m_s=b["prediction_error_m_s"]))
    selected = [r for r in rows if r["matching_context"]]
    different = [r for r in selected if not r["same_action"]]
    return dict(equal_clock_pairs=len(rows), matching_context_pairs=len(selected),
        different_action_matching_context_pairs=len(different),
        matching_context_error_correlation=correlation([(r["left_error_m_s"], r["right_error_m_s"]) for r in selected]),
        different_action_error_correlation=correlation([(r["left_error_m_s"], r["right_error_m_s"]) for r in different]),
        descriptive_only=True, common_error_identified=False, counterfactual_outcome_authority=False, rows=rows)


def diagnose_rows(rows, model, mode_order):
    plan, config = model.plan(), contextual.contract()
    require(len(mode_order) == len(set(mode_order)) == 6 and set(mode_order) == set(declaration()["modes"]), "Mode population")
    counts = {m: 0 for m in mode_order}
    previous, starts = {}, {m: {} for m in MODES}
    windows, decisions = {m: [] for m in MODES}, {m: [] for m in MODES}
    total = 0
    for row in rows:
        cell, step = total % 6, total // 6
        mode = mode_order[cell]
        require(row["mode"] == mode and row["cell"] == cell and row["outer_step"] == step
            and row["operation"] is None and row["provider_error"] is None
            and row["commands_applied_to_physics"] is True
            and row["outcome_credit"] == "actual_applied_action_sequence", "Diagnostic clock/mode/authority")
        total += 1
        counts[mode] += 1
        if mode not in MODES:
            continue
        request = row["resolution_request"]["provider_request"]
        before = request["provider_memory"]["opaque_state"]
        after = row["resolution"]["next_memory"]["opaque_state"]
        require(request["state"]["semantic_step"] == step
            and same_bits(before, previous.get(mode, {})), "Diagnostic memory continuity")
        active = before.get("active")
        completed = active is not None and step-active["start_step"] == plan["decision_window_steps"]
        expected_records = copy.deepcopy(before.get("records", []))
        expected_updates = before.get("updates", 0)
        if completed:
            require(active["start_step"] in starts[mode], "Missing action-time decision")
            original = starts[mode][active["start_step"]]
            require(same_bits(active, original), "Held action-time context changed")
            pos = request["state"]["base_pose_world"]["position_m"]
            duration = plan["decision_window_steps"] * plan["controller_dt_s"]
            forward = (pos["x"]-active["start_position"][0])/duration
            lateral = (pos["z"]-active["start_position"][1])/duration
            observed = -abs(forward-plan["desired_forward_velocity_m_s"])-plan["lateral_error_weight"]*abs(lateral)
            predictions = model.predictions(active["start_cue"])
            prediction = predictions[active["action"]]
            require(prediction["quality_m_s"] == active["prediction"]
                and prediction["case_ids"] == active["case_ids"], "Frozen action prediction changed")
            ranked = sorted((p["quality_m_s"] for p in predictions.values()), reverse=True)
            error = observed-active["prediction"]
            windows[mode].append(dict(start_step=active["start_step"], observed_at_step=step,
                applied_action=active["action"], cue=copy.deepcopy(active["start_cue"]),
                predicted_quality_m_s=active["prediction"], observed_quality_m_s=observed, prediction_error_m_s=error,
                prediction_count=len(ranked), top_two_prediction_gap_m_s=ranked[0]-ranked[1] if len(ranked) > 1 else None))
            if mode in contextual.EPISODIC:
                expected_updates += 1
                cap = config["maximum_residual_m_s"]
                expected_records.append(dict(start_step=active["start_step"], observed_at_step=step,
                    applied_action=active["action"], credited_action=contextual.credited_action(active["action"], mode, plan),
                    cue=copy.deepcopy(active["start_cue"]), predicted_quality_m_s=active["prediction"],
                    observed_quality_m_s=observed, residual_m_s=max(-cap, min(cap, error))))
                expected_records = expected_records[-config["maximum_records"]:]
        require(same_bits(after["records"], expected_records) and after["updates"] == expected_updates,
            "Completed feedback arithmetic or future credit")
        selected = after.get("active")
        if selected is not None and selected["start_step"] == step:
            query = contextual.base.cue(request, plan)
            require(same_bits(query, selected["start_cue"]), "Decision context changed")
            predictions = model.predictions(query)
            offsets = contextual.contextual_offsets(query, after["records"], plan, config) if mode in contextual.EPISODIC else {}
            frozen = contextual.select_action(predictions, {}, plan)
            chosen = contextual.select_action(predictions, offsets, plan)
            require(chosen == selected["action"], "Contextual decision changed")
            starts[mode][step] = copy.deepcopy(selected)
            decisions[mode].append(dict(step=step, frozen_action=frozen, selected_action=chosen, changed=frozen != chosen,
                all_feedback_actions=sorted(offsets), supported_feedback_actions=sorted(set(predictions) & set(offsets)),
                selected_feedback_offset_m_s=offsets.get(chosen, {}).get("offset_m_s"),
                frozen_feedback_offset_m_s=offsets.get(frozen, {}).get("offset_m_s"),
                action_feedback={str(a): v for a, v in sorted(offsets.items())}))
        previous[mode] = after
    require(total > 0 and total % 6 == 0 and len(set(counts.values())) == 1, "Incomplete diagnostic rounds")
    return dict(controller_rows=total, modes={mode: dict(controller_rows=counts[mode],
        completed_feedback_updates=previous[mode]["updates"], **score_summary(windows[mode]),
        **decision_summary(decisions[mode]), windows=windows[mode], decisions=decisions[mode]) for mode in MODES},
        paired_prediction_errors={mode: paired_errors(windows["frozen"], windows[mode], plan)
            for mode in contextual.EPISODIC})


def analyze(closure_path, evidence_root, core_path, baseline_path):
    verified = verify_record(closure_path, evidence_root, core_path, baseline_path)
    closure = json.loads(closure_path.read_text(encoding="utf-8"))
    evidence_root = evidence_root.resolve(strict=True)
    attempt = evidence_root/closure["attempt_id"]
    c = declaration()
    model = load_candidate(bridge.LocomotionCore(core_path), c)
    groups, bindings = {}, {}
    for trial in trial_plan(c):
        path = attempt/"physical"/trial["trial_id"]/"controller.jsonl"
        bindings[path.relative_to(evidence_root).as_posix()] = sha(path)
        with path.open(encoding="utf-8") as stream:
            result = diagnose_rows((json.loads(line) for line in stream), model, trial["mode_order"])
        require(result["controller_rows"] == c["outer_steps"]*6, "Full controller denominator")
        for mode, stats in result["modes"].items():
            original = closure["group_summary"][trial["group_id"]]["providers"][mode]
            require(stats["controller_rows"] == original["rows"] == c["outer_steps"]
                and stats["completed_feedback_updates"] == original["completed_feedback_updates"]
                and stats["action_selections"] == original["new_action_selections"]
                and stats["changed_selections"] == original["same_input_choices_changed_by_memory"]
                and stats["selections_with_matching_context_feedback"] == original["context_supported_action_selections"],
                "Original audited feedback/decision denominator")
        groups[trial["group_id"]] = result
    totals = {}
    for mode in MODES:
        parts = [group["modes"][mode] for group in groups.values()]
        totals[mode] = dict(controller_rows=sum(p["controller_rows"] for p in parts),
            completed_feedback_updates=sum(p["completed_feedback_updates"] for p in parts),
            **score_summary([w for p in parts for w in p["windows"]]),
            **decision_summary([d for p in parts for d in p["decisions"]]))
    return dict(schema_version="locolemotion_contextual_action_credit_diagnostic_v1",
        ledger_scope=dict(subsystem="adaptation", engine_scope="mujoco_warp", authority_mode="development", question_class="development"),
        input_closure_sha256=sha(closure_path), input_attempt_id=closure["attempt_id"], input_reader_verified=verified["ok"],
        controller_stream_bindings=bindings, fitted_model_sha256=model.sha256,
        controller_rows=sum(g["controller_rows"] for g in groups.values()), groups=groups, totals=totals,
        world_build_count=0, posthoc_diagnostic=True, physical_acceptance_authority=False, release_authority=False,
        training_data_authority=False, counterfactual_outcome_authority=False, causal_action_credit_identified=False,
        interpretation="Observed action prediction errors, same-input decision changes and descriptive cross-world error associations. Unobserved actions have no assigned outcome. Context similarity does not equate diverged states; error correlation cannot identify a common disturbance. No model fitting or original outcome regrading.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--closure", type=Path, default=ROOT/"sdk/discovery/gpu_contextual_influence_closure_v1.json")
    parser.add_argument("--evidence-root", type=Path, required=True)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = analyze(args.closure, args.evidence_root, args.core, args.baseline_core)
    with args.output.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(result, stream, indent=2, allow_nan=False)
        stream.write("\n")
    print(json.dumps(dict(totals=result["totals"], controller_rows=result["controller_rows"], world_build_count=0)))
