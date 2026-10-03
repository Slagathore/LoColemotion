"""Bounded native-MuJoCo positive-turn development for QSDK-R23D73.

This worker deliberately reuses the closed R23D65 selected-profile production
plumbing without changing it. Scoped in-memory bindings select the exposed
R23D71 positive-heading fixture, retain the complete 2,992-step turn-and-recovery
horizon, and replace only the support-loss-conditioned startup transform with
the unconditional one-cycle canonical-velocity ramp closed positive by R23D72.

The question is development, not a fresh finite decision: does that exact
MuJoCo cell pass the inherited common physical gates and positive raw
cycle-shift floor? One exposed cell cannot establish portable turning,
cross-engine equivalence, bilateral response, or population coverage.
"""

from __future__ import annotations

import argparse
import copy
from contextlib import contextmanager
from dataclasses import dataclass
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import sys
import threading
from types import ModuleType, SimpleNamespace
from typing import Any, Iterator, Mapping, Sequence

import numpy as np

SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
TURNING_ROOT = SDK_ROOT / "turning"
SDK_PYTHON = SDK_ROOT / "python"
if str(SDK_PYTHON) not in sys.path:
    sys.path.insert(0, str(SDK_PYTHON))
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

from . import qsdk_r23d65_selected_profile_turning as production  # noqa: E402
from .actuator_cap_profile import (  # noqa: E402
    HOST_MAPPING_ID,
    ORDERED_ACTUATOR_IDS,
    PROFILE_ID,
    PROFILE_SHA256,
)

import r23d38_mujoco_startup_ramp_stabilization as ramp_design  # noqa: E402
import r23d31_cycle_integrated_measurement as cycle_measurement  # noqa: E402


CONTRACT_PATH = (
    TURNING_ROOT
    / "r23d73_mujoco_selected_profile_positive_turn_development_v1.json"
)
CLOSURE_PATH = (
    TURNING_ROOT
    / "r23d73_mujoco_selected_profile_positive_turn_development_closure_v1.json"
)
WORKER_PATH = Path(__file__).resolve()
INHERITED_CORE_PATH = Path(__file__).with_name("qsdk_r23d3_phase_balanced.py")
RAMP_DESIGN_PATH = Path(ramp_design.__file__).resolve()
CYCLE_MEASUREMENT_PATH = Path(cycle_measurement.__file__).resolve()
COMMON_GATE_SOURCE_PATH = TURNING_ROOT / "r23d59_godot_knee_source_finite_decision.py"
PRODUCTION_PATH = Path(production.__file__).resolve()
PRODUCTION_ROUTE_PATH = Path(production.ROUTE_PATH).resolve()
CORE_LIBRARY_PATH = SDK_ROOT / "target" / "release" / "sporespore_locomotion_core.dll"
SUPERVISOR_PATH = SDK_ROOT / "run_qsdk_r23d73_supervisor.ps1"

CAMPAIGN_ID = "QSDK-R23D73-MUJOCO-SELECTED-PROFILE-POSITIVE-TURN-DEVELOPMENT"
GATE_ID = "QSDK-R23D73"
STAGE_ID = "mujoco_selected_profile_positive_turn_development"
ENGINE_ID = "mujoco"
CELL_ID = "r23d73__mujoco__s23191__positive_heading__unconditional_startup_ramp"
ONSET_ID = "onset_600"
ARM_ID = "positive_heading"
CAMPAIGN_SEED = 23_191
CONTROLLER_STEPS = 2_992
LAST_SEMANTIC_STEP = 2_991
TURN_START_STEP = 600
TURN_END_STEP_EXCLUSIVE = 1_800
TURN_DURATION_STEPS = TURN_END_STEP_EXCLUSIVE - TURN_START_STEP
RECOVERY_DURATION_STEPS = 600
TURN_HEADING_OFFSET_RAD = 0.2
EVIDENCE_ORIGIN_STEP = 472
ACTUATOR_COUNT = 8
POLICY_ID = production.POLICY_ID
TASK_ORIGIN_POLICY_ID = production.TASK_ORIGIN_POLICY_ID
STARTUP_RAMP_ID = ramp_design.STARTUP_RAMP_ID
EXPECTED_REANCHOR_STEPS = (600, 1_800, 2_400)

COMMON_PHYSICAL_GATES = {
    "minimum_final_forward_displacement_m": 0.030123046875,
    "maximum_tilt_rad": 0.6,
    "minimum_torso_height_m": 0.2499708652072946,
    "minimum_contact_cycles_per_limb": 2,
    "maximum_torso_ground_contact_step_count": 0,
    "maximum_controller_error_count": 0,
    "maximum_safe_no_actuation_count": 0,
    "maximum_nonfinite_observation_count": 0,
    "maximum_actuator_application_mismatch_count": 0,
    "exact_controller_semantic_step_count": CONTROLLER_STEPS,
    "exact_validated_portable_command_count": CONTROLLER_STEPS * ACTUATOR_COUNT,
    "exact_native_actuation_application_count": CONTROLLER_STEPS * ACTUATOR_COUNT,
    "maximum_portable_impulse_violation_count": 0,
}
MINIMUM_RAW_SIGNED_CYCLE_SHIFT_RAD = cycle_measurement.MECHANISM_FLOOR_RAD

TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d73_mujoco_positive_turn_trace_row_v1"
TRACE_RETENTION_SCHEMA = (
    "sporespore_qsdk_r23d73_mujoco_positive_turn_trace_retention_v1"
)
REPORT_SCHEMA = "sporespore_qsdk_r23d73_mujoco_positive_turn_cell_report_v1"
FAILURE_SCHEMA = "sporespore_qsdk_r23d73_mujoco_positive_turn_worker_failure_v1"
PREFLIGHT_SCHEMA = "sporespore_qsdk_r23d73_mujoco_positive_turn_preflight_v1"
AUTHORIZATION_PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r23d73_mujoco_positive_turn_authorization_preflight_v1"
)
FREEZE_SCHEMA = "sporespore_qsdk_r23d73_mujoco_positive_turn_physical_freeze_v1"
ATTEMPT_SCHEMA = "sporespore_qsdk_r23d73_mujoco_positive_turn_attempt_v1"

FREEZE_PATH_ENV = "SPORESPORE_QSDK_R23D73_FREEZE"
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D73_ATTEMPT"
TOKEN_ENV = "SPORESPORE_QSDK_R23D73_TOKEN"
STAGE_ENV = "SPORESPORE_QSDK_R23D73_STAGE"
CELL_ENV = "SPORESPORE_QSDK_R23D73_CELL"
ENGINE_ENV = "SPORESPORE_QSDK_R23D73_ENGINE"
ATTEMPT_ROOT_ENV = "SPORESPORE_QSDK_R23D73_ATTEMPT_ROOT"
AUTHORITY_REPO_ROOT_ENV = "SPORESPORE_QSDK_R23D73_AUTHORITY_REPO_ROOT"
PYTHON_ENV = "SPORESPORE_QSDK_R23D73_PYTHON"
POWERSHELL_ENV = "SPORESPORE_QSDK_R23D73_POWERSHELL"

INITIAL_PERTURBATION = {
    "campaign_seed": CAMPAIGN_SEED,
    "fixture_vertical_clearance_m": 0.0002604132751002908,
    "fixture_yaw_rad": -0.0049262382090091705,
    "gait_phase_offset_ticks": -1,
    "initial_linear_velocity_world_m_s": [
        0.002370542846620083,
        0.0,
        0.0037111244164407253,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        -0.0003552224952727556,
        -0.0022123241797089577,
        0.00008024764247238636,
    ],
}

FALSE_CLAIMS = {
    "turning_established": False,
    "portable_basic_turning": False,
    "cross_engine_equivalence": False,
    "arbitrary_quadruped_coverage": False,
    "population_robustness": False,
    "q_sdk_r23_satisfied": False,
    "release_readiness_score_changed": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}

LEDGER_SCOPE = {
    "subsystem": "turning",
    "engine_scope": "mujoco",
    "authority_mode": "physical_development",
    "question_class": "development",
}

_BINDING_LOCK = threading.Lock()


def _load_private_core() -> ModuleType:
    specification = importlib.util.spec_from_file_location(
        "sporespore_mujoco_adapter._qsdk_r23d73_fixed_horizon_core",
        INHERITED_CORE_PATH,
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("QSDK_R23D73_MJC_INHERITED_WORKER_UNAVAILABLE")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


_core = _load_private_core()


class _R23D73Core(production._R23D65Core):
    """Force preflight and physical execution onto one recorded core binary."""

    def __init__(self, library_path: str | os.PathLike[str] | None = None) -> None:
        super().__init__(library_path or CORE_LIBRARY_PATH)


@dataclass(frozen=True)
class _Cell:
    stage_id: str = STAGE_ID
    cell_id: str = CELL_ID
    engine_id: str = ENGINE_ID
    onset_id: str = ONSET_ID
    turn_start_semantic_step: int = TURN_START_STEP
    arm_id: str = ARM_ID
    turn_heading_offset_rad: float = TURN_HEADING_OFFSET_RAD
    campaign_seed: int = CAMPAIGN_SEED
    profile_id: str = PROFILE_ID
    host_mapping_id: str = HOST_MAPPING_ID


def _cell(stage_id: str, onset_id: str, arm_id: str) -> _Cell:
    if (stage_id, onset_id, arm_id) != (STAGE_ID, ONSET_ID, ARM_ID):
        raise _core.R23D3MujocoError(
            f"QSDK_R23D73_MJC_CELL_IDENTITY_INVALID:{stage_id}:{onset_id}:{arm_id}"
        )
    return _Cell()


def _segment_for_step(item: _Cell, semantic_step: int) -> tuple[str, float]:
    if item != _Cell() or not 0 <= semantic_step < CONTROLLER_STEPS:
        raise _core.R23D3MujocoError(
            f"QSDK_R23D73_MJC_SEMANTIC_STEP_INVALID:{semantic_step}"
        )
    if semantic_step < TURN_START_STEP:
        return "reference_warmup", 0.0
    if semantic_step < TURN_END_STEP_EXCLUSIVE:
        return "commanded_turn", TURN_HEADING_OFFSET_RAD
    if semantic_step < TURN_END_STEP_EXCLUSIVE + RECOVERY_DURATION_STEPS:
        return "reference_recovery", 0.0
    return "after_declared_schedule", 0.0


def _expected_segment_counts(_item: _Cell | None = None) -> dict[str, int]:
    return {
        "reference_warmup": TURN_START_STEP,
        "commanded_turn": TURN_DURATION_STEPS,
        "reference_recovery": RECOVERY_DURATION_STEPS,
        "after_declared_schedule": (
            CONTROLLER_STEPS - TURN_END_STEP_EXCLUSIVE - RECOVERY_DURATION_STEPS
        ),
    }


_design = SimpleNamespace(
    CAMPAIGN_ID=CAMPAIGN_ID,
    GATE_ID=GATE_ID,
    Cell=_Cell,
    ACTUATOR_COUNT=ACTUATOR_COUNT,
    CONTROLLER_STEPS=CONTROLLER_STEPS,
    TURN_DURATION_STEPS=TURN_DURATION_STEPS,
    GAIT_CYCLE_STEPS=ramp_design.GAIT_CYCLE_STEPS,
    LIMB_IDS=tuple(production.LIMB_IDS),
    PHASE_OFFSETS=tuple(production.PHASE_OFFSETS),
    TRACE_ROW_SCHEMA=TRACE_ROW_SCHEMA,
    segment_for_step=_segment_for_step,
    expected_segment_counts=_expected_segment_counts,
    stage_a_cells=lambda: [],
    stage_b_cells=lambda _onset: [_Cell()],
)
_evaluator = SimpleNamespace(
    REPORT_SCHEMA=REPORT_SCHEMA,
    FAILURE_SCHEMA=FAILURE_SCHEMA,
    TRACE_RETENTION_SCHEMA=TRACE_RETENTION_SCHEMA,
    FALSE_CLAIMS=FALSE_CLAIMS,
)


def _json_native(value: Any) -> Any:
    if isinstance(value, np.generic):
        return value.item()
    if isinstance(value, dict):
        return {key: _json_native(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_native(item) for item in value]
    return value


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _valid_lower_hex(value: Any, length: int) -> bool:
    return (
        isinstance(value, str)
        and len(value) == length
        and all(character in "0123456789abcdef" for character in value)
    )


def _read_json(path: Path, code: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise _core.R23D3MujocoError(f"{code}:{type(error).__name__}") from error
    if not isinstance(value, dict):
        raise _core.R23D3MujocoError(code)
    return value


def _validate_contract_value(contract: Mapping[str, Any]) -> None:
    role = contract.get("scientific_role", {})
    fixture = contract.get("fixture", {})
    intervention = contract.get("intervention", {})
    horizon = contract.get("fixed_horizon", {})
    gate = contract.get("development_gate", {})
    zero_world = contract.get("zero_world_gate", {})
    authorization = contract.get("authorization", {})
    claims = contract.get("claims", {})
    exact = (
        contract.get("schema_version")
        == "sporespore_qsdk_r23d73_mujoco_selected_profile_positive_turn_development_v1"
        and contract.get("campaign_id") == CAMPAIGN_ID
        and contract.get("gate_id") == GATE_ID
        and contract.get("status") == "prospective_zero_world_only"
        and contract.get("ledger_scope") == LEDGER_SCOPE
        and role.get("question_class") == "development"
        and role.get("repeatable_calibration_or_training_work") is True
        and role.get("finite_decision") is False
        and role.get("equivalence_or_non_inferiority") is False
        and role.get("held_out_prospective_native_validation") is False
        and role.get("outcome_exposed_fixture") is True
        and role.get("population_inference_allowed") is False
        and role.get("turning_tested") is True
        and fixture.get("engine_id") == ENGINE_ID
        and fixture.get("cell_id") == CELL_ID
        and fixture.get("stage_id") == STAGE_ID
        and fixture.get("onset_id") == ONSET_ID
        and fixture.get("arm_id") == ARM_ID
        and fixture.get("campaign_seed") == CAMPAIGN_SEED
        and fixture.get("seed_was_outcome_exposed_by_r23d71") is True
        and fixture.get("profile_id") == PROFILE_ID
        and fixture.get("profile_sha256") == PROFILE_SHA256
        and fixture.get("host_mapping_id") == HOST_MAPPING_ID
        and fixture.get("controller_policy_id") == POLICY_ID
        and fixture.get("task_origin_policy_id") == TASK_ORIGIN_POLICY_ID
        and fixture.get("initial_perturbation") == INITIAL_PERTURBATION
        and intervention.get("startup_ramp_id") == STARTUP_RAMP_ID
        and intervention.get("startup_ramp_step_count")
        == ramp_design.STARTUP_RAMP_STEPS
        and intervention.get("support_loss_trigger_used") is False
        and intervention.get("partial_support_threshold_added") is False
        and horizon.get("first_semantic_step") == 0
        and horizon.get("last_semantic_step") == LAST_SEMANTIC_STEP
        and horizon.get("controller_step_count") == CONTROLLER_STEPS
        and horizon.get("reference_warmup_step_count") == TURN_START_STEP
        and horizon.get("commanded_turn_step_count") == TURN_DURATION_STEPS
        and horizon.get("reference_recovery_step_count") == RECOVERY_DURATION_STEPS
        and horizon.get("after_declared_schedule_step_count")
        == CONTROLLER_STEPS - TURN_END_STEP_EXCLUSIVE - RECOVERY_DURATION_STEPS
        and horizon.get("turn_start_semantic_step") == TURN_START_STEP
        and horizon.get("turn_end_semantic_step_exclusive") == TURN_END_STEP_EXCLUSIVE
        and horizon.get("turn_heading_offset_rad") == TURN_HEADING_OFFSET_RAD
        and horizon.get("task_origin_reanchor_steps")
        == list(EXPECTED_REANCHOR_STEPS)
        and horizon.get("forward_displacement_measurement_origin_semantic_step")
        == EVIDENCE_ORIGIN_STEP
        and horizon.get("terminal_settle_step_count") == 0
        and horizon.get("declared_physical_world_count") == 1
        and gate.get("primary_observation")
        == "positive_heading_raw_cycle_shift_and_common_physical_gate_conjunction"
        and gate.get("all_common_physical_gates_required") is True
        and gate.get("common_physical_gates") == COMMON_PHYSICAL_GATES
        and gate.get("raw_signed_cycle_shift", {}).get("arm_id") == ARM_ID
        and gate.get("raw_signed_cycle_shift", {}).get("direction")
        == "greater_than_or_equal"
        and gate.get("raw_signed_cycle_shift", {}).get("minimum_rad")
        == MINIMUM_RAW_SIGNED_CYCLE_SHIFT_RAD
        and gate.get("reference_conditioned_cycle_shift_evaluated") is False
        and gate.get("bilateral_directional_response_evaluated") is False
        and zero_world.get("full_seeded_world_required") is False
        and zero_world.get("synthetic_ramp_semantic_steps") == [0, 1, 359, 360]
        and len(zero_world.get("negative_control_classes", [])) == 5
        and zero_world.get("model_construction_count") == 0
        and zero_world.get("world_attempt_count") == 0
        and zero_world.get("world_build_count") == 0
        and zero_world.get("solver_step_count") == 0
        and authorization.get("complete_zero_world_gate_required") is True
        and authorization.get("clean_pushed_source_required") is True
        and authorization.get("global_physical_operation_lock_required") is True
        and authorization.get("physical_execution_authorized") is False
        and claims.get("turning_established") is False
        and claims.get("positive_heading_turning_cell_established") is False
        and claims.get("cross_engine_equivalence") is False
        and claims.get("release_readiness_score_changed") is False
        and claims.get("release_authorized") is False
    )
    if not exact:
        raise _core.R23D3MujocoError("QSDK_R23D73_MJC_CONTRACT_INVALID")


def _contract() -> dict[str, Any]:
    contract = _read_json(CONTRACT_PATH, "QSDK_R23D73_MJC_CONTRACT_UNREADABLE")
    _validate_contract_value(contract)
    return contract


class _UnconditionalStartupRampRun:
    """Compose the closed R38/R42 ramp while retaining support diagnostics."""

    def __init__(self) -> None:
        self.reset()

    def reset(self) -> None:
        self.pending_support: dict[int, int] = {}
        self.rows: dict[int, dict[str, Any]] = {}
        self.composition_step_count = 0
        self.ramped_step_count = 0
        self.exact_zero_scale_step_count = 0
        self.exact_unity_scale_step_count = 0
        self.maximum_absolute_residual_rad_s = 0.0
        self.minimum_observed_support_count = len(production.LIMB_IDS)

    def capture_contacts(
        self,
        semantic_step: int,
        contacts: Mapping[str, bool],
    ) -> None:
        if semantic_step in self.pending_support or semantic_step in self.rows:
            raise RuntimeError("QSDK_R23D73_MJC_CONTACT_CAPTURE_DUPLICATE")
        if set(contacts) != set(production.LIMB_IDS):
            raise RuntimeError("QSDK_R23D73_MJC_CONTACT_CAPTURE_INVALID")
        support_count = sum(bool(contacts[limb_id]) for limb_id in production.LIMB_IDS)
        self.pending_support[semantic_step] = support_count
        self.minimum_observed_support_count = min(
            self.minimum_observed_support_count,
            support_count,
        )

    def compose(self, actuation: dict[str, Any]) -> list[dict[str, Any]]:
        semantic_step = int(actuation.get("semantic_step", -1))
        commands = actuation.get("ordered_commands")
        try:
            support_count = self.pending_support.pop(semantic_step)
        except KeyError as error:
            raise RuntimeError("QSDK_R23D73_MJC_CONTACT_CAPTURE_MISSING") from error
        if (
            semantic_step in self.rows
            or not isinstance(commands, list)
            or len(commands) != ACTUATOR_COUNT
            or production._RUNTIME.controller_commands is None
            or semantic_step in production._RUNTIME.controller_commands
        ):
            raise RuntimeError("QSDK_R23D73_MJC_RAMP_STEP_BINDING_INVALID")
        production._RUNTIME.controller_commands[semantic_step] = copy.deepcopy(commands)
        scale = ramp_design.startup_velocity_scale(semantic_step)
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
                raise RuntimeError("QSDK_R23D73_MJC_RAMP_NONFINITE")
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
        self.rows[semantic_step] = {
            "startup_ramp_id": STARTUP_RAMP_ID,
            "startup_transform_id": STARTUP_RAMP_ID,
            "startup_policy": "unconditional_one_cycle",
            "startup_velocity_scale": scale,
            "startup_ramp_active": scale < 1.0,
            "startup_ramp_triggered": False,
            "startup_ramp_trigger_step": None,
            "startup_probe_minimum_support_count": support_count,
            "observed_support_count": support_count,
            "startup_ramp_residual_count": len(residuals),
            "startup_ramp_maximum_absolute_residual_rad_s": maximum,
            "startup_transform_residual_count": len(residuals),
            "startup_transform_maximum_absolute_residual_rad_s": maximum,
        }
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
            raise RuntimeError("QSDK_R23D73_MJC_RAMP_TRACE_BINDING_INVALID") from error

    def summary(self) -> dict[str, Any]:
        exact = self.composition_step_count == CONTROLLER_STEPS
        return {
            "startup_ramp_id": STARTUP_RAMP_ID,
            "startup_transform_id": STARTUP_RAMP_ID,
            "startup_policy": "unconditional_one_cycle",
            "startup_ramp_step_count": ramp_design.STARTUP_RAMP_STEPS,
            "startup_ramp_triggered": False,
            "startup_ramp_trigger_step": None,
            "startup_probe_minimum_support_count": self.minimum_observed_support_count,
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
                exact and not self.pending_support and not self.rows
            ),
            "startup_transform_composition_integrity_passed": (
                exact and not self.pending_support and not self.rows
            ),
        }


@contextmanager
def _route_bindings() -> Iterator[None]:
    if not _BINDING_LOCK.acquire(blocking=False):
        raise _core.R23D3MujocoError("QSDK_R23D73_MJC_CONCURRENT_BINDING_REFUSED")
    saved = {
        "runtime": production._RUNTIME,
        "ramp": production._RAMP,
        "campaign_seed": production.CAMPAIGN_SEED,
        "reanchor_steps": production.EXPECTED_REANCHOR_STEPS,
        "design_steps": production.public_design.CONTROLLER_STEPS,
        "design_seed": production.public_design.CAMPAIGN_SEED,
        "design_perturbation": production.public_design.INITIAL_PERTURBATION,
        "bound_seed": production._bound_base.CAMPAIGN_SEED,
    }
    try:
        production._RUNTIME = production._RuntimeCapture()
        production._RUNTIME.reset()
        production._RAMP = _UnconditionalStartupRampRun()
        production.CAMPAIGN_SEED = CAMPAIGN_SEED
        production.EXPECTED_REANCHOR_STEPS = EXPECTED_REANCHOR_STEPS
        production.public_design.CONTROLLER_STEPS = CONTROLLER_STEPS
        production.public_design.CAMPAIGN_SEED = CAMPAIGN_SEED
        production.public_design.INITIAL_PERTURBATION = copy.deepcopy(
            INITIAL_PERTURBATION
        )
        production._bound_base.CAMPAIGN_SEED = CAMPAIGN_SEED
        yield
    finally:
        production._RUNTIME = saved["runtime"]
        production._RAMP = saved["ramp"]
        production.CAMPAIGN_SEED = saved["campaign_seed"]
        production.EXPECTED_REANCHOR_STEPS = saved["reanchor_steps"]
        production.public_design.CONTROLLER_STEPS = saved["design_steps"]
        production.public_design.CAMPAIGN_SEED = saved["design_seed"]
        production.public_design.INITIAL_PERTURBATION = saved[
            "design_perturbation"
        ]
        production._bound_base.CAMPAIGN_SEED = saved["bound_seed"]
        _BINDING_LOCK.release()


def _same_path(candidate: Any, expected: Path) -> bool:
    if not isinstance(candidate, str) or not candidate:
        return False
    try:
        return Path(candidate).resolve(strict=True) == expected.resolve(strict=True)
    except OSError:
        return False


def _required_source_paths() -> tuple[Path, ...]:
    return (
        WORKER_PATH,
        CONTRACT_PATH,
        INHERITED_CORE_PATH,
        RAMP_DESIGN_PATH,
        CYCLE_MEASUREMENT_PATH,
        COMMON_GATE_SOURCE_PATH,
        PRODUCTION_PATH,
        PRODUCTION_ROUTE_PATH,
        SUPERVISOR_PATH,
    )


def _source_bindings_exact(freeze: Mapping[str, Any]) -> bool:
    bindings = freeze.get("source_bindings")
    if not isinstance(bindings, list):
        return False
    observed = {
        str(item.get("path")): str(item.get("raw_sha256"))
        for item in bindings
        if isinstance(item, dict)
    }
    required = {
        path.relative_to(REPO_ROOT).as_posix(): _raw_sha256(path)
        for path in _required_source_paths()
    }
    return observed == required


def _physical_authorization(item: _Cell, source_commit: str) -> dict[str, Any]:
    if item != _Cell() or not _valid_lower_hex(source_commit, 40):
        raise _core.R23D3MujocoError("QSDK_R23D73_MJC_SELECTOR_INVALID")
    if CLOSURE_PATH.is_file():
        raise _core.R23D3MujocoError("QSDK_R23D73_MJC_CLOSED")
    freeze_path = Path(os.environ.get(FREEZE_PATH_ENV, ""))
    attempt_path = Path(os.environ.get(ATTEMPT_PATH_ENV, ""))
    attempt_root = Path(os.environ.get(ATTEMPT_ROOT_ENV, ""))
    authority_root_raw = os.environ.get(AUTHORITY_REPO_ROOT_ENV, "")
    token = os.environ.get(TOKEN_ENV, "")
    if (
        not freeze_path.is_file()
        or not attempt_path.is_file()
        or not attempt_root.is_dir()
        or not authority_root_raw
        or not _valid_lower_hex(token, 32)
    ):
        raise _core.R23D3MujocoError(
            "QSDK_R23D73_MJC_PHYSICAL_AUTHORIZATION_REQUIRED"
        )
    try:
        authority_root = Path(authority_root_raw).resolve(strict=True)
        canonical_attempt_root = attempt_root.resolve(strict=True)
        evidence_root = (REPO_ROOT.parent / "SporeSpore_Evidence").resolve(strict=True)
        canonical_attempt_root.relative_to(evidence_root)
    except (OSError, ValueError) as error:
        raise _core.R23D3MujocoError(
            "QSDK_R23D73_MJC_AUTHORIZATION_PATH_INVALID"
        ) from error
    freeze = _read_json(freeze_path, "QSDK_R23D73_MJC_FREEZE_UNREADABLE")
    attempt = _read_json(attempt_path, "QSDK_R23D73_MJC_ATTEMPT_UNREADABLE")
    exact = (
        authority_root == REPO_ROOT.resolve(strict=True)
        and freeze.get("schema_version") == FREEZE_SCHEMA
        and freeze.get("campaign_id") == CAMPAIGN_ID
        and freeze.get("gate_id") == GATE_ID
        and freeze.get("status") == "frozen_development_physical_authorized"
        and freeze.get("source_commit") == source_commit
        and freeze.get("origin_main_commit") == source_commit
        and freeze.get("live_github_main_commit") == source_commit
        and freeze.get("contract_raw_sha256") == _raw_sha256(CONTRACT_PATH)
        and freeze.get("worker_raw_sha256") == _raw_sha256(WORKER_PATH)
        and freeze.get("core_library_raw_sha256") == _raw_sha256(CORE_LIBRARY_PATH)
        and freeze.get("source_worktree_clean") is True
        and freeze.get("complete_zero_world_gate_passed") is True
        and freeze.get("declared_world_count") == 1
        and freeze.get("ordered_cell_ids") == [CELL_ID]
        and freeze.get("serial_execution_required") is True
        and freeze.get("physical_execution_authorized") is True
        and freeze.get("physical_behavior_thresholds_applied") is True
        and _source_bindings_exact(freeze)
        and attempt.get("schema_version") == ATTEMPT_SCHEMA
        and attempt.get("campaign_id") == CAMPAIGN_ID
        and attempt.get("gate_id") == GATE_ID
        and attempt.get("source_commit") == source_commit
        and attempt.get("freeze_raw_sha256") == _raw_sha256(freeze_path)
        and attempt.get("authorization_token") == token
        and _valid_lower_hex(attempt.get("attempt_id"), 32)
        and _same_path(attempt.get("attempt_root"), canonical_attempt_root)
        and attempt.get("ordered_cell_ids") == [CELL_ID]
        and attempt.get("single_use_supervisor_authorization") is True
        and attempt.get("operation_lock_held") is True
        and attempt.get("one_shot_attempt_unconsumed") is True
        and attempt.get("physical_execution_authorized") is True
        and os.environ.get(STAGE_ENV) == STAGE_ID
        and os.environ.get(CELL_ENV) == CELL_ID
        and os.environ.get(ENGINE_ENV) == ENGINE_ID
    )
    if not exact:
        raise _core.R23D3MujocoError(
            "QSDK_R23D73_MJC_PHYSICAL_AUTHORIZATION_INVALID"
        )
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
    if item != _Cell() or len(rows) != CONTROLLER_STEPS:
        raise _core.R23D3MujocoError(
            "QSDK_R23D73_MJC_TRACE_CARDINALITY_INVALID",
            world_attempt_count=1,
            world_build_count=1,
        )
    projected = [_json_native(copy.deepcopy(row)) for row in rows]
    for semantic_step, row in enumerate(projected):
        expected_segment, expected_heading = _segment_for_step(item, semantic_step)
        if (
            row.get("semantic_step") != semantic_step
            or row.get("segment_id") != expected_segment
            or row.get("desired_heading_offset_rad") != expected_heading
            or row.get("phase_id") != cycle_measurement.phase_for_step(semantic_step)
            or row.get("turning_tested") is not True
        ):
            raise _core.R23D3MujocoError(
                "QSDK_R23D73_MJC_TRACE_SCHEDULE_INVALID",
                world_attempt_count=1,
                world_build_count=1,
            )
    trace_root = attempt_root / "traces"
    trace_root.mkdir(parents=True, exist_ok=True)
    trace_path = trace_root / f"{CELL_ID}.ndjson"
    hasher = hashlib.sha256()
    byte_length = 0
    with trace_path.open("x", encoding="utf-8", newline="\n") as stream:
        for row in projected:
            encoded = (
                json.dumps(
                    row,
                    allow_nan=False,
                    ensure_ascii=False,
                    separators=(",", ":"),
                    sort_keys=True,
                )
                + "\n"
            ).encode("utf-8")
            stream.write(encoded.decode("utf-8"))
            hasher.update(encoded)
            byte_length += len(encoded)
    contact_steps = [
        int(row["semantic_step"])
        for row in projected
        if bool(row.get("torso_ground_contact"))
    ]
    scales = [float(row["startup_velocity_scale"]) for row in projected]
    support_counts = [int(row["observed_support_count"]) for row in projected]
    artifact = {
        "schema_version": "sporespore_content_addressed_artifact_receipt_v1",
        "path": str(trace_path.resolve(strict=True)),
        "media_type": "application/x-ndjson",
        "sha256": "sha256:" + hasher.hexdigest(),
        "byte_length": byte_length,
    }
    return {
        "schema_version": TRACE_RETENTION_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "ledger_scope": copy.deepcopy(LEDGER_SCOPE),
        "question_class": "development",
        "stage_id": STAGE_ID,
        "cell_id": CELL_ID,
        "engine_id": ENGINE_ID,
        "campaign_seed": CAMPAIGN_SEED,
        "row_count": len(projected),
        "retained_before_terminal_entry": True,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "trace_artifact": artifact,
        "trace_summary": {
            "row_count": len(projected),
            "first_semantic_step": 0,
            "last_semantic_step": LAST_SEMANTIC_STEP,
            "segment_counts": {
                segment: sum(row["segment_id"] == segment for row in projected)
                for segment in _expected_segment_counts()
            },
            "torso_ground_contact_trace_step_count": len(contact_steps),
            "first_torso_ground_contact_semantic_step": (
                contact_steps[0] if contact_steps else None
            ),
            "startup_ramp_active_step_count": sum(scale < 1.0 for scale in scales),
            "startup_ramp_exact_zero_scale_step_count": sum(
                scale == 0.0 for scale in scales
            ),
            "startup_ramp_exact_unity_scale_step_count": sum(
                scale == 1.0 for scale in scales
            ),
            "minimum_observed_support_count": min(support_counts),
            "canonical_ndjson": True,
            "full_precision": True,
        },
        "physical_acceptance_authority": False,
    }


def _trace_row(**kwargs: Any) -> dict[str, Any]:
    semantic_step = int(kwargs["semantic_step"])
    segment_id, desired_heading = _segment_for_step(_Cell(), semantic_step)
    row = _json_native(production._trace_row(**kwargs))
    row.update(
        schema_version=TRACE_ROW_SCHEMA,
        campaign_id=CAMPAIGN_ID,
        gate_id=GATE_ID,
        ledger_scope=copy.deepcopy(LEDGER_SCOPE),
        question_class="development",
        stage_id=STAGE_ID,
        engine_id=ENGINE_ID,
        cell_id=CELL_ID,
        campaign_seed=CAMPAIGN_SEED,
        semantic_step=semantic_step,
        trace_step=semantic_step,
        phase_id=cycle_measurement.phase_for_step(semantic_step),
        segment_id=segment_id,
        desired_heading_offset_rad=desired_heading,
        outcome_exposed_fixture=True,
        turning_tested=True,
        physical_acceptance_authority=False,
    )
    return row


def _synthetic_ramp_ghost() -> dict[str, Any]:
    ramp = _UnconditionalStartupRampRun()
    rows: list[dict[str, Any]] = []
    commands = [
        {
            "actuator_id": actuator_id,
            "target_velocity_rad_s": (index + 1) * 0.125,
        }
        for index, actuator_id in enumerate(ORDERED_ACTUATOR_IDS)
    ]
    for semantic_step in (0, 1, 359, 360):
        ramp.capture_contacts(
            semantic_step,
            {limb_id: True for limb_id in production.LIMB_IDS},
        )
        residuals = ramp.compose(
            {
                "semantic_step": semantic_step,
                "ordered_commands": copy.deepcopy(commands),
            }
        )
        fields = ramp.trace_fields(semantic_step)
        rows.append(
            {
                "semantic_step": semantic_step,
                "startup_velocity_scale": fields["startup_velocity_scale"],
                "residual_count": len(residuals),
            }
        )
    scales = [row["startup_velocity_scale"] for row in rows]
    if (
        scales[0] != 0.0
        or not 0.0 < scales[1] < 1.0
        or scales[2:] != [1.0, 1.0]
        or any(row["residual_count"] != ACTUATOR_COUNT for row in rows)
    ):
        raise _core.R23D3MujocoError("QSDK_R23D73_MJC_RAMP_GHOST_INVALID")
    production._RUNTIME.controller_commands = {}
    return {
        "selected_rows": rows,
        "exact_zero_at_step_zero": True,
        "exact_unity_at_step_359": True,
        "exact_unity_after_ramp": True,
        "synthetic_composition_count": len(rows),
    }


def _run_preflight_bound() -> dict[str, Any]:
    contract = _contract()
    core = _R23D73Core()
    compiled, profile = production._bound_base._compile_boundary(core)
    memory = core.balanced_wave_initial_memory()
    schedule = [_segment_for_step(_Cell(), step) for step in range(CONTROLLER_STEPS)]
    ramp_ghost = _synthetic_ramp_ghost()
    segment_counts = {
        segment: sum(value[0] == segment for value in schedule)
        for segment in _expected_segment_counts()
    }
    if (
        compiled.get("morphology_id") != "qsdk_r05_generated_s169"
        or profile.get("policy_id") != POLICY_ID
        or memory.get("schema_version")
        != "sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
        or segment_counts != _expected_segment_counts()
        or schedule[TURN_START_STEP - 1] != ("reference_warmup", 0.0)
        or schedule[TURN_START_STEP]
        != ("commanded_turn", TURN_HEADING_OFFSET_RAD)
        or schedule[TURN_END_STEP_EXCLUSIVE - 1]
        != ("commanded_turn", TURN_HEADING_OFFSET_RAD)
        or schedule[TURN_END_STEP_EXCLUSIVE] != ("reference_recovery", 0.0)
        or production._RUNTIME.route is None
    ):
        raise _core.R23D3MujocoError("QSDK_R23D73_MJC_PREFLIGHT_INVALID")
    mutations: list[dict[str, Any]] = []
    for name, mutate in (
        (
            "wrong_question_class",
            lambda value: value["scientific_role"].update(
                question_class="finite_decision"
            ),
        ),
        (
            "wrong_seed",
            lambda value: value["fixture"].update(campaign_seed=23_192),
        ),
        (
            "wrong_horizon",
            lambda value: value["fixed_horizon"].update(controller_step_count=2_993),
        ),
        (
            "wrong_startup_ramp_id",
            lambda value: value["intervention"].update(startup_ramp_id="mutated"),
        ),
        (
            "turning_threshold_changed",
            lambda value: value["development_gate"]["raw_signed_cycle_shift"].update(
                minimum_rad=0.02
            ),
        ),
    ):
        candidate = copy.deepcopy(contract)
        mutate(candidate)
        try:
            _validate_contract_value(candidate)
        except _core.R23D3MujocoError:
            mutations.append({"class": name, "rejected": True})
    if len(mutations) != 5:
        raise _core.R23D3MujocoError(
            "QSDK_R23D73_MJC_NEGATIVE_CONTROL_NOT_REJECTED"
        )
    route = production._RUNTIME.route
    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "ok": True,
        "failure_code": "",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "ledger_scope": copy.deepcopy(LEDGER_SCOPE),
        "question_class": "development",
        "engine_id": ENGINE_ID,
        "cell_id": CELL_ID,
        "campaign_seed": CAMPAIGN_SEED,
        "outcome_exposed_fixture": True,
        "controller_policy_id": POLICY_ID,
        "profile_id": PROFILE_ID,
        "profile_sha256": PROFILE_SHA256,
        "host_mapping_id": HOST_MAPPING_ID,
        "startup_ramp_id": STARTUP_RAMP_ID,
        "startup_ramp_ghost": ramp_ghost,
        "fixed_controller_horizon_step_count": CONTROLLER_STEPS,
        "first_semantic_step": 0,
        "last_semantic_step": LAST_SEMANTIC_STEP,
        "segment_counts": segment_counts,
        "commanded_turn_step_count": TURN_DURATION_STEPS,
        "turn_heading_offset_rad": TURN_HEADING_OFFSET_RAD,
        "turning_tested": True,
        "negative_control_results": mutations,
        "negative_control_class_count": len(mutations),
        "production_model_xml_sha256": route.model_xml_sha256,
        "production_model_xml_byte_length": len(route.model_xml_bytes),
        "public_profile_route_compiled_before_model": True,
        "returned_before_mjmodel": True,
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "behavioral_success_prediction_allowed": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def run_preflight() -> dict[str, Any]:
    with _route_bindings():
        return _run_preflight_bound()


def _inherited_preflight_bridge(
    stage_id: str,
    onset_id: str,
    arm_id: str,
    **_kwargs: Any,
) -> dict[str, Any]:
    _cell(stage_id, onset_id, arm_id)
    return _run_preflight_bound()


for _name, _value in {
    "design": _design,
    "evaluator": _evaluator,
    "base": production._bound_base,
    "LocomotionCore": _R23D73Core,
    "PREREGISTRATION_PATH": CONTRACT_PATH,
    "PHYSICAL_EVALUATOR_PATH": CONTRACT_PATH,
    "CLOSURE_PATH": CLOSURE_PATH,
    "WORKER_PATH": WORKER_PATH,
    "CAMPAIGN_ID": CAMPAIGN_ID,
    "GATE_ID": GATE_ID,
    "REPORT_SCHEMA": REPORT_SCHEMA,
    "FAILURE_SCHEMA": FAILURE_SCHEMA,
    "FREEZE_SCHEMA": FREEZE_SCHEMA,
    "ATTEMPT_SCHEMA": ATTEMPT_SCHEMA,
    "SCHEDULE_ID": "qsdk_r23d73_positive_turn_return_v1",
    "CONTROLLER_STEPS": CONTROLLER_STEPS,
    "ACTUATOR_COUNT": ACTUATOR_COUNT,
    "TURN_DURATION_STEPS": TURN_DURATION_STEPS,
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
    "run_preflight": _inherited_preflight_bridge,
}.items():
    setattr(_core, _name, _value)
_core._trace_row = _trace_row


def run_authorization_preflight(source_commit: str) -> dict[str, Any]:
    with _route_bindings():
        _contract()
        authorization = _physical_authorization(_Cell(), source_commit)
        return {
            "schema_version": AUTHORIZATION_PREFLIGHT_SCHEMA,
            "ok": True,
            "failure_code": "",
            "campaign_id": CAMPAIGN_ID,
            "gate_id": GATE_ID,
            "ledger_scope": copy.deepcopy(LEDGER_SCOPE),
            "question_class": "development",
            "engine_id": ENGINE_ID,
            "cell_id": CELL_ID,
            "attempt_root": str(authorization["attempt_root"]),
            "authorization_passed": True,
            "returned_before_model": True,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }


def _finite_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _count(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _common_physical_gate_failures(
    measurements: Mapping[str, Any],
    execution: Mapping[str, Any],
) -> list[str]:
    failures: list[str] = []
    expected_commands = CONTROLLER_STEPS * ACTUATOR_COUNT
    if (
        execution.get("integrity_passed") is not True
        or execution.get("controller_semantic_step_count") != CONTROLLER_STEPS
        or execution.get("validated_portable_command_count") != expected_commands
        or execution.get("native_actuation_application_count") != expected_commands
        or execution.get("portable_impulse_violation_count") != 0
        or execution.get("world_attempt_count") != 1
        or execution.get("world_build_count") != 1
        or execution.get("trace_retained_before_terminal_entry") is not True
        or execution.get("fixed_horizon_configuration_proved_before_fixture_insertion")
        is not True
    ):
        failures.append("R23D34_EXECUTION_INTEGRITY")
    numeric_fields = (
        "final_forward_displacement_m",
        "turn_phase_yaw_delta_rad",
        "maximum_absolute_requested_steering_fraction",
        "maximum_absolute_held_steering_fraction",
        "maximum_tilt_rad",
        "minimum_torso_height_m",
    )
    if any(not _finite_number(measurements.get(field)) for field in numeric_fields):
        failures.append("R23D34_MEASUREMENTS_NONFINITE")
    count_fields = (
        "torso_ground_contact_step_count",
        "controller_error_count",
        "safe_no_actuation_count",
        "nonfinite_observation_count",
        "actuator_application_mismatch_count",
        "controller_semantic_step_count",
        "validated_portable_command_count",
        "native_actuation_application_count",
    )
    if any(not _count(measurements.get(field)) for field in count_fields):
        failures.append("R23D34_MEASUREMENT_COUNTS")
    if failures:
        return failures

    contacts = measurements.get("contact_cycle_count_by_limb")
    if (
        not isinstance(contacts, Mapping)
        or set(contacts) != set(production.LIMB_IDS)
        or any(
            not _count(contacts.get(limb_id))
            or int(contacts[limb_id])
            < COMMON_PHYSICAL_GATES["minimum_contact_cycles_per_limb"]
            for limb_id in production.LIMB_IDS
        )
    ):
        failures.append("R23D34_CONTACT_CYCLES")
    if (
        float(measurements["final_forward_displacement_m"])
        < COMMON_PHYSICAL_GATES["minimum_final_forward_displacement_m"]
    ):
        failures.append("R23D34_FORWARD_DISPLACEMENT")
    if (
        float(measurements["maximum_tilt_rad"])
        > COMMON_PHYSICAL_GATES["maximum_tilt_rad"]
    ):
        failures.append("R23D34_MAXIMUM_TILT")
    if (
        float(measurements["minimum_torso_height_m"])
        < COMMON_PHYSICAL_GATES["minimum_torso_height_m"]
    ):
        failures.append("R23D34_MINIMUM_HEIGHT")
    for field, gate_id, maximum in (
        (
            "torso_ground_contact_step_count",
            "R23D34_TORSO_GROUND_CONTACT",
            COMMON_PHYSICAL_GATES["maximum_torso_ground_contact_step_count"],
        ),
        (
            "controller_error_count",
            "R23D34_CONTROLLER_ERROR",
            COMMON_PHYSICAL_GATES["maximum_controller_error_count"],
        ),
        (
            "safe_no_actuation_count",
            "R23D34_SAFE_NO_ACTUATION",
            COMMON_PHYSICAL_GATES["maximum_safe_no_actuation_count"],
        ),
        (
            "nonfinite_observation_count",
            "R23D34_NONFINITE_OBSERVATION",
            COMMON_PHYSICAL_GATES["maximum_nonfinite_observation_count"],
        ),
        (
            "actuator_application_mismatch_count",
            "R23D34_ACTUATOR_MISMATCH",
            COMMON_PHYSICAL_GATES["maximum_actuator_application_mismatch_count"],
        ),
    ):
        if int(measurements[field]) > int(maximum):
            failures.append(gate_id)
    for field, gate_id, expected in (
        (
            "controller_semantic_step_count",
            "R23D34_CONTROLLER_HORIZON",
            COMMON_PHYSICAL_GATES["exact_controller_semantic_step_count"],
        ),
        (
            "validated_portable_command_count",
            "R23D34_VALIDATED_COMMAND_COUNT",
            COMMON_PHYSICAL_GATES["exact_validated_portable_command_count"],
        ),
        (
            "native_actuation_application_count",
            "R23D34_NATIVE_APPLICATION_COUNT",
            COMMON_PHYSICAL_GATES["exact_native_actuation_application_count"],
        ),
    ):
        if int(measurements[field]) != int(expected):
            failures.append(gate_id)
    return failures


def _positive_cycle_measurement(report: Mapping[str, Any]) -> dict[str, Any]:
    artifact = report.get("trace_artifact")
    if not isinstance(artifact, Mapping):
        raise _core.R23D3MujocoError(
            "QSDK_R23D73_MJC_TRACE_ARTIFACT_MISSING",
            world_attempt_count=1,
            world_build_count=1,
        )
    trace_path = Path(str(artifact.get("path", "")))
    try:
        trace_path.resolve(strict=True).relative_to(
            Path(os.environ[ATTEMPT_ROOT_ENV]).resolve(strict=True)
        )
        rows = [
            json.loads(line)
            for line in trace_path.read_text(encoding="utf-8").splitlines()
        ]
        yaw = cycle_measurement._validated_yaw(rows, ARM_ID)
        measured = cycle_measurement._arm_measurement(yaw)
    except (
        KeyError,
        OSError,
        TypeError,
        ValueError,
        json.JSONDecodeError,
        cycle_measurement.CycleIntegratedMeasurementError,
    ) as error:
        raise _core.R23D3MujocoError(
            f"QSDK_R23D73_MJC_CYCLE_MEASUREMENT_INVALID:{type(error).__name__}",
            world_attempt_count=1,
            world_build_count=1,
        ) from error
    return _json_native(measured)


def run_physical(source_commit: str) -> dict[str, Any]:
    with _route_bindings():
        measurement_plan = (
            _core.evidence_window_forward_displacement_measurement_origin_plan(
                EVIDENCE_ORIGIN_STEP
            )
        )
        report = _core.run_physical(
            STAGE_ID,
            ONSET_ID,
            ARM_ID,
            source_commit,
            forward_displacement_measurement_origin_plan=measurement_plan,
        )
        if production._RUNTIME.route is None or production._RUNTIME.physical_binding is None:
            raise _core.R23D3MujocoError(
                "QSDK_R23D73_MJC_PUBLIC_PROFILE_EVIDENCE_MISSING",
                world_attempt_count=1,
                world_build_count=1,
            )
        startup_summary = production._RAMP.summary()
        runtime_integrity = (
            not production._RUNTIME.controller_commands
            and not production._RUNTIME.native_applications
            and not production._RUNTIME.task_origins
            and production._RUNTIME.task_origin_reanchor_count
            == len(EXPECTED_REANCHOR_STEPS)
        )
        measurements = report.get("measurements", {})
        execution = report.get("execution", {})
        trace_summary = report.get("trace_summary", {})
        positive_cycle = _positive_cycle_measurement(report)
        common_failures = _common_physical_gate_failures(measurements, execution)
        raw_cycle_shift = float(positive_cycle["cycle_shift_rad"])
        raw_positive_gate = raw_cycle_shift >= MINIMUM_RAW_SIGNED_CYCLE_SHIFT_RAD
        exact_execution = (
            execution.get("integrity_passed") is True
            and execution.get("controller_semantic_step_count") == CONTROLLER_STEPS
            and execution.get("world_attempt_count") == 1
            and execution.get("world_build_count") == 1
            and trace_summary.get("row_count") == CONTROLLER_STEPS
            and trace_summary.get("first_semantic_step") == 0
            and trace_summary.get("last_semantic_step") == LAST_SEMANTIC_STEP
            and startup_summary["startup_ramp_composition_integrity_passed"]
            and startup_summary["startup_transform_composition_integrity_passed"]
            and startup_summary["startup_ramp_composition_step_count"]
            == CONTROLLER_STEPS
            and startup_summary["startup_ramp_active_step_count"] == 359
            and startup_summary["startup_ramp_exact_zero_scale_step_count"] == 1
            and startup_summary["startup_ramp_exact_unity_scale_step_count"]
            == CONTROLLER_STEPS - 359
            and runtime_integrity
        )
        if not exact_execution:
            classification = "invalid_or_incomplete_positive_turn_development"
        elif not common_failures and raw_positive_gate:
            classification = "valid_complete_positive_turn_development"
        else:
            classification = "valid_complete_negative_turn_development"
        report.update(
            schema_version=REPORT_SCHEMA,
            campaign_id=CAMPAIGN_ID,
            gate_id=GATE_ID,
            ledger_scope=copy.deepcopy(LEDGER_SCOPE),
            question_class="development",
            stage_id=STAGE_ID,
            engine_id=ENGINE_ID,
            cell_id=CELL_ID,
            campaign_seed=CAMPAIGN_SEED,
            profile_id=PROFILE_ID,
            profile_sha256=PROFILE_SHA256,
            host_mapping_id=HOST_MAPPING_ID,
            arm_id=ARM_ID,
            turn_heading_offset_rad=TURN_HEADING_OFFSET_RAD,
            source_commit=source_commit,
            outcome_exposed_fixture=True,
            turning_tested=True,
            classification=classification,
            claims=copy.deepcopy(FALSE_CLAIMS),
            physical_acceptance_authority=False,
        )
        report["actuator_cap_profile_resolution_receipt"] = copy.deepcopy(
            production._RUNTIME.route.resolution_receipt
        )
        report["actuator_cap_profile_host_mapping_receipt"] = copy.deepcopy(
            production._RUNTIME.route.host_mapping_receipt
        )
        report["actuator_cap_profile_physical_binding_receipt"] = copy.deepcopy(
            production._RUNTIME.physical_binding
        )
        report["measurements"].update(startup_summary)
        report["measurements"]["positive_cycle_integrated_measurement"] = positive_cycle
        report["measurements"]["common_physical_gate_failures"] = common_failures
        report["measurements"]["common_physical_gates_passed"] = not common_failures
        report["measurements"]["raw_positive_cycle_shift_gate_passed"] = (
            raw_positive_gate
        )
        report["execution"].update(startup_summary)
        report["execution"].update(
            public_profile_model_xml_sha256=(
                production._RUNTIME.route.model_xml_sha256
            ),
            public_profile_model_xml_consumed_directly=True,
            physical_binding_completed_before_first_solver_step=True,
            task_frame_origin_reanchor_count=(
                production._RUNTIME.task_origin_reanchor_count
            ),
            runtime_capture_integrity_passed=runtime_integrity,
            fixed_horizon_first_semantic_step=0,
            fixed_horizon_last_semantic_step=LAST_SEMANTIC_STEP,
            commanded_turn_step_count=TURN_DURATION_STEPS,
            turning_tested=True,
        )
        report["execution"]["integrity_passed"] = exact_execution
        report["development_observation"] = {
            "primary_observation": (
                "positive_heading_raw_cycle_shift_and_common_physical_gate_conjunction"
            ),
            "observed_raw_signed_cycle_shift_rad": raw_cycle_shift,
            "minimum_raw_signed_cycle_shift_rad": (
                MINIMUM_RAW_SIGNED_CYCLE_SHIFT_RAD
            ),
            "raw_signed_cycle_shift_gate_passed": raw_positive_gate,
            "common_physical_gate_failures": common_failures,
            "all_common_physical_gates_passed": not common_failures,
            "criterion_passed": (
                exact_execution and not common_failures and raw_positive_gate
            ),
            "classification": classification,
            "bounded_fixture_only": True,
            "population_inference_allowed": False,
            "bilateral_turning_inference_allowed": False,
            "portable_turning_inference_allowed": False,
            "reference_conditioned_gate_evaluated": False,
            "physical_acceptance_authority": False,
        }
        report["trace_retention"] = {
            "schema_version": TRACE_RETENTION_SCHEMA,
            "campaign_id": CAMPAIGN_ID,
            "gate_id": GATE_ID,
            "ledger_scope": copy.deepcopy(LEDGER_SCOPE),
            "question_class": "development",
            "engine_id": ENGINE_ID,
            "cell_id": CELL_ID,
            "campaign_seed": CAMPAIGN_SEED,
            "row_count": trace_summary.get("row_count"),
            "first_semantic_step": trace_summary.get("first_semantic_step"),
            "last_semantic_step": trace_summary.get("last_semantic_step"),
            "canonical_ndjson": True,
            "full_precision": True,
            "retained_before_terminal_entry": True,
            "turning_tested": True,
            "trace_artifact": copy.deepcopy(report.get("trace_artifact")),
            "physical_acceptance_authority": False,
        }
        json.dumps(report, allow_nan=False)
        return report


def _failure(value: Exception, source_commit: str) -> dict[str, Any]:
    if isinstance(value, _core.R23D3MujocoError) and value.terminal_receipt:
        receipt = _json_native(copy.deepcopy(value.terminal_receipt))
        receipt.update(
            schema_version=FAILURE_SCHEMA,
            campaign_id=CAMPAIGN_ID,
            gate_id=GATE_ID,
            ledger_scope=copy.deepcopy(LEDGER_SCOPE),
            question_class="development",
            engine_id=ENGINE_ID,
            cell_id=CELL_ID,
            campaign_seed=CAMPAIGN_SEED,
            source_commit=source_commit,
            classification="invalid_or_incomplete_positive_turn_development",
            claims=copy.deepcopy(FALSE_CLAIMS),
            physical_acceptance_authority=False,
        )
        return receipt
    return {
        "schema_version": FAILURE_SCHEMA,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "ledger_scope": copy.deepcopy(LEDGER_SCOPE),
        "question_class": "development",
        "engine_id": ENGINE_ID,
        "cell_id": CELL_ID,
        "campaign_seed": CAMPAIGN_SEED,
        "source_commit": source_commit,
        "failure_stage": "before_world",
        "failure_code": (
            value.code
            if isinstance(value, _core.R23D3MujocoError)
            else f"QSDK_R23D73_MJC_UNHANDLED:{type(value).__name__}:{value}"
        ),
        "world_attempt_count": getattr(value, "world_attempt_count", 0),
        "world_build_count": getattr(value, "world_build_count", 0),
        "classification": "invalid_or_incomplete_positive_turn_development",
        "claims": copy.deepcopy(FALSE_CLAIMS),
        "physical_acceptance_authority": False,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command",
        choices=("preflight", "authorization-preflight", "physical"),
    )
    parser.add_argument("--source-commit", default="")
    arguments = parser.parse_args(argv)
    try:
        if arguments.command == "preflight":
            value = run_preflight()
            marker = "QSDK_R23D73_MUJOCO_PREFLIGHT "
        elif arguments.command == "authorization-preflight":
            value = run_authorization_preflight(arguments.source_commit)
            marker = "QSDK_R23D73_MUJOCO_AUTHORIZATION "
        else:
            value = run_physical(arguments.source_commit)
            marker = "QSDK_R23D73_MUJOCO_TERMINAL "
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
    except Exception as error:
        value = _failure(error, arguments.source_commit)
        print(
            "QSDK_R23D73_MUJOCO_TERMINAL "
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
