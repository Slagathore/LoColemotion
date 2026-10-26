"""Own contact-priority public controls and two independently reconstructed routes."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
import shutil
from pathlib import Path
import subprocess
import sys
import time
import uuid

from contact_sequence_public_task_v1 import ROOT,HERE,CONTRACT,SOURCES,CONTROLS,GATES,declaration,read,sha,require,CLOSURE_RESULT,DLL,DLL_SHA
from gpu_measurement_probe import write_new
from audit_gpu_batch_execution import same_bits
from run_gpu_measurement_probe import source_identity,invoke,jobs
from run_contact_sequence_v1 import bindings as parent_bindings,inventory
from run_residual_native import verify_tests


def bindings(core,baseline):
    value=parent_bindings(core,baseline)
    for path in (*[HERE/name for name in SOURCES],CONTRACT,CLOSURE_RESULT):
        value["source"][path.relative_to(ROOT).as_posix()]=sha(path)
    require(sha(DLL)==DLL_SHA,"Kernel runtime identity")
    value["runtime"][str(DLL)]=sha(DLL)
    return value


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);args=p.parse_args()
    core=args.core.resolve(strict=True);baseline=args.baseline_core.resolve(strict=True)
    source=source_identity(False);c=declaration()
    require(shutil.disk_usage(ROOT.parent/"SporeSpore_Evidence").free>=c["minimum_free_storage_bytes"],"Sequence durable storage budget")
    folder=ROOT.parent/"SporeSpore_Evidence"/("sdk2-contact-sequence-public-v1-"+uuid.uuid4().hex)
    folder.mkdir();print(str(folder),flush=True)
    receipt=dict(schema_version="locolemotion_contact_sequence_public_owner_v1",
        ledger_scope=c["ledger_scope"],source_commit=source,contract=c,ok=False,
        worlds_opened=0,solver_steps=0,physical_started=False,synthetic=True,controls_planned=CONTROLS,
        alternative_actions_generated_observations=False,recovery_benefit_established=False,
        dynamic_feasibility_established=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,training_data_authority=False,release_authority=False,equivalence_authority=False)
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;started=time.monotonic()
    try:
        require(jobs.wait(handle,0) in (0,128),"Another operation owns the mutex");owned=True
        before=bindings(core,baseline)
        status=subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()
        snapshot=folder/"source";snapshot.mkdir()
        for path in [HERE/name for name in SOURCES]+[CONTRACT,CLOSURE_RESULT]:
            with (snapshot/path.name).open("xb") as stream:stream.write(path.read_bytes())
            require(sha(snapshot/path.name)==before["source"][path.relative_to(ROOT).as_posix()],
                "Contact component source snapshot identity")
        write_new(folder/"declaration.json",dict(receipt,binding=before,source_status=status,
            contract_sha256=sha(CONTRACT)))
        env=dict(PYTHONPATH=";".join(str(ROOT/path) for path in ("sdk","sdk/python","sdk/discovery","sdk/explorer")),
            OPENBLAS_NUM_THREADS="1",OMP_NUM_THREADS="1",MKL_NUM_THREADS="1",PYTHONIOENCODING="utf-8",QUADRUPED_TEST_CORE=str(core))
        test_artifacts=folder/"test-artifacts";test_artifacts.mkdir()
        env["EXPLORER_TEST_OUTPUT"]=str(test_artifacts)
        receipt["controls_passed"]=0
        for name,module,count in GATES:
            invoke([sys.executable,"-B","-m","unittest","-v",module],folder/(name+"-controls"),c["maximum_control_wall_seconds"],env)
            verify_tests(folder/(name+"-controls"),count);receipt["controls_passed"]+=count
        for name in ("audit","reconstruction"):
            invoke([sys.executable,"-B",str(HERE/"audit_contact_sequence_public_v1.py"),
                "--core",str(core),"--baseline-core",str(baseline),"--output",str(folder/(name+".json"))],
                folder/(name+"-reader"),c["maximum_reader_wall_seconds"],env)
            require(read(folder/(name+".json"))["ok"] is True,"Contact component complete reader")
        require(same_bits(read(folder/"audit.json"),read(folder/"reconstruction.json")),"Contact component independent reconstruction")
        require(bindings(core,baseline)==before and source_identity(False)==source
            and subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()==status,
            "Contact component source/runtime drift")
        receipt.update(ok=True,source_runtime_unchanged=True,
            source_binding_count=len(before["source"]),runtime_binding_count=len(before["runtime"]),
            declaration_sha256=sha(folder/"declaration.json"),contract_sha256=sha(CONTRACT),
            audit_sha256=sha(folder/"audit.json"),reconstruction_sha256=sha(folder/"reconstruction.json"),
            gate_stderr_sha256={name:sha(folder/(name+"-controls/stderr.log")) for name,_,_ in GATES})
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
