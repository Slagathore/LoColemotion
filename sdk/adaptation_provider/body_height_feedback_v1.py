"""Finite flat-ground torso-height feedback over the frozen body/posture reference."""
import hashlib
import json
import math
from pathlib import Path
from . import body_gain_feedback_v1 as parent
from . import stance_feedback_v1 as body

CONTRACT=Path(__file__).with_suffix(".json")
require=parent.require
SETTINGS=dict(nominal_target_height_m=.40,minimum_target_height_m=.28,reach_margin_m=.01,
    height_gain_s_inv=3.,vertical_damping=.5,maximum_vertical_velocity_m_s=.20)
GROUND=dict(kind="declared_fixed_flat_plane",height_m=0.,up_axis="canonical_y",measured_terrain_height=False)


def expected_candidates():
    old=parent.expected_candidates()
    return [dict(old[0],height_enabled=False),dict(old[1],height_enabled=False),
        dict(old[1],id="feedback_height_v1",height_enabled=True)]


def definition():
    value=json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value["schema_version"]=="locolemotion_body_height_feedback_v1"
        and value["candidate_count"]==3 and value["candidates"]==expected_candidates()
        and value["height_control"]==SETTINGS and value["ground_domain"]==GROUND
        and value["distal_capsule_radius_m"]==.03994872276483847
        and value["envelope_selection"]=="prospectively_declared_candidate_bound_host_envelope"
        and all(value[k] is False for k in ["trained","training_data_authority","physical_acceptance_authority",
            "release_authority","equivalence_authority"]),"Body-height definition")
    for key,name in [("parent_model","body_gain_feedback_v1.json"),("parent_implementation","body_gain_feedback_v1.py")]:
        path=CONTRACT.with_name(name)
        require(value[key]==dict(path="sdk/adaptation_provider/"+name,
            sha256=hashlib.sha256(path.read_bytes()).hexdigest()),"Body-height parent bytes")
    model=parent.definition();model.update(value);return model


def validate_geometry(compiled,model):
    parent.validate_geometry(compiled,model)
    sites=compiled["morphology"]["morphology_spec"]["contact_sites"]
    require(all(s["radius_m"]==model["distal_capsule_radius_m"] for s in sites),"Body-height capsule radius")


def validate_candidate(candidate):
    require(candidate in expected_candidates(),"Body-height candidate outside frozen family")


def feedback(state,command,candidate,model):
    validate_candidate(candidate)
    require(candidate["mode"]=="feedback","Feedback candidate required")
    # Exact parent calculation keeps the reference role's feedback bits intact.
    delta,detail=parent.feedback(state,command,parent.expected_candidates()[1],model)
    if not candidate["height_enabled"]:return delta,detail
    require(model["ground_domain"]==GROUND and model["height_control"]==SETTINGS,"Body-height ground/settings domain")
    gravity=body.vector(state["gravity_world_m_s2"])
    require(gravity[0]==gravity[2]==0. and gravity[1]<0.,"Body-height requires canonical y-up gravity")
    pose=state["base_pose_world"];rotation=body.rotation(pose["orientation_xyzw"])
    height=body.vector(pose["position_m"])[1]
    vertical_speed=body.vector(state["base_twist_world"]["linear_velocity_m_s"])[1]
    a,b,c=rotation[1];rho=math.hypot(a,b)
    settings=model["height_control"];limits=[]
    for leg in model["legs"]:
        anchor=body.vector(leg["hip_anchor_body_m"])
        limits.append(GROUND["height_m"]+model["distal_capsule_radius_m"]
            -sum(v*w for v,w in zip([a,b,c],anchor))+(leg["upper_length_m"]+leg["lower_length_m"])*rho)
    cap=min(limits)-settings["reach_margin_m"]
    target=max(settings["minimum_target_height_m"],min(settings["nominal_target_height_m"],cap))
    raw=settings["height_gain_s_inv"]*(target-height)-settings["vertical_damping"]*vertical_speed
    maximum=settings["maximum_vertical_velocity_m_s"]
    velocity=max(-maximum,min(maximum,raw))
    # A planted foot moves opposite the requested torso translation.
    foot_velocity=body.transform(rotation,[0.,-velocity,0.],transpose=True)
    angles={j["joint_id"]:j["position_rad"] for j in state["ordered_joint_observations"]}
    combined=list(delta)
    for i,(leg,receipt) in enumerate(zip(model["legs"],detail["legs"],strict=True)):
        _,jacobian=body.foot_geometry(leg,angles[leg["id"]+"_hip"],angles[leg["id"]+"_knee"])
        extra=body.inverse_velocity(jacobian,foot_velocity[:2],model["jacobian_damping_m"]) if receipt["support"] else [0.,0.]
        combined[2*i:2*i+2]=[v+w for v,w in zip(delta[2*i:2*i+2],extra)]
        receipt.update(height_translation_delta_rad_s=extra,raw_combined_rad_s=combined[2*i:2*i+2])
    require(all(math.isfinite(v) for v in combined),"Nonfinite body-height correction")
    detail["height_control"]=dict(ground_domain=GROUND,body_height_m=height,vertical_speed_m_s=vertical_speed,
        geometric_height_limits_m=limits,reach_limited_height_cap_m=cap,target_height_m=target,
        reach_cap_below_minimum_target=cap<settings["minimum_target_height_m"],
        raw_vertical_velocity_m_s=raw,requested_vertical_velocity_m_s=velocity,
        requested_foot_velocity_body_m_s=foot_velocity,vertical_velocity_limited=raw!=velocity)
    return combined,detail
