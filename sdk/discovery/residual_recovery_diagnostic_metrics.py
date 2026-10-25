"""Pure retained-data measurements; no dynamics, fitting or counterfactual claims."""
from collections import Counter
import math

from adaptation_provider import bounded_residual_features_v1 as features
from adaptation_provider.retrieval.causal_history_v1 import final_velocities
from residual_training_task import physical_violation

ACTUATORS=list(features.ACTUATORS)
JOINTS=list(features.JOINTS)
LEGS=list(features.LEGS)
HANDOFF=60
COMMON_STOP=80
SUBSTEPS=5


def require(condition,message):
    if not condition:raise ValueError(message)


def vector(value,n,label):
    require(isinstance(value,(list,tuple)) and len(value)==n and all(
        type(x) in (int,float) and math.isfinite(x) for x in value),label)
    return list(value)


def xyz(value):
    require(isinstance(value,dict) and set(value)==set("xyz"),"Recovery diagnosis vector keys")
    return vector([value[k] for k in "xyz"],3,"Recovery diagnosis vector")


def tilt(q):
    return math.acos(max(-1.,min(1.,1.-2*(q[4]*q[4]+q[5]*q[5]))))


def support_geometry(center,points):
    """Planar geometry only; two contacts have no area or static margin."""
    pts=sorted(set(tuple(vector(p,2,"Recovery diagnosis support point")) for p in points))
    center=vector(center,2,"Recovery diagnosis center")
    def cross(o,a,b):return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    def chain(values):
        result=[]
        for p in values:
            while len(result)>=2 and cross(result[-2],result[-1],p)<=0:result.pop()
            result.append(p)
        return result
    hull=(chain(pts)[:-1]+chain(pts[::-1])[:-1]) if len(pts)>1 else pts
    def segment(a,b):
        dx,dy=b[0]-a[0],b[1]-a[1];den=dx*dx+dy*dy
        t=0. if den==0. else max(0.,min(1.,((center[0]-a[0])*dx+(center[1]-a[1])*dy)/den))
        return math.hypot(center[0]-a[0]-t*dx,center[1]-a[1]-t*dy)
    distance=None;margin=None
    if len(hull)==1:distance=segment(hull[0],hull[0])
    elif len(hull)==2:distance=segment(*hull)
    elif len(hull)>=3:
        edges=list(zip(hull,hull[1:]+hull[:1],strict=True))
        margin=min(cross(a,b,center)/math.dist(a,b) for a,b in edges)
        distance=0. if margin>=0. else min(segment(a,b) for a,b in edges)
    return dict(unique_support_points=len(pts),hull_vertices=len(hull),
        com_projection_distance_to_support_hull_m=distance,
        signed_interior_margin_m=margin,force_feasibility_established=False)


def frame(row,previous,index):
    require(row["outer_step"]==index and row["backend"]=="cpu" and row["cell"]==0,
        "Recovery diagnosis controller order")
    state=row["request"]["state"];request=row["resolution_request"]["provider_request"]
    require(state==request["state"] and state["semantic_step"]==index
        and state["sample_time_s"]==index*features.DT,"Recovery diagnosis state/clock")
    commands=row["resolution"]["ordered_commands"];limits=request["safety_envelope"]["ordered_actuator_limits"]
    joints=state["ordered_joint_observations"]
    require([v["actuator_id"] for v in commands]==[v["actuator_id"] for v in limits]==ACTUATORS
        and [v["joint_id"] for v in joints]==JOINTS
        and all(v["validity"]["position"] and v["validity"]["velocity"] for v in joints),
        "Recovery diagnosis actuator/joint order")
    resolved=vector([v["applied_correction_rad_s"] for v in commands],8,"Recovery diagnosis resolved correction")
    final=vector([v["final_canonical_target_velocity_rad_s"] for v in commands],8,"Recovery diagnosis final command")
    baseline=vector([v["baseline_canonical_target_velocity_rad_s"] for v in commands],8,"Recovery diagnosis baseline")
    proposed=vector([v["proposed_correction_rad_s"] for v in commands],8,"Recovery diagnosis proposal")
    prior=vector([v["previous_applied_correction_rad_s"] for v in limits],8,"Recovery diagnosis previous correction")
    entries=request["history"]["ordered_entries"]
    require(len(entries)==(0 if index==0 else 1),"Recovery diagnosis continuous history")
    if previous is None:
        require(index==0 and prior==[0.]*8,"Recovery diagnosis initial history")
    else:
        require(previous["step"]==index-1 and prior==previous["resolved"]
            and entries[0]["semantic_step"]==index-1
            and final_velocities(entries[0])==previous["final"],
            "Recovery diagnosis actual previous-action join")
    require(all(v["maximum_absolute_correction_rad_s"]==3.5 and v["maximum_slew_per_step_rad_s"]==.08 for v in limits),
        "Recovery diagnosis unchanged correction bounds")
    require(type(row["output"]["actuation"]["safe_no_actuation"]) is bool,"Recovery diagnosis actuation flag")
    original=request["deterministic_baseline"]["ordered_commands"]
    speeds=vector([v["maximum_target_speed_rad_s"] for v in commands],8,"Recovery diagnosis speed bounds")
    require([v["actuator_id"] for v in original]==ACTUATORS
        and all(command["valid_through_step"]==index and 0.<speed<=3.5
            and speed==base["maximum_target_speed_rad_s"]
            and command["baseline_canonical_target_velocity_rad_s"]==base["combined_canonical_target_velocity_rad_s"]
            and abs(command["final_canonical_target_velocity_rad_s"])<=speed
            for command,base,speed in zip(commands,original,speeds,strict=True)),
        "Recovery diagnosis command validity and original speed bounds")
    native=row["native_observation"];q=vector(native["qpos"],15,"Recovery diagnosis native position")
    qv=vector(native["qvel"],14,"Recovery diagnosis native velocity")
    targets=vector(row["native_targets"],8,"Recovery diagnosis native target")
    require(targets==final and [v["position_rad"] for v in joints]==q[7:]
        and [v["velocity_rad_s"] for v in joints]==qv[6:],"Recovery diagnosis native/canonical join")
    detail=row["residual"]["decision"]
    raw=detail["raw_correction_rad_s"]
    if raw is not None:raw=vector(raw,8,"Recovery diagnosis raw actor output")
    require(detail["step"]==index and detail["status"]==row["resolution"]["provider_status"],
        "Recovery diagnosis provider status")
    flags={}
    for key in ("absolute_correction_clamped","slew_clamped","final_speed_clamped"):
        flags[key]=[v[key] for v in commands]
        require(all(type(v) is bool for v in flags[key]),"Recovery diagnosis resolver flag type")
    contacts=state["ordered_contact_observations"];supports=row["stability"]["ordered_support_contacts"]
    ids=[leg+"_foot" for leg in LEGS]
    require([v["contact_site_id"] for v in contacts]==[v["contact_site_id"] for v in supports]==ids,
        "Recovery diagnosis contact order")
    mask=[];loads=[];points=[];slips=[]
    for contact,support in zip(contacts,supports,strict=True):
        require(type(contact["presence"]) is bool and type(contact["bears_support"]) is bool
            and (not contact["bears_support"] or contact["presence"])
            and contact["presence"]==support["presence"] and contact["bears_support"]==support["bears_support"],
            "Recovery diagnosis support join")
        active=contact["presence"] and contact["bears_support"];mask.append(active)
        load=contact["normal_load_n"]
        if load is not None:
            vector([load],1,"Recovery diagnosis finite measured load");require(load>=0.,"Recovery diagnosis negative normal load")
        loads.append(load)
        if active:
            point=xyz(support["point_world_m"]);velocity=xyz(support["surface_relative_velocity_world_m_s"])
            points.append([point[0],point[2]]);slips.append(math.hypot(velocity[0],velocity[2]))
    center_native=vector(native["subtree_com"][1],3,"Recovery diagnosis whole-body center")
    center=[center_native[0],center_native[2],-center_native[1]]
    angular=xyz(state["base_twist_world"]["angular_velocity_rad_s"])
    linear=xyz(state["base_twist_world"]["linear_velocity_m_s"])
    geometry=support_geometry([center[0],center[2]],points)
    return dict(step=index,time_s=index*features.DT,qpos=q,qvel=qv,targets=targets,
        joint_position_rad=q[7:],joint_velocity_rad_s=qv[6:],baseline=baseline,proposed=proposed,
        raw_actor_output=raw,resolved=resolved,final=final,delivered=[a-b for a,b in zip(final,baseline,strict=True)],
        flags=flags,command_speed_limit_rad_s=speeds,support_mask=mask,support_count=sum(mask),normal_load_n=loads,
        tilt_rad=tilt(q),height_m=q[2],vertical_velocity_m_s=linear[1],
        horizontal_angular_speed_rad_s=math.hypot(angular[0],angular[2]),
        whole_body_center_of_mass_world_m=center,support_geometry=geometry,
        maximum_supported_planar_slip_speed_m_s=max(slips) if slips else None,
        minimum_supported_abs_sin_knee=min((abs(math.sin(q[8+2*i])) for i,m in enumerate(mask) if m),default=None),
        provider_status=detail["status"],provider_reason=detail["reason"],
        active_actor=detail["active_actor"],active_actor_model_sha256=detail["active_actor_model_sha256"],
        handoff_command=detail["recovery"]["handoff_command"],
        support_distance=row["resolution"]["support_distance"],safe_no_actuation=row["output"]["actuation"]["safe_no_actuation"])


def windows(outer_steps,failure):
    boundary=failure["internal_step"] if failure else outer_steps*SUBSTEPS+1
    return dict(before_failure=lambda step:step*SUBSTEPS<boundary,
        after_handoff_before_failure=lambda step:HANDOFF<=step and step*SUBSTEPS<boundary,
        common_handoff_window=lambda step:HANDOFF<=step<COMMON_STOP)


def numeric(values):
    require(all(type(v) in (int,float) and math.isfinite(v) for v in values),"Recovery diagnosis finite statistic")
    return dict(count=len(values),mean=math.fsum(values)/len(values) if values else None,
        minimum=min(values) if values else None,maximum=max(values) if values else None)


def summarize_frames(frames,failure):
    require(len(frames)>COMMON_STOP and [f["step"] for f in frames]==list(range(len(frames))),
        "Recovery diagnosis full controller population")
    require(failure is None or failure["internal_step"]>COMMON_STOP*SUBSTEPS,
        "Recovery diagnosis common window crossed first failure")
    result={}
    for name,predicate in windows(len(frames),failure).items():
        values=[f for f in frames if predicate(f["step"])]
        count=len(values)
        result[name]=dict(controller_rows=count,actuator_commands=8*count,
            provider_status_counts=dict(sorted(Counter(f["provider_status"] for f in values).items())),
            provider_reason_counts=dict(sorted(Counter(f["provider_reason"] for f in values).items())),
            support_count_histogram=dict(sorted(Counter(str(f["support_count"]) for f in values).items())),
            supported_commands_by_foot=[sum(f["support_mask"][i] for f in values) for i in range(4)],
            measured_normal_load_values=sum(v is not None for f in values for v in f["normal_load_n"]),
            unavailable_normal_load_values=sum(v is None for f in values for v in f["normal_load_n"]),
            clamp_counts={k:[sum(f["flags"][k][i] for f in values) for i in range(8)]
                for k in ("absolute_correction_clamped","slew_clamped","final_speed_clamped")},
            opposed_resolved_to_proposed_commands=[sum(f["resolved"][i]*f["proposed"][i]<0. for f in values) for i in range(8)],
            opposed_delivered_to_proposed_commands=[sum(f["delivered"][i]*f["proposed"][i]<0. for f in values) for i in range(8)],
            correction_gap_rad_s=[numeric([abs(f["resolved"][i]-f["proposed"][i]) for f in values]) for i in range(8)],
            resolved_correction_rad_s=[numeric([f["resolved"][i] for f in values]) for i in range(8)],
            delivered_velocity_difference_rad_s=[numeric([f["delivered"][i] for f in values]) for i in range(8)],
            joint_velocity_rad_s=[numeric([f["joint_velocity_rad_s"][i] for f in values]) for i in range(8)],
            tilt_rad=numeric([f["tilt_rad"] for f in values]),
            horizontal_angular_speed_rad_s=numeric([f["horizontal_angular_speed_rad_s"] for f in values]),
            com_projection_distance_m=numeric([f["support_geometry"]["com_projection_distance_to_support_hull_m"] for f in values
                if f["support_geometry"]["com_projection_distance_to_support_hull_m"] is not None]),
            slip_speed_m_s=numeric([f["maximum_supported_planar_slip_speed_m_s"] for f in values
                if f["maximum_supported_planar_slip_speed_m_s"] is not None]))
    last=max(f["step"] for f in frames if windows(len(frames),failure)["before_failure"](f["step"]))
    # A successful endpoint is explicitly horizon-censored, never an invented failure.
    snapshots={key:frames[step] for key,step in (("handoff_time",HANDOFF),("common_window_last",COMMON_STOP-1),
        ("last_pre_failure_or_horizon",last))}
    return dict(windows=result,snapshots=snapshots,terminal_is_horizon_censored=failure is None,
        entire_horizon_measured_normal_load_values=sum(v is not None for f in frames for v in f["normal_load_n"]),
        entire_horizon_unavailable_normal_load_values=sum(v is None for f in frames for v in f["normal_load_n"]))


def motor_profile(metadata,spec):
    p=metadata["actuator_profile"]
    require(metadata["observation_stage"]=="prepared_before_control"
        and metadata["force_stage"]=="completed_step_before_next_prepare"
        and spec["ordered_actuators"]==ACTUATORS and spec["ordered_joints"]==JOINTS
        and p["forcerange"]==metadata["force_ranges"]==spec["force_ranges"]
        and p["gear"]==[[1.,0.,0.,0.,0.,0.]]*8
        and p["forcelimited"]==[True]*8 and p["ctrllimited"]==[False]*8
        and p["gaintype"]==p["dyntype"]==p["trntype"]==[0]*8
        and p["biastype"]==[1]*8 and p["trnid"]==[[i,-1] for i in range(1,9)],
        "Recovery diagnosis native affine profile")
    gains=vector(spec["velocity_gains"],8,"Recovery diagnosis gains")
    require(all(g>0. for g in gains)
        and p["gainprm"]==[[g]+[0.]*9 for g in gains]
        and p["biasprm"]==[[0.,0.,-g]+[0.]*7 for g in gains],
        "Recovery diagnosis affine gain/bias")
    caps=[vector(x,2,"Recovery diagnosis force range") for x in spec["force_ranges"]]
    require(all(lo<0.<hi for lo,hi in caps),"Recovery diagnosis force range signs")
    return gains,caps


def force_sample(row,gains,caps):
    """Reconstruct the retained affine motor force at the pre-integration velocity."""
    control=vector(row["ctrl"],8,"Recovery diagnosis force control")
    velocity=vector(row["before_qvel"],14,"Recovery diagnosis force velocity")
    forces=vector(row["actuator_force_nm"],8,"Recovery diagnosis force")
    joints=vector(row["joint_force_nm"],8,"Recovery diagnosis joint force")
    labels=[value<=lo or value>=hi for value,(lo,hi) in zip(forces,caps,strict=True)]
    require(joints==forces and row["on_force_cap"]==labels
        and all(type(x) is bool for x in row["on_force_cap"]),"Recovery diagnosis force identity/cap labels")
    predicted=[max(lo,min(hi,g*u-g*speed)) for g,u,speed,(lo,hi)
        in zip(gains,control,velocity[6:],caps,strict=True)]
    error=max(abs(a-b) for a,b in zip(forces,predicted,strict=True))
    require(error<=1e-9,"Recovery diagnosis pre-integration affine force")
    return forces,labels,error


def trace_measurements(rows,frames,expected_failure,selection,gains,caps):
    boundary=expected_failure["internal_step"] if expected_failure else len(frames)*5+1
    stats={name:dict(count=0,force_cap_samples=[0]*8,absolute_force_sum=[0.]*8,
        maximum_absolute_force_nm=[0.]*8,absolute_velocity_error_sum=[0.]*8)
        for name in ("before_failure","after_handoff_before_failure","common_handoff_window")}
    first=None;previous=None;maximum_force_error=0.;count=0
    for step,row in enumerate(rows,1):
        outer=(step-1)//5
        require(outer<len(frames) and row["step"]==step and row["backend"]=="cpu" and row["cell"]==0,
            "Recovery diagnosis internal order")
        f=frames[outer];before=vector(row["before_qpos"],15,"Recovery diagnosis before position")
        bv=vector(row["before_qvel"],14,"Recovery diagnosis before velocity")
        q=vector(row["qpos"],15,"Recovery diagnosis completed position")
        v=vector(row["qvel"],14,"Recovery diagnosis completed velocity")
        require(row["ctrl"]==f["targets"] and (previous is None or
            (before==previous["qpos"] and bv==previous["qvel"])),"Recovery diagnosis held input/continuity")
        if (step-1)%5==0:
            require(before==f["qpos"] and bv==f["qvel"],"Recovery diagnosis prepared/internal join")
        forces,labels,error=force_sample(row,gains,caps)
        maximum_force_error=max(maximum_force_error,error)
        require(abs(row["time_s"]-step/600)<=1e-9 and row["overflow"]==0 and all(x==0 for x in row["warnings"])
            and row["batch_contacts"]==len(row["contacts"])
            and all(set(c)=={"native_index","world","geom","distance_m","position_m","frame"} for c in row["contacts"]),
            "Recovery diagnosis retained contact measurements")
        if first is None:
            first=physical_violation(row,selection)
            if f["safe_no_actuation"]:
                first=dict(internal_step=step,time_s=row["time_s"],
                    failure_codes=["safe_no_actuation"]+(first["failure_codes"] if first else []))
        masks=dict(before_failure=step<boundary,
            after_handoff_before_failure=300<step<boundary,common_handoff_window=300<step<=400)
        for name,include in masks.items():
            if not include:continue
            s=stats[name];s["count"]+=1
            for i in range(8):
                s["force_cap_samples"][i]+=int(labels[i]);s["absolute_force_sum"][i]+=abs(forces[i])
                s["maximum_absolute_force_nm"][i]=max(s["maximum_absolute_force_nm"][i],abs(forces[i]))
                s["absolute_velocity_error_sum"][i]+=abs(row["ctrl"][i]-bv[6+i])
        count=step;previous=row
    require(count==len(frames)*5 and first==expected_failure,"Recovery diagnosis full internal population/first failure")
    for s in stats.values():
        n=s["count"]
        s["force_cap_fraction"]=[x/n if n else None for x in s["force_cap_samples"]]
        s["mean_absolute_force_nm"]=[x/n if n else None for x in s.pop("absolute_force_sum")]
        s["mean_absolute_velocity_error_rad_s"]=[x/n if n else None for x in s.pop("absolute_velocity_error_sum")]
    return dict(internal_samples=count,first_failure=first,windows=stats,
        maximum_affine_force_reconstruction_error_nm=maximum_force_error,
        normal_contact_forces_retained=False,actuator_forces_are_contact_forces=False,
        force_time_is_solver_impulse=False,force_cap_occupancy_is_infeasibility_proof=False)


def paired_frames(frames,reference,trial,reference_trial):
    require(trial["group_id"]==reference_trial["group_id"] and trial["stage"]==reference_trial["stage"]
        and reference_trial["role"]=="challenge_only" and trial["mode"]=="early_selected"
        and len(frames)==len(reference),"Recovery diagnosis fresh pair identity")
    require(all(a["qpos"]==b["qpos"] and a["qvel"]==b["qvel"] for a,b in zip(frames[:61],reference[:61],strict=True))
        and all(a["targets"]==b["targets"] for a,b in zip(frames[:60],reference[:60],strict=True)),
        "Recovery diagnosis fresh prefix")
    def first(key):
        return next((dict(command=i,time_s=i*features.DT,left=reference[i][key],right=frames[i][key])
            for i in range(HANDOFF,len(frames)) if frames[i][key]!=reference[i][key]),None)
    common=range(HANDOFF,COMMON_STOP)
    return dict(reference_trial_id=reference_trial["trial_id"],identical_through_handoff_observation=True,
        first_different_native_target=first("targets"),first_different_native_position=first("qpos"),
        first_different_support_mask=first("support_mask"),
        common_window_tilt_difference_rad=numeric([frames[i]["tilt_rad"]-reference[i]["tilt_rad"] for i in common]),
        common_window_support_count_difference=numeric([frames[i]["support_count"]-reference[i]["support_count"] for i in common]),
        comparison_does_not_supply_fitting_or_selection=True,causal_generalization=False)
