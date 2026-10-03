#!/usr/bin/env python3
"""Audit the consumed invalid R95 guarded production-route ghost."""

from __future__ import annotations

import math
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
    "sdk/recovery/r24d95_godot_jolt_publication_stable_guarded_"
    "recovery_route_ghost_invalid_closure_v1.json"
)
SOURCE = "de2bd0dd1a8eae0365141702bb8df14f6fe09acb"
LENGTH = 15060
DIGEST = "sha256:24453b3bf4708593f79296a0ef5ebaf7cd7d47254a37a7ff5c8350debe70c977"
STATUS = (
    "closed_consumed_invalid_incomplete_guarded_route_ghost_immediate_native_"
    "readback_exceeded_inner_guard_r96_required"
)
DECISION_TRUE = tuple(
    """
integration_ghost_attempt_consumed_for_exact_source model_construction_completed
world_build_completed first_solver_step_completed physics_state_modified
native_engine_health_passed termination_protocol_valid in_run_guard_failure_retained
distinct_r96_successor_required
""".split()
)
DECISION_FALSE = tuple(
    """
same_identity_rerun_permitted r24d95_requalification_permitted
two_solver_steps_completed integration_ghost_passed
all_in_run_physical_invariants_passed valid_complete_integration_result
native_engine_infrastructure_failure_observed controller_behavior_evaluated
recovery_success_established historical_threshold_changed
historical_selector_changed historical_evaluator_changed
historical_result_rewritten prone_to_standing_claimed sdk1_milestone_advanced
physical_acceptance_authority release_authority
""".split()
)
CLAIM_TRUE = tuple(
    """
integration_ghost_attempt_retained integration_ghost_attempt_consumed_for_exact_source
model_construction_completed world_build_completed one_solver_step_executed
physics_state_modified termination_protocol_valid native_engine_health_passed
in_run_guard_failure_observed
""".split()
)
CLAIM_FALSE = tuple(
    """
valid_complete_integration_result two_solver_steps_executed integration_ghost_passed
all_in_run_physical_invariants_passed controller_physical_viability_proven
recovery_success_established prone_to_standing_claimed population_claimed
cross_engine_equivalence_claimed sdk1_milestone_advanced
physical_acceptance_authority release_authority
""".split()
)


def _parse_vector(text: str) -> tuple[float, float, float]:
    require(text.startswith("(") and text.endswith(")"), "VECTOR_SHAPE")
    values = tuple(float(item.strip()) for item in text[1:-1].split(","))
    require(len(values) == 3 and all(math.isfinite(item) for item in values),
            "VECTOR_VALUE")
    return values  # type: ignore[return-value]


def audit() -> None:
    raw_closure = CLOSURE.read_bytes().replace(b"\r\n", b"\n")
    exact((len(raw_closure), sha256(raw_closure)), (LENGTH, DIGEST),
          "CLOSURE_BLOB")
    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d95_godot_jolt_publication_stable_"
                "guarded_recovery_route_ghost_invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D95",
            "stage_id": "R24D95-GHOST",
            "closure_status": STATUS,
            "question_class": "development",
            "physical_question_declared": True,
            "behavior_success_required": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": "fa30e7dc3e745ea0089916bc6b49bb0a63d65ef1",
            "source.tree": "b410e1e8610c316f63fd333df55459f2d49b42c7",
            "source.subject": (
                "[recovery/godot] Close R95 qualification: authorize two-step "
                "ghost"
            ),
        },
        "CLOSURE",
    )
    for key, fmt in (("parent_commit", "%P"), ("tree", "%T"), ("subject", "%s")):
        exact(git(ROOT, "show", "-s", f"--format={fmt}", SOURCE),
              closure["source"][key], f"SOURCE_{key.upper()}")
    for binding in closure["source"]["bindings"]:
        verify_source_binding(ROOT, SOURCE, binding)

    verify_exact_paths(
        closure["authorization_dependency"],
        {
            "qualification_closure_raw_sha256": (
                "sha256:c2837594a5bd76c324041ba054a644f89978b7ec8eab7a68d7f7653aa698cdd1"
            ),
            "qualification_source_freeze_commit": (
                "fa30e7dc3e745ea0089916bc6b49bb0a63d65ef1"
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
        gate_id="QSDK-R24D95",
        source_commit=SOURCE,
        status="invalid_or_incomplete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d95_route_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d95_godot_jolt_guarded_recovery_route_"
                "raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d95_route_terminal_v1",
        },
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(
        raw,
        {
            "ok": False,
            "failure_code": "QSDK_R24D95_GHOST_PORTABLE_COMMAND_APPLICATION_FAILED",
            "detail.failure_code": (
                "QSDK_R24D94_GUARDED_IMMEDIATE_NATIVE_READBACK_INVALID:0"
            ),
            "detail.body_impulse_write_count": 2,
            "detail.native_angular_velocity_readback_count": 11,
            "detail.detail.guard_limit_rad_s": 47.11813735961914,
            "detail.detail.parent_post": "(-0.000016, 0.000003, 0.495788)",
            "detail.detail.child_post": "(0.000981, -0.000545, -47.11815)",
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
            "worker.engine_health.passed": True,
            "worker.engine_health.fatal_diagnostic_line_count": 0,
            "worker.termination_protocol_valid": True,
            "worker.timed_out": False,
            "recovery_success_observed": False,
        },
        "TERMINAL",
    )

    observed = closure["observed_failure"]
    child = _parse_vector(str(raw["detail"]["detail"]["child_post"]))
    child_speed = math.sqrt(sum(item * item for item in child))
    guard = float(raw["detail"]["detail"]["guard_limit_rad_s"])
    exact(child_speed, observed["reported_child_post_speed_from_rounded_vector_rad_s"],
          "REPORTED_CHILD_SPEED")
    exact(child_speed - guard,
          observed["reported_guard_exceedance_from_rounded_vector_rad_s"],
          "REPORTED_GUARD_EXCEEDANCE")
    exact(
        (child_speed - guard) / observed["binary32_ulp_at_guard_rad_s"],
        observed["reported_guard_exceedance_binary32_ulp"],
        "REPORTED_GUARD_ULP",
    )
    require(child_speed > guard, "RETAINED_GUARD_FAILURE")
    verify_exact_paths(
        observed,
        {
            "completed_body_impulse_write_count": 2,
            "completed_native_angular_velocity_readback_count": 11,
            "first_solver_step_completed": True,
            "second_solver_step_completed": False,
            "native_engine_health_passed": True,
            "termination_protocol_valid": True,
            "physics_failure_is_valid_evidence": True,
            "full_route_result_valid_complete": False,
            "guard_projection_predictive_adequacy_established": False,
            "behavior_evaluator_invoked": False,
            "recovery_success_established": False,
            "prone_to_standing_established": False,
        },
        "OBSERVED",
    )
    verify_boolean_partition(closure["decision"], DECISION_TRUE, DECISION_FALSE,
                             "DECISION")
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE,
                             "CLAIM")
    verify_exact_paths(
        closure["next_boundary"],
        {
            "gate_id": "QSDK-R24D96",
            "question_class": "development_successor_not_yet_declared",
            "physical_execution_blocked": True,
            "maximum_world_attempt_count": 0,
            "maximum_world_build_count": 0,
            "maximum_physical_steps_authorized": 0,
            "complete_zero_world_gate_required": True,
            "distinct_clean_pushed_source_required": True,
            "r24d95_may_be_rerun_or_requalified": False,
            "guard_observation_limit_may_be_rewritten": False,
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
        record_key="r24d95_contract_path",
        expected={
            "r24d95_physical_attempt_consumed": True,
            "r24d95_physical_attempt_disposition": (
                "invalid_or_incomplete_integration_ghost"
            ),
            "r24d95_ghost_invalid_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
            "r24d95_ghost_invalid_closure_raw_sha256": DIGEST,
            "r24d95_ghost_invalid_closure_byte_length": LENGTH,
            "r24d95_invocation_source_commit": SOURCE,
            "r24d95_observed_model_construction_count": 1,
            "r24d95_observed_world_attempt_count": 1,
            "r24d95_observed_world_build_count": 1,
            "r24d95_observed_solver_step_count": 1,
            "r24d95_native_engine_health_passed": True,
            "r24d95_integration_ghost_passed": False,
            "r24d95_in_run_physical_invariants_passed": False,
            "r24d95_physical_execution_authorized": False,
            "r24d95_same_identity_rerun_permitted": False,
            "r24d96_distinct_successor_required": True,
            "r24d96_question_class_declared": False,
            "physical_execution_blocked_pending_r24d96_declaration": True,
        },
        prefix="LIVE_R95_GHOST",
    )


def test_r24d95_guarded_route_ghost_invalid_closure() -> None:
    audit()


if __name__ == "__main__":
    audit()
    print("QSDK_R24D95_GUARDED_ROUTE_GHOST_INVALID_CLOSURE_PASS")
