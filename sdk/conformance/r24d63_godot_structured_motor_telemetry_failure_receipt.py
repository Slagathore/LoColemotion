#!/usr/bin/env python3
"""Compact R63 semantic slice composed over inherited and shared controls."""

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
from sdk.conformance import r24d62_godot_candidate_bootstrap_identity as inherited  # noqa: E402

CONTRACT = ROOT / "sdk/recovery/r24d63_godot_structured_motor_telemetry_failure_receipt_contract_v1.json"
WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
WORKER = ROOT / "tests/test_sdk_qsdk_r24d63_godot_structured_motor_telemetry_failure_receipt_zero_world.gd"
BOUND_RUNNER = ROOT / "sdk/run_qsdk_r24d63_godot_native_recovery_route_ghost.ps1"
SOURCE_MARKER = "QSDK_R24D63_GODOT_STRUCTURED_TELEMETRY_FAILURE_RECEIPT_SOURCE_PASS"
WORKER_MARKER = "QSDK_R24D63_GODOT_STRUCTURED_TELEMETRY_FAILURE_ZERO_WORLD "
SUPERVISOR_MARKER = "QSDK_R24D63_GHOST_SUPERVISOR "
INVARIANT_IDS = (
    "telemetry_dictionary", "telemetry_schema_exact",
    "captured_during_active_step", "snapshot_is_current_space_step",
    "read_space_step_sequence_positive", "capture_matches_read_space_step_sequence",
    "actuator_population_space_step_sequence_consistent", "solver_step_finite",
    "solver_step_positive", "actuator_population_solver_step_consistent",
    "signed_motor_impulse_finite", "positive_motor_work_finite",
    "absorbed_motor_work_finite", "net_motor_work_finite",
    "positive_motor_work_nonnegative", "absorbed_motor_work_nonnegative",
    "net_motor_work_identity", "signed_motor_impulse_within_outer_step_cap",
    "zero_command_signed_motor_impulse_zero",
    "zero_command_positive_motor_work_zero",
    "zero_command_absorbed_motor_work_zero",
)

require = inherited.require
load = inherited.load
sha256 = inherited.sha256
markers = inherited.markers


def validate_contract() -> dict[str, Any]:
    contract = load(CONTRACT)
    require(contract["gate_id"] == "QSDK-R24D63", "CONTRACT_GATE")
    require(contract["question_class"] == "development", "QUESTION_CLASS")
    require(contract["physical_question_declared"] is False, "PHYSICAL_QUESTION")
    require(contract["ledger_scope"] == {
        "subsystem": "recovery", "engine_scope": "godot",
        "authority_mode": "prospective_development_source",
        "question_class": "development",
    }, "LEDGER_SCOPE")
    change = contract["controlled_change"]
    for key in (
        "structured_failure_detail_added", "exact_first_failed_invariant_retained",
        "all_failed_invariant_ids_retained_in_original_order",
        "native_telemetry_values_retained_json_safely",
        "validation_inputs_and_tolerances_retained",
        "same_pure_validator_used_by_zero_world_and_physical_sampler",
    ):
        require(change[key] is True, f"CONTROLLED_CHANGE:{key}")
    for key in (
        "legacy_route_failure_codes_changed", "success_receipt_schema_or_fields_changed",
        "in_run_predicate_order_changed", "telemetry_impulse_tolerance_changed",
        "net_work_identity_tolerance_changed", "candidate_bootstrap_identity_changed",
        "contact_identity_projection_changed", "canonical_prone_pose_changed",
        "engine_neutral_core_controller_changed", "controller_gain_changed",
        "behavior_threshold_changed", "behavior_margin_changed", "morphology_changed",
        "actuator_profile_changed", "native_physics_changed", "engine_patch_changed",
        "policy_changed", "selector_changed", "evaluator_changed", "cohort_changed",
        "authorization_projection_changed", "historical_observation_rewritten",
    ):
        require(change[key] is False, f"FORBIDDEN_CHANGE:{key}")
    interface = contract["telemetry_failure_receipt_contract"]
    require(interface["validator_function"] == "native_motor_telemetry_contract_v1",
            "VALIDATOR_FUNCTION")
    require(tuple(interface["ordered_invariant_ids"]) == INVARIANT_IDS,
            "INVARIANT_IDS")
    require(interface["telemetry_impulse_tolerance_nms"] == 1.0e-6,
            "IMPULSE_TOLERANCE")
    require(interface["net_work_identity_tolerance_j"] == 1.0e-12,
            "WORK_TOLERANCE")
    expected_controls = {
        "positive_control_count": 4, "success_schema_unchanged_count": 4,
        "mutation_count": 22, "exact_failure_receipt_count": 22,
        "distinct_invariant_id_count": 21, "cap_boundary_acceptance_count": 1,
        "work_identity_boundary_acceptance_count": 1,
    }
    for key, expected in expected_controls.items():
        require(contract["zero_world_controls"][key] == expected, f"CONTROL:{key}")
    projection = contract["physical_authorization_projection"]
    require(projection["gate_id"] == "QSDK-R24D63", "PROJECTION_GATE")
    require(projection["seed"] == 1935201670 and projection["held_out"] is False,
            "PROJECTION_IDENTITY")
    require(projection["maximum_world_build_count"] == 1 and
            projection["maximum_outer_solver_steps"] == 2, "PHYSICAL_BUDGET")
    require(projection["same_identity_rerun_permitted"] is False, "RERUN")
    published = contract["published_closure_authorization_control"]
    require(published["mode"] == "AuthorizationControl", "CONTROL_MODE")
    require(published["physical_mode_requires_control_before_lock"] is True and
            published["physical_mode_rechecks_control_after_lock"] is True,
            "PUBLISHED_CONTROL")
    gate = contract["complete_zero_world_gate"]
    require(gate["must_pass_before_physics"] is True and
            gate["physical_execution_authorized"] is False, "ZERO_GATE")
    for key in ("model_construction_count", "world_attempt_count",
                "world_build_count", "solver_step_count"):
        require(gate[key] == 0, f"ZERO_GATE:{key}")
    inventory = contract["source_inventory"]
    require(len(inventory) == 71 and len(inventory) == len(set(inventory)),
            "SOURCE_INVENTORY")
    for relative in inventory:
        require((ROOT / relative).is_file(), f"SOURCE_MISSING:{relative}")
    for predecessor in contract["bound_predecessors"]:
        path = ROOT / predecessor["path"]
        require(sha256(path) == predecessor["raw_sha256"], "PREDECESSOR_SHA")
        require(path.stat().st_size == predecessor["byte_length"], "PREDECESSOR_SIZE")
    return contract


def validate_sources() -> dict[str, int]:
    contract = validate_contract()
    inherited_counts = inherited.validate_sources()
    markers(WORLD, (
        "const TELEMETRY_IMPULSE_TOLERANCE_NMS := 1.0e-6",
        "const TELEMETRY_NET_WORK_IDENTITY_TOLERANCE_J := 1.0e-12",
        "static func _telemetry_evidence_value_v1(",
        "static func _native_motor_telemetry_failure_v1(",
        '"sporespore_qsdk_r24d63_godot_native_motor_telemetry_failure_receipt_v1"',
        '"first_failed_invariant_id"', '"failed_invariant_ids"',
        '"validation_inputs"', '"telemetry": telemetry_evidence',
        "static func native_motor_telemetry_contract_v1(",
        '"telemetry_dictionary"', '"telemetry_schema_exact"',
        '"signed_motor_impulse_within_outer_step_cap"',
        '"zero_command_absorbed_motor_work_zero"',
        '"QSDK_R24D57_WORLD_TELEMETRY_INVALID:%s"',
        '"QSDK_R24D57_WORLD_ZERO_COMMAND_TELEMETRY_NONZERO:%s"',
        '"sporespore_qsdk_r24d60_godot_native_motor_telemetry_contract_v1"',
        "JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(joint.get_rid())",
        "var telemetry_contract := native_motor_telemetry_contract_v1(",
        "return telemetry_contract",
    ))
    markers(WORKER, (
        "native_motor_telemetry_contract_v1", '"missing_telemetry"',
        '"impulse_above_cap_and_tolerance"', '"zero_command_absorbed_work_nonzero"',
        '"exact_failure_receipt_count"', '"cap_evidence_exact"',
        '"nonfinite_evidence_exact"', '"world_attempt_count": 0',
        '"solver_step_count": 0',
    ))
    markers(BOUND_RUNNER, (
        'GateId = "QSDK-R24D63"', 'GateToken = "R24D63"',
        'SupervisorMarker = "QSDK_R24D63_GHOST_SUPERVISOR "',
        "Seed = 1935201670", "QualifiedPhysicalPaths = $qualifiedPhysicalPaths",
        "& $shared @arguments", "exit $LASTEXITCODE",
    ))
    return {
        "source_inventory_count": len(contract["source_inventory"]),
        "bound_predecessor_count": len(contract["bound_predecessors"]),
        "inherited_source_inventory_count": inherited_counts["source_inventory_count"],
        "telemetry_positive_control_count": 4, "telemetry_mutation_count": 22,
        "telemetry_invariant_id_count": len(INVARIANT_IDS),
    }


def run_preflight(core_library: Path) -> dict[str, Any]:
    counts = validate_sources()
    inherited_receipt = inherited.run_preflight(core_library)
    contract = load(CONTRACT)
    worker = controls.run_godot_worker(
        ROOT, Path(contract["exact_runtime"]["console_path"]), WORKER, WORKER_MARKER)
    supervisor = controls.run_projection_control(
        ROOT, BOUND_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D63")
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT, BOUND_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D63",
        "sporespore_qsdk_r24d63_missing_physical_switch_refusal_v1")
    expected_worker = {
        "ok": True, "positive_control_count": 4,
        "success_schema_unchanged_count": 4, "mutation_count": 22,
        "exact_failure_receipt_count": 22, "cap_boundary_acceptance_count": 1,
        "work_identity_boundary_acceptance_count": 1,
        "cap_evidence_exact": True, "nonfinite_evidence_exact": True,
    }
    for key, expected in expected_worker.items():
        require(worker.get(key) == expected, f"WORKER:{key}")
    for receipt in (inherited_receipt, worker, supervisor, refusal):
        controls.require_zero_authority(receipt)
    return {
        "schema_version": "sporespore_qsdk_r24d63_godot_structured_motor_telemetry_failure_receipt_preflight_v1",
        "gate_id": "QSDK-R24D63", "ok": True,
        "runtime_id": "sporespore_qsdk_r24d63_godot_native_motor_telemetry_failure_receipt_v1",
        "runtime_version": contract["exact_runtime"]["profile_id"], **counts,
        "inherited_r62_preflight": inherited_receipt,
        "structured_telemetry_receipt": worker,
        "supervisor_projection_receipt": supervisor,
        "missing_physical_switch_refusal_receipt": refusal,
        "telemetry_positive_control_count": 4,
        "telemetry_exact_failure_receipt_count": 22,
        "telemetry_distinct_invariant_id_count": 21,
        "supervisor_forced_failure_control_count": 1,
        "missing_physical_switch_refusal_count": 1,
        "native_runtime_observation_collection_executed": False,
        "held_out_cell_access_count": 0, "model_construction_count": 0,
        "world_attempt_count": 0, "world_build_count": 0, "solver_step_count": 0,
        "physics_state_modified": False, "physical_question_opened": False,
        "prone_to_standing_claimed": False, "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    if args.core_library is None:
        counts = validate_sources()
        print(SOURCE_MARKER, " ".join(f"{key}={value}"
                                      for key, value in counts.items()))
        return 0
    print(json.dumps(run_preflight(args.core_library.resolve()), allow_nan=False,
                     separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, OSError, inherited.BootstrapError, controls.ControlError,
            ValueError, json.JSONDecodeError, subprocess.SubprocessError) as error:
        print(f"QSDK_R24D63_GODOT_STRUCTURED_TELEMETRY_FAILURE_RECEIPT_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
