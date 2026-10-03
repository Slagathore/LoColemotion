#!/usr/bin/env python3
"""Audit the consumed positive R88 force-based production-route ghost."""

from __future__ import annotations

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
    verify_force_based_joint_impulse_application,
    verify_force_based_joint_work_source,
    verify_legacy_live_gate_paths,
    verify_source_binding,
    verify_supervised_bounded_ghost_attempt,
    verify_two_step_native_portable_route,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d88_godot_force_based_recovery_production_route_"
    "ghost_positive_closure_v1.json"
)
SOURCE = "0db5835826dff92f484b8d49a06071923c64b1b3"
STATUS = (
    "closed_valid_complete_force_based_recovery_production_route_ghost_"
    "passed_distinct_r24d89_behavior_successor_required"
)
COUNT_KEYS = tuple("""
model_construction_attempt_count model_construction_count world_attempt_count
world_build_count solver_step_count portable_collection_count
portable_control_plan_count portable_command_application_count
validated_command_count host_readback_count host_write_count
body_impulse_write_count hard_constraint_motor_disabled_count
hard_constraint_motor_target_write_count behavior_evaluator_invocation_count
threshold_count margin_count held_out_cell_access_count
adapter_side_discrete_staging_event_count missing_measurement_synthesis_count
""".split())
DECISION_TRUE = tuple("""
integration_ghost_attempt_consumed_for_exact_source model_construction_completed
world_build_completed two_solver_steps_completed physics_state_modified
first_native_observation_completed first_portable_route_completed
force_based_command_applied second_native_observation_completed
second_portable_route_completed integration_ghost_passed
in_run_physical_invariants_passed distinct_recovery_behavior_successor_required
""".split())
DECISION_FALSE = tuple("""
same_identity_rerun_permitted r24d88_requalification_permitted
integration_refusal_observed infrastructure_failure_observed
controller_behavior_evaluated recovery_success_established
historical_threshold_changed historical_selector_changed
historical_evaluator_changed historical_result_rewritten
prone_to_standing_claimed physical_acceptance_authority release_authority
""".split())
CLAIM_TRUE = tuple("""
integration_ghost_attempt_retained integration_ghost_attempt_consumed_for_exact_source
valid_complete_integration_result model_construction_completed world_build_completed
two_solver_steps_executed physics_state_modified termination_protocol_valid
first_native_observation_completed first_portable_route_completed
force_based_command_applied second_native_observation_completed
second_portable_route_completed integration_ghost_passed
in_run_physical_invariants_passed
""".split())
CLAIM_FALSE = tuple("""
infrastructure_failure_observed controller_physical_viability_proven
recovery_success_established prone_to_standing_claimed population_claimed
cross_engine_equivalence_claimed sdk1_milestone_advanced
physical_acceptance_authority release_authority
""".split())


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d88_godot_force_based_recovery_"
                "production_route_ghost_positive_closure_v1"
            ),
            "gate_id": "QSDK-R24D88",
            "stage_id": "R24D88-GHOST",
            "closure_status": STATUS,
            "question_class": "development",
            "physical_question_declared": True,
            "behavior_success_required": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "source.commit": SOURCE,
            "source.parent_commit": "d7bc3fb122423731fb0efb6a9b74701408d9f1aa",
            "source.tree": "bd6d95b78d74520fd118a46476309c15429385b6",
            "source.subject": (
                "[recovery/godot] Close R88 qualification: authorize two-step "
                "force route"
            ),
        },
        "CLOSURE",
    )
    for flag, fmt in (("parent_commit", "%P"), ("tree", "%T"), ("subject", "%s")):
        exact(git(ROOT, "show", "-s", f"--format={fmt}", SOURCE),
              closure["source"][flag], f"SOURCE_{flag.upper()}")
    for binding in closure["source"]["bindings"]:
        verify_source_binding(ROOT, SOURCE, binding)

    verify_exact_paths(
        closure["authorization_dependency"],
        {
            "qualification_closure_raw_sha256": (
                "sha256:391cbfe09da219cae24f68a64c748703b81cf7a1034e6201f5ee33ec280647be"
            ),
            "qualification_source_freeze_commit": (
                "d7bc3fb122423731fb0efb6a9b74701408d9f1aa"
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
        gate_id="QSDK-R24D88",
        source_commit=SOURCE,
        status="valid_complete_integration_ghost",
        schemas={
            "attempt": "sporespore_qsdk_r24d88_route_attempt_v1",
            "raw": "sporespore_qsdk_r24d88_godot_force_based_recovery_route_raw_v1",
            "terminal": "sporespore_qsdk_r24d88_route_terminal_v1",
        },
        raw_count_keys=COUNT_KEYS,
    )
    raw, terminal = values["raw"], values["terminal"]
    verify_exact_paths(
        raw,
        {
            "ok": True,
            "actuator_mode": "force_based_joint_impulse_v1",
            "actuator_mapping_id": (
                "godot_jolt_r24d87_source_measured_force_based_joint_impulse_v1"
            ),
            "work_mapping_id": (
                "godot_jolt_r24d87_centered_source_measured_joint_work_v1"
            ),
            "native_scene_node_construction_attempted": True,
            "physical_question_opened": True,
            "physics_state_modified": True,
            "full_seeded_world_demo": False,
            "recovery_success_required": False,
            "all_in_run_physical_invariants_passed": True,
        },
        "RAW",
    )
    exact(terminal["completed_utc"], physical["completed_utc"], "TERMINAL_TIME")

    observed = closure["observed_integration"]
    initializer = raw["initializer_readback"]
    verify_exact_paths(
        initializer,
        {"ok": True, "body_readback_count": 9, "joint_readback_count": 8,
         "maximum_native_projection_to_readback_error_rad": 0.0,
         "writes_completed_before_first_solver_step": True},
        "INITIALIZER",
    )
    exact(initializer["initializer_manifest_sha256"], raw["initializer_manifest_sha256"],
          "INITIALIZER_BINDING")
    exact(initializer["native_projection_sha256"],
          observed["initializer_native_projection_sha256"], "INITIALIZER_PROJECTION")

    steps = verify_two_step_native_portable_route(
        raw, phase="establish_distal_support", joint_count=8
    )
    application = steps["first_step"]["application_intent"]
    verify_exact_paths(
        application,
        {"phase": "establish_distal_support", "semantic_step": 2,
         "source_control_semantic_step": 1},
        "APPLICATION_SEMANTICS",
    )
    force = verify_force_based_joint_impulse_application(
        application, actuator_mapping_id=raw["actuator_mapping_id"],
        work_mapping_id=raw["work_mapping_id"], joint_count=8
    )
    for observed_key, force_key in {
        "force_application_positive_impulse_count": "positive_impulse_count",
        "force_application_negative_impulse_count": "negative_impulse_count",
        "force_application_saturated_count": "saturated_count",
        "force_application_representation_projection_count": "representation_projection_count",
        "minimum_absolute_applied_impulse_nms": "minimum_absolute_applied_impulse_nms",
        "maximum_absolute_applied_impulse_nms": "maximum_absolute_applied_impulse_nms",
        "minimum_published_cap_nms": "minimum_published_cap_nms",
        "maximum_published_cap_nms": "maximum_published_cap_nms",
        "maximum_pairing_residual_component_nms": "maximum_pairing_residual_component_nms",
    }.items():
        exact(observed[observed_key], force[force_key], f"FORCE_{observed_key.upper()}")

    telemetry = steps["second_step"]["native_route"]["measurement"][
        "source_component_receipts"
    ]["telemetry_source_receipt"]
    work = verify_force_based_joint_work_source(
        telemetry, application_receipts=force["receipts"],
        actuator_mapping_id=raw["actuator_mapping_id"],
        work_mapping_id=raw["work_mapping_id"]
    )
    exact(
        (work["row_count"], work["positive_work_row_count"],
         work["absorbed_work_row_count"], work["net_motor_work_j"]),
        (observed["second_step_work_telemetry_row_count"],
         observed["second_step_positive_work_row_count"],
         observed["second_step_absorbed_work_row_count"],
         observed["second_step_net_motor_work_j"]),
        "WORK_PROJECTION",
    )

    projection = complete_in_run_physical_invariant_projection(raw)
    verify_exact_paths(
        closure["in_run_physical_invariants"],
        {
            **projection,
            "first_step_joint_observation_count": 8,
            "second_step_joint_observation_count": 8,
            "missing_measurement_synthesis_count": 0,
            "adapter_side_discrete_staging_event_count": 0,
            "initializer_exact_readback_passed": True,
            "native_step_results_ok": True,
            "portable_step_results_ok": True,
            "force_command_application_ok": True,
            "ordered_intent_receipt_equality_passed": True,
            "all_force_receipts_source_measured": True,
            "all_force_pairs_equal_and_opposite": True,
            "all_force_calls_returned": True,
            "all_force_axes_valid": True,
            "all_applied_impulses_at_or_below_published_caps": True,
            "all_centered_work_receipts_valid": True,
            "mechanical_energy_residual_used_as_work_source": False,
            "termination_protocol_valid": True,
        },
        "IN_RUN_INVARIANTS",
    )
    require(projection["all_raw_numeric_scalars_finite"] is True, "RAW_NUMERICS")
    require(projection["all_validity_fields_true"] is True, "RAW_VALIDITY")
    require(projection["all_source_measurement_flags_true"] is True,
            "RAW_SOURCE_MEASUREMENTS")
    exact(projection["external_intervention_total"], 0.0, "RAW_INTERVENTIONS")

    stdout = (Path(physical["evidence_root"]) / "godot.stdout.log").read_text(
        encoding="utf-8"
    )
    require_ordered_markers(
        stdout,
        ("Godot Engine v4.7.stable.custom_build",
         "QSDK_R24D88_GODOT_FORCE_BASED_RECOVERY_ROUTE_RAW ",
         '"status":"valid_complete_integration_ghost"',
         "QSDK_R24D88_GODOT_FORCE_BASED_RECOVERY_ROUTE_READY "),
        "STDOUT",
    )
    verify_exact_paths(
        observed,
        {"classification": (
             "valid_complete_godot_jolt_two_step_force_based_recovery_"
             "production_route"
         ), "native_observation_count": 2, "portable_collection_count": 2,
         "portable_control_plan_count": 2, "portable_command_application_count": 1,
         "ordered_command_count_per_plan": 8, "first_native_solver_step": 1,
         "second_native_solver_step": 2,
         "hard_constraint_motor_disabled_count": 8,
         "hard_constraint_motor_target_write_count": 0,
         "equal_and_opposite_body_impulse_write_count": 16,
         "force_application_readback_count": 8,
         "integration_refusal_observed": False,
         "infrastructure_failure_observed": False,
         "behavior_evaluator_invoked": False, "recovery_success_established": False,
         "prone_to_standing_established": False},
        "OBSERVED",
    )
    verify_boolean_partition(closure["decision"], DECISION_TRUE, DECISION_FALSE,
                             "DECISION")
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE,
                             "CLAIM")
    exact(closure["sdk_status"],
          {"sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
           "sdk1_total_steps": 20, "full_program_completed_steps": 11,
           "full_program_total_steps": 25}, "SDK_STATUS")
    verify_exact_paths(
        closure["next_boundary"],
        {"gate_id": "QSDK-R24D89",
         "question_class": "development_behavior_successor_not_yet_declared",
         "physical_execution_blocked": True, "maximum_world_attempt_count": 0,
         "maximum_world_build_count": 0, "maximum_physical_steps_authorized": 0,
         "complete_zero_world_gate_required": True,
         "distinct_clean_pushed_source_required": True,
         "r24d88_may_be_rerun_or_requalified": False,
         "held_out_cells_remain_sealed": True, "prone_to_standing_claimed": False,
         "physical_acceptance_authority": False, "release_authority": False},
        "NEXT",
    )

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--",
                      relative)
    revision = publication or None
    raw_closure = (CLOSURE.read_bytes() if revision is None
                   else source_bytes(ROOT, revision, relative))
    verify_legacy_live_gate_paths(
        ROOT, closure["live_authority_paths"], "QSDK-R24D45",
        {**closure["live_gate_expectations"],
         "r24d88_ghost_positive_closure_raw_sha256": sha256(raw_closure),
         "r24d88_ghost_positive_closure_byte_length": len(raw_closure)},
        revision=revision,
    )
    print(
        "QSDK_R24D88_GODOT_FORCE_BASED_RECOVERY_PRODUCTION_ROUTE_GHOST_"
        "POSITIVE_CLOSURE_PASS attempts=1 models=1 worlds=1 steps=2 "
        "commands=8 body_impulses=16 numerics=2842 validity=240/240 "
        "source_measurements=198/198 external_interventions=0 next=R24D89 "
        "sdk1=11/20"
    )


if __name__ == "__main__":
    audit()
