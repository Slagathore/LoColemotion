"""R24D24 recovery-context and native contact-observer decision worker."""

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
from . import qsdk_r24d23_recovery_morphology_worker as predecessor
from .recovery_context_qualification import run_zero_world_preflight
from .recovery_morphology_route import (
    EXPECTED_RECOVERY_DESCRIPTOR_SHA256,
    EXPECTED_RECOVERY_MORPHOLOGY_ID,
    EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
    MujocoRecoveryMorphologyWorld,
    ROUTE_ID,
    run_recovery_morphology_route_ghost,
)


CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d24_recovery_context_contact_observer_contract_v1"
)
CAMPAIGN_ID = "QSDK-R24D24-MUJOCO-RECOVERY-CONTEXT-CONTACT-OBSERVER-GHOST"
GATE_ID = "QSDK-R24D24"
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d24_recovery_context_contact_observer_zero_world_receipt_v1"
)
EXPECTED_CELL_ID = "development_recovery_morphology_nominal"
EXPECTED_SEED = 1129522465
EXPECTED_HORIZON_STEPS = 2
EXPECTED_PAIRED_ARM_COUNT = 2
EXPECTED_TOTAL_OUTER_STEPS = 4
EXPECTED_TOTAL_NATIVE_SOLVER_STEPS = 20
EXPECTED_OBSERVER_RULE_ID = (
    "mujoco_contact_midpoint_normal_distance_reconstructed_torso_surface_v1"
)


class R24D24WorkerError(RuntimeError):
    """Stable fail-closed worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D24WorkerError(code)


def load_contract_v1(path: Path) -> dict[str, Any]:
    contract = shared._load_json(path)
    ledger = contract.get("ledger_scope")
    change = contract.get("controlled_change")
    cell = contract.get("selected_development_cell")
    horizon = contract.get("ghost_horizon")
    held_out = contract.get("held_out_seal")
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "CONTRACT_QUESTION")
    _require(
        isinstance(ledger, dict)
        and ledger.get("subsystem") == "recovery"
        and ledger.get("engine_scope") == ["mujoco_native"]
        and ledger.get("authority_mode") == "development_ghost"
        and ledger.get("question_class") == "development",
        "CONTRACT_LEDGER",
    )
    _require(
        isinstance(change, dict)
        and change.get("route_id") == ROUTE_ID
        and change.get("recovery_morphology_id") == EXPECTED_RECOVERY_MORPHOLOGY_ID
        and change.get("recovery_descriptor_sha256")
        == EXPECTED_RECOVERY_DESCRIPTOR_SHA256
        and change.get("recovery_morphology_spec_sha256")
        == EXPECTED_RECOVERY_MORPHOLOGY_SHA256
        and change.get("contact_observer_rule_id") == EXPECTED_OBSERVER_RULE_ID
        and change.get("legacy_v1_request_shapes_changed") is False
        and change.get("controller_changed") is False
        and change.get("behavior_thresholds_changed") is False
        and change.get("held_out_selector_changed") is False,
        "CONTRACT_CHANGE",
    )
    _require(
        isinstance(cell, dict)
        and cell.get("cell_id") == EXPECTED_CELL_ID
        and cell.get("seed") == EXPECTED_SEED
        and cell.get("random_draw_count") == 0,
        "CONTRACT_CELL",
    )
    _require(
        isinstance(horizon, dict)
        and horizon.get("outer_steps_per_arm") == EXPECTED_HORIZON_STEPS
        and horizon.get("paired_arm_count") == EXPECTED_PAIRED_ARM_COUNT
        and horizon.get("maximum_total_outer_steps") == EXPECTED_TOTAL_OUTER_STEPS
        and horizon.get("maximum_total_native_solver_steps")
        == EXPECTED_TOTAL_NATIVE_SOLVER_STEPS,
        "CONTRACT_HORIZON",
    )
    _require(
        isinstance(held_out, dict)
        and held_out.get("held_out_cell_access_count") == 0
        and held_out.get("held_out_selector_invocation_count") == 0
        and held_out.get("held_out_data_use_permitted") is False,
        "CONTRACT_HELDOUT",
    )
    return contract


def _torso_records(arm: Mapping[str, Any]) -> list[Mapping[str, Any]]:
    observations = arm.get("observations")
    _require(isinstance(observations, list), "RESULT_OBSERVATIONS")
    records: list[Mapping[str, Any]] = []
    for observation in observations:
        _require(isinstance(observation, dict), "RESULT_OBSERVATION")
        clearances = observation.get("ordered_body_clearance_observations")
        _require(isinstance(clearances, list), "RESULT_CLEARANCES")
        torso = [
            value
            for value in clearances
            if isinstance(value, dict) and value.get("body_id") == "torso"
        ]
        _require(len(torso) == 1, "RESULT_TORSO_CLEARANCE")
        records.append(torso[0])
    return records


def _arm_decision_projection(arm: Mapping[str, Any]) -> dict[str, Any]:
    context = arm.get("portable_recovery_morphology_context")
    trace = arm.get("portable_request_trace")
    steps = arm.get("portable_step_receipts")
    _require(isinstance(context, dict), "RESULT_CONTEXT")
    _require(isinstance(trace, dict), "RESULT_REQUEST_TRACE")
    _require(isinstance(steps, list), "RESULT_STEP_RECEIPTS")
    _require(len(steps) == EXPECTED_HORIZON_STEPS, "RESULT_STEP_COUNT")
    torso = _torso_records(arm)
    classifications = [
        step.get("classification") if isinstance(step, dict) else None
        for step in steps
    ]
    memories = [
        step.get("memory") if isinstance(step, dict) else None
        for step in steps
    ]
    complete = all(isinstance(value, dict) for value in classifications + memories)
    joint_limits = [
        value.get("joint_limits_respected") if isinstance(value, dict) else None
        for value in classifications
    ]
    torso_contacts = [
        value.get("torso_ventral_contact") if isinstance(value, dict) else None
        for value in classifications
    ]
    pose_classes = [
        value.get("pose_class") if isinstance(value, dict) else None
        for value in classifications
    ]
    prone_counts = [
        value.get("prone_confirm_steps_observed")
        if isinstance(value, dict)
        else None
        for value in memories
    ]
    execution_checks = {
        "recovery_context_bound": arm.get("portable_recovery_context_bound") is True,
        "recovery_context_identity_exact": context.get(
            "recovery_morphology_spec_sha256"
        )
        == EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
        "initialize_request_is_v2": trace.get("initialize_request_schema")
        == "sporespore_recovery_initialize_request_v2",
        "collection_requests_are_v2": trace.get("collection_request_schemas")
        == ["sporespore_recovery_native_collection_request_v2"]
        * EXPECTED_HORIZON_STEPS,
        "step_requests_are_v2": trace.get("step_request_schemas")
        == ["sporespore_recovery_step_request_v2"] * EXPECTED_HORIZON_STEPS,
        "control_requests_are_v2": trace.get("control_request_schemas")
        == ["sporespore_recovery_control_request_v2"] * EXPECTED_HORIZON_STEPS,
        "classification_records_complete": complete,
        "torso_observer_rule_exact": len(torso) == EXPECTED_HORIZON_STEPS
        and all(
            value.get("classification_rule_id") == EXPECTED_OBSERVER_RULE_ID
            for value in torso
        ),
    }
    target_checks = {
        "recovery_joint_limits_respected_both_steps": joint_limits == [True, True],
        "torso_ventral_contact_both_steps": torso_contacts == [True, True],
        "pose_class_ventral_prone_both_steps": pose_classes
        == ["ventral_prone", "ventral_prone"],
        "prone_confirmation_accumulates": prone_counts == [1, 2],
    }
    return {
        "execution_checks": execution_checks,
        "target_checks": target_checks,
        "joint_limits_respected": joint_limits,
        "torso_ventral_contact": torso_contacts,
        "pose_class": pose_classes,
        "prone_confirm_steps_observed": prone_counts,
        "observer_rule_ids": [value.get("classification_rule_id") for value in torso],
    }


def compact_projection_v1(full: Mapping[str, Any]) -> dict[str, Any]:
    base_projection = predecessor.compact_projection_v1(full)
    candidate = full.get("candidate")
    matched_zero = full.get("matched_zero_command")
    _require(isinstance(candidate, dict), "RESULT_CANDIDATE")
    _require(isinstance(matched_zero, dict), "RESULT_MATCHED_ZERO")
    candidate_projection = _arm_decision_projection(candidate)
    zero_projection = _arm_decision_projection(matched_zero)
    route_checks = dict(base_projection["checks"])
    route_checks.update(candidate_projection["execution_checks"])
    route_checks.update(
        {
            f"matched_zero_{key}": value
            for key, value in zero_projection["execution_checks"].items()
        }
    )
    route_checks["evaluation_request_is_v2"] = full.get(
        "portable_evaluation_request_schema"
    ) == "sporespore_recovery_evaluation_request_v2"
    target_checks = dict(candidate_projection["target_checks"])
    target_checks.update(
        {
            f"matched_zero_{key}": value
            for key, value in zero_projection["target_checks"].items()
        }
    )
    execution_valid = all(route_checks.values())
    decision_positive = execution_valid and all(target_checks.values())
    return {
        "schema_version": (
            "sporespore_qsdk_r24d24_recovery_context_contact_observer_compact_projection_v1"
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
        "candidate": candidate_projection,
        "matched_zero_command": zero_projection,
        "route_checks": route_checks,
        "target_checks": target_checks,
        "execution_valid": execution_valid,
        "decision_positive": decision_positive,
        "valid_negative_if_decision_not_positive": execution_valid
        and not decision_positive,
        "behavior_success_required": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
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
    result = run_recovery_morphology_route_ghost(
        LocomotionCore(core_library),
        cell=deepcopy(contract["selected_development_cell"]),
        horizon_steps=EXPECTED_HORIZON_STEPS,
    )
    projection = compact_projection_v1(result)
    envelope = {
        "schema_version": (
            "sporespore_qsdk_r24d24_recovery_context_contact_observer_full_result_v1"
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
            "sporespore_qsdk_r24d24_recovery_context_contact_observer_manifest_v1"
        ),
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
        "execution_valid": projection["execution_valid"],
        "decision_positive": projection["decision_positive"],
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
        "ok": bool(projection["execution_valid"]),
        "execution_valid": bool(projection["execution_valid"]),
        "decision_positive": bool(projection["decision_positive"]),
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
        print(
            json.dumps(
                run_zero_world_preflight(
                    LocomotionCore(arguments.core_library.resolve())
                ),
                sort_keys=True,
            )
        )
        return 0
    try:
        completion = run_and_publish_v1(
            core_library=arguments.core_library.resolve(),
            contract_path=arguments.contract.resolve(),
            output_directory=arguments.output_directory.resolve(),
            source_commit=str(arguments.source_commit),
            qualification_receipt_path=arguments.qualification_receipt.resolve(),
            operation_lock_receipt_path=arguments.operation_lock_receipt.resolve(),
        )
        print(json.dumps(completion, sort_keys=True))
        return 0 if completion["ok"] else 3
    except Exception as error:
        invalid = {
            "schema_version": (
                "sporespore_qsdk_r24d24_recovery_context_contact_observer_invalid_v1"
            ),
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "source_commit": str(arguments.source_commit),
            "error_type": type(error).__name__,
            "error": str(error),
            "traceback": traceback.format_exc(),
            "invalid_but_retained": True,
            "held_out_cell_access_count": 0,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        output_directory = arguments.output_directory.resolve()
        if output_directory.is_dir():
            invalid_path = output_directory / "invalid_result.json"
            if not invalid_path.exists():
                shared._write_json_exclusive(invalid_path, invalid)
        print(json.dumps(invalid, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
