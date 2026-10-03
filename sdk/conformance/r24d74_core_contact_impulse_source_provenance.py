#!/usr/bin/env python3
"""Compact R74 paired contact-provenance audit and zero-world preflight."""

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

CONTRACT = ROOT / (
    "sdk/recovery/r24d74_core_contact_impulse_source_provenance_contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d74_core_contact_impulse_source_provenance_"
    "zero_world_qualification_closure_v1.json"
)
R73_CONTRACT = ROOT / (
    "sdk/recovery/r24d73_godot_jolt_publication_aware_contact_"
    "calibration_contract_v1.json"
)
R73_QUALIFICATION = ROOT / (
    "sdk/recovery/r24d73_godot_jolt_publication_aware_contact_calibration_"
    "zero_world_qualification_closure_v1.json"
)
PROTOCOL = ROOT / "sdk/core/src/protocol.rs"
RUNNER = ROOT / "sdk/run_qsdk_r24d74_godot_jolt_contact_calibration.ps1"
QUALIFICATION_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d74_core_contact_impulse_source_provenance_"
    "zero_world_qualification.ps1"
)
PHYSICAL_WORKER = ROOT / "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
ZERO_WORKER = ROOT / (
    "tests/test_sdk_qsdk_r24d74_godot_contact_provenance_schema_zero_world.gd"
)
ZERO_MARKER = "QSDK_R24D74_GODOT_CONTACT_PROVENANCE_SCHEMA_ZERO_WORLD "
SOURCE_MARKER = "QSDK_R24D74_CORE_CONTACT_IMPULSE_SOURCE_PROVENANCE_SOURCE_PASS"
SUPERVISOR_MARKER = "QSDK_R24D74_CONTACT_CALIBRATION_SUPERVISOR "


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
                "sporespore_qsdk_r24d74_core_contact_impulse_source_"
                "provenance_contract_v1"
            ),
            "gate_id": "QSDK-R24D74",
            "status": (
                "prospective_complete_zero_world_qualification_required_"
                "physics_blocked"
            ),
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "core_and_godot_jolt",
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": True,
            "controlled_change.contact_provenance_impulse_source_profile_id_added": True,
            "controlled_change.contact_provenance_impulse_source_kind_added": True,
            "controlled_change.paired_presence_required": True,
            "controlled_change.unknown_field_refusal_preserved": True,
            "controlled_change.physical_worker_changed": False,
            "controlled_change.shared_physical_supervisor_changed": False,
            "physical_envelope.maximum_world_build_count": 1,
            "physical_envelope.maximum_outer_solver_steps": 2,
            "physical_envelope.behavior_evaluator_invocation_count": 0,
            "complete_zero_world_gate.physical_execution_authorized": False,
            "authorization_boundary.maximum_physical_steps_authorized": 0,
        },
        "CONTRACT",
    )

    predecessor = contract["bound_r24d73_invalid_closure"]
    raw = source_bytes(ROOT, predecessor["closure_commit"], predecessor["path"])
    exact(
        (len(raw), sha256(raw)),
        (predecessor["byte_length"], predecessor["raw_sha256"]),
        "R73_INVALID_CONTENT",
    )
    exact(
        git(
            ROOT,
            "rev-parse",
            f'{predecessor["closure_commit"]}:{predecessor["path"]}',
        ),
        predecessor["git_blob_oid"],
        "R73_INVALID_BLOB",
    )
    invalid = json.loads(raw)
    verify_exact_paths(
        invalid,
        {
            "closure_status": predecessor["closure_status"],
            "physical_attempt.model_construction_count": 1,
            "physical_attempt.world_attempt_count": 1,
            "physical_attempt.world_build_count": 1,
            "physical_attempt.solver_step_count": 1,
            "physical_attempt.behavior_evaluator_invocation_count": 0,
            "decision.valid_contact_calibration_result_observed": False,
            "decision.same_identity_rerun_permitted": False,
            "decision.distinct_successor_required": True,
        },
        "R73_INVALID",
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
        "source_inventory": 23,
        "authored_source_paths": 18,
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
            "sporespore_qsdk_r24d74_core_contact_impulse_source_provenance_"
            "zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D74",
    )
    r73_source, r73_published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=load(R73_CONTRACT),
        closure_path=R73_QUALIFICATION,
        closure_schema=(
            "sporespore_qsdk_r24d73_godot_jolt_publication_aware_contact_"
            "calibration_zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D73",
    )
    exact(
        (r73_source, r73_published),
        ("94ac327a25809bceb8582e8004a35c2c37b6216e", True),
        "PUBLICATION_BINDING_CONTROL",
    )

    _contains(
        PROTOCOL,
        "pub impulse_source_profile_id: Option<String>",
        "pub impulse_source_kind: Option<String>",
        "incomplete_impulse_source_provenance",
        "contact_impulse_source_provenance_is_explicit_paired_and_strict",
        "deny_unknown_fields",
    )
    _contains(
        ZERO_WORKER,
        "RuntimeScript.collect_native_v3",
        "production_decoder_positive_count",
        "missing_half_mutation_rejection_count",
        "unknown_field_mutation_rejection_count",
    )
    _contains(
        RUNNER,
        'GateId = "QSDK-R24D74"',
        "MaximumOuterSolverSteps = 2",
        "QualifiedPhysicalPaths = @($contract.qualified_physical_paths",
    )
    _contains(
        QUALIFICATION_RUNNER,
        "run_qsdk_core_zero_world_qualification.ps1",
        'GateId = "QSDK-R24D74"',
        "ProspectivePhysicalQuestionDeclared = $true",
    )
    _contains(
        PHYSICAL_WORKER,
        "One-world, two-step",
        "collect_native_world_observation_v1(",
        '"portable_command_application_count": 1',
    )

    expected_live = {
        "next_gate_id": "QSDK-R24D74",
        "r24d74_question_class": "development",
        "r24d74_physical_question_declared": True,
        "r24d74_schema_correction_declared": True,
        "r24d74_development_zero_world_qualification_passed": True,
        "r24d74_development_check_count": 9,
        "r24d74_development_historical_closure_audits_executed_count": 0,
        "r24d74_development_physical_execution_count": 0,
        "r24d74_zero_world_qualification_pending": not published,
        "r24d74_zero_world_qualified": published,
        "r24d74_physical_execution_authorized": published,
        "physical_execution_blocked_pending_r24d74_declaration_and_zero_world_qualification": False,
        "physical_execution_blocked_until_r24d74_zero_world_qualification": not published,
    }
    for relative in (
        "sdk/release/quadruped_release_contract.json",
        "sdk/release/quadruped_support_matrix.json",
    ):
        value = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(value, "r24d74_zero_world_qualification_pending")
        exact(len(records), 1, f"LIVE_RECORD:{relative}")
        verify_exact_paths(records[0], expected_live, f"LIVE:{relative}")

    return contract, {
        "focused_source_inventory_count": 23,
        "authored_source_path_count": 18,
        "qualified_physical_path_count": 36,
        "bound_predecessor_count": 1,
        "rust_paired_provenance_contract_test_count": 1,
        "publication_binding_regression_control_count": 1,
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
                "id": "r74_contact_provenance_schema",
                "path": ZERO_WORKER,
                "marker": ZERO_MARKER,
                "expected": {
                    "gate_id": "QSDK-R24D74",
                    "ok": True,
                    "exact_impulse_source_profile_id": (
                        "godot_4_7_jolt_sporespore_solved_contact_telemetry_v1"
                    ),
                    "exact_impulse_source_kind": (
                        "native_post_solve_contact_constraint_lambda"
                    ),
                    "production_decoder_positive_count": 1,
                    "missing_half_mutation_count": 2,
                    "missing_half_mutation_rejection_count": 2,
                    "unknown_field_mutation_rejection_count": 1,
                    "native_runtime_observation_collection_executed": False,
                    "physical_question_opened": False,
                },
            },
        ),
    )["r74_contact_provenance_schema"]
    control = controls.run_projection_control(
        ROOT, RUNNER, SUPERVISOR_MARKER, "QSDK-R24D74"
    )
    controls.require_zero_authority(control)
    return {
        "schema_version": (
            "sporespore_qsdk_r24d74_core_contact_impulse_source_"
            "provenance_preflight_v1"
        ),
        "gate_id": "QSDK-R24D74",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["collector_id"],
        "runtime_version": contract["exact_runtime"]["runtime_profile_id"],
        **counts,
        "production_decoder_receipt": receipt,
        "supervisor_projection_receipt": control,
        "godot_production_decoder_positive_count": 1,
        "missing_half_mutation_count": 2,
        "missing_half_mutation_rejection_count": 2,
        "unknown_field_mutation_rejection_count": 1,
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
            "QSDK_R24D74_CORE_CONTACT_IMPULSE_SOURCE_PROVENANCE_FAIL "
            f"{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
