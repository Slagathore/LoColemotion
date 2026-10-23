"""Bind the retained full reader and recompute timing without repeating physics.

Default verification rehashes every artifact, frozen source and current runtime,
checks the retained independent-reader joins, and recomputes the timing table.
Use --replay to additionally repeat every scalar controller and internal check.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import statistics
import subprocess

from gpu_batch_execution import ROOT, FLAGS, declaration, trial_plan
from gpu_quadruped_model import sha
from audit_gpu_batch_execution import audit, timing_summary, read_jsonl
from audit_gpu_portable_search import require


def header(closure, evidence_root):
    require(closure["schema_version"] == "locolemotion_gpu_batch_execution_closure_v1"
            and closure["status"] == "complete_full_capture_execution_comparison"
            and closure["synthetic"] is False
            and all(closure[key] is False for key in [*FLAGS, "trained_provider", "statistical_superiority_authority"]),
            "Closure identity/authority")
    require(closure["ledger_scope"] == declaration()["ledger_scope"], "Closure ledger scope")
    root = evidence_root.resolve(strict=True)
    attempt = (root / closure["attempt_id"]).resolve(strict=True)
    require(attempt.parent == root and attempt.name == closure["attempt_id"], "Attempt path escaped")
    artifacts = closure["artifacts"]
    require(len(artifacts) == closure["artifact_count"] and bool(artifacts), "Artifact count")
    indexed = []
    for entry in artifacts:
        target = (root / entry["evidence_relative_path"]).resolve(strict=True)
        require(target.is_relative_to(attempt) and target.is_file(), "Artifact path escaped")
        require(type(entry["byte_length"]) is int and entry["byte_length"] >= 0
                and len(entry["sha256"]) == 64 and all(c in "0123456789abcdef" for c in entry["sha256"]), "Artifact binding shape")
        indexed.append(target)
    require(len(indexed) == len(set(indexed)), "Duplicate artifact")
    require(set(indexed) == {p.resolve() for p in attempt.rglob("*") if p.is_file()}, "Incomplete artifact inventory")
    return root, attempt, indexed


def verify_frozen_sources(commit, bindings):
    require(len(commit) == 40 and all(c in "0123456789abcdef" for c in commit), "Source commit shape")
    keys = list(bindings)
    paths = [key.replace("\\", "/") for key in keys]
    require(all(not path.startswith("/") and ":" not in path and ".." not in path.split("/")
                and "\n" not in path and "\r" not in path for path in paths), "Source path shape")
    payload = "".join(commit + ":" + path + "\n" for path in paths).encode()
    response = subprocess.run(["git", "cat-file", "--batch"], input=payload, cwd=ROOT,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True, timeout=60)
    stream = io.BytesIO(response.stdout)
    for key in keys:
        fields = stream.readline().decode().strip().split()
        require(len(fields) == 3 and fields[1] == "blob", "Frozen source missing")
        blob = stream.read(int(fields[2]))
        require(stream.read(1) == b"\n", "Git blob framing")
        # Git stores LF; historical text pins may bind the normal CRLF checkout.
        variants = [blob]
        if b"\r" not in blob:
            variants.append(blob.replace(b"\n", b"\r\n"))
        require(bindings[key] in [hashlib.sha256(value).hexdigest() for value in variants], "Frozen source bytes differ")
    require(stream.read() == b"", "Extra Git blob output")
    return len(keys)


def verify_record(path, evidence_root, core_path, baseline_path, *, replay=False):
    closure = json.loads(path.read_text())
    root, attempt, indexed = header(closure, evidence_root)
    for entry, target in zip(closure["artifacts"], indexed, strict=True):
        require(target.stat().st_size == entry["byte_length"] and sha(target) == entry["sha256"], "Retained artifact changed")
    declared = json.loads((attempt / "declaration.json").read_text())
    consumed = json.loads((attempt / "consumed.json").read_text())
    receipt = json.loads((attempt / "receipt.json").read_text())
    worker = json.loads((attempt / "physical/worker-result.json").read_text())
    retained = json.loads((attempt / "independent-audit.json").read_text())
    c = declared["contract"]
    require(c == declaration() == receipt["contract"], "Frozen contract changed")
    require(closure["source_commit"] == declared["source_commit"] == consumed["source_commit"] == receipt["source_commit"], "Crossed source freeze")
    require(consumed["attempt_id"] == closure["attempt_id"] and declared["binding"] == receipt["binding"], "Crossed attempt/runtime binding")
    require(receipt["ok"] is True and receipt["physical_started"] is True and receipt["zero_world_gate_passed"] is True
            and worker["ok"] is True and receipt["synthetic"] is False and worker["synthetic"] is False, "Incomplete native route")
    require(all(receipt[key] is False and worker[key] is False and retained[key] is False for key in FLAGS), "Changed retained authority")
    require(retained == receipt["audit"] and sha(attempt / "independent-audit.json") == closure["independent_audit_sha256"], "Independent reader binding")
    require(retained["ok"] is True and retained["synthetic"] is False and retained["reader_world_build_count"] == 0
            and retained["trained_provider"] is False and retained["statistical_superiority_authority"] is False, "Reader identity/authority")
    require(sha(core_path) == c["core_sha256"] == closure["core_sha256"]
            and sha(baseline_path) == c["baseline_core_sha256"] == closure["baseline_core_sha256"], "Native core binding")
    source_count = verify_frozen_sources(closure["source_commit"], declared["binding"]["source"])
    require(source_count == closure["source_binding_count"], "Source binding denominator")
    for name, digest in declared["binding"]["runtime"].items():
        require(sha(Path(name)) == digest, "Runtime bytes changed")
    require(len(declared["binding"]["runtime"]) == closure["runtime_binding_count"], "Runtime binding denominator")
    plans = trial_plan(c)
    worlds = sum(p["nworld"] for p in plans)
    require(declared["planned_trials"] == receipt["planned_trials"] == consumed["planned_trials"] == plans, "Trial plan join")
    require(declared["planned_worlds"] == receipt["planned_worlds"] == consumed["planned_worlds"] == dict(gpu=worlds, cpu=0), "Planned population")
    require(len(worker["trials"]) == len(retained["trials"]) == closure["trial_count"] == len(plans), "Completed trial denominator")
    require(worker["constructed_gpu_worlds"] == worker["cpu_readback_views"] == retained["constructed_gpu_worlds"] == closure["constructed_gpu_worlds"] == worlds
            and worker["stepped_cpu_worlds"] == 0 and worker["controller_sessions_closed"] is True, "Completed world lifecycle")
    require(retained["controller_rows"] == closure["controller_rows"] == worlds * c["outer_steps"]
            and retained["internal_rows"] == closure["internal_rows"] == worlds * c["outer_steps"] * 5, "Completed row denominator")
    require(closure["native_worker_wall_s"] == worker["total_wall_s"]
            and closure["independent_audit_wall_s"] == receipt["audit_wall_s"], "Wall timing join")
    gate_names = {"measurement_tests": "measurement-gate", "quadruped_tests": "quadruped-gate",
        "portable_tests": "portable-gate", "host_batch_tests": "host-batch-gate",
        "graph_execution_tests": "graph-execution-gate", "provider_tests": "provider-gate",
        "process_containment_tests": "containment-gate"}
    expected_counts = dict(measurement_tests=7, quadruped_tests=10, portable_tests=11,
        host_batch_tests=7, graph_execution_tests=7, provider_tests=2, process_containment_tests=1,
        runtime_preflight_worlds=0)
    require(closure["complete_zero_world_gate"] == expected_counts, "Safety gate accounting")
    for name, directory in gate_names.items():
        log = (attempt / directory / "stderr.log").read_text()
        require(re.findall(r"(?m)^Ran ([0-9]+) tests? in ", log) == [str(expected_counts[name])]
                and log.strip().endswith("OK"), "Safety gate terminal/count")
    preflight = json.loads((attempt / "runtime-gate/stdout.log").read_text())
    require(preflight == receipt["preflight"] and preflight["ok"] is True
            and preflight["world_build_count"] == preflight["solver_steps"] == 0
            and preflight["planned_trials"] == len(plans) and preflight["planned_gpu_worlds"] == worlds, "Runtime gate join")
    measured = []
    for plan, trial, checked in zip(plans, worker["trials"], retained["trials"], strict=True):
        directory = attempt / "physical" / plan["trial_id"]
        require(all(checked[key] == value and trial[key] == value for key, value in plan.items()), "Reader trial identity")
        require(json.loads((directory / "plan.json").read_text()) == plan
                and json.loads((directory / "result.json").read_text()) == trial and trial["completed"] is True, "Completed trial binding")
        for name in ["controller", "trace", "timing"]:
            require(sha(directory / (name + ".jsonl")) == trial["hashes"][name], "Trial raw binding")
        timing = timing_summary(list(read_jsonl(directory / "timing.jsonl")), c)
        require(timing == checked["timings"], "Recomputed timing differs")
        require(checked["controller_rows"] == trial["outer_rows"] == plan["nworld"] * c["outer_steps"]
                and checked["internal_rows"] == trial["internal_rows"] == plan["nworld"] * c["outer_steps"] * 5, "Per-trial denominator")
        measured.append(dict(plan, timing=timing))
    require(closure["comparisons"] == retained["comparisons"], "Closure comparison changed")
    for size, comparison in zip(c["batch_sizes"], retained["comparisons"], strict=True):
        medians = {arm: statistics.median(r["timing"]["measured"]["outer_total_s"] for r in measured
                    if r["nworld"] == size and r["arm"] == arm) for arm in c["arms"]}
        require(comparison["nworld"] == size and comparison["median_measured_outer_total_s"] == medians
                and comparison["scalar_over_batch_ratio"] == medians["scalar_direct"] / medians["batch_graph"]
                and comparison["batch_controller_steps_per_s"] == size * (c["outer_steps"] - c["warmup_outer_steps"]) / medians["batch_graph"], "Recomputed comparison differs")
    if replay:
        require(audit(attempt / "physical", core_path, baseline_path) == retained, "Repeated full independent audit differs")
    return dict(ok=True, artifact_count=len(indexed), source_binding_count=source_count,
        runtime_binding_count=closure["runtime_binding_count"], original_independent_reader_controller_rows=retained["controller_rows"],
        original_independent_reader_internal_rows=retained["internal_rows"], timing_summary_recomputed=True,
        full_controller_replay_performed=replay, world_build_count=0, trained_provider=False,
        comparisons=closure["comparisons"], **{key: False for key in FLAGS})


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("closure", type=Path)
    parser.add_argument("--evidence-root", type=Path, required=True)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--replay", action="store_true")
    args = parser.parse_args()
    print(json.dumps(verify_record(args.closure, args.evidence_root, args.core, args.baseline_core, replay=args.replay), indent=2))
