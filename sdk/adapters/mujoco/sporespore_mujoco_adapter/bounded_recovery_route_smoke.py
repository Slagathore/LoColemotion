"""Reusable append-only publisher for tiny qualified recovery-route smokes."""

from __future__ import annotations

import argparse
from copy import deepcopy
from dataclasses import dataclass
import json
from pathlib import Path
import traceback
from typing import Any, Callable, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import native_recovery_development as runtime
from . import qsdk_r24d18_recovery_development_worker as shared
from . import qsdk_r24d32_corrected_energy_progression_worker as source_inventory


class BoundedRecoveryRouteSmokeError(RuntimeError):
    """Stable fail-closed error for the shared smoke publication seam."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise BoundedRecoveryRouteSmokeError(code)


@dataclass(frozen=True)
class SmokeSchemasV1:
    result: str
    summary: str
    manifest: str


def run_and_publish_v1(
    *,
    core_library: Path,
    contract_path: Path,
    contract: Mapping[str, Any],
    output_directory: Path,
    source_commit: str,
    qualification_receipt_path: Path,
    operation_lock_receipt_path: Path,
    gate_id: str,
    campaign_id: str,
    qualification_receipt_schema: str,
    schemas: SmokeSchemasV1,
    world_type: type[runtime.MujocoNativeRecoveryWorld],
    trace_validator: Callable[[Mapping[str, Any]], dict[str, Any]],
    route_factory: Callable[[LocomotionCore], runtime.PublicProfileModelRoute]
    | None = None,
) -> dict[str, Any]:
    """Run one contract-bounded paired route and retain its complete trace."""

    _require(output_directory.is_dir(), "OUTPUT_DIRECTORY_MISSING")
    qualification = shared._load_json(qualification_receipt_path)
    operation_lock = shared._load_json(operation_lock_receipt_path)
    _require(
        qualification.get("schema_version") == qualification_receipt_schema
        and qualification.get("gate_id") == gate_id
        and qualification.get("mode") == "qualification"
        and qualification.get("ok") is True
        and qualification.get("source_commit") == source_commit
        and qualification.get("model_construction_count") == 0
        and qualification.get("world_attempt_count") == 0
        and qualification.get("world_build_count") == 0
        and qualification.get("solver_step_count") == 0
        and qualification.get("physics_state_modified") is False,
        "QUALIFICATION_RECEIPT_INVALID",
    )
    _require(
        operation_lock.get("acquired") is True
        and operation_lock.get("role") == "physical"
        and operation_lock.get("test_only") is False,
        "OPERATION_LOCK_RECEIPT_INVALID",
    )
    source_state = source_inventory._source_state(contract)
    _require(
        source_state["worktree_clean"] is True
        and source_state["head_commit"] == source_commit,
        "SOURCE_STATE_NOT_CLEAN_EXACT",
    )

    horizon = contract["ghost_horizon"]
    smoke = contract["bounded_native_code_path_smoke"]
    execution_core = LocomotionCore(core_library)
    exact_route = None if route_factory is None else route_factory(execution_core)
    result = runtime.run_paired_development(
        execution_core,
        cell=deepcopy(contract["selected_development_cell"]),
        horizon_steps=int(horizon["outer_steps_per_arm"]),
        route=exact_route,
        world_type=world_type,
        behavior_claim_authority=False,
    )
    invariants = trace_validator(result)
    _require(
        result["model_construction_count"]
        == smoke["maximum_model_construction_count"]
        and result["world_attempt_count"] == smoke["maximum_world_attempt_count"]
        and result["world_build_count"] == smoke["maximum_world_build_count"]
        and result["outer_step_count"] == smoke["maximum_total_outer_steps"]
        and result["native_solver_step_count"]
        == smoke["maximum_total_native_solver_steps"]
        and invariants["validated_outer_step_count"]
        == smoke["maximum_total_outer_steps"]
        and invariants["validated_native_substep_count"]
        == smoke["maximum_total_native_solver_steps"],
        "SMOKE_EXECUTION_COUNTS_INVALID",
    )

    result_envelope = {
        "schema_version": schemas.result,
        "gate_id": gate_id,
        "campaign_id": campaign_id,
        "question_class": "development",
        "physical_question_scope": "bounded_native_code_path_smoke_only",
        "source_commit": source_commit,
        "source_state": source_state,
        "contract_path": contract_path.as_posix(),
        "contract_raw_sha256": shared._sha256_path(contract_path),
        "qualification_receipt_path": str(qualification_receipt_path),
        "qualification_receipt_raw_sha256": shared._sha256_path(
            qualification_receipt_path
        ),
        "operation_lock": operation_lock,
        "result": result,
        "trace_invariants": invariants,
        "code_path_integration_passed": True,
        "behavior_success_predicted_or_claimed": False,
        "official_behavior_identity_consumed": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    result_path = output_directory / "smoke_result.json"
    result_sha256 = shared._write_json_exclusive(result_path, result_envelope)

    summary = {
        "schema_version": schemas.summary,
        "gate_id": gate_id,
        "campaign_id": campaign_id,
        "source_commit": source_commit,
        "result_path": result_path.name,
        "result_raw_sha256": result_sha256,
        "model_construction_count": result["model_construction_count"],
        "world_attempt_count": result["world_attempt_count"],
        "world_build_count": result["world_build_count"],
        "outer_step_count": result["outer_step_count"],
        "native_solver_step_count": result["native_solver_step_count"],
        "validated_native_substep_count": invariants[
            "validated_native_substep_count"
        ],
        "trace_invariants": invariants,
        "code_path_integration_passed": True,
        "behavior_result_observed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    summary_path = output_directory / "smoke_summary.json"
    summary_sha256 = shared._write_json_exclusive(summary_path, summary)

    manifest = {
        "schema_version": schemas.manifest,
        "gate_id": gate_id,
        "campaign_id": campaign_id,
        "source_commit": source_commit,
        "artifacts": [
            {
                "path": result_path.name,
                "byte_length": result_path.stat().st_size,
                "raw_sha256": result_sha256,
            },
            {
                "path": summary_path.name,
                "byte_length": summary_path.stat().st_size,
                "raw_sha256": summary_sha256,
            },
        ],
        "source_manifest_canonical_sha256": source_state[
            "source_manifest_canonical_sha256"
        ],
        "complete_trace_retained": True,
        "trace_invariants_replayed": True,
        "code_path_integration_passed": True,
        "behavior_result_observed": False,
        "held_out_cell_access_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    manifest_path = output_directory / "manifest.json"
    manifest_sha256 = shared._write_json_exclusive(manifest_path, manifest)
    return {
        "ok": True,
        "code_path_integration_passed": True,
        "evidence_root": str(output_directory),
        "result_path": str(result_path),
        "result_raw_sha256": result_sha256,
        "summary_path": str(summary_path),
        "summary_raw_sha256": summary_sha256,
        "manifest_path": str(manifest_path),
        "manifest_raw_sha256": manifest_sha256,
        "models": result["model_construction_count"],
        "worlds": result["world_attempt_count"],
        "outer_steps": result["outer_step_count"],
        "solver_steps": result["native_solver_step_count"],
        "behavior_result_observed": False,
        "prone_to_standing_claimed": False,
    }


def worker_main_v1(
    argv: Sequence[str] | None,
    *,
    description: str,
    gate_id: str,
    campaign_id: str,
    invalid_schema: str,
    preflight: Callable[[LocomotionCore], dict[str, Any]],
    run_and_publish: Callable[..., dict[str, Any]],
) -> int:
    """Provide one reusable CLI and invalid-result envelope for route workers."""

    parser = argparse.ArgumentParser(description=description)
    commands = parser.add_subparsers(dest="command", required=True)
    preflight_parser = commands.add_parser("preflight")
    preflight_parser.add_argument("--core-library", type=Path, required=True)
    run_parser = commands.add_parser("run")
    run_parser.add_argument("--core-library", type=Path, required=True)
    run_parser.add_argument("--contract", type=Path, required=True)
    run_parser.add_argument("--output-directory", type=Path, required=True)
    run_parser.add_argument("--source-commit", required=True)
    run_parser.add_argument("--qualification-receipt", type=Path, required=True)
    run_parser.add_argument("--operation-lock-receipt", type=Path, required=True)
    arguments = parser.parse_args(argv)
    if arguments.command == "preflight":
        receipt = preflight(LocomotionCore(arguments.core_library.resolve()))
        print(json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0

    output_directory = arguments.output_directory.resolve()
    try:
        completion = run_and_publish(
            core_library=arguments.core_library.resolve(),
            contract_path=arguments.contract.resolve(),
            output_directory=output_directory,
            source_commit=str(arguments.source_commit),
            qualification_receipt_path=arguments.qualification_receipt.resolve(),
            operation_lock_receipt_path=arguments.operation_lock_receipt.resolve(),
        )
        print(json.dumps(completion, allow_nan=False, sort_keys=True))
        return 0
    except Exception as error:
        invalid = {
            "schema_version": invalid_schema,
            "gate_id": gate_id,
            "campaign_id": campaign_id,
            "source_commit": str(arguments.source_commit),
            "error_type": type(error).__name__,
            "error": str(error),
            "traceback": traceback.format_exc(),
            "native_collection_refusal": deepcopy(getattr(error, "diagnostic", None)),
            "invalid_or_incomplete_retained": True,
            "valid_behavior_result_observed": False,
            "held_out_cell_access_count": 0,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        if output_directory.is_dir():
            shared._write_json_exclusive(output_directory / "invalid_result.json", invalid)
        print(json.dumps(invalid, allow_nan=False, sort_keys=True))
        return 2
