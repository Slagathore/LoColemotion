#!/usr/bin/env python3
"""Audit R97's retained zero-world qualification and finite authorization."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import (  # noqa: E402
    r24d97_godot_jolt_applied_scale_route as source_audit,
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
    "sdk/recovery/r24d97_godot_jolt_applied_scale_route_"
    "zero_world_qualification_closure_v1.json"
)
CONTRACT = ROOT / "sdk/recovery/r24d97_godot_jolt_applied_scale_route_contract_v1.json"
SOURCE = "80e4fa06226ff7d16b58997686ef7f9139de4fe6"
LENGTH = 18889
DIGEST = "sha256:f3210bb7dbe3793fa83f5d92f898695756107626f4f3ead2ff34708281ef1a72"
STATUS = (
    "closed_complete_zero_world_applied_scale_route_qualified_"
    "one_two_step_development_ghost_authorized"
)
PREDECESSOR_STATUS = (
    "closed_consumed_invalid_incomplete_nested_guarded_route_ghost_missing_"
    "applied_scale_key_r97_required"
)
AUDIT_PATH = "sdk/conformance/r24d97_godot_jolt_applied_scale_route.py"


def audit() -> None:
    raw = CLOSURE.read_bytes().replace(b"\r\n", b"\n")
    exact((len(raw), sha256(raw)), (LENGTH, DIGEST), "CLOSURE_BLOB")
    closure, frozen_contract, _receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d97_godot_jolt_applied_scale_route_"
                "zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D97",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/core] Fix R97 qualification: bind shared runner API"
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
                "sporespore_qsdk_r24d97_godot_jolt_applied_scale_route_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d97_godot_jolt_applied_scale_route_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d97-godot-jolt-applied-scale-route-qualification-"
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
                    "path": (
                        "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
                    ),
                    "cause": (
                        "existing_windows_checkout_mixed_line_ending_"
                        "materialization"
                    ),
                    "git_attribute": "text eol=lf",
                    "git_ls_files_eol": "i/lf w/mixed attr/text eol=lf",
                },
                {
                    "path": (
                        "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
                    ),
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
                        "tests/test_sdk_godot_guarded_applied_scale_route_"
                        "zero_world.gd"
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
                    "QSDK_R24D97_GODOT_JOLT_APPLIED_SCALE_ROUTE_SOURCE_PASS"
                ),
                "production_preflight.log": '"gate_id": "QSDK-R24D97"',
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
            "qualification.authored_source_path_count": 12,
            "qualification.qualified_physical_path_count": 47,
            "qualification.current_zero_world_worker_count": 1,
            "qualification.current_applied_scale_positive_case_count": 2,
            "qualification.current_applied_scale_forced_failure_case_count": 4,
            "qualification.r96_predecessor_regression_execution_count": 1,
            "qualification.r96_closure_audit_reexecution_count": 0,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.bespoke_physical_canary_count": 0,
            "qualification.full_seeded_ghost_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "publication_transition_projection.guard_or_projection_target_changed": False,
            "publication_transition_projection.physical_semantics_changed_after_source_freeze": False,
            "decision.r96_consumed_physical_closure_bound": True,
            "decision.shared_applied_scale_resolver_qualified": True,
            "decision.legacy_scale_path_qualified": True,
            "decision.nested_scale_path_qualified": True,
            "decision.r96_predecessor_regression_passed": True,
            "decision.guard_or_projection_target_changed": False,
            "decision.physical_ghost_authorized": True,
            "decision.maximum_world_build_count": 1,
            "decision.maximum_outer_solver_steps": 2,
            "decision.seed": 1365251757,
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
            "authored_source_path_count": 12,
            "qualified_physical_path_count": 47,
            "current_zero_world_worker_count": 1,
            "current_applied_scale_positive_case_count": 2,
            "current_applied_scale_forced_failure_case_count": 4,
            "production_worker_parse_count": 1,
            "forced_supervisor_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "r96_closure_audit_reexecution_count": 0,
            "historical_closure_audits_executed_count": 0,
            "bespoke_physical_canary_count": 0,
            "full_seeded_ghost_count": 0,
            "current_applied_scale_worker_receipt.r96_predecessor_regression_passed": True,
            "current_applied_scale_worker_receipt.route_and_world_use_shared_resolver_required": True,
            "current_applied_scale_worker_receipt.guard_or_projection_target_changed": False,
            "current_applied_scale_worker_receipt.legacy_scale_path": (
                "angular_velocity_guard_applied_scale"
            ),
            "current_applied_scale_worker_receipt.nested_scale_path": (
                "native_angular_velocity_guard_projection.applied_scale"
            ),
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
            "authored_source_path_count": 12,
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
        '"r24d97_zero_world_qualification_pending": False' in frozen_audit,
        "FROZEN_POSTPUBLICATION_PENDING",
    )
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d97_contract_path",
        expected={
            "r24d97_source_commit": SOURCE,
            "r24d97_source_status": STATUS,
            "r24d97_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
            "r24d97_zero_world_closure_byte_length": LENGTH,
            "r24d97_zero_world_closure_raw_sha256": DIGEST,
            "r24d97_official_qualification_attempt_count": 1,
            "r24d97_zero_world_qualification_pending": False,
            "r24d97_zero_world_qualified": True,
            "r24d97_publication_transition_qualified": True,
            "r24d97_physical_execution_authorized": True,
            "r24d97_sdk1_milestone_advanced": False,
            "physical_execution_blocked_until_r24d97_zero_world_qualification": False,
        },
        prefix="LIVE_R97_CLOSURE",
    )


def test_r24d97_zero_world_qualification_closure() -> None:
    audit()


if __name__ == "__main__":
    audit()
    print("QSDK_R24D97_ZERO_WORLD_QUALIFICATION_CLOSURE_PASS")
