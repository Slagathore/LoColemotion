"""Compact audit of the retained zero-world QSDK-R24D39 closure."""

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
    ROOT
    / "sdk/recovery/r24d39_recovery_observation_v2_consumer_qualification_closure_v1.json"
)
SOURCE = "bb312b13934362c144eb98e628d5ad2082ba950c"
GATE = "QSDK-R24D39"
SCHEMA = (
    "sporespore_qsdk_r24d39_recovery_observation_v2_consumer_"
    "qualification_closure_v1"
)
STATUS = (
    "closed_complete_zero_world_recovery_observation_v2_consumer_"
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
    "result": "positive_true_observation_v2_public_consumer_family_and_mujoco_route_source_qualified_zero_world",
    "portable_observation_schema": "sporespore_recovery_observation_v2",
    "source_binding_schema": "sporespore_recovery_observation_v2_source_binding_v1",
    "native_collection_request_schema": "sporespore_recovery_native_collection_request_v3",
    "native_collection_receipt_schema": "sporespore_recovery_native_collection_receipt_v2",
    "supervisor_step_request_schema": "sporespore_recovery_step_request_v3",
    "paired_trace_schema": "sporespore_recovery_trace_v2",
    "paired_evaluation_request_schema": "sporespore_recovery_evaluation_request_v3",
    "control_request_schema": "sporespore_recovery_control_request_v3",
    "publication_route_id": "sporespore_mujoco_exact_s169_recovery_observation_v2_consumer_v1",
    "portable_observation_v2_consumed_by_public_collector": True,
    "portable_observation_v2_consumed_by_public_supervisor": True,
    "portable_observation_v2_consumed_by_public_controller": True,
    "portable_observation_v2_consumed_by_public_paired_evaluator": True,
    "source_chain_content_addressed": True,
    "source_binding_mutations_fail_closed": True,
    "unsupported_engine_typed_refusal_qualified": True,
    "native_route_v2_observation_publication_source_implemented": True,
    "native_route_v2_observation_physically_published": False,
    "historical_observation_v1_meanings_changed": False,
    "historical_r24d36_preprojection_refusal_changed": False,
    "lossy_observation_v2_to_v1_projection_used": False,
    "signed_constraint_exchange_relabelled": False,
    "new_c_abi_symbol_count": 4,
    "total_c_abi_symbol_count": 48,
    "schema_registry_entry_count": 76,
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
    "r24d39_closed_without_physics": True,
    "r24d39_physical_execution_permitted": False,
}
NEXT_BOUNDARY = {
    "gate_id": "QSDK-R24D40",
    "question_class": "development",
    "status": "distinct_native_mujoco_observation_v2_execution_smoke_contract_required_physics_blocked",
    "work": "declare_the_smallest_distinct_native_mujoco_observation_v2_execution_smoke_with_in_run_invariants_before_any_finite_recovery_behavior_question",
    "physical_question_declared_here": False,
    "behavior_question_declared_here": False,
    "successor_must_declare_its_own_physical_question_and_budget": True,
    "distinct_clean_pushed_source_freeze_required": True,
    "complete_zero_world_route_gate_required": True,
    "maximum_physical_steps_authorized_here": 0,
    "full_seeded_ghost_required_here": False,
    "additional_physical_canary_required_here": False,
    "r24d40_physical_execution_authorized": False,
    "r24d39_may_be_requalified": False,
    "r24d38_may_be_requalified": False,
    "held_out_cells_remain_sealed": True,
    "prone_to_standing_claimed": False,
    "physical_acceptance_authority": False,
    "release_authority": False,
}
CLAIMS = {
    "official_zero_world_qualification_passed": True,
    "true_observation_v2_public_consumer_family_qualified": True,
    "portable_observation_v2_consumed_by_public_collector": True,
    "portable_observation_v2_consumed_by_public_supervisor": True,
    "portable_observation_v2_consumed_by_public_controller": True,
    "portable_observation_v2_consumed_by_public_paired_evaluator": True,
    "source_chain_content_addressing_qualified": True,
    "binding_schema_engine_and_legacy_mutations_fail_closed": True,
    "native_route_v2_observation_publication_source_implemented": True,
    "native_route_v2_observation_physically_published": False,
    "native_physical_consumer_proven": False,
    "new_physical_observation_made": False,
    "physical_measurement_adequacy_established": False,
    "energy_residual_within_threshold_observed": False,
    "recovery_progression_proven": False,
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
            source_subject=(
                "[recovery/core+mujoco] Freeze R24D39 observation-v2 consumer"
            ),
            source_binding_names=(
                "core",
                "publisher",
                "fixture",
                "native_route",
                "preflight",
                "source_audit",
                "wrapper",
                "shared_runner",
            ),
            predecessor_status=(
                "closed_complete_zero_world_native_energy_v2_mapping_"
                "qualified_no_physical_question"
            ),
            attempt_schema=(
                "sporespore_qsdk_r24d39_recovery_observation_v2_consumer_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d39_recovery_observation_v2_consumer_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix="qsdk-r24d39-qualification-",
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
                    "QSDK_R24D39_RECOVERY_OBSERVATION_V2_CONSUMER_SOURCE_PASS"
                ),
                "cargo_targeted_tests.log": "3 passed; 0 failed",
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
                "prospective_observation_v2_consumer_source_zero_world_"
                "development_passed_physics_blocked_pending_qualification"
            ),
            "physical_question_declared": False,
            "versioned_consumer_contract.portable_observation_schema": (
                "sporespore_recovery_observation_v2"
            ),
            "source_binding.source_chain_sha256_required": True,
            "mujoco_route_consumer.publication_route_id": (
                "sporespore_mujoco_exact_s169_recovery_observation_v2_consumer_v1"
            ),
            "complete_zero_world_gate.required_control_count": 8,
            "source_inventory_strategy.source_inventory_count": 27,
        },
        "CONTRACT",
    )
    verify_exact_paths(
        preflight,
        {
            "control_count": 8,
            "controls_passed": 8,
            "forced_failure_count": 8,
            "typed_refusal_count": 1,
            "public_c_abi_symbol_count": 48,
            "schema_registry_entry_count": 76,
            "portable_observation_sha256": "sha256:69d7382a22e2cd9964ac90a33a31e2a44c0b38ed006405b75cb2dbbb4caf6fde",
            "observation_source_binding_sha256": "sha256:2e1801a3bfbe9e19f6b82ce0d13e21f77175a4512b4b3806a7d6e306d63eeb60",
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
            "qualification.targeted_core_test_count": 3,
            "qualification.python_route_test_count": 1,
            "qualification.versioning_test_count": 1,
            "qualification.forced_failure_count": 8,
            "qualification.typed_refusal_count": 1,
            "qualification.public_c_abi_symbol_count": 48,
            "qualification.schema_registry_entry_count": 76,
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
        "QSDK_R24D39_RECOVERY_OBSERVATION_V2_CONSUMER_QUALIFICATION_CLOSURE_PASS "
        "sources=27 controls=8/8 forced_failures=8 refusals=1 abi=48 "
        "schemas=76 models=0 worlds=0 solver_steps=0 physical=false "
        "sdk1=11/20 next=QSDK-R24D40"
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
            "QSDK_R24D39_RECOVERY_OBSERVATION_V2_CONSUMER_QUALIFICATION_CLOSURE_FAIL "
            f"{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
