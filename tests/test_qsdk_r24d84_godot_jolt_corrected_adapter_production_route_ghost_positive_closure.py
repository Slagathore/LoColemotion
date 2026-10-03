#!/usr/bin/env python3
"""Audit the consumed positive R84 corrected production-route ghost."""

from __future__ import annotations

import math
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    load,
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d84_godot_jolt_corrected_adapter_production_route_"
    "ghost_positive_closure_v1.json"
)
SOURCE = "e5c42b9f29276cc28668e9a371aa9d5acca27f6f"
STATUS = (
    "closed_valid_complete_corrected_adapter_production_route_ghost_passed_"
    "distinct_r24d85_behavior_successor_required"
)
DECISION_TRUE = (
    "integration_ghost_attempt_consumed_for_exact_source",
    "model_construction_completed",
    "world_build_completed",
    "two_solver_steps_completed",
    "physics_state_modified",
    "first_native_observation_completed",
    "first_portable_route_completed",
    "portable_command_applied",
    "second_native_observation_completed",
    "second_portable_route_completed",
    "integration_ghost_passed",
    "in_run_physical_invariants_passed",
    "distinct_recovery_behavior_successor_required",
)
DECISION_FALSE = (
    "same_identity_rerun_permitted",
    "r24d84_requalification_permitted",
    "integration_refusal_observed",
    "infrastructure_failure_observed",
    "controller_behavior_evaluated",
    "recovery_success_established",
    "historical_threshold_changed",
    "historical_selector_changed",
    "historical_evaluator_changed",
    "historical_result_rewritten",
    "prone_to_standing_claimed",
    "physical_acceptance_authority",
    "release_authority",
)
CLAIM_TRUE = (
    "integration_ghost_attempt_retained",
    "integration_ghost_attempt_consumed_for_exact_source",
    "valid_complete_integration_result",
    "model_construction_completed",
    "world_build_completed",
    "two_solver_steps_executed",
    "physics_state_modified",
    "termination_protocol_valid",
    "first_native_observation_completed",
    "first_portable_route_completed",
    "portable_command_applied",
    "second_native_observation_completed",
    "second_portable_route_completed",
    "integration_ghost_passed",
    "in_run_physical_invariants_passed",
)
CLAIM_FALSE = (
    "infrastructure_failure_observed",
    "controller_physical_viability_proven",
    "recovery_success_established",
    "prone_to_standing_claimed",
    "population_claimed",
    "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced",
    "physical_acceptance_authority",
    "release_authority",
)


def _collect_in_run_invariants(value: object) -> dict[str, object]:
    numbers: list[float] = []
    validity_records: list[dict[str, object]] = []
    source_measurements: list[bool] = []
    external_interventions: list[dict[str, object]] = []

    def walk(current: object) -> None:
        if isinstance(current, dict):
            validity = current.get("validity")
            if isinstance(validity, dict):
                validity_records.append(validity)
            source_measurement = current.get("source_measurement")
            if isinstance(source_measurement, bool):
                source_measurements.append(source_measurement)
            interventions = current.get("external_interventions")
            if isinstance(interventions, dict):
                external_interventions.append(interventions)
            for child in current.values():
                walk(child)
        elif isinstance(current, list):
            for child in current:
                walk(child)
        elif isinstance(current, (int, float)) and not isinstance(current, bool):
            numbers.append(float(current))

    walk(value)
    return {
        "complete_raw_numeric_scalar_count": len(numbers),
        "all_raw_numeric_scalars_finite": all(math.isfinite(v) for v in numbers),
        "validity_record_count": len(validity_records),
        "validity_field_count": sum(len(record) for record in validity_records),
        "all_validity_fields_true": all(
            all(field is True for field in record.values())
            for record in validity_records
        ),
        "source_measurement_flag_count": len(source_measurements),
        "all_source_measurement_flags_true": all(source_measurements),
        "external_intervention_receipt_count": len(external_interventions),
        "external_intervention_field_count": sum(
            len(record) for record in external_interventions
        ),
        "external_intervention_total": sum(
            float(field)
            for record in external_interventions
            for field in record.values()
        ),
    }


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d84_godot_jolt_corrected_adapter_"
                "production_route_ghost_positive_closure_v1"
            ),
            "gate_id": "QSDK-R24D84",
            "stage_id": "R24D84-GHOST",
            "closure_status": STATUS,
            "question_class": "development",
            "physical_question_declared": True,
            "behavior_success_required": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": (
                "6bf1003ac2f0325df8eabe8ff33351ddeb9a1d1e"
            ),
            "source.tree": "594e2e832721bfeffc11d5d677d13fc973804e30",
            "source.subject": (
                "[recovery/godot] Close R84 qualification: authorize two-step "
                "route ghost"
            ),
        },
        "CLOSURE",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%P", SOURCE),
        closure["source"]["parent_commit"],
        "SOURCE_PARENT",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%T", SOURCE),
        closure["source"]["tree"],
        "SOURCE_TREE",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%s", SOURCE),
        closure["source"]["subject"],
        "SOURCE_SUBJECT",
    )
    for binding in closure["source"]["bindings"]:
        verify_source_binding(ROOT, SOURCE, binding)

    verify_exact_paths(
        closure["authorization_dependency"],
        {
            "qualification_closure_raw_sha256": (
                "sha256:57b80c915679cf1abc9ffd04423fa6e18d7bb4b5424e2241f14d9877654e09e7"
            ),
            "qualification_source_freeze_commit": (
                "6bf1003ac2f0325df8eabe8ff33351ddeb9a1d1e"
            ),
            "authorization_publication_commit": SOURCE,
            "complete_zero_world_gate_satisfied": True,
            "direct_committed_closure_recheck_satisfied": True,
            "published_closure_authorization_control_required": False,
            "qualified_physical_source_drift_check_passed": True,
            "qualified_physical_path_count": 47,
            "clean_pushed_remote_equality_passed": True,
            "same_identity_requalification_permitted": False,
        },
        "AUTHORIZATION",
    )

    physical = closure["physical_attempt"]
    values = verify_supervised_bounded_ghost_attempt(
        physical=physical,
        gate_id="QSDK-R24D84",
        source_commit=SOURCE,
        status="valid_complete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d84_route_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d84_godot_corrected_adapter_route_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d84_route_terminal_v1",
        },
        raw_count_keys=(
            "model_construction_attempt_count",
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
            "behavior_evaluator_invocation_count",
            "threshold_count",
            "margin_count",
            "held_out_cell_access_count",
        ),
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(
        raw,
        {
            "ok": True,
            "native_scene_node_construction_attempted": True,
            "physical_question_opened": True,
            "physics_state_modified": True,
            "physics_failure_is_valid_evidence": True,
            "full_seeded_world_demo": False,
            "recovery_success_required": False,
            "portable_collection_count": 2,
            "portable_control_plan_count": 2,
            "portable_command_application_count": 1,
            "validated_command_count": 8,
            "host_write_count": 8,
            "host_readback_count": 8,
            "adapter_side_discrete_staging_event_count": 0,
            "missing_measurement_synthesis_count": 0,
        },
        "RAW_RESULT",
    )
    exact(terminal["completed_utc"], physical["completed_utc"], "TERMINAL_TIME")

    initializer = raw["initializer_readback"]
    verify_exact_paths(
        initializer,
        {
            "ok": True,
            "body_readback_count": 9,
            "joint_readback_count": 8,
            "maximum_native_projection_to_readback_error_rad": 0.0,
            "native_projection_sha256": (
                "sha256:ff5c33f3e9ba172057db950423f5f53a56ba1e17943d050cd6525b9e4fabf088"
            ),
            "writes_completed_before_first_solver_step": True,
        },
        "INITIALIZER_READBACK",
    )
    exact(
        initializer["initializer_manifest_sha256"],
        raw["initializer_manifest_sha256"],
        "INITIALIZER_BINDING",
    )

    for name, solver_step, semantic_step in (
        ("first_step", 1, 1.0),
        ("second_step", 2, 2.0),
    ):
        step = raw[name]
        verify_exact_paths(
            step["native_route"],
            {
                "ok": True,
                "model_construction_count": 1,
                "world_attempt_count": 1,
                "world_build_count": 1,
                "solver_step_count": solver_step,
                "physics_state_modified": True,
                "native_runtime_observation_collection_executed": True,
            },
            f"{name.upper()}_NATIVE",
        )
        portable = step["portable_route"]
        verify_exact_paths(
            portable,
            {
                "ok": True,
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
                "physics_state_modified": False,
                "collection_receipt.supplied_native_post_step_observation_validated": True,
                "collection_receipt.native_observation_validation_kernel_implemented": True,
                "collection_receipt.refusal_reason": None,
                "control_receipt.phase": "establish_distal_support",
                "control_receipt.semantic_step": semantic_step,
                "control_receipt.controller_implemented": True,
                "control_receipt.refusal_reason": None,
                "control_receipt.matched_zero_command": False,
                "control_receipt.no_actuation_requested": False,
            },
            f"{name.upper()}_PORTABLE",
        )
        commands = portable["control_receipt"]["ordered_commands"]
        exact(len(commands), 8, f"{name.upper()}_COMMAND_COUNT")
        joints = portable["collection_request"]["observation"]["state"][
            "ordered_joint_observations"
        ]
        exact(len(joints), 8, f"{name.upper()}_JOINT_OBSERVATION_COUNT")
        require(
            all(all(item["validity"].values()) for item in joints),
            f"{name.upper()}_JOINT_VALIDITY",
        )

    application = raw["first_step"]["application_intent"]
    verify_exact_paths(
        application,
        {
            "ok": True,
            "phase": "establish_distal_support",
            "semantic_step": 2,
            "source_control_semantic_step": 1,
            "validated_command_count": 8,
            "host_write_count": 8,
            "host_readback_count": 8,
            "motor_enabled_count": 8,
            "fallback_control_count": 0,
            "root_actuation_count": 0,
            "zero_world_host_surface": False,
        },
        "APPLICATION",
    )
    exact(
        (len(application["ordered_intents"]), len(application["ordered_receipts"])),
        (8, 8),
        "APPLICATION_ORDERED_COUNTS",
    )

    invariant_projection = _collect_in_run_invariants(raw)
    verify_exact_paths(
        closure["in_run_physical_invariants"],
        {
            **invariant_projection,
            "first_step_joint_observation_count": 8,
            "second_step_joint_observation_count": 8,
            "missing_measurement_synthesis_count": 0,
            "adapter_side_discrete_staging_event_count": 0,
            "initializer_exact_readback_passed": True,
            "native_step_results_ok": True,
            "portable_step_results_ok": True,
            "command_application_ok": True,
            "termination_protocol_valid": True,
        },
        "IN_RUN_INVARIANTS",
    )
    require(
        invariant_projection["all_raw_numeric_scalars_finite"] is True,
        "RAW_NUMERICS_NONFINITE",
    )
    require(
        invariant_projection["all_validity_fields_true"] is True,
        "RAW_VALIDITY_FALSE",
    )
    require(
        invariant_projection["all_source_measurement_flags_true"] is True,
        "RAW_SOURCE_MEASUREMENT_FALSE",
    )
    exact(
        invariant_projection["external_intervention_total"],
        0.0,
        "RAW_EXTERNAL_INTERVENTIONS",
    )

    evidence = Path(physical["evidence_root"])
    stdout = (evidence / physical["artifacts"]["stdout"]["path"]).read_text(
        encoding="utf-8"
    )
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build",
            "QSDK_R24D84_GODOT_CORRECTED_ADAPTER_ROUTE_RAW ",
            '"status":"valid_complete_integration_ghost"',
            "QSDK_R24D84_GODOT_CORRECTED_ADAPTER_ROUTE_READY ",
        ),
        "STDOUT",
    )

    verify_exact_paths(
        closure["observed_integration"],
        {
            "classification": (
                "valid_complete_godot_jolt_two_step_corrected_adapter_"
                "production_route"
            ),
            "native_observation_count": 2,
            "portable_collection_count": 2,
            "portable_control_plan_count": 2,
            "portable_command_application_count": 1,
            "ordered_command_count_per_plan": 8,
            "first_native_solver_step": 1,
            "second_native_solver_step": 2,
            "controller_phase_at_both_steps": "establish_distal_support",
            "initializer_maximum_projection_to_readback_error_rad": 0.0,
            "integration_refusal_observed": False,
            "infrastructure_failure_observed": False,
            "behavior_evaluator_invoked": False,
            "recovery_success_established": False,
            "prone_to_standing_established": False,
        },
        "OBSERVED",
    )
    verify_boolean_partition(
        closure["decision"], DECISION_TRUE, DECISION_FALSE, "DECISION"
    )
    verify_boolean_partition(
        closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM"
    )
    exact(
        closure["sdk_status"],
        {
            "sdk1_milestone_advanced": False,
            "sdk1_completed_steps": 11,
            "sdk1_total_steps": 20,
            "full_program_completed_steps": 11,
            "full_program_total_steps": 25,
        },
        "SDK_STATUS",
    )
    verify_exact_paths(
        closure["next_boundary"],
        {
            "gate_id": "QSDK-R24D85",
            "question_class": "development_behavior_successor_not_yet_declared",
            "physical_execution_blocked": True,
            "maximum_world_attempt_count": 0,
            "maximum_world_build_count": 0,
            "maximum_physical_steps_authorized": 0,
            "complete_zero_world_gate_required": True,
            "distinct_clean_pushed_source_required": True,
            "r24d84_may_be_rerun_or_requalified": False,
            "held_out_cells_remain_sealed": True,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "NEXT",
    )

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative
    )
    revision = publication or None
    raw_closure = (
        CLOSURE.read_bytes()
        if revision is None
        else source_bytes(ROOT, revision, relative)
    )
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        {
            **closure["live_gate_expectations"],
            "r24d84_ghost_positive_closure_raw_sha256": sha256(raw_closure),
            "r24d84_ghost_positive_closure_byte_length": len(raw_closure),
        },
        revision=revision,
    )
    print(
        "QSDK_R24D84_GODOT_JOLT_CORRECTED_ADAPTER_PRODUCTION_ROUTE_GHOST_"
        "POSITIVE_CLOSURE_PASS attempts=1 models=1 worlds=1 steps=2 "
        "observations=2 plans=2 commands=8 numerics=3062 validity=240/240 "
        "source_measurements=182/182 external_interventions=0 next=R24D85 "
        "sdk1=11/20"
    )


if __name__ == "__main__":
    try:
        audit()
    except (
        ClosureAuditError,
        OSError,
        KeyError,
        TypeError,
        ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(
            "QSDK_R24D84_GODOT_JOLT_CORRECTED_ADAPTER_PRODUCTION_ROUTE_GHOST_"
            f"POSITIVE_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
