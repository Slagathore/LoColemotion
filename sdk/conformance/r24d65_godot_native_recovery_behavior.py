#!/usr/bin/env python3
"""Compact R65 behavior slice composed over the complete R64 route gate."""

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
from sdk.conformance import r24d64_godot_exact_net_motor_work_projection as inherited  # noqa: E402

CONTRACT = ROOT / "sdk/recovery/r24d65_godot_native_recovery_behavior_contract_v1.json"
ROUTE = ROOT / "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
WORKER = ROOT / "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
ZERO_WORKER = ROOT / "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior_zero_world.gd"
PHYSICAL_RUNNER = ROOT / "sdk/run_qsdk_r24d65_godot_native_recovery_behavior.ps1"
QUALIFICATION_RUNNER = (
    ROOT / "sdk/run_qsdk_r24d65_godot_native_recovery_behavior_zero_world_qualification.ps1"
)
SHARED_SUPERVISOR = ROOT / "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
AUTHORIZATION_PROJECTION = ROOT / "sdk/physical_authorization_projection.ps1"
SHARED_QUALIFIER = ROOT / "sdk/run_qsdk_core_zero_world_qualification.ps1"
R64_CONTRACT = ROOT / "sdk/recovery/r24d64_godot_exact_net_motor_work_projection_contract_v1.json"
SOURCE_MARKER = "QSDK_R24D65_GODOT_NATIVE_RECOVERY_BEHAVIOR_SOURCE_PASS"
ZERO_MARKER = "QSDK_R24D65_GODOT_NATIVE_RECOVERY_BEHAVIOR_ZERO_WORLD "
SUPERVISOR_MARKER = "QSDK_R24D65_BEHAVIOR_SUPERVISOR "

require = inherited.require
load = inherited.load
sha256 = inherited.sha256
markers = inherited.markers


def validate_contract() -> dict[str, Any]:
    contract = load(CONTRACT)
    require(contract["gate_id"] == "QSDK-R24D65", "CONTRACT_GATE")
    require(contract["question_class"] == "development", "QUESTION_CLASS")
    require(contract["physical_question_declared"] is True, "PHYSICAL_QUESTION")
    for key in (
        "finite_decision_declared", "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ):
        require(contract[key] is False, f"QUESTION_SCOPE:{key}")
    change = contract["controlled_change"]
    for key in (
        "world_geometry_changed", "canonical_prone_initializer_changed",
        "native_physics_or_jolt_patch_changed", "native_observation_mapping_changed",
        "native_telemetry_projection_changed", "contact_identity_projection_changed",
        "actuator_profile_changed", "controller_changed",
        "stance_controller_changed", "threshold_changed", "margin_changed",
        "evaluator_changed", "morphology_changed", "selector_changed",
        "historical_result_rewritten",
    ):
        require(change[key] is False, f"FORBIDDEN_CHANGE:{key}")
    for key in (
        "long_horizon_behavior_composition_added",
        "true_supervisor_phase_bootstrap_added",
        "matched_zero_no_actuation_transport_added",
        "exclusive_stance_owner_transport_added",
        "complete_paired_trace_retention_added",
        "in_run_physical_invariant_receipts_added",
    ):
        require(change[key] is True, f"CONTROLLED_CHANGE:{key}")
    population = contract["finite_development_population"]
    require(population["cell_count"] == 1, "CELL_COUNT")
    require(population["world_count"] == 2, "WORLD_COUNT")
    require(population["arm_count"] == 2, "ARM_COUNT")
    require(population["cell_seed"] == 260226999, "SEED")
    require(population["ordered_arms"] == [
        "candidate_command", "matched_zero_command"], "ARM_ORDER")
    require(population["maximum_outer_steps_per_arm"] == 1200, "ARM_BUDGET")
    require(population["maximum_total_outer_steps"] == 2400, "TOTAL_BUDGET")
    require(population["same_source_attempt_limit"] == 1, "ATTEMPT_LIMIT")
    for key in ("held_out", "repeatability_claimed", "population_inference_claimed",
                "cross_engine_equivalence_claimed"):
        require(population[key] is False, f"POPULATION_SCOPE:{key}")
    threshold = contract["threshold_and_margin_provenance"]
    require(threshold["profile_sha256"] ==
            "sha256:3081621eb53f4d67bc1d8dc0f3a7d3ad7ae5ed829f902bce60b01ba1530bfb34",
            "THRESHOLD_SHA")
    require(threshold["maximum_energy_balance_residual_j"] == 0.25,
            "ENERGY_THRESHOLD")
    require(threshold["required_stance_dwell_steps"] == 60, "STANCE_DWELL")
    require(threshold["stance_dwell_timeout_steps"] == 240, "STANCE_TIMEOUT")
    require(threshold["threshold_change_count"] == 0, "THRESHOLD_CHANGE")
    require(threshold["margin_change_count"] == 0, "MARGIN_CHANGE")
    ghost = contract["ghost_and_canary_adequacy"]
    require(ghost["additional_physical_route_ghost_required"] is False,
            "PHYSICAL_GHOST")
    require(ghost["full_seeded_physical_ghost_required"] is False,
            "FULL_GHOST")
    require(ghost["forced_failure_zero_world_control_required"] is True,
            "FORCED_FAILURE")
    gate = contract["complete_zero_world_gate"]
    require(gate["must_pass_before_physics"] is True, "ZERO_GATE")
    require(gate["prospectively_declared_physical_question_permitted"] is True,
            "PROSPECTIVE_PHYSICAL")
    require(gate["r65_positive_control_count"] == 4, "POSITIVE_COUNT")
    require(gate["r65_mutation_rejection_count"] == 4, "MUTATION_COUNT")
    require(gate["required_r65_mutation_ids"] == [
        "matched_zero_active_control",
        "no_actuation_command_digest_present",
        "stance_recovery_owner_overlap",
        "active_control_owner_none",
    ], "MUTATION_IDS")
    for key in ("model_construction_count", "world_attempt_count",
                "world_build_count", "solver_step_count"):
        require(gate[key] == 0, f"ZERO_GATE:{key}")
    require(gate["physical_execution_authorized"] is False,
            "ZERO_AUTHORIZATION")
    projection = contract["physical_authorization_projection"]
    expected_projection = {
        "maximum_model_construction_attempt_count": 2,
        "maximum_model_construction_count": 2,
        "maximum_world_attempt_count": 2,
        "maximum_world_build_count": 2,
        "maximum_outer_solver_steps": 2400,
        "physics_ticks_per_second": 120,
        "same_identity_rerun_permitted": False,
        "recovery_success_required": False,
        "physical_execution_authorized": False,
    }
    for key, expected in expected_projection.items():
        require(projection[key] == expected, f"PROJECTION:{key}")
    inventory = contract["source_inventory"]
    require(len(inventory) == 90 and len(inventory) == len(set(inventory)),
            "SOURCE_INVENTORY")
    for relative in inventory:
        require((ROOT / relative).is_file(), f"SOURCE_MISSING:{relative}")
    for predecessor in contract["bound_predecessors"]:
        path = ROOT / predecessor["path"]
        require(sha256(path) == predecessor["raw_sha256"],
                f"PREDECESSOR_SHA:{predecessor['gate_id']}")
        require(path.stat().st_size == predecessor["byte_length"],
                f"PREDECESSOR_SIZE:{predecessor['gate_id']}")
    return contract


def validate_sources() -> dict[str, int]:
    contract = validate_contract()
    inherited_counts = inherited.validate_sources()
    markers(WORLD, (
        'phase not in ["confirm_prone", "establish_distal_support"]',
        '"phase": phase',
        "static func initial_behavior_application_v1(",
    ))
    markers(ROUTE, (
        'const STANCE_CONTROLLER_ID := "sporespore_exact_s169_stance_handoff_controller_v1"',
        "static func initialize_behavior_arm_v1(",
        "static func advance_behavior_v4(",
        "RecoveryRuntimeScript.plan_stance_control_v3(",
        "static func initial_state_sha256_v1(",
        "static func evaluate_behavior_v4(",
        "RecoveryRuntimeScript.evaluate_trace_v4(",
        "static func apply_behavior_control_v1(",
        "static func _apply_active_control_commands_v1(",
        "static func _apply_no_actuation_control_v1(",
    ))
    markers(WORKER, (
        "MAXIMUM_OUTER_STEPS_PER_ARM := 1200",
        "MAXIMUM_TOTAL_OUTER_STEPS := 2400",
        'ARM_ORDER := ["candidate_command", "matched_zero_command"]',
        "RouteScript.advance_behavior_v4(",
        "RouteScript.apply_behavior_control_v1(",
        "RouteScript.evaluate_behavior_v4(",
        '"valid_complete_behavior_development"',
        '"recovery_success_required_for_valid_result": false',
        '"behavior_evaluator_invocation_count": 1',
        '"all_in_run_physical_invariants_passed": true',
    ))
    markers(ZERO_WORKER, (
        "initialize_behavior_arm_v1", "apply_behavior_control_v1",
        '"matched_zero_active_control"', '"stance_recovery_owner_overlap"',
        '"positive_control_count"', '"mutation_rejection_count"',
        '"model_construction_count": 0', '"solver_step_count": 0',
    ))
    markers(PHYSICAL_RUNNER, (
        'PhysicalQuestionKind = "behavior_development"',
        "MaximumWorldBuildCount = 2", "MaximumOuterSolverSteps = 2400",
        "ExpectedBehaviorEvaluatorInvocationCount = 1",
        'ValidCompleteStatus = "valid_complete_behavior_development"',
        "& $shared @arguments", "exit $LASTEXITCODE",
    ))
    markers(QUALIFICATION_RUNNER, (
        "run_qsdk_core_zero_world_qualification.ps1", 'GateId "QSDK-R24D65"',
        "-ProspectivePhysicalQuestionDeclared", "exit $LASTEXITCODE",
    ))
    markers(SHARED_SUPERVISOR, (
        '[ValidateSet("integration_ghost", "behavior_development")]',
        "$MaximumModelConstructionAttemptCount",
        "$ExpectedBehaviorEvaluatorInvocationCount",
        "$ValidCompleteStatus", "$PhysicalTimeoutSeconds",
        "behavior_development_completed",
    ))
    markers(AUTHORIZATION_PROJECTION, (
        "$MaximumModelConstructionAttemptCount",
        "$MaximumModelConstructionCount", "$MaximumWorldAttemptCount",
    ))
    markers(SHARED_QUALIFIER, (
        "$ProspectivePhysicalQuestionDeclared",
        "prospective_physical_question_declared",
    ))
    return {
        "source_inventory_count": len(contract["source_inventory"]),
        "bound_predecessor_count": len(contract["bound_predecessors"]),
        "inherited_r64_source_inventory_count":
            inherited_counts["source_inventory_count"],
        "r65_positive_control_count": 4,
        "r65_mutation_rejection_count": 4,
    }


def run_preflight(core_library: Path) -> dict[str, Any]:
    counts = validate_sources()
    inherited_receipt = inherited.run_preflight(core_library)
    contract = load(CONTRACT)
    r64_contract = load(R64_CONTRACT)
    worker = controls.run_godot_worker(
        ROOT, Path(r64_contract["exact_runtime"]["console_path"]),
        ZERO_WORKER, ZERO_MARKER)
    supervisor = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D65")
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D65",
        "sporespore_qsdk_r24d65_missing_physical_switch_refusal_v1")
    expected_worker = {
        "ok": True,
        "positive_control_count": 4,
        "positive_controls_passed": 4,
        "mutation_rejection_count": 4,
        "native_runtime_observation_collection_executed": False,
        "physical_question_opened": False,
    }
    for key, expected in expected_worker.items():
        require(worker.get(key) == expected, f"WORKER:{key}")
    require([item["mutation_id"] for item in worker["mutation_rejections"]] ==
            contract["complete_zero_world_gate"]["required_r65_mutation_ids"],
            "WORKER_MUTATION_ORDER")
    require(all(item["rejected"] for item in worker["mutation_rejections"]),
            "WORKER_MUTATION_REJECTION")
    for receipt in (inherited_receipt, worker, supervisor, refusal):
        controls.require_zero_authority(receipt)
    return {
        "schema_version":
            "sporespore_qsdk_r24d65_godot_native_recovery_behavior_preflight_v1",
        "gate_id": "QSDK-R24D65",
        "ok": True,
        "runtime_id": "sporespore_qsdk_r24d65_godot_native_recovery_behavior_v1",
        "runtime_version": "godot_4_7_jolt_instrumented_v2_exact_binary_pair",
        **counts,
        "inherited_r64_complete_preflight": inherited_receipt,
        "r65_behavior_composition_receipt": worker,
        "supervisor_projection_receipt": supervisor,
        "missing_physical_switch_refusal_receipt": refusal,
        "r65_positive_control_count": 4,
        "r65_mutation_rejection_count": 4,
        "supervisor_forced_failure_control_count": 1,
        "missing_physical_switch_refusal_count": 1,
        "additional_physical_route_ghost_required": False,
        "full_seeded_physical_ghost_required": False,
        "prospective_physical_question_declared": True,
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
        print(SOURCE_MARKER, " ".join(
            f"{key}={value}" for key, value in counts.items()))
        return 0
    print(json.dumps(run_preflight(args.core_library.resolve()),
                     allow_nan=False, separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:  # fail closed with one stable terminal marker
        print(f"QSDK_R24D65_GODOT_NATIVE_RECOVERY_BEHAVIOR_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
