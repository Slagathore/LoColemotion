"""Pure retained-trace diagnostics for native energy-work ledgers.

These helpers never construct a model, advance a world, select a threshold, or
turn a descriptive projection into acceptance authority.  They exist to make
outcome-exposed diagnosis reproducible before a distinct prospective design is
declared.
"""

from __future__ import annotations

from collections import OrderedDict
import math
import struct
from typing import Any, Mapping, Sequence


class RetainedEnergyTraceError(RuntimeError):
    """Stable fail-closed retained-energy diagnostic error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise RetainedEnergyTraceError(code)


def _finite(value: Any, code: str) -> float:
    _require(
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value)),
        code,
    )
    return float(value)


def _binary64_le(value: Any, code: str) -> float:
    _require(isinstance(value, str) and len(value) == 16, code)
    try:
        decoded = struct.unpack("<d", bytes.fromhex(value))[0]
    except (ValueError, struct.error) as error:
        raise RetainedEnergyTraceError(code) from error
    return _finite(decoded, code)


def endpoint_centered_actuator_projection_v1(
    arm: Mapping[str, Any],
) -> dict[str, Any]:
    """Project outer-step actuator work from retained impulses and velocities.

    This is deliberately descriptive.  An outer-step impulse multiplied by the
    mean of its retained endpoint velocities is not a substitute for a future
    per-native-substep discrete-work measurement.  It can, however, expose
    whether the frozen left-endpoint ledger has a material staging sensitivity.
    """

    observations = arm["observations"]
    native_receipts = arm["native_receipts"]
    portable_receipts = arm["portable_step_receipts"]
    _require(
        isinstance(observations, Sequence)
        and len(observations) > 0
        and len(observations) == len(native_receipts) == len(portable_receipts),
        "RETAINED_ENERGY_ARM_COUNT",
    )
    first_joints = observations[0]["state"]["ordered_joint_observations"]
    joint_ids = [str(value["joint_id"]) for value in first_joints]
    _require(len(joint_ids) > 0 and len(set(joint_ids)) == len(joint_ids), "RETAINED_ENERGY_JOINTS")
    qvel_hex = arm["canonical_pre_step_state"]["qvel_binary64_le_hex"]
    _require(len(qvel_hex) >= len(joint_ids), "RETAINED_ENERGY_INITIAL_QVEL")
    before_velocity = [
        _binary64_le(value, "RETAINED_ENERGY_INITIAL_QVEL_VALUE")
        for value in qvel_hex[-len(joint_ids) :]
    ]

    initial_energy = _finite(
        observations[0]["energy_balance"]["initial_mechanical_energy_j"],
        "RETAINED_ENERGY_INITIAL_MECHANICAL",
    )
    centered_cumulative = 0.0
    recorded_cumulative = 0.0
    rows: list[dict[str, Any]] = []
    phase_contributions: OrderedDict[str, dict[str, Any]] = OrderedDict()
    for index, (observation, native_receipt, portable) in enumerate(
        zip(observations, native_receipts, portable_receipts, strict=True)
    ):
        joints = observation["state"]["ordered_joint_observations"]
        _require(
            [str(value["joint_id"]) for value in joints] == joint_ids,
            f"RETAINED_ENERGY_JOINT_ORDER:{index}",
        )
        after_velocity = [
            _finite(value["velocity_rad_s"], f"RETAINED_ENERGY_JOINT_VELOCITY:{index}")
            for value in joints
        ]
        application = native_receipt["application"]
        impulses = application["ordered_signed_applied_impulse_nms"]
        _require(len(impulses) == len(joint_ids), f"RETAINED_ENERGY_IMPULSE_COUNT:{index}")
        centered_step = sum(
            _finite(impulse, f"RETAINED_ENERGY_IMPULSE:{index}")
            * (before + after)
            / 2.0
            for impulse, before, after in zip(
                impulses,
                before_velocity,
                after_velocity,
                strict=True,
            )
        )
        recorded_step = _finite(
            application["step_actuator_work_j"],
            f"RETAINED_ENERGY_RECORDED_WORK:{index}",
        )
        centered_cumulative += centered_step
        recorded_cumulative += recorded_step
        energy = observation["energy_balance"]
        current_energy = _finite(
            energy["current_mechanical_energy_j"],
            f"RETAINED_ENERGY_CURRENT_MECHANICAL:{index}",
        )
        native_recorded_cumulative = _finite(
            native_receipt["native_step"]["cumulative_actuator_work_j"],
            f"RETAINED_ENERGY_NATIVE_ACTUATOR:{index}",
        )
        portable_recorded_cumulative = _finite(
            energy["cumulative_applied_actuator_work_j"],
            f"RETAINED_ENERGY_PORTABLE_ACTUATOR:{index}",
        )
        _require(
            recorded_cumulative == native_recorded_cumulative == portable_recorded_cumulative,
            f"RETAINED_ENERGY_ACTUATOR_IDENTITY:{index}",
        )
        external_cumulative = _finite(
            energy["cumulative_external_work_j"],
            f"RETAINED_ENERGY_EXTERNAL:{index}",
        )
        dissipated_cumulative = _finite(
            energy["cumulative_dissipated_energy_j"],
            f"RETAINED_ENERGY_DISSIPATED:{index}",
        )
        original_signed_residual = (
            current_energy
            - initial_energy
            - recorded_cumulative
            - external_cumulative
            + dissipated_cumulative
        )
        projected_signed_residual = (
            current_energy
            - initial_energy
            - centered_cumulative
            - external_cumulative
            + dissipated_cumulative
        )
        phase = str(portable["prior_phase"])
        contribution = phase_contributions.setdefault(
            phase,
            {
                "outer_step_count": 0,
                "recorded_actuator_work_j": 0.0,
                "endpoint_centered_actuator_work_j": 0.0,
            },
        )
        contribution["outer_step_count"] += 1
        contribution["recorded_actuator_work_j"] += recorded_step
        contribution["endpoint_centered_actuator_work_j"] += centered_step
        rows.append(
            {
                "outer_index_zero_based": index,
                "raised_body_gate": portable["classification"]["raised_body_gate"] is True,
                "original_signed_residual_j": original_signed_residual,
                "projected_signed_residual_j": projected_signed_residual,
            }
        )
        before_velocity = after_velocity

    raised = [row for row in rows if row["raised_body_gate"]]
    return {
        "outer_step_count": len(rows),
        "joint_count": len(joint_ids),
        "joint_ids": joint_ids,
        "recorded_cumulative_actuator_work_j": recorded_cumulative,
        "endpoint_centered_cumulative_actuator_work_j": centered_cumulative,
        "additional_projected_actuator_work_j": centered_cumulative - recorded_cumulative,
        "terminal_original_signed_residual_j": rows[-1]["original_signed_residual_j"],
        "terminal_projected_signed_residual_j": rows[-1]["projected_signed_residual_j"],
        "raised_body_observation_count": len(raised),
        "minimum_raised_original_absolute_residual_j": (
            min(abs(row["original_signed_residual_j"]) for row in raised) if raised else None
        ),
        "minimum_raised_projected_absolute_residual_j": (
            min(abs(row["projected_signed_residual_j"]) for row in raised) if raised else None
        ),
        "minimum_raised_projected_outer_index_zero_based": (
            min(raised, key=lambda row: abs(row["projected_signed_residual_j"]))[
                "outer_index_zero_based"
            ]
            if raised
            else None
        ),
        "phase_contributions": phase_contributions,
    }


def _rapier_residual_rows_v1(
    arm: Mapping[str, Any],
) -> tuple[list[dict[str, Any]], OrderedDict[str, dict[str, Any]]]:
    """Rebuild the Rapier V2 residual from independently retained components."""

    observations = arm["trace"]["observations"]
    samples = arm["energy_samples"]
    portable = arm["portable_step_receipts"]
    _require(
        isinstance(observations, Sequence)
        and len(observations) > 0
        and len(observations) == len(samples) == len(portable),
        "RAPIER_RETAINED_ENERGY_ARM_COUNT",
    )

    cumulative_motor = 0.0
    cumulative_external = 0.0
    cumulative_constraint = 0.0
    cumulative_passive = 0.0
    previous_mechanical: float | None = None
    previous_residual = 0.0
    rows: list[dict[str, Any]] = []
    phase_contributions: OrderedDict[str, dict[str, Any]] = OrderedDict()
    for index, (observation, sample, receipt) in enumerate(
        zip(observations, samples, portable, strict=True)
    ):
        _require(
            sample["sequence"] == index + 1
            and sample["source_measurement"] is True
            and sample["residual_derived_work_used"] is False
            and sample["integration_and_numerical_exchange_role"]
            == "independent_v2_energy_balance_residual",
            f"RAPIER_RETAINED_ENERGY_SAMPLE_IDENTITY:{index}",
        )
        energy = observation["energy_balance"]
        _require(
            energy["source_measurement"] is True
            and energy["equation_id"]
            == "current_minus_initial_minus_actuator_minus_external_minus_constraint_plus_passive_v2",
            f"RAPIER_RETAINED_ENERGY_LEDGER_IDENTITY:{index}",
        )
        motor = _finite(sample["motor_net_work_j"], f"RAPIER_RETAINED_ENERGY_MOTOR:{index}")
        external = _finite(
            sample["signed_external_work_j"],
            f"RAPIER_RETAINED_ENERGY_EXTERNAL:{index}",
        )
        constraint = _finite(
            sample["signed_constraint_exchange_j"],
            f"RAPIER_RETAINED_ENERGY_CONSTRAINT:{index}",
        )
        passive = _finite(
            sample["passive_dissipation_j"],
            f"RAPIER_RETAINED_ENERGY_PASSIVE:{index}",
        )
        cumulative_motor += motor
        cumulative_external += external
        cumulative_constraint += constraint
        cumulative_passive += passive
        _require(
            cumulative_motor == energy["cumulative_applied_actuator_work_j"]
            and cumulative_external == energy["cumulative_signed_external_work_j"]
            and cumulative_constraint == energy["cumulative_signed_constraint_exchange_j"]
            and cumulative_passive == energy["cumulative_passive_dissipation_j"],
            f"RAPIER_RETAINED_ENERGY_CUMULATIVE_IDENTITY:{index}",
        )

        initial = _finite(
            energy["initial_mechanical_energy_j"],
            f"RAPIER_RETAINED_ENERGY_INITIAL_MECHANICAL:{index}",
        )
        current = _finite(
            energy["current_mechanical_energy_j"],
            f"RAPIER_RETAINED_ENERGY_CURRENT_MECHANICAL:{index}",
        )
        mechanical_delta = current - (initial if previous_mechanical is None else previous_mechanical)
        residual = (
            current
            - initial
            - cumulative_motor
            - cumulative_external
            - cumulative_constraint
            + cumulative_passive
        )
        residual_delta = residual - previous_residual
        phase = str(receipt["prior_phase"])
        contribution = phase_contributions.setdefault(
            phase,
            {
                "outer_step_count": 0,
                "mechanical_energy_change_j": 0.0,
                "motor_net_work_j": 0.0,
                "signed_external_work_j": 0.0,
                "signed_constraint_exchange_j": 0.0,
                "passive_dissipation_j": 0.0,
                "signed_residual_change_j": 0.0,
            },
        )
        contribution["outer_step_count"] += 1
        contribution["mechanical_energy_change_j"] += mechanical_delta
        contribution["motor_net_work_j"] += motor
        contribution["signed_external_work_j"] += external
        contribution["signed_constraint_exchange_j"] += constraint
        contribution["passive_dissipation_j"] += passive
        contribution["signed_residual_change_j"] += residual_delta
        velocity = observation["center_of_mass"]["linear_velocity_world_m_s"]
        com_speed = math.sqrt(
            sum(
                _finite(velocity[axis], f"RAPIER_RETAINED_ENERGY_COM_VELOCITY:{index}:{axis}")
                ** 2
                for axis in ("x", "y", "z")
            )
        )
        rows.append(
            {
                "outer_index_zero_based": index,
                "phase": phase,
                "mechanical_energy_change_j": mechanical_delta,
                "motor_net_work_j": motor,
                "signed_external_work_j": external,
                "signed_constraint_exchange_j": constraint,
                "passive_dissipation_j": passive,
                "signed_residual_j": residual,
                "signed_residual_change_j": residual_delta,
                "center_of_mass_speed_m_s": com_speed,
            }
        )
        previous_mechanical = current
        previous_residual = residual
    return rows, phase_contributions


def rapier_energy_residual_decomposition_v1(
    arm: Mapping[str, Any],
) -> dict[str, Any]:
    """Summarize a retained Rapier V2 ledger without selecting an outcome."""

    rows, phase_contributions = _rapier_residual_rows_v1(arm)
    maximum = max(rows, key=lambda row: abs(row["signed_residual_j"]))
    return {
        "outer_step_count": len(rows),
        "terminal_signed_residual_j": rows[-1]["signed_residual_j"],
        "maximum_absolute_residual_j": abs(maximum["signed_residual_j"]),
        "maximum_absolute_residual_outer_index_zero_based": maximum["outer_index_zero_based"],
        "phase_contributions": phase_contributions,
    }


def rapier_zero_control_gravity_staging_projection_v1(
    arm: Mapping[str, Any],
    *,
    total_dynamic_mass_kg: Any,
    terminal_window_outer_steps: int,
) -> dict[str, Any]:
    """Project the zero-velocity gravity kick in a retained zero-control arm.

    The projection is descriptive, not a corrected ledger.  It is the kinetic
    energy introduced when gravity accelerates the declared dynamic mass from
    zero velocity during every solver small step.  A supported near-stationary
    tail can expose this discrete staging term because constraints immediately
    remove nearly the same energy while endpoint mechanical energy barely
    changes.  Active or freely falling motion needs a distinct per-substep
    observer and must not use this projection as acceptance authority.
    """

    rows, _ = _rapier_residual_rows_v1(arm)
    observations = arm["trace"]["observations"]
    samples = arm["energy_samples"]
    _require(
        isinstance(terminal_window_outer_steps, int)
        and not isinstance(terminal_window_outer_steps, bool)
        and 0 < terminal_window_outer_steps <= len(rows),
        "RAPIER_GRAVITY_STAGING_WINDOW",
    )
    mass = _finite(total_dynamic_mass_kg, "RAPIER_GRAVITY_STAGING_MASS")
    _require(mass > 0.0, "RAPIER_GRAVITY_STAGING_MASS")

    first_gravity: tuple[float, float, float] | None = None
    first_duration: float | None = None
    first_small_steps: int | None = None
    for index, (observation, sample) in enumerate(zip(observations, samples, strict=True)):
        actuation = observation["applied_actuation"]
        _require(
            actuation["zero_command"] is True
            and all(
                _finite(
                    value["applied_angular_impulse_nms"],
                    f"RAPIER_GRAVITY_STAGING_ZERO_IMPULSE:{index}",
                )
                == 0.0
                for value in actuation["ordered_applied_impulses"]
            )
            and _finite(sample["motor_supplied_work_j"], f"RAPIER_GRAVITY_STAGING_MOTOR:{index}")
            == 0.0
            and _finite(sample["motor_absorbed_work_j"], f"RAPIER_GRAVITY_STAGING_MOTOR:{index}")
            == 0.0
            and _finite(sample["motor_net_work_j"], f"RAPIER_GRAVITY_STAGING_MOTOR:{index}")
            == 0.0
            and _finite(sample["signed_external_work_j"], f"RAPIER_GRAVITY_STAGING_EXTERNAL:{index}")
            == 0.0
            and _finite(sample["passive_dissipation_j"], f"RAPIER_GRAVITY_STAGING_PASSIVE:{index}")
            == 0.0,
            f"RAPIER_GRAVITY_STAGING_ZERO_CONTROL:{index}",
        )
        gravity_value = observation["state"]["gravity_world_m_s2"]
        gravity = tuple(
            _finite(gravity_value[axis], f"RAPIER_GRAVITY_STAGING_GRAVITY:{index}:{axis}")
            for axis in ("x", "y", "z")
        )
        duration = _finite(
            observation["outer_step_duration_s"],
            f"RAPIER_GRAVITY_STAGING_DURATION:{index}",
        )
        small_steps = sample["small_step_count"]
        _require(
            isinstance(small_steps, int) and not isinstance(small_steps, bool) and small_steps > 0,
            f"RAPIER_GRAVITY_STAGING_SMALL_STEPS:{index}",
        )
        if first_gravity is None:
            first_gravity = gravity
            first_duration = duration
            first_small_steps = small_steps
        _require(
            gravity == first_gravity
            and duration == first_duration
            and small_steps == first_small_steps,
            f"RAPIER_GRAVITY_STAGING_ROUTE_DRIFT:{index}",
        )

    assert first_gravity is not None
    assert first_duration is not None
    assert first_small_steps is not None
    gravity_magnitude = math.sqrt(sum(value * value for value in first_gravity))
    zero_velocity_projection = (
        0.5 * mass * (gravity_magnitude * first_duration) ** 2 / first_small_steps
    )
    _require(zero_velocity_projection > 0.0, "RAPIER_GRAVITY_STAGING_PROJECTION")

    window = rows[-terminal_window_outer_steps:]
    removals = [-row["signed_constraint_exchange_j"] for row in window]
    residual_changes = [row["signed_residual_change_j"] for row in window]
    mechanical_changes = [row["mechanical_energy_change_j"] for row in window]
    terminal = rows[-1]
    terminal_removal = -terminal["signed_constraint_exchange_j"]
    return {
        "outer_step_count": len(rows),
        "total_dynamic_mass_kg": mass,
        "gravity_world_m_s2": {
            axis: value for axis, value in zip(("x", "y", "z"), first_gravity, strict=True)
        },
        "gravity_magnitude_m_s2": gravity_magnitude,
        "outer_step_duration_s": first_duration,
        "solver_small_steps_per_outer_step": first_small_steps,
        "zero_velocity_gravity_kick_projection_per_outer_step_j": zero_velocity_projection,
        "terminal": {
            "outer_index_zero_based": terminal["outer_index_zero_based"],
            "measured_signed_constraint_exchange_j": terminal[
                "signed_constraint_exchange_j"
            ],
            "measured_constraint_removal_j": terminal_removal,
            "mechanical_energy_change_j": terminal["mechanical_energy_change_j"],
            "signed_residual_change_j": terminal["signed_residual_change_j"],
            "center_of_mass_speed_m_s": terminal["center_of_mass_speed_m_s"],
            "constraint_removal_fraction_of_projection": terminal_removal
            / zero_velocity_projection,
            "residual_growth_fraction_of_projection": terminal[
                "signed_residual_change_j"
            ]
            / zero_velocity_projection,
        },
        "terminal_contiguous_descriptive_window": {
            "outer_step_count": terminal_window_outer_steps,
            "first_outer_index_zero_based": window[0]["outer_index_zero_based"],
            "last_outer_index_zero_based": window[-1]["outer_index_zero_based"],
            "mean_measured_constraint_removal_j": sum(removals) / len(removals),
            "minimum_constraint_removal_fraction_of_projection": min(removals)
            / zero_velocity_projection,
            "maximum_constraint_removal_fraction_of_projection": max(removals)
            / zero_velocity_projection,
            "mean_constraint_removal_fraction_of_projection": sum(removals)
            / len(removals)
            / zero_velocity_projection,
            "mean_signed_residual_change_j": sum(residual_changes) / len(residual_changes),
            "mean_residual_growth_fraction_of_projection": sum(residual_changes)
            / len(residual_changes)
            / zero_velocity_projection,
            "mean_mechanical_energy_change_j": sum(mechanical_changes)
            / len(mechanical_changes),
            "maximum_absolute_mechanical_energy_change_j": max(
                abs(value) for value in mechanical_changes
            ),
            "maximum_center_of_mass_speed_m_s": max(
                row["center_of_mass_speed_m_s"] for row in window
            ),
        },
    }


_GODOT_PHYSICAL_STATE_FIELDS = (
    "base_pose_world",
    "base_twist_world",
    "gravity_world_m_s2",
    "ordered_contact_observations",
    "ordered_joint_observations",
    "sample_time_s",
    "semantic_step",
    "task_frame",
)
_GODOT_PHYSICAL_OBSERVATION_FIELDS = (
    "center_of_mass",
    "ordered_body_clearance_observations",
    "ordered_foot_bearing_observations",
)
_GODOT_PHYSICAL_CLASSIFICATION_FIELDS = (
    "actuator_budget_respected",
    "all_four_distal_sites_bearing",
    "any_nonfoot_contact",
    "center_of_mass_height_gain_m",
    "distal_support_gate",
    "entry_prone_gate",
    "intervention_counter_total",
    "joint_limits_respected",
    "maximum_nonfoot_contact_impulse_ns",
    "minimum_distal_bearing_impulse_ns",
    "minimum_nonfoot_clearance_m",
    "no_cheat_gate",
    "pose_class",
    "raised_body_gate",
    "terminal_angular_speed_rad_s",
    "terminal_linear_speed_m_s",
    "torso_height_ratio",
    "torso_up_dot",
    "torso_ventral_contact",
)


def _godot_v3_residual_rows_v1(
    arm: Mapping[str, Any],
) -> tuple[list[dict[str, Any]], OrderedDict[str, dict[str, Any]]]:
    """Rebuild a retained Godot/Jolt V3 energy residual by outer step."""

    observations = arm["trace_v3"]["observations"]
    portable = arm["portable_step_receipts"]
    applications = arm["command_application_receipts"]
    _require(
        isinstance(observations, Sequence)
        and len(observations) > 0
        and len(observations) == len(portable) == len(applications),
        "GODOT_V3_RETAINED_ENERGY_ARM_COUNT",
    )

    cumulative_previous = {
        "motor": 0.0,
        "external": 0.0,
        "constraint": 0.0,
        "staging": 0.0,
        "passive": 0.0,
    }
    previous_mechanical: float | None = None
    previous_residual = 0.0
    rows: list[dict[str, Any]] = []
    phase_contributions: OrderedDict[str, dict[str, Any]] = OrderedDict()
    for index, (observation, receipt, application) in enumerate(
        zip(observations, portable, applications, strict=True)
    ):
        semantic_step = index + 1
        _require(
            observation["semantic_step"] == semantic_step
            and application["semantic_step"] == semantic_step,
            f"GODOT_V3_RETAINED_ENERGY_STEP_IDENTITY:{index}",
        )
        energy = observation["energy_balance"]
        _require(
            energy["schema_version"] == "sporespore_recovery_energy_balance_ledger_v3"
            and energy["equation_id"]
            == "current_minus_initial_minus_actuator_minus_external_minus_constraint_minus_discrete_staging_plus_passive_v3"
            and energy["source_measurement"] is True,
            f"GODOT_V3_RETAINED_ENERGY_LEDGER_IDENTITY:{index}",
        )
        initial = _finite(
            energy["initial_mechanical_energy_j"],
            f"GODOT_V3_RETAINED_ENERGY_INITIAL:{index}",
        )
        current = _finite(
            energy["current_mechanical_energy_j"],
            f"GODOT_V3_RETAINED_ENERGY_CURRENT:{index}",
        )
        cumulative = {
            "motor": _finite(
                energy["cumulative_applied_actuator_work_j"],
                f"GODOT_V3_RETAINED_ENERGY_MOTOR:{index}",
            ),
            "external": _finite(
                energy["cumulative_signed_external_work_j"],
                f"GODOT_V3_RETAINED_ENERGY_EXTERNAL:{index}",
            ),
            "constraint": _finite(
                energy["cumulative_signed_constraint_exchange_j"],
                f"GODOT_V3_RETAINED_ENERGY_CONSTRAINT:{index}",
            ),
            "staging": _finite(
                energy["cumulative_signed_discrete_staging_exchange_j"],
                f"GODOT_V3_RETAINED_ENERGY_STAGING:{index}",
            ),
            "passive": _finite(
                energy["cumulative_passive_dissipation_j"],
                f"GODOT_V3_RETAINED_ENERGY_PASSIVE:{index}",
            ),
        }
        increments = {
            key: cumulative[key] - cumulative_previous[key] for key in cumulative
        }
        residual = (
            current
            - initial
            - cumulative["motor"]
            - cumulative["external"]
            - cumulative["constraint"]
            - cumulative["staging"]
            + cumulative["passive"]
        )
        classification = receipt["classification"]
        classified_residual = _finite(
            classification["energy_balance_residual_j"],
            f"GODOT_V3_RETAINED_ENERGY_CLASSIFICATION:{index}",
        )
        reconstruction_tolerance = 8.0 * math.ulp(
            max(abs(residual), abs(classified_residual), 1.0)
        )
        _require(
            abs(abs(residual) - classified_residual) <= reconstruction_tolerance,
            f"GODOT_V3_RETAINED_ENERGY_RESIDUAL_IDENTITY:{index}",
        )
        mechanical_delta = current - (
            initial if previous_mechanical is None else previous_mechanical
        )
        residual_delta = residual - previous_residual
        phase = str(receipt["prior_phase"])
        contribution = phase_contributions.setdefault(
            phase,
            {
                "outer_step_count": 0,
                "mechanical_energy_change_j": 0.0,
                "motor_net_work_j": 0.0,
                "signed_external_work_j": 0.0,
                "signed_constraint_exchange_j": 0.0,
                "signed_discrete_staging_exchange_j": 0.0,
                "passive_dissipation_j": 0.0,
                "signed_residual_change_j": 0.0,
            },
        )
        contribution["outer_step_count"] += 1
        contribution["mechanical_energy_change_j"] += mechanical_delta
        contribution["motor_net_work_j"] += increments["motor"]
        contribution["signed_external_work_j"] += increments["external"]
        contribution["signed_constraint_exchange_j"] += increments["constraint"]
        contribution["signed_discrete_staging_exchange_j"] += increments["staging"]
        contribution["passive_dissipation_j"] += increments["passive"]
        contribution["signed_residual_change_j"] += residual_delta
        velocity = observation["center_of_mass"]["linear_velocity_world_m_s"]
        rows.append(
            {
                "outer_index_zero_based": index,
                "semantic_step": semantic_step,
                "phase": phase,
                "mechanical_energy_change_j": mechanical_delta,
                "motor_net_work_j": increments["motor"],
                "signed_external_work_j": increments["external"],
                "signed_constraint_exchange_j": increments["constraint"],
                "signed_discrete_staging_exchange_j": increments["staging"],
                "passive_dissipation_j": increments["passive"],
                "signed_residual_j": residual,
                "signed_residual_change_j": residual_delta,
                "center_of_mass_speed_m_s": math.sqrt(
                    sum(
                        _finite(
                            velocity[axis],
                            f"GODOT_V3_RETAINED_ENERGY_COM_VELOCITY:{index}:{axis}",
                        )
                        ** 2
                        for axis in ("x", "y", "z")
                    )
                ),
                "classification": classification,
            }
        )
        cumulative_previous = cumulative
        previous_mechanical = current
        previous_residual = residual
    return rows, phase_contributions


def godot_v3_energy_residual_decomposition_v1(
    arm: Mapping[str, Any],
) -> dict[str, Any]:
    """Summarize a retained Godot/Jolt V3 ledger without changing its result."""

    rows, phase_contributions = _godot_v3_residual_rows_v1(arm)
    maximum = max(rows, key=lambda row: abs(row["signed_residual_j"]))
    return {
        "outer_step_count": len(rows),
        "terminal_signed_residual_j": rows[-1]["signed_residual_j"],
        "maximum_absolute_residual_j": abs(maximum["signed_residual_j"]),
        "maximum_absolute_residual_outer_index_zero_based": maximum[
            "outer_index_zero_based"
        ],
        "phase_contributions": phase_contributions,
    }


def godot_v3_zero_control_gravity_staging_projection_v1(
    arm: Mapping[str, Any],
    *,
    total_dynamic_mass_kg: Any,
    terminal_window_outer_steps: int,
) -> dict[str, Any]:
    """Describe the gravity kick exposed by a supported zero-control tail.

    As with the Rapier counterpart, this is not a corrected ledger.  Active and
    freely moving states require a prospective per-step staging observer with
    independent analytic controls before its output can enter an energy gate.
    """

    _require(
        isinstance(terminal_window_outer_steps, int)
        and not isinstance(terminal_window_outer_steps, bool)
        and terminal_window_outer_steps > 0,
        "GODOT_V3_GRAVITY_STAGING_WINDOW",
    )
    mass = _finite(total_dynamic_mass_kg, "GODOT_V3_GRAVITY_STAGING_MASS")
    _require(mass > 0.0, "GODOT_V3_GRAVITY_STAGING_MASS")
    rows, _ = _godot_v3_residual_rows_v1(arm)
    _require(
        terminal_window_outer_steps <= len(rows),
        "GODOT_V3_GRAVITY_STAGING_WINDOW",
    )
    observations = arm["trace_v3"]["observations"]
    applications = arm["command_application_receipts"]

    first_route: tuple[tuple[float, float, float], float, int] | None = None
    for index, (observation, application, row) in enumerate(
        zip(observations, applications, rows, strict=True)
    ):
        energy = observation["energy_balance"]
        _require(
            application["zero_command"] is True
            and application["no_actuation_requested"] is True
            and application["native_joint_motors_disabled"] is True
            and application["motor_enabled_count"] == 0
            and row["motor_net_work_j"] == 0.0
            and row["signed_external_work_j"] == 0.0
            and row["signed_discrete_staging_exchange_j"] == 0.0
            and row["passive_dissipation_j"] == 0.0
            and energy["cumulative_applied_actuator_work_j"] == 0.0
            and energy["cumulative_signed_external_work_j"] == 0.0
            and energy["cumulative_signed_discrete_staging_exchange_j"] == 0.0
            and energy["cumulative_passive_dissipation_j"] == 0.0,
            f"GODOT_V3_GRAVITY_STAGING_ZERO_CONTROL:{index}",
        )
        gravity_value = observation["state"]["gravity_world_m_s2"]
        gravity = tuple(
            _finite(
                gravity_value[axis],
                f"GODOT_V3_GRAVITY_STAGING_GRAVITY:{index}:{axis}",
            )
            for axis in ("x", "y", "z")
        )
        duration = _finite(
            observation["outer_step_duration_s"],
            f"GODOT_V3_GRAVITY_STAGING_DURATION:{index}",
        )
        substeps = observation["engine_step_identity"]["native_solver_substep_count"]
        _require(
            isinstance(substeps, int)
            and not isinstance(substeps, bool)
            and substeps > 0,
            f"GODOT_V3_GRAVITY_STAGING_SUBSTEPS:{index}",
        )
        route = (gravity, duration, substeps)
        if first_route is None:
            first_route = route
        _require(route == first_route, f"GODOT_V3_GRAVITY_STAGING_ROUTE_DRIFT:{index}")

    assert first_route is not None
    gravity, duration, substeps = first_route
    gravity_magnitude = math.sqrt(sum(value * value for value in gravity))
    zero_velocity_projection = (
        0.5 * mass * (gravity_magnitude * duration) ** 2 / substeps
    )
    _require(zero_velocity_projection > 0.0, "GODOT_V3_GRAVITY_STAGING_PROJECTION")
    window = rows[-terminal_window_outer_steps:]
    removals = [-row["signed_constraint_exchange_j"] for row in window]
    residual_changes = [row["signed_residual_change_j"] for row in window]
    mechanical_changes = [row["mechanical_energy_change_j"] for row in window]
    terminal = rows[-1]
    terminal_removal = -terminal["signed_constraint_exchange_j"]
    return {
        "outer_step_count": len(rows),
        "total_dynamic_mass_kg": mass,
        "gravity_world_m_s2": {
            axis: value
            for axis, value in zip(("x", "y", "z"), gravity, strict=True)
        },
        "gravity_magnitude_m_s2": gravity_magnitude,
        "outer_step_duration_s": duration,
        "native_solver_substeps_per_outer_step": substeps,
        "zero_velocity_gravity_kick_projection_per_outer_step_j": zero_velocity_projection,
        "terminal": {
            "outer_index_zero_based": terminal["outer_index_zero_based"],
            "measured_signed_constraint_exchange_j": terminal[
                "signed_constraint_exchange_j"
            ],
            "measured_constraint_removal_j": terminal_removal,
            "mechanical_energy_change_j": terminal["mechanical_energy_change_j"],
            "signed_residual_change_j": terminal["signed_residual_change_j"],
            "center_of_mass_speed_m_s": terminal["center_of_mass_speed_m_s"],
            "constraint_removal_fraction_of_projection": terminal_removal
            / zero_velocity_projection,
            "residual_growth_fraction_of_projection": terminal[
                "signed_residual_change_j"
            ]
            / zero_velocity_projection,
        },
        "terminal_contiguous_descriptive_window": {
            "outer_step_count": terminal_window_outer_steps,
            "first_outer_index_zero_based": window[0]["outer_index_zero_based"],
            "last_outer_index_zero_based": window[-1]["outer_index_zero_based"],
            "mean_measured_constraint_removal_j": sum(removals) / len(removals),
            "minimum_constraint_removal_fraction_of_projection": min(removals)
            / zero_velocity_projection,
            "maximum_constraint_removal_fraction_of_projection": max(removals)
            / zero_velocity_projection,
            "mean_constraint_removal_fraction_of_projection": sum(removals)
            / len(removals)
            / zero_velocity_projection,
            "mean_signed_residual_change_j": sum(residual_changes) / len(residual_changes),
            "mean_residual_growth_fraction_of_projection": sum(residual_changes)
            / len(residual_changes)
            / zero_velocity_projection,
            "mean_mechanical_energy_change_j": sum(mechanical_changes)
            / len(mechanical_changes),
            "maximum_absolute_mechanical_energy_change_j": max(
                abs(value) for value in mechanical_changes
            ),
            "maximum_center_of_mass_speed_m_s": max(
                row["center_of_mass_speed_m_s"] for row in window
            ),
        },
    }


def _godot_physical_projection_v1(
    arm: Mapping[str, Any], index: int
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    observation = arm["trace_v3"]["observations"][index]
    classification = arm["portable_step_receipts"][index]["classification"]
    return (
        {key: observation["state"][key] for key in _GODOT_PHYSICAL_STATE_FIELDS},
        {key: observation[key] for key in _GODOT_PHYSICAL_OBSERVATION_FIELDS},
        {
            key: classification[key]
            for key in _GODOT_PHYSICAL_CLASSIFICATION_FIELDS
        },
    )


def godot_complete_energy_handoff_diagnosis_v1(
    development_raw: Mapping[str, Any],
    complete_energy_raw: Mapping[str, Any],
    *,
    maximum_energy_balance_residual_j: Any,
    total_dynamic_mass_kg: Any,
    terminal_window_outer_steps: int,
) -> dict[str, Any]:
    """Localize a retained development/complete-energy handoff divergence."""

    threshold = _finite(
        maximum_energy_balance_residual_j,
        "GODOT_HANDOFF_ENERGY_THRESHOLD",
    )
    _require(threshold >= 0.0, "GODOT_HANDOFF_ENERGY_THRESHOLD")
    for key in ("seed", "seed_label", "seed_sha256", "cell_id", "recovery_controller_id"):
        _require(
            development_raw[key] == complete_energy_raw[key],
            f"GODOT_HANDOFF_PAIRED_ROOT:{key}",
        )
    development = development_raw["candidate_arm"]
    complete = complete_energy_raw["candidate_arm"]
    _require(
        development["arm_kind"] == complete["arm_kind"] == "candidate_command"
        and development["declared_initial_state_sha256"]
        == complete["declared_initial_state_sha256"]
        and development["initializer_manifest"]["ordered_body_poses"]
        == complete["initializer_manifest"]["ordered_body_poses"]
        and development["initializer_manifest"]["ordered_joint_positions_rad"]
        == complete["initializer_manifest"]["ordered_joint_positions_rad"]
        and development["initializer_manifest"]["recovery_descriptor_sha256"]
        == complete["initializer_manifest"]["recovery_descriptor_sha256"]
        and development["initializer_manifest"]["recovery_morphology_spec_sha256"]
        == complete["initializer_manifest"]["recovery_morphology_spec_sha256"],
        "GODOT_HANDOFF_PAIRED_INITIAL_STATE",
    )
    common_count = min(
        len(development["portable_step_receipts"]),
        len(complete["portable_step_receipts"]),
    )
    _require(common_count > 0, "GODOT_HANDOFF_PAIRED_COUNT")
    physical_equal = [
        _godot_physical_projection_v1(development, index)
        == _godot_physical_projection_v1(complete, index)
        for index in range(common_count)
    ]
    progression_equal = [
        tuple(
            development["portable_step_receipts"][index][key]
            for key in ("prior_phase", "next_phase", "transitioned")
        )
        == tuple(
            complete["portable_step_receipts"][index][key]
            for key in ("prior_phase", "next_phase", "transitioned")
        )
        for index in range(common_count)
    ]
    first_physical_divergence = next(
        (index for index, value in enumerate(physical_equal) if not value),
        common_count,
    )
    first_progression_divergence = next(
        (index for index, value in enumerate(progression_equal) if not value),
        common_count,
    )
    _require(
        first_progression_divergence < common_count
        and first_physical_divergence < common_count,
        "GODOT_HANDOFF_DIVERGENCE_REQUIRED",
    )
    boundary = first_progression_divergence
    _require(
        first_physical_divergence == boundary + 1
        and all(physical_equal[: boundary + 1])
        and all(progression_equal[:boundary]),
        "GODOT_HANDOFF_DIVERGENCE_ORDER",
    )

    complete_rows, _ = _godot_v3_residual_rows_v1(complete)
    raised = [row for row in complete_rows if row["classification"]["raised_body_gate"]]
    _require(raised, "GODOT_HANDOFF_RAISED_BODY_REQUIRED")
    energy_pass = [
        row for row in complete_rows if abs(row["signed_residual_j"]) <= threshold
    ]
    first_energy_failure = next(
        (
            row
            for row in complete_rows
            if abs(row["signed_residual_j"]) > threshold
        ),
        None,
    )
    _require(first_energy_failure is not None, "GODOT_HANDOFF_ENERGY_FAILURE_REQUIRED")
    first_recovery_actuation = next(
        (
            application
            for application in complete["command_application_receipts"]
            if application["no_actuation_requested"] is False
        ),
        None,
    )
    _require(
        first_recovery_actuation is not None,
        "GODOT_HANDOFF_RECOVERY_ACTUATION_REQUIRED",
    )
    development_step = development["portable_step_receipts"][boundary]
    complete_step = complete["portable_step_receipts"][boundary]
    development_progression = development["development_progression_receipts"][boundary]
    complete_progression = complete["development_progression_receipts"][boundary]
    return {
        "controlled_comparison": {
            "common_candidate_outer_step_count": common_count,
            "physical_projection_equal_prefix_step_count": first_physical_divergence,
            "first_progression_decision_divergence_semantic_step": boundary + 1,
            "first_post_decision_physical_divergence_semantic_step": first_physical_divergence
            + 1,
            "boundary_physical_projection_equal": physical_equal[boundary],
            "development_boundary": {
                "prior_phase": development_step["prior_phase"],
                "next_phase": development_step["next_phase"],
                "transitioned": development_step["transitioned"],
                "energy_balance_residual_j": development_step["classification"][
                    "energy_balance_residual_j"
                ],
                "safety_gate": development_step["classification"]["safety_gate"],
                "raised_body_gate": development_step["classification"][
                    "raised_body_gate"
                ],
                "development_progression_permitted": development_progression[
                    "development_progression_permitted"
                ],
                "development_stance_handoff_gate": development_progression[
                    "development_stance_handoff_gate"
                ],
                "development_progression_used": development_progression[
                    "development_progression_used"
                ],
            },
            "complete_energy_boundary": {
                "prior_phase": complete_step["prior_phase"],
                "next_phase": complete_step["next_phase"],
                "transitioned": complete_step["transitioned"],
                "energy_balance_residual_j": complete_step["classification"][
                    "energy_balance_residual_j"
                ],
                "safety_gate": complete_step["classification"]["safety_gate"],
                "raised_body_gate": complete_step["classification"][
                    "raised_body_gate"
                ],
                "component_partition_complete": complete_progression[
                    "component_partition_complete"
                ],
                "exact_balance_safety_authority": complete_progression[
                    "exact_balance_safety_authority"
                ],
                "development_progression_permitted": complete_progression[
                    "development_progression_permitted"
                ],
                "development_stance_handoff_gate": complete_progression[
                    "development_stance_handoff_gate"
                ],
                "development_progression_used": complete_progression[
                    "development_progression_used"
                ],
            },
        },
        "complete_energy_gate": {
            "maximum_energy_balance_residual_j": threshold,
            "first_energy_residual_failure_semantic_step": first_energy_failure[
                "semantic_step"
            ],
            "last_energy_residual_pass_semantic_step": (
                energy_pass[-1]["semantic_step"] if energy_pass else None
            ),
            "energy_residual_pass_step_count": len(energy_pass),
            "first_recovery_actuation_semantic_step": first_recovery_actuation[
                "semantic_step"
            ],
            "energy_residual_failed_before_recovery_actuation": first_energy_failure[
                "semantic_step"
            ]
            < first_recovery_actuation["semantic_step"],
            "safety_gate_true_step_count": sum(
                row["classification"]["safety_gate"] is True for row in complete_rows
            ),
            "raised_body_step_count": len(raised),
            "raised_body_safety_gate_true_step_count": sum(
                row["classification"]["safety_gate"] is True for row in raised
            ),
            "raised_body_component_pass_counts": {
                "joint_limits_respected": sum(
                    row["classification"]["joint_limits_respected"] is True
                    for row in raised
                ),
                "actuator_budget_respected": sum(
                    row["classification"]["actuator_budget_respected"] is True
                    for row in raised
                ),
                "forbidden_contact_impulse_respected": sum(
                    row["classification"]["maximum_nonfoot_contact_impulse_ns"]
                    == 0.0
                    for row in raised
                ),
                "energy_residual_respected": sum(
                    abs(row["signed_residual_j"]) <= threshold for row in raised
                ),
            },
            "minimum_raised_body_absolute_residual_j": min(
                abs(row["signed_residual_j"]) for row in raised
            ),
            "terminal_signed_residual_j": complete_rows[-1]["signed_residual_j"],
        },
        "complete_energy_candidate_residual_decomposition": (
            godot_v3_energy_residual_decomposition_v1(complete)
        ),
        "complete_energy_matched_zero_residual_decomposition": (
            godot_v3_energy_residual_decomposition_v1(
                complete_energy_raw["matched_zero_arm"]
            )
        ),
        "matched_zero_gravity_staging_projection": (
            godot_v3_zero_control_gravity_staging_projection_v1(
                complete_energy_raw["matched_zero_arm"],
                total_dynamic_mass_kg=total_dynamic_mass_kg,
                terminal_window_outer_steps=terminal_window_outer_steps,
            )
        ),
        "execution_counts": {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
    }


_GODOT_NONSTAGING_ENERGY_FIELDS = (
    "initial_mechanical_energy_j",
    "current_mechanical_energy_j",
    "cumulative_applied_actuator_work_j",
    "cumulative_signed_external_work_j",
    "cumulative_signed_constraint_exchange_j",
    "cumulative_passive_dissipation_j",
)


def godot_discrete_staging_successor_diagnosis_v1(
    predecessor_raw: Mapping[str, Any],
    successor_raw: Mapping[str, Any],
    *,
    maximum_energy_balance_residual_j: Any,
) -> dict[str, Any]:
    """Localize what changed across a staging-only behavior successor.

    The comparison is deliberately exact wherever the retained representation
    permits it.  It proves trajectory and pre-staging ledger identity and then
    checks the residual delta against the newly observed staging channel.  It
    does not infer that any unobserved stage caused the remaining residual.
    """

    threshold = _finite(
        maximum_energy_balance_residual_j,
        "GODOT_STAGING_SUCCESSOR_ENERGY_THRESHOLD",
    )
    _require(threshold >= 0.0, "GODOT_STAGING_SUCCESSOR_ENERGY_THRESHOLD")
    for key in (
        "seed",
        "seed_label",
        "seed_sha256",
        "cell_id",
        "recovery_controller_id",
        "maximum_outer_steps_per_arm",
        "maximum_total_outer_steps",
    ):
        _require(
            predecessor_raw[key] == successor_raw[key],
            f"GODOT_STAGING_SUCCESSOR_PAIRED_ROOT:{key}",
        )

    arm_comparisons: OrderedDict[str, dict[str, Any]] = OrderedDict()
    residual_rows: dict[str, list[dict[str, Any]]] = {}
    phase_contributions: dict[str, OrderedDict[str, dict[str, Any]]] = {}
    for arm_name in ("candidate_arm", "matched_zero_arm"):
        predecessor = predecessor_raw[arm_name]
        successor = successor_raw[arm_name]
        predecessor_count = len(predecessor["portable_step_receipts"])
        successor_count = len(successor["portable_step_receipts"])
        _require(
            predecessor_count > 0 and predecessor_count == successor_count,
            f"GODOT_STAGING_SUCCESSOR_ARM_COUNT:{arm_name}",
        )
        _require(
            predecessor["arm_kind"] == successor["arm_kind"]
            and predecessor["declared_initial_state_sha256"]
            == successor["declared_initial_state_sha256"]
            and predecessor["initializer_manifest"]
            == successor["initializer_manifest"],
            f"GODOT_STAGING_SUCCESSOR_INITIAL_STATE:{arm_name}",
        )

        predecessor_energy = [
            observation["energy_balance"]
            for observation in predecessor["trace_v3"]["observations"]
        ]
        successor_energy = [
            observation["energy_balance"]
            for observation in successor["trace_v3"]["observations"]
        ]
        _require(
            len(predecessor_energy) == predecessor_count
            and len(successor_energy) == successor_count,
            f"GODOT_STAGING_SUCCESSOR_TRACE_COUNT:{arm_name}",
        )
        for index, (before, after) in enumerate(
            zip(predecessor_energy, successor_energy, strict=True)
        ):
            semantic_step = index + 1
            _require(
                _godot_physical_projection_v1(predecessor, index)
                == _godot_physical_projection_v1(successor, index),
                (
                    "GODOT_STAGING_SUCCESSOR_PHYSICAL_IDENTITY:"
                    f"{arm_name}:{semantic_step}"
                ),
            )
            _require(
                before["schema_version"] == after["schema_version"]
                == "sporespore_recovery_energy_balance_ledger_v3"
                and before["equation_id"] == after["equation_id"]
                == (
                    "current_minus_initial_minus_actuator_minus_external_minus_"
                    "constraint_minus_discrete_staging_plus_passive_v3"
                )
                and all(
                    before[field] == after[field]
                    for field in _GODOT_NONSTAGING_ENERGY_FIELDS
                ),
                (
                    "GODOT_STAGING_SUCCESSOR_NONSTAGING_LEDGER_IDENTITY:"
                    f"{arm_name}:{semantic_step}"
                ),
            )
            _require(
                before["cumulative_signed_discrete_staging_exchange_j"] == 0.0,
                (
                    "GODOT_STAGING_SUCCESSOR_PREDECESSOR_STAGING_ZERO:"
                    f"{arm_name}:{semantic_step}"
                ),
            )

        predecessor_rows, _ = _godot_v3_residual_rows_v1(predecessor)
        successor_rows, successor_phases = _godot_v3_residual_rows_v1(successor)
        residual_rows[arm_name] = successor_rows
        phase_contributions[arm_name] = successor_phases
        maximum_identity_error = 0.0
        maximum_identity_bound = 0.0
        for index, (before_row, after_row) in enumerate(
            zip(predecessor_rows, successor_rows, strict=True)
        ):
            staging_delta = (
                successor_energy[index][
                    "cumulative_signed_discrete_staging_exchange_j"
                ]
                - predecessor_energy[index][
                    "cumulative_signed_discrete_staging_exchange_j"
                ]
            )
            error = (
                after_row["signed_residual_j"]
                - before_row["signed_residual_j"]
                + staging_delta
            )
            bound = 16.0 * math.ulp(
                max(
                    abs(after_row["signed_residual_j"]),
                    abs(before_row["signed_residual_j"]),
                    abs(staging_delta),
                    1.0,
                )
            )
            _require(
                abs(error) <= bound,
                (
                    "GODOT_STAGING_SUCCESSOR_RESIDUAL_RELATION:"
                    f"{arm_name}:{index + 1}"
                ),
            )
            maximum_identity_error = max(maximum_identity_error, abs(error))
            maximum_identity_bound = max(maximum_identity_bound, bound)

        nonzero_staging_count = sum(
            energy["cumulative_signed_discrete_staging_exchange_j"] != 0.0
            for energy in successor_energy
        )
        _require(
            nonzero_staging_count > 0,
            f"GODOT_STAGING_SUCCESSOR_STAGING_REQUIRED:{arm_name}",
        )
        threshold_pass = [
            row
            for row in successor_rows
            if abs(row["signed_residual_j"]) <= threshold
        ]
        arm_comparisons[arm_name] = {
            "outer_step_count": successor_count,
            "physical_projection_equal_step_count": successor_count,
            "nonstaging_numeric_ledger_equal_step_count": successor_count,
            "predecessor_zero_staging_step_count": successor_count,
            "successor_nonzero_cumulative_staging_step_count": (
                nonzero_staging_count
            ),
            "residual_delta_plus_staging_identity_maximum_absolute_error_j": (
                maximum_identity_error
            ),
            "residual_delta_plus_staging_identity_maximum_binary64_bound_j": (
                maximum_identity_bound
            ),
            "predecessor_terminal_signed_residual_j": predecessor_rows[-1][
                "signed_residual_j"
            ],
            "successor_terminal_signed_residual_j": successor_rows[-1][
                "signed_residual_j"
            ],
            "successor_terminal_cumulative_signed_staging_exchange_j": (
                successor_energy[-1][
                    "cumulative_signed_discrete_staging_exchange_j"
                ]
            ),
            "successor_energy_residual_pass_step_count": len(threshold_pass),
            "successor_last_energy_residual_pass_semantic_step": (
                threshold_pass[-1]["semantic_step"] if threshold_pass else None
            ),
        }

    candidate = successor_raw["candidate_arm"]
    matched_zero = successor_raw["matched_zero_arm"]
    candidate_applications = candidate["command_application_receipts"]
    matched_zero_applications = matched_zero["command_application_receipts"]
    _require(
        all(
            application["no_actuation_requested"] is True
            for application in matched_zero_applications
        ),
        "GODOT_STAGING_SUCCESSOR_MATCHED_ZERO_CONTROL",
    )
    first_actuation_index = next(
        (
            index
            for index, application in enumerate(candidate_applications)
            if application["no_actuation_requested"] is False
        ),
        None,
    )
    _require(
        first_actuation_index is not None and first_actuation_index > 0,
        "GODOT_STAGING_SUCCESSOR_ACTUATION_REQUIRED",
    )
    common_count = min(
        len(candidate["portable_step_receipts"]),
        len(matched_zero["portable_step_receipts"]),
    )
    first_candidate_zero_physical_divergence = next(
        (
            index
            for index in range(common_count)
            if _godot_physical_projection_v1(candidate, index)
            != _godot_physical_projection_v1(matched_zero, index)
        ),
        common_count,
    )
    _require(
        first_candidate_zero_physical_divergence == first_actuation_index
        and all(
            candidate_applications[index]["no_actuation_requested"] is True
            for index in range(first_actuation_index)
        ),
        "GODOT_STAGING_SUCCESSOR_BRANCH_ORDER",
    )
    candidate_rows = residual_rows["candidate_arm"]
    matched_zero_rows = residual_rows["matched_zero_arm"]
    _require(
        all(
            candidate_rows[index]["signed_residual_j"]
            == matched_zero_rows[index]["signed_residual_j"]
            for index in range(first_actuation_index)
        ),
        "GODOT_STAGING_SUCCESSOR_PREFIX_RESIDUAL_IDENTITY",
    )
    raised = [
        row for row in candidate_rows if row["classification"]["raised_body_gate"]
    ]
    _require(raised, "GODOT_STAGING_SUCCESSOR_RAISED_BODY_REQUIRED")
    candidate_phases = phase_contributions["candidate_arm"]
    matched_zero_phases = phase_contributions["matched_zero_arm"]
    _require(
        tuple(candidate_phases) == (
            "confirm_prone",
            "establish_distal_support",
            "raise_body",
        )
        and tuple(matched_zero_phases) == (
            "confirm_prone",
            "establish_distal_support",
        ),
        "GODOT_STAGING_SUCCESSOR_PHASE_POPULATION",
    )

    return {
        "paired_route_identity": {
            "predecessor_gate_id": predecessor_raw["gate_id"],
            "successor_gate_id": successor_raw["gate_id"],
            "seed": successor_raw["seed"],
            "seed_sha256": successor_raw["seed_sha256"],
            "cell_id": successor_raw["cell_id"],
            "recovery_controller_id": successor_raw["recovery_controller_id"],
            "maximum_energy_balance_residual_j": threshold,
            "arms": arm_comparisons,
        },
        "successor_branch_localization": {
            "candidate_matched_zero_common_unactuated_prefix_step_count": (
                first_actuation_index
            ),
            "first_candidate_actuation_semantic_step": first_actuation_index + 1,
            "first_candidate_matched_zero_physical_divergence_semantic_step": (
                first_candidate_zero_physical_divergence + 1
            ),
            "common_prefix_terminal_signed_residual_j": candidate_rows[
                first_actuation_index - 1
            ]["signed_residual_j"],
            "matched_zero_active_application_count": 0,
            "candidate_phase_signed_residual_change_j": {
                phase: values["signed_residual_change_j"]
                for phase, values in candidate_phases.items()
            },
            "matched_zero_phase_signed_residual_change_j": {
                phase: values["signed_residual_change_j"]
                for phase, values in matched_zero_phases.items()
            },
            "candidate_terminal_minus_matched_zero_terminal_residual_j": (
                candidate_rows[-1]["signed_residual_j"]
                - matched_zero_rows[-1]["signed_residual_j"]
            ),
            "candidate_raised_body_step_count": len(raised),
            "candidate_first_raised_body_semantic_step": raised[0]["semantic_step"],
            "candidate_raised_body_energy_residual_pass_step_count": sum(
                abs(row["signed_residual_j"]) <= threshold for row in raised
            ),
            "candidate_raised_body_joint_limits_pass_step_count": sum(
                row["classification"]["joint_limits_respected"] is True
                for row in raised
            ),
            "candidate_raised_body_actuator_budget_pass_step_count": sum(
                row["classification"]["actuator_budget_respected"] is True
                for row in raised
            ),
            "candidate_raised_body_forbidden_contact_impulse_pass_step_count": sum(
                row["classification"]["maximum_nonfoot_contact_impulse_ns"] == 0.0
                for row in raised
            ),
            "candidate_safety_gate_true_step_count": sum(
                row["classification"]["safety_gate"] is True
                for row in candidate_rows
            ),
            "candidate_stable_stance_gate_true_step_count": sum(
                row["classification"]["stable_stance_gate"] is True
                for row in candidate_rows
            ),
            "candidate_raise_body_to_stance_handoff_transition_count": sum(
                receipt["prior_phase"] == "raise_body"
                and receipt["next_phase"] == "stance_handoff"
                and receipt["transitioned"] is True
                for receipt in candidate["portable_step_receipts"]
            ),
            "candidate_minimum_raised_body_absolute_residual_j": min(
                abs(row["signed_residual_j"]) for row in raised
            ),
            "candidate_maximum_absolute_residual_j": max(
                abs(row["signed_residual_j"]) for row in candidate_rows
            ),
        },
        "execution_counts": {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
    }


_GODOT_ROTATION_INVARIANT_ENERGY_FIELDS = (
    "initial_mechanical_energy_j",
    "current_mechanical_energy_j",
    "cumulative_applied_actuator_work_j",
    "cumulative_signed_external_work_j",
    "cumulative_signed_discrete_staging_exchange_j",
    "cumulative_passive_dissipation_j",
)


def godot_rotation_aware_successor_diagnosis_v1(
    predecessor_raw: Mapping[str, Any],
    successor_raw: Mapping[str, Any],
    *,
    maximum_energy_balance_residual_j: Any,
) -> dict[str, Any]:
    """Compare a rotation-consumer successor without inferring behavior change.

    R162 adds one independently measured rotation-integration term to the
    existing signed constraint channel.  This projection proves that an exact
    predecessor/successor pair retained the same trajectory, non-rotation
    ledger population, and phase progression while bounding the expected
    residual/constraint algebra.  It deliberately says nothing about why a
    physical result occurred or how an unobserved boundary should be repaired.
    """

    threshold = _finite(
        maximum_energy_balance_residual_j,
        "GODOT_ROTATION_SUCCESSOR_ENERGY_THRESHOLD",
    )
    _require(threshold >= 0.0, "GODOT_ROTATION_SUCCESSOR_ENERGY_THRESHOLD")
    for key in (
        "seed",
        "seed_label",
        "seed_sha256",
        "cell_id",
        "recovery_controller_id",
        "maximum_outer_steps_per_arm",
        "maximum_total_outer_steps",
        "energy_route_id",
    ):
        _require(
            predecessor_raw[key] == successor_raw[key],
            f"GODOT_ROTATION_SUCCESSOR_PAIRED_ROOT:{key}",
        )

    arm_comparisons: OrderedDict[str, dict[str, Any]] = OrderedDict()
    for arm_name in ("candidate_arm", "matched_zero_arm"):
        predecessor = predecessor_raw[arm_name]
        successor = successor_raw[arm_name]
        predecessor_count = len(predecessor["portable_step_receipts"])
        successor_count = len(successor["portable_step_receipts"])
        _require(
            predecessor_count > 0 and predecessor_count == successor_count,
            f"GODOT_ROTATION_SUCCESSOR_ARM_COUNT:{arm_name}",
        )
        _require(
            predecessor["arm_kind"] == successor["arm_kind"]
            and predecessor["declared_initial_state_sha256"]
            == successor["declared_initial_state_sha256"]
            and predecessor["initializer_manifest"] == successor["initializer_manifest"],
            f"GODOT_ROTATION_SUCCESSOR_INITIAL_STATE:{arm_name}",
        )

        predecessor_observations = predecessor["trace_v3"]["observations"]
        successor_observations = successor["trace_v3"]["observations"]
        _require(
            len(predecessor_observations) == predecessor_count
            and len(successor_observations) == successor_count,
            f"GODOT_ROTATION_SUCCESSOR_TRACE_COUNT:{arm_name}",
        )
        for index, (before_observation, after_observation) in enumerate(
            zip(predecessor_observations, successor_observations, strict=True)
        ):
            semantic_step = index + 1
            _require(
                _godot_physical_projection_v1(predecessor, index)
                == _godot_physical_projection_v1(successor, index),
                (
                    "GODOT_ROTATION_SUCCESSOR_PHYSICAL_IDENTITY:"
                    f"{arm_name}:{semantic_step}"
                ),
            )
            before_energy = before_observation["energy_balance"]
            after_energy = after_observation["energy_balance"]
            _require(
                before_energy["schema_version"] == after_energy["schema_version"]
                == "sporespore_recovery_energy_balance_ledger_v3"
                and before_energy["equation_id"] == after_energy["equation_id"]
                == (
                    "current_minus_initial_minus_actuator_minus_external_minus_"
                    "constraint_minus_discrete_staging_plus_passive_v3"
                )
                and all(
                    before_energy[field] == after_energy[field]
                    for field in _GODOT_ROTATION_INVARIANT_ENERGY_FIELDS
                ),
                (
                    "GODOT_ROTATION_SUCCESSOR_NONROTATION_LEDGER_IDENTITY:"
                    f"{arm_name}:{semantic_step}"
                ),
            )
            before_step = predecessor["portable_step_receipts"][index]
            after_step = successor["portable_step_receipts"][index]
            _require(
                all(
                    before_step[field] == after_step[field]
                    for field in ("prior_phase", "next_phase", "transitioned")
                ),
                (
                    "GODOT_ROTATION_SUCCESSOR_PHASE_PROGRESSION_IDENTITY:"
                    f"{arm_name}:{semantic_step}"
                ),
            )

        predecessor_rows, _ = _godot_v3_residual_rows_v1(predecessor)
        successor_rows, _ = _godot_v3_residual_rows_v1(successor)
        maximum_identity_error = 0.0
        maximum_identity_bound = 0.0
        maximum_constraint_delta = 0.0
        nonzero_constraint_delta_count = 0
        for index, (before_row, after_row) in enumerate(
            zip(predecessor_rows, successor_rows, strict=True)
        ):
            before_constraint = _finite(
                predecessor_observations[index]["energy_balance"][
                    "cumulative_signed_constraint_exchange_j"
                ],
                f"GODOT_ROTATION_SUCCESSOR_PREDECESSOR_CONSTRAINT:{arm_name}:{index}",
            )
            after_constraint = _finite(
                successor_observations[index]["energy_balance"][
                    "cumulative_signed_constraint_exchange_j"
                ],
                f"GODOT_ROTATION_SUCCESSOR_SUCCESSOR_CONSTRAINT:{arm_name}:{index}",
            )
            constraint_delta = after_constraint - before_constraint
            residual_delta = (
                after_row["signed_residual_j"] - before_row["signed_residual_j"]
            )
            error = residual_delta + constraint_delta
            bound = 16.0 * math.ulp(
                max(
                    abs(after_row["signed_residual_j"]),
                    abs(before_row["signed_residual_j"]),
                    abs(constraint_delta),
                    1.0,
                )
            )
            _require(
                abs(error) <= bound,
                (
                    "GODOT_ROTATION_SUCCESSOR_RESIDUAL_RELATION:"
                    f"{arm_name}:{index + 1}"
                ),
            )
            maximum_identity_error = max(maximum_identity_error, abs(error))
            maximum_identity_bound = max(maximum_identity_bound, bound)
            maximum_constraint_delta = max(maximum_constraint_delta, abs(constraint_delta))
            nonzero_constraint_delta_count += int(constraint_delta != 0.0)

        _require(
            nonzero_constraint_delta_count > 0,
            f"GODOT_ROTATION_SUCCESSOR_MEASUREMENT_DELTA_REQUIRED:{arm_name}",
        )
        raised = [
            row for row in successor_rows if row["classification"]["raised_body_gate"]
        ]
        arm_comparisons[arm_name] = {
            "outer_step_count": successor_count,
            "physical_projection_equal_step_count": successor_count,
            "nonrotation_numeric_ledger_equal_step_count": successor_count,
            "phase_progression_equal_step_count": successor_count,
            "nonzero_rotation_constraint_delta_step_count": nonzero_constraint_delta_count,
            "maximum_absolute_rotation_constraint_delta_j": maximum_constraint_delta,
            "residual_delta_plus_constraint_delta_maximum_absolute_error_j": (
                maximum_identity_error
            ),
            "residual_delta_plus_constraint_delta_maximum_binary64_bound_j": (
                maximum_identity_bound
            ),
            "predecessor_terminal_signed_constraint_exchange_j": (
                predecessor_observations[-1]["energy_balance"][
                    "cumulative_signed_constraint_exchange_j"
                ]
            ),
            "successor_terminal_signed_constraint_exchange_j": (
                successor_observations[-1]["energy_balance"][
                    "cumulative_signed_constraint_exchange_j"
                ]
            ),
            "predecessor_terminal_signed_residual_j": predecessor_rows[-1][
                "signed_residual_j"
            ],
            "successor_terminal_signed_residual_j": successor_rows[-1][
                "signed_residual_j"
            ],
            "raised_body_step_count": len(raised),
            "raised_body_energy_residual_pass_step_count": sum(
                abs(row["signed_residual_j"]) <= threshold for row in raised
            ),
            "safety_gate_true_step_count": sum(
                row["classification"]["safety_gate"] is True for row in successor_rows
            ),
            "raise_body_to_stance_handoff_transition_count": sum(
                receipt["prior_phase"] == "raise_body"
                and receipt["next_phase"] == "stance_handoff"
                and receipt["transitioned"] is True
                for receipt in successor["portable_step_receipts"]
            ),
        }

    return {
        "paired_route_identity": {
            "predecessor_gate_id": predecessor_raw["gate_id"],
            "successor_gate_id": successor_raw["gate_id"],
            "seed": successor_raw["seed"],
            "seed_sha256": successor_raw["seed_sha256"],
            "cell_id": successor_raw["cell_id"],
            "recovery_controller_id": successor_raw["recovery_controller_id"],
            "energy_route_id": successor_raw["energy_route_id"],
            "maximum_energy_balance_residual_j": threshold,
            "arms": arm_comparisons,
        },
        "execution_counts": {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
    }
