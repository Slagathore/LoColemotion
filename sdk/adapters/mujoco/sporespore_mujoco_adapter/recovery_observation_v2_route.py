"""Pure R24D39 consumer for one MuJoCo recovery observation V2.

The publisher composes the already-qualified R24D38 native-component mapper
with the additive core V3 collector.  It imports no MuJoCo or NumPy module,
constructs no model or world, takes no solver step, and applies no behavior
threshold.  A native route may supply already-measured receipts later; this
module only validates, finalizes, content-addresses, and publishes them.
"""

from __future__ import annotations

from copy import deepcopy
import math
from typing import Any, Mapping, Sequence

from .recovery_energy_v2_mapping import (
    MAPPING_PROFILE_ID,
    MAPPING_RECEIPT_SCHEMA,
    PORTABLE_OBSERVATION_V2_SCHEMA,
    R24D36_NATIVE_SUBSTEPS_PER_OUTER_STEP,
    R24D36_ROUTE_ID,
    map_r24d36_components_to_recovery_observation_v2,
)
from .recovery_runtime import collection_request_v3, collect_native_v3


SOURCE_BINDING_SCHEMA = "sporespore_recovery_observation_v2_source_binding_v1"
PUBLICATION_RECEIPT_SCHEMA = (
    "sporespore_mujoco_recovery_observation_v2_publication_receipt_v1"
)
COLLECTION_RECEIPT_SCHEMA = "sporespore_recovery_native_collection_receipt_v2"
NATIVE_STEP_RECEIPT_SCHEMA = "sporespore_mujoco_recovery_native_step_receipt_v4"
IN_RUN_INVARIANT_RECEIPT_SCHEMA = (
    "sporespore_mujoco_recovery_observation_v2_in_run_invariants_v1"
)
IN_RUN_INVARIANT_VALIDATOR_ID = (
    "mujoco_recovery_observation_v2_native_step_invariants_v1"
)


class RecoveryObservationV2PublicationError(ValueError):
    """Stable fail-closed error for malformed publication inputs."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise RecoveryObservationV2PublicationError(code)


def _valid_digest(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 71
        and value.startswith("sha256:")
        and all(character in "0123456789abcdef" for character in value[7:])
    )


def _canonical_sha256(core: Any, value: Mapping[str, Any]) -> str:
    digest = core.canonicalize_json(deepcopy(dict(value))).get("sha256")
    _require(_valid_digest(digest), "QSDK_R24D39_CANONICAL_DIGEST_INVALID")
    return str(digest)


def _finite_number(value: Any, code: str) -> float:
    _require(
        isinstance(value, (int, float)) and not isinstance(value, bool),
        code,
    )
    result = float(value)
    _require(math.isfinite(result), code)
    return result


def _nonnegative_integer(value: Any, code: str) -> int:
    _require(
        isinstance(value, int) and not isinstance(value, bool) and value >= 0, code
    )
    return int(value)


def _require_json_finite(value: Any, code: str) -> None:
    """Reject a non-finite number anywhere in a retained native envelope."""

    if isinstance(value, float):
        _require(math.isfinite(value), code)
    elif isinstance(value, Mapping):
        for nested in value.values():
            _require_json_finite(nested, code)
    elif isinstance(value, Sequence) and not isinstance(value, (str, bytes)):
        for nested in value:
            _require_json_finite(nested, code)


def publish_recovery_observation_v2(
    core: Any,
    *,
    mapping_request: Mapping[str, Any],
    descriptor: Mapping[str, Any],
    morphology_context: Mapping[str, Any],
    capability_sha256: str,
    runtime_qualification_sha256: str,
    arm_kind: str,
    phase: str,
) -> dict[str, Any]:
    """Finalize, collect, and publish one source-bound observation V2."""

    mapping = map_r24d36_components_to_recovery_observation_v2(
        core,
        deepcopy(dict(mapping_request)),
    )
    return publish_recovery_observation_v2_mapping_v1(
        core,
        mapping=mapping,
        descriptor=descriptor,
        morphology_context=morphology_context,
        capability_sha256=capability_sha256,
        runtime_qualification_sha256=runtime_qualification_sha256,
        arm_kind=arm_kind,
        phase=phase,
    )


def publish_recovery_observation_v2_mapping_v1(
    core: Any,
    *,
    mapping: Mapping[str, Any],
    descriptor: Mapping[str, Any],
    morphology_context: Mapping[str, Any],
    capability_sha256: str,
    runtime_qualification_sha256: str,
    arm_kind: str,
    phase: str,
    mapping_profile_id: str = MAPPING_PROFILE_ID,
    mapping_receipt_schema: str = MAPPING_RECEIPT_SCHEMA,
    publisher_id: str = "sporespore_mujoco_r24d39_observation_v2_publisher_v1",
) -> dict[str, Any]:
    """Publish one already-mapped V2 observation through the public collector."""

    mapping = deepcopy(dict(mapping))
    _require(
        isinstance(mapping_profile_id, str)
        and bool(mapping_profile_id)
        and isinstance(mapping_receipt_schema, str)
        and bool(mapping_receipt_schema)
        and isinstance(publisher_id, str)
        and bool(publisher_id),
        "QSDK_R24D42_MAPPING_PUBLICATION_IDENTITY_INVALID",
    )
    _require(
        mapping.get("schema_version") == mapping_receipt_schema
        and mapping.get("mapping_profile_id") == mapping_profile_id
        and mapping.get("source_route_id") == R24D36_ROUTE_ID,
        "QSDK_R24D42_MAPPING_RECEIPT_IDENTITY_INVALID",
    )
    common = {
        "schema_version": PUBLICATION_RECEIPT_SCHEMA,
        "publisher_id": publisher_id,
        "source_route_id": R24D36_ROUTE_ID,
        "mapping_profile_id": mapping_profile_id,
        "mapping_receipt_schema": mapping_receipt_schema,
        "mapping_receipt_sha256": _canonical_sha256(core, mapping),
        "mapping_receipt": mapping,
        "threshold_applied": False,
        "physical_result": False,
        "publisher_imported_mujoco": False,
        "publisher_imported_numpy": False,
        "native_engine_execution_performed_by_publisher": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    if mapping.get("support_status") != "supported_exact":
        return {
            **common,
            "support_status": mapping.get("support_status"),
            "refusal_reason": mapping.get("refusal_reason"),
            "observation_source_binding": None,
            "observation_source_binding_sha256": None,
            "collection_request": None,
            "collection_receipt": None,
            "portable_observation_sha256": None,
            "portable_observation": None,
            "portable_observation_published": False,
        }

    observation = mapping.get("portable_observation")
    ledger = observation.get("energy_balance") if isinstance(observation, dict) else None
    _require(
        isinstance(observation, dict)
        and observation.get("schema_version") == PORTABLE_OBSERVATION_V2_SCHEMA
        and isinstance(ledger, dict)
        and ledger.get("source_profile_id") == mapping_profile_id
        and _valid_digest(mapping.get("source_component_receipts_sha256"))
        and _valid_digest(mapping.get("observation_base_sha256"))
        and _valid_digest(mapping.get("ledger_sha256"))
        and _valid_digest(mapping.get("portable_observation_sha256"))
        and mapping.get("threshold_applied") is False
        and mapping.get("physical_result") is False,
        "QSDK_R24D39_MAPPING_RECEIPT_INVALID",
    )
    source_binding_payload = {
        "schema_version": SOURCE_BINDING_SCHEMA,
        "producer_adapter_id": "sporespore_mujoco_adapter",
        "source_route_id": R24D36_ROUTE_ID,
        "mapping_profile_id": mapping_profile_id,
        "mapping_receipt_sha256": common["mapping_receipt_sha256"],
        "source_component_receipts_sha256": mapping["source_component_receipts_sha256"],
        "observation_base_sha256": mapping["observation_base_sha256"],
        "ledger_sha256": mapping["ledger_sha256"],
        "portable_observation_sha256": mapping["portable_observation_sha256"],
    }
    source_binding = {
        **source_binding_payload,
        "source_chain_sha256": _canonical_sha256(core, source_binding_payload),
    }
    collection_request = collection_request_v3(
        descriptor=descriptor,
        morphology_context=morphology_context,
        observation_source_binding=source_binding,
        observation=observation,
        capability_sha256=capability_sha256,
        runtime_qualification_sha256=runtime_qualification_sha256,
        arm_kind=arm_kind,
        phase=phase,
    )
    collection = collect_native_v3(core, collection_request)
    _require(
        collection.get("schema_version") == COLLECTION_RECEIPT_SCHEMA
        and collection.get("model_construction_count") == 0
        and collection.get("world_attempt_count") == 0
        and collection.get("world_build_count") == 0
        and collection.get("solver_step_count") == 0
        and collection.get("physics_state_modified") is False
        and collection.get("physical_acceptance_authority") is False
        and collection.get("release_authority") is False,
        "QSDK_R24D39_COLLECTION_RECEIPT_INVALID",
    )
    supported = collection.get("support_status") == "supported_exact"
    return {
        **common,
        "support_status": collection.get("support_status"),
        "refusal_reason": collection.get("refusal_reason"),
        "observation_source_binding": source_binding,
        "observation_source_binding_sha256": collection.get(
            "observation_source_binding_sha256"
        ),
        "collection_request": collection_request,
        "collection_receipt": collection,
        "portable_observation_sha256": (
            mapping["portable_observation_sha256"] if supported else None
        ),
        "portable_observation": observation if supported else None,
        "portable_observation_published": supported,
    }


def validate_recovery_observation_v2_in_run_invariants_v1(
    core: Any,
    *,
    publication: Mapping[str, Any],
    native_step: Mapping[str, Any],
    ordered_native_component_batches: Sequence[Mapping[str, Any]],
    expected_arm_kind: str,
    expected_phase: str,
) -> dict[str, Any]:
    """Replay one native V2 publication and bind it to its physical step.

    This validator is deliberately pure: the production world calls it after
    native integration but before returning the observation, and retained
    traces call it again after the run.  It constructs no model, takes no
    solver step, and applies no behavior threshold.
    """

    publication = deepcopy(dict(publication))
    native_step = deepcopy(dict(native_step))
    batches = deepcopy(list(ordered_native_component_batches))
    _require_json_finite(
        {
            "publication": publication,
            "native_step": native_step,
            "ordered_native_component_batches": batches,
        },
        "QSDK_R24D40_NONFINITE_NATIVE_ENVELOPE",
    )

    semantic_step = _nonnegative_integer(
        native_step.get("semantic_step"),
        "QSDK_R24D40_NATIVE_SEMANTIC_STEP_INVALID",
    )
    substeps = native_step.get("implicit_substep_energy_receipts")
    _require(
        native_step.get("schema_version") == NATIVE_STEP_RECEIPT_SCHEMA
        and native_step.get("route_id") == R24D36_ROUTE_ID
        and native_step.get("host_step_before") == semantic_step
        and native_step.get("host_step_after") == semantic_step + 1
        and native_step.get("native_substep_count")
        == R24D36_NATIVE_SUBSTEPS_PER_OUTER_STEP
        and isinstance(substeps, list)
        and len(substeps) == R24D36_NATIVE_SUBSTEPS_PER_OUTER_STEP,
        "QSDK_R24D40_NATIVE_STEP_IDENTITY_INVALID",
    )
    _require(
        _nonnegative_integer(
            native_step.get("solver_step_count_after"),
            "QSDK_R24D40_SOLVER_COUNT_INVALID",
        )
        == (semantic_step + 1) * R24D36_NATIVE_SUBSTEPS_PER_OUTER_STEP,
        "QSDK_R24D40_SOLVER_COUNT_MISMATCH",
    )

    _require(
        len(batches) == semantic_step + 1
        and [batch.get("semantic_step") for batch in batches]
        == list(range(semantic_step + 1))
        and batches[-1].get("ordered_substep_receipts") == substeps,
        "QSDK_R24D40_COMPONENT_BATCH_SEQUENCE_INVALID",
    )
    for batch in batches:
        batch_substeps = batch.get("ordered_substep_receipts")
        _require(
            isinstance(batch_substeps, list)
            and len(batch_substeps) == R24D36_NATIVE_SUBSTEPS_PER_OUTER_STEP,
            "QSDK_R24D40_COMPONENT_BATCH_SUBSTEPS_INVALID",
        )

    time_before = _finite_number(
        native_step.get("time_before_s"),
        "QSDK_R24D40_NATIVE_TIME_INVALID",
    )
    time_after = _finite_number(
        native_step.get("time_after_s"),
        "QSDK_R24D40_NATIVE_TIME_INVALID",
    )
    native_timestep_sum = sum(
        _finite_number(
            receipt.get("native_timestep_s"),
            "QSDK_R24D40_NATIVE_TIMESTEP_INVALID",
        )
        for receipt in substeps
    )
    expected_time_after = time_before + native_timestep_sum
    time_tolerance = 8.0 * max(
        math.ulp(time_before),
        math.ulp(time_after),
        math.ulp(expected_time_after),
        math.ulp(1.0),
    )
    _require(
        native_timestep_sum > 0.0
        and time_after > time_before
        and abs(time_after - expected_time_after) <= time_tolerance,
        "QSDK_R24D40_NATIVE_TIME_ADVANCE_INVALID",
    )

    observation = publication.get("portable_observation")
    collection = publication.get("collection_request")
    mapping = publication.get("mapping_receipt")
    _require(
        publication.get("schema_version") == PUBLICATION_RECEIPT_SCHEMA
        and publication.get("source_route_id") == R24D36_ROUTE_ID
        and publication.get("support_status") == "supported_exact"
        and publication.get("portable_observation_published") is True
        and isinstance(observation, dict)
        and isinstance(collection, dict)
        and isinstance(mapping, dict),
        "QSDK_R24D40_PUBLICATION_INVALID",
    )
    identity = observation.get("engine_step_identity")
    ledger = observation.get("energy_balance")
    runtime_binding = collection.get("runtime_binding")
    native_step_sha256 = _canonical_sha256(core, native_step)
    _require(
        isinstance(identity, dict)
        and identity.get("source_trace_sha256") == native_step_sha256
        and identity.get("semantic_step") == semantic_step
        and identity.get("host_step_before") == semantic_step
        and identity.get("host_step_after") == semantic_step + 1
        and identity.get("native_solver_substep_count")
        == R24D36_NATIVE_SUBSTEPS_PER_OUTER_STEP
        and observation.get("semantic_step") == semantic_step
        and observation.get("outer_step_duration_s") == native_timestep_sum
        and isinstance(ledger, dict)
        and ledger.get("current_mechanical_energy_j")
        == native_step.get("current_mechanical_energy_j")
        and isinstance(runtime_binding, dict)
        and collection.get("arm_kind") == expected_arm_kind
        and collection.get("phase") == expected_phase,
        "QSDK_R24D40_NATIVE_PUBLICATION_BINDING_INVALID",
    )
    _require(
        mapping.get("native_component_batch_count") == len(batches)
        and mapping.get("native_component_receipt_count")
        == len(batches) * R24D36_NATIVE_SUBSTEPS_PER_OUTER_STEP
        and mapping.get("first_semantic_step") == 0
        and mapping.get("last_semantic_step") == semantic_step,
        "QSDK_R24D40_MAPPING_CARDINALITY_INVALID",
    )

    observation_base = {
        key: deepcopy(value)
        for key, value in observation.items()
        if key not in {"schema_version", "energy_balance"}
    }
    replayed = publish_recovery_observation_v2(
        core,
        mapping_request={
            "schema_version": (
                "sporespore_mujoco_recovery_energy_v2_mapping_request_v1"
            ),
            "source_route_id": R24D36_ROUTE_ID,
            "initial_mechanical_energy_j": ledger["initial_mechanical_energy_j"],
            "current_mechanical_energy_j": ledger["current_mechanical_energy_j"],
            "observation_base": observation_base,
            "ordered_native_component_batches": batches,
        },
        descriptor=collection["descriptor"],
        morphology_context=collection["morphology_context"],
        capability_sha256=runtime_binding["capability_sha256"],
        runtime_qualification_sha256=runtime_binding["runtime_qualification_sha256"],
        arm_kind=expected_arm_kind,
        phase=expected_phase,
    )
    _require(
        replayed == publication,
        "QSDK_R24D40_PUBLICATION_REPLAY_MISMATCH",
    )

    payload = {
        "schema_version": IN_RUN_INVARIANT_RECEIPT_SCHEMA,
        "validator_id": IN_RUN_INVARIANT_VALIDATOR_ID,
        "native_source_route_id": R24D36_ROUTE_ID,
        "publication_route_id": (
            "sporespore_mujoco_exact_s169_recovery_observation_v2_consumer_v1"
        ),
        "arm_kind": expected_arm_kind,
        "phase": expected_phase,
        "semantic_step": semantic_step,
        "native_component_batch_count": len(batches),
        "validated_native_substep_count": len(substeps),
        "solver_step_count_after": native_step["solver_step_count_after"],
        "time_before_s": time_before,
        "time_after_s": time_after,
        "native_time_advance_s": native_timestep_sum,
        "native_time_tolerance_s": time_tolerance,
        "native_step_sha256": native_step_sha256,
        "publication_sha256": _canonical_sha256(core, publication),
        "portable_observation_sha256": publication["portable_observation_sha256"],
        "observation_source_binding_sha256": publication[
            "observation_source_binding_sha256"
        ],
        "all_numbers_finite": True,
        "native_time_advanced_exact_within_derived_ulp_tolerance": True,
        "native_counter_sequence_valid": True,
        "ordered_component_batches_replayed": True,
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
    return {
        **payload,
        "receipt_sha256": _canonical_sha256(core, payload),
    }
