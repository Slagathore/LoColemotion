"""Prospective exact-s169 MuJoCo BW19V selected-policy walking successor.

MV2 is deliberately finite: one deterministic body, host, controller,
composition, material, initialization, and 2,992-step LC1 schedule.  Its
evaluator recomputes the physical and integrity decision from the ordered
per-step trace.  Before any MuJoCo model can exist, its preflight passes the
exact characterized profile through the real Rust dynamic library and rejects
two profile-identity defects.  It does not test a population or cross-engine
equivalence.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

import mujoco
import numpy as np

from . import selected_policy_development as bridge
from sporespore_locomotion import LocomotionCoreError
from .velocity_only_stability_characterization_vh4 import (
    INTERNAL_DT_S,
    INTERNAL_STEPS_PER_OUTER,
)


CAMPAIGN_ID = "C6-MUJOCO-BW19V-SELECTED-POLICY-WALKING-MV2"
GATE_ID = "C6-MJC-BW19V-MV2"
REPORT_SCHEMA = "sporespore_mujoco_c6_bw19v_selected_policy_walking_mv2_report_v1"
TRACE_SCHEMA = "sporespore_mujoco_c6_bw19v_selected_policy_walking_mv2_trace_step_v1"
PREFLIGHT_SCHEMA = "sporespore_mujoco_c6_bw19v_selected_policy_walking_mv2_preflight_v1"
PROFILE_ID = bridge.PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID

SDK_ROOT = Path(__file__).resolve().parents[3]
PREREGISTRATION_PATH = SDK_ROOT / "mujoco_c6_bw19v_selected_policy_walking_mv2_preregistration.json"
VH5_CLOSURE_PATH = SDK_ROOT / "mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.json"
RAPIER_LC1_PREREGISTRATION_PATH = SDK_ROOT / "rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_preregistration.json"
MV1_CLOSURE_PATH = SDK_ROOT / "mujoco_c6_bw19v_selected_policy_walking_mv1_closure.json"
CORE_CANONICAL_ACTUATION_PATH = SDK_ROOT / "core" / "src" / "canonical_actuation.rs"
PYTHON_CORE_WRAPPER_PATH = SDK_ROOT / "python" / "sporespore_locomotion.py"
EXPECTED_RELEASE_LIBRARY_PATH = (
    SDK_ROOT / "target" / "release" / "sporespore_locomotion_core.dll"
).resolve()

# Patched only after the declaration is frozen.  The declaration does not
# contain this implementation hash, avoiding a circular source identity.
EXPECTED_PREREGISTRATION_SHA256 = "sha256:b9cb8910e74e8baf030296ed52576d1ef580183b477faedb1f6331bc3e6ed31b"
EXPECTED_VH5_CLOSURE_SHA256 = "sha256:fbb8441fb8a3907c56155db777de00ce8b6e2f293ef67e77a2a30d2eeeb0f34f"
EXPECTED_VH5_REPORT_SHA256 = "sha256:305b3b462ec463278eedd526d28f32abdde3d0eaff919a3d52b179f6590deb96"
EXPECTED_RAPIER_LC1_PREREGISTRATION_SHA256 = "sha256:a5e88d5e0f69772c7dec67cc0d8bd83aa903ab2fe642a301fbf8ed3f09b47d0b"
EXPECTED_MV1_CLOSURE_SHA256 = "sha256:97ea7d0cf1ebc1b48a7a508cf5cc41d9f8a7c1609b450a3ef9dea3b57c503e77"
EXPECTED_CORE_CANONICAL_ACTUATION_SHA256 = "sha256:e2d7e27edaf7caa218d95a5ed7966f5c6d317ff8c5990c5cd0e2876e1d485d05"
EXPECTED_PYTHON_CORE_WRAPPER_SHA256 = "sha256:53e9be5f192f1424bd2d6c22aeecb563b8d7ed0ae3931901c2dcd576ee1160f7"
EXPECTED_PREWORLD_DESCRIPTOR_SHA256 = "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0"
EXPECTED_PREWORLD_MAPPING_RECEIPT_SHA256 = "sha256:faf7d0a32314e51cc671cdc8ae86ed6af2d214152a6348245ee77fef8aba63a7"

TOTAL_STEPS = 2_992
CLOCKED_STEPS = 472
EVIDENCE_GAIT_STEPS = 1_440
MAXIMUM_EVIDENCE_EXTENSION_STEPS = 720
EVIDENCE_DEADLINE_EXCLUSIVE = 2_632
REQUIRED_POST_EVIDENCE_STEPS = 360
ACTUATOR_COUNT = 8
COMMANDS_PER_LAYER = TOTAL_STEPS * ACTUATOR_COUNT

# Inherited byte-for-value from the prospectively frozen Rapier LC1 contract.
MINIMUM_EVIDENCE_ADVANCE_M = 0.0401640625
MINIMUM_FINAL_ADVANCE_M = 0.030123046875
MAXIMUM_LATERAL_DRIFT_M = 0.10031893004115228
MAXIMUM_YAW_DRIFT_RAD = 0.45
MAXIMUM_TILT_RAD = 0.6
MINIMUM_TORSO_HEIGHT_M = 0.2499708652072946
MINIMUM_CONTACT_CYCLES_PER_LIMB = 2
MINIMUM_AIRBORNE_DWELL_STEPS = 3
MINIMUM_FOOT_RELOCATION_M = 0.01194880859375

POLICY_DIGEST = "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
CANDIDATE_COMPOSITION_DIGEST = "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77"
S169_RUNTIME_PROFILE_SHA256 = "sha256:312957dedabd3bd0eb7160c5cc69c7788bc7927acaedc42dc609a781f9c6c7db"

ZERO_INTEGRITY_FIELDS = (
    "controller_error_count",
    "safe_no_actuation_count",
    "composition_error_count",
    "nonfinite_observation_count",
    "actuator_application_mismatch_count",
    "host_mapping_or_readback_mismatch_count",
    "portable_impulse_limit_violation_count",
    "native_position_target_application_count",
    "global_scale_mismatch_count",
)


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _digest(value: Any) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _finite(value: Any) -> bool:
    return isinstance(value, (int, float)) and math.isfinite(float(value))


def _close(left: Any, right: Any, tolerance: float = 1.0e-9) -> bool:
    return _finite(left) and _finite(right) and abs(float(left) - float(right)) <= tolerance


def _authorities() -> dict[str, Any]:
    if _raw_sha256(PREREGISTRATION_PATH) != EXPECTED_PREREGISTRATION_SHA256:
        raise RuntimeError("C6_MJC_BW19V_MV2_PREREGISTRATION_HASH")
    if _raw_sha256(VH5_CLOSURE_PATH) != EXPECTED_VH5_CLOSURE_SHA256:
        raise RuntimeError("C6_MJC_BW19V_MV2_VH5_CLOSURE_HASH")
    if _raw_sha256(RAPIER_LC1_PREREGISTRATION_PATH) != EXPECTED_RAPIER_LC1_PREREGISTRATION_SHA256:
        raise RuntimeError("C6_MJC_BW19V_MV2_THRESHOLD_SOURCE_HASH")
    if _raw_sha256(MV1_CLOSURE_PATH) != EXPECTED_MV1_CLOSURE_SHA256:
        raise RuntimeError("C6_MJC_BW19V_MV2_MV1_CLOSURE_HASH")
    if _raw_sha256(CORE_CANONICAL_ACTUATION_PATH) != EXPECTED_CORE_CANONICAL_ACTUATION_SHA256:
        raise RuntimeError("C6_MJC_BW19V_MV2_CORE_PROFILE_REGISTRY_HASH")
    if _raw_sha256(PYTHON_CORE_WRAPPER_PATH) != EXPECTED_PYTHON_CORE_WRAPPER_SHA256:
        raise RuntimeError("C6_MJC_BW19V_MV2_PYTHON_CORE_WRAPPER_HASH")
    declaration = json.loads(PREREGISTRATION_PATH.read_text(encoding="utf-8"))
    vh5 = json.loads(VH5_CLOSURE_PATH.read_text(encoding="utf-8"))
    lc1 = json.loads(RAPIER_LC1_PREREGISTRATION_PATH.read_text(encoding="utf-8"))
    mv1 = json.loads(MV1_CLOSURE_PATH.read_text(encoding="utf-8"))
    report_file = next(
        item for item in vh5["physical_evidence"]["files"] if item["name"] == "report.json"
    )
    if (
        declaration["campaign_id"] != CAMPAIGN_ID
        or declaration["gate_id"] != GATE_ID
        or declaration["frozen_host_identity"]["profile_id"] != PROFILE_ID
        or vh5["status"]
        != "closed_complete_valid_positive_exact_finite_s169_per_actuator_host_characterization"
        or not vh5["technical_disposition"][
            "scientific_positive_exact_finite_s169_per_actuator_host_characterization"
        ]
        or "sha256:" + report_file["raw_sha256"] != EXPECTED_VH5_REPORT_SHA256
        or mv1["status"] != "closed_consumed_implementation_invalid_no_physical_report"
        or mv1["technical_disposition"]["scientific_positive"]
        or mv1["technical_disposition"]["scientific_negative"]
        or mv1["technical_disposition"]["walking_evaluated"]
        or not mv1["immutability"]["same_identity_rerun_forbidden"]
        or not mv1["immutability"]["successor_requires_new_identity"]
        or not mv1["next_allowed_work"]["add_zero_world_real_dynamic_library_profile_mapping_canary"]
    ):
        raise RuntimeError("C6_MJC_BW19V_MV2_AUTHORITY_CONTENT")
    inherited_thresholds = {
        key: lc1["walking_thresholds"][key]
        for key in declaration["walking_thresholds"]
        if key != "provenance"
    }
    declared_thresholds = {
        key: value
        for key, value in declaration["walking_thresholds"].items()
        if key != "provenance"
    }
    if inherited_thresholds != declared_thresholds:
        raise RuntimeError("C6_MJC_BW19V_MV2_THRESHOLD_CONTENT")
    return {
        "declaration": declaration,
        "vh5": vh5,
        "rapier_lc1": lc1,
        "mv1": mv1,
    }


def _real_dynamic_library_profile_canary() -> dict[str, Any]:
    """Cross the real Rust ABI before constructing any MuJoCo model or data."""

    core = bridge.LocomotionCore()
    library_path = core.library_path.resolve()
    descriptor = bridge.s169_descriptor()
    compiled = core.compile_bounded_quadruped(descriptor)
    morphology = compiled["morphology"]
    ordered_actuator_ids = list(morphology["ordered_actuator_ids"])
    request = {
        "schema_version": "sporespore_candidate35_step_request_v1",
        "descriptor": descriptor,
        "memory": core.balanced_wave_initial_memory(),
        "state": {
            "schema_version": "sporespore_state_frame_v1",
            "semantic_step": 0,
            "sample_time_s": 0.0,
            "base_pose_world": {
                "position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
                "orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
            },
            "base_twist_world": {
                "linear_velocity_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
                "angular_velocity_rad_s": {"x": 0.0, "y": 0.0, "z": 0.0},
            },
            "ordered_joint_observations": [
                {
                    "joint_id": joint_id,
                    "position_rad": 0.0,
                    "velocity_rad_s": 0.0,
                    "anchor_error_m": 0.0,
                    "validity": {
                        "position": True,
                        "velocity": True,
                        "anchor_error": True,
                    },
                }
                for joint_id in morphology["ordered_joint_ids"]
            ],
            "ordered_contact_observations": [
                {
                    "contact_site_id": contact_id,
                    "presence": True,
                    "bears_support": True,
                    "normal_load_n": None,
                    "provenance": {
                        "adapter_id": bridge.ADAPTER_ID,
                        "engine_contact_ids": [f"{contact_id}_zero_world_canary"],
                        "aggregation_rule_id": "qualified_bearing_only",
                        "quality": "qualified_bearing",
                    },
                }
                for contact_id in morphology["ordered_contact_site_ids"]
            ],
            "previous_applied_actuation": None,
            "gravity_world_m_s2": {"x": 0.0, "y": -9.81, "z": 0.0},
            "task_frame": {
                "origin_world_m": {"x": 0.0, "y": 0.0, "z": 0.0},
                "forward_axis_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
                "lateral_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
                "up_axis_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
                "reference_yaw_rad": 0.0,
            },
            "adapter_capability_sha256": bridge.capability_manifest_sha256(),
        },
        "command": {
            **bridge._motion_command(0, "contact_gated"),
            "command_id": "mujoco_mv2_zero_world_real_dynamic_library_canary",
        },
    }
    actuation = core.balanced_wave_policy_step(
        bridge.SELECTED_POLICY_ID,
        request,
    )["actuation"]
    residuals = [
        {
            "schema_version": "sporespore_canonical_velocity_residual_v1",
            "actuator_id": command["actuator_id"],
            "canonical_velocity_delta_rad_s": 0.01 if index % 2 == 0 else -0.01,
            "command_not_measurement": True,
            "physical_acceptance_authority": False,
        }
        for index, command in enumerate(actuation["ordered_commands"])
    ]
    canonical = core.canonical_velocity_compose_v1(
        {
            "schema_version": "sporespore_canonical_velocity_compose_request_v1",
            "descriptor": descriptor,
            "source_actuation": actuation,
            "ordered_stability_residuals": residuals,
        }
    )
    mapping_request = {
        "schema_version": "sporespore_canonical_velocity_host_map_request_v1",
        "descriptor": descriptor,
        "canonical_actuation": canonical,
        "host_profile": bridge._mujoco_host_profile(PROFILE_ID),
    }
    mapped = core.canonical_velocity_host_map_v1(mapping_request)

    negative_controls_rejected: dict[str, bool] = {}
    negative_control_failure_codes: dict[str, str | None] = {}
    for name, field, invalid_value in (
        ("false_characterization", "host_response_characterized_for_this_profile", False),
        ("wrong_native_motor_model", "native_motor_model_id", "wrong_native_motor_model"),
    ):
        invalid_request = copy.deepcopy(mapping_request)
        invalid_request["host_profile"][field] = invalid_value
        try:
            core.canonical_velocity_host_map_v1(invalid_request)
        except LocomotionCoreError as error:
            negative_controls_rejected[name] = error.failure_code == "ACTUATION_INVALID"
            negative_control_failure_codes[name] = error.failure_code
        else:
            negative_controls_rejected[name] = False
            negative_control_failure_codes[name] = None

    ordered_mapping_ids = [
        command["actuator_id"] for command in mapped["ordered_commands"]
    ]
    positive_mapping_passed = (
        mapped["host_profile_id"] == PROFILE_ID
        and mapped["adapter_id"] == bridge.ADAPTER_ID
        and mapped["engine_id"] == "mujoco"
        and mapped["host_response_characterized_for_this_profile"] is True
        and ordered_mapping_ids == ordered_actuator_ids
        and len(ordered_mapping_ids) == ACTUATOR_COUNT
        and all(
            command["native_target_position_rad"] is None
            for command in mapped["ordered_commands"]
        )
        and mapped["world_build_count"] == 0
        and mapped["physics_state_modified"] is False
        and mapped["physical_acceptance_authority"] is False
    )
    exact_release_library_loaded = library_path == EXPECTED_RELEASE_LIBRARY_PATH
    ok = (
        exact_release_library_loaded
        and positive_mapping_passed
        and len(negative_controls_rejected) == 2
        and all(negative_controls_rejected.values())
    )
    return {
        "schema_version": "sporespore_mujoco_mv2_real_dynamic_library_profile_canary_v1",
        "ok": ok,
        "library_path": library_path.as_posix(),
        "library_raw_sha256": _raw_sha256(library_path),
        "exact_release_library_loaded": exact_release_library_loaded,
        "core_version": core.version,
        "descriptor_sha256": compiled["descriptor_sha256"],
        "host_profile_id": PROFILE_ID,
        "ordered_actuator_ids": ordered_actuator_ids,
        "positive_mapping_passed": positive_mapping_passed,
        "positive_mapping_receipt": mapped,
        "positive_mapping_receipt_sha256": _digest(mapped),
        "negative_control_count": len(negative_controls_rejected),
        "negative_controls_rejected": negative_controls_rejected,
        "negative_control_failure_codes": negative_control_failure_codes,
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_modified": False,
        "locomotion_outcome_exposed": False,
        "physical_acceptance_authority": False,
    }


def _preworld_dynamic_canary_failures(canary: Any) -> list[str]:
    failures: list[str] = []
    if not isinstance(canary, dict):
        return ["C6_MJC_BW19V_MV2_PREWORLD_DYNAMIC_CANARY_TYPE"]
    expected_scalars = {
        "schema_version": "sporespore_mujoco_mv2_real_dynamic_library_profile_canary_v1",
        "ok": True,
        "library_path": EXPECTED_RELEASE_LIBRARY_PATH.as_posix(),
        "exact_release_library_loaded": True,
        "core_version": "0.1.0",
        "descriptor_sha256": EXPECTED_PREWORLD_DESCRIPTOR_SHA256,
        "host_profile_id": PROFILE_ID,
        "positive_mapping_passed": True,
        "positive_mapping_receipt_sha256": EXPECTED_PREWORLD_MAPPING_RECEIPT_SHA256,
        "negative_control_count": 2,
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_modified": False,
        "locomotion_outcome_exposed": False,
        "physical_acceptance_authority": False,
    }
    for key, expected in expected_scalars.items():
        if canary.get(key) != expected:
            _push(failures, f"C6_MJC_BW19V_MV2_PREWORLD_DYNAMIC_CANARY:{key}")
    library_hash = canary.get("library_raw_sha256")
    if (
        not isinstance(library_hash, str)
        or len(library_hash) != 71
        or not library_hash.startswith("sha256:")
        or any(character not in "0123456789abcdef" for character in library_hash[7:])
    ):
        _push(failures, "C6_MJC_BW19V_MV2_PREWORLD_DYNAMIC_CANARY:library_raw_sha256")
    ordered_ids = canary.get("ordered_actuator_ids")
    mapping = canary.get("positive_mapping_receipt")
    mapping_commands = mapping.get("ordered_commands") if isinstance(mapping, dict) else None
    if (
        not isinstance(ordered_ids, list)
        or len(ordered_ids) != ACTUATOR_COUNT
        or len(set(ordered_ids)) != ACTUATOR_COUNT
        or not isinstance(mapping, dict)
        or not isinstance(mapping_commands, list)
        or len(mapping_commands) != ACTUATOR_COUNT
        or any(not isinstance(item, dict) for item in mapping_commands)
        or mapping.get("host_profile_id") != PROFILE_ID
        or mapping.get("adapter_id") != bridge.ADAPTER_ID
        or mapping.get("engine_id") != "mujoco"
        or mapping.get("host_response_characterized_for_this_profile") is not True
        or mapping.get("world_build_count") != 0
        or mapping.get("physics_state_modified") is not False
        or mapping.get("physical_acceptance_authority") is not False
        or [item.get("actuator_id") for item in mapping_commands]
        != ordered_ids
        or any(
            item.get("native_target_position_rad") is not None
            for item in mapping_commands
        )
        or canary.get("positive_mapping_receipt_sha256") != _digest(mapping)
    ):
        _push(failures, "C6_MJC_BW19V_MV2_PREWORLD_DYNAMIC_CANARY_MAPPING")
    if canary.get("negative_controls_rejected") != {
        "false_characterization": True,
        "wrong_native_motor_model": True,
    } or canary.get("negative_control_failure_codes") != {
        "false_characterization": "ACTUATION_INVALID",
        "wrong_native_motor_model": "ACTUATION_INVALID",
    }:
        _push(failures, "C6_MJC_BW19V_MV2_PREWORLD_DYNAMIC_CANARY_NEGATIVES")
    return failures


@dataclass
class FootEvidence:
    previous_contact: bool
    airborne_steps: int = 0
    maximum_airborne_dwell_steps: int = 0
    liftoff_position: np.ndarray | None = None
    contact_cycles: int = 0
    maximum_foot_relocation_m: float = 0.0

    def observe(self, contact: bool, position: list[float]) -> None:
        point = np.asarray(position, dtype=np.float64)
        if self.previous_contact and not contact:
            self.airborne_steps = 1
            self.maximum_airborne_dwell_steps = max(
                self.maximum_airborne_dwell_steps, self.airborne_steps
            )
            self.liftoff_position = point
        elif not self.previous_contact and not contact:
            self.airborne_steps += 1
            self.maximum_airborne_dwell_steps = max(
                self.maximum_airborne_dwell_steps, self.airborne_steps
            )
        elif not self.previous_contact and contact:
            self.maximum_airborne_dwell_steps = max(
                self.maximum_airborne_dwell_steps, self.airborne_steps
            )
            if self.airborne_steps >= MINIMUM_AIRBORNE_DWELL_STEPS:
                self.contact_cycles += 1
                if self.liftoff_position is not None:
                    self.maximum_foot_relocation_m = max(
                        self.maximum_foot_relocation_m,
                        float(np.linalg.norm(point - self.liftoff_position)),
                    )
            self.airborne_steps = 0
            self.liftoff_position = None
        self.previous_contact = contact

    def receipt(self) -> dict[str, Any]:
        return {
            "contact_cycles": self.contact_cycles,
            "maximum_foot_relocation_m": self.maximum_foot_relocation_m,
            "maximum_airborne_dwell_steps": self.maximum_airborne_dwell_steps,
        }


def _site_snapshot(robot: bridge.MujocoBw19vRobot) -> dict[str, Any]:
    contacts: dict[str, bool] = {}
    positions: dict[str, list[float]] = {}
    for site_id in robot.morphology["ordered_contact_site_ids"]:
        site = robot.contact_sites[site_id]
        contacts[site_id] = bool(robot._contact(site)["present"])
        positions[site_id] = [
            float(value) for value in bridge._mujoco_to_canonical(robot._site_world(site))
        ]
    return {"contacts": contacts, "site_positions_m": positions}


def _snapshot(robot: bridge.MujocoBw19vRobot) -> dict[str, Any]:
    torso = robot.torso_metrics()
    sites = _site_snapshot(robot)
    return {
        "torso_position_m": [float(torso[axis]) for axis in ("x", "y", "z")],
        "torso_tilt_rad": float(torso["tilt_rad"]),
        "torso_yaw_rad": float(torso["yaw_rad"]),
        "torso_ground_contact": bool(torso["ground_contact"]),
        "ordered_declared_contacts": sites["contacts"],
        "ordered_contact_site_positions_m": sites["site_positions_m"],
    }


def _limb_receipt(memory: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        {
            "limb_id": limb["limb_id"],
            "gait_step": int(limb["gait_step"]),
            "evidence_gait_step_limit": (
                None
                if limb.get("evidence_gait_step_limit") is None
                else int(limb["evidence_gait_step_limit"])
            ),
        }
        for limb in memory["ordered_limb_memory"]
    ]


def _claim_boundary(passed: bool) -> dict[str, bool]:
    return {
        "exact_s169_mujoco_bw19v_mv2_walking": passed,
        "finite_single_body_selected_policy_technical_commissioning": passed,
        "independent_validation": False,
        "population_inference": False,
        "cross_engine_selected_policy_equivalence": False,
        "arbitrary_quadruped_coverage": False,
        "continuous_morphology_coverage": False,
        "friction_material_or_terrain_robustness": False,
        "rough_terrain_robustness": False,
        "external_push_recovery": False,
        "sensor_noise_or_latency_robustness": False,
        "release_authorized": False,
        "completed_engine_neutral_sdk": False,
        "physical_acceptance_authority": False,
    }


def _push(failures: list[str], code: str) -> None:
    if code not in failures:
        failures.append(code)


def _evaluate_core(report: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    expected_identity = {
        "schema_version": REPORT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "study_class": "outcome_exposed_single_body_finite_technical_commissioning_decision",
        "engine": "mujoco",
        "engine_version": mujoco.__version__,
        "adapter_id": bridge.ADAPTER_ID,
        "candidate_id": bridge.SELECTED_CANDIDATE_ID,
        "candidate_composition_digest": CANDIDATE_COMPOSITION_DIGEST,
        "selected_policy_id": bridge.SELECTED_POLICY_ID,
        "selected_policy_digest": POLICY_DIGEST,
        "stability_policy_id": bridge.STABILITY_POLICY_ID,
        "runtime_profile_sha256": S169_RUNTIME_PROFILE_SHA256,
        "morphology_id": "qsdk_r05_generated_s169",
        "global_requested_correction_scale": bridge.GLOBAL_REQUESTED_CORRECTION_SCALE,
        "host_profile_id": PROFILE_ID,
        "preregistration_raw_sha256": EXPECTED_PREREGISTRATION_SHA256,
        "vh5_closure_raw_sha256": EXPECTED_VH5_CLOSURE_SHA256,
        "vh5_report_raw_sha256": EXPECTED_VH5_REPORT_SHA256,
        "threshold_source_raw_sha256": EXPECTED_RAPIER_LC1_PREREGISTRATION_SHA256,
        "mv1_closure_raw_sha256": EXPECTED_MV1_CLOSURE_SHA256,
    }
    for key, expected in expected_identity.items():
        if report.get(key) != expected:
            _push(failures, f"C6_MJC_BW19V_MV2_IDENTITY:{key}")
    for failure in _preworld_dynamic_canary_failures(
        report.get("preworld_real_dynamic_library_profile_canary")
    ):
        _push(failures, failure)
    if (
        not isinstance(report.get("source_commit"), str)
        or len(report["source_commit"]) != 40
        or any(character not in "0123456789abcdef" for character in report["source_commit"])
    ):
        _push(failures, "C6_MJC_BW19V_MV2_SOURCE_COMMIT")
    if report.get("world_attempt_count") != 1 or report.get("world_build_count") != 1:
        _push(failures, "C6_MJC_BW19V_MV2_WORLD_COUNT")
    if report.get("world_reset_count") != 0:
        _push(failures, "C6_MJC_BW19V_MV2_WORLD_RESET")
    for field in ZERO_INTEGRITY_FIELDS:
        if report.get(field) != 0:
            _push(failures, f"C6_MJC_BW19V_MV2_INTEGRITY:{field}")

    actuator_ids = report.get("ordered_actuator_ids")
    limb_ids = report.get("ordered_limb_ids")
    contact_ids = report.get("ordered_contact_site_ids")
    trace = report.get("ordered_trace")
    if (
        not isinstance(actuator_ids, list)
        or len(actuator_ids) != ACTUATOR_COUNT
        or len(set(actuator_ids)) != ACTUATOR_COUNT
        or not isinstance(limb_ids, list)
        or len(limb_ids) != 4
        or not isinstance(contact_ids, list)
        or len(contact_ids) != 4
        or not isinstance(trace, list)
        or len(trace) != TOTAL_STEPS
    ):
        _push(failures, "C6_MJC_BW19V_MV2_CARDINALITY")
        return failures

    initial = report.get("initial_snapshot", {})
    initial_position = initial.get("torso_position_m")
    initial_yaw = initial.get("torso_yaw_rad")
    if (
        not isinstance(initial_position, list)
        or len(initial_position) != 3
        or not all(_finite(value) for value in initial_position)
        or not _finite(initial_yaw)
    ):
        _push(failures, "C6_MJC_BW19V_MV2_INITIAL_SNAPSHOT")
        return failures

    foot = {
        limb_id: FootEvidence(bool(initial["ordered_declared_contacts"][contact_id]))
        for limb_id, contact_id in zip(limb_ids, contact_ids, strict=True)
    }
    maximum_tilt = float(initial["torso_tilt_rad"])
    minimum_height = float(initial_position[1])
    torso_contacts = 0
    base_count = bounded_count = canonical_count = host_count = application_count = 0
    nonzero_bounded = nonzero_effective = 0
    evidence_start: list[float] | None = None
    evidence_end: list[float] | None = None
    evidence_completion: int | None = None

    for index, entry in enumerate(trace):
        if not isinstance(entry, dict):
            _push(failures, "C6_MJC_BW19V_MV2_TRACE_TYPE")
            continue
        phase = "clocked" if index < CLOCKED_STEPS else "contact_gated"
        if (
            entry.get("schema_version") != TRACE_SCHEMA
            or entry.get("semantic_step") != index
            or entry.get("phase_progression_mode") != phase
            or entry.get("command_provenance_recorded_before_application") is not True
        ):
            _push(failures, "C6_MJC_BW19V_MV2_TRACE_SEQUENCE")
        if index == CLOCKED_STEPS:
            evidence_start = entry.get("pre_step_snapshot", {}).get("torso_position_m")

        arrays = [
            entry.get("ordered_portable_base_commands"),
            entry.get("ordered_bounded_canonical_residuals"),
            entry.get("ordered_canonical_commands"),
            entry.get("ordered_host_commands"),
            entry.get("ordered_native_applications"),
        ]
        if any(
            not isinstance(array, list)
            or len(array) != ACTUATOR_COUNT
            or [item.get("actuator_id") for item in array] != actuator_ids
            for array in arrays
        ):
            _push(failures, "C6_MJC_BW19V_MV2_ACTUATOR_ORDER")
            continue
        base_count += ACTUATOR_COUNT
        bounded_count += ACTUATOR_COUNT
        canonical_count += ACTUATOR_COUNT
        host_count += ACTUATOR_COUNT
        application_count += ACTUATOR_COUNT
        if (
            entry.get("host_profile_id") != PROFILE_ID
            or entry.get("host_response_characterized_for_this_profile") is not True
            or entry.get("native_position_stiffness") != 0.0
            or entry.get("independent_native_position_feedback_applied") is not False
            or entry.get("global_requested_correction_scale")
            != bridge.GLOBAL_REQUESTED_CORRECTION_SCALE
        ):
            _push(failures, "C6_MJC_BW19V_MV2_HOST_OR_COMPOSITION_PROFILE")
        receipt_payload = entry.get("receipt_payload")
        if not isinstance(receipt_payload, dict) or _digest(receipt_payload) != entry.get(
            "receipt_payload_sha256"
        ):
            _push(failures, "C6_MJC_BW19V_MV2_RECEIPT_DIGEST")
        else:
            receipt_bounded = [
                {
                    "actuator_id": item.get("actuator_id"),
                    "applied_velocity_delta_rad_s": item.get(
                        "applied_velocity_delta_rad_s"
                    ),
                }
                for item in receipt_payload.get("stability_influence", {}).get(
                    "ordered_applied_corrections", []
                )
            ]
            if (
                receipt_payload.get("controller_actuation", {}).get("semantic_step")
                != index
                or receipt_payload.get("controller_actuation", {}).get(
                    "source_policy_id"
                )
                != bridge.SELECTED_POLICY_ID
                or receipt_payload.get("controller_actuation", {}).get(
                    "ordered_commands"
                )
                != arrays[0]
                or receipt_bounded != arrays[1]
                or receipt_payload.get("canonical_actuation", {}).get(
                    "ordered_commands"
                )
                != arrays[2]
                or receipt_payload.get("host_mapping", {}).get("ordered_commands")
                != arrays[3]
                or receipt_payload.get("host_mapping", {}).get("host_profile_id")
                != PROFILE_ID
                or receipt_payload.get("host_mapping", {}).get(
                    "host_response_characterized_for_this_profile"
                )
                is not True
            ):
                _push(failures, "C6_MJC_BW19V_MV2_RECEIPT_PROJECTION")
        for base, bounded, canonical, host, application in zip(*arrays, strict=True):
            bounded_delta = bounded.get("applied_velocity_delta_rad_s")
            stability_delta = canonical.get("stability_canonical_velocity_delta_rad_s")
            portable_velocity = canonical.get("portable_canonical_target_velocity_rad_s")
            combined_velocity = canonical.get("combined_canonical_target_velocity_rad_s")
            host_velocity = host.get("host_target_velocity_rad_s")
            if not all(
                _finite(value)
                for value in (
                    bounded_delta,
                    stability_delta,
                    portable_velocity,
                    combined_velocity,
                    host_velocity,
                    application.get("target_velocity_rad_s"),
                    application.get("cumulative_absolute_force_time_nms"),
                    application.get("portable_maximum_outer_impulse_nms"),
                    application.get("maximum_absolute_actuator_force_nm"),
                )
            ):
                _push(failures, "C6_MJC_BW19V_MV2_NONFINITE_COMMAND")
                continue
            if (
                not _close(bounded_delta, stability_delta)
                or not _close(combined_velocity, host_velocity)
                or not _close(host_velocity, application["target_velocity_rad_s"])
                or host.get("native_target_position_rad") is not None
                or application["cumulative_absolute_force_time_nms"]
                > application["portable_maximum_outer_impulse_nms"] + 1.0e-12
            ):
                _push(failures, "C6_MJC_BW19V_MV2_MAPPING_OR_FORCE_BUDGET")
            nonzero_bounded += int(float(bounded_delta) != 0.0)
            nonzero_effective += int(float(portable_velocity) != float(combined_velocity))

        post = entry.get("post_step_snapshot", {})
        position = post.get("torso_position_m")
        values = [
            *(position if isinstance(position, list) else []),
            post.get("torso_tilt_rad"),
            post.get("torso_yaw_rad"),
        ]
        if len(values) != 5 or not all(_finite(value) for value in values):
            _push(failures, "C6_MJC_BW19V_MV2_NONFINITE_STATE")
            continue
        maximum_tilt = max(maximum_tilt, float(post["torso_tilt_rad"]))
        minimum_height = min(minimum_height, float(position[1]))
        torso_contacts += int(post.get("torso_ground_contact") is True)
        contacts = post.get("ordered_declared_contacts", {})
        positions = post.get("ordered_contact_site_positions_m", {})
        for limb_id, contact_id in zip(limb_ids, contact_ids, strict=True):
            if contact_id not in contacts or contact_id not in positions:
                _push(failures, "C6_MJC_BW19V_MV2_CONTACT_TRACE")
                continue
            foot[limb_id].observe(bool(contacts[contact_id]), positions[contact_id])

        memory_after = entry.get("ordered_limb_controller_memory_after")
        if (
            not isinstance(memory_after, list)
            or [item.get("limb_id") for item in memory_after] != limb_ids
        ):
            _push(failures, "C6_MJC_BW19V_MV2_LIMB_MEMORY_ORDER")
        elif evidence_completion is None and index >= CLOCKED_STEPS and all(
            item.get("evidence_gait_step_limit") is not None
            and item.get("gait_step") >= item.get("evidence_gait_step_limit")
            for item in memory_after
        ):
            evidence_completion = index
            evidence_end = position

    declared_counts = {
        "trace_step_count": TOTAL_STEPS,
        "base_command_count": base_count,
        "bounded_residual_command_count": bounded_count,
        "canonical_command_count": canonical_count,
        "host_command_count": host_count,
        "native_application_count": application_count,
        "nonzero_bounded_residual_count": nonzero_bounded,
        "nonzero_effective_host_residual_count": nonzero_effective,
        "torso_ground_contact_step_count": torso_contacts,
    }
    for key, expected in declared_counts.items():
        if report.get(key) != expected:
            _push(failures, f"C6_MJC_BW19V_MV2_RECOMPUTE:{key}")
    if nonzero_bounded <= 0 or nonzero_effective <= 0:
        _push(failures, "C6_MJC_BW19V_MV2_STABILITY_CONTRIBUTION_MISSING")

    final = trace[-1]["post_step_snapshot"]
    final_position = final["torso_position_m"]
    evidence_advance = (
        None
        if evidence_start is None or evidence_end is None
        else float(evidence_end[0]) - float(evidence_start[0])
    )
    metrics = {
        "evidence_forward_displacement_m": evidence_advance,
        "final_forward_displacement_m": float(final_position[0]) - float(initial_position[0]),
        "final_lateral_displacement_m": float(final_position[2]) - float(initial_position[2]),
        "final_yaw_drift_rad": float(final["torso_yaw_rad"]) - float(initial_yaw),
        "maximum_tilt_rad": maximum_tilt,
        "minimum_torso_height_m": minimum_height,
    }
    declared_metrics = report.get("metrics", {})
    for key, expected in metrics.items():
        if expected is None or not _close(declared_metrics.get(key), expected, 1.0e-8):
            _push(failures, f"C6_MJC_BW19V_MV2_METRIC_RECOMPUTE:{key}")
    if evidence_advance is None or evidence_advance < MINIMUM_EVIDENCE_ADVANCE_M:
        _push(failures, "C6_MJC_BW19V_MV2_EVIDENCE_ADVANCE")
    if metrics["final_forward_displacement_m"] < MINIMUM_FINAL_ADVANCE_M:
        _push(failures, "C6_MJC_BW19V_MV2_FINAL_ADVANCE")
    if abs(metrics["final_lateral_displacement_m"]) > MAXIMUM_LATERAL_DRIFT_M:
        _push(failures, "C6_MJC_BW19V_MV2_LATERAL_DRIFT")
    if abs(metrics["final_yaw_drift_rad"]) > MAXIMUM_YAW_DRIFT_RAD:
        _push(failures, "C6_MJC_BW19V_MV2_YAW_DRIFT")
    if maximum_tilt > MAXIMUM_TILT_RAD or minimum_height < MINIMUM_TORSO_HEIGHT_M:
        _push(failures, "C6_MJC_BW19V_MV2_POSTURE")
    if torso_contacts != 0:
        _push(failures, "C6_MJC_BW19V_MV2_TORSO_CONTACT")

    schedule = report.get("schedule", {})
    expected_schedule = {
        "total_controller_semantic_steps": TOTAL_STEPS,
        "clocked_steps": CLOCKED_STEPS,
        "contact_gated_start_step": CLOCKED_STEPS,
        "evidence_gait_steps_per_limb": EVIDENCE_GAIT_STEPS,
        "maximum_evidence_extension_steps": MAXIMUM_EVIDENCE_EXTENSION_STEPS,
        "evidence_deadline_step_exclusive": EVIDENCE_DEADLINE_EXCLUSIVE,
        "required_post_evidence_steps": REQUIRED_POST_EVIDENCE_STEPS,
        "evidence_limits_reached": evidence_completion is not None,
        "evidence_completion_semantic_step": evidence_completion,
        "required_post_evidence_steps_completed": (
            evidence_completion is not None
            and evidence_completion + REQUIRED_POST_EVIDENCE_STEPS < TOTAL_STEPS
        ),
    }
    for key, expected in expected_schedule.items():
        if schedule.get(key) != expected:
            _push(failures, f"C6_MJC_BW19V_MV2_SCHEDULE:{key}")
    if evidence_completion is None or evidence_completion >= EVIDENCE_DEADLINE_EXCLUSIVE:
        _push(failures, "C6_MJC_BW19V_MV2_EVIDENCE_DEADLINE")
    if not expected_schedule["required_post_evidence_steps_completed"]:
        _push(failures, "C6_MJC_BW19V_MV2_POST_EVIDENCE_HORIZON")

    terminal = all(final["ordered_declared_contacts"].get(site_id) is True for site_id in contact_ids)
    if report.get("terminal_four_contact_stance") != terminal or not terminal:
        _push(failures, "C6_MJC_BW19V_MV2_TERMINAL_STANCE")
    declared_limb_evidence = report.get("limb_evidence", {})
    for limb_id, evidence in foot.items():
        actual = evidence.receipt()
        declared = declared_limb_evidence.get(limb_id, {})
        if (
            declared.get("contact_cycles") != actual["contact_cycles"]
            or declared.get("maximum_airborne_dwell_steps")
            != actual["maximum_airborne_dwell_steps"]
            or not _close(
                declared.get("maximum_foot_relocation_m"),
                actual["maximum_foot_relocation_m"],
                1.0e-8,
            )
        ):
            _push(failures, f"C6_MJC_BW19V_MV2_LIMB_RECOMPUTE:{limb_id}")
        if (
            actual["contact_cycles"] < MINIMUM_CONTACT_CYCLES_PER_LIMB
            or actual["maximum_airborne_dwell_steps"] < MINIMUM_AIRBORNE_DWELL_STEPS
            or actual["maximum_foot_relocation_m"] < MINIMUM_FOOT_RELOCATION_M
        ):
            _push(failures, f"C6_MJC_BW19V_MV2_LIMB_GATE:{limb_id}")
    return failures


def evaluate_report(report: dict[str, Any]) -> list[str]:
    """Recompute MV2 without building or modifying a physics world."""

    failures = _evaluate_core(report)
    expected_ok = len(failures) == 0
    if report.get("ok") is not expected_ok:
        _push(failures, "C6_MJC_BW19V_MV2_DECLARED_OK")
    expected_claims = _claim_boundary(expected_ok)
    if report.get("claim_boundary") != expected_claims:
        _push(failures, "C6_MJC_BW19V_MV2_CLAIM_BOUNDARY")
    return failures


def _synthetic_snapshot(step: int, contact: bool, x: float) -> dict[str, Any]:
    contact_ids = [
        "front_left_foot",
        "front_right_foot",
        "rear_left_foot",
        "rear_right_foot",
    ]
    offset = 0.02 if step >= 203 else 0.0
    positions = {
        site_id: [x + offset, 0.02, float(index) * 0.01]
        for index, site_id in enumerate(contact_ids)
    }
    return {
        "torso_position_m": [x, 0.44, 0.0],
        "torso_tilt_rad": 0.0,
        "torso_yaw_rad": 0.0,
        "torso_ground_contact": False,
        "ordered_declared_contacts": {site_id: contact for site_id in contact_ids},
        "ordered_contact_site_positions_m": positions,
    }


def _perfect_report(preworld_canary: dict[str, Any]) -> dict[str, Any]:
    actuator_ids = [
        "front_left_hip",
        "front_left_knee",
        "front_right_hip",
        "front_right_knee",
        "rear_left_hip",
        "rear_left_knee",
        "rear_right_hip",
        "rear_right_knee",
    ]
    limb_ids = ["front_left", "front_right", "rear_left", "rear_right"]
    contact_ids = [f"{limb_id}_foot" for limb_id in limb_ids]
    trace: list[dict[str, Any]] = []
    foot = {limb_id: FootEvidence(True) for limb_id in limb_ids}
    evidence_completion = 1_912
    for step in range(TOTAL_STEPS):
        contact = not (100 <= step <= 102 or 200 <= step <= 202)
        pre_x = 0.2 * step / TOTAL_STEPS
        post_x = 0.2 * (step + 1) / TOTAL_STEPS
        pre = _synthetic_snapshot(step - 1, contact, pre_x)
        post = _synthetic_snapshot(step, contact, post_x)
        for limb_id, site_id in zip(limb_ids, contact_ids, strict=True):
            foot[limb_id].observe(contact, post["ordered_contact_site_positions_m"][site_id])
        base = []
        bounded = []
        canonical = []
        host = []
        applications = []
        for index, actuator_id in enumerate(actuator_ids):
            base_velocity = 0.1 + index * 0.001
            delta = 0.001 if step % 2 == 0 else -0.001
            combined = base_velocity + delta
            base.append({"actuator_id": actuator_id})
            bounded.append(
                {"actuator_id": actuator_id, "applied_velocity_delta_rad_s": delta}
            )
            canonical.append(
                {
                    "actuator_id": actuator_id,
                    "portable_canonical_target_velocity_rad_s": base_velocity,
                    "stability_canonical_velocity_delta_rad_s": delta,
                    "combined_canonical_target_velocity_rad_s": combined,
                }
            )
            host.append(
                {
                    "actuator_id": actuator_id,
                    "host_target_velocity_rad_s": combined,
                    "native_target_position_rad": None,
                }
            )
            applications.append(
                {
                    "actuator_id": actuator_id,
                    "target_velocity_rad_s": combined,
                    "cumulative_absolute_force_time_nms": 0.01,
                    "portable_maximum_outer_impulse_nms": 0.04,
                    "maximum_absolute_actuator_force_nm": 2.0,
                }
            )
        receipt = {
            "controller_actuation": {
                "semantic_step": step,
                "source_policy_id": bridge.SELECTED_POLICY_ID,
                "ordered_commands": base,
            },
            "scheduled_load_transfer": {"synthetic": True},
            "endpoint_mapping": {"synthetic": True},
            "stability_influence": {
                "ordered_applied_corrections": bounded,
            },
            "canonical_actuation": {"ordered_commands": canonical},
            "host_mapping": {
                "host_profile_id": PROFILE_ID,
                "host_response_characterized_for_this_profile": True,
                "ordered_commands": host,
            },
        }
        memory = [
            {
                "limb_id": limb_id,
                "gait_step": min(step, evidence_completion),
                "evidence_gait_step_limit": evidence_completion if step >= CLOCKED_STEPS else None,
            }
            for limb_id in limb_ids
        ]
        trace.append(
            {
                "schema_version": TRACE_SCHEMA,
                "semantic_step": step,
                "phase_progression_mode": "clocked" if step < CLOCKED_STEPS else "contact_gated",
                "command_provenance_recorded_before_application": True,
                "pre_step_snapshot": pre,
                "ordered_portable_base_commands": base,
                "ordered_bounded_canonical_residuals": bounded,
                "ordered_canonical_commands": canonical,
                "host_profile_id": PROFILE_ID,
                "host_response_characterized_for_this_profile": True,
                "native_position_stiffness": 0.0,
                "independent_native_position_feedback_applied": False,
                "global_requested_correction_scale": bridge.GLOBAL_REQUESTED_CORRECTION_SCALE,
                "ordered_host_commands": host,
                "ordered_native_applications": applications,
                "receipt_payload": receipt,
                "receipt_payload_sha256": _digest(receipt),
                "post_step_snapshot": post,
                "ordered_limb_controller_memory_after": memory,
            }
        )
    initial = _synthetic_snapshot(-1, True, 0.0)
    evidence_start_x = trace[CLOCKED_STEPS]["pre_step_snapshot"]["torso_position_m"][0]
    evidence_end_x = trace[evidence_completion]["post_step_snapshot"]["torso_position_m"][0]
    report = {
        "schema_version": REPORT_SCHEMA,
        "ok": True,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "study_class": "outcome_exposed_single_body_finite_technical_commissioning_decision",
        "source_commit": "0" * 40,
        "preregistration_raw_sha256": EXPECTED_PREREGISTRATION_SHA256,
        "vh5_closure_raw_sha256": EXPECTED_VH5_CLOSURE_SHA256,
        "vh5_report_raw_sha256": EXPECTED_VH5_REPORT_SHA256,
        "threshold_source_raw_sha256": EXPECTED_RAPIER_LC1_PREREGISTRATION_SHA256,
        "mv1_closure_raw_sha256": EXPECTED_MV1_CLOSURE_SHA256,
        "preworld_real_dynamic_library_profile_canary": preworld_canary,
        "engine": "mujoco",
        "engine_version": mujoco.__version__,
        "adapter_id": bridge.ADAPTER_ID,
        "candidate_id": bridge.SELECTED_CANDIDATE_ID,
        "candidate_composition_digest": CANDIDATE_COMPOSITION_DIGEST,
        "selected_policy_id": bridge.SELECTED_POLICY_ID,
        "selected_policy_digest": POLICY_DIGEST,
        "stability_policy_id": bridge.STABILITY_POLICY_ID,
        "runtime_profile_sha256": S169_RUNTIME_PROFILE_SHA256,
        "morphology_id": "qsdk_r05_generated_s169",
        "global_requested_correction_scale": bridge.GLOBAL_REQUESTED_CORRECTION_SCALE,
        "host_profile_id": PROFILE_ID,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "world_reset_count": 0,
        **{field: 0 for field in ZERO_INTEGRITY_FIELDS},
        "ordered_actuator_ids": actuator_ids,
        "ordered_limb_ids": limb_ids,
        "ordered_contact_site_ids": contact_ids,
        "trace_step_count": TOTAL_STEPS,
        "base_command_count": COMMANDS_PER_LAYER,
        "bounded_residual_command_count": COMMANDS_PER_LAYER,
        "canonical_command_count": COMMANDS_PER_LAYER,
        "host_command_count": COMMANDS_PER_LAYER,
        "native_application_count": COMMANDS_PER_LAYER,
        "nonzero_bounded_residual_count": COMMANDS_PER_LAYER,
        "nonzero_effective_host_residual_count": COMMANDS_PER_LAYER,
        "initial_snapshot": initial,
        "schedule": {
            "total_controller_semantic_steps": TOTAL_STEPS,
            "clocked_steps": CLOCKED_STEPS,
            "contact_gated_start_step": CLOCKED_STEPS,
            "evidence_gait_steps_per_limb": EVIDENCE_GAIT_STEPS,
            "maximum_evidence_extension_steps": MAXIMUM_EVIDENCE_EXTENSION_STEPS,
            "evidence_deadline_step_exclusive": EVIDENCE_DEADLINE_EXCLUSIVE,
            "required_post_evidence_steps": REQUIRED_POST_EVIDENCE_STEPS,
            "evidence_limits_reached": True,
            "evidence_completion_semantic_step": evidence_completion,
            "required_post_evidence_steps_completed": True,
        },
        "metrics": {
            "evidence_forward_displacement_m": evidence_end_x - evidence_start_x,
            "final_forward_displacement_m": 0.2,
            "final_lateral_displacement_m": 0.0,
            "final_yaw_drift_rad": 0.0,
            "maximum_tilt_rad": 0.0,
            "minimum_torso_height_m": 0.44,
        },
        "terminal_four_contact_stance": True,
        "torso_ground_contact_step_count": 0,
        "limb_evidence": {limb_id: evidence.receipt() for limb_id, evidence in foot.items()},
        "ordered_trace": trace,
        "gate_failures": [],
        "claim_boundary": _claim_boundary(True),
    }
    return report


def run_preflight() -> dict[str, Any]:
    """Exercise the real Rust ABI and production evaluator with zero models."""

    _authorities()
    real_dynamic_canary = _real_dynamic_library_profile_canary()
    perfect = _perfect_report(real_dynamic_canary)
    perfect_failures = evaluate_report(perfect)
    round_trip = json.loads(json.dumps(perfect, allow_nan=False))
    controls: dict[str, Callable[[dict[str, Any]], None]] = {
        "missing_trace_step": lambda value: value["ordered_trace"].pop(),
        "reordered_semantic_step": lambda value: value["ordered_trace"][10].__setitem__("semantic_step", 11),
        "wrong_policy": lambda value: value.__setitem__("selected_policy_id", "wrong"),
        "wrong_candidate": lambda value: value.__setitem__("candidate_id", "wrong"),
        "wrong_profile": lambda value: value.__setitem__("host_profile_id", "wrong"),
        "wrong_vh5_closure": lambda value: value.__setitem__("vh5_closure_raw_sha256", "sha256:wrong"),
        "wrong_vh5_report": lambda value: value.__setitem__("vh5_report_raw_sha256", "sha256:wrong"),
        "wrong_mv1_closure": lambda value: value.__setitem__("mv1_closure_raw_sha256", "sha256:wrong"),
        "wrong_scale": lambda value: value.__setitem__("global_requested_correction_scale", 1.0),
        "missing_residual": lambda value: [
            item.__setitem__("applied_velocity_delta_rad_s", 0.0)
            for row in value["ordered_trace"]
            for item in row["ordered_bounded_canonical_residuals"]
        ],
        "native_position_target": lambda value: value["ordered_trace"][0]["ordered_host_commands"][0].__setitem__("native_target_position_rad", 0.1),
        "force_time_violation": lambda value: value["ordered_trace"][0]["ordered_native_applications"][0].__setitem__("cumulative_absolute_force_time_nms", 1.0),
        "command_order": lambda value: value["ordered_trace"][0]["ordered_host_commands"].reverse(),
        "receipt_digest": lambda value: value["ordered_trace"][0]["receipt_payload"]["scheduled_load_transfer"].__setitem__("synthetic", False),
        "forward_failure": lambda value: value["ordered_trace"][-1]["post_step_snapshot"]["torso_position_m"].__setitem__(0, 0.0),
        "lateral_failure": lambda value: value["ordered_trace"][-1]["post_step_snapshot"]["torso_position_m"].__setitem__(2, 1.0),
        "yaw_failure": lambda value: value["ordered_trace"][-1]["post_step_snapshot"].__setitem__("torso_yaw_rad", 1.0),
        "tilt_failure": lambda value: value["ordered_trace"][100]["post_step_snapshot"].__setitem__("torso_tilt_rad", 1.0),
        "height_failure": lambda value: value["ordered_trace"][100]["post_step_snapshot"]["torso_position_m"].__setitem__(1, 0.1),
        "torso_contact": lambda value: value["ordered_trace"][100]["post_step_snapshot"].__setitem__("torso_ground_contact", True),
        "limb_cycle_failure": lambda value: [
            row["post_step_snapshot"]["ordered_declared_contacts"].__setitem__("front_left_foot", True)
            for row in value["ordered_trace"]
        ],
        "terminal_stance_failure": lambda value: value["ordered_trace"][-1]["post_step_snapshot"]["ordered_declared_contacts"].__setitem__("front_left_foot", False),
        "evidence_deadline_failure": lambda value: [
            limb.__setitem__("evidence_gait_step_limit", TOTAL_STEPS + 1)
            for row in value["ordered_trace"]
            for limb in row["ordered_limb_controller_memory_after"]
        ],
        "world_count_inflation": lambda value: value.__setitem__("world_build_count", 2),
        "preworld_model_count_inflation": lambda value: value[
            "preworld_real_dynamic_library_profile_canary"
        ].__setitem__("model_construction_count", 1),
        "preworld_mapping_receipt_mutation": lambda value: value[
            "preworld_real_dynamic_library_profile_canary"
        ]["positive_mapping_receipt"].__setitem__("host_profile_id", "wrong"),
        "claim_inflation": lambda value: value["claim_boundary"].__setitem__("release_authorized", True),
    }
    rejected: dict[str, bool] = {}
    for name, mutate in controls.items():
        candidate = copy.deepcopy(perfect)
        mutate(candidate)
        rejected[name] = len(evaluate_report(candidate)) > 0
    ok = (
        not perfect_failures
        and not evaluate_report(round_trip)
        and len(controls) == 27
        and all(rejected.values())
        and real_dynamic_canary["ok"]
        and real_dynamic_canary["negative_control_count"] == 2
    )
    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "ok": ok,
        "perfect_synthetic_result_passed": not perfect_failures,
        "perfect_synthetic_serialization_round_trip_passed": not evaluate_report(round_trip),
        "perfect_synthetic_failure_codes": perfect_failures,
        "negative_control_count": len(controls)
        + real_dynamic_canary["negative_control_count"],
        "synthetic_report_negative_control_count": len(controls),
        "negative_controls_rejected": rejected,
        "real_dynamic_library_negative_control_count": real_dynamic_canary[
            "negative_control_count"
        ],
        "real_dynamic_library_profile_canary": real_dynamic_canary,
        "world_build_count": 0,
        "scene_insertion_count": 0,
        "physics_state_modified": False,
        "locomotion_outcome_exposed": False,
        "physical_acceptance_authority": False,
    }


def run_campaign(source_commit: str) -> dict[str, Any]:
    authorities = _authorities()
    if len(source_commit) != 40:
        raise ValueError("source_commit must be a full Git object ID")
    preflight = run_preflight()
    if not preflight["ok"]:
        raise RuntimeError("C6_MJC_BW19V_MV2_PREFLIGHT_FAILED")
    core = bridge.LocomotionCore()
    robot = bridge.MujocoBw19vRobot(core, PROFILE_ID)
    controller_memory = core.balanced_wave_initial_memory()
    composition_memory = bridge.CompositionMemory()
    robot.prepare()
    initial = _snapshot(robot)
    task_origin = np.asarray(initial["torso_position_m"], dtype=np.float64)
    actuator_ids = list(robot.morphology["ordered_actuator_ids"])
    limb_ids = list(robot.morphology["ordered_limb_ids"])
    contact_ids = list(robot.morphology["ordered_contact_site_ids"])
    foot = {
        limb_id: FootEvidence(bool(initial["ordered_declared_contacts"][contact_id]))
        for limb_id, contact_id in zip(limb_ids, contact_ids, strict=True)
    }
    trace: list[dict[str, Any]] = []
    evidence_start: list[float] | None = None
    evidence_end: list[float] | None = None
    evidence_completion: int | None = None
    counters = {field: 0 for field in ZERO_INTEGRITY_FIELDS}
    counts = {
        "base_command_count": 0,
        "bounded_residual_command_count": 0,
        "canonical_command_count": 0,
        "host_command_count": 0,
        "native_application_count": 0,
        "nonzero_bounded_residual_count": 0,
        "nonzero_effective_host_residual_count": 0,
    }
    maximum_tilt = float(initial["torso_tilt_rad"])
    minimum_height = float(initial["torso_position_m"][1])

    for semantic_step in range(TOTAL_STEPS):
        pre = _snapshot(robot)
        if semantic_step == CLOCKED_STEPS:
            evidence_start = list(pre["torso_position_m"])
            for limb in controller_memory["ordered_limb_memory"]:
                limb["evidence_gait_step_limit"] = (
                    int(limb["gait_step"]) + 1 + EVIDENCE_GAIT_STEPS
                )
        phase = "clocked" if semantic_step < CLOCKED_STEPS else "contact_gated"
        state = robot.state_frame(semantic_step, task_origin)
        stability_state = robot.stability_state(semantic_step)
        kinematics = robot.endpoint_kinematics(stability_state)
        limb_steps = bridge._ordered_limb_steps(controller_memory, limb_ids)
        output = core.balanced_wave_policy_step(
            bridge.SELECTED_POLICY_ID,
            {
                "descriptor": robot.descriptor,
                "memory": controller_memory,
                "state": state,
                "command": bridge._motion_command(semantic_step, phase),
            },
        )
        controller_memory = output["next_memory"]
        actuation = output["actuation"]
        counters["controller_error_count"] += int(
            actuation["receipt"]["controller_error"] is not None
        ) + len(actuation["failure_codes"])
        counters["safe_no_actuation_count"] += int(bool(actuation["safe_no_actuation"]))
        composition = bridge.compose_bw19v_step(
            robot,
            actuation,
            stability_state,
            kinematics,
            limb_steps,
            composition_memory,
        )
        mapping = composition["host_mapping"]
        application = robot.apply_host_mapping(mapping)
        counters["portable_impulse_limit_violation_count"] += application[
            "portable_impulse_violation_count"
        ]
        robot.prepare()
        post = _snapshot(robot)
        maximum_tilt = max(maximum_tilt, float(post["torso_tilt_rad"]))
        minimum_height = min(minimum_height, float(post["torso_position_m"][1]))
        counters["torso_ground_contact_step_count"] = counters.get(
            "torso_ground_contact_step_count", 0
        ) + int(post["torso_ground_contact"])
        if not all(
            _finite(value)
            for value in [
                *post["torso_position_m"],
                post["torso_tilt_rad"],
                post["torso_yaw_rad"],
            ]
        ):
            counters["nonfinite_observation_count"] += 1
        for limb_id, contact_id in zip(limb_ids, contact_ids, strict=True):
            foot[limb_id].observe(
                bool(post["ordered_declared_contacts"][contact_id]),
                post["ordered_contact_site_positions_m"][contact_id],
            )

        bounded = [
            {
                "actuator_id": item["actuator_id"],
                "applied_velocity_delta_rad_s": float(
                    item["applied_velocity_delta_rad_s"]
                ),
            }
            for item in composition["stability_influence"][
                "ordered_applied_corrections"
            ]
        ]
        canonical = [dict(item) for item in composition["canonical_actuation"]["ordered_commands"]]
        host = [dict(item) for item in mapping["ordered_commands"]]
        applications = [
            {
                "actuator_id": actuator_id,
                "target_velocity_rad_s": application["targets"][index],
                "cumulative_absolute_force_time_nms": application[
                    "cumulative_absolute_force_time_nms"
                ][index],
                "portable_maximum_outer_impulse_nms": application[
                    "portable_maximum_outer_impulse_nms"
                ][index],
                "maximum_absolute_actuator_force_nm": application[
                    "maximum_absolute_actuator_force_nm"
                ][index],
            }
            for index, actuator_id in enumerate(actuator_ids)
        ]
        receipt = {
            "controller_actuation": actuation,
            "scheduled_load_transfer": composition["scheduled_load_transfer"],
            "endpoint_mapping": composition["endpoint_mapping"],
            "stability_influence": composition["stability_influence"],
            "canonical_actuation": composition["canonical_actuation"],
            "host_mapping": mapping,
        }
        host_profile = bridge._mujoco_host_profile(PROFILE_ID)
        trace.append(
            {
                "schema_version": TRACE_SCHEMA,
                "semantic_step": semantic_step,
                "phase_progression_mode": phase,
                "command_provenance_recorded_before_application": True,
                "pre_step_snapshot": pre,
                "ordered_portable_base_commands": [
                    dict(item) for item in actuation["ordered_commands"]
                ],
                "ordered_bounded_canonical_residuals": bounded,
                "ordered_canonical_commands": canonical,
                "host_profile_id": PROFILE_ID,
                "host_response_characterized_for_this_profile": host_profile[
                    "host_response_characterized_for_this_profile"
                ],
                "native_position_stiffness": host_profile["native_position_stiffness"],
                "independent_native_position_feedback_applied": host_profile[
                    "independent_native_position_feedback_applied"
                ],
                "global_requested_correction_scale": composition["stability_influence"][
                    "global_requested_correction_scale"
                ],
                "ordered_host_commands": host,
                "ordered_native_applications": applications,
                "receipt_payload": receipt,
                "receipt_payload_sha256": _digest(receipt),
                "post_step_snapshot": post,
                "ordered_limb_controller_memory_after": _limb_receipt(controller_memory),
            }
        )
        counts["base_command_count"] += len(actuation["ordered_commands"])
        counts["bounded_residual_command_count"] += len(bounded)
        counts["canonical_command_count"] += len(canonical)
        counts["host_command_count"] += len(host)
        counts["native_application_count"] += len(applications)
        counts["nonzero_bounded_residual_count"] += sum(
            item["applied_velocity_delta_rad_s"] != 0.0 for item in bounded
        )
        counts["nonzero_effective_host_residual_count"] += sum(
            item["portable_canonical_target_velocity_rad_s"]
            != item["combined_canonical_target_velocity_rad_s"]
            for item in canonical
        )
        if evidence_completion is None and semantic_step >= CLOCKED_STEPS and all(
            limb.get("evidence_gait_step_limit") is not None
            and int(limb["gait_step"]) >= int(limb["evidence_gait_step_limit"])
            for limb in controller_memory["ordered_limb_memory"]
        ):
            evidence_completion = semantic_step
            evidence_end = list(post["torso_position_m"])

    final = trace[-1]["post_step_snapshot"]
    metrics = {
        "evidence_forward_displacement_m": (
            None
            if evidence_start is None or evidence_end is None
            else evidence_end[0] - evidence_start[0]
        ),
        "final_forward_displacement_m": final["torso_position_m"][0]
        - initial["torso_position_m"][0],
        "final_lateral_displacement_m": final["torso_position_m"][2]
        - initial["torso_position_m"][2],
        "final_yaw_drift_rad": final["torso_yaw_rad"] - initial["torso_yaw_rad"],
        "maximum_tilt_rad": maximum_tilt,
        "minimum_torso_height_m": minimum_height,
    }
    report = {
        "schema_version": REPORT_SCHEMA,
        "ok": False,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "study_class": "outcome_exposed_single_body_finite_technical_commissioning_decision",
        "source_commit": source_commit,
        "preregistration_raw_sha256": EXPECTED_PREREGISTRATION_SHA256,
        "vh5_closure_raw_sha256": EXPECTED_VH5_CLOSURE_SHA256,
        "vh5_report_raw_sha256": EXPECTED_VH5_REPORT_SHA256,
        "threshold_source_raw_sha256": EXPECTED_RAPIER_LC1_PREREGISTRATION_SHA256,
        "mv1_closure_raw_sha256": EXPECTED_MV1_CLOSURE_SHA256,
        "preworld_real_dynamic_library_profile_canary": preflight[
            "real_dynamic_library_profile_canary"
        ],
        "engine": "mujoco",
        "engine_version": mujoco.__version__,
        "adapter_id": bridge.ADAPTER_ID,
        "adapter_capability_sha256": bridge.capability_manifest_sha256(),
        "candidate_id": bridge.SELECTED_CANDIDATE_ID,
        "candidate_composition_digest": CANDIDATE_COMPOSITION_DIGEST,
        "selected_policy_id": bridge.SELECTED_POLICY_ID,
        "selected_policy_digest": POLICY_DIGEST,
        "stability_policy_id": bridge.STABILITY_POLICY_ID,
        "runtime_profile_sha256": S169_RUNTIME_PROFILE_SHA256,
        "morphology_id": robot.morphology["morphology_id"],
        "descriptor_sha256": robot.compiled["descriptor_sha256"],
        "global_requested_correction_scale": bridge.GLOBAL_REQUESTED_CORRECTION_SCALE,
        "host_profile_id": PROFILE_ID,
        "vh5_source_commit": authorities["vh5"]["source"]["commit"],
        "world_attempt_count": 1,
        "world_build_count": 1,
        "world_reset_count": 0,
        **counters,
        "ordered_actuator_ids": actuator_ids,
        "ordered_limb_ids": limb_ids,
        "ordered_contact_site_ids": contact_ids,
        "trace_step_count": len(trace),
        **counts,
        "initial_snapshot": initial,
        "schedule": {
            "total_controller_semantic_steps": TOTAL_STEPS,
            "clocked_steps": CLOCKED_STEPS,
            "contact_gated_start_step": CLOCKED_STEPS,
            "evidence_gait_steps_per_limb": EVIDENCE_GAIT_STEPS,
            "maximum_evidence_extension_steps": MAXIMUM_EVIDENCE_EXTENSION_STEPS,
            "evidence_deadline_step_exclusive": EVIDENCE_DEADLINE_EXCLUSIVE,
            "required_post_evidence_steps": REQUIRED_POST_EVIDENCE_STEPS,
            "evidence_limits_reached": evidence_completion is not None,
            "evidence_completion_semantic_step": evidence_completion,
            "required_post_evidence_steps_completed": (
                evidence_completion is not None
                and evidence_completion + REQUIRED_POST_EVIDENCE_STEPS < TOTAL_STEPS
            ),
        },
        "metrics": metrics,
        "terminal_four_contact_stance": all(
            final["ordered_declared_contacts"][site_id] for site_id in contact_ids
        ),
        "torso_ground_contact_step_count": counters.get(
            "torso_ground_contact_step_count", 0
        ),
        "limb_evidence": {
            limb_id: evidence.receipt() for limb_id, evidence in foot.items()
        },
        "ordered_trace": trace,
        "gate_failures": [],
        "claim_boundary": _claim_boundary(False),
        "physical_acceptance_authority": False,
    }
    failures = _evaluate_core(report)
    report["gate_failures"] = failures
    report["ok"] = not failures
    report["claim_boundary"] = _claim_boundary(report["ok"])
    return report


def _write_new_json(path: Path, value: dict[str, Any]) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, allow_nan=False)
        handle.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run MuJoCo BW19V MV2 preflight or physical campaign")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preflight-only", action="store_true")
    mode.add_argument("--run-physical", action="store_true")
    parser.add_argument("--source-commit")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    if args.preflight_only:
        result = run_preflight()
        print(json.dumps(result, indent=2, allow_nan=False))
        return 0 if result["ok"] else 1
    if not args.source_commit or args.report is None:
        parser.error("--run-physical requires --source-commit and --report")
    result = run_campaign(args.source_commit)
    _write_new_json(args.report, result)
    print(
        f"{GATE_ID} ok={result['ok']} steps={result['trace_step_count']} "
        f"failures={len(result['gate_failures'])}"
    )
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
