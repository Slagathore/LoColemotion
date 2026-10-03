#!/usr/bin/env python3
"""QSDK-R24D4 threshold-free one-hinge telemetry evaluator.

The evaluator separates execution validity from the observed telemetry outcome.
It rejects incomplete, malformed, reordered, or claim-promoted reports, then
computes signed impulse, momentum, work, energy, cap, limit, refusal, and
freshness measurements without applying an empirical acceptance threshold.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import pathlib
import sys
from typing import Any, Callable


SCHEMA = "sporespore_qsdk_r24d4_godot_jolt_one_hinge_raw_report_v1"
EVALUATION_SCHEMA = (
    "sporespore_qsdk_r24d4_godot_jolt_one_hinge_evaluation_v1"
)
TELEMETRY_SCHEMA = "sporespore.godot_jolt_hinge_motor_telemetry.v1"
EXPECTED_CELL_IDS = [
    "drive_positive",
    "drive_negative",
    "brake_positive",
    "brake_negative",
    "disabled_positive",
    "disabled_negative",
    "limit_positive",
    "limit_negative",
    "sleep_stale",
]
EXPECTED_CELL_CONFIGURATION: dict[str, dict[str, Any]] = {
    "drive_positive": {
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
    "drive_negative": {
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
    "brake_positive": {
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
    "brake_negative": {
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
    "disabled_positive": {
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
    "disabled_negative": {
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
    "limit_positive": {
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
    "limit_negative": {
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
    "sleep_stale": {
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
}
EXPECTED_FAMILIES = {
    cell_id: str(configuration["family"])
    for cell_id, configuration in EXPECTED_CELL_CONFIGURATION.items()
}
EXPECTED_STEPS = {
    cell_id: int(configuration["retained_step_count"])
    for cell_id, configuration in EXPECTED_CELL_CONFIGURATION.items()
}
EXPECTED_TOP_LEVEL = {
    "schema_version",
    "gate_id",
    "question_class",
    "source_commit",
    "execution_nonce",
    "engine",
    "fixture",
    "refusals",
    "cells",
    "execution",
    "claims",
}
EXPECTED_ENGINE_KEYS = {
    "physics_engine",
    "physics_ticks_per_second",
    "solver_velocity_steps",
    "solver_position_steps",
    "thread_model",
    "telemetry_class_registered",
    "telemetry_method_registered",
}
EXPECTED_FIXTURE_KEYS = {
    "fixture_id",
    "cell_count",
    "child_mass_kg",
    "child_inertia_diagonal_kg_m2",
    "hinge_axis_parent_local",
    "gravity_scale",
    "linear_damping",
    "angular_damping",
    "collision_layer",
    "collision_mask",
    "contact_count",
}
EXPECTED_REFUSAL_KEYS = {
    "invalid_rid_refused",
    "not_in_tree_joint_read_refused_by_cell",
}
EXPECTED_CELL_KEYS = {
    "cell_id",
    "family",
    "motor_enabled",
    "canonical_target_velocity_rad_s",
    "initial_canonical_rate_rad_s",
    "public_maximum_motor_impulse_nms",
    "joint_limits_enabled",
    "lower_limit_rad",
    "upper_limit_rad",
    "retained_step_count",
    "pre_tree_read_refused",
    "parameter_readback",
    "samples",
}
EXPECTED_PARAMETER_KEYS = {
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
EXPECTED_SAMPLE_KEYS = {
    "step_index",
    "pre_canonical_relative_rate_rad_s",
    "post_canonical_relative_rate_rad_s",
    "inverse_inertia_axis_kg_inv_m2",
    "integrated_canonical_angle_rad",
    "host_target_velocity_readback_rad_s",
    "joint_limit_lower_readback_rad",
    "joint_limit_upper_readback_rad",
    "telemetry",
    "stepping_read_attempt_count",
    "stepping_read_refusal_count",
    "child_sleeping",
}
EXPECTED_TELEMETRY_KEYS = {
    "schema",
    "telemetry_sequence",
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
EXPECTED_EXECUTION_KEYS = {
    "world_attempt_count",
    "world_build_count",
    "physics_step_count",
    "retained_sample_count",
    "direct_force_write_count",
    "direct_torque_write_count",
    "direct_impulse_write_count",
    "post_activation_transform_write_count",
    "pre_activation_initial_angular_velocity_write_count",
    "declared_sleep_input_write_count",
    "outcome_dependent_early_stop_count",
}
EXPECTED_CLAIM_KEYS = {
    "descriptive_development_characterization_only",
    "instrumented_profile_promoted",
    "stock_godot_profile_promoted",
    "recovery_claimed",
    "prone_to_standing_claimed",
    "turning_claim_changed",
    "cross_engine_equivalence_claimed",
    "physical_acceptance_authority",
    "release_authority",
}


class EvaluationError(ValueError):
    """Raised when an execution report is structurally invalid."""


def _reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise EvaluationError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def strict_loads(text: str) -> dict[str, Any]:
    try:
        value = json.loads(
            text,
            object_pairs_hook=_reject_duplicate_keys,
            parse_constant=lambda token: (_ for _ in ()).throw(
                EvaluationError(f"non-finite JSON constant: {token}")
            ),
        )
    except (json.JSONDecodeError, EvaluationError) as error:
        raise EvaluationError(str(error)) from error
    if not isinstance(value, dict):
        raise EvaluationError("top-level JSON value must be an object")
    return value


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise EvaluationError(code)


def _exact_keys(value: Any, expected: set[str], code: str) -> dict[str, Any]:
    _require(isinstance(value, dict), f"{code}_not_object")
    observed = set(value.keys())
    _require(observed == expected, f"{code}_keys:{sorted(observed ^ expected)}")
    return value


def _number(value: Any, code: str) -> float:
    _require(isinstance(value, (int, float)) and not isinstance(value, bool), code)
    result = float(value)
    _require(math.isfinite(result), code)
    return result


def _integer(value: Any, code: str, minimum: int | None = None) -> int:
    _require(isinstance(value, int) and not isinstance(value, bool), code)
    if minimum is not None:
        _require(value >= minimum, code)
    return value


def _boolean(value: Any, code: str) -> bool:
    _require(isinstance(value, bool), code)
    return value


def _numeric_vector(value: Any, count: int, code: str) -> list[float]:
    _require(isinstance(value, list) and len(value) == count, code)
    return [_number(item, f"{code}_{index}") for index, item in enumerate(value)]


def _validate_telemetry(value: Any, code: str) -> dict[str, Any] | None:
    if value is None:
        return None
    telemetry = _exact_keys(value, EXPECTED_TELEMETRY_KEYS, code)
    _require(telemetry["schema"] == TELEMETRY_SCHEMA, f"{code}_schema")
    _integer(telemetry["telemetry_sequence"], f"{code}_sequence", 1)
    _require(_number(telemetry["solver_step_s"], f"{code}_step") > 0.0, f"{code}_step")
    _require(
        telemetry["motor_state"] in {"off", "velocity", "position"},
        f"{code}_motor_state",
    )
    for key in EXPECTED_TELEMETRY_KEYS - {
        "schema",
        "telemetry_sequence",
        "motor_state",
    }:
        _number(telemetry[key], f"{code}_{key}")
    _require(telemetry["positive_motor_work_j"] >= 0.0, f"{code}_positive_work")
    _require(telemetry["absorbed_motor_work_j"] >= 0.0, f"{code}_absorbed_work")
    return telemetry


def validate_report(report: dict[str, Any]) -> None:
    _exact_keys(report, EXPECTED_TOP_LEVEL, "top_level")
    _require(report["schema_version"] == SCHEMA, "schema_version")
    _require(report["gate_id"] == "QSDK-R24D4", "gate_id")
    _require(report["question_class"] == "development", "question_class")
    _require(
        isinstance(report["source_commit"], str)
        and len(report["source_commit"]) == 40
        and all(character in "0123456789abcdef" for character in report["source_commit"]),
        "source_commit",
    )
    _require(
        isinstance(report["execution_nonce"], str)
        and len(report["execution_nonce"]) == 32
        and all(character in "0123456789abcdef" for character in report["execution_nonce"]),
        "execution_nonce",
    )

    engine = _exact_keys(report["engine"], EXPECTED_ENGINE_KEYS, "engine")
    _require(engine["physics_engine"] == "Jolt Physics", "engine_name")
    _require(engine["physics_ticks_per_second"] == 120, "physics_hz")
    _require(engine["solver_velocity_steps"] == 20, "velocity_steps")
    _require(engine["solver_position_steps"] == 7, "position_steps")
    _require(engine["thread_model"] == "single_safe", "thread_model")
    _require(
        _boolean(engine["telemetry_class_registered"], "telemetry_class_registered"),
        "telemetry_class_not_registered",
    )
    _require(
        _boolean(engine["telemetry_method_registered"], "telemetry_method_registered"),
        "telemetry_method_not_registered",
    )

    fixture = _exact_keys(report["fixture"], EXPECTED_FIXTURE_KEYS, "fixture")
    _require(
        fixture["fixture_id"] == "QSDK.R24D4.godot_jolt_one_hinge_telemetry.v1",
        "fixture_id",
    )
    _require(fixture["cell_count"] == 9, "fixture_cell_count")
    _require(_number(fixture["child_mass_kg"], "fixture_mass") == 1.0, "fixture_mass")
    fixture_inertia = _numeric_vector(
        fixture["child_inertia_diagonal_kg_m2"], 3, "fixture_inertia"
    )
    _require(
        fixture_inertia[0] > 0.0
        and fixture_inertia[0] == fixture_inertia[1] == fixture_inertia[2],
        "fixture_inertia_not_positive_spherical",
    )
    _require(
        _numeric_vector(fixture["hinge_axis_parent_local"], 3, "fixture_axis")
        == [0.0, 0.0, -1.0],
        "fixture_axis",
    )
    for key in ("gravity_scale", "linear_damping", "angular_damping"):
        _require(_number(fixture[key], f"fixture_{key}") == 0.0, f"fixture_{key}")
    for key in ("collision_layer", "collision_mask", "contact_count"):
        _require(_integer(fixture[key], f"fixture_{key}", 0) == 0, f"fixture_{key}")

    refusals = _exact_keys(report["refusals"], EXPECTED_REFUSAL_KEYS, "refusals")
    _require(
        _boolean(refusals["invalid_rid_refused"], "invalid_rid_refused"),
        "invalid_rid_not_refused",
    )
    pre_tree = refusals["not_in_tree_joint_read_refused_by_cell"]
    _require(isinstance(pre_tree, dict), "pre_tree_refusals")
    _require(list(pre_tree.keys()) == EXPECTED_CELL_IDS, "pre_tree_refusal_order")
    for cell_id, value in pre_tree.items():
        _require(
            _boolean(value, f"pre_tree_refusal_{cell_id}"),
            f"pre_tree_read_not_refused_{cell_id}",
        )

    cells = report["cells"]
    _require(isinstance(cells, list), "cells_not_array")
    _require(len(cells) == len(EXPECTED_CELL_IDS), "cell_count")
    observed_ids = [cell.get("cell_id") if isinstance(cell, dict) else None for cell in cells]
    _require(observed_ids == EXPECTED_CELL_IDS, "cell_identity_or_order")

    retained_sample_count = 0
    stepping_attempt_count = 0
    for cell_index, cell_value in enumerate(cells):
        cell_id = EXPECTED_CELL_IDS[cell_index]
        expected = EXPECTED_CELL_CONFIGURATION[cell_id]
        cell = _exact_keys(cell_value, EXPECTED_CELL_KEYS, f"cell_{cell_id}")
        _require(cell["cell_id"] == cell_id, f"cell_id_{cell_id}")
        _require(cell["family"] == expected["family"], f"family_{cell_id}")
        _require(
            _boolean(cell["motor_enabled"], f"motor_enabled_{cell_id}")
            is expected["motor_enabled"],
            f"motor_enabled_{cell_id}",
        )
        _require(
            _number(cell["canonical_target_velocity_rad_s"], f"target_{cell_id}")
            == expected["canonical_target_velocity_rad_s"],
            f"target_{cell_id}",
        )
        _require(
            _number(cell["initial_canonical_rate_rad_s"], f"initial_rate_{cell_id}")
            == expected["initial_canonical_rate_rad_s"],
            f"initial_rate_{cell_id}",
        )
        _require(
            _number(cell["public_maximum_motor_impulse_nms"], f"max_impulse_{cell_id}")
            == expected["public_maximum_motor_impulse_nms"],
            f"max_impulse_{cell_id}",
        )
        _require(
            _boolean(cell["joint_limits_enabled"], f"limits_{cell_id}")
            is expected["joint_limits_enabled"],
            f"limits_{cell_id}",
        )
        for key in ("lower_limit_rad", "upper_limit_rad"):
            _require(
                _number(cell[key], f"{key}_{cell_id}") == expected[key],
                f"{key}_{cell_id}",
            )
        _require(
            _integer(cell["retained_step_count"], f"step_count_{cell_id}", 1)
            == expected["retained_step_count"],
            f"step_count_{cell_id}",
        )
        _require(
            _boolean(cell["pre_tree_read_refused"], f"pre_tree_cell_{cell_id}"),
            f"pre_tree_cell_not_refused_{cell_id}",
        )

        parameters = _exact_keys(
            cell["parameter_readback"],
            EXPECTED_PARAMETER_KEYS,
            f"parameters_{cell_id}",
        )
        _require(
            _number(parameters["child_mass_kg"], f"parameter_mass_{cell_id}")
            == 1.0,
            f"parameter_mass_{cell_id}",
        )
        _require(
            _numeric_vector(
                parameters["child_inertia_diagonal_kg_m2"],
                3,
                f"parameter_inertia_{cell_id}",
            )
            == [0.05, 0.05, 0.05],
            f"parameter_inertia_{cell_id}",
        )
        for key in (
            "gravity_scale",
            "linear_damping",
            "angular_damping",
            "anchor_error_m",
            "axis_error_rad",
        ):
            _require(
                _number(parameters[key], f"parameter_{key}_{cell_id}") == 0.0,
                f"parameter_{key}_{cell_id}",
            )
        for key, expected_value in (
            (
                "host_target_velocity_rad_s",
                -expected["canonical_target_velocity_rad_s"],
            ),
            (
                "public_maximum_motor_impulse_nms",
                expected["public_maximum_motor_impulse_nms"],
            ),
            ("lower_limit_rad", expected["lower_limit_rad"]),
            ("upper_limit_rad", expected["upper_limit_rad"]),
        ):
            _require(
                _number(parameters[key], f"parameter_{key}_{cell_id}")
                == expected_value,
                f"parameter_{key}_{cell_id}",
            )
        for key in ("collision_layer", "collision_mask"):
            _require(
                _integer(parameters[key], f"parameter_{key}_{cell_id}", 0) == 0,
                f"parameter_{key}_{cell_id}",
            )
        for key in ("motor_enabled", "joint_limits_enabled"):
            _require(
                _boolean(parameters[key], f"parameter_{key}_{cell_id}")
                is expected[key],
                f"parameter_{key}_{cell_id}",
            )

        samples = cell["samples"]
        _require(isinstance(samples, list), f"samples_{cell_id}")
        _require(len(samples) == EXPECTED_STEPS[cell_id], f"sample_count_{cell_id}")
        retained_sample_count += len(samples)
        for sample_index, sample_value in enumerate(samples, start=1):
            sample = _exact_keys(
                sample_value, EXPECTED_SAMPLE_KEYS, f"sample_{cell_id}_{sample_index}"
            )
            _require(sample["step_index"] == sample_index, f"sample_order_{cell_id}")
            for key in (
                "pre_canonical_relative_rate_rad_s",
                "post_canonical_relative_rate_rad_s",
                "inverse_inertia_axis_kg_inv_m2",
                "integrated_canonical_angle_rad",
            ):
                _number(sample[key], f"sample_{cell_id}_{sample_index}_{key}")
            for key, expected_value in (
                (
                    "host_target_velocity_readback_rad_s",
                    -expected["canonical_target_velocity_rad_s"],
                ),
                ("joint_limit_lower_readback_rad", expected["lower_limit_rad"]),
                ("joint_limit_upper_readback_rad", expected["upper_limit_rad"]),
            ):
                _require(
                    _number(
                        sample[key],
                        f"sample_{cell_id}_{sample_index}_{key}",
                    )
                    == expected_value,
                    f"sample_{cell_id}_{sample_index}_{key}",
                )
            _require(
                sample["inverse_inertia_axis_kg_inv_m2"] > 0.0,
                f"sample_{cell_id}_{sample_index}_inverse_inertia",
            )
            sample_attempts = _integer(
                sample["stepping_read_attempt_count"],
                f"sample_{cell_id}_{sample_index}_stepping_attempts",
                0,
            )
            sample_refusals = _integer(
                sample["stepping_read_refusal_count"],
                f"sample_{cell_id}_{sample_index}_stepping_refusals",
                0,
            )
            _require(
                sample_refusals == sample_attempts,
                f"sample_{cell_id}_{sample_index}_unsafe_read_not_refused",
            )
            stepping_attempt_count += sample_attempts
            _boolean(sample["child_sleeping"], f"sample_{cell_id}_{sample_index}_sleeping")
            _validate_telemetry(sample["telemetry"], f"telemetry_{cell_id}_{sample_index}")

    _require(stepping_attempt_count > 0, "stepping_refusal_control_not_exercised")

    execution = _exact_keys(report["execution"], EXPECTED_EXECUTION_KEYS, "execution")
    _require(execution["world_attempt_count"] == 1, "world_attempt_count")
    _require(execution["world_build_count"] == 1, "world_build_count")
    _require(execution["physics_step_count"] == 20, "physics_step_count")
    _require(execution["retained_sample_count"] == retained_sample_count == 68, "retained_sample_count")
    for key in (
        "direct_force_write_count",
        "direct_torque_write_count",
        "direct_impulse_write_count",
        "post_activation_transform_write_count",
        "outcome_dependent_early_stop_count",
    ):
        _require(execution[key] == 0, key)
    _require(
        execution["pre_activation_initial_angular_velocity_write_count"] == 4,
        "initial_velocity_write_count",
    )
    _require(execution["declared_sleep_input_write_count"] == 1, "sleep_input_count")

    claims = _exact_keys(report["claims"], EXPECTED_CLAIM_KEYS, "claims")
    _require(claims["descriptive_development_characterization_only"] is True, "descriptive_claim")
    for key in EXPECTED_CLAIM_KEYS - {"descriptive_development_characterization_only"}:
        _require(claims[key] is False, f"claim_promotion_{key}")


def evaluate_report(report: dict[str, Any]) -> dict[str, Any]:
    validate_report(report)
    cell_evaluations: list[dict[str, Any]] = []
    telemetry_sample_count = 0
    telemetry_missing_sample_count = 0
    cap_observation_count = 0
    cap_within_hard_bound_count = 0
    stepping_attempt_count = 0
    stepping_refusal_count = 0
    active_sequence_increment_count = 0
    repeated_sequence_count = 0
    maximum_abs_impulse_residual = 0.0
    maximum_abs_work_residual = 0.0
    maximum_abs_decomposition_residual = 0.0

    for cell in report["cells"]:
        cell_samples: list[dict[str, Any]] = []
        previous_sequence: int | None = None
        for sample in cell["samples"]:
            pre_rate = float(sample["pre_canonical_relative_rate_rad_s"])
            post_rate = float(sample["post_canonical_relative_rate_rad_s"])
            inverse_inertia = float(sample["inverse_inertia_axis_kg_inv_m2"])
            effective_inertia = 1.0 / inverse_inertia
            independent_impulse = effective_inertia * (post_rate - pre_rate)
            independent_energy = 0.5 * effective_inertia * (
                post_rate * post_rate - pre_rate * pre_rate
            )
            stepping_attempt_count += int(sample["stepping_read_attempt_count"])
            stepping_refusal_count += int(sample["stepping_read_refusal_count"])
            telemetry = sample["telemetry"]
            evaluated_sample: dict[str, Any] = {
                "step_index": sample["step_index"],
                "telemetry_available": telemetry is not None,
                "effective_axis_inertia_kg_m2": effective_inertia,
                "independent_angular_momentum_change_nms": independent_impulse,
                "independent_kinetic_energy_change_j": independent_energy,
                "integrated_canonical_angle_rad": sample[
                    "integrated_canonical_angle_rad"
                ],
                "child_sleeping": sample["child_sleeping"],
            }
            if telemetry is None:
                telemetry_missing_sample_count += 1
                evaluated_sample.update(
                    {
                        "telemetry_sequence": None,
                        "impulse_residual_nms": None,
                        "work_residual_j": None,
                        "net_work_decomposition_residual_j": None,
                        "motor_impulse_cap_nms": None,
                        "within_configured_hard_solver_cap": None,
                        "sequence_relation_to_prior": "unavailable",
                    }
                )
            else:
                telemetry_sample_count += 1
                signed_impulse = float(telemetry["signed_motor_impulse_nms"])
                net_work = float(telemetry["net_motor_work_j"])
                decomposition = float(telemetry["positive_motor_work_j"]) - float(
                    telemetry["absorbed_motor_work_j"]
                )
                impulse_residual = signed_impulse - independent_impulse
                work_residual = net_work - independent_energy
                decomposition_residual = net_work - decomposition
                cap = max(
                    abs(float(telemetry["min_torque_limit_nm"])),
                    abs(float(telemetry["max_torque_limit_nm"])),
                ) * float(telemetry["solver_step_s"])
                cap_within = abs(signed_impulse) <= cap
                cap_observation_count += 1
                cap_within_hard_bound_count += int(cap_within)
                sequence = int(telemetry["telemetry_sequence"])
                if previous_sequence is None:
                    sequence_relation = "first_available"
                elif sequence > previous_sequence:
                    sequence_relation = "advanced"
                    active_sequence_increment_count += 1
                elif sequence == previous_sequence:
                    sequence_relation = "repeated"
                    repeated_sequence_count += 1
                else:
                    sequence_relation = "regressed"
                previous_sequence = sequence
                maximum_abs_impulse_residual = max(
                    maximum_abs_impulse_residual, abs(impulse_residual)
                )
                maximum_abs_work_residual = max(
                    maximum_abs_work_residual, abs(work_residual)
                )
                maximum_abs_decomposition_residual = max(
                    maximum_abs_decomposition_residual,
                    abs(decomposition_residual),
                )
                evaluated_sample.update(
                    {
                        "telemetry_sequence": sequence,
                        "telemetry_motor_state": telemetry["motor_state"],
                        "telemetry_target_angular_velocity_rad_s": telemetry[
                            "target_angular_velocity_rad_s"
                        ],
                        "signed_motor_impulse_nms": signed_impulse,
                        "positive_motor_work_j": telemetry["positive_motor_work_j"],
                        "absorbed_motor_work_j": telemetry["absorbed_motor_work_j"],
                        "net_motor_work_j": net_work,
                        "impulse_residual_nms": impulse_residual,
                        "work_residual_j": work_residual,
                        "net_work_decomposition_residual_j": decomposition_residual,
                        "motor_impulse_cap_nms": cap,
                        "within_configured_hard_solver_cap": cap_within,
                        "sequence_relation_to_prior": sequence_relation,
                    }
                )
            cell_samples.append(evaluated_sample)
        cell_evaluations.append(
            {
                "cell_id": cell["cell_id"],
                "family": cell["family"],
                "motor_enabled": cell["motor_enabled"],
                "joint_limits_enabled": cell["joint_limits_enabled"],
                "canonical_target_velocity_rad_s": cell[
                    "canonical_target_velocity_rad_s"
                ],
                "initial_canonical_rate_rad_s": cell[
                    "initial_canonical_rate_rad_s"
                ],
                "samples": cell_samples,
            }
        )

    encoded = json.dumps(report, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return {
        "schema_version": EVALUATION_SCHEMA,
        "gate_id": "QSDK-R24D4",
        "question_class": "development",
        "result_class": "complete_valid_descriptive_development_characterization",
        "raw_report_canonical_sha256": "sha256:" + hashlib.sha256(encoded).hexdigest(),
        "execution_valid": True,
        "descriptive_findings_are_acceptance_gates": False,
        "empirical_acceptance_threshold_count": 0,
        "superiority_margin_count": 0,
        "equivalence_or_non_inferiority_margin_count": 0,
        "population_claim_count": 0,
        "summary": {
            "cell_count": len(report["cells"]),
            "retained_sample_count": report["execution"]["retained_sample_count"],
            "telemetry_sample_count": telemetry_sample_count,
            "telemetry_missing_sample_count": telemetry_missing_sample_count,
            "configured_hard_cap_observation_count": cap_observation_count,
            "within_configured_hard_cap_count": cap_within_hard_bound_count,
            "stepping_read_attempt_count": stepping_attempt_count,
            "stepping_read_refusal_count": stepping_refusal_count,
            "active_sequence_increment_count": active_sequence_increment_count,
            "repeated_sequence_count": repeated_sequence_count,
            "maximum_absolute_impulse_residual_nms": maximum_abs_impulse_residual,
            "maximum_absolute_work_residual_j": maximum_abs_work_residual,
            "maximum_absolute_net_work_decomposition_residual_j": (
                maximum_abs_decomposition_residual
            ),
            "invalid_rid_refused_observation": report["refusals"][
                "invalid_rid_refused"
            ],
            "all_not_in_tree_reads_refused_observation": all(
                report["refusals"]["not_in_tree_joint_read_refused_by_cell"].values()
            ),
        },
        "cells": cell_evaluations,
        "claims": {
            "native_measurements_observed": telemetry_sample_count > 0,
            "complete_telemetry_sample_coverage_observed": (
                telemetry_missing_sample_count == 0
            ),
            "numerical_accuracy_accepted": False,
            "instrumented_profile_promoted": False,
            "recovery_claimed": False,
            "prone_to_standing_claimed": False,
            "cross_engine_equivalence_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
    }


def _synthetic_report() -> dict[str, Any]:
    cells: list[dict[str, Any]] = []
    targets = [1.0, -1.0, 0.0, 0.0, 0.0, 0.0, 2.0, -2.0, 0.0]
    initial_rates = [0.0, 0.0, 0.4, -0.4, 0.4, -0.4, 0.0, 0.0, 0.0]
    motor_enabled = [True, True, True, True, False, False, True, True, True]
    limits_enabled = [False, False, False, False, False, False, True, True, False]
    max_impulses = [0.002] * 6 + [0.01, 0.01, 0.002]
    pre_tree: dict[str, bool] = {}
    retained_samples = 0
    for index, cell_id in enumerate(EXPECTED_CELL_IDS):
        pre_tree[cell_id] = True
        samples: list[dict[str, Any]] = []
        rate = initial_rates[index]
        angle = 0.0
        for step_index in range(1, EXPECTED_STEPS[cell_id] + 1):
            pre_rate = rate
            if cell_id == "sleep_stale":
                post_rate = 0.0
                sequence = 1
            elif not motor_enabled[index]:
                post_rate = pre_rate
                sequence = step_index
            else:
                delta = max(-0.04, min(0.04, targets[index] - pre_rate))
                post_rate = pre_rate + delta
                sequence = step_index
            dt = 1.0 / 120.0
            angle += 0.5 * (pre_rate + post_rate) * dt
            impulse = 0.0 if not motor_enabled[index] else 0.05 * (post_rate - pre_rate)
            energy = 0.5 * 0.05 * (post_rate * post_rate - pre_rate * pre_rate)
            positive_work = max(0.0, energy)
            absorbed_work = max(0.0, -energy)
            telemetry = {
                "schema": TELEMETRY_SCHEMA,
                "telemetry_sequence": sequence,
                "solver_step_s": dt,
                "motor_state": "velocity" if motor_enabled[index] else "off",
                "target_angular_velocity_rad_s": targets[index],
                "min_torque_limit_nm": -max_impulses[index] / dt,
                "max_torque_limit_nm": max_impulses[index] / dt,
                "signed_motor_impulse_nms": impulse,
                "positive_motor_work_j": positive_work,
                "absorbed_motor_work_j": absorbed_work,
                "net_motor_work_j": positive_work - absorbed_work,
            }
            samples.append(
                {
                    "step_index": step_index,
                    "pre_canonical_relative_rate_rad_s": pre_rate,
                    "post_canonical_relative_rate_rad_s": post_rate,
                    "inverse_inertia_axis_kg_inv_m2": 20.0,
                    "integrated_canonical_angle_rad": angle,
                    "host_target_velocity_readback_rad_s": -targets[index],
                    "joint_limit_lower_readback_rad": -0.02 if limits_enabled[index] else -1.0,
                    "joint_limit_upper_readback_rad": 0.02 if limits_enabled[index] else 1.0,
                    "telemetry": telemetry,
                    "stepping_read_attempt_count": 1,
                    "stepping_read_refusal_count": 1,
                    "child_sleeping": cell_id == "sleep_stale" and step_index >= 2,
                }
            )
            rate = post_rate
        retained_samples += len(samples)
        cells.append(
            {
                "cell_id": cell_id,
                "family": EXPECTED_FAMILIES[cell_id],
                "motor_enabled": motor_enabled[index],
                "canonical_target_velocity_rad_s": targets[index],
                "initial_canonical_rate_rad_s": initial_rates[index],
                "public_maximum_motor_impulse_nms": max_impulses[index],
                "joint_limits_enabled": limits_enabled[index],
                "lower_limit_rad": -0.02 if limits_enabled[index] else -1.0,
                "upper_limit_rad": 0.02 if limits_enabled[index] else 1.0,
                "retained_step_count": EXPECTED_STEPS[cell_id],
                "pre_tree_read_refused": True,
                "parameter_readback": {
                    "child_mass_kg": 1.0,
                    "child_inertia_diagonal_kg_m2": [0.05, 0.05, 0.05],
                    "gravity_scale": 0.0,
                    "linear_damping": 0.0,
                    "angular_damping": 0.0,
                    "collision_layer": 0,
                    "collision_mask": 0,
                    "motor_enabled": motor_enabled[index],
                    "joint_limits_enabled": limits_enabled[index],
                    "host_target_velocity_rad_s": -targets[index],
                    "public_maximum_motor_impulse_nms": max_impulses[index],
                    "lower_limit_rad": -0.02 if limits_enabled[index] else -1.0,
                    "upper_limit_rad": 0.02 if limits_enabled[index] else 1.0,
                    "anchor_error_m": 0.0,
                    "axis_error_rad": 0.0,
                },
                "samples": samples,
            }
        )
    return {
        "schema_version": SCHEMA,
        "gate_id": "QSDK-R24D4",
        "question_class": "development",
        "source_commit": "1" * 40,
        "execution_nonce": "2" * 32,
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
            "fixture_id": "QSDK.R24D4.godot_jolt_one_hinge_telemetry.v1",
            "cell_count": 9,
            "child_mass_kg": 1.0,
            "child_inertia_diagonal_kg_m2": [0.05, 0.05, 0.05],
            "hinge_axis_parent_local": [0.0, 0.0, -1.0],
            "gravity_scale": 0.0,
            "linear_damping": 0.0,
            "angular_damping": 0.0,
            "collision_layer": 0,
            "collision_mask": 0,
            "contact_count": 0,
        },
        "refusals": {
            "invalid_rid_refused": True,
            "not_in_tree_joint_read_refused_by_cell": pre_tree,
        },
        "cells": cells,
        "execution": {
            "world_attempt_count": 1,
            "world_build_count": 1,
            "physics_step_count": 20,
            "retained_sample_count": retained_samples,
            "direct_force_write_count": 0,
            "direct_torque_write_count": 0,
            "direct_impulse_write_count": 0,
            "post_activation_transform_write_count": 0,
            "pre_activation_initial_angular_velocity_write_count": 4,
            "declared_sleep_input_write_count": 1,
            "outcome_dependent_early_stop_count": 0,
        },
        "claims": {
            "descriptive_development_characterization_only": True,
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
    base = _synthetic_report()
    evaluation = evaluate_report(copy.deepcopy(base))
    _require(evaluation["execution_valid"] is True, "synthetic_evaluation")

    mutations: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        ("schema", _set_path(("schema_version",), "mutated")),
        ("unknown_top_level", lambda value: value.__setitem__("unexpected", True)),
        ("question_class", _set_path(("question_class",), "finite_decision")),
        ("cell_omission", lambda value: value["cells"].pop()),
        ("cell_order", lambda value: value["cells"].reverse()),
        ("duplicate_cell", _set_path(("cells", 1, "cell_id"), "drive_positive")),
        ("sample_omission", lambda value: value["cells"][0]["samples"].pop()),
        ("sample_order", _set_path(("cells", 0, "samples", 1, "step_index"), 1)),
        ("telemetry_schema", _set_path(("cells", 0, "samples", 0, "telemetry", "schema"), "mutated")),
        ("sequence_type", _set_path(("cells", 0, "samples", 0, "telemetry", "telemetry_sequence"), 1.5)),
        ("non_finite_encoding", _set_path(("cells", 0, "samples", 0, "post_canonical_relative_rate_rad_s"), "nan")),
        ("negative_step", _set_path(("cells", 0, "samples", 0, "telemetry", "solver_step_s"), -1.0)),
        ("world_count", _set_path(("execution", "world_build_count"), 2)),
        ("direct_write", _set_path(("execution", "direct_torque_write_count"), 1)),
        ("release_claim", _set_path(("claims", "release_authority"), True)),
        (
            "cell_configuration",
            _set_path(("cells", 0, "canonical_target_velocity_rad_s"), 1.25),
        ),
        (
            "parameter_readback_configuration",
            _set_path(("cells", 0, "parameter_readback", "child_mass_kg"), 2.0),
        ),
        (
            "sample_public_readback_configuration",
            _set_path(
                (
                    "cells",
                    0,
                    "samples",
                    0,
                    "host_target_velocity_readback_rad_s",
                ),
                99.0,
            ),
        ),
        (
            "engine_registration",
            _set_path(("engine", "telemetry_class_registered"), False),
        ),
        (
            "invalid_rid_refusal",
            _set_path(("refusals", "invalid_rid_refused"), False),
        ),
        (
            "unsafe_read_non_refusal",
            _set_path(("cells", 0, "samples", 0, "stepping_read_refusal_count"), 0),
        ),
    ]
    rejected: list[str] = []
    for name, mutate in mutations:
        candidate = copy.deepcopy(base)
        mutate(candidate)
        try:
            evaluate_report(candidate)
        except EvaluationError:
            rejected.append(name)
        else:
            raise EvaluationError(f"mutation accepted: {name}")

    duplicate_key_rejected = False
    try:
        strict_loads('{"schema_version":"x","schema_version":"y"}')
    except EvaluationError:
        duplicate_key_rejected = True
    _require(duplicate_key_rejected, "duplicate_key_control")
    rejected.insert(0, "duplicate_json_key")

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
    ]:
        candidate = copy.deepcopy(base)
        _set_path(path, value)(candidate)
        evaluate_report(candidate)
        accepted_outcome_mutations.append(name)

    _require(len(rejected) == 22, "negative_control_count")
    return {
        "ok": True,
        "schema_version": EVALUATION_SCHEMA,
        "synthetic_cell_count": len(base["cells"]),
        "synthetic_sample_count": base["execution"]["retained_sample_count"],
        "rejected_negative_control_count": len(rejected),
        "rejected_negative_controls": rejected,
        "accepted_outcome_mutation_count": len(accepted_outcome_mutations),
        "accepted_outcome_mutations": accepted_outcome_mutations,
        "empirical_acceptance_threshold_count": 0,
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
    parser.add_argument("--input", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path)
    arguments = parser.parse_args()
    try:
        if arguments.self_test:
            receipt = self_test()
            print(
                "QSDK_R24D4_EVALUATOR_ZERO_WORLD "
                + json.dumps(receipt, sort_keys=True, separators=(",", ":"))
            )
            return 0
        if arguments.input is None or arguments.output is None:
            raise EvaluationError("--input and --output are required outside self-test")
        report = strict_loads(arguments.input.read_text(encoding="utf-8"))
        evaluation = evaluate_report(report)
        _write_json(arguments.output, evaluation)
        print(
            "QSDK_R24D4_EVALUATION "
            + json.dumps(
                {
                    "ok": True,
                    "result_class": evaluation["result_class"],
                    "cell_count": evaluation["summary"]["cell_count"],
                    "retained_sample_count": evaluation["summary"][
                        "retained_sample_count"
                    ],
                    "empirical_acceptance_threshold_count": 0,
                    "physical_acceptance_authority": False,
                    "release_authority": False,
                },
                sort_keys=True,
                separators=(",", ":"),
            )
        )
        return 0
    except (OSError, EvaluationError) as error:
        print(f"QSDK_R24D4_EVALUATION_ERROR {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
