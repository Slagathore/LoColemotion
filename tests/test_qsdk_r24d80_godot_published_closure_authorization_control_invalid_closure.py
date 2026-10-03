#!/usr/bin/env python3
"""Audit the retained pre-physics R80 publication-control failure."""

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
)

CLOSURE = ROOT / (
    "sdk/recovery/r24d80_godot_published_closure_"
    "authorization_control_invalid_closure_v1.json"
)
CONTRACT = ROOT / (
    "sdk/recovery/r24d80_godot_jolt_guarded_command_recovery_behavior_"
    "contract_v1.json"
)
QUALIFICATION = ROOT / (
    "sdk/recovery/r24d80_godot_jolt_guarded_command_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
CONTROL = "47d1ba2546154007e091b03a39f9cf82ff3a7c6c"
FREEZE = "3c3ff33649f0e718de7db1af8b97dacf7b6a95b3"
STATUS = (
    "closed_consumed_invalid_incomplete_published_closure_control_"
    "qualified_physical_path_role_conflict"
)
LIVE_PATHS = (
    "sdk/release/quadruped_release_contract.json",
    "sdk/release/quadruped_support_matrix.json",
)


def main() -> None:
    closure = json.loads(CLOSURE.read_text(encoding="utf-8"))
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    qualification = json.loads(QUALIFICATION.read_text(encoding="utf-8"))
    verify_exact_paths(
        closure,
        {
            "schema_version": (
                "sporespore_qsdk_r24d80_godot_published_closure_"
                "authorization_control_invalid_closure_v1"
            ),
            "gate_id": "QSDK-R24D80",
            "closure_status": STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": (
                "published_closure_authorization_control_invalid_closure"
            ),
            "ledger_scope.question_class": "development",
            "physical_question_declared": True,
            "source.control_commit": CONTROL,
            "source.source_freeze_commit": FREEZE,
            "attempt.invocation_count": 1,
            "attempt.mode": "AuthorizationControl",
            "attempt.run_physical_switch_present": False,
            "attempt.process_exit_code": 1,
            "attempt.failure_code": "qualified_physical_source_drift",
            "attempt.preflight_returned_before_failure": True,
            "attempt.preflight_receipt_retained": False,
            "attempt.authorization_control_id_allocated": False,
            "attempt.authorization_control_receipt_retained": False,
            "attempt.authorization_control_evidence_root_created": False,
            "attempt.same_identity_rerun_permitted": False,
            "source_drift_observation.qualified_physical_path_count": 61,
            "source_drift_observation.changed_qualified_physical_path_count": 2,
            "source_drift_observation.changed_qualified_physical_paths": list(LIVE_PATHS),
            "source_drift_observation.unexpected_physical_semantics_change_count": 0,
            "source_drift_observation.required_publication_delta_made_authorization_predicate_unsatisfiable": True,
            "physical_counts.model_construction_count": 0,
            "physical_counts.world_attempt_count": 0,
            "physical_counts.world_build_count": 0,
            "physical_counts.solver_step_count": 0,
            "physical_counts.physical_execution_count": 0,
            "physical_counts.physics_state_modified": False,
            "decision.r80_authorization_control_attempt_consumed": True,
            "decision.r80_campaign_closed_without_physical_execution": True,
            "decision.r80_physical_attempt_consumed": False,
            "decision.r80_physical_execution_authorized": False,
            "decision.distinct_successor_required": True,
            "decision.same_identity_rerun_permitted": False,
            "decision.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "next_boundary.gate_id": "QSDK-R24D81",
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_physical_steps_authorized": 0,
            "claim_boundary.r80_zero_world_qualification_preserved_positive": True,
            "claim_boundary.r80_published_closure_authorization_control_passed": False,
            "claim_boundary.r80_physical_attempted": False,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "CLOSURE",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%H", CONTROL),
        CONTROL,
        "CONTROL_COMMIT",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%P", CONTROL),
        FREEZE,
        "CONTROL_PARENT",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%T", CONTROL),
        closure["source"]["tree"],
        "CONTROL_TREE",
    )
    exact(
        git(ROOT, "show", "-s", "--format=%s", CONTROL),
        closure["source"]["subject"],
        "CONTROL_SUBJECT",
    )
    for name in ("qualification_closure", "contract", "shared_supervisor"):
        binding = closure["source"][name]
        raw = git(ROOT, "show", f"{CONTROL}:{binding['path']}", text=False)
        assert isinstance(raw, bytes)
        exact(len(raw), binding["byte_length"], f"{name}:BYTE_LENGTH")
        exact(sha256(raw), binding["raw_sha256"], f"{name}:SHA256")
        exact(
            git(ROOT, "rev-parse", f"{CONTROL}:{binding['path']}"),
            binding["git_blob_oid"],
            f"{name}:BLOB",
        )

    qualified = tuple(contract["qualified_physical_paths"])
    exact(len(qualified), 61, "QUALIFIED_PATH_COUNT")
    exact(tuple(qualification["live_authority_paths"]), LIVE_PATHS, "LIVE_PATHS")
    exact(all(path in qualified for path in LIVE_PATHS), True, "ROLE_CONFLICT")
    changed_raw = git(
        ROOT, "diff", "--name-only", FREEZE, CONTROL, "--", *qualified
    )
    assert isinstance(changed_raw, str)
    changed = tuple(line for line in changed_raw.splitlines() if line)
    exact(changed, LIVE_PATHS, "CHANGED_QUALIFIED_PATHS")
    physical_only = tuple(path for path in qualified if path not in LIVE_PATHS)
    physical_drift = git(
        ROOT, "diff", "--name-only", FREEZE, CONTROL, "--", *physical_only
    )
    exact(physical_drift, "", "PHYSICAL_SEMANTICS_DRIFT")

    supervisor_raw = git(
        ROOT,
        "show",
        f"{CONTROL}:{closure['source']['shared_supervisor']['path']}",
        text=False,
    )
    assert isinstance(supervisor_raw, bytes)
    supervisor = supervisor_raw.decode("utf-8")
    control_body = supervisor.split(
        "function Invoke-R57AuthorizationControl", 1
    )[1].split("function Invoke-R57Physical", 1)[0]
    exact(
        control_body.index("$preflight = Invoke-R57Preflight")
        < control_body.index("$authorization = Get-R57Authorization")
        < control_body.index("$controlId = [guid]::NewGuid()"),
        True,
        "FAILURE_ORDER",
    )
    exact("finally {" in control_body, True, "LOCK_FINALLY")
    exact(
        "Exit-SporeSporeLocomotionOperationLock -Receipt $lock" in control_body,
        True,
        "LOCK_RELEASE_CONTROL_FLOW",
    )
    exact(
        Path(closure["attempt"]["expected_authorization_control_evidence_root"])
        .exists(),
        False,
        "NO_CONTROL_EVIDENCE_ROOT",
    )

    expected = {
        "r24d80_source_status": STATUS,
        "r24d80_published_closure_authorization_control_executed": True,
        "r24d80_published_closure_authorization_control_passed": False,
        "r24d80_authorization_control_attempt_count": 1,
        "r24d80_authorization_control_attempt_consumed": True,
        "r24d80_authorization_control_source_commit": CONTROL,
        "r24d80_authorization_control_failure_code": (
            "qualified_physical_source_drift"
        ),
        "r24d80_authorization_control_receipt_retained": False,
        "r24d80_changed_qualified_physical_path_count": 2,
        "r24d80_changed_qualified_physical_paths": list(LIVE_PATHS),
        "r24d80_publication_only_path_role_conflict": True,
        "r24d80_campaign_closed_without_physical_execution": True,
        "r24d81_distinct_successor_required": True,
        "r24d80_model_construction_count": 0,
        "r24d80_world_attempt_count": 0,
        "r24d80_world_build_count": 0,
        "r24d80_solver_step_count": 0,
        "r24d80_physical_execution_authorized": False,
        "r24d80_physical_attempt_consumed": False,
        "r24d80_physical_execution_blocked": True,
        "physical_execution_blocked_until_r24d80_published_closure_control": True,
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
        records = records_with_key(authority, "r24d80_authorization_control_attempt_count")
        exact(len(records), 1, f"LIVE_RECORD_COUNT:{authority_path}")
        record = records[0]
        exact(
            {key: record[key] for key in expected},
            expected,
            f"LIVE_PROJECTION:{authority_path}",
        )
        exact(
            record["r24d80_authorization_control_invalid_closure_raw_sha256"],
            sha256(closure_blob),
            f"LIVE_CLOSURE_HASH:{authority_path}",
        )
        exact(
            record["r24d80_authorization_control_invalid_closure_byte_length"],
            len(closure_blob),
            f"LIVE_CLOSURE_LENGTH:{authority_path}",
        )
    print(
        "QSDK_R24D80_GODOT_PUBLISHED_CLOSURE_AUTHORIZATION_CONTROL_INVALID_"
        "CLOSURE_PASS attempts=1 failure=qualified_physical_source_drift "
        "changed_paths=2 publication_only=2 models=0 worlds=0 steps=0 "
        "next=R24D81 sdk1=11/20"
    )


if __name__ == "__main__":
    main()
