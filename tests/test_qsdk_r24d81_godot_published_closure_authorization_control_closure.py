#!/usr/bin/env python3
"""Audit the one exact R81 post-publication authorization control."""

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
    records_with_key,
    sha256,
    verify_exact_paths,
    verify_published_closure_authorization_control,
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d81_godot_published_closure_"
    "authorization_control_closure_v1.json"
)
CONTRACT_PATH = (
    "sdk/recovery/r24d81_godot_jolt_guarded_command_recovery_behavior_"
    "contract_v1.json"
)
SOURCE = "12290ca40de2d4f8d76d96fa096c1be42c179308"
FREEZE = "6abcff4fd2542389c7d741512d265f6e5eb561bb"
STATUS = (
    "closed_published_closure_authorization_control_positive_one_finite_"
    "guarded_command_recovery_pair_authorized"
)
PREDECESSOR_STATUS = (
    "closed_complete_zero_world_guarded_command_recovery_behavior_qualified_"
    "one_paired_development_attempt_authorized_after_publication_control"
)
OMITTED = (
    "maximum_outer_solver_steps_per_arm",
    "behavior_evaluator_invocation_count",
)
PUBLICATION_ONLY = (
    "sdk/release/quadruped_release_contract.json",
    "sdk/release/quadruped_support_matrix.json",
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
                "sporespore_qsdk_r24d81_godot_published_closure_"
                "authorization_control_closure_v1"
            ),
            gate_id="QSDK-R24D81",
            closure_status=STATUS,
            control_commit=SOURCE,
            control_subject=(
                "[recovery/godot] Close R81 zero-world qualification"
            ),
            predecessor_status=PREDECESSOR_STATUS,
            receipt_schema=(
                "sporespore_qsdk_r24d81_published_closure_"
                "authorization_control_v1"
            ),
            preflight_schema="sporespore_qsdk_r24d81_behavior_preflight_v1",
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
            "ledger_scope.question_class": "development",
            "physical_question_declared": False,
            "source.control_commit": SOURCE,
            "source.parent_commit": FREEZE,
            "source.qualified_physical_path_drift_from_source_freeze": False,
            "authorization_control.command_invocation_count": 1,
            "authorization_control.receipt_count": 1,
            "authorization_control.receipt_byte_length": 3595,
            "authorization_control.receipt_raw_sha256": (
                "sha256:d9faf90ca9cfbad7fe29480b9426518ec2594eee22da20d072532a50f5d8ce13"
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
            "source_path_role_control.qualified_physical_path_count": 59,
            "source_path_role_control.qualified_physical_changed_path_count": 0,
            "source_path_role_control.publication_only_path_count": 2,
            "source_path_role_control.publication_only_changed_path_count": 2,
            "source_path_role_control.publication_only_changed_paths": list(
                PUBLICATION_ONLY
            ),
            "source_path_role_control.path_role_overlap_count": 0,
            "source_path_role_control.required_closure_publication_delta_accepted": True,
            "decision.result": (
                "positive_exact_published_r81_closure_loaded_by_production_"
                "supervisor_at_zero_world"
            ),
            "decision.seed": 278151771,
            "decision.maximum_model_construction_count": 2,
            "decision.maximum_world_build_count": 2,
            "decision.maximum_outer_solver_steps": 2400,
            "decision.behavior_evaluator_invocation_count": 1,
            "decision.physical_execution_authorized": True,
            "decision.physical_attempted": False,
            "decision.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "next_boundary.gate_id": "QSDK-R24D81",
            "next_boundary.authorized_world_count": 2,
            "next_boundary.maximum_physical_steps_authorized": 2400,
            "next_boundary.same_source_physical_attempt_limit": 1,
            "next_boundary.same_identity_rerun_permitted": False,
            "next_boundary.physical_execution_authorized": True,
            "claim_boundary.path_role_partition_exactly_preserved": True,
            "claim_boundary.qualified_physical_source_drift_absent": True,
            "claim_boundary.required_publication_only_delta_permitted": True,
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
    publication_only = tuple(contract["source_path_roles"]["publication_only_paths"])
    exact(len(qualified), 59, "QUALIFIED_PATH_COUNT")
    exact(publication_only, PUBLICATION_ONLY, "PUBLICATION_ONLY_PATHS")
    exact(set(qualified).intersection(publication_only), set(), "PATH_ROLE_OVERLAP")
    physical_drift = git(
        ROOT, "diff", "--name-only", FREEZE, SOURCE, "--", *qualified
    )
    exact(physical_drift, "", "QUALIFIED_PHYSICAL_DRIFT")
    publication_drift_raw = git(
        ROOT, "diff", "--name-only", FREEZE, SOURCE, "--", *publication_only
    )
    assert isinstance(publication_drift_raw, str)
    exact(
        tuple(line for line in publication_drift_raw.splitlines() if line),
        PUBLICATION_ONLY,
        "PUBLICATION_ONLY_DRIFT",
    )

    expected = {
        "r24d81_source_status": STATUS,
        "r24d81_published_closure_authorization_control_executed": True,
        "r24d81_published_closure_authorization_control_passed": True,
        "r24d81_authorization_control_attempt_count": 1,
        "r24d81_authorization_control_source_commit": SOURCE,
        "r24d81_authorization_control_id": "4c75a265a82548bbab52b65806c164c3",
        "r24d81_authorization_control_receipt_raw_sha256": (
            "sha256:d9faf90ca9cfbad7fe29480b9426518ec2594eee22da20d072532a50f5d8ce13"
        ),
        "r24d81_authorization_control_receipt_byte_length": 3595,
        "r24d81_qualified_physical_source_drift_absent": True,
        "r24d81_required_publication_only_delta_permitted": True,
        "r24d81_model_construction_count": 0,
        "r24d81_world_attempt_count": 0,
        "r24d81_world_build_count": 0,
        "r24d81_solver_step_count": 0,
        "r24d81_physical_execution_authorized": True,
        "r24d81_physical_attempt_consumed": False,
        "r24d81_physical_execution_blocked": False,
        "physical_execution_blocked_until_r24d81_published_closure_control": False,
    }
    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(
        ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative
    )
    assert isinstance(publication, str)
    if publication:
        closure_blob = git(ROOT, "show", f"{publication}:{relative}", text=False)
    else:
        try:
            closure_blob = git(ROOT, "show", f":{relative}", text=False)
        except subprocess.CalledProcessError:
            closure_blob = CLOSURE.read_bytes()
    assert isinstance(closure_blob, bytes)
    for authority_path in closure["live_authority_paths"]:
        if publication:
            raw = git(ROOT, "show", f"{publication}:{authority_path}", text=False)
            assert isinstance(raw, bytes)
            authority = json.loads(raw)
        else:
            authority = json.loads((ROOT / authority_path).read_text(encoding="utf-8"))
        records = records_with_key(
            authority, "r24d81_published_closure_authorization_control_passed"
        )
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{authority_path}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{authority_path}",
        )
        exact(
            record["r24d81_authorization_control_closure_raw_sha256"],
            sha256(closure_blob),
            f"LIVE_CLOSURE_HASH:{authority_path}",
        )
        exact(
            record["r24d81_authorization_control_closure_byte_length"],
            len(closure_blob),
            f"LIVE_CLOSURE_LENGTH:{authority_path}",
        )
    print(
        "QSDK_R24D81_GODOT_PUBLISHED_CLOSURE_AUTHORIZATION_CONTROL_CLOSURE_"
        "PASS invocations=1 receipts=1 files=1 physical_paths=59 "
        "publication_paths=2 overlap=0 models=0 worlds=0 steps=0 "
        "next=two_worlds_2400_steps sdk1=11/20"
    )


if __name__ == "__main__":
    main()
