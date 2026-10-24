"""Contain and retain a zero-world warning fit, controls and independent reader."""
import argparse
import ctypes as C
from ctypes import wintypes as W
from pathlib import Path
import json
import subprocess
import sys
import time
import uuid

import residual_warning_fit as fit
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity,invoke,jobs
from run_residual_selection import bindings as previous_bindings,inventory
from run_residual_native import verify_tests

ROOT,HERE=fit.ROOT,fit.HERE
sha,require,read=fit.sha,fit.require,fit.read
CONTROL_COUNT=20


def bindings(core,baseline):
    value=previous_bindings(core,baseline)
    for path in [fit.CONTRACT,*fit.warning.CONTRACT.parent.glob("*")]:
        if path.is_file():value["source"][path.relative_to(ROOT).as_posix()]=sha(path)
    return value


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);args=p.parse_args()
    core=args.core.resolve(strict=True);baseline=args.baseline_core.resolve(strict=True)
    source=source_identity(False);recipe=fit.recipe()
    folder=ROOT.parent/"SporeSpore_Evidence"/("sdk2-residual-warning-fit-"+uuid.uuid4().hex)
    folder.mkdir();print(str(folder),flush=True)
    receipt=dict(schema_version="locolemotion_residual_warning_owner_v1",ledger_scope=fit.SCOPE,
        source_commit=source,ok=False,physical_started=False,worlds_opened=0,solver_steps=0,
        controls_planned=CONTROL_COUNT,planned_training_episodes=64,planned_rows=92160,
        planned_gpu_worlds=0,planned_cpu_worlds=0,
        physical_acceptance_authority=False,release_authority=False,
        automatic_withdrawal_authority=False,tier2_complete=False,tier3_complete=False)
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;started=time.monotonic()
    try:
        require(jobs.wait(handle,0) in (0,128),"Another operation owns the mutex");owned=True
        before=bindings(core,baseline)
        status=subprocess.check_output(["git","status","--porcelain","--untracked-files=all"],cwd=ROOT,text=True).splitlines()
        paths=[HERE/name for name in fit.SOURCES]+[fit.CONTRACT]
        paths+=[p for p in fit.warning.CONTRACT.parent.glob("*") if p.is_file()]
        for path in paths:
            target=folder/"source"/path.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True)
            with target.open("xb") as stream:stream.write(path.read_bytes())
            require(sha(target)==before["source"][path.relative_to(ROOT).as_posix()],"Warning exact source snapshot")
        write_new(folder/"declaration.json",dict(receipt,binding=before,source_status=status,recipe=recipe))
        env=dict(PYTHONPATH=";".join(str(ROOT/path) for path in ("sdk","sdk/python","sdk/discovery","sdk/explorer")),
            OPENBLAS_NUM_THREADS="1",OMP_NUM_THREADS="1",MKL_NUM_THREADS="1",NUMEXPR_NUM_THREADS="1")
        def unchanged():
            require(bindings(core,baseline)==before and source_identity(False)==source
                and subprocess.check_output(["git","status","--porcelain","--untracked-files=all"],
                    cwd=ROOT,text=True).splitlines()==status,"Warning source/runtime drift")
        invoke([sys.executable,"-B","-m","unittest","-v","test_residual_warning"],folder/"controls",300,env)
        verify_tests(folder/"controls",CONTROL_COUNT);receipt["controls_passed"]=CONTROL_COUNT
        unchanged();print(json.dumps(dict(stage="complete_training_fit")),flush=True)
        output=folder/"fit";output.mkdir()
        invoke([sys.executable,"-B",str(HERE/"residual_warning_fit.py"),"--output",str(output)],
            folder/"fit-worker",1200,env)
        unchanged();print(json.dumps(dict(stage="independent_reader")),flush=True)
        invoke([sys.executable,"-B",str(HERE/"audit_residual_warning.py"),"--folder",str(output),
            "--output",str(folder/"audit.json")],folder/"independent-reader",1200,env)
        audit=read(folder/"audit.json")
        require(audit["ok"] is True and audit["reader_world_build_count"]==audit["reader_solver_steps"]==0
            and len(audit["corruption_controls_passed"])==8,"Warning complete independent reader")
        unchanged()
        receipt.update(ok=True,source_runtime_unchanged=True,
            source_binding_count=len(before["source"]),runtime_binding_count=len(before["runtime"]),
            declaration_sha256=sha(folder/"declaration.json"),audit_sha256=sha(folder/"audit.json"),
            fit_sha256=sha(output/"fit.json"),dataset_sha256=read(output/"data-manifest.json")["dataset_sha256"],
            final_model_sha256=audit["final_model_sha256"],reader_corruption_controls_passed=8)
    except BaseException as exc:receipt["error"]=f"{type(exc).__name__}: {exc}"
    finally:
        receipt["wall_s"]=time.monotonic()-started
        try:
            receipt["artifacts"]=inventory(folder);write_new(folder/"receipt.json",receipt)
        finally:
            if owned:release(handle)
            jobs.close(handle)
    print(json.dumps(dict(ok=receipt["ok"],output=str(folder),worlds_opened=0,error=receipt.get("error"))),flush=True)
    return 0 if receipt["ok"] else 1


if __name__=="__main__":raise SystemExit(main())
