"""Complete safety gate, bounded discovery, frozen selection and fresh confirmation."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
from pathlib import Path
import shutil
import sys
import time
import uuid

from motor_effectiveness_task import ROOT, HERE, CONTRACT, FLAGS, declaration, trial_plan, select_profiles, sha
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity, invoke, jobs
from run_gpu_repertoire_v2 import bindings as foundation_bindings
from audit_gpu_motor_effectiveness import compare_confirmation


GATES = [
    ("measurement", "test_actuation_measurement.py", 7),
    ("quadruped", "test_gpu_quadruped_probe.py", 10),
    ("portable", "test_portable_search.py", 11),
    ("host-batch", "test_portable_batch.py", 7),
    ("graph-execution", "test_gpu_batch_execution.py", 7),
    ("repertoire", "test_gpu_repertoire_v2.py", 6),
    ("corpus", "test_freeze_retrieval_corpus_v2.py", 3),
    ("retrieval", "test_flat_retrieval.py", 9),
    ("motor-task", "test_motor_effectiveness_task.py", 7),
    ("motor-route", "test_gpu_motor_effectiveness.py", 5),
]


def bindings(core, baseline):
    value = foundation_bindings(core, baseline)
    value["source"][CONTRACT.relative_to(ROOT).as_posix()] = sha(CONTRACT)
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
    folder = evidence/("sdk2-gpu-motor-effectiveness-"+uuid.uuid4().hex)
    folder.mkdir()
    print(str(folder), flush=True)
    receipt = dict(schema_version="locolemotion_gpu_motor_effectiveness_receipt_v1", ledger_scope=c["ledger_scope"],
        source_commit=source, contract=c, synthetic=False, ok=False, physical_started=False,
        planned_worlds=dict(discovery=90, confirmation=30, cpu=0), training_data_scope="development_discovery_only",
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
        invoke([sys.executable, "-B", str(HERE/"gpu_motor_effectiveness.py"), "--check-only", *runtime], folder/"runtime-gate", 120)
        receipt["preflight"] = json.loads((folder/"runtime-gate/stdout.log").read_text())
        if receipt["preflight"]["ok"] is not True or receipt["preflight"]["world_build_count"] != 0 or sum(receipt["safety_controls"].values()) != 75:
            raise ValueError("Complete zero-world gate refused")
        if bindings(core, baseline) != receipt["binding"] or source_identity(args.run) != source:
            raise ValueError("Qualification source/runtime drift")
        receipt["zero_world_gate_passed"] = True
        if args.run:
            write_new(folder/"consumed.json", dict(attempt_id=folder.name, source_commit=source,
                planned_worlds=receipt["planned_worlds"], discovery_trials=trial_plan(c, "discovery"),
                confirmation_profile_selection="prospective_discovery_selector_only"))
            physical = folder/"physical"; physical.mkdir()
            receipt["physical_started"] = True
            selected = None
            for phase in ["discovery", "confirmation"]:
                phase_dir = physical/phase; phase_dir.mkdir()
                for condition in c["conditions"]:
                    cid = condition["condition_id"]
                    directory = phase_dir/cid
                    command = [sys.executable, "-B", str(HERE/"gpu_motor_effectiveness.py"), *runtime,
                        "--phase", phase, "--condition", cid, "--output", str(directory), "--permit", str(directory/"contained.permit")]
                    if phase == "confirmation":
                        command += ["--selection", str(folder/"selection.json")]
                    invoke(command, directory, c["maximum_worker_wall_seconds"])
                target = folder/(phase+"-reader")
                command = [sys.executable, "-B", str(HERE/"audit_gpu_motor_effectiveness.py"), *runtime,
                    "--folder", str(phase_dir), "--phase", phase, "--output", str(folder/(phase+"-audit.json"))]
                if phase == "confirmation":
                    command += ["--selection", str(folder/"selection.json")]
                tick = time.perf_counter()
                invoke(command, target, 2400)
                receipt[phase+"_audit_wall_s"] = time.perf_counter()-tick
                observed = json.loads((folder/(phase+"-audit.json")).read_text())
                receipt[phase+"_audit_sha256"] = sha(folder/(phase+"-audit.json"))
                if phase == "discovery":
                    selected = select_profiles(observed, c)
                    write_new(folder/"selection.json", dict(selection=selected, discovery_audit_sha256=receipt["discovery_audit_sha256"]))
                    receipt["selection_sha256"] = sha(folder/"selection.json")
                else:
                    receipt["comparison"] = compare_confirmation(observed, selected, c)
                    write_new(folder/"comparison.json", receipt["comparison"])
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
