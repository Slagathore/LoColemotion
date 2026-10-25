"""Own complete zero-world verification of the configured dynamic controller."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
from pathlib import Path
import subprocess
import shutil
import sys
import time
import uuid
import importlib.metadata as metadata

from dynamic_control_component_task import ROOT,HERE,CONTRACT,SOURCES,CONTROLS,GATES,declaration,read,sha,require,READBACK,FAILURE,DEPENDENCIES,LOCK,FLAGS
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity,invoke,jobs
from run_floating_dynamics_readback import bindings as parent_bindings,inventory
from run_residual_native import verify_tests


def bindings(core,baseline):
    value=parent_bindings(core,baseline)
    for path in (CONTRACT,READBACK,FAILURE,DEPENDENCIES,LOCK):
        value["source"][path.relative_to(ROOT).as_posix()]=sha(path)
    for package in ("osqp","scipy","jinja2","joblib","markupsafe","setuptools"):
        dist=metadata.distribution(package)
        for entry in dist.files:
            path=Path(dist.locate_file(entry)).resolve()
            if path.is_file() and path.suffix not in (".pyc",".pyo"):
                value["runtime"][str(path)]=sha(path)
    return value


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);args=p.parse_args()
    core=args.core.resolve(strict=True);baseline=args.baseline_core.resolve(strict=True)
    source=source_identity(False);c=declaration()
    require(shutil.disk_usage(ROOT.parent/"SporeSpore_Evidence").free>=c["minimum_free_storage_bytes"],"Reach retained storage")
    folder=ROOT.parent/"SporeSpore_Evidence"/("sdk2-dynamic-control-component-"+uuid.uuid4().hex)
    folder.mkdir();print(str(folder),flush=True)
    receipt=dict(schema_version="locolemotion_dynamic_control_component_owner_v1",
        ledger_scope=c["ledger_scope"],source_commit=source,contract=c,ok=False,
        worlds_opened=0,solver_steps=0,physical_started=False,synthetic=True,controls_planned=CONTROLS,
        alternative_actions_generated_observations=False,recovery_benefit_established=False,
        dynamic_feasibility_established=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,training_data_authority=False,release_authority=False,equivalence_authority=False)
    receipt.update({k:False for k in FLAGS})
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;started=time.monotonic()
    try:
        require(jobs.wait(handle,0) in (0,128),"Another operation owns the mutex");owned=True
        before=bindings(core,baseline)
        status=subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()
        snapshot=folder/"source";snapshot.mkdir()
        for path in [HERE/name for name in SOURCES]+[CONTRACT,READBACK,FAILURE,DEPENDENCIES,LOCK]:
            with (snapshot/path.name).open("xb") as stream:stream.write(path.read_bytes())
            require(sha(snapshot/path.name)==before["source"][path.relative_to(ROOT).as_posix()],
                "Force component source snapshot identity")
        write_new(folder/"declaration.json",dict(receipt,binding=before,source_status=status,
            contract_sha256=sha(CONTRACT)))
        env=dict(PYTHONPATH=";".join(str(ROOT/path) for path in ("sdk","sdk/python","sdk/discovery","sdk/explorer")),
            OPENBLAS_NUM_THREADS="1",OMP_NUM_THREADS="1",MKL_NUM_THREADS="1",PYTHONIOENCODING="utf-8",QUADRUPED_TEST_CORE=str(core))
        receipt["controls_passed"]=0
        for name,module,count in GATES:
            invoke([sys.executable,"-B","-m","unittest","-v",module],folder/(name+"-controls"),120,env)
            verify_tests(folder/(name+"-controls"),count);receipt["controls_passed"]+=count
        invoke([sys.executable,"-B","-m","pip","check"],folder/"dependency-check",60,env)
        require((folder/"dependency-check/stdout.log").read_text(encoding="utf-8").strip()=="No broken requirements found.",
            "Dynamic dependency compatibility")
        for name in ("audit","reconstruction"):
            invoke([sys.executable,"-B",str(HERE/"audit_dynamic_control_component.py"),
                "--core",str(core),"--baseline-core",str(baseline),"--output",str(folder/(name+".json"))],
                folder/(name+"-reader"),c["maximum_reader_wall_seconds"],env)
            require(read(folder/(name+".json"))["ok"] is True,"Force component complete reader")
        require(read(folder/"audit.json")==read(folder/"reconstruction.json"),"Force component independent reconstruction")
        require(bindings(core,baseline)==before and source_identity(False)==source
            and subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()==status,
            "Force component source/runtime drift")
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
