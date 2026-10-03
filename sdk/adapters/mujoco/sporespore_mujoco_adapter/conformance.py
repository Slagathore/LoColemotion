"""Fail-closed MuJoCo C0-C5 conformance fixtures and evidence runner."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import sys
from pathlib import Path
from typing import Any, Sequence

import mujoco
import numpy as np

ADAPTER_ID = "sporespore_mujoco_adapter"
ADAPTER_MANIFEST_VERSION = "sporespore_mujoco_adapter_manifest_v1"
MUJOCO_DT_S = 1.0 / 120.0
SOLVER_ITERATIONS = 20
LINE_SEARCH_ITERATIONS = 7

_SDK_ROOT = Path(__file__).resolve().parents[3]
_SDK_PYTHON = _SDK_ROOT / "python"
if str(_SDK_PYTHON) not in sys.path:
    sys.path.insert(0, str(_SDK_PYTHON))

from sporespore_locomotion import LocomotionCore, reference_quadruped  # noqa: E402


class ConformanceFailure(RuntimeError):
    """A typed, stable failure emitted by one conformance cell."""


def _require(condition: bool, failure_code: str, detail: str = "") -> None:
    if not condition:
        suffix = f": {detail}" if detail else ""
        raise ConformanceFailure(f"{failure_code}{suffix}")


def _finite(values: Sequence[float] | np.ndarray[Any, Any]) -> bool:
    return bool(np.isfinite(np.asarray(values, dtype=np.float64)).all())


def _canonical_to_mujoco(vector: Sequence[float]) -> np.ndarray[Any, Any]:
    """Map canonical X-forward/Y-up/Z-right to MuJoCo X-forward/Z-up."""

    x, y, z = (float(component) for component in vector)
    return np.asarray([x, -z, y], dtype=np.float64)


def _mujoco_to_canonical(vector: Sequence[float]) -> np.ndarray[Any, Any]:
    x, y, z = (float(component) for component in vector)
    return np.asarray([x, z, -y], dtype=np.float64)


def _canonical_json(value: dict[str, Any]) -> str:
    return json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    )


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return f"sha256:{digest.hexdigest()}"


def capability_manifest() -> dict[str, Any]:
    """Return only capabilities implemented and exercised by this adapter."""

    return {
        "schema_version": ADAPTER_MANIFEST_VERSION,
        "adapter_id": ADAPTER_ID,
        "locomotion_semantics_version": "sporespore_locomotion_semantics_v1",
        "host": {
            "engine": "mujoco",
            "engine_version": mujoco.__version__,
            "binding": "official_python_wheel",
            "scalar": "f64",
            "dimension": 3,
            "coordinate_mapping": (
                "canonical_x_forward_y_up_z_right_to_"
                "mujoco_x_forward_z_up_negative_y_right"
            ),
            "timestep_s": MUJOCO_DT_S,
            "integrator": "Euler",
            "solver": "Newton",
            "solver_iterations": SOLVER_ITERATIONS,
            "line_search_iterations": LINE_SEARCH_ITERATIONS,
            "friction_cone": "elliptic",
        },
        "conformance": {
            "c0_schema": True,
            "c1_pure_controller": True,
            "c2_kinematic": True,
            "c3_passive_dynamics": True,
            "c4_actuator": True,
            "c5_contact": True,
            "c6_locomotion": False,
        },
        "observation_capabilities": {
            "ordered_body_pose_twist": True,
            "joint_position_velocity": True,
            "joint_anchor_world": True,
            "joint_anchor_error": False,
            "contact_presence": True,
            "contact_bearing": False,
            "contact_point": True,
            "contact_normal": True,
            "contact_relative_velocity": True,
            "solver_contact_force": True,
            "solver_normal_load": True,
            "raw_contact_impulse": False,
            "persistent_semantic_contact_identity": False,
        },
        "actuator_capabilities": {
            "position_velocity_servo": True,
            "force_limit": True,
            "canonical_per_step_impulse_limit_mapping": True,
            "response_grid_characterization": True,
            "direct_effort_torque": False,
        },
        "material_characterization": {
            "authored_friction_vector": True,
            "effective_solver_friction_vector": True,
            "effective_breakaway": True,
            "steady_slide": True,
            "implemented_discrete_authored_sliding_values": [
                0.2,
                0.6,
                1.0,
            ],
            "characterization_report_authority": False,
            "restitution_coefficient": False,
        },
        "controller_policy_authority": False,
        "physical_acceptance_authority": False,
    }


def capability_manifest_sha256() -> str:
    payload = _canonical_json(capability_manifest()).encode("utf-8")
    return f"sha256:{hashlib.sha256(payload).hexdigest()}"


def _option_xml(
    gravity: str,
    *,
    integrator: str = "Euler",
) -> str:
    _require(
        integrator in ("Euler", "implicitfast"),
        "MUJOCO_OPTION_INTEGRATOR_UNSUPPORTED",
        integrator,
    )
    return (
        f'<option timestep="{MUJOCO_DT_S:.17g}" gravity="{gravity}" '
        f'integrator="{integrator}" solver="Newton" '
        f'iterations="{SOLVER_ITERATIONS}" '
        f'ls_iterations="{LINE_SEARCH_ITERATIONS}" cone="elliptic"/>'
    )


def _c0_c1_portable_core_fixture() -> dict[str, Any]:
    core = LocomotionCore()
    descriptor = reference_quadruped("mujoco_c0_c1_reference")
    compiled = core.compile_bounded_quadruped(descriptor)
    profile = core.candidate35_profile(descriptor)
    _require(core.version == "0.1.0", "MUJOCO_C0_CORE_VERSION_MISMATCH")
    _require(
        len(compiled["morphology"]["ordered_body_ids"]) == 9,
        "MUJOCO_C0_BODY_ORDER_MISMATCH",
    )
    _require(
        len(compiled["morphology"]["ordered_actuator_ids"]) == 8,
        "MUJOCO_C0_ACTUATOR_ORDER_MISMATCH",
    )
    _require(
        compiled["physical_acceptance_authority"] is False,
        "MUJOCO_C0_COMPILE_AUTHORITY_ESCALATION",
    )
    _require(
        profile["physical_acceptance_authority"] is False,
        "MUJOCO_C1_POLICY_AUTHORITY_ESCALATION",
    )
    return {
        "ok": True,
        "cell": "c0_c1_portable_core",
        "core_version": core.version,
        "core_library_path_execution_only": str(core.library_path),
        "core_library_sha256": _sha256_file(core.library_path),
        "ordered_body_count": 9,
        "ordered_actuator_count": 8,
        "candidate35_reference_profile_checked": True,
        "world_build_count": 0,
        "controller_policy_authority": False,
        "physical_acceptance_authority": False,
    }


def _c2_kinematic_fixture() -> dict[str, Any]:
    xml = f"""
<mujoco model="sporespore_mujoco_c2">
  <compiler angle="radian" inertiafromgeom="true"/>
  {_option_xml("0 0 0")}
  <worldbody>
    <body name="free_body">
      <freejoint name="free_joint"/>
      <geom type="box" size=".1 .1 .1" mass="1"
            contype="0" conaffinity="0"/>
    </body>
    <body name="hinge_parent">
      <body name="hinge_child">
        <joint name="hinge" type="hinge" axis="1 0 0" pos="0 0 0"
               limited="true" range="-.6 .8"/>
        <geom type="capsule" size=".05" fromto="0 0 0 0 .4 0" mass="1"
              contype="0" conaffinity="0"/>
      </body>
    </body>
  </worldbody>
</mujoco>
"""
    model = mujoco.MjModel.from_xml_string(xml)
    data = mujoco.MjData(model)
    free_joint_id = model.joint("free_joint").id
    free_qpos = int(model.jnt_qposadr[free_joint_id])
    free_dof = int(model.jnt_dofadr[free_joint_id])
    expected_position = np.asarray([1.25, 2.5, -3.75], dtype=np.float64)
    expected_linear_velocity = np.asarray([0.125, -0.25, 0.5], dtype=np.float64)
    expected_angular_velocity = np.asarray([0.25, -0.5, 0.75], dtype=np.float64)
    data.qpos[free_qpos : free_qpos + 3] = _canonical_to_mujoco(expected_position)
    data.qpos[free_qpos + 3 : free_qpos + 7] = [1.0, 0.0, 0.0, 0.0]
    data.qvel[free_dof : free_dof + 3] = _canonical_to_mujoco(expected_linear_velocity)
    data.qvel[free_dof + 3 : free_dof + 6] = _canonical_to_mujoco(
        expected_angular_velocity
    )
    mujoco.mj_forward(model, data)

    free_body_id = model.body("free_body").id
    observed_position = _mujoco_to_canonical(data.xpos[free_body_id])
    observed_linear_velocity = _mujoco_to_canonical(data.qvel[free_dof : free_dof + 3])
    observed_angular_velocity = _mujoco_to_canonical(
        data.qvel[free_dof + 3 : free_dof + 6]
    )
    position_error = float(np.linalg.norm(observed_position - expected_position))
    linear_error = float(
        np.linalg.norm(observed_linear_velocity - expected_linear_velocity)
    )
    angular_error = float(
        np.linalg.norm(observed_angular_velocity - expected_angular_velocity)
    )
    _require(position_error <= 1.0e-12, "MUJOCO_C2_POSITION_MAPPING_MISMATCH")
    _require(linear_error <= 1.0e-12, "MUJOCO_C2_LINEAR_VELOCITY_MISMATCH")
    _require(angular_error <= 1.0e-12, "MUJOCO_C2_ANGULAR_VELOCITY_MISMATCH")

    hinge_id = model.joint("hinge").id
    axis_canonical = _mujoco_to_canonical(model.jnt_axis[hinge_id])
    limits = model.jnt_range[hinge_id].copy()
    anchor_world_canonical = _mujoco_to_canonical(data.xanchor[hinge_id])
    _require(
        np.linalg.norm(axis_canonical - [1.0, 0.0, 0.0]) <= 1.0e-12,
        "MUJOCO_C2_HINGE_AXIS_MISMATCH",
    )
    _require(
        np.linalg.norm(limits - [-0.6, 0.8]) <= 1.0e-12,
        "MUJOCO_C2_HINGE_LIMIT_MISMATCH",
    )
    anchor_error = float(np.linalg.norm(anchor_world_canonical))
    _require(anchor_error <= 1.0e-12, "MUJOCO_C2_HINGE_ANCHOR_MISMATCH")

    return {
        "ok": True,
        "cell": "c2_kinematic",
        "body_pose_twist_roundtrip_error": {
            "translation_m": position_error,
            "linear_velocity_m_s": linear_error,
            "angular_velocity_rad_s": angular_error,
        },
        "joint": {
            "kind": "hinge",
            "axis_canonical": axis_canonical.tolist(),
            "limits_rad": limits.tolist(),
            "initial_anchor_mapping_error_m": anchor_error,
        },
        "coordinate_mapping": "canonical_xyz_to_mujoco_x_negative_z_y",
        "world_build_count": 1,
        "physical_acceptance_authority": False,
    }


def _c3_passive_dynamics_fixture() -> dict[str, Any]:
    fall_xml = f"""
<mujoco model="sporespore_mujoco_c3_fall">
  <compiler inertiafromgeom="true"/>
  {_option_xml("0 0 -9.8")}
  <worldbody>
    <body name="falling" pos="0 0 10">
      <freejoint/>
      <geom type="sphere" size=".1" mass="1"
            contype="0" conaffinity="0"/>
    </body>
  </worldbody>
</mujoco>
"""
    model = mujoco.MjModel.from_xml_string(fall_xml)
    data = mujoco.MjData(model)
    for _ in range(120):
        mujoco.mj_step(model, data)
    falling_id = model.body("falling").id
    final_height = float(data.xpos[falling_id][2])
    final_velocity = float(data.qvel[2])
    gravity = -9.8
    expected_velocity = gravity
    expected_explicit_euler_height = 10.0 + gravity * MUJOCO_DT_S * MUJOCO_DT_S * (
        120.0 * 119.0 / 2.0
    )
    _require(
        abs(final_velocity - expected_velocity) <= 2.0e-10,
        "MUJOCO_C3_FREE_FALL_VELOCITY_MISMATCH",
        f"observed={final_velocity:.12g} expected={expected_velocity:.12g}",
    )
    _require(
        abs(final_height - expected_explicit_euler_height) <= 2.0e-10,
        "MUJOCO_C3_FREE_FALL_POSITION_MISMATCH",
        (
            f"observed={final_height:.12g} "
            f"expected={expected_explicit_euler_height:.12g}"
        ),
    )

    damping_xml = f"""
<mujoco model="sporespore_mujoco_c3_damping">
  <compiler inertiafromgeom="true"/>
  {_option_xml("0 0 0")}
  <worldbody>
    <body>
      <joint name="damped" type="hinge" axis="1 0 0" damping="1"/>
      <geom type="capsule" size=".05" fromto="0 0 0 0 .4 0" mass="1"
            contype="0" conaffinity="0"/>
    </body>
  </worldbody>
</mujoco>
"""
    damping_model = mujoco.MjModel.from_xml_string(damping_xml)
    damping_data = mujoco.MjData(damping_model)
    damping_data.qvel[0] = 1.0
    mujoco.mj_forward(damping_model, damping_data)
    for _ in range(120):
        mujoco.mj_step(damping_model, damping_data)
    final_damped_speed = abs(float(damping_data.qvel[0]))
    _require(
        0.0 <= final_damped_speed < 0.5,
        "MUJOCO_C3_DAMPING_RESPONSE_INVALID",
        f"final_speed={final_damped_speed:.12g}",
    )
    return {
        "ok": True,
        "cell": "c3_passive_dynamics",
        "free_fall": {
            "steps": 120,
            "duration_s": 120.0 * MUJOCO_DT_S,
            "gravity_up_axis_m_s2": gravity,
            "final_height_m": final_height,
            "expected_explicit_euler_height_m": expected_explicit_euler_height,
            "final_vertical_velocity_m_s": final_velocity,
        },
        "joint_damping": {
            "coefficient": 1.0,
            "initial_speed_rad_s": 1.0,
            "final_speed_rad_s": final_damped_speed,
        },
        "world_build_count": 2,
        "physical_acceptance_authority": False,
    }


def _maximum_impulse_to_force(
    maximum_impulse_nms: float,
    timestep_s: float,
) -> float:
    _require(
        math.isfinite(maximum_impulse_nms) and maximum_impulse_nms >= 0.0,
        "MUJOCO_C4_MAXIMUM_IMPULSE_INVALID",
    )
    _require(
        math.isfinite(timestep_s) and timestep_s > 0.0,
        "MUJOCO_C4_TIMESTEP_INVALID",
    )
    force = maximum_impulse_nms / timestep_s
    _require(math.isfinite(force), "MUJOCO_C4_MAXIMUM_FORCE_UNREPRESENTABLE")
    return force


def _c4_actuator_fixture() -> dict[str, Any]:
    maximum_impulse = 0.25
    maximum_force = _maximum_impulse_to_force(maximum_impulse, MUJOCO_DT_S)
    target_position = 0.4
    xml = f"""
<mujoco model="sporespore_mujoco_c4">
  <compiler angle="radian" inertiafromgeom="true"/>
  {_option_xml("0 0 0")}
  <worldbody>
    <body>
      <joint name="hinge" type="hinge" axis="1 0 0"
             limited="true" range="-1 1" armature=".01"/>
      <geom type="capsule" size=".05" fromto="0 0 0 0 .4 0" mass="1"
            contype="0" conaffinity="0"/>
    </body>
  </worldbody>
  <actuator>
    <position name="motor" joint="hinge" kp="40" kv="10"
              forcelimited="true" forcerange="{-maximum_force} {maximum_force}"/>
  </actuator>
</mujoco>
"""
    model = mujoco.MjModel.from_xml_string(xml)
    data = mujoco.MjData(model)
    data.ctrl[0] = target_position
    maximum_observed_force = 0.0
    maximum_observed_derived_impulse = 0.0
    for _ in range(240):
        mujoco.mj_step(model, data)
        force = abs(float(data.actuator_force[0]))
        impulse = force * MUJOCO_DT_S
        maximum_observed_force = max(maximum_observed_force, force)
        maximum_observed_derived_impulse = max(
            maximum_observed_derived_impulse,
            impulse,
        )
        _require(
            impulse <= maximum_impulse + 1.0e-12,
            "MUJOCO_C4_PER_STEP_IMPULSE_LIMIT_EXCEEDED",
        )
    final_position = float(data.qpos[0])
    force_range = model.actuator_forcerange[0].copy()
    _require(
        np.linalg.norm(force_range - [-maximum_force, maximum_force]) <= 1.0e-12,
        "MUJOCO_C4_FORCE_RANGE_MAPPING_MISMATCH",
    )
    _require(
        abs(final_position - target_position) <= 0.02,
        "MUJOCO_C4_POSITION_SERVO_TRACKING_MISMATCH",
        f"observed={final_position:.12g} target={target_position:.12g}",
    )
    return {
        "ok": True,
        "cell": "c4_actuator",
        "actuator_model": "mujoco_position_servo_force_limited",
        "target_position_rad": target_position,
        "final_position_rad": final_position,
        "maximum_impulse_nms": maximum_impulse,
        "mapped_maximum_force_nm": maximum_force,
        "maximum_observed_force_nm": maximum_observed_force,
        "maximum_observed_derived_step_impulse_nms": (maximum_observed_derived_impulse),
        "mapping_rule": "force_limit_nm = maximum_impulse_nms / timestep_s",
        "world_build_count": 1,
        "physical_acceptance_authority": False,
    }


def _c5_contact_fixture() -> dict[str, Any]:
    ground_friction = np.asarray([0.6, 0.01, 0.001], dtype=np.float64)
    body_friction = np.asarray([0.4, 0.005, 0.0005], dtype=np.float64)
    expected_contact_friction = np.asarray(
        [0.6, 0.6, 0.01, 0.001, 0.001],
        dtype=np.float64,
    )
    xml = f"""
<mujoco model="sporespore_mujoco_c5">
  <compiler inertiafromgeom="true"/>
  {_option_xml("0 0 -9.8")}
  <worldbody>
    <geom name="ground" type="plane" size="5 5 .1"
          friction=".6 .01 .001" priority="0" condim="6"/>
    <body name="contact_body" pos="0 0 .49">
      <freejoint/>
      <geom name="ball" type="sphere" size=".5" mass="1"
            friction=".4 .005 .0005" priority="0" condim="6"/>
    </body>
  </worldbody>
</mujoco>
"""
    model = mujoco.MjModel.from_xml_string(xml)
    data = mujoco.MjData(model)
    for _ in range(8):
        mujoco.mj_step(model, data)
    ground_id = model.geom("ground").id
    ball_id = model.geom("ball").id
    contact_index = next(
        (
            index
            for index in range(data.ncon)
            if {int(data.contact[index].geom1), int(data.contact[index].geom2)}
            == {ground_id, ball_id}
        ),
        None,
    )
    _require(contact_index is not None, "MUJOCO_C5_CONTACT_PAIR_MISSING")
    contact = data.contact[contact_index]
    point_mujoco = np.asarray(contact.pos, dtype=np.float64).copy()
    frame = np.asarray(contact.frame, dtype=np.float64).reshape(3, 3)
    normal_mujoco = frame[0].copy()
    friction = np.asarray(contact.friction, dtype=np.float64).copy()
    _require(
        _finite(point_mujoco) and _finite(normal_mujoco),
        "MUJOCO_C5_CONTACT_GEOMETRY_NONFINITE",
    )
    _require(
        abs(float(np.linalg.norm(normal_mujoco)) - 1.0) <= 1.0e-12,
        "MUJOCO_C5_CONTACT_NORMAL_NOT_UNIT",
    )
    _require(
        np.linalg.norm(friction - expected_contact_friction) <= 1.0e-12,
        "MUJOCO_C5_EFFECTIVE_FRICTION_MISMATCH",
        f"observed={friction.tolist()}",
    )

    contact_force = np.zeros(6, dtype=np.float64)
    mujoco.mj_contactForce(model, data, contact_index, contact_force)
    _require(_finite(contact_force), "MUJOCO_C5_CONTACT_FORCE_NONFINITE")
    normal_load = abs(float(contact_force[0]))
    _require(normal_load > 0.0, "MUJOCO_C5_NORMAL_LOAD_UNAVAILABLE")

    body_id = model.body("contact_body").id
    body_spatial_velocity = np.zeros(6, dtype=np.float64)
    mujoco.mj_objectVelocity(
        model,
        data,
        mujoco.mjtObj.mjOBJ_BODY,
        body_id,
        body_spatial_velocity,
        0,
    )
    angular_velocity = body_spatial_velocity[:3]
    linear_velocity = body_spatial_velocity[3:]
    relative_velocity_mujoco = linear_velocity + np.cross(
        angular_velocity,
        point_mujoco - data.xpos[body_id],
    )
    _require(
        _finite(relative_velocity_mujoco),
        "MUJOCO_C5_RELATIVE_VELOCITY_NONFINITE",
    )
    point_canonical = _mujoco_to_canonical(point_mujoco)
    normal_canonical = _mujoco_to_canonical(normal_mujoco)
    relative_velocity_canonical = _mujoco_to_canonical(relative_velocity_mujoco)
    derived_step_impulse = float(np.linalg.norm(contact_force[:3]) * MUJOCO_DT_S)

    return {
        "ok": True,
        "cell": "c5_contact",
        "contact": {
            "presence": True,
            "point_world_canonical_m": point_canonical.tolist(),
            "normal_world_canonical_unit": normal_canonical.tolist(),
            "relative_velocity_world_canonical_m_s": (
                relative_velocity_canonical.tolist()
            ),
            "solver_contact_force_contact_frame_n": contact_force.tolist(),
            "solver_normal_load_n": normal_load,
            "derived_step_impulse_nms": derived_step_impulse,
            "derived_step_impulse_is_not_raw_engine_impulse": True,
            "solver_force_is_not_aggregated_per_foot_load": True,
        },
        "material": {
            "ground_authored_friction": ground_friction.tolist(),
            "body_authored_friction": body_friction.tolist(),
            "equal_priority_combine_rule": "component_wise_maximum",
            "effective_solver_friction_5d": friction.tolist(),
            "breakaway_characterized": False,
            "steady_slide_characterized": False,
            "restitution_coefficient_available": False,
        },
        "contact_identity": {
            "scope": "per_step_contact_array_index_and_geom_pair",
            "persistent_semantic_contact_identity": False,
        },
        "world_build_count": 1,
        "physical_acceptance_authority": False,
    }


def run_c0_c5_conformance() -> dict[str, Any]:
    cells = [
        _c0_c1_portable_core_fixture(),
        _c2_kinematic_fixture(),
        _c3_passive_dynamics_fixture(),
        _c4_actuator_fixture(),
        _c5_contact_fixture(),
    ]
    return {
        "schema_version": "sporespore_mujoco_c0_c5_conformance_report_v1",
        "ok": True,
        "adapter_id": ADAPTER_ID,
        "adapter_manifest": capability_manifest(),
        "adapter_manifest_sha256": capability_manifest_sha256(),
        "mujoco_version": mujoco.__version__,
        "numpy_version": np.__version__,
        "cells": cells,
        "passed_cells": len(cells),
        "failed_cells": 0,
        "passed_capabilities": ["c0", "c1", "c2", "c3", "c4", "c5"],
        "controller_policy_authority": False,
        "physical_acceptance_authority": False,
    }


def _retain_report(report: dict[str, Any], path: Path) -> None:
    _require(path.name == "report.json", "MUJOCO_REPORT_NAME_INVALID")
    _require(not path.exists(), "MUJOCO_REPORT_ALREADY_EXISTS", str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name("report.json.tmp")
    serialized = json.dumps(report, indent=2, allow_nan=False) + "\n"
    temporary.write_text(serialized, encoding="utf-8", newline="\n")
    os.replace(temporary, path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        report = run_c0_c5_conformance()
        if args.output is not None:
            _retain_report(report, args.output.resolve())
            print(
                f"retained MuJoCo C0-C5 report: {args.output.resolve()}",
                file=sys.stderr,
            )
        print(json.dumps(report, indent=2, allow_nan=False))
    except (ConformanceFailure, OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
