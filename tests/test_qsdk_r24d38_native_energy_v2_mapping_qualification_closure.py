"""Compact audit of the retained zero-world QSDK-R24D38 closure."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
)


CLOSURE_PATH = (
    ROOT / "sdk/recovery/r24d38_native_energy_v2_mapping_qualification_closure_v1.json"
)
SOURCE = "5ff284ae77486be4007698add327445ffa1a5cc0"
GATE = "QSDK-R24D38"
SCHEMA = "sporespore_qsdk_r24d38_native_energy_v2_mapping_qualification_closure_v1"
STATUS = (
    "closed_complete_zero_world_native_energy_v2_mapping_"
    "qualified_no_physical_question"
)
EXPECTED_CHECKS = (
    "core_dynamic_library_rebuilt",
    "core_targeted_tests_passed",
    "godot_adapter_binding_check_passed",
    "python_binding_smoke_passed",
    "versioning_conformance_passed",
    "source_contract_audit_passed",
    "production_preflight_passed",
    "worktree_unchanged",
)
DECISION = {
    "result": "positive_native_component_to_engine_neutral_ledger_v2_mapping_and_portable_observation_v2_qualified_zero_world",
    "source_route_id": "sporespore_mujoco_exact_s169_native_recovery_implicit_step_energy_v3",
    "mapping_profile_id": "mujoco_r24d36_native_components_to_recovery_energy_v2_v1",
    "ledger_schema": "sporespore_recovery_energy_balance_ledger_v2",
    "portable_observation_schema": "sporespore_recovery_observation_v2",
    "complete_native_component_receipt_replay_qualified": True,
    "contiguous_native_substep_order_qualified": True,
    "repeated_outer_semantic_steps_retained": True,
    "both_constraint_exchange_signs_retained": True,
    "actuator_constraint_external_and_passive_partition_qualified": True,
    "source_population_content_addressed": True,
    "ledger_content_addressed": True,
    "portable_observation_content_addressed": True,
    "unqualified_passive_work_typed_refusal_qualified": True,
    "unmeasured_external_work_typed_refusal_qualified": True,
    "historical_v1_route_changed": False,
    "current_v1_collector_changed": False,
    "current_v1_evaluator_changed": False,
    "portable_observation_v2_accepted_by_current_evaluator": False,
    "native_route_v2_observation_published": False,
    "mujoco_imported_by_mapping": False,
    "numpy_imported_by_mapping": False,
    "mechanical_energy_change_used_as_work_source": False,
    "energy_balance_residual_used_as_work_source": False,
    "absolute_value_or_clamp_used": False,
    "new_behavior_threshold_count": 0,
    "new_empirical_threshold_count": 0,
    "new_margin_count": 0,
    "physical_cohort_count": 0,
    "held_out_cohort_count": 0,
    "population_claim_count": 0,
    "controller_changed": False,
    "native_physics_changed": False,
    "morphology_changed": False,
    "initializer_changed": False,
    "r24d38_closed_without_physics": True,
    "r24d38_physical_execution_permitted": False,
}
NEXT_BOUNDARY = {
    "gate_id": "QSDK-R24D39",
    "question_class": "development",
    "status": "observation_v2_consumer_contract_required_physics_blocked",
    "work": "declare_and_zero_world_qualify_a_distinct_observation_v2_collector_evaluator_and_mujoco_route_consumer_before_any_physical_recovery_question",
    "physical_question_declared": False,
    "behavior_question_declared": False,
    "distinct_clean_pushed_source_freeze_required": True,
    "complete_zero_world_route_gate_required": True,
    "maximum_physical_steps_authorized": 0,
    "full_seeded_ghost_required": False,
    "additional_physical_canary_required": False,
    "r24d39_physical_execution_authorized": False,
    "r24d38_may_be_requalified": False,
    "r24d37_may_be_requalified": False,
    "held_out_cells_remain_sealed": True,
    "prone_to_standing_claimed": False,
    "physical_acceptance_authority": False,
    "release_authority": False,
}
CLAIMS = {
    "official_zero_world_qualification_passed": True,
    "native_component_mapping_qualified": True,
    "ordered_substep_to_ledger_v2_qualified": True,
    "positive_and_negative_constraint_mapping_qualified": True,
    "portable_observation_v2_construction_qualified": True,
    "mapping_receipt_and_observation_content_addressed": True,
    "typed_passive_and_external_refusals_qualified": True,
    "r24d38_closed_without_physics": True,
    "portable_observation_v2_consumed_by_recovery_evaluator": False,
    "native_route_v2_observation_published": False,
    "new_physical_observation_made": False,
    "physical_measurement_adequacy_established": False,
    "energy_residual_within_threshold_observed": False,
    "recovery_to_stance_handoff_observed": False,
    "controller_physical_viability_proven": False,
    "prone_to_standing_claimed": False,
    "repeatability_rate_claimed": False,
    "population_claimed": False,
    "held_out_validation_claimed": False,
    "cross_engine_recovery_claimed": False,
    "cross_engine_equivalence_claimed": False,
    "sdk1_milestone_advanced": False,
    "physical_acceptance_authority": False,
    "release_authority": False,
}


def audit() -> None:
    closure, contract, _receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE_PATH,
            schema_version=SCHEMA,
            gate_id=GATE,
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject="[recovery/mujoco] Freeze R24D38 energy-v2 mapping",
            source_binding_names=(
                "mapping",
                "fixture",
                "preflight",
                "source_audit",
                "wrapper",
                "shared_runner",
            ),
            predecessor_status=(
                "closed_complete_zero_world_engine_neutral_signed_exchange_"
                "ledger_qualified_no_physical_question"
            ),
            attempt_schema=(
                "sporespore_qsdk_r24d38_native_energy_v2_mapping_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d38_native_energy_v2_mapping_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix="qsdk-r24d38-qualification-",
            expected_checks=EXPECTED_CHECKS,
            checkout_only_metadata=(
                {
                    "path": "sdk/adapters/mujoco/README.md",
                    "reason": (
                        "mixed_crlf_lf_windows_checkout_clean_filter_"
                        "normalized_to_canonical_lf_git_blob"
                    ),
                    "source_semantics_changed": False,
                },
            ),
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D38_NATIVE_ENERGY_V2_MAPPING_SOURCE_PASS"
                ),
                "cargo_targeted_tests.log": "9 passed; 0 failed",
                "python_binding_smoke.log": "Ran 1 test",
                "versioning_conformance.log": "Ran 1 test",
            },
        )
    )
    verify_exact_paths(
        contract,
        {
            "gate_id": GATE,
            "status": (
                "prospective_native_energy_v2_mapping_source_zero_world_"
                "development_passed_physics_blocked_pending_qualification"
            ),
            "physical_question_declared": False,
            "mapping_semantics.mapping_profile_id": (
                "mujoco_r24d36_native_components_to_recovery_energy_v2_v1"
            ),
            "portable_observation_v2.schema_version": (
                "sporespore_recovery_observation_v2"
            ),
            "complete_zero_world_gate.required_control_count": 9,
            "source_inventory_strategy.source_inventory_count": 17,
        },
        "CONTRACT",
    )
    verify_exact_paths(
        preflight,
        {
            "control_count": 9,
            "controls_passed": 9,
            "native_component_batch_count": 2,
            "native_component_receipt_count": 10,
            "forced_failure_count": 5,
            "typed_refusal_count": 2,
            "source_component_receipts_sha256": "sha256:05452158922b2f2d6fcdbe60aed78312ffd5d685997d162f3318f02d59adedff",
            "ordered_source_values_sha256": "sha256:892e46d5d1642d3f3eb7b6fc0052bbff5699a682b8393e222c70599b24bfa771",
            "ledger_sha256": "sha256:5f073c29d80f14bfee30756090318ec5f1924321656e8870b566d31779e026b4",
            "portable_observation_sha256": "sha256:b4f9e178ab8cae65512606e55c3c4a55fa468651fbf0670fa9119605ae2d98b1",
        },
        "PREFLIGHT",
    )
    exact(
        preflight["controls"],
        {
            key: True
            for key in contract["complete_zero_world_gate"]["required_controls"]
        },
        "PREFLIGHT_CONTROLS",
    )
    verify_exact_paths(
        closure,
        {
            "qualification.targeted_core_test_count": 9,
            "qualification.python_mapping_test_count": 1,
            "qualification.versioning_test_count": 1,
            "qualification.native_component_batch_count": 2,
            "qualification.native_component_receipt_count": 10,
            "qualification.forced_failure_count": 5,
            "qualification.typed_refusal_count": 2,
            "sdk_status": {
                "sdk1_milestone_advanced": False,
                "sdk1_completed_steps": 11,
                "sdk1_total_steps": 20,
                "full_program_completed_steps": 11,
                "full_program_total_steps": 25,
            },
            "decision": DECISION,
            "next_boundary": NEXT_BOUNDARY,
            "claim_boundary": CLAIMS,
        },
        "CLOSURE",
    )
    print(
        "QSDK_R24D38_NATIVE_ENERGY_V2_MAPPING_QUALIFICATION_CLOSURE_PASS "
        "sources=17 controls=9/9 receipts=10 forced_failures=5 refusals=2 "
        "models=0 worlds=0 solver_steps=0 physical=false sdk1=11/20 "
        "next=QSDK-R24D39"
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
            "QSDK_R24D38_NATIVE_ENERGY_V2_MAPPING_QUALIFICATION_CLOSURE_FAIL "
            f"{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
