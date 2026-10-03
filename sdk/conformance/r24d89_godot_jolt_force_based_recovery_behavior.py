#!/usr/bin/env python3
"""Zero-world source authority for R89 force-based recovery behavior."""

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
    "sdk/recovery/r24d89_godot_jolt_force_based_recovery_behavior_"
    "contract_v1.json"
)
CLOSURE = ROOT / (
    "sdk/recovery/r24d89_godot_jolt_force_based_recovery_behavior_"
    "zero_world_qualification_closure_v1.json"
)
R85_CLOSURE = ROOT / (
    "sdk/recovery/r24d85_godot_jolt_corrected_adapter_recovery_behavior_"
    "negative_closure_v1.json"
)
R88_CLOSURE = ROOT / (
    "sdk/recovery/r24d88_godot_force_based_recovery_production_route_"
    "ghost_positive_closure_v1.json"
)
PHYSICAL_RUNNER = ROOT / (
    "sdk/run_qsdk_r24d89_godot_jolt_force_based_recovery_behavior.ps1"
)
QUALIFICATION_RUNNER = (
    "sdk/run_qsdk_r24d89_godot_jolt_force_based_recovery_behavior_"
    "zero_world_qualification.ps1"
)
WORKER = "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
SUPERVISOR = "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
SOURCE_MARKER = (
    "QSDK_R24D89_GODOT_JOLT_FORCE_BASED_RECOVERY_BEHAVIOR_SOURCE_PASS"
)
SUPERVISOR_MARKER = "QSDK_R24D89_FORCE_BASED_RECOVERY_BEHAVIOR_SUPERVISOR "
RUNTIME_IDENTITY_SCHEMA = (
    "sporespore_qsdk_r24d89_force_based_behavior_runtime_identity_v1"
)
SEED_LABEL = (
    "QSDK-R24D89/development/godot/"
    "r87-force-based-exact-nominal-prone-to-standing-paired-v1"
)
SEED_SHA256 = (
    "sha256:d17757ccf7bacc8bd0aade6d9d93886c5ccb33e8883606c5f9242cd080c044b5"
)
PROSPECTIVE_STATUS = (
    "prospective_force_based_recovery_behavior_complete_zero_world_"
    "qualification_required_physics_blocked"
)
ACTUATOR_MODE = "force_based_joint_impulse_v1"
ACTUATOR_MAPPING_ID = (
    "godot_jolt_r24d87_source_measured_force_based_joint_impulse_v1"
)
WORK_MAPPING_ID = "godot_jolt_r24d87_centered_source_measured_joint_work_v1"


def _one_marker(stdout: str, marker: str) -> dict[str, Any]:
    lines = [line for line in stdout.splitlines() if line.startswith(marker)]
    exact(len(lines), 1, "RUNTIME_IDENTITY_MARKER_COUNT")
    value = json.loads(lines[0][len(marker) :])
    require(isinstance(value, dict), "RUNTIME_IDENTITY_RECEIPT")
    return value


def _validate_predecessors(contract: dict[str, Any]) -> None:
    declarations = contract["bound_predecessors"]
    exact(len(declarations), 2, "PREDECESSOR_COUNT")
    expected = (
        (
            declarations[0],
            R85_CLOSURE,
            "closed_consumed_valid_finite_negative_corrected_adapter_"
            "raise_body_timeout_after_distal_support",
        ),
        (
            declarations[1],
            R88_CLOSURE,
            "closed_valid_complete_force_based_recovery_production_route_"
            "ghost_passed_distinct_r24d89_behavior_successor_required",
        ),
    )
    values: list[dict[str, Any]] = []
    for declaration, path, status in expected:
        raw = path.read_bytes()
        verify_exact_paths(
            declaration,
            {
                "path": path.relative_to(ROOT).as_posix(),
                "byte_length": len(raw),
                "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
                "closure_status": status,
                "same_identity_rerun_permitted": False,
                "same_identity_requalification_permitted": False,
                "historical_result_rewritten": False,
            },
            f"PREDECESSOR:{path.name}",
        )
        value = load(path)
        exact(value["closure_status"], status, f"PREDECESSOR_STATUS:{path.name}")
        values.append(value)

    verify_exact_paths(
        values[0],
        {
            "physical_attempt.status": "valid_complete_behavior_development",
            "physical_attempt.scientific_outcome": "negative",
            "physical_attempt.in_run_invariant_receipt_count": 1004,
            "decision.all_in_run_physical_invariants_passed": True,
            "decision.candidate_distal_support_completed": True,
            "decision.candidate_raise_body_timeout_observed": True,
            "decision.recovery_success_observed": False,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "R85",
    )
    verify_exact_paths(
        values[1],
        {
            "physical_attempt.status": "valid_complete_integration_ghost",
            "physical_attempt.model_construction_count": 1,
            "physical_attempt.world_build_count": 1,
            "physical_attempt.solver_step_count": 2,
            "physical_attempt.force_based_command_application_executed": True,
            "observed_integration.actuator_mode": ACTUATOR_MODE,
            "observed_integration.equal_and_opposite_body_impulse_write_count": 16,
            "decision.integration_ghost_passed": True,
            "decision.in_run_physical_invariants_passed": True,
            "decision.recovery_success_established": False,
            "claim_boundary.prone_to_standing_claimed": False,
        },
        "R88",
    )


def _validate_seed(contract: dict[str, Any]) -> None:
    question = contract["finite_behavior_question"]
    exact(question["seed_label"], SEED_LABEL, "SEED_LABEL")
    exact(
        "sha256:" + hashlib.sha256(SEED_LABEL.encode("utf-8")).hexdigest(),
        SEED_SHA256,
        "SEED_LABEL_HASH",
    )
    exact(
        (question["seed"], question["seed_sha256"]),
        (278151771, SEED_SHA256),
        "SEED_IDENTITY",
    )
    r85 = load(R85_CLOSURE)
    exact(question["seed"], r85["physical_attempt"]["seed"], "R85_SEED_REUSE")
    require(
        question["seed_label"]
        != "QSDK-R24D85/development/godot/"
        "r83-corrected-exact-nominal-prone-to-standing-paired-v1",
        "SEED_LABEL_NOT_DISTINCT",
    )


def validate_sources() -> tuple[dict[str, Any], dict[str, int], bool]:
    contract = load(CONTRACT)
    controls.validate_development_question(contract, "QSDK-R24D89")
    verify_exact_paths(
        contract,
        {
            "schema_version": (
                "sporespore_qsdk_r24d89_godot_jolt_force_based_recovery_"
                "behavior_contract_v1"
            ),
            "status": PROSPECTIVE_STATUS,
            "authored_parent_commit": "87ed7701803aef46061624b821d5006310d97fc2",
            "controlled_change.r85_valid_finite_behavior_negative_bound": True,
            "controlled_change.r88_valid_complete_force_based_production_route_bound": True,
            "controlled_change.r85_behavior_question_reused_under_distinct_campaign": True,
            "controlled_change.r85_seed_value_reused": True,
            "controlled_change.r85_portable_recovery_controller_changed": False,
            "controlled_change.r85_portable_recovery_evaluator_changed": False,
            "controlled_change.r85_behavior_threshold_changed": False,
            "controlled_change.r85_actuator_cap_changed": False,
            "controlled_change.r85_recovery_morphology_changed": False,
            "controlled_change.r85_initializer_changed": False,
            "controlled_change.r85_pose_ramp_or_timeout_changed": False,
            "controlled_change.r87_force_based_actuator_mapping_selected": True,
            "controlled_change.r87_source_measured_work_mapping_selected": True,
            "controlled_change.additional_route_ghost_required": False,
            "controlled_change.additional_physical_canary_required": False,
            "finite_behavior_question.cell_count": 1,
            "finite_behavior_question.physical_cohort_count": 1,
            "finite_behavior_question.arm_count": 2,
            "finite_behavior_question.world_count": 2,
            "finite_behavior_question.maximum_world_build_count": 2,
            "finite_behavior_question.maximum_outer_solver_steps": 2400,
            "finite_behavior_question.maximum_outer_solver_steps_per_arm": 1200,
            "finite_behavior_question.behavior_evaluator_invocation_count": 1,
            "finite_behavior_question.held_out": False,
            "behavior_execution_contract.actuator_mode": ACTUATOR_MODE,
            "behavior_execution_contract.actuator_mapping_id": ACTUATOR_MAPPING_ID,
            "behavior_execution_contract.work_mapping_id": WORK_MAPPING_ID,
            "threshold_margin_cohort_and_population_adequacy.new_behavior_threshold_count": 0,
            "threshold_margin_cohort_and_population_adequacy.equivalence_margin_count": 0,
            "threshold_margin_cohort_and_population_adequacy.population_claim_count": 0,
            "coverage_adequacy.r85_in_run_invariant_receipt_count": 1004,
            "coverage_adequacy.r85_all_in_run_physical_invariants_passed": True,
            "coverage_adequacy.r88_force_based_solver_step_count": 2,
            "coverage_adequacy.r88_force_based_body_impulse_write_count": 16,
            "coverage_adequacy.r88_force_based_route_complete": True,
            "coverage_adequacy.full_seeded_ghost_required": False,
            "coverage_adequacy.additional_physical_canary_required": False,
            "critical_path_audit_policy.source_inventory_count": 63,
            "critical_path_audit_policy.qualified_physical_path_count": 48,
            "critical_path_audit_policy.authored_source_path_count": 10,
            "critical_path_audit_policy.bound_predecessor_count": 2,
            "critical_path_audit_policy.unchanged_behavior_semantics_binding_count": 5,
            "critical_path_audit_policy.current_zero_world_worker_count": 0,
            "critical_path_audit_policy.production_worker_parse_count": 1,
            "critical_path_audit_policy.historical_closure_audits_executed_count": 0,
            "complete_zero_world_gate.production_worker_parse_count": 1,
            "complete_zero_world_gate.forced_supervisor_failure_control_count": 1,
            "complete_zero_world_gate.missing_physical_switch_refusal_count": 1,
            "complete_zero_world_gate.historical_closure_audits_executed_count": 0,
            "complete_zero_world_gate.model_construction_count": 0,
            "complete_zero_world_gate.world_attempt_count": 0,
            "complete_zero_world_gate.world_build_count": 0,
            "complete_zero_world_gate.solver_step_count": 0,
            "complete_zero_world_gate.behavior_evaluator_invocation_count": 0,
            "physical_runner.actuator_mode": ACTUATOR_MODE,
            "physical_runner.physical_question_kind": "behavior_development",
            "physical_runner.published_closure_authorization_control_required": False,
            "physical_runner.direct_committed_closure_recheck_under_operation_lock_required": True,
            "physical_authorization_projection.maximum_world_build_count": 2,
            "physical_authorization_projection.maximum_outer_solver_steps": 2400,
            "physical_authorization_projection.maximum_outer_solver_steps_per_arm": 1200,
            "physical_authorization_projection.behavior_evaluator_invocation_count": 1,
            "physical_authorization_projection.physical_execution_authorized": False,
            "claim_boundary.complete_zero_world_gate_passed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
        },
        "CONTRACT",
    )
    _validate_seed(contract)
    _validate_predecessors(contract)

    source_commit, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=(
            "sporespore_qsdk_r24d89_godot_jolt_force_based_recovery_behavior_"
            "zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D89",
    )
    semantics_source = str(contract["unchanged_behavior_semantics_source_commit"])
    for relative in contract["unchanged_behavior_semantics_paths"]:
        exact(
            source_bytes(ROOT, source_commit, relative),
            source_bytes(ROOT, semantics_source, relative),
            f"UNCHANGED_BEHAVIOR_SEMANTICS:{relative}",
        )

    bound_sources = {
        relative: source_bytes(ROOT, source_commit, relative)
        for relative in (
            WORKER,
            SUPERVISOR,
            PHYSICAL_RUNNER.relative_to(ROOT).as_posix(),
            QUALIFICATION_RUNNER,
        )
    }
    verify_bound_source_markers(
        bound_sources,
        {
            WORKER: (
                "SPORESPORE_GODOT_RECOVERY_ACTUATOR_MODE",
                'ACTUATOR_MODE_FORCE_BASED := "force_based_joint_impulse_v1"',
                "apply_behavior_control_force_based_v2",
                '"actuator_mode": _actuator_mode',
                "behavior_evaluator_invocation_count",
                "all_in_run_physical_invariants_passed",
            ),
            SUPERVISOR: (
                'ActuatorMode = "legacy_velocity_motor_v1"',
                "SPORESPORE_GODOT_RECOVERY_ACTUATOR_MODE",
                "raw.actuator_mode -ceq $actuatorModeValue",
                "ExpectedBehaviorEvaluatorInvocationCount",
            ),
            PHYSICAL_RUNNER.relative_to(ROOT).as_posix(): (
                'GateId = "QSDK-R24D89"',
                'ActuatorMode = "force_based_joint_impulse_v1"',
                'PhysicalQuestionKind = "behavior_development"',
                "MaximumOuterSolverSteps = 2400",
                "ExpectedBehaviorEvaluatorInvocationCount = 1",
            ),
            QUALIFICATION_RUNNER: (
                "run_qsdk_core_zero_world_qualification.ps1",
                'GateId = "QSDK-R24D89"',
                "ProspectivePhysicalQuestionDeclared = $true",
            ),
        },
        "BOUND_SOURCE",
    )

    inventory = contract["source_inventory"]
    verify_declared_source_inventory(ROOT, inventory)
    exact((len(inventory), len(set(inventory))), (63, 63), "SOURCE_INVENTORY")
    authored = contract["authored_source_paths"]
    exact((len(authored), len(set(authored))), (10, 10), "AUTHORED_SOURCE")
    qualified = contract["qualified_physical_paths"]
    exact((len(qualified), len(set(qualified))), (48, 48), "QUALIFIED_SOURCE")
    require(set(qualified).issubset(set(inventory)), "QUALIFIED_PATH_SUBSET")
    publication = set(contract["source_path_roles"]["publication_only_paths"])
    exact(publication.intersection(qualified), set(), "PATH_ROLE_OVERLAP")

    verify_legacy_live_authority_projection(
        ROOT,
        (
            "sdk/release/quadruped_release_contract.json",
            "sdk/release/quadruped_support_matrix.json",
        ),
        record_key="r24d89_contract_path",
        expected={
            "r24d89_question_class": "development",
            "r24d89_physical_question_declared": True,
            "r24d89_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
            "r24d89_r85_negative_closure_bound": True,
            "r24d89_r88_force_based_route_closure_bound": True,
            "r24d89_exact_r85_behavior_question_reused": True,
            "r24d89_force_based_actuator_mode_selected": True,
            "r24d89_full_seeded_ghost_required": False,
            "r24d89_additional_physical_canary_required": False,
        },
        prefix="LIVE_R89",
    )
    counts = {
        "source_inventory_count": 63,
        "authored_source_path_count": 10,
        "qualified_physical_path_count": 48,
        "bound_predecessor_count": 2,
        "unchanged_behavior_semantics_binding_count": 5,
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
    exact(completed.returncode, 0, "RUNTIME_IDENTITY_EXIT")
    exact(completed.stderr, "", "RUNTIME_IDENTITY_STDERR")
    receipt = _one_marker(completed.stdout, SUPERVISOR_MARKER)
    verify_exact_paths(
        receipt,
        {
            "schema_version": RUNTIME_IDENTITY_SCHEMA,
            "gate_id": "QSDK-R24D89",
            "ok": True,
            "selected_console_path": contract["exact_runtime"]["console_path"],
            "selected_console_sha256": contract["exact_runtime"]["console_sha256"],
            "selected_console_byte_length": contract["exact_runtime"][
                "console_byte_length"
            ],
            "worker_relative_path": WORKER,
            "worker_parse_count": 1,
            "actuator_mode": ACTUATOR_MODE,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_execution_authorized": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "RUNTIME_IDENTITY",
    )
    return receipt


def run_preflight(contract: dict[str, Any], counts: dict[str, int]) -> dict[str, Any]:
    runtime_identity = _run_runtime_identity(contract)
    projection = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D89"
    )
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT,
        PHYSICAL_RUNNER,
        SUPERVISOR_MARKER,
        "QSDK-R24D89",
        "sporespore_qsdk_r24d89_missing_physical_switch_refusal_v1",
    )
    controls.require_zero_authority(projection)
    controls.require_zero_authority(refusal)
    return {
        "schema_version": "sporespore_qsdk_r24d89_behavior_preflight_v1",
        "gate_id": "QSDK-R24D89",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["runtime_profile_id"],
        "runtime_version": contract["exact_runtime"]["runtime_version"],
        "actuator_mode": ACTUATOR_MODE,
        **counts,
        "r85_negative_closure_raw_sha256": contract["bound_predecessors"][0][
            "raw_sha256"
        ],
        "r88_force_based_route_closure_raw_sha256": contract["bound_predecessors"][
            1
        ]["raw_sha256"],
        "historical_closure_audit_reexecution_count": 0,
        "production_wrapper_runtime_identity_receipt": runtime_identity,
        "supervisor_projection_receipt": projection,
        "missing_physical_switch_refusal_receipt": refusal,
        "forced_supervisor_failure_control_count": 1,
        "missing_physical_switch_refusal_count": 1,
        "behavior_evaluator_invocation_count": 0,
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
                {"gate_id": "QSDK-R24D89", "ok": True, "published": published,
                 **counts},
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
        subprocess.SubprocessError,
        TypeError,
        ValueError,
    ) as error:
        print(f"QSDK_R24D89_SOURCE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
