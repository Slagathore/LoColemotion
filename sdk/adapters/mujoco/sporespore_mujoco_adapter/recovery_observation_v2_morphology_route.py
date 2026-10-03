"""Exact recovery-morphology route consumed by the observation-V2 world."""

from __future__ import annotations

from copy import deepcopy
import hashlib
from typing import Any

from sporespore_locomotion import LocomotionCore

from . import native_recovery_development as runtime
from . import recovery_morphology_route as morphology


CONJUNCTION_SCHEMA = (
    "sporespore_mujoco_recovery_morphology_observation_v2_conjunction_v1"
)
EXPECTED_COMPILED_SCHEMA = "sporespore_recovery_morphology_receipt_v1"
EXPECTED_MRO = (
    "MujocoRecoveryMorphologyObservationV2World",
    "MujocoRecoveryMorphologyWorld",
    "MujocoObservationV2RecoveryWorld",
    "MujocoSignedWorkPreprojectionRecoveryWorld",
    "MujocoSparseMomentImplicitStepRecoveryWorld",
    "MujocoImplicitStepRecoveryWorld",
    "MujocoNativeRecoveryWorld",
    "MujocoBw19vRobot",
    "object",
)


class RecoveryObservationV2MorphologyRouteError(RuntimeError):
    """Stable refusal from the exact route/world conjunction gate."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise RecoveryObservationV2MorphologyRouteError(code)


def _canonical_sha256(core: LocomotionCore, value: dict[str, Any]) -> str:
    digest = core.canonicalize_json(deepcopy(value)).get("sha256")
    _require(
        isinstance(digest, str) and len(digest) == 71 and digest.startswith("sha256:"),
        "QSDK_R24D41_CONJUNCTION_DIGEST_INVALID",
    )
    return str(digest)


class MujocoRecoveryMorphologyObservationV2World(
    morphology.MujocoRecoveryMorphologyWorld,
    runtime.MujocoObservationV2RecoveryWorld,
):
    """Recovery-morphology readback/initializer plus observation-V2 stepping."""

    route_id = runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID


def validate_recovery_observation_v2_morphology_conjunction_v1(
    core: LocomotionCore,
    model_route: runtime.PublicProfileModelRoute,
    world_type: type[runtime.MujocoNativeRecoveryWorld],
) -> dict[str, Any]:
    """Bind the exact compiled receipt and composite class without physics."""

    _require(
        isinstance(model_route, morphology.RecoveryMorphologyModelRoute),
        "QSDK_R24D41_RECOVERY_MORPHOLOGY_ROUTE_REQUIRED",
    )
    _require(
        model_route.compiled.get("schema_version") == EXPECTED_COMPILED_SCHEMA,
        "QSDK_R24D41_RECOVERY_MORPHOLOGY_SCHEMA_REQUIRED",
    )
    _require(
        world_type is MujocoRecoveryMorphologyObservationV2World,
        "QSDK_R24D41_COMPOSITE_WORLD_REQUIRED",
    )
    mro = tuple(item.__name__ for item in world_type.__mro__)
    _require(mro == EXPECTED_MRO, "QSDK_R24D41_COMPOSITE_MRO_INVALID")
    _require(
        world_type.__init__ is morphology.MujocoRecoveryMorphologyWorld.__init__
        and world_type._validate_model_identity
        is morphology.MujocoRecoveryMorphologyWorld._validate_model_identity
        and world_type.initialize_prone
        is morphology.MujocoRecoveryMorphologyWorld.initialize_prone
        and world_type.step_native
        is runtime.MujocoObservationV2RecoveryWorld.step_native,
        "QSDK_R24D41_COMPOSITE_METHOD_ROUTE_INVALID",
    )
    _require(
        world_type.route_id == runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID
        and world_type.publication_route_id == runtime.OBSERVATION_V2_CONSUMER_ROUTE_ID
        and world_type.initializer_id == morphology.INITIALIZER_ID
        and world_type.native_step_receipt_schema
        == runtime.SIGNED_WORK_PREPROJECTION_NATIVE_RECEIPT_SCHEMA
        and world_type.energy_work_preprojection_required is True
        and world_type.energy_work_preprojection_refusal_enabled is False
        and world_type.known_initial_overlap is False
        and world_type.reconstruct_torso_contact_surface is True,
        "QSDK_R24D41_COMPOSITE_IDENTITY_INVALID",
    )
    mapping = model_route.morphology_mapping_receipt
    _require(
        mapping.get("ok") is True
        and mapping.get("route_id") == morphology.ROUTE_ID
        and mapping.get("recovery_morphology_id")
        == morphology.EXPECTED_RECOVERY_MORPHOLOGY_ID
        and mapping.get("recovery_descriptor_sha256")
        == morphology.EXPECTED_RECOVERY_DESCRIPTOR_SHA256
        and mapping.get("recovery_morphology_spec_sha256")
        == morphology.EXPECTED_RECOVERY_MORPHOLOGY_SHA256
        and mapping.get("model_construction_count") == 0
        and mapping.get("world_attempt_count") == 0
        and mapping.get("world_build_count") == 0
        and mapping.get("solver_step_count") == 0
        and mapping.get("physics_state_modified") is False,
        "QSDK_R24D41_MORPHOLOGY_MAPPING_INVALID",
    )
    context = runtime._portable_morphology_context(model_route)
    _require(
        isinstance(context, dict)
        and context.get("schema_version") == runtime.RECOVERY_MORPHOLOGY_CONTEXT_SCHEMA
        and context.get("recovery_morphology_id")
        == morphology.EXPECTED_RECOVERY_MORPHOLOGY_ID
        and context.get("recovery_descriptor_sha256")
        == morphology.EXPECTED_RECOVERY_DESCRIPTOR_SHA256
        and context.get("recovery_morphology_spec_sha256")
        == morphology.EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
        "QSDK_R24D41_MORPHOLOGY_CONTEXT_INVALID",
    )

    model_xml_bytes = model_route.model_xml.encode("utf-8")
    receipt: dict[str, Any] = {
        "schema_version": CONJUNCTION_SCHEMA,
        "ok": True,
        "support_status": "supported_exact",
        "compiled_receipt_schema": EXPECTED_COMPILED_SCHEMA,
        "recovery_morphology_route_id": morphology.ROUTE_ID,
        "native_source_route_id": runtime.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
        "publication_route_id": runtime.OBSERVATION_V2_CONSUMER_ROUTE_ID,
        "initializer_id": morphology.INITIALIZER_ID,
        "world_type": (
            "sporespore_mujoco_adapter.recovery_observation_v2_morphology_route."
            "MujocoRecoveryMorphologyObservationV2World"
        ),
        "world_mro": list(mro),
        "recovery_morphology_id": morphology.EXPECTED_RECOVERY_MORPHOLOGY_ID,
        "recovery_descriptor_sha256": (morphology.EXPECTED_RECOVERY_DESCRIPTOR_SHA256),
        "recovery_morphology_spec_sha256": (
            morphology.EXPECTED_RECOVERY_MORPHOLOGY_SHA256
        ),
        "morphology_context_schema": runtime.RECOVERY_MORPHOLOGY_CONTEXT_SCHEMA,
        "model_xml_byte_length": len(model_xml_bytes),
        "model_xml_sha256": "sha256:" + hashlib.sha256(model_xml_bytes).hexdigest(),
        "morphology_mapping_receipt_sha256": _canonical_sha256(core, mapping),
        "compiled_receipt_sha256": _canonical_sha256(core, model_route.compiled),
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
    receipt["receipt_sha256"] = _canonical_sha256(core, receipt)
    return receipt
