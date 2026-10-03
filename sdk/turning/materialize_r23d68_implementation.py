#!/usr/bin/env python3
"""Materialize the compact, content-addressed R23D68 implementation contract.

The dependency inventory starts from the three actual worker entry points,
the accepted native source prefixes, the frozen scientific declaration, and
the retained-evidence publisher. It recursively follows local Python imports,
GDScript loads/extends, and PowerShell dot-sources with the already qualified
R23D65 scanner. The implementation contract itself is deliberately excluded
from its digest map and is bound separately by the physical freeze hash.

This tool only writes the declared JSON implementation contract. It never
loads a physics library, constructs a model, or opens a world.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Sequence

import r23d65_dependency_closure as scanner
import r23d68_production_route_runtime as design


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = (
    ROOT
    / "sdk"
    / "turning"
    / "r23d68_production_route_three_engine_turning_implementation_v1.json"
)
SCHEMA = (
    "sporespore_qsdk_r23d68_production_route_three_engine_turning_implementation_v1"
)
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
    "sdk/adapters/rapier/src/bin/qsdk_r23d68_turning_route.rs",
    "sdk/adapters/mujoco/requirements-lock.txt",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d68_turning_route.py",
    "sdk/turning/r23d68_production_path_conformance_repaired_three_engine_turning_preregistration_v1.json",
    "sdk/turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json",
    "sdk/turning/r23d68_production_route_runtime.py",
    "sdk/turning/r23d68_production_route_three_engine_turning_evaluator.py",
    "sdk/turning/r23d68_seed_fixture_compiler.gd",
    "sdk/turning/three_engine_authorization_receipt_contract_v1.json",
    "sdk/three_engine_authorization_receipt.ps1",
    "sdk/turning/materialize_r23d68_implementation.py",
    "sdk/turning/materialize_r23d68_production_route_sources.py",
    "sdk/process_result_projection.ps1",
    "tests/test_qsdk_r23d68_production_path_ghosts.ps1",
    "tests/test_sdk_qsdk_r23d68_trace_boundary_ghost.gd",
    "sdk/run_qsdk_r23d68_zero_world.ps1",
    "sdk/run_qsdk_r23d68_supervisor.ps1",
    "sdk/godot_receipt_terminated_process.ps1",
    "tests/test_qsdk_r23d68_zero_world.ps1",
    "tests/test_qsdk_r23d68_preregistration.ps1",
    "tests/test_qsdk_r23d68_evaluator.ps1",
    "tests/test_three_engine_authorization_receipt.ps1",
    "tests/test_qsdk_r23d65_physical_closure.ps1",
    "tests/test_three_engine_turning_production_route_development_closure.ps1",
    "tests/test_locomotion_operation_lock.ps1",
    "tests/fixtures/locomotion_operation_lock_child.ps1",
    "tests/test_strict_json_array_document.ps1",
    "tests/test_sdk_qsdk_r23d68_godot_jolt_worker.gd",
    "sdk/publish_qsdk_r23d48_trace.ps1",
    "sdk/content_addressed_artifact_store.ps1",
    "sdk/strict_json_array_document.ps1",
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
        "path": "tests/test_sdk_qsdk_r23d68_godot_jolt_worker.gd",
        "shared_native_kernel_path": (
            "tests/test_sdk_qsdk_r23d65_godot_jolt_physical_worker.gd"
        ),
        "native_runtime": "Godot 4.7 stable with Jolt Physics",
        "entry_marker": "QSDK_R23D68_GODOT_JOLT_PREFLIGHT ",
    },
    "rapier_parry": {
        "path": "sdk/adapters/rapier/src/qsdk_r23d68_turning_route.rs",
        "binary_source_path": (
            "sdk/adapters/rapier/src/bin/qsdk_r23d68_turning_route.rs"
        ),
        "shared_native_kernel_path": (
            "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs"
        ),
        "native_runtime": "Rapier 3D with Parry geometry",
        "entry_marker": "QSDK_R23D68_RAPIER_PREFLIGHT ",
    },
    "mujoco": {
        "path": (
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
            "qsdk_r23d68_turning_route.py"
        ),
        "shared_native_kernel_path": (
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
            "qsdk_r23d65_selected_profile_turning.py"
        ),
        "native_runtime": "MuJoCo Python native binding",
        "entry_marker": "QSDK_R23D68_MUJOCO_PREFLIGHT ",
    },
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
        raise MaterializationError(f"R23D68_DEPENDENCY_ESCAPES_REPOSITORY:{path}") from error


def _required_path(relative: str) -> Path:
    path = (ROOT / relative).resolve()
    if not path.is_file() or _relative(path) != relative:
        raise MaterializationError(f"R23D68_DEPENDENCY_MISSING:{relative}")
    return path


def _whole_prefix_paths() -> set[Path]:
    values: set[Path] = set()
    for relative in WHOLE_SOURCE_PREFIXES:
        root = (ROOT / relative).resolve()
        if not root.is_dir():
            raise MaterializationError(f"R23D68_DEPENDENCY_PREFIX_MISSING:{relative}")
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
        "policy_id": "r23d68_compact_recursive_local_language_dependency_inventory_v1",
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
        "schema_version": "sporespore_qsdk_r23d68_dependency_inventory_design_v1",
        "policy_id": projection["policy_id"],
        "adequacy_argument": (
            "The complete local-language closure of all three production workers, "
            "the full native Rust source prefixes, the frozen declaration/evaluator, "
            "and the CAS publisher invalidates the finite result on any source-byte "
            "change. The implementation JSON cannot hash itself; the clean physical "
            "freeze binds its exact bytes separately before any world."
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


def compose() -> dict[str, Any]:
    design.validate_runtime_projection()
    dependencies, inventory = _dependency_inventory()
    cells = [item.cell_id for item in design.cells()]
    if len(cells) != 9 or len(set(cells)) != 9:
        raise MaterializationError("R23D68_CELL_MATRIX_INVALID")
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
            "supervisor_path": "sdk/run_qsdk_r23d68_supervisor.ps1",
            "supervisor_raw_sha256": _raw_sha256(
                ROOT / "sdk" / "run_qsdk_r23d68_supervisor.ps1"
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
            "runner_path": "sdk/run_qsdk_r23d68_zero_world.ps1",
            "runner_raw_sha256": _raw_sha256(
                ROOT / "sdk" / "run_qsdk_r23d68_zero_world.ps1"
            ),
            "audit_path": "tests/test_qsdk_r23d68_zero_world.ps1",
            "audit_raw_sha256": _raw_sha256(
                ROOT / "tests" / "test_qsdk_r23d68_zero_world.ps1"
            ),
            "authorization_receipt_positive_count": 9,
            "missing_ok_negative_count": 3,
            "representative_native_preflight_count": 3,
            "invalid_selector_negative_count": 3,
            "missing_physical_authorization_negative_count": 3,
            "full_volume_evaluator_outcome_control_count": 4,
            "compact_trace_boundary_ghost_count": 1,
            "compact_process_projection_ghost_count": 1,
            "compact_ghost_model_construction_count": 0,
            "compact_ghost_world_attempt_count": 0,
            "compact_ghost_world_build_count": 0,
            "passed": True,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "physical_execution_authorized": False,
            "physical_acceptance_authority": False,
        },
        "workers": _worker_receipts(),
        "evaluator": {
            "path": (
                "sdk/turning/"
                "r23d68_production_route_three_engine_turning_evaluator.py"
            ),
            "raw_sha256": _raw_sha256(
                ROOT
                / "sdk"
                / "turning"
                / "r23d68_production_route_three_engine_turning_evaluator.py"
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
            "compact_production_path_ghosts_passed": True,
            "trace_vocabulary_conforms_with_zero_margin": True,
            "process_projection_conforms_for_complete_declared_shape_population": True,
            "all_three_positive_worker_receipts_pass_common_validator": True,
            "all_three_missing_ok_negatives_rejected": True,
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
            raise MaterializationError("R23D68_IMPLEMENTATION_MATERIALIZATION_DRIFT")
    else:
        sys.stdout.buffer.write(raw)
        return 0
    print(
        "QSDK_R23D68_IMPLEMENTATION "
        + json.dumps(
            {
                "path": OUTPUT.relative_to(ROOT).as_posix(),
                "raw_sha256": _raw_sha256(OUTPUT),
                "dependency_count": len(value["dependency_digests"]),
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
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
