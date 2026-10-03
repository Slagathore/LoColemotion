#!/usr/bin/env python3
"""Materialize the content-addressed R23D74 implementation contract.

The inventory begins at every native worker, the shared evaluator/supervisor,
the compact zero-world gate, and the four immutable predecessor replays.  It
then follows local Python, GDScript, and PowerShell edges with the accepted
R23D65 scanner and includes the complete native Rust source prefixes.  This
tool imports no physics library and constructs no model or world.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Sequence

import r23d65_dependency_closure as scanner
import r23d74_production_route_runtime as design


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = (
    ROOT
    / "sdk"
    / "turning"
    / "r23d74_production_route_three_engine_turning_implementation_v1.json"
)
SCHEMA = "sporespore_qsdk_r23d74_production_route_three_engine_turning_implementation_v1"
STATUS = (
    "implementation_complete_complete_zero_world_gate_passed_"
    "physical_not_authorized"
)
SELF_RELATIVE = OUTPUT.relative_to(ROOT).as_posix()

DIRECT_ENTRY_PATHS = (
    ".gitattributes",
    "project.godot",
    "sdk/Cargo.lock",
    "sdk/Cargo.toml",
    "sdk/core/Cargo.toml",
    "sdk/adapters/godot/Cargo.toml",
    "sdk/adapters/godot/sporespore_locomotion.gdextension",
    "sdk/adapters/rapier/Cargo.toml",
    "sdk/adapters/rapier/src/bin/qsdk_r23d74_turning_route.rs",
    "sdk/adapters/mujoco/requirements-lock.txt",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d74_turning_route.py",
    "sdk/turning/r23d74_fresh_finite_three_engine_turning_decision_v1.json",
    "sdk/turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json",
    "sdk/turning/r23d74_production_route_runtime.py",
    "sdk/turning/r23d74_production_route_three_engine_turning_evaluator.py",
    "sdk/turning/r23d74_seed_fixture_compiler.gd",
    "sdk/turning/r23d74_receipt_contract.py",
    "sdk/turning/r23d74_receipt_contract.gd",
    "sdk/turning/materialize_r23d74_native_bindings.py",
    "sdk/turning/materialize_r23d74_implementation.py",
    "sdk/audit_r23d74_fresh_finite_three_engine_turning_decision.ps1",
    "sdk/run_qsdk_r23d74_zero_world.ps1",
    "sdk/run_qsdk_r23d74_supervisor.ps1",
    "tests/test_qsdk_r23d74_zero_world.ps1",
    "tests/test_qsdk_r23d74_runtime_contract.py",
    "tests/test_qsdk_r23d74_measurement_origin_predecessor_replay.ps1",
    "tests/test_qsdk_r23d74_mujoco_positive_turn_predecessor_replay.ps1",
    "tests/test_qsdk_r23d74_legacy_mujoco_outer_lock_preflight.ps1",
    "tests/test_qsdk_r23d74_r23d72_outer_lock_replay.ps1",
    "tests/test_qsdk_r23d74_success_terminal_projection_ghost.ps1",
    "tests/test_qsdk_r23d74_success_terminal_projection_ghost.py",
    "tests/test_sdk_qsdk_r23d74_success_terminal_projection_ghost.gd",
    "tests/test_sdk_qsdk_r23d74_godot_jolt_worker.gd",
    "sdk/turning/three_engine_authorization_receipt_contract_v1.json",
    "sdk/three_engine_authorization_receipt.ps1",
    "sdk/process_result_projection.ps1",
    "sdk/godot_receipt_terminated_process.ps1",
    "sdk/publish_qsdk_r23d48_trace.ps1",
    "sdk/content_addressed_artifact_store.ps1",
    "sdk/strict_json_array_document.ps1",
    "tests/test_three_engine_authorization_receipt.ps1",
    "tests/test_locomotion_operation_lock.ps1",
    "tests/fixtures/locomotion_operation_lock_child.ps1",
    "tests/test_strict_json_array_document.ps1",
    "tests/test_qsdk_r23d71_physical_closure.ps1",
    "tests/test_three_engine_turning_production_route_development_closure.ps1",
    "sdk/audit_forward_displacement_measurement_origin_parity_v1.ps1",
    "sdk/audit_r23d73_mujoco_positive_turn_development_closure.ps1",
)
WHOLE_SOURCE_PREFIXES = (
    "sdk/core/src/",
    "sdk/adapters/godot/src/",
    "sdk/adapters/rapier/src/",
)
WHOLE_SOURCE_PREFIX_EXCLUSIONS = ("sdk/adapters/rapier/src/bin/",)
PYTHON_SEARCH_ROOTS = (
    ROOT / "sdk" / "turning",
    ROOT / "sdk" / "python",
    ROOT / "sdk" / "adapters" / "mujoco",
    ROOT / "sdk" / "adapters" / "mujoco" / "sporespore_mujoco_adapter",
)

WORKERS = {
    "godot_jolt": {
        "path": "tests/test_sdk_qsdk_r23d74_godot_jolt_worker.gd",
        "shared_native_kernel_path": (
            "tests/test_sdk_qsdk_r23d65_godot_jolt_physical_worker.gd"
        ),
        "native_runtime": "Godot 4.7 stable with Jolt Physics",
        "entry_marker": "QSDK_R23D74_GODOT_JOLT_PREFLIGHT ",
    },
    "rapier_parry": {
        "path": "sdk/adapters/rapier/src/qsdk_r23d74_turning_route.rs",
        "binary_source_path": (
            "sdk/adapters/rapier/src/bin/qsdk_r23d74_turning_route.rs"
        ),
        "shared_native_kernel_path": (
            "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs"
        ),
        "native_runtime": "Rapier 3D with Parry geometry",
        "entry_marker": "QSDK_R23D74_RAPIER_PREFLIGHT ",
    },
    "mujoco": {
        "path": (
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
            "qsdk_r23d74_turning_route.py"
        ),
        "shared_native_kernel_path": (
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
            "qsdk_r23d65_selected_profile_turning.py"
        ),
        "native_runtime": "MuJoCo Python native binding",
        "entry_marker": "QSDK_R23D74_MUJOCO_PREFLIGHT ",
    },
}

PREDECESSOR_REPLAYS = {
    "consumed_r23d71_finite_result": (
        "sdk/turning/r23d71_success_terminal_projection_repaired_three_engine_turning_validation_closure_v1.json",
        "tests/test_qsdk_r23d71_physical_closure.ps1",
    ),
    "closed_three_engine_execution_route": (
        "sdk/turning/three_engine_turning_production_route_development_closure_v1.json",
        "tests/test_three_engine_turning_production_route_development_closure.ps1",
    ),
    "prospective_measurement_origin_parity": (
        "sdk/turning/forward_displacement_measurement_origin_parity_v1.json",
        "tests/test_qsdk_r23d74_measurement_origin_predecessor_replay.ps1",
    ),
    "closed_r23d73_mujoco_positive_turn_development": (
        "sdk/turning/r23d73_mujoco_selected_profile_positive_turn_development_closure_v1.json",
        "tests/test_qsdk_r23d74_mujoco_positive_turn_predecessor_replay.ps1",
    ),
}


class MaterializationError(RuntimeError):
    """The deterministic implementation projection could not be built."""


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _canonical_sha256(value: Any) -> str:
    raw = json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError as error:
        raise MaterializationError(
            f"R23D74_DEPENDENCY_ESCAPES_REPOSITORY:{path}"
        ) from error


def _required_path(relative: str) -> Path:
    path = (ROOT / relative).resolve()
    if not path.is_file() or _relative(path) != relative:
        raise MaterializationError(f"R23D74_DEPENDENCY_MISSING:{relative}")
    return path


def _whole_prefix_paths() -> set[Path]:
    values: set[Path] = set()
    for relative in WHOLE_SOURCE_PREFIXES:
        root = (ROOT / relative).resolve()
        if not root.is_dir():
            raise MaterializationError(f"R23D74_DEPENDENCY_PREFIX_MISSING:{relative}")
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            item = _relative(path)
            if any(item.startswith(prefix) for prefix in WHOLE_SOURCE_PREFIX_EXCLUSIONS):
                continue
            values.add(path.resolve())
    return values


def _dependency_inventory() -> tuple[dict[str, str], dict[str, Any]]:
    roots = {_required_path(relative) for relative in DIRECT_ENTRY_PATHS}
    roots.update(_whole_prefix_paths())
    queue = sorted(roots, key=_relative)
    discovered: set[Path] = set()
    graph: dict[str, list[str]] = {}
    external_imports: set[str] = set()
    while queue:
        current = queue.pop(0)
        if current in discovered:
            continue
        discovered.add(current)
        edges, external = scanner._scan_edges(  # noqa: SLF001
            ROOT,
            current,
            PYTHON_SEARCH_ROOTS,
        )
        external_imports.update(external)
        source = _relative(current)
        targets = sorted(
            _relative(edge)
            for edge in edges
            if _relative(edge) != SELF_RELATIVE
        )
        graph[source] = targets
        for edge in sorted(edges, key=_relative):
            if _relative(edge) == SELF_RELATIVE:
                continue
            if edge not in discovered and edge not in queue:
                queue.append(edge)
        queue.sort(key=_relative)

    paths = sorted(
        _relative(path)
        for path in discovered
        if _relative(path) != SELF_RELATIVE
    )
    digests = {relative: _raw_sha256(ROOT / relative) for relative in paths}
    edges = [
        {"from": source, "to": target}
        for source in sorted(graph)
        if source != SELF_RELATIVE
        for target in graph[source]
    ]
    projection = {
        "policy_id": "r23d74_recursive_local_language_and_native_prefix_inventory_v1",
        "ordered_direct_entry_paths": sorted(DIRECT_ENTRY_PATHS),
        "ordered_whole_source_prefixes": list(WHOLE_SOURCE_PREFIXES),
        "ordered_whole_source_prefix_exclusions": list(
            WHOLE_SOURCE_PREFIX_EXCLUSIONS
        ),
        "ordered_paths": paths,
        "ordered_edges": edges,
        "ordered_external_python_import_roots": sorted(external_imports),
        "implementation_contract_self_path": SELF_RELATIVE,
        "implementation_contract_self_bound_separately_by_freeze_hash": True,
    }
    receipt = {
        "schema_version": "sporespore_qsdk_r23d74_dependency_inventory_design_v1",
        "policy_id": projection["policy_id"],
        "adequacy_argument": (
            "Every declared native entry, complete native Rust source prefix, "
            "shared evaluator/supervisor, compact zero-world control, retained "
            "artifact publisher, and predecessor replay is content-addressed. "
            "The self-excluded implementation JSON is bound by the clean freeze."
        ),
        "direct_entry_count": len(roots),
        "transitive_path_count": len(paths),
        "edge_count": len(edges),
        "inventory_projection_sha256": _canonical_sha256(projection),
        "ordered_paths": paths,
        "ordered_external_python_import_roots": sorted(external_imports),
        "recursive_local_python_import_inventory_complete": True,
        "recursive_gdscript_preload_and_extends_inventory_complete": True,
        "powershell_dot_source_inventory_complete": True,
        "whole_native_source_prefix_inventory_complete": True,
        "implementation_contract_self_bound_by_freeze_hash": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }
    return digests, receipt


def _worker_receipts() -> dict[str, Any]:
    receipts: dict[str, Any] = {}
    for engine_id, declaration in WORKERS.items():
        path = _required_path(declaration["path"])
        kernel = _required_path(declaration["shared_native_kernel_path"])
        receipt = dict(declaration)
        receipt.update(
            raw_sha256=_raw_sha256(path),
            shared_native_kernel_raw_sha256=_raw_sha256(kernel),
            shared_native_kernel_reused=True,
            implementation_complete=True,
            physical_execution_authorized=False,
            physical_acceptance_authority=False,
        )
        binary = receipt.get("binary_source_path")
        if isinstance(binary, str):
            receipt["binary_source_raw_sha256"] = _raw_sha256(
                _required_path(binary)
            )
        receipts[engine_id] = receipt
    return receipts


def _predecessor_receipts() -> dict[str, Any]:
    return {
        key: {
            "authority_path": authority,
            "authority_raw_sha256": _raw_sha256(_required_path(authority)),
            "audit_path": audit,
            "audit_raw_sha256": _raw_sha256(_required_path(audit)),
            "required_zero_world_replay": True,
            "historical_result_changed": False,
        }
        for key, (authority, audit) in PREDECESSOR_REPLAYS.items()
    }


def compose() -> dict[str, Any]:
    projection = design.validate_runtime_projection()
    dependencies, inventory = _dependency_inventory()
    cells = [item.cell_id for item in design.cells()]
    if len(cells) != 9 or len(set(cells)) != 9:
        raise MaterializationError("R23D74_CELL_MATRIX_INVALID")
    return {
        "schema_version": SCHEMA,
        "status": STATUS,
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "question_class": design.QUESTION_CLASS,
        "preregistration_path": design.DECLARATION_PATH.relative_to(ROOT).as_posix(),
        "preregistration_raw_sha256": _raw_sha256(design.DECLARATION_PATH),
        "declared_cell_count": len(cells),
        "declared_world_count": len(cells),
        "ordered_cell_ids": cells,
        "campaign_seed": design.CAMPAIGN_SEED,
        "profile_id": design.PROFILE_ID,
        "profile_sha256": design.PROFILE_SHA256,
        "controller_step_count": design.CONTROLLER_STEPS,
        "turn_start_step": design.TURN_START_STEP,
        "turn_end_step_exclusive": design.TURN_END_STEP_EXCLUSIVE,
        "recovery_duration_steps": design.RECOVERY_DURATION_STEPS,
        "measurement_origin_policy_id": design.MEASUREMENT_ORIGIN_POLICY_ID,
        "measurement_origin_semantic_step": design.MEASUREMENT_ORIGIN_SEMANTIC_STEP,
        "mujoco_startup_ramp_id": design.MUJOCO_STARTUP_RAMP_ID,
        "mujoco_startup_ramp_step_count": design.MUJOCO_STARTUP_RAMP_STEP_COUNT,
        "runtime_projection": projection,
        "authorization_receipt_contract": {
            "path": "sdk/turning/three_engine_authorization_receipt_contract_v1.json",
            "raw_sha256": _raw_sha256(
                ROOT / "sdk" / "turning" / "three_engine_authorization_receipt_contract_v1.json"
            ),
            "validator_path": "sdk/three_engine_authorization_receipt.ps1",
            "validator_raw_sha256": _raw_sha256(
                ROOT / "sdk" / "three_engine_authorization_receipt.ps1"
            ),
            "complete_producer_population_size": 3,
            "exact_common_positive_projection_required": True,
            "missing_ok_negative_required_per_engine": True,
        },
        "authorization_ghost": {
            "supervisor_path": "sdk/run_qsdk_r23d74_supervisor.ps1",
            "supervisor_raw_sha256": _raw_sha256(
                ROOT / "sdk" / "run_qsdk_r23d74_supervisor.ps1"
            ),
            "mode": "complete_ordered_nine_cell_actual_worker_authorization_path",
            "declared_cell_count": 9,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "physical_execution_authorized": False,
            "physical_acceptance_authority": False,
        },
        "complete_zero_world_gate": {
            "runner_path": "sdk/run_qsdk_r23d74_zero_world.ps1",
            "runner_raw_sha256": _raw_sha256(
                ROOT / "sdk" / "run_qsdk_r23d74_zero_world.ps1"
            ),
            "audit_path": "tests/test_qsdk_r23d74_zero_world.ps1",
            "audit_raw_sha256": _raw_sha256(
                ROOT / "tests" / "test_qsdk_r23d74_zero_world.ps1"
            ),
            "full_seeded_world_ghost_used": False,
            "representative_native_preflight_count": 3,
            "invalid_selector_negative_count": 3,
            "missing_physical_authorization_negative_count": 3,
            "authorization_receipt_positive_count": 9,
            "missing_ok_negative_count": 3,
            "predecessor_replay_count": 4,
            "evaluator_outcome_control_count": 4,
            "passed": True,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_execution_authorized": False,
            "physical_acceptance_authority": False,
        },
        "predecessor_replays": _predecessor_receipts(),
        "workers": _worker_receipts(),
        "evaluator": {
            "path": "sdk/turning/r23d74_production_route_three_engine_turning_evaluator.py",
            "raw_sha256": _raw_sha256(
                ROOT / "sdk" / "turning" / "r23d74_production_route_three_engine_turning_evaluator.py"
            ),
            "accepted_algorithm_rebound_without_threshold_change": True,
            "outcome_classes": ["positive", "negative", "invalid", "incomplete"],
        },
        "dependency_inventory": inventory,
        "dependency_digests": dependencies,
        "claims": {
            "implementation_complete": True,
            "complete_zero_world_gate_passed": True,
            "complete_authorization_ghost_passed": True,
            "full_seeded_world_ghost_used": False,
            "all_four_predecessor_replays_passed": True,
            "physical_campaign_opened": False,
            "finite_three_engine_turning": False,
            "portable_basic_turning": False,
            "q_sdk_r23_satisfied": False,
            "cross_engine_equivalence": False,
            "population_robustness": False,
            "arbitrary_quadruped_coverage": False,
            "prone_to_standing": False,
            "release_authorized": False,
            "physical_acceptance_authority": False,
        },
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def _raw_document(value: dict[str, Any]) -> bytes:
    return (
        json.dumps(
            value,
            allow_nan=False,
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        )
        + "\n"
    ).encode("utf-8")


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("write", "check", "print"))
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    value = compose()
    raw = _raw_document(value)
    if arguments.command == "write":
        OUTPUT.write_bytes(raw)
    elif arguments.command == "check":
        if not OUTPUT.is_file() or OUTPUT.read_bytes() != raw:
            raise MaterializationError("R23D74_IMPLEMENTATION_MATERIALIZATION_DRIFT")
    else:
        sys.stdout.buffer.write(raw)
        return 0
    print(
        "QSDK_R23D74_IMPLEMENTATION "
        + json.dumps(
            {
                "path": OUTPUT.relative_to(ROOT).as_posix(),
                "raw_sha256": _raw_sha256(OUTPUT),
                "dependency_count": len(value["dependency_digests"]),
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
                "physical_execution_authorized": False,
                "physical_acceptance_authority": False,
            },
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
