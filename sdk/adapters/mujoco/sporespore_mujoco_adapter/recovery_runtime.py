"""Zero-world MuJoCo surface for the exact-s169 recovery runtime.

The native worker remains responsible for sampling ``MjData`` immediately
after its five native substeps. This module binds those complete measurements
to the engine-neutral Rust validation/controller ABI. It intentionally does
not import MuJoCo, build a model, allocate data, or call ``mj_step``.
"""

from __future__ import annotations

from copy import deepcopy
from typing import Any, Mapping

from sporespore_recovery_stance import (
    REQUEST_SCHEMA as STANCE_CONTROL_REQUEST_SCHEMA,
    STANCE_CONTROLLER_ID,
    plan_recovery_stance_control_v1,
)

from .recovery_capability import (
    ACTUATOR_PROFILE_ID,
    SEMANTICS_ID,
    TASK_ID,
    mujoco_recovery_capability_v1,
)


COLLECTOR_BINDING_SCHEMA = "sporespore_recovery_native_collector_binding_v1"
COLLECTION_REQUEST_SCHEMA = "sporespore_recovery_native_collection_request_v1"
COLLECTION_REQUEST_V2_SCHEMA = "sporespore_recovery_native_collection_request_v2"
COLLECTION_REQUEST_V3_SCHEMA = "sporespore_recovery_native_collection_request_v3"
CONTROL_REQUEST_SCHEMA = "sporespore_recovery_control_request_v1"
CONTROL_REQUEST_V2_SCHEMA = "sporespore_recovery_control_request_v2"
CONTROL_REQUEST_V3_SCHEMA = "sporespore_recovery_control_request_v3"
DEVELOPMENT_PROFILE_SCHEMA = "sporespore_recovery_development_profile_v1"
CONTROLLER_ID = "sporespore_exact_s169_prone_to_standing_controller_v1"
COLLECTOR_ID = "sporespore_mujoco_recovery_collector_v1"
RUNTIME_PROFILE_ID = "mujoco_3_11_native_recovery_v1"
NATIVE_SUBSTEPS_PER_OUTER_STEP = 5


class RecoveryRuntimeError(RuntimeError):
    """Stable fail-closed error for malformed local recovery requests."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise RecoveryRuntimeError(code)


def _digest(value: object, code: str) -> str:
    _require(isinstance(value, str), code)
    assert isinstance(value, str)
    _require(
        len(value) == 71
        and value.startswith("sha256:")
        and all(character in "0123456789abcdef" for character in value[7:]),
        code,
    )
    return value


def recovery_development_profile_v1(core: Any) -> dict[str, Any]:
    """Return and locally bound-check the prospective recovery profile."""

    profile = core.recovery_development_profile_v1()
    _require(
        profile.get("schema_version") == DEVELOPMENT_PROFILE_SCHEMA, "PROFILE_SCHEMA"
    )
    _require(profile.get("physical_execution_authorized") is False, "PROFILE_EXECUTION")
    _require(
        profile.get("physical_acceptance_authority") is False, "PROFILE_ACCEPTANCE"
    )
    _require(profile.get("release_authority") is False, "PROFILE_RELEASE")
    return profile


def runtime_binding_v1(
    capability_sha256: str,
    runtime_qualification_sha256: str,
) -> dict[str, Any]:
    """Bind the exact MuJoCo runtime and capability identities without physics."""

    return {
        "schema_version": COLLECTOR_BINDING_SCHEMA,
        "collector_id": COLLECTOR_ID,
        "runtime_profile_id": RUNTIME_PROFILE_ID,
        "runtime_qualification_sha256": _digest(
            runtime_qualification_sha256,
            "RUNTIME_QUALIFICATION_DIGEST",
        ),
        "capability_sha256": _digest(capability_sha256, "CAPABILITY_DIGEST"),
        "exact_runtime_identity_qualified": True,
        "native_post_step_only": True,
        "source_measurement_only": True,
        "missing_value_synthesis_permitted": False,
        "engine_identity_exposed_to_controller": False,
    }


def collection_request_v1(
    *,
    descriptor: Mapping[str, Any],
    observation: Mapping[str, Any],
    capability_sha256: str,
    runtime_qualification_sha256: str,
    arm_kind: str,
    phase: str,
) -> dict[str, Any]:
    """Assemble a strict request from one complete native post-step snapshot."""

    observation_copy = deepcopy(dict(observation))
    step_identity = observation_copy.get("engine_step_identity")
    _require(isinstance(step_identity, dict), "ENGINE_STEP_IDENTITY")
    assert isinstance(step_identity, dict)
    _require(step_identity.get("engine") == "mujoco_native", "ENGINE_IDENTITY_ENGINE")
    _require(
        step_identity.get("source_kind") == "native_post_step",
        "ENGINE_IDENTITY_SOURCE",
    )
    _require(
        step_identity.get("native_solver_substep_count")
        == NATIVE_SUBSTEPS_PER_OUTER_STEP,
        "ENGINE_IDENTITY_SUBSTEPS",
    )
    return {
        "schema_version": COLLECTION_REQUEST_SCHEMA,
        "task_id": TASK_ID,
        "semantics_id": SEMANTICS_ID,
        "actuator_profile_id": ACTUATOR_PROFILE_ID,
        "descriptor": deepcopy(dict(descriptor)),
        "adapter_capability": mujoco_recovery_capability_v1(),
        "runtime_binding": runtime_binding_v1(
            capability_sha256,
            runtime_qualification_sha256,
        ),
        "arm_kind": arm_kind,
        "phase": phase,
        "observation": observation_copy,
    }


def collection_request_v2(
    *,
    descriptor: Mapping[str, Any],
    morphology_context: Mapping[str, Any],
    observation: Mapping[str, Any],
    capability_sha256: str,
    runtime_qualification_sha256: str,
    arm_kind: str,
    phase: str,
) -> dict[str, Any]:
    """Assemble the strict recovery-morphology-aware native request."""

    request = collection_request_v1(
        descriptor=descriptor,
        observation=observation,
        capability_sha256=capability_sha256,
        runtime_qualification_sha256=runtime_qualification_sha256,
        arm_kind=arm_kind,
        phase=phase,
    )
    request["schema_version"] = COLLECTION_REQUEST_V2_SCHEMA
    request["morphology_context"] = deepcopy(dict(morphology_context))
    return request


def collection_request_v3(
    *,
    descriptor: Mapping[str, Any],
    morphology_context: Mapping[str, Any],
    observation_source_binding: Mapping[str, Any],
    observation: Mapping[str, Any],
    capability_sha256: str,
    runtime_qualification_sha256: str,
    arm_kind: str,
    phase: str,
) -> dict[str, Any]:
    """Assemble the source-bound request for a true observation V2."""

    request = collection_request_v2(
        descriptor=descriptor,
        morphology_context=morphology_context,
        observation=observation,
        capability_sha256=capability_sha256,
        runtime_qualification_sha256=runtime_qualification_sha256,
        arm_kind=arm_kind,
        phase=phase,
    )
    request["schema_version"] = COLLECTION_REQUEST_V3_SCHEMA
    request["observation_source_binding"] = deepcopy(dict(observation_source_binding))
    return request


def collect_native_v1(core: Any, request: Mapping[str, Any]) -> dict[str, Any]:
    """Validate one complete supplied MuJoCo post-step observation through Rust."""

    _require(
        request.get("schema_version") == COLLECTION_REQUEST_SCHEMA, "REQUEST_SCHEMA"
    )
    return core.recovery_collect_native_v1(deepcopy(dict(request)))


def collect_native_v2(core: Any, request: Mapping[str, Any]) -> dict[str, Any]:
    """Validate one recovery-morphology-aware MuJoCo observation through Rust."""

    _require(
        request.get("schema_version") == COLLECTION_REQUEST_V2_SCHEMA, "REQUEST_SCHEMA"
    )
    return core.recovery_collect_native_v2(deepcopy(dict(request)))


def collect_native_v3(core: Any, request: Mapping[str, Any]) -> dict[str, Any]:
    """Validate one source-bound MuJoCo observation-V2 publication."""

    _require(
        request.get("schema_version") == COLLECTION_REQUEST_V3_SCHEMA, "REQUEST_SCHEMA"
    )
    return core.recovery_collect_native_v3(deepcopy(dict(request)))


def plan_control_v1(
    core: Any,
    collection_request: Mapping[str, Any],
    phase_step: int,
) -> dict[str, Any]:
    """Plan one deterministic command; this function never applies it to MuJoCo."""

    _require(
        collection_request.get("schema_version") == COLLECTION_REQUEST_SCHEMA,
        "REQUEST_SCHEMA",
    )
    _require(isinstance(phase_step, int) and phase_step >= 0, "PHASE_STEP")
    return core.recovery_plan_control_v1(
        {
            "schema_version": CONTROL_REQUEST_SCHEMA,
            "controller_id": CONTROLLER_ID,
            "phase_step": phase_step,
            "collection": deepcopy(dict(collection_request)),
        }
    )


def plan_control_v2(
    core: Any,
    collection_request: Mapping[str, Any],
    phase_step: int,
) -> dict[str, Any]:
    """Plan deterministic control from one V2 recovery collection request."""

    _require(
        collection_request.get("schema_version") == COLLECTION_REQUEST_V2_SCHEMA,
        "REQUEST_SCHEMA",
    )
    _require(isinstance(phase_step, int) and phase_step >= 0, "PHASE_STEP")
    return core.recovery_plan_control_v2(
        {
            "schema_version": CONTROL_REQUEST_V2_SCHEMA,
            "controller_id": CONTROLLER_ID,
            "phase_step": phase_step,
            "collection": deepcopy(dict(collection_request)),
        }
    )


def plan_control_v3(
    core: Any,
    collection_request: Mapping[str, Any],
    phase_step: int,
) -> dict[str, Any]:
    """Plan deterministic control from one observation-V2 request."""

    _require(
        collection_request.get("schema_version") == COLLECTION_REQUEST_V3_SCHEMA,
        "REQUEST_SCHEMA",
    )
    _require(isinstance(phase_step, int) and phase_step >= 0, "PHASE_STEP")
    return core.recovery_plan_control_v3(
        {
            "schema_version": CONTROL_REQUEST_V3_SCHEMA,
            "controller_id": CONTROLLER_ID,
            "phase_step": phase_step,
            "collection": deepcopy(dict(collection_request)),
        }
    )


def plan_stance_control_v1(
    core: Any,
    collection_request: Mapping[str, Any],
    handoff_or_stance_step: Mapping[str, Any],
) -> dict[str, Any]:
    """Plan exclusive stance ownership from one accepted recovery step."""

    _require(
        collection_request.get("schema_version") == COLLECTION_REQUEST_V3_SCHEMA,
        "REQUEST_SCHEMA",
    )
    receipt = plan_recovery_stance_control_v1(
        core,
        {
            "schema_version": STANCE_CONTROL_REQUEST_SCHEMA,
            "controller_id": STANCE_CONTROLLER_ID,
            "collection": deepcopy(dict(collection_request)),
            "handoff_or_stance_step": deepcopy(dict(handoff_or_stance_step)),
        },
    )
    _require(
        receipt.get("schema_version") == "sporespore_recovery_control_receipt_v1"
        and receipt.get("support_status") == "supported_exact"
        and receipt.get("controller_id") == STANCE_CONTROLLER_ID
        and receipt.get("owner") == "stance"
        and receipt.get("recovery_controller_active") is False
        and receipt.get("no_actuation_requested") is False,
        "STANCE_CONTROL_REFUSED",
    )
    return receipt


def zero_world_surface_receipt_v1(core: Any) -> dict[str, Any]:
    """Exercise profile transport only; no model, data, or solver is touched."""

    profile = recovery_development_profile_v1(core)
    return {
        "schema_version": "sporespore_mujoco_recovery_runtime_zero_world_surface_receipt_v1",
        "ok": True,
        "profile_id": profile["profile_id"],
        "collector_id": COLLECTOR_ID,
        "runtime_profile_id": RUNTIME_PROFILE_ID,
        "native_runtime_observation_collection_executed": False,
        "mujoco_import_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
