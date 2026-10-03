#!/usr/bin/env python3
"""Compact R81 path-role successor source audit and zero-world preflight."""

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
    verify_declared_source_inventory,
    verify_exact_paths,
)

CONTRACT = ROOT / (
    "sdk/recovery/r24d81_godot_jolt_guarded_command_recovery_behavior_"
    "contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d81_godot_jolt_guarded_command_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
R80_INVALID = ROOT / (
    "sdk/recovery/r24d80_godot_published_closure_authorization_control_"
    "invalid_closure_v1.json"
)
R79 = ROOT / (
    "sdk/recovery/r24d79_recovery_command_transport_population_"
    "zero_world_qualification_closure_v1.json"
)
WORKER = ROOT / "tests/test_sdk_recovery_command_digest_population_development_probe.gd"
BEHAVIOR_WORKER = ROOT / "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d81_godot_jolt_guarded_command_recovery_behavior.ps1"
)
QUALIFICATION_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d81_godot_jolt_guarded_command_recovery_behavior_"
    "zero_world_qualification.ps1"
)
SOURCE_MARKER = (
    "QSDK_R24D81_GODOT_JOLT_GUARDED_COMMAND_RECOVERY_BEHAVIOR_SOURCE_PASS"
)
SUPERVISOR_MARKER = "QSDK_R24D81_GUARDED_COMMAND_RECOVERY_BEHAVIOR_SUPERVISOR "
RUNTIME_IDENTITY_SCHEMA = "sporespore_qsdk_r24d81_runtime_identity_control_v1"

COMMAND_POPULATION_SPEC = {
    "id": "r81_command_transport_population",
    "path": WORKER,
    "marker": "QSDK_RECOVERY_COMMAND_DIGEST_POPULATION_DEVELOPMENT_PROBE ",
    "expected": {
        "schema_version": "sporespore_recovery_command_digest_population_development_probe_v3",
        "ok": True,
        "status": "transport_stable",
        "active_command_cell_count": 603,
        "recovery_active_command_cell_count": 602,
        "stance_command_shape_cell_count": 1,
        "synthetic_stance_handoff_fixture_count": 1,
        "application_pass_count": 603,
        "validated_command_count": 4824,
        "host_write_count": 4824,
        "host_readback_count": 4824,
        "digest_mismatch_count": 0,
        "unique_expected_digest_count": 362,
        "unique_recomputed_digest_count": 362,
        "population_sha256": (
            "sha256:0285fcd60dd739084fa6131d58ce7d389d556a9da1d4dae1239d98293228dc46"
        ),
        "forced_digest_failure_rejected": True,
        "native_runtime_observation_collection_executed": False,
        "physical_question_opened": False,
    },
}


def _contains(path: Path, *markers: str) -> None:
    value = path.read_text(encoding="utf-8")
    require(all(marker in value for marker in markers), f"MARKERS:{path.name}")


def _verify_bound_predecessors(contract: dict[str, Any]) -> None:
    predecessors = contract["bound_predecessors"]
    exact(len(predecessors), 2, "PREDECESSOR_COUNT")
    expected = (
        (
            R80_INVALID,
            (
                "closed_consumed_invalid_incomplete_published_closure_control_"
                "qualified_physical_path_role_conflict"
            ),
            {
                "attempt.invocation_count": 1,
                "attempt.failure_code": "qualified_physical_source_drift",
                "source_drift_observation.changed_qualified_physical_path_count": 2,
                "physical_counts.model_construction_count": 0,
                "physical_counts.world_build_count": 0,
                "physical_counts.solver_step_count": 0,
                "decision.distinct_successor_required": True,
                "claim_boundary.r80_zero_world_qualification_preserved_positive": True,
            },
        ),
        (
            R79,
            (
                "closed_complete_zero_world_finite_recovery_command_transport_"
                "population_qualified_physics_blocked_pending_distinct_successor"
            ),
            {
                "qualification.active_command_cell_count": 603,
                "qualification.validated_command_count": 4824,
                "qualification.digest_mismatch_count": 0,
                "decision.command_transport_defect_closed": True,
                "decision.physical_execution_authorized": False,
                "claim_boundary.prone_to_standing_claimed": False,
            },
        ),
    )
    for declaration, (path, status, semantic) in zip(predecessors, expected):
        exact(declaration["path"], path.relative_to(ROOT).as_posix(), "PREDECESSOR_PATH")
        raw = source_bytes(ROOT, declaration["closure_commit"], declaration["path"])
        exact(
            (len(raw), sha256(raw)),
            (declaration["byte_length"], declaration["raw_sha256"]),
            "PREDECESSOR_CONTENT",
        )
        exact(
            git(ROOT, "rev-parse", f"{declaration['closure_commit']}:{declaration['path']}"),
            declaration["git_blob_oid"],
            "PREDECESSOR_BLOB",
        )
        value = load(path)
        verify_exact_paths(
            value,
            {"closure_status": status, **semantic},
            path.stem.upper(),
        )
        exact(declaration["closure_status"], status, "PREDECESSOR_STATUS")
        exact(declaration["same_identity_rerun_permitted"], False, "PREDECESSOR_RERUN")
        exact(declaration["result_reclassified"], False, "PREDECESSOR_RECLASSIFIED")


def validate_sources() -> tuple[dict[str, Any], dict[str, int]]:
    contract = load(CONTRACT)
    controls.validate_development_question(contract, "QSDK-R24D81")
    verify_exact_paths(
        contract,
        {
            "schema_version": (
                "sporespore_qsdk_r24d81_godot_jolt_guarded_command_"
                "recovery_behavior_contract_v1"
            ),
            "status": (
                "prospective_complete_zero_world_qualification_required_"
                "physics_blocked"
            ),
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "controlled_change.r79_guarded_command_transport_reused": True,
            "controlled_change.r80_positive_zero_world_qualification_bound": True,
            "controlled_change.r80_invalid_authorization_control_closure_bound": True,
            "controlled_change.publication_only_path_role_partition_added": True,
            "controlled_change.publication_only_paths_removed_from_qualified_physical_paths": 2,
            "controlled_change.guarded_target_projection_significant_decimal_digits": 13,
            "controlled_change.canonical_digest_significant_decimal_digits": 14,
            "controlled_change.portable_recovery_controller_changed_from_r80": False,
            "controlled_change.portable_recovery_evaluator_changed_from_r80": False,
            "controlled_change.behavior_threshold_changed_from_r80": False,
            "controlled_change.physical_envelope_changed_from_r80": False,
            "source_path_roles.publication_only_path_count": 2,
            "source_path_roles.qualified_physical_path_count": 59,
            "source_path_roles.overlap_count": 0,
            "source_path_roles.partition_must_pass_before_official_qualification": True,
            "complete_zero_world_gate.current_worker_count": 1,
            "complete_zero_world_gate.active_command_cell_count": 603,
            "complete_zero_world_gate.validated_command_count": 4824,
            "complete_zero_world_gate.physical_execution_authorized": False,
            "physical_authorization_projection.seed": 278151771,
            "physical_authorization_projection.maximum_world_build_count": 2,
            "physical_authorization_projection.maximum_outer_solver_steps": 2400,
            "physical_authorization_projection.behavior_evaluator_invocation_count": 1,
            "authorization_boundary.maximum_physical_steps_authorized": 0,
            "sdk_status.sdk1_completed_steps": 11,
        },
        "CONTRACT",
    )
    _verify_bound_predecessors(contract)

    runtime = contract["exact_runtime"]
    for prefix in ("console", "engine"):
        path = Path(runtime[f"{prefix}_path"])
        require(path.is_file(), f"RUNTIME_MISSING:{prefix}")
        exact(
            (path.stat().st_size, sha256(path.read_bytes())),
            (runtime[f"{prefix}_byte_length"], runtime[f"{prefix}_sha256"]),
            f"RUNTIME_CONTENT:{prefix}",
        )

    inventory = contract["source_inventory"]
    physical_paths = contract["qualified_physical_paths"]
    authored = contract["authored_source_paths"]
    for paths in (inventory, physical_paths, authored):
        verify_declared_source_inventory(ROOT, paths)
    exact((len(inventory), len(set(inventory))), (76, 76), "SOURCE_COUNT")
    exact((len(physical_paths), len(set(physical_paths))), (59, 59), "PHYSICAL_COUNT")
    exact((len(authored), len(set(authored))), (11, 11), "AUTHORED_COUNT")
    require(set(physical_paths).issubset(set(inventory)), "PHYSICAL_SUBSET")
    publication_only = contract["source_path_roles"]["publication_only_paths"]
    verify_declared_source_inventory(ROOT, publication_only)
    exact(
        tuple(publication_only),
        (
            "sdk/release/quadruped_release_contract.json",
            "sdk/release/quadruped_support_matrix.json",
        ),
        "PUBLICATION_ONLY_PATHS",
    )
    require(set(publication_only).issubset(set(inventory)), "PUBLICATION_SUBSET")
    exact(
        sorted(set(publication_only).intersection(physical_paths)),
        [],
        "PATH_ROLE_OVERLAP",
    )
    _source, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=(
            "sporespore_qsdk_r24d81_godot_jolt_guarded_command_recovery_"
            "behavior_zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D81",
    )

    _contains(
        PHYSICAL_RUNNER,
        'GateId = "QSDK-R24D81"',
        'GateToken = "R24D81"',
        "ConsolePath = [string]$contract.exact_runtime.console_path",
        "MaximumOuterSolverSteps = 2400",
        "ExpectedBehaviorEvaluatorInvocationCount = 1",
    )
    _contains(
        QUALIFICATION_RUNNER,
        "run_qsdk_core_zero_world_qualification.ps1",
        'GateId = "QSDK-R24D81"',
        "ProspectivePhysicalQuestionDeclared = $true",
    )
    _contains(
        WORKER,
        "RouteScript.apply_behavior_control_v1(",
        'cell_specs.size() == 603',
        'validated_command_count == 4824',
        '"forced_digest_failure_rejected"',
    )

    permanent_live = {
        "r24d81_question_class": "development",
        "r24d81_physical_question_declared": True,
        "r24d81_guarded_command_recovery_behavior_declared": True,
        "r24d81_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
        "r24d81_bound_r24d80_invalid_control_closure_path": (
            R80_INVALID.relative_to(ROOT).as_posix()
        ),
        "r24d81_bound_r24d79_transport_closure_path": R79.relative_to(ROOT).as_posix(),
        "r24d81_source_inventory_count": 76,
        "r24d81_qualified_physical_path_count": 59,
        "r24d81_publication_only_path_count": 2,
        "r24d81_path_role_overlap_count": 0,
        "r24d81_current_zero_world_worker_count": 1,
        "r24d81_full_seeded_ghost_required": False,
        "r24d81_additional_physical_canary_required": False,
    }
    prospective_live = {
        "next_gate_id": "QSDK-R24D81",
        "r24d81_source_status": (
            "prospective_path_role_partitioned_guarded_command_recovery_behavior_"
            "complete_zero_world_qualification_required_physics_blocked"
        ),
        "r24d81_zero_world_qualification_pending": True,
        "r24d81_zero_world_qualified": False,
        "r24d81_physical_execution_authorized": False,
        "r24d81_physical_attempt_consumed": False,
        "physical_execution_blocked_pending_r24d81_declaration": False,
        "physical_execution_blocked_until_r24d81_zero_world_qualification": True,
    }
    for relative in (
        "sdk/release/quadruped_release_contract.json",
        "sdk/release/quadruped_support_matrix.json",
    ):
        value = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(value, "r24d81_guarded_command_recovery_behavior_declared")
        exact(len(records), 1, f"LIVE_RECORD:{relative}")
        verify_exact_paths(records[0], permanent_live, f"LIVE_PERMANENT:{relative}")
        if not published:
            verify_exact_paths(records[0], prospective_live, f"LIVE_PROSPECTIVE:{relative}")

    return contract, {
        "focused_source_inventory_count": len(inventory),
        "authored_source_path_count": len(authored),
        "qualified_physical_path_count": len(physical_paths),
        "bound_predecessor_count": 2,
        "current_zero_world_worker_count": 1,
        "historical_closure_audits_executed_count": 0,
        "bespoke_physical_canary_count": 0,
        "full_seeded_physical_ghost_count": 0,
        "published_closure_observed": int(published),
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
    require(completed.returncode == 0, f"RUNTIME_IDENTITY_EXIT:{completed.returncode}")
    require(completed.stderr == "", f"RUNTIME_IDENTITY_STDERR:{completed.stderr}")
    receipt = _one_marker(completed.stdout, SUPERVISOR_MARKER)
    runtime = contract["exact_runtime"]
    verify_exact_paths(
        receipt,
        {
            "schema_version": RUNTIME_IDENTITY_SCHEMA,
            "gate_id": "QSDK-R24D81",
            "ok": True,
            "selected_console_path": runtime["console_path"],
            "selected_console_sha256": runtime["console_sha256"],
            "selected_console_byte_length": runtime["console_byte_length"],
            "worker_relative_path": BEHAVIOR_WORKER.relative_to(ROOT).as_posix(),
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
    executable = controls.validate_exact_runtime_and_inventory(ROOT, contract, 76)
    population = controls.run_zero_world_worker_specs(
        ROOT, executable, (COMMAND_POPULATION_SPEC,)
    )["r81_command_transport_population"]
    forced = population["forced_digest_failure_detail"]
    controls.require_fields(
        forced,
        {
            "failure_code": "QSDK_R24D57_COMMAND_DIGEST_INVALID",
            "expected_command_sha256": "sha256:" + "0" * 64,
            "host_write_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
        "FORCED_DIGEST_FAILURE",
    )
    runtime_identity = _run_runtime_identity(contract)
    projection = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D81"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D81",
        "sporespore_qsdk_r24d81_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": (
            "sporespore_qsdk_r24d81_godot_jolt_guarded_command_recovery_"
            "behavior_preflight_v1"
        ),
        "gate_id": "QSDK-R24D81",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["collector_id"],
        "runtime_version": contract["exact_runtime"]["runtime_profile_id"],
        **counts,
        "command_population_receipt": population,
        "production_wrapper_runtime_identity_receipt": runtime_identity,
        "supervisor_projection_receipt": projection,
        "missing_physical_switch_refusal_receipt": refusal,
        "active_command_cell_count": population["active_command_cell_count"],
        "application_pass_count": population["application_pass_count"],
        "validated_command_count": population["validated_command_count"],
        "host_write_count": population["host_write_count"],
        "host_readback_count": population["host_readback_count"],
        "digest_mismatch_count": population["digest_mismatch_count"],
        "forced_digest_failure_rejection_count": 1,
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
            "QSDK_R24D81_GODOT_JOLT_GUARDED_COMMAND_RECOVERY_BEHAVIOR_FAIL "
            f"{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
