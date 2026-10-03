"""QSDK-R23D1 MuJoCo heading-response worker.

The preflight crosses the real public core ABI, release-selected BW5R-B
controller, canonical velocity mapper, VH5-characterized MuJoCo host profile,
and production model-XML compiler without constructing an ``MjModel``. The
physical entrypoint remains unreachable until the shared contract and future
one-shot supervisor both authorize it.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
from typing import Any, Iterable
from xml.etree import ElementTree as ET

import mujoco
import numpy as np

from sporespore_locomotion import LocomotionCore

from . import selected_policy_development as bridge
from .conformance import capability_manifest_sha256

SDK_ROOT = Path(__file__).resolve().parents[3]
CONTRACT_PATH = SDK_ROOT / "turning" / "physical_development_contract_v1.json"
CAMPAIGN_ID = "QSDK-R23D1-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
GATE_ID = "QSDK-R23D1"
ENGINE_ID = "mujoco"
POLICY_ID = "sporespore_balanced_wave_bw5r_b_v1"
POLICY_DIGEST = (
    "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
)
MORPHOLOGY_ID = "qsdk_r05_generated_s169"
REPORT_SCHEMA = "sporespore_qsdk_r23d1_engine_cell_report_v2"
COMMAND_VALIDATION_SCHEMA = "sporespore_qsdk_r23d1_command_validation_v1"
NORMALIZED_VALIDATION_MODE = "native_adapter_structure_and_receipts_v1"
SOURCE_VALIDATION_MODE = (
    "mujoco_vh5_characterized_velocity_only_xml_mapping_and_force_limit_receipts_v1"
)
SCHEDULE_ID = "qsdk_r23d1_step_turn_return_v1"
HOST_PROFILE_ID = bridge.PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID
CAMPAIGN_SEED = 21_501
PHYSICS_HZ = 120
SETTLE_STEPS = 240
PHASE_OFFSET_ACTIVATION_STEP = 360
CONTACT_GATED_START_STEP = 472
CONTROLLER_STEPS = 2_992
TERMINAL_SETTLE_STEPS = 240
TURN_START_STEP = 600
TURN_END_STEP_EXCLUSIVE = 1_800
DECLARED_SCHEDULE_END_STEP_EXCLUSIVE = 2_400
MINIMUM_ABSOLUTE_TURN_PHASE_YAW_DELTA_RAD = 0.01
MINIMUM_FINAL_FORWARD_DISPLACEMENT_M = 0.030_123_046_875
MAXIMUM_TILT_RAD = 0.6
MINIMUM_TORSO_HEIGHT_M = 0.249_970_865_207_294_6
MINIMUM_CONTACT_CYCLES_PER_LIMB = 2
MAXIMUM_STEERING_FRACTION = 0.4

ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D1_ATTEMPT"
AUTHORIZATION_TOKEN_ENV = "SPORESPORE_QSDK_R23D1_TOKEN"
CELL_ID_ENV = "SPORESPORE_QSDK_R23D1_CELL"
ENGINE_ID_ENV = "SPORESPORE_QSDK_R23D1_ENGINE"
PHYSICAL_IDENTITY_CLOSED = True


class QsdkR23d1WorkerError(RuntimeError):
    """A fail-closed worker error with explicit world-attempt provenance."""

    def __init__(
        self,
        code: str,
        *,
        world_attempt_count: int = 0,
        world_build_count: int = 0,
    ) -> None:
        super().__init__(code)
        self.code = code
        self.world_attempt_count = world_attempt_count
        self.world_build_count = world_build_count


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _bytes_sha256(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def _contract() -> dict[str, Any]:
    try:
        contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise QsdkR23d1WorkerError(
            f"QSDK_R23D1_MJC_CONTRACT_INVALID:{type(error).__name__}"
        ) from error
    engine_status = {
        engine.get("engine_id"): (
            engine.get("host_binding_status"),
            engine.get("actual_worker_path"),
            engine.get("actual_route_preflight_path"),
            engine.get("actual_route_zero_world_commissioned"),
        )
        for engine in contract.get("engines", [])
    }
    expected_status = {
        "godot_jolt": (
            "actual_route_zero_world_commissioned",
            "tests/test_sdk_qsdk_r23d1_godot_jolt_worker.gd",
            "sdk/run_qsdk_r23d1_godot_jolt_worker_preflight.ps1",
            True,
        ),
        "rapier_parry": (
            "actual_route_zero_world_commissioned",
            "sdk/adapters/rapier/src/bin/qsdk_r23d1_heading_response.rs",
            "sdk/run_qsdk_r23d1_rapier_worker_preflight.ps1",
            True,
        ),
        "mujoco": (
            "actual_route_zero_world_commissioned",
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d1_heading_response.py",
            "sdk/run_qsdk_r23d1_mujoco_worker_preflight.ps1",
            True,
        ),
    }
    expected_arms = [
        {
            "arm_id": "reference_zero",
            "turn_heading_offset_rad": 0.0,
            "role": "zero_command_straight_walk_compatibility",
        },
        {
            "arm_id": "positive_heading",
            "turn_heading_offset_rad": 0.2,
            "role": "positive_signed_heading_response",
        },
        {
            "arm_id": "negative_heading",
            "turn_heading_offset_rad": -0.2,
            "role": "negative_signed_heading_response",
        },
    ]
    expected_segments = [
        {
            "segment_id": "reference_warmup",
            "start_step_inclusive": 0,
            "end_step_exclusive": TURN_START_STEP,
            "heading_offset_source": "zero",
        },
        {
            "segment_id": "commanded_turn",
            "start_step_inclusive": TURN_START_STEP,
            "end_step_exclusive": TURN_END_STEP_EXCLUSIVE,
            "heading_offset_source": "arm.turn_heading_offset_rad",
        },
        {
            "segment_id": "reference_recovery",
            "start_step_inclusive": TURN_END_STEP_EXCLUSIVE,
            "end_step_exclusive": DECLARED_SCHEDULE_END_STEP_EXCLUSIVE,
            "heading_offset_source": "zero",
        },
    ]
    schedule = contract.get("command_schedule", {})
    gates = contract.get("development_detection_gates", {})
    validation = contract.get("required_command_validation", {})
    matrix = contract.get("cell_matrix", {})
    fixture = contract.get("fixture", {})
    if (
        contract.get("schema_version")
        != "sporespore_qsdk_r23d1_physical_development_contract_v1"
        or contract.get("campaign_id") != CAMPAIGN_ID
        or contract.get("gate_id") != GATE_ID
        or contract.get("required_normalized_report_schema") != REPORT_SCHEMA
        or contract.get("source_contract", {}).get("selected_policy_id") != POLICY_ID
        or contract.get("source_contract", {}).get("selected_policy_digest")
        != POLICY_DIGEST
        or fixture.get("morphology_id") != MORPHOLOGY_ID
        or fixture.get("descriptor") != bridge.s169_descriptor()
        or fixture.get("physics_hz") != PHYSICS_HZ
        or fixture.get("authored_sliding_friction") != bridge.AUTHORED_FRICTION
        or fixture.get("initial_condition_seed") != CAMPAIGN_SEED
        or fixture.get("initial_condition_policy")
        != "physical_wave_gait_compile_seeded_initial_perturbation_v1"
        or engine_status != expected_status
        or contract.get("arms") != expected_arms
        or matrix.get("declared_cell_count") != 9
        or matrix.get("worlds_per_cell") != 1
        or matrix.get("execution_order") != "engine_order_then_arm_order"
        or matrix.get("parallel_execution_permitted") is not False
        or matrix.get("replacement_or_selective_rerun_permitted") is not False
        or schedule.get("schedule_id") != SCHEDULE_ID
        or schedule.get("domain") != "controller_semantic_step"
        or schedule.get("minimum_required_controller_step_count")
        != DECLARED_SCHEDULE_END_STEP_EXCLUSIVE
        or schedule.get("segments") != expected_segments
        or schedule.get("after_last_segment") != "hold_reference_heading"
        or schedule.get("expected_segment_sample_counts")
        != {
            "reference_warmup": 600,
            "commanded_turn": 1_200,
            "reference_recovery": 600,
        }
        or validation.get("schema_version") != COMMAND_VALIDATION_SCHEMA
        or validation.get("normalized_validation_mode") != NORMALIZED_VALIDATION_MODE
        or validation.get("heading_command_conditioned_entire_schedule") is not True
        or validation.get("legacy_command_parity_applicable") is not False
        or validation.get("legacy_command_parity_checked_step_count") != 0
        or validation.get("legacy_command_parity_waived_step_count") != 0
        or gates.get("maximum_absolute_requested_or_held_steering_fraction")
        != MAXIMUM_STEERING_FRACTION
        or gates.get("minimum_absolute_signed_turn_phase_yaw_delta_rad")
        != MINIMUM_ABSOLUTE_TURN_PHASE_YAW_DELTA_RAD
        or gates.get("minimum_final_forward_displacement_m")
        != MINIMUM_FINAL_FORWARD_DISPLACEMENT_M
        or gates.get("maximum_tilt_rad") != MAXIMUM_TILT_RAD
        or gates.get("minimum_torso_height_m") != MINIMUM_TORSO_HEIGHT_M
        or gates.get("minimum_contact_cycles_per_limb")
        != MINIMUM_CONTACT_CYCLES_PER_LIMB
        or gates.get("zero_torso_ground_contact_required") is not True
        or gates.get("zero_command_requires_engine_production_straight_walking_gate")
        is not True
        or gates.get("turn_arms_require_forward_contact_and_stability_gates")
        is not True
        or gates.get("recovery_heading_is_measured_but_not_thresholded") is not True
    ):
        raise QsdkR23d1WorkerError("QSDK_R23D1_MJC_CONTRACT_IDENTITY_INVALID")
    return contract


def _initial_perturbation(contract: dict[str, Any]) -> dict[str, Any]:
    value = contract["fixture"].get("initial_perturbation")
    if not isinstance(value, dict):
        raise QsdkR23d1WorkerError("QSDK_R23D1_MJC_INITIAL_PERTURBATION_INVALID")
    linear = value.get("initial_linear_velocity_world_m_s")
    angular = value.get("initial_torso_angular_velocity_world_rad_s")
    numbers = [
        value.get("fixture_vertical_clearance_m"),
        value.get("fixture_yaw_rad"),
        *(linear if isinstance(linear, list) else []),
        *(angular if isinstance(angular, list) else []),
    ]
    if (
        value.get("campaign_seed") != CAMPAIGN_SEED
        or not isinstance(linear, list)
        or len(linear) != 3
        or not isinstance(angular, list)
        or len(angular) != 3
        or len(numbers) != 8
        or not all(
            isinstance(number, (int, float)) and math.isfinite(number)
            for number in numbers
        )
        or float(value["fixture_vertical_clearance_m"]) < 0.0
        or not isinstance(value.get("gait_phase_offset_ticks"), int)
        or abs(value["gait_phase_offset_ticks"]) > 3
    ):
        raise QsdkR23d1WorkerError("QSDK_R23D1_MJC_INITIAL_PERTURBATION_INVALID")
    return json.loads(json.dumps(value, allow_nan=False))


def _arm_offset(contract: dict[str, Any], arm_id: str) -> float:
    for arm in contract["arms"]:
        if arm["arm_id"] == arm_id:
            return float(arm["turn_heading_offset_rad"])
    raise QsdkR23d1WorkerError(f"QSDK_R23D1_MJC_ARM_UNKNOWN:{arm_id}")


def _wrap_angle(value: float) -> float:
    return (value + math.pi) % math.tau - math.pi


def _heading_receipt(
    semantic_step: int,
    reference_heading_rad: float,
    turn_heading_offset_rad: float,
) -> dict[str, Any]:
    if semantic_step < TURN_START_STEP:
        segment_id, command_role, offset, declared = (
            "reference_warmup",
            "reference_heading",
            0.0,
            True,
        )
    elif semantic_step < TURN_END_STEP_EXCLUSIVE:
        segment_id, command_role, offset, declared = (
            "commanded_turn",
            "turn_heading",
            turn_heading_offset_rad,
            True,
        )
    elif semantic_step < DECLARED_SCHEDULE_END_STEP_EXCLUSIVE:
        segment_id, command_role, offset, declared = (
            "reference_recovery",
            "reference_heading",
            0.0,
            True,
        )
    else:
        segment_id, command_role, offset, declared = (
            "after_schedule",
            "reference_heading",
            0.0,
            False,
        )
    return {
        "segment_id": segment_id,
        "command_role": command_role,
        "heading_offset_rad": offset,
        "desired_heading_rad": _wrap_angle(reference_heading_rad + offset),
        "declared_segment": declared,
    }


def _motion_command(
    semantic_step: int,
    phase_progression_mode: str,
    heading: dict[str, Any],
) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_motion_command_v2",
        "command_id": f"{SCHEDULE_ID}_{heading['segment_id']}",
        "desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
        "desired_heading_rad": heading["desired_heading_rad"],
        "desired_yaw_rate_rad_s": None,
        "gait_family_id": "lateral_wave",
        "speed_class": "walk",
        "gait_amplitude": 1.0,
        "phase_progression_mode": phase_progression_mode,
        "valid_from_step": semantic_step,
        "valid_through_step": semantic_step,
        "authority": "test_fixture",
    }


def _task_axes(
    reference_heading_rad: float,
) -> tuple[dict[str, float], dict[str, float]]:
    return (
        {
            "x": math.cos(reference_heading_rad),
            "y": 0.0,
            "z": math.sin(reference_heading_rad),
        },
        {
            "x": -math.sin(reference_heading_rad),
            "y": 0.0,
            "z": math.cos(reference_heading_rad),
        },
    )


def _synthetic_state(
    compiled: dict[str, Any],
    semantic_step: int,
    reference_heading_rad: float,
) -> dict[str, Any]:
    morphology = compiled["morphology"]
    forward, lateral = _task_axes(reference_heading_rad)
    return {
        "schema_version": "sporespore_state_frame_v1",
        "semantic_step": semantic_step,
        "sample_time_s": semantic_step / PHYSICS_HZ,
        "base_pose_world": {
            "position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
            "orientation_xyzw": {
                "x": 0.0,
                "y": -math.sin(reference_heading_rad / 2.0),
                "z": 0.0,
                "w": math.cos(reference_heading_rad / 2.0),
            },
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
                "contact_site_id": contact_id,
                "presence": True,
                "bears_support": True,
                "normal_load_n": None,
                "provenance": {
                    "adapter_id": bridge.ADAPTER_ID,
                    "engine_contact_ids": [f"{contact_id}_r23d1_zero_world"],
                    "aggregation_rule_id": "qualified_bearing_only",
                    "quality": "qualified_bearing",
                },
            }
            for contact_id in morphology["ordered_contact_site_ids"]
        ],
        "previous_applied_actuation": None,
        "gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
        "task_frame": {
            "origin_world_m": {"x": 0.0, "y": 0.0, "z": 0.0},
            "forward_axis_world_unit": forward,
            "lateral_axis_world_unit": lateral,
            "up_axis_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
            "reference_yaw_rad": reference_heading_rad,
        },
        "adapter_capability_sha256": capability_manifest_sha256(),
    }


def _zero_residuals(actuation: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        {
            "schema_version": "sporespore_canonical_velocity_residual_v1",
            "actuator_id": command["actuator_id"],
            "canonical_velocity_delta_rad_s": 0.0,
            "command_not_measurement": True,
            "physical_acceptance_authority": False,
        }
        for command in actuation["ordered_commands"]
    ]


def _model_xml_receipt(compiled: dict[str, Any]) -> dict[str, Any]:
    model_xml = bridge.build_model_xml(compiled, HOST_PROFILE_ID)
    root = ET.fromstring(model_xml)
    actuator_root = root.find("actuator")
    if actuator_root is None:
        raise QsdkR23d1WorkerError("QSDK_R23D1_MJC_MODEL_XML_ACTUATOR_ROOT_MISSING")
    actuators = list(actuator_root)
    morphology = compiled["morphology"]
    if len(actuators) != 8:
        raise QsdkR23d1WorkerError("QSDK_R23D1_MJC_MODEL_XML_ACTUATOR_COUNT_INVALID")
    specs = {
        actuator["actuator_id"]: actuator
        for actuator in morphology["morphology_spec"]["actuators"]
    }
    ordered_limits: dict[str, float] = {}
    for expected_id, element in zip(
        morphology["ordered_actuator_ids"], actuators, strict=True
    ):
        expected_limit = bridge._native_force_limit_nm(
            specs[expected_id], HOST_PROFILE_ID
        )
        force_range = [
            float(value) for value in element.attrib.get("forcerange", "").split()
        ]
        if (
            element.tag != "velocity"
            or element.attrib.get("name") != expected_id
            or element.attrib.get("joint") != specs[expected_id]["joint_id"]
            or element.attrib.get("forcelimited") != "true"
            or float(element.attrib.get("kv", "nan")) != bridge.VELOCITY_GAIN
            or force_range != [-expected_limit, expected_limit]
        ):
            raise QsdkR23d1WorkerError(
                f"QSDK_R23D1_MJC_MODEL_XML_ACTUATOR_INVALID:{expected_id}"
            )
        ordered_limits[expected_id] = expected_limit
    return {
        "schema_version": "sporespore_qsdk_r23d1_mujoco_model_xml_receipt_v1",
        "ok": True,
        "model_xml_sha256": _bytes_sha256(model_xml.encode("utf-8")),
        "native_actuator_count": len(actuators),
        "native_actuator_order_exact": True,
        "native_motor_model_id": (
            "velocity_servo_s169_per_actuator_force_limited_five_substep_"
            "vh5_validated_v1"
        ),
        "velocity_gain_nm_s_per_rad": bridge.VELOCITY_GAIN,
        "internal_timestep_s": bridge.INTERNAL_DT_S,
        "internal_steps_per_controller_step": bridge.INTERNAL_STEPS_PER_OUTER,
        "ordered_native_force_limits_nm": ordered_limits,
        "model_construction_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
    }


def _native_step(
    core: LocomotionCore,
    compiled: dict[str, Any],
    semantic_step: int,
    reference_heading_rad: float,
    turn_heading_offset_rad: float,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]:
    heading = _heading_receipt(
        semantic_step, reference_heading_rad, turn_heading_offset_rad
    )
    output = core.balanced_wave_policy_step(
        POLICY_ID,
        {
            "descriptor": bridge.s169_descriptor(),
            "memory": core.balanced_wave_initial_memory(),
            "state": _synthetic_state(compiled, semantic_step, reference_heading_rad),
            "command": _motion_command(semantic_step, "clocked", heading),
        },
    )
    actuation = output["actuation"]
    receipt = actuation["receipt"]
    ordered_ids = list(compiled["morphology"]["ordered_actuator_ids"])
    memory = output["next_memory"]
    if (
        actuation["safe_no_actuation"] is not False
        or actuation["failure_codes"] != []
        or receipt["controller_error"] is not None
        or receipt["policy_id"] != POLICY_ID
        or receipt["semantic_step"] != semantic_step
        or receipt["command_id"] != f"{SCHEDULE_ID}_{heading['segment_id']}"
        or receipt["world_build_count"] != 0
        or receipt["physical_acceptance_authority"] is not False
        or not math.isclose(
            float(receipt["desired_heading_error_rad"]),
            float(heading["heading_offset_rad"]),
            rel_tol=0.0,
            abs_tol=1.0e-12,
        )
        or not math.isfinite(float(receipt["requested_steering_fraction"]))
        or not math.isfinite(float(receipt["held_steering_fraction"]))
        or abs(float(receipt["requested_steering_fraction"]))
        > MAXIMUM_STEERING_FRACTION
        or abs(float(receipt["held_steering_fraction"])) > MAXIMUM_STEERING_FRACTION
        or [command["actuator_id"] for command in actuation["ordered_commands"]]
        != ordered_ids
        or memory["last_semantic_step"] != semantic_step
        or [limb["limb_id"] for limb in memory["ordered_limb_memory"]]
        != ["rear_left", "front_left", "rear_right", "front_right"]
    ):
        raise QsdkR23d1WorkerError("QSDK_R23D1_MJC_CONTROLLER_RECEIPT_INVALID")
    canonical = core.canonical_velocity_compose_v1(
        {
            "schema_version": "sporespore_canonical_velocity_compose_request_v1",
            "descriptor": bridge.s169_descriptor(),
            "source_actuation": actuation,
            "ordered_stability_residuals": _zero_residuals(actuation),
        }
    )
    mapping = core.canonical_velocity_host_map_v1(
        {
            "schema_version": "sporespore_canonical_velocity_host_map_request_v1",
            "descriptor": bridge.s169_descriptor(),
            "canonical_actuation": canonical,
            "host_profile": bridge._mujoco_host_profile(HOST_PROFILE_ID),
        }
    )
    commands = mapping["ordered_commands"]
    if (
        mapping["host_profile_id"] != HOST_PROFILE_ID
        or mapping["engine_id"] != ENGINE_ID
        or mapping["native_position_stiffness"] != 0.0
        or mapping["independent_native_position_feedback_applied"] is not False
        or mapping["host_response_characterized_for_this_profile"] is not True
        or [command["actuator_id"] for command in commands] != ordered_ids
        or any(
            command["native_target_position_rad"] is not None
            or command["host_clamped"] is not False
            or not math.isfinite(float(command["host_target_velocity_rad_s"]))
            for command in commands
        )
    ):
        raise QsdkR23d1WorkerError("QSDK_R23D1_MJC_NATIVE_MAPPING_INVALID")
    return heading, output, mapping, canonical


def _perfect_report(
    contract: dict[str, Any], arm_id: str, turn_heading_offset_rad: float
) -> dict[str, Any]:
    signed_yaw = (
        0.0
        if turn_heading_offset_rad == 0.0
        else math.copysign(0.02, turn_heading_offset_rad)
    )
    mean_turn = -1.3 * turn_heading_offset_rad
    return {
        "schema_version": REPORT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": ENGINE_ID,
        "arm_id": arm_id,
        "cell_id": f"{ENGINE_ID}__{arm_id}",
        "selected_policy_id": POLICY_ID,
        "selected_policy_digest": POLICY_DIGEST,
        "morphology_id": MORPHOLOGY_ID,
        "campaign_seed": CAMPAIGN_SEED,
        "contract_sha256": _raw_sha256(CONTRACT_PATH),
        "source_commit": "0" * 40,
        "execution": {
            "world_attempt_count": 1,
            "world_build_count": 1,
            "world_reset_count": 0,
            "direct_body_write_count": 0,
            "controller_error_count": 0,
            "safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "controller_semantic_step_count": CONTROLLER_STEPS,
            "validated_portable_command_count": CONTROLLER_STEPS * 8,
            "native_actuation_application_count": CONTROLLER_STEPS * 8,
        },
        "command_validation": {
            "schema_version": COMMAND_VALIDATION_SCHEMA,
            "normalized_validation_mode": NORMALIZED_VALIDATION_MODE,
            "source_validation_mode": SOURCE_VALIDATION_MODE,
            "native_validation_step_count": CONTROLLER_STEPS,
            "heading_command_conditioned_step_count": CONTROLLER_STEPS,
            "unconditioned_step_count": 0,
            "legacy_command_parity_applicable": False,
            "legacy_command_parity_checked_step_count": 0,
            "legacy_command_parity_waived_step_count": 0,
        },
        "schedule": {
            "schedule_id": SCHEDULE_ID,
            "observed_segment_sample_counts": {
                "reference_warmup": 600,
                "commanded_turn": 1_200,
                "reference_recovery": 600,
            },
            "turn_heading_offset_rad": turn_heading_offset_rad,
            "reference_heading_sample_count": 1_200,
            "turn_heading_sample_count": 1_200,
        },
        "controller": {
            "maximum_absolute_requested_steering_fraction": abs(mean_turn),
            "maximum_absolute_held_steering_fraction": abs(mean_turn),
            "mean_turn_held_steering_fraction": mean_turn,
        },
        "physics": {
            "turn_phase_yaw_delta_rad": signed_yaw,
            "final_reference_heading_error_rad": 0.0,
            "final_forward_displacement_m": 0.1,
            "maximum_tilt_rad": 0.1,
            "minimum_torso_height_m": 0.3,
            "torso_ground_contact_step_count": 0,
            "contact_cycles_by_limb": {
                "front_left": 2,
                "front_right": 2,
                "rear_left": 2,
                "rear_right": 2,
            },
            "engine_production_straight_walking_gate_passed": True,
            "commanded_turn_walk_gate_passed": True,
        },
        "host": {
            "adapter_id": bridge.ADAPTER_ID,
            "adapter_capability_sha256": capability_manifest_sha256(),
            "engine_version": mujoco.__version__,
            "velocity_only_profile_id": HOST_PROFILE_ID,
            "synthetic_preflight_only": True,
        },
        "claims": {
            "development_screen_only": True,
            "q_sdk_r23_satisfied": False,
            "command_conditioned_turning": False,
            "cross_engine_equivalence": False,
            "release_authorized": False,
            "physical_acceptance_authority": False,
        },
        "physical_acceptance_authority": False,
        "contract_physical_execution_authorized": contract["authorization"][
            "physical_execution_authorized"
        ],
    }


def run_preflight(arm_id: str) -> dict[str, Any]:
    contract = _contract()
    perturbation = _initial_perturbation(contract)
    turn_offset = _arm_offset(contract, arm_id)
    core = LocomotionCore()
    compiled = core.compile_bounded_quadruped(bridge.s169_descriptor())
    semantic_step = 0 if arm_id == "reference_zero" else TURN_START_STEP
    heading, output, mapping, canonical = _native_step(
        core, compiled, semantic_step, 0.17, turn_offset
    )
    model_xml_receipt = _model_xml_receipt(compiled)
    return {
        "schema_version": "sporespore_qsdk_r23d1_mujoco_worker_preflight_v1",
        "ok": True,
        "failure_code": "",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": ENGINE_ID,
        "arm_id": arm_id,
        "cell_id": f"{ENGINE_ID}__{arm_id}",
        "campaign_seed": CAMPAIGN_SEED,
        "selected_policy_id": POLICY_ID,
        "selected_policy_digest": POLICY_DIGEST,
        "morphology_id": MORPHOLOGY_ID,
        "contract_sha256": _raw_sha256(CONTRACT_PATH),
        "initial_perturbation": perturbation,
        "turn_heading_offset_rad": turn_offset,
        "native_heading_preflight": {
            "native_controller_step_passed": True,
            "native_controller_command_count": len(
                output["actuation"]["ordered_commands"]
            ),
            "native_controller_command_order_exact": True,
            "native_next_memory_exact": True,
            "heading_command_receipt": heading,
            "controller_receipt": output["actuation"]["receipt"],
            "canonical_actuation": canonical,
            "host_mapping": mapping,
            "model_xml_receipt": model_xml_receipt,
            "command_validation_receipt": {
                "schema_version": "sporespore_balanced_wave_command_validation_receipt_v1",
                "ok": True,
                "enabled": True,
                "validation_mode": SOURCE_VALIDATION_MODE,
                "heading_command_conditioned": True,
                "legacy_command_parity_applicable": False,
                "legacy_command_parity_checked": False,
                "legacy_command_parity_waived": False,
                "world_build_count": 0,
                "physics_state_modified": False,
                "physical_acceptance_authority": False,
            },
            "actual_world_build_count": 0,
            "model_construction_count": 0,
            "physics_state_modified": False,
            "locomotion_outcome_exposed": False,
            "physical_acceptance_authority": False,
        },
        "core": {
            "version": core.version,
            "library_path": str(core.library_path),
            "library_sha256": _raw_sha256(core.library_path),
        },
        "production_normalized_report": _perfect_report(contract, arm_id, turn_offset),
        "entrypoint_control_flow_complete": True,
        "actual_world_build_count": 0,
        "model_construction_count": 0,
        "physics_state_modified": False,
        "locomotion_outcome_exposed": False,
        "physical_execution_authorized": False,
        "q_sdk_r23_satisfied": False,
        "physical_acceptance_authority": False,
    }


def _valid_lower_hex(value: str, length: int) -> bool:
    return len(value) == length and all(
        character in "0123456789abcdef" for character in value
    )


def _physical_authorization(
    contract: dict[str, Any], arm_id: str, source_commit: str
) -> None:
    if contract["authorization"]["physical_execution_authorized"] is not True:
        raise QsdkR23d1WorkerError("QSDK_R23D1_MJC_PHYSICAL_AUTHORIZATION_REQUIRED")
    attempt_path = os.environ.get(ATTEMPT_PATH_ENV, "")
    token = os.environ.get(AUTHORIZATION_TOKEN_ENV, "")
    cell_id = f"{ENGINE_ID}__{arm_id}"
    if (
        not attempt_path
        or not _valid_lower_hex(token, 32)
        or os.environ.get(CELL_ID_ENV) != cell_id
        or os.environ.get(ENGINE_ID_ENV) != ENGINE_ID
    ):
        raise QsdkR23d1WorkerError("QSDK_R23D1_MJC_SUPERVISOR_AUTHORIZATION_INVALID")
    try:
        attempt = json.loads(Path(attempt_path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise QsdkR23d1WorkerError(
            f"QSDK_R23D1_MJC_ATTEMPT_INVALID:{type(error).__name__}"
        ) from error
    expected_cells = [
        f"{engine}__{arm}"
        for engine in ("godot_jolt", "rapier_parry", "mujoco")
        for arm in ("reference_zero", "positive_heading", "negative_heading")
    ]
    if not (
        attempt.get("schema_version") == "sporespore_qsdk_r23d1_attempt_v1"
        and attempt.get("campaign_id") == CAMPAIGN_ID
        and attempt.get("gate_id") == GATE_ID
        and attempt.get("contract_sha256") == _raw_sha256(CONTRACT_PATH)
        and attempt.get("source_commit") == source_commit
        and attempt.get("origin_main_commit") == source_commit
        and attempt.get("live_main_commit") == source_commit
        and attempt.get("authorization_token") == token
        and attempt.get("physical_execution_authorized") is True
        and attempt.get("single_use_supervisor_authorization") is True
        and attempt.get("source_worktree_clean") is True
        and attempt.get("source_matches_live_github_main") is True
        and attempt.get("operation_lock_held") is True
        and attempt.get("full_godot_attestation_valid") is True
        and attempt.get("content_addressed_inputs_retained") is True
        and attempt.get("one_shot_attempt_unconsumed") is True
        and attempt.get("ordered_cell_ids") == expected_cells
    ):
        raise QsdkR23d1WorkerError("QSDK_R23D1_MJC_ATTEMPT_AUTHORIZATION_INVALID")


def _quaternion_multiply(left: np.ndarray, right: np.ndarray) -> np.ndarray:
    lw, lx, ly, lz = left
    rw, rx, ry, rz = right
    return np.asarray(
        [
            lw * rw - lx * rx - ly * ry - lz * rz,
            lw * rx + lx * rw + ly * rz - lz * ry,
            lw * ry - lx * rz + ly * rw + lz * rx,
            lw * rz + lx * ry - ly * rx + lz * rw,
        ],
        dtype=np.float64,
    )


def _apply_initial_perturbation(
    robot: bridge.MujocoBw19vRobot, perturbation: dict[str, Any]
) -> dict[str, Any]:
    free_joint = robot.model.joint("torso_free").id
    if int(robot.model.jnt_type[free_joint]) != int(mujoco.mjtJoint.mjJNT_FREE):
        raise QsdkR23d1WorkerError(
            "QSDK_R23D1_MJC_TORSO_FREE_JOINT_INVALID",
            world_attempt_count=1,
            world_build_count=1,
        )
    qpos = int(robot.model.jnt_qposadr[free_joint])
    dof = int(robot.model.jnt_dofadr[free_joint])
    yaw = float(perturbation["fixture_yaw_rad"])
    cosine = math.cos(yaw)
    sine = math.sin(yaw)
    canonical_position = bridge._mujoco_to_canonical(robot.data.qpos[qpos : qpos + 3])
    rotated_position = np.asarray(
        [
            cosine * canonical_position[0] + sine * canonical_position[2],
            canonical_position[1] + float(perturbation["fixture_vertical_clearance_m"]),
            -sine * canonical_position[0] + cosine * canonical_position[2],
        ],
        dtype=np.float64,
    )
    robot.data.qpos[qpos : qpos + 3] = bridge._canonical_to_mujoco(rotated_position)
    yaw_quaternion_mujoco = np.asarray(
        [math.cos(yaw / 2.0), 0.0, 0.0, math.sin(yaw / 2.0)],
        dtype=np.float64,
    )
    base_quaternion = np.asarray(robot.data.qpos[qpos + 3 : qpos + 7], dtype=np.float64)
    updated_quaternion = _quaternion_multiply(yaw_quaternion_mujoco, base_quaternion)
    updated_quaternion /= np.linalg.norm(updated_quaternion)
    robot.data.qpos[qpos + 3 : qpos + 7] = updated_quaternion
    robot.data.qvel[:] = 0.0
    robot.data.qvel[dof : dof + 3] = bridge._canonical_to_mujoco(
        perturbation["initial_linear_velocity_world_m_s"]
    )
    robot.data.qvel[dof + 3 : dof + 6] = bridge._canonical_to_mujoco(
        perturbation["initial_torso_angular_velocity_world_rad_s"]
    )
    mujoco.mj_forward(robot.model, robot.data)
    if not np.isfinite(robot.data.qpos).all() or not np.isfinite(robot.data.qvel).all():
        raise QsdkR23d1WorkerError(
            "QSDK_R23D1_MJC_INITIAL_STATE_NONFINITE",
            world_attempt_count=1,
            world_build_count=1,
        )
    return {
        "schema_version": "sporespore_qsdk_r23d1_mujoco_initial_perturbation_receipt_v1",
        "application_count": 1,
        "free_joint_id": "torso_free",
        "canonical_linear_velocity_world_m_s": perturbation[
            "initial_linear_velocity_world_m_s"
        ],
        "canonical_torso_angular_velocity_world_rad_s": perturbation[
            "initial_torso_angular_velocity_world_rad_s"
        ],
        "world_build_count": 1,
        "physical_acceptance_authority": False,
    }


def _zero_prepared_outer_step(robot: bridge.MujocoBw19vRobot) -> None:
    for substep in range(bridge.INTERNAL_STEPS_PER_OUTER):
        if substep > 0:
            mujoco.mj_step1(robot.model, robot.data)
        robot.data.ctrl[:] = 0.0
        if np.count_nonzero(robot.data.ctrl) != 0:
            raise QsdkR23d1WorkerError(
                "QSDK_R23D1_MJC_ZERO_CONTROL_READBACK_INVALID",
                world_attempt_count=1,
                world_build_count=1,
            )
        mujoco.mj_step2(robot.model, robot.data)


def _phase_offset(
    memory: dict[str, Any], requested_offset_ticks: int
) -> dict[str, Any]:
    limbs = memory["ordered_limb_memory"]
    if abs(requested_offset_ticks) > 3 or len(limbs) != 4:
        raise QsdkR23d1WorkerError(
            "QSDK_R23D1_MJC_PHASE_OFFSET_INVALID",
            world_attempt_count=1,
            world_build_count=1,
        )
    minimum_raw = min(int(limb["gait_step"]) + requested_offset_ticks for limb in limbs)
    representation_shift_ticks = 0
    while minimum_raw + representation_shift_ticks < 0:
        representation_shift_ticks += 360
    for limb in limbs:
        limb["gait_step"] = (
            int(limb["gait_step"]) + requested_offset_ticks + representation_shift_ticks
        )
    return {
        "schema_version": "sporespore_sdk_phase_offset_synchronization_receipt_v2",
        "scheduled": True,
        "requested_offset_ticks": requested_offset_ticks,
        "activation_semantic_step": PHASE_OFFSET_ACTIVATION_STEP,
        "application_count": 1,
        "synchronized_limb_count": 4,
        "gait_step_representation": "nonnegative_u64_cycle_epoch",
        "cycle_steps": 360,
        "common_representation_shift_ticks": representation_shift_ticks,
    }


def _state_frame(
    robot: bridge.MujocoBw19vRobot,
    semantic_step: int,
    task_origin: np.ndarray,
    reference_heading_rad: float,
) -> dict[str, Any]:
    state = robot.state_frame(semantic_step, task_origin)
    forward, lateral = _task_axes(reference_heading_rad)
    state["task_frame"]["forward_axis_world_unit"] = forward
    state["task_frame"]["lateral_axis_world_unit"] = lateral
    state["task_frame"]["reference_yaw_rad"] = reference_heading_rad
    return state


def _foot_contacts(robot: bridge.MujocoBw19vRobot) -> dict[str, bool]:
    return {
        limb_id: bool(
            robot._contact(robot.contact_sites[limb["ordered_contact_site_ids"][0]])[
                "present"
            ]
        )
        for limb_id, limb in robot.limbs.items()
    }


def _physical_report(
    arm_id: str, source_commit: str, contract: dict[str, Any]
) -> dict[str, Any]:
    turn_offset = _arm_offset(contract, arm_id)
    _physical_authorization(contract, arm_id, source_commit)
    perturbation = _initial_perturbation(contract)
    preflight = run_preflight(arm_id)
    core = LocomotionCore()
    attempted = 1
    built = 0
    try:
        robot = bridge.MujocoBw19vRobot(core, HOST_PROFILE_ID)
        built = 1
        perturbation_receipt = _apply_initial_perturbation(robot, perturbation)
        for _ in range(SETTLE_STEPS):
            robot.prepare()
            _zero_prepared_outer_step(robot)
        robot.prepare()
        initial = robot.torso_metrics()
        task_origin = np.asarray(
            [initial["x"], initial["y"], initial["z"]], dtype=np.float64
        )
        reference_heading_rad = float(initial["yaw_rad"])
        controller_memory = core.balanced_wave_initial_memory()
        contacts = _foot_contacts(robot)
        previous_contacts = dict(contacts)
        contact_cycles = {limb_id: 0 for limb_id in contacts}
        counters = {
            "controller_error_count": 0,
            "safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "validated_portable_command_count": 0,
            "native_actuation_application_count": 0,
            "native_validation_step_count": 0,
            "heading_command_conditioned_step_count": 0,
            "portable_impulse_violation_count": 0,
            "torso_ground_contact_step_count": 0,
        }
        maximum_tilt_rad = float(initial["tilt_rad"])
        minimum_torso_height_m = float(initial["y"])
        maximum_requested = 0.0
        maximum_held = 0.0
        turn_held_sum = 0.0
        turn_held_count = 0
        turn_start_yaw: float | None = None
        turn_end_yaw: float | None = None
        phase_offset_receipt: dict[str, Any] | None = None
        segment_counts = {
            "reference_warmup": 0,
            "commanded_turn": 0,
            "reference_recovery": 0,
        }
        for semantic_step in range(CONTROLLER_STEPS):
            if semantic_step == PHASE_OFFSET_ACTIVATION_STEP:
                phase_offset_receipt = _phase_offset(
                    controller_memory,
                    int(perturbation["gait_phase_offset_ticks"]),
                )
            if semantic_step == CONTACT_GATED_START_STEP:
                for limb in controller_memory["ordered_limb_memory"]:
                    limb["evidence_gait_step_limit"] = (
                        int(limb["gait_step"]) + 1 + 1_440
                    )
            phase_mode = (
                "clocked"
                if semantic_step < CONTACT_GATED_START_STEP
                else "contact_gated"
            )
            state = _state_frame(
                robot,
                semantic_step,
                task_origin,
                reference_heading_rad,
            )
            state_numbers = [
                float(state["base_pose_world"]["position_m"][axis])
                for axis in ("x", "y", "z")
            ]
            counters["nonfinite_observation_count"] += int(
                not np.isfinite(state_numbers).all()
            )
            heading = _heading_receipt(
                semantic_step, reference_heading_rad, turn_offset
            )
            if semantic_step == TURN_START_STEP:
                turn_start_yaw = float(robot.torso_metrics()["yaw_rad"])
            if heading["declared_segment"]:
                segment_counts[heading["segment_id"]] += 1
            output = core.balanced_wave_policy_step(
                POLICY_ID,
                {
                    "descriptor": bridge.s169_descriptor(),
                    "memory": controller_memory,
                    "state": state,
                    "command": _motion_command(semantic_step, phase_mode, heading),
                },
            )
            actuation = output["actuation"]
            receipt = actuation["receipt"]
            counters["controller_error_count"] += int(
                receipt["controller_error"] is not None
            ) + len(actuation["failure_codes"])
            counters["safe_no_actuation_count"] += int(
                bool(actuation["safe_no_actuation"])
            )
            canonical = core.canonical_velocity_compose_v1(
                {
                    "schema_version": "sporespore_canonical_velocity_compose_request_v1",
                    "descriptor": bridge.s169_descriptor(),
                    "source_actuation": actuation,
                    "ordered_stability_residuals": _zero_residuals(actuation),
                }
            )
            mapping = core.canonical_velocity_host_map_v1(
                {
                    "schema_version": "sporespore_canonical_velocity_host_map_request_v1",
                    "descriptor": bridge.s169_descriptor(),
                    "canonical_actuation": canonical,
                    "host_profile": bridge._mujoco_host_profile(HOST_PROFILE_ID),
                }
            )
            ordered_ids = list(robot.morphology["ordered_actuator_ids"])
            native_valid = (
                receipt["semantic_step"] == semantic_step
                and receipt["command_id"] == f"{SCHEDULE_ID}_{heading['segment_id']}"
                and math.isclose(
                    float(receipt["desired_heading_error_rad"]),
                    float(heading["heading_offset_rad"]),
                    rel_tol=0.0,
                    abs_tol=1.0e-12,
                )
                and mapping["host_profile_id"] == HOST_PROFILE_ID
                and mapping["native_position_stiffness"] == 0.0
                and mapping["independent_native_position_feedback_applied"] is False
                and [command["actuator_id"] for command in mapping["ordered_commands"]]
                == ordered_ids
                and all(
                    command["native_target_position_rad"] is None
                    and command["host_clamped"] is False
                    for command in mapping["ordered_commands"]
                )
            )
            if not native_valid:
                raise QsdkR23d1WorkerError(
                    "QSDK_R23D1_MJC_NATIVE_STEP_INVALID",
                    world_attempt_count=1,
                    world_build_count=1,
                )
            requested = float(receipt["requested_steering_fraction"])
            held = float(receipt["held_steering_fraction"])
            maximum_requested = max(maximum_requested, abs(requested))
            maximum_held = max(maximum_held, abs(held))
            if TURN_START_STEP <= semantic_step < TURN_END_STEP_EXCLUSIVE:
                turn_held_sum += held
                turn_held_count += 1
            counters["validated_portable_command_count"] += len(
                actuation["ordered_commands"]
            )
            application = robot.apply_host_mapping(mapping)
            application_count = len(application["targets"])
            violations = int(application["portable_impulse_violation_count"])
            counters["native_actuation_application_count"] += application_count
            counters["portable_impulse_violation_count"] += violations
            counters["actuator_application_mismatch_count"] += int(
                application_count != 8
            )
            if application_count == 8 and violations == 0:
                counters["native_validation_step_count"] += 1
                counters["heading_command_conditioned_step_count"] += 1
            controller_memory = output["next_memory"]
            robot.prepare()
            metrics = robot.torso_metrics()
            if semantic_step + 1 == TURN_END_STEP_EXCLUSIVE:
                turn_end_yaw = float(metrics["yaw_rad"])
            metric_values = [
                float(metrics[key]) for key in ("x", "y", "z", "tilt_rad", "yaw_rad")
            ]
            counters["nonfinite_observation_count"] += int(
                not np.isfinite(metric_values).all()
            )
            maximum_tilt_rad = max(maximum_tilt_rad, float(metrics["tilt_rad"]))
            minimum_torso_height_m = min(minimum_torso_height_m, float(metrics["y"]))
            counters["torso_ground_contact_step_count"] += int(
                bool(metrics["ground_contact"])
            )
            if semantic_step >= CONTACT_GATED_START_STEP:
                contacts = _foot_contacts(robot)
                for limb_id, present in contacts.items():
                    if not previous_contacts[limb_id] and present:
                        contact_cycles[limb_id] += 1
                    previous_contacts[limb_id] = present
        for _ in range(TERMINAL_SETTLE_STEPS):
            _zero_prepared_outer_step(robot)
            robot.prepare()
            metrics = robot.torso_metrics()
            maximum_tilt_rad = max(maximum_tilt_rad, float(metrics["tilt_rad"]))
            minimum_torso_height_m = min(minimum_torso_height_m, float(metrics["y"]))
            counters["torso_ground_contact_step_count"] += int(
                bool(metrics["ground_contact"])
            )
        final = robot.torso_metrics()
        final_delta = (
            np.asarray([final["x"], final["y"], final["z"]], dtype=np.float64)
            - task_origin
        )
        task_forward = np.asarray(
            [math.cos(reference_heading_rad), 0.0, math.sin(reference_heading_rad)],
            dtype=np.float64,
        )
        final_forward_displacement_m = float(final_delta @ task_forward)
        final_reference_heading_error_rad = _wrap_angle(
            float(final["yaw_rad"]) - reference_heading_rad
        )
        if turn_start_yaw is None or turn_end_yaw is None or turn_held_count == 0:
            raise QsdkR23d1WorkerError(
                "QSDK_R23D1_MJC_TURN_WINDOW_INCOMPLETE",
                world_attempt_count=1,
                world_build_count=1,
            )
        turn_phase_yaw_delta_rad = _wrap_angle(turn_end_yaw - turn_start_yaw)
        mean_turn_held_steering_fraction = turn_held_sum / turn_held_count
        contacts_pass = all(
            count >= MINIMUM_CONTACT_CYCLES_PER_LIMB
            for count in contact_cycles.values()
        )
        integrity_pass = (
            counters["controller_error_count"] == 0
            and counters["safe_no_actuation_count"] == 0
            and counters["nonfinite_observation_count"] == 0
            and counters["actuator_application_mismatch_count"] == 0
            and counters["portable_impulse_violation_count"] == 0
            and counters["validated_portable_command_count"] == CONTROLLER_STEPS * 8
            and counters["native_actuation_application_count"] == CONTROLLER_STEPS * 8
            and counters["native_validation_step_count"] == CONTROLLER_STEPS
            and counters["heading_command_conditioned_step_count"] == CONTROLLER_STEPS
        )
        walking_gate = (
            integrity_pass
            and counters["torso_ground_contact_step_count"] == 0
            and maximum_tilt_rad <= MAXIMUM_TILT_RAD
            and minimum_torso_height_m >= MINIMUM_TORSO_HEIGHT_M
            and final_forward_displacement_m >= MINIMUM_FINAL_FORWARD_DISPLACEMENT_M
            and contacts_pass
        )
        report = {
            "schema_version": REPORT_SCHEMA,
            "campaign_id": CAMPAIGN_ID,
            "gate_id": GATE_ID,
            "engine_id": ENGINE_ID,
            "arm_id": arm_id,
            "cell_id": f"{ENGINE_ID}__{arm_id}",
            "selected_policy_id": POLICY_ID,
            "selected_policy_digest": POLICY_DIGEST,
            "morphology_id": MORPHOLOGY_ID,
            "campaign_seed": CAMPAIGN_SEED,
            "contract_sha256": _raw_sha256(CONTRACT_PATH),
            "source_commit": source_commit,
            "execution": {
                "world_attempt_count": attempted,
                "world_build_count": built,
                "world_reset_count": 0,
                "direct_body_write_count": 0,
                "controller_error_count": counters["controller_error_count"],
                "safe_no_actuation_count": counters["safe_no_actuation_count"],
                "nonfinite_observation_count": counters["nonfinite_observation_count"],
                "actuator_application_mismatch_count": counters[
                    "actuator_application_mismatch_count"
                ],
                "controller_semantic_step_count": CONTROLLER_STEPS,
                "validated_portable_command_count": counters[
                    "validated_portable_command_count"
                ],
                "native_actuation_application_count": counters[
                    "native_actuation_application_count"
                ],
            },
            "command_validation": {
                "schema_version": COMMAND_VALIDATION_SCHEMA,
                "normalized_validation_mode": NORMALIZED_VALIDATION_MODE,
                "source_validation_mode": SOURCE_VALIDATION_MODE,
                "native_validation_step_count": counters[
                    "native_validation_step_count"
                ],
                "heading_command_conditioned_step_count": counters[
                    "heading_command_conditioned_step_count"
                ],
                "unconditioned_step_count": CONTROLLER_STEPS
                - counters["heading_command_conditioned_step_count"],
                "legacy_command_parity_applicable": False,
                "legacy_command_parity_checked_step_count": 0,
                "legacy_command_parity_waived_step_count": 0,
            },
            "schedule": {
                "schedule_id": SCHEDULE_ID,
                "observed_segment_sample_counts": segment_counts,
                "turn_heading_offset_rad": turn_offset,
                "reference_heading_sample_count": 1_200,
                "turn_heading_sample_count": 1_200,
                "phase_offset_synchronization_receipt": phase_offset_receipt,
            },
            "controller": {
                "maximum_absolute_requested_steering_fraction": maximum_requested,
                "maximum_absolute_held_steering_fraction": maximum_held,
                "mean_turn_held_steering_fraction": mean_turn_held_steering_fraction,
            },
            "physics": {
                "turn_phase_yaw_delta_rad": turn_phase_yaw_delta_rad,
                "final_reference_heading_error_rad": final_reference_heading_error_rad,
                "final_forward_displacement_m": final_forward_displacement_m,
                "maximum_tilt_rad": maximum_tilt_rad,
                "minimum_torso_height_m": minimum_torso_height_m,
                "torso_ground_contact_step_count": counters[
                    "torso_ground_contact_step_count"
                ],
                "contact_cycles_by_limb": contact_cycles,
                "engine_production_straight_walking_gate_passed": walking_gate,
                "commanded_turn_walk_gate_passed": walking_gate,
            },
            "host": {
                "adapter_id": bridge.ADAPTER_ID,
                "adapter_capability_sha256": capability_manifest_sha256(),
                "engine_version": mujoco.__version__,
                "physics_hz": PHYSICS_HZ,
                "internal_timestep_s": bridge.INTERNAL_DT_S,
                "internal_steps_per_controller_step": bridge.INTERNAL_STEPS_PER_OUTER,
                "authored_friction": bridge.AUTHORED_FRICTION,
                "velocity_only_profile_id": HOST_PROFILE_ID,
                "native_motor_model_id": (
                    "velocity_servo_s169_per_actuator_force_limited_five_substep_"
                    "vh5_validated_v1"
                ),
                "native_position_target_application_count": 0,
                "portable_impulse_violation_count": counters[
                    "portable_impulse_violation_count"
                ],
                "initial_perturbation": perturbation,
                "initial_perturbation_receipt": perturbation_receipt,
                "preflight": preflight,
            },
            "claims": {
                "development_screen_only": True,
                "q_sdk_r23_satisfied": False,
                "command_conditioned_turning": False,
                "cross_engine_equivalence": False,
                "release_authorized": False,
                "physical_acceptance_authority": False,
            },
        }
        json.dumps(report, allow_nan=False)
        return report
    except QsdkR23d1WorkerError:
        raise
    except Exception as error:
        raise QsdkR23d1WorkerError(
            f"QSDK_R23D1_MJC_PHYSICAL_WORKER_ERROR:{type(error).__name__}:{error}",
            world_attempt_count=attempted,
            world_build_count=built,
        ) from error


def run_physical(arm_id: str, source_commit: str) -> dict[str, Any]:
    if not _valid_lower_hex(source_commit, 40):
        raise QsdkR23d1WorkerError("QSDK_R23D1_MJC_SOURCE_COMMIT_INVALID")
    if PHYSICAL_IDENTITY_CLOSED:
        raise QsdkR23d1WorkerError("QSDK_R23D1_MJC_PHYSICAL_IDENTITY_CLOSED")
    contract = _contract()
    _arm_offset(contract, arm_id)
    return _physical_report(arm_id, source_commit, contract)


def _failure(error: QsdkR23d1WorkerError, arm_id: str | None) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_qsdk_r23d1_mujoco_worker_failure_v1",
        "engine_id": ENGINE_ID,
        "arm_id": arm_id,
        "failure_code": error.code,
        "world_attempt_count": error.world_attempt_count,
        "world_build_count": error.world_build_count,
        "physical_acceptance_authority": False,
        "release_authorized": False,
    }


def _arguments(arguments: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--arm",
        required=True,
        choices=(
            "reference_zero",
            "positive_heading",
            "negative_heading",
            "undeclared_arm",
        ),
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preflight-only", action="store_true")
    mode.add_argument("--source-commit")
    return parser.parse_args(arguments)


def main(arguments: Iterable[str] | None = None) -> int:
    args = _arguments(arguments)
    try:
        report = (
            run_preflight(args.arm)
            if args.preflight_only
            else run_physical(args.arm, args.source_commit)
        )
    except QsdkR23d1WorkerError as error:
        print(
            "QSDK_R23D1_MUJOCO_FAILURE "
            + json.dumps(_failure(error, args.arm), sort_keys=True, allow_nan=False)
        )
        return 1
    prefix = (
        "QSDK_R23D1_MUJOCO_PREFLIGHT "
        if args.preflight_only
        else "QSDK_R23D1_MUJOCO_CELL "
    )
    print(prefix + json.dumps(report, sort_keys=True, allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
