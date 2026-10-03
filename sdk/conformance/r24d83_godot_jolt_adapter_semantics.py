#!/usr/bin/env python3
"""Compact R83 adapter-semantics source audit and zero-world preflight."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import godot_recovery_route_zero_world_controls as controls  # noqa: E402
from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    git,
    load,
    require,
    resolve_prospective_source_freeze,
    sha256,
    source_bytes,
    verify_bound_source_markers,
    verify_declared_source_inventory,
    verify_exact_paths,
    verify_initial_relative_joint_limit_projection,
    verify_legacy_live_authority_projection,
    verify_source_binding,
    collision_masks_interact,
)

CONTRACT = ROOT / "sdk/recovery/r24d83_godot_jolt_adapter_semantics_contract_v1.json"
CLOSURE = ROOT / (
    "sdk/recovery/r24d83_godot_jolt_adapter_semantics_"
    "zero_world_qualification_closure_v1.json"
)
PREDECESSOR = ROOT / (
    "sdk/recovery/r24d82_godot_jolt_limit_and_collision_diagnosis_v1.json"
)
WORLD = "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
ROUTE = "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
WORKER = "tests/test_sdk_qsdk_r24d83_godot_adapter_semantics_zero_world.gd"
QUALIFICATION_RUNNER = (
    "sdk/run_qsdk_r24d83_godot_jolt_adapter_semantics_"
    "zero_world_qualification.ps1"
)
SOURCE_MARKER = "QSDK_R24D83_GODOT_JOLT_ADAPTER_SEMANTICS_SOURCE_PASS"

WORKER_SPEC = {
    "id": "r83_adapter_semantics",
    "path": ROOT / WORKER,
    "marker": "QSDK_R24D83_GODOT_ADAPTER_SEMANTICS_ZERO_WORLD ",
    "expected": {
        "schema_version": (
            "sporespore_qsdk_r24d83_godot_adapter_semantics_zero_world_v1"
        ),
        "gate_id": "QSDK-R24D83",
        "ok": True,
        "joint_projection_count": 8,
        "exact_joint_property_readback_count": 8,
        "outward_lower_projection_count": 8,
        "outward_upper_projection_count": 8,
        "canonical_interval_not_shrunk_count": 8,
        "joint_mutation_rejection_count": 9,
        "collision_property_readback_count": 6,
        "robot_floor_collision_enabled_count": 1,
        "robot_robot_collision_disabled_count": 1,
        "collision_mutation_rejection_count": 3,
        "unattached_godot_property_node_count": 11,
        "node_entered_scene_tree_count": 0,
        "native_runtime_observation_collection_executed": False,
        "physical_question_opened": False,
    },
}


def _canonical_sha256(value: Any) -> str:
    raw = json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _verify_predecessor(contract: dict[str, Any]) -> dict[str, Any]:
    predecessor = controls.validate_bound_predecessor(ROOT, contract, PREDECESSOR)
    binding = contract["bound_predecessors"][0]
    verify_exact_paths(
        binding,
        {
            "gate_id": "QSDK-R24D82",
            "closure_commit": contract["authored_parent_commit"],
            "git_blob_oid": git(
                ROOT,
                "rev-parse",
                f"{binding['closure_commit']}:{binding['path']}",
            ),
            "closure_status": predecessor["closure_status"],
            "same_identity_rerun_permitted": False,
            "same_identity_requalification_permitted": False,
            "historical_result_rewritten": False,
        },
        "PREDECESSOR_BINDING",
    )
    verify_exact_paths(
        predecessor,
        {
            "closure_status": (
                "closed_read_only_retained_trace_and_pinned_source_diagnosis_"
                "two_adapter_defects_physics_blocked"
            ),
            "question_class": "development",
            "physical_question_declared": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "joint_limit_diagnosis.canonical_absolute_limit_projection_defect_proven": True,
            "collision_group_diagnosis.cross_engine_collision_filter_parity_defect_proven": True,
            "decision.r81_result_preserved": True,
            "decision.prone_to_standing_claimed": False,
        },
        "R82",
    )
    rows = predecessor["joint_limit_diagnosis"]["ordered_joint_projection"]
    exact(len(rows), 8, "R82_LIMIT_ROW_COUNT")
    verify_initial_relative_joint_limit_projection(
        rows,
        host_velocity_sign=-1.0,
        prefix="R82_LIMIT",
        require_nontrivial_offset=True,
    )
    current_floor = predecessor["collision_group_diagnosis"]["current_godot_floor"]
    current_robot = predecessor["collision_group_diagnosis"][
        "current_godot_robot_body"
    ]
    require(collision_masks_interact(current_floor, current_robot), "R82_FLOOR")
    require(collision_masks_interact(current_robot, current_robot), "R82_SELF")
    return predecessor


def validate_sources() -> tuple[dict[str, Any], dict[str, int], bool]:
    contract = load(CONTRACT)
    verify_exact_paths(
        contract,
        {
            "schema_version": (
                "sporespore_qsdk_r24d83_godot_jolt_adapter_semantics_contract_v1"
            ),
            "gate_id": "QSDK-R24D83",
            "status": (
                "prospective_adapter_semantics_complete_zero_world_"
                "qualification_required_physics_blocked"
            ),
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
            "question_class": "development",
            "physical_question_declared": False,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "controlled_change.godot_construction_relative_joint_limit_projection_added": True,
            "controlled_change.all_eight_recovery_hinges_use_projection": True,
            "controlled_change.floor_robot_collision_groups_changed_to_disjoint_layers": True,
            "controlled_change.portable_recovery_controller_changed": False,
            "controlled_change.portable_recovery_evaluator_changed": False,
            "controlled_change.behavior_threshold_changed": False,
            "controlled_change.actuator_cap_changed": False,
            "controlled_change.recovery_morphology_changed": False,
            "controlled_change.energy_observer_changed": False,
            "joint_limit_projection_contract.ordered_joint_count": 8,
            "joint_limit_projection_contract.canonical_to_host_velocity_sign": -1.0,
            "joint_limit_projection_contract.canonical_interval_may_shrink": False,
            "joint_limit_projection_contract.empirical_margin_added": False,
            "joint_limit_projection_contract.initializer_projection_sha256": (
                "sha256:ff5c33f3e9ba172057db950423f5f53a56ba1e17943d050cd6525b9e4fabf088"
            ),
            "joint_limit_projection_contract.expected_joint_projection_population_sha256": (
                "sha256:32fe327c5449758e6129589eb81d413e8f1dc936d2b5ae626c2e5d47a7c077b6"
            ),
            "joint_limit_projection_contract.expected_joint_property_readback_population_sha256": (
                "sha256:cd821787098a34fc5974c6a434e85519b63850c8dd4bfcde1c237334499dec8e"
            ),
            "collision_filter_contract.floor.layer": 1,
            "collision_filter_contract.floor.mask": 2,
            "collision_filter_contract.robot.layer": 2,
            "collision_filter_contract.robot.mask": 1,
            "collision_filter_contract.robot_floor_collision_enabled": True,
            "collision_filter_contract.robot_robot_collision_enabled": False,
            "complete_zero_world_gate.current_worker_count": 1,
            "complete_zero_world_gate.joint_projection_count": 8,
            "complete_zero_world_gate.joint_mutation_rejection_count": 9,
            "complete_zero_world_gate.collision_mutation_rejection_count": 3,
            "complete_zero_world_gate.historical_closure_audits_executed_count": 0,
            "complete_zero_world_gate.full_seeded_ghost_count": 0,
            "complete_zero_world_gate.model_construction_count": 0,
            "complete_zero_world_gate.world_attempt_count": 0,
            "complete_zero_world_gate.world_build_count": 0,
            "complete_zero_world_gate.solver_step_count": 0,
            "complete_zero_world_gate.physics_state_modified": False,
            "complete_zero_world_gate.physical_execution_authorized": False,
            "qualification_and_authorization_boundary.physical_question_opened_by_this_gate": False,
            "qualification_and_authorization_boundary.maximum_physical_steps_authorized": 0,
            "qualification_and_authorization_boundary.full_seeded_ghost_required": False,
            "qualification_and_authorization_boundary.prone_to_standing_claimed": False,
            "qualification_and_authorization_boundary.release_authority": False,
            "qualification_and_authorization_boundary.sdk1_score_after": "11/20",
            "qualification_and_authorization_boundary.full_score_after": "11/25",
        },
        "CONTRACT",
    )
    predecessor = _verify_predecessor(contract)
    source_commit, published = resolve_prospective_source_freeze(
        root=ROOT,
        contract=contract,
        closure_path=CLOSURE,
        closure_schema=(
            "sporespore_qsdk_r24d83_godot_jolt_adapter_semantics_"
            "zero_world_qualification_closure_v1"
        ),
        gate_id="QSDK-R24D83",
    )

    unchanged_commit = contract["unchanged_dependency_source_commit"]
    exact(
        unchanged_commit,
        contract["authored_parent_commit"],
        "UNCHANGED_SOURCE_COMMIT",
    )
    for binding in contract["unchanged_dependency_bindings"]:
        parent_raw = verify_source_binding(ROOT, unchanged_commit, binding)
        exact(
            source_bytes(ROOT, source_commit, binding["path"]),
            parent_raw,
            f"UNCHANGED_AT_FREEZE:{binding['path']}",
        )

    bound_sources = {
        path: source_bytes(ROOT, source_commit, path)
        for path in (WORLD, ROUTE, WORKER, QUALIFICATION_RUNNER)
    }
    decoded = verify_bound_source_markers(
        bound_sources,
        {
            WORLD: (
                "const CANONICAL_TO_GODOT_HOST_JOINT_SIGN := -1.0",
                "const RECOVERY_FLOOR_COLLISION_LAYER := 1",
                "const RECOVERY_FLOOR_COLLISION_MASK := 2",
                "const RECOVERY_ROBOT_COLLISION_LAYER := 2",
                "const RECOVERY_ROBOT_COLLISION_MASK := 1",
                "static func godot_initial_relative_joint_limit_projection_v1(",
                "static func validate_godot_initial_relative_joint_limit_readback_v1(",
                "static func validate_godot_recovery_collision_filter_readback_v1(",
                "var host_limit_projection := godot_initial_relative_joint_limit_projection_v1(",
                "host_limit_projection_by_joint_id[joint_id] = host_limit_projection",
                "floor.collision_layer = RECOVERY_FLOOR_COLLISION_LAYER",
                "body.collision_layer = RECOVERY_ROBOT_COLLISION_LAYER",
                '"collision_filter_readback": collision_filter_readback',
            ),
            ROUTE: (
                "const LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN := -1.0",
                "* LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN",
            ),
            WORKER: (
                "WorldScript.godot_initial_relative_joint_limit_projection_v1(",
                "WorldScript.validate_godot_initial_relative_joint_limit_readback_v1(",
                "WorldScript.validate_godot_recovery_collision_filter_readback_v1(",
                '"canonical_passthrough_limits"',
                '"legacy_same_group"',
            ),
            QUALIFICATION_RUNNER: (
                "run_qsdk_core_zero_world_qualification.ps1",
                'GateId = "QSDK-R24D83"',
                "ProspectivePhysicalQuestionDeclared",
            ),
        },
        "SOURCE_MARKERS",
    )
    world_source = decoded[WORLD]
    require(
        "joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, float(joint_spec" not in world_source,
        "LEGACY_DIRECT_LOWER_WRITE",
    )
    require(
        "joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, float(joint_spec" not in world_source,
        "LEGACY_DIRECT_UPPER_WRITE",
    )
    require("floor.collision_mask = 0" not in world_source, "LEGACY_FLOOR_MASK")
    require("body.collision_layer = 1" not in world_source, "LEGACY_BODY_LAYER")
    require("body.collision_mask = 1" not in world_source, "LEGACY_BODY_MASK")

    verify_declared_source_inventory(ROOT, contract["source_inventory"])
    exact(len(contract["source_inventory"]), 58, "SOURCE_INVENTORY_COUNT")
    controls.validate_exact_runtime_and_inventory(ROOT, contract, 58)
    for runtime_kind in ("console", "engine"):
        runtime_path = Path(contract["exact_runtime"][f"{runtime_kind}_path"])
        require(runtime_path.is_file(), f"RUNTIME_MISSING:{runtime_kind}")
        runtime_raw = runtime_path.read_bytes()
        exact(
            (len(runtime_raw), sha256(runtime_raw)),
            (
                contract["exact_runtime"][f"{runtime_kind}_byte_length"],
                contract["exact_runtime"][f"{runtime_kind}_sha256"],
            ),
            f"RUNTIME_IDENTITY:{runtime_kind}",
        )
    exact(len(contract["authored_source_paths"]), 10, "AUTHORED_PATH_COUNT")

    corrected_floor = contract["collision_filter_contract"]["floor"]
    corrected_robot = contract["collision_filter_contract"]["robot"]
    require(collision_masks_interact(corrected_floor, corrected_robot), "R83_FLOOR")
    require(
        not collision_masks_interact(corrected_robot, corrected_robot),
        "R83_SELF",
    )

    live_expected: dict[str, Any] = {
        "next_gate_id": "QSDK-R24D84" if published else "QSDK-R24D83",
        "r24d83_distinct_successor_required": False,
        "r24d83_question_class": "development",
        "r24d83_physical_question_declared": False,
        "r24d83_contract_path": CONTRACT.relative_to(ROOT).as_posix(),
        "r24d83_joint_limit_projection_implemented": True,
        "r24d83_collision_filter_correction_implemented": True,
        "r24d83_portable_controller_changed": False,
        "r24d83_behavior_threshold_changed": False,
        "r24d83_full_seeded_ghost_required": False,
        "r24d83_zero_world_qualification_pending": not published,
        "r24d83_zero_world_qualified": published,
        "r24d83_physical_execution_authorized": False,
        "physical_execution_blocked_until_r24d83_zero_world_qualification": (
            not published
        ),
    }
    verify_legacy_live_authority_projection(
        ROOT,
        (
            "sdk/release/quadruped_release_contract.json",
            "sdk/release/quadruped_support_matrix.json",
        ),
        record_key="r24d83_contract_path",
        expected=live_expected,
        prefix="LIVE_R83",
    )
    return contract, {
        "source_inventory_count": len(contract["source_inventory"]),
        "authored_source_path_count": len(contract["authored_source_paths"]),
        "unchanged_dependency_binding_count": len(
            contract["unchanged_dependency_bindings"]
        ),
        "bound_predecessor_count": 1,
        "diagnosed_joint_projection_count": len(
            predecessor["joint_limit_diagnosis"]["ordered_joint_projection"]
        ),
        "current_zero_world_worker_count": 1,
        "historical_closure_audits_executed_count": 0,
        "full_seeded_ghost_count": 0,
        "bespoke_physical_canary_count": 0,
    }, published


def run_preflight(contract: dict[str, Any], executable: Path) -> dict[str, Any]:
    receipts = controls.run_zero_world_worker_specs(
        ROOT, executable, (WORKER_SPEC,)
    )
    receipt = receipts["r83_adapter_semantics"]
    projections = receipt["ordered_joint_projections"]
    readbacks = receipt["ordered_property_readbacks"]
    exact(len(projections), 8, "PREFLIGHT_PROJECTION_COUNT")
    exact(len(readbacks), 8, "PREFLIGHT_READBACK_COUNT")
    projection_population_sha256 = _canonical_sha256(projections)
    readback_population_sha256 = _canonical_sha256(readbacks)
    exact(
        receipt["initializer_projection_sha256"],
        contract["joint_limit_projection_contract"]["initializer_projection_sha256"],
        "PREFLIGHT_INITIALIZER_PROJECTION",
    )
    exact(
        projection_population_sha256,
        contract["joint_limit_projection_contract"][
            "expected_joint_projection_population_sha256"
        ],
        "PREFLIGHT_PROJECTION_POPULATION",
    )
    exact(
        readback_population_sha256,
        contract["joint_limit_projection_contract"][
            "expected_joint_property_readback_population_sha256"
        ],
        "PREFLIGHT_READBACK_POPULATION",
    )
    exact(
        [row["joint_id"] for row in projections],
        [
            "front_left_hip",
            "front_left_knee",
            "front_right_hip",
            "front_right_knee",
            "rear_left_hip",
            "rear_left_knee",
            "rear_right_hip",
            "rear_right_knee",
        ],
        "PREFLIGHT_JOINT_ORDER",
    )
    return {
        "schema_version": (
            "sporespore_qsdk_r24d83_godot_jolt_adapter_semantics_preflight_v1"
        ),
        "gate_id": "QSDK-R24D83",
        "ok": True,
        "runtime_id": contract["exact_runtime"]["runtime_profile_id"],
        "runtime_version": contract["exact_runtime"]["runtime_version"],
        "worker_receipt_schema": receipt["schema_version"],
        "initializer_projection_sha256": receipt["initializer_projection_sha256"],
        "joint_projection_population_sha256": projection_population_sha256,
        "joint_property_readback_population_sha256": readback_population_sha256,
        "ordered_joint_projections": projections,
        "collision_property_readback": receipt["collision_property_readback"],
        "joint_projection_count": receipt["joint_projection_count"],
        "exact_joint_property_readback_count": receipt[
            "exact_joint_property_readback_count"
        ],
        "joint_mutation_rejection_count": receipt[
            "joint_mutation_rejection_count"
        ],
        "collision_property_readback_count": receipt[
            "collision_property_readback_count"
        ],
        "collision_mutation_rejection_count": receipt[
            "collision_mutation_rejection_count"
        ],
        "historical_closure_audits_executed_count": 0,
        "full_seeded_ghost_count": 0,
        "bespoke_physical_canary_count": 0,
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
                {"gate_id": "QSDK-R24D83", "ok": True, "published": published, **counts},
                sort_keys=True,
            ),
        )
        return 0
    require(args.core_library.is_file(), "CORE_LIBRARY_MISSING")
    executable = controls.validate_exact_runtime_and_inventory(ROOT, contract, 58)
    print(json.dumps(run_preflight(contract, executable), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (controls.ControlError, AssertionError, KeyError, ValueError) as error:
        print(f"QSDK_R24D83_GODOT_JOLT_ADAPTER_SEMANTICS_FAIL:{error}", file=sys.stderr)
        raise SystemExit(1)
