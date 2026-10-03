"""R24D26 active-application receipt serialization successor worker."""

from __future__ import annotations

import argparse
from copy import deepcopy
import json
import math
from pathlib import Path
import sys
import traceback
from typing import Any, Mapping, Sequence

import numpy as np

from sporespore_locomotion import LocomotionCore

from . import native_recovery_development as runtime
from . import qsdk_r24d18_recovery_development_worker as shared
from . import qsdk_r24d25_first_active_command_worker as predecessor
from .recovery_morphology_route import (
    EXPECTED_RECOVERY_DESCRIPTOR_SHA256,
    EXPECTED_RECOVERY_MORPHOLOGY_ID,
    EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
    ROUTE_ID,
    run_recovery_morphology_route_ghost,
)


CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d26_active_receipt_serialization_contract_v1"
)
CAMPAIGN_ID = "QSDK-R24D26-MUJOCO-FIRST-ACTIVE-RECOVERY-COMMAND-GHOST"
GATE_ID = "QSDK-R24D26"
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d26_active_receipt_serialization_zero_world_receipt_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r24d26_active_receipt_serialization_preflight_v1"
)
EXPECTED_CELL_ID = predecessor.EXPECTED_CELL_ID
EXPECTED_SEED = predecessor.EXPECTED_SEED
EXPECTED_HORIZON_STEPS = predecessor.EXPECTED_HORIZON_STEPS
EXPECTED_CONFIRM_STEPS = predecessor.EXPECTED_CONFIRM_STEPS
EXPECTED_FIRST_ACTIVE_INDEX = predecessor.EXPECTED_FIRST_ACTIVE_INDEX
EXPECTED_PAIRED_ARM_COUNT = predecessor.EXPECTED_PAIRED_ARM_COUNT
EXPECTED_TOTAL_OUTER_STEPS = predecessor.EXPECTED_TOTAL_OUTER_STEPS
EXPECTED_TOTAL_NATIVE_SOLVER_STEPS = predecessor.EXPECTED_TOTAL_NATIVE_SOLVER_STEPS
EXPECTED_OBSERVER_RULE_ID = predecessor.EXPECTED_OBSERVER_RULE_ID
R24D25_CLOSURE_SHA256 = (
    "sha256:01d88e85123724301ababf94d0f51c6b9a7fd7c403c68d66f7df96f494ce2d16"
)


class R24D26WorkerError(RuntimeError):
    """Stable fail-closed worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D26WorkerError(code)


def load_contract_v1(path: Path) -> dict[str, Any]:
    contract = shared._load_json(path)
    ledger = contract.get("ledger_scope")
    lineage = contract.get("lineage")
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
        isinstance(lineage, dict)
        and lineage.get("predecessor_gate_id") == "QSDK-R24D25"
        and lineage.get("predecessor_closure_raw_sha256") == R24D25_CLOSURE_SHA256
        and lineage.get("predecessor_result")
        == "closed_consumed_invalid_incomplete_active_application_receipt_serialization"
        and lineage.get("predecessor_may_rerun") is False,
        "CONTRACT_LINEAGE",
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
        and change.get("production_runtime_changed") is True
        and change.get("controller_changed") is False
        and change.get("behavior_thresholds_changed") is False
        and change.get("margins_changed") is False
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
        and horizon.get("entry_prone_confirm_steps") == EXPECTED_CONFIRM_STEPS
        and horizon.get("first_active_native_application_outer_index_zero_based")
        == EXPECTED_FIRST_ACTIVE_INDEX
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


def _active_control_fixture() -> dict[str, Any]:
    commands = [
        {
            "actuator_id": actuator_id,
            "joint_id": joint_id,
            "target_position_rad": 0.25 if index % 2 == 0 else -0.25,
            "maximum_target_speed_rad_s": 1.0,
        }
        for index, (actuator_id, joint_id) in enumerate(
            zip(runtime.ORDERED_ACTUATOR_IDS, runtime.ORDERED_JOINT_IDS, strict=True)
        )
    ]
    return {
        "schema_version": "sporespore_recovery_control_receipt_v1",
        "support_status": "supported_exact",
        "controller_id": runtime.CONTROLLER_ID,
        "semantic_step": EXPECTED_FIRST_ACTIVE_INDEX,
        "phase": "establish_distal_support",
        "phase_step": 0,
        "matched_zero_command": False,
        "no_actuation_requested": False,
        "ordered_commands": commands,
        "bootstrap": False,
    }


def _production_serialization_controls(
    core: LocomotionCore,
) -> tuple[dict[str, bool], dict[str, Any]]:
    control = _active_control_fixture()
    targets, host_clamped = runtime.prepare_active_recovery_host_command_v1(
        np.zeros(len(runtime.ORDERED_ACTUATOR_IDS), dtype=np.float64),
        control["ordered_commands"],
    )
    application, digest = runtime.canonicalize_recovery_application_receipt_v1(
        core,
        route_id=ROUTE_ID,
        semantic_step=EXPECTED_FIRST_ACTIVE_INDEX,
        phase="establish_distal_support",
        arm_kind="candidate",
        control=control,
        active=True,
        targets=targets,
        host_clamped=host_clamped,
        signed_impulses=np.zeros(len(runtime.ORDERED_ACTUATOR_IDS), dtype=np.float64),
        maximum_forces=np.ones(len(runtime.ORDERED_ACTUATOR_IDS), dtype=np.float64),
        step_actuator_work_j=np.float64(0.0),
    )
    json.dumps(application, sort_keys=True, allow_nan=False)
    positive = (
        len(host_clamped) == len(runtime.ORDERED_ACTUATOR_IDS)
        and all(type(value) is bool for value in host_clamped)
        and all(host_clamped)
        and application["ordered_host_clamped"] == host_clamped
        and all(
            type(value) is bool for value in application["ordered_host_clamped"]
        )
        and len(application["ordered_host_target_velocity_rad_s"])
        == len(runtime.ORDERED_ACTUATOR_IDS)
        and all(
            math.isfinite(float(value))
            for value in application["ordered_host_target_velocity_rad_s"]
        )
        and isinstance(digest, str)
        and digest.startswith("sha256:")
        and len(digest) == 71
    )
    historical = list(host_clamped)
    historical[0] = np.bool_(historical[0])
    rejected = False
    rejection = ""
    try:
        runtime.canonicalize_recovery_application_receipt_v1(
            core,
            route_id=ROUTE_ID,
            semantic_step=EXPECTED_FIRST_ACTIVE_INDEX,
            phase="establish_distal_support",
            arm_kind="candidate",
            control=control,
            active=True,
            targets=targets,
            host_clamped=historical,
            signed_impulses=np.zeros(
                len(runtime.ORDERED_ACTUATOR_IDS), dtype=np.float64
            ),
            maximum_forces=np.ones(
                len(runtime.ORDERED_ACTUATOR_IDS), dtype=np.float64
            ),
            step_actuator_work_j=0.0,
        )
    except runtime.NativeRecoveryRouteError as error:
        rejection = str(error)
        rejected = rejection == "QSDK_R24D26_APPLICATION_HOST_CLAMP_TYPE:0"
    checks = {
        "production_active_receipt_canonicalizes_builtin_booleans": positive,
        "historical_numpy_boolean_receipt_rejected_before_physics": rejected,
    }
    details = {
        "production_application_sha256": digest,
        "ordered_host_clamped_type_names": [
            type(value).__name__ for value in application["ordered_host_clamped"]
        ],
        "historical_rejection": rejection,
    }
    return checks, details


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    inherited = predecessor.run_zero_world_preflight(core)
    checks, details = _production_serialization_controls(core)
    _require(all(checks.values()), "APPLICATION_SERIALIZATION_CONTROL_FAILED")
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "active_application_serialization_controls": checks,
            "active_application_serialization_control_details": details,
            "active_application_serialization_control_count": len(checks),
            "active_application_serialization_controls_passed": sum(
                checks.values()
            ),
            "inherited_r24d25_control_count": inherited["negative_control_count"],
            "negative_control_count": inherited["negative_control_count"]
            + len(checks),
            "negative_controls_passed": inherited["negative_controls_passed"]
            + sum(checks.values()),
            "production_active_receipt_path_called": True,
            "production_active_receipt_json_scalar_types_standard": True,
        }
    )
    return receipt


def compact_projection_v1(full: Mapping[str, Any]) -> dict[str, Any]:
    projection = predecessor.compact_projection_v1(full)
    projection.update(
        {
            "schema_version": (
                "sporespore_qsdk_r24d26_active_receipt_serialization_"
                "compact_projection_v1"
            ),
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "serialization_successor": True,
            "production_active_application_receipt_complete": bool(
                projection.get("execution_valid")
            ),
        }
    )
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
            "sporespore_qsdk_r24d26_active_receipt_serialization_full_result_v1"
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
            "sporespore_qsdk_r24d26_active_receipt_serialization_manifest_v1"
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
                "sporespore_qsdk_r24d26_active_receipt_serialization_invalid_v1"
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
