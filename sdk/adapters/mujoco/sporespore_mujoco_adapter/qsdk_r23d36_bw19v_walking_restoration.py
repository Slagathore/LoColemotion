"""One-shot classic-MuJoCo worker for QSDK-R23D36.

R23D34 established that the unchanged R23D29 controller falls in MuJoCo
before turn onset.  This scientifically distinct successor keeps R23D29,
the fixture, host profile, seed, horizon, and walking gates fixed while
composing the engine-neutral BW19V scheduled-load-transfer residual that was
already accepted in the MuJoCo MV6 lineage.
"""

from __future__ import annotations

import argparse
import copy
import importlib.util
import json
import math
import os
from pathlib import Path
import sys
from types import ModuleType, SimpleNamespace
from typing import Any, Sequence

from sporespore_locomotion import LocomotionCore, LocomotionCoreError


SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
TURNING_ROOT = SDK_ROOT / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

from . import qsdk_r23d2_heading_response as inherited_base  # noqa: E402
from . import selected_policy_development as stability_bridge  # noqa: E402

import r23d36_mujoco_bw19v_walking_restoration as design  # noqa: E402
import r23d36_mujoco_bw19v_walking_restoration_evaluator as evaluator  # noqa: E402


def _load_private_worker() -> ModuleType:
    source = Path(__file__).with_name("qsdk_r23d3_phase_balanced.py")
    specification = importlib.util.spec_from_file_location(
        "sporespore_mujoco_adapter._qsdk_r23d36_fixed_horizon_core",
        source,
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("QSDK_R23D36_MJC_INHERITED_WORKER_UNAVAILABLE")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


_core = _load_private_worker()
_INHERITED_TRACE_ROW = _core._trace_row
PREREGISTRATION_PATH = (
    TURNING_ROOT / "r23d36_mujoco_bw19v_walking_restoration_preregistration_v1.json"
)
IMPLEMENTATION_PATH = (
    TURNING_ROOT / "r23d36_mujoco_bw19v_walking_restoration_implementation_v1.json"
)
CLOSURE_PATH = (
    TURNING_ROOT / "r23d36_mujoco_bw19v_walking_restoration_closure_v1.json"
)
WORKER_PATH = Path(__file__).resolve()
FREEZE_SCHEMA = "sporespore_qsdk_r23d36_physical_freeze_v1"
ATTEMPT_SCHEMA = "sporespore_qsdk_r23d36_attempt_v1"
FREEZE_PATH_ENV = "SPORESPORE_QSDK_R23D36_FREEZE"
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D36_ATTEMPT"
TOKEN_ENV = "SPORESPORE_QSDK_R23D36_TOKEN"
STAGE_ENV = "SPORESPORE_QSDK_R23D36_STAGE"
CELL_ENV = "SPORESPORE_QSDK_R23D36_CELL"
ENGINE_ENV = "SPORESPORE_QSDK_R23D36_ENGINE"
ATTEMPT_ROOT_ENV = "SPORESPORE_QSDK_R23D36_ATTEMPT_ROOT"
PYTHON_ENV = "SPORESPORE_QSDK_R23D36_PYTHON"
POWERSHELL_ENV = "SPORESPORE_QSDK_R23D36_POWERSHELL"
ENGINE_ID = design.ENGINE_ID
REQUIRED_SOURCE_PATHS = (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d36_bw19v_walking_restoration.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d3_phase_balanced.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d2_heading_response.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py",
    "sdk/turning/r23d36_mujoco_bw19v_walking_restoration.py",
    "sdk/turning/r23d36_mujoco_bw19v_walking_restoration_evaluator.py",
    "sdk/turning/r23d36_mujoco_bw19v_walking_restoration_preregistration_v1.json",
    "sdk/turning/r23d36_mujoco_bw19v_walking_restoration_implementation_v1.json",
    "sdk/publish_qsdk_r23d34_trace.ps1",
    "sdk/python/sporespore_locomotion.py",
)


class _OverlayRun:
    def __init__(self) -> None:
        self.reset()

    def reset(self) -> None:
        self.robot: Any | None = None
        self.memory = stability_bridge.CompositionMemory()
        self.pending_step: int | None = None
        self.pending_limb_steps: list[dict[str, Any]] | None = None
        self.rows: dict[int, dict[str, Any]] = {}
        self.composition_step_count = 0
        self.available_step_count = 0
        self.active_step_count = 0
        self.nonzero_step_count = 0
        self.maximum_absolute_velocity_residual_rad_s = 0.0
        self.integrity_passed = True

    def begin(self, robot: Any) -> None:
        self.reset()
        self.robot = robot

    def capture_controller_input(self, request: dict[str, Any]) -> None:
        memory = request.get("memory")
        state = request.get("state")
        if not isinstance(memory, dict) or not isinstance(state, dict):
            raise RuntimeError("QSDK_R23D36_OVERLAY_CONTROLLER_INPUT_INVALID")
        self.pending_step = int(state["semantic_step"])
        if self.robot is None:
            raise RuntimeError("QSDK_R23D36_OVERLAY_ROBOT_UNAVAILABLE")
        self.pending_limb_steps = stability_bridge._ordered_limb_steps(
            memory, list(self.robot.morphology["ordered_limb_ids"])
        )

    def compose(self, actuation: dict[str, Any]) -> list[dict[str, Any]]:
        semantic_step = int(actuation.get("semantic_step", -1))
        if (
            self.robot is None
            or self.pending_step != semantic_step
            or self.pending_limb_steps is None
            or semantic_step in self.rows
        ):
            raise RuntimeError("QSDK_R23D36_OVERLAY_STEP_BINDING_INVALID")
        stability_state = self.robot.stability_state(semantic_step)
        kinematics = self.robot.endpoint_kinematics(stability_state)
        composition = stability_bridge.compose_bw19v_step(
            self.robot,
            actuation,
            stability_state,
            kinematics,
            self.pending_limb_steps,
            self.memory,
        )
        plan = composition["scheduled_load_transfer"]
        influence = composition["stability_influence"]
        corrections = influence["ordered_applied_corrections"]
        ordered_ids = list(self.robot.morphology["ordered_actuator_ids"])
        if [item.get("actuator_id") for item in corrections] != ordered_ids:
            raise RuntimeError("QSDK_R23D36_OVERLAY_CORRECTION_ORDER_INVALID")
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
            for correction in corrections
        ]
        recomposed = self.robot.core.canonical_velocity_compose_v1(
            {
                "schema_version": "sporespore_canonical_velocity_compose_request_v1",
                "descriptor": self.robot.descriptor,
                "source_actuation": actuation,
                "ordered_stability_residuals": residuals,
            }
        )
        remapped = self.robot.core.canonical_velocity_host_map_v1(
            {
                "schema_version": "sporespore_canonical_velocity_host_map_request_v1",
                "descriptor": self.robot.descriptor,
                "canonical_actuation": recomposed,
                "host_profile": stability_bridge._mujoco_host_profile(
                    self.robot.profile_id
                ),
            }
        )
        integrity = (
            recomposed == composition["canonical_actuation"]
            and remapped == composition["host_mapping"]
        )
        values = [
            float(item["canonical_velocity_delta_rad_s"]) for item in residuals
        ]
        if any(not math.isfinite(value) for value in values):
            raise RuntimeError("QSDK_R23D36_OVERLAY_NONFINITE")
        maximum = max((abs(value) for value in values), default=0.0)
        if maximum > stability_bridge.MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S + 1.0e-12:
            raise RuntimeError("QSDK_R23D36_OVERLAY_BOUND_EXCEEDED")
        nonzero = sum(abs(value) > 1.0e-12 for value in values)
        self.composition_step_count += 1
        self.available_step_count += int(plan["planning_availability"] == "available")
        self.active_step_count += int(bool(plan["active"]))
        self.nonzero_step_count += int(nonzero > 0)
        self.maximum_absolute_velocity_residual_rad_s = max(
            self.maximum_absolute_velocity_residual_rad_s, maximum
        )
        self.integrity_passed = self.integrity_passed and integrity
        self.rows[semantic_step] = {
            "stability_policy_id": design.STABILITY_POLICY_ID,
            "stability_planning_availability": plan["planning_availability"],
            "stability_planning_outcome_code": plan["planning_outcome_code"],
            "stability_plan_active": bool(plan["active"]),
            "stability_nonzero_residual_count": nonzero,
            "stability_maximum_absolute_velocity_residual_rad_s": maximum,
            "ordered_stability_velocity_residuals": [
                {
                    "actuator_id": item["actuator_id"],
                    "canonical_velocity_delta_rad_s": float(
                        item["canonical_velocity_delta_rad_s"]
                    ),
                }
                for item in residuals
            ],
            "stability_composition_integrity_passed": integrity,
        }
        self.pending_step = None
        self.pending_limb_steps = None
        return residuals

    def trace_fields(self, semantic_step: int) -> dict[str, Any]:
        try:
            return self.rows.pop(semantic_step)
        except KeyError as error:
            raise RuntimeError("QSDK_R23D36_OVERLAY_TRACE_BINDING_INVALID") from error

    def summary(self) -> dict[str, Any]:
        return {
            "stability_composition_step_count": self.composition_step_count,
            "stability_planning_available_step_count": self.available_step_count,
            "stability_plan_active_step_count": self.active_step_count,
            "stability_nonzero_residual_step_count": self.nonzero_step_count,
            "maximum_absolute_stability_velocity_residual_rad_s": (
                self.maximum_absolute_velocity_residual_rad_s
            ),
            "stability_composition_integrity_passed": (
                self.integrity_passed and not self.rows
            ),
        }


_OVERLAY = _OverlayRun()


class _R23D36Core(LocomotionCore):
    def balanced_wave_initial_memory(self) -> dict[str, Any]:
        return self.balanced_wave_policy_initial_memory(
            design.POLICY_ID,
            inherited_base.bridge.s169_descriptor(),
        )

    def balanced_wave_policy_step(
        self, policy_id: str, request: dict[str, Any]
    ) -> dict[str, Any]:
        if policy_id == design.POLICY_ID:
            _OVERLAY.capture_controller_input(request)
        return super().balanced_wave_policy_step(policy_id, request)


class _BridgeBound:
    def __init__(self, bridge: ModuleType) -> None:
        self._bridge = bridge

    def __getattr__(self, name: str) -> Any:
        return getattr(self._bridge, name)

    def MujocoBw19vRobot(self, core: LocomotionCore, profile_id: str) -> Any:
        robot = self._bridge.MujocoBw19vRobot(core, profile_id)
        _OVERLAY.begin(robot)
        return robot


class _PolicyBoundBase:
    POLICY_ID = design.POLICY_ID
    CAMPAIGN_SEED = design.CAMPAIGN_SEED

    def __init__(self, base: ModuleType) -> None:
        self._base = base
        self.bridge = _BridgeBound(base.bridge)

    def __getattr__(self, name: str) -> Any:
        return getattr(self._base, name)

    def _compile_boundary(self, core: LocomotionCore) -> tuple[dict[str, Any], dict[str, Any]]:
        return self._base._compile_boundary(core, policy_id=design.POLICY_ID)

    def _initial_perturbation(self, _development: dict[str, Any]) -> dict[str, Any]:
        return copy.deepcopy(design.INITIAL_PERTURBATION)

    def _zero_residuals(self, actuation: dict[str, Any]) -> list[dict[str, Any]]:
        return _OVERLAY.compose(actuation)


_bound_base = _PolicyBoundBase(inherited_base)


def _cell(stage_id: str, onset_id: str, arm_id: str) -> design.Cell:
    if onset_id != "onset_600":
        raise _core.R23D3MujocoError(f"QSDK_R23D36_MJC_ONSET_INVALID:{onset_id}")
    try:
        return design.cell(stage_id, ENGINE_ID, arm_id)
    except ValueError as error:
        raise _core.R23D3MujocoError(str(error)) from error


def _contract() -> dict[str, Any]:
    declaration = evaluator.load_declaration()
    if CLOSURE_PATH.is_file():
        raise _core.R23D3MujocoError("QSDK_R23D36_MJC_CLOSED")
    return declaration


def _source_bindings_exact(freeze: dict[str, Any]) -> bool:
    bindings = freeze.get("source_bindings")
    if not isinstance(bindings, list):
        return False
    observed = {
        str(item.get("path")): str(item.get("raw_sha256"))
        for item in bindings
        if isinstance(item, dict)
    }
    return all(
        observed.get(relative) == evaluator.raw_sha256(REPO_ROOT / relative)
        for relative in REQUIRED_SOURCE_PATHS
    )


def _physical_authorization(item: design.Cell, source_commit: str) -> dict[str, Any]:
    freeze_path = Path(os.environ.get(FREEZE_PATH_ENV, ""))
    attempt_path = Path(os.environ.get(ATTEMPT_PATH_ENV, ""))
    attempt_root = Path(os.environ.get(ATTEMPT_ROOT_ENV, ""))
    token = os.environ.get(TOKEN_ENV, "")
    if (
        not freeze_path.is_file()
        or not attempt_path.is_file()
        or not attempt_root.is_dir()
        or not _core._valid_lower_hex(token, 32)
    ):
        raise _core.R23D3MujocoError("QSDK_R23D36_MJC_AUTHORIZATION_REQUIRED")
    freeze = _core._read_json(freeze_path, "QSDK_R23D36_MJC_FREEZE_UNREADABLE")
    attempt = _core._read_json(attempt_path, "QSDK_R23D36_MJC_ATTEMPT_UNREADABLE")
    try:
        attempt_root.resolve().relative_to((REPO_ROOT.parent / "SporeSpore_Evidence").resolve())
    except ValueError as error:
        raise _core.R23D3MujocoError("QSDK_R23D36_MJC_ATTEMPT_ROOT_NOT_DURABLE") from error
    invalid = (
        freeze.get("schema_version") != FREEZE_SCHEMA
        or freeze.get("campaign_id") != design.CAMPAIGN_ID
        or freeze.get("gate_id") != design.GATE_ID
        or freeze.get("status") != "frozen_supervisor_only_physical_authorized"
        or freeze.get("source_commit") != source_commit
        or freeze.get("preregistration_raw_sha256") != evaluator.raw_sha256(PREREGISTRATION_PATH)
        or freeze.get("implementation_contract_raw_sha256") != evaluator.raw_sha256(IMPLEMENTATION_PATH)
        or freeze.get("declared_world_count") != 1
        or freeze.get("physical_execution_authorized") is not True
        or not _source_bindings_exact(freeze)
        or attempt.get("schema_version") != ATTEMPT_SCHEMA
        or attempt.get("campaign_id") != design.CAMPAIGN_ID
        or attempt.get("gate_id") != design.GATE_ID
        or attempt.get("source_commit") != source_commit
        or attempt.get("freeze_raw_sha256") != evaluator.raw_sha256(freeze_path)
        or attempt.get("authorization_token") != token
        or attempt.get("ordered_matrix_cell_ids") != [item.cell_id]
        or attempt.get("physical_execution_authorized") is not True
        or attempt.get("single_use_supervisor_authorization") is not True
        or attempt.get("source_worktree_clean") is not True
        or attempt.get("source_matches_live_github_main") is not True
        or attempt.get("operation_lock_held") is not True
        or attempt.get("campaign_attestation_adoption_valid") is not True
        or attempt.get("content_addressed_inputs_retained") is not True
        or attempt.get("one_shot_attempt_unconsumed") is not True
        or Path(str(attempt.get("attempt_root", ""))).resolve() != attempt_root.resolve()
        or os.environ.get(STAGE_ENV) != item.stage_id
        or os.environ.get(CELL_ENV) != item.cell_id
        or os.environ.get(ENGINE_ENV) != ENGINE_ID
    )
    if invalid:
        raise _core.R23D3MujocoError("QSDK_R23D36_MJC_AUTHORIZATION_INVALID")
    return {"freeze": freeze, "attempt": attempt, "attempt_root": attempt_root}


def _retain_trace(
    item: design.Cell,
    rows: list[dict[str, Any]],
    attempt_root: Path,
) -> dict[str, Any]:
    pending = attempt_root / "pending-traces"
    pending.mkdir(parents=True, exist_ok=True)
    rows_path = pending / f"{item.cell_id}.rows.json"
    with rows_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(rows, stream, allow_nan=False, separators=(",", ":"), sort_keys=True)
        stream.write("\n")
    return evaluator.retain_trace(
        stage_id=item.stage_id,
        cell_id=item.cell_id,
        rows_json_path=rows_path,
        repo_root=REPO_ROOT,
        attempt_root=attempt_root,
        powershell=os.environ.get(POWERSHELL_ENV, "pwsh"),
    )


def _synthetic_composition_canary(core: LocomotionCore) -> dict[str, Any]:
    compiled, _profile = _bound_base._compile_boundary(core)
    descriptor = stability_bridge.s169_descriptor()
    state = inherited_base._state_for_canary(
        compiled,
        {
            "task_lateral_axis_world_unit": [0.0, 0.0, 1.0],
            "base_position_world_m": [0.0, 0.5, 0.0],
            "measured_heading_world_rad": 0.0,
            "base_linear_velocity_world_m_s": [0.0, 0.0, 0.0],
            "task_origin_world_m": [0.0, 0.5, 0.0],
            "reference_yaw_rad": 0.0,
        },
    )
    state["semantic_step"] = 0
    state["sample_time_s"] = 0.0
    command = {
        "schema_version": "sporespore_motion_command_v2",
        "command_id": "qsdk_r23d36_zero_world_reference_walk",
        "desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
        "desired_heading_rad": 0.0,
        "desired_yaw_rate_rad_s": None,
        "gait_family_id": "lateral_wave",
        "speed_class": "walk",
        "gait_amplitude": 1.0,
        "phase_progression_mode": "clocked",
        "valid_from_step": 0,
        "valid_through_step": 0,
        "authority": "test_fixture",
    }
    memory = core.balanced_wave_policy_initial_memory(design.POLICY_ID, descriptor)
    output = LocomotionCore.balanced_wave_policy_step(
        core,
        design.POLICY_ID,
        {"descriptor": descriptor, "memory": memory, "state": state, "command": command},
    )
    body_states = [
        {
            "body_id": body_id,
            "pose_world": {
                "position_m": {"x": 0.002, "y": 0.44, "z": 0.0},
                "orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
            },
            "twist_world": {
                "linear_velocity_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
                "angular_velocity_rad_s": {"x": 0.0, "y": 0.0, "z": 0.0},
            },
        }
        for body_id in compiled["morphology"]["ordered_body_ids"]
    ]
    contacts = [
        {
            "contact_site_id": contact_id,
            "presence": True,
            "bears_support": True,
            "point_world_m": {
                "x": 0.20 if contact_id.startswith("front") else -0.20,
                "y": 0.0,
                "z": 0.15 if "left" in contact_id else -0.15,
            },
            "normal_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
            "surface_relative_velocity_world_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
            "material_id": "qsdk_r23d36_zero_world",
            "adapter_id": "qsdk_r23d36_zero_world",
            "engine_contact_ids": [contact_id],
        }
        for contact_id in compiled["morphology"]["ordered_contact_site_ids"]
    ]
    stability_state = {
        "schema_version": "sporespore_stability_state_v2",
        "semantic_step": 0,
        "ordered_body_states": body_states,
        "ordered_support_contacts": contacts,
        "gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
        "support_plane_forward_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
        "adapter_capability_sha256": "sha256:" + ("3" * 64),
    }
    actuator_specs = {
        actuator["actuator_id"]: actuator
        for actuator in compiled["morphology"]["morphology_spec"]["actuators"]
    }
    limb_by_joint = {
        joint_id: limb
        for limb in compiled["morphology"]["morphology_spec"]["limbs"]
        for joint_id in limb["ordered_joint_ids"]
    }
    kinematics = []
    for index, actuator_id in enumerate(
        compiled["morphology"]["ordered_actuator_ids"]
    ):
        actuator = actuator_specs[actuator_id]
        limb = limb_by_joint[actuator["joint_id"]]
        is_hip = actuator["joint_id"].endswith("_hip")
        kinematics.append(
            {
                "actuator_id": actuator_id,
                "contact_site_id": limb["ordered_contact_site_ids"][0],
                "joint_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
                "endpoint_world_m": {"x": 0.2 + 0.01 * index, "y": -0.2, "z": 0.0},
                "joint_anchor_world_m": {
                    "x": 0.0 if is_hip else 0.1,
                    "y": 0.0 if is_hip else -0.1,
                    "z": 0.0,
                },
            }
        )
    robot = SimpleNamespace(
        core=core,
        descriptor=descriptor,
        morphology=compiled["morphology"],
        profile_id=inherited_base.HOST_PROFILE_ID,
    )
    composition = stability_bridge.compose_bw19v_step(
        robot,
        output["actuation"],
        stability_state,
        kinematics,
        [
            {"limb_id": limb_id, "gait_step": 0}
            for limb_id in compiled["morphology"]["ordered_limb_ids"]
        ],
        stability_bridge.CompositionMemory(),
    )
    corrections = composition["stability_influence"]["ordered_applied_corrections"]
    values = [abs(float(item["applied_velocity_delta_rad_s"])) for item in corrections]
    order_rejected = False
    bad = [
        {
            "schema_version": "sporespore_canonical_velocity_residual_v1",
            "actuator_id": item["actuator_id"],
            "canonical_velocity_delta_rad_s": item["applied_velocity_delta_rad_s"],
            "command_not_measurement": True,
            "physical_acceptance_authority": False,
        }
        for item in reversed(corrections)
    ]
    try:
        core.canonical_velocity_compose_v1(
            {
                "schema_version": "sporespore_canonical_velocity_compose_request_v1",
                "descriptor": descriptor,
                "source_actuation": output["actuation"],
                "ordered_stability_residuals": bad,
            }
        )
    except LocomotionCoreError:
        order_rejected = True
    if (
        composition["scheduled_load_transfer"]["planning_availability"] != "available"
        or max(values, default=0.0) <= 0.0
        or max(values, default=0.0)
        > stability_bridge.MAXIMUM_ABSOLUTE_VELOCITY_DELTA_RAD_S
        or not order_rejected
    ):
        raise _core.R23D3MujocoError("QSDK_R23D36_MJC_COMPOSITION_CANARY_INVALID")
    return {
        "planning_availability": "available",
        "nonzero_correction_count": sum(value > 0.0 for value in values),
        "maximum_absolute_velocity_residual_rad_s": max(values),
        "residual_order_mutation_rejected": order_rejected,
        "model_construction_count": 0,
        "world_build_count": 0,
    }


def run_preflight(stage_id: str, onset_id: str, arm_id: str) -> dict[str, Any]:
    _contract()
    item = _cell(stage_id, onset_id, arm_id)
    schedule = [design.segment_for_step(item, step) for step in range(design.CONTROLLER_STEPS)]
    core = _R23D36Core()
    compiled, profile = _bound_base._compile_boundary(core)
    memory = core.balanced_wave_initial_memory()
    canary = _synthetic_composition_canary(core)
    if (
        compiled.get("morphology_id") != design.MORPHOLOGY_ID
        or profile.get("policy_id") != design.POLICY_ID
        or memory.get("schema_version")
        != "sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
        or len(schedule) != design.CONTROLLER_STEPS
        or any(segment != ("reference_walk", 0.0) for segment in schedule)
    ):
        raise _core.R23D3MujocoError("QSDK_R23D36_MJC_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d36_mujoco_worker_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "engine_id": ENGINE_ID,
        "stage_id": item.stage_id,
        "cell_id": item.cell_id,
        "arm_id": item.arm_id,
        "controller_policy_id": design.POLICY_ID,
        "controller_memory_schema": memory["schema_version"],
        "stability_policy_id": design.STABILITY_POLICY_ID,
        "synthetic_composition_canary": canary,
        "fixed_controller_horizon_step_count": design.CONTROLLER_STEPS,
        "terminal_restoration_or_taper_invoked": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def _trace_row(**kwargs: Any) -> dict[str, Any]:
    row = _INHERITED_TRACE_ROW(**kwargs)
    row.update(_OVERLAY.trace_fields(int(kwargs["semantic_step"])))
    return row


for name, value in {
    "design": design,
    "evaluator": evaluator,
    "base": _bound_base,
    "LocomotionCore": _R23D36Core,
    "PREREGISTRATION_PATH": PREREGISTRATION_PATH,
    "PHYSICAL_EVALUATOR_PATH": evaluator.__file__,
    "CLOSURE_PATH": CLOSURE_PATH,
    "WORKER_PATH": WORKER_PATH,
    "CAMPAIGN_ID": design.CAMPAIGN_ID,
    "GATE_ID": design.GATE_ID,
    "REPORT_SCHEMA": evaluator.REPORT_SCHEMA,
    "FAILURE_SCHEMA": evaluator.FAILURE_SCHEMA,
    "FREEZE_SCHEMA": FREEZE_SCHEMA,
    "ATTEMPT_SCHEMA": ATTEMPT_SCHEMA,
    "SCHEDULE_ID": "qsdk_r23d36_reference_walk_v1",
    "CONTROLLER_STEPS": design.CONTROLLER_STEPS,
    "ACTUATOR_COUNT": design.ACTUATOR_COUNT,
    "TURN_DURATION_STEPS": design.TURN_DURATION_STEPS,
    "TERMINAL_SETTLE_STEPS": 0,
    "FREEZE_PATH_ENV": FREEZE_PATH_ENV,
    "ATTEMPT_PATH_ENV": ATTEMPT_PATH_ENV,
    "AUTHORIZATION_TOKEN_ENV": TOKEN_ENV,
    "STAGE_ID_ENV": STAGE_ENV,
    "CELL_ID_ENV": CELL_ENV,
    "ENGINE_ID_ENV": ENGINE_ENV,
    "ATTEMPT_ROOT_ENV": ATTEMPT_ROOT_ENV,
    "PYTHON_ENV": PYTHON_ENV,
    "POWERSHELL_ENV": POWERSHELL_ENV,
    "_cell": _cell,
    "_contract": _contract,
    "_source_bindings_exact": _source_bindings_exact,
    "_physical_authorization": _physical_authorization,
    "_retain_trace": _retain_trace,
    "_trace_row": _trace_row,
    "run_preflight": run_preflight,
}.items():
    setattr(_core, name, value)


def run_physical(stage_id: str, onset_id: str, arm_id: str, source_commit: str) -> dict[str, Any]:
    report = _core.run_physical(stage_id, onset_id, arm_id, source_commit)
    summary = _OVERLAY.summary()
    report["measurements"].update(summary)
    report["execution"].update(summary)
    report["execution"]["integrity_passed"] = bool(
        report["execution"]["integrity_passed"]
        and summary["stability_composition_integrity_passed"]
        and summary["stability_composition_step_count"] == design.CONTROLLER_STEPS
    )
    return report


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("preflight", "physical"))
    parser.add_argument("--stage", required=True)
    parser.add_argument("--onset", default="onset_600")
    parser.add_argument("--arm", required=True)
    parser.add_argument("--source-commit", default="")
    args = parser.parse_args(argv)
    try:
        if args.command == "preflight":
            value = run_preflight(args.stage, args.onset, args.arm)
            marker = "QSDK_R23D36_MUJOCO_PREFLIGHT "
        else:
            value = run_physical(args.stage, args.onset, args.arm, args.source_commit)
            marker = "QSDK_R23D36_MUJOCO_TERMINAL "
        print(marker + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    except _core.R23D3MujocoError as error:
        value = error.terminal_receipt or {"failure_code": error.code}
        print(
            "QSDK_R23D36_MUJOCO_TERMINAL "
            + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
