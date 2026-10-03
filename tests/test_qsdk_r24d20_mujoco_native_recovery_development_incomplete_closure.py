"""Verify the retained QSDK-R24D20 valid incomplete development closure."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
CLOSURE_RELATIVE = Path(
    "sdk/recovery/r24d20_mujoco_native_recovery_development_incomplete_closure_v1.json"
)
SOURCE_COMMIT = "0d8fe6391ab9e9f2c9f6fafb2cdb24d444011e62"


class ClosureError(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ClosureError(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}: expected={expected!r} actual={actual!r}")


def _reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        require(key not in value, f"DUPLICATE_KEY:{key}")
        value[key] = item
    return value


def load(path: Path) -> dict[str, Any]:
    value = json.loads(
        path.read_text(encoding="utf-8"),
        object_pairs_hook=_reject_duplicates,
    )
    require(isinstance(value, dict), f"JSON_ROOT:{path}")
    assert isinstance(value, dict)
    return value


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def audit() -> None:
    closure = load(REPO_ROOT / CLOSURE_RELATIVE)
    exact(
        closure["schema_version"],
        "sporespore_qsdk_r24d20_mujoco_native_recovery_development_incomplete_closure_v1",
        "SCHEMA",
    )
    exact(closure["gate_id"], "QSDK-R24D20", "GATE")
    exact(closure["question_class"], "development", "QUESTION_CLASS")
    exact(closure["source_commit"], SOURCE_COMMIT, "SOURCE_COMMIT")
    subprocess.run(
        ["git", "cat-file", "-e", f"{SOURCE_COMMIT}^{{commit}}"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
    )
    contract_path = REPO_ROOT / closure["contract_path"]
    exact(raw_sha256(contract_path), closure["contract_raw_sha256"], "CONTRACT_DIGEST")

    qualification = closure["qualification"]
    qualification_root = Path(qualification["evidence_root"])
    qualification_receipt = qualification_root / qualification["receipt_path"]
    require(qualification_receipt.is_file(), "QUALIFICATION_RECEIPT_MISSING")
    exact(
        raw_sha256(qualification_receipt),
        qualification["receipt_raw_sha256"],
        "QUALIFICATION_DIGEST",
    )
    qualification_value = load(qualification_receipt)
    exact(qualification_value["ok"], True, "QUALIFICATION_OK")
    exact(qualification_value["mode"], "qualification", "QUALIFICATION_MODE")
    exact(qualification_value["source_commit"], SOURCE_COMMIT, "QUALIFICATION_SOURCE")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        exact(qualification_value[key], 0, f"QUALIFICATION_{key.upper()}")
    exact(qualification_value["physics_state_modified"], False, "QUALIFICATION_PHYSICS")
    exact(qualification_value["held_out_cell_access_count"], 0, "QUALIFICATION_HELDOUT")

    attempt = closure["physical_attempt"]
    attempt_root = Path(attempt["evidence_root"])
    require(attempt_root.is_dir(), "ATTEMPT_ROOT_MISSING")
    for artifact in closure["retained_artifacts"]:
        path = attempt_root / artifact["path"]
        require(path.is_file(), f"ARTIFACT_MISSING:{artifact['path']}")
        exact(path.stat().st_size, artifact["byte_length"], "ARTIFACT_LENGTH")
        exact(raw_sha256(path), artifact["raw_sha256"], "ARTIFACT_DIGEST")
    require(not (attempt_root / "invalid_result.json").exists(), "INVALID_RESULT_PRESENT")

    summary = load(attempt_root / "paired_summary.json")
    manifest = load(attempt_root / "manifest.json")
    supervisor = load(attempt_root / "supervisor_completion.json")
    envelope = load(attempt_root / "paired_full_result.json")
    result = envelope["result"]
    exact(summary["source_commit"], SOURCE_COMMIT, "SUMMARY_SOURCE")
    exact(summary["physical_development_trace_valid"], True, "SUMMARY_TRACE_VALID")
    exact(summary["evaluation_verdict"], "physical_development_incomplete", "SUMMARY_VERDICT")
    exact(summary["physical_result"], False, "SUMMARY_PHYSICAL_RESULT")
    exact(summary["route_coverage_passed"], False, "SUMMARY_COVERAGE")
    exact(summary["candidate_active_command_outer_step_count"], 0, "SUMMARY_ACTIVE")
    exact(summary["matched_zero_active_command_outer_step_count"], 0, "SUMMARY_ZERO_ACTIVE")
    exact(summary["candidate_final_phase"], "confirm_prone", "SUMMARY_CANDIDATE_PHASE")
    exact(summary["matched_zero_final_phase"], "confirm_prone", "SUMMARY_ZERO_PHASE")
    false_checks = sorted(key for key, value in summary["checks"].items() if not value)
    exact(false_checks, ["candidate_active_command_covered"], "SUMMARY_FALSE_CHECKS")
    exact(summary["held_out_cell_access_count"], 0, "SUMMARY_HELDOUT")
    exact(summary["held_out_selector_invocation_count"], 0, "SUMMARY_SELECTOR")
    exact(summary["prone_to_standing_claimed"], False, "SUMMARY_CLAIM")

    exact(manifest["route_coverage_passed"], False, "MANIFEST_COVERAGE")
    exact(manifest["complete_trace_retained"], True, "MANIFEST_FULL")
    exact(manifest["compact_projection_retained"], True, "MANIFEST_COMPACT")
    manifest_by_path = {item["path"]: item for item in manifest["artifacts"]}
    exact(
        manifest_by_path["paired_full_result.json"]["raw_sha256"],
        raw_sha256(attempt_root / "paired_full_result.json"),
        "MANIFEST_FULL_DIGEST",
    )
    exact(
        manifest_by_path["paired_summary.json"]["raw_sha256"],
        raw_sha256(attempt_root / "paired_summary.json"),
        "MANIFEST_SUMMARY_DIGEST",
    )
    exact(supervisor["worker_exit_code"], 3, "SUPERVISOR_EXIT")
    exact(supervisor["caught_error"], None, "SUPERVISOR_ERROR")
    exact(supervisor["invalid_or_incomplete_retained"], True, "SUPERVISOR_RETAINED")
    exact(supervisor["operation_lock_released"], True, "SUPERVISOR_LOCK")

    exact(result["route_id"], summary["route_id"], "RESULT_ROUTE")
    exact(result["question_class"], "development", "RESULT_QUESTION")
    exact(result["model_construction_count"], 2, "RESULT_MODELS")
    exact(result["world_attempt_count"], 2, "RESULT_ATTEMPTS")
    exact(result["world_build_count"], 2, "RESULT_BUILDS")
    exact(result["outer_step_count"], 28, "RESULT_OUTER_STEPS")
    exact(result["native_solver_step_count"], 140, "RESULT_SOLVER_STEPS")
    exact(result["physics_state_modified"], True, "RESULT_PHYSICS")
    exact(result["native_runtime_observation_collection_executed"], True, "RESULT_COLLECTION")
    exact(result["initializer_identity_matched"], True, "RESULT_INITIALIZER_MATCH")
    exact(result["held_out_cell_access_count"] if "held_out_cell_access_count" in result else 0, 0, "RESULT_HELDOUT")
    exact(result["prone_to_standing_claimed"], False, "RESULT_CLAIM")

    candidate = result["candidate"]
    matched = result["matched_zero_command"]
    exact(candidate["initializer_manifest_sha256"], matched["initializer_manifest_sha256"], "INIT_SHA")
    exact(candidate["canonical_pre_step_state_sha256"], matched["canonical_pre_step_state_sha256"], "PRESTATE_SHA")
    for label, arm in (("CANDIDATE", candidate), ("MATCHED", matched)):
        exact(arm["world_attempt_count"], 1, f"{label}_ATTEMPT")
        exact(arm["world_build_count"], 1, f"{label}_BUILD")
        exact(arm["outer_step_count"], 14, f"{label}_OUTER")
        exact(arm["native_solver_step_count"], 70, f"{label}_SOLVER")
        exact(arm["physics_state_modified"], True, f"{label}_PHYSICS")
        exact(arm["final_phase"], "confirm_prone", f"{label}_PHASE")
        exact(len(arm["observations"]), 14, f"{label}_OBSERVATIONS")
        exact(len(arm["native_receipts"]), 14, f"{label}_NATIVE_RECEIPTS")
        exact(len(arm["portable_step_receipts"]), 14, f"{label}_PORTABLE_RECEIPTS")
        for step in arm["native_receipts"]:
            application = step["application"]
            exact(application["no_actuation_requested"], True, f"{label}_NO_ACTUATION")
            exact(
                application["ordered_signed_applied_impulse_nms"],
                [0.0] * 8,
                f"{label}_IMPULSE",
            )
        for step in arm["portable_step_receipts"]:
            exact(step["controller_command_emitted"], False, f"{label}_COMMAND")

    classifications_candidate = [
        step["classification"] for step in candidate["portable_step_receipts"]
    ]
    classifications_matched = [
        step["classification"] for step in matched["portable_step_receipts"]
    ]
    exact(classifications_candidate, classifications_matched, "PAIRED_CLASSIFICATIONS")
    entry_prone = [item["entry_prone_gate"] for item in classifications_candidate]
    exact(entry_prone, [True] + [False] * 13, "ENTRY_PRONE_SEQUENCE")
    prone_counts = [
        step["memory"]["prone_confirm_steps_observed"]
        for step in candidate["portable_step_receipts"]
    ]
    exact(prone_counts, [1] + [0] * 13, "PRONE_COUNT_SEQUENCE")

    initializer = candidate["initializer_manifest"]
    exact(initializer["known_initial_overlap_is_a_development_observation_not_hidden"], True, "KNOWN_OVERLAP")
    exact(candidate["canonical_pre_step_state"]["active_contact_count_after_mj_forward"], 20, "PRESTEP_CONTACTS")
    first_observation = candidate["observations"][0]
    second_observation = candidate["observations"][1]
    final_observation = candidate["observations"][-1]
    first_classification = classifications_candidate[0]
    final_classification = classifications_candidate[-1]
    exact(first_classification["pose_class"], "ventral_prone", "FIRST_POSE")
    exact(first_classification["minimum_nonfoot_clearance_m"], -0.16729235239294288, "FIRST_CLEARANCE")
    exact(first_classification["maximum_nonfoot_contact_impulse_ns"], 3.535369530556827, "FIRST_IMPULSE")
    exact(first_classification["minimum_distal_bearing_impulse_ns"], 0.0, "FIRST_FOOT_IMPULSE")
    exact(first_classification["terminal_linear_speed_m_s"], 1.8972562375838928, "FIRST_SPEED")
    exact(first_classification["energy_balance_residual_j"], 12.326742378823072, "FIRST_ENERGY")
    exact(first_observation["state"]["base_pose_world"]["position_m"]["y"], 0.06813493566713764, "FIRST_TORSO")
    exact(first_observation["center_of_mass"]["position_world_m"]["y"], 0.017888451104396103, "FIRST_COM")
    exact(second_observation["state"]["base_pose_world"]["position_m"]["y"], 0.08981328222855448, "SECOND_TORSO")
    exact(final_classification["pose_class"], "raised_body", "FINAL_POSE")
    exact(final_classification["minimum_nonfoot_clearance_m"], 0.12313811195059698, "FINAL_CLEARANCE")
    exact(final_classification["terminal_linear_speed_m_s"], 2.156320021396139, "FINAL_SPEED")
    exact(final_classification["energy_balance_residual_j"], 24.162847629578216, "FINAL_ENERGY")
    exact(final_observation["state"]["base_pose_world"]["position_m"]["y"], 0.3528143402277675, "FINAL_TORSO")
    exact(final_observation["center_of_mass"]["position_world_m"]["y"], 0.3012427910288037, "FINAL_COM")

    evaluation = result["evaluation"]
    exact(evaluation["physical_development_trace_valid"], True, "EVALUATION_VALID")
    exact(evaluation["verdict"], "physical_development_incomplete", "EVALUATION_VERDICT")
    exact(evaluation["physical_result"], False, "EVALUATION_RESULT")
    exact(evaluation["candidate_trace"]["final_phase"], "confirm_prone", "EVALUATION_PHASE")

    for key in (
        "selected_cell_id",
        "selected_seed",
        "selected_horizon_steps_per_arm",
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "outer_step_count",
        "solver_step_count",
        "candidate_active_command_outer_step_count",
        "matched_zero_active_command_outer_step_count",
        "physical_development_trace_valid",
        "evaluation_verdict",
        "physical_result",
        "route_coverage_passed",
        "worker_exit_code",
        "result_class",
    ):
        require(key in attempt, f"ATTEMPT_FIELD:{key}")
    exact(attempt["result_class"], "valid_physical_development_incomplete", "ATTEMPT_CLASS")
    exact(attempt["caught_error"], None, "ATTEMPT_ERROR")

    behavior = closure["observed_behavior"]
    exact(
        behavior["class"],
        "overlapping_prone_initializer_passively_ejected_by_native_contact_resolution",
        "BEHAVIOR_CLASS",
    )
    exact(behavior["pre_step_active_contact_count_after_mj_forward"], 20, "BEHAVIOR_CONTACTS")
    exact(behavior["both_arms_received_only_no_actuation_commands"], True, "BEHAVIOR_ZERO")
    exact(behavior["both_arms_produced_identical_reported_physical_classifications"], True, "BEHAVIOR_PAIRED")
    exact(behavior["integration_failure"], False, "BEHAVIOR_INTEGRATION")
    exact(behavior["controller_behavior_failure_observed"], False, "BEHAVIOR_CONTROLLER")
    exact(behavior["initializer_physical_viability_proven"], False, "BEHAVIOR_INITIALIZER")
    exact(behavior["threshold_or_evaluator_defect_identified"], False, "BEHAVIOR_EVALUATOR")
    exact(behavior["result_interpretation_rewritten"], False, "BEHAVIOR_REWRITE")

    decision = closure["decision"]
    exact(decision["r24d20_result"], "valid_physical_development_incomplete_and_retained", "DECISION")
    exact(decision["r24d20_may_be_rerun"], False, "RERUN")
    exact(decision["native_construction_collection_supervision_and_evaluation_route_executed"], True, "ROUTE_EXECUTED")
    exact(decision["active_controller_route_coverage_proven"], False, "ACTIVE_COVERAGE")
    exact(decision["prone_to_standing_claimed"], False, "RECOVERY_CLAIM")
    exact(decision["sdk1_completed_steps"], 11, "SDK1_COUNT")
    exact(decision["sdk1_total_steps"], 20, "SDK1_TOTAL")

    next_boundary = closure["next_boundary"]
    exact(next_boundary["gate_id"], "QSDK-R24D21", "NEXT_GATE")
    exact(next_boundary["question_class"], "development", "NEXT_CLASS")
    exact(next_boundary["initializer_changed"], True, "NEXT_INITIALIZER")
    exact(next_boundary["initial_state_identity_changed"], True, "NEXT_STATE")
    exact(next_boundary["controller_changed"], False, "NEXT_CONTROLLER")
    exact(next_boundary["thresholds_changed"], False, "NEXT_THRESHOLDS")
    exact(next_boundary["held_out_cells_remain_sealed"], True, "NEXT_HELDOUT")

    claim = closure["claim_boundary"]
    exact(claim["valid_physical_development_trace_observed"], True, "CLAIM_TRACE")
    exact(claim["native_construction_to_evaluation_route_executed"], True, "CLAIM_ROUTE")
    for key in (
        "active_controller_route_coverage_proven",
        "controller_physical_viability_proven",
        "prone_to_standing_claimed",
        "repeatability_rate_claimed",
        "population_claimed",
        "held_out_validation_claimed",
        "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claim[key], False, f"CLAIM_{key.upper()}")

    print(
        "QSDK_R24D20_INCOMPLETE_CLOSURE_PASS result=valid_physical_incomplete "
        "models=2 worlds=2 outer_steps=28 solver_steps=140 active_commands=0 "
        "cause=initializer_overlap_ejection heldout_access=0 "
        "prone_to_standing_claimed=False next=QSDK-R24D21"
    )


if __name__ == "__main__":
    try:
        audit()
    except Exception as error:
        print(f"QSDK_R24D20_INCOMPLETE_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
