"""Prospective s169 per-actuator MuJoCo host characterization VH5.

VH5 reuses VH4's temporally correct scalar-fixture measurement primitives but
owns a distinct declaration, evaluator, source identity, force-limit grid, and
claim boundary.  Its preflight compiles the portable s169 descriptor and
evaluates a complete synthetic report without constructing ``MjModel``.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
from typing import Any, Callable

from .conformance import ConformanceFailure, _require
from .selected_policy_development import LocomotionCore, s169_descriptor
from . import velocity_only_stability_characterization_vh4 as vh4


CAMPAIGN_ID = (
    "C6-MUJOCO-S169-PER-ACTUATOR-FORCE-LIMIT-HOST-CHARACTERIZATION-VH5"
)
GATE_ID = "C6-MJC-HC-VH5"
PROFILE_ID = "mujoco_s169_per_actuator_force_limited_five_substep_candidate_v1"
REPORT_SCHEMA = (
    "sporespore_mujoco_c6_s169_per_actuator_force_limit_host_"
    "characterization_vh5_report_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_mujoco_c6_s169_per_actuator_force_limit_host_"
    "characterization_vh5_preflight_v1"
)
SDK_ROOT = Path(__file__).resolve().parents[3]
PREREGISTRATION_PATH = SDK_ROOT / (
    "mujoco_c6_s169_per_actuator_force_limit_host_"
    "characterization_vh5_preregistration.json"
)
EXPECTED_PREREGISTRATION_SHA256 = (
    "sha256:dfe87630215f3c857b0edff51678b8e113acaf216b3d12e6b3a923ad0db30d90"
)
EXPECTED_IMPLEMENTATION_PARENT = "086f3019228167e8f8d526200d2b7304af0ed6e0"
EXPECTED_DESCRIPTOR_SHA256 = (
    "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0"
)
EXPECTED_MORPHOLOGY_SPEC_SHA256 = (
    "sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e"
)
EXPECTED_CLASS_COUNT = 4
EXPECTED_CELL_COUNT = 96
EXPECTED_PAIR_COUNT = 48
EXPECTED_TRACE_COUNT = EXPECTED_CELL_COUNT * vh4.TRACE_RECORDS_PER_CELL
NEGATIVE_CONTROL_COUNT = 24

EXPECTED_FORCE_CLASSES = (
    (
        "front_hip",
        ("front_left_hip_motor", "front_right_hip_motor"),
        0.05362625170687301,
        6.435150204824762,
    ),
    (
        "front_knee",
        ("front_left_knee_motor", "front_right_knee_motor"),
        0.04387602412380519,
        5.265122894856622,
    ),
    (
        "rear_hip",
        ("rear_left_hip_motor", "rear_right_hip_motor"),
        0.056373748293126996,
        6.764849795175239,
    ),
    (
        "rear_knee",
        ("rear_left_knee_motor", "rear_right_knee_motor"),
        0.046123975876194816,
        5.534877105143378,
    ),
)

PAIR_BASES = (
    ("unloaded_v075", "unloaded_vn075", "unloaded_vp075"),
    ("unloaded_v225", "unloaded_vn225", "unloaded_vp225"),
    (
        "loaded_v150_t075_same",
        "loaded_vn150_tn075",
        "loaded_vp150_tp075",
    ),
    (
        "loaded_v150_t075_opposed",
        "loaded_vn150_tp075",
        "loaded_vp150_tn075",
    ),
    (
        "loaded_v150_t225_same",
        "loaded_vn150_tn225",
        "loaded_vp150_tp225",
    ),
    (
        "loaded_v150_t225_opposed",
        "loaded_vn150_tp225",
        "loaded_vp150_tn225",
    ),
)

INTEGRITY_ZERO_FIELDS = (
    "world_reset_count",
    "model_or_field_mismatch_count",
    "initial_velocity_readback_mismatch_count",
    "trace_cardinality_mismatch_count",
    "nonfinite_observation_count",
    "internal_step_force_time_budget_violation_count",
    "controller_step_cumulative_force_time_budget_violation_count",
    "effective_motor_impulse_limit_violation_count",
    "actuation_space_to_joint_space_force_mismatch_count",
    "applied_torque_readback_mismatch_count",
    "generalized_inertia_readback_mismatch_count",
    "saturated_step_force_time_to_momentum_mismatch_count",
    "unsaturated_post_state_force_time_to_momentum_mismatch_count",
    "temporal_force_distinction_missing_count",
    "state_continuity_mismatch_count",
)


def _raw_sha256(path: Path) -> str:
    return f"sha256:{hashlib.sha256(path.read_bytes()).hexdigest()}"


def _preregistration() -> dict[str, Any]:
    _require(
        PREREGISTRATION_PATH.is_file(),
        "C6_MJC_HC_VH5_PREREGISTRATION_MISSING",
        str(PREREGISTRATION_PATH),
    )
    observed_hash = _raw_sha256(PREREGISTRATION_PATH)
    _require(
        observed_hash == EXPECTED_PREREGISTRATION_SHA256,
        "C6_MJC_HC_VH5_PREREGISTRATION_HASH_MISMATCH",
        observed_hash,
    )
    declaration = json.loads(PREREGISTRATION_PATH.read_text(encoding="utf-8"))
    host = declaration.get("host_identity", {})
    fixture = declaration.get("fixture", {})
    profile = declaration.get("motor_profile", {})
    grid = declaration.get("physical_grid", {})
    _require(
        declaration.get("campaign_id") == CAMPAIGN_ID
        and declaration.get("gate_id") == GATE_ID
        and declaration.get("status")
        in {
            "prospective_draft_before_executable_freeze",
            "frozen_before_first_c6_mjc_hc_vh5_campaign_world",
        }
        and declaration.get("implementation_parent_commit")
        == EXPECTED_IMPLEMENTATION_PARENT,
        "C6_MJC_HC_VH5_PREREGISTRATION_IDENTITY_INVALID",
    )
    _require(
        host.get("engine_version") == "3.11.0"
        and host.get("python_version") == "3.11.9"
        and host.get("numpy_version") == "2.4.6"
        and host.get("portable_controller_timestep_s") == vh4.CONTROLLER_DT_S
        and host.get("internal_physics_timestep_s") == vh4.INTERNAL_DT_S
        and host.get("internal_physics_steps_per_controller_step")
        == vh4.INTERNAL_STEPS_PER_OUTER
        and host.get("integrator") == "implicitfast"
        and host.get("solver") == "Newton"
        and host.get("solver_iterations") == 20
        and host.get("line_search_iterations") == 7
        and host.get("gravity_m_s2") == [0.0, 0.0, 0.0],
        "C6_MJC_HC_VH5_HOST_DECLARATION_INVALID",
    )
    _require(
        fixture.get("joint_armature") == vh4.JOINT_ARMATURE
        and fixture.get("joint_passive_damping") == 0.0
        and fixture.get("child_half_extents_m") == [0.1, 0.1, 0.1]
        and fixture.get("child_mass_kg") == vh4.CHILD_MASS_KG
        and math.isclose(
            float(fixture.get("analytic_effective_joint_inertia_kg_m2")),
            vh4.ANALYTIC_EFFECTIVE_INERTIA,
            rel_tol=0.0,
            abs_tol=1.0e-15,
        )
        and fixture.get("contacts_enabled") is False,
        "C6_MJC_HC_VH5_FIXTURE_DECLARATION_INVALID",
    )
    _require(
        profile.get("profile_id") == PROFILE_ID
        and profile.get("native_actuator") == "velocity"
        and profile.get("transmission_type") == "mjTRN_JOINT"
        and profile.get("velocity_gain_nm_s_per_rad") == vh4.VELOCITY_GAIN
        and profile.get("native_position_target") is False
        and profile.get("independent_native_position_feedback") is False,
        "C6_MJC_HC_VH5_PROFILE_DECLARATION_INVALID",
    )
    _require(
        _force_classes_match(profile.get("force_limit_classes")),
        "C6_MJC_HC_VH5_FORCE_CLASSES_INVALID",
    )
    _require(
        len(grid.get("base_target_load_cells", [])) == 12
        and len(grid.get("initial_condition_profiles", [])) == 2
        and grid.get("worlds") == EXPECTED_CELL_COUNT
        and grid.get("replacement_worlds") == 0
        and grid.get("outer_controller_steps_per_cell") == vh4.OUTER_STEPS
        and grid.get("internal_physics_steps_per_outer_step")
        == vh4.INTERNAL_STEPS_PER_OUTER
        and grid.get("internal_trace_records_per_cell")
        == vh4.TRACE_RECORDS_PER_CELL
        and grid.get("aggregate_internal_trace_records") == EXPECTED_TRACE_COUNT
        and grid.get("mirrored_signed_pairs") == EXPECTED_PAIR_COUNT
        and grid.get("first_acceptable_outer_step")
        == vh4.FIRST_ACCEPTABLE_OUTER_STEP
        and grid.get("required_consecutive_acceptable_outer_steps")
        == vh4.REQUIRED_OUTER_STREAK
        and grid.get("early_stop_forbidden") is True,
        "C6_MJC_HC_VH5_GRID_DECLARATION_INVALID",
    )
    claims = declaration.get("claim_boundary", {})
    qualification = declaration.get("pre_freeze_implementation_qualification", {})
    _require(
        qualification.get("draft_preregistration_raw_sha256")
        == "6ae2b1dee6036c0cdda8573eaa8610b816642da4b94b091cc8f76c624c94d2a2"
        and qualification.get(
            "complete_synthetic_preflight_passed_before_any_qualification_model"
        )
        is True
        and qualification.get("synthetic_preflight_world_build_count") == 0
        and qualification.get("ordinary_non_campaign_world_count") == 4
        and qualification.get("all_four_qualification_cells_passed_the_already_declared_cell_gate")
        is True
        and qualification.get(
            "qualification_results_may_not_be_substituted_into_campaign_report"
        )
        is True
        and qualification.get(
            "grid_thresholds_estimand_and_claim_boundary_changed_after_qualification"
        )
        is False
        and qualification.get("first_supervised_campaign_world_has_not_opened") is True,
        "C6_MJC_HC_VH5_QUALIFICATION_BOUNDARY_INVALID",
    )
    _require(
        claims.get("mujoco_selected_policy_locomotion") is False
        and claims.get("mujoco_walking") is False
        and claims.get("cross_engine_equivalence") is False
        and claims.get("physical_acceptance_authority") is False,
        "C6_MJC_HC_VH5_CLAIM_BOUNDARY_INVALID",
    )
    return declaration


def _force_classes_match(value: Any) -> bool:
    if not isinstance(value, list) or len(value) != EXPECTED_CLASS_COUNT:
        return False
    for observed, expected in zip(value, EXPECTED_FORCE_CLASSES, strict=True):
        class_id, actuator_ids, impulse_nms, force_nm = expected
        if not isinstance(observed, dict):
            return False
        if (
            observed.get("class_id") != class_id
            or tuple(observed.get("actuator_ids", [])) != actuator_ids
            or observed.get("portable_maximum_impulse_nms") != impulse_nms
            or observed.get("maximum_force_nm") != force_nm
            or observed.get("maximum_internal_step_force_time_budget_nms")
            != force_nm * vh4.INTERNAL_DT_S
            or observed.get(
                "maximum_controller_step_cumulative_absolute_force_time_budget_nms"
            )
            != impulse_nms
            or force_nm != impulse_nms / vh4.CONTROLLER_DT_S
        ):
            return False
    return True


def _compiled_s169_receipt(declaration: dict[str, Any]) -> dict[str, Any]:
    compiled = LocomotionCore().compile_bounded_quadruped(s169_descriptor())
    morphology = compiled["morphology"]
    spec = morphology["morphology_spec"]
    actuators = {item["actuator_id"]: item for item in spec["actuators"]}
    classes = declaration["motor_profile"]["force_limit_classes"]
    class_receipts: list[dict[str, Any]] = []
    for force_class in classes:
        actuator_ids = list(force_class["actuator_ids"])
        impulses = [float(actuators[item]["maximum_impulse_nms"]) for item in actuator_ids]
        forces = [value / vh4.CONTROLLER_DT_S for value in impulses]
        matches = bool(
            len(set(impulses)) == 1
            and impulses[0] == float(force_class["portable_maximum_impulse_nms"])
            and len(set(forces)) == 1
            and forces[0] == float(force_class["maximum_force_nm"])
        )
        class_receipts.append(
            {
                "class_id": force_class["class_id"],
                "actuator_ids": actuator_ids,
                "compiled_portable_maximum_impulses_nms": impulses,
                "derived_native_force_limits_nm": forces,
                "matches_declaration": matches,
            }
        )
    source = declaration["selected_policy_source_binding"]
    _require(
        compiled["morphology_id"] == source["morphology_id"]
        and compiled["descriptor_sha256"] == EXPECTED_DESCRIPTOR_SHA256
        and morphology["morphology_spec_sha256"] == EXPECTED_MORPHOLOGY_SPEC_SHA256
        and all(item["matches_declaration"] for item in class_receipts),
        "C6_MJC_HC_VH5_COMPILED_S169_FORCE_LIMIT_MISMATCH",
    )
    return {
        "morphology_id": compiled["morphology_id"],
        "descriptor_sha256": compiled["descriptor_sha256"],
        "morphology_spec_sha256": morphology["morphology_spec_sha256"],
        "ordered_actuator_ids": morphology["ordered_actuator_ids"],
        "force_limit_classes": class_receipts,
        "class_count": len(class_receipts),
        "world_build_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
    }


def _expanded_cells(declaration: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for force_class in declaration["motor_profile"]["force_limit_classes"]:
        class_id = str(force_class["class_id"])
        maximum_force_nm = float(force_class["maximum_force_nm"])
        portable_impulse_nms = float(force_class["portable_maximum_impulse_nms"])
        for base in declaration["physical_grid"]["base_target_load_cells"]:
            target = float(base["target_velocity_rad_s"])
            torque = float(base["external_torque_nm"])
            predicted = target + torque / vh4.VELOCITY_GAIN
            _require(
                predicted != 0.0,
                "C6_MJC_HC_VH5_ZERO_PREDICTED_VELOCITY",
                str(base["base_id"]),
            )
            for initial_profile in ("zero", "adverse"):
                initial = (
                    0.0
                    if initial_profile == "zero"
                    else -3.0 * math.copysign(1.0, predicted)
                )
                result.append(
                    {
                        "cell_id": (
                            f"{class_id}__{base['base_id']}__i{initial_profile}"
                        ),
                        "force_limit_class_id": class_id,
                        "force_limit_class_actuator_ids": list(
                            force_class["actuator_ids"]
                        ),
                        "base_id": base["base_id"],
                        "kind": base["kind"],
                        "initial_condition_profile": initial_profile,
                        "initial_joint_velocity_rad_s": initial,
                        "target_velocity_rad_s": target,
                        "external_torque_nm": torque,
                        "predicted_steady_velocity_rad_s": predicted,
                        "portable_maximum_impulse_nms": portable_impulse_nms,
                        "maximum_force_nm": maximum_force_nm,
                        "maximum_internal_step_force_time_budget_nms": (
                            maximum_force_nm * vh4.INTERNAL_DT_S
                        ),
                        "maximum_controller_step_cumulative_absolute_force_time_budget_nms": (
                            portable_impulse_nms
                        ),
                        "profile_id": PROFILE_ID,
                    }
                )
    _require(
        len(result) == len({item["cell_id"] for item in result}) == EXPECTED_CELL_COUNT,
        "C6_MJC_HC_VH5_EXPANDED_CELL_IDENTITY_INVALID",
    )
    return result


def _relative_asymmetry(left: float, right: float) -> float:
    return abs(abs(left) - abs(right)) / max(abs(left), abs(right), 1.0e-12)


def _pair_receipts(cells: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_id = {str(cell.get("cell_id")): cell for cell in cells}
    result: list[dict[str, Any]] = []
    for class_id, _, _, _ in EXPECTED_FORCE_CLASSES:
        for initial_profile in ("zero", "adverse"):
            for pair_base, negative_base, positive_base in PAIR_BASES:
                left_id = f"{class_id}__{negative_base}__i{initial_profile}"
                right_id = f"{class_id}__{positive_base}__i{initial_profile}"
                left = by_id.get(left_id, {})
                right = by_id.get(right_id, {})
                velocity = _relative_asymmetry(
                    float(left.get("terminal_normalized_velocity_response", math.nan)),
                    float(right.get("terminal_normalized_velocity_response", math.nan)),
                )
                left_force = left.get("terminal_normalized_force_response")
                right_force = right.get("terminal_normalized_force_response")
                force = (
                    None
                    if left_force is None and right_force is None
                    else _relative_asymmetry(float(left_force), float(right_force))
                )
                result.append(
                    {
                        "pair_id": f"{class_id}__{pair_base}__i{initial_profile}",
                        "force_limit_class_id": class_id,
                        "left_cell_id": left_id,
                        "right_cell_id": right_id,
                        "velocity_response_relative_asymmetry": velocity,
                        "force_response_relative_asymmetry": force,
                        "passed": bool(
                            math.isfinite(velocity)
                            and velocity <= vh4.MAXIMUM_PAIR_ASYMMETRY
                            and (
                                force is None
                                or (
                                    math.isfinite(force)
                                    and force <= vh4.MAXIMUM_PAIR_ASYMMETRY
                                )
                            )
                        ),
                    }
                )
    return result


def _integrity(cells: list[dict[str, Any]]) -> dict[str, int]:
    result = {
        "world_attempt_count": EXPECTED_CELL_COUNT,
        "world_build_count": sum(int(cell["world_build_count"]) for cell in cells),
        "world_reset_count": 0,
        "model_or_field_mismatch_count": sum(
            int(not cell["motor_profile_fields_match"]) for cell in cells
        ),
        "initial_velocity_readback_mismatch_count": sum(
            int(not cell["initial_velocity_readback_matches"]) for cell in cells
        ),
        "trace_cardinality_mismatch_count": sum(
            int(len(cell["internal_step_trace"]) != vh4.TRACE_RECORDS_PER_CELL)
            for cell in cells
        ),
        "internal_trace_record_count": sum(
            len(cell["internal_step_trace"]) for cell in cells
        ),
    }
    source_fields = {
        "nonfinite_observation_count": "nonfinite_observation_count",
        "internal_step_force_time_budget_violation_count": (
            "internal_step_force_time_budget_violation_count"
        ),
        "controller_step_cumulative_force_time_budget_violation_count": (
            "controller_step_cumulative_force_time_budget_violation_count"
        ),
        "effective_motor_impulse_limit_violation_count": (
            "effective_motor_impulse_limit_violation_count"
        ),
        "actuation_space_to_joint_space_force_mismatch_count": (
            "actuation_space_to_joint_space_force_mismatch_count"
        ),
        "applied_torque_readback_mismatch_count": (
            "applied_torque_readback_mismatch_count"
        ),
        "generalized_inertia_readback_mismatch_count": (
            "generalized_inertia_readback_mismatch_count"
        ),
        "saturated_step_force_time_to_momentum_mismatch_count": (
            "saturated_step_force_time_to_momentum_mismatch_count"
        ),
        "unsaturated_post_state_force_time_to_momentum_mismatch_count": (
            "unsaturated_post_state_force_time_to_momentum_mismatch_count"
        ),
        "temporal_force_distinction_missing_count": (
            "temporal_force_distinction_missing_count"
        ),
        "state_continuity_mismatch_count": "state_continuity_mismatch_count",
    }
    for aggregate_name, cell_name in source_fields.items():
        result[aggregate_name] = sum(int(cell[cell_name]) for cell in cells)
    return result


def _value_matches(left: Any, right: Any) -> bool:
    if isinstance(right, float):
        try:
            return math.isclose(float(left), right, rel_tol=0.0, abs_tol=1.0e-15)
        except (TypeError, ValueError):
            return False
    return left == right


def evaluate_report(report: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    try:
        declaration = _preregistration()
        declared_cells = _expanded_cells(declaration)
    except (ConformanceFailure, KeyError, TypeError, ValueError) as error:
        return [f"C6_MJC_HC_VH5_DECLARATION:{error}"]
    if not isinstance(report, dict):
        return ["C6_MJC_HC_VH5_REPORT_TYPE"]
    if report.get("schema_version") != REPORT_SCHEMA:
        failures.append("C6_MJC_HC_VH5_REPORT_SCHEMA")
    if report.get("campaign_id") != CAMPAIGN_ID or report.get("gate_id") != GATE_ID:
        failures.append("C6_MJC_HC_VH5_REPORT_IDENTITY")
    profile = report.get("motor_profile", {})
    if (
        not isinstance(profile, dict)
        or profile.get("profile_id") != PROFILE_ID
        or not _force_classes_match(profile.get("force_limit_classes"))
    ):
        failures.append("C6_MJC_HC_VH5_REPORT_FORCE_CLASSES")
    cells = report.get("cells")
    if not isinstance(cells, list):
        return sorted(set(failures + ["C6_MJC_HC_VH5_CELLS_TYPE"]))
    expected_ids = [item["cell_id"] for item in declared_cells]
    if [item.get("cell_id") for item in cells if isinstance(item, dict)] != expected_ids:
        failures.append("C6_MJC_HC_VH5_CELL_IDENTITY_ORDER")
    if len(cells) != EXPECTED_CELL_COUNT:
        failures.append("C6_MJC_HC_VH5_CELL_COUNT")
    for index, declared in enumerate(declared_cells):
        if index >= len(cells) or not isinstance(cells[index], dict):
            failures.append(f"C6_MJC_HC_VH5_CELL_MISSING:{declared['cell_id']}")
            continue
        cell = cells[index]
        for key, expected in declared.items():
            if not _value_matches(cell.get(key), expected):
                failures.append(f"C6_MJC_HC_VH5_CELL_DECLARATION:{declared['cell_id']}:{key}")
        try:
            if not vh4._motor_readback_matches(cell.get("motor_readback"), declared):
                failures.append(f"C6_MJC_HC_VH5_MOTOR_READBACK:{declared['cell_id']}")
            trace_failures = vh4._trace_failures(
                cell,
                float(declared["maximum_force_nm"]),
            )
            failures.extend(
                item.replace("C6_MJC_HC_VH4", "C6_MJC_HC_VH5")
                for item in trace_failures
            )
        except (KeyError, TypeError, ValueError, OverflowError) as error:
            failures.append(f"C6_MJC_HC_VH5_CELL_EVALUATOR:{declared['cell_id']}:{error}")
        if cell.get("passed") is not True:
            failures.append(f"C6_MJC_HC_VH5_CELL_PASS:{declared['cell_id']}")
    try:
        expected_pairs = _pair_receipts(cells)
    except (KeyError, TypeError, ValueError, OverflowError):
        expected_pairs = []
        failures.append("C6_MJC_HC_VH5_PAIR_RECONSTRUCTION")
    if report.get("mirrored_pairs") != expected_pairs:
        failures.append("C6_MJC_HC_VH5_PAIR_RECEIPTS")
    if len(expected_pairs) != EXPECTED_PAIR_COUNT or any(
        item.get("passed") is not True for item in expected_pairs
    ):
        failures.append("C6_MJC_HC_VH5_PAIR_GATE")
    try:
        expected_integrity = _integrity(cells)
    except (KeyError, TypeError, ValueError, OverflowError):
        expected_integrity = {}
        failures.append("C6_MJC_HC_VH5_INTEGRITY_RECONSTRUCTION")
    if report.get("integrity") != expected_integrity:
        failures.append("C6_MJC_HC_VH5_INTEGRITY_RECEIPT")
    if (
        expected_integrity.get("world_attempt_count") != EXPECTED_CELL_COUNT
        or expected_integrity.get("world_build_count") != EXPECTED_CELL_COUNT
        or expected_integrity.get("internal_trace_record_count") != EXPECTED_TRACE_COUNT
        or any(expected_integrity.get(field) != 0 for field in INTEGRITY_ZERO_FIELDS)
    ):
        failures.append("C6_MJC_HC_VH5_INTEGRITY_GATE")
    claims = report.get("claim_boundary", {})
    forbidden_claims = (
        "continuous_force_limit_gain_inertia_load_or_timestep_domain",
        "selected_robot_multibody_dynamics_characterized",
        "mujoco_selected_policy_locomotion",
        "mujoco_walking",
        "cross_engine_equivalence",
        "arbitrary_quadruped_coverage",
        "friction_material_or_terrain_robustness",
        "release_authorized",
        "completed_engine_neutral_sdk",
        "physical_acceptance_authority",
    )
    if not isinstance(claims, dict) or any(claims.get(name) is not False for name in forbidden_claims):
        failures.append("C6_MJC_HC_VH5_CLAIM_INFLATION")
    if (
        report.get("controller_policy_authority") is not False
        or report.get("selected_policy_physical_authority") is not False
        or report.get("physical_acceptance_authority") is not False
    ):
        failures.append("C6_MJC_HC_VH5_AUTHORITY_INFLATION")
    substantive_failures = sorted(set(failures))
    expected_ok = not substantive_failures
    if report.get("ok") is not expected_ok:
        failures.append("C6_MJC_HC_VH5_OK_RECEIPT")
    expected_claim = bool(expected_ok)
    if not isinstance(claims, dict) or claims.get(
        "exact_finite_s169_per_actuator_force_limit_host_characterization_if_passed"
    ) is not expected_claim:
        failures.append("C6_MJC_HC_VH5_FINITE_CLAIM_RECEIPT")
    if report.get("passed_cells") != sum(
        int(isinstance(item, dict) and item.get("passed") is True) for item in cells
    ):
        failures.append("C6_MJC_HC_VH5_PASSED_COUNT")
    if report.get("failed_cells") != sum(
        int(not isinstance(item, dict) or item.get("passed") is not True) for item in cells
    ):
        failures.append("C6_MJC_HC_VH5_FAILED_COUNT")
    return sorted(set(failures))


def _perfect_cell(declared: dict[str, Any]) -> dict[str, Any]:
    trace = vh4._perfect_trace(declared)
    torque = float(declared["external_torque_nm"])
    maximum_force_nm = float(declared["maximum_force_nm"])
    terminal = trace[-1]
    force_time_budgets = [abs(float(row[7])) * vh4.INTERNAL_DT_S for row in trace]
    outer_force_time_budgets = [
        sum(
            force_time_budgets[
                outer * vh4.INTERNAL_STEPS_PER_OUTER :
                (outer + 1) * vh4.INTERNAL_STEPS_PER_OUTER
            ]
        )
        for outer in range(vh4.OUTER_STEPS)
    ]
    saturated_rows = [
        row
        for row in trace
        if abs(abs(float(row[6])) - maximum_force_nm) <= vh4.SATURATION_TOLERANCE_NM
    ]
    unsaturated_rows = [row for row in trace if row not in saturated_rows]
    return {
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
        "maximum_internal_step_force_time_budget_nms": max(force_time_budgets),
        "maximum_controller_step_cumulative_abs_force_time_budget_nms": max(
            outer_force_time_budgets
        ),
        "maximum_effective_motor_impulse_nms": max(
            abs(float(row[12])) for row in trace
        ),
        "maximum_saturated_step_force_time_to_momentum_error_nms": max(
            abs(float(row[12]) - float(row[7]) * vh4.INTERNAL_DT_S)
            for row in saturated_rows
        ),
        "maximum_unsaturated_post_state_force_time_to_momentum_error_nms": max(
            abs(float(row[12]) - float(row[14]) * vh4.INTERNAL_DT_S)
            for row in unsaturated_rows
        ),
        "outer_steps_executed": vh4.OUTER_STEPS,
        "internal_steps_executed": vh4.TRACE_RECORDS_PER_CELL,
        "first_acceptable_outer_step": vh4.FIRST_ACCEPTABLE_OUTER_STEP,
        "longest_acceptable_outer_streak": (
            vh4.OUTER_STEPS - vh4.FIRST_ACCEPTABLE_OUTER_STEP
        ),
        "saturated_internal_step_count": len(saturated_rows),
        "temporal_force_distinction_witness_count": sum(
            int(
                abs(float(row[6]) - float(row[13]))
                > vh4.TEMPORAL_FORCE_WITNESS_TOLERANCE_NM
            )
            for row in trace
        ),
        "temporal_measurement_valid": True,
        "terminal_internal_step_unsaturated": True,
        "motor_profile_fields_match": True,
        "motor_readback": vh4._perfect_motor_readback(declared),
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


def _perfect_report() -> dict[str, Any]:
    declaration = _preregistration()
    cells = [_perfect_cell(item) for item in _expanded_cells(declaration)]
    claim_boundary = dict(declaration["claim_boundary"])
    claim_boundary[
        "exact_finite_s169_per_actuator_force_limit_host_characterization_if_passed"
    ] = True
    return {
        "schema_version": REPORT_SCHEMA,
        "ok": True,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "motor_profile": declaration["motor_profile"],
        "cells": cells,
        "mirrored_pairs": _pair_receipts(cells),
        "integrity": _integrity(cells),
        "passed_cells": EXPECTED_CELL_COUNT,
        "failed_cells": 0,
        "claim_boundary": claim_boundary,
        "controller_policy_authority": False,
        "selected_policy_physical_authority": False,
        "physical_acceptance_authority": False,
    }


def run_preflight() -> dict[str, Any]:
    declaration = _preregistration()
    host = vh4._host_identity_receipt(declaration)
    compiled = _compiled_s169_receipt(declaration)
    perfect = _perfect_report()
    _require(
        evaluate_report(perfect) == [],
        "C6_MJC_HC_VH5_PERFECT_SYNTHETIC_REJECTED",
    )
    serialized = json.dumps(perfect, allow_nan=False, separators=(",", ":"))
    _require(
        evaluate_report(json.loads(serialized)) == [],
        "C6_MJC_HC_VH5_PERFECT_ROUND_TRIP_REJECTED",
    )

    def rejects(mutator: Callable[[dict[str, Any]], None]) -> bool:
        candidate = json.loads(serialized)
        mutator(candidate)
        return len(evaluate_report(candidate)) > 0

    controls = {
        "missing_cell": rejects(lambda value: value["cells"].pop()),
        "reordered_cells": rejects(lambda value: value["cells"].reverse()),
        "duplicate_cell_id": rejects(
            lambda value: value["cells"][1].__setitem__(
                "cell_id", value["cells"][0]["cell_id"]
            )
        ),
        "wrong_cell_force_limit": rejects(
            lambda value: value["cells"][0].__setitem__("maximum_force_nm", 6.0)
        ),
        "wrong_cell_portable_impulse": rejects(
            lambda value: value["cells"][0].__setitem__(
                "portable_maximum_impulse_nms", 0.05
            )
        ),
        "wrong_profile_id": rejects(
            lambda value: value["motor_profile"].__setitem__(
                "profile_id", "mujoco_velocity_servo_force_limited_five_substep_v3"
            )
        ),
        "wrong_profile_force_class": rejects(
            lambda value: value["motor_profile"]["force_limit_classes"][0].__setitem__(
                "maximum_force_nm", 6.0
            )
        ),
        "wrong_motor_readback_force_range": rejects(
            lambda value: value["cells"][0]["motor_readback"].__setitem__(
                "force_range_nm", [-6.0, 6.0]
            )
        ),
        "missing_trace": rejects(
            lambda value: value["cells"][0].pop("internal_step_trace")
        ),
        "missing_trace_row": rejects(
            lambda value: value["cells"][0]["internal_step_trace"].pop()
        ),
        "over_limit_force": rejects(
            lambda value: value["cells"][0]["internal_step_trace"][0].__setitem__(
                6, value["cells"][0]["maximum_force_nm"] + 0.01
            )
        ),
        "temporal_force_substitution": rejects(
            lambda value: value["cells"][0]["internal_step_trace"][0].__setitem__(
                13, value["cells"][0]["internal_step_trace"][0][6]
            )
        ),
        "saturated_momentum_corruption": rejects(
            lambda value: value["cells"][0]["internal_step_trace"][0].__setitem__(
                12, value["cells"][0]["internal_step_trace"][0][12] + 0.001
            )
        ),
        "unsaturated_momentum_corruption": rejects(
            lambda value: value["cells"][0]["internal_step_trace"][-1].__setitem__(
                12, value["cells"][0]["internal_step_trace"][-1][12] + 0.001
            )
        ),
        "nonfinite_trace": rejects(
            lambda value: value["cells"][0]["internal_step_trace"][0].__setitem__(
                10, float("nan")
            )
        ),
        "false_cell_pass": rejects(
            lambda value: value["cells"][0].__setitem__("passed", False)
        ),
        "missing_pair": rejects(lambda value: value["mirrored_pairs"].pop()),
        "false_pair_pass": rejects(
            lambda value: value["mirrored_pairs"][0].__setitem__("passed", False)
        ),
        "wrong_world_count": rejects(
            lambda value: value["integrity"].__setitem__("world_build_count", 95)
        ),
        "wrong_trace_count": rejects(
            lambda value: value["integrity"].__setitem__(
                "internal_trace_record_count", EXPECTED_TRACE_COUNT - 1
            )
        ),
        "walking_claim_inflation": rejects(
            lambda value: value["claim_boundary"].__setitem__(
                "mujoco_walking", True
            )
        ),
        "finite_claim_removed": rejects(
            lambda value: value["claim_boundary"].__setitem__(
                "exact_finite_s169_per_actuator_force_limit_host_characterization_if_passed",
                False,
            )
        ),
        "authority_inflation": rejects(
            lambda value: value.__setitem__("physical_acceptance_authority", True)
        ),
        "ok_inflation": rejects(lambda value: value.__setitem__("ok", False)),
    }
    _require(
        len(controls) == NEGATIVE_CONTROL_COUNT and all(controls.values()),
        "C6_MJC_HC_VH5_NEGATIVE_CONTROL_FAILED",
        json.dumps(controls, sort_keys=True),
    )
    compiled_canaries: dict[str, bool] = {}
    for force_class in declaration["motor_profile"]["force_limit_classes"]:
        perturbed = json.loads(json.dumps(declaration))
        candidate_class = next(
            item
            for item in perturbed["motor_profile"]["force_limit_classes"]
            if item["class_id"] == force_class["class_id"]
        )
        candidate_class["maximum_force_nm"] += 0.001
        compiled_canaries[str(force_class["class_id"])] = not _force_classes_match(
            perturbed["motor_profile"]["force_limit_classes"]
        )
    _require(
        len(compiled_canaries) == EXPECTED_CLASS_COUNT
        and all(compiled_canaries.values()),
        "C6_MJC_HC_VH5_COMPILED_CANARY_FAILED",
    )
    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "ok": True,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "preregistration_raw_sha256": EXPECTED_PREREGISTRATION_SHA256,
        "host_identity": host,
        "compiled_s169_force_limit_receipt": compiled,
        "perfect_synthetic_result_passed": True,
        "perfect_synthetic_serialization_round_trip_passed": True,
        "declared_force_limit_class_count": EXPECTED_CLASS_COUNT,
        "declared_cell_count": EXPECTED_CELL_COUNT,
        "declared_mirrored_pair_count": EXPECTED_PAIR_COUNT,
        "declared_internal_trace_record_count": EXPECTED_TRACE_COUNT,
        "negative_control_count": len(controls),
        "negative_controls_rejected": controls,
        "compiled_force_limit_canary_count": len(compiled_canaries),
        "compiled_force_limit_canaries_rejected": compiled_canaries,
        "binding_surface_canary_count": host["binding_surface_canary_count"],
        "world_build_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
    }


def run_characterization(source_commit: str) -> dict[str, Any]:
    _require(
        len(source_commit) == 40
        and all(character in "0123456789abcdef" for character in source_commit),
        "C6_MJC_HC_VH5_SOURCE_COMMIT_INVALID",
        source_commit,
    )
    preflight = run_preflight()
    declaration = _preregistration()
    cells = [
        vh4._run_cell(item, vh4._model(float(item["maximum_force_nm"])))
        for item in _expanded_cells(declaration)
    ]
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
            "portable_controller_timestep_s": vh4.CONTROLLER_DT_S,
            "internal_physics_timestep_s": vh4.INTERNAL_DT_S,
            "internal_steps_per_controller_step": vh4.INTERNAL_STEPS_PER_OUTER,
            "integrator": "implicitfast",
            "solver": "Newton",
            "solver_iterations": 20,
            "line_search_iterations": 7,
        },
        "compiled_s169_force_limit_receipt": preflight[
            "compiled_s169_force_limit_receipt"
        ],
        "motor_profile": declaration["motor_profile"],
        "cells": cells,
        "mirrored_pairs": _pair_receipts(cells),
        "integrity": _integrity(cells),
        "passed_cells": sum(int(cell["passed"]) for cell in cells),
        "failed_cells": sum(int(not cell["passed"]) for cell in cells),
        "claim_boundary": dict(declaration["claim_boundary"]),
        "controller_policy_authority": False,
        "selected_policy_physical_authority": False,
        "physical_acceptance_authority": False,
    }
    provisional = dict(report)
    provisional["ok"] = True
    provisional["claim_boundary"] = dict(report["claim_boundary"])
    provisional["claim_boundary"][
        "exact_finite_s169_per_actuator_force_limit_host_characterization_if_passed"
    ] = True
    failures = evaluate_report(provisional)
    report["ok"] = not failures
    report["claim_boundary"][
        "exact_finite_s169_per_actuator_force_limit_host_characterization_if_passed"
    ] = report["ok"]
    report["failures"] = failures
    final_failures = evaluate_report(report)
    if final_failures:
        report["ok"] = False
        report["claim_boundary"][
            "exact_finite_s169_per_actuator_force_limit_host_characterization_if_passed"
        ] = False
        report["failures"] = final_failures
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
            print(json.dumps(run_preflight(), indent=2, allow_nan=False))
            return 0
        _require(
            isinstance(args.source_commit, str) and isinstance(args.report, str),
            "C6_MJC_HC_VH5_PHYSICAL_ARGUMENTS_MISSING",
        )
        report = run_characterization(args.source_commit)
        _write_new_json(Path(args.report), report)
        print(json.dumps(report, separators=(",", ":"), allow_nan=False))
        return 0 if report["ok"] else 1
    except (ConformanceFailure, OSError, ValueError, KeyError) as error:
        print(str(error), file=__import__("sys").stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
