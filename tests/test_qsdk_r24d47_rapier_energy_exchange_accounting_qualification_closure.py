"""Compact audit of the retained zero-world QSDK-R24D47 closure."""

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
    require,
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
    "r24d47_rapier_energy_exchange_accounting_qualification_closure_v1.json"
)
SOURCE = "2922a65fe231d6b04dc34514b69c5c609b2c8be2"
GATE = "QSDK-R24D47"
SCHEMA = (
    "sporespore_qsdk_r24d47_rapier_energy_exchange_accounting_"
    "qualification_closure_v1"
)
STATUS = (
    "closed_complete_zero_world_supported_route_rapier_energy_accounting_"
    "observer_qualified_no_physical_question"
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
    "stale_telemetry_sequence",
    "wrong_solver_phase_count",
    "nonfinite_phase_exchange",
    "stale_motor_sequence",
    "inconsistent_total_partition",
    "nonzero_user_force",
    "nonzero_linear_damping",
    "kinematic_body",
    "locked_axis",
    "multibody_joint",
    "multiple_ccd_substeps",
    "solver_configuration_drift",
    "sleeping_enabled",
]
MUTATION_ERRORS = [
    "QSDK_R24D47_TELEMETRY_SEQUENCE_INVALID",
    "QSDK_R24D47_PHASE_COUNTER_IDENTITY_INVALID",
    "QSDK_R24D47_PHASE_EXCHANGE_NONFINITE",
    "QSDK_R24D47_MOTOR_SEQUENCE_OR_COUNTER_INVALID",
    "QSDK_R24D47_PHASE_PARTITION_INVALID",
    "QSDK_R24D47_EXPLICIT_EXTERNAL_WORK_NOT_ZERO",
    "QSDK_R24D47_PASSIVE_ZERO_CAPABILITY_INVALID",
    "QSDK_R24D47_KINEMATIC_ROUTE_UNSUPPORTED",
    "QSDK_R24D47_LOCKED_AXIS_ROUTE_UNSUPPORTED",
    "QSDK_R24D47_MULTIBODY_ROUTE_UNSUPPORTED",
    "QSDK_R24D47_CCD_ROUTE_UNSUPPORTED",
    "QSDK_R24D47_SOLVER_CONFIGURATION_UNSUPPORTED",
    "QSDK_R24D47_PASSIVE_ZERO_CAPABILITY_INVALID",
]
DECISION_TRUE = (
    "fresh_registry_archive_patch_application_qualified",
    "patched_dependency_files_content_addressed",
    "phase_exchange_observer_qualified",
    "route_capability_validator_qualified",
    "live_world_collector_compiled_and_source_bound",
    "complete_supported_route_energy_accounting_observer_qualified",
    "motor_nonmotor_and_contact_partition_qualified",
    "publication_sequence_and_exact_phase_counters_qualified",
    "parallel_compile_refusal_qualified",
    "simd_compile_refusal_qualified",
    "valid_fixture_accepted",
    "all_declared_mutations_rejected",
    "source_population_content_addressed",
    "retained_evidence_tree_content_addressed",
    "r24d47_closed_without_physics",
)
DECISION_FALSE = (
    "complete_rapier_energy_partition_physically_observed",
    "live_world_collector_physically_exercised",
    "integration_and_numerical_residual_closed",
    "controller_changed",
    "native_solver_order_or_constraint_equation_changed",
    "stock_workspace_dependency_changed",
    "morphology_changed",
    "initializer_changed",
    "r24d47_physical_execution_permitted",
)
NEXT_TRUE = (
    "distinct_clean_pushed_source_freeze_required",
    "complete_zero_world_gate_required",
    "held_out_cells_remain_sealed",
)
NEXT_FALSE = (
    "physical_question_declared",
    "behavior_question_declared",
    "full_seeded_ghost_required",
    "additional_physical_canary_required",
    "r24d48_physical_execution_authorized",
    "r24d47_may_be_requalified",
    "r24d45_may_be_rerun_or_requalified",
    "prone_to_standing_claimed",
    "physical_acceptance_authority",
    "release_authority",
)
CLAIM_TRUE = (
    "official_zero_world_qualification_passed",
    "fresh_registry_archive_patch_application_qualified",
    "phase_exchange_observer_qualified",
    "route_capability_validator_qualified",
    "complete_supported_route_energy_accounting_observer_qualified",
    "motor_nonmotor_contact_partition_qualified",
    "publication_freshness_and_completeness_qualified",
    "parallel_and_simd_refusals_qualified",
    "all_thirteen_declared_mutations_rejected",
    "source_population_content_addressed",
    "retained_evidence_tree_content_addressed",
    "r24d47_closed_without_physics",
)
CLAIM_FALSE = (
    "complete_rapier_energy_partition_physically_observed",
    "live_world_collector_physically_exercised",
    "integration_and_numerical_residual_closed",
    "new_physical_observation_made",
    "controller_physical_viability_proven",
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
            source_subject="[recovery/rapier] Add R47 energy exchange observer",
            source_binding_names=(
                "patch",
                "collector",
                "collector_entrypoint",
                "common_conformance_helper",
                "shared_runner",
                "source_audit",
            ),
            predecessor_status=(
                "closed_complete_zero_world_exact_rapier_motor_work_observer_"
                "qualified_no_physical_question"
            ),
            attempt_schema=(
                "sporespore_qsdk_r24d47_rapier_energy_exchange_zero_world_"
                "attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d47_rapier_energy_exchange_zero_world_"
                "receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d47-rapier-energy-exchange-qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(),
            retained_log_markers={
                "01-source-audit.log": (
                    "QSDK_R24D47_RAPIER_ENERGY_EXCHANGE_SOURCE_PASS"
                ),
                "03-refusal-parallel.log": (
                    "qualified only for the sequential scalar solver"
                ),
                "03-refusal-simd-stable.log": (
                    "qualified only for scalar rigid impulse-joint constraints"
                ),
                "04-production-preflight.log": (
                    "QSDK_R24D47_RAPIER_ENERGY_EXCHANGE_ZERO_WORLD "
                ),
            },
        )
    )
    verify_exact_paths(contract, {
        "gate_id": GATE,
        "question_class": "development",
        "physical_question_declared": False,
        "pinned_dependency.version": "0.34.0",
        "pinned_dependency.cargo_registry_checksum": (
            "4592f61e65aa81ecb8701576336c8e66e893f4ad6a1238efe9ff17f2c77006ef"
        ),
        "supported_route.solver_small_steps_per_outer_step": 16,
        "supported_route.internal_pgs_iterations_per_small_step": 3,
        "supported_route.internal_stabilization_iterations_per_small_step": 5,
        "complete_zero_world_gate.collector_mutation_rejection_count": 13,
        "complete_zero_world_gate.total_preflight_check_count": 14,
    }, "CONTRACT")
    exact(len(contract["source_inventory"]), 24, "CONTRACT_SOURCE_COUNT")

    dependency = contract["pinned_dependency"]
    archive = receipt["registry_archive"]
    exact(
        (archive["raw_sha256"], archive["byte_length"]),
        (
            "sha256:" + dependency["cargo_registry_checksum"],
            dependency["registry_archive_byte_length"],
        ),
        "REGISTRY_ARCHIVE",
    )
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
        "qualification_class": "zero_world_scalar_solver_phase_energy_exchange",
        "question_class": "development",
        "check_count": 14,
        "checks_passed": 14,
        "mutation_rejection_count": 13,
        "accepted_fixture.sequence": 1,
        "accepted_fixture.small_step_count": 16,
        "accepted_fixture.joint_phase_count": 128,
        "accepted_fixture.contact_phase_count": 128,
        "accepted_fixture.contact_warmstart_phase_count": 16,
        "accepted_fixture.constraint_phase_count": 272,
        "accepted_fixture.motor_count": 8,
        "accepted_fixture.motor_net_work_j": 1.0,
        "accepted_fixture.joint_phase_exchange_j": 2.0,
        "accepted_fixture.nonmotor_joint_and_stabilization_exchange_j": 1.0,
        "accepted_fixture.contact_and_friction_exchange_j": -0.5,
        "accepted_fixture.signed_constraint_exchange_j": 0.5,
        "accepted_fixture.signed_external_work_j": 0.0,
        "accepted_fixture.passive_dissipation_j": 0.0,
        "accepted_fixture.residual_derived_work_used": False,
        "route_capability_fixture.dynamic_body_count": 9,
        "route_capability_fixture.fixed_ground_body_count": 1,
        "route_capability_fixture.impulse_joint_count": 8,
        "route_capability_fixture.solver_small_steps_per_outer_step": 16,
        "route_capability_fixture.internal_pgs_iterations_per_small_step": 3,
        "route_capability_fixture.internal_stabilization_iterations_per_small_step": 5,
        "route_capability_fixture.maximum_ccd_substeps": 1,
        "physical_question_opened": False,
        "prone_to_standing_claimed": False,
    }, "PREFLIGHT")
    exact(preflight["mutation_ids"], MUTATION_IDS, "MUTATION_IDS")
    mutations = preflight["mutation_rejections"]
    exact([item["mutation_id"] for item in mutations], MUTATION_IDS,
          "MUTATION_RECEIPT_IDS")
    exact([item["expected_error"] for item in mutations], MUTATION_ERRORS,
          "MUTATION_EXPECTED_ERRORS")
    require(
        all(
            item["observed_error"].startswith(item["expected_error"])
            for item in mutations
        ),
        "MUTATION_OBSERVED_ERRORS",
    )

    qualification = closure["qualification"]
    exact(
        (
            qualification["check_count"],
            qualification["checks_passed"],
            qualification["expected_compile_refusal_count"],
            qualification["preflight_check_count"],
            qualification["preflight_checks_passed"],
            qualification["collector_mutation_rejection_count"],
        ),
        (12, 12, 2, 14, 14, 13),
        "QUALIFICATION_COUNTS",
    )
    decision = closure["decision"]
    verify_exact_paths(decision, {
        "result": (
            "positive_supported_route_rapier_energy_exchange_accounting_"
            "observer_qualified_zero_world"
        ),
        "rapier_version": "0.34.0",
        "supported_solver_path": (
            "sequential_scalar_rigid_body_impulse_joint_and_contact_constraints"
        ),
        "mutation_rejection_count": 13,
        "new_behavior_threshold_count": 0,
        "new_empirical_threshold_count": 0,
        "new_margin_count": 0,
        "physical_cohort_count": 0,
        "held_out_cohort_count": 0,
        "population_claim_count": 0,
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
        "gate_id": "QSDK-R24D48",
        "question_class": "not_yet_declared",
        "status": (
            "distinct_physical_recovery_successor_declaration_and_complete_"
            "zero_world_gate_required"
        ),
        "maximum_physical_steps_authorized": 0,
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
        "r24d47_closure_raw_sha256": sha256(closure_raw),
    }
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        live,
        revision=revision,
    )
    print(
        "QSDK_R24D47_RAPIER_ENERGY_EXCHANGE_QUALIFICATION_CLOSURE_PASS "
        "sources=24 checks=12/12 preflight=14/14 mutations=13+2 "
        "refusals=2 tree_files=148 models=0 worlds=0 solver_steps=0 "
        "physical=false sdk1=11/20 next=QSDK-R24D48"
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
            "QSDK_R24D47_RAPIER_ENERGY_EXCHANGE_QUALIFICATION_CLOSURE_FAIL "
            f"{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
