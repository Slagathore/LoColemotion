#!/usr/bin/env python3
"""Frozen evaluator for QSDK-R24D8 active-step snapshot timing evidence."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any, Callable


RAW_SCHEMA = (
    "sporespore_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_"
    "raw_report_v1"
)
EVALUATION_SCHEMA = (
    "sporespore_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_"
    "evaluation_v1"
)
TELEMETRY_SCHEMA = "sporespore.godot_jolt_hinge_motor_telemetry.v2"
FIXTURE_ID = "QSDK.R24D8.godot_jolt_active_step_snapshot_timing.v1"
EVIDENCE_KINDS = {"synthetic_zero_world", "native_physical"}
TELEMETRY_FIELDS = {
    "schema",
    "telemetry_sequence",
    "capture_space_step_sequence",
    "read_space_step_sequence",
    "captured_during_active_step",
    "snapshot_is_current_space_step",
    "solver_step_s",
    "motor_state",
    "target_angular_velocity_rad_s",
    "min_torque_limit_nm",
    "max_torque_limit_nm",
    "signed_motor_impulse_nms",
    "positive_motor_work_j",
    "absorbed_motor_work_j",
    "net_motor_work_j",
}
CLAIM_FALSE_FIELDS = {
    "instrumented_profile_promoted",
    "stock_godot_profile_promoted",
    "native_numerical_telemetry_characterized",
    "recovery_claimed",
    "prone_to_standing_claimed",
    "turning_claim_changed",
    "cross_engine_equivalence_claimed",
    "physical_acceptance_authority",
    "release_authority",
}


class EvaluationError(RuntimeError):
    """A frozen, machine-readable evaluator refusal."""

    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


def _fail(code: str) -> None:
    raise EvaluationError(code)


def _dict(value: Any, code: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(code)
    return value


def _list(value: Any, code: str) -> list[Any]:
    if not isinstance(value, list):
        _fail(code)
    return value


def _str(value: Any, code: str) -> str:
    if not isinstance(value, str):
        _fail(code)
    return value


def _bool(value: Any, code: str) -> bool:
    if type(value) is not bool:
        _fail(code)
    return value


def _int(value: Any, code: str) -> int:
    if type(value) is not int:
        _fail(code)
    return value


def _finite(value: Any, code: str) -> float:
    if type(value) not in (int, float) or not math.isfinite(float(value)):
        _fail(code)
    return float(value)


def _exact_keys(value: dict[str, Any], expected: set[str], code: str) -> None:
    if set(value) != expected:
        _fail(code)


def _validate_engine(report: dict[str, Any]) -> None:
    engine = _dict(report.get("engine"), "engine_not_object")
    _exact_keys(
        engine,
        {
            "physics_engine",
            "physics_ticks_per_second",
            "solver_velocity_steps",
            "solver_position_steps",
            "thread_model",
            "telemetry_class_registered",
            "telemetry_method_registered",
        },
        "engine_field_set",
    )
    if (
        _str(engine.get("physics_engine"), "physics_engine_type")
        != "Jolt Physics"
        or _int(engine.get("physics_ticks_per_second"), "physics_hz_type") != 120
        or _int(engine.get("solver_velocity_steps"), "velocity_steps_type") != 20
        or _int(engine.get("solver_position_steps"), "position_steps_type") != 7
        or _str(engine.get("thread_model"), "thread_model_type") != "single_safe"
        or not _bool(
            engine.get("telemetry_class_registered"),
            "telemetry_class_registered_type",
        )
        or not _bool(
            engine.get("telemetry_method_registered"),
            "telemetry_method_registered_type",
        )
    ):
        _fail("engine_or_solver_freeze")


def _validate_fixture(report: dict[str, Any]) -> None:
    fixture = _dict(report.get("fixture"), "fixture_not_object")
    _exact_keys(
        fixture,
        {
            "fixture_id",
            "world_count",
            "isolated_hinge_count",
            "dynamic_body_count",
            "static_parent_count",
            "child_mass_kg",
            "child_inertia_diagonal_kg_m2",
            "hinge_axis_parent_local",
            "motor_enabled",
            "canonical_target_velocity_rad_s",
            "public_maximum_motor_impulse_nms",
            "joint_limits_enabled",
            "fresh_active_sample_count",
            "sleeping_stale_sample_count",
            "maximum_physics_step_count",
            "retained_sample_count",
            "gravity_scale",
            "linear_damping",
            "angular_damping",
            "collision_layer",
            "collision_mask",
            "contact_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
        },
        "fixture_field_set",
    )
    expected_ints = {
        "world_count": 1,
        "isolated_hinge_count": 1,
        "dynamic_body_count": 1,
        "static_parent_count": 1,
        "fresh_active_sample_count": 4,
        "sleeping_stale_sample_count": 4,
        "maximum_physics_step_count": 8,
        "retained_sample_count": 8,
        "collision_layer": 0,
        "collision_mask": 0,
        "contact_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
    }
    if _str(fixture.get("fixture_id"), "fixture_id_type") != FIXTURE_ID:
        _fail("fixture_id")
    for field, expected in expected_ints.items():
        if _int(fixture.get(field), f"fixture_{field}_type") != expected:
            _fail(f"fixture_{field}")
    if not _bool(fixture.get("motor_enabled"), "fixture_motor_enabled_type"):
        _fail("fixture_motor_enabled")
    if _bool(
        fixture.get("joint_limits_enabled"),
        "fixture_joint_limits_enabled_type",
    ):
        _fail("fixture_joint_limits_enabled")
    exact_scalars = {
        "child_mass_kg": 1.0,
        "canonical_target_velocity_rad_s": 0.0,
        "public_maximum_motor_impulse_nms": 0.002,
        "gravity_scale": 0.0,
        "linear_damping": 0.0,
        "angular_damping": 0.0,
    }
    for field, expected in exact_scalars.items():
        if _finite(fixture.get(field), f"fixture_{field}_type") != expected:
            _fail(f"fixture_{field}")
    inertia = _list(
        fixture.get("child_inertia_diagonal_kg_m2"),
        "fixture_inertia_not_array",
    )
    axis = _list(fixture.get("hinge_axis_parent_local"), "fixture_axis_not_array")
    if len(inertia) != 3 or any(
        _finite(value, "fixture_inertia_type") != 0.05000000074505806
        for value in inertia
    ):
        _fail("fixture_inertia")
    if len(axis) != 3 or [
        _finite(value, "fixture_axis_type") for value in axis
    ] != [0.0, 0.0, 1.0]:
        _fail("fixture_axis")


def _validate_refusals_and_readback(report: dict[str, Any]) -> None:
    refusals = _dict(report.get("refusals"), "refusals_not_object")
    _exact_keys(
        refusals,
        {"invalid_rid_refused", "not_in_tree_joint_read_refused"},
        "refusal_field_set",
    )
    if not _bool(refusals.get("invalid_rid_refused"), "invalid_rid_type"):
        _fail("invalid_rid_not_refused")
    if not _bool(
        refusals.get("not_in_tree_joint_read_refused"),
        "not_in_tree_refusal_type",
    ):
        _fail("not_in_tree_joint_not_refused")

    readback = _dict(report.get("parameter_readback"), "readback_not_object")
    _exact_keys(
        readback,
        {
            "child_mass_kg",
            "child_inertia_diagonal_kg_m2",
            "host_target_velocity_readback_rad_s",
            "public_maximum_motor_impulse_readback_nms",
            "motor_enabled_readback",
            "joint_limits_enabled_readback",
        },
        "readback_field_set",
    )
    _finite(readback.get("child_mass_kg"), "readback_mass_type")
    inertia = _list(
        readback.get("child_inertia_diagonal_kg_m2"),
        "readback_inertia_not_array",
    )
    if len(inertia) != 3:
        _fail("readback_inertia_count")
    for value in inertia:
        _finite(value, "readback_inertia_type")
    _finite(
        readback.get("host_target_velocity_readback_rad_s"),
        "readback_target_type",
    )
    _finite(
        readback.get("public_maximum_motor_impulse_readback_nms"),
        "readback_impulse_limit_type",
    )
    if not _bool(
        readback.get("motor_enabled_readback"),
        "readback_motor_enabled_type",
    ):
        _fail("readback_motor_disabled")
    if _bool(
        readback.get("joint_limits_enabled_readback"),
        "readback_joint_limits_type",
    ):
        _fail("readback_joint_limits_enabled")


def _validate_telemetry(value: Any, sample_index: int) -> dict[str, Any]:
    telemetry = _dict(value, f"sample_{sample_index}_telemetry_not_object")
    _exact_keys(telemetry, TELEMETRY_FIELDS, f"sample_{sample_index}_field_set")
    if _str(telemetry.get("schema"), f"sample_{sample_index}_schema_type") != (
        TELEMETRY_SCHEMA
    ):
        _fail(f"sample_{sample_index}_schema")
    for field in (
        "telemetry_sequence",
        "capture_space_step_sequence",
        "read_space_step_sequence",
    ):
        if _int(telemetry.get(field), f"sample_{sample_index}_{field}_type") <= 0:
            _fail(f"sample_{sample_index}_{field}_nonpositive")
    _bool(
        telemetry.get("captured_during_active_step"),
        f"sample_{sample_index}_active_capture_type",
    )
    _bool(
        telemetry.get("snapshot_is_current_space_step"),
        f"sample_{sample_index}_current_type",
    )
    if _finite(
        telemetry.get("solver_step_s"),
        f"sample_{sample_index}_solver_step_type",
    ) <= 0.0:
        _fail(f"sample_{sample_index}_solver_step_nonpositive")
    _str(telemetry.get("motor_state"), f"sample_{sample_index}_motor_state_type")
    for field in (
        "target_angular_velocity_rad_s",
        "min_torque_limit_nm",
        "max_torque_limit_nm",
        "signed_motor_impulse_nms",
        "positive_motor_work_j",
        "absorbed_motor_work_j",
        "net_motor_work_j",
    ):
        _finite(telemetry.get(field), f"sample_{sample_index}_{field}_type")
    return telemetry


def _validate_samples(report: dict[str, Any]) -> dict[str, Any]:
    samples = _list(report.get("samples"), "samples_not_array")
    if len(samples) != 8:
        _fail("retained_sample_count")
    fresh: list[dict[str, Any]] = []
    stale: list[dict[str, Any]] = []
    for index, value in enumerate(samples, start=1):
        sample = _dict(value, f"sample_{index}_not_object")
        _exact_keys(
            sample,
            {"step_index", "phase", "child_sleeping", "telemetry"},
            f"sample_{index}_outer_field_set",
        )
        if _int(sample.get("step_index"), f"sample_{index}_step_type") != index:
            _fail(f"sample_{index}_step_index")
        telemetry = _validate_telemetry(sample.get("telemetry"), index)
        if index <= 4:
            if _str(sample.get("phase"), f"sample_{index}_phase_type") != (
                "fresh_active"
            ):
                _fail(f"sample_{index}_phase")
            if _bool(sample.get("child_sleeping"), f"sample_{index}_sleep_type"):
                _fail(f"sample_{index}_unexpected_sleep")
            if not _bool(
                telemetry.get("captured_during_active_step"),
                f"sample_{index}_active_capture_type",
            ):
                _fail(f"sample_{index}_not_captured_active")
            capture = _int(
                telemetry.get("capture_space_step_sequence"),
                f"sample_{index}_capture_type",
            )
            read = _int(
                telemetry.get("read_space_step_sequence"),
                f"sample_{index}_read_type",
            )
            if capture != read:
                _fail(f"sample_{index}_fresh_capture_read_mismatch")
            if not _bool(
                telemetry.get("snapshot_is_current_space_step"),
                f"sample_{index}_current_type",
            ):
                _fail(f"sample_{index}_fresh_not_current")
            fresh.append(telemetry)
        else:
            if _str(sample.get("phase"), f"sample_{index}_phase_type") != (
                "sleeping_stale"
            ):
                _fail(f"sample_{index}_phase")
            if not _bool(
                sample.get("child_sleeping"),
                f"sample_{index}_sleep_type",
            ):
                _fail(f"sample_{index}_not_sleeping")
            if not _bool(
                telemetry.get("captured_during_active_step"),
                f"sample_{index}_active_capture_type",
            ):
                _fail(f"sample_{index}_retained_capture_not_active")
            if _bool(
                telemetry.get("snapshot_is_current_space_step"),
                f"sample_{index}_current_type",
            ):
                _fail(f"sample_{index}_stale_marked_current")
            stale.append(telemetry)

    prior_telemetry_sequence = 0
    prior_capture_sequence = 0
    for index, telemetry in enumerate(fresh, start=1):
        telemetry_sequence = _int(
            telemetry["telemetry_sequence"],
            f"fresh_{index}_telemetry_sequence_type",
        )
        capture_sequence = _int(
            telemetry["capture_space_step_sequence"],
            f"fresh_{index}_capture_sequence_type",
        )
        if telemetry_sequence <= prior_telemetry_sequence:
            _fail(f"fresh_{index}_telemetry_sequence_not_advanced")
        if capture_sequence <= prior_capture_sequence:
            _fail(f"fresh_{index}_capture_sequence_not_advanced")
        prior_telemetry_sequence = telemetry_sequence
        prior_capture_sequence = capture_sequence

    final_fresh_telemetry_sequence = _int(
        fresh[-1]["telemetry_sequence"],
        "final_fresh_telemetry_sequence_type",
    )
    final_fresh_capture_sequence = _int(
        fresh[-1]["capture_space_step_sequence"],
        "final_fresh_capture_sequence_type",
    )
    prior_read_sequence = final_fresh_capture_sequence
    for index, telemetry in enumerate(stale, start=5):
        telemetry_sequence = _int(
            telemetry["telemetry_sequence"],
            f"stale_{index}_telemetry_sequence_type",
        )
        capture_sequence = _int(
            telemetry["capture_space_step_sequence"],
            f"stale_{index}_capture_sequence_type",
        )
        read_sequence = _int(
            telemetry["read_space_step_sequence"],
            f"stale_{index}_read_sequence_type",
        )
        if telemetry_sequence != final_fresh_telemetry_sequence:
            _fail(f"stale_{index}_telemetry_sequence_refreshed")
        if capture_sequence != final_fresh_capture_sequence:
            _fail(f"stale_{index}_capture_sequence_refreshed")
        if read_sequence <= prior_read_sequence or read_sequence <= capture_sequence:
            _fail(f"stale_{index}_read_sequence_not_advanced")
        prior_read_sequence = read_sequence

    return {
        "fresh_sample_count": len(fresh),
        "stale_sample_count": len(stale),
        "first_fresh_telemetry_sequence": fresh[0]["telemetry_sequence"],
        "final_fresh_telemetry_sequence": final_fresh_telemetry_sequence,
        "first_fresh_capture_space_step_sequence": fresh[0][
            "capture_space_step_sequence"
        ],
        "final_fresh_capture_space_step_sequence": final_fresh_capture_sequence,
        "final_stale_read_space_step_sequence": stale[-1][
            "read_space_step_sequence"
        ],
    }


def _validate_execution_and_claims(
    report: dict[str, Any], evidence_kind: str
) -> None:
    execution = _dict(report.get("execution"), "execution_not_object")
    _exact_keys(
        execution,
        {
            "world_attempt_count",
            "world_build_count",
            "physics_step_count",
            "retained_sample_count",
            "direct_force_write_count",
            "direct_torque_write_count",
            "direct_impulse_write_count",
            "post_activation_transform_write_count",
            "declared_sleep_input_write_count",
            "pre_sample_physics_frame_count",
            "terminal_physics_server_deactivation_count",
            "outcome_dependent_early_stop_count",
        },
        "execution_field_set",
    )
    expected = {
        "world_attempt_count": 1,
        "world_build_count": 1,
        "physics_step_count": 8,
        "retained_sample_count": 8,
        "direct_force_write_count": 0,
        "direct_torque_write_count": 0,
        "direct_impulse_write_count": 0,
        "post_activation_transform_write_count": 0,
        "declared_sleep_input_write_count": 1,
        "pre_sample_physics_frame_count": 1,
        "terminal_physics_server_deactivation_count": 1,
        "outcome_dependent_early_stop_count": 0,
    }
    for field, expected_value in expected.items():
        if _int(execution.get(field), f"execution_{field}_type") != expected_value:
            _fail(f"execution_{field}")

    provenance = _dict(
        report.get("evidence_provenance"),
        "evidence_provenance_not_object",
    )
    _exact_keys(
        provenance,
        {"synthetic_shape_only", "native_physical_observation"},
        "evidence_provenance_field_set",
    )
    expected_synthetic = evidence_kind == "synthetic_zero_world"
    if _bool(
        provenance.get("synthetic_shape_only"),
        "synthetic_shape_only_type",
    ) != expected_synthetic:
        _fail("synthetic_shape_only")
    if _bool(
        provenance.get("native_physical_observation"),
        "native_physical_observation_type",
    ) == expected_synthetic:
        _fail("native_physical_observation")

    claims = _dict(report.get("claims"), "claims_not_object")
    _exact_keys(
        claims,
        CLAIM_FALSE_FIELDS | {"descriptive_development_timing_only"},
        "claims_field_set",
    )
    if not _bool(
        claims.get("descriptive_development_timing_only"),
        "descriptive_claim_type",
    ):
        _fail("descriptive_claim_missing")
    for field in CLAIM_FALSE_FIELDS:
        if _bool(claims.get(field), f"claim_{field}_type"):
            _fail(f"claim_{field}_true")


def evaluate(
    report: dict[str, Any],
    expected_source_commit: str,
    expected_nonce: str,
    expected_evidence_kind: str,
) -> dict[str, Any]:
    if report.get("schema_version") != RAW_SCHEMA:
        _fail("schema_version")
    if report.get("gate_id") != "QSDK-R24D8":
        _fail("gate_id")
    if report.get("question_class") != "development":
        _fail("question_class")
    evidence_kind = _str(report.get("evidence_kind"), "evidence_kind_type")
    if evidence_kind not in EVIDENCE_KINDS or evidence_kind != expected_evidence_kind:
        _fail("evidence_kind")
    if report.get("source_commit") != expected_source_commit:
        _fail("source_commit")
    if report.get("execution_nonce") != expected_nonce:
        _fail("execution_nonce")
    _validate_engine(report)
    _validate_fixture(report)
    _validate_refusals_and_readback(report)
    timing = _validate_samples(report)
    _validate_execution_and_claims(report, evidence_kind)
    return {
        "schema_version": EVALUATION_SCHEMA,
        "ok": True,
        "gate_id": "QSDK-R24D8",
        "question_class": "development",
        "evidence_kind": evidence_kind,
        "result": (
            "synthetic_shape_conforms_zero_world_only"
            if evidence_kind == "synthetic_zero_world"
            else "finite_native_active_step_snapshot_timing_positive"
        ),
        "source_commit": expected_source_commit,
        "execution_nonce": expected_nonce,
        "timing_observations": timing,
        "empirical_acceptance_threshold_count": 0,
        "superiority_margin_count": 0,
        "equivalence_or_non_inferiority_margin_count": 0,
        "validation_cohort_identity_count": 0,
        "population_claim_count": 0,
        "native_numerical_telemetry_characterized": False,
        "instrumented_profile_promoted": False,
        "recovery_claimed": False,
        "prone_to_standing_claimed": False,
        "turning_claim_changed": False,
        "cross_engine_equivalence_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _valid_report(evidence_kind: str = "synthetic_zero_world") -> dict[str, Any]:
    samples: list[dict[str, Any]] = []
    for step_index in range(1, 9):
        fresh = step_index <= 4
        sequence = step_index if fresh else 4
        samples.append(
            {
                "step_index": step_index,
                "phase": "fresh_active" if fresh else "sleeping_stale",
                "child_sleeping": not fresh,
                "telemetry": {
                    "schema": TELEMETRY_SCHEMA,
                    "telemetry_sequence": sequence,
                    "capture_space_step_sequence": sequence,
                    "read_space_step_sequence": step_index,
                    "captured_during_active_step": True,
                    "snapshot_is_current_space_step": fresh,
                    "solver_step_s": 1.0 / 120.0,
                    "motor_state": "velocity",
                    "target_angular_velocity_rad_s": 0.0,
                    "min_torque_limit_nm": -0.24,
                    "max_torque_limit_nm": 0.24,
                    "signed_motor_impulse_nms": 0.0,
                    "positive_motor_work_j": 0.0,
                    "absorbed_motor_work_j": 0.0,
                    "net_motor_work_j": 0.0,
                },
            }
        )
    return {
        "schema_version": RAW_SCHEMA,
        "gate_id": "QSDK-R24D8",
        "question_class": "development",
        "evidence_kind": evidence_kind,
        "source_commit": "a" * 40,
        "execution_nonce": "b" * 32,
        "engine": {
            "physics_engine": "Jolt Physics",
            "physics_ticks_per_second": 120,
            "solver_velocity_steps": 20,
            "solver_position_steps": 7,
            "thread_model": "single_safe",
            "telemetry_class_registered": True,
            "telemetry_method_registered": True,
        },
        "fixture": {
            "fixture_id": FIXTURE_ID,
            "world_count": 1,
            "isolated_hinge_count": 1,
            "dynamic_body_count": 1,
            "static_parent_count": 1,
            "child_mass_kg": 1.0,
            "child_inertia_diagonal_kg_m2": [
                0.05000000074505806,
                0.05000000074505806,
                0.05000000074505806,
            ],
            "hinge_axis_parent_local": [0.0, 0.0, 1.0],
            "motor_enabled": True,
            "canonical_target_velocity_rad_s": 0.0,
            "public_maximum_motor_impulse_nms": 0.002,
            "joint_limits_enabled": False,
            "fresh_active_sample_count": 4,
            "sleeping_stale_sample_count": 4,
            "maximum_physics_step_count": 8,
            "retained_sample_count": 8,
            "gravity_scale": 0.0,
            "linear_damping": 0.0,
            "angular_damping": 0.0,
            "collision_layer": 0,
            "collision_mask": 0,
            "contact_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
        },
        "refusals": {
            "invalid_rid_refused": True,
            "not_in_tree_joint_read_refused": True,
        },
        "parameter_readback": {
            "child_mass_kg": 1.0,
            "child_inertia_diagonal_kg_m2": [
                0.05000000074505806,
                0.05000000074505806,
                0.05000000074505806,
            ],
            "host_target_velocity_readback_rad_s": 0.0,
            "public_maximum_motor_impulse_readback_nms": 0.0020000000949949026,
            "motor_enabled_readback": True,
            "joint_limits_enabled_readback": False,
        },
        "samples": samples,
        "execution": {
            "world_attempt_count": 1,
            "world_build_count": 1,
            "physics_step_count": 8,
            "retained_sample_count": 8,
            "direct_force_write_count": 0,
            "direct_torque_write_count": 0,
            "direct_impulse_write_count": 0,
            "post_activation_transform_write_count": 0,
            "declared_sleep_input_write_count": 1,
            "pre_sample_physics_frame_count": 1,
            "terminal_physics_server_deactivation_count": 1,
            "outcome_dependent_early_stop_count": 0,
        },
        "evidence_provenance": {
            "synthetic_shape_only": evidence_kind == "synthetic_zero_world",
            "native_physical_observation": evidence_kind == "native_physical",
        },
        "claims": {
            "descriptive_development_timing_only": True,
            **{field: False for field in CLAIM_FALSE_FIELDS},
        },
    }


def _set_path(report: dict[str, Any], path: tuple[Any, ...], value: Any) -> None:
    current: Any = report
    for part in path[:-1]:
        current = current[part]
    current[path[-1]] = value


def self_test() -> dict[str, Any]:
    baseline = _valid_report()
    evaluate(baseline, "a" * 40, "b" * 32, "synthetic_zero_world")
    cases: list[tuple[str, tuple[Any, ...], Any, str]] = [
        ("schema", ("schema_version",), "bad", "schema_version"),
        ("gate", ("gate_id",), "QSDK-R24D7", "gate_id"),
        ("question", ("question_class",), "finite_decision", "question_class"),
        ("kind", ("evidence_kind",), "native_physical", "evidence_kind"),
        ("source", ("source_commit",), "c" * 40, "source_commit"),
        ("nonce", ("execution_nonce",), "d" * 32, "execution_nonce"),
        ("engine", ("engine", "solver_velocity_steps"), 19, "engine_or_solver_freeze"),
        ("fixture", ("fixture", "fixture_id"), "bad", "fixture_id"),
        ("worlds", ("execution", "world_build_count"), 2, "execution_world_build_count"),
        (
            "terminal_step_control",
            ("execution", "terminal_physics_server_deactivation_count"),
            0,
            "execution_terminal_physics_server_deactivation_count",
        ),
        ("refusal", ("refusals", "invalid_rid_refused"), False, "invalid_rid_not_refused"),
        ("sample_count", ("samples",), baseline["samples"][:-1], "retained_sample_count"),
        ("telemetry_schema", ("samples", 0, "telemetry", "schema"), "bad", "sample_1_schema"),
        ("active_capture", ("samples", 0, "telemetry", "captured_during_active_step"), False, "sample_1_not_captured_active"),
        ("fresh_read", ("samples", 0, "telemetry", "read_space_step_sequence"), 2, "sample_1_fresh_capture_read_mismatch"),
        ("fresh_current", ("samples", 0, "telemetry", "snapshot_is_current_space_step"), False, "sample_1_fresh_not_current"),
        ("fresh_sequence", ("samples", 1, "telemetry", "telemetry_sequence"), 1, "fresh_2_telemetry_sequence_not_advanced"),
        ("fresh_capture_sequence", ("samples", 1, "telemetry", "capture_space_step_sequence"), 1, "sample_2_fresh_capture_read_mismatch"),
        ("stale_sleep", ("samples", 4, "child_sleeping"), False, "sample_5_not_sleeping"),
        ("stale_current", ("samples", 4, "telemetry", "snapshot_is_current_space_step"), True, "sample_5_stale_marked_current"),
        ("stale_telemetry_refresh", ("samples", 4, "telemetry", "telemetry_sequence"), 5, "stale_5_telemetry_sequence_refreshed"),
        ("stale_capture_refresh", ("samples", 4, "telemetry", "capture_space_step_sequence"), 5, "stale_5_capture_sequence_refreshed"),
        ("stale_read", ("samples", 4, "telemetry", "read_space_step_sequence"), 4, "stale_5_read_sequence_not_advanced"),
        ("claim", ("claims", "instrumented_profile_promoted"), True, "claim_instrumented_profile_promoted_true"),
        ("physical_promotion", ("evidence_provenance", "native_physical_observation"), True, "native_physical_observation"),
    ]
    passed: list[str] = []
    for name, path, value, expected_code in cases:
        mutated = copy.deepcopy(baseline)
        _set_path(mutated, path, value)
        try:
            evaluate(mutated, "a" * 40, "b" * 32, "synthetic_zero_world")
        except EvaluationError as exc:
            if exc.code != expected_code:
                raise AssertionError(
                    f"{name}: expected {expected_code}, observed {exc.code}"
                ) from exc
            passed.append(name)
        else:
            raise AssertionError(f"{name}: mutation unexpectedly passed")

    surprising = []
    for name, impulse, positive_work, absorbed_work in (
        ("large_positive_values", 1234.5, 987.25, 0.0),
        ("negative_impulse_and_absorption", -432.1, 0.0, 765.0),
    ):
        candidate = copy.deepcopy(baseline)
        for sample in candidate["samples"]:
            sample["telemetry"]["signed_motor_impulse_nms"] = impulse
            sample["telemetry"]["positive_motor_work_j"] = positive_work
            sample["telemetry"]["absorbed_motor_work_j"] = absorbed_work
            sample["telemetry"]["net_motor_work_j"] = positive_work - absorbed_work
        evaluate(candidate, "a" * 40, "b" * 32, "synthetic_zero_world")
        surprising.append(name)
    return {
        "ok": True,
        "gate_id": "QSDK-R24D8",
        "rejected_mutation_count": len(passed),
        "rejected_mutations": passed,
        "accepted_surprising_outcome_count": len(surprising),
        "accepted_surprising_outcomes": surprising,
        "empirical_acceptance_threshold_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--expected-source-commit")
    parser.add_argument("--expected-nonce")
    parser.add_argument("--expected-evidence-kind", choices=sorted(EVIDENCE_KINDS))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        receipt = self_test()
        print("QSDK_R24D8_EVALUATOR_SELF_TEST " + json.dumps(receipt, sort_keys=True))
        return 0
    required = (
        args.input,
        args.output,
        args.expected_source_commit,
        args.expected_nonce,
        args.expected_evidence_kind,
    )
    if any(value is None for value in required):
        parser.error("evaluation mode requires input, output, source, nonce, and kind")
    assert args.input is not None
    assert args.output is not None
    try:
        report = json.loads(args.input.read_text(encoding="utf-8"))
        evaluation = evaluate(
            _dict(report, "report_not_object"),
            str(args.expected_source_commit),
            str(args.expected_nonce),
            str(args.expected_evidence_kind),
        )
        evaluation["raw_report_sha256"] = "sha256:" + _sha256(args.input)
        args.output.write_text(
            json.dumps(evaluation, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
    except (EvaluationError, json.JSONDecodeError, OSError) as exc:
        code = exc.code if isinstance(exc, EvaluationError) else type(exc).__name__
        print(f"QSDK_R24D8_EVALUATION_ERROR {code}", file=sys.stderr)
        return 2
    print(
        "QSDK_R24D8_EVALUATION_PASS "
        + json.dumps(
            {
                "result": evaluation["result"],
                "evidence_kind": evaluation["evidence_kind"],
                "raw_report_sha256": evaluation["raw_report_sha256"],
                "physical_acceptance_authority": False,
                "release_authority": False,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
