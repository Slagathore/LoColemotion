#!/usr/bin/env python3
"""Differential R60 audit composed over the complete R59 preflight."""

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

from sdk.conformance import r24d59_godot_authorization_projection as inherited  # noqa: E402


CONTRACT = ROOT / (
    "sdk/recovery/"
    "r24d60_godot_native_telemetry_schema_consumer_contract_v1.json"
)
WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
PATCH = ROOT / (
    "sdk/adapters/godot/engine_patches/"
    "godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
)
WORKER = ROOT / (
    "tests/test_sdk_qsdk_r24d60_godot_native_motor_"
    "telemetry_contract_zero_world.gd"
)
BOUND_RUNNER = ROOT / "sdk/run_qsdk_r24d60_godot_native_recovery_route_ghost.ps1"
SOURCE_MARKER = "QSDK_R24D60_GODOT_NATIVE_TELEMETRY_SCHEMA_CONSUMER_SOURCE_PASS"
WORKER_MARKER = "QSDK_R24D60_GODOT_NATIVE_MOTOR_TELEMETRY_ZERO_WORLD "
SUPERVISOR_MARKER = "QSDK_R24D60_GHOST_SUPERVISOR "


class ConsumerError(RuntimeError):
    """Stable fail-closed R60 error."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ConsumerError(code)


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def markers(path: Path, expected: tuple[str, ...]) -> str:
    source = path.read_text(encoding="utf-8")
    for marker in expected:
        require(marker in source, f"SOURCE_MARKER:{path.relative_to(ROOT)}:{marker}")
    return source


def validate_contract() -> dict[str, Any]:
    contract = load(CONTRACT)
    require(contract["gate_id"] == "QSDK-R24D60", "CONTRACT_GATE")
    require(contract["question_class"] == "development", "QUESTION_CLASS")
    require(contract["physical_question_declared"] is False, "PHYSICAL_QUESTION")
    change = contract["controlled_change"]
    for key in (
        "native_telemetry_consumer_schema_key_changed_from_schema_version_to_schema",
        "same_pure_telemetry_invariant_used_by_zero_world_and_physical_sampler",
        "representative_interface_and_numerical_mutations_added",
    ):
        require(change[key] is True, f"CONTROLLED_CHANGE:{key}")
    for key in (
        "engine_neutral_core_controller_changed",
        "authored_initializer_changed",
        "initializer_readback_tolerance_changed",
        "behavior_threshold_changed",
        "behavior_margin_changed",
        "morphology_changed",
        "actuator_profile_changed",
        "native_physics_changed",
        "engine_patch_changed",
        "policy_changed",
        "selector_changed",
        "evaluator_changed",
        "cohort_changed",
        "authorization_projection_changed",
        "historical_observation_rewritten",
    ):
        require(change[key] is False, f"FORBIDDEN_CHANGE:{key}")
    interface = contract["telemetry_interface_contract"]
    require(interface["function"] == "native_motor_telemetry_contract_v1",
            "INTERFACE_FUNCTION")
    require(interface["binding_schema_key"] == "schema", "BINDING_KEY")
    require(interface["rejected_legacy_consumer_key"] == "schema_version",
            "LEGACY_KEY")
    require(
        interface["telemetry_schema_value"]
        == "sporespore.godot_jolt_hinge_motor_telemetry.v2",
        "TELEMETRY_SCHEMA",
    )
    for key in (
        "physical_sampler_calls_exact_function",
        "checks_active_step_capture",
        "checks_current_snapshot",
        "checks_step_sequence_coherence",
        "checks_finite_numerical_fields",
        "checks_motor_work_identity",
        "checks_outer_step_impulse_cap",
        "checks_zero_command_zero_telemetry",
    ):
        require(interface[key] is True, f"INTERFACE:{key}")
    controls = contract["zero_world_controls"]
    require(controls["positive_control_count"] == 2, "POSITIVE_COUNT")
    require(controls["mutation_count"] == 13, "MUTATION_COUNT")
    require(controls["mutation_rejection_count"] == 13, "REJECTION_COUNT")
    require(len(controls["mutation_ids"]) == 13, "MUTATION_IDS")
    projection = contract["physical_authorization_projection"]
    require(
        projection["schema_version"]
        == "sporespore_qsdk_physical_route_authorization_projection_v1",
        "PROJECTION_SCHEMA",
    )
    require(projection["gate_id"] == "QSDK-R24D60", "PROJECTION_GATE")
    require(projection["seed"] == 89023516, "SEED")
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
    require(published["physical_execution_authorized_before_control"] is False,
            "EARLY_PHYSICAL_AUTHORITY")
    gate = contract["complete_zero_world_gate"]
    require(gate["must_pass_before_physics"] is True, "ZERO_GATE")
    require(gate["physical_execution_authorized"] is False, "ZERO_GATE_AUTHORITY")
    for key in (
        "model_construction_count", "world_attempt_count",
        "world_build_count", "solver_step_count",
    ):
        require(gate[key] == 0, f"ZERO_COUNT:{key}")
    inventory = contract["source_inventory"]
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
    world = markers(
        WORLD,
        (
            "static func native_motor_telemetry_contract_v1(",
            'String(telemetry.get("schema", ""))',
            '"sporespore.godot_jolt_hinge_motor_telemetry.v2"',
            '"QSDK_R24D57_WORLD_TELEMETRY_INVALID:%s"',
            "var telemetry_contract := native_motor_telemetry_contract_v1(",
            'var telemetry: Dictionary = telemetry_contract["telemetry"]',
        ),
    )
    validator = world[
        world.index("static func native_motor_telemetry_contract_v1(") :
        world.index("static func sample_native_step_v1(")
    ]
    require('telemetry.get("schema_version"' not in validator,
            "STALE_TELEMETRY_SCHEMA_KEY")
    require(
        'result["schema"] = "sporespore.godot_jolt_hinge_motor_telemetry.v2";'
        in PATCH.read_text(encoding="utf-8"),
        "BOUND_PATCH_SCHEMA_KEY",
    )
    markers(
        WORKER,
        (
            "native_motor_telemetry_contract_v1",
            '"legacy_schema_version_only"',
            '"not_captured_during_active_step"',
            '"capture_read_sequence_mismatch"',
            '"work_identity_mismatch"',
            '"zero_command_nonzero"',
            '"mutation_rejection_count": mutation_rejection_count',
            '"world_attempt_count": 0',
            '"solver_step_count": 0',
        ),
    )
    markers(
        BOUND_RUNNER,
        (
            'GateId = "QSDK-R24D60"',
            'GateToken = "R24D60"',
            'Seed = 89023516',
            'SupervisorMarker = "QSDK_R24D60_GHOST_SUPERVISOR "',
            "QualifiedPhysicalPaths = $qualifiedPhysicalPaths",
            "& $shared @arguments",
            "exit $LASTEXITCODE",
        ),
    )
    return {
        "source_inventory_count": len(contract["source_inventory"]),
        "bound_predecessor_count": len(contract["bound_predecessors"]),
        "inherited_source_inventory_count": inherited_counts["source_inventory_count"],
        "telemetry_positive_control_count": contract["zero_world_controls"]
        ["positive_control_count"],
        "telemetry_mutation_count": contract["zero_world_controls"]["mutation_count"],
    }


def run_worker(executable: Path) -> dict[str, Any]:
    completed = subprocess.run(
        [
            str(executable), "--headless", "--path", str(ROOT), "--script",
            "res://" + WORKER.relative_to(ROOT).as_posix(),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    require(
        completed.returncode == 0,
        f"TELEMETRY_WORKER:{completed.stdout}:{completed.stderr}",
    )
    lines = [line for line in completed.stdout.splitlines()
             if line.startswith(WORKER_MARKER)]
    require(len(lines) == 1, "TELEMETRY_WORKER_MARKER")
    value = json.loads(lines[0][len(WORKER_MARKER):])
    require(isinstance(value, dict), "TELEMETRY_WORKER_RECEIPT")
    return value


def run_supervisor_projection_control() -> dict[str, Any]:
    completed = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(BOUND_RUNNER),
         "-Mode", "ProjectionControl"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    require(completed.returncode == 23, f"SUPERVISOR_EXIT:{completed.returncode}")
    lines = [line for line in completed.stdout.splitlines()
             if line.startswith(SUPERVISOR_MARKER)]
    require(len(lines) == 1, "SUPERVISOR_MARKER")
    value = json.loads(lines[0][len(SUPERVISOR_MARKER):])
    require(value["gate_id"] == "QSDK-R24D60", "SUPERVISOR_GATE")
    require(value["status"] == "forced_failure_projection_control",
            "SUPERVISOR_STATUS")
    require(value["ok"] is False, "SUPERVISOR_FORCED_OK")
    require(completed.stderr == "", f"SUPERVISOR_STDERR:{completed.stderr}")
    return value


def run_missing_physical_switch_refusal() -> dict[str, Any]:
    completed = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(BOUND_RUNNER), "-Mode", "Physical"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    require(completed.returncode == 1, f"PHYSICAL_REFUSAL_EXIT:{completed.returncode}")
    require("physical_switch_required" in completed.stderr, "PHYSICAL_REFUSAL_CODE")
    require(SUPERVISOR_MARKER not in completed.stdout, "PHYSICAL_REFUSAL_SUMMARY")
    return {
        "schema_version": "sporespore_qsdk_r24d60_missing_physical_switch_refusal_v1",
        "gate_id": "QSDK-R24D60",
        "ok": True,
        "refusal_count": 1,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
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
    require(worker["binding_schema_key_acceptance_count"] == 1,
            "WORKER_BINDING_KEY")
    require(worker["legacy_schema_version_key_refusal_count"] == 1,
            "WORKER_LEGACY_KEY")
    require(worker["mutation_rejection_count"] == 13, "WORKER_MUTATIONS")
    for receipt in (inherited_receipt, worker, supervisor, refusal):
        for key in (
            "model_construction_count", "world_attempt_count",
            "world_build_count", "solver_step_count",
        ):
            require(receipt[key] == 0, f"ZERO_COUNT:{key}")
        require(receipt["physical_acceptance_authority"] is False,
                "PHYSICAL_AUTHORITY")
        require(receipt["release_authority"] is False, "RELEASE_AUTHORITY")
    return {
        "schema_version": (
            "sporespore_qsdk_r24d60_godot_native_telemetry_"
            "schema_consumer_preflight_v1"
        ),
        "gate_id": "QSDK-R24D60",
        "ok": True,
        "runtime_id": contract["telemetry_interface_contract"]
        ["telemetry_schema_value"],
        "runtime_version": contract["telemetry_interface_contract"]
        ["success_schema_version"],
        **counts,
        "inherited_r59_preflight": inherited_receipt,
        "telemetry_contract_receipt": worker,
        "supervisor_projection_receipt": supervisor,
        "missing_physical_switch_refusal_receipt": refusal,
        "telemetry_positive_control_count": 2,
        "telemetry_mutation_rejection_count": 13,
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
    except (
        KeyError, OSError, ConsumerError, inherited.AuthorizationError,
        ValueError, json.JSONDecodeError, subprocess.SubprocessError,
    ) as error:
        print(f"QSDK_R24D60_GODOT_NATIVE_TELEMETRY_SCHEMA_CONSUMER_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
