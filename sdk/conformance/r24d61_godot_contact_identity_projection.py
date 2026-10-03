#!/usr/bin/env python3
"""Differential R61 audit composed over the complete R60 preflight."""

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

from sdk.conformance import r24d60_godot_native_telemetry_schema_consumer as inherited  # noqa: E402

CONTRACT = ROOT / "sdk/recovery/r24d61_godot_contact_identity_projection_contract_v1.json"
WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
OBSERVER = ROOT / "scripts/lab/mechanics/semantic_contact_rigid_body.gd"
WORKER = ROOT / "tests/test_sdk_qsdk_r24d61_godot_contact_identity_projection_zero_world.gd"
BOUND_RUNNER = ROOT / "sdk/run_qsdk_r24d61_godot_native_recovery_route_ghost.ps1"
SOURCE_MARKER = "QSDK_R24D61_GODOT_CONTACT_IDENTITY_PROJECTION_SOURCE_PASS"
WORKER_MARKER = "QSDK_R24D61_GODOT_CONTACT_IDENTITY_PROJECTION_ZERO_WORLD "
SUPERVISOR_MARKER = "QSDK_R24D61_GHOST_SUPERVISOR "


class ProjectionError(RuntimeError):
    """Stable fail-closed R61 error."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ProjectionError(code)


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
    require(contract["gate_id"] == "QSDK-R24D61", "CONTRACT_GATE")
    require(contract["question_class"] == "development", "QUESTION_CLASS")
    require(contract["physical_question_declared"] is False, "PHYSICAL_QUESTION")
    change = contract["controlled_change"]
    for key in (
        "shape_pair_contact_provenance_deduplicated_at_portable_projection",
        "stable_first_observation_order_preserved",
        "point_level_contact_samples_retained",
        "normal_impulse_aggregation_unchanged",
        "same_pure_identity_projection_used_by_zero_world_and_physical_sampler",
    ):
        require(change[key] is True, f"CONTROLLED_CHANGE:{key}")
    for key in (
        "engine_neutral_core_controller_changed", "authored_initializer_changed",
        "initializer_readback_tolerance_changed", "behavior_threshold_changed",
        "behavior_margin_changed", "morphology_changed", "actuator_profile_changed",
        "native_physics_changed", "engine_patch_changed",
        "semantic_contact_observer_changed", "policy_changed", "selector_changed",
        "evaluator_changed", "cohort_changed", "authorization_projection_changed",
        "historical_observation_rewritten",
    ):
        require(change[key] is False, f"FORBIDDEN_CHANGE:{key}")
    interface = contract["contact_identity_projection_contract"]
    require(interface["function"] == "native_contact_identity_projection_v1",
            "INTERFACE_FUNCTION")
    for key in (
        "physical_sampler_calls_exact_function_for_foot_and_nonfoot_buckets",
        "stable_first_observation_order_preserved", "empty_identity_refused",
        "non_string_identity_refused", "duplicate_identity_consolidated_not_rejected",
        "raw_point_count_reported", "duplicate_count_reported",
        "ordered_point_samples_remain_in_source_receipt",
        "normal_impulse_sum_occurs_per_point_before_projection",
    ):
        require(interface[key] is True, f"INTERFACE:{key}")
    controls = contract["zero_world_controls"]
    require(controls["positive_control_count"] == 4, "POSITIVE_COUNT")
    require(controls["duplicate_consolidation_control_count"] == 1,
            "DUPLICATE_CONTROL_COUNT")
    require(controls["stable_order_control_count"] == 1, "ORDER_CONTROL_COUNT")
    require(controls["mutation_count"] == 3, "MUTATION_COUNT")
    require(controls["mutation_rejection_count"] == 3, "REJECTION_COUNT")
    require(len(controls["mutation_ids"]) == 3, "MUTATION_IDS")
    projection = contract["physical_authorization_projection"]
    require(projection["gate_id"] == "QSDK-R24D61", "PROJECTION_GATE")
    require(projection["seed"] == 1825763330, "SEED")
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
    require(len(inventory) == 53, "SOURCE_COUNT")
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
    world = markers(WORLD, (
        "static func native_contact_identity_projection_v1(",
        "if contact_id.strip_edges().is_empty():",
        "if seen.has(contact_id):", "engine_contact_ids.append(contact_id)",
        '"point_samples_modified": false', '"impulse_aggregation_modified": false',
        "foot_impulses[site_id] = float(foot_impulses[site_id]) + normal_impulse",
        "(foot_ids[site_id] as Array).append(engine_contact_id)",
        "nonfoot_impulses[body_id] = float(nonfoot_impulses[body_id]) + normal_impulse",
        "(nonfoot_ids[body_id] as Array).append(engine_contact_id)",
        "var identity_projection := native_contact_identity_projection_v1(raw_ids)",
        "var identity_projection := native_contact_identity_projection_v1(raw_ids)",
        '"ordered_contact_samples": ordered_contact_samples',
        '"ordered_contact_identity_projections": ordered_contact_identity_projections',
    ))
    function = world[
        world.index("static func native_contact_identity_projection_v1("):
        world.index("static func sample_native_step_v1(")
    ]
    require("contact_index" not in function, "POINT_INDEX_ENTERED_PAIR_ID_PROJECTION")
    markers(OBSERVER, (
        "for contact_index in state.get_contact_count():", "samples.append(",
        '"engine_contact_id":', '"%s:%d|%s:%d"',
    ))
    markers(WORKER, (
        "native_contact_identity_projection_v1", '"non_string_identity"',
        '"empty_identity"', '"whitespace_identity"',
        '"duplicate_consolidation_control_count"',
        '"raw_point_identity_count_preserved"', '"world_attempt_count": 0',
        '"solver_step_count": 0',
    ))
    markers(BOUND_RUNNER, (
        'GateId = "QSDK-R24D61"', 'GateToken = "R24D61"',
        'SupervisorMarker = "QSDK_R24D61_GHOST_SUPERVISOR "',
        'Seed = 1825763330',
        "QualifiedPhysicalPaths = $qualifiedPhysicalPaths", "& $shared @arguments",
        "exit $LASTEXITCODE",
    ))
    return {
        "source_inventory_count": len(contract["source_inventory"]),
        "bound_predecessor_count": len(contract["bound_predecessors"]),
        "inherited_source_inventory_count": inherited_counts["source_inventory_count"],
        "identity_positive_control_count": contract["zero_world_controls"]
        ["positive_control_count"],
        "identity_mutation_count": contract["zero_world_controls"]["mutation_count"],
    }


def run_worker(executable: Path) -> dict[str, Any]:
    completed = subprocess.run(
        [str(executable), "--headless", "--path", str(ROOT), "--script",
         "res://" + WORKER.relative_to(ROOT).as_posix()],
        cwd=ROOT, capture_output=True, text=True, check=False,
    )
    require(completed.returncode == 0,
            f"IDENTITY_WORKER:{completed.stdout}:{completed.stderr}")
    lines = [line for line in completed.stdout.splitlines()
             if line.startswith(WORKER_MARKER)]
    require(len(lines) == 1, "IDENTITY_WORKER_MARKER")
    value = json.loads(lines[0][len(WORKER_MARKER):])
    require(isinstance(value, dict), "IDENTITY_WORKER_RECEIPT")
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
    require(value["gate_id"] == "QSDK-R24D61", "SUPERVISOR_GATE")
    require(value["status"] == "forced_failure_projection_control",
            "SUPERVISOR_STATUS")
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
        "schema_version": "sporespore_qsdk_r24d61_missing_physical_switch_refusal_v1",
        "gate_id": "QSDK-R24D61", "ok": True, "refusal_count": 1,
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
    require(worker["positive_control_count"] == 4, "WORKER_POSITIVE")
    require(worker["duplicate_consolidation_control_count"] == 1,
            "WORKER_DUPLICATE")
    require(worker["stable_order_control_count"] == 1, "WORKER_ORDER")
    require(worker["raw_point_identity_count_preserved"] is True,
            "WORKER_POINT_COUNT")
    require(worker["mutation_rejection_count"] == 3, "WORKER_MUTATIONS")
    for receipt in (inherited_receipt, worker, supervisor, refusal):
        for key in ("model_construction_count", "world_attempt_count",
                    "world_build_count", "solver_step_count"):
            require(receipt[key] == 0, f"ZERO_COUNT:{key}")
        require(receipt["physical_acceptance_authority"] is False,
                "PHYSICAL_AUTHORITY")
        require(receipt["release_authority"] is False, "RELEASE_AUTHORITY")
    return {
        "schema_version": "sporespore_qsdk_r24d61_godot_contact_identity_projection_preflight_v1",
        "gate_id": "QSDK-R24D61", "ok": True,
        "runtime_id": "sporespore_qsdk_r24d61_godot_contact_identity_projection_v1",
        "runtime_version": contract["exact_runtime"]["profile_id"],
        **counts,
        "inherited_r60_preflight": inherited_receipt,
        "contact_identity_projection_receipt": worker,
        "supervisor_projection_receipt": supervisor,
        "missing_physical_switch_refusal_receipt": refusal,
        "identity_positive_control_count": 4,
        "identity_mutation_rejection_count": 3,
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
    except (KeyError, OSError, ProjectionError, inherited.ConsumerError,
            ValueError, json.JSONDecodeError, subprocess.SubprocessError) as error:
        print(f"QSDK_R24D61_GODOT_CONTACT_IDENTITY_PROJECTION_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
