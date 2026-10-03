"""Audit the retained QSDK-R24D24 context/observer positive closure."""

from __future__ import annotations

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    load,
    loads,
    require,
    sha256,
    source_bytes,
    verify_retained_commit,
    verify_retained_file_manifest,
    verify_source_receipt_manifest,
)


CLOSURE = ROOT / "sdk/recovery/r24d24_recovery_context_contact_observer_positive_closure_v1.json"
SOURCE = "b542b9ad3cbdc09772c3ac867bdf519e9cee21d8"
ROUTE = "sporespore_mujoco_qsdk_r24_recovery_morphology_development_v1"
MORPHOLOGY = "sha256:926551af3a72eb1fd1f3b71bfb103587a0b906a116775551a2463792e2c160f9"
CONTEXT = "sporespore_recovery_morphology_context_v1"
OBSERVER = "mujoco_contact_midpoint_normal_distance_reconstructed_torso_surface_v1"


def all_zero(mapping: dict[str, object]) -> bool:
    return all(value == 0 for value in mapping.values())


def audit() -> None:
    closure = load(CLOSURE)
    exact(closure["schema_version"], "sporespore_qsdk_r24d24_recovery_context_contact_observer_positive_closure_v1", "SCHEMA")
    exact(closure["gate_id"], "QSDK-R24D24", "GATE")
    exact(closure["question_class"], "development", "QUESTION")
    exact(closure["ledger_scope"], {"subsystem": "recovery", "engine_scope": ["mujoco_native"], "authority_mode": "development_ghost_closure", "question_class": "development"}, "LEDGER")
    exact(closure["source_commit"], SOURCE, "SOURCE")
    verify_retained_commit(ROOT, SOURCE, closure["source_parent_commit"])
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE), closure["source_tree"], "TREE")
    contract_raw = source_bytes(ROOT, SOURCE, closure["contract_path"])
    exact(len(contract_raw), closure["contract_byte_length"], "CONTRACT_LENGTH")
    exact(sha256(contract_raw), closure["contract_raw_sha256"], "CONTRACT_HASH")
    contract = loads(contract_raw)
    exact(contract["question_class"], "development", "CONTRACT_QUESTION")
    exact(contract["threshold_authority"]["new_behavior_threshold_count"], 0, "THRESHOLDS")
    exact(contract["threshold_authority"]["new_margin_count"], 0, "MARGINS")
    require(bool(contract["threshold_authority"]["adequacy_argument"].strip()), "THRESHOLD_ADEQUACY")
    require(bool(contract["selected_development_cell"]["selection_provenance"].strip()), "CELL_PROVENANCE")
    require(bool(contract["selected_development_cell"]["selection_adequacy"].strip()), "CELL_ADEQUACY")
    exact(contract["contact_observer_authority"]["reconstruction_formula"], "geom0_surface = pos - dist * normal / 2; geom1_surface = pos + dist * normal / 2", "OBSERVER_FORMULA")
    exact(contract["contact_observer_authority"]["new_empirical_threshold_count"], 0, "OBSERVER_THRESHOLDS")

    qualification = closure["qualification"]
    qualification_root = Path(qualification["evidence_root"])
    verify_retained_file_manifest(qualification_root, qualification["retained_artifacts"])
    receipt = load(qualification_root / qualification["receipt_path"])
    exact(sha256((qualification_root / qualification["receipt_path"]).read_bytes()), qualification["receipt_raw_sha256"], "QUALIFICATION_HASH")
    exact(receipt["ok"], True, "QUALIFICATION_OK")
    exact(receipt["source_commit"], SOURCE, "QUALIFICATION_SOURCE")
    exact([item["path"] for item in receipt["source_manifest"]], contract["source_inventory"], "SOURCE_INVENTORY")
    exact(len(receipt["source_manifest"]), 40, "SOURCE_COUNT")
    verify_source_receipt_manifest(ROOT, SOURCE, receipt["source_manifest"])
    preflight = receipt["production_preflight"]
    exact(preflight["negative_control_count"], 18, "NEGATIVE_COUNT")
    exact(preflight["negative_controls_passed"], 18, "NEGATIVE_PASS")
    exact(preflight["v2_public_entrypoint_count"], 5, "V2_COUNT")
    exact(preflight["v1_unknown_context_field_rejected"], True, "V1_REFUSAL")
    exact(preflight["v2_context_mutation_rejected"], True, "V2_MUTATION")
    require(all(preflight["v2_malformed_dispatch_controls"].values()), "V2_DISPATCH")
    observer = preflight["contact_observer"]
    exact(observer["rule_id"], OBSERVER, "OBSERVER_RULE")
    exact(observer["control_count"], 7, "OBSERVER_COUNT")
    exact(observer["controls_passed"], 7, "OBSERVER_PASS")
    require(all(observer["checks"].values()), "OBSERVER_CHECKS")
    for key in ("model_construction_count", "world_attempt_count", "world_build_count", "solver_step_count", "held_out_cell_access_count", "held_out_selector_invocation_count"):
        exact(receipt[key], 0, f"QUALIFICATION_{key.upper()}")
    exact(receipt["physics_state_modified"], False, "QUALIFICATION_PHYSICS")
    exact(receipt["operation_lock_released"], True, "QUALIFICATION_LOCK")

    attempt = closure["physical_attempt"]
    attempt_root = Path(attempt["evidence_root"])
    verify_retained_file_manifest(attempt_root, closure["retained_physical_artifacts"])
    require(not (attempt_root / "invalid_result.json").exists(), "INVALID_RESULT")
    summary = load(attempt_root / "paired_summary.json")
    manifest = load(attempt_root / "manifest.json")
    supervisor = load(attempt_root / "supervisor_completion.json")
    envelope = load(attempt_root / "paired_full_result.json")
    exact(summary["source_commit"], SOURCE, "SUMMARY_SOURCE")
    exact(summary["route_id"], ROUTE, "SUMMARY_ROUTE")
    exact(summary["execution_valid"], True, "SUMMARY_VALID")
    exact(summary["decision_positive"], True, "SUMMARY_POSITIVE")
    exact(len(summary["route_checks"]), 32, "ROUTE_CHECK_COUNT")
    exact(len(summary["target_checks"]), 8, "TARGET_CHECK_COUNT")
    require(all(summary["route_checks"].values()), "ROUTE_CHECKS")
    require(all(summary["target_checks"].values()), "TARGET_CHECKS")
    exact(summary["held_out_cell_access_count"], 0, "SUMMARY_HELDOUT")
    exact(summary["held_out_selector_invocation_count"], 0, "SUMMARY_SELECTOR")
    exact(summary["prone_to_standing_claimed"], False, "SUMMARY_CLAIM")
    exact(manifest["execution_valid"], True, "MANIFEST_VALID")
    exact(manifest["decision_positive"], True, "MANIFEST_POSITIVE")
    exact(manifest["complete_trace_retained"], True, "MANIFEST_FULL")
    exact(manifest["compact_projection_retained"], True, "MANIFEST_COMPACT")
    exact(supervisor["worker_exit_code"], 0, "WORKER_EXIT")
    exact(supervisor["caught_error"], None, "SUPERVISOR_ERROR")
    exact(supervisor["route_coverage_passed"], True, "SUPERVISOR_ROUTE")
    exact(supervisor["operation_lock_released"], True, "PHYSICAL_LOCK")

    exact(envelope["source_commit"], SOURCE, "ENVELOPE_SOURCE")
    exact(envelope["contract_raw_sha256"], closure["contract_raw_sha256"], "ENVELOPE_CONTRACT")
    exact(envelope["qualification_receipt_raw_sha256"], qualification["receipt_raw_sha256"], "ENVELOPE_QUALIFICATION")
    result = envelope["result"]
    for key, expected in (("model_construction_count", 2), ("world_attempt_count", 2), ("world_build_count", 2), ("outer_step_count", 4), ("native_solver_step_count", 20)):
        exact(result[key], expected, f"RESULT_{key.upper()}")
    exact(result["initializer_identity_matched"], True, "INITIALIZER_IDENTITY")
    exact(result["native_runtime_observation_collection_executed"], True, "COLLECTION")
    exact(result["portable_evaluation_request_schema"], "sporespore_recovery_evaluation_request_v2", "EVALUATION_SCHEMA")
    exact(result["prone_to_standing_claimed"], False, "RESULT_CLAIM")
    candidate, matched = result["candidate"], result["matched_zero_command"]
    exact(candidate["initializer_manifest_sha256"], matched["initializer_manifest_sha256"], "PAIRED_INITIALIZER")
    exact(candidate["canonical_pre_step_state_sha256"], matched["canonical_pre_step_state_sha256"], "PAIRED_PRESTATE")
    for label, arm in (("CANDIDATE", candidate), ("MATCHED", matched)):
        exact(arm["portable_recovery_context_bound"], True, f"{label}_CONTEXT_BOUND")
        exact(arm["portable_recovery_morphology_context"]["schema_version"], CONTEXT, f"{label}_CONTEXT_SCHEMA")
        exact(arm["portable_recovery_morphology_context"]["recovery_morphology_spec_sha256"], MORPHOLOGY, f"{label}_CONTEXT_ID")
        trace = arm["portable_request_trace"]
        exact(trace["initialize_request_schema"], "sporespore_recovery_initialize_request_v2", f"{label}_INITIALIZE_SCHEMA")
        exact(trace["collection_request_schemas"], ["sporespore_recovery_native_collection_request_v2"] * 2, f"{label}_COLLECT_SCHEMAS")
        exact(trace["step_request_schemas"], ["sporespore_recovery_step_request_v2"] * 2, f"{label}_STEP_SCHEMAS")
        exact(trace["control_request_schemas"], ["sporespore_recovery_control_request_v2"] * 2, f"{label}_CONTROL_SCHEMAS")
        for key in ("observations", "native_receipts", "collector_receipts", "portable_step_receipts"):
            exact(len(arm[key]), 2, f"{label}_{key.upper()}")
        require(all(all_zero(item["external_interventions"]) for item in arm["observations"]), f"{label}_INTERVENTIONS")
        require(all(item["native_step"]["route_id"] == ROUTE and item["application"]["route_id"] == ROUTE for item in arm["native_receipts"]), f"{label}_ROUTE_BINDING")
        require(all(item["application"]["no_actuation_requested"] is True for item in arm["native_receipts"]), f"{label}_ACTUATION")
        require(all(all(value == 0 for value in item["application"]["ordered_maximum_absolute_force_nm"]) for item in arm["native_receipts"]), f"{label}_FORCES")
        require(all(item["support_status"] == "supported_exact" and item["supplied_native_post_step_observation_validated"] is True for item in arm["collector_receipts"]), f"{label}_COLLECTORS")
        steps = arm["portable_step_receipts"]
        exact([item["classification"]["pose_class"] for item in steps], ["ventral_prone", "ventral_prone"], f"{label}_POSE")
        exact([item["classification"]["joint_limits_respected"] for item in steps], [True, True], f"{label}_LIMITS")
        exact([item["classification"]["torso_ventral_contact"] for item in steps], [True, True], f"{label}_CONTACT")
        exact([item["memory"]["prone_confirm_steps_observed"] for item in steps], [1, 2], f"{label}_CONFIRM")
        exact([item["controller_command_emitted"] for item in steps], [False, False], f"{label}_COMMAND")
        for observation in arm["observations"]:
            torso = [item for item in observation["ordered_body_clearance_observations"] if item["body_id"] == "torso"]
            exact(len(torso), 1, f"{label}_TORSO_COUNT")
            exact(torso[0]["classification_rule_id"], OBSERVER, f"{label}_OBSERVER")
            exact(torso[0]["ventral_surface_contact"], True, f"{label}_VENTRAL")
    exact([item["applied_actuation"]["zero_command"] for item in matched["observations"]], [True, True], "MATCHED_ZERO")
    evaluation = result["evaluation"]
    exact(evaluation["physical_development_trace_valid"], True, "EVALUATION_VALID")
    exact(evaluation["verdict"], "physical_development_incomplete", "EVALUATION_VERDICT")
    exact(evaluation["physical_result"], False, "EVALUATION_RESULT")

    decision = closure["decision"]
    exact(decision["r24d24_result"], "complete_execution_valid_native_context_contact_observer_positive_behavior_incomplete_and_retained", "DECISION")
    exact(decision["portable_recovery_context_compatibility_proven"], True, "DECISION_CONTEXT")
    exact(decision["native_contact_surface_observer_proven_for_declared_two_step_cell"], True, "DECISION_OBSERVER")
    exact(decision["first_active_command_covered"], False, "DECISION_COMMAND")
    exact(decision["sdk1_completed_steps"], 11, "SDK1_COUNT")
    exact(closure["next_boundary"]["gate_id"], "QSDK-R24D25", "NEXT_GATE")
    exact(closure["next_boundary"]["held_out_cells_remain_sealed"], True, "NEXT_HELDOUT")
    for key in ("first_active_command_covered", "controller_physical_viability_proven", "prone_to_standing_claimed", "repeatability_rate_claimed", "population_claimed", "held_out_validation_claimed", "cross_engine_recovery_claimed", "cross_engine_equivalence_claimed", "sdk1_milestone_advanced", "physical_acceptance_authority", "release_authority"):
        exact(closure["claim_boundary"][key], False, f"CLAIM_{key.upper()}")
    print("QSDK_R24D24_CONTEXT_OBSERVER_CLOSURE_PASS decision=positive models=2 worlds=2 outer_steps=4 solver_steps=20 route_checks=32/32 target_checks=8/8 heldout_access=0 next=QSDK-R24D25")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError) as error:
        print(f"QSDK_R24D24_CONTEXT_OBSERVER_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
