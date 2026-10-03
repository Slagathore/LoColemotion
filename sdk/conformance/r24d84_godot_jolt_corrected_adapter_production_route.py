#!/usr/bin/env python3
"""Compact R84 source audit and zero-world production-route preflight."""

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

from sdk.conformance import godot_recovery_route_zero_world_controls as controls  # noqa: E402
from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    load,
    require,
    resolve_prospective_source_freeze,
    source_bytes,
    verify_bound_source_markers,
    verify_declared_source_inventory,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)

CONTRACT = ROOT / (
    "sdk/recovery/r24d84_godot_jolt_corrected_adapter_"
    "production_route_contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d84_godot_jolt_corrected_adapter_production_route_"
    "zero_world_qualification_closure_v1.json"
)
R83_CLOSURE = ROOT / (
    "sdk/recovery/r24d83_godot_jolt_adapter_semantics_"
    "zero_world_qualification_closure_v1.json"
)
WORLD = "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
ROUTE = "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
SUPERVISOR = "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
WORKER = "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d84_godot_jolt_corrected_adapter_production_route.ps1"
)
QUALIFICATION_RUNNER = (
    "sdk/run_qsdk_r24d84_godot_jolt_corrected_adapter_production_route_"
    "zero_world_qualification.ps1"
)
SOURCE_MARKER = (
    "QSDK_R24D84_GODOT_JOLT_CORRECTED_ADAPTER_PRODUCTION_ROUTE_SOURCE_PASS"
)
SUPERVISOR_MARKER = "QSDK_R24D84_CORRECTED_ADAPTER_ROUTE_SUPERVISOR "
RUNTIME_IDENTITY_SCHEMA = (
    "sporespore_qsdk_r24d84_corrected_adapter_route_runtime_identity_v1"
)
PROSPECTIVE_STATUS = (
    "prospective_corrected_adapter_production_route_complete_zero_world_"
    "qualification_required_physics_blocked"
)
QUALIFIED_STATUS = (
    "closed_complete_zero_world_corrected_adapter_production_route_qualified_"
    "one_two_step_development_ghost_authorized"
)


def _one_marker(stdout: str, marker: str) -> dict[str, Any]:
    lines = [line for line in stdout.splitlines() if line.startswith(marker)]
    exact(len(lines), 1, "RUNTIME_IDENTITY_MARKER_COUNT")
    value = json.loads(lines[0][len(marker) :])
    require(isinstance(value, dict), "RUNTIME_IDENTITY_RECEIPT")
    return value


def _validate_seed(contract: dict[str, Any]) -> None:
    question = contract["route_ghost_question"]
    label = str(question["seed_label"])
    digest = hashlib.sha256(label.encode("utf-8")).hexdigest()
    derived = int(digest[:8], 16) & 0x7FFFFFFF
    exact(
        (
            question["seed_derivation_rule"],
            question["seed_sha256"],
            question["seed"],
        ),
        (
            "uint32(first_8_sha256_hex_of_utf8_seed_label) & 0x7fffffff",
            f"sha256:{digest}",
            derived,
        ),
        "SEED",
    )


def _validate_predecessor(contract: dict[str, Any]) -> dict[str, Any]:
    predecessor = controls.validate_bound_predecessor(ROOT, contract, R83_CLOSURE)
    verify_exact_paths(
        predecessor,
        {
            "closure_status": (
                "closed_complete_zero_world_adapter_semantics_qualified_"
                "physics_blocked_pending_distinct_route_successor"
            ),
            "question_class": "development",
            "physical_question_declared": False,
            "qualification.official_zero_world_qualification_passed": True,
            "qualification.joint_projection_count": 8,
            "qualification.exact_joint_property_readback_count": 8,
            "qualification.joint_mutation_rejection_count": 9,
            "qualification.collision_property_readback_count": 6,
            "qualification.collision_mutation_rejection_count": 3,
            "qualification.historical_closure_audits_executed_count": 0,
            "qualification.model_construction_count": 0,
            "qualification.world_attempt_count": 0,
            "qualification.world_build_count": 0,
            "qualification.solver_step_count": 0,
            "decision.physical_execution_authorized": False,
            "decision.physical_attempted": False,
            "decision.prone_to_standing_claimed": False,
        },
        "R83",
    )
    return predecessor


def validate_sources() -> tuple[dict[str, Any], dict[str, int], bool]:
    contract = load(CONTRACT)
    verify_exact_paths(
        contract,
        {
            "schema_version": (
                "sporespore_qsdk_r24d84_godot_jolt_corrected_adapter_"
                "production_route_contract_v1"
            ),
            "gate_id": "QSDK-R24D84",
            "status": PROSPECTIVE_STATUS,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": True,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "controlled_change.r83_qualified_adapter_semantics_bound": True,
            "controlled_change.actual_production_world_builder_selected": True,
            "controlled_change.actual_production_route_selected": True,
            "controlled_change.existing_generic_two_step_worker_reused": True,
            "controlled_change.existing_serial_physical_supervisor_reused": True,
            "controlled_change.portable_recovery_controller_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.native_world_builder_changed_from_r83": False,
            "controlled_change.native_route_changed_from_r83": False,
            "controlled_change.physical_worker_changed_from_r83": False,
            "route_ghost_question.world_count": 1,
            "route_ghost_question.maximum_model_construction_count": 1,
            "route_ghost_question.maximum_world_build_count": 1,
            "route_ghost_question.maximum_outer_solver_steps": 2,
            "route_ghost_question.minimum_completed_solver_steps_for_valid_route": 2,
            "route_ghost_question.behavior_evaluator_invocation_count": 0,
            "route_ghost_question.full_seeded_world_demo": False,
            "route_ghost_question.recovery_success_required": False,
            "route_ghost_question.same_source_attempt_limit": 1,
            "coverage_adequacy.new_behavior_threshold_count": 0,
            "coverage_adequacy.new_margin_count": 0,
            "coverage_adequacy.physical_population_claim_count": 0,
            "complete_zero_world_gate.r83_closure_binding_count": 1,
            "complete_zero_world_gate.r83_closure_audit_reexecution_count": 0,
            "complete_zero_world_gate.production_worker_parse_count": 1,
            "complete_zero_world_gate.forced_supervisor_failure_control_count": 1,
            "complete_zero_world_gate.missing_physical_switch_refusal_count": 1,
            "complete_zero_world_gate.historical_closure_audits_executed_count": 0,
            "complete_zero_world_gate.model_construction_count": 0,
            "complete_zero_world_gate.world_attempt_count": 0,
            "complete_zero_world_gate.world_build_count": 0,
            "complete_zero_world_gate.solver_step_count": 0,
            "complete_zero_world_gate.physical_execution_authorized": False,
            "physical_runner.published_closure_authorization_control_required": False,
            "physical_runner.direct_committed_closure_recheck_under_operation_lock_required": True,
            "physical_runner.qualified_physical_source_drift_check_required": True,
            "physical_authorization_projection.maximum_world_build_count": 1,
            "physical_authorization_projection.maximum_outer_solver_steps": 2,
            "physical_authorization_projection.behavior_evaluator_invocation_count": 0,
            "physical_authorization_projection.physical_execution_authorized": False,
            "claim_boundary.complete_zero_world_gate_passed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
        },
        "CONTRACT",
    )
    _validate_seed(contract)
    _validate_predecessor(contract)
    source_commit, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=(
            "sporespore_qsdk_r24d84_godot_jolt_corrected_adapter_"
            "production_route_zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D84",
    )

    unchanged_commit = str(contract["unchanged_route_source_commit"])
    exact(unchanged_commit, contract["authored_parent_commit"], "UNCHANGED_COMMIT")
    for relative in contract["unchanged_route_paths"]:
        exact(
            source_bytes(ROOT, source_commit, relative),
            source_bytes(ROOT, unchanged_commit, relative),
            f"UNCHANGED_ROUTE:{relative}",
        )

    bound_sources = {
        relative: source_bytes(ROOT, source_commit, relative)
        for relative in (
            WORLD,
            ROUTE,
            SUPERVISOR,
            WORKER,
            PHYSICAL_RUNNER.relative_to(ROOT).as_posix(),
            QUALIFICATION_RUNNER,
        )
    }
    verify_bound_source_markers(
        bound_sources,
        {
            WORLD: (
                "const CANONICAL_TO_GODOT_HOST_JOINT_SIGN := -1.0",
                "const RECOVERY_FLOOR_COLLISION_LAYER := 1",
                "const RECOVERY_FLOOR_COLLISION_MASK := 2",
                "const RECOVERY_ROBOT_COLLISION_LAYER := 2",
                "const RECOVERY_ROBOT_COLLISION_MASK := 1",
                "host_limit_projection_by_joint_id[joint_id] = host_limit_projection",
                '"collision_filter_readback": collision_filter_readback',
            ),
            ROUTE: (
                "static func build_native_world_v1(",
                "static func collect_native_world_observation_v1(",
                "static func apply_control_v1(",
            ),
            SUPERVISOR: (
                "function Invoke-R57RuntimeIdentity",
                "function Invoke-R57Preflight",
                "function Invoke-R57Physical",
                "qualified_physical_source_drift",
            ),
            WORKER: (
                "const MAXIMUM_SOLVER_STEPS := 2",
                "RouteScript.build_native_world_v1(self, _sdk, _context)",
                "func _capture_first_step() -> void:",
                "func _capture_second_step_and_finish() -> void:",
                '"portable_command_application_count": 1',
            ),
            PHYSICAL_RUNNER.relative_to(ROOT).as_posix(): (
                'GateId = "QSDK-R24D84"',
                'PhysicalQuestionKind = "integration_ghost"',
                "MaximumOuterSolverSteps = 2",
                "QualifiedPhysicalPaths",
            ),
            QUALIFICATION_RUNNER: (
                "run_qsdk_core_zero_world_qualification.ps1",
                'GateId = "QSDK-R24D84"',
                "ProspectivePhysicalQuestionDeclared = $true",
            ),
        },
        "SOURCE_MARKERS",
    )

    inventory = contract["source_inventory"]
    verify_declared_source_inventory(ROOT, inventory)
    exact(
        len(inventory),
        contract["critical_path_audit_policy"]["source_inventory_count"],
        "SOURCE_INVENTORY_COUNT",
    )
    controls.validate_exact_runtime_and_inventory(ROOT, contract, len(inventory))
    qualified = contract["qualified_physical_paths"]
    exact(len(qualified), len(set(qualified)), "QUALIFIED_PATH_UNIQUE")
    exact(
        len(qualified),
        contract["critical_path_audit_policy"]["qualified_physical_path_count"],
        "QUALIFIED_PATH_COUNT",
    )
    require(set(qualified).issubset(set(inventory)), "QUALIFIED_PATH_SUBSET")
    publication = set(contract["source_path_roles"]["publication_only_paths"])
    exact(publication.intersection(qualified), set(), "PATH_ROLE_OVERLAP")
    exact(
        len(contract["authored_source_paths"]),
        contract["critical_path_audit_policy"]["authored_source_path_count"],
        "AUTHORED_PATH_COUNT",
    )

    live_expected: dict[str, Any] = {
        "next_gate_id": "QSDK-R24D84",
        "r24d84_distinct_successor_required": False,
        "r24d84_question_class": "development",
        "r24d84_physical_question_declared": True,
        "r24d84_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
        "r24d84_source_status": QUALIFIED_STATUS if published else PROSPECTIVE_STATUS,
        "r24d84_r83_zero_world_closure_bound": True,
        "r24d84_actual_production_route_selected": True,
        "r24d84_smallest_coverage_adequate_route_ghost_required": True,
        "r24d84_maximum_world_build_count": 1,
        "r24d84_maximum_outer_solver_steps": 2,
        "r24d84_full_seeded_ghost_required": False,
        "r24d84_additional_physical_canary_required": False,
        "r24d84_zero_world_qualification_pending": not published,
        "r24d84_zero_world_qualified": published,
        "r24d84_physical_execution_authorized": published,
        "physical_execution_blocked_pending_r24d84_declaration": False,
        "physical_execution_blocked_until_r24d84_zero_world_qualification": (
            not published
        ),
    }
    if published:
        live_expected.update(
            {
                "r24d84_source_commit": source_commit,
                "r24d84_zero_world_closure_path": CLOSURE.relative_to(ROOT).as_posix(),
                "r24d84_official_qualification_attempt_count": 1,
            }
        )
    verify_legacy_live_authority_projection(
        ROOT,
        (
            "sdk/release/quadruped_release_contract.json",
            "sdk/release/quadruped_support_matrix.json",
        ),
        record_key="r24d84_contract_path",
        expected=live_expected,
        prefix="LIVE_R84",
    )
    counts = {
        "source_inventory_count": len(inventory),
        "authored_source_path_count": len(contract["authored_source_paths"]),
        "qualified_physical_path_count": len(qualified),
        "bound_predecessor_count": 1,
        "current_zero_world_worker_count": 0,
        "production_worker_parse_count": 1,
        "historical_closure_audits_executed_count": 0,
        "full_seeded_ghost_count": 0,
        "bespoke_physical_canary_count": 0,
    }
    return contract, counts, published


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
    verify_exact_paths(
        receipt,
        {
            "schema_version": RUNTIME_IDENTITY_SCHEMA,
            "gate_id": "QSDK-R24D84",
            "ok": True,
            "selected_console_path": contract["exact_runtime"]["console_path"],
            "selected_console_sha256": contract["exact_runtime"]["console_sha256"],
            "selected_console_byte_length": contract["exact_runtime"][
                "console_byte_length"
            ],
            "worker_relative_path": WORKER,
            "worker_parse_count": 1,
            "source_audit_execution_count": 0,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_execution_authorized": False,
        },
        "RUNTIME_IDENTITY",
    )
    controls.require_zero_authority(receipt)
    return receipt


def run_preflight(contract: dict[str, Any], counts: dict[str, int]) -> dict[str, Any]:
    runtime_identity = _run_runtime_identity(contract)
    projection = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D84"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D84",
        "sporespore_qsdk_r24d84_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": "sporespore_qsdk_r24d84_route_preflight_v1",
        "gate_id": "QSDK-R24D84",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["runtime_profile_id"],
        "runtime_version": contract["exact_runtime"]["runtime_version"],
        **counts,
        "r83_closure_raw_sha256": contract["bound_predecessors"][0]["raw_sha256"],
        "r83_closure_audit_reexecution_count": 0,
        "production_wrapper_runtime_identity_receipt": runtime_identity,
        "supervisor_projection_receipt": projection,
        "missing_physical_switch_refusal_receipt": refusal,
        "forced_supervisor_failure_control_count": 1,
        "missing_physical_switch_refusal_count": 1,
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
    parser = argparse.ArgumentParser()
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    contract, counts, published = validate_sources()
    if args.core_library is None:
        print(
            SOURCE_MARKER,
            json.dumps(
                {
                    "gate_id": "QSDK-R24D84",
                    "ok": True,
                    "published": published,
                    **counts,
                },
                sort_keys=True,
            ),
        )
        return 0
    require(args.core_library.is_file(), "CORE_LIBRARY_MISSING")
    print(json.dumps(run_preflight(contract, counts), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        ClosureAuditError,
        controls.ControlError,
        AssertionError,
        KeyError,
        OSError,
        TypeError,
        ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(
            f"QSDK_R24D84_GODOT_JOLT_CORRECTED_ADAPTER_ROUTE_FAIL:{error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
