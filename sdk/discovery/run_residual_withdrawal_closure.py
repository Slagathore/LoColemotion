"""Retain nine contained zero-world controls for the complete withdrawal closure."""
import argparse
import ctypes as C
from ctypes import wintypes as W
from pathlib import Path
import json
import subprocess
import sys
import time
import uuid

from audit_residual_withdrawal_closure import ROOT,HERE,CLOSURE,sha,require,read
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity,invoke,jobs
from run_residual_withdrawal import bindings as training_bindings,inventory
from run_residual_native import verify_tests

SOURCES=("audit_residual_withdrawal_closure.py","test_residual_withdrawal_closure.py","run_residual_withdrawal_closure.py")


def bindings(core,baseline):
    value=training_bindings(core,baseline)
    value["source"][CLOSURE.relative_to(ROOT).as_posix()]=sha(CLOSURE)
    return value


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);args=p.parse_args()
    core=args.core.resolve(strict=True);baseline=args.baseline_core.resolve(strict=True)
    source=source_identity(False)
    folder=ROOT.parent/"SporeSpore_Evidence"/("sdk2-residual-withdrawal-closure-controls-"+uuid.uuid4().hex)
    folder.mkdir();print(str(folder),flush=True)
    scope=dict(subsystem="adaptation",engine_scope="core",authority_mode="development_closure_audit",question_class="development")
    receipt=dict(schema_version="locolemotion_residual_withdrawal_closure_controls_v1",ledger_scope=scope,
        source_commit=source,ok=False,worlds_opened=0,solver_steps=0,controls_planned=9,
        physical_acceptance_authority=False,release_authority=False,training_data_authority=False)
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;started=time.monotonic()
    try:
        require(jobs.wait(handle,0) in (0,128),"Another native operation owns the mutex");owned=True
        before=bindings(core,baseline)
        status=subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()
        snapshot=folder/"source";snapshot.mkdir()
        for path in [HERE/name for name in SOURCES]+[CLOSURE]:
            with (snapshot/path.name).open("xb") as stream:stream.write(path.read_bytes())
            require(sha(snapshot/path.name)==before["source"][path.relative_to(ROOT).as_posix()],"Withdrawal closure source snapshot")
        write_new(folder/"declaration.json",dict(receipt,binding=before,source_status=status,closure_sha256=sha(CLOSURE)))
        artifacts=folder/"artifacts";artifacts.mkdir()
        env=dict(PYTHONPATH=";".join(str(ROOT/path) for path in ("sdk","sdk/python","sdk/discovery","sdk/explorer")),
            QUADRUPED_TEST_CORE=str(core),PORTABLE_BATCH_BASELINE_CORE=str(baseline),
            SPORESPORE_LOCOMOTION_LIBRARY=str(core),EXPLORER_TEST_OUTPUT=str(artifacts))
        invoke([sys.executable,"-B","-m","unittest","-v","test_residual_withdrawal_closure"],folder/"controls",1800,env)
        verify_tests(folder/"controls",9)
        require(read(artifacts/"complete-reconstruction.json")["ok"] is True,"Withdrawal closure complete reconstruction")
        require(bindings(core,baseline)==before and source_identity(False)==source
            and subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()==status,
            "Withdrawal closure source/runtime drift")
        receipt.update(ok=True,controls_passed=9,source_runtime_unchanged=True,
            source_binding_count=len(before["source"]),runtime_binding_count=len(before["runtime"]),
            declaration_sha256=sha(folder/"declaration.json"),closure_sha256=sha(CLOSURE),
            reconstruction_sha256=sha(artifacts/"complete-reconstruction.json"),stderr_sha256=sha(folder/"controls/stderr.log"))
    except BaseException as exc:receipt["error"]=f"{type(exc).__name__}: {exc}"
    finally:
        receipt["wall_s"]=time.monotonic()-started
        try:
            receipt["artifacts"]=inventory(folder)
            write_new(folder/"receipt.json",receipt)
        finally:
            if owned:release(handle)
            jobs.close(handle)
    print(json.dumps(dict(ok=receipt["ok"],output=str(folder),error=receipt.get("error"))),flush=True)
    return 0 if receipt["ok"] else 1


if __name__=="__main__":raise SystemExit(main())
