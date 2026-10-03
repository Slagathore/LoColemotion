"""Deterministic zero-world fixtures for the R24D38 mapping seam."""

from __future__ import annotations

from . import energy_work_projection
from .implicit_step_energy import measure_implicit_step_energy_work_v3
from .recovery_energy_v2_mapping import (
    IMPLICIT_STEP_ENERGY_PROFILE_ID,
    MAPPING_REQUEST_SCHEMA,
    R24D36_NATIVE_SUBSTEPS_PER_OUTER_STEP,
    R24D36_ROUTE_ID,
    R24D36_SUBSTEP_SCHEMA,
    SPARSE_ACTUATOR_MOMENT_PROFILE_ID,
    SPARSE_ACTUATOR_MOMENT_RECEIPT_SCHEMA,
)


TASK_ID = "sporespore_canonical_ventral_prone_to_four_foot_stance_v1"
SEMANTICS_ID = "sporespore_qsdk_r24d2_portable_recovery_semantics_v1"
ACTUATOR_PROFILE_ID = "sporespore_r23d60_selected_s169_actuator_cap_v1"
ADAPTER_ID = "sporespore_mujoco_adapter"
ENGINE_ID = "mujoco_native"
HISTORICAL_ENERGY_PROFILE_ID = (
    "mujoco_independent_constraint_and_passive_work_energy_ledger_v2"
)


def _sparse_receipt() -> dict[str, object]:
    return {
        "schema_version": SPARSE_ACTUATOR_MOMENT_RECEIPT_SCHEMA,
        "profile_id": SPARSE_ACTUATOR_MOMENT_PROFILE_ID,
        "public_expansion_function": "mju_sparse2dense",
        "independent_dense_crosscheck_passed": True,
        "nout": 1,
        "nv": 1,
        "nJmom": 1,
        "sparse_values": [1.0],
        "moment_rownnz": [1],
        "moment_rowadr": [0],
        "moment_colind": [0],
        "dense_actuator_moment": [[1.0]],
    }


def _substep_batch(
    *,
    target: tuple[float, ...],
    pre_velocity: tuple[float, ...],
    pre_force: tuple[float, ...],
    pre_qvel: tuple[float, ...],
    post_qvel: tuple[float, ...],
    qfrc_actuator: tuple[float, ...],
    qfrc_constraint: tuple[float, ...],
    qfrc_damper: tuple[float, ...],
    native_timestep_s: float = 0.1,
) -> tuple[list[dict[str, object]], float, float]:
    dt = native_timestep_s
    zero = (0.0,)
    implicit = measure_implicit_step_energy_work_v3(
        timestep_s=dt,
        target_actuator_velocity_rad_s=target,
        reported_pre_actuator_velocity_rad_s=pre_velocity,
        reported_pre_actuator_force_nm=pre_force,
        velocity_gain_nm_s_per_rad=(10.0,),
        force_range_lower_nm=(-100.0,),
        force_range_upper_nm=(100.0,),
        actuator_moment=((1.0,),),
        pre_generalized_velocity=pre_qvel,
        post_generalized_velocity=post_qvel,
        reported_pre_generalized_actuator_force=qfrc_actuator,
        reported_pre_generalized_constraint_force=qfrc_constraint,
        reported_pre_generalized_damper_force=zero,
        reported_pre_generalized_fluid_force=zero,
        reported_pre_generalized_adhesion_force=zero,
    )
    count = R24D36_NATIVE_SUBSTEPS_PER_OUTER_STEP
    historical_constraint = qfrc_constraint[0] * pre_qvel[0] * dt
    historical_damper = qfrc_damper[0] * pre_qvel[0] * dt
    historical_fluid = 0.0
    historical_adhesion = 0.0
    midpoint_velocity = 0.5 * (pre_qvel[0] + post_qvel[0])
    centered_damper = qfrc_damper[0] * midpoint_velocity * dt
    centered_dissipated = -(
        implicit.centered_constraint_work_j
        + centered_damper
        + implicit.centered_fluid_work_j
        + implicit.centered_adhesion_work_j
    )
    historical = {
        "energy_ledger_profile_id": HISTORICAL_ENERGY_PROFILE_ID,
        "left_endpoint_actuator_work_j": pre_force[0] * pre_velocity[0] * dt,
        "left_endpoint_generalized_actuator_work_j": (
            qfrc_actuator[0] * pre_qvel[0] * dt
        ),
        "left_endpoint_constraint_work_j": historical_constraint,
        "left_endpoint_damper_work_j": historical_damper,
        "left_endpoint_fluid_work_j": historical_fluid,
        "left_endpoint_adhesion_work_j": historical_adhesion,
        "left_endpoint_dissipated_energy_j": -(
            historical_constraint
            + historical_damper
            + historical_fluid
            + historical_adhesion
        ),
    }

    def receipt(native_substep: int) -> dict[str, object]:
        return {
            "schema_version": R24D36_SUBSTEP_SCHEMA,
            "measurement_profile_id": IMPLICIT_STEP_ENERGY_PROFILE_ID,
            "native_substep": native_substep,
            "native_timestep_s": dt,
            "preintegration_stage": (
                "after_mj_fwd_constraint_and_mj_check_acc_before_mj_implicit"
            ),
            "target_actuator_velocity_rad_s": list(target),
            "reported_pre_actuator_velocity_rad_s": list(pre_velocity),
            "reported_pre_actuator_force_nm": list(pre_force),
            "velocity_gain_nm_s_per_rad": [10.0],
            "force_range_lower_nm": [-100.0],
            "force_range_upper_nm": [100.0],
            "actuator_moment": [[1.0]],
            "pre_generalized_velocity": list(pre_qvel),
            "post_generalized_velocity": list(post_qvel),
            "reported_pre_generalized_actuator_force": list(qfrc_actuator),
            "reported_pre_generalized_constraint_force": list(qfrc_constraint),
            "reported_pre_generalized_damper_force": list(qfrc_damper),
            "reported_pre_generalized_fluid_force": list(zero),
            "reported_pre_generalized_adhesion_force": list(zero),
            "historical_v2": historical,
            "implicit_v3": {
                "energy_ledger_profile_id": IMPLICIT_STEP_ENERGY_PROFILE_ID,
                "effective_implicit_actuator_force_nm": list(
                    implicit.effective_implicit_actuator_force_nm
                ),
                "force_limited_at_pre_step": list(implicit.force_limited_at_pre_step),
                "effective_centered_actuator_work_j": (
                    implicit.effective_centered_actuator_work_j
                ),
                "effective_centered_generalized_actuator_work_j": (
                    implicit.effective_centered_generalized_actuator_work_j
                ),
                "centered_constraint_work_j": implicit.centered_constraint_work_j,
                "centered_damper_work_j": centered_damper,
                "centered_fluid_work_j": implicit.centered_fluid_work_j,
                "centered_adhesion_work_j": implicit.centered_adhesion_work_j,
                "centered_dissipated_energy_j": centered_dissipated,
            },
            "actuator_moment_expansion": _sparse_receipt(),
            "actuator_moment_expansion_profile_id": (SPARSE_ACTUATOR_MOMENT_PROFILE_ID),
            "historical_v2_energy_preprojection": (
                energy_work_projection.classify_energy_work_for_portable_v1(
                    constraint_work_j=historical_constraint,
                    damper_work_j=historical_damper,
                    fluid_work_j=historical_fluid,
                    adhesion_work_j=historical_adhesion,
                ).receipt_v1()
            ),
            "portable_v3_energy_preprojection": (
                energy_work_projection.classify_energy_work_for_portable_v1(
                    constraint_work_j=implicit.centered_constraint_work_j,
                    damper_work_j=centered_damper,
                    fluid_work_j=implicit.centered_fluid_work_j,
                    adhesion_work_j=implicit.centered_adhesion_work_j,
                ).receipt_v1()
            ),
            "energy_work_preprojection_profile_id": (energy_work_projection.PROFILE_ID),
        }

    return (
        [receipt(index) for index in range(count)],
        implicit.effective_centered_actuator_work_j * count,
        implicit.centered_constraint_work_j * count,
    )


def synthetic_r24d38_mapping_request_v1(
    *,
    centered_damper_force: float = 0.0,
    external_intervention_count: int = 0,
    native_timestep_s: float = 0.1,
) -> dict[str, object]:
    """Create two ordered outer-step batches through the production receipt type."""

    positive, positive_actuator, positive_constraint = _substep_batch(
        target=(1.0,),
        pre_velocity=(0.0,),
        pre_force=(10.0,),
        pre_qvel=(0.0,),
        post_qvel=(1.0 / 3.0,),
        qfrc_actuator=(10.0,),
        qfrc_constraint=(3.0,),
        qfrc_damper=(centered_damper_force,),
        native_timestep_s=native_timestep_s,
    )
    negative, negative_actuator, negative_constraint = _substep_batch(
        target=(1.0,),
        pre_velocity=(1.0,),
        pre_force=(0.0,),
        pre_qvel=(1.0,),
        post_qvel=(0.8,),
        qfrc_actuator=(0.0,),
        qfrc_constraint=(-4.0,),
        qfrc_damper=(0.0,),
        native_timestep_s=native_timestep_s,
    )
    cumulative_actuator = positive_actuator + negative_actuator
    cumulative_constraint = positive_constraint + negative_constraint
    initial_energy = 10.0
    current_energy = initial_energy + cumulative_actuator + cumulative_constraint
    interventions = {
        "root_force_application_count": external_intervention_count,
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
    return {
        "schema_version": MAPPING_REQUEST_SCHEMA,
        "source_route_id": R24D36_ROUTE_ID,
        "initial_mechanical_energy_j": initial_energy,
        "current_mechanical_energy_j": current_energy,
        "observation_base": {
            "task_id": TASK_ID,
            "semantics_id": SEMANTICS_ID,
            "actuator_profile_id": ACTUATOR_PROFILE_ID,
            "semantic_step": 13,
            "outer_step_duration_s": 0.5,
            "state": {
                "schema_version": "sporespore_state_frame_v1",
                "semantic_step": 13,
                "zero_world_fixture": True,
            },
            "center_of_mass": {"source_measurement": True},
            "ordered_foot_bearing_observations": [],
            "ordered_body_clearance_observations": [],
            "applied_actuation": {"source_measurement": True},
            "external_interventions": interventions,
            "controller_ownership": {
                "controller_owner": "recovery_supervisor",
            },
            "engine_step_identity": {
                "schema_version": "sporespore_recovery_engine_step_identity_v1",
                "source_kind": "native_post_step",
                "adapter_id": ADAPTER_ID,
                "engine": ENGINE_ID,
                "capability_sha256": "sha256:" + ("a" * 64),
                "source_trace_sha256": "sha256:" + ("b" * 64),
                "semantic_step": 13,
                "host_step_before": 13,
                "host_step_after": 14,
                "native_solver_substep_count": (R24D36_NATIVE_SUBSTEPS_PER_OUTER_STEP),
                "post_step_observation": True,
                "engine_identity_exposed_to_policy": False,
            },
        },
        "ordered_native_component_batches": [
            {
                "semantic_step": 12,
                "ordered_substep_receipts": positive,
            },
            {
                "semantic_step": 13,
                "ordered_substep_receipts": negative,
            },
        ],
    }
