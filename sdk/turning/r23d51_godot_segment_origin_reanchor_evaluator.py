"""Evaluator and retained-trace gate for QSDK-R23D51."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import sys
from typing import Any, Mapping, Sequence

import r23d34_native_r23d29_transfer_evaluator as inherited
import r23d51_godot_segment_origin_reanchor as design


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
DECLARATION_PATH = (
    ROOT / "r23d51_godot_segment_origin_reanchor_preregistration_v1.json"
)
PUBLISHER_PATH = SDK_ROOT / "publish_qsdk_r23d48_trace.ps1"
PUBLISHER_MARKER = "QSDK_R23D48_EVIDENCE_CAS "
REPORT_SCHEMA = "sporespore_qsdk_r23d51_engine_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d51_worker_failure_v1"
TRACE_RETENTION_SCHEMA = "sporespore_qsdk_r23d51_trace_retention_v1"
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d51_trace_summary_v1"
COMPLETE_EVALUATION_SCHEMA = "sporespore_qsdk_r23d51_complete_evaluation_v1"
ARTIFACT_SCHEMA = "sporespore_content_addressed_artifact_receipt_v1"
FALSE_CLAIMS = {
    "godot_jolt_r23d29_turning": False,
    "finite_three_engine_turning": False,
    "portable_basic_turning": False,
    "q_sdk_r23_satisfied": False,
    "cross_engine_equivalence": False,
    "population_robustness": False,
    "prone_to_standing": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}


class R23D51EvaluationError(RuntimeError):
    """The declaration, retained evidence, or three-cell result is invalid."""


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


def _same_existing_file(left: Path, right: Path) -> bool:
    """Compare existing filesystem identity, not Windows namespace spelling."""

    try:
        return os.path.samefile(os.fspath(left), os.fspath(right))
    except OSError:
        return False


def _alternate_windows_spelling(path: Path) -> Path:
    absolute = os.path.abspath(os.fspath(path))
    if os.name != "nt":
        return Path(absolute)
    if absolute.startswith("\\\\?\\UNC\\"):
        return Path("\\\\" + absolute[8:])
    if absolute.startswith("\\\\?\\"):
        return Path(absolute[4:])
    if absolute.startswith("\\\\"):
        return Path("\\\\?\\UNC\\" + absolute[2:])
    return Path("\\\\?\\" + absolute)


def load_declaration() -> dict[str, Any]:
    try:
        value = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D51EvaluationError(
            f"R23D51_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error
    lineage = value.get("immutable_lineage", {})
    successor = value.get("scientifically_distinct_successor", {})
    matrix = value.get("frozen_matrix", {})
    gates = value.get("frozen_common_physical_gates", {})
    measurement = value.get("cycle_integrated_measurement", {})
    adequacy = value.get("adequacy", {})
    evidence = value.get("evidence_integrity", {})
    claims = value.get("claims", {})
    invalid = (
        value.get("schema_version")
        != "sporespore_qsdk_r23d51_godot_segment_origin_reanchor_preregistration_v1"
        or value.get("status") != "prospective_zero_world_only"
        or value.get("campaign_id") != design.CAMPAIGN_ID
        or value.get("gate_id") != design.GATE_ID
        or value.get("study_classification")
        != "exact_outcome_exposed_same_seed_godot_jolt_implementation_development_screen"
        or successor.get("same_outcome_exposed_seed_as_comparator") is not True
        or successor.get("same_initial_perturbation_as_comparator") is not True
        or successor.get("only_declared_physical_change")
        != (
            "task_frame_origin_policy_id=fixed_initial_origin_v1 becomes "
            "heading_segment_origin_reanchor_v1"
        )
        or successor.get("reference_yaw_rebased") is not False
        or successor.get("task_axes_rebased") is not False
        or successor.get("controller_source_or_gain_changed") is not False
        or successor.get("engine_identity_input_permitted") is not False
        or successor.get("arm_identity_input_permitted") is not False
        or successor.get("outcome_branching_permitted") is not False
        or successor.get("threshold_changed") is not False
        or successor.get("fresh_held_out_condition_consumed") is not False
        or matrix.get("stage_id") != design.STAGE_ID
        or matrix.get("ordered_engine_ids") != list(design.ENGINE_IDS)
        or matrix.get("ordered_candidate_ids") != [design.CANDIDATE_ID]
        or matrix.get("ordered_arm_ids") != list(design.ARM_OFFSETS)
        or matrix.get("ordered_heading_offsets_rad")
        != list(design.ARM_OFFSETS.values())
        or matrix.get("declared_cell_count") != len(design.cells())
        or matrix.get("declared_world_count") != len(design.cells())
        or matrix.get("seed") != design.CAMPAIGN_SEED
        or matrix.get("initial_perturbation") != design.INITIAL_PERTURBATION
        or matrix.get("morphology_id") != design.MORPHOLOGY_ID
        or matrix.get("controller_policy_id") != design.POLICY_ID
        or matrix.get("task_frame_origin_policy_id")
        != design.TASK_FRAME_ORIGIN_POLICY_ID
        or matrix.get("expected_reanchor_semantic_steps")
        != list(design.EXPECTED_REANCHOR_STEPS)
        or matrix.get("controller_step_count") != design.CONTROLLER_STEPS
        or matrix.get("turn_start_step") != design.TURN_START_STEP
        or matrix.get("turn_end_step_exclusive") != design.TURN_END_STEP_EXCLUSIVE
        or matrix.get("recovery_duration_steps") != design.RECOVERY_DURATION_STEPS
        or matrix.get("startup_transform_id") != design.STARTUP_TRANSFORM_ID
        or matrix.get("terminal_restoration_or_taper_invoked") is not False
        or matrix.get("serial_execution_required") is not True
        or matrix.get("all_cells_run_regardless_of_intermediate_outcome") is not True
        or gates.get("minimum_final_forward_displacement_m") != 0.030123046875
        or gates.get("maximum_tilt_rad") != 0.6
        or gates.get("minimum_torso_height_m") != 0.2499708652072946
        or gates.get("minimum_contact_cycles_per_limb") != 2
        or measurement.get("inherited_unchanged_from_r23d31") is not True
        or measurement.get("minimum_raw_signed_cycle_shift_rad") != 0.01
        or measurement.get("minimum_reference_conditioned_cycle_shift_rad")
        != 0.01
        or measurement.get("reference_arm_required") is not True
        or measurement.get("both_signed_arms_required") is not True
        or adequacy.get("population_inference_attempted") is not False
        or adequacy.get("cross_engine_equivalence_attempted") is not False
        or adequacy.get("positive_selects_only_a_held_out_validation_candidate")
        is not True
        or evidence.get("r23d50_existing_file_identity_verifier_inherited")
        is not True
        or evidence.get("ordinary_and_windows_extended_path_spellings_equivalent")
        is not True
        or evidence.get("wrong_existing_file_rejected") is not True
        or evidence.get("authority_repo_root_required_for_complete_evaluation")
        is not True
        or claims.get("godot_jolt_turning_validation") is not False
        or claims.get("finite_three_engine_turning") is not False
        or claims.get("portable_basic_turning") is not False
        or claims.get("physical_acceptance_authority") is not False
        or lineage.get("r23d48_closure_raw_sha256")
        != raw_sha256(
            ROOT
            / "r23d48_support_loss_conditioned_three_engine_turning_closure_v1.json"
        )
        or lineage.get("r23d50_closure_raw_sha256")
        != raw_sha256(
            ROOT / "r23d50_rapier_cas_path_identity_replay_closure_v1.json"
        )
        or lineage.get("r23d31_closure_raw_sha256")
        != raw_sha256(
            ROOT / "r23d31_cycle_integrated_directional_response_closure_v1.json"
        )
        or lineage.get("r23d32_closure_raw_sha256")
        != raw_sha256(
            ROOT / "r23d32_finite_rapier_turning_replication_closure_v1.json"
        )
        or lineage.get("r23d48_identity_consumed") is not True
        or lineage.get("r23d50_identity_consumed") is not True
        or lineage.get("historical_result_reinterpreted") is not False
        or lineage.get("historical_world_reused_as_a_new_cell") is not False
        or lineage.get("same_identity_rerun_permitted") is not False
    )
    if invalid:
        raise R23D51EvaluationError("R23D51_DECLARATION_IDENTITY_INVALID")
    return value


# Reuse the accepted R23D34 fixed-horizon trace/CAS implementation, rebound to
# this one-engine outcome-exposed successor.  Its native physics and common
# walking gates remain unchanged.
inherited.design = design
inherited.DECLARATION_PATH = DECLARATION_PATH
inherited.PUBLISHER_PATH = PUBLISHER_PATH
inherited.PUBLISHER_MARKER = PUBLISHER_MARKER
inherited.REPORT_SCHEMA = REPORT_SCHEMA
inherited.FAILURE_SCHEMA = FAILURE_SCHEMA
inherited.TRACE_RETENTION_SCHEMA = TRACE_RETENTION_SCHEMA
inherited.TRACE_SUMMARY_SCHEMA = TRACE_SUMMARY_SCHEMA
inherited.COMPLETE_EVALUATION_SCHEMA = COMPLETE_EVALUATION_SCHEMA
inherited.FALSE_CLAIMS = FALSE_CLAIMS
inherited.load_declaration = load_declaration

_BASE_VALIDATE_TRACE = inherited.validate_trace


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    summary = _BASE_VALIDATE_TRACE(cell_id, rows)
    failures = list(summary.get("failure_codes", []))
    governor = design.SupportLossConditionedStartup()
    active_count = 0
    zero_count = 0
    unity_count = 0
    observed_transition_steps: list[int] = []
    expected_origin: list[float] | None = None
    expected_segment = ""
    expected_reanchor_count = 0
    if isinstance(rows, list):
        for semantic_step, row in enumerate(rows):
            if not isinstance(row, dict):
                continue
            contacts = row.get("ordered_foot_contacts_before")
            try:
                startup = governor.step(semantic_step, contacts)
            except (design.StartupTransformError, TypeError):
                failures.append(f"R23D51_STARTUP_CONTACTS_INVALID:{semantic_step}")
                continue
            expected_scale = float(startup["startup_velocity_scale"])
            startup_valid = (
                row.get("startup_ramp_id") == design.STARTUP_RAMP_ID
                and row.get("startup_transform_id") == design.STARTUP_TRANSFORM_ID
                and _finite(row.get("startup_velocity_scale"))
                and abs(float(row["startup_velocity_scale"]) - expected_scale)
                <= 1.0e-15
                and row.get("startup_ramp_active") == (expected_scale < 1.0)
                and row.get("startup_ramp_residual_count") == design.ACTUATOR_COUNT
                and row.get("startup_transform_residual_count")
                == design.ACTUATOR_COUNT
                and all(row.get(field) == expected for field, expected in startup.items())
                and _finite(row.get("startup_ramp_maximum_absolute_residual_rad_s"))
                and float(row["startup_ramp_maximum_absolute_residual_rad_s"]) >= 0.0
            )
            if not startup_valid:
                failures.append(f"R23D51_STARTUP_TRANSFORM_INVALID:{semantic_step}")
            active_count += int(expected_scale < 1.0)
            zero_count += int(expected_scale == 0.0)
            unity_count += int(expected_scale == 1.0)

            segment, _ = design.segment_for_step(design.cell(
                design.STAGE_ID, "godot_jolt", row.get("cell_id", "").rsplit("__", 1)[-1]
            ), semantic_step)
            origin = row.get("task_frame_origin_world_m")
            position = row.get("torso_position_world_m")
            transition = semantic_step in design.EXPECTED_REANCHOR_STEPS
            if segment != expected_segment:
                expected_segment = segment
                expected_reanchor_count += 1
                expected_origin = (
                    [float(component) for component in position]
                    if isinstance(position, list)
                    and len(position) == 3
                    and all(_finite(component) for component in position)
                    else None
                )
            origin_valid = (
                row.get("task_frame_origin_policy_id")
                == design.TASK_FRAME_ORIGIN_POLICY_ID
                and isinstance(origin, list)
                and len(origin) == 3
                and all(_finite(component) for component in origin)
                and expected_origin is not None
                and all(
                    abs(float(observed) - expected) <= 1.0e-12
                    for observed, expected in zip(origin, expected_origin, strict=True)
                )
                and row.get("task_frame_origin_reanchored_this_step") is transition
                and row.get("task_frame_origin_reanchor_count")
                == expected_reanchor_count
            )
            if not origin_valid:
                failures.append(f"R23D51_TASK_FRAME_ORIGIN_INVALID:{semantic_step}")
            if row.get("task_frame_origin_reanchored_this_step") is True:
                observed_transition_steps.append(semantic_step)
    if observed_transition_steps != list(design.EXPECTED_REANCHOR_STEPS):
        failures.append("R23D51_TASK_FRAME_ORIGIN_TRANSITION_STEPS")
    summary.update(
        schema_version=TRACE_SUMMARY_SCHEMA,
        ok=not failures,
        failure_codes=failures[:32],
        startup_ramp_active_step_count=active_count,
        startup_ramp_exact_zero_scale_step_count=zero_count,
        startup_ramp_exact_unity_scale_step_count=unity_count,
        startup_transform_id=design.STARTUP_TRANSFORM_ID,
        startup_ramp_triggered=governor.trigger_step is not None,
        startup_ramp_trigger_step=governor.trigger_step,
        startup_probe_minimum_support_count=governor.minimum_probe_support_count,
        task_frame_origin_policy_id=design.TASK_FRAME_ORIGIN_POLICY_ID,
        task_frame_origin_transition_steps=observed_transition_steps,
        task_frame_origin_transition_count=len(observed_transition_steps),
    )
    return summary


inherited.validate_trace = validate_trace


def retain_trace(**kwargs: Any) -> dict[str, Any]:
    return inherited.retain_trace(**kwargs)


def _cas_binding_failures(
    entry: Mapping[str, Any], *, authority_repo_root: Path | None = None
) -> list[str]:
    artifact = entry.get("trace_artifact")
    if not isinstance(artifact, dict) or artifact.get("schema_version") != ARTIFACT_SCHEMA:
        return ["R23D51_TRACE_ARTIFACT_RECEIPT"]
    digest = str(artifact.get("sha256", ""))
    digest_hex = digest.removeprefix("sha256:")
    if (
        len(digest_hex) != 64
        or any(character not in "0123456789abcdef" for character in digest_hex)
        or artifact.get("test_only") is True
    ):
        return ["R23D51_TRACE_ARTIFACT_IDENTITY"]
    authority_root = (
        REPO_ROOT if authority_repo_root is None else authority_repo_root.resolve()
    )
    directory = (
        authority_root.parent
        / "SporeSpore_Evidence"
        / "artifacts"
        / "sha256"
        / digest_hex
    )
    payload = directory / "payload.bin"
    manifest_path = directory / "manifest.json"
    recorded_payload = Path(str(artifact.get("payload_path", "")))
    recorded_manifest = Path(str(artifact.get("manifest_path", "")))
    if not _same_existing_file(recorded_payload, payload) or not _same_existing_file(
        recorded_manifest, manifest_path
    ):
        return ["R23D51_TRACE_ARTIFACT_CAS_FILE_IDENTITY"]
    try:
        raw = payload.read_bytes()
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return [f"R23D51_TRACE_ARTIFACT_UNREADABLE:{type(error).__name__}"]
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
        return ["R23D51_TRACE_ARTIFACT_BYTES"]
    return []


def evaluate_entry(
    entry: Any,
    item: design.Cell,
    *,
    expected_source_commit: str,
    authority_repo_root: Path,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    evaluation, rows = inherited.evaluate_entry(
        entry, item, expected_source_commit=expected_source_commit
    )
    if isinstance(entry, dict) and evaluation.get("entry_kind") == "report":
        failures = _cas_binding_failures(
            entry,
            authority_repo_root=authority_repo_root,
        )
        measurements = entry.get("measurements")
        trace_summary = validate_trace(item.cell_id, rows)
        if not isinstance(measurements, dict) or (
            measurements.get("startup_ramp_id") != design.STARTUP_RAMP_ID
            or measurements.get("startup_ramp_step_count")
            != design.STARTUP_RAMP_STEPS
            or measurements.get("startup_ramp_composition_step_count")
            != design.CONTROLLER_STEPS
            or measurements.get("startup_ramp_active_step_count")
            != trace_summary.get("startup_ramp_active_step_count")
            or measurements.get("startup_ramp_exact_zero_scale_step_count")
            != trace_summary.get("startup_ramp_exact_zero_scale_step_count")
            or measurements.get("startup_ramp_exact_unity_scale_step_count")
            != trace_summary.get("startup_ramp_exact_unity_scale_step_count")
            or measurements.get("startup_ramp_composition_integrity_passed") is not True
            or measurements.get("startup_transform_id")
            != design.STARTUP_TRANSFORM_ID
            or measurements.get("startup_ramp_triggered")
            != trace_summary.get("startup_ramp_triggered")
            or measurements.get("startup_ramp_trigger_step")
            != trace_summary.get("startup_ramp_trigger_step")
            or measurements.get("startup_probe_minimum_support_count")
            != trace_summary.get("startup_probe_minimum_support_count")
            or measurements.get("startup_transform_composition_integrity_passed")
            is not True
        ):
            failures.append("R23D51_STARTUP_REPORT_INTEGRITY")
        if trace_summary.get("task_frame_origin_transition_steps") != list(
            design.EXPECTED_REANCHOR_STEPS
        ):
            failures.append("R23D51_TASK_FRAME_ORIGIN_REPORT_INTEGRITY")
        if failures:
            evaluation["execution_valid"] = False
            evaluation["common_physical_gate_passed"] = False
            evaluation["failed_gate_ids"] = list(evaluation["failed_gate_ids"]) + failures
    return evaluation, rows


def evaluate_complete_entries(
    entries: Sequence[dict[str, Any]],
    *,
    expected_source_commit: str,
    authority_repo_root: Path,
) -> dict[str, Any]:
    load_declaration()
    if not _source_commit(expected_source_commit):
        raise R23D51EvaluationError("R23D51_SOURCE_COMMIT_INVALID")
    authority_root = authority_repo_root.resolve()
    if not (authority_root / ".git").exists():
        raise R23D51EvaluationError("R23D51_AUTHORITY_REPO_ROOT_INVALID")
    expected = design.cells()
    if len(entries) != len(expected) or any(
        not isinstance(entry, dict) or entry.get("cell_id") != item.cell_id
        for entry, item in zip(entries, expected, strict=True)
    ):
        raise R23D51EvaluationError("R23D51_COMPLETE_ENTRY_ORDER_INVALID")
    evaluations: list[dict[str, Any]] = []
    rows_by_cell: dict[str, list[dict[str, Any]]] = {}
    for entry, item in zip(entries, expected, strict=True):
        evaluation, rows = evaluate_entry(
            entry,
            item,
            expected_source_commit=expected_source_commit,
            authority_repo_root=authority_root,
        )
        evaluations.append(evaluation)
        rows_by_cell[item.cell_id] = rows
    all_execution_valid = all(row["execution_valid"] for row in evaluations)
    all_physical_passed = all(
        row["common_physical_gate_passed"] for row in evaluations
    )
    measurement: dict[str, Any] | None = None
    measurement_failures: list[str] = []
    if all_execution_valid:
        measurement = inherited.measure_cycle_integrated_response(
            {
                item.arm_id: inherited._measurement_rows(rows_by_cell[item.cell_id])
                for item in expected
            }
        )
        measurement_failures = [
            gate for gate, passed in measurement["gates"].items() if not passed
        ]
    mechanism_selected = (
        all_execution_valid
        and all_physical_passed
        and bool(measurement and measurement.get("passed") is True)
    )
    any_invalid = any(not row["execution_valid"] for row in evaluations)
    classification = (
        "valid_complete_positive_outcome_exposed_godot_segment_origin_development"
        if mechanism_selected
        else "invalid_complete_outcome_exposed_godot_segment_origin_development"
        if any_invalid
        else "valid_complete_negative_outcome_exposed_godot_segment_origin_development"
    )
    claims = copy.deepcopy(FALSE_CLAIMS)
    claims["segment_origin_reanchor_mechanism_selected_for_held_out_validation"] = (
        mechanism_selected
    )
    return {
        "schema_version": COMPLETE_EVALUATION_SCHEMA,
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "source_commit": expected_source_commit,
        "declaration_raw_sha256": raw_sha256(DECLARATION_PATH),
        "classification": classification,
        "cell_count": len(evaluations),
        "cell_evaluations": evaluations,
        "engine_result": {
            "engine_id": "godot_jolt",
            "all_cells_execution_valid": all_execution_valid,
            "all_common_physical_gates_passed": all_physical_passed,
            "cycle_integrated_measurement": measurement,
            "measurement_failure_codes": measurement_failures,
            "mechanism_selected": mechanism_selected,
        },
        "all_declared_cells_executed_or_retained_as_failures": True,
        "all_cells_run_regardless_of_intermediate_outcome": True,
        "fresh_held_out_condition_consumed": False,
        "outcome_exposed_before_preregistration": True,
        "terminal_restoration_or_taper_invoked": False,
        "cross_engine_equivalence_test_invoked": False,
        "claims": claims,
    }


def _synthetic_rows(item: design.Cell) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    governor = design.SupportLossConditionedStartup()
    latched_origin = [0.0, 0.4, 0.0]
    reanchor_count = 0
    for step in range(design.CONTROLLER_STEPS):
        row = inherited._synthetic_row(item, step)
        contacts = row["ordered_foot_contacts_before"]
        startup = governor.step(step, contacts)
        scale = float(startup["startup_velocity_scale"])
        row.update(startup)
        row.update(
            startup_ramp_id=design.STARTUP_RAMP_ID,
            startup_transform_id=design.STARTUP_TRANSFORM_ID,
            startup_ramp_active=scale < 1.0,
            startup_ramp_residual_count=design.ACTUATOR_COUNT,
            startup_transform_residual_count=design.ACTUATOR_COUNT,
            startup_ramp_maximum_absolute_residual_rad_s=0.0,
        )
        if step in design.EXPECTED_REANCHOR_STEPS:
            latched_origin = [float(value) for value in row["torso_position_world_m"]]
            reanchor_count += 1
        row.update(
            task_frame_origin_policy_id=design.TASK_FRAME_ORIGIN_POLICY_ID,
            task_frame_origin_world_m=latched_origin.copy(),
            task_frame_origin_reanchored_this_step=(
                step in design.EXPECTED_REANCHOR_STEPS
            ),
            task_frame_origin_reanchor_count=reanchor_count,
        )
        rows.append(row)
    return rows


def _manifest_paths_value(value: Any) -> list[str]:
    if not isinstance(value, list) or any(
        not isinstance(item, str) or not item for item in value
    ):
        raise R23D51EvaluationError("R23D51_TERMINAL_MANIFEST_INVALID")
    return value


def run_zero_world_preflight() -> dict[str, Any]:
    load_declaration()
    traces = {item.cell_id: _synthetic_rows(item) for item in design.cells()}
    validations = [validate_trace(item.cell_id, traces[item.cell_id]) for item in design.cells()]
    first = design.cells()[0]
    mutations: list[list[dict[str, Any]]] = []
    missing_origin = copy.deepcopy(traces[first.cell_id])
    missing_origin[design.TURN_START_STEP].pop("task_frame_origin_world_m")
    mutations.append(missing_origin)
    wrong_origin = copy.deepcopy(traces[first.cell_id])
    wrong_origin[design.TURN_START_STEP]["task_frame_origin_world_m"][0] += 0.01
    mutations.append(wrong_origin)
    missing_transition = copy.deepcopy(traces[first.cell_id])
    missing_transition[design.TURN_START_STEP][
        "task_frame_origin_reanchored_this_step"
    ] = False
    mutations.append(missing_transition)
    extra_transition = copy.deepcopy(traces[first.cell_id])
    extra_transition[design.TURN_START_STEP + 1][
        "task_frame_origin_reanchored_this_step"
    ] = True
    mutations.append(extra_transition)
    wrong_count = copy.deepcopy(traces[first.cell_id])
    wrong_count[design.TURN_START_STEP]["task_frame_origin_reanchor_count"] = 99
    mutations.append(wrong_count)
    wrong_policy = copy.deepcopy(traces[first.cell_id])
    wrong_policy[0]["task_frame_origin_policy_id"] = "fixed_initial_origin_v1"
    mutations.append(wrong_policy)
    startup_mutation = copy.deepcopy(traces[first.cell_id])
    startup_mutation[179]["startup_velocity_scale"] += 0.001
    mutations.append(startup_mutation)
    segment_mutation = copy.deepcopy(traces[first.cell_id])
    segment_mutation[design.TURN_START_STEP]["segment_id"] = "reference_warmup"
    mutations.append(segment_mutation)
    rejected = [validate_trace(first.cell_id, rows) for rows in mutations]
    measurement = inherited.measure_cycle_integrated_response(
        {
            item.arm_id: inherited._measurement_rows(traces[item.cell_id])
            for item in design.cells()
        }
    )
    invalid_manifest_count = 0
    for value in ("one", {"path": "one"}, [""], [1]):
        try:
            _manifest_paths_value(value)
        except R23D51EvaluationError:
            invalid_manifest_count += 1
    alternate = _alternate_windows_spelling(DECLARATION_PATH)
    same_file_alias_accepted = _same_existing_file(DECLARATION_PATH, alternate)
    wrong_existing_file_rejected = not _same_existing_file(
        DECLARATION_PATH,
        ROOT / "r23d51_godot_segment_origin_reanchor_implementation_v1.json",
    )
    complete_arguments = _arguments(
        [
            "evaluate-complete",
            "--manifest",
            str(DECLARATION_PATH),
            "--expected-source-commit",
            "0" * 40,
            "--repo-root",
            str(REPO_ROOT),
        ]
    )
    if (
        not all(validation["ok"] for validation in validations)
        or any(result["ok"] for result in rejected)
        or measurement.get("passed") is not True
        or [len(_manifest_paths_value(value)) for value in ([], ["one"], ["one", "two", "three"])]
        != [0, 1, 3]
        or invalid_manifest_count != 4
        or not same_file_alias_accepted
        or not wrong_existing_file_rejected
        or complete_arguments.repo_root != REPO_ROOT
    ):
        raise R23D51EvaluationError("R23D51_ZERO_WORLD_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d51_evaluator_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "declared_cell_count": len(design.cells()),
        "valid_trace_canary_count": len(validations),
        "trace_mutation_rejection_count": len(rejected),
        "origin_policy_mutation_rejection_count": 6,
        "startup_transform_mutation_rejection_count": 1,
        "segment_mutation_rejection_count": 1,
        "cycle_integrated_positive_canary_count": 1,
        "valid_manifest_shape_canary_count": 3,
        "invalid_manifest_shape_rejection_count": invalid_manifest_count,
        "same_file_path_spelling_positive_control_count": 1,
        "wrong_file_path_rejection_count": 1,
        "production_cas_binding_uses_existing_file_identity": True,
        "complete_evaluation_authority_root_cli_canary_count": 1,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
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
    evaluate.add_argument("--repo-root", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        if args.command == "preflight":
            value = run_zero_world_preflight()
            marker = "QSDK_R23D51_EVALUATOR_PREFLIGHT "
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
            marker = "QSDK_R23D51_TRACE_RETAINED "
        else:
            manifest_value = json.loads(args.manifest.read_text(encoding="utf-8"))
            paths = _manifest_paths_value(manifest_value)
            entries = [json.loads(Path(path).read_text(encoding="utf-8")) for path in paths]
            value = evaluate_complete_entries(
                entries,
                expected_source_commit=args.expected_source_commit,
                authority_repo_root=args.repo_root,
            )
            marker = "QSDK_R23D51_COMPLETE_EVALUATION "
        print(marker + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    except (
        R23D51EvaluationError,
        inherited.R23D34EvaluationError,
        inherited.CycleIntegratedMeasurementError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        ValueError,
    ) as error:
        print(f"QSDK_R23D51_EVALUATOR_FAILURE {type(error).__name__}:{error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
