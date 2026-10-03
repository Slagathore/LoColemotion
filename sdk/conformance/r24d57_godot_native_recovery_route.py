#!/usr/bin/env python3
"""Compact source audit and zero-world preflight for QSDK-R24D57."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = (
    REPO_ROOT / "sdk/recovery/r24d57_godot_jolt_native_recovery_route_contract_v1.json"
)
ROUTE_PATH = REPO_ROOT / "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
WORLD_PATH = REPO_ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
SEMANTIC_BODY_PATH = REPO_ROOT / "scripts/lab/mechanics/semantic_contact_rigid_body.gd"
WORKER_PATH = (
    REPO_ROOT / "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_zero_world.gd"
)
GHOST_WORKER_PATH = (
    REPO_ROOT / "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
)
GHOST_RUNNER_PATH = (
    REPO_ROOT / "sdk/run_qsdk_r24d57_godot_native_recovery_route_ghost.ps1"
)
SOURCE_MARKER = "QSDK_R24D57_GODOT_NATIVE_RECOVERY_ROUTE_SOURCE_PASS"
RUNTIME_MARKER = "QSDK_R24D57_GODOT_NATIVE_RECOVERY_ROUTE_ZERO_WORLD "


class RouteError(RuntimeError):
    """Stable fail-closed R24D57 error."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise RouteError(code)


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def validate_contract() -> dict[str, Any]:
    contract = load_json(CONTRACT_PATH)
    require(contract["gate_id"] == "QSDK-R24D57", "CONTRACT_GATE")
    require(contract["question_class"] == "development", "QUESTION_CLASS")
    require(contract["physical_question_declared"] is False, "PHYSICAL_QUESTION")
    require(contract["work_kind"] == "non_physical_native_route_conformance", "WORK_KIND")
    route = contract["route_contract"]
    require(route["ordered_actuator_count"] == 8, "ACTUATOR_COUNT")
    require(route["native_body_count"] == 9, "NATIVE_BODY_COUNT")
    require(route["native_joint_count"] == 8, "NATIVE_JOINT_COUNT")
    require(route["native_contact_site_count"] == 4, "NATIVE_CONTACT_COUNT")
    require(route["canonical_to_godot_velocity_sign"] == -1.0, "HOST_SIGN")
    require(route["engine_identity_input_count"] == 0, "ENGINE_INPUT")
    require(route["engine_specific_policy_branch_count"] == 0, "ENGINE_BRANCH")
    energy = contract["energy_mapping_provenance"]
    require(energy["adapter_side_discrete_staging_mechanism_present"] is False, "STAGING")
    require(energy["missing_measurement_synthesis_permitted"] is False, "SYNTHESIS")
    require(energy["unclosed_residual_preserved"] is True, "UNCLOSED_RESIDUAL")
    require(
        energy["mechanical_energy_residual_used_as_work_source"] is False,
        "RESIDUAL_WORK_SOURCE",
    )
    gate = contract["complete_zero_world_gate"]
    require(gate["must_pass_before_physics"] is True, "ZERO_GATE")
    require(gate["route_mutation_count"] == 6, "MUTATION_COUNT")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
    ):
        require(gate[key] == 0, f"ZERO_COUNT:{key}")
    require(contract["held_out_seal"]["held_out_cell_access_count"] == 0, "HELD_OUT")
    ghost = contract["next_boundary_if_positive"]
    require(ghost["question_class"] == "development", "GHOST_CLASS")
    require(ghost["held_out"] is False, "GHOST_HELD_OUT")
    require(ghost["maximum_outer_solver_steps"] == 2, "GHOST_STEP_BUDGET")
    require(ghost["physics_ticks_per_second"] == 120, "GHOST_PHYSICS_HZ")
    require(ghost["outer_step_duration_s"] == 1.0 / 120.0, "GHOST_STEP_DURATION")
    require(ghost["full_seeded_world_demo"] is False, "GHOST_FULL_WORLD")
    require(ghost["same_identity_rerun_permitted"] is False, "GHOST_RERUN")
    inventory = contract["source_inventory"]
    require(len(inventory) == len(set(inventory)), "SOURCE_INVENTORY_DUPLICATE")
    for relative in inventory:
        require((REPO_ROOT / relative).is_file(), f"SOURCE_MISSING:{relative}")
    for predecessor in contract["bound_predecessors"]:
        path = REPO_ROOT / predecessor["path"]
        require(raw_sha256(path) == predecessor["raw_sha256"], "PREDECESSOR_SHA")
        require(path.stat().st_size == predecessor["byte_length"], "PREDECESSOR_SIZE")
    return contract


def require_markers(path: Path, markers: tuple[str, ...]) -> str:
    source = path.read_text(encoding="utf-8")
    for marker in markers:
        require(marker in source, f"SOURCE_MARKER:{path.relative_to(REPO_ROOT)}:{marker}")
    return source


def validate_sources() -> dict[str, int]:
    contract = validate_contract()
    require_markers(
        ROUTE_PATH,
        (
            'const ROUTE_ID := "sporespore_qsdk_r24d57_godot_jolt_recovery_observation_v3_route_v1"',
            'const ENERGY_MAPPING_PROFILE_ID := "godot_jolt_r24d57_native_recovery_energy_mapping_v1"',
            "static func compose_observations_v1(",
            "static func native_world_blueprint_v1(",
            "static func build_native_world_v1(",
            "static func collect_native_world_observation_v1(",
            'energy_source_receipt["adapter_side_discrete_staging_event_count"]',
            'return _failure("QSDK_R24D57_ENERGY_SOURCE_INCOMPLETE")',
            'return _failure("QSDK_R24D57_GODOT_STAGING_ZERO_NOT_STRUCTURAL")',
            "static func collect_and_plan_v1(",
            "static func initialize_and_step_v4(",
            "static func apply_control_v1(",
            "LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN := -1.0",
        ),
    )
    require_markers(
        WORLD_PATH,
        (
            'const WORLD_ROUTE_ID := "sporespore_qsdk_r24d57_godot_jolt_recovery_native_world_v1"',
            "static func compile_blueprint_v1(",
            "static func build_world_v1(",
            "static func initial_zero_application_v1(",
            "static func sample_native_step_v1(",
            "JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(joint.get_rid())",
            '"godot_jolt_distal_capsule_lower_cap_contact_v1"',
            '"unclosed_energy_residual_preserved": true',
            '"mechanical_energy_residual_used_as_work_source": false',
            "PhysicsServer3D.set_active(false)",
        ),
    )
    require_markers(
        SEMANTIC_BODY_PATH,
        (
            "var latest_direct_state_snapshot: Dictionary = {}",
            '"transform": state.transform',
            '"total_gravity_world_m_s2": state.total_gravity',
            '"inverse_inertia_tensor_world_kg_inv_m2": get_inverse_inertia_tensor()',
        ),
    )
    require_markers(
        REPO_ROOT / "sdk/core/src/recovery_runtime.rs",
        (
            'pub const GODOT_R24D57_RECOVERY_ROUTE_ID: &str =',
            'pub const GODOT_R24D57_ENERGY_MAPPING_PROFILE_ID: &str =',
            "RecoveryNativeEngineV1::GodotJolt4_7 => {",
            "source_route_id == GODOT_R24D57_RECOVERY_ROUTE_ID",
            "mapping_profile_id == GODOT_R24D57_ENERGY_MAPPING_PROFILE_ID",
            "| (RecoveryNativeEngineV1::GodotJolt4_7, GODOT_ADAPTER_ID)",
        ),
    )
    require_markers(
        REPO_ROOT / "sdk/adapters/godot/gdscript/recovery_runtime.gd",
        (
            "const JsonTransportScript := preload(",
            "static func canonicalize(",
            "static func compile_recovery_morphology_v1(",
            "static func resolve_actuator_cap_profile_v1(",
            "JsonTransportScript.stringify(request)",
        ),
    )
    require_markers(
        REPO_ROOT / "sdk/adapters/godot/src/lib.rs",
        (
            "ss_canonicalize_json",
            "ss_compile_recovery_morphology_v1_json",
            "fn canonicalize_json(&self, input: GString) -> GString",
            "fn compile_recovery_morphology_v1_json(&self, input: GString) -> GString",
        ),
    )
    require_markers(
        WORKER_PATH,
        (
            "forced_failure_route_control_count",
            '"wrong_route"',
            '"missing_staging_measurement"',
            '"nonzero_staging_event"',
            '"swapped_command_order"',
            '"missing_host_joint"',
            "RouteScript.native_world_blueprint_v1(sdk, context)",
            '"native_world_blueprint_count": 1',
        ),
    )
    require_markers(
        GHOST_WORKER_PATH,
        (
            "const SEED := 1656561876",
            "const PHYSICS_HZ := 120",
            "const MAXIMUM_SOLVER_STEPS := 2",
            "Engine.physics_ticks_per_second = PHYSICS_HZ",
            "RouteScript.build_native_world_v1(self, _sdk, _context)",
            "RouteScript.collect_native_world_observation_v1(",
            "RouteScript.apply_control_v1(",
            '"portable_command_application_count": 1',
            '"behavior_evaluator_invocation_count": 0',
            '"prone_to_standing_claimed": false',
        ),
    )
    require_markers(
        GHOST_RUNNER_PATH,
        (
            "$physicsHz = 120",
            "$outerStepDurationS = 1.0 / [double]$physicsHz",
            "Invoke-R57Preflight",
            "Get-R57Authorization",
            "Enter-SporeSporeLocomotionOperationLock -Role physical_development",
            'status = "running"',
            "Invoke-SporeSporeGodotReceiptTerminatedProcess",
            '"valid_complete_integration_ghost"',
            "Publish-SporeSporeContentAddressedArtifact",
            "same_identity_rerun_permitted = $false",
        ),
    )
    return {
        "source_inventory_count": len(contract["source_inventory"]),
        "bound_predecessor_count": len(contract["bound_predecessors"]),
        "route_mutation_count": contract["complete_zero_world_gate"]["route_mutation_count"],
    }


def verify_executable(path: Path, expected_sha256: str, expected_size: int) -> None:
    require(path.is_file(), f"EXECUTABLE_MISSING:{path}")
    require(raw_sha256(path) == expected_sha256, f"EXECUTABLE_SHA:{path}")
    require(path.stat().st_size == expected_size, f"EXECUTABLE_SIZE:{path}")


def run_worker(executable: Path, expected_profile: str) -> dict[str, Any]:
    completed = subprocess.run(
        [
            str(executable),
            "--headless",
            "--path",
            str(REPO_ROOT),
            "--script",
            "res://" + WORKER_PATH.relative_to(REPO_ROOT).as_posix(),
            "--",
            f"--expected_profile={expected_profile}",
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    require(
        completed.returncode == 0,
        f"GODOT_WORKER:{expected_profile}:{completed.stdout}:{completed.stderr}",
    )
    lines = [line for line in completed.stdout.splitlines() if line.startswith(RUNTIME_MARKER)]
    require(len(lines) == 1, f"GODOT_MARKER:{expected_profile}")
    receipt = json.loads(lines[0][len(RUNTIME_MARKER) :])
    require(isinstance(receipt, dict), f"GODOT_RECEIPT:{expected_profile}")
    return receipt


def run_preflight(core_library: Path) -> dict[str, Any]:
    counts = validate_sources()
    require(core_library.is_file(), "CORE_LIBRARY_MISSING")
    contract = load_json(CONTRACT_PATH)
    runtime = contract["exact_runtime"]
    instrumented = Path(runtime["console_path"])
    stock = Path(runtime["stock_console_path"])
    verify_executable(
        instrumented,
        runtime["console_raw_sha256"],
        runtime["console_byte_length"],
    )
    verify_executable(
        stock,
        runtime["stock_console_raw_sha256"],
        runtime["stock_console_byte_length"],
    )

    positive = run_worker(instrumented, "instrumented")
    negative = run_worker(stock, "stock")
    require(
        positive["ok"] is True
        and positive["instrumented_profile_selected"] is True
        and positive["collection_support_status"] == "supported_exact"
        and positive["source_bound_observation_validated"] is True
        and positive["control_support_status"] == "supported_exact"
        and positive["ordered_command_count"] == 8
        and positive["step_v4_support_status"] == "supported_exact"
        and positive["validated_command_count"] == 8
        and positive["host_write_count"] == 8
        and positive["host_readback_count"] == 8
        and positive["adapter_side_discrete_staging_event_count"] == 0
        and positive["missing_measurement_synthesis_count"] == 0
        and positive["mutation_rejection_count"] == 6
        and positive["forced_failure_route_control_count"] == 1
        and positive["native_world_blueprint_count"] == 1
        and positive["native_world_blueprint_body_count"] == 9
        and positive["native_world_blueprint_joint_count"] == 8
        and positive["native_world_blueprint_contact_site_count"] == 4,
        "INSTRUMENTED_CONJUNCTION",
    )
    require(
        negative["ok"] is True
        and negative["instrumented_profile_selected"] is False
        and negative["stock_runtime_route_refusal_count"] == 1,
        "STOCK_REFUSAL",
    )
    for receipt in (positive, negative):
        require(receipt["model_construction_count"] == 0, "MODEL_COUNT")
        require(receipt["world_attempt_count"] == 0, "WORLD_ATTEMPT")
        require(receipt["world_build_count"] == 0, "WORLD_BUILD")
        require(receipt["solver_step_count"] == 0, "SOLVER_STEP")
        require(receipt["physics_state_modified"] is False, "PHYSICS_STATE")
        require(receipt["held_out_cell_access_count"] == 0, "HELD_OUT_ACCESS")
        require(receipt["physical_question_opened"] is False, "PHYSICAL_QUESTION_OPENED")
        require(receipt["prone_to_standing_claimed"] is False, "RECOVERY_CLAIM")
        require(receipt["physical_acceptance_authority"] is False, "PHYSICAL_AUTHORITY")
        require(receipt["release_authority"] is False, "RELEASE_AUTHORITY")

    return {
        "schema_version": "sporespore_qsdk_r24d57_godot_native_recovery_route_preflight_v1",
        "gate_id": "QSDK-R24D57",
        "ok": True,
        "runtime_id": runtime["route_id"],
        "runtime_version": runtime["profile_id"],
        **counts,
        "instrumented_runtime_positive_count": 1,
        "stock_runtime_negative_count": 1,
        "forced_failure_route_control_count": 1,
        "instrumented_receipt": positive,
        "stock_receipt": negative,
        "core_library_raw_sha256": raw_sha256(core_library),
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
    arguments = parser.parse_args()
    if arguments.core_library is None:
        counts = validate_sources()
        print(SOURCE_MARKER, " ".join(f"{key}={value}" for key, value in counts.items()))
        return 0
    print(
        json.dumps(
            run_preflight(arguments.core_library.resolve()),
            allow_nan=False,
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, OSError, RouteError, ValueError, json.JSONDecodeError) as error:
        print(f"QSDK_R24D57_GODOT_NATIVE_RECOVERY_ROUTE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
