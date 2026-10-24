"""Post-hoc full-state, issued-action and force-coverage diagnosis of all 48 trials.

A nearby retrieval cue is not proof of equivalent joint state or action history.
Case differences and cap occupancy describe retained observations, not causation,
available counterfactual force, recoverability, or a trained replacement policy.
"""
import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path

from audit_cpu_committed_feedback_closure import verify_record as verify_parent
from audit_cpu_committed_feedback_closure import read, declaration, trial_plan, physical_violation
from audit_gpu_batch_execution import read_jsonl, same_bits
from cpu_committed_feedback_task import ROOT, require
from committed_feedback_control import ROLES
from adaptation_provider.retrieval import feedback_dense_v1 as learner

PARENT = ROOT/"sdk/discovery/cpu_committed_feedback_closure_v1.json"
PARENT_SHA = "5aeb46084f5431386656a029f3a887433945c0df97f3180a6ac58d0ba2b5d633"
FIT = ROOT/"sdk/discovery/command_resolution_repertoire_closure_v1.json"
FIT_SHA = "19fa595e36719c287f2985298d062e7ce89e25a12f41654c4c46655f7231c7bb"
DT, SUBSTEPS = 1/120, 5
AUTHORITY = dict(training_data_authority=False, selection_authority=False,
    causal_authority=False, counterfactual_performance_authority=False,
    recoverability_authority=False, physical_acceptance_authority=False,
    release_authority=False, population_inference=False)
RULES = dict(post_hoc=True, complete_population=True,
    comparison_prefix="all five command substeps strictly precede the first physical violation",
    force_prefix="completed internal samples strictly before the first physical violation",
    retrieval_neighbors="actual proposed expert's recorded cases, including shuffled roles",
    unscored="no actual-expert prediction, no proposal, disabled, or no comparable previous action",
    previous_action="prior resolved final canonical command from adjacent raw rows, never raw proposal",
    provider_history_after_step_one="empty in the tested host; prior-command differences are audit-only observations",
    omitted_differences="maximum absolute coordinate difference per named field and case neighbor",
    phase_difference="maximum circular difference of the exact four clocked phase steps",
    observations_are_independent_trials=False, fixed_expert_counterfactual_labels=False,
    force_cap_occupancy_is_infeasibility_proof=False, failed_official_quality_remains_null=True)
FEATURE_NAMES = ["joint_position_rad", "joint_velocity_rad_s", "vertical_velocity_m_s",
    "roll_pitch_rate_rad_s", "previous_final_command_rad_s", "previous_correction_rad_s",
    "exact_phase_commands"]


def sha(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def population(parent):
    c = declaration(); rows = parent["finite_outcomes"]["trials"]; plans = trial_plan(c)
    require(len(rows) == len(plans) == 48 and all(
        all(row[k] == plan[k] for k in ["trial_id", "condition_id", "start_id", "role", "selection_role_index"])
        for row, plan in zip(rows, plans, strict=True)), "State coverage complete population")
    require((parent["finite_outcomes"]["eligible"], parent["finite_outcomes"]["negative"]) == (29, 19)
        and sum(t["outcome"] == "positive" for t in rows) == 29
        and all(t["episode_metrics"]["quality_m_s"] is None for t in rows if t["outcome"] == "negative")
        and parent["finite_outcomes"]["repertoire"]["ranked_role_indices"] == [],
        "State coverage original outcomes/authority")
    return rows, c


def finite_vector(values, length, name):
    require(isinstance(values, list) and len(values) == length
        and all(type(v) in (int, float) and math.isfinite(v) for v in values), name)
    return values


def state_features(request, previous):
    plan = learner.contract(); state = request["state"]
    joints = state["ordered_joint_observations"]
    require([r["joint_id"]+"_motor" for r in joints] == plan["ordered_actuator_ids"]
        and all(r["validity"]["position"] and r["validity"]["velocity"] for r in joints),
        "State coverage joint order/availability")
    twist = state["base_twist_world"]
    steps = {r["limb_id"]: r["gait_step"] for r in request["controller_context"]["controller_memory"]["ordered_limb_memory"]}
    require(set(steps) == set(plan["ordered_limb_ids"])
        and all(type(v) is int and v >= 0 for v in steps.values()), "State coverage exact phase")
    value = dict(joint_position_rad=[r["position_rad"] for r in joints],
        joint_velocity_rad_s=[r["velocity_rad_s"] for r in joints],
        vertical_velocity_m_s=[twist["linear_velocity_m_s"]["y"]],
        roll_pitch_rate_rad_s=[twist["angular_velocity_rad_s"][k] for k in ["x", "z"]],
        previous_final_command_rad_s=None if previous is None else previous["final"],
        previous_correction_rad_s=None if previous is None else previous["correction"],
        exact_phase_commands=[steps[k] % 360 for k in plan["ordered_limb_ids"]])
    for key, size in zip(FEATURE_NAMES, [8, 8, 1, 2, 8, 8, 4], strict=True):
        if value[key] is not None: finite_vector(value[key], size, "State coverage finite "+key)
    return value


def describe(row, role, step, previous):
    require(row["outer_step"] == step and row["backend"] == "cpu" and row["cell"] == 0
        and row["request"]["state"]["semantic_step"] == step
        and row["request"]["state"]["sample_time_s"] == step*DT, "State coverage controller order/clock")
    require(row["selection"]["role"] == next(r for r in ROLES if r["id"] == role), "State coverage role")
    request = row["resolution_request"]["provider_request"]
    require(request["state"] == row["request"]["state"]
        and request["controller_context"]["controller_memory"] == row["output"]["next_memory"],
        "State coverage canonical state/context join")
    entries = request["history"]["ordered_entries"]
    require(len(entries) == (1 if step == 1 else 0), "State coverage actual history availability")
    if previous is not None:
        require(previous["step"] == step-1 and same_bits(
            [r["previous_applied_correction_rad_s"] for r in request["safety_envelope"]["ordered_actuator_limits"]],
            previous["correction"]), "State coverage prior correction join")
    if step == 1:
        require(entries[-1]["semantic_step"] == step-1, "State coverage prior history step")
        entry = entries[-1]
        commands = entry["deterministic_baseline"]["ordered_commands"]
        correction = entry["ordered_applied_corrections"]
        require([r["actuator_id"] for r in commands] == [r["actuator_id"] for r in correction]
            == learner.contract()["ordered_actuator_ids"], "State coverage prior history actuator order")
        final = [r["combined_canonical_target_velocity_rad_s"]+c["canonical_velocity_delta_rad_s"]
            for r, c in zip(commands, correction, strict=True)]
        # Final-speed saturation belongs to the resolver. Reconstruct its
        # issued command using the same declared per-actuator speed limit.
        limits = [r["maximum_target_speed_rad_s"] for r in previous["commands"]]
        final = [max(-cap, min(cap, v)) for v, cap in zip(final, limits, strict=True)]
        require(same_bits(final, previous["final"])
            and same_bits([r["canonical_velocity_delta_rad_s"] for r in correction], previous["correction"]),
            "State coverage actual previous command join")
    commands = row["resolution"]["ordered_commands"]
    require([r["actuator_id"] for r in commands] == learner.contract()["ordered_actuator_ids"],
        "State coverage command order")
    final = finite_vector([r["final_canonical_target_velocity_rad_s"] for r in commands], 8, "State coverage final command")
    correction = finite_vector([r["applied_correction_rad_s"] for r in commands], 8, "State coverage correction")
    d = row["selection"]["decision"]
    if d is None:
        require(role == "baseline", "State coverage missing selection")
        action, predictions, reason, query = 0, {}, "fixed_baseline", None
    else:
        require(d["step"] == step and d["mode"] == next(r["mode"] for r in ROLES if r["id"] == role),
            "State coverage decision identity")
        action, reason, query = d["proposed_action_index"], d["selection_reason"], d["query"]
        predictions = {p["action_index"]: p for p in d["predictions"]}
        require(len(predictions) == len(d["predictions"]), "State coverage duplicate prediction")
        logical = d["logical_action_index"]
        require((action is None and logical is None) or (type(logical) is int and logical in range(3)
            and action == ([0, 2, 1][logical] if "shuffled" in role else logical)), "State coverage shuffled action")
    require(role != "disabled" or not any(correction), "State coverage disabled influence")
    state = request["state"]; native = row["native_observation"]; p = state["base_pose_world"]["position_m"]
    require([p["x"], p["y"], p["z"]] == [native["qpos"][0], native["qpos"][2], -native["qpos"][1]],
        "State coverage native position join")
    return dict(step=step, features=state_features(request, previous), final=final, correction=correction,
        commands=commands, qpos=native["qpos"], qvel=native["qvel"], targets=row["native_targets"],
        action=action, query=query, prediction=predictions.get(action), reason=reason,
        applied=row["resolution"]["provider_status"] == "applied",
        contacts=[r["presence"] and r["bears_support"] for r in state["ordered_contact_observations"]])


def case_features(evidence_root):
    require(sha(FIT) == FIT_SHA, "State coverage fitted source changed")
    fit = read(FIT)["result"]; model = fit["model"]; plan = learner.contract()
    require(fit["case_count"] == len(model["ordered_cases"]) == 21165
        and len(fit["source_ledger"]) == 32 and len(fit["source_bindings"]) == 24,
        "State coverage fitted denominator")
    by_episode = {r["derived_episode_id"]: r for r in fit["source_bindings"]}
    grouped = {key: [] for key in by_episode}
    for case in model["ordered_cases"]:
        require(case["episode_id"] in grouped, "State coverage crossed case episode")
        grouped[case["episode_id"]].append(case)
    output = {}; bindings = []; source_rows = 0
    for episode, source in by_episode.items():
        path = evidence_root/fit["parent_attempt_id"]/"physical"/source["trial_id"]/"controller.jsonl"
        require(sha(path) == source["controller_sha256"], "State coverage fitted raw stream changed")
        values = grouped[episode]
        bindings.append(dict(trial_id=source["trial_id"], controller_sha256=source["controller_sha256"],
            outcome=source["outcome"], case_count=len(values)))
        if source["outcome"] != "positive":
            require(not values, "State coverage failed positive cases"); continue
        require(len(values) == 1411 and [c["case_id"] for c in values] == [episode+"_"+str(i) for i in range(1411)],
            "State coverage case step population")
        previous = None
        for i, row in enumerate(read_jsonl(path)):
            require(i < 1440 and row["outer_step"] == i, "State coverage case raw chronology")
            request = row["resolution_request"]["provider_request"]
            require(request["state"] == row["request"]["state"], "State coverage case state join")
            if i < 1411:
                case = values[i]
                require(learner.cue(request, plan) == case["cue"], "State coverage case cue join")
                output[case["case_id"]] = dict(features=state_features(request, previous),
                    action_index=case["action_index"], cue=case["cue"], trial_id=source["trial_id"], step=i)
            previous = dict(final=[r["final_canonical_target_velocity_rad_s"] for r in row["resolution"]["ordered_commands"]],
                correction=[r["applied_correction_rad_s"] for r in row["resolution"]["ordered_commands"]])
            source_rows += 1
        require(i+1 == 1440, "State coverage case raw denominator")
    require(len(output) == 21165 and source_rows == 21600, "State coverage source feature population")
    return output, bindings


def differences(current, stored):
    result = {}
    for key in FEATURE_NAMES:
        a, b = current[key], stored[key]
        if a is None or b is None: result[key] = None; continue
        require(len(a) == len(b), "State coverage difference dimensions")
        delta = [abs(x-y) for x, y in zip(a, b, strict=True)]
        if key == "exact_phase_commands": delta = [min(d, 360-d) for d in delta]
        result[key] = max(delta)
    return result


def summarize_cases(frames, cases, boundary):
    stats = {k: dict(count=0, total=0., maximum=None, witness=None, unavailable=0) for k in FEATURE_NAMES}
    reasons = Counter(); eligible = 0; compared = 0
    for f in frames:
        if boundary is not None and (f["step"]+1)*SUBSTEPS >= boundary: continue
        eligible += 1; reasons[f["reason"]] += 1
        prediction = f["prediction"]
        if f["action"] not in [1, 2] or not f["applied"] or prediction is None: continue
        ids = prediction["case_ids"]
        require(0 < len(ids) <= 3 and len(set(ids)) == len(ids), "State coverage selected case IDs")
        for identity in ids:
            require(identity in cases, "State coverage unknown selected case")
            case = cases[identity]
            require(case["action_index"] == f["action"] and case["cue"]["phase"] == f["query"]["phase"]
                and case["cue"]["contact_mask"] == f["query"]["contact_mask"], "State coverage case action/phase/contact")
            compared += 1
            delta = differences(f["features"], case["features"])
            for key, value in delta.items():
                s = stats[key]
                if value is None: s["unavailable"] += 1; continue
                s["count"] += 1; s["total"] += value
                if s["maximum"] is None or value > s["maximum"]:
                    s["maximum"] = value
                    s["witness"] = dict(runtime_step=f["step"], case_id=identity,
                        source_trial_id=case["trial_id"], source_step=case["step"],
                        runtime_value=f["features"][key], source_value=case["features"][key])
    return dict(complete_commands_before_violation=eligible, reasons=dict(sorted(reasons.items())),
        selected_neighbor_pairs=compared,
        omitted_state_differences={k: dict(count=v["count"], unavailable=v["unavailable"],
            mean=v["total"]/v["count"] if v["count"] else None, maximum=v["maximum"], witness=v["witness"])
            for k, v in stats.items()})


def trace_summary(directory, frames, trial, selection, caps):
    first = None; before_count = 0; counts = [0]*8; full_counts = [0]*8; previous = None; count = 0
    for index, row in enumerate(read_jsonl(directory/"trace.jsonl"), 1):
        require(index <= 7200 and row["step"] == index and row["backend"] == "cpu" and row["cell"] == 0,
            "State coverage internal chronology")
        f = frames[(index-1)//5]
        require(same_bits(row["ctrl"], f["targets"]), "State coverage held command")
        if (index-1)%5 == 0:
            require(same_bits(row["before_qpos"], f["qpos"]) and same_bits(row["before_qvel"], f["qvel"]),
                "State coverage prepared native join")
        if previous is not None:
            require(same_bits(row["before_qpos"], previous["qpos"]) and same_bits(row["before_qvel"], previous["qvel"]),
                "State coverage internal continuity")
        forces = finite_vector(row["actuator_force_nm"], 8, "State coverage finite forces")
        labels = [v <= lo or v >= hi for v, (lo, hi) in zip(forces, caps, strict=True)]
        require(row["on_force_cap"] == labels, "State coverage cap label")
        require(all(lo-1e-9 <= v <= hi+1e-9 for v,(lo,hi) in zip(forces,caps,strict=True)),
            "State coverage force exceeds cap")
        if first is None: first = physical_violation(row, selection)
        if first is None:
            before_count += 1
            counts = [n+int(v) for n,v in zip(counts,labels,strict=True)]
        full_counts = [n+int(v) for n,v in zip(full_counts,labels,strict=True)]
        previous = row; count = index
    require(count == 7200 and first == trial["native_metrics"]["first_physical_violation"],
        "State coverage first violation/denominator")
    return dict(internal_samples=count, first_physical_violation=first,
        internal_samples_before_violation=before_count, force_cap_steps_before_violation=counts,
        force_cap_fraction_before_violation=[n/before_count if before_count else None for n in counts],
        full_force_cap_steps=full_counts)


def first_difference(left, right, key):
    require(len(left) == len(right) == 1440, "State coverage paired denominator")
    for a, b in zip(left, right, strict=True):
        if not same_bits(a[key], b[key]):
            return dict(step=a["step"], time_s=a["step"]*DT, left=a[key], right=b[key])
    return None


def pair_summary(left, right, left_trial, right_trial):
    require(left_trial["condition_id"] == right_trial["condition_id"]
        and left_trial["start_id"] == right_trial["start_id"], "State coverage crossed pair")
    correction = first_difference(left, right, "correction")
    first = None if correction is None else correction["step"]
    return dict(left_role=left_trial["role"], right_role=right_trial["role"],
        left_outcome=left_trial["outcome"], right_outcome=right_trial["outcome"],
        first_different_correction=correction,
        same_observation_at_first_correction_difference=None if first is None else (
            same_bits(left[first]["qpos"], right[first]["qpos"]) and same_bits(left[first]["qvel"], right[first]["qvel"])),
        first_different_final_command=first_difference(left,right,"final"),
        first_different_native_position=first_difference(left,right,"qpos"),
        first_different_contacts=first_difference(left,right,"contacts"))


def analyze(evidence_root):
    require(sha(PARENT) == PARENT_SHA, "State coverage parent changed")
    parent = read(PARENT); trials, c = population(parent)
    root = Path(evidence_root).resolve(strict=True)
    require(root == Path(parent["evidence_root"]).resolve(strict=True), "State coverage evidence root")
    cases, sources = case_features(root); physical = root/parent["attempt_id"]/"physical"
    results = []; groups = []
    for start in range(0,48,6):
        group = trials[start:start+6]; retained = {}
        for trial in group:
            directory = physical/trial["trial_id"]; result = read(directory/"result.json")
            require(result["trial_id"] == trial["trial_id"] and result["completed"] is True
                and result["outer_rows"] == 1440 and result["internal_rows"] == 7200,
                "State coverage original trial identity")
            for name in ["controller","trace"]:
                require(sha(directory/(name+".jsonl")) == result["hashes"][name], "State coverage original raw bytes changed")
            frames=[]; previous=None
            for i,row in enumerate(read_jsonl(directory/"controller.jsonl")):
                value=describe(row,trial["role"],i,previous);frames.append(value);previous=value
            require(len(frames)==1440, "State coverage controller denominator")
            metadata=read(physical/"models"/trial["condition_id"]/"native-model.json")
            require(metadata["condition_id"] == trial["condition_id"], "State coverage condition caps")
            trace=trace_summary(directory,frames,trial,c["selection"],metadata["force_ranges"])
            boundary=None if trace["first_physical_violation"] is None else trace["first_physical_violation"]["internal_step"]
            results.append(dict(trial_id=trial["trial_id"],condition_id=trial["condition_id"],start_id=trial["start_id"],
                role=trial["role"],original_outcome=trial["outcome"],official_quality_m_s=trial["episode_metrics"]["quality_m_s"],
                trace=trace,cases=summarize_cases(frames,cases,boundary),
                raw_bindings={name:result["hashes"][name] for name in ["controller","trace"]}))
            retained[trial["role"]]=frames
        paired=[]
        for a,b in [(0,1),(0,2),(0,3),(2,4),(3,5),(2,3),(4,5)]:
            pair=pair_summary(retained[group[a]["role"]],retained[group[b]["role"]],group[a],group[b])
            if (a,b)==(0,1) or group[a]["condition_id"]=="nominal":
                require(all(pair[k] is None for k in ["first_different_correction","first_different_final_command",
                    "first_different_native_position","first_different_contacts"]), "State coverage baseline/healthy identity")
            paired.append(pair)
        groups.append(dict(condition_id=group[0]["condition_id"],start_id=group[0]["start_id"],pairs=paired))
    paths=["sdk/discovery/committed_state_coverage_diagnostic.py","sdk/discovery/audit_cpu_committed_feedback_closure.py",
        "sdk/discovery/body_height_diagnostic.py","sdk/adaptation_provider/retrieval/learner.py",
        "sdk/adaptation_provider/retrieval/feedback_dense_v1.py","sdk/adaptation_provider/retrieval/feedback_dense_contract_v1.json"]
    return dict(schema_version="locolemotion_committed_state_coverage_diagnostic_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",authority_mode="retained_evidence_diagnostic",question_class="development"),
        parent_closure=dict(path=PARENT.relative_to(ROOT).as_posix(),sha256=PARENT_SHA),
        fitted_source=dict(path=FIT.relative_to(ROOT).as_posix(),sha256=FIT_SHA),
        original_source_commit=parent["source_commit"],source_attempt=parent["attempt_id"],rules=RULES,
        source_trials=48,controller_rows=69120,internal_samples=345600,original_eligible=29,original_negative=19,
        fitted_source_streams=24,fitted_feature_rows=21600,fitted_cases=21165,fitted_source_bindings=sources,
        implementation_bindings=[dict(path=p,sha256=sha(ROOT/p)) for p in paths],
        ordered_actuator_ids=learner.contract()["ordered_actuator_ids"],
        world_build_count=0,solver_steps=0,trials=results,groups=groups,**AUTHORITY)


def verify_record(path,evidence_root,core,baseline):
    verify_parent(PARENT,evidence_root,core,baseline)
    require(read(path)==analyze(evidence_root), "State coverage record changed")
    return dict(ok=True,source_trials=48,controller_rows=69120,internal_samples=345600,
        fitted_source_streams=24,fitted_feature_rows=21600,fitted_cases=21165,
        world_build_count=0,solver_steps=0,**AUTHORITY)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--record",type=Path,required=True)
    p.add_argument("--evidence-root",type=Path,default=ROOT.parent/"SporeSpore_Evidence")
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--write",action="store_true");a=p.parse_args()
    if a.write:
        verify_parent(PARENT,a.evidence_root,a.core,a.baseline_core)
        value=analyze(a.evidence_root)
        with a.record.open("x",encoding="utf-8",newline="\n") as f:json.dump(value,f,indent=2,allow_nan=False);f.write("\n")
        print(json.dumps(dict(ok=True,source_trials=48,world_build_count=0,solver_steps=0)),flush=True)
    else:print(json.dumps(verify_record(a.record,a.evidence_root,a.core,a.baseline_core)),flush=True)
