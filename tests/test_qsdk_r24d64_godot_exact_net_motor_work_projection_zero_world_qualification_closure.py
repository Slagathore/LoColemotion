"""Compact audit of the retained zero-world R24D64 qualification closure."""

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
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
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d64_godot_exact_net_motor_work_projection_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "1007801eb39a60044c9236d3485dfc2da913e4bb"
STATUS = (
    "closed_complete_zero_world_exact_net_motor_work_projection_qualified_"
    "published_closure_control_required_physics_blocked"
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
TRUE = (
    "r63_invalid_result_preserved",
    "r63_same_identity_not_rerun",
    "exact_net_motor_work_projection_implemented",
    "native_positive_work_preserved",
    "native_absorbed_work_preserved",
    "raw_native_net_work_preserved",
    "native_float32_identity_checked_exactly",
    "public_binary64_net_work_derived_from_exported_components",
    "projection_delta_retained",
    "same_r63_validator_used_after_projection",
    "native_engine_telemetry_patch_unchanged",
    "telemetry_tolerances_unchanged",
    "zero_world_successor_qualified",
    "all_declared_mutations_rejected",
    "inherited_failure_passthroughs_preserved",
    "exact_r63_replay_passed",
    "inherited_route_authorization_controls_passed",
    "supervisor_forced_failure_preserved",
    "missing_physical_switch_refusal_proven",
    "source_population_content_addressed",
    "retained_evidence_tree_content_addressed",
    "published_closure_control_required",
    "physical_execution_blocked_until_published_closure_control",
)
DECISION_FALSE = (
    "published_closure_control_executed",
    "physical_ghost_authorized",
    "physical_attempted",
    "native_world_constructed",
    "solver_step_executed",
    "native_runtime_observation_collection_executed",
    "portable_command_application_executed",
    "controller_behavior_evaluated",
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
CLAIM_FALSE = tuple(
    "controller_physical_viability_proven"
    if key == "controller_behavior_evaluated"
    else key
    for key in DECISION_FALSE
)


def audit() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d64_godot_exact_net_motor_work_projection_"
                "zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D64",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject="[recovery/godot] Freeze R64: exact net-work projection",
            source_binding_names=(
                "shared_zero_world_controls",
                "source_audit",
                "native_world",
                "native_route",
                "ghost_binding",
                "zero_world_worker",
            ),
            predecessor_status=(
                "closed_consumed_invalid_second_step_net_motor_work_identity_"
                "float32_projection_mismatch"
            ),
            attempt_schema=(
                "sporespore_qsdk_r24d64_godot_exact_net_motor_work_projection_"
                "qualification_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d64_godot_exact_net_motor_work_projection_"
                "qualification_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d64-godot-exact-net-motor-work-projection-"
                "qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(),
            physical_question_declared=False,
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D64_GODOT_EXACT_NET_MOTOR_WORK_PROJECTION_SOURCE_PASS"
                ),
                "cargo_targeted_tests.log": "test result: ok. 1 passed; 0 failed",
                "production_preflight.log": (
                    '"schema_version":"sporespore_qsdk_r24d64_godot_exact_'
                    'net_motor_work_projection_preflight_v1"'
                ),
                "versioning_conformance.log": "Ran 6 tests",
            },
        )
    )

    verify_exact_paths(
        contract,
        {
            "gate_id": "QSDK-R24D64",
            "question_class": "development",
            "physical_question_declared": False,
            "net_motor_work_projection_contract.projection_function": (
                "native_motor_work_projection_v1"
            ),
            "net_motor_work_projection_contract.native_float32_subtraction_function": (
                "_native_float32_subtract_v1"
            ),
            "net_motor_work_projection_contract.failure_code_prefix": (
                "QSDK_R24D64_WORLD_NATIVE_NET_WORK_FLOAT32_IDENTITY_INVALID:"
            ),
            "net_motor_work_projection_contract.downstream_validator_function": (
                "native_motor_telemetry_contract_v1"
            ),
            "net_motor_work_projection_contract.native_float32_source_identity_is_exact_equality": True,
            "net_motor_work_projection_contract.native_float32_source_identity_tolerance_count": 0,
            "net_motor_work_projection_contract.unchanged_net_work_identity_tolerance_j": 1e-12,
            "zero_world_controls.positive_control_count": 4,
            "zero_world_controls.binary64_identity_count": 4,
            "zero_world_controls.mismatch_mutation_count": 2,
            "zero_world_controls.mismatch_mutation_rejection_count": 2,
            "zero_world_controls.passthrough_control_count": 3,
            "zero_world_controls.r63_replay_count": 1,
            "zero_world_controls.r63_replay_exact": True,
            "controlled_change.native_engine_telemetry_patch_changed": False,
            "controlled_change.net_work_identity_tolerance_changed": False,
            "controlled_change.native_physics_changed": False,
            "published_closure_authorization_control.mode": "AuthorizationControl",
            "published_closure_authorization_control.control_must_close_before_physical_authority": True,
            "complete_zero_world_gate.official_qualification_run_count": 1,
            "next_boundary_if_positive.physical_execution_authorized": False,
        },
        "CONTRACT",
    )
    exact(len(contract["source_inventory"]), 81, "SOURCE_COUNT")

    verify_exact_paths(
        preflight,
        {
            "schema_version": (
                "sporespore_qsdk_r24d64_godot_exact_net_motor_work_projection_"
                "preflight_v1"
            ),
            "runtime_id": (
                "sporespore_qsdk_r24d64_native_float32_to_binary64_"
                "net_work_projection_v1"
            ),
            "runtime_version": (
                "godot_4_7_jolt_sporespore_motor_telemetry_"
                "active_step_snapshot_v2"
            ),
            "source_inventory_count": 81,
            "bound_predecessor_count": 3,
            "inherited_source_inventory_count": 71,
            "projection_positive_control_count": 4,
            "projection_binary64_identity_count": 4,
            "projection_mutation_count": 2,
            "projection_mutation_rejection_count": 2,
            "projection_passthrough_control_count": 3,
            "net_motor_work_projection_receipt.positive_control_count": 4,
            "net_motor_work_projection_receipt.binary64_identity_count": 4,
            "net_motor_work_projection_receipt.mismatch_mutation_count": 2,
            "net_motor_work_projection_receipt.mismatch_mutation_rejection_count": 2,
            "net_motor_work_projection_receipt.passthrough_control_count": 3,
            "net_motor_work_projection_receipt.r63_replay_count": 1,
            "net_motor_work_projection_receipt.r63_replay_exact": True,
            "net_motor_work_projection_receipt.r63_native_net_motor_work_j": 0.003383097006008029,
            "net_motor_work_projection_receipt.r63_projected_net_motor_work_j": 0.003383096965990262,
            "net_motor_work_projection_receipt.r63_projection_delta_j": 4.001776687800884e-11,
            "net_motor_work_projection_receipt.net_work_identity_tolerance_j": 1e-12,
            "net_motor_work_projection_receipt.threshold_changed": False,
            "supervisor_forced_failure_control_count": 1,
            "supervisor_projection_receipt.status": "forced_failure_projection_control",
            "missing_physical_switch_refusal_count": 1,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_question_opened": False,
            "prone_to_standing_claimed": False,
        },
        "PREFLIGHT",
    )
    qualification = closure["qualification"]
    exact(
        (
            qualification["check_count"],
            qualification["checks_passed"],
            qualification["source_inventory_count"],
            qualification["retained_tree"]["file_count"],
            receipt["held_out_cell_access_count"],
        ),
        (9, 9, 81, 9, 0),
        "QUALIFICATION_COUNTS",
    )

    exact(
        closure["physical_authorization"],
        {
            "schema_version": (
                "sporespore_qsdk_physical_route_authorization_projection_v1"
            ),
            "gate_id": "QSDK-R24D64",
            "question_class": "development",
            "zero_world_qualification_passed": True,
            "source_freeze_commit": SOURCE,
            "seed": 491850074,
            "seed_label": "QSDK-R24D64/ghost/godot/route-smoke-v1",
            "seed_sha256": (
                "sha256:1d51095aad1a7e667a50ced6972dfb1caf18eba354890391794c8a523aed3b9e"
            ),
            "held_out": False,
            "maximum_model_construction_attempt_count": 1,
            "maximum_model_construction_count": 1,
            "maximum_world_attempt_count": 1,
            "maximum_world_build_count": 1,
            "maximum_outer_solver_steps": 2,
            "physics_ticks_per_second": 120,
            "outer_step_duration_s": 0.008333333333333333,
            "same_identity_rerun_permitted": False,
            "recovery_success_required": False,
            "physical_execution_authorized": True,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "PHYSICAL_AUTHORIZATION",
    )

    decision = closure["decision"]
    verify_exact_paths(
        decision,
        {
            "result": "positive_zero_world_exact_net_motor_work_projection_qualified",
            "new_behavior_threshold_count": 0,
            "new_empirical_threshold_count": 0,
            "new_margin_count": 0,
            "observed_physical_cohort_count": 0,
            "held_out_cohort_count": 0,
            "population_claim_count": 0,
        },
        "DECISION",
    )
    verify_boolean_partition(decision, TRUE, DECISION_FALSE, "DECISION")
    verify_boolean_partition(
        closure["claim_boundary"],
        ("official_zero_world_qualification_passed",) + TRUE,
        CLAIM_FALSE,
        "CLAIM",
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
            "gate_id": "QSDK-R24D64",
            "question_class": "development",
            "mode": "AuthorizationControl",
            "exact_control_execution_limit": 1,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "maximum_physical_steps_authorized": 0,
            "held_out": False,
            "same_identity_rerun_permitted": False,
            "physical_execution_authorized": False,
        },
        "NEXT",
    )

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative
    )
    assert isinstance(publication, str)
    revision = publication or None
    raw = CLOSURE.read_bytes() if revision is None else source_bytes(
        ROOT, revision, relative
    )
    live = {
        **closure["live_gate_expectations"],
        "r24d64_zero_world_closure_raw_sha256": sha256(raw),
    }
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        live,
        revision=revision,
    )
    print(
        "QSDK_R24D64_GODOT_EXACT_NET_MOTOR_WORK_PROJECTION_ZERO_WORLD_"
        "QUALIFICATION_CLOSURE_PASS sources=81 checks=9/9 retained=9 "
        "positive=4 binary64=4 mutations=2/2 passthrough=3 r63_replay=1 "
        "models=0 worlds=0 steps=0 authorization_control_required=1 "
        "physics_authorized=0 sdk1=11/20"
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
            "QSDK_R24D64_GODOT_EXACT_NET_MOTOR_WORK_PROJECTION_ZERO_WORLD_"
            f"QUALIFICATION_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
