#!/usr/bin/env python3
"""Audit R98's retained zero-world qualification and behavior authorization."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import (  # noqa: E402
    r24d98_godot_jolt_nested_guarded_recovery_behavior as source_audit,
)
from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    load,
    require,
    sha256,
    source_bytes,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d98_godot_jolt_nested_guarded_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
CONTRACT = ROOT / (
    "sdk/recovery/r24d98_godot_jolt_nested_guarded_recovery_behavior_"
    "contract_v1.json"
)
R92_CLOSURE = ROOT / (
    "sdk/recovery/r24d92_godot_jolt_force_based_recovery_behavior_"
    "invalid_closure_v1.json"
)
SOURCE = "396e247a16e2e5090bf3f80e3bd39e98b28127d5"
LENGTH = 19900
DIGEST = "sha256:4f481afaa2b6d9c90271f7ad35ad29f152f7daf05df686ada864b85c65e8b365"
STATUS = (
    "closed_complete_zero_world_nested_guarded_recovery_behavior_qualified_"
    "one_finite_paired_development_attempt_authorized"
)
R97_STATUS = (
    "closed_valid_complete_applied_scale_recovery_production_route_ghost_"
    "passed_distinct_r24d98_behavior_successor_required"
)
R92_STATUS = (
    "closed_consumed_complete_producer_negative_invalid_for_physical_inference_"
    "native_angular_velocity_limit_assertions"
)
AUDIT_PATH = (
    "sdk/conformance/r24d98_godot_jolt_nested_guarded_recovery_behavior.py"
)


def audit() -> None:
    raw = CLOSURE.read_bytes().replace(b"\r\n", b"\n")
    exact((len(raw), sha256(raw)), (LENGTH, DIGEST), "CLOSURE_BLOB")
    closure, frozen_contract, _receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d98_godot_jolt_nested_guarded_recovery_"
                "behavior_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D98",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Declare R98 behavior: bind guarded "
                "prone-to-stand pair"
            ),
            source_binding_names=(
                "source_audit",
                "shared_helper",
                "shared_controls",
                "physical_runner",
                "shared_supervisor",
                "production_worker",
                "current_zero_world_worker",
                "qualification_runner",
            ),
            predecessor_status=R97_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d98_godot_jolt_nested_guarded_recovery_"
                "behavior_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d98_godot_jolt_nested_guarded_recovery_"
                "behavior_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d98-godot-jolt-nested-guarded-recovery-behavior-"
                "qualification-"
            ),
            expected_checks=(
                "core_dynamic_library_rebuilt",
                "core_targeted_tests_passed",
                "godot_adapter_binding_check_passed",
                "godot_adapter_debug_build_passed",
                "python_binding_smoke_passed",
                "versioning_conformance_passed",
                "source_contract_audit_passed",
                "production_preflight_passed",
                "worktree_unchanged",
            ),
            checkout_only_metadata=(
                {
                    "path": "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd",
                    "cause": (
                        "existing_windows_checkout_mixed_line_ending_"
                        "materialization"
                    ),
                    "git_attribute": "text eol=lf",
                    "git_ls_files_eol": "i/lf w/mixed attr/text eol=lf",
                },
                {
                    "path": "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
                    "cause": (
                        "existing_windows_checkout_mixed_line_ending_"
                        "materialization"
                    ),
                    "git_attribute": "text eol=lf",
                    "git_ls_files_eol": "i/lf w/mixed attr/text eol=lf",
                },
                {
                    "path": "sdk/python/test_ctypes_smoke.py",
                    "cause": (
                        "existing_windows_checkout_mixed_line_ending_"
                        "materialization"
                    ),
                    "git_attribute": "text eol=lf",
                    "git_ls_files_eol": "i/lf w/mixed attr/text eol=lf",
                },
                {
                    "path": (
                        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_"
                        "behavior.gd"
                    ),
                    "cause": (
                        "existing_windows_checkout_mixed_line_ending_"
                        "materialization"
                    ),
                    "git_attribute": "text eol=lf",
                    "git_ls_files_eol": "i/lf w/mixed attr/text eol=lf",
                },
            ),
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D98_GODOT_JOLT_NESTED_GUARDED_RECOVERY_"
                    "BEHAVIOR_SOURCE_PASS"
                ),
                "production_preflight.log": '"gate_id": "QSDK-R24D98"',
            },
            physical_question_declared=True,
        )
    )
    exact(frozen_contract, load(CONTRACT), "FROZEN_CONTRACT")

    behavior_predecessor = closure["behavior_predecessor"]
    verify_exact_paths(
        behavior_predecessor,
        {
            "gate_id": "QSDK-R24D92",
            "role": (
                "consumed_complete_producer_negative_invalid_for_behavioral_"
                "inference"
            ),
            "closure_path": R92_CLOSURE.relative_to(ROOT).as_posix(),
            "closure_commit": "cb1b510b09c97ef97d3cb14a949baa5e87817895",
            "closure_byte_length": 22402,
            "closure_raw_sha256": (
                "sha256:7ff62d7b7304f2a3d7836d74a080f2cd02ed806bc0c44fc8f"
                "9873d00b431f14a"
            ),
            "closure_status": R92_STATUS,
            "historical_result": R92_STATUS,
            "historical_closure_audit_reexecuted": False,
            "historical_result_rewritten": False,
            "historical_threshold_rewritten": False,
            "historical_selector_rewritten": False,
            "historical_evaluator_rewritten": False,
            "historical_interpretation_rewritten": False,
            "same_identity_rerun_permitted": False,
            "same_identity_requalification_permitted": False,
        },
        "R92_BEHAVIOR_PREDECESSOR",
    )
    r92_raw = R92_CLOSURE.read_bytes()
    exact(len(r92_raw), 22402, "R92_CLOSURE_LENGTH")
    exact(
        sha256(r92_raw),
        "sha256:7ff62d7b7304f2a3d7836d74a080f2cd02ed806bc0c44fc8f9873d00b431f14a",
        "R92_CLOSURE_DIGEST",
    )
    verify_exact_paths(
        load(R92_CLOSURE),
        {
            "gate_id": "QSDK-R24D92",
            "closure_status": R92_STATUS,
            "physical_attempt.attempt_count_for_exact_source_and_gate": 1,
            "physical_attempt.seed": 278151771,
            "physical_attempt.status": "valid_complete_behavior_development",
            "physical_attempt.scientific_outcome": "negative",
            "decision.closure_invalid_for_behavioral_inference": True,
            "decision.same_identity_rerun_permitted": False,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "R92_BEHAVIOR_CLOSURE",
    )

    verify_exact_paths(
        closure,
        {
            "qualification.official_zero_world_qualification_passed": True,
            "qualification.official_qualification_attempt_count_for_source": 1,
            "qualification.check_count": 9,
            "qualification.checks_passed": 9,
            "qualification.source_inventory_count": 64,
            "qualification.authored_source_path_count": 11,
            "qualification.qualified_physical_path_count": 48,
            "qualification.bound_predecessor_count": 2,
            "qualification.current_zero_world_worker_count": 1,
            "qualification.current_behavior_dispatch_positive_case_count": 4,
            "qualification.current_behavior_dispatch_forced_failure_case_count": 7,
            "qualification.production_worker_parse_count": 1,
            "qualification.forced_supervisor_failure_control_count": 1,
            "qualification.missing_physical_switch_refusal_count": 1,
            "qualification.r92_closure_audit_reexecution_count": 0,
            "qualification.r97_closure_audit_reexecution_count": 0,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.bespoke_physical_canary_count": 0,
            "qualification.full_seeded_ghost_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "publication_transition_projection.physical_semantics_changed_after_source_freeze": False,
            "publication_transition_projection.behavior_question_changed_after_source_freeze": False,
            "decision.r92_consumed_invalid_behavior_closure_bound": True,
            "decision.r97_valid_complete_route_closure_bound": True,
            "decision.r92_behavioral_inference_reused": False,
            "decision.exact_r92_behavior_question_reused": True,
            "decision.nested_guarded_behavior_dispatch_qualified": True,
            "decision.nested_guarded_behavior_receipt_validation_qualified": True,
            "decision.r97_route_ghost_coverage_accepted": True,
            "decision.physical_behavior_attempt_authorized": True,
            "decision.maximum_world_build_count": 2,
            "decision.maximum_outer_solver_steps": 2400,
            "decision.maximum_outer_solver_steps_per_arm": 1200,
            "decision.behavior_evaluator_invocation_count": 1,
            "decision.seed": 278151771,
            "decision.held_out": False,
            "decision.same_identity_rerun_permitted": False,
            "decision.physical_attempted": False,
            "decision.prone_to_standing_claimed": False,
            "claim_boundary.physical_execution_authorized": True,
            "claim_boundary.new_physical_observation_made": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
        },
        "CLOSURE",
    )
    verify_exact_paths(
        preflight,
        {
            "actuator_mode": "force_based_nested_native_angular_velocity_guarded_v1",
            "source_inventory_count": 64,
            "authored_source_path_count": 11,
            "qualified_physical_path_count": 48,
            "bound_predecessor_count": 2,
            "current_zero_world_worker_count": 1,
            "current_behavior_dispatch_positive_case_count": 4,
            "current_behavior_dispatch_forced_failure_case_count": 7,
            "production_worker_parse_count": 1,
            "forced_supervisor_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "r92_closure_audit_reexecution_count": 0,
            "r97_closure_audit_reexecution_count": 0,
            "historical_closure_audits_executed_count": 0,
            "bespoke_physical_canary_count": 0,
            "full_seeded_ghost_count": 0,
            "current_behavior_dispatch_worker_receipt.positive_case_count": 4,
            "current_behavior_dispatch_worker_receipt.forced_failure_case_count": 7,
            "current_behavior_dispatch_worker_receipt.production_validation_seam_invoked": True,
            "current_behavior_dispatch_worker_receipt.nested_mapping_selection_verified": True,
            "current_behavior_dispatch_worker_receipt.nested_active_positive_count": 1,
            "current_behavior_dispatch_worker_receipt.nested_no_actuation_positive_count": 1,
            "current_behavior_dispatch_worker_receipt.legacy_compatibility_positive_count": 2,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
        },
        "PREFLIGHT",
    )

    live_contract, live_counts, published = source_audit.validate_sources()
    exact(live_contract, frozen_contract, "POSTPUBLICATION_FROZEN_CONTRACT")
    exact(published, True, "POSTPUBLICATION_PHASE")
    exact(
        live_counts,
        {
            "source_inventory_count": 64,
            "authored_source_path_count": 11,
            "qualified_physical_path_count": 48,
            "bound_predecessor_count": 2,
            "current_zero_world_worker_count": 1,
            "production_worker_parse_count": 1,
            "historical_closure_audits_executed_count": 0,
            "full_seeded_ghost_count": 0,
            "bespoke_physical_canary_count": 0,
        },
        "POSTPUBLICATION_COUNTS",
    )
    frozen_audit = source_bytes(ROOT, SOURCE, AUDIT_PATH).decode("utf-8")
    require("if published:" in frozen_audit, "FROZEN_PHASE_BRANCH")
    require(
        '"r24d98_zero_world_qualification_pending": False' in frozen_audit,
        "FROZEN_POSTPUBLICATION_PENDING",
    )
    physical_closed = (
        ROOT
        / "sdk/recovery/r24d98_godot_jolt_nested_guarded_recovery_behavior_"
        "invalid_closure_v1.json"
    ).is_file()
    live_expected = {
        "r24d98_source_commit": SOURCE,
        "r24d98_source_status": (
            "closed_consumed_invalid_incomplete_nested_guarded_recovery_"
            "behavior_no_feasible_parent_scale_r99_required"
            if physical_closed
            else STATUS
        ),
        "r24d98_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
        "r24d98_zero_world_closure_byte_length": LENGTH,
        "r24d98_zero_world_closure_raw_sha256": DIGEST,
        "r24d98_official_qualification_attempt_count": 1,
        "r24d98_zero_world_qualification_pending": False,
        "r24d98_zero_world_qualified": True,
        "r24d98_publication_transition_qualified": True,
        "r24d98_qualification_model_construction_count": 0,
        "r24d98_qualification_world_build_count": 0,
        "r24d98_qualification_solver_step_count": 0,
        "r24d98_physical_execution_authorized": not physical_closed,
        "r24d98_authorized_world_count": 0 if physical_closed else 2,
        "r24d98_maximum_outer_solver_steps": 0 if physical_closed else 2400,
        "r24d98_physical_attempt_consumed": physical_closed,
        "r24d98_sdk1_milestone_advanced": False,
        "physical_execution_blocked_until_r24d98_zero_world_qualification": False,
    }
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d98_contract_path",
        expected=live_expected,
        prefix="LIVE_R98_CLOSURE",
    )


def test_r24d98_zero_world_qualification_closure() -> None:
    audit()


if __name__ == "__main__":
    audit()
    print("QSDK_R24D98_ZERO_WORLD_QUALIFICATION_CLOSURE_PASS")
