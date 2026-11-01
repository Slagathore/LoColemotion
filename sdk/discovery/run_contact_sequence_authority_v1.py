"""Own the complete retained-only gate and two contained contact-authority readers."""
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

from contact_sequence_authority_task_v1 import (
    CLOSURE, CONTRACT, CONTROLS, EVIDENCE, FLAGS, GATES, HERE, ROOT, SCOPE, SOURCES,
    declaration, inventory, read, require, sha, write_new,
)
from contained_stage_owner_v2 import jobs
from run_contact_sequence_native_v2 import bindings as native_bindings, invoke, validate_cleanup
from run_gpu_measurement_probe import source_identity
from run_residual_native import verify_tests


def bindings(core, baseline):
    value = native_bindings(core, baseline)
    for path in [HERE / name for name in SOURCES] + [CONTRACT, CLOSURE]:
        value["source"][path.relative_to(ROOT).as_posix()] = sha(path)
    return value


def source_status():
    return subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).splitlines()


def validate_status(status):
    allowed = {"sdk/discovery/" + name for name in SOURCES} | {CONTRACT.relative_to(ROOT).as_posix()}
    require(all(line[:2] in ("A ", "M ") and line[3:] in allowed for line in status),
            "Contact authority requires clean or explicitly staged diagnostic source")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    args = parser.parse_args()
    core = args.core.resolve(strict=True); baseline = args.baseline_core.resolve(strict=True)
    source = source_identity(False); status = source_status(); validate_status(status)
    contract = declaration()
    require(shutil.disk_usage(EVIDENCE).free >= contract["minimum_free_storage_bytes"],
            "Contact authority durable storage budget")
    folder = EVIDENCE / ("sdk2-contact-sequence-authority-v1-" + uuid.uuid4().hex)
    folder.mkdir(); print(str(folder), flush=True)
    receipt = dict(
        schema_version="locolemotion_contact_sequence_authority_owner_v1", ledger_scope=SCOPE,
        ok=False, source_commit=source, source_status=status, contract_sha256=sha(CONTRACT),
        controls_planned=CONTROLS, controls_passed=0, new_worlds_opened=0,
        new_forecasts=0, candidate_searches=0, dynamics_solves=0,
        **{name: False for name in FLAGS},
    )
    handle = None; owned = False; started = time.monotonic()
    try:
        create = jobs.api("CreateMutexW", [C.c_void_p, W.BOOL, W.LPCWSTR], W.HANDLE)
        release = jobs.api("ReleaseMutex", [W.HANDLE])
        handle = jobs.checked(create(None, False, r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
        require(jobs.wait(handle, 0) in (0, 128), "Another operation owns the mutex")
        owned = True
        before = bindings(core, baseline)
        for path in [HERE / name for name in SOURCES] + [CONTRACT, CLOSURE]:
            target = folder / "source" / path.relative_to(ROOT)
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as stream:
                stream.write(path.read_bytes())
            require(sha(target) == before["source"][path.relative_to(ROOT).as_posix()],
                    "Contact authority complete source snapshot")
        write_new(folder / "declaration.json", dict(receipt, contract=contract, binding=before))
        env = dict(
            PYTHONPATH=";".join(str(ROOT / path) for path in ("sdk", "sdk/python", "sdk/discovery", "sdk/explorer")),
            OPENBLAS_NUM_THREADS="1", OMP_NUM_THREADS="1", MKL_NUM_THREADS="1", PYTHONIOENCODING="utf-8",
            QUADRUPED_TEST_CORE=str(core), PORTABLE_BATCH_BASELINE_CORE=str(baseline),
        )
        for name, module, count in GATES:
            artifacts = folder / (name + "-artifacts"); artifacts.mkdir()
            print(json.dumps(dict(stage=name, controls=count)), flush=True)
            invoke([sys.executable, "-B", "-m", "unittest", "-v", module],
                   folder / (name + "-gate"), contract["maximum_control_wall_seconds"],
                   dict(env, EXPLORER_TEST_OUTPUT=str(artifacts)))
            verify_tests(folder / (name + "-gate"), count)
            receipt["controls_passed"] += count
        require(receipt["controls_passed"] == CONTROLS, "Contact authority full applicable gate")
        for name in ("audit", "reconstruction"):
            print(json.dumps(dict(stage=name)), flush=True)
            invoke([sys.executable, "-B", str(HERE / "audit_contact_sequence_authority_v1.py"),
                    "--output", str(folder / (name + ".json"))],
                   folder / (name + "-reader"), contract["maximum_reader_wall_seconds"], env)
            require(read(folder / (name + ".json"))["ok"] is True,
                    "Contact authority complete independent reader")
        require((folder / "audit.json").read_bytes() == (folder / "reconstruction.json").read_bytes(),
                "Contact authority byte-identical complete reader results")
        require(bindings(core, baseline) == before and declaration() == contract
                and source_identity(False) == source and source_status() == status,
                "Contact authority source/runtime changed during retained diagnosis")
        cleanup = []
        for name in [name + "-gate" for name, _, _ in GATES] + ["audit-reader", "reconstruction-reader"]:
            path = folder / name / "cleanup.json"; validate_cleanup(read(path))
            cleanup.append(dict(path=path.relative_to(folder).as_posix(), sha256=sha(path)))
        receipt.update(ok=True, source_runtime_unchanged=True,
                       declaration_sha256=sha(folder / "declaration.json"),
                       audit_sha256=sha(folder / "audit.json"),
                       reconstruction_sha256=sha(folder / "reconstruction.json"),
                       source_binding_count=len(before["source"]),
                       runtime_binding_count=len(before["runtime"]), outer_cleanup=cleanup)
    except BaseException as exc:
        receipt["error"] = f"{type(exc).__name__}: {exc}"
    finally:
        receipt["wall_s"] = time.monotonic() - started
        try:
            receipt["artifacts"] = inventory(folder)
            write_new(folder / "receipt.json", receipt)
        finally:
            if owned:
                release(handle)
            if handle:
                jobs.close(handle)
    print(json.dumps(dict(ok=receipt["ok"], output=str(folder), error=receipt.get("error"))), flush=True)
    return 0 if receipt["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
