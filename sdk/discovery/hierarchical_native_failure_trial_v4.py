"""Reconstruct the consumed dynamic trial and its untransferred terminal command."""
import argparse
from contextlib import ExitStack
import hashlib
import json
import math
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from collections import Counter

import mujoco
import numpy as np
from audit_gpu_batch_execution import same_bits,finite_vector,timing_summary,read_jsonl
from audit_gpu_portable_search import validate_observation
from body_height_diagnostic import physical_violation
from gpu_measurement_probe import write_new
from motor_effectiveness_task import condition_inputs,expected_actuator_arrays
from hierarchical_native_task_v6 import ROOT,FLAGS,declaration,initial_arrays,require,sha,provider,controller_contract,bridge,read
from causal_force_control import ForceController,terminal_error
from hierarchical_native_task_v6 import profile_for
from hierarchical_native_task_v6 import controller_for
from residual_recovery_metrics import transitions,paired_prefix


from hierarchical_native_trial_audit_v6 import reference_checks,motor_checks,reconstructed_kinematics,optimization_statistics


def audit_partial_trial(folder,plan,c,core_path,core,expected_model=None):
    require(read(folder/"plan.json")==plan,"Residual audit plan")
    result=read(folder/"result.json")
    require(all(result.get(k)==v for k,v in plan.items()) and result["completed"] is False
        and result["controller_closed"] is True,"Residual incomplete/crossed trial")
    require(plan["trial_id"]=="hierarchy_hold_left_075_train_001" and c["outer_steps"]==1440
        and result["outer_rows"]==120 and result["internal_rows"]==595
        and result["error"]=="ValueError: Residual terminal provider failure","Failure exact partial denominator")
    for key in ("setup_s","graph_capture_s"):
        require(provider.ars.finite(result[key]) and result[key]>=0.,"Residual setup timing")
    require(result["graph_capture_s"]==0.,"Residual CPU graph identity")
    for name in ("controller","trace","timing"):
        require(sha(folder/(name+".jsonl"))==result["hashes"][name],"Residual raw digest")
    expected,xml,spec=condition_inputs(core_path,dict(c,core_sha256=sha(core_path)),plan["condition_id"])
    compiled=read(folder/"compiled.json");metadata=read(folder/"native-model.json")
    require(compiled==expected and read(folder/"inputs.json")==spec
        and (folder/"model.xml").read_text(encoding="utf-8")==xml,"Residual model/compiler inputs")
    for name,key in (("model.xml","model_sha256"),("inputs.json","inputs_sha256"),("compiled.json","compiled_sha256")):
        require(sha(folder/name)==metadata[key],"Residual native metadata digest")
    require(metadata["condition_id"]==plan["condition_id"]
        and metadata["actuator_profile"]==expected_actuator_arrays(spec)
        and metadata["force_ranges"]==spec["force_ranges"]
        and metadata["ordered_bodies"]==["world"]+compiled["morphology"]["ordered_body_ids"]
        and metadata["body_rootid"]==[0]+[1]*9
        and metadata["observation_stage"]=="prepared_before_control"
        and metadata["force_stage"]=="completed_step_before_next_prepare"
        and metadata["dynamics_dtype"]=="float64" and metadata["initial_values"]==c["initial_values"],
        "Residual native topology/profile/stages")
    artifact=read(folder/"provider-model.json")
    require(expected_model is not None and artifact==expected_model,"Recovery crossed frozen artifact")
    model=provider.FrozenModel.load(core,artifact)
    require("sha256:"+sha(folder/"provider-model.json")==model.sha256
        ==metadata["provider_model_sha256"]==result["provider_model_sha256"],"Residual model byte identity")
    profile=profile_for(plan["role"],compiled,spec)
    require(read(folder/"force-profile.json")==profile
        and metadata["force_profile_sha256"]==sha(folder/"force-profile.json"),"Force exact configured profile")
    controller=controller_for(plan["role"],core,compiled,c,model,plan["trial_id"],profile)
    controls=[];applied=nonzero=refusals=safe=0;solver_witness=[]
    reference_count=0;geometry_error=0.;optimization_count=0;optimization_reports=[]
    dynamics=None
    if plan["role"]=="hierarchy_hold":
        from floating_base_dynamics import FloatingDynamics
        from floating_base_dynamics_inputs import native_parameters
        native=native_parameters(xml,profile["morphology_spec"])
        require(native["joint_inertia_kg_m2"]==profile["parameters"]["joint_inertia_kg_m2"],"Dynamic native joint inertia")
        dynamics=FloatingDynamics(profile["morphology_spec"],native["joint_inertia_kg_m2"])
    nominal=controller.force_policy.height;prior_height=nominal
    try:
        for step,row in enumerate(read_jsonl(folder/"controller.jsonl")):
            require(step<120 and (row["backend"],row["cell"],row["outer_step"])==("cpu",0,step),"Residual controller order")
            validate_terminal(row,step)
            validate_observation(row,metadata,compiled)
            require(same_bits(reconstructed_kinematics(row,compiled,metadata),row["kinematics"]),"Residual endpoint/native join")
            if step==119:
                with capture_failure(solver_witness,row,profile):
                    expected=controller.step(row["request"]["state"],row["stability"],row["kinematics"])
            else:expected=controller.step(row["request"]["state"],row["stability"],row["kinematics"])
            require(all(key in row and same_bits(value,row[key]) for key,value in expected.items()),"Residual independent control replay")
            if 60<=step<119:
                check=reference_checks(row,controls[-1],profile,plan["role"],nominal,prior_height,controller.force_policy.reach,metadata,dynamics)
                prior_height=check["height"];reference_count+=1
                geometry_error=max(geometry_error,check["geometry_error_m"])
                if check["optimization"] is not None:
                    optimization_count+=1
                    optimization_reports.append(check["optimization"])
            receipt=row["resolution"];commands=receipt["ordered_commands"]
            require(receipt["world_build_count"]==0 and receipt["physics_state_modified"] is False
                and receipt["physical_acceptance_authority"] is False,"Residual resolver authority")
            applied+=int(receipt["adaptation_applied"])
            nonzero+=int(any(r["applied_correction_rad_s"]!=0. for r in commands))
            refusals+=int(receipt["fallback_reason"] not in ("none","provider_absent","provider_no_proposal"))
            safe+=int(row["output"]["actuation"]["safe_no_actuation"])
            controls.append(row)
    finally:controller.close()
    require(len(controls)==120 and len(solver_witness)==1,"Failure complete partial control/solver witness")
    qpos,qvel=initial_arrays(spec,plan);last=None;eps=2**-52
    metric=dict(minimum_height_m=math.inf,maximum_tilt_rad=0.,torso_contact_steps=0,
        ground_contact_steps=0,nonzero_force_steps=0,safe_no_actuation_steps=safe,first_physical_violation=None)
    positions=hashlib.sha256();rows=0;motor_error=prepared_error=held_error=0.;prepared_count=dynamic_samples=0
    for index,row in enumerate(read_jsonl(folder/"trace.jsonl")):
        step=index+1
        require(step<=595 and (row["backend"],row["cell"],row["step"])==("cpu",0,step),"Residual internal order")
        for name,length in (("qpos",15),("before_qpos",15),("qvel",14),("before_qvel",14),
                            ("ctrl",8),("actuator_force_nm",8),("joint_force_nm",8)):
            require(finite_vector(row[name],length),"Residual finite native population")
        require(same_bits(row["before_qpos"],last["qpos"] if last else qpos)
            and same_bits(row["before_qvel"],last["qvel"] if last else qvel),"Residual native state continuity")
        control=controls[(step-1)//5]
        require(same_bits(row["ctrl"],control["native_targets"]),"Residual held solver input differs")
        if (step-1)%5==0:
            require(same_bits(row["before_qpos"],control["native_observation"]["qpos"])
                and same_bits(row["before_qvel"],control["native_observation"]["qvel"]),"Residual prepared-state clock")
            now=control["native_observation"]["time_s"]
            require(math.isfinite(now) and abs(now-(step-1)*c["timestep_s"])<=4*eps*step*step*c["timestep_s"],"Residual observation time")
        require(math.isfinite(row["time_s"]) and abs(row["time_s"]-step*c["timestep_s"])<=4*eps*step*step*c["timestep_s"],"Residual internal time")
        require(abs(sum(x*x for x in row["qpos"][3:7])-1.)<=128*eps,"Residual native quaternion")
        require(row["warnings"]==[0]*c["cpu_warning_count"] and type(row["overflow"]) is int and row["overflow"]==0
            and type(row["nefc"]) is int and 0<=row["nefc"]<=c["njmax"],"Residual native warning/capacity")
        require(row["on_force_cap"]==[f<=lo or f>=hi for f,(lo,hi) in zip(row["actuator_force_nm"],spec["force_ranges"],strict=True)],
            "Residual force-cap labels")
        for force,joint,(lo,hi) in zip(row["actuator_force_nm"],row["joint_force_nm"],spec["force_ranges"],strict=True):
            require(lo-32*eps*abs(lo)<=force<=hi+32*eps*abs(hi)
                and abs(force-joint)<=32*eps*max(abs(lo),abs(hi)),"Residual force bounds/named sensors")
        require(type(row["batch_contacts"]) is int and 0<=row["batch_contacts"]<=c["naconmax"],"Residual contact capacity")
        slots=[]
        for contact in row["contacts"]:
            require(type(contact["world"]) is int and contact["world"]==0
                and type(contact["native_index"]) is int and 0<=contact["native_index"]<row["batch_contacts"],"Residual contact world/index")
            pair=contact["geom"]
            require(len(pair)==2 and 0 in pair and pair[0]!=pair[1]
                and all(type(g) is int and 0<=g<10 for g in pair),"Residual contact geometry")
            require(finite_vector(contact["position_m"],3) and finite_vector(contact["frame"],9)
                and math.isfinite(contact["distance_m"]),"Residual finite contact")
            slots.append(contact["native_index"])
        require(sorted(slots)==list(range(row["batch_contacts"])),"Residual contact denominator")
        checked=motor_checks(row,control,profile,c,plan["role"])
        motor_error=max(motor_error,checked["motor_model_error_nm"])
        if checked["requested_torque_error_nm"] is not None:
            dynamic_samples+=1;held_error=max(held_error,checked["requested_torque_error_nm"])
            if checked["prepared"]:
                prepared_count+=1;prepared_error=max(prepared_error,checked["requested_torque_error_nm"])
        height=row["qpos"][2]
        tilt=math.acos(max(-1.,min(1.,1.-2*(row["qpos"][4]**2+row["qpos"][5]**2))))
        metric["minimum_height_m"]=min(metric["minimum_height_m"],height)
        metric["maximum_tilt_rad"]=max(metric["maximum_tilt_rad"],tilt)
        metric["torso_contact_steps"]+=int(any(1 in contact["geom"] for contact in row["contacts"]))
        metric["ground_contact_steps"]+=int(bool(row["contacts"]))
        metric["nonzero_force_steps"]+=int(any(f!=0. for f in row["actuator_force_nm"]))
        if metric["first_physical_violation"] is None:metric["first_physical_violation"]=physical_violation(row,c["selection"])
        positions.update(json.dumps(row["qpos"],separators=(",",":"),allow_nan=False).encode("utf-8")+b"\n")
        last=row;rows+=1
    require(rows==595,"Failure complete retained internal samples")
    terminal=controls[-1]
    require(same_bits(last["qpos"],terminal["native_observation"]["qpos"])
        and same_bits(last["qvel"],terminal["native_observation"]["qvel"])
        and last["time_s"]==terminal["native_observation"]["time_s"],
        "Failure terminal observation must follow last completed step")
    metric["forward_displacement_m"]=last["qpos"][0]-spec["initial_qpos"][0]
    failures=[]
    for name,bad in (("height",metric["minimum_height_m"]<c["selection"]["minimum_height_m"]),
        ("tilt",metric["maximum_tilt_rad"]>c["selection"]["maximum_tilt_rad"]),
        ("torso_contact",metric["torso_contact_steps"]>0),("safe_no_actuation",bool(safe))):
        if bad:failures.append(name)
    expected_dynamic=59
    require(optimization_count==prepared_count==expected_dynamic and dynamic_samples==5*expected_dynamic,
        "Dynamic complete optimization and motor denominator")
    timings=timing_summary(list(read_jsonl(folder/"timing.jsonl")),dict(c,outer_steps=119))
    return dict(plan,controller_rows=len(controls),internal_rows=rows,provider_model_sha256=model.sha256,
        control_applied_commands=applied,nonzero_correction_commands=nonzero,refused_commands=refusals,
        diagnostic_metrics=metric,diagnostic_failure_codes=failures,diagnostic_eligible=False,
        native_horizon_completed=False,terminal_command=119,terminal_transferred=False,terminal_domain_witness=solver_witness[0],terminal_qp_solves=0,
        joint_prediction_gap=prediction_gap(controls,list(read_jsonl(folder/"trace.jsonl")),profile),
        official_quality_m_s=None,selection_authority=False,
        raw_hashes=result["hashes"],positions_sha256=positions.hexdigest(),timing=timings,
        reference_validation=dict(commands=reference_count,window="commands_60_through_118",
            may_include_post_failure_states=True,maximum_native_geometry_error_m=geometry_error,
            checked_optimizations=optimization_count,maximum_optimization_errors=optimization_statistics(optimization_reports)["maximum_errors"],optimization_statistics=optimization_statistics(optimization_reports),
            actual_contact_guaranteed=False,dynamic_feasibility_established=False),
        native_motor_validation=dict(internal_samples=rows,maximum_model_error_nm=motor_error,
            dynamic_internal_samples=dynamic_samples,prepared_dynamic_commands=prepared_count,
            maximum_prepared_requested_torque_error_nm=prepared_error,
            maximum_held_interval_requested_torque_error_nm=held_error,
            held_interval_force_guaranteed=False))

TERMINAL=dict(type="HierarchyRefusal",message="Hierarchical support control refused")
ALLOCATION=dict(accepted=False,status="native joint limit already active",prediction=None,selected=None,
    attempts=[],patterns_tried=0,solver_route="original_generic",fallback_attempted=False,
    original_refusal=None,total_qp_solves=0,primary_backend_fallback_attempted=False,previous_refusal=None,
    scaled_primary_fallback_attempted=False,scaling_previous_refusal=None)

def validate_terminal(row,step):
    require(terminal_error(row)==(TERMINAL if step==119 else None),"Failure4 exact terminal error/order")
    if step!=119:return
    reference=row["force_reference"];d=reference["decision"]
    require(reference["provider_error"]==TERMINAL and d["step"]==119
        and same_bits(d["allocation"],ALLOCATION) and d["physical_acceptance_authority"] is False
        and row["resolution"]["fallback_reason"]=="provider_absent"
        and row["resolution"]["adaptation_applied"] is False,"Failure4 domain refusal without solver or transfer")

def joint_limit_witness(row,profile):
    spec=profile["morphology_spec"]["joints"];obs=row["request"]["state"]["ordered_joint_observations"]
    require([x["joint_id"] for x in obs]==[x["joint_id"] for x in spec]
        and same_bits([x["position_rad"] for x in obs],row["native_observation"]["qpos"][7:]),
        "Failure4 ordered canonical/native joint join")
    events=[]
    for observed,joint in zip(obs,spec,strict=True):
        q=observed["position_rad"];v=observed["velocity_rad_s"]
        lo=joint["lower_limit_rad"];hi=joint["upper_limit_rad"]
        require(all(type(x) in (int,float) and math.isfinite(x) for x in (q,v,lo,hi))
            and lo<hi,"Failure4 finite ordered joint limits")
        if q<lo or q>hi:
            events.append(dict(joint_id=joint["joint_id"],position_rad=q,velocity_rad_s=v,
                lower_limit_rad=lo,upper_limit_rad=hi,lower_excess_rad=max(lo-q,0.),upper_excess_rad=max(q-hi,0.)))
    return dict(command=row["outer_step"],outside_joint_limits=events,strict_domain_boundary=True,
        boundary_tolerance_changed=False,solver_infeasibility_established=False)

def prediction_gap(controls,trace,profile):
    require(len(controls)==120 and len(trace)==595,"Failure4 complete prediction/native population")
    joint_ids=[j["joint_id"] for j in profile["morphology_spec"]["joints"]]
    require(len(joint_ids)==8,"Failure4 exact joint population")
    maximum=np.zeros(8);worst=None;last=[];samples=0
    for command in range(60,119):
        row=controls[command];require(row["outer_step"]==command,"Failure4 prediction command order")
        joint_limit_witness(row,profile)
        predictions=row["force_reference"]["decision"]["allocation"]["prediction"]["predicted_steps"]
        require(len(predictions)==5,"Failure4 full held prediction")
        for offset,prediction in enumerate(predictions):
            native=trace[5*command+offset]
            require(native["step"]==5*command+offset+1,"Failure4 prediction/native step join")
            predicted=np.asarray(prediction["joint_position"]);observed=np.asarray(native["qpos"][7:])
            require(predicted.shape==observed.shape==(8,) and np.isfinite(predicted).all()
                and np.isfinite(observed).all(),"Failure4 finite predicted/observed joints")
            error=observed-predicted;maximum=np.maximum(maximum,np.abs(error));samples+=1
            j=int(np.argmax(np.abs(error)))
            value=dict(command=command,internal_step=native["step"],joint_id=joint_ids[j],
                predicted_position_rad=float(predicted[j]),observed_position_rad=float(observed[j]),
                absolute_error_rad=float(abs(error[j])))
            if worst is None or value["absolute_error_rad"]>worst["absolute_error_rad"]:worst=value
            if command==118:
                last.append(dict(internal_step=native["step"],predicted_position_rad=predicted.tolist(),
                    observed_position_rad=observed.tolist(),observed_minus_predicted_rad=error.tolist()))
    from contact_priority_component import parameters
    margin=parameters()["joint_position_margin_rad"]
    return dict(applied_commands=59,internal_samples=samples,joint_comparisons=samples*8,
        maximum_absolute_error_rad=dict(zip(joint_ids,maximum.tolist(),strict=True)),
        worst=worst,last_applied_command=118,last_five_steps=last,
        planning_margin_rad=margin,model_only=True,robust_error_bound_established=False,
        physical_joint_limit_guarantee=False)

from contextlib import contextmanager
@contextmanager
def capture_failure(output,row,profile):
    """Reconstruct the strict domain refusal while both QP constructors are forbidden."""
    import contact_priority_component as constraints
    import generic_proximal_qp_solver as proximal
    import osqp
    build=constraints.build;witness=joint_limit_witness(row,profile)
    require(len(witness["outside_joint_limits"])==1
        and witness["outside_joint_limits"][0]["joint_id"]=="rear_left_hip"
        and witness["outside_joint_limits"][0]["position_rad"]==0.7202513120289704
        and witness["outside_joint_limits"][0]["upper_limit_rad"]==0.72,
        "Failure4 exact native domain witness")
    def capture(*args,**kwargs):
        value=build(*args,**kwargs)
        require(value==dict(domain_refusal="native joint limit already active",mode="combined"),
            "Failure4 reconstructed pre-solver domain refusal")
        output.append(dict(witness,base=value,qp_constructors_forbidden=True,qp_solves=0))
        return value
    with patch.object(constraints,"build",capture),patch.object(osqp,"OSQP",
        side_effect=AssertionError("Domain refusal cannot construct OSQP")),patch.object(proximal.proxsuite.proxqp.dense,"QP",
        side_effect=AssertionError("Domain refusal cannot construct ProxQP")):yield
