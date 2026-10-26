"""Retain a zero-physics shutdown diagnostic and the original failed native gate."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
from pathlib import Path
import subprocess
import sys
import time
import uuid
from contained_stage_owner_v2 import OwnedChild,jobs,SCOPE
from run_gpu_measurement_probe import source_identity
from run_contact_sequence_native_v1 import bindings as parent_bindings,inventory
from contact_sequence_native_task_v1 import ROOT,HERE,read,sha,require,GATES,CONTRACT
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from gpu_measurement_probe import write_new
from run_residual_native import verify_tests

SOURCES=("contained_stage_owner_v2.py","test_contained_stage_owner_v2.py","run_contained_stage_diagnostic_v2.py")
FAILED="sdk2-contact-sequence-native-v1-111482303b2140a2a51f85ca79e708f8"
FAILED_SHA="7676172756c0b0587ca9ba09cb507952f664330d831d605c20760a187c5ffef0"
CONTROLS=(("lifecycle","test_contained_stage_owner_v2",17),("selection-rehearsal","test_predictive_command_selection_v2",25))


def verify_failed_parent():
    folder=ROOT.parent/"SporeSpore_Evidence"/FAILED
    r=read(folder/"receipt.json");d=read(folder/"declaration.json")
    require(sha(folder/"receipt.json")==FAILED_SHA,"Original failed receipt identity")
    prefix=[]
    for g in GATES:
        if g[0]=="prediction-selection":break
        prefix.append(g)
    require(sum(g[2] for g in prefix)==1091 and r["safety_controls"]=={n:k for n,_,k in prefix}
        and list(r["safety_controls"])==[n for n,_,_ in prefix],"Failed gate exact accepted prefix")
    require(r["ok"] is False and r["component_only"] is False and r["source_status"]==[]
        and r["source_commit"]==d["source_commit"]=="af21b17f8ae70f723121f7e7b7f953b6f64ea4a2"
        and r["physical_started"] is False and r["physical_launch_requested"] is False
        and r["constructed_cpu_worlds"]==r["constructed_gpu_worlds"]==0
        and r["error"]=="RuntimeError: Contained descendant did not exit",
        "Original zero-world containment failure")
    require(r["contract"]==d["contract"]==read(CONTRACT),"Original contract identity")
    require(all(not (folder/x).exists() for x in ("physical","consumed.json","gate-receipt.json")),"Failed attempt opened physical route")
    for key in ("physical_acceptance_authority","release_authority","equivalence_authority","training_data_authority"):
        require(r[key] is False,"Failed gate authority")
    verify_population(r["artifacts"],inventory(folder));validate_bindings(d["binding"])
    for name,_,count in prefix:verify_tests(folder/(name+"-gate"),count)
    verify_tests(folder/"prediction-selection-gate",25)
    return dict(attempt_id=FAILED,receipt_sha256=FAILED_SHA,declaration_sha256=sha(folder/"declaration.json"),
        contract_sha256=sha(CONTRACT),source_commit=r["source_commit"],accepted_controls=1091,
        completed_modules=len(prefix),failed_stage="prediction-selection",stage_tests_passed=25,
        stage_stderr_sha256=sha(folder/"prediction-selection-gate/stderr.log"),
        error=r["error"],owner_wall_s=r["wall_s"],artifacts_including_receipt=len(r["artifacts"])+1,
        physical_launch_requested=False,constructed_cpu_worlds=0,constructed_gpu_worlds=0,
        original_incident_cause_established=False,original_member_identities_retained=False,
        source_runtime_verified_at_diagnostic=True,physical_acceptance_authority=False,release_authority=False)


def bindings(core,baseline):
    value=parent_bindings(core,baseline)
    for name in SOURCES:value["source"]["sdk/discovery/"+name]=sha(HERE/name)
    return value


def invoke(command,folder,env):
    folder.mkdir();child=OwnedChild(command,ROOT,env,folder);began=time.monotonic()
    try:
        while child.process.poll() is None:
            require(time.monotonic()-began<=180,"Lifecycle stage exceeded prospective bound")
            time.sleep(.05)
        require(child.process.returncode==0,"Lifecycle stage failed")
    finally:child.close()
    require(read(folder/"cleanup.json")["ok"] is True,"Lifecycle cleanup unverified")


def cleanup_population(folder):
    values=[]
    for path in sorted(folder.rglob("cleanup.json")):
        r=read(path);parent=path.parent.name
        negative=parent.startswith(("uncertain-exit-","membership-error-"))
        require(r["ok"] is (not negative) and r["cleanup_seconds"]==10.
            and r["stable_handles"] is True and r["exact_job_membership"] is True
            and r["pid_reopened_after_job_close"] is False
            and r["physical_acceptance_authority"] is False and r["release_authority"] is False,"Exact lifecycle fixture outcome")
        if not negative:
            require(all(x.get("final_wait")==0 for x in r["members"] if x["member"] is True),"Unsignaled retained member")
        values.append(dict(path=path.relative_to(folder).as_posix(),sha256=sha(path),ok=r["ok"],
            member_handles=sum(x["member"] is True for x in r["members"]),
            outside_owned_job=sum(x["member"] is False for x in r["members"])))
    require(len(values)==16 and sum(not x["ok"] for x in values)==2,"Complete lifecycle fixture population")
    require(any(x["member_handles"]>=3 and "/three-processes-" in x["path"] for x in values),"Missing real descendant reaping")
    return values


def main():
    p=argparse.ArgumentParser();p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    args=p.parse_args();core=args.core.resolve(strict=True);baseline=args.baseline_core.resolve(strict=True)
    source=source_identity(False);evidence=ROOT.parent/"SporeSpore_Evidence"
    folder=evidence/("sdk2-contained-stage-diagnostic-v2-"+uuid.uuid4().hex);folder.mkdir();print(str(folder),flush=True)
    status=subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()
    r=dict(schema_version="locolemotion_contained_stage_diagnostic_v2",ledger_scope=SCOPE,source_commit=source,
        ok=False,controls_planned=42,controls_passed=0,worlds_opened=0,solver_steps=0,physical_started=False,
        physical_acceptance_authority=False,training_data_authority=False,release_authority=False,
        tier2_qualified=False,tier3_benefit_established=False,maximum_stage_wall_seconds=180,
        cleanup_seconds=10.,original_incident_cause_established=False)
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;began=time.monotonic()
    try:
        require(jobs.wait(handle,0) in (0,128),"Another operation owns the mutex");owned=True
        before=bindings(core,baseline);r["failed_parent"]=verify_failed_parent()
        snapshot=folder/"source";snapshot.mkdir()
        for name in SOURCES:
            with (snapshot/name).open("xb") as stream:stream.write((HERE/name).read_bytes())
            require(sha(snapshot/name)==before["source"]["sdk/discovery/"+name],"Lifecycle source snapshot")
        write_new(folder/"declaration.json",dict(r,binding=before,source_status=status,
            controls=[dict(name=n,module=m,count=k) for n,m,k in CONTROLS],
            real_process_scope="one normal leaf/worker, one leaf/worker/grandchild, eight short-lived leaf/workers; no physics",
            synthetic_negative_scope="stale outside-job PID, lookup/query/wait failures, timeout and missing witnesses"))
        env=dict(PYTHONPATH=";".join(str(ROOT/x) for x in ("sdk","sdk/python","sdk/discovery","sdk/explorer")),
            PYTHONDONTWRITEBYTECODE="1",PYTHONIOENCODING="utf-8",OPENBLAS_NUM_THREADS="1",
            OMP_NUM_THREADS="1",MKL_NUM_THREADS="1",QUADRUPED_TEST_CORE=str(core),PORTABLE_BATCH_BASELINE_CORE=str(baseline),
            SPORESPORE_LOCOMOTION_LIBRARY=str(core))
        for name,module,count in CONTROLS:
            artifacts=folder/(name+"-artifacts");artifacts.mkdir();print(json.dumps(dict(stage=name,controls=count)),flush=True)
            invoke([sys.executable,"-B","-m","unittest","-v",module],folder/(name+"-controls"),
                dict(env,EXPLORER_TEST_OUTPUT=str(artifacts)))
            verify_tests(folder/(name+"-controls"),count);r["controls_passed"]+=count
        r["cleanup_population"]=cleanup_population(folder)
        require(bindings(core,baseline)==before and source_identity(False)==source
            and subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).splitlines()==status,
            "Lifecycle source/runtime drift")
        r.update(ok=True,source_runtime_unchanged=True)
    except BaseException as exc:r["error"]=type(exc).__name__+": "+str(exc)
    finally:
        r["wall_s"]=time.monotonic()-began
        try:r["artifacts"]=inventory(folder);write_new(folder/"receipt.json",r)
        finally:
            if owned:release(handle)
            jobs.close(handle)
    print(json.dumps(dict(ok=r["ok"],output=str(folder),controls=r["controls_passed"],error=r.get("error"))),flush=True)
    return 0 if r["ok"] else 1


if __name__=="__main__":raise SystemExit(main())
