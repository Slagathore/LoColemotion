#!/usr/bin/env python3
"""Reusable retained-state load-path diagnosis for finite recovery work."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
from typing import Any

from sdk.conformance.content_addressed_zero_world_closure import (
    ClosureAuditError,
    canonical_bytes,
    exact,
    require,
    sha256,
    verify_exact_paths,
    verify_legacy_live_authority_projection,
    verify_source_binding,
)
from sdk.conformance.finite_recovery_trace_diagnosis import (
    _load_bound_physical_raw,
)

JOINTS = (
    "front_left_hip",
    "front_left_knee",
    "front_right_hip",
    "front_right_knee",
    "rear_left_hip",
    "rear_left_knee",
    "rear_right_hip",
    "rear_right_knee",
)
FEET = (
    "front_left_foot",
    "front_right_foot",
    "rear_left_foot",
    "rear_right_foot",
)
PHASE = "establish_distal_support"
RAISE_BODY_PHASE = "raise_body"


def _vector(value: dict[str, Any]) -> list[float]:
    return [float(value[axis]) for axis in ("x", "y", "z")]


def _add(left: list[float], right: list[float]) -> list[float]:
    return [left[index] + right[index] for index in range(3)]


def _scale(value: list[float], factor: float) -> list[float]:
    return [component * factor for component in value]


def _basis_multiply(value: dict[str, Any], vector: list[float]) -> list[float]:
    x, y, z = value["x"], value["y"], value["z"]
    return [
        float(x["x"]) * vector[0]
        + float(y["x"]) * vector[1]
        + float(z["x"]) * vector[2],
        float(x["y"]) * vector[0]
        + float(y["y"]) * vector[1]
        + float(z["y"]) * vector[2],
        float(x["z"]) * vector[0]
        + float(y["z"]) * vector[1]
        + float(z["z"]) * vector[2],
    ]


def _solve_from_cholesky(lower: list[list[float]], rhs: list[float]) -> list[float]:
    size = len(rhs)
    exact(
        (len(lower), tuple(len(row) for row in lower)),
        (size, (size,) * size),
        "CHOLESKY_SHAPE",
    )
    forward: list[float] = []
    for row in range(size):
        value = rhs[row]
        for column in range(row):
            value -= float(lower[row][column]) * forward[column]
        forward.append(value / float(lower[row][row]))
    solution = [0.0] * size
    for reverse_index in range(size):
        row = size - 1 - reverse_index
        value = forward[row]
        for column in range(row + 1, size):
            value -= float(lower[column][row]) * solution[column]
        solution[row] = value / float(lower[row][row])
    require(all(math.isfinite(value) for value in solution), "CHOLESKY_SOLUTION")
    return solution


def _next_power_of_two_at_least(value: float) -> float:
    require(math.isfinite(value) and value > 1.0, "POWER_OF_TWO_INPUT")
    result = 1.0
    while result < value:
        result *= 2.0
    return result


def _bearing_projection(arm: dict[str, Any]) -> dict[str, Any]:
    observations = arm["trace_v3"]["observations"]
    per_foot = {foot: 0 for foot in FEET}
    maximum_simultaneous = 0
    all_four: list[tuple[float, int, list[float]]] = []
    for observation in observations:
        bearing = {
            str(value["contact_site_id"]): value
            for value in observation["ordered_foot_bearing_observations"]
        }
        exact(tuple(bearing), FEET, "FOOT_ORDER")
        impulses: list[float] = []
        simultaneous = 0
        for foot in FEET:
            record = bearing[foot]
            ordinary = bool(record["ordinary_unilateral_contact"])
            impulse = float(record["bearing_normal_impulse_ns"]) if ordinary else 0.0
            require(math.isfinite(impulse) and impulse >= 0.0, "FOOT_IMPULSE")
            simultaneous += int(ordinary)
            per_foot[foot] += int(ordinary)
            impulses.append(impulse)
        maximum_simultaneous = max(maximum_simultaneous, simultaneous)
        if simultaneous == len(FEET):
            all_four.append(
                (min(impulses), int(observation["semantic_step"]), impulses)
            )
    result: dict[str, Any] = {
        "maximum_simultaneous_ordinary_distal_contacts": maximum_simultaneous,
        "ordinary_contact_step_count_by_foot": per_foot,
        "all_four_ordinary_contact_step_count": len(all_four),
    }
    if all_four:
        weakest, step, impulses = max(all_four)
        result.update(
            {
                "first_all_four_ordinary_contact_semantic_step": all_four[0][1],
                "last_all_four_ordinary_contact_semantic_step": all_four[-1][1],
                "peak_weakest_simultaneous_foot_impulse_ns": weakest,
                "peak_weakest_simultaneous_foot_semantic_step": step,
                "peak_step_ordered_foot_impulses_ns": impulses,
            }
        )
    return result


def recovery_load_path_projection(
    raw: dict[str, Any],
    *,
    frozen_bearing_minimum_ns: float,
    observed_maximum_target_speed_rad_s: float,
) -> dict[str, Any]:
    """Project one immutable behavior pair without stepping a new world."""

    exact(raw["status"], "valid_complete_behavior_development", "RAW_STATUS")
    exact(raw["scientific_outcome"], "negative", "RAW_OUTCOME")
    exact(raw["recovery_success_observed"], False, "RAW_RECOVERY")
    exact(raw["all_in_run_physical_invariants_passed"], True, "RAW_INVARIANTS")
    candidate = raw["candidate_arm"]
    matched_zero = raw["matched_zero_arm"]
    exact(candidate["arm_kind"], "candidate_command", "CANDIDATE_ARM")
    exact(matched_zero["arm_kind"], "matched_zero_command", "ZERO_ARM")

    observations = candidate["trace_v3"]["observations"]
    steps = candidate["portable_step_receipts"]
    exact(len(observations), len(steps), "TRACE_STEP_COUNT")
    indices = [
        index for index, step in enumerate(steps) if step["prior_phase"] == PHASE
    ]
    exact(indices, list(range(indices[0], indices[0] + 240)), "PHASE_STEPS")
    require(indices[0] > 0, "PHASE_SOURCE")
    controls = [
        value
        for value in candidate["planned_control_receipts"]
        if value["phase"] == PHASE
    ]
    applications = [
        value
        for value in candidate["command_application_receipts"]
        if value["phase"] == PHASE
    ]
    exact((len(controls), len(applications)), (240, 240), "PHASE_COUNTS")

    duration = float(raw["outer_step_duration_s"])
    require(math.isfinite(duration) and duration > 0.0, "OUTER_STEP_DURATION")
    minimum_unclamped_speed = math.inf
    current_maximum_solution_to_cap_ratio = 0.0
    current_positive_common_scale_count = 0
    current_representation_zero_hold_count = 0
    phase_rows: list[dict[str, Any]] = []
    stable_targets: list[float] | None = None
    stable_command_sha256: str | None = None
    for offset, observation_index in enumerate(indices):
        control = controls[offset]
        application = applications[offset]
        source_observation = observations[observation_index - 1]
        post_observation = observations[observation_index]
        exact(
            (
                int(control["semantic_step"]),
                int(application["source_control_semantic_step"]),
                int(application["semantic_step"]),
                int(source_observation["semantic_step"]),
                int(post_observation["semantic_step"]),
            ),
            (
                int(source_observation["semantic_step"]),
                int(source_observation["semantic_step"]),
                int(post_observation["semantic_step"]),
                int(source_observation["semantic_step"]),
                int(source_observation["semantic_step"]) + 1,
            ),
            f"PHASE_ALIGNMENT:{offset}",
        )
        commands = control["ordered_commands"]
        intents = application["ordered_intents"]
        exact(len(commands), len(JOINTS), f"COMMAND_COUNT:{offset}")
        exact(len(intents), len(JOINTS), f"INTENT_COUNT:{offset}")
        exact(
            tuple(str(value["joint_id"]) for value in commands), JOINTS, "COMMAND_ORDER"
        )
        exact(
            tuple(str(value["joint_id"]) for value in intents), JOINTS, "INTENT_ORDER"
        )
        positions = {
            str(value["joint_id"]): float(value["position_rad"])
            for value in source_observation["state"]["ordered_joint_observations"]
        }
        exact(tuple(positions), JOINTS, "SOURCE_JOINT_ORDER")
        targets = [float(value["target_position_rad"]) for value in commands]
        if stable_targets is None:
            stable_targets = targets
            stable_command_sha256 = str(control["command_sha256"])
        exact(targets, stable_targets, "TARGET_STABILITY")
        exact(
            str(control["command_sha256"]), stable_command_sha256, "COMMAND_STABILITY"
        )
        for index, command in enumerate(commands):
            exact(
                float(command["maximum_target_speed_rad_s"]),
                observed_maximum_target_speed_rad_s,
                f"OBSERVED_MAXIMUM_SPEED:{offset}:{index}",
            )
            intent = intents[index]
            exact(
                float(intent["canonical_target_velocity_rad_s"]),
                math.copysign(
                    observed_maximum_target_speed_rad_s,
                    targets[index] - positions[JOINTS[index]],
                ),
                f"OBSERVED_SATURATION:{offset}:{index}",
            )
            minimum_unclamped_speed = min(
                minimum_unclamped_speed,
                abs(targets[index] - positions[JOINTS[index]]) / duration,
            )
        population = application[
            "joint_space_effective_inertia_population_guard_projection"
        ]
        current_maximum_solution_to_cap_ratio = max(
            current_maximum_solution_to_cap_ratio,
            float(population["maximum_solution_to_published_cap_ratio"]),
        )
        current_positive_common_scale_count += int(
            float(population["nominal_composed_common_scale"]) > 0.0
        )
        current_representation_zero_hold_count += int(
            bool(population["representation_zero_hold"])
        )
        phase_rows.append(
            {
                "targets": targets,
                "positions": positions,
                "application": application,
            }
        )

    candidate_bearing = _bearing_projection(candidate)
    matched_zero_bearing = _bearing_projection(matched_zero)
    peak_weakest = float(candidate_bearing["peak_weakest_simultaneous_foot_impulse_ns"])
    require(
        math.isfinite(frozen_bearing_minimum_ns)
        and frozen_bearing_minimum_ns > 0.0
        and peak_weakest > 0.0
        and peak_weakest < frozen_bearing_minimum_ns,
        "BEARING_GAP",
    )
    gap_ratio = frozen_bearing_minimum_ns / peak_weakest
    selected_multiplier = _next_power_of_two_at_least(gap_ratio)
    selected_speed = observed_maximum_target_speed_rad_s * selected_multiplier
    require(minimum_unclamped_speed > selected_speed, "SELECTED_SPEED_NOT_SATURATED")

    maximum_solution_to_cap_ratio = 0.0
    maximum_body_angular_speed = 0.0
    minimum_projection_headroom = math.inf
    for row in phase_rows:
        application = row["application"]
        population = application[
            "joint_space_effective_inertia_population_guard_projection"
        ]
        joints = population["ordered_joint_solve_projections"]
        target_velocities = [
            math.copysign(
                selected_speed, row["targets"][index] - row["positions"][joint]
            )
            for index, joint in enumerate(JOINTS)
        ]
        reconstructed = [
            float(value["reconstructed_source_relative_velocity_rad_s"])
            for value in joints
        ]
        solution = _solve_from_cholesky(
            population["cholesky_lower_factor"],
            [target_velocities[index] - reconstructed[index] for index in range(8)],
        )
        caps = [
            float(value["published_maximum_outer_step_impulse_nms"]) for value in joints
        ]
        maximum_solution_to_cap_ratio = max(
            maximum_solution_to_cap_ratio,
            max(abs(solution[index]) / caps[index] for index in range(8)),
        )
        bodies = population["body_guard_population_projection"][
            "ordered_body_projections"
        ]
        aggregate = {str(body["body_id"]): [0.0, 0.0, 0.0] for body in bodies}
        for index, impulse in enumerate(solution):
            axis = _vector(joints[index]["axis_world"])
            angular_impulse = _scale(axis, impulse)
            parent = str(joints[index]["parent_body_id"])
            child = str(joints[index]["child_body_id"])
            aggregate[parent] = _add(aggregate[parent], _scale(angular_impulse, -1.0))
            aggregate[child] = _add(aggregate[child], angular_impulse)
        target_limit = float(
            population["inner_projection_target"]["projection_target_limit_rad_s"]
        )
        for body in bodies:
            body_id = str(body["body_id"])
            predicted = _add(
                _vector(body["source_angular_velocity_world_rad_s"]),
                _basis_multiply(
                    body["inverse_inertia_tensor_world_kg_inv_m2"], aggregate[body_id]
                ),
            )
            speed = math.sqrt(sum(component * component for component in predicted))
            maximum_body_angular_speed = max(maximum_body_angular_speed, speed)
            minimum_projection_headroom = min(
                minimum_projection_headroom, target_limit - speed
            )

    return {
        "support_command_sha256": stable_command_sha256,
        "support_phase_step_count": len(indices),
        "observed_support_target_positions_rad": stable_targets,
        "observed_maximum_target_speed_rad_s": observed_maximum_target_speed_rad_s,
        "minimum_absolute_unclamped_target_speed_across_phase_rad_s": minimum_unclamped_speed,
        "candidate_bearing_projection": candidate_bearing,
        "matched_zero_bearing_projection": matched_zero_bearing,
        "frozen_minimum_distal_bearing_impulse_ns": frozen_bearing_minimum_ns,
        "observed_peak_weakest_to_frozen_bearing_ratio": peak_weakest
        / frozen_bearing_minimum_ns,
        "frozen_bearing_to_observed_peak_weakest_gap_ratio": gap_ratio,
        "selected_smallest_exact_power_of_two_multiplier_above_gap": selected_multiplier,
        "selected_successor_maximum_target_speed_rad_s": selected_speed,
        "current_maximum_solution_to_published_cap_ratio": current_maximum_solution_to_cap_ratio,
        "current_positive_common_scale_application_count": current_positive_common_scale_count,
        "current_representation_zero_hold_application_count": current_representation_zero_hold_count,
        "selected_speed_retained_state_float64_reprojection": {
            "projection_kind": "counterfactual_same_retained_source_state_float64_joint_space_solve_without_native_application_or_new_trajectory",
            "maximum_solution_to_published_cap_ratio": maximum_solution_to_cap_ratio,
            "maximum_full_scale_predicted_body_angular_speed_rad_s": maximum_body_angular_speed,
            "minimum_projection_target_headroom_rad_s": minimum_projection_headroom,
            "all_solutions_inside_unchanged_published_caps": maximum_solution_to_cap_ratio
            < 1.0,
            "all_predicted_bodies_inside_unchanged_projection_target": minimum_projection_headroom
            > 0.0,
            "binary32_representation_or_application_projected": False,
            "new_physical_trajectory_projected": False,
        },
        "execution_counts": {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
    }


def _semantic_index(
    values: list[dict[str, Any]], label: str
) -> dict[int, dict[str, Any]]:
    indexed = {int(value["semantic_step"]): value for value in values}
    exact(len(indexed), len(values), f"{label}_SEMANTIC_STEP_UNIQUENESS")
    return indexed


def _ordered_joint_positions(observation: dict[str, Any]) -> list[float]:
    joints = observation["state"]["ordered_joint_observations"]
    exact(tuple(str(value["joint_id"]) for value in joints), JOINTS, "JOINT_ORDER")
    positions = [float(value["position_rad"]) for value in joints]
    require(all(math.isfinite(value) for value in positions), "JOINT_POSITIONS")
    return positions


def _foot_impulses(observation: dict[str, Any]) -> tuple[list[bool], list[float]]:
    values = observation["ordered_foot_bearing_observations"]
    exact(tuple(str(value["contact_site_id"]) for value in values), FEET, "FOOT_ORDER")
    ordinary = [bool(value["ordinary_unilateral_contact"]) for value in values]
    impulses = [float(value["bearing_normal_impulse_ns"]) for value in values]
    require(
        all(math.isfinite(value) and value >= 0.0 for value in impulses),
        "FOOT_IMPULSES",
    )
    return ordinary, impulses


def _phase_boundary_application_projection(
    arm: dict[str, Any], application_step: int
) -> dict[str, Any]:
    observations = _semantic_index(arm["trace_v3"]["observations"], "BOUNDARY_OBS")
    controls = _semantic_index(arm["planned_control_receipts"], "BOUNDARY_CONTROL")
    applications = _semantic_index(
        arm["command_application_receipts"], "BOUNDARY_APPLICATION"
    )
    application = applications[application_step]
    source_step = int(application["source_control_semantic_step"])
    exact(application_step, source_step + 1, "BOUNDARY_APPLICATION_ALIGNMENT")
    control = controls[source_step]
    source = observations[source_step]
    post = observations[application_step]
    commands = control["ordered_commands"]
    intents = application["ordered_intents"]
    exact(
        tuple(str(value["joint_id"]) for value in commands),
        JOINTS,
        "BOUNDARY_COMMAND_ORDER",
    )
    exact(
        tuple(str(value["joint_id"]) for value in intents),
        JOINTS,
        "BOUNDARY_INTENT_ORDER",
    )
    speeds = {float(value["maximum_target_speed_rad_s"]) for value in commands}
    exact(len(speeds), 1, "BOUNDARY_SPEED_POPULATION")
    ordinary, impulses = _foot_impulses(post)
    receipt = arm["portable_step_receipts"][application_step - 1]
    exact(int(post["semantic_step"]), application_step, "BOUNDARY_POST_STEP")
    population = application[
        "joint_space_effective_inertia_population_guard_projection"
    ]
    return {
        "application_semantic_step": application_step,
        "source_semantic_step": source_step,
        "phase": str(application["phase"]),
        "phase_step": int(control["phase_step"]),
        "command_sha256": str(control["command_sha256"]),
        "target_positions_rad": [
            float(value["target_position_rad"]) for value in commands
        ],
        "maximum_target_speed_rad_s": next(iter(speeds)),
        "canonical_target_velocities_rad_s": [
            float(value["canonical_target_velocity_rad_s"]) for value in intents
        ],
        "source_joint_positions_rad": _ordered_joint_positions(source),
        "post_joint_positions_rad": _ordered_joint_positions(post),
        "absolute_applied_impulse_sum_nms": sum(
            abs(float(value["applied_signed_joint_impulse_nms"])) for value in intents
        ),
        "maximum_solution_to_published_cap_ratio": float(
            population["maximum_solution_to_published_cap_ratio"]
        ),
        "joint_space_common_pre_scale": float(
            population["joint_space_common_pre_scale"]
        ),
        "body_guard_common_applied_scale": float(
            population["body_guard_common_applied_scale"]
        ),
        "nominal_composed_common_scale": float(
            population["nominal_composed_common_scale"]
        ),
        "representation_refinement_count": int(
            population["representation_refinement_count"]
        ),
        "post_all_four_ordinary_contact": all(ordinary),
        "post_ordered_foot_impulses_ns": impulses,
        "post_weakest_foot_impulse_ns": min(impulses),
        "post_all_four_distal_sites_bearing": bool(
            receipt["classification"]["all_four_distal_sites_bearing"]
        ),
        "post_center_of_mass_height_gain_m": float(
            receipt["classification"]["center_of_mass_height_gain_m"]
        ),
    }


def raise_body_speed_continuity_projection(
    r115_raw: dict[str, Any],
    r118_raw: dict[str, Any],
    *,
    frozen_bearing_minimum_ns: float,
    frozen_minimum_com_height_gain_m: float,
    frozen_minimum_nonfoot_clearance_m: float,
    observed_support_speed_rad_s: float,
    observed_raise_body_speed_rad_s: float,
    selected_raise_body_speed_rad_s: float,
) -> dict[str, Any]:
    """Diagnose one immutable support-to-raise transition without a new world."""

    r115_projection = recovery_load_path_projection(
        r115_raw,
        frozen_bearing_minimum_ns=frozen_bearing_minimum_ns,
        observed_maximum_target_speed_rad_s=1.0,
    )
    verify_exact_paths(
        r118_raw,
        {
            "gate_id": "QSDK-R24D118",
            "status": "valid_complete_behavior_development",
            "scientific_outcome": "negative",
            "recovery_success_observed": False,
            "all_in_run_physical_invariants_passed": True,
            "prone_to_standing_claimed": False,
            "model_construction_count": 2,
            "world_build_count": 2,
            "solver_step_count": 907,
        },
        "R118_RAW",
    )
    candidate = r118_raw["candidate_arm"]
    matched_zero = r118_raw["matched_zero_arm"]
    verify_exact_paths(
        candidate,
        {
            "arm_kind": "candidate_command",
            "outer_step_count": 639,
            "final_phase": "failed",
            "terminal_failure_code": "phase_timeout:raise_body",
            "native_solver_step_count": 639,
        },
        "R118_CANDIDATE",
    )
    verify_exact_paths(
        matched_zero,
        {
            "arm_kind": "matched_zero_command",
            "outer_step_count": 268,
            "final_phase": "failed",
            "terminal_failure_code": "phase_timeout:establish_distal_support",
            "native_solver_step_count": 268,
        },
        "R118_ZERO",
    )
    exact(r115_raw["seed"], r118_raw["seed"], "SHARED_SEED")
    exact(
        r115_raw["threshold_profile_sha256"],
        r118_raw["threshold_profile_sha256"],
        "SHARED_THRESHOLD_PROFILE",
    )
    exact(
        r115_raw["outer_step_duration_s"],
        r118_raw["outer_step_duration_s"],
        "SHARED_OUTER_STEP_DURATION",
    )
    exact(
        r115_raw["candidate_arm"]["declared_initial_state_sha256"],
        candidate["declared_initial_state_sha256"],
        "SHARED_CANDIDATE_INITIAL_STATE",
    )
    exact(
        r115_raw["candidate_arm"]["initializer_manifest_sha256"],
        candidate["initializer_manifest_sha256"],
        "SHARED_CANDIDATE_INITIALIZER",
    )

    observations = candidate["trace_v3"]["observations"]
    steps = candidate["portable_step_receipts"]
    exact(len(observations), len(steps), "R118_TRACE_STEP_COUNT")
    support_indices = [
        index for index, step in enumerate(steps) if step["prior_phase"] == PHASE
    ]
    raise_indices = [
        index
        for index, step in enumerate(steps)
        if step["prior_phase"] == RAISE_BODY_PHASE
    ]
    exact(support_indices, list(range(28, 39)), "R118_SUPPORT_PHASE_INDICES")
    exact(raise_indices, list(range(39, 639)), "R118_RAISE_PHASE_INDICES")

    support_last = _phase_boundary_application_projection(candidate, 39)
    raise_first = _phase_boundary_application_projection(candidate, 40)
    exact(support_last["phase"], PHASE, "BOUNDARY_SUPPORT_PHASE")
    exact(raise_first["phase"], RAISE_BODY_PHASE, "BOUNDARY_RAISE_PHASE")
    exact(support_last["phase_step"], 10, "BOUNDARY_SUPPORT_PHASE_STEP")
    exact(raise_first["phase_step"], 0, "BOUNDARY_RAISE_PHASE_STEP")
    exact(
        support_last["target_positions_rad"],
        raise_first["target_positions_rad"],
        "BOUNDARY_TARGET_POSITIONS",
    )
    exact(
        support_last["maximum_target_speed_rad_s"],
        observed_support_speed_rad_s,
        "BOUNDARY_SUPPORT_SPEED",
    )
    exact(
        raise_first["maximum_target_speed_rad_s"],
        observed_raise_body_speed_rad_s,
        "BOUNDARY_RAISE_SPEED",
    )
    exact(
        [
            math.copysign(1.0, value)
            for value in support_last["canonical_target_velocities_rad_s"]
        ],
        [
            math.copysign(1.0, value)
            for value in raise_first["canonical_target_velocities_rad_s"]
        ],
        "BOUNDARY_TARGET_VELOCITY_SIGNS",
    )

    controls = _semantic_index(candidate["planned_control_receipts"], "R118_CONTROL")
    observation_by_step = _semantic_index(observations, "R118_OBSERVATION")
    applications = [
        value
        for value in candidate["command_application_receipts"]
        if value["phase"] == RAISE_BODY_PHASE
    ]
    exact(len(applications), 600, "R118_RAISE_APPLICATION_COUNT")
    exact(
        [int(value["semantic_step"]) for value in applications],
        list(range(40, 640)),
        "R118_RAISE_APPLICATION_STEPS",
    )

    duration = float(r118_raw["outer_step_duration_s"])
    require(math.isfinite(duration) and duration > 0.0, "OUTER_STEP_DURATION")
    joint_source_positions: list[list[float]] = [[] for _ in JOINTS]
    joint_post_positions: list[list[float]] = [[] for _ in JOINTS]
    joint_targets: list[list[float]] = [[] for _ in JOINTS]
    joint_velocities: list[set[float]] = [set() for _ in JOINTS]
    joint_nonzero_impulses = [0] * len(JOINTS)
    joint_absolute_impulse_sums = [0.0] * len(JOINTS)
    minimum_unclamped_speed = math.inf
    selected_sign_match_count = 0
    selected_projection_count = 0
    maximum_solution_to_cap_ratio = 0.0
    maximum_solve_residual = 0.0
    maximum_body_angular_speed = 0.0
    minimum_projection_headroom = math.inf
    per_actuator_solution_abs_maximum = [0.0] * len(JOINTS)
    per_actuator_cap_ratio_maximum = [0.0] * len(JOINTS)
    current_positive_common_scale_count = 0
    current_representation_zero_hold_count = 0
    current_solver_guard_engagement_count = 0
    current_representation_refinement_count = 0
    current_body_impulse_write_count = 0
    current_joint_target_crossing_count = 0
    current_minimum_common_scale = math.inf
    current_maximum_common_scale = 0.0

    for application in applications:
        application_step = int(application["semantic_step"])
        source_step = int(application["source_control_semantic_step"])
        exact(application_step, source_step + 1, "RAISE_APPLICATION_ALIGNMENT")
        control = controls[source_step]
        exact(control["phase"], RAISE_BODY_PHASE, "RAISE_CONTROL_PHASE")
        source = observation_by_step[source_step]
        post = observation_by_step[application_step]
        source_positions = _ordered_joint_positions(source)
        post_positions = _ordered_joint_positions(post)
        commands = control["ordered_commands"]
        intents = application["ordered_intents"]
        exact(
            tuple(str(value["joint_id"]) for value in commands),
            JOINTS,
            "RAISE_COMMAND_ORDER",
        )
        exact(
            tuple(str(value["joint_id"]) for value in intents),
            JOINTS,
            "RAISE_INTENT_ORDER",
        )
        targets = [float(value["target_position_rad"]) for value in commands]
        exact(
            {float(value["maximum_target_speed_rad_s"]) for value in commands},
            {observed_raise_body_speed_rad_s},
            "RAISE_OBSERVED_SPEED",
        )
        target_velocities: list[float] = []
        for index, joint_id in enumerate(JOINTS):
            error = targets[index] - source_positions[index]
            require(
                error != 0.0 and math.isfinite(error), f"RAISE_TARGET_ERROR:{joint_id}"
            )
            minimum_unclamped_speed = min(
                minimum_unclamped_speed, abs(error) / duration
            )
            selected_velocity = math.copysign(selected_raise_body_speed_rad_s, error)
            target_velocities.append(selected_velocity)
            observed_velocity = float(intents[index]["canonical_target_velocity_rad_s"])
            selected_sign_match_count += int(
                math.copysign(1.0, observed_velocity)
                == math.copysign(1.0, selected_velocity)
            )
            selected_projection_count += 1
            joint_source_positions[index].append(source_positions[index])
            joint_post_positions[index].append(post_positions[index])
            joint_targets[index].append(targets[index])
            joint_velocities[index].add(observed_velocity)
            applied = float(intents[index]["applied_signed_joint_impulse_nms"])
            joint_nonzero_impulses[index] += int(applied != 0.0)
            joint_absolute_impulse_sums[index] += abs(applied)

        population = application[
            "joint_space_effective_inertia_population_guard_projection"
        ]
        current_scale = float(population["nominal_composed_common_scale"])
        current_positive_common_scale_count += int(current_scale > 0.0)
        current_representation_zero_hold_count += int(
            bool(population["representation_zero_hold"])
        )
        current_solver_guard_engagement_count += int(
            bool(population["solver_guard_engaged"])
        )
        current_representation_refinement_count += int(
            population["representation_refinement_count"]
        )
        current_body_impulse_write_count += int(application["body_impulse_write_count"])
        current_joint_target_crossing_count += int(
            application["joint_target_crossing_count"]
        )
        current_minimum_common_scale = min(current_minimum_common_scale, current_scale)
        current_maximum_common_scale = max(current_maximum_common_scale, current_scale)

        joint_projections = population["ordered_joint_solve_projections"]
        exact(
            tuple(str(value["joint_id"]) for value in joint_projections),
            JOINTS,
            "RAISE_SOLVE_ORDER",
        )
        reconstructed = [
            float(value["reconstructed_source_relative_velocity_rad_s"])
            for value in joint_projections
        ]
        right_hand_side = [
            target_velocities[index] - reconstructed[index]
            for index in range(len(JOINTS))
        ]
        solution = _solve_from_cholesky(
            population["cholesky_lower_factor"], right_hand_side
        )
        matrix = [
            [float(value) for value in row]
            for row in population["symmetric_response_matrix"]
        ]
        reconstructed_delta = [
            sum(matrix[row][column] * solution[column] for column in range(len(JOINTS)))
            for row in range(len(JOINTS))
        ]
        maximum_solve_residual = max(
            maximum_solve_residual,
            max(
                abs(reconstructed_delta[index] - right_hand_side[index])
                for index in range(len(JOINTS))
            ),
        )
        caps = [
            float(value["published_maximum_outer_step_impulse_nms"])
            for value in joint_projections
        ]
        for index, impulse in enumerate(solution):
            ratio = abs(impulse) / caps[index]
            per_actuator_solution_abs_maximum[index] = max(
                per_actuator_solution_abs_maximum[index], abs(impulse)
            )
            per_actuator_cap_ratio_maximum[index] = max(
                per_actuator_cap_ratio_maximum[index], ratio
            )
            maximum_solution_to_cap_ratio = max(maximum_solution_to_cap_ratio, ratio)

        bodies = population["body_guard_population_projection"][
            "ordered_body_projections"
        ]
        aggregate = {str(body["body_id"]): [0.0, 0.0, 0.0] for body in bodies}
        for index, impulse in enumerate(solution):
            axis = _vector(joint_projections[index]["axis_world"])
            angular_impulse = _scale(axis, impulse)
            parent = str(joint_projections[index]["parent_body_id"])
            child = str(joint_projections[index]["child_body_id"])
            aggregate[parent] = _add(aggregate[parent], _scale(angular_impulse, -1.0))
            aggregate[child] = _add(aggregate[child], angular_impulse)
        target_limit = float(
            population["inner_projection_target"]["projection_target_limit_rad_s"]
        )
        for body in bodies:
            body_id = str(body["body_id"])
            predicted = _add(
                _vector(body["source_angular_velocity_world_rad_s"]),
                _basis_multiply(
                    body["inverse_inertia_tensor_world_kg_inv_m2"],
                    aggregate[body_id],
                ),
            )
            speed = math.sqrt(sum(component * component for component in predicted))
            maximum_body_angular_speed = max(maximum_body_angular_speed, speed)
            minimum_projection_headroom = min(
                minimum_projection_headroom, target_limit - speed
            )

    raise_rows: list[dict[str, Any]] = []
    per_foot_values: dict[str, list[float]] = {foot: [] for foot in FEET}
    per_foot_ordinary: dict[str, int] = {foot: 0 for foot in FEET}
    body_contact_counts: dict[str, int] = {}
    body_ventral_counts: dict[str, int] = {}
    body_minimum_clearance: dict[str, float] = {}
    body_maximum_impulse: dict[str, float] = {}
    for index in raise_indices:
        observation = observations[index]
        classification = steps[index]["classification"]
        ordinary, impulses = _foot_impulses(observation)
        for foot_index, foot in enumerate(FEET):
            per_foot_values[foot].append(impulses[foot_index])
            per_foot_ordinary[foot] += int(ordinary[foot_index])
        for body in observation["ordered_body_clearance_observations"]:
            body_id = str(body["body_id"])
            body_contact_counts.setdefault(body_id, 0)
            body_ventral_counts.setdefault(body_id, 0)
            body_minimum_clearance.setdefault(body_id, math.inf)
            body_maximum_impulse.setdefault(body_id, 0.0)
            body_contact_counts[body_id] += int(bool(body["nonfoot_contact_present"]))
            body_ventral_counts[body_id] += int(bool(body["ventral_surface_contact"]))
            body_minimum_clearance[body_id] = min(
                body_minimum_clearance[body_id],
                float(body["minimum_nonfoot_clearance_m"]),
            )
            body_maximum_impulse[body_id] = max(
                body_maximum_impulse[body_id],
                float(body["accumulated_nonfoot_normal_impulse_ns"]),
            )
        raise_rows.append(
            {
                "semantic_step": int(observation["semantic_step"]),
                "all_four_ordinary": all(ordinary),
                "all_four_bearing": bool(
                    classification["all_four_distal_sites_bearing"]
                ),
                "weakest_foot_impulse_ns": min(impulses),
                "center_of_mass_height_gain_m": float(
                    classification["center_of_mass_height_gain_m"]
                ),
                "any_nonfoot_contact": bool(classification["any_nonfoot_contact"]),
                "torso_ventral_contact": bool(classification["torso_ventral_contact"]),
                "minimum_nonfoot_clearance_m": float(
                    classification["minimum_nonfoot_clearance_m"]
                ),
                "maximum_nonfoot_contact_impulse_ns": float(
                    classification["maximum_nonfoot_contact_impulse_ns"]
                ),
                "raised_body_gate": bool(classification["raised_body_gate"]),
                "safety_gate": bool(classification["safety_gate"]),
            }
        )

    maximum_com_row = max(
        raise_rows, key=lambda value: value["center_of_mass_height_gain_m"]
    )
    minimum_com_row = min(
        raise_rows, key=lambda value: value["center_of_mass_height_gain_m"]
    )
    peak_weakest_row = max(
        raise_rows, key=lambda value: value["weakest_foot_impulse_ns"]
    )
    joint_projection = []
    for index, joint_id in enumerate(JOINTS):
        errors = [
            joint_targets[index][row] - joint_source_positions[index][row]
            for row in range(len(applications))
        ]
        joint_projection.append(
            {
                "joint_id": joint_id,
                "source_position_first_rad": joint_source_positions[index][0],
                "post_position_last_rad": joint_post_positions[index][-1],
                "minimum_absolute_position_target_error_rad": min(
                    abs(value) for value in errors
                ),
                "observed_canonical_target_velocity_population_rad_s": sorted(
                    joint_velocities[index]
                ),
                "nonzero_applied_impulse_count": joint_nonzero_impulses[index],
                "absolute_applied_impulse_sum_nms": joint_absolute_impulse_sums[index],
            }
        )

    return {
        "controlled_comparison": {
            "seed": int(r118_raw["seed"]),
            "threshold_profile_sha256": str(r118_raw["threshold_profile_sha256"]),
            "outer_step_duration_s": duration,
            "candidate_initial_state_sha256": str(
                candidate["declared_initial_state_sha256"]
            ),
            "initializer_manifest_sha256": str(
                candidate["initializer_manifest_sha256"]
            ),
            "r115_controller_id": str(r115_raw["recovery_controller_id"]),
            "r118_controller_id": str(r118_raw["recovery_controller_id"]),
        },
        "r115_support_context": {
            "support_phase_step_count": int(
                r115_projection["support_phase_step_count"]
            ),
            "observed_maximum_target_speed_rad_s": float(
                r115_projection["observed_maximum_target_speed_rad_s"]
            ),
            "all_four_ordinary_contact_step_count": int(
                r115_projection["candidate_bearing_projection"][
                    "all_four_ordinary_contact_step_count"
                ]
            ),
            "peak_weakest_simultaneous_foot_impulse_ns": float(
                r115_projection["candidate_bearing_projection"][
                    "peak_weakest_simultaneous_foot_impulse_ns"
                ]
            ),
            "frozen_bearing_to_observed_peak_gap_ratio": float(
                r115_projection["frozen_bearing_to_observed_peak_weakest_gap_ratio"]
            ),
            "selected_successor_maximum_target_speed_rad_s": float(
                r115_projection["selected_successor_maximum_target_speed_rad_s"]
            ),
        },
        "r118_phase_boundary": {
            "support_phase_step_count": len(support_indices),
            "raise_body_phase_step_count": len(raise_indices),
            "support_last_application": support_last,
            "raise_body_first_application": raise_first,
            "target_positions_identical": True,
            "target_velocity_signs_identical": True,
            "maximum_target_speed_ratio_support_to_raise": (
                observed_support_speed_rad_s / observed_raise_body_speed_rad_s
            ),
            "absolute_applied_impulse_ratio_support_to_raise": (
                float(support_last["absolute_applied_impulse_sum_nms"])
                / float(raise_first["absolute_applied_impulse_sum_nms"])
            ),
            "weakest_foot_impulse_ratio_support_to_raise": (
                float(support_last["post_weakest_foot_impulse_ns"])
                / float(raise_first["post_weakest_foot_impulse_ns"])
            ),
        },
        "r118_raise_body_observation": {
            "semantic_step_first": int(raise_rows[0]["semantic_step"]),
            "semantic_step_last": int(raise_rows[-1]["semantic_step"]),
            "phase_step_count": len(raise_rows),
            "all_four_ordinary_contact_step_count": sum(
                bool(value["all_four_ordinary"]) for value in raise_rows
            ),
            "all_four_bearing_step_count": sum(
                bool(value["all_four_bearing"]) for value in raise_rows
            ),
            "peak_weakest_foot_impulse": {
                "semantic_step": int(peak_weakest_row["semantic_step"]),
                "value_ns": float(peak_weakest_row["weakest_foot_impulse_ns"]),
                "ratio_to_frozen_bearing_minimum": float(
                    peak_weakest_row["weakest_foot_impulse_ns"]
                )
                / frozen_bearing_minimum_ns,
            },
            "center_of_mass_height_gain_first_m": float(
                raise_rows[0]["center_of_mass_height_gain_m"]
            ),
            "center_of_mass_height_gain_last_m": float(
                raise_rows[-1]["center_of_mass_height_gain_m"]
            ),
            "center_of_mass_height_gain_maximum": {
                "semantic_step": int(maximum_com_row["semantic_step"]),
                "value_m": float(maximum_com_row["center_of_mass_height_gain_m"]),
            },
            "center_of_mass_height_gain_minimum": {
                "semantic_step": int(minimum_com_row["semantic_step"]),
                "value_m": float(minimum_com_row["center_of_mass_height_gain_m"]),
            },
            "com_height_component_pass_count": sum(
                float(value["center_of_mass_height_gain_m"])
                >= frozen_minimum_com_height_gain_m
                for value in raise_rows
            ),
            "no_nonfoot_contact_component_pass_count": sum(
                not bool(value["any_nonfoot_contact"]) for value in raise_rows
            ),
            "minimum_clearance_component_pass_count": sum(
                float(value["minimum_nonfoot_clearance_m"])
                >= frozen_minimum_nonfoot_clearance_m
                for value in raise_rows
            ),
            "raised_body_gate_count": sum(
                bool(value["raised_body_gate"]) for value in raise_rows
            ),
            "safety_gate_count": sum(
                bool(value["safety_gate"]) for value in raise_rows
            ),
            "any_nonfoot_contact_step_count": sum(
                bool(value["any_nonfoot_contact"]) for value in raise_rows
            ),
            "torso_ventral_contact_step_count": sum(
                bool(value["torso_ventral_contact"]) for value in raise_rows
            ),
            "maximum_nonfoot_contact_impulse_ns": max(
                float(value["maximum_nonfoot_contact_impulse_ns"])
                for value in raise_rows
            ),
            "per_foot": [
                {
                    "foot_id": foot,
                    "ordinary_contact_step_count": per_foot_ordinary[foot],
                    "bearing_threshold_step_count": sum(
                        value >= frozen_bearing_minimum_ns
                        for value in per_foot_values[foot]
                    ),
                    "minimum_bearing_impulse_ns": min(per_foot_values[foot]),
                    "maximum_bearing_impulse_ns": max(per_foot_values[foot]),
                }
                for foot in FEET
            ],
            "per_body_nonfoot_load_path": [
                {
                    "body_id": body_id,
                    "nonfoot_contact_step_count": body_contact_counts[body_id],
                    "ventral_contact_step_count": body_ventral_counts[body_id],
                    "minimum_clearance_m": body_minimum_clearance[body_id],
                    "maximum_accumulated_normal_impulse_ns": body_maximum_impulse[
                        body_id
                    ],
                }
                for body_id in body_contact_counts
            ],
            "per_joint_tracking": joint_projection,
            "current_application_projection": {
                "application_count": len(applications),
                "positive_common_scale_count": current_positive_common_scale_count,
                "representation_zero_hold_count": current_representation_zero_hold_count,
                "solver_guard_engagement_count": current_solver_guard_engagement_count,
                "representation_refinement_count": current_representation_refinement_count,
                "body_impulse_write_count": current_body_impulse_write_count,
                "joint_target_crossing_count": current_joint_target_crossing_count,
                "minimum_common_scale": current_minimum_common_scale,
                "maximum_common_scale": current_maximum_common_scale,
            },
        },
        "selected_raise_body_speed_retained_state_float64_projection": {
            "projection_kind": "same_600_immutable_r118_raise_body_source_states_float64_joint_space_solve_without_native_application_or_new_trajectory",
            "source_state_count": len(applications),
            "joint_projection_count": selected_projection_count,
            "selected_maximum_target_speed_rad_s": selected_raise_body_speed_rad_s,
            "selection_basis": "continue_the_already_qualified_immediately_preceding_r117_support_speed_across_the_raise_body_phase_boundary",
            "minimum_absolute_unclamped_target_speed_across_phase_rad_s": minimum_unclamped_speed,
            "all_selected_commands_speed_saturated": (
                minimum_unclamped_speed > selected_raise_body_speed_rad_s
            ),
            "all_target_error_signs_match_observed_command_signs": (
                selected_sign_match_count == selected_projection_count
            ),
            "maximum_solve_residual_rad_s": maximum_solve_residual,
            "per_actuator_maximum_absolute_solved_impulse_nms": per_actuator_solution_abs_maximum,
            "per_actuator_maximum_solution_to_published_cap_ratio": per_actuator_cap_ratio_maximum,
            "maximum_solution_to_published_cap_ratio": maximum_solution_to_cap_ratio,
            "all_solutions_inside_unchanged_published_caps": (
                maximum_solution_to_cap_ratio < 1.0
            ),
            "maximum_full_scale_predicted_body_angular_speed_rad_s": maximum_body_angular_speed,
            "minimum_projection_target_headroom_rad_s": minimum_projection_headroom,
            "all_predicted_bodies_inside_unchanged_projection_target": (
                minimum_projection_headroom > 0.0
            ),
            "binary32_representation_or_application_projected": False,
            "new_physical_trajectory_projected": False,
        },
        "execution_counts": {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
    }


def _raise_body_observed_actuation_projection(
    raw: dict[str, Any],
    *,
    expected_gate_id: str,
    observed_speed_rad_s: float,
    raise_body_ramp_steps: int,
    target_velocity_rule: str = "require_speed_ceiling_saturated",
) -> dict[str, Any]:
    """Summarize one complete immutable raise-body actuation trajectory."""

    exact(
        target_velocity_rule
        in (
            "require_speed_ceiling_saturated",
            "exact_position_error_clamp",
        ),
        True,
        "ACTUATION_TARGET_VELOCITY_RULE",
    )

    verify_exact_paths(
        raw,
        {
            "gate_id": expected_gate_id,
            "status": "valid_complete_behavior_development",
            "scientific_outcome": "negative",
            "recovery_success_observed": False,
            "all_in_run_physical_invariants_passed": True,
            "prone_to_standing_claimed": False,
            "model_construction_count": 2,
            "world_build_count": 2,
            "solver_step_count": 907,
        },
        f"{expected_gate_id}_RAW",
    )
    candidate = raw["candidate_arm"]
    verify_exact_paths(
        candidate,
        {
            "arm_kind": "candidate_command",
            "outer_step_count": 639,
            "final_phase": "failed",
            "terminal_failure_code": "phase_timeout:raise_body",
            "native_solver_step_count": 639,
        },
        f"{expected_gate_id}_CANDIDATE",
    )
    observations = _semantic_index(
        candidate["trace_v3"]["observations"], f"{expected_gate_id}_OBSERVATION"
    )
    controls = _semantic_index(
        candidate["planned_control_receipts"], f"{expected_gate_id}_CONTROL"
    )
    applications = [
        value
        for value in candidate["command_application_receipts"]
        if value["phase"] == RAISE_BODY_PHASE
    ]
    exact(len(applications), 600, f"{expected_gate_id}_APPLICATION_COUNT")
    exact(
        [int(value["semantic_step"]) for value in applications],
        list(range(40, 640)),
        f"{expected_gate_id}_APPLICATION_STEPS",
    )

    absolute_impulse_sum = 0.0
    maximum_solution_to_cap_ratio = 0.0
    maximum_immediate_target_velocity_residual = 0.0
    absolute_post_solver_delta_retention_ratios: list[float] = []
    absolute_post_solver_speed_to_command_ratios: list[float] = []
    post_solver_helpful_count = 0
    post_solver_nonhelpful_count = 0
    positive_common_scale_count = 0
    representation_zero_hold_count = 0
    joint_target_crossing_count = 0
    body_impulse_write_count = 0
    target_trajectory: list[list[float]] = []
    settled_semantic_steps: list[int] = []
    settled_foot_impulse_totals: list[float] = []
    settled_torso_impulses: list[float] = []
    settled_nonfoot_impulse_totals: list[float] = []
    settled_foot_shares: list[float] = []
    settled_all_load_foot_shares: list[float] = []
    settled_com_heights: list[float] = []
    settled_joint_positions: list[list[float]] = [[] for _ in JOINTS]
    all_four_bearing_count = 0
    nonfoot_contact_count = 0
    speed_ceiling_saturated_projection_count = 0

    for application in applications:
        semantic_step = int(application["semantic_step"])
        source_step = int(application["source_control_semantic_step"])
        exact(semantic_step, source_step + 1, "ACTUATION_APPLICATION_ALIGNMENT")
        source = observations[source_step]
        post = observations[semantic_step]
        control = controls[source_step]
        commands = control["ordered_commands"]
        intents = application["ordered_intents"]
        exact(control["phase"], RAISE_BODY_PHASE, "ACTUATION_CONTROL_PHASE")
        exact(
            tuple(str(value["joint_id"]) for value in commands),
            JOINTS,
            "ACTUATION_COMMAND_ORDER",
        )
        exact(
            tuple(str(value["joint_id"]) for value in intents),
            JOINTS,
            "ACTUATION_INTENT_ORDER",
        )
        exact(
            {float(value["maximum_target_speed_rad_s"]) for value in commands},
            {observed_speed_rad_s},
            "ACTUATION_COMMAND_SPEED",
        )
        target_trajectory.append(
            [float(value["target_position_rad"]) for value in commands]
        )
        source_velocities = [
            float(value["velocity_rad_s"])
            for value in source["state"]["ordered_joint_observations"]
        ]
        source_positions = [
            float(value["position_rad"])
            for value in source["state"]["ordered_joint_observations"]
        ]
        post_joints = post["state"]["ordered_joint_observations"]
        exact(
            tuple(str(value["joint_id"]) for value in post_joints),
            JOINTS,
            "ACTUATION_POST_JOINT_ORDER",
        )
        for index, intent in enumerate(intents):
            source_velocity = source_velocities[index]
            exact(
                float(intent["measured_pre_step_relative_velocity_rad_s"]),
                source_velocity,
                "ACTUATION_SOURCE_VELOCITY",
            )
            target_velocity = float(intent["canonical_target_velocity_rad_s"])
            if target_velocity_rule == "require_speed_ceiling_saturated":
                exact(
                    abs(target_velocity),
                    observed_speed_rad_s,
                    "ACTUATION_TARGET_SPEED",
                )
                speed_ceiling_saturated_projection_count += 1
            else:
                target_position = float(commands[index]["target_position_rad"])
                unclamped_target_velocity = (
                    target_position - source_positions[index]
                ) / float(raw["outer_step_duration_s"])
                expected_target_velocity = max(
                    -observed_speed_rad_s,
                    min(observed_speed_rad_s, unclamped_target_velocity),
                )
                exact(
                    target_velocity,
                    expected_target_velocity,
                    "ACTUATION_POSITION_ERROR_TARGET_SPEED",
                )
                speed_ceiling_saturated_projection_count += int(
                    abs(expected_target_velocity) == observed_speed_rad_s
                )
            predicted_velocity = float(
                intent["joint_space_solve_projection"][
                    "predicted_relative_velocity_rad_s"
                ]
            )
            post_velocity = float(post_joints[index]["velocity_rad_s"])
            immediate_delta = predicted_velocity - source_velocity
            require(immediate_delta != 0.0, "ACTUATION_IMMEDIATE_DELTA")
            post_delta = post_velocity - source_velocity
            absolute_post_solver_delta_retention_ratios.append(
                abs(post_delta / immediate_delta)
            )
            absolute_post_solver_speed_to_command_ratios.append(
                abs(post_velocity / target_velocity)
            )
            source_error = abs(target_velocity - source_velocity)
            post_error = abs(target_velocity - post_velocity)
            post_solver_helpful_count += int(post_error < source_error)
            post_solver_nonhelpful_count += int(post_error >= source_error)
            maximum_immediate_target_velocity_residual = max(
                maximum_immediate_target_velocity_residual,
                abs(predicted_velocity - target_velocity),
            )
            absolute_impulse_sum += abs(
                float(intent["applied_signed_joint_impulse_nms"])
            )

        population = application[
            "joint_space_effective_inertia_population_guard_projection"
        ]
        maximum_solution_to_cap_ratio = max(
            maximum_solution_to_cap_ratio,
            float(population["maximum_solution_to_published_cap_ratio"]),
        )
        positive_common_scale_count += int(
            float(population["nominal_composed_common_scale"]) > 0.0
        )
        representation_zero_hold_count += int(
            bool(population["representation_zero_hold"])
        )
        joint_target_crossing_count += int(application["joint_target_crossing_count"])
        body_impulse_write_count += int(application["body_impulse_write_count"])

        receipt = candidate["portable_step_receipts"][semantic_step - 1]
        classification = receipt["classification"]
        all_four_bearing_count += int(
            bool(classification["all_four_distal_sites_bearing"])
        )
        nonfoot_contact_count += int(bool(classification["any_nonfoot_contact"]))
        phase_step = int(control["phase_step"])
        if phase_step >= raise_body_ramp_steps:
            exact(
                target_trajectory[-1],
                [0.0] * len(JOINTS),
                "SETTLED_ZERO_TARGETS",
            )
            ordinary, foot_impulses = _foot_impulses(post)
            require(all(ordinary), "SETTLED_FOUR_ORDINARY_CONTACTS")
            body_clearances = post["ordered_body_clearance_observations"]
            torso = next(
                value for value in body_clearances if value["body_id"] == "torso"
            )
            foot_total = sum(foot_impulses)
            torso_impulse = float(torso["accumulated_nonfoot_normal_impulse_ns"])
            nonfoot_total = sum(
                float(value["accumulated_nonfoot_normal_impulse_ns"])
                for value in body_clearances
            )
            require(foot_total > 0.0 and torso_impulse > 0.0, "SETTLED_LOAD_PATH")
            settled_semantic_steps.append(semantic_step)
            settled_foot_impulse_totals.append(foot_total)
            settled_torso_impulses.append(torso_impulse)
            settled_nonfoot_impulse_totals.append(nonfoot_total)
            settled_foot_shares.append(foot_total / (foot_total + torso_impulse))
            settled_all_load_foot_shares.append(
                foot_total / (foot_total + nonfoot_total)
            )
            settled_com_heights.append(
                float(post["center_of_mass"]["position_world_m"]["y"])
            )
            for index, joint in enumerate(post_joints):
                settled_joint_positions[index].append(float(joint["position_rad"]))

    exact(settled_semantic_steps, list(range(400, 640)), "SETTLED_STEPS")
    result = {
        "gate_id": expected_gate_id,
        "observed_raise_body_maximum_target_speed_rad_s": observed_speed_rad_s,
        "raise_body_application_count": len(applications),
        "joint_projection_count": len(absolute_post_solver_delta_retention_ratios),
        "target_trajectory": target_trajectory,
        "total_absolute_applied_joint_impulse_nms": absolute_impulse_sum,
        "maximum_solution_to_published_cap_ratio": maximum_solution_to_cap_ratio,
        "maximum_immediate_target_velocity_residual_rad_s": (
            maximum_immediate_target_velocity_residual
        ),
        "mean_absolute_post_solver_delta_retention_ratio": (
            sum(absolute_post_solver_delta_retention_ratios)
            / len(absolute_post_solver_delta_retention_ratios)
        ),
        "maximum_absolute_post_solver_delta_retention_ratio": max(
            absolute_post_solver_delta_retention_ratios
        ),
        "mean_absolute_post_solver_speed_to_command_ratio": (
            sum(absolute_post_solver_speed_to_command_ratios)
            / len(absolute_post_solver_speed_to_command_ratios)
        ),
        "maximum_absolute_post_solver_speed_to_command_ratio": max(
            absolute_post_solver_speed_to_command_ratios
        ),
        "post_solver_helpful_joint_projection_count": post_solver_helpful_count,
        "post_solver_nonhelpful_joint_projection_count": post_solver_nonhelpful_count,
        "positive_common_scale_count": positive_common_scale_count,
        "representation_zero_hold_count": representation_zero_hold_count,
        "joint_target_crossing_count": joint_target_crossing_count,
        "body_impulse_write_count": body_impulse_write_count,
        "all_four_bearing_step_count": all_four_bearing_count,
        "nonfoot_contact_step_count": nonfoot_contact_count,
        "settled_zero_target_window": {
            "selection_rule": "controller_authored_raise_body_phase_step_at_or_after_raise_body_ramp_steps",
            "semantic_step_first": settled_semantic_steps[0],
            "semantic_step_last": settled_semantic_steps[-1],
            "step_count": len(settled_semantic_steps),
            "mean_foot_bearing_impulse_total_ns": (
                sum(settled_foot_impulse_totals) / len(settled_foot_impulse_totals)
            ),
            "mean_torso_nonfoot_normal_impulse_ns": (
                sum(settled_torso_impulses) / len(settled_torso_impulses)
            ),
            "mean_total_nonfoot_normal_impulse_ns": (
                sum(settled_nonfoot_impulse_totals)
                / len(settled_nonfoot_impulse_totals)
            ),
            "mean_non_torso_nonfoot_normal_impulse_ns": (
                sum(
                    total - torso
                    for total, torso in zip(
                        settled_nonfoot_impulse_totals, settled_torso_impulses
                    )
                )
                / len(settled_nonfoot_impulse_totals)
            ),
            "mean_foot_share_of_foot_plus_torso_impulse": (
                sum(settled_foot_shares) / len(settled_foot_shares)
            ),
            "mean_foot_share_of_foot_plus_all_nonfoot_impulse": (
                sum(settled_all_load_foot_shares) / len(settled_all_load_foot_shares)
            ),
            "center_of_mass_height_range_m": (
                max(settled_com_heights) - min(settled_com_heights)
            ),
            "summed_per_joint_position_range_rad": sum(
                max(values) - min(values) for values in settled_joint_positions
            ),
            "final_center_of_mass_height_m": settled_com_heights[-1],
            "final_joint_positions_rad": [
                values[-1] for values in settled_joint_positions
            ],
            "ordered_torso_impulses_ns": settled_torso_impulses,
        },
    }
    if target_velocity_rule == "exact_position_error_clamp":
        result.update(
            {
                "canonical_target_velocity_rule": target_velocity_rule,
                "speed_ceiling_saturated_projection_count": (
                    speed_ceiling_saturated_projection_count
                ),
                "position_error_limited_projection_count": (
                    len(absolute_post_solver_delta_retention_ratios)
                    - speed_ceiling_saturated_projection_count
                ),
            }
        )
    return result


def _selected_raise_body_speed_projection(
    raw: dict[str, Any], selected_speed_rad_s: float
) -> dict[str, Any]:
    """Re-solve retained source states at one selected speed without application."""

    candidate = raw["candidate_arm"]
    observations = _semantic_index(
        candidate["trace_v3"]["observations"], "SELECTED_OBS"
    )
    controls = _semantic_index(
        candidate["planned_control_receipts"], "SELECTED_CONTROL"
    )
    applications = [
        value
        for value in candidate["command_application_receipts"]
        if value["phase"] == RAISE_BODY_PHASE
    ]
    duration = float(raw["outer_step_duration_s"])
    maximum_solution_to_cap_ratio = 0.0
    maximum_solve_residual = 0.0
    maximum_body_angular_speed = 0.0
    minimum_projection_headroom = math.inf
    speed_ceiling_saturated_projection_count = 0
    per_actuator_cap_ratio_maximum = [0.0] * len(JOINTS)

    for application in applications:
        source_step = int(application["source_control_semantic_step"])
        source = observations[source_step]
        control = controls[source_step]
        commands = control["ordered_commands"]
        positions = _ordered_joint_positions(source)
        targets = [float(value["target_position_rad"]) for value in commands]
        population = application[
            "joint_space_effective_inertia_population_guard_projection"
        ]
        joint_projections = population["ordered_joint_solve_projections"]
        reconstructed = [
            float(value["reconstructed_source_relative_velocity_rad_s"])
            for value in joint_projections
        ]
        target_velocities: list[float] = []
        for index in range(len(JOINTS)):
            unclamped = (targets[index] - positions[index]) / duration
            require(unclamped != 0.0 and math.isfinite(unclamped), "SELECTED_UNCLAMPED")
            target_velocities.append(
                max(-selected_speed_rad_s, min(selected_speed_rad_s, unclamped))
            )
            speed_ceiling_saturated_projection_count += int(
                abs(unclamped) > selected_speed_rad_s
            )
        right_hand_side = [
            target_velocities[index] - reconstructed[index]
            for index in range(len(JOINTS))
        ]
        solution = _solve_from_cholesky(
            population["cholesky_lower_factor"], right_hand_side
        )
        matrix = [
            [float(value) for value in row]
            for row in population["symmetric_response_matrix"]
        ]
        reconstructed_delta = [
            sum(matrix[row][column] * solution[column] for column in range(len(JOINTS)))
            for row in range(len(JOINTS))
        ]
        maximum_solve_residual = max(
            maximum_solve_residual,
            max(
                abs(reconstructed_delta[index] - right_hand_side[index])
                for index in range(len(JOINTS))
            ),
        )
        caps = [
            float(value["published_maximum_outer_step_impulse_nms"])
            for value in joint_projections
        ]
        for index, impulse in enumerate(solution):
            ratio = abs(impulse) / caps[index]
            maximum_solution_to_cap_ratio = max(maximum_solution_to_cap_ratio, ratio)
            per_actuator_cap_ratio_maximum[index] = max(
                per_actuator_cap_ratio_maximum[index], ratio
            )

        bodies = population["body_guard_population_projection"][
            "ordered_body_projections"
        ]
        aggregate = {str(body["body_id"]): [0.0, 0.0, 0.0] for body in bodies}
        for index, impulse in enumerate(solution):
            angular_impulse = _scale(
                _vector(joint_projections[index]["axis_world"]), impulse
            )
            parent = str(joint_projections[index]["parent_body_id"])
            child = str(joint_projections[index]["child_body_id"])
            aggregate[parent] = _add(aggregate[parent], _scale(angular_impulse, -1.0))
            aggregate[child] = _add(aggregate[child], angular_impulse)
        target_limit = float(
            population["inner_projection_target"]["projection_target_limit_rad_s"]
        )
        for body in bodies:
            predicted = _add(
                _vector(body["source_angular_velocity_world_rad_s"]),
                _basis_multiply(
                    body["inverse_inertia_tensor_world_kg_inv_m2"],
                    aggregate[str(body["body_id"])],
                ),
            )
            speed = math.sqrt(sum(component * component for component in predicted))
            maximum_body_angular_speed = max(maximum_body_angular_speed, speed)
            minimum_projection_headroom = min(
                minimum_projection_headroom, target_limit - speed
            )

    return {
        "projection_kind": "same_600_immutable_r121_raise_body_source_states_float64_joint_space_solve_without_binary32_application_or_new_trajectory",
        "source_state_count": len(applications),
        "joint_projection_count": len(applications) * len(JOINTS),
        "selected_maximum_target_speed_rad_s": selected_speed_rad_s,
        "speed_ceiling_saturated_projection_count": speed_ceiling_saturated_projection_count,
        "maximum_solve_residual_rad_s": maximum_solve_residual,
        "per_actuator_maximum_solution_to_published_cap_ratio": per_actuator_cap_ratio_maximum,
        "maximum_solution_to_published_cap_ratio": maximum_solution_to_cap_ratio,
        "all_solutions_inside_unchanged_published_caps": (
            maximum_solution_to_cap_ratio < 1.0
        ),
        "maximum_full_scale_predicted_body_angular_speed_rad_s": (
            maximum_body_angular_speed
        ),
        "minimum_projection_target_headroom_rad_s": minimum_projection_headroom,
        "all_predicted_bodies_inside_unchanged_projection_target": (
            minimum_projection_headroom > 0.0
        ),
        "binary32_representation_or_application_projected": False,
        "new_physical_trajectory_projected": False,
    }


def raise_body_actuation_comparison_projection(
    r118_raw: dict[str, Any],
    r121_raw: dict[str, Any],
    *,
    observed_r118_speed_rad_s: float,
    observed_r121_speed_rad_s: float,
    selected_successor_speed_rad_s: float,
    raise_body_ramp_steps: int,
) -> dict[str, Any]:
    """Compare immutable R118/R121 load transfer and select a bounded probe."""

    exact(r118_raw["seed"], r121_raw["seed"], "ACTUATION_SHARED_SEED")
    exact(
        r118_raw["threshold_profile_sha256"],
        r121_raw["threshold_profile_sha256"],
        "ACTUATION_SHARED_THRESHOLDS",
    )
    exact(
        r118_raw["outer_step_duration_s"],
        r121_raw["outer_step_duration_s"],
        "ACTUATION_SHARED_DURATION",
    )
    r118_candidate = r118_raw["candidate_arm"]
    r121_candidate = r121_raw["candidate_arm"]
    exact(
        r118_candidate["declared_initial_state_sha256"],
        r121_candidate["declared_initial_state_sha256"],
        "ACTUATION_SHARED_INITIAL_STATE",
    )
    exact(
        r118_candidate["initializer_manifest_sha256"],
        r121_candidate["initializer_manifest_sha256"],
        "ACTUATION_SHARED_INITIALIZER",
    )
    r118_observations = _semantic_index(
        r118_candidate["trace_v3"]["observations"], "ACTUATION_R118_OBS"
    )
    r121_observations = _semantic_index(
        r121_candidate["trace_v3"]["observations"], "ACTUATION_R121_OBS"
    )
    for field in (
        "state",
        "center_of_mass",
        "ordered_foot_bearing_observations",
        "ordered_body_clearance_observations",
        "energy_balance",
        "external_interventions",
    ):
        exact(
            r118_observations[39][field],
            r121_observations[39][field],
            f"ACTUATION_SHARED_HANDOFF:{field}",
        )

    r118 = _raise_body_observed_actuation_projection(
        r118_raw,
        expected_gate_id="QSDK-R24D118",
        observed_speed_rad_s=observed_r118_speed_rad_s,
        raise_body_ramp_steps=raise_body_ramp_steps,
    )
    r121 = _raise_body_observed_actuation_projection(
        r121_raw,
        expected_gate_id="QSDK-R24D121",
        observed_speed_rad_s=observed_r121_speed_rad_s,
        raise_body_ramp_steps=raise_body_ramp_steps,
    )
    exact(r118["target_trajectory"], r121["target_trajectory"], "ACTUATION_TARGETS")
    r118_settled = r118["settled_zero_target_window"]
    r121_settled = r121["settled_zero_target_window"]
    r118_torso = r118_settled.pop("ordered_torso_impulses_ns")
    r121_torso = r121_settled.pop("ordered_torso_impulses_ns")
    exact(len(r118_torso), len(r121_torso), "ACTUATION_SETTLED_PAIR_COUNT")
    zero_reaction_speeds: list[float] = []
    for r118_impulse, r121_impulse in zip(r118_torso, r121_torso):
        require(
            r118_impulse > r121_impulse > 0.0,
            "ACTUATION_MONOTONE_TORSO_LOAD_TRANSFER",
        )
        zero_reaction_speeds.append(
            observed_r118_speed_rad_s
            + r118_impulse
            * (observed_r121_speed_rad_s - observed_r118_speed_rad_s)
            / (r118_impulse - r121_impulse)
        )
    selected_by_rule = float(math.ceil(max(zero_reaction_speeds)))
    exact(
        selected_successor_speed_rad_s,
        selected_by_rule,
        "ACTUATION_SELECTED_SPEED_RULE",
    )
    r118.pop("target_trajectory")
    r121.pop("target_trajectory")
    final_joint_difference = max(
        abs(left - right)
        for left, right in zip(
            r118_settled["final_joint_positions_rad"],
            r121_settled["final_joint_positions_rad"],
        )
    )
    return {
        "controlled_comparison": {
            "seed": int(r118_raw["seed"]),
            "threshold_profile_sha256": str(r118_raw["threshold_profile_sha256"]),
            "outer_step_duration_s": float(r118_raw["outer_step_duration_s"]),
            "candidate_initial_state_sha256": str(
                r118_candidate["declared_initial_state_sha256"]
            ),
            "initializer_manifest_sha256": str(
                r118_candidate["initializer_manifest_sha256"]
            ),
            "r118_controller_id": str(r118_raw["recovery_controller_id"]),
            "r121_controller_id": str(r121_raw["recovery_controller_id"]),
            "support_handoff_physical_fields_exact": True,
            "raise_body_target_trajectory_exact": True,
            "changed_controller_parameter": "stance_pose.maximum_target_speed_rad_s",
        },
        "r118_observed": r118,
        "r121_observed": r121,
        "observed_cross_run_effect": {
            "absolute_applied_joint_impulse_ratio_r121_to_r118": (
                r121["total_absolute_applied_joint_impulse_nms"]
                / r118["total_absolute_applied_joint_impulse_nms"]
            ),
            "settled_foot_load_ratio_r121_to_r118": (
                r121_settled["mean_foot_bearing_impulse_total_ns"]
                / r118_settled["mean_foot_bearing_impulse_total_ns"]
            ),
            "settled_torso_load_reduction_ns": (
                r118_settled["mean_torso_nonfoot_normal_impulse_ns"]
                - r121_settled["mean_torso_nonfoot_normal_impulse_ns"]
            ),
            "settled_foot_load_increase_ns": (
                r121_settled["mean_foot_bearing_impulse_total_ns"]
                - r118_settled["mean_foot_bearing_impulse_total_ns"]
            ),
            "maximum_final_joint_position_difference_rad": final_joint_difference,
            "final_center_of_mass_height_difference_m": (
                r121_settled["final_center_of_mass_height_m"]
                - r118_settled["final_center_of_mass_height_m"]
            ),
            "interpretation": "larger_pre_solver_impulse_shifted_native_contact_load_from_torso_to_feet_but_post_solver_joint_motion_and_body_lift_remained_negligible",
        },
        "selected_successor_input": {
            "selection_rule": "next_integer_rad_s_above_maximum_per_step_two_point_affine_zero_torso_reaction_extrapolation_in_controller_authored_settled_zero_target_window",
            "settled_paired_state_count": len(zero_reaction_speeds),
            "descriptive_zero_torso_reaction_speed_minimum_rad_s": min(
                zero_reaction_speeds
            ),
            "descriptive_zero_torso_reaction_speed_maximum_rad_s": max(
                zero_reaction_speeds
            ),
            "descriptive_zero_torso_reaction_speed_mean_rad_s": (
                sum(zero_reaction_speeds) / len(zero_reaction_speeds)
            ),
            "selected_raise_body_maximum_target_speed_rad_s": selected_by_rule,
            "selection_adequate_only_for_bounded_development_probe": True,
            "affine_contact_response_or_lift_claimed": False,
            "trajectory_or_standing_success_predicted": False,
        },
        "selected_speed_retained_state_float64_projection": (
            _selected_raise_body_speed_projection(
                r121_raw, selected_successor_speed_rad_s
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


def _false_intervals(rows: list[tuple[int, bool]]) -> list[dict[str, int]]:
    """Return compact contiguous intervals where one measured predicate is false."""

    require(bool(rows), "FALSE_INTERVAL_ROWS")
    exact(
        [step for step, _ in rows],
        list(range(rows[0][0], rows[0][0] + len(rows))),
        "FALSE_INTERVAL_STEP_ORDER",
    )
    intervals: list[dict[str, int]] = []
    start: int | None = None
    for step, value in rows:
        if not value and start is None:
            start = step
        if value and start is not None:
            intervals.append(
                {
                    "semantic_step_first": start,
                    "semantic_step_last": step - 1,
                    "step_count": step - start,
                }
            )
            start = None
    if start is not None:
        terminal = rows[-1][0]
        intervals.append(
            {
                "semantic_step_first": start,
                "semantic_step_last": terminal,
                "step_count": terminal - start + 1,
            }
        )
    return intervals


def _raise_body_contact_response_projection(raw: dict[str, Any]) -> dict[str, Any]:
    """Project compact contact transitions and terminal nonfoot contact state."""

    candidate = raw["candidate_arm"]
    observations = _semantic_index(
        candidate["trace_v3"]["observations"], "CONTACT_RESPONSE_OBSERVATION"
    )
    receipts = candidate["portable_step_receipts"]
    raise_receipts = [
        value for value in receipts if value["prior_phase"] == RAISE_BODY_PHASE
    ]
    exact(len(raise_receipts), 600, "CONTACT_RESPONSE_RAISE_COUNT")
    ordinary_rows: list[tuple[int, bool]] = []
    bearing_rows: list[tuple[int, bool]] = []
    contact_histogram: dict[str, int] = {}
    for receipt in raise_receipts:
        semantic_step = int(receipt["memory"]["last_semantic_step"])
        observation = observations[semantic_step]
        ordinary, _ = _foot_impulses(observation)
        simultaneous = sum(ordinary)
        key = str(simultaneous)
        contact_histogram[key] = contact_histogram.get(key, 0) + 1
        ordinary_rows.append((semantic_step, all(ordinary)))
        bearing_rows.append(
            (
                semantic_step,
                bool(receipt["classification"]["all_four_distal_sites_bearing"]),
            )
        )
    exact(
        [step for step, _ in ordinary_rows],
        list(range(40, 640)),
        "CONTACT_RESPONSE_RAISE_STEPS",
    )
    terminal = observations[ordinary_rows[-1][0]]
    terminal_nonfoot = [
        {
            "body_id": str(value["body_id"]),
            "nonfoot_contact_present": bool(value["nonfoot_contact_present"]),
            "accumulated_nonfoot_normal_impulse_ns": float(
                value["accumulated_nonfoot_normal_impulse_ns"]
            ),
            "minimum_nonfoot_clearance_m": float(
                value["minimum_nonfoot_clearance_m"]
            ),
        }
        for value in terminal["ordered_body_clearance_observations"]
        if bool(value["nonfoot_contact_present"])
    ]
    return {
        "raise_body_semantic_step_first": ordinary_rows[0][0],
        "raise_body_semantic_step_last": ordinary_rows[-1][0],
        "raise_body_step_count": len(ordinary_rows),
        "simultaneous_ordinary_distal_contact_histogram": contact_histogram,
        "all_four_ordinary_contact_step_count": sum(value for _, value in ordinary_rows),
        "all_four_bearing_step_count": sum(value for _, value in bearing_rows),
        "all_four_ordinary_contact_loss_intervals": _false_intervals(ordinary_rows),
        "all_four_bearing_loss_intervals": _false_intervals(bearing_rows),
        "terminal_all_four_ordinary_contact": ordinary_rows[-1][1],
        "terminal_all_four_bearing": bearing_rows[-1][1],
        "terminal_active_nonfoot_contacts": terminal_nonfoot,
    }


def _candidate_safety_component_projection(
    raw: dict[str, Any], *, frozen_maximum_energy_balance_residual_j: float
) -> dict[str, Any]:
    """Reconstruct frozen safety components over one immutable candidate trace."""

    candidate = raw["candidate_arm"]
    observations = candidate["trace_v3"]["observations"]
    receipts = candidate["portable_step_receipts"]
    exact(len(observations), len(receipts), "SAFETY_TRACE_STEP_COUNT")
    exact(
        [int(value["semantic_step"]) for value in observations],
        list(range(1, len(observations) + 1)),
        "SAFETY_TRACE_STEP_ORDER",
    )
    rows: list[dict[str, Any]] = []
    for observation, receipt in zip(observations, receipts):
        classification = receipt["classification"]
        residual = float(classification["energy_balance_residual_j"])
        require(math.isfinite(residual) and residual >= 0.0, "SAFETY_ENERGY_RESIDUAL")
        rows.append(
            {
                "semantic_step": int(observation["semantic_step"]),
                "prior_phase": str(receipt["prior_phase"]),
                "joint_limits": bool(classification["joint_limits_respected"]),
                "actuator_budget": bool(classification["actuator_budget_respected"]),
                "forbidden_contact": float(
                    classification["maximum_nonfoot_contact_impulse_ns"]
                )
                <= 0.0,
                "energy": residual <= frozen_maximum_energy_balance_residual_j,
                "energy_residual_j": residual,
                "safety_gate": bool(classification["safety_gate"]),
                "no_cheat_gate": bool(classification["no_cheat_gate"]),
            }
        )
    energy_failures = [value for value in rows if not value["energy"]]
    require(bool(energy_failures), "SAFETY_ENERGY_FAILURE_REQUIRED")
    first_energy_failure = energy_failures[0]
    first_raise = next(value for value in rows if value["prior_phase"] == RAISE_BODY_PHASE)
    return {
        "semantic_step_first": rows[0]["semantic_step"],
        "semantic_step_last": rows[-1]["semantic_step"],
        "step_count": len(rows),
        "frozen_maximum_energy_balance_residual_j": (
            frozen_maximum_energy_balance_residual_j
        ),
        "joint_limit_component_pass_count": sum(value["joint_limits"] for value in rows),
        "actuator_budget_component_pass_count": sum(
            value["actuator_budget"] for value in rows
        ),
        "forbidden_contact_component_pass_count": sum(
            value["forbidden_contact"] for value in rows
        ),
        "energy_component_pass_count": sum(value["energy"] for value in rows),
        "safety_gate_pass_count": sum(value["safety_gate"] for value in rows),
        "no_cheat_gate_pass_count": sum(value["no_cheat_gate"] for value in rows),
        "first_energy_component_failure_semantic_step": first_energy_failure[
            "semantic_step"
        ],
        "first_energy_component_failure_residual_j": first_energy_failure[
            "energy_residual_j"
        ],
        "energy_component_recovered_after_first_failure": any(
            value["energy"]
            for value in rows[first_energy_failure["semantic_step"] :]
        ),
        "first_raise_body_semantic_step": first_raise["semantic_step"],
        "energy_component_passed_at_raise_body_entry": first_raise["energy"],
        "energy_balance_residual_at_raise_body_entry_j": first_raise[
            "energy_residual_j"
        ],
        "terminal_energy_balance_residual_j": rows[-1]["energy_residual_j"],
    }


def raise_body_v4_v5_response_and_safety_projection(
    r121_raw: dict[str, Any],
    r124_raw: dict[str, Any],
    *,
    observed_r121_speed_rad_s: float,
    observed_r124_speed_rad_s: float,
    raise_body_ramp_steps: int,
    frozen_maximum_energy_balance_residual_j: float,
) -> dict[str, Any]:
    """Compare immutable V4/V5 response and expose the latent safety block."""

    for field, code in (
        ("seed", "V4_V5_SHARED_SEED"),
        ("threshold_profile_sha256", "V4_V5_SHARED_THRESHOLDS"),
        ("outer_step_duration_s", "V4_V5_SHARED_DURATION"),
    ):
        exact(r121_raw[field], r124_raw[field], code)
    r121_candidate = r121_raw["candidate_arm"]
    r124_candidate = r124_raw["candidate_arm"]
    for field, code in (
        ("declared_initial_state_sha256", "V4_V5_SHARED_INITIAL_STATE"),
        ("initializer_manifest_sha256", "V4_V5_SHARED_INITIALIZER"),
    ):
        exact(r121_candidate[field], r124_candidate[field], code)
    r121_observations = _semantic_index(
        r121_candidate["trace_v3"]["observations"], "V4_V5_R121_OBSERVATION"
    )
    r124_observations = _semantic_index(
        r124_candidate["trace_v3"]["observations"], "V4_V5_R124_OBSERVATION"
    )
    physical_fields = (
        "state",
        "center_of_mass",
        "ordered_foot_bearing_observations",
        "ordered_body_clearance_observations",
        "energy_balance",
        "external_interventions",
    )
    divergent_steps = [
        semantic_step
        for semantic_step in range(1, 640)
        if any(
            r121_observations[semantic_step][field]
            != r124_observations[semantic_step][field]
            for field in physical_fields
        )
    ]
    require(bool(divergent_steps), "V4_V5_PHYSICAL_DIVERGENCE")

    r121 = _raise_body_observed_actuation_projection(
        r121_raw,
        expected_gate_id="QSDK-R24D121",
        observed_speed_rad_s=observed_r121_speed_rad_s,
        raise_body_ramp_steps=raise_body_ramp_steps,
        target_velocity_rule="exact_position_error_clamp",
    )
    r124 = _raise_body_observed_actuation_projection(
        r124_raw,
        expected_gate_id="QSDK-R24D124",
        observed_speed_rad_s=observed_r124_speed_rad_s,
        raise_body_ramp_steps=raise_body_ramp_steps,
        target_velocity_rule="exact_position_error_clamp",
    )
    exact(r121["target_trajectory"], r124["target_trajectory"], "V4_V5_TARGETS")
    r121.pop("target_trajectory")
    r124.pop("target_trajectory")
    r121_settled = r121["settled_zero_target_window"]
    r124_settled = r124["settled_zero_target_window"]
    r121_settled.pop("ordered_torso_impulses_ns")
    r124_settled.pop("ordered_torso_impulses_ns")

    return {
        "controlled_comparison": {
            "seed": int(r121_raw["seed"]),
            "threshold_profile_sha256": str(r121_raw["threshold_profile_sha256"]),
            "outer_step_duration_s": float(r121_raw["outer_step_duration_s"]),
            "candidate_initial_state_sha256": str(
                r121_candidate["declared_initial_state_sha256"]
            ),
            "initializer_manifest_sha256": str(
                r121_candidate["initializer_manifest_sha256"]
            ),
            "r121_controller_id": str(r121_raw["recovery_controller_id"]),
            "r124_controller_id": str(r124_raw["recovery_controller_id"]),
            "support_handoff_physical_fields_exact": all(
                r121_observations[39][field] == r124_observations[39][field]
                for field in physical_fields
            ),
            "raise_body_target_trajectory_exact": True,
            "first_physical_divergence_semantic_step": divergent_steps[0],
            "changed_controller_parameter": "stance_pose.maximum_target_speed_rad_s",
        },
        "r121_v4_observed": r121,
        "r124_v5_observed": r124,
        "r121_v4_contact_response": _raise_body_contact_response_projection(r121_raw),
        "r124_v5_contact_response": _raise_body_contact_response_projection(r124_raw),
        "observed_cross_run_effect": {
            "absolute_applied_joint_impulse_ratio_v5_to_v4": (
                r124["total_absolute_applied_joint_impulse_nms"]
                / r121["total_absolute_applied_joint_impulse_nms"]
            ),
            "settled_foot_load_ratio_v5_to_v4": (
                r124_settled["mean_foot_bearing_impulse_total_ns"]
                / r121_settled["mean_foot_bearing_impulse_total_ns"]
            ),
            "settled_torso_load_reduction_ns": (
                r121_settled["mean_torso_nonfoot_normal_impulse_ns"]
                - r124_settled["mean_torso_nonfoot_normal_impulse_ns"]
            ),
            "settled_total_nonfoot_load_reduction_ns": (
                r121_settled["mean_total_nonfoot_normal_impulse_ns"]
                - r124_settled["mean_total_nonfoot_normal_impulse_ns"]
            ),
            "terminal_center_of_mass_height_difference_m_v5_minus_v4": (
                r124_settled["final_center_of_mass_height_m"]
                - r121_settled["final_center_of_mass_height_m"]
            ),
            "v5_settled_center_of_mass_height_range_m": r124_settled[
                "center_of_mass_height_range_m"
            ],
            "v5_settled_summed_per_joint_position_range_rad": r124_settled[
                "summed_per_joint_position_range_rad"
            ],
            "future_horizon_or_trajectory_projected": False,
        },
        "r121_v4_safety_components": _candidate_safety_component_projection(
            r121_raw,
            frozen_maximum_energy_balance_residual_j=(
                frozen_maximum_energy_balance_residual_j
            ),
        ),
        "r124_v5_safety_components": _candidate_safety_component_projection(
            r124_raw,
            frozen_maximum_energy_balance_residual_j=(
                frozen_maximum_energy_balance_residual_j
            ),
        ),
        "execution_counts": {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
    }


def raise_body_v4_v5_compact_summary(
    projection: dict[str, Any],
) -> dict[str, Any]:
    """Keep the durable diagnosis readable while the full projection stays hashed."""

    def observed(
        actuation_key: str, contact_key: str, safety_key: str
    ) -> dict[str, Any]:
        actuation = projection[actuation_key]
        settled = actuation["settled_zero_target_window"]
        return {
            "observed_raise_body_maximum_target_speed_rad_s": actuation[
                "observed_raise_body_maximum_target_speed_rad_s"
            ],
            "total_absolute_applied_joint_impulse_nms": actuation[
                "total_absolute_applied_joint_impulse_nms"
            ],
            "maximum_solution_to_published_cap_ratio": actuation[
                "maximum_solution_to_published_cap_ratio"
            ],
            "mean_absolute_post_solver_delta_retention_ratio": actuation[
                "mean_absolute_post_solver_delta_retention_ratio"
            ],
            "speed_ceiling_saturated_projection_count": actuation[
                "speed_ceiling_saturated_projection_count"
            ],
            "position_error_limited_projection_count": actuation[
                "position_error_limited_projection_count"
            ],
            "settled_zero_target_window": {
                "semantic_step_first": settled["semantic_step_first"],
                "semantic_step_last": settled["semantic_step_last"],
                "step_count": settled["step_count"],
                "mean_foot_bearing_impulse_total_ns": settled[
                    "mean_foot_bearing_impulse_total_ns"
                ],
                "mean_torso_nonfoot_normal_impulse_ns": settled[
                    "mean_torso_nonfoot_normal_impulse_ns"
                ],
                "mean_total_nonfoot_normal_impulse_ns": settled[
                    "mean_total_nonfoot_normal_impulse_ns"
                ],
                "mean_foot_share_of_foot_plus_all_nonfoot_impulse": settled[
                    "mean_foot_share_of_foot_plus_all_nonfoot_impulse"
                ],
                "center_of_mass_height_range_m": settled[
                    "center_of_mass_height_range_m"
                ],
                "summed_per_joint_position_range_rad": settled[
                    "summed_per_joint_position_range_rad"
                ],
                "final_center_of_mass_height_m": settled[
                    "final_center_of_mass_height_m"
                ],
            },
            "contact_response": projection[contact_key],
            "safety_components": projection[safety_key],
        }

    return {
        "controlled_comparison": projection["controlled_comparison"],
        "r121_v4": observed(
            "r121_v4_observed",
            "r121_v4_contact_response",
            "r121_v4_safety_components",
        ),
        "r124_v5": observed(
            "r124_v5_observed",
            "r124_v5_contact_response",
            "r124_v5_safety_components",
        ),
        "observed_cross_run_effect": projection["observed_cross_run_effect"],
        "execution_counts": projection["execution_counts"],
    }


def validate_load_path_diagnosis(
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
    next_required_key: str,
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
        "DIAGNOSIS",
    )
    projection = recovery_load_path_projection(
        _load_bound_physical_raw(root, diagnosis["predecessor"], "PREDECESSOR"),
        frozen_bearing_minimum_ns=float(
            diagnosis["method"]["frozen_minimum_distal_bearing_impulse_ns"]
        ),
        observed_maximum_target_speed_rad_s=float(
            diagnosis["method"]["observed_maximum_target_speed_rad_s"]
        ),
    )
    encoded = canonical_bytes(projection)
    exact(
        (len(encoded), sha256(encoded)),
        (
            diagnosis["computed_projection_canonical_byte_length"],
            diagnosis["computed_projection_canonical_sha256"],
        ),
        "PROJECTION_IDENTITY",
    )
    exact(projection, diagnosis["computed_projection"], "PROJECTION")
    for binding in diagnosis["source_bindings"]:
        source = verify_source_binding(
            root, str(binding["source_commit"]), binding
        ).decode("utf-8")
        require(
            all(str(marker) in source for marker in binding["required_utf8_markers"]),
            f"SOURCE_MARKERS:{binding['path']}",
        )
    verify_exact_paths(
        diagnosis,
        {
            "decision.predecessor_same_identity_rerun_permitted": False,
            "decision.next_zero_world_implementation_authorized": True,
            "decision.physical_execution_authorized": False,
            "decision.historical_result_rewritten": False,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "next_boundary.gate_id": next_gate_id,
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_build_count": 0,
            "claim_boundary.trajectory_prediction_claimed": False,
            "claim_boundary.behavior_improvement_claimed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.release_authority": False,
        },
        "DECISION",
    )
    expected_live = dict(diagnosis["live_authority_projection"])
    expected_live.pop("next_gate_id")
    expected_live.pop(next_required_key)
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
        prefix=f"LIVE_{gate_id.replace('-', '_')}",
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
    **scope: str,
) -> int:
    try:
        diagnosis = validate_load_path_diagnosis(
            root,
            relative_path,
            schema,
            expected_sha256,
            expected_length,
            **scope,
        )
        projection = diagnosis["computed_projection"]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": diagnosis["gate_id"],
                    "ok": True,
                    "status": diagnosis["status"],
                    "all_four_contact_step_count": projection[
                        "candidate_bearing_projection"
                    ]["all_four_ordinary_contact_step_count"],
                    "bearing_gap_ratio": projection[
                        "frozen_bearing_to_observed_peak_weakest_gap_ratio"
                    ],
                    "selected_maximum_target_speed_rad_s": projection[
                        "selected_successor_maximum_target_speed_rad_s"
                    ],
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


def validate_raise_body_load_path_diagnosis(
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
    ignored_forward_live_keys: tuple[str, ...] = (),
) -> dict[str, Any]:
    """Validate a finite support-to-raise diagnosis through shared mechanics."""

    raw_bytes = (root / relative_path).read_bytes()
    exact(
        (len(raw_bytes), "sha256:" + hashlib.sha256(raw_bytes).hexdigest()),
        (expected_length, expected_sha256),
        "RAISE_DIAGNOSIS_IDENTITY",
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
            "ledger_scope.authority_mode": "closed_zero_world_retained_trace_raise_body_load_path_diagnosis",
            "ledger_scope.question_class": "development",
        },
        "RAISE_DIAGNOSIS",
    )
    for binding in diagnosis["bound_json_authorities"]:
        path = root / str(binding["path"])
        payload = path.read_bytes()
        exact(
            (
                len(payload),
                "sha256:" + hashlib.sha256(payload).hexdigest(),
            ),
            (
                int(binding["byte_length"]),
                str(binding["raw_sha256"]),
            ),
            f"BOUND_JSON:{binding['path']}",
        )
        verify_exact_paths(
            json.loads(payload),
            dict(binding["expected_paths"]),
            f"BOUND_JSON_PATHS:{binding['path']}",
        )
    for binding in diagnosis["source_bindings"]:
        source = verify_source_binding(
            root, str(binding["source_commit"]), binding
        ).decode("utf-8")
        require(
            all(str(marker) in source for marker in binding["required_utf8_markers"]),
            f"SOURCE_MARKERS:{binding['path']}",
        )
    projection = raise_body_speed_continuity_projection(
        _load_bound_physical_raw(root, diagnosis["predecessors"]["r24d115"], "R115"),
        _load_bound_physical_raw(root, diagnosis["predecessors"]["r24d118"], "R118"),
        frozen_bearing_minimum_ns=float(
            diagnosis["method"]["frozen_minimum_distal_bearing_impulse_ns"]
        ),
        frozen_minimum_com_height_gain_m=float(
            diagnosis["method"]["frozen_minimum_com_height_gain_m"]
        ),
        frozen_minimum_nonfoot_clearance_m=float(
            diagnosis["method"]["frozen_minimum_nonfoot_clearance_m"]
        ),
        observed_support_speed_rad_s=float(
            diagnosis["method"]["observed_support_maximum_target_speed_rad_s"]
        ),
        observed_raise_body_speed_rad_s=float(
            diagnosis["method"]["observed_raise_body_maximum_target_speed_rad_s"]
        ),
        selected_raise_body_speed_rad_s=float(
            diagnosis["method"]["selected_raise_body_maximum_target_speed_rad_s"]
        ),
    )
    encoded = canonical_bytes(projection)
    exact(
        (len(encoded), sha256(encoded)),
        (
            int(diagnosis["computed_projection_canonical_byte_length"]),
            str(diagnosis["computed_projection_canonical_sha256"]),
        ),
        "RAISE_PROJECTION_IDENTITY",
    )
    exact(projection, diagnosis["computed_projection"], "RAISE_PROJECTION")
    verify_exact_paths(
        diagnosis,
        {
            "decision.r24d115_same_identity_rerun_permitted": False,
            "decision.r24d118_same_identity_rerun_permitted": False,
            "decision.r24d120_zero_world_implementation_authorized": True,
            "decision.physical_execution_authorized": False,
            "decision.historical_result_rewritten": False,
            "decision.historical_threshold_changed": False,
            "decision.historical_evaluator_changed": False,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "next_boundary.gate_id": next_gate_id,
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_build_count": 0,
            "claim_boundary.trajectory_prediction_claimed": False,
            "claim_boundary.behavior_improvement_claimed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.release_authority": False,
        },
        "RAISE_DECISION",
    )
    expected_live = dict(diagnosis["live_authority_projection"])
    expected_live.pop("next_gate_id")
    for key in ignored_forward_live_keys:
        expected_live.pop(key)
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
        prefix=f"LIVE_{gate_id.replace('-', '_')}",
    )
    require((root / str(diagnosis["closure_audit_path"])).is_file(), "AUDIT_PATH")
    return diagnosis


def run_raise_body_load_path_cli(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    pass_marker: str,
    failure_marker: str,
    **scope: str,
) -> int:
    try:
        diagnosis = validate_raise_body_load_path_diagnosis(
            root,
            relative_path,
            schema,
            expected_sha256,
            expected_length,
            **scope,
        )
        projection = diagnosis["computed_projection"]
        boundary = projection["r118_phase_boundary"]
        raise_body = projection["r118_raise_body_observation"]
        selected = projection[
            "selected_raise_body_speed_retained_state_float64_projection"
        ]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": diagnosis["gate_id"],
                    "ok": True,
                    "status": diagnosis["status"],
                    "support_to_raise_speed_ratio": boundary[
                        "maximum_target_speed_ratio_support_to_raise"
                    ],
                    "raise_body_step_count": raise_body["phase_step_count"],
                    "raise_body_all_four_ordinary_contact_step_count": raise_body[
                        "all_four_ordinary_contact_step_count"
                    ],
                    "raise_body_all_four_bearing_step_count": raise_body[
                        "all_four_bearing_step_count"
                    ],
                    "selected_raise_body_speed_rad_s": selected[
                        "selected_maximum_target_speed_rad_s"
                    ],
                    "selected_maximum_solution_to_cap_ratio": selected[
                        "maximum_solution_to_published_cap_ratio"
                    ],
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


def validate_raise_body_actuation_diagnosis(
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
    ignored_forward_live_keys: tuple[str, ...] = (),
) -> dict[str, Any]:
    """Validate one paired retained-trace actuation diagnosis."""

    raw_bytes = (root / relative_path).read_bytes()
    exact(
        (len(raw_bytes), "sha256:" + hashlib.sha256(raw_bytes).hexdigest()),
        (expected_length, expected_sha256),
        "ACTUATION_DIAGNOSIS_IDENTITY",
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
            "ledger_scope.authority_mode": "closed_zero_world_retained_trace_raise_body_actuation_diagnosis",
            "ledger_scope.question_class": "development",
        },
        "ACTUATION_DIAGNOSIS",
    )
    for binding in diagnosis["bound_json_authorities"]:
        path = root / str(binding["path"])
        payload = path.read_bytes()
        exact(
            (len(payload), "sha256:" + hashlib.sha256(payload).hexdigest()),
            (int(binding["byte_length"]), str(binding["raw_sha256"])),
            f"ACTUATION_BOUND_JSON:{binding['path']}",
        )
        verify_exact_paths(
            json.loads(payload),
            dict(binding["expected_paths"]),
            f"ACTUATION_BOUND_JSON_PATHS:{binding['path']}",
        )
    for binding in diagnosis["source_bindings"]:
        source = verify_source_binding(
            root, str(binding["source_commit"]), binding
        ).decode("utf-8")
        require(
            all(str(marker) in source for marker in binding["required_utf8_markers"]),
            f"ACTUATION_SOURCE_MARKERS:{binding['path']}",
        )
    projection = raise_body_actuation_comparison_projection(
        _load_bound_physical_raw(
            root, diagnosis["predecessors"]["r24d118"], "ACTUATION_R118"
        ),
        _load_bound_physical_raw(
            root, diagnosis["predecessors"]["r24d121"], "ACTUATION_R121"
        ),
        observed_r118_speed_rad_s=float(
            diagnosis["method"]["observed_r24d118_raise_body_speed_rad_s"]
        ),
        observed_r121_speed_rad_s=float(
            diagnosis["method"]["observed_r24d121_raise_body_speed_rad_s"]
        ),
        selected_successor_speed_rad_s=float(
            diagnosis["method"]["selected_successor_raise_body_speed_rad_s"]
        ),
        raise_body_ramp_steps=int(diagnosis["method"]["raise_body_ramp_steps"]),
    )
    encoded = canonical_bytes(projection)
    exact(
        (len(encoded), sha256(encoded)),
        (
            int(diagnosis["computed_projection_canonical_byte_length"]),
            str(diagnosis["computed_projection_canonical_sha256"]),
        ),
        "ACTUATION_PROJECTION_IDENTITY",
    )
    exact(projection, diagnosis["computed_projection"], "ACTUATION_PROJECTION")
    verify_exact_paths(
        diagnosis,
        {
            "decision.r24d118_same_identity_rerun_permitted": False,
            "decision.r24d121_same_identity_rerun_permitted": False,
            "decision.r24d123_zero_world_implementation_authorized": True,
            "decision.physical_execution_authorized": False,
            "decision.historical_result_rewritten": False,
            "decision.historical_threshold_changed": False,
            "decision.historical_evaluator_changed": False,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "next_boundary.gate_id": next_gate_id,
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_build_count": 0,
            "claim_boundary.affine_contact_response_claimed": False,
            "claim_boundary.trajectory_prediction_claimed": False,
            "claim_boundary.behavior_improvement_claimed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.release_authority": False,
        },
        "ACTUATION_DECISION",
    )
    expected_live = dict(diagnosis["live_authority_projection"])
    expected_live.pop("next_gate_id")
    for key in ignored_forward_live_keys:
        expected_live.pop(key)
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
        prefix=f"LIVE_{gate_id.replace('-', '_')}",
    )
    require((root / str(diagnosis["closure_audit_path"])).is_file(), "AUDIT_PATH")
    return diagnosis


def run_raise_body_actuation_diagnosis_cli(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    pass_marker: str,
    failure_marker: str,
    **scope: str,
) -> int:
    """Run one thin campaign binding over the reusable actuation diagnosis."""

    try:
        diagnosis = validate_raise_body_actuation_diagnosis(
            root,
            relative_path,
            schema,
            expected_sha256,
            expected_length,
            **scope,
        )
        projection = diagnosis["computed_projection"]
        effect = projection["observed_cross_run_effect"]
        selected = projection["selected_speed_retained_state_float64_projection"]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": diagnosis["gate_id"],
                    "ok": True,
                    "status": diagnosis["status"],
                    "applied_impulse_ratio_r121_to_r118": effect[
                        "absolute_applied_joint_impulse_ratio_r121_to_r118"
                    ],
                    "settled_foot_load_ratio_r121_to_r118": effect[
                        "settled_foot_load_ratio_r121_to_r118"
                    ],
                    "selected_raise_body_speed_rad_s": selected[
                        "selected_maximum_target_speed_rad_s"
                    ],
                    "selected_maximum_solution_to_cap_ratio": selected[
                        "maximum_solution_to_published_cap_ratio"
                    ],
                    "selected_minimum_projection_headroom_rad_s": selected[
                        "minimum_projection_target_headroom_rad_s"
                    ],
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


def validate_raise_body_response_and_energy_authority_diagnosis(
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
    ignored_forward_live_keys: tuple[str, ...] = (),
) -> dict[str, Any]:
    """Validate one compact retained-response and energy-authority diagnosis."""

    raw_bytes = (root / relative_path).read_bytes()
    exact(
        (len(raw_bytes), "sha256:" + hashlib.sha256(raw_bytes).hexdigest()),
        (expected_length, expected_sha256),
        "RESPONSE_DIAGNOSIS_IDENTITY",
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
            "ledger_scope.authority_mode": "closed_zero_world_retained_trace_response_and_energy_authority_diagnosis",
            "ledger_scope.question_class": "development",
        },
        "RESPONSE_DIAGNOSIS",
    )
    bound_payloads: dict[str, dict[str, Any]] = {}
    for binding in diagnosis["bound_json_authorities"]:
        path = root / str(binding["path"])
        payload = path.read_bytes()
        exact(
            (len(payload), "sha256:" + hashlib.sha256(payload).hexdigest()),
            (int(binding["byte_length"]), str(binding["raw_sha256"])),
            f"RESPONSE_BOUND_JSON:{binding['path']}",
        )
        decoded = json.loads(payload)
        bound_payloads[str(binding["path"])] = decoded
        verify_exact_paths(
            decoded,
            dict(binding["expected_paths"]),
            f"RESPONSE_BOUND_JSON_PATHS:{binding['path']}",
        )
    for binding in diagnosis["source_bindings"]:
        source = verify_source_binding(
            root, str(binding["source_commit"]), binding
        ).decode("utf-8")
        require(
            all(str(marker) in source for marker in binding["required_utf8_markers"]),
            f"RESPONSE_SOURCE_MARKERS:{binding['path']}",
        )

    threshold_authority = bound_payloads[
        "sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"
    ]
    energy_thresholds = [
        value
        for value in threshold_authority["threshold_profile"]["thresholds"]
        if value["threshold_id"] == "maximum_energy_balance_residual_j"
    ]
    exact(len(energy_thresholds), 1, "RESPONSE_ENERGY_THRESHOLD_COUNT")
    exact(
        float(energy_thresholds[0]["value"]),
        float(diagnosis["method"]["frozen_maximum_energy_balance_residual_j"]),
        "RESPONSE_ENERGY_THRESHOLD_VALUE",
    )
    exact(
        threshold_authority["threshold_profile"]["post_outcome_rethresholding_permitted"],
        False,
        "RESPONSE_RETHRESHOLDING_AUTHORITY",
    )

    projection = raise_body_v4_v5_response_and_safety_projection(
        _load_bound_physical_raw(
            root, diagnosis["predecessors"]["r24d121"], "RESPONSE_R121"
        ),
        _load_bound_physical_raw(
            root, diagnosis["predecessors"]["r24d124"], "RESPONSE_R124"
        ),
        observed_r121_speed_rad_s=float(
            diagnosis["method"]["observed_r24d121_raise_body_speed_rad_s"]
        ),
        observed_r124_speed_rad_s=float(
            diagnosis["method"]["observed_r24d124_raise_body_speed_rad_s"]
        ),
        raise_body_ramp_steps=int(diagnosis["method"]["raise_body_ramp_steps"]),
        frozen_maximum_energy_balance_residual_j=float(
            diagnosis["method"]["frozen_maximum_energy_balance_residual_j"]
        ),
    )
    encoded = canonical_bytes(projection)
    exact(
        (len(encoded), sha256(encoded)),
        (
            int(diagnosis["computed_projection_canonical_byte_length"]),
            str(diagnosis["computed_projection_canonical_sha256"]),
        ),
        "RESPONSE_PROJECTION_IDENTITY",
    )
    exact(
        raise_body_v4_v5_compact_summary(projection),
        diagnosis["observed_response"],
        "RESPONSE_COMPACT_SUMMARY",
    )
    verify_exact_paths(
        diagnosis,
        {
            "energy_authority_diagnosis.godot_mapping_profile_id": "godot_jolt_r24d57_native_recovery_energy_mapping_v1",
            "energy_authority_diagnosis.constraint_and_passive_partition_complete": False,
            "energy_authority_diagnosis.exact_balance_safety_authority_available": False,
            "energy_authority_diagnosis.residual_balancing_permitted": False,
            "energy_authority_diagnosis.frozen_energy_threshold_changed": False,
            "decision.r24d121_same_identity_rerun_permitted": False,
            "decision.r24d124_same_identity_rerun_permitted": False,
            "decision.additional_raise_body_speed_only_successor_selected": False,
            "decision.additional_horizon_selected": False,
            "decision.r24d126_zero_world_implementation_authorized": True,
            "decision.physical_execution_authorized": False,
            "decision.historical_result_rewritten": False,
            "decision.historical_threshold_changed": False,
            "decision.historical_evaluator_changed": False,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "next_boundary.gate_id": next_gate_id,
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_build_count": 0,
            "claim_boundary.future_trajectory_predicted": False,
            "claim_boundary.energy_balance_physically_corrected": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.release_authority": False,
        },
        "RESPONSE_DECISION",
    )
    expected_live = dict(diagnosis["live_authority_projection"])
    expected_live.pop("next_gate_id")
    for key in ignored_forward_live_keys:
        expected_live.pop(key)
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
        prefix=f"LIVE_{gate_id.replace('-', '_')}",
    )
    require((root / str(diagnosis["closure_audit_path"])).is_file(), "AUDIT_PATH")
    return diagnosis


def run_raise_body_response_and_energy_authority_diagnosis_cli(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    pass_marker: str,
    failure_marker: str,
    **scope: str,
) -> int:
    """Run one thin campaign binding over the reusable response diagnosis."""

    try:
        diagnosis = validate_raise_body_response_and_energy_authority_diagnosis(
            root,
            relative_path,
            schema,
            expected_sha256,
            expected_length,
            **scope,
        )
        observed = diagnosis["observed_response"]
        print(
            pass_marker,
            json.dumps(
                {
                    "gate_id": diagnosis["gate_id"],
                    "ok": True,
                    "status": diagnosis["status"],
                    "first_physical_divergence_semantic_step": observed[
                        "controlled_comparison"
                    ]["first_physical_divergence_semantic_step"],
                    "v5_all_four_bearing_step_count": observed["r124_v5"][
                        "contact_response"
                    ]["all_four_bearing_step_count"],
                    "v5_terminal_center_of_mass_height_m": observed["r124_v5"][
                        "settled_zero_target_window"
                    ]["final_center_of_mass_height_m"],
                    "first_energy_component_failure_semantic_step": observed[
                        "r124_v5"
                    ]["safety_components"][
                        "first_energy_component_failure_semantic_step"
                    ],
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


def validate_bound_zero_world_engineering_diagnosis(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    *,
    gate_id: str,
    expected_status: str,
    authority_mode: str,
    next_gate_id: str,
    next_required_decision_key: str,
    live_record_key: str,
    live_identity_prefix: str,
    required_record_paths: dict[str, object] | None = None,
    ignored_forward_live_keys: tuple[str, ...] = (),
) -> dict[str, Any]:
    """Validate a compact digest-bound zero-world engineering decision.

    This deliberately verifies prior immutable records by exact identity and
    selected fields instead of re-executing their historical closure audits.
    Source conclusions are likewise limited to immutable Git blobs and declared
    markers. Campaign-specific policy stays in data and a thin binding.
    """

    raw_bytes = (root / relative_path).read_bytes()
    exact(
        (len(raw_bytes), "sha256:" + hashlib.sha256(raw_bytes).hexdigest()),
        (expected_length, expected_sha256),
        "BOUND_ENGINEERING_DIAGNOSIS_IDENTITY",
    )
    diagnosis = json.loads(raw_bytes)
    verify_exact_paths(
        diagnosis,
        {
            "schema_version": schema,
            "gate_id": gate_id,
            "status": expected_status,
            "question_class": "development",
            "physical_question_declared": False,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "ledger_scope.subsystem": "recovery",
            "ledger_scope.engine_scope": "godot_jolt",
            "ledger_scope.authority_mode": authority_mode,
            "ledger_scope.question_class": "development",
        },
        "BOUND_ENGINEERING_DIAGNOSIS",
    )

    bound_authorities = diagnosis["bound_json_authorities"]
    require(isinstance(bound_authorities, list) and bound_authorities, "BOUND_AUTHORITIES")
    roles: set[str] = set()
    for binding in bound_authorities:
        require(isinstance(binding, dict), "BOUND_AUTHORITY_SHAPE")
        role = str(binding["role"])
        require(role and role not in roles, f"BOUND_AUTHORITY_ROLE:{role}")
        roles.add(role)
        path = root / str(binding["path"])
        payload = path.read_bytes()
        exact(
            (len(payload), "sha256:" + hashlib.sha256(payload).hexdigest()),
            (int(binding["byte_length"]), str(binding["raw_sha256"])),
            f"BOUND_AUTHORITY_IDENTITY:{binding['path']}",
        )
        expected_paths = binding["expected_paths"]
        require(
            isinstance(expected_paths, dict) and bool(expected_paths),
            f"BOUND_AUTHORITY_EXPECTATIONS:{binding['path']}",
        )
        verify_exact_paths(
            json.loads(payload),
            expected_paths,
            f"BOUND_AUTHORITY:{role}",
        )
        exact(
            bool(binding.get("historical_audit_reexecuted", True)),
            False,
            f"BOUND_AUTHORITY_REEXECUTION:{role}",
        )

    source_bindings = diagnosis["source_bindings"]
    require(isinstance(source_bindings, list) and source_bindings, "SOURCE_BINDINGS")
    source_roles: set[str] = set()
    for binding in source_bindings:
        require(isinstance(binding, dict), "SOURCE_BINDING_SHAPE")
        role = str(binding["role"])
        require(role and role not in source_roles, f"SOURCE_BINDING_ROLE:{role}")
        source_roles.add(role)
        source = verify_source_binding(
            root, str(binding["source_commit"]), binding
        ).decode("utf-8")
        required_markers = binding["required_utf8_markers"]
        require(
            isinstance(required_markers, list) and bool(required_markers),
            f"SOURCE_MARKERS_DECLARED:{role}",
        )
        require(
            all(str(marker) in source for marker in required_markers),
            f"SOURCE_MARKERS:{role}",
        )
        forbidden_markers = binding.get("forbidden_utf8_markers", [])
        require(
            all(str(marker) not in source for marker in forbidden_markers),
            f"SOURCE_FORBIDDEN_MARKERS:{role}",
        )

    verify_exact_paths(
        diagnosis,
        {
            "method.bound_json_authority_count": len(bound_authorities),
            "method.source_binding_count": len(source_bindings),
            "method.historical_closure_audits_executed_count": 0,
            "method.model_construction_count": 0,
            "method.world_attempt_count": 0,
            "method.world_build_count": 0,
            "method.solver_step_count": 0,
            "method.physics_state_modified": False,
            f"decision.{next_required_decision_key}": True,
            "decision.physical_execution_authorized": False,
            "decision.historical_result_rewritten": False,
            "decision.historical_threshold_changed": False,
            "decision.historical_margin_changed": False,
            "decision.historical_selector_changed": False,
            "decision.historical_evaluator_changed": False,
            "decision.prone_to_standing_claimed": False,
            "decision.sdk1_milestone_advanced": False,
            "next_boundary.gate_id": next_gate_id,
            "next_boundary.physical_question_declared": False,
            "next_boundary.physical_execution_authorized": False,
            "next_boundary.maximum_world_attempt_count": 0,
            "next_boundary.maximum_world_build_count": 0,
            "next_boundary.maximum_physical_steps_authorized": 0,
            "claim_boundary.behavior_improvement_claimed": False,
            "claim_boundary.prone_to_standing_claimed": False,
            "claim_boundary.repeatability_claimed": False,
            "claim_boundary.population_claimed": False,
            "claim_boundary.cross_engine_recovery_claimed": False,
            "claim_boundary.cross_engine_equivalence_claimed": False,
            "claim_boundary.physical_acceptance_authority": False,
            "claim_boundary.release_authority": False,
            "sdk_status.sdk1_milestone_advanced": False,
            "sdk_status.sdk1_completed_steps": 11,
            "sdk_status.sdk1_total_steps": 20,
            "sdk_status.full_program_completed_steps": 11,
            "sdk_status.full_program_total_steps": 25,
        },
        "BOUND_ENGINEERING_DECISION",
    )
    if required_record_paths:
        verify_exact_paths(
            diagnosis,
            required_record_paths,
            "BOUND_ENGINEERING_CAMPAIGN",
        )

    expected_live = dict(diagnosis["live_authority_projection"])
    expected_live.pop("next_gate_id")
    for key in ignored_forward_live_keys:
        expected_live.pop(key)
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
        prefix=f"LIVE_{gate_id.replace('-', '_')}",
    )
    require((root / str(diagnosis["closure_audit_path"])).is_file(), "AUDIT_PATH")
    return diagnosis


def run_bound_zero_world_engineering_diagnosis_cli(
    root: Path,
    relative_path: str,
    schema: str,
    expected_sha256: str,
    expected_length: int,
    pass_marker: str,
    failure_marker: str,
    **scope: Any,
) -> int:
    """Run one thin campaign binding over the reusable digest-bound audit."""

    try:
        diagnosis = validate_bound_zero_world_engineering_diagnosis(
            root,
            relative_path,
            schema,
            expected_sha256,
            expected_length,
            **scope,
        )
        summary = dict(diagnosis["audit_summary"])
        summary.update(
            {
                "gate_id": diagnosis["gate_id"],
                "ok": True,
                "status": diagnosis["status"],
                "bound_json_authority_count": len(
                    diagnosis["bound_json_authorities"]
                ),
                "source_binding_count": len(diagnosis["source_bindings"]),
                "model_construction_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
                "prone_to_standing_claimed": False,
                "sdk1_milestone_advanced": False,
            }
        )
        print(pass_marker, json.dumps(summary, sort_keys=True))
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


if __name__ == "__main__":
    raise SystemExit("use a campaign-specific thin binding")
