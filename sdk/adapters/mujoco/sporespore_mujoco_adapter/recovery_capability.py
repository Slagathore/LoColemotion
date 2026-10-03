"""Zero-world MuJoCo 3.11 recovery-observation capability mapping.

The mapping names native sources but deliberately does not import ``mujoco``,
construct an ``MjModel``/``MjData``, or call ``mj_step``. In particular,
``mj_contactForce`` yields force; the future collector must multiply its
normal component by the exact integrated native timestep before publishing a
portable impulse. A force sample must never be relabeled as an impulse.
"""

from __future__ import annotations

from copy import deepcopy
from typing import Any


CAPABILITY_SCHEMA_VERSION = "sporespore_recovery_adapter_capability_v1"
ADAPTER_ID = "sporespore_mujoco_adapter"
ENGINE_ID = "mujoco_native"
ENGINE_VERSION = "3.11.0"
MAPPING_ID = "sporespore_mujoco_native_recovery_observation_capability_v2"
TASK_ID = "sporespore_canonical_ventral_prone_to_four_foot_stance_v1"
SEMANTICS_ID = "sporespore_qsdk_r24d2_portable_recovery_semantics_v1"
ACTUATOR_PROFILE_ID = (
    "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
)
THRESHOLD_PROFILE_ID = (
    "sporespore_qsdk_r24d2_synthetic_zero_world_canary_thresholds_v1"
)

ORDERED_CHANNELS = (
    "canonical_body_pose_and_twist",
    "whole_system_center_of_mass_position_and_velocity",
    "ordered_joint_position_and_velocity",
    "ordered_foot_bearing_contact_observations",
    "classified_nonfoot_contact_observations",
    "applied_actuation_receipts",
    "external_intervention_ledger",
    "controller_ownership_receipt",
    "energy_balance_ledger",
    "engine_step_identity",
)

_SOURCES: tuple[tuple[tuple[str, ...], str], ...] = (
    (
        ("MjData.xpos", "MjData.xquat", "MjData.cvel"),
        "mujoco_xpos_xquat_cvel_to_canonical_y_up_right_handed_v1",
    ),
    (
        (
            "MjData.subtree_com",
            "mujoco.mj_subtreeVel",
            "MjData.subtree_linvel",
        ),
        "mujoco_root_subtree_com_and_velocity_projection_v1",
    ),
    (
        ("MjData.qpos", "MjData.qvel", "MjModel.jnt_qposadr", "MjModel.jnt_dofadr"),
        "mujoco_joint_address_ordered_position_velocity_projection_v1",
    ),
    (
        ("MjData.contact", "mujoco.mj_contactForce", "MjModel.opt.timestep"),
        "mujoco_post_step_contact_normal_force_integrated_over_exact_native_dt_v1",
    ),
    (
        (
            "MjData.contact",
            "mujoco.mj_geomDistance",
            "MjModel.geom_bodyid",
            "MjModel.geom_user",
        ),
        "mujoco_geom_identity_nonfoot_classification_and_clearance_query_v1",
    ),
    (
        (
            "MjData.actuator_force",
            "MjData.qfrc_actuator",
            "MjModel.opt.timestep",
            "sporespore_mujoco_adapter.applied_actuation_ledger_v1",
        ),
        "mujoco_applied_actuator_force_integrated_over_exact_outer_step_v1",
    ),
    (
        ("sporespore_mujoco_adapter.append_only_intervention_call_ledger_v1",),
        "mujoco_adapter_owned_exact_intervention_counter_projection_v1",
    ),
    (
        ("sporespore_mujoco_adapter.exclusive_controller_owner_ledger_v1",),
        "mujoco_adapter_owned_controller_handoff_projection_v1",
    ),
    (
        (
            "mujoco.mj_energyPos",
            "mujoco.mj_energyVel",
            "MjData.energy",
            "MjData.qfrc_constraint",
            "MjData.qfrc_damper",
            "MjData.qfrc_fluid",
            "MjData.qfrc_adhesion",
            "MjData.qvel",
            "sporespore_mujoco_adapter.measured_actuator_and_native_energy_work_ledger_v2",
        ),
        "mujoco_mechanical_energy_independent_native_work_balance_ledger_v2",
    ),
    (
        ("MjData.time", "sporespore_mujoco_adapter.mj_step_identity_ledger_v1"),
        "mujoco_exact_post_step_time_and_native_substep_identity_v1",
    ),
)


class RecoveryCapabilityError(RuntimeError):
    """Stable fail-closed error for the zero-world mapping surface."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise RecoveryCapabilityError(code)


def mujoco_recovery_capability_v1() -> dict[str, Any]:
    """Return a fresh exact-order capability receipt with no host side effect."""

    channels = []
    for channel_id, (source_ids, mapping_rule_id) in zip(
        ORDERED_CHANNELS,
        _SOURCES,
        strict=True,
    ):
        channels.append(
            {
                "channel": channel_id,
                "support": "supported_measured",
                "host_source_ids": list(source_ids),
                "mapping_rule_id": mapping_rule_id,
                "source_measurement_only": True,
                "synthesized_when_missing": False,
            }
        )
    return {
        "schema_version": CAPABILITY_SCHEMA_VERSION,
        "adapter_id": ADAPTER_ID,
        "engine": ENGINE_ID,
        "engine_version": ENGINE_VERSION,
        "mapping_id": MAPPING_ID,
        "native_engine": True,
        "ordered_channels": channels,
        "host_pose_label_used_for_success": False,
        "fallback_control_permitted": False,
        "engine_identity_exposed_to_policy": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }

def _validate_local(capability: dict[str, Any]) -> None:
    _require(capability.get("schema_version") == CAPABILITY_SCHEMA_VERSION, "SCHEMA")
    _require(capability.get("adapter_id") == ADAPTER_ID, "ADAPTER")
    _require(capability.get("engine") == ENGINE_ID, "ENGINE")
    _require(capability.get("engine_version") == ENGINE_VERSION, "ENGINE_VERSION")
    _require(capability.get("mapping_id") == MAPPING_ID, "MAPPING")
    channels = capability.get("ordered_channels")
    _require(isinstance(channels, list) and len(channels) == 10, "CHANNEL_COUNT")
    assert isinstance(channels, list)
    for index, channel in enumerate(channels):
        _require(isinstance(channel, dict), "CHANNEL_RECORD")
        _require(channel.get("channel") == ORDERED_CHANNELS[index], "CHANNEL_ORDER")
        _require(channel.get("support") == "supported_measured", "CHANNEL_SUPPORT")
        source_ids = channel.get("host_source_ids")
        _require(
            isinstance(source_ids, list)
            and bool(source_ids)
            and all(isinstance(value, str) and value for value in source_ids),
            "CHANNEL_SOURCE",
        )
        _require(bool(channel.get("mapping_rule_id")), "CHANNEL_MAPPING")
        _require(channel.get("source_measurement_only") is True, "CHANNEL_MEASURED")
        _require(channel.get("synthesized_when_missing") is False, "CHANNEL_SYNTHESIS")
    _require(capability.get("native_engine") is True, "NATIVE_ENGINE")
    for field in (
        "host_pose_label_used_for_success",
        "fallback_control_permitted",
        "engine_identity_exposed_to_policy",
        "physics_state_modified",
        "physical_acceptance_authority",
        "release_authority",
    ):
        _require(capability.get(field) is False, f"BOUNDARY_{field.upper()}")
    for field in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        _require(capability.get(field) == 0, f"COUNT_{field.upper()}")


def run_recovery_capability_preflight(
    core: Any,
    descriptor: dict[str, Any],
) -> dict[str, Any]:
    """Cross the real C ABI and prove typed capability mutations fail closed."""

    capability = mujoco_recovery_capability_v1()
    _validate_local(capability)
    request = {
        "schema_version": "sporespore_recovery_initialize_request_v1",
        "task_id": TASK_ID,
        "semantics_id": SEMANTICS_ID,
        "actuator_profile_id": ACTUATOR_PROFILE_ID,
        "threshold_profile_id": THRESHOLD_PROFILE_ID,
        "descriptor": deepcopy(descriptor),
        "adapter_capability": capability,
        "arm_kind": "candidate_command",
    }
    receipt = core.recovery_initialize_v1(request)
    _require(receipt.get("support_status") == "supported_exact", "PORTABLE_INIT")
    _require(receipt.get("controller_implemented") is False, "CONTROLLER_BOUNDARY")
    for field in (
        "physical_threshold_authority",
        "physical_question_opened",
        "physics_state_modified",
        "prone_to_standing_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        _require(receipt.get(field) is False, f"RECEIPT_{field.upper()}")
    for field in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        _require(receipt.get(field) == 0, f"RECEIPT_{field.upper()}")

    mutations = []
    for mutation_id in (
        "missing_channel",
        "synthesized_channel",
        "world_count",
        "engine_branch",
    ):
        mutated_request = deepcopy(request)
        mutated = mutated_request["adapter_capability"]
        if mutation_id == "missing_channel":
            mutated["ordered_channels"].pop()
        elif mutation_id == "synthesized_channel":
            mutated["ordered_channels"][3]["synthesized_when_missing"] = True
        elif mutation_id == "world_count":
            mutated["world_build_count"] = 1
        else:
            mutated["engine_identity_exposed_to_policy"] = True
        mutated_receipt = core.recovery_initialize_v1(mutated_request)
        rejected = mutated_receipt.get("support_status") == "unsupported_capability"
        _require(rejected, f"MUTATION_ACCEPTED_{mutation_id.upper()}")
        mutations.append({"mutation_id": mutation_id, "rejected": True})

    return {
        "schema_version": (
            "sporespore_qsdk_r24d2_mujoco_recovery_capability_preflight_v1"
        ),
        "ok": True,
        "question_class": "non_physical_source_conformance",
        "adapter_id": ADAPTER_ID,
        "engine_version": ENGINE_VERSION,
        "mapping_id": MAPPING_ID,
        "capability_sha256": receipt["capability_sha256"],
        "required_channel_count": 10,
        "force_to_impulse_rule_explicit": True,
        "force_sample_relabelled_as_impulse": False,
        "mutation_rejection_count": len(mutations),
        "mutations": mutations,
        "mujoco_import_count": 0,
        "native_runtime_observation_collection_executed": False,
        "controller_implemented": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "prone_to_standing_claimed": False,
        "cross_engine_equivalence_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
