#!/usr/bin/env python3
"""Audit the retained R114 finite-behavior qualification closure."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
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

SOURCE_COMMIT = "de6c114bef968f11a4dcc9d11d807c34ee0f13f0"
CLOSURE_RELATIVE_PATH = (
    "sdk/recovery/r24d114_godot_jolt_mirrored_front_knee_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
CLOSURE = ROOT / CLOSURE_RELATIVE_PATH
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d114_godot_jolt_mirrored_front_knee_recovery_"
    "behavior_zero_world_qualification_closure_v1"
)
QUALIFIED_STATUS = (
    "closed_complete_zero_world_mirrored_front_knee_recovery_behavior_"
    "qualified_publication_state_audit_not_reusable_no_physics_authorized_"
    "r115_required"
)
PREDECESSOR_STATUS = (
    "closed_complete_zero_world_versioned_mirrored_front_knee_controller_"
    "qualified_successor_physical_declaration_required"
)
AUDIT_RELATIVE_PATH = (
    "sdk/conformance/r24d114_godot_jolt_mirrored_front_knee_recovery_"
    "behavior_qualification_closure.py"
)
MARKER = (
    "QSDK_R24D114_GODOT_JOLT_MIRRORED_FRONT_KNEE_RECOVERY_BEHAVIOR_"
    "QUALIFICATION_CLOSURE_PASS"
)


def _validate_bound_development(closure: dict[str, Any]) -> None:
    development = closure["development_evidence"]
    r111_path = ROOT / str(development["r24d111_path"])
    r112_path = ROOT / str(development["r24d112_path"])
    r111_raw = r111_path.read_bytes()
    r112_raw = r112_path.read_bytes()
    verify_exact_paths(
        development,
        {
            "r24d111_raw_sha256": sha256(r111_raw),
            "r24d111_byte_length": len(r111_raw),
            "r24d111_scientific_outcome": "negative",
            "r24d112_raw_sha256": sha256(r112_raw),
            "r24d112_byte_length": len(r112_raw),
            "r24d112_selected_front_knee_target_rad": -1.05,
            "source_contract_bindings_reverified": True,
            "historical_closure_audits_reexecuted_count": 0,
        },
        "DEVELOPMENT_EVIDENCE",
    )
    verify_exact_paths(
        load(r111_path),
        {
            "gate_id": "QSDK-R24D111",
            "physical_attempt.status": "valid_complete_behavior_development",
            "physical_attempt.scientific_outcome": "negative",
            "physical_attempt.recovery_success_observed": False,
            "decision.same_identity_rerun_permitted": False,
        },
        "R111_BOUND_NEGATIVE",
    )
    verify_exact_paths(
        load(r112_path),
        {
            "gate_id": "QSDK-R24D112",
            "computed_projection.selected_front_knee_target_rad": -1.05,
            "computed_projection.selected_rear_knee_target_rad": 1.05,
            "computed_projection.execution_counts.world_attempt_count": 0,
            "decision.physical_execution_authorized": False,
        },
        "R112_BOUND_DIAGNOSIS",
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
            gate_id="QSDK-R24D114",
            closure_status=QUALIFIED_STATUS,
            source_commit=SOURCE_COMMIT,
            source_subject=(
                "[recovery/godot] Freeze R114: declare mirrored-knee behavior pair"
            ),
            source_binding_names=(
                "source_audit",
                "versioned_controller_gate",
                "shared_closure_helper",
                "qualification_runner",
                "physical_runner",
                "shared_physical_supervisor",
                "native_zero_world_test",
                "production_worker",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d114_godot_jolt_mirrored_front_knee_"
                "recovery_behavior_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d114_godot_jolt_mirrored_front_knee_"
                "recovery_behavior_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d114-godot-jolt-mirrored-front-knee-recovery-"
                "behavior-qualification-"
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
                    "QSDK_R24D114_GODOT_JOLT_MIRRORED_FRONT_KNEE_BEHAVIOR_"
                    "SOURCE_PASS"
                ),
                "native_zero_world.log": (
                    "SPORESPORE_GODOT_R24D114_MIRRORED_FRONT_KNEE_BEHAVIOR_"
                    "ZERO_WORLD"
                ),
            },
            physical_question_declared=True,
        )
    )
    require(
        len(contract["source_inventory"])
        == len(set(contract["source_inventory"]))
        == 62,
        "FROZEN_SOURCE_INVENTORY",
    )
    require(
        len(contract["qualified_physical_paths"])
        == len(set(contract["qualified_physical_paths"]))
        == 49,
        "QUALIFIED_PHYSICAL_PATHS",
    )
    require(
        CLOSURE_RELATIVE_PATH not in contract["qualified_physical_paths"]
        and AUDIT_RELATIVE_PATH not in contract["qualified_physical_paths"]
        and not set(closure["live_authority_paths"])
        & set(contract["qualified_physical_paths"]),
        "PUBLICATION_PARTITION",
    )
    verify_exact_paths(
        contract,
        {
            "status": (
                "prospective_finite_mirrored_front_knee_recovery_behavior_"
                "complete_zero_world_qualification_required_physics_blocked"
            ),
            "question_class": "development",
            "physical_question_declared": True,
            "finite_development_population.world_count": 2,
            "finite_development_population.maximum_total_outer_steps": 2400,
            "finite_development_population.same_source_attempt_limit": 1,
            "finite_development_population.same_identity_rerun_permitted": False,
            "behavior_execution_contract.recovery_controller_id": (
                "sporespore_exact_s169_prone_to_standing_controller_v2"
            ),
            "behavior_execution_contract.support_command_sha256": (
                "sha256:b2ac422515763c5c42acd5a6dcf943bb267f5a3ab4b234be783d83b4e284e2d9"
            ),
            "complete_zero_world_gate.additional_physical_ghost_count": 0,
            "complete_zero_world_gate.additional_physical_canary_count": 0,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "FROZEN_CONTRACT",
    )
    _validate_bound_development(closure)

    evidence_root = Path(closure["qualification"]["evidence_root"])
    attempt = load(evidence_root / closure["qualification"]["attempt_path"])
    verify_exact_paths(
        attempt,
        {
            "prospective_physical_question_declared": True,
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
            "prospective_physical_question_declared": True,
            "native_zero_world.changed_target_count": 2,
            "native_zero_world.changed_target_indices": [1, 3],
            "native_zero_world.successor_controller_id": (
                "sporespore_exact_s169_prone_to_standing_controller_v2"
            ),
            "native_zero_world.cross_version_observation_refusal_count": 2,
            "native_zero_world.unregistered_controller_refusal_count": 3,
            "native_zero_world.historical_v1_regression_passed": True,
            "native_zero_world.non_target_command_fields_identical": True,
            "native_zero_world.effective_inertia_route_regression_passed": True,
            "native_zero_world.zero_world_bootstrap_application_passed": True,
            "native_zero_world.zero_world_application_passed": True,
            "native_zero_world.world_attempt_count": 0,
            "native_zero_world.solver_step_count": 0,
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
                "sporespore_qsdk_r24d114_mirrored_front_knee_behavior_" "preflight_v1"
            ),
            "ok": True,
            "runtime_id": "sporespore_locomotion_core_debug_dll",
            "runtime_version": (
                "sha256:825b6111188313cd7d7690cc3b6088c5952dd36d6dd7201e087066decbcc31fb"
            ),
            "prospective_physical_question_declared": True,
            "physical_execution_authorized": False,
            "world_attempt_count": 0,
            "solver_step_count": 0,
        },
        "PREFLIGHT_SEMANTICS",
    )
    verify_exact_paths(
        closure,
        {
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": (
                "closed_complete_zero_world_finite_mirrored_front_knee_"
                "behavior_qualification"
            ),
            "ledger_scope.question_class": "development",
            "source.source_freeze_commit": SOURCE_COMMIT,
            "source.upstream_equal_at_qualification": True,
            "source.live_remote_equal_at_qualification": True,
            "qualification.check_count": 12,
            "qualification.checks_passed": 12,
            "qualification.source_inventory_count": 62,
            "qualification.authored_source_path_count": 11,
            "qualification.qualified_physical_path_count": 49,
            "qualification.additional_physical_ghost_count": 0,
            "qualification.bespoke_physical_canary_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "runtime_identity_projection.recovery_controller_id": (
                "sporespore_exact_s169_prone_to_standing_controller_v2"
            ),
            "post_qualification_publication_stability_diagnosis.development_preflight_invocation_count": 1,
            "post_qualification_publication_stability_diagnosis.failure_phase": "source_preflight",
            "post_qualification_publication_stability_diagnosis.failure_code": "LIVE_R114_PROSPECTIVE",
            "post_qualification_publication_stability_diagnosis.operation_lock_acquired": False,
            "post_qualification_publication_stability_diagnosis.physical_process_started": False,
            "post_qualification_publication_stability_diagnosis.world_attempt_count": 0,
            "post_qualification_publication_stability_diagnosis.solver_step_count": 0,
            "decision.physical_execution_authorized": False,
            "decision.physical_behavior_attempt_authorized": False,
            "decision.authorized_world_count": 0,
            "decision.maximum_outer_solver_steps": 0,
            "decision.seed": 278151771,
            "physical_authorization.zero_world_qualification_passed": True,
            "physical_authorization.physical_execution_authorized": False,
            "physical_authorization.maximum_world_attempt_count": 0,
            "physical_authorization.maximum_outer_solver_steps": 0,
            "physical_authorization.same_identity_rerun_permitted": False,
            "next_boundary.gate_id": "QSDK-R24D115",
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_attempt_count": 0,
            "next_boundary.maximum_solver_step_count": 0,
            "claim_boundary.complete_zero_world_gate_passed": True,
            "claim_boundary.mirrored_front_knee_controller_mechanics_qualified": True,
            "claim_boundary.publication_stable_behavior_route_qualified": False,
            "claim_boundary.physical_execution_authorized": False,
            "claim_boundary.physical_attempted": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.sdk1_milestone_advanced": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
            "closure_audit_path": AUDIT_RELATIVE_PATH,
        },
        "CLOSURE_SEMANTICS",
    )

    closure_raw = CLOSURE.read_bytes()
    live_expected = {
        "r24d114_source_status": QUALIFIED_STATUS,
        "r24d114_source_commit": SOURCE_COMMIT,
        "r24d114_zero_world_qualified": True,
        "r24d114_zero_world_qualification_complete": True,
        "r24d114_zero_world_closure_path": CLOSURE_RELATIVE_PATH,
        "r24d114_zero_world_closure_raw_sha256": sha256(closure_raw),
        "r24d114_zero_world_closure_byte_length": len(closure_raw),
        "r24d114_zero_world_evidence_root": closure["qualification"]["evidence_root"],
        "r24d114_qualification_attempt_raw_sha256": closure["qualification"][
            "attempt_raw_sha256"
        ],
        "r24d114_qualification_receipt_raw_sha256": closure["qualification"][
            "receipt_raw_sha256"
        ],
        "r24d114_qualification_check_count": 12,
        "r24d114_qualification_checks_passed": 12,
        "r24d114_qualification_model_construction_count": 0,
        "r24d114_qualification_world_attempt_count": 0,
        "r24d114_qualification_world_build_count": 0,
        "r24d114_qualification_solver_step_count": 0,
        "r24d114_physical_question_declared": True,
        "r24d114_physical_execution_authorized": False,
        "r24d114_prone_to_standing_claimed": False,
        "r24d114_sdk1_milestone_advanced": False,
        "physical_execution_blocked_until_r24d114_zero_world_qualification": False,
        "physical_execution_blocked_by_r24d114_publication_state_audit_limit": True,
        "r24d115_publication_stable_successor_required": True,
        "r24d114_qualification_closure_audit_path": AUDIT_RELATIVE_PATH,
    }
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d114_contract_path",
        expected=live_expected,
        prefix="LIVE_R114_QUALIFICATION",
    )
    return closure, receipt


def main() -> int:
    try:
        closure, receipt = _validate()
    except (
        ClosureAuditError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
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
