#!/usr/bin/env python3
"""Audit the R88 zero-world qualification through reusable closure mechanics."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    load,
    sha256,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d88_godot_force_based_recovery_production_route_"
    "zero_world_qualification_closure_v1.json"
)
CONTRACT = ROOT / (
    "sdk/recovery/r24d88_godot_force_based_recovery_production_route_"
    "contract_v1.json"
)
SOURCE = "d7bc3fb122423731fb0efb6a9b74701408d9f1aa"
LENGTH = 16639
DIGEST = "sha256:391cbfe09da219cae24f68a64c748703b81cf7a1034e6201f5ee33ec280647be"
STATUS = (
    "closed_complete_zero_world_force_based_recovery_production_route_"
    "qualified_one_two_step_development_ghost_authorized"
)


def audit() -> None:
    raw = CLOSURE.read_bytes().replace(b"\r\n", b"\n")
    exact((len(raw), sha256(raw)), (LENGTH, DIGEST), "CLOSURE_BLOB")
    closure, frozen_contract, _receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d88_godot_force_based_recovery_"
                "production_route_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D88",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Declare R88 route ghost: bind force-based "
                "two-step path"
            ),
            source_binding_names=(
                "source_audit",
                "shared_helper",
                "shared_controls",
                "physical_runner",
                "shared_supervisor",
                "production_worker",
                "qualification_runner",
            ),
            predecessor_status=(
                "closed_complete_zero_world_force_based_recovery_actuator_"
                "mapping_qualified_physics_blocked"
            ),
            attempt_schema=(
                "sporespore_qsdk_r24d88_godot_force_based_recovery_"
                "production_route_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d88_godot_force_based_recovery_"
                "production_route_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d88-godot-force-based-recovery-production-route-"
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
                    "path": "sdk/python/test_ctypes_smoke.py",
                    "cause": (
                        "existing_windows_checkout_mixed_line_ending_materialization"
                    ),
                    "git_attribute": "text eol=lf",
                },
                {
                    "path": (
                        "tests/test_sdk_qsdk_r24d57_godot_native_"
                        "recovery_route_ghost.gd"
                    ),
                    "cause": "windows_checkout_crlf_materialization",
                    "git_attribute": "text eol=lf",
                },
            ),
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D88_GODOT_FORCE_BASED_RECOVERY_PRODUCTION_"
                    "ROUTE_SOURCE_PASS"
                ),
                "production_preflight.log": '"gate_id": "QSDK-R24D88"',
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
            "qualification.source_inventory_count": 63,
            "qualification.qualified_physical_path_count": 47,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.bespoke_physical_canary_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "decision.physical_ghost_authorized": True,
            "decision.maximum_world_build_count": 1,
            "decision.maximum_outer_solver_steps": 2,
            "decision.physics_ticks_per_second": 120,
            "decision.outer_step_duration_s": 1.0 / 120.0,
            "decision.seed": 362738678,
            "decision.held_out": False,
            "decision.same_identity_rerun_permitted": False,
            "decision.physical_attempted": False,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "claim_boundary.physical_execution_authorized": True,
            "claim_boundary.new_physical_observation_made": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
        },
        "CLOSURE",
    )
    verify_exact_paths(
        preflight,
        {
            "actuator_mode": "force_based_joint_impulse_v1",
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
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d88_contract_path",
        expected={
            "r24d88_source_commit": SOURCE,
            "r24d88_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
            "r24d88_zero_world_closure_byte_length": LENGTH,
            "r24d88_zero_world_closure_raw_sha256": DIGEST,
            "r24d88_official_qualification_attempt_count": 1,
            "r24d88_zero_world_qualified": True,
            "r24d88_sdk1_milestone_advanced": False,
        },
        prefix="LIVE_R88_CLOSURE",
    )


def test_r24d88_zero_world_qualification_closure() -> None:
    audit()


if __name__ == "__main__":
    audit()
    print("QSDK_R24D88_ZERO_WORLD_QUALIFICATION_CLOSURE_PASS")
