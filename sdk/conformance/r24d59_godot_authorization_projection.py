#!/usr/bin/env python3
"""Compact R59 audit composed over R58 plus shared authorization mechanics."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import r24d58_godot_initializer_projection_successor as inherited  # noqa: E402


CONTRACT = ROOT / "sdk/recovery/r24d59_godot_authorization_projection_contract_v1.json"
SHARED_RUNNER = ROOT / "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
BOUND_RUNNER = ROOT / "sdk/run_qsdk_r24d59_godot_native_recovery_route_ghost.ps1"
PROJECTION = ROOT / "sdk/physical_authorization_projection.ps1"
PROJECTION_TEST = ROOT / "tests/test_qsdk_physical_authorization_projection.ps1"
SOURCE_MARKER = "QSDK_R24D59_GODOT_AUTHORIZATION_PROJECTION_SOURCE_PASS"
PROJECTION_MARKER = "QSDK_PHYSICAL_AUTHORIZATION_PROJECTION_ZERO_WORLD "
SUPERVISOR_MARKER = "QSDK_R24D59_GHOST_SUPERVISOR "


class AuthorizationError(RuntimeError):
    """Stable fail-closed R59 error."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuthorizationError(code)


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def markers(path: Path, expected: tuple[str, ...]) -> str:
    source = path.read_text(encoding="utf-8")
    for marker in expected:
        require(marker in source, f"SOURCE_MARKER:{path.relative_to(ROOT)}:{marker}")
    return source


def validate_contract() -> dict[str, Any]:
    contract = load(CONTRACT)
    require(contract["gate_id"] == "QSDK-R24D59", "CONTRACT_GATE")
    require(contract["question_class"] == "development", "QUESTION_CLASS")
    require(contract["physical_question_declared"] is False, "PHYSICAL_QUESTION")
    change = contract["controlled_change"]
    for key in (
        "shared_authorization_projection_added",
        "campaign_specific_authorization_field_paths_removed_for_r59",
        "post_publication_exact_closure_control_added",
        "physical_mode_requires_exact_control_before_and_after_lock",
        "raw_schema_binding_expression_repaired",
    ):
        require(change[key] is True, f"CONTROLLED_CHANGE:{key}")
    for key in (
        "engine_neutral_core_controller_changed",
        "authored_initializer_changed",
        "initializer_readback_tolerance_changed",
        "behavior_threshold_changed",
        "behavior_margin_changed",
        "morphology_changed",
        "actuator_profile_changed",
        "native_physics_changed",
        "policy_changed",
        "selector_changed",
        "evaluator_changed",
        "cohort_changed",
        "r57_and_r58_observations_rewritten",
    ):
        require(change[key] is False, f"FORBIDDEN_CHANGE:{key}")
    projection = contract["physical_authorization_projection"]
    require(
        projection["schema_version"]
        == "sporespore_qsdk_physical_route_authorization_projection_v1",
        "PROJECTION_SCHEMA",
    )
    require(projection["seed"] == 1802965793, "SEED")
    require(projection["held_out"] is False, "HELD_OUT")
    require(projection["maximum_world_build_count"] == 1, "WORLD_BUDGET")
    require(projection["maximum_outer_solver_steps"] == 2, "STEP_BUDGET")
    require(projection["same_identity_rerun_permitted"] is False, "RERUN")
    controls = contract["zero_world_controls"]
    require(controls["projection_positive_control_count"] == 1, "POSITIVE_COUNT")
    require(controls["projection_mutation_count"] == 29, "MUTATION_COUNT")
    require(controls["projection_mutation_rejection_count"] == 29, "REJECTION_COUNT")
    require(len(controls["mutation_ids"]) == 29, "MUTATION_IDS")
    published = contract["published_closure_authorization_control"]
    require(published["mode"] == "AuthorizationControl", "CONTROL_MODE")
    require(published["requires_exact_committed_closure_path_and_raw_sha256"] is True,
            "CONTROL_EXACT_CLOSURE")
    require(published["physical_mode_requires_control_before_lock"] is True,
            "CONTROL_BEFORE_LOCK")
    require(published["physical_mode_rechecks_control_after_lock"] is True,
            "CONTROL_AFTER_LOCK")
    require(published["physical_execution_authorized_before_control"] is False,
            "EARLY_PHYSICAL_AUTHORITY")
    gate = contract["complete_zero_world_gate"]
    require(gate["must_pass_before_physics"] is True, "ZERO_GATE")
    require(gate["physical_execution_authorized"] is False, "ZERO_GATE_AUTHORITY")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        require(gate[key] == 0, f"ZERO_COUNT:{key}")
    next_boundary = contract["next_boundary_if_positive"]
    require(next_boundary["first_required_mode"] == "AuthorizationControl",
            "NEXT_CONTROL")
    require(next_boundary["physical_execution_authorized"] is False,
            "NEXT_EARLY_AUTHORITY")
    inventory = contract["source_inventory"]
    require(len(inventory) == len(set(inventory)), "SOURCE_DUPLICATE")
    for relative in inventory:
        require((ROOT / relative).is_file(), f"SOURCE_MISSING:{relative}")
    for predecessor in contract["bound_predecessors"]:
        path = ROOT / predecessor["path"]
        require(sha256(path) == predecessor["raw_sha256"], "PREDECESSOR_SHA")
        require(path.stat().st_size == predecessor["byte_length"], "PREDECESSOR_SIZE")
    return contract


def validate_sources() -> dict[str, int]:
    contract = validate_contract()
    inherited_counts = inherited.validate_sources()
    markers(
        PROJECTION,
        (
            "function ConvertTo-SporeSporePhysicalAuthorizationProjection",
            'if (-not $Closure.Contains("physical_authorization"))',
            'physical_execution = [bool]$projection["physical_execution_authorized"]',
            'physical_authority = -not [bool]$projection["physical_acceptance_authority"]',
            'release_authority = -not [bool]$projection["release_authority"]',
        ),
    )
    shared = markers(
        SHARED_RUNNER,
        (
            '[ValidateSet("Preflight", "Physical", "ProjectionControl", "AuthorizationControl")]',
            '. (Join-Path $PSScriptRoot "physical_authorization_projection.ps1")',
            "function Get-R57AuthorizationControlReceipt",
            "function Find-R57AuthorizationControlReceipts",
            "function Invoke-R57AuthorizationControl",
            '"authorization_control_count:$($authorizationControls.Count)"',
            '"authorization_control_count_after_lock:$($authorizationControls.Count)"',
            "$receiptProjectionJson -ceq $authorizationProjectionJson -and",
            "Materialize a fail-closed provisional receipt while the serialized",
            '[string]$raw.schema_version -ceq $RawSchema -and',
            'if ($Mode -ceq "AuthorizationControl")',
        ),
    )
    require(
        "[string]$raw.schema_version -ceq\n" not in shared,
        "DUPLICATE_RAW_SCHEMA_COMPARISON",
    )
    markers(
        BOUND_RUNNER,
        (
            '-GateId "QSDK-R24D59"',
            '-GateToken "R24D59"',
            '-AuthorizationProjectionSchema (',
            '"sporespore_qsdk_physical_route_authorization_projection_v1"',
            '-AuthorizationControlSchema (',
            '"sporespore_qsdk_r24d59_published_closure_authorization_control_v1"',
            '-Seed 1802965793',
            '-SupervisorMarker "QSDK_R24D59_GHOST_SUPERVISOR "',
            "exit $LASTEXITCODE",
        ),
    )
    markers(
        PROJECTION_TEST,
        (
            'mutation_rejection_count = $rejections.Count',
            'physical_execution_authorized = $false',
            'physical_acceptance_authority = $false',
            'release_authority = $false',
        ),
    )
    return {
        "source_inventory_count": len(contract["source_inventory"]),
        "bound_predecessor_count": len(contract["bound_predecessors"]),
        "inherited_source_inventory_count": inherited_counts["source_inventory_count"],
        "projection_mutation_count": contract["zero_world_controls"]
        ["projection_mutation_count"],
    }


def run_projection_test() -> dict[str, Any]:
    completed = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(PROJECTION_TEST)],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    require(completed.returncode == 0, f"PROJECTION_TEST_EXIT:{completed.returncode}")
    lines = [line for line in completed.stdout.splitlines()
             if line.startswith(PROJECTION_MARKER)]
    require(len(lines) == 1, "PROJECTION_TEST_MARKER")
    receipt = json.loads(lines[0][len(PROJECTION_MARKER):])
    require(isinstance(receipt, dict), "PROJECTION_TEST_RECEIPT")
    require(receipt["ok"] is True, "PROJECTION_TEST_NOT_OK")
    require(receipt["positive_control_count"] == 1, "PROJECTION_POSITIVE")
    require(receipt["mutation_rejection_count"] == 29, "PROJECTION_REJECTIONS")
    require(completed.stderr == "", f"PROJECTION_TEST_STDERR:{completed.stderr}")
    return receipt


def run_supervisor_projection_control() -> dict[str, Any]:
    completed = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(BOUND_RUNNER),
         "-Mode", "ProjectionControl"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    require(completed.returncode == 23, f"SUPERVISOR_EXIT:{completed.returncode}")
    lines = [line for line in completed.stdout.splitlines()
             if line.startswith(SUPERVISOR_MARKER)]
    require(len(lines) == 1, "SUPERVISOR_MARKER")
    receipt = json.loads(lines[0][len(SUPERVISOR_MARKER):])
    require(receipt["gate_id"] == "QSDK-R24D59", "SUPERVISOR_GATE")
    require(receipt["status"] == "forced_failure_projection_control",
            "SUPERVISOR_STATUS")
    require(receipt["ok"] is False, "SUPERVISOR_FORCED_OK")
    require(completed.stderr == "", f"SUPERVISOR_STDERR:{completed.stderr}")
    return receipt


def run_missing_physical_switch_refusal() -> dict[str, Any]:
    completed = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(BOUND_RUNNER), "-Mode", "Physical"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    require(completed.returncode == 1, f"PHYSICAL_REFUSAL_EXIT:{completed.returncode}")
    require("physical_switch_required" in completed.stderr, "PHYSICAL_REFUSAL_CODE")
    require(SUPERVISOR_MARKER not in completed.stdout, "PHYSICAL_REFUSAL_SUMMARY")
    return {
        "schema_version": "sporespore_qsdk_r24d59_missing_physical_switch_refusal_v1",
        "gate_id": "QSDK-R24D59",
        "ok": True,
        "refusal_count": 1,
        "semantic_exit_code": 1,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def run_preflight(core_library: Path) -> dict[str, Any]:
    counts = validate_sources()
    inherited_receipt = inherited.run_preflight(core_library)
    projection = run_projection_test()
    supervisor = run_supervisor_projection_control()
    refusal = run_missing_physical_switch_refusal()
    for receipt in (inherited_receipt, projection, supervisor, refusal):
        for key in (
            "model_construction_count", "world_attempt_count",
            "world_build_count", "solver_step_count",
        ):
            require(receipt[key] == 0, f"ZERO_COUNT:{key}")
        require(receipt["physical_acceptance_authority"] is False,
                "PHYSICAL_AUTHORITY")
        require(receipt["release_authority"] is False, "RELEASE_AUTHORITY")
    return {
        "schema_version": "sporespore_qsdk_r24d59_godot_authorization_projection_preflight_v1",
        "gate_id": "QSDK-R24D59",
        "ok": True,
        "runtime_id": "sporespore_qsdk_physical_route_authorization_projection_v1",
        "runtime_version": "sporespore_qsdk_r24d59_published_closure_authorization_control_v1",
        **counts,
        "inherited_r58_preflight": inherited_receipt,
        "authorization_projection_receipt": projection,
        "supervisor_projection_receipt": supervisor,
        "missing_physical_switch_refusal_receipt": refusal,
        "projection_positive_control_count": 1,
        "projection_mutation_rejection_count": 29,
        "supervisor_forced_failure_control_count": 1,
        "missing_physical_switch_refusal_count": 1,
        "published_closure_authorization_control_executed": False,
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
        counts = validate_sources()
        print(SOURCE_MARKER, " ".join(f"{key}={value}"
                                      for key, value in counts.items()))
        return 0
    print(json.dumps(run_preflight(args.core_library.resolve()), allow_nan=False,
                     separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        KeyError, OSError, AuthorizationError, inherited.SuccessorError,
        ValueError, json.JSONDecodeError, subprocess.SubprocessError,
    ) as error:
        print(f"QSDK_R24D59_GODOT_AUTHORIZATION_PROJECTION_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
