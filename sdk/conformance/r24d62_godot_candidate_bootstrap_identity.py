#!/usr/bin/env python3
"""Differential R62 audit composed over the complete R61 preflight."""

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

from sdk.conformance import r24d61_godot_contact_identity_projection as inherited  # noqa: E402

CONTRACT = ROOT / "sdk/recovery/r24d62_godot_candidate_bootstrap_identity_contract_v1.json"
WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
ROUTE = ROOT / "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
CORE = ROOT / "sdk/core/src/recovery.rs"
WORKER = ROOT / "tests/test_sdk_qsdk_r24d62_godot_candidate_bootstrap_identity_zero_world.gd"
BOUND_RUNNER = ROOT / "sdk/run_qsdk_r24d62_godot_native_recovery_route_ghost.ps1"
SOURCE_MARKER = "QSDK_R24D62_GODOT_CANDIDATE_BOOTSTRAP_IDENTITY_SOURCE_PASS"
WORKER_MARKER = "QSDK_R24D62_GODOT_CANDIDATE_BOOTSTRAP_IDENTITY_ZERO_WORLD "
SUPERVISOR_MARKER = "QSDK_R24D62_GHOST_SUPERVISOR "


class BootstrapError(RuntimeError):
    """Stable fail-closed R62 error."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise BootstrapError(code)


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def markers(path: Path, expected: tuple[str, ...]) -> str:
    source = path.read_text(encoding="utf-8")
    cursor = 0
    for marker in expected:
        index = source.find(marker, cursor)
        require(index >= 0, f"SOURCE_MARKER:{path.relative_to(ROOT)}:{marker}")
        cursor = index + len(marker)
    return source


def validate_contract() -> dict[str, Any]:
    contract = load(CONTRACT)
    require(contract["gate_id"] == "QSDK-R24D62", "CONTRACT_GATE")
    require(contract["question_class"] == "development", "QUESTION_CLASS")
    require(contract["physical_question_declared"] is False, "PHYSICAL_QUESTION")
    change = contract["controlled_change"]
    for key in (
        "candidate_bootstrap_stamped_candidate_command",
        "matched_zero_bootstrap_stamped_matched_zero_command",
        "candidate_and_matched_zero_no_actuation_bootstraps_distinguished",
        "same_pure_arm_projection_used_by_zero_world_and_physical_initializer",
    ):
        require(change[key] is True, f"CONTROLLED_CHANGE:{key}")
    for key in (
        "first_step_motor_enable_state_changed", "first_step_target_velocity_changed",
        "canonical_prone_pose_changed", "engine_neutral_core_controller_changed",
        "controller_gain_changed", "behavior_threshold_changed", "behavior_margin_changed",
        "morphology_changed", "actuator_profile_changed", "native_physics_changed",
        "engine_patch_changed", "semantic_contact_observer_changed",
        "contact_identity_projection_changed", "policy_changed", "selector_changed",
        "evaluator_changed", "cohort_changed", "authorization_projection_changed",
        "historical_observation_rewritten",
    ):
        require(change[key] is False, f"FORBIDDEN_CHANGE:{key}")
    interface = contract["bootstrap_arm_identity_contract"]
    require(interface["function"] == "native_bootstrap_arm_identity_v1",
            "INTERFACE_FUNCTION")
    require(interface["candidate_zero_command"] is False, "CANDIDATE_ZERO")
    require(interface["matched_zero_zero_command"] is True, "MATCHED_ZERO")
    for key in (
        "candidate_no_actuation_requested", "matched_zero_no_actuation_requested",
        "unknown_arm_refused", "physical_candidate_initializer_calls_exact_projection",
        "physical_route_calls_candidate_initializer",
        "all_eight_motors_remain_disabled_for_bootstrap",
        "all_eight_bootstrap_target_velocities_remain_zero",
    ):
        require(interface[key] is True, f"INTERFACE:{key}")
    controls = contract["zero_world_controls"]
    require(controls["positive_control_count"] == 2, "POSITIVE_COUNT")
    require(controls["candidate_control_count"] == 1, "CANDIDATE_COUNT")
    require(controls["matched_zero_control_count"] == 1, "MATCHED_ZERO_COUNT")
    require(controls["mutation_count"] == 3, "MUTATION_COUNT")
    require(controls["mutation_rejection_count"] == 3, "REJECTION_COUNT")
    projection = contract["physical_authorization_projection"]
    require(projection["gate_id"] == "QSDK-R24D62", "PROJECTION_GATE")
    require(projection["seed"] == 1268887312, "SEED")
    require(projection["held_out"] is False, "HELD_OUT")
    require(projection["maximum_world_build_count"] == 1, "WORLD_BUDGET")
    require(projection["maximum_outer_solver_steps"] == 2, "STEP_BUDGET")
    require(projection["same_identity_rerun_permitted"] is False, "RERUN")
    published = contract["published_closure_authorization_control"]
    require(published["mode"] == "AuthorizationControl", "CONTROL_MODE")
    require(published["physical_mode_requires_control_before_lock"] is True,
            "CONTROL_BEFORE_LOCK")
    require(published["physical_mode_rechecks_control_after_lock"] is True,
            "CONTROL_AFTER_LOCK")
    gate = contract["complete_zero_world_gate"]
    require(gate["must_pass_before_physics"] is True, "ZERO_GATE")
    require(gate["physical_execution_authorized"] is False, "ZERO_GATE_AUTHORITY")
    for key in ("model_construction_count", "world_attempt_count",
                "world_build_count", "solver_step_count"):
        require(gate[key] == 0, f"ZERO_COUNT:{key}")
    inventory = contract["source_inventory"]
    require(len(inventory) == 60, "SOURCE_COUNT")
    require(len(inventory) == len(set(inventory)), "SOURCE_DUPLICATE")
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
        "static func native_bootstrap_arm_identity_v1(",
        'arm_kind != "candidate_command" and arm_kind != "matched_zero_command"',
        'var matched_zero := arm_kind == "matched_zero_command"',
        '"zero_command": matched_zero', '"no_actuation_requested": true',
        "static func _initial_bootstrap_application_v2(",
        "var identity := native_bootstrap_arm_identity_v1(arm_kind)",
        "joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)",
        "joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)",
        '"zero_command": bool(identity["zero_command"])',
        "static func initial_candidate_application_v1(",
        'return _initial_bootstrap_application_v2(sdk, model, "candidate_command")',
        "static func initial_zero_application_v1(",
        'return _initial_bootstrap_application_v2(sdk, model, "matched_zero_command")',
    ))
    markers(ROUTE, (
        "static func initial_native_application_v1(",
        "return NativeWorldScript.initial_candidate_application_v1(sdk, model)",
        "static func collect_and_plan_v1(",
        'context, bound, "candidate_command", phase',
    ))
    markers(CORE, (
        "if applied.zero_command != (memory.arm_kind == RecoveryArmKindV1::MatchedZeroCommand)",
        'return Err("actuation_arm_identity_invalid".to_owned());',
    ))
    markers(WORKER, (
        "native_bootstrap_arm_identity_v1", '"candidate_command"',
        '"matched_zero_command"', '"empty_arm"', '"abbreviated_candidate"',
        '"case_mutation"', '"arm_identities_distinct"', '"world_attempt_count": 0',
        '"solver_step_count": 0',
    ))
    markers(BOUND_RUNNER, (
        'GateId = "QSDK-R24D62"', 'GateToken = "R24D62"',
        'SupervisorMarker = "QSDK_R24D62_GHOST_SUPERVISOR "',
        "Seed = 1268887312", "QualifiedPhysicalPaths = $qualifiedPhysicalPaths",
        "& $shared @arguments", "exit $LASTEXITCODE",
    ))
    return {
        "source_inventory_count": len(contract["source_inventory"]),
        "bound_predecessor_count": len(contract["bound_predecessors"]),
        "inherited_source_inventory_count": inherited_counts["source_inventory_count"],
        "bootstrap_positive_control_count": contract["zero_world_controls"]
        ["positive_control_count"],
        "bootstrap_mutation_count": contract["zero_world_controls"]["mutation_count"],
    }


def run_worker(executable: Path) -> dict[str, Any]:
    completed = subprocess.run(
        [str(executable), "--headless", "--path", str(ROOT), "--script",
         "res://" + WORKER.relative_to(ROOT).as_posix()],
        cwd=ROOT, capture_output=True, text=True, check=False,
    )
    require(completed.returncode == 0,
            f"BOOTSTRAP_WORKER:{completed.stdout}:{completed.stderr}")
    lines = [line for line in completed.stdout.splitlines()
             if line.startswith(WORKER_MARKER)]
    require(len(lines) == 1, "BOOTSTRAP_WORKER_MARKER")
    value = json.loads(lines[0][len(WORKER_MARKER):])
    require(isinstance(value, dict), "BOOTSTRAP_WORKER_RECEIPT")
    return value


def run_supervisor_projection_control() -> dict[str, Any]:
    completed = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(BOUND_RUNNER),
         "-Mode", "ProjectionControl"],
        cwd=ROOT, capture_output=True, text=True, check=False,
    )
    require(completed.returncode == 23, f"SUPERVISOR_EXIT:{completed.returncode}")
    lines = [line for line in completed.stdout.splitlines()
             if line.startswith(SUPERVISOR_MARKER)]
    require(len(lines) == 1, "SUPERVISOR_MARKER")
    value = json.loads(lines[0][len(SUPERVISOR_MARKER):])
    require(value["gate_id"] == "QSDK-R24D62", "SUPERVISOR_GATE")
    require(value["status"] == "forced_failure_projection_control", "SUPERVISOR_STATUS")
    require(value["ok"] is False, "SUPERVISOR_FORCED_OK")
    require(completed.stderr == "", f"SUPERVISOR_STDERR:{completed.stderr}")
    return value


def run_missing_physical_switch_refusal() -> dict[str, Any]:
    completed = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(BOUND_RUNNER), "-Mode", "Physical"],
        cwd=ROOT, capture_output=True, text=True, check=False,
    )
    require(completed.returncode == 1, f"PHYSICAL_REFUSAL_EXIT:{completed.returncode}")
    require("physical_switch_required" in completed.stderr, "PHYSICAL_REFUSAL_CODE")
    require(SUPERVISOR_MARKER not in completed.stdout, "PHYSICAL_REFUSAL_SUMMARY")
    return {
        "schema_version": "sporespore_qsdk_r24d62_missing_physical_switch_refusal_v1",
        "gate_id": "QSDK-R24D62", "ok": True, "refusal_count": 1,
        "model_construction_count": 0, "world_attempt_count": 0,
        "world_build_count": 0, "solver_step_count": 0,
        "physical_acceptance_authority": False, "release_authority": False,
    }


def run_preflight(core_library: Path) -> dict[str, Any]:
    counts = validate_sources()
    inherited_receipt = inherited.run_preflight(core_library)
    contract = load(CONTRACT)
    worker = run_worker(Path(contract["exact_runtime"]["console_path"]))
    supervisor = run_supervisor_projection_control()
    refusal = run_missing_physical_switch_refusal()
    require(worker["ok"] is True, "WORKER_NOT_OK")
    require(worker["positive_control_count"] == 2, "WORKER_POSITIVE")
    require(worker["candidate_control_count"] == 1, "WORKER_CANDIDATE")
    require(worker["matched_zero_control_count"] == 1, "WORKER_MATCHED_ZERO")
    require(worker["candidate_zero_command"] is False, "WORKER_CANDIDATE_ZERO")
    require(worker["candidate_no_actuation_requested"] is True,
            "WORKER_CANDIDATE_NO_ACTUATION")
    require(worker["matched_zero_zero_command"] is True, "WORKER_MATCHED_ZERO_ID")
    require(worker["mutation_rejection_count"] == 3, "WORKER_MUTATIONS")
    for receipt in (inherited_receipt, worker, supervisor, refusal):
        for key in ("model_construction_count", "world_attempt_count",
                    "world_build_count", "solver_step_count"):
            require(receipt[key] == 0, f"ZERO_COUNT:{key}")
        require(receipt["physical_acceptance_authority"] is False,
                "PHYSICAL_AUTHORITY")
        require(receipt["release_authority"] is False, "RELEASE_AUTHORITY")
    return {
        "schema_version": "sporespore_qsdk_r24d62_godot_candidate_bootstrap_identity_preflight_v1",
        "gate_id": "QSDK-R24D62", "ok": True,
        "runtime_id": "sporespore_qsdk_r24d62_godot_bootstrap_arm_identity_v1",
        "runtime_version": contract["exact_runtime"]["profile_id"], **counts,
        "inherited_r61_preflight": inherited_receipt,
        "bootstrap_identity_receipt": worker,
        "supervisor_projection_receipt": supervisor,
        "missing_physical_switch_refusal_receipt": refusal,
        "bootstrap_positive_control_count": 2,
        "bootstrap_mutation_rejection_count": 3,
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
    except (KeyError, OSError, BootstrapError, inherited.ProjectionError,
            ValueError, json.JSONDecodeError, subprocess.SubprocessError) as error:
        print(f"QSDK_R24D62_GODOT_CANDIDATE_BOOTSTRAP_IDENTITY_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
