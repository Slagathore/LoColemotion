"""Pure R24D36 native-component to portable recovery-energy V2 mapping.

The historical R24D36 route remains a strict portable-V1 route and therefore
continues to refuse signed constraint work.  This additive seam consumes its
already-versioned per-substep receipts, replays the measured implicit-step
terms, and delegates ordered V2 aggregation to the engine-neutral core.  It
does not import MuJoCo, construct a model, step a world, or apply a threshold.
"""

from __future__ import annotations

from copy import deepcopy
import math
from typing import Any, Mapping, Sequence

from . import energy_work_projection as r24d36_projection
from .implicit_step_energy import (
    PROFILE_ID as IMPLICIT_STEP_ENERGY_PROFILE_ID,
    ImplicitStepEnergyError,
    measure_implicit_step_energy_work_v3,
)


MAPPING_PROFILE_ID = "mujoco_r24d36_native_components_to_recovery_energy_v2_v1"
MAPPING_REQUEST_SCHEMA = "sporespore_mujoco_recovery_energy_v2_mapping_request_v1"
MAPPING_RECEIPT_SCHEMA = "sporespore_mujoco_recovery_energy_v2_mapping_receipt_v1"
PORTABLE_OBSERVATION_V2_SCHEMA = "sporespore_recovery_observation_v2"
LEDGER_AGGREGATION_REQUEST_SCHEMA = (
    "sporespore_recovery_energy_balance_aggregation_request_v2"
)
R24D36_ROUTE_ID = "sporespore_mujoco_exact_s169_native_recovery_implicit_step_energy_v3"
R24D36_SUBSTEP_SCHEMA = "sporespore_mujoco_implicit_substep_energy_receipt_v3"
R24D36_NATIVE_SUBSTEPS_PER_OUTER_STEP = 5
ACTUATOR_WORK_CROSSCHECK_TOLERANCE_J = 1.0e-10
SPARSE_ACTUATOR_MOMENT_PROFILE_ID = "mujoco_3_11_sparse_actuator_moment_to_dense_v1"
SPARSE_ACTUATOR_MOMENT_RECEIPT_SCHEMA = (
    "sporespore_mujoco_sparse_actuator_moment_expansion_v1"
)

_REQUEST_KEYS = frozenset(
    {
        "schema_version",
        "source_route_id",
        "initial_mechanical_energy_j",
        "current_mechanical_energy_j",
        "observation_base",
        "ordered_native_component_batches",
    }
)
_BATCH_KEYS = frozenset({"semantic_step", "ordered_substep_receipts"})
_OBSERVATION_BASE_KEYS = frozenset(
    {
        "task_id",
        "semantics_id",
        "actuator_profile_id",
        "semantic_step",
        "outer_step_duration_s",
        "state",
        "center_of_mass",
        "ordered_foot_bearing_observations",
        "ordered_body_clearance_observations",
        "applied_actuation",
        "external_interventions",
        "controller_ownership",
        "engine_step_identity",
    }
)
_INTERVENTION_KEYS = frozenset(
    {
        "root_force_application_count",
        "root_torque_application_count",
        "root_impulse_application_count",
        "root_pose_write_count",
        "root_velocity_write_count",
        "pin_or_guide_constraint_count",
        "hidden_body_actuation_count",
        "pose_teleport_count",
        "collision_disable_count",
        "contact_relabel_count",
        "gravity_mutation_count",
        "time_scale_mutation_count",
        "engine_specific_policy_branch_count",
    }
)
_ENGINE_STEP_IDENTITY_KEYS = frozenset(
    {
        "schema_version",
        "source_kind",
        "adapter_id",
        "engine",
        "capability_sha256",
        "source_trace_sha256",
        "semantic_step",
        "host_step_before",
        "host_step_after",
        "native_solver_substep_count",
        "post_step_observation",
        "engine_identity_exposed_to_policy",
    }
)
_SUBSTEP_KEYS = frozenset(
    {
        "schema_version",
        "measurement_profile_id",
        "native_substep",
        "native_timestep_s",
        "preintegration_stage",
        "target_actuator_velocity_rad_s",
        "reported_pre_actuator_velocity_rad_s",
        "reported_pre_actuator_force_nm",
        "velocity_gain_nm_s_per_rad",
        "force_range_lower_nm",
        "force_range_upper_nm",
        "actuator_moment",
        "pre_generalized_velocity",
        "post_generalized_velocity",
        "reported_pre_generalized_actuator_force",
        "reported_pre_generalized_constraint_force",
        "reported_pre_generalized_damper_force",
        "reported_pre_generalized_fluid_force",
        "reported_pre_generalized_adhesion_force",
        "historical_v2",
        "implicit_v3",
        "actuator_moment_expansion",
        "actuator_moment_expansion_profile_id",
        "historical_v2_energy_preprojection",
        "portable_v3_energy_preprojection",
        "energy_work_preprojection_profile_id",
    }
)
_HISTORICAL_V2_KEYS = frozenset(
    {
        "energy_ledger_profile_id",
        "left_endpoint_actuator_work_j",
        "left_endpoint_generalized_actuator_work_j",
        "left_endpoint_constraint_work_j",
        "left_endpoint_damper_work_j",
        "left_endpoint_fluid_work_j",
        "left_endpoint_adhesion_work_j",
        "left_endpoint_dissipated_energy_j",
    }
)
_IMPLICIT_V3_KEYS = frozenset(
    {
        "energy_ledger_profile_id",
        "effective_implicit_actuator_force_nm",
        "force_limited_at_pre_step",
        "effective_centered_actuator_work_j",
        "effective_centered_generalized_actuator_work_j",
        "centered_constraint_work_j",
        "centered_damper_work_j",
        "centered_fluid_work_j",
        "centered_adhesion_work_j",
        "centered_dissipated_energy_j",
    }
)
_SPARSE_EXPANSION_KEYS = frozenset(
    {
        "schema_version",
        "profile_id",
        "public_expansion_function",
        "independent_dense_crosscheck_passed",
        "nout",
        "nv",
        "nJmom",
        "sparse_values",
        "moment_rownnz",
        "moment_rowadr",
        "moment_colind",
        "dense_actuator_moment",
    }
)


class RecoveryEnergyV2MappingError(ValueError):
    """Stable fail-closed error for malformed or mutated mapping input."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise RecoveryEnergyV2MappingError(code)


def _exact_keys(value: Any, expected: frozenset[str], code: str) -> Mapping[str, Any]:
    _require(isinstance(value, Mapping), code)
    _require(frozenset(value) == expected, code)
    return value


def _finite(value: Any, code: str) -> float:
    _require(isinstance(value, (int, float)) and not isinstance(value, bool), code)
    result = float(value)
    _require(math.isfinite(result), code)
    return result


def _exact_nonnegative_integer(value: Any, code: str) -> int:
    _require(
        isinstance(value, int) and not isinstance(value, bool) and value >= 0, code
    )
    _require(value <= 9_007_199_254_740_991, code)
    return value


def _valid_digest(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 71
        and value.startswith("sha256:")
        and all(character in "0123456789abcdef" for character in value[7:])
    )


def _close(left: float, right: float) -> bool:
    return abs(left - right) <= ACTUATOR_WORK_CROSSCHECK_TOLERANCE_J


def _canonical_sha256(core: Any, value: Any) -> str:
    receipt = core.canonicalize_json(value)
    digest = receipt.get("sha256")
    _require(_valid_digest(digest), "QSDK_R24D38_CANONICAL_DIGEST_INVALID")
    return str(digest)


def _validate_sparse_expansion_receipt(value: Any) -> list[list[float]]:
    """Replay the retained CSR values without importing MuJoCo or NumPy."""

    receipt = _exact_keys(
        value,
        _SPARSE_EXPANSION_KEYS,
        "QSDK_R24D38_SPARSE_EXPANSION_FIELDS_INVALID",
    )
    _require(
        receipt["schema_version"] == SPARSE_ACTUATOR_MOMENT_RECEIPT_SCHEMA
        and receipt["profile_id"] == SPARSE_ACTUATOR_MOMENT_PROFILE_ID
        and receipt["public_expansion_function"] == "mju_sparse2dense"
        and receipt["independent_dense_crosscheck_passed"] is True,
        "QSDK_R24D38_SPARSE_EXPANSION_IDENTITY_INVALID",
    )
    nout = _exact_nonnegative_integer(
        receipt["nout"],
        "QSDK_R24D38_SPARSE_NOUT_INVALID",
    )
    nv = _exact_nonnegative_integer(
        receipt["nv"],
        "QSDK_R24D38_SPARSE_NV_INVALID",
    )
    nonzero_count = _exact_nonnegative_integer(
        receipt["nJmom"],
        "QSDK_R24D38_SPARSE_COUNT_INVALID",
    )
    _require(nout > 0 and nv > 0, "QSDK_R24D38_SPARSE_DIMENSION_INVALID")
    values = receipt["sparse_values"]
    row_counts = receipt["moment_rownnz"]
    row_addresses = receipt["moment_rowadr"]
    column_indices = receipt["moment_colind"]
    _require(
        all(
            isinstance(sequence, Sequence) and not isinstance(sequence, (str, bytes))
            for sequence in (values, row_counts, row_addresses, column_indices)
        )
        and len(values) == len(column_indices) == nonzero_count
        and len(row_counts) == len(row_addresses) == nout,
        "QSDK_R24D38_SPARSE_CARDINALITY_INVALID",
    )
    finite_values = [
        _finite(item, "QSDK_R24D38_SPARSE_VALUE_INVALID") for item in values
    ]
    counts = [
        _exact_nonnegative_integer(
            item,
            "QSDK_R24D38_SPARSE_ROW_COUNT_INVALID",
        )
        for item in row_counts
    ]
    addresses = [
        _exact_nonnegative_integer(
            item,
            "QSDK_R24D38_SPARSE_ROW_ADDRESS_INVALID",
        )
        for item in row_addresses
    ]
    columns = [
        _exact_nonnegative_integer(
            item,
            "QSDK_R24D38_SPARSE_COLUMN_INVALID",
        )
        for item in column_indices
    ]
    _require(sum(counts) == nonzero_count, "QSDK_R24D38_SPARSE_TOTAL_INVALID")
    dense = [[0.0 for _ in range(nv)] for _ in range(nout)]
    expected_address = 0
    for row, (count, address) in enumerate(zip(counts, addresses, strict=True)):
        _require(
            address == expected_address and address + count <= nonzero_count,
            "QSDK_R24D38_SPARSE_PACKING_INVALID",
        )
        selected = columns[address : address + count]
        _require(
            len(set(selected)) == count and all(column < nv for column in selected),
            "QSDK_R24D38_SPARSE_COLUMN_INVALID",
        )
        for offset, column in enumerate(selected):
            dense[row][column] = finite_values[address + offset]
        expected_address += count
    _require(
        expected_address == nonzero_count and receipt["dense_actuator_moment"] == dense,
        "QSDK_R24D38_SPARSE_DENSE_MISMATCH",
    )
    return dense


def _validate_observation_base(
    value: Any,
    *,
    final_semantic_step: int,
    final_native_substep_count: int,
) -> tuple[dict[str, Any], bool]:
    base = _exact_keys(
        value,
        _OBSERVATION_BASE_KEYS,
        "QSDK_R24D38_OBSERVATION_BASE_FIELDS_INVALID",
    )
    _require(
        all(
            isinstance(base[field], str) and bool(base[field])
            for field in ("task_id", "semantics_id", "actuator_profile_id")
        ),
        "QSDK_R24D38_OBSERVATION_BASE_IDENTITY_INVALID",
    )
    _require(
        _exact_nonnegative_integer(
            base["semantic_step"],
            "QSDK_R24D38_OBSERVATION_SEMANTIC_STEP_INVALID",
        )
        == final_semantic_step,
        "QSDK_R24D38_OBSERVATION_SEMANTIC_STEP_MISMATCH",
    )
    _require(
        _finite(
            base["outer_step_duration_s"],
            "QSDK_R24D38_OUTER_STEP_DURATION_INVALID",
        )
        > 0.0,
        "QSDK_R24D38_OUTER_STEP_DURATION_INVALID",
    )

    interventions = _exact_keys(
        base["external_interventions"],
        _INTERVENTION_KEYS,
        "QSDK_R24D38_EXTERNAL_INTERVENTION_LEDGER_INVALID",
    )
    intervention_total = sum(
        _exact_nonnegative_integer(
            interventions[field],
            "QSDK_R24D38_EXTERNAL_INTERVENTION_COUNT_INVALID",
        )
        for field in sorted(_INTERVENTION_KEYS)
    )

    identity = _exact_keys(
        base["engine_step_identity"],
        _ENGINE_STEP_IDENTITY_KEYS,
        "QSDK_R24D38_ENGINE_STEP_IDENTITY_FIELDS_INVALID",
    )
    _require(
        identity["schema_version"] == "sporespore_recovery_engine_step_identity_v1"
        and identity["source_kind"] == "native_post_step"
        and identity["adapter_id"] == "sporespore_mujoco_adapter"
        and identity["engine"] == "mujoco_native"
        and _valid_digest(identity["capability_sha256"])
        and _valid_digest(identity["source_trace_sha256"])
        and identity["post_step_observation"] is True
        and identity["engine_identity_exposed_to_policy"] is False,
        "QSDK_R24D38_ENGINE_STEP_IDENTITY_INVALID",
    )
    semantic_step = _exact_nonnegative_integer(
        identity["semantic_step"],
        "QSDK_R24D38_ENGINE_SEMANTIC_STEP_INVALID",
    )
    host_before = _exact_nonnegative_integer(
        identity["host_step_before"],
        "QSDK_R24D38_ENGINE_HOST_STEP_INVALID",
    )
    host_after = _exact_nonnegative_integer(
        identity["host_step_after"],
        "QSDK_R24D38_ENGINE_HOST_STEP_INVALID",
    )
    native_substeps = _exact_nonnegative_integer(
        identity["native_solver_substep_count"],
        "QSDK_R24D38_ENGINE_SUBSTEP_COUNT_INVALID",
    )
    _require(
        semantic_step == final_semantic_step
        and host_before == final_semantic_step
        and host_after == host_before + 1
        and native_substeps == final_native_substep_count,
        "QSDK_R24D38_ENGINE_STEP_IDENTITY_ORDER_MISMATCH",
    )
    return deepcopy(dict(base)), intervention_total == 0


def _validate_replayed_substep(
    value: Any,
    *,
    expected_native_substep: int,
) -> dict[str, float]:
    receipt = _exact_keys(
        value,
        _SUBSTEP_KEYS,
        "QSDK_R24D38_SUBSTEP_FIELDS_INVALID",
    )
    _require(
        receipt["schema_version"] == R24D36_SUBSTEP_SCHEMA
        and receipt["measurement_profile_id"] == IMPLICIT_STEP_ENERGY_PROFILE_ID
        and receipt["energy_work_preprojection_profile_id"]
        == r24d36_projection.PROFILE_ID
        and receipt["preintegration_stage"]
        == "after_mj_fwd_constraint_and_mj_check_acc_before_mj_implicit"
        and _exact_nonnegative_integer(
            receipt["native_substep"],
            "QSDK_R24D38_NATIVE_SUBSTEP_INVALID",
        )
        == expected_native_substep,
        "QSDK_R24D38_SUBSTEP_IDENTITY_INVALID",
    )
    _require(
        _finite(
            receipt["native_timestep_s"],
            "QSDK_R24D38_NATIVE_TIMESTEP_INVALID",
        )
        > 0.0,
        "QSDK_R24D38_NATIVE_TIMESTEP_INVALID",
    )

    historical = _exact_keys(
        receipt["historical_v2"],
        _HISTORICAL_V2_KEYS,
        "QSDK_R24D38_HISTORICAL_COMPONENT_FIELDS_INVALID",
    )
    implicit = _exact_keys(
        receipt["implicit_v3"],
        _IMPLICIT_V3_KEYS,
        "QSDK_R24D38_IMPLICIT_COMPONENT_FIELDS_INVALID",
    )
    _require(
        implicit["energy_ledger_profile_id"] == IMPLICIT_STEP_ENERGY_PROFILE_ID,
        "QSDK_R24D38_IMPLICIT_PROFILE_INVALID",
    )

    passive_measurement_refused = False
    try:
        replayed = measure_implicit_step_energy_work_v3(
            timestep_s=receipt["native_timestep_s"],
            target_actuator_velocity_rad_s=receipt["target_actuator_velocity_rad_s"],
            reported_pre_actuator_velocity_rad_s=receipt[
                "reported_pre_actuator_velocity_rad_s"
            ],
            reported_pre_actuator_force_nm=receipt["reported_pre_actuator_force_nm"],
            velocity_gain_nm_s_per_rad=receipt["velocity_gain_nm_s_per_rad"],
            force_range_lower_nm=receipt["force_range_lower_nm"],
            force_range_upper_nm=receipt["force_range_upper_nm"],
            actuator_moment=receipt["actuator_moment"],
            pre_generalized_velocity=receipt["pre_generalized_velocity"],
            post_generalized_velocity=receipt["post_generalized_velocity"],
            reported_pre_generalized_actuator_force=receipt[
                "reported_pre_generalized_actuator_force"
            ],
            reported_pre_generalized_constraint_force=receipt[
                "reported_pre_generalized_constraint_force"
            ],
            reported_pre_generalized_damper_force=receipt[
                "reported_pre_generalized_damper_force"
            ],
            reported_pre_generalized_fluid_force=receipt[
                "reported_pre_generalized_fluid_force"
            ],
            reported_pre_generalized_adhesion_force=receipt[
                "reported_pre_generalized_adhesion_force"
            ],
        )
    except ImplicitStepEnergyError as error:
        if str(error) == "QSDK_R24D33_UNQUALIFIED_IMPLICIT_PASSIVE_FORCE":
            passive_measurement_refused = True
            replayed = None
        else:
            raise RecoveryEnergyV2MappingError(
                "QSDK_R24D38_IMPLICIT_COMPONENT_REPLAY_FAILED"
            ) from error
    except (KeyError, TypeError, ValueError) as error:
        raise RecoveryEnergyV2MappingError(
            "QSDK_R24D38_IMPLICIT_COMPONENT_REPLAY_FAILED"
        ) from error

    if replayed is not None:
        for field in (
            "effective_centered_actuator_work_j",
            "effective_centered_generalized_actuator_work_j",
            "centered_constraint_work_j",
            "centered_damper_work_j",
            "centered_fluid_work_j",
            "centered_adhesion_work_j",
            "centered_dissipated_energy_j",
        ):
            _require(
                _close(
                    _finite(
                        implicit[field],
                        f"QSDK_R24D38_IMPLICIT_VALUE_INVALID:{field}",
                    ),
                    float(getattr(replayed, field)),
                ),
                f"QSDK_R24D38_IMPLICIT_COMPONENT_REPLAY_MISMATCH:{field}",
            )
        _require(
            tuple(implicit["effective_implicit_actuator_force_nm"])
            == replayed.effective_implicit_actuator_force_nm
            and tuple(implicit["force_limited_at_pre_step"])
            == replayed.force_limited_at_pre_step,
            "QSDK_R24D38_IMPLICIT_VECTOR_REPLAY_MISMATCH",
        )

    expansion = _validate_sparse_expansion_receipt(receipt["actuator_moment_expansion"])
    _require(
        receipt["actuator_moment_expansion_profile_id"]
        == SPARSE_ACTUATOR_MOMENT_PROFILE_ID
        and expansion == receipt["actuator_moment"],
        "QSDK_R24D38_SPARSE_ACTUATOR_MOMENT_MISMATCH",
    )

    try:
        historical_projection = (
            r24d36_projection.validate_energy_work_preprojection_receipt_v1(
                receipt["historical_v2_energy_preprojection"]
            )
        )
        portable_projection = (
            r24d36_projection.validate_energy_work_preprojection_receipt_v1(
                receipt["portable_v3_energy_preprojection"]
            )
        )
    except (r24d36_projection.EnergyWorkProjectionError, KeyError) as error:
        raise RecoveryEnergyV2MappingError(
            "QSDK_R24D38_R24D36_PREPROJECTION_REPLAY_FAILED"
        ) from error

    _require(
        historical_projection.constraint_work_j
        == _finite(
            historical["left_endpoint_constraint_work_j"],
            "QSDK_R24D38_HISTORICAL_CONSTRAINT_INVALID",
        )
        and historical_projection.damper_work_j
        == _finite(
            historical["left_endpoint_damper_work_j"],
            "QSDK_R24D38_HISTORICAL_DAMPER_INVALID",
        )
        and historical_projection.fluid_work_j
        == _finite(
            historical["left_endpoint_fluid_work_j"],
            "QSDK_R24D38_HISTORICAL_FLUID_INVALID",
        )
        and historical_projection.adhesion_work_j
        == _finite(
            historical["left_endpoint_adhesion_work_j"],
            "QSDK_R24D38_HISTORICAL_ADHESION_INVALID",
        ),
        "QSDK_R24D38_HISTORICAL_PREPROJECTION_MISMATCH",
    )

    actuator = _finite(
        implicit["effective_centered_actuator_work_j"],
        "QSDK_R24D38_ACTUATOR_WORK_INVALID",
    )
    generalized_actuator = _finite(
        implicit["effective_centered_generalized_actuator_work_j"],
        "QSDK_R24D38_GENERALIZED_ACTUATOR_WORK_INVALID",
    )
    constraint = _finite(
        implicit["centered_constraint_work_j"],
        "QSDK_R24D38_CONSTRAINT_WORK_INVALID",
    )
    damper = _finite(
        implicit["centered_damper_work_j"],
        "QSDK_R24D38_DAMPER_WORK_INVALID",
    )
    fluid = _finite(
        implicit["centered_fluid_work_j"],
        "QSDK_R24D38_FLUID_WORK_INVALID",
    )
    adhesion = _finite(
        implicit["centered_adhesion_work_j"],
        "QSDK_R24D38_ADHESION_WORK_INVALID",
    )
    _require(
        _close(actuator, generalized_actuator),
        "QSDK_R24D38_ACTUATOR_WORK_CROSSCHECK_FAILED",
    )
    _require(
        portable_projection.constraint_work_j == constraint
        and portable_projection.damper_work_j == damper
        and portable_projection.fluid_work_j == fluid
        and portable_projection.adhesion_work_j == adhesion,
        "QSDK_R24D38_PORTABLE_PREPROJECTION_MISMATCH",
    )
    passive_is_exact_zero = damper == fluid == adhesion == 0.0
    _require(
        passive_measurement_refused is (not passive_is_exact_zero),
        "QSDK_R24D38_PASSIVE_SUPPORT_CLASSIFICATION_MISMATCH",
    )
    return {
        "applied_actuator_work_j": actuator,
        "signed_constraint_exchange_j": constraint,
        "signed_damper_work_j": damper,
        "signed_fluid_work_j": fluid,
        "signed_adhesion_work_j": adhesion,
    }


def map_r24d36_components_to_recovery_observation_v2(
    core: Any,
    request: Mapping[str, Any],
) -> dict[str, Any]:
    """Map complete ordered R24D36 component receipts into one V2 observation.

    Malformed or mutated evidence raises :class:`RecoveryEnergyV2MappingError`.
    A well-formed source outside the currently qualified passive/external-work
    subset returns an ordinary typed refusal receipt retaining exact source
    values and digests.
    """

    request = _exact_keys(
        request,
        _REQUEST_KEYS,
        "QSDK_R24D38_MAPPING_REQUEST_FIELDS_INVALID",
    )
    _require(
        request["schema_version"] == MAPPING_REQUEST_SCHEMA
        and request["source_route_id"] == R24D36_ROUTE_ID,
        "QSDK_R24D38_MAPPING_REQUEST_IDENTITY_INVALID",
    )
    initial_energy = _finite(
        request["initial_mechanical_energy_j"],
        "QSDK_R24D38_INITIAL_MECHANICAL_ENERGY_INVALID",
    )
    current_energy = _finite(
        request["current_mechanical_energy_j"],
        "QSDK_R24D38_CURRENT_MECHANICAL_ENERGY_INVALID",
    )
    batches = request["ordered_native_component_batches"]
    _require(
        isinstance(batches, Sequence)
        and not isinstance(batches, (str, bytes))
        and bool(batches),
        "QSDK_R24D38_COMPONENT_BATCHES_INVALID",
    )

    ordered_increments: list[dict[str, Any]] = []
    ordered_component_mappings: list[dict[str, Any]] = []
    prior_semantic_step: int | None = None
    final_native_substep_count = 0
    has_unqualified_passive = False
    for batch_index, untyped_batch in enumerate(batches):
        batch = _exact_keys(
            untyped_batch,
            _BATCH_KEYS,
            "QSDK_R24D38_COMPONENT_BATCH_FIELDS_INVALID",
        )
        semantic_step = _exact_nonnegative_integer(
            batch["semantic_step"],
            "QSDK_R24D38_COMPONENT_SEMANTIC_STEP_INVALID",
        )
        if prior_semantic_step is not None:
            _require(
                semantic_step == prior_semantic_step + 1,
                "QSDK_R24D38_COMPONENT_BATCH_ORDER_INVALID",
            )
        prior_semantic_step = semantic_step
        substeps = batch["ordered_substep_receipts"]
        _require(
            isinstance(substeps, Sequence)
            and not isinstance(substeps, (str, bytes))
            and len(substeps) == R24D36_NATIVE_SUBSTEPS_PER_OUTER_STEP,
            "QSDK_R24D38_COMPONENT_SUBSTEP_COUNT_INVALID",
        )
        final_native_substep_count = len(substeps)
        for native_substep, substep in enumerate(substeps):
            components = _validate_replayed_substep(
                substep,
                expected_native_substep=native_substep,
            )
            sequence_index = len(ordered_increments)
            passive_is_exact_zero = (
                components["signed_damper_work_j"]
                == components["signed_fluid_work_j"]
                == components["signed_adhesion_work_j"]
                == 0.0
            )
            has_unqualified_passive = (
                has_unqualified_passive or not passive_is_exact_zero
            )
            ordered_component_mappings.append(
                {
                    "sequence_index": sequence_index,
                    "batch_index": batch_index,
                    "semantic_step": semantic_step,
                    "native_substep": native_substep,
                    **components,
                    "signed_external_work_j": 0.0,
                    "passive_dissipation_j": (0.0 if passive_is_exact_zero else None),
                    "source_measurement": True,
                }
            )
            if passive_is_exact_zero:
                ordered_increments.append(
                    {
                        "sequence_index": sequence_index,
                        "semantic_step": semantic_step,
                        "applied_actuator_work_j": components[
                            "applied_actuator_work_j"
                        ],
                        "signed_external_work_j": 0.0,
                        "signed_constraint_exchange_j": components[
                            "signed_constraint_exchange_j"
                        ],
                        "passive_dissipation_j": 0.0,
                        "source_measurement": True,
                    }
                )

    _require(
        prior_semantic_step is not None,
        "QSDK_R24D38_COMPONENT_BATCHES_INVALID",
    )
    observation_base, no_external_intervention = _validate_observation_base(
        request["observation_base"],
        final_semantic_step=prior_semantic_step,
        final_native_substep_count=final_native_substep_count,
    )
    source_payload = {
        "source_route_id": request["source_route_id"],
        "ordered_native_component_batches": deepcopy(list(batches)),
    }
    source_component_receipts_sha256 = _canonical_sha256(core, source_payload)
    observation_base_sha256 = _canonical_sha256(core, observation_base)
    request_sha256 = _canonical_sha256(core, dict(request))

    common = {
        "schema_version": MAPPING_RECEIPT_SCHEMA,
        "mapping_profile_id": MAPPING_PROFILE_ID,
        "source_route_id": R24D36_ROUTE_ID,
        "source_substep_schema": R24D36_SUBSTEP_SCHEMA,
        "request_sha256": request_sha256,
        "source_component_receipts_sha256": source_component_receipts_sha256,
        "observation_base_sha256": observation_base_sha256,
        "native_component_batch_count": len(batches),
        "native_component_receipt_count": len(ordered_component_mappings),
        "first_semantic_step": ordered_component_mappings[0]["semantic_step"],
        "last_semantic_step": ordered_component_mappings[-1]["semantic_step"],
        "first_sequence_index": 0,
        "last_sequence_index": len(ordered_component_mappings) - 1,
        "ordered_component_mappings": ordered_component_mappings,
        "component_partition": {
            "actuator": "implicit_v3.effective_centered_actuator_work_j",
            "external": "exact_zero_only_when_intervention_ledger_is_zero",
            "constraint": "implicit_v3.centered_constraint_work_j_signed",
            "passive": (
                "exact_zero_only_for_r24d36_qualified_damper_fluid_adhesion_subset"
            ),
            "mechanical_energy_change_used_as_work_source": False,
            "energy_balance_residual_used_as_work_source": False,
        },
        "threshold_applied": False,
        "physical_result": False,
        "native_engine_execution_executed": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    if has_unqualified_passive or not no_external_intervention:
        reason = (
            r24d36_projection.PASSIVE_WORK_REFUSAL
            if has_unqualified_passive
            else "nonzero_external_intervention_work_unmeasured"
        )
        return {
            **common,
            "support_status": "unsupported_capability",
            "refusal_reason": reason,
            "ordered_increments": None,
            "ordered_source_values_sha256": None,
            "ledger_sha256": None,
            "ledger_aggregation_receipt": None,
            "portable_observation_sha256": None,
            "portable_observation": None,
        }

    aggregation = core.recovery_energy_balance_aggregate_v2(
        {
            "schema_version": LEDGER_AGGREGATION_REQUEST_SCHEMA,
            "source_profile_id": MAPPING_PROFILE_ID,
            "initial_mechanical_energy_j": initial_energy,
            "current_mechanical_energy_j": current_energy,
            "ordered_increments": ordered_increments,
        }
    )
    ledger = aggregation["ledger"]
    portable_observation = {
        "schema_version": PORTABLE_OBSERVATION_V2_SCHEMA,
        **observation_base,
        "energy_balance": ledger,
    }
    portable_observation_sha256 = _canonical_sha256(core, portable_observation)
    return {
        **common,
        "support_status": "supported_exact",
        "refusal_reason": None,
        "ordered_increments": ordered_increments,
        "ordered_source_values_sha256": aggregation["ordered_source_values_sha256"],
        "ledger_sha256": aggregation["ledger_sha256"],
        "ledger_aggregation_receipt": aggregation,
        "portable_observation_sha256": portable_observation_sha256,
        "portable_observation": portable_observation,
    }
