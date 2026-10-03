#!/usr/bin/env python3
"""Compact R75 contact-source retention audit and zero-world preflight."""

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
from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    git,
    load,
    records_with_key,
    require,
    resolve_prospective_source_freeze,
    sha256,
    source_bytes,
    verify_exact_paths,
)

CONTRACT = ROOT / "sdk/recovery/r24d75_godot_contact_source_retention_contract_v1.json"
CLOSURE = ROOT / (
    "sdk/recovery/r24d75_godot_contact_source_retention_"
    "zero_world_qualification_closure_v1.json"
)
WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
RUNNER = ROOT / "sdk/run_qsdk_r24d75_godot_jolt_contact_calibration.ps1"
QUALIFICATION_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d75_godot_contact_source_retention_"
    "zero_world_qualification.ps1"
)
PHYSICAL_WORKER = ROOT / "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
ZERO_WORKER = ROOT / (
    "tests/test_sdk_qsdk_r24d75_godot_contact_source_retention_zero_world.gd"
)
ZERO_MARKER = "QSDK_R24D75_GODOT_CONTACT_SOURCE_RETENTION_ZERO_WORLD "
SOURCE_MARKER = "QSDK_R24D75_GODOT_CONTACT_SOURCE_RETENTION_SOURCE_PASS"
SUPERVISOR_MARKER = "QSDK_R24D75_CONTACT_CALIBRATION_SUPERVISOR "


def _contains(path: Path, *markers: str) -> None:
    text = path.read_text(encoding="utf-8")
    require(
        all(marker in text for marker in markers),
        f"MARKERS:{path.relative_to(ROOT).as_posix()}",
    )


def validate_sources() -> tuple[dict[str, Any], dict[str, int]]:
    contract = load(CONTRACT)
    verify_exact_paths(
        contract,
        {
            "schema_version": (
                "sporespore_qsdk_r24d75_godot_contact_source_retention_"
                "contract_v1"
            ),
            "gate_id": "QSDK-R24D75",
            "status": (
                "prospective_complete_zero_world_qualification_required_"
                "physics_blocked"
            ),
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": True,
            "controlled_change.exact_contact_source_receipt_retained_beside_existing_digest": True,
            "controlled_change.contact_source_receipt_deep_copy_required": True,
            "controlled_change.contact_source_digest_semantics_unchanged": True,
            "controlled_change.production_retention_helper_shared_with_zero_world_worker": True,
            "controlled_change.physical_worker_changed": False,
            "controlled_change.shared_physical_supervisor_changed": False,
            "controlled_change.portable_recovery_controller_changed": False,
            "physical_envelope.maximum_world_build_count": 1,
            "physical_envelope.maximum_outer_solver_steps": 2,
            "physical_envelope.behavior_evaluator_invocation_count": 0,
            "complete_zero_world_gate.retention_mutation_population_count": 8,
            "complete_zero_world_gate.exact_retention_mutation_rejection_count": 8,
            "complete_zero_world_gate.physical_execution_authorized": False,
            "authorization_boundary.maximum_physical_steps_authorized": 0,
        },
        "CONTRACT",
    )

    predecessor = contract["bound_r24d74_incomplete_closure"]
    raw = source_bytes(ROOT, predecessor["closure_commit"], predecessor["path"])
    exact(
        (len(raw), sha256(raw)),
        (predecessor["byte_length"], predecessor["raw_sha256"]),
        "R74_INCOMPLETE_CONTENT",
    )
    exact(
        git(
            ROOT,
            "rev-parse",
            f'{predecessor["closure_commit"]}:{predecessor["path"]}',
        ),
        predecessor["git_blob_oid"],
        "R74_INCOMPLETE_BLOB",
    )
    incomplete = json.loads(raw)
    verify_exact_paths(
        incomplete,
        {
            "closure_status": predecessor["closure_status"],
            "physical_attempt.world_build_count": 1,
            "physical_attempt.solver_step_count": 2,
            "causal_diagnosis.route_integration_valid": True,
            "causal_diagnosis.contact_source_payload_retained_step_count": 0,
            "causal_diagnosis.declared_exact_contact_point_count_retained_step_count": 0,
            "decision.valid_contact_calibration_result_observed": False,
            "decision.same_identity_rerun_permitted": False,
            "next_boundary.gate_id": "QSDK-R24D75",
        },
        "R74_INCOMPLETE",
    )

    runtime = contract["exact_runtime"]
    for prefix in ("console", "engine"):
        path = Path(runtime[f"{prefix}_path"])
        require(path.is_file(), f"RUNTIME_MISSING:{prefix}")
        exact(
            (path.stat().st_size, sha256(path.read_bytes())),
            (runtime[f"{prefix}_byte_length"], runtime[f"{prefix}_sha256"]),
            f"RUNTIME_CONTENT:{prefix}",
        )

    expected_counts = {
        "source_inventory": 20,
        "authored_source_paths": 13,
        "qualified_physical_paths": 36,
    }
    for key, count in expected_counts.items():
        paths = contract[key]
        exact((len(paths), len(set(paths))), (count, count), f"COUNT:{key}")
        require(all((ROOT / relative).is_file() for relative in paths), f"MISSING:{key}")

    _source, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=(
            "sporespore_qsdk_r24d75_godot_contact_source_retention_"
            "zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D75",
    )

    _contains(
        WORLD,
        "static func retain_contact_source_receipt_v1(",
        "source_receipt.duplicate(true)",
        '"contact_source_receipt": contact_source_receipt',
        '"contact_source_sha256": contact_source_sha256',
        "SOURCE_COMPONENT_RECEIPTS_SCHEMA",
        '"exact_contact_point_count_int"',
        '"exact_contact_point_count_nonnegative"',
    )
    _contains(
        ZERO_WORKER,
        "WorldScript.retain_contact_source_receipt_v1",
        '"canonical_digest_recompute_count"',
        '"deep_copy_isolation_count"',
        '"exact_mutation_rejection_count"',
    )
    _contains(
        RUNNER,
        'GateId = "QSDK-R24D75"',
        "MaximumOuterSolverSteps = 2",
        "QualifiedPhysicalPaths = @($contract.qualified_physical_paths",
    )
    _contains(
        QUALIFICATION_RUNNER,
        "run_qsdk_core_zero_world_qualification.ps1",
        'GateId = "QSDK-R24D75"',
        "ProspectivePhysicalQuestionDeclared = $true",
    )
    _contains(
        PHYSICAL_WORKER,
        "One-world, two-step",
        "collect_native_world_observation_v1(",
        '"portable_command_application_count": 1',
    )

    permanent_live = {
        "r24d75_distinct_successor_required": True,
        "r24d75_question_class": "development",
        "r24d75_physical_question_declared": True,
        "r24d75_retention_correction_declared": True,
        "r24d75_contact_source_payload_retention_required": True,
        "r24d75_contract_path": (
            "sdk/recovery/r24d75_godot_contact_source_retention_contract_v1.json"
        ),
        "r24d75_source_inventory_count": 20,
        "r24d75_authored_source_path_count": 13,
        "r24d75_qualified_physical_path_count": 36,
        "r24d75_development_zero_world_qualification_passed": True,
        "r24d75_development_physical_execution_count": 0,
    }
    prospective_live = {
        "next_gate_id": "QSDK-R24D75",
        "r24d75_zero_world_qualification_pending": True,
        "r24d75_zero_world_qualified": False,
        "r24d75_physical_execution_authorized": False,
        "physical_execution_blocked_pending_r24d75_declaration_and_zero_world_qualification": True,
    }
    for relative in (
        "sdk/release/quadruped_release_contract.json",
        "sdk/release/quadruped_support_matrix.json",
    ):
        value = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(value, "r24d75_retention_correction_declared")
        exact(len(records), 1, f"LIVE_RECORD:{relative}")
        verify_exact_paths(records[0], permanent_live, f"LIVE_PERMANENT:{relative}")
        if not published:
            verify_exact_paths(records[0], prospective_live, f"LIVE_PROSPECTIVE:{relative}")

    return contract, {
        "focused_source_inventory_count": 20,
        "authored_source_path_count": 13,
        "qualified_physical_path_count": 36,
        "bound_predecessor_count": 1,
        "physical_component_assembly_source_control_count": 1,
        "historical_closure_audits_executed_count": 0,
    }


def _parse_worker(executable: str, worker: Path) -> None:
    parsed = subprocess.run(
        [
            executable,
            "--headless",
            "--path",
            str(ROOT),
            "--check-only",
            "--script",
            "res://" + worker.relative_to(ROOT).as_posix(),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    require(
        parsed.returncode == 0,
        f"WORKER_PARSE:{worker.name}:{parsed.stdout}|{parsed.stderr}",
    )


def run_preflight(core_library: Path) -> dict[str, Any]:
    contract, counts = validate_sources()
    require(core_library.is_file(), "CORE_LIBRARY_MISSING")
    executable = contract["exact_runtime"]["console_path"]
    for worker in (PHYSICAL_WORKER, ZERO_WORKER):
        _parse_worker(executable, worker)

    receipt = controls.run_zero_world_worker_specs(
        ROOT,
        Path(executable),
        (
            {
                "id": "r75_contact_source_retention",
                "path": ZERO_WORKER,
                "marker": ZERO_MARKER,
                "expected": {
                    "gate_id": "QSDK-R24D75",
                    "ok": True,
                    "retained_populated_count": 1,
                    "retained_zero_count": 1,
                    "populated_exact_contact_point_count": 8,
                    "zero_exact_contact_point_count": 0,
                    "canonical_digest_recompute_count": 2,
                    "deep_copy_isolation_count": 1,
                    "mutation_population_count": 8,
                    "exact_mutation_rejection_count": 8,
                    "native_runtime_observation_collection_executed": False,
                    "physical_question_opened": False,
                },
            },
        ),
    )["r75_contact_source_retention"]
    control = controls.run_projection_control(
        ROOT, RUNNER, SUPERVISOR_MARKER, "QSDK-R24D75"
    )
    controls.require_zero_authority(control)
    return {
        "schema_version": (
            "sporespore_qsdk_r24d75_godot_contact_source_retention_preflight_v1"
        ),
        "gate_id": "QSDK-R24D75",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["collector_id"],
        "runtime_version": contract["exact_runtime"]["runtime_profile_id"],
        **counts,
        "production_retention_receipt": receipt,
        "supervisor_projection_receipt": control,
        "production_retention_populated_positive_count": 1,
        "production_retention_zero_positive_count": 1,
        "canonical_digest_recompute_count": 2,
        "deep_copy_isolation_count": 1,
        "retention_mutation_population_count": 8,
        "exact_retention_mutation_rejection_count": 8,
        "exact_runtime_pair_count": 1,
        "worker_parse_count": 2,
        "forced_failure_projection_control_count": 1,
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
        print(SOURCE_MARKER, " ".join(f"{key}={value}" for key, value in counts.items()))
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
            f"QSDK_R24D75_GODOT_CONTACT_SOURCE_RETENTION_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
