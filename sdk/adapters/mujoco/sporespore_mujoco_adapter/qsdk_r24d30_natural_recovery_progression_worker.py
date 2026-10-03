"""R24D30 natural-recovery progression successor over R24D29 semantics.

This module deliberately reuses the commissioned R24D27 progression decision,
the R24D28 refusal-retention path, and the R24D29 semantic preflight.  It adds
only a distinct campaign identity and append-only result publication for the
new physical development attempt.
"""

from __future__ import annotations

import argparse
from copy import deepcopy
import json
from pathlib import Path
import sys
import traceback
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import native_recovery_development as runtime
from . import qsdk_r24d18_recovery_development_worker as shared
from . import qsdk_r24d27_natural_recovery_progression_worker as progression
from . import qsdk_r24d28_collection_refusal_observability_worker as observability
from . import qsdk_r24d29_signed_clearance_semantics_worker as semantics
from .recovery_morphology_route import (
    EXPECTED_RECOVERY_DESCRIPTOR_SHA256,
    EXPECTED_RECOVERY_MORPHOLOGY_ID,
    EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
    ROUTE_ID,
    run_recovery_morphology_route_ghost,
)


GATE_ID = "QSDK-R24D30"
CAMPAIGN_ID = "QSDK-R24D30-MUJOCO-NATURAL-RECOVERY-PROGRESSION-DEVELOPMENT"
CONTRACT_SCHEMA = "sporespore_qsdk_r24d30_natural_recovery_progression_contract_v1"
PREFLIGHT_SCHEMA = "sporespore_qsdk_r24d30_natural_recovery_progression_preflight_v1"
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d30_natural_recovery_progression_zero_world_receipt_v1"
)
COMPACT_PROJECTION_SCHEMA = (
    "sporespore_qsdk_r24d30_natural_recovery_progression_compact_projection_v1"
)
FULL_RESULT_SCHEMA = (
    "sporespore_qsdk_r24d30_natural_recovery_progression_full_result_v1"
)
MANIFEST_SCHEMA = "sporespore_qsdk_r24d30_natural_recovery_progression_manifest_v1"
PARTIAL_RESULT_SCHEMA = (
    "sporespore_qsdk_r24d30_natural_recovery_progression_partial_result_v1"
)
INVALID_RESULT_SCHEMA = (
    "sporespore_qsdk_r24d30_natural_recovery_progression_invalid_v1"
)
R24D29_CLOSURE_SHA256 = (
    "sha256:1613ea7764fa8e4e4e4d84a4c8dad8997291814e9ede759c3812cff3b889d927"
)
R24D28_CLOSURE_SHA256 = (
    "sha256:83bf49035a3f8c36abc7f1d29a2b5a9d2cf8410263548bd8d76286d5d0e3bd57"
)
EXPECTED_CELL_ID = progression.EXPECTED_CELL_ID
EXPECTED_SEED = progression.EXPECTED_SEED
EXPECTED_MAXIMUM_HORIZON_STEPS = progression.EXPECTED_MAXIMUM_HORIZON_STEPS
EXPECTED_PAIRED_ARM_COUNT = progression.EXPECTED_PAIRED_ARM_COUNT
EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS = progression.EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS
EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS = (
    progression.EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS
)
EXPECTED_OBSERVER_RULE_ID = progression.EXPECTED_OBSERVER_RULE_ID
REPO_ROOT = Path(__file__).resolve().parents[4]
R24D29_CLOSURE_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d29_signed_clearance_semantics_qualification_closure_v1.json"
)


class R24D30WorkerError(RuntimeError):
    """Stable fail-closed R24D30 worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D30WorkerError(code)


def load_contract_v1(path: Path) -> dict[str, Any]:
    contract = shared._load_json(path)
    ledger = contract.get("ledger_scope")
    lineage = contract.get("lineage")
    physical_lineage = contract.get("physical_lineage")
    change = contract.get("controlled_change")
    cell = contract.get("selected_development_cell")
    horizon = contract.get("ghost_horizon")
    held_out = contract.get("held_out_seal")

    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "CONTRACT_QUESTION")
    _require(contract.get("physical_question_declared") is True, "CONTRACT_PHYSICAL")
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
        and lineage.get("predecessor_gate_id") == "QSDK-R24D29"
        and lineage.get("predecessor_closure_raw_sha256") == R24D29_CLOSURE_SHA256
        and lineage.get("predecessor_result")
        == "closed_complete_zero_world_signed_clearance_semantics_positive_no_physical_question"
        and lineage.get("predecessor_official_zero_world_qualification_passed") is True
        and lineage.get("predecessor_physical_question_opened") is False
        and lineage.get("predecessor_may_requalify") is False,
        "CONTRACT_LINEAGE",
    )
    _require(
        isinstance(physical_lineage, dict)
        and physical_lineage.get("latest_physical_gate_id") == "QSDK-R24D28"
        and physical_lineage.get("latest_physical_closure_raw_sha256")
        == R24D28_CLOSURE_SHA256
        and physical_lineage.get("latest_physical_may_rerun") is False,
        "CONTRACT_PHYSICAL_LINEAGE",
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
        and change.get("qualified_r24d29_semantics_consumed") is True
        and change.get("controller_changed") is False
        and change.get("native_physics_changed") is False
        and change.get("native_observer_changed") is False
        and change.get("behavior_thresholds_changed") is False
        and change.get("margins_changed") is False
        and change.get("cell_changed") is False
        and change.get("seed_changed") is False
        and change.get("horizon_changed") is False
        and change.get("progression_evaluator_meaning_changed") is False
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
        and horizon.get("outer_steps_per_arm") == EXPECTED_MAXIMUM_HORIZON_STEPS
        and horizon.get("maximum_steps_per_arm") == EXPECTED_MAXIMUM_HORIZON_STEPS
        and horizon.get("paired_arm_count") == EXPECTED_PAIRED_ARM_COUNT
        and horizon.get("maximum_total_outer_steps")
        == EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS
        and horizon.get("maximum_total_native_solver_steps")
        == EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS
        and set(horizon.get("existing_route_stop_phases", []))
        == progression.NATURAL_STOP_PHASES,
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


def retarget_projection_v1(value: Mapping[str, Any]) -> dict[str, Any]:
    """Give an unchanged R24D27 progression projection the R24D30 identity."""

    projection = deepcopy(dict(value))
    projection.update(
        {
            "schema_version": COMPACT_PROJECTION_SCHEMA,
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "qualified_signed_clearance_semantics_gate_id": "QSDK-R24D29",
        }
    )
    return projection


def compact_projection_v1(full: Mapping[str, Any]) -> dict[str, Any]:
    return retarget_projection_v1(progression.compact_projection_v1(full))


def build_collection_refusal_partial_v1(
    error: runtime.NativeRecoveryCollectionRefusal,
    *,
    source_commit: str,
    contract_path: str,
    qualification_receipt_path: str,
    operation_lock: Mapping[str, Any],
) -> dict[str, Any]:
    partial = observability.build_collection_refusal_partial_v1(
        error,
        source_commit=source_commit,
        contract_path=contract_path,
        qualification_receipt_path=qualification_receipt_path,
        operation_lock=operation_lock,
    )
    partial.update(
        {
            "schema_version": PARTIAL_RESULT_SCHEMA,
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "qualified_signed_clearance_semantics_gate_id": "QSDK-R24D29",
        }
    )
    shared._canonical_bytes(partial)
    return partial


def build_collection_refusal_invalid_v1(
    error: runtime.NativeRecoveryCollectionRefusal,
    *,
    source_commit: str,
    traceback_text: str,
    partial_result_path: str,
    partial_result_raw_sha256: str,
    partial_result_byte_length: int,
) -> dict[str, Any]:
    invalid = observability.build_collection_refusal_invalid_v1(
        error,
        source_commit=source_commit,
        traceback_text=traceback_text,
        partial_result_path=partial_result_path,
        partial_result_raw_sha256=partial_result_raw_sha256,
        partial_result_byte_length=partial_result_byte_length,
    )
    invalid.update(
        {
            "schema_version": INVALID_RESULT_SCHEMA,
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "qualified_signed_clearance_semantics_gate_id": "QSDK-R24D29",
        }
    )
    shared._canonical_bytes(invalid)
    return invalid


def publish_collection_refusal_v1(
    error: runtime.NativeRecoveryCollectionRefusal,
    *,
    output_directory: Path,
    source_commit: str,
    contract_path: Path,
    qualification_receipt_path: Path,
    operation_lock_receipt_path: Path,
    traceback_text: str,
) -> dict[str, Any]:
    operation_lock = shared._load_json(operation_lock_receipt_path)
    partial = build_collection_refusal_partial_v1(
        error,
        source_commit=source_commit,
        contract_path=contract_path.as_posix(),
        qualification_receipt_path=str(qualification_receipt_path),
        operation_lock=operation_lock,
    )
    partial_path = output_directory / "partial_result.json"
    partial_sha256 = shared._write_json_exclusive(partial_path, partial)
    invalid = build_collection_refusal_invalid_v1(
        error,
        source_commit=source_commit,
        traceback_text=traceback_text,
        partial_result_path=partial_path.name,
        partial_result_raw_sha256=partial_sha256,
        partial_result_byte_length=partial_path.stat().st_size,
    )
    shared._write_json_exclusive(output_directory / "invalid_result.json", invalid)
    return invalid


def _successor_integration_controls() -> tuple[dict[str, bool], dict[str, Any]]:
    closure = shared._load_json(R24D29_CLOSURE_PATH)
    positive = progression._positive_control_facts()
    base_projection = {
        "schema_version": progression.COMPACT_PROJECTION_SCHEMA
        if hasattr(progression, "COMPACT_PROJECTION_SCHEMA")
        else "sporespore_qsdk_r24d27_natural_recovery_progression_compact_projection_v1",
        "gate_id": progression.GATE_ID,
        "campaign_id": progression.CAMPAIGN_ID,
        "target_facts": deepcopy(positive),
        "target_checks": progression.evaluate_progression_facts_v1(positive),
        "execution_valid": True,
        "decision_positive": True,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    retargeted = retarget_projection_v1(base_projection)

    refusal = observability._synthetic_refusal_receipt()
    context = observability._synthetic_refusal_context()
    caught: runtime.NativeRecoveryCollectionRefusal | None = None
    try:
        runtime.require_supported_native_collection_v1(refusal, refusal_context=context)
    except runtime.NativeRecoveryCollectionRefusal as error:
        caught = error
    _require(caught is not None, "FORCED_REFUSAL_NOT_RAISED")
    partial = build_collection_refusal_partial_v1(
        caught,
        source_commit="0" * 40,
        contract_path="synthetic_zero_world_contract.json",
        qualification_receipt_path="synthetic_zero_world_qualification.json",
        operation_lock={"role": "conformance", "test_only": True},
    )

    checks = {
        "closed_r24d29_semantics_bound_exact": (
            shared._sha256_path(R24D29_CLOSURE_PATH) == R24D29_CLOSURE_SHA256
            and closure.get("closure_status")
            == "closed_complete_zero_world_signed_clearance_semantics_positive_no_physical_question"
            and closure.get("qualification", {}).get("controls_passed") == 45
            and closure.get("qualification", {}).get("world_attempt_count") == 0
        ),
        "progression_decision_retarget_preserves_all_nonidentity_fields": (
            all(base_projection[key] == retargeted[key] for key in base_projection if key not in {"schema_version", "gate_id", "campaign_id"})
            and retargeted["gate_id"] == GATE_ID
            and retargeted["campaign_id"] == CAMPAIGN_ID
            and all(retargeted["target_checks"].values())
        ),
        "collection_refusal_retarget_preserves_diagnostic_and_zero_claims": (
            partial["gate_id"] == GATE_ID
            and partial["campaign_id"] == CAMPAIGN_ID
            and partial["native_collection_refusal"]["collector_receipt"] == refusal
            and partial["native_collection_refusal"]["refusal_context"] == context
            and partial["prone_to_standing_claimed"] is False
            and partial["physical_acceptance_authority"] is False
            and partial["release_authority"] is False
        ),
    }
    details = {
        "r24d29_closure_raw_sha256": R24D29_CLOSURE_SHA256,
        "r24d29_qualification_control_count": 45,
        "progression_positive_check_count": len(retargeted["target_checks"]),
        "forced_refusal_semantic_step": context["semantic_step"],
    }
    return checks, details


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    inherited = semantics.run_zero_world_preflight(core)
    checks, details = _successor_integration_controls()
    _require(all(checks.values()), "SUCCESSOR_INTEGRATION_CONTROL_FAILED")
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "gate_id": GATE_ID,
            "inherited_r24d29_control_count": inherited["negative_control_count"],
            "successor_integration_controls": checks,
            "successor_integration_control_details": details,
            "successor_integration_control_count": len(checks),
            "successor_integration_controls_passed": sum(checks.values()),
            "negative_control_count": inherited["negative_control_count"] + len(checks),
            "negative_controls_passed": inherited["negative_controls_passed"]
            + sum(checks.values()),
            "maximum_horizon_steps_per_arm": EXPECTED_MAXIMUM_HORIZON_STEPS,
            "production_route_stop_semantics_reused": True,
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
    )
    return receipt


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
        horizon_steps=EXPECTED_MAXIMUM_HORIZON_STEPS,
    )
    projection = compact_projection_v1(result)
    envelope = {
        "schema_version": FULL_RESULT_SCHEMA,
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
        "qualified_signed_clearance_semantics_gate_id": "QSDK-R24D29",
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
        "schema_version": MANIFEST_SCHEMA,
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


def _generic_invalid(
    error: Exception,
    *,
    source_commit: str,
    traceback_text: str,
) -> dict[str, Any]:
    return {
        "schema_version": INVALID_RESULT_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "source_commit": source_commit,
        "error_type": type(error).__name__,
        "error": str(error),
        "traceback": traceback_text,
        "exact_native_collection_refusal_retained": False,
        "invalid_but_retained": True,
        "valid_physical_behavior_result_observed": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    preflight = commands.add_parser("preflight")
    preflight.add_argument("--core-library", type=Path, required=True)
    run = commands.add_parser("run")
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
        receipt = run_zero_world_preflight(
            LocomotionCore(arguments.core_library.resolve())
        )
        print(json.dumps(receipt, sort_keys=True))
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
    except runtime.NativeRecoveryCollectionRefusal as error:
        trace = traceback.format_exc()
        output_directory = arguments.output_directory.resolve()
        try:
            invalid = publish_collection_refusal_v1(
                error,
                output_directory=output_directory,
                source_commit=str(arguments.source_commit),
                contract_path=arguments.contract.resolve(),
                qualification_receipt_path=arguments.qualification_receipt.resolve(),
                operation_lock_receipt_path=arguments.operation_lock_receipt.resolve(),
                traceback_text=trace,
            )
        except Exception as publication_error:
            invalid = _generic_invalid(
                publication_error,
                source_commit=str(arguments.source_commit),
                traceback_text=traceback.format_exc(),
            )
            invalid["original_error_type"] = type(error).__name__
            invalid["original_error"] = str(error)
            invalid["original_collector_support_status"] = error.diagnostic.get(
                "collector_support_status"
            )
            invalid["original_collector_refusal_reason"] = error.diagnostic.get(
                "collector_refusal_reason"
            )
            invalid["refusal_publication_error"] = str(publication_error)
            invalid_path = output_directory / "invalid_result.json"
            if output_directory.is_dir() and not invalid_path.exists():
                shared._write_json_exclusive(invalid_path, invalid)
        print(json.dumps(invalid, sort_keys=True), file=sys.stderr)
        return 2
    except Exception as error:
        invalid = _generic_invalid(
            error,
            source_commit=str(arguments.source_commit),
            traceback_text=traceback.format_exc(),
        )
        output_directory = arguments.output_directory.resolve()
        invalid_path = output_directory / "invalid_result.json"
        if output_directory.is_dir() and not invalid_path.exists():
            shared._write_json_exclusive(invalid_path, invalid)
        print(json.dumps(invalid, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
