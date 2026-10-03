"""Pure support-confirmed active-to-passive handoff oracle for QSDK-R23D9.

This module owns no physics adapter and constructs no model or world.  It
freezes the temporal state machine that future MuJoCo, Rapier/Parry, and
Godot/Jolt workers must implement around the unchanged R23D8 neutral-stance
command equation.
"""

from __future__ import annotations

import copy
import hashlib
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Sequence

from r23d8_neutral_stance import bounded_neutral_velocity


ROOT = Path(__file__).resolve().parent
DECLARATION_PATH = ROOT / "r23d9_support_handoff_preregistration_v1.json"
PREDECESSOR_CLOSURE_PATH = ROOT / "r23d8_physical_closure_v1.json"
PREDECESSOR_CONTRACT_PATH = ROOT / "r23d8_scientific_execution_contract_v1.json"
PREDECESSOR_NEUTRAL_ORACLE_PATH = ROOT / "r23d8_neutral_stance.py"

SCHEMA_VERSION = "sporespore_qsdk_r23d9_support_handoff_preregistration_v1"
CAMPAIGN_ID = (
    "QSDK-R23D9-SUPPORT-CONFIRMED-ACTIVE-TO-PASSIVE-HANDOFF-"
    "BILATERAL-TURN-DEVELOPMENT"
)
GATE_ID = "QSDK-R23D9"
POLICY_ID = "sporespore_support_confirmed_irreversible_passive_handoff_v1"
ACTIVE_POLICY_ID = "sporespore_morphology_neutral_stance_bounded_pd_v1"
TRACE_SCHEMA = "sporespore_qsdk_r23d9_turn_support_handoff_trace_v1"
TRACE_ROW_SCHEMA = "sporespore_qsdk_r23d9_turn_support_handoff_trace_row_v1"

PHYSICS_HZ = 120
CONTROLLER_STEPS = 2_992
TURN_START_STEP = 600
TURN_DURATION_STEPS = 1_200
REFERENCE_RECOVERY_STEPS = 600
REFERENCE_CONTINUATION_STEPS = 592
TERMINAL_STEPS = 780
MAXIMUM_ACTIVE_STEPS = 420
SUPPORT_CONFIRMATION_STEPS = 30
MINIMUM_PASSIVE_STEPS = 360
ACTUATOR_COUNT = 8
TOTAL_TRACE_STEPS = CONTROLLER_STEPS + TERMINAL_STEPS
MINIMUM_TOTAL_ACTIVE_APPLICATIONS = (
    CONTROLLER_STEPS + SUPPORT_CONFIRMATION_STEPS
) * ACTUATOR_COUNT
MAXIMUM_TOTAL_ACTIVE_APPLICATIONS = (
    CONTROLLER_STEPS + MAXIMUM_ACTIVE_STEPS
) * ACTUATOR_COUNT

ACTIVE_MODE = "active_neutral_acquisition"
PASSIVE_MODE = "irreversible_zero_actuation_stability"
SUPPORT_CONFIRMED_REASON = "support_confirmed"
DEADLINE_FORCED_REASON = "deadline_forced_without_support_confirmation"
LIMB_IDS = ("front_left", "front_right", "rear_left", "rear_right")
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
    "handoff_receipt_present",
    "pre_step_support_counter",
    "post_step_support_counter",
    "transition_after_step",
    "next_terminal_mode",
    "handoff_reason",
    "maximum_absolute_joint_position_error_rad",
    "maximum_absolute_commanded_joint_velocity_rad_s",
)


class R23D9Error(RuntimeError):
    """Fail-closed R23D9 stage-zero contract error."""


@dataclass(frozen=True)
class Cell:
    stage_id: str
    cell_id: str
    engine_id: str
    arm_id: str
    turn_heading_offset_rad: float


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _exact_keys(value: Any, expected: Iterable[str]) -> bool:
    return isinstance(value, dict) and set(value) == set(expected)


def _canonical(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    ).encode("utf-8")


def _canonical_row(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            allow_nan=False,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
        + "\n"
    ).encode("utf-8")


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _contacts(value: Sequence[bool]) -> tuple[bool, bool, bool, bool]:
    if (
        isinstance(value, (str, bytes))
        or len(value) != len(LIMB_IDS)
        or any(type(item) is not bool for item in value)
    ):
        raise R23D9Error("R23D9_CONTACT_VECTOR_INVALID")
    return tuple(value)  # type: ignore[return-value]


@dataclass(frozen=True)
class HandoffState:
    next_step: int = 0
    mode: str = ACTIVE_MODE
    consecutive_all_four_contact_steps: int = 0
    handoff_after_active_step: int | None = None
    first_passive_step: int | None = None
    handoff_reason: str | None = None
    support_confirmed: bool = False
    active_step_count: int = 0
    passive_step_count: int = 0
    active_native_application_count: int = 0
    passive_native_application_count: int = 0
    first_post_handoff_contact_loss_step: int | None = None
    post_handoff_contact_loss_step_count: int = 0


@dataclass(frozen=True)
class StepDirective:
    step: int
    mode: str
    apply_neutral_commands: bool
    expected_native_application_count: int
    pre_step_support_counter: int


def stage_a_cells() -> list[Cell]:
    return [
        Cell(
            stage_id="mujoco_support_handoff_screen",
            cell_id=f"mujoco__support_handoff__{arm_id}",
            engine_id="mujoco",
            arm_id=arm_id,
            turn_heading_offset_rad=ARM_OFFSETS[arm_id],
        )
        for arm_id in STAGE_A_ARMS
    ]


def stage_b_cells() -> list[Cell]:
    return [
        Cell(
            stage_id="three_engine_confirmation",
            cell_id=f"{engine_id}__support_handoff__{arm_id}",
            engine_id=engine_id,
            arm_id=arm_id,
            turn_heading_offset_rad=ARM_OFFSETS[arm_id],
        )
        for engine_id in STAGE_B_ENGINES
        for arm_id in STAGE_B_ARMS
    ]


def all_cells() -> list[Cell]:
    return stage_a_cells() + stage_b_cells()


def initial_state() -> HandoffState:
    return HandoffState()


def plan_step(state: HandoffState) -> StepDirective:
    if state.next_step < 0 or state.next_step >= TERMINAL_STEPS:
        raise R23D9Error("R23D9_STEP_OUTSIDE_TERMINAL_HORIZON")
    if state.mode not in (ACTIVE_MODE, PASSIVE_MODE):
        raise R23D9Error("R23D9_MODE_INVALID")
    active = state.mode == ACTIVE_MODE
    return StepDirective(
        step=state.next_step,
        mode=state.mode,
        apply_neutral_commands=active,
        expected_native_application_count=ACTUATOR_COUNT if active else 0,
        pre_step_support_counter=state.consecutive_all_four_contact_steps,
    )


def observe_completed_step(
    state: HandoffState,
    directive: StepDirective,
    ordered_contacts: Sequence[bool],
    observed_native_application_count: int,
) -> tuple[HandoffState, dict[str, Any]]:
    contacts = _contacts(ordered_contacts)
    if directive != plan_step(state):
        raise R23D9Error("R23D9_STEP_DIRECTIVE_STALE_OR_MUTATED")
    if observed_native_application_count != directive.expected_native_application_count:
        raise R23D9Error("R23D9_NATIVE_APPLICATION_COUNT_MISMATCH")

    all_four = all(contacts)
    post_counter = state.consecutive_all_four_contact_steps
    next_mode = state.mode
    handoff_after = state.handoff_after_active_step
    first_passive = state.first_passive_step
    handoff_reason = state.handoff_reason
    support_confirmed = state.support_confirmed
    first_loss = state.first_post_handoff_contact_loss_step
    loss_count = state.post_handoff_contact_loss_step_count

    if state.mode == ACTIVE_MODE:
        post_counter = state.consecutive_all_four_contact_steps + 1 if all_four else 0
        if post_counter >= SUPPORT_CONFIRMATION_STEPS:
            next_mode = PASSIVE_MODE
            handoff_after = directive.step
            first_passive = directive.step + 1
            handoff_reason = SUPPORT_CONFIRMED_REASON
            support_confirmed = True
        elif directive.step == MAXIMUM_ACTIVE_STEPS - 1:
            next_mode = PASSIVE_MODE
            handoff_after = directive.step
            first_passive = directive.step + 1
            handoff_reason = DEADLINE_FORCED_REASON
            support_confirmed = False
        elif directive.step >= MAXIMUM_ACTIVE_STEPS:
            raise R23D9Error("R23D9_ACTIVE_STEP_AFTER_DEADLINE")
    elif not all_four:
        loss_count += 1
        if first_loss is None:
            first_loss = directive.step

    next_state = HandoffState(
        next_step=directive.step + 1,
        mode=next_mode,
        consecutive_all_four_contact_steps=post_counter,
        handoff_after_active_step=handoff_after,
        first_passive_step=first_passive,
        handoff_reason=handoff_reason,
        support_confirmed=support_confirmed,
        active_step_count=state.active_step_count + int(state.mode == ACTIVE_MODE),
        passive_step_count=state.passive_step_count + int(state.mode == PASSIVE_MODE),
        active_native_application_count=(
            state.active_native_application_count
            + observed_native_application_count * int(state.mode == ACTIVE_MODE)
        ),
        passive_native_application_count=(
            state.passive_native_application_count
            + observed_native_application_count * int(state.mode == PASSIVE_MODE)
        ),
        first_post_handoff_contact_loss_step=first_loss,
        post_handoff_contact_loss_step_count=loss_count,
    )
    receipt = {
        "schema_version": "sporespore_qsdk_r23d9_handoff_step_receipt_v1",
        "step": directive.step,
        "mode": directive.mode,
        "ordered_contacts": dict(zip(LIMB_IDS, contacts, strict=True)),
        "all_four_contacts": all_four,
        "pre_step_support_counter": directive.pre_step_support_counter,
        "post_step_support_counter": post_counter,
        "neutral_commands_applied": directive.apply_neutral_commands,
        "native_application_count": observed_native_application_count,
        "transition_after_step": next_mode != state.mode,
        "next_mode": next_mode,
        "handoff_reason": handoff_reason if next_mode != state.mode else None,
    }
    return next_state, receipt


def outcome(state: HandoffState) -> dict[str, Any]:
    if state.next_step != TERMINAL_STEPS:
        raise R23D9Error("R23D9_OUTCOME_BEFORE_COMPLETE_HORIZON")
    first_passive = state.first_passive_step
    passed = (
        state.support_confirmed
        and state.handoff_reason == SUPPORT_CONFIRMED_REASON
        and first_passive is not None
        and SUPPORT_CONFIRMATION_STEPS <= first_passive <= MAXIMUM_ACTIVE_STEPS
        and state.passive_step_count >= MINIMUM_PASSIVE_STEPS
        and state.passive_native_application_count == 0
        and state.post_handoff_contact_loss_step_count == 0
        and state.mode == PASSIVE_MODE
    )
    return {
        "schema_version": "sporespore_qsdk_r23d9_handoff_outcome_v1",
        "terminal_step_count": state.next_step,
        "handoff_reason": state.handoff_reason,
        "support_confirmed": state.support_confirmed,
        "handoff_after_active_step": state.handoff_after_active_step,
        "first_passive_step": first_passive,
        "active_step_count": state.active_step_count,
        "passive_step_count": state.passive_step_count,
        "active_native_application_count": state.active_native_application_count,
        "passive_native_application_count": state.passive_native_application_count,
        "first_post_handoff_contact_loss_step": (
            state.first_post_handoff_contact_loss_step
        ),
        "post_handoff_contact_loss_step_count": (
            state.post_handoff_contact_loss_step_count
        ),
        "irreversible_handoff_gate_passed": passed,
    }


def simulate(
    ordered_contact_rows: Sequence[Sequence[bool]],
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    if len(ordered_contact_rows) != TERMINAL_STEPS:
        raise R23D9Error("R23D9_CONTACT_SEQUENCE_HORIZON_INVALID")
    state = initial_state()
    receipts: list[dict[str, Any]] = []
    for contacts in ordered_contact_rows:
        directive = plan_step(state)
        state, receipt = observe_completed_step(
            state,
            directive,
            contacts,
            directive.expected_native_application_count,
        )
        receipts.append(receipt)
    return receipts, outcome(state)


def validation_failures(
    ordered_contact_rows: Sequence[Sequence[bool]],
    receipts: Any,
    reported_outcome: Any,
) -> list[str]:
    try:
        expected_receipts, expected_outcome = simulate(ordered_contact_rows)
    except (R23D9Error, TypeError, ValueError) as error:
        return [f"R23D9_INPUT_INVALID:{type(error).__name__}"]
    failures: list[str] = []
    if not isinstance(receipts, list) or len(receipts) != TERMINAL_STEPS:
        failures.append("R23D9_RECEIPT_HORIZON")
    elif _canonical(receipts) != _canonical(expected_receipts):
        failures.append("R23D9_RECEIPT_REPLAY")
    if not isinstance(reported_outcome, dict):
        failures.append("R23D9_OUTCOME_SHAPE")
    elif _canonical(reported_outcome) != _canonical(expected_outcome):
        failures.append("R23D9_OUTCOME_REPLAY")
    return failures


def controller_phase_for_step(
    cell: Cell, semantic_step: int
) -> tuple[str, float]:
    if semantic_step < 0 or semantic_step >= CONTROLLER_STEPS:
        raise R23D9Error("R23D9_CONTROLLER_STEP_OUT_OF_RANGE")
    if semantic_step < TURN_START_STEP:
        return "reference_warmup", 0.0
    if semantic_step < TURN_START_STEP + TURN_DURATION_STEPS:
        return "commanded_turn", cell.turn_heading_offset_rad
    if semantic_step < (
        TURN_START_STEP + TURN_DURATION_STEPS + REFERENCE_RECOVERY_STEPS
    ):
        return "reference_recovery", 0.0
    return "reference_continuation", 0.0


def expected_controller_phase_counts() -> dict[str, int]:
    return {
        "reference_warmup": TURN_START_STEP,
        "commanded_turn": TURN_DURATION_STEPS,
        "reference_recovery": REFERENCE_RECOVERY_STEPS,
        "reference_continuation": REFERENCE_CONTINUATION_STEPS,
    }


def _synthetic_controller_row(cell: Cell, trace_step: int) -> dict[str, Any]:
    phase_id, desired_heading = controller_phase_for_step(cell, trace_step)
    if phase_id == "reference_warmup":
        measured_yaw = 0.0
    elif phase_id == "commanded_turn":
        progress = (trace_step - TURN_START_STEP + 1) / TURN_DURATION_STEPS
        measured_yaw = cell.turn_heading_offset_rad * 0.5 * progress
    else:
        measured_yaw = cell.turn_heading_offset_rad * 0.5
    return {
        "schema_version": TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": phase_id,
        "controller_semantic_step": trace_step,
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
        "handoff_receipt_present": False,
        "pre_step_support_counter": None,
        "post_step_support_counter": None,
        "transition_after_step": False,
        "next_terminal_mode": None,
        "handoff_reason": None,
        "maximum_absolute_joint_position_error_rad": None,
        "maximum_absolute_commanded_joint_velocity_rad_s": None,
    }


def _synthetic_terminal_row(
    cell: Cell,
    trace_step: int,
    directive: StepDirective,
    receipt: dict[str, Any],
) -> dict[str, Any]:
    active = directive.mode == ACTIVE_MODE
    return {
        "schema_version": TRACE_ROW_SCHEMA,
        "cell_id": cell.cell_id,
        "trace_step": trace_step,
        "phase_id": (
            "terminal_neutral_acquisition"
            if active
            else "terminal_irreversible_zero_actuation"
        ),
        "controller_semantic_step": None,
        "desired_heading_offset_rad": 0.0,
        "measured_yaw_rad": cell.turn_heading_offset_rad * 0.5,
        "torso_height_m": 0.4,
        "torso_tilt_rad": 0.1,
        "torso_ground_contact": False,
        "ordered_foot_contacts": copy.deepcopy(receipt["ordered_contacts"]),
        "actuator_command_count": directive.expected_native_application_count,
        "native_actuation_application_count": receipt["native_application_count"],
        "zero_actuation": not active,
        "command_composition_mode": (
            ACTIVE_POLICY_ID if active else "passive_zero_actuation_v1"
        ),
        "handoff_receipt_present": True,
        "pre_step_support_counter": receipt["pre_step_support_counter"],
        "post_step_support_counter": receipt["post_step_support_counter"],
        "transition_after_step": receipt["transition_after_step"],
        "next_terminal_mode": receipt["next_mode"],
        "handoff_reason": receipt["handoff_reason"],
        "maximum_absolute_joint_position_error_rad": 0.05 if active else None,
        "maximum_absolute_commanded_joint_velocity_rad_s": (
            0.35 if active else None
        ),
    }


def synthetic_trace(
    cell: Cell,
    terminal_contacts: Sequence[Sequence[bool]] | None = None,
) -> list[dict[str, Any]]:
    contacts = (
        terminal_contacts
        if terminal_contacts is not None
        else [(True, True, True, True)] * TERMINAL_STEPS
    )
    if len(contacts) != TERMINAL_STEPS:
        raise R23D9Error("R23D9_SYNTHETIC_TERMINAL_HORIZON_INVALID")
    rows = [
        _synthetic_controller_row(cell, step) for step in range(CONTROLLER_STEPS)
    ]
    state = initial_state()
    for terminal_step, ordered_contacts in enumerate(contacts):
        directive = plan_step(state)
        state, receipt = observe_completed_step(
            state,
            directive,
            ordered_contacts,
            directive.expected_native_application_count,
        )
        rows.append(
            _synthetic_terminal_row(
                cell,
                CONTROLLER_STEPS + terminal_step,
                directive,
                receipt,
            )
        )
    return rows


def validate_trace(cell: Cell, rows: Sequence[Any]) -> dict[str, Any]:
    failures: list[str] = []
    phase_counts: dict[str, int] = {
        **expected_controller_phase_counts(),
        "terminal_neutral_acquisition": 0,
        "terminal_irreversible_zero_actuation": 0,
    }
    for phase in phase_counts:
        phase_counts[phase] = 0
    hasher = hashlib.sha256()
    byte_length = 0
    state = initial_state()
    terminal_replay_valid = True
    if len(rows) != TOTAL_TRACE_STEPS:
        failures.append("R23D9_TRACE_ROW_COUNT")
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            failures.append(f"R23D9_TRACE_ROW_TYPE:{index}")
            terminal_replay_valid = False
            continue
        try:
            raw = _canonical_row(row)
        except (TypeError, ValueError):
            failures.append(f"R23D9_TRACE_ROW_CANONICAL:{index}")
            terminal_replay_valid = False
            continue
        hasher.update(raw)
        byte_length += len(raw)
        if not _exact_keys(row, TRACE_ROW_FIELDS):
            failures.append(f"R23D9_TRACE_ROW_FIELDS:{index}")
            terminal_replay_valid = False
            continue
        if (
            row.get("schema_version") != TRACE_ROW_SCHEMA
            or row.get("cell_id") != cell.cell_id
            or type(row.get("trace_step")) is not int
            or row.get("trace_step") != index
        ):
            failures.append(f"R23D9_TRACE_ROW_IDENTITY:{index}")
        contacts = row.get("ordered_foot_contacts")
        observation_valid = (
            _finite(row.get("measured_yaw_rad"))
            and _finite(row.get("torso_height_m"))
            and _finite(row.get("torso_tilt_rad"))
            and type(row.get("torso_ground_contact")) is bool
            and isinstance(contacts, dict)
            and list(contacts) == list(LIMB_IDS)
            and all(type(value) is bool for value in contacts.values())
        )
        if not observation_valid:
            failures.append(f"R23D9_TRACE_OBSERVATION:{index}")

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
                failures.append(f"R23D9_TRACE_CONTROLLER_PHASE:{index}")
            else:
                phase_counts[expected_phase] += 1
            if (
                row.get("actuator_command_count") != ACTUATOR_COUNT
                or row.get("native_actuation_application_count") != ACTUATOR_COUNT
                or row.get("zero_actuation") is not False
                or row.get("command_composition_mode")
                != "balanced_wave_turning_v1"
                or row.get("handoff_receipt_present") is not False
                or row.get("pre_step_support_counter") is not None
                or row.get("post_step_support_counter") is not None
                or row.get("transition_after_step") is not False
                or row.get("next_terminal_mode") is not None
                or row.get("handoff_reason") is not None
                or row.get("maximum_absolute_joint_position_error_rad") is not None
                or row.get("maximum_absolute_commanded_joint_velocity_rad_s")
                is not None
            ):
                failures.append(f"R23D9_TRACE_CONTROLLER_ACTUATION:{index}")
            continue

        terminal_step = index - CONTROLLER_STEPS
        if not observation_valid or not terminal_replay_valid:
            terminal_replay_valid = False
            continue
        if type(row.get("native_actuation_application_count")) is not int:
            failures.append(f"R23D9_TRACE_TERMINAL_APPLICATION_TYPE:{terminal_step}")
            terminal_replay_valid = False
            continue
        try:
            directive = plan_step(state)
            ordered_contacts = tuple(contacts[limb] for limb in LIMB_IDS)
            next_state, expected_receipt = observe_completed_step(
                state,
                directive,
                ordered_contacts,
                row.get("native_actuation_application_count"),
            )
        except (KeyError, R23D9Error, TypeError, ValueError) as error:
            failures.append(
                f"R23D9_TRACE_TERMINAL_REPLAY:{terminal_step}:{type(error).__name__}"
            )
            terminal_replay_valid = False
            continue
        expected_phase = (
            "terminal_neutral_acquisition"
            if directive.mode == ACTIVE_MODE
            else "terminal_irreversible_zero_actuation"
        )
        expected_mode = (
            ACTIVE_POLICY_ID
            if directive.mode == ACTIVE_MODE
            else "passive_zero_actuation_v1"
        )
        active = directive.mode == ACTIVE_MODE
        receipt_projection = {
            "pre_step_support_counter": row.get("pre_step_support_counter"),
            "post_step_support_counter": row.get("post_step_support_counter"),
            "transition_after_step": row.get("transition_after_step"),
            "next_mode": row.get("next_terminal_mode"),
            "handoff_reason": row.get("handoff_reason"),
            "native_application_count": row.get(
                "native_actuation_application_count"
            ),
        }
        expected_projection = {
            key: expected_receipt[key] for key in receipt_projection
        }
        if (
            row.get("phase_id") != expected_phase
            or row.get("controller_semantic_step") is not None
            or row.get("desired_heading_offset_rad") != 0.0
            or row.get("actuator_command_count")
            != directive.expected_native_application_count
            or row.get("zero_actuation") is active
            or row.get("command_composition_mode") != expected_mode
            or row.get("handoff_receipt_present") is not True
            or receipt_projection != expected_projection
        ):
            failures.append(f"R23D9_TRACE_TERMINAL_SEMANTICS:{terminal_step}")
        if active:
            if (
                not _finite(row.get("maximum_absolute_joint_position_error_rad"))
                or float(row["maximum_absolute_joint_position_error_rad"]) < 0.0
                or not _finite(
                    row.get("maximum_absolute_commanded_joint_velocity_rad_s")
                )
                or float(row["maximum_absolute_commanded_joint_velocity_rad_s"])
                > 0.35 + 1.0e-12
            ):
                failures.append(f"R23D9_TRACE_ACTIVE_NEUTRAL:{terminal_step}")
        elif (
            row.get("maximum_absolute_joint_position_error_rad") is not None
            or row.get("maximum_absolute_commanded_joint_velocity_rad_s") is not None
        ):
            failures.append(f"R23D9_TRACE_PASSIVE_NEUTRAL_ABSENT:{terminal_step}")
        phase_counts[expected_phase] += 1
        state = next_state

    expected_controller = expected_controller_phase_counts()
    if any(phase_counts[phase] != count for phase, count in expected_controller.items()):
        failures.append("R23D9_TRACE_CONTROLLER_PHASE_COUNTS")
    if (
        phase_counts["terminal_neutral_acquisition"]
        + phase_counts["terminal_irreversible_zero_actuation"]
        != TERMINAL_STEPS
    ):
        failures.append("R23D9_TRACE_TERMINAL_PHASE_COUNTS")
    replay_outcome: dict[str, Any] | None = None
    if terminal_replay_valid and state.next_step == TERMINAL_STEPS:
        replay_outcome = outcome(state)
    else:
        failures.append("R23D9_TRACE_TERMINAL_OUTCOME_UNAVAILABLE")
    return {
        "ok": not failures,
        "failure_codes": failures,
        "row_count": len(rows),
        "raw_sha256": "sha256:" + hasher.hexdigest(),
        "byte_length": byte_length,
        "hash_projection": "sha256_canonical_sorted_key_ndjson_rows_v1",
        "phase_counts": phase_counts,
        "handoff_outcome": replay_outcome,
    }


def _rows(*segments: tuple[int, Sequence[bool]]) -> list[tuple[bool, ...]]:
    rows: list[tuple[bool, ...]] = []
    for count, contacts in segments:
        rows.extend([_contacts(contacts)] * count)
    if len(rows) != TERMINAL_STEPS:
        raise R23D9Error("R23D9_CANARY_HORIZON_INVALID")
    return rows


def _load_contracts() -> tuple[dict[str, Any], dict[str, Any]]:
    declaration = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    closure = json.loads(PREDECESSOR_CLOSURE_PATH.read_text(encoding="utf-8"))
    lineage = declaration.get("lineage", {})
    sources = declaration.get("pinned_predecessor_acquisition_sources", {})
    schedule = declaration.get("frozen_schedule_and_gate_snapshot", {})
    machine = declaration.get("handoff_state_machine_contract", {})
    authorization = declaration.get("authorization", {})
    claims = declaration.get("claim_boundary", {})
    invalid = (
        declaration.get("schema_version") != SCHEMA_VERSION
        or declaration.get("campaign_id") != CAMPAIGN_ID
        or declaration.get("gate_id") != GATE_ID
        or lineage.get("predecessor_status") != closure.get("status")
        or lineage.get("predecessor_closure_raw_sha256")
        != _raw_sha256(PREDECESSOR_CLOSURE_PATH)
        or lineage.get("predecessor_same_identity_rerun_allowed") is not False
        or lineage.get("predecessor_scientific_negative") is not True
        or lineage.get("predecessor_passive_all_four_contact_settle_pass_count") != 2
        or sources.get("scientific_contract_raw_sha256")
        != _raw_sha256(PREDECESSOR_CONTRACT_PATH)
        or sources.get("neutral_oracle_raw_sha256")
        != _raw_sha256(PREDECESSOR_NEUTRAL_ORACLE_PATH)
        or sources.get("neutral_command_equation_reused_without_change") is not True
        or schedule.get("physics_hz") != PHYSICS_HZ
        or schedule.get("turning_controller_semantic_step_count") != CONTROLLER_STEPS
        or schedule.get("terminal_support_handoff_step_count") != TERMINAL_STEPS
        or schedule.get("maximum_active_neutral_acquisition_steps")
        != MAXIMUM_ACTIVE_STEPS
        or schedule.get("support_confirmation_step_count")
        != SUPPORT_CONFIRMATION_STEPS
        or schedule.get("minimum_post_handoff_zero_actuation_steps")
        != MINIMUM_PASSIVE_STEPS
        or schedule.get("total_traced_step_count") != TOTAL_TRACE_STEPS
        or schedule.get("minimum_total_active_native_application_count")
        != MINIMUM_TOTAL_ACTIVE_APPLICATIONS
        or schedule.get("maximum_total_active_native_application_count")
        != MAXIMUM_TOTAL_ACTIVE_APPLICATIONS
        or schedule.get("exact_post_handoff_native_application_count") != 0
        or machine.get("initial_mode") != ACTIVE_MODE
        or machine.get("passive_mode") != PASSIVE_MODE
        or machine.get("support_confirmation_requires_consecutive_completed_steps")
        != SUPPORT_CONFIRMATION_STEPS
        or machine.get("latest_first_passive_step_zero_based")
        != MAXIMUM_ACTIVE_STEPS
        or machine.get("mode_reactivation_permitted") is not False
        or machine.get("all_780_steps_execute") is not True
        or authorization.get("physical_execution_authorized") is not False
        or authorization.get("worker_implementation_authorized") is not True
        or claims.get("stage_zero_design_complete") is not True
        or claims.get("command_conditioned_turning") is not False
        or claims.get("physical_acceptance_authority") is not False
    )
    if invalid:
        raise R23D9Error("R23D9_CONTRACT_IDENTITY_INVALID")
    return declaration, closure


def _oracle_canaries() -> dict[str, dict[str, Any]]:
    down = (False, False, False, False)
    partial = (True, True, True, False)
    supported = (True, True, True, True)
    sequences = {
        "support_from_first_step": _rows((TERMINAL_STEPS, supported)),
        "predecessor_shaped_transients": _rows(
            (100, down),
            (23, supported),
            (1, partial),
            (16, supported),
            (1, partial),
            (159, down),
            (480, supported),
        ),
        "confirmation_at_deadline": _rows((390, down), (390, supported)),
        "never_confirmed": _rows((TERMINAL_STEPS, down)),
        "post_handoff_contact_loss": _rows(
            (30, supported), (10, supported), (1, partial), (739, supported)
        ),
    }
    expected = {
        "support_from_first_step": (29, 30, True, 750, 0),
        "predecessor_shaped_transients": (329, 330, True, 450, 0),
        "confirmation_at_deadline": (419, 420, True, 360, 0),
        "never_confirmed": (419, 420, False, 360, 360),
        "post_handoff_contact_loss": (29, 30, False, 750, 1),
    }
    results: dict[str, dict[str, Any]] = {}
    for canary_id, sequence in sequences.items():
        receipts, observed = simulate(sequence)
        after_step, first_passive, passed, passive_steps, loss_count = expected[
            canary_id
        ]
        if (
            observed["handoff_after_active_step"] != after_step
            or observed["first_passive_step"] != first_passive
            or observed["irreversible_handoff_gate_passed"] is not passed
            or observed["passive_step_count"] != passive_steps
            or observed["post_handoff_contact_loss_step_count"] != loss_count
            or validation_failures(sequence, receipts, observed)
        ):
            raise R23D9Error(f"R23D9_ORACLE_CANARY_FAILED:{canary_id}")
        results[canary_id] = observed
    return results


def _mutation_control_failures() -> dict[str, list[str]]:
    down = (False, False, False, False)
    partial = (True, True, True, False)
    supported = (True, True, True, True)
    sequence = _rows(
        (100, down),
        (23, supported),
        (1, partial),
        (16, supported),
        (1, partial),
        (159, down),
        (480, supported),
    )
    receipts, observed = simulate(sequence)
    mutations: dict[str, tuple[list[dict[str, Any]], dict[str, Any]]] = {}

    def mutate_receipt(name: str, index: int, key: str, value: Any) -> None:
        changed = copy.deepcopy(receipts)
        changed[index][key] = value
        mutations[name] = (changed, copy.deepcopy(observed))

    mutate_receipt("transitioned_after_one_contact_step", 100, "transition_after_step", True)
    mutate_receipt(
        "transitioned_after_twenty_nine_contact_steps",
        328,
        "transition_after_step",
        True,
    )
    mutate_receipt(
        "did_not_reset_counter_on_contact_loss",
        123,
        "post_step_support_counter",
        23,
    )
    changed_partial = copy.deepcopy(receipts)
    changed_partial[123]["ordered_contacts"]["rear_right"] = True
    changed_partial[123]["all_four_contacts"] = True
    mutations["counted_partial_contact_as_all_four"] = (
        changed_partial,
        copy.deepcopy(observed),
    )
    mutate_receipt(
        "applied_transition_to_confirming_step_instead_of_next_step",
        329,
        "mode",
        PASSIVE_MODE,
    )
    mutate_receipt(
        "reactivated_after_post_handoff_contact_loss",
        400,
        "mode",
        ACTIVE_MODE,
    )
    mutate_receipt(
        "applied_native_actuation_after_handoff",
        400,
        "native_application_count",
        ACTUATOR_COUNT,
    )
    early = copy.deepcopy(observed)
    early["handoff_after_active_step"] = 418
    early["first_passive_step"] = 419
    mutations["forced_deadline_before_420_active_steps"] = (copy.deepcopy(receipts), early)
    mutate_receipt("allowed_active_step_after_deadline", 420, "mode", ACTIVE_MODE)
    forced_pass = copy.deepcopy(observed)
    forced_pass["handoff_reason"] = DEADLINE_FORCED_REASON
    forced_pass["support_confirmed"] = False
    forced_pass["irreversible_handoff_gate_passed"] = True
    mutations["allowed_deadline_forced_handoff_to_pass"] = (
        copy.deepcopy(receipts),
        forced_pass,
    )
    mutations["stopped_outcome_execution_early"] = (
        copy.deepcopy(receipts[:-1]),
        copy.deepcopy(observed),
    )
    changed_horizon = copy.deepcopy(observed)
    changed_horizon["terminal_step_count"] = TERMINAL_STEPS - 1
    mutations["changed_total_terminal_horizon"] = (
        copy.deepcopy(receipts),
        changed_horizon,
    )

    results: dict[str, list[str]] = {}
    for name, (changed_receipts, changed_outcome) in mutations.items():
        failures = validation_failures(sequence, changed_receipts, changed_outcome)
        if not failures:
            raise R23D9Error(f"R23D9_MUTATION_NOT_REJECTED:{name}")
        results[name] = failures
    return results


def run_zero_world_preflight() -> dict[str, Any]:
    declaration, closure = _load_contracts()
    canaries = _oracle_canaries()
    mutations = _mutation_control_failures()
    neutral_canary = bounded_neutral_velocity(0.05, 0.0)
    if neutral_canary["bounded_velocity_rad_s"] != -0.35:
        raise R23D9Error("R23D9_INHERITED_NEUTRAL_ORACLE_CHANGED")
    declared_canaries = declaration.get("required_oracle_canaries", [])
    declared_mutations = declaration.get("required_mutation_controls", [])
    if declared_canaries != list(canaries) or declared_mutations != list(mutations):
        raise R23D9Error("R23D9_DECLARED_CONTROL_COUNT_CHANGED")
    return {
        "schema_version": "sporespore_qsdk_r23d9_support_handoff_zero_world_preflight_v1",
        "ok": True,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "policy_id": POLICY_ID,
        "active_acquisition_policy_id": ACTIVE_POLICY_ID,
        "predecessor_status": closure["status"],
        "predecessor_result_classification": closure["immutable_completion_record"][
            "result_classification"
        ],
        "terminal_step_count": TERMINAL_STEPS,
        "maximum_active_step_count": MAXIMUM_ACTIVE_STEPS,
        "minimum_passive_step_count": MINIMUM_PASSIVE_STEPS,
        "support_confirmation_step_count": SUPPORT_CONFIRMATION_STEPS,
        "oracle_canary_count": len(canaries),
        "mutation_control_count": len(mutations),
        "oracle_canary_outcomes": canaries,
        "mutation_failure_codes": mutations,
        "physics_adapter_start_count": 0,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


def main() -> int:
    try:
        report = run_zero_world_preflight()
    except (OSError, UnicodeError, json.JSONDecodeError, R23D9Error) as error:
        print(
            json.dumps(
                {
                    "schema_version": "sporespore_qsdk_r23d9_support_handoff_zero_world_preflight_v1",
                    "ok": False,
                    "error": str(error),
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "physical_acceptance_authority": False,
                },
                sort_keys=True,
            )
        )
        return 1
    print(json.dumps(report, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
