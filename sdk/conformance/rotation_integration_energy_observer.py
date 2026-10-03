"""Engine-neutral reference checks for a rigid-body rotation energy boundary."""

from __future__ import annotations

from math import cos, isfinite, sin, sqrt, ulp
from typing import Any, Iterable, Sequence


class RotationObserverError(ValueError):
    """Raised when a rotation boundary is incomplete, crossed, or contaminated."""


FORBIDDEN_INPUT_KEYS = frozenset(
    {
        "whole_step_mechanical_energy_change_j",
        "mechanical_energy_change_j",
        "energy_balance_residual_j",
        "signed_energy_balance_residual_j",
        "acceptance_threshold_j",
        "controller_result",
        "behavior_result",
    }
)


Vector3 = tuple[float, float, float]
Matrix3 = tuple[Vector3, Vector3, Vector3]


def _vector(value: Sequence[float], label: str) -> Vector3:
    if len(value) != 3:
        raise RotationObserverError(f"{label}_SHAPE")
    result = tuple(float(component) for component in value)
    if not all(isfinite(component) for component in result):
        raise RotationObserverError(f"{label}_NONFINITE")
    return result  # type: ignore[return-value]


def _matrix(value: Sequence[Sequence[float]], label: str) -> Matrix3:
    if len(value) != 3:
        raise RotationObserverError(f"{label}_SHAPE")
    return tuple(_vector(row, label) for row in value)  # type: ignore[return-value]


def _dot(left: Vector3, right: Vector3) -> float:
    return sum(a * b for a, b in zip(left, right, strict=True))


def _transpose(value: Matrix3) -> Matrix3:
    return tuple(tuple(value[row][column] for row in range(3)) for column in range(3))  # type: ignore[return-value]


def _matrix_vector(value: Matrix3, vector: Vector3) -> Vector3:
    return tuple(_dot(row, vector) for row in value)  # type: ignore[return-value]


def _matrix_multiply(left: Matrix3, right: Matrix3) -> Matrix3:
    right_t = _transpose(right)
    return tuple(tuple(_dot(row, column) for column in right_t) for row in left)  # type: ignore[return-value]


def _identity() -> Matrix3:
    return ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))


def _axis_angle(axis: Vector3, angle: float) -> Matrix3:
    x, y, z = axis
    c = cos(angle)
    s = sin(angle)
    one_minus_c = 1.0 - c
    return (
        (
            c + x * x * one_minus_c,
            x * y * one_minus_c - z * s,
            x * z * one_minus_c + y * s,
        ),
        (
            y * x * one_minus_c + z * s,
            c + y * y * one_minus_c,
            y * z * one_minus_c - x * s,
        ),
        (
            z * x * one_minus_c - y * s,
            z * y * one_minus_c + x * s,
            c + z * z * one_minus_c,
        ),
    )


def jolt_rotation_step(
    pre_body_to_world: Sequence[Sequence[float]],
    angular_velocity_world_rad_s: Sequence[float],
    solver_step_s: float,
) -> Matrix3:
    """Mirror Body::AddRotationStep's left-multiplied axis-angle update."""

    rotation = _matrix(pre_body_to_world, "PRE_ROTATION")
    angular = _vector(angular_velocity_world_rad_s, "ANGULAR_VELOCITY")
    step = float(solver_step_s)
    if not isfinite(step) or step <= 0.0:
        raise RotationObserverError("SOLVER_STEP_INVALID")
    increment = tuple(component * step for component in angular)
    angle = sqrt(_dot(increment, increment))
    if angle <= 1.0e-6:
        return rotation
    axis = tuple(component / angle for component in increment)
    return _matrix_multiply(_axis_angle(axis, angle), rotation)  # type: ignore[arg-type]


def rotational_kinetic_energy_j(
    principal_inertia_kg_m2: Sequence[float],
    body_to_world: Sequence[Sequence[float]],
    angular_velocity_world_rad_s: Sequence[float],
) -> float:
    inertia = _vector(principal_inertia_kg_m2, "PRINCIPAL_INERTIA")
    if any(component <= 0.0 for component in inertia):
        raise RotationObserverError("PRINCIPAL_INERTIA_NONPOSITIVE")
    rotation = _matrix(body_to_world, "ROTATION")
    angular = _vector(angular_velocity_world_rad_s, "ANGULAR_VELOCITY")
    angular_body = _matrix_vector(_transpose(rotation), angular)
    energy = 0.5 * sum(
        moment * component * component
        for moment, component in zip(inertia, angular_body, strict=True)
    )
    if not isfinite(energy) or energy < 0.0:
        raise RotationObserverError("ROTATIONAL_ENERGY_INVALID")
    return energy


def binary64_bound(values: Iterable[float], operation_factor: int = 64) -> float:
    scale = max(1.0, *(abs(float(value)) for value in values))
    return operation_factor * ulp(scale)


def observe_rotation_integration_exchange(payload: dict[str, Any]) -> dict[str, Any]:
    """Validate one ordered source boundary and return its signed kinetic change."""

    contaminated = FORBIDDEN_INPUT_KEYS.intersection(payload)
    if contaminated:
        raise RotationObserverError("RESIDUAL_DERIVED_INPUT_REFUSED")
    previous = payload.get("previous_sequence")
    sequence = payload.get("sequence")
    if not isinstance(previous, int) or not isinstance(sequence, int):
        raise RotationObserverError("SEQUENCE_TYPE")
    if previous < 0 or sequence != previous + 1:
        raise RotationObserverError("SEQUENCE_CROSSED")
    if payload.get("pre_source_measurement") is not True or payload.get(
        "post_source_measurement"
    ) is not True:
        raise RotationObserverError("BOUNDARY_NOT_SOURCE_MEASURED")

    pre_rotation = _matrix(payload["pre_body_to_world"], "PRE_ROTATION")
    post_rotation = _matrix(payload["post_body_to_world"], "POST_ROTATION")
    angular = _vector(payload["angular_velocity_world_rad_s"], "ANGULAR_VELOCITY")
    expected_post = jolt_rotation_step(
        pre_rotation, angular, float(payload["solver_step_s"])
    )
    rotation_bound = binary64_bound(
        component
        for matrix in (post_rotation, expected_post)
        for row in matrix
        for component in row
    )
    maximum_rotation_error = max(
        abs(observed - expected)
        for observed_row, expected_row in zip(post_rotation, expected_post, strict=True)
        for observed, expected in zip(observed_row, expected_row, strict=True)
    )
    if maximum_rotation_error > rotation_bound:
        raise RotationObserverError("POST_ROTATION_NOT_JOLT_STEP")

    inertia = _vector(payload["principal_inertia_kg_m2"], "PRINCIPAL_INERTIA")
    before = rotational_kinetic_energy_j(inertia, pre_rotation, angular)
    after = rotational_kinetic_energy_j(inertia, post_rotation, angular)
    return {
        "previous_sequence": previous,
        "sequence": sequence,
        "pre_rotational_kinetic_energy_j": before,
        "post_rotational_kinetic_energy_j": after,
        "signed_rotation_integration_kinetic_exchange_j": after - before,
        "rotation_step_maximum_error": maximum_rotation_error,
        "rotation_step_binary64_bound": rotation_bound,
        "source_measurement": True,
        "mechanical_energy_residual_used_as_input": False,
        "acceptance_threshold_used_as_input": False,
    }
