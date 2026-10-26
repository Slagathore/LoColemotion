"""Arithmetic audit of retained forecasts; no new dynamics or interventions."""
import copy
import math
import numpy as np
from actuation_recovery_mechanics import require,array,command_envelope,resolve_correction,motor_torque,torque_envelope
from predictive_command_selection_v2 import validate,guard
from predictive_sequence_v1 import commands


def clamp(x,lo,hi):
    return max(lo,min(hi,x))


def close(a,b,label):
    require(np.allclose(a,b,rtol=1e-12,atol=1e-12),label)


def specification(value):
    require(set(value)=={"joint_ids","limits","gains","ranges","geom_bodies"},"Authority specification fields")
    require(len(value["joint_ids"])==8 and len(set(value["joint_ids"]))==8
        and all(isinstance(x,str) for x in value["joint_ids"]),"Authority joint identities")
    limits=array(value["limits"],(8,2),"Authority limits")
    gains=array(value["gains"],(8,),"Authority gains")
    ranges=array(value["ranges"],(8,2),"Authority torque ranges")
    require(np.all(limits[:,0]<limits[:,1]) and np.all(gains>0)
        and np.all(ranges[:,0]<0) and np.all(ranges[:,1]>0),"Authority valid actuator domain")
    require(len(value["geom_bodies"])==10 and value["geom_bodies"][0]=="world"
        and len(set(value["geom_bodies"]))==10,"Authority geometry identities")
    return limits,gains,ranges


def contact_loads(row,spec):
    """Map the retained conic force vector, including scalar joint-limit rows."""
    prediction=row["prediction"];solution=prediction["solution"];forces=solution["force"]
    require(solution["accepted"] is True and all(math.isfinite(x) for x in forces),"Authority finite solved forces")
    cursor=0;loads={};seen=set();seen_limits=set()
    for item in prediction["constraints"]:
        if item["kind"]=="joint_limit":
            joint=item["joint_id"];require(joint in spec["joint_ids"] and joint not in seen_limits,"Authority joint-limit identity")
            j=spec["joint_ids"].index(joint);q=row["before_qpos"][7+j];lo,hi=spec["limits"][j]
            require(q<lo or q>hi,"Authority active joint limit");seen_limits.add(joint)
            require(cursor<len(forces),"Authority scalar limit force block");cursor+=1
        else:
            require(item["kind"]=="contact","Authority supported constraint")
            index=item["native_index"];require(type(index) is int and 0<=index<len(row["contacts"])
                and index not in seen,"Authority contact index");seen.add(index)
            contact=row["contacts"][index];geom=contact["geom"]
            require(len(geom)==2 and geom[0]==0 and type(geom[1]) is int and 1<=geom[1]<10
                and contact["distance_m"]<0 and item["body_id"]==spec["geom_bodies"][geom[1]],
                "Authority contact geometry join")
            require(cursor+3<=len(forces),"Authority contact force block")
            loads[item["body_id"]]=loads.get(item["body_id"],0.)+forces[cursor];cursor+=3
    require(cursor==len(forces),"Authority exact force population")
    require(seen=={i for i,c in enumerate(row["contacts"]) if c["distance_m"]<0},"Authority complete penetrating contacts")
    required_limits={spec["joint_ids"][j] for j,(lo,hi) in enumerate(spec["limits"])
        if row["before_qpos"][7+j]<lo or row["before_qpos"][7+j]>hi}
    require(seen_limits==required_limits,"Authority complete active limits")
    return loads


def scalar_guards(row,spec):
    q=row["qpos"];v=row["qvel"];reasons=[];violations=[]
    for j,(lo,hi) in enumerate(spec["limits"]):
        low=lo+3.5/600.-2e-6;high=hi-3.5/600.+2e-6
        if q[7+j]<low or q[7+j]>high:
            reasons.append("joint_position_margin")
            violations.append(dict(joint=spec["joint_ids"][j],position_rad=q[7+j],bounds_rad=[low,high]))
        if abs(v[6+j])>3.5+2e-6:reasons.append("joint_speed_cap")
    tilt=math.acos(clamp(1.-2.*(q[4]**2+q[5]**2),-1.,1.))
    if q[2]<.25:reasons.append("height")
    if tilt>.6:reasons.append("tilt")
    if any(1 in c["geom"] for c in row["contacts"]):reasons.append("torso_contact")
    return sorted(set(reasons)),violations,tilt


def diagnose(value,knots,result,spec):
    validate(value);limits,gains,ranges=specification(spec)
    points=array(knots,(4,8),"Authority bounded control points")
    require(np.all(np.abs(points)<=3.5),"Authority knot domain")
    require(result["planned_intervals"]==66 and 1<=len(result["rows"])<=66,"Authority declared horizon")
    require(result["future_baseline_assumption"]=="current deterministic baseline held constant"
        and all(result[k] is False for k in ("future_observations_used","future_recorded_actions_used",
            "public_future_envelope_equivalence","trained","physical_acceptance_authority","release_authority"))
        and result["native_worlds"]==result["native_physics_steps"]==0,"Authority retained-only scope")
    before=copy.deepcopy((value,knots,result,spec))
    vector_corrections,vector_targets=commands(value,knots,66)
    previous=list(value["previous_correction"]);q=list(value["qpos"]);v=list(value["qvel"])
    trace=[];interval_reasons=[];first_guard=None
    cap_lower=[0]*8;cap_upper=[0]*8;braking_positive=[0]*8;frozen_torque=[0]*8
    absolute_bound=[0]*8;slew_bound=[0]*8;speed_bound=[0]*8
    front_geometry=front_loaded=rear_loaded=0;max_torque_error=0.
    for offset,interval in enumerate(result["rows"]):
        require(interval["offset"]==offset,"Authority consecutive intervals")
        position=offset*3/65.;lo=min(int(position),2);alpha=position-lo
        proposed=[(1-alpha)*float(points[lo,j])+alpha*float(points[lo+1,j]) for j in range(8)]
        low=[max(-3.5,p-.08) for p in previous];high=[min(3.5,p+.08) for p in previous]
        correction=[clamp(x,l,h) for x,l,h in zip(proposed,low,high)]
        target=[clamp(b+c,-s,s) for b,c,s in zip(value["baseline"],correction,value["speeds"])]
        envelope=command_envelope(value["baseline"],value["speeds"],previous,[3.5]*8,[.08]*8)
        vc,vt=resolve_correction(envelope,proposed)
        for actual,expected in ((interval["correction"],correction),(interval["target"],target),
            (vector_corrections[offset],correction),(vector_targets[offset],target),(vc,correction),(vt,target)):
            close(actual,expected,"Authority scalar/vector projection")
        for j in range(8):
            absolute_bound[j]+=int(abs(correction[j])==3.5)
            slew_bound[j]+=int(correction[j] in (previous[j]-.08,previous[j]+.08))
            speed_bound[j]+=int(abs(target[j])==value["speeds"][j])
        forecast=interval["forecast"]
        require(forecast["accepted"] is True and forecast["planned_steps"]==forecast["completed_steps"]==5
            and len(forecast["rows"])==5,"Authority complete finite forecast required")
        close(forecast["held_target"],target,"Authority held target")
        reasons=set()
        for step,row in enumerate(forecast["rows"]):
            require(row["step"]==step and row["prediction"]["accepted"] is True,"Authority finite step")
            array(row["qpos"],(15,),"Authority post position");array(row["qvel"],(14,),"Authority post velocity")
            close(row["before_qpos"],q,"Authority position chain");close(row["before_qvel"],v,"Authority velocity chain")
            force=[clamp(float(gains[j])*(target[j]-v[6+j]),*map(float,ranges[j])) for j in range(8)]
            actual=row["prediction"]["actuator_force"]
            close(actual,force,"Authority retained velocity-motor force")
            close(motor_torque(target,v[6:],gains,ranges),force,"Authority scalar/vector motor force")
            max_torque_error=max(max_torque_error,max(abs(a-b) for a,b in zip(actual,force)))
            torque_low,torque_high=torque_envelope(envelope,v[6:],gains,ranges)
            scalar_low=[clamp(float(gains[j])*(clamp(value["baseline"][j]+low[j],-value["speeds"][j],value["speeds"][j])-v[6+j]),*map(float,ranges[j])) for j in range(8)]
            scalar_high=[clamp(float(gains[j])*(clamp(value["baseline"][j]+high[j],-value["speeds"][j],value["speeds"][j])-v[6+j]),*map(float,ranges[j])) for j in range(8)]
            close(torque_low,scalar_low,"Authority reachable lower torque");close(torque_high,scalar_high,"Authority reachable upper torque")
            for j in range(8):
                cap_lower[j]+=int(force[j]==ranges[j,0]);cap_upper[j]+=int(force[j]==ranges[j,1])
                braking_positive[j]+=int(force[j]==ranges[j,0] and v[6+j]>0)
                frozen_torque[j]+=int(scalar_low[j]==scalar_high[j])
            loads=contact_loads(row,spec)
            front_geometry+=int(any(n.startswith("front_") for n in loads))
            front_loaded+=int(any(n.startswith("front_") and f>0 for n,f in loads.items()))
            rear_loaded+=int(any(n.startswith("rear_") and f>0 for n,f in loads.items()))
            failures,violations,tilt=scalar_guards(row,spec);reasons.update(failures)
            if failures and first_guard is None:first_guard=dict(interval=offset,step=step,reasons=failures)
            q=list(row["qpos"]);v=list(row["qvel"])
            close(row["prediction"]["post_velocity"],v,"Authority predicted velocity join")
            close(row["prediction"]["post_joint_position"],q[7:],"Authority predicted joint join")
            trace.append(dict(interval=offset,step=step,forecast_time_s=(offset*5+step+1)/600.,
                torque_nm=force,reachable_lower_torque_nm=scalar_low,reachable_upper_torque_nm=scalar_high,
                joint_position_rad=q[7:],joint_velocity_rad_s=v[6:],height_m=q[2],tilt_rad=tilt,
                contact_normal_forces_n=loads,guard_reasons=failures,joint_margin_violations=violations))
        require(sorted(reasons)==interval["guard_reasons"]==guard(forecast,limits),"Authority scalar/vector interval guards")
        require(not reasons or offset==len(result["rows"])-1,"Authority stop at first rejected interval")
        close(forecast["final_qpos"],q,"Authority forecast final position");close(forecast["final_qvel"],v,"Authority forecast final velocity")
        interval_reasons.append(sorted(reasons));previous=correction
    valid=sum(not x for x in interval_reasons)
    require(result["valid_intervals"]==valid and result["eligible"]==(valid==66)
        and result["attempted_intervals"]==len(interval_reasons)
        and result["completed_predicted_steps"]==len(trace)
        and result["rejection_reasons"]==interval_reasons[-1],"Authority exact finite outcome")
    require(before==(value,knots,result,spec),"Authority immutable inputs")
    bounds=[[clamp(b-3.5,-s,s),clamp(b+3.5,-s,s)] for b,s in zip(value["baseline"],value["speeds"])]
    return dict(command=value["command"],accepted=result["eligible"],valid_intervals=valid,
        predicted_steps=len(trace),first_guard=first_guard,joint_ids=spec["joint_ids"],
        lower_force_cap_steps=cap_lower,upper_force_cap_steps=cap_upper,
        lower_cap_while_positive_velocity_steps=braking_positive,
        unchanged_torque_across_interval_envelope_steps=frozen_torque,
        absolute_correction_bound_intervals=absolute_bound,slew_bound_intervals=slew_bound,
        target_speed_bound_intervals=speed_bound,held_baseline_absolute_target_bounds=bounds,
        front_geometric_contact_steps=front_geometry,front_positive_normal_force_steps=front_loaded,
        rear_positive_normal_force_steps=rear_loaded,maximum_torque_reconstruction_error=max_torque_error,
        terminal=trace[-1],trace=trace,retained_forecasts_only=True,new_forecasts=0,worlds_opened=0,
        solver_steps=0,local_torque_ranges_are_counterfactual_trajectories=False,
        contact_count_proves_dynamic_feasibility=False,global_infeasibility_established=False,
        baseline_approximation_error_measured=False,actual_native_transfer_verified=False,
        recovery_benefit_established=False,training_data_authority=False,tier2_qualified=False,
        tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False)
