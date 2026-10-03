"""Trace retention and finite development evaluation for QSDK-R23D37."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import sys
from typing import Any, Mapping, Sequence

import r23d34_native_r23d29_transfer_evaluator as inherited
import r23d37_mujoco_policy_seed_isolation as design


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
DECLARATION_PATH = ROOT / "r23d37_mujoco_policy_seed_isolation_preregistration_v1.json"
REPORT_SCHEMA = "sporespore_qsdk_r23d37_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d37_worker_failure_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d37_trace_retention_v1"
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d37_trace_summary_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d37_complete_evaluation_v1"
ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
FALSE_CLAIMS = {
    "finite_mujoco_r23d21_seed_21507_walking": False,
    "mujoco_r23d29_walking_restored": False,
    "mujoco_r23d29_turning": False,
    "finite_three_engine_turning": False,
    "portable_basic_turning": False,
    "cross_engine_equivalence": False,
    "population_robustness": False,
    "prone_to_standing": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}


class R23D37EvaluationError(RuntimeError):
    """The declaration, retained evidence, or one-cell result is invalid."""


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _source_commit(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 40
        and all(character in "0123456789abcdef" for character in value)
    )


def load_declaration() -> dict[str, Any]:
    try:
        value = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D37EvaluationError(
            f"R23D37_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    matrix = value.get("frozen_matrix", {})
    successor = value.get("scientifically_distinct_successor", {})
    gates = value.get("frozen_common_physical_gates", {})
    lineage = value.get("immutable_lineage", {})
    entry = value.get("zero_world_entry_gate", {})
    invalid = (
        value.get("schema_version")
        != "sporespore_qsdk_r23d37_mujoco_policy_seed_isolation_preregistration_v1"
        or value.get("status") != "prospective_zero_world_only"
        or value.get("campaign_id") != design.CAMPAIGN_ID
        or value.get("gate_id") != design.GATE_ID
        or value.get("study_classification")
        != "prospective_exact_finite_outcome_exposed_mujoco_policy_isolation_development_screen"
        or successor.get("screened_policy_id") != design.POLICY_ID
        or successor.get("comparator_policy_id")
        != "sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1"
        or successor.get("same_outcome_exposed_seed_as_comparator") is not True
        or successor.get("same_initial_perturbation_as_comparator") is not True
        or successor.get("controller_source_changed") is not False
        or successor.get("new_controller_candidate_created") is not False
        or successor.get("fresh_held_out_condition_consumed") is not False
        or successor.get("threshold_changed") is not False
        or successor.get("turning_tested") is not False
        or successor.get("engine_specific_gait_logic_permitted") is not False
        or successor.get("arm_identity_or_outcome_branching_permitted") is not False
        or matrix.get("stage_id") != design.STAGE_ID
        or matrix.get("ordered_engine_ids") != [design.ENGINE_ID]
        or matrix.get("ordered_candidate_ids") != [design.CANDIDATE_ID]
        or matrix.get("ordered_arm_ids") != [design.ARM_ID]
        or matrix.get("declared_cell_count") != 1
        or matrix.get("declared_world_count") != 1
        or matrix.get("seed") != design.CAMPAIGN_SEED
        or matrix.get("initial_perturbation") != design.INITIAL_PERTURBATION
        or matrix.get("controller_step_count") != design.CONTROLLER_STEPS
        or matrix.get("command_schedule") != "reference_walk_for_all_2992_steps"
        or matrix.get("desired_heading_offset_rad") != 0.0
        or matrix.get("terminal_restoration_or_taper_invoked") is not False
        or matrix.get("serial_execution_required") is not True
        or gates.get("minimum_final_forward_displacement_m") != 0.030123046875
        or gates.get("maximum_tilt_rad") != 0.6
        or gates.get("minimum_torso_height_m") != 0.2499708652072946
        or gates.get("minimum_contact_cycles_per_limb") != 2
        or lineage.get("r23d21_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d21_physical_closure_v1.json")
        or lineage.get("r23d25_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d25_mujoco_terminal_zero_forward_closure_v1.json")
        or lineage.get("r23d34_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d34_native_r23d29_transfer_closure_v1.json")
        or lineage.get("r23d35_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d35_godot_trace_recovery_closure_v1.json")
        or lineage.get("r23d36_closure_raw_sha256")
        != raw_sha256(ROOT / "r23d36_mujoco_bw19v_walking_restoration_closure_v1.json")
        or lineage.get("r23d34_identity_consumed") is not True
        or lineage.get("r23d36_identity_consumed") is not True
        or lineage.get("historical_result_reinterpreted") is not False
        or lineage.get("historical_world_reused_as_a_new_cell") is not False
        or lineage.get("same_identity_rerun_permitted") is not False
        or entry.get("terminal_manifest_writer_path")
        != "sdk/strict_json_array_document.ps1"
        or entry.get("terminal_manifest_must_be_a_json_array_for_zero_one_and_many_items")
        is not True
        or entry.get("physical_execution_authorized") is not False
    )
    if invalid:
        raise R23D37EvaluationError("R23D37_DECLARATION_IDENTITY_INVALID")
    return value


# Reuse the already accepted R23D34 fixed-horizon trace validator and CAS
# publisher, but bind every identity-bearing global to this new campaign. The
# R23D37 wrapper adds an exact CAS path/manifest check below.
inherited.design = design
inherited.DECLARATION_PATH = DECLARATION_PATH
inherited.REPORT_SCHEMA = REPORT_SCHEMA
inherited.FAILURE_SCHEMA = FAILURE_SCHEMA
inherited.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
inherited.TRACE_SUMMARY_SCHEMA = TRACE_SUMMARY_SCHEMA
inherited.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
inherited.FALSE_CLAIMS = FALSE_CLAIMS
inherited.load_declaration = load_declaration


def expected_cells() -> list[str]:
    return [item.cell_id for item in design.cells()]


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    return inherited.validate_trace(cell_id, rows)


def retain_trace(**kwargs: Any) -> dict[str, Any]:
    return inherited.retain_trace(**kwargs)


def _cas_binding_failures(entry: Mapping[str, Any]) -> list[str]:
    artifact = entry.get("trace_artifact")
    if not isinstance(artifact, dict) or artifact.get("schema_version") != ARTIFACT_SCHEMA:
        return ["R23D37_TRACE_ARTIFACT_RECEIPT"]
    digest = str(artifact.get("sha256", ""))
    digest_hex = digest.removeprefix("sha256:")
    if (
        len(digest_hex) != 64
        or any(character not in "0123456789abcdef" for character in digest_hex)
        or artifact.get("test_only") is True
    ):
        return ["R23D37_TRACE_ARTIFACT_IDENTITY"]
    directory = (
        REPO_ROOT.parent / "SporeSpore_Evidence" / "artifacts" / "sha256" / digest_hex
    ).resolve()
    payload = directory / "payload.bin"
    manifest_path = directory / "manifest.json"
    if (
        Path(str(artifact.get("payload_path", ""))).resolve() != payload
        or Path(str(artifact.get("manifest_path", ""))).resolve() != manifest_path
    ):
        return ["R23D37_TRACE_ARTIFACT_CAS_PATH"]
    try:
        raw = payload.read_bytes()
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return [f"R23D37_TRACE_ARTIFACT_UNREADABLE:{type(error).__name__}"]
    observed = "sha256:" + hashlib.sha256(raw).hexdigest()
    if (
        observed != digest
        or len(raw) != artifact.get("byte_length")
        or manifest.get("schema_version")
        != "sporespore_content_addressed_artifact_manifest_v1"
        or manifest.get("algorithm") != "sha256"
        or manifest.get("sha256") != digest
        or manifest.get("byte_length") != len(raw)
        or manifest.get("payload_name") != "payload.bin"
        or manifest.get("media_type") != "application/x-ndjson"
    ):
        return ["R23D37_TRACE_ARTIFACT_BYTES"]
    return []


def evaluate_entry(
    entry: Any,
    item: design.Cell,
    *,
    expected_source_commit: str,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    evaluation, rows = inherited.evaluate_entry(
        entry, item, expected_source_commit=expected_source_commit
    )
    if isinstance(entry, dict) and evaluation.get("entry_kind") == "report":
        failures = _cas_binding_failures(entry)
        if failures:
            evaluation["execution_valid"] = False
            evaluation["common_physical_gate_passed"] = False
            evaluation["failed_gate_ids"] = list(evaluation["failed_gate_ids"]) + failures
    return evaluation, rows


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
) -> dict[str, Any]:
    load_declaration()
    if not _source_commit(expected_source_commit):
        raise R23D37EvaluationError("R23D37_SOURCE_COMMIT_INVALID")
    expected = design.cells()
    if (
        len(entries) != 1
        or len(expected) != 1
        or not isinstance(entries[0], dict)
        or entries[0].get("cell_id") != expected[0].cell_id
    ):
        raise R23D37EvaluationError("R23D37_COMPLETE_ENTRY_ORDER_INVALID")
    evaluation, _rows = evaluate_entry(
        entries[0], expected[0], expected_source_commit=expected_source_commit
    )
    positive = evaluation.get("common_physical_gate_passed") is True
    invalid = evaluation.get("execution_valid") is not True
    classification = (
        "valid_complete_positive_policy_seed_isolation"
        if positive
        else "invalid_complete_policy_seed_isolation"
        if invalid
        else "valid_complete_negative_policy_seed_isolation"
    )
    claims = copy.deepcopy(FALSE_CLAIMS)
    claims["finite_mujoco_r23d21_seed_21507_walking"] = positive
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "source_commit": expected_source_commit,
        "declaration_raw_sha256": raw_sha256(DECLARATION_PATH),
        "classification": classification,
        "cell_count": 1,
        "cell_evaluations": [evaluation],
        "all_declared_cells_executed_or_retained_as_failures": True,
        "outcome_exposed_development_screen": True,
        "fresh_held_out_condition_consumed": False,
        "terminal_restoration_or_taper_invoked": False,
        "turning_tested": False,
        "claims": claims,
    }


def _synthetic_row(item: design.Cell, step: int) -> dict[str, Any]:
    segment, offset = design.segment_for_step(item, step)
    contacts = {limb: True for limb in design.LIMB_IDS}
    return {
        "schema_version": design.TRACE_ROW_SCHEMA,
        "cell_id": item.cell_id,
        "semantic_step": step,
        "segment_id": segment,
        "desired_heading_offset_rad": offset,
        "measured_yaw_rad": 0.0,
        "desired_heading_error_rad": 0.0,
        "yaw_tracking_error_rad": 0.0,
        "requested_steering_fraction": 0.0,
        "held_steering_fraction": 0.0,
        "steering_saturated": False,
        "torso_position_world_m": [step * 0.0001, 0.4, 0.0],
        "torso_height_m": 0.4,
        "torso_tilt_rad": 0.0,
        "torso_ground_contact": False,
        "ordered_limb_phase_before": [],
        "ordered_foot_contacts_before": contacts,
        "ordered_foot_contacts_after": contacts.copy(),
        "validated_portable_command_count": design.ACTUATOR_COUNT,
        "native_actuation_application_count": design.ACTUATOR_COUNT,
        "oracle_passed": True,
    }


def _manifest_paths_value(value: Any) -> list[str]:
    if (
        not isinstance(value, list)
        or any(not isinstance(path, str) or not path for path in value)
    ):
        raise R23D37EvaluationError("R23D37_TERMINAL_MANIFEST_NOT_STRING_ARRAY")
    return value


def run_zero_world_preflight() -> dict[str, Any]:
    load_declaration()
    item = design.cells()[0]
    trace = [_synthetic_row(item, step) for step in range(design.CONTROLLER_STEPS)]
    valid = validate_trace(item.cell_id, trace)
    mutated = copy.deepcopy(trace)
    mutated[0]["segment_id"] = "wrong"
    rejected = validate_trace(item.cell_id, mutated)
    valid_manifest_shapes = [
        _manifest_paths_value([]),
        _manifest_paths_value(["one"]),
        _manifest_paths_value(["one", "two"]),
    ]
    invalid_manifest_count = 0
    for value in ("one", {"path": "one"}, [""], [1]):
        try:
            _manifest_paths_value(value)
        except R23D37EvaluationError:
            invalid_manifest_count += 1
    if (
        not valid["ok"]
        or rejected["ok"]
        or [len(value) for value in valid_manifest_shapes] != [0, 1, 2]
        or invalid_manifest_count != 4
    ):
        raise R23D37EvaluationError("R23D37_ZERO_WORLD_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d37_evaluator_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "declared_cell_count": 1,
        "valid_trace_canary_count": 1,
        "trace_mutation_rejection_count": 1,
        "valid_manifest_shape_canary_count": 3,
        "invalid_manifest_shape_rejection_count": 4,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("preflight")
    retain = commands.add_parser("retain-trace")
    retain.add_argument("--stage-id", required=True)
    retain.add_argument("--cell-id", required=True)
    retain.add_argument("--rows-json", type=Path, required=True)
    retain.add_argument("--repo-root", type=Path, required=True)
    retain.add_argument("--attempt-root", type=Path, required=True)
    retain.add_argument("--powershell", required=True)
    retain.add_argument("--test-only", action="store_true")
    retain.add_argument("--evidence-root-override", type=Path)
    evaluate = commands.add_parser("evaluate-complete")
    evaluate.add_argument("--manifest", type=Path, required=True)
    evaluate.add_argument("--expected-source-commit", required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        if args.command == "preflight":
            value = run_zero_world_preflight()
            marker = "QSDK_R23D37_EVALUATOR_PREFLIGHT "
        elif args.command == "retain-trace":
            value = retain_trace(
                stage_id=args.stage_id,
                cell_id=args.cell_id,
                rows_json_path=args.rows_json,
                repo_root=args.repo_root,
                attempt_root=args.attempt_root,
                powershell=args.powershell,
                test_only=args.test_only,
                evidence_root_override=args.evidence_root_override,
            )
            marker = "QSDK_R23D37_TRACE_RETAINED "
        else:
            manifest_value = json.loads(args.manifest.read_text(encoding="utf-8"))
            paths = _manifest_paths_value(manifest_value)
            entries = [json.loads(Path(path).read_text(encoding="utf-8")) for path in paths]
            value = evaluate_complete_entries(
                entries, expected_source_commit=args.expected_source_commit
            )
            marker = "QSDK_R23D37_COMPLETE_EVALUATION "
        print(marker + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    except (
        R23D37EvaluationError,
        inherited.R23D34EvaluationError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        ValueError,
    ) as error:
        print(f"QSDK_R23D37_EVALUATOR_FAILURE {type(error).__name__}:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
