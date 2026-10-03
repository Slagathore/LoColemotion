#!/usr/bin/env python3
"""Compact R58 audit composed over the complete R57 route preflight."""

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

from sdk.conformance import r24d57_godot_native_recovery_route as inherited  # noqa: E402


CONTRACT = ROOT / (
    "sdk/recovery/r24d58_godot_initializer_projection_successor_contract_v1.json"
)
WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
SHARED_RUNNER = ROOT / "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
BOUND_RUNNER = ROOT / "sdk/run_qsdk_r24d58_godot_native_recovery_route_ghost.ps1"
WORKER = ROOT / "tests/test_sdk_qsdk_r24d58_godot_initializer_projection_zero_world.gd"
SOURCE_MARKER = "QSDK_R24D58_GODOT_INITIALIZER_PROJECTION_SUCCESSOR_SOURCE_PASS"
WORKER_MARKER = "QSDK_R24D58_GODOT_INITIALIZER_PROJECTION_ZERO_WORLD "
SUPERVISOR_MARKER = "QSDK_R24D58_GHOST_SUPERVISOR "


class SuccessorError(RuntimeError):
    """Stable fail-closed R58 error."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise SuccessorError(code)


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
    require(contract["gate_id"] == "QSDK-R24D58", "CONTRACT_GATE")
    require(contract["question_class"] == "development", "QUESTION_CLASS")
    require(contract["physical_question_declared"] is False, "PHYSICAL_QUESTION")
    change = contract["controlled_change"]
    for key in (
        "initializer_comparison_target_changed_to_native_projection",
        "initializer_failure_detail_made_lossless",
        "attempted_and_completed_construction_counts_separated",
        "supervisor_output_and_exit_projection_repaired",
    ):
        require(change[key] is True, f"CONTROLLED_CHANGE:{key}")
    for key in (
        "engine_neutral_core_controller_changed",
        "behavior_threshold_changed",
        "behavior_margin_changed",
        "initializer_readback_tolerance_changed",
        "authored_initializer_changed",
        "morphology_changed",
        "actuator_profile_changed",
        "native_physics_changed",
        "policy_changed",
        "selector_changed",
        "evaluator_changed",
        "cohort_changed",
    ):
        require(change[key] is False, f"FORBIDDEN_CHANGE:{key}")
    representation = contract["initializer_representation_contract"]
    require(representation["readback_tolerance_rad"] == 1.0e-8, "READBACK_TOLERANCE")
    require(
        representation["readback_tolerance_changed_from_r24d57"] is False,
        "READBACK_TOLERANCE_CHANGE",
    )
    require(
        representation["development_calibration_observation"]
        ["observation_used_to_set_tolerance"] is False,
        "POSTHOC_TOLERANCE",
    )
    controls = contract["zero_world_controls"]
    require(controls["projection_mutation_count"] == 4, "MUTATION_COUNT")
    require(controls["supervisor_forced_failure_exit_code"] == 23, "FORCED_EXIT")
    gate = contract["complete_zero_world_gate"]
    require(gate["must_pass_before_physics"] is True, "ZERO_GATE")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        require(gate[key] == 0, f"ZERO_COUNT:{key}")
    ghost = contract["next_boundary_if_positive"]
    require(ghost["question_class"] == "development", "GHOST_CLASS")
    require(ghost["held_out"] is False, "GHOST_HELD_OUT")
    require(ghost["maximum_world_attempt_count"] == 1, "GHOST_WORLD_ATTEMPT")
    require(ghost["maximum_world_build_count"] == 1, "GHOST_WORLD_BUILD")
    require(ghost["maximum_outer_solver_steps"] == 2, "GHOST_STEPS")
    require(ghost["same_identity_rerun_permitted"] is False, "GHOST_RERUN")
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
            'INITIALIZER_READBACK_TOLERANCE := 1.0e-8',
            '"godot_4_7_real_t_basis_relative_angle_projection_v1"',
            "static func native_initializer_scalar_projection_v1(",
            "static func native_initializer_projection_contract_v2(",
            "var readback_error := absf(angle - projected)",
            '"authored_to_native_projection_delta_rad"',
            '"native_projection_to_readback_error_rad"',
            '"readback_tolerance_changed_from_r24d57": false',
            '"model_construction_attempt_count": 1',
            '"native_scene_node_construction_attempted": true',
        ),
    )
    readback = world[
        world.index("static func _initializer_readback_v1(") :
        world.index("static func _measure_state_v1(")
    ]
    require("angle - expected" not in readback, "STALE_DECIMAL_COMPARATOR")
    require("angle - authored" not in readback, "AUTHORED_READBACK_COMPARATOR")
    markers(
        SHARED_RUNNER,
        (
            '[ValidateSet("Preflight", "Physical", "ProjectionControl", "AuthorizationControl")]',
            "function New-R57SupervisorProjection",
            "output_line = $supervisorMarker",
            "exit_code = $ExitCode",
            "$semanticExitCode = if ($validComplete) { 0 } else { 1 }",
            "Write-Output $physical.output_line",
            "exit ([int]$physical.exit_code)",
            "SPORESPORE_GODOT_RECOVERY_GATE_ID",
        ),
    )
    markers(
        BOUND_RUNNER,
        (
            '-GateId "QSDK-R24D58"',
            '-GateToken "R24D58"',
            '-Seed 408048331',
            '-SupervisorMarker "QSDK_R24D58_GHOST_SUPERVISOR "',
            "exit $LASTEXITCODE",
        ),
    )
    markers(
        WORKER,
        (
            "native_initializer_projection_contract_v2",
            "NEIGHBOR_PROBE_DELTA_RAD := 2.0e-7",
            '"changed_manifest_without_digest_rebind"',
            '"swapped_joint_order"',
            '"missing_native_basis"',
            '"wrong_initializer_digest"',
            '"forced_failure_projection_control_count": 1',
            '"model_construction_count": 0',
            '"world_attempt_count": 0',
            '"solver_step_count": 0',
        ),
    )
    return {
        "source_inventory_count": len(contract["source_inventory"]),
        "bound_predecessor_count": len(contract["bound_predecessors"]),
        "inherited_route_mutation_count": inherited_counts["route_mutation_count"],
        "projection_mutation_count": contract["zero_world_controls"]
        ["projection_mutation_count"],
    }


def run_projection_worker(executable: Path) -> dict[str, Any]:
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
        f"PROJECTION_WORKER:{completed.stdout}:{completed.stderr}",
    )
    lines = [line for line in completed.stdout.splitlines()
             if line.startswith(WORKER_MARKER)]
    require(len(lines) == 1, "PROJECTION_WORKER_MARKER")
    value = json.loads(lines[0][len(WORKER_MARKER) :])
    require(isinstance(value, dict), "PROJECTION_WORKER_RECEIPT")
    return value


def run_supervisor_control() -> dict[str, Any]:
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
    value = json.loads(lines[0][len(SUPERVISOR_MARKER) :])
    require(isinstance(value, dict), "SUPERVISOR_RECEIPT")
    require(
        value == {
            "schema_version": "sporespore_qsdk_r24d58_ghost_supervisor_result_v1",
            "gate_id": "QSDK-R24D58",
            "ok": False,
            "status": "forced_failure_projection_control",
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "SUPERVISOR_CONTENT",
    )
    require(completed.stderr == "", f"SUPERVISOR_STDERR:{completed.stderr}")
    return value


def run_preflight(core_library: Path) -> dict[str, Any]:
    counts = validate_sources()
    inherited_receipt = inherited.run_preflight(core_library)
    contract = load(CONTRACT)
    executable = Path(contract["exact_runtime"]["console_path"])
    projection = run_projection_worker(executable)
    supervisor = run_supervisor_control()
    require(projection["ok"] is True, "PROJECTION_NOT_OK")
    require(projection["projection_count"] == 8, "PROJECTION_COUNT")
    require(projection["sign_preservation_count"] == 8, "SIGN_COUNT")
    require(projection["neighbor_ordering_control_count"] == 1, "NEIGHBOR_COUNT")
    require(projection["negative_sign_control_count"] == 1, "NEGATIVE_COUNT")
    require(projection["zero_control_count"] == 1, "ZERO_CONTROL")
    require(projection["nonfinite_refusal_count"] == 1, "NONFINITE_CONTROL")
    require(projection["mutation_rejection_count"] == 4, "MUTATION_REJECTION")
    require(projection["readback_tolerance_rad"] == 1.0e-8, "TOLERANCE")
    require(
        projection["readback_tolerance_changed_from_r24d57"] is False,
        "TOLERANCE_CHANGED",
    )
    require(
        projection["maximum_authored_projection_delta_rad"]
        == contract["initializer_representation_contract"]
        ["development_calibration_observation"]
        ["maximum_authored_to_native_projection_delta_rad"],
        "DEVELOPMENT_PROJECTION_DELTA",
    )
    for receipt in (inherited_receipt, projection, supervisor):
        for key in (
            "model_construction_count", "world_attempt_count",
            "world_build_count", "solver_step_count",
        ):
            require(receipt[key] == 0, f"ZERO_COUNT:{key}")
        require(receipt["physical_acceptance_authority"] is False, "PHYSICAL_AUTHORITY")
        require(receipt["release_authority"] is False, "RELEASE_AUTHORITY")
    return {
        "schema_version": "sporespore_qsdk_r24d58_godot_initializer_projection_successor_preflight_v1",
        "gate_id": "QSDK-R24D58",
        "ok": True,
        "runtime_id": contract["initializer_representation_contract"]["profile_id"],
        "runtime_version": contract["exact_runtime"]["profile_id"],
        **counts,
        "inherited_route_preflight": inherited_receipt,
        "projection_receipt": projection,
        "supervisor_projection_receipt": supervisor,
        "instrumented_runtime_positive_count": 1,
        "stock_runtime_negative_count": 1,
        "forced_failure_route_control_count": 1,
        "supervisor_forced_failure_control_count": 1,
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
        print(SOURCE_MARKER, " ".join(f"{key}={value}" for key, value in counts.items()))
        return 0
    print(json.dumps(run_preflight(args.core_library.resolve()), allow_nan=False,
                     separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        KeyError, OSError, SuccessorError, inherited.RouteError,
        ValueError, json.JSONDecodeError, subprocess.SubprocessError,
    ) as error:
        print(f"QSDK_R24D58_GODOT_INITIALIZER_PROJECTION_SUCCESSOR_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
