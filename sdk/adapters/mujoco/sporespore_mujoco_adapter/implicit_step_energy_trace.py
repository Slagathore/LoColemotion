"""Replayable invariants for serialized MuJoCo implicit-step energy traces."""

from __future__ import annotations

import math
from copy import deepcopy
from typing import Any, Mapping, Sequence

from . import native_recovery_development as runtime
from .implicit_step_energy import measure_implicit_step_energy_work_v3
from .sparse_actuator_moment import (
    PROFILE_ID as SPARSE_ACTUATOR_MOMENT_PROFILE_ID,
    SparseActuatorMomentError,
    expand_sparse_actuator_moment_v1,
    validate_sparse_actuator_moment_receipt_v1,
)


TRACE_VALIDATOR_ID = "mujoco_implicit_step_energy_trace_invariants_v1"
AGGREGATE_TOLERANCE_J = 1.0e-10


class ImplicitStepEnergyTraceError(ValueError):
    """Stable fail-closed error for retained v2/v3 trace invariants."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise ImplicitStepEnergyTraceError(code)


def _number(value: Any, code: str) -> float:
    _require(isinstance(value, (int, float)) and not isinstance(value, bool), code)
    result = float(value)
    _require(math.isfinite(result), code)
    return result


def _close(left: float, right: float) -> bool:
    return abs(left - right) <= AGGREGATE_TOLERANCE_J


def _vector_close(left: Sequence[Any], right: Sequence[float], code: str) -> None:
    _require(len(left) == len(right), code)
    _require(
        all(_close(_number(a, code), float(b)) for a, b in zip(left, right, strict=True)),
        code,
    )


def validate_implicit_step_energy_trace_v1(
    result: Mapping[str, Any],
    *,
    expected_route_id: str = runtime.IMPLICIT_STEP_ROUTE_ID,
    expected_native_receipt_schema: str = runtime.IMPLICIT_STEP_NATIVE_RECEIPT_SCHEMA,
    require_sparse_actuator_moment_expansion: bool = False,
) -> dict[str, Any]:
    """Re-derive every native substep and its outer/portable cumulative mapping."""

    total_outer_steps = 0
    total_native_substeps = 0
    effective_matched_zero_nonzero_count = 0
    sparse_expansion_receipt_count = 0
    arm_outer_steps: dict[str, int] = {}
    for arm_key in ("candidate", "matched_zero_command"):
        arm = result[arm_key]
        observations = arm["observations"]
        native_receipts = arm["native_receipts"]
        portable_receipts = arm["portable_step_receipts"]
        _require(
            len(observations) == len(native_receipts) == len(portable_receipts),
            f"QSDK_R24D34_{arm_key.upper()}_OUTER_COUNT_MISMATCH",
        )
        arm_outer_steps[arm_key] = len(observations)
        cumulative_v2 = {
            "actuator": 0.0,
            "constraint": 0.0,
            "damper": 0.0,
            "fluid": 0.0,
            "adhesion": 0.0,
            "dissipated": 0.0,
        }
        cumulative_v3 = {
            "actuator": 0.0,
            "generalized_actuator": 0.0,
            "constraint": 0.0,
            "damper": 0.0,
            "fluid": 0.0,
            "adhesion": 0.0,
            "dissipated": 0.0,
        }
        for outer_index, (observation, native_receipt) in enumerate(
            zip(observations, native_receipts, strict=True)
        ):
            native = native_receipt["native_step"]
            _require(
                native["schema_version"] == expected_native_receipt_schema
                and native["route_id"] == expected_route_id
                and native["energy_ledger_profile_id"]
                == runtime.IMPLICIT_STEP_ENERGY_LEDGER_PROFILE_ID
                and native["historical_v2_energy_ledger_profile_id"]
                == runtime.ENERGY_LEDGER_PROFILE_ID,
                "QSDK_R24D34_NATIVE_PROFILE_IDENTITY",
            )
            substeps = native["implicit_substep_energy_receipts"]
            _require(
                len(substeps) == native["native_substep_count"],
                "QSDK_R24D34_SUBSTEP_COUNT_MISMATCH",
            )
            step_v2 = {key: 0.0 for key in cumulative_v2}
            step_v3 = {key: 0.0 for key in cumulative_v3}
            retained_elapsed_s = 0.0
            for expected_substep, retained in enumerate(substeps):
                _require(
                    retained["schema_version"]
                    == (
                        runtime.SPARSE_MOMENT_IMPLICIT_SUBSTEP_RECEIPT_SCHEMA
                        if require_sparse_actuator_moment_expansion
                        else runtime.IMPLICIT_SUBSTEP_RECEIPT_SCHEMA
                    )
                    and retained["measurement_profile_id"]
                    == runtime.IMPLICIT_STEP_ENERGY_LEDGER_PROFILE_ID
                    and retained["native_substep"] == expected_substep,
                    "QSDK_R24D34_SUBSTEP_IDENTITY",
                )
                if require_sparse_actuator_moment_expansion:
                    try:
                        expansion = validate_sparse_actuator_moment_receipt_v1(
                            retained["actuator_moment_expansion"]
                        )
                    except (KeyError, SparseActuatorMomentError) as error:
                        raise ImplicitStepEnergyTraceError(
                            "QSDK_R24D35_SPARSE_EXPANSION_RECEIPT_INVALID"
                        ) from error
                    _require(
                        retained["actuator_moment_expansion_profile_id"]
                        == SPARSE_ACTUATOR_MOMENT_PROFILE_ID
                        and [list(row) for row in expansion.dense]
                        == retained["actuator_moment"],
                        "QSDK_R24D35_SPARSE_EXPANSION_DENSE_MISMATCH",
                    )
                    sparse_expansion_receipt_count += 1
                historical = retained["historical_v2"]
                implicit = retained["implicit_v3"]
                native_timestep_s = _number(
                    retained["native_timestep_s"],
                    "native_timestep_s",
                )
                _require(
                    native_timestep_s > 0.0,
                    "QSDK_R24D34_NATIVE_TIMESTEP_INVALID",
                )
                retained_elapsed_s += native_timestep_s
                v2 = runtime.measure_native_energy_work_v2(
                    timestep_s=native_timestep_s,
                    actuator_force=retained["reported_pre_actuator_force_nm"],
                    actuator_velocity=retained[
                        "reported_pre_actuator_velocity_rad_s"
                    ],
                    generalized_velocity=retained["pre_generalized_velocity"],
                    generalized_actuator_force=retained[
                        "reported_pre_generalized_actuator_force"
                    ],
                    generalized_constraint_force=retained[
                        "reported_pre_generalized_constraint_force"
                    ],
                    generalized_damper_force=retained[
                        "reported_pre_generalized_damper_force"
                    ],
                    generalized_fluid_force=retained[
                        "reported_pre_generalized_fluid_force"
                    ],
                    generalized_adhesion_force=retained[
                        "reported_pre_generalized_adhesion_force"
                    ],
                )
                v3 = measure_implicit_step_energy_work_v3(
                    timestep_s=native_timestep_s,
                    target_actuator_velocity_rad_s=retained[
                        "target_actuator_velocity_rad_s"
                    ],
                    reported_pre_actuator_velocity_rad_s=retained[
                        "reported_pre_actuator_velocity_rad_s"
                    ],
                    reported_pre_actuator_force_nm=retained[
                        "reported_pre_actuator_force_nm"
                    ],
                    velocity_gain_nm_s_per_rad=retained[
                        "velocity_gain_nm_s_per_rad"
                    ],
                    force_range_lower_nm=retained["force_range_lower_nm"],
                    force_range_upper_nm=retained["force_range_upper_nm"],
                    actuator_moment=retained["actuator_moment"],
                    pre_generalized_velocity=retained["pre_generalized_velocity"],
                    post_generalized_velocity=retained["post_generalized_velocity"],
                    reported_pre_generalized_actuator_force=retained[
                        "reported_pre_generalized_actuator_force"
                    ],
                    reported_pre_generalized_constraint_force=retained[
                        "reported_pre_generalized_constraint_force"
                    ],
                    reported_pre_generalized_damper_force=retained[
                        "reported_pre_generalized_damper_force"
                    ],
                    reported_pre_generalized_fluid_force=retained[
                        "reported_pre_generalized_fluid_force"
                    ],
                    reported_pre_generalized_adhesion_force=retained[
                        "reported_pre_generalized_adhesion_force"
                    ],
                )
                v2_values = {
                    "actuator": v2.actuator_work_j,
                    "constraint": v2.constraint_work_j,
                    "damper": v2.damper_work_j,
                    "fluid": v2.fluid_work_j,
                    "adhesion": v2.adhesion_work_j,
                    "dissipated": v2.dissipated_energy_j,
                }
                v3_values = {
                    "actuator": v3.effective_centered_actuator_work_j,
                    "generalized_actuator": (
                        v3.effective_centered_generalized_actuator_work_j
                    ),
                    "constraint": v3.centered_constraint_work_j,
                    "damper": v3.centered_damper_work_j,
                    "fluid": v3.centered_fluid_work_j,
                    "adhesion": v3.centered_adhesion_work_j,
                    "dissipated": v3.centered_dissipated_energy_j,
                }
                for key, field in (
                    ("actuator", "left_endpoint_actuator_work_j"),
                    ("constraint", "left_endpoint_constraint_work_j"),
                    ("damper", "left_endpoint_damper_work_j"),
                    ("fluid", "left_endpoint_fluid_work_j"),
                    ("adhesion", "left_endpoint_adhesion_work_j"),
                    ("dissipated", "left_endpoint_dissipated_energy_j"),
                ):
                    _require(
                        _close(v2_values[key], _number(historical[field], field)),
                        f"QSDK_R24D34_SUBSTEP_V2_MISMATCH:{field}",
                    )
                for key, field in (
                    ("actuator", "effective_centered_actuator_work_j"),
                    (
                        "generalized_actuator",
                        "effective_centered_generalized_actuator_work_j",
                    ),
                    ("constraint", "centered_constraint_work_j"),
                    ("damper", "centered_damper_work_j"),
                    ("fluid", "centered_fluid_work_j"),
                    ("adhesion", "centered_adhesion_work_j"),
                    ("dissipated", "centered_dissipated_energy_j"),
                ):
                    _require(
                        _close(v3_values[key], _number(implicit[field], field)),
                        f"QSDK_R24D34_SUBSTEP_V3_MISMATCH:{field}",
                    )
                _vector_close(
                    implicit["effective_implicit_actuator_force_nm"],
                    v3.effective_implicit_actuator_force_nm,
                    "QSDK_R24D34_EFFECTIVE_FORCE_MISMATCH",
                )
                _require(
                    tuple(implicit["force_limited_at_pre_step"])
                    == v3.force_limited_at_pre_step,
                    "QSDK_R24D34_FORCE_LIMIT_BRANCH_MISMATCH",
                )
                for key, value in v2_values.items():
                    step_v2[key] += value
                for key, value in v3_values.items():
                    step_v3[key] += value
                if arm_key == "matched_zero_command" and not _close(
                    v3_values["actuator"], 0.0
                ):
                    effective_matched_zero_nonzero_count += 1
                total_native_substeps += 1

            _require(
                _close(
                    retained_elapsed_s,
                    _number(native["time_after_s"], "time_after_s")
                    - _number(native["time_before_s"], "time_before_s"),
                ),
                "QSDK_R24D34_NATIVE_TIMESTEP_SUM_MISMATCH",
            )

            for key in cumulative_v2:
                cumulative_v2[key] += step_v2[key]
            for key in cumulative_v3:
                cumulative_v3[key] += step_v3[key]
            selected_fields = {
                "cumulative_actuator_work_j": cumulative_v3["actuator"],
                "step_effective_centered_actuator_work_j": step_v3["actuator"],
                "step_effective_centered_generalized_actuator_work_j": step_v3[
                    "generalized_actuator"
                ],
                "cumulative_effective_centered_actuator_work_j": cumulative_v3[
                    "actuator"
                ],
                "cumulative_effective_centered_generalized_actuator_work_j": (
                    cumulative_v3["generalized_actuator"]
                ),
                "step_constraint_work_j": step_v3["constraint"],
                "step_damper_work_j": step_v3["damper"],
                "step_fluid_work_j": step_v3["fluid"],
                "step_adhesion_work_j": step_v3["adhesion"],
                "step_dissipated_energy_j": step_v3["dissipated"],
                "cumulative_constraint_work_j": cumulative_v3["constraint"],
                "cumulative_damper_work_j": cumulative_v3["damper"],
                "cumulative_fluid_work_j": cumulative_v3["fluid"],
                "cumulative_adhesion_work_j": cumulative_v3["adhesion"],
                "cumulative_dissipated_energy_j": cumulative_v3["dissipated"],
                "historical_v2_step_actuator_work_j": step_v2["actuator"],
                "historical_v2_step_constraint_work_j": step_v2["constraint"],
                "historical_v2_step_damper_work_j": step_v2["damper"],
                "historical_v2_step_fluid_work_j": step_v2["fluid"],
                "historical_v2_step_adhesion_work_j": step_v2["adhesion"],
                "historical_v2_step_dissipated_energy_j": step_v2["dissipated"],
                "historical_v2_cumulative_actuator_work_j": cumulative_v2[
                    "actuator"
                ],
                "historical_v2_cumulative_constraint_work_j": cumulative_v2[
                    "constraint"
                ],
                "historical_v2_cumulative_damper_work_j": cumulative_v2["damper"],
                "historical_v2_cumulative_fluid_work_j": cumulative_v2["fluid"],
                "historical_v2_cumulative_adhesion_work_j": cumulative_v2[
                    "adhesion"
                ],
                "historical_v2_cumulative_dissipated_energy_j": cumulative_v2[
                    "dissipated"
                ],
            }
            for field, expected in selected_fields.items():
                _require(
                    _close(_number(native[field], field), expected),
                    f"QSDK_R24D34_OUTER_AGGREGATE_MISMATCH:{field}",
                )
            _require(
                _close(
                    _number(
                        native_receipt["application"]["step_actuator_work_j"],
                        "application.step_actuator_work_j",
                    ),
                    step_v3["actuator"],
                ),
                "QSDK_R24D34_APPLICATION_WORK_MAPPING_MISMATCH",
            )
            energy = observation["energy_balance"]
            _require(
                _close(
                    _number(
                        energy["cumulative_applied_actuator_work_j"],
                        "portable.cumulative_applied_actuator_work_j",
                    ),
                    cumulative_v3["actuator"],
                )
                and _close(
                    _number(
                        energy["cumulative_dissipated_energy_j"],
                        "portable.cumulative_dissipated_energy_j",
                    ),
                    cumulative_v3["dissipated"],
                )
                and energy["source_measurement"] is True,
                "QSDK_R24D34_NATIVE_PORTABLE_MAPPING_MISMATCH",
            )
            _require(
                cumulative_v3["dissipated"] >= 0.0,
                "QSDK_R24D34_CUMULATIVE_DISSIPATION_NEGATIVE",
            )
            total_outer_steps += 1
            _require(
                native["semantic_step"] == outer_index,
                "QSDK_R24D34_OUTER_STEP_ORDER",
            )

    _require(
        result["route_id"] == expected_route_id
        and result["outer_step_count"] == total_outer_steps
        and result["native_solver_step_count"] == total_native_substeps,
        "QSDK_R24D34_RESULT_COUNT_OR_ROUTE_MISMATCH",
    )
    return {
        "ok": True,
        "trace_validator_id": TRACE_VALIDATOR_ID,
        "energy_ledger_profile_id": runtime.IMPLICIT_STEP_ENERGY_LEDGER_PROFILE_ID,
        "historical_v2_energy_ledger_profile_id": runtime.ENERGY_LEDGER_PROFILE_ID,
        "arm_outer_steps": arm_outer_steps,
        "validated_outer_step_count": total_outer_steps,
        "validated_native_substep_count": total_native_substeps,
        "effective_matched_zero_nonzero_substep_count": (
            effective_matched_zero_nonzero_count
        ),
        "all_substeps_rederived_from_retained_pre_post_state": True,
        "all_v2_and_v3_aggregates_valid": True,
        "portable_v3_mapping_valid": True,
        "sparse_actuator_moment_expansion_required": (
            require_sparse_actuator_moment_expansion
        ),
        "sparse_actuator_moment_expansion_receipt_count": (
            sparse_expansion_receipt_count
        ),
    }


def synthetic_implicit_step_energy_trace_v1() -> dict[str, Any]:
    """Create a zero-world serialized fixture through the production receipt type."""

    dt = 0.1
    zero = (0.0,)

    def arm(
        *,
        target: tuple[float, ...],
        pre_velocity: tuple[float, ...],
        pre_force: tuple[float, ...],
        pre_qvel: tuple[float, ...],
        post_qvel: tuple[float, ...],
        qfrc_actuator: tuple[float, ...],
        qfrc_constraint: tuple[float, ...],
    ) -> dict[str, Any]:
        inputs = {
            "timestep_s": dt,
            "target_actuator_velocity_rad_s": target,
            "reported_pre_actuator_velocity_rad_s": pre_velocity,
            "reported_pre_actuator_force_nm": pre_force,
            "velocity_gain_nm_s_per_rad": (10.0,),
            "force_range_lower_nm": (-100.0,),
            "force_range_upper_nm": (100.0,),
            "actuator_moment": ((1.0,),),
            "pre_generalized_velocity": pre_qvel,
            "post_generalized_velocity": post_qvel,
            "reported_pre_generalized_actuator_force": qfrc_actuator,
            "reported_pre_generalized_constraint_force": qfrc_constraint,
            "reported_pre_generalized_damper_force": zero,
            "reported_pre_generalized_fluid_force": zero,
            "reported_pre_generalized_adhesion_force": zero,
        }
        v2 = runtime.measure_native_energy_work_v2(
            timestep_s=dt,
            actuator_force=pre_force,
            actuator_velocity=pre_velocity,
            generalized_velocity=pre_qvel,
            generalized_actuator_force=qfrc_actuator,
            generalized_constraint_force=qfrc_constraint,
            generalized_damper_force=zero,
            generalized_fluid_force=zero,
            generalized_adhesion_force=zero,
        )
        v3 = measure_implicit_step_energy_work_v3(**inputs)
        measurement = runtime.NativeImplicitStepEnergyV3(
            native_timestep_s=dt,
            target_actuator_velocity_rad_s=target,
            reported_pre_actuator_velocity_rad_s=pre_velocity,
            reported_pre_actuator_force_nm=pre_force,
            velocity_gain_nm_s_per_rad=(10.0,),
            force_range_lower_nm=(-100.0,),
            force_range_upper_nm=(100.0,),
            actuator_moment=((1.0,),),
            pre_generalized_velocity=pre_qvel,
            post_generalized_velocity=post_qvel,
            reported_pre_generalized_actuator_force=qfrc_actuator,
            reported_pre_generalized_constraint_force=qfrc_constraint,
            reported_pre_generalized_damper_force=zero,
            reported_pre_generalized_fluid_force=zero,
            reported_pre_generalized_adhesion_force=zero,
            historical_v2=v2,
            implicit_v3=v3,
        )
        count = 5
        substeps = [measurement.receipt_v1(index) for index in range(count)]
        v2_actuator = count * v2.actuator_work_j
        v2_constraint = count * v2.constraint_work_j
        v2_dissipated = count * v2.dissipated_energy_j
        v3_actuator = count * v3.effective_centered_actuator_work_j
        v3_generalized = count * v3.effective_centered_generalized_actuator_work_j
        v3_constraint = count * v3.centered_constraint_work_j
        v3_dissipated = count * v3.centered_dissipated_energy_j
        native = {
            "schema_version": runtime.IMPLICIT_STEP_NATIVE_RECEIPT_SCHEMA,
            "route_id": runtime.IMPLICIT_STEP_ROUTE_ID,
            "semantic_step": 0,
            "time_before_s": 0.0,
            "time_after_s": count * dt,
            "native_substep_count": count,
            "energy_ledger_profile_id": runtime.IMPLICIT_STEP_ENERGY_LEDGER_PROFILE_ID,
            "historical_v2_energy_ledger_profile_id": runtime.ENERGY_LEDGER_PROFILE_ID,
            "cumulative_actuator_work_j": v3_actuator,
            "step_constraint_work_j": v3_constraint,
            "step_damper_work_j": 0.0,
            "step_fluid_work_j": 0.0,
            "step_adhesion_work_j": 0.0,
            "step_dissipated_energy_j": v3_dissipated,
            "cumulative_constraint_work_j": v3_constraint,
            "cumulative_damper_work_j": 0.0,
            "cumulative_fluid_work_j": 0.0,
            "cumulative_adhesion_work_j": 0.0,
            "cumulative_dissipated_energy_j": v3_dissipated,
            "historical_v2_step_actuator_work_j": v2_actuator,
            "historical_v2_step_constraint_work_j": v2_constraint,
            "historical_v2_step_damper_work_j": 0.0,
            "historical_v2_step_fluid_work_j": 0.0,
            "historical_v2_step_adhesion_work_j": 0.0,
            "historical_v2_step_dissipated_energy_j": v2_dissipated,
            "historical_v2_cumulative_actuator_work_j": v2_actuator,
            "historical_v2_cumulative_constraint_work_j": v2_constraint,
            "historical_v2_cumulative_damper_work_j": 0.0,
            "historical_v2_cumulative_fluid_work_j": 0.0,
            "historical_v2_cumulative_adhesion_work_j": 0.0,
            "historical_v2_cumulative_dissipated_energy_j": v2_dissipated,
            "step_effective_centered_actuator_work_j": v3_actuator,
            "step_effective_centered_generalized_actuator_work_j": v3_generalized,
            "cumulative_effective_centered_actuator_work_j": v3_actuator,
            "cumulative_effective_centered_generalized_actuator_work_j": v3_generalized,
            "implicit_substep_energy_receipts": substeps,
        }
        return {
            "observations": [
                {
                    "energy_balance": {
                        "cumulative_applied_actuator_work_j": v3_actuator,
                        "cumulative_dissipated_energy_j": v3_dissipated,
                        "source_measurement": True,
                    }
                }
            ],
            "native_receipts": [
                {
                    "native_step": native,
                    "application": {"step_actuator_work_j": v3_actuator},
                }
            ],
            "portable_step_receipts": [{}],
        }

    return {
        "route_id": runtime.IMPLICIT_STEP_ROUTE_ID,
        "candidate": arm(
            target=(1.0,),
            pre_velocity=(0.0,),
            pre_force=(10.0,),
            pre_qvel=(0.0,),
            post_qvel=(1.0 / 3.0,),
            qfrc_actuator=(10.0,),
            qfrc_constraint=zero,
        ),
        "matched_zero_command": arm(
            target=(1.0,),
            pre_velocity=(1.0,),
            pre_force=(0.0,),
            pre_qvel=(1.0,),
            post_qvel=(0.8,),
            qfrc_actuator=(0.0,),
            qfrc_constraint=(-4.0,),
        ),
        "outer_step_count": 2,
        "native_solver_step_count": 10,
    }


def synthetic_sparse_actuator_moment_trace_v1() -> dict[str, Any]:
    """Promote the zero-world trace fixture through the exact R35 receipt seam."""

    result = deepcopy(synthetic_implicit_step_energy_trace_v1())
    expansion = expand_sparse_actuator_moment_v1(
        values=[1.0],
        rownnz=[1],
        rowadr=[0],
        colind=[0],
        nout=1,
        nv=1,
        nJmom=1,
    ).receipt_v1()
    result["route_id"] = runtime.SPARSE_MOMENT_IMPLICIT_STEP_ROUTE_ID
    for arm_key in ("candidate", "matched_zero_command"):
        for retained in result[arm_key]["native_receipts"]:
            native = retained["native_step"]
            native["schema_version"] = (
                runtime.SPARSE_MOMENT_IMPLICIT_STEP_NATIVE_RECEIPT_SCHEMA
            )
            native["route_id"] = runtime.SPARSE_MOMENT_IMPLICIT_STEP_ROUTE_ID
            for substep in native["implicit_substep_energy_receipts"]:
                substep["schema_version"] = (
                    runtime.SPARSE_MOMENT_IMPLICIT_SUBSTEP_RECEIPT_SCHEMA
                )
                substep["actuator_moment_expansion"] = deepcopy(expansion)
                substep["actuator_moment_expansion_profile_id"] = (
                    SPARSE_ACTUATOR_MOMENT_PROFILE_ID
                )
    return result


def sparse_actuator_moment_trace_zero_world_controls_v1() -> tuple[dict[str, bool], dict[str, Any]]:
    """Replay R35 receipts and reject sparse/dense retained-trace mutations."""

    def validate(value: Mapping[str, Any]) -> dict[str, Any]:
        return validate_implicit_step_energy_trace_v1(
            value,
            expected_route_id=runtime.SPARSE_MOMENT_IMPLICIT_STEP_ROUTE_ID,
            expected_native_receipt_schema=(
                runtime.SPARSE_MOMENT_IMPLICIT_STEP_NATIVE_RECEIPT_SCHEMA
            ),
            require_sparse_actuator_moment_expansion=True,
        )

    replayed = validate(synthetic_sparse_actuator_moment_trace_v1())

    def rejected(path: str, expected: str) -> bool:
        value = synthetic_sparse_actuator_moment_trace_v1()
        substep = value["candidate"]["native_receipts"][0]["native_step"][
            "implicit_substep_energy_receipts"
        ][0]
        if path == "expansion":
            substep["actuator_moment_expansion"]["dense_actuator_moment"] = [[2.0]]
        else:
            substep["actuator_moment"] = [[2.0]]
        try:
            validate(value)
        except ImplicitStepEnergyTraceError as error:
            return expected in str(error)
        return False

    controls = {
        "complete_sparse_trace_replayed": (
            replayed["validated_native_substep_count"] == 10
            and replayed["sparse_actuator_moment_expansion_receipt_count"] == 10
        ),
        "retained_sparse_and_dense_mutations_refused": (
            rejected("expansion", "QSDK_R24D35_SPARSE_EXPANSION_RECEIPT_INVALID")
            and rejected("observer", "QSDK_R24D35_SPARSE_EXPANSION_DENSE_MISMATCH")
        ),
    }
    return controls, {
        "validated_native_substep_count": replayed["validated_native_substep_count"],
        "sparse_expansion_receipt_count": replayed[
            "sparse_actuator_moment_expansion_receipt_count"
        ],
    }
