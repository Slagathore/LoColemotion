#!/usr/bin/env python3
"""Audit the publication-stable R115 zero-world qualification closure."""

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

SOURCE_COMMIT = "70b41bf54d7469f246ce8ba5a33f269c9dc82e39"
CLOSURE_RELATIVE_PATH = (
    "sdk/recovery/r24d115_godot_jolt_publication_stable_mirrored_front_knee_"
    "recovery_behavior_zero_world_qualification_closure_v1.json"
)
CLOSURE = ROOT / CLOSURE_RELATIVE_PATH
CLOSURE_SCHEMA = (
    "sporespore_qsdk_r24d115_godot_jolt_publication_stable_mirrored_front_"
    "knee_recovery_behavior_zero_world_qualification_closure_v1"
)
QUALIFIED_STATUS = (
    "closed_complete_zero_world_publication_stable_mirrored_front_knee_"
    "recovery_behavior_qualified_one_finite_paired_development_attempt_"
    "authorized"
)
PREDECESSOR_STATUS = (
    "closed_complete_zero_world_mirrored_front_knee_recovery_behavior_"
    "qualified_publication_state_audit_not_reusable_no_physics_authorized_"
    "r115_required"
)
AUDIT_RELATIVE_PATH = (
    "sdk/conformance/r24d115_godot_jolt_publication_stable_mirrored_front_"
    "knee_recovery_behavior_qualification_closure.py"
)
MARKER = (
    "QSDK_R24D115_GODOT_JOLT_PUBLICATION_STABLE_MIRRORED_FRONT_KNEE_"
    "BEHAVIOR_QUALIFICATION_CLOSURE_PASS"
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
            gate_id="QSDK-R24D115",
            closure_status=QUALIFIED_STATUS,
            source_commit=SOURCE_COMMIT,
            source_subject=(
                "[recovery/godot] Freeze R115: stabilize behavior publication"
            ),
            source_binding_names=(
                "source_audit",
                "shared_closure_helper",
                "qualification_runner",
                "physical_runner",
                "shared_physical_supervisor",
                "native_zero_world_test",
                "production_worker",
            ),
            predecessor_status=PREDECESSOR_STATUS,
            attempt_schema=(
                "sporespore_qsdk_r24d115_godot_jolt_publication_stable_"
                "mirrored_front_knee_recovery_behavior_zero_world_attempt_v1"
            ),
            receipt_schema=(
                "sporespore_qsdk_r24d115_godot_jolt_publication_stable_"
                "mirrored_front_knee_recovery_behavior_zero_world_receipt_v1"
            ),
            qualification_directory_prefix=(
                "qsdk-r24d115-godot-jolt-publication-stable-mirrored-front-"
                "knee-recovery-behavior-qualification-"
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
                    "QSDK_R24D115_GODOT_JOLT_PUBLICATION_STABLE_MIRRORED_"
                    "FRONT_KNEE_BEHAVIOR_SOURCE_PASS"
                ),
                "native_zero_world.log": (
                    "SPORESPORE_GODOT_R24D115_PUBLICATION_STABLE_MIRRORED_"
                    "FRONT_KNEE_ZERO_WORLD"
                ),
            },
            physical_question_declared=True,
        )
    )

    require(
        len(contract["source_inventory"])
        == len(set(contract["source_inventory"]))
        == 64,
        "FROZEN_SOURCE_INVENTORY",
    )
    require(
        len(contract["authored_source_paths"])
        == len(set(contract["authored_source_paths"]))
        == 9,
        "AUTHORED_SOURCE_PATHS",
    )
    require(
        len(contract["qualified_physical_paths"])
        == len(set(contract["qualified_physical_paths"]))
        == 50,
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
                "prospective_publication_stable_mirrored_front_knee_recovery_"
                "behavior_complete_zero_world_qualification_required_physics_blocked"
            ),
            "controlled_change.physical_question_semantics_changed": False,
            "controlled_change.recovery_controller_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.seed_value_changed": False,
            "finite_development_population.world_count": 2,
            "finite_development_population.maximum_total_outer_steps": 2400,
            "finite_development_population.same_source_attempt_limit": 1,
            "finite_development_population.same_identity_rerun_permitted": False,
            "behavior_execution_contract.recovery_controller_id": (
                "sporespore_exact_s169_prone_to_standing_controller_v2"
            ),
            "complete_zero_world_gate.phase_aware_source_resolution_count": 1,
            "complete_zero_world_gate.publication_phase_live_projection_count": 1,
            "complete_zero_world_gate.additional_physical_ghost_count": 0,
            "complete_zero_world_gate.additional_physical_canary_count": 0,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "FROZEN_CONTRACT",
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
                "sporespore_qsdk_r24d115_publication_stable_mirrored_front_"
                "knee_behavior_preflight_v1"
            ),
            "ok": True,
            "source_freeze_commit": SOURCE_COMMIT,
            "publication_phase": False,
            "publication_state_resolution_passed": True,
            "source_inventory_count": 64,
            "authored_source_path_count": 9,
            "qualified_physical_path_count": 50,
            "physical_execution_authorized": False,
            "world_attempt_count": 0,
            "solver_step_count": 0,
        },
        "PREFLIGHT_SEMANTICS",
    )
    verify_exact_paths(
        closure,
        {
            "ledger_scope.authority_mode": (
                "closed_complete_zero_world_publication_stable_finite_behavior_"
                "qualification"
            ),
            "qualification.check_count": 12,
            "qualification.checks_passed": 12,
            "qualification.source_inventory_count": 64,
            "qualification.authored_source_path_count": 9,
            "qualification.qualified_physical_path_count": 50,
            "qualification.publication_state_resolution_passed": True,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.additional_physical_ghost_count": 0,
            "qualification.bespoke_physical_canary_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.solver_step_count": 0,
            "publication_transition_projection.phase_aware_source_resolution_passed": True,
            "publication_transition_projection.physical_partition_changed_by_publication": False,
            "decision.physical_question_semantics_changed_from_r24d114": False,
            "decision.publication_state_resolution_qualified": True,
            "decision.physical_execution_authorized": True,
            "decision.authorized_world_count": 2,
            "decision.maximum_outer_solver_steps": 2400,
            "decision.seed": 278151771,
            "physical_authorization.maximum_world_attempt_count": 2,
            "physical_authorization.maximum_outer_solver_steps": 2400,
            "physical_authorization.same_identity_rerun_permitted": False,
            "physical_authorization.physical_execution_authorized": True,
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
    # Qualification identity is immutable, while source status and physical
    # authorization advance when the one-shot result is consumed. The physical
    # closure audit owns those forward-moving live fields.
    live_expected = {
        "r24d115_source_commit": SOURCE_COMMIT,
        "r24d115_zero_world_qualified": True,
        "r24d115_zero_world_qualification_complete": True,
        "r24d115_zero_world_closure_path": CLOSURE_RELATIVE_PATH,
        "r24d115_zero_world_closure_raw_sha256": sha256(closure_raw),
        "r24d115_zero_world_closure_byte_length": len(closure_raw),
        "r24d115_zero_world_evidence_root": closure["qualification"][
            "evidence_root"
        ],
        "r24d115_qualification_attempt_raw_sha256": closure["qualification"][
            "attempt_raw_sha256"
        ],
        "r24d115_qualification_receipt_raw_sha256": closure["qualification"][
            "receipt_raw_sha256"
        ],
        "r24d115_qualification_check_count": 12,
        "r24d115_qualification_checks_passed": 12,
        "r24d115_qualification_model_construction_count": 0,
        "r24d115_qualification_world_attempt_count": 0,
        "r24d115_qualification_world_build_count": 0,
        "r24d115_qualification_solver_step_count": 0,
        "r24d115_qualification_closure_audit_path": AUDIT_RELATIVE_PATH,
        "r24d115_prone_to_standing_claimed": False,
        "r24d115_sdk1_milestone_advanced": False,
        "physical_execution_blocked_until_r24d115_zero_world_qualification": False,
    }
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d115_contract_path",
        expected=live_expected,
        prefix="LIVE_R115_QUALIFICATION",
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
                "world_attempt_count": 0,
                "solver_step_count": 0,
                "physical_execution_authorized": True,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
