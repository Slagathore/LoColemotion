"""XV2-only MuJoCo material bridge over the immutable MV6 implementation.

The historical ``selected_policy_development`` module is byte-bound by the
MV5/MV6 closures and must remain unchanged.  This successor module delegates
the complete morphology, actuator, controller, and stepping implementation to
that frozen bridge while replacing only the prospectively declared material
vector in the authored XML before MuJoCo constructs a model.
"""

from __future__ import annotations

import math
from typing import Any
from xml.etree import ElementTree as ET

import mujoco

from . import selected_policy_development as baseline


def validated_friction_vector(
    authored_friction_vector: tuple[float, float, float],
) -> tuple[float, float, float]:
    """Require one explicit finite, nonnegative MuJoCo friction triplet."""

    try:
        raw_vector = tuple(authored_friction_vector)
    except TypeError as error:
        raise ValueError(
            "authored_friction_vector must be an explicit three-value sequence"
        ) from error
    if len(raw_vector) != 3 or not all(
        not isinstance(value, bool)
        and isinstance(value, (int, float))
        and math.isfinite(float(value))
        and float(value) >= 0.0
        for value in raw_vector
    ):
        raise ValueError(
            "authored_friction_vector must contain three finite nonnegative values"
        )
    return tuple(float(value) for value in raw_vector)


def _xml_vector(values: tuple[float, float, float]) -> str:
    return " ".join(f"{value:.17g}" for value in values)


def build_model_xml(
    compiled: dict[str, Any],
    profile_id: str,
    authored_friction_vector: tuple[float, float, float],
) -> str:
    """Author XV2's exact material vector without changing the MV6 source."""

    vector = validated_friction_vector(authored_friction_vector)
    root = ET.fromstring(baseline.build_model_xml(compiled, profile_id))
    root.set("model", "sporespore_mujoco_bw19v_xv2")

    morphology = compiled["morphology"]
    expected_geom_names = {"ground"} | {
        f"{body_id}_geom" for body_id in morphology["ordered_body_ids"]
    }
    named_geoms = {
        str(geom.get("name")): geom
        for geom in root.findall(".//geom")
        if geom.get("name") is not None
    }
    if set(named_geoms) != expected_geom_names:
        raise RuntimeError("C6_XE_BW19V_XV2_MJC_GEOM_IDENTITY_MISMATCH")

    encoded_vector = _xml_vector(vector)
    for geom_name in sorted(expected_geom_names):
        named_geoms[geom_name].set("friction", encoded_vector)
    return ET.tostring(root, encoding="unicode")


class MujocoBw19vRobot(baseline.MujocoBw19vRobot):
    """One fresh XV2 world with an explicit, declared material profile."""

    def __init__(
        self,
        core: baseline.LocomotionCore,
        profile_id: str,
        authored_friction_vector: tuple[float, float, float],
    ) -> None:
        self.core = core
        self.profile_id = profile_id
        self.authored_friction_vector = validated_friction_vector(
            authored_friction_vector
        )
        self.descriptor = baseline.s169_descriptor()
        self.compiled = core.compile_bounded_quadruped(self.descriptor)
        self.morphology = self.compiled["morphology"]
        self.spec = self.morphology["morphology_spec"]
        self.model_xml = build_model_xml(
            self.compiled,
            profile_id,
            self.authored_friction_vector,
        )
        self.model = mujoco.MjModel.from_xml_string(self.model_xml)
        self.data = mujoco.MjData(self.model)
        mujoco.mj_forward(self.model, self.data)
        self.ground_geom_id = self.model.geom("ground").id
        self.body_geom_ids = {
            body_id: self.model.geom(f"{body_id}_geom").id
            for body_id in self.morphology["ordered_body_ids"]
        }
        self.joint_ids = {
            joint_id: self.model.joint(joint_id).id
            for joint_id in self.morphology["ordered_joint_ids"]
        }
        self.actuator_ids = {
            actuator_id: self.model.actuator(actuator_id).id
            for actuator_id in self.morphology["ordered_actuator_ids"]
        }
        self.actuator_specs = {
            actuator["actuator_id"]: actuator for actuator in self.spec["actuators"]
        }
        self.contact_sites = {
            site["contact_site_id"]: site for site in self.spec["contact_sites"]
        }
        self.limbs = {limb["limb_id"]: limb for limb in self.spec["limbs"]}
        self._validate_model_identity()
