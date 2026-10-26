"""Protocol-only continuation using a separately recorded next observation."""
import copy
from actuation_recovery_mechanics import require
from adaptation_provider.retrieval import causal_history_v1 as history
from audit_gpu_batch_execution import same_bits


def following_request(core,policy,row,next_frame):
    previous=row["resolution_request"]["provider_request"];resolved=row["resolution"]
    step=previous["state"]["semantic_step"]
    require(resolved["adaptation_applied"] is True and resolved["provider_status"]=="applied"
        and next_frame["request"]["state"]["semantic_step"]==step+1,"Following applied command and next clock")
    memory=resolved["next_memory"];episode=memory["opaque_state"]["episode_id"]
    request=policy.bind(copy.deepcopy(next_frame["resolution_request"]["provider_request"]),
        copy.deepcopy(next_frame["stability"]),memory,episode)
    entries,boundary=history.append_resolved(core,previous,resolved)
    require(boundary is None,"Following actual history boundary")
    entries["ordered_entries"]=entries["ordered_entries"][-1:]
    for limit,applied in zip(request["safety_envelope"]["ordered_actuator_limits"],resolved["ordered_commands"],strict=True):
        limit["previous_applied_correction_rad_s"]=applied["applied_correction_rad_s"]
    request=history.attach(request,entries)
    require(same_bits(request["provider_memory"],memory)
        and request["provider_memory"]["opaque_state"]["plan"]["request_sha256"]==resolved["request_sha256"]
        and request["provider_memory"]["opaque_state"]["plan"]["correction"]==
            [x["applied_correction_rad_s"] for x in resolved["ordered_commands"]],"Following actual resolved plan")
    internal=policy.nominal_request(request)
    require(internal["provider_memory"]["opaque_state"]["previous_binding"]==resolved["request_sha256"],
        "Following nominal memory actual binding")
    missing=core.resolve_adaptation_v1(dict(schema_version="sporespore_adaptation_resolution_request_v1",
        provider_request=request,provider_response=None))
    require(missing["adaptation_applied"] is False and missing["world_build_count"]==0
        and missing["physics_state_modified"] is False,"Following request validation opens no world")
    return dict(request=request,validation_resolution=missing,synthetic_protocol_fixture=True,
        observation_generated_by_refined_action=False,next_action_predicted=False,
        native_continuation_verified=False,physical_acceptance_authority=False,training_data_authority=False)
