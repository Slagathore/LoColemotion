#!/usr/bin/env python3
"""Audit the retained R113 versioned-controller qualification closure."""

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

SOURCE_COMMIT = "f4a0e709860e8ff81cc2201c02c541445ff6339a"
CLOSURE_RELATIVE_PATH = (
    "sdk/recovery/r24d113_godot_jolt_mirrored_front_knee_controller_"
    "zero_world_qualification_closure_v1.json"
)
CLOSURE = ROOT / CLOSURE_RELATIVE_PATH
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d113_godot_jolt_mirrored_front_knee_controller_"
    "zero_world_qualification_closure_v1"
)
QUALIFIED_STATUS = (
    "closed_complete_zero_world_versioned_mirrored_front_knee_controller_"
    "qualified_successor_physical_declaration_required"
)
PREDECESSOR_STATUS = (
    "closed_zero_world_front_support_target_sign_asymmetry_diagnosis_"
    "mirrored_front_knee_successor_selected"
)
AUDIT_RELATIVE_PATH = (
    "sdk/conformance/r24d113_godot_jolt_mirrored_front_knee_controller_"
    "qualification_closure.py"
)
MARKER = "QSDK_R24D113_GODOT_JOLT_MIRRORED_FRONT_KNEE_QUALIFICATION_CLOSURE_PASS"


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
            gate_id="QSDK-R24D113",
            closure_status=QUALIFIED_STATUS,
            source_commit=SOURCE_COMMIT,
            source_subject=(
                "[recovery/core] Implement R113: version mirrored-knee controller"
            ),
            source_binding_names=(
                "source_audit",
                "versioned_controller_gate",
                "shared_closure_helper",
                "qualification_runner",
                "native_zero_world_test",
                "production_worker",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d113_godot_jolt_mirrored_front_knee_"
                "controller_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d113_godot_jolt_mirrored_front_knee_"
                "controller_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d113-godot-jolt-mirrored-front-knee-controller-"
                "qualification-"
            ),
            expected_checks=(
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
            ),
            checkout_only_metadata=checkout_metadata,
            retained_log_markers={
                "source_audit.log": (
                    "QSDK_R24D113_GODOT_JOLT_MIRRORED_FRONT_KNEE_CONTROLLER_"
                    "SOURCE_PASS"
                ),
                "native_zero_world.log": (
                    "SPORESPORE_GODOT_R24D113_MIRRORED_FRONT_KNEE_ZERO_WORLD"
                ),
            },
            physical_question_declared=False,
        )
    )
    require(
        len(contract["source_inventory"])
        == len(set(contract["source_inventory"]))
        == 25,
        "FROZEN_SOURCE_INVENTORY",
    )
    verify_exact_paths(
        contract,
        {
            "status": (
                "prospective_zero_world_versioned_controller_target_"
                "implementation_qualification_pending"
            ),
            "question_class": "development",
            "physical_question_declared": False,
            "controller_version_contract.historical_controller_id": (
                "sporespore_exact_s169_prone_to_standing_controller_v1"
            ),
            "controller_version_contract.successor_controller_id": (
                "sporespore_exact_s169_prone_to_standing_controller_v2"
            ),
            "controller_version_contract.historical_support_command_sha256": (
                "sha256:a3db46122897f379a8e85913bfb8d1b52f795886fd122ec9a99966917e57fd74"
            ),
            "controller_version_contract.successor_support_command_sha256": (
                "sha256:b2ac422515763c5c42acd5a6dcf943bb267f5a3ab4b234be783d83b4e284e2d9"
            ),
            "controller_version_contract.changed_target_count": 2,
            "controller_version_contract.changed_target_indices": [1, 3],
            "complete_zero_world_gate.cross_version_refusal_count": 2,
            "complete_zero_world_gate.unregistered_controller_refusal_count": 3,
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
            "native_zero_world.changed_target_count": 2,
            "native_zero_world.changed_target_indices": [1, 3],
            "native_zero_world.cross_version_observation_refusal_count": 2,
            "native_zero_world.unregistered_controller_refusal_count": 3,
            "native_zero_world.historical_v1_regression_passed": True,
            "native_zero_world.non_target_command_fields_identical": True,
            "native_zero_world.effective_inertia_route_regression_passed": True,
            "native_zero_world.zero_world_bootstrap_application_passed": True,
            "native_zero_world.zero_world_application_passed": True,
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
            "schema_version": (
                "sporespore_versioned_recovery_controller_target_preflight_v1"
            ),
            "ok": True,
            "runtime_id": "sporespore_locomotion_core_debug_dll",
            "runtime_version": (
                "sha256:676e7691e7f1979433a29802e02983fa7e058c2b0e8e241e8e0a81c6bf6a586a"
            ),
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
                "closed_complete_zero_world_versioned_controller_target_qualification"
            ),
            "ledger_scope.question_class": "development",
            "source.branch": "main",
            "source.remote": "https://github.com/Slagathore/sporespore.git",
            "source.upstream_equal_at_qualification": True,
            "source.live_remote_equal_at_qualification": True,
            "source.worktree_clean_at_qualification_start_and_end": True,
            "qualification.check_count": 12,
            "qualification.checks_passed": 12,
            "qualification.source_inventory_count": 25,
            "qualification.authored_source_path_count": 13,
            "qualification.cross_version_observation_refusal_count": 2,
            "qualification.unregistered_controller_refusal_count": 3,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.bespoke_physical_canary_count": 0,
            "qualification.full_seeded_ghost_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "decision.complete_zero_world_gate_passed": True,
            "decision.physical_question_declared": False,
            "decision.physical_execution_authorized": False,
            "decision.r24d114_distinct_physical_declaration_required": True,
            "decision.prone_to_standing_claimed": False,
            "next_boundary.physical_question_declared": False,
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_attempt_count": 0,
            "next_boundary.maximum_solver_step_count": 0,
            "claim_boundary.complete_zero_world_gate_passed": True,
            "claim_boundary.versioned_mirrored_front_knee_controller_mechanics_qualified": True,
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
    closure_sha256 = sha256(closure_raw)
    live_expected = {
        "r24d113_source_status": QUALIFIED_STATUS,
        "r24d113_source_commit": SOURCE_COMMIT,
        "r24d113_zero_world_qualified": True,
        "r24d113_zero_world_qualification_complete": True,
        "r24d113_zero_world_closure_path": CLOSURE_RELATIVE_PATH,
        "r24d113_zero_world_closure_raw_sha256": closure_sha256,
        "r24d113_zero_world_closure_byte_length": len(closure_raw),
        "r24d113_zero_world_evidence_root": closure["qualification"]["evidence_root"],
        "r24d113_qualification_attempt_raw_sha256": closure["qualification"][
            "attempt_raw_sha256"
        ],
        "r24d113_qualification_receipt_raw_sha256": closure["qualification"][
            "receipt_raw_sha256"
        ],
        "r24d113_qualification_check_count": 12,
        "r24d113_qualification_checks_passed": 12,
        "r24d113_qualification_model_construction_count": 0,
        "r24d113_qualification_world_attempt_count": 0,
        "r24d113_qualification_world_build_count": 0,
        "r24d113_qualification_solver_step_count": 0,
        "r24d113_physical_question_declared": False,
        "r24d113_physical_execution_authorized": False,
        "r24d113_prone_to_standing_claimed": False,
        "r24d113_sdk1_milestone_advanced": False,
        "r24d114_distinct_physical_declaration_required": True,
        "physical_execution_blocked_until_r24d113_zero_world_qualification": False,
        "physical_execution_blocked_pending_r24d114_declaration": True,
        "r24d113_qualification_closure_audit_path": AUDIT_RELATIVE_PATH,
    }
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d113_contract_path",
        expected=live_expected,
        prefix="LIVE_R113_QUALIFICATION",
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
