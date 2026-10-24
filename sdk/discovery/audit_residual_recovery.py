"""Independent full native replay and recovery transition accounting."""
import argparse
from contextlib import ExitStack
import hashlib
import json
import math
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import mujoco
import numpy as np
from audit_gpu_batch_execution import same_bits,finite_vector,timing_summary,read_jsonl
from audit_gpu_portable_search import validate_observation
from body_height_diagnostic import physical_violation
from gpu_measurement_probe import write_new
from motor_effectiveness_task import condition_inputs,expected_actuator_arrays
from residual_recovery_task import (ROOT,FLAGS,declaration,initial_arrays,require,sha,provider,controller_contract,bridge,read,load_stage,score,assess_comparison,validate_launch_records)
from residual_recovery_control import RecoveryController as ResidualController
from residual_recovery_metrics import transitions,paired_prefix


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


def audit_trial(folder,plan,c,core_path,core,expected_model=None):
    require(read(folder/"plan.json")==plan,"Residual audit plan")
    result=read(folder/"result.json")
    require(all(result.get(k)==v for k,v in plan.items()) and result["completed"] is True
        and result["controller_closed"] is True,"Residual incomplete/crossed trial")
    require(result["outer_rows"]==c["outer_steps"] and result["internal_rows"]==5*c["outer_steps"],"Residual worker denominator")
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
    controller=ResidualController(core,compiled,controller_contract(c,model),model,plan["mode"],plan["trial_id"])
    controls=[];applied=nonzero=refusals=safe=0
    try:
        for step,row in enumerate(read_jsonl(folder/"controller.jsonl")):
            require(step<c["outer_steps"] and (row["backend"],row["cell"],row["outer_step"])==("cpu",0,step),"Residual controller order")
            require(row["residual"]["terminal_error"] is None and row["residual"]["provider_error"] is None,"Residual terminal provider row")
            validate_observation(row,metadata,compiled)
            require(same_bits(reconstructed_kinematics(row,compiled,metadata),row["kinematics"]),"Residual endpoint/native join")
            expected=controller.step(row["request"]["state"],row["stability"],row["kinematics"])
            require(all(key in row and same_bits(value,row[key]) for key,value in expected.items()),"Residual independent control replay")
            receipt=row["resolution"];commands=receipt["ordered_commands"]
            require(receipt["world_build_count"]==0 and receipt["physics_state_modified"] is False
                and receipt["physical_acceptance_authority"] is False,"Residual resolver authority")
            applied+=int(receipt["adaptation_applied"])
            nonzero+=int(any(r["applied_correction_rad_s"]!=0. for r in commands))
            refusals+=int(receipt["fallback_reason"] not in ("none","provider_absent","provider_no_proposal"))
            safe+=int(row["output"]["actuation"]["safe_no_actuation"])
            controls.append(row)
    finally:controller.close()
    require(len(controls)==c["outer_steps"],"Residual missing controller rows")
    qpos,qvel=initial_arrays(spec,plan);last=None;eps=2**-52
    metric=dict(minimum_height_m=math.inf,maximum_tilt_rad=0.,torso_contact_steps=0,
        ground_contact_steps=0,nonzero_force_steps=0,safe_no_actuation_steps=safe,first_physical_violation=None)
    positions=hashlib.sha256();rows=0
    for index,row in enumerate(read_jsonl(folder/"trace.jsonl")):
        step=index+1
        require(step<=5*c["outer_steps"] and (row["backend"],row["cell"],row["step"])==("cpu",0,step),"Residual internal order")
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
    require(rows==5*c["outer_steps"],"Residual missing internal samples")
    metric["forward_displacement_m"]=last["qpos"][0]-spec["initial_qpos"][0]
    failures=[]
    for name,bad in (("height",metric["minimum_height_m"]<c["selection"]["minimum_height_m"]),
        ("tilt",metric["maximum_tilt_rad"]>c["selection"]["maximum_tilt_rad"]),
        ("torso_contact",metric["torso_contact_steps"]>0),("safe_no_actuation",bool(safe))):
        if bad:failures.append(name)
    timings=timing_summary(list(read_jsonl(folder/"timing.jsonl")),c)
    return dict(plan,controller_rows=len(controls),internal_rows=rows,provider_model_sha256=model.sha256,
        control_applied_commands=applied,nonzero_correction_commands=nonzero,refused_commands=refusals,
        diagnostic_metrics=metric,diagnostic_failure_codes=failures,diagnostic_eligible=not failures,
        official_quality_m_s=None,selection_authority=False,
        raw_hashes=result["hashes"],positions_sha256=positions.hexdigest(),timing=timings)


def audit(folder,core_path,baseline_path,lane):
    c=declaration(lane);stage=folder.parent.name;training=stage!="comparison"
    from run_residual_recovery import bindings
    from run_gpu_measurement_probe import source_identity
    source=source_identity(True);owner=validate_launch_records(folder,c,source)
    require(sha(core_path)==c["core_sha256"] and sha(baseline_path)==c["baseline_core_sha256"]
        and bindings(core_path,baseline_path)==owner["binding"],"Residual training independent source/runtime freeze")
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Residual training audit opens no world")))
        core=bridge.LocomotionCore(baseline_path)
        claim,_,models=load_stage(folder.parent,c,core);worker=read(folder/"worker-result.json");plans=claim["trials"]
        require(worker["ok"] is True and worker["synthetic"] is False and worker["stage"]==stage
            and worker["status"]=="complete_native_recovery_comparison" and worker["ledger_scope"]==c["ledger_scope"]
            and worker["training_data_scope"]==c["training_data_scope"]
            and worker["stage_claim_sha256"]==sha(folder.parent/"stage.json")
            and all(worker[k] is (training and k=="training_data_authority") for k in FLAGS),
            "Residual training worker completion/authority")
        require(worker["constructed_cpu_worlds"]==worker["constructed_model_count"]==len(plans)
            and worker["constructed_gpu_worlds"]==0 and len(worker["trials"])==len(plans),"Residual training stage denominator")
        trials=[]
        for plan,observed in zip(plans,worker["trials"],strict=True):
            trial=folder/plan["trial_id"];model=models[plan["model_key"]]
            require(observed==read(trial/"result.json"),"Residual training worker/trial join")
            require(read(trial/"world-opened.json")==dict(trial_id=plan["trial_id"],native_data_constructed=True,
                core_sha256=c["core_sha256"],provider_model_sha256=model.sha256),"Residual training construction marker")
            result=audit_trial(trial,plan,c,baseline_path,core,model.document())
            controls=list(read_jsonl(trial/"controller.jsonl"));trace=list(read_jsonl(trial/"trace.jsonl"))
            scored=score(controls,trace,c,training=training)
            require(result["diagnostic_eligible"] is (scored["first_reward_failure"] is None),"Residual score/physical eligibility join")
            result.update(scored,policy_sha256=model.policy.sha256,recovery_policy_sha256=model.recovery.policy.sha256,
                actor_model_sha256=model.actor.sha256,recovery_model_sha256=model.recovery.sha256,
                warning_model_sha256=model.warning.sha256,
                recovery=transitions(controls,scored["first_reward_failure"],c,model,plan["mode"]))
            trials.append(result)
            print(json.dumps(dict(audited_trial=plan["trial_id"],eligible=result["diagnostic_eligible"],
                reward=result["training_reward"],official_quality=result["official_quality_m_s"])),flush=True)
        for result in trials:
            if result["mode"].startswith(("early_","warning_")):
                reference=next(r for r in trials if r["group_id"]==result["group_id"] and r["role"]=="challenge_only")
                result["paired_prefix"]=paired_prefix(folder/result["trial_id"],folder/reference["trial_id"],result["recovery"],c)
        comparison=assess_comparison(trials,c) if not training else None
    require(source_identity(True)==source and bindings(core_path,baseline_path)==owner["binding"],
        "Residual training audit source/runtime drift")
    return dict(schema_version="locolemotion_residual_recovery_audit_v1",ok=True,synthetic=False,
        source_commit=source,stage=stage,lane=lane,stage_claim_sha256=sha(folder.parent/"stage.json"),
        ledger_scope=c["ledger_scope"],training_data_scope=c["training_data_scope"],trials=trials,
        reader_world_build_count=0,reader_solver_steps=0,constructed_cpu_worlds=len(plans),constructed_gpu_worlds=0,
        controller_rows=len(plans)*c["outer_steps"],internal_rows=len(plans)*c["outer_steps"]*5,
        final_comparison=comparison,controller_selection_authority=False,tier3_benefit_established=False,
        **{k:training and k=="training_data_authority" for k in FLAGS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--folder",type=Path,required=True)
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--lane",choices=("comparison",),required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();result=audit(args.folder,args.core,args.baseline_core,args.lane)
    write_new(args.output,result);print(json.dumps(dict(ok=result["ok"],output=str(args.output))),flush=True)
    return 0


if __name__=="__main__":raise SystemExit(main())
