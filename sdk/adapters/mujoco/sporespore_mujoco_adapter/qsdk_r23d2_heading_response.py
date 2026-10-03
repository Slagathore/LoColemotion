"""QSDK-R23D2 MuJoCo heading-response worker.

This consumed successor crossed the public core dynamic library, selected
BW5R-B controller, canonical velocity mapper, VH5-characterized MuJoCo host
profile, and production model-XML compiler. Its retained physical loop remains
inspectable, but the entry point now refuses before model construction because
the sole shared aggregate identity is closed. Any new experiment is R23D3.
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
ORACLE_PATH = SDK_ROOT / "turning" / "r23d2_oracle_preregistration.json"
WORKER_CONTRACT_PATH = SDK_ROOT / "turning" / "r23d2_mujoco_worker_contract_v1.json"
DEVELOPMENT_CONTRACT_PATH = SDK_ROOT / "turning" / "r23d2_development_contract_v1.json"
CAMPAIGN_ID = "QSDK-R23D2-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
GATE_ID = "QSDK-R23D2-MJC"
PARENT_GATE_ID = "QSDK-R23D2"
ENGINE_ID = "mujoco"
PHYSICAL_IDENTITY_CLOSED = True
POLICY_ID = "sporespore_balanced_wave_bw5r_b_v1"
POLICY_DIGEST = (
    "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
)
MORPHOLOGY_ID = "qsdk_r05_generated_s169"
HOST_PROFILE_ID = bridge.PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID
NATIVE_MOTOR_MODEL_ID = (
    "velocity_servo_s169_per_actuator_force_limited_five_substep_" "vh5_validated_v1"
)
PREFLIGHT_SCHEMA = "sporespore_qsdk_r23d2_mujoco_worker_preflight_v1"
REPORT_SCHEMA = "sporespore_qsdk_r23d2_engine_cell_report_v1"
WORKER_FAILURE_SCHEMA = "sporespore_qsdk_r23d2_worker_failure_v1"
COMMAND_VALIDATION_SCHEMA = "sporespore_qsdk_r23d2_command_validation_v1"
EXECUTION_STAGE_SCHEMA = "sporespore_qsdk_r23d2_execution_stage_v1"
NORMALIZED_VALIDATION_MODE = (
    "native_adapter_structure_receipts_and_independent_heading_oracle_v1"
)
SOURCE_VALIDATION_MODE = (
    "mujoco_vh5_characterized_velocity_only_mapping_receipt_and_"
    "independent_oracle_v1"
)
SCHEDULE_ID = "qsdk_r23d1_step_turn_return_v1"
TOLERANCE = 1.0e-12
COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID = (
    "command_heading_aligned_task_frame_v1"
)
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
MINIMUM_FINAL_FORWARD_DISPLACEMENT_M = 0.030_123_046_875
MAXIMUM_TILT_RAD = 0.6
MINIMUM_TORSO_HEIGHT_M = 0.249_970_865_207_294_6
MINIMUM_CONTACT_CYCLES_PER_LIMB = 2

ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D2_ATTEMPT"
AUTHORIZATION_TOKEN_ENV = "SPORESPORE_QSDK_R23D2_TOKEN"
CELL_ID_ENV = "SPORESPORE_QSDK_R23D2_CELL"
ENGINE_ID_ENV = "SPORESPORE_QSDK_R23D2_ENGINE"
RECEIPT_FIELDS = (
    "cross_track_error_m",
    "cross_track_velocity_m_s",
    "measured_yaw_error_rad",
    "desired_heading_error_rad",
    "yaw_tracking_error_rad",
)


class QsdkR23d2MujocoWorkerError(RuntimeError):
    """Fail-closed worker error with explicit attempt/build/model provenance."""

    def __init__(
        self,
        code: str,
        *,
        world_attempt_count: int = 0,
        world_build_count: int = 0,
        model_construction_count: int = 0,
    ) -> None:
        super().__init__(code)
        self.code = code
        self.world_attempt_count = world_attempt_count
        self.world_build_count = world_build_count
        self.model_construction_count = model_construction_count


class QsdkR23d2MujocoPhysicalFailure(QsdkR23d2MujocoWorkerError):
    """A terminal evaluator-shaped physical failure receipt."""

    def __init__(self, receipt: dict[str, Any]) -> None:
        super().__init__(
            str(receipt["process_failure_code"]),
            world_attempt_count=int(receipt["world_attempt_count"]),
            world_build_count=int(receipt["world_build_count"]),
            model_construction_count=int(receipt["world_build_count"]),
        )
        self.receipt = receipt


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _json_sha256(value: Any) -> str:
    raw = json.dumps(
        value, sort_keys=True, separators=(",", ":"), allow_nan=False
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _wrap_angle(value: float) -> float:
    return (value + math.pi) % math.tau - math.pi


def _finite(value: Any, field: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise QsdkR23d2MujocoWorkerError(f"QSDK_R23D2_MJC_{field}_INVALID")
    number = float(value)
    if not math.isfinite(number):
        raise QsdkR23d2MujocoWorkerError(f"QSDK_R23D2_MJC_{field}_INVALID")
    return number


def _vec3(value: Any, field: str) -> dict[str, float]:
    if not isinstance(value, list) or len(value) != 3:
        raise QsdkR23d2MujocoWorkerError(f"QSDK_R23D2_MJC_{field}_INVALID")
    return {
        "x": _finite(value[0], field),
        "y": _finite(value[1], field),
        "z": _finite(value[2], field),
    }


def _contracts() -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    oracle = json.loads(ORACLE_PATH.read_text(encoding="utf-8"))
    worker = json.loads(WORKER_CONTRACT_PATH.read_text(encoding="utf-8"))
    development = json.loads(DEVELOPMENT_CONTRACT_PATH.read_text(encoding="utf-8"))
    development_engine = next(
        (
            engine
            for engine in development.get("engines", [])
            if engine.get("engine_id") == ENGINE_ID
        ),
        None,
    )
    exact = (
        oracle.get("schema_version")
        == "sporespore_qsdk_r23d2_oracle_preregistration_v1"
        and oracle.get("campaign_id") == CAMPAIGN_ID
        and oracle.get("gate_id") == "QSDK-R23D2"
        and oracle.get("authorization", {}).get("physical_execution_authorized")
        is False
        and len(oracle.get("oracle_canaries", [])) == 7
        and worker.get("schema_version")
        == "sporespore_qsdk_r23d2_mujoco_worker_contract_v1"
        and worker.get("campaign_id") == CAMPAIGN_ID
        and worker.get("gate_id") == GATE_ID
        and worker.get("stage_zero_oracle", {}).get("sha256")
        == _raw_sha256(ORACLE_PATH)
        and worker.get("engine", {}).get("engine_id") == ENGINE_ID
        and worker.get("engine", {}).get("adapter_id") == bridge.ADAPTER_ID
        and worker.get("engine", {}).get("engine_version") == mujoco.__version__
        and worker.get("engine", {}).get("host_profile_id") == HOST_PROFILE_ID
        and worker.get("engine", {}).get("native_motor_model_id")
        == NATIVE_MOTOR_MODEL_ID
        and worker.get("worker", {}).get("implementation_path")
        == (
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
            "qsdk_r23d2_heading_response.py"
        )
        and worker.get("worker", {}).get("test_path")
        == "sdk/adapters/mujoco/test_qsdk_r23d2_heading_response.py"
        and worker.get("worker", {}).get("preflight_path")
        == "sdk/run_qsdk_r23d2_mujoco_worker_preflight.ps1"
        and worker.get("status") == "mujoco_supervisor_only_physical_authorized"
        and worker.get("future_physical_requirements", {}).get(
            "physical_implementation_present"
        )
        is True
        and worker.get("future_physical_requirements", {}).get(
            "successful_report_canary_per_arm"
        )
        is True
        and worker.get("future_physical_requirements", {}).get(
            "all_six_failure_stage_canaries_per_arm"
        )
        is True
        and worker.get("authorization", {}).get("physical_execution_authorized") is True
        and worker.get("authorization", {}).get("model_construction_count") == 0
        and worker.get("authorization", {}).get("world_build_count") == 0
        and development.get("schema_version")
        == "sporespore_qsdk_r23d2_development_contract_v1"
        and development.get("status")
        == "frozen_supervisor_only_physical_authorized_pending_exact_source_attestation"
        and development.get("campaign_id") == CAMPAIGN_ID
        and development.get("gate_id") == PARENT_GATE_ID
        and development.get("source_contract", {}).get("selected_policy_id")
        == POLICY_ID
        and development.get("source_contract", {}).get("selected_policy_digest")
        == POLICY_DIGEST
        and development.get("fixture", {}).get("morphology_id") == MORPHOLOGY_ID
        and development.get("fixture", {}).get("initial_condition_seed")
        == CAMPAIGN_SEED
        and development.get("fixture", {}).get("physics_hz") == PHYSICS_HZ
        and development.get("fixture", {}).get("authored_sliding_friction")
        == bridge.AUTHORED_FRICTION
        and isinstance(development_engine, dict)
        and development_engine.get("worker_contract_sha256")
        == _raw_sha256(WORKER_CONTRACT_PATH)
        and development_engine.get("physical_implementation_present") is True
        and development.get("claim_boundary", {}).get(
            "physical_worker_implementation_count"
        )
        == 3
        and development.get("claim_boundary", {}).get("physical_workers_complete")
        is True
        and development.get("normalized_entry_contract", {}).get(
            "successful_report_schema_version"
        )
        == REPORT_SCHEMA
        and development.get("normalized_entry_contract", {}).get(
            "worker_failure_schema_version"
        )
        == WORKER_FAILURE_SCHEMA
        and development.get("normalized_entry_contract", {}).get(
            "command_validation_schema_version"
        )
        == COMMAND_VALIDATION_SCHEMA
        and development.get("normalized_entry_contract", {}).get(
            "execution_stage_schema_version"
        )
        == EXECUTION_STAGE_SCHEMA
        and development.get("normalized_entry_contract", {}).get(
            "normalized_validation_mode"
        )
        == NORMALIZED_VALIDATION_MODE
        and development.get("authorization", {}).get("physical_execution_authorized")
        is True
    )
    if not exact:
        raise QsdkR23d2MujocoWorkerError("QSDK_R23D2_MJC_CONTRACT_IDENTITY_INVALID")
    return oracle, worker, development


def _arm_offset(arm_id: str) -> float:
    offsets = {
        "reference_zero": 0.0,
        "positive_heading": 0.2,
        "negative_heading": -0.2,
    }
    try:
        return offsets[arm_id]
    except KeyError as error:
        raise QsdkR23d2MujocoWorkerError(
            f"QSDK_R23D2_MJC_ARM_UNKNOWN:{arm_id}"
        ) from error


def _compile_boundary(
    core: LocomotionCore,
    policy_id: str = POLICY_ID,
) -> tuple[dict[str, Any], dict[str, Any]]:
    descriptor = bridge.s169_descriptor()
    compiled = core.compile_bounded_quadruped(descriptor)
    profile = core.balanced_wave_policy_profile(policy_id, descriptor)
    if (
        compiled.get("world_build_count") != 0
        or compiled.get("morphology", {}).get("world_build_count") != 0
        or compiled.get("morphology_id") != MORPHOLOGY_ID
        or profile.get("policy_id") != policy_id
        or profile.get("physical_acceptance_authority") is not False
    ):
        raise QsdkR23d2MujocoWorkerError("QSDK_R23D2_MJC_PORTABLE_BOUNDARY_INVALID")
    return compiled, profile


def _orientation(heading_rad: float) -> dict[str, float]:
    return {
        "x": 0.0,
        "y": -math.sin(heading_rad / 2.0),
        "z": 0.0,
        "w": math.cos(heading_rad / 2.0),
    }


def _state_for_canary(
    compiled: dict[str, Any], canary: dict[str, Any]
) -> dict[str, Any]:
    morphology = compiled["morphology"]
    lateral = _vec3(canary.get("task_lateral_axis_world_unit"), "LATERAL_AXIS")
    forward = {"x": lateral["z"], "y": 0.0, "z": -lateral["x"]}
    return {
        "schema_version": "sporespore_state_frame_v1",
        "semantic_step": 0,
        "sample_time_s": 0.0,
        "base_pose_world": {
            "position_m": _vec3(canary.get("base_position_world_m"), "POSITION"),
            "orientation_xyzw": _orientation(
                _finite(canary.get("measured_heading_world_rad"), "MEASURED_HEADING")
            ),
        },
        "base_twist_world": {
            "linear_velocity_m_s": _vec3(
                canary.get("base_linear_velocity_world_m_s"), "LINEAR_VELOCITY"
            ),
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
                    "engine_contact_ids": [f"{contact_id}_r23d2_zero_world"],
                    "aggregation_rule_id": "qualified_bearing_only",
                    "quality": "qualified_bearing",
                },
            }
            for contact_id in morphology["ordered_contact_site_ids"]
        ],
        "previous_applied_actuation": None,
        "gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
        "task_frame": {
            "origin_world_m": _vec3(canary.get("task_origin_world_m"), "TASK_ORIGIN"),
            "forward_axis_world_unit": forward,
            "lateral_axis_world_unit": lateral,
            "up_axis_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
            "reference_yaw_rad": _finite(
                canary.get("reference_yaw_rad"), "REFERENCE_YAW"
            ),
        },
        "adapter_capability_sha256": capability_manifest_sha256(),
    }


def _command(command_id: str, desired_heading_rad: float) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_motion_command_v2",
        "command_id": command_id,
        "desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
        "desired_heading_rad": desired_heading_rad,
        "desired_yaw_rate_rad_s": None,
        "gait_family_id": "lateral_wave",
        "speed_class": "walk",
        "gait_amplitude": 1.0,
        "phase_progression_mode": "clocked",
        "valid_from_step": 0,
        "valid_through_step": 0,
        "authority": "test_fixture",
    }


def _dot(first: dict[str, float], second: dict[str, float]) -> float:
    return sum(first[axis] * second[axis] for axis in ("x", "y", "z"))


def _independent_oracle(
    state: dict[str, Any], command: dict[str, Any], profile: dict[str, Any]
) -> dict[str, float]:
    position = state["base_pose_world"]["position_m"]
    origin = state["task_frame"]["origin_world_m"]
    displacement = {
        axis: float(position[axis]) - float(origin[axis]) for axis in ("x", "y", "z")
    }
    reference_yaw = float(state["task_frame"]["reference_yaw_rad"])
    requested_error = _wrap_angle(float(command["desired_heading_rad"]) - reference_yaw)
    lateral = state["task_frame"]["lateral_axis_world_unit"]
    frame_mode = profile.get("cross_track_frame_mode_id")
    if frame_mode == COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID:
        forward = state["task_frame"]["forward_axis_world_unit"]
        cosine = math.cos(requested_error)
        sine = math.sin(requested_error)
        lateral = {
            axis: -sine * float(forward[axis]) + cosine * float(lateral[axis])
            for axis in ("x", "y", "z")
        }
    elif frame_mode is not None:
        raise RuntimeError(f"QSDK_R23D2_MJC_CROSS_TRACK_FRAME_MODE:{frame_mode}")
    cross_track_error = _dot(displacement, lateral)
    cross_track_velocity = _dot(
        state["base_twist_world"]["linear_velocity_m_s"], lateral
    )
    quaternion = state["base_pose_world"]["orientation_xyzw"]
    forward_x = 1.0 - 2.0 * (float(quaternion["y"]) ** 2 + float(quaternion["z"]) ** 2)
    forward_z = 2.0 * (
        float(quaternion["x"]) * float(quaternion["z"])
        - float(quaternion["w"]) * float(quaternion["y"])
    )
    measured_heading = math.atan2(forward_z, forward_x)
    measured_error = _wrap_angle(measured_heading - reference_yaw)
    desired_error = max(
        -0.25,
        min(
            0.25,
            requested_error
            - float(profile["cross_track_heading_gain_rad_per_m"]) * cross_track_error
            - float(profile["cross_track_velocity_heading_gain_rad_per_m_s"])
            * cross_track_velocity,
        ),
    )
    return {
        "cross_track_error_m": cross_track_error,
        "cross_track_velocity_m_s": cross_track_velocity,
        "measured_yaw_error_rad": measured_error,
        "desired_heading_error_rad": desired_error,
        "yaw_tracking_error_rad": _wrap_angle(measured_error - desired_error),
    }


def _predicate_failures(
    expected: dict[str, float], observed: dict[str, Any]
) -> list[str]:
    failures: list[str] = []
    for field in RECEIPT_FIELDS:
        value = observed.get(field)
        if (
            isinstance(value, bool)
            or not isinstance(value, (int, float))
            or not math.isfinite(float(value))
            or abs(float(value) - expected[field]) > TOLERANCE
        ):
            failures.append(f"{field}:mismatch")
    return failures


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


def _controller_and_mapping(
    core: LocomotionCore,
    compiled: dict[str, Any],
    state: dict[str, Any],
    command: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    output = core.balanced_wave_policy_step(
        POLICY_ID,
        {
            "descriptor": bridge.s169_descriptor(),
            "memory": core.balanced_wave_initial_memory(),
            "state": state,
            "command": command,
        },
    )
    actuation = output["actuation"]
    receipt = actuation["receipt"]
    ordered_ids = list(compiled["morphology"]["ordered_actuator_ids"])
    if (
        actuation.get("safe_no_actuation") is not False
        or actuation.get("failure_codes") != []
        or receipt.get("controller_error") is not None
        or receipt.get("policy_id") != POLICY_ID
        or receipt.get("command_id") != command["command_id"]
        or receipt.get("world_build_count") != 0
        or receipt.get("physical_acceptance_authority") is not False
        or [item["actuator_id"] for item in actuation["ordered_commands"]]
        != ordered_ids
        or len(actuation["ordered_commands"]) != 8
    ):
        raise QsdkR23d2MujocoWorkerError("QSDK_R23D2_MJC_CONTROLLER_OUTPUT_INVALID")
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
        mapping.get("host_profile_id") != HOST_PROFILE_ID
        or mapping.get("engine_id") != ENGINE_ID
        or mapping.get("native_position_stiffness") != 0.0
        or mapping.get("independent_native_position_feedback_applied") is not False
        or mapping.get("host_response_characterized_for_this_profile") is not True
        or [item["actuator_id"] for item in commands] != ordered_ids
        or len(commands) != 8
        or any(
            item["native_target_position_rad"] is not None
            or item["host_clamped"] is not False
            or not math.isfinite(float(item["host_target_velocity_rad_s"]))
            for item in commands
        )
    ):
        raise QsdkR23d2MujocoWorkerError("QSDK_R23D2_MJC_NATIVE_MAPPING_INVALID")
    return receipt, mapping


def _model_xml_receipt(compiled: dict[str, Any]) -> dict[str, Any]:
    model_xml = bridge.build_model_xml(compiled, HOST_PROFILE_ID)
    root = ET.fromstring(model_xml)
    actuator_root = root.find("actuator")
    if actuator_root is None:
        raise QsdkR23d2MujocoWorkerError(
            "QSDK_R23D2_MJC_MODEL_XML_ACTUATOR_ROOT_MISSING"
        )
    actuators = list(actuator_root)
    morphology = compiled["morphology"]
    specs = {
        actuator["actuator_id"]: actuator
        for actuator in morphology["morphology_spec"]["actuators"]
    }
    ordered_limits: dict[str, float] = {}
    if len(actuators) != 8:
        raise QsdkR23d2MujocoWorkerError(
            "QSDK_R23D2_MJC_MODEL_XML_ACTUATOR_COUNT_INVALID"
        )
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
            raise QsdkR23d2MujocoWorkerError(
                f"QSDK_R23D2_MJC_MODEL_XML_ACTUATOR_INVALID:{expected_id}"
            )
        ordered_limits[expected_id] = expected_limit
    return {
        "schema_version": "sporespore_qsdk_r23d2_mujoco_model_xml_receipt_v1",
        "engine_version": mujoco.__version__,
        "model_xml_sha256": "sha256:"
        + hashlib.sha256(model_xml.encode("utf-8")).hexdigest(),
        "native_actuator_count": 8,
        "native_actuator_order_exact": True,
        "native_motor_model_id": NATIVE_MOTOR_MODEL_ID,
        "velocity_gain_nm_s_per_rad": bridge.VELOCITY_GAIN,
        "internal_timestep_s": bridge.INTERNAL_DT_S,
        "internal_steps_per_controller_step": bridge.INTERNAL_STEPS_PER_OUTER,
        "ordered_native_force_limits_nm": ordered_limits,
        "model_construction_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _claims() -> dict[str, bool]:
    return {
        "development_screen_only": True,
        "q_sdk_r23_satisfied": False,
        "command_conditioned_turning": False,
        "cross_engine_equivalence": False,
        "release_authorized": False,
        "physical_acceptance_authority": False,
    }


def _xyz_list(value: dict[str, Any]) -> list[float]:
    return [float(value[axis]) for axis in ("x", "y", "z")]


def _measured_heading(state: dict[str, Any]) -> float:
    quaternion = state["base_pose_world"]["orientation_xyzw"]
    forward_x = 1.0 - 2.0 * (float(quaternion["y"]) ** 2 + float(quaternion["z"]) ** 2)
    forward_z = 2.0 * (
        float(quaternion["x"]) * float(quaternion["z"])
        - float(quaternion["w"]) * float(quaternion["y"])
    )
    return math.atan2(forward_z, forward_x)


def _oracle_state_projection(state: dict[str, Any]) -> dict[str, Any]:
    return {
        "reference_yaw_rad": float(state["task_frame"]["reference_yaw_rad"]),
        "measured_heading_world_rad": _measured_heading(state),
        "task_origin_world_m": _xyz_list(state["task_frame"]["origin_world_m"]),
        "task_lateral_axis_world_unit": _xyz_list(
            state["task_frame"]["lateral_axis_world_unit"]
        ),
        "base_position_world_m": _xyz_list(state["base_pose_world"]["position_m"]),
        "base_linear_velocity_world_m_s": _xyz_list(
            state["base_twist_world"]["linear_velocity_m_s"]
        ),
    }


def _receipt_projection(receipt: dict[str, Any]) -> dict[str, Any]:
    return {field: receipt.get(field) for field in RECEIPT_FIELDS}


def _oracle_evaluation(
    expected: dict[str, float], observed: dict[str, Any]
) -> dict[str, Any]:
    failures = _predicate_failures(expected, observed)
    return {
        "schema_version": "sporespore_qsdk_r23d2_oracle_evaluation_v1",
        "ok": not failures,
        "failed_predicates": failures,
        "expected_receipt": dict(expected),
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _worker_failure(
    arm_id: str,
    source_commit: str,
    stage_id: str,
    world_attempt_count: int,
    world_build_count: int,
    process_failure_code: str,
    controller_failure: (
        tuple[dict[str, Any], dict[str, Any], dict[str, Any]] | None
    ) = None,
) -> dict[str, Any]:
    projection: dict[str, Any] | None = None
    oracle_input: dict[str, Any] | None = None
    evaluation: dict[str, Any] | None = None
    if controller_failure is not None:
        projection, oracle_input, evaluation = controller_failure
    return {
        "schema_version": WORKER_FAILURE_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": PARENT_GATE_ID,
        "cell_id": f"{ENGINE_ID}__{arm_id}",
        "engine_id": ENGINE_ID,
        "arm_id": arm_id,
        "source_commit": source_commit,
        "contract_sha256": _raw_sha256(DEVELOPMENT_CONTRACT_PATH),
        "stage_id": stage_id,
        "world_attempt_count": world_attempt_count,
        "world_build_count": world_build_count,
        "process_failure_code": process_failure_code,
        "rejected_controller_projection": projection,
        "oracle_input": oracle_input,
        "oracle_evaluation": evaluation,
        "rejected_projection_retention": {
            "schema_version": (
                "sporespore_qsdk_r23d2_rejected_projection_retention_v1"
            ),
            "embedded_before_exit": projection is not None,
            "payload_sha256": (
                _json_sha256(projection) if projection is not None else None
            ),
            "content_addressed_by_supervisor_before_aggregation_required": True,
        },
        "claims": _claims(),
    }


def _compose_physical_report(
    arm_id: str,
    source_commit: str,
    turn_heading_offset_rad: float,
    metrics: dict[str, Any],
) -> dict[str, Any]:
    return {
        "schema_version": REPORT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": PARENT_GATE_ID,
        "cell_id": f"{ENGINE_ID}__{arm_id}",
        "engine_id": ENGINE_ID,
        "arm_id": arm_id,
        "source_commit": source_commit,
        "contract_sha256": _raw_sha256(DEVELOPMENT_CONTRACT_PATH),
        "selected_policy_id": POLICY_ID,
        "selected_policy_digest": POLICY_DIGEST,
        "morphology_id": MORPHOLOGY_ID,
        "campaign_seed": CAMPAIGN_SEED,
        "execution": {
            "world_attempt_count": 1,
            "world_build_count": 1,
            "world_reset_count": 0,
            "direct_body_write_count": 0,
            "controller_error_count": metrics["controller_error_count"],
            "safe_no_actuation_count": metrics["safe_no_actuation_count"],
            "nonfinite_observation_count": metrics["nonfinite_observation_count"],
            "actuator_application_mismatch_count": metrics[
                "actuator_application_mismatch_count"
            ],
            "controller_semantic_step_count": metrics["controller_semantic_step_count"],
            "validated_portable_command_count": metrics[
                "validated_portable_command_count"
            ],
            "native_actuation_application_count": metrics[
                "native_actuation_application_count"
            ],
        },
        "execution_stage": {
            "schema_version": EXECUTION_STAGE_SCHEMA,
            "stage_id": "cell_report_complete",
            "world_attempt_count": 1,
            "world_build_count": 1,
        },
        "command_validation": {
            "schema_version": COMMAND_VALIDATION_SCHEMA,
            "normalized_validation_mode": NORMALIZED_VALIDATION_MODE,
            "source_validation_mode": SOURCE_VALIDATION_MODE,
            "native_validation_step_count": metrics["controller_semantic_step_count"],
            "heading_command_conditioned_step_count": metrics[
                "controller_semantic_step_count"
            ],
            "unconditioned_step_count": 0,
            "legacy_command_parity_applicable": False,
            "legacy_command_parity_checked_step_count": 0,
            "legacy_command_parity_waived_step_count": 0,
            "oracle_contract_sha256": _raw_sha256(ORACLE_PATH),
            "independent_oracle_validation_step_count": metrics[
                "controller_semantic_step_count"
            ],
            "accepted_receipt_count": metrics["controller_semantic_step_count"],
            "rejected_receipt_count": 0,
            "predicate_failure_count": 0,
            "raw_heading_offset_equality_used": False,
        },
        "schedule": {
            "schedule_id": SCHEDULE_ID,
            "turn_heading_offset_rad": turn_heading_offset_rad,
            "observed_segment_sample_counts": metrics["observed_segment_sample_counts"],
            "reference_heading_sample_count": 1_200,
            "turn_heading_sample_count": 1_200,
        },
        "controller": {
            "maximum_absolute_requested_steering_fraction": metrics[
                "maximum_absolute_requested_steering_fraction"
            ],
            "maximum_absolute_held_steering_fraction": metrics[
                "maximum_absolute_held_steering_fraction"
            ],
            "mean_turn_held_steering_fraction": metrics[
                "mean_turn_held_steering_fraction"
            ],
        },
        "physics": {
            "turn_phase_yaw_delta_rad": metrics["turn_phase_yaw_delta_rad"],
            "final_reference_heading_error_rad": metrics[
                "final_reference_heading_error_rad"
            ],
            "final_forward_displacement_m": metrics["final_forward_displacement_m"],
            "maximum_tilt_rad": metrics["maximum_tilt_rad"],
            "minimum_torso_height_m": metrics["minimum_torso_height_m"],
            "torso_ground_contact_step_count": metrics[
                "torso_ground_contact_step_count"
            ],
            "contact_cycles_by_limb": metrics["contact_cycles_by_limb"],
            "engine_production_straight_walking_gate_passed": metrics[
                "walking_gate_passed"
            ],
            "commanded_turn_walk_gate_passed": metrics["walking_gate_passed"],
        },
        "claims": _claims(),
    }


def _synthetic_physical_report(
    arm_id: str, turn_heading_offset_rad: float
) -> dict[str, Any]:
    signed_controller = (
        0.0
        if turn_heading_offset_rad == 0.0
        else -math.copysign(0.2, turn_heading_offset_rad)
    )
    signed_yaw = (
        0.0
        if turn_heading_offset_rad == 0.0
        else math.copysign(0.1, turn_heading_offset_rad)
    )
    return _compose_physical_report(
        arm_id,
        "a" * 40,
        turn_heading_offset_rad,
        {
            "controller_error_count": 0,
            "safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "controller_semantic_step_count": CONTROLLER_STEPS,
            "validated_portable_command_count": CONTROLLER_STEPS * 8,
            "native_actuation_application_count": CONTROLLER_STEPS * 8,
            "observed_segment_sample_counts": {
                "reference_warmup": 600,
                "commanded_turn": 1_200,
                "reference_recovery": 600,
            },
            "maximum_absolute_requested_steering_fraction": 0.3,
            "maximum_absolute_held_steering_fraction": 0.25,
            "mean_turn_held_steering_fraction": signed_controller,
            "turn_phase_yaw_delta_rad": signed_yaw,
            "final_reference_heading_error_rad": 0.02,
            "final_forward_displacement_m": 0.5,
            "maximum_tilt_rad": 0.2,
            "minimum_torso_height_m": 0.4,
            "torso_ground_contact_step_count": 0,
            "contact_cycles_by_limb": {
                "front_left": 3,
                "front_right": 3,
                "rear_left": 3,
                "rear_right": 3,
            },
            "walking_gate_passed": True,
        },
    )


def _synthetic_failure_receipts(
    arm_id: str,
    oracle_contract: dict[str, Any],
    compiled: dict[str, Any],
    profile: dict[str, Any],
) -> list[dict[str, Any]]:
    source_commit = "a" * 40
    receipts = [
        _worker_failure(
            arm_id,
            source_commit,
            stage_id,
            attempts,
            builds,
            f"QSDK_R23D2_MJC_SYNTHETIC_{stage_id.upper()}",
        )
        for stage_id, attempts, builds in (
            ("before_world", 0, 0),
            ("world_construction_failed", 1, 0),
            ("world_constructed", 1, 1),
            ("settlement_complete", 1, 1),
            ("cell_report_complete", 1, 1),
        )
    ]
    canary = oracle_contract["oracle_canaries"][1]
    state = _state_for_canary(compiled, canary)
    command = _command(
        f"qsdk_r23d2_failure_{canary['canary_id']}",
        float(canary["desired_heading_rad"]),
    )
    expected = _independent_oracle(state, command, profile)
    rejected = dict(expected)
    rejected["desired_heading_error_rad"] += 1.0e-6
    projection = _receipt_projection(rejected)
    oracle_input = {
        "state": _oracle_state_projection(state),
        "command": {"desired_heading_rad": command["desired_heading_rad"]},
        "profile": dict(oracle_contract["selected_profile_oracle"]),
    }
    receipts.append(
        _worker_failure(
            arm_id,
            source_commit,
            "controller_validation_failed",
            1,
            1,
            "QSDK_R23D2_MJC_SYNTHETIC_CONTROLLER_VALIDATION_FAILED",
            (projection, oracle_input, _oracle_evaluation(expected, rejected)),
        )
    )
    return receipts


def run_preflight(arm_id: str) -> dict[str, Any]:
    arm_heading_offset_rad = _arm_offset(arm_id)
    oracle_contract, worker_contract, development_contract = _contracts()
    core = LocomotionCore()
    compiled, profile = _compile_boundary(core)
    declared_profile = oracle_contract["selected_profile_oracle"]
    if (
        abs(
            float(profile["cross_track_heading_gain_rad_per_m"])
            - _finite(
                declared_profile.get("cross_track_heading_gain_rad_per_m"),
                "HEADING_GAIN",
            )
        )
        > 1.0e-15
        or abs(
            float(profile["cross_track_velocity_heading_gain_rad_per_m_s"])
            - _finite(
                declared_profile.get("cross_track_velocity_heading_gain_rad_per_m_s"),
                "VELOCITY_GAIN",
            )
        )
        > 1.0e-15
    ):
        raise QsdkR23d2MujocoWorkerError("QSDK_R23D2_MJC_PROFILE_ORACLE_MISMATCH")

    results: list[dict[str, Any]] = []
    nonzero_count = 0
    legacy_rejections = 0
    predicate_controls = 0
    native_command_count = 0
    for canary in oracle_contract["oracle_canaries"]:
        canary_id = str(canary["canary_id"])
        state = _state_for_canary(compiled, canary)
        command = _command(
            f"qsdk_r23d2_oracle_{canary_id}",
            _finite(canary.get("desired_heading_rad"), "DESIRED_HEADING"),
        )
        receipt, mapping = _controller_and_mapping(core, compiled, state, command)
        expected = _independent_oracle(state, command, profile)
        failures = _predicate_failures(expected, receipt)
        if failures:
            raise QsdkR23d2MujocoWorkerError(
                f"QSDK_R23D2_MJC_ORACLE_MISMATCH:{canary_id}:" + ",".join(failures)
            )
        if (
            abs(
                expected["desired_heading_error_rad"]
                - _finite(
                    canary.get("expected_desired_heading_error_rad"),
                    "EXPECTED_DESIRED_HEADING",
                )
            )
            > TOLERANCE
        ):
            raise QsdkR23d2MujocoWorkerError(
                f"QSDK_R23D2_MJC_CANARY_EXPECTATION_INVALID:{canary_id}"
            )
        nonzero = (
            expected["cross_track_error_m"] != 0.0
            or expected["cross_track_velocity_m_s"] != 0.0
        )
        if nonzero:
            nonzero_count += 1
            legacy = dict(expected)
            raw_heading = _wrap_angle(
                float(command["desired_heading_rad"])
                - float(state["task_frame"]["reference_yaw_rad"])
            )
            legacy["desired_heading_error_rad"] = raw_heading
            legacy["yaw_tracking_error_rad"] = _wrap_angle(
                expected["measured_yaw_error_rad"] - raw_heading
            )
            if not _predicate_failures(expected, legacy):
                raise QsdkR23d2MujocoWorkerError(
                    f"QSDK_R23D2_MJC_LEGACY_ORACLE_ACCEPTED:{canary_id}"
                )
            legacy_rejections += 1
        for field in RECEIPT_FIELDS:
            mutated = dict(expected)
            mutated[field] += 1.0e-6
            if _predicate_failures(expected, mutated) != [f"{field}:mismatch"]:
                raise QsdkR23d2MujocoWorkerError(
                    f"QSDK_R23D2_MJC_NEGATIVE_CONTROL_INVALID:{canary_id}:{field}"
                )
            predicate_controls += 1
        native_command_count += len(mapping["ordered_commands"])
        results.append(
            {
                "canary_id": canary_id,
                "nonzero_cross_track": nonzero,
                "expected_receipt": expected,
                "observed_receipt": {field: receipt[field] for field in RECEIPT_FIELDS},
                "failed_predicates": failures,
                "host_mapping_sha256": _json_sha256(mapping),
                "model_construction_count": 0,
                "world_build_count": 0,
                "physical_acceptance_authority": False,
            }
        )

    arm_state = _state_for_canary(compiled, oracle_contract["oracle_canaries"][0])
    arm_command = _command(
        f"qsdk_r23d2_arm_boundary_{arm_id}",
        float(arm_state["task_frame"]["reference_yaw_rad"]) + arm_heading_offset_rad,
    )
    arm_receipt, arm_mapping = _controller_and_mapping(
        core, compiled, arm_state, arm_command
    )
    arm_expected = _independent_oracle(arm_state, arm_command, profile)
    arm_failures = _predicate_failures(arm_expected, arm_receipt)
    if (
        arm_failures
        or abs(arm_expected["desired_heading_error_rad"] - arm_heading_offset_rad)
        > TOLERANCE
    ):
        raise QsdkR23d2MujocoWorkerError(
            f"QSDK_R23D2_MJC_ARM_COMMAND_BOUNDARY_INVALID:{arm_id}:"
            + ",".join(arm_failures)
        )
    native_command_count += len(arm_mapping["ordered_commands"])
    model_xml_receipt = _model_xml_receipt(compiled)
    synthetic_report = _synthetic_physical_report(arm_id, arm_heading_offset_rad)
    synthetic_failures = _synthetic_failure_receipts(
        arm_id, oracle_contract, compiled, profile
    )
    if (
        nonzero_count != 6
        or legacy_rejections != 6
        or predicate_controls != 35
        or native_command_count != 64
        or model_xml_receipt["model_construction_count"] != 0
        or len(synthetic_failures) != 6
    ):
        raise QsdkR23d2MujocoWorkerError("QSDK_R23D2_MJC_PREFLIGHT_COUNTS_INVALID")

    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": ENGINE_ID,
        "engine_version": mujoco.__version__,
        "arm_id": arm_id,
        "arm_heading_offset_rad": arm_heading_offset_rad,
        "selected_policy_id": POLICY_ID,
        "morphology_id": MORPHOLOGY_ID,
        "host_profile_id": HOST_PROFILE_ID,
        "native_motor_model_id": NATIVE_MOTOR_MODEL_ID,
        "adapter_capability_sha256": capability_manifest_sha256(),
        "core_version": core.version,
        "core_library_path": str(core.library_path),
        "core_library_sha256": _raw_sha256(core.library_path),
        "oracle_contract_sha256": _raw_sha256(ORACLE_PATH),
        "worker_contract_sha256": _raw_sha256(WORKER_CONTRACT_PATH),
        "development_contract_sha256": _raw_sha256(DEVELOPMENT_CONTRACT_PATH),
        "worker_contract_status": worker_contract["status"],
        "development_contract_status": development_contract["status"],
        "canary_count": len(results),
        "nonzero_cross_track_canary_count": nonzero_count,
        "legacy_raw_offset_oracle_rejection_count": legacy_rejections,
        "predicate_negative_control_count": predicate_controls,
        "canaries": results,
        "arm_command_boundary": {
            "desired_heading_error_rad": arm_expected["desired_heading_error_rad"],
            "observed_heading_error_rad": arm_receipt["desired_heading_error_rad"],
            "failed_predicates": arm_failures,
            "host_mapping_sha256": _json_sha256(arm_mapping),
            "native_command_count": len(arm_mapping["ordered_commands"]),
            "model_construction_count": 0,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        "model_xml_receipt": model_xml_receipt,
        "synthetic_physical_report": synthetic_report,
        "synthetic_failure_receipts": synthetic_failures,
        "physical_implementation_present": True,
        "native_controller_step_count": len(results) + 1,
        "native_command_count": native_command_count,
        "host_mapping_validation_count": len(results) + 1,
        "model_xml_validation_count": 1,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "model_construction_count": 0,
        "physical_execution_authorized": True,
        "q_sdk_r23_satisfied": False,
        "physical_acceptance_authority": False,
    }


def _valid_source_commit(value: str) -> bool:
    return len(value) == 40 and all(
        character in "0123456789abcdef" for character in value
    )


def _valid_lower_hex(value: str, length: int) -> bool:
    return len(value) == length and all(
        character in "0123456789abcdef" for character in value
    )


def _initial_perturbation(development: dict[str, Any]) -> dict[str, Any]:
    value = development["fixture"].get("initial_perturbation")
    if not isinstance(value, dict):
        raise QsdkR23d2MujocoWorkerError("QSDK_R23D2_MJC_INITIAL_PERTURBATION_INVALID")
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
            not isinstance(number, bool)
            and isinstance(number, (int, float))
            and math.isfinite(float(number))
            for number in numbers
        )
        or float(value["fixture_vertical_clearance_m"]) < 0.0
        or not isinstance(value.get("gait_phase_offset_ticks"), int)
        or isinstance(value.get("gait_phase_offset_ticks"), bool)
        or abs(int(value["gait_phase_offset_ticks"])) > 3
    ):
        raise QsdkR23d2MujocoWorkerError("QSDK_R23D2_MJC_INITIAL_PERTURBATION_INVALID")
    return json.loads(json.dumps(value, allow_nan=False))


def _heading_schedule(
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


def _physical_motion_command(
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


def _physical_authorization(
    development: dict[str, Any], arm_id: str, source_commit: str
) -> None:
    if development["authorization"]["physical_execution_authorized"] is not True:
        raise QsdkR23d2MujocoWorkerError(
            "QSDK_R23D2_MJC_PHYSICAL_AUTHORIZATION_REQUIRED"
        )
    attempt_path = os.environ.get(ATTEMPT_PATH_ENV, "")
    token = os.environ.get(AUTHORIZATION_TOKEN_ENV, "")
    cell_id = f"{ENGINE_ID}__{arm_id}"
    if (
        not attempt_path
        or not _valid_lower_hex(token, 32)
        or os.environ.get(CELL_ID_ENV) != cell_id
        or os.environ.get(ENGINE_ID_ENV) != ENGINE_ID
    ):
        raise QsdkR23d2MujocoWorkerError(
            "QSDK_R23D2_MJC_SUPERVISOR_AUTHORIZATION_INVALID"
        )
    try:
        attempt = json.loads(Path(attempt_path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise QsdkR23d2MujocoWorkerError(
            f"QSDK_R23D2_MJC_ATTEMPT_INVALID:{type(error).__name__}"
        ) from error
    expected_cells = [
        f"{engine}__{arm}"
        for engine in ("godot_jolt", "rapier_parry", "mujoco")
        for arm in ("reference_zero", "positive_heading", "negative_heading")
    ]
    if not (
        attempt.get("schema_version") == "sporespore_qsdk_r23d2_attempt_v1"
        and attempt.get("campaign_id") == CAMPAIGN_ID
        and attempt.get("gate_id") == PARENT_GATE_ID
        and attempt.get("contract_sha256") == _raw_sha256(DEVELOPMENT_CONTRACT_PATH)
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
        raise QsdkR23d2MujocoWorkerError("QSDK_R23D2_MJC_ATTEMPT_AUTHORIZATION_INVALID")


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
) -> None:
    free_joint = robot.model.joint("torso_free").id
    if int(robot.model.jnt_type[free_joint]) != int(mujoco.mjtJoint.mjJNT_FREE):
        raise QsdkR23d2MujocoWorkerError("QSDK_R23D2_MJC_TORSO_FREE_JOINT_INVALID")
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
        raise QsdkR23d2MujocoWorkerError("QSDK_R23D2_MJC_INITIAL_STATE_NONFINITE")


def _zero_prepared_outer_step(robot: bridge.MujocoBw19vRobot) -> None:
    for substep in range(bridge.INTERNAL_STEPS_PER_OUTER):
        if substep > 0:
            mujoco.mj_step1(robot.model, robot.data)
        robot.data.ctrl[:] = 0.0
        if np.count_nonzero(robot.data.ctrl) != 0:
            raise QsdkR23d2MujocoWorkerError(
                "QSDK_R23D2_MJC_ZERO_CONTROL_READBACK_INVALID"
            )
        mujoco.mj_step2(robot.model, robot.data)


def _phase_offset(memory: dict[str, Any], requested_offset_ticks: int) -> None:
    limbs = memory["ordered_limb_memory"]
    if abs(requested_offset_ticks) > 3 or len(limbs) != 4:
        raise QsdkR23d2MujocoWorkerError("QSDK_R23D2_MJC_PHASE_OFFSET_INVALID")
    minimum_raw = min(int(limb["gait_step"]) + requested_offset_ticks for limb in limbs)
    representation_shift_ticks = 0
    while minimum_raw + representation_shift_ticks < 0:
        representation_shift_ticks += 360
    for limb in limbs:
        limb["gait_step"] = (
            int(limb["gait_step"]) + requested_offset_ticks + representation_shift_ticks
        )


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


def _physical_failure(
    arm_id: str,
    source_commit: str,
    stage_id: str,
    world_attempt_count: int,
    world_build_count: int,
    code: str,
    controller_failure: (
        tuple[dict[str, Any], dict[str, Any], dict[str, Any]] | None
    ) = None,
) -> QsdkR23d2MujocoPhysicalFailure:
    return QsdkR23d2MujocoPhysicalFailure(
        _worker_failure(
            arm_id,
            source_commit,
            stage_id,
            world_attempt_count,
            world_build_count,
            code,
            controller_failure,
        )
    )


def _physical_report(
    arm_id: str,
    source_commit: str,
    turn_offset: float,
    oracle_contract: dict[str, Any],
    development: dict[str, Any],
) -> dict[str, Any]:
    perturbation = _initial_perturbation(development)
    # Re-run the commissioned zero-world boundary before the native attempt.
    run_preflight(arm_id)
    core = LocomotionCore()
    compiled, profile = _compile_boundary(core)

    # The attempt count increments immediately before this constructor call.
    try:
        robot = bridge.MujocoBw19vRobot(core, HOST_PROFILE_ID)
    except Exception as error:
        code = (
            error.code
            if isinstance(error, QsdkR23d2MujocoWorkerError)
            else f"QSDK_R23D2_MJC_WORLD_CONSTRUCTION_ERROR:{type(error).__name__}:{error}"
        )
        raise _physical_failure(
            arm_id, source_commit, "world_construction_failed", 1, 0, code
        ) from error

    try:
        _apply_initial_perturbation(robot, perturbation)
        for _ in range(SETTLE_STEPS):
            robot.prepare()
            _zero_prepared_outer_step(robot)
        robot.prepare()
    except Exception as error:
        code = (
            error.code
            if isinstance(error, QsdkR23d2MujocoWorkerError)
            else f"QSDK_R23D2_MJC_SETTLEMENT_ERROR:{type(error).__name__}:{error}"
        )
        raise _physical_failure(
            arm_id, source_commit, "world_constructed", 1, 1, code
        ) from error

    try:
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
        segment_counts = {
            "reference_warmup": 0,
            "commanded_turn": 0,
            "reference_recovery": 0,
        }

        for semantic_step in range(CONTROLLER_STEPS):
            if semantic_step == PHASE_OFFSET_ACTIVATION_STEP:
                _phase_offset(
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
            heading = _heading_schedule(
                semantic_step, reference_heading_rad, turn_offset
            )
            if semantic_step == TURN_START_STEP:
                turn_start_yaw = float(robot.torso_metrics()["yaw_rad"])
            if heading["declared_segment"]:
                segment_counts[heading["segment_id"]] += 1
            command = _physical_motion_command(semantic_step, phase_mode, heading)
            output = core.balanced_wave_policy_step(
                POLICY_ID,
                {
                    "descriptor": bridge.s169_descriptor(),
                    "memory": controller_memory,
                    "state": state,
                    "command": command,
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
            ordered_ids = list(compiled["morphology"]["ordered_actuator_ids"])
            if (
                receipt.get("semantic_step") != semantic_step
                or receipt.get("command_id") != command["command_id"]
                or receipt.get("policy_id") != POLICY_ID
                or receipt.get("world_build_count") != 0
                or receipt.get("physical_acceptance_authority") is not False
                or [entry["actuator_id"] for entry in actuation["ordered_commands"]]
                != ordered_ids
                or len(actuation["ordered_commands"]) != 8
            ):
                raise QsdkR23d2MujocoWorkerError(
                    "QSDK_R23D2_MJC_CONTROLLER_OUTPUT_INVALID"
                )

            expected = _independent_oracle(state, command, profile)
            oracle_failures = _predicate_failures(expected, receipt)
            if oracle_failures:
                projection = _receipt_projection(receipt)
                oracle_input = {
                    "state": _oracle_state_projection(state),
                    "command": {"desired_heading_rad": command["desired_heading_rad"]},
                    "profile": dict(oracle_contract["selected_profile_oracle"]),
                }
                evaluation = _oracle_evaluation(expected, projection)
                raise _physical_failure(
                    arm_id,
                    source_commit,
                    "controller_validation_failed",
                    1,
                    1,
                    "QSDK_R23D2_MJC_CONTROLLER_RECEIPT_INVALID:"
                    + ",".join(oracle_failures),
                    (projection, oracle_input, evaluation),
                )

            canonical = core.canonical_velocity_compose_v1(
                {
                    "schema_version": (
                        "sporespore_canonical_velocity_compose_request_v1"
                    ),
                    "descriptor": bridge.s169_descriptor(),
                    "source_actuation": actuation,
                    "ordered_stability_residuals": _zero_residuals(actuation),
                }
            )
            mapping = core.canonical_velocity_host_map_v1(
                {
                    "schema_version": (
                        "sporespore_canonical_velocity_host_map_request_v1"
                    ),
                    "descriptor": bridge.s169_descriptor(),
                    "canonical_actuation": canonical,
                    "host_profile": bridge._mujoco_host_profile(HOST_PROFILE_ID),
                }
            )
            if (
                mapping.get("host_profile_id") != HOST_PROFILE_ID
                or mapping.get("engine_id") != ENGINE_ID
                or mapping.get("native_position_stiffness") != 0.0
                or mapping.get("independent_native_position_feedback_applied")
                is not False
                or [entry["actuator_id"] for entry in mapping["ordered_commands"]]
                != ordered_ids
                or len(mapping["ordered_commands"]) != 8
                or any(
                    entry["native_target_position_rad"] is not None
                    or entry["host_clamped"] is not False
                    for entry in mapping["ordered_commands"]
                )
            ):
                raise QsdkR23d2MujocoWorkerError(
                    "QSDK_R23D2_MJC_NATIVE_MAPPING_INVALID"
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
            impulse_violations = int(application["portable_impulse_violation_count"])
            counters["native_actuation_application_count"] += application_count
            counters["portable_impulse_violation_count"] += impulse_violations
            counters["actuator_application_mismatch_count"] += int(
                application_count != 8
            )
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
            raise QsdkR23d2MujocoWorkerError("QSDK_R23D2_MJC_TURN_WINDOW_INCOMPLETE")
        turn_phase_yaw_delta_rad = _wrap_angle(turn_end_yaw - turn_start_yaw)
        mean_turn_held_steering_fraction = turn_held_sum / turn_held_count
        contacts_pass = all(
            count >= MINIMUM_CONTACT_CYCLES_PER_LIMB
            for count in contact_cycles.values()
        )
        walking_gate = (
            counters["controller_error_count"] == 0
            and counters["safe_no_actuation_count"] == 0
            and counters["nonfinite_observation_count"] == 0
            and counters["actuator_application_mismatch_count"] == 0
            and counters["portable_impulse_violation_count"] == 0
            and counters["validated_portable_command_count"] == CONTROLLER_STEPS * 8
            and counters["native_actuation_application_count"] == CONTROLLER_STEPS * 8
            and counters["torso_ground_contact_step_count"] == 0
            and maximum_tilt_rad <= MAXIMUM_TILT_RAD
            and minimum_torso_height_m >= MINIMUM_TORSO_HEIGHT_M
            and final_forward_displacement_m >= MINIMUM_FINAL_FORWARD_DISPLACEMENT_M
            and contacts_pass
        )
        try:
            report = _compose_physical_report(
                arm_id,
                source_commit,
                turn_offset,
                {
                    **counters,
                    "controller_semantic_step_count": CONTROLLER_STEPS,
                    "observed_segment_sample_counts": segment_counts,
                    "maximum_absolute_requested_steering_fraction": maximum_requested,
                    "maximum_absolute_held_steering_fraction": maximum_held,
                    "mean_turn_held_steering_fraction": (
                        mean_turn_held_steering_fraction
                    ),
                    "turn_phase_yaw_delta_rad": turn_phase_yaw_delta_rad,
                    "final_reference_heading_error_rad": (
                        final_reference_heading_error_rad
                    ),
                    "final_forward_displacement_m": final_forward_displacement_m,
                    "maximum_tilt_rad": maximum_tilt_rad,
                    "minimum_torso_height_m": minimum_torso_height_m,
                    "contact_cycles_by_limb": contact_cycles,
                    "walking_gate_passed": walking_gate,
                },
            )
            json.dumps(report, allow_nan=False)
        except Exception as error:
            code = (
                error.code
                if isinstance(error, QsdkR23d2MujocoWorkerError)
                else (
                    "QSDK_R23D2_MJC_REPORT_COMPOSITION_ERROR:"
                    f"{type(error).__name__}:{error}"
                )
            )
            raise _physical_failure(
                arm_id, source_commit, "cell_report_complete", 1, 1, code
            ) from error
        return report
    except QsdkR23d2MujocoPhysicalFailure:
        raise
    except Exception as error:
        code = (
            error.code
            if isinstance(error, QsdkR23d2MujocoWorkerError)
            else f"QSDK_R23D2_MJC_PHYSICAL_WORKER_ERROR:{type(error).__name__}:{error}"
        )
        raise _physical_failure(
            arm_id, source_commit, "settlement_complete", 1, 1, code
        ) from error


def run_physical(arm_id: str, source_commit: str) -> dict[str, Any]:
    if PHYSICAL_IDENTITY_CLOSED:
        raise _physical_failure(
            arm_id,
            source_commit,
            "before_world",
            0,
            0,
            "QSDK_R23D2_MJC_PHYSICAL_IDENTITY_CLOSED",
        )
    try:
        turn_offset = _arm_offset(arm_id)
        if not _valid_source_commit(source_commit):
            raise QsdkR23d2MujocoWorkerError("QSDK_R23D2_MJC_SOURCE_COMMIT_INVALID")
        oracle, _, development = _contracts()
        _physical_authorization(development, arm_id, source_commit)
    except QsdkR23d2MujocoWorkerError as error:
        raise _physical_failure(
            arm_id,
            source_commit,
            "before_world",
            0,
            0,
            error.code,
        ) from error
    return _physical_report(arm_id, source_commit, turn_offset, oracle, development)


def _failure(error: QsdkR23d2MujocoWorkerError, arm_id: str | None) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_qsdk_r23d2_worker_failure_v1",
        "engine_id": ENGINE_ID,
        "arm_id": arm_id,
        "stage_id": "before_world",
        "failure_code": error.code,
        "failed_predicates": [],
        "rejected_native_receipt": None,
        "world_attempt_count": error.world_attempt_count,
        "world_build_count": error.world_build_count,
        "model_construction_count": error.model_construction_count,
        "physical_acceptance_authority": False,
        "release_authorized": False,
    }


def _arguments(arguments: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--arm", required=True)
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
    except QsdkR23d2MujocoPhysicalFailure as error:
        print(
            "QSDK_R23D2_MUJOCO_FAILURE "
            + json.dumps(error.receipt, sort_keys=True, allow_nan=False)
        )
        return 1
    except QsdkR23d2MujocoWorkerError as error:
        print(
            "QSDK_R23D2_MUJOCO_FAILURE "
            + json.dumps(_failure(error, args.arm), sort_keys=True, allow_nan=False)
        )
        return 1
    prefix = (
        "QSDK_R23D2_MUJOCO_PREFLIGHT "
        if args.preflight_only
        else "QSDK_R23D2_MUJOCO_CELL "
    )
    print(prefix + json.dumps(report, sort_keys=True, allow_nan=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
