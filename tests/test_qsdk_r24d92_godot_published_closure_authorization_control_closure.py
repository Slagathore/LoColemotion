#!/usr/bin/env python3
"""Audit R92's one exact post-publication authorization control."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    git,
    sha256,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
    verify_published_closure_authorization_control,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d92_godot_published_closure_"
    "authorization_control_closure_v1.json"
)
CONTRACT_PATH = (
    "sdk/recovery/r24d92_godot_jolt_force_based_recovery_behavior_"
    "contract_v1.json"
)
SOURCE_AUDIT = (
    "sdk/conformance/r24d92_godot_jolt_force_based_recovery_behavior.py"
)
SOURCE = "c8c8b07ea97107815e2538f51b2123fc19cf52b8"
FREEZE = "dd938b1cc63a8dfb5dd86cfc410203d5ca2a82a1"
STATUS = (
    "closed_published_closure_authorization_control_positive_one_finite_"
    "future_state_stable_recovery_pair_authorized"
)
PREDECESSOR_STATUS = (
    "closed_complete_zero_world_future_state_stable_recovery_behavior_"
    "qualified_one_finite_paired_development_attempt_authorized_after_"
    "publication_control"
)
OMITTED = (
    "maximum_outer_solver_steps_per_arm",
    "behavior_evaluator_invocation_count",
)
CHANGED_PATHS = (
    "docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
    "docs/README.md",
    "docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
    (
        "sdk/recovery/r24d92_godot_jolt_force_based_recovery_behavior_"
        "zero_world_qualification_closure_v1.json"
    ),
    "sdk/release/quadruped_release_contract.json",
    "sdk/release/quadruped_support_matrix.json",
    (
        "tests/test_qsdk_r24d92_godot_jolt_force_based_recovery_behavior_"
        "zero_world_qualification_closure.py"
    ),
)
CONSOLE_PATH = (
    "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/"
    "qsdk-r24d71-godot-solved-contact-telemetry/development-runtime-v3/"
    "19dc32b39400-b20323fd08a7/"
    "godot.windows.editor.dev.x86_64.console.exe"
)
CONSOLE_SHA256 = (
    "sha256:19dc32b39400d200b5e5273f541ac41aa72a82110bb2fd338726a7fd465e0fa8"
)


def main() -> None:
    closure, predecessor, receipt = (
        verify_published_closure_authorization_control(
            root=ROOT,
            closure_path=CLOSURE,
            schema_version=(
                "sporespore_qsdk_r24d92_godot_published_closure_"
                "authorization_control_closure_v1"
            ),
            gate_id="QSDK-R24D92",
            closure_status=STATUS,
            control_commit=SOURCE,
            control_subject=(
                "[recovery/core] Close R92 qualification: authorize "
                "publication control"
            ),
            predecessor_status=PREDECESSOR_STATUS,
            receipt_schema=(
                "sporespore_qsdk_r24d92_published_closure_"
                "authorization_control_v1"
            ),
            preflight_schema="sporespore_qsdk_r24d92_behavior_preflight_v1",
            projection_omitted_fields=OMITTED,
        )
    )
    verify_exact_paths(
        closure,
        {
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": (
                "published_closure_authorization_control"
            ),
            "source.control_commit": SOURCE,
            "source.parent_commit": FREEZE,
            "source.qualified_physical_path_drift_from_source_freeze": False,
            "authorization_control.command_invocation_count": 1,
            "authorization_control.receipt_count": 1,
            "authorization_control.receipt_byte_length": 3684,
            "authorization_control.receipt_raw_sha256": (
                "sha256:7ab979607eef7216f882f9e63617a5209c0814239e05cb338a9f737c7b58d8e4"
            ),
            "authorization_control.source_audit_and_runtime_preflight_count": 1,
            "authorization_control.worker_parse_count": 1,
            "authorization_control.operation_lock_acquired": True,
            "authorization_control.operation_lock_released": True,
            "authorization_control.model_construction_count": 0,
            "authorization_control.world_attempt_count": 0,
            "authorization_control.world_build_count": 0,
            "authorization_control.solver_step_count": 0,
            "authorization_control.physical_execution_count": 0,
            "source_path_role_control.qualified_physical_path_count": 47,
            "source_path_role_control.qualified_physical_changed_path_count": 0,
            "source_path_role_control.publication_only_path_count": 16,
            "source_path_role_control.future_publication_only_path_count": 4,
            "source_path_role_control.declared_publication_path_count": 20,
            "source_path_role_control.publication_changed_path_count": 7,
            "source_path_role_control.publication_changed_paths": list(CHANGED_PATHS),
            "source_path_role_control.path_role_overlap_count": 0,
            "source_path_role_control.all_changed_paths_declared_publication_only": True,
            "source_path_role_control.qualified_physical_source_drift_absent": True,
            "decision.result": (
                "positive_exact_published_r92_closure_loaded_by_production_"
                "supervisor_at_zero_world"
            ),
            "decision.seed": 278151771,
            "decision.maximum_model_construction_count": 2,
            "decision.maximum_world_build_count": 2,
            "decision.maximum_outer_solver_steps": 2400,
            "decision.behavior_evaluator_invocation_count": 1,
            "decision.one_finite_future_state_stable_recovery_pair_authorized": True,
            "decision.physical_execution_authorized": True,
            "decision.physical_attempted": False,
            "decision.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "next_boundary.gate_id": "QSDK-R24D92",
            "next_boundary.authorized_world_count": 2,
            "next_boundary.maximum_physical_steps_authorized": 2400,
            "next_boundary.same_source_physical_attempt_limit": 1,
            "next_boundary.same_identity_rerun_permitted": False,
            "next_boundary.physical_execution_authorized": True,
            "claim_boundary.future_state_stable_source_preflight_passed_with_one_retained_control": True,
            "claim_boundary.physical_execution_authorized": True,
            "claim_boundary.physical_attempted": False,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "CLOSURE",
    )

    source_projection = predecessor["physical_authorization"]
    normalized_projection = receipt["authorization"]["projection"]
    verify_exact_paths(
        closure["projection_normalization"],
        {
            "source_authorization_field_count": len(source_projection),
            "normalized_projection_field_count": len(normalized_projection),
            "exactly_omitted_fields": list(OMITTED),
            "exactly_omitted_values.maximum_outer_solver_steps_per_arm": 1200,
            "exactly_omitted_values.behavior_evaluator_invocation_count": 1,
            "all_other_fields_exactly_matched": True,
            "projection_authority_weakened": False,
        },
        "PROJECTION_NORMALIZATION",
    )
    exact(
        {key: value for key, value in source_projection.items() if key not in OMITTED},
        normalized_projection,
        "NORMALIZED_PROJECTION_BINDING",
    )
    verify_exact_paths(
        receipt,
        {
            "preflight.selected_console_path": CONSOLE_PATH,
            "preflight.selected_console_sha256": CONSOLE_SHA256,
            "preflight.selected_console_byte_length": 293376,
            "preflight.worker_parse_count": 1,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_execution_count": 0,
            "next_physical_invocation_authorized": True,
        },
        "RECEIPT",
    )

    contract_raw = git(ROOT, "show", f"{SOURCE}:{CONTRACT_PATH}", text=False)
    assert isinstance(contract_raw, bytes)
    contract = json.loads(contract_raw)
    qualified = tuple(contract["qualified_physical_paths"])
    publication = tuple(contract["source_path_roles"]["publication_only_paths"])
    future_publication = tuple(
        contract["source_path_roles"]["future_publication_only_paths"]
    )
    declared_publication = tuple(dict.fromkeys((*publication, *future_publication)))
    exact(len(qualified), 47, "QUALIFIED_PATH_COUNT")
    exact(len(publication), 16, "PUBLICATION_PATH_COUNT")
    exact(len(future_publication), 4, "FUTURE_PUBLICATION_PATH_COUNT")
    exact(len(declared_publication), 20, "DECLARED_PUBLICATION_PATH_COUNT")
    exact(set(qualified).intersection(declared_publication), set(), "PATH_ROLE_OVERLAP")
    exact(
        git(ROOT, "diff", "--name-only", FREEZE, SOURCE, "--", *qualified),
        "",
        "QUALIFIED_PHYSICAL_DRIFT",
    )
    changed_raw = git(ROOT, "diff", "--name-only", FREEZE, SOURCE)
    assert isinstance(changed_raw, str)
    changed = tuple(line for line in changed_raw.splitlines() if line)
    exact(changed, CHANGED_PATHS, "PUBLICATION_DRIFT")
    exact(set(changed).issubset(declared_publication), True, "DECLARED_PUBLICATION")

    source_check = subprocess.run(
        [sys.executable, SOURCE_AUDIT],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="strict",
        check=False,
    )
    exact(source_check.returncode, 0, "ONE_RECEIPT_SOURCE_AUDIT_EXIT")
    exact(source_check.stderr, "", "ONE_RECEIPT_SOURCE_AUDIT_STDERR")
    marker = "QSDK_R24D92_GODOT_JOLT_FORCE_BASED_RECOVERY_BEHAVIOR_SOURCE_PASS"
    exact(source_check.stdout.count(marker), 1, "ONE_RECEIPT_SOURCE_AUDIT_MARKER")

    live_expected = {
        "r24d92_published_authorization_control_pending": False,
        "r24d92_published_authorization_control_passed": True,
        "r24d92_published_closure_authorization_control_executed": True,
        "r24d92_authorization_control_attempt_count": 1,
        "r24d92_authorization_control_source_commit": SOURCE,
        "r24d92_authorization_control_id": "2539f7519d024204b377774dc30c050a",
        "r24d92_authorization_control_receipt_raw_sha256": (
            "sha256:7ab979607eef7216f882f9e63617a5209c0814239e05cb338a9f737c7b58d8e4"
        ),
        "r24d92_authorization_control_receipt_byte_length": 3684,
        "r24d92_authorization_control_closure_path": CLOSURE.relative_to(
            ROOT
        ).as_posix(),
        "r24d92_authorization_control_closure_raw_sha256": sha256(
            CLOSURE.read_bytes()
        ),
        "r24d92_authorization_control_closure_byte_length": CLOSURE.stat().st_size,
        "r24d92_qualified_physical_source_drift_absent": True,
        "r24d92_required_publication_only_delta_permitted": True,
        "r24d92_future_state_stable_one_receipt_preflight_passed": True,
        "physical_execution_blocked_until_r24d92_published_authorization_control": False,
    }
    verify_legacy_live_authority_projection(
        ROOT,
        closure["live_authority_paths"],
        record_key="r24d92_contract_path",
        expected=live_expected,
        prefix="LIVE_R92_CONTROL",
    )
    print(
        "QSDK_R24D92_GODOT_PUBLISHED_CLOSURE_AUTHORIZATION_CONTROL_CLOSURE_"
        "PASS invocations=1 receipts=1 physical_paths=47 publication_paths=20 "
        "changed_publication_paths=7 models=0 worlds=0 steps=0 "
        "next=two_worlds_2400_steps sdk1=11/20"
    )


if __name__ == "__main__":
    main()
