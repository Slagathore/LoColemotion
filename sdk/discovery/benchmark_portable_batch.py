"""Matched saved-input host timings. No world creation or physics execution."""
import argparse
import hashlib
import json
from pathlib import Path
import statistics
import time
import unittest
from unittest.mock import patch

import mujoco
from portable_batch_control import BatchController
from portable_search_control import ROOT, Controller, bridge, contract, inputs, sha
from test_portable_batch import assert_bits


def benchmark(candidate_core, baseline_core, output):
    output = Path(output).resolve()
    evidence = (ROOT.parent / "SporeSpore_Evidence").resolve()
    if not output.is_relative_to(evidence):
        raise ValueError("Benchmark output must be fresh durable project evidence")
    output.mkdir(parents=False, exist_ok=False)
    c = contract()
    closure = json.loads((ROOT / "sdk/discovery/gpu_portable_search_closure_v2.json").read_text())
    source = Path(closure["evidence_root"]) / closure["attempt_id"] / "physical"
    worker = json.loads((source / "worker-result.json").read_text())
    source_hash = sha(source / "controller.jsonl")
    if source_hash != worker["controller_sha256"]:
        raise ValueError("Saved observation source changed")
    native = {}
    with (source / "controller.jsonl").open() as stream:
        for line in stream:
            row = json.loads(line)
            if row["backend"] != "gpu" or row["outer_step"] >= 28:
                break
            native[row["outer_step"], row["cell"]] = row
    if len(native) != 112:
        raise ValueError("Incomplete saved-input benchmark population")
    declaration = dict(schema_version="locolemotion_portable_batch_host_benchmark_v1",
        ledger_scope=dict(subsystem="discovery", engine_scope="core", authority_mode="development", question_class="development"),
        batch_sizes=[1, 4, 16], warmup_outer_steps=4, measured_outer_steps=24, repeats=3,
        order="alternate scalar/batch order by size index plus repeat index",
        source_controller_sha256=source_hash, source_attempt_id=closure["attempt_id"],
        candidate_core_sha256=sha(candidate_core), baseline_core_sha256=sha(baseline_core),
        workload="same saved observations, commands, proposal candidates and explicit memory evolution; exact full outputs checked outside timing",
        timing="controller calls including transport and host record construction; setup/warmup/checks reported separately",
        world_build_count=0, physics_state_modified=False, physical_acceptance_authority=False,
        throughput_qualification=False, statistical_superiority_claim=False)
    (output / "declaration.json").write_text(json.dumps(declaration, indent=2) + "\n", encoding="utf-8", newline="\n")
    check = unittest.TestCase()
    trials = []
    baseline = bridge.LocomotionCore(baseline_core)
    candidate = bridge.LocomotionCore(candidate_core)
    synthetic_binding = dict(c, core_sha256=sha(candidate_core))
    compiled, _, _ = inputs(candidate_core, synthetic_binding)
    for size_index, count in enumerate(declaration["batch_sizes"]):
        cells = [i % 4 for i in range(count)]
        for repeat in range(declaration["repeats"]):
            order = ["scalar", "batch"] if (repeat + size_index) % 2 == 0 else ["batch", "scalar"]
            for mode in order:
                start = time.perf_counter()
                controllers = ([Controller(baseline, compiled, c, cell) for cell in cells]
                               if mode == "scalar" else BatchController(candidate, compiled, c, cells))
                setup = time.perf_counter() - start
                elapsed = warmup = validation = 0.0
                digest = hashlib.sha256()
                try:
                    for outer in range(28):
                        expected = [native[outer, cell] for cell in cells]
                        observations = [(r["request"]["state"], r["stability"], r["kinematics"]) for r in expected]
                        start = time.perf_counter()
                        actual = ([controller.step(*observation) for controller, observation in zip(controllers, observations, strict=True)]
                                  if mode == "scalar" else controllers.step(observations))
                        duration = time.perf_counter() - start
                        if outer < declaration["warmup_outer_steps"]:
                            warmup += duration
                        else:
                            elapsed += duration
                        start = time.perf_counter()
                        for original, result in zip(expected, actual, strict=True):
                            assert_bits(check, {key: original[key] for key in result}, result)
                            digest.update(json.dumps(result, sort_keys=True, separators=(",", ":"), allow_nan=False).encode())
                        validation += time.perf_counter() - start
                finally:
                    if mode == "scalar":
                        for controller in controllers:
                            controller.close()
                    else:
                        controllers.close()
                trial = dict(batch_size=count, repeat=repeat, mode=mode, setup_s=setup, warmup_s=warmup,
                    measured_s=elapsed, validation_s=validation, measured_controller_steps=24 * count,
                    full_comparison_steps=28 * count, output_sha256=digest.hexdigest())
                trials.append(trial)
                with (output / "trials.jsonl").open("a", encoding="utf-8", newline="\n") as stream:
                    stream.write(json.dumps(trial, sort_keys=True) + "\n")
    summaries = []
    for count in declaration["batch_sizes"]:
        by_mode = {mode: [r for r in trials if r["batch_size"] == count and r["mode"] == mode] for mode in ("scalar", "batch")}
        for left, right in zip(by_mode["scalar"], by_mode["batch"], strict=True):
            if left["repeat"] != right["repeat"] or left["output_sha256"] != right["output_sha256"]:
                raise ValueError("Matched workload output disagreement")
        times = {mode: statistics.median(r["measured_s"] for r in rows) for mode, rows in by_mode.items()}
        summaries.append(dict(batch_size=count, median_s=times,
            scalar_over_batch_time_ratio=times["scalar"] / times["batch"],
            batch_controller_steps_per_wall_second=24 * count / times["batch"]))
    result = dict(ok=True, declaration_sha256=sha(output / "declaration.json"), trials_sha256=sha(output / "trials.jsonl"),
        trials=len(trials), full_comparison_steps=sum(r["full_comparison_steps"] for r in trials),
        summaries=summaries, world_build_count=0, physics_state_modified=False,
        physical_acceptance_authority=False, throughput_qualification=False)
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    # Pure-input generation and controller execution may not open a native world.
    with patch.object(mujoco, "MjModel", side_effect=AssertionError("world")), \
            patch.object(mujoco, "MjData", side_effect=AssertionError("data")), \
            patch.object(mujoco, "mj_step", side_effect=AssertionError("physics")):
        print(json.dumps(benchmark(args.candidate_core.resolve(), args.baseline_core.resolve(), args.output), indent=2))


if __name__ == "__main__":
    main()
