#!/usr/bin/env python3
"""Compact R72 source audit and zero-world physical-route preflight."""

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

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact, git, load, records_with_key, require, sha256, source_bytes,
    verify_exact_paths,
)

CONTRACT = ROOT / (
    "sdk/recovery/r24d72_godot_jolt_minimal_contact_calibration_contract_v1.json"
)
SHARED = ROOT / "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
RUNNER = ROOT / "sdk/run_qsdk_r24d72_godot_jolt_minimal_contact_calibration.ps1"
WORKER = ROOT / "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
SOURCE_MARKER = "QSDK_R24D72_GODOT_JOLT_MINIMAL_CONTACT_CALIBRATION_SOURCE_PASS"


def _contains(path: Path, *markers: str) -> None:
    text = path.read_text(encoding="utf-8")
    require(all(marker in text for marker in markers),
            f"MARKERS:{path.relative_to(ROOT)}")


def validate_sources() -> tuple[dict[str, Any], dict[str, int]]:
    contract = load(CONTRACT)
    verify_exact_paths(contract, {
        "schema_version": (
            "sporespore_qsdk_r24d72_godot_jolt_minimal_contact_calibration_"
            "contract_v1"
        ),
        "gate_id": "QSDK-R24D72",
        "status": "prospective_complete_zero_world_qualification_required_physics_blocked",
        "question_class": "development",
        "physical_question_declared": True,
        "finite_decision_declared": False,
        "ledger_scope.subsystem": "recovery",
        "ledger_scope.engine_scope": "godot_jolt",
        "physical_envelope.maximum_world_build_count": 1,
        "physical_envelope.maximum_outer_solver_steps": 2,
        "physical_envelope.behavior_evaluator_invocation_count": 0,
        "complete_zero_world_gate.physical_execution_authorized": False,
        "authorization_boundary.maximum_physical_steps_authorized": 0,
    }, "CONTRACT")

    predecessor = contract["bound_predecessor"]
    raw = source_bytes(ROOT, predecessor["closure_commit"], predecessor["path"])
    exact((len(raw), sha256(raw)), (predecessor["byte_length"],
          predecessor["raw_sha256"]), "PREDECESSOR_CONTENT")
    exact(git(ROOT, "rev-parse",
              f'{predecessor["closure_commit"]}:{predecessor["path"]}'),
          predecessor["git_blob_oid"], "PREDECESSOR_BLOB")
    exact(json.loads(raw)["closure_status"], predecessor["closure_status"],
          "PREDECESSOR_STATUS")

    runtime = contract["exact_runtime"]
    for prefix in ("console", "engine"):
        path = Path(runtime[f"{prefix}_path"])
        require(path.is_file(), f"RUNTIME_MISSING:{prefix}")
        exact((path.stat().st_size, sha256(path.read_bytes())),
              (runtime[f"{prefix}_byte_length"], runtime[f"{prefix}_sha256"]),
              f"RUNTIME_CONTENT:{prefix}")

    expected_counts = {
        "source_inventory": 15,
        "authored_source_paths": 12,
        "qualified_physical_paths": 30,
    }
    for key, count in expected_counts.items():
        paths = contract[key]
        exact((len(paths), len(set(paths))), (count, count), f"COUNT:{key}")
        require(all((ROOT / relative).is_file() for relative in paths),
                f"MISSING:{key}")
    head, parent = str(git(ROOT, "rev-parse", "HEAD")), contract["authored_parent_commit"]
    if head != parent:
        changed = str(git(ROOT, "diff", "--name-only", f"{parent}..{head}"))
        exact(changed.splitlines(), contract["authored_source_paths"], "COMMIT_PATHS")

    _contains(SHARED, "[string]$ConsolePath", "[string]$ExpectedConsoleSha256",
              "[long]$ExpectedConsoleByteLength", "Assert-R57Console")
    _contains(RUNNER, 'GateId = "QSDK-R24D72"', "ExpectedConsoleSha256",
              "MaximumOuterSolverSteps = 2",
              "QualifiedPhysicalPaths = @($contract.qualified_physical_paths")
    _contains(WORKER, "One-world, two-step",
              "collect_native_world_observation_v1(",
              '"portable_command_application_count": 1')
    for relative in ("sdk/release/quadruped_release_contract.json",
                     "sdk/release/quadruped_support_matrix.json"):
        value = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(value, "r24d72_zero_world_qualification_pending")
        exact(len(records), 1, f"LIVE_RECORD:{relative}")
        verify_exact_paths(records[0], {
            "next_gate_id": "QSDK-R24D72",
            "r24d72_physical_question_declared": True,
            "r24d72_zero_world_qualification_pending": True,
            "r24d72_physical_execution_authorized": False,
            "physical_execution_blocked_until_r24d72_zero_world_qualification": True,
        }, f"LIVE:{relative}")
    return contract, {
        "focused_source_inventory_count": 15,
        "authored_source_path_count": 12,
        "qualified_physical_path_count": 30,
        "bound_predecessor_count": 1,
        "historical_closure_audits_executed_count": 0,
    }


def run_preflight(core_library: Path) -> dict[str, Any]:
    contract, counts = validate_sources()
    require(core_library.is_file(), "CORE_LIBRARY_MISSING")
    parse = subprocess.run([
        contract["exact_runtime"]["console_path"], "--headless", "--path", str(ROOT),
        "--check-only", "--script", "res://" + WORKER.relative_to(ROOT).as_posix(),
    ], cwd=ROOT, capture_output=True, text=True)
    require(parse.returncode == 0, f"WORKER_PARSE:{parse.stdout}|{parse.stderr}")

    control = subprocess.run([
        "pwsh", "-NoLogo", "-NoProfile", "-File", str(RUNNER),
        "-Mode", "ProjectionControl",
    ], cwd=ROOT, capture_output=True, text=True)
    exact(control.returncode, 23, "FORCED_CONTROL_EXIT")
    marker = contract["physical_runner"]["supervisor_marker"]
    lines = [line for line in control.stdout.splitlines() if line.startswith(marker)]
    exact(len(lines), 1, "FORCED_CONTROL_MARKER")
    verify_exact_paths(json.loads(lines[0][len(marker):]), {
        "gate_id": "QSDK-R24D72", "ok": False,
        "status": "forced_failure_projection_control",
        "model_construction_count": 0, "world_attempt_count": 0,
        "world_build_count": 0, "solver_step_count": 0,
        "physical_acceptance_authority": False, "release_authority": False,
    }, "FORCED_CONTROL")
    return {
        "schema_version": (
            "sporespore_qsdk_r24d72_godot_minimal_contact_calibration_preflight_v1"
        ),
        "gate_id": "QSDK-R24D72", "ok": True,
        "runtime_id": contract["exact_runtime"]["collector_id"],
        "runtime_version": contract["exact_runtime"]["runtime_profile_id"],
        **counts,
        "exact_runtime_pair_count": 1, "worker_parse_count": 1,
        "forced_failure_projection_control_count": 1,
        "model_construction_count": 0, "world_attempt_count": 0,
        "world_build_count": 0, "solver_step_count": 0,
        "physics_state_modified": False, "physical_question_opened": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False, "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    if args.core_library is None:
        _contract, counts = validate_sources()
        print(SOURCE_MARKER, " ".join(f"{key}={value}" for key, value in counts.items()))
    else:
        print(json.dumps(run_preflight(args.core_library.resolve()),
                         separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"QSDK_R24D72_GODOT_JOLT_MINIMAL_CONTACT_CALIBRATION_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
