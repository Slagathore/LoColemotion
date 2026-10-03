#!/usr/bin/env python3
"""Reusable audit for one consumed two-step Godot recovery route ghost."""

from __future__ import annotations

import copy
import json
import math
from pathlib import Path
import subprocess
import sys
from typing import Any

from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    core_canonical_bytes,
    complete_in_run_physical_invariant_projection,
    exact,
    git,
    load,
    require,
    sha256,
    source_bytes,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
    verify_retained_commit,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
    verify_two_step_native_portable_route,
)


FORCE_BODY_IMPULSE_PROFILE = "force_based_body_impulse_position_solver_v1"
SOLVER_COUPLED_COMPLETE_ENERGY_PROFILE = (
    "solver_coupled_native_motor_complete_energy_v1"
)
DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE = (
    "solver_coupled_native_motor_discrete_staging_complete_energy_v1"
)
ROTATION_AWARE_DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE = (
    "solver_coupled_native_motor_rotation_aware_discrete_staging_complete_energy_v1"
)
CONTIGUOUS_ROTATION_AWARE_DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE = (
    "solver_coupled_native_motor_contiguous_rotation_aware_discrete_staging_"
    "complete_energy_v1"
)


def _valid_sha256(value: Any) -> bool:
    return (
        isinstance(value, str)
        and value.startswith("sha256:")
        and len(value) == 71
        and all(character in "0123456789abcdef" for character in value[7:])
    )


def _finite_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _verify_force_body_impulse_profile(
    *,
    application: dict[str, Any],
    actuator_mapping_id: str,
    work_mapping_id: str,
    projection_key: str,
    projection_schema: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Preserve the exact R140 force/body-impulse closure semantics."""

    verify_exact_paths(
        application,
        {
            "ok": True,
            "actuator_mapping_id": actuator_mapping_id,
            "work_mapping_id": work_mapping_id,
            "validated_command_count": 8,
            "host_write_count": 9,
            "body_impulse_write_count": 9,
            "host_readback_count": 8,
            "joint_space_effective_inertia_population_projection_required": True,
            "aggregate_body_application_required": True,
            "per_actuator_attribution_required": True,
            "input_iteration_order_has_action_authority": False,
            "all_immediate_native_readbacks_inside_guard": True,
            "all_joint_target_errors_nonincreasing": True,
            "joint_target_crossing_count": 0,
            "physics_state_modified": True,
        },
        "ROUTE_PHYSICAL_APPLICATION",
    )
    bodies = application["ordered_body_application_receipts"]
    actuators = application["ordered_receipts"]
    require(len(bodies) == 9 and len(actuators) == 8, "ROUTE_RECEIPT_COUNTS")
    require(
        all(row["call_performed"] and row["call_returned"] for row in bodies)
        and sum(int(row["body_impulse_write_count"]) for row in bodies) == 9,
        "ROUTE_BODY_APPLICATIONS",
    )
    require(
        all(
            row["ok"]
            and row["source_measurement"]
            and not row["target_crossed"]
            and row["population_attribution"]["equal_and_opposite_pair"]
            for row in actuators
        ),
        "ROUTE_ACTUATOR_ATTRIBUTION",
    )

    projection = application[projection_key]
    verify_exact_paths(
        projection,
        {
            "schema_version": projection_schema,
            "ok": True,
            "actuator_count": 8,
            "body_count": 9,
            "nonzero_body_impulse_count": 9,
            "solver_guard_engaged": True,
            "all_joint_target_errors_nonincreasing": True,
            "joint_target_crossing_count": 0,
            "input_iteration_order_has_action_authority": False,
            "published_actuator_caps_changed": False,
            "controller_target_changed": False,
            "outer_guard_changed": False,
            "representation_zero_hold": False,
            "aggregate_body_application_required": True,
            "per_actuator_attribution_required": True,
        },
        "ROUTE_COUPLED_PROJECTION",
    )
    require(
        len(projection["response_matrix"]) == 8
        and all(len(row) == 8 for row in projection["response_matrix"])
        and len(projection["cholesky_pivots"]) == 8
        and all(float(value) > 0.0 for value in projection["cholesky_pivots"])
        and len(projection["ordered_joint_solve_projections"]) == 8,
        "ROUTE_COUPLED_POPULATION",
    )
    named = {
        "coupled_command_application_ok": bool(application["ok"]),
        "all_joint_target_errors_nonincreasing": bool(
            projection["all_joint_target_errors_nonincreasing"]
        ),
        "joint_target_crossing_count": int(projection["joint_target_crossing_count"]),
        "all_cholesky_pivots_positive": all(
            float(value) > 0.0 for value in projection["cholesky_pivots"]
        ),
        "solve_residual_finite": math.isfinite(
            float(projection["maximum_solve_residual_rad_s"])
        ),
        "aggregate_body_application_count_exact": True,
        "all_body_calls_returned": True,
        "all_actuator_receipts_valid": True,
        "all_actuator_receipts_source_measured": True,
        "all_immediate_native_readbacks_inside_guard": bool(
            application["all_immediate_native_readbacks_inside_guard"]
        ),
        "input_iteration_order_has_action_authority": False,
    }
    live = {
        "body_impulse_write_count": 9,
        "native_angular_velocity_total_readback_count": 18,
    }
    return named, live


def _verify_solver_coupled_complete_energy_profile(
    *,
    raw: dict[str, Any],
    application: dict[str, Any],
    actuator_mapping_id: str,
    work_mapping_id: str,
    bindings: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Verify the reusable native-motor route and its two measured partitions."""

    required_bindings = {
        "recovery_controller_id",
        "energy_route_id",
        "application_schema",
        "actuation_realization_id",
        "application_mutation_semantics_id",
        "energy_mapping_profile_id",
        "partition_rule_id",
    }
    rotation_aware_binding_keys = {
        "partition_contract_schema",
        "partition_numerical_term_count",
        "recovery_energy_ledger_profile_id",
        "solver_energy_consumer_contract_schema",
        "solver_energy_telemetry_schema",
        "solver_energy_telemetry_profile_id",
    }
    binding_keys = set(bindings)
    rotation_aware = binding_keys == required_bindings | rotation_aware_binding_keys
    require(
        binding_keys == required_bindings or rotation_aware,
        "ROUTE_SOLVER_PROFILE_BINDINGS",
    )
    verify_exact_paths(
        application,
        {
            "schema_version": bindings["application_schema"],
            "ok": True,
            "semantic_step": 2,
            "actuator_mapping_id": actuator_mapping_id,
            "work_mapping_id": work_mapping_id,
            "validated_command_count": 8,
            "host_write_count": 8,
            "host_readback_count": 8,
            "motor_enabled_count": 8,
            "host_constraint_configuration_write_count": 8,
            "native_joint_motor_enabled_count": 8,
            "active_constraint_motor_configuration_modified": True,
            "pre_solver_rigid_body_state_modified": False,
            "solver_state_advanced": False,
            "solver_step_count": 0,
            "actuation_realization_id": bindings["actuation_realization_id"],
            "application_mutation_semantics_id": bindings[
                "application_mutation_semantics_id"
            ],
            "energy_route_id": bindings["energy_route_id"],
            "energy_mapping_profile_id": bindings["energy_mapping_profile_id"],
            "partition_rule_id": bindings["partition_rule_id"],
            "portable_recovery_controller_id": bindings["recovery_controller_id"],
            "complete_energy_profile_selected": True,
            "solver_coupled_complete_energy_profile_selected": True,
            "complete_energy_sampler_representation": True,
            "native_joint_motors_disabled": False,
            "native_contact_solver_coupled": True,
            "constraint_exchange_source_owned_by_native_solver_telemetry": True,
            "actuator_work_source_owned_by_native_motor_telemetry": True,
            "native_motor_work_partitioned_from_whole_joint_exchange": True,
            "pre_solver_direct_body_impulse_write_count": 0,
            "adapter_side_discrete_staging_event_count": 0,
            "physics_state_modified": True,
            "zero_world_host_surface": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "ROUTE_SOLVER_APPLICATION",
    )
    intents = application["ordered_intents"]
    receipts = application["ordered_receipts"]
    exact((len(intents), len(receipts)), (8, 8), "ROUTE_SOLVER_COMMAND_COUNTS")
    intent_ids = []
    receipt_ids = []
    for label, rows, identities in (
        ("INTENT", intents, intent_ids),
        ("RECEIPT", receipts, receipt_ids),
    ):
        for index, row in enumerate(rows):
            require(isinstance(row, dict), f"ROUTE_SOLVER_{label}_SHAPE:{index}")
            identity = (str(row["actuator_id"]), str(row["joint_id"]))
            require(all(identity), f"ROUTE_SOLVER_{label}_IDENTITY:{index}")
            identities.append(identity)
            require(
                all(
                    _finite_number(row[key])
                    for key in (
                        "canonical_target_velocity_rad_s",
                        "godot_target_velocity_rad_s",
                        "godot_unprojected_target_velocity_rad_s",
                        "godot_projected_target_velocity_rad_s",
                        "godot_host_readback_target_velocity_rad_s",
                        "published_maximum_outer_step_impulse_nms",
                        "host_maximum_impulse_readback_nms",
                    )
                ),
                f"ROUTE_SOLVER_{label}_NONFINITE:{index}",
            )
            verify_exact_paths(
                row,
                {
                    "host_real_command_projection.ok": True,
                    "host_real_command_readback.ok": True,
                    "host_real_command_readback.exact_projected_readback": True,
                    "host_cap_projection.ok": True,
                    "host_cap_projection.native_effective_limit_not_above_published": True,
                },
                f"ROUTE_SOLVER_{label}_HOST_BINDING:{index}",
            )
            exact(
                row["godot_host_readback_target_velocity_rad_s"],
                row["godot_projected_target_velocity_rad_s"],
                f"ROUTE_SOLVER_{label}_READBACK:{index}",
            )
            require(
                float(row["host_maximum_impulse_readback_nms"])
                <= float(row["published_maximum_outer_step_impulse_nms"]),
                f"ROUTE_SOLVER_{label}_CAP:{index}",
            )
    exact(len(set(intent_ids)), 8, "ROUTE_SOLVER_INTENT_IDENTITIES")
    exact(len(set(receipt_ids)), 8, "ROUTE_SOLVER_RECEIPT_IDENTITIES")
    exact(intent_ids, receipt_ids, "ROUTE_SOLVER_COMMAND_IDENTITY_ALIGNMENT")

    projections = raw["ordered_complete_energy_solver_projections"]
    exact(len(projections), 2, "ROUTE_SOLVER_PARTITION_COUNT")
    step_records = (raw["first_step"], raw["second_step"])
    for index, (projection, step) in enumerate(zip(projections, step_records), start=1):
        components = step["native_route"]["measurement"]["source_component_receipts"]
        partition = projection["solver_coupled_partition_receipt"]
        partition_sha = projection["solver_coupled_partition_receipt_sha256"]
        projection_expected: dict[str, Any] = {
            "schema_version": (
                "sporespore_qsdk_godot_route_position_solver_projection_v1"
            ),
            "ok": True,
            "required": True,
            "semantic_step": index,
            "partition_rule_id": bindings["partition_rule_id"],
            "native_motor_work_subtracted_exactly_once": True,
            "motor_work_also_counted_as_constraint_exchange": False,
            "constraint_exchange_partition_disjoint": True,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        if rotation_aware:
            projection_expected.update(
                {
                    "recovery_energy_ledger_profile_id": bindings[
                        "recovery_energy_ledger_profile_id"
                    ],
                    "rotation_integration_exchange_included_exactly_once": True,
                }
            )
        verify_exact_paths(
            projection,
            projection_expected,
            f"ROUTE_SOLVER_PROJECTION:{index}",
        )
        components_expected: dict[str, Any] = {
            "schema_version": (
                "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_source_component_receipts_v1"
            ),
            "semantic_step": index,
            "component_partition_complete": True,
            "mechanical_energy_residual_used_as_work_source": False,
            "source_measurement": True,
            "solver_coupled_partition_receipt_sha256": partition_sha,
        }
        if rotation_aware:
            components_expected.update(
                {
                    "recovery_energy_ledger_profile_id": bindings[
                        "recovery_energy_ledger_profile_id"
                    ],
                    "rotation_integration_exchange_included_exactly_once": True,
                }
            )
        verify_exact_paths(
            components,
            components_expected,
            f"ROUTE_SOLVER_COMPONENTS:{index}",
        )
        exact(
            components["solver_coupled_partition_receipt"],
            partition,
            f"ROUTE_SOLVER_PARTITION_BINDING:{index}",
        )
        require(_valid_sha256(partition_sha), f"ROUTE_SOLVER_PARTITION_SHA:{index}")
        if rotation_aware:
            solver_receipt = projection["solver_energy_exchange_receipt"]
            solver_sha = projection["solver_energy_exchange_receipt_sha256"]
            verify_exact_paths(
                solver_receipt,
                {
                    "schema_version": bindings[
                        "solver_energy_consumer_contract_schema"
                    ],
                    "recovery_energy_ledger_profile_id": bindings[
                        "recovery_energy_ledger_profile_id"
                    ],
                    "telemetry_schema_version": bindings[
                        "solver_energy_telemetry_schema"
                    ],
                    "telemetry_profile_id": bindings[
                        "solver_energy_telemetry_profile_id"
                    ],
                    "rotation_integration_partition_complete": True,
                    "source_measurement": True,
                    "mechanical_energy_residual_used_as_work_source": False,
                },
                f"ROUTE_SOLVER_ROTATION_RECEIPT:{index}",
            )
            require(
                _valid_sha256(solver_sha)
                and sha256(core_canonical_bytes(solver_receipt)) == solver_sha,
                f"ROUTE_SOLVER_ROTATION_RECEIPT_SHA:{index}",
            )
            exact(
                components["solver_energy_exchange_receipt"],
                solver_receipt,
                f"ROUTE_SOLVER_ROTATION_RECEIPT_BINDING:{index}",
            )
            exact(
                components["solver_energy_exchange_receipt_sha256"],
                solver_sha,
                f"ROUTE_SOLVER_ROTATION_RECEIPT_SHA_BINDING:{index}",
            )
            exact(
                sha256(core_canonical_bytes(partition)),
                partition_sha,
                f"ROUTE_SOLVER_ROTATION_PARTITION_SHA:{index}",
            )
        expected_motor_count = 0 if index == 1 else 8
        inputs = components["complete_energy_inputs_receipt"]
        verify_exact_paths(
            inputs,
            {
                "semantic_step": index,
                "no_actuation_requested": index == 1,
                "native_joint_motor_enabled_count": expected_motor_count,
                "expected_native_joint_motor_enabled_count": expected_motor_count,
                "actuator_mapping_id": ("" if index == 1 else actuator_mapping_id),
                "work_mapping_id": "" if index == 1 else work_mapping_id,
                "external_intervention_event_count": 0,
                "adapter_side_discrete_staging_event_count": 0,
                "actuator_configuration_partition_compatible": True,
                "passive_dissipation_partition_complete": True,
                "source_measurement": True,
                "mechanical_energy_residual_used_as_work_source": False,
            },
            f"ROUTE_SOLVER_INPUTS:{index}",
        )
        measured_application = components["application_receipt"]
        verify_exact_paths(
            measured_application,
            {
                "schema_version": (
                    "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_native_application_receipt_v1"
                ),
                "route_id": bindings["energy_route_id"],
                "semantic_step": index,
                "bootstrap_application": index == 1,
                "energy_mapping_profile_id": bindings["energy_mapping_profile_id"],
                "actuation_realization_id": bindings["actuation_realization_id"],
                "actuator_mapping_id": "" if index == 1 else actuator_mapping_id,
                "work_mapping_id": "" if index == 1 else work_mapping_id,
                "partition_rule_id": bindings["partition_rule_id"],
                "native_joint_motor_enabled_count": expected_motor_count,
                "native_contact_solver_coupled": True,
                "pre_solver_direct_body_impulse_write_count": 0,
                "body_impulse_write_count": 0,
                "native_motor_work_partitioned_from_whole_joint_exchange": True,
                "solver_coupled_partition_receipt_sha256": partition_sha,
                "source_measurement": True,
            },
            f"ROUTE_SOLVER_MEASURED_APPLICATION:{index}",
        )
        if index == 1:
            require(
                "application_mutation_semantics_id" not in measured_application,
                "ROUTE_SOLVER_BOOTSTRAP_MUTATION_SEMANTICS",
            )
        else:
            exact(
                measured_application["application_mutation_semantics_id"],
                bindings["application_mutation_semantics_id"],
                "ROUTE_SOLVER_ACTIVE_MUTATION_SEMANTICS",
            )
        partition_expected: dict[str, Any] = {
            "schema_version": (
                bindings["partition_contract_schema"]
                if rotation_aware
                else "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_partition_contract_v1"
            ),
            "ok": True,
            "partition_rule_id": bindings["partition_rule_id"],
            "expected_space_step_sequence": index,
            "motor_receipt_count": 8,
            "numerical_bound_kind": (
                "deterministic_ieee754_binary32_forward_error_bound"
            ),
            "numerical_term_count": (
                bindings["partition_numerical_term_count"] if rotation_aware else 13
            ),
            "joint_velocity_exchange_includes_native_motor_work": True,
            "native_motor_work_subtracted_exactly_once": True,
            "motor_work_also_counted_as_constraint_exchange": False,
            "constraint_exchange_partition_disjoint": True,
            "component_partition_complete": True,
            "source_measurement": True,
            "mechanical_energy_residual_used_as_work_source": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        if rotation_aware:
            partition_expected.update(
                {
                    "recovery_energy_ledger_profile_id": bindings[
                        "recovery_energy_ledger_profile_id"
                    ],
                    "rotation_integration_exchange_included_exactly_once": True,
                    "rotation_integration_partition_complete": True,
                }
            )
        verify_exact_paths(
            partition,
            partition_expected,
            f"ROUTE_SOLVER_PARTITION:{index}",
        )
        numeric_fields = [
            "step_actuator_work_j",
            "motor_absolute_work_sum_j",
            "raw_joint_velocity_constraint_exchange_j",
            "nonmotor_joint_constraint_exchange_j",
            "contact_velocity_constraint_exchange_j",
            "position_constraint_kinetic_exchange_j",
            "position_constraint_potential_exchange_j",
            "raw_step_signed_solver_exchange_j",
            "step_signed_constraint_exchange_j",
            "raw_component_reconstruction_delta_j",
            "partition_reconstruction_delta_j",
            "native_float32_epsilon",
            "numerical_consistency_bound_j",
        ]
        if rotation_aware:
            numeric_fields.append("rotation_integration_kinetic_exchange_j")
        require(
            all(_finite_number(partition[field]) for field in numeric_fields),
            f"ROUTE_SOLVER_PARTITION_NONFINITE:{index}",
        )
        bound = float(partition["numerical_consistency_bound_j"])
        require(bound >= 0.0, f"ROUTE_SOLVER_PARTITION_BOUND:{index}")
        raw_delta = (
            float(partition["raw_joint_velocity_constraint_exchange_j"])
            + float(partition["contact_velocity_constraint_exchange_j"])
            + (
                float(partition["rotation_integration_kinetic_exchange_j"])
                if rotation_aware
                else 0.0
            )
            + float(partition["position_constraint_kinetic_exchange_j"])
            + float(partition["position_constraint_potential_exchange_j"])
            - float(partition["raw_step_signed_solver_exchange_j"])
        )
        partition_delta = (
            float(partition["step_actuator_work_j"])
            + float(partition["step_signed_constraint_exchange_j"])
            - float(partition["raw_step_signed_solver_exchange_j"])
        )
        require(
            abs(float(partition["raw_component_reconstruction_delta_j"])) <= bound
            and abs(float(partition["partition_reconstruction_delta_j"])) <= bound
            and abs(raw_delta) <= bound
            and abs(partition_delta) <= bound,
            f"ROUTE_SOLVER_PARTITION_RECONSTRUCTION:{index}",
        )
        require(
            math.isclose(
                float(inputs["step_actuator_work_j"]),
                float(partition["step_actuator_work_j"]),
                rel_tol=0.0,
                abs_tol=bound,
            ),
            f"ROUTE_SOLVER_MOTOR_WORK_BINDING:{index}",
        )

    named = {
        "coupled_command_application_ok": bool(application["ok"]),
        "native_motor_application_identity_bound": True,
        "native_joint_motor_enabled_count": 8,
        "constraint_configuration_write_count": 8,
        "direct_body_impulse_write_count": 0,
        "solver_coupled_partition_receipt_count": 2,
        "all_solver_coupled_partitions_disjoint": True,
        "all_partition_reconstructions_within_declared_numerical_bound": True,
    }
    live = {
        "body_impulse_write_count": 0,
        "native_joint_motor_enabled_count": 8,
        "host_constraint_configuration_write_count": 8,
        "solver_coupled_partition_receipt_count": 2,
    }
    return named, live


def _verify_discrete_staging_complete_energy_profile(
    *,
    raw: dict[str, Any],
    application: dict[str, Any],
    actuator_mapping_id: str,
    work_mapping_id: str,
    bindings: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Extend the qualified R144 partition audit with R148 live staging."""

    required_bindings = {
        "recovery_controller_id",
        "energy_route_id",
        "energy_mapping_profile_id",
        "predecessor_energy_route_id",
        "predecessor_energy_mapping_profile_id",
        "application_schema",
        "actuation_realization_id",
        "application_mutation_semantics_id",
        "partition_rule_id",
        "source_receipt_schema",
        "source_component_receipts_schema",
        "boundary_capture_schema",
        "observer_schema",
        "accumulator_schema",
        "mapping_receipt_schema",
        "discrete_staging_rule_id",
        "live_boundary_transport_id",
        "native_world_route_id",
    }
    route_aware_binding_keys = {
        "application_provenance_profile_id",
        "complete_energy_authority_profile_id",
        "intermediate_application_schema",
        "predecessor_application_schema",
        "native_application_schema",
        "predecessor_native_application_schema",
        "native_source_trace_schema",
    }
    rotation_aware_binding_keys = {
        "native_bound_measurement_schema",
        "native_measurement_schema",
        "partition_contract_schema",
        "partition_numerical_term_count",
        "recovery_energy_ledger_profile_id",
        "rotation_aware_predecessor_source_component_receipts_schema",
        "rotation_aware_predecessor_source_receipt_schema",
        "solver_energy_consumer_contract_schema",
        "solver_energy_telemetry_schema",
        "solver_energy_telemetry_profile_id",
        "step_mapping_schema",
    }
    contiguous_transport_binding_keys = {
        "boundary_transport_design_id",
        "boundary_transport_initializer_schema",
        "boundary_transport_pair_schema",
        "boundary_transport_state_schema",
    }
    binding_keys = set(bindings)
    rotation_aware_application = binding_keys == (
        required_bindings | route_aware_binding_keys | rotation_aware_binding_keys
    )
    contiguous_transport_application = binding_keys == (
        required_bindings
        | route_aware_binding_keys
        | rotation_aware_binding_keys
        | contiguous_transport_binding_keys
    )
    route_aware_application = (
        binding_keys == required_bindings | route_aware_binding_keys
        or rotation_aware_application
        or contiguous_transport_application
    )
    rotation_aware_application = (
        rotation_aware_application or contiguous_transport_application
    )
    require(
        binding_keys == required_bindings or route_aware_application,
        "ROUTE_STAGING_PROFILE_BINDINGS",
    )

    # R148 preserves every R144 partition member and changes only the outer
    # component-receipt schema while adding independently measured staging.
    # Reuse the complete R144 audit after projecting that one declared wrapper
    # back to its exact predecessor identity.
    predecessor_raw = copy.deepcopy(raw)
    predecessor_application = application
    if route_aware_application:
        verify_exact_paths(
            application,
            {
                "schema_version": bindings["application_schema"],
                "energy_route_id": bindings["energy_route_id"],
                "energy_mapping_profile_id": bindings["energy_mapping_profile_id"],
                "predecessor_complete_energy_schema_version": bindings[
                    "predecessor_application_schema"
                ],
                "predecessor_route_aware_application_schema_version": bindings[
                    "intermediate_application_schema"
                ],
                "predecessor_complete_energy_route_id": bindings[
                    "predecessor_energy_route_id"
                ],
                "discrete_staging_complete_energy_profile_selected": True,
                "complete_energy_authority_profile_id": bindings[
                    "complete_energy_authority_profile_id"
                ],
                "application_provenance_profile_id": bindings[
                    "application_provenance_profile_id"
                ],
            },
            "ROUTE_STAGING_OUTER_APPLICATION",
        )
        predecessor_application = copy.deepcopy(application)
        predecessor_application["schema_version"] = bindings[
            "predecessor_application_schema"
        ]
        predecessor_application["energy_route_id"] = bindings[
            "predecessor_energy_route_id"
        ]
        predecessor_application["energy_mapping_profile_id"] = bindings[
            "predecessor_energy_mapping_profile_id"
        ]
        for key in (
            "predecessor_complete_energy_schema_version",
            "predecessor_route_aware_application_schema_version",
            "predecessor_complete_energy_route_id",
            "discrete_staging_complete_energy_profile_selected",
            "complete_energy_authority_profile_id",
            "application_provenance_profile_id",
        ):
            predecessor_application.pop(key, None)
    for step in (predecessor_raw["first_step"], predecessor_raw["second_step"]):
        measurement = step["native_route"]["measurement"]
        components = measurement["source_component_receipts"]
        exact(
            components["schema_version"],
            bindings["source_component_receipts_schema"],
            "ROUTE_STAGING_COMPONENT_SCHEMA",
        )
        if route_aware_application:
            measured_application = components["application_receipt"]
            verify_exact_paths(
                measured_application,
                {
                    "schema_version": bindings["native_application_schema"],
                    "route_id": bindings["energy_route_id"],
                    "energy_mapping_profile_id": bindings["energy_mapping_profile_id"],
                    "predecessor_complete_energy_route_id": bindings[
                        "predecessor_energy_route_id"
                    ],
                    "predecessor_complete_energy_mapping_profile_id": bindings[
                        "predecessor_energy_mapping_profile_id"
                    ],
                    "discrete_staging_complete_energy_profile_selected": True,
                    "complete_energy_authority_profile_id": bindings[
                        "complete_energy_authority_profile_id"
                    ],
                    "application_provenance_profile_id": bindings[
                        "application_provenance_profile_id"
                    ],
                },
                "ROUTE_STAGING_MEASURED_OUTER_APPLICATION",
            )
            source_trace = components["source_trace"]
            verify_exact_paths(
                source_trace,
                {
                    "schema_version": bindings["native_source_trace_schema"],
                    "energy_route_id": bindings["energy_route_id"],
                    "energy_mapping_profile_id": bindings["energy_mapping_profile_id"],
                    "predecessor_complete_energy_route_id": bindings[
                        "predecessor_energy_route_id"
                    ],
                    "predecessor_complete_energy_mapping_profile_id": bindings[
                        "predecessor_energy_mapping_profile_id"
                    ],
                    "complete_energy_authority_profile_id": bindings[
                        "complete_energy_authority_profile_id"
                    ],
                    "application_provenance_profile_id": bindings[
                        "application_provenance_profile_id"
                    ],
                },
                "ROUTE_STAGING_OUTER_SOURCE_TRACE",
            )
            measured_application["schema_version"] = bindings[
                "predecessor_native_application_schema"
            ]
            measured_application["route_id"] = bindings["predecessor_energy_route_id"]
            measured_application["energy_mapping_profile_id"] = bindings[
                "predecessor_energy_mapping_profile_id"
            ]
            for key in (
                "predecessor_complete_energy_route_id",
                "predecessor_complete_energy_mapping_profile_id",
                "discrete_staging_complete_energy_profile_selected",
                "complete_energy_authority_profile_id",
                "application_provenance_profile_id",
            ):
                measured_application.pop(key, None)
        if rotation_aware_application:
            mapping = step["native_route"]["bound"][
                "native_to_portable_staging_mapping"
            ]
            original_energy = mapping[
                "rotation_aware_predecessor_energy_source_receipt"
            ]
            original_components = mapping[
                "rotation_aware_predecessor_source_component_receipts"
            ]
            original_energy_sha = sha256(core_canonical_bytes(original_energy))
            original_components_sha = sha256(core_canonical_bytes(original_components))
            verify_exact_paths(
                original_energy,
                {
                    "schema_version": bindings[
                        "rotation_aware_predecessor_source_receipt_schema"
                    ],
                    "recovery_energy_ledger_profile_id": bindings[
                        "recovery_energy_ledger_profile_id"
                    ],
                    "rotation_integration_exchange_included_exactly_once": True,
                },
                "ROUTE_STAGING_ROTATION_ORIGINAL_ENERGY",
            )
            verify_exact_paths(
                original_components,
                {
                    "schema_version": bindings[
                        "rotation_aware_predecessor_source_component_receipts_schema"
                    ],
                    "recovery_energy_ledger_profile_id": bindings[
                        "recovery_energy_ledger_profile_id"
                    ],
                    "rotation_integration_exchange_included_exactly_once": True,
                },
                "ROUTE_STAGING_ROTATION_ORIGINAL_COMPONENTS",
            )
            exact(
                mapping["rotation_aware_predecessor_energy_source_receipt_sha256"],
                original_energy_sha,
                "ROUTE_STAGING_ROTATION_ORIGINAL_ENERGY_SHA",
            )
            exact(
                mapping["rotation_aware_predecessor_source_component_receipts_sha256"],
                original_components_sha,
                "ROUTE_STAGING_ROTATION_ORIGINAL_COMPONENTS_SHA",
            )
            projected_energy = copy.deepcopy(original_energy)
            projected_energy["schema_version"] = (
                "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_source_receipt_v1"
            )
            projected_components = copy.deepcopy(original_components)
            projected_components["schema_version"] = (
                "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_source_component_receipts_v1"
            )
            mapping_receipt = mapping["mapping_receipt"]
            exact(
                mapping_receipt["predecessor_energy_source_projection_sha256"],
                sha256(core_canonical_bytes(projected_energy)),
                "ROUTE_STAGING_ROTATION_PROJECTED_ENERGY_SHA",
            )
            exact(
                mapping_receipt["predecessor_source_component_projection_sha256"],
                sha256(core_canonical_bytes(projected_components)),
                "ROUTE_STAGING_ROTATION_PROJECTED_COMPONENTS_SHA",
            )
        components["schema_version"] = (
            "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_"
            "source_component_receipts_v1"
        )
    predecessor_invariants, predecessor_live = (
        _verify_solver_coupled_complete_energy_profile(
            raw=predecessor_raw,
            application=predecessor_application,
            actuator_mapping_id=actuator_mapping_id,
            work_mapping_id=work_mapping_id,
            bindings={
                "recovery_controller_id": bindings["recovery_controller_id"],
                "energy_route_id": bindings["predecessor_energy_route_id"],
                "application_schema": (
                    bindings["predecessor_application_schema"]
                    if route_aware_application
                    else bindings["application_schema"]
                ),
                "actuation_realization_id": bindings["actuation_realization_id"],
                "application_mutation_semantics_id": bindings[
                    "application_mutation_semantics_id"
                ],
                "energy_mapping_profile_id": bindings[
                    "predecessor_energy_mapping_profile_id"
                ],
                "partition_rule_id": bindings["partition_rule_id"],
                **(
                    {
                        "partition_contract_schema": bindings[
                            "partition_contract_schema"
                        ],
                        "partition_numerical_term_count": bindings[
                            "partition_numerical_term_count"
                        ],
                        "recovery_energy_ledger_profile_id": bindings[
                            "recovery_energy_ledger_profile_id"
                        ],
                        "solver_energy_consumer_contract_schema": bindings[
                            "solver_energy_consumer_contract_schema"
                        ],
                        "solver_energy_telemetry_schema": bindings[
                            "solver_energy_telemetry_schema"
                        ],
                        "solver_energy_telemetry_profile_id": bindings[
                            "solver_energy_telemetry_profile_id"
                        ],
                    }
                    if rotation_aware_application
                    else {}
                ),
            },
        )
    )

    previous_accumulator: dict[str, Any] = {
        "schema_version": bindings["accumulator_schema"],
        "sequence": 0,
        "event_count": 0,
        "cumulative_signed_discrete_staging_exchange_j": 0.0,
        "last_observer_receipt_sha256": None,
        "previous_accumulator_sha256": None,
        "source_measurement": True,
        "mechanical_energy_change_used_as_input": False,
        "energy_balance_residual_used_as_input": False,
        "acceptance_threshold_used_as_input": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    if contiguous_transport_application:
        initializer = raw["boundary_transport_initializer_receipt"]
        verify_exact_paths(
            initializer,
            {
                "schema_version": bindings["boundary_transport_initializer_schema"],
                "ok": True,
                "transport_design_id": bindings["boundary_transport_design_id"],
                "transport_profile_id": bindings["live_boundary_transport_id"],
                "initializer_boundary_sequence": 0,
                "state_revision": 0,
                "native_readback_count": 9,
                "physics_active_during_readback": False,
                "source_measurement": True,
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
                "physical_acceptance_authority": False,
                "release_authority": False,
            },
            "ROUTE_STAGING_CONTIGUOUS_INITIALIZER",
        )
        verify_exact_paths(
            raw,
            {
                "contiguous_boundary_transport_profile_selected": True,
                "contiguous_boundary_transport_design_id": bindings[
                    "boundary_transport_design_id"
                ],
                "contiguous_boundary_transport_profile_id": bindings[
                    "live_boundary_transport_id"
                ],
                "boundary_transport_state_schema_version": bindings[
                    "boundary_transport_state_schema"
                ],
                "boundary_transport_pair_schema_version": bindings[
                    "boundary_transport_pair_schema"
                ],
                "legacy_aliased_boundary_transport_selected": False,
                "boundary_transport_initializer_native_readback_count": 9,
                "boundary_transport_completed_boundary_count": 2,
                "boundary_transport_cache_advance_commit_count": 2,
                "boundary_transport_terminal_cached_sequence": 2,
                "boundary_transport_terminal_accepted_pair_count": 2,
                "boundary_transport_terminal_state_revision": 2,
            },
            "ROUTE_STAGING_CONTIGUOUS_RAW",
        )
    for index, step in enumerate((raw["first_step"], raw["second_step"]), start=1):
        native = step["native_route"]
        measurement = native["measurement"]
        capture = native["discrete_staging_boundary_capture"]
        observer = native["discrete_staging_observer_receipt"]
        accumulator = native["discrete_staging_accumulator_after"]
        mapping = native["bound"]["native_to_portable_staging_mapping"]
        components = measurement["source_component_receipts"]
        energy = measurement["energy_source_receipt"]
        mapping_receipt = components["discrete_staging_mapping_receipt"]

        native_expected: dict[str, Any] = {
            "ok": True,
            "solver_step_count": index,
            "native_runtime_observation_collection_executed": True,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        if rotation_aware_application:
            native_expected.update(
                {
                    "schema_version": bindings["native_bound_measurement_schema"],
                    "rotation_aware_energy_ledger_profile_selected": True,
                    "recovery_energy_ledger_profile_id": bindings[
                        "recovery_energy_ledger_profile_id"
                    ],
                }
            )
        if contiguous_transport_application:
            native_expected.update(
                {
                    "contiguous_boundary_transport_profile_selected": True,
                    "contiguous_boundary_transport_state_revision": index,
                    "contiguous_boundary_transport_cache_advance_committed": True,
                }
            )
        verify_exact_paths(
            native,
            native_expected,
            f"ROUTE_STAGING_NATIVE:{index}",
        )
        if rotation_aware_application:
            verify_exact_paths(
                measurement,
                {
                    "schema_version": bindings["native_measurement_schema"],
                    "recovery_energy_ledger_profile_id": bindings[
                        "recovery_energy_ledger_profile_id"
                    ],
                    "rotation_integration_exchange_included_exactly_once": True,
                },
                f"ROUTE_STAGING_ROTATION_MEASUREMENT:{index}",
            )
            verify_exact_paths(
                mapping,
                {
                    "schema_version": bindings["step_mapping_schema"],
                    "recovery_energy_ledger_profile_id": bindings[
                        "recovery_energy_ledger_profile_id"
                    ],
                    "rotation_integration_exchange_included_exactly_once": True,
                },
                f"ROUTE_STAGING_ROTATION_MAPPING:{index}",
            )
        capture_expected: dict[str, Any] = {
            "schema_version": bindings["boundary_capture_schema"],
            "ok": True,
            "semantic_step": index,
            "previous_sequence": index - 1,
            "body_count": 9,
            "source_measurement": True,
        }
        if contiguous_transport_application:
            capture_expected.update(
                {
                    "pre_boundary_source_kind": (
                        "inactive_physics_initializer_readback_v1"
                        if index == 1
                        else "completed_step_direct_state_callback_v1"
                    ),
                    "post_boundary_source_kind": (
                        "completed_step_direct_state_callback_v1"
                    ),
                    "transport_design_id": bindings[
                        "boundary_transport_design_id"
                    ],
                    "transport_profile_id": bindings["live_boundary_transport_id"],
                    "transport_state_revision_before": index - 1,
                    "transport_state_revision_after": index,
                    "cache_advance_count_pending_commit": 1,
                    "mechanical_energy_change_used_as_input": False,
                    "energy_balance_residual_used_as_input": False,
                    "acceptance_threshold_used_as_input": False,
                    "controller_or_behavior_result_used_as_input": False,
                }
            )
            require(
                "transport_state_after" not in capture,
                f"ROUTE_STAGING_PENDING_STATE_RETAINED:{index}",
            )
        else:
            capture_expected.update(
                {
                    "pre_boundary_source_kind": (
                        "physics_direct_body_state_callback_before_native_solve"
                    ),
                    "post_boundary_source_kind": (
                        "synchronized_rigid_body_property_readback_after_native_solve"
                    ),
                    "force_path_readback_complete": True,
                }
            )
        verify_exact_paths(
            capture,
            capture_expected,
            f"ROUTE_STAGING_CAPTURE:{index}",
        )
        boundaries = capture["ordered_body_boundaries"]
        readbacks = (
            []
            if contiguous_transport_application
            else capture["ordered_post_solver_readbacks"]
        )
        exact(len(boundaries), 9, f"ROUTE_STAGING_BOUNDARY_BODIES:{index}")
        if not contiguous_transport_application:
            exact(len(readbacks), 9, f"ROUTE_STAGING_READBACK_BODIES:{index}")
        exact(
            [row["body_id"] for row in boundaries],
            capture["ordered_body_ids"],
            f"ROUTE_STAGING_BODY_ORDER:{index}",
        )
        for body_index, boundary in enumerate(boundaries):
            boundary_expected: dict[str, Any] = {
                "body_index": body_index,
                "pre_boundary_sequence": index - 1,
                "post_boundary_sequence": index,
                "pre_source_measurement": True,
                "post_source_measurement": True,
            }
            if not contiguous_transport_application:
                boundary_expected["pre_callback_sequence"] = index
            verify_exact_paths(
                boundary,
                boundary_expected,
                f"ROUTE_STAGING_BOUNDARY:{index}:{body_index}",
            )
            if contiguous_transport_application:
                exact(
                    boundary["pre_source_event_id"],
                    capture["pre_source_event_id"],
                    f"ROUTE_STAGING_PRE_EVENT:{index}:{body_index}",
                )
                exact(
                    boundary["post_source_event_id"],
                    capture["post_source_event_id"],
                    f"ROUTE_STAGING_POST_EVENT:{index}:{body_index}",
                )
                require(
                    _finite_number(boundary["mass_kg"])
                    and float(boundary["mass_kg"]) > 0.0
                    and _finite_number(boundary["solver_step_s"])
                    and float(boundary["solver_step_s"]) > 0.0,
                    f"ROUTE_STAGING_CONTIGUOUS_NUMERIC:{index}:{body_index}",
                )
                continue
            readback = readbacks[body_index]
            verify_exact_paths(
                readback,
                {
                    "body_id": boundary["body_id"],
                    "boundary_sequence": index,
                    "body_dynamic": True,
                    "translation_dofs_unlocked": True,
                    "gravity_scale_one": True,
                    "constant_force_zero": True,
                    "constant_torque_zero": True,
                    "linear_damping_zero": True,
                    "angular_damping_zero": True,
                    "custom_integrator_disabled": True,
                    "sleeping_disabled": True,
                    "continuous_collision_detection_disabled": True,
                    "source_measurement": True,
                },
                f"ROUTE_STAGING_READBACK:{index}:{body_index}",
            )

        verify_exact_paths(
            observer,
            {
                "schema_version": bindings["observer_schema"],
                "ok": True,
                "sequence": index,
                "previous_sequence": index - 1,
                "body_count": 9,
                "rule_id": bindings["discrete_staging_rule_id"],
                "source_measurement": True,
                "mechanical_energy_change_used_as_input": False,
                "energy_balance_residual_used_as_input": False,
                "acceptance_threshold_used_as_input": False,
                "constraint_exchange_used_as_staging_input": False,
                "controller_or_behavior_result_used_as_input": False,
            },
            f"ROUTE_STAGING_OBSERVER:{index}",
        )
        verify_exact_paths(
            energy,
            {
                "schema_version": bindings["source_receipt_schema"],
                "semantic_step": index,
                "source_route_id": bindings["energy_route_id"],
                "energy_mapping_profile_id": bindings["energy_mapping_profile_id"],
                "discrete_staging_rule_id": bindings["discrete_staging_rule_id"],
                "adapter_side_discrete_staging_event_count": index,
                "source_measurement": True,
            },
            f"ROUTE_STAGING_ENERGY:{index}",
        )
        verify_exact_paths(
            components,
            {
                "schema_version": bindings["source_component_receipts_schema"],
                "semantic_step": index,
                "source_route_id": bindings["energy_route_id"],
                "energy_mapping_profile_id": bindings["energy_mapping_profile_id"],
                "source_measurement": True,
            },
            f"ROUTE_STAGING_COMPONENTS:{index}",
        )
        if rotation_aware_application:
            verify_exact_paths(
                energy,
                {
                    "recovery_energy_ledger_profile_id": bindings[
                        "recovery_energy_ledger_profile_id"
                    ],
                    "rotation_integration_exchange_included_exactly_once": True,
                },
                f"ROUTE_STAGING_ROTATION_ENERGY:{index}",
            )
            verify_exact_paths(
                components,
                {
                    "recovery_energy_ledger_profile_id": bindings[
                        "recovery_energy_ledger_profile_id"
                    ],
                    "rotation_integration_exchange_included_exactly_once": True,
                },
                f"ROUTE_STAGING_ROTATION_COMPONENTS:{index}",
            )
        verify_exact_paths(
            accumulator,
            {
                "schema_version": bindings["accumulator_schema"],
                "sequence": index,
                "event_count": index,
                "source_measurement": True,
            },
            f"ROUTE_STAGING_ACCUMULATOR:{index}",
        )
        exact(
            components["discrete_staging_accumulator_before"],
            previous_accumulator,
            f"ROUTE_STAGING_ACCUMULATOR_CHAIN:{index}",
        )
        exact(
            float(accumulator["cumulative_signed_discrete_staging_exchange_j"]),
            float(previous_accumulator["cumulative_signed_discrete_staging_exchange_j"])
            + float(observer["signed_discrete_staging_exchange_j"]),
            f"ROUTE_STAGING_ACCUMULATOR_SUM:{index}",
        )
        verify_exact_paths(
            mapping_receipt,
            {
                "schema_version": bindings["mapping_receipt_schema"],
                "route_id": bindings["energy_route_id"],
                "mapping_profile_id": bindings["energy_mapping_profile_id"],
                "semantic_step": index,
                "adapter_side_discrete_staging_event_count": index,
                "source_measurement": True,
            },
            f"ROUTE_STAGING_MAPPING:{index}",
        )
        exact(
            measurement["discrete_staging_boundary_capture"],
            capture,
            f"ROUTE_STAGING_CAPTURE_BINDING:{index}",
        )
        exact(
            measurement["discrete_staging_observer_receipt"],
            observer,
            f"ROUTE_STAGING_OBSERVER_BINDING:{index}",
        )
        exact(
            components["discrete_staging_observer_receipt"],
            observer,
            f"ROUTE_STAGING_COMPONENT_OBSERVER:{index}",
        )
        exact(
            components["discrete_staging_accumulator_after"],
            accumulator,
            f"ROUTE_STAGING_COMPONENT_ACCUMULATOR:{index}",
        )
        exact(
            mapping["accumulator_after"],
            accumulator,
            f"ROUTE_STAGING_MAPPING_ACCUMULATOR:{index}",
        )
        previous_accumulator = accumulator

    named = {
        **predecessor_invariants,
        "live_boundary_transport_identity_bound": bool(
            bindings["live_boundary_transport_id"]
        ),
        "discrete_staging_observer_receipt_count": 2,
        "discrete_staging_boundary_capture_count": 2,
        "discrete_staging_accumulator_event_count": 2,
        "discrete_staging_accumulator_chain_exact": True,
        "energy_residual_used_as_staging_input": False,
    }
    if contiguous_transport_application:
        named["all_contiguous_boundary_source_measurements_complete"] = True
    else:
        named["all_force_path_readbacks_complete"] = True
    if rotation_aware_application:
        named["rotation_aware_energy_ledger_profile_selected"] = True
        named["rotation_integration_exchange_included_exactly_once"] = True
    if contiguous_transport_application:
        named["contiguous_boundary_transport_profile_selected"] = True
        named["contiguous_boundary_transport_initializer_exact"] = True
        named["contiguous_boundary_transport_cache_advance_count"] = 2
        named["contiguous_boundary_transport_terminal_state_revision"] = 2
    live = {
        **predecessor_live,
        "discrete_staging_observer_receipt_count": 2,
        "discrete_staging_boundary_capture_count": 2,
        "adapter_side_discrete_staging_event_count": 2,
        "cumulative_signed_discrete_staging_exchange_j": raw[
            "cumulative_signed_discrete_staging_exchange_j"
        ],
    }
    if rotation_aware_application:
        live["rotation_aware_energy_ledger_profile_selected"] = True
        live["recovery_energy_ledger_profile_id"] = bindings[
            "recovery_energy_ledger_profile_id"
        ]
    if contiguous_transport_application:
        live["contiguous_boundary_transport_profile_selected"] = True
        live["boundary_transport_initializer_native_readback_count"] = 9
        live["boundary_transport_completed_boundary_count"] = 2
        live["boundary_transport_cache_advance_commit_count"] = 2
    return named, live


def validate_closure(
    *,
    root: Path,
    closure_relative_path: str,
    closure_schema: str,
    gate_id: str,
    closure_status: str,
    invocation_source_commit: str,
    schemas: dict[str, str],
    actuator_mode: str,
    actuator_mapping_id: str,
    work_mapping_id: str,
    projection_key: str,
    projection_schema: str,
    qualified_source_commit: str,
    qualification_closure_relative_path: str,
    qualified_physical_path_count: int,
    live_prefix: str,
    next_gate_id: str,
    next_live_prefix: str,
    route_realization_profile: str = FORCE_BODY_IMPULSE_PROFILE,
    profile_bindings: dict[str, Any] | None = None,
) -> dict[str, Any]:
    require(
        route_realization_profile
        in {
            FORCE_BODY_IMPULSE_PROFILE,
            SOLVER_COUPLED_COMPLETE_ENERGY_PROFILE,
            DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE,
            ROTATION_AWARE_DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE,
            CONTIGUOUS_ROTATION_AWARE_DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE,
        },
        "ROUTE_REALIZATION_PROFILE",
    )
    bindings = dict(profile_bindings or {})
    closure_path = root / closure_relative_path
    closure_raw = closure_path.read_bytes()
    closure = load(closure_path)
    verify_exact_paths(
        closure,
        {
            "schema_version": closure_schema,
            "gate_id": gate_id,
            "closure_status": closure_status,
            "question_class": "development",
            "physical_question_declared": True,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "source.commit": invocation_source_commit,
            "authorization_dependency.qualification_source_freeze_commit": (
                qualified_source_commit
            ),
            "authorization_dependency.qualification_closure_path": (
                qualification_closure_relative_path
            ),
            "authorization_dependency.qualified_physical_path_count": (
                qualified_physical_path_count
            ),
            "decision.ghost_attempt_consumed_for_exact_source": True,
            "decision.integration_ghost_passed": True,
            "decision.in_run_physical_invariants_passed": True,
            "decision.native_engine_health_passed": True,
            "decision.same_identity_rerun_permitted": False,
            "decision.physical_execution_authorized": False,
            "claim_boundary.physical_attempt_consumed": True,
            "claim_boundary.valid_complete_route_result": True,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
        },
        "ROUTE_PHYSICAL_CLOSURE",
    )

    source = closure["source"]
    verify_exact_paths(
        source,
        {
            "branch": "main",
            "remote": "https://github.com/Slagathore/sporespore.git",
            "upstream_equal_at_invocation": True,
            "live_remote_equal_at_invocation": True,
            "worktree_clean_at_invocation": True,
            "qualified_physical_source_freeze_commit": qualified_source_commit,
            "qualified_physical_path_count": qualified_physical_path_count,
        },
        "INVALID_ROUTE_SOURCE",
    )
    verify_retained_commit(root, invocation_source_commit, str(source["parent_commit"]))
    require(
        git(root, "show", "-s", "--format=%T", invocation_source_commit)
        == source["tree"],
        "ROUTE_PHYSICAL_SOURCE_TREE",
    )
    require(
        git(root, "show", "-s", "--format=%s", invocation_source_commit)
        == source["subject"],
        "ROUTE_PHYSICAL_SOURCE_SUBJECT",
    )
    for binding in source["bindings"]:
        verify_source_binding(root, invocation_source_commit, binding)

    authorization_raw = source_bytes(
        root, invocation_source_commit, qualification_closure_relative_path
    )
    verify_exact_paths(
        closure["authorization_dependency"],
        {
            "qualification_closure_byte_length": len(authorization_raw),
            "qualification_closure_raw_sha256": sha256(authorization_raw),
            "authorization_publication_commit": invocation_source_commit,
            "complete_zero_world_gate_satisfied": True,
            "qualified_physical_source_drift_check_passed": True,
            "clean_pushed_remote_equality_passed": True,
            "same_identity_requalification_permitted": False,
        },
        "ROUTE_PHYSICAL_AUTHORIZATION",
    )

    values = verify_supervised_bounded_ghost_attempt(
        physical=closure["physical_attempt"],
        gate_id=gate_id,
        source_commit=invocation_source_commit,
        status="valid_complete_integration_ghost",
        schemas=schemas,
    )
    raw = values["raw"]
    verify_two_step_native_portable_route(
        raw, phase="establish_distal_support", joint_count=8
    )
    raw_expected: dict[str, Any] = {
        "actuator_mode": actuator_mode,
        "actuator_mapping_id": actuator_mapping_id,
        "work_mapping_id": work_mapping_id,
        "model_construction_attempt_count": 1,
        "model_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 2,
        "portable_collection_count": 2,
        "portable_control_plan_count": 2,
        "portable_command_application_count": 1,
        "validated_command_count": 8,
        "host_readback_count": 8,
        "in_run_physical_invariant_step_count": 2,
        "all_in_run_physical_invariants_passed": True,
        "behavior_evaluator_invocation_count": 0,
        "threshold_count": 0,
        "margin_count": 0,
        "held_out_cell_access_count": 0,
        "prone_to_standing_claimed": False,
    }
    if route_realization_profile == FORCE_BODY_IMPULSE_PROFILE:
        raw_expected.update(
            {
                "host_write_count": 9,
                "body_impulse_write_count": 9,
                "native_angular_velocity_total_readback_count": 18,
                "population_actuator_count": 8,
                "population_body_count": 9,
                "all_joint_target_errors_nonincreasing": True,
                "joint_target_crossing_count": 0,
            }
        )
    else:
        raw_expected.update(
            {
                "recovery_controller_id": bindings.get("recovery_controller_id", ""),
                "energy_route_id": bindings.get("energy_route_id", ""),
                "recovery_energy_route_id": bindings.get("energy_route_id", ""),
                "complete_energy_profile_selected": True,
                "solver_coupled_complete_energy_profile_selected": True,
                "position_solver_entry_receipt_count": 2,
                "all_complete_energy_position_solver_receipts_passed": True,
                "actuation_realization_id": bindings.get(
                    "actuation_realization_id", ""
                ),
                "partition_rule_id": bindings.get("partition_rule_id", ""),
                "host_write_count": 8,
                "body_impulse_write_count": 0,
                "motor_enabled_count": 8,
                "native_joint_motor_enabled_count": 8,
                "host_constraint_configuration_write_count": 8,
                "active_constraint_motor_configuration_modified": True,
                "pre_solver_direct_body_impulse_write_count": 0,
            }
        )
        if route_realization_profile in {
            DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE,
            ROTATION_AWARE_DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE,
            CONTIGUOUS_ROTATION_AWARE_DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE,
        }:
            raw_expected.update(
                {
                    "discrete_staging_complete_energy_profile_selected": True,
                    "native_world_route_id": bindings.get("native_world_route_id", ""),
                    "adapter_side_discrete_staging_event_count": 2,
                    "discrete_staging_observer_receipt_count": 2,
                    "discrete_staging_boundary_capture_count": 2,
                }
            )
        if (
            route_realization_profile
            in {
                ROTATION_AWARE_DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE,
                CONTIGUOUS_ROTATION_AWARE_DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE,
            }
        ):
            raw_expected.update(
                {
                    "rotation_aware_energy_ledger_profile_selected": True,
                    "recovery_energy_ledger_profile_id": bindings.get(
                        "recovery_energy_ledger_profile_id", ""
                    ),
                }
            )
        if (
            route_realization_profile
            == CONTIGUOUS_ROTATION_AWARE_DISCRETE_STAGING_COMPLETE_ENERGY_PROFILE
        ):
            raw_expected.update(
                {
                    "contiguous_boundary_transport_profile_selected": True,
                    "contiguous_boundary_transport_design_id": bindings.get(
                        "boundary_transport_design_id", ""
                    ),
                    "contiguous_boundary_transport_profile_id": bindings.get(
                        "live_boundary_transport_id", ""
                    ),
                    "boundary_transport_state_schema_version": bindings.get(
                        "boundary_transport_state_schema", ""
                    ),
                    "boundary_transport_pair_schema_version": bindings.get(
                        "boundary_transport_pair_schema", ""
                    ),
                    "legacy_aliased_boundary_transport_selected": False,
                    "boundary_transport_initializer_native_readback_count": 9,
                    "boundary_transport_completed_boundary_count": 2,
                    "boundary_transport_cache_advance_commit_count": 2,
                    "boundary_transport_terminal_cached_sequence": 2,
                    "boundary_transport_terminal_accepted_pair_count": 2,
                    "boundary_transport_terminal_state_revision": 2,
                }
            )
    verify_exact_paths(raw, raw_expected, "ROUTE_PHYSICAL_RAW")

    application = raw["first_step"]["application_intent"]
    if route_realization_profile == FORCE_BODY_IMPULSE_PROFILE:
        profile_invariants, live_observations = _verify_force_body_impulse_profile(
            application=application,
            actuator_mapping_id=actuator_mapping_id,
            work_mapping_id=work_mapping_id,
            projection_key=projection_key,
            projection_schema=projection_schema,
        )
    elif route_realization_profile == SOLVER_COUPLED_COMPLETE_ENERGY_PROFILE:
        profile_invariants, live_observations = (
            _verify_solver_coupled_complete_energy_profile(
                raw=raw,
                application=application,
                actuator_mapping_id=actuator_mapping_id,
                work_mapping_id=work_mapping_id,
                bindings=bindings,
            )
        )
    else:
        profile_invariants, live_observations = (
            _verify_discrete_staging_complete_energy_profile(
                raw=raw,
                application=application,
                actuator_mapping_id=actuator_mapping_id,
                work_mapping_id=work_mapping_id,
                bindings=bindings,
            )
        )

    invariant_projection = complete_in_run_physical_invariant_projection(raw)
    for key, value in invariant_projection.items():
        require(
            closure["in_run_physical_invariants"].get(key) == value,
            f"ROUTE_PHYSICAL_INVARIANT:{key}",
        )
    named_invariants = {
        "in_run_physical_invariant_step_count": 2,
        "all_in_run_physical_invariants_passed": True,
        "initializer_exact_readback_passed": bool(raw["initializer_readback"]["ok"]),
        "native_step_results_ok": bool(
            raw["first_step"]["native_route"]["ok"]
            and raw["second_step"]["native_route"]["ok"]
        ),
        "portable_step_results_ok": bool(
            raw["first_step"]["portable_route"]["ok"]
            and raw["second_step"]["portable_route"]["ok"]
        ),
        "termination_protocol_valid": True,
        "native_engine_health_passed": True,
        **profile_invariants,
    }
    verify_exact_paths(
        closure["in_run_physical_invariants"],
        named_invariants,
        "ROUTE_NAMED_INVARIANTS",
    )
    require(
        invariant_projection["all_raw_numeric_scalars_finite"]
        and invariant_projection["all_validity_fields_true"]
        and invariant_projection["all_source_measurement_flags_true"]
        and invariant_projection["external_intervention_total"] == 0.0,
        "ROUTE_COMPLETE_INVARIANT_POPULATION",
    )
    require(
        values["terminal"]["worker"]["engine_health"]["passed"],
        "ROUTE_NATIVE_ENGINE_HEALTH",
    )

    live_projection = {
        "next_gate_id": next_gate_id,
        f"{live_prefix}_source_status": closure_status,
        f"{live_prefix}_physical_attempt_consumed": True,
        f"{live_prefix}_official_physical_attempt_count": 1,
        f"{live_prefix}_physical_attempt_disposition": (
            "valid_complete_integration_ghost_positive"
        ),
        f"{live_prefix}_route_ghost_closure_path": closure_relative_path,
        f"{live_prefix}_invocation_source_commit": invocation_source_commit,
        f"{live_prefix}_observed_model_construction_count": 1,
        f"{live_prefix}_observed_world_attempt_count": 1,
        f"{live_prefix}_observed_world_build_count": 1,
        f"{live_prefix}_observed_solver_step_count": 2,
        f"{live_prefix}_integration_ghost_passed": True,
        f"{live_prefix}_in_run_physical_invariants_passed": True,
        f"{live_prefix}_native_engine_health_passed": True,
        **{f"{live_prefix}_{key}": value for key, value in live_observations.items()},
        f"{live_prefix}_physical_execution_authorized": False,
        f"{live_prefix}_same_identity_rerun_permitted": False,
        f"{next_live_prefix}_distinct_behavior_successor_required": True,
        f"{next_live_prefix}_question_class_declared": False,
        f"{next_live_prefix}_physical_execution_authorized": False,
        f"physical_execution_blocked_pending_{next_live_prefix}_declaration": True,
        f"physical_execution_blocked_until_{next_live_prefix}_zero_world_qualification": True,
    }
    require(
        closure["live_authority_projection"] == live_projection,
        "ROUTE_LIVE_PROJECTION",
    )
    live_expected = {
        **live_projection,
        f"{live_prefix}_route_ghost_closure_raw_sha256": sha256(closure_raw),
        f"{live_prefix}_route_ghost_closure_byte_length": len(closure_raw),
    }
    verify_legacy_live_authority_projection(
        root,
        tuple(str(path) for path in closure["live_authority_paths"]),
        record_key=f"{live_prefix}_contract_path",
        expected=live_expected,
        prefix=f"LIVE_{live_prefix.upper()}_PHYSICAL",
    )
    require((root / str(closure["closure_audit_path"])).is_file(), "ROUTE_AUDIT_PATH")
    return closure


def run_cli(*, pass_marker: str, failure_marker: str, **kwargs: Any) -> int:
    try:
        closure = validate_closure(**kwargs)
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": closure["gate_id"],
                    "ok": True,
                    "status": closure["closure_status"],
                    "attempt_id": closure["physical_attempt"]["attempt_id"],
                    "model_construction_count": 1,
                    "world_build_count": 1,
                    "solver_step_count": 2,
                    "same_identity_rerun_permitted": False,
                },
                sort_keys=True,
            ),
        )
        return 0
    except (
        ClosureAuditError,
        AssertionError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(f"{failure_marker}:{error}", file=sys.stderr)
        return 1


def validate_invalid_route_closure(
    *,
    root: Path,
    closure_relative_path: str,
    closure_schema: str,
    gate_id: str,
    closure_status: str,
    invocation_source_commit: str,
    schemas: dict[str, str],
    actuator_mode: str,
    recovery_controller_id: str,
    recovery_energy_route_id: str,
    failure_code: str,
    detail_failure_code: str,
    qualified_source_commit: str,
    qualification_closure_relative_path: str,
    contract_relative_path: str,
    qualified_physical_path_count: int,
    live_prefix: str,
    next_gate_id: str,
    next_live_prefix: str,
    disposition: str,
    root_cause_refusal_reason: str = "",
    observed_model_construction_attempt_count: int = 0,
    observed_model_construction_count: int = 0,
    observed_world_attempt_count: int = 0,
    observed_world_build_count: int = 0,
    observed_solver_step_count: int = 0,
    observed_physical_question_opened: bool = False,
    observed_physics_state_modified: bool = False,
) -> dict[str, Any]:
    """Audit a consumed incomplete route failure with the shared ghost mechanics."""

    closure_path = root / closure_relative_path
    closure_raw = closure_path.read_bytes()
    closure = load(closure_path)
    verify_exact_paths(
        closure,
        {
            "schema_version": closure_schema,
            "gate_id": gate_id,
            "closure_status": closure_status,
            "question_class": "development",
            "source.commit": invocation_source_commit,
            "authorization_dependency.qualification_source_freeze_commit": (
                qualified_source_commit
            ),
            "authorization_dependency.qualification_closure_path": (
                qualification_closure_relative_path
            ),
            "authorization_dependency.qualified_physical_path_count": (
                qualified_physical_path_count
            ),
            "decision.ghost_attempt_consumed_for_exact_source": True,
            "decision.invalid_incomplete_result_retained": True,
            "decision.integration_ghost_passed": False,
            "decision.infrastructure_invalid_result_retained": True,
            "decision.physics_state_modified": observed_physics_state_modified,
            "decision.physical_question_opened": observed_physical_question_opened,
            "decision.same_identity_rerun_permitted": False,
            "decision.physical_execution_authorized": False,
            "claim_boundary.physical_attempt_consumed": True,
            "claim_boundary.valid_complete_route_result": False,
            "claim_boundary.physical_question_opened": (
                observed_physical_question_opened
            ),
            "claim_boundary.model_construction_attempted": (
                observed_model_construction_attempt_count > 0
            ),
            "claim_boundary.model_construction_completed": (
                observed_model_construction_count > 0
            ),
            "claim_boundary.world_attempted": observed_world_attempt_count > 0,
            "claim_boundary.world_build_completed": observed_world_build_count > 0,
            "claim_boundary.solver_step_executed": observed_solver_step_count > 0,
            "claim_boundary.physics_state_modified": observed_physics_state_modified,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
        },
        "INVALID_ROUTE_PHYSICAL_CLOSURE",
    )

    source = closure["source"]
    verify_retained_commit(root, invocation_source_commit, str(source["parent_commit"]))
    require(
        git(root, "show", "-s", "--format=%T", invocation_source_commit)
        == source["tree"],
        "INVALID_ROUTE_SOURCE_TREE",
    )
    require(
        git(root, "show", "-s", "--format=%s", invocation_source_commit)
        == source["subject"],
        "INVALID_ROUTE_SOURCE_SUBJECT",
    )
    for binding in source["bindings"]:
        verify_source_binding(root, invocation_source_commit, binding)

    authorization_raw = source_bytes(
        root, invocation_source_commit, qualification_closure_relative_path
    )
    verify_exact_paths(
        closure["authorization_dependency"],
        {
            "qualification_closure_byte_length": len(authorization_raw),
            "qualification_closure_raw_sha256": sha256(authorization_raw),
            "authorization_publication_commit": invocation_source_commit,
            "complete_zero_world_gate_satisfied": True,
            "qualified_physical_source_drift_check_passed": True,
            "clean_pushed_remote_equality_passed": True,
            "same_identity_requalification_permitted": False,
        },
        "INVALID_ROUTE_PHYSICAL_AUTHORIZATION",
    )
    contract = json.loads(
        source_bytes(root, qualified_source_commit, contract_relative_path)
    )
    qualified_paths = tuple(str(path) for path in contract["qualified_physical_paths"])
    exact(
        len(qualified_paths),
        qualified_physical_path_count,
        "INVALID_ROUTE_QUALIFIED_PATH_COUNT",
    )
    require(
        subprocess.run(
            [
                "git",
                "diff",
                "--quiet",
                qualified_source_commit,
                invocation_source_commit,
                "--",
                *qualified_paths,
            ],
            cwd=root,
            check=False,
        ).returncode
        == 0,
        "INVALID_ROUTE_QUALIFIED_SOURCE_DRIFT",
    )

    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id=gate_id,
        source_commit=invocation_source_commit,
        status="invalid_or_incomplete_integration_ghost",
        schemas=schemas,
    )
    raw = values["raw"]
    terminal = values["terminal"]
    verify_exact_paths(
        physical,
        {
            "attempt_count_for_exact_source_and_gate": 1,
            "status": "invalid_or_incomplete_integration_ghost",
            "worker_semantic_exit_code": 1,
            "worker_host_exit_code": -1,
            "worker_timed_out": False,
            "termination_protocol_valid": True,
            "raw_marker_count": 1,
            "raw_binding_valid": True,
            "native_engine_health_passed": True,
            "integration_ghost_passed": False,
            "maximum_model_construction_attempt_count": 1,
            "maximum_model_construction_count": 1,
            "maximum_world_attempt_count": 1,
            "maximum_world_build_count": 1,
            "maximum_solver_step_count": 2,
            "model_construction_attempt_count": (
                observed_model_construction_attempt_count
            ),
            "model_construction_count": observed_model_construction_count,
            "world_attempt_count": observed_world_attempt_count,
            "world_build_count": observed_world_build_count,
            "solver_step_count": observed_solver_step_count,
            "physical_question_opened": observed_physical_question_opened,
            "physics_state_modified": observed_physics_state_modified,
        },
        "INVALID_ROUTE_PHYSICAL_ATTEMPT",
    )
    raw_expected = {
        "ok": False,
        "status": "invalid_or_incomplete_integration_ghost",
        "failure_code": failure_code,
        "detail.failure_code": detail_failure_code,
        "actuator_mode": actuator_mode,
        "recovery_controller_id": recovery_controller_id,
        "recovery_energy_route_id": recovery_energy_route_id,
        "complete_energy_profile_selected": True,
        "model_construction_attempt_count": (observed_model_construction_attempt_count),
        "model_construction_count": observed_model_construction_count,
        "world_attempt_count": observed_world_attempt_count,
        "world_build_count": observed_world_build_count,
        "solver_step_count": observed_solver_step_count,
        "physics_state_modified": observed_physics_state_modified,
        "physical_question_opened": observed_physical_question_opened,
        "behavior_evaluator_invocation_count": 0,
        "threshold_count": 0,
        "margin_count": 0,
        "held_out_cell_access_count": 0,
        "prone_to_standing_claimed": False,
    }
    if root_cause_refusal_reason:
        raw_expected["detail.detail.refusal_reason"] = root_cause_refusal_reason
    verify_exact_paths(
        raw,
        raw_expected,
        "INVALID_ROUTE_RAW",
    )
    verify_exact_paths(
        terminal,
        {
            "worker.engine_health.passed": True,
            "worker.engine_health.stderr_raw_byte_length": 0,
            "worker.engine_health.fatal_diagnostic_line_count": 0,
            "worker.termination_protocol_valid": True,
            "worker.raw_binding_valid": True,
            "worker.raw_marker_count": 1,
            "integration_ghost_passed": False,
        },
        "INVALID_ROUTE_TERMINAL",
    )
    observed_failure_expected = {
        "failure_code": failure_code,
        "detail_failure_code": detail_failure_code,
        "model_construction_attempt_count": (observed_model_construction_attempt_count),
        "model_construction_count": observed_model_construction_count,
        "world_attempt_count": observed_world_attempt_count,
        "world_build_count": observed_world_build_count,
        "solver_step_count": observed_solver_step_count,
        "physical_question_opened": observed_physical_question_opened,
        "physics_state_modified": observed_physics_state_modified,
        "native_engine_health_passed": True,
    }
    if root_cause_refusal_reason:
        observed_failure_expected["root_cause_refusal_reason"] = (
            root_cause_refusal_reason
        )
    verify_exact_paths(
        closure["observed_failure"],
        observed_failure_expected,
        "INVALID_ROUTE_OBSERVED_FAILURE",
    )

    live_projection = {
        "next_gate_id": next_gate_id,
        f"{live_prefix}_source_status": closure_status,
        f"{live_prefix}_physical_attempt_consumed": True,
        f"{live_prefix}_official_physical_attempt_count": 1,
        f"{live_prefix}_physical_attempt_disposition": disposition,
        f"{live_prefix}_invocation_source_commit": invocation_source_commit,
        f"{live_prefix}_observed_model_construction_count": (
            observed_model_construction_count
        ),
        f"{live_prefix}_observed_world_attempt_count": observed_world_attempt_count,
        f"{live_prefix}_observed_world_build_count": observed_world_build_count,
        f"{live_prefix}_observed_solver_step_count": observed_solver_step_count,
        f"{live_prefix}_failure_code": failure_code,
        f"{live_prefix}_detail_failure_code": detail_failure_code,
        f"{live_prefix}_integration_ghost_passed": False,
        f"{live_prefix}_native_engine_health_passed": True,
        f"{live_prefix}_physical_execution_authorized": False,
        f"{live_prefix}_same_identity_rerun_permitted": False,
        f"{next_live_prefix}_distinct_route_successor_required": True,
        f"{next_live_prefix}_question_class_declared": False,
        f"{next_live_prefix}_physical_execution_authorized": False,
        f"physical_execution_blocked_pending_{next_live_prefix}_declaration": True,
        f"physical_execution_blocked_until_{next_live_prefix}_zero_world_qualification": True,
    }
    exact(
        closure["live_authority_projection"],
        live_projection,
        "INVALID_ROUTE_LIVE_PROJECTION",
    )
    live_expected = {
        **live_projection,
        f"{live_prefix}_physical_closure_path": closure_relative_path,
        f"{live_prefix}_physical_closure_raw_sha256": sha256(closure_raw),
        f"{live_prefix}_physical_closure_byte_length": len(closure_raw),
    }
    verify_legacy_live_authority_projection(
        root,
        tuple(str(path) for path in closure["live_authority_paths"]),
        record_key=f"{live_prefix}_contract_path",
        expected=live_expected,
        prefix=f"LIVE_{live_prefix.upper()}_INVALID_ROUTE",
    )
    require(
        (root / str(closure["closure_audit_path"])).is_file(),
        "INVALID_ROUTE_AUDIT_PATH",
    )
    return closure


def run_invalid_cli(*, pass_marker: str, failure_marker: str, **kwargs: Any) -> int:
    """CLI for the reusable consumed-invalid route-ghost closure audit."""

    try:
        closure = validate_invalid_route_closure(**kwargs)
        physical = closure["physical_attempt"]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": closure["gate_id"],
                    "ok": True,
                    "status": closure["closure_status"],
                    "attempt_id": physical["attempt_id"],
                    "model_construction_count": int(
                        physical["model_construction_count"]
                    ),
                    "world_build_count": int(physical["world_build_count"]),
                    "solver_step_count": int(physical["solver_step_count"]),
                    "native_engine_health_passed": True,
                    "same_identity_rerun_permitted": False,
                },
                sort_keys=True,
            ),
        )
        return 0
    except (
        ClosureAuditError,
        AssertionError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(f"{failure_marker}:{error}", file=sys.stderr)
        return 1
