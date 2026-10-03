#!/usr/bin/env python3
"""Audit the retained R131 production-dispatch qualification closure."""

from __future__ import annotations

import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    load,
    require,
    sha256,
    verify_declared_zero_world_qualification_authority,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)

SOURCE_COMMIT = "48b105107910811a0ecdf399789b5544d1714d27"
CLOSURE_RELATIVE_PATH = (
    "sdk/recovery/r24d131_godot_jolt_progression_dispatch_"
    "zero_world_qualification_closure_v1.json"
)
CLOSURE = ROOT / CLOSURE_RELATIVE_PATH
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d131_godot_jolt_progression_dispatch_"
    "zero_world_qualification_closure_v1"
)
QUALIFIED_STATUS = (
    "closed_complete_zero_world_production_progression_dispatch_"
    "qualified_distinct_physical_declaration_required"
)
PREDECESSOR_STATUS = (
    "closed_zero_world_declared_r126_progression_route_omission_diagnosed_"
    "r129_behavior_inference_invalid_r131_route_correction_required"
)
AUDIT_RELATIVE_PATH = (
    "sdk/conformance/r24d131_godot_jolt_progression_dispatch_"
    "qualification_closure.py"
)
MARKER = "QSDK_R24D131_GODOT_JOLT_PROGRESSION_DISPATCH_QUALIFICATION_CLOSURE_PASS"
EXPECTED_CHECKS = (
    "source_manifest_frozen",
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


def _validate() -> tuple[dict[str, Any], dict[str, Any]]:
    checkout_metadata = tuple(
        {
            "path": path,
            "cause": "existing_windows_checkout_mixed_line_ending_materialization",
            "git_attribute": "text eol=lf",
        }
        for path in (
            "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd",
            "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
            "sdk/python/test_ctypes_smoke.py",
            "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd",
        )
    )
    closure, contract, receipt, preflight = (
        verify_declared_zero_world_qualification_authority(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=CLOSURE_SCHEMA,
            gate_id="QSDK-R24D131",
            closure_status=QUALIFIED_STATUS,
            source_commit=SOURCE_COMMIT,
            source_subject=(
                "[recovery/godot] Freeze R131: bind production progression dispatch"
            ),
            source_binding_names=(
                "source_audit",
                "production_route_binding_gate",
                "shared_closure_helper",
                "qualification_runner",
                "native_zero_world_test",
                "production_worker",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d131_godot_jolt_progression_dispatch_"
                "zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d131_godot_jolt_progression_dispatch_"
                "zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d131-godot-jolt-progression-dispatch-qualification-"
            ),
            expected_checks=EXPECTED_CHECKS,
            checkout_only_metadata=checkout_metadata,
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D131_GODOT_JOLT_PROGRESSION_DISPATCH_SOURCE_PASS"
                ),
                "native_zero_world.log": (
                    "SPORESPORE_GODOT_R24D131_PROGRESSION_DISPATCH_ZERO_WORLD"
                ),
            },
            physical_question_declared=False,
        )
    )
    require(
        len(contract["source_inventory"])
        == len(set(contract["source_inventory"]))
        == 67,
        "FROZEN_SOURCE_INVENTORY",
    )
    require(
        len(contract["authored_source_paths"])
        == len(set(contract["authored_source_paths"]))
        == 12,
        "FROZEN_AUTHORED_PATHS",
    )
    verify_exact_paths(
        contract,
        {
            "status": (
                "prospective_zero_world_production_progression_dispatch_"
                "implementation_qualification_pending"
            ),
            "question_class": "development",
            "physical_question_declared": False,
            "physical_execution_authorized": False,
            "production_binding.dispatch_id": (
                "godot_jolt_r24d131_versioned_recovery_progression_dispatch_v1"
            ),
            "production_binding.v6_selected_portable_advance_route": (
                "r126_development_progression_v5"
            ),
            "production_binding.historical_v5_selected_portable_advance_route": (
                "legacy_recovery_v4"
            ),
            "production_binding.one_progression_receipt_per_v6_observation_required": True,
            "complete_zero_world_gate.positive_case_count": 6,
            "complete_zero_world_gate.forced_failure_case_count": 7,
            "complete_zero_world_gate.model_construction_count": 0,
            "complete_zero_world_gate.world_build_count": 0,
            "complete_zero_world_gate.solver_step_count": 0,
            "claim_boundary.complete_zero_world_gate_passed": False,
            "claim_boundary.physical_execution_authorized": False,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "FROZEN_CONTRACT",
    )

    evidence_root = Path(closure["qualification"]["evidence_root"])
    attempt = load(evidence_root / closure["qualification"]["attempt_path"])
    verify_exact_paths(
        attempt,
        {
            "prospective_physical_question_declared": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
        },
        "ATTEMPT_SEMANTICS",
    )
    verify_exact_paths(
        receipt,
        {
            "declared_question_class": "development",
            "prospective_physical_question_declared": False,
            "native_zero_world.ok": True,
            "native_zero_world.positive_case_count": 6,
            "native_zero_world.positive_pass_count": 6,
            "native_zero_world.forced_failure_case_count": 7,
            "native_zero_world.forced_failure_pass_count": 7,
            "native_zero_world.production_advance_dispatch_id": (
                "godot_jolt_r24d131_versioned_recovery_progression_dispatch_v1"
            ),
            "native_zero_world.selected_v6_portable_advance_route": (
                "r126_development_progression_v5"
            ),
            "native_zero_world.progression_schema": (
                "sporespore_recovery_development_progression_receipt_v1"
            ),
            "native_zero_world.model_construction_count": 0,
            "native_zero_world.world_attempt_count": 0,
            "native_zero_world.world_build_count": 0,
            "native_zero_world.solver_step_count": 0,
            "native_zero_world.physics_state_modified": False,
            "native_zero_world.prone_to_standing_claimed": False,
            "native_zero_world.physical_acceptance_authority": False,
            "native_zero_world.release_authority": False,
            "native_zero_world_runtime.raw_sha256": (
                "sha256:19dc32b39400d200b5e5273f541ac41aa72a82110bb2fd338726a7fd465e0fa8"
            ),
        },
        "RECEIPT_SEMANTICS",
    )
    verify_exact_paths(
        preflight,
        {
            "schema_version": "sporespore_qsdk_r24d131_progression_dispatch_preflight_v1",
            "ok": True,
            "runtime_id": (
                "godot_4_7_jolt_sporespore_motor_and_solved_contact_telemetry_v3"
            ),
            "runtime_version": "4.7.stable.custom_build.5b4e0cb0f",
            "physical_question_opened": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "PREFLIGHT_SEMANTICS",
    )
    verify_exact_paths(
        closure,
        {
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": (
                "closed_complete_zero_world_production_progression_dispatch_"
                "qualification"
            ),
            "ledger_scope.question_class": "development",
            "source.branch": "main",
            "source.remote": "https://github.com/Slagathore/sporespore.git",
            "source.upstream_equal_at_qualification": True,
            "source.live_remote_equal_at_qualification": True,
            "source.worktree_clean_at_qualification_start_and_end": True,
            "qualification.check_count": 12,
            "qualification.checks_passed": 12,
            "qualification.source_inventory_count": 67,
            "qualification.authored_source_path_count": 12,
            "qualification.positive_case_count": 6,
            "qualification.positive_pass_count": 6,
            "qualification.forced_failure_case_count": 7,
            "qualification.forced_failure_pass_count": 7,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.bespoke_physical_canary_count": 0,
            "qualification.full_seeded_ghost_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "decision.complete_zero_world_gate_passed": True,
            "decision.production_dispatch_identity_validated": True,
            "decision.progression_receipt_identity_validated": True,
            "decision.progression_population_validated": True,
            "decision.historical_v5_route_preserved": True,
            "decision.physical_question_declared": False,
            "decision.physical_execution_authorized": False,
            "decision.r24d132_distinct_physical_declaration_required": True,
            "decision.prone_to_standing_claimed": False,
            "next_boundary.physical_question_declared": False,
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_attempt_count": 0,
            "next_boundary.maximum_solver_step_count": 0,
            "claim_boundary.complete_zero_world_gate_passed": True,
            "claim_boundary.production_progression_dispatch_mechanics_qualified": True,
            "claim_boundary.physical_attempted": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.sdk1_milestone_advanced": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
            "closure_audit_path": AUDIT_RELATIVE_PATH,
        },
        "CLOSURE_SEMANTICS",
    )

    closure_raw = CLOSURE.read_bytes()
    qualification = closure["qualification"]
    live_expected = {
        "r24d131_zero_world_route_correction_required": False,
        "r24d131_contract_path": (
            "sdk/recovery/r24d131_godot_jolt_progression_dispatch_contract_v1.json"
        ),
        "r24d131_source_status": QUALIFIED_STATUS,
        "r24d131_question_class": "development",
        "r24d131_physical_question_declared": False,
        "r24d131_production_advance_dispatch_id": (
            "godot_jolt_r24d131_versioned_recovery_progression_dispatch_v1"
        ),
        "r24d131_v6_selected_portable_advance_route": (
            "r126_development_progression_v5"
        ),
        "r24d131_progression_receipt_schema": (
            "sporespore_recovery_development_progression_receipt_v1"
        ),
        "r24d131_zero_world_positive_case_count": 6,
        "r24d131_zero_world_forced_failure_case_count": 7,
        "r24d131_zero_world_qualification_pending": False,
        "r24d131_zero_world_qualification_complete": True,
        "r24d131_zero_world_qualified": True,
        "r24d131_source_commit": SOURCE_COMMIT,
        "r24d131_zero_world_closure_path": CLOSURE_RELATIVE_PATH,
        "r24d131_zero_world_closure_raw_sha256": sha256(closure_raw),
        "r24d131_zero_world_closure_byte_length": len(closure_raw),
        "r24d131_zero_world_evidence_root": qualification["evidence_root"],
        "r24d131_qualification_attempt_raw_sha256": qualification[
            "attempt_raw_sha256"
        ],
        "r24d131_qualification_receipt_raw_sha256": qualification[
            "receipt_raw_sha256"
        ],
        "r24d131_qualification_check_count": 12,
        "r24d131_qualification_checks_passed": 12,
        "r24d131_qualification_model_construction_count": 0,
        "r24d131_qualification_world_attempt_count": 0,
        "r24d131_qualification_world_build_count": 0,
        "r24d131_qualification_solver_step_count": 0,
        "r24d131_physical_execution_authorized": False,
        "r24d131_prone_to_standing_claimed": False,
        "r24d131_sdk1_milestone_advanced": False,
        "r24d132_distinct_physical_declaration_required": True,
        "physical_execution_blocked_until_r24d131_zero_world_qualification": False,
        "physical_execution_blocked_pending_r24d132_declaration": True,
        "r24d131_qualification_closure_audit_path": AUDIT_RELATIVE_PATH,
        "next_gate_id": "QSDK-R24D132",
    }
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d131_contract_path",
        expected=live_expected,
        prefix="LIVE_R131_QUALIFICATION",
    )
    return closure, receipt


def main() -> int:
    try:
        closure, receipt = _validate()
    except (ClosureAuditError, KeyError, OSError, TypeError, ValueError) as error:
        print(f"{MARKER}_FAIL {error}")
        return 1
    print(
        MARKER
        + " "
        + json.dumps(
            {
                "gate_id": closure["gate_id"],
                "ok": True,
                "source_commit": SOURCE_COMMIT,
                "retained_file_count": closure["qualification"]["retained_tree"][
                    "file_count"
                ],
                "check_count": len(receipt["checks"]),
                "positive_case_count": receipt["native_zero_world"][
                    "positive_case_count"
                ],
                "forced_failure_case_count": receipt["native_zero_world"][
                    "forced_failure_case_count"
                ],
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
                "physical_execution_authorized": False,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
