"""Reopen the consumed native shadow result without promoting learned influence.

The default verifies retained bytes, frozen sources, runtime/model bindings,
complete gate accounting, original reader results and recomputed timing. The
optional --replay additionally repeats all baseline/provider/native checks.
"""
import argparse
import json
from pathlib import Path
import re

from gpu_retrieval_shadow import ROOT, FLAGS, declaration, trial_plan, sha
from audit_gpu_retrieval_shadow import audit
from audit_gpu_batch_execution import timing_summary, read_jsonl
from audit_gpu_repertoire_negative_closure import verify_frozen_sources
from audit_gpu_portable_search import require
from retrieval_shadow_control import load_candidate, candidate_path, learner
from portable_search_control import bridge


def shadow_summary(audit_result):
    return {mode: dict(rows=value["rows"], provider_errors=value["provider_errors"],
        unexpected_fallbacks=value["unexpected_fallbacks"],
        hypothetical_nonzero_rows=value["hypothetical_nonzero_rows"],
        statuses=value["statuses"], operations=value["operations"],
        final_reset_epoch=value["final_memory"]["reset_epoch"],
        final_sequence=value["final_memory"]["sequence"],
        final_opaque_state_sha256=value["final_memory"]["opaque_state_sha256"])
        for mode, value in audit_result["trials"][0]["shadow"].items()}


def verify_record(path, evidence_root, core_path, baseline_path, *, replay=False):
    closure = json.loads(path.read_text())
    require(closure["schema_version"] == "locolemotion_gpu_retrieval_shadow_closure_v1"
        and closure["status"] == "complete_native_shadow_baseline_only"
        and closure["synthetic"] is False
        and all(closure[key] is False for key in [*FLAGS, "native_influence_evaluated",
            "provider_promotion_authority", "statistical_superiority_authority"]), "Closure identity/authority")
    root = evidence_root.resolve(strict=True)
    attempt = (root / closure["attempt_id"]).resolve(strict=True)
    require(attempt.parent == root and attempt.name == closure["attempt_id"], "Attempt path escaped")
    artifacts = closure["artifacts"]
    require(len(artifacts) == closure["artifact_count"] and bool(artifacts), "Artifact count")
    indexed = []
    for item in artifacts:
        target = (root / item["evidence_relative_path"]).resolve(strict=True)
        require(target.is_relative_to(attempt) and target.is_file(), "Artifact path escaped")
        require(target.stat().st_size == item["byte_length"] and sha(target) == item["sha256"], "Retained artifact changed")
        indexed.append(target)
    require(len(indexed) == len(set(indexed))
        and set(indexed) == {p.resolve() for p in attempt.rglob("*") if p.is_file()}, "Incomplete/duplicate artifact inventory")
    declared = json.loads((attempt / "declaration.json").read_text())
    consumed = json.loads((attempt / "consumed.json").read_text())
    receipt = json.loads((attempt / "receipt.json").read_text())
    worker = json.loads((attempt / "physical/worker-result.json").read_text())
    retained = json.loads((attempt / "independent-audit.json").read_text())
    c = declared["contract"]
    require(c == declaration() == receipt["contract"] and closure["ledger_scope"] == c["ledger_scope"], "Frozen declaration changed")
    require(closure["source_commit"] == declared["source_commit"] == consumed["source_commit"] == receipt["source_commit"]
        and consumed["attempt_id"] == closure["attempt_id"] and declared["binding"] == receipt["binding"], "Crossed source/attempt binding")
    require(receipt["ok"] is True and receipt["zero_world_gate_passed"] is True
        and receipt["physical_started"] is True and receipt["synthetic"] is False
        and worker["ok"] is True and worker["synthetic"] is False
        and worker["status"] == "complete_native_retrieval_shadow", "Incomplete native route")
    require(all(receipt[k] is False and worker[k] is False and retained[k] is False for k in FLAGS), "Retained authority changed")
    require(retained == receipt["audit"] and sha(attempt / "independent-audit.json") == closure["independent_audit_sha256"]
        and retained["ok"] is True and retained["synthetic"] is False and retained["reader_world_build_count"] == 0,
        "Independent reader binding")
    require(sha(core_path) == c["core_sha256"] == closure["core_sha256"]
        and sha(baseline_path) == c["baseline_core_sha256"] == closure["baseline_core_sha256"], "Core binding")
    sources = verify_frozen_sources(closure["source_commit"], declared["binding"]["source"])
    require(sources == closure["source_binding_count"], "Source denominator")
    require(len(declared["binding"]["runtime"]) == closure["runtime_binding_count"], "Runtime denominator")
    for name, digest in declared["binding"]["runtime"].items():
        require(sha(Path(name)) == digest, "Runtime bytes changed")
    candidate = candidate_path(c)
    expected_evidence = {str(candidate): c["model"]["artifact_sha256"],
        str(candidate.parent / "fit-receipt.json"): c["model"]["fit_receipt_sha256"]}
    require(declared["binding"]["candidate_evidence"] == expected_evidence
        and closure["candidate_evidence_binding_count"] == len(expected_evidence), "Candidate evidence population")
    for name, digest in expected_evidence.items():
        require(sha(Path(name)) == digest, "Retained candidate changed")
    core = bridge.LocomotionCore(core_path)
    model = load_candidate(core, c)
    require(model.sha256 == retained["model_sha256"] == closure["model_sha256"]
        and sha(attempt / "physical/retrieval-model.json") == c["model"]["artifact_sha256"]
        and retained["base_model_immutable"] is True, "Frozen model changed")
    plans = trial_plan(c)
    population = dict(gpu=1, cpu=0)
    require(declared["planned_trials"] == consumed["planned_trials"] == receipt["planned_trials"] == plans
        and declared["planned_worlds"] == consumed["planned_worlds"] == receipt["planned_worlds"] == population,
        "Planned population")
    require(len(worker["trials"]) == len(retained["trials"]) == closure["trial_count"] == 1
        and worker["constructed_gpu_worlds"] == worker["cpu_readback_views"] == retained["constructed_gpu_worlds"] == closure["constructed_gpu_worlds"] == 1
        and worker["stepped_cpu_worlds"] == 0 and worker["controller_sessions_closed"] is True, "Native lifecycle denominator")
    require(retained["controller_rows"] == closure["controller_rows"] == 480
        and retained["shadow_rows"] == closure["shadow_rows"] == 2400
        and retained["internal_rows"] == closure["internal_rows"] == 2400
        and retained["physical_provider_influence_rows"] == closure["physical_provider_influence_rows"] == 0
        and retained["calibration_worlds"] == closure["calibration_worlds"] == 1
        and retained["evaluation_worlds"] == closure["evaluation_worlds"]
        == retained["training_worlds"] == closure["training_worlds"] == 0, "Completed population")
    require(closure["native_worker_wall_s"] == worker["total_wall_s"]
        and closure["independent_audit_wall_s"] == receipt["audit_wall_s"], "Timing identity")
    gate_counts = {"measurement-gate":7, "quadruped-gate":10, "portable-gate":11,
        "host-batch-gate":7, "graph-execution-gate":7, "fit-closure-gate":5,
        "shadow-gate":9, "retrieval-gate":9, "provider-gate":2, "containment-gate":1}
    require(closure["complete_zero_world_gate"] == gate_counts and sum(gate_counts.values()) == 68, "Safety gate accounting")
    for directory, count in gate_counts.items():
        log = (attempt / directory / "stderr.log").read_text()
        require(re.findall(r"(?m)^Ran ([0-9]+) tests? in ", log) == [str(count)]
            and log.strip().endswith("OK"), "Safety gate terminal/count")
    preflight = json.loads((attempt / "runtime-gate/stdout.log").read_text())
    require(preflight == receipt["preflight"] and preflight["ok"] is True
        and preflight["world_build_count"] == preflight["solver_steps"] == 0
        and preflight["planned_gpu_worlds"] == preflight["calibration_worlds"] == 1
        and preflight["evaluation_worlds"] == preflight["training_worlds"] == 0, "Runtime gate join")
    plan, trial, checked = plans[0], worker["trials"][0], retained["trials"][0]
    folder = attempt / "physical" / plan["trial_id"]
    require(all(trial[k] == value and checked[k] == value for k,value in plan.items())
        and json.loads((folder / "plan.json").read_text()) == plan
        and json.loads((folder / "result.json").read_text()) == trial
        and trial["completed"] is True, "Trial identity")
    for name in ["controller", "trace", "timing"]:
        require(sha(folder / (name + ".jsonl")) == trial["hashes"][name], "Raw stream binding")
    require(trial["outer_rows"] == checked["controller_rows"] == 480
        and trial["internal_rows"] == checked["internal_rows"] == 2400
        and timing_summary(list(read_jsonl(folder / "timing.jsonl")), c) == checked["timings"], "Trial population/timing")
    require(shadow_summary(retained) == closure["shadow_summary"], "Shadow summary changed")
    for mode, state in checked["shadow"].items():
        memory = state["final_memory"]
        require(state["rows"] == sum(state["statuses"].values()) == 480
            and state["provider_errors"] == state["unexpected_fallbacks"] == 0
            and memory["weights_mutated"] is False
            and learner.digest(core, memory["opaque_state"]) == memory["opaque_state_sha256"], "Shadow memory/counts")
        episodic = mode in c["shadow_operation_modes"]
        require(state["operations"] == (c["shadow_operations"] if episodic else [])
            and memory["reset_epoch"] == (1 if episodic else 0)
            and memory["sequence"] == (119 if episodic else 480), "Shadow lifecycle")
    metric = checked["metrics"][0]
    eligible = (metric["minimum_height_m"] >= c["selection"]["minimum_height_m"]
        and metric["maximum_tilt_rad"] <= c["selection"]["maximum_tilt_rad"]
        and metric["torso_contact_steps"] == metric["safe_no_actuation_steps"] == 0)
    require(eligible and checked["shadow"]["frozen"]["hypothetical_nonzero_rows"] > 0
        and checked["shadow"]["disabled"]["hypothetical_nonzero_rows"] == 0
        and retained["baseline_eligible"] is True
        and retained["shadow_ready_for_distinct_influence_design"] is True
        and closure["shadow_ready_for_distinct_influence_design"] is True, "Shadow readiness changed")
    if replay:
        require(audit(attempt / "physical", core_path, baseline_path) == retained, "Repeated complete reader differs")
    return dict(ok=True, artifact_count=len(indexed), source_binding_count=sources,
        runtime_binding_count=closure["runtime_binding_count"], candidate_evidence_binding_count=2,
        original_independent_reader_controller_rows=480, original_independent_reader_shadow_rows=2400,
        original_independent_reader_internal_rows=2400, timing_summary_recomputed=True,
        full_controller_replay_performed=replay, world_build_count=0,
        model_sha256=model.sha256, physical_provider_influence_rows=0,
        shadow_ready_for_distinct_influence_design=True, native_influence_evaluated=False,
        provider_promotion_authority=False, **{k:False for k in FLAGS})


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("closure", type=Path)
    parser.add_argument("--evidence-root", type=Path, required=True)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--replay", action="store_true")
    args = parser.parse_args()
    print(json.dumps(verify_record(args.closure, args.evidence_root, args.core, args.baseline_core, replay=args.replay), indent=2))
