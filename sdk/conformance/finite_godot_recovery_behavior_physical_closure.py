#!/usr/bin/env python3
"""Reusable publication audit for finite Godot recovery behavior results."""

from __future__ import annotations

from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    complete_in_run_physical_invariant_projection,
    exact,
    git,
    load,
    require,
    source_bytes,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
    verify_retained_commit,
    verify_supervised_bounded_ghost_attempt,
)


_CONTIGUOUS_BOUNDARY_TRANSPORT_DESIGN_ID = (
    "godot_jolt_r24d167_contiguous_completed_step_boundary_transport_v1"
)
_CONTIGUOUS_BOUNDARY_TRANSPORT_PROFILE_ID = (
    "godot_jolt_r24d168_live_contiguous_completed_step_boundary_transport_v1"
)
_CONTIGUOUS_BOUNDARY_TRANSPORT_INITIALIZER_SCHEMA = (
    "sporespore_qsdk_r24d168_native_initializer_boundary_transport_v1"
)
_CONTIGUOUS_BOUNDARY_TRANSPORT_STATE_SCHEMA = (
    "sporespore_qsdk_r24d167_boundary_transport_state_v1"
)
_CONTIGUOUS_BOUNDARY_TRANSPORT_PAIR_SCHEMA = (
    "sporespore_qsdk_r24d167_contiguous_body_boundary_pair_v1"
)


def _contiguous_boundary_transport_projection(
    arm: dict[str, Any],
    outer_step_count: int,
) -> dict[str, Any]:
    """Verify the per-world transactional boundary state retained by R170+."""

    initializer = arm["boundary_transport_initializer_receipt"]
    terminal = arm["boundary_transport_terminal_state"]
    invariant_receipts = arm["in_run_invariant_receipts"]
    require(isinstance(initializer, dict), "BOUNDARY_TRANSPORT_INITIALIZER")
    require(isinstance(terminal, dict), "BOUNDARY_TRANSPORT_TERMINAL_STATE")
    require(
        isinstance(invariant_receipts, list)
        and len(invariant_receipts) == outer_step_count,
        "BOUNDARY_TRANSPORT_INVARIANT_POPULATION",
    )
    verify_exact_paths(
        initializer,
        {
            "schema_version": _CONTIGUOUS_BOUNDARY_TRANSPORT_INITIALIZER_SCHEMA,
            "gate_id": "QSDK-R24D168",
            "ok": True,
            "transport_design_id": _CONTIGUOUS_BOUNDARY_TRANSPORT_DESIGN_ID,
            "transport_profile_id": _CONTIGUOUS_BOUNDARY_TRANSPORT_PROFILE_ID,
            "initializer_boundary_sequence": 0,
            "state_revision": 0,
            "native_readback_count": 9,
            "physics_active_during_readback": False,
            "source_measurement": True,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "BOUNDARY_TRANSPORT_INITIALIZER",
    )
    verify_exact_paths(
        terminal,
        {
            "schema_version": _CONTIGUOUS_BOUNDARY_TRANSPORT_STATE_SCHEMA,
            "transport_design_id": _CONTIGUOUS_BOUNDARY_TRANSPORT_DESIGN_ID,
            "arm_id": arm["arm_kind"],
            "cached_boundary_sequence": outer_step_count,
            "accepted_pair_count": outer_step_count,
            "state_revision": outer_step_count,
            "cached_completed_boundary.boundary_sequence": outer_step_count,
            "cached_completed_boundary.source_kind": (
                "completed_step_direct_state_callback_v1"
            ),
            "cached_completed_boundary.physics_active": True,
            "cached_completed_boundary.source_measurement": True,
            "cached_completed_boundary.mechanical_energy_change_used_as_input": False,
            "cached_completed_boundary.energy_balance_residual_used_as_input": False,
            "cached_completed_boundary.acceptance_threshold_used_as_input": False,
            "cached_completed_boundary.controller_or_behavior_result_used_as_input": False,
        },
        "BOUNDARY_TRANSPORT_TERMINAL_STATE",
    )
    for semantic_step, receipt in enumerate(invariant_receipts, start=1):
        require(isinstance(receipt, dict), "BOUNDARY_TRANSPORT_INVARIANT_RECEIPT")
        verify_exact_paths(
            receipt,
            {
                "semantic_step": semantic_step,
                "contiguous_boundary_transport_profile_selected": True,
                "boundary_transport_capture_schema_version": (
                    "sporespore_qsdk_r24d168_godot_jolt_"
                    "contiguous_body_boundary_capture_v1"
                ),
                "boundary_transport_design_id": (
                    _CONTIGUOUS_BOUNDARY_TRANSPORT_DESIGN_ID
                ),
                "boundary_transport_profile_id": (
                    _CONTIGUOUS_BOUNDARY_TRANSPORT_PROFILE_ID
                ),
                "boundary_transport_previous_sequence": semantic_step - 1,
                "boundary_transport_state_revision_before": semantic_step - 1,
                "boundary_transport_state_revision_after": semantic_step,
                "boundary_transport_pre_boundary_source_kind": (
                    "inactive_physics_initializer_readback_v1"
                    if semantic_step == 1
                    else "completed_step_direct_state_callback_v1"
                ),
                "boundary_transport_post_boundary_source_kind": (
                    "completed_step_direct_state_callback_v1"
                ),
                "boundary_transport_cache_advance_count_pending_commit": 1,
                "boundary_transport_cache_advance_committed": True,
                "boundary_transport_source_measurement": True,
                "boundary_transport_mechanical_energy_change_used_as_input": False,
                "boundary_transport_energy_balance_residual_used_as_input": False,
                "boundary_transport_acceptance_threshold_used_as_input": False,
                "boundary_transport_controller_or_behavior_result_used_as_input": False,
            },
            "BOUNDARY_TRANSPORT_INVARIANT_RECEIPT",
        )
        capture_sha256 = receipt.get("boundary_transport_capture_sha256")
        require(
            isinstance(capture_sha256, str)
            and len(capture_sha256) == 71
            and capture_sha256.startswith("sha256:")
            and all(char in "0123456789abcdef" for char in capture_sha256[7:]),
            "BOUNDARY_TRANSPORT_CAPTURE_SHA256",
        )
    return {
        "initializer_native_readback_count": initializer["native_readback_count"],
        "per_step_invariant_receipt_count": len(invariant_receipts),
        "terminal_cached_boundary_sequence": terminal["cached_boundary_sequence"],
        "terminal_accepted_pair_count": terminal["accepted_pair_count"],
        "terminal_state_revision": terminal["state_revision"],
    }


def _trajectory_projection(arm: dict[str, Any]) -> dict[str, Any]:
    observations = arm["trace_v3"]["observations"]
    steps = arm["portable_step_receipts"]
    require(len(observations) == len(steps) > 0, "TRAJECTORY_POPULATION")
    classifications = [step["classification"] for step in steps]
    require(all(isinstance(value, dict) for value in classifications), "CLASSIFICATION")
    center_of_mass_y = [
        float(value["center_of_mass"]["position_world_m"]["y"])
        for value in observations
    ]
    simultaneous_contacts: list[int] = []
    foot_contact_steps: Counter[str] = Counter()
    for observation in observations:
        contacts = observation["ordered_foot_bearing_observations"]
        count = 0
        for contact in contacts:
            if bool(contact["ordinary_unilateral_contact"]):
                count += 1
                foot_contact_steps[str(contact["contact_site_id"])] += 1
        simultaneous_contacts.append(count)
    all_foot_ids = sorted(
        str(value["contact_site_id"])
        for value in observations[0]["ordered_foot_bearing_observations"]
    )
    maximum_contacts = max(simultaneous_contacts)
    energy_residuals = [
        float(value["energy_balance_residual_j"]) for value in classifications
    ]
    projection: dict[str, Any] = {
        "arm_kind": arm["arm_kind"],
        "outer_step_count": len(observations),
        "final_phase": arm["final_phase"],
        "terminal_failure_code": arm["terminal_failure_code"],
        "completed_phases": arm["final_memory"]["ordered_completed_phases"],
        "phase_counts": dict(
            sorted(Counter(str(step["prior_phase"]) for step in steps).items())
        ),
        "distal_support_gate_true_steps": sum(
            bool(value["distal_support_gate"]) for value in classifications
        ),
        "raised_body_gate_true_steps": sum(
            bool(value["raised_body_gate"]) for value in classifications
        ),
        "stable_stance_gate_true_steps": sum(
            bool(value["stable_stance_gate"]) for value in classifications
        ),
        "all_four_distal_sites_bearing_true_steps": sum(
            bool(value["all_four_distal_sites_bearing"])
            for value in classifications
        ),
        "entry_prone_gate_true_steps": sum(
            bool(value["entry_prone_gate"]) for value in classifications
        ),
        "center_of_mass_y_m": {
            "first": center_of_mass_y[0],
            "last": center_of_mass_y[-1],
            "minimum": min(center_of_mass_y),
            "maximum": max(center_of_mass_y),
            "last_gain": float(
                classifications[-1]["center_of_mass_height_gain_m"]
            ),
        },
        "energy_balance_residual_j": {
            "last": energy_residuals[-1],
            "maximum": max(energy_residuals),
        },
        "simultaneous_distal_contact_histogram": {
            str(key): value
            for key, value in sorted(Counter(simultaneous_contacts).items())
        },
        "maximum_simultaneous_distal_contacts": maximum_contacts,
        "first_maximum_simultaneous_contact_step": (
            simultaneous_contacts.index(maximum_contacts) + 1
        ),
        "last_maximum_simultaneous_contact_step": (
            len(simultaneous_contacts)
            - simultaneous_contacts[::-1].index(maximum_contacts)
        ),
        "foot_contact_steps": {
            foot_id: foot_contact_steps[foot_id] for foot_id in all_foot_ids
        },
        "complete_raw_invariant_projection": (
            complete_in_run_physical_invariant_projection(arm)
        ),
    }
    transport_keys = {
        "boundary_transport_initializer_receipt",
        "boundary_transport_terminal_state",
    }
    present_transport_keys = transport_keys.intersection(arm)
    require(
        not present_transport_keys or present_transport_keys == transport_keys,
        "BOUNDARY_TRANSPORT_PARTIAL_ARM_RECEIPT",
    )
    if present_transport_keys:
        projection["contiguous_boundary_transport"] = (
            _contiguous_boundary_transport_projection(arm, len(observations))
        )
    return projection


def _guard_projection(arm: dict[str, Any]) -> dict[str, Any]:
    intent_count = 0
    engagements = 0
    holds = 0
    fallbacks: list[tuple[int, str]] = []
    for application in arm["command_application_receipts"]:
        step = int(application["semantic_step"])
        for receipt in application.get("ordered_receipts", []):
            projection = receipt.get("native_angular_velocity_guard_projection")
            if not isinstance(projection, dict):
                continue
            intent_count += 1
            engagements += int(bool(projection["guard_engaged"]))
            holds += int(bool(projection["outer_guard_zero_impulse_hold"]))
            if bool(projection["representational_zero_impulse_fallback"]):
                fallbacks.append((step, str(receipt["actuator_id"])))
    require(fallbacks, "REPRESENTATIONAL_FALLBACK_POPULATION")
    by_actuator = Counter(actuator for _step, actuator in fallbacks)
    return {
        "refinement_safe_intent_count": intent_count,
        "guard_engagement_count": engagements,
        "outer_guard_zero_impulse_hold_count": holds,
        "representational_zero_impulse_fallback_count": len(fallbacks),
        "representational_fallback_step_count": len(
            {step for step, _actuator in fallbacks}
        ),
        "first_representational_fallback_step": min(step for step, _ in fallbacks),
        "last_representational_fallback_step": max(step for step, _ in fallbacks),
        "fallback_by_actuator": dict(sorted(by_actuator.items())),
    }


def _solver_coupled_constraint_motor_projection(
    arm: dict[str, Any],
) -> dict[str, Any]:
    """Compactly recheck pre-solver constraint-motor application semantics."""

    applications = arm["command_application_receipts"]
    require(len(applications) > 1, "SOLVER_COUPLED_APPLICATION_POPULATION")
    checked: list[dict[str, Any]] = []
    bootstrap_application_count = 0
    semantics_ids: set[str] = set()
    phase_counts: Counter[str] = Counter()
    active_phase_counts: Counter[str] = Counter()
    mutation_scope_counts: Counter[str] = Counter()
    zero_command_counts: Counter[str] = Counter()
    active_steps: list[int] = []
    host_configuration_writes = 0
    host_writes = 0
    host_readbacks = 0
    motor_enables = 0
    target_writes = 0
    validated_commands = 0

    for application in applications:
        if "application_mutation_semantics_checked" not in application:
            bootstrap_application_count += 1
            continue
        require(
            bool(application["application_mutation_semantics_checked"]),
            "SOLVER_COUPLED_SEMANTICS_CHECK",
        )
        require(
            bool(application["controller_realization_identity_checked"]),
            "SOLVER_COUPLED_REALIZATION_CHECK",
        )
        require(
            bool(application["native_contact_solver_coupled"]),
            "SOLVER_COUPLED_NATIVE_PATH",
        )
        semantics_id = str(application["application_mutation_semantics_id"])
        require(bool(semantics_id), "SOLVER_COUPLED_SEMANTICS_ID")
        semantics_ids.add(semantics_id)
        active = bool(
            application["active_constraint_motor_configuration_modified"]
        )
        exact(
            bool(application["physics_state_modified"]),
            active,
            "SOLVER_COUPLED_PHYSICS_MUTATION",
        )
        exact(
            str(application["physics_state_mutation_scope"]),
            "constraint_motor_configuration_pre_solver" if active else "none",
            "SOLVER_COUPLED_MUTATION_SCOPE",
        )
        exact(
            bool(application["pre_solver_rigid_body_state_modified"]),
            False,
            "SOLVER_COUPLED_PRE_SOLVER_BODY_MUTATION",
        )
        exact(
            bool(application["solver_state_advanced"]),
            False,
            "SOLVER_COUPLED_SOLVER_ADVANCEMENT",
        )
        exact(
            int(application["pre_solver_direct_body_impulse_write_count"]),
            0,
            "SOLVER_COUPLED_DIRECT_BODY_WRITE",
        )
        exact(
            int(application["root_actuation_count"]),
            0,
            "SOLVER_COUPLED_ROOT_ACTUATION",
        )
        exact(
            int(application["engine_specific_policy_branch_count"]),
            0,
            "SOLVER_COUPLED_ENGINE_POLICY_BRANCH",
        )
        exact(
            int(application["fallback_control_count"]),
            0,
            "SOLVER_COUPLED_FALLBACK",
        )
        exact(
            int(application["host_constraint_configuration_write_count"]),
            8,
            "SOLVER_COUPLED_CONFIGURATION_WRITES",
        )
        exact(int(application["host_write_count"]), 8, "SOLVER_COUPLED_WRITES")
        exact(
            int(application["host_readback_count"]),
            8,
            "SOLVER_COUPLED_READBACKS",
        )
        expected_active_count = 8 if active else 0
        exact(
            int(application["motor_enabled_count"]),
            expected_active_count,
            "SOLVER_COUPLED_MOTOR_ENABLES",
        )
        exact(
            int(application["solver_coupled_motor_target_write_count"]),
            expected_active_count,
            "SOLVER_COUPLED_TARGET_WRITES",
        )
        exact(
            int(application["validated_command_count"]),
            expected_active_count,
            "SOLVER_COUPLED_VALIDATED_COMMANDS",
        )
        checked.append(application)
        phase = str(application["phase"])
        phase_counts[phase] += 1
        mutation_scope_counts[str(application["physics_state_mutation_scope"])] += 1
        zero_command_counts[
            "true" if bool(application["zero_command"]) else "false"
        ] += 1
        if active:
            active_steps.append(int(application["semantic_step"]))
            active_phase_counts[phase] += 1
        host_configuration_writes += int(
            application["host_constraint_configuration_write_count"]
        )
        host_writes += int(application["host_write_count"])
        host_readbacks += int(application["host_readback_count"])
        motor_enables += int(application["motor_enabled_count"])
        target_writes += int(
            application["solver_coupled_motor_target_write_count"]
        )
        validated_commands += int(application["validated_command_count"])

    require(len(semantics_ids) == 1, "SOLVER_COUPLED_SEMANTICS_POPULATION")
    exact(
        bootstrap_application_count + len(checked),
        len(applications),
        "SOLVER_COUPLED_APPLICATION_PARTITION",
    )
    return {
        "application_count": len(applications),
        "bootstrap_application_count": bootstrap_application_count,
        "semantics_checked_application_count": len(checked),
        "application_mutation_semantics_ids": sorted(semantics_ids),
        "active_constraint_configuration_application_count": len(active_steps),
        "inactive_constraint_configuration_application_count": (
            len(checked) - len(active_steps)
        ),
        "physics_state_modified_application_count": len(active_steps),
        "pre_solver_rigid_body_state_modified_application_count": 0,
        "solver_state_advanced_application_count": 0,
        "phase_counts": dict(sorted(phase_counts.items())),
        "active_phase_counts": dict(sorted(active_phase_counts.items())),
        "mutation_scope_counts": dict(sorted(mutation_scope_counts.items())),
        "zero_command_counts": dict(sorted(zero_command_counts.items())),
        "first_active_application_step": min(active_steps) if active_steps else None,
        "last_active_application_step": max(active_steps) if active_steps else None,
        "total_host_constraint_configuration_write_count": (
            host_configuration_writes
        ),
        "total_host_write_count": host_writes,
        "total_host_readback_count": host_readbacks,
        "total_motor_enabled_count": motor_enables,
        "total_solver_coupled_motor_target_write_count": target_writes,
        "total_validated_command_count": validated_commands,
    }


def _order_neutral_population_projection(arm: dict[str, Any]) -> dict[str, Any]:
    """Compactly recheck the order-neutral application population in one arm."""

    application_steps: list[int] = []
    common_scales: list[float] = []
    actuator_ids: tuple[str, ...] | None = None
    body_ids: tuple[str, ...] | None = None
    actuator_mapping_id: str | None = None
    work_mapping_id: str | None = None
    allocation_rule_id: str | None = None
    attribution_rule_id: str | None = None
    body_application_rule_id: str | None = None
    guard_engagement_count = 0
    outer_guard_hold_count = 0
    representational_fallback_count = 0
    scale_refinement_count = 0
    total_body_impulse_write_count = 0
    total_native_readback_count = 0
    body_write_histogram: Counter[int] = Counter()
    nonzero_applied_impulse_steps: Counter[str] = Counter()

    for application in arm["command_application_receipts"]:
        population = application.get("order_neutral_population_guard_projection")
        if population is None:
            continue
        require(isinstance(population, dict), "ORDER_NEUTRAL_POPULATION")
        require(bool(population["ok"]), "ORDER_NEUTRAL_POPULATION_OK")
        require(
            bool(application["order_neutral_population_projection_required"]),
            "ORDER_NEUTRAL_REQUIRED",
        )
        require(
            bool(application["aggregate_body_application_required"]),
            "ORDER_NEUTRAL_AGGREGATE_APPLICATION",
        )
        require(
            bool(application["per_actuator_attribution_required"]),
            "ORDER_NEUTRAL_ATTRIBUTION",
        )
        require(
            not bool(application["input_iteration_order_has_action_authority"]),
            "ORDER_NEUTRAL_ITERATION_AUTHORITY",
        )
        require(
            bool(application["all_immediate_native_readbacks_inside_guard"]),
            "ORDER_NEUTRAL_READBACK_GUARD",
        )

        current_actuator_ids = tuple(
            str(value) for value in population["ordered_actuator_ids"]
        )
        current_body_ids = tuple(str(value) for value in population["ordered_body_ids"])
        require(
            len(current_actuator_ids) == int(population["actuator_count"]) > 0,
            "ORDER_NEUTRAL_ACTUATOR_POPULATION",
        )
        require(
            len(current_body_ids) == int(population["body_count"]) > 0,
            "ORDER_NEUTRAL_BODY_POPULATION",
        )
        require(
            len(set(current_actuator_ids)) == len(current_actuator_ids),
            "ORDER_NEUTRAL_ACTUATOR_IDENTITY",
        )
        require(
            len(set(current_body_ids)) == len(current_body_ids),
            "ORDER_NEUTRAL_BODY_IDENTITY",
        )
        if actuator_ids is None:
            actuator_ids = current_actuator_ids
            body_ids = current_body_ids
            actuator_mapping_id = str(application["actuator_mapping_id"])
            work_mapping_id = str(application["work_mapping_id"])
            allocation_rule_id = str(population["allocation_rule_id"])
            attribution_rule_id = str(population["attribution_rule_id"])
            body_application_rule_id = str(population["body_application_rule_id"])
        exact(current_actuator_ids, actuator_ids, "ORDER_NEUTRAL_ACTUATOR_ORDER")
        exact(current_body_ids, body_ids, "ORDER_NEUTRAL_BODY_ORDER")
        exact(
            str(application["actuator_mapping_id"]),
            actuator_mapping_id,
            "ORDER_NEUTRAL_ACTUATOR_MAPPING",
        )
        exact(
            str(application["work_mapping_id"]),
            work_mapping_id,
            "ORDER_NEUTRAL_WORK_MAPPING",
        )
        exact(
            str(population["allocation_rule_id"]),
            allocation_rule_id,
            "ORDER_NEUTRAL_ALLOCATION_RULE",
        )
        exact(
            str(population["attribution_rule_id"]),
            attribution_rule_id,
            "ORDER_NEUTRAL_ATTRIBUTION_RULE",
        )
        exact(
            str(population["body_application_rule_id"]),
            body_application_rule_id,
            "ORDER_NEUTRAL_BODY_APPLICATION_RULE",
        )

        receipts = application["ordered_receipts"]
        body_receipts = application["ordered_body_application_receipts"]
        exact(len(receipts), len(current_actuator_ids), "ORDER_NEUTRAL_RECEIPTS")
        exact(len(body_receipts), len(current_body_ids), "ORDER_NEUTRAL_BODY_RECEIPTS")
        scale = float(population["common_applied_scale"])
        require(0.0 <= scale <= 1.0, "ORDER_NEUTRAL_SCALE")
        exact(
            float(application["native_angular_velocity_guard_minimum_applied_scale"]),
            scale,
            "ORDER_NEUTRAL_APPLICATION_SCALE",
        )
        for index, receipt in enumerate(receipts):
            exact(
                str(receipt["actuator_id"]),
                current_actuator_ids[index],
                "ORDER_NEUTRAL_RECEIPT_ORDER",
            )
            exact(
                float(receipt["common_applied_scale"]),
                scale,
                "ORDER_NEUTRAL_RECEIPT_SCALE",
            )
            exact(
                str(receipt["actuator_mapping_id"]),
                actuator_mapping_id,
                "ORDER_NEUTRAL_RECEIPT_MAPPING",
            )
            exact(
                str(receipt["work_mapping_id"]),
                work_mapping_id,
                "ORDER_NEUTRAL_RECEIPT_WORK_MAPPING",
            )
            require(
                bool(receipt["aggregate_body_application"])
                and bool(receipt["joint_attribution_only"])
                and int(receipt["direct_joint_body_impulse_write_count"]) == 0,
                "ORDER_NEUTRAL_RECEIPT_ATTRIBUTION",
            )
            if abs(float(receipt["applied_signed_joint_impulse_nms"])) > 0.0:
                nonzero_applied_impulse_steps[current_actuator_ids[index]] += 1

        body_write_count = int(application["body_impulse_write_count"])
        exact(
            body_write_count,
            int(population["nonzero_body_impulse_count"]),
            "ORDER_NEUTRAL_BODY_WRITE_COUNT",
        )
        exact(
            int(application["host_write_count"]),
            body_write_count,
            "ORDER_NEUTRAL_HOST_WRITE_COUNT",
        )
        exact(
            int(application["native_angular_velocity_total_readback_count"]),
            2 * len(current_body_ids),
            "ORDER_NEUTRAL_READBACK_COUNT",
        )
        application_steps.append(int(application["semantic_step"]))
        common_scales.append(scale)
        guard_engagement_count += int(bool(population["population_guard_engaged"]))
        outer_guard_hold_count += int(bool(population["outer_guard_zero_impulse_hold"]))
        representational_fallback_count += int(
            bool(population["representational_zero_impulse_fallback"])
        )
        scale_refinement_count += int(population["scale_refinement_count"])
        total_body_impulse_write_count += body_write_count
        total_native_readback_count += int(
            application["native_angular_velocity_total_readback_count"]
        )
        body_write_histogram[body_write_count] += 1

    if not application_steps:
        return {
            "application_count": 0,
            "ordered_actuator_ids": [],
            "ordered_body_ids": [],
            "actuator_mapping_id": None,
            "work_mapping_id": None,
            "allocation_rule_id": None,
            "attribution_rule_id": None,
            "body_application_rule_id": None,
            "first_application_step": None,
            "last_application_step": None,
            "positive_common_scale_count": 0,
            "zero_common_scale_count": 0,
            "minimum_common_applied_scale": None,
            "maximum_common_applied_scale": None,
            "population_guard_engagement_count": 0,
            "outer_guard_zero_impulse_hold_count": 0,
            "representational_zero_impulse_fallback_count": 0,
            "scale_refinement_count": 0,
            "actuator_attribution_count": 0,
            "total_body_impulse_write_count": 0,
            "body_impulse_write_histogram": {},
            "total_native_readback_count": 0,
            "nonzero_applied_impulse_steps_by_actuator": {},
        }

    if actuator_ids is None or body_ids is None:
        raise ClosureAuditError("ORDER_NEUTRAL_POPULATION_IDENTITY")
    return {
        "application_count": len(application_steps),
        "ordered_actuator_ids": list(actuator_ids),
        "ordered_body_ids": list(body_ids),
        "actuator_mapping_id": actuator_mapping_id,
        "work_mapping_id": work_mapping_id,
        "allocation_rule_id": allocation_rule_id,
        "attribution_rule_id": attribution_rule_id,
        "body_application_rule_id": body_application_rule_id,
        "first_application_step": min(application_steps),
        "last_application_step": max(application_steps),
        "positive_common_scale_count": sum(scale > 0.0 for scale in common_scales),
        "zero_common_scale_count": sum(scale == 0.0 for scale in common_scales),
        "minimum_common_applied_scale": min(common_scales),
        "maximum_common_applied_scale": max(common_scales),
        "population_guard_engagement_count": guard_engagement_count,
        "outer_guard_zero_impulse_hold_count": outer_guard_hold_count,
        "representational_zero_impulse_fallback_count": (
            representational_fallback_count
        ),
        "scale_refinement_count": scale_refinement_count,
        "actuator_attribution_count": len(application_steps) * len(actuator_ids),
        "total_body_impulse_write_count": total_body_impulse_write_count,
        "body_impulse_write_histogram": {
            str(key): value for key, value in sorted(body_write_histogram.items())
        },
        "total_native_readback_count": total_native_readback_count,
        "nonzero_applied_impulse_steps_by_actuator": {
            actuator_id: nonzero_applied_impulse_steps[actuator_id]
            for actuator_id in actuator_ids
        },
    }


def _joint_target_monotone_population_projection(
    arm: dict[str, Any],
) -> dict[str, Any]:
    """Compactly recheck target-monotone aggregate applications in one arm."""

    application_steps: list[int] = []
    target_scales: list[float] = []
    body_scales: list[float] = []
    actuator_ids: tuple[str, ...] | None = None
    body_ids: tuple[str, ...] | None = None
    actuator_mapping_id: str | None = None
    work_mapping_id: str | None = None
    allocation_rule_id: str | None = None
    body_application_rule_id: str | None = None
    target_monotone_rule_id: str | None = None
    population_zero_hold_count = 0
    target_guard_engagement_count = 0
    target_representational_zero_hold_count = 0
    target_scale_refinement_count = 0
    helpful_joint_projection_count = 0
    neutral_joint_projection_count = 0
    nonhelpful_joint_projection_count = 0
    joint_target_crossing_count = 0
    total_body_impulse_write_count = 0
    total_native_readback_count = 0
    body_write_histogram: Counter[int] = Counter()
    per_actuator_classification: dict[str, Counter[str]] = {}

    for application in arm["command_application_receipts"]:
        population = application.get(
            "joint_target_monotone_population_guard_projection"
        )
        if population is None:
            continue
        require(isinstance(population, dict), "TARGET_MONOTONE_POPULATION")
        require(bool(population["ok"]), "TARGET_MONOTONE_POPULATION_OK")
        require(
            bool(application["joint_target_monotone_population_projection_required"]),
            "TARGET_MONOTONE_REQUIRED",
        )
        require(
            bool(application["order_neutral_population_projection_required"])
            and bool(application["aggregate_body_application_required"])
            and bool(application["per_actuator_attribution_required"]),
            "TARGET_MONOTONE_AGGREGATE_APPLICATION",
        )
        require(
            not bool(application["input_iteration_order_has_action_authority"]),
            "TARGET_MONOTONE_ITERATION_AUTHORITY",
        )

        current_actuator_ids = tuple(
            str(value) for value in population["ordered_actuator_ids"]
        )
        current_body_ids = tuple(
            str(value) for value in population["ordered_body_ids"]
        )
        require(
            len(current_actuator_ids) == int(population["actuator_count"]) > 0,
            "TARGET_MONOTONE_ACTUATOR_POPULATION",
        )
        require(
            len(current_body_ids) == int(population["body_count"]) > 0,
            "TARGET_MONOTONE_BODY_POPULATION",
        )
        require(
            len(set(current_actuator_ids)) == len(current_actuator_ids)
            and len(set(current_body_ids)) == len(current_body_ids),
            "TARGET_MONOTONE_POPULATION_IDENTITY",
        )
        if actuator_ids is None:
            actuator_ids = current_actuator_ids
            body_ids = current_body_ids
            actuator_mapping_id = str(application["actuator_mapping_id"])
            work_mapping_id = str(application["work_mapping_id"])
            allocation_rule_id = str(population["allocation_rule_id"])
            body_application_rule_id = str(population["body_application_rule_id"])
            target_monotone_rule_id = str(population["target_monotone_rule_id"])
        exact(current_actuator_ids, actuator_ids, "TARGET_MONOTONE_ACTUATOR_ORDER")
        exact(current_body_ids, body_ids, "TARGET_MONOTONE_BODY_ORDER")
        exact(
            str(application["actuator_mapping_id"]),
            actuator_mapping_id,
            "TARGET_MONOTONE_ACTUATOR_MAPPING",
        )
        exact(
            str(application["work_mapping_id"]),
            work_mapping_id,
            "TARGET_MONOTONE_WORK_MAPPING",
        )
        exact(
            str(population["allocation_rule_id"]),
            allocation_rule_id,
            "TARGET_MONOTONE_ALLOCATION_RULE",
        )
        exact(
            str(population["body_application_rule_id"]),
            body_application_rule_id,
            "TARGET_MONOTONE_BODY_APPLICATION_RULE",
        )
        exact(
            str(population["target_monotone_rule_id"]),
            target_monotone_rule_id,
            "TARGET_MONOTONE_RULE",
        )

        target_scale = float(population["target_common_pre_scale"])
        body_scale = float(population["body_guard_common_applied_scale"])
        require(
            0.0 <= target_scale <= 1.0 and 0.0 <= body_scale <= 1.0,
            "TARGET_MONOTONE_SCALE",
        )
        exact(
            float(application["joint_target_monotone_common_pre_scale"]),
            target_scale,
            "TARGET_MONOTONE_APPLICATION_SCALE",
        )
        exact(
            float(application["body_guard_common_applied_scale"]),
            body_scale,
            "TARGET_MONOTONE_BODY_SCALE",
        )

        joint_projections = population["ordered_joint_target_projections"]
        receipts = application["ordered_receipts"]
        body_receipts = application["ordered_body_application_receipts"]
        exact(
            len(joint_projections),
            len(current_actuator_ids),
            "TARGET_MONOTONE_JOINT_PROJECTIONS",
        )
        exact(len(receipts), len(current_actuator_ids), "TARGET_MONOTONE_RECEIPTS")
        exact(
            len(body_receipts),
            len(current_body_ids),
            "TARGET_MONOTONE_BODY_RECEIPTS",
        )
        local_helpful = 0
        local_neutral = 0
        local_nonhelpful = 0
        for index, projection in enumerate(joint_projections):
            actuator_id = current_actuator_ids[index]
            exact(
                str(projection["actuator_id"]),
                actuator_id,
                "TARGET_MONOTONE_JOINT_ORDER",
            )
            exact(
                float(projection["target_common_pre_scale"]),
                target_scale,
                "TARGET_MONOTONE_JOINT_SCALE",
            )
            require(
                bool(projection["absolute_target_error_nonincreasing"])
                and not bool(projection["target_crossed"]),
                "TARGET_MONOTONE_JOINT_RESULT",
            )
            helpful = bool(projection["full_scale_delta_helpful"])
            neutral = bool(projection["full_scale_delta_neutral"])
            require(not (helpful and neutral), "TARGET_MONOTONE_CLASSIFICATION")
            classification = "helpful" if helpful else "neutral" if neutral else "nonhelpful"
            per_actuator_classification.setdefault(actuator_id, Counter())[classification] += 1
            local_helpful += int(helpful)
            local_neutral += int(neutral)
            local_nonhelpful += int(not helpful and not neutral)

            receipt = receipts[index]
            exact(str(receipt["actuator_id"]), actuator_id, "TARGET_MONOTONE_RECEIPT_ORDER")
            exact(
                float(receipt["target_common_pre_scale"]),
                target_scale,
                "TARGET_MONOTONE_RECEIPT_SCALE",
            )
            require(
                bool(receipt["absolute_target_error_nonincreasing"])
                and not bool(receipt["target_crossed"]),
                "TARGET_MONOTONE_RECEIPT_RESULT",
            )
        exact(
            (
                local_helpful,
                local_neutral,
                local_nonhelpful,
            ),
            (
                int(population["helpful_joint_projection_count"]),
                int(population["neutral_joint_projection_count"]),
                int(population["nonhelpful_joint_projection_count"]),
            ),
            "TARGET_MONOTONE_CLASSIFICATION_COUNTS",
        )
        zero_hold = local_nonhelpful > 0
        exact(
            bool(population["population_zero_hold_for_nonhelpful_joint_delta"]),
            zero_hold,
            "TARGET_MONOTONE_ZERO_HOLD",
        )
        if zero_hold:
            exact(target_scale, 0.0, "TARGET_MONOTONE_HELD_SCALE")
        require(
            bool(population["all_joint_target_errors_nonincreasing"])
            and int(population["joint_target_crossing_count"]) == 0,
            "TARGET_MONOTONE_POPULATION_RESULT",
        )

        body_write_count = int(application["body_impulse_write_count"])
        exact(
            body_write_count,
            int(population["body_impulse_write_count"]),
            "TARGET_MONOTONE_BODY_WRITE_COUNT",
        )
        exact(
            int(application["host_write_count"]),
            body_write_count,
            "TARGET_MONOTONE_HOST_WRITE_COUNT",
        )
        exact(
            int(application["native_angular_velocity_total_readback_count"]),
            2 * len(current_body_ids),
            "TARGET_MONOTONE_READBACK_COUNT",
        )

        application_steps.append(int(application["semantic_step"]))
        target_scales.append(target_scale)
        body_scales.append(body_scale)
        population_zero_hold_count += int(zero_hold)
        target_guard_engagement_count += int(bool(population["target_guard_engaged"]))
        target_representational_zero_hold_count += int(
            bool(population["target_representational_zero_hold"])
        )
        target_scale_refinement_count += int(population["target_scale_refinement_count"])
        helpful_joint_projection_count += local_helpful
        neutral_joint_projection_count += local_neutral
        nonhelpful_joint_projection_count += local_nonhelpful
        joint_target_crossing_count += int(population["joint_target_crossing_count"])
        total_body_impulse_write_count += body_write_count
        total_native_readback_count += int(
            application["native_angular_velocity_total_readback_count"]
        )
        body_write_histogram[body_write_count] += 1

    if not application_steps:
        return {
            "application_count": 0,
            "ordered_actuator_ids": [],
            "ordered_body_ids": [],
            "actuator_mapping_id": None,
            "work_mapping_id": None,
            "allocation_rule_id": None,
            "body_application_rule_id": None,
            "target_monotone_rule_id": None,
            "first_application_step": None,
            "last_application_step": None,
            "positive_target_common_scale_count": 0,
            "zero_target_common_scale_count": 0,
            "minimum_target_common_pre_scale": None,
            "maximum_target_common_pre_scale": None,
            "minimum_body_guard_common_applied_scale": None,
            "maximum_body_guard_common_applied_scale": None,
            "population_zero_hold_count": 0,
            "target_guard_engagement_count": 0,
            "target_representational_zero_hold_count": 0,
            "target_scale_refinement_count": 0,
            "helpful_joint_projection_count": 0,
            "neutral_joint_projection_count": 0,
            "nonhelpful_joint_projection_count": 0,
            "joint_target_crossing_count": 0,
            "total_body_impulse_write_count": 0,
            "body_impulse_write_histogram": {},
            "total_native_readback_count": 0,
            "per_actuator_classification_counts": {},
        }

    if actuator_ids is None or body_ids is None:
        raise ClosureAuditError("TARGET_MONOTONE_POPULATION_IDENTITY")
    return {
        "application_count": len(application_steps),
        "ordered_actuator_ids": list(actuator_ids),
        "ordered_body_ids": list(body_ids),
        "actuator_mapping_id": actuator_mapping_id,
        "work_mapping_id": work_mapping_id,
        "allocation_rule_id": allocation_rule_id,
        "body_application_rule_id": body_application_rule_id,
        "target_monotone_rule_id": target_monotone_rule_id,
        "first_application_step": min(application_steps),
        "last_application_step": max(application_steps),
        "positive_target_common_scale_count": sum(scale > 0.0 for scale in target_scales),
        "zero_target_common_scale_count": sum(scale == 0.0 for scale in target_scales),
        "minimum_target_common_pre_scale": min(target_scales),
        "maximum_target_common_pre_scale": max(target_scales),
        "minimum_body_guard_common_applied_scale": min(body_scales),
        "maximum_body_guard_common_applied_scale": max(body_scales),
        "population_zero_hold_count": population_zero_hold_count,
        "target_guard_engagement_count": target_guard_engagement_count,
        "target_representational_zero_hold_count": target_representational_zero_hold_count,
        "target_scale_refinement_count": target_scale_refinement_count,
        "helpful_joint_projection_count": helpful_joint_projection_count,
        "neutral_joint_projection_count": neutral_joint_projection_count,
        "nonhelpful_joint_projection_count": nonhelpful_joint_projection_count,
        "joint_target_crossing_count": joint_target_crossing_count,
        "total_body_impulse_write_count": total_body_impulse_write_count,
        "body_impulse_write_histogram": {
            str(key): value for key, value in sorted(body_write_histogram.items())
        },
        "total_native_readback_count": total_native_readback_count,
        "per_actuator_classification_counts": {
            actuator_id: {
                classification: per_actuator_classification[actuator_id][classification]
                for classification in ("helpful", "neutral", "nonhelpful")
            }
            for actuator_id in actuator_ids
        },
    }


def _joint_space_effective_inertia_population_projection(
    arm: dict[str, Any],
) -> dict[str, Any]:
    """Compactly bind coupled joint-space applications in one behavior arm."""

    empty: dict[str, Any] = {
        "application_count": 0,
        "ordered_actuator_ids": [],
        "ordered_body_ids": [],
        "actuator_mapping_id": None,
        "work_mapping_id": None,
        "projection_schema": None,
        "allocation_rule_id": None,
        "body_application_rule_id": None,
        "response_matrix_rule_id": None,
        "solve_rule_id": None,
        "representation_rule_id": None,
        "first_application_step": None,
        "last_application_step": None,
        "positive_joint_space_common_scale_count": 0,
        "zero_joint_space_common_scale_count": 0,
        "minimum_joint_space_common_pre_scale": None,
        "maximum_joint_space_common_pre_scale": None,
        "minimum_body_guard_common_applied_scale": None,
        "maximum_body_guard_common_applied_scale": None,
        "minimum_cap_common_scale": None,
        "maximum_cap_common_scale": None,
        "solver_guard_engagement_count": 0,
        "representation_zero_hold_count": 0,
        "representation_refinement_count": 0,
        "joint_target_crossing_count": 0,
        "minimum_cholesky_pivot": None,
        "maximum_solve_residual_rad_s": None,
        "maximum_response_matrix_symmetry_residual": None,
        "maximum_source_reconstruction_residual_rad_s": None,
        "maximum_predicted_target_error_rad_s": None,
        "total_body_impulse_write_count": 0,
        "body_impulse_write_histogram": {},
        "total_native_readback_count": 0,
        "nonzero_applied_impulse_steps_by_actuator": {},
        "saturated_impulse_steps_by_actuator": {},
    }
    rows = [
        (application, projection)
        for application in arm["command_application_receipts"]
        if (
            projection := application.get(
                "joint_space_effective_inertia_population_guard_projection"
            )
        )
        is not None
    ]
    if not rows:
        return empty

    first_application, first = rows[0]
    actuator_ids = tuple(str(value) for value in first["ordered_actuator_ids"])
    body_ids = tuple(str(value) for value in first["ordered_body_ids"])
    identity = {
        "actuator_mapping_id": str(first_application["actuator_mapping_id"]),
        "work_mapping_id": str(first_application["work_mapping_id"]),
        "projection_schema": str(first["schema_version"]),
        "allocation_rule_id": str(first["allocation_rule_id"]),
        "body_application_rule_id": str(first["body_application_rule_id"]),
        "response_matrix_rule_id": str(first["response_matrix_rule_id"]),
        "solve_rule_id": str(first["solve_rule_id"]),
        "representation_rule_id": str(first["representation_rule_id"]),
    }
    steps: list[int] = []
    joint_scales: list[float] = []
    body_scales: list[float] = []
    cap_scales: list[float] = []
    pivots: list[float] = []
    solve_residuals: list[float] = []
    symmetry_residuals: list[float] = []
    reconstruction_residuals: list[float] = []
    predicted_target_errors: list[float] = []
    body_writes: Counter[int] = Counter()
    nonzero_steps: Counter[str] = Counter()
    saturated_steps: Counter[str] = Counter()
    solver_guards = 0
    zero_holds = 0
    refinements = 0
    crossings = 0
    write_count = 0
    readback_count = 0

    for application, population in rows:
        require(isinstance(population, dict) and bool(population["ok"]), "JOINT_SPACE")
        current_actuators = tuple(
            str(value) for value in population["ordered_actuator_ids"]
        )
        current_bodies = tuple(str(value) for value in population["ordered_body_ids"])
        exact(current_actuators, actuator_ids, "JOINT_SPACE_ACTUATOR_ORDER")
        exact(current_bodies, body_ids, "JOINT_SPACE_BODY_ORDER")
        exact(len(actuator_ids), int(population["actuator_count"]), "JOINT_SPACE_ACTUATORS")
        exact(len(body_ids), int(population["body_count"]), "JOINT_SPACE_BODIES")
        require(
            len(set(actuator_ids)) == len(actuator_ids)
            and len(set(body_ids)) == len(body_ids),
            "JOINT_SPACE_IDENTITIES",
        )
        for key, value in identity.items():
            observed = (
                application[key]
                if key in ("actuator_mapping_id", "work_mapping_id")
                else population[
                    "schema_version" if key == "projection_schema" else key
                ]
            )
            exact(str(observed), value, f"JOINT_SPACE_{key.upper()}")

        require(
            bool(
                application[
                    "joint_space_effective_inertia_population_projection_required"
                ]
            )
            and bool(application["order_neutral_population_projection_required"])
            and bool(application["aggregate_body_application_required"])
            and bool(application["per_actuator_attribution_required"])
            and bool(application["all_immediate_native_readbacks_inside_guard"])
            and not bool(application["input_iteration_order_has_action_authority"]),
            "JOINT_SPACE_APPLICATION_CONTRACT",
        )
        require(
            bool(population["all_joint_target_errors_nonincreasing"])
            and int(population["joint_target_crossing_count"]) == 0
            and bool(population["all_predicted_inside_outer_guard"])
            and bool(population["symmetric_response_matrix"])
            and not bool(population["input_iteration_order_has_action_authority"])
            and not bool(population["published_actuator_caps_changed"])
            and not bool(population["controller_target_changed"])
            and not bool(population["outer_guard_changed"]),
            "JOINT_SPACE_POPULATION_CONTRACT",
        )

        joint_scale = float(population["joint_space_common_pre_scale"])
        body_scale = float(population["body_guard_common_applied_scale"])
        cap_scale = float(population["cap_common_scale"])
        require(
            all(0.0 <= value <= 1.0 for value in (joint_scale, body_scale, cap_scale)),
            "JOINT_SPACE_SCALE",
        )
        exact(
            float(application["joint_space_effective_inertia_common_pre_scale"]),
            joint_scale,
            "JOINT_SPACE_APPLICATION_SCALE",
        )
        exact(
            float(application["body_guard_common_applied_scale"]),
            body_scale,
            "JOINT_SPACE_BODY_SCALE",
        )

        matrix = population["response_matrix"]
        local_pivots = [float(value) for value in population["cholesky_pivots"]]
        projections = population["ordered_joint_solve_projections"]
        receipts = application["ordered_receipts"]
        body_receipts = application["ordered_body_application_receipts"]
        require(
            len(matrix) == len(actuator_ids)
            and all(len(row) == len(actuator_ids) for row in matrix)
            and len(local_pivots) == len(actuator_ids)
            and all(value > 0.0 for value in local_pivots),
            "JOINT_SPACE_SOLVE",
        )
        exact(len(projections), len(actuator_ids), "JOINT_SPACE_PROJECTIONS")
        exact(len(receipts), len(actuator_ids), "JOINT_SPACE_RECEIPTS")
        exact(len(body_receipts), len(body_ids), "JOINT_SPACE_BODY_RECEIPTS")
        for index, (projection, receipt) in enumerate(zip(projections, receipts)):
            actuator_id = actuator_ids[index]
            exact(str(projection["actuator_id"]), actuator_id, "JOINT_SPACE_PROJECTION_ORDER")
            exact(str(receipt["actuator_id"]), actuator_id, "JOINT_SPACE_RECEIPT_ORDER")
            require(
                bool(projection["absolute_target_error_nonincreasing"])
                and not bool(projection["target_crossed"])
                and bool(receipt["ok"])
                and bool(receipt["source_measurement"])
                and bool(receipt["absolute_target_error_nonincreasing"])
                and not bool(receipt["target_crossed"])
                and bool(receipt["aggregate_body_application"])
                and bool(receipt["joint_attribution_only"])
                and int(receipt["direct_joint_body_impulse_write_count"]) == 0
                and bool(receipt["population_attribution"]["equal_and_opposite_pair"]),
                "JOINT_SPACE_ACTUATOR_RESULT",
            )
            nonzero_steps[actuator_id] += int(
                abs(float(receipt["applied_signed_joint_impulse_nms"])) > 0.0
            )
            saturated_steps[actuator_id] += int(bool(receipt["impulse_saturated"]))
            reconstruction_residuals.append(
                abs(float(projection["source_reconstruction_residual_rad_s"]))
            )
            predicted_target_errors.append(
                abs(float(projection["predicted_target_error_rad_s"]))
            )

        local_writes = int(application["body_impulse_write_count"])
        exact(local_writes, int(population["nonzero_body_impulse_count"]), "JOINT_SPACE_WRITES")
        exact(int(application["host_write_count"]), local_writes, "JOINT_SPACE_HOST_WRITES")
        exact(
            sum(int(value["body_impulse_write_count"]) for value in body_receipts),
            local_writes,
            "JOINT_SPACE_BODY_WRITES",
        )
        require(
            all(
                bool(value["call_performed"]) == bool(value["call_returned"])
                for value in body_receipts
            ),
            "JOINT_SPACE_BODY_CALLS",
        )
        exact(
            int(application["native_angular_velocity_total_readback_count"]),
            2 * len(body_ids),
            "JOINT_SPACE_READBACKS",
        )
        zero_hold = bool(population["representation_zero_hold"])
        exact(zero_hold, local_writes == 0, "JOINT_SPACE_ZERO_HOLD")
        if zero_hold:
            exact(joint_scale, 0.0, "JOINT_SPACE_HELD_SCALE")

        steps.append(int(application["semantic_step"]))
        joint_scales.append(joint_scale)
        body_scales.append(body_scale)
        cap_scales.append(cap_scale)
        pivots.append(min(local_pivots))
        solve_residuals.append(abs(float(population["maximum_solve_residual_rad_s"])))
        symmetry_residuals.append(
            abs(float(population["response_matrix_symmetry_maximum_absolute_residual"]))
        )
        body_writes[local_writes] += 1
        solver_guards += int(bool(population["solver_guard_engaged"]))
        zero_holds += int(zero_hold)
        refinements += int(population["representation_refinement_count"])
        crossings += int(population["joint_target_crossing_count"])
        write_count += local_writes
        readback_count += int(application["native_angular_velocity_total_readback_count"])

    return {
        **empty,
        **identity,
        "application_count": len(rows),
        "ordered_actuator_ids": list(actuator_ids),
        "ordered_body_ids": list(body_ids),
        "first_application_step": min(steps),
        "last_application_step": max(steps),
        "positive_joint_space_common_scale_count": sum(
            value > 0.0 for value in joint_scales
        ),
        "zero_joint_space_common_scale_count": sum(
            value == 0.0 for value in joint_scales
        ),
        "minimum_joint_space_common_pre_scale": min(joint_scales),
        "maximum_joint_space_common_pre_scale": max(joint_scales),
        "minimum_body_guard_common_applied_scale": min(body_scales),
        "maximum_body_guard_common_applied_scale": max(body_scales),
        "minimum_cap_common_scale": min(cap_scales),
        "maximum_cap_common_scale": max(cap_scales),
        "solver_guard_engagement_count": solver_guards,
        "representation_zero_hold_count": zero_holds,
        "representation_refinement_count": refinements,
        "joint_target_crossing_count": crossings,
        "minimum_cholesky_pivot": min(pivots),
        "maximum_solve_residual_rad_s": max(solve_residuals),
        "maximum_response_matrix_symmetry_residual": max(symmetry_residuals),
        "maximum_source_reconstruction_residual_rad_s": max(
            reconstruction_residuals
        ),
        "maximum_predicted_target_error_rad_s": max(predicted_target_errors),
        "total_body_impulse_write_count": write_count,
        "body_impulse_write_histogram": {
            str(key): value for key, value in sorted(body_writes.items())
        },
        "total_native_readback_count": readback_count,
        "nonzero_applied_impulse_steps_by_actuator": {
            actuator_id: nonzero_steps[actuator_id] for actuator_id in actuator_ids
        },
        "saturated_impulse_steps_by_actuator": {
            actuator_id: saturated_steps[actuator_id] for actuator_id in actuator_ids
        },
    }


def _validate_source(
    root: Path,
    closure: dict[str, Any],
    contract_relative_path: str,
) -> dict[str, Any]:
    source = closure["source"]
    commit = str(source["commit"])
    freeze = str(source["qualification_source_commit"])
    verify_retained_commit(root, commit, str(source["parent_commit"]))
    exact(git(root, "show", "-s", "--format=%T", commit), source["tree"], "TREE")
    exact(
        git(root, "show", "-s", "--format=%s", commit),
        source["subject"],
        "SUBJECT",
    )
    verify_exact_paths(
        source,
        {
            "branch": "main",
            "remote": "https://github.com/Slagathore/sporespore.git",
            "upstream_equal_at_physical_start": True,
            "live_remote_equal_at_physical_start": True,
            "worktree_clean_at_physical_start": True,
            "qualified_physical_source_drift_count_at_physical_start": 0,
        },
        "SOURCE",
    )
    require(
        subprocess.run(
            ["git", "merge-base", "--is-ancestor", freeze, commit],
            cwd=root,
            check=False,
        ).returncode
        == 0,
        "QUALIFICATION_NOT_ANCESTOR",
    )
    authority = closure["qualification_authority"]
    authority_raw = source_bytes(root, commit, str(authority["path"]))
    exact(
        (len(authority_raw), "sha256:" + hashlib.sha256(authority_raw).hexdigest()),
        (
            authority["byte_length_at_physical_start"],
            authority["raw_sha256_at_physical_start"],
        ),
        "QUALIFICATION_AUTHORITY",
    )
    qualification = json.loads(authority_raw)
    exact(qualification["gate_id"], closure["gate_id"], "QUALIFICATION_GATE")
    contract = json.loads(
        source_bytes(
            root,
            freeze,
            contract_relative_path,
        )
    )
    exact(contract["gate_id"], closure["gate_id"], "CONTRACT_GATE")
    qualified_paths = tuple(str(path) for path in contract["qualified_physical_paths"])
    exact(len(qualified_paths), source["qualified_physical_path_count"], "PATH_COUNT")
    require(
        subprocess.run(
            ["git", "diff", "--quiet", freeze, commit, "--", *qualified_paths],
            cwd=root,
            check=False,
        ).returncode
        == 0,
        "QUALIFIED_PHYSICAL_SOURCE_DRIFT",
    )
    return qualification


def _validate_live_authority(
    root: Path,
    closure: dict[str, Any],
    closure_relative_path: str,
    closure_raw: bytes,
    live_record_key: str,
    live_identity_prefix: str,
    ignored_forward_live_keys: tuple[str, ...],
) -> None:
    expected = dict(closure["live_authority_projection"])
    # A consumed result may name forward-moving successor state. Ignore only
    # keys explicitly bound by the thin historical audit so later valid
    # diagnosis does not turn immutable evidence red.
    for key in ignored_forward_live_keys:
        expected.pop(key, None)
    expected.update(
        {
            f"{live_identity_prefix}_path": closure_relative_path,
            f"{live_identity_prefix}_raw_sha256": (
                "sha256:" + hashlib.sha256(closure_raw).hexdigest()
            ),
            f"{live_identity_prefix}_byte_length": len(closure_raw),
        }
    )
    verify_legacy_live_authority_projection(
        root,
        tuple(str(path) for path in closure["live_authority_paths"]),
        record_key=live_record_key,
        expected=expected,
        prefix=f"LIVE_{closure['gate_id'].replace('-', '_')}_PHYSICAL",
    )


def validate_closure(
    root: Path,
    closure_relative_path: str,
    closure_schema: str,
    gate_id: str,
    expected_raw_sha256: str,
    expected_byte_length: int,
    *,
    contract_relative_path: str,
    actuation_projection_mode: str,
    live_record_key: str,
    live_identity_prefix: str,
    ignored_forward_live_keys: tuple[str, ...],
    next_gate_id: str,
    expected_scientific_outcome: str,
    expected_sdk1_milestone_advanced: bool,
) -> dict[str, Any]:
    closure_path = root / closure_relative_path
    closure_raw = closure_path.read_bytes()
    exact(
        (len(closure_raw), "sha256:" + hashlib.sha256(closure_raw).hexdigest()),
        (expected_byte_length, expected_raw_sha256),
        "CLOSURE_IDENTITY",
    )
    closure = json.loads(closure_raw)
    verify_exact_paths(
        closure,
        {
            "schema_version": closure_schema,
            "gate_id": gate_id,
            "question_class": "development",
            "physical_question_declared": True,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
        },
        "CLOSURE",
    )
    _validate_source(root, closure, contract_relative_path)
    physical = closure["physical_attempt"]
    retained = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id=gate_id,
        source_commit=str(closure["source"]["commit"]),
        status="valid_complete_behavior_development",
        schemas=physical["schemas"],
        raw_count_keys=(
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
            "behavior_evaluator_invocation_count",
            "held_out_cell_access_count",
        ),
    )
    raw = retained["raw"]
    if "worker_progress_marker_count" in physical:
        verify_exact_paths(
            retained["terminal"],
            {
                "worker.progress_marker_count": physical[
                    "worker_progress_marker_count"
                ],
                "worker.progress_binding_valid": physical[
                    "worker_progress_binding_valid"
                ],
            },
            "PROGRESS_OBSERVABILITY",
        )
    exact(
        raw["scientific_outcome"],
        expected_scientific_outcome,
        "SCIENTIFIC_OUTCOME",
    )
    verify_exact_paths(raw, closure["observed_behavior"]["raw_exact"], "RAW")
    exact(
        raw["arm_execution_summary"]["ordered_arm_summaries"],
        closure["observed_behavior"]["arm_summaries"],
        "ARM_SUMMARIES",
    )
    projection = {
        "candidate": _trajectory_projection(raw["candidate_arm"]),
        "matched_zero": _trajectory_projection(raw["matched_zero_arm"]),
    }
    candidate_transport = projection["candidate"].get(
        "contiguous_boundary_transport"
    )
    matched_zero_transport = projection["matched_zero"].get(
        "contiguous_boundary_transport"
    )
    require(
        (candidate_transport is None) == (matched_zero_transport is None),
        "BOUNDARY_TRANSPORT_ARM_POPULATION",
    )
    require(
        gate_id != "QSDK-R24D170"
        or (candidate_transport is not None and matched_zero_transport is not None),
        "R24D170_BOUNDARY_TRANSPORT_REQUIRED",
    )
    if candidate_transport is not None and matched_zero_transport is not None:
        verify_exact_paths(
            raw,
            {
                "contiguous_boundary_transport_profile_selected": True,
                "contiguous_boundary_transport_design_id": (
                    _CONTIGUOUS_BOUNDARY_TRANSPORT_DESIGN_ID
                ),
                "contiguous_boundary_transport_profile_id": (
                    _CONTIGUOUS_BOUNDARY_TRANSPORT_PROFILE_ID
                ),
                "boundary_transport_state_schema_version": (
                    _CONTIGUOUS_BOUNDARY_TRANSPORT_STATE_SCHEMA
                ),
                "boundary_transport_pair_schema_version": (
                    _CONTIGUOUS_BOUNDARY_TRANSPORT_PAIR_SCHEMA
                ),
                "legacy_aliased_boundary_transport_selected": False,
                "boundary_transport_initializer_native_readback_count": 18,
                "boundary_transport_completed_boundary_count": raw[
                    "solver_step_count"
                ],
                "boundary_transport_cache_advance_commit_count": raw[
                    "solver_step_count"
                ],
                "candidate_boundary_transport_terminal_cached_sequence": (
                    candidate_transport["terminal_cached_boundary_sequence"]
                ),
                "candidate_boundary_transport_terminal_accepted_pair_count": (
                    candidate_transport["terminal_accepted_pair_count"]
                ),
                "candidate_boundary_transport_terminal_state_revision": (
                    candidate_transport["terminal_state_revision"]
                ),
                "matched_zero_boundary_transport_terminal_cached_sequence": (
                    matched_zero_transport["terminal_cached_boundary_sequence"]
                ),
                "matched_zero_boundary_transport_terminal_accepted_pair_count": (
                    matched_zero_transport["terminal_accepted_pair_count"]
                ),
                "matched_zero_boundary_transport_terminal_state_revision": (
                    matched_zero_transport["terminal_state_revision"]
                ),
            },
            "BOUNDARY_TRANSPORT_RAW",
        )
        projection["contiguous_boundary_transport_pair"] = {
            "initializer_native_readback_count": 18,
            "completed_boundary_count": raw["solver_step_count"],
            "cache_advance_commit_count": raw["solver_step_count"],
        }
    if actuation_projection_mode == "refinement_safe_guard_v1":
        projection["candidate"]["refinement_safe_guard"] = _guard_projection(
            raw["candidate_arm"]
        )
    elif actuation_projection_mode == "order_neutral_population_v1":
        candidate_population = _order_neutral_population_projection(
            raw["candidate_arm"]
        )
        matched_zero_population = _order_neutral_population_projection(
            raw["matched_zero_arm"]
        )
        require(
            int(candidate_population["application_count"]) > 0,
            "ORDER_NEUTRAL_CANDIDATE_APPLICATIONS",
        )
        exact(
            matched_zero_population["application_count"],
            0,
            "ORDER_NEUTRAL_MATCHED_ZERO_APPLICATIONS",
        )
        projection["candidate"]["order_neutral_population"] = candidate_population
        projection["matched_zero"]["order_neutral_population"] = (
            matched_zero_population
        )
    elif actuation_projection_mode == "joint_target_monotone_population_v1":
        candidate_population = _joint_target_monotone_population_projection(
            raw["candidate_arm"]
        )
        matched_zero_population = _joint_target_monotone_population_projection(
            raw["matched_zero_arm"]
        )
        require(
            int(candidate_population["application_count"]) > 0,
            "TARGET_MONOTONE_CANDIDATE_APPLICATIONS",
        )
        exact(
            matched_zero_population["application_count"],
            0,
            "TARGET_MONOTONE_MATCHED_ZERO_APPLICATIONS",
        )
        projection["candidate"]["joint_target_monotone_population"] = (
            candidate_population
        )
        projection["matched_zero"]["joint_target_monotone_population"] = (
            matched_zero_population
        )
    elif actuation_projection_mode == "joint_space_effective_inertia_population_v1":
        candidate_population = _joint_space_effective_inertia_population_projection(
            raw["candidate_arm"]
        )
        matched_zero_population = (
            _joint_space_effective_inertia_population_projection(
                raw["matched_zero_arm"]
            )
        )
        require(
            int(candidate_population["application_count"]) > 0,
            "JOINT_SPACE_CANDIDATE_APPLICATIONS",
        )
        exact(
            matched_zero_population["application_count"],
            0,
            "JOINT_SPACE_MATCHED_ZERO_APPLICATIONS",
        )
        projection["candidate"]["joint_space_effective_inertia_population"] = (
            candidate_population
        )
        projection["matched_zero"][
            "joint_space_effective_inertia_population"
        ] = matched_zero_population
    elif actuation_projection_mode == "solver_coupled_constraint_motor_v1":
        candidate_population = _solver_coupled_constraint_motor_projection(
            raw["candidate_arm"]
        )
        matched_zero_population = _solver_coupled_constraint_motor_projection(
            raw["matched_zero_arm"]
        )
        require(
            int(
                candidate_population[
                    "active_constraint_configuration_application_count"
                ]
            )
            > 0,
            "SOLVER_COUPLED_CANDIDATE_APPLICATIONS",
        )
        exact(
            matched_zero_population[
                "active_constraint_configuration_application_count"
            ],
            0,
            "SOLVER_COUPLED_MATCHED_ZERO_APPLICATIONS",
        )
        exact(
            candidate_population["application_mutation_semantics_ids"],
            matched_zero_population["application_mutation_semantics_ids"],
            "SOLVER_COUPLED_ARM_SEMANTICS",
        )
        projection["candidate"]["solver_coupled_constraint_motor"] = (
            candidate_population
        )
        projection["matched_zero"]["solver_coupled_constraint_motor"] = (
            matched_zero_population
        )
    else:
        raise ClosureAuditError(
            f"ACTUATION_PROJECTION_MODE:{actuation_projection_mode}"
        )
    exact(
        projection,
        closure["observed_behavior"]["computed_projection"],
        "BEHAVIOR_PROJECTION",
    )
    verify_exact_paths(
        closure,
        {
            "decision.behavior_attempt_consumed_for_exact_source": True,
            "decision.same_identity_rerun_permitted": False,
            "decision.physical_execution_authorized": False,
            "decision.valid_complete_behavior_result": True,
            "decision.behavior_negative_accepted_for_finite_development_inference": (
                expected_scientific_outcome == "negative"
            ),
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": expected_sdk1_milestone_advanced,
            "claim_boundary.valid_complete_behavior_result": True,
            "claim_boundary.scientific_behavior_negative": (
                expected_scientific_outcome == "negative"
            ),
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.repeatability_claimed": False,
            "claim_boundary.population_claimed": False,
            "claim_boundary.cross_engine_recovery_claimed": False,
            "claim_boundary.cross_engine_equivalence_claimed": False,
            "claim_boundary.sdk1_milestone_advanced": (
                expected_sdk1_milestone_advanced
            ),
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
            "next_boundary.gate_id": next_gate_id,
            "next_boundary.physical_question_declared": False,
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_build_count": 0,
            "next_boundary.maximum_physical_steps_authorized": 0,
        },
        "DECISION",
    )
    _validate_live_authority(
        root,
        closure,
        closure_relative_path,
        closure_raw,
        live_record_key,
        live_identity_prefix,
        ignored_forward_live_keys,
    )
    require((root / str(closure["closure_audit_path"])).is_file(), "AUDIT_PATH")
    return closure


def run_cli(
    root: Path,
    closure_relative_path: str,
    closure_schema: str,
    gate_id: str,
    expected_raw_sha256: str,
    expected_byte_length: int,
    pass_marker: str,
    failure_marker: str,
    *,
    contract_relative_path: str = (
        "sdk/recovery/"
        "r24d101_godot_jolt_refinement_safe_recovery_behavior_contract_v1.json"
    ),
    actuation_projection_mode: str = "refinement_safe_guard_v1",
    live_record_key: str = "r24d101_contract_path",
    live_identity_prefix: str = "r24d101_physical_closure",
    ignored_forward_live_keys: tuple[str, ...] = (
        "r24d102_zero_world_trajectory_diagnosis_required",
    ),
    next_gate_id: str = "QSDK-R24D102",
    expected_scientific_outcome: str = "negative",
    expected_sdk1_milestone_advanced: bool = False,
) -> int:
    try:
        closure = validate_closure(
            root,
            closure_relative_path,
            closure_schema,
            gate_id,
            expected_raw_sha256,
            expected_byte_length,
            contract_relative_path=contract_relative_path,
            actuation_projection_mode=actuation_projection_mode,
            live_record_key=live_record_key,
            live_identity_prefix=live_identity_prefix,
            ignored_forward_live_keys=ignored_forward_live_keys,
            next_gate_id=next_gate_id,
            expected_scientific_outcome=expected_scientific_outcome,
            expected_sdk1_milestone_advanced=expected_sdk1_milestone_advanced,
        )
        physical = closure["physical_attempt"]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": gate_id,
                    "ok": True,
                    "status": physical["status"],
                    "scientific_outcome": physical["scientific_outcome"],
                    "model_construction_count": physical[
                        "model_construction_count"
                    ],
                    "world_build_count": physical["world_build_count"],
                    "solver_step_count": physical["solver_step_count"],
                    "in_run_invariant_receipt_count": closure["observed_behavior"][
                        "raw_exact"
                    ]["in_run_invariant_receipt_count"],
                    "prone_to_standing_claimed": closure["claim_boundary"][
                        "prone_to_standing_claimed"
                    ],
                    "sdk1_milestone_advanced": closure["claim_boundary"][
                        "sdk1_milestone_advanced"
                    ],
                },
                sort_keys=True,
            ),
        )
        return 0
    except (
        ClosureAuditError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(f"{failure_marker}:{error}", file=sys.stderr)
        return 1
