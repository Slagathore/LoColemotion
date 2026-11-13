"""Shared contained owner for declared zero-world geometry diagnostics.

Historical owners remain byte-verifiable in their commits. New diagnostics
supply a declaration reader, worker and source inventory to this shared route.
"""
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

import numpy as np
from actuation_recovery_mechanics import require
from creature_righting_geometry import sha, write_new


def main(module):
    parser=argparse.ArgumentParser(description=module.__doc__)
    parser.add_argument("--contract",type=Path,required=True)
    parser.add_argument("--core",type=Path,required=True)
    parser.add_argument("--worker",action="store_true")
    parser.add_argument("--check-only",action="store_true")
    parser.add_argument("--output",type=Path)
    args=parser.parse_args()
    contract=args.contract.resolve(strict=True);core=args.core.resolve(strict=True)
    if args.worker:
        require(args.output is not None and not args.check_only,"Geometry worker arguments")
        result=module.work(contract,core,args.output)
        print(json.dumps({k:result[k] for k in ("ok","body_count","pose_orientation_cases","world_build_count")}))
        return
    require(args.output is None,"Geometry owner chooses fresh identity")
    from run_gpu_measurement_probe import source_identity
    from run_gpu_motor_effectiveness import bindings as inherited_bindings
    from run_contact_sequence_native_v2 import invoke,jobs
    from run_residual_native import verify_tests
    from run_creature_native import inventory
    root=Path(__file__).resolve().parents[2];c=module.declaration(contract)
    require(contract.is_relative_to(root) and sha(core)==c["core_sha256"]
            and np.__version__==c["runtime_numpy"],"Geometry source/runtime identity")
    source=source_identity(False)
    require(shutil.disk_usage(root.parent/"SporeSpore_Evidence").free>=c["minimum_free_storage_bytes"],
            "Geometry durable storage budget")
    status=lambda:subprocess.check_output(["git","status","--porcelain"],cwd=root,text=True).splitlines()
    initial_status=status()
    paths=list(dict.fromkeys([contract,Path(__file__).resolve(),Path(module.__file__).resolve(),
                              *module.source_paths(c)]))
    require(all(p.resolve(strict=True).is_relative_to(root) for p in paths),"Geometry source boundary")
    def bindings():
        result=inherited_bindings(core,core)
        result["source"].update({p.relative_to(root).as_posix():sha(p) for p in paths})
        return result
    folder=root.parent/"SporeSpore_Evidence"/(module.OWNER_PREFIX+uuid.uuid4().hex)
    folder.mkdir();print(str(folder),flush=True)
    receipt=dict(schema_version="locolemotion_geometry_diagnostic_owner_v1",ledger_scope=c["ledger_scope"],
        source_commit=source,source_status=initial_status,contract=c,ok=False,synthetic=True,
        check_only=args.check_only,world_build_count=0,solver_steps=0,physical_started=False,
        trained=False,physical_acceptance_authority=False,training_data_authority=False,release_authority=False)
    create=jobs.api("CreateMutexW",[C.c_void_p,W.BOOL,W.LPCWSTR],W.HANDLE)
    release=jobs.api("ReleaseMutex",[W.HANDLE])
    handle=jobs.checked(create(None,False,r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    acquired=False;started=time.monotonic()
    try:
        require(jobs.wait(handle,0)==0,"Another operation owns the project mutex");acquired=True
        receipt["bindings"]=bindings()
        for path in paths:
            target=folder/"source"/path.relative_to(root);target.parent.mkdir(parents=True,exist_ok=True)
            with target.open("xb") as stream:stream.write(path.read_bytes())
        write_new(folder/"declaration.json",receipt)
        env=dict(PYTHONPATH=";".join(str(root/p) for p in
            ("sdk/discovery","sdk/conformance","sdk/explorer","sdk/python","sdk/adapters/mujoco","sdk")),
            QUADRUPED_TEST_CORE=str(core),PYTHONIOENCODING="utf-8",
            OPENBLAS_NUM_THREADS="1",OMP_NUM_THREADS="1",MKL_NUM_THREADS="1")
        tests=folder/"test-artifacts";tests.mkdir()
        invoke([sys.executable,"-B","-m","unittest","-v",*module.TEST_MODULES],
               folder/"controls",c["maximum_control_wall_seconds"],dict(env,EXPLORER_TEST_OUTPUT=str(tests)))
        verify_tests(folder/"controls",c["controls_required"])
        receipt["controls_passed"]=c["controls_required"]
        def unchanged():
            require(source_identity(False)==source and status()==initial_status and bindings()==receipt["bindings"],
                    "Geometry source/runtime drift")
        unchanged()
        if not args.check_only:
            invoke([sys.executable,"-B",str(Path(module.__file__).resolve()),"--worker",
                "--contract",str(contract),"--core",str(core),"--output",str(folder/"computation")],
                folder/"worker",c["maximum_worker_wall_seconds"],env)
            result=json.loads((folder/"computation/result.json").read_bytes())
            require(result["ok"] is True and result["world_build_count"]==result["solver_steps"]==0
                    and result["body_count"]==c["body_count"],"Geometry worker completion")
            receipt.update(result_sha256=sha(folder/"computation/result.json"),
                body_count=result["body_count"],pose_orientation_cases=result["pose_orientation_cases"])
        unchanged()
        receipt.update(ok=True,source_runtime_unchanged=True)
    except BaseException as exc:
        receipt["error"]=type(exc).__name__+": "+str(exc)
    finally:
        if acquired:release(handle)
        jobs.close(handle)
        receipt["wall_s"]=time.monotonic()-started
        receipt["artifacts"]=inventory(folder)
        write_new(folder/"receipt.json",receipt)
    print(json.dumps(dict(ok=receipt["ok"],output=str(folder),error=receipt.get("error"))))
    if not receipt["ok"]:raise SystemExit(1)
