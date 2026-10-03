"""Deterministic zero-world fixture for the R24D39 V2 route consumer."""

from __future__ import annotations

from copy import deepcopy
from typing import Any

from sporespore_locomotion import (
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
    r24d22_recovery_s169_morphology,
)

from .recovery_capability import (
    ACTUATOR_PROFILE_ID,
    ADAPTER_ID,
    ENGINE_ID,
    SEMANTICS_ID,
    TASK_ID,
    mujoco_recovery_capability_v1,
)
from .recovery_energy_v2_mapping_fixture import (
    synthetic_r24d38_mapping_request_v1,
)
from .recovery_runtime import STANCE_CONTROLLER_ID


SEMANTIC_STEP = 13
OUTER_STEP_DURATION_S = 1.0 / 120.0
SHA_A = "sha256:" + ("a" * 64)
SHA_B = "sha256:" + ("b" * 64)
SHA_C = "sha256:" + ("c" * 64)
SYNTHETIC_THRESHOLD_PROFILE_ID = (
    "sporespore_qsdk_r24d2_synthetic_zero_world_canary_thresholds_v1"
)


def _zero_interventions() -> dict[str, int]:
    return {
        "root_force_application_count": 0,
        "root_torque_application_count": 0,
        "root_impulse_application_count": 0,
        "root_pose_write_count": 0,
        "root_velocity_write_count": 0,
        "pin_or_guide_constraint_count": 0,
        "hidden_body_actuation_count": 0,
        "pose_teleport_count": 0,
        "collision_disable_count": 0,
        "contact_relabel_count": 0,
        "gravity_mutation_count": 0,
        "time_scale_mutation_count": 0,
        "engine_specific_policy_branch_count": 0,
    }


def synthetic_r24d39_publication_arguments_v1(core: Any) -> dict[str, Any]:
    """Return one full core-valid source publication without native imports."""

    recovery_descriptor = r24d22_recovery_s169_morphology()
    recovery = core.compile_recovery_morphology_v1(recovery_descriptor)
    descriptor = deepcopy(recovery_descriptor["base_descriptor"])
    morphology = recovery["morphology"]
    geometry = recovery["geometry"]
    capability = mujoco_recovery_capability_v1()
    capability_sha256 = core.canonicalize_json(capability)["sha256"]
    ordered_joint_ids = morphology["ordered_joint_ids"]
    ordered_actuator_ids = morphology["ordered_actuator_ids"]
    ordered_contact_site_ids = morphology["ordered_contact_site_ids"]
    ordered_body_ids = morphology["ordered_body_ids"]
    torso_height = float(geometry["initial_torso_center_y_m"])

    state = {
        "schema_version": "sporespore_state_frame_v1",
        "semantic_step": SEMANTIC_STEP,
        "sample_time_s": SEMANTIC_STEP * OUTER_STEP_DURATION_S,
        "base_pose_world": {
            "position_m": {"x": 0.0, "y": torso_height, "z": 0.0},
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
            for joint_id in ordered_joint_ids
        ],
        "ordered_contact_observations": [
            {
                "contact_site_id": site_id,
                "presence": True,
                "bears_support": True,
                "normal_load_n": None,
                "provenance": {
                    "adapter_id": ADAPTER_ID,
                    "engine_contact_ids": [f"{site_id}_synthetic_native_contact"],
                    "aggregation_rule_id": "r24d39_zero_world_bearing_v1",
                    "quality": "qualified_bearing",
                },
            }
            for site_id in ordered_contact_site_ids
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
        "adapter_capability_sha256": capability_sha256,
    }
    interventions = _zero_interventions()
    observation_base = {
        "task_id": TASK_ID,
        "semantics_id": SEMANTICS_ID,
        "actuator_profile_id": ACTUATOR_PROFILE_ID,
        "semantic_step": SEMANTIC_STEP,
        "outer_step_duration_s": OUTER_STEP_DURATION_S,
        "state": state,
        "center_of_mass": {
            "position_world_m": {"x": 0.0, "y": torso_height, "z": 0.0},
            "linear_velocity_world_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
            "source_measurement": True,
        },
        "ordered_foot_bearing_observations": [
            {
                "contact_site_id": site_id,
                "bearing_normal_impulse_ns": 0.05,
                "ordinary_unilateral_contact": True,
                "source_measurement": True,
            }
            for site_id in ordered_contact_site_ids
        ],
        "ordered_body_clearance_observations": [
            {
                "adapter_id": ADAPTER_ID,
                "body_id": body_id,
                "nonfoot_contact_present": False,
                "ventral_surface_contact": False,
                "accumulated_nonfoot_normal_impulse_ns": 0.0,
                "minimum_nonfoot_clearance_m": 0.01,
                "engine_contact_ids": [],
                "classification_rule_id": "r24d39_zero_world_nonfoot_v1",
                "foot_site_contacts_excluded": True,
                "source_measurement": True,
            }
            for body_id in ordered_body_ids
        ],
        "applied_actuation": {
            "adapter_id": ADAPTER_ID,
            "adapter_receipt_sha256": SHA_A,
            "source_semantic_step": SEMANTIC_STEP,
            "command_id": "r24d39_zero_world_candidate_command_v1",
            "command_sha256": SHA_B,
            "actuator_profile_id": ACTUATOR_PROFILE_ID,
            "actuator_profile_sha256": (
                R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
            ),
            "zero_command": False,
            "ordered_applied_impulses": [
                {
                    "actuator_id": actuator_id,
                    "applied_angular_impulse_nms": 0.0,
                    "host_clamped": False,
                }
                for actuator_id in ordered_actuator_ids
            ],
            "source_measurement": True,
        },
        "external_interventions": interventions,
        "controller_ownership": {
            "owner": "recovery",
            "recovery_controller_id": (
                "sporespore_exact_s169_prone_to_standing_controller_v1"
            ),
            "stance_controller_id": None,
            "handoff_event_count": 0,
            "fallback_controller_active": False,
            "source_measurement": True,
        },
        "engine_step_identity": {
            "schema_version": "sporespore_recovery_engine_step_identity_v1",
            "source_kind": "native_post_step",
            "adapter_id": ADAPTER_ID,
            "engine": ENGINE_ID,
            "capability_sha256": capability_sha256,
            "source_trace_sha256": SHA_C,
            "semantic_step": SEMANTIC_STEP,
            "host_step_before": SEMANTIC_STEP,
            "host_step_after": SEMANTIC_STEP + 1,
            "native_solver_substep_count": 5,
            "post_step_observation": True,
            "engine_identity_exposed_to_policy": False,
        },
    }
    mapping_request = synthetic_r24d38_mapping_request_v1()
    mapping_request["observation_base"] = observation_base
    return {
        "mapping_request": mapping_request,
        "descriptor": descriptor,
        "morphology_context": {
            "schema_version": "sporespore_recovery_morphology_context_v1",
            "recovery_morphology_id": recovery["recovery_morphology_id"],
            "recovery_descriptor": recovery["descriptor"],
            "recovery_descriptor_sha256": recovery["descriptor_sha256"],
            "base_descriptor_sha256": recovery["base_descriptor_sha256"],
            "base_morphology_spec_sha256": recovery["base_morphology_spec_sha256"],
            "recovery_morphology_spec_sha256": recovery[
                "recovery_morphology_spec_sha256"
            ],
        },
        "capability_sha256": capability_sha256,
        "runtime_qualification_sha256": SHA_A,
        "arm_kind": "candidate_command",
        "phase": "establish_distal_support",
    }


def synthetic_r24d40_native_invariant_case_v1(
    core: Any,
    *,
    arm_kind: str = "candidate_command",
    phase: str = "establish_distal_support",
    semantic_step: int = 0,
) -> dict[str, Any]:
    """Build one zero-world native-shaped step and its exact V2 publication."""

    if arm_kind not in {"candidate_command", "matched_zero_command"}:
        raise ValueError("R24D40_FIXTURE_ARM_KIND_INVALID")
    if phase not in {
        "confirm_prone",
        "establish_distal_support",
        "raise_body",
        "stance_handoff",
        "stance_dwell",
    }:
        raise ValueError("R24D40_FIXTURE_PHASE_INVALID")
    if (
        not isinstance(semantic_step, int)
        or isinstance(semantic_step, bool)
        or semantic_step < 0
    ):
        raise ValueError("R24D40_FIXTURE_SEMANTIC_STEP_INVALID")
    arguments = synthetic_r24d39_publication_arguments_v1(core)
    arguments["phase"] = phase
    mapping_request = synthetic_r24d38_mapping_request_v1(
        native_timestep_s=1.0 / 600.0,
    )
    mapping_request["observation_base"] = deepcopy(
        arguments["mapping_request"]["observation_base"]
    )
    arguments["mapping_request"] = mapping_request
    selected_batch = deepcopy(mapping_request["ordered_native_component_batches"][0])
    selected_batch["semantic_step"] = semantic_step
    mapping_request["ordered_native_component_batches"] = [selected_batch]
    observation_base = mapping_request["observation_base"]
    observation_base["semantic_step"] = semantic_step
    observation_base["outer_step_duration_s"] = sum(
        float(receipt["native_timestep_s"])
        for receipt in selected_batch["ordered_substep_receipts"]
    )
    observation_base["state"]["semantic_step"] = semantic_step
    observation_base["state"]["sample_time_s"] = (
        semantic_step * observation_base["outer_step_duration_s"]
    )
    observation_base["applied_actuation"]["source_semantic_step"] = semantic_step
    observation_base["engine_step_identity"].update(
        {
            "semantic_step": semantic_step,
            "host_step_before": semantic_step,
            "host_step_after": semantic_step + 1,
        }
    )
    if arm_kind == "matched_zero_command":
        observation_base["applied_actuation"].update(
            {
                "zero_command": True,
                "command_id": "r24d40_zero_world_matched_zero_command_v1",
            }
        )
        observation_base["controller_ownership"] = {
            "owner": "none",
            "recovery_controller_id": None,
            "stance_controller_id": None,
            "handoff_event_count": 0,
            "fallback_controller_active": False,
            "source_measurement": True,
        }
    elif phase in {"stance_handoff", "stance_dwell"}:
        observation_base["controller_ownership"] = {
            "owner": "stance",
            "recovery_controller_id": None,
            "stance_controller_id": STANCE_CONTROLLER_ID,
            "handoff_event_count": 1,
            "fallback_controller_active": False,
            "source_measurement": True,
        }
    arguments["arm_kind"] = arm_kind

    time_advance = observation_base["outer_step_duration_s"]
    native_step = {
        "schema_version": "sporespore_mujoco_recovery_native_step_receipt_v4",
        "route_id": (
            "sporespore_mujoco_exact_s169_native_recovery_implicit_step_energy_v3"
        ),
        "semantic_step": semantic_step,
        "host_step_before": semantic_step,
        "host_step_after": semantic_step + 1,
        "time_before_s": semantic_step * time_advance,
        "time_after_s": (semantic_step + 1) * time_advance,
        "native_substep_count": 5,
        "solver_step_count_after": 5,
        "current_mechanical_energy_j": mapping_request["current_mechanical_energy_j"],
        "implicit_substep_energy_receipts": deepcopy(
            selected_batch["ordered_substep_receipts"]
        ),
    }
    observation_base["engine_step_identity"]["source_trace_sha256"] = str(
        core.canonicalize_json(native_step)["sha256"]
    )
    from .recovery_observation_v2_route import publish_recovery_observation_v2

    publication = publish_recovery_observation_v2(core, **arguments)
    if publication.get("support_status") != "supported_exact":
        raise ValueError("R24D40_FIXTURE_PUBLICATION_REFUSED")
    return {
        "publication": publication,
        "native_step": native_step,
        "ordered_native_component_batches": [selected_batch],
        "expected_arm_kind": arm_kind,
        "expected_phase": phase,
    }


def synthetic_r24d39_supervisor_observation_v2(
    publication: dict[str, Any],
    *,
    arm_kind: str,
) -> dict[str, Any]:
    """Adapt the published V2 value to the existing synthetic supervisor gate.

    R24D39's mapping inputs are synthetic receipts even though their schema is
    the future native route schema.  This explicit source-kind substitution is
    used only to cross the step/evaluator ABI without opening a physical
    question.  It does not alter the separately tested native publication.
    """

    observation = deepcopy(publication["portable_observation"])
    observation["engine_step_identity"]["source_kind"] = "synthetic_zero_world_canary"
    observation["engine_step_identity"]["native_solver_substep_count"] = 0
    if arm_kind == "candidate_command":
        return observation
    if arm_kind != "matched_zero_command":
        raise ValueError("R24D39_FIXTURE_ARM_KIND_INVALID")
    observation["applied_actuation"]["zero_command"] = True
    observation["applied_actuation"]["command_id"] = (
        "r24d39_zero_world_matched_zero_command_v1"
    )
    observation["controller_ownership"] = {
        "owner": "none",
        "recovery_controller_id": None,
        "stance_controller_id": None,
        "handoff_event_count": 0,
        "fallback_controller_active": False,
        "source_measurement": True,
    }
    return observation


def synthetic_r24d39_initialize_request_v2(
    publication: dict[str, Any],
    *,
    arm_kind: str = "candidate_command",
) -> dict[str, Any]:
    """Build the unchanged morphology-aware initializer request."""

    collection = publication["collection_request"]
    return {
        "schema_version": "sporespore_recovery_initialize_request_v2",
        "task_id": collection["task_id"],
        "semantics_id": collection["semantics_id"],
        "actuator_profile_id": collection["actuator_profile_id"],
        "threshold_profile_id": SYNTHETIC_THRESHOLD_PROFILE_ID,
        "descriptor": deepcopy(collection["descriptor"]),
        "morphology_context": deepcopy(collection["morphology_context"]),
        "adapter_capability": deepcopy(collection["adapter_capability"]),
        "arm_kind": arm_kind,
    }


def synthetic_r24d39_step_request_v3(
    publication: dict[str, Any],
    *,
    memory: dict[str, Any],
) -> dict[str, Any]:
    """Build one true observation-V2 supervisor request."""

    collection = publication["collection_request"]
    return {
        "schema_version": "sporespore_recovery_step_request_v3",
        "descriptor": deepcopy(collection["descriptor"]),
        "morphology_context": deepcopy(collection["morphology_context"]),
        "adapter_capability": deepcopy(collection["adapter_capability"]),
        "memory": deepcopy(memory),
        "observation": synthetic_r24d39_supervisor_observation_v2(
            publication,
            arm_kind="candidate_command",
        ),
    }


def _initial_state_sha256(core: Any, observation: dict[str, Any]) -> str:
    state = observation["state"]
    energy = observation["energy_balance"]
    initial_state = {
        "base_pose_world": state["base_pose_world"],
        "base_twist_world": state["base_twist_world"],
        "ordered_joint_observations": state["ordered_joint_observations"],
        "ordered_contact_observations": state["ordered_contact_observations"],
        "gravity_world_m_s2": state["gravity_world_m_s2"],
        "task_frame": state["task_frame"],
        "center_of_mass": observation["center_of_mass"],
        "ordered_foot_bearing_observations": observation[
            "ordered_foot_bearing_observations"
        ],
        "ordered_body_clearance_observations": observation[
            "ordered_body_clearance_observations"
        ],
        "energy_initial_mechanical_j": energy["initial_mechanical_energy_j"],
        "energy_current_mechanical_j": energy["current_mechanical_energy_j"],
    }
    return str(core.canonicalize_json(initial_state)["sha256"])


def synthetic_r24d39_evaluation_request_v3(
    core: Any,
    publication: dict[str, Any],
) -> dict[str, Any]:
    """Build a paired one-observation V2 ABI conformance request.

    The deliberately incomplete traces prove parser, source, identity, replay,
    and no-world semantics.  They are not a behavior canary and cannot yield a
    recovery or standing claim.
    """

    collection = publication["collection_request"]
    candidate = synthetic_r24d39_supervisor_observation_v2(
        publication,
        arm_kind="candidate_command",
    )
    matched_zero = synthetic_r24d39_supervisor_observation_v2(
        publication,
        arm_kind="matched_zero_command",
    )
    initial_state_sha256 = _initial_state_sha256(core, candidate)
    if _initial_state_sha256(core, matched_zero) != initial_state_sha256:
        raise ValueError("R24D39_FIXTURE_INITIAL_STATE_IDENTITY_MISMATCH")
    return {
        "schema_version": "sporespore_recovery_evaluation_request_v3",
        "task_id": collection["task_id"],
        "semantics_id": collection["semantics_id"],
        "actuator_profile_id": collection["actuator_profile_id"],
        "threshold_profile_id": SYNTHETIC_THRESHOLD_PROFILE_ID,
        "descriptor": deepcopy(collection["descriptor"]),
        "morphology_context": deepcopy(collection["morphology_context"]),
        "adapter_capability": deepcopy(collection["adapter_capability"]),
        "candidate_trace": {
            "schema_version": "sporespore_recovery_trace_v2",
            "arm_kind": "candidate_command",
            "declared_initial_state_sha256": initial_state_sha256,
            "observations": [candidate],
        },
        "matched_zero_command_trace": {
            "schema_version": "sporespore_recovery_trace_v2",
            "arm_kind": "matched_zero_command",
            "declared_initial_state_sha256": initial_state_sha256,
            "observations": [matched_zero],
        },
    }
