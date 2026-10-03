"""R24D35 sparse actuator-moment gate and qualified bounded route smoke."""

from __future__ import annotations

from collections import OrderedDict
from copy import deepcopy
from pathlib import Path
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import bounded_recovery_route_smoke as bounded_smoke
from . import native_recovery_development as runtime
from . import qsdk_r24d18_recovery_development_worker as shared
from . import sparse_actuator_moment as sparse_moment
from .implicit_step_energy_trace import (
    sparse_actuator_moment_trace_zero_world_controls_v1,
    validate_implicit_step_energy_trace_v1,
)


GATE_ID = "QSDK-R24D35"
CAMPAIGN_ID = "QSDK-R24D35-MUJOCO-SPARSE-ACTUATOR-MOMENT"
CONTRACT_SCHEMA = "sporespore_qsdk_r24d35_mujoco_sparse_actuator_moment_contract_v1"
PREFLIGHT_SCHEMA = "sporespore_qsdk_r24d35_mujoco_sparse_actuator_moment_preflight_v1"
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d35_mujoco_sparse_actuator_moment_zero_world_receipt_v1"
)
SMOKE_SCHEMAS = bounded_smoke.SmokeSchemasV1(
    result="sporespore_qsdk_r24d35_mujoco_sparse_actuator_moment_smoke_result_v1",
    summary="sporespore_qsdk_r24d35_mujoco_sparse_actuator_moment_smoke_summary_v1",
    manifest="sporespore_qsdk_r24d35_mujoco_sparse_actuator_moment_smoke_manifest_v1",
)
INVALID_SCHEMA = "sporespore_qsdk_r24d35_mujoco_sparse_actuator_moment_invalid_v1"
R24D34_SOURCE = "d7b477d0d92575fe1b1fe819591099cc5a02a86f"
R24D34_CLOSURE_COMMIT = "12b4f034243d872eba581b08a4bd88180f2ca62d"
R24D34_CLOSURE_SHA256 = (
    "sha256:100f9f7f951e7f6dad4a33d97cc7ad24d21d17d4bb275a4583d4066c78cd8a35"
)
EXPECTED_OUTER_STEPS_PER_ARM = 2
EXPECTED_PAIRED_ARM_COUNT = 2
EXPECTED_TOTAL_OUTER_STEPS = 4
EXPECTED_TOTAL_NATIVE_STEPS = 20
REPO_ROOT = Path(__file__).resolve().parents[4]
CONTRACT_PATH = REPO_ROOT / "sdk/recovery/r24d35_mujoco_sparse_actuator_moment_contract_v1.json"
R24D34_CONTRACT_PATH = (
    REPO_ROOT / "sdk/recovery/r24d34_mujoco_implicit_step_route_wiring_contract_v1.json"
)
R24D34_CLOSURE_PATH = (
    REPO_ROOT / "sdk/recovery/r24d34_mujoco_implicit_step_route_wiring_invalid_closure_v1.json"
)


class R24D35WorkerError(RuntimeError):
    """Stable fail-closed R24D35 worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D35WorkerError(code)


def load_contract_v1(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    contract = shared._load_json(path)
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "QUESTION_CLASS")
    _require(contract.get("physical_question_declared") is True, "PHYSICAL_QUESTION")
    _require(contract.get("behavior_question_declared") is False, "BEHAVIOR_QUESTION")
    _require(
        contract["lineage"]["predecessor_source_commit"] == R24D34_SOURCE
        and contract["lineage"]["predecessor_closure_commit"]
        == R24D34_CLOSURE_COMMIT
        and contract["lineage"]["predecessor_closure_raw_sha256"]
        == R24D34_CLOSURE_SHA256,
        "R24D34_LINEAGE",
    )
    _require(
        len(contract["source_inventory"])
        == len(set(contract["source_inventory"]))
        == contract["source_inventory_strategy"]["source_inventory_count"]
        == contract["prospective_freeze"]["source_inventory_count"],
        "SOURCE_INVENTORY",
    )
    return contract


def _validate_trace(result: Mapping[str, Any]) -> dict[str, Any]:
    return validate_implicit_step_energy_trace_v1(
        result,
        expected_route_id=runtime.SPARSE_MOMENT_IMPLICIT_STEP_ROUTE_ID,
        expected_native_receipt_schema=(
            runtime.SPARSE_MOMENT_IMPLICIT_STEP_NATIVE_RECEIPT_SCHEMA
        ),
        require_sparse_actuator_moment_expansion=True,
    )


def _zero_world_controls() -> tuple[OrderedDict[str, bool], dict[str, Any]]:
    contract = load_contract_v1()
    predecessor_contract = shared._load_json(R24D34_CONTRACT_PATH)
    closure = shared._load_json(R24D34_CLOSURE_PATH)
    preflight = runtime.run_sparse_actuator_moment_zero_world_preflight(
        LocomotionCore(REPO_ROOT / "sdk/target/debug/sporespore_locomotion_core.dll")
    )
    sparse_controls, sparse_details = (
        sparse_moment.sparse_actuator_moment_zero_world_controls_v1()
    )
    trace_controls, trace_details = (
        sparse_actuator_moment_trace_zero_world_controls_v1()
    )

    smoke = contract["bounded_native_code_path_smoke"]
    horizon = contract["ghost_horizon"]
    change = contract["controlled_change"]
    claims = contract["claim_boundary"]
    controls: OrderedDict[str, bool] = OrderedDict(
        [
            (
                "r24d34_invalid_closure_is_exact_consumed_and_not_reexecuted",
                shared._sha256_path(R24D34_CLOSURE_PATH)
                == R24D34_CLOSURE_SHA256
                and closure["source"]["commit"] == R24D34_SOURCE
                and closure["closure_status"]
                == "closed_consumed_invalid_incomplete_sparse_actuator_moment_representation_mismatch"
                and closure["qualification"]["controls_passed"] == 10
                and closure["physical_attempt"]["invalid_or_incomplete_retained"]
                is True
                and closure["physical_attempt"]["exact_execution_counts_published"]
                is False
                and closure["next_boundary"]["gate_id"] == GATE_ID
                and closure["next_boundary"]["r24d34_may_rerun"] is False,
            ),
            (
                "mujoco_3_11_sparse_fields_dimensions_and_public_api_are_bound",
                preflight["ok"] is True
                and preflight["engine_version"] == "3.11.0"
                and not preflight["missing_sparse_mjdata_fields"]
                and not preflight["missing_sparse_mjmodel_fields"]
                and not preflight["missing_sparse_functions"]
                and preflight["actuator_moment_expansion_profile_id"]
                == sparse_moment.PROFILE_ID
                and preflight["model_construction_count"] == 0,
            ),
            (
                "synthetic_sparse_expansion_matches_independent_exact_dense_matrix",
                sparse_controls["exact_expansion_and_receipt_replay"],
            ),
            (
                "malformed_sparse_counts_addresses_columns_dimensions_and_values_fail_closed",
                sparse_controls["malformed_sparse_representation_refused"],
            ),
            (
                "public_expansion_output_is_independently_crosschecked",
                sparse_controls["public_converter_output_crosschecked"],
            ),
            (
                "production_route_and_retained_trace_bind_sparse_expansion_receipts",
                runtime.MujocoSparseMomentImplicitStepRecoveryWorld.route_id
                == contract["route_wiring"]["route_id"]
                and runtime.MujocoSparseMomentImplicitStepRecoveryWorld.native_step_receipt_schema
                == contract["route_wiring"]["native_step_receipt_schema"]
                and runtime.MujocoSparseMomentImplicitStepRecoveryWorld.implicit_substep_receipt_schema
                == contract["route_wiring"]["native_substep_receipt_schema"]
                and trace_controls["complete_sparse_trace_replayed"],
            ),
            (
                "serialized_sparse_and_dense_observer_mutations_fail_closed",
                trace_controls["retained_sparse_and_dense_mutations_refused"],
            ),
            (
                "controller_physics_cell_seed_horizon_evaluator_thresholds_and_claims_are_unchanged",
                contract["selected_development_cell"]
                == predecessor_contract["selected_development_cell"]
                and smoke["maximum_outer_steps_per_arm"]
                == predecessor_contract["bounded_native_code_path_smoke"][
                    "maximum_outer_steps_per_arm"
                ]
                == EXPECTED_OUTER_STEPS_PER_ARM
                and smoke["paired_arm_count"]
                == horizon["paired_arm_count"]
                == EXPECTED_PAIRED_ARM_COUNT
                and smoke["maximum_total_outer_steps"] == EXPECTED_TOTAL_OUTER_STEPS
                and smoke["maximum_total_native_solver_steps"]
                == EXPECTED_TOTAL_NATIVE_STEPS
                and change["controller_changed"] is False
                and change["native_physics_configuration_changed"] is False
                and change["morphology_changed"] is False
                and change["initializer_changed"] is False
                and change["observer_formula_changed"] is False
                and change["selected_cell_changed"] is False
                and change["seed_changed"] is False
                and change["horizon_changed"] is False
                and change["portable_evaluator_changed"] is False
                and change["behavior_thresholds_changed"] is False
                and change["margins_changed"] is False
                and claims["prone_to_standing_claimed"] is False
                and claims["population_claimed"] is False
                and claims["cross_engine_equivalence_claimed"] is False,
            ),
            (
                "one_clean_pushed_qualification_then_one_serial_physical_smoke_is_the_only_authority",
                contract["complete_zero_world_gate"]["must_pass_before_physics"]
                is True
                and contract["qualification_and_smoke_authority"][
                    "physical_smoke_blocked_until_qualification_passes"
                ]
                is True
                and contract["qualification_and_smoke_authority"][
                    "physical_smoke_run_count_after_qualification"
                ]
                == 1
                and smoke["one_serialized_attempt_for_exact_source"] is True
                and smoke["full_seed_or_natural_stop_required"] is False
                and contract["held_out_seal"]["held_out_cell_access_count"] == 0,
            ),
        ]
    )
    return controls, {
        "r24d34_closure_raw_sha256": shared._sha256_path(R24D34_CLOSURE_PATH),
        "sparse_profile_id": sparse_moment.PROFILE_ID,
        "synthetic_sparse_nonzero_count": sparse_details[
            "synthetic_sparse_nonzero_count"
        ],
        "synthetic_dense_shape": sparse_details["synthetic_dense_shape"],
        "synthetic_validated_native_substeps": trace_details[
            "validated_native_substep_count"
        ],
        "synthetic_expansion_receipt_count": trace_details[
            "sparse_expansion_receipt_count"
        ],
    }


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    inherited = runtime.run_sparse_actuator_moment_zero_world_preflight(core)
    checks, details = _zero_world_controls()
    _require(all(checks.values()), "R24D35_ZERO_WORLD_CONTROL_FAILED")
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "gate_id": GATE_ID,
            "negative_control_count": len(checks),
            "negative_controls_passed": sum(checks.values()),
            "sparse_actuator_moment_controls": checks,
            "sparse_actuator_moment_control_details": details,
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
    contract = load_contract_v1(contract_path)
    return bounded_smoke.run_and_publish_v1(
        core_library=core_library,
        contract_path=contract_path,
        contract=contract,
        output_directory=output_directory,
        source_commit=source_commit,
        qualification_receipt_path=qualification_receipt_path,
        operation_lock_receipt_path=operation_lock_receipt_path,
        gate_id=GATE_ID,
        campaign_id=CAMPAIGN_ID,
        qualification_receipt_schema=QUALIFICATION_RECEIPT_SCHEMA,
        schemas=SMOKE_SCHEMAS,
        world_type=runtime.MujocoSparseMomentImplicitStepRecoveryWorld,
        trace_validator=_validate_trace,
    )


def main(argv: Sequence[str] | None = None) -> int:
    return bounded_smoke.worker_main_v1(
        argv,
        description=__doc__ or "R24D35 sparse actuator-moment worker",
        gate_id=GATE_ID,
        campaign_id=CAMPAIGN_ID,
        invalid_schema=INVALID_SCHEMA,
        preflight=run_zero_world_preflight,
        run_and_publish=run_and_publish_smoke_v1,
    )


if __name__ == "__main__":
    raise SystemExit(main())
