"""One mutex owner: complete gate, canary comparison, then frozen population."""
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

from population_discovery_task_v1 import ROOT, HERE, CONTRACT, PARENT, SOURCES, FLAGS, GATES, declaration, plans, require, sha
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity
from run_gpu_motor_effectiveness import bindings as inherited_bindings
from run_contact_sequence_native_v2 import invoke, jobs
from run_residual_native import verify_tests

def bindings(core, baseline):
    value = inherited_bindings(core, baseline)
    for path in [CONTRACT, PARENT, *[HERE / name for name in SOURCES]]:
        value["source"][path.relative_to(ROOT).as_posix()] = sha(path)
    return value


def status():
    return subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).splitlines()


def inventory(folder):
    return [dict(path=p.relative_to(folder).as_posix(), bytes=p.stat().st_size, sha256=sha(p))
        for p in sorted(folder.rglob("*")) if p.is_file() and "warp-cache" not in p.parts]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    core, baseline = args.core.resolve(strict=True), args.baseline_core.resolve(strict=True)
    source, c, original_status = source_identity(args.run), declaration(), status()
    evidence = ROOT.parent / "SporeSpore_Evidence"
    require(sha(core) == c["core_sha256"] and sha(baseline) == c["baseline_core_sha256"], "Population runtime freeze")
    require(shutil.disk_usage(evidence).free >= c["challenge"]["minimum_free_storage_bytes"], "Population evidence storage")
    folder = evidence / ("sdk2-population-discovery-v1-" + uuid.uuid4().hex)
    folder.mkdir()
    print(str(folder), flush=True)
    receipt = dict(schema_version="locolemotion_population_discovery_owner_v1", ledger_scope=c["ledger_scope"],
        source_commit=source, source_status=original_status, contract=c, synthetic=False, ok=False,
        physical_launch_requested=False, physical_started=False, planned_worlds=dict(canaries=16, population=256, cpu=0),
        safety_controls={}, completed_phases=[], **{key: False for key in FLAGS})
    create = jobs.api("CreateMutexW", [C.c_void_p, W.BOOL, W.LPCWSTR], W.HANDLE)
    release = jobs.api("ReleaseMutex", [W.HANDLE])
    handle = jobs.checked(create(None, False, r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    acquired, started = False, time.monotonic()
    try:
        require(jobs.wait(handle, 0) in (0, 128), "Another physical operation owns the mutex")
        acquired = True
        receipt["binding"] = bindings(core, baseline)
        for path in [CONTRACT, *[HERE / name for name in SOURCES]]:
            target = folder / "source" / path.relative_to(ROOT)
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as stream:
                stream.write(path.read_bytes())
        write_new(folder / "declaration.json", receipt)
        env = dict(PYTHONPATH=";".join(str(ROOT / p) for p in ("sdk", "sdk/python", "sdk/discovery", "sdk/explorer")),
            QUADRUPED_TEST_CORE=str(baseline), PORTABLE_BATCH_BASELINE_CORE=str(baseline),
            SPORESPORE_LOCOMOTION_LIBRARY=str(baseline), PYTHONIOENCODING="utf-8",
            OPENBLAS_NUM_THREADS="1", OMP_NUM_THREADS="1", MKL_NUM_THREADS="1")
        batch_env = dict(env, QUADRUPED_TEST_CORE=str(core), SPORESPORE_LOCOMOTION_LIBRARY=str(core))
        for index, (name, module, count) in enumerate(GATES):
            artifacts = folder / (name + "-artifacts")
            artifacts.mkdir()
            target = folder / (name + "-gate")
            print(json.dumps(dict(stage=name, controls=count)), flush=True)
            invoke([sys.executable, "-B", "-m", "unittest", "-v", module], target, 900,
                dict(env if index < 3 else batch_env, EXPLORER_TEST_OUTPUT=str(artifacts)))
            verify_tests(target, count)
            receipt["safety_controls"][name] = count
        runtime = ["--core", str(core), "--baseline-core", str(baseline)]
        invoke([sys.executable, "-B", str(HERE / "population_discovery_v1.py"), "--check-only", *runtime],
            folder / "runtime-gate", 240, batch_env)
        preflight = json.loads((folder / "runtime-gate/stdout.log").read_text(encoding="utf-8"))
        require(preflight["ok"] is True and preflight["world_build_count"] == preflight["solver_steps"] == 0
            and sum(receipt["safety_controls"].values()) == sum(r[2] for r in GATES), "Complete population zero-world gate")
        def unchanged():
            require(bindings(core, baseline) == receipt["binding"] and source_identity(args.run) == source
                and status() == original_status, "Population source/runtime drift")
        unchanged()
        receipt.update(zero_world_gate_passed=True, preflight=preflight)
        write_new(folder / "gate-receipt.json", dict(ok=True, source_commit=source,
            declaration_sha256=sha(folder / "declaration.json"), safety_controls=receipt["safety_controls"], preflight=preflight))
        if args.run:
            write_new(folder / "consumed.json", dict(attempt_id=folder.name, source_commit=source,
                contract_sha256=sha(CONTRACT), gate_receipt_sha256=sha(folder / "gate-receipt.json"),
                planned_trials={phase: plans(c, phase) for phase in ("canaries", "population")}))
            for phase, audit_name in [("canaries", "canary-audit.json"), ("population", "population-audit.json")]:
                receipt["physical_launch_requested"] = True
                target = folder / phase
                invoke([sys.executable, "-B", str(HERE / "population_discovery_v1.py"), *runtime,
                    "--phase", phase, "--output", str(target), "--permit", str(target / "contained.permit")],
                    target, c["challenge"]["maximum_worker_wall_seconds"], batch_env)
                unchanged()
                invoke([sys.executable, "-B", str(HERE / "audit_population_discovery_v1.py"), *runtime,
                    "--phase", phase, "--folder", str(target), "--output", str(folder / audit_name)],
                    folder / (phase + "-reader"), c["challenge"]["maximum_reader_wall_seconds"], batch_env)
                audit = json.loads((folder / audit_name).read_text(encoding="utf-8"))
                require(audit["ok"] is True, "Population phase reader refused")
                receipt["completed_phases"].append(dict(phase=phase, audit_sha256=sha(folder / audit_name)))
                unchanged()
        receipt.update(ok=True, source_runtime_unchanged=True)
    except BaseException as exc:
        receipt["error"] = f"{type(exc).__name__}: {exc}"
    finally:
        workers = []
        for phase in ("canaries", "population"):
            path = folder / phase / "worker-result.json"
            if path.is_file():
                workers.append(json.loads(path.read_text(encoding="utf-8")))
        receipt["worker_states"] = workers
        receipt["constructed_gpu_worlds_lower_bound"] = sum(
            json.loads(p.read_text(encoding="utf-8"))["native_gpu_worlds"] for p in folder.glob("*/*/*/worlds-opened.json"))
        receipt["physical_started"] = (True if receipt["constructed_gpu_worlds_lower_bound"] else
            False if not receipt["physical_launch_requested"] or len(workers) == len(receipt["completed_phases"]) > 0 else None)
        receipt["wall_s"] = time.monotonic()-started
        try:
            receipt["artifacts"] = inventory(folder)
            write_new(folder / "receipt.json", receipt)
        finally:
            if acquired:
                release(handle)
            jobs.close(handle)
    print(json.dumps(dict(ok=receipt["ok"], output=str(folder), physical_started=receipt["physical_started"],
        constructed_gpu_worlds_lower_bound=receipt["constructed_gpu_worlds_lower_bound"], error=receipt.get("error"))), flush=True)
    return 0 if receipt["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
