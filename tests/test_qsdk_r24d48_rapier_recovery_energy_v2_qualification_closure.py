"""Compact audit of the retained zero-world QSDK-R24D48 closure."""

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
    git,
    load,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
    verify_retained_file_tree,
)


CLOSURE_PATH = ROOT / (
    "sdk/recovery/"
    "r24d48_rapier_recovery_energy_v2_qualification_closure_v1.json"
)
SOURCE = "2633da0297e999c0211e20fdb5e0d5b25f315ec9"
GATE = "QSDK-R24D48"
SCHEMA = (
    "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_"
    "qualification_closure_v1"
)
STATUS = (
    "closed_complete_zero_world_rapier_recovery_energy_v2_"
    "qualified_physics_staged"
)
CHECKS = (
    "fresh_registry_archive_patched_and_bound",
    "source_contract_audit_passed",
    "stock_adapter_check_passed",
    "isolated_patched_rapier_and_adapter_check_passed",
    "expected_compile_refusal_parallel",
    "expected_compile_refusal_simd_stable",
    "contract_declared_preflight_expectations_passed",
    "production_preflight_passed",
    "source_manifest_bound",
    "worktree_unchanged",
    "source_commit_unchanged",
    "live_remote_unchanged",
)
MUTATION_IDS = [
    "sample_sequence_mismatch",
    "source_measurement_false",
    "nonfinite_actuator_work",
    "negative_passive_dissipation",
    "wrong_source_route",
    "wrong_mapping_profile",
    "wrong_adapter",
    "unqualified_engine",
]
DECISION_TRUE = (
    "fresh_registry_archive_patch_application_qualified",
    "patched_dependency_files_content_addressed",
    "rapier_observation_v2_source_identity_qualified",
    "r24d47_to_energy_v2_mapping_qualified",
    "public_v3_collection_control_and_evaluator_path_qualified",
    "direct_actuator_external_constraint_passive_partition_qualified",
    "parallel_compile_refusal_qualified",
    "simd_compile_refusal_qualified",
    "valid_energy_increment_and_aggregation_fixture_accepted",
    "all_declared_mapping_mutations_rejected",
    "source_population_content_addressed",
    "retained_evidence_tree_content_addressed",
    "qualification_harness_cargo_lock_content_addressed",
    "integration_ghost_stage_authorized",
)
DECISION_FALSE = (
    "live_v2_recovery_route_physically_exercised",
    "integration_ghost_passed",
    "paired_development_authorized",
    "controller_behavior_evaluated",
    "controller_changed",
    "threshold_changed",
    "selector_changed",
    "evaluator_changed",
    "morphology_changed",
    "initializer_changed",
    "physical_acceptance_authority",
    "release_authority",
)
NEXT_TRUE = (
    "physical_question_declared",
    "complete_zero_world_gate_satisfied",
    "distinct_clean_pushed_source_freeze_required",
    "same_qualification_dependency_toolchain_and_environment_required",
    "physical_execution_authorized",
    "paired_development_blocked_until_valid_ghost",
    "held_out_cells_remain_sealed",
)
NEXT_FALSE = (
    "behavior_success_required",
    "full_seeded_ghost_required",
    "additional_physical_canary_required",
    "r24d48_may_be_requalified",
    "r24d45_or_r24d47_may_be_rerun_or_requalified",
    "prone_to_standing_claimed",
    "physical_acceptance_authority",
    "release_authority",
)
CLAIM_TRUE = (
    "official_zero_world_qualification_passed",
    "fresh_registry_archive_patch_application_qualified",
    "rapier_observation_v2_source_identity_qualified",
    "r24d47_to_energy_v2_mapping_qualified",
    "public_v3_collection_control_and_evaluator_path_qualified",
    "all_eight_declared_mapping_mutations_rejected",
    "parallel_and_simd_refusals_qualified",
    "source_population_content_addressed",
    "retained_evidence_tree_content_addressed",
    "qualification_harness_cargo_lock_content_addressed",
    "integration_ghost_stage_authorized",
    "held_out_cells_remain_sealed",
)
CLAIM_FALSE = (
    "live_v2_recovery_route_physically_exercised",
    "integration_ghost_passed",
    "paired_development_attempt_consumed",
    "controller_behavior_evaluated",
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
            closure_path=CLOSURE_PATH,
            schema_version=SCHEMA,
            gate_id=GATE,
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/rapier] Add R48 observation-v2 recovery route"
            ),
            source_binding_names=(
                "route",
                "entrypoint",
                "core_runtime",
                "adapter_runtime",
                "common_conformance_helper",
                "shared_runner",
                "physical_runner",
                "source_audit",
            ),
            predecessor_status=(
                "closed_complete_zero_world_supported_route_rapier_energy_"
                "accounting_observer_qualified_no_physical_question"
            ),
            attempt_schema=(
                "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d48-rapier-recovery-energy-v2-qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(),
            retained_log_markers={
                "01-source-audit.log": (
                    "QSDK_R24D48_RAPIER_RECOVERY_ENERGY_V2_SOURCE_PASS"
                ),
                "03-refusal-parallel.log": (
                    "qualified only for the sequential scalar solver"
                ),
                "03-refusal-simd-stable.log": (
                    "qualified only for scalar rigid impulse-joint constraints"
                ),
                "04-production-preflight.log": (
                    "QSDK_R24D48_RAPIER_RECOVERY_ENERGY_V2_ZERO_WORLD "
                ),
            },
            physical_question_declared=True,
        )
    )
    verify_exact_paths(contract, {
        "gate_id": GATE,
        "question_class": "development",
        "physical_question_declared": True,
        "scope.engine": "rapier_parry_native",
        "scope.route_id": (
            "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_route_v1"
        ),
        "scope.mapping_profile_id": (
            "rapier_r24d47_native_components_to_recovery_energy_v2_v1"
        ),
        "complete_zero_world_gate.mapping_mutation_rejection_count": 8,
        "complete_zero_world_gate.maximum_physical_steps_authorized": 0,
        "staged_physical_execution.integration_ghost.maximum_total_outer_steps": 4,
        "staged_physical_execution.paired_development.maximum_total_outer_steps": 2400,
        "physical_runner.qualification_harness_cargo_lock_path": (
            "isolated-harness/Cargo.lock"
        ),
        "physical_runner.qualification_harness_cargo_lock_reused_exactly": True,
        "physical_runner.locked_dependency_resolution_required": True,
    }, "CONTRACT")
    exact(len(contract["source_inventory"]), 28, "CONTRACT_SOURCE_COUNT")
    exact(
        len(contract["qualification_runner"]["preflight_expectations"]),
        14,
        "CONTRACT_PREFLIGHT_EXPECTATION_COUNT",
    )

    dependency_contract = load(ROOT / contract["predecessor"]["contract_path"])
    dependency = dependency_contract["pinned_dependency"]
    exact(receipt["registry_archive"], {
        "path": receipt["registry_archive"]["path"],
        "raw_sha256": "sha256:" + dependency["cargo_registry_checksum"],
        "byte_length": dependency["registry_archive_byte_length"],
    }, "REGISTRY_ARCHIVE")
    exact(receipt["patch_raw_sha256"], dependency["patch_raw_sha256"], "PATCH")
    exact(receipt["patched_dependency_files"], [
        {
            "path": item["path"],
            "raw_sha256": item["patched_raw_sha256"],
            "byte_length": item["patched_byte_length"],
        }
        for item in dependency["upstream_and_patched_files"]
    ], "PATCHED_FILES")

    verify_exact_paths(preflight, {
        "schema_version": (
            "sporespore_qsdk_r24d48_rapier_recovery_energy_v2_"
            "zero_world_qualification_v1"
        ),
        "qualification_class": (
            "zero_world_rapier_recovery_observation_v2_mapping"
        ),
        "question_class": "development",
        "route_id": contract["scope"]["route_id"],
        "mapping_profile_id": contract["scope"]["mapping_profile_id"],
        "energy_rule_id": contract["scope"]["energy_rule_id"],
        "accepted_energy_increment.sequence_index": 1,
        "accepted_energy_increment.semantic_step": 1,
        "accepted_energy_increment.applied_actuator_work_j": 1.0,
        "accepted_energy_increment.signed_external_work_j": 0.0,
        "accepted_energy_increment.signed_constraint_exchange_j": 0.5,
        "accepted_energy_increment.passive_dissipation_j": 0.0,
        "accepted_aggregation.ledger.initial_mechanical_energy_j": 10.0,
        "accepted_aggregation.ledger.current_mechanical_energy_j": 11.5,
        "accepted_aggregation.evaluation.absolute_residual_j": 0.0,
        "accepted_aggregation.evaluation.threshold_applied": False,
        "rapier_source_identity_supported": True,
        "mapping_mutation_rejection_count": 8,
        "physical_question_declared": True,
        "physical_execution_authorized_by_this_receipt": False,
        "maximum_physical_steps_authorized_by_this_receipt": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "prone_to_standing_claimed": False,
        "sdk1_milestone_advanced": False,
    }, "PREFLIGHT")
    exact(
        preflight["mapping_mutation_results"],
        [{"mutation_id": item, "rejected": True} for item in MUTATION_IDS],
        "MUTATIONS",
    )

    qualification = closure["qualification"]
    exact(
        (
            qualification["check_count"],
            qualification["checks_passed"],
            qualification["expected_compile_refusal_count"],
            qualification["preflight_expectation_count"],
            qualification["preflight_expectations_passed"],
            qualification["mapping_mutation_rejection_count"],
        ),
        (12, 12, 2, 14, 14, 8),
        "QUALIFICATION_COUNTS",
    )
    lock = receipt["isolated_harness_cargo_lock"]
    exact(lock, qualification["isolated_harness_cargo_lock"], "CARGO_LOCK")
    lock_path = Path(qualification["evidence_root"]) / lock["path"]
    lock_raw = lock_path.read_bytes()
    exact(len(lock_raw), lock["byte_length"], "CARGO_LOCK_LENGTH")
    exact(sha256(lock_raw), lock["raw_sha256"], "CARGO_LOCK_HASH")

    decision = closure["decision"]
    verify_exact_paths(decision, {
        "result": (
            "positive_exact_rapier_recovery_observation_v2_mapping_"
            "qualified_zero_world"
        ),
        "rapier_version": "0.34.0",
        "new_behavior_threshold_count": 0,
        "new_empirical_threshold_count": 0,
        "new_margin_count": 0,
        "physical_cohort_count": 0,
        "held_out_cohort_count": 0,
        "population_claim_count": 0,
        "maximum_physical_steps_authorized": 4,
    }, "DECISION")
    verify_boolean_partition(decision, DECISION_TRUE, DECISION_FALSE, "DECISION")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False,
        "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20,
        "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")

    next_boundary = closure["next_boundary"]
    verify_exact_paths(next_boundary, {
        "gate_id": GATE,
        "stage_id": "R24D48-A",
        "question_class": "development_integration_ghost",
        "status": "two_step_per_arm_integration_ghost_authorized",
        "maximum_outer_steps_per_arm_authorized": 2,
        "maximum_physical_steps_authorized": 4,
    }, "NEXT")
    verify_boolean_partition(next_boundary, NEXT_TRUE, NEXT_FALSE, "NEXT")
    verify_boolean_partition(
        closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM"
    )

    evidence_root = Path(qualification["evidence_root"])
    tree = qualification["retained_tree"]
    rejected = 0
    for mutation in (
        {**tree, "file_count": tree["file_count"] + 1},
        {**tree, "manifest_canonical_sha256": "sha256:" + "0" * 64},
    ):
        try:
            verify_retained_file_tree(evidence_root, mutation)
        except ClosureAuditError:
            rejected += 1
    exact(rejected, 2, "TREE_MUTATION_REJECTIONS")

    relative = CLOSURE_PATH.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative
    )
    assert isinstance(publication, str)
    revision = publication or None
    closure_raw = (
        CLOSURE_PATH.read_bytes()
        if revision is None
        else source_bytes(ROOT, revision, relative)
    )
    live = {
        **closure["live_gate_expectations"],
        "r24d48_closure_raw_sha256": sha256(closure_raw),
    }
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        live,
        revision=revision,
    )
    print(
        "QSDK_R24D48_RAPIER_RECOVERY_ENERGY_V2_QUALIFICATION_CLOSURE_PASS "
        "sources=28 checks=12/12 preflight=14/14 mutations=8+2 "
        "refusals=2 tree_files=148 models=0 worlds=0 solver_steps=0 "
        "stage_a_steps=4 behavior=false sdk1=11/20"
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
            "QSDK_R24D48_RAPIER_RECOVERY_ENERGY_V2_QUALIFICATION_CLOSURE_FAIL "
            f"{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
