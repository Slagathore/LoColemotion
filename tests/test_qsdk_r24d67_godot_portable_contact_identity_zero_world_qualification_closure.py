"""Compact audit of the retained zero-world R24D67 qualification closure."""

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
    "sdk/recovery/r24d67_godot_portable_contact_identity_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "728f67eade350dfdba684861f3f28583f9c64c0e"
STATUS = (
    "closed_complete_zero_world_portable_contact_identity_qualified_"
    "published_closure_control_required_physics_blocked"
)
PREDECESSOR_STATUS = (
    "closed_consumed_invalid_candidate_step_81_engine_contact_identity_"
    "validation_refusal"
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
    "r66_invalid_result_preserved",
    "r66_same_identity_not_rerun",
    "r66_same_identity_not_requalified",
    "lossless_utf8_hex_projection_implemented",
    "raw_to_portable_diagnostics_retained",
    "exact_r66_raw_identity_refusal_reproduced",
    "projected_identity_accepted_by_unchanged_core_validator",
    "collision_tricky_identities_separated",
    "non_ascii_utf8_identity_encoded_exactly",
    "invalid_identity_inputs_refused",
    "portable_core_identity_grammar_unchanged",
    "controller_unchanged",
    "evaluator_unchanged",
    "native_physics_unchanged",
    "behavior_worker_unchanged",
    "zero_world_successor_qualified",
    "current_r65_and_r66_controls_passed",
    "supervisor_forced_failure_preserved",
    "missing_physical_switch_refusal_proven",
    "source_population_content_addressed",
    "retained_evidence_tree_content_addressed",
    "published_closure_control_required",
    "physical_execution_blocked_until_published_closure_control",
)
DECISION_FALSE = (
    "published_closure_control_executed",
    "physical_pair_authorized",
    "physical_attempted",
    "native_world_constructed",
    "solver_step_executed",
    "native_runtime_observation_collection_executed",
    "controller_behavior_evaluated",
    "valid_godot_behavior_result_observed",
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
                "sporespore_qsdk_r24d67_godot_portable_contact_identity_"
                "zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D67",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Freeze R67: portable contact identities"
            ),
            source_binding_names=(
                "source_audit",
                "shared_controls",
                "native_world",
                "native_route",
                "core_protocol",
                "shared_qualifier",
                "shared_supervisor",
                "physical_binding",
                "zero_world_binding",
                "zero_world_worker",
                "behavior_worker",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d67_godot_portable_contact_identity_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d67_godot_portable_contact_identity_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d67-godot-portable-contact-identity-qualification-"
            ),
            expected_checks=CHECKS,
            checkout_only_metadata=(),
            physical_question_declared=True,
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D67_GODOT_PORTABLE_CONTACT_IDENTITY_SOURCE_PASS"
                ),
                "cargo_targeted_tests.log": "test result: ok. 1 passed; 0 failed",
                "production_preflight.log": (
                    '"schema_version":"sporespore_qsdk_r24d67_godot_'
                    'portable_contact_identity_preflight_v1"'
                ),
                "versioning_conformance.log": "Ran 1 test",
            },
        )
    )

    exact(
        (
            closure["predecessor"]["source_commit"],
            closure["predecessor"]["closure_commit"],
        ),
        (
            "c194a73b9a9df3316c05f160567738d7f4291ca2",
            "4a45ed7dd9b1f569031292cf5bb139def3150a4d",
        ),
        "PREDECESSOR_COMMITS",
    )
    verify_exact_paths(
        contract,
        {
            "gate_id": "QSDK-R24D67",
            "question_class": "development",
            "physical_question_declared": True,
            "finite_development_population.cell_count": 1,
            "finite_development_population.world_count": 2,
            "finite_development_population.arm_count": 2,
            "finite_development_population.cell_seed": 1497255095,
            "finite_development_population.maximum_outer_steps_per_arm": 1200,
            "finite_development_population.maximum_total_outer_steps": 2400,
            "finite_development_population.same_source_attempt_limit": 1,
            "finite_development_population.held_out": False,
            "threshold_and_margin_provenance.profile_sha256": (
                "sha256:3081621eb53f4d67bc1d8dc0f3a7d3ad7ae5ed829f902bce60b01ba1530bfb34"
            ),
            "threshold_and_margin_provenance.quaternion_norm_squared_tolerance": 1e-9,
            "threshold_and_margin_provenance.threshold_change_count": 0,
            "threshold_and_margin_provenance.margin_change_count": 0,
            "controlled_change.native_observation_mapping_changed": True,
            "controlled_change.contact_identity_projection_changed": True,
            "controlled_change.lossless_utf8_hex_projection_added": True,
            "controlled_change.raw_to_portable_diagnostics_added": True,
            "controlled_change.collision_refusal_added": True,
            "controlled_change.controller_changed": False,
            "controlled_change.evaluator_changed": False,
            "controlled_change.native_physics_or_jolt_patch_changed": False,
            "controlled_change.behavior_worker_changed": False,
            "contact_identity_projection_contract.method_id": (
                "godot_utf8_hex_portable_contact_identity_v1"
            ),
            "contact_identity_projection_contract.observed_raw_identity": (
                "rear_left_distal:0|floor:0"
            ),
            "contact_identity_projection_contract.observed_portable_identity": (
                "godot_contact_726561725f6c6566745f64697374616c3a307c666c6f6f723a30"
            ),
            "contact_identity_projection_contract.hash_or_truncation_used": False,
            "contact_identity_projection_contract.raw_to_portable_pairs_retained": True,
            "contact_identity_projection_contract.portable_collision_checked_and_refused": True,
            "critical_path_audit_policy.current_zero_world_worker_count": 3,
            "critical_path_audit_policy.historical_closure_audits_executed_count": 0,
            "critical_path_audit_policy.scheduled_historical_regression_cadence_replaced_or_waived": False,
            "ghost_and_canary_adequacy.additional_physical_route_ghost_required": False,
            "ghost_and_canary_adequacy.full_seeded_physical_ghost_required": False,
            "complete_zero_world_gate.official_qualification_run_count": 1,
            "complete_zero_world_gate.r67_observed_projection_exact_count": 1,
            "complete_zero_world_gate.r67_raw_core_refusal_count": 1,
            "complete_zero_world_gate.r67_projected_core_acceptance_count": 1,
            "complete_zero_world_gate.r67_mutation_rejection_count": 3,
            "physical_authorization_projection.maximum_model_construction_count": 2,
            "physical_authorization_projection.maximum_world_build_count": 2,
            "physical_authorization_projection.maximum_outer_solver_steps": 2400,
            "physical_authorization_projection.physical_execution_authorized": False,
            "next_boundary.maximum_physical_steps_authorized": 0,
        },
        "CONTRACT",
    )
    exact(len(contract["source_inventory"]), 108, "SOURCE_COUNT")

    verify_exact_paths(
        preflight,
        {
            "schema_version": (
                "sporespore_qsdk_r24d67_godot_portable_contact_identity_"
                "preflight_v1"
            ),
            "runtime_id": (
                "sporespore_qsdk_r24d67_godot_portable_contact_identity_v1"
            ),
            "runtime_version": "godot_4_7_jolt_instrumented_v2_exact_binary_pair",
            "source_inventory_count": 108,
            "bound_predecessor_count": 1,
            "current_zero_world_worker_count": 3,
            "historical_closure_audits_executed_count": 0,
            "r65_positive_control_count": 4,
            "r65_mutation_rejection_count": 4,
            "r66_quaternion_projection_case_count": 4,
            "r67_observed_projection_exact_count": 1,
            "r67_empty_bucket_projection_control_count": 1,
            "r67_collision_tricky_control_count": 1,
            "r67_non_ascii_utf8_projection_control_count": 1,
            "r67_mutation_rejection_count": 3,
            "r67_portable_contact_identity_receipt.raw_core_refusal_count": 1,
            "r67_portable_contact_identity_receipt.projected_core_acceptance_count": 1,
            "r67_portable_contact_identity_receipt.utf8_projection.raw_engine_contact_id": (
                "shape_µ:0|floor:0"
            ),
            "supervisor_forced_failure_control_count": 1,
            "supervisor_projection_receipt.status": "forced_failure_projection_control",
            "missing_physical_switch_refusal_count": 1,
            "additional_physical_route_ghost_required": False,
            "full_seeded_physical_ghost_required": False,
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
            qualification["current_zero_world_worker_count"],
            qualification["historical_closure_audits_executed_count"],
            qualification["r67_observed_projection_exact_count"],
            qualification["r67_mutation_rejection_count"],
            receipt["held_out_cell_access_count"],
        ),
        (9, 9, 108, 9, 3, 0, 1, 3, 0),
        "QUALIFICATION_COUNTS",
    )

    exact(
        closure["physical_authorization"],
        {
            "schema_version": "sporespore_qsdk_physical_route_authorization_projection_v1",
            "gate_id": "QSDK-R24D67",
            "question_class": "development",
            "zero_world_qualification_passed": True,
            "source_freeze_commit": SOURCE,
            "seed": 1497255095,
            "seed_label": "QSDK-R24D67/development/godot/exact-nominal-paired-v1",
            "seed_sha256": (
                "sha256:593e4cb7b7560788af8cb8601369267df40509260feeed86e63c024729a30aa5"
            ),
            "held_out": False,
            "maximum_model_construction_attempt_count": 2,
            "maximum_model_construction_count": 2,
            "maximum_world_attempt_count": 2,
            "maximum_world_build_count": 2,
            "maximum_outer_solver_steps": 2400,
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
            "result": "positive_zero_world_portable_contact_identity_qualified",
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
            "gate_id": "QSDK-R24D67",
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
        "r24d67_zero_world_closure_raw_sha256": sha256(raw),
    }
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        live,
        revision=revision,
    )
    print(
        "QSDK_R24D67_GODOT_PORTABLE_CONTACT_IDENTITY_ZERO_WORLD_"
        "QUALIFICATION_CLOSURE_PASS sources=108 checks=9/9 retained=9 "
        "workers=3 historical_audits=0 projected=1 raw_refusal=1 "
        "mutations=3 models=0 worlds=0 steps=0 "
        "authorization_control_required=1 physics_authorized=0 sdk1=11/20"
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
            "QSDK_R24D67_GODOT_PORTABLE_CONTACT_IDENTITY_ZERO_WORLD_"
            f"QUALIFICATION_CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
