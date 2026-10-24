"""Single-owner gated native training with independent verification between stages."""
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

from residual_training_task import (ROOT,HERE,CONTRACT,SOURCES,FLAGS,GATES,EXPECTED_CONTROLS,
    declaration,all_plans,stages,prepare_stage,write_update,verify_update,read,require,sha,bridge)
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity,invoke,jobs
from run_residual_native import bindings as native_bindings,verify_tests


def bindings(core,baseline):
    value=native_bindings(core,baseline)
    value["source"][CONTRACT.relative_to(ROOT).as_posix()]=sha(CONTRACT)
    for path in [HERE/name for name in SOURCES]:
        require(value["source"][path.relative_to(ROOT).as_posix()]==sha(path),"Residual training source snapshot population")
    return value


def inventory(folder):
    return [dict(path=path.relative_to(folder).as_posix(),sha256=sha(path),byte_length=path.stat().st_size)
        for path in sorted(folder.rglob("*")) if path.is_file() and path!=folder/"receipt.json"]


def validate_route_attempt(folder,source,c,binding):
    require(folder is not None,"Residual pilot requires verified execution fixture")
    folder=folder.resolve(strict=True);evidence=(ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
    require(folder.parent==evidence and folder.name.startswith("sdk2-residual-training-"),"Residual route evidence boundary")
    receipt=read(folder/"receipt.json")
    require(receipt["ok"] is True and receipt["source_commit"]==source and receipt["contract"]==declaration("route")
        and receipt["binding"]==binding and receipt["source_runtime_unchanged"] is True
        and receipt["zero_world_gate_passed"] is True and receipt["physical_started"] is True
        and receipt["constructed_cpu_worlds"]==3 and receipt["constructed_gpu_worlds"]==0
        and receipt["completed_stages"]==stages(declaration("route")),"Residual verified execution fixture required")
    require(receipt["artifacts"]==inventory(folder),"Residual execution fixture artifact integrity")
    require(c["optimizer"]["route_data_may_initialize_pilot"] is False,"Residual fixture cannot initialize pilot")
    return dict(attempt_id=folder.name,receipt_sha256=sha(folder/"receipt.json"),
        use="execution_path_gate_only",training_initialization=False)


def capture_worker_state(receipt,folder):
    requested=receipt["requested_stages"]
    if not requested:
        receipt.update(physical_started=False,constructed_cpu_worlds=0,constructed_gpu_worlds=0)
        return
    total=0;known=True;lower=0;errors=[]
    for stage in requested:
        physical=folder/"stages"/stage/"physical"
        try:
            worker=read(physical/"worker-result.json")
            count=worker["constructed_cpu_worlds"]
            planned=sum(p["stage"]==stage for p in receipt["planned_trials"])
            require(type(count) is int and 0<=count<=planned and worker["constructed_gpu_worlds"]==0,
                "Residual partial training world count")
            total+=count;lower+=count
        except (OSError,ValueError,KeyError,TypeError) as exc:
            known=False;errors.append(dict(stage=stage,error=f"{type(exc).__name__}: {exc}"))
            for marker in physical.glob("*/world-opened.json"):
                try:
                    value=read(marker)
                    if value["native_data_constructed"] is True and value["trial_id"]==marker.parent.name \
                            and value["core_sha256"]==receipt["contract"]["core_sha256"]:lower+=1
                except (OSError,ValueError,KeyError,TypeError):pass
    if known:receipt.update(constructed_cpu_worlds=total,constructed_gpu_worlds=0,physical_started=total>0)
    else:
        receipt.update(constructed_cpu_worlds_lower_bound=lower,physical_started=True if lower else None,
            worker_result_read_errors=errors)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--lane",choices=("route","pilot"),required=True)
    p.add_argument("--run",action="store_true");p.add_argument("--route-attempt",type=Path);args=p.parse_args()
    core=args.core.resolve(strict=True);baseline=args.baseline_core.resolve(strict=True)
    source=source_identity(args.run);c=declaration(args.lane)
    require(sha(core)==c["core_sha256"] and sha(baseline)==c["baseline_core_sha256"],"Residual training core freeze")
    evidence=ROOT.parent/"SporeSpore_Evidence"
    require(shutil.disk_usage(evidence).free>=c["minimum_free_storage_bytes"],"Residual retained full-capture storage bound")
    folder=evidence/("sdk2-residual-training-"+uuid.uuid4().hex);folder.mkdir()
    print(str(folder),flush=True)
    status=subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()
    receipt=dict(schema_version="locolemotion_residual_training_owner_v1",ledger_scope=c["ledger_scope"],
        source_commit=source,contract=c,synthetic=False,ok=False,physical_started=False,physical_launch_requested=False,
        requested_stages=[],completed_stages=[],stage_records=[],planned_trials=all_plans(c),
        planned_worlds=dict(cpu=c["planned_cpu_worlds"],gpu=0),training_data_scope=c["training_data_scope"],
        **{k:k=="training_data_authority" for k in FLAGS})
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;started=time.monotonic()
    try:
        require(jobs.wait(handle,0) in (0,128),"Another native operation owns the mutex")
        owned=True;receipt["binding"]=bindings(core,baseline);receipt["source_status"]=status
        if args.lane=="pilot" and args.run:
            receipt["execution_fixture"]=validate_route_attempt(args.route_attempt,source,c,receipt["binding"])
        snapshots=folder/"source";snapshots.mkdir()
        for path in [HERE/name for name in SOURCES]+[CONTRACT]:
            with (snapshots/path.name).open("xb") as stream:stream.write(path.read_bytes())
            require(sha(snapshots/path.name)==receipt["binding"]["source"][path.relative_to(ROOT).as_posix()],
                "Residual training snapshot identity")
        write_new(folder/"declaration.json",receipt)
        env=dict(PYTHONPATH=";".join(str(ROOT/path) for path in ("sdk","sdk/python","sdk/discovery","sdk/explorer")),
            QUADRUPED_TEST_CORE=str(baseline),PORTABLE_BATCH_BASELINE_CORE=str(baseline),SPORESPORE_LOCOMOTION_LIBRARY=str(baseline))
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
        runtime=["--core",str(core),"--baseline-core",str(baseline),"--lane",args.lane]
        invoke([sys.executable,"-B",str(HERE/"residual_training.py"),"--check-only",*runtime],
            folder/"runtime-gate",120,batch_env)
        receipt["preflight"]=read(folder/"runtime-gate/stdout.log")
        require(sum(receipt["safety_controls"].values())==EXPECTED_CONTROLS
            and receipt["preflight"]["ok"] is True and receipt["preflight"]["world_build_count"]==0
            and receipt["preflight"]["solver_steps"]==0,"Residual training full zero-world gate")
        def unchanged():
            require(bindings(core,baseline)==receipt["binding"] and source_identity(args.run)==source
                and subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()==status,
                "Residual training source/runtime drift")
        unchanged();receipt["zero_world_gate_passed"]=True
        write_new(folder/"gate-receipt.json",dict(ok=True,source_commit=source,safety_controls=receipt["safety_controls"],
            preflight=receipt["preflight"],declaration_sha256=sha(folder/"declaration.json")))
        if args.run:
            write_new(folder/"consumed.json",dict(attempt_id=folder.name,source_commit=source,lane=args.lane,
                contract_sha256=sha(CONTRACT),declaration_sha256=sha(folder/"declaration.json"),
                gate_receipt_sha256=sha(folder/"gate-receipt.json"),trials=all_plans(c)))
            (folder/"stages").mkdir();library=bridge.LocomotionCore(core)
            for stage in stages(c):
                unchanged();directory=folder/"stages"/stage
                prepare_stage(directory,c,library);physical=directory/"physical"
                receipt["requested_stages"].append(stage);receipt["physical_launch_requested"]=True
                print(json.dumps(dict(stage=stage,event="native_stage_launch")),flush=True)
                invoke([sys.executable,"-B",str(HERE/"residual_training.py"),*runtime,"--output",str(physical),
                    "--permit",str(physical/"contained.permit")],physical,c["maximum_worker_wall_seconds"],batch_env)
                unchanged()
                invoke([sys.executable,"-B",str(HERE/"audit_residual_training.py"),*runtime,"--folder",str(physical),
                    "--output",str(directory/"audit.json")],directory/"independent-reader",c["maximum_reader_wall_seconds"],batch_env)
                audit=read(directory/"audit.json")
                require(audit["ok"] is True and audit["synthetic"] is False and audit["stage"]==stage
                    and audit["reader_world_build_count"]==audit["reader_solver_steps"]==0,"Residual training independent stage audit")
                record=dict(stage=stage,stage_claim_sha256=sha(directory/"stage.json"),audit_sha256=sha(directory/"audit.json"),
                    constructed_cpu_worlds=audit["constructed_cpu_worlds"],controller_rows=audit["controller_rows"],internal_rows=audit["internal_rows"])
                if stage!="comparison":
                    write_update(directory,c,library)
                    invoke([sys.executable,"-B",str(HERE/"audit_residual_training.py"),*runtime,"--folder",str(directory),
                        "--verify-update","--output",str(directory/"verified-update.json")],directory/"update-reader",180,batch_env)
                    verified=verify_update(directory,c,library,require_verification=True)
                    record.update(update_sha256=sha(directory/"update.json"),model_sha256=verified["model_sha256"],
                        verified_update_sha256=sha(directory/"verified-update.json"),normalizer_sample_count=verified["normalizer_sample_count"])
                else:receipt["final_comparison"]=audit["final_comparison"]
                receipt["stage_records"].append(record);receipt["completed_stages"].append(stage)
                print(json.dumps(dict(stage=stage,event="complete_and_independently_verified")),flush=True)
            require(sum(row["constructed_cpu_worlds"] for row in receipt["stage_records"])==c["planned_cpu_worlds"],
                "Residual training complete declared world population")
        unchanged();receipt.update(ok=True,source_runtime_unchanged=True)
    except BaseException as exc:receipt["error"]=f"{type(exc).__name__}: {exc}"
    finally:
        capture_worker_state(receipt,folder)
        try:receipt["artifacts"]=inventory(folder)
        except BaseException as exc:receipt.update(ok=False,inventory_error=f"{type(exc).__name__}: {exc}")
        receipt["wall_s"]=time.monotonic()-started
        try:write_new(folder/"receipt.json",receipt)
        finally:
            if owned:release(handle)
            jobs.close(handle)
    print(json.dumps(dict(ok=receipt["ok"],output=str(folder),physical_started=receipt["physical_started"],
        constructed_cpu_worlds=receipt.get("constructed_cpu_worlds"),error=receipt.get("error"))),flush=True)
    return 0 if receipt["ok"] else 1


if __name__=="__main__":raise SystemExit(main())
