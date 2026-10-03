"""Prospective MuJoCo MV6 shared-report-assembler restoration successor.

MV6 preserves MV5's complete finite physical hypothesis and fixes only the
implementation-invalid report-authority projection.  The exact report
assembler used after the physical loop is also exercised by the full-horizon
synthetic preflight, against the real MV3 and PH1 closure schemas, before any
MuJoCo model or data object can exist.  A physical result, if authorized by the
external supervisor, remains one exact deterministic technical-commissioning
decision rather than release C6 or cross-engine equivalence.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from dataclasses import dataclass, field
from pathlib import Path
from types import SimpleNamespace
from typing import Any, Callable

import mujoco
import numpy as np

from . import selected_policy_development as bridge
from . import selected_policy_walking_mv3 as mv3


CAMPAIGN_ID = "C6-MUJOCO-BW19V-SELECTED-POLICY-POSE-HOLD-RESTORATION-MV6"
GATE_ID = "C6-MJC-BW19V-MV6"
REPORT_SCHEMA = (
    "sporespore_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_report_v1"
)
TRACE_SCHEMA = (
    "sporespore_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_trace_step_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_preflight_v1"
)

SDK_ROOT = Path(__file__).resolve().parents[3]
PREREGISTRATION_PATH = (
    SDK_ROOT / "mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_preregistration.json"
)
MV3_CLOSURE_PATH = SDK_ROOT / "mujoco_c6_bw19v_selected_policy_walking_mv3_closure.json"
MV5_CLOSURE_PATH = (
    SDK_ROOT / "mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv5_closure.json"
)
MV4_CLOSURE_PATH = (
    SDK_ROOT / "mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv4_closure.json"
)
MV3_IMPLEMENTATION_PATH = (
    SDK_ROOT
    / "adapters"
    / "mujoco"
    / "sporespore_mujoco_adapter"
    / "selected_policy_walking_mv3.py"
)
PH1_CLOSURE_PATH = (
    SDK_ROOT / "rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json"
)
PH1_PREREGISTRATION_PATH = (
    SDK_ROOT / "rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_preregistration.json"
)

EXPECTED_PREREGISTRATION_SHA256 = (
    "sha256:b08ba1a691fa36a06d45f7c33928a0738b2659ade5e1e1a820d0e384816f0956"
)
EXPECTED_MV5_CLOSURE_SHA256 = (
    "sha256:1f0a48bbeda23042196f26db551ef12bce2fd2e1fbc617e84414bdb3d0809329"
)
EXPECTED_MV4_CLOSURE_SHA256 = (
    "sha256:ee8c6805a63adda4c0711e99d2e527b3b9c2a37a8dbea7146a3b67cc033fdd28"
)
EXPECTED_MV3_CLOSURE_SHA256 = (
    "sha256:96e9947628794b9ffdcb1d42f5cfc42b44d89f5f53f7c04007dedf694c8fbf8c"
)
EXPECTED_MV3_IMPLEMENTATION_SHA256 = (
    "sha256:a01cc11c5cb89d90b006b2bf05cee66d119722f0bbc7e1749c22671c8be24078"
)
EXPECTED_PH1_CLOSURE_SHA256 = (
    "sha256:e2fd42545d59908db69f9fe34a18453afafe4273a02618be0b531f6443e040db"
)
EXPECTED_PH1_PREREGISTRATION_SHA256 = (
    "sha256:dd0c7b741fa785d517e88a13921703880c0de7f1e9d0ae28755a307661b016a4"
)
EXPECTED_MV3_SOURCE_COMMIT = "a52af71de64f43b8d742d17d4cf9905b778a134f"
EXPECTED_PH1_PHYSICAL_SOURCE_COMMIT = "91c528e0d0eb494a7ff1d9dc9250ef1af6963249"

TOTAL_STEPS = mv3.TOTAL_STEPS
CLOCKED_STEPS = mv3.CLOCKED_STEPS
EVIDENCE_GAIT_STEPS = mv3.EVIDENCE_GAIT_STEPS
MAXIMUM_EVIDENCE_EXTENSION_STEPS = mv3.MAXIMUM_EVIDENCE_EXTENSION_STEPS
EVIDENCE_DEADLINE_EXCLUSIVE = mv3.EVIDENCE_DEADLINE_EXCLUSIVE
ACTUATOR_COUNT = mv3.ACTUATOR_COUNT
COMMANDS_PER_LAYER = mv3.COMMANDS_PER_LAYER
PROFILE_ID = mv3.PROFILE_ID

RESTORATION_POLICY_ID = (
    "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_v1"
)
DOWNWARD_SPEED_M_S = 0.02
DLS_LAMBDA_M = 0.04
MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S = 0.35
POSE_POSITION_GAIN_PER_S = 8.0
POSE_RATE_DAMPING = 0.65
MAXIMUM_ABSOLUTE_STEERING_FRACTION = 0.4
MAXIMUM_ACQUISITION_STEPS = 180
REQUIRED_CONSECUTIVE_CONTACT_STEPS = 360

SCHEDULER_LIMB_ORDER = ["rear_left", "front_left", "rear_right", "front_right"]
MORPHOLOGY_LIMB_ORDER = ["front_left", "front_right", "rear_left", "rear_right"]


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _digest(value: Any) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _finite(value: Any) -> bool:
    return isinstance(value, (int, float)) and math.isfinite(float(value))


def _close(left: Any, right: Any, tolerance: float = 1.0e-9) -> bool:
    return _finite(left) and _finite(right) and abs(float(left) - float(right)) <= tolerance


def _push(failures: list[str], code: str) -> None:
    if code not in failures:
        failures.append(code)


def _claim_boundary(passed: bool) -> dict[str, bool]:
    return {
        "exact_s169_mujoco_bw19v_mv6_pose_hold_restoration_technical_commissioning": passed,
        "finite_single_body_walking_contract": passed,
        "independent_validation": False,
        "population_inference": False,
        "mujoco_release_selected_policy_physical_c6": False,
        "cross_engine_selected_policy_equivalence": False,
        "arbitrary_quadruped_coverage": False,
        "continuous_morphology_coverage": False,
        "friction_material_or_terrain_robustness": False,
        "rough_terrain_robustness": False,
        "external_push_recovery": False,
        "sensor_noise_or_latency_robustness": False,
        "release_authorized": False,
        "completed_engine_neutral_sdk": False,
        "physical_acceptance_authority": False,
    }


def _authorities() -> dict[str, Any]:
    expected = {
        PREREGISTRATION_PATH: EXPECTED_PREREGISTRATION_SHA256,
        MV5_CLOSURE_PATH: EXPECTED_MV5_CLOSURE_SHA256,
        MV4_CLOSURE_PATH: EXPECTED_MV4_CLOSURE_SHA256,
        MV3_CLOSURE_PATH: EXPECTED_MV3_CLOSURE_SHA256,
        MV3_IMPLEMENTATION_PATH: EXPECTED_MV3_IMPLEMENTATION_SHA256,
        PH1_CLOSURE_PATH: EXPECTED_PH1_CLOSURE_SHA256,
        PH1_PREREGISTRATION_PATH: EXPECTED_PH1_PREREGISTRATION_SHA256,
    }
    for path, digest in expected.items():
        if _raw_sha256(path) != digest:
            raise RuntimeError(f"C6_MJC_BW19V_MV6_AUTHORITY_HASH:{path.name}")
    declaration = json.loads(PREREGISTRATION_PATH.read_text(encoding="utf-8"))
    mv5_closure = json.loads(MV5_CLOSURE_PATH.read_text(encoding="utf-8"))
    mv4_closure = json.loads(MV4_CLOSURE_PATH.read_text(encoding="utf-8"))
    mv3_closure = json.loads(MV3_CLOSURE_PATH.read_text(encoding="utf-8"))
    ph1_closure = json.loads(PH1_CLOSURE_PATH.read_text(encoding="utf-8"))
    ph1_preregistration = json.loads(PH1_PREREGISTRATION_PATH.read_text(encoding="utf-8"))
    if (
        declaration["campaign_id"] != CAMPAIGN_ID
        or declaration["gate_id"] != GATE_ID
        or declaration["implementation_parent_commit"]
        != "067d9062b98a10983c716867fd5275ed0aeec916"
        or mv5_closure["status"]
        != "closed_consumed_implementation_invalid_no_physical_report"
        or mv5_closure["implementation_failure"]["classification"]
        != "post_horizon_report_authority_schema_mismatch"
        or mv5_closure["consumed_attempt"]["report_present"] is not False
        or not mv5_closure["immutability"]["same_identity_rerun_forbidden"]
        or not mv5_closure["next_allowed_work"][
            "use_ph1_physical_source_commit_field_in_a_distinct_successor"
        ]
        or not mv5_closure["next_allowed_work"][
            "factor_and_zero_world_qualify_the_exact_shared_physical_report_assembler"
        ]
        or not mv5_closure["next_allowed_work"][
            "bind_real_mv5_mv4_mv3_and_ph1_closure_schemas_before_world_construction"
        ]
        or mv4_closure["status"]
        != "closed_consumed_implementation_invalid_no_physical_report"
        or mv4_closure["implementation_failure"]["classification"]
        != "terminal_restoration_runtime_vector_representation_mismatch"
        or mv3_closure["status"]
        != "closed_consumed_complete_valid_negative_combined_walking_and_integrity_contract"
        or not mv3_closure["frozen_primary_result"][
            "scientific_negative_for_declared_combined_contract"
        ]
        or not mv3_closure["next_allowed_work"][
            "new_physical_successor_must_address_observed_terminal_front_left_contact_failure"
        ]
        or ph1_closure["status"]
        != "closed_complete_valid_positive_exact_s169_pose_hold_restoration_and_finite_walking_contract"
        or "experiment_source" in ph1_closure
        or ph1_closure.get("physical_source_commit")
        != EXPECTED_PH1_PHYSICAL_SOURCE_COMMIT
        or ph1_preregistration["physical_horizon"]["terminal_restoration_phase"][
            "restoration_policy_id"
        ]
        != RESTORATION_POLICY_ID
        or ph1_preregistration["physical_horizon"]["terminal_restoration_phase"][
            "pose_position_gain_per_s"
        ]
        != POSE_POSITION_GAIN_PER_S
        or ph1_preregistration["physical_horizon"]["terminal_restoration_phase"][
            "pose_rate_damping"
        ]
        != POSE_RATE_DAMPING
    ):
        raise RuntimeError("C6_MJC_BW19V_MV6_AUTHORITY_CONTENT")
    return {
        "declaration": declaration,
        "mv5_closure": mv5_closure,
        "mv4_closure": mv4_closure,
        "mv3_closure": mv3_closure,
        "ph1_closure": ph1_closure,
        "ph1_preregistration": ph1_preregistration,
    }


def _strict_source_commit(value: Any, field_name: str) -> str:
    if (
        not isinstance(value, str)
        or len(value) != 40
        or any(character not in "0123456789abcdef" for character in value)
    ):
        raise RuntimeError(f"C6_MJC_BW19V_MV6_REPORT_AUTHORITY_SCHEMA:{field_name}")
    return value


def _report_authority_projection(authorities: dict[str, Any]) -> dict[str, str]:
    try:
        mv3_commit = _strict_source_commit(
            authorities["mv3_closure"]["experiment_source"]["commit"],
            "mv3_closure.experiment_source.commit",
        )
        ph1_closure = authorities["ph1_closure"]
        if "experiment_source" in ph1_closure:
            raise RuntimeError(
                "C6_MJC_BW19V_MV6_REPORT_AUTHORITY_SCHEMA:"
                "ph1_closure.legacy_experiment_source_forbidden"
            )
        ph1_commit = _strict_source_commit(
            ph1_closure["physical_source_commit"],
            "ph1_closure.physical_source_commit",
        )
    except (KeyError, TypeError) as error:
        raise RuntimeError(
            "C6_MJC_BW19V_MV6_REPORT_AUTHORITY_SCHEMA:missing_or_wrong_shape"
        ) from error
    if mv3_commit != EXPECTED_MV3_SOURCE_COMMIT:
        raise RuntimeError(
            "C6_MJC_BW19V_MV6_REPORT_AUTHORITY_SCHEMA:mv3_source_identity"
        )
    if ph1_commit != EXPECTED_PH1_PHYSICAL_SOURCE_COMMIT:
        raise RuntimeError(
            "C6_MJC_BW19V_MV6_REPORT_AUTHORITY_SCHEMA:ph1_source_identity"
        )
    return {
        "mv3_source_commit": mv3_commit,
        "ph1_source_commit": ph1_commit,
    }


def _assemble_report(
    report: dict[str, Any], authorities: dict[str, Any]
) -> dict[str, Any]:
    """Finalize the exact synthetic and physical report through one path."""

    report.update(_report_authority_projection(authorities))
    failures = _evaluate_core(report)
    report["gate_failures"] = failures
    report["ok"] = not failures
    report["claim_boundary"] = _claim_boundary(report["ok"])
    return report


def _shared_report_assembler_authority_schema_canary(
    authorities: dict[str, Any],
) -> dict[str, Any]:
    projection = _report_authority_projection(authorities)
    candidates: dict[str, dict[str, Any]] = {}

    candidate = copy.deepcopy(authorities)
    candidate["ph1_closure"].pop("physical_source_commit")
    candidates["ph1_missing_physical_source_commit"] = candidate

    candidate = copy.deepcopy(authorities)
    candidate["ph1_closure"].pop("physical_source_commit")
    candidate["ph1_closure"]["experiment_source"] = {
        "commit": EXPECTED_PH1_PHYSICAL_SOURCE_COMMIT
    }
    candidates["ph1_legacy_experiment_source_shape"] = candidate

    candidate = copy.deepcopy(authorities)
    candidate["ph1_closure"]["physical_source_commit"] = "not-a-commit"
    candidates["ph1_malformed_physical_source_commit"] = candidate

    candidate = copy.deepcopy(authorities)
    candidate["ph1_closure"]["physical_source_commit"] = "0" * 40
    candidates["ph1_wrong_physical_source_identity"] = candidate

    candidate = copy.deepcopy(authorities)
    candidate["mv3_closure"].pop("experiment_source")
    candidates["mv3_missing_experiment_source"] = candidate

    candidate = copy.deepcopy(authorities)
    candidate["mv3_closure"]["experiment_source"]["commit"] = "0" * 40
    candidates["mv3_wrong_experiment_source_identity"] = candidate

    rejected: dict[str, bool] = {}
    for name, candidate in candidates.items():
        try:
            # Invalid authority inputs must be rejected by the same assembler
            # that finalizes the physical report, before evaluation is reached.
            _assemble_report({}, candidate)
        except RuntimeError as error:
            rejected[name] = str(error).startswith(
                "C6_MJC_BW19V_MV6_REPORT_AUTHORITY_SCHEMA:"
            )
        else:
            rejected[name] = False

    return {
        "schema_version": (
            "sporespore_mujoco_c6_bw19v_mv6_shared_report_assembler_"
            "authority_schema_canary_v1"
        ),
        "ok": projection
        == {
            "mv3_source_commit": EXPECTED_MV3_SOURCE_COMMIT,
            "ph1_source_commit": EXPECTED_PH1_PHYSICAL_SOURCE_COMMIT,
        }
        and all(rejected.values()),
        "assembler_function": "_assemble_report",
        "real_authority_projection": projection,
        "negative_control_count": len(candidates),
        "negative_controls_rejected": rejected,
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
    }


def _zero_world_state(
    morphology: dict[str, Any], semantic_step: int = 0
) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_state_frame_v1",
        "semantic_step": semantic_step,
        "sample_time_s": semantic_step * bridge.CONTROLLER_DT_S,
        "base_pose_world": {
            "position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
            "orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
        },
        "base_twist_world": {
            "linear_velocity_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
            "angular_velocity_rad_s": {"x": 0.0, "y": 0.0, "z": 0.0},
        },
        "ordered_joint_observations": [
            {
                "joint_id": joint_id,
                "position_rad": 0.0,
                "velocity_rad_s": 0.0,
                "anchor_error_m": 0.0,
                "validity": {
                    "position": True,
                    "velocity": True,
                    "anchor_error": True,
                },
            }
            for joint_id in morphology["ordered_joint_ids"]
        ],
        "ordered_contact_observations": [
            {
                "contact_site_id": site_id,
                "presence": True,
                "bears_support": True,
                "normal_load_n": None,
                "provenance": {
                    "adapter_id": bridge.ADAPTER_ID,
                    "engine_contact_ids": [f"{site_id}_mv6_zero_world"],
                    "aggregation_rule_id": "qualified_bearing_only",
                    "quality": "qualified_bearing",
                },
            }
            for site_id in morphology["ordered_contact_site_ids"]
        ],
        "previous_applied_actuation": None,
        "gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
        "task_frame": {
            "origin_world_m": {"x": 0.0, "y": 0.0, "z": 0.0},
            "forward_axis_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
            "lateral_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
            "up_axis_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
            "reference_yaw_rad": 0.0,
        },
        "adapter_capability_sha256": bridge.capability_manifest_sha256(),
    }


def _zero_world_controller_step() -> dict[str, Any]:
    core = bridge.LocomotionCore()
    descriptor = bridge.s169_descriptor()
    compiled = core.compile_bounded_quadruped(descriptor)
    state = _zero_world_state(compiled["morphology"])
    output = core.balanced_wave_policy_step(
        bridge.SELECTED_POLICY_ID,
        {
            "schema_version": "sporespore_candidate35_step_request_v1",
            "descriptor": descriptor,
            "memory": core.balanced_wave_initial_memory(),
            "state": state,
            "command": {
                **bridge._motion_command(0, "contact_gated"),
                "command_id": "mujoco_mv6_real_shaped_trace_canary",
            },
        },
    )
    return {
        "core": core,
        "descriptor": descriptor,
        "compiled": compiled,
        "state": state,
        "output": output,
    }


def _trace_projection_failures(projection: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    actuation = projection.get("controller_actuation")
    memory = projection.get("ordered_limb_controller_memory_after")
    if not isinstance(actuation, dict):
        return ["controller_actuation"]
    if actuation.get("receipt", {}).get("policy_id") != bridge.SELECTED_POLICY_ID:
        failures.append("nested_policy_id")
    if "source_policy_id" in actuation:
        failures.append("synthetic_top_level_policy_id")
    if actuation.get("semantic_step") != 0 or actuation.get("receipt", {}).get(
        "semantic_step"
    ) != 0:
        failures.append("semantic_step")
    if not isinstance(memory, list):
        return failures + ["limb_memory_type"]
    ids = [item.get("limb_id") for item in memory if isinstance(item, dict)]
    if ids != SCHEDULER_LIMB_ORDER:
        failures.append("scheduler_order")
    if len(ids) != 4 or set(ids) != set(MORPHOLOGY_LIMB_ORDER):
        failures.append("limb_identity_set")
    if len(set(ids)) != len(ids):
        failures.append("duplicate_limb_identity")
    return failures


def _real_controller_trace_projection_canary() -> dict[str, Any]:
    step = _zero_world_controller_step()
    output = step["output"]
    projection = {
        "controller_actuation": output["actuation"],
        "ordered_limb_controller_memory_after": mv3._limb_receipt(
            output["next_memory"]
        ),
    }
    round_trip = json.loads(json.dumps(projection, allow_nan=False))
    controls: dict[str, Callable[[dict[str, Any]], None]] = {
        "missing_nested_policy": lambda value: value["controller_actuation"][
            "receipt"
        ].pop("policy_id"),
        "wrong_nested_policy": lambda value: value["controller_actuation"][
            "receipt"
        ].__setitem__("policy_id", "wrong"),
        "synthetic_top_level_substitution": lambda value: (
            value["controller_actuation"].__setitem__(
                "source_policy_id", bridge.SELECTED_POLICY_ID
            ),
            value["controller_actuation"]["receipt"].pop("policy_id"),
        ),
        "duplicate_limb_identity": lambda value: value[
            "ordered_limb_controller_memory_after"
        ][1].__setitem__("limb_id", "rear_left"),
        "morphology_order_substitution": lambda value: value.__setitem__(
            "ordered_limb_controller_memory_after",
            sorted(
                value["ordered_limb_controller_memory_after"],
                key=lambda item: MORPHOLOGY_LIMB_ORDER.index(item["limb_id"]),
            ),
        ),
    }
    rejected: dict[str, bool] = {}
    for name, mutate in controls.items():
        candidate = copy.deepcopy(projection)
        mutate(candidate)
        rejected[name] = bool(_trace_projection_failures(candidate))
    return {
        "schema_version": "sporespore_mujoco_mv6_real_controller_trace_projection_canary_v1",
        "ok": not _trace_projection_failures(projection)
        and not _trace_projection_failures(round_trip)
        and len(controls) == 5
        and all(rejected.values()),
        "real_release_dynamic_library_step_executed": True,
        "projection": projection,
        "serialization_round_trip_passed": not _trace_projection_failures(round_trip),
        "scheduler_limb_order": SCHEDULER_LIMB_ORDER,
        "morphology_limb_order": MORPHOLOGY_LIMB_ORDER,
        "orders_intentionally_differ": SCHEDULER_LIMB_ORDER != MORPHOLOGY_LIMB_ORDER,
        "negative_control_count": len(controls),
        "negative_controls_rejected": rejected,
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "locomotion_outcome_exposed": False,
        "physical_acceptance_authority": False,
    }


@dataclass
class TerminalRestorationMemory:
    activation_held_steering_fraction: float | None = None
    neutral_joint_position_by_actuator: dict[str, float] = field(default_factory=dict)


def _canonical_vector3(value: Any, field_name: str) -> np.ndarray:
    """Parse the bridge's exact JSON vector representation into x/y/z order."""
    if not isinstance(value, dict) or set(value) != {"x", "y", "z"}:
        raise RuntimeError(f"C6_MJC_BW19V_MV6_VECTOR_SHAPE:{field_name}")
    ordered: list[float] = []
    for component_name in ("x", "y", "z"):
        component = value[component_name]
        if isinstance(component, bool) or not _finite(component):
            raise RuntimeError(
                f"C6_MJC_BW19V_MV6_VECTOR_COMPONENT:{field_name}:{component_name}"
            )
        ordered.append(float(component))
    result = np.asarray(ordered, dtype=np.float64)
    if result.shape != (3,) or not np.all(np.isfinite(result)):
        raise RuntimeError(f"C6_MJC_BW19V_MV6_VECTOR_NORMALIZATION:{field_name}")
    return result


def _production_kinematic_vector_representation_canary() -> dict[str, Any]:
    produced = bridge._vec_json([1.25, -2.5, 3.75])
    normalized = _canonical_vector3(produced, "positive")
    controls: dict[str, Any] = {
        "list_shaped": [1.25, -2.5, 3.75],
        "missing_z": {"x": 1.25, "y": -2.5},
        "extra_field": {"x": 1.25, "y": -2.5, "z": 3.75, "w": 0.0},
        "nonnumeric_x": {"x": "1.25", "y": -2.5, "z": 3.75},
        "nonfinite_z": {"x": 1.25, "y": -2.5, "z": float("inf")},
    }
    rejected: dict[str, bool] = {}
    for name, candidate in controls.items():
        try:
            _canonical_vector3(candidate, name)
            rejected[name] = False
        except RuntimeError:
            rejected[name] = True
    return {
        "schema_version": (
            "sporespore_mujoco_mv6_production_kinematic_vector_representation_canary_v1"
        ),
        "ok": (
            list(produced.keys()) == ["x", "y", "z"]
            and np.array_equal(normalized, np.asarray([1.25, -2.5, 3.75]))
            and len(rejected) == 5
            and all(rejected.values())
        ),
        "producer_module": "selected_policy_development",
        "producer_function": "_vec_json",
        "producer_output": produced,
        "normalized_xyz": normalized.tolist(),
        "negative_control_count": len(rejected),
        "negative_controls_rejected": rejected,
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "locomotion_outcome_exposed": False,
        "physical_acceptance_authority": False,
    }


def _portable_heading_target_delta(
    base_actuation: dict[str, Any],
    command: dict[str, Any],
    limb_id: str,
    joint_id: str,
    activation_held_steering_fraction: float,
) -> dict[str, float | None]:
    if not joint_id.endswith("_hip"):
        return {
            "delta_rad": 0.0,
            "lateral_side_sign": None,
            "forward_velocity_correction_rad": None,
            "nominal_unsteered_hip_target_rad": None,
        }
    receipt = base_actuation["receipt"]
    current_held = float(receipt["held_steering_fraction"])
    if (
        abs(current_held) > MAXIMUM_ABSOLUTE_STEERING_FRACTION
        or abs(activation_held_steering_fraction)
        > MAXIMUM_ABSOLUTE_STEERING_FRACTION
    ):
        raise RuntimeError("C6_MJC_BW19V_MV6_HEADING_STEERING_FRACTION")
    corrections = [
        item
        for item in receipt["forward_velocity_foot_placement"][
            "ordered_limb_corrections"
        ]
        if item["limb_id"] == limb_id
    ]
    if len(corrections) != 1:
        raise RuntimeError(f"C6_MJC_BW19V_MV6_HEADING_LIMB:{limb_id}")
    side_sign = 1.0 if limb_id.endswith("_right") else -1.0
    denominator = 1.0 + side_sign * current_held
    correction = float(corrections[0]["applied_hip_target_correction_rad"])
    nominal = (float(command["requested_target_position_rad"]) - correction) / denominator
    delta = nominal * side_sign * (
        current_held - activation_held_steering_fraction
    )
    if not math.isfinite(nominal) or not math.isfinite(delta):
        raise RuntimeError(f"C6_MJC_BW19V_MV6_HEADING_NONFINITE:{limb_id}")
    return {
        "delta_rad": delta,
        "lateral_side_sign": side_sign,
        "forward_velocity_correction_rad": correction,
        "nominal_unsteered_hip_target_rad": nominal,
    }


def _terminal_restoration_composition(
    robot: Any,
    base_actuation: dict[str, Any],
    state: dict[str, Any],
    pre_step_contacts: dict[str, bool],
    ordered_kinematics: list[dict[str, Any]],
    memory: TerminalRestorationMemory,
) -> dict[str, Any]:
    actuator_ids = list(robot.morphology["ordered_actuator_ids"])
    if [item["actuator_id"] for item in ordered_kinematics] != actuator_ids:
        raise RuntimeError("C6_MJC_BW19V_MV6_RESTORATION_KINEMATIC_ORDER")
    receipt = base_actuation["receipt"]
    current_held = float(receipt["held_steering_fraction"])
    if memory.activation_held_steering_fraction is None:
        memory.activation_held_steering_fraction = current_held
    activation_held = memory.activation_held_steering_fraction
    joint_by_id = {
        item["joint_id"]: item for item in state["ordered_joint_observations"]
    }
    command_by_actuator = {
        item["actuator_id"]: item for item in base_actuation["ordered_commands"]
    }
    actuator_by_id = {
        item["actuator_id"]: item for item in robot.spec["actuators"]
    }
    desired_foot_velocity = np.asarray(
        [0.0, -DOWNWARD_SPEED_M_S, 0.0], dtype=np.float64
    )
    desired_by_actuator: dict[str, float] = {}
    ordered_limb_solutions: list[dict[str, Any]] = []

    for limb in robot.spec["limbs"]:
        if len(limb["ordered_joint_ids"]) != 2 or len(
            limb["ordered_contact_site_ids"]
        ) != 1:
            raise RuntimeError(
                f"C6_MJC_BW19V_MV6_RESTORATION_LIMB_CARDINALITY:{limb['limb_id']}"
            )
        site_id = limb["ordered_contact_site_ids"][0]
        contact = bool(pre_step_contacts[site_id])
        limb_kinematics = [
            item for item in ordered_kinematics if item["contact_site_id"] == site_id
        ]
        if len(limb_kinematics) != 2:
            raise RuntimeError(
                f"C6_MJC_BW19V_MV6_RESTORATION_KINEMATIC_CARDINALITY:{limb['limb_id']}"
            )
        columns = [
            np.cross(
                _canonical_vector3(
                    item["joint_axis_world_unit"], "joint_axis_world_unit"
                ),
                _canonical_vector3(item["endpoint_world_m"], "endpoint_world_m")
                - _canonical_vector3(
                    item["joint_anchor_world_m"], "joint_anchor_world_m"
                ),
            )
            for item in limb_kinematics
        ]
        raw_missing: np.ndarray | None = None
        if not contact:
            jacobian = np.column_stack(columns)
            normal = jacobian.T @ jacobian + (DLS_LAMBDA_M**2) * np.eye(2)
            rhs = jacobian.T @ desired_foot_velocity
            raw_missing = np.linalg.solve(normal, rhs)
            if not np.all(np.isfinite(raw_missing)):
                raise RuntimeError(
                    f"C6_MJC_BW19V_MV6_RESTORATION_DLS_NONFINITE:{limb['limb_id']}"
                )
        actuator_solutions: list[dict[str, Any]] = []
        for index, kinematics in enumerate(limb_kinematics):
            actuator_id = kinematics["actuator_id"]
            actuator = actuator_by_id[actuator_id]
            observation = joint_by_id[actuator["joint_id"]]
            measured_position = float(observation["position_rad"])
            measured_velocity = float(observation["velocity_rad_s"])
            command = command_by_actuator[actuator_id]
            heading = _portable_heading_target_delta(
                base_actuation,
                command,
                limb["limb_id"],
                actuator["joint_id"],
                activation_held,
            )
            if raw_missing is not None:
                memory.neutral_joint_position_by_actuator.pop(actuator_id, None)
                raw_velocity = float(raw_missing[index])
                desired_velocity = float(
                    np.clip(
                        raw_velocity,
                        -MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S,
                        MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S,
                    )
                )
                pose_capture = False
                neutral = requested = clamped = None
            else:
                pose_capture = (
                    actuator_id not in memory.neutral_joint_position_by_actuator
                )
                if pose_capture:
                    memory.neutral_joint_position_by_actuator[actuator_id] = (
                        measured_position - float(heading["delta_rad"])
                    )
                neutral = memory.neutral_joint_position_by_actuator[actuator_id]
                requested = neutral + float(heading["delta_rad"])
                clamped = float(
                    np.clip(
                        requested,
                        float(actuator["minimum_target_position_rad"]),
                        float(actuator["maximum_target_position_rad"]),
                    )
                )
                raw_velocity = POSE_POSITION_GAIN_PER_S * (
                    clamped - measured_position
                ) - POSE_RATE_DAMPING * measured_velocity
                desired_velocity = float(
                    np.clip(
                        raw_velocity,
                        -MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S,
                        MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S,
                    )
                )
            desired_by_actuator[actuator_id] = desired_velocity
            actuator_solutions.append(
                {
                    "actuator_id": actuator_id,
                    "joint_id": actuator["joint_id"],
                    "linear_jacobian_column_world_m": columns[index].tolist(),
                    "kinematics": copy.deepcopy(kinematics),
                    "measured_joint_position_rad": measured_position,
                    "measured_joint_velocity_rad_s": measured_velocity,
                    "minimum_target_position_rad": float(
                        actuator["minimum_target_position_rad"]
                    ),
                    "maximum_target_position_rad": float(
                        actuator["maximum_target_position_rad"]
                    ),
                    "pose_capture_activated": pose_capture,
                    "neutral_joint_position_rad": neutral,
                    "portable_lateral_side_sign": heading["lateral_side_sign"],
                    "portable_forward_velocity_hip_target_correction_rad": heading[
                        "forward_velocity_correction_rad"
                    ],
                    "portable_nominal_unsteered_hip_target_rad": heading[
                        "nominal_unsteered_hip_target_rad"
                    ],
                    "portable_heading_target_delta_rad": heading["delta_rad"],
                    "requested_pose_target_position_rad": requested,
                    "clamped_pose_target_position_rad": clamped,
                    "unbounded_joint_velocity_rad_s": raw_velocity,
                    "desired_joint_velocity_rad_s": desired_velocity,
                }
            )
        ordered_limb_solutions.append(
            {
                "limb_id": limb["limb_id"],
                "contact_site_id": site_id,
                "pre_step_contact": contact,
                "desired_foot_velocity_world_m_s": (
                    [0.0, 0.0, 0.0]
                    if contact
                    else desired_foot_velocity.tolist()
                ),
                "ordered_actuator_solutions": actuator_solutions,
            }
        )

    residuals = [
        {
            "schema_version": "sporespore_canonical_velocity_residual_v1",
            "actuator_id": command["actuator_id"],
            "canonical_velocity_delta_rad_s": desired_by_actuator[
                command["actuator_id"]
            ]
            - (-float(command["target_velocity_rad_s"])),
            "command_not_measurement": True,
            "physical_acceptance_authority": False,
        }
        for command in base_actuation["ordered_commands"]
    ]
    canonical = robot.core.canonical_velocity_compose_v1(
        {
            "schema_version": "sporespore_canonical_velocity_compose_request_v1",
            "descriptor": robot.descriptor,
            "source_actuation": base_actuation,
            "ordered_stability_residuals": residuals,
        }
    )
    host = robot.core.canonical_velocity_host_map_v1(
        {
            "schema_version": "sporespore_canonical_velocity_host_map_request_v1",
            "descriptor": robot.descriptor,
            "canonical_actuation": canonical,
            "host_profile": bridge._mujoco_host_profile(PROFILE_ID),
        }
    )
    for canonical_command, host_command in zip(
        canonical["ordered_commands"], host["ordered_commands"], strict=True
    ):
        desired = desired_by_actuator[canonical_command["actuator_id"]]
        if (
            not _close(
                canonical_command["combined_canonical_target_velocity_rad_s"],
                desired,
                1.0e-12,
            )
            or not _close(host_command["host_target_velocity_rad_s"], desired, 1.0e-12)
            or host_command["native_target_position_rad"] is not None
        ):
            raise RuntimeError(
                f"C6_MJC_BW19V_MV6_RESTORATION_MAPPING:{canonical_command['actuator_id']}"
            )
    terminal_receipt = {
        "schema_version": (
            "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_receipt_v1"
        ),
        "semantic_step": int(base_actuation["semantic_step"]),
        "policy_id": RESTORATION_POLICY_ID,
        "missing_limb_desired_foot_velocity_world_m_s": [
            0.0,
            -DOWNWARD_SPEED_M_S,
            0.0,
        ],
        "contacting_limb_target_joint_velocity_mode": (
            "captured_pose_proportional_derivative_velocity_v1"
        ),
        "pose_hold_position_gain_per_s": POSE_POSITION_GAIN_PER_S,
        "pose_hold_rate_damping": POSE_RATE_DAMPING,
        "maximum_absolute_pose_hold_joint_velocity_rad_s": (
            MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S
        ),
        "heading_correction_mode": (
            "registered_portable_yaw_only_hip_target_delta_from_activation_v1"
        ),
        "activation_held_steering_fraction": activation_held,
        "current_held_steering_fraction": current_held,
        "registered_steering_stride_transform_id": None,
        "damped_least_squares_lambda_m": DLS_LAMBDA_M,
        "maximum_absolute_search_joint_velocity_rad_s": (
            MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S
        ),
        "ordered_limb_solutions": ordered_limb_solutions,
        "pose_memory_actuator_count": len(
            memory.neutral_joint_position_by_actuator
        ),
        "world_build_count": 0,
        "physics_state_modified": False,
        "command_not_measurement": True,
        "physical_acceptance_authority": False,
    }
    bounded = [
        {
            "actuator_id": item["actuator_id"],
            "applied_velocity_delta_rad_s": float(
                item["canonical_velocity_delta_rad_s"]
            ),
        }
        for item in residuals
    ]
    return {
        "canonical_actuation": canonical,
        "host_mapping": host,
        "ordered_bounded_canonical_residuals": bounded,
        "terminal_receipt": terminal_receipt,
    }


def _terminal_receipt_failures(
    receipt: dict[str, Any],
    canonical: dict[str, Any] | None = None,
    host: dict[str, Any] | None = None,
) -> list[str]:
    failures: list[str] = []
    expected_static = {
        "schema_version": (
            "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_receipt_v1"
        ),
        "policy_id": RESTORATION_POLICY_ID,
        "missing_limb_desired_foot_velocity_world_m_s": [0.0, -0.02, 0.0],
        "contacting_limb_target_joint_velocity_mode": (
            "captured_pose_proportional_derivative_velocity_v1"
        ),
        "pose_hold_position_gain_per_s": POSE_POSITION_GAIN_PER_S,
        "pose_hold_rate_damping": POSE_RATE_DAMPING,
        "maximum_absolute_pose_hold_joint_velocity_rad_s": 0.35,
        "heading_correction_mode": (
            "registered_portable_yaw_only_hip_target_delta_from_activation_v1"
        ),
        "registered_steering_stride_transform_id": None,
        "damped_least_squares_lambda_m": DLS_LAMBDA_M,
        "maximum_absolute_search_joint_velocity_rad_s": 0.35,
        "world_build_count": 0,
        "physics_state_modified": False,
        "command_not_measurement": True,
        "physical_acceptance_authority": False,
    }
    for key, expected in expected_static.items():
        if receipt.get(key) != expected:
            _push(failures, f"terminal_static:{key}")
    limbs = receipt.get("ordered_limb_solutions")
    if not isinstance(limbs, list) or len(limbs) != 4:
        return failures + ["terminal_limb_cardinality"]
    limb_ids = [limb.get("limb_id") for limb in limbs]
    if limb_ids != MORPHOLOGY_LIMB_ORDER or len(set(limb_ids)) != 4:
        _push(failures, "terminal_limb_identity_order")
    activation_held = receipt.get("activation_held_steering_fraction")
    current_held = receipt.get("current_held_steering_fraction")
    heading_fractions_valid = (
        _finite(activation_held)
        and _finite(current_held)
        and abs(float(activation_held)) <= MAXIMUM_ABSOLUTE_STEERING_FRACTION
        and abs(float(current_held)) <= MAXIMUM_ABSOLUTE_STEERING_FRACTION
    )
    if not heading_fractions_valid:
        _push(failures, "terminal_heading_fraction")
    desired_by_actuator: dict[str, float] = {}
    for limb in limbs:
        limb_id = limb.get("limb_id")
        if (
            limb_id not in MORPHOLOGY_LIMB_ORDER
            or limb.get("contact_site_id") != f"{limb_id}_foot"
            or not isinstance(limb.get("pre_step_contact"), bool)
        ):
            _push(failures, f"terminal_limb_semantics:{limb_id}")
        solutions = limb.get("ordered_actuator_solutions")
        if not isinstance(solutions, list) or len(solutions) != 2:
            _push(failures, f"terminal_actuator_cardinality:{limb_id}")
            continue
        contact = limb.get("pre_step_contact") is True
        expected_foot_velocity = (
            [0.0, 0.0, 0.0]
            if contact
            else expected_static["missing_limb_desired_foot_velocity_world_m_s"]
        )
        if limb.get("desired_foot_velocity_world_m_s") != expected_foot_velocity:
            _push(failures, f"terminal_foot_velocity:{limb_id}")
        normalized_solution_ids = [
            solution.get("actuator_id", "").removesuffix("_motor")
            if isinstance(solution.get("actuator_id"), str)
            else None
            for solution in solutions
        ]
        if normalized_solution_ids != [f"{limb_id}_hip", f"{limb_id}_knee"]:
            _push(failures, f"terminal_limb_actuator_identity:{limb_id}")
        for solution in solutions:
            actuator_id = solution.get("actuator_id")
            desired = solution.get("desired_joint_velocity_rad_s")
            raw = solution.get("unbounded_joint_velocity_rad_s")
            if not isinstance(actuator_id, str) or not _finite(desired) or not _finite(raw):
                _push(failures, "terminal_solution_numeric")
                continue
            if abs(float(desired)) > 0.35 + 1.0e-12:
                _push(failures, f"terminal_solution_bound:{actuator_id}")
            normalized_actuator_id = actuator_id.removesuffix("_motor")
            side = solution.get("portable_lateral_side_sign")
            correction = solution.get(
                "portable_forward_velocity_hip_target_correction_rad"
            )
            nominal = solution.get("portable_nominal_unsteered_hip_target_rad")
            delta = solution.get("portable_heading_target_delta_rad")
            if normalized_actuator_id.endswith("_hip"):
                expected_side = 1.0 if limb_id.endswith("_right") else -1.0
                if not all(
                    _finite(value) for value in [side, correction, nominal, delta]
                ):
                    _push(failures, f"terminal_heading_numeric:{actuator_id}")
                elif heading_fractions_valid:
                    expected_delta = float(nominal) * expected_side * (
                        float(current_held) - float(activation_held)
                    )
                    if not _close(side, expected_side) or not _close(
                        delta, expected_delta
                    ):
                        _push(failures, f"terminal_heading_recompute:{actuator_id}")
            elif (
                side is not None
                or correction is not None
                or nominal is not None
                or not _close(delta, 0.0)
            ):
                _push(failures, f"terminal_nonhip_heading:{actuator_id}")
            if contact:
                requested = solution.get("requested_pose_target_position_rad")
                neutral = solution.get("neutral_joint_position_rad")
                clamped = solution.get("clamped_pose_target_position_rad")
                measured = solution.get("measured_joint_position_rad")
                velocity = solution.get("measured_joint_velocity_rad_s")
                minimum = solution.get("minimum_target_position_rad")
                maximum = solution.get("maximum_target_position_rad")
                values = [requested, neutral, delta, clamped, measured, velocity, minimum, maximum]
                if not all(_finite(value) for value in values):
                    _push(failures, f"terminal_pose_numeric:{actuator_id}")
                else:
                    expected_requested = float(neutral) + float(delta)
                    expected_clamped = float(
                        np.clip(float(requested), float(minimum), float(maximum))
                    )
                    expected_raw = POSE_POSITION_GAIN_PER_S * (
                        expected_clamped - float(measured)
                    ) - POSE_RATE_DAMPING * float(velocity)
                    expected_desired = float(np.clip(expected_raw, -0.35, 0.35))
                    if (
                        not _close(requested, expected_requested)
                        or not _close(clamped, expected_clamped)
                        or not _close(raw, expected_raw)
                        or not _close(desired, expected_desired)
                    ):
                        _push(failures, f"terminal_pose_recompute:{actuator_id}")
            elif (
                solution.get("pose_capture_activated") is not False
                or solution.get("neutral_joint_position_rad") is not None
                or solution.get("requested_pose_target_position_rad") is not None
                or solution.get("clamped_pose_target_position_rad") is not None
            ):
                _push(failures, f"terminal_missing_limb_pose_state:{actuator_id}")
            if actuator_id in desired_by_actuator:
                _push(failures, f"terminal_duplicate_actuator:{actuator_id}")
            desired_by_actuator[actuator_id] = float(desired)
        if not contact:
            columns = [
                solution.get("linear_jacobian_column_world_m")
                for solution in solutions
            ]
            if not all(
                isinstance(column, list)
                and len(column) == 3
                and all(_finite(value) for value in column)
                for column in columns
            ):
                _push(failures, f"terminal_dls_columns:{limb_id}")
            else:
                jacobian = np.column_stack(
                    [np.asarray(column, dtype=np.float64) for column in columns]
                )
                normal = jacobian.T @ jacobian + (DLS_LAMBDA_M**2) * np.eye(2)
                rhs = jacobian.T @ np.asarray(expected_foot_velocity, dtype=np.float64)
                expected_raw = np.linalg.solve(normal, rhs)
                for index, solution in enumerate(solutions):
                    expected_desired = float(
                        np.clip(
                            expected_raw[index],
                            -MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S,
                            MAXIMUM_RESTORATION_JOINT_SPEED_RAD_S,
                        )
                    )
                    if not _close(
                        solution.get("unbounded_joint_velocity_rad_s"),
                        expected_raw[index],
                    ) or not _close(
                        solution.get("desired_joint_velocity_rad_s"),
                        expected_desired,
                    ):
                        _push(
                            failures,
                            f"terminal_dls_recompute:{solution.get('actuator_id')}",
                        )
    expected_pose_memory_count = 2 * sum(
        limb.get("pre_step_contact") is True for limb in limbs
    )
    if receipt.get("pose_memory_actuator_count") != expected_pose_memory_count:
        _push(failures, "terminal_pose_memory_count")
    normalized_actuator_ids = {
        actuator_id.removesuffix("_motor") for actuator_id in desired_by_actuator
    }
    if normalized_actuator_ids != {
        "front_left_hip",
        "front_left_knee",
        "front_right_hip",
        "front_right_knee",
        "rear_left_hip",
        "rear_left_knee",
        "rear_right_hip",
        "rear_right_knee",
    }:
        _push(failures, "terminal_actuator_identity_set")
    if canonical is not None and host is not None:
        canonical_by_id = {
            item["actuator_id"]: item for item in canonical.get("ordered_commands", [])
        }
        host_by_id = {
            item["actuator_id"]: item for item in host.get("ordered_commands", [])
        }
        for actuator_id, desired in desired_by_actuator.items():
            if (
                actuator_id not in canonical_by_id
                or actuator_id not in host_by_id
                or not _close(
                    canonical_by_id[actuator_id].get(
                        "combined_canonical_target_velocity_rad_s"
                    ),
                    desired,
                    1.0e-12,
                )
                or not _close(
                    host_by_id[actuator_id].get("host_target_velocity_rad_s"),
                    desired,
                    1.0e-12,
                )
                or host_by_id[actuator_id].get("native_target_position_rad") is not None
            ):
                _push(failures, f"terminal_mapping:{actuator_id}")
    return failures


def _terminal_pose_memory_transition_failures(
    receipt: dict[str, Any],
    neutral_by_actuator: dict[str, float],
) -> list[str]:
    """Replay the stateful capture/clear/recapture contract from receipts."""
    failures: list[str] = []
    limbs = receipt.get("ordered_limb_solutions")
    if not isinstance(limbs, list):
        return ["terminal_pose_memory_limb_shape"]
    for limb in limbs:
        contact = limb.get("pre_step_contact") is True
        solutions = limb.get("ordered_actuator_solutions")
        if not isinstance(solutions, list):
            _push(failures, f"terminal_pose_memory_solution_shape:{limb.get('limb_id')}")
            continue
        for solution in solutions:
            actuator_id = solution.get("actuator_id")
            if not isinstance(actuator_id, str):
                _push(failures, "terminal_pose_memory_actuator_identity")
                continue
            capture = solution.get("pose_capture_activated")
            neutral = solution.get("neutral_joint_position_rad")
            if not contact:
                neutral_by_actuator.pop(actuator_id, None)
                if capture is not False or neutral is not None:
                    _push(failures, f"terminal_pose_memory_not_cleared:{actuator_id}")
                continue
            measured = solution.get("measured_joint_position_rad")
            delta = solution.get("portable_heading_target_delta_rad")
            if not _finite(neutral) or not _finite(measured) or not _finite(delta):
                _push(failures, f"terminal_pose_memory_numeric:{actuator_id}")
                continue
            if actuator_id not in neutral_by_actuator:
                expected_neutral = float(measured) - float(delta)
                if capture is not True or not _close(neutral, expected_neutral):
                    _push(failures, f"terminal_pose_memory_capture:{actuator_id}")
            elif capture is not False or not _close(
                neutral, neutral_by_actuator[actuator_id]
            ):
                _push(failures, f"terminal_pose_memory_continuity:{actuator_id}")
            neutral_by_actuator[actuator_id] = float(neutral)
    return failures


def _zero_world_terminal_restoration_canary() -> dict[str, Any]:
    step = _zero_world_controller_step()
    compiled = step["compiled"]
    morphology = compiled["morphology"]
    spec = morphology["morphology_spec"]
    limb_by_joint = {
        joint_id: limb
        for limb in spec["limbs"]
        for joint_id in limb["ordered_joint_ids"]
    }
    joint_by_id = {item["joint_id"]: item for item in spec["joints"]}
    actuator_by_id = {item["actuator_id"]: item for item in spec["actuators"]}
    kinematics: list[dict[str, Any]] = []
    for actuator_id in morphology["ordered_actuator_ids"]:
        actuator = actuator_by_id[actuator_id]
        limb = limb_by_joint[actuator["joint_id"]]
        joint_index = limb["ordered_joint_ids"].index(actuator["joint_id"])
        kinematics.append(
            {
                "actuator_id": actuator_id,
                "contact_site_id": limb["ordered_contact_site_ids"][0],
                "joint_anchor_world_m": bridge._vec_json(
                    [0.1 * joint_index, 0.0, 0.0]
                ),
                "joint_axis_world_unit": bridge._vec_json([0.0, 0.0, 1.0]),
                "endpoint_world_m": bridge._vec_json([0.2, -0.2, 0.0]),
                "joint_id": joint_by_id[actuator["joint_id"]]["joint_id"],
            }
        )
    fixture = SimpleNamespace(
        core=step["core"],
        descriptor=step["descriptor"],
        morphology=morphology,
        spec=spec,
        profile_id=PROFILE_ID,
    )
    contacts = {site_id: True for site_id in morphology["ordered_contact_site_ids"]}
    contacts["front_left_foot"] = False
    restoration_memory = TerminalRestorationMemory()
    composition = _terminal_restoration_composition(
        fixture,
        step["output"]["actuation"],
        step["state"],
        contacts,
        kinematics,
        restoration_memory,
    )
    receipt = composition["terminal_receipt"]
    all_contacts = {
        site_id: True for site_id in morphology["ordered_contact_site_ids"]
    }
    recontact_composition = _terminal_restoration_composition(
        fixture,
        step["output"]["actuation"],
        step["state"],
        all_contacts,
        kinematics,
        restoration_memory,
    )
    held_composition = _terminal_restoration_composition(
        fixture,
        step["output"]["actuation"],
        step["state"],
        all_contacts,
        kinematics,
        restoration_memory,
    )
    compositions = [composition, recontact_composition, held_composition]
    base_failures: list[str] = []
    transition_memory: dict[str, float] = {}
    for candidate in compositions:
        base_failures.extend(
            _terminal_receipt_failures(
                candidate["terminal_receipt"],
                candidate["canonical_actuation"],
                candidate["host_mapping"],
            )
        )
        base_failures.extend(
            _terminal_pose_memory_transition_failures(
                candidate["terminal_receipt"], transition_memory
            )
        )
    controls: dict[str, Callable[[dict[str, Any]], None]] = {
        "wrong_policy": lambda value: value.__setitem__("policy_id", "wrong"),
        "wrong_lambda": lambda value: value.__setitem__(
            "damped_least_squares_lambda_m", 0.05
        ),
        "wrong_dls_solution": lambda value: value["ordered_limb_solutions"][0][
            "ordered_actuator_solutions"
        ][0].__setitem__("unbounded_joint_velocity_rad_s", 0.01),
        "wrong_heading_delta": lambda value: value["ordered_limb_solutions"][1][
            "ordered_actuator_solutions"
        ][0].__setitem__("portable_heading_target_delta_rad", 0.01),
    }
    rejected: dict[str, bool] = {}
    for name, mutate in controls.items():
        candidate = copy.deepcopy(receipt)
        mutate(candidate)
        rejected[name] = bool(_terminal_receipt_failures(candidate))
    discontinuous = copy.deepcopy(held_composition["terminal_receipt"])
    discontinuous["ordered_limb_solutions"][1]["ordered_actuator_solutions"][
        0
    ].__setitem__("pose_capture_activated", True)
    discontinuous_memory: dict[str, float] = {}
    discontinuity_failures: list[str] = []
    for candidate in [
        receipt,
        recontact_composition["terminal_receipt"],
        discontinuous,
    ]:
        discontinuity_failures.extend(
            _terminal_pose_memory_transition_failures(
                candidate, discontinuous_memory
            )
        )
    rejected["wrong_pose_memory_transition"] = bool(discontinuity_failures)
    missing_limbs = [
        limb["limb_id"]
        for limb in receipt["ordered_limb_solutions"]
        if limb["pre_step_contact"] is False
    ]
    return {
        "schema_version": "sporespore_mujoco_mv6_engine_neutral_terminal_restoration_canary_v1",
        "ok": not base_failures and len(rejected) == 5 and all(rejected.values()),
        "restoration_policy_id": RESTORATION_POLICY_ID,
        "missing_limb_ids": missing_limbs,
        "receipt": receipt,
        "canonical_actuation": composition["canonical_actuation"],
        "host_mapping": composition["host_mapping"],
        "pose_memory_transition_receipt_count": len(compositions),
        "pose_memory_transition_passed": not base_failures,
        "negative_control_count": len(rejected),
        "negative_controls_rejected": rejected,
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "locomotion_outcome_exposed": False,
        "physical_acceptance_authority": False,
    }


def _synthetic_terminal_receipt(
    semantic_step: int,
    actuator_ids: list[str],
    pose_capture: bool,
) -> dict[str, Any]:
    limbs: list[dict[str, Any]] = []
    for limb_id in MORPHOLOGY_LIMB_ORDER:
        solutions = []
        for actuator_id in [
            item for item in actuator_ids if item.startswith(f"{limb_id}_")
        ]:
            joint_id = actuator_id
            is_hip = actuator_id.endswith("_hip")
            solutions.append(
                {
                    "actuator_id": actuator_id,
                    "joint_id": joint_id,
                    "linear_jacobian_column_world_m": [0.2, 0.2, 0.0],
                    "kinematics": {
                        "actuator_id": actuator_id,
                        "contact_site_id": f"{limb_id}_foot",
                        "joint_anchor_world_m": bridge._vec_json([0.0, 0.0, 0.0]),
                        "joint_axis_world_unit": bridge._vec_json([0.0, 0.0, 1.0]),
                        "endpoint_world_m": bridge._vec_json([0.2, -0.2, 0.0]),
                    },
                    "measured_joint_position_rad": 0.0,
                    "measured_joint_velocity_rad_s": 0.0,
                    "minimum_target_position_rad": -1.0,
                    "maximum_target_position_rad": 1.0,
                    "pose_capture_activated": pose_capture,
                    "neutral_joint_position_rad": 0.0,
                    "portable_lateral_side_sign": (
                        (1.0 if limb_id.endswith("_right") else -1.0)
                        if is_hip
                        else None
                    ),
                    "portable_forward_velocity_hip_target_correction_rad": (
                        0.0 if is_hip else None
                    ),
                    "portable_nominal_unsteered_hip_target_rad": (
                        0.0 if is_hip else None
                    ),
                    "portable_heading_target_delta_rad": 0.0,
                    "requested_pose_target_position_rad": 0.0,
                    "clamped_pose_target_position_rad": 0.0,
                    "unbounded_joint_velocity_rad_s": 0.0,
                    "desired_joint_velocity_rad_s": 0.0,
                }
            )
        limbs.append(
            {
                "limb_id": limb_id,
                "contact_site_id": f"{limb_id}_foot",
                "pre_step_contact": True,
                "desired_foot_velocity_world_m_s": [0.0, 0.0, 0.0],
                "ordered_actuator_solutions": solutions,
            }
        )
    return {
        "schema_version": (
            "sporespore_contact_state_gated_pose_hold_heading_preserving_vertical_search_receipt_v1"
        ),
        "semantic_step": semantic_step,
        "policy_id": RESTORATION_POLICY_ID,
        "missing_limb_desired_foot_velocity_world_m_s": [0.0, -0.02, 0.0],
        "contacting_limb_target_joint_velocity_mode": (
            "captured_pose_proportional_derivative_velocity_v1"
        ),
        "pose_hold_position_gain_per_s": 8.0,
        "pose_hold_rate_damping": 0.65,
        "maximum_absolute_pose_hold_joint_velocity_rad_s": 0.35,
        "heading_correction_mode": (
            "registered_portable_yaw_only_hip_target_delta_from_activation_v1"
        ),
        "activation_held_steering_fraction": 0.0,
        "current_held_steering_fraction": 0.0,
        "registered_steering_stride_transform_id": None,
        "damped_least_squares_lambda_m": 0.04,
        "maximum_absolute_search_joint_velocity_rad_s": 0.35,
        "ordered_limb_solutions": limbs,
        "pose_memory_actuator_count": 8,
        "world_build_count": 0,
        "physics_state_modified": False,
        "command_not_measurement": True,
        "physical_acceptance_authority": False,
    }


def _perfect_report(
    profile_canary: dict[str, Any],
    morphology_canary: dict[str, Any],
    trace_canary: dict[str, Any],
    restoration_canary: dict[str, Any],
    vector_canary: dict[str, Any],
    assembler_canary: dict[str, Any],
    authorities: dict[str, Any],
) -> dict[str, Any]:
    report = mv3._perfect_report(profile_canary, morphology_canary)
    report.update(
        {
            "schema_version": REPORT_SCHEMA,
            "campaign_id": CAMPAIGN_ID,
            "gate_id": GATE_ID,
            "preregistration_raw_sha256": EXPECTED_PREREGISTRATION_SHA256,
            "mv5_closure_raw_sha256": EXPECTED_MV5_CLOSURE_SHA256,
            "mv4_closure_raw_sha256": EXPECTED_MV4_CLOSURE_SHA256,
            "mv3_closure_raw_sha256": EXPECTED_MV3_CLOSURE_SHA256,
            "ph1_closure_raw_sha256": EXPECTED_PH1_CLOSURE_SHA256,
            "preworld_real_controller_trace_projection_canary": trace_canary,
            "preworld_engine_neutral_terminal_restoration_canary": (
                restoration_canary
            ),
            "preworld_production_kinematic_vector_representation_canary": (
                vector_canary
            ),
            "preworld_shared_report_assembler_authority_schema_canary": (
                assembler_canary
            ),
        }
    )
    report.pop("mv2_closure_raw_sha256", None)
    actuator_ids = list(report["ordered_actuator_ids"])
    evidence_completion = int(
        report["schedule"]["evidence_completion_semantic_step"]
    )
    first_contact = evidence_completion + 1
    hold_completion = first_contact + REQUIRED_CONSECUTIVE_CONTACT_STEPS - 1
    for row in report["ordered_trace"]:
        step = int(row["semantic_step"])
        row["schema_version"] = TRACE_SCHEMA
        old_controller = row["receipt_payload"]["controller_actuation"]
        row["receipt_payload"]["controller_actuation"] = {
            "schema_version": "sporespore_actuation_frame_v1",
            "semantic_step": step,
            "ordered_commands": old_controller["ordered_commands"],
            "safe_no_actuation": False,
            "failure_codes": [],
            "receipt": {
                "schema_version": "sporespore_controller_step_receipt_v5",
                "policy_id": bridge.SELECTED_POLICY_ID,
                "semantic_step": step,
                "held_steering_fraction": 0.0,
                "forward_velocity_foot_placement": {
                    "ordered_limb_corrections": [
                        {
                            "limb_id": limb_id,
                            "applied_hip_target_correction_rad": 0.0,
                        }
                        for limb_id in MORPHOLOGY_LIMB_ORDER
                    ]
                },
                "controller_error": None,
            },
        }
        memory_by_id = {
            item["limb_id"]: item
            for item in row["ordered_limb_controller_memory_after"]
        }
        row["ordered_limb_controller_memory_after"] = [
            memory_by_id[limb_id] for limb_id in SCHEDULER_LIMB_ORDER
        ]
        row["ordered_pre_step_joint_position_velocity_observations"] = [
            {
                "joint_id": actuator_id,
                "position_rad": 0.0,
                "velocity_rad_s": 0.0,
            }
            for actuator_id in actuator_ids
        ]
        row["campaign_phase"] = (
            "clocked_walking"
            if step < CLOCKED_STEPS
            else (
                "evidence_walking"
                if step <= evidence_completion
                else (
                    "terminal_acquisition"
                    if step <= hold_completion
                    else "terminal_hold"
                )
            )
        )
        if step > evidence_completion:
            terminal_receipt = _synthetic_terminal_receipt(
                step, actuator_ids, step == first_contact
            )
            for index, actuator_id in enumerate(actuator_ids):
                base_velocity = 0.1 + index * 0.001
                row["ordered_bounded_canonical_residuals"][index][
                    "applied_velocity_delta_rad_s"
                ] = -base_velocity
                row["ordered_canonical_commands"][index][
                    "stability_canonical_velocity_delta_rad_s"
                ] = -base_velocity
                row["ordered_canonical_commands"][index][
                    "combined_canonical_target_velocity_rad_s"
                ] = 0.0
                row["ordered_host_commands"][index]["host_target_velocity_rad_s"] = 0.0
                row["ordered_native_applications"][index][
                    "target_velocity_rad_s"
                ] = 0.0
            row["receipt_payload"]["scheduled_load_transfer"] = terminal_receipt
            row["receipt_payload"]["endpoint_mapping"] = {
                "mode": "terminal_pose_hold_restoration_v1"
            }
            row["receipt_payload"]["stability_influence"] = {
                "ordered_applied_corrections": copy.deepcopy(
                    row["ordered_bounded_canonical_residuals"]
                )
            }
            row["receipt_payload"]["canonical_actuation"] = {
                "ordered_commands": copy.deepcopy(row["ordered_canonical_commands"])
            }
            row["receipt_payload"]["host_mapping"] = {
                "host_profile_id": PROFILE_ID,
                "host_response_characterized_for_this_profile": True,
                "ordered_commands": copy.deepcopy(row["ordered_host_commands"]),
            }
            row["command_composition"] = {
                "mode": "terminal_pose_hold_restoration_v1",
                "receipt": terminal_receipt,
                "receipt_sha256": _digest(terminal_receipt),
            }
        else:
            row["command_composition"] = {"mode": "walking_v4"}
        row["receipt_payload_sha256"] = _digest(row["receipt_payload"])
    report["schedule"]["terminal_restoration_phase"] = {
        "restoration_policy_id": RESTORATION_POLICY_ID,
        "activation_semantic_step": first_contact,
        "maximum_four_contact_acquisition_steps_after_evidence_completion": 180,
        "first_four_contact_acquisition_semantic_step": first_contact,
        "required_consecutive_all_four_contact_steps": 360,
        "consecutive_four_contact_completion_semantic_step": hold_completion,
        "maximum_consecutive_four_contact_steps": TOTAL_STEPS - first_contact,
        "required_consecutive_hold_completed": True,
    }
    return _assemble_report(report, authorities)


def _project_for_mv3(report: dict[str, Any]) -> dict[str, Any]:
    proxy = copy.deepcopy(report)
    proxy.update(
        {
            "schema_version": mv3.REPORT_SCHEMA,
            "campaign_id": mv3.CAMPAIGN_ID,
            "gate_id": mv3.GATE_ID,
            "preregistration_raw_sha256": mv3.EXPECTED_PREREGISTRATION_SHA256,
            "mv2_closure_raw_sha256": mv3.EXPECTED_MV2_CLOSURE_SHA256,
        }
    )
    proxy.pop("mv3_closure_raw_sha256", None)
    proxy.pop("mv5_closure_raw_sha256", None)
    proxy.pop("mv4_closure_raw_sha256", None)
    proxy.pop("ph1_closure_raw_sha256", None)
    proxy.pop("preworld_shared_report_assembler_authority_schema_canary", None)
    for row in proxy.get("ordered_trace", []):
        row["schema_version"] = mv3.TRACE_SCHEMA
        controller = row["receipt_payload"]["controller_actuation"]
        row["receipt_payload"]["controller_actuation"] = {
            "semantic_step": row["semantic_step"],
            "source_policy_id": controller.get("receipt", {}).get(
                "policy_id", "__missing_policy_id__"
            ),
            "ordered_commands": copy.deepcopy(row["ordered_portable_base_commands"]),
        }
        memory_by_id = {
            item["limb_id"]: item
            for item in row["ordered_limb_controller_memory_after"]
        }
        if all(limb_id in memory_by_id for limb_id in proxy["ordered_limb_ids"]):
            row["ordered_limb_controller_memory_after"] = [
                memory_by_id[limb_id] for limb_id in proxy["ordered_limb_ids"]
            ]
        row["receipt_payload_sha256"] = _digest(row["receipt_payload"])
    proxy["claim_boundary"] = mv3._claim_boundary(bool(proxy.get("ok")))
    return proxy


def _specific_failures(report: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    expected = {
        "schema_version": REPORT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "preregistration_raw_sha256": EXPECTED_PREREGISTRATION_SHA256,
        "mv5_closure_raw_sha256": EXPECTED_MV5_CLOSURE_SHA256,
        "mv4_closure_raw_sha256": EXPECTED_MV4_CLOSURE_SHA256,
        "mv3_closure_raw_sha256": EXPECTED_MV3_CLOSURE_SHA256,
        "ph1_closure_raw_sha256": EXPECTED_PH1_CLOSURE_SHA256,
    }
    for key, value in expected.items():
        if report.get(key) != value:
            _push(failures, f"C6_MJC_BW19V_MV6_IDENTITY:{key}")
    trace_canary = report.get("preworld_real_controller_trace_projection_canary")
    restoration_canary = report.get(
        "preworld_engine_neutral_terminal_restoration_canary"
    )
    vector_canary = report.get(
        "preworld_production_kinematic_vector_representation_canary"
    )
    assembler_canary = report.get(
        "preworld_shared_report_assembler_authority_schema_canary"
    )
    if (
        not isinstance(trace_canary, dict)
        or trace_canary.get("ok") is not True
        or trace_canary.get("world_build_count") != 0
        or trace_canary.get("negative_control_count") != 5
    ):
        _push(failures, "C6_MJC_BW19V_MV6_PREWORLD_TRACE_CANARY")
    if (
        not isinstance(restoration_canary, dict)
        or restoration_canary.get("ok") is not True
        or restoration_canary.get("world_build_count") != 0
        or restoration_canary.get("negative_control_count") != 5
    ):
        _push(failures, "C6_MJC_BW19V_MV6_PREWORLD_RESTORATION_CANARY")
    if (
        not isinstance(vector_canary, dict)
        or vector_canary.get("ok") is not True
        or vector_canary.get("world_build_count") != 0
        or vector_canary.get("negative_control_count") != 5
        or list(vector_canary.get("producer_output", {}).keys()) != ["x", "y", "z"]
    ):
        _push(failures, "C6_MJC_BW19V_MV6_PREWORLD_VECTOR_CANARY")
    if (
        not isinstance(assembler_canary, dict)
        or assembler_canary.get("ok") is not True
        or assembler_canary.get("assembler_function") != "_assemble_report"
        or assembler_canary.get("world_build_count") != 0
        or assembler_canary.get("negative_control_count") != 6
        or assembler_canary.get("real_authority_projection")
        != {
            "mv3_source_commit": EXPECTED_MV3_SOURCE_COMMIT,
            "ph1_source_commit": EXPECTED_PH1_PHYSICAL_SOURCE_COMMIT,
        }
    ):
        _push(failures, "C6_MJC_BW19V_MV6_PREWORLD_REPORT_ASSEMBLER_CANARY")
    trace = report.get("ordered_trace")
    if not isinstance(trace, list) or len(trace) != TOTAL_STEPS:
        return failures + ["C6_MJC_BW19V_MV6_TRACE_CARDINALITY"]
    schedule = report.get("schedule", {})
    evidence_completion = schedule.get("evidence_completion_semantic_step")
    if not isinstance(evidence_completion, int):
        return failures + ["C6_MJC_BW19V_MV6_EVIDENCE_COMPLETION"]
    terminal_contacts: list[tuple[int, bool]] = []
    terminal_pose_memory: dict[str, float] = {}
    for index, row in enumerate(trace):
        if row.get("schema_version") != TRACE_SCHEMA or row.get("semantic_step") != index:
            _push(failures, "C6_MJC_BW19V_MV6_TRACE_SEQUENCE")
        controller = row.get("receipt_payload", {}).get("controller_actuation", {})
        if (
            controller.get("receipt", {}).get("policy_id")
            != bridge.SELECTED_POLICY_ID
            or "source_policy_id" in controller
            or controller.get("semantic_step") != index
        ):
            _push(failures, "C6_MJC_BW19V_MV6_RECEIPT_PROJECTION")
        memory = row.get("ordered_limb_controller_memory_after")
        ids = (
            [item.get("limb_id") for item in memory]
            if isinstance(memory, list)
            else []
        )
        if ids != SCHEDULER_LIMB_ORDER or len(set(ids)) != 4:
            _push(failures, "C6_MJC_BW19V_MV6_LIMB_MEMORY_IDENTITY")
        if row.get("receipt_payload_sha256") != _digest(row.get("receipt_payload")):
            _push(failures, "C6_MJC_BW19V_MV6_RECEIPT_DIGEST")
        terminal = index > evidence_completion
        mode = row.get("command_composition", {}).get("mode")
        if terminal:
            memory_by_id = {
                item.get("limb_id"): item
                for item in memory
                if isinstance(item, dict)
            }
            for limb_id in SCHEDULER_LIMB_ORDER:
                limb_memory = memory_by_id.get(limb_id, {})
                if (
                    not isinstance(limb_memory.get("gait_step"), int)
                    or not isinstance(
                        limb_memory.get("evidence_gait_step_limit"), int
                    )
                    or limb_memory["gait_step"]
                    != limb_memory["evidence_gait_step_limit"]
                ):
                    _push(
                        failures,
                        f"C6_MJC_BW19V_MV6_TERMINAL_MEMORY_NOT_FROZEN:{limb_id}",
                    )
            if mode != "terminal_pose_hold_restoration_v1":
                _push(failures, "C6_MJC_BW19V_MV6_TERMINAL_MODE")
            terminal_receipt = row.get("command_composition", {}).get("receipt")
            if not isinstance(terminal_receipt, dict):
                _push(failures, "C6_MJC_BW19V_MV6_TERMINAL_RECEIPT")
            else:
                if terminal_receipt.get("semantic_step") != index:
                    _push(failures, "C6_MJC_BW19V_MV6_RESTORATION_STEP")
                for failure in _terminal_receipt_failures(
                    terminal_receipt,
                    {"ordered_commands": row.get("ordered_canonical_commands", [])},
                    {"ordered_commands": row.get("ordered_host_commands", [])},
                ):
                    _push(failures, f"C6_MJC_BW19V_MV6_RESTORATION:{failure}")
                for failure in _terminal_pose_memory_transition_failures(
                    terminal_receipt, terminal_pose_memory
                ):
                    _push(
                        failures,
                        f"C6_MJC_BW19V_MV6_RESTORATION_TRANSITION:{failure}",
                    )
                if row.get("command_composition", {}).get("receipt_sha256") != _digest(
                    terminal_receipt
                ):
                    _push(failures, "C6_MJC_BW19V_MV6_RESTORATION_DIGEST")
            contacts = row.get("post_step_snapshot", {}).get(
                "ordered_declared_contacts", {}
            )
            terminal_contacts.append(
                (
                    index,
                    all(contacts.get(f"{limb_id}_foot") is True for limb_id in MORPHOLOGY_LIMB_ORDER),
                )
            )
        elif mode != "walking_v4":
            _push(failures, "C6_MJC_BW19V_MV6_WALKING_MODE")
    first_contact: int | None = None
    completion: int | None = None
    consecutive = maximum = 0
    for step, all_four in terminal_contacts:
        if all_four:
            if first_contact is None:
                first_contact = step
            consecutive += 1
            maximum = max(maximum, consecutive)
            if consecutive == REQUIRED_CONSECUTIVE_CONTACT_STEPS and completion is None:
                completion = step
        else:
            consecutive = 0
    terminal_schedule = schedule.get("terminal_restoration_phase", {})
    expected_terminal = {
        "restoration_policy_id": RESTORATION_POLICY_ID,
        "activation_semantic_step": evidence_completion + 1,
        "maximum_four_contact_acquisition_steps_after_evidence_completion": 180,
        "first_four_contact_acquisition_semantic_step": first_contact,
        "required_consecutive_all_four_contact_steps": 360,
        "consecutive_four_contact_completion_semantic_step": completion,
        "maximum_consecutive_four_contact_steps": maximum,
        "required_consecutive_hold_completed": maximum >= 360,
    }
    if terminal_schedule != expected_terminal:
        _push(failures, "C6_MJC_BW19V_MV6_TERMINAL_SCHEDULE")
    if first_contact is None or first_contact > evidence_completion + 180:
        _push(failures, "C6_MJC_BW19V_MV6_TERMINAL_ACQUISITION")
    if maximum < 360:
        _push(failures, "C6_MJC_BW19V_MV6_TERMINAL_HOLD")
    return failures


def _evaluate_core(report: dict[str, Any]) -> list[str]:
    _authorities()
    failures = _specific_failures(report)
    proxy = _project_for_mv3(report)
    for code in mv3._evaluate_core(proxy):
        _push(failures, code.replace("C6_MJC_BW19V_MV3", "C6_MJC_BW19V_MV6"))
    return failures


def evaluate_report(report: dict[str, Any]) -> list[str]:
    failures = _evaluate_core(report)
    expected_ok = not failures
    if report.get("ok") is not expected_ok:
        _push(failures, "C6_MJC_BW19V_MV6_DECLARED_OK")
    if report.get("claim_boundary") != _claim_boundary(expected_ok):
        _push(failures, "C6_MJC_BW19V_MV6_CLAIM_BOUNDARY")
    return failures


def run_preflight() -> dict[str, Any]:
    authorities = _authorities()
    profile_canary = mv3._real_dynamic_library_profile_canary()
    morphology_canary = mv3._compiled_morphology_report_assembly_canary()
    trace_canary = _real_controller_trace_projection_canary()
    restoration_canary = _zero_world_terminal_restoration_canary()
    vector_canary = _production_kinematic_vector_representation_canary()
    assembler_canary = _shared_report_assembler_authority_schema_canary(authorities)
    perfect = _perfect_report(
        profile_canary,
        morphology_canary,
        trace_canary,
        restoration_canary,
        vector_canary,
        assembler_canary,
        authorities,
    )
    perfect_failures = evaluate_report(perfect)
    round_trip = json.loads(json.dumps(perfect, allow_nan=False))
    controls: dict[str, Callable[[dict[str, Any]], None]] = {
        "missing_trace_step": lambda value: value["ordered_trace"].pop(),
        "wrong_nested_policy": lambda value: value["ordered_trace"][0][
            "receipt_payload"
        ]["controller_actuation"]["receipt"].__setitem__("policy_id", "wrong"),
        "synthetic_top_level_policy": lambda value: value["ordered_trace"][0][
            "receipt_payload"
        ]["controller_actuation"].__setitem__(
            "source_policy_id", bridge.SELECTED_POLICY_ID
        ),
        "morphology_memory_order": lambda value: value["ordered_trace"][0].__setitem__(
            "ordered_limb_controller_memory_after",
            sorted(
                value["ordered_trace"][0]["ordered_limb_controller_memory_after"],
                key=lambda item: MORPHOLOGY_LIMB_ORDER.index(item["limb_id"]),
            ),
        ),
        "duplicate_limb_identity": lambda value: value["ordered_trace"][0][
            "ordered_limb_controller_memory_after"
        ][1].__setitem__("limb_id", "rear_left"),
        "terminal_pose_memory_transition": lambda value: value["ordered_trace"][-1][
            "command_composition"
        ]["receipt"]["ordered_limb_solutions"][1][
            "ordered_actuator_solutions"
        ][0].__setitem__("pose_capture_activated", True),
        "wrong_pose_gain": lambda value: value["ordered_trace"][-1][
            "command_composition"
        ]["receipt"].__setitem__("pose_hold_position_gain_per_s", 9.0),
        "terminal_command_mismatch": lambda value: value["ordered_trace"][-1][
            "ordered_host_commands"
        ][0].__setitem__("host_target_velocity_rad_s", 0.2),
        "terminal_contact_trace_mutation": lambda value: value["ordered_trace"][-1][
            "post_step_snapshot"
        ]["ordered_declared_contacts"].__setitem__("front_left_foot", False),
        "terminal_memory_not_frozen": lambda value: value["ordered_trace"][-1][
            "ordered_limb_controller_memory_after"
        ][0].__setitem__(
            "gait_step",
            value["ordered_trace"][-1]["ordered_limb_controller_memory_after"][0][
                "gait_step"
            ]
            + 1,
        ),
        "terminal_schedule_failure": lambda value: value["schedule"][
            "terminal_restoration_phase"
        ].__setitem__("required_consecutive_hold_completed", False),
        "native_position_target": lambda value: value["ordered_trace"][-1][
            "ordered_host_commands"
        ][0].__setitem__("native_target_position_rad", 0.1),
        "forward_metric_failure": lambda value: value["metrics"].__setitem__(
            "evidence_forward_displacement_m", 0.0
        ),
        "world_count_inflation": lambda value: value.__setitem__("world_build_count", 2),
        "claim_inflation": lambda value: value["claim_boundary"].__setitem__(
            "release_authorized", True
        ),
        "trace_canary_inflation": lambda value: value[
            "preworld_real_controller_trace_projection_canary"
        ].__setitem__("world_build_count", 1),
        "restoration_canary_inflation": lambda value: value[
            "preworld_engine_neutral_terminal_restoration_canary"
        ].__setitem__("world_build_count", 1),
        "vector_canary_inflation": lambda value: value[
            "preworld_production_kinematic_vector_representation_canary"
        ].__setitem__("world_build_count", 1),
    }
    rejected: dict[str, bool] = {}
    for name, mutate in controls.items():
        candidate = copy.deepcopy(perfect)
        mutate(candidate)
        if name not in {
            "wrong_nested_policy",
            "synthetic_top_level_policy",
            "morphology_memory_order",
            "duplicate_limb_identity",
        }:
            # Mutations outside the receipt projection may otherwise leave an
            # unrelated stale digest as the first witness.  Recompute it so the
            # intended surface itself must fail.
            for row in candidate.get("ordered_trace", []):
                row["receipt_payload_sha256"] = _digest(row["receipt_payload"])
                if row.get("command_composition", {}).get("receipt") is not None:
                    row["command_composition"]["receipt_sha256"] = _digest(
                        row["command_composition"]["receipt"]
                    )
        rejected[name] = bool(evaluate_report(candidate))
    total_controls = (
        len(controls)
        + int(profile_canary["negative_control_count"])
        + int(morphology_canary["negative_control_count"])
        + int(trace_canary["negative_control_count"])
        + int(restoration_canary["negative_control_count"])
        + int(vector_canary["negative_control_count"])
        + int(assembler_canary["negative_control_count"])
    )
    ok = (
        not perfect_failures
        and not evaluate_report(round_trip)
        and len(controls) == 18
        and total_controls == 43
        and all(rejected.values())
        and profile_canary["ok"]
        and morphology_canary["ok"]
        and trace_canary["ok"]
        and restoration_canary["ok"]
        and vector_canary["ok"]
        and assembler_canary["ok"]
    )
    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "ok": ok,
        "perfect_synthetic_result_passed": not perfect_failures,
        "perfect_synthetic_failure_codes": perfect_failures,
        "perfect_synthetic_serialization_round_trip_passed": not evaluate_report(
            round_trip
        ),
        "negative_control_count": total_controls,
        "synthetic_report_negative_control_count": len(controls),
        "synthetic_report_negative_controls_rejected": rejected,
        "real_dynamic_library_profile_canary": profile_canary,
        "compiled_morphology_report_assembly_canary": morphology_canary,
        "real_controller_trace_projection_canary": trace_canary,
        "engine_neutral_terminal_restoration_canary": restoration_canary,
        "production_kinematic_vector_representation_canary": vector_canary,
        "shared_report_assembler_authority_schema_canary": assembler_canary,
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_modified": False,
        "locomotion_outcome_exposed": False,
        "physical_acceptance_authority": False,
    }


def run_campaign(source_commit: str) -> dict[str, Any]:
    authorities = _authorities()
    if len(source_commit) != 40:
        raise ValueError("source_commit must be a full Git object ID")
    preflight = run_preflight()
    if not preflight["ok"]:
        raise RuntimeError("C6_MJC_BW19V_MV6_PREFLIGHT_FAILED")
    core = bridge.LocomotionCore()
    robot = bridge.MujocoBw19vRobot(core, PROFILE_ID)
    controller_memory = core.balanced_wave_initial_memory()
    composition_memory = bridge.CompositionMemory()
    restoration_memory = TerminalRestorationMemory()
    robot.prepare()
    initial = mv3._snapshot(robot)
    task_origin = np.asarray(initial["torso_position_m"], dtype=np.float64)
    actuator_ids = list(robot.morphology["ordered_actuator_ids"])
    limb_ids = list(robot.morphology["ordered_limb_ids"])
    contact_ids = list(robot.morphology["ordered_contact_site_ids"])
    foot = {
        limb_id: mv3.FootEvidence(
            bool(initial["ordered_declared_contacts"][contact_id])
        )
        for limb_id, contact_id in zip(limb_ids, contact_ids, strict=True)
    }
    trace: list[dict[str, Any]] = []
    evidence_start: list[float] | None = None
    evidence_end: list[float] | None = None
    evidence_completion: int | None = None
    first_four_contact: int | None = None
    four_contact_completion: int | None = None
    consecutive_four_contact = 0
    maximum_consecutive_four_contact = 0
    counters = {field: 0 for field in mv3.ZERO_INTEGRITY_FIELDS}
    counts = {
        "base_command_count": 0,
        "bounded_residual_command_count": 0,
        "canonical_command_count": 0,
        "host_command_count": 0,
        "native_application_count": 0,
        "nonzero_bounded_residual_count": 0,
        "nonzero_effective_host_residual_count": 0,
    }
    maximum_tilt = float(initial["torso_tilt_rad"])
    minimum_height = float(initial["torso_position_m"][1])

    for semantic_step in range(TOTAL_STEPS):
        pre = mv3._snapshot(robot)
        if semantic_step == CLOCKED_STEPS:
            evidence_start = list(pre["torso_position_m"])
            for limb in controller_memory["ordered_limb_memory"]:
                limb["evidence_gait_step_limit"] = (
                    int(limb["gait_step"]) + 1 + EVIDENCE_GAIT_STEPS
                )
        phase = "clocked" if semantic_step < CLOCKED_STEPS else "contact_gated"
        campaign_phase = (
            "clocked_walking"
            if semantic_step < CLOCKED_STEPS
            else (
                "evidence_walking"
                if evidence_completion is None
                else (
                    "terminal_acquisition"
                    if four_contact_completion is None
                    else "terminal_hold"
                )
            )
        )
        state = robot.state_frame(semantic_step, task_origin)
        pre_joint_observations = [
            {
                "joint_id": item["joint_id"],
                "position_rad": item["position_rad"],
                "velocity_rad_s": item["velocity_rad_s"],
            }
            for item in state["ordered_joint_observations"]
        ]
        stability_state = robot.stability_state(semantic_step)
        kinematics = robot.endpoint_kinematics(stability_state)
        limb_steps = bridge._ordered_limb_steps(controller_memory, limb_ids)
        output = core.balanced_wave_policy_step(
            bridge.SELECTED_POLICY_ID,
            {
                "descriptor": robot.descriptor,
                "memory": controller_memory,
                "state": state,
                "command": bridge._motion_command(semantic_step, phase),
            },
        )
        controller_memory = output["next_memory"]
        actuation = output["actuation"]
        counters["controller_error_count"] += int(
            actuation["receipt"]["controller_error"] is not None
        ) + len(actuation["failure_codes"])
        counters["safe_no_actuation_count"] += int(bool(actuation["safe_no_actuation"]))

        if evidence_completion is None:
            composition = bridge.compose_bw19v_step(
                robot,
                actuation,
                stability_state,
                kinematics,
                limb_steps,
                composition_memory,
            )
            mapping = composition["host_mapping"]
            bounded = [
                {
                    "actuator_id": item["actuator_id"],
                    "applied_velocity_delta_rad_s": float(
                        item["applied_velocity_delta_rad_s"]
                    ),
                }
                for item in composition["stability_influence"][
                    "ordered_applied_corrections"
                ]
            ]
            canonical_frame = composition["canonical_actuation"]
            terminal_receipt = None
            receipt = {
                "controller_actuation": actuation,
                "scheduled_load_transfer": composition["scheduled_load_transfer"],
                "endpoint_mapping": composition["endpoint_mapping"],
                "stability_influence": composition["stability_influence"],
                "canonical_actuation": canonical_frame,
                "host_mapping": mapping,
            }
            command_composition = {"mode": "walking_v4"}
        else:
            pre_contacts = dict(pre["ordered_declared_contacts"])
            restoration = _terminal_restoration_composition(
                robot,
                actuation,
                state,
                pre_contacts,
                kinematics,
                restoration_memory,
            )
            mapping = restoration["host_mapping"]
            canonical_frame = restoration["canonical_actuation"]
            bounded = restoration["ordered_bounded_canonical_residuals"]
            terminal_receipt = restoration["terminal_receipt"]
            receipt = {
                "controller_actuation": actuation,
                "scheduled_load_transfer": terminal_receipt,
                "endpoint_mapping": {"mode": "terminal_pose_hold_restoration_v1"},
                "stability_influence": {
                    "ordered_applied_corrections": bounded
                },
                "canonical_actuation": canonical_frame,
                "host_mapping": mapping,
            }
            command_composition = {
                "mode": "terminal_pose_hold_restoration_v1",
                "receipt": terminal_receipt,
                "receipt_sha256": _digest(terminal_receipt),
            }
        application = robot.apply_host_mapping(mapping)
        counters["portable_impulse_limit_violation_count"] += application[
            "portable_impulse_violation_count"
        ]
        robot.prepare()
        post = mv3._snapshot(robot)
        maximum_tilt = max(maximum_tilt, float(post["torso_tilt_rad"]))
        minimum_height = min(minimum_height, float(post["torso_position_m"][1]))
        counters["torso_ground_contact_step_count"] = counters.get(
            "torso_ground_contact_step_count", 0
        ) + int(post["torso_ground_contact"])
        if not all(
            _finite(value)
            for value in [
                *post["torso_position_m"],
                post["torso_tilt_rad"],
                post["torso_yaw_rad"],
            ]
        ):
            counters["nonfinite_observation_count"] += 1
        for limb_id, contact_id in zip(limb_ids, contact_ids, strict=True):
            foot[limb_id].observe(
                bool(post["ordered_declared_contacts"][contact_id]),
                post["ordered_contact_site_positions_m"][contact_id],
            )
        canonical = [
            dict(item) for item in canonical_frame["ordered_commands"]
        ]
        host = [dict(item) for item in mapping["ordered_commands"]]
        applications = [
            {
                "actuator_id": actuator_id,
                "target_velocity_rad_s": application["targets"][index],
                "cumulative_absolute_force_time_nms": application[
                    "cumulative_absolute_force_time_nms"
                ][index],
                "portable_maximum_outer_impulse_nms": application[
                    "portable_maximum_outer_impulse_nms"
                ][index],
                "maximum_absolute_actuator_force_nm": application[
                    "maximum_absolute_actuator_force_nm"
                ][index],
            }
            for index, actuator_id in enumerate(actuator_ids)
        ]
        trace.append(
            {
                "schema_version": TRACE_SCHEMA,
                "semantic_step": semantic_step,
                "campaign_phase": campaign_phase,
                "phase_progression_mode": phase,
                "command_provenance_recorded_before_application": True,
                "pre_step_snapshot": pre,
                "ordered_pre_step_joint_position_velocity_observations": (
                    pre_joint_observations
                ),
                "ordered_portable_base_commands": [
                    dict(item) for item in actuation["ordered_commands"]
                ],
                "ordered_bounded_canonical_residuals": bounded,
                "ordered_canonical_commands": canonical,
                "host_profile_id": PROFILE_ID,
                "host_response_characterized_for_this_profile": True,
                "native_position_stiffness": 0.0,
                "independent_native_position_feedback_applied": False,
                "global_requested_correction_scale": (
                    bridge.GLOBAL_REQUESTED_CORRECTION_SCALE
                ),
                "ordered_host_commands": host,
                "ordered_native_applications": applications,
                "receipt_payload": receipt,
                "receipt_payload_sha256": _digest(receipt),
                "command_composition": command_composition,
                "post_step_snapshot": post,
                "ordered_limb_controller_memory_after": mv3._limb_receipt(
                    controller_memory
                ),
            }
        )
        counts["base_command_count"] += len(actuation["ordered_commands"])
        counts["bounded_residual_command_count"] += len(bounded)
        counts["canonical_command_count"] += len(canonical)
        counts["host_command_count"] += len(host)
        counts["native_application_count"] += len(applications)
        counts["nonzero_bounded_residual_count"] += sum(
            item["applied_velocity_delta_rad_s"] != 0.0 for item in bounded
        )
        counts["nonzero_effective_host_residual_count"] += sum(
            item["portable_canonical_target_velocity_rad_s"]
            != item["combined_canonical_target_velocity_rad_s"]
            for item in canonical
        )
        if evidence_completion is None and semantic_step >= CLOCKED_STEPS:
            memory_by_id = {
                item["limb_id"]: item
                for item in controller_memory["ordered_limb_memory"]
            }
            if set(memory_by_id) == set(limb_ids) and all(
                memory_by_id[limb_id].get("evidence_gait_step_limit") is not None
                and int(memory_by_id[limb_id]["gait_step"])
                >= int(memory_by_id[limb_id]["evidence_gait_step_limit"])
                for limb_id in limb_ids
            ):
                evidence_completion = semantic_step
                evidence_end = list(post["torso_position_m"])
        elif evidence_completion is not None:
            all_four = all(
                post["ordered_declared_contacts"][site_id] for site_id in contact_ids
            )
            if all_four:
                if first_four_contact is None:
                    first_four_contact = semantic_step
                consecutive_four_contact += 1
                maximum_consecutive_four_contact = max(
                    maximum_consecutive_four_contact, consecutive_four_contact
                )
                if (
                    consecutive_four_contact == REQUIRED_CONSECUTIVE_CONTACT_STEPS
                    and four_contact_completion is None
                ):
                    four_contact_completion = semantic_step
            else:
                consecutive_four_contact = 0

    final = trace[-1]["post_step_snapshot"]
    metrics = {
        "evidence_forward_displacement_m": (
            None
            if evidence_start is None or evidence_end is None
            else evidence_end[0] - evidence_start[0]
        ),
        "final_forward_displacement_m": final["torso_position_m"][0]
        - initial["torso_position_m"][0],
        "final_lateral_displacement_m": final["torso_position_m"][2]
        - initial["torso_position_m"][2],
        "final_yaw_drift_rad": final["torso_yaw_rad"] - initial["torso_yaw_rad"],
        "maximum_tilt_rad": maximum_tilt,
        "minimum_torso_height_m": minimum_height,
    }
    report = {
        "schema_version": REPORT_SCHEMA,
        "ok": False,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "study_class": "outcome_exposed_single_body_finite_technical_commissioning_decision",
        "source_commit": source_commit,
        "preregistration_raw_sha256": EXPECTED_PREREGISTRATION_SHA256,
        "mv5_closure_raw_sha256": EXPECTED_MV5_CLOSURE_SHA256,
        "mv4_closure_raw_sha256": EXPECTED_MV4_CLOSURE_SHA256,
        "mv3_closure_raw_sha256": EXPECTED_MV3_CLOSURE_SHA256,
        "ph1_closure_raw_sha256": EXPECTED_PH1_CLOSURE_SHA256,
        "preworld_real_dynamic_library_profile_canary": preflight[
            "real_dynamic_library_profile_canary"
        ],
        "preworld_compiled_morphology_report_assembly_canary": preflight[
            "compiled_morphology_report_assembly_canary"
        ],
        "preworld_real_controller_trace_projection_canary": preflight[
            "real_controller_trace_projection_canary"
        ],
        "preworld_engine_neutral_terminal_restoration_canary": preflight[
            "engine_neutral_terminal_restoration_canary"
        ],
        "preworld_production_kinematic_vector_representation_canary": preflight[
            "production_kinematic_vector_representation_canary"
        ],
        "preworld_shared_report_assembler_authority_schema_canary": preflight[
            "shared_report_assembler_authority_schema_canary"
        ],
        "engine": "mujoco",
        "engine_version": mujoco.__version__,
        "adapter_id": bridge.ADAPTER_ID,
        "adapter_capability_sha256": bridge.capability_manifest_sha256(),
        "candidate_id": bridge.SELECTED_CANDIDATE_ID,
        "candidate_composition_digest": mv3.CANDIDATE_COMPOSITION_DIGEST,
        "selected_policy_id": bridge.SELECTED_POLICY_ID,
        "selected_policy_digest": mv3.POLICY_DIGEST,
        "stability_policy_id": bridge.STABILITY_POLICY_ID,
        "runtime_profile_sha256": mv3.S169_RUNTIME_PROFILE_SHA256,
        **mv3._compiled_morphology_report_identity(robot),
        "global_requested_correction_scale": bridge.GLOBAL_REQUESTED_CORRECTION_SCALE,
        "host_profile_id": PROFILE_ID,
        "vh5_closure_raw_sha256": mv3.EXPECTED_VH5_CLOSURE_SHA256,
        "vh5_report_raw_sha256": mv3.EXPECTED_VH5_REPORT_SHA256,
        "threshold_source_raw_sha256": mv3.EXPECTED_RAPIER_LC1_PREREGISTRATION_SHA256,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "world_reset_count": 0,
        **counters,
        "ordered_actuator_ids": actuator_ids,
        "ordered_limb_ids": limb_ids,
        "ordered_contact_site_ids": contact_ids,
        "trace_step_count": len(trace),
        **counts,
        "initial_snapshot": initial,
        "schedule": {
            "total_controller_semantic_steps": TOTAL_STEPS,
            "clocked_steps": CLOCKED_STEPS,
            "contact_gated_start_step": CLOCKED_STEPS,
            "evidence_gait_steps_per_limb": EVIDENCE_GAIT_STEPS,
            "maximum_evidence_extension_steps": MAXIMUM_EVIDENCE_EXTENSION_STEPS,
            "evidence_deadline_step_exclusive": EVIDENCE_DEADLINE_EXCLUSIVE,
            "required_post_evidence_steps": mv3.REQUIRED_POST_EVIDENCE_STEPS,
            "evidence_limits_reached": evidence_completion is not None,
            "evidence_completion_semantic_step": evidence_completion,
            "required_post_evidence_steps_completed": (
                evidence_completion is not None
                and evidence_completion + mv3.REQUIRED_POST_EVIDENCE_STEPS
                < TOTAL_STEPS
            ),
            "terminal_restoration_phase": {
                "restoration_policy_id": RESTORATION_POLICY_ID,
                "activation_semantic_step": (
                    None if evidence_completion is None else evidence_completion + 1
                ),
                "maximum_four_contact_acquisition_steps_after_evidence_completion": 180,
                "first_four_contact_acquisition_semantic_step": first_four_contact,
                "required_consecutive_all_four_contact_steps": 360,
                "consecutive_four_contact_completion_semantic_step": (
                    four_contact_completion
                ),
                "maximum_consecutive_four_contact_steps": (
                    maximum_consecutive_four_contact
                ),
                "required_consecutive_hold_completed": (
                    maximum_consecutive_four_contact >= 360
                ),
            },
        },
        "metrics": metrics,
        "terminal_four_contact_stance": all(
            final["ordered_declared_contacts"][site_id] for site_id in contact_ids
        ),
        "torso_ground_contact_step_count": counters.get(
            "torso_ground_contact_step_count", 0
        ),
        "limb_evidence": {
            limb_id: evidence.receipt() for limb_id, evidence in foot.items()
        },
        "ordered_trace": trace,
        "gate_failures": [],
        "claim_boundary": _claim_boundary(False),
        "physical_acceptance_authority": False,
    }
    return _assemble_report(report, authorities)


def _write_new_json(path: Path, value: dict[str, Any]) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, allow_nan=False)
        handle.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run MuJoCo BW19V MV6 preflight or physical campaign"
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preflight-only", action="store_true")
    mode.add_argument("--run-physical", action="store_true")
    parser.add_argument("--source-commit")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    if args.preflight_only:
        result = run_preflight()
        print(json.dumps(result, indent=2, allow_nan=False))
        return 0 if result["ok"] else 1
    if not args.source_commit or args.report is None:
        parser.error("--run-physical requires --source-commit and --report")
    result = run_campaign(args.source_commit)
    _write_new_json(args.report, result)
    print(
        f"{GATE_ID} ok={result['ok']} steps={result['trace_step_count']} "
        f"failures={len(result['gate_failures'])}"
    )
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
