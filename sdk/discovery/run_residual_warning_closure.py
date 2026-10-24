"""Retain six contained controls for the complete warning evidence closure."""
import argparse
import ctypes as C
from ctypes import wintypes as W
from pathlib import Path
import json
import subprocess
import sys
import time
import uuid

from audit_residual_warning_closure import ROOT,HERE,CLOSURE,MODEL,sha,require,read
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity,invoke,jobs
from run_residual_warning import bindings as warning_bindings
from run_residual_training import inventory
from run_residual_native import verify_tests

SOURCES=("audit_residual_warning_closure.py","test_residual_warning_closure.py","run_residual_warning_closure.py")


def bindings(core,baseline):
    value=warning_bindings(core,baseline)
    for path in (CLOSURE,MODEL):value["source"][path.relative_to(ROOT).as_posix()]=sha(path)
    return value


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);args=p.parse_args()
    core=args.core.resolve(strict=True);baseline=args.baseline_core.resolve(strict=True)
    source=source_identity(False)
    folder=ROOT.parent/"SporeSpore_Evidence"/("sdk2-residual-warning-closure-controls-"+uuid.uuid4().hex)
    folder.mkdir();print(str(folder),flush=True)
    scope=dict(subsystem="adaptation",engine_scope="core",authority_mode="development_closure_audit",question_class="development")
    receipt=dict(schema_version="locolemotion_residual_warning_closure_controls_v1",ledger_scope=scope,
        source_commit=source,ok=False,worlds_opened=0,solver_steps=0,controls_planned=6,
        physical_acceptance_authority=False,release_authority=False)
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;started=time.monotonic()
    try:
        require(jobs.wait(handle,0) in (0,128),"Another operation owns the mutex");owned=True
        before=bindings(core,baseline)
        status=subprocess.check_output(["git","status","--porcelain","--untracked-files=all"],cwd=ROOT,text=True).splitlines()
        snapshot=folder/"source";snapshot.mkdir()
        for path in [HERE/name for name in SOURCES]+[CLOSURE,MODEL]:
            with (snapshot/path.name).open("xb") as stream:stream.write(path.read_bytes())
            require(sha(snapshot/path.name)==before["source"][path.relative_to(ROOT).as_posix()],"Warning closure source snapshot")
        write_new(folder/"declaration.json",dict(receipt,binding=before,source_status=status,closure_sha256=sha(CLOSURE)))
        artifacts=folder/"artifacts";artifacts.mkdir()
        env=dict(PYTHONPATH=";".join(str(ROOT/path) for path in ("sdk","sdk/python","sdk/discovery","sdk/explorer")),
            OPENBLAS_NUM_THREADS="1",OMP_NUM_THREADS="1",MKL_NUM_THREADS="1",
            EXPLORER_TEST_OUTPUT=str(artifacts))
        invoke([sys.executable,"-B","-m","unittest","-v","test_residual_warning_closure"],folder/"controls",300,env)
        verify_tests(folder/"controls",6)
        require(read(artifacts/"complete-binding-check.json")["ok"] is True,"Warning closure complete binding check")
        require(bindings(core,baseline)==before and source_identity(False)==source
            and subprocess.check_output(["git","status","--porcelain","--untracked-files=all"],
                cwd=ROOT,text=True).splitlines()==status,"Warning closure source/runtime drift")
        receipt.update(ok=True,controls_passed=6,source_runtime_unchanged=True,
            source_binding_count=len(before["source"]),runtime_binding_count=len(before["runtime"]),
            declaration_sha256=sha(folder/"declaration.json"),closure_sha256=sha(CLOSURE),
            binding_check_sha256=sha(artifacts/"complete-binding-check.json"))
    except BaseException as exc:receipt["error"]=f"{type(exc).__name__}: {exc}"
    finally:
        receipt["wall_s"]=time.monotonic()-started
        try:
            receipt["artifacts"]=inventory(folder);write_new(folder/"receipt.json",receipt)
        finally:
            if owned:release(handle)
            jobs.close(handle)
    print(json.dumps(dict(ok=receipt["ok"],output=str(folder),error=receipt.get("error"))),flush=True)
    return 0 if receipt["ok"] else 1


if __name__=="__main__":raise SystemExit(main())
