"""Independent resolver bounds and observation joins for vertical composition."""
import struct
from adaptation_provider import support_vertical_feedback_v1 as parent
from phase_release_control import ROLES
from early_context_v1 import features as context_features
from audit_gpu_portable_search import require


def validate_proposal(row, c, cell, previous):
    request = row["resolution_request"]["provider_request"]
    response = row["resolution_request"]["provider_response"]; resolved = row["resolution"]
    role = ROLES[cell]
    candidate = c["provider"]["candidates"][role["candidate_index"]]
    probe_steps = role["baseline_probe_steps"]
    cap, slew = [candidate[k] for k in ["maximum_absolute_correction_rad_s", "maximum_slew_per_step_rad_s"]]
    require(request["deterministic_baseline"] == row["composition"]["canonical_actuation"]
        and request["state"] == row["request"]["state"] and request["command"] == row["request"]["command"], "Feedback observation/baseline join")
    require(request["expected_model_id"] == candidate["id"] and request["provider_id"] == "phase_release_comparison"
        and request["expected_provider_version"] == "phase_release_v1"
        and request["expected_training_corpus_id"] == "untrained_no_training_corpus", "Feedback candidate identity")
    step = request["state"]["semantic_step"]
    probe = step < probe_steps
    no_proposal = probe or candidate["mode"] == "baseline"
    if no_proposal:
        require(response is not None and response["status"] == "no_proposal"
                and response["ordered_corrections"] == [] and row["feedback"]["status"] == "baseline"
                and resolved["provider_status"] == "no_proposal" and not resolved["adaptation_applied"],
                "Phase-release no-proposal prefix/role")
    else:
        require((response is None) == (row["feedback"]["status"] == "refused"), "Phase-release feedback refusal join")
    if candidate.get("phase_release", False) and response is not None and not no_proposal:
        # Independent arithmetic uses the parent's raw equations, not the new
        # provider's taper helper or its reported weight.
        context = request["controller_context"]
        memory = context["controller_memory"]
        require(memory == row["output"]["next_memory"] and memory["last_semantic_step"] == step,
            "Phase-release actual memory join")
        order = ["rear_left", "front_left", "rear_right", "front_right"]
        require([m["limb_id"] for m in memory["ordered_limb_memory"]] == order,
            "Phase-release independent phase order")
        phases = {m["limb_id"]:(m["gait_step"]-90*i) % 360 for i,m in enumerate(memory["ordered_limb_memory"])}
        old_delta, _ = parent.feedback(request["state"], request["command"], parent.expected_candidates()[3],
            parent.definition(), request["deterministic_baseline"])
        for i, leg in enumerate(row["feedback"]["legs"]):
            local = phases[leg["limb_id"]]
            weight = 0. if local < 72 else (1. if local <= 316 else (360-local)/44.)
            bounded = [min(3.5,max(-3.5,v)) for v in old_delta[2*i:2*i+2]]
            proposed = [weight*v for v in bounded] if weight else [0.,0.]
            require(leg["phase_release"] == dict(local_phase_step=local,
                scheduled_phase="swing" if local < 72 else "stance", weight=weight,
                parent_raw_correction_rad_s=old_delta[2*i:2*i+2], bounded_parent_correction_rad_s=bounded,
                proposed_correction_rad_s=proposed), "Phase-release independent taper receipt")
            require(leg["raw_combined_rad_s"] == proposed and proposed ==
                [r["canonical_velocity_delta_rad_s"] for r in response["ordered_corrections"][2*i:2*i+2]],
                "Phase-release independent tapered proposal")
    expected_count = step if step <= probe_steps else 0
    require(len(request["history"]["ordered_entries"]) == expected_count, "Phase-release bounded prefix history")
    require(row["activation_probe"] == dict(role_id=role["id"],candidate_index=role["candidate_index"],
            activation_step=role["activation_step"],baseline_probe_steps=probe_steps,
            phase="baseline_observation" if probe else "fixed_controller",history_entries=expected_count,
            features=context_features(request) if probe_steps and step == probe_steps else None,
            learned_selection=False), "Phase-release causal feature/onset join")
    baseline = request["deterministic_baseline"]["ordered_commands"]
    limits = request["safety_envelope"]["ordered_actuator_limits"]
    require(len(baseline) == len(limits) == len(resolved["ordered_commands"]) == len(row["native_targets"]) == 8, "Feedback population")
    for i,(base,limit,actual) in enumerate(zip(baseline,limits,resolved["ordered_commands"],strict=True)):
        require(limit["previous_applied_correction_rad_s"] == previous[i]
            and limit["maximum_absolute_correction_rad_s"] == cap
            and limit["maximum_slew_per_step_rad_s"] == slew, "Feedback envelope/history")
        raw = 0. if response is None or no_proposal else response["ordered_corrections"][i]["canonical_velocity_delta_rad_s"]
        if response is None or no_proposal or resolved["safe_no_actuation"]:
            expected = 0.
        else:
            bounded = max(-cap,min(cap,raw))
            expected = max(-cap,min(cap,max(previous[i]-slew,min(previous[i]+slew,bounded))))
        require(actual["applied_correction_rad_s"] == expected, "Feedback resolved correction")
        final = max(-base["maximum_target_speed_rad_s"],min(base["maximum_target_speed_rad_s"],
            base["combined_canonical_target_velocity_rad_s"]+expected))
        require(actual["final_canonical_target_velocity_rad_s"] == final and row["native_targets"][i] == final, "Feedback final target")
        if response is None or no_proposal:
            require(struct.pack("d",final) == struct.pack("d",base["combined_canonical_target_velocity_rad_s"]), "Feedback fallback bits")
