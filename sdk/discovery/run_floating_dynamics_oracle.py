"""Single mutex/job owner for the prospective zero-integration native oracle."""
import argparse,ctypes as C,json,shutil,subprocess,sys,time,uuid
from ctypes import wintypes as W
from pathlib import Path
from floating_dynamics_oracle_task import ROOT,HERE,EVIDENCE,CONTRACT,RESULT,SOURCES,GATES,CONTROL_COUNT,FLAGS,declaration,read,sha,require
from run_floating_base_dynamics import bindings as parent_bindings,inventory
from run_gpu_measurement_probe import source_identity,invoke,jobs
from run_residual_native import verify_tests
from gpu_measurement_probe import write_new


def bindings(core,baseline):
    value=parent_bindings(core,baseline)
    for path in (CONTRACT,RESULT):value["source"][path.relative_to(ROOT).as_posix()]=sha(path)
    return value


def capture(receipt,folder):
    if not receipt["native_launch_requested"]:
        receipt.update(constructed_models=0,constructed_cpu_worlds=0,constructed_gpu_worlds=0,solver_steps=0,physical_started=False)
        return
    try:
        worker=read(folder/"native/worker-result.json")
        for key in ("constructed_models","constructed_cpu_worlds","constructed_gpu_worlds","solver_steps"):
            receipt[key]=worker[key]
        receipt["physical_started"]=worker["constructed_cpu_worlds"]>0
    except (OSError,ValueError,KeyError,TypeError) as exc:
        receipt.update(constructed_model_lower_bound=len(list((folder/"native").glob("*/model-built.json"))),
            constructed_cpu_world_lower_bound=len(list((folder/"native").glob("*/world-opened.json"))),
            physical_started=None,worker_result_error=f"{type(exc).__name__}: {exc}")


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--run",action="store_true");args=p.parse_args()
    core=args.core.resolve(strict=True);baseline=args.baseline_core.resolve(strict=True)
    source=source_identity(args.run);c=declaration()
    require(shutil.disk_usage(EVIDENCE).free>=c["minimum_free_storage_bytes"],"Oracle retained storage")
    folder=EVIDENCE/("sdk2-floating-dynamics-oracle-"+uuid.uuid4().hex);folder.mkdir();print(str(folder),flush=True)
    receipt=dict(schema_version="locolemotion_floating_dynamics_oracle_owner_v1",ok=False,ledger_scope=c["ledger_scope"],
        contract=c,source_commit=source,source_status=subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines(),
        native_launch_requested=False,synthetic=False,**{k:False for k in FLAGS})
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;started=time.monotonic()
    try:
        require(jobs.wait(handle,0) in (0,128),"Another operation owns the mutex");owned=True
        before=bindings(core,baseline);receipt["binding"]=before
        snapshot=folder/"source";snapshot.mkdir()
        for path in [HERE/n for n in SOURCES]+[CONTRACT,RESULT]:
            with (snapshot/path.name).open("xb") as stream:stream.write(path.read_bytes())
            require(sha(snapshot/path.name)==before["source"][path.relative_to(ROOT).as_posix()],"Oracle source snapshot")
        write_new(folder/"declaration.json",receipt)
        env=dict(PYTHONPATH=";".join(str(ROOT/p) for p in ("sdk","sdk/python","sdk/discovery","sdk/explorer")),
            OPENBLAS_NUM_THREADS="1",OMP_NUM_THREADS="1",MKL_NUM_THREADS="1",PYTHONIOENCODING="utf-8",QUADRUPED_TEST_CORE=str(core))
        receipt["safety_controls"]={}
        for name,module,count in GATES:
            invoke([sys.executable,"-B","-m","unittest","-v",module],folder/(name+"-controls"),180,env)
            verify_tests(folder/(name+"-controls"),count);receipt["safety_controls"][name]=count
        invoke([sys.executable,"-B","-m","unittest","test_showcase.Construction.test_real_job_owner_reaps_leaf_and_descendant"],
            folder/"containment-controls",90,dict(env,EXPLORER_TEST_OUTPUT=str(folder)))
        verify_tests(folder/"containment-controls",1);receipt["safety_controls"]["containment"]=1
        invoke([sys.executable,"-B",str(HERE/"floating_dynamics_oracle.py"),"--check-only"],folder/"runtime-gate",180,env)
        receipt["preflight"]=read(folder/"runtime-gate/stdout.log")
        require(sum(receipt["safety_controls"].values())==CONTROL_COUNT and receipt["preflight"]==
            dict(ok=True,component_evidence_verified=True,states=132,world_build_count=0,solver_steps=0),"Oracle complete gate")
        def unchanged():
            require(bindings(core,baseline)==before and source_identity(args.run)==source
                and subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()==receipt["source_status"],
                "Oracle source/runtime drift")
        unchanged()
        write_new(folder/"gate-receipt.json",dict(ok=True,source_commit=source,declaration_sha256=sha(folder/"declaration.json"),
            safety_controls=receipt["safety_controls"],preflight=receipt["preflight"]))
        receipt["zero_world_gate_passed"]=True
        if args.run:
            write_new(folder/"consumed.json",dict(attempt_id=folder.name,source_commit=source,contract_sha256=sha(CONTRACT),
                declaration_sha256=sha(folder/"declaration.json"),gate_receipt_sha256=sha(folder/"gate-receipt.json"),trials=c["trials"]))
            native=folder/"native";receipt["native_launch_requested"]=True
            invoke([sys.executable,"-B",str(HERE/"floating_dynamics_oracle.py"),"--core",str(core),"--baseline-core",str(baseline),
                "--output",str(native),"--permit",str(native/"contained.permit")],native,c["maximum_worker_wall_seconds"],env)
            unchanged()
            for name in ("audit","reconstruction"):
                invoke([sys.executable,"-B",str(HERE/"audit_floating_dynamics_oracle.py"),"--folder",str(native),
                    "--output",str(folder/(name+".json"))],folder/(name+"-reader"),c["maximum_reader_wall_seconds"],env)
                require(read(folder/(name+".json"))["ok"] is True,"Oracle complete comparison")
            require(read(folder/"audit.json")==read(folder/"reconstruction.json"),"Oracle independent reconstruction")
            receipt.update(audit_sha256=sha(folder/"audit.json"),reconstruction_sha256=sha(folder/"reconstruction.json"))
        unchanged();receipt.update(ok=True,source_runtime_unchanged=True,
            source_binding_count=len(before["source"]),runtime_binding_count=len(before["runtime"]))
    except BaseException as exc:receipt["error"]=f"{type(exc).__name__}: {exc}"
    finally:
        capture(receipt,folder);receipt["wall_s"]=time.monotonic()-started
        try:receipt["artifacts"]=inventory(folder);write_new(folder/"receipt.json",receipt)
        finally:
            if owned:release(handle)
            jobs.close(handle)
    print(json.dumps(dict(ok=receipt["ok"],output=str(folder),constructed_cpu_worlds=receipt.get("constructed_cpu_worlds"),
        solver_steps=receipt.get("solver_steps"),error=receipt.get("error"))),flush=True)
    return 0 if receipt["ok"] else 1
if __name__=="__main__":raise SystemExit(main())
