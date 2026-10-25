"""Contained fresh paired reach and configured dynamic control worlds."""
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
from hierarchical_native_task_v2 import ROOT,FLAGS,read,sha,require,declaration,plans,launch_records,retained,verify_component,profile_for,bridge,frozen_model,controller_for,initial_arrays
from hierarchical_native_trial_v2 import run_hold_trial
from causal_force_policy import make_profile
from motor_effectiveness_task import condition_inputs
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity


def preflight(core_path,baseline_path):
    c=declaration();require(sha(core_path)==c["core_sha256"] and sha(baseline_path)==c["baseline_core_sha256"],"Reach core identities")
    require({k:importlib.metadata.version(k) for k in c["runtime"]}==c["runtime"],"Reach runtime versions")
    verified=verify_component(ROOT.parent/"SporeSpore_Evidence")
    retained.header(read(retained.CLOSURE),ROOT.parent/"SporeSpore_Evidence")
    prepared={};profiles={}
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Posture preflight opens no world")))
        for path in (core_path,baseline_path):
            core=bridge.LocomotionCore(path);model=frozen_model(core)
            for plan in plans(c):
                condition=plan["condition_id"];role=plan["role"]
                compiled,xml,spec=condition_inputs(path,dict(c,core_sha256=sha(path)),condition)
                require(hashlib.sha256(xml.encode()).hexdigest()==c["condition_model_sha256"][condition],"Reach unchanged XML")
                value=(compiled,xml,spec)
                require(condition not in prepared or prepared[condition]==value,"Reach two-core compilation")
                prepared[condition]=value;profile=profile_for(role,compiled,spec);key=condition+"_"+role
                digest=core.canonicalize_json(profile)["sha256"]
                require(key not in profiles or profiles[key]==digest,"Reach two-core profile identity");profiles[key]=digest
                control=controller_for(role,core,compiled,c,model,"reach_preflight_"+key,profile)
                control.close();require(control.closed,"Posture preflight session leak")
                qpos,qvel=initial_arrays(spec,plan);require(len(qpos)==15 and len(qvel)==14,"Reach initial dimensions")
    return dict(ok=True,world_build_count=0,solver_steps=0,planned_cpu_worlds=4,planned_gpu_worlds=0,
        planned_controller_rows=5760,planned_internal_rows=28800,contact_sample_rows=28800,
        component_evidence_verified=verified["ok"],component_evidence=verified,profiles=profiles,
        original_reach_closure_sha256=sha(retained.CLOSURE),physical_acceptance_authority=False,training_data_authority=False)


def run(folder,permit,core_path,baseline_path):
    sys.path.insert(0,str(ROOT/"sdk/conformance"));import r10v_windows_job as jobs
    require(permit.is_file() and jobs.current_in_job() and permit.resolve(strict=True)==folder.resolve(strict=True)/"contained.permit","Reach containment/permit")
    source=source_identity(True);c=declaration();owner=launch_records(folder,c,source)
    from run_hierarchical_native_v2 import bindings
    require(bindings(core_path,baseline_path)==owner["binding"],"Reach worker source/runtime bindings")
    preflight(core_path,baseline_path)
    core=bridge.LocomotionCore(core_path);model=frozen_model(core)
    result=dict(schema_version="locolemotion_hierarchical_native_worker_v2",ok=False,synthetic=False,
        ledger_scope=c["ledger_scope"],trials=[],constructed_model_count=0,constructed_cpu_worlds=0,
        constructed_gpu_worlds=0,**{k:False for k in FLAGS})
    started=time.perf_counter()
    try:
        for plan in plans(c):result["trials"].append(run_hold_trial(folder/plan["trial_id"],plan,c,core_path,core,result,model.document()))
        result.update(ok=True,status="complete_hierarchical_native_v2_fixture")
    except BaseException as exc:result.update(error=f"{type(exc).__name__}: {exc}",status="incomplete_or_refused_execution")
    finally:
        result["total_wall_s"]=time.perf_counter()-started;write_new(folder/"worker-result.json",result)
    require(result["ok"],result.get("error","Reach incomplete worker"));return result


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--check-only",action="store_true")
    p.add_argument("--output",type=Path);p.add_argument("--permit",type=Path);args=p.parse_args()
    if args.check_only:print(json.dumps(preflight(args.core,args.baseline_core)))
    else:
        require(args.output is not None and args.permit is not None,"Reach output/permit required")
        run(args.output,args.permit,args.core,args.baseline_core)
    return 0


if __name__=="__main__":raise SystemExit(main())
