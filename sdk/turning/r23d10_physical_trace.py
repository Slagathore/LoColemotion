"""Canonical production trace contract for prospective QSDK-R23D10.

The module is engine-free and zero-world.  It defines the exact 2,992-step
turning-controller plus 900-step terminal trace that future MuJoCo, Rapier,
and Godot/Jolt workers must retain.  Terminal receipts are independently
replayed through the frozen stage-zero oracle.
"""

from __future__ import annotations

import copy
from dataclasses import dataclass
import hashlib
import json
import math
from pathlib import Path
import sys
from typing import Any, Iterable, Sequence


MODULE_ROOT = Path(__file__).resolve().parent
if str(MODULE_ROOT) not in sys.path:
    sys.path.insert(0, str(MODULE_ROOT))

import r23d10_quiescent_taper as terminal


CAMPAIGN_ID = (
    "QSDK-R23D10-SUPPORT-POSE-CONFIRMED-QUIESCENT-TAPER-"
    "BILATERAL-TURN-DEVELOPMENT"
)
GATE_ID = "QSDK-R23D10"
POLICY_ID = "sporespore_support_pose_confirmed_quiescent_taper_v1"
TRACE_SCHEMA = "sporespore_qsdk_r23d10_turn_quiescent_taper_trace_v1"
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d10_turn_quiescent_taper_trace_row_v1"

PHYSICS_HZ = 120
CONTROLLER_STEPS = 2_992
TURN_START_STEP = 600
TURN_DURATION_STEPS = 1_200
REFERENCE_RECOVERY_STEPS = 600
REFERENCE_CONTINUATION_STEPS = 592
TERMINAL_STEPS = terminal.TERMINAL_STEPS
TOTAL_TRACE_STEPS = CONTROLLER_STEPS + TERMINAL_STEPS
ACTUATOR_COUNT = terminal.ACTUATOR_COUNT
BASE_VELOCITY_LIMIT_RAD_S = 0.35

LIMB_IDS = ("front_left", "front_right", "rear_left", "rear_right")
STAGE_A_ID = "mujoco_quiescent_taper_screen"
STAGE_B_ID = "three_engine_confirmation"
STAGE_A_ARMS = ("positive_heading", "negative_heading")
STAGE_B_ARMS = ("reference_zero", "positive_heading", "negative_heading")
STAGE_B_ENGINES = ("godot_jolt", "rapier_parry", "mujoco")
ARM_OFFSETS = {
    "reference_zero": 0.0,
    "positive_heading": 0.2,
    "negative_heading": -0.2,
}

TRACE_ROW_FIELDS = (
    "schema_version",
    "cell_id",
    "trace_step",
    "phase_id",
    "controller_semantic_step",
    "desired_heading_offset_rad",
    "measured_yaw_rad",
    "torso_height_m",
    "torso_tilt_rad",
    "torso_ground_contact",
    "ordered_foot_contacts",
    "actuator_command_count",
    "native_actuation_application_count",
    "zero_actuation",
    "command_composition_mode",
    "taper_receipt_present",
    "pre_step_taper_count",
    "post_step_taper_count",
    "coarse_pose_satisfied",
    "tight_pose_satisfied",
    "velocity_scale_numerator",
    "velocity_scale_denominator",
    "transition_after_step",
    "taper_reset_after_step",
    "next_terminal_mode",
    "handoff_reason",
    "maximum_absolute_joint_position_error_rad",
    "maximum_absolute_commanded_joint_velocity_rad_s",
)


class R23D10TraceError(RuntimeError):
    """The canonical R23D10 trace contract failed closed."""


@dataclass(frozen=True)
class Cell:
    stage_id: str
    cell_id: str
    engine_id: str
    arm_id: str
    turn_heading_offset_rad: float


def stage_a_cells() -> list[Cell]:
    return [
        Cell(
            stage_id=STAGE_A_ID,
            cell_id=f"mujoco__quiescent_taper__{arm_id}",
            engine_id="mujoco",
            arm_id=arm_id,
            turn_heading_offset_rad=ARM_OFFSETS[arm_id],
        )
        for arm_id in STAGE_A_ARMS
    ]


def stage_b_cells() -> list[Cell]:
    return [
        Cell(
            stage_id=STAGE_B_ID,
            cell_id=f"{engine_id}__quiescent_taper__{arm_id}",
            engine_id=engine_id,
            arm_id=arm_id,
            turn_heading_offset_rad=ARM_OFFSETS[arm_id],
        )
        for engine_id in STAGE_B_ENGINES
        for arm_id in STAGE_B_ARMS
    ]


def all_cells() -> list[Cell]:
    return stage_a_cells() + stage_b_cells()


def cell_for_identity(stage_id: str, cell_id: str) -> Cell:
    matches = [
        cell
        for cell in all_cells()
        if cell.stage_id == stage_id and cell.cell_id == cell_id
    ]
    if len(matches) != 1:
        raise R23D10TraceError("R23D10_CELL_IDENTITY_INVALID")
    return matches[0]


def _exact_keys(value: Any, fields: Iterable[str]) -> bool:
    return isinstance(value, dict) and set(value) == set(fields)


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _canonical_row(row: Any) -> bytes:
    return (
        json.dumps(
            row,
            allow_nan=False,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
        + "\n"
    ).encode("utf-8")


def canonical_ndjson(rows: Sequence[dict[str, Any]]) -> bytes:
    return b"".join(_canonical_row(row) for row in rows)


def controller_phase_for_step(cell: Cell, step: int) -> tuple[str, float]:
    if step < 0 or step >= CONTROLLER_STEPS:
        raise R23D10TraceError("R23D10_CONTROLLER_STEP_OUTSIDE_HORIZON")
    if step < TURN_START_STEP:
        return "reference_warmup", 0.0
    if step < TURN_START_STEP + TURN_DURATION_STEPS:
        return "commanded_turn", cell.turn_heading_offset_rad
    if step < TURN_START_STEP + TURN_DURATION_STEPS + REFERENCE_RECOVERY_STEPS:
        return "reference_recovery", 0.0
    return "reference_continuation", 0.0


def expected_controller_phase_counts() -> dict[str, int]:
    return {
        "reference_warmup": TURN_START_STEP,
        "commanded_turn": TURN_DURATION_STEPS,
        "reference_recovery": REFERENCE_RECOVERY_STEPS,
        "reference_continuation": REFERENCE_CONTINUATION_STEPS,
    }


def _controller_row(cell: Cell, step: int) -> dict[str, Any]:
    phase, desired_heading = controller_phase_for_step(cell, step)
    if phase == "reference_warmup":
        measured_yaw = 0.0
    elif phase == "commanded_turn":
        progress = (step - TURN_START_STEP + 1) / TURN_DURATION_STEPS
        measured_yaw = cell.turn_heading_offset_rad * 0.5 * progress
    else:
        measured_yaw = cell.turn_heading_offset_rad * 0.5
    return {
        "schema_version": TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": step,
        "phase_id": phase,
        "controller_semantic_step": step,
        "desired_heading_offset_rad": desired_heading,
        "measured_yaw_rad": measured_yaw,
        "torso_height_m": 0.4,
        "torso_tilt_rad": 0.1,
        "torso_ground_contact": False,
        "ordered_foot_contacts": {limb: True for limb in LIMB_IDS},
        "actuator_command_count": ACTUATOR_COUNT,
        "native_actuation_application_count": ACTUATOR_COUNT,
        "zero_actuation": False,
        "command_composition_mode": "balanced_wave_turning_v1",
        "taper_receipt_present": False,
        "pre_step_taper_count": None,
        "post_step_taper_count": None,
        "coarse_pose_satisfied": None,
        "tight_pose_satisfied": None,
        "velocity_scale_numerator": None,
        "velocity_scale_denominator": None,
        "transition_after_step": False,
        "taper_reset_after_step": False,
        "next_terminal_mode": None,
        "handoff_reason": None,
        "maximum_absolute_joint_position_error_rad": None,
        "maximum_absolute_commanded_joint_velocity_rad_s": None,
    }


def _terminal_phase(mode: str) -> tuple[str, str]:
    if mode == terminal.ACTIVE_MODE:
        return "terminal_neutral_acquisition", "neutral_stance_full_authority_v1"
    if mode == terminal.TAPER_MODE:
        return "terminal_quiescent_taper", "neutral_stance_quiescent_taper_v1"
    if mode == terminal.PASSIVE_MODE:
        return "terminal_irreversible_zero_actuation", "passive_zero_actuation_v1"
    raise R23D10TraceError("R23D10_TERMINAL_MODE_INVALID")


def _terminal_row(
    cell: Cell,
    trace_step: int,
    observation: terminal.Observation,
    receipt: dict[str, Any],
) -> dict[str, Any]:
    phase, composition = _terminal_phase(str(receipt["mode"]))
    active = receipt["mode"] != terminal.PASSIVE_MODE
    numerator = int(receipt["velocity_scale_numerator"])
    denominator = int(receipt["velocity_scale_denominator"])
    return {
        "schema_version": TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase,
        "controller_semantic_step": None,
        "desired_heading_offset_rad": 0.0,
        "measured_yaw_rad": cell.turn_heading_offset_rad * 0.5,
        "torso_height_m": 0.4,
        "torso_tilt_rad": observation.torso_tilt_rad,
        "torso_ground_contact": False,
        "ordered_foot_contacts": dict(zip(LIMB_IDS, observation.contacts, strict=True)),
        "actuator_command_count": ACTUATOR_COUNT if active else 0,
        "native_actuation_application_count": receipt["native_application_count"],
        "zero_actuation": not active,
        "command_composition_mode": composition,
        "taper_receipt_present": True,
        "pre_step_taper_count": receipt["pre_step_taper_count"],
        "post_step_taper_count": receipt["post_step_taper_count"],
        "coarse_pose_satisfied": receipt["coarse_pose_satisfied"],
        "tight_pose_satisfied": receipt["tight_pose_satisfied"],
        "velocity_scale_numerator": numerator,
        "velocity_scale_denominator": denominator,
        "transition_after_step": receipt["transition_after_step"],
        "taper_reset_after_step": receipt["taper_reset_after_step"],
        "next_terminal_mode": receipt["next_mode"],
        "handoff_reason": receipt["handoff_reason"],
        "maximum_absolute_joint_position_error_rad": (
            observation.maximum_absolute_joint_position_error_rad
        ),
        "maximum_absolute_commanded_joint_velocity_rad_s": (
            BASE_VELOCITY_LIMIT_RAD_S * numerator / denominator if active else None
        ),
    }


def synthetic_trace(
    cell: Cell,
    terminal_observations: Sequence[terminal.Observation] | None = None,
) -> list[dict[str, Any]]:
    observations = list(
        terminal_observations
        if terminal_observations is not None
        else [
            terminal.Observation((True, True, True, True), 0.005, 0.18)
            for _ in range(TERMINAL_STEPS)
        ]
    )
    if len(observations) != TERMINAL_STEPS:
        raise R23D10TraceError("R23D10_SYNTHETIC_TERMINAL_HORIZON_INVALID")
    rows = [_controller_row(cell, step) for step in range(CONTROLLER_STEPS)]
    state = terminal.State()
    for terminal_step, observation in enumerate(observations):
        numerator, denominator = terminal.expected_velocity_scale_fraction(state)
        applications = 0 if state.mode == terminal.PASSIVE_MODE else ACTUATOR_COUNT
        state, receipt = terminal.observe_completed_step(
            state,
            observation,
            applications,
            numerator,
            denominator,
        )
        rows.append(
            _terminal_row(
                cell,
                CONTROLLER_STEPS + terminal_step,
                observation,
                receipt,
            )
        )
    return rows


def _contacts(value: Any) -> tuple[bool, bool, bool, bool] | None:
    if (
        not isinstance(value, dict)
        or list(value) != list(LIMB_IDS)
        or any(type(contact) is not bool for contact in value.values())
    ):
        return None
    return tuple(value[limb] for limb in LIMB_IDS)  # type: ignore[return-value]


def validate_trace(cell: Cell, rows: Sequence[Any]) -> dict[str, Any]:
    failures: list[str] = []
    phase_counts = {
        **{phase: 0 for phase in expected_controller_phase_counts()},
        "terminal_neutral_acquisition": 0,
        "terminal_quiescent_taper": 0,
        "terminal_irreversible_zero_actuation": 0,
    }
    hasher = hashlib.sha256()
    byte_length = 0
    state = terminal.State()
    terminal_replay_valid = True
    if len(rows) != TOTAL_TRACE_STEPS:
        failures.append("R23D10_TRACE_ROW_COUNT")

    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            failures.append(f"R23D10_TRACE_ROW_TYPE:{index}")
            terminal_replay_valid = False
            continue
        try:
            raw = _canonical_row(row)
        except (TypeError, ValueError):
            failures.append(f"R23D10_TRACE_ROW_CANONICAL:{index}")
            terminal_replay_valid = False
            continue
        hasher.update(raw)
        byte_length += len(raw)
        if not _exact_keys(row, TRACE_ROW_FIELDS):
            failures.append(f"R23D10_TRACE_ROW_FIELDS:{index}")
            terminal_replay_valid = False
            continue
        if (
            row.get("schema_version") != TRACE_ROW_SCHEMA
            or row.get("cell_id") != cell.cell_id
            or type(row.get("trace_step")) is not int
            or row.get("trace_step") != index
        ):
            failures.append(f"R23D10_TRACE_ROW_IDENTITY:{index}")

        contacts = _contacts(row.get("ordered_foot_contacts"))
        observation_valid = (
            _finite(row.get("measured_yaw_rad"))
            and _finite(row.get("torso_height_m"))
            and _finite(row.get("torso_tilt_rad"))
            and float(row.get("torso_tilt_rad", -1.0)) >= 0.0
            and type(row.get("torso_ground_contact")) is bool
            and contacts is not None
        )
        if not observation_valid:
            failures.append(f"R23D10_TRACE_OBSERVATION:{index}")

        if index < CONTROLLER_STEPS:
            expected_phase, expected_heading = controller_phase_for_step(cell, index)
            if (
                row.get("phase_id") != expected_phase
                or row.get("controller_semantic_step") != index
                or not _finite(row.get("desired_heading_offset_rad"))
                or not math.isclose(
                    float(row.get("desired_heading_offset_rad", math.inf)),
                    expected_heading,
                    rel_tol=0.0,
                    abs_tol=1.0e-12,
                )
            ):
                failures.append(f"R23D10_TRACE_CONTROLLER_PHASE:{index}")
            else:
                phase_counts[expected_phase] += 1
            if (
                row.get("actuator_command_count") != ACTUATOR_COUNT
                or row.get("native_actuation_application_count") != ACTUATOR_COUNT
                or row.get("zero_actuation") is not False
                or row.get("command_composition_mode") != "balanced_wave_turning_v1"
                or row.get("taper_receipt_present") is not False
                or row.get("pre_step_taper_count") is not None
                or row.get("post_step_taper_count") is not None
                or row.get("coarse_pose_satisfied") is not None
                or row.get("tight_pose_satisfied") is not None
                or row.get("velocity_scale_numerator") is not None
                or row.get("velocity_scale_denominator") is not None
                or row.get("transition_after_step") is not False
                or row.get("taper_reset_after_step") is not False
                or row.get("next_terminal_mode") is not None
                or row.get("handoff_reason") is not None
                or row.get("maximum_absolute_joint_position_error_rad") is not None
                or row.get("maximum_absolute_commanded_joint_velocity_rad_s") is not None
            ):
                failures.append(f"R23D10_TRACE_CONTROLLER_ACTUATION:{index}")
            continue

        terminal_step = index - CONTROLLER_STEPS
        joint_error = row.get("maximum_absolute_joint_position_error_rad")
        if (
            not observation_valid
            or contacts is None
            or not _finite(joint_error)
            or float(joint_error) < 0.0
            or not terminal_replay_valid
        ):
            failures.append(f"R23D10_TRACE_TERMINAL_OBSERVATION:{terminal_step}")
            terminal_replay_valid = False
            continue
        if type(row.get("native_actuation_application_count")) is not int:
            failures.append(f"R23D10_TRACE_TERMINAL_APPLICATION_TYPE:{terminal_step}")
            terminal_replay_valid = False
            continue

        pre_mode = state.mode
        try:
            expected_numerator, expected_denominator = (
                terminal.expected_velocity_scale_fraction(state)
            )
            observation = terminal.Observation(
                contacts,
                float(row["torso_tilt_rad"]),
                float(joint_error),
            )
            next_state, expected_receipt = terminal.observe_completed_step(
                state,
                observation,
                int(row["native_actuation_application_count"]),
                int(row.get("velocity_scale_numerator", -1)),
                int(row.get("velocity_scale_denominator", -1)),
            )
        except (terminal.ContractError, TypeError, ValueError) as error:
            failures.append(
                f"R23D10_TRACE_TERMINAL_REPLAY:{terminal_step}:{type(error).__name__}"
            )
            terminal_replay_valid = False
            continue

        expected_phase, expected_composition = _terminal_phase(pre_mode)
        active = pre_mode != terminal.PASSIVE_MODE
        receipt_projection = {
            "pre_step_taper_count": row.get("pre_step_taper_count"),
            "post_step_taper_count": row.get("post_step_taper_count"),
            "coarse_pose_satisfied": row.get("coarse_pose_satisfied"),
            "tight_pose_satisfied": row.get("tight_pose_satisfied"),
            "velocity_scale_numerator": row.get("velocity_scale_numerator"),
            "velocity_scale_denominator": row.get("velocity_scale_denominator"),
            "transition_after_step": row.get("transition_after_step"),
            "taper_reset_after_step": row.get("taper_reset_after_step"),
            "next_mode": row.get("next_terminal_mode"),
            "handoff_reason": row.get("handoff_reason"),
            "native_application_count": row.get(
                "native_actuation_application_count"
            ),
        }
        expected_projection = {
            key: expected_receipt[key] for key in receipt_projection
        }
        commanded_velocity = row.get(
            "maximum_absolute_commanded_joint_velocity_rad_s"
        )
        velocity_limit = (
            BASE_VELOCITY_LIMIT_RAD_S
            * expected_numerator
            / expected_denominator
        )
        velocity_valid = (
            _finite(commanded_velocity)
            and 0.0 <= float(commanded_velocity) <= velocity_limit + 1.0e-12
            if active
            else commanded_velocity is None
        )
        if (
            row.get("phase_id") != expected_phase
            or row.get("controller_semantic_step") is not None
            or row.get("desired_heading_offset_rad") != 0.0
            or row.get("actuator_command_count")
            != (ACTUATOR_COUNT if active else 0)
            or row.get("zero_actuation") is active
            or row.get("command_composition_mode") != expected_composition
            or row.get("taper_receipt_present") is not True
            or receipt_projection != expected_projection
            or not velocity_valid
        ):
            failures.append(f"R23D10_TRACE_TERMINAL_SEMANTICS:{terminal_step}")
        phase_counts[expected_phase] += 1
        state = next_state

    expected_controller = expected_controller_phase_counts()
    if any(
        phase_counts[phase] != count
        for phase, count in expected_controller.items()
    ):
        failures.append("R23D10_TRACE_CONTROLLER_PHASE_COUNTS")
    if (
        phase_counts["terminal_neutral_acquisition"]
        + phase_counts["terminal_quiescent_taper"]
        + phase_counts["terminal_irreversible_zero_actuation"]
        != TERMINAL_STEPS
    ):
        failures.append("R23D10_TRACE_TERMINAL_PHASE_COUNTS")

    replay_outcome: dict[str, Any] | None = None
    if terminal_replay_valid and state.next_step == TERMINAL_STEPS:
        try:
            replay_outcome = terminal.outcome(state)
        except terminal.ContractError as error:
            failures.append(f"R23D10_TRACE_TERMINAL_OUTCOME:{error}")
    else:
        failures.append("R23D10_TRACE_TERMINAL_OUTCOME_UNAVAILABLE")
    return {
        "ok": not failures,
        "failure_codes": failures,
        "row_count": len(rows),
        "raw_sha256": "sha256:" + hasher.hexdigest(),
        "byte_length": byte_length,
        "hash_projection": "sha256_canonical_sorted_key_ndjson_rows_v1",
        "phase_counts": phase_counts,
        "taper_outcome": replay_outcome,
    }


def observations(
    *segments: tuple[
        int,
        tuple[bool, bool, bool, bool],
        float,
        float,
    ],
) -> list[terminal.Observation]:
    result: list[terminal.Observation] = []
    for count, contacts, tilt, joint_error in segments:
        if count < 0:
            raise R23D10TraceError("R23D10_OBSERVATION_SEGMENT_INVALID")
        result.extend(
            terminal.Observation(contacts, float(tilt), float(joint_error))
            for _ in range(count)
        )
    if len(result) != TERMINAL_STEPS:
        raise R23D10TraceError("R23D10_OBSERVATION_HORIZON_INVALID")
    return result
