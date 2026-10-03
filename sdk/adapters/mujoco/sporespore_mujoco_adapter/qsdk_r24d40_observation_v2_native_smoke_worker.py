"""R24D40 smallest native observation-V2 route smoke and replay gate."""

from __future__ import annotations

from collections import OrderedDict
from copy import deepcopy
from pathlib import Path
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import bounded_recovery_route_smoke as bounded_smoke
from . import native_recovery_development as runtime
from . import qsdk_r24d18_recovery_development_worker as shared
from . import recovery_observation_v2_route as route
from .recovery_observation_v2_route_fixture import (
    synthetic_r24d39_evaluation_request_v3,
    synthetic_r24d40_native_invariant_case_v1,
)


GATE_ID = "QSDK-R24D40"
CAMPAIGN_ID = "QSDK-R24D40-MUJOCO-OBSERVATION-V2-NATIVE-ROUTE-SMOKE"
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d40_mujoco_observation_v2_native_smoke_contract_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r24d40_mujoco_observation_v2_native_smoke_preflight_v1"
)
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d40_mujoco_observation_v2_native_smoke_zero_world_receipt_v1"
)
SMOKE_SCHEMAS = bounded_smoke.SmokeSchemasV1(
    result="sporespore_qsdk_r24d40_mujoco_observation_v2_native_smoke_result_v1",
    summary="sporespore_qsdk_r24d40_mujoco_observation_v2_native_smoke_summary_v1",
    manifest="sporespore_qsdk_r24d40_mujoco_observation_v2_native_smoke_manifest_v1",
)
INVALID_SCHEMA = "sporespore_qsdk_r24d40_mujoco_observation_v2_native_invalid_v1"
R24D39_SOURCE = "bb312b13934362c144eb98e628d5ad2082ba950c"
R24D39_CLOSURE_COMMIT = "8d71116e2fdcb9495201469faeaf7f4c4a80469a"
R24D39_CLOSURE_SHA256 = (
    "sha256:533791463a699bef5aeb5171e2ebf45f285290f334f81f44c8c8204191726cd7"
)
EXPECTED_OUTER_STEPS_PER_ARM = 1
EXPECTED_PAIRED_ARM_COUNT = 2
EXPECTED_TOTAL_OUTER_STEPS = 2
EXPECTED_TOTAL_NATIVE_STEPS = 10
EVALUATION_RECEIPT_SCHEMA = "sporespore_recovery_evaluation_receipt_v1"
REPO_ROOT = Path(__file__).resolve().parents[4]
CONTRACT_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d40_mujoco_observation_v2_native_smoke_contract_v1.json"
)
R24D39_CLOSURE_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d39_recovery_observation_v2_consumer_qualification_closure_v1.json"
)


class R24D40WorkerError(RuntimeError):
    """Stable fail-closed R24D40 worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D40WorkerError(code)


def load_contract_v1(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    contract = shared._load_json(path)
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "QUESTION_CLASS")
    _require(contract.get("physical_question_declared") is True, "PHYSICAL_QUESTION")
    _require(contract.get("behavior_question_declared") is False, "BEHAVIOR_QUESTION")
    lineage = contract["lineage"]
    _require(
        lineage["predecessor_source_commit"] == R24D39_SOURCE
        and lineage["predecessor_closure_commit"] == R24D39_CLOSURE_COMMIT
        and lineage["predecessor_closure_raw_sha256"] == R24D39_CLOSURE_SHA256,
        "R24D39_LINEAGE",
    )
    inventory = contract["source_inventory"]
    _require(
        len(inventory)
        == len(set(inventory))
        == contract["source_inventory_strategy"]["source_inventory_count"]
        == contract["prospective_freeze"]["source_inventory_count"],
        "SOURCE_INVENTORY",
    )
    return contract


def _invariant_receipt(core: LocomotionCore, case: Mapping[str, Any]) -> dict[str, Any]:
    return route.validate_recovery_observation_v2_in_run_invariants_v1(
        core,
        **deepcopy(dict(case)),
    )


def _forced_failure_count(core: LocomotionCore, case: Mapping[str, Any]) -> int:
    mutations: list[dict[str, Any]] = []
    reversed_time = deepcopy(dict(case))
    reversed_time["native_step"]["time_after_s"] = -1.0
    mutations.append(reversed_time)
    wrong_solver_count = deepcopy(dict(case))
    wrong_solver_count["native_step"]["solver_step_count_after"] = 4
    mutations.append(wrong_solver_count)
    wrong_batch_step = deepcopy(dict(case))
    wrong_batch_step["ordered_native_component_batches"][0]["semantic_step"] = 1
    mutations.append(wrong_batch_step)
    missing_substep = deepcopy(dict(case))
    missing_substep["native_step"]["implicit_substep_energy_receipts"].pop()
    mutations.append(missing_substep)
    broken_binding = deepcopy(dict(case))
    broken_binding["publication"]["portable_observation"]["engine_step_identity"][
        "source_trace_sha256"
    ] = "sha256:" + ("f" * 64)
    mutations.append(broken_binding)
    nonfinite = deepcopy(dict(case))
    nonfinite["native_step"]["time_after_s"] = float("nan")
    mutations.append(nonfinite)
    wrong_phase = deepcopy(dict(case))
    wrong_phase["expected_phase"] = "raise_body"
    mutations.append(wrong_phase)

    refused = 0
    for mutation in mutations:
        try:
            _invariant_receipt(core, mutation)
        except route.RecoveryObservationV2PublicationError:
            refused += 1
    _require(refused == len(mutations) == 7, "FORCED_FAILURE_NOT_CLOSED")
    return refused


def _zero_world_controls(
    core: LocomotionCore,
) -> tuple[OrderedDict[str, bool], dict[str, Any]]:
    contract = load_contract_v1()
    closure = shared._load_json(R24D39_CLOSURE_PATH)
    inherited = runtime.run_signed_work_preprojection_zero_world_preflight(core)
    candidate_case = synthetic_r24d40_native_invariant_case_v1(core)
    zero_case = synthetic_r24d40_native_invariant_case_v1(
        core,
        arm_kind="matched_zero_command",
    )
    candidate_receipt = _invariant_receipt(core, candidate_case)
    zero_receipt = _invariant_receipt(core, zero_case)
    synthetic_evaluation = core.recovery_evaluate_trace_v3(
        synthetic_r24d39_evaluation_request_v3(
            core,
            candidate_case["publication"],
        )
    )
    forced_failures = _forced_failure_count(core, candidate_case)
    smoke = contract["bounded_native_code_path_smoke"]
    horizon = contract["ghost_horizon"]
    change = contract["controlled_change"]
    claims = contract["claim_boundary"]
    controls: OrderedDict[str, bool] = OrderedDict(
        [
            (
                "r24d39_qualification_closure_is_exact_consumed_and_not_reexecuted",
                shared._sha256_path(R24D39_CLOSURE_PATH) == R24D39_CLOSURE_SHA256
                and closure["source"]["commit"] == R24D39_SOURCE
                and closure["closure_status"]
                == "closed_complete_zero_world_recovery_observation_v2_consumer_qualified_no_physical_question"
                and closure["qualification"]["controls_passed"] == 8
                and closure["next_boundary"]["gate_id"] == GATE_ID
                and closure["next_boundary"]["r24d39_may_be_requalified"] is False,
            ),
            (
                "mujoco_3_11_r36_native_source_and_r39_publication_dependencies_are_bound",
                inherited["engine_version"] == "3.11.0"
                and inherited["route_id"] == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID
                and inherited["model_construction_count"] == 0
                and callable(runtime.MujocoObservationV2RecoveryWorld.step_native),
            ),
            (
                "candidate_and_matched_zero_native_shaped_publications_replay_exactly",
                candidate_receipt["publication_replayed_exact"] is True
                and zero_receipt["publication_replayed_exact"] is True
                and candidate_receipt["arm_kind"] == "candidate_command"
                and zero_receipt["arm_kind"] == "matched_zero_command"
                and candidate_receipt["receipt_sha256"]
                != zero_receipt["receipt_sha256"]
                and synthetic_evaluation["schema_version"] == EVALUATION_RECEIPT_SCHEMA
                and synthetic_evaluation["support_status"] == "supported_exact",
            ),
            (
                "time_counter_batch_substep_binding_nonfinite_and_phase_mutations_fail_closed",
                forced_failures == 7,
            ),
            (
                "production_world_checks_and_retains_in_run_invariants_before_return",
                runtime.MujocoObservationV2RecoveryWorld.publication_route_id
                == runtime.OBSERVATION_V2_CONSUMER_ROUTE_ID
                and runtime.MujocoObservationV2RecoveryWorld.energy_work_preprojection_refusal_enabled
                is False
                and route.IN_RUN_INVARIANT_VALIDATOR_ID
                == contract["in_run_invariants"]["validator_id"],
            ),
            (
                "one_step_per_required_paired_arm_is_the_smallest_real_evaluator_route",
                smoke["maximum_outer_steps_per_arm"]
                == horizon["outer_steps_per_arm"]
                == EXPECTED_OUTER_STEPS_PER_ARM
                and smoke["paired_arm_count"]
                == horizon["paired_arm_count"]
                == EXPECTED_PAIRED_ARM_COUNT
                and smoke["maximum_total_outer_steps"] == EXPECTED_TOTAL_OUTER_STEPS
                and smoke["maximum_total_native_solver_steps"]
                == EXPECTED_TOTAL_NATIVE_STEPS
                and smoke["maximum_model_construction_count"] == 2,
            ),
            (
                "controller_physics_morphology_initializer_cell_seed_evaluator_thresholds_and_margins_are_unchanged",
                change["controller_changed"] is False
                and change["native_physics_changed"] is False
                and change["morphology_changed"] is False
                and change["initializer_changed"] is False
                and change["selected_cell_changed"] is False
                and change["seed_changed"] is False
                and change["portable_evaluator_changed"] is False
                and change["behavior_thresholds_changed"] is False
                and change["margins_changed"] is False,
            ),
            (
                "one_clean_pushed_qualification_then_one_serial_smoke_has_no_behavior_or_population_authority",
                contract["complete_zero_world_gate"]["must_pass_before_physics"] is True
                and contract["qualification_and_smoke_authority"][
                    "physical_smoke_run_count_after_qualification"
                ]
                == 1
                and smoke["one_serialized_attempt_for_exact_source"] is True
                and smoke["full_seed_or_natural_stop_required"] is False
                and claims["prone_to_standing_claimed"] is False
                and claims["population_claimed"] is False
                and claims["sdk1_milestone_advanced"] is False,
            ),
        ]
    )
    return controls, {
        "r24d39_closure_raw_sha256": shared._sha256_path(R24D39_CLOSURE_PATH),
        "candidate_invariant_receipt_sha256": candidate_receipt["receipt_sha256"],
        "matched_zero_invariant_receipt_sha256": zero_receipt["receipt_sha256"],
        "forced_failure_count": forced_failures,
        "public_evaluation_receipt_schema": synthetic_evaluation["schema_version"],
    }


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    inherited = runtime.run_signed_work_preprojection_zero_world_preflight(core)
    checks, details = _zero_world_controls(core)
    _require(all(checks.values()), "R24D40_ZERO_WORLD_CONTROL_FAILED")
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "gate_id": GATE_ID,
            "route_id": runtime.OBSERVATION_V2_CONSUMER_ROUTE_ID,
            "native_source_route_id": runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
            "control_count": len(checks),
            "controls_passed": sum(checks.values()),
            "forced_failure_count": details["forced_failure_count"],
            "observation_v2_native_smoke_controls": checks,
            "observation_v2_native_smoke_control_details": details,
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


def _validate_trace(
    result: Mapping[str, Any],
    *,
    core: LocomotionCore,
) -> dict[str, Any]:
    _require(
        result.get("schema_version")
        == "sporespore_mujoco_paired_recovery_development_result_v1"
        and result.get("route_id") == runtime.OBSERVATION_V2_CONSUMER_ROUTE_ID
        and result.get("portable_evaluation_request_schema")
        == "sporespore_recovery_evaluation_request_v3"
        and result.get("model_construction_count") == 2
        and result.get("world_attempt_count") == 2
        and result.get("world_build_count") == 2
        and result.get("outer_step_count") == EXPECTED_TOTAL_OUTER_STEPS
        and result.get("native_solver_step_count") == EXPECTED_TOTAL_NATIVE_STEPS
        and result.get("physics_state_modified") is True,
        "TRACE_TOP_LEVEL_INVALID",
    )
    invariant_hashes: list[str] = []
    validated_substeps = 0
    for result_key, arm_kind in (
        ("candidate", "candidate_command"),
        ("matched_zero_command", "matched_zero_command"),
    ):
        arm = result[result_key]
        observations = arm["observations"]
        native_receipts = arm["native_receipts"]
        collectors = arm["collector_receipts"]
        steps = arm["portable_step_receipts"]
        _require(
            arm["route_id"] == runtime.OBSERVATION_V2_CONSUMER_ROUTE_ID
            and arm["native_source_route_id"]
            == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID
            and arm["portable_observation_schema"]
            == "sporespore_recovery_observation_v2"
            and arm["outer_step_count"] == EXPECTED_OUTER_STEPS_PER_ARM
            and arm["native_solver_step_count"] == 5
            and len(observations)
            == len(native_receipts)
            == len(collectors)
            == len(steps)
            == EXPECTED_OUTER_STEPS_PER_ARM,
            f"TRACE_ARM_INVALID:{arm_kind}",
        )
        batches: list[dict[str, Any]] = []
        for semantic_step, native in enumerate(native_receipts):
            native_step = native["native_step"]
            publication = native["observation_v2_publication"]
            batches.append(
                {
                    "semantic_step": semantic_step,
                    "ordered_substep_receipts": deepcopy(
                        native_step["implicit_substep_energy_receipts"]
                    ),
                }
            )
            replay = route.validate_recovery_observation_v2_in_run_invariants_v1(
                core,
                publication=publication,
                native_step=native_step,
                ordered_native_component_batches=batches,
                expected_arm_kind=arm_kind,
                expected_phase=publication["collection_request"]["phase"],
            )
            _require(
                native["observation_v2_in_run_invariants"] == replay
                and native["native_source_route_id"]
                == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID
                and native["publication_route_id"]
                == runtime.OBSERVATION_V2_CONSUMER_ROUTE_ID
                and observations[semantic_step] == publication["portable_observation"]
                and collectors[semantic_step] == publication["collection_receipt"]
                and steps[semantic_step]["support_status"] == "supported_exact",
                f"TRACE_STEP_REPLAY_INVALID:{arm_kind}:{semantic_step}",
            )
            invariant_hashes.append(replay["receipt_sha256"])
            validated_substeps += replay["validated_native_substep_count"]
        request_trace = arm["portable_request_trace"]
        _require(
            request_trace["initialize_request_schema"]
            == "sporespore_recovery_initialize_request_v2"
            and request_trace["collection_request_schemas"]
            == ["sporespore_recovery_native_collection_request_v3"]
            and request_trace["step_request_schemas"]
            == ["sporespore_recovery_step_request_v3"]
            and request_trace["control_request_schemas"]
            == ["sporespore_recovery_control_request_v3"],
            f"TRACE_PUBLIC_REQUEST_FAMILY_INVALID:{arm_kind}",
        )

    evaluation = result["evaluation"]
    _require(
        evaluation["schema_version"] == EVALUATION_RECEIPT_SCHEMA
        and evaluation["support_status"] == "supported_exact"
        and evaluation["physical_development_trace_valid"] is True
        and isinstance(evaluation["verdict"], str)
        and bool(evaluation["verdict"])
        and result["controller_physical_viability_proven"] is False
        and result["prone_to_standing_claimed"] is False
        and result["repeatability_rate_claimed"] is False
        and result["population_claimed"] is False
        and result["physical_acceptance_authority"] is False
        and result["release_authority"] is False,
        "TRACE_EVALUATION_OR_CLAIM_INVALID",
    )
    return {
        "schema_version": (
            "sporespore_qsdk_r24d40_observation_v2_native_trace_invariants_v1"
        ),
        "validator_id": route.IN_RUN_INVARIANT_VALIDATOR_ID,
        "validated_arm_count": EXPECTED_PAIRED_ARM_COUNT,
        "validated_outer_step_count": EXPECTED_TOTAL_OUTER_STEPS,
        "validated_native_substep_count": validated_substeps,
        "in_run_invariant_receipt_sha256s": invariant_hashes,
        "portable_publication_replayed_exact": True,
        "public_collector_supervisor_controller_and_evaluator_executed": True,
        "evaluator_verdict_retained_without_behavior_interpretation": evaluation[
            "verdict"
        ],
        "behavior_threshold_selected_or_changed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


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
    validation_core = LocomotionCore(core_library)
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
        world_type=runtime.MujocoObservationV2RecoveryWorld,
        trace_validator=lambda result: _validate_trace(result, core=validation_core),
    )


def main(argv: Sequence[str] | None = None) -> int:
    return bounded_smoke.worker_main_v1(
        argv,
        description=__doc__ or "R24D40 observation-V2 native smoke worker",
        gate_id=GATE_ID,
        campaign_id=CAMPAIGN_ID,
        invalid_schema=INVALID_SCHEMA,
        preflight=run_zero_world_preflight,
        run_and_publish=run_and_publish_smoke_v1,
    )


if __name__ == "__main__":
    raise SystemExit(main())
