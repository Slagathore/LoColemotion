#!/usr/bin/env python3
"""Audit the compact R83 Godot/Jolt adapter-semantics closure."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    sha256,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d83_godot_jolt_adapter_semantics_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "c526130f0ef23be80d1dfe031385fa874ffd8d92"
STATUS = (
    "closed_complete_zero_world_adapter_semantics_qualified_physics_blocked_"
    "pending_distinct_route_successor"
)
PREDECESSOR_STATUS = (
    "closed_read_only_retained_trace_and_pinned_source_diagnosis_two_adapter_"
    "defects_physics_blocked"
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
INITIALIZER_SHA256 = (
    "sha256:ff5c33f3e9ba172057db950423f5f53a56ba1e17943d050cd6525b9e4fabf088"
)
PROJECTION_SHA256 = (
    "sha256:32fe327c5449758e6129589eb81d413e8f1dc936d2b5ae626c2e5d47a7c077b6"
)
READBACK_SHA256 = (
    "sha256:cd821787098a34fc5974c6a434e85519b63850c8dd4bfcde1c237334499dec8e"
)


def main() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d83_godot_jolt_adapter_semantics_"
                "zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D83",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Freeze R83 adapter semantics: project limits "
                "and collision groups"
            ),
            source_binding_names=(
                "contract",
                "source_audit",
                "shared_helper",
                "shared_controls",
                "native_world",
                "native_route",
                "qualification_runner",
                "zero_world_worker",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d83_godot_jolt_adapter_semantics_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d83_godot_jolt_adapter_semantics_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d83-godot-jolt-adapter-semantics-qualification-"
            ),
            expected_checks=CHECKS,
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
            ),
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D83_GODOT_JOLT_ADAPTER_SEMANTICS_SOURCE_PASS"
                ),
                "cargo_targeted_tests.log": (
                    "complete_active_recovery_population_has_transport_stable_"
                    "command_identity ... ok"
                ),
                "production_preflight.log": (
                    '"joint_projection_population_sha256": "' + PROJECTION_SHA256
                ),
            },
        )
    )

    verify_exact_paths(
        contract,
        {
            "status": (
                "prospective_adapter_semantics_complete_zero_world_"
                "qualification_required_physics_blocked"
            ),
            "question_class": "development",
            "physical_question_declared": False,
            "controlled_change.godot_construction_relative_joint_limit_projection_added": True,
            "controlled_change.all_eight_recovery_hinges_use_projection": True,
            "controlled_change.host_limits_projected_outward_to_binary32": True,
            "controlled_change.floor_robot_collision_groups_changed_to_disjoint_layers": True,
            "controlled_change.portable_recovery_controller_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "complete_zero_world_gate.current_worker_count": 1,
            "complete_zero_world_gate.historical_closure_audits_executed_count": 0,
            "complete_zero_world_gate.full_seeded_ghost_count": 0,
            "complete_zero_world_gate.bespoke_physical_canary_count": 0,
        },
        "CONTRACT",
    )
    verify_exact_paths(
        preflight,
        {
            "ok": True,
            "initializer_projection_sha256": INITIALIZER_SHA256,
            "joint_projection_population_sha256": PROJECTION_SHA256,
            "joint_property_readback_population_sha256": READBACK_SHA256,
            "joint_projection_count": 8,
            "exact_joint_property_readback_count": 8,
            "joint_mutation_rejection_count": 9,
            "collision_property_readback_count": 6,
            "collision_mutation_rejection_count": 3,
            "collision_property_readback.floor.layer": 1,
            "collision_property_readback.floor.mask": 2,
            "collision_property_readback.robot.layer": 2,
            "collision_property_readback.robot.mask": 1,
            "collision_property_readback.robot_floor_collision_enabled": True,
            "collision_property_readback.robot_robot_collision_enabled": False,
            "historical_closure_audits_executed_count": 0,
            "bespoke_physical_canary_count": 0,
            "full_seeded_ghost_count": 0,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
        },
        "PREFLIGHT",
    )
    verify_exact_paths(
        closure,
        {
            "qualification.check_count": len(CHECKS),
            "qualification.checks_passed": len(CHECKS),
            "qualification.source_manifest_entry_count": 58,
            "qualification.authored_source_path_count": 10,
            "qualification.unchanged_dependency_binding_count": 12,
            "qualification.joint_projection_count": 8,
            "qualification.exact_joint_property_readback_count": 8,
            "qualification.joint_mutation_rejection_count": 9,
            "qualification.collision_property_readback_count": 6,
            "qualification.collision_mutation_rejection_count": 3,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.bespoke_physical_canary_count": 0,
            "qualification.full_seeded_ghost_count": 0,
            "decision.result": "positive_zero_world_godot_adapter_semantics_qualified",
            "decision.portable_recovery_controller_changed": False,
            "decision.portable_recovery_evaluator_changed": False,
            "decision.behavior_threshold_changed": False,
            "decision.physical_execution_authorized": False,
            "decision.physical_attempted": False,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "next_boundary.gate_id": "QSDK-R24D84",
            "next_boundary.question_class": "development",
            "next_boundary.physical_question_declared": False,
            "next_boundary.smallest_coverage_adequate_route_ghost_required": True,
            "next_boundary.full_seeded_ghost_required": False,
            "next_boundary.additional_physical_canary_required": False,
            "next_boundary.physical_execution_authorized": False,
            "claim_boundary.integrated_production_world_constructed": False,
            "claim_boundary.solver_step_executed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
        },
        "CLOSURE",
    )
    exact(receipt["production_preflight"], preflight, "PREFLIGHT_BINDING")

    expected_live = {
        "next_gate_id": "QSDK-R24D84",
        "r24d83_source_status": STATUS,
        "r24d83_source_commit": SOURCE,
        "r24d83_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
        "r24d83_zero_world_closure_byte_length": CLOSURE.stat().st_size,
        "r24d83_zero_world_closure_raw_sha256": sha256(CLOSURE.read_bytes()),
        "r24d83_official_qualification_attempt_count": 1,
        "r24d83_source_inventory_count": 58,
        "r24d83_authored_source_path_count": 10,
        "r24d83_unchanged_dependency_binding_count": 12,
        "r24d83_joint_projection_count": 8,
        "r24d83_exact_joint_property_readback_count": 8,
        "r24d83_joint_mutation_rejection_count": 9,
        "r24d83_collision_property_readback_count": 6,
        "r24d83_collision_mutation_rejection_count": 3,
        "r24d83_historical_closure_audits_executed_count": 0,
        "r24d83_bespoke_physical_canary_count": 0,
        "r24d83_full_seeded_ghost_count": 0,
        "r24d83_model_construction_count": 0,
        "r24d83_world_attempt_count": 0,
        "r24d83_world_build_count": 0,
        "r24d83_solver_step_count": 0,
        "r24d83_zero_world_qualification_pending": False,
        "r24d83_zero_world_qualified": True,
        "r24d83_physical_execution_authorized": False,
        "physical_execution_blocked_until_r24d83_zero_world_qualification": False,
        "r24d84_distinct_successor_required": True,
        "r24d84_question_class": "development",
        "r24d84_physical_question_declared": False,
        "r24d84_smallest_coverage_adequate_route_ghost_required": True,
        "r24d84_full_seeded_ghost_required": False,
        "r24d84_additional_physical_canary_required": False,
        "r24d84_zero_world_gate_passed": False,
        "r24d84_physical_execution_authorized": False,
        "physical_execution_blocked_pending_r24d84_declaration": True,
    }
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d83_contract_path",
        expected=expected_live,
        prefix="LIVE_R83_CLOSURE",
    )
    print(
        "QSDK_R24D83_GODOT_JOLT_ADAPTER_SEMANTICS_ZERO_WORLD_CLOSURE_PASS "
        "sources=58 checks=9/9 joints=8 mutations=12 historical_audits=0 "
        "models=0 worlds=0 steps=0 next=R24D84 sdk1=11/20"
    )


if __name__ == "__main__":
    try:
        main()
    except ClosureAuditError as exc:
        print(f"QSDK_R24D83_CLOSURE_FAIL {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
