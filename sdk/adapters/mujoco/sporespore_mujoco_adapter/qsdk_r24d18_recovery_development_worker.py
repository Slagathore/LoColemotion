"""Bounded worker for the QSDK-R24D18 MuJoCo recovery ghost.

The worker has two explicit modes. ``preflight`` crosses the real production
imports and XML compiler while opening zero worlds. ``run`` accepts only the
single prospective development cell, executes the paired native route, and
publishes both a complete trace and a compact content-addressed projection.
Repository, remote, qualification, and operation-lock authority remain owned
by the PowerShell supervisor.
"""

from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
import traceback
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from .native_recovery_development import run_paired_development, run_zero_world_preflight


CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d18_mujoco_native_recovery_development_contract_v1"
)
CAMPAIGN_ID = "QSDK-R24D18-MUJOCO-NATIVE-RECOVERY-ROUTE-DEVELOPMENT-GHOST"
GATE_ID = "QSDK-R24D18"
EXPECTED_CELL_ID = "development_nominal"
EXPECTED_SEED = 1129522465
EXPECTED_HORIZON_STEPS = 14
EXPECTED_PAIRED_ARM_COUNT = 2
EXPECTED_TOTAL_OUTER_STEPS = 28
EXPECTED_TOTAL_NATIVE_SOLVER_STEPS = 140


class R24D18WorkerError(RuntimeError):
    """Stable fail-closed error from the bounded physical worker."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D18WorkerError(code)


def _canonical_bytes(value: object) -> bytes:
    return json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


def _sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def _sha256_path(path: Path) -> str:
    return _sha256_bytes(path.read_bytes())


def _load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    _require(isinstance(value, dict), "QSDK_R24D18_JSON_ROOT_INVALID")
    assert isinstance(value, dict)
    return value


def _write_json_exclusive(path: Path, value: object) -> str:
    raw = _canonical_bytes(value) + b"\n"
    with path.open("xb") as handle:
        handle.write(raw)
    return _sha256_bytes(raw)


def load_contract_v1(path: Path) -> dict[str, Any]:
    """Load and bind the one prospective development selector."""

    contract = _load_json(path)
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "CONTRACT_QUESTION")
    scope = contract.get("scope")
    _require(isinstance(scope, dict), "CONTRACT_SCOPE")
    assert isinstance(scope, dict)
    _require(scope.get("engine") == "mujoco_native", "CONTRACT_ENGINE")
    _require(scope.get("engine_version") == "3.11.0", "CONTRACT_ENGINE_VERSION")
    cell = contract.get("selected_development_cell")
    _require(isinstance(cell, dict), "CONTRACT_CELL")
    assert isinstance(cell, dict)
    _require(cell.get("question_class") == "development", "CONTRACT_CELL_CLASS")
    _require(cell.get("cell_id") == EXPECTED_CELL_ID, "CONTRACT_CELL_ID")
    _require(cell.get("seed") == EXPECTED_SEED, "CONTRACT_CELL_SEED")
    _require(cell.get("random_draw_count") == 0, "CONTRACT_RANDOM_DRAW")
    horizon = contract.get("ghost_horizon")
    _require(isinstance(horizon, dict), "CONTRACT_HORIZON")
    assert isinstance(horizon, dict)
    _require(
        horizon.get("outer_steps_per_arm") == EXPECTED_HORIZON_STEPS,
        "CONTRACT_HORIZON_STEPS",
    )
    _require(
        horizon.get("paired_arm_count") == EXPECTED_PAIRED_ARM_COUNT,
        "CONTRACT_ARM_COUNT",
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


def _active_command_count(arm: Mapping[str, Any]) -> int:
    receipts = arm.get("native_receipts")
    _require(isinstance(receipts, list), "RESULT_NATIVE_RECEIPTS")
    assert isinstance(receipts, list)
    return sum(
        1
        for receipt in receipts
        if isinstance(receipt, dict)
        and isinstance(receipt.get("application"), dict)
        and receipt["application"].get("no_actuation_requested") is False
    )


def compact_projection_v1(full: Mapping[str, Any]) -> dict[str, Any]:
    """Project route coverage without discarding the complete trace."""

    candidate = full.get("candidate")
    matched_zero = full.get("matched_zero_command")
    evaluation = full.get("evaluation")
    _require(isinstance(candidate, dict), "RESULT_CANDIDATE")
    _require(isinstance(matched_zero, dict), "RESULT_MATCHED_ZERO")
    _require(isinstance(evaluation, dict), "RESULT_EVALUATION")
    assert isinstance(candidate, dict)
    assert isinstance(matched_zero, dict)
    assert isinstance(evaluation, dict)
    candidate_active = _active_command_count(candidate)
    zero_active = _active_command_count(matched_zero)
    candidate_observations = candidate.get("observations")
    zero_observations = matched_zero.get("observations")
    _require(isinstance(candidate_observations, list), "RESULT_CANDIDATE_TRACE")
    _require(isinstance(zero_observations, list), "RESULT_ZERO_TRACE")
    assert isinstance(candidate_observations, list)
    assert isinstance(zero_observations, list)

    checks = {
        "paired_initializer_identity_matched": full.get("initializer_identity_matched")
        is True,
        "model_construction_count_exact": full.get("model_construction_count")
        == EXPECTED_PAIRED_ARM_COUNT,
        "world_attempt_count_exact": full.get("world_attempt_count")
        == EXPECTED_PAIRED_ARM_COUNT,
        "world_build_count_exact": full.get("world_build_count")
        == EXPECTED_PAIRED_ARM_COUNT,
        "outer_step_count_exact": full.get("outer_step_count")
        == EXPECTED_TOTAL_OUTER_STEPS,
        "native_solver_step_count_exact": full.get("native_solver_step_count")
        == EXPECTED_TOTAL_NATIVE_SOLVER_STEPS,
        "candidate_observation_count_exact": len(candidate_observations)
        == EXPECTED_HORIZON_STEPS,
        "matched_zero_observation_count_exact": len(zero_observations)
        == EXPECTED_HORIZON_STEPS,
        "candidate_active_command_covered": candidate_active >= 1,
        "matched_zero_remained_unactuated": zero_active == 0,
        "portable_paired_evaluation_valid": evaluation.get(
            "physical_development_trace_valid"
        )
        is True,
        "declared_incomplete_verdict": evaluation.get("verdict")
        == "physical_development_incomplete",
        "no_prone_to_standing_claim": full.get("prone_to_standing_claimed")
        is False,
        "held_out_selector_invocation_count_zero": True,
    }
    route_coverage_passed = all(checks.values())
    return {
        "schema_version": "sporespore_qsdk_r24d18_recovery_ghost_compact_projection_v1",
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "question_class": "development",
        "cell_id": EXPECTED_CELL_ID,
        "seed": EXPECTED_SEED,
        "horizon_steps_per_arm": EXPECTED_HORIZON_STEPS,
        "candidate_active_command_outer_step_count": candidate_active,
        "matched_zero_active_command_outer_step_count": zero_active,
        "candidate_final_phase": candidate.get("final_phase"),
        "matched_zero_final_phase": matched_zero.get("final_phase"),
        "evaluation_verdict": evaluation.get("verdict"),
        "physical_development_trace_valid": evaluation.get(
            "physical_development_trace_valid"
        ),
        "physical_result": evaluation.get("physical_result"),
        "checks": checks,
        "route_coverage_passed": route_coverage_passed,
        "behavior_success_required": False,
        "prone_to_standing_claimed": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "repeatability_rate_claimed": False,
        "population_claimed": False,
        "cross_engine_recovery_claimed": False,
        "cross_engine_equivalence_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def run_and_publish_v1(
    *,
    core_library: Path,
    contract_path: Path,
    output_directory: Path,
    source_commit: str,
    qualification_receipt_path: Path,
    operation_lock_receipt_path: Path,
) -> dict[str, Any]:
    """Execute the one paired ghost and retain full plus compact evidence."""

    _require(output_directory.is_dir(), "OUTPUT_DIRECTORY_MISSING")
    contract = load_contract_v1(contract_path)
    qualification = _load_json(qualification_receipt_path)
    operation_lock = _load_json(operation_lock_receipt_path)
    _require(
        qualification.get("schema_version")
        == "sporespore_qsdk_r24d18_mujoco_recovery_zero_world_receipt_v1"
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
    cell = deepcopy(contract["selected_development_cell"])
    core = LocomotionCore(core_library)
    result = run_paired_development(
        core,
        cell=cell,
        horizon_steps=EXPECTED_HORIZON_STEPS,
    )
    projection = compact_projection_v1(result)
    envelope = {
        "schema_version": "sporespore_qsdk_r24d18_recovery_ghost_full_result_v1",
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "source_commit": source_commit,
        "contract_path": contract_path.as_posix(),
        "contract_raw_sha256": _sha256_path(contract_path),
        "qualification_receipt_path": str(qualification_receipt_path),
        "qualification_receipt_raw_sha256": _sha256_path(
            qualification_receipt_path
        ),
        "operation_lock": operation_lock,
        "result": result,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    full_path = output_directory / "paired_full_result.json"
    full_sha256 = _write_json_exclusive(full_path, envelope)
    projection["source_commit"] = source_commit
    projection["full_result_path"] = full_path.name
    projection["full_result_raw_sha256"] = full_sha256
    summary_path = output_directory / "paired_summary.json"
    summary_sha256 = _write_json_exclusive(summary_path, projection)
    manifest = {
        "schema_version": "sporespore_qsdk_r24d18_recovery_ghost_manifest_v1",
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
    manifest_sha256 = _write_json_exclusive(manifest_path, manifest)
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
        print(json.dumps(run_zero_world_preflight(core), sort_keys=True))
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
    except Exception as error:  # retain invalid development attempts before exit
        invalid = {
            "schema_version": "sporespore_qsdk_r24d18_recovery_ghost_invalid_v1",
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "source_commit": str(arguments.source_commit),
            "error_type": type(error).__name__,
            "error": str(error),
            "traceback": traceback.format_exc(),
            "route_coverage_passed": False,
            "invalid_but_retained": True,
            "held_out_cell_access_count": 0,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        if output_directory.is_dir():
            invalid_path = output_directory / "invalid_result.json"
            if not invalid_path.exists():
                _write_json_exclusive(invalid_path, invalid)
        print(json.dumps(invalid, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
