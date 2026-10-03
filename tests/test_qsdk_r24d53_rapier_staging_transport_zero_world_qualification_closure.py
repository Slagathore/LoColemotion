"""Compact audit of the retained zero-world QSDK-R24D53 closure."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, git, load, sha256, source_bytes,
    verify_boolean_partition, verify_declared_zero_world_qualification_authority,
    verify_exact_paths, verify_legacy_live_gate_paths,
)

CLOSURE = ROOT / (
    "sdk/recovery/"
    "r24d53_rapier_staging_transport_zero_world_qualification_closure_v1.json"
)
SOURCE = "f722b4f64a9df3c10164ad21bcf938a0644ea691"
STATUS = (
    "closed_complete_zero_world_native_staging_transport_binding_qualified_"
    "single_smoke_authorized"
)
CHECKS = (
    "fresh_registry_archive_patched_and_bound",
    "successor_patch_sequence_applied_and_bound",
    "source_contract_audit_passed", "stock_adapter_check_passed",
    "isolated_patched_rapier_and_adapter_check_passed",
    "expected_compile_refusal_parallel", "expected_compile_refusal_simd_stable",
    "contract_declared_preflight_expectations_passed",
    "production_preflight_passed", "source_manifest_bound",
    "worktree_unchanged", "source_commit_unchanged", "live_remote_unchanged",
)
MUTATION_IDS = [
    "wrong_gate", "wrong_r52_predecessor_digest", "wrong_recovery_route",
    "wrong_staging_mapping_profile", "wrong_step_budget",
]


def audit() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT, closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d53_rapier_staging_transport_"
                "zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D53", closure_status=STATUS,
            source_commit=SOURCE,
            source_subject="[recovery/rapier] Freeze R53 staging transport gate",
            source_binding_names=(
                "transport_module", "recovery_route", "native_entrypoint",
                "zero_world_runner", "physical_runner", "source_audit",
            ),
            predecessor_status=(
                "closed_complete_zero_world_native_boundary_telemetry_and_"
                "portable_v3_staging_ledger_qualified_physical_transport_smoke_blocked"
            ),
            attempt_schema=(
                "sporespore_qsdk_r24d53_rapier_staging_transport_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d53_rapier_staging_transport_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d53-rapier-staging-transport-qualification-"
            ),
            expected_checks=CHECKS, checkout_only_metadata=(),
            retained_log_markers={
                "01-source-audit.log": (
                    "QSDK_R24D53_RAPIER_STAGING_TRANSPORT_SMOKE_SOURCE_PASS"
                ),
                "03-refusal-parallel.log": (
                    "qualified only for the sequential scalar solver"
                ),
                "03-refusal-simd-stable.log": (
                    "qualified only for scalar rigid impulse-joint constraints"
                ),
                "04-production-preflight.log": (
                    "QSDK_R24D53_RAPIER_STAGING_TRANSPORT_ZERO_WORLD "
                ),
            },
            physical_question_declared=True,
        )
    )
    verify_exact_paths(contract, {
        "gate_id": "QSDK-R24D53", "question_class": "development",
        "physical_question_declared": True,
        "finite_physical_population.world_count": 1,
        "finite_physical_population.arm_count": 1,
        "finite_physical_population.arm_kind": "candidate_command",
        "finite_physical_population.maximum_total_outer_steps": 2,
        "complete_zero_world_gate.prospectively_declared_physical_question_permitted": True,
        "complete_zero_world_gate.positive_control_count": 7,
        "complete_zero_world_gate.mutation_rejection_count": 5,
        "complete_zero_world_gate.total_preflight_check_count": 12,
        "complete_zero_world_gate.maximum_physical_steps_authorized": 0,
    }, "CONTRACT")
    exact(len(contract["source_inventory"]), 35, "SOURCE_COUNT")

    dependency_contract = load(
        ROOT / contract["qualification_runner"]["pinned_dependency_contract_path"]
    )
    dependency = dependency_contract["pinned_dependency"]
    exact((receipt["registry_archive"]["raw_sha256"],
           receipt["registry_archive"]["byte_length"],
           receipt["patch_raw_sha256"]),
          ("sha256:" + dependency["cargo_registry_checksum"],
           dependency["registry_archive_byte_length"],
           dependency["patch_raw_sha256"]), "PINNED_DEPENDENCY")
    exact(receipt["successor_patch_sequence"],
          contract["qualification_runner"]["successor_patch_sequence"],
          "SUCCESSOR_PATCH_SEQUENCE")
    exact(receipt["successor_patched_dependency_files"],
          contract["qualification_runner"]["successor_patched_files"],
          "SUCCESSOR_PATCHED_FILES")

    verify_exact_paths(preflight, {
        "qualification_class": "zero_world_native_staging_transport_binding",
        "question_class": "development", "check_count": 12,
        "checks_passed": 12, "control_count": 7, "controls_passed": 7,
        "mutation_rejection_count": 5,
        "runtime_binding_sha256": closure["qualification"]["runtime_binding_sha256"],
        "transport_arm_count": 1, "maximum_total_outer_steps": 2,
        "native_staging_transport_implemented": True,
        "native_staging_transport_observed": False,
        "in_run_physical_invariant_route_compiled": True,
        "physical_execution_authorized_by_this_receipt": False,
        "maximum_physical_steps_authorized_by_this_receipt": 0,
        "model_construction_count": 0, "world_attempt_count": 0,
        "world_build_count": 0, "solver_step_count": 0,
        "prone_to_standing_claimed": False, "sdk1_milestone_advanced": False,
    }, "PREFLIGHT")
    exact(preflight["mutation_ids"], MUTATION_IDS, "MUTATION_IDS")
    exact([item["mutation_id"] for item in preflight["mutation_rejections"]],
          MUTATION_IDS, "MUTATION_RECEIPTS")
    exact([item["rejected"] for item in preflight["mutation_rejections"]],
          [True] * 5, "MUTATION_REJECTIONS")

    qualification = closure["qualification"]
    exact((qualification["check_count"], qualification["checks_passed"],
           qualification["expected_compile_refusal_count"],
           qualification["preflight_check_count"],
           qualification["preflight_checks_passed"],
           qualification["positive_control_count"],
           qualification["mutation_rejection_count"],
           qualification["successor_patch_count"],
           qualification["successor_patched_file_count"]),
          (13, 13, 2, 12, 12, 7, 5, 1, 8), "QUALIFICATION_COUNTS")
    decision = closure["decision"]
    verify_exact_paths(decision, {
        "result": (
            "positive_rapier_native_staging_transport_binding_qualified_"
            "zero_world_single_two_step_smoke_authorized"
        ),
        "rapier_version": "0.34.0",
        "runtime_binding_sha256": qualification["runtime_binding_sha256"],
        "authorized_arm_kind": "candidate_command", "authorized_world_count": 1,
        "authorized_outer_step_count": 2, "maximum_physical_steps_authorized": 2,
        "new_behavior_threshold_count": 0, "new_empirical_threshold_count": 0,
        "new_margin_count": 0, "observed_physical_cohort_count": 0,
        "held_out_cohort_count": 0, "population_claim_count": 0,
    }, "DECISION")
    verify_boolean_partition(decision, (
        "r52_zero_world_qualification_closed_positive",
        "native_staging_transport_implemented",
        "native_staging_transport_zero_world_qualified",
        "producer_owned_runtime_binding_qualified",
        "single_arm_two_step_projection_qualified",
        "in_run_physical_invariant_route_compiled", "all_seven_controls_passed",
        "all_five_declared_mutations_rejected", "parallel_compile_refusal_qualified",
        "simd_compile_refusal_qualified", "ordered_successor_patch_sequence_qualified",
        "source_population_content_addressed", "retained_evidence_tree_content_addressed",
        "native_transport_smoke_stage_authorized", "r24d53_closed_without_physics",
    ), (
        "native_transport_smoke_attempted", "native_transport_smoke_observed",
        "new_physical_observation_made", "retained_r49_residual_recomputed",
        "retained_r49_result_reclassified", "controller_changed",
        "controller_behavior_evaluated", "prone_to_standing_claimed",
        "repeatability_rate_claimed", "population_claimed",
        "held_out_validation_claimed", "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "r24d53_zero_world_requalification_permitted",
        "physical_acceptance_authority", "release_authority",
    ), "DECISION")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    verify_exact_paths(closure["next_boundary"], {
        "gate_id": "QSDK-R24D53", "question_class": "development",
        "status": "single_exact_native_staging_transport_smoke_authorized_unattempted",
        "authorized_world_count": 1, "authorized_arm_kind": "candidate_command",
        "maximum_outer_steps_authorized": 2,
        "maximum_physical_steps_authorized": 2,
        "r24d53_physical_execution_authorized": True,
        "r24d53_same_source_physical_attempt_limit": 1,
        "r24d53_zero_world_requalification_permitted": False,
        "r24d49_may_be_rerun_or_rethresholded": False,
    }, "NEXT")
    verify_boolean_partition(closure["claim_boundary"], (
        "official_zero_world_qualification_passed",
        "r52_zero_world_qualification_closed_positive",
        "native_staging_transport_implemented",
        "producer_owned_runtime_binding_qualified",
        "single_arm_two_step_projection_qualified",
        "in_run_physical_invariant_route_compiled", "all_seven_controls_passed",
        "all_five_declared_mutations_rejected", "parallel_and_simd_refusals_qualified",
        "ordered_successor_patch_sequence_qualified", "source_population_content_addressed",
        "retained_evidence_tree_content_addressed", "native_transport_smoke_stage_authorized",
    ), (
        "native_transport_smoke_attempted", "native_transport_smoke_observed",
        "new_physical_observation_made", "retained_r49_residual_recomputed",
        "retained_r49_result_reclassified", "controller_physical_viability_proven",
        "controller_behavior_evaluated", "prone_to_standing_claimed",
        "repeatability_rate_claimed", "population_claimed",
        "held_out_validation_claimed", "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed", "sdk1_milestone_advanced",
        "physical_acceptance_authority", "release_authority",
    ), "CLAIM")

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    assert isinstance(publication, str)
    revision = publication or None
    raw = CLOSURE.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    live = {**closure["live_gate_expectations"],
            "r24d53_closure_raw_sha256": sha256(raw)}
    verify_legacy_live_gate_paths(ROOT, closure["live_authority_paths"],
                                  "QSDK-R24D45", live, revision=revision)
    print("QSDK_R24D53_RAPIER_STAGING_TRANSPORT_ZERO_WORLD_QUALIFICATION_CLOSURE_PASS "
          "sources=35 checks=13/13 preflight=12/12 controls=7 mutations=5 "
          "refusals=2 successor=1/8 tree_files=150 models=0 worlds=0 solver_steps=0 "
          "physical=false authorized=1x2 sdk1=11/20 next=QSDK-R24D53")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print("QSDK_R24D53_RAPIER_STAGING_TRANSPORT_ZERO_WORLD_QUALIFICATION_"
              f"CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
