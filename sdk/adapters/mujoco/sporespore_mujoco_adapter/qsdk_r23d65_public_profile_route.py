"""R23D65 public-profile route into the production MuJoCo model XML.

The zero-world entry point resolves the published R23D61 actuator profile
through the real core, maps its eight outer-step impulse caps to MuJoCo force
ranges, and compiles the complete XML consumed by the prospective physical
worker.  It deliberately never constructs ``MjModel`` or ``MjData``.  The
physical worker calls :func:`compile_public_profile_model_route` and passes the
returned bytes directly to ``MjModel.from_xml_string`` after authorization.
"""

from __future__ import annotations

import argparse
from copy import deepcopy
from dataclasses import dataclass
import hashlib
import json
import math
from pathlib import Path
import sys
from typing import Any, Sequence
from xml.etree import ElementTree as ET


SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
SDK_PYTHON = SDK_ROOT / "python"
if str(SDK_PYTHON) not in sys.path:
    sys.path.insert(0, str(SDK_PYTHON))

from sporespore_locomotion import (  # noqa: E402
    LocomotionCore,
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
    r23d60_selected_s169_quadruped,
    reference_quadruped,
)

from .actuator_cap_profile import (  # noqa: E402
    CONTROLLER_DT_S,
    HOST_MAPPING_ID,
    ORDERED_ACTUATOR_IDS,
    ORDERED_CAPS_NMS,
    ORDERED_JOINT_IDS,
    PROFILE_ID,
    PROFILE_SHA256,
    VELOCITY_GAIN_NM_S_PER_RAD,
    ActuatorCapProfileMappingError,
    map_actuator_cap_profile,
)
from .selected_policy_development import (  # noqa: E402
    PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID,
    build_model_xml,
)


CAMPAIGN_ID = "QSDK-R23D65-RUNTIME-INTEGRATION-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION"
GATE_ID = "QSDK-R23D65"
ENGINE_ID = "mujoco"
ROUTE_SCHEMA = (
    "sporespore_qsdk_r23d65_mujoco_public_profile_" "production_route_zero_world_v1"
)
PHYSICAL_BINDING_SCHEMA = "sporespore_qsdk_r23d62_physical_actuator_cap_binding_v1"
MORPHOLOGY_ID = "qsdk_r05_generated_s169"
DESCRIPTOR_SHA256 = (
    "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0"
)
MORPHOLOGY_SPEC_SHA256 = (
    "sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e"
)
MODEL_ID = "sporespore_mujoco_bw19v_development"
MODEL_ROUTE_ID = "sporespore_r23d65_mujoco_public_profile_model_xml_route_v1"
CONFIGURATION_READBACK_TOLERANCE_NMS = 4.440892098500626e-16
CORE_LIBRARY = SDK_ROOT / "target" / "debug" / "sporespore_locomotion_core.dll"


class R23D65MujocoRouteError(RuntimeError):
    """Stable fail-closed error for the production public-profile route."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R23D65MujocoRouteError(code)


def _canonical_json_sha256(value: Any) -> str:
    raw = json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _raw_sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def _validate_compiled(compiled: dict[str, Any]) -> None:
    morphology = compiled.get("morphology")
    _require(
        isinstance(morphology, dict),
        "QSDK_R23D65_MJC_ROUTE_MORPHOLOGY_MISSING",
    )
    assert isinstance(morphology, dict)
    _require(
        compiled.get("schema_version") == "sporespore_compiled_bounded_quadruped_v1"
        and compiled.get("morphology_id") == MORPHOLOGY_ID
        and compiled.get("descriptor_sha256") == DESCRIPTOR_SHA256
        and compiled.get("world_build_count") == 0
        and compiled.get("physical_acceptance_authority") is False,
        "QSDK_R23D65_MJC_ROUTE_COMPILED_IDENTITY_INVALID",
    )
    _require(
        morphology.get("morphology_spec_sha256") == MORPHOLOGY_SPEC_SHA256
        and tuple(morphology.get("ordered_actuator_ids", [])) == ORDERED_ACTUATOR_IDS
        and tuple(morphology.get("ordered_joint_ids", [])) == ORDERED_JOINT_IDS
        and morphology.get("world_build_count") == 0
        and morphology.get("physical_acceptance_authority") is False,
        "QSDK_R23D65_MJC_ROUTE_COMPILED_MORPHOLOGY_INVALID",
    )
    specification = morphology.get("morphology_spec")
    _require(
        isinstance(specification, dict),
        "QSDK_R23D65_MJC_ROUTE_SPEC_MISSING",
    )
    assert isinstance(specification, dict)
    actuators = specification.get("actuators")
    _require(
        isinstance(actuators, list) and len(actuators) == len(ORDERED_ACTUATOR_IDS),
        "QSDK_R23D65_MJC_ROUTE_SPEC_ACTUATOR_CARDINALITY_INVALID",
    )
    for index, (actuator, actuator_id, joint_id) in enumerate(
        zip(actuators, ORDERED_ACTUATOR_IDS, ORDERED_JOINT_IDS, strict=True)
    ):
        _require(
            isinstance(actuator, dict)
            and actuator.get("actuator_id") == actuator_id
            and actuator.get("joint_id") == joint_id,
            f"QSDK_R23D65_MJC_ROUTE_SPEC_ACTUATOR_ORDER_INVALID:{index}",
        )


def _validate_mapping(mapping: dict[str, Any]) -> None:
    ordered = mapping.get("ordered_mappings")
    _require(
        mapping.get("schema_version")
        == "sporespore_mujoco_actuator_cap_profile_zero_world_mapping_v1"
        and mapping.get("ok") is True
        and mapping.get("host_mapping_id") == HOST_MAPPING_ID
        and mapping.get("profile_id") == PROFILE_ID
        and mapping.get("profile_sha256") == PROFILE_SHA256
        and mapping.get("validated_actuator_count") == len(ORDERED_ACTUATOR_IDS)
        and mapping.get("model_construction_count") == 0
        and mapping.get("data_construction_count") == 0
        and mapping.get("world_attempt_count") == 0
        and mapping.get("world_build_count") == 0
        and mapping.get("solver_step_count") == 0
        and mapping.get("physics_state_modified") is False
        and mapping.get("physical_acceptance_authority") is False
        and mapping.get("release_authority") is False
        and isinstance(ordered, list)
        and len(ordered) == len(ORDERED_ACTUATOR_IDS),
        "QSDK_R23D65_MJC_ROUTE_MAPPING_HEADER_INVALID",
    )
    assert isinstance(ordered, list)
    for index, (item, actuator_id, joint_id, cap) in enumerate(
        zip(
            ordered,
            ORDERED_ACTUATOR_IDS,
            ORDERED_JOINT_IDS,
            ORDERED_CAPS_NMS,
            strict=True,
        )
    ):
        force_range = (
            item.get("mujoco_symmetric_force_range_nm")
            if isinstance(item, dict)
            else None
        )
        _require(
            isinstance(item, dict)
            and item.get("actuator_id") == actuator_id
            and item.get("joint_id") == joint_id
            and item.get("portable_maximum_outer_step_impulse_nms") == cap
            and isinstance(force_range, list)
            and len(force_range) == 2
            and all(
                isinstance(value, (int, float))
                and not isinstance(value, bool)
                and math.isfinite(float(value))
                for value in force_range
            )
            and float(force_range[0]) == -float(force_range[1])
            and float(force_range[1]) > 0.0
            and abs(float(force_range[1]) * CONTROLLER_DT_S - cap)
            <= CONFIGURATION_READBACK_TOLERANCE_NMS
            and f'name="{actuator_id}"' in str(item.get("velocity_actuator_xml", ""))
            and f'joint="{joint_id}"' in str(item.get("velocity_actuator_xml", "")),
            f"QSDK_R23D65_MJC_ROUTE_MAPPING_ENTRY_INVALID:{index}",
        )


def bind_public_profile_model_xml(
    source_xml: str,
    mapping: dict[str, Any],
) -> str:
    """Bind the public actuator profile into an already-compiled model XML.

    Morphology compilation and validation remain the caller's responsibility.
    Keeping actuator binding as one shared production operation lets later
    versioned morphology receipts use the exact public force-profile route
    without pretending to be the immutable walking/turning morphology.
    """

    _validate_mapping(mapping)
    try:
        root = ET.fromstring(source_xml)
    except ET.ParseError as error:
        raise R23D65MujocoRouteError(
            "QSDK_R23D65_MJC_ROUTE_SCAFFOLD_XML_INVALID"
        ) from error
    _require(
        root.tag == "mujoco" and root.get("model") == MODEL_ID,
        "QSDK_R23D65_MJC_ROUTE_MODEL_ID_INVALID",
    )
    actuator_container = root.find("actuator")
    _require(
        actuator_container is not None,
        "QSDK_R23D65_MJC_ROUTE_ACTUATOR_CONTAINER_MISSING",
    )
    assert actuator_container is not None
    actuator_elements = list(actuator_container)
    _require(
        len(actuator_elements) == len(ORDERED_ACTUATOR_IDS),
        "QSDK_R23D65_MJC_ROUTE_XML_ACTUATOR_CARDINALITY_INVALID",
    )
    mapping_items = mapping["ordered_mappings"]
    for index, (element, mapping_item, actuator_id, joint_id) in enumerate(
        zip(
            actuator_elements,
            mapping_items,
            ORDERED_ACTUATOR_IDS,
            ORDERED_JOINT_IDS,
            strict=True,
        )
    ):
        _require(
            element.tag == "velocity"
            and element.get("name") == actuator_id
            and element.get("joint") == joint_id
            and element.get("gear") == "1 0 0 0 0 0"
            and element.get("ctrllimited") == "false"
            and element.get("forcelimited") == "true"
            and float(element.get("kv", "nan")) == VELOCITY_GAIN_NM_S_PER_RAD,
            f"QSDK_R23D65_MJC_ROUTE_SCAFFOLD_ACTUATOR_INVALID:{index}",
        )
        force_range = mapping_item["mujoco_symmetric_force_range_nm"]
        element.set(
            "forcerange",
            f"{float(force_range[0]):.17g} {float(force_range[1]):.17g}",
        )
    model_xml = ET.tostring(root, encoding="unicode")

    # Reparse the exact returned text.  This catches serialization drift and is
    # also the byte string later handed to MjModel by the physical worker.
    reparsed = ET.fromstring(model_xml)
    reparsed_actuators = list(reparsed.find("actuator") or [])
    _require(
        len(reparsed_actuators) == len(ORDERED_ACTUATOR_IDS),
        "QSDK_R23D65_MJC_ROUTE_SERIALIZED_CARDINALITY_INVALID",
    )
    for index, (element, actuator_id, joint_id, cap) in enumerate(
        zip(
            reparsed_actuators,
            ORDERED_ACTUATOR_IDS,
            ORDERED_JOINT_IDS,
            ORDERED_CAPS_NMS,
            strict=True,
        )
    ):
        values = str(element.get("forcerange", "")).split()
        _require(
            element.get("name") == actuator_id
            and element.get("joint") == joint_id
            and len(values) == 2
            and float(values[0]) == -float(values[1])
            and abs(float(values[1]) * CONTROLLER_DT_S - cap)
            <= CONFIGURATION_READBACK_TOLERANCE_NMS,
            f"QSDK_R23D65_MJC_ROUTE_SERIALIZED_BINDING_INVALID:{index}",
        )
    return model_xml


def _compile_full_model_xml(
    compiled: dict[str, Any],
    mapping: dict[str, Any],
    *,
    scaffold_xml: str | None = None,
) -> str:
    """Bind the public force plan into the production morphology XML."""

    _validate_compiled(compiled)
    source_xml = (
        build_model_xml(compiled, PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID)
        if scaffold_xml is None
        else scaffold_xml
    )
    return bind_public_profile_model_xml(source_xml, mapping)


@dataclass(frozen=True)
class PublicProfileModelRoute:
    """The exact zero-world inputs and XML later consumed by MjModel."""

    compiled: dict[str, Any]
    resolution_receipt: dict[str, Any]
    host_mapping_receipt: dict[str, Any]
    model_xml: str

    @property
    def model_xml_bytes(self) -> bytes:
        return self.model_xml.encode("utf-8")

    @property
    def model_xml_sha256(self) -> str:
        return _raw_sha256_bytes(self.model_xml_bytes)


def compile_public_profile_model_route(
    core: LocomotionCore,
    *,
    descriptor: dict[str, Any] | None = None,
    resolution_receipt: dict[str, Any] | None = None,
    host_mapping_receipt: dict[str, Any] | None = None,
    compiled: dict[str, Any] | None = None,
    scaffold_xml: str | None = None,
) -> PublicProfileModelRoute:
    """Compile the exact full model XML without constructing a native model."""

    exact_descriptor = (
        r23d60_selected_s169_quadruped() if descriptor is None else descriptor
    )
    exact_compiled = (
        core.compile_bounded_quadruped(exact_descriptor)
        if compiled is None
        else compiled
    )
    exact_resolution = (
        core.resolve_actuator_cap_profile_v1(
            R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            exact_descriptor,
        )
        if resolution_receipt is None
        else resolution_receipt
    )
    try:
        expected_mapping = map_actuator_cap_profile(exact_resolution)
    except ActuatorCapProfileMappingError as error:
        raise R23D65MujocoRouteError(str(error)) from error
    exact_mapping = (
        expected_mapping if host_mapping_receipt is None else host_mapping_receipt
    )
    _require(
        _canonical_json_sha256(exact_mapping)
        == _canonical_json_sha256(expected_mapping),
        "QSDK_R23D65_MJC_ROUTE_MAPPING_NOT_RESOLUTION_DERIVED",
    )
    model_xml = _compile_full_model_xml(
        exact_compiled,
        exact_mapping,
        scaffold_xml=scaffold_xml,
    )
    return PublicProfileModelRoute(
        compiled=exact_compiled,
        resolution_receipt=exact_resolution,
        host_mapping_receipt=exact_mapping,
        model_xml=model_xml,
    )


def physical_binding_receipt(
    model: Any, route: PublicProfileModelRoute
) -> dict[str, Any]:
    """Read the exact public caps from a constructed model before its first step."""

    ordered: list[dict[str, Any]] = []
    for index, (actuator_id, joint_id, cap) in enumerate(
        zip(ORDERED_ACTUATOR_IDS, ORDERED_JOINT_IDS, ORDERED_CAPS_NMS, strict=True)
    ):
        try:
            native_id = int(model.actuator(actuator_id).id)
            force_range = model.actuator_forcerange[native_id]
            negative = float(force_range[0])
            positive = float(force_range[1])
        except (AttributeError, IndexError, KeyError, TypeError, ValueError) as error:
            raise R23D65MujocoRouteError(
                f"QSDK_R23D65_MJC_PHYSICAL_BINDING_UNREADABLE:{index}"
            ) from error
        readback = positive * CONTROLLER_DT_S
        readback_error = abs(readback - cap)
        matches = (
            negative == -positive
            and positive > 0.0
            and readback_error <= CONFIGURATION_READBACK_TOLERANCE_NMS
        )
        _require(
            matches,
            f"QSDK_R23D65_MJC_PHYSICAL_BINDING_MISMATCH:{index}",
        )
        ordered.append(
            {
                "profile_actuator_id": actuator_id,
                "trace_actuator_id": actuator_id,
                "joint_id": joint_id,
                "declared_maximum_outer_step_impulse_nms": cap,
                "host_readback_outer_step_impulse_nms": readback,
                "readback_error_nms": readback_error,
                "readback_matches": matches,
            }
        )
    return {
        "schema_version": PHYSICAL_BINDING_SCHEMA,
        "ok": True,
        "failure_code": "",
        "engine_id": ENGINE_ID,
        "profile_id": PROFILE_ID,
        "profile_sha256": PROFILE_SHA256,
        "host_mapping_id": HOST_MAPPING_ID,
        "host_mapping_receipt_sha256": _canonical_json_sha256(
            route.host_mapping_receipt
        ),
        "completed_before_first_solver_step": True,
        "solver_step_count_at_binding": 0,
        "validated_actuator_count": len(ordered),
        "write_count": len(ordered),
        "readback_count": len(ordered),
        "all_readbacks_match": all(item["readback_matches"] for item in ordered),
        "ordered_bindings": ordered,
    }


def _mutation_candidates(
    route: PublicProfileModelRoute,
) -> list[tuple[str, dict[str, Any], dict[str, Any], str | None]]:
    compiled = route.compiled
    mapping = route.host_mapping_receipt
    scaffold = build_model_xml(compiled, PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID)
    candidates: list[tuple[str, dict[str, Any], dict[str, Any], str | None]] = []

    wrong_morphology = deepcopy(compiled)
    wrong_morphology["morphology_id"] += "_mutated"
    candidates.append(("compiled_morphology_id", wrong_morphology, mapping, None))

    wrong_descriptor = deepcopy(compiled)
    wrong_descriptor["descriptor_sha256"] = "sha256:" + "0" * 64
    candidates.append(("compiled_descriptor_sha256", wrong_descriptor, mapping, None))

    wrong_spec = deepcopy(compiled)
    wrong_spec["morphology"]["morphology_spec_sha256"] = "sha256:" + "0" * 64
    candidates.append(("compiled_morphology_spec_sha256", wrong_spec, mapping, None))

    inflated_world = deepcopy(compiled)
    inflated_world["world_build_count"] = 1
    candidates.append(("compiled_world_build_count", inflated_world, mapping, None))

    swapped_actuators = deepcopy(compiled)
    swapped_actuators["morphology"]["ordered_actuator_ids"][0:2] = reversed(
        swapped_actuators["morphology"]["ordered_actuator_ids"][0:2]
    )
    candidates.append(("compiled_actuator_order", swapped_actuators, mapping, None))

    swapped_joints = deepcopy(compiled)
    swapped_joints["morphology"]["ordered_joint_ids"][0:2] = reversed(
        swapped_joints["morphology"]["ordered_joint_ids"][0:2]
    )
    candidates.append(("compiled_joint_order", swapped_joints, mapping, None))

    wrong_mapping_schema = deepcopy(mapping)
    wrong_mapping_schema["schema_version"] += "_mutated"
    candidates.append(("mapping_schema", compiled, wrong_mapping_schema, None))

    wrong_host = deepcopy(mapping)
    wrong_host["host_mapping_id"] += "_mutated"
    candidates.append(("mapping_host_id", compiled, wrong_host, None))

    wrong_profile = deepcopy(mapping)
    wrong_profile["profile_sha256"] = "sha256:" + "0" * 64
    candidates.append(("mapping_profile_sha256", compiled, wrong_profile, None))

    swapped_mapping = deepcopy(mapping)
    swapped_mapping["ordered_mappings"][0:2] = reversed(
        swapped_mapping["ordered_mappings"][0:2]
    )
    candidates.append(("mapping_actuator_order", compiled, swapped_mapping, None))

    wrong_joint = deepcopy(mapping)
    wrong_joint["ordered_mappings"][0]["joint_id"] += "_mutated"
    candidates.append(("mapping_joint_id", compiled, wrong_joint, None))

    asymmetric_force = deepcopy(mapping)
    asymmetric_force["ordered_mappings"][0]["mujoco_symmetric_force_range_nm"][0] = 0.0
    candidates.append(("mapping_force_symmetry", compiled, asymmetric_force, None))

    wrong_force = deepcopy(mapping)
    wrong_force["ordered_mappings"][0]["mujoco_symmetric_force_range_nm"] = [-1.0, 1.0]
    candidates.append(("mapping_force_value", compiled, wrong_force, None))

    wrong_fragment = deepcopy(mapping)
    wrong_fragment["ordered_mappings"][0]["velocity_actuator_xml"] = "<velocity/>"
    candidates.append(("mapping_xml_fragment", compiled, wrong_fragment, None))

    wrong_count = deepcopy(mapping)
    wrong_count["validated_actuator_count"] = 7
    candidates.append(("mapping_validated_count", compiled, wrong_count, None))

    root = ET.fromstring(scaffold)
    container = root.find("actuator")
    assert container is not None
    list(container)[0].set("kv", "9")
    candidates.append(
        (
            "scaffold_velocity_gain",
            compiled,
            mapping,
            ET.tostring(root, encoding="unicode"),
        )
    )

    root = ET.fromstring(scaffold)
    container = root.find("actuator")
    assert container is not None
    container.remove(list(container)[-1])
    candidates.append(
        (
            "scaffold_actuator_count",
            compiled,
            mapping,
            ET.tostring(root, encoding="unicode"),
        )
    )
    return candidates


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    """Exercise the exact route, route mutations, and support refusals."""

    route = compile_public_profile_model_route(core)
    mutation_results: list[dict[str, Any]] = []
    for mutation_id, compiled, mapping, scaffold in _mutation_candidates(route):
        try:
            # This calls the same compiler used by the physical route while
            # bypassing only the already-proved resolution-to-mapping equality
            # so each host-route mutation reaches its intended predicate.
            _compile_full_model_xml(
                compiled,
                mapping,
                scaffold_xml=scaffold,
            )
        except R23D65MujocoRouteError:
            rejected = True
        else:
            rejected = False
        _require(
            rejected,
            f"QSDK_R23D65_MJC_ROUTE_MUTATION_ACCEPTED:{mutation_id}",
        )
        mutation_results.append({"mutation_id": mutation_id, "rejected": rejected})

    out_of_domain = core.resolve_actuator_cap_profile_v1(
        R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        reference_quadruped("valid_out_of_domain"),
    )
    unsupported = core.resolve_actuator_cap_profile_v1(
        "unknown_profile",
        r23d60_selected_s169_quadruped(),
    )
    support_results: list[dict[str, Any]] = []
    for control_id, receipt in (
        ("valid_out_of_domain_morphology", out_of_domain),
        ("unsupported_profile", unsupported),
    ):
        try:
            map_actuator_cap_profile(receipt)
        except ActuatorCapProfileMappingError:
            refused = True
        else:
            refused = False
        _require(
            refused,
            f"QSDK_R23D65_MJC_ROUTE_SUPPORT_CONTROL_ACCEPTED:{control_id}",
        )
        support_results.append({"control_id": control_id, "refused": refused})

    return {
        "schema_version": ROUTE_SCHEMA,
        "ok": True,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "engine_id": ENGINE_ID,
        "profile_id": PROFILE_ID,
        "profile_sha256": PROFILE_SHA256,
        "host_mapping_id": HOST_MAPPING_ID,
        "model_route_id": MODEL_ROUTE_ID,
        "model_xml_sha256": route.model_xml_sha256,
        "model_xml_byte_length": len(route.model_xml_bytes),
        "model_xml_actuator_count": len(ORDERED_ACTUATOR_IDS),
        "validated_actuator_count": len(ORDERED_ACTUATOR_IDS),
        "full_model_xml_compiled_before_first_mjmodel": True,
        "same_full_model_xml_consumed_by_physical_constructor": True,
        "historical_constructor_behavior_changed": False,
        "mutation_rejection_count": len(mutation_results),
        "mutation_results": mutation_results,
        "support_controls": {
            "control_count": len(support_results),
            "valid_out_of_domain_morphology_refused": support_results[0]["refused"],
            "unsupported_profile_refused": support_results[1]["refused"],
            "results": support_results,
        },
        "ordered_production_force_bindings": deepcopy(
            route.host_mapping_receipt["ordered_mappings"]
        ),
        "actuator_cap_profile_resolution_receipt": deepcopy(route.resolution_receipt),
        "actuator_cap_profile_host_mapping_receipt": deepcopy(
            route.host_mapping_receipt
        ),
        "mujoco_import_count": 1,
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_execution_authorized": False,
        "turning_claimed": False,
        "finite_three_engine_turning_claimed": False,
        "q_sdk_r23_satisfied": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _arguments(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("preflight",))
    parser.add_argument("--core-library", type=Path, default=CORE_LIBRARY)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(argv)
    try:
        core = LocomotionCore(arguments.core_library.resolve())
        value = run_zero_world_preflight(core)
    except (
        OSError,
        KeyError,
        TypeError,
        ValueError,
        ActuatorCapProfileMappingError,
        R23D65MujocoRouteError,
    ) as error:
        print(
            "QSDK_R23D65_MUJOCO_PUBLIC_PROFILE_ROUTE_FAILURE "
            f"{type(error).__name__}:{error}",
            file=sys.stderr,
        )
        return 1
    print(
        "QSDK_R23D65_MUJOCO_PUBLIC_PROFILE_ROUTE "
        + json.dumps(
            value,
            allow_nan=False,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
