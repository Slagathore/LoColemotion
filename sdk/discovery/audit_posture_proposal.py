"""Independent public-resolver bounds and observation joins for posture feedback."""
import struct
from audit_gpu_portable_search import require


def validate_proposal(row, c, cell, previous):
    request = row["resolution_request"]["provider_request"]
    response = row["resolution_request"]["provider_response"]; resolved = row["resolution"]
    candidate = c["provider"]["candidates"][cell]
    cap, slew = [candidate[k] for k in ["maximum_absolute_correction_rad_s", "maximum_slew_per_step_rad_s"]]
    require(request["deterministic_baseline"] == row["composition"]["canonical_actuation"]
        and request["state"] == row["request"]["state"] and request["command"] == row["request"]["command"], "Feedback observation/baseline join")
    require(request["expected_model_id"] == candidate["id"] and request["provider_id"] == "posture_feedback_search"
        and request["expected_provider_version"] == "posture_feedback_v1"
        and request["expected_training_corpus_id"] == "untrained_no_training_corpus", "Feedback candidate identity")
    require((response is None) == (row["feedback"]["status"] in ("baseline", "refused"))
        and (candidate["mode"] != "baseline" or row["feedback"]["status"] == "baseline"), "Feedback refusal join")
    baseline = request["deterministic_baseline"]["ordered_commands"]
    limits = request["safety_envelope"]["ordered_actuator_limits"]
    require(len(baseline) == len(limits) == len(resolved["ordered_commands"]) == len(row["native_targets"]) == 8, "Feedback population")
    for i,(base,limit,actual) in enumerate(zip(baseline,limits,resolved["ordered_commands"],strict=True)):
        require(limit["previous_applied_correction_rad_s"] == previous[i]
            and limit["maximum_absolute_correction_rad_s"] == cap
            and limit["maximum_slew_per_step_rad_s"] == slew, "Feedback envelope/history")
        raw = 0. if response is None else response["ordered_corrections"][i]["canonical_velocity_delta_rad_s"]
        if response is None or resolved["safe_no_actuation"]:
            expected = 0.
        else:
            bounded = max(-cap,min(cap,raw))
            expected = max(-cap,min(cap,max(previous[i]-slew,min(previous[i]+slew,bounded))))
        require(actual["applied_correction_rad_s"] == expected, "Feedback resolved correction")
        final = max(-base["maximum_target_speed_rad_s"],min(base["maximum_target_speed_rad_s"],
            base["combined_canonical_target_velocity_rad_s"]+expected))
        require(actual["final_canonical_target_velocity_rad_s"] == final and row["native_targets"][i] == final, "Feedback final target")
        if response is None:
            require(struct.pack("d",final) == struct.pack("d",base["combined_canonical_target_velocity_rad_s"]), "Feedback fallback bits")
