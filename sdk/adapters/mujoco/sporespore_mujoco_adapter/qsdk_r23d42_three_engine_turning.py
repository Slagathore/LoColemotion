"""Classic-MuJoCo slice of the nine-cell QSDK-R23D42 validation.

The inherited controller, accepted startup ramp, and physics loop are
unchanged.  This wrapper executes the reference and bilateral heading arms
under the already-frozen R23D31 cycle-integrated turning estimator.
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
from types import ModuleType
from typing import Any, Sequence

from sporespore_locomotion import LocomotionCore, LocomotionCoreError


SDK_ROOT = Path(__file__).resolve().parents[3]
REPO_ROOT = SDK_ROOT.parent
TURNING_ROOT = SDK_ROOT / "turning"
if str(TURNING_ROOT) not in sys.path:
    sys.path.insert(0, str(TURNING_ROOT))

from . import qsdk_r23d2_heading_response as inherited_base  # noqa: E402

import r23d42_three_engine_startup_ramp_turning as design  # noqa: E402
import r23d42_three_engine_startup_ramp_turning_evaluator as evaluator  # noqa: E402


def _load_private_fixed_horizon_worker() -> ModuleType:
    """Load the accepted R23D3 loop without mutating a consumed wrapper."""

    source = Path(__file__).with_name("qsdk_r23d3_phase_balanced.py")
    specification = importlib.util.spec_from_file_location(
        "sporespore_mujoco_adapter._qsdk_r23d42_fixed_horizon_core",
        source,
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("QSDK_R23D42_MJC_INHERITED_WORKER_UNAVAILABLE")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


_core = _load_private_fixed_horizon_worker()
_INHERITED_TRACE_ROW = _core._trace_row
PREREGISTRATION_PATH = (
    TURNING_ROOT / "r23d42_three_engine_startup_ramp_turning_preregistration_v1.json"
)
IMPLEMENTATION_PATH = (
    TURNING_ROOT / "r23d42_three_engine_startup_ramp_turning_implementation_v1.json"
)
CLOSURE_PATH = TURNING_ROOT / "r23d42_three_engine_startup_ramp_turning_closure_v1.json"
WORKER_PATH = Path(__file__).resolve()
FREEZE_SCHEMA = "sporespore_qsdk_r23d42_physical_freeze_v1"
ATTEMPT_SCHEMA = "sporespore_qsdk_r23d42_attempt_v1"
FREEZE_PATH_ENV = "SPORESPORE_QSDK_R23D42_FREEZE"
ATTEMPT_PATH_ENV = "SPORESPORE_QSDK_R23D42_ATTEMPT"
TOKEN_ENV = "SPORESPORE_QSDK_R23D42_TOKEN"
STAGE_ENV = "SPORESPORE_QSDK_R23D42_STAGE"
CELL_ENV = "SPORESPORE_QSDK_R23D42_CELL"
ENGINE_ENV = "SPORESPORE_QSDK_R23D42_ENGINE"
ATTEMPT_ROOT_ENV = "SPORESPORE_QSDK_R23D42_ATTEMPT_ROOT"
PYTHON_ENV = "SPORESPORE_QSDK_R23D42_PYTHON"
POWERSHELL_ENV = "SPORESPORE_QSDK_R23D42_POWERSHELL"
ENGINE_ID = "mujoco"
REQUIRED_SOURCE_PATHS = (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d42_three_engine_turning.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d3_phase_balanced.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d2_heading_response.py",
    "sdk/turning/r23d42_three_engine_startup_ramp_turning.py",
    "sdk/turning/r23d42_three_engine_startup_ramp_turning_evaluator.py",
    "sdk/turning/r23d42_three_engine_startup_ramp_turning_preregistration_v1.json",
    "sdk/turning/r23d42_three_engine_startup_ramp_turning_implementation_v1.json",
    "sdk/turning/r23d34_native_r23d29_transfer.py",
    "sdk/turning/r23d34_native_r23d29_transfer_evaluator.py",
    "sdk/turning/r23d31_cycle_integrated_measurement.py",
    "sdk/publish_qsdk_r23d42_trace.ps1",
    "sdk/python/sporespore_locomotion.py",
)


class _StartupRampRun:
    """Bind every canonical ramp residual to one controller semantic step."""

    def __init__(self) -> None:
        self.reset()

    def reset(self) -> None:
        self.rows: dict[int, dict[str, Any]] = {}
        self.composition_step_count = 0
        self.ramped_step_count = 0
        self.exact_zero_scale_step_count = 0
        self.exact_unity_scale_step_count = 0
        self.maximum_absolute_residual_rad_s = 0.0
        self.integrity_passed = True

    def compose(self, actuation: dict[str, Any]) -> list[dict[str, Any]]:
        semantic_step = int(actuation.get("semantic_step", -1))
        commands = actuation.get("ordered_commands")
        if (
            semantic_step in self.rows
            or not isinstance(commands, list)
            or len(commands) != design.ACTUATOR_COUNT
        ):
            raise RuntimeError("QSDK_R23D42_RAMP_STEP_BINDING_INVALID")
        scale = design.startup_velocity_scale(semantic_step)
        residuals: list[dict[str, Any]] = []
        maximum = 0.0
        for command in commands:
            actuator_id = command.get("actuator_id")
            legacy_velocity = float(command.get("target_velocity_rad_s", float("nan")))
            # The legacy portable controller uses the historical Godot sign;
            # canonicalization flips it before this residual is added.
            portable_canonical = -legacy_velocity
            delta = portable_canonical * (scale - 1.0)
            if not isinstance(actuator_id, str) or not all(
                math.isfinite(value) for value in (legacy_velocity, delta)
            ):
                raise RuntimeError("QSDK_R23D42_RAMP_NONFINITE")
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
            "startup_ramp_id": design.STARTUP_RAMP_ID,
            "startup_velocity_scale": scale,
            "startup_ramp_active": scale < 1.0,
            "startup_ramp_residual_count": len(residuals),
            "startup_ramp_maximum_absolute_residual_rad_s": maximum,
        }
        self.composition_step_count += 1
        self.ramped_step_count += int(scale < 1.0)
        self.exact_zero_scale_step_count += int(scale == 0.0)
        self.exact_unity_scale_step_count += int(scale == 1.0)
        self.maximum_absolute_residual_rad_s = max(
            self.maximum_absolute_residual_rad_s, maximum
        )
        return residuals

    def trace_fields(self, semantic_step: int) -> dict[str, Any]:
        try:
            return self.rows.pop(semantic_step)
        except KeyError as error:
            raise RuntimeError("QSDK_R23D42_RAMP_TRACE_BINDING_INVALID") from error

    def summary(self) -> dict[str, Any]:
        return {
            "startup_ramp_id": design.STARTUP_RAMP_ID,
            "startup_ramp_step_count": design.STARTUP_RAMP_STEPS,
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
                self.integrity_passed and not self.rows
            ),
        }


_RAMP = _StartupRampRun()


class _R23D42Core(LocomotionCore):
    def balanced_wave_initial_memory(self) -> dict[str, Any]:
        return self.balanced_wave_policy_initial_memory(
            design.POLICY_ID,
            inherited_base.bridge.s169_descriptor(),
        )


class _BridgeBound:
    def __init__(self, bridge: ModuleType) -> None:
        self._bridge = bridge

    def __getattr__(self, name: str) -> Any:
        return getattr(self._bridge, name)

    def MujocoBw19vRobot(self, core: LocomotionCore, profile_id: str) -> Any:
        robot = self._bridge.MujocoBw19vRobot(core, profile_id)
        _RAMP.reset()
        return robot


class _PolicyBoundBase:
    POLICY_ID = design.POLICY_ID
    CAMPAIGN_SEED = design.CAMPAIGN_SEED

    def __init__(self, base: ModuleType) -> None:
        self._base = base
        self.bridge = _BridgeBound(base.bridge)

    def __getattr__(self, name: str) -> Any:
        return getattr(self._base, name)

    def _compile_boundary(
        self, core: LocomotionCore
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        return self._base._compile_boundary(core, policy_id=design.POLICY_ID)

    def _initial_perturbation(self, _development: dict[str, Any]) -> dict[str, Any]:
        return copy.deepcopy(design.INITIAL_PERTURBATION)

    def _zero_residuals(self, actuation: dict[str, Any]) -> list[dict[str, Any]]:
        return _RAMP.compose(actuation)


_bound_base = _PolicyBoundBase(inherited_base)


def _cell(stage_id: str, onset_id: str, arm_id: str) -> design.Cell:
    if onset_id != "onset_600":
        raise _core.R23D3MujocoError(f"QSDK_R23D42_MJC_ONSET_INVALID:{onset_id}")
    try:
        return design.cell(stage_id, ENGINE_ID, arm_id)
    except ValueError as error:
        raise _core.R23D3MujocoError(str(error)) from error


def _contract() -> dict[str, Any]:
    declaration = evaluator.load_declaration()
    if CLOSURE_PATH.is_file():
        raise _core.R23D3MujocoError("QSDK_R23D42_MJC_CLOSED")
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
        raise _core.R23D3MujocoError("QSDK_R23D42_MJC_AUTHORIZATION_REQUIRED")
    freeze = _core._read_json(freeze_path, "QSDK_R23D42_MJC_FREEZE_UNREADABLE")
    attempt = _core._read_json(attempt_path, "QSDK_R23D42_MJC_ATTEMPT_UNREADABLE")
    try:
        attempt_root.resolve().relative_to(
            (REPO_ROOT.parent / "SporeSpore_Evidence").resolve()
        )
    except ValueError as error:
        raise _core.R23D3MujocoError("QSDK_R23D42_MJC_ATTEMPT_ROOT_NOT_DURABLE") from error
    invalid = (
        freeze.get("schema_version") != FREEZE_SCHEMA
        or freeze.get("campaign_id") != design.CAMPAIGN_ID
        or freeze.get("gate_id") != design.GATE_ID
        or freeze.get("status") != "frozen_supervisor_only_physical_authorized"
        or freeze.get("source_commit") != source_commit
        or freeze.get("preregistration_raw_sha256")
        != evaluator.raw_sha256(PREREGISTRATION_PATH)
        or freeze.get("implementation_contract_raw_sha256")
        != evaluator.raw_sha256(IMPLEMENTATION_PATH)
        or freeze.get("declared_world_count") != len(design.cells())
        or freeze.get("physical_execution_authorized") is not True
        or not _source_bindings_exact(freeze)
        or attempt.get("schema_version") != ATTEMPT_SCHEMA
        or attempt.get("campaign_id") != design.CAMPAIGN_ID
        or attempt.get("gate_id") != design.GATE_ID
        or attempt.get("source_commit") != source_commit
        or attempt.get("freeze_raw_sha256") != evaluator.raw_sha256(freeze_path)
        or attempt.get("authorization_token") != token
        or attempt.get("ordered_matrix_cell_ids")
        != [cell.cell_id for cell in design.cells()]
        or item.cell_id not in attempt.get("ordered_matrix_cell_ids", [])
        or attempt.get("physical_execution_authorized") is not True
        or attempt.get("single_use_supervisor_authorization") is not True
        or attempt.get("matrix_authorization_immutable_before_first_world")
        is not True
        or attempt.get("source_worktree_clean") is not True
        or attempt.get("source_matches_live_github_main") is not True
        or attempt.get("operation_lock_held") is not True
        or attempt.get("campaign_attestation_adoption_valid") is not True
        or attempt.get("content_addressed_inputs_retained") is not True
        or attempt.get("one_shot_attempt_unconsumed") is not True
        or attempt.get("all_cells_run_regardless_of_intermediate_outcome")
        is not True
        or Path(str(attempt.get("attempt_root", ""))).resolve()
        != attempt_root.resolve()
        or os.environ.get(STAGE_ENV) != item.stage_id
        or os.environ.get(CELL_ENV) != item.cell_id
        or os.environ.get(ENGINE_ENV) != ENGINE_ID
    )
    if invalid:
        raise _core.R23D3MujocoError("QSDK_R23D42_MJC_AUTHORIZATION_INVALID")
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


def _synthetic_ramp_canary(core: LocomotionCore) -> dict[str, Any]:
    descriptor = inherited_base.bridge.s169_descriptor()
    compiled, _profile = _bound_base._compile_boundary(core)
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
    memory = core.balanced_wave_policy_initial_memory(design.POLICY_ID, descriptor)
    selected_steps = (0, 1, 179, 358, 359, 360)
    selected_set = set(selected_steps)
    all_scales: list[float] = []
    selected_scales: list[float] = []
    last_actuation: dict[str, Any] | None = None
    last_residuals: list[dict[str, Any]] | None = None
    _RAMP.reset()
    for semantic_step in range(selected_steps[-1] + 1):
        state["semantic_step"] = semantic_step
        state["sample_time_s"] = semantic_step / 120.0
        command = {
            "schema_version": "sporespore_motion_command_v2",
            "command_id": f"qsdk_r23d42_zero_world_{semantic_step}",
            "desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
            "desired_heading_rad": 0.0,
            "desired_yaw_rate_rad_s": None,
            "gait_family_id": "lateral_wave",
            "speed_class": "walk",
            "gait_amplitude": 1.0,
            "phase_progression_mode": "clocked",
            "valid_from_step": semantic_step,
            "valid_through_step": semantic_step,
            "authority": "test_fixture",
        }
        output = LocomotionCore.balanced_wave_policy_step(
            core,
            design.POLICY_ID,
            {
                "descriptor": descriptor,
                "memory": memory,
                "state": state,
                "command": command,
            },
        )
        memory = output["next_memory"]
        actuation = output["actuation"]
        residuals = _RAMP.compose(actuation)
        canonical = core.canonical_velocity_compose_v1(
            {
                "schema_version": "sporespore_canonical_velocity_compose_request_v1",
                "descriptor": descriptor,
                "source_actuation": actuation,
                "ordered_stability_residuals": residuals,
            }
        )
        scale = design.startup_velocity_scale(semantic_step)
        all_scales.append(scale)
        if semantic_step in selected_set:
            selected_scales.append(scale)
        for source, canonical_command in zip(
            actuation["ordered_commands"], canonical["ordered_commands"], strict=True
        ):
            expected = -float(source["target_velocity_rad_s"]) * scale
            if abs(
                float(canonical_command["combined_canonical_target_velocity_rad_s"])
                - expected
            ) > 1.0e-12:
                raise _core.R23D3MujocoError(
                    "QSDK_R23D42_MJC_RAMP_CANARY_COMPOSITION_INVALID"
                )
        _RAMP.trace_fields(semantic_step)
        last_actuation = actuation
        last_residuals = residuals
    if last_actuation is None or last_residuals is None:
        raise _core.R23D3MujocoError("QSDK_R23D42_MJC_RAMP_CANARY_EMPTY")
    reversed_order_rejected = False
    try:
        core.canonical_velocity_compose_v1(
            {
                "schema_version": "sporespore_canonical_velocity_compose_request_v1",
                "descriptor": descriptor,
                "source_actuation": last_actuation,
                "ordered_stability_residuals": list(reversed(last_residuals)),
            }
        )
    except LocomotionCoreError:
        reversed_order_rejected = True
    ramp_summary = _RAMP.summary()
    if (
        len(all_scales) != 361
        or any(not math.isfinite(value) or value < 0.0 or value > 1.0 for value in all_scales)
        or all_scales[0] != 0.0
        or all_scales[359] != 1.0
        or all_scales[360] != 1.0
        or not all(left < right for left, right in zip(all_scales[:359], all_scales[1:360], strict=True))
        or sum(value < 1.0 for value in all_scales) != 359
        or sum(value == 0.0 for value in all_scales) != 1
        or sum(value == 1.0 for value in all_scales) != 2
        or ramp_summary["startup_ramp_composition_step_count"] != 361
        or ramp_summary["startup_ramp_active_step_count"] != 359
        or ramp_summary["startup_ramp_exact_zero_scale_step_count"] != 1
        or ramp_summary["startup_ramp_exact_unity_scale_step_count"] != 2
        or ramp_summary["startup_ramp_composition_integrity_passed"] is not True
        or not reversed_order_rejected
    ):
        raise _core.R23D3MujocoError("QSDK_R23D42_MJC_RAMP_CANARY_INVALID")
    _RAMP.reset()
    return {
        "selected_semantic_steps": list(selected_steps),
        "selected_velocity_scales": selected_scales,
        "complete_ramp_scale_canary_count": len(all_scales),
        "active_ramp_scale_canary_count": 359,
        "all_scales_finite_bounded_and_monotonic": True,
        "exact_zero_start": True,
        "exact_unity_at_last_ramp_step": True,
        "exact_unity_after_ramp": True,
        "residual_order_mutation_rejected": True,
        "model_construction_count": 0,
        "world_build_count": 0,
    }


def run_preflight(stage_id: str, onset_id: str, arm_id: str) -> dict[str, Any]:
    _contract()
    item = _cell(stage_id, onset_id, arm_id)
    schedule = [
        design.segment_for_step(item, step) for step in range(design.CONTROLLER_STEPS)
    ]
    core = _R23D42Core()
    compiled, profile = _bound_base._compile_boundary(core)
    memory = core.balanced_wave_initial_memory()
    ramp_canary = _synthetic_ramp_canary(core)
    segment_counts = {name: 0 for name in design.expected_segment_counts(item)}
    for segment, _offset in schedule:
        if segment not in segment_counts:
            raise _core.R23D3MujocoError(
                "QSDK_R23D42_MJC_PREFLIGHT_UNDECLARED_SEGMENT"
            )
        segment_counts[segment] += 1
    if (
        compiled.get("morphology_id") != design.MORPHOLOGY_ID
        or profile.get("policy_id") != design.POLICY_ID
        or memory.get("schema_version") != "sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
        or memory.get("steering_guard_floor_hold_steps_remaining") != 0
        or len(schedule) != design.CONTROLLER_STEPS
        or segment_counts != design.expected_segment_counts(item)
        or schedule[design.TURN_START_STEP - 1] != ("reference_warmup", 0.0)
        or schedule[design.TURN_START_STEP]
        != ("commanded_turn", item.turn_heading_offset_rad)
        or schedule[design.TURN_END_STEP_EXCLUSIVE - 1]
        != ("commanded_turn", item.turn_heading_offset_rad)
        or schedule[design.TURN_END_STEP_EXCLUSIVE]
        != ("reference_recovery", 0.0)
        or schedule[
            design.TURN_END_STEP_EXCLUSIVE + design.RECOVERY_DURATION_STEPS
        ]
        != ("after_declared_schedule", 0.0)
    ):
        raise _core.R23D3MujocoError("QSDK_R23D42_MJC_PREFLIGHT_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d42_mujoco_worker_preflight_v1",
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "engine_id": ENGINE_ID,
        "stage_id": item.stage_id,
        "cell_id": item.cell_id,
        "arm_id": item.arm_id,
        "turn_heading_offset_rad": item.turn_heading_offset_rad,
        "segment_counts": segment_counts,
        "controller_policy_id": design.POLICY_ID,
        "controller_memory_schema": memory["schema_version"],
        "startup_ramp_id": design.STARTUP_RAMP_ID,
        "startup_ramp_step_count": design.STARTUP_RAMP_STEPS,
        "startup_ramp_canary": ramp_canary,
        "fixed_controller_horizon_step_count": design.CONTROLLER_STEPS,
        "terminal_restoration_or_taper_invoked": False,
        "turning_tested": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


for name, value in {
    "design": design,
    "evaluator": evaluator,
    "base": _bound_base,
    "LocomotionCore": _R23D42Core,
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
    "SCHEDULE_ID": "qsdk_r23d42_startup_ramp_turning_v1",
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
}.items():
    setattr(_core, name, value)


def _trace_row(**kwargs: Any) -> dict[str, Any]:
    row = _INHERITED_TRACE_ROW(**kwargs)
    row.update(_RAMP.trace_fields(int(kwargs["semantic_step"])))
    return row


_core._trace_row = _trace_row
_core.run_preflight = run_preflight


def run_physical(
    stage_id: str,
    onset_id: str,
    arm_id: str,
    source_commit: str,
) -> dict[str, Any]:
    _RAMP.reset()
    report = _core.run_physical(stage_id, onset_id, arm_id, source_commit)
    summary = _RAMP.summary()
    report["measurements"].update(summary)
    report["execution"].update(summary)
    report["execution"]["integrity_passed"] = bool(
        report["execution"]["integrity_passed"]
        and summary["startup_ramp_composition_integrity_passed"]
        and summary["startup_ramp_composition_step_count"]
        == design.CONTROLLER_STEPS
    )
    return report


def run_authorization_preflight(
    stage_id: str,
    onset_id: str,
    arm_id: str,
    source_commit: str,
) -> dict[str, Any]:
    """Exercise the exact production predicate and return before a model."""

    _contract()
    item = _cell(stage_id, onset_id, arm_id)
    if not _core._valid_lower_hex(source_commit, 40):
        raise _core.R23D3MujocoError("QSDK_R23D42_MJC_SOURCE_COMMIT_INVALID")
    _physical_authorization(item, source_commit)
    return {
        "schema_version": (
            "sporespore_qsdk_r23d42_mujoco_production_authorization_preflight_v1"
        ),
        "campaign_id": design.CAMPAIGN_ID,
        "gate_id": design.GATE_ID,
        "engine_id": ENGINE_ID,
        "stage_id": item.stage_id,
        "cell_id": item.cell_id,
        "actual_production_authorization_function": "_physical_authorization",
        "authorization_passed": True,
        "returned_before_model": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "command", choices=("preflight", "authorization-preflight", "physical")
    )
    parser.add_argument("--stage", required=True)
    parser.add_argument("--onset", default="onset_600")
    parser.add_argument("--arm", required=True)
    parser.add_argument("--source-commit", default="")
    args = parser.parse_args(argv)
    try:
        if args.command == "preflight":
            value = run_preflight(args.stage, args.onset, args.arm)
            marker = "QSDK_R23D42_MUJOCO_PREFLIGHT "
        elif args.command == "authorization-preflight":
            value = run_authorization_preflight(
                args.stage, args.onset, args.arm, args.source_commit
            )
            marker = "QSDK_R23D42_MUJOCO_AUTHORIZATION_PREFLIGHT "
        else:
            value = run_physical(
                args.stage, args.onset, args.arm, args.source_commit
            )
            marker = "QSDK_R23D42_MUJOCO_TERMINAL "
        print(marker + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    except _core.R23D3MujocoError as error:
        value = error.terminal_receipt or {"failure_code": error.code}
        print(
            "QSDK_R23D42_MUJOCO_TERMINAL "
            + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
