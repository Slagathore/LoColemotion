"""Own zero-world recovery diagnosis, corruption controls and complete reconstruction."""
import argparse
import ctypes as C
from ctypes import wintypes as W
from pathlib import Path
import json
import subprocess
import sys
import time
import uuid

import residual_recovery_diagnostic as diagnostic
from residual_recovery_diagnostic import ROOT,HERE,CLOSURE,read,sha,require
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity,invoke,jobs
from run_residual_recovery_training_closure import bindings
from run_residual_recovery_training import inventory
from run_residual_native import verify_tests


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);args=p.parse_args()
    core=args.core.resolve(strict=True);baseline=args.baseline_core.resolve(strict=True)
    source=source_identity(False)
    folder=ROOT.parent/"SporeSpore_Evidence"/("sdk2-recovery-diagnosis-"+uuid.uuid4().hex)
    folder.mkdir();print(str(folder),flush=True)
    receipt=dict(schema_version="locolemotion_residual_recovery_diagnostic_owner_v1",
        ledger_scope=diagnostic.SCOPE,source_commit=source,ok=False,worlds_opened=0,solver_steps=0,
        controls_planned=diagnostic.CONTROLS,**{k:False for k in diagnostic.DENIALS})
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;started=time.monotonic()
    try:
        require(jobs.wait(handle,0) in (0,128),"Another native operation owns the mutex");owned=True
        require(sha(CLOSURE)==diagnostic.PARENT_SHA,"Recovery diagnostic parent identity")
        before=bindings(core,baseline)
        status=subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()
        snapshot=folder/"source";snapshot.mkdir()
        for path in [HERE/name for name in diagnostic.SOURCES]+[CLOSURE]:
            with (snapshot/path.name).open("xb") as stream:stream.write(path.read_bytes())
            require(sha(snapshot/path.name)==before["source"][path.relative_to(ROOT).as_posix()],
                "Recovery diagnosis source snapshot")
        write_new(folder/"declaration.json",dict(receipt,binding=before,source_status=status,
            parent_closure_sha256=sha(CLOSURE),complete_parent_reconstruction_required=True,
            complete_diagnostic_reconstruction_required=True))
        artifacts=folder/"artifacts";artifacts.mkdir()
        env=dict(PYTHONPATH=";".join(str(ROOT/path) for path in ("sdk","sdk/python","sdk/discovery","sdk/explorer")),
            QUADRUPED_TEST_CORE=str(core),PORTABLE_BATCH_BASELINE_CORE=str(baseline),
            SPORESPORE_LOCOMOTION_LIBRARY=str(core),EXPLORER_TEST_OUTPUT=str(artifacts),
            OPENBLAS_NUM_THREADS="1",OMP_NUM_THREADS="1",MKL_NUM_THREADS="1",NUMEXPR_NUM_THREADS="1",
            PYTHONIOENCODING="utf-8")
        invoke([sys.executable,"-B","-m","unittest","-v","test_residual_recovery_diagnostic"],folder/"controls",180,env)
        verify_tests(folder/"controls",diagnostic.CONTROLS);receipt["controls_passed"]=diagnostic.CONTROLS
        command=[sys.executable,"-B",str(HERE/"residual_recovery_diagnostic.py"),"--output-dir",str(artifacts),
            "--core",str(core),"--baseline-core",str(baseline)]
        invoke([*command,"--mode","produce"],folder/"produce",3600,env)
        invoke([*command,"--mode","verify"],folder/"reconstruct",3600,env)
        require(read(artifacts/"complete-reconstruction.json")["ok"] is True,"Recovery diagnosis complete reconstruction")
        require(bindings(core,baseline)==before and source_identity(False)==source
            and subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()==status,
            "Recovery diagnosis source/runtime drift")
        receipt.update(ok=True,source_runtime_unchanged=True,
            source_binding_count=len(before["source"]),runtime_binding_count=len(before["runtime"]),
            declaration_sha256=sha(folder/"declaration.json"),parent_closure_sha256=sha(CLOSURE),
            diagnostic_sha256=sha(artifacts/"diagnostic.json"),
            parent_reconstruction_sha256=sha(artifacts/"parent-reconstruction.json"),
            reconstruction_sha256=sha(artifacts/"complete-reconstruction.json"),
            stderr_sha256=sha(folder/"controls/stderr.log"))
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
