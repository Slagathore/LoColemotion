"""Compact audit of the retained zero-world QSDK-R24D52 closure."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, git, load, require, sha256, source_bytes,
    verify_boolean_partition, verify_declared_zero_world_qualification_authority,
    verify_exact_paths, verify_legacy_live_gate_paths, verify_retained_file_tree,
)

CLOSURE = ROOT / "sdk/recovery/r24d52_rapier_discrete_staging_ledger_qualification_closure_v1.json"
SOURCE = "f4174f563841ff9fa59bfe3d7fef6c118bd13e27"
STATUS = "closed_complete_zero_world_native_boundary_telemetry_and_portable_v3_staging_ledger_qualified_physical_transport_smoke_blocked"
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
    "stale_sequence", "short_small_step_population", "native_small_step_overflow",
    "multiple_island_solves", "multiple_ccd_substeps",
    "endpoint_body_population_drift", "endpoint_not_source_measured",
    "small_step_not_source_measured", "native_force_boundary_nonfinite",
    "native_small_step_reordered", "energy_sequence_mismatch",
]
MUTATION_CODES = [
    "QSDK_R24D51_SEQUENCE_INVALID",
    "QSDK_R24D52_NATIVE_SMALL_STEP_POPULATION_INVALID",
    "QSDK_R24D52_NATIVE_SMALL_STEP_POPULATION_INVALID",
    "QSDK_R24D52_NATIVE_SOLVER_ROUTE_INVALID",
    "QSDK_R24D52_NATIVE_SOLVER_ROUTE_INVALID",
    "QSDK_R24D52_ENDPOINT_BODY_POPULATION_INVALID",
    "QSDK_R24D51_ENDPOINT_NOT_SOURCE_MEASURED",
    "QSDK_R24D51_SMALL_STEP_NOT_SOURCE_MEASURED",
    "QSDK_R24D51_FORCE_BOUNDARY_NONFINITE",
    "QSDK_R24D51_SMALL_STEP_ORDER_INVALID",
    "QSDK_R24D52_NATIVE_SOURCE_IDENTITY_INVALID",
]


def audit() -> None:
    closure, contract, receipt, preflight = verify_declared_zero_world_qualification_authority(
        root=ROOT, closure_path=CLOSURE,
        schema_version="sporespore_qsdk_r24d52_rapier_discrete_staging_ledger_qualification_closure_v1",
        gate_id="QSDK-R24D52", closure_status=STATUS, source_commit=SOURCE,
        source_subject="[recovery/rapier] Freeze R52 native staging ledger gate",
        source_binding_names=("native_delta", "portable_ledger", "native_collector",
                              "native_entrypoint", "shared_runner", "source_audit"),
        predecessor_status="closed_complete_zero_world_discrete_force_position_staging_observer_design_qualified_native_wiring_blocked",
        attempt_schema="sporespore_qsdk_r24d52_rapier_discrete_staging_ledger_zero_world_attempt_v1",
        receipt_schema="sporespore_qsdk_r24d52_rapier_discrete_staging_ledger_zero_world_receipt_v1",
        qualification_directory_prefix="qsdk-r24d52-rapier-discrete-staging-ledger-qualification-",
        expected_checks=CHECKS, checkout_only_metadata=(),
        retained_log_markers={
            "01-source-audit.log": "QSDK_R24D52_RAPIER_DISCRETE_STAGING_LEDGER_SOURCE_PASS",
            "03-refusal-parallel.log": "qualified only for the sequential scalar solver",
            "03-refusal-simd-stable.log": "qualified only for scalar rigid impulse-joint constraints",
            "04-production-preflight.log": "QSDK_R24D52_RAPIER_DISCRETE_STAGING_LEDGER_ZERO_WORLD ",
        },
    )
    verify_exact_paths(contract, {
        "gate_id": "QSDK-R24D52", "question_class": "development",
        "supported_native_envelope.solver_small_steps_per_outer_step": 16,
        "observer_semantics.rule_id": "rapier_discrete_force_position_half_step_staging_exchange_v1",
        "portable_ledger_v3.ledger_schema_version": "sporespore_recovery_energy_balance_ledger_v3",
        "portable_ledger_v3.mapping_profile_id": "rapier_r24d52_native_discrete_staging_energy_v3_mapping_v1",
        "complete_zero_world_gate.positive_control_count": 6,
        "complete_zero_world_gate.mutation_rejection_count": 11,
        "complete_zero_world_gate.total_preflight_check_count": 17,
    }, "CONTRACT")
    exact(len(contract["source_inventory"]), 25, "SOURCE_COUNT")

    dependency = load(ROOT / contract["native_patch"]["base_complete_patch_contract_path"])[
        "pinned_dependency"
    ]
    exact((receipt["registry_archive"]["raw_sha256"],
           receipt["registry_archive"]["byte_length"], receipt["patch_raw_sha256"]),
          ("sha256:" + dependency["cargo_registry_checksum"],
           dependency["registry_archive_byte_length"], dependency["patch_raw_sha256"]),
          "PINNED_BASE_DEPENDENCY")
    exact(receipt["successor_patch_sequence"],
          contract["qualification_runner"]["successor_patch_sequence"],
          "SUCCESSOR_PATCH_SEQUENCE")
    exact(receipt["successor_patched_dependency_files"],
          contract["qualification_runner"]["successor_patched_files"],
          "SUCCESSOR_PATCHED_FILES")

    verify_exact_paths(preflight, {
        "qualification_class": "zero_world_native_boundary_telemetry_and_portable_v3_ledger",
        "question_class": "development", "check_count": 17, "checks_passed": 17,
        "control_count": 6, "controls_passed": 6, "mutation_rejection_count": 11,
        "inherited_r51_check_count": 13,
        "mapping_profile_id": "rapier_r24d52_native_discrete_staging_energy_v3_mapping_v1",
        "native_boundary_telemetry_implemented": True,
        "engine_neutral_staging_ledger_v3_implemented": True,
        "staging_mapped_to_external_work": False,
        "staging_mapped_to_passive_dissipation": False,
        "mechanical_energy_change_used_as_work_source": False,
        "energy_balance_residual_used_as_work_source": False,
        "threshold_applied": False, "model_construction_count": 0,
        "world_attempt_count": 0, "world_build_count": 0, "solver_step_count": 0,
        "physical_question_opened": False, "prone_to_standing_claimed": False,
        "sdk1_milestone_advanced": False,
    }, "PREFLIGHT")
    exact(preflight["mutation_ids"], MUTATION_IDS, "MUTATION_IDS")
    mutations = preflight["mutation_rejections"]
    exact([item["mutation_id"] for item in mutations], MUTATION_IDS,
          "MUTATION_RECEIPTS")
    exact([item["expected_code"] for item in mutations], MUTATION_CODES,
          "MUTATION_CODES")
    require(all(item["rejected"] is True and item["observed_code"].startswith(
        item["expected_code"]) for item in mutations), "MUTATION_REJECTIONS")

    q = closure["qualification"]
    exact((q["check_count"], q["checks_passed"], q["expected_compile_refusal_count"],
           q["preflight_check_count"], q["preflight_checks_passed"],
           q["positive_control_count"], q["mutation_rejection_count"],
           q["successor_patch_count"], q["successor_patched_file_count"]),
          (13, 13, 2, 17, 17, 6, 11, 1, 8), "QUALIFICATION_COUNTS")
    decision = closure["decision"]
    verify_exact_paths(decision, {
        "result": "positive_rapier_native_discrete_staging_telemetry_and_engine_neutral_v3_ledger_qualified_zero_world",
        "rapier_version": "0.34.0", "mutation_rejection_count": 11,
        "new_behavior_threshold_count": 0, "new_empirical_threshold_count": 0,
        "new_margin_count": 0, "physical_cohort_count": 0,
        "held_out_cohort_count": 0, "population_claim_count": 0,
    }, "DECISION")
    verify_boolean_partition(decision, (
        "r51_pure_staging_observer_design_qualified",
        "native_boundary_telemetry_implemented",
        "native_boundary_telemetry_source_placement_qualified",
        "native_boundary_telemetry_qualified", "ordered_sixteen_small_step_population_qualified",
        "endpoint_projection_population_qualified",
        "native_sequence_topology_source_and_overflow_refusals_qualified",
        "engine_neutral_staging_ledger_v3_implemented",
        "engine_neutral_staging_ledger_v3_qualified",
        "native_to_portable_staging_mapping_implemented",
        "native_to_portable_staging_mapping_qualified",
        "staging_channel_separate_from_external_and_passive",
        "forced_staging_omission_control_qualified", "all_declared_mutations_rejected",
        "parallel_compile_refusal_qualified", "simd_compile_refusal_qualified",
        "ordered_successor_patch_sequence_qualified", "source_population_content_addressed",
        "retained_evidence_tree_content_addressed", "r24d52_closed_without_physics",
    ), (
        "native_runtime_observation_made", "retained_r49_residual_recomputed",
        "retained_r49_result_reclassified", "controller_changed",
        "native_physics_behavior_changed", "morphology_changed", "initializer_changed",
        "r24d52_physical_execution_permitted",
    ), "DECISION")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    verify_exact_paths(closure["next_boundary"], {
        "gate_id": "QSDK-R24D53", "question_class": "not_yet_declared",
        "maximum_physical_steps_authorized": 0,
        "r24d52_may_be_requalified": False,
        "r24d49_may_be_rerun_or_rethresholded": False,
    }, "NEXT")
    verify_boolean_partition(closure["claim_boundary"], (
        "official_zero_world_qualification_passed",
        "r51_pure_staging_observer_design_qualified",
        "native_boundary_telemetry_source_placement_qualified",
        "engine_neutral_staging_ledger_v3_qualified",
        "native_to_portable_staging_mapping_qualified", "all_six_controls_passed",
        "all_eleven_declared_mutations_rejected", "parallel_and_simd_refusals_qualified",
        "ordered_successor_patch_sequence_qualified", "source_population_content_addressed",
        "retained_evidence_tree_content_addressed", "r24d52_closed_without_physics",
    ), (
        "new_physical_observation_made", "native_runtime_transport_observed",
        "retained_r49_residual_recomputed", "retained_r49_result_reclassified",
        "controller_physical_viability_proven", "prone_to_standing_claimed",
        "repeatability_rate_claimed", "population_claimed", "held_out_validation_claimed",
        "cross_engine_recovery_claimed", "cross_engine_equivalence_claimed",
        "sdk1_milestone_advanced", "physical_acceptance_authority", "release_authority",
    ), "CLAIM")

    evidence_root = Path(q["evidence_root"])
    verify_retained_file_tree(evidence_root, q["retained_tree"])
    rejected = 0
    for mutation in ({**q["retained_tree"], "file_count": 151},
                     {**q["retained_tree"], "manifest_canonical_sha256":
                      "sha256:" + "0" * 64}):
        try:
            verify_retained_file_tree(evidence_root, mutation)
        except ClosureAuditError:
            rejected += 1
    exact(rejected, 2, "TREE_MUTATIONS")

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    assert isinstance(publication, str)
    revision = publication or None
    raw = CLOSURE.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    live = {**closure["live_gate_expectations"],
            "r24d52_closure_raw_sha256": sha256(raw)}
    verify_legacy_live_gate_paths(ROOT, closure["live_authority_paths"],
                                  "QSDK-R24D45", live, revision=revision)
    print("QSDK_R24D52_RAPIER_DISCRETE_STAGING_LEDGER_QUALIFICATION_CLOSURE_PASS "
          "sources=25 checks=13/13 preflight=17/17 controls=6 mutations=11+2 "
          "refusals=2 successor=1/8 tree_files=150 models=0 worlds=0 solver_steps=0 "
          "physical=false sdk1=11/20 next=QSDK-R24D53")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D52_RAPIER_DISCRETE_STAGING_LEDGER_QUALIFICATION_CLOSURE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
