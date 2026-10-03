#!/usr/bin/env python3
"""Compact R76 solved-contact recovery behavior audit and preflight."""

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
    "sdk/recovery/r24d76_godot_jolt_solved_contact_"
    "recovery_behavior_contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d76_godot_jolt_solved_contact_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d76_godot_jolt_solved_contact_recovery_behavior.ps1"
)
QUALIFICATION_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d76_godot_jolt_solved_contact_recovery_behavior_"
    "zero_world_qualification.ps1"
)
BEHAVIOR_WORKER = ROOT / (
    "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
CONTACT_WORKER = ROOT / (
    "tests/test_sdk_qsdk_r24d75_godot_contact_source_retention_zero_world.gd"
)
NATIVE_WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
SOURCE_MARKER = (
    "QSDK_R24D76_GODOT_JOLT_SOLVED_CONTACT_RECOVERY_BEHAVIOR_SOURCE_PASS"
)
SUPERVISOR_MARKER = (
    "QSDK_R24D76_SOLVED_CONTACT_RECOVERY_BEHAVIOR_SUPERVISOR "
)

CONTACT_SPEC = {
    "id": "r75_contact_source_retention",
    "path": CONTACT_WORKER,
    "marker": "QSDK_R24D75_GODOT_CONTACT_SOURCE_RETENTION_ZERO_WORLD ",
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
}


def _contains(path: Path, *markers: str) -> None:
    value = path.read_text(encoding="utf-8")
    require(
        all(marker in value for marker in markers),
        f"MARKERS:{path.relative_to(ROOT).as_posix()}",
    )


def _verify_predecessors(contract: dict[str, Any]) -> None:
    predecessors = contract["bound_predecessors"]
    exact(len(predecessors), 2, "PREDECESSOR_COUNT")
    for predecessor in predecessors:
        raw = source_bytes(
            ROOT, predecessor["closure_commit"], predecessor["path"]
        )
        exact(
            (len(raw), sha256(raw)),
            (predecessor["byte_length"], predecessor["raw_sha256"]),
            f"PREDECESSOR_CONTENT:{predecessor['role']}",
        )
        exact(
            git(
                ROOT,
                "rev-parse",
                f"{predecessor['closure_commit']}:{predecessor['path']}",
            ),
            predecessor["git_blob_oid"],
            f"PREDECESSOR_BLOB:{predecessor['role']}",
        )
        value = json.loads(raw)
        exact(
            value["closure_status"],
            predecessor["closure_status"],
            f"PREDECESSOR_STATUS:{predecessor['role']}",
        )
        require(
            value["decision"]["same_identity_rerun_permitted"] is False,
            f"PREDECESSOR_RERUN:{predecessor['role']}",
        )

    r70_value = json.loads(
        source_bytes(ROOT, predecessors[0]["closure_commit"], predecessors[0]["path"])
    )
    verify_exact_paths(
        r70_value,
        {
            "physical_attempt.status": "valid_complete_behavior_development",
            "physical_attempt.solver_step_count": 526,
            "causal_diagnosis.candidate_final_phase": "failed",
            "causal_diagnosis.candidate_terminal_failure_code": (
                "phase_timeout:establish_distal_support"
            ),
            "causal_diagnosis.all_526_in_run_physical_invariants_passed": True,
            "decision.scientific_negative_observed": True,
            "decision.historical_threshold_changed": False,
        },
        "R70",
    )
    r75_value = json.loads(
        source_bytes(ROOT, predecessors[1]["closure_commit"], predecessors[1]["path"])
    )
    verify_exact_paths(
        r75_value,
        {
            "physical_attempt.status": "valid_complete_integration_ghost",
            "classifier_observation.first_step_exact_contact_point_count": 8,
            "classifier_observation.second_step_exact_contact_point_count": 8,
            "classifier_observation.exact_core_digest_match_count": 2,
            "decision.scientific_positive_observed": True,
            "decision.recovery_success_observed": False,
        },
        "R75",
    )


def validate_sources() -> tuple[dict[str, Any], dict[str, int]]:
    contract = load(CONTRACT)
    verify_exact_paths(
        contract,
        {
            "schema_version": (
                "sporespore_qsdk_r24d76_godot_jolt_solved_contact_"
                "recovery_behavior_contract_v1"
            ),
            "gate_id": "QSDK-R24D76",
            "status": (
                "prospective_complete_zero_world_qualification_required_"
                "physics_blocked"
            ),
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": True,
            "controlled_change.portable_recovery_controller_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "controlled_change.behavior_worker_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.physical_envelope_changed_from_r70": False,
            "behavior_execution_contract.candidate_and_matched_zero_run_sequentially": True,
            "behavior_execution_contract.every_native_step_retains_contact_source_receipt": True,
            "complete_zero_world_gate.current_worker_count": 7,
            "complete_zero_world_gate.physical_execution_authorized": False,
            "physical_authorization_projection.seed": 278151771,
            "physical_authorization_projection.maximum_world_build_count": 2,
            "physical_authorization_projection.maximum_outer_solver_steps": 2400,
            "physical_authorization_projection.behavior_evaluator_invocation_count": 1,
            "authorization_boundary.maximum_physical_steps_authorized": 0,
        },
        "CONTRACT",
    )
    _verify_predecessors(contract)

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
            "sporespore_qsdk_r24d76_godot_jolt_solved_contact_"
            "recovery_behavior_zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D76",
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
        PHYSICAL_RUNNER,
        'GateId = "QSDK-R24D76"',
        "MaximumOuterSolverSteps = 2400",
        "ExpectedBehaviorEvaluatorInvocationCount = 1",
        "QualifiedPhysicalPaths = @($contract.qualified_physical_paths",
    )
    _contains(
        QUALIFICATION_RUNNER,
        "run_qsdk_core_zero_world_qualification.ps1",
        'GateId = "QSDK-R24D76"',
        "ProspectivePhysicalQuestionDeclared = $true",
    )

    permanent_live = {
        "r24d76_distinct_successor_required": True,
        "r24d76_question_class": "development",
        "r24d76_physical_question_declared": True,
        "r24d76_contract_path": (
            "sdk/recovery/r24d76_godot_jolt_solved_contact_"
            "recovery_behavior_contract_v1.json"
        ),
        "r24d76_portable_recovery_controller_changed": False,
        "r24d76_behavior_threshold_changed": False,
        "r24d76_full_paired_behavior_route_declared": True,
        "r24d76_additional_physical_canary_required": False,
        "r24d76_source_inventory_count": len(source_inventory),
        "r24d76_qualified_physical_path_count": len(physical_paths),
        "r24d76_development_zero_world_qualification_passed": True,
    }
    prospective_live = {
        "next_gate_id": "QSDK-R24D76",
        "r24d76_zero_world_qualification_pending": True,
        "r24d76_zero_world_qualified": False,
        "r24d76_physical_execution_authorized": False,
        "r24d76_physical_attempt_consumed": False,
        "physical_execution_blocked_pending_r24d76_declaration_and_zero_world_qualification": True,
        "physical_execution_blocked_until_r24d76_zero_world_qualification": True,
    }
    for relative in (
        "sdk/release/quadruped_release_contract.json",
        "sdk/release/quadruped_support_matrix.json",
    ):
        value = json.loads((ROOT / relative).read_text(encoding="utf-8"))
        records = records_with_key(value, "r24d76_full_paired_behavior_route_declared")
        exact(len(records), 1, f"LIVE_RECORD:{relative}")
        verify_exact_paths(records[0], permanent_live, f"LIVE_PERMANENT:{relative}")
        if not published:
            verify_exact_paths(records[0], prospective_live, f"LIVE_PROSPECTIVE:{relative}")

    return contract, {
        "focused_source_inventory_count": len(source_inventory),
        "authored_source_path_count": len(authored_paths),
        "qualified_physical_path_count": len(physical_paths),
        "bound_predecessor_count": 2,
        "current_zero_world_worker_count": 7,
        "historical_closure_audits_executed_count": 0,
        "bespoke_campaign_source_audit_mechanics_added_count": 0,
        "additional_physical_canary_count": 0,
    }


def _parse_behavior_worker(executable: str) -> None:
    parsed = subprocess.run(
        [
            executable,
            "--headless",
            "--path",
            str(ROOT),
            "--check-only",
            "--script",
            "res://" + BEHAVIOR_WORKER.relative_to(ROOT).as_posix(),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    require(
        parsed.returncode == 0,
        f"BEHAVIOR_WORKER_PARSE:{parsed.stdout}|{parsed.stderr}",
    )


def run_preflight(core_library: Path) -> dict[str, Any]:
    contract, counts = validate_sources()
    require(core_library.is_file(), "CORE_LIBRARY_MISSING")
    executable = str(contract["exact_runtime"]["console_path"])
    _parse_behavior_worker(executable)
    specs = tuple(r70.WORKER_SPECS) + (CONTACT_SPEC,)
    receipts = controls.run_zero_world_worker_specs(
        ROOT, Path(executable), specs
    )
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
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D76"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D76",
        "sporespore_qsdk_r24d76_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": (
            "sporespore_qsdk_r24d76_godot_jolt_solved_contact_"
            "recovery_behavior_preflight_v1"
        ),
        "gate_id": "QSDK-R24D76",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["collector_id"],
        "runtime_version": contract["exact_runtime"]["runtime_profile_id"],
        **counts,
        **{f"{key}_receipt": value for key, value in receipts.items()},
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
            "QSDK_R24D76_GODOT_JOLT_SOLVED_CONTACT_RECOVERY_BEHAVIOR_FAIL "
            f"{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
