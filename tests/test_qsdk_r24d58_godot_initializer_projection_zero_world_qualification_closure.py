"""Compact, data-driven audit of the retained zero-world R24D58 closure."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, git, sha256, source_bytes,
    verify_boolean_partition, verify_declared_zero_world_qualification_authority,
    verify_exact_paths, verify_legacy_live_gate_paths,
)

CLOSURE = ROOT / "sdk/recovery/r24d58_godot_initializer_projection_zero_world_qualification_closure_v1.json"
SOURCE = "1fd5e2fe540d197e6c96813add3e30295dbe2bca"
STATUS = "closed_complete_zero_world_initializer_native_projection_and_supervisor_transport_qualified_one_two_step_development_ghost_authorized"
CHECKS = (
    "core_dynamic_library_rebuilt", "core_targeted_tests_passed",
    "godot_adapter_binding_check_passed", "godot_adapter_debug_build_passed",
    "python_binding_smoke_passed", "versioning_conformance_passed",
    "source_contract_audit_passed", "production_preflight_passed",
    "worktree_unchanged",
)
TRUE = (
    "r24d57_invalid_result_preserved", "native_projection_successor_implemented",
    "native_projection_successor_zero_world_qualified", "authored_initializer_unchanged",
    "readback_tolerance_unchanged", "attempted_and_completed_construction_counts_separated",
    "supervisor_output_and_exit_projection_qualified",
    "inherited_native_route_zero_world_qualification_preserved",
    "all_projection_controls_passed", "all_declared_mutations_rejected",
    "source_population_content_addressed", "retained_evidence_tree_content_addressed",
    "physical_ghost_authorized",
)
DECISION_FALSE = (
    "physical_attempted", "native_world_constructed", "solver_step_executed",
    "native_runtime_observation_collection_executed", "portable_command_application_executed",
    "controller_behavior_evaluated", "exact_nominal_godot_prone_to_standing_observed",
    "prone_to_standing_claimed", "repeatability_rate_claimed", "population_claimed",
    "held_out_validation_claimed", "cross_engine_recovery_claimed",
    "cross_engine_equivalence_claimed", "sdk1_milestone_advanced",
    "physical_acceptance_authority", "release_authority",
)
CLAIM_FALSE = tuple(
    "controller_physical_viability_proven" if key == "controller_behavior_evaluated" else key
    for key in DECISION_FALSE
)


def audit() -> None:
    closure, contract, receipt, preflight = verify_declared_zero_world_qualification_authority(
        root=ROOT, closure_path=CLOSURE,
        schema_version="sporespore_qsdk_r24d58_godot_initializer_projection_zero_world_qualification_closure_v1",
        gate_id="QSDK-R24D58", closure_status=STATUS, source_commit=SOURCE,
        source_subject="[recovery/godot] Freeze R58 initializer projection successor",
        source_binding_names=("source_audit", "projection_worker", "native_world",
                              "shared_ghost_supervisor", "ghost_binding", "shared_ghost_worker"),
        predecessor_status="closed_consumed_invalid_native_initializer_readback_before_world_completion_or_solver_step",
        attempt_schema="sporespore_qsdk_r24d58_godot_initializer_projection_qualification_attempt_v1",
        receipt_schema="sporespore_qsdk_r24d58_godot_initializer_projection_qualification_receipt_v1",
        qualification_directory_prefix="qsdk-r24d58-godot-initializer-projection-qualification",
        expected_checks=CHECKS, checkout_only_metadata=(), physical_question_declared=True,
        retained_log_markers={
            "source_audit.log": "QSDK_R24D58_GODOT_INITIALIZER_PROJECTION_SUCCESSOR_SOURCE_PASS",
            "cargo_targeted_tests.log": "test result: ok. 1 passed; 0 failed",
            "production_preflight.log": '"schema_version":"sporespore_qsdk_r24d58_godot_initializer_projection_successor_preflight_v1"',
            "versioning_conformance.log": "Ran 6 tests",
        },
    )

    verify_exact_paths(contract, {
        "gate_id": "QSDK-R24D58", "question_class": "development",
        "physical_question_declared": False,
        "initializer_representation_contract.profile_id": "godot_4_7_real_t_basis_relative_angle_projection_v1",
        "initializer_representation_contract.readback_tolerance_rad": 1e-8,
        "initializer_representation_contract.readback_tolerance_changed_from_r24d57": False,
        "initializer_representation_contract.authored_initializer_changed": False,
        "complete_zero_world_gate.official_qualification_run_count": 1,
        "next_boundary_if_positive.seed": 408048331,
        "next_boundary_if_positive.maximum_world_build_count": 1,
        "next_boundary_if_positive.maximum_outer_solver_steps": 2,
        "next_boundary_if_positive.same_identity_rerun_permitted": False,
    }, "CONTRACT")
    exact(len(contract["source_inventory"]), 37, "SOURCE_COUNT")

    verify_exact_paths(preflight, {
        "schema_version": "sporespore_qsdk_r24d58_godot_initializer_projection_successor_preflight_v1",
        "runtime_id": "godot_4_7_real_t_basis_relative_angle_projection_v1",
        "source_inventory_count": 37, "bound_predecessor_count": 3,
        "instrumented_runtime_positive_count": 1, "stock_runtime_negative_count": 1,
        "inherited_route_mutation_count": 6, "projection_mutation_count": 4,
        "supervisor_forced_failure_control_count": 1,
        "projection_receipt.projection_count": 8,
        "projection_receipt.sign_preservation_count": 8,
        "projection_receipt.mutation_rejection_count": 4,
        "projection_receipt.readback_tolerance_rad": 1e-8,
        "projection_receipt.readback_tolerance_changed_from_r24d57": False,
        "projection_receipt.authored_initializer_changed": False,
        "supervisor_projection_receipt.status": "forced_failure_projection_control",
        "model_construction_count": 0, "world_attempt_count": 0,
        "world_build_count": 0, "solver_step_count": 0,
        "native_runtime_observation_collection_executed": False,
        "prone_to_standing_claimed": False,
    }, "PREFLIGHT")
    q = closure["qualification"]
    exact((q["check_count"], q["checks_passed"], q["source_inventory_count"],
           q["retained_tree"]["file_count"], receipt["held_out_cell_access_count"]),
          (9, 9, 37, 9, 0), "QUALIFICATION_COUNTS")

    decision = closure["decision"]
    verify_exact_paths(decision, {
        "result": "positive_zero_world_initializer_native_projection_and_supervisor_transport_qualified",
        "initializer_readback_tolerance_rad": 1e-8, "seed": 408048331,
        "authorized_world_count": 1, "maximum_outer_solver_steps": 2,
        "new_behavior_threshold_count": 0, "new_empirical_threshold_count": 0,
        "new_margin_count": 0, "observed_physical_cohort_count": 0,
        "held_out_cohort_count": 0, "population_claim_count": 0,
    }, "DECISION")
    verify_boolean_partition(decision, TRUE, DECISION_FALSE, "DECISION")
    verify_boolean_partition(closure["claim_boundary"],
                             ("official_zero_world_qualification_passed",) + TRUE,
                             CLAIM_FALSE, "CLAIM")
    exact(closure["sdk_status"], {
        "sdk1_milestone_advanced": False, "sdk1_completed_steps": 11,
        "sdk1_total_steps": 20, "full_program_completed_steps": 11,
        "full_program_total_steps": 25,
    }, "SDK_STATUS")
    verify_exact_paths(closure["next_boundary"], {
        "gate_id": "QSDK-R24D58", "question_class": "development",
        "physical_question_declared": True, "complete_zero_world_gate_passed": True,
        "seed": 408048331, "held_out": False, "held_out_cells_remain_sealed": True,
        "full_seeded_ghost_required": False, "additional_physical_canary_required": False,
        "authorized_world_count": 1, "maximum_outer_solver_steps": 2,
        "maximum_physical_steps_authorized": 2, "same_source_physical_attempt_limit": 1,
        "same_identity_rerun_permitted": False, "recovery_success_required": False,
        "physical_execution_authorized": True,
    }, "NEXT")

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    assert isinstance(publication, str)
    revision = publication or None
    raw = CLOSURE.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    live = {**closure["live_gate_expectations"],
            "r24d58_zero_world_closure_raw_sha256": sha256(raw)}
    verify_legacy_live_gate_paths(ROOT, closure["live_authority_paths"],
                                  "QSDK-R24D45", live, revision=revision)
    print("QSDK_R24D58_GODOT_INITIALIZER_PROJECTION_ZERO_WORLD_QUALIFICATION_"
          "CLOSURE_PASS sources=37 checks=9/9 retained=9 inherited=1+1+6 "
          "projections=8 mutations=4 supervisor_exit=23 models=0 worlds=0 "
          "steps=0 ghost_authorized=1x2 sdk1=11/20")


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, TypeError, ValueError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D58_GODOT_INITIALIZER_PROJECTION_ZERO_WORLD_QUALIFICATION_CLOSURE_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
