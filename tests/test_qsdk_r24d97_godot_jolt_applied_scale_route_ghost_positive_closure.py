#!/usr/bin/env python3
"""Audit the consumed positive R97 applied-scale production-route ghost."""

from __future__ import annotations

import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    complete_in_run_physical_invariant_projection,
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
    verify_two_step_native_portable_route,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d97_godot_jolt_applied_scale_route_"
    "ghost_positive_closure_v1.json"
)
SOURCE = "16ab79ceb25d4dfc29cba8462f395944b10c74be"
STATUS = (
    "closed_valid_complete_applied_scale_recovery_production_route_ghost_"
    "passed_distinct_r24d98_behavior_successor_required"
)
COUNT_KEYS = tuple(
    """
model_construction_attempt_count model_construction_count world_attempt_count
world_build_count solver_step_count portable_collection_count
portable_control_plan_count portable_command_application_count
validated_command_count host_readback_count host_write_count
body_impulse_write_count hard_constraint_motor_disabled_count
hard_constraint_motor_target_write_count
native_angular_velocity_initial_readback_count
native_angular_velocity_post_application_readback_count
native_angular_velocity_total_readback_count
native_angular_velocity_guard_engagement_count behavior_evaluator_invocation_count
threshold_count margin_count held_out_cell_access_count
adapter_side_discrete_staging_event_count missing_measurement_synthesis_count
""".split()
)
DECISION_TRUE = tuple(
    """
integration_ghost_attempt_consumed_for_exact_source model_construction_completed
world_build_completed two_solver_steps_completed physics_state_modified
first_native_observation_completed first_portable_route_completed
nested_guarded_command_applied second_native_observation_completed
second_portable_route_completed integration_ghost_passed
in_run_physical_invariants_passed native_engine_health_passed
distinct_recovery_behavior_successor_required
""".split()
)
DECISION_FALSE = tuple(
    """
same_identity_rerun_permitted r24d97_requalification_permitted
integration_refusal_observed infrastructure_failure_observed
controller_behavior_evaluated recovery_success_established
historical_threshold_changed historical_selector_changed
historical_evaluator_changed historical_result_rewritten
prone_to_standing_claimed physical_acceptance_authority release_authority
""".split()
)
CLAIM_TRUE = tuple(
    """
integration_ghost_attempt_retained integration_ghost_attempt_consumed_for_exact_source
valid_complete_integration_result model_construction_completed world_build_completed
two_solver_steps_executed physics_state_modified termination_protocol_valid
first_native_observation_completed first_portable_route_completed
nested_guarded_command_applied second_native_observation_completed
second_portable_route_completed integration_ghost_passed
in_run_physical_invariants_passed native_engine_health_passed
""".split()
)
CLAIM_FALSE = tuple(
    """
infrastructure_failure_observed controller_physical_viability_proven
recovery_success_established prone_to_standing_claimed population_claimed
cross_engine_equivalence_claimed sdk1_milestone_advanced
physical_acceptance_authority release_authority
""".split()
)


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d97_godot_jolt_applied_scale_route_"
                "ghost_positive_closure_v1"
            ),
            "gate_id": "QSDK-R24D97",
            "stage_id": "R24D97-GHOST",
            "closure_status": STATUS,
            "question_class": "development",
            "physical_question_declared": True,
            "behavior_success_required": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": (
                "80e4fa06226ff7d16b58997686ef7f9139de4fe6"
            ),
            "source.subject": (
                "[recovery/godot] Close R97 qualification: authorize two-step "
                "ghost"
            ),
        },
        "CLOSURE",
    )
    for flag, fmt in (("parent_commit", "%P"), ("tree", "%T"), ("subject", "%s")):
        exact(
            git(ROOT, "show", "-s", f"--format={fmt}", SOURCE),
            closure["source"][flag],
            f"SOURCE_{flag.upper()}",
        )
    for binding in closure["source"]["bindings"]:
        verify_source_binding(ROOT, SOURCE, binding)

    verify_exact_paths(
        closure["authorization_dependency"],
        {
            "qualification_closure_raw_sha256": (
                "sha256:f3210bb7dbe3793fa83f5d92f898695756107626f4f3ead2ff34708281ef1a72"
            ),
            "qualification_source_freeze_commit": (
                "80e4fa06226ff7d16b58997686ef7f9139de4fe6"
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
        gate_id="QSDK-R24D97",
        source_commit=SOURCE,
        status="valid_complete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d97_route_attempt_v1",
            "raw": (
                "sporespore_qsdk_r24d97_godot_jolt_applied_scale_"
                "recovery_route_raw_v1"
            ),
            "terminal": "sporespore_qsdk_r24d97_route_terminal_v1",
        },
        raw_count_keys=COUNT_KEYS,
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(
        raw,
        {
            "ok": True,
            "actuator_mode": (
                "force_based_nested_native_angular_velocity_guarded_v1"
            ),
            "actuator_mapping_id": (
                "godot_jolt_r24d96_source_measured_nested_native_angular_"
                "velocity_guarded_joint_impulse_v1"
            ),
            "work_mapping_id": (
                "godot_jolt_r24d96_nested_guarded_centered_source_measured_"
                "joint_work_v1"
            ),
            "native_scene_node_construction_attempted": True,
            "physical_question_opened": True,
            "physics_state_modified": True,
            "full_seeded_world_demo": False,
            "recovery_success_required": False,
            "all_immediate_native_readbacks_inside_guard": True,
            "all_in_run_physical_invariants_passed": True,
        },
        "RAW",
    )
    exact(terminal["completed_utc"], physical["completed_utc"], "TERMINAL_TIME")
    exact(terminal["worker"]["engine_health"]["passed"], True, "ENGINE_HEALTH")

    observed = closure["observed_integration"]
    initializer = raw["initializer_readback"]
    verify_exact_paths(
        initializer,
        {
            "ok": True,
            "body_readback_count": 9,
            "joint_readback_count": 8,
            "maximum_native_projection_to_readback_error_rad": 0.0,
            "writes_completed_before_first_solver_step": True,
        },
        "INITIALIZER",
    )
    exact(initializer["sha256"], observed["initializer_readback_sha256"], "INIT")

    steps = verify_two_step_native_portable_route(
        raw, phase="establish_distal_support", joint_count=8
    )
    application = steps["first_step"]["application_intent"]
    verify_exact_paths(
        application,
        {
            "ok": True,
            "phase": "establish_distal_support",
            "semantic_step": 2,
            "source_control_semantic_step": 1,
            "validated_command_count": 8,
            "host_readback_count": 8,
            "host_write_count": 16,
            "body_impulse_write_count": 16,
            "hard_constraint_motor_disabled_count": 8,
            "hard_constraint_motor_target_write_count": 0,
            "native_angular_velocity_initial_readback_count": 9,
            "native_angular_velocity_post_application_readback_count": 16,
            "native_angular_velocity_total_readback_count": 25,
            "native_angular_velocity_guard_engagement_count": 8,
            "native_angular_velocity_nested_projection_required": True,
            "projection_target_separated_from_native_readback_guard": True,
            "all_immediate_native_readbacks_inside_guard": True,
        },
        "APPLICATION",
    )
    receipts = application["ordered_receipts"]
    exact(len(receipts), 8, "RECEIPT_COUNT")
    scales: list[float] = []
    readback_speeds: list[float] = []
    for index, receipt in enumerate(receipts):
        projection = receipt["native_angular_velocity_guard_projection"]
        readback = receipt["native_angular_velocity_readback"]
        verify_exact_paths(
            receipt,
            {
                "actuator_index": index,
                "ok": True,
                "equal_and_opposite_pair": True,
                "parent_call_returned": True,
                "child_call_returned": True,
                "body_impulse_write_count": 2,
                "hard_constraint_velocity_motor_enabled": False,
                "source_measurement": True,
                "outer_guard_changed": False,
                "projection_target_separated_from_native_readback_guard": True,
                "native_angular_velocity_guard_engaged": True,
            },
            f"RECEIPT_{index}",
        )
        verify_exact_paths(
            projection,
            {
                "ok": True,
                "source_measurement": True,
                "both_predicted_inside_projection_target": True,
                "outer_guard_changed": False,
                "guard_limit_rad_s": 47.11813735961914,
                "projection_target_limit_rad_s": 47.11238479614258,
            },
            f"PROJECTION_{index}",
        )
        verify_exact_paths(
            readback,
            {
                "ok": True,
                "source_measurement": True,
                "readback_count": 2,
                "both_readbacks_inside_guard": True,
                "inner_target_is_prediction_only": True,
                "readback_authority": "frozen_outer_native_guard",
                "guard_limit_rad_s": 47.11813735961914,
                "projection_target_limit_rad_s": 47.11238479614258,
            },
            f"READBACK_{index}",
        )
        scale = float(projection["applied_scale"])
        require(math.isfinite(scale) and 0.0 <= scale <= 1.0, f"SCALE_{index}")
        scales.append(scale)
        readback_speeds.extend(
            (
                float(readback["parent_angular_speed_rad_s"]),
                float(readback["child_angular_speed_rad_s"]),
            )
        )
    exact(min(scales), observed["minimum_nested_applied_scale"], "MIN_SCALE")
    exact(max(scales), observed["maximum_nested_applied_scale"], "MAX_SCALE")
    exact(
        max(readback_speeds),
        observed["maximum_immediate_native_angular_speed_rad_s"],
        "MAX_READBACK",
    )

    projection = complete_in_run_physical_invariant_projection(raw)
    verify_exact_paths(
        closure["in_run_physical_invariants"],
        {
            **projection,
            "first_step_joint_observation_count": 8,
            "second_step_joint_observation_count": 8,
            "nested_guarded_command_application_ok": True,
            "all_nested_guard_receipts_source_measured": True,
            "all_nested_guard_pairs_equal_and_opposite": True,
            "all_immediate_native_readbacks_inside_guard": True,
            "all_projection_targets_separated_from_outer_guard": True,
            "all_nested_applied_scales_finite_and_unit_bounded": True,
            "termination_protocol_valid": True,
            "native_engine_health_passed": True,
        },
        "IN_RUN_INVARIANTS",
    )
    require(projection["all_raw_numeric_scalars_finite"] is True, "RAW_NUMERICS")
    require(projection["all_validity_fields_true"] is True, "RAW_VALIDITY")
    require(
        projection["all_source_measurement_flags_true"] is True,
        "RAW_SOURCE_MEASUREMENTS",
    )
    exact(projection["external_intervention_total"], 0.0, "RAW_INTERVENTIONS")

    stdout = (Path(physical["evidence_root"]) / "godot.stdout.log").read_text(
        encoding="utf-8"
    )
    require_ordered_markers(
        stdout,
        (
            "Godot Engine v4.7.stable.custom_build",
            "QSDK_R24D97_GODOT_JOLT_APPLIED_SCALE_RECOVERY_ROUTE_RAW ",
            '"status":"valid_complete_integration_ghost"',
            "QSDK_R24D97_GODOT_JOLT_APPLIED_SCALE_RECOVERY_ROUTE_READY ",
        ),
        "STDOUT",
    )
    verify_boolean_partition(closure["decision"], DECISION_TRUE, DECISION_FALSE, "DECISION")
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM")
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
            "gate_id": "QSDK-R24D98",
            "question_class": "development_behavior_successor_not_yet_declared",
            "physical_execution_blocked": True,
            "maximum_world_attempt_count": 0,
            "maximum_world_build_count": 0,
            "maximum_physical_steps_authorized": 0,
            "complete_zero_world_gate_required": True,
            "distinct_clean_pushed_source_required": True,
            "r24d97_may_be_rerun_or_requalified": False,
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
    raw_closure = CLOSURE.read_bytes() if revision is None else source_bytes(
        ROOT, revision, relative
    )
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        {
            **closure["live_gate_expectations"],
            "r24d97_ghost_positive_closure_raw_sha256": sha256(raw_closure),
            "r24d97_ghost_positive_closure_byte_length": len(raw_closure),
        },
        revision=revision,
    )
    print(
        "QSDK_R24D97_APPLIED_SCALE_ROUTE_GHOST_POSITIVE_CLOSURE_PASS "
        "attempts=1 models=1 worlds=1 steps=2 commands=8 body_impulses=16 "
        "native_readbacks=25 guard_engagements=8 native_health=true "
        "next=R24D98 sdk1=11/20"
    )


if __name__ == "__main__":
    audit()
