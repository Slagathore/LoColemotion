"""R24D34 zero-world route gate and qualified bounded MuJoCo smoke worker."""

from __future__ import annotations

import argparse
import ast
from collections import OrderedDict
from copy import deepcopy
import hashlib
import inspect
import json
from pathlib import Path
import traceback
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import native_recovery_development as runtime
from . import qsdk_r24d18_recovery_development_worker as shared
from . import qsdk_r24d32_corrected_energy_progression_worker as r24d32
from .implicit_step_energy_trace import (
    TRACE_VALIDATOR_ID,
    ImplicitStepEnergyTraceError,
    synthetic_implicit_step_energy_trace_v1,
    validate_implicit_step_energy_trace_v1,
)


GATE_ID = "QSDK-R24D34"
CAMPAIGN_ID = "QSDK-R24D34-MUJOCO-IMPLICIT-STEP-ROUTE-WIRING"
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d34_mujoco_implicit_step_route_wiring_contract_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r24d34_mujoco_implicit_step_route_wiring_preflight_v1"
)
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d34_mujoco_implicit_step_route_wiring_zero_world_receipt_v1"
)
SMOKE_RESULT_SCHEMA = (
    "sporespore_qsdk_r24d34_mujoco_implicit_step_route_wiring_smoke_result_v1"
)
SMOKE_SUMMARY_SCHEMA = (
    "sporespore_qsdk_r24d34_mujoco_implicit_step_route_wiring_smoke_summary_v1"
)
SMOKE_MANIFEST_SCHEMA = (
    "sporespore_qsdk_r24d34_mujoco_implicit_step_route_wiring_smoke_manifest_v1"
)
INVALID_SCHEMA = (
    "sporespore_qsdk_r24d34_mujoco_implicit_step_route_wiring_invalid_v1"
)
R24D33_SOURCE = "4e7a94daebec600621cfeb6a1eaee54f43c8a196"
R24D33_CLOSURE_SHA256 = (
    "sha256:5088d34126362a74e90b4e32170e043f09a2e4d274cc569e0202fce2a9b0f9b0"
)
EXPECTED_CELL_ID = "development_recovery_morphology_nominal"
EXPECTED_SEED = 1129522465
EXPECTED_OUTER_STEPS_PER_ARM = 2
EXPECTED_PAIRED_ARM_COUNT = 2
EXPECTED_TOTAL_OUTER_STEPS = 4
EXPECTED_TOTAL_NATIVE_STEPS = 20
REPO_ROOT = Path(__file__).resolve().parents[4]
CONTRACT_PATH = (
    REPO_ROOT / "sdk/recovery/r24d34_mujoco_implicit_step_route_wiring_contract_v1.json"
)
R24D33_CLOSURE_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d33_mujoco_implicit_step_energy_measurement_qualification_closure_v1.json"
)
R24D17_CONTRACT_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"
)


class R24D34WorkerError(RuntimeError):
    """Stable fail-closed R24D34 worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D34WorkerError(code)


def _load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    _require(isinstance(value, dict), f"JSON_ROOT:{path}")
    return value


def _sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def load_contract_v1(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    contract = _load(path)
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "QUESTION_CLASS")
    _require(contract.get("physical_question_declared") is True, "PHYSICAL_QUESTION")
    _require(contract.get("behavior_question_declared") is False, "BEHAVIOR_QUESTION")
    _require(
        len(contract["source_inventory"])
        == len(set(contract["source_inventory"]))
        == contract["source_inventory_strategy"]["source_inventory_count"]
        == contract["prospective_freeze"]["source_inventory_count"],
        "SOURCE_INVENTORY",
    )
    return contract


def _called_attributes(function: Any) -> list[str]:
    tree = ast.parse(inspect.getsource(function))
    calls = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            if isinstance(node.func, ast.Attribute):
                calls.append((node.lineno, node.func.attr))
            elif isinstance(node.func, ast.Name):
                calls.append((node.lineno, node.func.id))
    return [name for _line, name in sorted(calls)]


def _mutation_rejected(mutator: Any, expected: str) -> bool:
    value = synthetic_implicit_step_energy_trace_v1()
    mutator(value)
    try:
        validate_implicit_step_energy_trace_v1(value)
    except (ImplicitStepEnergyTraceError, ValueError, runtime.NativeRecoveryRouteError) as error:
        return expected in str(error)
    return False


def _zero_world_controls() -> tuple[OrderedDict[str, bool], dict[str, Any]]:
    contract = load_contract_v1()
    closure = _load(R24D33_CLOSURE_PATH)
    threshold_contract = _load(R24D17_CONTRACT_PATH)
    energy_limit = next(
        item["value"]
        for item in threshold_contract["threshold_profile"]["thresholds"]
        if item["threshold_id"] == "maximum_energy_balance_residual_j"
    )
    preflight = runtime.run_implicit_step_energy_zero_world_preflight(
        LocomotionCore(REPO_ROOT / "sdk/target/debug/sporespore_locomotion_core.dll")
    )
    helper_calls = _called_attributes(runtime.advance_implicitfast_after_control_v3)
    expected_stage_calls = [
        "mj_fwdActuation",
        "mj_fwdAcceleration",
        "mj_fwdConstraint",
        "mj_sensorAcc",
        "mj_checkAcc",
        "mj_compareFwdInv",
        "mj_implicit",
    ]
    stage_calls = [name for name in helper_calls if name.startswith("mj_")]
    synthetic = synthetic_implicit_step_energy_trace_v1()
    validated = validate_implicit_step_energy_trace_v1(synthetic)

    def mutate_post_velocity(value: dict[str, Any]) -> None:
        value["candidate"]["native_receipts"][0]["native_step"][
            "implicit_substep_energy_receipts"
        ][0]["post_generalized_velocity"] = [0.0]

    def mutate_effective_force(value: dict[str, Any]) -> None:
        value["candidate"]["native_receipts"][0]["native_step"][
            "implicit_substep_energy_receipts"
        ][0]["implicit_v3"]["effective_implicit_actuator_force_nm"] = [999.0]

    def remove_substep(value: dict[str, Any]) -> None:
        value["candidate"]["native_receipts"][0]["native_step"][
            "implicit_substep_energy_receipts"
        ].pop()

    def mutate_v2_aggregate(value: dict[str, Any]) -> None:
        value["candidate"]["native_receipts"][0]["native_step"][
            "historical_v2_step_actuator_work_j"
        ] = 1.0

    def mutate_portable(value: dict[str, Any]) -> None:
        value["candidate"]["observations"][0]["energy_balance"][
            "cumulative_applied_actuator_work_j"
        ] = 1.0

    def mutate_elapsed_time(value: dict[str, Any]) -> None:
        value["candidate"]["native_receipts"][0]["native_step"][
            "time_after_s"
        ] = 0.6

    smoke = contract["bounded_native_code_path_smoke"]
    supervisor_horizon = contract["ghost_horizon"]
    route_wiring = contract["route_wiring"]
    claims = contract["claim_boundary"]
    checks: OrderedDict[str, bool] = OrderedDict(
        [
            (
                "r24d33_qualification_closure_is_exact_positive_and_consumed",
                _sha256(R24D33_CLOSURE_PATH) == R24D33_CLOSURE_SHA256
                and closure["source"]["commit"] == R24D33_SOURCE
                and closure["qualification"]["controls_passed"] == 12
                and closure["qualification"][
                    "official_qualification_attempt_count_for_source"
                ]
                == 1
                and closure["claim_boundary"][
                    "reusable_implicit_step_measurement_qualified"
                ]
                is True
                and closure["claim_boundary"]["measurement_wired_into_native_route"]
                is False,
            ),
            (
                "mujoco_3_11_split_step_source_and_required_public_api_are_bound",
                preflight["ok"] is True
                and preflight["engine_version"] == "3.11.0"
                and not preflight["missing_v3_mjdata_fields"]
                and not preflight["missing_v3_mjmodel_fields"]
                and not preflight["missing_v3_functions"]
                and preflight["model_construction_count"] == 0,
            ),
            (
                "production_route_uses_one_ordered_preintegration_snapshot_and_one_genuine_implicit_advance",
                stage_calls == expected_stage_calls
                and helper_calls.count("mj_implicit") == 1
                and "mj_step2" not in helper_calls
                and helper_calls.count("measure_implicit_step_energy_work_v3") == 1
                and runtime.MujocoImplicitStepRecoveryWorld.route_id
                == route_wiring["route_id"],
            ),
            (
                "serialized_substeps_rederive_v2_and_v3_from_retained_pre_post_state",
                validated["ok"] is True
                and validated["trace_validator_id"] == TRACE_VALIDATOR_ID
                and validated["validated_native_substep_count"] == 10
                and validated["all_substeps_rederived_from_retained_pre_post_state"]
                is True,
            ),
            (
                "force_timing_substep_cardinality_aggregate_and_portable_mutations_fail_closed",
                _mutation_rejected(
                    mutate_post_velocity,
                    "QSDK_R24D34_SUBSTEP_V3_MISMATCH",
                )
                and _mutation_rejected(
                    mutate_effective_force,
                    "QSDK_R24D34_EFFECTIVE_FORCE_MISMATCH",
                )
                and _mutation_rejected(
                    remove_substep,
                    "QSDK_R24D34_SUBSTEP_COUNT_MISMATCH",
                )
                and _mutation_rejected(
                    mutate_v2_aggregate,
                    "QSDK_R24D34_OUTER_AGGREGATE_MISMATCH",
                )
                and _mutation_rejected(
                    mutate_portable,
                    "QSDK_R24D34_NATIVE_PORTABLE_MAPPING_MISMATCH",
                )
                and _mutation_rejected(
                    mutate_elapsed_time,
                    "QSDK_R24D34_NATIVE_TIMESTEP_SUM_MISMATCH",
                ),
            ),
            (
                "historical_v2_and_effective_matched_zero_terms_remain_explicit",
                route_wiring["historical_v2_terms_retained_side_by_side"] is True
                and route_wiring[
                    "effective_implicit_force_is_not_relabelled_as_reported_applied_force"
                ]
                is True
                and validated["effective_matched_zero_nonzero_substep_count"] > 0,
            ),
            (
                "portable_energy_selects_v3_without_changing_controller_or_threshold",
                route_wiring["portable_actuator_work_selection"]
                == "v3_effective_centered_actuator_work"
                and energy_limit
                == contract["threshold_and_adequacy_authority"][
                    "maximum_energy_balance_residual_j"
                ]
                == 0.25
                and contract["controlled_change"]["controller_changed"] is False
                and contract["controlled_change"]["behavior_thresholds_changed"]
                is False,
            ),
            (
                "bounded_smoke_is_exactly_two_outer_steps_per_arm_and_not_behavior_evidence",
                smoke["maximum_outer_steps_per_arm"] == EXPECTED_OUTER_STEPS_PER_ARM
                and smoke["maximum_total_outer_steps"] == EXPECTED_TOTAL_OUTER_STEPS
                and smoke["maximum_total_native_solver_steps"]
                == EXPECTED_TOTAL_NATIVE_STEPS
                and smoke["behavior_question_declared"] is False
                and smoke["behavior_success_predicted_or_claimed"] is False
                and smoke["official_behavior_identity_consumed"] is False
                and supervisor_horizon["outer_steps_per_arm"]
                == smoke["maximum_outer_steps_per_arm"]
                and supervisor_horizon["paired_arm_count"]
                == smoke["paired_arm_count"]
                and supervisor_horizon["full_seed_or_natural_stop_required"]
                is False
                and supervisor_horizon["behavior_question_declared"] is False,
            ),
            (
                "held_out_population_equivalence_and_standing_claims_remain_closed",
                contract["held_out_seal"]["held_out_cell_access_count"] == 0
                and contract["held_out_seal"]["held_out_selector_invocation_count"]
                == 0
                and claims["prone_to_standing_claimed"] is False
                and claims["population_claimed"] is False
                and claims["cross_engine_equivalence_claimed"] is False,
            ),
            (
                "physical_smoke_requires_this_clean_pushed_qualification_and_one_writer",
                contract["qualification_and_smoke_authority"][
                    "clean_pushed_source_required"
                ]
                is True
                and contract["qualification_and_smoke_authority"][
                    "physical_smoke_blocked_until_qualification_passes"
                ]
                is True
                and smoke["one_serialized_attempt_for_exact_source"] is True
                and smoke["operation_lock_role"] == "physical",
            ),
        ]
    )
    return checks, {
        "r24d33_closure_raw_sha256": _sha256(R24D33_CLOSURE_PATH),
        "stage_calls": stage_calls,
        "trace_validator_id": TRACE_VALIDATOR_ID,
        "synthetic_validated_native_substeps": validated[
            "validated_native_substep_count"
        ],
        "synthetic_effective_matched_zero_nonzero_substeps": validated[
            "effective_matched_zero_nonzero_substep_count"
        ],
        "unchanged_maximum_energy_balance_residual_j": energy_limit,
    }


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    inherited = runtime.run_implicit_step_energy_zero_world_preflight(core)
    checks, details = _zero_world_controls()
    _require(all(checks.values()), "R24D34_ZERO_WORLD_CONTROL_FAILED")
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "gate_id": GATE_ID,
            "negative_control_count": len(checks),
            "negative_controls_passed": sum(checks.values()),
            "route_wiring_controls": checks,
            "route_wiring_control_details": details,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "behavior_question_opened": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
    )
    return receipt


def run_and_publish_smoke_v1(
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
    qualification = _load(qualification_receipt_path)
    operation_lock = _load(operation_lock_receipt_path)
    _require(
        qualification.get("schema_version") == QUALIFICATION_RECEIPT_SCHEMA
        and qualification.get("gate_id") == GATE_ID
        and qualification.get("mode") == "qualification"
        and qualification.get("ok") is True
        and qualification.get("source_commit") == source_commit
        and qualification.get("model_construction_count") == 0
        and qualification.get("world_attempt_count") == 0
        and qualification.get("solver_step_count") == 0,
        "QUALIFICATION_RECEIPT_INVALID",
    )
    _require(
        operation_lock.get("acquired") is True
        and operation_lock.get("role") == "physical"
        and operation_lock.get("test_only") is False,
        "OPERATION_LOCK_RECEIPT_INVALID",
    )
    source_state = r24d32._source_state(contract)
    _require(
        source_state["worktree_clean"] is True
        and source_state["head_commit"] == source_commit,
        "SOURCE_STATE_NOT_CLEAN_EXACT",
    )
    result = runtime.run_paired_development(
        LocomotionCore(core_library),
        cell=deepcopy(contract["selected_development_cell"]),
        horizon_steps=EXPECTED_OUTER_STEPS_PER_ARM,
        world_type=runtime.MujocoImplicitStepRecoveryWorld,
        behavior_claim_authority=False,
    )
    invariants = validate_implicit_step_energy_trace_v1(result)
    _require(
        result["model_construction_count"] == EXPECTED_PAIRED_ARM_COUNT
        and result["world_attempt_count"] == EXPECTED_PAIRED_ARM_COUNT
        and result["world_build_count"] == EXPECTED_PAIRED_ARM_COUNT
        and result["outer_step_count"] == EXPECTED_TOTAL_OUTER_STEPS
        and result["native_solver_step_count"] == EXPECTED_TOTAL_NATIVE_STEPS
        and invariants["validated_outer_step_count"] == EXPECTED_TOTAL_OUTER_STEPS
        and invariants["validated_native_substep_count"]
        == EXPECTED_TOTAL_NATIVE_STEPS,
        "SMOKE_EXECUTION_COUNTS_INVALID",
    )
    envelope = {
        "schema_version": SMOKE_RESULT_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "question_class": "development",
        "physical_question_scope": "bounded_native_code_path_smoke_only",
        "source_commit": source_commit,
        "source_state": source_state,
        "contract_path": contract_path.as_posix(),
        "contract_raw_sha256": _sha256(contract_path),
        "qualification_receipt_path": str(qualification_receipt_path),
        "qualification_receipt_raw_sha256": _sha256(qualification_receipt_path),
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
    result_sha256 = shared._write_json_exclusive(result_path, envelope)
    summary = {
        "schema_version": SMOKE_SUMMARY_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
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
        "effective_matched_zero_nonzero_substep_count": invariants[
            "effective_matched_zero_nonzero_substep_count"
        ],
        "code_path_integration_passed": True,
        "behavior_result_observed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    summary_path = output_directory / "smoke_summary.json"
    summary_sha256 = shared._write_json_exclusive(summary_path, summary)
    manifest = {
        "schema_version": SMOKE_MANIFEST_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
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
        print(json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    output_directory = arguments.output_directory.resolve()
    try:
        completion = run_and_publish_smoke_v1(
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
            "schema_version": INVALID_SCHEMA,
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
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


if __name__ == "__main__":
    raise SystemExit(main())
