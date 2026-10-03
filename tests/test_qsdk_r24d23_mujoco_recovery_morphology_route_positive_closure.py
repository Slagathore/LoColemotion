"""Audit the retained QSDK-R24D23 route-positive development closure."""

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


CLOSURE = ROOT / "sdk/recovery/r24d23_mujoco_recovery_morphology_route_positive_closure_v1.json"
SOURCE = "bbcae8829b93fb402bea7eb99449a94a469abb7b"
ROUTE = "sporespore_mujoco_qsdk_r24_recovery_morphology_development_v1"
MORPHOLOGY = "sha256:926551af3a72eb1fd1f3b71bfb103587a0b906a116775551a2463792e2c160f9"


def audit() -> None:
    closure = load(CLOSURE)
    exact(closure["schema_version"], "sporespore_qsdk_r24d23_mujoco_recovery_morphology_route_positive_closure_v1", "SCHEMA")
    exact(closure["gate_id"], "QSDK-R24D23", "GATE")
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

    qualification = closure["qualification"]
    qualification_root = Path(qualification["evidence_root"])
    verify_retained_file_manifest(qualification_root, qualification["retained_artifacts"])
    receipt = load(qualification_root / qualification["receipt_path"])
    exact(sha256((qualification_root / qualification["receipt_path"]).read_bytes()), qualification["receipt_raw_sha256"], "QUALIFICATION_HASH")
    exact(receipt["ok"], True, "QUALIFICATION_OK")
    exact(receipt["source_commit"], SOURCE, "QUALIFICATION_SOURCE")
    exact([item["path"] for item in receipt["source_manifest"]], contract["source_inventory"], "SOURCE_INVENTORY")
    exact(len(receipt["source_manifest"]), 43, "SOURCE_COUNT")
    verify_source_receipt_manifest(ROOT, SOURCE, receipt["source_manifest"])
    preflight = receipt["production_preflight"]
    exact(preflight["negative_control_count"], 4, "NEGATIVE_COUNT")
    exact(preflight["negative_controls_passed"], 4, "NEGATIVE_PASS")
    exact(preflight["morphology_mapping"]["ordered_joint_mapping_count"], 8, "MAPPING_COUNT")
    exact(preflight["recovery_morphology_spec_sha256"], MORPHOLOGY, "PREFLIGHT_MORPHOLOGY")
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
    result = envelope["result"]
    exact(summary["source_commit"], SOURCE, "SUMMARY_SOURCE")
    exact(summary["route_id"], ROUTE, "SUMMARY_ROUTE")
    exact(summary["route_coverage_passed"], True, "SUMMARY_COVERAGE")
    require(all(summary["checks"].values()), "SUMMARY_CHECKS")
    exact(len(summary["checks"]), 15, "SUMMARY_CHECK_COUNT")
    exact(summary["evaluation_verdict"], "physical_development_incomplete", "SUMMARY_VERDICT")
    exact(summary["physical_development_trace_valid"], True, "SUMMARY_VALID")
    exact(summary["physical_result_observed"], False, "SUMMARY_RESULT")
    exact(manifest["route_coverage_passed"], True, "MANIFEST_COVERAGE")
    exact(manifest["complete_trace_retained"], True, "MANIFEST_FULL")
    exact(manifest["compact_projection_retained"], True, "MANIFEST_COMPACT")
    exact(supervisor["worker_exit_code"], 0, "WORKER_EXIT")
    exact(supervisor["caught_error"], None, "SUPERVISOR_ERROR")
    exact(supervisor["operation_lock_released"], True, "PHYSICAL_LOCK")

    exact(result["route_id"], ROUTE, "RESULT_ROUTE")
    for key, expected in (("model_construction_count", 2), ("world_attempt_count", 2), ("world_build_count", 2), ("outer_step_count", 4), ("native_solver_step_count", 20)):
        exact(result[key], expected, f"RESULT_{key.upper()}")
    exact(result["initializer_identity_matched"], True, "INITIALIZER_IDENTITY")
    exact(result["native_runtime_observation_collection_executed"], True, "COLLECTION")
    exact(result["prone_to_standing_claimed"], False, "RESULT_CLAIM")
    candidate, matched = result["candidate"], result["matched_zero_command"]
    exact(candidate["initializer_manifest_sha256"], matched["initializer_manifest_sha256"], "PAIRED_INITIALIZER")
    exact(candidate["canonical_pre_step_state_sha256"], matched["canonical_pre_step_state_sha256"], "PAIRED_PRESTATE")
    for label, arm in (("CANDIDATE", candidate), ("MATCHED", matched)):
        exact(arm["native_recovery_morphology_readback"]["ordered_joint_readback_count"], 8, f"{label}_READBACK_COUNT")
        require(all(item["matches_zero_world_mapping"] for item in arm["native_recovery_morphology_readback"]["ordered_joint_readbacks"]), f"{label}_READBACKS")
        exact(arm["initializer_manifest"]["recovery_morphology_spec_sha256"], MORPHOLOGY, f"{label}_MORPHOLOGY")
        exact(arm["initializer_manifest"]["native_joint_position_readback_matches"], True, f"{label}_INITIALIZER")
        for key in ("observations", "native_receipts", "collector_receipts", "portable_step_receipts"):
            exact(len(arm[key]), 2, f"{label}_{key.upper()}")
        require(all(all(value == 0 for value in item["external_interventions"].values()) for item in arm["observations"]), f"{label}_INTERVENTIONS")
        require(all(item["native_step"]["route_id"] == ROUTE and item["application"]["route_id"] == ROUTE for item in arm["native_receipts"]), f"{label}_ROUTE_BINDING")
        require(all(item["application"]["no_actuation_requested"] is True for item in arm["native_receipts"]), f"{label}_ACTUATION")
        require(all(item["support_status"] == "supported_exact" and item["supplied_native_post_step_observation_validated"] is True for item in arm["collector_receipts"]), f"{label}_COLLECTORS")
        require(all(item["support_status"] == "supported_exact" for item in arm["portable_step_receipts"]), f"{label}_PORTABLE")
    candidate_class = [item["classification"] for item in candidate["portable_step_receipts"]]
    exact(candidate_class, [item["classification"] for item in matched["portable_step_receipts"]], "PAIRED_CLASSIFICATIONS")
    exact([item["pose_class"] for item in candidate_class], ["ventral_prone", "transitional"], "POSE_SEQUENCE")
    exact([item["joint_limits_respected"] for item in candidate_class], [False, False], "JOINT_LIMIT_SEQUENCE")
    exact([item["torso_ventral_contact"] for item in candidate_class], [True, False], "VENTRAL_SEQUENCE")
    exact([item["minimum_nonfoot_clearance_m"] for item in candidate_class], [-0.00009774084991721887, -0.0001857972797272081], "CLEARANCE_SEQUENCE")
    exact([item["state"]["base_pose_world"]["position_m"]["y"] for item in candidate["observations"]], [0.05990278934755676, 0.05981669113466014], "TORSO_SEQUENCE")
    evaluation = result["evaluation"]
    exact(evaluation["physical_development_trace_valid"], True, "EVALUATION_VALID")
    exact(evaluation["verdict"], "physical_development_incomplete", "EVALUATION_VERDICT")
    exact(evaluation["physical_result"], False, "EVALUATION_RESULT")

    decision = closure["decision"]
    exact(decision["r24d23_result"], "complete_execution_valid_mujoco_recovery_morphology_route_positive_behavior_incomplete_and_retained", "DECISION")
    exact(decision["native_recovery_morphology_mapping_proven"], True, "DECISION_MAPPING")
    exact(decision["native_recovery_initializer_proven"], True, "DECISION_INITIALIZER")
    exact(decision["portable_recovery_context_compatibility_proven"], False, "DECISION_CONTEXT")
    exact(decision["sdk1_completed_steps"], 11, "SDK1_COUNT")
    exact(closure["next_boundary"]["gate_id"], "QSDK-R24D24", "NEXT_GATE")
    exact(closure["next_boundary"]["held_out_cells_remain_sealed"], True, "NEXT_HELDOUT")
    for key in ("controller_command_route_covered", "portable_recovery_context_compatibility_proven", "controller_physical_viability_proven", "prone_to_standing_claimed", "repeatability_rate_claimed", "population_claimed", "held_out_validation_claimed", "cross_engine_recovery_claimed", "cross_engine_equivalence_claimed", "physical_acceptance_authority", "release_authority"):
        exact(closure["claim_boundary"][key], False, f"CLAIM_{key.upper()}")
    print("QSDK_R24D23_ROUTE_CLOSURE_PASS route=positive behavior=incomplete models=2 worlds=2 outer_steps=4 solver_steps=20 invariants=15/15 heldout_access=0 next=QSDK-R24D24")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError) as error:
        print(f"QSDK_R24D23_ROUTE_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
