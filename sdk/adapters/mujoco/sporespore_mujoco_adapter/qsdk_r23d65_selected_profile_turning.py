"""Dormant native MuJoCo worker for the prospective R23D65 finite decision.

All public preflight and authorization-control paths return before ``MjModel``
construction.  The physical path is available only to the later one-shot
supervisor.  Once authorized it consumes the exact full model XML produced by
``qsdk_r23d65_public_profile_route``, reads the eight native force ranges before
the first solver step, executes the unchanged R23D29 schedule, and retains the
full-precision trace through the canonical prospective evaluator.
"""

from __future__ import annotations

import argparse
import copy
from dataclasses import dataclass
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import subprocess
import sys
from types import ModuleType, SimpleNamespace
from typing import Any, Mapping, Sequence

import mujoco
import numpy as np

SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
TURNING_ROOT = SDK_ROOT / "turning"
SDK_PYTHON = SDK_ROOT / "python"
if str(SDK_PYTHON) not in sys.path:
    sys.path.insert(0, str(SDK_PYTHON))
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

from sporespore_locomotion import LocomotionCore  # noqa: E402

from . import qsdk_r23d2_heading_response as inherited_base  # noqa: E402
from . import selected_policy_development as bridge  # noqa: E402
from .actuator_cap_profile import (  # noqa: E402
    CONTROLLER_DT_S,
    HOST_MAPPING_ID,
    ORDERED_ACTUATOR_IDS,
    ORDERED_CAPS_NMS,
    ORDERED_JOINT_IDS,
    PROFILE_ID,
    PROFILE_SHA256,
)
from .qsdk_r23d65_public_profile_route import (  # noqa: E402
    PublicProfileModelRoute,
    R23D65MujocoRouteError,
    compile_public_profile_model_route,
    physical_binding_receipt,
)

import r23d45_support_loss_conditioned_startup as startup  # noqa: E402
import r23d65_selected_profile_three_engine_turning_validation as public_design  # noqa: E402
import r23d65_selected_profile_three_engine_turning_validation_evaluator as evaluator  # noqa: E402


def _load_private_fixed_horizon_worker() -> ModuleType:
    """Load the accepted loop privately so consumed wrappers stay immutable."""

    source = Path(__file__).with_name("qsdk_r23d3_phase_balanced.py")
    specification = importlib.util.spec_from_file_location(
        "sporespore_mujoco_adapter._qsdk_r23d65_fixed_horizon_core",
        source,
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("QSDK_R23D65_MJC_INHERITED_WORKER_UNAVAILABLE")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


_core = _load_private_fixed_horizon_worker()
_INHERITED_TRACE_ROW = _core._trace_row

CAMPAIGN_ID = public_design.CAMPAIGN_ID
GATE_ID = public_design.GATE_ID
STAGE_ID = public_design.STAGE_ID
ENGINE_ID = "mujoco"
ONSET_ID = "onset_600"
CAMPAIGN_SEED = public_design.CAMPAIGN_SEED
POLICY_ID = public_design.POLICY_ID
TASK_ORIGIN_POLICY_ID = public_design.TASK_ORIGIN_POLICY_ID
TRACE_TRANSPORT_ID = "sporespore_r23d65_full_precision_native_trace_transport_v1"
ACTUATOR_PHASE_OBSERVATION_SCHEMA = (
    "sporespore_godot_jolt_actuator_phase_observation_v1"
)
APPLICATION_RECEIPT_SCHEMA = (
    "sporespore_godot_jolt_full_authority_application_receipt_v1"
)
PREFLIGHT_SCHEMA = "sporespore_qsdk_r23d65_mujoco_physical_worker_preflight_v1"
AUTHORIZATION_PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r23d65_mujoco_production_authorization_preflight_v1"
)
REPORT_SCHEMA = evaluator.REPORT_SCHEMA
FAILURE_SCHEMA = evaluator.FAILURE_SCHEMA
TRACE_RETENTION_SCHEMA = evaluator.TRACE_RETENTION_SCHEMA
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d65_turning_trace_row_v1"
PREREGISTRATION_PATH = (
    TURNING_ROOT / "r23d65_selected_profile_three_engine_turning_validation_"
    "preregistration_v1.json"
)
IMPLEMENTATION_PATH = (
    TURNING_ROOT / "r23d65_selected_profile_three_engine_turning_validation_"
    "implementation_v1.json"
)
CLOSURE_PATH = (
    TURNING_ROOT
    / "r23d65_selected_profile_three_engine_turning_validation_closure_v1.json"
)
EVALUATOR_PATH = (
    TURNING_ROOT
    / "r23d65_selected_profile_three_engine_turning_validation_evaluator.py"
)
WORKER_PATH = Path(__file__).resolve()
ROUTE_PATH = Path(__file__).with_name("qsdk_r23d65_public_profile_route.py")
CORE_LIBRARY = SDK_ROOT / "target" / "debug" / "sporespore_locomotion_core.dll"

FREEZE_SCHEMA = "sporespore_qsdk_r23d65_physical_freeze_v1"
ATTEMPT_SCHEMA = "sporespore_qsdk_r23d65_attempt_v1"
FREEZE_PATH_ENV = "SPORESPORE_QSDK_R23D65_FREEZE"
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D65_ATTEMPT"
TOKEN_ENV = "SPORESPORE_QSDK_R23D65_TOKEN"
STAGE_ENV = "SPORESPORE_QSDK_R23D65_STAGE"
CELL_ENV = "SPORESPORE_QSDK_R23D65_CELL"
ENGINE_ENV = "SPORESPORE_QSDK_R23D65_ENGINE"
ATTEMPT_ROOT_ENV = "SPORESPORE_QSDK_R23D65_ATTEMPT_ROOT"
AUTHORITY_REPO_ROOT_ENV = "SPORESPORE_QSDK_R23D65_AUTHORITY_REPO_ROOT"
PYTHON_ENV = "SPORESPORE_QSDK_R23D65_PYTHON"
POWERSHELL_ENV = "SPORESPORE_QSDK_R23D65_POWERSHELL"
EXPECTED_REANCHOR_STEPS = (600, 1_800, 2_400)
LIMB_IDS = tuple(startup.LIMB_IDS)
PHASE_OFFSETS = (0, 90, 180, 270)
TRACE_READBACK_TOLERANCE = 2.5e-7
CONFIGURATION_READBACK_TOLERANCE_NMS = 4.440892098500626e-16


def _native_json_bool(value: Any) -> bool:
    """Project NumPy and native predicates onto strict-JSON booleans."""

    return bool(value)


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _canonical_json_sha256(value: Any) -> str:
    raw = json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def _read_json(path: Path, code: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise _core.R23D3MujocoError(f"{code}:{type(error).__name__}") from error
    if not isinstance(value, dict):
        raise _core.R23D3MujocoError(code)
    return value


@dataclass(frozen=True)
class _Cell:
    stage_id: str
    cell_id: str
    engine_id: str
    onset_id: str
    turn_start_semantic_step: int
    arm_id: str
    turn_heading_offset_rad: float
    campaign_seed: int
    profile_id: str
    host_mapping_id: str


def _cells() -> list[_Cell]:
    return [
        _Cell(
            stage_id=item.stage_id,
            cell_id=item.cell_id,
            engine_id=item.engine_id,
            onset_id=ONSET_ID,
            turn_start_semantic_step=public_design.TURN_START_STEP,
            arm_id=item.arm_id,
            turn_heading_offset_rad=item.turn_heading_offset_rad,
            campaign_seed=item.campaign_seed,
            profile_id=item.profile_id,
            host_mapping_id=item.host_mapping_id,
        )
        for item in public_design.cells()
        if item.engine_id == ENGINE_ID
    ]


def _cell(stage_id: str, onset_id: str, arm_id: str) -> _Cell:
    if onset_id != ONSET_ID:
        raise _core.R23D3MujocoError(f"QSDK_R23D65_MJC_ONSET_INVALID:{onset_id}")
    matches = [
        item for item in _cells() if item.stage_id == stage_id and item.arm_id == arm_id
    ]
    if len(matches) != 1:
        raise _core.R23D3MujocoError(
            f"QSDK_R23D65_MJC_CELL_IDENTITY_INVALID:{stage_id}:{arm_id}"
        )
    return matches[0]


def _segment_for_step(item: _Cell, semantic_step: int) -> tuple[str, float]:
    matches = [value for value in _cells() if value == item]
    if len(matches) != 1 or not 0 <= semantic_step < public_design.CONTROLLER_STEPS:
        raise _core.R23D3MujocoError(
            f"QSDK_R23D65_MJC_SEMANTIC_STEP_INVALID:{semantic_step}"
        )
    if semantic_step < public_design.TURN_START_STEP:
        return "reference_warmup", 0.0
    if semantic_step < public_design.TURN_END_STEP_EXCLUSIVE:
        return "commanded_turn", item.turn_heading_offset_rad
    if semantic_step < (
        public_design.TURN_END_STEP_EXCLUSIVE + public_design.RECOVERY_DURATION_STEPS
    ):
        return "reference_recovery", 0.0
    return "after_declared_schedule", 0.0


def _expected_segment_counts(_item: _Cell) -> dict[str, int]:
    return public_design.expected_segment_counts()


_design = SimpleNamespace(
    CAMPAIGN_ID=CAMPAIGN_ID,
    GATE_ID=GATE_ID,
    Cell=_Cell,
    ACTUATOR_COUNT=public_design.ACTUATOR_COUNT,
    CONTROLLER_STEPS=public_design.CONTROLLER_STEPS,
    TURN_DURATION_STEPS=(
        public_design.TURN_END_STEP_EXCLUSIVE - public_design.TURN_START_STEP
    ),
    GAIT_CYCLE_STEPS=startup.GAIT_CYCLE_STEPS,
    LIMB_IDS=LIMB_IDS,
    PHASE_OFFSETS=PHASE_OFFSETS,
    TRACE_ROW_SCHEMA=TRACE_ROW_SCHEMA,
    segment_for_step=_segment_for_step,
    expected_segment_counts=_expected_segment_counts,
    stage_a_cells=lambda: [],
    stage_b_cells=lambda _onset: _cells(),
)
_evaluator = SimpleNamespace(
    REPORT_SCHEMA=REPORT_SCHEMA,
    FAILURE_SCHEMA=FAILURE_SCHEMA,
    TRACE_RETENTION_SCHEMA=TRACE_RETENTION_SCHEMA,
    FALSE_CLAIMS=evaluator.FALSE_CLAIMS,
)


@dataclass
class _RuntimeCapture:
    route: PublicProfileModelRoute | None = None
    physical_binding: dict[str, Any] | None = None
    controller_commands: dict[int, list[dict[str, Any]]] | None = None
    native_applications: dict[int, list[dict[str, Any]]] | None = None
    task_origins: dict[int, dict[str, Any]] | None = None
    task_origin_reanchor_count: int = 0

    def reset(self) -> None:
        self.route = None
        self.physical_binding = None
        self.controller_commands = {}
        self.native_applications = {}
        self.task_origins = {}
        self.task_origin_reanchor_count = 0


_RUNTIME = _RuntimeCapture()
_RUNTIME.reset()


class _StartupRampRun:
    """Bind the inherited support-loss startup transform to every step."""

    def __init__(self) -> None:
        self.reset()

    def reset(self) -> None:
        self.governor = startup.SupportLossConditionedStartup()
        self.pending_contacts: dict[int, dict[str, bool]] = {}
        self.rows: dict[int, dict[str, Any]] = {}
        self.composition_step_count = 0
        self.ramped_step_count = 0
        self.exact_zero_scale_step_count = 0
        self.exact_unity_scale_step_count = 0
        self.maximum_absolute_residual_rad_s = 0.0

    def capture_contacts(
        self,
        semantic_step: int,
        contacts: Mapping[str, bool],
    ) -> None:
        if semantic_step in self.pending_contacts or semantic_step in self.rows:
            raise RuntimeError("QSDK_R23D65_MJC_CONTACT_CAPTURE_DUPLICATE")
        self.pending_contacts[semantic_step] = {
            limb_id: bool(contacts[limb_id]) for limb_id in LIMB_IDS
        }

    def compose(self, actuation: dict[str, Any]) -> list[dict[str, Any]]:
        semantic_step = int(actuation.get("semantic_step", -1))
        commands = actuation.get("ordered_commands")
        try:
            contacts = self.pending_contacts.pop(semantic_step)
        except KeyError as error:
            raise RuntimeError("QSDK_R23D65_MJC_CONTACT_CAPTURE_MISSING") from error
        if (
            semantic_step in self.rows
            or not isinstance(commands, list)
            or len(commands) != public_design.ACTUATOR_COUNT
            or _RUNTIME.controller_commands is None
            or semantic_step in _RUNTIME.controller_commands
        ):
            raise RuntimeError("QSDK_R23D65_MJC_TRANSFORM_STEP_BINDING_INVALID")
        _RUNTIME.controller_commands[semantic_step] = copy.deepcopy(commands)
        receipt = self.governor.step(semantic_step, contacts)
        scale = float(receipt["startup_velocity_scale"])
        residuals: list[dict[str, Any]] = []
        maximum = 0.0
        for command in commands:
            actuator_id = command.get("actuator_id")
            legacy_velocity = float(command.get("target_velocity_rad_s", float("nan")))
            portable_canonical = -legacy_velocity
            delta = portable_canonical * (scale - 1.0)
            if not isinstance(actuator_id, str) or not all(
                math.isfinite(value) for value in (legacy_velocity, delta)
            ):
                raise RuntimeError("QSDK_R23D65_MJC_TRANSFORM_NONFINITE")
            maximum = max(maximum, abs(delta))
            residuals.append(
                {
                    "schema_version": "sporespore_canonical_velocity_residual_v1",
                    "actuator_id": actuator_id,
                    "canonical_velocity_delta_rad_s": delta,
                    "command_not_measurement": True,
                    "physical_acceptance_authority": False,
                }
            )
        receipt.update(
            startup_ramp_id=public_design.STARTUP_TRANSFORM_ID,
            startup_ramp_residual_count=len(residuals),
            startup_ramp_maximum_absolute_residual_rad_s=maximum,
            startup_transform_residual_count=len(residuals),
            startup_transform_maximum_absolute_residual_rad_s=maximum,
        )
        self.rows[semantic_step] = receipt
        self.composition_step_count += 1
        self.ramped_step_count += int(scale < 1.0)
        self.exact_zero_scale_step_count += int(scale == 0.0)
        self.exact_unity_scale_step_count += int(scale == 1.0)
        self.maximum_absolute_residual_rad_s = max(
            self.maximum_absolute_residual_rad_s,
            maximum,
        )
        return residuals

    def trace_fields(self, semantic_step: int) -> dict[str, Any]:
        try:
            return self.rows.pop(semantic_step)
        except KeyError as error:
            raise RuntimeError(
                "QSDK_R23D65_MJC_TRANSFORM_TRACE_BINDING_INVALID"
            ) from error

    def summary(self) -> dict[str, Any]:
        return {
            "startup_ramp_id": public_design.STARTUP_TRANSFORM_ID,
            "startup_transform_id": public_design.STARTUP_TRANSFORM_ID,
            "startup_ramp_step_count": startup.GAIT_CYCLE_STEPS,
            "startup_probe_last_semantic_step": startup.PROBE_LAST_SEMANTIC_STEP,
            "startup_ramp_triggered": self.governor.trigger_step is not None,
            "startup_ramp_trigger_step": self.governor.trigger_step,
            "startup_probe_minimum_support_count": (
                self.governor.minimum_probe_support_count
            ),
            "startup_ramp_composition_step_count": self.composition_step_count,
            "startup_ramp_active_step_count": self.ramped_step_count,
            "startup_ramp_exact_zero_scale_step_count": (
                self.exact_zero_scale_step_count
            ),
            "startup_ramp_exact_unity_scale_step_count": (
                self.exact_unity_scale_step_count
            ),
            "maximum_absolute_startup_ramp_residual_rad_s": (
                self.maximum_absolute_residual_rad_s
            ),
            "startup_ramp_composition_integrity_passed": (
                not self.pending_contacts
                and not self.rows
                and self.composition_step_count == public_design.CONTROLLER_STEPS
            ),
            "startup_transform_composition_integrity_passed": (
                not self.pending_contacts
                and not self.rows
                and self.composition_step_count == public_design.CONTROLLER_STEPS
            ),
        }


_RAMP = _StartupRampRun()


class _R23D65Core(LocomotionCore):
    def balanced_wave_initial_memory(self) -> dict[str, Any]:
        return self.balanced_wave_policy_initial_memory(
            POLICY_ID,
            inherited_base.bridge.s169_descriptor(),
        )


class R23D65MujocoRobot(bridge.MujocoBw19vRobot):
    """One genuine MuJoCo fixture built from the public-profile route XML."""

    def __init__(
        self,
        core: LocomotionCore,
        profile_id: str,
        route: PublicProfileModelRoute,
    ) -> None:
        if profile_id != bridge.PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID:
            raise R23D65MujocoRouteError(
                "QSDK_R23D65_MJC_HOST_PROFILE_IDENTITY_INVALID"
            )
        self.core = core
        self.profile_id = profile_id
        self.descriptor = inherited_base.bridge.s169_descriptor()
        self.compiled = route.compiled
        self.morphology = self.compiled["morphology"]
        self.spec = self.morphology["morphology_spec"]
        self.model_xml = route.model_xml
        self.model = mujoco.MjModel.from_xml_string(self.model_xml)

        # This receipt is completed from MjModel configuration before MjData,
        # mj_forward, mj_step1, or mj_step2 can execute.
        self.r23d65_physical_binding = physical_binding_receipt(
            self.model,
            route,
        )
        _RUNTIME.physical_binding = copy.deepcopy(self.r23d65_physical_binding)
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
        self._validate_public_profile_model()

    def _validate_public_profile_model(self) -> None:
        if self.model.nu != 8 or self.model.njnt != 9 or self.model.nbody != 10:
            raise RuntimeError("QSDK_R23D65_MJC_MODEL_CARDINALITY_MISMATCH")
        if not math.isclose(
            float(self.model.opt.timestep),
            bridge.INTERNAL_DT_S,
        ):
            raise RuntimeError("QSDK_R23D65_MJC_INTERNAL_TIMESTEP_MISMATCH")
        if int(self.model.opt.integrator) != int(
            mujoco.mjtIntegrator.mjINT_IMPLICITFAST
        ):
            raise RuntimeError("QSDK_R23D65_MJC_INTEGRATOR_MISMATCH")
        for index, (actuator_id, cap) in enumerate(
            zip(ORDERED_ACTUATOR_IDS, ORDERED_CAPS_NMS, strict=True)
        ):
            native_id = self.actuator_ids[actuator_id]
            force_range = np.asarray(
                self.model.actuator_forcerange[native_id],
                dtype=np.float64,
            )
            readback_cap = float(force_range[1]) * CONTROLLER_DT_S
            if (
                float(self.model.actuator_gainprm[native_id, 0]) != bridge.VELOCITY_GAIN
                or float(self.model.actuator_biasprm[native_id, 2])
                != -bridge.VELOCITY_GAIN
                or not bool(self.model.actuator_forcelimited[native_id])
                or float(force_range[0]) != -float(force_range[1])
                or abs(readback_cap - cap) > CONFIGURATION_READBACK_TOLERANCE_NMS
            ):
                raise RuntimeError(f"QSDK_R23D65_MJC_MODEL_PROFILE_MISMATCH:{index}")

    def apply_host_mapping(self, mapping: dict[str, Any]) -> dict[str, Any]:
        if (
            mapping.get("host_profile_id") != self.profile_id
            or mapping.get("engine_id") != ENGINE_ID
            or mapping.get("independent_native_position_feedback_applied") is not False
            or mapping.get("native_position_stiffness") != 0.0
            or mapping.get("host_response_characterized_for_this_profile") is not True
        ):
            raise RuntimeError("QSDK_R23D65_MJC_HOST_MAPPING_CONTRACT_MISMATCH")
        semantic_step = int(mapping.get("semantic_step", -1))
        commands = mapping.get("ordered_commands")
        if (
            not isinstance(commands, list)
            or len(commands) != len(ORDERED_ACTUATOR_IDS)
            or _RUNTIME.controller_commands is None
            or semantic_step not in _RUNTIME.controller_commands
            or _RUNTIME.native_applications is None
            or semantic_step in _RUNTIME.native_applications
        ):
            raise RuntimeError("QSDK_R23D65_MJC_HOST_COMMAND_CONTAINER_INVALID")
        controller_commands = _RUNTIME.controller_commands.pop(semantic_step)
        targets = np.empty(8, dtype=np.float64)
        portable_limits = np.asarray(ORDERED_CAPS_NMS, dtype=np.float64)
        ordered_applications: list[dict[str, Any]] = []
        for index, (command, controller, actuator_id, joint_id, cap) in enumerate(
            zip(
                commands,
                controller_commands,
                ORDERED_ACTUATOR_IDS,
                ORDERED_JOINT_IDS,
                ORDERED_CAPS_NMS,
                strict=True,
            )
        ):
            if (
                command.get("actuator_id") != actuator_id
                or controller.get("actuator_id") != actuator_id
                or command.get("native_target_position_rad") is not None
            ):
                raise RuntimeError(
                    f"QSDK_R23D65_MJC_HOST_COMMAND_ORDER_INVALID:{index}"
                )
            targets[index] = float(command["host_target_velocity_rad_s"])
            native_id = self.actuator_ids[actuator_id]
            force_range = self.model.actuator_forcerange[native_id]
            cap_readback = float(force_range[1]) * CONTROLLER_DT_S
            cap_error = abs(cap_readback - cap)
            maximum_speed = float(command["maximum_host_target_speed_rad_s"])
            requested = float(command["requested_target_position_rad"])
            clamped = float(command["clamped_target_position_rad"])
            ordered_applications.append(
                {
                    "actuator_id": actuator_id,
                    "joint_id": joint_id,
                    "host_joint_id": joint_id,
                    "requested_target_position_rad": requested,
                    "clamped_target_position_rad": clamped,
                    "controller_target_velocity_rad_s": targets[index],
                    "maximum_target_speed_rad_s": maximum_speed,
                    "host_applied_target_velocity_rad_s": targets[index],
                    "motor_target_velocity_readback_rad_s": 0.0,
                    "motor_target_velocity_readback_error_rad_s": 0.0,
                    "declared_maximum_impulse_nms": cap,
                    "motor_maximum_impulse_readback_nms": cap_readback,
                    "motor_maximum_impulse_readback_error_nms": cap_error,
                    "position_saturated": bool(
                        controller.get(
                            "position_saturated",
                            requested != clamped,
                        )
                    ),
                    "velocity_saturated": bool(
                        controller.get(
                            "velocity_saturated",
                            abs(targets[index])
                            >= maximum_speed - np.finfo(np.float64).eps,
                        )
                    ),
                    "slew_limited": bool(controller.get("slew_limited", False)),
                    "host_additional_clamp_applied": False,
                    "target_velocity_readback_matches": False,
                    "maximum_impulse_readback_matches": _native_json_bool(
                        cap_error <= CONFIGURATION_READBACK_TOLERANCE_NMS
                    ),
                }
            )

        cumulative_absolute_force_time = np.zeros(8, dtype=np.float64)
        maximum_force = np.zeros(8, dtype=np.float64)
        for substep in range(bridge.INTERNAL_STEPS_PER_OUTER):
            if substep > 0:
                mujoco.mj_step1(self.model, self.data)
            self.data.ctrl[:] = targets
            readback = np.asarray(self.data.ctrl, dtype=np.float64).copy()
            if not np.array_equal(readback, targets):
                raise RuntimeError("QSDK_R23D65_MJC_CONTROL_READBACK_MISMATCH")
            if substep == 0:
                for index, application in enumerate(ordered_applications):
                    target_error = abs(float(readback[index]) - targets[index])
                    application["motor_target_velocity_readback_rad_s"] = float(
                        readback[index]
                    )
                    application["motor_target_velocity_readback_error_rad_s"] = (
                        target_error
                    )
                    application["target_velocity_readback_matches"] = _native_json_bool(
                        target_error <= TRACE_READBACK_TOLERANCE
                    )
            mujoco.mj_step2(self.model, self.data)
            forces = np.abs(np.asarray(self.data.actuator_force, dtype=np.float64))
            cumulative_absolute_force_time += forces * bridge.INTERNAL_DT_S
            maximum_force = np.maximum(maximum_force, forces)

        if not all(
            item["target_velocity_readback_matches"]
            and item["maximum_impulse_readback_matches"]
            for item in ordered_applications
        ):
            raise RuntimeError("QSDK_R23D65_MJC_APPLICATION_READBACK_MISMATCH")
        _RUNTIME.native_applications[semantic_step] = ordered_applications
        return {
            "targets": targets.tolist(),
            "cumulative_absolute_force_time_nms": (
                cumulative_absolute_force_time.tolist()
            ),
            "portable_maximum_outer_impulse_nms": portable_limits.tolist(),
            "portable_impulse_violation_count": int(
                np.count_nonzero(
                    cumulative_absolute_force_time > portable_limits + 1.0e-12
                )
            ),
            "maximum_absolute_actuator_force_nm": maximum_force.tolist(),
        }


class _BridgeBound:
    def __init__(self, wrapped: ModuleType) -> None:
        self._wrapped = wrapped

    def __getattr__(self, name: str) -> Any:
        return getattr(self._wrapped, name)

    def MujocoBw19vRobot(
        self,
        core: LocomotionCore,
        profile_id: str,
    ) -> R23D65MujocoRobot:
        if _RUNTIME.route is None:
            raise R23D65MujocoRouteError(
                "QSDK_R23D65_MJC_PRODUCTION_ROUTE_NOT_COMPILED"
            )
        return R23D65MujocoRobot(core, profile_id, _RUNTIME.route)


class _PolicyBoundBase:
    POLICY_ID = POLICY_ID
    CAMPAIGN_SEED = CAMPAIGN_SEED

    def __init__(self, wrapped: ModuleType) -> None:
        self._wrapped = wrapped
        self.bridge = _BridgeBound(wrapped.bridge)

    def __getattr__(self, name: str) -> Any:
        return getattr(self._wrapped, name)

    def _compile_boundary(
        self,
        core: LocomotionCore,
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        compiled, profile = self._wrapped._compile_boundary(
            core,
            policy_id=POLICY_ID,
        )
        _RUNTIME.route = compile_public_profile_model_route(
            core,
            compiled=compiled,
        )
        return compiled, profile

    def _initial_perturbation(self, _development: dict[str, Any]) -> dict[str, Any]:
        return copy.deepcopy(public_design.INITIAL_PERTURBATION)

    def _state_frame(
        self,
        robot: Any,
        semantic_step: int,
        task_origin: np.ndarray,
        reference_heading_rad: float,
    ) -> dict[str, Any]:
        reanchored = semantic_step in EXPECTED_REANCHOR_STEPS
        metrics = robot.torso_metrics()
        command_time_position = [
            float(metrics["x"]),
            float(metrics["y"]),
            float(metrics["z"]),
        ]
        if reanchored:
            task_origin[:] = np.asarray(command_time_position, dtype=np.float64)
            _RUNTIME.task_origin_reanchor_count += 1
        if _RUNTIME.task_origins is None or semantic_step in _RUNTIME.task_origins:
            raise RuntimeError("QSDK_R23D65_MJC_TASK_ORIGIN_CAPTURE_DUPLICATE")
        _RUNTIME.task_origins[semantic_step] = {
            "task_frame_origin_world_m": [
                float(task_origin[0]),
                float(task_origin[1]),
                float(task_origin[2]),
            ],
            "torso_position_world_m": command_time_position,
            "task_frame_origin_reanchored_this_step": reanchored,
            "task_frame_origin_reanchor_count": (_RUNTIME.task_origin_reanchor_count),
        }
        state = self._wrapped._state_frame(
            robot,
            semantic_step,
            task_origin,
            reference_heading_rad,
        )
        _RAMP.capture_contacts(
            semantic_step,
            self._wrapped._foot_contacts(robot),
        )
        return state

    def _zero_residuals(self, actuation: dict[str, Any]) -> list[dict[str, Any]]:
        return _RAMP.compose(actuation)


_bound_base = _PolicyBoundBase(inherited_base)


def _contract() -> dict[str, Any]:
    if CLOSURE_PATH.is_file():
        raise _core.R23D3MujocoError("QSDK_R23D65_MJC_CLOSED")
    declaration = _read_json(
        PREREGISTRATION_PATH,
        "QSDK_R23D65_MJC_DECLARATION_UNREADABLE",
    )
    try:
        public_design.validate_declaration(declaration)
    except public_design.DeclarationError as error:
        raise _core.R23D3MujocoError(
            f"QSDK_R23D65_MJC_DECLARATION_INVALID:{error}"
        ) from error
    implementation = _read_json(
        IMPLEMENTATION_PATH,
        "QSDK_R23D65_MJC_IMPLEMENTATION_UNREADABLE",
    )
    worker = implementation.get("workers", {}).get("mujoco", {})
    exact = (
        implementation.get("schema_version")
        == "sporespore_qsdk_r23d65_selected_profile_three_engine_turning_"
        "validation_implementation_v1"
        and implementation.get("campaign_id") == CAMPAIGN_ID
        and implementation.get("gate_id") == GATE_ID
        and implementation.get("question_class") == "finite_decision"
        and implementation.get("physical_campaign_opened") is False
        and implementation.get("implemented_native_dependency_route_count") == 3
        and implementation.get("implemented_native_worker_count") == 3
        and isinstance(worker, dict)
        and worker.get("path") == WORKER_PATH.relative_to(REPO_ROOT).as_posix()
        and worker.get("raw_sha256") == _raw_sha256(WORKER_PATH)
        and worker.get("production_public_profile_route_path")
        == ROUTE_PATH.relative_to(REPO_ROOT).as_posix()
        and worker.get("production_public_profile_route_raw_sha256")
        == _raw_sha256(ROUTE_PATH)
        and worker.get("implementation_complete") is True
        and worker.get("zero_world_dependency_route_gate_passed") is True
        and worker.get("zero_world_worker_gate_passed") is True
        and worker.get("physical_execution_authorized") is False
        and implementation.get("claims", {}).get(
            "mujoco_worker_implementation_complete"
        )
        is True
        and implementation.get("claims", {}).get("native_routes_and_workers_complete")
        is True
        and implementation.get("claims", {}).get("implementation_complete") is True
        and implementation.get("claims", {}).get("complete_zero_world_gate_passed")
        is True
        and implementation.get("claims", {}).get(
            "complete_transitive_dependency_inventory_proved"
        )
        is True
        and implementation.get("claims", {}).get("q_sdk_r23_satisfied") is False
    )
    if not exact:
        raise _core.R23D3MujocoError("QSDK_R23D65_MJC_IMPLEMENTATION_IDENTITY_INVALID")
    return declaration


def _source_bindings_exact(
    freeze: dict[str, Any],
    implementation: dict[str, Any],
) -> bool:
    expected = implementation.get("dependency_closure", {}).get(
        "expected_transitive_paths"
    )
    bindings = freeze.get("source_bindings")
    inventory = freeze.get("dependency_inventory")
    if (
        not isinstance(expected, list)
        or not expected
        or not isinstance(bindings, list)
        or len(bindings) != len(expected)
        or not isinstance(inventory, dict)
        or inventory.get("ordered_paths") != expected
        or inventory.get("transitive_path_count") != len(expected)
    ):
        return False
    observed: dict[str, str] = {}
    for item in bindings:
        if not isinstance(item, dict):
            return False
        path = item.get("path")
        digest = item.get("raw_sha256")
        if (
            not isinstance(path, str)
            or not path
            or path in observed
            or not isinstance(digest, str)
            or not _core._valid_lower_hex(digest.removeprefix("sha256:"), 64)
        ):
            return False
        observed[path] = digest
    return all(
        isinstance(path, str)
        and path
        and (REPO_ROOT / path).is_file()
        and observed.get(path) == _raw_sha256(REPO_ROOT / path)
        for path in expected
    )


def _expected_matrix_cell_ids() -> list[str]:
    return [item.cell_id for item in public_design.cells()]


def _same_path(left: Any, right: Path) -> bool:
    try:
        return Path(str(left)).resolve(strict=True) == right.resolve(strict=True)
    except OSError:
        return False


def _receipt_schema_conformance_exact(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and value.get("schema_version")
        == "sporespore_qsdk_r23d65_authorization_receipt_schema_conformance_v1"
        and value.get("campaign_id") == CAMPAIGN_ID
        and value.get("gate_id") == GATE_ID
        and value.get("question_class") == "equivalence_non_inferiority"
        and value.get("declared_producer_count") == 3
        and value.get("conforming_producer_count") == 3
        and value.get("required_field")
        == "complete_ordered_nine_cell_matrix_validated"
        and value.get("required_json_type") == "boolean"
        and type(value.get("required_value")) is bool
        and value.get("required_value") is True
        and value.get("equivalence_margin") == 0
        and value.get("non_inferiority_margin") == 0
        and value.get("sampling_used") is False
        and value.get("total_negative_control_count") == 12
        and value.get("negative_controls_passed") == 12
        and value.get("model_construction_count") == 0
        and value.get("world_attempt_count") == 0
        and value.get("world_build_count") == 0
        and value.get("physical_equivalence_claimed") is False
        and value.get("physical_acceptance_authority") is False
    )


def _physical_authorization(
    item: _Cell,
    source_commit: str,
) -> dict[str, Any]:
    freeze_path = Path(os.environ.get(FREEZE_PATH_ENV, ""))
    attempt_path = Path(os.environ.get(ATTEMPT_PATH_ENV, ""))
    attempt_root = Path(os.environ.get(ATTEMPT_ROOT_ENV, ""))
    authority_repo_root_raw = os.environ.get(AUTHORITY_REPO_ROOT_ENV, "")
    token = os.environ.get(TOKEN_ENV, "")
    if (
        not IMPLEMENTATION_PATH.is_file()
        or not freeze_path.is_file()
        or not attempt_path.is_file()
        or not attempt_root.is_dir()
        or not _core._valid_lower_hex(token, 32)
        or not authority_repo_root_raw
    ):
        raise _core.R23D3MujocoError("QSDK_R23D65_MJC_PHYSICAL_AUTHORIZATION_REQUIRED")
    implementation = _read_json(
        IMPLEMENTATION_PATH,
        "QSDK_R23D65_MJC_IMPLEMENTATION_UNREADABLE",
    )
    freeze = _read_json(freeze_path, "QSDK_R23D65_MJC_FREEZE_UNREADABLE")
    attempt = _read_json(attempt_path, "QSDK_R23D65_MJC_ATTEMPT_UNREADABLE")
    try:
        authority_repo_root = Path(authority_repo_root_raw).resolve(strict=True)
        evidence_root = (authority_repo_root.parent / "SporeSpore_Evidence").resolve(
            strict=True
        )
        canonical_attempt_root = attempt_root.resolve(strict=True)
        canonical_attempt_root.relative_to(evidence_root)
    except (OSError, ValueError) as error:
        raise _core.R23D3MujocoError(
            "QSDK_R23D65_MJC_AUTHORIZATION_PATH_INVALID"
        ) from error

    inventory = freeze.get("dependency_inventory", {})
    zero_world = freeze.get("zero_world_receipt", {})
    freeze_receipt_schema = freeze.get("authorization_receipt_schema_conformance")
    attempt_receipt_schema = attempt.get("authorization_receipt_schema_conformance")
    frozen_inputs = freeze.get("content_addressed_inputs", {})
    adoption_input = (
        frozen_inputs.get("campaign_attestation_adoption", {})
        if isinstance(frozen_inputs, dict)
        else {}
    )
    dependency_policy = implementation.get("dependency_closure", {})
    exact = (
        freeze.get("schema_version") == FREEZE_SCHEMA
        and freeze.get("campaign_id") == CAMPAIGN_ID
        and freeze.get("gate_id") == GATE_ID
        and freeze.get("status") == "frozen_supervisor_only_physical_authorized"
        and freeze.get("preregistration_raw_sha256")
        == _raw_sha256(PREREGISTRATION_PATH)
        and freeze.get("implementation_contract_raw_sha256")
        == _raw_sha256(IMPLEMENTATION_PATH)
        and freeze.get("source_commit") == source_commit
        and freeze.get("origin_main_commit") == source_commit
        and freeze.get("live_github_main_commit") == source_commit
        and _core._valid_lower_hex(freeze.get("source_tree_git_oid"), 40)
        and freeze.get("complete_zero_world_gate_passed") is True
        and isinstance(zero_world, dict)
        and zero_world.get("campaign_id") == CAMPAIGN_ID
        and zero_world.get("gate_id") == GATE_ID
        and zero_world.get("model_construction_count") == 0
        and zero_world.get("world_attempt_count") == 0
        and zero_world.get("world_build_count") == 0
        and zero_world.get("physical_execution_authorized") is False
        and zero_world.get("physical_acceptance_authority") is False
        and _receipt_schema_conformance_exact(freeze_receipt_schema)
        and attempt_receipt_schema == freeze_receipt_schema
        and zero_world.get("authorization_receipt_schema_conformance")
        == freeze_receipt_schema
        and freeze.get(
            "authorization_receipt_schema_conformance_passed_before_freeze"
        )
        is True
        and attempt.get(
            "authorization_receipt_schema_conformance_passed_before_attempt"
        )
        is True
        and freeze.get("dependency_inventory_complete") is True
        and isinstance(inventory, dict)
        and inventory.get("schema_version")
        == "sporespore_qsdk_r23d65_dependency_inventory_v1"
        and inventory.get("policy_id")
        == "r23d65_declared_roots_recursive_local_language_closure_v1"
        and inventory.get("inventory_projection_sha256")
        == dependency_policy.get("expected_inventory_projection_sha256")
        and inventory.get("expected_transitive_path_set_exact") is True
        and inventory.get("all_paths_tracked_with_exact_case") is True
        and inventory.get("checkout_bytes_equal_git_blobs") is True
        and inventory.get("model_construction_count") == 0
        and inventory.get("world_attempt_count") == 0
        and inventory.get("world_build_count") == 0
        and freeze.get("source_bindings") == inventory.get("source_receipts")
        and freeze.get("declared_world_count") == 9
        and freeze.get("ordered_matrix_cell_ids") == _expected_matrix_cell_ids()
        and freeze.get("serial_execution_required") is True
        and freeze.get("all_cells_run_regardless_of_intermediate_outcome") is True
        and freeze.get("terminal_restoration_or_taper_invoked") is False
        and freeze.get("source_checkout_bytes_equal_git_blobs") is True
        and freeze.get("reproducible_runtime_materialization_passed") is True
        and isinstance(adoption_input, dict)
        and freeze.get("campaign_attestation_adoption_sha256")
        == adoption_input.get("sha256")
        and freeze.get("physical_execution_authorized") is True
        and _source_bindings_exact(freeze, implementation)
        and attempt.get("schema_version") == ATTEMPT_SCHEMA
        and attempt.get("campaign_id") == CAMPAIGN_ID
        and attempt.get("gate_id") == GATE_ID
        and attempt.get("freeze_raw_sha256") == _raw_sha256(freeze_path)
        and attempt.get("source_commit") == source_commit
        and attempt.get("authorization_token") == token
        and _core._valid_lower_hex(attempt.get("attempt_id"), 32)
        and attempt.get("physical_execution_authorized") is True
        and attempt.get("single_use_supervisor_authorization") is True
        and attempt.get("matrix_authorization_immutable_before_first_world") is True
        and attempt.get("source_worktree_clean") is True
        and attempt.get("source_matches_live_github_main") is True
        and attempt.get("operation_lock_held") is True
        and attempt.get("campaign_attestation_adoption_valid") is True
        and attempt.get("content_addressed_inputs_retained") is True
        and attempt.get("content_addressed_inputs") == frozen_inputs
        and attempt.get("one_shot_attempt_unconsumed") is True
        and attempt.get("all_cells_run_regardless_of_intermediate_outcome") is True
        and _same_path(attempt.get("attempt_root"), canonical_attempt_root)
        and _same_path(attempt.get("authority_repo_root"), authority_repo_root)
        and attempt.get("ordered_matrix_cell_ids") == _expected_matrix_cell_ids()
        and os.environ.get(STAGE_ENV) == item.stage_id
        and os.environ.get(CELL_ENV) == item.cell_id
        and os.environ.get(ENGINE_ENV) == ENGINE_ID
    )
    if not exact:
        raise _core.R23D3MujocoError("QSDK_R23D65_MJC_PHYSICAL_AUTHORIZATION_INVALID")
    return {
        "freeze": freeze,
        "attempt": attempt,
        "attempt_root": canonical_attempt_root,
    }


def _retain_trace(
    item: _Cell,
    rows: list[dict[str, Any]],
    attempt_root: Path,
) -> dict[str, Any]:
    pending_root = attempt_root / "pending-traces"
    pending_root.mkdir(parents=True, exist_ok=True)
    rows_path = pending_root / f"{item.stage_id}__{item.cell_id}.rows.json"
    with rows_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(
            rows,
            stream,
            allow_nan=False,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
        stream.write("\n")
    python = os.environ.get(PYTHON_ENV, sys.executable)
    powershell = os.environ.get(POWERSHELL_ENV, "pwsh")
    process = subprocess.run(
        [
            python,
            str(EVALUATOR_PATH),
            "retain-trace",
            "--stage-id",
            item.stage_id,
            "--cell-id",
            item.cell_id,
            "--rows-json",
            str(rows_path),
            "--repo-root",
            str(REPO_ROOT),
            "--attempt-root",
            str(attempt_root),
            "--powershell",
            powershell,
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        check=False,
        text=True,
        timeout=240,
    )
    marker = "QSDK_R23D65_TRACE_RETAINED "
    matches = [
        line.removeprefix(marker)
        for line in process.stdout.splitlines()
        if line.startswith(marker)
    ]
    if process.returncode != 0 or len(matches) != 1:
        raise _core.R23D3MujocoError(
            "QSDK_R23D65_MJC_TRACE_RETENTION_FAILED:"
            f"{process.returncode}:{process.stderr[-1000:]}",
            world_attempt_count=1,
            world_build_count=1,
        )
    receipt = json.loads(matches[0])
    if (
        receipt.get("schema_version") != TRACE_RETENTION_SCHEMA
        or receipt.get("stage_id") != item.stage_id
        or receipt.get("cell_id") != item.cell_id
        or receipt.get("engine_id") != ENGINE_ID
        or receipt.get("profile_id") != PROFILE_ID
        or receipt.get("host_mapping_id") != HOST_MAPPING_ID
        or receipt.get("retained_before_terminal_entry") is not True
        or receipt.get("world_attempt_count") != 0
        or receipt.get("world_build_count") != 0
    ):
        raise _core.R23D3MujocoError(
            "QSDK_R23D65_MJC_TRACE_RETENTION_RECEIPT_INVALID",
            world_attempt_count=1,
            world_build_count=1,
        )
    return receipt


def _actuator_limb_identity(actuator_id: str) -> tuple[str, int]:
    if actuator_id.endswith("_hip_motor"):
        return actuator_id.removesuffix("_hip_motor"), 0
    if actuator_id.endswith("_knee_motor"):
        return actuator_id.removesuffix("_knee_motor"), 1
    raise RuntimeError(f"QSDK_R23D65_MJC_TRACE_ACTUATOR_ID_INVALID:{actuator_id}")


def _trace_row(**kwargs: Any) -> dict[str, Any]:
    semantic_step = int(kwargs["semantic_step"])
    row = _INHERITED_TRACE_ROW(**kwargs)
    row.update(_RAMP.trace_fields(semantic_step))
    if (
        _RUNTIME.task_origins is None
        or semantic_step not in _RUNTIME.task_origins
        or _RUNTIME.native_applications is None
        or semantic_step not in _RUNTIME.native_applications
    ):
        raise RuntimeError("QSDK_R23D65_MJC_TRACE_CAPTURE_MISSING")
    origin = _RUNTIME.task_origins.pop(semantic_step)
    applications = _RUNTIME.native_applications.pop(semantic_step)
    phase_rows = kwargs["limb_phase_before"]
    phase_by_limb = {item["limb_id"]: item for item in phase_rows}
    contacts_before = kwargs["contacts_before"]
    contacts_after = kwargs["contacts_after"]
    completed: list[dict[str, Any]] = []
    for index, (application, expected_actuator, expected_joint) in enumerate(
        zip(
            applications,
            ORDERED_ACTUATOR_IDS,
            ORDERED_JOINT_IDS,
            strict=True,
        )
    ):
        limb_id, limb_joint_index = _actuator_limb_identity(expected_actuator)
        phase = phase_by_limb.get(limb_id)
        if (
            application.get("actuator_id") != expected_actuator
            or application.get("joint_id") != expected_joint
            or not isinstance(phase, dict)
            or limb_id not in contacts_before
            or limb_id not in contacts_after
        ):
            raise RuntimeError(
                f"QSDK_R23D65_MJC_TRACE_APPLICATION_IDENTITY_INVALID:{index}"
            )
        value = copy.deepcopy(application)
        value.update(
            limb_id=limb_id,
            limb_joint_index=limb_joint_index,
            local_phase_step_before=int(phase["local_phase_step"]),
            gait_step_before=int(phase["gait_step"]),
            release_hold_step_count_before=int(phase["release_hold_step_count"]),
            foot_contact_before=bool(contacts_before[limb_id]),
            foot_contact_after=bool(contacts_after[limb_id]),
        )
        completed.append(value)

    receipt_digest = _canonical_json_sha256(kwargs["receipt"])
    row.update(
        campaign_seed=CAMPAIGN_SEED,
        profile_id=PROFILE_ID,
        task_frame_origin_policy_id=TASK_ORIGIN_POLICY_ID,
        task_frame_origin_world_m=origin["task_frame_origin_world_m"],
        torso_position_world_m=origin["torso_position_world_m"],
        task_frame_origin_reanchored_this_step=origin[
            "task_frame_origin_reanchored_this_step"
        ],
        task_frame_origin_reanchor_count=origin["task_frame_origin_reanchor_count"],
        actuator_phase_observation={
            "schema_version": ACTUATOR_PHASE_OBSERVATION_SCHEMA,
            "semantic_step": semantic_step,
            "controller_step_receipt_sha256": receipt_digest,
            "application_receipt_schema_version": APPLICATION_RECEIPT_SCHEMA,
            "ordered_actuator_ids": list(ORDERED_ACTUATOR_IDS),
            "ordered_limb_ids": list(LIMB_IDS),
            "readback_tolerance": TRACE_READBACK_TOLERANCE,
            "ordered_applications": completed,
            "after_contact_observation_complete": True,
            "configured_motor_parameters_only": True,
            "measured_motor_torque_available": False,
            "measured_motor_impulse_available": False,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
    )
    return row


def _validate_selector(
    stage_id: str,
    onset_id: str,
    campaign_seed: int,
    profile_id: str,
    arm_id: str,
) -> _Cell:
    if stage_id != STAGE_ID:
        raise _core.R23D3MujocoError("QSDK_R23D65_MJC_STAGE_INVALID")
    if onset_id != ONSET_ID:
        raise _core.R23D3MujocoError("QSDK_R23D65_MJC_ONSET_INVALID")
    if campaign_seed != CAMPAIGN_SEED:
        raise _core.R23D3MujocoError("QSDK_R23D65_MJC_CAMPAIGN_SEED_INVALID")
    if profile_id != PROFILE_ID:
        raise _core.R23D3MujocoError("QSDK_R23D65_MJC_PROFILE_INVALID")
    return _cell(stage_id, onset_id, arm_id)


def _reset_run() -> None:
    _RUNTIME.reset()
    _RAMP.reset()


def run_preflight(
    stage_id: str,
    onset_id: str,
    campaign_seed: int,
    profile_id: str,
    arm_id: str,
) -> dict[str, Any]:
    _reset_run()
    item = _validate_selector(
        stage_id,
        onset_id,
        campaign_seed,
        profile_id,
        arm_id,
    )
    _contract()
    core = _R23D65Core(CORE_LIBRARY)
    compiled, profile = _bound_base._compile_boundary(core)
    memory = core.balanced_wave_initial_memory()
    schedule = [
        _segment_for_step(item, step) for step in range(public_design.CONTROLLER_STEPS)
    ]
    segment_counts = {
        segment: sum(value[0] == segment for value in schedule)
        for segment in public_design.expected_segment_counts()
    }
    if (
        compiled.get("morphology_id") != public_design.MORPHOLOGY_ID
        or profile.get("policy_id") != POLICY_ID
        or memory.get("schema_version")
        != "sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
        or len(schedule) != public_design.CONTROLLER_STEPS
        or segment_counts != public_design.expected_segment_counts()
        or _RUNTIME.route is None
    ):
        raise _core.R23D3MujocoError("QSDK_R23D65_MJC_PREFLIGHT_INVALID")
    route = _RUNTIME.route
    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "question_class": "finite_decision",
        "stage_id": item.stage_id,
        "cell_id": item.cell_id,
        "engine_id": ENGINE_ID,
        "onset_id": ONSET_ID,
        "campaign_seed": CAMPAIGN_SEED,
        "profile_id": PROFILE_ID,
        "profile_sha256": PROFILE_SHA256,
        "host_mapping_id": HOST_MAPPING_ID,
        "arm_id": item.arm_id,
        "turn_heading_offset_rad": item.turn_heading_offset_rad,
        "segment_counts": segment_counts,
        "controller_policy_id": POLICY_ID,
        "controller_memory_schema": memory["schema_version"],
        "task_frame_origin_policy_id": TASK_ORIGIN_POLICY_ID,
        "expected_task_origin_reanchor_steps": list(EXPECTED_REANCHOR_STEPS),
        "startup_transform_id": public_design.STARTUP_TRANSFORM_ID,
        "fixed_controller_horizon_step_count": (public_design.CONTROLLER_STEPS),
        "production_model_xml_sha256": route.model_xml_sha256,
        "production_model_xml_byte_length": len(route.model_xml_bytes),
        "public_profile_route_compiled_before_model": True,
        "same_full_model_xml_consumed_by_physical_constructor": True,
        "physical_worker_dormant_behind_supervisor_authorization": True,
        "complete_nine_cell_matrix_authorization_required": True,
        "terminal_restoration_or_taper_invoked": False,
        "turning_tested": True,
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def run_authorization_preflight(
    stage_id: str,
    onset_id: str,
    campaign_seed: int,
    profile_id: str,
    arm_id: str,
    source_commit: str,
) -> dict[str, Any]:
    _reset_run()
    item = _validate_selector(
        stage_id,
        onset_id,
        campaign_seed,
        profile_id,
        arm_id,
    )
    _contract()
    if not _core._valid_lower_hex(source_commit, 40):
        raise _core.R23D3MujocoError("QSDK_R23D65_MJC_SOURCE_COMMIT_INVALID")
    _physical_authorization(item, source_commit)
    return compose_authorization_preflight_receipt(item)


def compose_authorization_preflight_receipt(item: _Cell) -> dict[str, Any]:
    receipt = {
        "schema_version": AUTHORIZATION_PREFLIGHT_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "stage_id": item.stage_id,
        "cell_id": item.cell_id,
        "engine_id": ENGINE_ID,
        "actual_production_authorization_function": "_physical_authorization",
        "actual_production_receipt_composer": "compose_authorization_preflight_receipt",
        "authorization_passed": True,
        "complete_ordered_nine_cell_matrix_validated": True,
        "returned_before_model": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }
    validate_authorization_preflight_receipt(receipt, item)
    return receipt


def validate_authorization_preflight_receipt(
    receipt: Mapping[str, Any],
    item: _Cell,
) -> None:
    exact = (
        receipt.get("schema_version") == AUTHORIZATION_PREFLIGHT_SCHEMA
        and receipt.get("campaign_id") == CAMPAIGN_ID
        and receipt.get("gate_id") == GATE_ID
        and receipt.get("engine_id") == ENGINE_ID
        and receipt.get("stage_id") == item.stage_id
        and receipt.get("cell_id") == item.cell_id
        and receipt.get("actual_production_authorization_function")
        == "_physical_authorization"
        and receipt.get("actual_production_receipt_composer")
        == "compose_authorization_preflight_receipt"
        and receipt.get("authorization_passed") is True
        and type(receipt.get("complete_ordered_nine_cell_matrix_validated")) is bool
        and receipt.get("complete_ordered_nine_cell_matrix_validated") is True
        and receipt.get("returned_before_model") is True
        and receipt.get("model_construction_count") == 0
        and receipt.get("world_attempt_count") == 0
        and receipt.get("world_build_count") == 0
        and receipt.get("physical_acceptance_authority") is False
    )
    if not exact:
        raise _core.R23D3MujocoError(
            "QSDK_R23D65_MJC_AUTHORIZATION_PREFLIGHT_RECEIPT_INVALID"
        )


def _inherited_physical_entry_preflight_bridge(
    stage_id: str,
    onset_id: str,
    arm_id: str,
) -> dict[str, Any]:
    """Adapts the inherited private 3-argument entry to this campaign contract."""

    return run_preflight(
        stage_id,
        onset_id,
        CAMPAIGN_SEED,
        PROFILE_ID,
        arm_id,
    )


for name, value in {
    "design": _design,
    "evaluator": _evaluator,
    "base": _bound_base,
    "LocomotionCore": _R23D65Core,
    "PREREGISTRATION_PATH": PREREGISTRATION_PATH,
    "PHYSICAL_EVALUATOR_PATH": EVALUATOR_PATH,
    "CLOSURE_PATH": CLOSURE_PATH,
    "WORKER_PATH": WORKER_PATH,
    "CAMPAIGN_ID": CAMPAIGN_ID,
    "GATE_ID": GATE_ID,
    "REPORT_SCHEMA": REPORT_SCHEMA,
    "FAILURE_SCHEMA": FAILURE_SCHEMA,
    "FREEZE_SCHEMA": FREEZE_SCHEMA,
    "ATTEMPT_SCHEMA": ATTEMPT_SCHEMA,
    "SCHEDULE_ID": "qsdk_r23d65_selected_profile_turn_return_v1",
    "CONTROLLER_STEPS": public_design.CONTROLLER_STEPS,
    "ACTUATOR_COUNT": public_design.ACTUATOR_COUNT,
    "TURN_DURATION_STEPS": (
        public_design.TURN_END_STEP_EXCLUSIVE - public_design.TURN_START_STEP
    ),
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
    "run_preflight": _inherited_physical_entry_preflight_bridge,
}.items():
    setattr(_core, name, value)
_core._trace_row = _trace_row


def run_physical(
    stage_id: str,
    onset_id: str,
    campaign_seed: int,
    profile_id: str,
    arm_id: str,
    source_commit: str,
) -> dict[str, Any]:
    _reset_run()
    _validate_selector(
        stage_id,
        onset_id,
        campaign_seed,
        profile_id,
        arm_id,
    )
    report = _core.run_physical(
        stage_id,
        onset_id,
        arm_id,
        source_commit,
    )
    if _RUNTIME.route is None or _RUNTIME.physical_binding is None:
        raise _core.R23D3MujocoError("QSDK_R23D65_MJC_PUBLIC_PROFILE_EVIDENCE_MISSING")
    startup_summary = _RAMP.summary()
    runtime_integrity = (
        not _RUNTIME.controller_commands
        and not _RUNTIME.native_applications
        and not _RUNTIME.task_origins
        and _RUNTIME.task_origin_reanchor_count == len(EXPECTED_REANCHOR_STEPS)
    )
    report["profile_id"] = PROFILE_ID
    report["profile_sha256"] = PROFILE_SHA256
    report["host_mapping_id"] = HOST_MAPPING_ID
    report["campaign_seed"] = CAMPAIGN_SEED
    report["actuator_cap_profile_resolution_receipt"] = copy.deepcopy(
        _RUNTIME.route.resolution_receipt
    )
    report["actuator_cap_profile_host_mapping_receipt"] = copy.deepcopy(
        _RUNTIME.route.host_mapping_receipt
    )
    report["actuator_cap_profile_physical_binding_receipt"] = copy.deepcopy(
        _RUNTIME.physical_binding
    )
    report["task_frame_origin_policy_id"] = TASK_ORIGIN_POLICY_ID
    report["trace_transport"] = {
        "trace_transport_id": TRACE_TRANSPORT_ID,
        "trace_transport_engine_id": ENGINE_ID,
        "canonical_ndjson": True,
        "full_precision": True,
        "python_json_full_precision": True,
    }
    report["measurements"].update(startup_summary)
    report["execution"].update(startup_summary)
    report["execution"].update(
        public_profile_model_xml_sha256=_RUNTIME.route.model_xml_sha256,
        public_profile_model_xml_consumed_directly=True,
        physical_binding_completed_before_first_solver_step=True,
        task_frame_origin_reanchor_count=_RUNTIME.task_origin_reanchor_count,
        runtime_capture_integrity_passed=runtime_integrity,
    )
    report["execution"]["integrity_passed"] = bool(
        report["execution"]["integrity_passed"]
        and startup_summary["startup_ramp_composition_integrity_passed"]
        and startup_summary["startup_transform_composition_integrity_passed"]
        and runtime_integrity
    )
    json.dumps(report, allow_nan=False)
    return report


def _arguments(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=("preflight", "authorization-preflight", "physical"),
    )
    parser.add_argument("--stage", required=True)
    parser.add_argument("--onset", required=True)
    parser.add_argument("--campaign-seed", required=True, type=int)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--arm", required=True)
    parser.add_argument("--source-commit", default="")
    return parser.parse_args(argv)


def _complete_failure_terminal(
    value: Mapping[str, Any],
    arguments: argparse.Namespace,
) -> dict[str, Any]:
    terminal = dict(value)
    arm_id = str(arguments.arm)
    arm_offsets = dict(public_design.ARMS)
    exact_arm = arm_id in arm_offsets
    terminal.update(
        schema_version=FAILURE_SCHEMA,
        campaign_id=CAMPAIGN_ID,
        gate_id=GATE_ID,
        stage_id=str(arguments.stage),
        cell_id=(
            f"{ENGINE_ID}__s{int(arguments.campaign_seed)}__selected_profile__{arm_id}"
            if exact_arm
            else None
        ),
        engine_id=ENGINE_ID,
        campaign_seed=int(arguments.campaign_seed),
        profile_id=str(arguments.profile),
        host_mapping_id=HOST_MAPPING_ID,
        arm_id=arm_id,
        turn_heading_offset_rad=(arm_offsets.get(arm_id) if exact_arm else None),
        source_commit=str(arguments.source_commit),
        physical_acceptance_authority=False,
    )
    terminal.setdefault("failure_stage", "before_world")
    terminal.setdefault("failure_code", "QSDK_R23D65_MJC_WORKER_FAILURE")
    terminal.setdefault("model_construction_count", 0)
    terminal.setdefault("world_attempt_count", 0)
    terminal.setdefault("world_build_count", 0)
    terminal.setdefault("claims", copy.deepcopy(_evaluator.FALSE_CLAIMS))
    return terminal


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(argv)
    try:
        if arguments.command == "preflight":
            value = run_preflight(
                arguments.stage,
                arguments.onset,
                arguments.campaign_seed,
                arguments.profile,
                arguments.arm,
            )
            marker = "QSDK_R23D65_MUJOCO_PREFLIGHT "
        elif arguments.command == "authorization-preflight":
            value = run_authorization_preflight(
                arguments.stage,
                arguments.onset,
                arguments.campaign_seed,
                arguments.profile,
                arguments.arm,
                arguments.source_commit,
            )
            marker = "QSDK_R23D65_MUJOCO_AUTHORIZATION_PREFLIGHT "
        else:
            value = run_physical(
                arguments.stage,
                arguments.onset,
                arguments.campaign_seed,
                arguments.profile,
                arguments.arm,
                arguments.source_commit,
            )
            marker = "QSDK_R23D65_MUJOCO_TERMINAL "
        print(
            marker
            + json.dumps(
                value,
                allow_nan=False,
                ensure_ascii=False,
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return 0
    except (
        R23D65MujocoRouteError,
        _core.R23D3MujocoError,
        KeyError,
        TypeError,
        ValueError,
    ) as error:
        if isinstance(error, _core.R23D3MujocoError):
            value = error.terminal_receipt or {"failure_code": error.code}
        else:
            value = {
                "failure_code": (
                    f"QSDK_R23D65_MJC_WORKER_ERROR:{type(error).__name__}:{error}"
                )
            }
        value = _complete_failure_terminal(value, arguments)
        print(
            "QSDK_R23D65_MUJOCO_TERMINAL "
            + json.dumps(
                value,
                allow_nan=False,
                ensure_ascii=False,
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
