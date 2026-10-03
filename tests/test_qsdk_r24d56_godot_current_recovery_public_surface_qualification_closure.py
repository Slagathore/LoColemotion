"""Compact audit of the retained zero-world QSDK-R24D56 closure."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, git, load, loads, sha256, source_bytes,
    verify_boolean_partition, verify_exact_paths, verify_exact_retained_inventory,
    verify_legacy_live_gate_paths, verify_retained_commit, verify_source_binding,
    verify_zero_world_qualification_closure,
)

CLOSURE = ROOT / (
    "sdk/recovery/"
    "r24d56_godot_current_recovery_public_surface_qualification_closure_v1.json"
)
SOURCE = "dbc9a3cd72f1a106beef2daf46f413d8e6cdb1cf"
PARENT = "367114bee5f6228fcab95938304e7e632a8f3e0f"
STATUS = (
    "closed_complete_zero_world_current_recovery_public_surface_qualified_"
    "native_godot_route_pending"
)
CHECKS = (
    "core_dynamic_library_rebuilt", "core_targeted_tests_passed",
    "godot_adapter_binding_check_passed", "godot_adapter_debug_build_passed",
    "python_binding_smoke_passed", "versioning_conformance_passed",
    "source_contract_audit_passed", "production_preflight_passed",
    "worktree_unchanged",
)
CLAIM_TRUE = (
    "official_zero_world_qualification_passed",
    "current_recovery_core_public_surface_implemented",
    "current_recovery_python_surface_implemented",
    "current_recovery_godot_surface_implemented",
    "current_recovery_public_surface_zero_world_qualified",
    "all_twenty_four_godot_methods_present",
    "all_malformed_surface_controls_passed", "energy_v3_exact_fixture_passed",
    "source_population_content_addressed",
    "retained_evidence_population_content_addressed", "r55_positive_result_preserved",
)
CLAIM_FALSE = (
    "native_godot_recovery_collector_implemented", "native_godot_recovery_route_implemented",
    "native_runtime_observation_collection_executed", "new_physical_observation_made",
    "controller_physical_viability_proven", "exact_nominal_godot_prone_to_standing_observed",
    "all_engine_canonical_prone_to_standing_claimed", "repeatability_rate_claimed",
    "population_claimed", "held_out_validation_claimed", "cross_engine_recovery_claimed",
    "cross_engine_equivalence_claimed", "sdk1_milestone_advanced",
    "physical_execution_authorized", "physical_acceptance_authority", "release_authority",
)


def audit() -> None:
    closure = load(CLOSURE)
    verify_exact_paths(closure, {
        "schema_version": (
            "sporespore_qsdk_r24d56_godot_current_recovery_public_surface_"
            "qualification_closure_v1"
        ),
        "gate_id": "QSDK-R24D56", "closure_status": STATUS,
        "question_class": "development", "physical_question_declared": False,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False,
    }, "CLOSURE")
    verify_retained_commit(ROOT, SOURCE, PARENT)
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE), closure["source"]["tree"], "TREE")
    exact(git(ROOT, "show", "-s", "--format=%s", SOURCE),
          closure["source"]["subject"], "SUBJECT")

    contract = loads(verify_source_binding(ROOT, SOURCE, closure["source"]["contract"]))
    verify_exact_paths(contract, {
        "gate_id": "QSDK-R24D56", "question_class": "development",
        "physical_question_declared": False,
        "public_surface.public_abi_symbol_count_after_change": 55,
        "public_surface.registered_schema_count_after_change": 89,
        "public_surface.new_core_public_entrypoint_count": 4,
        "public_surface.godot_input_method_count": 24,
        "complete_zero_world_gate.official_qualification_run_count": 1,
        "complete_zero_world_gate.new_abi_forced_failure_count": 4,
        "complete_zero_world_gate.godot_direct_core_refusal_count": 24,
        "complete_zero_world_gate.godot_local_schema_mutation_rejection_count": 24,
        "complete_zero_world_gate.maximum_physical_steps_authorized": 0,
        "claim_boundary.sdk1_milestone_score_after": "11/20",
        "claim_boundary.full_program_score_after": "11/25",
    }, "CONTRACT")
    exact(len(contract["source_inventory"]), 26, "SOURCE_COUNT")

    _attempt, receipt, preflight = verify_zero_world_qualification_closure(
        root=ROOT, closure=closure, gate_id="QSDK-R24D56", source_commit=SOURCE,
        attempt_schema=(
            "sporespore_qsdk_r24d56_godot_recovery_public_surface_qualification_attempt_v1"
        ),
        receipt_schema=(
            "sporespore_qsdk_r24d56_godot_recovery_public_surface_qualification_receipt_v1"
        ),
        qualification_directory_prefix=(
            "qsdk-r24d56-godot-recovery-public-surface-qualification-"
        ),
        contract_inventory=contract["source_inventory"], expected_checks=CHECKS,
        source_manifest_raw_representation="observed_checkout_plus_git_blob",
    )
    qualification = closure["qualification"]
    verify_exact_retained_inventory(
        Path(qualification["evidence_root"]), qualification["retained_artifacts"]
    )
    exact((receipt["contract_path"], receipt["contract_raw_sha256"]),
          (closure["source"]["contract"]["path"],
           closure["source"]["contract"]["raw_sha256"]), "RECEIPT_CONTRACT")
    verify_exact_paths(preflight, {
        "runtime_id": "sporespore_godot_current_recovery_public_surface_v1",
        "runtime_version": "recovery_observation_v3_step_and_evaluator_v4",
        "abi_symbol_count": 55, "schema_count": 89, "source_inventory_count": 26,
        "godot_input_method_count": 24, "new_abi_forced_failure_count": 4,
        "energy_v3_signed_residual_j": 0.0, "held_out_cell_access_count": 0,
        "model_construction_count": 0, "world_attempt_count": 0,
        "world_build_count": 0, "solver_step_count": 0,
        "physics_state_modified": False, "stock_godot_profile_promoted": False,
        "instrumented_godot_profile_substituted": False,
        "native_runtime_observation_collection_executed": False,
        "prone_to_standing_claimed": False, "physical_acceptance_authority": False,
        "release_authority": False,
        "godot_receipt.ok": True, "godot_receipt.input_method_count": 24,
        "godot_receipt.input_method_present_count": 24,
        "godot_receipt.direct_core_refusal_count": 24,
        "godot_receipt.local_schema_mutation_count": 24,
        "godot_receipt.local_schema_mutation_rejection_count": 24,
        "godot_receipt.missing_methods": [], "godot_receipt.model_construction_count": 0,
        "godot_receipt.world_attempt_count": 0, "godot_receipt.world_build_count": 0,
        "godot_receipt.solver_step_count": 0,
    }, "PREFLIGHT")
    exact((qualification["check_count"], qualification["checks_passed"],
           qualification["source_inventory_count"], qualification["public_abi_symbol_count"],
           qualification["registered_schema_count"], qualification["godot_input_method_count"],
           qualification["retained_artifact_count"]),
          (9, 9, 26, 55, 89, 24, 9), "QUALIFICATION_COUNTS")

    decision = closure["decision"]
    verify_exact_paths(decision, {
        "result": (
            "positive_current_recovery_public_surface_qualified_zero_world_"
            "native_godot_route_pending"
        ),
        "new_public_c_abi_symbol_count": 4, "public_c_abi_symbol_count": 55,
        "new_registered_schema_count": 10, "registered_schema_count": 89,
        "godot_input_method_count": 24, "authorized_world_count": 0,
        "maximum_physical_steps_authorized": 0, "new_behavior_threshold_count": 0,
        "new_empirical_threshold_count": 0, "new_margin_count": 0,
        "observed_physical_cohort_count": 0, "held_out_cohort_count": 0,
        "population_claim_count": 0, "controller_changed": False,
        "threshold_changed": False, "margin_changed": False,
        "selector_changed": False, "evaluator_changed": False,
        "morphology_changed": False, "initializer_changed": False,
        "r24d56_zero_world_requalification_permitted": False,
    }, "DECISION")
    claim = closure["claim_boundary"]
    verify_boolean_partition(claim, CLAIM_TRUE, CLAIM_FALSE, "CLAIM")
    for key, value in claim.items():
        if key in decision:
            exact(decision[key], value, f"DECISION_CLAIM:{key}")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    verify_exact_paths(closure["next_boundary"], {
        "gate_id": "QSDK-R24D57", "question_class": "development",
        "status": (
            "native_godot_recovery_route_declaration_and_zero_world_qualification_pending"
        ),
        "physical_question_declared": False, "complete_zero_world_gate_passed": False,
        "held_out_seed_access_permitted": False, "full_seeded_ghost_required": False,
        "short_route_ghost_maximum_outer_steps_if_authorized": 2,
        "short_route_ghost_authorized": False, "authorized_world_count": 0,
        "maximum_physical_steps_authorized": 0, "physical_execution_authorized": False,
    }, "NEXT")

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    assert isinstance(publication, str)
    revision = publication or None
    raw = CLOSURE.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    live = {**closure["live_gate_expectations"],
            "r24d56_closure_raw_sha256": sha256(raw)}
    verify_legacy_live_gate_paths(ROOT, closure["live_authority_paths"],
                                  "QSDK-R24D45", live, revision=revision)
    print("QSDK_R24D56_GODOT_CURRENT_RECOVERY_PUBLIC_SURFACE_QUALIFICATION_"
          "CLOSURE_PASS sources=26 checks=9/9 abi=55 schemas=89 godot=24/24 "
          "direct_refusals=24 local_refusals=24 retained=9 models=0 worlds=0 "
          "solver_steps=0 physical=false sdk1=11/20 next=QSDK-R24D57")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print("QSDK_R24D56_GODOT_CURRENT_RECOVERY_PUBLIC_SURFACE_QUALIFICATION_"
              f"CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
