"""Reopen the exact incomplete posture trial, including its untransferred terminal row."""
import sys
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
from contact_posture_native_task import ROOT,FLAGS,declaration,initial_arrays,require,sha,provider,controller_contract,bridge,read
from causal_force_control import ForceController,terminal_error
from contact_posture_native_task import profile_for
from contact_posture_native_task import controller_for
from residual_recovery_metrics import transitions,paired_prefix


def reference_checks(row,previous,profile,role,nominal,prior_height,reach_model,metadata):
    """Independently rejoin bounded references to the current native observation."""
    from audit_contact_posture_component import verify_posture,native_clearances
    require(role in ("reach_hold","posture_hold"),"Posture reference role")
    decision=row["force_reference"]["decision"];reference=decision["support_reference"]
    height=reference["target_com_height_m"]
    require(nominal-.10-1e-12<=height<=prior_height+1e-12
        and prior_height-height<=.20/120.+1e-12,"Posture unchanged COM reference bounds")
    native=native_clearances(metadata,row,reach_model)
    geometric_error=max(abs(v["current_clearance_m"]-value) for v,value in zip(decision["support_reach"],native,strict=True))
    require(geometric_error<=2e-10,"Posture current native capsule geometry")
    for old,command in zip(previous["resolution"]["ordered_commands"],row["resolution"]["ordered_commands"],strict=True):
        require(abs(command["applied_correction_rad_s"])<=3.5
            and abs(command["applied_correction_rad_s"]-old["applied_correction_rad_s"])<=.08+1e-12
            and abs(command["final_canonical_target_velocity_rad_s"])<=3.5,"Posture unchanged resolver caps")
    status=None;witness=dict(contact_drift_m=0.,joint_increment_rad=0.);ranks={}
    if role=="posture_hold":
        posture=decision["posture_reference"];status=posture["status"]
        contacts=row["resolution_request"]["provider_request"]["controller_context"]["controller_memory"]["contact_packet"]["ordered_contacts"]
        witness=verify_posture(posture,row["request"]["state"],decision,profile,contacts)
        if status=="solved":ranks={r["name"]:r["attainable_rank"] for r in posture["linear_solution"]["tasks"]}
    else:require("posture_reference" not in decision,"Posture baseline profile crossed")
    return dict(height=height,geometry_error_m=geometric_error,posture_status=status,task_ranks=ranks,**witness)


def reconstructed_kinematics(row,compiled,metadata):
    robot=object.__new__(bridge.MujocoBw19vRobot)
    robot.morphology=compiled["morphology"];robot.spec=robot.morphology["morphology_spec"]
    robot.actuator_specs={r["actuator_id"]:r for r in robot.spec["actuators"]}
    robot.contact_sites={r["contact_site_id"]:r for r in robot.spec["contact_sites"]}
    robot.joint_ids={joint:i+1 for i,joint in enumerate(robot.morphology["ordered_joint_ids"])}
    robot.data=SimpleNamespace(**{name:np.asarray(row["native_observation"][name],dtype=np.float64)
        for name in ("xanchor","xaxis","xpos","xmat")})
    robot.model=SimpleNamespace(body=lambda name:SimpleNamespace(id=metadata["ordered_bodies"].index(name)))
    return robot.endpoint_kinematics(row["stability"])


def audit_partial_trial(folder,plan,c,core_path,core,expected_model=None):
    require(read(folder/"plan.json")==plan,"Residual audit plan")
    result=read(folder/"result.json")
    require(all(result.get(k)==v for k,v in plan.items()) and result["completed"] is False
        and result["controller_closed"] is True,"Residual incomplete/crossed trial")
    require(plan["trial_id"]=="posture_hold_left_075_train_001" and c["outer_steps"]==1440
        and result["outer_rows"]==1231 and result["internal_rows"]==6150
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
    statuses=Counter();ranks={};reference_count=0;geometry_error=contact_drift=joint_increment=0.
    nominal=controller.force_policy.height;prior_height=nominal
    try:
        for step,row in enumerate(read_jsonl(folder/"controller.jsonl")):
            require(step<1231 and (row["backend"],row["cell"],row["outer_step"])==("cpu",0,step),"Residual controller order")
            validate_terminal(row,step)
            validate_observation(row,metadata,compiled)
            require(same_bits(reconstructed_kinematics(row,compiled,metadata),row["kinematics"]),"Residual endpoint/native join")
            if step==1230:
                with capture_failure(solver_witness):
                    expected=controller.step(row["request"]["state"],row["stability"],row["kinematics"])
            else:expected=controller.step(row["request"]["state"],row["stability"],row["kinematics"])
            require(all(key in row and same_bits(value,row[key]) for key,value in expected.items()),"Residual independent control replay")
            if 60<=step<1230:
                check=reference_checks(row,controls[-1],profile,plan["role"],nominal,prior_height,controller.force_policy.reach,metadata)
                prior_height=check["height"];reference_count+=1
                geometry_error=max(geometry_error,check["geometry_error_m"])
                contact_drift=max(contact_drift,check["contact_drift_m"])
                joint_increment=max(joint_increment,check["joint_increment_rad"])
                if check["posture_status"] is not None:statuses[check["posture_status"]]+=1
                for name,rank in check["task_ranks"].items():ranks.setdefault(name,Counter())[str(rank)]+=1
            receipt=row["resolution"];commands=receipt["ordered_commands"]
            require(receipt["world_build_count"]==0 and receipt["physics_state_modified"] is False
                and receipt["physical_acceptance_authority"] is False,"Residual resolver authority")
            applied+=int(receipt["adaptation_applied"])
            nonzero+=int(any(r["applied_correction_rad_s"]!=0. for r in commands))
            refusals+=int(receipt["fallback_reason"] not in ("none","provider_absent","provider_no_proposal"))
            safe+=int(row["output"]["actuation"]["safe_no_actuation"])
            controls.append(row)
    finally:controller.close()
    require(len(controls)==1231 and len(solver_witness)==1,"Failure complete partial control/solver witness")
    qpos,qvel=initial_arrays(spec,plan);last=None;eps=2**-52
    metric=dict(minimum_height_m=math.inf,maximum_tilt_rad=0.,torso_contact_steps=0,
        ground_contact_steps=0,nonzero_force_steps=0,safe_no_actuation_steps=safe,first_physical_violation=None)
    positions=hashlib.sha256();rows=0
    for index,row in enumerate(read_jsonl(folder/"trace.jsonl")):
        step=index+1
        require(step<=6150 and (row["backend"],row["cell"],row["step"])==("cpu",0,step),"Residual internal order")
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
    require(rows==6150,"Failure complete retained internal samples")
    terminal=controls[-1]
    require(same_bits(last["qpos"],terminal["native_observation"]["qpos"])
        and same_bits(last["qvel"],terminal["native_observation"]["qvel"])
        and last["time_s"]==terminal["native_observation"]["time_s"],
        "Failure terminal observation must follow last completed step")
    reproduce_solver(solver_witness[0])
    metric["forward_displacement_m"]=last["qpos"][0]-spec["initial_qpos"][0]
    failures=[]
    for name,bad in (("height",metric["minimum_height_m"]<c["selection"]["minimum_height_m"]),
        ("tilt",metric["maximum_tilt_rad"]>c["selection"]["maximum_tilt_rad"]),
        ("torso_contact",metric["torso_contact_steps"]>0),("safe_no_actuation",bool(safe))):
        if bad:failures.append(name)
    timings=timing_summary(list(read_jsonl(folder/"timing.jsonl")),dict(c,outer_steps=1230))
    return dict(plan,controller_rows=len(controls),internal_rows=rows,provider_model_sha256=model.sha256,
        control_applied_commands=applied,nonzero_correction_commands=nonzero,refused_commands=refusals,
        diagnostic_metrics=metric,diagnostic_failure_codes=failures,diagnostic_eligible=False,
        native_horizon_completed=False,terminal_command=1230,terminal_transferred=False,solver_failure=solver_witness[0],
        official_quality_m_s=None,selection_authority=False,
        raw_hashes=result["hashes"],positions_sha256=positions.hexdigest(),timing=timings,
        reference_validation=dict(commands=reference_count,window="commands_60_through_1229",
            may_include_post_failure_states=True,maximum_native_geometry_error_m=geometry_error,
            maximum_nonlinear_contact_drift_m=contact_drift,maximum_joint_reference_increment_rad=joint_increment,
            posture_status_counts=dict(sorted(statuses.items())),
            task_attainable_rank_counts={k:dict(sorted(v.items())) for k,v in ranks.items()},
            actual_contact_guaranteed=False,dynamic_feasibility_established=False))


TERMINAL=dict(type="ValueError",message="Posture independent blocking bound")


def validate_terminal(row,step):
    require(terminal_error(row)==(TERMINAL if step==1230 else None),"Failure exact terminal error/order")
    if step==1230:
        require(row["force_reference"]["provider_error"]==TERMINAL
            and row["force_reference"]["decision"] is None
            and row["resolution"]["fallback_reason"]=="provider_absent"
            and row["resolution"]["adaptation_applied"] is False,"Failure resolver terminal boundary")


from contextlib import contextmanager
@contextmanager
def capture_failure(output):
    """Observe original solver locals without changing its numerical execution."""
    require(sys.gettrace() is None,"Failure tracer already active")
    def trace(frame,event,arg):
        if (frame.f_code.co_name=="bounded_least_squares"
            and Path(frame.f_code.co_filename).resolve()==ROOT/"sdk/discovery/bounded_posture_solver.py"
            and event=="exception" and str(arg[1])==TERMINAL["message"]):
            v=frame.f_locals;j,sign=v["blocking"]
            output.append(dict(inputs={k:np.asarray(v[k]).tolist() for k in
                ("a","b","e","d","lower","upper","initial")},
                iteration=v["iteration"],old_rank=v["old_rank"],new_rank=v["new_rank"],
                previous_rank=v["rank"],blocking=[j,sign],alpha=v["alpha"],
                projected_coordinate_norm=float(np.linalg.norm(v["z"][j])),
                direction=float(v["p"][j]),bounds_added=v["added"],bounds_released=v["released"]))
        return trace
    sys.settrace(trace)
    try:yield
    finally:sys.settrace(None)


def reproduce_solver(witness):
    """The isolated matrix problem must reproduce the same refusal and trace."""
    from bounded_posture_solver import bounded_least_squares
    observed=[];error=None
    try:
        with capture_failure(observed):bounded_least_squares(**witness["inputs"])
    except ValueError as exc:error=str(exc)
    require(error==TERMINAL["message"] and observed==[witness],"Failure isolated solver reconstruction")
