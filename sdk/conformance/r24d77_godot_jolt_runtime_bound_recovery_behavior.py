#!/usr/bin/env python3
"""Compact R77 production-runtime binding audit and zero-world preflight."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import godot_recovery_route_zero_world_controls as controls  # noqa: E402
from sdk.conformance import r24d70_godot_behavior_receipt_acceptance as r70  # noqa: E402
from sdk.conformance import r24d76_godot_jolt_solved_contact_recovery_behavior as r76  # noqa: E402
from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    git,
    load,
    records_with_key,
    require,
    resolve_prospective_source_freeze,
    sha256,
    source_bytes,
    verify_declared_source_inventory,
    verify_exact_paths,
)

CONTRACT = ROOT / (
    "sdk/recovery/r24d77_godot_jolt_runtime_bound_recovery_"
    "behavior_contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d77_godot_jolt_runtime_bound_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
PREDECESSOR = ROOT / (
    "sdk/recovery/r24d76_godot_jolt_solved_contact_recovery_behavior_"
    "incomplete_closure_v1.json"
)
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d77_godot_jolt_runtime_bound_recovery_behavior.ps1"
)
QUALIFICATION_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d77_godot_jolt_runtime_bound_recovery_behavior_"
    "zero_world_qualification.ps1"
)
SHARED_SUPERVISOR = ROOT / (
    "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
)
BEHAVIOR_WORKER = ROOT / (
    "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
NATIVE_WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
SOURCE_MARKER = (
    "QSDK_R24D77_GODOT_JOLT_RUNTIME_BOUND_RECOVERY_BEHAVIOR_SOURCE_PASS"
)
SUPERVISOR_MARKER = (
    "QSDK_R24D77_RUNTIME_BOUND_RECOVERY_BEHAVIOR_SUPERVISOR "
)
RUNTIME_IDENTITY_SCHEMA = (
    "sporespore_qsdk_r24d77_runtime_identity_control_v1"
)


def _contains(path: Path, *markers: str) -> None:
    value = path.read_text(encoding="utf-8")
    require(
        all(marker in value for marker in markers),
        f"MARKERS:{path.relative_to(ROOT).as_posix()}",
    )


def _verify_predecessor(contract: dict[str, Any]) -> None:
    predecessors = contract["bound_predecessors"]
    exact(len(predecessors), 1, "PREDECESSOR_COUNT")
    predecessor = predecessors[0]
    raw = source_bytes(
        ROOT, predecessor["closure_commit"], predecessor["path"]
    )
    exact(
        (len(raw), sha256(raw)),
        (predecessor["byte_length"], predecessor["raw_sha256"]),
        "PREDECESSOR_CONTENT",
    )
    exact(
        git(
            ROOT,
            "rev-parse",
            f"{predecessor['closure_commit']}:{predecessor['path']}",
        ),
        predecessor["git_blob_oid"],
        "PREDECESSOR_BLOB",
    )
    value = json.loads(raw)
    verify_exact_paths(
        value,
        {
            "closure_status": predecessor["closure_status"],
            "physical_attempt.model_construction_attempt_count": 0,
            "physical_attempt.world_attempt_count": 0,
            "physical_attempt.solver_step_count": 0,
            "physical_attempt.physics_state_modified": False,
            "runtime_binding_diagnosis.wrapper_forwarded_console_path": False,
            "runtime_binding_diagnosis.wrapper_forwarded_expected_console_sha256": False,
            "runtime_binding_diagnosis.wrapper_forwarded_expected_console_byte_length": False,
            "runtime_binding_diagnosis.failure_occurred_before_model_construction": True,
            "decision.same_identity_rerun_permitted": False,
            "decision.scientific_positive_observed": False,
            "decision.scientific_negative_observed": False,
        },
        "R76",
    )


def validate_sources() -> tuple[dict[str, Any], dict[str, int]]:
    contract = load(CONTRACT)
    verify_exact_paths(
        contract,
        {
            "schema_version": (
                "sporespore_qsdk_r24d77_godot_jolt_runtime_bound_"
                "recovery_behavior_contract_v1"
            ),
            "gate_id": "QSDK-R24D77",
            "status": (
                "prospective_complete_zero_world_qualification_required_"
                "physics_blocked"
            ),
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": True,
            "controlled_change.production_wrapper_binds_console_path": True,
            "controlled_change.production_wrapper_binds_console_sha256": True,
            "controlled_change.production_wrapper_binds_console_byte_length": True,
            "controlled_change.selected_runtime_identity_added_to_shared_preflight_receipt": True,
            "controlled_change.portable_recovery_controller_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "controlled_change.behavior_worker_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.physical_envelope_changed_from_r76": False,
            "complete_zero_world_gate.current_worker_count": 7,
            "complete_zero_world_gate.production_wrapper_runtime_identity_control_count": 1,
            "complete_zero_world_gate.physical_execution_authorized": False,
            "physical_authorization_projection.seed": 278151771,
            "physical_authorization_projection.maximum_world_build_count": 2,
            "physical_authorization_projection.maximum_outer_solver_steps": 2400,
            "physical_authorization_projection.behavior_evaluator_invocation_count": 1,
            "physical_runner.selected_runtime_binding_argument_count": 3,
            "authorization_boundary.maximum_physical_steps_authorized": 0,
        },
        "CONTRACT",
    )
    _verify_predecessor(contract)

    runtime = contract["exact_runtime"]
    for prefix in ("console", "engine"):
        path = Path(runtime[f"{prefix}_path"])
        require(path.is_file(), f"RUNTIME_MISSING:{prefix}")
        exact(
            (path.stat().st_size, sha256(path.read_bytes())),
            (runtime[f"{prefix}_byte_length"], runtime[f"{prefix}_sha256"]),
            f"RUNTIME_CONTENT:{prefix}",
        )

    source_inventory = contract["source_inventory"]
    physical_paths = contract["qualified_physical_paths"]
    authored_paths = contract["authored_source_paths"]
    verify_declared_source_inventory(ROOT, source_inventory)
    verify_declared_source_inventory(ROOT, physical_paths)
    verify_declared_source_inventory(ROOT, authored_paths)
    require(
        set(physical_paths).issubset(set(source_inventory)),
        "PHYSICAL_PATHS_NOT_SOURCE_SUBSET",
    )
    exact(
        len(source_inventory),
        contract["critical_path_audit_policy"]["focused_source_inventory_count"],
        "SOURCE_COUNT",
    )
    exact(
        len(physical_paths),
        contract["critical_path_audit_policy"]["qualified_physical_path_count"],
        "PHYSICAL_PATH_COUNT",
    )

    _source, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=(
            "sporespore_qsdk_r24d77_godot_jolt_runtime_bound_recovery_"
            "behavior_zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D77",
    )
    _contains(
        BEHAVIOR_WORKER,
        'const MAXIMUM_OUTER_STEPS_PER_ARM := 1200',
        'const ARM_ORDER := ["candidate_command", "matched_zero_command"]',
        "RouteScript.evaluate_behavior_v4(",
        '"in_run_invariant_receipt_count": _total_solver_step_count',
    )
    _contains(
        NATIVE_WORLD,
        '"contact_source_receipt": contact_source_receipt',
        '"exact_contact_point_count_int"',
        '"impulse_source_kind": "native_post_solve_contact_constraint_lambda"',
    )
    _contains(
        SHARED_SUPERVISOR,
        '"RuntimeIdentity"',
        "function Invoke-R57RuntimeIdentity",
        "selected_console_path = $consolePath.Replace",
        "selected_console_sha256 = Get-R57Sha $consolePath",
        "selected_console_byte_length = (Get-Item -LiteralPath $consolePath).Length",
    )
    _contains(
        PHYSICAL_RUNNER,
        'GateId = "QSDK-R24D77"',
        "ConsolePath = [string]$contract.exact_runtime.console_path",
        "ExpectedConsoleSha256 = [string]$contract.exact_runtime.console_sha256",
        "ExpectedConsoleByteLength = [long]$contract.exact_runtime.console_byte_length",
        'RuntimeIdentitySchema =',
        "MaximumOuterSolverSteps = 2400",
        "ExpectedBehaviorEvaluatorInvocationCount = 1",
    )
    _contains(
        QUALIFICATION_RUNNER,
        "run_qsdk_core_zero_world_qualification.ps1",
        'GateId = "QSDK-R24D77"',
        "ProspectivePhysicalQuestionDeclared = $true",
    )

    permanent_live = {
        "r24d77_distinct_successor_required": True,
        "r24d77_question_class": "development",
        "r24d77_physical_question_declared": True,
        "r24d77_runtime_bound_recovery_behavior_declared": True,
        "r24d77_contract_path": (
            "sdk/recovery/r24d77_godot_jolt_runtime_bound_recovery_"
            "behavior_contract_v1.json"
        ),
        "r24d77_bound_r24d76_incomplete_closure_path": (
            "sdk/recovery/r24d76_godot_jolt_solved_contact_recovery_"
            "behavior_incomplete_closure_v1.json"
        ),
        "r24d77_runtime_binding_argument_count": 3,
        "r24d77_runtime_identity_control_required": True,
        "r24d77_portable_recovery_controller_changed": False,
        "r24d77_behavior_threshold_changed": False,
        "r24d77_full_paired_behavior_route_declared": True,
        "r24d77_additional_physical_canary_required": False,
        "r24d77_source_inventory_count": len(source_inventory),
        "r24d77_qualified_physical_path_count": len(physical_paths),
        "r24d77_development_zero_world_qualification_passed": True,
    }
    prospective_live = {
        "next_gate_id": "QSDK-R24D77",
        "r24d77_source_status": (
            "prospective_runtime_bound_recovery_behavior_complete_zero_world_"
            "qualification_required_physics_blocked"
        ),
        "r24d77_zero_world_qualification_pending": True,
        "r24d77_zero_world_qualified": False,
        "r24d77_physical_execution_authorized": False,
        "r24d77_physical_attempt_consumed": False,
        "physical_execution_blocked_pending_r24d77_declaration_and_zero_world_qualification": True,
        "physical_execution_blocked_until_r24d77_zero_world_qualification": True,
    }
    for relative in (
        "sdk/release/quadruped_release_contract.json",
        "sdk/release/quadruped_support_matrix.json",
    ):
        value = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(
            value, "r24d77_runtime_bound_recovery_behavior_declared"
        )
        exact(len(records), 1, f"LIVE_RECORD:{relative}")
        verify_exact_paths(records[0], permanent_live, f"LIVE_PERMANENT:{relative}")
        if not published:
            verify_exact_paths(records[0], prospective_live, f"LIVE_PROSPECTIVE:{relative}")

    return contract, {
        "focused_source_inventory_count": len(source_inventory),
        "authored_source_path_count": len(authored_paths),
        "qualified_physical_path_count": len(physical_paths),
        "bound_predecessor_count": 1,
        "current_zero_world_worker_count": 7,
        "production_wrapper_runtime_identity_control_count": 1,
        "historical_closure_audits_executed_count": 0,
        "bespoke_campaign_source_audit_mechanics_added_count": 0,
        "additional_physical_canary_count": 0,
    }


def _one_marker(stdout: str, marker: str) -> dict[str, Any]:
    lines = [line for line in stdout.splitlines() if line.startswith(marker)]
    exact(len(lines), 1, "RUNTIME_IDENTITY_MARKER_COUNT")
    value = json.loads(lines[0][len(marker) :])
    require(isinstance(value, dict), "RUNTIME_IDENTITY_RECEIPT")
    return value


def _run_runtime_identity(contract: dict[str, Any]) -> dict[str, Any]:
    completed = subprocess.run(
        [
            "pwsh",
            "-NoLogo",
            "-NoProfile",
            "-File",
            str(PHYSICAL_RUNNER),
            "-Mode",
            "RuntimeIdentity",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="strict",
        check=False,
    )
    require(
        completed.returncode == 0,
        f"RUNTIME_IDENTITY_EXIT:{completed.returncode}:{completed.stdout}:{completed.stderr}",
    )
    require(completed.stderr == "", f"RUNTIME_IDENTITY_STDERR:{completed.stderr}")
    receipt = _one_marker(completed.stdout, SUPERVISOR_MARKER)
    runtime = contract["exact_runtime"]
    verify_exact_paths(
        receipt,
        {
            "schema_version": RUNTIME_IDENTITY_SCHEMA,
            "gate_id": "QSDK-R24D77",
            "ok": True,
            "selected_console_path": runtime["console_path"],
            "selected_console_sha256": runtime["console_sha256"],
            "selected_console_byte_length": runtime["console_byte_length"],
            "worker_relative_path": (
                "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
            ),
            "worker_parse_count": 1,
            "source_audit_execution_count": 0,
            "physics_state_modified": False,
            "physical_execution_authorized": False,
        },
        "RUNTIME_IDENTITY",
    )
    controls.require_zero_authority(receipt)
    return receipt


def run_preflight(core_library: Path) -> dict[str, Any]:
    contract, counts = validate_sources()
    require(core_library.is_file(), "CORE_LIBRARY_MISSING")
    runtime_identity = _run_runtime_identity(contract)
    executable = Path(contract["exact_runtime"]["console_path"])
    specs = tuple(r70.WORKER_SPECS) + (r76.CONTACT_SPEC,)
    receipts = controls.run_zero_world_worker_specs(ROOT, executable, specs)
    r70_receipt = receipts["r70_receipt_acceptance"]
    require(
        r70_receipt["ordered_acceptance_receipts"][1]["scientific_outcome"]
        == "negative"
        and r70_receipt["full_summary"]["completed_arm_count"] == 2,
        "R70_CURRENT_BEHAVIOR_RECEIPT",
    )
    r75_receipt = receipts["r75_contact_source_retention"]
    require(
        r75_receipt["populated_exact_contact_point_count"] == 8
        and r75_receipt["zero_exact_contact_point_count"] == 0
        and r75_receipt["canonical_digest_recompute_count"] == 2,
        "R75_CURRENT_CONTACT_RECEIPT",
    )
    projection = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D77"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D77",
        "sporespore_qsdk_r24d77_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": (
            "sporespore_qsdk_r24d77_godot_jolt_runtime_bound_recovery_"
            "behavior_preflight_v1"
        ),
        "gate_id": "QSDK-R24D77",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["collector_id"],
        "runtime_version": contract["exact_runtime"]["runtime_profile_id"],
        **counts,
        **{f"{key}_receipt": value for key, value in receipts.items()},
        "production_wrapper_runtime_identity_receipt": runtime_identity,
        "supervisor_projection_receipt": projection,
        "missing_physical_switch_refusal_receipt": refusal,
        "behavior_worker_parse_count": 1,
        "supervisor_forced_failure_control_count": 1,
        "missing_physical_switch_refusal_count": 1,
        "native_runtime_observation_collection_executed": False,
        "held_out_cell_access_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_question_opened": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    if args.core_library is None:
        _contract, counts = validate_sources()
        print(
            SOURCE_MARKER,
            " ".join(f"{key}={value}" for key, value in counts.items()),
        )
    else:
        print(
            json.dumps(
                run_preflight(args.core_library.resolve()),
                allow_nan=False,
                separators=(",", ":"),
                sort_keys=True,
            )
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(
            "QSDK_R24D77_GODOT_JOLT_RUNTIME_BOUND_RECOVERY_BEHAVIOR_FAIL "
            f"{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
