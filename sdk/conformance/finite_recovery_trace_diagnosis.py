#!/usr/bin/env python3
"""Compact reusable zero-world diagnosis of a retained recovery trace."""

from __future__ import annotations

from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
from typing import Any

from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    exact,
    require,
    source_bytes,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)


PHASE = "establish_distal_support"
ACTUATORS = (
    "front_left_hip_motor",
    "front_left_knee_motor",
    "front_right_hip_motor",
    "front_right_knee_motor",
    "rear_left_hip_motor",
    "rear_left_knee_motor",
    "rear_right_hip_motor",
    "rear_right_knee_motor",
)
PAIRS = ((0, 1), (2, 3), (4, 5), (6, 7))
CONTACT = {
    "front_left_foot": "FL",
    "front_right_foot": "FR",
    "rear_left_foot": "RL",
    "rear_right_foot": "RR",
}


def _v(value: dict[str, Any]) -> tuple[float, float, float]:
    return (float(value["x"]), float(value["y"]), float(value["z"]))


def _add(
    left: tuple[float, float, float], right: tuple[float, float, float]
) -> tuple[float, float, float]:
    return (left[0] + right[0], left[1] + right[1], left[2] + right[2])


def _dot(
    left: tuple[float, float, float], right: tuple[float, float, float]
) -> float:
    return left[0] * right[0] + left[1] * right[1] + left[2] * right[2]


def _percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    require(bool(ordered), "PERCENTILE_POPULATION")
    position = (len(ordered) - 1) * fraction
    lower, upper = math.floor(position), math.ceil(position)
    return (
        ordered[lower]
        if lower == upper
        else ordered[lower]
        + (ordered[upper] - ordered[lower]) * (position - lower)
    )


def _binary32_floor(value: float) -> float:
    projected = struct.unpack("<f", struct.pack("<f", value))[0]
    if projected > value:
        bits = struct.unpack("<I", struct.pack("<f", projected))[0]
        require(bits > 0, "BINARY32_FLOOR_UNDERFLOW")
        projected = struct.unpack("<f", struct.pack("<I", bits - 1))[0]
    require(0.0 <= projected <= value, "BINARY32_FLOOR_ORDER")
    return projected


def _maximum_scale(
    source: tuple[float, float, float],
    delta: tuple[float, float, float],
    limit: float,
) -> float:
    a = _dot(delta, delta)
    b = 2.0 * _dot(source, delta)
    c = _dot(source, source) - limit * limit
    require(c <= 1.0e-6, "REPLAY_SOURCE_OUTSIDE_TARGET")
    if a == 0.0:
        return 1.0
    discriminant = b * b - 4.0 * a * c
    require(discriminant >= 0.0, "REPLAY_EMPTY_INTERVAL")
    return min(1.0, max(0.0, (-b + math.sqrt(discriminant)) / (2.0 * a)))


def recovery_trace_diagnosis_projection(raw: dict[str, Any]) -> dict[str, Any]:
    """Compute the finite diagnosis without constructing or advancing a world."""

    verify_exact_paths(
        raw,
        {
            "gate_id": "QSDK-R24D101",
            "status": "valid_complete_behavior_development",
            "scientific_outcome": "negative",
            "all_in_run_physical_invariants_passed": True,
            "recovery_success_observed": False,
            "prone_to_standing_claimed": False,
            "model_construction_count": 2,
            "world_build_count": 2,
            "solver_step_count": 536,
        },
        "R101_RAW",
    )
    arm = raw["candidate_arm"]
    verify_exact_paths(
        arm,
        {
            "arm_kind": "candidate_command",
            "outer_step_count": 268,
            "final_phase": "failed",
            "terminal_failure_code": "phase_timeout:establish_distal_support",
            "native_solver_step_count": 268,
        },
        "R101_CANDIDATE",
    )
    applications = [
        value
        for value in arm["command_application_receipts"]
        if value["phase"] == PHASE
    ]
    require(bool(applications), "PHASE_APPLICATION_POPULATION")
    steps = [int(value["semantic_step"]) for value in applications]
    exact(steps, list(range(steps[0], steps[-1] + 1)), "PHASE_STEP_ORDER")
    observations = {
        int(value["semantic_step"]): value
        for value in arm["trace_v3"]["observations"]
    }
    controls = {
        int(value["semantic_step"]): value
        for value in arm["planned_control_receipts"]
    }

    command_digests: set[str] = set()
    target_limits: set[float] = set()
    targets: list[float] | None = None
    velocities = [set() for _ in ACTUATORS]
    positions = [[] for _ in ACTUATORS]
    contacts: Counter[str] = Counter()
    nonzero = [0] * 8
    zero = [0] * 8
    holds = [0] * 8
    fallbacks = [0] * 8
    absolute_applied = [0.0] * 8
    scales = [[] for _ in ACTUATORS]
    parent_outside = [0] * 8
    parent_outward = [0] * 8
    shared = Counter()
    hold_causes = Counter()
    replay_scales: list[float] = []
    limiting_bodies: Counter[str] = Counter()
    replay_impulse = [0.0] * 8
    replay_source_inside = 0
    replay_final_inside = 0
    replay_maximum_excess = -math.inf

    for application in applications:
        exact(
            tuple(value["actuator_id"] for value in application["ordered_intents"]),
            ACTUATORS,
            "ACTUATOR_ORDER",
        )
        control = controls[int(application["source_control_semantic_step"])]
        exact(control["phase"], PHASE, "CONTROL_PHASE")
        command_digests.add(str(control["command_sha256"]))
        command_targets = [
            float(value["target_position_rad"])
            for value in control["ordered_commands"]
        ]
        targets = command_targets if targets is None else targets
        exact(command_targets, targets, "FIXED_TARGETS")

        observation = observations[int(application["semantic_step"])]
        for index, joint in enumerate(
            observation["state"]["ordered_joint_observations"]
        ):
            positions[index].append(float(joint["position_rad"]))
        contact_key = "+".join(
            CONTACT[str(value["contact_site_id"])]
            for value in observation["ordered_foot_bearing_observations"]
            if bool(value["ordinary_unilateral_contact"])
        )
        contacts[contact_key or "none"] += 1

        initial: dict[str, tuple[float, float, float]] = {}
        net_delta: dict[str, tuple[float, float, float]] = defaultdict(
            lambda: (0.0, 0.0, 0.0)
        )
        intents = application["ordered_intents"]
        requested_this_step: list[float] = []
        for index, intent in enumerate(intents):
            guard = intent["native_angular_velocity_guard_projection"]
            parent_source = _v(
                guard["parent_source_angular_velocity_world_rad_s"]
            )
            parent_delta = _v(
                guard["parent_full_scale_delta_angular_velocity_world_rad_s"]
            )
            child_source = _v(guard["child_source_angular_velocity_world_rad_s"])
            child_delta = _v(
                guard["child_full_scale_delta_angular_velocity_world_rad_s"]
            )
            parent = str(guard["parent_body_id"])
            child = str(guard["child_body_id"])
            initial.setdefault(parent, parent_source)
            initial.setdefault(child, child_source)
            net_delta[parent] = _add(net_delta[parent], parent_delta)
            net_delta[child] = _add(net_delta[child], child_delta)
            target_limits.add(float(guard["projection_target_limit_rad_s"]))
            velocities[index].add(float(intent["canonical_target_velocity_rad_s"]))
            applied = float(intent["applied_signed_joint_impulse_nms"])
            scale = float(guard["applied_scale"])
            nonzero[index] += int(applied != 0.0)
            zero[index] += int(scale == 0.0)
            holds[index] += int(bool(guard["outer_guard_zero_impulse_hold"]))
            fallbacks[index] += int(
                bool(guard["representational_zero_impulse_fallback"])
            )
            absolute_applied[index] += abs(applied)
            scales[index].append(scale)
            is_parent_outside = bool(
                guard["parent_source_projection_target_relation"]["outside_limit"]
            )
            is_child_outside = bool(
                guard["child_source_projection_target_relation"]["outside_limit"]
            )
            is_parent_outward = _dot(parent_source, parent_delta) > 0.0
            parent_outside[index] += int(is_parent_outside)
            parent_outward[index] += int(is_parent_outward)
            if index % 2 == 1 and bool(guard["outer_guard_zero_impulse_hold"]):
                hold_causes["parent_outside_child_inside"] += int(
                    is_parent_outside and not is_child_outside
                )
                hold_causes["parent_requested_delta_radially_outward"] += int(
                    is_parent_outward
                )
            requested_this_step.append(
                abs(
                    float(
                        intent["predecessor_projection"][
                            "applied_signed_joint_impulse_nms"
                        ]
                    )
                )
            )

        exact(len(target_limits), 1, "PROJECTION_TARGET_POPULATION")
        target_limit = next(iter(target_limits))
        for hip_index, knee_index in PAIRS:
            hip_post = _v(
                intents[hip_index]["native_angular_velocity_readback"][
                    "child_angular_velocity_world_rad_s"
                ]
            )
            knee_guard = intents[knee_index][
                "native_angular_velocity_guard_projection"
            ]
            knee_source = _v(
                knee_guard["parent_source_angular_velocity_world_rad_s"]
            )
            shared["pair_count"] += 1
            shared["exact_hip_post_equals_knee_parent_source"] += int(
                hip_post == knee_source
            )
            shared["hip_post_outside_inner_target"] += int(
                _dot(hip_post, hip_post) > target_limit * target_limit
            )
            shared["hip_post_within_1e_3_rad_s_of_inner_target"] += int(
                abs(math.sqrt(_dot(hip_post, hip_post)) - target_limit) <= 1.0e-3
            )
            shared["following_knee_outer_hold"] += int(
                bool(knee_guard["outer_guard_zero_impulse_hold"])
            )
            shared["following_knee_representational_fallback"] += int(
                bool(knee_guard["representational_zero_impulse_fallback"])
            )

        require(len(initial) == len(net_delta) == 9, "REPLAY_BODY_COUNT")
        body_maximum = {
            body: _maximum_scale(initial[body], net_delta[body], target_limit)
            for body in initial
        }
        continuous_scale = min(body_maximum.values())
        replay_scale = _binary32_floor(continuous_scale)
        replay_scales.append(replay_scale)
        for body, maximum in body_maximum.items():
            limiting_bodies[body] += int(abs(maximum - continuous_scale) <= 1.0e-12)
            source_excess = _dot(initial[body], initial[body]) - target_limit**2
            delta = tuple(value * replay_scale for value in net_delta[body])
            predicted = _add(initial[body], delta)  # type: ignore[arg-type]
            final_excess = _dot(predicted, predicted) - target_limit**2
            replay_source_inside += int(source_excess <= 0.0)
            replay_final_inside += int(final_excess <= 0.0)
            replay_maximum_excess = max(replay_maximum_excess, final_excess)
        for index, requested in enumerate(requested_this_step):
            replay_impulse[index] += requested * replay_scale

    require(targets is not None, "TARGET_POPULATION")
    exact(len(command_digests), 1, "FIXED_COMMAND_DIGEST")
    minimum_errors = [
        min(abs(targets[index] - value) for value in positions[index])
        for index in range(8)
    ]
    final_errors = [targets[index] - positions[index][-1] for index in range(8)]
    crossings = [
        sum(
            (targets[index] - first) * (targets[index] - second) < 0.0
            for first, second in zip(positions[index], positions[index][1:])
        )
        for index in range(8)
    ]
    hip_observed, knee_observed = sum(absolute_applied[0::2]), sum(
        absolute_applied[1::2]
    )
    hip_replay, knee_replay = sum(replay_impulse[0::2]), sum(replay_impulse[1::2])
    return {
        "phase": {
            "phase": PHASE,
            "application_step_first": steps[0],
            "application_step_last": steps[-1],
            "application_step_count": len(steps),
            "fixed_command_sha256": next(iter(command_digests)),
            "ordered_actuator_ids": list(ACTUATORS),
            "target_positions_rad": targets,
            "canonical_target_velocity_rad_s_population": [
                sorted(value) for value in velocities
            ],
            "first_positions_rad": [value[0] for value in positions],
            "last_positions_rad": [value[-1] for value in positions],
            "minimum_absolute_target_errors_rad": minimum_errors,
            "final_signed_target_errors_rad": final_errors,
            "target_crossing_counts": crossings,
            "contact_set_histogram": dict(sorted(contacts.items())),
            "all_four_contact_step_count": contacts["FL+FR+RL+RR"],
        },
        "sequential_guard": {
            "actuator_intent_count": len(applications) * 8,
            "hip_nonzero_applied_count": sum(nonzero[0::2]),
            "knee_intent_count": len(applications) * 4,
            "knee_zero_scale_count": sum(zero[1::2]),
            "knee_zero_scale_fraction": sum(zero[1::2]) / (len(applications) * 4),
            "per_actuator_nonzero_applied_count": nonzero,
            "per_actuator_zero_scale_count": zero,
            "per_actuator_outer_hold_count": holds,
            "per_actuator_representational_fallback_count": fallbacks,
            "per_actuator_absolute_applied_impulse_sum_nms": absolute_applied,
            "per_actuator_scale_p50": [_percentile(value, 0.50) for value in scales],
            "per_actuator_parent_outside_inner_target_count": parent_outside,
            "per_actuator_parent_requested_delta_radially_outward_count": (
                parent_outward
            ),
            "shared_hip_then_knee": dict(sorted(shared.items())),
            "outer_hold_cause_counts": dict(sorted(hold_causes.items())),
        },
        "order_neutral_population_replay": {
            "counterfactual_kind": "frozen_source_state_non_predictive_zero_world_sensitivity",
            "allocation_rule": "one_common_binary32_floored_scale_for_all_eight_requested_joint_impulses_against_summed_nine_body_angular_velocity_deltas",
            "source_reconstruction_rule": "first_retained_sequential_source_for_each_body_before_that_body_receives_any_same_step_impulse",
            "source_state_count": len(applications),
            "body_relation_count": len(applications) * 9,
            "positive_common_scale_count": sum(value > 0.0 for value in replay_scales),
            "source_inside_inner_target_count": replay_source_inside,
            "replayed_final_inside_inner_target_count": replay_final_inside,
            "binary32_common_scale_minimum": min(replay_scales),
            "binary32_common_scale_p50": _percentile(replay_scales, 0.50),
            "binary32_common_scale_p95": _percentile(replay_scales, 0.95),
            "binary32_common_scale_maximum": max(replay_scales),
            "maximum_replayed_squared_norm_excess_rad2_s2": replay_maximum_excess,
            "limiting_body_count": dict(
                sorted((body, count) for body, count in limiting_bodies.items() if count)
            ),
            "actuator_group_projection": {
                "hips": {
                    "observed_absolute_applied_impulse_sum_nms": hip_observed,
                    "replay_absolute_applied_impulse_sum_nms": hip_replay,
                    "replay_to_observed_ratio": hip_replay / hip_observed,
                },
                "knees": {
                    "observed_absolute_applied_impulse_sum_nms": knee_observed,
                    "replay_absolute_applied_impulse_sum_nms": knee_replay,
                    "replay_to_observed_ratio": knee_replay / knee_observed,
                },
            },
            "trajectory_prediction_claimed": False,
            "behavior_improvement_claimed": False,
            "threshold_or_margin_selected": False,
        },
        "execution_counts": {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "body_impulse_write_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
    }


def _mean(values: list[float]) -> float:
    require(bool(values), "MEAN_POPULATION")
    return sum(values) / len(values)


def _sign_change_count(values: list[float]) -> int:
    return sum(first * second < 0.0 for first, second in zip(values, values[1:]))


def _velocity_projection(values: list[float], target: float) -> dict[str, Any]:
    return {
        "first_rad_s": values[0],
        "last_rad_s": values[-1],
        "minimum_rad_s": min(values),
        "maximum_rad_s": max(values),
        "mean_absolute_rad_s": _mean([abs(value) for value in values]),
        "mean_absolute_target_error_rad_s": _mean(
            [abs(target - value) for value in values]
        ),
        "toward_fixed_target_count": sum(value * target > 0.0 for value in values),
        "away_from_fixed_target_count": sum(value * target < 0.0 for value in values),
        "zero_count": sum(value == 0.0 for value in values),
        "sign_change_count": _sign_change_count(values),
        "magnitude_above_canonical_target_count": sum(
            abs(value) > abs(target) for value in values
        ),
    }


def _candidate_target_tracking_projection(
    raw: dict[str, Any], gate_id: str
) -> dict[str, Any]:
    """Project one immutable candidate trace onto phase-local target tracking."""

    verify_exact_paths(
        raw,
        {
            "gate_id": gate_id,
            "status": "valid_complete_behavior_development",
            "scientific_outcome": "negative",
            "all_in_run_physical_invariants_passed": True,
            "recovery_success_observed": False,
            "prone_to_standing_claimed": False,
            "model_construction_count": 2,
            "world_build_count": 2,
            "solver_step_count": 536,
        },
        f"{gate_id}_RAW",
    )
    arm = raw["candidate_arm"]
    verify_exact_paths(
        arm,
        {
            "arm_kind": "candidate_command",
            "outer_step_count": 268,
            "final_phase": "failed",
            "terminal_failure_code": "phase_timeout:establish_distal_support",
            "native_solver_step_count": 268,
        },
        f"{gate_id}_CANDIDATE",
    )
    applications = [
        value
        for value in arm["command_application_receipts"]
        if value["phase"] == PHASE
    ]
    steps = [int(value["semantic_step"]) for value in applications]
    exact(steps, list(range(29, 269)), f"{gate_id}_PHASE_STEPS")
    observations = {
        int(value["semantic_step"]): value for value in arm["trace_v3"]["observations"]
    }
    controls = {
        int(value["semantic_step"]): value
        for value in arm["planned_control_receipts"]
    }
    target_positions: list[float] | None = None
    target_velocities = [set() for _ in ACTUATORS]
    command_digests: set[str] = set()
    measured = [[] for _ in ACTUATORS]
    post_solver = [[] for _ in ACTUATORS]
    positions = [[] for _ in ACTUATORS]
    anchor_errors = [[] for _ in ACTUATORS]
    impulses = [[] for _ in ACTUATORS]
    contacts: Counter[str] = Counter()
    contact_sequence: list[str] = []
    center_of_mass_y: list[float] = []

    for application in applications:
        intents = application["ordered_intents"]
        exact(
            tuple(value["actuator_id"] for value in intents),
            ACTUATORS,
            f"{gate_id}_ACTUATOR_ORDER",
        )
        control = controls[int(application["source_control_semantic_step"])]
        exact(control["phase"], PHASE, f"{gate_id}_CONTROL_PHASE")
        command_digests.add(str(control["command_sha256"]))
        current_positions = [
            float(value["target_position_rad"])
            for value in control["ordered_commands"]
        ]
        target_positions = current_positions if target_positions is None else target_positions
        exact(current_positions, target_positions, f"{gate_id}_FIXED_TARGETS")
        observation = observations[int(application["semantic_step"])]
        joints = observation["state"]["ordered_joint_observations"]
        exact(
            tuple(value["joint_id"] + "_motor" for value in joints),
            ACTUATORS,
            f"{gate_id}_JOINT_ORDER",
        )
        for index, (intent, joint) in enumerate(zip(intents, joints)):
            target_velocities[index].add(
                float(intent["canonical_target_velocity_rad_s"])
            )
            measured[index].append(
                float(intent["measured_pre_step_relative_velocity_rad_s"])
            )
            post_solver[index].append(float(joint["velocity_rad_s"]))
            positions[index].append(float(joint["position_rad"]))
            anchor_errors[index].append(float(joint["anchor_error_m"]))
            impulses[index].append(float(intent["applied_signed_joint_impulse_nms"]))
        contact_key = "+".join(
            CONTACT[str(value["contact_site_id"])]
            for value in observation["ordered_foot_bearing_observations"]
            if bool(value["ordinary_unilateral_contact"])
        ) or "none"
        contacts[contact_key] += 1
        contact_sequence.append(contact_key)
        center_of_mass_y.append(
            float(observation["center_of_mass"]["position_world_m"]["y"])
        )

    require(target_positions is not None, f"{gate_id}_TARGETS")
    exact(len(command_digests), 1, f"{gate_id}_COMMAND_DIGEST")
    exact([len(value) for value in target_velocities], [1] * 8, f"{gate_id}_VELOCITIES")
    targets = [next(iter(value)) for value in target_velocities]
    actuator_projection: list[dict[str, Any]] = []
    for index, actuator_id in enumerate(ACTUATORS):
        adjacent_position_deltas = [
            abs(second - first)
            for first, second in zip(positions[index], positions[index][1:])
        ]
        target_position = target_positions[index]
        target_velocity = targets[index]
        actuator_projection.append(
            {
                "actuator_id": actuator_id,
                "target_position_rad": target_position,
                "canonical_target_velocity_rad_s": target_velocity,
                "measured_pre_step": _velocity_projection(
                    measured[index], target_velocity
                ),
                "post_solver": _velocity_projection(
                    post_solver[index], target_velocity
                ),
                "position": {
                    "first_rad": positions[index][0],
                    "last_rad": positions[index][-1],
                    "minimum_absolute_target_error_rad": min(
                        abs(target_position - value) for value in positions[index]
                    ),
                    "target_crossing_count": sum(
                        (target_position - first) * (target_position - second) < 0.0
                        for first, second in zip(
                            positions[index], positions[index][1:]
                        )
                    ),
                    "mean_absolute_adjacent_delta_rad": _mean(
                        adjacent_position_deltas
                    ),
                    "maximum_absolute_adjacent_delta_rad": max(
                        adjacent_position_deltas
                    ),
                    "maximum_anchor_error_m": max(anchor_errors[index]),
                },
                "applied_impulse": {
                    "nonzero_count": sum(value != 0.0 for value in impulses[index]),
                    "absolute_sum_nms": sum(abs(value) for value in impulses[index]),
                    "sign_change_count": _sign_change_count(impulses[index]),
                    "correct_velocity_error_direction_count": sum(
                        impulse * (target_velocity - source) > 0.0
                        for impulse, source in zip(impulses[index], measured[index])
                    ),
                },
            }
        )
    return {
        "gate_id": gate_id,
        "phase": PHASE,
        "application_step_first": steps[0],
        "application_step_last": steps[-1],
        "application_step_count": len(steps),
        "fixed_command_sha256": next(iter(command_digests)),
        "ordered_actuator_ids": list(ACTUATORS),
        "target_positions_rad": target_positions,
        "canonical_target_velocities_rad_s": targets,
        "per_actuator": actuator_projection,
        "contact_set_histogram": dict(sorted(contacts.items())),
        "contact_set_transition_count": sum(
            first != second
            for first, second in zip(contact_sequence, contact_sequence[1:])
        ),
        "maximum_simultaneous_distal_contacts": max(
            0 if value == "none" else len(value.split("+"))
            for value in contact_sequence
        ),
        "all_four_contact_step_count": contacts["FL+FR+RL+RR"],
        "center_of_mass_y_m": {
            "first": center_of_mass_y[0],
            "last": center_of_mass_y[-1],
            "minimum": min(center_of_mass_y),
            "maximum": max(center_of_mass_y),
            "last_gain": center_of_mass_y[-1] - center_of_mass_y[0],
        },
    }


def _target_monotone_population_replay(raw: dict[str, Any]) -> dict[str, Any]:
    """Replay R105 source states without constructing or stepping a world."""

    applications = [
        value
        for value in raw["candidate_arm"]["command_application_receipts"]
        if value["phase"] == PHASE
    ]
    current_scales: list[float] = []
    target_scales: list[float] = []
    scale_ratios: list[float] = []
    limiting: Counter[str] = Counter()
    unhelpful: list[dict[str, Any]] = []
    reconstruction_residuals: list[float] = []
    source_errors: list[float] = []
    current_errors: list[float] = []
    target_errors: list[float] = []
    full_delta_helpful_count = 0
    current_crossing_count = 0
    target_crossing_count = 0
    current_worsened_count = 0
    target_nonincreasing_count = 0
    scale_at_or_below_current_count = 0

    for application in applications:
        population = application["order_neutral_population_guard_projection"]
        exact(
            tuple(population["ordered_actuator_ids"]),
            ACTUATORS,
            "R105_REPLAY_ACTUATOR_ORDER",
        )
        bodies = {
            str(value["body_id"]): value
            for value in population["ordered_body_projections"]
        }
        exact(len(bodies), 9, "R105_REPLAY_BODY_COUNT")
        current_scale = float(population["common_applied_scale"])
        current_scales.append(current_scale)
        joint_values: list[dict[str, Any]] = []
        caps: list[float] = []
        for intent in application["ordered_intents"]:
            axis = _v(intent["axis_world"])
            parent = bodies[str(intent["parent_body_id"])]
            child = bodies[str(intent["child_body_id"])]
            source = _dot(
                tuple(
                    child_value - parent_value
                    for child_value, parent_value in zip(
                        _v(child["source_angular_velocity_world_rad_s"]),
                        _v(parent["source_angular_velocity_world_rad_s"]),
                    )
                ),
                axis,
            )
            retained_source = float(
                intent["measured_pre_step_relative_velocity_rad_s"]
            )
            reconstruction_residuals.append(abs(source - retained_source))
            delta = _dot(
                tuple(
                    child_value - parent_value
                    for child_value, parent_value in zip(
                        _v(child["full_scale_delta_angular_velocity_world_rad_s"]),
                        _v(parent["full_scale_delta_angular_velocity_world_rad_s"]),
                    )
                ),
                axis,
            )
            target = float(intent["canonical_target_velocity_rad_s"])
            error = target - source
            helpful = error * delta > 0.0
            full_delta_helpful_count += int(helpful)
            if helpful:
                cap = min(1.0, abs(error / delta))
            elif delta == 0.0:
                cap = 1.0
            else:
                cap = 0.0
                unhelpful.append(
                    {
                        "semantic_step": int(application["semantic_step"]),
                        "actuator_id": str(intent["actuator_id"]),
                        "source_relative_velocity_rad_s": source,
                        "canonical_target_velocity_rad_s": target,
                        "full_scale_relative_velocity_delta_rad_s": delta,
                    }
                )
            caps.append(cap)
            joint_values.append(
                {
                    "actuator_id": str(intent["actuator_id"]),
                    "source": source,
                    "target": target,
                    "delta": delta,
                }
            )
        continuous_target_scale = min(caps)
        projected_target_scale = _binary32_floor(continuous_target_scale)
        applied_target_scale = min(current_scale, projected_target_scale)
        target_scales.append(applied_target_scale)
        scale_ratios.append(applied_target_scale / current_scale)
        scale_at_or_below_current_count += int(applied_target_scale <= current_scale)
        for index, cap in enumerate(caps):
            limiting[ACTUATORS[index]] += int(cap == continuous_target_scale)
        for value in joint_values:
            source = float(value["source"])
            target = float(value["target"])
            delta = float(value["delta"])
            current_predicted = source + delta * current_scale
            target_predicted = source + delta * applied_target_scale
            source_error = abs(target - source)
            current_error = abs(target - current_predicted)
            target_error = abs(target - target_predicted)
            source_errors.append(source_error)
            current_errors.append(current_error)
            target_errors.append(target_error)
            current_crossing_count += int(
                (target - source) * (target - current_predicted) < 0.0
            )
            target_crossing_count += int(
                (target - source) * (target - target_predicted) < 0.0
            )
            current_worsened_count += int(current_error > source_error)
            target_nonincreasing_count += int(target_error <= source_error)

    return {
        "counterfactual_kind": "frozen_source_state_non_predictive_zero_world_sensitivity",
        "source_state_count": len(applications),
        "joint_projection_count": len(applications) * len(ACTUATORS),
        "source_relative_velocity_reconstruction_maximum_absolute_residual_rad_s": max(
            reconstruction_residuals
        ),
        "full_population_delta_helpful_projection_count": full_delta_helpful_count,
        "full_population_delta_unhelpful_projection_count": len(unhelpful),
        "unhelpful_projection_details": unhelpful,
        "current_body_guard_common_scale": {
            "minimum": min(current_scales),
            "p50": _percentile(current_scales, 0.50),
            "maximum": max(current_scales),
        },
        "target_monotone_common_scale": {
            "selection_rule": "binary32_floor_of_minimum_nonovershooting_joint_target_scale_then_minimum_with_existing_body_guard_scale",
            "positive_count": sum(value > 0.0 for value in target_scales),
            "zero_hold_count": sum(value == 0.0 for value in target_scales),
            "minimum": min(target_scales),
            "p05": _percentile(target_scales, 0.05),
            "p50": _percentile(target_scales, 0.50),
            "p95": _percentile(target_scales, 0.95),
            "maximum": max(target_scales),
            "to_current_body_guard_ratio_p50": _percentile(scale_ratios, 0.50),
            "to_current_body_guard_ratio_p95": _percentile(scale_ratios, 0.95),
            "to_current_body_guard_ratio_maximum": max(scale_ratios),
            "at_or_below_current_body_guard_count": scale_at_or_below_current_count,
            "limiting_actuator_count": dict(sorted(limiting.items())),
        },
        "absolute_joint_velocity_target_error": {
            "source_mean_rad_s": _mean(source_errors),
            "current_body_guard_prediction_mean_rad_s": _mean(current_errors),
            "target_monotone_prediction_mean_rad_s": _mean(target_errors),
            "current_body_guard_prediction_worsened_count": current_worsened_count,
            "current_body_guard_prediction_target_crossing_count": current_crossing_count,
            "target_monotone_prediction_nonincreasing_count": target_nonincreasing_count,
            "target_monotone_prediction_target_crossing_count": target_crossing_count,
        },
        "trajectory_prediction_claimed": False,
        "behavior_improvement_claimed": False,
        "threshold_or_margin_selected": False,
    }


def paired_target_tracking_diagnosis_projection(
    r101_raw: dict[str, Any], r105_raw: dict[str, Any]
) -> dict[str, Any]:
    """Compare the two immutable trajectories and replay the smaller control."""

    common_identity_keys = (
        "seed",
        "cell_id",
        "outer_step_duration_s",
        "physics_ticks_per_second",
        "threshold_profile_id",
        "threshold_profile_sha256",
        "maximum_outer_steps_per_arm",
        "required_stance_dwell_steps",
        "stance_dwell_timeout_steps",
    )
    common_identity = {key: r101_raw[key] for key in common_identity_keys}
    exact(
        {key: r105_raw[key] for key in common_identity_keys},
        common_identity,
        "PAIRED_RAW_IDENTITY",
    )
    exact(
        r105_raw["candidate_arm"]["declared_initial_state_sha256"],
        r101_raw["candidate_arm"]["declared_initial_state_sha256"],
        "PAIRED_INITIAL_STATE",
    )
    common_identity["declared_initial_state_sha256"] = r101_raw["candidate_arm"][
        "declared_initial_state_sha256"
    ]
    common_identity["r101_seed_label"] = r101_raw["seed_label"]
    common_identity["r101_seed_sha256"] = r101_raw["seed_sha256"]
    common_identity["r105_seed_label"] = r105_raw["seed_label"]
    common_identity["r105_seed_sha256"] = r105_raw["seed_sha256"]
    r101 = _candidate_target_tracking_projection(r101_raw, "QSDK-R24D101")
    r105 = _candidate_target_tracking_projection(r105_raw, "QSDK-R24D105")
    for key in (
        "phase",
        "application_step_first",
        "application_step_last",
        "application_step_count",
        "fixed_command_sha256",
        "ordered_actuator_ids",
        "target_positions_rad",
        "canonical_target_velocities_rad_s",
    ):
        exact(r105[key], r101[key], f"PAIRED_PHASE:{key}")
    impulse_ratios = [
        r105_value["applied_impulse"]["absolute_sum_nms"]
        / r101_value["applied_impulse"]["absolute_sum_nms"]
        for r101_value, r105_value in zip(
            r101["per_actuator"], r105["per_actuator"]
        )
    ]
    return {
        "paired_identity": common_identity,
        "r101_candidate": r101,
        "r105_candidate": r105,
        "paired_comparison": {
            "r105_to_r101_per_actuator_absolute_applied_impulse_ratio": impulse_ratios,
            "r105_all_actuators_nonzero_on_all_phase_steps": all(
                value["applied_impulse"]["nonzero_count"] == 240
                for value in r105["per_actuator"]
            ),
            "r105_all_actuators_post_solver_sign_change_every_adjacent_step": all(
                value["post_solver"]["sign_change_count"] == 239
                for value in r105["per_actuator"]
            ),
            "r101_all_four_contact_step_count": r101["all_four_contact_step_count"],
            "r105_all_four_contact_step_count": r105["all_four_contact_step_count"],
        },
        "r105_target_monotone_population_replay": _target_monotone_population_replay(
            r105_raw
        ),
        "execution_counts": {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "body_impulse_write_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
    }


def paired_target_tracking_diagnosis_summary(
    projection: dict[str, Any]
) -> dict[str, Any]:
    """Select the compact human-facing facts from the hashed full projection."""

    r101 = projection["r101_candidate"]
    r105 = projection["r105_candidate"]
    replay = projection["r105_target_monotone_population_replay"]
    error = replay["absolute_joint_velocity_target_error"]
    scale = replay["target_monotone_common_scale"]
    return {
        "phase_application_step_count": r105["application_step_count"],
        "fixed_command_sha256": r105["fixed_command_sha256"],
        "target_positions_rad": r105["target_positions_rad"],
        "canonical_target_velocities_rad_s": r105[
            "canonical_target_velocities_rad_s"
        ],
        "r101_contact_set_histogram": r101["contact_set_histogram"],
        "r105_contact_set_histogram": r105["contact_set_histogram"],
        "r101_contact_set_transition_count": r101[
            "contact_set_transition_count"
        ],
        "r105_contact_set_transition_count": r105[
            "contact_set_transition_count"
        ],
        "r101_maximum_simultaneous_distal_contacts": r101[
            "maximum_simultaneous_distal_contacts"
        ],
        "r105_maximum_simultaneous_distal_contacts": r105[
            "maximum_simultaneous_distal_contacts"
        ],
        "r101_center_of_mass_y_m": r101["center_of_mass_y_m"],
        "r105_center_of_mass_y_m": r105["center_of_mass_y_m"],
        "r105_measured_pre_step_mean_absolute_velocity_rad_s": [
            value["measured_pre_step"]["mean_absolute_rad_s"]
            for value in r105["per_actuator"]
        ],
        "r105_post_solver_mean_absolute_velocity_rad_s": [
            value["post_solver"]["mean_absolute_rad_s"]
            for value in r105["per_actuator"]
        ],
        "r105_measured_pre_step_sign_change_count": [
            value["measured_pre_step"]["sign_change_count"]
            for value in r105["per_actuator"]
        ],
        "r105_post_solver_sign_change_count": [
            value["post_solver"]["sign_change_count"]
            for value in r105["per_actuator"]
        ],
        "r105_measured_toward_fixed_target_count": [
            value["measured_pre_step"]["toward_fixed_target_count"]
            for value in r105["per_actuator"]
        ],
        "r105_measured_away_from_fixed_target_count": [
            value["measured_pre_step"]["away_from_fixed_target_count"]
            for value in r105["per_actuator"]
        ],
        "r105_mean_absolute_adjacent_position_delta_rad": [
            value["position"]["mean_absolute_adjacent_delta_rad"]
            for value in r105["per_actuator"]
        ],
        "r105_maximum_anchor_error_m": [
            value["position"]["maximum_anchor_error_m"]
            for value in r105["per_actuator"]
        ],
        "r105_to_r101_absolute_impulse_ratio": projection["paired_comparison"][
            "r105_to_r101_per_actuator_absolute_applied_impulse_ratio"
        ],
        "source_relative_velocity_reconstruction_maximum_absolute_residual_rad_s": replay[
            "source_relative_velocity_reconstruction_maximum_absolute_residual_rad_s"
        ],
        "full_population_delta_helpful_projection_count": replay[
            "full_population_delta_helpful_projection_count"
        ],
        "full_population_delta_unhelpful_projection_count": replay[
            "full_population_delta_unhelpful_projection_count"
        ],
        "unhelpful_projection_details": replay["unhelpful_projection_details"],
        "current_body_guard_common_scale": replay[
            "current_body_guard_common_scale"
        ],
        "target_monotone_common_scale": scale,
        "source_mean_absolute_joint_velocity_target_error_rad_s": error[
            "source_mean_rad_s"
        ],
        "current_body_guard_prediction_mean_absolute_joint_velocity_target_error_rad_s": error[
            "current_body_guard_prediction_mean_rad_s"
        ],
        "target_monotone_prediction_mean_absolute_joint_velocity_target_error_rad_s": error[
            "target_monotone_prediction_mean_rad_s"
        ],
        "current_body_guard_prediction_target_crossing_count": error[
            "current_body_guard_prediction_target_crossing_count"
        ],
        "target_monotone_prediction_nonincreasing_count": error[
            "target_monotone_prediction_nonincreasing_count"
        ],
        "target_monotone_prediction_target_crossing_count": error[
            "target_monotone_prediction_target_crossing_count"
        ],
        "execution_counts": projection["execution_counts"],
    }


def _load_raw(path: Path, length: int, digest: str) -> dict[str, Any]:
    exact(path.stat().st_size, length, "RAW_LENGTH")
    with path.open("rb") as handle:
        exact(
            "sha256:" + hashlib.file_digest(handle, "sha256").hexdigest(),
            digest,
            "RAW_SHA256",
        )
    with path.open("r", encoding="utf-8-sig") as handle:
        value = json.load(handle)
    require(isinstance(value, dict), "RAW_ROOT")
    return value


def _load_bound_physical_raw(
    root: Path, binding: dict[str, Any], label: str
) -> dict[str, Any]:
    closure_bytes = (root / str(binding["physical_closure_path"])).read_bytes()
    exact(
        (
            len(closure_bytes),
            "sha256:" + hashlib.sha256(closure_bytes).hexdigest(),
        ),
        (
            int(binding["physical_closure_byte_length"]),
            str(binding["physical_closure_raw_sha256"]),
        ),
        f"{label}_CLOSURE_IDENTITY",
    )
    closure = json.loads(closure_bytes)
    verify_exact_paths(
        closure,
        {
            "gate_id": binding["gate_id"],
            "closure_status": binding["closure_status"],
            "physical_attempt.source_commit": binding["physical_source_commit"],
            "physical_attempt.status": "valid_complete_behavior_development",
            "physical_attempt.scientific_outcome": "negative",
            "physical_attempt.same_identity_rerun_permitted": False,
        },
        f"{label}_CLOSURE",
    )
    attempt = closure["physical_attempt"]
    artifact = attempt["artifacts"]["raw"]
    evidence_path = Path(str(attempt["evidence_root"])) / str(artifact["path"])
    exact(
        str(evidence_path).replace("\\", "/"),
        binding["raw_result_path"],
        f"{label}_RAW_PATH",
    )
    exact(
        (int(artifact["byte_length"]), str(artifact["raw_sha256"])),
        (
            int(binding["raw_result_byte_length"]),
            str(binding["raw_result_raw_sha256"]),
        ),
        f"{label}_RAW_DECLARATION",
    )
    return _load_raw(
        evidence_path,
        int(binding["raw_result_byte_length"]),
        str(binding["raw_result_raw_sha256"]),
    )


def validate_paired_target_tracking_diagnosis(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    *,
    gate_id: str,
    next_gate_id: str,
    live_record_key: str,
    live_identity_prefix: str,
) -> dict[str, Any]:
    """Validate a content-addressed paired trace diagnosis and live binding."""

    raw_bytes = (root / relative_path).read_bytes()
    exact(
        (len(raw_bytes), "sha256:" + hashlib.sha256(raw_bytes).hexdigest()),
        (expected_length, expected_sha256),
        "PAIRED_DIAGNOSIS_IDENTITY",
    )
    diagnosis = json.loads(raw_bytes)
    verify_exact_paths(
        diagnosis,
        {
            "schema_version": schema,
            "gate_id": gate_id,
            "question_class": "development",
            "physical_question_declared": False,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
        },
        "PAIRED_DIAGNOSIS",
    )
    r101_raw = _load_bound_physical_raw(
        root, diagnosis["predecessors"]["r24d101"], "R101"
    )
    r105_raw = _load_bound_physical_raw(
        root, diagnosis["predecessors"]["r24d105"], "R105"
    )
    projection = paired_target_tracking_diagnosis_projection(r101_raw, r105_raw)
    canonical_projection = json.dumps(
        projection,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")
    exact(
        (
            len(canonical_projection),
            "sha256:" + hashlib.sha256(canonical_projection).hexdigest(),
        ),
        (
            diagnosis["computed_projection_canonical_byte_length"],
            diagnosis["computed_projection_canonical_sha256"],
        ),
        "PAIRED_TARGET_TRACKING_PROJECTION_IDENTITY",
    )
    exact(
        paired_target_tracking_diagnosis_summary(projection),
        diagnosis["computed_projection_summary"],
        "PAIRED_TARGET_TRACKING_PROJECTION_SUMMARY",
    )
    verify_exact_paths(
        diagnosis,
        {
            "decision.r24d101_same_identity_rerun_permitted": False,
            "decision.r24d105_same_identity_rerun_permitted": False,
            "decision.r24d107_zero_world_implementation_authorized": True,
            "decision.physical_execution_authorized": False,
            "decision.historical_threshold_changed": False,
            "decision.historical_margin_changed": False,
            "decision.historical_selector_changed": False,
            "decision.historical_evaluator_changed": False,
            "decision.historical_result_rewritten": False,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "next_boundary.gate_id": next_gate_id,
            "next_boundary.physical_question_declared": False,
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_build_count": 0,
            "next_boundary.maximum_physical_steps_authorized": 0,
            "claim_boundary.trajectory_prediction_claimed": False,
            "claim_boundary.behavior_improvement_claimed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
        },
        "PAIRED_DECISION",
    )
    expected_live = dict(diagnosis["live_authority_projection"])
    expected_live.update(
        {
            f"{live_identity_prefix}_path": relative_path,
            f"{live_identity_prefix}_raw_sha256": expected_sha256,
            f"{live_identity_prefix}_byte_length": expected_length,
        }
    )
    verify_legacy_live_authority_projection(
        root,
        tuple(str(value) for value in diagnosis["live_authority_paths"]),
        record_key=live_record_key,
        expected=expected_live,
        prefix=f"LIVE_{gate_id.replace('-', '_')}_DIAGNOSIS",
    )
    require((root / str(diagnosis["closure_audit_path"])).is_file(), "AUDIT_PATH")
    return diagnosis


def run_paired_target_tracking_cli(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    pass_marker: str,
    failure_marker: str,
    *,
    gate_id: str,
    next_gate_id: str,
    live_record_key: str,
    live_identity_prefix: str,
) -> int:
    try:
        diagnosis = validate_paired_target_tracking_diagnosis(
            root,
            relative_path,
            schema,
            expected_sha256,
            expected_length,
            gate_id=gate_id,
            next_gate_id=next_gate_id,
            live_record_key=live_record_key,
            live_identity_prefix=live_identity_prefix,
        )
        summary = diagnosis["computed_projection_summary"]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": gate_id,
                    "ok": True,
                    "status": diagnosis["status"],
                    "source_state_count": summary["phase_application_step_count"],
                    "current_target_crossing_count": summary[
                        "current_body_guard_prediction_target_crossing_count"
                    ],
                    "target_monotone_target_crossing_count": summary[
                        "target_monotone_prediction_target_crossing_count"
                    ],
                    "target_monotone_zero_hold_count": summary[
                        "target_monotone_common_scale"
                    ]["zero_hold_count"],
                    "model_construction_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "prone_to_standing_claimed": False,
                    "sdk1_milestone_advanced": False,
                },
                sort_keys=True,
            ),
        )
        return 0
    except (
        ClosureAuditError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(f"{failure_marker}:{error}", file=sys.stderr)
        return 1


def validate_diagnosis(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
) -> dict[str, Any]:
    raw_bytes = (root / relative_path).read_bytes()
    exact(
        (len(raw_bytes), "sha256:" + hashlib.sha256(raw_bytes).hexdigest()),
        (expected_length, expected_sha256),
        "DIAGNOSIS_IDENTITY",
    )
    diagnosis = json.loads(raw_bytes)
    verify_exact_paths(
        diagnosis,
        {
            "schema_version": schema,
            "gate_id": "QSDK-R24D102",
            "question_class": "development",
            "physical_question_declared": False,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.question_class": "development",
        },
        "DIAGNOSIS",
    )
    predecessor = diagnosis["predecessor"]
    closure_raw = (
        root / str(predecessor["r24d101_physical_closure_path"])
    ).read_bytes()
    exact(
        (len(closure_raw), "sha256:" + hashlib.sha256(closure_raw).hexdigest()),
        (
            predecessor["r24d101_physical_closure_byte_length"],
            predecessor["r24d101_physical_closure_raw_sha256"],
        ),
        "R101_CLOSURE_IDENTITY",
    )
    closure = json.loads(closure_raw)
    exact(closure["gate_id"], "QSDK-R24D101", "R101_GATE")
    exact(closure["closure_status"], predecessor["closure_status"], "R101_STATUS")
    artifact = closure["physical_attempt"]["artifacts"]["raw"]
    evidence_path = Path(str(closure["physical_attempt"]["evidence_root"])) / str(
        artifact["path"]
    )
    exact(
        str(evidence_path).replace("\\", "/"),
        predecessor["raw_result_path"],
        "RAW_PATH",
    )
    exact(
        (artifact["byte_length"], artifact["raw_sha256"]),
        (
            predecessor["raw_result_byte_length"],
            predecessor["raw_result_raw_sha256"],
        ),
        "RAW_DECLARATION",
    )
    for binding in diagnosis["source_bindings"]:
        retained = source_bytes(
            root,
            str(predecessor["r24d101_physical_source_commit"]),
            str(binding["path"]),
        )
        exact(
            (len(retained), "sha256:" + hashlib.sha256(retained).hexdigest()),
            (binding["byte_length"], binding["raw_sha256"]),
            f"SOURCE:{binding['path']}",
        )
    raw = _load_raw(
        evidence_path,
        int(predecessor["raw_result_byte_length"]),
        str(predecessor["raw_result_raw_sha256"]),
    )
    exact(
        recovery_trace_diagnosis_projection(raw),
        diagnosis["computed_projection"],
        "DIAGNOSIS_PROJECTION",
    )
    verify_exact_paths(
        diagnosis,
        {
            "decision.r24d101_same_identity_rerun_permitted": False,
            "decision.r24d101_historical_audit_live_successor_state_decoupled": True,
            "decision.historical_threshold_changed": False,
            "decision.historical_margin_changed": False,
            "decision.historical_selector_changed": False,
            "decision.historical_evaluator_changed": False,
            "decision.historical_result_rewritten": False,
            "decision.physical_execution_authorized": False,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "next_boundary.gate_id": "QSDK-R24D103",
            "next_boundary.physical_question_declared": False,
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_build_count": 0,
            "next_boundary.maximum_physical_steps_authorized": 0,
            "claim_boundary.trajectory_prediction_claimed": False,
            "claim_boundary.behavior_improvement_claimed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
        },
        "DECISION",
    )
    expected_live = dict(diagnosis["live_authority_projection"])
    # These two values described the then-current successor boundary rather
    # than the immutable R102 diagnosis.  Later valid successors must not turn
    # the retained evidence audit red.
    for key in (
        "next_gate_id",
        "r24d103_zero_world_population_projection_required",
    ):
        expected_live.pop(key, None)
    expected_live.update(
        {
            "r24d102_diagnosis_path": relative_path,
            "r24d102_diagnosis_raw_sha256": expected_sha256,
            "r24d102_diagnosis_byte_length": expected_length,
        }
    )
    verify_legacy_live_authority_projection(
        root,
        tuple(str(value) for value in diagnosis["live_authority_paths"]),
        record_key="r24d101_contract_path",
        expected=expected_live,
        prefix="LIVE_R102_DIAGNOSIS",
    )
    require((root / str(diagnosis["closure_audit_path"])).is_file(), "AUDIT_PATH")
    return diagnosis


def run_cli(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    pass_marker: str,
    failure_marker: str,
) -> int:
    try:
        diagnosis = validate_diagnosis(
            root, relative_path, schema, expected_sha256, expected_length
        )
        projection = diagnosis["computed_projection"]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": "QSDK-R24D102",
                    "ok": True,
                    "status": diagnosis["status"],
                    "phase_step_count": projection["phase"]["application_step_count"],
                    "knee_zero_scale_count": projection["sequential_guard"][
                        "knee_zero_scale_count"
                    ],
                    "positive_common_scale_count": projection[
                        "order_neutral_population_replay"
                    ]["positive_common_scale_count"],
                    "model_construction_count": 0,
                    "world_build_count": 0,
                    "solver_step_count": 0,
                    "prone_to_standing_claimed": False,
                    "sdk1_milestone_advanced": False,
                },
                sort_keys=True,
            ),
        )
        return 0
    except (
        ClosureAuditError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
        TypeError,
        ValueError,
    ) as error:
        print(f"{failure_marker}:{error}", file=sys.stderr)
        return 1
