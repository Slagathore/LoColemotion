"""Retain contained analytical recovery-training controls with zero worlds."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid

from residual_recovery_task import ROOT,sha,require
from run_residual_recovery import bindings as parent_bindings
from run_residual_training import inventory
from run_gpu_measurement_probe import source_identity,invoke,jobs
from run_residual_native import verify_tests
from gpu_measurement_probe import write_new

SOURCES=tuple(ROOT/p for p in (
    "sdk/adaptation_provider/bounded_residual_ars_fixed_v1.py",
    "sdk/discovery/residual_recovery_training_objective.py",
    "sdk/discovery/test_residual_recovery_training_component.py",
    "sdk/discovery/run_residual_recovery_training_component.py",
    "sdk/discovery/residual_recovery_closure_v1.json"))


def bindings(core,baseline):
    value=parent_bindings(core,baseline)
    for path in SOURCES:value["source"][path.relative_to(ROOT).as_posix()]=sha(path)
    return value


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);args=p.parse_args()
    core=args.core.resolve(strict=True);baseline=args.baseline_core.resolve(strict=True);source=source_identity(False)
    folder=ROOT.parent/"SporeSpore_Evidence"/("sdk2-recovery-training-component-"+uuid.uuid4().hex)
    folder.mkdir();print(str(folder),flush=True)
    scope=dict(subsystem="adaptation",engine_scope="core",authority_mode="development_training_component",question_class="development")
    receipt=dict(schema_version="locolemotion_recovery_training_component_controls_v1",ledger_scope=scope,
        source_commit=source,ok=False,controls_planned=18,worlds_opened=0,solver_steps=0,
        synthetic_inputs=True,retained_native_inputs=False,new_physical_outcomes=False,
        training_updates_are_analytical_fixtures=True,training_data_authority=False,
        physical_acceptance_authority=False,release_authority=False,tier2_complete=False,tier3_complete=False)
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;started=time.monotonic()
    try:
        require(jobs.wait(handle,0) in (0,128),"Another operation owns the mutex");owned=True
        before=bindings(core,baseline)
        status=subprocess.check_output(["git","status","--porcelain","--untracked-files=all"],cwd=ROOT,text=True).splitlines()
        for path in SOURCES:
            target=folder/"source"/path.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True)
            with target.open("xb") as stream:stream.write(path.read_bytes())
            require(sha(target)==before["source"][path.relative_to(ROOT).as_posix()],"Recovery training component source snapshot")
        write_new(folder/"declaration.json",dict(receipt,binding=before,source_status=status))
        env=dict(PYTHONPATH=";".join(str(ROOT/p) for p in ("sdk","sdk/python","sdk/discovery","sdk/explorer")),
            OPENBLAS_NUM_THREADS="1",OMP_NUM_THREADS="1",MKL_NUM_THREADS="1")
        invoke([sys.executable,"-B","-m","unittest","-v","test_residual_recovery_training_component"],folder/"controls",180,env)
        verify_tests(folder/"controls",18)
        require(bindings(core,baseline)==before and source_identity(False)==source
            and subprocess.check_output(["git","status","--porcelain","--untracked-files=all"],cwd=ROOT,text=True).splitlines()==status,
            "Recovery training component source/runtime drift")
        receipt.update(ok=True,controls_passed=18,source_runtime_unchanged=True,
            source_binding_count=len(before["source"]),runtime_binding_count=len(before["runtime"]),
            declaration_sha256=sha(folder/"declaration.json"),stderr_sha256=sha(folder/"controls/stderr.log"))
    except BaseException as exc:receipt["error"]=f"{type(exc).__name__}: {exc}"
    finally:
        receipt["wall_s"]=time.monotonic()-started
        try:receipt["artifacts"]=inventory(folder);write_new(folder/"receipt.json",receipt)
        finally:
            if owned:release(handle)
            jobs.close(handle)
    print(json.dumps(dict(ok=receipt["ok"],output=str(folder),error=receipt.get("error"))),flush=True)
    return 0 if receipt["ok"] else 1


if __name__=="__main__":raise SystemExit(main())
