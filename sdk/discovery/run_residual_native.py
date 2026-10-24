"""Full applicable safety gate and single-use contained residual native smoke."""
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

from residual_native_task import ROOT,HERE,CONTRACT,SOURCES,FLAGS,GATES,EXPECTED_CONTROLS,declaration,trial_plan,require,sha
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity,invoke,jobs
from run_gpu_portable_search import bindings as parent_bindings


def normalize_source_bindings(source):
    canonical={}
    for name,digest in source.items():
        key=Path(name).as_posix()
        require(key not in canonical or canonical[key]==digest,"Residual conflicting source aliases")
        canonical[key]=digest
    return canonical


def bindings(core,baseline):
    value=parent_bindings(baseline)
    value["runtime"][str(core)]=sha(core)
    value["source"][CONTRACT.relative_to(ROOT).as_posix()]=sha(CONTRACT)
    for path in (ROOT/"sdk/adaptation_provider/retrieval").glob("*.py"):
        value["source"][path.relative_to(ROOT).as_posix()]=sha(path)
    value["source"]=normalize_source_bindings(value["source"])
    return value


def verify_tests(folder,count):
    text=(folder/"stderr.log").read_text(encoding="utf-8")
    noun="test" if count==1 else "tests"
    require(f"Ran {count} {noun} in " in text and text.rstrip().endswith("OK"),
        "Residual complete safety controls: "+folder.name)


def capture_worker_state(receipt,folder):
    if not receipt["physical_launch_requested"]:
        receipt.update(constructed_cpu_worlds=0,constructed_gpu_worlds=0,physical_started=False)
        return
    worker=folder/"physical/worker-result.json"
    if worker.is_file():
        try:
            value=json.loads(worker.read_text(encoding="utf-8"))
            cpu,gpu=value["constructed_cpu_worlds"],value["constructed_gpu_worlds"]
            require(type(cpu) is int and 0<=cpu<=3 and type(gpu) is int and gpu==0,
                "Residual partial worker count")
            receipt.update(constructed_cpu_worlds=cpu,constructed_gpu_worlds=gpu,physical_started=cpu>0)
            return
        except (OSError,ValueError,KeyError,TypeError) as exc:
            # A timeout can interrupt write_new(). Preserve that fact without
            # losing the owner's original error or its terminal receipt.
            receipt.update(ok=False,worker_result_read_error=f"{type(exc).__name__}: {exc}")
    valid_markers=0
    for marker in (folder/"physical").glob("*/world-opened.json"):
        try:
            value=json.loads(marker.read_text(encoding="utf-8"))
            if (value["native_data_constructed"] is True and value["trial_id"]==marker.parent.name
                    and value["core_sha256"]==receipt["contract"]["core_sha256"]):
                valid_markers+=1
        except (OSError,ValueError,KeyError,TypeError):
            pass
    receipt["constructed_cpu_worlds_lower_bound"]=valid_markers
    receipt["physical_started"]=True if valid_markers else None


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--run",action="store_true")
    args=p.parse_args();core=args.core.resolve(strict=True);baseline=args.baseline_core.resolve(strict=True)
    source=source_identity(args.run);c=declaration()
    require(sha(core)==c["core_sha256"] and sha(baseline)==c["baseline_core_sha256"],"Residual prospective core bindings")
    evidence=ROOT.parent/"SporeSpore_Evidence"
    require(shutil.disk_usage(evidence).free>=2*2**30,"Residual retained-capture storage bound")
    folder=evidence/("sdk2-residual-native-"+uuid.uuid4().hex);folder.mkdir()
    print(str(folder),flush=True)
    status=subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()
    receipt=dict(schema_version="locolemotion_residual_native_owner_v1",ledger_scope=c["ledger_scope"],
        source_commit=source,contract=c,synthetic=False,ok=False,physical_launch_requested=False,physical_started=False,
        planned_worlds=dict(cpu=3,gpu=0),planned_trials=trial_plan(c),
        training_data_scope=None,**{k:False for k in FLAGS})
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE)
    release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;started=time.monotonic()
    try:
        require(jobs.wait(handle,0) in (0,128),"Another native operation owns the mutex")
        owned=True;receipt["binding"]=bindings(core,baseline);receipt["source_status"]=status
        snapshots=folder/"source";snapshots.mkdir()
        for path in [HERE/name for name in SOURCES]+[CONTRACT]:
            with (snapshots/path.name).open("xb") as f:f.write(path.read_bytes())
            require(sha(snapshots/path.name)==receipt["binding"]["source"][path.relative_to(ROOT).as_posix()],"Residual snapshot identity")
        write_new(folder/"declaration.json",receipt)
        env=dict(PYTHONPATH=";".join(str(ROOT/path) for path in ("sdk","sdk/python","sdk/discovery","sdk/explorer")),
            QUADRUPED_TEST_CORE=str(baseline),PORTABLE_BATCH_BASELINE_CORE=str(baseline),
            SPORESPORE_LOCOMOTION_LIBRARY=str(baseline))
        batch_env=dict(env,QUADRUPED_TEST_CORE=str(core),SPORESPORE_LOCOMOTION_LIBRARY=str(core))
        receipt["safety_controls"]={}
        for index,(name,module,count) in enumerate(GATES):
            artifacts=folder/(name+"-artifacts");artifacts.mkdir()
            stage_env=dict(env if index<3 else batch_env,EXPLORER_TEST_OUTPUT=str(artifacts))
            print(json.dumps(dict(stage=name,controls=count)),flush=True)
            invoke([sys.executable,"-B","-m","unittest","-v",module],folder/(name+"-gate"),900,stage_env)
            verify_tests(folder/(name+"-gate"),count);receipt["safety_controls"][name]=count
        invoke([sys.executable,"-B","-m","unittest","-v","adaptation_provider.test_conformance"],
            folder/"provider-gate",120,batch_env)
        verify_tests(folder/"provider-gate",2);receipt["safety_controls"]["provider"]=2
        invoke([sys.executable,"-B","-m","unittest",
            "test_showcase.Construction.test_real_job_owner_reaps_leaf_and_descendant"],folder/"containment-gate",90,
            dict(env,EXPLORER_TEST_OUTPUT=str(folder)))
        verify_tests(folder/"containment-gate",1);receipt["safety_controls"]["containment"]=1
        runtime=["--core",str(core),"--baseline-core",str(baseline)]
        invoke([sys.executable,"-B",str(HERE/"residual_native.py"),"--check-only",*runtime],folder/"runtime-gate",120,batch_env)
        receipt["preflight"]=json.loads((folder/"runtime-gate/stdout.log").read_text(encoding="utf-8"))
        require(sum(receipt["safety_controls"].values())==EXPECTED_CONTROLS
            and receipt["preflight"]["ok"] is True and receipt["preflight"]["world_build_count"]==0
            and receipt["preflight"]["solver_steps"]==0,"Residual full zero-world gate")
        require(bindings(core,baseline)==receipt["binding"] and source_identity(args.run)==source
            and subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()==status,"Residual prelaunch source/runtime drift")
        receipt["zero_world_gate_passed"]=True
        write_new(folder/"gate-receipt.json",dict(ok=True,source_commit=source,safety_controls=receipt["safety_controls"],
            preflight=receipt["preflight"],declaration_sha256=sha(folder/"declaration.json")))
        if args.run:
            write_new(folder/"consumed.json",dict(attempt_id=folder.name,source_commit=source,
                contract_sha256=sha(CONTRACT),declaration_sha256=sha(folder/"declaration.json"),
                gate_receipt_sha256=sha(folder/"gate-receipt.json"),trials=trial_plan(c)))
            physical=folder/"physical";receipt["physical_launch_requested"]=True
            invoke([sys.executable,"-B",str(HERE/"residual_native.py"),*runtime,"--output",str(physical),
                "--permit",str(physical/"contained.permit")],physical,c["maximum_worker_wall_seconds"],batch_env)
            invoke([sys.executable,"-B",str(HERE/"audit_residual_native.py"),*runtime,"--folder",str(physical),
                "--output",str(folder/"independent-audit.json")],folder/"independent-reader",c["maximum_reader_wall_seconds"],batch_env)
            audit=json.loads((folder/"independent-audit.json").read_text(encoding="utf-8"))
            require(audit["ok"] is True and audit["synthetic"] is False and audit["native_route_verified"] is True
                and audit["constructed_cpu_worlds"]==3 and audit["controller_rows"]==360 and audit["internal_rows"]==1800
                and audit["reader_world_build_count"]==audit["reader_solver_steps"]==0
                and all(audit[k] is False for k in FLAGS),"Residual complete native route audit")
            receipt["audit_sha256"]=sha(folder/"independent-audit.json")
        require(bindings(core,baseline)==receipt["binding"] and source_identity(args.run)==source
            and subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()==status,"Residual execution source/runtime drift")
        receipt.update(ok=True,source_runtime_unchanged=True)
    except BaseException as exc:receipt["error"]=f"{type(exc).__name__}: {exc}"
    finally:
        capture_worker_state(receipt,folder)
        if owned:release(handle)
        jobs.close(handle)
        receipt["wall_s"]=time.monotonic()-started;write_new(folder/"receipt.json",receipt)
    print(json.dumps(dict(ok=receipt["ok"],output=str(folder),physical_started=receipt["physical_started"],
        constructed_cpu_worlds=receipt.get("constructed_cpu_worlds"),error=receipt.get("error"))),flush=True)
    return 0 if receipt["ok"] else 1


if __name__=="__main__":raise SystemExit(main())
