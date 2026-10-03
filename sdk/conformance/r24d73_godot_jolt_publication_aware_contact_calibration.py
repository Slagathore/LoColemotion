#!/usr/bin/env python3
"""Compact R73 publication-aware source audit and route preflight."""

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
    exact, git, load, records_with_key, require,
    resolve_prospective_source_freeze, sha256, source_bytes, verify_exact_paths,
)

CONTRACT = ROOT / (
    "sdk/recovery/r24d73_godot_jolt_publication_aware_contact_"
    "calibration_contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d73_godot_jolt_publication_aware_contact_calibration_"
    "zero_world_qualification_closure_v1.json"
)
R72_CONTRACT = ROOT / (
    "sdk/recovery/r24d72_godot_jolt_minimal_contact_calibration_contract_v1.json"
)
R72_CLOSURE = ROOT / (
    "sdk/recovery/r24d72_godot_jolt_minimal_contact_calibration_"
    "zero_world_qualification_closure_v1.json"
)
SHARED = ROOT / "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
RUNNER = ROOT / (
    "sdk/run_qsdk_r24d73_godot_jolt_publication_aware_contact_calibration.ps1"
)
WORKER = ROOT / "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
SOURCE_MARKER = (
    "QSDK_R24D73_GODOT_JOLT_PUBLICATION_AWARE_CONTACT_CALIBRATION_SOURCE_PASS"
)


def _contains(path: Path, *markers: str) -> None:
    text = path.read_text(encoding="utf-8")
    require(all(marker in text for marker in markers),
            f"MARKERS:{path.relative_to(ROOT)}")


def validate_sources() -> tuple[dict[str, Any], dict[str, int]]:
    contract = load(CONTRACT)
    verify_exact_paths(contract, {
        "schema_version": (
            "sporespore_qsdk_r24d73_godot_jolt_publication_aware_contact_"
            "calibration_contract_v1"
        ),
        "gate_id": "QSDK-R24D73",
        "status": "prospective_complete_zero_world_qualification_required_physics_blocked",
        "question_class": "development",
        "physical_question_declared": True,
        "controlled_change.physical_worker_changed": False,
        "controlled_change.shared_physical_supervisor_changed": False,
        "physical_envelope.maximum_world_build_count": 1,
        "physical_envelope.maximum_outer_solver_steps": 2,
        "physical_envelope.behavior_evaluator_invocation_count": 0,
        "complete_zero_world_gate.physical_execution_authorized": False,
        "authorization_boundary.maximum_physical_steps_authorized": 0,
    }, "CONTRACT")

    predecessor = contract["bound_r24d72_zero_world_closure"]
    raw = source_bytes(ROOT, predecessor["closure_commit"], predecessor["path"])
    exact((len(raw), sha256(raw)), (predecessor["byte_length"],
          predecessor["raw_sha256"]), "R72_CLOSURE_CONTENT")
    exact(git(ROOT, "rev-parse",
              f'{predecessor["closure_commit"]}:{predecessor["path"]}'),
          predecessor["git_blob_oid"], "R72_CLOSURE_BLOB")
    exact(json.loads(raw)["closure_status"], predecessor["closure_status"],
          "R72_CLOSURE_STATUS")

    invalid = contract["bound_r24d72_pre_execution_invalid"]
    invalid_path = Path(invalid["path"])
    require(invalid_path.is_file(), "R72_INVALID_MISSING")
    invalid_raw = invalid_path.read_bytes()
    exact((len(invalid_raw), sha256(invalid_raw)),
          (invalid["byte_length"], invalid["raw_sha256"]), "R72_INVALID_CONTENT")
    verify_exact_paths(json.loads(invalid_raw), {
        "status": invalid["status"],
        "observed_evidence_population.physical_attempt_directory_created": False,
        "observed_evidence_population.godot_runtime_process_started": False,
        "observed_evidence_population.model_construction_count": 0,
        "observed_evidence_population.world_attempt_count": 0,
        "observed_evidence_population.world_build_count": 0,
        "observed_evidence_population.solver_step_count": 0,
        "observed_evidence_population.physics_state_modified": False,
        "interpretation.r24d72_same_identity_reinvocation_permitted": False,
        "interpretation.distinct_successor_required": True,
    }, "R72_INVALID")

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
        "qualified_physical_paths": 31,
    }
    for key, count in expected_counts.items():
        paths = contract[key]
        exact((len(paths), len(set(paths))), (count, count), f"COUNT:{key}")
        require(all((ROOT / relative).is_file() for relative in paths),
                f"MISSING:{key}")

    _source, published = resolve_prospective_source_freeze(
        root=ROOT, contract=contract, closure_path=CLOSURE,
        closure_schema=(
            "sporespore_qsdk_r24d73_godot_jolt_publication_aware_contact_"
            "calibration_zero_world_qualification_closure_v1"
        ), gate_id="QSDK-R24D73",
    )
    r72_source, r72_published = resolve_prospective_source_freeze(
        root=ROOT, contract=load(R72_CONTRACT), closure_path=R72_CLOSURE,
        closure_schema=(
            "sporespore_qsdk_r24d72_godot_jolt_minimal_contact_calibration_"
            "zero_world_qualification_closure_v1"
        ), gate_id="QSDK-R24D72",
    )
    exact((r72_source, r72_published),
          ("3d76c15a2fcb05c3a2c5f214912e3c14d6846847", True),
          "PUBLICATION_BINDING_CONTROL")

    _contains(SHARED, "Get-R57Authorization", "qualified_physical_source_drift")
    _contains(RUNNER, 'GateId = "QSDK-R24D73"', "ExpectedConsoleSha256",
              "MaximumOuterSolverSteps = 2",
              "QualifiedPhysicalPaths = @($contract.qualified_physical_paths")
    _contains(WORKER, "One-world, two-step",
              "collect_native_world_observation_v1(",
              '"portable_command_application_count": 1')

    expected_live = {
        "next_gate_id": "QSDK-R24D73",
        "r24d73_physical_question_declared": True,
        "r24d73_zero_world_qualification_pending": not published,
        "r24d73_physical_execution_authorized": published,
        "physical_execution_blocked_until_r24d73_zero_world_qualification": not published,
    }
    for relative in ("sdk/release/quadruped_release_contract.json",
                     "sdk/release/quadruped_support_matrix.json"):
        value = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(value, "r24d73_zero_world_qualification_pending")
        exact(len(records), 1, f"LIVE_RECORD:{relative}")
        verify_exact_paths(records[0], expected_live, f"LIVE:{relative}")
    return contract, {
        "focused_source_inventory_count": 15,
        "authored_source_path_count": 12,
        "qualified_physical_path_count": 31,
        "bound_predecessor_count": 2,
        "publication_binding_regression_control_count": 1,
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
        "gate_id": "QSDK-R24D73", "ok": False,
        "status": "forced_failure_projection_control",
        "model_construction_count": 0, "world_attempt_count": 0,
        "world_build_count": 0, "solver_step_count": 0,
        "physical_acceptance_authority": False, "release_authority": False,
    }, "FORCED_CONTROL")
    return {
        "schema_version": (
            "sporespore_qsdk_r24d73_godot_publication_aware_contact_"
            "calibration_preflight_v1"
        ),
        "gate_id": "QSDK-R24D73", "ok": True,
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
        print(f"QSDK_R24D73_GODOT_JOLT_PUBLICATION_AWARE_CONTACT_CALIBRATION_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
