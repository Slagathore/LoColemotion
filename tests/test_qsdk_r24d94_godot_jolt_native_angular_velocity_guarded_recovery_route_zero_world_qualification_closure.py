#!/usr/bin/env python3
"""Audit R94's positive qualification and publication-state authorization limit."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

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
    "sdk/recovery/r24d94_godot_jolt_native_angular_velocity_guarded_"
    "recovery_route_zero_world_qualification_closure_v1.json"
)
CONTRACT = ROOT / (
    "sdk/recovery/r24d94_godot_jolt_native_angular_velocity_guarded_"
    "recovery_route_contract_v1.json"
)
SOURCE = "b527003132f1da4c42c773377e9b1bf3a0308b95"
LENGTH = 17538
DIGEST = "sha256:0d09e97d34a3f8601f7a7f8a07e41b23d14de97eda45948c73667cffe1e84552"
STATUS = (
    "closed_complete_zero_world_guarded_recovery_route_qualification_passed_"
    "publication_state_audit_not_reusable_no_physics_authorized_r95_required"
)
PREDECESSOR_STATUS = (
    "closed_complete_zero_world_native_engine_health_qualification_passed_no_"
    "physical_question_r24d94_required"
)
AUDIT_PATH = (
    "sdk/conformance/r24d94_godot_jolt_native_angular_velocity_guarded_"
    "recovery_route.py"
)


def audit() -> None:
    raw = CLOSURE.read_bytes().replace(b"\r\n", b"\n")
    exact((len(raw), sha256(raw)), (LENGTH, DIGEST), "CLOSURE_BLOB")
    closure, frozen_contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d94_godot_jolt_native_angular_velocity_"
                "guarded_recovery_route_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D94",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Declare R94 route: bind guarded production path"
            ),
            source_binding_names=(
                "source_audit",
                "shared_helper",
                "shared_controls",
                "physical_runner",
                "shared_supervisor",
                "production_worker",
                "native_zero_world_worker",
                "qualification_runner",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d94_godot_jolt_guarded_recovery_route_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d94_godot_jolt_guarded_recovery_route_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d94-godot-jolt-guarded-recovery-route-qualification-"
            ),
            expected_checks=(
                "core_dynamic_library_rebuilt",
                "core_targeted_tests_passed",
                "godot_adapter_binding_check_passed",
                "godot_adapter_debug_build_passed",
                "godot_production_worker_parse_passed",
                "native_zero_world_gate_passed",
                "python_binding_smoke_passed",
                "versioning_conformance_passed",
                "source_contract_audit_passed",
                "production_preflight_passed",
                "worktree_unchanged",
            ),
            checkout_only_metadata=(
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
                    "QSDK_R24D94_GODOT_JOLT_GUARDED_RECOVERY_ROUTE_SOURCE_PASS"
                ),
                "native_zero_world.log": (
                    "SPORESPORE_GODOT_JOLT_NATIVE_ANGULAR_VELOCITY_GUARD_"
                    "ZERO_WORLD "
                ),
                "production_preflight.log": '"gate_id": "QSDK-R24D94"',
            },
            physical_question_declared=True,
        )
    )
    exact(frozen_contract, load(CONTRACT), "FROZEN_CONTRACT")
    verify_exact_paths(
        closure,
        {
            "source.source_freeze_commit": SOURCE,
            "qualification.official_zero_world_qualification_passed": True,
            "qualification.official_qualification_attempt_count_for_source": 1,
            "qualification.check_count": 11,
            "qualification.checks_passed": 11,
            "qualification.source_inventory_count": 64,
            "qualification.authored_source_path_count": 16,
            "qualification.qualified_physical_path_count": 47,
            "qualification.current_zero_world_worker_count": 1,
            "qualification.native_guard_positive_case_count": 5,
            "qualification.native_guard_forced_failure_case_count": 13,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.bespoke_physical_canary_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "guard_qualification_projection.guard_limit_rad_s": 47.11813735961914,
            "guard_qualification_projection.positive_case_count": 5,
            "guard_qualification_projection.forced_failure_case_count": 13,
            "decision.guard_mapping_zero_world_qualified": True,
            "decision.physical_ghost_authorized": False,
            "decision.publication_transition_reusable": False,
            "decision.maximum_world_build_count": 0,
            "decision.maximum_outer_solver_steps": 0,
            "decision.physical_attempted": False,
            "decision.distinct_r95_successor_required": True,
            "claim_boundary.physical_execution_authorized": False,
            "claim_boundary.new_physical_observation_made": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
            "post_qualification_publication_state_diagnosis.physical_invocation_count": 0,
            "post_qualification_publication_state_diagnosis.future_physical_preflight_would_reject_honest_published_state": True,
            "post_qualification_publication_state_diagnosis.source_reusable_for_physical_authorization": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
        },
        "CLOSURE",
    )
    verify_exact_paths(
        preflight,
        {
            "actuator_mode": "force_based_native_angular_velocity_guarded_v1",
            "source_inventory_count": 64,
            "authored_source_path_count": 16,
            "qualified_physical_path_count": 47,
            "current_zero_world_worker_count": 1,
            "native_guard_positive_case_count": 5,
            "native_guard_forced_failure_case_count": 13,
            "production_worker_parse_count": 1,
            "forced_supervisor_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "historical_closure_audits_executed_count": 0,
            "bespoke_physical_canary_count": 0,
            "full_seeded_ghost_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
        },
        "PREFLIGHT",
    )
    verify_exact_paths(
        receipt["native_zero_world"],
        {
            "ok": True,
            "positive_case_count": 5,
            "forced_failure_case_count": 13,
            "ordinary_full_scale_passed": True,
            "saturation_guard_engaged": True,
            "above_guard_braking_path_passed": True,
            "guarded_mapping_and_centered_work_passed": True,
            "immediate_native_readback_receipt_passed": True,
            "equal_and_opposite_pairing_preserved": True,
            "model_construction_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
        },
        "NATIVE_ZERO_WORLD",
    )

    frozen_audit = source_bytes(ROOT, SOURCE, AUDIT_PATH).decode("utf-8")
    require(
        '"r24d94_zero_world_qualification_pending": True' in frozen_audit,
        "FROZEN_PENDING_ASSERTION",
    )
    require(
        '"r24d94_zero_world_qualified": False' in frozen_audit,
        "FROZEN_QUALIFIED_ASSERTION",
    )
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d94_contract_path",
        expected={
            "r24d94_source_commit": SOURCE,
            "r24d94_source_status": STATUS,
            "r24d94_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
            "r24d94_zero_world_closure_byte_length": LENGTH,
            "r24d94_zero_world_closure_raw_sha256": DIGEST,
            "r24d94_official_qualification_attempt_count": 1,
            "r24d94_zero_world_qualification_pending": False,
            "r24d94_zero_world_qualified": True,
            "r24d94_publication_state_audit_reusable": False,
            "r24d94_physical_execution_authorized": False,
            "r24d94_sdk1_milestone_advanced": False,
            "r24d95_distinct_successor_required": True,
        },
        prefix="LIVE_R94_CLOSURE",
    )


def test_r24d94_zero_world_qualification_closure() -> None:
    audit()


if __name__ == "__main__":
    audit()
    print("QSDK_R24D94_ZERO_WORLD_QUALIFICATION_CLOSURE_PASS")
