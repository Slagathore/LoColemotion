"""Reopen the consumed finite native influence result without promotion.

Default verification binds the original full reader, immutable artifacts,
source/runtime/model identities, all group outcomes, memory and timing.
Optional --replay repeats every scalar/provider/native check without worlds.
"""
import argparse
import json
from pathlib import Path
import re

from gpu_contextual_influence import ROOT, FLAGS, declaration, trial_plan, sha
from audit_gpu_contextual_influence import audit
from audit_gpu_batch_execution import timing_summary, read_jsonl
from audit_gpu_repertoire_negative_closure import verify_frozen_sources
from audit_gpu_portable_search import require
from retrieval_shadow_control import load_candidate, candidate_path, learner
from adaptation_provider.retrieval import contextual_v1 as contextual
from portable_search_control import bridge


GATE_COUNTS = {"measurement-gate":7, "quadruped-gate":10, "portable-gate":11,
    "host-batch-gate":7, "graph-execution-gate":7, "fit-closure-gate":5,
    "shadow-closure-gate":4, "influence-route-gate":6, "influence-host-gate":3,
    "influence-accounting-gate":5, "retrieval-gate":9, "provider-gate":2, "containment-gate":1,
    "influence-closure-gate":4, "feedback-diagnostic-gate":4, "contextual-component-gate":6,
    "contextual-route-gate":6, "contextual-host-gate":3}


def group_summary(result):
    return {trial["group_id"]: dict(mode_order=trial["mode_order"],
        metrics=dict(zip(trial["mode_order"], trial["metrics"], strict=True)),
        comparison=trial["comparison"],
        providers={mode: dict(rows=value["rows"], provider_errors=value["provider_errors"],
            unexpected_fallbacks=value["unexpected_fallbacks"], statuses=value["statuses"],
            resolved_nonzero_rows=value["resolved_nonzero_rows"],
            new_action_selections=value["new_action_selections"],
            same_input_choices_changed_by_memory=value["same_input_choices_changed_by_memory"],
            completed_feedback_updates=value["completed_feedback_updates"],
            context_supported_action_selections=value.get("context_supported_action_selections",0),
            context_nonzero_offset_selections=value.get("context_nonzero_offset_selections",0),
            final_reset_epoch=value["final_memory"]["reset_epoch"],
            final_sequence=value["final_memory"]["sequence"],
            final_opaque_state_sha256=value["final_memory"]["opaque_state_sha256"])
            for mode,value in trial["providers"].items()})
        for trial in result["trials"]}


def finite_outcomes(result):
    groups = result["group_comparisons"]
    episodic = [s for t in result["trials"] for mode,s in t["providers"].items()
                if mode in ["episodic", "episodic_shuffled"]]
    return dict(
        frozen_favorable_groups=[r["group_id"] for r in groups if r["frozen_favorable_in_this_group"]],
        episodic_favorable_groups=[r["group_id"] for r in groups if r["episodic_favorable_in_this_group"]],
        matched_influence_memory_benefit_groups=[r["group_id"] for r in groups if r["matched_influence_memory_benefit"]],
        native_episode_feedback_mechanism_verified=all(s["completed_feedback_updates"] > 0
            and s["provider_errors"] == s["unexpected_fallbacks"] == 0 for s in episodic),
        completed_episode_feedback_updates=sum(s["completed_feedback_updates"] for s in episodic),
        same_input_choices_changed_by_episode_memory=sum(s["same_input_choices_changed_by_memory"] for s in episodic),
        selections_with_matching_context_feedback=sum(s.get("context_supported_action_selections",0) for s in episodic),
        selections_with_nonzero_context_offsets=sum(s.get("context_nonzero_offset_selections",0) for s in episodic),
        native_context_reuse_mechanism_verified=all(s.get("context_supported_action_selections",0) > 0
            and s["provider_errors"] == s["unexpected_fallbacks"] == 0 for s in episodic))


def verify_record(path, evidence_root, core_path, baseline_path, *, replay=False):
    closure = json.loads(path.read_text())
    require(closure["schema_version"] == "locolemotion_gpu_contextual_influence_closure_v1"
        and closure["status"] == "complete_native_influence_comparison"
        and closure["synthetic"] is False
        and closure["native_influence_evaluated"] is True
        and all(closure[key] is False for key in [*FLAGS, "provider_promotion_authority",
            "statistical_superiority_authority", "noninferiority_authority"]), "Closure identity/authority")
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
        and worker["status"] == "complete_native_retrieval_influence", "Incomplete native route")
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
    diagnostic = root/c["design_diagnostic"]["attempt_id"]/c["design_diagnostic"]["artifact"]
    require(declared["binding"]["design_diagnostic"] == {str(diagnostic):c["design_diagnostic"]["sha256"]}
        and closure["design_diagnostic_binding_count"] == 1
        and sha(diagnostic) == c["design_diagnostic"]["sha256"], "Retained design diagnostic changed")
    require(closure["contextual_contract_sha256"] == c["contextual_contract_sha256"] == sha(contextual.CONTRACT),
        "Contextual component binding")
    core = bridge.LocomotionCore(core_path)
    model = load_candidate(core, c)
    require(model.sha256 == retained["model_sha256"] == closure["model_sha256"]
        and sha(attempt / "physical/retrieval-model.json") == c["model"]["artifact_sha256"]
        and retained["base_model_immutable"] is True, "Frozen model changed")
    plans = trial_plan(c)
    population = dict(gpu=18, cpu=0)
    require(declared["planned_trials"] == consumed["planned_trials"] == receipt["planned_trials"] == plans
        and declared["planned_worlds"] == consumed["planned_worlds"] == receipt["planned_worlds"] == population,
        "Planned population")
    require(len(worker["trials"]) == len(retained["trials"]) == closure["trial_count"] == 3
        and worker["constructed_gpu_worlds"] == worker["cpu_readback_views"] == retained["constructed_gpu_worlds"] == closure["constructed_gpu_worlds"] == 18
        and worker["stepped_cpu_worlds"] == 0 and worker["controller_sessions_closed"] is True, "Native lifecycle denominator")
    require(retained["controller_rows"] == closure["controller_rows"] == 17280
        and retained["internal_rows"] == closure["internal_rows"] == 86400
        and retained["physical_provider_influence_rows"] == closure["physical_provider_influence_rows"] == retained["solver_nonzero_rows"]
        and retained["resolved_nonzero_rows"] == closure["resolved_nonzero_rows"]
        and retained["development_worlds"] == closure["development_worlds"] == 18
        and retained["calibration_worlds"] == closure["calibration_worlds"] == 0
        and retained["evaluation_worlds"] == closure["evaluation_worlds"]
        == retained["training_worlds"] == closure["training_worlds"] == 0, "Completed population")
    require(retained["native_influence_evaluated"] is True
        and all(retained[key] is False for key in ["provider_promotion_authority",
            "statistical_superiority_authority", "noninferiority_authority"]), "Reader authority")
    require(closure["native_worker_wall_s"] == worker["total_wall_s"]
        and closure["independent_audit_wall_s"] == receipt["audit_wall_s"], "Timing identity")
    require(closure["complete_zero_world_gate"] == GATE_COUNTS and sum(GATE_COUNTS.values()) == 100, "Safety gate accounting")
    for directory, count in GATE_COUNTS.items():
        log = (attempt / directory / "stderr.log").read_text()
        require(re.findall(r"(?m)^Ran ([0-9]+) tests? in ", log) == [str(count)]
            and log.strip().endswith("OK"), "Safety gate terminal/count")
    preflight = json.loads((attempt / "runtime-gate/stdout.log").read_text())
    require(preflight == receipt["preflight"] and preflight["ok"] is True
        and preflight["world_build_count"] == preflight["solver_steps"] == 0
        and preflight["planned_gpu_worlds"] == preflight["development_worlds"] == 18
        and preflight["calibration_worlds"] == 0
        and preflight["planned_controller_rows"] == 17280 and preflight["planned_internal_rows"] == 86400
        and preflight["evaluation_worlds"] == preflight["training_worlds"] == 0, "Runtime gate join")
    for plan, trial, checked in zip(plans, worker["trials"], retained["trials"], strict=True):
        folder = attempt / "physical" / plan["trial_id"]
        require(all(trial[k] == value and checked[k] == value for k,value in plan.items())
            and json.loads((folder / "plan.json").read_text()) == plan
            and json.loads((folder / "result.json").read_text()) == trial
            and trial["completed"] is True, "Trial identity")
        for name in ["controller", "trace", "timing"]:
            require(sha(folder / (name + ".jsonl")) == trial["hashes"][name], "Raw stream binding")
        require(trial["outer_rows"] == checked["controller_rows"] == 5760
            and trial["internal_rows"] == checked["internal_rows"] == 28800
            and timing_summary(list(read_jsonl(folder / "timing.jsonl")), c) == checked["timings"], "Trial population/timing")
        require(list(checked["providers"]) == plan["mode_order"]
            and set(checked["comparison"]["arms"]) == set(c["modes"])
            and len(checked["metrics"]) == 6, "Complete comparison arms")
        for mode, state in checked["providers"].items():
            memory = state["final_memory"]
            require(state["rows"] == sum(state["statuses"].values()) == 960
                and memory["weights_mutated"] is False
                and learner.digest(core, memory["opaque_state"]) == memory["opaque_state_sha256"], "Provider memory/counts")
            require(state["completed_feedback_updates"] == memory["opaque_state"].get("updates", 0)
                and state["uncredited_active_window"] == memory["opaque_state"].get("active"), "Feedback endpoint accounting")
            if mode in ["baseline", "disabled", "frozen", "shuffled"]:
                require(state["completed_feedback_updates"] == 0, "Non-episodic feedback")
            if mode != "baseline":
                config = contextual.contract()
                contextual.validate_opaque(memory["opaque_state"],960,dict(seed=plan["seed"]),model,mode,
                    model.plan(),config,learner.digest(core,config))
            require(0 <= state.get("context_nonzero_offset_selections",0)
                <= state.get("context_supported_action_selections",0) <= state["new_action_selections"],
                "Context lookup denominator")
    require(retained["group_comparisons"] == [dict(group_id=t["group_id"], **t["comparison"]) for t in retained["trials"]],
        "Group comparison join")
    require(group_summary(retained) == closure["group_summary"]
        and finite_outcomes(retained) == closure["finite_outcomes"], "Influence or memory summary changed")
    require(sum(s["resolved_nonzero_rows"] for t in retained["trials"] for s in t["providers"].values()) == retained["resolved_nonzero_rows"]
        and sum(len(a["exposure"]["solver"]["nonzero_outer_steps"]) for t in retained["trials"]
            for a in t["comparison"]["arms"].values()) == retained["solver_nonzero_rows"], "Actual influence denominator")
    if replay:
        require(audit(attempt / "physical", core_path, baseline_path) == retained, "Repeated complete reader differs")
    return dict(ok=True, artifact_count=len(indexed), source_binding_count=sources,
        runtime_binding_count=closure["runtime_binding_count"], candidate_evidence_binding_count=2,
        design_diagnostic_binding_count=1,
        original_independent_reader_controller_rows=17280, original_independent_reader_internal_rows=86400,
        timing_summary_recomputed=True, full_controller_replay_performed=replay, world_build_count=0,
        model_sha256=model.sha256, physical_provider_influence_rows=retained["physical_provider_influence_rows"],
        finite_outcomes=finite_outcomes(retained), native_influence_evaluated=True,
        provider_promotion_authority=False, statistical_superiority_authority=False,
        noninferiority_authority=False, **{k:False for k in FLAGS})



if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("closure", type=Path)
    parser.add_argument("--evidence-root", type=Path, required=True)
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--replay", action="store_true")
    args = parser.parse_args()
    print(json.dumps(verify_record(args.closure, args.evidence_root, args.core, args.baseline_core, replay=args.replay), indent=2))
