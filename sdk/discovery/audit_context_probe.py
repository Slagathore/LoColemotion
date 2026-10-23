"""Independent public-resolver bounds and observation joins for causal-prefix repertoire."""
import struct
from context_probe_control import PROBE_STEPS, context_features
from audit_gpu_portable_search import require


def validate_proposal(row, c, cell, previous):
    request = row["resolution_request"]["provider_request"]
    response = row["resolution_request"]["provider_response"]; resolved = row["resolution"]
    candidate = c["provider"]["candidates"][cell]
    cap, slew = [candidate[k] for k in ["maximum_absolute_correction_rad_s", "maximum_slew_per_step_rad_s"]]
    require(request["deterministic_baseline"] == row["composition"]["canonical_actuation"]
        and request["state"] == row["request"]["state"] and request["command"] == row["request"]["command"], "Feedback observation/baseline join")
    require(request["expected_model_id"] == candidate["id"] and request["provider_id"] == "context_probe_repertoire"
        and request["expected_provider_version"] == "context_probe_v1"
        and request["expected_training_corpus_id"] == "untrained_no_training_corpus", "Feedback candidate identity")
    step = request["state"]["semantic_step"]
    probe = step < PROBE_STEPS
    no_proposal = probe or candidate["mode"] == "baseline"
    if no_proposal:
        require(response is not None and response["status"] == "no_proposal"
                and response["ordered_corrections"] == [] and row["feedback"]["status"] == "baseline"
                and resolved["provider_status"] == "no_proposal" and not resolved["adaptation_applied"],
                "Context no-proposal prefix/role")
    else:
        require((response is None) == (row["feedback"]["status"] == "refused"), "Context feedback refusal join")
    expected_count = step if step <= PROBE_STEPS else 0
    require(len(request["history"]["ordered_entries"]) == expected_count, "Context bounded prefix history")
    require(row["context_probe"] == dict(phase="baseline_observation" if probe else "fixed_controller",
            planned_candidate_index=cell, selected_candidate_index=cell if not probe else None,
            history_entries=expected_count, features=context_features(request) if step == PROBE_STEPS else None,
            learned_selection=False), "Context causal feature/choice join")
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
