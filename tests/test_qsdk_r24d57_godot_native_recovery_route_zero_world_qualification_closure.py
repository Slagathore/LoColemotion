"""Compact audit of the retained zero-world QSDK-R24D57 closure."""

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
    loads,
    sha256,
    source_bytes,
    verify_boolean_partition,
    verify_exact_paths,
    verify_exact_retained_inventory,
    verify_legacy_live_gate_paths,
    verify_retained_commit,
    verify_source_binding,
    verify_zero_world_qualification_closure,
)

CLOSURE = ROOT / (
    "sdk/recovery/"
    "r24d57_godot_native_recovery_route_zero_world_qualification_closure_v1.json"
)
SOURCE = "931ee0f5210e448f92a7953b546896f7ca6346a1"
PARENT = "521248ea97c048ebcb572b1fe6758dc2b354c718"
STATUS = (
    "closed_complete_zero_world_native_godot_recovery_route_qualified_"
    "one_two_step_development_ghost_authorized"
)
CHECKS = (
    "core_dynamic_library_rebuilt",
    "core_targeted_tests_passed",
    "godot_adapter_binding_check_passed",
    "godot_adapter_debug_build_passed",
    "python_binding_smoke_passed",
    "versioning_conformance_passed",
    "source_contract_audit_passed",
    "production_preflight_passed",
    "worktree_unchanged",
)
CLAIM_TRUE = (
    "official_zero_world_qualification_passed",
    "native_godot_recovery_route_implemented",
    "native_godot_recovery_world_builder_implemented",
    "native_godot_recovery_sampler_implemented",
    "zero_world_route_qualified",
    "native_world_blueprint_qualified",
    "all_six_declared_mutations_rejected",
    "stock_runtime_refusal_qualified",
    "source_population_content_addressed",
    "retained_evidence_population_content_addressed",
    "physical_ghost_authorized",
)
CLAIM_FALSE = (
    "physical_attempted",
    "native_runtime_observation_collection_executed",
    "new_physical_observation_made",
    "controller_physical_viability_proven",
    "exact_nominal_godot_prone_to_standing_observed",
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
    closure = load(CLOSURE)
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d57_godot_native_recovery_route_zero_world_"
                "qualification_closure_v1"
            ),
            "gate_id": "QSDK-R24D57",
            "closure_status": STATUS,
            "question_class": "development",
            "physical_question_declared": True,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
        },
        "CLOSURE",
    )
    verify_retained_commit(ROOT, SOURCE, PARENT)
    exact(closure["source"]["source_freeze_commit"], SOURCE, "SOURCE_FREEZE")
    exact(closure["source"]["commit"], SOURCE, "SOURCE_COMMIT")
    exact(git(ROOT, "show", "-s", "--format=%T", SOURCE), closure["source"]["tree"], "TREE")
    exact(
        git(ROOT, "show", "-s", "--format=%s", SOURCE),
        closure["source"]["subject"],
        "SUBJECT",
    )

    contract = loads(verify_source_binding(ROOT, SOURCE, closure["source"]["contract"]))
    verify_exact_paths(
        contract,
        {
            "gate_id": "QSDK-R24D57",
            "question_class": "development",
            "physical_question_declared": False,
            "complete_zero_world_gate.official_qualification_run_count": 1,
            "complete_zero_world_gate.route_mutation_count": 6,
            "complete_zero_world_gate.native_world_blueprint_body_count": 9,
            "complete_zero_world_gate.native_world_blueprint_joint_count": 8,
            "complete_zero_world_gate.native_world_blueprint_contact_site_count": 4,
            "complete_zero_world_gate.maximum_physical_steps_authorized": 0,
            "next_boundary_if_positive.maximum_world_build_count": 1,
            "next_boundary_if_positive.maximum_outer_solver_steps": 2,
            "next_boundary_if_positive.physics_ticks_per_second": 120,
            "next_boundary_if_positive.held_out": False,
            "next_boundary_if_positive.same_identity_rerun_permitted": False,
            "claim_boundary.sdk1_milestone_score_after": "11/20",
            "claim_boundary.full_program_score_after": "11/25",
        },
        "CONTRACT",
    )
    exact(len(contract["source_inventory"]), 31, "SOURCE_COUNT")

    _attempt, receipt, preflight = verify_zero_world_qualification_closure(
        root=ROOT,
        closure=closure,
        gate_id="QSDK-R24D57",
        source_commit=SOURCE,
        attempt_schema="sporespore_qsdk_r24d57_qualification_attempt_v1",
        receipt_schema="sporespore_qsdk_r24d57_qualification_receipt_v1",
        qualification_directory_prefix=(
            "qsdk-r24d57-godot-native-recovery-route-qualification-"
        ),
        contract_inventory=contract["source_inventory"],
        expected_checks=CHECKS,
        source_manifest_raw_representation="observed_checkout_plus_git_blob",
    )
    qualification = closure["qualification"]
    verify_exact_retained_inventory(
        Path(qualification["evidence_root"]), qualification["retained_artifacts"]
    )
    exact(
        (receipt["contract_path"], receipt["contract_raw_sha256"]),
        (
            closure["source"]["contract"]["path"],
            closure["source"]["contract"]["raw_sha256"],
        ),
        "RECEIPT_CONTRACT",
    )
    verify_exact_paths(
        preflight,
        {
            "runtime_id": (
                "sporespore_qsdk_r24d57_godot_jolt_recovery_observation_v3_route_v1"
            ),
            "runtime_version": (
                "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2"
            ),
            "source_inventory_count": 31,
            "bound_predecessor_count": 3,
            "instrumented_runtime_positive_count": 1,
            "stock_runtime_negative_count": 1,
            "forced_failure_route_control_count": 1,
            "route_mutation_count": 6,
            "held_out_cell_access_count": 0,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "native_runtime_observation_collection_executed": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
            "instrumented_receipt.ok": True,
            "instrumented_receipt.mutation_rejection_count": 6,
            "instrumented_receipt.native_world_blueprint_body_count": 9,
            "instrumented_receipt.native_world_blueprint_joint_count": 8,
            "instrumented_receipt.native_world_blueprint_contact_site_count": 4,
            "instrumented_receipt.host_write_count": 8,
            "instrumented_receipt.host_readback_count": 8,
            "stock_receipt.stock_runtime_route_refusal_count": 1,
        },
        "PREFLIGHT",
    )
    exact(
        (
            qualification["check_count"],
            qualification["checks_passed"],
            qualification["source_manifest_entry_count"],
            qualification["retained_artifact_count"],
            qualification["route_mutation_rejection_count"],
        ),
        (9, 9, 31, 9, 6),
        "QUALIFICATION_COUNTS",
    )

    verify_exact_paths(
        closure["decision"],
        {
            "physical_ghost_authorized": True,
            "maximum_world_build_count": 1,
            "maximum_outer_solver_steps": 2,
            "physics_ticks_per_second": 120,
            "outer_step_duration_s": 1.0 / 120.0,
            "seed": 1656561876,
            "held_out": False,
            "full_seeded_world_demo": False,
            "same_identity_rerun_permitted": False,
            "recovery_success_required": False,
            "new_behavior_threshold_count": 0,
            "new_margin_count": 0,
            "observed_physical_cohort_count": 0,
            "population_claim_count": 0,
        },
        "DECISION",
    )
    verify_boolean_partition(closure["claim_boundary"], CLAIM_TRUE, CLAIM_FALSE, "CLAIM")
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
            "gate_id": "QSDK-R24D57",
            "question_class": "development",
            "physical_question_declared": True,
            "complete_zero_world_gate_passed": True,
            "authorized_world_count": 1,
            "maximum_outer_solver_steps": 2,
            "maximum_physical_steps_authorized": 2,
            "full_seeded_ghost_required": False,
            "additional_physical_canary_required": False,
            "physical_execution_authorized": True,
            "same_source_physical_attempt_limit": 1,
            "held_out_cells_remain_sealed": True,
        },
        "NEXT",
    )
    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    assert isinstance(publication, str)
    revision = publication or None
    raw = CLOSURE.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    live = {
        **closure["live_gate_expectations"],
        "r24d57_closure_raw_sha256": sha256(raw),
    }
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        live,
        revision=revision,
    )
    print(
        "QSDK_R24D57_GODOT_NATIVE_RECOVERY_ROUTE_ZERO_WORLD_QUALIFICATION_"
        "CLOSURE_PASS sources=31 checks=9/9 retained=9 instrumented=1 stock=1 "
        "mutations=6/6 blueprint=9/8/4 commands=8 models=0 worlds=0 steps=0 "
        "ghost_authorized=1x2 sdk1=11/20"
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
            "QSDK_R24D57_GODOT_NATIVE_RECOVERY_ROUTE_ZERO_WORLD_QUALIFICATION_"
            f"CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
