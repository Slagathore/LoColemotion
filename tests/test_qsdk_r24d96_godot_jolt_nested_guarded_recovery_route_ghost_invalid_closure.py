#!/usr/bin/env python3
"""Audit the consumed integration-invalid R96 Godot/Jolt route ghost."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    git,
    load,
    require,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d96_godot_jolt_nested_guarded_recovery_route_"
    "ghost_invalid_closure_v1.json"
)
SOURCE = "8dfeb1e1cd5211a0675d18e76eeef4bb1cacb777"
LENGTH = 15089
DIGEST = "sha256:8caa65214374032c2aa7c0ef0f01c33f08e7833435e0c32d2d0c2b56b52d3eb0"
STATUS = (
    "closed_consumed_invalid_incomplete_nested_guarded_route_ghost_missing_"
    "applied_scale_key_r97_required"
)
DIAGNOSTIC = (
    "SCRIPT ERROR: Invalid access to property or key "
    "'angular_velocity_guard_applied_scale' on a base object of type "
    "'Dictionary'."
)

DECISION_TRUE = tuple(
    """
integration_ghost_attempt_consumed_for_exact_source model_construction_completed
world_build_completed first_solver_step_completed physics_state_modified
termination_protocol_valid native_engine_infrastructure_failure_observed
missing_projection_scale_key_diagnosed invalid_incomplete_result_retained
distinct_r97_successor_required
""".split()
)
DECISION_FALSE = tuple(
    """
native_engine_health_passed same_identity_rerun_permitted
r24d96_requalification_permitted two_solver_steps_completed
integration_ghost_passed all_in_run_physical_invariants_passed
valid_complete_integration_result valid_physics_behavior_negative
controller_behavior_evaluated recovery_success_established
historical_threshold_changed historical_selector_changed
historical_evaluator_changed historical_result_rewritten
prone_to_standing_claimed sdk1_milestone_advanced
physical_acceptance_authority release_authority
""".split()
)
CLAIM_TRUE = tuple(
    """
integration_ghost_attempt_retained integration_ghost_attempt_consumed_for_exact_source
model_construction_completed world_build_completed one_solver_step_executed
physics_state_modified termination_protocol_valid
native_engine_infrastructure_failure_observed invalid_incomplete_result_retained
""".split()
)
CLAIM_FALSE = tuple(
    """
native_engine_health_passed valid_complete_integration_result
two_solver_steps_executed integration_ghost_passed
all_in_run_physical_invariants_passed valid_physics_behavior_negative
controller_physical_viability_proven recovery_success_established
prone_to_standing_claimed population_claimed cross_engine_equivalence_claimed
sdk1_milestone_advanced physical_acceptance_authority release_authority
""".split()
)


def audit() -> None:
    raw_closure = CLOSURE.read_bytes().replace(b"\r\n", b"\n")
    exact((len(raw_closure), sha256(raw_closure)), (LENGTH, DIGEST), "CLOSURE_BLOB")
    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d96_godot_jolt_nested_guarded_recovery_"
                "route_ghost_invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D96",
            "stage_id": "R24D96-GHOST",
            "closure_status": STATUS,
            "question_class": "development",
            "physical_question_declared": True,
            "behavior_success_required": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": "7160d9fb53e882189eca7f8df770ebb3b2170424",
            "source.tree": "5600c35d6e65a0df85e9b4f3d357a9b2065b7051",
            "source.subject": (
                "[recovery/godot] Close R96 qualification: authorize two-step "
                "ghost"
            ),
        },
        "CLOSURE",
    )
    for key, fmt in (("parent_commit", "%P"), ("tree", "%T"), ("subject", "%s")):
        exact(
            git(ROOT, "show", "-s", f"--format={fmt}", SOURCE),
            closure["source"][key],
            f"SOURCE_{key.upper()}",
        )
    for binding in closure["source"]["bindings"]:
        verify_source_binding(ROOT, SOURCE, binding)

    verify_exact_paths(
        closure["authorization_dependency"],
        {
            "qualification_closure_raw_sha256": (
                "sha256:3348235c55c98c9d05f391c03168c113fc0c3cd777a2a09d295bdf68ec700ec9"
            ),
            "qualification_source_freeze_commit": (
                "7160d9fb53e882189eca7f8df770ebb3b2170424"
            ),
            "authorization_publication_commit": SOURCE,
            "complete_zero_world_gate_satisfied": True,
            "phase_aware_postpublication_source_audit_passed": True,
            "direct_committed_closure_recheck_satisfied": True,
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
        gate_id="QSDK-R24D96",
        source_commit=SOURCE,
        status="invalid_or_incomplete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d96_route_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d96_godot_jolt_nested_guarded_recovery_"
                "route_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d96_route_terminal_v1",
        },
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(
        raw,
        {
            "ok": False,
            "failure_code": "QSDK_R24D96_GHOST_PORTABLE_COMMAND_APPLICATION_FAILED",
            "detail": {},
            "native_scene_node_construction_attempted": True,
            "physical_question_opened": True,
            "physics_failure_is_valid_evidence": True,
            "physics_state_modified": True,
            "full_seeded_world_demo": False,
            "recovery_success_required": False,
            "model_construction_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "solver_step_count": 1,
            "behavior_evaluator_invocation_count": 0,
        },
        "RAW",
    )
    verify_exact_paths(
        terminal,
        {
            "worker.engine_health.passed": False,
            "worker.engine_health.engine_error_line_count": 1,
            "worker.engine_health.fatal_diagnostic_line_count": 1,
            "worker.engine_health.fatal_diagnostic_unique_line_count": 1,
            "worker.engine_health.ordered_unique_fatal_diagnostic_lines": [DIAGNOSTIC],
            "worker.termination_protocol_valid": True,
            "worker.timed_out": False,
            "recovery_success_observed": False,
        },
        "TERMINAL",
    )

    observed = closure["observed_failure"]
    verify_exact_paths(
        observed,
        {
            "top_level_failure_code": (
                "QSDK_R24D96_GHOST_PORTABLE_COMMAND_APPLICATION_FAILED"
            ),
            "direct_engine_diagnostic": DIAGNOSTIC,
            "source_site": (
                "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd:2138"
            ),
            "requested_missing_key": "angular_velocity_guard_applied_scale",
            "diagnosed_existing_nested_scale_path": (
                "native_angular_velocity_guard_projection.applied_scale"
            ),
            "first_solver_step_completed": True,
            "second_solver_step_completed": False,
            "native_engine_health_passed": False,
            "fatal_diagnostic_line_count": 1,
            "termination_protocol_valid": True,
            "worker_timed_out": False,
            "stderr_byte_length": 1023,
            "stderr_raw_sha256": (
                "sha256:63e46271fb03075866265dd015bca8fe63957fab04cfb82ab32fd3337d2309a6"
            ),
            "raw_physics_failure_is_valid_evidence_field": True,
            "valid_physics_behavior_negative": False,
            "full_route_result_valid_complete": False,
            "behavior_evaluator_invoked": False,
            "recovery_success_established": False,
            "prone_to_standing_established": False,
        },
        "OBSERVED",
    )
    route_source = source_bytes(
        ROOT, SOURCE, "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
    ).decode("utf-8")
    world_source = source_bytes(
        ROOT, SOURCE, "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
    ).decode("utf-8")
    require(
        'guarded_projection["angular_velocity_guard_applied_scale"]' in route_source,
        "MISSING_KEY_ACCESS_NOT_BOUND",
    )
    require(
        '"native_angular_velocity_guard_projection": guard_pair.duplicate(true)'
        in world_source,
        "NESTED_GUARD_RECEIPT_NOT_BOUND",
    )
    require('"applied_scale": applied_scale' in world_source, "NESTED_SCALE_NOT_BOUND")

    verify_boolean_partition(closure["decision"], DECISION_TRUE, DECISION_FALSE, "DECISION")
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM")
    verify_exact_paths(
        closure["next_boundary"],
        {
            "gate_id": "QSDK-R24D97",
            "question_class": "development_successor_not_yet_declared",
            "physical_execution_blocked": True,
            "maximum_world_attempt_count": 0,
            "maximum_world_build_count": 0,
            "maximum_physical_steps_authorized": 0,
            "complete_zero_world_gate_required": True,
            "distinct_clean_pushed_source_required": True,
            "r24d96_may_be_rerun_or_requalified": False,
            "r24d96_guard_or_projection_target_may_be_rewritten": False,
            "held_out_cells_remain_sealed": True,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "NEXT",
    )
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d96_contract_path",
        expected={
            "r24d96_physical_attempt_consumed": True,
            "r24d96_physical_attempt_disposition": (
                "invalid_or_incomplete_integration_ghost"
            ),
            "r24d96_ghost_invalid_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
            "r24d96_ghost_invalid_closure_raw_sha256": DIGEST,
            "r24d96_ghost_invalid_closure_byte_length": LENGTH,
            "r24d96_invocation_source_commit": SOURCE,
            "r24d96_observed_model_construction_count": 1,
            "r24d96_observed_world_attempt_count": 1,
            "r24d96_observed_world_build_count": 1,
            "r24d96_observed_solver_step_count": 1,
            "r24d96_native_engine_health_passed": False,
            "r24d96_native_engine_infrastructure_failure_observed": True,
            "r24d96_valid_physics_behavior_negative": False,
            "r24d96_integration_ghost_passed": False,
            "r24d96_in_run_physical_invariants_passed": False,
            "r24d96_physical_execution_authorized": False,
            "r24d96_same_identity_rerun_permitted": False,
            "r24d97_distinct_successor_required": True,
            "r24d97_question_class_declared": False,
            "physical_execution_blocked_pending_r24d97_declaration": True,
        },
        prefix="LIVE_R96_GHOST",
    )


def test_r24d96_nested_route_ghost_invalid_closure() -> None:
    audit()


if __name__ == "__main__":
    audit()
    print("QSDK_R24D96_NESTED_ROUTE_GHOST_INVALID_CLOSURE_PASS")
