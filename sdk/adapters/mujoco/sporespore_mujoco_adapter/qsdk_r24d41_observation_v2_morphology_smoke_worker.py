"""R24D41 exact recovery-morphology observation-V2 route smoke worker."""

from __future__ import annotations

from collections import OrderedDict
from copy import deepcopy
import inspect
from pathlib import Path
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import bounded_recovery_route_smoke as bounded_smoke
from . import native_recovery_development as runtime
from . import qsdk_r24d18_recovery_development_worker as shared
from . import qsdk_r24d40_observation_v2_native_smoke_worker as r40
from . import recovery_morphology_route as morphology
from . import recovery_observation_v2_morphology_route as conjunction
from .recovery_observation_v2_route_fixture import (
    synthetic_r24d40_native_invariant_case_v1,
)


GATE_ID = "QSDK-R24D41"
CAMPAIGN_ID = "QSDK-R24D41-MUJOCO-RECOVERY-MORPHOLOGY-OBSERVATION-V2-SMOKE"
CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d41_mujoco_recovery_morphology_observation_v2_smoke_contract_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r24d41_mujoco_recovery_morphology_observation_v2_"
    "smoke_preflight_v1"
)
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d41_mujoco_recovery_morphology_observation_v2_"
    "smoke_zero_world_receipt_v1"
)
SMOKE_SCHEMAS = bounded_smoke.SmokeSchemasV1(
    result=(
        "sporespore_qsdk_r24d41_mujoco_recovery_morphology_observation_v2_"
        "smoke_result_v1"
    ),
    summary=(
        "sporespore_qsdk_r24d41_mujoco_recovery_morphology_observation_v2_"
        "smoke_summary_v1"
    ),
    manifest=(
        "sporespore_qsdk_r24d41_mujoco_recovery_morphology_observation_v2_"
        "smoke_manifest_v1"
    ),
)
INVALID_SCHEMA = (
    "sporespore_qsdk_r24d41_mujoco_recovery_morphology_observation_v2_invalid_v1"
)
R24D40_SOURCE = "c68a1aef834998b9c57be59f2bffa8e134ddef64"
R24D40_CLOSURE_COMMIT = "a30d469742629ba8ce15c1d3d8b7169146a4e99b"
R24D40_CLOSURE_SHA256 = (
    "sha256:6015015a87e533ba128810282aba4338f36e3fab0a9e3b53fe7599728012a715"
)
R24D40_CLOSURE_AUDIT_SHA256 = (
    "sha256:9b12b3795ccd740fcad226a790b0593f1444e63240306141804135b8f841c72e"
)
EXPECTED_OUTER_STEPS_PER_ARM = 1
EXPECTED_PAIRED_ARM_COUNT = 2
EXPECTED_TOTAL_OUTER_STEPS = 2
EXPECTED_TOTAL_NATIVE_STEPS = 10
EXPECTED_SOURCE_INVENTORY_COUNT = 25
REPO_ROOT = Path(__file__).resolve().parents[4]
CONTRACT_PATH = (
    REPO_ROOT / "sdk/recovery/"
    "r24d41_mujoco_recovery_morphology_observation_v2_smoke_contract_v1.json"
)
R24D40_CLOSURE_PATH = (
    REPO_ROOT / "sdk/recovery/"
    "r24d40_mujoco_observation_v2_native_smoke_invalid_closure_v1.json"
)
R24D40_CLOSURE_AUDIT_PATH = (
    REPO_ROOT / "tests/test_qsdk_r24d40_observation_v2_native_smoke_invalid_closure.py"
)


class R24D41WorkerError(RuntimeError):
    """Stable fail-closed R24D41 worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D41WorkerError(code)


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
        lineage["predecessor_source_commit"] == R24D40_SOURCE
        and lineage["predecessor_closure_commit"] == R24D40_CLOSURE_COMMIT
        and lineage["predecessor_closure_raw_sha256"] == R24D40_CLOSURE_SHA256
        and lineage["predecessor_closure_audit_raw_sha256"]
        == R24D40_CLOSURE_AUDIT_SHA256,
        "R24D40_LINEAGE",
    )
    inventory = contract["source_inventory"]
    _require(
        len(inventory)
        == len(set(inventory))
        == contract["source_inventory_strategy"]["source_inventory_count"]
        == contract["prospective_freeze"]["source_inventory_count"]
        == EXPECTED_SOURCE_INVENTORY_COUNT,
        "SOURCE_INVENTORY",
    )
    cell = contract["selected_development_cell"]
    horizon = contract["ghost_horizon"]
    _require(
        cell["cell_id"] == "development_recovery_morphology_nominal"
        and cell["seed"] == 1129522465
        and cell["question_class"] == "development"
        and cell["random_draw_count"] == 0,
        "CELL_IDENTITY",
    )
    _require(
        horizon["outer_steps_per_arm"] == EXPECTED_OUTER_STEPS_PER_ARM
        and horizon["paired_arm_count"] == EXPECTED_PAIRED_ARM_COUNT,
        "HORIZON_IDENTITY",
    )
    return contract


def _expect_conjunction_refusal(
    core: LocomotionCore,
    model_route: runtime.PublicProfileModelRoute,
    world_type: type[runtime.MujocoNativeRecoveryWorld],
    expected: str,
) -> str:
    try:
        conjunction.validate_recovery_observation_v2_morphology_conjunction_v1(
            core,
            model_route,
            world_type,
        )
    except conjunction.RecoveryObservationV2MorphologyRouteError as error:
        _require(str(error) == expected, "CONJUNCTION_REFUSAL_ERROR")
        return str(error)
    raise R24D41WorkerError("CONJUNCTION_REFUSAL_ACCEPTED")


def _zero_world_controls(
    core: LocomotionCore,
) -> tuple[OrderedDict[str, bool], dict[str, Any]]:
    contract = load_contract_v1()
    closure = shared._load_json(R24D40_CLOSURE_PATH)
    inherited = runtime.run_signed_work_preprojection_zero_world_preflight(core)
    exact_route = morphology.compile_recovery_morphology_model_route(core)
    conjunction_receipt = (
        conjunction.validate_recovery_observation_v2_morphology_conjunction_v1(
            core,
            exact_route,
            conjunction.MujocoRecoveryMorphologyObservationV2World,
        )
    )
    base_route = runtime.compile_public_profile_model_route(core)
    base_refusal = _expect_conjunction_refusal(
        core,
        base_route,
        conjunction.MujocoRecoveryMorphologyObservationV2World,
        "QSDK_R24D41_RECOVERY_MORPHOLOGY_ROUTE_REQUIRED",
    )
    world_refusal = _expect_conjunction_refusal(
        core,
        exact_route,
        runtime.MujocoObservationV2RecoveryWorld,
        "QSDK_R24D41_COMPOSITE_WORLD_REQUIRED",
    )
    candidate_case = synthetic_r24d40_native_invariant_case_v1(core)
    zero_case = synthetic_r24d40_native_invariant_case_v1(
        core,
        arm_kind="matched_zero_command",
    )
    candidate_invariant = r40._invariant_receipt(core, candidate_case)
    zero_invariant = r40._invariant_receipt(core, zero_case)
    invariant_forced_failures = r40._forced_failure_count(core, candidate_case)
    smoke = contract["bounded_native_code_path_smoke"]
    horizon = contract["ghost_horizon"]
    change = contract["controlled_change"]
    claims = contract["claim_boundary"]
    route_factory_parameter = inspect.signature(
        bounded_smoke.run_and_publish_v1
    ).parameters.get("route_factory")
    controls: OrderedDict[str, bool] = OrderedDict(
        [
            (
                "r24d40_closure_is_exact_consumed_invalid_and_not_reexecuted",
                shared._sha256_path(R24D40_CLOSURE_PATH) == R24D40_CLOSURE_SHA256
                and shared._sha256_path(R24D40_CLOSURE_AUDIT_PATH)
                == R24D40_CLOSURE_AUDIT_SHA256
                and closure["source"]["commit"] == R24D40_SOURCE
                and closure["closure_status"]
                == "closed_consumed_invalid_recovery_morphology_route_context_missing"
                and closure["decision"]["r24d40_may_be_rerun"] is False
                and closure["next_boundary"]["gate_id"] == GATE_ID,
            ),
            (
                "exact_recovery_morphology_receipt_and_context_compile_at_zero_world",
                conjunction_receipt["ok"] is True
                and conjunction_receipt["compiled_receipt_schema"]
                == conjunction.EXPECTED_COMPILED_SCHEMA
                and conjunction_receipt["recovery_morphology_id"]
                == morphology.EXPECTED_RECOVERY_MORPHOLOGY_ID
                and conjunction_receipt["model_construction_count"] == 0
                and conjunction_receipt["world_attempt_count"] == 0
                and conjunction_receipt["solver_step_count"] == 0,
            ),
            (
                "composite_world_mro_methods_and_route_identities_are_exact",
                tuple(conjunction_receipt["world_mro"]) == conjunction.EXPECTED_MRO
                and conjunction_receipt["native_source_route_id"]
                == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID
                and conjunction_receipt["publication_route_id"]
                == runtime.OBSERVATION_V2_CONSUMER_ROUTE_ID
                and conjunction_receipt["initializer_id"] == morphology.INITIALIZER_ID,
            ),
            (
                "shared_smoke_explicit_route_factory_preserves_default_callers",
                route_factory_parameter is not None
                and route_factory_parameter.default is None
                and contract["route_conjunction"]["route_factory"]
                == "compile_recovery_morphology_model_route"
                and contract["route_conjunction"]["existing_callers_default_to_none"]
                is True,
            ),
            (
                "base_route_and_noncomposite_world_fail_closed_before_physics",
                base_refusal == "QSDK_R24D41_RECOVERY_MORPHOLOGY_ROUTE_REQUIRED"
                and world_refusal == "QSDK_R24D41_COMPOSITE_WORLD_REQUIRED",
            ),
            (
                "r24d40_invariant_replay_and_forced_failures_remain_exact",
                candidate_invariant["publication_replayed_exact"] is True
                and zero_invariant["publication_replayed_exact"] is True
                and candidate_invariant["receipt_sha256"]
                != zero_invariant["receipt_sha256"]
                and invariant_forced_failures == 7,
            ),
            (
                "controller_physics_morphology_initializer_cell_seed_horizon_evaluator_thresholds_and_margins_are_unchanged",
                change["production_route_factory_handoff_changed"] is True
                and change["production_world_composition_changed"] is True
                and change["r24d40_observed_constructor_input_changed"] is True
                and change["declared_recovery_morphology_changed"] is False
                and change["native_physics_changed"] is False
                and change["controller_changed"] is False
                and change["initializer_semantics_changed"] is False
                and change["selected_cell_changed"] is False
                and change["seed_changed"] is False
                and change["horizon_changed"] is False
                and change["portable_evaluator_changed"] is False
                and change["behavior_thresholds_changed"] is False
                and change["margins_changed"] is False,
            ),
            (
                "one_clean_pushed_qualification_then_one_serial_minimum_smoke_has_no_behavior_or_population_authority",
                contract["complete_zero_world_gate"]["must_pass_before_physics"] is True
                and contract["qualification_and_smoke_authority"][
                    "physical_smoke_run_count_after_qualification"
                ]
                == 1
                and smoke["maximum_outer_steps_per_arm"]
                == horizon["outer_steps_per_arm"]
                == EXPECTED_OUTER_STEPS_PER_ARM
                and smoke["paired_arm_count"]
                == horizon["paired_arm_count"]
                == EXPECTED_PAIRED_ARM_COUNT
                and smoke["maximum_total_outer_steps"] == EXPECTED_TOTAL_OUTER_STEPS
                and smoke["maximum_total_native_solver_steps"]
                == EXPECTED_TOTAL_NATIVE_STEPS
                and smoke["full_seed_or_natural_stop_required"] is False
                and smoke["additional_physical_canary_required"] is False
                and claims["prone_to_standing_claimed"] is False
                and claims["population_claimed"] is False
                and claims["sdk1_milestone_advanced"] is False,
            ),
        ]
    )
    return controls, {
        "r24d40_closure_raw_sha256": shared._sha256_path(R24D40_CLOSURE_PATH),
        "conjunction_receipt_sha256": conjunction_receipt["receipt_sha256"],
        "compiled_receipt_sha256": conjunction_receipt["compiled_receipt_sha256"],
        "model_xml_sha256": conjunction_receipt["model_xml_sha256"],
        "model_xml_byte_length": conjunction_receipt["model_xml_byte_length"],
        "candidate_invariant_receipt_sha256": candidate_invariant["receipt_sha256"],
        "matched_zero_invariant_receipt_sha256": zero_invariant["receipt_sha256"],
        "invariant_forced_failure_count": invariant_forced_failures,
        "conjunction_forced_failure_count": 2,
        "forced_failure_count": invariant_forced_failures + 2,
        "base_route_refusal": base_refusal,
        "noncomposite_world_refusal": world_refusal,
        "inherited_route_id": inherited["route_id"],
    }


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    inherited = runtime.run_signed_work_preprojection_zero_world_preflight(core)
    checks, details = _zero_world_controls(core)
    _require(all(checks.values()), "R24D41_ZERO_WORLD_CONTROL_FAILED")
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "gate_id": GATE_ID,
            "route_id": runtime.OBSERVATION_V2_CONSUMER_ROUTE_ID,
            "native_source_route_id": runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
            "compiled_receipt_schema": conjunction.EXPECTED_COMPILED_SCHEMA,
            "conjunction_schema": conjunction.CONJUNCTION_SCHEMA,
            "control_count": len(checks),
            "controls_passed": sum(checks.values()),
            "forced_failure_count": details["forced_failure_count"],
            "recovery_morphology_observation_v2_controls": checks,
            "recovery_morphology_observation_v2_control_details": details,
            "model_xml_sha256": details["model_xml_sha256"],
            "model_xml_byte_length": details["model_xml_byte_length"],
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
    validated = r40._validate_trace(result, core=core)
    for result_key, arm_kind in (
        ("candidate", "candidate_command"),
        ("matched_zero_command", "matched_zero_command"),
    ):
        arm = result[result_key]
        mapping = arm["native_recovery_morphology_readback"]
        initializer = arm["initializer_manifest"]
        context = arm["portable_recovery_morphology_context"]
        _require(
            arm["arm_kind"] == arm_kind
            and arm["route_id"] == runtime.OBSERVATION_V2_CONSUMER_ROUTE_ID
            and arm["native_source_route_id"]
            == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID
            and arm["portable_recovery_context_bound"] is True
            and mapping["ok"] is True
            and mapping["recovery_morphology_spec_sha256"]
            == morphology.EXPECTED_RECOVERY_MORPHOLOGY_SHA256
            and mapping["ordered_joint_readback_count"] == 8
            and all(
                item["matches_zero_world_mapping"]
                for item in mapping["ordered_joint_readbacks"]
            )
            and initializer["initializer_id"] == morphology.INITIALIZER_ID
            and initializer["recovery_morphology_id"]
            == morphology.EXPECTED_RECOVERY_MORPHOLOGY_ID
            and initializer["recovery_morphology_spec_sha256"]
            == morphology.EXPECTED_RECOVERY_MORPHOLOGY_SHA256
            and initializer["native_joint_position_readback_matches"] is True
            and context["schema_version"] == runtime.RECOVERY_MORPHOLOGY_CONTEXT_SCHEMA
            and context["recovery_morphology_id"]
            == morphology.EXPECTED_RECOVERY_MORPHOLOGY_ID,
            f"TRACE_MORPHOLOGY_CONJUNCTION_INVALID:{arm_kind}",
        )
    validated["schema_version"] = (
        "sporespore_qsdk_r24d41_recovery_morphology_observation_v2_trace_invariants_v1"
    )
    validated["recovery_morphology_arm_count"] = EXPECTED_PAIRED_ARM_COUNT
    validated["recovery_morphology_readback_exact"] = True
    validated["recovery_morphology_initializer_exact"] = True
    return validated


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
        world_type=conjunction.MujocoRecoveryMorphologyObservationV2World,
        trace_validator=lambda result: _validate_trace(result, core=validation_core),
        route_factory=morphology.compile_recovery_morphology_model_route,
    )


def main(argv: Sequence[str] | None = None) -> int:
    return bounded_smoke.worker_main_v1(
        argv,
        description=__doc__ or "R24D41 morphology observation-V2 smoke worker",
        gate_id=GATE_ID,
        campaign_id=CAMPAIGN_ID,
        invalid_schema=INVALID_SCHEMA,
        preflight=run_zero_world_preflight,
        run_and_publish=run_and_publish_smoke_v1,
    )


if __name__ == "__main__":
    raise SystemExit(main())
