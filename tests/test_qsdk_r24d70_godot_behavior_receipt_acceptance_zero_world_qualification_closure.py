"""Compact semantic audit over the shared retained R70 closure verifier."""

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
    "sdk/recovery/r24d70_godot_behavior_receipt_acceptance_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "6312e361ffd4c841a98d54d78fb36e13966a7c41"
STATUS = (
    "closed_complete_zero_world_behavior_receipt_acceptance_qualified_"
    "published_closure_control_required_physics_blocked"
)
PREDECESSOR_STATUS = (
    "closed_consumed_invalid_positive_only_worker_evaluator_receipt_"
    "acceptance_predicate"
)
CHECKS = """
core_dynamic_library_rebuilt core_targeted_tests_passed
godot_adapter_binding_check_passed godot_adapter_debug_build_passed
python_binding_smoke_passed versioning_conformance_passed
source_contract_audit_passed production_preflight_passed worktree_unchanged
""".split()
SOURCE_BINDINGS = """
source_audit shared_controls native_world native_route core_runtime
shared_qualifier shared_supervisor physical_binding zero_world_binding
zero_world_worker behavior_worker
""".split()
TRUE = """
r69_invalid_result_preserved r69_same_identity_not_rerun
r69_same_identity_not_requalified verdict_aware_consumer_predicate_qualified
positive_negative_and_incomplete_outcomes_accepted
refused_and_malformed_outcomes_fail_closed_invalid
terminal_invariant_populations_content_addressed portable_core_unchanged
controller_unchanged evaluator_unchanged native_physics_unchanged
zero_world_successor_qualified all_six_current_workers_passed
supervisor_forced_failure_preserved missing_physical_switch_refusal_proven
source_population_content_addressed retained_evidence_tree_content_addressed
published_closure_control_required
physical_execution_blocked_until_published_closure_control
""".split()
FALSE = """
r69_result_reclassified threshold_changed margin_added
published_closure_control_executed physical_pair_authorized physical_attempted
native_world_constructed solver_step_executed controller_behavior_evaluated
valid_godot_behavior_result_observed
exact_nominal_godot_prone_to_standing_observed prone_to_standing_claimed
repeatability_rate_claimed population_claimed held_out_validation_claimed
cross_engine_recovery_claimed cross_engine_equivalence_claimed
sdk1_milestone_advanced physical_acceptance_authority release_authority
""".split()


def audit() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d70_godot_behavior_receipt_acceptance_"
                "zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D70",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Freeze R70 consumer: verdict-aware evidence"
            ),
            source_binding_names=SOURCE_BINDINGS,
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d70_godot_behavior_receipt_acceptance_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d70_godot_behavior_receipt_acceptance_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d70-godot-behavior-receipt-acceptance-qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(
                {
                    "path": (
                        "sdk/adapters/godot/"
                        "sporespore_locomotion.gdextension.uid"
                    ),
                    "representation": "clean_windows_text_auto_checkout_crlf",
                    "reason": (
                        "catch_all_text_auto_has_no_explicit_eol_rule_for_"
                        "uid_suffix"
                    ),
                },
            ),
            physical_question_declared=True,
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D70_GODOT_BEHAVIOR_RECEIPT_ACCEPTANCE_SOURCE_PASS"
                ),
                "cargo_targeted_tests.log": "test result: ok. 1 passed; 0 failed",
                "production_preflight.log": (
                    '"schema_version":"sporespore_qsdk_r24d70_godot_'
                    'behavior_receipt_acceptance_preflight_v1"'
                ),
                "versioning_conformance.log": "Ran 1 test",
            },
        )
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
    exact(
        (
            closure["predecessor"]["source_commit"],
            closure["predecessor"]["closure_commit"],
        ),
        (
            "1fd9b510c20d58bb35ffe508113b5de2b22d714c",
            "6db52f606f74cea6a7bfeeaa1370c52e504deb53",
        ),
        "PREDECESSOR_COMMITS",
    )
    verify_exact_paths(
        contract,
        {
            "ledger_scope.question_class": "development",
            "finite_development_population.cell_seed": 278151771,
            "finite_development_population.maximum_total_outer_steps": 2400,
            "finite_development_population.held_out": False,
            "controlled_change.worker_evaluation_receipt_consumer_predicate_changed": True,
            "controlled_change.terminal_arm_invariant_summary_added": True,
            "controlled_change.portable_core_changed": False,
            "controlled_change.portable_evaluator_changed": False,
            "controlled_change.recovery_controller_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.actuator_cap_changed": False,
            "controlled_change.native_physics_or_jolt_patch_changed": False,
            "receipt_acceptance_contract.common_check_count": 22,
            "receipt_acceptance_contract.verdict_check_count": 9,
            "receipt_acceptance_contract.refused_or_malformed_scientific_outcome": "invalid",
            "receipt_acceptance_contract.malformed_mutation_count": 17,
            "terminal_invariant_summary_contract.terminal_summary_fixture_count": 3,
            "terminal_invariant_summary_contract.summary_mutation_count": 6,
            "critical_path_audit_policy.current_zero_world_worker_count": 6,
            "critical_path_audit_policy.historical_closure_audits_executed_count": 0,
            "ghost_and_canary_adequacy.additional_physical_route_ghost_required": False,
            "ghost_and_canary_adequacy.full_seeded_physical_ghost_required": False,
            "physical_authorization_projection.maximum_outer_solver_steps": 2400,
            "physical_authorization_projection.physical_execution_authorized": False,
        },
        "CONTRACT",
    )
    exact(len(contract["source_inventory"]), 147, "SOURCE_COUNT")
    verify_exact_paths(
        preflight,
        {
            "source_inventory_count": 147,
            "bound_predecessor_count": 1,
            "current_zero_world_worker_count": 6,
            "historical_closure_audits_executed_count": 0,
            "accepted_outcome_fixture_count": 3,
            "receipt_mutation_rejection_count": 17,
            "terminal_summary_fixture_count": 3,
            "summary_mutation_rejection_count": 6,
            "r70_receipt_acceptance_receipt.r69_failure_shape_accepted": True,
            "r70_receipt_acceptance_receipt.positive_acceptance_count": 1,
            "r70_receipt_acceptance_receipt.negative_acceptance_count": 1,
            "r70_receipt_acceptance_receipt.incomplete_acceptance_count": 1,
            "r70_receipt_acceptance_receipt.full_summary_arm_count": 2,
            "r70_receipt_acceptance_receipt.full_summary_invariant_count": 5,
            "supervisor_projection_receipt.status": (
                "forced_failure_projection_control"
            ),
            "missing_physical_switch_refusal_count": 1,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_question_opened": False,
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
            qualification["accepted_outcome_fixture_count"],
            qualification["receipt_mutation_rejection_count"],
            qualification["summary_mutation_rejection_count"],
            receipt["held_out_cell_access_count"],
        ),
        (9, 9, 147, 9, 6, 0, 3, 17, 6, 0),
        "QUALIFICATION_COUNTS",
    )
    expected = dict(contract["physical_authorization_projection"])
    expected.update(
        zero_world_qualification_passed=True,
        source_freeze_commit=SOURCE,
        physical_execution_authorized=True,
    )
    exact(closure["physical_authorization"], expected, "AUTHORIZATION")
    verify_exact_paths(
        closure["decision"],
        {
            "result": "positive_zero_world_behavior_receipt_acceptance_qualified",
            "new_behavior_threshold_count": 0,
            "new_empirical_threshold_count": 0,
            "new_margin_count": 0,
            "observed_physical_cohort_count": 0,
            "held_out_cohort_count": 0,
            "population_claim_count": 0,
        },
        "DECISION",
    )
    verify_boolean_partition(closure["decision"], TRUE, FALSE, "DECISION")
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
            "mode": "AuthorizationControl",
            "exact_control_execution_limit": 1,
            "maximum_physical_steps_authorized": 0,
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
    raw = CLOSURE.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        {
            **closure["live_gate_expectations"],
            "r24d70_zero_world_closure_raw_sha256": sha256(raw),
        },
        revision=revision,
    )
    print(
        "QSDK_R24D70_GODOT_BEHAVIOR_RECEIPT_ACCEPTANCE_ZERO_WORLD_"
        "QUALIFICATION_CLOSURE_PASS sources=147 checks=9/9 retained=9 "
        "workers=6 historical_audits=0 outcomes=3 receipt_mutations=17 "
        "summary_mutations=6 models=0 worlds=0 steps=0 control_required=1 "
        "physics_authorized=0 sdk1=11/20"
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
            "QSDK_R24D70_GODOT_BEHAVIOR_RECEIPT_ACCEPTANCE_ZERO_WORLD_"
            f"QUALIFICATION_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
