"""Complete safety gate and bounded native learned-provider influence comparison."""
import argparse
import ctypes as C
from ctypes import wintypes as W
import json
from pathlib import Path
import sys
import time
import uuid

from gpu_contextual_influence import ROOT, HERE, CONTRACT, FLAGS, sha, declaration, trial_plan
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity, invoke, jobs
from run_gpu_retrieval_shadow import bindings as previous_bindings
from retrieval_shadow_control import candidate_path
from audit_gpu_contextual_influence import audit


def bindings(core, baseline):
    value = previous_bindings(core, baseline)
    c = declaration()
    for path in [CONTRACT, ROOT / c["model"]["closure_path"], ROOT / c["prerequisite_shadow"]["path"],
                 ROOT / c["prerequisite_influence"]["path"]]:
        value["source"][path.relative_to(ROOT).as_posix()] = sha(path)
    candidate = candidate_path(c)
    value["candidate_evidence"] = {str(path): sha(path) for path in [candidate, candidate.parent / "fit-receipt.json"]}
    diagnostic = ROOT.parent/"SporeSpore_Evidence"/c["design_diagnostic"]["attempt_id"]/c["design_diagnostic"]["artifact"]
    value["design_diagnostic"] = {str(diagnostic): sha(diagnostic)}
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    core = args.core.resolve(strict=True)
    baseline = args.baseline_core.resolve(strict=True)
    source = source_identity(args.run)
    c = declaration()
    if sha(core) != c["core_sha256"] or sha(baseline) != c["baseline_core_sha256"]:
        raise ValueError("Prospective core runtime binding")
    folder = ROOT.parent / "SporeSpore_Evidence" / ("sdk2-gpu-contextual-influence-" + uuid.uuid4().hex)
    folder.mkdir()
    print(str(folder), flush=True)
    receipt = dict(ledger_scope=c["ledger_scope"], source_commit=source, contract=c, synthetic=False,
        ok=False, physical_started=False, planned_trials=trial_plan(c),
        planned_worlds=dict(gpu=sum(p["nworld"] for p in trial_plan(c)), cpu=0), **{k: c[k] for k in FLAGS})
    create = jobs.api("CreateMutexW", [C.c_void_p, W.BOOL, W.LPCWSTR], W.HANDLE)
    release = jobs.api("ReleaseMutex", [W.HANDLE])
    handle = jobs.checked(create(None, False, "Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    acquired = False
    try:
        if jobs.wait(handle, 0) not in (0, 128):
            raise RuntimeError("Another physical operation owns the mutex")
        acquired = True
        receipt["binding"] = bindings(core, baseline)
        write_new(folder / "declaration.json", receipt)
        env = dict(EXPLORER_TEST_OUTPUT=str(folder), QUADRUPED_TEST_CORE=str(baseline),
            SPORESPORE_LOCOMOTION_LIBRARY=str(baseline), PYTHONPATH=str(ROOT / "sdk") + ";" + str(ROOT / "sdk/python"))
        for name, test in [("measurement-gate", "test_actuation_measurement.py"),
                           ("quadruped-gate", "test_gpu_quadruped_probe.py"),
                           ("portable-gate", "test_portable_search.py")]:
            invoke([sys.executable, "-B", "-m", "unittest", "discover", "-s", str(HERE), "-p", test, "-v"], folder / name, 180, env)
        batch_env = dict(env, QUADRUPED_TEST_CORE=str(core), PORTABLE_BATCH_BASELINE_CORE=str(baseline),
                         SPORESPORE_LOCOMOTION_LIBRARY=str(core))
        for name, test in [("host-batch-gate", "test_portable_batch.py"),
                ("graph-execution-gate", "test_gpu_batch_execution.py"),
                ("fit-closure-gate", "test_gpu_repertoire_fit_closure_v2.py"),
                ("shadow-closure-gate", "test_shadow_closure_v1.py"),
                ("influence-route-gate", "test_gpu_retrieval_influence.py"),
                ("influence-host-gate", "test_retrieval_influence_control.py"),
                ("influence-accounting-gate", "test_retrieval_influence_accounting.py"),
                ("influence-closure-gate", "test_influence_closure_v1.py"),
                ("feedback-diagnostic-gate", "test_episode_feedback_diagnostic.py"),
                ("contextual-component-gate", "test_contextual_retrieval.py"),
                ("contextual-route-gate", "test_gpu_contextual_influence.py"),
                ("contextual-host-gate", "test_contextual_influence_control.py")]:
            invoke([sys.executable, "-B", "-m", "unittest", "discover", "-s", str(HERE), "-p", test, "-v"], folder / name, 180, batch_env)
        invoke([sys.executable, "-B", "-m", "unittest", "discover", "-s", str(HERE), "-p", "test_flat_retrieval.py", "-v"], folder / "retrieval-gate", 180, batch_env)
        invoke([sys.executable, "-B", "-m", "unittest", "adaptation_provider.test_conformance", "-v"], folder / "provider-gate", 90, batch_env)
        invoke([sys.executable, "-B", "-m", "unittest", "test_showcase.Construction.test_real_job_owner_reaps_leaf_and_descendant"],
            folder / "containment-gate", 60, dict(env, PYTHONPATH=str(ROOT / "sdk/explorer")))
        runtime_args = ["--core", str(core), "--baseline-core", str(baseline)]
        invoke([sys.executable, "-B", str(HERE / "gpu_contextual_influence.py"), "--check-only", *runtime_args], folder / "runtime-gate", 90)
        receipt["preflight"] = json.loads((folder / "runtime-gate/stdout.log").read_text())
        if receipt["preflight"]["ok"] is not True or receipt["preflight"]["world_build_count"] != 0:
            raise ValueError("Runtime preflight refused")
        if bindings(core, baseline) != receipt["binding"] or source_identity(args.run) != source:
            raise ValueError("Qualification source/runtime drift")
        receipt["zero_world_gate_passed"] = True
        if args.run:
            write_new(folder / "consumed.json", dict(attempt_id=folder.name, source_commit=source,
                planned_worlds=receipt["planned_worlds"], planned_trials=receipt["planned_trials"]))
            receipt["physical_started"] = True
            physical = folder / "physical"
            invoke([sys.executable, "-B", str(HERE / "gpu_contextual_influence.py"), *runtime_args,
                "--output", str(physical), "--permit", str(physical / "contained.permit")], physical, c["maximum_worker_wall_seconds"])
            tick = time.perf_counter()
            receipt["audit"] = audit(physical, core, baseline)
            receipt["audit_wall_s"] = time.perf_counter() - tick
            write_new(folder / "independent-audit.json", receipt["audit"])
        if bindings(core, baseline) != receipt["binding"] or source_identity(args.run) != source:
            raise ValueError("Execution source/runtime drift")
        receipt["ok"] = True
    except BaseException as exc:
        receipt["error"] = f"{type(exc).__name__}: {exc}"
        if (folder / "physical/worker-result.json").is_file():
            receipt["partial_worker_result"] = json.loads((folder / "physical/worker-result.json").read_text())
    finally:
        if acquired:
            release(handle)
        jobs.close(handle)
        write_new(folder / "receipt.json", receipt)
    print(json.dumps(dict(ok=receipt["ok"], output=str(folder), physical_started=receipt["physical_started"], error=receipt.get("error"))), flush=True)
    return 0 if receipt["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
