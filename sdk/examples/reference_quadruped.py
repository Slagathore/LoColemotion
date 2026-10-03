"""Deterministic reference frames for the standalone quadruped quickstart."""

from __future__ import annotations

from typing import Any, Mapping

from python import LocomotionCore, SELECTED_BALANCED_WAVE_POLICY_ID


def build_reference_state(
    morphology: Mapping[str, Any],
    semantic_step: int,
) -> dict[str, Any]:
    """Build a canonical, engine-independent host observation.

    This is a synthetic API example. It is not a physics result and carries no
    walking or physical-acceptance authority.
    """

    return {
        "schema_version": "sporespore_state_frame_v1",
        "semantic_step": semantic_step,
        "sample_time_s": semantic_step / 120.0,
        "base_pose_world": {
            "position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
            "orientation_xyzw": {
                "x": 0.0,
                "y": 0.0,
                "z": 0.0,
                "w": 1.0,
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
                    "adapter_id": "standalone_python_quickstart",
                    "engine_contact_ids": [f"{contact_id}_synthetic"],
                    "aggregation_rule_id": "qualified_bearing_only",
                    "quality": "qualified_bearing",
                },
            }
            for contact_id in morphology["ordered_contact_site_ids"]
        ],
        "previous_applied_actuation": None,
        "gravity_world_m_s2": {"x": 0.0, "y": -9.81, "z": 0.0},
        "task_frame": {
            "origin_world_m": {"x": 0.0, "y": 0.0, "z": 0.0},
            "forward_axis_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
            "lateral_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
            "up_axis_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
            "reference_yaw_rad": 0.0,
        },
        "adapter_capability_sha256": (
            "sha256:" "2222222222222222222222222222222222222222222222222222222222222222"
        ),
    }


def build_reference_command(semantic_step: int) -> dict[str, Any]:
    """Build a bounded walking command for one semantic step."""

    return {
        "schema_version": "sporespore_motion_command_v2",
        "command_id": f"standalone_quickstart_{semantic_step}",
        "desired_planar_velocity_task_m_s": {
            "x": 0.2,
            "y": 0.0,
            "z": 0.0,
        },
        "desired_heading_rad": 0.0,
        "desired_yaw_rate_rad_s": None,
        "gait_family_id": "lateral_wave",
        "speed_class": "walk",
        "gait_amplitude": 1.0,
        "phase_progression_mode": "contact_gated",
        "valid_from_step": semantic_step,
        "valid_through_step": semantic_step,
        "authority": "test_fixture",
    }


def build_reference_request(
    *,
    descriptor: Mapping[str, Any],
    morphology: Mapping[str, Any],
    memory: Mapping[str, Any],
    semantic_step: int,
) -> dict[str, Any]:
    """Build the explicit selected-policy public request envelope."""

    return {
        "schema_version": ("sporespore_balanced_wave_policy_step_request_v1"),
        "policy_id": SELECTED_BALANCED_WAVE_POLICY_ID,
        "descriptor": dict(descriptor),
        "memory": dict(memory),
        "state": build_reference_state(morphology, semantic_step),
        "command": build_reference_command(semantic_step),
    }


def run_reference_frames(
    core: LocomotionCore,
    *,
    frame_count: int = 2,
    morphology_id: str = "standalone_python_quickstart",
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Execute deterministic pure SDK frames and retain request/output pairs."""

    from python import reference_quadruped

    if frame_count < 1:
        raise ValueError("frame_count must be positive")
    descriptor = reference_quadruped(morphology_id)
    compiled = core.compile_bounded_quadruped(descriptor)
    morphology = compiled["morphology"]
    memory = core.balanced_wave_policy_initial_memory(
        SELECTED_BALANCED_WAVE_POLICY_ID,
        descriptor,
    )
    frames: list[dict[str, Any]] = []
    for semantic_step in range(frame_count):
        request = build_reference_request(
            descriptor=descriptor,
            morphology=morphology,
            memory=memory,
            semantic_step=semantic_step,
        )
        response = core.balanced_wave_policy_step(
            SELECTED_BALANCED_WAVE_POLICY_ID,
            request,
        )
        frames.append({"request": request, "response": response})
        memory = response["next_memory"]
    return descriptor, frames
