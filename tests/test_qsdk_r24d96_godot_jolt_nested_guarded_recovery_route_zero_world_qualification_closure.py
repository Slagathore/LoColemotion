#!/usr/bin/env python3
"""Audit R96's retained zero-world qualification and finite authorization."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import (  # noqa: E402
    r24d96_godot_jolt_nested_guarded_recovery_route as source_audit,
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
    "sdk/recovery/r24d96_godot_jolt_nested_guarded_recovery_route_"
    "zero_world_qualification_closure_v1.json"
)
CONTRACT = ROOT / (
    "sdk/recovery/r24d96_godot_jolt_nested_guarded_recovery_route_contract_v1.json"
)
SOURCE = "7160d9fb53e882189eca7f8df770ebb3b2170424"
LENGTH = 18014
DIGEST = "sha256:3348235c55c98c9d05f391c03168c113fc0c3cd777a2a09d295bdf68ec700ec9"
STATUS = (
    "closed_complete_zero_world_nested_guarded_recovery_route_qualified_"
    "one_two_step_development_ghost_authorized"
)
PREDECESSOR_STATUS = (
    "closed_consumed_invalid_incomplete_guarded_route_ghost_immediate_native_"
    "readback_exceeded_inner_guard_r96_required"
)
AUDIT_PATH = "sdk/conformance/r24d96_godot_jolt_nested_guarded_recovery_route.py"


def audit() -> None:
    raw = CLOSURE.read_bytes().replace(b"\r\n", b"\n")
    exact((len(raw), sha256(raw)), (LENGTH, DIGEST), "CLOSURE_BLOB")
    closure, frozen_contract, _receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d96_godot_jolt_nested_guarded_recovery_"
                "route_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D96",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/core] Declare R96 route: separate projection target"
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
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d96_godot_jolt_nested_guarded_route_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d96_godot_jolt_nested_guarded_route_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d96-godot-jolt-nested-guarded-route-qualification-"
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
                    "path": "sdk/python/test_ctypes_smoke.py",
                    "cause": "existing_windows_checkout_mixed_line_ending_materialization",
                    "git_attribute": "text eol=lf",
                    "git_ls_files_eol": "i/lf w/mixed attr/text eol=lf",
                },
                {
                    "path": (
                        "tests/test_sdk_godot_jolt_nested_native_angular_"
                        "velocity_guard_zero_world.gd"
                    ),
                    "cause": "windows_checkout_crlf_materialization",
                    "git_attribute": "text eol=lf",
                    "git_ls_files_eol": "i/lf w/crlf attr/text eol=lf",
                },
                {
                    "path": (
                        "tests/test_sdk_qsdk_r24d57_godot_native_recovery_"
                        "route_ghost.gd"
                    ),
                    "cause": "windows_checkout_mixed_line_ending_materialization",
                    "git_attribute": "text eol=lf",
                    "git_ls_files_eol": "i/lf w/mixed attr/text eol=lf",
                },
            ),
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D96_GODOT_JOLT_NESTED_GUARDED_ROUTE_SOURCE_PASS"
                ),
                "production_preflight.log": '"gate_id": "QSDK-R24D96"',
            },
            physical_question_declared=True,
        )
    )
    exact(frozen_contract, load(CONTRACT), "FROZEN_CONTRACT")
    verify_exact_paths(
        closure,
        {
            "qualification.official_zero_world_qualification_passed": True,
            "qualification.official_qualification_attempt_count_for_source": 1,
            "qualification.check_count": 9,
            "qualification.checks_passed": 9,
            "qualification.source_inventory_count": 64,
            "qualification.authored_source_path_count": 14,
            "qualification.qualified_physical_path_count": 47,
            "qualification.current_zero_world_worker_count": 1,
            "qualification.current_nested_guard_positive_case_count": 5,
            "qualification.current_nested_guard_forced_failure_case_count": 7,
            "qualification.r94_predecessor_regression_execution_count": 1,
            "qualification.r95_closure_audit_reexecution_count": 0,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.bespoke_physical_canary_count": 0,
            "qualification.full_seeded_ghost_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "publication_transition_projection.outer_guard_changed": False,
            "publication_transition_projection.physical_semantics_changed_after_source_freeze": False,
            "decision.r95_consumed_physical_closure_bound": True,
            "decision.nested_guard_worker_qualified": True,
            "decision.r94_predecessor_regression_passed": True,
            "decision.inner_projection_target_source_derived": True,
            "decision.outer_native_readback_guard_unchanged": True,
            "decision.physical_ghost_authorized": True,
            "decision.maximum_world_build_count": 1,
            "decision.maximum_outer_solver_steps": 2,
            "decision.seed": 312063631,
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
            "authored_source_path_count": 14,
            "qualified_physical_path_count": 47,
            "current_zero_world_worker_count": 1,
            "current_nested_guard_positive_case_count": 5,
            "current_nested_guard_forced_failure_case_count": 7,
            "production_worker_parse_count": 1,
            "forced_supervisor_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "r95_closure_audit_reexecution_count": 0,
            "historical_closure_audits_executed_count": 0,
            "bespoke_physical_canary_count": 0,
            "full_seeded_ghost_count": 0,
            "current_nested_guard_worker_receipt.predecessor_regression_passed": True,
            "current_nested_guard_worker_receipt.outer_guard_limit_rad_s": 47.11813735961914,
            "current_nested_guard_worker_receipt.projection_target_limit_rad_s": 47.11238479614258,
            "current_nested_guard_worker_receipt.r24d95_observation_selected_margin": False,
            "physics_state_modified": False,
            "physical_question_opened": False,
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
            "authored_source_path_count": 14,
            "qualified_physical_path_count": 47,
            "bound_predecessor_count": 1,
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
        '"r24d96_zero_world_qualification_pending": False' in frozen_audit,
        "FROZEN_POSTPUBLICATION_PENDING",
    )
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d96_contract_path",
        expected={
            "r24d96_source_commit": SOURCE,
            "r24d96_source_status": STATUS,
            "r24d96_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
            "r24d96_zero_world_closure_byte_length": LENGTH,
            "r24d96_zero_world_closure_raw_sha256": DIGEST,
            "r24d96_official_qualification_attempt_count": 1,
            "r24d96_zero_world_qualification_pending": False,
            "r24d96_zero_world_qualified": True,
            "r24d96_physical_execution_authorized": True,
            "r24d96_sdk1_milestone_advanced": False,
            "physical_execution_blocked_until_r24d96_zero_world_qualification": False,
        },
        prefix="LIVE_R96_CLOSURE",
    )


def test_r24d96_zero_world_qualification_closure() -> None:
    audit()


if __name__ == "__main__":
    audit()
    print("QSDK_R24D96_ZERO_WORLD_QUALIFICATION_CLOSURE_PASS")
