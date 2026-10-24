"""Single-owner complete-gate launcher for frozen warning intervention diagnostics."""
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

from residual_recovery_task import (ROOT,HERE,CONTRACT,SOURCES,FLAGS,GATES,EXPECTED_CONTROLS,
    declaration,all_plans,prepare_stage,read,sha,require,ARTIFACTS,COMPONENTS)
from run_gpu_measurement_probe import source_identity,invoke,jobs
from run_residual_withdrawal import bindings as previous_bindings
from run_residual_training import inventory,capture_worker_state
from run_residual_native import verify_tests
from gpu_measurement_probe import write_new


def bindings(core,baseline):
    value=previous_bindings(core,baseline)
    for path in (CONTRACT,*ARTIFACTS,*COMPONENTS):
        value["source"][path.relative_to(ROOT).as_posix()]=sha(path)
    for name in SOURCES:
        require(value["source"][(HERE/name).relative_to(ROOT).as_posix()]==sha(HERE/name),
            "Residual selection snapshot population")
    return value


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--run",action="store_true")
    args=p.parse_args();core=args.core.resolve(strict=True);baseline=args.baseline_core.resolve(strict=True)
    source=source_identity(args.run);c=declaration()
    require(sha(core)==c["core_sha256"] and sha(baseline)==c["baseline_core_sha256"],"Residual selection core freeze")
    evidence=ROOT.parent/"SporeSpore_Evidence"
    require(shutil.disk_usage(evidence).free>=c["minimum_free_storage_bytes"],"Residual selection capture storage")
    folder=evidence/("sdk2-residual-recovery-"+uuid.uuid4().hex);folder.mkdir();print(str(folder),flush=True)
    status=subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()
    receipt=dict(schema_version="locolemotion_residual_recovery_owner_v1",ledger_scope=c["ledger_scope"],
        source_commit=source,contract=c,synthetic=False,ok=False,physical_started=False,physical_launch_requested=False,
        requested_stages=[],completed_stages=[],stage_records=[],planned_trials=all_plans(c),
        planned_worlds=dict(cpu=14,gpu=0),training_data_scope=c["training_data_scope"],
        challenge_choice_is_retrospective=True,recovery_choice_is_retrospective=True,comparison_data_used_for_fitting=False,**{k:False for k in FLAGS})
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;started=time.monotonic()
    try:
        require(jobs.wait(handle,0) in (0,128),"Another native operation owns the mutex");owned=True
        receipt["binding"]=bindings(core,baseline);receipt["source_status"]=status
        snapshots=folder/"source";snapshots.mkdir()
        for path in [HERE/n for n in SOURCES]+[CONTRACT,*ARTIFACTS,*COMPONENTS]:
            target=snapshots/path.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True)
            with target.open("xb") as stream:stream.write(path.read_bytes())
            require(sha(target)==receipt["binding"]["source"][path.relative_to(ROOT).as_posix()],
                "Residual selection source snapshot")
        write_new(folder/"declaration.json",receipt)
        env=dict(PYTHONPATH=";".join(str(ROOT/p) for p in ("sdk","sdk/python","sdk/discovery","sdk/explorer")),
            QUADRUPED_TEST_CORE=str(baseline),PORTABLE_BATCH_BASELINE_CORE=str(baseline),SPORESPORE_LOCOMOTION_LIBRARY=str(baseline),
            OPENBLAS_NUM_THREADS="1",OMP_NUM_THREADS="1",MKL_NUM_THREADS="1",NUMEXPR_NUM_THREADS="1")
        batch_env=dict(env,QUADRUPED_TEST_CORE=str(core),SPORESPORE_LOCOMOTION_LIBRARY=str(core))
        receipt["safety_controls"]={}
        for index,(name,module,count) in enumerate(GATES):
            artifacts=folder/(name+"-artifacts");artifacts.mkdir()
            print(json.dumps(dict(stage=name,controls=count)),flush=True)
            invoke([sys.executable,"-B","-m","unittest","-v",module],folder/(name+"-gate"),1800,
                dict(env if index<3 else batch_env,EXPLORER_TEST_OUTPUT=str(artifacts)))
            verify_tests(folder/(name+"-gate"),count);receipt["safety_controls"][name]=count
        invoke([sys.executable,"-B","-m","unittest","-v","adaptation_provider.test_conformance"],
            folder/"provider-gate",120,batch_env)
        verify_tests(folder/"provider-gate",2);receipt["safety_controls"]["provider"]=2
        invoke([sys.executable,"-B","-m","unittest",
            "test_showcase.Construction.test_real_job_owner_reaps_leaf_and_descendant"],
            folder/"containment-gate",90,dict(env,EXPLORER_TEST_OUTPUT=str(folder)))
        verify_tests(folder/"containment-gate",1);receipt["safety_controls"]["containment"]=1
        runtime=["--core",str(core),"--baseline-core",str(baseline),"--lane","comparison"]
        invoke([sys.executable,"-B",str(HERE/"residual_recovery_native.py"),"--check-only",*runtime],
            folder/"runtime-gate",180,batch_env)
        receipt["preflight"]=read(folder/"runtime-gate/stdout.log")
        require(sum(receipt["safety_controls"].values())==EXPECTED_CONTROLS
            and receipt["preflight"]["ok"] is True and receipt["preflight"]["world_build_count"]==0
            and receipt["preflight"]["solver_steps"]==0,"Residual selection full zero-world gate")
        def unchanged():
            require(bindings(core,baseline)==receipt["binding"] and source_identity(args.run)==source
                and subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()==status,
                "Residual selection source/runtime drift")
        unchanged();receipt["zero_world_gate_passed"]=True
        write_new(folder/"gate-receipt.json",dict(ok=True,source_commit=source,safety_controls=receipt["safety_controls"],
            preflight=receipt["preflight"],declaration_sha256=sha(folder/"declaration.json")))
        if args.run:
            write_new(folder/"consumed.json",dict(attempt_id=folder.name,source_commit=source,lane=c["lane"],
                contract_sha256=sha(CONTRACT),declaration_sha256=sha(folder/"declaration.json"),
                gate_receipt_sha256=sha(folder/"gate-receipt.json"),trials=all_plans(c)))
            (folder/"stages").mkdir();directory=folder/"stages/comparison"
            from residual_recovery_task import bridge
            prepare_stage(directory,c,bridge.LocomotionCore(core));physical=directory/"physical"
            receipt["requested_stages"].append("comparison");receipt["physical_launch_requested"]=True
            unchanged();print(json.dumps(dict(stage="comparison",event="native_stage_launch")),flush=True)
            invoke([sys.executable,"-B",str(HERE/"residual_recovery_native.py"),*runtime,"--output",str(physical),
                "--permit",str(physical/"contained.permit")],physical,c["maximum_worker_wall_seconds"],batch_env)
            unchanged()
            invoke([sys.executable,"-B",str(HERE/"audit_residual_recovery.py"),*runtime,"--folder",str(physical),
                "--output",str(directory/"audit.json")],directory/"independent-reader",c["maximum_reader_wall_seconds"],batch_env)
            audit=read(directory/"audit.json")
            require(audit["ok"] is True and audit["synthetic"] is False
                and audit["reader_world_build_count"]==audit["reader_solver_steps"]==0,
                "Residual selected complete independent audit")
            receipt["stage_records"].append(dict(stage="comparison",stage_claim_sha256=sha(directory/"stage.json"),
                audit_sha256=sha(directory/"audit.json"),constructed_cpu_worlds=audit["constructed_cpu_worlds"],
                controller_rows=audit["controller_rows"],internal_rows=audit["internal_rows"]))
            receipt["completed_stages"].append("comparison");receipt["final_comparison"]=audit["final_comparison"]
            print(json.dumps(dict(stage="comparison",event="complete_and_independently_verified")),flush=True)
        unchanged();receipt.update(ok=True,source_runtime_unchanged=True)
    except BaseException as exc:
        receipt["error"]=f"{type(exc).__name__}: {exc}"
    finally:
        receipt["wall_s"]=time.monotonic()-started
        try:
            capture_worker_state(receipt,folder);receipt["artifacts"]=inventory(folder)
            write_new(folder/"receipt.json",receipt)
        finally:
            if owned:release(handle)
            jobs.close(handle)
    print(json.dumps(dict(ok=receipt["ok"],output=str(folder),physical_started=receipt["physical_started"],
        constructed_cpu_worlds=receipt.get("constructed_cpu_worlds"),error=receipt.get("error"))),flush=True)
    return 0 if receipt["ok"] else 1


if __name__=="__main__":raise SystemExit(main())
