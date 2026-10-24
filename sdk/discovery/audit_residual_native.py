"""Zero-world independent baseline-core replay and native trace audit for residual smoke."""
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
from residual_native_task import ROOT,FLAGS,declaration,trial_plan,initial_arrays,require,sha,provider,model_artifact,controller_contract,bridge
from residual_control import ResidualController


def read(path):return json.loads(path.read_text(encoding="utf-8"))


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


def audit_trial(folder,plan,c,core_path,core):
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
    require(artifact==model_artifact(plan["model_kind"]),"Residual crossed frozen artifact")
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


def compare_native_paths(folder,results,synthetic):
    by_role={r["role"]:r for r in results}
    baseline,zero,probe=[by_role[k] for k in ("absent","zero","probe")]
    require(baseline["raw_hashes"]["trace"]==zero["raw_hashes"]["trace"],"Residual zero changed native baseline")
    require(baseline["nonzero_correction_commands"]==zero["nonzero_correction_commands"]==0,"Residual zero influence")
    require(probe["nonzero_correction_commands"]>0,"Residual probe never reached command path")
    first_control=first_position=None
    streams=[read_jsonl(folder/r["trial_id"]/"trace.jsonl") for r in (baseline,probe)]
    for a,b in zip(*streams,strict=True):
        if first_control is None and not same_bits(a["ctrl"],b["ctrl"]):first_control=a["step"]
        if first_position is None and not same_bits(a["qpos"],b["qpos"]):first_position=a["step"]
    require(first_control is not None,"Residual native input never differed")
    if not synthetic:
        require(first_position is not None and first_position>=first_control,"Residual native state response missing/crossed")
    return dict(zero_residual_native_trace_bit_identical=True,probe_first_different_internal_input=first_control,
        probe_first_different_native_position=first_position,
        native_response_verified=not synthetic and first_position is not None,
        locomotion_benefit_established=False)


def audit(folder,core_path,baseline_path):
    c=declaration();parent=read(folder.parent/"declaration.json")
    require(parent["contract"]==c and type(parent["synthetic"]) is bool,"Residual owner declaration")
    synthetic=parent["synthetic"];worker=read(folder/"worker-result.json")
    require(worker["ok"] is True and worker["synthetic"] is synthetic and worker["ledger_scope"]==c["ledger_scope"]
        and worker["status"]=="complete_native_residual_route" and all(worker[k] is False for k in FLAGS),
        "Residual worker completion/authority")
    require(sha(core_path)==c["core_sha256"] and sha(baseline_path)==c["baseline_core_sha256"],"Residual audit core identity")
    plans=trial_plan(c)
    require(worker["constructed_cpu_worlds"]==worker["constructed_model_count"]==(0 if synthetic else len(plans))
        and worker["constructed_gpu_worlds"]==0 and len(worker["trials"])==len(plans),"Residual world/role denominator")
    if not synthetic:
        from run_residual_native import bindings
        from run_gpu_measurement_probe import source_identity
        require(source_identity(True)==parent["source_commit"] and bindings(core_path,baseline_path)==parent["binding"],
            "Residual independent source/runtime freeze")
        from residual_native import validate_launch_records
        validate_launch_records(folder,parent["source_commit"])
        for plan in plans:
            opened=read(folder/plan["trial_id"]/"world-opened.json")
            require(opened==dict(trial_id=plan["trial_id"],native_data_constructed=True,
                core_sha256=c["core_sha256"],
                provider_model_sha256=read(folder/plan["trial_id"]/"result.json")["provider_model_sha256"]),
                "Residual native construction marker")
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Residual audit constructs no world")))
        core=bridge.LocomotionCore(baseline_path)
        trials=[]
        for plan,observed in zip(plans,worker["trials"],strict=True):
            require(observed==read(folder/plan["trial_id"]/"result.json"),"Residual worker/trial join")
            trials.append(audit_trial(folder/plan["trial_id"],plan,c,baseline_path,core))
        comparison=compare_native_paths(folder,trials,synthetic)
    return dict(schema_version="locolemotion_residual_native_audit_v1",ok=True,synthetic=synthetic,
        ledger_scope=c["ledger_scope"],reader_world_build_count=0,reader_solver_steps=0,trials=trials,
        constructed_cpu_worlds=worker["constructed_cpu_worlds"],constructed_gpu_worlds=0,
        controller_rows=sum(t["controller_rows"] for t in trials),internal_rows=sum(t["internal_rows"] for t in trials),
        native_path_comparison=comparison,native_route_verified=comparison["native_response_verified"],
        training_data_authority=False,physical_acceptance_authority=False,release_authority=False,equivalence_authority=False,
        controller_selection_authority=False,tier3_benefit_established=False)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--folder",type=Path,required=True)
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True);args=p.parse_args()
    result=audit(args.folder,args.core,args.baseline_core);write_new(args.output,result)
    print(json.dumps(dict(ok=result["ok"],synthetic=result["synthetic"],controller_rows=result["controller_rows"],
        internal_rows=result["internal_rows"],native_route_verified=result["native_route_verified"])))
    return 0


if __name__=="__main__":raise SystemExit(main())
