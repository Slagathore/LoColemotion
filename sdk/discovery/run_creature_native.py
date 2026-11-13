"""One retained owner for declared mixed-creature gates, native work and replay."""
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

from creature_native import ROOT, HERE, FLAGS, gates, MODEL_SOURCES, declaration, require, sha, capture, retiming, braking_search
from gpu_measurement_probe import write_new
from run_gpu_measurement_probe import source_identity
from run_gpu_motor_effectiveness import bindings as inherited_bindings
from run_contact_sequence_native_v2 import invoke, jobs
from run_residual_native import verify_tests


def status():
    return subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).splitlines()


def inventory(folder):
    return [dict(path=p.relative_to(folder).as_posix(), bytes=p.stat().st_size, sha256=sha(p))
            for p in sorted(folder.rglob("*")) if p.is_file() and "warp-cache" not in p.parts]


def source_paths(contract_path, c):
    paths = [contract_path, HERE / ".gitattributes", *[HERE / name for name in MODEL_SOURCES],
             *retiming.source_dependencies(c), *braking_search.source_dependencies(c)]
    if "capture_reference" in c:
        reference = (ROOT / c["capture_reference"]["path"]).resolve(strict=True)
        require(reference.is_relative_to(ROOT) and sha(reference) == c["capture_reference"]["sha256"],
                "Creature capture reference source")
        paths.append(reference)
    # The selected contract may also be a declared test dependency.
    return list(dict.fromkeys(paths))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--full-canary", type=Path, help="Verified same-freeze full-capture owner receipt for compact native execution")
    args = parser.parse_args()
    contract_path, core, baseline = [p.resolve(strict=True) for p in (args.contract, args.core, args.baseline_core)]
    c = declaration(contract_path)
    source, original_status = source_identity(args.run), status()
    require(sha(core) == c["core_sha256"] and sha(baseline) == c["baseline_core_sha256"], "Creature frozen core images")
    evidence = ROOT.parent / "SporeSpore_Evidence"
    require(shutil.disk_usage(evidence).free >= c["minimum_free_storage_bytes"], "Creature evidence storage")
    sources = source_paths(contract_path, c)
    def bindings():
        bound = inherited_bindings(core, baseline)
        bound["source"].update({p.relative_to(ROOT).as_posix(): sha(p) for p in sources})
        return bound
    folder = evidence / ("sdk2-" + c["campaign_id"].replace("_", "-") + "-" + uuid.uuid4().hex)
    folder.mkdir()
    print(str(folder), flush=True)
    receipt = dict(schema_version="locolemotion_creature_owner_v1", ledger_scope=c["ledger_scope"],
        source_commit=source, source_status=original_status, contract=c, synthetic=not args.run,
        ok=False, physical_launch_requested=False, physical_started=False, safety_controls={},
        **{k: False for k in FLAGS})
    create = jobs.api("CreateMutexW", [C.c_void_p, W.BOOL, W.LPCWSTR], W.HANDLE)
    release = jobs.api("ReleaseMutex", [W.HANDLE])
    handle = jobs.checked(create(None, False, r"Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"))
    acquired, started = False, time.monotonic()
    try:
        require(jobs.wait(handle, 0) == 0, "Another operation owns the physical mutex")
        acquired = True
        receipt["bindings"] = bindings()
        if args.run and c["capture_mode"] == "compact_v1":
            require(args.full_canary is not None, "Compact native launch requires a full canary receipt")
            receipt["capture_prerequisite"] = capture.canary_receipt(
                args.full_canary, c, source, receipt["bindings"], evidence)
        else:
            require(args.full_canary is None, "Full canary receipt outside compact native launch")
        for path in sources:
            target = folder / "source" / path.relative_to(ROOT)
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("xb") as stream:
                stream.write(path.read_bytes())
        write_new(folder / "declaration.json", receipt)
        env = dict(PYTHONPATH=";".join(str(ROOT / p) for p in
            ("sdk/discovery", "sdk/conformance", "sdk/explorer", "sdk/python", "sdk/adapters/mujoco", "sdk")),
            QUADRUPED_TEST_CORE=str(baseline), PORTABLE_BATCH_BASELINE_CORE=str(baseline),
            SPORESPORE_LOCOMOTION_LIBRARY=str(baseline), PYTHONIOENCODING="utf-8",
            OPENBLAS_NUM_THREADS="1", OMP_NUM_THREADS="1", MKL_NUM_THREADS="1")
        batch_env = dict(env, QUADRUPED_TEST_CORE=str(core), SPORESPORE_LOCOMOTION_LIBRARY=str(core))
        for index, (name, module, count) in enumerate(gates(c)):
            print(json.dumps(dict(stage=name, controls=count)), flush=True)
            artifacts = folder / (name + "-artifacts")
            artifacts.mkdir()
            target = folder / (name + "-gate")
            invoke([sys.executable, "-B", "-m", "unittest", "-v", module], target, 900,
                   dict(env if index < 3 else batch_env, EXPLORER_TEST_OUTPUT=str(artifacts)))
            verify_tests(target, count)
            receipt["safety_controls"][name] = count
        command = [sys.executable, "-B", str(HERE / "creature_native.py"),
                   "--contract", str(contract_path), "--core", str(core)]
        invoke([*command, "--check-only"], folder / "runtime-gate", 240, batch_env)
        preflight = json.loads((folder / "runtime-gate/stdout.log").read_text(encoding="utf-8"))
        require(preflight["ok"] is True and preflight["world_build_count"] == preflight["solver_steps"] == 0
                and preflight["planned_gpu_worlds"] == len(c["cells"])
                and receipt["safety_controls"] == {n:k for n, _, k in gates(c)}, "Creature incomplete safety gate")
        def unchanged():
            require(bindings() == receipt["bindings"] and source_identity(args.run) == source
                    and status() == original_status, "Creature source/runtime drift")
            if "capture_prerequisite" in receipt:
                require(capture.canary_receipt(args.full_canary, c, source, receipt["bindings"], evidence)
                        == receipt["capture_prerequisite"], "Full canary evidence drift")
        unchanged()
        receipt.update(zero_world_gate_passed=True, preflight=preflight)
        write_new(folder / "gate-receipt.json", dict(ok=True, source_commit=source, ledger_scope=c["ledger_scope"],
            declaration_sha256=sha(folder / "declaration.json"), safety_controls=receipt["safety_controls"], preflight=preflight))
        if args.run:
            write_new(folder / "consumed.json", dict(attempt_id=folder.name, source_commit=source,
                contract_sha256=sha(contract_path), gate_receipt_sha256=sha(folder / "gate-receipt.json")))
            target = folder / "native"
            receipt["physical_launch_requested"] = True
            invoke([*command, "--output", str(target), "--permit", str(target / "contained.permit")],
                   target, c["maximum_worker_wall_seconds"], batch_env)
            unchanged()
            invoke([*command, "--audit", "--folder", str(target), "--output", str(folder / "independent-audit.json")],
                   folder / "reader", c["maximum_reader_wall_seconds"], batch_env)
            audit = json.loads((folder / "independent-audit.json").read_text())
            require(audit["ok"] is True and audit["synthetic"] is False and audit["reader_world_build_count"] == 0
                    and audit["gpu_worlds"] == len(c["cells"])
                    and audit["controller_rows_replayed"] == (len(c["cells"])*c["outer_steps"] if c["capture_mode"] == "full" else 0)
                    and audit["native_rows_verified"] == (len(c["cells"])*c["outer_steps"]*5 if c["capture_mode"] == "full" else 0),
                    "Creature native reader refused")
            if "compact_capture" in c:
                captured = audit["capture"]
                require(captured["compact_controller_rows_verified"] == len(c["cells"])*c["outer_steps"]
                        and captured["compact_native_samples_reconstructed"] == len(c["cells"])*c["outer_steps"]*5
                        and captured["within_run_projection_verified"] is (c["capture_mode"] == "full")
                        and captured["full_capture"] is (c["capture_mode"] == "full")
                        and captured["qualification_requires_fresh_full_capture"] is True,
                        "Creature compact reader scope or denominator")
            receipt["audit"] = audit
            unchanged()
        receipt.update(ok=True, source_runtime_unchanged=True)
    except BaseException as exc:
        receipt["error"] = type(exc).__name__ + ": " + str(exc)
    finally:
        worker_path = folder / "native/worker-result.json"
        if worker_path.is_file():
            worker = json.loads(worker_path.read_text())
            receipt["worker"] = worker
            receipt["physical_started"] = bool(worker["native_model_constructions"] or worker["constructed_gpu_worlds"])
        elif receipt["physical_launch_requested"]:
            receipt["physical_started"] = None
        receipt["wall_s"] = time.monotonic() - started
        try:
            receipt["artifacts"] = inventory(folder)
            write_new(folder / "receipt.json", receipt)
        finally:
            if acquired:
                release(handle)
            jobs.close(handle)
    print(json.dumps(dict(ok=receipt["ok"], output=str(folder), physical_started=receipt["physical_started"],
                          error=receipt.get("error"))), flush=True)
    return 0 if receipt["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
