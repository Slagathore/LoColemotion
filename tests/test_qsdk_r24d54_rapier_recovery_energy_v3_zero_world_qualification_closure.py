"""Compact audit of the retained zero-world QSDK-R24D54 closure."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
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
)

CLOSURE = ROOT / (
    "sdk/recovery/"
    "r24d54_rapier_recovery_energy_v3_zero_world_qualification_closure_v1.json"
)
SOURCE = "0249b288da59b7eab9420a43f3a976f1078f2e16"
STATUS = (
    "closed_complete_zero_world_v3_recovery_behavior_route_qualified_"
    "paired_development_authorized"
)
CHECKS = (
    "fresh_registry_archive_patched_and_bound",
    "successor_patch_sequence_applied_and_bound",
    "source_contract_audit_passed",
    "stock_adapter_check_passed",
    "workspace_zero_world_test_recovery_observation_v3",
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
    "wrong_gate",
    "wrong_r49_closure_digest",
    "wrong_r53_closure_digest",
    "wrong_observation_schema",
    "wrong_step_budget",
    "wrong_replay_rule",
]


def audit() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d54_rapier_recovery_energy_v3_"
                "zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D54",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject="[conformance/rapier] Normalize runner modes",
            source_binding_names=(
                "behavior_module",
                "core_recovery",
                "core_energy_v3",
                "zero_world_runner",
                "physical_runner",
                "source_audit",
            ),
            predecessor_status=(
                "closed_valid_complete_live_native_staging_transport_and_"
                "portable_v3_mapping_positive_behavior_unassessed"
            ),
            attempt_schema=(
                "sporespore_qsdk_r24d54_rapier_recovery_energy_v3_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d54_rapier_recovery_energy_v3_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d54-rapier-recovery-energy-v3-qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(),
            retained_log_markers={
                "01-source-audit.log": (
                    "QSDK_R24D54_RAPIER_RECOVERY_ENERGY_V3_SOURCE_PASS"
                ),
                "02-test-recovery-observation-v3.log": (
                    "test result: ok. 2 passed; 0 failed"
                ),
                "03-refusal-parallel.log": (
                    "qualified only for the sequential scalar solver"
                ),
                "03-refusal-simd-stable.log": (
                    "qualified only for scalar rigid impulse-joint constraints"
                ),
                "04-production-preflight.log": (
                    "QSDK_R24D54_RAPIER_RECOVERY_ENERGY_V3_ZERO_WORLD "
                ),
            },
            physical_question_declared=True,
        )
    )

    verify_exact_paths(
        contract,
        {
            "gate_id": "QSDK-R24D54",
            "question_class": "development",
            "physical_question_declared": True,
            "finite_development_population.world_count": 2,
            "finite_development_population.arm_count": 2,
            "finite_development_population.maximum_outer_steps_per_arm": 1200,
            "finite_development_population.maximum_total_outer_steps": 2400,
            "finite_development_population.same_source_attempt_limit": 1,
            "complete_zero_world_gate.prospectively_declared_physical_question_permitted": True,
            "complete_zero_world_gate.positive_control_count": 9,
            "complete_zero_world_gate.mutation_rejection_count": 6,
            "complete_zero_world_gate.total_preflight_check_count": 15,
            "complete_zero_world_gate.full_seeded_ghost_required": False,
            "complete_zero_world_gate.additional_physical_canary_required": False,
            "complete_zero_world_gate.maximum_physical_steps_authorized": 0,
            "v3_replay_validity.pre_terminal_phase_identity_required": True,
            "v3_replay_validity.only_terminal_transition_divergence_permitted": True,
        },
        "CONTRACT",
    )
    exact(len(contract["source_inventory"]), 34, "SOURCE_COUNT")

    dependency_contract = load(
        ROOT / contract["qualification_runner"]["pinned_dependency_contract_path"]
    )
    dependency = dependency_contract["pinned_dependency"]
    exact(
        (
            receipt["registry_archive"]["raw_sha256"],
            receipt["registry_archive"]["byte_length"],
            receipt["patch_raw_sha256"],
        ),
        (
            "sha256:" + dependency["cargo_registry_checksum"],
            dependency["registry_archive_byte_length"],
            dependency["patch_raw_sha256"],
        ),
        "PINNED_DEPENDENCY",
    )
    patch_profile = load(
        ROOT / contract["qualification_runner"]["patch_profile_contract_path"]
    )["qualification_runner"]
    exact(
        receipt["successor_patch_sequence"],
        patch_profile["successor_patch_sequence"],
        "SUCCESSOR_PATCH_SEQUENCE",
    )
    exact(
        receipt["successor_patched_dependency_files"],
        patch_profile["successor_patched_files"],
        "SUCCESSOR_PATCHED_FILES",
    )
    exact(
        receipt["isolated_harness_cargo_lock"],
        closure["qualification"]["isolated_harness_cargo_lock"],
        "QUALIFICATION_CARGO_LOCK",
    )

    verify_exact_paths(
        preflight,
        {
            "schema_version": (
                "sporespore_qsdk_r24d54_rapier_recovery_energy_v3_"
                "zero_world_qualification_v1"
            ),
            "qualification_class": "zero_world_v3_recovery_behavior_route",
            "question_class": "development",
            "check_count": 15,
            "checks_passed": 15,
            "control_count": 9,
            "controls_passed": 9,
            "mutation_rejection_count": 6,
            "runtime_binding_sha256": closure["qualification"][
                "runtime_binding_sha256"
            ],
            "maximum_total_outer_steps": 2400,
            "r53_live_transport_observed": True,
            "v3_staging_consumed_by_evaluator": True,
            "pre_terminal_phase_identity_compiled": True,
            "physical_execution_authorized_by_this_receipt": False,
            "maximum_physical_steps_authorized_by_this_receipt": 0,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "prone_to_standing_claimed": False,
            "sdk1_milestone_advanced": False,
            "balanced_v3_fixture.evaluation.signed_residual_j": 0.0,
            "balanced_v3_fixture.ledger.cumulative_signed_discrete_staging_exchange_j": 0.375,
            "forced_staging_omission_fixture.evaluation.signed_residual_j": 0.375,
            "forced_staging_omission_fixture.ledger.cumulative_signed_discrete_staging_exchange_j": 0.0,
        },
        "PREFLIGHT",
    )
    exact(preflight["mutation_ids"], MUTATION_IDS, "MUTATION_IDS")
    exact(
        [item["mutation_id"] for item in preflight["mutation_rejections"]],
        MUTATION_IDS,
        "MUTATION_RECEIPTS",
    )
    exact(
        [item["rejected"] for item in preflight["mutation_rejections"]],
        [True] * 6,
        "MUTATION_REJECTIONS",
    )

    qualification = closure["qualification"]
    exact(
        (
            qualification["check_count"],
            qualification["checks_passed"],
            qualification["expected_compile_refusal_count"],
            qualification["preflight_check_count"],
            qualification["preflight_checks_passed"],
            qualification["positive_control_count"],
            qualification["mutation_rejection_count"],
            qualification["successor_patch_count"],
            qualification["successor_patched_file_count"],
        ),
        (14, 14, 2, 15, 15, 9, 6, 1, 8),
        "QUALIFICATION_COUNTS",
    )

    decision = closure["decision"]
    verify_exact_paths(
        decision,
        {
            "result": (
                "positive_zero_world_v3_recovery_behavior_route_qualified_"
                "paired_development_authorized"
            ),
            "rapier_version": "0.34.0",
            "runtime_binding_sha256": qualification["runtime_binding_sha256"],
            "authorized_arm_kinds": [
                "candidate_command",
                "matched_zero_command",
            ],
            "authorized_world_count": 2,
            "maximum_outer_steps_per_arm": 1200,
            "maximum_physical_steps_authorized": 2400,
            "new_behavior_threshold_count": 0,
            "new_empirical_threshold_count": 0,
            "new_margin_count": 0,
            "observed_physical_cohort_count": 0,
            "held_out_cohort_count": 0,
            "population_claim_count": 0,
        },
        "DECISION",
    )
    verify_boolean_partition(
        decision,
        (
            "r49_negative_preserved",
            "r53_live_transport_positive_preserved",
            "v3_behavior_route_implemented",
            "v3_behavior_route_zero_world_qualified",
            "recovery_observation_v3_consumed",
            "pre_terminal_phase_identity_qualified",
            "all_nine_controls_passed",
            "all_six_declared_mutations_rejected",
            "parallel_compile_refusal_qualified",
            "simd_compile_refusal_qualified",
            "ordered_successor_patch_sequence_qualified",
            "source_population_content_addressed",
            "retained_evidence_tree_content_addressed",
            "r53_live_integration_closure_replaces_new_ghost",
            "paired_development_authorized",
            "r24d54_closed_without_physics",
        ),
        (
            "physical_attempted",
            "r24d54_behavior_observed",
            "new_physical_observation_made",
            "retained_r49_residual_recomputed",
            "retained_r49_result_reclassified",
            "controller_changed",
            "controller_behavior_evaluated",
            "prone_to_standing_claimed",
            "repeatability_rate_claimed",
            "population_claimed",
            "held_out_validation_claimed",
            "cross_engine_recovery_claimed",
            "cross_engine_equivalence_claimed",
            "r24d54_zero_world_requalification_permitted",
            "physical_acceptance_authority",
            "release_authority",
        ),
        "DECISION",
    )
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
            "gate_id": "QSDK-R24D54",
            "question_class": "development",
            "status": (
                "one_exact_nominal_paired_rapier_v3_recovery_attempt_"
                "authorized_unattempted"
            ),
            "authorized_world_count": 2,
            "authorized_arm_kinds": [
                "candidate_command",
                "matched_zero_command",
            ],
            "maximum_outer_steps_per_arm": 1200,
            "maximum_physical_steps_authorized": 2400,
            "r24d54_physical_execution_authorized": True,
            "r24d54_same_source_physical_attempt_limit": 1,
            "r24d54_zero_world_requalification_permitted": False,
            "r24d49_may_be_rerun_or_rethresholded": False,
        },
        "NEXT",
    )
    verify_boolean_partition(
        closure["claim_boundary"],
        (
            "official_zero_world_qualification_passed",
            "r49_negative_preserved",
            "r53_live_transport_positive_preserved",
            "v3_behavior_route_implemented",
            "strict_v3_evaluator_route_qualified",
            "pre_terminal_phase_identity_qualified",
            "all_nine_controls_passed",
            "all_six_declared_mutations_rejected",
            "parallel_and_simd_refusals_qualified",
            "ordered_successor_patch_sequence_qualified",
            "source_population_content_addressed",
            "retained_evidence_tree_content_addressed",
            "paired_development_authorized",
        ),
        (
            "physical_attempted",
            "r24d54_behavior_observed",
            "new_physical_observation_made",
            "retained_r49_residual_recomputed",
            "retained_r49_result_reclassified",
            "controller_physical_viability_proven",
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
        ),
        "CLAIM",
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
        "r24d54_closure_raw_sha256": sha256(raw),
    }
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        live,
        revision=revision,
    )
    print(
        "QSDK_R24D54_RAPIER_RECOVERY_ENERGY_V3_ZERO_WORLD_QUALIFICATION_"
        "CLOSURE_PASS sources=34 checks=14/14 preflight=15/15 controls=9 "
        "mutations=6 refusals=2 successor=1/8 tree_files=151 models=0 "
        "worlds=0 solver_steps=0 physical=false authorized=2x1200 "
        "sdk1=11/20 next=QSDK-R24D54"
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
            "QSDK_R24D54_RAPIER_RECOVERY_ENERGY_V3_ZERO_WORLD_"
            f"QUALIFICATION_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
