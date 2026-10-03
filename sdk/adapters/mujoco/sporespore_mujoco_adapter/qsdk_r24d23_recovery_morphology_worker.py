"""QSDK-R24D23 shortest production-route recovery-morphology ghost worker."""

from __future__ import annotations

import argparse
from copy import deepcopy
import json
from pathlib import Path
import sys
import traceback
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import qsdk_r24d18_recovery_development_worker as shared
from .recovery_morphology_route import (
    EXPECTED_RECOVERY_DESCRIPTOR_SHA256,
    EXPECTED_RECOVERY_MORPHOLOGY_ID,
    EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
    INITIALIZER_ID,
    ROUTE_ID,
    run_recovery_morphology_route_ghost,
    run_zero_world_preflight,
)


CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d23_mujoco_recovery_morphology_route_contract_v1"
)
CAMPAIGN_ID = "QSDK-R24D23-MUJOCO-RECOVERY-MORPHOLOGY-ROUTE-GHOST"
GATE_ID = "QSDK-R24D23"
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d23_mujoco_recovery_morphology_zero_world_receipt_v1"
)
EXPECTED_CELL_ID = "development_recovery_morphology_nominal"
EXPECTED_INITIAL_STATE_ID = "qsdk_r24_recovery_s169_canonical_prone_v1"
EXPECTED_SEED = 1129522465
EXPECTED_HORIZON_STEPS = 2
EXPECTED_PAIRED_ARM_COUNT = 2
EXPECTED_TOTAL_OUTER_STEPS = 4
EXPECTED_TOTAL_NATIVE_SOLVER_STEPS = 20


class R24D23WorkerError(RuntimeError):
    """Stable fail-closed worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D23WorkerError(code)


def load_contract_v1(path: Path) -> dict[str, Any]:
    contract = shared._load_json(path)
    ledger = contract.get("ledger_scope")
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "CONTRACT_QUESTION")
    _require(isinstance(ledger, dict), "CONTRACT_LEDGER")
    assert isinstance(ledger, dict)
    _require(
        ledger.get("subsystem") == "recovery"
        and ledger.get("engine_scope") == ["mujoco_native"]
        and ledger.get("authority_mode") == "development_ghost"
        and ledger.get("question_class") == "development",
        "CONTRACT_LEDGER_SCOPE",
    )
    change = contract.get("controlled_change")
    _require(isinstance(change, dict), "CONTRACT_CHANGE")
    assert isinstance(change, dict)
    _require(
        change.get("route_id") == ROUTE_ID
        and change.get("recovery_morphology_id")
        == EXPECTED_RECOVERY_MORPHOLOGY_ID
        and change.get("recovery_descriptor_sha256")
        == EXPECTED_RECOVERY_DESCRIPTOR_SHA256
        and change.get("recovery_morphology_spec_sha256")
        == EXPECTED_RECOVERY_MORPHOLOGY_SHA256
        and change.get("controller_changed") is False
        and change.get("behavior_thresholds_changed") is False
        and change.get("held_out_selector_changed") is False,
        "CONTRACT_CHANGE_SCOPE",
    )
    cell = contract.get("selected_development_cell")
    _require(isinstance(cell, dict), "CONTRACT_CELL")
    assert isinstance(cell, dict)
    _require(
        cell.get("question_class") == "development"
        and cell.get("cell_id") == EXPECTED_CELL_ID
        and cell.get("initial_state_id") == EXPECTED_INITIAL_STATE_ID
        and cell.get("seed") == EXPECTED_SEED
        and cell.get("random_draw_count") == 0,
        "CONTRACT_CELL_SELECTOR",
    )
    horizon = contract.get("ghost_horizon")
    _require(isinstance(horizon, dict), "CONTRACT_HORIZON")
    assert isinstance(horizon, dict)
    _require(
        horizon.get("outer_steps_per_arm") == EXPECTED_HORIZON_STEPS
        and horizon.get("paired_arm_count") == EXPECTED_PAIRED_ARM_COUNT
        and horizon.get("maximum_total_outer_steps")
        == EXPECTED_TOTAL_OUTER_STEPS
        and horizon.get("maximum_total_native_solver_steps")
        == EXPECTED_TOTAL_NATIVE_SOLVER_STEPS,
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


def _arm_invariants_pass(arm: Mapping[str, Any]) -> bool:
    observations = arm.get("observations")
    native = arm.get("native_receipts")
    collectors = arm.get("collector_receipts")
    portable = arm.get("portable_step_receipts")
    mapping = arm.get("native_recovery_morphology_readback")
    initializer = arm.get("initializer_manifest")
    if not all(
        isinstance(value, list)
        for value in (observations, native, collectors, portable)
    ):
        return False
    assert isinstance(observations, list)
    assert isinstance(native, list)
    assert isinstance(collectors, list)
    assert isinstance(portable, list)
    if not isinstance(mapping, dict) or not isinstance(initializer, dict):
        return False
    zero_interventions = all(
        isinstance(observation, dict)
        and isinstance(observation.get("external_interventions"), dict)
        and all(value == 0 for value in observation["external_interventions"].values())
        for observation in observations
    )
    native_route_bound = all(
        isinstance(receipt, dict)
        and isinstance(receipt.get("native_step"), dict)
        and receipt["native_step"].get("route_id") == ROUTE_ID
        and isinstance(receipt.get("application"), dict)
        and receipt["application"].get("route_id") == ROUTE_ID
        for receipt in native
    )
    collector_valid = all(
        isinstance(receipt, dict)
        and receipt.get("support_status") == "supported_exact"
        and receipt.get("supplied_native_post_step_observation_validated") is True
        for receipt in collectors
    )
    portable_valid = all(
        isinstance(receipt, dict)
        and receipt.get("support_status") == "supported_exact"
        for receipt in portable
    )
    return (
        len(observations) == EXPECTED_HORIZON_STEPS
        and len(native) == EXPECTED_HORIZON_STEPS
        and len(collectors) == EXPECTED_HORIZON_STEPS
        and len(portable) == EXPECTED_HORIZON_STEPS
        and arm.get("outer_step_count") == EXPECTED_HORIZON_STEPS
        and arm.get("native_solver_step_count")
        == EXPECTED_HORIZON_STEPS * 5
        and mapping.get("ok") is True
        and mapping.get("recovery_morphology_spec_sha256")
        == EXPECTED_RECOVERY_MORPHOLOGY_SHA256
        and mapping.get("ordered_joint_readback_count") == 8
        and initializer.get("initializer_id") == INITIALIZER_ID
        and initializer.get("recovery_morphology_id")
        == EXPECTED_RECOVERY_MORPHOLOGY_ID
        and initializer.get("recovery_morphology_spec_sha256")
        == EXPECTED_RECOVERY_MORPHOLOGY_SHA256
        and initializer.get("native_joint_position_readback_matches") is True
        and zero_interventions
        and native_route_bound
        and collector_valid
        and portable_valid
    )


def compact_projection_v1(full: Mapping[str, Any]) -> dict[str, Any]:
    """Project code-path coverage while preserving the complete physical trace."""

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
    checks = {
        "recovery_route_id_exact": full.get("route_id") == ROUTE_ID,
        "paired_initializer_identity_matched": full.get(
            "initializer_identity_matched"
        )
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
        "candidate_in_run_invariants_pass": _arm_invariants_pass(candidate),
        "matched_zero_in_run_invariants_pass": _arm_invariants_pass(matched_zero),
        "matched_zero_remained_unactuated": zero_active == 0,
        "portable_paired_evaluation_valid": evaluation.get(
            "physical_development_trace_valid"
        )
        is True,
        "portable_evaluation_supported": evaluation.get("support_status")
        == "supported_exact",
        "native_collection_executed": full.get(
            "native_runtime_observation_collection_executed"
        )
        is True,
        "behavior_authority_absent": full.get(
            "controller_physical_viability_proven"
        )
        is False,
        "no_prone_to_standing_claim": full.get("prone_to_standing_claimed")
        is False,
    }
    return {
        "schema_version": (
            "sporespore_qsdk_r24d23_recovery_morphology_ghost_compact_projection_v1"
        ),
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": ["mujoco_native"],
            "authority_mode": "development_ghost",
            "question_class": "development",
        },
        "route_id": ROUTE_ID,
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
        "physical_result_observed": evaluation.get("physical_result"),
        "checks": checks,
        "route_coverage_passed": all(checks.values()),
        "behavior_success_required": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
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
    _require(output_directory.is_dir(), "OUTPUT_DIRECTORY_MISSING")
    contract = load_contract_v1(contract_path)
    qualification = shared._load_json(qualification_receipt_path)
    operation_lock = shared._load_json(operation_lock_receipt_path)
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
    result = run_recovery_morphology_route_ghost(
        core,
        cell=deepcopy(contract["selected_development_cell"]),
        horizon_steps=EXPECTED_HORIZON_STEPS,
    )
    projection = compact_projection_v1(result)
    envelope = {
        "schema_version": (
            "sporespore_qsdk_r24d23_recovery_morphology_ghost_full_result_v1"
        ),
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "ledger_scope": deepcopy(contract["ledger_scope"]),
        "source_commit": source_commit,
        "contract_path": contract_path.as_posix(),
        "contract_raw_sha256": shared._sha256_path(contract_path),
        "qualification_receipt_path": str(qualification_receipt_path),
        "qualification_receipt_raw_sha256": shared._sha256_path(
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
    full_sha256 = shared._write_json_exclusive(full_path, envelope)
    projection["source_commit"] = source_commit
    projection["full_result_path"] = full_path.name
    projection["full_result_raw_sha256"] = full_sha256
    summary_path = output_directory / "paired_summary.json"
    summary_sha256 = shared._write_json_exclusive(summary_path, projection)
    manifest = {
        "schema_version": (
            "sporespore_qsdk_r24d23_recovery_morphology_ghost_manifest_v1"
        ),
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "ledger_scope": deepcopy(contract["ledger_scope"]),
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
    manifest_sha256 = shared._write_json_exclusive(manifest_path, manifest)
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
    except Exception as error:
        invalid = {
            "schema_version": (
                "sporespore_qsdk_r24d23_recovery_morphology_ghost_invalid_v1"
            ),
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "ledger_scope": {
                "subsystem": "recovery",
                "engine_scope": ["mujoco_native"],
                "authority_mode": "development_ghost",
                "question_class": "development",
            },
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
                shared._write_json_exclusive(invalid_path, invalid)
        print(json.dumps(invalid, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
