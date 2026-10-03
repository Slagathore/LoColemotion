#!/usr/bin/env python3
"""QSDK-R24D9 threshold-free native numerical telemetry evaluator.

This evaluator has two deliberately separate jobs:

* reject an incomplete, malformed, provenance-drifted, timing-invalid, or
  claim-promoted report; and
* describe every finite native impulse/work observation without turning a
  residual, sign, cap comparison, or limit response into an acceptance gate.

The synthetic envelope used by the complete zero-world gate has the identical
shape and is evaluated by the same code, but it is never a native observation.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import pathlib
import re
import sys
from typing import Any, Callable


RAW_SCHEMA = (
    "sporespore_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_raw_report_v1"
)
EVALUATION_SCHEMA = (
    "sporespore_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_evaluation_v1"
)
TELEMETRY_SCHEMA = "sporespore.godot_jolt_hinge_motor_telemetry.v2"
GATE_ID = "QSDK-R24D9"
FIXTURE_ID = "QSDK.R24D9.godot_jolt_one_hinge_numerical_telemetry.v1"
EXPECTED_SOURCE = "1" * 40
EXPECTED_NONCE = "2" * 32

EXPECTED_INERTIA = [
    0.05000000074505806,
    0.05000000074505806,
    0.05000000074505806,
]
EXPECTED_REAL_T_IMPULSE = {
    0.002: 0.0020000000949949026,
    0.01: 0.009999999776482582,
}
EXPECTED_REAL_T_LIMIT = {
    -1.0: -1.0,
    1.0: 1.0,
    -0.02: -0.019999999552965164,
    0.02: 0.019999999552965164,
}

AUTHORIZATION = {
    "closure_id": "QSDK-R24D8-PH1-CLOSURE",
    "closure_path": (
        "sdk/recovery/"
        "r24d8_godot_jolt_active_step_snapshot_timing_positive_closure_v1.json"
    ),
    "closure_raw_sha256": (
        "sha256:a068b13f8fa97db5559572b1a221bff262da4c3d933a2544198ec67156cbba4d"
    ),
    "closure_publication_commit": "4088881d92ea335c1cb70ff42e15abe5bf5d42c5",
}
RUNTIME_PROVENANCE = {
    "runtime_profile_id": (
        "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2"
    ),
    "godot_source_commit": "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88",
    "combined_patch_raw_sha256": (
        "sha256:9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
    ),
    "toolchain_provenance_console_binary_raw_sha256": (
        "sha256:8a629f16859f653d447cd7f07f712f0045a1aed3f27be53413d97df6ff1ec0e6"
    ),
    "toolchain_provenance_console_binary_byte_length": 293376,
    "toolchain_provenance_engine_binary_raw_sha256": (
        "sha256:0d77df42106c6d2f6fa51727d8051bf403e8a0273b3242daee581c93c4ba7257"
    ),
    "toolchain_provenance_engine_binary_byte_length": 188829184,
    "r24d9_independent_cold_build_required": True,
}
RECOMPUTATION_CONTRACT = {
    "effective_axis_inertia_kg_m2": "1 / inverse_inertia_axis_kg_inv_m2",
    "independent_angular_momentum_change_nms": (
        "effective_axis_inertia_kg_m2 * "
        "(post_canonical_relative_rate_rad_s - pre_canonical_relative_rate_rad_s)"
    ),
    "independent_kinetic_energy_change_j": (
        "0.5 * effective_axis_inertia_kg_m2 * "
        "(post_canonical_relative_rate_rad_s^2 - "
        "pre_canonical_relative_rate_rad_s^2)"
    ),
    "impulse_residual_nms": (
        "signed_motor_impulse_nms - independent_angular_momentum_change_nms"
    ),
    "work_residual_j": (
        "net_motor_work_j - independent_kinetic_energy_change_j"
    ),
    "motor_impulse_cap_nms": (
        "max(abs(min_torque_limit_nm), abs(max_torque_limit_nm)) * solver_step_s"
    ),
    "net_work_decomposition_residual_j": (
        "net_motor_work_j - (positive_motor_work_j - absorbed_motor_work_j)"
    ),
    "relative_angle_integral_rad": (
        "prior_integrated_angle_rad + 0.5 * (pre_rate + post_rate) * solver_step_s"
    ),
    "independent_oracle_uses_instrumented_motor_impulse_or_work_as_input": False,
    "sleeping_stale_samples_enter_numerical_aggregate": False,
}

CELL_CONFIG: list[dict[str, Any]] = [
    {
        "cell_id": "drive_positive",
        "family": "signed_drive",
        "motor_enabled": True,
        "canonical_target_velocity_rad_s": 1.0,
        "initial_canonical_rate_rad_s": 0.0,
        "public_maximum_motor_impulse_nms": 0.002,
        "joint_limits_enabled": False,
        "lower_limit_rad": -1.0,
        "upper_limit_rad": 1.0,
        "retained_step_count": 4,
    },
    {
        "cell_id": "drive_negative",
        "family": "signed_drive",
        "motor_enabled": True,
        "canonical_target_velocity_rad_s": -1.0,
        "initial_canonical_rate_rad_s": 0.0,
        "public_maximum_motor_impulse_nms": 0.002,
        "joint_limits_enabled": False,
        "lower_limit_rad": -1.0,
        "upper_limit_rad": 1.0,
        "retained_step_count": 4,
    },
    {
        "cell_id": "brake_positive",
        "family": "signed_braking",
        "motor_enabled": True,
        "canonical_target_velocity_rad_s": 0.0,
        "initial_canonical_rate_rad_s": 0.4,
        "public_maximum_motor_impulse_nms": 0.002,
        "joint_limits_enabled": False,
        "lower_limit_rad": -1.0,
        "upper_limit_rad": 1.0,
        "retained_step_count": 4,
    },
    {
        "cell_id": "brake_negative",
        "family": "signed_braking",
        "motor_enabled": True,
        "canonical_target_velocity_rad_s": 0.0,
        "initial_canonical_rate_rad_s": -0.4,
        "public_maximum_motor_impulse_nms": 0.002,
        "joint_limits_enabled": False,
        "lower_limit_rad": -1.0,
        "upper_limit_rad": 1.0,
        "retained_step_count": 4,
    },
    {
        "cell_id": "disabled_positive",
        "family": "motor_disabled",
        "motor_enabled": False,
        "canonical_target_velocity_rad_s": 0.0,
        "initial_canonical_rate_rad_s": 0.4,
        "public_maximum_motor_impulse_nms": 0.002,
        "joint_limits_enabled": False,
        "lower_limit_rad": -1.0,
        "upper_limit_rad": 1.0,
        "retained_step_count": 4,
    },
    {
        "cell_id": "disabled_negative",
        "family": "motor_disabled",
        "motor_enabled": False,
        "canonical_target_velocity_rad_s": 0.0,
        "initial_canonical_rate_rad_s": -0.4,
        "public_maximum_motor_impulse_nms": 0.002,
        "joint_limits_enabled": False,
        "lower_limit_rad": -1.0,
        "upper_limit_rad": 1.0,
        "retained_step_count": 4,
    },
    {
        "cell_id": "limit_positive",
        "family": "limit_active_separation",
        "motor_enabled": True,
        "canonical_target_velocity_rad_s": 2.0,
        "initial_canonical_rate_rad_s": 0.0,
        "public_maximum_motor_impulse_nms": 0.01,
        "joint_limits_enabled": True,
        "lower_limit_rad": -0.02,
        "upper_limit_rad": 0.02,
        "retained_step_count": 20,
    },
    {
        "cell_id": "limit_negative",
        "family": "limit_active_separation",
        "motor_enabled": True,
        "canonical_target_velocity_rad_s": -2.0,
        "initial_canonical_rate_rad_s": 0.0,
        "public_maximum_motor_impulse_nms": 0.01,
        "joint_limits_enabled": True,
        "lower_limit_rad": -0.02,
        "upper_limit_rad": 0.02,
        "retained_step_count": 20,
    },
    {
        "cell_id": "sleep_stale",
        "family": "sleeping_freshness",
        "motor_enabled": True,
        "canonical_target_velocity_rad_s": 0.0,
        "initial_canonical_rate_rad_s": 0.0,
        "public_maximum_motor_impulse_nms": 0.002,
        "joint_limits_enabled": False,
        "lower_limit_rad": -1.0,
        "upper_limit_rad": 1.0,
        "retained_step_count": 4,
    },
]
CELL_IDS = [str(value["cell_id"]) for value in CELL_CONFIG]
CELL_BY_ID = {str(value["cell_id"]): value for value in CELL_CONFIG}

TELEMETRY_KEYS = {
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
SAMPLE_KEYS = {
    "step_index",
    "pre_canonical_relative_rate_rad_s",
    "post_canonical_relative_rate_rad_s",
    "inverse_inertia_axis_kg_inv_m2",
    "integrated_canonical_angle_rad",
    "host_target_velocity_readback_rad_s",
    "joint_limit_lower_readback_rad",
    "joint_limit_upper_readback_rad",
    "telemetry",
    "child_sleeping",
}
PARAMETER_KEYS = {
    "child_mass_kg",
    "child_inertia_diagonal_kg_m2",
    "gravity_scale",
    "linear_damping",
    "angular_damping",
    "collision_layer",
    "collision_mask",
    "motor_enabled",
    "joint_limits_enabled",
    "host_target_velocity_rad_s",
    "public_maximum_motor_impulse_nms",
    "lower_limit_rad",
    "upper_limit_rad",
    "anchor_error_m",
    "axis_error_rad",
}
CLAIM_FALSE_FIELDS = {
    "numerical_accuracy_accepted",
    "instrumented_profile_promoted",
    "stock_godot_profile_promoted",
    "recovery_claimed",
    "prone_to_standing_claimed",
    "turning_claim_changed",
    "cross_engine_equivalence_claimed",
    "physical_acceptance_authority",
    "release_authority",
}

DECLARED_NEGATIVES = [
    "duplicate_json_key_rejected",
    "schema_mutation_rejected",
    "gate_id_mutation_rejected",
    "question_class_promotion_rejected",
    "authorization_closure_identity_mutation_rejected",
    "patch_identity_mutation_rejected",
    "runtime_binary_pair_identity_mutation_rejected",
    "world_count_mutation_rejected",
    "cell_count_mutation_rejected",
    "cell_omission_rejected",
    "cell_order_mutation_rejected",
    "duplicate_cell_identity_rejected",
    "sample_omission_rejected",
    "sample_order_mutation_rejected",
    "non_finite_numeric_encoding_rejected",
    "telemetry_schema_mutation_rejected",
    "telemetry_field_omission_rejected",
    "non_integer_telemetry_sequence_rejected",
    "non_integer_capture_sequence_rejected",
    "non_integer_read_sequence_rejected",
    "active_capture_false_rejected",
    "active_current_false_rejected",
    "sleeping_stale_current_true_rejected",
    "sleeping_stale_telemetry_advance_rejected",
    "direct_force_write_mutation_rejected",
    "direct_torque_write_mutation_rejected",
    "direct_impulse_write_mutation_rejected",
    "post_activation_transform_write_mutation_rejected",
    "outcome_dependent_early_stop_mutation_rejected",
    "contact_count_mutation_rejected",
    "fixture_axis_sign_mutation_rejected",
    "fixture_inertia_representation_mutation_rejected",
    "parameter_readback_mutation_rejected",
    "limit_readback_mutation_rejected",
    "invalid_rid_non_refusal_rejected",
    "not_in_tree_non_refusal_rejected",
    "motor_state_mutation_rejected",
    "non_positive_solver_step_rejected",
    "cap_source_mutation_rejected",
    "work_decomposition_mutation_rejected",
    "numerical_accuracy_claim_promotion_rejected",
    "instrumented_profile_promotion_rejected",
    "recovery_claim_promotion_rejected",
    "prone_to_standing_claim_promotion_rejected",
    "cross_engine_claim_promotion_rejected",
    "release_claim_promotion_rejected",
]


class EvaluationError(ValueError):
    """A stable fail-closed report rejection."""


def _fail(code: str) -> None:
    raise EvaluationError(code)


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        if key in value:
            _fail(f"duplicate_json_key:{key}")
        value[key] = item
    return value


def _reject_constant(value: str) -> Any:
    _fail(f"non_finite_json_constant:{value}")


def strict_loads(text: str) -> dict[str, Any]:
    try:
        value = json.loads(
            text,
            object_pairs_hook=_reject_duplicate_keys,
            parse_constant=_reject_constant,
        )
    except EvaluationError:
        raise
    except (json.JSONDecodeError, TypeError, ValueError) as exc:
        raise EvaluationError(f"invalid_json:{exc}") from exc
    if not isinstance(value, dict):
        _fail("report_not_object")
    return value


def _dict(value: Any, code: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(code)
    return value


def _list(value: Any, code: str) -> list[Any]:
    if not isinstance(value, list):
        _fail(code)
    return value


def _string(value: Any, code: str) -> str:
    if not isinstance(value, str):
        _fail(code)
    return value


def _boolean(value: Any, code: str) -> bool:
    if not isinstance(value, bool):
        _fail(code)
    return value


def _integer(value: Any, code: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        _fail(code)
    return value


def _finite(value: Any, code: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        _fail(code)
    result = float(value)
    if not math.isfinite(result):
        _fail(code)
    return result


def _exact_keys(value: dict[str, Any], expected: set[str], code: str) -> None:
    if set(value) != expected:
        _fail(code)


def _exact_mapping(value: Any, expected: dict[str, Any], code: str) -> None:
    observed = _dict(value, f"{code}_not_object")
    _exact_keys(observed, set(expected), f"{code}_field_set")
    if observed != expected:
        _fail(code)


def _exact_vector(value: Any, expected: list[float], code: str) -> None:
    observed = _list(value, f"{code}_not_array")
    if len(observed) != len(expected):
        _fail(f"{code}_length")
    if [_finite(item, f"{code}_numeric") for item in observed] != expected:
        _fail(code)


def _valid_identity(value: Any, length: int, code: str) -> str:
    text = _string(value, code)
    if len(text) != length or re.fullmatch(r"[0-9a-f]+", text) is None:
        _fail(code)
    return text


def _validate_engine(value: Any) -> None:
    engine = _dict(value, "engine_not_object")
    expected = {
        "physics_engine": "Jolt Physics",
        "physics_ticks_per_second": 120,
        "solver_velocity_steps": 20,
        "solver_position_steps": 7,
        "thread_model": "single_safe",
        "telemetry_class_registered": True,
        "telemetry_method_registered": True,
    }
    _exact_keys(engine, set(expected), "engine_field_set")
    for key, expected_value in expected.items():
        if engine.get(key) != expected_value or type(engine.get(key)) is not type(expected_value):
            _fail(f"engine_{key}")


def _validate_fixture(value: Any) -> None:
    fixture = _dict(value, "fixture_not_object")
    _exact_keys(
        fixture,
        {
            "fixture_id",
            "world_count",
            "isolated_cell_count",
            "cell_ids_in_order",
            "hinges_per_cell",
            "dynamic_bodies_per_cell",
            "static_parents_per_cell",
            "child_mass_kg",
            "child_inertia_diagonal_kg_m2",
            "hinge_axis_parent_local",
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
    exact = {
        "fixture_id": FIXTURE_ID,
        "world_count": 1,
        "isolated_cell_count": 9,
        "cell_ids_in_order": CELL_IDS,
        "hinges_per_cell": 1,
        "dynamic_bodies_per_cell": 1,
        "static_parents_per_cell": 1,
        "maximum_physics_step_count": 20,
        "retained_sample_count": 68,
        "collision_layer": 0,
        "collision_mask": 0,
        "contact_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
    }
    for key, expected_value in exact.items():
        if fixture.get(key) != expected_value or type(fixture.get(key)) is not type(expected_value):
            _fail(f"fixture_{key}")
    for key, expected_value in {
        "child_mass_kg": 1.0,
        "gravity_scale": 0.0,
        "linear_damping": 0.0,
        "angular_damping": 0.0,
    }.items():
        if _finite(fixture.get(key), f"fixture_{key}_type") != expected_value:
            _fail(f"fixture_{key}")
    _exact_vector(fixture.get("child_inertia_diagonal_kg_m2"), EXPECTED_INERTIA, "fixture_inertia")
    _exact_vector(fixture.get("hinge_axis_parent_local"), [0.0, 0.0, 1.0], "fixture_axis")


def _validate_parameter_readback(value: Any, expected: dict[str, Any], cell_id: str) -> None:
    readback = _dict(value, f"parameter_{cell_id}_not_object")
    _exact_keys(readback, PARAMETER_KEYS, f"parameter_{cell_id}_field_set")
    exact_numeric = {
        "child_mass_kg": 1.0,
        "gravity_scale": 0.0,
        "linear_damping": 0.0,
        "angular_damping": 0.0,
        "host_target_velocity_rad_s": -float(expected["canonical_target_velocity_rad_s"]),
        "public_maximum_motor_impulse_nms": EXPECTED_REAL_T_IMPULSE[
            float(expected["public_maximum_motor_impulse_nms"])
        ],
        "lower_limit_rad": EXPECTED_REAL_T_LIMIT[float(expected["lower_limit_rad"])],
        "upper_limit_rad": EXPECTED_REAL_T_LIMIT[float(expected["upper_limit_rad"])],
        "anchor_error_m": 0.0,
        "axis_error_rad": 0.0,
    }
    for key, expected_value in exact_numeric.items():
        if _finite(readback.get(key), f"parameter_{cell_id}_{key}_type") != expected_value:
            _fail(f"parameter_{cell_id}_{key}")
    _exact_vector(
        readback.get("child_inertia_diagonal_kg_m2"),
        EXPECTED_INERTIA,
        f"parameter_{cell_id}_inertia",
    )
    for key in ("collision_layer", "collision_mask"):
        if _integer(readback.get(key), f"parameter_{cell_id}_{key}_type") != 0:
            _fail(f"parameter_{cell_id}_{key}")
    for key in ("motor_enabled", "joint_limits_enabled"):
        if _boolean(readback.get(key), f"parameter_{cell_id}_{key}_type") is not expected[key]:
            _fail(f"parameter_{cell_id}_{key}")


def _validate_telemetry(value: Any, expected: dict[str, Any], code: str) -> dict[str, Any]:
    telemetry = _dict(value, f"{code}_not_object")
    _exact_keys(telemetry, TELEMETRY_KEYS, f"{code}_field_set")
    if _string(telemetry.get("schema"), f"{code}_schema_type") != TELEMETRY_SCHEMA:
        _fail(f"{code}_schema")
    for key in (
        "telemetry_sequence",
        "capture_space_step_sequence",
        "read_space_step_sequence",
    ):
        if _integer(telemetry.get(key), f"{code}_{key}_type") <= 0:
            _fail(f"{code}_{key}")
    _boolean(telemetry.get("captured_during_active_step"), f"{code}_active_type")
    _boolean(telemetry.get("snapshot_is_current_space_step"), f"{code}_current_type")
    if _finite(telemetry.get("solver_step_s"), f"{code}_solver_step_type") <= 0.0:
        _fail(f"{code}_solver_step")
    expected_state = "velocity" if bool(expected["motor_enabled"]) else "off"
    if _string(telemetry.get("motor_state"), f"{code}_motor_state_type") != expected_state:
        _fail(f"{code}_motor_state")
    if _finite(
        telemetry.get("target_angular_velocity_rad_s"),
        f"{code}_target_type",
    ) != float(expected["canonical_target_velocity_rad_s"]):
        _fail(f"{code}_target")
    for key in (
        "min_torque_limit_nm",
        "max_torque_limit_nm",
        "signed_motor_impulse_nms",
        "positive_motor_work_j",
        "absorbed_motor_work_j",
        "net_motor_work_j",
    ):
        _finite(telemetry.get(key), f"{code}_{key}_type")
    return telemetry


def _validate_cells(value: Any) -> list[dict[str, Any]]:
    cells = _list(value, "cells_not_array")
    if len(cells) != 9:
        _fail("cell_count")
    observed_ids: list[str] = []
    retained_count = 0
    validated: list[dict[str, Any]] = []
    for cell_index, (cell_value, expected) in enumerate(zip(cells, CELL_CONFIG), start=1):
        cell = _dict(cell_value, f"cell_{cell_index}_not_object")
        _exact_keys(
            cell,
            set(expected) | {"pre_tree_read_refused", "parameter_readback", "samples"},
            f"cell_{cell_index}_field_set",
        )
        cell_id = _string(cell.get("cell_id"), f"cell_{cell_index}_id_type")
        observed_ids.append(cell_id)
        if cell_id != expected["cell_id"]:
            _fail(f"cell_{cell_index}_identity_or_order")
        for key, expected_value in expected.items():
            if cell.get(key) != expected_value or type(cell.get(key)) is not type(expected_value):
                _fail(f"cell_{cell_id}_{key}")
        if not _boolean(cell.get("pre_tree_read_refused"), f"cell_{cell_id}_pre_tree_type"):
            _fail(f"cell_{cell_id}_pre_tree_refusal")
        _validate_parameter_readback(cell.get("parameter_readback"), expected, cell_id)
        samples = _list(cell.get("samples"), f"cell_{cell_id}_samples_not_array")
        expected_steps = int(expected["retained_step_count"])
        if len(samples) != expected_steps:
            _fail(f"cell_{cell_id}_sample_count")
        retained_count += len(samples)
        prior_telemetry = 0
        prior_capture = 0
        prior_read = 0
        sleep_first_telemetry = 0
        sleep_first_capture = 0
        for step_index, sample_value in enumerate(samples, start=1):
            code = f"cell_{cell_id}_sample_{step_index}"
            sample = _dict(sample_value, f"{code}_not_object")
            _exact_keys(sample, SAMPLE_KEYS, f"{code}_field_set")
            if _integer(sample.get("step_index"), f"{code}_step_type") != step_index:
                _fail(f"{code}_order")
            for key in (
                "pre_canonical_relative_rate_rad_s",
                "post_canonical_relative_rate_rad_s",
                "integrated_canonical_angle_rad",
            ):
                _finite(sample.get(key), f"{code}_{key}_type")
            if _finite(
                sample.get("inverse_inertia_axis_kg_inv_m2"),
                f"{code}_inverse_inertia_type",
            ) <= 0.0:
                _fail(f"{code}_inverse_inertia")
            expected_host_target = -float(expected["canonical_target_velocity_rad_s"])
            if _finite(sample.get("host_target_velocity_readback_rad_s"), f"{code}_host_target_type") != expected_host_target:
                _fail(f"{code}_host_target")
            for key, expected_value in (
                (
                    "joint_limit_lower_readback_rad",
                    EXPECTED_REAL_T_LIMIT[float(expected["lower_limit_rad"])],
                ),
                (
                    "joint_limit_upper_readback_rad",
                    EXPECTED_REAL_T_LIMIT[float(expected["upper_limit_rad"])],
                ),
            ):
                if _finite(sample.get(key), f"{code}_{key}_type") != expected_value:
                    _fail(f"{code}_{key}")
            child_sleeping = _boolean(sample.get("child_sleeping"), f"{code}_sleep_type")
            telemetry = _validate_telemetry(sample.get("telemetry"), expected, f"{code}_telemetry")
            sequence = _integer(telemetry["telemetry_sequence"], f"{code}_sequence_type")
            capture = _integer(telemetry["capture_space_step_sequence"], f"{code}_capture_type")
            read = _integer(telemetry["read_space_step_sequence"], f"{code}_read_type")
            active = _boolean(telemetry["captured_during_active_step"], f"{code}_active_type")
            current = _boolean(telemetry["snapshot_is_current_space_step"], f"{code}_current_type")
            if cell_id == "sleep_stale" and step_index > 1:
                if not child_sleeping:
                    _fail(f"{code}_not_sleeping")
                if not active or current:
                    _fail(f"{code}_stale_timing")
                if sequence != sleep_first_telemetry or capture != sleep_first_capture:
                    _fail(f"{code}_stale_snapshot_advanced")
                if read <= prior_read or read <= capture:
                    _fail(f"{code}_stale_read_not_advanced")
            else:
                if child_sleeping:
                    _fail(f"{code}_unexpected_sleep")
                if not active or not current or capture != read:
                    _fail(f"{code}_active_timing")
                if sequence <= prior_telemetry or capture <= prior_capture:
                    _fail(f"{code}_active_sequence_not_advanced")
                if cell_id == "sleep_stale":
                    sleep_first_telemetry = sequence
                    sleep_first_capture = capture
            prior_telemetry = sequence
            prior_capture = capture
            prior_read = read
        validated.append(cell)
    if observed_ids != CELL_IDS or len(set(observed_ids)) != 9:
        _fail("cell_identity_order_or_uniqueness")
    if retained_count != 68:
        _fail("retained_sample_count")
    return validated


def _validate_execution(value: Any) -> None:
    execution = _dict(value, "execution_not_object")
    expected = {
        "world_attempt_count": 1,
        "world_build_count": 1,
        "physics_step_count": 20,
        "retained_sample_count": 68,
        "direct_force_write_count": 0,
        "direct_torque_write_count": 0,
        "direct_impulse_write_count": 0,
        "post_activation_transform_write_count": 0,
        "pre_activation_initial_angular_velocity_write_count": 4,
        "declared_sleep_input_write_count": 1,
        "pre_sample_physics_frame_count": 1,
        "terminal_physics_server_deactivation_count": 1,
        "outcome_dependent_early_stop_count": 0,
    }
    _exact_keys(execution, set(expected), "execution_field_set")
    for key, expected_value in expected.items():
        if _integer(execution.get(key), f"execution_{key}_type") != expected_value:
            _fail(f"execution_{key}")


def _validate_claims(value: Any) -> None:
    claims = _dict(value, "claims_not_object")
    expected_keys = CLAIM_FALSE_FIELDS | {
        "descriptive_development_characterization_only",
        "descriptive_findings_are_acceptance_gates",
    }
    _exact_keys(claims, expected_keys, "claims_field_set")
    if not _boolean(
        claims.get("descriptive_development_characterization_only"),
        "descriptive_claim_type",
    ):
        _fail("descriptive_claim")
    if _boolean(
        claims.get("descriptive_findings_are_acceptance_gates"),
        "descriptive_gate_claim_type",
    ):
        _fail("descriptive_gate_claim")
    for key in CLAIM_FALSE_FIELDS:
        if _boolean(claims.get(key), f"claim_{key}_type"):
            _fail(f"claim_{key}")


def validate_report(
    report: dict[str, Any],
    expected_source_commit: str,
    expected_nonce: str,
    expected_evidence_kind: str,
) -> list[dict[str, Any]]:
    _exact_keys(
        report,
        {
            "schema_version",
            "gate_id",
            "question_class",
            "evidence_kind",
            "source_commit",
            "execution_nonce",
            "authorization",
            "runtime_provenance",
            "engine",
            "fixture",
            "refusals",
            "recomputation_contract",
            "cells",
            "execution",
            "evidence_provenance",
            "claims",
        },
        "top_level_field_set",
    )
    if report.get("schema_version") != RAW_SCHEMA:
        _fail("schema_version")
    if report.get("gate_id") != GATE_ID:
        _fail("gate_id")
    if report.get("question_class") != "development":
        _fail("question_class")
    if report.get("evidence_kind") != expected_evidence_kind or expected_evidence_kind not in {
        "synthetic_zero_world",
        "native_physical",
    }:
        _fail("evidence_kind")
    _valid_identity(report.get("source_commit"), 40, "source_commit_format")
    _valid_identity(report.get("execution_nonce"), 32, "execution_nonce_format")
    if report.get("source_commit") != expected_source_commit:
        _fail("source_commit")
    if report.get("execution_nonce") != expected_nonce:
        _fail("execution_nonce")
    _exact_mapping(report.get("authorization"), AUTHORIZATION, "authorization")
    _exact_mapping(report.get("runtime_provenance"), RUNTIME_PROVENANCE, "runtime_provenance")
    _exact_mapping(
        report.get("recomputation_contract"),
        RECOMPUTATION_CONTRACT,
        "recomputation_contract",
    )
    _validate_engine(report.get("engine"))
    _validate_fixture(report.get("fixture"))
    refusals = _dict(report.get("refusals"), "refusals_not_object")
    _exact_keys(
        refusals,
        {"invalid_rid_refused", "not_in_tree_joint_read_refused_by_cell"},
        "refusals_field_set",
    )
    if not _boolean(refusals.get("invalid_rid_refused"), "invalid_rid_refusal_type"):
        _fail("invalid_rid_not_refused")
    pre_tree = _dict(
        refusals.get("not_in_tree_joint_read_refused_by_cell"),
        "pre_tree_refusals_not_object",
    )
    _exact_keys(pre_tree, set(CELL_IDS), "pre_tree_refusal_field_set")
    if any(not _boolean(pre_tree.get(cell_id), f"pre_tree_{cell_id}_type") for cell_id in CELL_IDS):
        _fail("not_in_tree_joint_not_refused")
    cells = _validate_cells(report.get("cells"))
    _validate_execution(report.get("execution"))
    provenance = _dict(report.get("evidence_provenance"), "evidence_provenance_not_object")
    _exact_keys(
        provenance,
        {"synthetic_shape_only", "native_physical_observation"},
        "evidence_provenance_field_set",
    )
    expected_synthetic = expected_evidence_kind == "synthetic_zero_world"
    if _boolean(provenance.get("synthetic_shape_only"), "synthetic_shape_type") is not expected_synthetic:
        _fail("synthetic_shape_only")
    if _boolean(
        provenance.get("native_physical_observation"),
        "native_observation_type",
    ) is expected_synthetic:
        _fail("native_physical_observation")
    _validate_claims(report.get("claims"))
    return cells


def evaluate_report(
    report: dict[str, Any],
    expected_source_commit: str,
    expected_nonce: str,
    expected_evidence_kind: str,
) -> dict[str, Any]:
    cells = validate_report(
        report,
        expected_source_commit,
        expected_nonce,
        expected_evidence_kind,
    )
    evaluated_cells: list[dict[str, Any]] = []
    included_count = 0
    stale_excluded_count = 0
    cap_observation_count = 0
    within_cap_count = 0
    maximum_abs_impulse_residual = 0.0
    maximum_abs_work_residual = 0.0
    maximum_abs_decomposition_residual = 0.0
    maximum_abs_angle_integral_residual = 0.0
    for cell in cells:
        cell_samples: list[dict[str, Any]] = []
        prior_angle = 0.0
        for sample in cell["samples"]:
            telemetry = sample["telemetry"]
            stale = (
                cell["cell_id"] == "sleep_stale"
                and int(sample["step_index"]) > 1
            )
            effective_inertia = 1.0 / float(sample["inverse_inertia_axis_kg_inv_m2"])
            pre_rate = float(sample["pre_canonical_relative_rate_rad_s"])
            post_rate = float(sample["post_canonical_relative_rate_rad_s"])
            dt = float(telemetry["solver_step_s"])
            independent_impulse = effective_inertia * (post_rate - pre_rate)
            independent_energy = 0.5 * effective_inertia * (
                post_rate * post_rate - pre_rate * pre_rate
            )
            signed_impulse = float(telemetry["signed_motor_impulse_nms"])
            net_work = float(telemetry["net_motor_work_j"])
            decomposition = float(telemetry["positive_motor_work_j"]) - float(
                telemetry["absorbed_motor_work_j"]
            )
            cap = max(
                abs(float(telemetry["min_torque_limit_nm"])),
                abs(float(telemetry["max_torque_limit_nm"])),
            ) * dt
            impulse_residual = signed_impulse - independent_impulse
            work_residual = net_work - independent_energy
            decomposition_residual = net_work - decomposition
            recomputed_angle = prior_angle + 0.5 * (pre_rate + post_rate) * dt
            angle_residual = float(sample["integrated_canonical_angle_rad"]) - recomputed_angle
            included = not stale
            if included:
                included_count += 1
                cap_observation_count += 1
                within_cap_count += int(abs(signed_impulse) <= cap)
                maximum_abs_impulse_residual = max(
                    maximum_abs_impulse_residual,
                    abs(impulse_residual),
                )
                maximum_abs_work_residual = max(
                    maximum_abs_work_residual,
                    abs(work_residual),
                )
                maximum_abs_decomposition_residual = max(
                    maximum_abs_decomposition_residual,
                    abs(decomposition_residual),
                )
                maximum_abs_angle_integral_residual = max(
                    maximum_abs_angle_integral_residual,
                    abs(angle_residual),
                )
            else:
                stale_excluded_count += 1
            cell_samples.append(
                {
                    "step_index": sample["step_index"],
                    "numerical_aggregate_included": included,
                    "snapshot_current": telemetry["snapshot_is_current_space_step"],
                    "effective_axis_inertia_kg_m2": effective_inertia,
                    "independent_angular_momentum_change_nms": independent_impulse,
                    "independent_kinetic_energy_change_j": independent_energy,
                    "signed_motor_impulse_nms": signed_impulse,
                    "positive_motor_work_j": telemetry["positive_motor_work_j"],
                    "absorbed_motor_work_j": telemetry["absorbed_motor_work_j"],
                    "net_motor_work_j": net_work,
                    "impulse_residual_nms": impulse_residual,
                    "work_residual_j": work_residual,
                    "net_work_decomposition_residual_j": decomposition_residual,
                    "motor_impulse_cap_nms": cap,
                    "within_source_derived_hard_solver_cap": abs(signed_impulse) <= cap,
                    "relative_angle_integral_residual_rad": angle_residual,
                    "integrated_canonical_angle_rad": sample["integrated_canonical_angle_rad"],
                }
            )
            prior_angle = float(sample["integrated_canonical_angle_rad"])
        evaluated_cells.append(
            {
                "cell_id": cell["cell_id"],
                "family": cell["family"],
                "motor_enabled": cell["motor_enabled"],
                "joint_limits_enabled": cell["joint_limits_enabled"],
                "samples": cell_samples,
            }
        )
    canonical = json.dumps(
        report,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    physical = expected_evidence_kind == "native_physical"
    return {
        "schema_version": EVALUATION_SCHEMA,
        "ok": True,
        "gate_id": GATE_ID,
        "question_class": "development",
        "evidence_kind": expected_evidence_kind,
        "result": (
            "complete_valid_finite_descriptive_native_numerical_characterization"
            if physical
            else "synthetic_shape_conforms_zero_world_only"
        ),
        "source_commit": expected_source_commit,
        "execution_nonce": expected_nonce,
        "raw_report_canonical_sha256": "sha256:" + hashlib.sha256(canonical).hexdigest(),
        "execution_valid": True,
        "descriptive_findings_are_acceptance_gates": False,
        "summary": {
            "cell_count": 9,
            "retained_sample_count": 68,
            "current_numerical_aggregate_sample_count": included_count,
            "sleeping_stale_excluded_sample_count": stale_excluded_count,
            "source_derived_hard_cap_observation_count": cap_observation_count,
            "within_source_derived_hard_cap_count": within_cap_count,
            "maximum_absolute_impulse_residual_nms": maximum_abs_impulse_residual,
            "maximum_absolute_work_residual_j": maximum_abs_work_residual,
            "maximum_absolute_net_work_decomposition_residual_j": (
                maximum_abs_decomposition_residual
            ),
            "maximum_absolute_relative_angle_integral_residual_rad": (
                maximum_abs_angle_integral_residual
            ),
        },
        "cells": evaluated_cells,
        "empirical_acceptance_threshold_count": 0,
        "superiority_margin_count": 0,
        "equivalence_or_non_inferiority_margin_count": 0,
        "held_out_validation_cohort_count": 0,
        "population_claim_count": 0,
        "native_numerical_telemetry_characterized": physical,
        "numerical_accuracy_accepted": False,
        "instrumented_profile_promoted": False,
        "recovery_claimed": False,
        "prone_to_standing_claimed": False,
        "turning_claim_changed": False,
        "cross_engine_equivalence_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def synthetic_report(
    source_commit: str = EXPECTED_SOURCE,
    nonce: str = EXPECTED_NONCE,
) -> dict[str, Any]:
    cells: list[dict[str, Any]] = []
    pre_tree = {cell_id: True for cell_id in CELL_IDS}
    retained_count = 0
    for expected in CELL_CONFIG:
        cell_id = str(expected["cell_id"])
        target = float(expected["canonical_target_velocity_rad_s"])
        rate = float(expected["initial_canonical_rate_rad_s"])
        motor_enabled = bool(expected["motor_enabled"])
        impulse_limit = float(expected["public_maximum_motor_impulse_nms"])
        dt = 1.0 / 120.0
        angle = 0.0
        samples: list[dict[str, Any]] = []
        first_sequence = 1
        for step_index in range(1, int(expected["retained_step_count"]) + 1):
            stale = cell_id == "sleep_stale" and step_index > 1
            pre_rate = rate
            if stale:
                post_rate = rate
                sequence = first_sequence
                capture = first_sequence
            elif not motor_enabled:
                post_rate = pre_rate
                sequence = step_index
                capture = step_index
            else:
                delta = max(-0.04, min(0.04, target - pre_rate))
                post_rate = pre_rate + delta
                sequence = step_index
                capture = step_index
            read = step_index
            angle += 0.5 * (pre_rate + post_rate) * dt
            impulse = 0.0 if stale or not motor_enabled else 0.05 * (post_rate - pre_rate)
            energy = 0.0 if stale else 0.5 * 0.05 * (
                post_rate * post_rate - pre_rate * pre_rate
            )
            positive_work = max(0.0, energy)
            absorbed_work = max(0.0, -energy)
            samples.append(
                {
                    "step_index": step_index,
                    "pre_canonical_relative_rate_rad_s": pre_rate,
                    "post_canonical_relative_rate_rad_s": post_rate,
                    "inverse_inertia_axis_kg_inv_m2": 20.0,
                    "integrated_canonical_angle_rad": angle,
                    "host_target_velocity_readback_rad_s": -target,
                    "joint_limit_lower_readback_rad": EXPECTED_REAL_T_LIMIT[
                        float(expected["lower_limit_rad"])
                    ],
                    "joint_limit_upper_readback_rad": EXPECTED_REAL_T_LIMIT[
                        float(expected["upper_limit_rad"])
                    ],
                    "telemetry": {
                        "schema": TELEMETRY_SCHEMA,
                        "telemetry_sequence": sequence,
                        "capture_space_step_sequence": capture,
                        "read_space_step_sequence": read,
                        "captured_during_active_step": True,
                        "snapshot_is_current_space_step": not stale,
                        "solver_step_s": dt,
                        "motor_state": "velocity" if motor_enabled else "off",
                        "target_angular_velocity_rad_s": target,
                        "min_torque_limit_nm": -impulse_limit / dt,
                        "max_torque_limit_nm": impulse_limit / dt,
                        "signed_motor_impulse_nms": impulse,
                        "positive_motor_work_j": positive_work,
                        "absorbed_motor_work_j": absorbed_work,
                        "net_motor_work_j": positive_work - absorbed_work,
                    },
                    "child_sleeping": stale,
                }
            )
            rate = post_rate
        retained_count += len(samples)
        cells.append(
            {
                **copy.deepcopy(expected),
                "pre_tree_read_refused": True,
                "parameter_readback": {
                    "child_mass_kg": 1.0,
                    "child_inertia_diagonal_kg_m2": list(EXPECTED_INERTIA),
                    "gravity_scale": 0.0,
                    "linear_damping": 0.0,
                    "angular_damping": 0.0,
                    "collision_layer": 0,
                    "collision_mask": 0,
                    "motor_enabled": motor_enabled,
                    "joint_limits_enabled": bool(expected["joint_limits_enabled"]),
                    "host_target_velocity_rad_s": -target,
                    "public_maximum_motor_impulse_nms": EXPECTED_REAL_T_IMPULSE[
                        impulse_limit
                    ],
                    "lower_limit_rad": EXPECTED_REAL_T_LIMIT[
                        float(expected["lower_limit_rad"])
                    ],
                    "upper_limit_rad": EXPECTED_REAL_T_LIMIT[
                        float(expected["upper_limit_rad"])
                    ],
                    "anchor_error_m": 0.0,
                    "axis_error_rad": 0.0,
                },
                "samples": samples,
            }
        )
    return {
        "schema_version": RAW_SCHEMA,
        "gate_id": GATE_ID,
        "question_class": "development",
        "evidence_kind": "synthetic_zero_world",
        "source_commit": source_commit,
        "execution_nonce": nonce,
        "authorization": copy.deepcopy(AUTHORIZATION),
        "runtime_provenance": copy.deepcopy(RUNTIME_PROVENANCE),
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
            "isolated_cell_count": 9,
            "cell_ids_in_order": list(CELL_IDS),
            "hinges_per_cell": 1,
            "dynamic_bodies_per_cell": 1,
            "static_parents_per_cell": 1,
            "child_mass_kg": 1.0,
            "child_inertia_diagonal_kg_m2": list(EXPECTED_INERTIA),
            "hinge_axis_parent_local": [0.0, 0.0, 1.0],
            "maximum_physics_step_count": 20,
            "retained_sample_count": 68,
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
            "not_in_tree_joint_read_refused_by_cell": pre_tree,
        },
        "recomputation_contract": copy.deepcopy(RECOMPUTATION_CONTRACT),
        "cells": cells,
        "execution": {
            "world_attempt_count": 1,
            "world_build_count": 1,
            "physics_step_count": 20,
            "retained_sample_count": retained_count,
            "direct_force_write_count": 0,
            "direct_torque_write_count": 0,
            "direct_impulse_write_count": 0,
            "post_activation_transform_write_count": 0,
            "pre_activation_initial_angular_velocity_write_count": 4,
            "declared_sleep_input_write_count": 1,
            "pre_sample_physics_frame_count": 1,
            "terminal_physics_server_deactivation_count": 1,
            "outcome_dependent_early_stop_count": 0,
        },
        "evidence_provenance": {
            "synthetic_shape_only": True,
            "native_physical_observation": False,
        },
        "claims": {
            "descriptive_development_characterization_only": True,
            "descriptive_findings_are_acceptance_gates": False,
            "numerical_accuracy_accepted": False,
            "instrumented_profile_promoted": False,
            "stock_godot_profile_promoted": False,
            "recovery_claimed": False,
            "prone_to_standing_claimed": False,
            "turning_claim_changed": False,
            "cross_engine_equivalence_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
    }


def _set_path(path: tuple[Any, ...], value: Any) -> Callable[[dict[str, Any]], None]:
    def mutate(document: dict[str, Any]) -> None:
        target: Any = document
        for part in path[:-1]:
            target = target[part]
        target[path[-1]] = value

    return mutate


def self_test() -> dict[str, Any]:
    base = synthetic_report()
    evaluation = evaluate_report(
        copy.deepcopy(base),
        EXPECTED_SOURCE,
        EXPECTED_NONCE,
        "synthetic_zero_world",
    )
    if evaluation["result"] != "synthetic_shape_conforms_zero_world_only":
        _fail("synthetic_baseline")
    duplicate_rejected = False
    try:
        strict_loads('{"gate_id":"x","gate_id":"y"}')
    except EvaluationError:
        duplicate_rejected = True
    if not duplicate_rejected:
        _fail("duplicate_json_key_control")

    mutations: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        ("schema_mutation_rejected", _set_path(("schema_version",), "mutated")),
        ("gate_id_mutation_rejected", _set_path(("gate_id",), "QSDK-X")),
        ("question_class_promotion_rejected", _set_path(("question_class",), "finite_decision")),
        (
            "authorization_closure_identity_mutation_rejected",
            _set_path(("authorization", "closure_raw_sha256"), "sha256:" + "0" * 64),
        ),
        (
            "patch_identity_mutation_rejected",
            _set_path(("runtime_provenance", "combined_patch_raw_sha256"), "sha256:" + "0" * 64),
        ),
        (
            "runtime_binary_pair_identity_mutation_rejected",
            _set_path(
                ("runtime_provenance", "toolchain_provenance_console_binary_raw_sha256"),
                "sha256:" + "0" * 64,
            ),
        ),
        ("world_count_mutation_rejected", _set_path(("fixture", "world_count"), 2)),
        ("cell_count_mutation_rejected", _set_path(("fixture", "isolated_cell_count"), 8)),
        ("cell_omission_rejected", lambda value: value["cells"].pop()),
        ("cell_order_mutation_rejected", lambda value: value["cells"].reverse()),
        ("duplicate_cell_identity_rejected", _set_path(("cells", 1, "cell_id"), "drive_positive")),
        ("sample_omission_rejected", lambda value: value["cells"][0]["samples"].pop()),
        ("sample_order_mutation_rejected", _set_path(("cells", 0, "samples", 1, "step_index"), 1)),
        (
            "non_finite_numeric_encoding_rejected",
            _set_path(("cells", 0, "samples", 0, "post_canonical_relative_rate_rad_s"), math.nan),
        ),
        (
            "telemetry_schema_mutation_rejected",
            _set_path(("cells", 0, "samples", 0, "telemetry", "schema"), "mutated"),
        ),
        (
            "telemetry_field_omission_rejected",
            lambda value: value["cells"][0]["samples"][0]["telemetry"].pop("net_motor_work_j"),
        ),
        (
            "non_integer_telemetry_sequence_rejected",
            _set_path(("cells", 0, "samples", 0, "telemetry", "telemetry_sequence"), 1.0),
        ),
        (
            "non_integer_capture_sequence_rejected",
            _set_path(("cells", 0, "samples", 0, "telemetry", "capture_space_step_sequence"), 1.0),
        ),
        (
            "non_integer_read_sequence_rejected",
            _set_path(("cells", 0, "samples", 0, "telemetry", "read_space_step_sequence"), 1.0),
        ),
        (
            "active_capture_false_rejected",
            _set_path(("cells", 0, "samples", 0, "telemetry", "captured_during_active_step"), False),
        ),
        (
            "active_current_false_rejected",
            _set_path(("cells", 0, "samples", 0, "telemetry", "snapshot_is_current_space_step"), False),
        ),
        (
            "sleeping_stale_current_true_rejected",
            _set_path(("cells", 8, "samples", 1, "telemetry", "snapshot_is_current_space_step"), True),
        ),
        (
            "sleeping_stale_telemetry_advance_rejected",
            _set_path(("cells", 8, "samples", 1, "telemetry", "telemetry_sequence"), 2),
        ),
        ("direct_force_write_mutation_rejected", _set_path(("execution", "direct_force_write_count"), 1)),
        ("direct_torque_write_mutation_rejected", _set_path(("execution", "direct_torque_write_count"), 1)),
        ("direct_impulse_write_mutation_rejected", _set_path(("execution", "direct_impulse_write_count"), 1)),
        (
            "post_activation_transform_write_mutation_rejected",
            _set_path(("execution", "post_activation_transform_write_count"), 1),
        ),
        (
            "outcome_dependent_early_stop_mutation_rejected",
            _set_path(("execution", "outcome_dependent_early_stop_count"), 1),
        ),
        ("contact_count_mutation_rejected", _set_path(("fixture", "contact_count"), 1)),
        ("fixture_axis_sign_mutation_rejected", _set_path(("fixture", "hinge_axis_parent_local"), [0.0, 0.0, -1.0])),
        ("fixture_inertia_representation_mutation_rejected", _set_path(("fixture", "child_inertia_diagonal_kg_m2"), [0.05, 0.05, 0.05])),
        ("parameter_readback_mutation_rejected", _set_path(("cells", 0, "parameter_readback", "child_mass_kg"), 2.0)),
        ("limit_readback_mutation_rejected", _set_path(("cells", 6, "samples", 0, "joint_limit_upper_readback_rad"), 0.02)),
        ("invalid_rid_non_refusal_rejected", _set_path(("refusals", "invalid_rid_refused"), False)),
        (
            "not_in_tree_non_refusal_rejected",
            _set_path(("refusals", "not_in_tree_joint_read_refused_by_cell", "drive_positive"), False),
        ),
        ("motor_state_mutation_rejected", _set_path(("cells", 0, "samples", 0, "telemetry", "motor_state"), "off")),
        ("non_positive_solver_step_rejected", _set_path(("cells", 0, "samples", 0, "telemetry", "solver_step_s"), 0.0)),
        (
            "cap_source_mutation_rejected",
            _set_path(("recomputation_contract", "motor_impulse_cap_nms"), "mutated"),
        ),
        (
            "work_decomposition_mutation_rejected",
            _set_path(("recomputation_contract", "net_work_decomposition_residual_j"), "mutated"),
        ),
        ("numerical_accuracy_claim_promotion_rejected", _set_path(("claims", "numerical_accuracy_accepted"), True)),
        ("instrumented_profile_promotion_rejected", _set_path(("claims", "instrumented_profile_promoted"), True)),
        ("recovery_claim_promotion_rejected", _set_path(("claims", "recovery_claimed"), True)),
        ("prone_to_standing_claim_promotion_rejected", _set_path(("claims", "prone_to_standing_claimed"), True)),
        ("cross_engine_claim_promotion_rejected", _set_path(("claims", "cross_engine_equivalence_claimed"), True)),
        ("release_claim_promotion_rejected", _set_path(("claims", "release_authority"), True)),
    ]
    expected_mutation_names = DECLARED_NEGATIVES[1:]
    if [name for name, _ in mutations] != expected_mutation_names:
        _fail("declared_negative_order")
    rejected = [DECLARED_NEGATIVES[0]]
    for name, mutate in mutations:
        candidate = copy.deepcopy(base)
        mutate(candidate)
        try:
            evaluate_report(candidate, EXPECTED_SOURCE, EXPECTED_NONCE, "synthetic_zero_world")
        except EvaluationError:
            rejected.append(name)
        else:
            _fail(f"mutation_accepted:{name}")

    accepted_outcome_mutations: list[str] = []
    for name, path, value in [
        (
            "opposite_signed_impulse",
            ("cells", 0, "samples", 0, "telemetry", "signed_motor_impulse_nms"),
            -0.002,
        ),
        (
            "large_finite_work_residual",
            ("cells", 0, "samples", 0, "telemetry", "net_motor_work_j"),
            1000.0,
        ),
        (
            "finite_hard_cap_exceedance",
            ("cells", 0, "samples", 0, "telemetry", "signed_motor_impulse_nms"),
            1.0,
        ),
    ]:
        candidate = copy.deepcopy(base)
        _set_path(path, value)(candidate)
        evaluate_report(candidate, EXPECTED_SOURCE, EXPECTED_NONCE, "synthetic_zero_world")
        accepted_outcome_mutations.append(name)
    if rejected != DECLARED_NEGATIVES or len(rejected) != 46:
        _fail("negative_control_count_or_identity")
    return {
        "ok": True,
        "schema_version": EVALUATION_SCHEMA,
        "gate_id": GATE_ID,
        "question_class": "development",
        "synthetic_cell_count": 9,
        "synthetic_sample_count": 68,
        "declared_negative_control_count": 46,
        "rejected_negative_control_count": len(rejected),
        "rejected_negative_controls": rejected,
        "accepted_descriptive_outcome_mutation_count": len(accepted_outcome_mutations),
        "accepted_descriptive_outcome_mutations": accepted_outcome_mutations,
        "empirical_acceptance_threshold_count": 0,
        "superiority_margin_count": 0,
        "equivalence_or_non_inferiority_margin_count": 0,
        "held_out_validation_cohort_count": 0,
        "population_claim_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _write_json(path: pathlib.Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, sort_keys=False, allow_nan=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--emit-zero-world-template", type=pathlib.Path)
    parser.add_argument("--input", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--expected-source-commit", default=EXPECTED_SOURCE)
    parser.add_argument("--expected-nonce", default=EXPECTED_NONCE)
    parser.add_argument(
        "--expected-evidence-kind",
        choices=("synthetic_zero_world", "native_physical"),
        default="synthetic_zero_world",
    )
    args = parser.parse_args()
    try:
        if args.self_test:
            receipt = self_test()
            print("QSDK_R24D9_EVALUATOR_SELF_TEST " + json.dumps(receipt, separators=(",", ":")))
            return 0
        if args.emit_zero_world_template is not None:
            _valid_identity(args.expected_source_commit, 40, "source_commit_format")
            _valid_identity(args.expected_nonce, 32, "execution_nonce_format")
            report = synthetic_report(args.expected_source_commit, args.expected_nonce)
            evaluate_report(
                copy.deepcopy(report),
                args.expected_source_commit,
                args.expected_nonce,
                "synthetic_zero_world",
            )
            _write_json(args.emit_zero_world_template, report)
            print(
                "QSDK_R24D9_ZERO_WORLD_TEMPLATE "
                + json.dumps(
                    {
                        "ok": True,
                        "path": str(args.emit_zero_world_template),
                        "cell_count": 9,
                        "retained_sample_count": 68,
                        "world_attempt_count": 0,
                        "world_build_count": 0,
                        "solver_step_count": 0,
                        "physical_acceptance_authority": False,
                        "release_authority": False,
                    },
                    separators=(",", ":"),
                )
            )
            return 0
        if args.input is None or args.output is None:
            parser.error("--input and --output are required unless a utility mode is selected")
        report = strict_loads(args.input.read_text(encoding="utf-8"))
        evaluation = evaluate_report(
            report,
            args.expected_source_commit,
            args.expected_nonce,
            args.expected_evidence_kind,
        )
        _write_json(args.output, evaluation)
        print("QSDK_R24D9_EVALUATION_PASS " + json.dumps(evaluation, separators=(",", ":")))
        return 0
    except EvaluationError as exc:
        print(
            "QSDK_R24D9_EVALUATION_FAILURE "
            + json.dumps(
                {
                    "ok": False,
                    "failure_code": str(exc),
                    "physical_acceptance_authority": False,
                    "release_authority": False,
                },
                separators=(",", ":"),
            )
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
