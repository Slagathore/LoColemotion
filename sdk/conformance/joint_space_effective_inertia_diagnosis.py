#!/usr/bin/env python3
"""Reusable zero-world diagnosis for coupled joint-space impulse control."""

from __future__ import annotations

from collections import Counter
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
    verify_exact_paths,
    verify_legacy_live_authority_projection,
)
from sdk.conformance.finite_recovery_trace_diagnosis import (
    ACTUATORS,
    PHASE,
    _binary32_floor,
    _load_bound_physical_raw,
    _maximum_scale,
)


Vector = tuple[float, float, float]
Matrix = list[list[float]]


def _canonical_bytes(value: object) -> bytes:
    return json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


def _sha256(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def _v(value: dict[str, Any]) -> Vector:
    return (float(value["x"]), float(value["y"]), float(value["z"]))


def _add(left: Vector, right: Vector) -> Vector:
    return tuple(a + b for a, b in zip(left, right))  # type: ignore[return-value]


def _sub(left: Vector, right: Vector) -> Vector:
    return tuple(a - b for a, b in zip(left, right))  # type: ignore[return-value]


def _scale(value: Vector, scalar: float) -> Vector:
    return tuple(component * scalar for component in value)  # type: ignore[return-value]


def _dot(left: Vector, right: Vector) -> float:
    return sum(a * b for a, b in zip(left, right))


def _matrix(value: dict[str, Any]) -> Matrix:
    return [
        [float(value[row][column]) for column in ("x", "y", "z")]
        for row in ("x", "y", "z")
    ]


def _matrix_vector(matrix: Matrix, value: Vector) -> Vector:
    return tuple(_dot(tuple(row), value) for row in matrix)  # type: ignore[return-value]


def _f32(value: float) -> float:
    return struct.unpack("<f", struct.pack("<f", value))[0]


def _f32_add(left: float, right: float) -> float:
    return _f32(_f32(left) + _f32(right))


def _f32_mul(left: float, right: float) -> float:
    return _f32(_f32(left) * _f32(right))


def _f32_previous_nonnegative(value: float) -> float:
    projected = _f32(value)
    bits = struct.unpack("<I", struct.pack("<f", projected))[0]
    require(bits > 0, "REPRESENTATION_REFINEMENT_UNDERFLOW")
    return struct.unpack("<f", struct.pack("<I", bits - 1))[0]


def _f32_vector_add(left: Vector, right: Vector) -> Vector:
    return tuple(_f32_add(a, b) for a, b in zip(left, right))  # type: ignore[return-value]


def _f32_vector_scale(value: Vector, scalar: float) -> Vector:
    return tuple(_f32_mul(component, scalar) for component in value)  # type: ignore[return-value]


def _f32_matrix_vector(matrix: Matrix, value: Vector) -> Vector:
    result: list[float] = []
    for row in matrix:
        total = _f32_mul(row[0], value[0])
        total = _f32_add(total, _f32_mul(row[1], value[1]))
        total = _f32_add(total, _f32_mul(row[2], value[2]))
        result.append(total)
    return tuple(result)  # type: ignore[return-value]


def _f32_dot(left: Vector, right: Vector) -> float:
    total = _f32_mul(left[0], right[0])
    total = _f32_add(total, _f32_mul(left[1], right[1]))
    return _f32_add(total, _f32_mul(left[2], right[2]))


def _symmetrize(matrix: Matrix) -> Matrix:
    size = len(matrix)
    return [
        [0.5 * (matrix[row][column] + matrix[column][row]) for column in range(size)]
        for row in range(size)
    ]


def _cholesky_solve(matrix: Matrix, right: list[float]) -> tuple[list[float], float]:
    """Solve one symmetric positive-definite system without external packages."""

    size = len(matrix)
    exact([len(row) for row in matrix], [size] * size, "CHOLESKY_SHAPE")
    exact(len(right), size, "CHOLESKY_RIGHT_SHAPE")
    lower = [[0.0] * size for _ in range(size)]
    minimum_pivot = math.inf
    for row in range(size):
        for column in range(row + 1):
            residual = matrix[row][column] - sum(
                lower[row][index] * lower[column][index]
                for index in range(column)
            )
            if row == column:
                require(residual > 0.0 and math.isfinite(residual), "CHOLESKY_PIVOT")
                minimum_pivot = min(minimum_pivot, residual)
                lower[row][column] = math.sqrt(residual)
            else:
                lower[row][column] = residual / lower[column][column]
    forward = [0.0] * size
    for row in range(size):
        forward[row] = (
            right[row]
            - sum(lower[row][column] * forward[column] for column in range(row))
        ) / lower[row][row]
    solution = [0.0] * size
    for row in range(size - 1, -1, -1):
        solution[row] = (
            forward[row]
            - sum(
                lower[column][row] * solution[column]
                for column in range(row + 1, size)
            )
        ) / lower[row][row]
    return solution, minimum_pivot


def _response_matrix(
    bodies: dict[str, dict[str, Any]],
    joints: list[dict[str, Any]],
) -> Matrix:
    matrix = [[0.0] * len(joints) for _ in joints]
    for column, source_joint in enumerate(joints):
        axis = _v(source_joint["axis_world"])
        body_delta = {body_id: (0.0, 0.0, 0.0) for body_id in bodies}
        parent_id = str(source_joint["parent_body_id"])
        child_id = str(source_joint["child_body_id"])
        body_delta[parent_id] = _matrix_vector(
            _matrix(bodies[parent_id]["inverse_inertia_tensor_world_kg_inv_m2"]),
            _scale(axis, -1.0),
        )
        body_delta[child_id] = _matrix_vector(
            _matrix(bodies[child_id]["inverse_inertia_tensor_world_kg_inv_m2"]),
            axis,
        )
        for row, observed_joint in enumerate(joints):
            relative_delta = _sub(
                body_delta[str(observed_joint["child_body_id"])],
                body_delta[str(observed_joint["parent_body_id"])],
            )
            matrix[row][column] = _dot(relative_delta, _v(observed_joint["axis_world"]))
    return matrix


def _matrix_product(matrix: Matrix, value: list[float]) -> list[float]:
    return [sum(left * right for left, right in zip(row, value)) for row in matrix]


def _represented_prediction(
    bodies: dict[str, dict[str, Any]],
    joints: list[dict[str, Any]],
    source: list[float],
    solution: list[float],
    scale: float,
) -> list[float]:
    impulses = {body_id: (0.0, 0.0, 0.0) for body_id in bodies}
    for amount, joint in zip(solution, joints):
        axis = _v(joint["axis_world"])
        represented_amount = _f32(amount * scale)
        parent_id = str(joint["parent_body_id"])
        child_id = str(joint["child_body_id"])
        impulses[parent_id] = _f32_vector_add(
            impulses[parent_id],
            _f32_vector_scale(axis, -represented_amount),
        )
        impulses[child_id] = _f32_vector_add(
            impulses[child_id],
            _f32_vector_scale(axis, represented_amount),
        )
    body_delta = {
        body_id: _f32_matrix_vector(
            _matrix(body["inverse_inertia_tensor_world_kg_inv_m2"]),
            impulses[body_id],
        )
        for body_id, body in bodies.items()
    }
    predicted: list[float] = []
    for index, joint in enumerate(joints):
        relative_delta = tuple(
            _f32(child - parent)
            for child, parent in zip(
                body_delta[str(joint["child_body_id"])],
                body_delta[str(joint["parent_body_id"])],
            )
        )
        predicted.append(source[index] + _f32_dot(relative_delta, _v(joint["axis_world"])))
    return predicted


def _target_applications(raw: dict[str, Any]) -> list[dict[str, Any]]:
    applications = [
        value
        for value in raw["candidate_arm"]["command_application_receipts"]
        if value.get("joint_target_monotone_population_guard_projection") is not None
    ]
    exact(len(applications), 240, "TARGET_APPLICATION_COUNT")
    exact(
        [int(value["semantic_step"]) for value in applications],
        list(range(29, 269)),
        "TARGET_APPLICATION_STEPS",
    )
    return applications


def _fixed_direction_subset_projection(
    matrix: Matrix,
    error: list[float],
    existing: list[float],
) -> dict[str, Any]:
    feasible: list[tuple[int, int]] = []
    for mask in range(1, 1 << len(existing)):
        value = [amount if mask & (1 << index) else 0.0 for index, amount in enumerate(existing)]
        delta = _matrix_product(matrix, value)
        if all(source * change >= 0.0 for source, change in zip(error, delta)):
            feasible.append((mask.bit_count(), mask))
    require(bool(feasible), "FIXED_DIRECTION_SUBSET_EMPTY")
    maximum_cardinality = max(cardinality for cardinality, _mask in feasible)
    selected_mask = min(mask for cardinality, mask in feasible if cardinality == maximum_cardinality)
    rear_hips_removed_mask = sum(
        1 << index
        for index, actuator_id in enumerate(ACTUATORS)
        if actuator_id not in {"rear_left_hip_motor", "rear_right_hip_motor"}
    )
    rear_hips_removed_delta = _matrix_product(
        matrix,
        [
            amount if rear_hips_removed_mask & (1 << index) else 0.0
            for index, amount in enumerate(existing)
        ],
    )
    return {
        "feasible_nonempty_subset_count": len(feasible),
        "maximum_cardinality": maximum_cardinality,
        "selected_canonical_mask": selected_mask,
        "rear_hips_removed_mask": rear_hips_removed_mask,
        "rear_hips_removed_direction_feasible": all(
            source * change >= 0.0
            for source, change in zip(error, rear_hips_removed_delta)
        ),
    }


def joint_space_effective_inertia_projection(
    r105_raw: dict[str, Any],
    r106_diagnosis: dict[str, Any],
    r107_raw: dict[str, Any],
) -> dict[str, Any]:
    """Explain the R107 deadlock and replay the smallest coupled successor."""

    for raw, gate_id in ((r105_raw, "QSDK-R24D105"), (r107_raw, "QSDK-R24D107")):
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
            gate_id,
        )
    identity_keys = (
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
    paired_identity = {key: r105_raw[key] for key in identity_keys}
    exact(
        {key: r107_raw[key] for key in identity_keys},
        paired_identity,
        "PAIRED_IDENTITY",
    )
    exact(
        r107_raw["candidate_arm"]["declared_initial_state_sha256"],
        r105_raw["candidate_arm"]["declared_initial_state_sha256"],
        "PAIRED_INITIAL_STATE",
    )
    paired_identity["declared_initial_state_sha256"] = r105_raw["candidate_arm"][
        "declared_initial_state_sha256"
    ]
    paired_identity["r105_seed_label"] = r105_raw["seed_label"]
    paired_identity["r107_seed_label"] = r107_raw["seed_label"]

    r105_first = next(
        value
        for value in r105_raw["candidate_arm"]["command_application_receipts"]
        if value.get("order_neutral_population_guard_projection") is not None
    )
    applications = _target_applications(r107_raw)
    r107_first = applications[0]
    exact(r105_first["semantic_step"], r107_first["semantic_step"], "FIRST_STEP")
    exact(
        [float(value["measured_pre_step_relative_velocity_rad_s"]) for value in r105_first["ordered_intents"]],
        [
            float(value["reconstructed_source_relative_velocity_rad_s"])
            for value in r107_first["joint_target_monotone_population_guard_projection"]["ordered_joint_target_projections"]
        ],
        "FIRST_SOURCE_STATE",
    )

    verify_exact_paths(
        r106_diagnosis,
        {
            "gate_id": "QSDK-R24D106",
            "decision.r24d107_zero_world_implementation_authorized": True,
            "claim_boundary.trajectory_prediction_claimed": False,
            "claim_boundary.behavior_improvement_claimed": False,
        },
        "R106",
    )
    r106_scale = r106_diagnosis["computed_projection_summary"][
        "target_monotone_common_scale"
    ]

    step_records: list[dict[str, Any]] = []
    symmetry_residuals: list[float] = []
    cholesky_pivots: list[float] = []
    solve_residuals: list[float] = []
    solution_to_cap_ratios: list[float] = []
    body_scales: list[float] = []
    refinement_counts: Counter[int] = Counter()
    sign_difference_by_actuator: Counter[str] = Counter()
    actual_helpful_by_actuator: Counter[str] = Counter()
    actual_nonhelpful_by_actuator: Counter[str] = Counter()
    subset_counts: list[int] = []
    subset_cardinalities: list[int] = []
    subset_masks: Counter[int] = Counter()
    rear_hips_removed_feasible_count = 0
    maximum_remaining_error = 0.0

    for application in applications:
        population = application["joint_target_monotone_population_guard_projection"]
        joints = population["ordered_joint_target_projections"]
        exact(
            tuple(str(value["actuator_id"]) for value in joints),
            ACTUATORS,
            "JOINT_ORDER",
        )
        body_guard = population["body_guard_population_projection"]
        bodies = {
            str(value["body_id"]): value
            for value in body_guard["ordered_body_projections"]
        }
        exact(len(bodies), 9, "BODY_COUNT")
        matrix = _response_matrix(bodies, joints)
        symmetry_residual = max(
            abs(matrix[row][column] - matrix[column][row])
            for row in range(8)
            for column in range(8)
        )
        symmetric = _symmetrize(matrix)
        source = [
            float(value["reconstructed_source_relative_velocity_rad_s"])
            for value in joints
        ]
        target = [float(value["canonical_target_velocity_rad_s"]) for value in joints]
        error = [desired - observed for desired, observed in zip(target, source)]
        solution, minimum_pivot = _cholesky_solve(symmetric, error)
        solved = _matrix_product(symmetric, solution)
        solve_residual = max(
            abs(observed - expected) for observed, expected in zip(solved, error)
        )
        caps = [
            float(value["predecessor_projection"]["published_maximum_outer_step_impulse_nms"])
            for value in joints
        ]
        cap_scale = min(
            1.0,
            min(
                cap / abs(amount) if amount != 0.0 else 1.0
                for cap, amount in zip(caps, solution)
            ),
        )
        cap_scale = _binary32_floor(cap_scale)
        solution_to_cap_ratios.extend(
            abs(amount) / cap for amount, cap in zip(solution, caps)
        )
        existing = [
            float(value["predecessor_projection"]["applied_signed_joint_impulse_nms"])
            for value in joints
        ]
        for actuator_id, proposed, current in zip(ACTUATORS, solution, existing):
            sign_difference_by_actuator[actuator_id] += int(
                math.copysign(1.0, proposed) != math.copysign(1.0, current)
            )

        body_impulses = {body_id: (0.0, 0.0, 0.0) for body_id in bodies}
        for amount, joint in zip(solution, joints):
            represented = amount * cap_scale
            axis = _v(joint["axis_world"])
            parent_id = str(joint["parent_body_id"])
            child_id = str(joint["child_body_id"])
            body_impulses[parent_id] = _add(
                body_impulses[parent_id], _scale(axis, -represented)
            )
            body_impulses[child_id] = _add(
                body_impulses[child_id], _scale(axis, represented)
            )
        projection_limit = float(
            body_guard["inner_projection_target"]["projection_target_limit_rad_s"]
        )
        body_scale = min(
            _maximum_scale(
                _v(body["source_angular_velocity_world_rad_s"]),
                _matrix_vector(
                    _matrix(body["inverse_inertia_tensor_world_kg_inv_m2"]),
                    body_impulses[body_id],
                ),
                projection_limit,
            )
            for body_id, body in bodies.items()
        )
        body_scale = _binary32_floor(body_scale)
        common_scale = _binary32_floor(min(cap_scale, body_scale))
        maximum_iterations = {
            int(value["predecessor_projection"]["maximum_representation_projection_iterations"])
            for value in joints
        }
        exact(maximum_iterations, {16}, "REPRESENTATION_ITERATION_LIMIT")
        refinement_count = 0
        while True:
            predicted = _represented_prediction(
                bodies, joints, source, solution, common_scale
            )
            remaining = [desired - observed for desired, observed in zip(target, predicted)]
            if all(before * after >= 0.0 for before, after in zip(error, remaining)):
                break
            require(refinement_count < 16, "REPRESENTATION_REFINEMENT_LIMIT")
            common_scale = _f32_previous_nonnegative(common_scale)
            refinement_count += 1
        require(
            all(abs(after) <= abs(before) for before, after in zip(error, remaining)),
            "SOLUTION_TARGET_ERROR",
        )
        maximum_remaining_error = max(
            maximum_remaining_error, max(abs(value) for value in remaining)
        )

        subset = _fixed_direction_subset_projection(matrix, error, existing)
        subset_counts.append(int(subset["feasible_nonempty_subset_count"]))
        subset_cardinalities.append(int(subset["maximum_cardinality"]))
        subset_masks[int(subset["selected_canonical_mask"])] += 1
        rear_hips_removed_feasible_count += int(
            bool(subset["rear_hips_removed_direction_feasible"])
        )

        local_helpful: list[str] = []
        local_nonhelpful: list[str] = []
        for value in joints:
            actuator_id = str(value["actuator_id"])
            if bool(value["full_scale_delta_helpful"]):
                actual_helpful_by_actuator[actuator_id] += 1
                local_helpful.append(actuator_id)
            elif not bool(value["full_scale_delta_neutral"]):
                actual_nonhelpful_by_actuator[actuator_id] += 1
                local_nonhelpful.append(actuator_id)
        exact(
            bool(population["population_zero_hold_for_nonhelpful_joint_delta"]),
            bool(local_nonhelpful),
            "ACTUAL_ZERO_HOLD",
        )
        exact(float(population["target_common_pre_scale"]), 0.0, "ACTUAL_SCALE")
        exact(int(application["body_impulse_write_count"]), 0, "ACTUAL_BODY_WRITE")

        symmetry_residuals.append(symmetry_residual)
        cholesky_pivots.append(minimum_pivot)
        solve_residuals.append(solve_residual)
        body_scales.append(body_scale)
        refinement_counts[refinement_count] += 1
        step_records.append(
            {
                "semantic_step": int(application["semantic_step"]),
                "response_matrix": matrix,
                "source_relative_velocity_rad_s": source,
                "canonical_target_velocity_rad_s": target,
                "solved_signed_joint_impulse_nms": solution,
                "published_cap_nms": caps,
                "cap_scale": cap_scale,
                "body_guard_scale": body_scale,
                "represented_common_scale": common_scale,
                "representation_refinement_count": refinement_count,
                "maximum_remaining_absolute_target_error_rad_s": max(
                    abs(value) for value in remaining
                ),
                "actual_helpful_actuator_ids": local_helpful,
                "actual_nonhelpful_actuator_ids": local_nonhelpful,
                "fixed_direction_subset": subset,
            }
        )

    step_bytes = _canonical_bytes(step_records)
    return {
        "paired_identity": paired_identity,
        "r106_frozen_state_replay_vs_r107_counterfactual": {
            "r106_counterfactual_kind": "frozen_source_state_non_predictive_zero_world_sensitivity",
            "r106_trajectory_prediction_claimed": False,
            "r106_positive_common_scale_count": int(r106_scale["positive_count"]),
            "r106_zero_hold_count": int(r106_scale["zero_hold_count"]),
            "r107_positive_common_scale_count": 0,
            "r107_zero_hold_count": len(applications),
            "r107_first_zero_hold_semantic_step": int(applications[0]["semantic_step"]),
            "r107_first_hold_predecessor_state_identical_to_r105": True,
            "absorbing_counterfactual_hold_established": True,
        },
        "r107_actual_population_hold": {
            "application_count": len(applications),
            "body_impulse_write_count": 0,
            "helpful_projection_count_by_actuator": {
                actuator_id: actual_helpful_by_actuator[actuator_id]
                for actuator_id in ACTUATORS
            },
            "nonhelpful_projection_count_by_actuator": {
                actuator_id: actual_nonhelpful_by_actuator[actuator_id]
                for actuator_id in ACTUATORS
            },
        },
        "fixed_predecessor_direction_subset_sensitivity": {
            "feasible_nonempty_subset_count_minimum": min(subset_counts),
            "feasible_nonempty_subset_count_maximum": max(subset_counts),
            "maximum_feasible_cardinality_minimum": min(subset_cardinalities),
            "maximum_feasible_cardinality_maximum": max(subset_cardinalities),
            "selected_canonical_mask_histogram": {
                str(mask): count for mask, count in sorted(subset_masks.items())
            },
            "rear_hips_removed_direction_feasible_step_count": rear_hips_removed_feasible_count,
            "trajectory_prediction_claimed": False,
        },
        "coupled_effective_inertia_solve": {
            "response_matrix_rule_id": "symmetric_average_eight_joint_effective_inverse_inertia_response_v1",
            "solve_rule_id": "deterministic_cholesky_exact_joint_velocity_error_impulse_v1",
            "representation_rule_id": "canonical_order_binary32_body_aggregate_with_at_most_existing_sixteen_downward_common_scale_refinements_v1",
            "source_state_count": len(applications),
            "joint_solve_count": len(applications) * len(ACTUATORS),
            "response_matrix_symmetry_maximum_absolute_residual": max(
                symmetry_residuals
            ),
            "minimum_cholesky_pivot": min(cholesky_pivots),
            "solve_maximum_absolute_residual_rad_s": max(solve_residuals),
            "maximum_solution_to_published_cap_ratio": max(solution_to_cap_ratios),
            "all_solutions_inside_published_caps": all(
                value <= 1.0 for value in solution_to_cap_ratios
            ),
            "body_guard_scale_minimum": min(body_scales),
            "body_guard_scale_maximum": max(body_scales),
            "representation_refinement_count_histogram": {
                str(count): population
                for count, population in sorted(refinement_counts.items())
            },
            "maximum_representation_refinement_count": max(refinement_counts),
            "existing_maximum_representation_projection_iterations": 16,
            "all_joint_target_errors_nonincreasing_step_count": len(applications),
            "target_crossing_step_count": 0,
            "maximum_remaining_absolute_target_error_rad_s": maximum_remaining_error,
            "solution_sign_difference_count_by_actuator": {
                actuator_id: sign_difference_by_actuator[actuator_id]
                for actuator_id in ACTUATORS
            },
        },
        "ordered_step_records_canonical_byte_length": len(step_bytes),
        "ordered_step_records_canonical_sha256": _sha256(step_bytes),
        "execution_counts": {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "body_impulse_write_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
        },
        "trajectory_prediction_claimed": False,
        "behavior_improvement_claimed": False,
        "threshold_or_margin_selected": False,
    }


def projection_summary(projection: dict[str, Any]) -> dict[str, Any]:
    replay = projection["r106_frozen_state_replay_vs_r107_counterfactual"]
    actual = projection["r107_actual_population_hold"]
    subset = projection["fixed_predecessor_direction_subset_sensitivity"]
    solve = projection["coupled_effective_inertia_solve"]
    return {
        "source_state_count": solve["source_state_count"],
        "r106_predicted_positive_common_scale_count": replay[
            "r106_positive_common_scale_count"
        ],
        "r106_predicted_zero_hold_count": replay["r106_zero_hold_count"],
        "r107_actual_positive_common_scale_count": replay[
            "r107_positive_common_scale_count"
        ],
        "r107_actual_zero_hold_count": replay["r107_zero_hold_count"],
        "r107_helpful_projection_count_by_actuator": actual[
            "helpful_projection_count_by_actuator"
        ],
        "r107_nonhelpful_projection_count_by_actuator": actual[
            "nonhelpful_projection_count_by_actuator"
        ],
        "fixed_direction_feasible_subset_count": {
            "minimum": subset["feasible_nonempty_subset_count_minimum"],
            "maximum": subset["feasible_nonempty_subset_count_maximum"],
        },
        "fixed_direction_maximum_feasible_cardinality": {
            "minimum": subset["maximum_feasible_cardinality_minimum"],
            "maximum": subset["maximum_feasible_cardinality_maximum"],
        },
        "rear_hips_removed_direction_feasible_step_count": subset[
            "rear_hips_removed_direction_feasible_step_count"
        ],
        "response_matrix_symmetry_maximum_absolute_residual": solve[
            "response_matrix_symmetry_maximum_absolute_residual"
        ],
        "minimum_cholesky_pivot": solve["minimum_cholesky_pivot"],
        "solve_maximum_absolute_residual_rad_s": solve[
            "solve_maximum_absolute_residual_rad_s"
        ],
        "maximum_solution_to_published_cap_ratio": solve[
            "maximum_solution_to_published_cap_ratio"
        ],
        "body_guard_scale": {
            "minimum": solve["body_guard_scale_minimum"],
            "maximum": solve["body_guard_scale_maximum"],
        },
        "representation_refinement_count_histogram": solve[
            "representation_refinement_count_histogram"
        ],
        "maximum_representation_refinement_count": solve[
            "maximum_representation_refinement_count"
        ],
        "all_joint_target_errors_nonincreasing_step_count": solve[
            "all_joint_target_errors_nonincreasing_step_count"
        ],
        "target_crossing_step_count": solve["target_crossing_step_count"],
        "solution_sign_difference_count_by_actuator": solve[
            "solution_sign_difference_count_by_actuator"
        ],
        "ordered_step_records_canonical_byte_length": projection[
            "ordered_step_records_canonical_byte_length"
        ],
        "ordered_step_records_canonical_sha256": projection[
            "ordered_step_records_canonical_sha256"
        ],
        "execution_counts": projection["execution_counts"],
    }


def _load_bound_json(root: Path, binding: dict[str, Any], label: str) -> dict[str, Any]:
    path = root / str(binding["path"])
    raw = path.read_bytes()
    exact(
        (len(raw), _sha256(raw)),
        (int(binding["byte_length"]), str(binding["raw_sha256"])),
        f"{label}_IDENTITY",
    )
    value = json.loads(raw)
    verify_exact_paths(
        value,
        {
            "schema_version": binding["schema_version"],
            "gate_id": binding["gate_id"],
            "status": binding["status"],
        },
        label,
    )
    return value


def validate_diagnosis(
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
    raw_bytes = (root / relative_path).read_bytes()
    exact(
        (len(raw_bytes), _sha256(raw_bytes)),
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
    predecessors = diagnosis["predecessors"]
    r105_raw = _load_bound_physical_raw(root, predecessors["r24d105"], "R105")
    r106 = _load_bound_json(root, predecessors["r24d106"], "R106")
    r107_raw = _load_bound_physical_raw(root, predecessors["r24d107"], "R107")
    projection = joint_space_effective_inertia_projection(r105_raw, r106, r107_raw)
    encoded = _canonical_bytes(projection)
    exact(
        (len(encoded), _sha256(encoded)),
        (
            diagnosis["computed_projection_canonical_byte_length"],
            diagnosis["computed_projection_canonical_sha256"],
        ),
        "PROJECTION_IDENTITY",
    )
    exact(projection_summary(projection), diagnosis["computed_projection_summary"], "SUMMARY")
    verify_exact_paths(
        diagnosis,
        {
            "decision.r24d105_same_identity_rerun_permitted": False,
            "decision.r24d107_same_identity_rerun_permitted": False,
            "decision.r24d109_zero_world_implementation_authorized": True,
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
        "DECISION",
    )
    expected_live = dict(diagnosis["live_authority_projection"])
    for key in ("next_gate_id", "r24d109_zero_world_implementation_required"):
        expected_live.pop(key, None)
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


def run_cli(
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
        diagnosis = validate_diagnosis(
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
                    "source_state_count": summary["source_state_count"],
                    "r107_zero_hold_count": summary[
                        "r107_actual_zero_hold_count"
                    ],
                    "maximum_solution_to_published_cap_ratio": summary[
                        "maximum_solution_to_published_cap_ratio"
                    ],
                    "maximum_representation_refinement_count": summary[
                        "maximum_representation_refinement_count"
                    ],
                    "target_crossing_step_count": summary[
                        "target_crossing_step_count"
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
