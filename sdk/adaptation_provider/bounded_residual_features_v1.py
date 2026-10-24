"""Canonical state and actual one-command response for residual development."""
import copy
import math

from . import bounded_residual_ars_v1 as ars
from . import stance_feedback_v1 as geometry
from . import phase_release_feedback_v1 as phase
from .retrieval import causal_history_v1 as history

require = ars.require
DT = 1/120
SCHEMA = "locolemotion_residual_observation_v1"
LEGS = ("front_left","front_right","rear_left","rear_right")
JOINTS = tuple(leg+"_"+joint for leg in LEGS for joint in ("hip","knee"))
ACTUATORS = tuple(joint+"_motor" for joint in JOINTS)
MORPHOLOGY_FIELDS = ("torso_length_scale","torso_width_scale","upper_length_fraction",
                     "hip_span_scale","foot_radius_scale","front_limb_mass_scale")
DESCRIPTOR = dict(schema_version="sporespore_bounded_quadruped_descriptor_v1",
    morphology_id="qsdk_r05_generated_s169",torso_length_scale=1.0041015625,
    torso_width_scale=1.0031893004115227,upper_length_fraction=.5219571428571428,
    hip_span_scale=.9856413994169096,foot_radius_scale=.9987180691209617,
    front_limb_mass_scale=.975022758306782)
DOMAIN = dict(descriptor=DESCRIPTOR,ground_height_m=0.,canonical_up_axis="y",
    gravity_m_s2=9.8,gravity_absolute_tolerance_m_s2=1e-5,
    desired_forward_velocity_m_s=.2,minimum_height_m=.2,maximum_height_m=1.,
    maximum_tilt_rad=.6,maximum_linear_speed_m_s=10.,maximum_angular_speed_rad_s=20.,
    maximum_joint_position_rad=math.pi,maximum_joint_velocity_rad_s=20.,
    maximum_command_response_error_rad_s=40.,maximum_correction_rad_s=3.5,
    maximum_slew_per_command_rad_s=.08,maximum_final_speed_rad_s=3.5,
    empirical_recoverability_bound=False)
NAMES = (tuple("morphology_"+k for k in MORPHOLOGY_FIELDS) + ("height_m",)
    + tuple(prefix+"_"+axis for prefix in ("up_body","linear_velocity_body_m_s",
        "angular_velocity_body_rad_s","desired_velocity_body_m_s") for axis in "xyz")
    + tuple(j+"_"+suffix for suffix in ("position_rad","velocity_rad_s","baseline_command_rad_s","maximum_command_speed_rad_s",
        "previous_final_command_rad_s","previous_correction_rad_s","previous_response_error_rad_s") for j in JOINTS)
    + tuple(leg+"_phase_"+function for leg in LEGS for function in ("sin","cos"))
    + tuple(leg+"_observed_support" for leg in LEGS) + ("previous_action_available",))
DIMENSION = len(NAMES)


def schema():
    return dict(schema_version=SCHEMA,feature_names=list(NAMES),feature_count=DIMENSION,
        controller_dt_s=DT,history_entries=1,history_source="actual_prior_resolved_command",
        response_error="(current_position - prior_position) / dt - prior_issued_command",
        phase_source="current_output_memory_with_declared_limb_offsets",
        cycle_commands=360,domain=copy.deepcopy(DOMAIN),
        support_distance="maximum_normalized_mechanical_envelope_occupancy_not_case_density",
        confidence_semantics="declared_domain_indicator_not_calibrated_probability",
        engine_specific_inputs=False,privileged_motor_parameters=False,
        physical_acceptance_authority=False,release_authority=False)


def triple(value):
    require(isinstance(value,dict) and set(value)==set("xyz"),"Residual vector shape")
    return ars.vector([value[k] for k in "xyz"],3,"Residual vector finiteness")


def joints(state,step):
    require(type(state["semantic_step"]) is int and state["semantic_step"]==step
        and state["sample_time_s"]==step*DT,"Residual observation clock")
    rows=state["ordered_joint_observations"]
    require([r["joint_id"] for r in rows]==list(JOINTS)
        and all(r["validity"]["position"] is True and r["validity"]["velocity"] is True for r in rows),
        "Residual joint order/availability")
    return (ars.vector([r["position_rad"] for r in rows],8,"Residual joint positions"),
            ars.vector([r["velocity_rad_s"] for r in rows],8,"Residual joint velocities"))


def observation_binding(core,request):
    return core.canonicalize_json({k:request[k] for k in
        ("state","command","deterministic_baseline")})["sha256"]


def extract(core,request,previous_binding=None):
    state=request["state"];step=state["semantic_step"]
    require(type(step) is int and step>=0,"Residual step")
    require(request["descriptor"]==DESCRIPTOR,"Residual morphology domain")
    require(state["schema_version"]=="sporespore_state_frame_v1","Residual state schema")
    qpos,qvel=joints(state,step)
    command=request["command"]
    require(command["schema_version"]=="sporespore_motion_command_v2"
        and command["desired_planar_velocity_task_m_s"]==dict(x=.2,y=0.,z=0.)
        and command["desired_heading_rad"]==0. and command["desired_yaw_rate_rad_s"] is None
        and command["gait_family_id"]=="lateral_wave" and command["speed_class"]=="walk"
        and command["gait_amplitude"]==1. and command["phase_progression_mode"]=="clocked"
        and command["valid_from_step"]==command["valid_through_step"]==step,"Residual task domain")
    gravity=triple(state["gravity_world_m_s2"])
    require(gravity[0]==gravity[2]==0. and abs(gravity[1]+9.8)<=1e-5,"Residual gravity/ground domain")
    frame=state["task_frame"]
    require(triple(frame["forward_axis_world_unit"])==(1.,0.,0.)
        and triple(frame["lateral_axis_world_unit"])==(0.,0.,1.)
        and triple(frame["up_axis_world_unit"])==(0.,1.,0.)
        and frame["reference_yaw_rad"]==0.,"Residual task frame")
    pose=state["base_pose_world"];position=triple(pose["position_m"])
    rotation=geometry.rotation(pose["orientation_xyzw"])
    up=geometry.transform(rotation,[0.,1.,0.],transpose=True)
    linear=geometry.transform(rotation,triple(state["base_twist_world"]["linear_velocity_m_s"]),transpose=True)
    angular=geometry.transform(rotation,triple(state["base_twist_world"]["angular_velocity_rad_s"]),transpose=True)
    desired=geometry.transform(rotation,[.2,0.,0.],transpose=True)
    context=request["controller_context"]
    require(core.canonicalize_json(context["controller_memory"])["sha256"]==context["controller_memory_sha256"],
            "Residual controller memory digest")
    phases=phase.weights(context,step)
    local=[phases[leg]["local_phase_step"] for leg in LEGS]
    phase_values=[function(2*math.pi*p/360) for p in local for function in (math.sin,math.cos)]
    contacts=state["ordered_contact_observations"]
    require([r["contact_site_id"] for r in contacts]==[leg+"_foot" for leg in LEGS]
        and all(type(r["presence"]) is bool and type(r["bears_support"]) is bool
                and (not r["bears_support"] or r["presence"]) for r in contacts),"Residual contact order/validity")
    support=[float(r["presence"] and r["bears_support"]) for r in contacts]
    baseline=request["deterministic_baseline"]
    require(baseline["semantic_step"]==step and baseline["source_policy_id"]==phase.POLICY,
            "Residual baseline clock/policy")
    commands=baseline["ordered_commands"]
    require([r["actuator_id"] for r in commands]==list(ACTUATORS)
        and all(ars.finite(r["maximum_target_speed_rad_s"]) and 0<r["maximum_target_speed_rad_s"]<=3.5
                and r["valid_through_step"]==step for r in commands),
        "Residual command order/limits")
    targets=ars.vector([r["combined_canonical_target_velocity_rad_s"] for r in commands],8,"Residual baseline commands")
    speeds=ars.vector([r["maximum_target_speed_rad_s"] for r in commands],8,"Residual command speeds")
    require(all(abs(v)<=cap for v,cap in zip(targets,speeds,strict=True)),"Residual baseline exceeds own command limit")
    limits=request["safety_envelope"]["ordered_actuator_limits"]
    require([r["actuator_id"] for r in limits]==list(ACTUATORS)
        and all(r["maximum_absolute_correction_rad_s"]==3.5
                and r["maximum_slew_per_step_rad_s"]==.08 for r in limits),"Residual unchanged safety limits")
    previous_correction=ars.vector([r["previous_applied_correction_rad_s"] for r in limits],8,"Residual prior corrections")
    history.attach(request,request["history"])
    entries=request["history"]["ordered_entries"]
    require(len(entries)==(0 if step==0 else 1),"Residual requires continuous latest action history")
    previous_final=(0.,)*8;errors=(0.,)*8;request_sha=resolution_sha=None
    if step:
        entry=entries[0];oldpos,_=joints(entry["state"],step-1)
        require(entry["provider_status"] in history.STATUSES and type(entry["adaptation_applied"]) is bool
            and entry["adaptation_applied"]==(entry["provider_status"]=="applied"),"Residual past status")
        require(entry["semantic_step"]==step-1,"Residual previous action clock")
        require([r["actuator_id"] for r in entry["deterministic_baseline"]["ordered_commands"]]==list(ACTUATORS),
                "Residual prior action order")
        prior_baseline=entry["deterministic_baseline"]
        require(prior_baseline["semantic_step"]==step-1 and prior_baseline["source_policy_id"]==phase.POLICY
            and all(ars.finite(r["maximum_target_speed_rad_s"]) and 0<r["maximum_target_speed_rad_s"]<=3.5
                    and r["valid_through_step"]==step-1
                    and ars.finite(r["combined_canonical_target_velocity_rad_s"])
                    and abs(r["combined_canonical_target_velocity_rad_s"])<=r["maximum_target_speed_rad_s"]
                    for r in prior_baseline["ordered_commands"]),"Residual prior command clock/limits")
        issued=history.final_velocities(entry)
        previous_final=ars.vector(issued,8,"Residual actual issued command")
        require([r["canonical_velocity_delta_rad_s"] for r in entry["ordered_applied_corrections"]]
                ==list(previous_correction),"Residual actual prior correction join")
        if previous_binding is not None:
            require(observation_binding(core,entry)==previous_binding["observation_sha256"]
                and entry["request_sha256"]==previous_binding["request_sha256"],
                "Residual crossed prior observation/action")
        request_sha,resolution_sha=entry["request_sha256"],entry["resolution_receipt_sha256"]
        errors=tuple((a-b)/DT-u for a,b,u in zip(qpos,oldpos,previous_final,strict=True))
    else:
        require(not any(previous_correction) and previous_binding is None,"Residual fresh episode history")
    height=position[1];tilt=math.acos(max(-1.,min(1.,up[1])))
    occupancy=max(abs(height-.6)/.4,tilt/.6,
        math.sqrt(sum(v*v for v in linear))/10,math.sqrt(sum(v*v for v in angular))/20,
        max(abs(v) for v in qpos)/math.pi,max(abs(v) for v in qvel)/20,
        max(abs(v) for v in targets)/3.5,max(abs(v) for v in previous_final)/3.5,
        max(abs(v) for v in previous_correction)/3.5,max(abs(v) for v in errors)/40)
    require(ars.finite(occupancy) and occupancy<=1.,"Residual outside declared mechanical domain")
    values=tuple(DESCRIPTOR[k] for k in MORPHOLOGY_FIELDS)+(height,)+tuple(up)+tuple(linear)+tuple(angular)+tuple(desired)
    values+=qpos+qvel+targets+speeds+previous_final+previous_correction+errors+tuple(phase_values)+tuple(support)+(float(step>0),)
    values=ars.vector(values,DIMENSION,"Residual complete finite observation")
    return dict(schema_version=SCHEMA,names=list(NAMES),values=list(values),history_entries=len(entries),
        previous_semantic_step=step-1 if step else None,previous_request_sha256=request_sha,
        previous_resolution_sha256=resolution_sha,exact_local_phase_commands=local,
        support_distance=occupancy,confidence_is_calibrated=False)
