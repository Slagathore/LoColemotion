"""Canonical zero-world production trace contract for prospective QSDK-R23D20.

R23D20 inherits R23D19's heading-aligned controller and the already qualified
diagnostic, whole-body, residual-pose-authority, and R23D14 tight-gated temporal
semantics unchanged.  Its only changes repair adapter-session admission and
evidence retention.  This module loads the shared trace implementation under a
private identity and binds the distinct R23D20 campaign, matrix-stage, path
diagnostics, and evidence schemas.
The private load prevents an R23D20 import from mutating an R23D13 module that
may coexist in the same Python process.

The resulting trace has exactly 2,992 controller rows followed by 960 terminal
rows.  It is a schema/evidence implementation only: no adapter, model, or
physics world is imported or constructed here.
"""

from __future__ import annotations

import copy
from dataclasses import dataclass
import importlib.util
import math
from pathlib import Path
import sys
from types import ModuleType
from typing import Any, Sequence


MODULE_ROOT = Path(__file__).resolve().parent
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

import r23d11_stability_assisted_taper as composition
import r23d12_measurement_semantics as diagnostic_semantics
import r23d13_residual_pose_authority as authority
import r23d14_tight_gated_horizon as temporal


CAMPAIGN_ID = "QSDK-R23D20-ACTUAL-SESSION-INTEGRATION-RECOVERY-GODOT-DEVELOPMENT"
GATE_ID = "QSDK-R23D20"
POLICY_ID = temporal.POLICY_ID
CONTROLLER_POLICY_ID = "sporespore_balanced_wave_r23d19_heading_aligned_path_v1"
CROSS_TRACK_FRAME_MODE_ID = "command_heading_aligned_task_frame_v1"
TRACE_SCHEMA = "sporespore_qsdk_r23d20_physical_trace_v1"
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d20_physical_trace_row_v1"

PHYSICS_HZ = 120
CONTROLLER_STEPS = 2_992
TURN_START_STEP = 600
TURN_DURATION_STEPS = 1_200
REFERENCE_RECOVERY_STEPS = 600
REFERENCE_CONTINUATION_STEPS = 592
TERMINAL_STEPS = temporal.TERMINAL_STEPS
TOTAL_TRACE_STEPS = CONTROLLER_STEPS + TERMINAL_STEPS
ACTUATOR_COUNT = temporal.ACTUATOR_COUNT
MAXIMUM_COMBINED_VELOCITY_RAD_S = authority.MAXIMUM_ABSOLUTE_COMBINED_VELOCITY_RAD_S

LIMB_IDS = ("front_left", "front_right", "rear_left", "rear_right")
MATRIX_STAGE_ID = "godot_jolt_actual_session_integration_recovery_development"
MATRIX_ARMS = ("reference_zero", "positive_heading", "negative_heading")
MATRIX_ENGINES = ("godot_jolt",)
ARM_OFFSETS = {
    "reference_zero": 0.0,
    "positive_heading": 0.2,
    "negative_heading": -0.2,
}


class R23D20TraceError(RuntimeError):
    """The canonical R23D20 trace contract failed closed."""


def _load_private_core() -> ModuleType:
    source = MODULE_ROOT / "r23d13_physical_trace.py"
    specification = importlib.util.spec_from_file_location(
        "_sporespore_r23d20_inherited_trace_core",
        source,
    )
    if specification is None or specification.loader is None:
        raise R23D20TraceError("R23D20_INHERITED_TRACE_CORE_UNAVAILABLE")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


_core = _load_private_core()

# Bind every semantic global consumed by the inherited implementation.  These
# assignments affect only the private module instance above.
_core.temporal = temporal
_core.composition = composition
_core.diagnostic_semantics = diagnostic_semantics
_core.authority = authority
_core.CAMPAIGN_ID = CAMPAIGN_ID
_core.GATE_ID = GATE_ID
_core.POLICY_ID = POLICY_ID
_core.TRACE_SCHEMA = TRACE_SCHEMA
_core.TRACE_ROW_SCHEMA = TRACE_ROW_SCHEMA
_core.PHYSICS_HZ = PHYSICS_HZ
_core.CONTROLLER_STEPS = CONTROLLER_STEPS
_core.TURN_START_STEP = TURN_START_STEP
_core.TURN_DURATION_STEPS = TURN_DURATION_STEPS
_core.REFERENCE_RECOVERY_STEPS = REFERENCE_RECOVERY_STEPS
_core.REFERENCE_CONTINUATION_STEPS = REFERENCE_CONTINUATION_STEPS
_core.TERMINAL_STEPS = TERMINAL_STEPS
_core.TOTAL_TRACE_STEPS = TOTAL_TRACE_STEPS
_core.ACTUATOR_COUNT = ACTUATOR_COUNT
_core.MAXIMUM_COMBINED_VELOCITY_RAD_S = MAXIMUM_COMBINED_VELOCITY_RAD_S
_core.LIMB_IDS = LIMB_IDS
_core.ARM_OFFSETS = ARM_OFFSETS

Cell = _core.Cell
R23D20_CONTROLLER_DIAGNOSTIC_FIELDS = (
    "requested_heading_error_rad",
    "cross_track_error_m",
    "cross_track_velocity_m_s",
    "legacy_fixed_axis_cross_track_error_m",
    "legacy_fixed_axis_cross_track_velocity_m_s",
    "measured_yaw_error_rad",
    "desired_heading_error_rad",
    "yaw_tracking_error_rad",
    "requested_steering_fraction",
    "held_steering_fraction",
)
TRACE_ROW_FIELDS = _core.TRACE_ROW_FIELDS + R23D20_CONTROLLER_DIAGNOSTIC_FIELDS
_core.TRACE_ROW_FIELDS = TRACE_ROW_FIELDS


def matrix_cells() -> list[Cell]:
    """Return the exact declared three-cell Godot/Jolt development screen."""

    return [
        Cell(
            stage_id=MATRIX_STAGE_ID,
            cell_id=f"{engine_id}__tight_gated_horizon__{arm_id}",
            engine_id=engine_id,
            arm_id=arm_id,
            turn_heading_offset_rad=ARM_OFFSETS[arm_id],
        )
        for engine_id in MATRIX_ENGINES
        for arm_id in MATRIX_ARMS
    ]


def all_cells() -> list[Cell]:
    return matrix_cells()


def cell_for_identity(stage_id: str, cell_id: str) -> Cell:
    matches = [
        cell
        for cell in matrix_cells()
        if cell.stage_id == stage_id and cell.cell_id == cell_id
    ]
    if len(matches) != 1:
        raise R23D20TraceError("R23D20_CELL_IDENTITY_INVALID")
    return matches[0]


def _translate(value: Any) -> Any:
    if isinstance(value, str):
        return value.replace("R23D13", "R23D20").replace("QSDK-R23D13", "QSDK-R23D20")
    if isinstance(value, list):
        return [_translate(item) for item in value]
    if isinstance(value, tuple):
        return tuple(_translate(item) for item in value)
    if isinstance(value, dict):
        return {key: _translate(item) for key, item in value.items()}
    return value


def _invoke(function: Any, *args: Any, **kwargs: Any) -> Any:
    try:
        return function(*args, **kwargs)
    except Exception as error:
        message = str(_translate(str(error)))
        raise R23D20TraceError(message) from error


def controller_phase_for_step(cell: Cell, step: int) -> tuple[str, float]:
    return _invoke(_core.controller_phase_for_step, cell, step)


def expected_controller_phase_counts() -> dict[str, int]:
    return _core.expected_controller_phase_counts()


def synthetic_trace(
    cell: Cell,
    terminal_observations: Sequence[temporal.Observation] | None = None,
) -> list[dict[str, Any]]:
    rows = _invoke(_core.synthetic_trace, cell, terminal_observations)
    for row in rows:
        controller = int(row["trace_step"]) < CONTROLLER_STEPS
        desired_heading = float(row["desired_heading_offset_rad"])
        measured_yaw = float(row["measured_yaw_rad"])
        values: dict[str, float | None] = {
            "requested_heading_error_rad": desired_heading if controller else None,
            "cross_track_error_m": 0.0 if controller else None,
            "cross_track_velocity_m_s": 0.0 if controller else None,
            "legacy_fixed_axis_cross_track_error_m": 0.0 if controller else None,
            "legacy_fixed_axis_cross_track_velocity_m_s": 0.0 if controller else None,
            "measured_yaw_error_rad": measured_yaw if controller else None,
            "desired_heading_error_rad": desired_heading if controller else None,
            "yaw_tracking_error_rad": (
                desired_heading - measured_yaw if controller else None
            ),
            "requested_steering_fraction": 0.0 if controller else None,
            "held_steering_fraction": 0.0 if controller else None,
        }
        row.update(values)
    return rows


def validate_trace(cell: Cell, rows: Sequence[Any]) -> dict[str, Any]:
    result = _translate(_invoke(_core.validate_trace, cell, rows))
    failures: list[str] = []
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            continue
        controller = index < CONTROLLER_STEPS
        for field in R23D20_CONTROLLER_DIAGNOSTIC_FIELDS:
            value = row.get(field)
            if controller:
                if type(value) not in (int, float) or not math.isfinite(float(value)):
                    failures.append(f"R23D20_PATH_DIAGNOSTIC:{index}:{field}")
            elif value is not None:
                failures.append(f"R23D20_TERMINAL_PATH_DIAGNOSTIC:{index}:{field}")
    if failures:
        result["ok"] = False
        result["failure_codes"] = list(result.get("failure_codes", [])) + failures
    return result


def observations(
    *segments: tuple[int, tuple[bool, bool, bool, bool], float, float],
) -> list[temporal.Observation]:
    return _invoke(_core.observations, *segments)


def _canonical_row(row: Any) -> bytes:
    return _core._canonical_row(row)


def canonical_ndjson(rows: Sequence[dict[str, Any]]) -> bytes:
    return _core.canonical_ndjson(rows)


def zero_world_receipt() -> dict[str, Any]:
    cells = matrix_cells()
    results = [validate_trace(cell, synthetic_trace(cell)) for cell in cells]
    if not all(result["ok"] for result in results):
        raise R23D20TraceError("R23D20_SYNTHETIC_MATRIX_TRACE_FAILED")
    digests = [result["raw_sha256"] for result in results]
    return {
        "schema_version": "sporespore_qsdk_r23d20_physical_trace_preflight_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "policy_id": POLICY_ID,
        "controller_policy_id": CONTROLLER_POLICY_ID,
        "cross_track_frame_mode_id": CROSS_TRACK_FRAME_MODE_ID,
        "matrix_cell_count": len(cells),
        "trace_row_count_per_cell": TOTAL_TRACE_STEPS,
        "distinct_trace_digest_count": len(set(digests)),
        "trace_schema": TRACE_SCHEMA,
        "trace_row_schema": TRACE_ROW_SCHEMA,
        "controller_semantic_step_count": CONTROLLER_STEPS,
        "terminal_step_count": TERMINAL_STEPS,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }
