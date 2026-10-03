#!/usr/bin/env python3
"""Reusable retained-trace extension for the shared zero-world audit."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any, Callable

from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    canonical_bytes,
    exact,
    verify_exact_paths,
)
from sdk.conformance.finite_recovery_load_path_diagnosis import (
    validate_bound_zero_world_engineering_diagnosis,
)
from sdk.conformance.finite_recovery_trace_diagnosis import (
    _load_bound_physical_raw,
)
from sdk.conformance.retained_energy_trace_diagnosis import (
    RetainedEnergyTraceError,
    godot_complete_energy_handoff_diagnosis_v1,
    godot_discrete_staging_successor_diagnosis_v1,
    godot_rotation_aware_successor_diagnosis_v1,
    godot_v3_zero_control_gravity_staging_projection_v1,
)


def _expect_error(expected: str, call: Callable[[], object]) -> None:
    caught: RetainedEnergyTraceError | None = None
    try:
        call()
    except RetainedEnergyTraceError as error:
        caught = error
    exact(str(caught), expected, f"MUTATION:{expected}")


def _mutation_controls(
    development_raw: dict[str, Any],
    complete_raw: dict[str, Any],
    *,
    threshold: float,
    mass: float,
    window: int,
) -> None:
    zero = complete_raw["matched_zero_arm"]
    _expect_error(
        "GODOT_V3_GRAVITY_STAGING_MASS",
        lambda: godot_v3_zero_control_gravity_staging_projection_v1(
            zero, total_dynamic_mass_kg=0.0, terminal_window_outer_steps=window
        ),
    )
    _expect_error(
        "GODOT_V3_GRAVITY_STAGING_WINDOW",
        lambda: godot_v3_zero_control_gravity_staging_projection_v1(
            zero, total_dynamic_mass_kg=mass, terminal_window_outer_steps=0
        ),
    )

    wrong_pair = dict(complete_raw)
    wrong_pair["seed_sha256"] = "sha256:" + "0" * 64
    _expect_error(
        "GODOT_HANDOFF_PAIRED_ROOT:seed_sha256",
        lambda: godot_complete_energy_handoff_diagnosis_v1(
            development_raw,
            wrong_pair,
            maximum_energy_balance_residual_j=threshold,
            total_dynamic_mass_kg=mass,
            terminal_window_outer_steps=window,
        ),
    )

    wrong_zero = dict(zero)
    applications = list(zero["command_application_receipts"])
    applications[0] = dict(applications[0])
    applications[0]["no_actuation_requested"] = False
    wrong_zero["command_application_receipts"] = applications
    _expect_error(
        "GODOT_V3_GRAVITY_STAGING_ZERO_CONTROL:0",
        lambda: godot_v3_zero_control_gravity_staging_projection_v1(
            wrong_zero,
            total_dynamic_mass_kg=mass,
            terminal_window_outer_steps=window,
        ),
    )


def validate_complete_energy_handoff_diagnosis(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    **scope: Any,
) -> dict[str, Any]:
    """Extend the common audit only with R147's retained-trace question."""

    diagnosis = validate_bound_zero_world_engineering_diagnosis(
        root,
        relative_path,
        schema,
        expected_sha256,
        expected_length,
        **scope,
    )

    authorities = {
        str(binding["role"]): binding
        for binding in diagnosis["bound_json_authorities"]
    }
    threshold_binding = authorities["threshold_contract"]
    threshold_contract = json.loads(
        (root / str(threshold_binding["path"])).read_bytes()
    )
    thresholds = {
        value["threshold_id"]: value["value"]
        for value in threshold_contract["threshold_profile"]["thresholds"]
    }
    threshold = float(thresholds["maximum_energy_balance_residual_j"])
    mass = float(
        threshold_contract["geometry_and_weight_provenance"]["total_mass_kg"]
    )
    exact(
        threshold,
        float(diagnosis["method"]["maximum_energy_balance_residual_j"]),
        "THRESHOLD",
    )
    exact(mass, float(diagnosis["method"]["total_dynamic_mass_kg"]), "MASS")

    development_raw = _load_bound_physical_raw(
        root, diagnosis["predecessors"]["r24d134"], "R134"
    )
    complete_raw = _load_bound_physical_raw(
        root, diagnosis["predecessors"]["r24d146"], "R146"
    )
    window = int(diagnosis["method"]["terminal_zero_control_window_outer_steps"])
    projection = godot_complete_energy_handoff_diagnosis_v1(
        development_raw,
        complete_raw,
        maximum_energy_balance_residual_j=threshold,
        total_dynamic_mass_kg=mass,
        terminal_window_outer_steps=window,
    )
    encoded = canonical_bytes(projection)
    exact(
        (len(encoded), "sha256:" + hashlib.sha256(encoded).hexdigest()),
        (
            int(diagnosis["computed_projection_canonical_byte_length"]),
            str(diagnosis["computed_projection_canonical_sha256"]),
        ),
        "ENERGY_HANDOFF_PROJECTION_IDENTITY",
    )
    exact(projection, diagnosis["computed_projection"], "ENERGY_HANDOFF_PROJECTION")
    _mutation_controls(
        development_raw,
        complete_raw,
        threshold=threshold,
        mass=mass,
        window=window,
    )

    verify_exact_paths(
        diagnosis,
        {
            "method.mutation_control_count": 4,
            "decision.r24d134_same_identity_rerun_permitted": False,
            "decision.r24d146_same_identity_rerun_permitted": False,
            "decision.r24d144_zero_world_qualification_rewritten": False,
            "decision.controller_change_selected": False,
            "decision.threshold_change_selected": False,
            "claim_boundary.corrected_discrete_staging_observer_claimed": False,
        },
        "ENERGY_HANDOFF_EXTENSION",
    )
    return diagnosis


def run_complete_energy_handoff_diagnosis_cli(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    pass_marker: str,
    failure_marker: str,
    **scope: Any,
) -> int:
    try:
        diagnosis = validate_complete_energy_handoff_diagnosis(
            root,
            relative_path,
            schema,
            expected_sha256,
            expected_length,
            **scope,
        )
        projection = diagnosis["computed_projection"]
        comparison = projection["controlled_comparison"]
        gate = projection["complete_energy_gate"]
        staging = projection["matched_zero_gravity_staging_projection"]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": diagnosis["gate_id"],
                    "ok": True,
                    "status": diagnosis["status"],
                    "physical_equal_prefix_steps": comparison[
                        "physical_projection_equal_prefix_step_count"
                    ],
                    "first_progression_divergence_step": comparison[
                        "first_progression_decision_divergence_semantic_step"
                    ],
                    "first_energy_failure_step": gate[
                        "first_energy_residual_failure_semantic_step"
                    ],
                    "raised_energy_pass_count": gate[
                        "raised_body_component_pass_counts"
                    ]["energy_residual_respected"],
                    "terminal_gravity_projection_fraction": staging["terminal"][
                        "residual_growth_fraction_of_projection"
                    ],
                    "mutation_control_count": 4,
                    "model_construction_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "prone_to_standing_claimed": False,
                    "sdk1_milestone_advanced": False,
                },
                sort_keys=True,
            ),
        )
        return 0
    except (
        ClosureAuditError,
        RetainedEnergyTraceError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(f"{failure_marker}:{error}", file=sys.stderr)
        return 1


def _replace_arm_row(
    raw: dict[str, Any],
    arm_name: str,
    collection_name: str,
    index: int,
    row: dict[str, Any],
) -> dict[str, Any]:
    """Copy only the containers needed by one deterministic mutation."""

    mutated = dict(raw)
    arm = dict(raw[arm_name])
    collection = list(arm[collection_name])
    collection[index] = row
    arm[collection_name] = collection
    mutated[arm_name] = arm
    return mutated


def _staging_successor_mutation_controls(
    predecessor_raw: dict[str, Any],
    successor_raw: dict[str, Any],
    *,
    threshold: float,
) -> None:
    wrong_root = dict(successor_raw)
    wrong_root["seed_sha256"] = "sha256:" + "0" * 64
    _expect_error(
        "GODOT_STAGING_SUCCESSOR_PAIRED_ROOT:seed_sha256",
        lambda: godot_discrete_staging_successor_diagnosis_v1(
            predecessor_raw,
            wrong_root,
            maximum_energy_balance_residual_j=threshold,
        ),
    )

    successor_observation = successor_raw["candidate_arm"]["trace_v3"][
        "observations"
    ][0]
    wrong_observation = dict(successor_observation)
    wrong_state = dict(successor_observation["state"])
    wrong_state["sample_time_s"] = float(wrong_state["sample_time_s"]) + 1.0
    wrong_observation["state"] = wrong_state
    wrong_physics = dict(successor_raw)
    wrong_arm = dict(successor_raw["candidate_arm"])
    wrong_trace = dict(wrong_arm["trace_v3"])
    wrong_observations = list(wrong_trace["observations"])
    wrong_observations[0] = wrong_observation
    wrong_trace["observations"] = wrong_observations
    wrong_arm["trace_v3"] = wrong_trace
    wrong_physics["candidate_arm"] = wrong_arm
    _expect_error(
        "GODOT_STAGING_SUCCESSOR_PHYSICAL_IDENTITY:candidate_arm:1",
        lambda: godot_discrete_staging_successor_diagnosis_v1(
            predecessor_raw,
            wrong_physics,
            maximum_energy_balance_residual_j=threshold,
        ),
    )

    wrong_observation = dict(successor_observation)
    wrong_energy = dict(successor_observation["energy_balance"])
    wrong_energy["current_mechanical_energy_j"] = (
        float(wrong_energy["current_mechanical_energy_j"]) + 1.0
    )
    wrong_observation["energy_balance"] = wrong_energy
    wrong_ledger = dict(successor_raw)
    wrong_arm = dict(successor_raw["candidate_arm"])
    wrong_trace = dict(wrong_arm["trace_v3"])
    wrong_observations = list(wrong_trace["observations"])
    wrong_observations[0] = wrong_observation
    wrong_trace["observations"] = wrong_observations
    wrong_arm["trace_v3"] = wrong_trace
    wrong_ledger["candidate_arm"] = wrong_arm
    _expect_error(
        "GODOT_STAGING_SUCCESSOR_NONSTAGING_LEDGER_IDENTITY:candidate_arm:1",
        lambda: godot_discrete_staging_successor_diagnosis_v1(
            predecessor_raw,
            wrong_ledger,
            maximum_energy_balance_residual_j=threshold,
        ),
    )

    zero_application = dict(
        successor_raw["matched_zero_arm"]["command_application_receipts"][0]
    )
    zero_application["no_actuation_requested"] = False
    wrong_zero = _replace_arm_row(
        successor_raw,
        "matched_zero_arm",
        "command_application_receipts",
        0,
        zero_application,
    )
    _expect_error(
        "GODOT_STAGING_SUCCESSOR_MATCHED_ZERO_CONTROL",
        lambda: godot_discrete_staging_successor_diagnosis_v1(
            predecessor_raw,
            wrong_zero,
            maximum_energy_balance_residual_j=threshold,
        ),
    )


def validate_discrete_staging_successor_diagnosis(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    **scope: Any,
) -> dict[str, Any]:
    """Extend the common zero-world audit with an exact staging handoff."""

    diagnosis = validate_bound_zero_world_engineering_diagnosis(
        root,
        relative_path,
        schema,
        expected_sha256,
        expected_length,
        **scope,
    )
    authorities = {
        str(binding["role"]): binding
        for binding in diagnosis["bound_json_authorities"]
    }
    threshold_contract = json.loads(
        (root / str(authorities["threshold_contract"]["path"])).read_bytes()
    )
    threshold = float(
        {
            value["threshold_id"]: value["value"]
            for value in threshold_contract["threshold_profile"]["thresholds"]
        }["maximum_energy_balance_residual_j"]
    )
    exact(
        threshold,
        float(diagnosis["method"]["maximum_energy_balance_residual_j"]),
        "STAGING_SUCCESSOR_THRESHOLD",
    )
    predecessor_raw = _load_bound_physical_raw(
        root, diagnosis["predecessors"]["r24d146"], "R146"
    )
    successor_raw = _load_bound_physical_raw(
        root, diagnosis["predecessors"]["r24d154"], "R154"
    )
    projection = godot_discrete_staging_successor_diagnosis_v1(
        predecessor_raw,
        successor_raw,
        maximum_energy_balance_residual_j=threshold,
    )
    encoded = canonical_bytes(projection)
    exact(
        (len(encoded), "sha256:" + hashlib.sha256(encoded).hexdigest()),
        (
            int(diagnosis["computed_projection_canonical_byte_length"]),
            str(diagnosis["computed_projection_canonical_sha256"]),
        ),
        "STAGING_SUCCESSOR_PROJECTION_IDENTITY",
    )
    exact(projection, diagnosis["computed_projection"], "STAGING_SUCCESSOR_PROJECTION")
    _staging_successor_mutation_controls(
        predecessor_raw,
        successor_raw,
        threshold=threshold,
    )
    verify_exact_paths(
        diagnosis,
        {
            "method.mutation_control_count": 4,
            "interpretation.rotational_position_integration_observer_gap_established": True,
            "interpretation.rotational_staging_cause_established": False,
            "decision.r24d146_same_identity_rerun_permitted": False,
            "decision.r24d154_same_identity_rerun_permitted": False,
            "decision.controller_change_selected": False,
            "decision.threshold_change_selected": False,
            "claim_boundary.rotational_staging_cause_established": False,
        },
        "STAGING_SUCCESSOR_EXTENSION",
    )
    return diagnosis


def run_discrete_staging_successor_diagnosis_cli(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    pass_marker: str,
    failure_marker: str,
    **scope: Any,
) -> int:
    try:
        diagnosis = validate_discrete_staging_successor_diagnosis(
            root,
            relative_path,
            schema,
            expected_sha256,
            expected_length,
            **scope,
        )
        projection = diagnosis["computed_projection"]
        arms = projection["paired_route_identity"]["arms"]
        branch = projection["successor_branch_localization"]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": diagnosis["gate_id"],
                    "ok": True,
                    "status": diagnosis["status"],
                    "candidate_physical_identity_steps": arms["candidate_arm"][
                        "physical_projection_equal_step_count"
                    ],
                    "matched_zero_physical_identity_steps": arms["matched_zero_arm"][
                        "physical_projection_equal_step_count"
                    ],
                    "first_candidate_actuation_step": branch[
                        "first_candidate_actuation_semantic_step"
                    ],
                    "candidate_raised_energy_pass_steps": branch[
                        "candidate_raised_body_energy_residual_pass_step_count"
                    ],
                    "mutation_control_count": 4,
                    "model_construction_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "prone_to_standing_claimed": False,
                    "sdk1_milestone_advanced": False,
                },
                sort_keys=True,
            ),
        )
        return 0
    except (
        ClosureAuditError,
        RetainedEnergyTraceError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(f"{failure_marker}:{error}", file=sys.stderr)
        return 1


def _rotation_successor_mutation_controls(
    predecessor_raw: dict[str, Any],
    successor_raw: dict[str, Any],
    *,
    threshold: float,
) -> None:
    """Prove the retained comparison refuses crossed or altered inputs."""

    wrong_root = dict(successor_raw)
    wrong_root["seed_sha256"] = "sha256:" + "0" * 64
    _expect_error(
        "GODOT_ROTATION_SUCCESSOR_PAIRED_ROOT:seed_sha256",
        lambda: godot_rotation_aware_successor_diagnosis_v1(
            predecessor_raw,
            wrong_root,
            maximum_energy_balance_residual_j=threshold,
        ),
    )

    successor_observation = successor_raw["candidate_arm"]["trace_v3"][
        "observations"
    ][0]
    wrong_observation = dict(successor_observation)
    wrong_state = dict(successor_observation["state"])
    wrong_state["sample_time_s"] = float(wrong_state["sample_time_s"]) + 1.0
    wrong_observation["state"] = wrong_state
    wrong_physics = dict(successor_raw)
    wrong_arm = dict(successor_raw["candidate_arm"])
    wrong_trace = dict(wrong_arm["trace_v3"])
    wrong_observations = list(wrong_trace["observations"])
    wrong_observations[0] = wrong_observation
    wrong_trace["observations"] = wrong_observations
    wrong_arm["trace_v3"] = wrong_trace
    wrong_physics["candidate_arm"] = wrong_arm
    _expect_error(
        "GODOT_ROTATION_SUCCESSOR_PHYSICAL_IDENTITY:candidate_arm:1",
        lambda: godot_rotation_aware_successor_diagnosis_v1(
            predecessor_raw,
            wrong_physics,
            maximum_energy_balance_residual_j=threshold,
        ),
    )

    wrong_observation = dict(successor_observation)
    wrong_energy = dict(successor_observation["energy_balance"])
    wrong_energy["cumulative_signed_discrete_staging_exchange_j"] = (
        float(wrong_energy["cumulative_signed_discrete_staging_exchange_j"]) + 1.0
    )
    wrong_observation["energy_balance"] = wrong_energy
    wrong_ledger = dict(successor_raw)
    wrong_arm = dict(successor_raw["candidate_arm"])
    wrong_trace = dict(wrong_arm["trace_v3"])
    wrong_observations = list(wrong_trace["observations"])
    wrong_observations[0] = wrong_observation
    wrong_trace["observations"] = wrong_observations
    wrong_arm["trace_v3"] = wrong_trace
    wrong_ledger["candidate_arm"] = wrong_arm
    _expect_error(
        "GODOT_ROTATION_SUCCESSOR_NONROTATION_LEDGER_IDENTITY:candidate_arm:1",
        lambda: godot_rotation_aware_successor_diagnosis_v1(
            predecessor_raw,
            wrong_ledger,
            maximum_energy_balance_residual_j=threshold,
        ),
    )

    wrong_step = dict(successor_raw["candidate_arm"]["portable_step_receipts"][0])
    wrong_step["next_phase"] = "failed"
    wrong_progression = _replace_arm_row(
        successor_raw,
        "candidate_arm",
        "portable_step_receipts",
        0,
        wrong_step,
    )
    _expect_error(
        "GODOT_ROTATION_SUCCESSOR_PHASE_PROGRESSION_IDENTITY:candidate_arm:1",
        lambda: godot_rotation_aware_successor_diagnosis_v1(
            predecessor_raw,
            wrong_progression,
            maximum_energy_balance_residual_j=threshold,
        ),
    )


def validate_rotation_boundary_alignment_diagnosis(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    **scope: Any,
) -> dict[str, Any]:
    """Audit R166's retained comparison and source-timing localization."""

    diagnosis = validate_bound_zero_world_engineering_diagnosis(
        root,
        relative_path,
        schema,
        expected_sha256,
        expected_length,
        **scope,
    )
    authorities = {
        str(binding["role"]): binding
        for binding in diagnosis["bound_json_authorities"]
    }
    threshold_contract = json.loads(
        (root / str(authorities["threshold_contract"]["path"])).read_bytes()
    )
    threshold = float(
        {
            value["threshold_id"]: value["value"]
            for value in threshold_contract["threshold_profile"]["thresholds"]
        }["maximum_energy_balance_residual_j"]
    )
    exact(
        threshold,
        float(diagnosis["method"]["maximum_energy_balance_residual_j"]),
        "ROTATION_BOUNDARY_THRESHOLD",
    )
    predecessor_raw = _load_bound_physical_raw(
        root, diagnosis["predecessors"]["r24d154"], "R154"
    )
    successor_raw = _load_bound_physical_raw(
        root, diagnosis["predecessors"]["r24d165"], "R165"
    )
    projection = godot_rotation_aware_successor_diagnosis_v1(
        predecessor_raw,
        successor_raw,
        maximum_energy_balance_residual_j=threshold,
    )
    encoded = canonical_bytes(projection)
    exact(
        (len(encoded), "sha256:" + hashlib.sha256(encoded).hexdigest()),
        (
            int(diagnosis["computed_projection_canonical_byte_length"]),
            str(diagnosis["computed_projection_canonical_sha256"]),
        ),
        "ROTATION_BOUNDARY_PROJECTION_IDENTITY",
    )
    exact(projection, diagnosis["computed_projection"], "ROTATION_BOUNDARY_PROJECTION")
    _rotation_successor_mutation_controls(
        predecessor_raw,
        successor_raw,
        threshold=threshold,
    )

    r7_binding = authorities["r24d7_callback_timing_closure"]
    r7 = json.loads((root / str(r7_binding["path"])).read_bytes())
    exact(
        r7["diagnosis"]["pinned_upstream_source_bindings"],
        diagnosis["native_source_timing_proof"]["r24d7_pinned_upstream_source_bindings"],
        "ROTATION_BOUNDARY_R7_SOURCE_BINDINGS",
    )
    verify_exact_paths(
        diagnosis,
        {
            "method.mutation_control_count": 4,
            "source_alignment_projection.callback_runs_after_preceding_native_step": True,
            "source_alignment_projection.callback_runs_before_next_native_step": True,
            "source_alignment_projection.rigid_body_sync_precedes_script_callback": True,
            "source_alignment_projection.worker_sample_runs_in_same_physics_frame_as_callback": True,
            "source_alignment_projection.live_pre_values_are_current_completed_step_values": True,
            "source_alignment_projection.live_post_values_are_current_completed_step_values": True,
            "source_alignment_projection.live_pre_and_post_boundaries_are_temporally_distinct": False,
            "source_alignment_projection.declared_pre_boundary_sequence_matches_value_timing": False,
            "interpretation.r154_r165_physical_identity_established": True,
            "interpretation.rotation_measurement_changed_behavior": False,
            "interpretation.live_boundary_transport_alignment_defect_established": True,
            "interpretation.r165_residual_explained": False,
            "interpretation.existing_threshold_defect_established": False,
            "interpretation.controller_defect_established": False,
            "decision.r24d154_same_identity_rerun_permitted": False,
            "decision.r24d165_same_identity_rerun_permitted": False,
            "decision.r24d167_zero_world_contiguous_boundary_transport_design_required": True,
            "decision.controller_change_selected": False,
            "decision.threshold_change_selected": False,
            "decision.physical_execution_authorized": False,
            "claim_boundary.energy_balance_physically_corrected": False,
        },
        "ROTATION_BOUNDARY_EXTENSION",
    )
    return diagnosis


def run_rotation_boundary_alignment_diagnosis_cli(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    pass_marker: str,
    failure_marker: str,
    **scope: Any,
) -> int:
    """Run one thin R166 binding over the reusable zero-world checks."""

    try:
        diagnosis = validate_rotation_boundary_alignment_diagnosis(
            root,
            relative_path,
            schema,
            expected_sha256,
            expected_length,
            **scope,
        )
        arms = diagnosis["computed_projection"]["paired_route_identity"]["arms"]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": diagnosis["gate_id"],
                    "ok": True,
                    "status": diagnosis["status"],
                    "candidate_physical_identity_steps": arms["candidate_arm"][
                        "physical_projection_equal_step_count"
                    ],
                    "matched_zero_physical_identity_steps": arms["matched_zero_arm"][
                        "physical_projection_equal_step_count"
                    ],
                    "boundary_pair_temporally_distinct": diagnosis[
                        "source_alignment_projection"
                    ]["live_pre_and_post_boundaries_are_temporally_distinct"],
                    "mutation_control_count": 4,
                    "model_construction_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "prone_to_standing_claimed": False,
                    "sdk1_milestone_advanced": False,
                },
                sort_keys=True,
            ),
        )
        return 0
    except (
        ClosureAuditError,
        RetainedEnergyTraceError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(f"{failure_marker}:{error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit("use a campaign-specific thin binding")
