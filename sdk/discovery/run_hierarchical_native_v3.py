"""Single contained owner for the gate and fresh four-world dynamic-control comparison."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid

from hierarchical_native_task_v3 import (ROOT,HERE,CONTRACT,MODEL,PARENT_CLOSURE,DIAGNOSIS,
    SOURCES,GATES,EXPECTED_CONTROLS,ROUTE_CONTROLS,FLAGS,declaration,plans,read,sha,require,COMPONENT_CONTRACT,COMPONENT_RESULT)
from gpu_measurement_probe import write_new
from audit_gpu_batch_execution import same_bits
from run_gpu_measurement_probe import source_identity,invoke,jobs
from run_hierarchical_public_v6 import bindings as parent_bindings,inventory
from run_residual_native import verify_tests


def bindings(core,baseline):
    value=parent_bindings(core,baseline)
    for path in (CONTRACT,MODEL,PARENT_CLOSURE,DIAGNOSIS,COMPONENT_CONTRACT,COMPONENT_RESULT):
        value["source"][path.relative_to(ROOT).as_posix()]=sha(path)
    return value


def capture_worker_state(receipt,folder):
    if not receipt["physical_launch_requested"]:
        receipt.update(constructed_cpu_worlds=0,constructed_gpu_worlds=0,physical_started=False)
        return
    try:
        worker=read(folder/"physical/worker-result.json");count=worker["constructed_cpu_worlds"]
        require(type(count) is int and 0<=count<=4 and worker["constructed_gpu_worlds"]==0,
                "Force route partial world population")
        receipt.update(constructed_cpu_worlds=count,constructed_gpu_worlds=0,physical_started=count>0)
    except (OSError,ValueError,KeyError,TypeError) as exc:
        lower=0
        for marker in (folder/"physical").glob("*/world-opened.json"):
            try:
                value=read(marker)
                if value["native_data_constructed"] is True and value["trial_id"]==marker.parent.name:lower+=1
            except (OSError,ValueError,KeyError,TypeError):pass
        receipt.update(constructed_cpu_worlds_lower_bound=lower,physical_started=True if lower else None,
                       worker_result_read_error=f"{type(exc).__name__}: {exc}")


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True)
    mode=p.add_mutually_exclusive_group()
    mode.add_argument("--run",action="store_true")
    mode.add_argument("--component-only",action="store_true",help="Only the declared new native-route controls and zero-world runtime preflight; cannot launch")
    args=p.parse_args();core=args.core.resolve(strict=True);baseline=args.baseline_core.resolve(strict=True)
    source=source_identity(args.run);c=declaration()
    require(sha(core)==c["core_sha256"] and sha(baseline)==c["baseline_core_sha256"],"Force route core freeze")
    evidence=ROOT.parent/"SporeSpore_Evidence"
    require(shutil.disk_usage(evidence).free>=c["minimum_free_storage_bytes"],"Force route retained storage")
    folder=evidence/("sdk2-hierarchical-native-v3-"+uuid.uuid4().hex);folder.mkdir();print(str(folder),flush=True)
    status=subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()
    receipt=dict(schema_version="locolemotion_hierarchical_native_owner_v3",ledger_scope=c["ledger_scope"],
        source_commit=source,contract=c,synthetic=False,ok=False,physical_started=False,component_only=args.component_only,
        physical_launch_requested=False,planned_trials=plans(c),source_status=status,
        planned_worlds=dict(cpu=4,gpu=0),**{k:False for k in FLAGS})
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;started=time.monotonic()
    try:
        require(jobs.wait(handle,0) in (0,128),"Another native operation owns the mutex");owned=True
        receipt["binding"]=bindings(core,baseline)
        for path in [HERE/n for n in SOURCES]+[CONTRACT,MODEL,PARENT_CLOSURE,DIAGNOSIS,COMPONENT_CONTRACT,COMPONENT_RESULT]:
            target=folder/"source"/path.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True)
            with target.open("xb") as stream:stream.write(path.read_bytes())
            require(sha(target)==receipt["binding"]["source"][path.relative_to(ROOT).as_posix()],
                    "Force route source snapshot identity")
        write_new(folder/"declaration.json",receipt)
        env=dict(PYTHONPATH=";".join(str(ROOT/x) for x in ("sdk","sdk/python","sdk/discovery","sdk/explorer")),
            QUADRUPED_TEST_CORE=str(baseline),PORTABLE_BATCH_BASELINE_CORE=str(baseline),
            SPORESPORE_LOCOMOTION_LIBRARY=str(baseline),OPENBLAS_NUM_THREADS="1",OMP_NUM_THREADS="1",
            MKL_NUM_THREADS="1",PYTHONIOENCODING="utf-8")
        batch_env=dict(env,QUADRUPED_TEST_CORE=str(core),SPORESPORE_LOCOMOTION_LIBRARY=str(core))
        receipt["safety_controls"]={}
        indexed=list(enumerate(GATES))
        if args.component_only:indexed=indexed[-1:]
        for index,(name,module,count) in indexed:
            artifacts=folder/(name+"-artifacts");artifacts.mkdir()
            print(json.dumps(dict(stage=name,controls=count)),flush=True)
            invoke([sys.executable,"-B","-m","unittest","-v",module],folder/(name+"-gate"),900,
                dict(env if index<3 else batch_env,EXPLORER_TEST_OUTPUT=str(artifacts)))
            verify_tests(folder/(name+"-gate"),count);receipt["safety_controls"][name]=count
        if not args.component_only:
            invoke([sys.executable,"-B","-m","unittest","-v","adaptation_provider.test_conformance"],
                   folder/"provider-gate",120,batch_env)
            verify_tests(folder/"provider-gate",2);receipt["safety_controls"]["provider"]=2
            invoke([sys.executable,"-B","-m","unittest",
                    "test_showcase.Construction.test_real_job_owner_reaps_leaf_and_descendant"],
                   folder/"containment-gate",90,dict(env,EXPLORER_TEST_OUTPUT=str(folder)))
            verify_tests(folder/"containment-gate",1);receipt["safety_controls"]["containment"]=1
        runtime=["--core",str(core),"--baseline-core",str(baseline)]
        invoke([sys.executable,"-B",str(HERE/"hierarchical_native_v3.py"),"--check-only",*runtime],
               folder/"runtime-gate",240,batch_env)
        receipt["preflight"]=read(folder/"runtime-gate/stdout.log")
        require(sum(receipt["safety_controls"].values())==(ROUTE_CONTROLS if args.component_only else EXPECTED_CONTROLS)
            and receipt["preflight"]["ok"] is True
            and receipt["preflight"]["world_build_count"]==receipt["preflight"]["solver_steps"]==0,
            "Force route complete zero-world gate")
        def unchanged():
            require(bindings(core,baseline)==receipt["binding"] and source_identity(args.run)==source
                and subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()==status,
                "Force route source/runtime drift")
        unchanged();receipt["zero_world_gate_passed"]=not args.component_only
        receipt["component_controls_passed"]=ROUTE_CONTROLS
        gate_name="component-receipt.json" if args.component_only else "gate-receipt.json"
        write_new(folder/gate_name,dict(ok=True,source_commit=source,
            declaration_sha256=sha(folder/"declaration.json"),safety_controls=receipt["safety_controls"],
            preflight=receipt["preflight"]))
        if args.run:
            write_new(folder/"consumed.json",dict(attempt_id=folder.name,source_commit=source,
                contract_sha256=sha(CONTRACT),declaration_sha256=sha(folder/"declaration.json"),
                gate_receipt_sha256=sha(folder/"gate-receipt.json"),trials=plans(c)))
            physical=folder/"physical";receipt["physical_launch_requested"]=True
            invoke([sys.executable,"-B",str(HERE/"hierarchical_native_v3.py"),*runtime,
                    "--output",str(physical),"--permit",str(physical/"contained.permit")],
                   physical,c["maximum_worker_wall_seconds"],batch_env)
            unchanged()
            for name in ("audit","reconstruction"):
                invoke([sys.executable,"-B",str(HERE/"audit_hierarchical_native_v3.py"),*runtime,
                    "--folder",str(physical),"--output",str(folder/(name+".json"))],
                    folder/(name+"-reader"),c["maximum_reader_wall_seconds"],batch_env)
                require(read(folder/(name+".json"))["ok"] is True,"Force route independent audit")
            require(same_bits(read(folder/"audit.json"),read(folder/"reconstruction.json")),
                    "Force route complete independent reconstruction")
            receipt["audit_sha256"]=sha(folder/"audit.json")
            receipt["reconstruction_sha256"]=sha(folder/"reconstruction.json")
        unchanged();receipt.update(ok=True,source_runtime_unchanged=True)
    except BaseException as exc:receipt["error"]=f"{type(exc).__name__}: {exc}"
    finally:
        capture_worker_state(receipt,folder);receipt["wall_s"]=time.monotonic()-started
        try:
            receipt["artifacts"]=inventory(folder);write_new(folder/"receipt.json",receipt)
        finally:
            if owned:release(handle)
            jobs.close(handle)
    print(json.dumps(dict(ok=receipt["ok"],output=str(folder),physical_started=receipt["physical_started"],
        constructed_cpu_worlds=receipt.get("constructed_cpu_worlds"),error=receipt.get("error"))),flush=True)
    return 0 if receipt["ok"] else 1


if __name__=="__main__":raise SystemExit(main())
