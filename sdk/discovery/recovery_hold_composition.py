"""Successor BW19V composition with the actual motion-command amplitude.

The frozen adapter composition remains unchanged. This successor keeps its
pure ABI operations and bounds, but joins the support plan to the motion
command. A zero-amplitude hold is not a guarantee of zero actuator velocity.
"""
import math
from typing import Any
from portable_search_control import bridge
from causal_force_policy import HANDOFF
from actuation_recovery_mechanics import require


def hold_motion_command(step, phase_mode):
    require(type(step) is int and HANDOFF <= step and phase_mode == "clocked",
        "Recovery hold command clock/phase")
    command=bridge._motion_command(step,phase_mode)
    command.update(speed_class="hold",gait_amplitude=0.0,
        desired_planar_velocity_task_m_s=dict(x=0.0,y=0.0,z=0.0))
    return command


def validate_composition_command(command, step):
    require(type(step) is int and type(command.get("valid_from_step")) is int
        and command.get("phase_progression_mode") == "clocked",
        "Recovery composition command clock/phase")
    expected=(hold_motion_command(step,"clocked") if command.get("speed_class") == "hold"
        else bridge._motion_command(step,"clocked"))
    require(command == expected,"Recovery composition motion-command mismatch")


def compose_recovery_step(
    robot: bridge.MujocoBw19vRobot,
    base_actuation: dict[str, Any],
    stability_state: dict[str, Any],
    kinematics: list[dict[str, Any]],
    limb_steps: list[dict[str, Any]],
    memory: bridge.CompositionMemory,
    command: dict[str, Any],
) -> dict[str, Any]:
    """Compose BW19V using only versioned pure Rust-core ABI operations."""

    semantic_step = int(base_actuation["semantic_step"])
    validate_composition_command(command, semantic_step)
    available = any(
        contact["bears_support"] is True
        for contact in stability_state["ordered_support_contacts"]
    )
    gravity = stability_state["gravity_world_m_s2"]
    gravity_norm = math.sqrt(sum(float(gravity[axis]) ** 2 for axis in ("x", "y", "z")))
    plan = robot.core.plan_scheduled_load_transfer_v3(
        {
            "schema_version": "sporespore_plan_scheduled_load_transfer_request_v3",
            "descriptor": robot.descriptor,
            "request": {
                "schema_version": "sporespore_scheduled_load_transfer_request_v3",
                "policy_id": bridge.STABILITY_POLICY_ID,
                "semantic_step": semantic_step,
                "observation_available": available,
                "observation_unavailable_reason": (
                    None if available else bridge.NO_QUALIFIED_SUPPORT_CONTACT_REASON
                ),
                "gait_amplitude": command["gait_amplitude"],
                "cycle_steps": bridge.CYCLE_STEPS,
                "swing_steps": bridge.SWING_STEPS,
                "characterized_friction_coefficient": bridge.CHARACTERIZED_CONTROLLER_FRICTION,
                "maximum_normal_force_n": float(robot.morphology["total_mass_kg"])
                * gravity_norm,
                "feasibility_tolerance": bridge.FEASIBILITY_TOLERANCE,
                "ordered_limb_gait_steps": limb_steps,
                # Preserve the same v3 receipt path used by the Rapier BW19V
                # composition: an unavailable observation still carries the
                # emitted, explicitly unusable state instead of disappearing.
                "stability_state": stability_state,
            },
        }
    )
    planning_available = plan["planning_availability"] == "available"
    mapping = None
    if planning_available:
        mapping = robot.core.map_endpoint_force_to_joint_v3(
            {
                "schema_version": "sporespore_map_endpoint_force_to_joint_request_v3",
                "descriptor": robot.descriptor,
                "request": {
                    "schema_version": "sporespore_endpoint_force_joint_map_request_v3",
                    "semantic_step": semantic_step,
                    "centroidal_command": plan["centroidal_command"],
                    "ordered_actuator_kinematics": kinematics,
                },
            }
        )
    raw_torque: list[float | None] = []
    mapping_modes: list[str | None] = []
    requested = []
    if mapping is not None:
        commands = mapping["ordered_generalized_joint_torque_commands"]
        for expected, command in zip(
            robot.morphology["ordered_actuator_ids"], commands, strict=True
        ):
            if command["actuator_id"] != expected:
                raise RuntimeError("C6_MJC_SP_DEV_MAPPING_ORDER_MISMATCH")
            torque = float(command["generalized_torque_command_nm"])
            raw_torque.append(torque)
            mapping_modes.append(command["mapping_mode"])
            requested.append(
                {
                    "actuator_id": expected,
                    "requested_position_delta_rad": 0.0,
                    "requested_velocity_delta_rad_s": torque / bridge.VELOCITY_GAIN,
                }
            )
    else:
        for actuator_id in robot.morphology["ordered_actuator_ids"]:
            raw_torque.append(None)
            mapping_modes.append(None)
            requested.append(
                {
                    "actuator_id": actuator_id,
                    "requested_position_delta_rad": None,
                    "requested_velocity_delta_rad_s": None,
                }
            )
    previous = memory.ordered_previous_applied_corrections
    if previous is not None:
        previous = [dict(correction) for correction in previous]
        for correction, mode in zip(previous, mapping_modes, strict=True):
            if mode == "inactive_contact_zero":
                correction["applied_position_delta_rad"] = 0.0
                correction["applied_velocity_delta_rad_s"] = 0.0
    influence = robot.core.bound_stability_influence_v3(
        {
            "schema_version": "sporespore_bound_stability_influence_request_v3",
            "descriptor": robot.descriptor,
            "request": {
                "schema_version": "sporespore_stability_influence_request_v3",
                "semantic_step": semantic_step,
                "availability": plan["planning_availability"],
                "global_requested_correction_scale": bridge.GLOBAL_REQUESTED_CORRECTION_SCALE,
                "maximum_absolute_position_delta_rad": bridge.MAXIMUM_ABSOLUTE_POSITION_DELTA_RAD,
                "maximum_absolute_velocity_delta_rad_s": bridge.MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S,
                "maximum_position_delta_slew_per_step_rad": bridge.MAXIMUM_POSITION_SLEW_PER_STEP_RAD,
                "maximum_velocity_delta_slew_per_step_rad_s": (
                    bridge.MAXIMUM_VELOCITY_SLEW_PER_STEP_RAD_S
                ),
                "ordered_requested_corrections": requested,
                "previous_semantic_step": memory.previous_semantic_step,
                "ordered_previous_applied_corrections": previous,
            },
        }
    )
    memory.previous_semantic_step = semantic_step
    memory.ordered_previous_applied_corrections = [
        {
            "actuator_id": correction["actuator_id"],
            "applied_position_delta_rad": correction["applied_position_delta_rad"],
            "applied_velocity_delta_rad_s": correction[
                "applied_velocity_delta_rad_s"
            ],
        }
        for correction in influence["ordered_applied_corrections"]
    ]
    residuals = [
        {
            "schema_version": "sporespore_canonical_velocity_residual_v1",
            "actuator_id": correction["actuator_id"],
            "canonical_velocity_delta_rad_s": correction[
                "applied_velocity_delta_rad_s"
            ],
            "command_not_measurement": True,
            "physical_acceptance_authority": False,
        }
        for correction in influence["ordered_applied_corrections"]
    ]
    canonical = robot.core.canonical_velocity_compose_v1(
        {
            "schema_version": "sporespore_canonical_velocity_compose_request_v1",
            "descriptor": robot.descriptor,
            "source_actuation": base_actuation,
            "ordered_stability_residuals": residuals,
        }
    )
    host_mapping = robot.core.canonical_velocity_host_map_v1(
        {
            "schema_version": "sporespore_canonical_velocity_host_map_request_v1",
            "descriptor": robot.descriptor,
            "canonical_actuation": canonical,
            "host_profile": bridge._mujoco_host_profile(robot.profile_id),
        }
    )
    return {
        "scheduled_load_transfer": plan,
        "endpoint_mapping": mapping,
        "stability_influence": influence,
        "raw_generalized_torque_commands_nm": raw_torque,
        "canonical_actuation": canonical,
        "host_mapping": host_mapping,
    }
