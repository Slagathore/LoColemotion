#!/usr/bin/env python3
"""Audit R95's zero-world qualification and stable publication transition."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import (  # noqa: E402
    r24d95_godot_jolt_publication_stable_guarded_recovery_route as source_audit,
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
    "sdk/recovery/r24d95_godot_jolt_publication_stable_guarded_"
    "recovery_route_zero_world_qualification_closure_v1.json"
)
CONTRACT = ROOT / (
    "sdk/recovery/r24d95_godot_jolt_publication_stable_guarded_"
    "recovery_route_contract_v1.json"
)
SOURCE = "fa30e7dc3e745ea0089916bc6b49bb0a63d65ef1"
LENGTH = 16634
DIGEST = "sha256:c2837594a5bd76c324041ba054a644f89978b7ec8eab7a68d7f7653aa698cdd1"
STATUS = (
    "closed_complete_zero_world_publication_state_stable_guarded_recovery_"
    "route_qualified_one_two_step_development_ghost_authorized"
)
PREDECESSOR_STATUS = (
    "closed_complete_zero_world_guarded_recovery_route_qualification_passed_"
    "publication_state_audit_not_reusable_no_physics_authorized_r95_required"
)
AUDIT_PATH = (
    "sdk/conformance/r24d95_godot_jolt_publication_stable_guarded_"
    "recovery_route.py"
)


def audit() -> None:
    raw = CLOSURE.read_bytes().replace(b"\r\n", b"\n")
    exact((len(raw), sha256(raw)), (LENGTH, DIGEST), "CLOSURE_BLOB")
    closure, frozen_contract, _receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d95_godot_jolt_publication_stable_"
                "guarded_recovery_route_zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D95",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/core] Declare R95 route: stabilize publication state"
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
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d95_godot_jolt_publication_stable_"
                "guarded_route_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d95_godot_jolt_publication_stable_"
                "guarded_route_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d95-godot-jolt-publication-stable-guarded-route-"
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
                    "QSDK_R24D95_GODOT_JOLT_PUBLICATION_STABLE_GUARDED_"
                    "ROUTE_SOURCE_PASS"
                ),
                "production_preflight.log": '"gate_id": "QSDK-R24D95"',
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
            "qualification.check_count": 9,
            "qualification.checks_passed": 9,
            "qualification.source_inventory_count": 63,
            "qualification.authored_source_path_count": 9,
            "qualification.qualified_physical_path_count": 47,
            "qualification.current_zero_world_worker_count": 0,
            "qualification.r94_closure_audit_reexecution_count": 0,
            "qualification.r94_native_guard_worker_reexecution_count": 0,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.bespoke_physical_canary_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "publication_transition_projection.same_frozen_source_audit_valid_in_both_phases": True,
            "publication_transition_projection.postpublication_pending": False,
            "publication_transition_projection.postpublication_qualified": True,
            "publication_transition_projection.postpublication_physical_execution_authorized": True,
            "decision.r94_guard_qualification_bound": True,
            "decision.publication_transition_qualified": True,
            "decision.physical_ghost_authorized": True,
            "decision.maximum_world_build_count": 1,
            "decision.maximum_outer_solver_steps": 2,
            "decision.physics_ticks_per_second": 120,
            "decision.outer_step_duration_s": 1.0 / 120.0,
            "decision.seed": 198935103,
            "decision.held_out": False,
            "decision.same_identity_rerun_permitted": False,
            "decision.physical_attempted": False,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "claim_boundary.publication_state_stable_source_preflight_proven": True,
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
            "actuator_mode": "force_based_native_angular_velocity_guarded_v1",
            "source_inventory_count": 63,
            "authored_source_path_count": 9,
            "qualified_physical_path_count": 47,
            "current_zero_world_worker_count": 0,
            "production_worker_parse_count": 1,
            "forced_supervisor_failure_control_count": 1,
            "missing_physical_switch_refusal_count": 1,
            "r94_closure_audit_reexecution_count": 0,
            "r94_native_guard_worker_reexecution_count": 0,
            "historical_closure_audits_executed_count": 0,
            "bespoke_physical_canary_count": 0,
            "full_seeded_ghost_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
        },
        "PREFLIGHT",
    )

    # This is the R95 question: the exact source audit that passed before the
    # closure must also pass after honest closure publication without changing
    # any qualified physical dependency.
    live_contract, live_counts, published = source_audit.validate_sources()
    exact(live_contract, frozen_contract, "POSTPUBLICATION_FROZEN_CONTRACT")
    exact(published, True, "POSTPUBLICATION_PHASE")
    exact(
        live_counts,
        {
            "source_inventory_count": 63,
            "authored_source_path_count": 9,
            "qualified_physical_path_count": 47,
            "bound_predecessor_count": 1,
            "current_zero_world_worker_count": 0,
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
        '"r24d95_zero_world_qualification_pending": False' in frozen_audit,
        "FROZEN_POSTPUBLICATION_PENDING",
    )
    require(
        '"r24d95_zero_world_qualified": True' in frozen_audit,
        "FROZEN_POSTPUBLICATION_QUALIFIED",
    )
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d95_contract_path",
        expected={
            "r24d95_source_commit": SOURCE,
            "r24d95_source_status": STATUS,
            "r24d95_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
            "r24d95_zero_world_closure_byte_length": LENGTH,
            "r24d95_zero_world_closure_raw_sha256": DIGEST,
            "r24d95_official_qualification_attempt_count": 1,
            "r24d95_zero_world_qualification_pending": False,
            "r24d95_zero_world_qualified": True,
            "r24d95_publication_state_audit_reusable": True,
            "r24d95_physical_execution_authorized": True,
            "r24d95_sdk1_milestone_advanced": False,
            "physical_execution_blocked_until_r24d95_zero_world_qualification": False,
            "physical_execution_blocked_by_r24d94_publication_state_audit_limit": False,
        },
        prefix="LIVE_R95_CLOSURE",
    )


def test_r24d95_zero_world_qualification_closure() -> None:
    audit()


if __name__ == "__main__":
    audit()
    print("QSDK_R24D95_ZERO_WORLD_QUALIFICATION_CLOSURE_PASS")
