"""Linear-time content-addressed observation-V2 publication for long traces."""

from __future__ import annotations

from copy import deepcopy
import math
from typing import Any, Mapping

from sporespore_locomotion import LocomotionCore

from . import native_recovery_development as runtime
from . import recovery_energy_v2_mapping as full_mapping
from . import recovery_observation_v2_morphology_route as conjunction
from . import recovery_observation_v2_route as publication_route


MAPPING_PROFILE_ID = (
    "mujoco_r24d36_native_components_to_recovery_energy_v2_streaming_v1"
)
MAPPING_REQUEST_SCHEMA = (
    "sporespore_mujoco_recovery_energy_v2_streaming_mapping_request_v1"
)
MAPPING_RECEIPT_SCHEMA = (
    "sporespore_mujoco_recovery_energy_v2_streaming_mapping_receipt_v1"
)
STATE_SCHEMA = "sporespore_mujoco_recovery_energy_v2_streaming_state_v1"
CHAIN_GENESIS_SCHEMA = (
    "sporespore_mujoco_recovery_energy_v2_streaming_chain_genesis_v1"
)
CHAIN_STEP_SCHEMA = "sporespore_mujoco_recovery_energy_v2_streaming_chain_step_v1"
IN_RUN_INVARIANT_SCHEMA = (
    "sporespore_mujoco_recovery_observation_v2_streaming_in_run_invariants_v1"
)
IN_RUN_INVARIANT_VALIDATOR_ID = (
    "mujoco_recovery_observation_v2_streaming_native_step_invariants_v1"
)
CONJUNCTION_SCHEMA = (
    "sporespore_mujoco_recovery_morphology_observation_v2_streaming_conjunction_v1"
)
PUBLICATION_ROUTE_ID = (
    "sporespore_mujoco_exact_s169_recovery_observation_v2_streaming_consumer_v1"
)
PUBLISHER_ID = "sporespore_mujoco_r24d42_streaming_observation_v2_publisher_v1"
LEDGER_SCHEMA = "sporespore_recovery_energy_balance_ledger_v2"
LEDGER_EQUATION_ID = (
    "current_minus_initial_minus_actuator_minus_external_minus_constraint_plus_passive_v2"
)
LEDGER_COMPONENT_PARTITION_ID = (
    "sporespore_disjoint_actuator_external_constraint_passive_energy_partition_v2"
)
LEDGER_EVALUATION_REQUEST_SCHEMA = (
    "sporespore_recovery_energy_balance_evaluation_request_v2"
)
EXPECTED_NATIVE_SUBSTEPS = 5

_REQUEST_KEYS = frozenset(
    {
        "schema_version",
        "source_route_id",
        "initial_mechanical_energy_j",
        "current_mechanical_energy_j",
        "observation_base",
        "native_component_batch",
    }
)
_STATE_KEYS = frozenset(
    {
        "schema_version",
        "mapping_profile_id",
        "arm_kind",
        "initial_mechanical_energy_j",
        "next_semantic_step",
        "next_sequence_index",
        "native_component_batch_count",
        "native_component_receipt_count",
        "cumulative_applied_actuator_work_j",
        "cumulative_signed_external_work_j",
        "cumulative_signed_constraint_exchange_j",
        "cumulative_passive_dissipation_j",
        "source_chain_sha256",
        "state_sha256",
    }
)


class RecoveryObservationV2StreamingError(RuntimeError):
    """Stable fail-closed streaming publication error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise RecoveryObservationV2StreamingError(code)


def _canonical_sha256(core: LocomotionCore, value: Mapping[str, Any]) -> str:
    digest = core.canonicalize_json(deepcopy(dict(value))).get("sha256")
    _require(
        isinstance(digest, str)
        and digest.startswith("sha256:")
        and len(digest) == 71,
        "QSDK_R24D42_STREAMING_DIGEST_INVALID",
    )
    return digest


def _state_payload(value: Mapping[str, Any]) -> dict[str, Any]:
    return {key: deepcopy(item) for key, item in value.items() if key != "state_sha256"}


def initial_streaming_state_v1(
    core: LocomotionCore,
    *,
    initial_mechanical_energy_j: float,
    arm_kind: str,
) -> dict[str, Any]:
    _require(
        math.isfinite(initial_mechanical_energy_j)
        and arm_kind in {"candidate_command", "matched_zero_command"},
        "QSDK_R24D42_STREAMING_INITIAL_STATE_INVALID",
    )
    genesis = {
        "schema_version": CHAIN_GENESIS_SCHEMA,
        "mapping_profile_id": MAPPING_PROFILE_ID,
        "native_source_route_id": runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
        "arm_kind": arm_kind,
        "initial_mechanical_energy_j": initial_mechanical_energy_j,
    }
    payload = {
        "schema_version": STATE_SCHEMA,
        "mapping_profile_id": MAPPING_PROFILE_ID,
        "arm_kind": arm_kind,
        "initial_mechanical_energy_j": initial_mechanical_energy_j,
        "next_semantic_step": 0,
        "next_sequence_index": 0,
        "native_component_batch_count": 0,
        "native_component_receipt_count": 0,
        "cumulative_applied_actuator_work_j": 0.0,
        "cumulative_signed_external_work_j": 0.0,
        "cumulative_signed_constraint_exchange_j": 0.0,
        "cumulative_passive_dissipation_j": 0.0,
        "source_chain_sha256": _canonical_sha256(core, genesis),
    }
    return {**payload, "state_sha256": _canonical_sha256(core, payload)}


def validate_streaming_state_v1(
    core: LocomotionCore,
    value: Mapping[str, Any],
) -> dict[str, Any]:
    state = deepcopy(dict(value))
    _require(set(state) == _STATE_KEYS, "QSDK_R24D42_STREAMING_STATE_FIELDS")
    for field in (
        "initial_mechanical_energy_j",
        "cumulative_applied_actuator_work_j",
        "cumulative_signed_external_work_j",
        "cumulative_signed_constraint_exchange_j",
        "cumulative_passive_dissipation_j",
    ):
        _require(
            isinstance(state[field], (int, float))
            and not isinstance(state[field], bool)
            and math.isfinite(float(state[field])),
            f"QSDK_R24D42_STREAMING_STATE_NUMBER:{field}",
        )
    for field in (
        "next_semantic_step",
        "next_sequence_index",
        "native_component_batch_count",
        "native_component_receipt_count",
    ):
        _require(
            isinstance(state[field], int)
            and not isinstance(state[field], bool)
            and state[field] >= 0,
            f"QSDK_R24D42_STREAMING_STATE_COUNT:{field}",
        )
    _require(
        state["schema_version"] == STATE_SCHEMA
        and state["mapping_profile_id"] == MAPPING_PROFILE_ID
        and state["arm_kind"] in {"candidate_command", "matched_zero_command"}
        and state["next_sequence_index"]
        == state["native_component_receipt_count"]
        == state["native_component_batch_count"] * EXPECTED_NATIVE_SUBSTEPS
        and state["next_semantic_step"] == state["native_component_batch_count"]
        and state["cumulative_passive_dissipation_j"] >= 0.0
        and state["state_sha256"] == _canonical_sha256(core, _state_payload(state)),
        "QSDK_R24D42_STREAMING_STATE_INVALID",
    )
    return state


def streaming_mapping_request_v1(
    *,
    observation: Mapping[str, Any],
    native_step: Mapping[str, Any],
) -> dict[str, Any]:
    ledger = observation.get("energy_balance")
    _require(isinstance(ledger, Mapping), "QSDK_R24D42_STREAMING_LEDGER_REQUIRED")
    observation_base = {
        key: deepcopy(value)
        for key, value in observation.items()
        if key not in {"schema_version", "energy_balance"}
    }
    substeps = native_step.get("implicit_substep_energy_receipts")
    _require(
        isinstance(substeps, list) and len(substeps) == EXPECTED_NATIVE_SUBSTEPS,
        "QSDK_R24D42_STREAMING_NATIVE_SUBSTEPS_REQUIRED",
    )
    return {
        "schema_version": MAPPING_REQUEST_SCHEMA,
        "source_route_id": runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
        "initial_mechanical_energy_j": ledger["initial_mechanical_energy_j"],
        "current_mechanical_energy_j": ledger["current_mechanical_energy_j"],
        "observation_base": observation_base,
        "native_component_batch": {
            "semantic_step": native_step["semantic_step"],
            "ordered_substep_receipts": deepcopy(substeps),
        },
    }


def _add_finite(current: float, value: float, code: str) -> float:
    result = current + value
    _require(math.isfinite(result), code)
    return result


def map_native_batch_to_streaming_observation_v2_v1(
    core: LocomotionCore,
    request: Mapping[str, Any],
    prior_state: Mapping[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Validate one new native batch and extend the content-addressed ledger."""

    request = full_mapping._exact_keys(
        request,
        _REQUEST_KEYS,
        "QSDK_R24D42_STREAMING_MAPPING_REQUEST_FIELDS",
    )
    state = validate_streaming_state_v1(core, prior_state)
    _require(
        request["schema_version"] == MAPPING_REQUEST_SCHEMA
        and request["source_route_id"]
        == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
        "QSDK_R24D42_STREAMING_MAPPING_REQUEST_IDENTITY",
    )
    initial_energy = full_mapping._finite(
        request["initial_mechanical_energy_j"],
        "QSDK_R24D42_STREAMING_INITIAL_ENERGY",
    )
    current_energy = full_mapping._finite(
        request["current_mechanical_energy_j"],
        "QSDK_R24D42_STREAMING_CURRENT_ENERGY",
    )
    _require(
        initial_energy == state["initial_mechanical_energy_j"],
        "QSDK_R24D42_STREAMING_INITIAL_ENERGY_CHANGED",
    )
    batch = full_mapping._exact_keys(
        request["native_component_batch"],
        full_mapping._BATCH_KEYS,
        "QSDK_R24D42_STREAMING_BATCH_FIELDS",
    )
    semantic_step = full_mapping._exact_nonnegative_integer(
        batch["semantic_step"],
        "QSDK_R24D42_STREAMING_SEMANTIC_STEP",
    )
    substeps = batch["ordered_substep_receipts"]
    _require(
        semantic_step == state["next_semantic_step"]
        and isinstance(substeps, list)
        and len(substeps) == EXPECTED_NATIVE_SUBSTEPS,
        "QSDK_R24D42_STREAMING_BATCH_ORDER",
    )
    observation_base, no_external_intervention = (
        full_mapping._validate_observation_base(
            request["observation_base"],
            final_semantic_step=semantic_step,
            final_native_substep_count=len(substeps),
        )
    )
    component_mappings: list[dict[str, Any]] = []
    increments: list[dict[str, Any]] = []
    has_unqualified_passive = False
    cumulative_actuator = float(state["cumulative_applied_actuator_work_j"])
    cumulative_external = float(state["cumulative_signed_external_work_j"])
    cumulative_constraint = float(
        state["cumulative_signed_constraint_exchange_j"]
    )
    cumulative_passive = float(state["cumulative_passive_dissipation_j"])
    for native_substep, receipt in enumerate(substeps):
        components = full_mapping._validate_replayed_substep(
            receipt,
            expected_native_substep=native_substep,
        )
        sequence_index = state["next_sequence_index"] + native_substep
        passive_is_exact_zero = (
            components["signed_damper_work_j"]
            == components["signed_fluid_work_j"]
            == components["signed_adhesion_work_j"]
            == 0.0
        )
        has_unqualified_passive = (
            has_unqualified_passive or not passive_is_exact_zero
        )
        component_mappings.append(
            {
                "sequence_index": sequence_index,
                "semantic_step": semantic_step,
                "native_substep": native_substep,
                **components,
                "signed_external_work_j": 0.0,
                "passive_dissipation_j": 0.0 if passive_is_exact_zero else None,
                "source_measurement": True,
            }
        )
        if passive_is_exact_zero:
            increment = {
                "sequence_index": sequence_index,
                "semantic_step": semantic_step,
                "applied_actuator_work_j": components["applied_actuator_work_j"],
                "signed_external_work_j": 0.0,
                "signed_constraint_exchange_j": components[
                    "signed_constraint_exchange_j"
                ],
                "passive_dissipation_j": 0.0,
                "source_measurement": True,
            }
            increments.append(increment)
            cumulative_actuator = _add_finite(
                cumulative_actuator,
                float(increment["applied_actuator_work_j"]),
                "QSDK_R24D42_STREAMING_ACTUATOR_SUM",
            )
            cumulative_external = _add_finite(
                cumulative_external,
                float(increment["signed_external_work_j"]),
                "QSDK_R24D42_STREAMING_EXTERNAL_SUM",
            )
            cumulative_constraint = _add_finite(
                cumulative_constraint,
                float(increment["signed_constraint_exchange_j"]),
                "QSDK_R24D42_STREAMING_CONSTRAINT_SUM",
            )
            cumulative_passive = _add_finite(
                cumulative_passive,
                float(increment["passive_dissipation_j"]),
                "QSDK_R24D42_STREAMING_PASSIVE_SUM",
            )

    batch_sha256 = _canonical_sha256(core, batch)
    increments_payload = {"ordered_increments": increments}
    increments_sha256 = _canonical_sha256(core, increments_payload)
    chain_payload = {
        "schema_version": CHAIN_STEP_SCHEMA,
        "mapping_profile_id": MAPPING_PROFILE_ID,
        "arm_kind": state["arm_kind"],
        "semantic_step": semantic_step,
        "prior_source_chain_sha256": state["source_chain_sha256"],
        "native_component_batch_sha256": batch_sha256,
        "ordered_increment_batch_sha256": increments_sha256,
        "first_sequence_index": state["next_sequence_index"],
        "last_sequence_index": state["next_sequence_index"] + len(substeps) - 1,
    }
    next_chain = _canonical_sha256(core, chain_payload)
    next_payload = {
        **_state_payload(state),
        "next_semantic_step": semantic_step + 1,
        "next_sequence_index": state["next_sequence_index"] + len(substeps),
        "native_component_batch_count": state["native_component_batch_count"] + 1,
        "native_component_receipt_count": state["native_component_receipt_count"]
        + len(substeps),
        "cumulative_applied_actuator_work_j": cumulative_actuator,
        "cumulative_signed_external_work_j": cumulative_external,
        "cumulative_signed_constraint_exchange_j": cumulative_constraint,
        "cumulative_passive_dissipation_j": cumulative_passive,
        "source_chain_sha256": next_chain,
    }
    next_state = {
        **next_payload,
        "state_sha256": _canonical_sha256(core, next_payload),
    }
    common = {
        "schema_version": MAPPING_RECEIPT_SCHEMA,
        "mapping_profile_id": MAPPING_PROFILE_ID,
        "source_route_id": runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
        "source_substep_schema": runtime.SIGNED_WORK_PREPROJECTION_SUBSTEP_RECEIPT_SCHEMA,
        "request_sha256": _canonical_sha256(core, request),
        "source_component_receipts_sha256": next_chain,
        "observation_base_sha256": _canonical_sha256(core, observation_base),
        "prior_state_sha256": state["state_sha256"],
        "next_state_sha256": next_state["state_sha256"],
        "prior_source_chain_sha256": state["source_chain_sha256"],
        "source_chain_sha256": next_chain,
        "native_component_batch_sha256": batch_sha256,
        "ordered_increment_batch_sha256": increments_sha256,
        "native_component_batch_count": next_state["native_component_batch_count"],
        "native_component_receipt_count": next_state[
            "native_component_receipt_count"
        ],
        "current_batch_component_mappings": component_mappings,
        "current_batch_ordered_increments": increments if increments else None,
        "component_partition": {
            "actuator": "implicit_v3.effective_centered_actuator_work_j",
            "external": "exact_zero_only_when_intervention_ledger_is_zero",
            "constraint": "implicit_v3.centered_constraint_work_j_signed",
            "passive": "exact_zero_only_for_r24d36_qualified_damper_fluid_adhesion_subset",
            "mechanical_energy_change_used_as_work_source": False,
            "energy_balance_residual_used_as_work_source": False,
        },
        "history_retained_as": "content_addressed_prior_state_plus_current_native_batch",
        "prior_history_replayed_in_current_step": False,
        "threshold_applied": False,
        "physical_result": False,
        "native_engine_execution_executed": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    if has_unqualified_passive or not no_external_intervention:
        reason = (
            full_mapping.r24d36_projection.PASSIVE_WORK_REFUSAL
            if has_unqualified_passive
            else "nonzero_external_intervention_work_unmeasured"
        )
        return (
            {
                **common,
                "support_status": "unsupported_capability",
                "refusal_reason": reason,
                "ledger_sha256": None,
                "ledger_evaluation_receipt": None,
                "portable_observation_sha256": None,
                "portable_observation": None,
            },
            state,
        )

    ledger = {
        "schema_version": LEDGER_SCHEMA,
        "equation_id": LEDGER_EQUATION_ID,
        "component_partition_id": LEDGER_COMPONENT_PARTITION_ID,
        "source_profile_id": MAPPING_PROFILE_ID,
        "source_values_sha256": next_chain,
        "initial_mechanical_energy_j": initial_energy,
        "current_mechanical_energy_j": current_energy,
        "cumulative_applied_actuator_work_j": cumulative_actuator,
        "cumulative_signed_external_work_j": cumulative_external,
        "cumulative_signed_constraint_exchange_j": cumulative_constraint,
        "cumulative_passive_dissipation_j": cumulative_passive,
        "source_measurement": True,
    }
    evaluation = core.recovery_energy_balance_evaluate_v2(
        {
            "schema_version": LEDGER_EVALUATION_REQUEST_SCHEMA,
            "ledger": ledger,
        }
    )
    _require(
        evaluation.get("support_status") == "supported_exact"
        and evaluation.get("threshold_applied") is False
        and evaluation.get("physical_result") is False,
        "QSDK_R24D42_STREAMING_LEDGER_EVALUATION_REFUSED",
    )
    portable_observation = {
        "schema_version": publication_route.PORTABLE_OBSERVATION_V2_SCHEMA,
        **observation_base,
        "energy_balance": ledger,
    }
    return (
        {
            **common,
            "support_status": "supported_exact",
            "refusal_reason": None,
            "ledger_sha256": evaluation["ledger_sha256"],
            "ledger_evaluation_receipt": evaluation,
            "portable_observation_sha256": _canonical_sha256(
                core, portable_observation
            ),
            "portable_observation": portable_observation,
        },
        validate_streaming_state_v1(core, next_state),
    )


def publish_recovery_observation_v2_streaming_v1(
    core: LocomotionCore,
    *,
    mapping_request: Mapping[str, Any],
    prior_state: Mapping[str, Any],
    descriptor: Mapping[str, Any],
    morphology_context: Mapping[str, Any],
    capability_sha256: str,
    runtime_qualification_sha256: str,
    arm_kind: str,
    phase: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    state = validate_streaming_state_v1(core, prior_state)
    _require(
        arm_kind == state["arm_kind"],
        "QSDK_R24D42_STREAMING_ARM_KIND_CHANGED",
    )
    mapping, next_state = map_native_batch_to_streaming_observation_v2_v1(
        core,
        mapping_request,
        state,
    )
    published = publication_route.publish_recovery_observation_v2_mapping_v1(
        core,
        mapping=mapping,
        descriptor=descriptor,
        morphology_context=morphology_context,
        capability_sha256=capability_sha256,
        runtime_qualification_sha256=runtime_qualification_sha256,
        arm_kind=arm_kind,
        phase=phase,
        mapping_profile_id=MAPPING_PROFILE_ID,
        mapping_receipt_schema=MAPPING_RECEIPT_SCHEMA,
        publisher_id=PUBLISHER_ID,
    )
    return published, next_state


def validate_streaming_publication_in_run_v1(
    core: LocomotionCore,
    *,
    publication: Mapping[str, Any],
    native_step: Mapping[str, Any],
    mapping_request: Mapping[str, Any],
    prior_state: Mapping[str, Any],
    descriptor: Mapping[str, Any],
    morphology_context: Mapping[str, Any],
    capability_sha256: str,
    runtime_qualification_sha256: str,
    expected_arm_kind: str,
    expected_phase: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    publication = deepcopy(dict(publication))
    native_step = deepcopy(dict(native_step))
    state = validate_streaming_state_v1(core, prior_state)
    semantic_step = native_step.get("semantic_step")
    substeps = native_step.get("implicit_substep_energy_receipts")
    _require(
        isinstance(semantic_step, int)
        and not isinstance(semantic_step, bool)
        and semantic_step == state["next_semantic_step"]
        and native_step.get("schema_version")
        == runtime.SIGNED_WORK_PREPROJECTION_NATIVE_RECEIPT_SCHEMA
        and native_step.get("route_id")
        == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID
        and native_step.get("host_step_before") == semantic_step
        and native_step.get("host_step_after") == semantic_step + 1
        and native_step.get("native_substep_count") == EXPECTED_NATIVE_SUBSTEPS
        and native_step.get("solver_step_count_after")
        == (semantic_step + 1) * EXPECTED_NATIVE_SUBSTEPS
        and isinstance(substeps, list)
        and len(substeps) == EXPECTED_NATIVE_SUBSTEPS,
        "QSDK_R24D42_STREAMING_NATIVE_STEP_INVALID",
    )
    native_timestep_sum = sum(float(item["native_timestep_s"]) for item in substeps)
    time_before = float(native_step["time_before_s"])
    time_after = float(native_step["time_after_s"])
    expected_time_after = time_before + native_timestep_sum
    time_tolerance = max(
        math.ulp(time_before),
        math.ulp(time_after),
        math.ulp(expected_time_after),
        math.ulp(1.0),
    ) * 8.0
    _require(
        all(math.isfinite(value) for value in (time_before, time_after, native_timestep_sum))
        and native_timestep_sum > 0.0
        and time_after > time_before
        and abs(time_after - expected_time_after) <= time_tolerance,
        "QSDK_R24D42_STREAMING_NATIVE_TIME_INVALID",
    )
    replayed_mapping, next_state = map_native_batch_to_streaming_observation_v2_v1(
        core,
        mapping_request,
        state,
    )
    observation = publication.get("portable_observation")
    mapping = publication.get("mapping_receipt")
    source_binding = publication.get("observation_source_binding")
    collection_request = publication.get("collection_request")
    collection_receipt = publication.get("collection_receipt")
    identity = observation.get("engine_step_identity") if isinstance(observation, dict) else None
    _require(
        isinstance(mapping, dict)
        and replayed_mapping == mapping
        and publication.get("mapping_receipt_sha256")
        == _canonical_sha256(core, mapping)
        and publication.get("portable_observation_sha256")
        == replayed_mapping.get("portable_observation_sha256")
        and observation == replayed_mapping.get("portable_observation"),
        "QSDK_R24D42_STREAMING_MAPPING_REPLAY_MISMATCH",
    )
    source_binding_payload = {
        "schema_version": publication_route.SOURCE_BINDING_SCHEMA,
        "producer_adapter_id": "sporespore_mujoco_adapter",
        "source_route_id": runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
        "mapping_profile_id": MAPPING_PROFILE_ID,
        "mapping_receipt_sha256": publication["mapping_receipt_sha256"],
        "source_component_receipts_sha256": mapping[
            "source_component_receipts_sha256"
        ],
        "observation_base_sha256": mapping["observation_base_sha256"],
        "ledger_sha256": mapping["ledger_sha256"],
        "portable_observation_sha256": mapping["portable_observation_sha256"],
    }
    expected_source_binding = {
        **source_binding_payload,
        "source_chain_sha256": _canonical_sha256(core, source_binding_payload),
    }
    expected_collection_request = publication_route.collection_request_v3(
        descriptor=descriptor,
        morphology_context=morphology_context,
        observation_source_binding=expected_source_binding,
        observation=observation,
        capability_sha256=capability_sha256,
        runtime_qualification_sha256=runtime_qualification_sha256,
        arm_kind=expected_arm_kind,
        phase=expected_phase,
    )
    _require(
        source_binding == expected_source_binding
        and collection_request == expected_collection_request,
        "QSDK_R24D42_STREAMING_SOURCE_BINDING_REPLAY_MISMATCH",
    )
    _require(
        publication.get("schema_version")
        == publication_route.PUBLICATION_RECEIPT_SCHEMA
        and publication.get("publisher_id") == PUBLISHER_ID
        and publication.get("source_route_id")
        == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID
        and publication.get("mapping_profile_id") == MAPPING_PROFILE_ID
        and publication.get("mapping_receipt_schema") == MAPPING_RECEIPT_SCHEMA
        and publication.get("support_status") == "supported_exact"
        and publication.get("refusal_reason") is None
        and publication.get("portable_observation_published") is True
        and isinstance(collection_request, dict)
        and isinstance(collection_receipt, dict)
        and collection_receipt.get("support_status") == "supported_exact"
        and collection_receipt.get("supplied_native_post_step_observation_validated")
        is True
        and collection_receipt.get("observation") == observation
        and collection_receipt.get("observation_sha256")
        == publication["portable_observation_sha256"]
        and collection_receipt.get("observation_source_binding")
        == expected_source_binding
        and collection_receipt.get("observation_source_binding_sha256")
        == publication.get("observation_source_binding_sha256")
        == _canonical_sha256(core, expected_source_binding)
        and publication.get("threshold_applied") is False
        and publication.get("physical_result") is False
        and publication.get("model_construction_count") == 0
        and publication.get("world_attempt_count") == 0
        and publication.get("world_build_count") == 0
        and publication.get("solver_step_count") == 0
        and publication.get("physics_state_modified") is False,
        "QSDK_R24D42_STREAMING_COLLECTION_BINDING_INVALID",
    )
    _require(
        isinstance(identity, dict)
        and identity.get("source_trace_sha256") == _canonical_sha256(core, native_step)
        and identity.get("semantic_step") == semantic_step,
        "QSDK_R24D42_STREAMING_NATIVE_SOURCE_BINDING_INVALID",
    )
    payload = {
        "schema_version": IN_RUN_INVARIANT_SCHEMA,
        "validator_id": IN_RUN_INVARIANT_VALIDATOR_ID,
        "native_source_route_id": runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
        "publication_route_id": PUBLICATION_ROUTE_ID,
        "mapping_profile_id": MAPPING_PROFILE_ID,
        "arm_kind": expected_arm_kind,
        "phase": expected_phase,
        "semantic_step": semantic_step,
        "validated_native_substep_count": len(substeps),
        "solver_step_count_after": native_step["solver_step_count_after"],
        "time_before_s": time_before,
        "time_after_s": time_after,
        "native_time_advance_s": native_timestep_sum,
        "native_time_tolerance_s": time_tolerance,
        "native_step_sha256": _canonical_sha256(core, native_step),
        "prior_state_sha256": state["state_sha256"],
        "next_state_sha256": next_state["state_sha256"],
        "source_chain_sha256": next_state["source_chain_sha256"],
        "publication_sha256": _canonical_sha256(core, publication),
        "portable_observation_sha256": publication["portable_observation_sha256"],
        "observation_source_binding_sha256": publication[
            "observation_source_binding_sha256"
        ],
        "native_time_advanced_exact_within_derived_ulp_tolerance": True,
        "native_counter_sequence_valid": True,
        "current_native_batch_replayed": True,
        "prior_history_bound_by_content_addressed_state": True,
        "publication_replayed_exact": True,
        "native_source_physics_state_modified": True,
        "validator_model_construction_count": 0,
        "validator_world_attempt_count": 0,
        "validator_solver_step_count": 0,
        "validator_physics_state_modified": False,
        "behavior_threshold_applied": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    return (
        {**payload, "receipt_sha256": _canonical_sha256(core, payload)},
        next_state,
    )


class MujocoRecoveryMorphologyStreamingObservationV2World(
    conjunction.MujocoRecoveryMorphologyObservationV2World
):
    """R24D41 morphology/physics route with linear-time V2 publication."""

    publication_route_id = PUBLICATION_ROUTE_ID

    def __init__(
        self,
        core: LocomotionCore,
        route: runtime.PublicProfileModelRoute,
        capability_sha256: str,
    ) -> None:
        super().__init__(core, route, capability_sha256)
        self.streaming_observation_v2_state: dict[str, Any] | None = None

    def step_native(
        self,
        *,
        semantic_step: int,
        phase: str,
        arm_kind: str,
        control: Mapping[str, Any],
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        observation_v1, native = (
            runtime.MujocoSignedWorkPreprojectionRecoveryWorld.step_native(
                self,
                semantic_step=semantic_step,
                phase=phase,
                arm_kind=arm_kind,
                control=control,
            )
        )
        native_step = native.get("native_step")
        _require(
            isinstance(native_step, dict),
            "QSDK_R24D42_STREAMING_NATIVE_STEP_REQUIRED",
        )
        if self.streaming_observation_v2_state is None:
            self.streaming_observation_v2_state = initial_streaming_state_v1(
                self.core,
                initial_mechanical_energy_j=float(self.initial_mechanical_energy_j),
                arm_kind=arm_kind,
            )
        prior_state = deepcopy(self.streaming_observation_v2_state)
        mapping_request = streaming_mapping_request_v1(
            observation=observation_v1,
            native_step=native_step,
        )
        published, next_state = publish_recovery_observation_v2_streaming_v1(
            self.core,
            mapping_request=mapping_request,
            prior_state=prior_state,
            descriptor=self.descriptor,
            morphology_context=self.observation_v2_morphology_context,
            capability_sha256=self.capability_sha256,
            runtime_qualification_sha256=runtime.R24D17_RUNTIME_QUALIFICATION_SHA256,
            arm_kind=arm_kind,
            phase=phase,
        )
        if published.get("support_status") != "supported_exact":
            raise runtime.NativeObservationV2PublicationRefusal(published)
        invariant, replayed_next_state = validate_streaming_publication_in_run_v1(
            self.core,
            publication=published,
            native_step=native_step,
            mapping_request=mapping_request,
            prior_state=prior_state,
            descriptor=self.descriptor,
            morphology_context=self.observation_v2_morphology_context,
            capability_sha256=self.capability_sha256,
            runtime_qualification_sha256=runtime.R24D17_RUNTIME_QUALIFICATION_SHA256,
            expected_arm_kind=arm_kind,
            expected_phase=phase,
        )
        _require(
            replayed_next_state == next_state,
            "QSDK_R24D42_STREAMING_NEXT_STATE_REPLAY_MISMATCH",
        )
        self.streaming_observation_v2_state = next_state
        native["observation_v2_in_run_invariants"] = invariant
        native["observation_v2_streaming_state"] = deepcopy(next_state)
        native["observation_v2_publication"] = published
        native["native_source_route_id"] = self.route_id
        native["publication_route_id"] = self.publication_route_id
        return deepcopy(published["portable_observation"]), native


def validate_streaming_morphology_route_v1(
    core: LocomotionCore,
    model_route: runtime.PublicProfileModelRoute,
) -> dict[str, Any]:
    """Bind the R24D41 composite to the additive streaming publisher, zero-world."""

    inherited = conjunction.validate_recovery_observation_v2_morphology_conjunction_v1(
        core,
        model_route,
        conjunction.MujocoRecoveryMorphologyObservationV2World,
    )
    world_type = MujocoRecoveryMorphologyStreamingObservationV2World
    _require(
        world_type.__bases__
        == (conjunction.MujocoRecoveryMorphologyObservationV2World,)
        and world_type.__init__
        is MujocoRecoveryMorphologyStreamingObservationV2World.__init__
        and world_type.step_native
        is MujocoRecoveryMorphologyStreamingObservationV2World.step_native
        and world_type.route_id == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID
        and world_type.publication_route_id == PUBLICATION_ROUTE_ID
        and world_type.initializer_id == inherited["initializer_id"]
        and world_type.native_step_receipt_schema
        == runtime.SIGNED_WORK_PREPROJECTION_NATIVE_RECEIPT_SCHEMA,
        "QSDK_R24D42_STREAMING_COMPOSITE_IDENTITY_INVALID",
    )
    payload = {
        "schema_version": CONJUNCTION_SCHEMA,
        "ok": True,
        "support_status": "supported_exact",
        "compiled_receipt_schema": inherited["compiled_receipt_schema"],
        "inherited_conjunction_schema": conjunction.CONJUNCTION_SCHEMA,
        "inherited_conjunction_receipt_sha256": inherited["receipt_sha256"],
        "native_source_route_id": runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
        "publication_route_id": PUBLICATION_ROUTE_ID,
        "mapping_profile_id": MAPPING_PROFILE_ID,
        "mapping_receipt_schema": MAPPING_RECEIPT_SCHEMA,
        "state_schema": STATE_SCHEMA,
        "world_type": (
            "sporespore_mujoco_adapter.recovery_observation_v2_streaming_route."
            "MujocoRecoveryMorphologyStreamingObservationV2World"
        ),
        "world_mro": [item.__name__ for item in world_type.__mro__],
        "model_xml_sha256": inherited["model_xml_sha256"],
        "model_xml_byte_length": inherited["model_xml_byte_length"],
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
    return {**payload, "receipt_sha256": _canonical_sha256(core, payload)}
