"""Prepare a bounded proposal after an explicit nominal allocation refusal."""
import copy
import numpy as np
from actuation_recovery_mechanics import array,xyz,require,command_envelope,resolve_correction
from hierarchical_force_policy_v8 import HANDOFF,digest,plain
from support_reach_geometry import support_reference

STRATEGY="project_actual_history_after_bound_nominal_refusal"


def reference(policy,request):
    state=request["state"];opaque=request["provider_memory"]["opaque_state"]
    q=array([x["position_rad"] for x in state["ordered_joint_observations"]],(8,),"Seed reference joints")
    position=xyz(state["base_pose_world"]["position_m"])
    quaternion=array([state["base_pose_world"]["orientation_xyzw"][k] for k in "xyzw"],(4,),"Seed reference orientation")
    frame=policy.tree.kinematics(position,quaternion,q);com=frame["whole_body_com"]
    target=np.array([com[0],policy.height,com[2]]) if state["semantic_step"]==HANDOFF else array(opaque["target_com"],(3,),"Seed reference anchor")
    contacts=request["controller_context"]["controller_memory"]["contact_packet"]["ordered_contacts"]
    ref=support_reference(policy.reach.evaluate(position,quaternion,q),
        {x["contact_site_id"]:x["presence"] and x["bears_support"] for x in contacts},
        float(position[1]),float(com[1]),policy.height,float(target[1]),policy.profile["reference_parameters"])
    target[1]=ref["target_com_height_m"]
    return target.tolist(),plain(ref)


def prepare(policy,request,failure):
    require(type(failure) is dict and set(failure)=={"step","profile_sha256","request_sha256","allocation","active_contacts",
        "target_com","support_reference","physical_acceptance_authority"}
        and failure["step"]==request["state"]["semantic_step"] and failure["profile_sha256"]==policy.sha
        and failure["request_sha256"]==digest(policy.core,request)
        and type(failure["allocation"]) is dict and {"accepted","prediction","selected"}<=set(failure["allocation"])
        and failure["allocation"]["accepted"] is False and failure["allocation"]["prediction"] is None
        and failure["allocation"]["selected"] is None and failure["physical_acceptance_authority"] is False,
        "History seed requires a bound nominal allocation refusal")
    target,ref=reference(policy,request)
    require(failure["target_com"]==target and failure["support_reference"]==ref,"History seed exact geometric reference")
    base=request["deterministic_baseline"]["ordered_commands"];limits=request["safety_envelope"]["ordered_actuator_limits"]
    entries=request["history"]["ordered_entries"]
    require(not request["deterministic_baseline"]["safe_no_actuation"] and len(entries)==1
        and entries[0]["semantic_step"]==request["state"]["semantic_step"]-1
        and [x["actuator_id"] for x in base]==[x["actuator_id"] for x in limits]==policy.actuators
        and [x["actuator_id"] for x in entries[0]["ordered_applied_corrections"]]==policy.actuators
        and all(x["maximum_absolute_correction_rad_s"]==3.5 and x["maximum_slew_per_step_rad_s"]==.08 for x in limits),
        "History seed ordered actual envelope")
    previous=[x["previous_applied_correction_rad_s"] for x in limits]
    require(previous==[x["canonical_velocity_delta_rad_s"] for x in entries[0]["ordered_applied_corrections"]],
        "History seed actual preceding corrections")
    envelope=command_envelope([x["combined_canonical_target_velocity_rad_s"] for x in base],
        [x["maximum_target_speed_rad_s"] for x in base],previous,[3.5]*8,[.08]*8)
    correction,velocity=resolve_correction(envelope,previous)
    proposal=dict(kind=STRATEGY,nominal_allocation_available=False,
        projection=dict(proposal=correction.tolist(),target=velocity.tolist()),
        target_com=target,support_reference=ref,force_certificate_for_selected_sequence=False)
    # Advance only reference/clock state. No nominal forces were produced.
    # This compatibility memory is explicitly marked as allocation-free by
    # the outer provider memory and must never be read as an allocation result.
    memory=copy.deepcopy(request["provider_memory"]);opaque=memory["opaque_state"]
    opaque.update(last_step=request["state"]["semantic_step"],target_com=target,previous_forces={},
        previous_binding=digest(policy.core,request))
    memory.update(sequence=request["state"]["semantic_step"]-HANDOFF+1,opaque_state_sha256=digest(policy.core,opaque))
    return proposal,memory
