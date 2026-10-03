#!/usr/bin/env python3
"""Compact R64 semantic slice composed over R63 and shared controls."""

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
from sdk.conformance import r24d63_godot_structured_motor_telemetry_failure_receipt as inherited  # noqa: E402

CONTRACT = ROOT / "sdk/recovery/r24d64_godot_exact_net_motor_work_projection_contract_v1.json"
WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
WORKER = ROOT / "tests/test_sdk_qsdk_r24d64_godot_exact_net_motor_work_projection_zero_world.gd"
BOUND_RUNNER = ROOT / "sdk/run_qsdk_r24d64_godot_native_recovery_route_ghost.ps1"
SOURCE_MARKER = "QSDK_R24D64_GODOT_EXACT_NET_MOTOR_WORK_PROJECTION_SOURCE_PASS"
WORKER_MARKER = "QSDK_R24D64_GODOT_EXACT_NET_WORK_PROJECTION_ZERO_WORLD "
SUPERVISOR_MARKER = "QSDK_R24D64_GHOST_SUPERVISOR "

require = inherited.require
load = inherited.load
sha256 = inherited.sha256
markers = inherited.markers


def validate_contract() -> dict[str, Any]:
    contract = load(CONTRACT)
    require(contract["gate_id"] == "QSDK-R24D64", "CONTRACT_GATE")
    require(contract["question_class"] == "development", "QUESTION_CLASS")
    require(contract["physical_question_declared"] is False, "PHYSICAL_QUESTION")
    require(contract["ledger_scope"] == {
        "subsystem": "recovery", "engine_scope": "godot",
        "authority_mode": "prospective_development_source",
        "question_class": "development",
    }, "LEDGER_SCOPE")
    change = contract["controlled_change"]
    for key in (
        "exact_native_positive_motor_work_preserved",
        "exact_native_absorbed_motor_work_preserved",
        "exact_raw_native_net_motor_work_preserved",
        "native_float32_net_identity_checked_before_projection",
        "public_net_work_derived_from_exported_binary64_components",
        "projection_delta_retained", "same_r63_validator_used_after_projection",
        "physical_sampler_calls_exact_projection_then_validator",
    ):
        require(change[key] is True, f"CONTROLLED_CHANGE:{key}")
    for key in (
        "legacy_route_failure_codes_changed", "r63_validator_predicate_order_changed",
        "telemetry_impulse_tolerance_changed", "net_work_identity_tolerance_changed",
        "native_positive_or_absorbed_measurement_changed",
        "native_engine_telemetry_patch_changed", "candidate_bootstrap_identity_changed",
        "contact_identity_projection_changed", "canonical_prone_pose_changed",
        "engine_neutral_core_controller_changed", "controller_gain_changed",
        "behavior_threshold_changed", "behavior_margin_changed", "morphology_changed",
        "actuator_profile_changed", "native_physics_changed", "policy_changed",
        "selector_changed", "evaluator_changed", "cohort_changed",
        "authorization_projection_changed", "historical_observation_rewritten",
    ):
        require(change[key] is False, f"FORBIDDEN_CHANGE:{key}")
    projection = contract["net_motor_work_projection_contract"]
    require(projection["projection_function"] == "native_motor_work_projection_v1",
            "PROJECTION_FUNCTION")
    require(projection["native_float32_source_identity_is_exact_equality"] is True,
            "SOURCE_IDENTITY")
    require(projection["native_float32_source_identity_tolerance_count"] == 0,
            "SOURCE_IDENTITY_TOLERANCE")
    require(projection["unchanged_net_work_identity_tolerance_j"] == 1.0e-12,
            "WORK_TOLERANCE")
    require(projection["r63_projection_delta_j"] == 4.001776687800884e-11,
            "R63_DELTA")
    expected_controls = {
        "positive_control_count": 4, "binary64_identity_count": 4,
        "mismatch_mutation_count": 2, "mismatch_mutation_rejection_count": 2,
        "passthrough_control_count": 3, "r63_replay_count": 1,
        "r63_replay_exact": True,
    }
    for key, expected in expected_controls.items():
        require(contract["zero_world_controls"][key] == expected, f"CONTROL:{key}")
    authorization = contract["physical_authorization_projection"]
    require(authorization["gate_id"] == "QSDK-R24D64", "AUTHORIZATION_GATE")
    require(authorization["seed"] == 491850074 and authorization["held_out"] is False,
            "AUTHORIZATION_IDENTITY")
    require(authorization["maximum_world_build_count"] == 1 and
            authorization["maximum_outer_solver_steps"] == 2, "PHYSICAL_BUDGET")
    require(authorization["same_identity_rerun_permitted"] is False, "RERUN")
    published = contract["published_closure_authorization_control"]
    require(published["mode"] == "AuthorizationControl", "CONTROL_MODE")
    require(published["control_must_close_before_physical_authority"] is True,
            "PUBLISHED_CONTROL")
    gate = contract["complete_zero_world_gate"]
    require(gate["must_pass_before_physics"] is True and
            gate["physical_execution_authorized"] is False, "ZERO_GATE")
    for key in ("model_construction_count", "world_attempt_count",
                "world_build_count", "solver_step_count"):
        require(gate[key] == 0, f"ZERO_GATE:{key}")
    inventory = contract["source_inventory"]
    require(len(inventory) == 81 and len(inventory) == len(set(inventory)),
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
        "static func _native_float32_subtract_v1(",
        "static func native_motor_work_projection_v1(",
        '"sporespore_qsdk_r24d64_godot_native_net_motor_work_projection_v1"',
        '"QSDK_R24D64_WORLD_NATIVE_NET_WORK_FLOAT32_IDENTITY_INVALID:%s"',
        'projected_telemetry["native_net_motor_work_j"] = native_net_work',
        'projected_telemetry["net_motor_work_j"] = projected_net',
        '"sporespore_qsdk_r24d64_native_float32_to_binary64_net_work_projection_v1"',
        "static func native_motor_telemetry_contract_v1(",
        "JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(joint.get_rid())",
        "var work_projection := native_motor_work_projection_v1(",
        'telemetry_value = work_projection["telemetry"]',
        "var telemetry_contract := native_motor_telemetry_contract_v1(",
        '"native_net_motor_work_j": native_net_work',
        '"net_motor_work_projection_delta_j": net_work_projection_delta',
    ))
    markers(WORKER, (
        "native_motor_work_projection_v1", "native_motor_telemetry_contract_v1",
        '"mismatch_mutation_count": 2', '"passthrough_control_count"',
        '"r63_replay_exact"', '"threshold_changed": false',
        '"world_attempt_count": 0', '"solver_step_count": 0',
    ))
    markers(BOUND_RUNNER, (
        'GateId = "QSDK-R24D64"', 'GateToken = "R24D64"',
        'SupervisorMarker = "QSDK_R24D64_GHOST_SUPERVISOR "',
        "Seed = 491850074", "QualifiedPhysicalPaths = $qualifiedPhysicalPaths",
        "& $shared @arguments", "exit $LASTEXITCODE",
    ))
    return {
        "source_inventory_count": len(contract["source_inventory"]),
        "bound_predecessor_count": len(contract["bound_predecessors"]),
        "inherited_source_inventory_count": inherited_counts["source_inventory_count"],
        "projection_positive_control_count": 4, "projection_mutation_count": 2,
        "projection_passthrough_control_count": 3,
    }


def run_preflight(core_library: Path) -> dict[str, Any]:
    counts = validate_sources()
    inherited_receipt = inherited.run_preflight(core_library)
    contract = load(CONTRACT)
    worker = controls.run_godot_worker(
        ROOT, Path(contract["exact_runtime"]["console_path"]), WORKER, WORKER_MARKER)
    supervisor = controls.run_projection_control(
        ROOT, BOUND_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D64")
    refusal = controls.run_missing_physical_switch_refusal(
        ROOT, BOUND_RUNNER, SUPERVISOR_MARKER, "QSDK-R24D64",
        "sporespore_qsdk_r24d64_missing_physical_switch_refusal_v1")
    expected_worker = {
        "ok": True, "positive_control_count": 4, "binary64_identity_count": 4,
        "mismatch_mutation_count": 2, "mismatch_mutation_rejection_count": 2,
        "passthrough_control_count": 3, "r63_replay_count": 1,
        "r63_replay_exact": True, "threshold_changed": False,
        "native_positive_or_absorbed_measurement_changed": False,
        "native_physics_changed": False,
    }
    for key, expected in expected_worker.items():
        require(worker.get(key) == expected, f"WORKER:{key}")
    for receipt in (inherited_receipt, worker, supervisor, refusal):
        controls.require_zero_authority(receipt)
    return {
        "schema_version": "sporespore_qsdk_r24d64_godot_exact_net_motor_work_projection_preflight_v1",
        "gate_id": "QSDK-R24D64", "ok": True,
        "runtime_id": "sporespore_qsdk_r24d64_native_float32_to_binary64_net_work_projection_v1",
        "runtime_version": contract["exact_runtime"]["profile_id"], **counts,
        "inherited_r63_preflight": inherited_receipt,
        "net_motor_work_projection_receipt": worker,
        "supervisor_projection_receipt": supervisor,
        "missing_physical_switch_refusal_receipt": refusal,
        "projection_positive_control_count": 4,
        "projection_binary64_identity_count": 4,
        "projection_mutation_count": 2,
        "projection_mutation_rejection_count": 2,
        "projection_passthrough_control_count": 3,
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
    except (KeyError, OSError, inherited.inherited.BootstrapError,
            controls.ControlError, ValueError, json.JSONDecodeError,
            subprocess.SubprocessError) as error:
        print(f"QSDK_R24D64_GODOT_EXACT_NET_MOTOR_WORK_PROJECTION_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
