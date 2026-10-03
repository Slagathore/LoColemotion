#!/usr/bin/env python3
"""Strict evaluator for the finite QSDK-R24D13 braking mechanism question.

The evaluator rejects source, fixture, activation, timing, and report-shape
drift. A mechanically valid native execution is retained as either a positive
or negative development result; missing braking witnesses never become a
harness failure.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import struct
from pathlib import Path
from typing import Any, Callable


GATE_ID = "QSDK-R24D13"
RAW_SCHEMA = "sporespore_qsdk_r24d13_godot_jolt_braking_mechanism_activation_raw_report_v1"
EVALUATION_SCHEMA = "sporespore_qsdk_r24d13_godot_jolt_braking_mechanism_activation_evaluation_v1"
TELEMETRY_SCHEMA = "sporespore.godot_jolt_hinge_motor_telemetry.v2"
FIXTURE_ID = "QSDK.R24D13.godot_jolt_braking_mechanism_activation.v1"
ACTIVATION_ROUTE_ID = "godot_jolt_unfreeze_then_public_angular_velocity_write_v1"
R24D11_DECISION_SHA = "sha256:7418141ac1ac5fd4a6fab8a34956346ccd721792630025939e837f7b698440a4"
RUNTIME_PATCH_SHA = "sha256:9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
EXPECTED_REAL_T_RATE = 0.4000000059604645
NATIVE_REAL_T_IMPULSE = struct.unpack("<f", struct.pack("<f", 0.002))[0]
EXPECTED_REAL_T_IMPULSE = float("0.0020000000949949")
EXPECTED_REAL_T_TORQUE = 0.24000000953674316
NATIVE_DT = struct.unpack("<f", struct.pack("<f", 1.0 / 120.0))[0]
EXPECTED_DT = float("0.00833333376795053")
EXPECTED_INVERSE_INERTIA = 20.0
EXPECTED_NATIVE_INERTIA = struct.unpack("<f", struct.pack("<f", 0.05))[0]
CELL_CONFIG = [
    {
        "cell_id": "brake_positive",
        "family": "signed_braking",
        "motor_enabled": True,
        "canonical_target_velocity_rad_s": 0.0,
        "initial_canonical_rate_rad_s": 0.4,
        "expected_real_t_rate_rad_s": EXPECTED_REAL_T_RATE,
    },
    {
        "cell_id": "brake_negative",
        "family": "signed_braking",
        "motor_enabled": True,
        "canonical_target_velocity_rad_s": 0.0,
        "initial_canonical_rate_rad_s": -0.4,
        "expected_real_t_rate_rad_s": -EXPECTED_REAL_T_RATE,
    },
    {
        "cell_id": "disabled_positive",
        "family": "motor_disabled",
        "motor_enabled": False,
        "canonical_target_velocity_rad_s": 0.0,
        "initial_canonical_rate_rad_s": 0.4,
        "expected_real_t_rate_rad_s": EXPECTED_REAL_T_RATE,
    },
    {
        "cell_id": "disabled_negative",
        "family": "motor_disabled",
        "motor_enabled": False,
        "canonical_target_velocity_rad_s": 0.0,
        "initial_canonical_rate_rad_s": -0.4,
        "expected_real_t_rate_rad_s": -EXPECTED_REAL_T_RATE,
    },
]
CELL_IDS = [str(cell["cell_id"]) for cell in CELL_CONFIG]
REPORT_KEYS = {
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
    "activation_receipts",
    "cells",
    "execution",
    "evidence_provenance",
    "claims",
}
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
FALSE_CLAIMS = [
    "numerical_accuracy_accepted",
    "instrumented_profile_promoted",
    "stock_godot_profile_promoted",
    "native_capability_conjunction_complete",
    "recovery_world_opened",
    "prone_to_standing_world_opened",
    "turning_claim_changed",
    "cross_engine_equivalence_claimed",
    "q_sdk_r24_satisfied",
    "physical_acceptance_authority",
    "release_authority",
]


class EvaluationError(RuntimeError):
    """Raised for implementation-invalid input, never for a physics negative."""


def fail(code: str) -> None:
    raise EvaluationError(code)


def require(condition: bool, code: str) -> None:
    if not condition:
        fail(code)


def exact_type(value: Any, expected_type: type, code: str) -> Any:
    if type(value) is not expected_type:
        fail(code)
    return value


def object_value(value: Any, code: str) -> dict[str, Any]:
    return exact_type(value, dict, code)


def list_value(value: Any, code: str) -> list[Any]:
    return exact_type(value, list, code)


def string_value(value: Any, code: str) -> str:
    return exact_type(value, str, code)


def bool_value(value: Any, code: str) -> bool:
    return exact_type(value, bool, code)


def integer_value(value: Any, code: str) -> int:
    return exact_type(value, int, code)


def finite_value(value: Any, code: str) -> float:
    if type(value) not in (int, float) or type(value) is bool:
        fail(code)
    number = float(value)
    if not math.isfinite(number):
        fail(code)
    return number


def exact_keys(value: dict[str, Any], keys: set[str], code: str) -> None:
    if set(value) != keys:
        fail(code)


def exact(value: Any, expected: Any, code: str) -> None:
    if value != expected or type(value) is not type(expected):
        fail(code)


def validate_engine(value: Any) -> dict[str, Any]:
    engine = object_value(value, "ENGINE_NOT_OBJECT")
    exact_keys(
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
        "ENGINE_FIELD_SET",
    )
    exact(engine["physics_engine"], "Jolt Physics", "ENGINE_NAME")
    exact(engine["physics_ticks_per_second"], 120, "ENGINE_TICKS")
    exact(engine["solver_velocity_steps"], 20, "ENGINE_VELOCITY_STEPS")
    exact(engine["solver_position_steps"], 7, "ENGINE_POSITION_STEPS")
    exact(engine["thread_model"], "single_safe", "ENGINE_THREAD_MODEL")
    exact(engine["telemetry_class_registered"], True, "ENGINE_TELEMETRY_CLASS")
    exact(engine["telemetry_method_registered"], True, "ENGINE_TELEMETRY_METHOD")
    return engine


def validate_fixture(value: Any) -> dict[str, Any]:
    fixture = object_value(value, "FIXTURE_NOT_OBJECT")
    expected = {
        "fixture_id": FIXTURE_ID,
        "activation_route_id": ACTIVATION_ROUTE_ID,
        "world_count": 1,
        "isolated_cell_count": 4,
        "cell_ids_in_order": CELL_IDS,
        "hinges_per_cell": 1,
        "dynamic_bodies_per_cell": 1,
        "static_parents_per_cell": 1,
        "child_mass_kg": 1.0,
        "child_inertia_diagonal_kg_m2": [EXPECTED_NATIVE_INERTIA] * 3,
        "hinge_axis_parent_local": [0.0, 0.0, 1.0],
        "maximum_physics_step_count": 1,
        "retained_sample_count": 4,
        "gravity_scale": 0.0,
        "linear_damping": 0.0,
        "angular_damping": 0.0,
        "collision_layer": 0,
        "collision_mask": 0,
        "contact_count": 0,
        "joint_limits_enabled": False,
        "lower_limit_rad": -1.0,
        "upper_limit_rad": 1.0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
    }
    exact_keys(fixture, set(expected), "FIXTURE_FIELD_SET")
    for key, expected_value in expected.items():
        exact(fixture.get(key), expected_value, f"FIXTURE_{key.upper()}")
    return fixture


def validate_activation_receipts(value: Any) -> list[dict[str, Any]]:
    receipts = list_value(value, "ACTIVATION_RECEIPTS_NOT_ARRAY")
    require(len(receipts) == 4, "ACTIVATION_RECEIPT_COUNT")
    validated: list[dict[str, Any]] = []
    expected_keys = {
        "cell_id",
        "ok",
        "activation_route_id",
        "unfreeze_write_count",
        "can_sleep_write_count",
        "sleeping_write_count",
        "scene_property_angular_velocity_write_count",
        "physics_server_state_write_count",
        "declared_canonical_rate_rad_s",
        "scene_canonical_rate_readback_rad_s",
        "physics_server_canonical_rate_readback_rad_s",
    }
    for receipt_value, config in zip(receipts, CELL_CONFIG):
        receipt = object_value(receipt_value, "ACTIVATION_RECEIPT_NOT_OBJECT")
        exact_keys(receipt, expected_keys, "ACTIVATION_RECEIPT_FIELD_SET")
        exact(receipt["cell_id"], config["cell_id"], "ACTIVATION_CELL_ID")
        exact(receipt["ok"], True, "ACTIVATION_OK")
        exact(receipt["activation_route_id"], ACTIVATION_ROUTE_ID, "ACTIVATION_ROUTE")
        for key in (
            "unfreeze_write_count",
            "can_sleep_write_count",
            "sleeping_write_count",
            "scene_property_angular_velocity_write_count",
        ):
            exact(receipt[key], 1, f"ACTIVATION_{key.upper()}")
        exact(receipt["physics_server_state_write_count"], 0, "ACTIVATION_SERVER_WRITE_COUNT")
        exact(
            finite_value(receipt["declared_canonical_rate_rad_s"], "ACTIVATION_DECLARED_RATE_TYPE"),
            float(config["initial_canonical_rate_rad_s"]),
            "ACTIVATION_DECLARED_RATE",
        )
        expected_rate = float(config["expected_real_t_rate_rad_s"])
        exact(
            finite_value(receipt["scene_canonical_rate_readback_rad_s"], "ACTIVATION_SCENE_RATE_TYPE"),
            expected_rate,
            "ACTIVATION_SCENE_RATE",
        )
        exact(
            finite_value(receipt["physics_server_canonical_rate_readback_rad_s"], "ACTIVATION_SERVER_RATE_TYPE"),
            expected_rate,
            "ACTIVATION_SERVER_RATE",
        )
        validated.append(receipt)
    return validated


def validate_parameter_readback(value: Any, config: dict[str, Any], cell_id: str) -> None:
    readback = object_value(value, f"PARAMETER_{cell_id}_NOT_OBJECT")
    expected = {
        "child_mass_kg": 1.0,
        "child_inertia_diagonal_kg_m2": [EXPECTED_NATIVE_INERTIA] * 3,
        "gravity_scale": 0.0,
        "linear_damping": 0.0,
        "angular_damping": 0.0,
        "collision_layer": 0,
        "collision_mask": 0,
        "motor_enabled": bool(config["motor_enabled"]),
        "joint_limits_enabled": False,
        "host_target_velocity_rad_s": 0.0,
        "public_maximum_motor_impulse_nms": EXPECTED_REAL_T_IMPULSE,
        "lower_limit_rad": -1.0,
        "upper_limit_rad": 1.0,
        "anchor_error_m": 0.0,
        "axis_error_rad": 0.0,
    }
    exact_keys(readback, set(expected), f"PARAMETER_{cell_id}_FIELD_SET")
    for key, expected_value in expected.items():
        exact(readback.get(key), expected_value, f"PARAMETER_{cell_id}_{key}")


def validate_telemetry(value: Any, config: dict[str, Any], cell_id: str) -> dict[str, Any]:
    telemetry = object_value(value, f"TELEMETRY_{cell_id}_NOT_OBJECT")
    exact_keys(telemetry, TELEMETRY_KEYS, f"TELEMETRY_{cell_id}_FIELD_SET")
    exact(telemetry["schema"], TELEMETRY_SCHEMA, f"TELEMETRY_{cell_id}_SCHEMA")
    for key in ("telemetry_sequence", "capture_space_step_sequence", "read_space_step_sequence"):
        exact(telemetry[key], 1, f"TELEMETRY_{cell_id}_{key}")
    exact(telemetry["captured_during_active_step"], True, f"TELEMETRY_{cell_id}_ACTIVE")
    exact(telemetry["snapshot_is_current_space_step"], True, f"TELEMETRY_{cell_id}_CURRENT")
    exact(finite_value(telemetry["solver_step_s"], f"TELEMETRY_{cell_id}_DT_TYPE"), EXPECTED_DT, f"TELEMETRY_{cell_id}_DT")
    exact(
        telemetry["motor_state"],
        "velocity" if bool(config["motor_enabled"]) else "off",
        f"TELEMETRY_{cell_id}_MOTOR_STATE",
    )
    exact(finite_value(telemetry["target_angular_velocity_rad_s"], f"TELEMETRY_{cell_id}_TARGET_TYPE"), 0.0, f"TELEMETRY_{cell_id}_TARGET")
    exact(finite_value(telemetry["min_torque_limit_nm"], f"TELEMETRY_{cell_id}_MIN_TORQUE_TYPE"), -EXPECTED_REAL_T_TORQUE, f"TELEMETRY_{cell_id}_MIN_TORQUE")
    exact(finite_value(telemetry["max_torque_limit_nm"], f"TELEMETRY_{cell_id}_MAX_TORQUE_TYPE"), EXPECTED_REAL_T_TORQUE, f"TELEMETRY_{cell_id}_MAX_TORQUE")
    for key in (
        "signed_motor_impulse_nms",
        "positive_motor_work_j",
        "absorbed_motor_work_j",
        "net_motor_work_j",
    ):
        finite_value(telemetry[key], f"TELEMETRY_{cell_id}_{key}_TYPE")
    return telemetry


def validate_cells(value: Any) -> list[dict[str, Any]]:
    cells = list_value(value, "CELLS_NOT_ARRAY")
    require(len(cells) == 4, "CELL_COUNT")
    validated: list[dict[str, Any]] = []
    cell_keys = {
        "cell_id",
        "family",
        "motor_enabled",
        "canonical_target_velocity_rad_s",
        "initial_canonical_rate_rad_s",
        "public_maximum_motor_impulse_nms",
        "pre_tree_read_refused",
        "parameter_readback",
        "samples",
    }
    sample_keys = {
        "step_index",
        "pre_canonical_relative_rate_rad_s",
        "post_canonical_relative_rate_rad_s",
        "inverse_inertia_axis_kg_inv_m2",
        "host_target_velocity_readback_rad_s",
        "telemetry",
        "child_sleeping",
    }
    for cell_value, config in zip(cells, CELL_CONFIG):
        cell = object_value(cell_value, "CELL_NOT_OBJECT")
        exact_keys(cell, cell_keys, "CELL_FIELD_SET")
        for key in (
            "cell_id",
            "family",
            "motor_enabled",
            "canonical_target_velocity_rad_s",
            "initial_canonical_rate_rad_s",
        ):
            exact(cell[key], config[key], f"CELL_{config['cell_id']}_{key}")
        exact(
            finite_value(cell["public_maximum_motor_impulse_nms"], "CELL_IMPULSE_TYPE"),
            0.002,
            f"CELL_{config['cell_id']}_IMPULSE_LIMIT",
        )
        exact(cell["pre_tree_read_refused"], True, f"CELL_{config['cell_id']}_PRE_TREE_REFUSAL")
        validate_parameter_readback(cell["parameter_readback"], config, str(config["cell_id"]))
        samples = list_value(cell["samples"], f"CELL_{config['cell_id']}_SAMPLES_NOT_ARRAY")
        require(len(samples) == 1, f"CELL_{config['cell_id']}_SAMPLE_COUNT")
        sample = object_value(samples[0], f"CELL_{config['cell_id']}_SAMPLE_NOT_OBJECT")
        exact_keys(sample, sample_keys, f"CELL_{config['cell_id']}_SAMPLE_FIELD_SET")
        exact(sample["step_index"], 1, f"CELL_{config['cell_id']}_STEP_INDEX")
        expected_rate = float(config["expected_real_t_rate_rad_s"])
        exact(
            finite_value(sample["pre_canonical_relative_rate_rad_s"], "SAMPLE_PRE_RATE_TYPE"),
            expected_rate,
            f"CELL_{config['cell_id']}_PRE_RATE",
        )
        finite_value(sample["post_canonical_relative_rate_rad_s"], "SAMPLE_POST_RATE_TYPE")
        exact(
            finite_value(sample["inverse_inertia_axis_kg_inv_m2"], "SAMPLE_INVERSE_INERTIA_TYPE"),
            EXPECTED_INVERSE_INERTIA,
            f"CELL_{config['cell_id']}_INVERSE_INERTIA",
        )
        exact(
            finite_value(sample["host_target_velocity_readback_rad_s"], "SAMPLE_HOST_TARGET_TYPE"),
            0.0,
            f"CELL_{config['cell_id']}_HOST_TARGET",
        )
        telemetry = validate_telemetry(sample["telemetry"], config, str(config["cell_id"]))
        exact(sample["child_sleeping"], False, f"CELL_{config['cell_id']}_SLEEPING")
        validated.append({"config": config, "cell": cell, "sample": sample, "telemetry": telemetry})
    return validated


def evaluate(
    report: dict[str, Any],
    *,
    expected_evidence_kind: str,
    expected_source_commit: str,
    expected_nonce: str,
) -> dict[str, Any]:
    exact_keys(report, REPORT_KEYS, "REPORT_FIELD_SET")
    exact(report["schema_version"], RAW_SCHEMA, "REPORT_SCHEMA")
    exact(report["gate_id"], GATE_ID, "REPORT_GATE")
    exact(report["question_class"], "development", "REPORT_QUESTION_CLASS")
    exact(report["evidence_kind"], expected_evidence_kind, "REPORT_EVIDENCE_KIND")
    exact(report["source_commit"], expected_source_commit, "REPORT_SOURCE_COMMIT")
    exact(report["execution_nonce"], expected_nonce, "REPORT_NONCE")

    authorization = object_value(report["authorization"], "AUTHORIZATION_NOT_OBJECT")
    exact_keys(
        authorization,
        {"decision_gate_id", "decision_path", "decision_raw_sha256", "decision_publication_commit", "same_source_rerun"},
        "AUTHORIZATION_FIELD_SET",
    )
    exact(authorization["decision_gate_id"], "QSDK-R24D11", "AUTHORIZATION_GATE")
    exact(authorization["decision_raw_sha256"], R24D11_DECISION_SHA, "AUTHORIZATION_SHA")
    exact(authorization["decision_publication_commit"], "324620ee4f228e856a898dff1be96fe4351b8ff0", "AUTHORIZATION_COMMIT")
    exact(authorization["same_source_rerun"], False, "AUTHORIZATION_RERUN")

    runtime = object_value(report["runtime_provenance"], "RUNTIME_NOT_OBJECT")
    exact(runtime.get("runtime_profile_id"), "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2", "RUNTIME_PROFILE")
    exact(runtime.get("godot_source_commit"), "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88", "RUNTIME_COMMIT")
    exact(runtime.get("combined_patch_raw_sha256"), RUNTIME_PATCH_SHA, "RUNTIME_PATCH")
    exact(runtime.get("activation_route_id"), ACTIVATION_ROUTE_ID, "RUNTIME_ACTIVATION_ROUTE")
    exact(runtime.get("engine_build_reuse_scope"), "exact_unchanged_native_runtime_bytes_only", "RUNTIME_REUSE_SCOPE")

    validate_engine(report["engine"])
    validate_fixture(report["fixture"])
    refusals = object_value(report["refusals"], "REFUSALS_NOT_OBJECT")
    exact_keys(refusals, {"invalid_rid_refused", "not_in_tree_joint_read_refused_by_cell"}, "REFUSALS_FIELD_SET")
    exact(refusals["invalid_rid_refused"], True, "REFUSAL_INVALID_RID")
    exact(refusals["not_in_tree_joint_read_refused_by_cell"], {cell_id: True for cell_id in CELL_IDS}, "REFUSAL_PRE_TREE")
    validate_activation_receipts(report["activation_receipts"])
    cells = validate_cells(report["cells"])

    execution = object_value(report["execution"], "EXECUTION_NOT_OBJECT")
    expected_execution = {
        "world_attempt_count": 1,
        "world_build_count": 1,
        "physics_step_count": 1,
        "retained_sample_count": 4,
        "direct_force_write_count": 0,
        "direct_torque_write_count": 0,
        "direct_impulse_write_count": 0,
        "post_activation_transform_write_count": 0,
        "unfreeze_write_count": 4,
        "scene_property_angular_velocity_write_count": 4,
        "physics_server_state_write_count": 0,
        "pre_sample_physics_frame_count": 0,
        "schedule_start_physics_frame_boundary_count": 1,
        "terminal_physics_server_deactivation_count": 1,
        "outcome_dependent_early_stop_count": 0,
        "space_step_sequence_initial_value": 0,
        "first_retained_space_step_sequence": 1,
        "last_retained_space_step_sequence": 1,
        "observed_retained_space_step_token_count": 1,
        "extra_unretained_post_activation_step_count": 0,
        "physics_server_disabled_before_step_two": True,
    }
    exact_keys(execution, set(expected_execution), "EXECUTION_FIELD_SET")
    for key, expected_value in expected_execution.items():
        exact(execution.get(key), expected_value, f"EXECUTION_{key.upper()}")

    provenance = object_value(report["evidence_provenance"], "PROVENANCE_NOT_OBJECT")
    exact_keys(provenance, {"synthetic_shape_only", "native_physical_observation"}, "PROVENANCE_FIELD_SET")
    physical = expected_evidence_kind == "native_physical"
    exact(provenance["synthetic_shape_only"], not physical, "PROVENANCE_SYNTHETIC")
    exact(provenance["native_physical_observation"], physical, "PROVENANCE_NATIVE")

    claims = object_value(report["claims"], "CLAIMS_NOT_OBJECT")
    exact_keys(claims, {"descriptive_development_characterization_only", "mechanism_witness_is_performance_threshold"} | set(FALSE_CLAIMS), "CLAIMS_FIELD_SET")
    exact(claims["descriptive_development_characterization_only"], True, "CLAIMS_DEVELOPMENT")
    exact(claims["mechanism_witness_is_performance_threshold"], False, "CLAIMS_THRESHOLD")
    for field in FALSE_CLAIMS:
        exact(claims[field], False, f"CLAIMS_{field.upper()}")

    enabled_witnesses = 0
    disabled_zero_witnesses = 0
    cell_findings: list[dict[str, Any]] = []
    for item in cells:
        config = item["config"]
        sample = item["sample"]
        telemetry = item["telemetry"]
        pre_rate = float(sample["pre_canonical_relative_rate_rad_s"])
        impulse = float(telemetry["signed_motor_impulse_nms"])
        positive_work = float(telemetry["positive_motor_work_j"])
        absorbed_work = float(telemetry["absorbed_motor_work_j"])
        net_work = float(telemetry["net_motor_work_j"])
        if bool(config["motor_enabled"]):
            witness = (
                impulse != 0.0
                and impulse * pre_rate < 0.0
                and absorbed_work > 0.0
                and net_work < 0.0
            )
            enabled_witnesses += int(witness)
        else:
            witness = (
                impulse == 0.0
                and positive_work == 0.0
                and absorbed_work == 0.0
                and net_work == 0.0
            )
            disabled_zero_witnesses += int(witness)
        effective_inertia = 1.0 / float(sample["inverse_inertia_axis_kg_inv_m2"])
        independent_impulse = effective_inertia * (
            float(sample["post_canonical_relative_rate_rad_s"]) - pre_rate
        )
        independent_energy = 0.5 * effective_inertia * (
            float(sample["post_canonical_relative_rate_rad_s"]) ** 2 - pre_rate**2
        )
        cell_findings.append(
            {
                "cell_id": config["cell_id"],
                "motor_enabled": config["motor_enabled"],
                "mechanism_witness": witness,
                "pre_canonical_relative_rate_rad_s": pre_rate,
                "post_canonical_relative_rate_rad_s": sample["post_canonical_relative_rate_rad_s"],
                "signed_motor_impulse_nms": impulse,
                "positive_motor_work_j": positive_work,
                "absorbed_motor_work_j": absorbed_work,
                "net_motor_work_j": net_work,
                "independent_angular_momentum_change_nms": independent_impulse,
                "independent_kinetic_energy_change_j": independent_energy,
                "impulse_residual_nms": impulse - independent_impulse,
                "work_residual_j": net_work - independent_energy,
            }
        )
    mechanism_observed = enabled_witnesses == 2 and disabled_zero_witnesses == 2
    if not physical:
        result = "synthetic_shape_conforms_zero_world_only"
    elif mechanism_observed:
        result = "complete_valid_finite_native_braking_mechanism_activation_positive"
    else:
        result = "complete_valid_finite_native_braking_mechanism_activation_negative"

    canonical = json.dumps(report, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")
    return {
        "schema_version": EVALUATION_SCHEMA,
        "ok": True,
        "gate_id": GATE_ID,
        "question_class": "development",
        "evidence_kind": expected_evidence_kind,
        "result": result,
        "source_commit": expected_source_commit,
        "execution_nonce": expected_nonce,
        "raw_report_canonical_sha256": "sha256:" + hashlib.sha256(canonical).hexdigest(),
        "execution_valid": True,
        "summary": {
            "cell_count": 4,
            "retained_sample_count": 4,
            "motor_enabled_braking_witness_count": enabled_witnesses,
            "motor_disabled_zero_witness_count": disabled_zero_witnesses,
            "native_braking_mechanism_activation_observed": mechanism_observed if physical else False,
        },
        "cells": cell_findings,
        "empirical_acceptance_threshold_count": 0,
        "superiority_margin_count": 0,
        "equivalence_or_non_inferiority_margin_count": 0,
        "held_out_validation_cohort_count": 0,
        "population_claim_count": 0,
        "numerical_accuracy_accepted": False,
        "instrumented_profile_promoted": False,
        "stock_godot_profile_promoted": False,
        "native_capability_conjunction_complete": False,
        "recovery_world_opened": False,
        "prone_to_standing_world_opened": False,
        "q_sdk_r24_satisfied": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def synthetic_report(source_commit: str, nonce: str, evidence_kind: str = "synthetic_zero_world") -> dict[str, Any]:
    cells: list[dict[str, Any]] = []
    activation_receipts: list[dict[str, Any]] = []
    for config in CELL_CONFIG:
        rate = float(config["expected_real_t_rate_rad_s"])
        enabled = bool(config["motor_enabled"])
        impulse = (-1.0 if rate > 0.0 else 1.0) * EXPECTED_REAL_T_IMPULSE if enabled else 0.0
        post_rate = rate + impulse / 0.05
        energy = 0.5 * 0.05 * (post_rate**2 - rate**2)
        absorbed = max(0.0, -energy) if enabled else 0.0
        net = -absorbed if enabled else 0.0
        activation_receipts.append(
            {
                "cell_id": config["cell_id"],
                "ok": True,
                "activation_route_id": ACTIVATION_ROUTE_ID,
                "unfreeze_write_count": 1,
                "can_sleep_write_count": 1,
                "sleeping_write_count": 1,
                "scene_property_angular_velocity_write_count": 1,
                "physics_server_state_write_count": 0,
                "declared_canonical_rate_rad_s": config["initial_canonical_rate_rad_s"],
                "scene_canonical_rate_readback_rad_s": rate,
                "physics_server_canonical_rate_readback_rad_s": rate,
            }
        )
        cells.append(
            {
                "cell_id": config["cell_id"],
                "family": config["family"],
                "motor_enabled": enabled,
                "canonical_target_velocity_rad_s": 0.0,
                "initial_canonical_rate_rad_s": config["initial_canonical_rate_rad_s"],
                "public_maximum_motor_impulse_nms": 0.002,
                "pre_tree_read_refused": True,
                "parameter_readback": {
                    "child_mass_kg": 1.0,
                    "child_inertia_diagonal_kg_m2": [EXPECTED_NATIVE_INERTIA] * 3,
                    "gravity_scale": 0.0,
                    "linear_damping": 0.0,
                    "angular_damping": 0.0,
                    "collision_layer": 0,
                    "collision_mask": 0,
                    "motor_enabled": enabled,
                    "joint_limits_enabled": False,
                    "host_target_velocity_rad_s": 0.0,
                    "public_maximum_motor_impulse_nms": EXPECTED_REAL_T_IMPULSE,
                    "lower_limit_rad": -1.0,
                    "upper_limit_rad": 1.0,
                    "anchor_error_m": 0.0,
                    "axis_error_rad": 0.0,
                },
                "samples": [
                    {
                        "step_index": 1,
                        "pre_canonical_relative_rate_rad_s": rate,
                        "post_canonical_relative_rate_rad_s": post_rate,
                        "inverse_inertia_axis_kg_inv_m2": EXPECTED_INVERSE_INERTIA,
                        "host_target_velocity_readback_rad_s": 0.0,
                        "telemetry": {
                            "schema": TELEMETRY_SCHEMA,
                            "telemetry_sequence": 1,
                            "capture_space_step_sequence": 1,
                            "read_space_step_sequence": 1,
                            "captured_during_active_step": True,
                            "snapshot_is_current_space_step": True,
                            "solver_step_s": EXPECTED_DT,
                            "motor_state": "velocity" if enabled else "off",
                            "target_angular_velocity_rad_s": 0.0,
                            "min_torque_limit_nm": -EXPECTED_REAL_T_TORQUE,
                            "max_torque_limit_nm": EXPECTED_REAL_T_TORQUE,
                            "signed_motor_impulse_nms": impulse,
                            "positive_motor_work_j": 0.0,
                            "absorbed_motor_work_j": absorbed,
                            "net_motor_work_j": net,
                        },
                        "child_sleeping": False,
                    }
                ],
            }
        )
    return {
        "schema_version": RAW_SCHEMA,
        "gate_id": GATE_ID,
        "question_class": "development",
        "evidence_kind": evidence_kind,
        "source_commit": source_commit,
        "execution_nonce": nonce,
        "authorization": {
            "decision_gate_id": "QSDK-R24D11",
            "decision_path": "sdk/recovery/r24d11_godot_jolt_instrumented_profile_promotion_decision_v1.json",
            "decision_raw_sha256": R24D11_DECISION_SHA,
            "decision_publication_commit": "324620ee4f228e856a898dff1be96fe4351b8ff0",
            "same_source_rerun": False,
        },
        "runtime_provenance": {
            "runtime_profile_id": "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2",
            "godot_source_commit": "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88",
            "combined_patch_raw_sha256": RUNTIME_PATCH_SHA,
            "activation_route_id": ACTIVATION_ROUTE_ID,
            "engine_build_reuse_scope": "exact_unchanged_native_runtime_bytes_only",
        },
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
            "activation_route_id": ACTIVATION_ROUTE_ID,
            "world_count": 1,
            "isolated_cell_count": 4,
            "cell_ids_in_order": CELL_IDS,
            "hinges_per_cell": 1,
            "dynamic_bodies_per_cell": 1,
            "static_parents_per_cell": 1,
            "child_mass_kg": 1.0,
            "child_inertia_diagonal_kg_m2": [EXPECTED_NATIVE_INERTIA] * 3,
            "hinge_axis_parent_local": [0.0, 0.0, 1.0],
            "maximum_physics_step_count": 1,
            "retained_sample_count": 4,
            "gravity_scale": 0.0,
            "linear_damping": 0.0,
            "angular_damping": 0.0,
            "collision_layer": 0,
            "collision_mask": 0,
            "contact_count": 0,
            "joint_limits_enabled": False,
            "lower_limit_rad": -1.0,
            "upper_limit_rad": 1.0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
        },
        "refusals": {
            "invalid_rid_refused": True,
            "not_in_tree_joint_read_refused_by_cell": {cell_id: True for cell_id in CELL_IDS},
        },
        "activation_receipts": activation_receipts,
        "cells": cells,
        "execution": {
            "world_attempt_count": 1,
            "world_build_count": 1,
            "physics_step_count": 1,
            "retained_sample_count": 4,
            "direct_force_write_count": 0,
            "direct_torque_write_count": 0,
            "direct_impulse_write_count": 0,
            "post_activation_transform_write_count": 0,
            "unfreeze_write_count": 4,
            "scene_property_angular_velocity_write_count": 4,
            "physics_server_state_write_count": 0,
            "pre_sample_physics_frame_count": 0,
            "schedule_start_physics_frame_boundary_count": 1,
            "terminal_physics_server_deactivation_count": 1,
            "outcome_dependent_early_stop_count": 0,
            "space_step_sequence_initial_value": 0,
            "first_retained_space_step_sequence": 1,
            "last_retained_space_step_sequence": 1,
            "observed_retained_space_step_token_count": 1,
            "extra_unretained_post_activation_step_count": 0,
            "physics_server_disabled_before_step_two": True,
        },
        "evidence_provenance": {
            "synthetic_shape_only": evidence_kind == "synthetic_zero_world",
            "native_physical_observation": evidence_kind == "native_physical",
        },
        "claims": {
            "descriptive_development_characterization_only": True,
            "mechanism_witness_is_performance_threshold": False,
            **{field: False for field in FALSE_CLAIMS},
        },
    }


def set_path(value: dict[str, Any], path: tuple[Any, ...], replacement: Any) -> None:
    target: Any = value
    for part in path[:-1]:
        target = target[part]
    target[path[-1]] = replacement


def self_test() -> tuple[int, int]:
    require(
        struct.pack("<f", EXPECTED_NATIVE_INERTIA).hex() == "cdcc4c3d",
        "SELF_TEST_NATIVE_INERTIA_BINARY32",
    )
    require(
        struct.pack("<f", NATIVE_REAL_T_IMPULSE).hex() == "6f12033b"
        and struct.unpack("<f", struct.pack("<f", EXPECTED_REAL_T_IMPULSE))[0]
        == NATIVE_REAL_T_IMPULSE,
        "SELF_TEST_NATIVE_IMPULSE_SERIALIZER_PROJECTION",
    )
    require(
        struct.pack("<f", NATIVE_DT).hex() == "8988083c"
        and struct.unpack("<f", struct.pack("<f", EXPECTED_DT))[0] == NATIVE_DT,
        "SELF_TEST_NATIVE_DT_SERIALIZER_PROJECTION",
    )
    source = "1" * 40
    nonce = "2" * 32
    synthetic = synthetic_report(source, nonce)
    evaluation = evaluate(
        synthetic,
        expected_evidence_kind="synthetic_zero_world",
        expected_source_commit=source,
        expected_nonce=nonce,
    )
    require(evaluation["result"] == "synthetic_shape_conforms_zero_world_only", "SELF_TEST_SYNTHETIC_RESULT")
    positive = synthetic_report(source, nonce, "native_physical")
    positive_evaluation = evaluate(
        positive,
        expected_evidence_kind="native_physical",
        expected_source_commit=source,
        expected_nonce=nonce,
    )
    require(positive_evaluation["result"].endswith("_positive"), "SELF_TEST_POSITIVE_RESULT")

    invalid_cases: list[tuple[str, tuple[Any, ...], Any]] = [
        ("schema", ("schema_version",), "mutated"),
        ("gate", ("gate_id",), "QSDK-MUTATED"),
        ("question", ("question_class",), "finite_decision"),
        ("evidence", ("evidence_kind",), "other"),
        ("source", ("source_commit",), "0" * 40),
        ("nonce", ("execution_nonce",), "0" * 32),
        ("decision", ("authorization", "decision_raw_sha256"), "sha256:" + "0" * 64),
        ("runtime_patch", ("runtime_provenance", "combined_patch_raw_sha256"), "sha256:" + "0" * 64),
        ("engine", ("engine", "physics_engine"), "GodotPhysics3D"),
        ("fixture", ("fixture", "fixture_id"), "mutated"),
        (
            "authored_double_inertia",
            ("fixture", "child_inertia_diagonal_kg_m2"),
            [0.05, 0.05, 0.05],
        ),
        (
            "unserialized_native_impulse_projection",
            (
                "cells",
                0,
                "parameter_readback",
                "public_maximum_motor_impulse_nms",
            ),
            NATIVE_REAL_T_IMPULSE,
        ),
        (
            "unserialized_native_dt_projection",
            ("cells", 0, "samples", 0, "telemetry", "solver_step_s"),
            NATIVE_DT,
        ),
        ("route", ("fixture", "activation_route_id"), "mutated"),
        ("cell_order", ("fixture", "cell_ids_in_order"), list(reversed(CELL_IDS))),
        ("refusal", ("refusals", "invalid_rid_refused"), False),
        ("activation_route", ("activation_receipts", 0, "activation_route_id"), "mutated"),
        ("activation_rate", ("activation_receipts", 0, "physics_server_canonical_rate_readback_rad_s"), 0.0),
        ("motor_config", ("cells", 0, "motor_enabled"), False),
        ("parameter", ("cells", 0, "parameter_readback", "child_mass_kg"), 2.0),
        ("sample_step", ("cells", 0, "samples", 0, "step_index"), 2),
        ("sample_pre", ("cells", 0, "samples", 0, "pre_canonical_relative_rate_rad_s"), 0.0),
        ("telemetry_schema", ("cells", 0, "samples", 0, "telemetry", "schema"), "mutated"),
        ("telemetry_sequence", ("cells", 0, "samples", 0, "telemetry", "read_space_step_sequence"), 2),
        ("freshness", ("cells", 0, "samples", 0, "telemetry", "snapshot_is_current_space_step"), False),
        ("execution_step", ("execution", "physics_step_count"), 2),
        ("direct_torque", ("execution", "direct_torque_write_count"), 1),
        ("authority", ("claims", "release_authority"), True),
    ]
    rejected = 0
    for case_id, path, replacement in invalid_cases:
        mutated = copy.deepcopy(positive)
        set_path(mutated, path, replacement)
        try:
            evaluate(
                mutated,
                expected_evidence_kind="native_physical",
                expected_source_commit=source,
                expected_nonce=nonce,
            )
        except EvaluationError:
            rejected += 1
        else:
            fail(f"SELF_TEST_INVALID_MUTATION_ACCEPTED:{case_id}")

    def clear_enabled(cell_index: int) -> Callable[[dict[str, Any]], None]:
        def apply(report: dict[str, Any]) -> None:
            telemetry = report["cells"][cell_index]["samples"][0]["telemetry"]
            telemetry["signed_motor_impulse_nms"] = 0.0
            telemetry["absorbed_motor_work_j"] = 0.0
            telemetry["net_motor_work_j"] = 0.0
        return apply

    adverse_cases: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        ("brake_positive_zero", clear_enabled(0)),
        ("brake_negative_zero", clear_enabled(1)),
        (
            "disabled_positive_nonzero",
            lambda report: report["cells"][2]["samples"][0]["telemetry"].update(
                {"signed_motor_impulse_nms": 0.001}
            ),
        ),
        (
            "brake_positive_same_direction",
            lambda report: report["cells"][0]["samples"][0]["telemetry"].update(
                {"signed_motor_impulse_nms": EXPECTED_REAL_T_IMPULSE}
            ),
        ),
    ]
    accepted_adverse = 0
    for case_id, apply in adverse_cases:
        mutated = copy.deepcopy(positive)
        apply(mutated)
        result = evaluate(
            mutated,
            expected_evidence_kind="native_physical",
            expected_source_commit=source,
            expected_nonce=nonce,
        )
        require(result["result"].endswith("_negative"), f"SELF_TEST_ADVERSE_NOT_NEGATIVE:{case_id}")
        accepted_adverse += 1
    return rejected, accepted_adverse


def load_report(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    return object_value(value, "INPUT_NOT_OBJECT")


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--expected-evidence-kind", choices=("synthetic_zero_world", "native_physical"))
    parser.add_argument("--expected-source-commit")
    parser.add_argument("--expected-nonce")
    parser.add_argument("--emit-zero-world-template", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        rejected, adverse = self_test()
        print(
            "QSDK_R24D13_EVALUATOR_SELF_TEST_PASS "
            f"invalid_mutations={rejected} accepted_adverse_outcomes={adverse} "
            "worlds=0 builds=0 solver_steps=0"
        )
        return 0
    require(bool(args.expected_source_commit) and len(args.expected_source_commit) == 40, "CLI_SOURCE_COMMIT")
    require(bool(args.expected_nonce) and len(args.expected_nonce) == 32, "CLI_NONCE")
    if args.emit_zero_world_template:
        write_json(
            args.emit_zero_world_template,
            synthetic_report(args.expected_source_commit, args.expected_nonce),
        )
        print(
            "QSDK_R24D13_SYNTHETIC_TEMPLATE "
            "ok=true worlds=0 builds=0 solver_steps=0"
        )
        return 0
    require(args.input is not None and args.output is not None, "CLI_INPUT_OUTPUT")
    require(args.expected_evidence_kind is not None, "CLI_EVIDENCE_KIND")
    evaluation = evaluate(
        load_report(args.input),
        expected_evidence_kind=args.expected_evidence_kind,
        expected_source_commit=args.expected_source_commit,
        expected_nonce=args.expected_nonce,
    )
    write_json(args.output, evaluation)
    print(
        "QSDK_R24D13_EVALUATION "
        f"ok=true result={evaluation['result']} "
        f"enabled_witnesses={evaluation['summary']['motor_enabled_braking_witness_count']}/2 "
        f"disabled_zero={evaluation['summary']['motor_disabled_zero_witness_count']}/2"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except EvaluationError as error:
        print(f"QSDK_R24D13_EVALUATION_FAILURE code={error}")
        raise SystemExit(1)
