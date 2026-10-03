"""Compact audit of the retained zero-world QSDK-R24D46 closure."""

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
    "r24d46_rapier_exact_solver_work_observer_qualification_closure_v1.json"
)
SOURCE = "a3221a1fcf0b2369ced84a9988139e11a356f2c2"
GATE = "QSDK-R24D46"
SCHEMA = (
    "sporespore_qsdk_r24d46_rapier_exact_solver_work_observer_"
    "qualification_closure_v1"
)
STATUS = (
    "closed_complete_zero_world_exact_rapier_motor_work_observer_"
    "qualified_no_physical_question"
)
CHECKS = (
    "fresh_registry_archive_patched_and_bound",
    "source_contract_audit_passed",
    "stock_adapter_check_passed",
    "isolated_patched_rapier_and_adapter_check_passed",
    "production_preflight_passed",
    "source_manifest_bound",
    "worktree_unchanged",
    "source_commit_unchanged",
    "live_remote_unchanged",
)
MUTATIONS = [
    "QSDK_R24D46_TELEMETRY_SEQUENCE_INVALID:expected=1:observed=0",
    "QSDK_R24D46_APPLICATION_COUNT_INVALID:expected=128:observed=127",
    "QSDK_R24D46_MOTOR_WORK_NONFINITE",
    "QSDK_R24D46_NONNEGATIVE_PARTITION_INVALID",
    "QSDK_R24D46_ABSOLUTE_IMPULSE_PARTITION_INVALID",
    "QSDK_R24D46_WORK_PARTITION_INVALID",
]
DECISION_TRUE = (
    "fresh_registry_archive_patch_application_qualified",
    "patched_dependency_files_content_addressed",
    "exact_active_scalar_solver_work_observer_qualified",
    "application_centered_velocity_and_delta_impulse_qualified",
    "signed_and_absolute_generalized_impulse_qualified",
    "supplied_absorbed_and_net_motor_work_qualified",
    "publication_sequence_and_exact_counters_qualified",
    "valid_fixture_accepted",
    "all_declared_mutations_rejected",
    "source_population_content_addressed",
    "retained_evidence_tree_content_addressed",
    "unmeasured_energy_channels_typed_refused",
    "r24d46_closed_without_physics",
)
DECISION_FALSE = (
    "complete_rapier_energy_partition_established",
    "simd_solver_path_supported",
    "generic_or_multibody_solver_path_supported",
    "controller_changed",
    "native_solver_dynamics_or_constraint_equation_changed",
    "stock_workspace_dependency_changed",
    "morphology_changed",
    "initializer_changed",
    "r24d46_physical_execution_permitted",
)
NEXT_TRUE = (
    "distinct_clean_pushed_source_freeze_required",
    "complete_zero_world_energy_partition_gate_required",
    "held_out_cells_remain_sealed",
)
NEXT_FALSE = (
    "physical_question_declared",
    "behavior_question_declared",
    "full_seeded_ghost_required",
    "additional_physical_canary_required",
    "r24d47_physical_execution_authorized",
    "r24d46_may_be_requalified",
    "r24d45_may_be_rerun_or_requalified",
    "prone_to_standing_claimed",
    "physical_acceptance_authority",
    "release_authority",
)
CLAIM_TRUE = (
    "official_zero_world_qualification_passed",
    "fresh_registry_archive_patch_application_qualified",
    "exact_active_scalar_rapier_motor_work_observer_qualified",
    "application_centered_impulse_work_qualified",
    "publication_freshness_and_completeness_qualified",
    "all_six_declared_mutations_rejected",
    "unmeasured_energy_channels_typed_refused",
    "r24d46_closed_without_physics",
)
CLAIM_FALSE = (
    "complete_rapier_energy_partition_established",
    "simd_or_multibody_coverage_claimed",
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
            source_subject="[recovery/rapier] Add isolated R46 qualifier",
            source_binding_names=(
                "patch", "collector", "collector_entrypoint", "shared_runner",
                "source_audit",
            ),
            predecessor_status=(
                "closed_valid_complete_negative_raise_body_timeout_"
                "energy_residual_boundary"
            ),
            attempt_schema=(
                "sporespore_qsdk_r24d46_rapier_motor_work_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d46_rapier_motor_work_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d46-rapier-motor-work-qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(),
            retained_log_markers={
                "01-source-audit.log": (
                    "QSDK_R24D46_RAPIER_EXACT_SOLVER_WORK_SOURCE_PASS"
                ),
                "04-production-preflight.log": (
                    "QSDK_R24D46_RAPIER_MOTOR_WORK_ZERO_WORLD "
                ),
            },
            preflight_zero_count_keys=("world_build_count", "solver_step_count"),
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
        "observer_semantics.active_solver_small_steps": 16,
        "observer_semantics.active_applications_per_small_step": 8,
        "observer_semantics.active_applications_per_outer_step": 128,
        "complete_zero_world_gate.collector_mutation_rejection_count": 6,
    }, "CONTRACT")
    exact(len(contract["source_inventory"]), 19, "CONTRACT_SOURCE_COUNT")

    dependency = contract["pinned_dependency"]
    archive = receipt["registry_archive"]
    exact(
        (archive["raw_sha256"], archive["byte_length"]),
        ("sha256:" + dependency["cargo_registry_checksum"],
         dependency["registry_archive_byte_length"]),
        "REGISTRY_ARCHIVE",
    )
    exact(receipt["patch_raw_sha256"], dependency["patch_raw_sha256"], "PATCH")
    exact(receipt["patched_dependency_files"], [
        {"path": item["path"], "raw_sha256": item["patched_raw_sha256"],
         "byte_length": item["patched_byte_length"]}
        for item in dependency["upstream_and_patched_files"]
    ], "PATCHED_FILES")

    verify_exact_paths(preflight, {
        "qualification_class": "zero_world_exact_solver_work_observer",
        "question_class": "development",
        "supported_solver_path": "scalar_rigid_body_impulse_joint_motor_constraints",
        "expected_small_step_count": 16,
        "expected_applications_per_small_step": 8,
        "expected_application_count": 128,
        "mutation_rejection_count": 6,
        "unmeasured_energy_channels_typed_refused": True,
        "complete_energy_partition_claimed": False,
        "physical_execution_authorized": False,
        "accepted_fixture.sequence": 1,
        "accepted_fixture.small_step_count": 16,
        "accepted_fixture.application_count": 128,
        "accepted_fixture.generalized_impulse": -0.6000000238418579,
        "accepted_fixture.absolute_generalized_impulse": 0.800000011920929,
        "accepted_fixture.supplied_work_j": 1.25,
        "accepted_fixture.absorbed_work_j": 0.5,
        "accepted_fixture.net_work_j": 0.75,
    }, "PREFLIGHT")
    exact(preflight["mutation_rejections"], MUTATIONS, "MUTATIONS")
    exact(preflight["unmeasured_energy_channels"],
          closure["decision"]["unmeasured_energy_channels"], "UNMEASURED")

    decision = closure["decision"]
    verify_exact_paths(decision, {
        "result": (
            "positive_exact_active_scalar_rapier_motor_work_observer_"
            "qualified_zero_world"
        ),
        "rapier_version": "0.34.0",
        "supported_solver_path": "scalar_rigid_body_impulse_joint_motor_constraints",
        "mutation_rejection_count": 6,
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
        "gate_id": "QSDK-R24D47",
        "question_class": "development",
        "status": (
            "remaining_rapier_energy_exchange_accounting_boundary_required_"
            "physics_blocked"
        ),
        "maximum_physical_steps_authorized": 0,
    }, "NEXT")
    verify_boolean_partition(next_boundary, NEXT_TRUE, NEXT_FALSE, "NEXT")
    verify_boolean_partition(
        closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM"
    )

    evidence_root = Path(closure["qualification"]["evidence_root"])
    tree = closure["qualification"]["retained_tree"]
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
    live = {**closure["live_gate_expectations"],
            "r24d46_closure_raw_sha256": sha256(closure_raw)}
    verify_legacy_live_gate_paths(
        ROOT, closure["live_authority_paths"], "QSDK-R24D45", live,
        revision=revision,
    )
    print(
        "QSDK_R24D46_RAPIER_EXACT_SOLVER_WORK_QUALIFICATION_CLOSURE_PASS "
        "sources=19 checks=9/9 applications=128 mutations=6+2 tree_files=146 "
        "models=0 worlds=0 solver_steps=0 physical=false sdk1=11/20 "
        "next=QSDK-R24D47"
    )


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(
            "QSDK_R24D46_RAPIER_EXACT_SOLVER_WORK_QUALIFICATION_CLOSURE_FAIL "
            f"{error}", file=sys.stderr,
        )
        raise SystemExit(1) from error
