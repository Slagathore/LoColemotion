"""Read-only verification of the pure batch component and host benchmark."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics

ROOT = Path(__file__).resolve().parents[2]
RECORD = Path(__file__).with_name("portable_batch_component_v1.json")


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def audit_benchmark(declaration, trials, result):
    require(declaration["batch_sizes"] == [1, 4, 16] and declaration["repeats"] == 3
            and declaration["warmup_outer_steps"] == 4 and declaration["measured_outer_steps"] == 24,
            "Benchmark declaration")
    require(len(trials) == 18 and result["trials"] == 18, "Trial denominator")
    expected_order = []
    for size_index, count in enumerate([1, 4, 16]):
        for repeat in range(3):
            modes = ["scalar", "batch"] if (repeat + size_index) % 2 == 0 else ["batch", "scalar"]
            expected_order.extend((count, repeat, mode) for mode in modes)
    require([(r["batch_size"], r["repeat"], r["mode"]) for r in trials] == expected_order, "Trial identities/order")
    for row in trials:
        require(row["measured_controller_steps"] == 24 * row["batch_size"]
                and row["full_comparison_steps"] == 28 * row["batch_size"], "Comparison denominator")
        require(all(math.isfinite(row[k]) and row[k] > 0 for k in ["measured_s", "setup_s", "warmup_s", "validation_s"]), "Invalid timing")
    summaries = []
    for count in [1, 4, 16]:
        rows = {mode: [r for r in trials if r["batch_size"] == count and r["mode"] == mode] for mode in ["scalar", "batch"]}
        for a, b in zip(rows["scalar"], rows["batch"], strict=True):
            require(a["output_sha256"] == b["output_sha256"] and len(a["output_sha256"]) == 64, "Matched output digest")
        times = {mode: statistics.median(r["measured_s"] for r in cells) for mode, cells in rows.items()}
        summaries.append(dict(batch_size=count, median_s=times,
            scalar_over_batch_time_ratio=times["scalar"] / times["batch"],
            batch_controller_steps_per_wall_second=24 * count / times["batch"]))
    require(result["summaries"] == summaries, "Recomputed timing summary")
    require(result["full_comparison_steps"] == sum(r["full_comparison_steps"] for r in trials) == 3528, "Full comparison denominator")
    for record in [declaration, result]:
        require(record["world_build_count"] == 0 and record["physics_state_modified"] is False
                and record["physical_acceptance_authority"] is False and record["throughput_qualification"] is False,
                "Benchmark authority")
    require(result["ok"] is True and declaration["statistical_superiority_claim"] is False, "Benchmark claim")
    return summaries


def verify_component(record=None):
    record = json.loads(RECORD.read_text()) if record is None else record
    require(record["schema_version"] == "locolemotion_portable_batch_component_v1", "Component version")
    require(record["world_build_count"] == 0 and record["physical_acceptance_authority"] is False
            and record["native_gpu_integration_verified"] is False and record["trained_provider"] is False,
            "Component authority")
    evidence = (ROOT.parent / "SporeSpore_Evidence").resolve()
    folder = (evidence / record["attempt_id"]).resolve()
    require(folder.is_relative_to(evidence) and folder != evidence, "Evidence boundary")
    for artifact in record["artifacts"]:
        path = (folder / artifact["path"]).resolve()
        require(path.is_relative_to(folder) and path.is_file(), "Artifact boundary")
        require(path.stat().st_size == artifact["bytes"] and digest(path) == artifact["sha256"], "Artifact digest")
    for binding in record["source_bindings"]:
        path = (ROOT / binding["path"]).resolve()
        require(path.is_relative_to(ROOT) and digest(path) == binding["sha256"], "Component source digest")
    load = lambda name: json.loads((folder / name).read_text())
    for name in ["compile-02", "tests-02", "core-tests-01", "benchmark-launch-01"]:
        require(load(name + "/receipt.json")["returncode"] == 0, "Successful process receipt")
    require(load("tests-01/receipt.json")["returncode"] != 0, "Preserved fixture binding failure")
    require(load("compile-01/manifest.json")["status"] == "initial_compile_failure", "Preserved compiler failure")
    require("524 passed; 0 failed" in (folder / "core-tests-01/stdout.txt").read_text(), "Core test result")
    tests = (folder / "tests-02/stderr.txt").read_text()
    require("Ran 7 tests" in tests and tests.rstrip().endswith("OK")
            and "test_complete_retained_population_replays_without_physics" in tests, "Batch conformance result")
    require(record["retained_controller_steps_compared"] == 3840, "Retained comparison scope")
    candidate = folder / "tests-01/sporespore_locomotion_core.dll"
    require(digest(candidate) == record["candidate_core_sha256"], "Candidate core digest")
    declaration = load("benchmark-01/declaration.json")
    result = load("benchmark-01/result.json")
    trials = [json.loads(line) for line in (folder / "benchmark-01/trials.jsonl").read_text().splitlines()]
    require(digest(folder / "benchmark-01/declaration.json") == result["declaration_sha256"]
            and digest(folder / "benchmark-01/trials.jsonl") == result["trials_sha256"], "Benchmark raw binding")
    require(declaration["candidate_core_sha256"] == record["candidate_core_sha256"], "Benchmark runtime binding")
    source = evidence / declaration["source_attempt_id"] / "physical/controller.jsonl"
    require(digest(source) == declaration["source_controller_sha256"], "Retained observation binding")
    return dict(ok=True, artifacts_rehashed=len(record["artifacts"]), source_files=len(record["source_bindings"]),
                retained_controller_steps_compared=3840, benchmark=audit_benchmark(declaration, trials, result),
                world_build_count=0, native_gpu_integration_verified=False, physical_acceptance_authority=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    print(json.dumps(verify_component(), indent=2))
