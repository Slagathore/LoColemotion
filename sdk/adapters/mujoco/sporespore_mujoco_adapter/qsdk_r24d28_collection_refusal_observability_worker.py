"""R24D28 exact native-collection refusal observability successor."""

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
from . import qsdk_r24d27_natural_recovery_progression_worker as predecessor
from .recovery_morphology_route import (
    EXPECTED_RECOVERY_DESCRIPTOR_SHA256,
    EXPECTED_RECOVERY_MORPHOLOGY_ID,
    EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
    ROUTE_ID,
    run_recovery_morphology_route_ghost,
)


CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d28_collection_refusal_observability_contract_v1"
)
CAMPAIGN_ID = (
    "QSDK-R24D28-MUJOCO-NATURAL-RECOVERY-PROGRESSION-OBSERVABLE-DEVELOPMENT"
)
GATE_ID = "QSDK-R24D28"
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d28_collection_refusal_observability_zero_world_receipt_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r24d28_collection_refusal_observability_preflight_v1"
)
EXPECTED_CELL_ID = predecessor.EXPECTED_CELL_ID
EXPECTED_SEED = predecessor.EXPECTED_SEED
EXPECTED_MAXIMUM_HORIZON_STEPS = predecessor.EXPECTED_MAXIMUM_HORIZON_STEPS
EXPECTED_PAIRED_ARM_COUNT = predecessor.EXPECTED_PAIRED_ARM_COUNT
EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS = (
    predecessor.EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS
)
EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS = (
    predecessor.EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS
)
EXPECTED_OBSERVER_RULE_ID = predecessor.EXPECTED_OBSERVER_RULE_ID
R24D27_CLOSURE_SHA256 = (
    "sha256:2c2794df584ba4758c37dec7f817209bca31c83dd42d8f55fd1463b408bc42e7"
)
REFUSAL_DIAGNOSTIC_SCHEMA = (
    "sporespore_mujoco_recovery_native_collection_refusal_diagnostic_v1"
)
PARTIAL_RESULT_SCHEMA = (
    "sporespore_qsdk_r24d28_collection_refusal_partial_result_v1"
)
INVALID_RESULT_SCHEMA = (
    "sporespore_qsdk_r24d28_collection_refusal_observability_invalid_v1"
)


class R24D28WorkerError(RuntimeError):
    """Stable fail-closed worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D28WorkerError(code)


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
        and lineage.get("predecessor_gate_id") == "QSDK-R24D27"
        and lineage.get("predecessor_closure_raw_sha256")
        == R24D27_CLOSURE_SHA256
        and lineage.get("predecessor_result")
        == "closed_consumed_invalid_incomplete_native_collection_refusal_observability_loss"
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
        and change.get("diagnostic_retention_changed") is True
        and change.get("controller_changed") is False
        and change.get("native_physics_changed") is False
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
        and horizon.get("outer_steps_per_arm") == EXPECTED_MAXIMUM_HORIZON_STEPS
        and horizon.get("maximum_steps_per_arm")
        == EXPECTED_MAXIMUM_HORIZON_STEPS
        and horizon.get("paired_arm_count") == EXPECTED_PAIRED_ARM_COUNT
        and horizon.get("maximum_total_outer_steps")
        == EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS
        and horizon.get("maximum_total_native_solver_steps")
        == EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS,
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


def _synthetic_refusal_context() -> dict[str, Any]:
    return {
        "schema_version": "sporespore_mujoco_recovery_arm_partial_state_v1",
        "route_id": ROUTE_ID,
        "cell_id": EXPECTED_CELL_ID,
        "arm_kind": "candidate_command",
        "semantic_step": 19,
        "phase": "establish_distal_support",
        "memory_before_current_step": {
            "phase": "establish_distal_support",
            "phase_steps_observed": 7,
        },
        "control_applied_current_step": {
            "support_status": "supported_exact",
            "semantic_step": 19,
            "phase": "establish_distal_support",
            "no_actuation_requested": False,
        },
        "current_collection_request": {
            "schema_version": "sporespore_recovery_native_collection_request_v2",
            "arm_kind": "candidate_command",
            "phase": "establish_distal_support",
            "observation": {"semantic_step": 19},
        },
        "current_observation": {"semantic_step": 19, "engine": "mujoco_native"},
        "current_native_receipt": {
            "semantic_step": 19,
            "solver_step_count": 100,
            "application": {"no_actuation_requested": False},
        },
        "accepted_prefix": {
            "observations": [{"semantic_step": 18}],
            "native_receipts": [{"semantic_step": 18}],
            "collector_receipts": [{"support_status": "supported_exact"}],
            "portable_step_receipts": [{"support_status": "supported_exact"}],
        },
        "portable_request_trace": {
            "initialize_request_schema": "sporespore_recovery_initialize_request_v2",
            "collection_request_schemas": [
                "sporespore_recovery_native_collection_request_v2"
            ],
            "step_request_schemas": ["sporespore_recovery_step_request_v2"],
            "control_request_schemas": ["sporespore_recovery_control_request_v2"],
        },
        "portable_initialization_receipt": {"support_status": "supported_exact"},
        "portable_recovery_morphology_context": {
            "recovery_morphology_id": EXPECTED_RECOVERY_MORPHOLOGY_ID
        },
        "initializer_manifest": {"initializer_id": "synthetic_zero_world"},
        "initializer_manifest_sha256": "sha256:" + "1" * 64,
        "canonical_pre_step_state": {"synthetic_zero_world": True},
        "canonical_pre_step_state_sha256": "sha256:" + "2" * 64,
        "physical_binding": {"synthetic_zero_world": True},
        "model_identity": {"synthetic_zero_world": True},
        "native_recovery_morphology_readback": {"synthetic_zero_world": True},
        "execution_counts": {
            "model_construction_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "native_outer_steps_completed": 20,
            "portable_steps_accepted": 19,
            "native_solver_step_count": 100,
            "physics_state_modified": True,
        },
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _synthetic_refusal_receipt() -> dict[str, Any]:
    return {
        "schema_version": "sporespore_recovery_native_collection_receipt_v1",
        "support_status": "invalid_observation",
        "refusal_reason": "energy_balance_invalid",
        "collector_id": "sporespore_mujoco_native_recovery_collector_v1",
        "adapter_id": "sporespore_mujoco_adapter_v1",
        "engine": "mujoco_native",
        "runtime_profile_id": "sporespore_mujoco_native_recovery_runtime_v1",
        "capability_sha256": "sha256:" + "3" * 64,
        "observation_sha256": None,
        "observation": None,
        "native_observation_validation_kernel_implemented": True,
        "native_adapter_collection_surface_implemented": True,
        "supplied_native_post_step_observation_validated": False,
        "native_runtime_observation_collection_executed": False,
        "engine_identity_exposed_to_controller": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def build_collection_refusal_partial_v1(
    error: runtime.NativeRecoveryCollectionRefusal,
    *,
    source_commit: str,
    contract_path: str,
    qualification_receipt_path: str,
    operation_lock: Mapping[str, Any],
) -> dict[str, Any]:
    diagnostic = deepcopy(error.diagnostic)
    _require(diagnostic.get("schema_version") == REFUSAL_DIAGNOSTIC_SCHEMA, "DIAGNOSTIC_SCHEMA")
    context = diagnostic.get("refusal_context")
    _require(isinstance(context, dict), "DIAGNOSTIC_CONTEXT")
    _require(isinstance(context.get("semantic_step"), int), "DIAGNOSTIC_STEP")
    _require(isinstance(context.get("phase"), str), "DIAGNOSTIC_PHASE")
    _require(isinstance(context.get("arm_kind"), str), "DIAGNOSTIC_ARM")
    _require(isinstance(context.get("current_observation"), dict), "DIAGNOSTIC_OBSERVATION")
    _require(isinstance(context.get("current_native_receipt"), dict), "DIAGNOSTIC_NATIVE")
    _require(isinstance(context.get("accepted_prefix"), dict), "DIAGNOSTIC_PREFIX")
    _require(isinstance(context.get("execution_counts"), dict), "DIAGNOSTIC_COUNTS")
    partial = {
        "schema_version": PARTIAL_RESULT_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "source_commit": source_commit,
        "contract_path": contract_path,
        "qualification_receipt_path": qualification_receipt_path,
        "operation_lock": deepcopy(dict(operation_lock)),
        "native_collection_refusal": diagnostic,
        "invalid_but_retained": True,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
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
    diagnostic = error.diagnostic
    context = diagnostic["refusal_context"]
    counts = context["execution_counts"]
    invalid = {
        "schema_version": INVALID_RESULT_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "source_commit": source_commit,
        "error_type": type(error).__name__,
        "error": str(error),
        "traceback": traceback_text,
        "collector_support_status": diagnostic.get("collector_support_status"),
        "collector_refusal_reason": diagnostic.get("collector_refusal_reason"),
        "collector_supplied_native_post_step_observation_validated": diagnostic.get(
            "collector_supplied_native_post_step_observation_validated"
        ),
        "arm_kind": context.get("arm_kind"),
        "semantic_step": context.get("semantic_step"),
        "phase": context.get("phase"),
        "execution_counts": deepcopy(counts),
        "current_observation_retained": True,
        "current_native_receipt_retained": True,
        "accepted_prefix_retained": True,
        "partial_result_path": partial_result_path,
        "partial_result_raw_sha256": partial_result_raw_sha256,
        "partial_result_byte_length": partial_result_byte_length,
        "invalid_but_retained": True,
        "valid_physical_behavior_result_observed": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
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


def _forced_refusal_observability_controls() -> tuple[dict[str, bool], dict[str, Any]]:
    refusal = _synthetic_refusal_receipt()
    context = _synthetic_refusal_context()
    caught: runtime.NativeRecoveryCollectionRefusal | None = None
    try:
        runtime.require_supported_native_collection_v1(
            refusal,
            refusal_context=context,
        )
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
    partial_raw = shared._canonical_bytes(partial) + b"\n"
    partial_sha256 = shared._sha256_bytes(partial_raw)
    invalid = build_collection_refusal_invalid_v1(
        caught,
        source_commit="0" * 40,
        traceback_text="synthetic_zero_world_forced_refusal",
        partial_result_path="partial_result.json",
        partial_result_raw_sha256=partial_sha256,
        partial_result_byte_length=len(partial_raw),
    )
    diagnostic = partial["native_collection_refusal"]
    retained_context = diagnostic["refusal_context"]
    checks = {
        "production_acceptance_helper_raises_typed_refusal": (
            isinstance(caught, runtime.NativeRecoveryRouteError)
            and str(caught) == "QSDK_R24D18_NATIVE_COLLECTION_REFUSED"
        ),
        "collector_status_and_reason_survive_exactly": (
            diagnostic["collector_receipt"] == refusal
            and invalid["collector_support_status"] == "invalid_observation"
            and invalid["collector_refusal_reason"] == "energy_balance_invalid"
        ),
        "step_phase_arm_and_current_receipts_survive_exactly": (
            retained_context["arm_kind"] == "candidate_command"
            and retained_context["semantic_step"] == 19
            and retained_context["phase"] == "establish_distal_support"
            and retained_context["current_observation"]
            == context["current_observation"]
            and retained_context["current_native_receipt"]
            == context["current_native_receipt"]
        ),
        "accepted_prefix_and_execution_counts_survive_exactly": (
            retained_context["accepted_prefix"] == context["accepted_prefix"]
            and retained_context["execution_counts"] == context["execution_counts"]
        ),
        "invalid_projection_binds_content_addressed_partial_result": (
            invalid["partial_result_path"] == "partial_result.json"
            and invalid["partial_result_raw_sha256"] == partial_sha256
            and invalid["partial_result_byte_length"] == len(partial_raw)
        ),
        "forced_refusal_retains_zero_claim_authority": (
            invalid["valid_physical_behavior_result_observed"] is False
            and invalid["prone_to_standing_claimed"] is False
            and invalid["physical_acceptance_authority"] is False
            and invalid["release_authority"] is False
        ),
    }
    details = {
        "forced_collector_support_status": invalid["collector_support_status"],
        "forced_collector_refusal_reason": invalid["collector_refusal_reason"],
        "forced_semantic_step": invalid["semantic_step"],
        "forced_phase": invalid["phase"],
        "forced_partial_result_raw_sha256": partial_sha256,
        "forced_partial_result_byte_length": len(partial_raw),
    }
    return checks, details


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    inherited = predecessor.run_zero_world_preflight(core)
    checks, details = _forced_refusal_observability_controls()
    _require(all(checks.values()), "REFUSAL_OBSERVABILITY_CONTROL_FAILED")
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "forced_refusal_observability_controls": checks,
            "forced_refusal_observability_control_details": details,
            "forced_refusal_observability_control_count": len(checks),
            "forced_refusal_observability_controls_passed": sum(checks.values()),
            "inherited_r24d27_control_count": inherited["negative_control_count"],
            "negative_control_count": inherited["negative_control_count"] + len(checks),
            "negative_controls_passed": inherited["negative_controls_passed"]
            + sum(checks.values()),
            "production_collection_acceptance_helper_called": True,
            "durable_invalid_projection_built_without_physics": True,
        }
    )
    return receipt


def compact_projection_v1(full: Mapping[str, Any]) -> dict[str, Any]:
    projection = predecessor.compact_projection_v1(full)
    projection.update(
        {
            "schema_version": (
                "sporespore_qsdk_r24d28_collection_refusal_observability_"
                "compact_projection_v1"
            ),
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "collection_refusal_observability_successor": True,
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
        horizon_steps=EXPECTED_MAXIMUM_HORIZON_STEPS,
    )
    projection = compact_projection_v1(result)
    envelope = {
        "schema_version": (
            "sporespore_qsdk_r24d28_collection_refusal_observability_full_result_v1"
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
            "sporespore_qsdk_r24d28_collection_refusal_observability_manifest_v1"
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
