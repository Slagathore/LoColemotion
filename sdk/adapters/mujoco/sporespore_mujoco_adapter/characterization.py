"""Prospectively frozen MuJoCo material and actuator characterization."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import sys
from typing import Any

import mujoco
import numpy as np

from .conformance import (
    ADAPTER_ID,
    MUJOCO_DT_S,
    ConformanceFailure,
    _maximum_impulse_to_force,
    _option_xml,
    _require,
    capability_manifest,
    capability_manifest_sha256,
)

_SDK_ROOT = Path(__file__).resolve().parents[3]
_BASE_PREREGISTRATION_PATH = (
    _SDK_ROOT
    / "cross_engine_c6_host_characterization_preregistration.json"
)
_PREDECESSOR_CLOSURE_PATH = (
    _SDK_ROOT / "cross_engine_c6_host_characterization_closure.json"
)
_R1_PREREGISTRATION_PATH = (
    _SDK_ROOT
    / "cross_engine_c6_host_characterization_r1_preregistration.json"
)
_R1_CLOSURE_PATH = (
    _SDK_ROOT / "cross_engine_c6_host_characterization_r1_closure.json"
)
_PREREGISTRATION_PATH = (
    _SDK_ROOT
    / "cross_engine_c6_host_characterization_r2_preregistration.json"
)
_BASE_PREREGISTRATION_RAW_SHA256 = (
    "sha256:"
    "2ff51bc87745d84f2d4d0521005098ead3bef20e691b25f9f49c0cf7eadade8e"
)
_PREDECESSOR_CLOSURE_RAW_SHA256 = (
    "sha256:"
    "dadd1e8a44dca2e66136c496a91bf2d4e579300459af4f0884b9040aa3faff21"
)
_R1_PREREGISTRATION_RAW_SHA256 = (
    "sha256:"
    "a5ebb5c3fa827ec6d4952326f63ef68a87134d2cea71186ca15bd3174df84e11"
)
_R1_CLOSURE_RAW_SHA256 = (
    "sha256:"
    "c4fac9d63428e747ac052169d97b344e2b774ce728f1a368f3e842f70248da12"
)
_GRAVITY_M_S2 = 9.8
_SLED_MASS_KG = 1.0
_SETTLE_STEPS = 240
_BREAKAWAY_STEPS = 120
_STEADY_SLIDE_STEPS = 6
_ACTUATOR_STEPS = 240
_BREAKAWAY_VELOCITY_THRESHOLD_M_S = 0.02
_BREAKAWAY_DISPLACEMENT_THRESHOLD_M = 0.005
_MAXIMUM_BREAKAWAY_BRACKET_WIDTH_RATIO = 0.25
_MINIMUM_BREAKAWAY_LOWER_RATIO = 0.5
_MAXIMUM_BREAKAWAY_UPPER_RATIO = 1.5
_STEADY_SLIDE_INITIAL_VELOCITY_M_S = 1.0
_MINIMUM_STEADY_SLIDE_EFFECTIVE_TO_AUTHORED_RATIO = 0.5
_MAXIMUM_STEADY_SLIDE_EFFECTIVE_TO_AUTHORED_RATIO = 1.5
_ACTUATOR_TARGET_VELOCITY_RAD_S = 0.0
_ACTUATOR_STIFFNESS_NM_PER_RAD = 40.0
_ACTUATOR_DAMPING_NM_S_PER_RAD = 10.0
_ACTUATOR_CHILD_HALF_EXTENTS_M = (0.2, 0.2, 0.2)
_ACTUATOR_CHILD_MASS_KG = 1.0
_ACTUATOR_CHILD_EXPECTED_PRINCIPAL_INERTIA_KG_M2 = (
    0.02666666666666667,
    0.02666666666666667,
    0.02666666666666667,
)
_ACTUATOR_CHILD_MASS_TOLERANCE_KG = 0.000001
_ACTUATOR_CHILD_INERTIA_TOLERANCE_KG_M2 = 0.000001
_MAXIMUM_FINAL_POSITION_ERROR_RAD = 0.02
_MAXIMUM_IMPULSE_TOLERANCE_NMS = 0.000001
_AUTHORED_FRICTIONS = (0.2, 0.6, 1.0)
_BREAKAWAY_FORCE_RATIOS = (0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5)
_ACTUATOR_TARGETS_RAD = (-0.4, 0.4)
_ACTUATOR_MAXIMUM_STEP_IMPULSES_NMS = (0.05, 0.25)


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _base_preregistration() -> dict[str, Any]:
    _require(
        _raw_sha256(_BASE_PREREGISTRATION_PATH)
        == _BASE_PREREGISTRATION_RAW_SHA256,
        "MUJOCO_HC1_BASE_PREREGISTRATION_HASH",
    )
    preregistration = json.loads(
        _BASE_PREREGISTRATION_PATH.read_text(encoding="utf-8")
    )
    _require(
        preregistration["schema_version"]
        == (
            "sporespore_cross_engine_c6_host_characterization_"
            "preregistration_v1"
        ),
        "MUJOCO_HC1_PREREGISTRATION_SCHEMA",
    )
    _require(
        preregistration["campaign_id"] == "C6-HOST-CHARACTERIZATION"
        and preregistration["gate_id"] == "C6-HC1"
        and preregistration["status"]
        == "frozen_before_first_c6_hc1_physics_world",
        "MUJOCO_HC1_PREREGISTRATION_IDENTITY",
    )
    common = preregistration["common_fixture"]
    actuator = preregistration["actuator_fixture"]
    _require(
        abs(float(common["timestep_s"]) - MUJOCO_DT_S)
        <= math.ulp(MUJOCO_DT_S)
        and float(common["gravity_m_s2"]) == _GRAVITY_M_S2
        and float(common["sled_mass_kg"]) == _SLED_MASS_KG
        and int(common["settle_steps"]) == _SETTLE_STEPS
        and int(common["breakaway_observation_steps"])
        == _BREAKAWAY_STEPS
        and int(common["steady_slide_observation_steps"])
        == _STEADY_SLIDE_STEPS
        and int(actuator["observation_steps"]) == _ACTUATOR_STEPS
        and tuple(
            float(value)
            for value in common["authored_sliding_friction_values"]
        )
        == _AUTHORED_FRICTIONS
        and tuple(
            float(value)
            for value in common["breakaway_force_ratios"]
        )
        == _BREAKAWAY_FORCE_RATIOS
        and float(common["breakaway_velocity_threshold_m_s"])
        == _BREAKAWAY_VELOCITY_THRESHOLD_M_S
        and float(common["breakaway_displacement_threshold_m"])
        == _BREAKAWAY_DISPLACEMENT_THRESHOLD_M
        and float(common["maximum_breakaway_bracket_width_ratio"])
        == _MAXIMUM_BREAKAWAY_BRACKET_WIDTH_RATIO
        and float(common["minimum_breakaway_lower_ratio"])
        == _MINIMUM_BREAKAWAY_LOWER_RATIO
        and float(common["maximum_breakaway_upper_ratio"])
        == _MAXIMUM_BREAKAWAY_UPPER_RATIO
        and float(common["steady_slide_initial_velocity_m_s"])
        == _STEADY_SLIDE_INITIAL_VELOCITY_M_S
        and float(
            common["minimum_steady_slide_effective_to_authored_ratio"]
        )
        == _MINIMUM_STEADY_SLIDE_EFFECTIVE_TO_AUTHORED_RATIO
        and float(
            common["maximum_steady_slide_effective_to_authored_ratio"]
        )
        == _MAXIMUM_STEADY_SLIDE_EFFECTIVE_TO_AUTHORED_RATIO
        and tuple(
            float(value) for value in actuator["target_positions_rad"]
        )
        == _ACTUATOR_TARGETS_RAD
        and tuple(
            float(value)
            for value in actuator["maximum_step_impulses_nms"]
        )
        == _ACTUATOR_MAXIMUM_STEP_IMPULSES_NMS
        and float(actuator["target_velocity_rad_s"])
        == _ACTUATOR_TARGET_VELOCITY_RAD_S
        and float(actuator["stiffness_nm_per_rad"])
        == _ACTUATOR_STIFFNESS_NM_PER_RAD
        and float(actuator["damping_nm_s_per_rad"])
        == _ACTUATOR_DAMPING_NM_S_PER_RAD
        and float(actuator["maximum_final_position_error_rad"])
        == _MAXIMUM_FINAL_POSITION_ERROR_RAD
        and float(actuator["maximum_impulse_tolerance_nms"])
        == _MAXIMUM_IMPULSE_TOLERANCE_NMS,
        "MUJOCO_HC1_PREREGISTRATION_COMMON_FIXTURE",
    )
    host = preregistration["host_contracts"]["mujoco"]
    _require(
        host["adapter_id"] == ADAPTER_ID
        and host["engine_version"] == mujoco.__version__
        and host["friction_cone"] == "elliptic"
        and int(host["geom_priority"]) == 1
        and float(host["torsional_friction"]) == 0.0
        and float(host["rolling_friction"]) == 0.0,
        "MUJOCO_HC1_PREREGISTRATION_HOST",
    )
    return preregistration


def _r1_preregistration() -> tuple[dict[str, Any], dict[str, Any]]:
    base = _base_preregistration()
    _require(
        _raw_sha256(_PREDECESSOR_CLOSURE_PATH)
        == _PREDECESSOR_CLOSURE_RAW_SHA256,
        "MUJOCO_HC1_R1_PREDECESSOR_CLOSURE_HASH",
    )
    preregistration = json.loads(
        _R1_PREREGISTRATION_PATH.read_text(encoding="utf-8")
    )
    _require(
        preregistration["schema_version"]
        == (
            "sporespore_cross_engine_c6_host_characterization_"
            "r1_preregistration_v1"
        )
        and preregistration["campaign_id"]
        == "C6-HOST-CHARACTERIZATION-R1"
        and preregistration["gate_id"] == "C6-HC1-R1"
        and preregistration["status"]
        == "frozen_before_first_c6_hc1_r1_physics_world",
        "MUJOCO_HC1_R1_PREREGISTRATION_IDENTITY",
    )
    _require(
        preregistration["implementation_parent_commit"]
        == "4707b8d5d467d899a3b6ea1d8f5caf28bd99f008"
        and preregistration["base_preregistration"]["raw_sha256"]
        == _BASE_PREREGISTRATION_RAW_SHA256
        and preregistration["predecessor_closure"]["raw_sha256"]
        == _PREDECESSOR_CLOSURE_RAW_SHA256
        and bool(
            preregistration["predecessor_closure"][
                "same_identity_rerun_forbidden"
            ]
        ),
        "MUJOCO_HC1_R1_PREDECESSOR_BOUNDARY",
    )
    correction = preregistration["correction"]["shared_actuator_child"]
    mujoco_correction = preregistration["correction"]["mujoco"]
    _require(
        correction["shape"] == "cuboid"
        and tuple(float(value) for value in correction["half_extents_m"])
        == _ACTUATOR_CHILD_HALF_EXTENTS_M
        and float(correction["mass_kg"]) == _ACTUATOR_CHILD_MASS_KG
        and correction["mass_properties_source"]
        == "shape_derived_from_nonzero_mass_collider"
        and bool(correction["center_of_mass_at_joint_anchor"])
        and tuple(
            float(value)
            for value in correction[
                "expected_principal_angular_inertia_kg_m2"
            ]
        )
        == _ACTUATOR_CHILD_EXPECTED_PRINCIPAL_INERTIA_KG_M2
        and float(correction["maximum_absolute_mass_error_kg"])
        == _ACTUATOR_CHILD_MASS_TOLERANCE_KG
        and float(
            correction[
                "maximum_absolute_principal_inertia_error_kg_m2"
            ]
        )
        == _ACTUATOR_CHILD_INERTIA_TOLERANCE_KG_M2
        and bool(
            correction["every_principal_inertia_axis_must_be_positive"]
        )
        and bool(
            mujoco_correction[
                "replace_predecessor_capsule_with_shared_cuboid"
            ]
        )
        and float(mujoco_correction["geom_mass_kg"])
        == _ACTUATOR_CHILD_MASS_KG
        and float(mujoco_correction["joint_armature_kg_m2"]) == 0.0
        and bool(mujoco_correction["report_measured_body_inertia"]),
        "MUJOCO_HC1_R1_ACTUATOR_CORRECTION",
    )
    unchanged = preregistration["unchanged_grid"]
    _require(
        float(unchanged["timestep_s"]) == MUJOCO_DT_S
        and tuple(
            float(value)
            for value in unchanged["authored_sliding_friction_values"]
        )
        == _AUTHORED_FRICTIONS
        and tuple(
            float(value)
            for value in unchanged["breakaway_force_ratios"]
        )
        == _BREAKAWAY_FORCE_RATIOS
        and tuple(
            float(value) for value in unchanged["target_positions_rad"]
        )
        == _ACTUATOR_TARGETS_RAD
        and tuple(
            float(value)
            for value in unchanged["maximum_step_impulses_nms"]
        )
        == _ACTUATOR_MAXIMUM_STEP_IMPULSES_NMS
        and int(unchanged["actuator_observation_steps"])
        == _ACTUATOR_STEPS
        and float(unchanged["maximum_final_position_error_rad"])
        == _MAXIMUM_FINAL_POSITION_ERROR_RAD,
        "MUJOCO_HC1_R1_UNCHANGED_GRID",
    )
    return base, preregistration


def _preregistration() -> tuple[
    dict[str, Any],
    dict[str, Any],
    dict[str, Any],
]:
    base, r1 = _r1_preregistration()
    _require(
        _raw_sha256(_R1_PREREGISTRATION_PATH)
        == _R1_PREREGISTRATION_RAW_SHA256
        and _raw_sha256(_R1_CLOSURE_PATH) == _R1_CLOSURE_RAW_SHA256,
        "MUJOCO_HC1_R2_R1_SOURCE_HASH",
    )
    preregistration = json.loads(
        _PREREGISTRATION_PATH.read_text(encoding="utf-8")
    )
    _require(
        preregistration["schema_version"]
        == (
            "sporespore_cross_engine_c6_host_characterization_"
            "r2_preregistration_v1"
        )
        and preregistration["campaign_id"]
        == "C6-HOST-CHARACTERIZATION-R2"
        and preregistration["gate_id"] == "C6-HC1-R2"
        and preregistration["status"]
        == "frozen_before_first_c6_hc1_r2_physics_world",
        "MUJOCO_HC1_R2_PREREGISTRATION_IDENTITY",
    )
    correction = preregistration["correction"]
    _require(
        preregistration["implementation_parent_commit"]
        == "f54375ad1a4ba3d1e02c01b77983c3879e110bf4"
        and preregistration["r1_preregistration"]["raw_sha256"]
        == _R1_PREREGISTRATION_RAW_SHA256
        and preregistration["r1_closure"]["raw_sha256"]
        == _R1_CLOSURE_RAW_SHA256
        and bool(
            preregistration["r1_closure"]["same_identity_rerun_forbidden"]
        )
        and correction["mujoco_material"]["integrator"] == "Euler"
        and bool(
            correction["mujoco_material"]["all_fixture_inputs_unchanged"]
        )
        and correction["mujoco_actuator"]["predecessor_integrator"]
        == "Euler"
        and correction["mujoco_actuator"]["successor_integrator"]
        == "implicitfast"
        and bool(
            correction["mujoco_actuator"][
                "all_other_fixture_inputs_unchanged"
            ]
        ),
        "MUJOCO_HC1_R2_PREDECESSOR_BOUNDARY",
    )
    fixture = preregistration["unchanged_actuator_fixture"]
    _require(
        fixture["shape"] == "cuboid"
        and tuple(float(value) for value in fixture["half_extents_m"])
        == _ACTUATOR_CHILD_HALF_EXTENTS_M
        and float(fixture["mass_kg"]) == _ACTUATOR_CHILD_MASS_KG
        and fixture["mass_properties_source"]
        == "shape_derived_from_nonzero_mass_collider"
        and tuple(
            float(value)
            for value in fixture[
                "expected_principal_angular_inertia_kg_m2"
            ]
        )
        == _ACTUATOR_CHILD_EXPECTED_PRINCIPAL_INERTIA_KG_M2
        and tuple(
            float(value) for value in fixture["target_positions_rad"]
        )
        == _ACTUATOR_TARGETS_RAD
        and tuple(
            float(value)
            for value in fixture["maximum_step_impulses_nms"]
        )
        == _ACTUATOR_MAXIMUM_STEP_IMPULSES_NMS
        and float(fixture["stiffness_nm_per_rad"])
        == _ACTUATOR_STIFFNESS_NM_PER_RAD
        and float(fixture["damping_nm_s_per_rad"])
        == _ACTUATOR_DAMPING_NM_S_PER_RAD
        and float(fixture["timestep_s"]) == MUJOCO_DT_S
        and int(fixture["observation_steps"]) == _ACTUATOR_STEPS
        and float(fixture["maximum_final_position_error_rad"])
        == _MAXIMUM_FINAL_POSITION_ERROR_RAD,
        "MUJOCO_HC1_R2_UNCHANGED_ACTUATOR_FIXTURE",
    )
    return base, r1, preregistration


def _preregistration_raw_sha256() -> str:
    return _raw_sha256(_PREREGISTRATION_PATH)


def _perfect_synthetic_summary() -> dict[str, int]:
    return {
        "expected_material_profile_count": 3,
        "observed_material_profile_count": 3,
        "expected_breakaway_trial_count": 21,
        "observed_breakaway_trial_count": 21,
        "expected_steady_slide_trial_count": 3,
        "observed_steady_slide_trial_count": 3,
        "expected_actuator_cell_count": 4,
        "observed_actuator_cell_count": 4,
        "failed_material_profile_count": 0,
        "failed_breakaway_trial_count": 0,
        "failed_steady_slide_trial_count": 0,
        "failed_actuator_cell_count": 0,
        "source_mismatch_count": 0,
        "nonfinite_observation_count": 0,
    }


def _validate_integrity_summary(summary: dict[str, int]) -> None:
    expected = _perfect_synthetic_summary()
    _require(
        all(summary.get(key) == value for key, value in expected.items()),
        "MUJOCO_HC1_INTEGRITY_GATE",
    )


def run_host_characterization_preflight() -> dict[str, Any]:
    """Exercise the complete result gate with zero physical worlds."""

    _preregistration()
    perfect = _perfect_synthetic_summary()
    _validate_integrity_summary(perfect)
    canary = dict(perfect)
    canary["failed_breakaway_trial_count"] = 1
    canary_rejected = False
    try:
        _validate_integrity_summary(canary)
    except ConformanceFailure:
        canary_rejected = True
    _require(canary_rejected, "MUJOCO_HC1_NONZERO_CANARY_ACCEPTED")
    return {
        "schema_version": (
            "sporespore_c6_host_characterization_r2_preflight_v1"
        ),
        "ok": True,
        "adapter_id": ADAPTER_ID,
        "campaign_id": "C6-HOST-CHARACTERIZATION-R2",
        "gate_id": "C6-HC1-R2",
        "preregistration_raw_sha256": _preregistration_raw_sha256(),
        "perfect_synthetic_result_passed": True,
        "nonzero_failure_canary_rejected": True,
        "full_integrity_gate_executed": True,
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_mutation_count": 0,
        "physical_acceptance_authority": False,
    }


def _sled_model(authored_friction: float) -> mujoco.MjModel:
    friction = f"{authored_friction:.17g} 0 0"
    xml = f"""
<mujoco model="sporespore_mujoco_hc1_sled">
  <compiler inertiafromgeom="true"/>
  {_option_xml("0 0 -9.8")}
  <worldbody>
    <geom name="ground" type="plane" size="5 5 .1"
          friction="{friction}" priority="1" condim="3"/>
    <body name="sled" pos="0 0 .1">
      <freejoint/>
      <geom name="sled_geom" type="box" size=".2 .15 .1"
            mass="1" friction="{friction}" priority="1" condim="3"/>
    </body>
  </worldbody>
</mujoco>
"""
    return mujoco.MjModel.from_xml_string(xml)


def _settled_sled(
    authored_friction: float,
) -> tuple[mujoco.MjModel, mujoco.MjData, int]:
    model = _sled_model(authored_friction)
    data = mujoco.MjData(model)
    for _ in range(_SETTLE_STEPS):
        mujoco.mj_step(model, data)
    sled_body_id = model.body("sled").id
    _require(
        abs(float(model.body_mass[sled_body_id]) - _SLED_MASS_KG)
        <= 1.0e-12,
        "MUJOCO_HC1_SLED_MASS_MISMATCH",
    )
    _require(
        bool(np.isfinite(data.xpos[sled_body_id]).all())
        and bool(np.isfinite(data.qvel).all()),
        "MUJOCO_HC1_SLED_SETTLE_NONFINITE",
    )
    return model, data, sled_body_id


def _breakaway_trial(
    authored_friction: float,
    force_ratio: float,
) -> dict[str, Any]:
    model, data, sled_body_id = _settled_sled(authored_friction)
    start_x = float(data.xpos[sled_body_id, 0])
    applied_force = (
        authored_friction
        * _SLED_MASS_KG
        * _GRAVITY_M_S2
        * force_ratio
    )
    maximum_speed = 0.0
    for _ in range(_BREAKAWAY_STEPS):
        data.xfrc_applied.fill(0.0)
        data.xfrc_applied[sled_body_id, 0] = applied_force
        mujoco.mj_step(model, data)
        maximum_speed = max(maximum_speed, abs(float(data.qvel[0])))
    displacement = abs(float(data.xpos[sled_body_id, 0]) - start_x)
    broke_away = (
        maximum_speed > _BREAKAWAY_VELOCITY_THRESHOLD_M_S
        or displacement > _BREAKAWAY_DISPLACEMENT_THRESHOLD_M
    )
    _require(
        all(
            math.isfinite(value)
            for value in (applied_force, displacement, maximum_speed)
        ),
        "MUJOCO_HC1_BREAKAWAY_NONFINITE",
    )
    return {
        "ok": True,
        "authored_friction": authored_friction,
        "force_ratio_to_authored_coulomb_limit": force_ratio,
        "applied_force_n": applied_force,
        "absolute_forward_displacement_m": displacement,
        "maximum_absolute_forward_speed_m_s": maximum_speed,
        "velocity_threshold_m_s": _BREAKAWAY_VELOCITY_THRESHOLD_M_S,
        "displacement_threshold_m": (
            _BREAKAWAY_DISPLACEMENT_THRESHOLD_M
        ),
        "broke_away": broke_away,
        "failure_codes": [],
        "world_attempt_count": 1,
        "world_build_count": 1,
    }


def _steady_slide_trial(authored_friction: float) -> dict[str, Any]:
    model, data, sled_body_id = _settled_sled(authored_friction)
    data.qvel[0] = _STEADY_SLIDE_INITIAL_VELOCITY_M_S
    mujoco.mj_forward(model, data)
    start_x = float(data.xpos[sled_body_id, 0])
    for _ in range(_STEADY_SLIDE_STEPS):
        data.xfrc_applied.fill(0.0)
        mujoco.mj_step(model, data)
    final_velocity = float(data.qvel[0])
    elapsed = _STEADY_SLIDE_STEPS * MUJOCO_DT_S
    effective_friction = (
        _STEADY_SLIDE_INITIAL_VELOCITY_M_S - final_velocity
    ) / (_GRAVITY_M_S2 * elapsed)
    effective_to_authored = effective_friction / authored_friction
    _require(
        all(
            math.isfinite(value)
            for value in (
                final_velocity,
                effective_friction,
                effective_to_authored,
            )
        ),
        "MUJOCO_HC1_STEADY_SLIDE_NONFINITE",
    )
    _require(
        final_velocity > 0.0
        and _MINIMUM_STEADY_SLIDE_EFFECTIVE_TO_AUTHORED_RATIO
        <= effective_to_authored
        <= _MAXIMUM_STEADY_SLIDE_EFFECTIVE_TO_AUTHORED_RATIO,
        "MUJOCO_HC1_STEADY_SLIDE_ENVELOPE",
        (
            f"mu={authored_friction:.12g} "
            f"ratio={effective_to_authored:.12g}"
        ),
    )
    return {
        "ok": True,
        "authored_friction": authored_friction,
        "initial_forward_velocity_m_s": (
            _STEADY_SLIDE_INITIAL_VELOCITY_M_S
        ),
        "final_forward_velocity_m_s": final_velocity,
        "observation_steps": _STEADY_SLIDE_STEPS,
        "elapsed_s": elapsed,
        "forward_displacement_m": (
            float(data.xpos[sled_body_id, 0]) - start_x
        ),
        "effective_sliding_friction": effective_friction,
        "effective_to_authored_ratio": effective_to_authored,
        "failure_codes": [],
        "world_attempt_count": 1,
        "world_build_count": 1,
    }


def _failure_text(error: Exception) -> str:
    message = str(error)
    return message if message else type(error).__name__


def _failed_breakaway_trial(
    authored_friction: float,
    force_ratio: float,
    error: Exception,
) -> dict[str, Any]:
    return {
        "ok": False,
        "authored_friction": authored_friction,
        "force_ratio_to_authored_coulomb_limit": force_ratio,
        "failure_codes": [_failure_text(error)],
        "world_attempt_count": 1,
        "world_build_count": 0,
    }


def _failed_steady_slide_trial(
    authored_friction: float,
    error: Exception,
) -> dict[str, Any]:
    return {
        "ok": False,
        "authored_friction": authored_friction,
        "failure_codes": [_failure_text(error)],
        "world_attempt_count": 1,
        "world_build_count": 0,
    }


def _material_profile(authored_friction: float) -> dict[str, Any]:
    trials = []
    for force_ratio in _BREAKAWAY_FORCE_RATIOS:
        try:
            trial = _breakaway_trial(authored_friction, force_ratio)
        except Exception as error:
            trial = _failed_breakaway_trial(
                authored_friction,
                force_ratio,
                error,
            )
        trials.append(trial)
    try:
        steady_slide = _steady_slide_trial(authored_friction)
    except Exception as error:
        steady_slide = _failed_steady_slide_trial(
            authored_friction,
            error,
        )

    breakaway_cells_ok = all(bool(trial["ok"]) for trial in trials)
    steady_slide_ok = bool(steady_slide["ok"])
    failure_codes: list[str] = []
    monotonic = False
    characterized = False
    lower_ratio: float | None = None
    upper_ratio: float | None = None

    if not breakaway_cells_ok:
        failure_codes.append(
            "MUJOCO_HC1_BREAKAWAY_CELL_FAILURES:"
            f"mu={authored_friction:.12g}"
        )
    else:
        outcomes = [bool(trial["broke_away"]) for trial in trials]
        monotonic = all(
            not earlier or later
            for earlier, later in zip(outcomes, outcomes[1:])
        )
        if not monotonic:
            failure_codes.append(
                "MUJOCO_HC1_BREAKAWAY_NONMONOTONIC:"
                f"mu={authored_friction:.12g}"
            )
        try:
            first_breakaway_index = outcomes.index(True)
        except ValueError:
            failure_codes.append(
                "MUJOCO_HC1_BREAKAWAY_UPPER_BRACKET_MISSING:"
                f"mu={authored_friction:.12g}"
            )
        else:
            if first_breakaway_index == 0:
                failure_codes.append(
                    "MUJOCO_HC1_BREAKAWAY_LOWER_BRACKET_MISSING:"
                    f"mu={authored_friction:.12g}"
                )
            else:
                lower_ratio = _BREAKAWAY_FORCE_RATIOS[
                    first_breakaway_index - 1
                ]
                upper_ratio = _BREAKAWAY_FORCE_RATIOS[
                    first_breakaway_index
                ]
                if (
                    lower_ratio < _MINIMUM_BREAKAWAY_LOWER_RATIO
                    or upper_ratio > _MAXIMUM_BREAKAWAY_UPPER_RATIO
                    or upper_ratio - lower_ratio
                    > _MAXIMUM_BREAKAWAY_BRACKET_WIDTH_RATIO
                    + math.ulp(_MAXIMUM_BREAKAWAY_BRACKET_WIDTH_RATIO)
                ):
                    failure_codes.append(
                        "MUJOCO_HC1_BREAKAWAY_BRACKET_ENVELOPE:"
                        f"mu={authored_friction:.12g} "
                        f"lower={lower_ratio:.12g} "
                        f"upper={upper_ratio:.12g}"
                    )
                elif monotonic:
                    characterized = True
    if not steady_slide_ok:
        failure_codes.append(
            "MUJOCO_HC1_STEADY_SLIDE_CELL_FAILURE:"
            f"mu={authored_friction:.12g}"
        )
    world_build_count = sum(
        int(trial["world_build_count"]) for trial in trials
    ) + int(steady_slide["world_build_count"])
    ok = (
        not failure_codes
        and characterized
        and steady_slide_ok
    )
    return {
        "ok": ok,
        "authored_friction": authored_friction,
        "ground_and_sled_friction_vectors_equal": True,
        "friction_cone": "elliptic",
        "integrator": "Euler",
        "geom_priority": 1,
        "torsional_friction": 0.0,
        "rolling_friction": 0.0,
        "breakaway": {
            "trials": trials,
            "nonbreaking_lower_ratio": lower_ratio,
            "breaking_upper_ratio": upper_ratio,
            "bracket_width_ratio": (
                upper_ratio - lower_ratio
                if lower_ratio is not None and upper_ratio is not None
                else None
            ),
            "monotonic": monotonic,
            "characterized": characterized,
        },
        "steady_slide": steady_slide,
        "failure_codes": failure_codes,
        "world_attempt_count": len(_BREAKAWAY_FORCE_RATIOS) + 1,
        "world_build_count": world_build_count,
        "physical_acceptance_authority": False,
    }


def _actuator_cell(
    target_position: float,
    maximum_step_impulse: float,
) -> dict[str, Any]:
    maximum_force = _maximum_impulse_to_force(
        maximum_step_impulse,
        MUJOCO_DT_S,
    )
    xml = f"""
<mujoco model="sporespore_mujoco_hc1_actuator">
  <compiler angle="radian" inertiafromgeom="true"/>
  {_option_xml("0 0 0", integrator="implicitfast")}
  <worldbody>
    <body name="actuator_child">
      <joint name="hinge" type="hinge" axis="1 0 0"
             limited="true" range="-1 1" armature="0"/>
      <geom type="box" size=".2 .2 .2" mass="1"
            contype="0" conaffinity="0"/>
    </body>
  </worldbody>
  <actuator>
    <position name="motor" joint="hinge"
              kp="{_ACTUATOR_STIFFNESS_NM_PER_RAD:.17g}"
              kv="{_ACTUATOR_DAMPING_NM_S_PER_RAD:.17g}"
              forcelimited="true"
              forcerange="{-maximum_force} {maximum_force}"/>
  </actuator>
</mujoco>
"""
    model = mujoco.MjModel.from_xml_string(xml)
    data = mujoco.MjData(model)
    child_body_id = model.body("actuator_child").id
    measured_child_mass = float(model.body_mass[child_body_id])
    measured_child_inertia = tuple(
        float(value) for value in model.body_inertia[child_body_id]
    )
    _require(
        abs(measured_child_mass - _ACTUATOR_CHILD_MASS_KG)
        <= _ACTUATOR_CHILD_MASS_TOLERANCE_KG,
        "MUJOCO_HC1_R1_ACTUATOR_CHILD_MASS",
    )
    _require(
        all(value > 0.0 for value in measured_child_inertia)
        and all(
            abs(observed - expected)
            <= _ACTUATOR_CHILD_INERTIA_TOLERANCE_KG_M2
            for observed, expected in zip(
                measured_child_inertia,
                _ACTUATOR_CHILD_EXPECTED_PRINCIPAL_INERTIA_KG_M2,
            )
        ),
        "MUJOCO_HC1_R1_ACTUATOR_CHILD_INERTIA",
    )
    data.ctrl[0] = target_position
    maximum_observed_force = 0.0
    maximum_observed_impulse = 0.0
    maximum_absolute_position = 0.0
    for _ in range(_ACTUATOR_STEPS):
        mujoco.mj_step(model, data)
        force = abs(float(data.actuator_force[0]))
        impulse = force * MUJOCO_DT_S
        maximum_observed_force = max(maximum_observed_force, force)
        maximum_observed_impulse = max(
            maximum_observed_impulse,
            impulse,
        )
        maximum_absolute_position = max(
            maximum_absolute_position,
            abs(float(data.qpos[0])),
        )
        _require(
            impulse
            <= maximum_step_impulse + _MAXIMUM_IMPULSE_TOLERANCE_NMS,
            "MUJOCO_HC1_PER_STEP_IMPULSE_LIMIT_EXCEEDED",
        )
    final_position = float(data.qpos[0])
    final_error = abs(final_position - target_position)
    _require(
        all(
            math.isfinite(value)
            for value in (
                final_position,
                final_error,
                maximum_observed_force,
                maximum_observed_impulse,
                maximum_absolute_position,
            )
        ),
        "MUJOCO_HC1_ACTUATOR_NONFINITE",
    )
    _require(
        final_error <= _MAXIMUM_FINAL_POSITION_ERROR_RAD,
        "MUJOCO_HC1_ACTUATOR_TRACKING",
        (
            f"target={target_position:.12g} "
            f"observed={final_position:.12g} error={final_error:.12g}"
        ),
    )
    return {
        "ok": True,
        "actuator_model": "mujoco_position_servo_force_limited",
        "integrator": "implicitfast",
        "target_position_rad": target_position,
        "target_velocity_rad_s": _ACTUATOR_TARGET_VELOCITY_RAD_S,
        "child_shape": "cuboid",
        "child_half_extents_m": list(_ACTUATOR_CHILD_HALF_EXTENTS_M),
        "child_mass_properties_source": (
            "shape_derived_from_nonzero_mass_collider"
        ),
        "measured_child_mass_kg": measured_child_mass,
        "measured_child_principal_inertia_kg_m2": list(
            measured_child_inertia
        ),
        "final_position_rad": final_position,
        "final_absolute_position_error_rad": final_error,
        "maximum_absolute_position_rad": maximum_absolute_position,
        "maximum_step_impulse_nms": maximum_step_impulse,
        "mapped_maximum_force_nm": maximum_force,
        "maximum_observed_force_nm": maximum_observed_force,
        "maximum_observed_derived_step_impulse_nms": (
            maximum_observed_impulse
        ),
        "mapping_rule": (
            "force_limit_nm = maximum_step_impulse_nms / timestep_s"
        ),
        "failure_codes": [],
        "world_attempt_count": 1,
        "world_build_count": 1,
        "physical_acceptance_authority": False,
    }


def _failed_actuator_cell(
    target_position: float,
    maximum_step_impulse: float,
    error: Exception,
) -> dict[str, Any]:
    return {
        "ok": False,
        "actuator_model": "mujoco_position_servo_force_limited",
        "integrator": "implicitfast",
        "target_position_rad": target_position,
        "target_velocity_rad_s": _ACTUATOR_TARGET_VELOCITY_RAD_S,
        "child_shape": "cuboid",
        "child_half_extents_m": list(_ACTUATOR_CHILD_HALF_EXTENTS_M),
        "child_mass_properties_source": (
            "shape_derived_from_nonzero_mass_collider"
        ),
        "maximum_step_impulse_nms": maximum_step_impulse,
        "failure_codes": [_failure_text(error)],
        "world_attempt_count": 1,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def _count_nonfinite_failure_codes(value: Any) -> int:
    if isinstance(value, dict):
        return sum(
            _count_nonfinite_failure_codes(item)
            for item in value.values()
        )
    if isinstance(value, list):
        return sum(_count_nonfinite_failure_codes(item) for item in value)
    if isinstance(value, str):
        return int("NONFINITE" in value)
    return 0


def run_host_characterization(source_commit: str) -> dict[str, Any]:
    """Run the complete frozen physical grid after its zero-world preflight."""

    preflight = run_host_characterization_preflight()
    _require(
        len(source_commit) == 40
        and all(
            character in "0123456789abcdefABCDEF"
            for character in source_commit
        ),
        "MUJOCO_HC1_SOURCE_COMMIT_INVALID",
    )
    (
        base_preregistration,
        r1_preregistration,
        preregistration,
    ) = _preregistration()
    material_profiles = [
        _material_profile(authored_friction)
        for authored_friction in _AUTHORED_FRICTIONS
    ]
    actuator_cells = []
    for target in _ACTUATOR_TARGETS_RAD:
        for maximum_impulse in _ACTUATOR_MAXIMUM_STEP_IMPULSES_NMS:
            try:
                cell = _actuator_cell(target, maximum_impulse)
            except Exception as error:
                cell = _failed_actuator_cell(
                    target,
                    maximum_impulse,
                    error,
                )
            actuator_cells.append(cell)

    breakaway_trials = [
        trial
        for profile in material_profiles
        for trial in profile["breakaway"]["trials"]
    ]
    steady_slide_trials = [
        profile["steady_slide"] for profile in material_profiles
    ]
    failed_material_profiles = sum(
        not bool(profile["ok"]) for profile in material_profiles
    )
    failed_breakaway_trials = sum(
        not bool(trial["ok"]) for trial in breakaway_trials
    )
    failed_steady_slide_trials = sum(
        not bool(trial["ok"]) for trial in steady_slide_trials
    )
    failed_actuator_cells = sum(
        not bool(cell["ok"]) for cell in actuator_cells
    )
    nonfinite_observation_count = sum(
        _count_nonfinite_failure_codes(profile)
        for profile in material_profiles
    ) + sum(
        _count_nonfinite_failure_codes(cell)
        for cell in actuator_cells
    )
    summary = {
        "expected_material_profile_count": len(_AUTHORED_FRICTIONS),
        "observed_material_profile_count": len(material_profiles),
        "expected_breakaway_trial_count": (
            len(_AUTHORED_FRICTIONS) * len(_BREAKAWAY_FORCE_RATIOS)
        ),
        "observed_breakaway_trial_count": len(breakaway_trials),
        "expected_steady_slide_trial_count": len(_AUTHORED_FRICTIONS),
        "observed_steady_slide_trial_count": len(steady_slide_trials),
        "expected_actuator_cell_count": (
            len(_ACTUATOR_TARGETS_RAD)
            * len(_ACTUATOR_MAXIMUM_STEP_IMPULSES_NMS)
        ),
        "observed_actuator_cell_count": len(actuator_cells),
        "failed_material_profile_count": failed_material_profiles,
        "failed_breakaway_trial_count": failed_breakaway_trials,
        "failed_steady_slide_trial_count": failed_steady_slide_trials,
        "failed_actuator_cell_count": failed_actuator_cells,
        "source_mismatch_count": 0,
        "nonfinite_observation_count": nonfinite_observation_count,
    }
    total_world_attempt_count = sum(
        int(profile["world_attempt_count"])
        for profile in material_profiles
    ) + sum(int(cell["world_attempt_count"]) for cell in actuator_cells)
    total_world_build_count = sum(
        int(profile["world_build_count"])
        for profile in material_profiles
    ) + sum(int(cell["world_build_count"]) for cell in actuator_cells)
    integrity_failure_codes = []
    try:
        _validate_integrity_summary(summary)
    except ConformanceFailure:
        integrity_failure_codes.append("MUJOCO_HC1_INTEGRITY_GATE")
    if total_world_attempt_count != 28:
        integrity_failure_codes.append(
            "MUJOCO_HC1_WORLD_ATTEMPT_COUNT"
        )
    if total_world_build_count != 28:
        integrity_failure_codes.append(
            "MUJOCO_HC1_WORLD_BUILD_COUNT"
        )
    material_complete = failed_material_profiles == 0
    actuator_complete = failed_actuator_cells == 0
    ok = (
        not integrity_failure_codes
        and material_complete
        and actuator_complete
    )
    return {
        "schema_version": (
            "sporespore_mujoco_c6_host_characterization_r2_report_v1"
        ),
        "ok": ok,
        "campaign_id": "C6-HOST-CHARACTERIZATION-R2",
        "gate_id": "C6-HC1-R2",
        "source": {
            "commit": source_commit,
            "clean": True,
            "matches_origin_main": True,
        },
        "adapter_id": ADAPTER_ID,
        "adapter_manifest": capability_manifest(),
        "adapter_manifest_sha256": capability_manifest_sha256(),
        "mujoco_version": mujoco.__version__,
        "numpy_version": np.__version__,
        "preregistration": {
            "schema_version": preregistration["schema_version"],
            "status": preregistration["status"],
            "raw_sha256": _preregistration_raw_sha256(),
            "base_schema_version": base_preregistration["schema_version"],
            "base_raw_sha256": _BASE_PREREGISTRATION_RAW_SHA256,
            "predecessor_closure_raw_sha256": (
                _PREDECESSOR_CLOSURE_RAW_SHA256
            ),
            "r1_schema_version": r1_preregistration["schema_version"],
            "r1_raw_sha256": _R1_PREREGISTRATION_RAW_SHA256,
            "r1_closure_raw_sha256": _R1_CLOSURE_RAW_SHA256,
        },
        "preflight": preflight,
        "integrity_summary": summary,
        "integrity_failure_codes": integrity_failure_codes,
        "material_profiles": material_profiles,
        "actuator_cells": actuator_cells,
        "material_characterization_complete_for_declared_grid": (
            material_complete
        ),
        "actuator_characterization_complete_for_declared_grid": (
            actuator_complete
        ),
        "world_attempt_count": total_world_attempt_count,
        "world_build_count": total_world_build_count,
        "controller_policy_authority": False,
        "selected_policy_physical_authority": False,
        "cross_engine_c6": False,
        "different_physics_engines": False,
        "locomotion_acceptance": False,
        "material_robustness": False,
        "physical_acceptance_authority": False,
        "release_authorized": False,
        "completed_engine_neutral_sdk": False,
    }


def _retain(report: dict[str, Any], output: Path) -> None:
    output = output.resolve()
    _require(
        output.name == "report.json",
        "MUJOCO_HC1_OUTPUT_NAME",
    )
    _require(
        not output.exists(),
        "MUJOCO_HC1_OUTPUT_EXISTS",
        str(output),
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name("report.json.tmp")
    _require(
        not temporary.exists(),
        "MUJOCO_HC1_TEMPORARY_OUTPUT_EXISTS",
        str(temporary),
    )
    serialized = json.dumps(
        report,
        allow_nan=False,
        ensure_ascii=False,
        indent=2,
        sort_keys=True,
    )
    temporary.write_text(
        serialized + "\n",
        encoding="utf-8",
        newline="\n",
    )
    os.replace(temporary, output)


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preflight-only", action="store_true")
    mode.add_argument("--source-commit")
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    if arguments.preflight_only:
        _require(
            arguments.output is None,
            "MUJOCO_HC1_PREFLIGHT_OUTPUT_FORBIDDEN",
        )
        report = run_host_characterization_preflight()
    else:
        report = run_host_characterization(arguments.source_commit)
        if arguments.output is not None:
            _retain(report, arguments.output)
    print(
        json.dumps(
            report,
            allow_nan=False,
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        )
    )
    if not bool(report["ok"]):
        print(
            "MuJoCo C6-HC1-R2 characterization retained a complete "
            "negative report",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
