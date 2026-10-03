"""Compact audit of the retained zero-world QSDK-R24D51 closure."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, git, require, sha256, source_bytes,
    verify_boolean_partition, verify_declared_zero_world_qualification_authority,
    verify_exact_paths, verify_legacy_live_gate_paths, verify_retained_file_tree,
)

CLOSURE = ROOT / "sdk/recovery/r24d51_rapier_discrete_staging_observer_qualification_closure_v1.json"
SOURCE = "f5ca0e1634f136af7fc60c4975b9e947f9044bd5"
STATUS = "closed_complete_zero_world_discrete_force_position_staging_observer_design_qualified_native_wiring_blocked"
CHECKS = (
    "fresh_registry_archive_patched_and_bound", "source_contract_audit_passed",
    "stock_adapter_check_passed", "isolated_patched_rapier_and_adapter_check_passed",
    "expected_compile_refusal_parallel", "expected_compile_refusal_simd_stable",
    "contract_declared_preflight_expectations_passed", "production_preflight_passed",
    "source_manifest_bound", "worktree_unchanged", "source_commit_unchanged",
    "live_remote_unchanged",
)
CONTROL_IDS = [
    "resting_supported_gravity_kick_and_constraint_cancellation_close",
    "free_fall_force_position_and_half_step_terms_match_endpoint_change_once",
    "upward_and_downward_free_fall_preserve_the_same_discrete_defect",
    "zero_gravity_has_zero_force_position_half_step_and_total_exchange",
    "all_three_components_are_retained_separately_before_the_signed_sum",
]
MUTATION_IDS = [
    "omitted_small_step", "duplicated_small_step", "reordered_small_steps",
    "small_step_not_source_measured", "nonfinite_force_boundary",
    "nonfinite_position_boundary", "endpoint_not_source_measured",
    "nonfinite_endpoint_boundary",
]
MUTATION_CODES = [
    "QSDK_R24D51_SMALL_STEP_POPULATION_INVALID",
    "QSDK_R24D51_SMALL_STEP_ORDER_INVALID",
    "QSDK_R24D51_SMALL_STEP_ORDER_INVALID",
    "QSDK_R24D51_SMALL_STEP_NOT_SOURCE_MEASURED",
    "QSDK_R24D51_FORCE_BOUNDARY_NONFINITE",
    "QSDK_R24D51_POSITION_BOUNDARY_NONFINITE",
    "QSDK_R24D51_ENDPOINT_NOT_SOURCE_MEASURED",
    "QSDK_R24D51_ENDPOINT_BOUNDARY_NONFINITE",
]


def audit() -> None:
    closure, contract, receipt, preflight = verify_declared_zero_world_qualification_authority(
        root=ROOT, closure_path=CLOSURE,
        schema_version="sporespore_qsdk_r24d51_rapier_discrete_staging_observer_qualification_closure_v1",
        gate_id="QSDK-R24D51", closure_status=STATUS, source_commit=SOURCE,
        source_subject="[recovery/rapier] Freeze R51 discrete staging observer",
        source_binding_names=("observer", "observer_entrypoint",
                              "common_conformance_helper", "shared_runner", "source_audit"),
        predecessor_status="closed_repeatable_zero_world_retained_trace_diagnosis_gravity_force_staging_observer_boundary_localized_physics_blocked",
        attempt_schema="sporespore_qsdk_r24d51_rapier_discrete_staging_zero_world_attempt_v1",
        receipt_schema="sporespore_qsdk_r24d51_rapier_discrete_staging_zero_world_receipt_v1",
        qualification_directory_prefix="qsdk-r24d51-rapier-discrete-staging-qualification-",
        expected_checks=CHECKS, checkout_only_metadata=(),
        retained_log_markers={
            "01-source-audit.log": "QSDK_R24D51_RAPIER_DISCRETE_STAGING_SOURCE_PASS",
            "03-refusal-parallel.log": "qualified only for the sequential scalar solver",
            "03-refusal-simd-stable.log": "qualified only for scalar rigid impulse-joint constraints",
            "04-production-preflight.log": "QSDK_R24D51_RAPIER_DISCRETE_STAGING_ZERO_WORLD ",
        },
    )
    verify_exact_paths(contract, {
        "gate_id": "QSDK-R24D51", "question_class": "development",
        "physical_question_declared": False,
        "supported_design_envelope.solver_small_steps_per_outer_step": 16,
        "observer_semantics.rule_id": "rapier_discrete_force_position_half_step_staging_exchange_v1",
        "complete_zero_world_gate.positive_control_count": 5,
        "complete_zero_world_gate.mutation_rejection_count": 8,
        "complete_zero_world_gate.total_preflight_check_count": 13,
    }, "CONTRACT")
    exact(len(contract["source_inventory"]), 22, "SOURCE_COUNT")
    dependency = __import__("json").loads(
        (ROOT / contract["qualification_runner"]["pinned_dependency_contract_path"])
        .read_text(encoding="utf-8"))["pinned_dependency"]
    exact((receipt["registry_archive"]["raw_sha256"],
           receipt["registry_archive"]["byte_length"], receipt["patch_raw_sha256"]),
          ("sha256:" + dependency["cargo_registry_checksum"],
           dependency["registry_archive_byte_length"], dependency["patch_raw_sha256"]),
          "PINNED_DEPENDENCY")

    verify_exact_paths(preflight, {
        "qualification_class": "zero_world_discrete_force_position_staging_observer_design",
        "question_class": "development", "check_count": 13, "checks_passed": 13,
        "control_count": 5, "mutation_rejection_count": 8,
        "mechanical_energy_change_used_as_observer_input": False,
        "energy_balance_residual_used_as_observer_input": False,
        "acceptance_threshold_used_as_observer_input": False,
        "native_runtime_wiring_implemented": False,
        "new_engine_neutral_ledger_mapping_implemented": False,
        "accepted_fixtures.supported_rest.force_integration_kinetic_exchange_j":
            0.0009837430555555554,
        "accepted_fixtures.supported_rest.raw_gravity_potential_position_exchange_j": 0.0,
        "accepted_fixtures.supported_rest.endpoint_half_step_projection_exchange_j": 0.0,
        "accepted_fixtures.free_fall.signed_discrete_staging_exchange_j":
            0.014756145833326503,
        "accepted_fixtures.zero_gravity.signed_discrete_staging_exchange_j": 0.0,
        "model_construction_count": 0, "world_build_count": 0, "solver_step_count": 0,
        "physical_question_opened": False, "prone_to_standing_claimed": False,
    }, "PREFLIGHT")
    exact([item["control_id"] for item in preflight["controls"]], CONTROL_IDS, "CONTROLS")
    require(all(item["passed"] is True for item in preflight["controls"]), "CONTROL_PASS")
    exact(preflight["mutation_ids"], MUTATION_IDS, "MUTATION_IDS")
    mutations = preflight["mutation_rejections"]
    exact([item["mutation_id"] for item in mutations], MUTATION_IDS, "MUTATION_RECEIPTS")
    exact([item["expected_code"] for item in mutations], MUTATION_CODES, "MUTATION_CODES")
    require(all(item["rejected"] is True and item["observed_code"].startswith(
        item["expected_code"]) for item in mutations), "MUTATION_REJECTIONS")

    q = closure["qualification"]
    exact((q["check_count"], q["checks_passed"], q["expected_compile_refusal_count"],
           q["preflight_check_count"], q["preflight_checks_passed"],
           q["positive_control_count"], q["mutation_rejection_count"]),
          (12, 12, 2, 13, 13, 5, 8), "QUALIFICATION_COUNTS")
    decision = closure["decision"]
    verify_exact_paths(decision, {
        "result": "positive_rapier_discrete_force_position_staging_observer_design_qualified_zero_world",
        "rapier_version": "0.34.0", "mutation_rejection_count": 8,
        "new_behavior_threshold_count": 0, "new_empirical_threshold_count": 0,
        "new_margin_count": 0, "physical_cohort_count": 0,
        "held_out_cohort_count": 0, "population_claim_count": 0,
    }, "DECISION")
    verify_boolean_partition(decision, (
        "pure_staging_observer_design_qualified", "force_integration_kinetic_component_qualified",
        "raw_gravity_potential_position_component_qualified",
        "endpoint_half_step_projection_component_qualified",
        "ordered_sixteen_small_step_population_qualified", "supported_rest_control_qualified",
        "free_fall_control_qualified", "upward_downward_and_zero_gravity_controls_qualified",
        "all_declared_mutations_rejected", "parallel_compile_refusal_qualified",
        "simd_compile_refusal_qualified", "source_population_content_addressed",
        "retained_evidence_tree_content_addressed", "r24d51_closed_without_physics",
    ), (
        "native_boundary_telemetry_implemented", "native_boundary_telemetry_qualified",
        "engine_neutral_staging_ledger_implemented", "retained_r49_residual_recomputed",
        "retained_r49_result_reclassified", "controller_changed", "native_physics_changed",
        "morphology_changed", "initializer_changed", "r24d51_physical_execution_permitted",
    ), "DECISION")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    verify_exact_paths(closure["next_boundary"], {
        "gate_id": "QSDK-R24D52", "question_class": "not_yet_declared",
        "maximum_physical_steps_authorized": 0,
        "r24d51_may_be_requalified": False,
        "r24d49_may_be_rerun_or_rethresholded": False,
    }, "NEXT")
    verify_boolean_partition(closure["claim_boundary"], (
        "official_zero_world_qualification_passed", "pure_staging_observer_design_qualified",
        "all_five_analytic_controls_passed", "all_eight_declared_mutations_rejected",
        "parallel_and_simd_refusals_qualified", "source_population_content_addressed",
        "retained_evidence_tree_content_addressed", "r24d51_closed_without_physics",
    ), (
        "native_boundary_telemetry_implemented", "native_boundary_telemetry_qualified",
        "engine_neutral_staging_ledger_implemented", "new_physical_observation_made",
        "retained_r49_residual_recomputed", "retained_r49_result_reclassified",
        "controller_physical_viability_proven", "prone_to_standing_claimed",
        "repeatability_rate_claimed", "population_claimed", "held_out_validation_claimed",
        "cross_engine_recovery_claimed", "cross_engine_equivalence_claimed",
        "sdk1_milestone_advanced", "physical_acceptance_authority", "release_authority",
    ), "CLAIM")

    evidence_root = Path(q["evidence_root"])
    verify_retained_file_tree(evidence_root, q["retained_tree"])
    rejected = 0
    for mutation in ({**q["retained_tree"], "file_count": 149},
                     {**q["retained_tree"], "manifest_canonical_sha256": "sha256:" + "0" * 64}):
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
            "r24d51_closure_raw_sha256": sha256(raw)}
    verify_legacy_live_gate_paths(ROOT, closure["live_authority_paths"],
                                  "QSDK-R24D45", live, revision=revision)
    print("QSDK_R24D51_RAPIER_DISCRETE_STAGING_QUALIFICATION_CLOSURE_PASS "
          "sources=22 checks=12/12 preflight=13/13 controls=5 mutations=8+2 "
          "refusals=2 tree_files=148 models=0 worlds=0 solver_steps=0 "
          "physical=false sdk1=11/20 next=QSDK-R24D52")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D51_RAPIER_DISCRETE_STAGING_QUALIFICATION_CLOSURE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
