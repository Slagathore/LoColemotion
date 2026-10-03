"""Audit the compact retained zero-world QSDK-R24D55 closure."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    load,
    verify_boolean_partition,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
)

CLOSURE = ROOT / (
    "sdk/recovery/"
    "r24d55_rapier_terminal_prefix_recovery_zero_world_qualification_closure_v1.json"
)
SOURCE = "e189aed52b4fde5686a554bb3c562a8fb12eef37"
STATUS = (
    "closed_complete_zero_world_terminal_prefix_projection_qualified_"
    "one_paired_development_attempt_authorized"
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
MUTATIONS = [
    "wrong_gate",
    "wrong_r54_invalid_closure_digest",
    "wrong_projection_rule",
    "wrong_observation_schema",
    "wrong_step_budget",
    "wrong_attempt_limit",
]


def audit() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d55_rapier_terminal_prefix_recovery_"
                "zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D55",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject="[recovery/rapier] Freeze R55 terminal-prefix successor",
            source_binding_names=(
                "behavior_module",
                "core_recovery",
                "core_energy_v3",
                "zero_world_runner",
                "physical_runner",
                "source_audit",
            ),
            predecessor_status=(
                "closed_consumed_invalid_complete_evaluation_trace_population_"
                "included_post_terminal_candidate_tail"
            ),
            attempt_schema=(
                "sporespore_qsdk_r24d55_rapier_terminal_prefix_recovery_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d55_rapier_terminal_prefix_recovery_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d55-rapier-terminal-prefix-recovery-qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(),
            retained_log_markers={
                "01-source-audit.log": (
                    "QSDK_R24D55_RAPIER_TERMINAL_PREFIX_RECOVERY_SOURCE_PASS"
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
                    "QSDK_R24D55_RAPIER_TERMINAL_PREFIX_RECOVERY_ZERO_WORLD "
                ),
            },
            physical_question_declared=True,
        )
    )

    verify_exact_paths(
        contract,
        {
            "gate_id": "QSDK-R24D55",
            "question_class": "development",
            "finite_development_population.world_count": 2,
            "finite_development_population.arm_count": 2,
            "finite_development_population.maximum_total_outer_steps": 2400,
            "finite_development_population.same_source_attempt_limit": 1,
            "complete_zero_world_gate.positive_control_count": 8,
            "complete_zero_world_gate.mutation_rejection_count": 6,
            "complete_zero_world_gate.total_preflight_check_count": 14,
            "complete_zero_world_gate.full_seeded_ghost_required": False,
            "complete_zero_world_gate.additional_physical_canary_required": False,
            "terminal_prefix_projection.complete_capture_retained": True,
            "terminal_prefix_projection.evaluator_input_is_exact_terminal_prefix": True,
            "terminal_prefix_projection.post_terminal_tail_excluded_from_evaluator": True,
        },
        "CONTRACT",
    )
    exact(len(contract["source_inventory"]), 35, "SOURCE_COUNT")

    dependency = load(
        ROOT / contract["qualification_runner"]["pinned_dependency_contract_path"]
    )["pinned_dependency"]
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
    exact(receipt["successor_patch_sequence"], patch_profile["successor_patch_sequence"], "PATCH_SEQUENCE")
    exact(receipt["successor_patched_dependency_files"], patch_profile["successor_patched_files"], "PATCH_FILES")

    qualification = closure["qualification"]
    verify_exact_paths(
        preflight,
        {
            "schema_version": (
                "sporespore_qsdk_r24d55_rapier_terminal_prefix_recovery_"
                "zero_world_qualification_v1"
            ),
            "qualification_class": "zero_world_terminal_prefix_projection_route",
            "check_count": 14,
            "checks_passed": 14,
            "control_count": 8,
            "mutation_rejection_count": 6,
            "runtime_binding_sha256": qualification["runtime_binding_sha256"],
            "r54_consumed_invalid_preserved": True,
            "complete_capture_retained": True,
            "evaluator_input_is_exact_terminal_prefix": True,
            "projection_fixture.captured": [10, 20, 30, 40],
            "projection_fixture.evaluator_input": [10, 20, 30],
            "projection_fixture.invalid_counts_rejected": True,
            "physical_execution_authorized_by_this_receipt": False,
            "world_build_count": 0,
            "solver_step_count": 0,
            "prone_to_standing_claimed": False,
        },
        "PREFLIGHT",
    )
    exact(preflight["mutation_ids"], MUTATIONS, "MUTATION_IDS")
    exact(
        [item["rejected"] for item in preflight["mutation_rejections"]],
        [True] * 6,
        "MUTATION_REJECTIONS",
    )
    exact(
        (
            qualification["check_count"],
            qualification["preflight_check_count"],
            qualification["positive_control_count"],
            qualification["mutation_rejection_count"],
            qualification["retained_tree"]["file_count"],
        ),
        (14, 14, 8, 6, 151),
        "QUALIFICATION_COUNTS",
    )

    decision = closure["decision"]
    verify_exact_paths(
        decision,
        {
            "runtime_binding_sha256": qualification["runtime_binding_sha256"],
            "authorized_arm_kinds": ["candidate_command", "matched_zero_command"],
            "authorized_world_count": 2,
            "maximum_outer_steps_per_arm": 1200,
            "maximum_physical_steps_authorized": 2400,
            "new_behavior_threshold_count": 0,
            "new_empirical_threshold_count": 0,
            "new_margin_count": 0,
        },
        "DECISION",
    )
    verify_boolean_partition(
        decision,
        (
            "r54_consumed_invalid_preserved",
            "terminal_prefix_projection_implemented",
            "terminal_prefix_projection_zero_world_qualified",
            "complete_native_capture_retained",
            "unchanged_evaluator_receives_exact_terminal_prefix",
            "zero_and_out_of_range_prefix_counts_refused",
            "all_eight_controls_passed",
            "all_six_declared_mutations_rejected",
            "parallel_compile_refusal_qualified",
            "simd_compile_refusal_qualified",
            "ordered_successor_patch_sequence_qualified",
            "source_population_content_addressed",
            "retained_evidence_tree_content_addressed",
            "r53_live_integration_closure_replaces_new_ghost",
            "paired_development_authorized",
            "r24d55_closed_without_physics",
        ),
        (
            "physical_attempted",
            "r24d55_behavior_observed",
            "new_physical_observation_made",
            "historical_r54_result_rewritten",
            "controller_changed",
            "evaluator_changed",
            "controller_behavior_evaluated",
            "prone_to_standing_claimed",
            "repeatability_rate_claimed",
            "population_claimed",
            "held_out_validation_claimed",
            "cross_engine_recovery_claimed",
            "cross_engine_equivalence_claimed",
            "r24d55_zero_world_requalification_permitted",
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
            "gate_id": "QSDK-R24D55",
            "authorized_world_count": 2,
            "maximum_physical_steps_authorized": 2400,
            "r24d55_physical_execution_authorized": True,
            "r24d55_same_source_physical_attempt_limit": 1,
            "r24d54_may_be_rerun_requalified_or_reclassified": False,
        },
        "NEXT",
    )
    print(
        "QSDK_R24D55_RAPIER_TERMINAL_PREFIX_RECOVERY_ZERO_WORLD_"
        "QUALIFICATION_CLOSURE_PASS sources=35 checks=14/14 preflight=14/14 "
        "controls=8 mutations=6 refusals=2 tree_files=151 worlds=0 "
        "solver_steps=0 physical=false authorized=2x1200 sdk1=11/20"
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
            "QSDK_R24D55_RAPIER_TERMINAL_PREFIX_RECOVERY_ZERO_WORLD_"
            f"QUALIFICATION_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
