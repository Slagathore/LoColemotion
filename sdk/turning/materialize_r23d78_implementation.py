#!/usr/bin/env python3
"""Materialize the content-addressed R23D78 zero-world implementation."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any, Sequence

import r23d65_dependency_closure as scanner
import r23d78_production_route_runtime as design


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = (
    ROOT
    / "sdk"
    / "turning"
    / "r23d78_production_route_three_engine_turning_implementation_v1.json"
)
SCHEMA = "sporespore_qsdk_r23d78_production_route_three_engine_turning_implementation_v1"
STATUS = "implementation_complete_complete_zero_world_gate_passed_physical_not_authorized"
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
    "sdk/adapters/rapier/src/bin/qsdk_r23d78_turning_route.rs",
    "sdk/adapters/mujoco/requirements-lock.txt",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d78_turning_route.py",
    "sdk/turning/r23d78_fresh_finite_three_engine_turning_decision_v1.json",
    "sdk/turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json",
    "sdk/turning/r23d75_native_startup_trace_evaluator_conformance.py",
    "sdk/turning/r23d75_native_startup_trace_evaluator_conformance_closure_v1.json",
    "sdk/turning/r23d77_windows_cas_file_identity.py",
    "sdk/turning/r23d77_windows_cas_path_identity_conformance_closure_v1.json",
    "sdk/turning/r23d78_production_route_runtime.py",
    "sdk/turning/r23d78_production_route_three_engine_turning_evaluator.py",
    "sdk/turning/r23d78_seed_fixture_compiler.gd",
    "sdk/turning/r23d78_receipt_contract.py",
    "sdk/turning/r23d78_receipt_contract.gd",
    "sdk/turning/materialize_r23d78_native_bindings.py",
    "sdk/turning/materialize_r23d78_implementation.py",
    "sdk/audit_r23d78_fresh_finite_three_engine_turning_decision.ps1",
    "sdk/run_qsdk_r23d78_supervisor.ps1",
    "tests/test_qsdk_r23d78_runtime_contract.py",
    "tests/test_qsdk_r23d78_zero_world.ps1",
    "tests/test_sdk_qsdk_r23d78_godot_jolt_worker.gd",
    "sdk/turning/three_engine_authorization_receipt_contract_v1.json",
    "sdk/three_engine_authorization_receipt.ps1",
    "sdk/process_result_projection.ps1",
    "sdk/godot_receipt_terminated_process.ps1",
    "sdk/publish_qsdk_r23d48_trace.ps1",
    "sdk/content_addressed_artifact_store.ps1",
    "sdk/strict_json_array_document.ps1",
    "tests/test_qsdk_r23d76_physical_closure.ps1",
    "sdk/audit_r23d77_windows_cas_path_identity_conformance_closure.py",
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
        "path": "tests/test_sdk_qsdk_r23d78_godot_jolt_worker.gd",
        "shared_native_kernel_path": (
            "tests/test_sdk_qsdk_r23d65_godot_jolt_physical_worker.gd"
        ),
        "native_runtime": "Godot 4.7 stable with Jolt Physics",
        "entry_marker": "QSDK_R23D78_GODOT_JOLT_PREFLIGHT ",
        "startup_transform_id": design.STARTUP_TRANSFORM_BY_ENGINE["godot_jolt"],
    },
    "rapier_parry": {
        "path": "sdk/adapters/rapier/src/qsdk_r23d78_turning_route.rs",
        "binary_source_path": (
            "sdk/adapters/rapier/src/bin/qsdk_r23d78_turning_route.rs"
        ),
        "shared_native_kernel_path": (
            "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs"
        ),
        "native_runtime": "Rapier 3D with Parry geometry",
        "entry_marker": "QSDK_R23D78_RAPIER_PREFLIGHT ",
        "startup_transform_id": design.STARTUP_TRANSFORM_BY_ENGINE["rapier_parry"],
    },
    "mujoco": {
        "path": (
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
            "qsdk_r23d78_turning_route.py"
        ),
        "shared_native_kernel_path": (
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
            "qsdk_r23d65_selected_profile_turning.py"
        ),
        "native_runtime": "MuJoCo Python native binding",
        "entry_marker": "QSDK_R23D78_MUJOCO_PREFLIGHT ",
        "startup_transform_id": design.STARTUP_TRANSFORM_BY_ENGINE["mujoco"],
    },
}

PREDECESSOR_REPLAYS = {
    "consumed_r23d76_finite_result": (
        "sdk/turning/r23d76_production_route_three_engine_turning_validation_closure_v1.json",
        "tests/test_qsdk_r23d76_physical_closure.ps1",
    ),
    "closed_r23d77_windows_cas_path_identity_conformance": (
        "sdk/turning/r23d77_windows_cas_path_identity_conformance_closure_v1.json",
        "sdk/audit_r23d77_windows_cas_path_identity_conformance_closure.py",
    ),
}


class MaterializationError(RuntimeError):
    """The deterministic R23D78 implementation could not be composed."""


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
            f"R23D78_DEPENDENCY_ESCAPES_REPOSITORY:{path}"
        ) from error


def _required_path(relative: str) -> Path:
    path = (ROOT / relative).resolve()
    if not path.is_file() or _relative(path) != relative:
        raise MaterializationError(f"R23D78_DEPENDENCY_MISSING:{relative}")
    return path


def _whole_prefix_paths() -> set[Path]:
    values: set[Path] = set()
    for relative in WHOLE_SOURCE_PREFIXES:
        root = (ROOT / relative).resolve()
        if not root.is_dir():
            raise MaterializationError(
                f"R23D78_DEPENDENCY_PREFIX_MISSING:{relative}"
            )
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
        "policy_id": "r23d78_recursive_local_language_and_native_prefix_inventory_v1",
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
        "schema_version": "sporespore_qsdk_r23d78_dependency_inventory_design_v1",
        "policy_id": projection["policy_id"],
        "adequacy_argument": (
            "Every declared native entry, complete native Rust source prefix, "
            "engine-aware evaluator, compact zero-world control, and both "
            "immutable predecessor replays are content-addressed. The "
            "self-excluded implementation JSON is bound by the clean freeze."
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
        "solver_step_count": 0,
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
        raise MaterializationError("R23D78_CELL_MATRIX_INVALID")
    return {
        "schema_version": SCHEMA,
        "status": STATUS,
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "question_class": design.QUESTION_CLASS,
        "declaration_parent_commit": "2e09180dc99bd99934a9073ff30bee347121367c",
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
        "native_startup_binding_contract_id": design.NATIVE_STARTUP_BINDING_CONTRACT_ID,
        "startup_transform_by_engine": dict(design.STARTUP_TRANSFORM_BY_ENGINE),
        "startup_step_count": design.MUJOCO_STARTUP_RAMP_STEP_COUNT,
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
        "complete_zero_world_gate": {
            "audit_path": "tests/test_qsdk_r23d78_zero_world.ps1",
            "audit_raw_sha256": _raw_sha256(
                ROOT / "tests" / "test_qsdk_r23d78_zero_world.ps1"
            ),
            "full_seeded_world_ghost_used": False,
            "native_worker_preflight_count": 3,
            "invalid_selector_negative_count": 3,
            "missing_physical_authorization_negative_count": 3,
            "authorization_receipt_positive_count": 9,
            "predecessor_replay_count": 2,
            "declaration_mutation_rejection_count": 13,
            "terminal_contract_mutation_rejection_count": 8,
            "r23d77_existing_file_identity_negative_control_count": 12,
            "r23d77_existing_file_identity_negative_control_rejection_count": 12,
            "r23d77_existing_file_identity_successor_binding_proved": True,
            "evaluator_outcome_control_count": 4,
            "engine_startup_binding_count": 3,
            "startup_mutation_rejection_count": 19,
            "unsupported_engine_rejection_count": 1,
            "passed": True,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_execution_authorized": False,
            "physical_acceptance_authority": False,
        },
        "native_smoke_adequacy": {
            "required_after_zero_world_before_qualification": False,
            "maximum_world_count": 0,
            "maximum_solver_step_count_per_engine": 0,
            "uses_held_out_seed_23199": False,
            "r23d76_complete_native_horizon_count_used_for_route_adequacy": 9,
            "r23d76_reused_as_r23d78_finite_result": False,
            "precise_invalidation_declared": True,
            "behavior_thresholds_applied": False,
            "behavioral_success_prediction_allowed": False,
            "passed": False,
            "physical_acceptance_authority": False,
        },
        "predecessor_replays": _predecessor_receipts(),
        "workers": _worker_receipts(),
        "evaluator": {
            "path": "sdk/turning/r23d78_production_route_three_engine_turning_evaluator.py",
            "raw_sha256": _raw_sha256(
                ROOT
                / "sdk"
                / "turning"
                / "r23d78_production_route_three_engine_turning_evaluator.py"
            ),
            "engine_aware_startup_binding": True,
            "r23d77_existing_file_identity_verifier_bound": True,
            "accepted_algorithm_rebound_without_threshold_change": True,
            "outcome_classes": ["positive", "negative", "invalid", "incomplete"],
        },
        "dependency_inventory": inventory,
        "dependency_digests": dependencies,
        "claims": {
            "implementation_complete": True,
            "complete_zero_world_gate_passed": True,
            "new_native_smoke_required": False,
            "native_smoke_passed": False,
            "full_seeded_world_ghost_used": False,
            "both_predecessor_replays_passed": True,
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
    parser.add_argument("command", choices=("write", "check"))
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    raw = _raw_document(compose())
    if arguments.command == "write":
        OUTPUT.write_bytes(raw)
    elif not OUTPUT.is_file() or OUTPUT.read_bytes() != raw:
        raise MaterializationError("R23D78_IMPLEMENTATION_MATERIALIZATION_DRIFT")
    print(
        "QSDK_R23D78_IMPLEMENTATION "
        + json.dumps(
            {
                "command": arguments.command,
                "dependency_count": len(json.loads(raw)["dependency_digests"]),
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
                "physical_execution_authorized": False,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
