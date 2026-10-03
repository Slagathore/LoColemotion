"""Distinct QSDK-R24D20 worker for the production-timestep successor."""

from __future__ import annotations

import argparse
from copy import deepcopy
import json
from pathlib import Path
import sys
import traceback
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import qsdk_r24d18_recovery_development_worker as base_worker
from .native_recovery_development import (
    ROUTE_ID,
    run_paired_development,
    run_zero_world_preflight,
)


CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d20_production_timestep_identity_successor_contract_v1"
)
CAMPAIGN_ID = "QSDK-R24D20-MUJOCO-NATIVE-RECOVERY-ROUTE-DEVELOPMENT-GHOST"
GATE_ID = "QSDK-R24D20"
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d20_mujoco_recovery_zero_world_receipt_v1"
)
EXPECTED_ROUTE_ID = "sporespore_mujoco_exact_s169_native_recovery_development_v3"


class R24D20WorkerError(RuntimeError):
    """Stable fail-closed error from the distinct successor worker."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D20WorkerError(code)


def load_contract_v1(path: Path) -> dict[str, Any]:
    contract = base_worker._load_json(path)
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "CONTRACT_QUESTION")
    change = contract.get("controlled_change")
    _require(isinstance(change, dict), "CONTRACT_CHANGE")
    assert isinstance(change, dict)
    _require(
        change.get("route_id") == EXPECTED_ROUTE_ID
        and change.get("comparison_relaxed") is False
        and change.get("controller_changed") is False
        and change.get("thresholds_changed") is False
        and change.get("selector_changed") is False
        and change.get("evaluator_changed") is False,
        "CONTRACT_CHANGE_SCOPE",
    )
    cell = contract.get("selected_development_cell")
    _require(isinstance(cell, dict), "CONTRACT_CELL")
    assert isinstance(cell, dict)
    _require(
        cell.get("question_class") == "development"
        and cell.get("cell_id") == base_worker.EXPECTED_CELL_ID
        and cell.get("seed") == base_worker.EXPECTED_SEED
        and cell.get("random_draw_count") == 0,
        "CONTRACT_CELL_SELECTOR",
    )
    horizon = contract.get("ghost_horizon")
    _require(isinstance(horizon, dict), "CONTRACT_HORIZON")
    assert isinstance(horizon, dict)
    _require(
        horizon.get("outer_steps_per_arm") == base_worker.EXPECTED_HORIZON_STEPS
        and horizon.get("paired_arm_count") == base_worker.EXPECTED_PAIRED_ARM_COUNT,
        "CONTRACT_HORIZON_VALUE",
    )
    held_out = contract.get("held_out_seal")
    _require(isinstance(held_out, dict), "CONTRACT_HELDOUT")
    assert isinstance(held_out, dict)
    _require(
        held_out.get("held_out_cell_access_count") == 0
        and held_out.get("held_out_selector_invocation_count") == 0
        and held_out.get("held_out_data_use_permitted") is False,
        "CONTRACT_HELDOUT_OPEN",
    )
    return contract


def compact_projection_v3(full: Mapping[str, Any]) -> dict[str, Any]:
    projection = base_worker.compact_projection_v1(full)
    projection["schema_version"] = (
        "sporespore_qsdk_r24d20_recovery_ghost_compact_projection_v1"
    )
    projection["gate_id"] = GATE_ID
    projection["campaign_id"] = CAMPAIGN_ID
    projection["route_id"] = full.get("route_id")
    projection["production_timestep_identity_successor"] = True
    projection["r24d18_invalid_result_rewritten"] = False
    projection["r24d19_invalid_result_rewritten"] = False
    projection["checks"]["successor_route_id_exact"] = (
        full.get("route_id") == EXPECTED_ROUTE_ID == ROUTE_ID
    )
    projection["route_coverage_passed"] = all(projection["checks"].values())
    return projection


def run_and_publish_v1(
    *,
    core_library: Path,
    contract_path: Path,
    output_directory: Path,
    source_commit: str,
    qualification_receipt_path: Path,
    operation_lock_receipt_path: Path,
) -> dict[str, Any]:
    _require(output_directory.is_dir(), "OUTPUT_DIRECTORY_MISSING")
    contract = load_contract_v1(contract_path)
    qualification = base_worker._load_json(qualification_receipt_path)
    operation_lock = base_worker._load_json(operation_lock_receipt_path)
    _require(
        qualification.get("schema_version") == QUALIFICATION_RECEIPT_SCHEMA
        and qualification.get("gate_id") == GATE_ID
        and qualification.get("ok") is True
        and qualification.get("mode") == "qualification"
        and qualification.get("source_commit") == source_commit,
        "QUALIFICATION_RECEIPT_INVALID",
    )
    _require(
        operation_lock.get("acquired") is True
        and operation_lock.get("role") == "physical"
        and operation_lock.get("test_only") is False,
        "OPERATION_LOCK_RECEIPT_INVALID",
    )
    core = LocomotionCore(core_library)
    result = run_paired_development(
        core,
        cell=deepcopy(contract["selected_development_cell"]),
        horizon_steps=base_worker.EXPECTED_HORIZON_STEPS,
    )
    _require(result.get("route_id") == EXPECTED_ROUTE_ID, "RESULT_ROUTE_ID")
    projection = compact_projection_v3(result)
    envelope = {
        "schema_version": "sporespore_qsdk_r24d20_recovery_ghost_full_result_v1",
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "source_commit": source_commit,
        "contract_path": contract_path.as_posix(),
        "contract_raw_sha256": base_worker._sha256_path(contract_path),
        "qualification_receipt_path": str(qualification_receipt_path),
        "qualification_receipt_raw_sha256": base_worker._sha256_path(
            qualification_receipt_path
        ),
        "operation_lock": operation_lock,
        "result": result,
        "r24d18_invalid_result_rewritten": False,
        "r24d19_invalid_result_rewritten": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    full_path = output_directory / "paired_full_result.json"
    full_sha256 = base_worker._write_json_exclusive(full_path, envelope)
    projection["source_commit"] = source_commit
    projection["full_result_path"] = full_path.name
    projection["full_result_raw_sha256"] = full_sha256
    summary_path = output_directory / "paired_summary.json"
    summary_sha256 = base_worker._write_json_exclusive(summary_path, projection)
    manifest = {
        "schema_version": "sporespore_qsdk_r24d20_recovery_ghost_manifest_v1",
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "source_commit": source_commit,
        "artifacts": [
            {
                "path": full_path.name,
                "raw_sha256": full_sha256,
                "byte_length": full_path.stat().st_size,
            },
            {
                "path": summary_path.name,
                "raw_sha256": summary_sha256,
                "byte_length": summary_path.stat().st_size,
            },
        ],
        "route_coverage_passed": projection["route_coverage_passed"],
        "complete_trace_retained": True,
        "compact_projection_retained": True,
        "held_out_cell_access_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    manifest_path = output_directory / "manifest.json"
    manifest_sha256 = base_worker._write_json_exclusive(manifest_path, manifest)
    return {
        "ok": bool(projection["route_coverage_passed"]),
        "route_coverage_passed": bool(projection["route_coverage_passed"]),
        "summary_path": str(summary_path),
        "summary_raw_sha256": summary_sha256,
        "manifest_path": str(manifest_path),
        "manifest_raw_sha256": manifest_sha256,
        "prone_to_standing_claimed": False,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    preflight = subparsers.add_parser("preflight")
    preflight.add_argument("--core-library", type=Path, required=True)
    run = subparsers.add_parser("run")
    run.add_argument("--core-library", type=Path, required=True)
    run.add_argument("--contract", type=Path, required=True)
    run.add_argument("--output-directory", type=Path, required=True)
    run.add_argument("--source-commit", required=True)
    run.add_argument("--qualification-receipt", type=Path, required=True)
    run.add_argument("--operation-lock-receipt", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    if arguments.command == "preflight":
        core = LocomotionCore(arguments.core_library.resolve())
        preflight = run_zero_world_preflight(core)
        _require(preflight.get("route_id") == EXPECTED_ROUTE_ID, "PREFLIGHT_ROUTE_ID")
        print(json.dumps(preflight, sort_keys=True))
        return 0
    output_directory = arguments.output_directory.resolve()
    try:
        completion = run_and_publish_v1(
            core_library=arguments.core_library.resolve(),
            contract_path=arguments.contract.resolve(),
            output_directory=output_directory,
            source_commit=str(arguments.source_commit),
            qualification_receipt_path=arguments.qualification_receipt.resolve(),
            operation_lock_receipt_path=arguments.operation_lock_receipt.resolve(),
        )
        print(json.dumps(completion, sort_keys=True))
        return 0 if completion["ok"] else 3
    except Exception as error:
        invalid = {
            "schema_version": "sporespore_qsdk_r24d20_recovery_ghost_invalid_v1",
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "source_commit": str(arguments.source_commit),
            "error_type": type(error).__name__,
            "error": str(error),
            "traceback": traceback.format_exc(),
            "route_coverage_passed": False,
            "invalid_but_retained": True,
            "r24d18_invalid_result_rewritten": False,
            "r24d19_invalid_result_rewritten": False,
            "held_out_cell_access_count": 0,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        if output_directory.is_dir():
            invalid_path = output_directory / "invalid_result.json"
            if not invalid_path.exists():
                base_worker._write_json_exclusive(invalid_path, invalid)
        print(json.dumps(invalid, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
