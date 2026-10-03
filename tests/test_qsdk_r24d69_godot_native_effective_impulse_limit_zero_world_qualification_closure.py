"""Thin semantic audit over the shared retained zero-world closure verifier."""

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
    "sdk/recovery/r24d69_godot_native_effective_impulse_limit_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "a2587f18934df5c58efb25547a077d2e57568e7e"
STATUS = (
    "closed_complete_zero_world_native_effective_impulse_limit_qualified_"
    "published_closure_control_required_physics_blocked"
)
PREDECESSOR_STATUS = (
    "closed_consumed_invalid_candidate_step_90_one_binary32_ulp_"
    "native_effective_limit_reexpansion"
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
r68_invalid_result_preserved r68_same_identity_not_rerun
r68_same_identity_not_requalified
native_effective_impulse_limit_projection_implemented
all_eight_selected_limits_safe all_eight_adjacent_limits_unsafe
binary32_maximality_proven source_algebra_identity_proven
production_route_projection_proven production_route_safe_readback_proven
shared_binary32_controls_reused strict_native_core_budget_predicate_inherited
raw_measurement_forwarded_unchanged published_cap_unchanged portable_core_unchanged
controller_unchanged evaluator_unchanged native_physics_unchanged
behavior_semantics_unchanged zero_world_successor_qualified
all_five_current_workers_passed supervisor_forced_failure_preserved
missing_physical_switch_refusal_proven source_population_content_addressed
retained_evidence_tree_content_addressed published_closure_control_required
physical_execution_blocked_until_published_closure_control
""".split()
FALSE = """
empirical_margin_added r68_result_reclassified published_closure_control_executed
physical_pair_authorized physical_attempted native_world_constructed
solver_step_executed native_runtime_observation_collection_executed
controller_behavior_evaluated valid_godot_behavior_result_observed
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
                "sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_"
                "zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D69",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Implement R69: native effective cap projection"
            ),
            source_binding_names=SOURCE_BINDINGS,
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d69_godot_native_effective_impulse_limit_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d69-godot-native-effective-impulse-limit-qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(),
            physical_question_declared=True,
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D69_GODOT_NATIVE_EFFECTIVE_IMPULSE_LIMIT_SOURCE_PASS"
                ),
                "cargo_targeted_tests.log": "test result: ok. 1 passed; 0 failed",
                "production_preflight.log": (
                    '"schema_version":"sporespore_qsdk_r24d69_godot_native_'
                    'effective_impulse_limit_preflight_v1"'
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
            "a5414e1ba18b698e550dabb0e39b066c0ae29ff1",
            "c1df9320ce6074017efe2081cfa350301c816622",
        ),
        "PREDECESSOR_COMMITS",
    )
    verify_exact_paths(
        contract,
        {
            "ledger_scope.question_class": "development",
            "finite_development_population.cell_seed": 739575220,
            "finite_development_population.maximum_total_outer_steps": 2400,
            "finite_development_population.held_out": False,
            "controlled_change.native_effective_impulse_limit_projection_added": True,
            "controlled_change.published_cap_changed": False,
            "controlled_change.native_physics_or_jolt_patch_changed": False,
            "controlled_change.portable_core_changed": False,
            "controlled_change.controller_changed": False,
            "controlled_change.evaluator_changed": False,
            "native_effective_impulse_limit_projection_contract.projection_id": (
                "godot_jolt_binary32_native_effective_impulse_limit_"
                "inverse_projection_v1"
            ),
            "native_effective_impulse_limit_projection_contract.selected_effective_limit_not_above_published_count": 8,
            "native_effective_impulse_limit_projection_contract.immediately_higher_effective_limit_above_published_count": 8,
            "native_effective_impulse_limit_projection_contract.binary32_maximality_proof_count": 8,
            "native_effective_impulse_limit_projection_contract.empirical_margin_added": False,
            "critical_path_audit_policy.current_zero_world_worker_count": 5,
            "critical_path_audit_policy.historical_closure_audits_executed_count": 0,
            "ghost_and_canary_adequacy.additional_physical_route_ghost_required": False,
            "ghost_and_canary_adequacy.full_seeded_physical_ghost_required": False,
            "physical_authorization_projection.maximum_outer_solver_steps": 2400,
            "physical_authorization_projection.physical_execution_authorized": False,
        },
        "CONTRACT",
    )
    exact(len(contract["source_inventory"]), 124, "SOURCE_COUNT")
    verify_exact_paths(
        preflight,
        {
            "source_inventory_count": 124,
            "bound_predecessor_count": 1,
            "current_zero_world_worker_count": 5,
            "historical_closure_audits_executed_count": 0,
            "projection_control_count": 8,
            "native_effective_safe_count": 8,
            "adjacent_unsafe_count": 8,
            "binary32_maximality_count": 8,
            "source_algebra_identity_count": 8,
            "production_route_projection_count": 8,
            "production_route_safe_readback_count": 8,
            "identity_mutation_rejection_count": 4,
            "r69_native_effective_impulse_limit_receipt.production_route_guard_receipt.validated_actuator_count": 8,
            "supervisor_projection_receipt.status": "forced_failure_projection_control",
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
            qualification["projection_control_count"],
            qualification["adjacent_unsafe_count"],
            qualification["identity_mutation_rejection_count"],
            receipt["held_out_cell_access_count"],
        ),
        (9, 9, 124, 9, 5, 0, 8, 8, 4, 0),
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
            "result": "positive_zero_world_native_effective_impulse_limit_qualified",
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
            "r24d69_zero_world_closure_raw_sha256": sha256(raw),
        },
        revision=revision,
    )
    print(
        "QSDK_R24D69_GODOT_NATIVE_EFFECTIVE_IMPULSE_LIMIT_ZERO_WORLD_"
        "QUALIFICATION_CLOSURE_PASS sources=124 checks=9/9 retained=9 "
        "workers=5 historical_audits=0 safe=8 adjacent_unsafe=8 "
        "mutations=4 models=0 worlds=0 steps=0 control_required=1 "
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
            "QSDK_R24D69_GODOT_NATIVE_EFFECTIVE_IMPULSE_LIMIT_ZERO_WORLD_"
            f"QUALIFICATION_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
