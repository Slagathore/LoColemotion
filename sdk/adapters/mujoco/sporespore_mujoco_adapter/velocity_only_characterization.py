"""Finite MuJoCo velocity-only host characterization for C6-MJC-HC-VH1.

The preflight path constructs no ``MjModel``.  The physical path is guarded by
the repository supervisor and always returns a complete positive or negative
report for all twelve prospectively declared cells.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import sys
from pathlib import Path
from typing import Any

import mujoco
import numpy as np

from .conformance import (
    LINE_SEARCH_ITERATIONS,
    MUJOCO_DT_S,
    SOLVER_ITERATIONS,
    ConformanceFailure,
    _option_xml,
    _require,
)


CAMPAIGN_ID = "C6-MUJOCO-VELOCITY-ONLY-HOST-CHARACTERIZATION-VH1"
GATE_ID = "C6-MJC-HC-VH1"
REPORT_SCHEMA = (
    "sporespore_mujoco_c6_velocity_only_host_characterization_vh1_report_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_mujoco_c6_velocity_only_host_characterization_vh1_preflight_v1"
)
PROFILE_ID = "mujoco_velocity_servo_force_limited_v1"

SDK_ROOT = Path(__file__).resolve().parents[3]
PREREGISTRATION_PATH = (
    SDK_ROOT / "mujoco_c6_velocity_only_host_characterization_vh1_preregistration.json"
)
EXPECTED_PREREGISTRATION_SHA256 = (
    "sha256:0a4fad451f39987bbeaa0ed8fb5ae17d5dff76445ead28c89de7d5ff0cb611c5"
)

VELOCITY_GAIN = 10.0
MAXIMUM_FORCE_NM = 6.0
MAXIMUM_STEP_IMPULSE_NMS = MAXIMUM_FORCE_NM * MUJOCO_DT_S
OUTER_STEPS = 360
FIRST_ACCEPTABLE_STEP = 120
REQUIRED_STREAK = 60
RESPONSE_MINIMUM = 0.98
RESPONSE_MAXIMUM = 1.02
MAXIMUM_PAIR_ASYMMETRY = 0.005
MAXIMUM_ANCHOR_WORLD_POSITION_RESIDUAL_M = 1.0e-12
MAXIMUM_ACTUATION_TO_JOINT_FORCE_ERROR_NM = 1.0e-12
MAXIMUM_APPLIED_TORQUE_READBACK_ERROR_NM = 1.0e-12
NUMERIC_IMPULSE_TOLERANCE_NMS = 1.0e-12
DECLARED_ANCHOR_WORLD_M = np.asarray([0.0, 0.0, 0.0], dtype=np.float64)
DECLARED_JOINT_AXIS = np.asarray([1.0, 0.0, 0.0], dtype=np.float64)
DECLARED_ACTUATOR_GEAR = np.asarray(
    [1.0, 0.0, 0.0, 0.0, 0.0, 0.0], dtype=np.float64
)


def _raw_sha256(path: Path) -> str:
    return f"sha256:{hashlib.sha256(path.read_bytes()).hexdigest()}"


def _numeric_sequence_matches(
    observed: Any,
    expected: list[float] | np.ndarray[Any, Any],
    tolerance: float = 1.0e-12,
) -> bool:
    try:
        observed_array = np.asarray(observed, dtype=np.float64)
        expected_array = np.asarray(expected, dtype=np.float64)
    except (TypeError, ValueError):
        return False
    return bool(
        observed_array.shape == expected_array.shape
        and np.isfinite(observed_array).all()
        and np.linalg.norm(observed_array - expected_array) <= tolerance
    )


def _host_identity_receipt(declaration: dict[str, Any]) -> dict[str, Any]:
    """Verify the exact interpreter and official-wheel files without a world."""

    host = declaration["host_identity"]
    source = declaration["host_source_semantics"]
    site_packages = Path(mujoco.__file__).resolve().parent.parent
    requirements_lock = SDK_ROOT / "adapters" / "mujoco" / "requirements-lock.txt"
    base_executable = Path(sys._base_executable).resolve()
    _require(
        mujoco.__version__ == host["engine_version"]
        and np.__version__ == host["numpy_version"]
        and sys.version.split()[0] == host["python_version"],
        "C6_MJC_HC_VH1_HOST_VERSION_MISMATCH",
        f"python={sys.version.split()[0]} mujoco={mujoco.__version__} numpy={np.__version__}",
    )
    _require(
        requirements_lock.is_file()
        and _raw_sha256(requirements_lock)
        == f"sha256:{source['requirements_lock_raw_sha256']}",
        "C6_MJC_HC_VH1_REQUIREMENTS_LOCK_MISMATCH",
    )
    _require(
        base_executable.as_posix().lower()
        == str(source["python_base_executable"]).lower()
        and _raw_sha256(base_executable)
        == f"sha256:{source['python_base_executable_raw_sha256']}",
        "C6_MJC_HC_VH1_PYTHON_EXECUTABLE_MISMATCH",
        base_executable.as_posix(),
    )
    verified_files: list[dict[str, Any]] = []
    for expected in source["installed_wheel_files"]:
        relative = Path(str(expected["relative_to_site_packages"]))
        path = (site_packages / relative).resolve()
        _require(
            path.is_relative_to(site_packages)
            and path.is_file()
            and _raw_sha256(path) == f"sha256:{expected['raw_sha256']}",
            "C6_MJC_HC_VH1_WHEEL_FILE_MISMATCH",
            relative.as_posix(),
        )
        verified_files.append(
            {
                "relative_to_site_packages": relative.as_posix(),
                "raw_sha256": f"sha256:{expected['raw_sha256']}",
            }
        )
    return {
        "engine": "MuJoCo",
        "engine_version": mujoco.__version__,
        "binding": host["binding"],
        "python_version": sys.version.split()[0],
        "python_base_executable": base_executable.as_posix(),
        "python_base_executable_raw_sha256": _raw_sha256(base_executable),
        "numpy_version": np.__version__,
        "requirements_lock_raw_sha256": _raw_sha256(requirements_lock),
        "verified_wheel_file_count": len(verified_files),
        "verified_wheel_files": verified_files,
        "world_build_count": 0,
        "physics_state_modified": False,
    }


def _preregistration() -> dict[str, Any]:
    _require(
        PREREGISTRATION_PATH.is_file(),
        "C6_MJC_HC_VH1_PREREGISTRATION_MISSING",
        str(PREREGISTRATION_PATH),
    )
    observed_hash = _raw_sha256(PREREGISTRATION_PATH)
    _require(
        observed_hash == EXPECTED_PREREGISTRATION_SHA256,
        "C6_MJC_HC_VH1_PREREGISTRATION_HASH_MISMATCH",
        observed_hash,
    )
    declaration = json.loads(PREREGISTRATION_PATH.read_text(encoding="utf-8"))
    _require(
        declaration.get("campaign_id") == CAMPAIGN_ID
        and declaration.get("gate_id") == GATE_ID
        and declaration.get("status")
        == "frozen_before_first_c6_mjc_hc_vh1_physics_world",
        "C6_MJC_HC_VH1_PREREGISTRATION_IDENTITY_INVALID",
    )
    profile = declaration.get("motor_profile", {})
    host = declaration.get("host_identity", {})
    fixture = declaration.get("fixture", {})
    grid = declaration.get("physical_grid", {})
    _require(
        profile.get("profile_id") == PROFILE_ID
        and profile.get("native_actuator") == "velocity"
        and profile.get("transmission_type") == "mjTRN_JOINT"
        and _numeric_sequence_matches(
            profile.get("transmission_gear"), DECLARED_ACTUATOR_GEAR
        )
        and profile.get("velocity_gain_nm_s_per_rad") == VELOCITY_GAIN
        and profile.get("minimum_force_nm") == -MAXIMUM_FORCE_NM
        and profile.get("maximum_force_nm") == MAXIMUM_FORCE_NM
        and profile.get("maximum_declared_load_fraction_of_force_limit") == 0.375
        and profile.get("native_position_target") is False
        and profile.get("independent_native_position_feedback") is False
        and profile.get("saturation_boundary", {}).get(
            "every_declared_physical_load_is_strictly_sub_limit"
        )
        is True
        and profile.get("saturation_boundary", {}).get(
            "dynamic_force_saturation_response_characterized"
        )
        is False,
        "C6_MJC_HC_VH1_MOTOR_PROFILE_DECLARATION_INVALID",
    )
    _require(
        host.get("engine") == "MuJoCo"
        and host.get("engine_version") == "3.11.0"
        and host.get("binding") == "official_cpython_windows_wheel"
        and host.get("python_version") == "3.11.9"
        and host.get("numpy_version") == "2.4.6"
        and host.get("timestep_s") == MUJOCO_DT_S
        and host.get("integrator") == "implicitfast"
        and host.get("solver") == "Newton"
        and host.get("solver_iterations") == SOLVER_ITERATIONS == 20
        and host.get("line_search_iterations") == LINE_SEARCH_ITERATIONS == 7
        and _numeric_sequence_matches(host.get("gravity_m_s2"), [0.0, 0.0, 0.0]),
        "C6_MJC_HC_VH1_HOST_DECLARATION_INVALID",
    )
    _require(
        fixture.get("joint_type") == "unlimited_hinge"
        and _numeric_sequence_matches(
            fixture.get("joint_axis_mujoco"), DECLARED_JOINT_AXIS
        )
        and _numeric_sequence_matches(
            fixture.get("joint_anchor_world_m"), DECLARED_ANCHOR_WORLD_M
        )
        and fixture.get("joint_armature") == 0.01
        and fixture.get("joint_passive_damping") == 0.0
        and fixture.get("child_shape") == "box"
        and _numeric_sequence_matches(
            fixture.get("child_half_extents_m"), [0.1, 0.1, 0.1]
        )
        and fixture.get("child_mass_kg") == 1.0
        and fixture.get("contacts_enabled") is False
        and fixture.get("primary_data_buffers_per_world") == 1
        and fixture.get("read_only_observation_data_buffers_per_world") == 1
        and fixture.get("observation_buffer_modifies_primary_trajectory") is False,
        "C6_MJC_HC_VH1_FIXTURE_DECLARATION_INVALID",
    )
    _require(
        grid.get("outer_steps_per_cell") == OUTER_STEPS
        and grid.get("first_acceptable_step") == FIRST_ACCEPTABLE_STEP
        and grid.get("required_consecutive_acceptable_steps") == REQUIRED_STREAK
        and grid.get("worlds") == 12
        and grid.get("replacement_worlds") == 0
        and grid.get("early_stop_forbidden") is True
        and len(grid.get("ordered_cells", [])) == 12,
        "C6_MJC_HC_VH1_GRID_DECLARATION_INVALID",
    )
    _require(
        declaration.get("claim_boundary", {}).get("dynamic_force_saturation_response")
        is False
        and declaration.get("claim_boundary", {}).get("mujoco_walking") is False
        and declaration.get("claim_boundary", {}).get("physical_acceptance_authority")
        is False,
        "C6_MJC_HC_VH1_CLAIM_BOUNDARY_INVALID",
    )
    return declaration


def _declared_cells(declaration: dict[str, Any]) -> list[dict[str, Any]]:
    cells = declaration["physical_grid"]["ordered_cells"]
    identifiers = [str(cell["cell_id"]) for cell in cells]
    _require(
        len(identifiers) == len(set(identifiers)) == 12,
        "C6_MJC_HC_VH1_CELL_IDENTITIES_INVALID",
    )
    return cells


def _relative_asymmetry(left: float, right: float) -> float:
    denominator = max(abs(left), abs(right), 1.0e-12)
    return abs(abs(left) - abs(right)) / denominator


def _pair_asymmetries(cells: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_id = {str(cell["cell_id"]): cell for cell in cells}
    pairs = [
        ("unloaded_075", "unloaded_vn075", "unloaded_vp075"),
        ("unloaded_225", "unloaded_vn225", "unloaded_vp225"),
        ("loaded_150_075_same", "loaded_vn150_tn075", "loaded_vp150_tp075"),
        ("loaded_150_075_cross", "loaded_vn150_tp075", "loaded_vp150_tn075"),
        ("loaded_150_225_same", "loaded_vn150_tn225", "loaded_vp150_tp225"),
        ("loaded_150_225_cross", "loaded_vn150_tp225", "loaded_vp150_tn225"),
    ]
    receipts: list[dict[str, Any]] = []
    for pair_id, left_id, right_id in pairs:
        left = by_id.get(left_id)
        right = by_id.get(right_id)
        if left is None or right is None:
            receipts.append(
                {
                    "pair_id": pair_id,
                    "left_cell_id": left_id,
                    "right_cell_id": right_id,
                    "velocity_response_relative_asymmetry": None,
                    "force_response_relative_asymmetry": None,
                    "passed": False,
                }
            )
            continue
        velocity_asymmetry = _relative_asymmetry(
            float(left["terminal_normalized_velocity_response"]),
            float(right["terminal_normalized_velocity_response"]),
        )
        force_asymmetry: float | None = None
        if left["kind"] == "loaded":
            force_asymmetry = _relative_asymmetry(
                float(left["terminal_normalized_force_response"]),
                float(right["terminal_normalized_force_response"]),
            )
        passed = velocity_asymmetry <= MAXIMUM_PAIR_ASYMMETRY and (
            force_asymmetry is None or force_asymmetry <= MAXIMUM_PAIR_ASYMMETRY
        )
        receipts.append(
            {
                "pair_id": pair_id,
                "left_cell_id": left_id,
                "right_cell_id": right_id,
                "velocity_response_relative_asymmetry": velocity_asymmetry,
                "force_response_relative_asymmetry": force_asymmetry,
                "passed": passed,
            }
        )
    return receipts


def _motor_readback_matches(readback: Any, target: float) -> bool:
    if not isinstance(readback, dict):
        return False
    return bool(
        readback.get("native_actuator") == "velocity"
        and readback.get("transmission_type") == "mjTRN_JOINT"
        and readback.get("transmission_type_code") == 0
        and readback.get("transmission_target_joint_id_matches") is True
        and _numeric_sequence_matches(
            readback.get("transmission_gear"), DECLARED_ACTUATOR_GEAR
        )
        and readback.get("control_target_velocity_rad_s") == target
        and readback.get("control_limited") is False
        and readback.get("velocity_gain_nm_s_per_rad") == VELOCITY_GAIN
        and readback.get("velocity_bias_gain_nm_s_per_rad") == -VELOCITY_GAIN
        and readback.get("force_limited") is True
        and _numeric_sequence_matches(
            readback.get("force_range_nm"), [-MAXIMUM_FORCE_NM, MAXIMUM_FORCE_NM]
        )
        and readback.get("joint_type") == "hinge"
        and readback.get("joint_limited") is False
        and _numeric_sequence_matches(readback.get("joint_axis"), DECLARED_JOINT_AXIS)
        and readback.get("joint_armature") == 0.01
        and readback.get("joint_passive_damping") == 0.0
        and _numeric_sequence_matches(
            readback.get("child_half_extents_m"), [0.1, 0.1, 0.1]
        )
        and readback.get("child_mass_kg") == 1.0
        and readback.get("contacts_enabled") is False
        and readback.get("timestep_s") == MUJOCO_DT_S
        and readback.get("integrator") == "implicitfast"
        and readback.get("solver") == "Newton"
        and readback.get("solver_iterations") == SOLVER_ITERATIONS
        and readback.get("line_search_iterations") == LINE_SEARCH_ITERATIONS
        and _numeric_sequence_matches(readback.get("gravity_m_s2"), [0.0, 0.0, 0.0])
        and readback.get("native_position_target") is False
        and readback.get("independent_native_position_feedback") is False
    )


def evaluate_velocity_only_host_report(report: dict[str, Any]) -> list[str]:
    """Evaluate one real or synthetic report through the complete frozen gate."""

    failures: list[str] = []
    try:
        declaration = _preregistration()
        declared = _declared_cells(declaration)
    except (ConformanceFailure, OSError, ValueError, json.JSONDecodeError) as error:
        return [f"C6_MJC_HC_VH1_DECLARATION_INVALID:{error}"]

    if report.get("schema_version") != REPORT_SCHEMA:
        failures.append("C6_MJC_HC_VH1_REPORT_SCHEMA")
    if report.get("campaign_id") != CAMPAIGN_ID or report.get("gate_id") != GATE_ID:
        failures.append("C6_MJC_HC_VH1_REPORT_IDENTITY")
    if report.get("motor_profile", {}).get("profile_id") != PROFILE_ID:
        failures.append("C6_MJC_HC_VH1_REPORT_MOTOR_PROFILE")
    expected_ids = [str(cell["cell_id"]) for cell in declared]
    cells = report.get("cells")
    if not isinstance(cells, list):
        return failures + ["C6_MJC_HC_VH1_CELLS_MISSING"]
    observed_ids = [str(cell.get("cell_id")) for cell in cells]
    if observed_ids != expected_ids or len(set(observed_ids)) != 12:
        failures.append("C6_MJC_HC_VH1_CELL_ORDER_OR_CARDINALITY")

    for cell in cells:
        cell_id = str(cell.get("cell_id", "unknown"))
        numeric_values = [
            cell.get("target_velocity_rad_s"),
            cell.get("external_torque_nm"),
            cell.get("predicted_terminal_velocity_rad_s"),
            cell.get("terminal_joint_velocity_rad_s"),
            cell.get("terminal_actuator_force_nm"),
            cell.get("terminal_generalized_actuator_torque_nm"),
            cell.get("terminal_external_applied_torque_nm"),
            cell.get("terminal_normalized_velocity_response"),
            cell.get("maximum_joint_anchor_world_position_residual_m"),
            cell.get("maximum_actuation_space_to_joint_space_force_error_nm"),
            cell.get("maximum_applied_torque_readback_error_nm"),
            cell.get("maximum_derived_step_impulse_nms"),
        ]
        if not all(
            isinstance(value, (int, float)) and math.isfinite(float(value))
            for value in numeric_values
        ):
            failures.append(f"C6_MJC_HC_VH1_NONFINITE:{cell_id}")
            continue
        kind = cell.get("kind")
        velocity_response = float(cell["terminal_normalized_velocity_response"])
        force_response = cell.get("terminal_normalized_force_response")
        if kind == "loaded" and not (
            isinstance(force_response, (int, float))
            and math.isfinite(float(force_response))
        ):
            failures.append(f"C6_MJC_HC_VH1_FORCE_RESPONSE_MISSING:{cell_id}")
        passed = (
            cell.get("motor_profile_fields_match") is True
            and _motor_readback_matches(
                cell.get("motor_readback"), float(cell["target_velocity_rad_s"])
            )
            and cell.get("all_values_finite") is True
            and cell.get("target_and_response_signs_match") is True
            and cell.get("loaded_force_opposes_external_torque") is True
            and int(cell.get("steps_executed", -1)) == OUTER_STEPS
            and int(cell.get("longest_acceptable_streak", -1)) >= REQUIRED_STREAK
            and RESPONSE_MINIMUM <= velocity_response <= RESPONSE_MAXIMUM
            and float(cell["maximum_joint_anchor_world_position_residual_m"])
            <= MAXIMUM_ANCHOR_WORLD_POSITION_RESIDUAL_M
            and float(
                cell["maximum_actuation_space_to_joint_space_force_error_nm"]
            )
            <= MAXIMUM_ACTUATION_TO_JOINT_FORCE_ERROR_NM
            and float(cell["maximum_applied_torque_readback_error_nm"])
            <= MAXIMUM_APPLIED_TORQUE_READBACK_ERROR_NM
            and float(cell["maximum_derived_step_impulse_nms"])
            <= MAXIMUM_STEP_IMPULSE_NMS + NUMERIC_IMPULSE_TOLERANCE_NMS
            and int(cell.get("derived_step_impulse_limit_violation_count", -1)) == 0
            and int(cell.get("nonfinite_observation_count", -1)) == 0
        )
        if kind == "loaded":
            passed = passed and RESPONSE_MINIMUM <= float(force_response) <= RESPONSE_MAXIMUM
        if cell.get("passed") is not True or not passed:
            failures.append(f"C6_MJC_HC_VH1_CELL_GATE:{cell_id}")

    pairs = _pair_asymmetries(cells)
    if len(pairs) != 6 or not all(pair["passed"] for pair in pairs):
        failures.append("C6_MJC_HC_VH1_MIRRORED_PAIR_GATE")
    counts = report.get("integrity", {})
    exact_counts = {
        "world_attempt_count": 12,
        "world_build_count": 12,
        "world_reset_count": 0,
        "model_or_field_mismatch_count": 0,
        "nonfinite_observation_count": 0,
        "derived_step_impulse_limit_violation_count": 0,
        "actuation_space_to_joint_space_force_mismatch_count": 0,
        "applied_torque_readback_mismatch_count": 0,
    }
    for name, expected in exact_counts.items():
        if counts.get(name) != expected:
            failures.append(f"C6_MJC_HC_VH1_INTEGRITY_{name.upper()}")
    if report.get("controller_policy_authority") is not False:
        failures.append("C6_MJC_HC_VH1_CONTROLLER_AUTHORITY")
    if report.get("selected_policy_physical_authority") is not False:
        failures.append("C6_MJC_HC_VH1_SELECTED_POLICY_AUTHORITY")
    if report.get("physical_acceptance_authority") is not False:
        failures.append("C6_MJC_HC_VH1_PHYSICAL_AUTHORITY")
    claim_boundary = report.get("claim_boundary", {})
    for forbidden_claim in (
        "dynamic_force_saturation_response",
        "mujoco_selected_policy_locomotion",
        "mujoco_walking",
        "cross_engine_equivalence",
        "continuous_host_domain_coverage",
        "morphology_coverage",
        "friction_or_material_robustness",
        "release_authority",
        "physical_acceptance_authority",
        "completed_engine_neutral_sdk",
    ):
        if claim_boundary.get(forbidden_claim) is not False:
            failures.append(f"C6_MJC_HC_VH1_CLAIM_{forbidden_claim.upper()}")
    return failures


def _perfect_motor_readback(target: float) -> dict[str, Any]:
    return {
        "native_actuator": "velocity",
        "transmission_type": "mjTRN_JOINT",
        "transmission_type_code": 0,
        "transmission_target_joint_id_matches": True,
        "transmission_gear": DECLARED_ACTUATOR_GEAR.tolist(),
        "control_target_velocity_rad_s": target,
        "control_limited": False,
        "velocity_gain_nm_s_per_rad": VELOCITY_GAIN,
        "velocity_bias_gain_nm_s_per_rad": -VELOCITY_GAIN,
        "force_limited": True,
        "force_range_nm": [-MAXIMUM_FORCE_NM, MAXIMUM_FORCE_NM],
        "joint_type": "hinge",
        "joint_limited": False,
        "joint_axis": DECLARED_JOINT_AXIS.tolist(),
        "joint_armature": 0.01,
        "joint_passive_damping": 0.0,
        "child_half_extents_m": [0.1, 0.1, 0.1],
        "child_mass_kg": 1.0,
        "contacts_enabled": False,
        "timestep_s": MUJOCO_DT_S,
        "integrator": "implicitfast",
        "solver": "Newton",
        "solver_iterations": SOLVER_ITERATIONS,
        "line_search_iterations": LINE_SEARCH_ITERATIONS,
        "gravity_m_s2": [0.0, 0.0, 0.0],
        "native_position_target": False,
        "independent_native_position_feedback": False,
    }


def _perfect_synthetic_report() -> dict[str, Any]:
    declaration = _preregistration()
    cells: list[dict[str, Any]] = []
    for declared in _declared_cells(declaration):
        target = float(declared["target_velocity_rad_s"])
        torque = float(declared["external_torque_nm"])
        predicted_velocity = target + torque / VELOCITY_GAIN
        cells.append(
            {
                **declared,
                "predicted_terminal_velocity_rad_s": predicted_velocity,
                "terminal_joint_position_rad": predicted_velocity * OUTER_STEPS * MUJOCO_DT_S,
                "terminal_joint_velocity_rad_s": predicted_velocity,
                "terminal_actuator_force_nm": -torque,
                "terminal_generalized_actuator_torque_nm": -torque,
                "terminal_external_applied_torque_nm": torque,
                "terminal_normalized_velocity_response": 1.0,
                "terminal_normalized_force_response": (
                    1.0 if declared["kind"] == "loaded" else None
                ),
                "maximum_joint_anchor_world_position_residual_m": 0.0,
                "maximum_actuation_space_to_joint_space_force_error_nm": 0.0,
                "maximum_applied_torque_readback_error_nm": 0.0,
                "maximum_derived_step_impulse_nms": abs(torque) * MUJOCO_DT_S,
                "steps_executed": OUTER_STEPS,
                "first_acceptable_step": FIRST_ACCEPTABLE_STEP,
                "longest_acceptable_streak": OUTER_STEPS - FIRST_ACCEPTABLE_STEP,
                "motor_profile_fields_match": True,
                "motor_readback": _perfect_motor_readback(target),
                "all_values_finite": True,
                "target_and_response_signs_match": True,
                "loaded_force_opposes_external_torque": True,
                "derived_step_impulse_limit_violation_count": 0,
                "nonfinite_observation_count": 0,
                "passed": True,
            }
        )
    return {
        "schema_version": REPORT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "motor_profile": {"profile_id": PROFILE_ID},
        "cells": cells,
        "mirrored_pairs": _pair_asymmetries(cells),
        "integrity": {
            "world_attempt_count": 12,
            "world_build_count": 12,
            "world_reset_count": 0,
            "model_or_field_mismatch_count": 0,
            "nonfinite_observation_count": 0,
            "derived_step_impulse_limit_violation_count": 0,
            "actuation_space_to_joint_space_force_mismatch_count": 0,
            "applied_torque_readback_mismatch_count": 0,
        },
        "claim_boundary": declaration["claim_boundary"],
        "controller_policy_authority": False,
        "selected_policy_physical_authority": False,
        "physical_acceptance_authority": False,
    }


def run_velocity_only_host_preflight() -> dict[str, Any]:
    declaration = _preregistration()
    host_identity = _host_identity_receipt(declaration)
    perfect = _perfect_synthetic_report()
    _require(
        evaluate_velocity_only_host_report(perfect) == [],
        "C6_MJC_HC_VH1_PERFECT_SYNTHETIC_REJECTED",
    )
    serialized_perfect = json.dumps(perfect, allow_nan=False, sort_keys=True)
    _require(
        evaluate_velocity_only_host_report(json.loads(serialized_perfect)) == [],
        "C6_MJC_HC_VH1_PERFECT_SYNTHETIC_ROUND_TRIP_REJECTED",
    )

    canaries: list[tuple[str, dict[str, Any]]] = []
    missing = json.loads(json.dumps(perfect))
    missing["cells"].pop()
    canaries.append(("missing_cell", missing))
    wrong_profile = json.loads(json.dumps(perfect))
    wrong_profile["cells"][0]["motor_profile_fields_match"] = False
    canaries.append(("wrong_motor_profile", wrong_profile))
    wrong_velocity = json.loads(json.dumps(perfect))
    wrong_velocity["cells"][0]["terminal_normalized_velocity_response"] = 0.97
    canaries.append(("wrong_velocity_response", wrong_velocity))
    wrong_force = json.loads(json.dumps(perfect))
    wrong_force["cells"][4]["terminal_normalized_force_response"] = 1.03
    canaries.append(("wrong_force_response", wrong_force))
    generalized_force = json.loads(json.dumps(perfect))
    generalized_force["cells"][4][
        "maximum_actuation_space_to_joint_space_force_error_nm"
    ] = 0.001
    generalized_force["integrity"][
        "actuation_space_to_joint_space_force_mismatch_count"
    ] = 1
    canaries.append(("actuation_space_to_joint_space_force_mismatch", generalized_force))
    applied_torque = json.loads(json.dumps(perfect))
    applied_torque["cells"][4]["maximum_applied_torque_readback_error_nm"] = 0.001
    applied_torque["integrity"]["applied_torque_readback_mismatch_count"] = 1
    canaries.append(("applied_torque_readback_mismatch", applied_torque))
    anchor = json.loads(json.dumps(perfect))
    anchor["cells"][0]["maximum_joint_anchor_world_position_residual_m"] = 0.001
    canaries.append(("anchor_world_position_residual", anchor))
    impulse = json.loads(json.dumps(perfect))
    impulse["cells"][4]["maximum_derived_step_impulse_nms"] = 0.051
    impulse["cells"][4]["derived_step_impulse_limit_violation_count"] = 1
    canaries.append(("impulse_limit", impulse))
    world_count = json.loads(json.dumps(perfect))
    world_count["integrity"]["world_build_count"] = 13
    canaries.append(("world_count_inflation", world_count))
    authority = json.loads(json.dumps(perfect))
    authority["physical_acceptance_authority"] = True
    canaries.append(("physical_authority_inflation", authority))
    rejected = {
        name: len(evaluate_velocity_only_host_report(canary)) > 0
        for name, canary in canaries
    }
    _require(
        all(rejected.values()),
        "C6_MJC_HC_VH1_NEGATIVE_CONTROL_ACCEPTED",
        json.dumps(rejected, sort_keys=True),
    )
    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "ok": True,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "preregistration_raw_sha256": EXPECTED_PREREGISTRATION_SHA256,
        "declared_cell_count": len(_declared_cells(declaration)),
        "host_identity": host_identity,
        "perfect_synthetic_result_passed": True,
        "perfect_synthetic_serialization_round_trip_passed": True,
        "negative_controls_rejected": rejected,
        "negative_control_count": len(rejected),
        "world_build_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
    }


def _model() -> mujoco.MjModel:
    xml = f"""
<mujoco model="sporespore_mujoco_velocity_only_vh1">
  <compiler angle="radian" inertiafromgeom="true"/>
  {_option_xml("0 0 0", integrator="implicitfast")}
  <worldbody>
    <body name="child" pos="0 0 0">
      <joint name="hinge" type="hinge" pos="0 0 0" axis="1 0 0" armature=".01"
             damping="0" limited="false"/>
      <geom name="child_geom" type="box" pos="0 0 0" size=".1 .1 .1" mass="1"
             contype="0" conaffinity="0"/>
    </body>
  </worldbody>
  <actuator>
    <velocity name="motor" joint="hinge" gear="1 0 0 0 0 0"
              ctrllimited="false" kv="{VELOCITY_GAIN:.17g}"
              forcelimited="true"
              forcerange="{-MAXIMUM_FORCE_NM:.17g} {MAXIMUM_FORCE_NM:.17g}"/>
  </actuator>
</mujoco>
"""
    return mujoco.MjModel.from_xml_string(xml)


def _run_cell(declared: dict[str, Any], model: mujoco.MjModel) -> dict[str, Any]:
    # The observation buffer is never fed back into the primary trajectory. It
    # lets mj_forward produce kinematics and force observables that all belong
    # to the same post-step integration state.
    data = mujoco.MjData(model)
    observation = mujoco.MjData(model)
    joint_id = model.joint("hinge").id
    actuator_id = model.actuator("motor").id
    child_body_id = model.body("child").id
    child_geom_id = model.geom("child_geom").id
    qpos_address = int(model.jnt_qposadr[joint_id])
    dof_address = int(model.jnt_dofadr[joint_id])
    target = float(declared["target_velocity_rad_s"])
    torque = float(declared["external_torque_nm"])
    predicted_velocity = target + torque / VELOCITY_GAIN

    force_range = np.asarray(model.actuator_forcerange[actuator_id], dtype=float)
    axis = np.asarray(model.jnt_axis[joint_id], dtype=float)
    gear = np.asarray(model.actuator_gear[actuator_id], dtype=float)
    half_extents = np.asarray(model.geom_size[child_geom_id], dtype=float)
    gravity = np.asarray(model.opt.gravity, dtype=float)
    transmission_type_code = int(model.actuator_trntype[actuator_id])
    joint_type_code = int(model.jnt_type[joint_id])
    integrator_code = int(model.opt.integrator)
    solver_code = int(model.opt.solver)
    transmission_type = (
        "mjTRN_JOINT"
        if transmission_type_code == int(mujoco.mjtTrn.mjTRN_JOINT)
        else f"code:{transmission_type_code}"
    )
    joint_type = (
        "hinge"
        if joint_type_code == int(mujoco.mjtJoint.mjJNT_HINGE)
        else f"code:{joint_type_code}"
    )
    integrator = (
        "implicitfast"
        if integrator_code == int(mujoco.mjtIntegrator.mjINT_IMPLICITFAST)
        else f"code:{integrator_code}"
    )
    solver = (
        "Newton"
        if solver_code == int(mujoco.mjtSolver.mjSOL_NEWTON)
        else f"code:{solver_code}"
    )
    motor_readback = {
        "native_actuator": "velocity",
        "transmission_type": transmission_type,
        "transmission_type_code": transmission_type_code,
        "transmission_target_joint_id_matches": int(
            model.actuator_trnid[actuator_id, 0]
        )
        == joint_id,
        "transmission_gear": gear.tolist(),
        "control_target_velocity_rad_s": target,
        "control_limited": bool(model.actuator_ctrllimited[actuator_id]),
        "velocity_gain_nm_s_per_rad": float(model.actuator_gainprm[actuator_id, 0]),
        "velocity_bias_gain_nm_s_per_rad": float(
            model.actuator_biasprm[actuator_id, 2]
        ),
        "force_limited": bool(model.actuator_forcelimited[actuator_id]),
        "force_range_nm": force_range.tolist(),
        "joint_type": joint_type,
        "joint_limited": bool(model.jnt_limited[joint_id]),
        "joint_axis": axis.tolist(),
        "joint_armature": float(model.dof_armature[dof_address]),
        "joint_passive_damping": float(model.dof_damping[dof_address]),
        "child_half_extents_m": half_extents.tolist(),
        "child_mass_kg": float(model.body_mass[child_body_id]),
        "contacts_enabled": bool(
            model.geom_contype[child_geom_id] != 0
            or model.geom_conaffinity[child_geom_id] != 0
        ),
        "timestep_s": float(model.opt.timestep),
        "integrator": integrator,
        "solver": solver,
        "solver_iterations": int(model.opt.iterations),
        "line_search_iterations": int(model.opt.ls_iterations),
        "gravity_m_s2": gravity.tolist(),
        "native_position_target": False,
        "independent_native_position_feedback": False,
    }
    fields_match = _motor_readback_matches(motor_readback, target)

    longest_streak = 0
    current_streak = 0
    first_acceptable: int | None = None
    maximum_anchor_residual = 0.0
    maximum_actuation_to_joint_error = 0.0
    maximum_applied_torque_error = 0.0
    maximum_impulse = 0.0
    impulse_violations = 0
    actuation_to_joint_mismatches = 0
    applied_torque_mismatches = 0
    nonfinite = 0
    terminal_position = 0.0
    terminal_velocity = 0.0
    terminal_actuator_force = 0.0
    terminal_generalized_torque = 0.0
    terminal_external_torque = 0.0
    terminal_velocity_response = math.nan
    terminal_force_response: float | None = None

    for step in range(OUTER_STEPS):
        data.ctrl[actuator_id] = target
        data.qfrc_applied.fill(0.0)
        data.qfrc_applied[dof_address] = torque
        mujoco.mj_step(model, data)

        observation.time = data.time
        observation.qpos[:] = data.qpos
        observation.qvel[:] = data.qvel
        observation.act[:] = data.act
        observation.qacc_warmstart[:] = data.qacc_warmstart
        observation.ctrl[:] = data.ctrl
        observation.qfrc_applied.fill(0.0)
        observation.qfrc_applied[dof_address] = torque
        observation.xfrc_applied.fill(0.0)
        mujoco.mj_forward(model, observation)

        velocity = float(observation.qvel[dof_address])
        actuator_force = float(observation.actuator_force[actuator_id])
        generalized_torque = float(observation.qfrc_actuator[dof_address])
        applied_torque = float(observation.qfrc_applied[dof_address])
        position = float(observation.qpos[qpos_address])
        anchor_residual = float(
            np.linalg.norm(
                np.asarray(observation.xanchor[joint_id], dtype=float)
                - DECLARED_ANCHOR_WORLD_M
            )
        )
        actuation_to_joint_error = abs(generalized_torque - actuator_force)
        applied_torque_error = abs(applied_torque - torque)
        derived_impulse = abs(generalized_torque) * MUJOCO_DT_S
        finite = all(
            math.isfinite(value)
            for value in (
                velocity,
                actuator_force,
                generalized_torque,
                applied_torque,
                position,
                anchor_residual,
                actuation_to_joint_error,
                applied_torque_error,
                derived_impulse,
            )
        )
        if finite:
            maximum_anchor_residual = max(maximum_anchor_residual, anchor_residual)
            maximum_actuation_to_joint_error = max(
                maximum_actuation_to_joint_error, actuation_to_joint_error
            )
            maximum_applied_torque_error = max(
                maximum_applied_torque_error, applied_torque_error
            )
            maximum_impulse = max(maximum_impulse, derived_impulse)
        else:
            nonfinite += 1
        if derived_impulse > MAXIMUM_STEP_IMPULSE_NMS + NUMERIC_IMPULSE_TOLERANCE_NMS:
            impulse_violations += 1
        if actuation_to_joint_error > MAXIMUM_ACTUATION_TO_JOINT_FORCE_ERROR_NM:
            actuation_to_joint_mismatches += 1
        if applied_torque_error > MAXIMUM_APPLIED_TORQUE_READBACK_ERROR_NM:
            applied_torque_mismatches += 1
        velocity_response = (
            velocity / predicted_velocity if predicted_velocity != 0.0 else math.nan
        )
        force_response = (
            abs(generalized_torque) / abs(torque) if torque != 0.0 else None
        )
        signs_match = velocity != 0.0 and velocity * predicted_velocity > 0.0
        force_opposes = torque == 0.0 or generalized_torque * torque < 0.0
        acceptable = (
            step >= FIRST_ACCEPTABLE_STEP
            and finite
            and fields_match
            and RESPONSE_MINIMUM <= velocity_response <= RESPONSE_MAXIMUM
            and (
                force_response is None
                or RESPONSE_MINIMUM <= force_response <= RESPONSE_MAXIMUM
            )
            and signs_match
            and force_opposes
            and anchor_residual <= MAXIMUM_ANCHOR_WORLD_POSITION_RESIDUAL_M
            and actuation_to_joint_error <= MAXIMUM_ACTUATION_TO_JOINT_FORCE_ERROR_NM
            and applied_torque_error <= MAXIMUM_APPLIED_TORQUE_READBACK_ERROR_NM
            and derived_impulse
            <= MAXIMUM_STEP_IMPULSE_NMS + NUMERIC_IMPULSE_TOLERANCE_NMS
        )
        if acceptable:
            if first_acceptable is None:
                first_acceptable = step
            current_streak += 1
            longest_streak = max(longest_streak, current_streak)
        else:
            current_streak = 0
        terminal_position = position
        terminal_velocity = velocity
        terminal_actuator_force = actuator_force
        terminal_generalized_torque = generalized_torque
        terminal_external_torque = applied_torque
        terminal_velocity_response = velocity_response
        terminal_force_response = force_response

    target_and_response_signs_match = (
        terminal_velocity != 0.0 and terminal_velocity * predicted_velocity > 0.0
    )
    loaded_force_opposes = (
        torque == 0.0 or terminal_generalized_torque * torque < 0.0
    )
    passed = (
        fields_match
        and nonfinite == 0
        and impulse_violations == 0
        and actuation_to_joint_mismatches == 0
        and applied_torque_mismatches == 0
        and longest_streak >= REQUIRED_STREAK
        and RESPONSE_MINIMUM <= terminal_velocity_response <= RESPONSE_MAXIMUM
        and (
            terminal_force_response is None
            or RESPONSE_MINIMUM <= terminal_force_response <= RESPONSE_MAXIMUM
        )
        and target_and_response_signs_match
        and loaded_force_opposes
        and maximum_anchor_residual <= MAXIMUM_ANCHOR_WORLD_POSITION_RESIDUAL_M
        and maximum_actuation_to_joint_error
        <= MAXIMUM_ACTUATION_TO_JOINT_FORCE_ERROR_NM
        and maximum_applied_torque_error <= MAXIMUM_APPLIED_TORQUE_READBACK_ERROR_NM
    )
    return {
        **declared,
        "world_build_count": 1,
        "primary_data_buffer_count": 1,
        "read_only_observation_data_buffer_count": 1,
        "observation_buffer_modified_primary_trajectory": False,
        "predicted_terminal_velocity_rad_s": predicted_velocity,
        "terminal_joint_position_rad": terminal_position,
        "terminal_joint_velocity_rad_s": terminal_velocity,
        "terminal_actuator_force_nm": terminal_actuator_force,
        "terminal_generalized_actuator_torque_nm": terminal_generalized_torque,
        "terminal_external_applied_torque_nm": terminal_external_torque,
        "terminal_normalized_velocity_response": terminal_velocity_response,
        "terminal_normalized_force_response": terminal_force_response,
        "maximum_joint_anchor_world_position_residual_m": maximum_anchor_residual,
        "maximum_actuation_space_to_joint_space_force_error_nm": (
            maximum_actuation_to_joint_error
        ),
        "maximum_applied_torque_readback_error_nm": maximum_applied_torque_error,
        "maximum_derived_step_impulse_nms": maximum_impulse,
        "steps_executed": OUTER_STEPS,
        "first_acceptable_step": first_acceptable,
        "longest_acceptable_streak": longest_streak,
        "motor_profile_fields_match": fields_match,
        "motor_readback": motor_readback,
        "all_values_finite": nonfinite == 0,
        "target_and_response_signs_match": target_and_response_signs_match,
        "loaded_force_opposes_external_torque": loaded_force_opposes,
        "derived_step_impulse_limit_violation_count": impulse_violations,
        "actuation_space_to_joint_space_force_mismatch_count": (
            actuation_to_joint_mismatches
        ),
        "applied_torque_readback_mismatch_count": applied_torque_mismatches,
        "nonfinite_observation_count": nonfinite,
        "passed": passed,
    }


def run_velocity_only_host_characterization(source_commit: str) -> dict[str, Any]:
    _require(
        len(source_commit) == 40
        and all(character in "0123456789abcdef" for character in source_commit),
        "C6_MJC_HC_VH1_SOURCE_COMMIT_INVALID",
        source_commit,
    )
    preflight = run_velocity_only_host_preflight()
    declaration = _preregistration()
    cells: list[dict[str, Any]] = []
    world_attempt_count = 0
    for declared in _declared_cells(declaration):
        world_attempt_count += 1
        model: mujoco.MjModel | None = None
        try:
            model = _model()
            cells.append(_run_cell(declared, model))
        except Exception as error:  # Retain a complete failed cell and continue the grid.
            cells.append(
                {
                    **declared,
                    "world_build_count": 1 if model is not None else 0,
                    "primary_data_buffer_count": 0,
                    "read_only_observation_data_buffer_count": 0,
                    "observation_buffer_modified_primary_trajectory": False,
                    "predicted_terminal_velocity_rad_s": (
                        float(declared["target_velocity_rad_s"])
                        + float(declared["external_torque_nm"]) / VELOCITY_GAIN
                    ),
                    "terminal_joint_position_rad": 0.0,
                    "terminal_joint_velocity_rad_s": 0.0,
                    "terminal_actuator_force_nm": 0.0,
                    "terminal_generalized_actuator_torque_nm": 0.0,
                    "terminal_external_applied_torque_nm": 0.0,
                    "terminal_normalized_velocity_response": 0.0,
                    "terminal_normalized_force_response": (
                        0.0 if declared["kind"] == "loaded" else None
                    ),
                    "maximum_joint_anchor_world_position_residual_m": 0.0,
                    "maximum_actuation_space_to_joint_space_force_error_nm": 0.0,
                    "maximum_applied_torque_readback_error_nm": 0.0,
                    "maximum_derived_step_impulse_nms": 0.0,
                    "steps_executed": 0,
                    "first_acceptable_step": None,
                    "longest_acceptable_streak": 0,
                    "motor_profile_fields_match": False,
                    "motor_readback": None,
                    "all_values_finite": False,
                    "target_and_response_signs_match": False,
                    "loaded_force_opposes_external_torque": False,
                    "derived_step_impulse_limit_violation_count": 0,
                    "actuation_space_to_joint_space_force_mismatch_count": 0,
                    "applied_torque_readback_mismatch_count": 0,
                    "nonfinite_observation_count": 0,
                    "runtime_error": f"{type(error).__name__}:{error}",
                    "passed": False,
                }
            )
    report: dict[str, Any] = {
        "schema_version": REPORT_SCHEMA,
        "ok": False,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "source": {
            "commit": source_commit,
            "clean": True,
            "matches_origin_main": True,
            "matches_live_github_main": True,
        },
        "preregistration": {
            "path": "sdk/mujoco_c6_velocity_only_host_characterization_vh1_preregistration.json",
            "raw_sha256": EXPECTED_PREREGISTRATION_SHA256,
        },
        "preflight": preflight,
        "host": {
            **preflight["host_identity"],
            "timestep_s": MUJOCO_DT_S,
            "integrator": "implicitfast",
            "solver": "Newton",
            "solver_iterations": SOLVER_ITERATIONS,
            "line_search_iterations": LINE_SEARCH_ITERATIONS,
        },
        "motor_profile": {
            "profile_id": PROFILE_ID,
            "native_actuator": "velocity",
            "transmission_type": "mjTRN_JOINT",
            "transmission_gear": DECLARED_ACTUATOR_GEAR.tolist(),
            "velocity_gain_nm_s_per_rad": VELOCITY_GAIN,
            "force_range_nm": [-MAXIMUM_FORCE_NM, MAXIMUM_FORCE_NM],
            "maximum_declared_load_fraction_of_force_limit": 0.375,
            "native_position_target": False,
            "independent_native_position_feedback": False,
            "dynamic_force_saturation_response_characterized": False,
        },
        "observation_contract": {
            "method": "post_step_integration_state_copied_to_read_only_mjdata_then_mj_forward",
            "read_only_observation_buffer_modifies_primary_trajectory": False,
            "world_count_unit": "MjModel instance",
            "data_buffers_per_successful_world": 2,
        },
        "cells": cells,
        "mirrored_pairs": _pair_asymmetries(cells),
        "integrity": {
            "world_attempt_count": world_attempt_count,
            "world_build_count": sum(int(cell["world_build_count"]) for cell in cells),
            "world_reset_count": 0,
            "model_or_field_mismatch_count": sum(
                1 for cell in cells if not cell["motor_profile_fields_match"]
            ),
            "nonfinite_observation_count": sum(
                int(cell["nonfinite_observation_count"]) for cell in cells
            ),
            "derived_step_impulse_limit_violation_count": sum(
                int(cell["derived_step_impulse_limit_violation_count"])
                for cell in cells
            ),
            "actuation_space_to_joint_space_force_mismatch_count": sum(
                int(cell["actuation_space_to_joint_space_force_mismatch_count"])
                for cell in cells
            ),
            "applied_torque_readback_mismatch_count": sum(
                int(cell["applied_torque_readback_mismatch_count"])
                for cell in cells
            ),
        },
        "claim_boundary": json.loads(json.dumps(declaration["claim_boundary"])),
        "controller_policy_authority": False,
        "selected_policy_physical_authority": False,
        "physical_acceptance_authority": False,
    }
    report["claim_boundary"][
        "exact_finite_mujoco_velocity_only_host_characterization_if_passed"
    ] = False
    failures = evaluate_velocity_only_host_report(report)
    report["failures"] = failures
    report["passed_cells"] = sum(1 for cell in cells if cell["passed"])
    report["failed_cells"] = len(cells) - int(report["passed_cells"])
    report["ok"] = not failures
    report["claim_boundary"][
        "exact_finite_mujoco_velocity_only_host_characterization_if_passed"
    ] = report["ok"]
    return report


def _retain(report: dict[str, Any], output: Path) -> None:
    _require(output.name == "report.json", "C6_MJC_HC_VH1_REPORT_NAME_INVALID")
    _require(not output.exists(), "C6_MJC_HC_VH1_REPORT_ALREADY_EXISTS", str(output))
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name("report.json.tmp")
    serialized = json.dumps(report, indent=2, allow_nan=False) + "\n"
    temporary.write_text(serialized, encoding="utf-8", newline="\n")
    os.replace(temporary, output)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preflight-only", action="store_true")
    mode.add_argument("--run-physical", action="store_true")
    parser.add_argument("--source-commit")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        if args.preflight_only:
            _require(
                args.source_commit is None and args.output is None,
                "C6_MJC_HC_VH1_PREFLIGHT_ARGUMENTS_INVALID",
            )
            print(json.dumps(run_velocity_only_host_preflight(), indent=2, allow_nan=False))
            return 0
        _require(
            isinstance(args.source_commit, str) and args.output is not None,
            "C6_MJC_HC_VH1_PHYSICAL_ARGUMENTS_INVALID",
        )
        report = run_velocity_only_host_characterization(args.source_commit)
        _retain(report, args.output.resolve())
        print(json.dumps(report, indent=2, allow_nan=False))
        return 0 if report["ok"] else 1
    except (ConformanceFailure, OSError, ValueError, json.JSONDecodeError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
