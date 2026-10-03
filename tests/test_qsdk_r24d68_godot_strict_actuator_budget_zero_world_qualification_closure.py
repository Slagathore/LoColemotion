"""Compact audit of the retained R24D68 zero-world qualification closure."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d68_godot_strict_actuator_budget_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "bb6bf958702ec7f398838bad156555cfffa3e2c9"
STATUS = (
    "closed_complete_zero_world_strict_actuator_budget_qualified_"
    "published_closure_control_required_physics_blocked"
)
PREDECESSOR_STATUS = (
    "closed_consumed_invalid_candidate_step_90_"
    "actuator_budget_predicate_mismatch"
)
CHECKS = (
    "core_dynamic_library_rebuilt",
    "core_targeted_tests_passed",
    "godot_adapter_binding_check_passed",
    "godot_adapter_debug_build_passed",
    "python_binding_smoke_passed",
    "versioning_conformance_passed",
    "source_contract_audit_passed",
    "production_preflight_passed",
    "worktree_unchanged",
)
TRUE = (
    "r67_invalid_result_preserved",
    "r67_same_identity_not_rerun",
    "r67_same_identity_not_requalified",
    "host_binary32_floor_projection_implemented",
    "all_host_caps_not_above_published",
    "rear_hip_floor_guards_proven",
    "strict_native_core_budget_predicate_identical",
    "zero_tolerance_budget_predicate_proven",
    "exact_rejected_budget_diagnostics_retained",
    "raw_measurement_forwarded_unchanged",
    "published_cap_unchanged",
    "historical_v1_telemetry_contract_unchanged",
    "portable_core_unchanged",
    "controller_unchanged",
    "evaluator_unchanged",
    "native_physics_unchanged",
    "behavior_semantics_unchanged",
    "zero_world_successor_qualified",
    "all_five_current_workers_passed",
    "supervisor_forced_failure_preserved",
    "missing_physical_switch_refusal_proven",
    "source_population_content_addressed",
    "retained_evidence_tree_content_addressed",
    "published_closure_control_required",
    "physical_execution_blocked_until_published_closure_control",
)
FALSE = (
    "r67_exact_measurement_reconstructed",
    "published_closure_control_executed",
    "physical_pair_authorized",
    "physical_attempted",
    "native_world_constructed",
    "solver_step_executed",
    "native_runtime_observation_collection_executed",
    "controller_behavior_evaluated",
    "valid_godot_behavior_result_observed",
    "exact_nominal_godot_prone_to_standing_observed",
    "prone_to_standing_claimed",
    "repeatability_rate_claimed",
    "population_claimed",
    "held_out_validation_claimed",
    "cross_engine_recovery_claimed",
    "cross_engine_equivalence_claimed",
    "sdk1_milestone_advanced",
    "physical_acceptance_authority",
    "release_authority",
)


def audit() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d68_godot_strict_actuator_budget_"
                "zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D68",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Freeze R68: strict actuator budget"
            ),
            source_binding_names=(
                "source_audit",
                "shared_controls",
                "native_world",
                "native_route",
                "core_runtime",
                "shared_qualifier",
                "shared_supervisor",
                "physical_binding",
                "zero_world_binding",
                "zero_world_worker",
                "behavior_worker",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d68_godot_strict_actuator_budget_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d68_godot_strict_actuator_budget_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d68-godot-strict-actuator-budget-qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(),
            physical_question_declared=True,
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D68_GODOT_STRICT_ACTUATOR_BUDGET_SOURCE_PASS"
                ),
                "cargo_targeted_tests.log": (
                    "test result: ok. 1 passed; 0 failed"
                ),
                "production_preflight.log": (
                    '"schema_version":"sporespore_qsdk_r24d68_godot_'
                    'strict_actuator_budget_preflight_v1"'
                ),
                "versioning_conformance.log": "Ran 1 test",
            },
        )
    )

    exact(
        (
            closure["predecessor"]["source_commit"],
            closure["predecessor"]["closure_commit"],
        ),
        (
            "001bd02a8314b3eb36db08a1570d83292353437c",
            "5a0414f145a60b114cca0385adf988c1effd02cc",
        ),
        "PREDECESSOR_COMMITS",
    )
    exact(
        closure["ledger_scope"],
        {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_qualification_closure",
            "question_class": "development",
        },
        "LEDGER_SCOPE",
    )
    verify_exact_paths(
        contract,
        {
            "gate_id": "QSDK-R24D68",
            "question_class": "development",
            "physical_question_declared": True,
            "finite_development_population.cell_count": 1,
            "finite_development_population.world_count": 2,
            "finite_development_population.arm_count": 2,
            "finite_development_population.cell_seed": 368340612,
            "finite_development_population.maximum_outer_steps_per_arm": 1200,
            "finite_development_population.maximum_total_outer_steps": 2400,
            "finite_development_population.same_source_attempt_limit": 1,
            "finite_development_population.held_out": False,
            "controlled_change.host_cap_representation_mapping_changed": True,
            "controlled_change.native_motor_telemetry_contract_changed": True,
            "controlled_change.native_motor_telemetry_v1_rewritten": False,
            "controlled_change.raw_measurement_clamping_added": False,
            "controlled_change.published_cap_changed": False,
            "controlled_change.portable_core_changed": False,
            "controlled_change.controller_changed": False,
            "controlled_change.evaluator_changed": False,
            "controlled_change.native_physics_or_jolt_patch_changed": False,
            "host_cap_projection_contract.selection_rule": (
                "greatest_binary32_value_not_above_the_unchanged_"
                "published_binary64_cap"
            ),
            "host_cap_projection_contract.rear_hip_floor_guard_count": 2,
            "host_cap_projection_contract.published_cap_changed": False,
            "host_cap_projection_contract.empirical_margin_added": False,
            "host_cap_projection_contract.raw_measurement_clamped": False,
            "strict_budget_predicate_contract.effective_tolerance_nms": 0.0,
            "strict_budget_predicate_contract.raw_measurement_forwarded_unchanged": True,
            "strict_budget_predicate_contract.r67_measurement_reconstructed_or_reinterpreted": False,
            "threshold_and_margin_provenance.threshold_change_count": 0,
            "threshold_and_margin_provenance.margin_change_count": 0,
            "critical_path_audit_policy.current_zero_world_worker_count": 5,
            "critical_path_audit_policy.historical_closure_audits_executed_count": 0,
            "critical_path_audit_policy.scheduled_historical_regression_cadence_replaced_or_waived": False,
            "ghost_and_canary_adequacy.additional_physical_route_ghost_required": False,
            "ghost_and_canary_adequacy.full_seeded_physical_ghost_required": False,
            "complete_zero_world_gate.official_qualification_run_count": 1,
            "complete_zero_world_gate.r68_host_projection_control_count": 8,
            "complete_zero_world_gate.r68_rear_binary32_floor_guard_count": 2,
            "complete_zero_world_gate.r68_strict_boundary_case_count": 8,
            "complete_zero_world_gate.r68_native_core_agreement_count": 8,
            "complete_zero_world_gate.r68_identity_order_mutation_rejection_count": 6,
            "complete_zero_world_gate.r68_disagreement_mutation_rejection_count": 1,
            "physical_authorization_projection.maximum_model_construction_count": 2,
            "physical_authorization_projection.maximum_world_build_count": 2,
            "physical_authorization_projection.maximum_outer_solver_steps": 2400,
            "physical_authorization_projection.physical_execution_authorized": False,
            "next_boundary.maximum_physical_steps_authorized": 0,
        },
        "CONTRACT",
    )
    exact(len(contract["source_inventory"]), 116, "SOURCE_COUNT")

    verify_exact_paths(
        preflight,
        {
            "schema_version": (
                "sporespore_qsdk_r24d68_godot_strict_actuator_budget_"
                "preflight_v1"
            ),
            "runtime_id": (
                "sporespore_qsdk_r24d68_godot_strict_actuator_budget_v1"
            ),
            "runtime_version": "godot_4_7_jolt_instrumented_v2_exact_binary_pair",
            "source_inventory_count": 116,
            "bound_predecessor_count": 1,
            "current_zero_world_worker_count": 5,
            "historical_closure_audits_executed_count": 0,
            "host_projection_control_count": 8,
            "rear_binary32_floor_guard_count": 2,
            "strict_boundary_case_count": 8,
            "native_core_agreement_count": 8,
            "identity_order_mutation_rejection_count": 6,
            "disagreement_mutation_rejection_count": 1,
            "r68_strict_actuator_budget_receipt.host_cap_not_above_published_count": 8,
            "r68_strict_actuator_budget_receipt.native_acceptance_count": 4,
            "r68_strict_actuator_budget_receipt.native_rejection_count": 4,
            "r68_strict_actuator_budget_receipt.core_acceptance_count": 4,
            "r68_strict_actuator_budget_receipt.core_rejection_count": 4,
            "r68_strict_actuator_budget_receipt.exact_diagnostic_count": 8,
            "r68_strict_actuator_budget_receipt.nonfinite_rejection_count": 1,
            "r68_strict_actuator_budget_receipt.strict_host_cap_guard_receipt.validated_actuator_count": 8,
            "r68_strict_actuator_budget_receipt.r67_like_upward_binary32_rejection_diagnostic.absolute_budget_delta_nms": 6.351814976768289e-10,
            "r68_strict_actuator_budget_receipt.r67_like_upward_binary32_rejection_diagnostic.legacy_v1_budget_predicate_decision": True,
            "r68_strict_actuator_budget_receipt.r67_like_upward_binary32_rejection_diagnostic.native_v2_strict_budget_decision": False,
            "r68_strict_actuator_budget_receipt.r67_like_upward_binary32_rejection_diagnostic.projected_core_strict_budget_decision": False,
            "r68_strict_actuator_budget_receipt.r67_like_upward_binary32_rejection_diagnostic.raw_measurement_modified": False,
            "supervisor_forced_failure_control_count": 1,
            "supervisor_projection_receipt.status": "forced_failure_projection_control",
            "missing_physical_switch_refusal_count": 1,
            "additional_physical_route_ghost_required": False,
            "full_seeded_physical_ghost_required": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_question_opened": False,
            "prone_to_standing_claimed": False,
        },
        "PREFLIGHT",
    )

    qualification = closure["qualification"]
    exact(
        (
            qualification["check_count"],
            qualification["checks_passed"],
            qualification["source_inventory_count"],
            qualification["retained_tree"]["file_count"],
            qualification["current_zero_world_worker_count"],
            qualification["historical_closure_audits_executed_count"],
            qualification["host_projection_control_count"],
            qualification["strict_boundary_case_count"],
            qualification["identity_order_mutation_rejection_count"],
            receipt["held_out_cell_access_count"],
        ),
        (9, 9, 116, 9, 5, 0, 8, 8, 6, 0),
        "QUALIFICATION_COUNTS",
    )

    expected_projection = dict(contract["physical_authorization_projection"])
    expected_projection.update(
        zero_world_qualification_passed=True,
        source_freeze_commit=SOURCE,
        physical_execution_authorized=True,
    )
    exact(
        closure["physical_authorization"],
        expected_projection,
        "PHYSICAL_AUTHORIZATION",
    )

    decision = closure["decision"]
    verify_exact_paths(
        decision,
        {
            "result": "positive_zero_world_strict_actuator_budget_qualified",
            "new_behavior_threshold_count": 0,
            "new_empirical_threshold_count": 0,
            "new_margin_count": 0,
            "observed_physical_cohort_count": 0,
            "held_out_cohort_count": 0,
            "population_claim_count": 0,
        },
        "DECISION",
    )
    verify_boolean_partition(decision, TRUE, FALSE, "DECISION")
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
            "gate_id": "QSDK-R24D68",
            "question_class": "development",
            "mode": "AuthorizationControl",
            "exact_control_execution_limit": 1,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "maximum_physical_steps_authorized": 0,
            "held_out": False,
            "same_identity_rerun_permitted": False,
            "physical_execution_authorized": False,
        },
        "NEXT",
    )

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative
    )
    assert isinstance(publication, str)
    revision = publication or None
    raw = (
        CLOSURE.read_bytes()
        if revision is None
        else source_bytes(ROOT, revision, relative)
    )
    live = {
        **closure["live_gate_expectations"],
        "r24d68_zero_world_closure_raw_sha256": sha256(raw),
    }
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        live,
        revision=revision,
    )
    print(
        "QSDK_R24D68_GODOT_STRICT_ACTUATOR_BUDGET_ZERO_WORLD_"
        "QUALIFICATION_CLOSURE_PASS sources=116 checks=9/9 retained=9 "
        "workers=5 historical_audits=0 projections=8 floor_guards=2 "
        "boundaries=8 mutations=7 models=0 worlds=0 steps=0 "
        "authorization_control_required=1 physics_authorized=0 sdk1=11/20"
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
            "QSDK_R24D68_GODOT_STRICT_ACTUATOR_BUDGET_ZERO_WORLD_"
            f"QUALIFICATION_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
