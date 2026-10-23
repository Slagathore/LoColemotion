"""Complete safety gate and fresh native CPU body-attitude/rate factorial discovery."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
from pathlib import Path
import shutil
import sys
import time
import uuid

from cpu_body_gain_task import ROOT, HERE, CONTRACT, FLAGS, declaration, trial_plan, sha
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity, invoke, jobs
from run_cpu_posture_discovery import bindings as parent_bindings, GATES as PARENT_GATES


GATES = PARENT_GATES + [("body-gain-feedback", "test_body_gain_feedback.py", 8), ("cpu-body-gain", "test_cpu_body_gain_discovery.py", 10)]


def bindings(core, baseline):
    value = parent_bindings(core, baseline)
    for path in [CONTRACT, HERE/"cpu_posture_discovery_closure_v1.json",
        ROOT/"sdk/adaptation_provider/body_gain_feedback_v1.py", ROOT/"sdk/adaptation_provider/body_gain_feedback_v1.json"]:
        value["source"][path.relative_to(ROOT).as_posix()] = sha(path)
    return value


def verify_tests(folder, expected):
    log = (folder/"stderr.log").read_text()
    if f"Ran {expected} tests in " not in log or not log.rstrip().endswith("OK"):
        raise ValueError("Incomplete declared safety controls: "+folder.name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    core, baseline = args.core.resolve(strict=True), args.baseline_core.resolve(strict=True)
    source, c = source_identity(args.run), declaration()
    if sha(core) != c["core_sha256"] or sha(baseline) != c["baseline_core_sha256"]:
        raise ValueError("Prospective core binding")
    evidence = ROOT.parent/"SporeSpore_Evidence"
    if args.run and shutil.disk_usage(evidence).free < 30*2**30:
        raise ValueError("Full-capture campaign requires at least 30 GiB free in durable evidence storage")
    folder = evidence/("sdk2-cpu-body-gain-discovery-"+uuid.uuid4().hex)
    folder.mkdir()
    print(str(folder), flush=True)
    receipt = dict(schema_version="locolemotion_cpu_body_gain_discovery_receipt_v1", ledger_scope=c["ledger_scope"],
        source_commit=source, contract=c, synthetic=False, ok=False, physical_started=False,
        planned_worlds=dict(gpu=0, cpu=10), planned_trials=trial_plan(c), training_data_scope="development_discovery_only",
        **{k: c[k] for k in FLAGS})
    create = jobs.api("CreateMutexW", [C.c_void_p, W.BOOL, W.LPCWSTR], W.HANDLE)
    release = jobs.api("ReleaseMutex", [W.HANDLE])
    handle = jobs.checked(create(None, False, "Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    acquired = False
    try:
        if jobs.wait(handle, 0) not in (0, 128):
            raise RuntimeError("Another physical operation owns the mutex")
        acquired = True
        receipt["binding"] = bindings(core, baseline)
        write_new(folder/"declaration.json", receipt)
        env = dict(EXPLORER_TEST_OUTPUT=str(folder), QUADRUPED_TEST_CORE=str(baseline),
            PORTABLE_BATCH_BASELINE_CORE=str(baseline), SPORESPORE_LOCOMOTION_LIBRARY=str(baseline),
            PYTHONPATH=str(ROOT/"sdk")+";"+str(ROOT/"sdk/python"))
        batch_env = dict(env, QUADRUPED_TEST_CORE=str(core), SPORESPORE_LOCOMOTION_LIBRARY=str(core))
        receipt["safety_controls"] = {}
        for index, (name, filename, count) in enumerate(GATES):
            target = folder/(name+"-gate")
            invoke([sys.executable, "-B", "-m", "unittest", "discover", "-s", str(HERE), "-p", filename, "-v"],
                target, 300, env if index < 3 else batch_env)
            verify_tests(target, count)
            receipt["safety_controls"][name] = count
        target = folder/"provider-gate"
        invoke([sys.executable, "-B", "-m", "unittest", "adaptation_provider.test_conformance", "-v"], target, 120, batch_env)
        verify_tests(target, 2); receipt["safety_controls"]["provider"] = 2
        target = folder/"containment-gate"
        invoke([sys.executable, "-B", "-m", "unittest", "test_showcase.Construction.test_real_job_owner_reaps_leaf_and_descendant"],
            target, 90, dict(env, PYTHONPATH=str(ROOT/"sdk/explorer")))
        # unittest uses the singular noun for a one-control population.
        log = (target/"stderr.log").read_text()
        if "Ran 1 test in " not in log or not log.rstrip().endswith("OK"):
            raise ValueError("Containment control incomplete")
        receipt["safety_controls"]["containment"] = 1
        runtime = ["--core", str(core), "--baseline-core", str(baseline)]
        invoke([sys.executable, "-B", str(HERE/"cpu_body_gain_discovery.py"), "--check-only", *runtime], folder/"runtime-gate", 120)
        receipt["preflight"] = json.loads((folder/"runtime-gate/stdout.log").read_text())
        if receipt["preflight"]["ok"] is not True or receipt["preflight"]["world_build_count"] != 0 or sum(receipt["safety_controls"].values()) != 141:
            raise ValueError("Complete zero-world gate refused")
        if bindings(core, baseline) != receipt["binding"] or source_identity(args.run) != source:
            raise ValueError("Qualification source/runtime drift")
        receipt["zero_world_gate_passed"] = True
        if args.run:
            write_new(folder/"consumed.json", dict(attempt_id=folder.name, source_commit=source,
                planned_worlds=receipt["planned_worlds"], planned_trials=trial_plan(c)))
            physical = folder/"physical"
            receipt["physical_started"] = True
            command = [sys.executable, "-B", str(HERE/"cpu_body_gain_discovery.py"), *runtime,
                "--output", str(physical), "--permit", str(physical/"contained.permit")]
            invoke(command, physical, c["maximum_worker_wall_seconds"])
            tick = time.perf_counter()
            invoke([sys.executable, "-B", str(HERE/"audit_cpu_body_gain_discovery.py"), *runtime,
                "--folder", str(physical), "--output", str(folder/"independent-audit.json")],
                folder/"independent-reader", c["challenge"]["maximum_reader_wall_seconds"])
            receipt["audit_wall_s"] = time.perf_counter()-tick
            receipt["audit_sha256"] = sha(folder/"independent-audit.json")
        if bindings(core, baseline) != receipt["binding"] or source_identity(args.run) != source:
            raise ValueError("Execution source/runtime drift")
        receipt["ok"] = True
    except BaseException as exc:
        receipt["error"] = f"{type(exc).__name__}: {exc}"
    finally:
        if acquired:
            release(handle)
        jobs.close(handle)
        write_new(folder/"receipt.json", receipt)
    print(json.dumps(dict(ok=receipt["ok"], output=str(folder), physical_started=receipt["physical_started"], error=receipt.get("error"))), flush=True)
    return 0 if receipt["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
