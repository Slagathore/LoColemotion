"""Pure MuJoCo implicit-step work measurement for direct velocity servos.

This module does not import MuJoCo or inspect mechanical-energy change.  It
reconstructs the actuator term used by ``implicit``/``implicitfast`` from the
reported pre-step force, the source-defined velocity derivative, and the
observed velocity increment.  The resulting force is paired with midpoint
velocity to measure discrete work for the velocity update.
"""

from __future__ import annotations

from collections import OrderedDict
from dataclasses import dataclass
import inspect
import math
from typing import Any, Sequence


PROFILE_ID = "mujoco_direct_velocity_servo_implicit_step_work_v3"
BINARY64_ULP_BUDGET = 8


class ImplicitStepEnergyError(ValueError):
    """Raised when the exact supported measurement envelope is not satisfied."""


@dataclass(frozen=True)
class ImplicitStepEnergyWorkV3:
    """Independent v2 and v3 work terms for one native velocity update."""

    reported_pre_actuator_force_nm: tuple[float, ...]
    effective_implicit_actuator_force_nm: tuple[float, ...]
    force_limited_at_pre_step: tuple[bool, ...]
    left_endpoint_actuator_work_j: float
    left_endpoint_generalized_actuator_work_j: float
    effective_centered_actuator_work_j: float
    effective_centered_generalized_actuator_work_j: float
    left_endpoint_constraint_work_j: float
    centered_constraint_work_j: float
    centered_damper_work_j: float
    centered_fluid_work_j: float
    centered_adhesion_work_j: float
    centered_dissipated_energy_j: float


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise ImplicitStepEnergyError(code)


def _vector(value: Sequence[float], code: str) -> tuple[float, ...]:
    try:
        result = tuple(float(item) for item in value)
    except (TypeError, ValueError) as error:
        raise ImplicitStepEnergyError(code) from error
    _require(bool(result) and all(math.isfinite(item) for item in result), code)
    return result


def _same_length(code: str, *values: Sequence[object]) -> None:
    _require(len({len(value) for value in values}) == 1, code)


def _dot(left: Sequence[float], right: Sequence[float]) -> float:
    return math.fsum(a * b for a, b in zip(left, right, strict=True))


def _close(left: float, right: float) -> bool:
    scale = max(abs(left), abs(right), 1.0)
    return abs(left - right) <= BINARY64_ULP_BUDGET * math.ulp(scale)


def measure_implicit_step_energy_work_v3(
    *,
    timestep_s: float,
    target_actuator_velocity_rad_s: Sequence[float],
    reported_pre_actuator_velocity_rad_s: Sequence[float],
    reported_pre_actuator_force_nm: Sequence[float],
    velocity_gain_nm_s_per_rad: Sequence[float],
    force_range_lower_nm: Sequence[float],
    force_range_upper_nm: Sequence[float],
    actuator_moment: Sequence[Sequence[float]],
    pre_generalized_velocity: Sequence[float],
    post_generalized_velocity: Sequence[float],
    reported_pre_generalized_actuator_force: Sequence[float],
    reported_pre_generalized_constraint_force: Sequence[float],
    reported_pre_generalized_damper_force: Sequence[float],
    reported_pre_generalized_fluid_force: Sequence[float],
    reported_pre_generalized_adhesion_force: Sequence[float],
) -> ImplicitStepEnergyWorkV3:
    """Measure v3 work for the qualified direct velocity-servo subset.

    MuJoCo 3.11 skips an actuator's velocity derivative when its reported
    pre-step force is clamped.  Otherwise a direct velocity servo contributes
    ``-kv`` through its transmission moment.  Therefore the force used by the
    implicit velocity update is ``f_pre + df/dv * (v_post - v_pre)``.  No
    mechanical-energy or balance-residual value is accepted as input.

    The currently qualified recovery model has zero damping, fluid, and
    adhesion force.  Nonzero values are refused until their own implicit
    derivative mappings are specified rather than silently measured as if
    they were explicit forces.
    """

    dt = float(timestep_s)
    _require(math.isfinite(dt) and dt > 0.0, "QSDK_R24D33_TIMESTEP_INVALID")

    target = _vector(target_actuator_velocity_rad_s, "QSDK_R24D33_TARGET_INVALID")
    pre_actuator_velocity = _vector(
        reported_pre_actuator_velocity_rad_s,
        "QSDK_R24D33_PRE_ACTUATOR_VELOCITY_INVALID",
    )
    pre_force = _vector(
        reported_pre_actuator_force_nm,
        "QSDK_R24D33_PRE_ACTUATOR_FORCE_INVALID",
    )
    gain = _vector(velocity_gain_nm_s_per_rad, "QSDK_R24D33_GAIN_INVALID")
    lower = _vector(force_range_lower_nm, "QSDK_R24D33_FORCE_LOWER_INVALID")
    upper = _vector(force_range_upper_nm, "QSDK_R24D33_FORCE_UPPER_INVALID")
    _same_length(
        "QSDK_R24D33_ACTUATOR_SHAPE_MISMATCH",
        target,
        pre_actuator_velocity,
        pre_force,
        gain,
        lower,
        upper,
        actuator_moment,
    )
    _require(all(value > 0.0 for value in gain), "QSDK_R24D33_GAIN_NONPOSITIVE")
    _require(
        all(low < high for low, high in zip(lower, upper, strict=True)),
        "QSDK_R24D33_FORCE_RANGE_INVALID",
    )

    pre_qvel = _vector(pre_generalized_velocity, "QSDK_R24D33_PRE_QVEL_INVALID")
    post_qvel = _vector(post_generalized_velocity, "QSDK_R24D33_POST_QVEL_INVALID")
    _same_length("QSDK_R24D33_QVEL_SHAPE_MISMATCH", pre_qvel, post_qvel)
    nv = len(pre_qvel)
    moment = tuple(
        _vector(row, f"QSDK_R24D33_ACTUATOR_MOMENT_INVALID:{index}")
        for index, row in enumerate(actuator_moment)
    )
    _require(
        all(len(row) == nv for row in moment),
        "QSDK_R24D33_ACTUATOR_MOMENT_SHAPE_MISMATCH",
    )

    pre_qfrc_actuator = _vector(
        reported_pre_generalized_actuator_force,
        "QSDK_R24D33_PRE_QFRC_ACTUATOR_INVALID",
    )
    pre_qfrc_constraint = _vector(
        reported_pre_generalized_constraint_force,
        "QSDK_R24D33_PRE_QFRC_CONSTRAINT_INVALID",
    )
    pre_qfrc_damper = _vector(
        reported_pre_generalized_damper_force,
        "QSDK_R24D33_PRE_QFRC_DAMPER_INVALID",
    )
    pre_qfrc_fluid = _vector(
        reported_pre_generalized_fluid_force,
        "QSDK_R24D33_PRE_QFRC_FLUID_INVALID",
    )
    pre_qfrc_adhesion = _vector(
        reported_pre_generalized_adhesion_force,
        "QSDK_R24D33_PRE_QFRC_ADHESION_INVALID",
    )
    _same_length(
        "QSDK_R24D33_GENERALIZED_FORCE_SHAPE_MISMATCH",
        pre_qvel,
        pre_qfrc_actuator,
        pre_qfrc_constraint,
        pre_qfrc_damper,
        pre_qfrc_fluid,
        pre_qfrc_adhesion,
    )
    _require(
        all(value == 0.0 for value in (*pre_qfrc_damper, *pre_qfrc_fluid, *pre_qfrc_adhesion)),
        "QSDK_R24D33_UNQUALIFIED_IMPLICIT_PASSIVE_FORCE",
    )

    derived_pre_velocity = tuple(_dot(row, pre_qvel) for row in moment)
    _require(
        all(_close(left, right) for left, right in zip(derived_pre_velocity, pre_actuator_velocity, strict=True)),
        "QSDK_R24D33_PRE_ACTUATOR_VELOCITY_CROSSCHECK_FAILED",
    )
    derived_pre_force = tuple(
        min(high, max(low, kv * (command - velocity)))
        for command, velocity, kv, low, high in zip(
            target, pre_actuator_velocity, gain, lower, upper, strict=True
        )
    )
    _require(
        all(_close(left, right) for left, right in zip(derived_pre_force, pre_force, strict=True)),
        "QSDK_R24D33_PRE_ACTUATOR_FORCE_CROSSCHECK_FAILED",
    )

    derived_pre_qfrc = tuple(
        _dot(tuple(row[dof] for row in moment), pre_force) for dof in range(nv)
    )
    _require(
        all(_close(left, right) for left, right in zip(derived_pre_qfrc, pre_qfrc_actuator, strict=True)),
        "QSDK_R24D33_PRE_QFRC_ACTUATOR_CROSSCHECK_FAILED",
    )

    post_actuator_velocity = tuple(_dot(row, post_qvel) for row in moment)
    limited = tuple(
        force <= low or force >= high
        for force, low, high in zip(pre_force, lower, upper, strict=True)
    )
    effective_force = tuple(
        force if is_limited else force - kv * (post_velocity - pre_velocity)
        for force, is_limited, kv, post_velocity, pre_velocity in zip(
            pre_force,
            limited,
            gain,
            post_actuator_velocity,
            pre_actuator_velocity,
            strict=True,
        )
    )
    effective_qfrc = tuple(
        _dot(tuple(row[dof] for row in moment), effective_force)
        for dof in range(nv)
    )
    midpoint_qvel = tuple(
        (before + after) * 0.5
        for before, after in zip(pre_qvel, post_qvel, strict=True)
    )
    midpoint_actuator_velocity = tuple(
        (before + after) * 0.5
        for before, after in zip(
            pre_actuator_velocity, post_actuator_velocity, strict=True
        )
    )

    left_actuator = _dot(pre_force, pre_actuator_velocity) * dt
    left_generalized = _dot(pre_qfrc_actuator, pre_qvel) * dt
    effective_actuator = _dot(effective_force, midpoint_actuator_velocity) * dt
    effective_generalized = _dot(effective_qfrc, midpoint_qvel) * dt
    _require(
        _close(left_actuator, left_generalized),
        "QSDK_R24D33_LEFT_ACTUATOR_WORK_CROSSCHECK_FAILED",
    )
    _require(
        _close(effective_actuator, effective_generalized),
        "QSDK_R24D33_EFFECTIVE_ACTUATOR_WORK_CROSSCHECK_FAILED",
    )

    left_constraint = _dot(pre_qfrc_constraint, pre_qvel) * dt
    centered_constraint = _dot(pre_qfrc_constraint, midpoint_qvel) * dt
    centered_damper = _dot(pre_qfrc_damper, midpoint_qvel) * dt
    centered_fluid = _dot(pre_qfrc_fluid, midpoint_qvel) * dt
    centered_adhesion = _dot(pre_qfrc_adhesion, midpoint_qvel) * dt
    centered_dissipated = -(
        centered_constraint + centered_damper + centered_fluid + centered_adhesion
    )
    values = (
        *effective_force,
        *effective_qfrc,
        left_actuator,
        left_generalized,
        effective_actuator,
        effective_generalized,
        left_constraint,
        centered_constraint,
        centered_dissipated,
    )
    _require(all(math.isfinite(value) for value in values), "QSDK_R24D33_WORK_NONFINITE")

    return ImplicitStepEnergyWorkV3(
        reported_pre_actuator_force_nm=pre_force,
        effective_implicit_actuator_force_nm=effective_force,
        force_limited_at_pre_step=limited,
        left_endpoint_actuator_work_j=left_actuator,
        left_endpoint_generalized_actuator_work_j=left_generalized,
        effective_centered_actuator_work_j=effective_actuator,
        effective_centered_generalized_actuator_work_j=effective_generalized,
        left_endpoint_constraint_work_j=left_constraint,
        centered_constraint_work_j=centered_constraint,
        centered_damper_work_j=centered_damper,
        centered_fluid_work_j=centered_fluid,
        centered_adhesion_work_j=centered_adhesion,
        centered_dissipated_energy_j=centered_dissipated,
    )


def _conformance_measure(**changes: Any) -> ImplicitStepEnergyWorkV3:
    values: dict[str, Any] = {
        "timestep_s": 0.1,
        "target_actuator_velocity_rad_s": [1.0],
        "reported_pre_actuator_velocity_rad_s": [0.0],
        "reported_pre_actuator_force_nm": [10.0],
        "velocity_gain_nm_s_per_rad": [10.0],
        "force_range_lower_nm": [-100.0],
        "force_range_upper_nm": [100.0],
        "actuator_moment": [[1.0]],
        "pre_generalized_velocity": [0.0],
        "post_generalized_velocity": [1.0 / 3.0],
        "reported_pre_generalized_actuator_force": [10.0],
        "reported_pre_generalized_constraint_force": [0.0],
        "reported_pre_generalized_damper_force": [0.0],
        "reported_pre_generalized_fluid_force": [0.0],
        "reported_pre_generalized_adhesion_force": [0.0],
    }
    values.update(changes)
    return measure_implicit_step_energy_work_v3(**values)


def _conformance_rejected(code: str, **changes: Any) -> bool:
    try:
        _conformance_measure(**changes)
    except ImplicitStepEnergyError as error:
        return str(error) == code
    return False


def implicit_step_energy_zero_world_controls_v1(
) -> tuple[OrderedDict[str, bool], dict[str, float | str]]:
    """Run reusable algebra and refusal controls without importing MuJoCo."""

    nominal = _conformance_measure()
    hidden = _conformance_measure(
        target_actuator_velocity_rad_s=[1.0],
        reported_pre_actuator_velocity_rad_s=[1.0],
        reported_pre_actuator_force_nm=[0.0],
        pre_generalized_velocity=[1.0],
        post_generalized_velocity=[17.0 / 15.0],
        reported_pre_generalized_actuator_force=[0.0],
        reported_pre_generalized_constraint_force=[4.0],
    )
    limited = _conformance_measure(
        target_actuator_velocity_rad_s=[100.0],
        reported_pre_actuator_force_nm=[5.0],
        force_range_lower_nm=[-5.0],
        force_range_upper_nm=[5.0],
        post_generalized_velocity=[0.25],
        reported_pre_generalized_actuator_force=[5.0],
    )
    coupled = _conformance_measure(
        target_actuator_velocity_rad_s=[0.5, 0.4],
        reported_pre_actuator_velocity_rad_s=[0.2, -0.2],
        reported_pre_actuator_force_nm=[3.0, 3.0],
        velocity_gain_nm_s_per_rad=[10.0, 5.0],
        force_range_lower_nm=[-100.0, -100.0],
        force_range_upper_nm=[100.0, 100.0],
        actuator_moment=[[1.0, 0.0], [0.0, 2.0]],
        pre_generalized_velocity=[0.2, -0.1],
        post_generalized_velocity=[0.3, 0.0],
        reported_pre_generalized_actuator_force=[3.0, 6.0],
        reported_pre_generalized_constraint_force=[1.0, -2.0],
        reported_pre_generalized_damper_force=[0.0, 0.0],
        reported_pre_generalized_fluid_force=[0.0, 0.0],
        reported_pre_generalized_adhesion_force=[0.0, 0.0],
    )
    signature = set(inspect.signature(measure_implicit_step_energy_work_v3).parameters)
    controls: OrderedDict[str, bool] = OrderedDict(
        [
            (
                "unsaturated_implicit_servo_effective_work_closes_the_one_dof_velocity_update",
                nominal.force_limited_at_pre_step == (False,)
                and _close(nominal.effective_implicit_actuator_force_nm[0], 20.0 / 3.0)
                and _close(nominal.effective_centered_actuator_work_j, (1.0 / 3.0) ** 2),
            ),
            (
                "zero_reported_pre_force_does_not_hide_effective_implicit_actuator_work",
                hidden.reported_pre_actuator_force_nm == (0.0,)
                and _close(hidden.effective_implicit_actuator_force_nm[0], -4.0 / 3.0)
                and hidden.effective_centered_actuator_work_j != 0.0,
            ),
            (
                "matched_zero_style_actuator_and_constraint_work_close_the_forced_velocity_update",
                _close(
                    hidden.effective_centered_actuator_work_j
                    + hidden.centered_constraint_work_j,
                    (17.0 / 15.0) ** 2 - 1.0,
                ),
            ),
            (
                "force_limited_servo_skips_the_velocity_derivative_exactly_as_mujoco_3_11",
                limited.force_limited_at_pre_step == (True,)
                and limited.effective_implicit_actuator_force_nm == (5.0,)
                and _close(limited.effective_centered_actuator_work_j, 0.0625),
            ),
            (
                "actuator_space_and_generalized_space_effective_work_agree_through_the_moment_matrix",
                _close(coupled.effective_centered_actuator_work_j, 0.03)
                and _close(
                    coupled.effective_centered_actuator_work_j,
                    coupled.effective_centered_generalized_actuator_work_j,
                ),
            ),
            (
                "constraint_work_uses_pre_and_post_generalized_velocity_while_retaining_the_v2_term",
                _close(coupled.left_endpoint_constraint_work_j, 0.04)
                and _close(coupled.centered_constraint_work_j, 0.035)
                and coupled.left_endpoint_constraint_work_j != coupled.centered_constraint_work_j,
            ),
            (
                "reported_pre_force_and_generalized_force_mutations_fail_closed",
                _conformance_rejected(
                    "QSDK_R24D33_PRE_ACTUATOR_FORCE_CROSSCHECK_FAILED",
                    reported_pre_actuator_force_nm=[9.0],
                )
                and _conformance_rejected(
                    "QSDK_R24D33_PRE_QFRC_ACTUATOR_CROSSCHECK_FAILED",
                    reported_pre_generalized_actuator_force=[9.0],
                ),
            ),
            (
                "shape_nonfinite_and_unqualified_passive_force_mutations_fail_closed",
                _conformance_rejected(
                    "QSDK_R24D33_QVEL_SHAPE_MISMATCH",
                    post_generalized_velocity=[0.0, 1.0],
                )
                and _conformance_rejected(
                    "QSDK_R24D33_PRE_QVEL_INVALID",
                    pre_generalized_velocity=[math.nan],
                )
                and _conformance_rejected(
                    "QSDK_R24D33_UNQUALIFIED_IMPLICIT_PASSIVE_FORCE",
                    reported_pre_generalized_damper_force=[-1.0],
                ),
            ),
            (
                "measurement_has_no_mechanical_energy_residual_or_acceptance_input",
                not {
                    "initial_mechanical_energy_j",
                    "current_mechanical_energy_j",
                    "balance_residual_j",
                    "maximum_energy_balance_residual_j",
                    "acceptance_threshold_j",
                }.intersection(signature),
            ),
            (
                "the_v2_terms_remain_side_by_side_with_the_v3_terms",
                nominal.left_endpoint_actuator_work_j == 0.0
                and nominal.effective_centered_actuator_work_j > 0.0,
            ),
        ]
    )
    return controls, {
        "profile_id": PROFILE_ID,
        "nominal_effective_work_j": nominal.effective_centered_actuator_work_j,
        "hidden_zero_pre_force_effective_work_j": hidden.effective_centered_actuator_work_j,
        "hidden_zero_pre_force_constraint_work_j": hidden.centered_constraint_work_j,
    }
