#!/usr/bin/env python3
"""Compact R78 host-real command projection audit and zero-world preflight."""

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
    "sdk/recovery/r24d78_godot_jolt_host_real_recovery_behavior_contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d78_godot_jolt_host_real_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
PREDECESSOR = ROOT / (
    "sdk/recovery/r24d77_godot_jolt_runtime_bound_recovery_behavior_"
    "incomplete_closure_v1.json"
)
ROUTE = ROOT / "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
ZERO_WORKER = ROOT / (
    "tests/test_sdk_qsdk_r24d78_godot_host_real_command_projection_zero_world.gd"
)
BEHAVIOR_WORKER = ROOT / (
    "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d78_godot_jolt_host_real_recovery_behavior.ps1"
)
QUALIFICATION_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d78_godot_jolt_host_real_recovery_behavior_"
    "zero_world_qualification.ps1"
)
SOURCE_MARKER = (
    "QSDK_R24D78_GODOT_JOLT_HOST_REAL_RECOVERY_BEHAVIOR_SOURCE_PASS"
)
SUPERVISOR_MARKER = "QSDK_R24D78_HOST_REAL_RECOVERY_BEHAVIOR_SUPERVISOR "
RUNTIME_IDENTITY_SCHEMA = "sporespore_qsdk_r24d78_runtime_identity_control_v1"

HOST_REAL_SPEC = {
    "id": "r78_host_real_command_projection",
    "path": ZERO_WORKER,
    "marker": "QSDK_R24D78_GODOT_HOST_REAL_COMMAND_PROJECTION_ZERO_WORLD ",
    "expected": {
        "schema_version": (
            "sporespore_qsdk_r24d78_godot_host_real_command_projection_"
            "zero_world_v1"
        ),
        "gate_id": "QSDK-R24D78",
        "ok": True,
        "actual_production_application_count": 1,
        "validated_command_count": 8,
        "host_write_count": 8,
        "host_readback_count": 8,
        "non_binary32_exact_projection_count": 8,
        "exact_projected_readback_count": 8,
        "mutation_rejection_count": 3,
        "native_runtime_observation_collection_executed": False,
        "physical_question_opened": False,
    },
}


def _contains(path: Path, *markers: str) -> None:
    value = path.read_text(encoding="utf-8")
    require(all(marker in value for marker in markers), f"MARKERS:{path.name}")


def _verify_predecessor(contract: dict[str, Any]) -> None:
    value = controls.validate_bound_predecessor(ROOT, contract, PREDECESSOR)
    predecessor = contract["bound_predecessors"][0]
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
    verify_exact_paths(
        value,
        {
            "closure_status": predecessor["closure_status"],
            "physical_attempt.model_construction_attempt_count": 1,
            "physical_attempt.world_attempt_count": 1,
            "physical_attempt.solver_step_count": 137,
            "physical_attempt.behavior_evaluator_invocation_count": 0,
            "partial_physical_observation.in_run_invariant_receipt_count": 137,
            "partial_physical_observation.all_in_run_physical_invariants_passed": True,
            "partial_physical_observation.final_phase": "raise_body",
            "partial_physical_observation.matched_zero_arm_started": False,
            "decision.same_identity_rerun_permitted": False,
            "decision.scientific_positive_observed": False,
            "decision.scientific_negative_observed": False,
        },
        "R77",
    )


def validate_sources() -> tuple[dict[str, Any], dict[str, int]]:
    contract = load(CONTRACT)
    controls.validate_development_question(contract, "QSDK-R24D78")
    verify_exact_paths(
        contract,
        {
            "schema_version": (
                "sporespore_qsdk_r24d78_godot_jolt_host_real_"
                "recovery_behavior_contract_v1"
            ),
            "status": (
                "prospective_complete_zero_world_qualification_required_"
                "physics_blocked"
            ),
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "controlled_change.explicit_packed_float32_command_projection_added": True,
            "controlled_change.projection_applied_in_actual_behavior_command_path": True,
            "controlled_change.canonical_unprojected_projected_and_readback_values_retained": True,
            "controlled_change.exact_projected_readback_required": True,
            "controlled_change.focused_projection_negative_control_count": 3,
            "controlled_change.portable_recovery_controller_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.physical_envelope_changed_from_r77": False,
            "host_real_projection_contract.host_real_numeric_format": "ieee_754_binary32",
            "host_real_projection_contract.projection_method": "PackedFloat32Array",
            "host_real_projection_contract.binary32_relative_error_bound": 2.0**-23,
            "host_real_projection_contract.readback_comparison": "exact_equality_to_already_projected_binary32_value",
            "host_real_projection_contract.empirical_readback_tolerance_added": False,
            "host_real_projection_contract.r77_unretained_delta_used_to_fit_bound": False,
            "complete_zero_world_gate.current_worker_count": 8,
            "complete_zero_world_gate.focused_host_real_application_count": 1,
            "complete_zero_world_gate.focused_exact_projected_readback_count": 8,
            "complete_zero_world_gate.focused_projection_mutation_rejection_count": 3,
            "complete_zero_world_gate.physical_execution_authorized": False,
            "physical_authorization_projection.seed": 278151771,
            "physical_authorization_projection.maximum_world_build_count": 2,
            "physical_authorization_projection.maximum_outer_solver_steps": 2400,
            "physical_authorization_projection.behavior_evaluator_invocation_count": 1,
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
    require(set(physical_paths).issubset(set(source_inventory)), "PHYSICAL_SUBSET")
    exact(len(source_inventory), 79, "SOURCE_COUNT")
    exact(len(physical_paths), 55, "PHYSICAL_COUNT")

    _source, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=(
            "sporespore_qsdk_r24d78_godot_jolt_host_real_recovery_"
            "behavior_zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D78",
    )
    route_source = ROUTE.read_text(encoding="utf-8")
    require("const COMMAND_READBACK_TOLERANCE" not in route_source, "OLD_TOLERANCE")
    _contains(
        ROUTE,
        "const HOST_REAL_BINARY32_RELATIVE_ERROR_BOUND := 1.1920928955078125e-7",
        "static func godot_host_real_command_projection_v1(",
        "PackedFloat32Array(",
        "static func validate_godot_host_real_command_readback_v1(",
        '"QSDK_R24D78_COMMAND_READBACK_INVALID:%d"',
        '"host_real_command_projection":',
    )
    _contains(
        ZERO_WORKER,
        "RouteScript.apply_behavior_control_v1(",
        '"non_binary32_exact_projection_count"',
        '"projection_receipt_tamper"',
        '"host_readback_mismatch"',
    )
    _contains(
        PHYSICAL_RUNNER,
        'GateId = "QSDK-R24D78"',
        "ConsolePath = [string]$contract.exact_runtime.console_path",
        "MaximumOuterSolverSteps = 2400",
        "ExpectedBehaviorEvaluatorInvocationCount = 1",
    )
    _contains(
        QUALIFICATION_RUNNER,
        "run_qsdk_core_zero_world_qualification.ps1",
        'GateId = "QSDK-R24D78"',
        "ProspectivePhysicalQuestionDeclared = $true",
    )

    permanent_live = {
        "r24d78_distinct_successor_required": True,
        "r24d78_question_class": "development",
        "r24d78_physical_question_declared": True,
        "r24d78_host_real_recovery_behavior_declared": True,
        "r24d78_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
        "r24d78_bound_r24d77_incomplete_closure_path": PREDECESSOR.relative_to(ROOT).as_posix(),
        "r24d78_explicit_binary32_projection_added": True,
        "r24d78_exact_projected_readback_required": True,
        "r24d78_empirical_readback_tolerance_added": False,
        "r24d78_portable_recovery_controller_changed": False,
        "r24d78_behavior_threshold_changed": False,
        "r24d78_full_seeded_ghost_required": False,
        "r24d78_additional_physical_canary_required": False,
        "r24d78_source_inventory_count": 79,
        "r24d78_qualified_physical_path_count": 55,
        "r24d78_current_zero_world_worker_count": 8,
    }
    prospective_live = {
        "next_gate_id": "QSDK-R24D78",
        "r24d78_source_status": (
            "prospective_host_real_recovery_behavior_complete_zero_world_"
            "qualification_required_physics_blocked"
        ),
        "r24d78_zero_world_qualification_pending": True,
        "r24d78_zero_world_qualified": False,
        "r24d78_physical_execution_authorized": False,
        "r24d78_physical_attempt_consumed": False,
        "physical_execution_blocked_pending_r24d78_declaration_and_zero_world_qualification": True,
    }
    for relative in (
        "sdk/release/quadruped_release_contract.json",
        "sdk/release/quadruped_support_matrix.json",
    ):
        value = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(value, "r24d78_host_real_recovery_behavior_declared")
        exact(len(records), 1, f"LIVE_RECORD:{relative}")
        verify_exact_paths(records[0], permanent_live, f"LIVE_PERMANENT:{relative}")
        if not published:
            verify_exact_paths(records[0], prospective_live, f"LIVE_PROSPECTIVE:{relative}")

    return contract, {
        "focused_source_inventory_count": len(source_inventory),
        "authored_source_path_count": len(authored_paths),
        "qualified_physical_path_count": len(physical_paths),
        "bound_predecessor_count": 1,
        "current_zero_world_worker_count": 8,
        "focused_host_real_application_worker_count": 1,
        "historical_closure_audits_executed_count": 0,
        "bespoke_physical_canary_count": 0,
        "full_seeded_physical_ghost_count": 0,
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
            "gate_id": "QSDK-R24D78",
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
    runtime_identity = _run_runtime_identity(contract)
    executable = Path(contract["exact_runtime"]["console_path"])
    specs = tuple(r70.WORKER_SPECS) + (r76.CONTACT_SPEC, HOST_REAL_SPEC)
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
        and r75_receipt["zero_exact_contact_point_count"] == 0,
        "R75_CURRENT_CONTACT_RECEIPT",
    )
    host_receipt = receipts["r78_host_real_command_projection"]
    require(
        host_receipt["direct_projection"]["absolute_quantization_error_rad_s"] > 0.0
        and host_receipt["direct_projection"]["host_real_format"]
        == "ieee_754_binary32",
        "R78_HOST_REAL_RECEIPT",
    )
    projection = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D78"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D78",
        "sporespore_qsdk_r24d78_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": (
            "sporespore_qsdk_r24d78_godot_jolt_host_real_recovery_"
            "behavior_preflight_v1"
        ),
        "gate_id": "QSDK-R24D78",
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
            "QSDK_R24D78_GODOT_JOLT_HOST_REAL_RECOVERY_BEHAVIOR_FAIL "
            f"{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
