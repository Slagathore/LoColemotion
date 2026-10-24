"""Contained native recovery training using the unchanged production physics loop."""
import argparse
from contextlib import ExitStack
import hashlib
import importlib.metadata
import json
from pathlib import Path
import sys
import time
from unittest.mock import patch

import mujoco
from gpu_measurement_probe import write_new
from motor_effectiveness_task import condition_inputs
from residual_recovery_native import run_trial
from residual_recovery_control import RecoveryController as ResidualController
from residual_recovery_training_task import (ROOT,FLAGS,declaration,all_plans,initial_arrays,sha,require,
    provider,controller_contract,bridge,load_stage,validate_launch_records,warm_model,ars,ars_plan,candidate_keys,composite)
from run_gpu_measurement_probe import source_identity


def preflight_models(c,core):
    warm=warm_model(core);batch=ars.ask(warm.recovery.policy,ars_plan(c,0))
    return [warm]+[composite(core,warm,batch.candidate(d,s),warm.recovery.document()["corpus"])
        for d,s,_ in candidate_keys(c)]


def preflight(core_path,baseline_path,lane):
    c=declaration(lane);plans=all_plans(c)
    require(sha(core_path)==c["core_sha256"] and sha(baseline_path)==c["baseline_core_sha256"],"Residual training core images")
    require({k:importlib.metadata.version(k) for k in c["runtime"]}==c["runtime"],"Residual training runtime")
    prepared={}
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Residual training preflight opens no world")))
        for path in (core_path,baseline_path):
            core=bridge.LocomotionCore(path)
            for condition in sorted({p["condition_id"] for p in plans}):
                compiled,xml,spec=condition_inputs(path,dict(c,core_sha256=sha(path)),condition)
                require(hashlib.sha256(xml.encode("utf-8")).hexdigest()==c["condition_model_sha256"][condition]
                    and compiled["descriptor_sha256"]==c["descriptor_sha256"],"Residual training model identity")
                value=(compiled,xml,spec)
                require(condition not in prepared or prepared[condition]==value,"Residual training core compilation")
                prepared[condition]=value
                for model in preflight_models(c,core):
                    require(provider.FrozenModel.load(core,model.document())==model,"Recovery model round trip")
                    for mode in ("challenge_only","early_selected"):
                        controller=ResidualController(core,compiled,controller_contract(c,model),model,mode,"preflight_"+condition+"_"+mode)
                        controller.close();require(controller.session.closed,"Recovery preflight leaked session")
            for plan in plans:
                qpos,qvel=initial_arrays(prepared[plan["condition_id"]][2],plan)
                require(len(qpos)==15 and len(qvel)==14 and all(provider.ars.finite(x) for x in qpos+qvel),
                    "Residual training initial state")
    return dict(ok=True,lane=lane,world_build_count=0,solver_steps=0,planned_cpu_worlds=len(plans),planned_gpu_worlds=0,
        planned_controller_rows=len(plans)*c["outer_steps"],planned_internal_rows=len(plans)*c["outer_steps"]*5,
        runtime=c["runtime"],physical_acceptance_authority=False,training_data_authority=False)


def run(folder,permit,core_path,baseline_path,lane):
    sys.path.insert(0,str(ROOT/"sdk/conformance"));import r10v_windows_job as jobs
    require(permit.is_file() and jobs.current_in_job(),"Residual training execution requires containment")
    source=source_identity(True);c=declaration(lane)
    require(permit.resolve(strict=True)==folder.resolve(strict=True)/"contained.permit","Residual training permit path")
    owner=validate_launch_records(folder,c,source)
    from run_residual_recovery_training import bindings
    require(bindings(core_path,baseline_path)==owner["binding"],"Recovery training worker source/runtime freeze")
    preflight(core_path,baseline_path,lane)
    core=bridge.LocomotionCore(core_path);claim,_,models=load_stage(folder.parent,c,core)
    training=folder.parent.name!="comparison"
    result=dict(schema_version="locolemotion_residual_recovery_training_worker_v1",ok=False,synthetic=False,
        stage=folder.parent.name,stage_claim_sha256=sha(folder.parent/"stage.json"),ledger_scope=c["ledger_scope"],
        training_data_scope=c["training_data_scope"],trials=[],constructed_model_count=0,constructed_cpu_worlds=0,
        constructed_gpu_worlds=0,**{k:training and k=="training_data_authority" for k in FLAGS})
    started=time.perf_counter();stage="setup"
    try:
        for plan in claim["trials"]:
            stage=plan["trial_id"]
            result["trials"].append(run_trial(folder/stage,plan,c,core_path,core,result,models[plan["model_key"]].document()))
        result.update(ok=True,status="complete_native_recovery_training_stage")
    except BaseException as exc:
        result.update(error=f"{type(exc).__name__}: {exc}",failed_stage=stage,status="incomplete_or_refused_execution")
    finally:
        result["total_wall_s"]=time.perf_counter()-started
        write_new(folder/"worker-result.json",result)
    if not result["ok"]:raise RuntimeError(result["error"])
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--lane",choices=("route","pilot"),required=True)
    p.add_argument("--check-only",action="store_true");p.add_argument("--output",type=Path);p.add_argument("--permit",type=Path)
    args=p.parse_args()
    if args.check_only:print(json.dumps(preflight(args.core,args.baseline_core,args.lane)))
    else:
        require(args.output is not None and args.permit is not None,"Residual training output/permit required")
        run(args.output,args.permit,args.core,args.baseline_core,args.lane)
    return 0


if __name__=="__main__":raise SystemExit(main())
