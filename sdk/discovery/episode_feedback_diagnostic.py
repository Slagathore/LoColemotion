"""Post-hoc mechanism diagnosis of the immutable native memory comparison.

This reconstructs observed feedback and same-input choices. It cannot assign
an outcome to an unexecuted alternative, fit a model, or regrade the campaign.
"""
import argparse
import json
import math
from pathlib import Path

from audit_gpu_retrieval_influence_closure import verify_record
from gpu_retrieval_influence import ROOT, declaration, trial_plan
from gpu_quadruped_model import sha
from portable_search_control import bridge
from retrieval_shadow_control import learner, load_candidate


def compatible(query, stored, plan):
    learner.validate_cue(query)
    learner.validate_cue(stored)
    distance = math.sqrt(sum(((a-b)/scale)**2 for a,b,scale in
        zip(query["vector"], stored["vector"], plan["feature_scales"], strict=True)))
    return (query["phase"] == stored["phase"] and query["contact_mask"] == stored["contact_mask"]
        and distance <= plan["maximum_support_distance"])


def choice(predictions, offsets, plan):
    learner.require(0 in predictions, "Decision lacks baseline support")
    adjusted = {a:r["quality_m_s"]+offsets[a] for a,r in predictions.items()}
    selected = min(adjusted, key=lambda a:(-adjusted[a],a))
    return 0 if adjusted[selected] < adjusted[0]+plan["minimum_predicted_gain_m_s"] else selected


def credited_action(action, mode, plan):
    if mode != "episodic_shuffled" or action == 0:
        return action
    original = plan["actions"][action]
    return next(i for i,r in enumerate(plan["actions"]) if
        r["global_scale"] == -original["global_scale"] and r["side_bias"] == -original["side_bias"])


def diagnose_rows(rows, model):
    plan = model.plan()
    modes = ["episodic", "episodic_shuffled"]
    starts, credits, decisions = {m:{} for m in modes}, {m:[] for m in modes}, {m:[] for m in modes}
    counts = {m:0 for m in modes}
    for row in rows:
        mode = row["mode"]
        if mode not in modes:
            continue
        step = row["outer_step"]
        learner.require(step == counts[mode] and row["operation"] is None and row["provider_error"] is None,
            "Diagnostic input clock/error/operation")
        counts[mode] += 1
        request = row["resolution_request"]["provider_request"]
        before = request["provider_memory"]["opaque_state"]
        after = row["resolution"]["next_memory"]["opaque_state"]
        old_updates = before.get("updates",0)
        learner.require(after["updates"] in [old_updates,old_updates+1], "Feedback update count")
        if after["updates"] != old_updates:
            held = before["active"]
            learner.require(held is not None and held["start_step"] in starts[mode]
                and step-held["start_step"] == plan["decision_window_steps"], "Feedback start/window join")
            start = starts[mode][held["start_step"]]
            learner.require(start["action"] == held["action"], "Feedback action changed")
            position = [request["state"]["base_pose_world"]["position_m"][axis] for axis in ["x","z"]]
            observed = learner.quality(held["start_position"],position,
                plan["decision_window_steps"]*plan["controller_dt_s"],plan)
            action = credited_action(held["action"],mode,plan)
            cap = plan["episodic_memory"]["maximum_offset_m_s"]
            residual = max(-cap,min(cap,observed-held["prediction"]))
            count = min(before["counts"][action]+1,plan["episodic_memory"]["maximum_count"])
            expected = max(-cap,min(cap,before["offsets"][action]+(residual-before["offsets"][action])/count))
            learner.require(after["counts"][action] == count and after["offsets"][action] == expected,
                "Observed feedback arithmetic")
            credits[mode].append(dict(start_step=held["start_step"],observed_at_step=step,
                applied_action=held["action"],credited_action=action,cue=start["cue"],
                predicted_quality_m_s=held["prediction"],observed_quality_m_s=observed,
                clipped_residual_m_s=residual,resulting_global_offset_m_s=expected))
        active = after["active"]
        if active is None or active["start_step"] != step:
            continue
        query = learner.cue(request,plan)
        predictions = model.predictions(query)
        frozen = choice(predictions,[0.]*len(plan["actions"]),plan)
        adjusted = choice(predictions,after["offsets"],plan)
        learner.require(adjusted == active["action"], "Same-input decision replay")
        starts[mode][step] = dict(action=adjusted,cue=query)
        decisive = sorted({a for a in [frozen,adjusted] if after["offsets"][a] != 0.})
        context_support = {str(action):[credit["start_step"] for credit in credits[mode]
            if credit["credited_action"] == action and compatible(query,credit["cue"],plan)] for action in decisive}
        decisions[mode].append(dict(step=step,cue=query,selected_action=adjusted,frozen_action=frozen,
            changed=adjusted != frozen,decisive_offsets_m_s={str(a):after["offsets"][a] for a in decisive},
            matching_feedback_start_steps=context_support,
            no_matching_feedback_for_any_decisive_action=bool(decisive) and not any(context_support.values())))
    summaries = {}
    for mode in modes:
        changed = [d for d in decisions[mode] if d["changed"]]
        summaries[mode] = dict(controller_rows=counts[mode],completed_feedback_updates=len(credits[mode]),
            action_selections=len(decisions[mode]),changed_selections=len(changed),
            changed_selections_without_any_matching_feedback=sum(d["no_matching_feedback_for_any_decisive_action"] for d in changed),
            feedback=credits[mode],decisions=decisions[mode])
    return summaries


def analyze(closure_path, evidence_root, core_path, baseline_path):
    verified = verify_record(closure_path,evidence_root,core_path,baseline_path)
    record = json.loads(closure_path.read_text(encoding="utf-8"))
    evidence_root = evidence_root.resolve(strict=True)
    attempt = evidence_root/record["attempt_id"]
    retained = json.loads((attempt/"independent-audit.json").read_text(encoding="utf-8"))
    model = load_candidate(bridge.LocomotionCore(core_path),declaration())
    groups = {}
    bindings = {}
    for plan, original in zip(trial_plan(declaration()),retained["trials"],strict=True):
        path = attempt/"physical"/plan["trial_id"]/"controller.jsonl"
        bindings[path.relative_to(evidence_root).as_posix()] = sha(path)
        with path.open(encoding="utf-8") as stream:
            groups[plan["group_id"]] = diagnose_rows((json.loads(line) for line in stream),model)
        for mode,state in groups[plan["group_id"]].items():
            expected = original["providers"][mode]
            learner.require(state["controller_rows"] == expected["rows"] == 480
                and state["completed_feedback_updates"] == expected["completed_feedback_updates"]
                and state["changed_selections"] == expected["same_input_choices_changed_by_memory"],
                "Original complete reader denominator")
    totals = {key:sum(s[key] for group in groups.values() for s in group.values()) for key in [
        "controller_rows","completed_feedback_updates","action_selections","changed_selections",
        "changed_selections_without_any_matching_feedback"]}
    return dict(schema_version="locolemotion_episode_feedback_diagnostic_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_warp",authority_mode="development",question_class="development"),
        input_closure_sha256=sha(closure_path),input_attempt_id=record["attempt_id"],
        input_reader_verified=verified["ok"],controller_stream_bindings=bindings,
        fitted_model_sha256=model.sha256,groups=groups,totals=totals,world_build_count=0,
        posthoc_diagnostic=True,physical_acceptance_authority=False,release_authority=False,
        training_data_authority=False,counterfactual_outcome_authority=False,
        interpretation="Reconstructs actual feedback and same-input decisions using the frozen retrieval context definition. Cross-context reuse is a mechanism diagnosis, not proof that a contextual successor improves physical outcomes. No original result is regraded.")


if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--closure",type=Path,default=ROOT/"sdk/discovery/gpu_retrieval_influence_closure_v1.json")
    parser.add_argument("--evidence-root",type=Path,required=True)
    parser.add_argument("--core",type=Path,required=True)
    parser.add_argument("--baseline-core",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    result=analyze(args.closure,args.evidence_root,args.core,args.baseline_core)
    with args.output.open("x",encoding="utf-8",newline="\n") as stream:
        json.dump(result,stream,indent=2,allow_nan=False)
        stream.write("\n")
    print(json.dumps(dict(totals=result["totals"],world_build_count=0,posthoc_diagnostic=True)))
