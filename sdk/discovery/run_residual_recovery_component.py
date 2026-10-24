"""Contain and retain both-core recovery interface controls without worlds."""
import argparse
import ctypes as C
from ctypes import wintypes as W
from pathlib import Path
import json
import subprocess
import sys
import time
import uuid

from adaptation_provider.warning import recovery_v1 as provider
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity,invoke,jobs
from run_residual_warning import bindings as parent_bindings
from run_residual_training import inventory
from run_residual_native import verify_tests

ROOT=provider.ROOT
HERE=ROOT/"sdk/discovery"
MODEL=HERE/"residual_recovery_model_v1.json"
SOURCES=(HERE/"residual_recovery_control.py",HERE/"test_residual_recovery_provider.py",
    HERE/"run_residual_recovery_component.py",Path(provider.__file__),provider.CONTRACT,MODEL)


def bindings(core,baseline):
    value=parent_bindings(core,baseline)
    for path in SOURCES:value["source"][path.relative_to(ROOT).as_posix()]=provider.warning.sha(path)
    return value


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core",type=Path,required=True);parser.add_argument("--baseline-core",type=Path,required=True)
    args=parser.parse_args();core=args.core.resolve(strict=True);baseline=args.baseline_core.resolve(strict=True)
    source=source_identity(False);provider.definition()
    folder=ROOT.parent/"SporeSpore_Evidence"/("sdk2-residual-recovery-component-"+uuid.uuid4().hex)
    folder.mkdir();print(str(folder),flush=True)
    scope=dict(subsystem="adaptation",engine_scope="core",authority_mode="development_interface_controls",question_class="development")
    receipt=dict(schema_version="locolemotion_residual_recovery_component_controls_v1",ledger_scope=scope,
        source_commit=source,ok=False,worlds_opened=0,solver_steps=0,controls_planned=26,
        replay_groups=2,steps_per_group=160,provider_modes=8,core_images=2,
        planned_recovery_host_decisions=5120,planned_original_actor_decisions=1280,
        retained_input_replay=True,new_physical_outcomes=False,training_data_authority=False,
        physical_acceptance_authority=False,tier2_complete=False,tier3_complete=False,release_authority=False)
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE);release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    owned=False;started=time.monotonic()
    try:
        provider.require(jobs.wait(handle,0) in (0,128),"Another operation owns the mutex");owned=True
        before=bindings(core,baseline)
        status=subprocess.check_output(["git","status","--porcelain","--untracked-files=all"],cwd=ROOT,text=True).splitlines()
        for path in SOURCES:
            target=folder/"source"/path.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True)
            with target.open("xb") as stream:stream.write(path.read_bytes())
            provider.require(provider.warning.sha(target)==before["source"][path.relative_to(ROOT).as_posix()],
                "Recovery component source snapshot")
        write_new(folder/"declaration.json",dict(receipt,binding=before,source_status=status,
            definition_sha256=provider.warning.sha(provider.CONTRACT),model_file_sha256=provider.warning.sha(MODEL)))
        artifacts=folder/"artifacts";artifacts.mkdir()
        env=dict(PYTHONPATH=";".join(str(ROOT/path) for path in ("sdk","sdk/python","sdk/discovery","sdk/explorer")),
            QUADRUPED_TEST_CORE=str(core),PORTABLE_BATCH_BASELINE_CORE=str(baseline),
            SPORESPORE_LOCOMOTION_LIBRARY=str(core),EXPLORER_TEST_OUTPUT=str(artifacts),
            OPENBLAS_NUM_THREADS="1",OMP_NUM_THREADS="1",MKL_NUM_THREADS="1")
        invoke([sys.executable,"-B","-m","unittest","-v","test_residual_recovery_provider"],
            folder/"controls",900,env)
        verify_tests(folder/"controls",26)
        provider.require(bindings(core,baseline)==before and source_identity(False)==source
            and subprocess.check_output(["git","status","--porcelain","--untracked-files=all"],cwd=ROOT,text=True).splitlines()==status,
            "Recovery component source/runtime drift")
        receipt.update(ok=True,controls_passed=26,source_runtime_unchanged=True,
            source_binding_count=len(before["source"]),runtime_binding_count=len(before["runtime"]),
            declaration_sha256=provider.warning.sha(folder/"declaration.json"),
            input_bindings_sha256=provider.warning.sha(artifacts/"recovery-input-bindings.json"),
            stderr_sha256=provider.warning.sha(folder/"controls/stderr.log"))
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
