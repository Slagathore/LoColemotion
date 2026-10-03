"""MuJoCo mapping for the exact R24D22 recovery-morphology receipt.

The zero-world half of this module compiles the public recovery descriptor,
maps its portable morphology into the existing production MuJoCo XML builder,
and verifies every changed anchor and range without constructing ``MjModel``.
The physical half subclasses the already-commissioned recovery world so the
same collector, controller, step, evaluator, and retention route receives the
new canonical prone initializer.
"""

from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass
import math
from typing import Any, Mapping, Sequence
import xml.etree.ElementTree as ET

import mujoco
import numpy as np

from sporespore_locomotion import (
    LocomotionCore,
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
    r24d22_recovery_s169_morphology,
)

from . import selected_policy_development as base
from .actuator_cap_profile import map_actuator_cap_profile
from .native_recovery_development import (
    MujocoNativeRecoveryWorld,
    _canonical_sha256,
    run_paired_development,
    run_zero_world_preflight as run_inherited_zero_world_preflight,
    validate_public_profile_model_identity_v3,
)
from .qsdk_r23d65_public_profile_route import (
    MODEL_ID,
    ORDERED_ACTUATOR_IDS,
    ORDERED_JOINT_IDS,
    PublicProfileModelRoute,
    bind_public_profile_model_xml,
)


ROUTE_ID = "sporespore_mujoco_qsdk_r24_recovery_morphology_development_v1"
INITIALIZER_ID = "sporespore_qsdk_r24_recovery_s169_canonical_prone_initializer_v1"
MAPPING_SCHEMA = "sporespore_mujoco_recovery_morphology_mapping_v1"
NATIVE_READBACK_SCHEMA = (
    "sporespore_mujoco_recovery_morphology_native_readback_v1"
)
EXPECTED_RECOVERY_MORPHOLOGY_ID = "qsdk_r24_recovery_s169_v1"
EXPECTED_RECOVERY_DESCRIPTOR_SHA256 = (
    "sha256:431a9c8001931e751bb2f1f2750c31650dd2d994575a736c53adbef1b27a71f6"
)
EXPECTED_BASE_DESCRIPTOR_SHA256 = (
    "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0"
)
EXPECTED_BASE_MORPHOLOGY_SHA256 = (
    "sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e"
)
EXPECTED_RECOVERY_MORPHOLOGY_SHA256 = (
    "sha256:926551af3a72eb1fd1f3b71bfb103587a0b906a116775551a2463792e2c160f9"
)
EXPECTED_MINIMUM_LIMB_CLEARANCE_M = 0.01625237411795359


class RecoveryMorphologyRouteError(RuntimeError):
    """Stable fail-closed error from the recovery-morphology mapping route."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise RecoveryMorphologyRouteError(code)


def _finite_vector(value: str | Sequence[float], code: str) -> tuple[float, ...]:
    try:
        values = (
            tuple(float(item) for item in value.split())
            if isinstance(value, str)
            else tuple(float(item) for item in value)
        )
    except (TypeError, ValueError) as error:
        raise RecoveryMorphologyRouteError(code) from error
    _require(bool(values) and all(math.isfinite(item) for item in values), code)
    return values


def _canonical_xyz(value: Mapping[str, Any]) -> np.ndarray:
    return np.asarray(
        [float(value[axis]) for axis in ("x", "y", "z")],
        dtype=np.float64,
    )


def _exact_tuple(left: Sequence[float], right: Sequence[float]) -> bool:
    return tuple(float(value) for value in left) == tuple(float(value) for value in right)


def _joint_pose_value(descriptor: Mapping[str, Any], joint_id: str) -> float:
    pose = descriptor["canonical_prone_pose"]
    front = joint_id.startswith("front_")
    hip = joint_id.endswith("_hip")
    key = f"{'front' if front else 'rear'}_{'hip' if hip else 'knee'}_angle_rad"
    return float(pose[key])


def validate_recovery_morphology_receipt(
    receipt: Mapping[str, Any],
) -> dict[str, Any]:
    """Validate the one finite public receipt accepted by R24D23."""

    descriptor = receipt.get("descriptor")
    morphology = receipt.get("morphology")
    prone = receipt.get("prone_geometry")
    claim = receipt.get("claim_boundary")
    _require(isinstance(descriptor, dict), "QSDK_R24D23_RECEIPT_DESCRIPTOR")
    _require(isinstance(morphology, dict), "QSDK_R24D23_RECEIPT_MORPHOLOGY")
    _require(isinstance(prone, dict), "QSDK_R24D23_RECEIPT_PRONE")
    _require(isinstance(claim, dict), "QSDK_R24D23_RECEIPT_CLAIM")
    assert isinstance(descriptor, dict)
    assert isinstance(morphology, dict)
    assert isinstance(prone, dict)
    assert isinstance(claim, dict)

    _require(
        receipt.get("schema_version")
        == "sporespore_recovery_morphology_receipt_v1"
        and receipt.get("recovery_morphology_id")
        == EXPECTED_RECOVERY_MORPHOLOGY_ID
        and receipt.get("support_status") == "supported_exact"
        and receipt.get("refusal_reason") is None
        and descriptor == r24d22_recovery_s169_morphology()
        and receipt.get("descriptor_sha256")
        == EXPECTED_RECOVERY_DESCRIPTOR_SHA256
        and receipt.get("base_descriptor_sha256")
        == EXPECTED_BASE_DESCRIPTOR_SHA256
        and receipt.get("base_morphology_spec_sha256")
        == EXPECTED_BASE_MORPHOLOGY_SHA256
        and receipt.get("recovery_morphology_spec_sha256")
        == EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
        "QSDK_R24D23_RECEIPT_IDENTITY",
    )
    _require(
        morphology.get("morphology_spec_sha256")
        == EXPECTED_RECOVERY_MORPHOLOGY_SHA256
        and tuple(morphology.get("ordered_joint_ids", [])) == ORDERED_JOINT_IDS
        and tuple(morphology.get("ordered_actuator_ids", []))
        == ORDERED_ACTUATOR_IDS,
        "QSDK_R24D23_RECEIPT_TOPOLOGY",
    )
    _require(
        prone.get("feasible") is True
        and prone.get("all_limbs_fold_outward_from_torso") is True
        and prone.get("all_declared_collisions_ground_nonpenetrating") is True
        and prone.get("minimum_limb_ground_clearance_m")
        == EXPECTED_MINIMUM_LIMB_CLEARANCE_M,
        "QSDK_R24D23_RECEIPT_GEOMETRY",
    )
    _require(
        claim.get("exact_prone_ground_geometry_supported") is True
        and claim.get("controller_compatibility_claimed") is False
        and claim.get("recovery_behavior_claimed") is False
        and claim.get("prone_to_standing_claimed") is False
        and receipt.get("model_construction_count") == 0
        and receipt.get("world_attempt_count") == 0
        and receipt.get("world_build_count") == 0
        and receipt.get("solver_step_count") == 0
        and receipt.get("physics_state_modified") is False
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False,
        "QSDK_R24D23_RECEIPT_AUTHORITY",
    )
    return dict(receipt)


def validate_zero_world_model_mapping(
    recovery_receipt: Mapping[str, Any],
    model_xml: str,
) -> dict[str, Any]:
    """Verify every recovery-changed joint field in the exact native XML."""

    validated = validate_recovery_morphology_receipt(recovery_receipt)
    morphology = validated["morphology"]
    specification = morphology["morphology_spec"]
    joints = {
        str(joint["joint_id"]): joint for joint in specification["joints"]
    }
    _require(
        tuple(joints) == ORDERED_JOINT_IDS,
        "QSDK_R24D23_MAPPING_JOINT_ORDER",
    )
    try:
        root = ET.fromstring(model_xml)
    except ET.ParseError as error:
        raise RecoveryMorphologyRouteError(
            "QSDK_R24D23_MAPPING_XML_INVALID"
        ) from error
    _require(
        root.tag == "mujoco" and root.get("model") == MODEL_ID,
        "QSDK_R24D23_MAPPING_MODEL_ID",
    )

    ordered: list[dict[str, Any]] = []
    for joint_id in ORDERED_JOINT_IDS:
        joint = joints[joint_id]
        child_body_id = str(joint["child_body_id"])
        body_element = root.find(f".//body[@name='{child_body_id}']")
        _require(
            body_element is not None,
            f"QSDK_R24D23_MAPPING_BODY_MISSING:{joint_id}",
        )
        assert body_element is not None
        joint_element = body_element.find(f"joint[@name='{joint_id}']")
        _require(
            joint_element is not None,
            f"QSDK_R24D23_MAPPING_JOINT_MISSING:{joint_id}",
        )
        assert joint_element is not None

        anchor_parent = _canonical_xyz(joint["anchor_parent_m"])
        anchor_child = _canonical_xyz(joint["anchor_child_m"])
        expected_body_position = base._canonical_to_mujoco(
            anchor_parent - anchor_child
        )
        expected_joint_position = base._canonical_to_mujoco(anchor_child)
        expected_axis = base._canonical_to_mujoco(
            _canonical_xyz(joint["axis_parent_unit"])
        )
        expected_range = (
            float(joint["lower_limit_rad"]),
            float(joint["upper_limit_rad"]),
        )
        body_position = _finite_vector(
            str(body_element.get("pos", "")),
            f"QSDK_R24D23_MAPPING_BODY_POSITION_INVALID:{joint_id}",
        )
        joint_position = _finite_vector(
            str(joint_element.get("pos", "")),
            f"QSDK_R24D23_MAPPING_JOINT_POSITION_INVALID:{joint_id}",
        )
        axis = _finite_vector(
            str(joint_element.get("axis", "")),
            f"QSDK_R24D23_MAPPING_AXIS_INVALID:{joint_id}",
        )
        native_range = _finite_vector(
            str(joint_element.get("range", "")),
            f"QSDK_R24D23_MAPPING_RANGE_INVALID:{joint_id}",
        )
        _require(
            len(body_position) == 3
            and _exact_tuple(body_position, expected_body_position),
            f"QSDK_R24D23_MAPPING_BODY_POSITION:{joint_id}",
        )
        _require(
            len(joint_position) == 3
            and _exact_tuple(joint_position, expected_joint_position),
            f"QSDK_R24D23_MAPPING_JOINT_POSITION:{joint_id}",
        )
        _require(
            len(axis) == 3 and _exact_tuple(axis, expected_axis),
            f"QSDK_R24D23_MAPPING_AXIS:{joint_id}",
        )
        _require(
            len(native_range) == 2
            and _exact_tuple(native_range, expected_range),
            f"QSDK_R24D23_MAPPING_RANGE:{joint_id}",
        )
        ordered.append(
            {
                "joint_id": joint_id,
                "child_body_id": child_body_id,
                "canonical_anchor_parent_m": deepcopy(joint["anchor_parent_m"]),
                "canonical_anchor_child_m": deepcopy(joint["anchor_child_m"]),
                "mujoco_body_position": list(body_position),
                "mujoco_joint_position": list(joint_position),
                "mujoco_axis": list(axis),
                "mujoco_range_rad": list(native_range),
                "canonical_prone_position_rad": _joint_pose_value(
                    validated["descriptor"], joint_id
                ),
            }
        )

    return {
        "schema_version": MAPPING_SCHEMA,
        "ok": True,
        "route_id": ROUTE_ID,
        "recovery_morphology_id": EXPECTED_RECOVERY_MORPHOLOGY_ID,
        "recovery_descriptor_sha256": EXPECTED_RECOVERY_DESCRIPTOR_SHA256,
        "base_descriptor_sha256": EXPECTED_BASE_DESCRIPTOR_SHA256,
        "base_morphology_spec_sha256": EXPECTED_BASE_MORPHOLOGY_SHA256,
        "recovery_morphology_spec_sha256": EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
        "minimum_limb_ground_clearance_m": EXPECTED_MINIMUM_LIMB_CLEARANCE_M,
        "ordered_joint_mapping_count": len(ordered),
        "ordered_joint_mappings": ordered,
        "canonical_initializer_id": INITIALIZER_ID,
        "engine_module_imported": True,
        "native_model_api_invoked": False,
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_question_opened": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


@dataclass(frozen=True)
class RecoveryMorphologyModelRoute(PublicProfileModelRoute):
    """Exact public inputs and XML later consumed by the physical constructor."""

    morphology_mapping_receipt: dict[str, Any]


def compile_recovery_morphology_model_route(
    core: LocomotionCore,
    *,
    descriptor: dict[str, Any] | None = None,
) -> RecoveryMorphologyModelRoute:
    """Compile the finite recovery receipt through the shared production XML path."""

    exact_descriptor = (
        r24d22_recovery_s169_morphology() if descriptor is None else descriptor
    )
    recovery_receipt = core.compile_recovery_morphology_v1(exact_descriptor)
    validate_recovery_morphology_receipt(recovery_receipt)
    base_descriptor = exact_descriptor["base_descriptor"]
    resolution = core.resolve_actuator_cap_profile_v1(
        R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        base_descriptor,
    )
    host_mapping = map_actuator_cap_profile(resolution)
    scaffold_xml = base.build_model_xml(
        recovery_receipt,
        base.PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID,
    )
    model_xml = bind_public_profile_model_xml(scaffold_xml, host_mapping)
    morphology_mapping = validate_zero_world_model_mapping(
        recovery_receipt,
        model_xml,
    )
    return RecoveryMorphologyModelRoute(
        compiled=recovery_receipt,
        resolution_receipt=resolution,
        host_mapping_receipt=host_mapping,
        model_xml=model_xml,
        morphology_mapping_receipt=morphology_mapping,
    )


def validate_native_recovery_morphology_readback(
    model: Any,
    route: RecoveryMorphologyModelRoute,
) -> dict[str, Any]:
    """Read back the recovery-changed fields from one constructed MuJoCo model."""

    mapping = route.morphology_mapping_receipt
    _require(mapping.get("ok") is True, "QSDK_R24D23_NATIVE_MAPPING_INVALID")
    ordered = mapping.get("ordered_joint_mappings")
    _require(isinstance(ordered, list), "QSDK_R24D23_NATIVE_MAPPING_ENTRIES")
    assert isinstance(ordered, list)
    readbacks: list[dict[str, Any]] = []
    for index, item in enumerate(ordered):
        _require(isinstance(item, dict), f"QSDK_R24D23_NATIVE_ITEM:{index}")
        assert isinstance(item, dict)
        joint_id = str(item["joint_id"])
        body_id = str(item["child_body_id"])
        try:
            native_joint_id = int(model.joint(joint_id).id)
            native_body_id = int(model.body(body_id).id)
            body_position = tuple(
                float(value) for value in model.body_pos[native_body_id]
            )
            joint_position = tuple(
                float(value) for value in model.jnt_pos[native_joint_id]
            )
            axis = tuple(float(value) for value in model.jnt_axis[native_joint_id])
            joint_range = tuple(
                float(value) for value in model.jnt_range[native_joint_id]
            )
        except (AttributeError, IndexError, KeyError, TypeError, ValueError) as error:
            raise RecoveryMorphologyRouteError(
                f"QSDK_R24D23_NATIVE_READBACK_UNAVAILABLE:{joint_id}"
            ) from error
        _require(
            _exact_tuple(body_position, item["mujoco_body_position"]),
            f"QSDK_R24D23_NATIVE_BODY_POSITION:{joint_id}",
        )
        _require(
            _exact_tuple(joint_position, item["mujoco_joint_position"]),
            f"QSDK_R24D23_NATIVE_JOINT_POSITION:{joint_id}",
        )
        _require(
            _exact_tuple(axis, item["mujoco_axis"]),
            f"QSDK_R24D23_NATIVE_AXIS:{joint_id}",
        )
        _require(
            _exact_tuple(joint_range, item["mujoco_range_rad"]),
            f"QSDK_R24D23_NATIVE_RANGE:{joint_id}",
        )
        readbacks.append(
            {
                "joint_id": joint_id,
                "child_body_id": body_id,
                "mujoco_body_position": list(body_position),
                "mujoco_joint_position": list(joint_position),
                "mujoco_axis": list(axis),
                "mujoco_range_rad": list(joint_range),
                "matches_zero_world_mapping": True,
            }
        )
    return {
        "schema_version": NATIVE_READBACK_SCHEMA,
        "ok": True,
        "route_id": ROUTE_ID,
        "recovery_morphology_id": EXPECTED_RECOVERY_MORPHOLOGY_ID,
        "recovery_morphology_spec_sha256": EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
        "ordered_joint_readback_count": len(readbacks),
        "ordered_joint_readbacks": readbacks,
        "completed_before_initializer": True,
        "completed_before_first_solver_step": True,
        "model_construction_count": 1,
        "data_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


class MujocoRecoveryMorphologyWorld(MujocoNativeRecoveryWorld):
    """Existing production recovery world with the R24D22 morphology receipt."""

    route_id = ROUTE_ID
    initializer_id = INITIALIZER_ID
    known_initial_overlap = False
    nonfoot_classification_rule_id = (
        "mujoco_contact_midpoint_normal_distance_reconstructed_torso_surface_v1"
    )
    reconstruct_torso_contact_surface = True

    def __init__(
        self,
        core: LocomotionCore,
        route: RecoveryMorphologyModelRoute,
        capability_sha256: str,
    ) -> None:
        self.recovery_model_route = route
        super().__init__(core, route, capability_sha256)

    def _validate_model_identity(self) -> None:
        self.model_identity = validate_public_profile_model_identity_v3(
            self.model,
            self.physical_binding,
            self.actuator_ids,
        )
        self.native_recovery_morphology_readback = (
            validate_native_recovery_morphology_readback(
                self.model,
                self.recovery_model_route,
            )
        )

    def _prone_joint_positions(self) -> list[float]:
        descriptor = self.compiled["descriptor"]
        return [
            _joint_pose_value(descriptor, joint_id) for joint_id in ORDERED_JOINT_IDS
        ]

    def _initializer_manifest_extension(self) -> dict[str, Any]:
        return {
            "recovery_morphology_id": EXPECTED_RECOVERY_MORPHOLOGY_ID,
            "recovery_descriptor_sha256": EXPECTED_RECOVERY_DESCRIPTOR_SHA256,
            "base_descriptor_sha256": EXPECTED_BASE_DESCRIPTOR_SHA256,
            "base_morphology_spec_sha256": EXPECTED_BASE_MORPHOLOGY_SHA256,
            "recovery_morphology_spec_sha256": EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
            "zero_world_minimum_limb_ground_clearance_m": (
                EXPECTED_MINIMUM_LIMB_CLEARANCE_M
            ),
            "canonical_pose_source": (
                "public_recovery_morphology_receipt_descriptor"
            ),
            "zero_world_geometry_supported": True,
        }

    def initialize_prone(self, **kwargs: Any):  # type: ignore[no-untyped-def]
        receipt = super().initialize_prone(**kwargs)
        expected = self._prone_joint_positions()
        actual = [float(value) for value in self._joint_positions()]
        _require(
            _exact_tuple(actual, expected),
            "QSDK_R24D23_INITIALIZER_NATIVE_JOINT_READBACK",
        )
        manifest = deepcopy(receipt.manifest)
        manifest["native_ordered_joint_position_readback_rad"] = actual
        manifest["native_joint_position_readback_matches"] = True
        return type(receipt)(
            manifest=manifest,
            manifest_sha256=_canonical_sha256(self.core, manifest),
            canonical_pre_step_state=receipt.canonical_pre_step_state,
            canonical_pre_step_state_sha256=receipt.canonical_pre_step_state_sha256,
        )


def run_recovery_morphology_route_ghost(
    core: LocomotionCore,
    *,
    cell: Mapping[str, Any],
    horizon_steps: int,
) -> dict[str, Any]:
    """Traverse the complete paired production route with no behavior authority."""

    route = compile_recovery_morphology_model_route(core)
    return run_paired_development(
        core,
        cell=cell,
        horizon_steps=horizon_steps,
        route=route,
        world_type=MujocoRecoveryMorphologyWorld,
        behavior_claim_authority=False,
    )


def _typed_refusal_control(core: LocomotionCore) -> dict[str, Any]:
    descriptor = r24d22_recovery_s169_morphology()
    descriptor["recovery_morphology_id"] = "qsdk_r24d23_legacy_geometry_refusal"
    descriptor["joint_authority"] = {
        "hip_anchor_parent_y_m": -0.05,
        "hip_limit_magnitude_rad": 0.72,
        "knee_limit_magnitude_rad": 1.10,
    }
    descriptor["canonical_prone_pose"] = {
        "front_hip_angle_rad": 0.72,
        "front_knee_angle_rad": 1.10,
        "rear_hip_angle_rad": -0.72,
        "rear_knee_angle_rad": -1.10,
    }
    receipt = core.compile_recovery_morphology_v1(descriptor)
    _require(
        receipt.get("support_status")
        == "unsupported_prone_geometry_infeasible"
        and receipt.get("model_construction_count") == 0
        and receipt.get("world_attempt_count") == 0
        and receipt.get("world_build_count") == 0
        and receipt.get("solver_step_count") == 0,
        "QSDK_R24D23_TYPED_REFUSAL_CONTROL",
    )
    return {
        "support_status": receipt["support_status"],
        "refusal_reason": receipt["refusal_reason"],
        "returned_before_model": True,
    }


def _expect_mapping_refusal(
    receipt: Mapping[str, Any],
    model_xml: str,
    expected_code: str,
) -> None:
    try:
        validate_zero_world_model_mapping(receipt, model_xml)
    except RecoveryMorphologyRouteError as error:
        _require(str(error) == expected_code, "QSDK_R24D23_NEGATIVE_WRONG_ERROR")
        return
    raise RecoveryMorphologyRouteError("QSDK_R24D23_NEGATIVE_ACCEPTED")


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    """Run the complete compact mapping gate without constructing a model."""

    inherited = run_inherited_zero_world_preflight(core)
    route = compile_recovery_morphology_model_route(core)
    refusal = _typed_refusal_control(core)

    range_root = ET.fromstring(route.model_xml)
    range_joint = range_root.find(".//joint[@name='front_left_hip']")
    _require(range_joint is not None, "QSDK_R24D23_RANGE_CONTROL_FIXTURE")
    assert range_joint is not None
    range_joint.set("range", "-1.6 1.5999999999999999")
    _expect_mapping_refusal(
        route.compiled,
        ET.tostring(range_root, encoding="unicode"),
        "QSDK_R24D23_MAPPING_RANGE:front_left_hip",
    )

    anchor_root = ET.fromstring(route.model_xml)
    anchor_body = anchor_root.find(".//body[@name='front_left_upper']")
    _require(anchor_body is not None, "QSDK_R24D23_ANCHOR_CONTROL_FIXTURE")
    assert anchor_body is not None
    anchor_values = list(_finite_vector(str(anchor_body.get("pos", "")), "ANCHOR"))
    anchor_values[2] = math.nextafter(anchor_values[2], math.inf)
    anchor_body.set("pos", " ".join(f"{value:.17g}" for value in anchor_values))
    _expect_mapping_refusal(
        route.compiled,
        ET.tostring(anchor_root, encoding="unicode"),
        "QSDK_R24D23_MAPPING_BODY_POSITION:front_left_hip",
    )

    identity_mutation = deepcopy(route.compiled)
    identity_mutation["recovery_morphology_spec_sha256"] = (
        EXPECTED_BASE_MORPHOLOGY_SHA256
    )
    _expect_mapping_refusal(
        identity_mutation,
        route.model_xml,
        "QSDK_R24D23_RECEIPT_IDENTITY",
    )

    mapping_sha256 = _canonical_sha256(core, route.morphology_mapping_receipt)
    return {
        "schema_version": (
            "sporespore_qsdk_r24d23_mujoco_recovery_morphology_zero_world_preflight_v1"
        ),
        "ok": True,
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": ["mujoco_native"],
            "authority_mode": "zero_world_qualification",
            "question_class": "development",
        },
        "route_id": ROUTE_ID,
        "engine": "mujoco_native",
        "engine_version": str(mujoco.__version__),
        "numpy_version": str(np.__version__),
        "recovery_morphology_id": EXPECTED_RECOVERY_MORPHOLOGY_ID,
        "recovery_descriptor_sha256": EXPECTED_RECOVERY_DESCRIPTOR_SHA256,
        "base_descriptor_sha256": EXPECTED_BASE_DESCRIPTOR_SHA256,
        "base_morphology_spec_sha256": EXPECTED_BASE_MORPHOLOGY_SHA256,
        "recovery_morphology_spec_sha256": EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
        "minimum_limb_ground_clearance_m": EXPECTED_MINIMUM_LIMB_CLEARANCE_M,
        "model_xml_sha256": route.model_xml_sha256,
        "model_xml_byte_length": len(route.model_xml_bytes),
        "morphology_mapping_sha256": mapping_sha256,
        "morphology_mapping": route.morphology_mapping_receipt,
        "negative_control_count": 4,
        "negative_controls_passed": 4,
        "typed_refusal_control": refusal,
        "mutated_range_refused": True,
        "mutated_anchor_refused": True,
        "mutated_recovery_identity_refused": True,
        "production_constructor_callable": inherited[
            "production_constructor_callable"
        ],
        "production_step_callable": inherited["production_step_callable"],
        "production_finalize_callable": inherited["production_finalize_callable"],
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "native_runtime_observation_collection_executed": False,
        "physical_question_opened": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
