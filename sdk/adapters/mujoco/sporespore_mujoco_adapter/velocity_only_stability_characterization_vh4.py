"""Stability-aware MuJoCo velocity-only host characterization for VH4.

The preflight imports MuJoCo and verifies the pinned runtime, declaration,
Python binding surface, analytic stability mechanism, complete production
evaluator, JSON round trip, and negative controls.  It never calls an
``MjModel`` constructor.  The physical path is reachable only through the
repository supervisor.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any

import mujoco
import numpy as np

from .conformance import ConformanceFailure, _require


CAMPAIGN_ID = "C6-MUJOCO-VELOCITY-ONLY-STABILITY-HOST-CHARACTERIZATION-VH4"
GATE_ID = "C6-MJC-HC-VH4"
REPORT_SCHEMA = (
    "sporespore_mujoco_c6_velocity_only_stability_host_"
    "characterization_vh4_report_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_mujoco_c6_velocity_only_stability_host_"
    "characterization_vh4_preflight_v1"
)
PROFILE_ID = "mujoco_velocity_servo_force_limited_five_substep_v3"

SDK_ROOT = Path(__file__).resolve().parents[3]
PREREGISTRATION_PATH = SDK_ROOT / (
    "mujoco_c6_velocity_only_stability_host_characterization_"
    "vh4_preregistration.json"
)
EXPECTED_PREREGISTRATION_SHA256 = (
    "sha256:291c004730a689db9d244fda0ec4e51a171f3abf267fcd01fdd016f8171904b7"
)

EXPECTED_MJ_FULLM_SIGNATURE = (
    "mj_fullM(m: mujoco._structs.MjModel, d: mujoco._structs.MjData, "
    "dst: typing.Annotated[numpy.typing.NDArray[numpy.float64], "
    '"[m, n]", "flags.writeable", "flags.c_contiguous"]) -> None'
)

CONTROLLER_DT_S = 1.0 / 120.0
INTERNAL_DT_S = 1.0 / 600.0
INTERNAL_STEPS_PER_OUTER = 5
OUTER_STEPS = 360
TRACE_RECORDS_PER_CELL = OUTER_STEPS * INTERNAL_STEPS_PER_OUTER
FIRST_ACCEPTABLE_OUTER_STEP = 120
REQUIRED_OUTER_STREAK = 120
VELOCITY_GAIN = 10.0
MAXIMUM_FORCE_NM = 6.0
MAXIMUM_INTERNAL_IMPULSE_NMS = MAXIMUM_FORCE_NM * INTERNAL_DT_S
MAXIMUM_OUTER_CUMULATIVE_ABS_IMPULSE_NMS = (
    MAXIMUM_INTERNAL_IMPULSE_NMS * INTERNAL_STEPS_PER_OUTER
)
RESPONSE_MINIMUM = 0.98
RESPONSE_MAXIMUM = 1.02
MAXIMUM_PAIR_ASYMMETRY = 0.005
NUMERIC_TOLERANCE = 1.0e-12
SATURATION_TOLERANCE_NM = 1.0e-10
UNSATURATED_MARGIN_NM = 1.0e-9
ANCHOR_TOLERANCE_M = 1.0e-12
FORCE_MAPPING_TOLERANCE_NM = 1.0e-12
IMPULSE_TOLERANCE_NMS = 1.0e-12
GENERALIZED_INERTIA_TOLERANCE_KG_M2 = 1.0e-12
MOMENTUM_IMPULSE_TOLERANCE_NMS = 1.0e-12
TEMPORAL_FORCE_WITNESS_TOLERANCE_NM = 1.0e-12
JOINT_ARMATURE = 0.01
CHILD_HALF_EXTENTS_M = np.asarray([0.1, 0.1, 0.1], dtype=np.float64)
CHILD_MASS_KG = 1.0
ANALYTIC_CHILD_INERTIA = float(
    CHILD_MASS_KG
    * ((2.0 * CHILD_HALF_EXTENTS_M[1]) ** 2 + (2.0 * CHILD_HALF_EXTENTS_M[2]) ** 2)
    / 12.0
)
ANALYTIC_EFFECTIVE_INERTIA = float(JOINT_ARMATURE + ANALYTIC_CHILD_INERTIA)
SATURATION_BAND_HALF_WIDTH_RAD_S = MAXIMUM_FORCE_NM / VELOCITY_GAIN
EXACT_FIXTURE_SATURATED_BAND_CROSSING_RATIO = float(
    VELOCITY_GAIN * INTERNAL_DT_S / ANALYTIC_EFFECTIVE_INERTIA
)
ARMATURE_ONLY_SATURATED_BAND_CROSSING_RATIO = float(
    VELOCITY_GAIN * INTERNAL_DT_S / JOINT_ARMATURE
)
EXACT_FIXTURE_UNSATURATED_IMPLICITFAST_MULTIPLIER = float(
    1.0 / (1.0 + EXACT_FIXTURE_SATURATED_BAND_CROSSING_RATIO)
)
ARMATURE_ONLY_UNSATURATED_IMPLICITFAST_MULTIPLIER = float(
    1.0 / (1.0 + ARMATURE_ONLY_SATURATED_BAND_CROSSING_RATIO)
)
STRICT_SATURATED_BAND_SKIP_BOUND = 2.0
DECLARED_AXIS = np.asarray([1.0, 0.0, 0.0], dtype=np.float64)
DECLARED_GEAR = np.asarray([1.0, 0.0, 0.0, 0.0, 0.0, 0.0], dtype=np.float64)
DECLARED_ANCHOR = np.asarray([0.0, 0.0, 0.0], dtype=np.float64)

# Temporally explicit internal trace row:
# [index, outer, substep, post_time, pre_qpos, pre_qvel,
#  step_actuator_force, step_generalized_force, step_applied_torque,
#  pre_inertia, post_qpos, post_qvel, momentum_inferred_motor_impulse,
#  post_state_recomputed_actuator_force, post_state_recomputed_generalized_force,
#  post_inertia, post_anchor_residual]
TRACE_WIDTH = 17


def _raw_sha256(path: Path) -> str:
    return f"sha256:{hashlib.sha256(path.read_bytes()).hexdigest()}"


def _numeric_sequence_matches(
    observed: Any, expected: Any, tolerance: float = NUMERIC_TOLERANCE
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


def _preregistration() -> dict[str, Any]:
    _require(
        PREREGISTRATION_PATH.is_file(),
        "C6_MJC_HC_VH4_PREREGISTRATION_MISSING",
        str(PREREGISTRATION_PATH),
    )
    observed_hash = _raw_sha256(PREREGISTRATION_PATH)
    _require(
        observed_hash == EXPECTED_PREREGISTRATION_SHA256,
        "C6_MJC_HC_VH4_PREREGISTRATION_HASH_MISMATCH",
        observed_hash,
    )
    declaration = json.loads(PREREGISTRATION_PATH.read_text(encoding="utf-8"))
    host = declaration.get("host_identity", {})
    fixture = declaration.get("fixture", {})
    mechanism = declaration.get("stability_mechanism", {})
    profile = declaration.get("motor_profile", {})
    grid = declaration.get("physical_grid", {})
    _require(
        declaration.get("campaign_id") == CAMPAIGN_ID
        and declaration.get("gate_id") == GATE_ID
        and declaration.get("status")
        in {
            "prospective_draft_before_executable_freeze",
            "frozen_before_first_c6_mjc_hc_vh4_physics_world",
        }
        and declaration.get("implementation_parent_commit")
        == "1501e7e278b660810623db9b865082388cc6c27f",
        "C6_MJC_HC_VH4_PREREGISTRATION_IDENTITY_INVALID",
    )
    _require(
        host.get("engine_version") == "3.11.0"
        and host.get("python_version") == "3.11.9"
        and host.get("numpy_version") == "2.4.6"
        and host.get("portable_controller_timestep_s") == CONTROLLER_DT_S
        and host.get("internal_physics_timestep_s") == INTERNAL_DT_S
        and host.get("internal_physics_steps_per_controller_step")
        == INTERNAL_STEPS_PER_OUTER
        and host.get("integrator") == "implicitfast"
        and host.get("solver") == "Newton"
        and host.get("solver_iterations") == 20
        and host.get("line_search_iterations") == 7,
        "C6_MJC_HC_VH4_HOST_DECLARATION_INVALID",
    )
    _require(
        fixture.get("joint_armature") == JOINT_ARMATURE
        and fixture.get("joint_passive_damping") == 0.0
        and _numeric_sequence_matches(
            fixture.get("child_half_extents_m"), CHILD_HALF_EXTENTS_M
        )
        and fixture.get("child_mass_kg") == CHILD_MASS_KG
        and math.isclose(
            float(fixture.get("analytic_child_inertia_about_hinge_kg_m2")),
            ANALYTIC_CHILD_INERTIA,
            rel_tol=0.0,
            abs_tol=1.0e-15,
        )
        and math.isclose(
            float(fixture.get("analytic_effective_joint_inertia_kg_m2")),
            ANALYTIC_EFFECTIVE_INERTIA,
            rel_tol=0.0,
            abs_tol=1.0e-15,
        )
        and fixture.get("contacts_enabled") is False,
        "C6_MJC_HC_VH4_FIXTURE_DECLARATION_INVALID",
    )
    _require(
        profile.get("profile_id") == PROFILE_ID
        and profile.get("native_actuator") == "velocity"
        and profile.get("transmission_type") == "mjTRN_JOINT"
        and _numeric_sequence_matches(profile.get("transmission_gear"), DECLARED_GEAR)
        and profile.get("velocity_gain_nm_s_per_rad") == VELOCITY_GAIN
        and profile.get("minimum_force_nm") == -MAXIMUM_FORCE_NM
        and profile.get("maximum_force_nm") == MAXIMUM_FORCE_NM
        and profile.get("native_position_target") is False
        and profile.get("independent_native_position_feedback") is False
        and profile.get("maximum_internal_step_force_time_budget_nms")
        == MAXIMUM_INTERNAL_IMPULSE_NMS
        and profile.get(
            "maximum_controller_step_cumulative_absolute_force_time_budget_nms"
        )
        == MAXIMUM_OUTER_CUMULATIVE_ABS_IMPULSE_NMS,
        "C6_MJC_HC_VH4_MOTOR_PROFILE_DECLARATION_INVALID",
    )
    _require(
        math.isclose(
            float(
                mechanism.get(
                    "vh4_exact_fixture_saturated_band_crossing_ratio"
                )
            ),
            EXACT_FIXTURE_SATURATED_BAND_CROSSING_RATIO,
            rel_tol=0.0,
            abs_tol=1.0e-15,
        )
        and math.isclose(
            float(
                mechanism.get(
                    "vh4_armature_only_upper_saturated_band_crossing_ratio"
                )
            ),
            ARMATURE_ONLY_SATURATED_BAND_CROSSING_RATIO,
            rel_tol=0.0,
            abs_tol=1.0e-15,
        )
        and math.isclose(
            float(
                mechanism.get(
                    "vh4_exact_fixture_unsaturated_implicitfast_error_multiplier"
                )
            ),
            EXACT_FIXTURE_UNSATURATED_IMPLICITFAST_MULTIPLIER,
            rel_tol=0.0,
            abs_tol=1.0e-15,
        )
        and math.isclose(
            float(
                mechanism.get(
                    "vh4_armature_only_unsaturated_implicitfast_error_multiplier"
                )
            ),
            ARMATURE_ONLY_UNSATURATED_IMPLICITFAST_MULTIPLIER,
            rel_tol=0.0,
            abs_tol=1.0e-15,
        )
        and mechanism.get(
            "strict_single_saturated_step_no_full_linear_band_skip_upper_bound"
        )
        == STRICT_SATURATED_BAND_SKIP_BOUND
        and EXACT_FIXTURE_SATURATED_BAND_CROSSING_RATIO
        < STRICT_SATURATED_BAND_SKIP_BOUND
        and ARMATURE_ONLY_SATURATED_BAND_CROSSING_RATIO
        < STRICT_SATURATED_BAND_SKIP_BOUND,
        "C6_MJC_HC_VH4_STABILITY_DECLARATION_INVALID",
    )
    _require(
        len(grid.get("base_target_load_cells", [])) == 12
        and len(grid.get("initial_condition_profiles", [])) == 2
        and grid.get("worlds") == 24
        and grid.get("replacement_worlds") == 0
        and grid.get("outer_controller_steps_per_cell") == OUTER_STEPS
        and grid.get("internal_physics_steps_per_outer_step")
        == INTERNAL_STEPS_PER_OUTER
        and grid.get("internal_trace_records_per_cell") == TRACE_RECORDS_PER_CELL
        and grid.get("aggregate_internal_trace_records")
        == TRACE_RECORDS_PER_CELL * 24
        and grid.get("first_acceptable_outer_step")
        == FIRST_ACCEPTABLE_OUTER_STEP
        and grid.get("required_consecutive_acceptable_outer_steps")
        == REQUIRED_OUTER_STREAK
        and grid.get("early_stop_forbidden") is True,
        "C6_MJC_HC_VH4_GRID_DECLARATION_INVALID",
    )
    claims = declaration.get("claim_boundary", {})
    _require(
        claims.get("mujoco_selected_policy_locomotion") is False
        and claims.get("mujoco_walking") is False
        and claims.get("cross_engine_equivalence") is False
        and claims.get("physical_acceptance_authority") is False,
        "C6_MJC_HC_VH4_CLAIM_BOUNDARY_INVALID",
    )
    return declaration


def _host_identity_receipt(declaration: dict[str, Any]) -> dict[str, Any]:
    host = declaration["host_identity"]
    source = declaration["host_source_semantics"]
    site_packages = Path(mujoco.__file__).resolve().parent.parent
    requirements_lock = SDK_ROOT / "adapters" / "mujoco" / "requirements-lock.txt"
    base_executable = Path(sys._base_executable).resolve()
    mj_fullm_signature = str(mujoco.mj_fullM.__doc__ or "").splitlines()[0]
    binding_surface = {
        "mjdata_has_M": hasattr(mujoco.MjData, "M"),
        "mjdata_has_qM": hasattr(mujoco.MjData, "qM"),
        "mj_fullM_signature": mj_fullm_signature,
        "mj_step1_callable": callable(getattr(mujoco, "mj_step1", None)),
        "mj_step2_callable": callable(getattr(mujoco, "mj_step2", None)),
    }
    _require(
        binding_surface["mjdata_has_M"] is True
        and binding_surface["mjdata_has_qM"] is False
        and binding_surface["mj_fullM_signature"] == EXPECTED_MJ_FULLM_SIGNATURE
        and binding_surface["mj_step1_callable"] is True
        and binding_surface["mj_step2_callable"] is True
        and source.get("python_generalized_inertia_field") == "M"
        and source.get("python_forbidden_generalized_inertia_field") == "qM"
        and source.get("python_mj_fullM_signature") == EXPECTED_MJ_FULLM_SIGNATURE,
        "C6_MJC_HC_VH4_BINDING_SURFACE_MISMATCH",
        json.dumps(binding_surface, sort_keys=True),
    )
    _require(
        mujoco.__version__ == host["engine_version"]
        and np.__version__ == host["numpy_version"]
        and sys.version.split()[0] == host["python_version"],
        "C6_MJC_HC_VH4_HOST_VERSION_MISMATCH",
    )
    _require(
        requirements_lock.is_file()
        and _raw_sha256(requirements_lock)
        == "sha256:"
        + source["requirements_lock_windows_checkout_raw_sha256"],
        "C6_MJC_HC_VH4_REQUIREMENTS_LOCK_MISMATCH",
    )
    _require(
        base_executable.as_posix().lower()
        == str(source["python_base_executable"]).lower()
        and _raw_sha256(base_executable)
        == "sha256:" + source["python_base_executable_raw_sha256"],
        "C6_MJC_HC_VH4_PYTHON_EXECUTABLE_MISMATCH",
    )
    files: list[dict[str, str]] = []
    for expected in source["installed_wheel_files"]:
        relative = Path(str(expected["relative_to_site_packages"]))
        path = (site_packages / relative).resolve()
        _require(
            path.is_relative_to(site_packages)
            and path.is_file()
            and _raw_sha256(path) == "sha256:" + expected["raw_sha256"],
            "C6_MJC_HC_VH4_WHEEL_FILE_MISMATCH",
            relative.as_posix(),
        )
        files.append(
            {
                "relative_to_site_packages": relative.as_posix(),
                "raw_sha256": "sha256:" + expected["raw_sha256"],
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
        "verified_wheel_file_count": len(files),
        "verified_wheel_files": files,
        "binding_surface": binding_surface,
        "binding_surface_canary_count": 5,
        "world_build_count": 0,
        "physics_state_modified": False,
    }


def _expanded_cells(declaration: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for base in declaration["physical_grid"]["base_target_load_cells"]:
        target = float(base["target_velocity_rad_s"])
        torque = float(base["external_torque_nm"])
        predicted = target + torque / VELOCITY_GAIN
        _require(predicted != 0.0, "C6_MJC_HC_VH4_ZERO_PREDICTED_VELOCITY")
        for profile in ("zero", "adverse"):
            initial = 0.0 if profile == "zero" else -3.0 * math.copysign(1.0, predicted)
            result.append(
                {
                    "cell_id": f"{base['base_id']}_i{profile}",
                    "base_id": base["base_id"],
                    "kind": base["kind"],
                    "initial_condition_profile": profile,
                    "initial_joint_velocity_rad_s": initial,
                    "target_velocity_rad_s": target,
                    "external_torque_nm": torque,
                    "predicted_steady_velocity_rad_s": predicted,
                }
            )
    _require(
        len(result) == len({cell["cell_id"] for cell in result}) == 24,
        "C6_MJC_HC_VH4_EXPANDED_CELL_IDENTITY_INVALID",
    )
    return result


def _relative_asymmetry(left: float, right: float) -> float:
    return abs(abs(left) - abs(right)) / max(abs(left), abs(right), 1.0e-12)


def _pair_receipts(cells: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_id = {str(cell.get("cell_id")): cell for cell in cells}
    base_pairs = (
        ("unloaded_075", "unloaded_vn075", "unloaded_vp075"),
        ("unloaded_225", "unloaded_vn225", "unloaded_vp225"),
        ("loaded_150_075_same", "loaded_vn150_tn075", "loaded_vp150_tp075"),
        ("loaded_150_075_cross", "loaded_vn150_tp075", "loaded_vp150_tn075"),
        ("loaded_150_225_same", "loaded_vn150_tn225", "loaded_vp150_tp225"),
        ("loaded_150_225_cross", "loaded_vn150_tp225", "loaded_vp150_tn225"),
    )
    receipts: list[dict[str, Any]] = []
    for profile in ("zero", "adverse"):
        for pair_id, left_base, right_base in base_pairs:
            left_id = f"{left_base}_i{profile}"
            right_id = f"{right_base}_i{profile}"
            left = by_id.get(left_id)
            right = by_id.get(right_id)
            if left is None or right is None:
                receipts.append(
                    {
                        "pair_id": f"{pair_id}_{profile}",
                        "left_cell_id": left_id,
                        "right_cell_id": right_id,
                        "velocity_response_relative_asymmetry": None,
                        "force_response_relative_asymmetry": None,
                        "passed": False,
                    }
                )
                continue
            velocity = _relative_asymmetry(
                float(left["terminal_normalized_velocity_response"]),
                float(right["terminal_normalized_velocity_response"]),
            )
            force: float | None = None
            if left["kind"] == "loaded":
                force = _relative_asymmetry(
                    float(left["terminal_normalized_force_response"]),
                    float(right["terminal_normalized_force_response"]),
                )
            receipts.append(
                {
                    "pair_id": f"{pair_id}_{profile}",
                    "left_cell_id": left_id,
                    "right_cell_id": right_id,
                    "velocity_response_relative_asymmetry": velocity,
                    "force_response_relative_asymmetry": force,
                    "passed": velocity <= MAXIMUM_PAIR_ASYMMETRY
                    and (force is None or force <= MAXIMUM_PAIR_ASYMMETRY),
                }
            )
    return receipts


def _motor_readback_matches(readback: Any, declared: dict[str, Any]) -> bool:
    if not isinstance(readback, dict):
        return False
    maximum_force_nm = float(declared.get("maximum_force_nm", MAXIMUM_FORCE_NM))
    profile_id = str(declared.get("profile_id", PROFILE_ID))
    return bool(
        readback.get("profile_id") == profile_id
        and readback.get("native_actuator") == "velocity"
        and readback.get("transmission_type") == "mjTRN_JOINT"
        and readback.get("transmission_type_code") == 0
        and readback.get("transmission_target_joint_id_matches") is True
        and _numeric_sequence_matches(readback.get("transmission_gear"), DECLARED_GEAR)
        and readback.get("control_target_velocity_rad_s")
        == declared["target_velocity_rad_s"]
        and readback.get("velocity_gain_nm_s_per_rad") == VELOCITY_GAIN
        and readback.get("velocity_bias_gain_nm_s_per_rad") == -VELOCITY_GAIN
        and readback.get("force_limited") is True
        and _numeric_sequence_matches(
            readback.get("force_range_nm"), [-maximum_force_nm, maximum_force_nm]
        )
        and readback.get("joint_type") == "hinge"
        and readback.get("joint_limited") is False
        and _numeric_sequence_matches(readback.get("joint_axis"), DECLARED_AXIS)
        and readback.get("joint_armature") == JOINT_ARMATURE
        and readback.get("joint_passive_damping") == 0.0
        and _numeric_sequence_matches(
            readback.get("child_half_extents_m"), CHILD_HALF_EXTENTS_M
        )
        and readback.get("child_mass_kg") == CHILD_MASS_KG
        and readback.get("contacts_enabled") is False
        and readback.get("internal_timestep_s") == INTERNAL_DT_S
        and readback.get("controller_timestep_s") == CONTROLLER_DT_S
        and readback.get("internal_steps_per_controller_step")
        == INTERNAL_STEPS_PER_OUTER
        and readback.get("integrator") == "implicitfast"
        and readback.get("solver") == "Newton"
        and readback.get("solver_iterations") == 20
        and readback.get("line_search_iterations") == 7
        and readback.get("stepping_api") == "mj_step1_mj_step2"
        and readback.get("actuation_capture")
        == "after_mj_step2_before_post_state_mj_forward"
        and readback.get("initial_joint_velocity_rad_s")
        == declared["initial_joint_velocity_rad_s"]
        and readback.get("native_position_target") is False
        and readback.get("independent_native_position_feedback") is False
        and math.isclose(
            float(readback.get("analytic_effective_joint_inertia_kg_m2")),
            ANALYTIC_EFFECTIVE_INERTIA,
            rel_tol=0.0,
            abs_tol=1.0e-15,
        )
        and math.isclose(
            float(readback.get("generalized_inertia_readback_kg_m2")),
            ANALYTIC_EFFECTIVE_INERTIA,
            rel_tol=0.0,
            abs_tol=GENERALIZED_INERTIA_TOLERANCE_KG_M2,
        )
        and math.isclose(
            float(readback.get("saturated_band_crossing_ratio")),
            EXACT_FIXTURE_SATURATED_BAND_CROSSING_RATIO,
            rel_tol=0.0,
            abs_tol=1.0e-15,
        )
        and math.isclose(
            float(readback.get("unsaturated_implicitfast_error_multiplier")),
            EXACT_FIXTURE_UNSATURATED_IMPLICITFAST_MULTIPLIER,
            rel_tol=0.0,
            abs_tol=1.0e-15,
        )
    )


def _trace_failures(
    cell: dict[str, Any],
    maximum_force_nm: float = MAXIMUM_FORCE_NM,
) -> list[str]:
    """Reconstruct every trace gate at an explicitly trusted force limit.

    The default is deliberately VH4's frozen 6 N m profile.  Successors may
    reuse the temporal measurement machinery only by passing a force limit
    that their own declaration evaluator has already validated; an untrusted
    report field must never change VH4's historical gate.
    """

    cell_id = str(cell.get("cell_id", "unknown"))
    maximum_force_nm = float(maximum_force_nm)
    maximum_internal_impulse_nms = maximum_force_nm * INTERNAL_DT_S
    maximum_outer_cumulative_abs_impulse_nms = (
        maximum_internal_impulse_nms * INTERNAL_STEPS_PER_OUTER
    )
    trace = cell.get("internal_step_trace")
    if not isinstance(trace, list):
        return [f"C6_MJC_HC_VH4_TRACE_MISSING:{cell_id}"]
    if len(trace) != TRACE_RECORDS_PER_CELL:
        return [f"C6_MJC_HC_VH4_TRACE_CARDINALITY:{cell_id}"]
    torque = float(cell.get("external_torque_nm", math.nan))
    predicted = float(cell.get("predicted_steady_velocity_rad_s", math.nan))
    saturation_count = 0
    temporal_witness_count = 0
    maximum_internal_force_time_budget = 0.0
    maximum_outer_force_time_budget = 0.0
    current_outer_force_time_budget = 0.0
    maximum_effective_motor_impulse = 0.0
    maximum_force_error = 0.0
    maximum_post_force_error = 0.0
    maximum_applied_error = 0.0
    maximum_inertia_error = 0.0
    maximum_saturated_momentum_error = 0.0
    maximum_unsaturated_momentum_error = 0.0
    maximum_anchor = 0.0
    internal_force_time_budget_violations = 0
    outer_force_time_budget_violations = 0
    effective_motor_impulse_violations = 0
    force_mismatches = 0
    applied_mismatches = 0
    inertia_mismatches = 0
    saturated_momentum_mismatches = 0
    unsaturated_momentum_mismatches = 0
    continuity_mismatches = 0
    first_acceptable: int | None = None
    longest_streak = 0
    current_streak = 0
    previous_post_position: float | None = None
    previous_post_velocity: float | None = None

    for index, row in enumerate(trace):
        if not isinstance(row, list) or len(row) != TRACE_WIDTH:
            return [f"C6_MJC_HC_VH4_TRACE_SHAPE:{cell_id}:{index}"]
        if not all(isinstance(value, (int, float)) for value in row):
            return [f"C6_MJC_HC_VH4_TRACE_TYPE:{cell_id}:{index}"]
        values = [float(value) for value in row]
        if not all(math.isfinite(value) for value in values):
            return [f"C6_MJC_HC_VH4_TRACE_NONFINITE:{cell_id}:{index}"]

        expected_outer = index // INTERNAL_STEPS_PER_OUTER
        expected_substep = index % INTERNAL_STEPS_PER_OUTER
        expected_time = (index + 1) * INTERNAL_DT_S
        if (
            int(row[0]) != index
            or int(row[1]) != expected_outer
            or int(row[2]) != expected_substep
            or not math.isclose(values[3], expected_time, rel_tol=0.0, abs_tol=1e-12)
        ):
            return [f"C6_MJC_HC_VH4_TRACE_INDEX:{cell_id}:{index}"]

        pre_position = values[4]
        pre_velocity = values[5]
        step_actuator_force = values[6]
        step_generalized_force = values[7]
        applied_torque = values[8]
        pre_inertia = values[9]
        post_position = values[10]
        post_velocity = values[11]
        momentum_inferred_impulse = values[12]
        post_state_actuator_force = values[13]
        post_state_generalized_force = values[14]
        post_inertia = values[15]
        anchor = values[16]

        if index == 0:
            if not math.isclose(
                pre_velocity,
                float(cell.get("initial_joint_velocity_rad_s", math.nan)),
                rel_tol=0.0,
                abs_tol=1e-15,
            ):
                continuity_mismatches += 1
        elif (
            not math.isclose(
                pre_position,
                float(previous_post_position),
                rel_tol=0.0,
                abs_tol=1e-12,
            )
            or not math.isclose(
                pre_velocity,
                float(previous_post_velocity),
                rel_tol=0.0,
                abs_tol=1e-12,
            )
        ):
            continuity_mismatches += 1
        previous_post_position = post_position
        previous_post_velocity = post_velocity

        if pre_inertia <= 0.0 or post_inertia <= 0.0:
            return [f"C6_MJC_HC_VH4_TRACE_INERTIA_NONPOSITIVE:{cell_id}:{index}"]
        if anchor < 0.0:
            return [f"C6_MJC_HC_VH4_TRACE_ANCHOR_NEGATIVE:{cell_id}:{index}"]
        if abs(step_actuator_force) > maximum_force_nm + NUMERIC_TOLERANCE:
            return [f"C6_MJC_HC_VH4_TRACE_FORCE_LIMIT:{cell_id}:{index}"]

        if (
            abs(abs(step_actuator_force) - maximum_force_nm)
            <= SATURATION_TOLERANCE_NM
        ):
            saturation_count += 1
        if (
            abs(step_actuator_force - post_state_actuator_force)
            > TEMPORAL_FORCE_WITNESS_TOLERANCE_NM
        ):
            temporal_witness_count += 1

        signed_force_time_budget = step_generalized_force * INTERNAL_DT_S
        reconstructed_momentum_impulse = (
            pre_inertia * (post_velocity - pre_velocity)
            - applied_torque * INTERNAL_DT_S
        )
        reconstruction_error = abs(
            momentum_inferred_impulse - reconstructed_momentum_impulse
        )
        saturated = (
            abs(abs(step_actuator_force) - maximum_force_nm)
            <= SATURATION_TOLERANCE_NM
        )
        if saturated:
            momentum_error = max(
                reconstruction_error,
                abs(momentum_inferred_impulse - signed_force_time_budget),
            )
            maximum_saturated_momentum_error = max(
                maximum_saturated_momentum_error, momentum_error
            )
            if momentum_error > MOMENTUM_IMPULSE_TOLERANCE_NMS:
                saturated_momentum_mismatches += 1
        else:
            post_state_force_time = post_state_generalized_force * INTERNAL_DT_S
            momentum_error = max(
                reconstruction_error,
                abs(momentum_inferred_impulse - post_state_force_time),
            )
            maximum_unsaturated_momentum_error = max(
                maximum_unsaturated_momentum_error, momentum_error
            )
            if momentum_error > MOMENTUM_IMPULSE_TOLERANCE_NMS:
                unsaturated_momentum_mismatches += 1
        force_time_budget = abs(signed_force_time_budget)
        effective_motor_impulse = abs(momentum_inferred_impulse)
        current_outer_force_time_budget += force_time_budget
        maximum_internal_force_time_budget = max(
            maximum_internal_force_time_budget, force_time_budget
        )
        maximum_effective_motor_impulse = max(
            maximum_effective_motor_impulse, effective_motor_impulse
        )
        maximum_force_error = max(
            maximum_force_error,
            abs(step_actuator_force - step_generalized_force),
        )
        maximum_post_force_error = max(
            maximum_post_force_error,
            abs(post_state_actuator_force - post_state_generalized_force),
        )
        maximum_applied_error = max(
            maximum_applied_error, abs(applied_torque - torque)
        )
        maximum_inertia_error = max(
            maximum_inertia_error,
            abs(pre_inertia - ANALYTIC_EFFECTIVE_INERTIA),
            abs(post_inertia - ANALYTIC_EFFECTIVE_INERTIA),
        )
        maximum_anchor = max(maximum_anchor, anchor)
        if force_time_budget > maximum_internal_impulse_nms + IMPULSE_TOLERANCE_NMS:
            internal_force_time_budget_violations += 1
        if (
            effective_motor_impulse
            > maximum_internal_impulse_nms + IMPULSE_TOLERANCE_NMS
        ):
            effective_motor_impulse_violations += 1
        if abs(step_actuator_force - step_generalized_force) > FORCE_MAPPING_TOLERANCE_NM:
            force_mismatches += 1
        if abs(applied_torque - torque) > FORCE_MAPPING_TOLERANCE_NM:
            applied_mismatches += 1
        if (
            abs(pre_inertia - ANALYTIC_EFFECTIVE_INERTIA)
            > GENERALIZED_INERTIA_TOLERANCE_KG_M2
            or abs(post_inertia - ANALYTIC_EFFECTIVE_INERTIA)
            > GENERALIZED_INERTIA_TOLERANCE_KG_M2
        ):
            inertia_mismatches += 1
        if expected_substep == INTERNAL_STEPS_PER_OUTER - 1:
            maximum_outer_force_time_budget = max(
                maximum_outer_force_time_budget,
                current_outer_force_time_budget,
            )
            if (
                current_outer_force_time_budget
                > maximum_outer_cumulative_abs_impulse_nms
                + IMPULSE_TOLERANCE_NMS
            ):
                outer_force_time_budget_violations += 1
            velocity_response = post_velocity / predicted
            force_response = (
                abs(step_generalized_force) / abs(torque)
                if torque != 0.0
                else None
            )
            acceptable = (
                expected_outer >= FIRST_ACCEPTABLE_OUTER_STEP
                and cell.get("motor_profile_fields_match") is True
                and cell.get("initial_velocity_readback_matches") is True
                and RESPONSE_MINIMUM <= velocity_response <= RESPONSE_MAXIMUM
                and (
                    force_response is None
                    or RESPONSE_MINIMUM <= force_response <= RESPONSE_MAXIMUM
                )
                and post_velocity * predicted > 0.0
                and (torque == 0.0 or step_generalized_force * torque < 0.0)
                and abs(step_actuator_force)
                < maximum_force_nm - UNSATURATED_MARGIN_NM
                and maximum_anchor <= ANCHOR_TOLERANCE_M
                and maximum_force_error <= FORCE_MAPPING_TOLERANCE_NM
                and maximum_post_force_error <= FORCE_MAPPING_TOLERANCE_NM
                and maximum_applied_error <= FORCE_MAPPING_TOLERANCE_NM
                and maximum_inertia_error
                <= GENERALIZED_INERTIA_TOLERANCE_KG_M2
                and maximum_saturated_momentum_error
                <= MOMENTUM_IMPULSE_TOLERANCE_NMS
                and maximum_unsaturated_momentum_error
                <= MOMENTUM_IMPULSE_TOLERANCE_NMS
                and internal_force_time_budget_violations == 0
                and outer_force_time_budget_violations == 0
                and effective_motor_impulse_violations == 0
                and continuity_mismatches == 0
            )
            if acceptable:
                if first_acceptable is None:
                    first_acceptable = expected_outer
                current_streak += 1
                longest_streak = max(longest_streak, current_streak)
            else:
                current_streak = 0
            current_outer_force_time_budget = 0.0

    terminal = [float(value) for value in trace[-1]]
    terminal_velocity_response = terminal[11] / predicted
    terminal_force_response = (
        abs(terminal[7]) / abs(torque) if torque != 0.0 else None
    )
    terminal_unsaturated = (
        abs(terminal[6]) < maximum_force_nm - UNSATURATED_MARGIN_NM
    )
    failures: list[str] = []
    if saturation_count < 1 or saturation_count != cell.get(
        "saturated_internal_step_count"
    ):
        failures.append(f"C6_MJC_HC_VH4_TRACE_SATURATION:{cell_id}")
    if temporal_witness_count < 1 or temporal_witness_count != cell.get(
        "temporal_force_distinction_witness_count"
    ):
        failures.append(f"C6_MJC_HC_VH4_TRACE_TEMPORAL_WITNESS:{cell_id}")
    if not terminal_unsaturated:
        failures.append(f"C6_MJC_HC_VH4_TRACE_TERMINAL_SATURATION:{cell_id}")
    if continuity_mismatches != 0:
        failures.append(f"C6_MJC_HC_VH4_TRACE_STATE_CONTINUITY:{cell_id}")

    comparisons = (
        (terminal[10], float(cell.get("terminal_joint_position_rad", math.nan))),
        (terminal[11], float(cell.get("terminal_joint_velocity_rad_s", math.nan))),
        (terminal[6], float(cell.get("terminal_actuator_force_nm", math.nan))),
        (
            terminal[7],
            float(cell.get("terminal_generalized_actuator_torque_nm", math.nan)),
        ),
        (
            terminal[8],
            float(cell.get("terminal_external_applied_torque_nm", math.nan)),
        ),
        (
            maximum_internal_force_time_budget,
            float(
                cell.get("maximum_internal_step_force_time_budget_nms", math.nan)
            ),
        ),
        (
            maximum_outer_force_time_budget,
            float(
                cell.get(
                    "maximum_controller_step_cumulative_abs_force_time_budget_nms",
                    math.nan,
                )
            ),
        ),
        (
            maximum_effective_motor_impulse,
            float(cell.get("maximum_effective_motor_impulse_nms", math.nan)),
        ),
        (
            maximum_force_error,
            float(
                cell.get(
                    "maximum_actuation_space_to_joint_space_force_error_nm",
                    math.nan,
                )
            ),
        ),
        (
            maximum_post_force_error,
            float(
                cell.get(
                    "maximum_post_state_actuation_space_to_joint_space_force_error_nm",
                    math.nan,
                )
            ),
        ),
        (
            maximum_applied_error,
            float(cell.get("maximum_applied_torque_readback_error_nm", math.nan)),
        ),
        (
            maximum_inertia_error,
            float(
                cell.get(
                    "maximum_generalized_inertia_readback_error_kg_m2",
                    math.nan,
                )
            ),
        ),
        (
            maximum_saturated_momentum_error,
            float(
                cell.get(
                    "maximum_saturated_step_force_time_to_momentum_error_nms",
                    math.nan,
                )
            ),
        ),
        (
            maximum_unsaturated_momentum_error,
            float(
                cell.get(
                    "maximum_unsaturated_post_state_force_time_to_momentum_error_nms",
                    math.nan,
                )
            ),
        ),
        (
            maximum_anchor,
            float(
                cell.get(
                    "maximum_joint_anchor_world_position_residual_m", math.nan
                )
            ),
        ),
    )
    if any(
        not math.isclose(a, b, rel_tol=0.0, abs_tol=1.0e-12)
        for a, b in comparisons
    ):
        failures.append(f"C6_MJC_HC_VH4_TRACE_SUMMARY_MISMATCH:{cell_id}")
    if not math.isclose(
        terminal_velocity_response,
        float(cell.get("terminal_normalized_velocity_response", math.nan)),
        rel_tol=0.0,
        abs_tol=1.0e-12,
    ):
        failures.append(f"C6_MJC_HC_VH4_TRACE_VELOCITY_RESPONSE:{cell_id}")
    reported_force_response = cell.get("terminal_normalized_force_response")
    if (
        terminal_force_response is None
        and reported_force_response is not None
    ) or (
        terminal_force_response is not None
        and (
            not isinstance(reported_force_response, (int, float))
            or not math.isclose(
                terminal_force_response,
                float(reported_force_response),
                rel_tol=0.0,
                abs_tol=1.0e-12,
            )
        )
    ):
        failures.append(f"C6_MJC_HC_VH4_TRACE_FORCE_RESPONSE:{cell_id}")
    if (
        cell.get("first_acceptable_outer_step") != first_acceptable
        or cell.get("longest_acceptable_outer_streak") != longest_streak
    ):
        failures.append(f"C6_MJC_HC_VH4_TRACE_RECOVERY_STREAK:{cell_id}")

    reconstructed_counts = {
        "internal_step_force_time_budget_violation_count": (
            internal_force_time_budget_violations
        ),
        "controller_step_cumulative_force_time_budget_violation_count": (
            outer_force_time_budget_violations
        ),
        "effective_motor_impulse_limit_violation_count": (
            effective_motor_impulse_violations
        ),
        "actuation_space_to_joint_space_force_mismatch_count": force_mismatches,
        "applied_torque_readback_mismatch_count": applied_mismatches,
        "generalized_inertia_readback_mismatch_count": inertia_mismatches,
        "saturated_step_force_time_to_momentum_mismatch_count": (
            saturated_momentum_mismatches
        ),
        "unsaturated_post_state_force_time_to_momentum_mismatch_count": (
            unsaturated_momentum_mismatches
        ),
        "temporal_force_distinction_missing_count": int(
            temporal_witness_count == 0
        ),
        "state_continuity_mismatch_count": continuity_mismatches,
        "nonfinite_observation_count": 0,
    }
    if any(cell.get(name) != value for name, value in reconstructed_counts.items()):
        failures.append(f"C6_MJC_HC_VH4_TRACE_COUNT_RECEIPT:{cell_id}")
    if (
        cell.get("terminal_internal_step_unsaturated") is not terminal_unsaturated
        or cell.get("target_and_response_signs_match")
        is not (terminal[11] * predicted > 0.0)
        or cell.get("loaded_force_opposes_external_torque")
        is not (torque == 0.0 or terminal[7] * torque < 0.0)
        or cell.get("temporal_measurement_valid")
        is not (
            saturated_momentum_mismatches == 0
            and unsaturated_momentum_mismatches == 0
            and temporal_witness_count >= 1
            and continuity_mismatches == 0
        )
        or cell.get("all_values_finite") is not True
    ):
        failures.append(f"C6_MJC_HC_VH4_TRACE_BOOLEAN_RECEIPT:{cell_id}")
    if maximum_anchor > ANCHOR_TOLERANCE_M:
        failures.append(f"C6_MJC_HC_VH4_TRACE_ANCHOR_LIMIT:{cell_id}")
    if maximum_force_error > FORCE_MAPPING_TOLERANCE_NM:
        failures.append(f"C6_MJC_HC_VH4_TRACE_FORCE_MAPPING_LIMIT:{cell_id}")
    if maximum_post_force_error > FORCE_MAPPING_TOLERANCE_NM:
        failures.append(f"C6_MJC_HC_VH4_TRACE_POST_FORCE_MAPPING_LIMIT:{cell_id}")
    if maximum_applied_error > FORCE_MAPPING_TOLERANCE_NM:
        failures.append(f"C6_MJC_HC_VH4_TRACE_APPLIED_TORQUE_LIMIT:{cell_id}")
    if maximum_inertia_error > GENERALIZED_INERTIA_TOLERANCE_KG_M2:
        failures.append(f"C6_MJC_HC_VH4_TRACE_INERTIA_LIMIT:{cell_id}")
    if (
        maximum_saturated_momentum_error > MOMENTUM_IMPULSE_TOLERANCE_NMS
        or maximum_unsaturated_momentum_error > MOMENTUM_IMPULSE_TOLERANCE_NMS
    ):
        failures.append(f"C6_MJC_HC_VH4_TRACE_MOMENTUM_RELATION:{cell_id}")
    if (
        internal_force_time_budget_violations != 0
        or outer_force_time_budget_violations != 0
        or effective_motor_impulse_violations != 0
    ):
        failures.append(f"C6_MJC_HC_VH4_TRACE_FORCE_TIME_OR_IMPULSE_LIMIT:{cell_id}")
    return failures


def evaluate_stability_host_report(report: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    try:
        declaration = _preregistration()
        declared = _expanded_cells(declaration)
    except (ConformanceFailure, OSError, ValueError, json.JSONDecodeError) as error:
        return [f"C6_MJC_HC_VH4_DECLARATION_INVALID:{error}"]
    if report.get("schema_version") != REPORT_SCHEMA:
        failures.append("C6_MJC_HC_VH4_REPORT_SCHEMA")
    if report.get("campaign_id") != CAMPAIGN_ID or report.get("gate_id") != GATE_ID:
        failures.append("C6_MJC_HC_VH4_REPORT_IDENTITY")
    mechanism = report.get("stability_mechanism", {})
    if (
        mechanism.get("internal_steps_per_controller_step")
        != INTERNAL_STEPS_PER_OUTER
        or mechanism.get("internal_timestep_s") != INTERNAL_DT_S
        or not math.isclose(
            float(
                mechanism.get(
                    "exact_fixture_saturated_band_crossing_ratio", math.nan
                )
            ),
            EXACT_FIXTURE_SATURATED_BAND_CROSSING_RATIO,
            rel_tol=0.0,
            abs_tol=1.0e-15,
        )
        or not math.isclose(
            float(
                mechanism.get(
                    "exact_fixture_unsaturated_implicitfast_error_multiplier",
                    math.nan,
                )
            ),
            EXACT_FIXTURE_UNSATURATED_IMPLICITFAST_MULTIPLIER,
            rel_tol=0.0,
            abs_tol=1.0e-15,
        )
        or float(
            mechanism.get(
                "armature_only_saturated_band_crossing_ratio", math.inf
            )
        )
        >= STRICT_SATURATED_BAND_SKIP_BOUND
    ):
        failures.append("C6_MJC_HC_VH4_STABILITY_MECHANISM")
    cells = report.get("cells")
    if not isinstance(cells, list):
        return failures + ["C6_MJC_HC_VH4_CELLS_MISSING"]
    expected_ids = [cell["cell_id"] for cell in declared]
    if [cell.get("cell_id") for cell in cells] != expected_ids:
        failures.append("C6_MJC_HC_VH4_CELL_ORDER_OR_CARDINALITY")
    declared_by_id = {cell["cell_id"]: cell for cell in declared}
    for cell in cells:
        cell_id = str(cell.get("cell_id", "unknown"))
        expected = declared_by_id.get(cell_id)
        if expected is None:
            failures.append(f"C6_MJC_HC_VH4_UNKNOWN_CELL:{cell_id}")
            continue
        if any(cell.get(key) != value for key, value in expected.items()):
            failures.append(f"C6_MJC_HC_VH4_DECLARED_CELL_MISMATCH:{cell_id}")
        trace_failures = _trace_failures(cell)
        failures.extend(trace_failures)
        velocity_response = float(cell.get("terminal_normalized_velocity_response", math.nan))
        force_response = cell.get("terminal_normalized_force_response")
        passed = (
            _motor_readback_matches(cell.get("motor_readback"), expected)
            and int(cell.get("world_build_count", -1)) == 1
            and cell.get("motor_profile_fields_match") is True
            and cell.get("initial_velocity_readback_matches") is True
            and math.isclose(
                float(
                    cell.get(
                        "initial_joint_velocity_readback_rad_s", math.nan
                    )
                ),
                float(expected["initial_joint_velocity_rad_s"]),
                rel_tol=0.0,
                abs_tol=1.0e-15,
            )
            and cell.get("generalized_inertia_readback_matches") is True
            and cell.get("temporal_measurement_valid") is True
            and int(cell.get("temporal_force_distinction_witness_count", 0))
            >= 1
            and cell.get("all_values_finite") is True
            and cell.get("target_and_response_signs_match") is True
            and cell.get("loaded_force_opposes_external_torque") is True
            and cell.get("terminal_internal_step_unsaturated") is True
            and int(cell.get("outer_steps_executed", -1)) == OUTER_STEPS
            and int(cell.get("internal_steps_executed", -1))
            == TRACE_RECORDS_PER_CELL
            and int(cell.get("longest_acceptable_outer_streak", -1))
            >= REQUIRED_OUTER_STREAK
            and int(cell.get("saturated_internal_step_count", 0)) >= 1
            and RESPONSE_MINIMUM <= velocity_response <= RESPONSE_MAXIMUM
            and float(
                cell.get("maximum_internal_step_force_time_budget_nms", math.inf)
            )
            <= MAXIMUM_INTERNAL_IMPULSE_NMS + IMPULSE_TOLERANCE_NMS
            and float(
                cell.get(
                    "maximum_controller_step_cumulative_abs_force_time_budget_nms",
                    math.inf,
                )
            )
            <= MAXIMUM_OUTER_CUMULATIVE_ABS_IMPULSE_NMS + IMPULSE_TOLERANCE_NMS
            and float(cell.get("maximum_effective_motor_impulse_nms", math.inf))
            <= MAXIMUM_INTERNAL_IMPULSE_NMS + IMPULSE_TOLERANCE_NMS
            and int(
                cell.get("internal_step_force_time_budget_violation_count", -1)
            )
            == 0
            and int(
                cell.get(
                    "controller_step_cumulative_force_time_budget_violation_count",
                    -1,
                )
            )
            == 0
            and int(cell.get("effective_motor_impulse_limit_violation_count", -1))
            == 0
            and int(cell.get("nonfinite_observation_count", -1)) == 0
            and float(
                cell.get(
                    "maximum_joint_anchor_world_position_residual_m",
                    math.inf,
                )
            )
            <= ANCHOR_TOLERANCE_M
            and float(
                cell.get(
                    "maximum_actuation_space_to_joint_space_force_error_nm",
                    math.inf,
                )
            )
            <= FORCE_MAPPING_TOLERANCE_NM
            and float(
                cell.get("maximum_applied_torque_readback_error_nm", math.inf)
            )
            <= FORCE_MAPPING_TOLERANCE_NM
            and int(
                cell.get(
                    "actuation_space_to_joint_space_force_mismatch_count", -1
                )
            )
            == 0
            and int(cell.get("applied_torque_readback_mismatch_count", -1)) == 0
            and float(
                cell.get(
                    "maximum_generalized_inertia_readback_error_kg_m2",
                    math.inf,
                )
            )
            <= GENERALIZED_INERTIA_TOLERANCE_KG_M2
            and int(cell.get("generalized_inertia_readback_mismatch_count", -1))
            == 0
            and float(
                cell.get(
                    "maximum_saturated_step_force_time_to_momentum_error_nms",
                    math.inf,
                )
            )
            <= MOMENTUM_IMPULSE_TOLERANCE_NMS
            and int(
                cell.get(
                    "saturated_step_force_time_to_momentum_mismatch_count",
                    -1,
                )
            )
            == 0
            and float(
                cell.get(
                    "maximum_unsaturated_post_state_force_time_to_momentum_error_nms",
                    math.inf,
                )
            )
            <= MOMENTUM_IMPULSE_TOLERANCE_NMS
            and int(
                cell.get(
                    "unsaturated_post_state_force_time_to_momentum_mismatch_count",
                    -1,
                )
            )
            == 0
            and int(cell.get("temporal_force_distinction_missing_count", -1))
            == 0
            and int(cell.get("state_continuity_mismatch_count", -1)) == 0
            and trace_failures == []
        )
        if expected["kind"] == "loaded":
            passed = passed and isinstance(force_response, (int, float)) and (
                RESPONSE_MINIMUM <= float(force_response) <= RESPONSE_MAXIMUM
            )
        if cell.get("passed") is not True or not passed:
            failures.append(f"C6_MJC_HC_VH4_CELL_GATE:{cell_id}")
    pairs = _pair_receipts(cells)
    if len(pairs) != 12 or not all(pair["passed"] for pair in pairs):
        failures.append("C6_MJC_HC_VH4_MIRRORED_PAIR_GATE")
    expected_integrity = {
        "world_attempt_count": 24,
        "world_build_count": 24,
        "world_reset_count": 0,
        "model_or_field_mismatch_count": 0,
        "initial_velocity_readback_mismatch_count": 0,
        "trace_cardinality_mismatch_count": 0,
        "nonfinite_observation_count": 0,
        "internal_step_force_time_budget_violation_count": 0,
        "controller_step_cumulative_force_time_budget_violation_count": 0,
        "effective_motor_impulse_limit_violation_count": 0,
        "actuation_space_to_joint_space_force_mismatch_count": 0,
        "applied_torque_readback_mismatch_count": 0,
        "generalized_inertia_readback_mismatch_count": 0,
        "saturated_step_force_time_to_momentum_mismatch_count": 0,
        "unsaturated_post_state_force_time_to_momentum_mismatch_count": 0,
        "temporal_force_distinction_missing_count": 0,
        "state_continuity_mismatch_count": 0,
        "internal_trace_record_count": TRACE_RECORDS_PER_CELL * 24,
    }
    integrity = report.get("integrity", {})
    for name, expected_value in expected_integrity.items():
        if integrity.get(name) != expected_value:
            failures.append(f"C6_MJC_HC_VH4_INTEGRITY_{name.upper()}")
    for authority in (
        "controller_policy_authority",
        "selected_policy_physical_authority",
        "physical_acceptance_authority",
    ):
        if report.get(authority) is not False:
            failures.append(f"C6_MJC_HC_VH4_{authority.upper()}")
    claim_boundary = report.get("claim_boundary", {})
    for forbidden in (
        "continuous_gain_inertia_timestep_velocity_or_load_domain",
        "mujoco_selected_policy_locomotion",
        "mujoco_walking",
        "cross_engine_equivalence",
        "morphology_coverage",
        "friction_or_material_robustness",
        "release_authority",
        "physical_acceptance_authority",
        "completed_engine_neutral_sdk",
    ):
        if claim_boundary.get(forbidden) is not False:
            failures.append(f"C6_MJC_HC_VH4_CLAIM_{forbidden.upper()}")
    return sorted(set(failures))


def _perfect_motor_readback(declared: dict[str, Any]) -> dict[str, Any]:
    maximum_force_nm = float(declared.get("maximum_force_nm", MAXIMUM_FORCE_NM))
    profile_id = str(declared.get("profile_id", PROFILE_ID))
    return {
        "profile_id": profile_id,
        "native_actuator": "velocity",
        "transmission_type": "mjTRN_JOINT",
        "transmission_type_code": 0,
        "transmission_target_joint_id_matches": True,
        "transmission_gear": DECLARED_GEAR.tolist(),
        "control_target_velocity_rad_s": declared["target_velocity_rad_s"],
        "velocity_gain_nm_s_per_rad": VELOCITY_GAIN,
        "velocity_bias_gain_nm_s_per_rad": -VELOCITY_GAIN,
        "force_limited": True,
        "force_range_nm": [-maximum_force_nm, maximum_force_nm],
        "joint_type": "hinge",
        "joint_limited": False,
        "joint_axis": DECLARED_AXIS.tolist(),
        "joint_armature": JOINT_ARMATURE,
        "joint_passive_damping": 0.0,
        "child_half_extents_m": CHILD_HALF_EXTENTS_M.tolist(),
        "child_mass_kg": CHILD_MASS_KG,
        "contacts_enabled": False,
        "internal_timestep_s": INTERNAL_DT_S,
        "controller_timestep_s": CONTROLLER_DT_S,
        "internal_steps_per_controller_step": INTERNAL_STEPS_PER_OUTER,
        "integrator": "implicitfast",
        "solver": "Newton",
        "solver_iterations": 20,
        "line_search_iterations": 7,
        "stepping_api": "mj_step1_mj_step2",
        "actuation_capture": "after_mj_step2_before_post_state_mj_forward",
        "initial_joint_velocity_rad_s": declared["initial_joint_velocity_rad_s"],
        "native_position_target": False,
        "independent_native_position_feedback": False,
        "analytic_effective_joint_inertia_kg_m2": ANALYTIC_EFFECTIVE_INERTIA,
        "generalized_inertia_readback_kg_m2": ANALYTIC_EFFECTIVE_INERTIA,
        "saturated_band_crossing_ratio": (
            EXACT_FIXTURE_SATURATED_BAND_CROSSING_RATIO
        ),
        "unsaturated_implicitfast_error_multiplier": (
            EXACT_FIXTURE_UNSATURATED_IMPLICITFAST_MULTIPLIER
        ),
    }


def _perfect_trace(declared: dict[str, Any]) -> list[list[float | int]]:
    target = float(declared["target_velocity_rad_s"])
    torque = float(declared["external_torque_nm"])
    maximum_force_nm = float(declared.get("maximum_force_nm", MAXIMUM_FORCE_NM))
    trace: list[list[float | int]] = []
    position = 0.0
    velocity = float(declared["initial_joint_velocity_rad_s"])
    for index in range(TRACE_RECORDS_PER_CELL):
        outer = index // INTERNAL_STEPS_PER_OUTER
        substep = index % INTERNAL_STEPS_PER_OUTER
        pre_position = position
        pre_velocity = velocity
        step_force = max(
            -maximum_force_nm,
            min(maximum_force_nm, VELOCITY_GAIN * (target - pre_velocity)),
        )
        saturated = (
            abs(abs(step_force) - maximum_force_nm) <= SATURATION_TOLERANCE_NM
        )
        denominator = ANALYTIC_EFFECTIVE_INERTIA
        if not saturated:
            denominator += INTERNAL_DT_S * VELOCITY_GAIN
        velocity = pre_velocity + (
            INTERNAL_DT_S * (step_force + torque) / denominator
        )
        position = pre_position + velocity * INTERNAL_DT_S
        effective_motor_impulse = (
            ANALYTIC_EFFECTIVE_INERTIA * (velocity - pre_velocity)
            - torque * INTERNAL_DT_S
        )
        post_state_force = max(
            -maximum_force_nm,
            min(maximum_force_nm, VELOCITY_GAIN * (target - velocity)),
        )
        trace.append(
            [
                index,
                outer,
                substep,
                (index + 1) * INTERNAL_DT_S,
                pre_position,
                pre_velocity,
                step_force,
                step_force,
                torque,
                ANALYTIC_EFFECTIVE_INERTIA,
                position,
                velocity,
                effective_motor_impulse,
                post_state_force,
                post_state_force,
                ANALYTIC_EFFECTIVE_INERTIA,
                0.0,
            ]
        )
    return trace


def _perfect_synthetic_report() -> dict[str, Any]:
    declaration = _preregistration()
    cells: list[dict[str, Any]] = []
    for declared in _expanded_cells(declaration):
        trace = _perfect_trace(declared)
        torque = float(declared["external_torque_nm"])
        terminal = trace[-1]
        force_time_budgets = [abs(float(row[7])) * INTERNAL_DT_S for row in trace]
        outer_force_time_budgets = [
            sum(
                force_time_budgets[
                    outer * INTERNAL_STEPS_PER_OUTER :
                    (outer + 1) * INTERNAL_STEPS_PER_OUTER
                ]
            )
            for outer in range(OUTER_STEPS)
        ]
        saturated_rows = [
            row
            for row in trace
            if abs(abs(float(row[6])) - MAXIMUM_FORCE_NM)
            <= SATURATION_TOLERANCE_NM
        ]
        unsaturated_rows = [row for row in trace if row not in saturated_rows]
        saturated_momentum_error = max(
            abs(float(row[12]) - float(row[7]) * INTERNAL_DT_S)
            for row in saturated_rows
        )
        unsaturated_momentum_error = max(
            abs(float(row[12]) - float(row[14]) * INTERNAL_DT_S)
            for row in unsaturated_rows
        )
        temporal_witness_count = sum(
            int(abs(float(row[6]) - float(row[13])) > TEMPORAL_FORCE_WITNESS_TOLERANCE_NM)
            for row in trace
        )
        cells.append(
            {
                **declared,
                "world_build_count": 1,
                "initial_joint_velocity_readback_rad_s": declared[
                    "initial_joint_velocity_rad_s"
                ],
                "initial_velocity_readback_matches": True,
                "generalized_inertia_readback_matches": True,
                "terminal_joint_position_rad": terminal[10],
                "terminal_joint_velocity_rad_s": terminal[11],
                "terminal_actuator_force_nm": terminal[6],
                "terminal_generalized_actuator_torque_nm": terminal[7],
                "terminal_external_applied_torque_nm": terminal[8],
                "terminal_normalized_velocity_response": 1.0,
                "terminal_normalized_force_response": 1.0 if torque != 0.0 else None,
                "maximum_joint_anchor_world_position_residual_m": 0.0,
                "maximum_actuation_space_to_joint_space_force_error_nm": 0.0,
                "maximum_post_state_actuation_space_to_joint_space_force_error_nm": 0.0,
                "maximum_applied_torque_readback_error_nm": 0.0,
                "maximum_generalized_inertia_readback_error_kg_m2": 0.0,
                "maximum_internal_step_force_time_budget_nms": max(
                    force_time_budgets
                ),
                "maximum_controller_step_cumulative_abs_force_time_budget_nms": max(
                    outer_force_time_budgets
                ),
                "maximum_effective_motor_impulse_nms": max(
                    abs(float(row[12])) for row in trace
                ),
                "maximum_saturated_step_force_time_to_momentum_error_nms": (
                    saturated_momentum_error
                ),
                "maximum_unsaturated_post_state_force_time_to_momentum_error_nms": (
                    unsaturated_momentum_error
                ),
                "outer_steps_executed": OUTER_STEPS,
                "internal_steps_executed": TRACE_RECORDS_PER_CELL,
                "first_acceptable_outer_step": FIRST_ACCEPTABLE_OUTER_STEP,
                "longest_acceptable_outer_streak": (
                    OUTER_STEPS - FIRST_ACCEPTABLE_OUTER_STEP
                ),
                "saturated_internal_step_count": len(saturated_rows),
                "temporal_force_distinction_witness_count": temporal_witness_count,
                "temporal_measurement_valid": True,
                "terminal_internal_step_unsaturated": True,
                "motor_profile_fields_match": True,
                "motor_readback": _perfect_motor_readback(declared),
                "all_values_finite": True,
                "target_and_response_signs_match": True,
                "loaded_force_opposes_external_torque": True,
                "internal_step_force_time_budget_violation_count": 0,
                "controller_step_cumulative_force_time_budget_violation_count": 0,
                "effective_motor_impulse_limit_violation_count": 0,
                "actuation_space_to_joint_space_force_mismatch_count": 0,
                "applied_torque_readback_mismatch_count": 0,
                "generalized_inertia_readback_mismatch_count": 0,
                "saturated_step_force_time_to_momentum_mismatch_count": 0,
                "unsaturated_post_state_force_time_to_momentum_mismatch_count": 0,
                "temporal_force_distinction_missing_count": 0,
                "state_continuity_mismatch_count": 0,
                "nonfinite_observation_count": 0,
                "internal_step_trace": trace,
                "passed": True,
            }
        )
    return {
        "schema_version": REPORT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "stability_mechanism": {
            "internal_steps_per_controller_step": INTERNAL_STEPS_PER_OUTER,
            "internal_timestep_s": INTERNAL_DT_S,
            "saturation_band_half_width_rad_s": SATURATION_BAND_HALF_WIDTH_RAD_S,
            "exact_fixture_saturated_band_crossing_ratio": (
                EXACT_FIXTURE_SATURATED_BAND_CROSSING_RATIO
            ),
            "exact_fixture_unsaturated_implicitfast_error_multiplier": (
                EXACT_FIXTURE_UNSATURATED_IMPLICITFAST_MULTIPLIER
            ),
            "armature_only_saturated_band_crossing_ratio": (
                ARMATURE_ONLY_SATURATED_BAND_CROSSING_RATIO
            ),
            "armature_only_unsaturated_implicitfast_error_multiplier": (
                ARMATURE_ONLY_UNSATURATED_IMPLICITFAST_MULTIPLIER
            ),
            "strict_saturated_band_skip_bound": STRICT_SATURATED_BAND_SKIP_BOUND,
        },
        "motor_profile": {"profile_id": PROFILE_ID},
        "cells": cells,
        "mirrored_pairs": _pair_receipts(cells),
        "integrity": {
            "world_attempt_count": 24,
            "world_build_count": 24,
            "world_reset_count": 0,
            "model_or_field_mismatch_count": 0,
            "initial_velocity_readback_mismatch_count": 0,
            "trace_cardinality_mismatch_count": 0,
            "nonfinite_observation_count": 0,
            "internal_step_force_time_budget_violation_count": 0,
            "controller_step_cumulative_force_time_budget_violation_count": 0,
            "effective_motor_impulse_limit_violation_count": 0,
            "actuation_space_to_joint_space_force_mismatch_count": 0,
            "applied_torque_readback_mismatch_count": 0,
            "generalized_inertia_readback_mismatch_count": 0,
            "saturated_step_force_time_to_momentum_mismatch_count": 0,
            "unsaturated_post_state_force_time_to_momentum_mismatch_count": 0,
            "temporal_force_distinction_missing_count": 0,
            "state_continuity_mismatch_count": 0,
            "internal_trace_record_count": TRACE_RECORDS_PER_CELL * 24,
        },
        "claim_boundary": declaration["claim_boundary"],
        "controller_policy_authority": False,
        "selected_policy_physical_authority": False,
        "physical_acceptance_authority": False,
    }


def run_stability_host_preflight() -> dict[str, Any]:
    declaration = _preregistration()
    host = _host_identity_receipt(declaration)
    perfect = _perfect_synthetic_report()
    _require(
        evaluate_stability_host_report(perfect) == [],
        "C6_MJC_HC_VH4_PERFECT_SYNTHETIC_REJECTED",
    )
    serialized = json.dumps(perfect, allow_nan=False, separators=(",", ":"))
    _require(
        evaluate_stability_host_report(json.loads(serialized)) == [],
        "C6_MJC_HC_VH4_PERFECT_ROUND_TRIP_REJECTED",
    )

    def rejects(mutator: Any) -> bool:
        candidate = json.loads(serialized)
        mutator(candidate)
        return len(evaluate_stability_host_report(candidate)) > 0

    def corrupt_recovery_trace(value: dict[str, Any]) -> None:
        trace = value["cells"][0]["internal_step_trace"]
        for outer in range(FIRST_ACCEPTABLE_OUTER_STEP, 241):
            terminal_index = (
                outer * INTERNAL_STEPS_PER_OUTER
                + INTERNAL_STEPS_PER_OUTER
                - 1
            )
            trace[terminal_index][11] = 0.0

    def corrupt_anchor_trace_and_summary(value: dict[str, Any]) -> None:
        corrupted_anchor = ANCHOR_TOLERANCE_M * 1000.0
        value["cells"][0]["internal_step_trace"][0][16] = corrupted_anchor
        value["cells"][0][
            "maximum_joint_anchor_world_position_residual_m"
        ] = corrupted_anchor

    canaries = {
        "missing_cell": rejects(lambda value: value["cells"].pop()),
        "wrong_substep_count": rejects(
            lambda value: value["stability_mechanism"].__setitem__(
                "internal_steps_per_controller_step", 1
            )
        ),
        "wrong_initial_velocity": rejects(
            lambda value: value["cells"][0].__setitem__(
                "initial_joint_velocity_rad_s", 1.0
            )
        ),
        "wrong_initial_velocity_numeric_readback": rejects(
            lambda value: value["cells"][0].__setitem__(
                "initial_joint_velocity_readback_rad_s", 1.0
            )
        ),
        "unsafe_declared_saturated_band_crossing_ratio": rejects(
            lambda value: value["stability_mechanism"].__setitem__(
                "armature_only_saturated_band_crossing_ratio", 2.1
            )
        ),
        "wrong_generalized_inertia_readback": rejects(
            lambda value: value["cells"][0]["internal_step_trace"][0].__setitem__(
                9, 0.02
            )
        ),
        "missing_trace": rejects(
            lambda value: value["cells"][0].pop("internal_step_trace")
        ),
        "wrong_trace_cardinality": rejects(
            lambda value: value["cells"][0]["internal_step_trace"].pop()
        ),
        "wrong_velocity_response": rejects(
            lambda value: value["cells"][0].__setitem__(
                "terminal_normalized_velocity_response", 0.97
            )
        ),
        "wrong_loaded_force_response": rejects(
            lambda value: value["cells"][8].__setitem__(
                "terminal_normalized_force_response", 1.03
            )
        ),
        "missing_transient_saturation": rejects(
            lambda value: value["cells"][0].__setitem__(
                "saturated_internal_step_count", 0
            )
        ),
        "missing_saturation_recovery": rejects(
            lambda value: value["cells"][0].__setitem__(
                "longest_acceptable_outer_streak", 0
            )
        ),
        "forged_recovery_streak_over_failing_trace": rejects(
            corrupt_recovery_trace
        ),
        "coherent_anchor_limit_violation": rejects(
            corrupt_anchor_trace_and_summary
        ),
        "force_mapping_mismatch": rejects(
            lambda value: value["cells"][0]["internal_step_trace"][0].__setitem__(
                7, 5.0
            )
        ),
        "force_time_budget_limit": rejects(
            lambda value: value["cells"][0].__setitem__(
                "maximum_internal_step_force_time_budget_nms", 0.011
            )
        ),
        "effective_impulse_limit": rejects(
            lambda value: value["cells"][0].__setitem__(
                "maximum_effective_motor_impulse_nms", 0.011
            )
        ),
        "pre_step_force_replaced_by_post_state_force": rejects(
            lambda value: (
                value["cells"][0]["internal_step_trace"][0].__setitem__(
                    6, value["cells"][0]["internal_step_trace"][0][13]
                ),
                value["cells"][0]["internal_step_trace"][0].__setitem__(
                    7, value["cells"][0]["internal_step_trace"][0][14]
                ),
            )
        ),
        "saturated_momentum_impulse_mismatch": rejects(
            lambda value: value["cells"][0]["internal_step_trace"][0].__setitem__(
                12, value["cells"][0]["internal_step_trace"][0][12] + 0.001
            )
        ),
        "unsaturated_momentum_impulse_mismatch": rejects(
            lambda value: value["cells"][0]["internal_step_trace"][1].__setitem__(
                12, value["cells"][0]["internal_step_trace"][1][12] + 0.001
            )
        ),
        "missing_temporal_distinction_witness": rejects(
            lambda value: [
                (
                    row.__setitem__(6, row[13]),
                    row.__setitem__(7, row[14]),
                )
                for row in value["cells"][0]["internal_step_trace"]
            ]
        ),
        "world_count_inflation": rejects(
            lambda value: value["integrity"].__setitem__("world_build_count", 25)
        ),
        "physical_authority_inflation": rejects(
            lambda value: value.__setitem__("physical_acceptance_authority", True)
        ),
    }
    _require(
        len(canaries) == 23 and all(canaries.values()),
        "C6_MJC_HC_VH4_NEGATIVE_CONTROL_ACCEPTED",
        json.dumps(canaries, sort_keys=True),
    )
    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "ok": True,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "preregistration_raw_sha256": EXPECTED_PREREGISTRATION_SHA256,
        "declared_cell_count": 24,
        "declared_internal_trace_record_count": TRACE_RECORDS_PER_CELL * 24,
        "host_identity": host,
        "stability_mechanism": {
            "saturation_band_half_width_rad_s": SATURATION_BAND_HALF_WIDTH_RAD_S,
            "vh1_exact_fixture_saturated_band_crossing_ratio": 5.0,
            "vh1_exact_fixture_unsaturated_implicitfast_error_multiplier": (
                1.0 / 6.0
            ),
            "vh4_exact_fixture_saturated_band_crossing_ratio": (
                EXACT_FIXTURE_SATURATED_BAND_CROSSING_RATIO
            ),
            "vh4_exact_fixture_unsaturated_implicitfast_error_multiplier": (
                EXACT_FIXTURE_UNSATURATED_IMPLICITFAST_MULTIPLIER
            ),
            "vh4_armature_only_saturated_band_crossing_ratio": (
                ARMATURE_ONLY_SATURATED_BAND_CROSSING_RATIO
            ),
            "vh4_armature_only_unsaturated_implicitfast_error_multiplier": (
                ARMATURE_ONLY_UNSATURATED_IMPLICITFAST_MULTIPLIER
            ),
            "strict_saturated_band_skip_bound": STRICT_SATURATED_BAND_SKIP_BOUND,
            "exact_fixture_cannot_skip_full_unsaturated_band": (
                EXACT_FIXTURE_SATURATED_BAND_CROSSING_RATIO
                < STRICT_SATURATED_BAND_SKIP_BOUND
            ),
            "armature_only_cannot_skip_full_unsaturated_band": (
                ARMATURE_ONLY_SATURATED_BAND_CROSSING_RATIO
                < STRICT_SATURATED_BAND_SKIP_BOUND
            ),
        },
        "perfect_synthetic_result_passed": True,
        "perfect_synthetic_serialization_round_trip_passed": True,
        "negative_controls_rejected": canaries,
        "negative_control_count": len(canaries),
        "binding_surface_canaries_passed": {
            "mjdata_has_M": host["binding_surface"]["mjdata_has_M"],
            "mjdata_has_no_qM": not host["binding_surface"]["mjdata_has_qM"],
            "mj_fullM_signature_exact": (
                host["binding_surface"]["mj_fullM_signature"]
                == EXPECTED_MJ_FULLM_SIGNATURE
            ),
            "mj_step1_callable": host["binding_surface"]["mj_step1_callable"],
            "mj_step2_callable": host["binding_surface"]["mj_step2_callable"],
        },
        "binding_surface_canary_count": host["binding_surface_canary_count"],
        "world_build_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
    }


def _option_xml() -> str:
    return (
        f'<option timestep="{INTERNAL_DT_S:.17g}" gravity="0 0 0" '
        'integrator="implicitfast" solver="Newton" iterations="20" '
        'ls_iterations="7" cone="elliptic"/>'
    )


def _model(maximum_force_nm: float = MAXIMUM_FORCE_NM) -> mujoco.MjModel:
    xml = f"""
<mujoco model="sporespore_mujoco_velocity_only_vh4">
  <compiler angle="radian" inertiafromgeom="true"/>
  {_option_xml()}
  <worldbody>
    <body name="child" pos="0 0 0">
      <joint name="hinge" type="hinge" pos="0 0 0" axis="1 0 0"
             armature="{JOINT_ARMATURE:.17g}" damping="0" limited="false"/>
      <geom name="child_geom" type="box" pos="0 0 0" size=".1 .1 .1"
             mass="1" contype="0" conaffinity="0"/>
    </body>
  </worldbody>
  <actuator>
    <velocity name="motor" joint="hinge" gear="1 0 0 0 0 0"
              ctrllimited="false" kv="{VELOCITY_GAIN:.17g}"
              forcelimited="true"
               forcerange="{-maximum_force_nm:.17g} {maximum_force_nm:.17g}"/>
  </actuator>
</mujoco>
"""
    return mujoco.MjModel.from_xml_string(xml)


def _generalized_inertia_readback(
    model: mujoco.MjModel, data: mujoco.MjData
) -> float:
    dense = np.empty((int(model.nv), int(model.nv)), dtype=np.float64, order="C")
    mujoco.mj_fullM(model, data, dense)
    return float(dense[0, 0])


def _run_cell(declared: dict[str, Any], model: mujoco.MjModel) -> dict[str, Any]:
    """Run one VH4 cell with actuation and state sampled on distinct time slices."""

    data = mujoco.MjData(model)
    observation = mujoco.MjData(model)
    joint_id = model.joint("hinge").id
    actuator_id = model.actuator("motor").id
    body_id = model.body("child").id
    geom_id = model.geom("child_geom").id
    qpos_address = int(model.jnt_qposadr[joint_id])
    dof_address = int(model.jnt_dofadr[joint_id])
    target = float(declared["target_velocity_rad_s"])
    torque = float(declared["external_torque_nm"])
    predicted = float(declared["predicted_steady_velocity_rad_s"])
    initial = float(declared["initial_joint_velocity_rad_s"])
    maximum_force_nm = float(declared.get("maximum_force_nm", MAXIMUM_FORCE_NM))
    maximum_internal_impulse_nms = maximum_force_nm * INTERNAL_DT_S
    maximum_outer_cumulative_abs_impulse_nms = (
        maximum_internal_impulse_nms * INTERNAL_STEPS_PER_OUTER
    )
    profile_id = str(declared.get("profile_id", PROFILE_ID))
    data.qvel[dof_address] = initial
    mujoco.mj_forward(model, data)
    initial_velocity_readback = float(data.qvel[dof_address])
    initial_readback_matches = initial_velocity_readback == initial
    _require(
        int(model.nv) == 1
        and np.asarray(data.M).shape == (1,)
        and np.asarray(data.M).dtype == np.float64,
        "C6_MJC_HC_VH4_GENERALIZED_INERTIA_LAYOUT_INVALID",
    )

    child_inertia = float(model.body_inertia[body_id, 0])
    effective_inertia = child_inertia + float(model.dof_armature[dof_address])
    generalized_inertia_readback = _generalized_inertia_readback(model, data)
    saturated_band_crossing_ratio = (
        VELOCITY_GAIN * float(model.opt.timestep) / generalized_inertia_readback
    )
    unsaturated_implicitfast_multiplier = 1.0 / (
        1.0 + saturated_band_crossing_ratio
    )
    motor_readback = {
        "profile_id": profile_id,
        "native_actuator": "velocity",
        "transmission_type": (
            "mjTRN_JOINT"
            if int(model.actuator_trntype[actuator_id])
            == int(mujoco.mjtTrn.mjTRN_JOINT)
            else f"code:{int(model.actuator_trntype[actuator_id])}"
        ),
        "transmission_type_code": int(model.actuator_trntype[actuator_id]),
        "transmission_target_joint_id_matches": int(
            model.actuator_trnid[actuator_id, 0]
        )
        == joint_id,
        "transmission_gear": np.asarray(
            model.actuator_gear[actuator_id], dtype=float
        ).tolist(),
        "control_target_velocity_rad_s": target,
        "velocity_gain_nm_s_per_rad": float(model.actuator_gainprm[actuator_id, 0]),
        "velocity_bias_gain_nm_s_per_rad": float(
            model.actuator_biasprm[actuator_id, 2]
        ),
        "force_limited": bool(model.actuator_forcelimited[actuator_id]),
        "force_range_nm": np.asarray(
            model.actuator_forcerange[actuator_id], dtype=float
        ).tolist(),
        "joint_type": (
            "hinge"
            if int(model.jnt_type[joint_id]) == int(mujoco.mjtJoint.mjJNT_HINGE)
            else f"code:{int(model.jnt_type[joint_id])}"
        ),
        "joint_limited": bool(model.jnt_limited[joint_id]),
        "joint_axis": np.asarray(model.jnt_axis[joint_id], dtype=float).tolist(),
        "joint_armature": float(model.dof_armature[dof_address]),
        "joint_passive_damping": float(model.dof_damping[dof_address]),
        "child_half_extents_m": np.asarray(model.geom_size[geom_id], dtype=float).tolist(),
        "child_mass_kg": float(model.body_mass[body_id]),
        "contacts_enabled": bool(
            model.geom_contype[geom_id] != 0 or model.geom_conaffinity[geom_id] != 0
        ),
        "internal_timestep_s": float(model.opt.timestep),
        "controller_timestep_s": CONTROLLER_DT_S,
        "internal_steps_per_controller_step": INTERNAL_STEPS_PER_OUTER,
        "integrator": (
            "implicitfast"
            if int(model.opt.integrator)
            == int(mujoco.mjtIntegrator.mjINT_IMPLICITFAST)
            else f"code:{int(model.opt.integrator)}"
        ),
        "solver": (
            "Newton"
            if int(model.opt.solver) == int(mujoco.mjtSolver.mjSOL_NEWTON)
            else f"code:{int(model.opt.solver)}"
        ),
        "solver_iterations": int(model.opt.iterations),
        "line_search_iterations": int(model.opt.ls_iterations),
        "stepping_api": "mj_step1_mj_step2",
        "actuation_capture": "after_mj_step2_before_post_state_mj_forward",
        "initial_joint_velocity_rad_s": initial,
        "native_position_target": False,
        "independent_native_position_feedback": False,
        "analytic_effective_joint_inertia_kg_m2": effective_inertia,
        "generalized_inertia_readback_kg_m2": generalized_inertia_readback,
        "saturated_band_crossing_ratio": saturated_band_crossing_ratio,
        "unsaturated_implicitfast_error_multiplier": (
            unsaturated_implicitfast_multiplier
        ),
    }
    fields_match = _motor_readback_matches(motor_readback, declared)

    trace: list[list[float | int]] = []
    longest_streak = 0
    current_streak = 0
    first_acceptable: int | None = None
    saturation_count = 0
    temporal_witness_count = 0
    maximum_anchor = 0.0
    maximum_force_error = 0.0
    maximum_post_force_error = 0.0
    maximum_applied_error = 0.0
    maximum_inertia_error = 0.0
    maximum_internal_force_time_budget = 0.0
    maximum_outer_force_time_budget = 0.0
    maximum_effective_motor_impulse = 0.0
    maximum_saturated_momentum_error = 0.0
    maximum_unsaturated_momentum_error = 0.0
    internal_force_time_budget_violations = 0
    outer_force_time_budget_violations = 0
    effective_motor_impulse_violations = 0
    force_mismatches = 0
    applied_mismatches = 0
    inertia_mismatches = 0
    saturated_momentum_mismatches = 0
    unsaturated_momentum_mismatches = 0
    nonfinite = 0
    terminal_position = math.nan
    terminal_velocity = math.nan
    terminal_actuator_force = math.nan
    terminal_generalized_force = math.nan
    terminal_applied_torque = math.nan

    for outer in range(OUTER_STEPS):
        outer_force_time_budget = 0.0
        for substep in range(INTERNAL_STEPS_PER_OUTER):
            index = outer * INTERNAL_STEPS_PER_OUTER + substep
            mujoco.mj_step1(model, data)
            pre_position = float(data.qpos[qpos_address])
            pre_velocity = float(data.qvel[dof_address])
            pre_inertia = _generalized_inertia_readback(model, data)

            data.ctrl[actuator_id] = target
            data.qfrc_applied.fill(0.0)
            data.qfrc_applied[dof_address] = torque
            mujoco.mj_step2(model, data)

            step_actuator_force = float(data.actuator_force[actuator_id])
            step_generalized_force = float(data.qfrc_actuator[dof_address])
            applied_torque = float(data.qfrc_applied[dof_address])
            post_position = float(data.qpos[qpos_address])
            post_velocity = float(data.qvel[dof_address])
            momentum_inferred_impulse = (
                pre_inertia * (post_velocity - pre_velocity)
                - applied_torque * INTERNAL_DT_S
            )

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
            post_state_actuator_force = float(
                observation.actuator_force[actuator_id]
            )
            post_state_generalized_force = float(
                observation.qfrc_actuator[dof_address]
            )
            post_inertia = _generalized_inertia_readback(model, observation)
            anchor = float(
                np.linalg.norm(
                    np.asarray(observation.xanchor[joint_id], dtype=float)
                    - DECLARED_ANCHOR
                )
            )

            force_error = abs(step_actuator_force - step_generalized_force)
            post_force_error = abs(
                post_state_actuator_force - post_state_generalized_force
            )
            applied_error = abs(applied_torque - torque)
            inertia_error = max(
                abs(pre_inertia - ANALYTIC_EFFECTIVE_INERTIA),
                abs(post_inertia - ANALYTIC_EFFECTIVE_INERTIA),
            )
            force_time_budget = abs(step_generalized_force) * INTERNAL_DT_S
            effective_motor_impulse = abs(momentum_inferred_impulse)
            saturated = (
                abs(abs(step_actuator_force) - maximum_force_nm)
                <= SATURATION_TOLERANCE_NM
            )
            if saturated:
                saturation_count += 1
                momentum_error = abs(
                    momentum_inferred_impulse
                    - step_generalized_force * INTERNAL_DT_S
                )
                maximum_saturated_momentum_error = max(
                    maximum_saturated_momentum_error, momentum_error
                )
                if momentum_error > MOMENTUM_IMPULSE_TOLERANCE_NMS:
                    saturated_momentum_mismatches += 1
            else:
                momentum_error = abs(
                    momentum_inferred_impulse
                    - post_state_generalized_force * INTERNAL_DT_S
                )
                maximum_unsaturated_momentum_error = max(
                    maximum_unsaturated_momentum_error, momentum_error
                )
                if momentum_error > MOMENTUM_IMPULSE_TOLERANCE_NMS:
                    unsaturated_momentum_mismatches += 1
            if (
                abs(step_actuator_force - post_state_actuator_force)
                > TEMPORAL_FORCE_WITNESS_TOLERANCE_NM
            ):
                temporal_witness_count += 1

            outer_force_time_budget += force_time_budget
            maximum_anchor = max(maximum_anchor, anchor)
            maximum_force_error = max(maximum_force_error, force_error)
            maximum_post_force_error = max(
                maximum_post_force_error, post_force_error
            )
            maximum_applied_error = max(maximum_applied_error, applied_error)
            maximum_inertia_error = max(maximum_inertia_error, inertia_error)
            maximum_internal_force_time_budget = max(
                maximum_internal_force_time_budget, force_time_budget
            )
            maximum_effective_motor_impulse = max(
                maximum_effective_motor_impulse, effective_motor_impulse
            )
            if force_time_budget > maximum_internal_impulse_nms + IMPULSE_TOLERANCE_NMS:
                internal_force_time_budget_violations += 1
            if effective_motor_impulse > maximum_internal_impulse_nms + IMPULSE_TOLERANCE_NMS:
                effective_motor_impulse_violations += 1
            if force_error > FORCE_MAPPING_TOLERANCE_NM:
                force_mismatches += 1
            if applied_error > FORCE_MAPPING_TOLERANCE_NM:
                applied_mismatches += 1
            if inertia_error > GENERALIZED_INERTIA_TOLERANCE_KG_M2:
                inertia_mismatches += 1

            values = (
                post_position,
                post_velocity,
                step_actuator_force,
                step_generalized_force,
                applied_torque,
                pre_inertia,
                momentum_inferred_impulse,
                post_state_actuator_force,
                post_state_generalized_force,
                post_inertia,
                anchor,
            )
            if not all(math.isfinite(value) for value in values):
                nonfinite += 1
            trace.append(
                [
                    index,
                    outer,
                    substep,
                    float(data.time),
                    pre_position,
                    pre_velocity,
                    step_actuator_force,
                    step_generalized_force,
                    applied_torque,
                    pre_inertia,
                    post_position,
                    post_velocity,
                    momentum_inferred_impulse,
                    post_state_actuator_force,
                    post_state_generalized_force,
                    post_inertia,
                    anchor,
                ]
            )
            terminal_position = post_position
            terminal_velocity = post_velocity
            terminal_actuator_force = step_actuator_force
            terminal_generalized_force = step_generalized_force
            terminal_applied_torque = applied_torque

        maximum_outer_force_time_budget = max(
            maximum_outer_force_time_budget, outer_force_time_budget
        )
        if (
            outer_force_time_budget
            > maximum_outer_cumulative_abs_impulse_nms + IMPULSE_TOLERANCE_NMS
        ):
            outer_force_time_budget_violations += 1
        velocity_response = terminal_velocity / predicted
        force_response = (
            abs(terminal_generalized_force) / abs(torque) if torque != 0.0 else None
        )
        acceptable = (
            outer >= FIRST_ACCEPTABLE_OUTER_STEP
            and fields_match
            and initial_readback_matches
            and RESPONSE_MINIMUM <= velocity_response <= RESPONSE_MAXIMUM
            and (
                force_response is None
                or RESPONSE_MINIMUM <= force_response <= RESPONSE_MAXIMUM
            )
            and terminal_velocity * predicted > 0.0
            and (torque == 0.0 or terminal_generalized_force * torque < 0.0)
            and abs(terminal_actuator_force)
            < maximum_force_nm - UNSATURATED_MARGIN_NM
            and maximum_anchor <= ANCHOR_TOLERANCE_M
            and maximum_force_error <= FORCE_MAPPING_TOLERANCE_NM
            and maximum_post_force_error <= FORCE_MAPPING_TOLERANCE_NM
            and maximum_applied_error <= FORCE_MAPPING_TOLERANCE_NM
            and maximum_inertia_error <= GENERALIZED_INERTIA_TOLERANCE_KG_M2
            and maximum_saturated_momentum_error
            <= MOMENTUM_IMPULSE_TOLERANCE_NMS
            and maximum_unsaturated_momentum_error
            <= MOMENTUM_IMPULSE_TOLERANCE_NMS
            and internal_force_time_budget_violations == 0
            and outer_force_time_budget_violations == 0
            and effective_motor_impulse_violations == 0
            and nonfinite == 0
        )
        if acceptable:
            if first_acceptable is None:
                first_acceptable = outer
            current_streak += 1
            longest_streak = max(longest_streak, current_streak)
        else:
            current_streak = 0

    velocity_response = terminal_velocity / predicted
    force_response = (
        abs(terminal_generalized_force) / abs(torque) if torque != 0.0 else None
    )
    terminal_unsaturated = (
        abs(terminal_actuator_force) < maximum_force_nm - UNSATURATED_MARGIN_NM
    )
    temporal_measurement_valid = (
        saturated_momentum_mismatches == 0
        and unsaturated_momentum_mismatches == 0
        and temporal_witness_count >= 1
    )
    passed = (
        fields_match
        and initial_readback_matches
        and saturation_count >= 1
        and temporal_measurement_valid
        and terminal_unsaturated
        and longest_streak >= REQUIRED_OUTER_STREAK
        and RESPONSE_MINIMUM <= velocity_response <= RESPONSE_MAXIMUM
        and (
            force_response is None
            or RESPONSE_MINIMUM <= force_response <= RESPONSE_MAXIMUM
        )
        and terminal_velocity * predicted > 0.0
        and (torque == 0.0 or terminal_generalized_force * torque < 0.0)
        and len(trace) == TRACE_RECORDS_PER_CELL
        and maximum_anchor <= ANCHOR_TOLERANCE_M
        and maximum_force_error <= FORCE_MAPPING_TOLERANCE_NM
        and maximum_post_force_error <= FORCE_MAPPING_TOLERANCE_NM
        and maximum_applied_error <= FORCE_MAPPING_TOLERANCE_NM
        and maximum_inertia_error <= GENERALIZED_INERTIA_TOLERANCE_KG_M2
        and internal_force_time_budget_violations == 0
        and outer_force_time_budget_violations == 0
        and effective_motor_impulse_violations == 0
        and force_mismatches == 0
        and applied_mismatches == 0
        and inertia_mismatches == 0
        and nonfinite == 0
    )
    return {
        **declared,
        "world_build_count": 1,
        "initial_joint_velocity_readback_rad_s": initial_velocity_readback,
        "initial_velocity_readback_matches": initial_readback_matches,
        "generalized_inertia_readback_matches": inertia_mismatches == 0,
        "terminal_joint_position_rad": terminal_position,
        "terminal_joint_velocity_rad_s": terminal_velocity,
        "terminal_actuator_force_nm": terminal_actuator_force,
        "terminal_generalized_actuator_torque_nm": terminal_generalized_force,
        "terminal_external_applied_torque_nm": terminal_applied_torque,
        "terminal_normalized_velocity_response": velocity_response,
        "terminal_normalized_force_response": force_response,
        "maximum_joint_anchor_world_position_residual_m": maximum_anchor,
        "maximum_actuation_space_to_joint_space_force_error_nm": maximum_force_error,
        "maximum_post_state_actuation_space_to_joint_space_force_error_nm": (
            maximum_post_force_error
        ),
        "maximum_applied_torque_readback_error_nm": maximum_applied_error,
        "maximum_generalized_inertia_readback_error_kg_m2": maximum_inertia_error,
        "maximum_internal_step_force_time_budget_nms": (
            maximum_internal_force_time_budget
        ),
        "maximum_controller_step_cumulative_abs_force_time_budget_nms": (
            maximum_outer_force_time_budget
        ),
        "maximum_effective_motor_impulse_nms": maximum_effective_motor_impulse,
        "maximum_saturated_step_force_time_to_momentum_error_nms": (
            maximum_saturated_momentum_error
        ),
        "maximum_unsaturated_post_state_force_time_to_momentum_error_nms": (
            maximum_unsaturated_momentum_error
        ),
        "outer_steps_executed": OUTER_STEPS,
        "internal_steps_executed": len(trace),
        "first_acceptable_outer_step": first_acceptable,
        "longest_acceptable_outer_streak": longest_streak,
        "saturated_internal_step_count": saturation_count,
        "temporal_force_distinction_witness_count": temporal_witness_count,
        "temporal_measurement_valid": temporal_measurement_valid,
        "terminal_internal_step_unsaturated": terminal_unsaturated,
        "motor_profile_fields_match": fields_match,
        "motor_readback": motor_readback,
        "all_values_finite": nonfinite == 0,
        "target_and_response_signs_match": terminal_velocity * predicted > 0.0,
        "loaded_force_opposes_external_torque": (
            torque == 0.0 or terminal_generalized_force * torque < 0.0
        ),
        "internal_step_force_time_budget_violation_count": (
            internal_force_time_budget_violations
        ),
        "controller_step_cumulative_force_time_budget_violation_count": (
            outer_force_time_budget_violations
        ),
        "effective_motor_impulse_limit_violation_count": (
            effective_motor_impulse_violations
        ),
        "actuation_space_to_joint_space_force_mismatch_count": force_mismatches,
        "applied_torque_readback_mismatch_count": applied_mismatches,
        "generalized_inertia_readback_mismatch_count": inertia_mismatches,
        "saturated_step_force_time_to_momentum_mismatch_count": (
            saturated_momentum_mismatches
        ),
        "unsaturated_post_state_force_time_to_momentum_mismatch_count": (
            unsaturated_momentum_mismatches
        ),
        "temporal_force_distinction_missing_count": int(
            temporal_witness_count == 0
        ),
        "state_continuity_mismatch_count": 0,
        "nonfinite_observation_count": nonfinite,
        "internal_step_trace": trace,
        "passed": passed,
    }


def run_stability_host_characterization(source_commit: str) -> dict[str, Any]:
    _require(
        len(source_commit) == 40
        and all(character in "0123456789abcdef" for character in source_commit),
        "C6_MJC_HC_VH4_SOURCE_COMMIT_INVALID",
        source_commit,
    )
    preflight = run_stability_host_preflight()
    declaration = _preregistration()
    cells: list[dict[str, Any]] = []
    for declared in _expanded_cells(declaration):
        cells.append(_run_cell(declared, _model()))
    integrity = {
        "world_attempt_count": 24,
        "world_build_count": sum(int(cell["world_build_count"]) for cell in cells),
        "world_reset_count": 0,
        "model_or_field_mismatch_count": sum(
            int(not cell["motor_profile_fields_match"]) for cell in cells
        ),
        "initial_velocity_readback_mismatch_count": sum(
            int(not cell["initial_velocity_readback_matches"]) for cell in cells
        ),
        "trace_cardinality_mismatch_count": sum(
            int(len(cell["internal_step_trace"]) != TRACE_RECORDS_PER_CELL)
            for cell in cells
        ),
        "nonfinite_observation_count": sum(
            int(cell["nonfinite_observation_count"]) for cell in cells
        ),
        "internal_step_force_time_budget_violation_count": sum(
            int(cell["internal_step_force_time_budget_violation_count"])
            for cell in cells
        ),
        "controller_step_cumulative_force_time_budget_violation_count": sum(
            int(
                cell[
                    "controller_step_cumulative_force_time_budget_violation_count"
                ]
            )
            for cell in cells
        ),
        "effective_motor_impulse_limit_violation_count": sum(
            int(cell["effective_motor_impulse_limit_violation_count"])
            for cell in cells
        ),
        "actuation_space_to_joint_space_force_mismatch_count": sum(
            int(cell["actuation_space_to_joint_space_force_mismatch_count"])
            for cell in cells
        ),
        "applied_torque_readback_mismatch_count": sum(
            int(cell["applied_torque_readback_mismatch_count"]) for cell in cells
        ),
        "generalized_inertia_readback_mismatch_count": sum(
            int(cell["generalized_inertia_readback_mismatch_count"])
            for cell in cells
        ),
        "saturated_step_force_time_to_momentum_mismatch_count": sum(
            int(cell["saturated_step_force_time_to_momentum_mismatch_count"])
            for cell in cells
        ),
        "unsaturated_post_state_force_time_to_momentum_mismatch_count": sum(
            int(
                cell[
                    "unsaturated_post_state_force_time_to_momentum_mismatch_count"
                ]
            )
            for cell in cells
        ),
        "temporal_force_distinction_missing_count": sum(
            int(cell["temporal_force_distinction_missing_count"])
            for cell in cells
        ),
        "state_continuity_mismatch_count": sum(
            int(cell["state_continuity_mismatch_count"]) for cell in cells
        ),
        "internal_trace_record_count": sum(
            len(cell["internal_step_trace"]) for cell in cells
        ),
    }
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
            "path": PREREGISTRATION_PATH.relative_to(SDK_ROOT.parent).as_posix(),
            "raw_sha256": EXPECTED_PREREGISTRATION_SHA256,
        },
        "preflight": preflight,
        "host": {
            **preflight["host_identity"],
            "portable_controller_timestep_s": CONTROLLER_DT_S,
            "internal_physics_timestep_s": INTERNAL_DT_S,
            "internal_steps_per_controller_step": INTERNAL_STEPS_PER_OUTER,
            "integrator": "implicitfast",
            "solver": "Newton",
            "solver_iterations": 20,
            "line_search_iterations": 7,
        },
        "stability_mechanism": {
            "internal_steps_per_controller_step": INTERNAL_STEPS_PER_OUTER,
            "internal_timestep_s": INTERNAL_DT_S,
            "saturation_band_half_width_rad_s": SATURATION_BAND_HALF_WIDTH_RAD_S,
            "exact_fixture_saturated_band_crossing_ratio": (
                EXACT_FIXTURE_SATURATED_BAND_CROSSING_RATIO
            ),
            "exact_fixture_unsaturated_implicitfast_error_multiplier": (
                EXACT_FIXTURE_UNSATURATED_IMPLICITFAST_MULTIPLIER
            ),
            "armature_only_saturated_band_crossing_ratio": (
                ARMATURE_ONLY_SATURATED_BAND_CROSSING_RATIO
            ),
            "armature_only_unsaturated_implicitfast_error_multiplier": (
                ARMATURE_ONLY_UNSATURATED_IMPLICITFAST_MULTIPLIER
            ),
            "strict_saturated_band_skip_bound": STRICT_SATURATED_BAND_SKIP_BOUND,
        },
        "motor_profile": {
            "profile_id": PROFILE_ID,
            "native_actuator": "velocity",
            "velocity_gain_nm_s_per_rad": VELOCITY_GAIN,
            "force_range_nm": [-MAXIMUM_FORCE_NM, MAXIMUM_FORCE_NM],
            "native_position_target": False,
            "independent_native_position_feedback": False,
            "finite_dynamic_force_saturation_recovery_characterized_if_passed": True,
        },
        "cells": cells,
        "mirrored_pairs": _pair_receipts(cells),
        "integrity": integrity,
        "claim_boundary": declaration["claim_boundary"],
        "controller_policy_authority": False,
        "selected_policy_physical_authority": False,
        "physical_acceptance_authority": False,
    }
    failures = evaluate_stability_host_report(report)
    report["failures"] = failures
    report["passed_cells"] = sum(int(cell["passed"]) for cell in cells)
    report["failed_cells"] = len(cells) - report["passed_cells"]
    report["ok"] = not failures
    report["claim_boundary"][
        "exact_finite_mujoco_velocity_only_stability_host_characterization_if_passed"
    ] = report["ok"]
    report["claim_boundary"][
        "exact_finite_transient_force_saturation_recovery_if_passed"
    ] = report["ok"]
    # Re-evaluate the final claim-carrying representation.
    final_failures = evaluate_stability_host_report(report)
    if final_failures != failures:
        report["failures"] = final_failures
        report["ok"] = False
    return report


def _write_new_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--preflight-only", action="store_true")
    group.add_argument("--run-physical", action="store_true")
    parser.add_argument("--source-commit")
    parser.add_argument("--report")
    args = parser.parse_args()
    try:
        if args.preflight_only:
            receipt = run_stability_host_preflight()
            print(json.dumps(receipt, indent=2, allow_nan=False))
            return 0
        _require(
            isinstance(args.source_commit, str) and isinstance(args.report, str),
            "C6_MJC_HC_VH4_PHYSICAL_ARGUMENTS_MISSING",
        )
        report = run_stability_host_characterization(args.source_commit)
        _write_new_json(Path(args.report), report)
        print(json.dumps(report, separators=(",", ":"), allow_nan=False))
        return 0 if report["ok"] else 1
    except (ConformanceFailure, OSError, ValueError, json.JSONDecodeError) as error:
        print(str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
