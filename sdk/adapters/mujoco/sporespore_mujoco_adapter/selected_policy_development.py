"""Development-only MuJoCo bridge for the unchanged BW19V selected policy.

This module deliberately exposes no locomotion authority. It builds a real
MuJoCo quadruped, obtains controller and stability commands from the compiled
Rust core through the public Python ABI, and applies the exact VH4 velocity
servo identity. Its probes exist to discover and remove integration defects
before a separately frozen, one-shot selected-policy campaign is designed.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable
from xml.etree import ElementTree as ET

import mujoco
import numpy as np

_SDK_ROOT = Path(__file__).resolve().parents[3]
_SDK_PYTHON = _SDK_ROOT / "python"
if str(_SDK_PYTHON) not in sys.path:
    sys.path.insert(0, str(_SDK_PYTHON))

from sporespore_locomotion import LocomotionCore

from .conformance import capability_manifest_sha256
from .velocity_only_stability_characterization_vh4 import (
    INTERNAL_DT_S,
    INTERNAL_STEPS_PER_OUTER,
    MAXIMUM_FORCE_NM,
    PROFILE_ID as VH4_PROFILE_ID,
    VELOCITY_GAIN,
)


ADAPTER_ID = "sporespore_mujoco_adapter"
SELECTED_POLICY_ID = "sporespore_balanced_wave_bw15f_b_v1"
SELECTED_CANDIDATE_ID = "BW19V-B"
STABILITY_POLICY_ID = "sporespore_scheduled_load_transfer_bw13p_a_v3"
GLOBAL_REQUESTED_CORRECTION_SCALE = 0.5
CHARACTERIZED_CONTROLLER_FRICTION = 0.94
AUTHORED_FRICTION = 0.95
CYCLE_STEPS = 360
SWING_STEPS = 72
FEASIBILITY_TOLERANCE = 1.0e-5
MAXIMUM_ABSOLUTE_POSITION_DELTA_RAD = 0.0
MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S = 0.075
MAXIMUM_POSITION_SLEW_PER_STEP_RAD = 0.0
MAXIMUM_VELOCITY_SLEW_PER_STEP_RAD_S = 0.010
NO_QUALIFIED_SUPPORT_CONTACT_REASON = "NO_QUALIFIED_SUPPORT_CONTACT"
CONTROLLER_DT_S = INTERNAL_DT_S * INTERNAL_STEPS_PER_OUTER
JOINT_ARMATURE = 0.01
LC1_TOTAL_STEPS = 2_992
LC1_CLOCKED_STEPS = 472
LC1_EVIDENCE_GAIT_STEPS = 1_440
PER_ACTUATOR_DEVELOPMENT_PROFILE_ID = (
    "mujoco_per_actuator_force_limited_five_substep_development_v1"
)
PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID = (
    "mujoco_s169_per_actuator_force_limited_five_substep_vh5_validated_v1"
)


def _profile_is_characterized(profile_id: str) -> bool:
    return profile_id in {VH4_PROFILE_ID, PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID}

_CANONICAL_TO_MUJOCO = np.asarray(
    [[1.0, 0.0, 0.0], [0.0, 0.0, -1.0], [0.0, 1.0, 0.0]],
    dtype=np.float64,
)


def s169_descriptor() -> dict[str, Any]:
    """Return the exact finite s169 descriptor used by the Rapier track."""

    return {
        "schema_version": "sporespore_bounded_quadruped_descriptor_v1",
        "morphology_id": "qsdk_r05_generated_s169",
        "torso_length_scale": 1.0041015625,
        "torso_width_scale": 1.0031893004115227,
        "upper_length_fraction": 0.5219571428571428,
        "hip_span_scale": 0.9856413994169096,
        "foot_radius_scale": 0.9987180691209617,
        "front_limb_mass_scale": 0.975022758306782,
    }


def _canonical_to_mujoco(vector: dict[str, Any] | Iterable[float]) -> np.ndarray:
    if isinstance(vector, dict):
        canonical = np.asarray(
            [vector["x"], vector["y"], vector["z"]], dtype=np.float64
        )
    else:
        canonical = np.asarray(list(vector), dtype=np.float64)
    return _CANONICAL_TO_MUJOCO @ canonical


def _mujoco_to_canonical(vector: Iterable[float]) -> np.ndarray:
    return _CANONICAL_TO_MUJOCO.T @ np.asarray(list(vector), dtype=np.float64)


def _vec_json(vector: Iterable[float]) -> dict[str, float]:
    values = list(float(value) for value in vector)
    return {"x": values[0], "y": values[1], "z": values[2]}


def _xml_vector(vector: Iterable[float]) -> str:
    return " ".join(f"{float(value):.17g}" for value in vector)


def _canonical_rotation(model_xmat: Iterable[float]) -> np.ndarray:
    mujoco_rotation = np.asarray(list(model_xmat), dtype=np.float64).reshape(3, 3)
    return _CANONICAL_TO_MUJOCO.T @ mujoco_rotation @ _CANONICAL_TO_MUJOCO


def _quaternion_xyzw(rotation: np.ndarray) -> dict[str, float]:
    trace = float(np.trace(rotation))
    if trace > 0.0:
        scale = math.sqrt(trace + 1.0) * 2.0
        w = 0.25 * scale
        x = (rotation[2, 1] - rotation[1, 2]) / scale
        y = (rotation[0, 2] - rotation[2, 0]) / scale
        z = (rotation[1, 0] - rotation[0, 1]) / scale
    else:
        diagonal = np.diag(rotation)
        index = int(np.argmax(diagonal))
        if index == 0:
            scale = math.sqrt(1.0 + rotation[0, 0] - rotation[1, 1] - rotation[2, 2]) * 2.0
            w = (rotation[2, 1] - rotation[1, 2]) / scale
            x = 0.25 * scale
            y = (rotation[0, 1] + rotation[1, 0]) / scale
            z = (rotation[0, 2] + rotation[2, 0]) / scale
        elif index == 1:
            scale = math.sqrt(1.0 + rotation[1, 1] - rotation[0, 0] - rotation[2, 2]) * 2.0
            w = (rotation[0, 2] - rotation[2, 0]) / scale
            x = (rotation[0, 1] + rotation[1, 0]) / scale
            y = 0.25 * scale
            z = (rotation[1, 2] + rotation[2, 1]) / scale
        else:
            scale = math.sqrt(1.0 + rotation[2, 2] - rotation[0, 0] - rotation[1, 1]) * 2.0
            w = (rotation[1, 0] - rotation[0, 1]) / scale
            x = (rotation[0, 2] + rotation[2, 0]) / scale
            y = (rotation[1, 2] + rotation[2, 1]) / scale
            z = 0.25 * scale
    quaternion = np.asarray([x, y, z, w], dtype=np.float64)
    norm = float(np.linalg.norm(quaternion))
    if not math.isfinite(norm) or norm <= np.finfo(np.float64).eps:
        raise RuntimeError("C6_MJC_SP_DEV_QUATERNION_NONFINITE_OR_ZERO")
    quaternion /= norm
    return {
        "x": float(quaternion[0]),
        "y": float(quaternion[1]),
        "z": float(quaternion[2]),
        "w": float(quaternion[3]),
    }


def _add_inertial(body_element: ET.Element, body: dict[str, Any]) -> None:
    inertia = body["inertia_diagonal_kg_m2"]
    mujoco_inertia = [inertia["x"], inertia["z"], inertia["y"]]
    ET.SubElement(
        body_element,
        "inertial",
        {
            "pos": _xml_vector(_canonical_to_mujoco(body["center_of_mass_local_m"])),
            "mass": f"{float(body['mass_kg']):.17g}",
            "diaginertia": _xml_vector(mujoco_inertia),
        },
    )


def _add_geom(body_element: ET.Element, body: dict[str, Any]) -> None:
    collision = body["collision"]
    common = {
        "name": f"{body['body_id']}_geom",
        "contype": "2",
        "conaffinity": "1",
        "friction": f"{AUTHORED_FRICTION:.17g} .005 .0001",
        "solref": ".02 1",
        "solimp": ".9 .95 .001",
    }
    kind = collision["kind"]
    if kind == "box":
        size = collision["size_m"]
        common.update(
            {
                "type": "box",
                "size": _xml_vector(
                    [size["x"] / 2.0, size["z"] / 2.0, size["y"] / 2.0]
                ),
            }
        )
    elif kind == "capsule":
        half_length = float(collision["length_m"]) / 2.0
        common.update(
            {
                "type": "capsule",
                "size": f"{float(collision['radius_m']):.17g}",
                "fromto": _xml_vector([0.0, 0.0, -half_length, 0.0, 0.0, half_length]),
            }
        )
    elif kind == "sphere":
        common.update(
            {
                "type": "sphere",
                "size": f"{float(collision['radius_m']):.17g}",
            }
        )
    else:
        raise RuntimeError(f"C6_MJC_SP_DEV_COLLISION_UNSUPPORTED:{kind}")
    ET.SubElement(body_element, "geom", common)


def _native_force_limit_nm(actuator: dict[str, Any], profile_id: str) -> float:
    if profile_id == VH4_PROFILE_ID:
        return MAXIMUM_FORCE_NM
    if profile_id in {
        PER_ACTUATOR_DEVELOPMENT_PROFILE_ID,
        PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID,
    }:
        return float(actuator["maximum_impulse_nms"]) / CONTROLLER_DT_S
    raise RuntimeError(f"C6_MJC_SP_DEV_HOST_PROFILE_UNKNOWN:{profile_id}")


def build_model_xml(compiled: dict[str, Any], profile_id: str) -> str:
    """Compile the portable morphology into a real MuJoCo tree."""

    morphology = compiled["morphology"]
    spec = morphology["morphology_spec"]
    bodies = {body["body_id"]: body for body in spec["bodies"]}
    joints_by_child = {joint["child_body_id"]: joint for joint in spec["joints"]}
    children: dict[str, list[str]] = {body_id: [] for body_id in bodies}
    for body in spec["bodies"]:
        parent = body["parent_body_id"]
        if parent is not None:
            children[parent].append(body["body_id"])

    root = ET.Element("mujoco", {"model": "sporespore_mujoco_bw19v_development"})
    ET.SubElement(
        root,
        "compiler",
        {"angle": "radian", "inertiafromgeom": "false", "autolimits": "false"},
    )
    ET.SubElement(
        root,
        "option",
        {
            "timestep": f"{INTERNAL_DT_S:.17g}",
            "gravity": "0 0 -9.8",
            "integrator": "implicitfast",
            "solver": "Newton",
            "iterations": "20",
            "ls_iterations": "7",
            "cone": "elliptic",
        },
    )
    worldbody = ET.SubElement(root, "worldbody")
    ET.SubElement(
        worldbody,
        "geom",
        {
            "name": "ground",
            "type": "plane",
            "size": "10 10 .1",
            "contype": "1",
            "conaffinity": "2",
            "friction": f"{AUTHORED_FRICTION:.17g} .005 .0001",
            "solref": ".02 1",
            "solimp": ".9 .95 .001",
        },
    )

    actuator_for_joint = {
        actuator["joint_id"]: actuator for actuator in spec["actuators"]
    }

    def add_body(parent_element: ET.Element, body_id: str) -> None:
        body = bodies[body_id]
        attributes = {"name": body_id}
        if body_id == "torso":
            attributes["pos"] = _xml_vector(
                _canonical_to_mujoco(
                    [0.0, compiled["geometry"]["initial_torso_center_y_m"], 0.0]
                )
            )
        else:
            joint = joints_by_child[body_id]
            relative = np.asarray(
                [joint["anchor_parent_m"][axis] for axis in ("x", "y", "z")],
                dtype=np.float64,
            ) - np.asarray(
                [joint["anchor_child_m"][axis] for axis in ("x", "y", "z")],
                dtype=np.float64,
            )
            attributes["pos"] = _xml_vector(_canonical_to_mujoco(relative))
        element = ET.SubElement(parent_element, "body", attributes)
        if body_id == "torso":
            ET.SubElement(element, "freejoint", {"name": "torso_free"})
        else:
            joint = joints_by_child[body_id]
            ET.SubElement(
                element,
                "joint",
                {
                    "name": joint["joint_id"],
                    "type": "hinge",
                    "pos": _xml_vector(_canonical_to_mujoco(joint["anchor_child_m"])),
                    "axis": _xml_vector(_canonical_to_mujoco(joint["axis_parent_unit"])),
                    "limited": "true",
                    "range": (
                        f"{float(joint['lower_limit_rad']):.17g} "
                        f"{float(joint['upper_limit_rad']):.17g}"
                    ),
                    "damping": "0",
                    "armature": f"{JOINT_ARMATURE:.17g}",
                },
            )
        _add_inertial(element, body)
        _add_geom(element, body)
        for child_id in children[body_id]:
            add_body(element, child_id)

    add_body(worldbody, "torso")
    actuators = ET.SubElement(root, "actuator")
    for actuator_id in morphology["ordered_actuator_ids"]:
        actuator = next(
            item for item in spec["actuators"] if item["actuator_id"] == actuator_id
        )
        force_limit = _native_force_limit_nm(actuator, profile_id)
        ET.SubElement(
            actuators,
            "velocity",
            {
                "name": actuator_id,
                "joint": actuator["joint_id"],
                "gear": "1 0 0 0 0 0",
                "ctrllimited": "false",
                "kv": f"{VELOCITY_GAIN:.17g}",
                "forcelimited": "true",
                "forcerange": f"{-force_limit:.17g} {force_limit:.17g}",
            },
        )
    return ET.tostring(root, encoding="unicode")


@dataclass
class CompositionMemory:
    previous_semantic_step: int | None = None
    ordered_previous_applied_corrections: list[dict[str, Any]] | None = None


class MujocoBw19vRobot:
    """One real s169 MuJoCo world with exact semantic order receipts."""

    def __init__(
        self,
        core: LocomotionCore,
        profile_id: str = PER_ACTUATOR_DEVELOPMENT_PROFILE_ID,
    ) -> None:
        self.core = core
        self.profile_id = profile_id
        self.descriptor = s169_descriptor()
        self.compiled = core.compile_bounded_quadruped(self.descriptor)
        self.morphology = self.compiled["morphology"]
        self.spec = self.morphology["morphology_spec"]
        self.model_xml = build_model_xml(self.compiled, profile_id)
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

    def _validate_model_identity(self) -> None:
        if self.model.nu != 8 or self.model.njnt != 9 or self.model.nbody != 10:
            raise RuntimeError("C6_MJC_SP_DEV_MODEL_CARDINALITY_MISMATCH")
        if not math.isclose(float(self.model.opt.timestep), INTERNAL_DT_S):
            raise RuntimeError("C6_MJC_SP_DEV_INTERNAL_TIMESTEP_MISMATCH")
        if int(self.model.opt.integrator) != int(mujoco.mjtIntegrator.mjINT_IMPLICITFAST):
            raise RuntimeError("C6_MJC_SP_DEV_INTEGRATOR_MISMATCH")
        for actuator_id in self.morphology["ordered_actuator_ids"]:
            actuator = self.actuator_ids[actuator_id]
            expected_force = _native_force_limit_nm(
                self.actuator_specs[actuator_id], self.profile_id
            )
            force_range = np.asarray(self.model.actuator_forcerange[actuator], dtype=float)
            if (
                float(self.model.actuator_gainprm[actuator, 0]) != VELOCITY_GAIN
                or float(self.model.actuator_biasprm[actuator, 2]) != -VELOCITY_GAIN
                or not bool(self.model.actuator_forcelimited[actuator])
                or not np.array_equal(
                    force_range, [-expected_force, expected_force]
                )
            ):
                raise RuntimeError(
                    f"C6_MJC_SP_DEV_ACTUATOR_PROFILE_MISMATCH:{actuator_id}"
                )

    def prepare(self) -> None:
        mujoco.mj_step1(self.model, self.data)

    def _body_pose_twist(self, body_id: str) -> tuple[dict[str, Any], dict[str, Any]]:
        body = self.model.body(body_id).id
        position = _mujoco_to_canonical(self.data.xpos[body])
        rotation = _canonical_rotation(self.data.xmat[body])
        spatial = np.zeros(6, dtype=np.float64)
        mujoco.mj_objectVelocity(
            self.model,
            self.data,
            mujoco.mjtObj.mjOBJ_BODY,
            body,
            spatial,
            0,
        )
        angular = _mujoco_to_canonical(spatial[:3])
        linear = _mujoco_to_canonical(spatial[3:])
        return (
            {
                "position_m": _vec_json(position),
                "orientation_xyzw": _quaternion_xyzw(rotation),
            },
            {
                "linear_velocity_m_s": _vec_json(linear),
                "angular_velocity_rad_s": _vec_json(angular),
            },
        )

    def _site_world(self, site: dict[str, Any]) -> np.ndarray:
        body = self.model.body(site["body_id"]).id
        local = _canonical_to_mujoco(site["local_center_m"])
        rotation = np.asarray(self.data.xmat[body], dtype=np.float64).reshape(3, 3)
        return np.asarray(self.data.xpos[body], dtype=np.float64) + rotation @ local

    def _contact(self, site: dict[str, Any]) -> dict[str, Any]:
        body_geom = self.body_geom_ids[site["body_id"]]
        matches: list[int] = []
        for index in range(int(self.data.ncon)):
            contact = self.data.contact[index]
            if {int(contact.geom1), int(contact.geom2)} == {
                self.ground_geom_id,
                body_geom,
            }:
                matches.append(index)
        if not matches:
            return {
                "present": False,
                "point_canonical": None,
                "normal_canonical": None,
                "engine_contact_ids": [],
            }
        chosen = min(matches, key=lambda index: float(self.data.contact[index].dist))
        contact = self.data.contact[chosen]
        point = _mujoco_to_canonical(contact.pos)
        normal = _mujoco_to_canonical(
            np.asarray(contact.frame, dtype=np.float64).reshape(3, 3)[0]
        )
        if normal[1] < 0.0:
            normal *= -1.0
        norm = float(np.linalg.norm(normal))
        if not math.isfinite(norm) or norm <= np.finfo(np.float64).eps:
            raise RuntimeError("C6_MJC_SP_DEV_CONTACT_NORMAL_INVALID")
        normal /= norm
        return {
            "present": True,
            "point_canonical": point,
            "normal_canonical": normal,
            "engine_contact_ids": [f"mujoco_contact_{index}" for index in matches],
        }

    def state_frame(self, semantic_step: int, task_origin: np.ndarray) -> dict[str, Any]:
        torso_pose, torso_twist = self._body_pose_twist("torso")
        joint_observations = []
        for joint_id in self.morphology["ordered_joint_ids"]:
            joint = self.joint_ids[joint_id]
            qpos = int(self.model.jnt_qposadr[joint])
            dof = int(self.model.jnt_dofadr[joint])
            joint_observations.append(
                {
                    "joint_id": joint_id,
                    "position_rad": float(self.data.qpos[qpos]),
                    "velocity_rad_s": float(self.data.qvel[dof]),
                    "anchor_error_m": 0.0,
                    "validity": {
                        "position": True,
                        "velocity": True,
                        "anchor_error": True,
                    },
                }
            )
        contact_observations = []
        for site_id in self.morphology["ordered_contact_site_ids"]:
            site = self.contact_sites[site_id]
            contact = self._contact(site)
            present = bool(contact["present"])
            contact_observations.append(
                {
                    "contact_site_id": site_id,
                    "presence": present,
                    "bears_support": present and bool(site["can_support"]),
                    "normal_load_n": None,
                    "provenance": {
                        "adapter_id": ADAPTER_ID,
                        "engine_contact_ids": contact["engine_contact_ids"],
                        "aggregation_rule_id": (
                            "mujoco_distal_geom_ground_contact_presence_v1"
                        ),
                        "quality": "qualified_bearing",
                    },
                }
            )
        return {
            "schema_version": "sporespore_state_frame_v1",
            "semantic_step": semantic_step,
            "sample_time_s": semantic_step * CONTROLLER_DT_S,
            "base_pose_world": torso_pose,
            "base_twist_world": torso_twist,
            "ordered_joint_observations": joint_observations,
            "ordered_contact_observations": contact_observations,
            "previous_applied_actuation": None,
            "gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
            "task_frame": {
                "origin_world_m": _vec_json(task_origin),
                "forward_axis_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
                "lateral_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
                "up_axis_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
                "reference_yaw_rad": 0.0,
            },
            "adapter_capability_sha256": capability_manifest_sha256(),
        }

    def stability_state(self, semantic_step: int) -> dict[str, Any]:
        body_states = []
        for body_id in self.morphology["ordered_body_ids"]:
            pose, twist = self._body_pose_twist(body_id)
            body_states.append(
                {"body_id": body_id, "pose_world": pose, "twist_world": twist}
            )
        contacts = []
        for site_id in self.morphology["ordered_contact_site_ids"]:
            site = self.contact_sites[site_id]
            contact = self._contact(site)
            if contact["present"]:
                body = self.model.body(site["body_id"]).id
                spatial = np.zeros(6, dtype=np.float64)
                mujoco.mj_objectVelocity(
                    self.model,
                    self.data,
                    mujoco.mjtObj.mjOBJ_BODY,
                    body,
                    spatial,
                    0,
                )
                point_mujoco = _CANONICAL_TO_MUJOCO @ contact["point_canonical"]
                radius = point_mujoco - np.asarray(self.data.xpos[body], dtype=float)
                point_velocity = spatial[3:] + np.cross(spatial[:3], radius)
                contacts.append(
                    {
                        "contact_site_id": site_id,
                        "presence": True,
                        "bears_support": bool(site["can_support"]),
                        "point_world_m": _vec_json(contact["point_canonical"]),
                        "normal_world_unit": _vec_json(contact["normal_canonical"]),
                        "surface_relative_velocity_world_m_s": _vec_json(
                            _mujoco_to_canonical(point_velocity)
                        ),
                        "material_id": "mujoco_bw19v_mu095",
                        "adapter_id": ADAPTER_ID,
                        "engine_contact_ids": contact["engine_contact_ids"],
                    }
                )
            else:
                contacts.append(
                    {
                        "contact_site_id": site_id,
                        "presence": False,
                        "bears_support": False,
                        "point_world_m": None,
                        "normal_world_unit": None,
                        "surface_relative_velocity_world_m_s": None,
                        "material_id": "mujoco_bw19v_mu095",
                        "adapter_id": ADAPTER_ID,
                        "engine_contact_ids": [],
                    }
                )
        return {
            "schema_version": "sporespore_stability_state_v2",
            "semantic_step": semantic_step,
            "ordered_body_states": body_states,
            "ordered_support_contacts": contacts,
            "gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
            "support_plane_forward_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
            "adapter_capability_sha256": capability_manifest_sha256(),
        }

    def endpoint_kinematics(
        self, stability_state: dict[str, Any]
    ) -> list[dict[str, Any]]:
        contact_points = {
            contact["contact_site_id"]: contact["point_world_m"]
            for contact in stability_state["ordered_support_contacts"]
            if contact["point_world_m"] is not None
        }
        ordered = []
        for actuator_id in self.morphology["ordered_actuator_ids"]:
            actuator = self.actuator_specs[actuator_id]
            joint_spec = next(
                joint for joint in self.spec["joints"] if joint["joint_id"] == actuator["joint_id"]
            )
            limb = next(
                limb
                for limb in self.spec["limbs"]
                if joint_spec["joint_id"] in limb["ordered_joint_ids"]
            )
            site_id = limb["ordered_contact_site_ids"][0]
            joint = self.joint_ids[joint_spec["joint_id"]]
            anchor = _mujoco_to_canonical(self.data.xanchor[joint])
            axis = _mujoco_to_canonical(self.data.xaxis[joint])
            axis /= np.linalg.norm(axis)
            endpoint = contact_points.get(site_id)
            if endpoint is None:
                endpoint = _vec_json(
                    _mujoco_to_canonical(self._site_world(self.contact_sites[site_id]))
                )
            ordered.append(
                {
                    "actuator_id": actuator_id,
                    "contact_site_id": site_id,
                    "joint_anchor_world_m": _vec_json(anchor),
                    "joint_axis_world_unit": _vec_json(axis),
                    "endpoint_world_m": endpoint,
                }
            )
        return ordered

    def apply_host_mapping(self, mapping: dict[str, Any]) -> dict[str, Any]:
        if (
            mapping["host_profile_id"] != self.profile_id
            or mapping["engine_id"] != "mujoco"
            or mapping["independent_native_position_feedback_applied"]
            or mapping["native_position_stiffness"] != 0.0
            or mapping["host_response_characterized_for_this_profile"]
            != _profile_is_characterized(self.profile_id)
        ):
            raise RuntimeError("C6_MJC_SP_DEV_HOST_MAPPING_CONTRACT_MISMATCH")
        targets = np.empty(8, dtype=np.float64)
        portable_limits = np.empty(8, dtype=np.float64)
        for index, command in enumerate(mapping["ordered_commands"]):
            expected = self.morphology["ordered_actuator_ids"][index]
            if command["actuator_id"] != expected or command["native_target_position_rad"] is not None:
                raise RuntimeError("C6_MJC_SP_DEV_HOST_COMMAND_ORDER_OR_POSITION_MISMATCH")
            targets[index] = float(command["host_target_velocity_rad_s"])
            portable_limits[index] = float(
                self.actuator_specs[expected]["maximum_impulse_nms"]
            )
        cumulative_absolute_force_time = np.zeros(8, dtype=np.float64)
        maximum_force = np.zeros(8, dtype=np.float64)
        for substep in range(INTERNAL_STEPS_PER_OUTER):
            if substep > 0:
                mujoco.mj_step1(self.model, self.data)
            self.data.ctrl[:] = targets
            if not np.array_equal(np.asarray(self.data.ctrl), targets):
                raise RuntimeError("C6_MJC_SP_DEV_CONTROL_READBACK_MISMATCH")
            mujoco.mj_step2(self.model, self.data)
            forces = np.abs(np.asarray(self.data.actuator_force, dtype=np.float64))
            cumulative_absolute_force_time += forces * INTERNAL_DT_S
            maximum_force = np.maximum(maximum_force, forces)
        return {
            "targets": targets.tolist(),
            "cumulative_absolute_force_time_nms": cumulative_absolute_force_time.tolist(),
            "portable_maximum_outer_impulse_nms": portable_limits.tolist(),
            "portable_impulse_violation_count": int(
                np.count_nonzero(cumulative_absolute_force_time > portable_limits + 1.0e-12)
            ),
            "maximum_absolute_actuator_force_nm": maximum_force.tolist(),
        }

    def torso_metrics(self) -> dict[str, float | bool]:
        torso = self.model.body("torso").id
        position = _mujoco_to_canonical(self.data.xpos[torso])
        rotation = _canonical_rotation(self.data.xmat[torso])
        up = rotation @ np.asarray([0.0, 1.0, 0.0])
        forward = rotation @ np.asarray([1.0, 0.0, 0.0])
        torso_site = {"body_id": "torso"}
        return {
            "x": float(position[0]),
            "y": float(position[1]),
            "z": float(position[2]),
            "tilt_rad": math.acos(float(np.clip(up[1], -1.0, 1.0))),
            "yaw_rad": math.atan2(float(forward[2]), float(forward[0])),
            "ground_contact": bool(self._contact(torso_site)["present"]),
        }


def _motion_command(semantic_step: int, phase_mode: str) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_motion_command_v2",
        "command_id": f"mujoco_development_step_{semantic_step}",
        "desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
        "desired_heading_rad": 0.0,
        "desired_yaw_rate_rad_s": None,
        "gait_family_id": "lateral_wave",
        "speed_class": "walk",
        "gait_amplitude": 1.0,
        "phase_progression_mode": phase_mode,
        "valid_from_step": semantic_step,
        "valid_through_step": semantic_step,
        "authority": "test_fixture",
    }


def _ordered_limb_steps(memory: dict[str, Any], ordered_ids: list[str]) -> list[dict[str, Any]]:
    by_id = {limb["limb_id"]: limb for limb in memory["ordered_limb_memory"]}
    return [
        {"limb_id": limb_id, "gait_step": int(by_id[limb_id]["gait_step"])}
        for limb_id in ordered_ids
    ]


def _mujoco_host_profile(profile_id: str) -> dict[str, Any]:
    if profile_id == VH4_PROFILE_ID:
        motor_model_id = "velocity_servo_force_limited_five_substep_v3"
        characterized = True
    elif profile_id == PER_ACTUATOR_DEVELOPMENT_PROFILE_ID:
        motor_model_id = (
            "velocity_servo_per_actuator_force_limited_five_substep_development_v1"
        )
        characterized = False
    elif profile_id == PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID:
        motor_model_id = (
            "velocity_servo_s169_per_actuator_force_limited_five_substep_"
            "vh5_validated_v1"
        )
        characterized = True
    else:
        raise RuntimeError(f"C6_MJC_SP_DEV_HOST_PROFILE_UNKNOWN:{profile_id}")
    return {
        "schema_version": "sporespore_velocity_only_host_profile_v1",
        "profile_id": profile_id,
        "adapter_id": ADAPTER_ID,
        "engine_id": "mujoco",
        "native_motor_model_id": motor_model_id,
        "canonical_to_host_velocity_sign": 1.0,
        "independent_native_position_feedback_applied": False,
        "native_position_stiffness": 0.0,
        "retained_host_behavior_equivalence_target": False,
        "host_response_characterized_for_this_profile": characterized,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def compose_bw19v_step(
    robot: MujocoBw19vRobot,
    base_actuation: dict[str, Any],
    stability_state: dict[str, Any],
    kinematics: list[dict[str, Any]],
    limb_steps: list[dict[str, Any]],
    memory: CompositionMemory,
) -> dict[str, Any]:
    """Compose BW19V using only versioned pure Rust-core ABI operations."""

    semantic_step = int(base_actuation["semantic_step"])
    available = any(
        contact["bears_support"] is True
        for contact in stability_state["ordered_support_contacts"]
    )
    gravity = stability_state["gravity_world_m_s2"]
    gravity_norm = math.sqrt(sum(float(gravity[axis]) ** 2 for axis in ("x", "y", "z")))
    plan = robot.core.plan_scheduled_load_transfer_v3(
        {
            "schema_version": "sporespore_plan_scheduled_load_transfer_request_v3",
            "descriptor": robot.descriptor,
            "request": {
                "schema_version": "sporespore_scheduled_load_transfer_request_v3",
                "policy_id": STABILITY_POLICY_ID,
                "semantic_step": semantic_step,
                "observation_available": available,
                "observation_unavailable_reason": (
                    None if available else NO_QUALIFIED_SUPPORT_CONTACT_REASON
                ),
                "gait_amplitude": 1.0,
                "cycle_steps": CYCLE_STEPS,
                "swing_steps": SWING_STEPS,
                "characterized_friction_coefficient": CHARACTERIZED_CONTROLLER_FRICTION,
                "maximum_normal_force_n": float(robot.morphology["total_mass_kg"])
                * gravity_norm,
                "feasibility_tolerance": FEASIBILITY_TOLERANCE,
                "ordered_limb_gait_steps": limb_steps,
                # Preserve the same v3 receipt path used by the Rapier BW19V
                # composition: an unavailable observation still carries the
                # emitted, explicitly unusable state instead of disappearing.
                "stability_state": stability_state,
            },
        }
    )
    planning_available = plan["planning_availability"] == "available"
    mapping = None
    if planning_available:
        mapping = robot.core.map_endpoint_force_to_joint_v3(
            {
                "schema_version": "sporespore_map_endpoint_force_to_joint_request_v3",
                "descriptor": robot.descriptor,
                "request": {
                    "schema_version": "sporespore_endpoint_force_joint_map_request_v3",
                    "semantic_step": semantic_step,
                    "centroidal_command": plan["centroidal_command"],
                    "ordered_actuator_kinematics": kinematics,
                },
            }
        )
    raw_torque: list[float | None] = []
    mapping_modes: list[str | None] = []
    requested = []
    if mapping is not None:
        commands = mapping["ordered_generalized_joint_torque_commands"]
        for expected, command in zip(
            robot.morphology["ordered_actuator_ids"], commands, strict=True
        ):
            if command["actuator_id"] != expected:
                raise RuntimeError("C6_MJC_SP_DEV_MAPPING_ORDER_MISMATCH")
            torque = float(command["generalized_torque_command_nm"])
            raw_torque.append(torque)
            mapping_modes.append(command["mapping_mode"])
            requested.append(
                {
                    "actuator_id": expected,
                    "requested_position_delta_rad": 0.0,
                    "requested_velocity_delta_rad_s": torque / VELOCITY_GAIN,
                }
            )
    else:
        for actuator_id in robot.morphology["ordered_actuator_ids"]:
            raw_torque.append(None)
            mapping_modes.append(None)
            requested.append(
                {
                    "actuator_id": actuator_id,
                    "requested_position_delta_rad": None,
                    "requested_velocity_delta_rad_s": None,
                }
            )
    previous = memory.ordered_previous_applied_corrections
    if previous is not None:
        previous = [dict(correction) for correction in previous]
        for correction, mode in zip(previous, mapping_modes, strict=True):
            if mode == "inactive_contact_zero":
                correction["applied_position_delta_rad"] = 0.0
                correction["applied_velocity_delta_rad_s"] = 0.0
    influence = robot.core.bound_stability_influence_v3(
        {
            "schema_version": "sporespore_bound_stability_influence_request_v3",
            "descriptor": robot.descriptor,
            "request": {
                "schema_version": "sporespore_stability_influence_request_v3",
                "semantic_step": semantic_step,
                "availability": plan["planning_availability"],
                "global_requested_correction_scale": GLOBAL_REQUESTED_CORRECTION_SCALE,
                "maximum_absolute_position_delta_rad": MAXIMUM_ABSOLUTE_POSITION_DELTA_RAD,
                "maximum_absolute_velocity_delta_rad_s": MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S,
                "maximum_position_delta_slew_per_step_rad": MAXIMUM_POSITION_SLEW_PER_STEP_RAD,
                "maximum_velocity_delta_slew_per_step_rad_s": (
                    MAXIMUM_VELOCITY_SLEW_PER_STEP_RAD_S
                ),
                "ordered_requested_corrections": requested,
                "previous_semantic_step": memory.previous_semantic_step,
                "ordered_previous_applied_corrections": previous,
            },
        }
    )
    memory.previous_semantic_step = semantic_step
    memory.ordered_previous_applied_corrections = [
        {
            "actuator_id": correction["actuator_id"],
            "applied_position_delta_rad": correction["applied_position_delta_rad"],
            "applied_velocity_delta_rad_s": correction[
                "applied_velocity_delta_rad_s"
            ],
        }
        for correction in influence["ordered_applied_corrections"]
    ]
    residuals = [
        {
            "schema_version": "sporespore_canonical_velocity_residual_v1",
            "actuator_id": correction["actuator_id"],
            "canonical_velocity_delta_rad_s": correction[
                "applied_velocity_delta_rad_s"
            ],
            "command_not_measurement": True,
            "physical_acceptance_authority": False,
        }
        for correction in influence["ordered_applied_corrections"]
    ]
    canonical = robot.core.canonical_velocity_compose_v1(
        {
            "schema_version": "sporespore_canonical_velocity_compose_request_v1",
            "descriptor": robot.descriptor,
            "source_actuation": base_actuation,
            "ordered_stability_residuals": residuals,
        }
    )
    host_mapping = robot.core.canonical_velocity_host_map_v1(
        {
            "schema_version": "sporespore_canonical_velocity_host_map_request_v1",
            "descriptor": robot.descriptor,
            "canonical_actuation": canonical,
            "host_profile": _mujoco_host_profile(robot.profile_id),
        }
    )
    return {
        "scheduled_load_transfer": plan,
        "endpoint_mapping": mapping,
        "stability_influence": influence,
        "raw_generalized_torque_commands_nm": raw_torque,
        "canonical_actuation": canonical,
        "host_mapping": host_mapping,
    }


def run_development_probe(
    *,
    outer_steps: int = 480,
    use_stability: bool = True,
    profile_id: str = PER_ACTUATOR_DEVELOPMENT_PROFILE_ID,
    schedule_id: str = "clocked",
) -> dict[str, Any]:
    """Run a disposable real-physics integration probe with no claim authority."""

    if outer_steps <= 0:
        raise ValueError("outer_steps must be positive")
    if schedule_id not in {"clocked", "lc1"}:
        raise ValueError("schedule_id must be 'clocked' or 'lc1'")
    core = LocomotionCore()
    robot = MujocoBw19vRobot(core, profile_id)
    controller_memory = core.balanced_wave_initial_memory()
    composition_memory = CompositionMemory()
    robot.prepare()
    initial = robot.torso_metrics()
    task_origin = np.asarray([initial["x"], initial["y"], initial["z"]], dtype=float)
    maximum_tilt = float(initial["tilt_rad"])
    minimum_height = float(initial["y"])
    maximum_abs_lateral = abs(float(initial["z"]))
    maximum_abs_yaw = abs(float(initial["yaw_rad"]))
    controller_error_count = 0
    safe_no_actuation_count = 0
    portable_impulse_violation_count = 0
    nonfinite_count = 0
    torso_ground_contact_step_count = 0
    nonzero_stability_step_count = 0
    contact_cycles = {site_id: 0 for site_id in robot.morphology["ordered_contact_site_ids"]}
    previous_contacts = {
        site_id: bool(robot._contact(robot.contact_sites[site_id])["present"])
        for site_id in contact_cycles
    }
    maximum_outer_force_time = {
        actuator_id: 0.0 for actuator_id in robot.morphology["ordered_actuator_ids"]
    }
    evidence_start_x: float | None = None

    for semantic_step in range(outer_steps):
        if schedule_id == "lc1" and semantic_step == LC1_CLOCKED_STEPS:
            evidence_start_x = float(robot.torso_metrics()["x"])
            for limb in controller_memory["ordered_limb_memory"]:
                limb["evidence_gait_step_limit"] = (
                    int(limb["gait_step"]) + 1 + LC1_EVIDENCE_GAIT_STEPS
                )
        phase_mode = (
            "contact_gated"
            if schedule_id == "lc1" and semantic_step >= LC1_CLOCKED_STEPS
            else "clocked"
        )
        state = robot.state_frame(semantic_step, task_origin)
        stability_state = robot.stability_state(semantic_step)
        kinematics = robot.endpoint_kinematics(stability_state)
        limb_steps = _ordered_limb_steps(
            controller_memory, robot.morphology["ordered_limb_ids"]
        )
        output = core.balanced_wave_policy_step(
            SELECTED_POLICY_ID,
            {
                "descriptor": robot.descriptor,
                "memory": controller_memory,
                "state": state,
                "command": _motion_command(semantic_step, phase_mode),
            },
        )
        controller_memory = output["next_memory"]
        actuation = output["actuation"]
        controller_error_count += int(actuation["receipt"]["controller_error"] is not None)
        controller_error_count += len(actuation["failure_codes"])
        safe_no_actuation_count += int(bool(actuation["safe_no_actuation"]))
        if use_stability:
            composition = compose_bw19v_step(
                robot,
                actuation,
                stability_state,
                kinematics,
                limb_steps,
                composition_memory,
            )
            mapping = composition["host_mapping"]
            if any(
                correction["applied_velocity_delta_rad_s"] != 0.0
                for correction in composition["stability_influence"][
                    "ordered_applied_corrections"
                ]
            ):
                nonzero_stability_step_count += 1
        else:
            zero_residuals = [
                {
                    "schema_version": "sporespore_canonical_velocity_residual_v1",
                    "actuator_id": command["actuator_id"],
                    "canonical_velocity_delta_rad_s": 0.0,
                    "command_not_measurement": True,
                    "physical_acceptance_authority": False,
                }
                for command in actuation["ordered_commands"]
            ]
            canonical = core.canonical_velocity_compose_v1(
                {
                    "schema_version": "sporespore_canonical_velocity_compose_request_v1",
                    "descriptor": robot.descriptor,
                    "source_actuation": actuation,
                    "ordered_stability_residuals": zero_residuals,
                }
            )
            mapping = core.canonical_velocity_host_map_v1(
                {
                    "schema_version": "sporespore_canonical_velocity_host_map_request_v1",
                    "descriptor": robot.descriptor,
                    "canonical_actuation": canonical,
                    "host_profile": _mujoco_host_profile(robot.profile_id),
                }
            )
        application = robot.apply_host_mapping(mapping)
        portable_impulse_violation_count += application[
            "portable_impulse_violation_count"
        ]
        for actuator_id, force_time in zip(
            robot.morphology["ordered_actuator_ids"],
            application["cumulative_absolute_force_time_nms"],
            strict=True,
        ):
            maximum_outer_force_time[actuator_id] = max(
                maximum_outer_force_time[actuator_id], float(force_time)
            )
        robot.prepare()
        metrics = robot.torso_metrics()
        values = [float(value) for key, value in metrics.items() if key != "ground_contact"]
        nonfinite_count += int(not np.isfinite(values).all())
        maximum_tilt = max(maximum_tilt, float(metrics["tilt_rad"]))
        minimum_height = min(minimum_height, float(metrics["y"]))
        maximum_abs_lateral = max(maximum_abs_lateral, abs(float(metrics["z"])))
        maximum_abs_yaw = max(maximum_abs_yaw, abs(float(metrics["yaw_rad"])))
        torso_ground_contact_step_count += int(bool(metrics["ground_contact"]))
        for site_id in contact_cycles:
            present = bool(robot._contact(robot.contact_sites[site_id])["present"])
            if not previous_contacts[site_id] and present:
                contact_cycles[site_id] += 1
            previous_contacts[site_id] = present

    final = robot.torso_metrics()
    return {
        "schema_version": "sporespore_mujoco_selected_policy_development_probe_v1",
        "ok": (
            controller_error_count == 0
            and safe_no_actuation_count == 0
            and portable_impulse_violation_count == 0
            and nonfinite_count == 0
            and torso_ground_contact_step_count == 0
        ),
        "development_only": True,
        "selected_candidate_id": SELECTED_CANDIDATE_ID,
        "selected_policy_id": SELECTED_POLICY_ID,
        "stability_enabled": use_stability,
        "global_requested_correction_scale": (
            GLOBAL_REQUESTED_CORRECTION_SCALE if use_stability else 0.0
        ),
        "host_profile_id": robot.profile_id,
        "ordered_native_force_limits_nm": {
            actuator_id: _native_force_limit_nm(
                robot.actuator_specs[actuator_id], robot.profile_id
            )
            for actuator_id in robot.morphology["ordered_actuator_ids"]
        },
        "host_profile_exact_vh4_identity": robot.profile_id == VH4_PROFILE_ID,
        "host_response_characterized_for_this_profile": _profile_is_characterized(
            robot.profile_id
        ),
        "portable_force_budget_enforced_by_native_limit": (
            robot.profile_id
            in {
                PER_ACTUATOR_DEVELOPMENT_PROFILE_ID,
                PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID,
            }
        ),
        "portable_force_budget_checked_from_observed_force_time": True,
        "outer_steps": outer_steps,
        "internal_steps": outer_steps * INTERNAL_STEPS_PER_OUTER,
        "world_build_count": 1,
        "controller_error_count": controller_error_count,
        "safe_no_actuation_count": safe_no_actuation_count,
        "portable_impulse_violation_count": portable_impulse_violation_count,
        "nonfinite_observation_count": nonfinite_count,
        "torso_ground_contact_step_count": torso_ground_contact_step_count,
        "nonzero_stability_step_count": nonzero_stability_step_count,
        "contact_cycles": contact_cycles,
        "schedule": {
            "schedule_id": schedule_id,
            "clocked_steps": (
                min(outer_steps, LC1_CLOCKED_STEPS)
                if schedule_id == "lc1"
                else outer_steps
            ),
            "contact_gated_start_step": (
                LC1_CLOCKED_STEPS if schedule_id == "lc1" else None
            ),
            "evidence_gait_steps_per_limb": (
                LC1_EVIDENCE_GAIT_STEPS if schedule_id == "lc1" else None
            ),
        },
        "final_limb_memory": controller_memory["ordered_limb_memory"],
        "maximum_outer_absolute_force_time_nms": maximum_outer_force_time,
        "initial_torso": initial,
        "final_torso": final,
        "metrics": {
            "forward_displacement_m": float(final["x"]) - float(initial["x"]),
            "evidence_forward_displacement_m": (
                None
                if evidence_start_x is None
                else float(final["x"]) - evidence_start_x
            ),
            "lateral_displacement_m": float(final["z"]) - float(initial["z"]),
            "maximum_absolute_lateral_m": maximum_abs_lateral,
            "maximum_absolute_yaw_rad": maximum_abs_yaw,
            "maximum_tilt_rad": maximum_tilt,
            "minimum_torso_height_m": minimum_height,
        },
        "claim_boundary": {
            "walking": False,
            "locomotion_acceptance": False,
            "independent_validation": False,
            "cross_engine_c6": False,
            "physical_acceptance_authority": False,
        },
        "physical_acceptance_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run a development-only real-physics MuJoCo BW19V probe."
    )
    parser.add_argument("--steps", type=int, default=480)
    parser.add_argument(
        "--schedule",
        choices=("clocked", "lc1"),
        default="clocked",
    )
    parser.add_argument(
        "--base-only",
        action="store_true",
        help="Disable the BW19V scale-0.5 stability contribution.",
    )
    arguments = parser.parse_args()
    report = run_development_probe(
        outer_steps=arguments.steps,
        use_stability=not arguments.base_only,
        schedule_id=arguments.schedule,
    )
    print(json.dumps(report, allow_nan=False, indent=2, sort_keys=True))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
