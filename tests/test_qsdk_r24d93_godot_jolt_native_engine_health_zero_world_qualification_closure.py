#!/usr/bin/env python3
"""Audit the compact R93 native-engine-health qualification closure."""

from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    sha256,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d93_godot_jolt_native_engine_health_"
    "zero_world_qualification_closure_v1.json"
)
SOURCE = "c2a075639ae02e10490f899247d122f70b4cfbef"
STATUS = (
    "closed_complete_zero_world_native_engine_health_qualification_passed_"
    "no_physical_question_r24d94_required"
)
PREDECESSOR_STATUS = (
    "closed_consumed_complete_producer_negative_invalid_for_physical_inference_"
    "native_angular_velocity_limit_assertions"
)
CHECKS = (
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
)


def main() -> None:
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d93_godot_jolt_native_engine_health_"
                "zero_world_qualification_closure_v1"
            ),
            gate_id="QSDK-R24D93",
            closure_status=STATUS,
            source_commit=SOURCE,
            source_subject=(
                "[recovery/godot] Declare R93 health: fail closed native limits"
            ),
            source_binding_names=(
                "contract",
                "source_audit",
                "shared_helper",
                "engine_health_helper",
                "native_world",
                "shared_supervisor",
                "production_worker",
                "native_zero_world_worker",
                "qualification_runner",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d93_godot_jolt_native_engine_health_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d93_godot_jolt_native_engine_health_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d93-godot-jolt-native-engine-health-qualification-"
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
                {
                    "path": (
                        "tests/test_sdk_qsdk_r24d65_godot_native_recovery_"
                        "behavior.gd"
                    ),
                    "cause": "windows_checkout_mixed_line_ending_materialization",
                    "git_attribute": "text eol=lf",
                    "git_ls_files_eol": "i/lf w/mixed attr/text eol=lf",
                },
            ),
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D93_GODOT_JOLT_NATIVE_ENGINE_HEALTH_SOURCE_PASS"
                ),
                "cargo_targeted_tests.log": (
                    "complete_active_recovery_population_has_transport_stable_"
                    "command_identity ... ok"
                ),
                "native_zero_world.log": (
                    "SPORESPORE_GODOT_JOLT_NATIVE_ENGINE_HEALTH_ZERO_WORLD"
                ),
                "production_preflight.log": '"physical_question_opened":false',
            },
            physical_question_declared=False,
        )
    )

    verify_exact_paths(
        contract,
        {
            "status": "declared_zero_world_native_engine_health_coverage_physics_blocked",
            "question_class": "development",
            "physical_question_declared": False,
            "controlled_change.shared_supervisor_engine_health_projection_added": True,
            "controlled_change.complete_ordered_body_population_required_per_native_step": True,
            "controlled_change.exact_limit_equality_passes": True,
            "controlled_change.any_limit_exceedance_fails_closed": True,
            "controlled_change.historical_r24d92_result_changed": False,
            "controlled_change.native_engine_limit_changed": False,
            "threshold_margin_cohort_and_population_adequacy.comparison_margin_rad_s": 0.0,
            "threshold_margin_cohort_and_population_adequacy.zero_world_positive_case_count": 4,
            "threshold_margin_cohort_and_population_adequacy.zero_world_forced_failure_case_count": 13,
            "complete_zero_world_gate.historical_closure_audits_executed_count": 0,
            "complete_zero_world_gate.bespoke_physical_canary_count": 0,
            "complete_zero_world_gate.full_seeded_ghost_count": 0,
            "critical_path_audit_policy.source_inventory_count": 65,
            "critical_path_audit_policy.qualified_physical_path_count": 47,
            "critical_path_audit_policy.publication_only_path_count": 18,
            "critical_path_audit_policy.authored_source_path_count": 16,
        },
        "CONTRACT",
    )
    exact(
        closure["predecessor"]["closure_raw_sha256"],
        contract["bound_predecessor"]["raw_sha256"],
        "PREDECESSOR_BINDING",
    )
    verify_exact_paths(
        preflight,
        {
            "schema_version": "sporespore_qsdk_r24d93_native_engine_health_preflight_v1",
            "gate_id": "QSDK-R24D93",
            "ok": True,
            "runtime_id": contract["exact_runtime"]["runtime_profile_id"],
            "runtime_version": contract["exact_runtime"]["runtime_version"],
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "prone_to_standing_claimed": False,
        },
        "PREFLIGHT",
    )
    exact(
        receipt["native_zero_world"],
        closure["native_zero_world_projection"],
        "NATIVE_ZERO_WORLD_BINDING",
    )
    exact(receipt["production_preflight"], preflight, "PREFLIGHT_BINDING")
    verify_exact_paths(
        closure,
        {
            "qualification.check_count": len(CHECKS),
            "qualification.checks_passed": len(CHECKS),
            "qualification.source_manifest_entry_count": 65,
            "qualification.source_inventory_count": 65,
            "qualification.qualified_physical_path_count": 47,
            "qualification.publication_only_path_count": 18,
            "qualification.authored_source_path_count": 16,
            "qualification.powershell_positive_case_count": 2,
            "qualification.powershell_forced_failure_case_count": 5,
            "qualification.native_positive_case_count": 2,
            "qualification.native_forced_failure_case_count": 8,
            "qualification.production_worker_parse_count": 1,
            "qualification.wrapper_physical_refusal_count": 1,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.bespoke_physical_canary_count": 0,
            "qualification.full_seeded_ghost_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "decision.shared_engine_diagnostic_invariant_qualified": True,
            "decision.complete_body_angular_velocity_limit_invariants_qualified": True,
            "decision.physical_question_declared": False,
            "decision.physical_execution_authorized": False,
            "decision.distinct_r24d94_successor_required": True,
            "next_boundary.gate_id": "QSDK-R24D94",
            "next_boundary.question_class_declared": False,
            "next_boundary.physical_execution_authorized": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
        },
        "CLOSURE",
    )

    closure_raw = CLOSURE.read_bytes()
    live_expected = {
        "r24d93_source_status": STATUS,
        "r24d93_source_commit": SOURCE,
        "r24d93_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
        "r24d93_zero_world_closure_raw_sha256": sha256(closure_raw),
        "r24d93_zero_world_closure_byte_length": len(closure_raw),
        "r24d93_official_qualification_attempt_count": 1,
        "r24d93_check_count": 11,
        "r24d93_source_inventory_count": 65,
        "r24d93_qualified_physical_path_count": 47,
        "r24d93_publication_only_path_count": 18,
        "r24d93_authored_source_path_count": 16,
        "r24d93_native_effective_max_angular_velocity_rad_s": 47.1238899230957,
        "r24d93_native_exact_limit_equality_passed": True,
        "r24d93_zero_world_qualification_pending": False,
        "r24d93_zero_world_qualified": True,
        "r24d93_physical_execution_authorized": False,
        "physical_execution_blocked_until_r24d93_zero_world_qualification": False,
        "r24d94_distinct_successor_required": True,
        "r24d94_question_class_declared": False,
        "r24d94_physical_question_declared": False,
        "physical_execution_blocked_pending_r24d94_declaration": True,
    }
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d93_contract_path",
        expected=live_expected,
        prefix="LIVE_R93",
    )
    print(
        "QSDK_R24D93_GODOT_JOLT_NATIVE_ENGINE_HEALTH_ZERO_WORLD_CLOSURE_PASS "
        "sources=65 physical_paths=47 checks=11/11 positives=4 forced=13 "
        "historical_audits=0 canaries=0 ghosts=0 models=0 worlds=0 steps=0 "
        "next=r24d94_declaration sdk1=11/20"
    )


if __name__ == "__main__":
    main()
