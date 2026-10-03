#!/usr/bin/env python3
"""Compact R66 quaternion seam over the complete R65 zero-world gate."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import godot_recovery_route_zero_world_controls as controls  # noqa: E402
from sdk.conformance import r24d65_godot_native_recovery_behavior as inherited  # noqa: E402

CONTRACT = ROOT / "sdk/recovery/r24d66_godot_exact_quaternion_projection_contract_v1.json"
R65_INVALID = ROOT / "sdk/recovery/r24d65_godot_native_recovery_behavior_invalid_closure_v1.json"
WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
ROUTE = ROOT / "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
ZERO_WORKER = ROOT / "tests/test_sdk_qsdk_r24d66_godot_quaternion_projection_zero_world.gd"
PHYSICAL_WORKER = ROOT / "tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
PHYSICAL_RUNNER = ROOT / "sdk/run_qsdk_r24d66_godot_exact_quaternion_projection.ps1"
QUALIFICATION_RUNNER = (
    ROOT / "sdk/run_qsdk_r24d66_godot_exact_quaternion_projection_zero_world_qualification.ps1"
)
SOURCE_MARKER = "QSDK_R24D66_GODOT_EXACT_QUATERNION_PROJECTION_SOURCE_PASS"
ZERO_MARKER = "QSDK_R24D66_GODOT_QUATERNION_PROJECTION_ZERO_WORLD "
SUPERVISOR_MARKER = "QSDK_R24D66_BEHAVIOR_SUPERVISOR "

require = inherited.require
load = inherited.load
sha256 = inherited.sha256
markers = inherited.markers


def validate_contract() -> dict[str, Any]:
    contract = load(CONTRACT)
    require(contract["gate_id"] == "QSDK-R24D66", "CONTRACT_GATE")
    require(contract["question_class"] == "development", "QUESTION_CLASS")
    require(contract["physical_question_declared"] is True, "PHYSICAL_QUESTION")
    for key in (
        "finite_decision_declared", "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ):
        require(contract[key] is False, f"QUESTION_SCOPE:{key}")

    predecessors = contract["bound_predecessors"]
    require(len(predecessors) == 1, "PREDECESSOR_COUNT")
    predecessor = predecessors[0]
    require(predecessor["path"] == R65_INVALID.relative_to(ROOT).as_posix(),
            "PREDECESSOR_PATH")
    require(sha256(R65_INVALID) == predecessor["raw_sha256"],
            "PREDECESSOR_SHA")
    require(R65_INVALID.stat().st_size == predecessor["byte_length"],
            "PREDECESSOR_SIZE")
    require(predecessor["same_identity_rerun_permitted"] is False,
            "R65_RERUN")

    change = contract["controlled_change"]
    require(change["native_observation_mapping_changed"] is True,
            "ORIENTATION_MAPPING_CHANGE")
    require(change["native_observation_mapping_change_scope"] ==
            "orientation_xyzw_scalar_unit_projection_only", "MAPPING_SCOPE")
    for key in (
        "world_geometry_changed", "canonical_prone_initializer_changed",
        "native_physics_or_jolt_patch_changed",
        "native_telemetry_projection_changed", "contact_identity_projection_changed",
        "actuator_profile_changed", "controller_changed",
        "stance_controller_changed", "threshold_changed", "margin_changed",
        "evaluator_changed", "morphology_changed", "selector_changed",
        "historical_result_rewritten", "behavior_worker_changed",
        "physical_supervisor_changed",
    ):
        require(change[key] is False, f"FORBIDDEN_CHANGE:{key}")
    for key in (
        "exact_quaternion_scalar_projection_added",
        "largest_component_unit_reconstruction_added",
        "collection_refusal_quaternion_diagnostics_added",
    ):
        require(change[key] is True, f"CONTROLLED_CHANGE:{key}")

    population = contract["finite_development_population"]
    require(population["cell_count"] == 1, "CELL_COUNT")
    require(population["world_count"] == 2, "WORLD_COUNT")
    require(population["arm_count"] == 2, "ARM_COUNT")
    require(population["cell_seed"] == 1976530392, "SEED")
    require(population["seed_sha256"] ==
            "sha256:75cf75d8f8c1036398f736e9fa7fba4529abfc49ba78f14fa5551f545ae63299",
            "SEED_SHA")
    require(population["ordered_arms"] ==
            ["candidate_command", "matched_zero_command"], "ARM_ORDER")
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
    require(threshold["quaternion_norm_squared_tolerance"] == 1.0e-9,
            "QUATERNION_TOLERANCE")
    require(threshold["threshold_change_count"] == 0, "THRESHOLD_CHANGE")
    require(threshold["margin_change_count"] == 0, "MARGIN_CHANGE")

    projection = contract["quaternion_projection_contract"]
    require(projection["method_id"] ==
            "godot_real_t_to_float64_largest_component_unit_reconstruction_v1",
            "PROJECTION_METHOD")
    expected_projection = {
        "source_components_promoted_before_norm": True,
        "normalization_performed_in_exported_scalar_space": True,
        "largest_absolute_component_reconstructed": True,
        "source_component_sign_preserved": True,
        "core_tolerance_changed": False,
        "representative_projection_case_count": 4,
        "representative_nonidentity_case_count": 3,
        "expected_raw_core_refusal_count": 3,
        "expected_projected_core_acceptance_count": 4,
        "forced_zero_quaternion_refusal_count": 1,
        "structured_diagnostic_retention_count": 1,
        "exact_r65_offending_components_reconstructed_or_claimed": False,
        "exact_r65_low_level_numeric_cause_claimed": False,
    }
    for key, expected in expected_projection.items():
        require(projection[key] == expected, f"QUATERNION_PROJECTION:{key}")

    ghost = contract["ghost_and_canary_adequacy"]
    require(ghost["additional_physical_route_ghost_required"] is False,
            "PHYSICAL_GHOST")
    require(ghost["full_seeded_physical_ghost_required"] is False,
            "FULL_GHOST")
    require(ghost["forced_failure_zero_world_control_required"] is True,
            "FORCED_FAILURE")

    gate = contract["complete_zero_world_gate"]
    expected_gate = {
        "must_pass_before_physics": True,
        "prospectively_declared_physical_question_permitted": True,
        "r65_complete_preflight_replayed": True,
        "quaternion_projection_case_count": 4,
        "projected_core_acceptance_count": 4,
        "raw_core_refusal_count": 3,
        "zero_quaternion_projection_refusal_count": 1,
        "structured_diagnostic_retention_count": 1,
        "supervisor_forced_failure_control_count": 1,
        "missing_physical_switch_refusal_count": 1,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_execution_authorized": False,
        "maximum_physical_steps_authorized": 0,
    }
    for key, expected in expected_gate.items():
        require(gate[key] == expected, f"ZERO_GATE:{key}")

    authorization = contract["physical_authorization_projection"]
    expected_authorization = {
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
    for key, expected in expected_authorization.items():
        require(authorization[key] == expected, f"AUTHORIZATION:{key}")

    inventory = contract["source_inventory"]
    require(len(inventory) == 100, "SOURCE_INVENTORY_COUNT")
    require(inventory == sorted(set(inventory)), "SOURCE_INVENTORY_ORDER")
    for relative in inventory:
        require((ROOT / relative).is_file(), f"SOURCE_MISSING:{relative}")
    return contract


def validate_sources() -> dict[str, int]:
    contract = validate_contract()
    inherited_counts = inherited.validate_sources()
    markers(WORLD, (
        '"sporespore_qsdk_r24d66_godot_quaternion_scalar_projection_v1"',
        "CORE_QUATERNION_NORM_SQUARED_TOLERANCE := 1.0e-9",
        "quaternion_projection_receipts",
        "static func project_quaternion_to_unit_scalar_v1(",
        '"godot_real_t_to_float64_largest_component_unit_reconstruction_v1"',
        '"reconstructed_component_index"',
        "static func diagnose_orientation_xyzw_v1(",
    ))
    markers(ROUTE, (
        'failure_detail["base_orientation_diagnostic"]',
        "NativeWorldScript.diagnose_orientation_xyzw_v1(orientation_value)",
        'return _failure("QSDK_R24D65_BEHAVIOR_COLLECTION_REFUSED", failure_detail)',
    ))
    markers(ZERO_WORKER, (
        "project_quaternion_to_unit_scalar_v1",
        "RecoveryRuntimeScript.collect_native_v3",
        '"projected_core_acceptance_count"',
        '"raw_core_refusal_count"',
        '"zero_projection_refusal_count"',
        '"diagnostic_retention_count"',
        '"model_construction_count": 0',
        '"solver_step_count": 0',
    ))
    markers(PHYSICAL_WORKER, (
        'GENERIC_GATE_ID_ENV := "SPORESPORE_GODOT_RECOVERY_GATE_ID"',
        'GENERIC_RAW_SCHEMA_ENV := "SPORESPORE_GODOT_RECOVERY_RAW_SCHEMA"',
        "RouteScript.advance_behavior_v4(",
        '"all_in_run_physical_invariants_passed": true',
    ))
    markers(PHYSICAL_RUNNER, (
        'GateId = "QSDK-R24D66"',
        'PhysicalQuestionKind = "behavior_development"',
        "MaximumWorldBuildCount = 2", "MaximumOuterSolverSteps = 2400",
        "ExpectedBehaviorEvaluatorInvocationCount = 1",
        "& $shared @arguments", "exit $LASTEXITCODE",
    ))
    markers(QUALIFICATION_RUNNER, (
        "run_qsdk_core_zero_world_qualification.ps1", 'GateId "QSDK-R24D66"',
        "-ProspectivePhysicalQuestionDeclared", "exit $LASTEXITCODE",
    ))
    return {
        "source_inventory_count": len(contract["source_inventory"]),
        "bound_predecessor_count": len(contract["bound_predecessors"]),
        "inherited_r65_source_inventory_count":
            inherited_counts["source_inventory_count"],
        "quaternion_projection_case_count": 4,
        "raw_core_refusal_count": 3,
        "projected_core_acceptance_count": 4,
        "zero_quaternion_projection_refusal_count": 1,
        "structured_diagnostic_retention_count": 1,
    }


def run_preflight(core_library: Path) -> dict[str, Any]:
    counts = validate_sources()
    inherited_receipt = inherited.run_preflight(core_library)
    contract = load(CONTRACT)
    worker = controls.run_godot_worker(
        ROOT, Path(contract["exact_runtime"]["console_path"]),
        ZERO_WORKER, ZERO_MARKER)
    supervisor = controls.run_projection_control(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D66")
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT, PHYSICAL_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D66",
        "sporespore_qsdk_r24d66_missing_physical_switch_refusal_v1")
    expected_worker = {
        "ok": True,
        "projection_case_count": 4,
        "projected_core_acceptance_count": 4,
        "raw_core_refusal_count": 3,
        "zero_projection_refusal_count": 1,
        "diagnostic_retention_count": 1,
        "native_runtime_observation_collection_executed": False,
        "physical_question_opened": False,
    }
    for key, expected in expected_worker.items():
        require(worker.get(key) == expected, f"WORKER:{key}")
    require(all(item["projected_unit_delta"] <= 1.0e-9
                for item in worker["projection_receipts"]),
            "WORKER_PROJECTED_UNIT_DELTA")
    require(worker["zero_projection_refusal"]["refusal_reason"] ==
            "nonpositive_source_norm_squared", "WORKER_ZERO_REFUSAL")
    diagnostic = worker["diagnostic_retention_receipt"]
    require(set(diagnostic["source_orientation_xyzw"]) == {"x", "y", "z", "w"},
            "WORKER_DIAGNOSTIC_COMPONENTS")
    require(diagnostic["within_core_unit_contract"] is False,
            "WORKER_DIAGNOSTIC_REFUSAL")
    for receipt in (inherited_receipt, worker, supervisor, refusal):
        controls.require_zero_authority(receipt)
    return {
        "schema_version":
            "sporespore_qsdk_r24d66_godot_exact_quaternion_projection_preflight_v1",
        "gate_id": "QSDK-R24D66",
        "ok": True,
        "runtime_id": "sporespore_qsdk_r24d66_godot_exact_quaternion_projection_v1",
        "runtime_version": "godot_4_7_jolt_instrumented_v2_exact_binary_pair",
        **counts,
        "inherited_r65_complete_preflight": inherited_receipt,
        "r66_quaternion_projection_receipt": worker,
        "supervisor_projection_receipt": supervisor,
        "missing_physical_switch_refusal_receipt": refusal,
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
    except Exception as error:
        print(f"QSDK_R24D66_GODOT_EXACT_QUATERNION_PROJECTION_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
