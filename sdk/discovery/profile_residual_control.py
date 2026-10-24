"""Profile exact production residual decisions on retained native inputs; no physics."""
import argparse
import cProfile
import ctypes as C
from ctypes import wintypes as W
from contextlib import ExitStack
import json
from pathlib import Path
import pstats
import subprocess
import sys
import time
from unittest.mock import patch
import uuid

import mujoco
from residual_native_task import ROOT,HERE,declaration,model_artifact,controller_contract,require,sha,bridge,provider
from residual_control import ResidualController
from audit_residual_native_closure import CLOSURE,read,verify_record
from audit_gpu_batch_execution import read_jsonl,same_bits
from run_residual_native import bindings
from run_gpu_measurement_probe import source_identity,jobs
from gpu_measurement_probe import write_new


def hotspots(profile):
    rows=[]
    for (filename,line,function),(primitive,total,self_s,cumulative_s,_) in pstats.Stats(profile).stats.items():
        path=Path(filename)
        if path.is_absolute() and path.is_relative_to(ROOT):filename=path.relative_to(ROOT).as_posix()
        rows.append(dict(path=filename,line=line,function=function,primitive_calls=primitive,
            total_calls=total,self_s=self_s,cumulative_s=cumulative_s))
    return sorted(rows,key=lambda r:(-r["cumulative_s"],r["path"],r["line"],r["function"]))


def replay(directory,c,core,profiled,output):
    plan=read(directory/"plan.json");compiled=read(directory/"compiled.json")
    saved=list(read_jsonl(directory/"controller.jsonl"))
    require(len(saved)==c["outer_steps"]==120,"Residual profile population")
    model=provider.FrozenModel.load(core,model_artifact(plan["model_kind"]))
    controller=ResidualController(core,compiled,controller_contract(c,model),model,plan["mode"],plan["trial_id"])
    profile=cProfile.Profile() if profiled else None;actual=[];durations=[]
    try:
        if profile:profile.enable()
        started=time.perf_counter()
        for row in saved:
            tick=time.perf_counter()
            actual.append(controller.step(row["request"]["state"],row["stability"],row["kinematics"]))
            durations.append(time.perf_counter()-tick)
        wall=time.perf_counter()-started
    finally:
        if profile:profile.disable()
        controller.close()
    require(controller.session.closed and all(all(k in old and same_bits(v,old[k]) for k,v in new.items())
        for old,new in zip(saved,actual,strict=True)),"Residual profiled decision changed")
    result=dict(role=plan["role"],profiled=profiled,controller_rows=120,all_returned_fields_bit_identical=True,
        controller_closed=True,step_wall_s=wall,command_duration_s=durations,command_duration_sum_s=sum(durations))
    if profile:
        target=output/(plan["role"]+".pstats");profile.dump_stats(str(target))
        rows=hotspots(profile);write_new(output/(plan["role"]+"-hotspots.json"),rows)
        result.update(profile_sha256=sha(target),hotspot_count=len(rows),top_cumulative=rows[:30],
            hotspot_json_sha256=sha(output/(plan["role"]+"-hotspots.json")))
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);a=p.parse_args()
    core=a.core.resolve(strict=True);baseline=a.baseline_core.resolve(strict=True)
    source=source_identity(False);c=declaration();evidence=ROOT.parent/"SporeSpore_Evidence"
    folder=evidence/("sdk2-residual-control-profile-"+uuid.uuid4().hex);folder.mkdir()
    print(str(folder),flush=True)
    receipt=dict(schema_version="locolemotion_residual_control_profile_v1",ok=False,
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",authority_mode="development_diagnostic",question_class="development"),
        source_commit=source,profiler_sha256=sha(Path(__file__)),closure_sha256=sha(CLOSURE),
        worlds_opened=0,solver_steps=0,training_data_authority=False,physical_acceptance_authority=False,
        release_authority=False,profile_scope="three_retained_nominal_one_second_trajectories; descriptive_instrumented_costs_not_a_scaling_benchmark")
    status=subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;before=None;started=time.monotonic()
    try:
        require(jobs.wait(handle,0) in (0,128),"Another operation owns the mutex");owned=True
        before=bindings(core,baseline)
        with (folder/"profiler.py").open("xb") as f:f.write(Path(__file__).read_bytes())
        write_new(folder/"declaration.json",dict(receipt,binding=before,source_status=status,planned_decisions=720))
        with ExitStack() as guards:
            for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
                guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Residual profile opens no worlds")))
            verify_record(CLOSURE,evidence,core,baseline)
            closure=read(CLOSURE);original=evidence/closure["attempt_id"]/"physical"
            engine=bridge.LocomotionCore(core);rows=[]
            for plan in c["roles"]:
                directory=original/("route_nominal_"+plan["id"])
                for profiled in (False,True):
                    result=replay(directory,c,engine,profiled,folder);rows.append(result)
                    write_new(folder/(plan["id"]+("-profiled" if profiled else "-plain")+".json"),result)
            require(sum(r["controller_rows"] for r in rows)==720,"Residual complete profile count")
            receipt.update(original_native_attempt=closure["attempt_id"],controller_decisions=720,
                all_returned_fields_bit_identical=True,results=rows)
        require(bindings(core,baseline)==before and source_identity(False)==source
            and subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()==status,
            "Residual profile source/runtime drift")
        receipt.update(ok=True,source_runtime_unchanged=True,source_binding_count=len(before["source"]),
            runtime_binding_count=len(before["runtime"]))
    except BaseException as exc:receipt["error"]=f"{type(exc).__name__}: {exc}"
    finally:
        if owned:release(handle)
        jobs.close(handle);receipt["wall_s"]=time.monotonic()-started;write_new(folder/"receipt.json",receipt)
    print(json.dumps({k:v for k,v in receipt.items() if k!="results"}),flush=True)
    return 0 if receipt["ok"] else 1


if __name__=="__main__":raise SystemExit(main())
