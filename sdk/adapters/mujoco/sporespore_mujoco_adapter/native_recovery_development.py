"""Genuine MuJoCo route for exact-s169 recovery development.

This durable adapter owns native model construction, deterministic prone-state
initialization, five-substep command application, and all ten measured recovery
channels.  It delegates phase supervision, controller targets, native snapshot
validation, and paired-trace evaluation to the engine-neutral Rust core.

Importing this module does not construct a model.  ``run_zero_world_preflight``
compiles the production XML and checks the installed API surface without
calling ``MjModel.from_xml_string``.  Physical entry is exposed only through
``run_paired_development`` and is expected to be wrapped by a clean-pushed,
operation-locked campaign supervisor.
"""

from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass
import json
import math
import struct
from typing import Any, Mapping, Sequence

import mujoco
import numpy as np

from sporespore_locomotion import LocomotionCore

from . import selected_policy_development as base
from .actuator_cap_profile import (
    PROFILE_ID as PUBLIC_ACTUATOR_PROFILE_ID,
    VELOCITY_GAIN_NM_S_PER_RAD,
)
from .implicit_step_energy import (
    PROFILE_ID as IMPLICIT_STEP_ENERGY_LEDGER_PROFILE_ID,
    ImplicitStepEnergyWorkV3,
    measure_implicit_step_energy_work_v3,
)
from .energy_work_projection import (
    PROFILE_ID as ENERGY_WORK_PREPROJECTION_PROFILE_ID,
    classify_energy_work_for_portable_v1,
    energy_work_projection_zero_world_controls_v1,
    summarize_energy_work_preprojections_v1,
)
from .qsdk_r23d65_public_profile_route import (
    CONFIGURATION_READBACK_TOLERANCE_NMS,
    ORDERED_ACTUATOR_IDS,
    ORDERED_CAPS_NMS,
    ORDERED_JOINT_IDS,
    PublicProfileModelRoute,
    compile_public_profile_model_route,
    physical_binding_receipt,
)
from .recovery_capability import (
    ACTUATOR_PROFILE_ID,
    ADAPTER_ID,
    ENGINE_ID,
    ENGINE_VERSION,
    SEMANTICS_ID,
    TASK_ID,
    mujoco_recovery_capability_v1,
)
from .recovery_runtime import (
    CONTROLLER_ID,
    NATIVE_SUBSTEPS_PER_OUTER_STEP,
    STANCE_CONTROLLER_ID,
    collect_native_v1,
    collect_native_v2,
    collection_request_v1,
    collection_request_v2,
    plan_control_v1,
    plan_control_v2,
    plan_control_v3,
    plan_stance_control_v1,
)
from .recovery_observation_v2_route import (
    publish_recovery_observation_v2,
    validate_recovery_observation_v2_in_run_invariants_v1,
)
from .sparse_actuator_moment import (
    PROFILE_ID as SPARSE_ACTUATOR_MOMENT_PROFILE_ID,
    SparseActuatorMomentExpansionV1,
    expand_sparse_actuator_moment_v1,
)


PHYSICAL_THRESHOLD_PROFILE_ID = (
    "sporespore_exact_s169_recovery_development_thresholds_v1"
)
R24D17_RUNTIME_QUALIFICATION_SHA256 = (
    "sha256:0860fd4594c4f25a958f07fd369b6816e54042a88d1dabb14367fd071d56cbbf"
)
ROUTE_ID = "sporespore_mujoco_exact_s169_native_recovery_development_v3"
INITIALIZER_ID = "sporespore_exact_s169_ventral_prone_initializer_v1"
HOST_MAPPING_ID = "sporespore_recovery_position_target_to_velocity_servo_v1"
FOOT_CLASSIFICATION_RULE_ID = "mujoco_distal_capsule_lower_cap_contact_v1"
NONFOOT_CLASSIFICATION_RULE_ID = (
    "mujoco_geom_contact_and_foot_cap_excluded_clearance_v1"
)
RECOVERY_MORPHOLOGY_CONTEXT_SCHEMA = "sporespore_recovery_morphology_context_v1"
OUTER_DT_S = 1.0 / 120.0
CONTACT_CLASSIFICATION_TOLERANCE_M = 1.0e-9
ZERO_ACTUATOR_FORCE_TOLERANCE_NM = 1.0e-12
ACTUATOR_WORK_CROSSCHECK_TOLERANCE_J = 1.0e-10
ENERGY_LEDGER_PROFILE_ID = (
    "mujoco_independent_constraint_and_passive_work_energy_ledger_v2"
)
IMPLICIT_STEP_ROUTE_ID = (
    "sporespore_mujoco_exact_s169_native_recovery_implicit_step_energy_v1"
)
SPARSE_MOMENT_IMPLICIT_STEP_ROUTE_ID = (
    "sporespore_mujoco_exact_s169_native_recovery_implicit_step_energy_v2"
)
SIGNED_WORK_PREPROJECTION_ROUTE_ID = (
    "sporespore_mujoco_exact_s169_native_recovery_implicit_step_energy_v3"
)
OBSERVATION_V2_CONSUMER_ROUTE_ID = (
    "sporespore_mujoco_exact_s169_recovery_observation_v2_consumer_v1"
)
IMPLICIT_STEP_NATIVE_RECEIPT_SCHEMA = (
    "sporespore_mujoco_recovery_native_step_receipt_v2"
)
SPARSE_MOMENT_IMPLICIT_STEP_NATIVE_RECEIPT_SCHEMA = (
    "sporespore_mujoco_recovery_native_step_receipt_v3"
)
SIGNED_WORK_PREPROJECTION_NATIVE_RECEIPT_SCHEMA = (
    "sporespore_mujoco_recovery_native_step_receipt_v4"
)
IMPLICIT_SUBSTEP_RECEIPT_SCHEMA = "sporespore_mujoco_implicit_substep_energy_receipt_v1"
SPARSE_MOMENT_IMPLICIT_SUBSTEP_RECEIPT_SCHEMA = (
    "sporespore_mujoco_implicit_substep_energy_receipt_v2"
)
SIGNED_WORK_PREPROJECTION_SUBSTEP_RECEIPT_SCHEMA = (
    "sporespore_mujoco_implicit_substep_energy_receipt_v3"
)

_ACTIVE_RECOVERY_PHASES = {
    "confirm_prone",
    "establish_distal_support",
    "raise_body",
}
_STANCE_PHASES = {"stance_handoff", "stance_dwell", "complete"}
_TERMINAL_PHASES = {"complete", "failed", "refused"}


class NativeRecoveryRouteError(RuntimeError):
    """Stable fail-closed error emitted by the native recovery route."""


class NativeRecoveryCollectionRefusal(NativeRecoveryRouteError):
    """Collection refusal retaining the exact receipt and partial native state."""

    def __init__(self, diagnostic: Mapping[str, Any]) -> None:
        self.diagnostic = deepcopy(dict(diagnostic))
        super().__init__("QSDK_R24D18_NATIVE_COLLECTION_REFUSED")


class NativeEnergyProjectionRefusal(NativeRecoveryRouteError):
    """Typed refusal retaining signed work before portable-v1 projection."""

    def __init__(self, diagnostic: Mapping[str, Any]) -> None:
        self.diagnostic = deepcopy(dict(diagnostic))
        super().__init__("QSDK_R24D36_PORTABLE_ENERGY_PROJECTION_REFUSED")


class NativeObservationV2PublicationRefusal(NativeRecoveryRouteError):
    """Typed refusal retaining a complete R24D39 publication receipt."""

    def __init__(self, diagnostic: Mapping[str, Any]) -> None:
        self.diagnostic = deepcopy(dict(diagnostic))
        super().__init__("QSDK_R24D39_OBSERVATION_V2_PUBLICATION_REFUSED")


def require_stance_continuation_commissioned_v1(
    phase: str,
    commissioned: bool,
) -> None:
    """Fail closed before any world step when stance ownership is not commissioned."""

    _require(
        commissioned or phase not in _STANCE_PHASES,
        "QSDK_R24D18_STANCE_HANDOFF_CONTROLLER_NOT_COMMISSIONED",
    )


@dataclass(frozen=True)
class NativeEnergyWorkV2:
    """Independent native work terms for one MuJoCo integration substep."""

    actuator_work_j: float
    generalized_actuator_work_j: float
    constraint_work_j: float
    damper_work_j: float
    fluid_work_j: float
    adhesion_work_j: float
    dissipated_energy_j: float


@dataclass(frozen=True)
class NativeImplicitStepEnergyV3:
    """Frozen pre/post state and parallel v2/v3 work for one native substep."""

    native_timestep_s: float
    target_actuator_velocity_rad_s: tuple[float, ...]
    reported_pre_actuator_velocity_rad_s: tuple[float, ...]
    reported_pre_actuator_force_nm: tuple[float, ...]
    velocity_gain_nm_s_per_rad: tuple[float, ...]
    force_range_lower_nm: tuple[float, ...]
    force_range_upper_nm: tuple[float, ...]
    actuator_moment: tuple[tuple[float, ...], ...]
    pre_generalized_velocity: tuple[float, ...]
    post_generalized_velocity: tuple[float, ...]
    reported_pre_generalized_actuator_force: tuple[float, ...]
    reported_pre_generalized_constraint_force: tuple[float, ...]
    reported_pre_generalized_damper_force: tuple[float, ...]
    reported_pre_generalized_fluid_force: tuple[float, ...]
    reported_pre_generalized_adhesion_force: tuple[float, ...]
    historical_v2: NativeEnergyWorkV2
    implicit_v3: ImplicitStepEnergyWorkV3
    actuator_moment_expansion: SparseActuatorMomentExpansionV1 | None = None

    def receipt_v1(self, native_substep: int) -> dict[str, Any]:
        """Return the complete re-derivable per-substep evidence receipt."""

        return {
            "schema_version": IMPLICIT_SUBSTEP_RECEIPT_SCHEMA,
            "measurement_profile_id": IMPLICIT_STEP_ENERGY_LEDGER_PROFILE_ID,
            "native_substep": int(native_substep),
            "native_timestep_s": self.native_timestep_s,
            "preintegration_stage": (
                "after_mj_fwd_constraint_and_mj_check_acc_before_mj_implicit"
            ),
            "target_actuator_velocity_rad_s": list(self.target_actuator_velocity_rad_s),
            "reported_pre_actuator_velocity_rad_s": list(
                self.reported_pre_actuator_velocity_rad_s
            ),
            "reported_pre_actuator_force_nm": list(self.reported_pre_actuator_force_nm),
            "velocity_gain_nm_s_per_rad": list(self.velocity_gain_nm_s_per_rad),
            "force_range_lower_nm": list(self.force_range_lower_nm),
            "force_range_upper_nm": list(self.force_range_upper_nm),
            "actuator_moment": [list(row) for row in self.actuator_moment],
            "pre_generalized_velocity": list(self.pre_generalized_velocity),
            "post_generalized_velocity": list(self.post_generalized_velocity),
            "reported_pre_generalized_actuator_force": list(
                self.reported_pre_generalized_actuator_force
            ),
            "reported_pre_generalized_constraint_force": list(
                self.reported_pre_generalized_constraint_force
            ),
            "reported_pre_generalized_damper_force": list(
                self.reported_pre_generalized_damper_force
            ),
            "reported_pre_generalized_fluid_force": list(
                self.reported_pre_generalized_fluid_force
            ),
            "reported_pre_generalized_adhesion_force": list(
                self.reported_pre_generalized_adhesion_force
            ),
            "historical_v2": {
                "energy_ledger_profile_id": ENERGY_LEDGER_PROFILE_ID,
                "left_endpoint_actuator_work_j": self.historical_v2.actuator_work_j,
                "left_endpoint_generalized_actuator_work_j": (
                    self.historical_v2.generalized_actuator_work_j
                ),
                "left_endpoint_constraint_work_j": (
                    self.historical_v2.constraint_work_j
                ),
                "left_endpoint_damper_work_j": self.historical_v2.damper_work_j,
                "left_endpoint_fluid_work_j": self.historical_v2.fluid_work_j,
                "left_endpoint_adhesion_work_j": self.historical_v2.adhesion_work_j,
                "left_endpoint_dissipated_energy_j": (
                    self.historical_v2.dissipated_energy_j
                ),
            },
            "implicit_v3": {
                "energy_ledger_profile_id": IMPLICIT_STEP_ENERGY_LEDGER_PROFILE_ID,
                "effective_implicit_actuator_force_nm": list(
                    self.implicit_v3.effective_implicit_actuator_force_nm
                ),
                "force_limited_at_pre_step": list(
                    self.implicit_v3.force_limited_at_pre_step
                ),
                "effective_centered_actuator_work_j": (
                    self.implicit_v3.effective_centered_actuator_work_j
                ),
                "effective_centered_generalized_actuator_work_j": (
                    self.implicit_v3.effective_centered_generalized_actuator_work_j
                ),
                "centered_constraint_work_j": (
                    self.implicit_v3.centered_constraint_work_j
                ),
                "centered_damper_work_j": self.implicit_v3.centered_damper_work_j,
                "centered_fluid_work_j": self.implicit_v3.centered_fluid_work_j,
                "centered_adhesion_work_j": (self.implicit_v3.centered_adhesion_work_j),
                "centered_dissipated_energy_j": (
                    self.implicit_v3.centered_dissipated_energy_j
                ),
            },
        }

    def receipt_v2(self, native_substep: int) -> dict[str, Any]:
        """Return v1 energy evidence plus exact sparse-expansion provenance."""

        _require(
            self.actuator_moment_expansion is not None,
            "QSDK_R24D35_SPARSE_EXPANSION_RECEIPT_MISSING",
        )
        receipt = self.receipt_v1(native_substep)
        receipt["schema_version"] = SPARSE_MOMENT_IMPLICIT_SUBSTEP_RECEIPT_SCHEMA
        receipt["actuator_moment_expansion"] = (
            self.actuator_moment_expansion.receipt_v1()
        )
        receipt["actuator_moment_expansion_profile_id"] = (
            SPARSE_ACTUATOR_MOMENT_PROFILE_ID
        )
        return receipt

    def receipt_v3(self, native_substep: int) -> dict[str, Any]:
        """Return sparse provenance plus v2/v3 typed energy preprojections."""

        receipt = self.receipt_v2(native_substep)
        historical = self.historical_v2
        centered = self.implicit_v3
        receipt["schema_version"] = SIGNED_WORK_PREPROJECTION_SUBSTEP_RECEIPT_SCHEMA
        receipt["historical_v2_energy_preprojection"] = (
            classify_energy_work_for_portable_v1(
                constraint_work_j=historical.constraint_work_j,
                damper_work_j=historical.damper_work_j,
                fluid_work_j=historical.fluid_work_j,
                adhesion_work_j=historical.adhesion_work_j,
            ).receipt_v1()
        )
        receipt["portable_v3_energy_preprojection"] = (
            classify_energy_work_for_portable_v1(
                constraint_work_j=centered.centered_constraint_work_j,
                damper_work_j=centered.centered_damper_work_j,
                fluid_work_j=centered.centered_fluid_work_j,
                adhesion_work_j=centered.centered_adhesion_work_j,
            ).receipt_v1()
        )
        receipt["energy_work_preprojection_profile_id"] = (
            ENERGY_WORK_PREPROJECTION_PROFILE_ID
        )
        return receipt


def measure_native_energy_work_v2(
    *,
    timestep_s: float,
    actuator_force: Sequence[float],
    actuator_velocity: Sequence[float],
    generalized_velocity: Sequence[float],
    generalized_actuator_force: Sequence[float],
    generalized_constraint_force: Sequence[float],
    generalized_damper_force: Sequence[float],
    generalized_fluid_force: Sequence[float],
    generalized_adhesion_force: Sequence[float],
) -> NativeEnergyWorkV2:
    """Measure work without using mechanical-energy change or the residual.

    MuJoCo exposes each force term at the pre-integration state used by
    ``mj_step2``.  The dot products therefore use the copied pre-step
    generalized velocity.  Constraint and non-conservative passive work are
    kept separate in the native receipt; their negated sum is the independently
    measured energy removal supplied to the portable dissipation field.
    """

    dt = float(timestep_s)
    _require(math.isfinite(dt) and dt > 0.0, "QSDK_R24D31_ENERGY_DT_INVALID")

    def vector(value: Sequence[float], code: str) -> np.ndarray:
        result = np.asarray(value, dtype=np.float64)
        _require(
            result.ndim == 1 and bool(np.all(np.isfinite(result))),
            code,
        )
        return result

    actuator_force_v = vector(actuator_force, "QSDK_R24D31_ACTUATOR_FORCE_INVALID")
    actuator_velocity_v = vector(
        actuator_velocity,
        "QSDK_R24D31_ACTUATOR_VELOCITY_INVALID",
    )
    qvel = vector(generalized_velocity, "QSDK_R24D31_QVEL_INVALID")
    qfrc_actuator = vector(
        generalized_actuator_force,
        "QSDK_R24D31_QFRC_ACTUATOR_INVALID",
    )
    qfrc_constraint = vector(
        generalized_constraint_force,
        "QSDK_R24D31_QFRC_CONSTRAINT_INVALID",
    )
    qfrc_damper = vector(
        generalized_damper_force,
        "QSDK_R24D31_QFRC_DAMPER_INVALID",
    )
    qfrc_fluid = vector(
        generalized_fluid_force,
        "QSDK_R24D31_QFRC_FLUID_INVALID",
    )
    qfrc_adhesion = vector(
        generalized_adhesion_force,
        "QSDK_R24D31_QFRC_ADHESION_INVALID",
    )
    _require(
        actuator_force_v.shape == actuator_velocity_v.shape,
        "QSDK_R24D31_ACTUATOR_VECTOR_SHAPE_MISMATCH",
    )
    for value, code in (
        (qfrc_actuator, "QSDK_R24D31_QFRC_ACTUATOR_SHAPE_MISMATCH"),
        (qfrc_constraint, "QSDK_R24D31_QFRC_CONSTRAINT_SHAPE_MISMATCH"),
        (qfrc_damper, "QSDK_R24D31_QFRC_DAMPER_SHAPE_MISMATCH"),
        (qfrc_fluid, "QSDK_R24D31_QFRC_FLUID_SHAPE_MISMATCH"),
        (qfrc_adhesion, "QSDK_R24D31_QFRC_ADHESION_SHAPE_MISMATCH"),
    ):
        _require(value.shape == qvel.shape, code)

    actuator_work = float(np.dot(actuator_force_v, actuator_velocity_v) * dt)
    generalized_actuator_work = float(np.dot(qfrc_actuator, qvel) * dt)
    _require(
        abs(actuator_work - generalized_actuator_work)
        <= ACTUATOR_WORK_CROSSCHECK_TOLERANCE_J,
        "QSDK_R24D31_ACTUATOR_WORK_CROSSCHECK_FAILED",
    )
    constraint_work = float(np.dot(qfrc_constraint, qvel) * dt)
    damper_work = float(np.dot(qfrc_damper, qvel) * dt)
    fluid_work = float(np.dot(qfrc_fluid, qvel) * dt)
    adhesion_work = float(np.dot(qfrc_adhesion, qvel) * dt)
    values = (
        actuator_work,
        generalized_actuator_work,
        constraint_work,
        damper_work,
        fluid_work,
        adhesion_work,
    )
    _require(
        all(math.isfinite(value) for value in values),
        "QSDK_R24D31_NATIVE_WORK_NONFINITE",
    )
    dissipated = -(constraint_work + damper_work + fluid_work + adhesion_work)
    _require(math.isfinite(dissipated), "QSDK_R24D31_DISSIPATION_NONFINITE")
    return NativeEnergyWorkV2(
        actuator_work_j=actuator_work,
        generalized_actuator_work_j=generalized_actuator_work,
        constraint_work_j=constraint_work,
        damper_work_j=damper_work,
        fluid_work_j=fluid_work,
        adhesion_work_j=adhesion_work,
        dissipated_energy_j=dissipated,
    )


def advance_implicitfast_after_control_v3(
    *,
    model: Any,
    data: Any,
    target_actuator_velocity_rad_s: Sequence[float],
    velocity_gain_nm_s_per_rad: Sequence[float],
    force_range_lower_nm: Sequence[float],
    force_range_upper_nm: Sequence[float],
) -> NativeImplicitStepEnergyV3:
    """Complete the post-control half-step and measure immediately before integration.

    ``mj_step2`` computes control-dependent forces and integrates without an
    observation seam between those operations.  This function executes the
    same public MuJoCo 3.11 stages in the same order, snapshots the completed
    pre-integration dynamics state, then calls the genuine ``mj_implicit``
    integrator exactly once.  The caller must have already run ``mj_step1`` and
    assigned ``data.ctrl``.
    """

    _require(
        int(model.opt.integrator) == int(mujoco.mjtIntegrator.mjINT_IMPLICITFAST),
        "QSDK_R24D34_INTEGRATOR_NOT_IMPLICITFAST",
    )
    dt = float(model.opt.timestep)
    _require(
        math.isfinite(dt) and dt > 0.0,
        "QSDK_R24D34_NATIVE_TIMESTEP_INVALID",
    )

    target = np.asarray(target_actuator_velocity_rad_s, dtype=np.float64).copy()
    gain = np.asarray(velocity_gain_nm_s_per_rad, dtype=np.float64).copy()
    lower = np.asarray(force_range_lower_nm, dtype=np.float64).copy()
    upper = np.asarray(force_range_upper_nm, dtype=np.float64).copy()
    ctrl = np.asarray(data.ctrl, dtype=np.float64)
    _require(
        target.ndim == gain.ndim == lower.ndim == upper.ndim == ctrl.ndim == 1
        and target.shape == gain.shape == lower.shape == upper.shape == ctrl.shape
        and bool(np.all(np.isfinite(target)))
        and bool(np.all(np.isfinite(gain)))
        and bool(np.all(np.isfinite(lower)))
        and bool(np.all(np.isfinite(upper)))
        and bool(np.all(np.isfinite(ctrl))),
        "QSDK_R24D34_ACTUATOR_CONFIGURATION_INVALID",
    )
    _require(
        bool(np.array_equal(ctrl, target)),
        "QSDK_R24D34_CONTROL_TARGET_NOT_BOUND",
    )

    entry_qvel = np.asarray(data.qvel, dtype=np.float64).copy()
    entry_time = float(data.time)
    _require(
        entry_qvel.ndim == 1
        and bool(np.all(np.isfinite(entry_qvel)))
        and math.isfinite(entry_time),
        "QSDK_R24D34_PREINTEGRATION_STATE_INVALID",
    )

    # This is the acceleration-dependent body of MuJoCo 3.11 ``mj_step2``.
    mujoco.mj_fwdActuation(model, data)
    mujoco.mj_fwdAcceleration(model, data)
    mujoco.mj_fwdConstraint(model, data)
    data.flg_rnepost = 0
    mujoco.mj_sensorAcc(model, data)
    mujoco.mj_checkAcc(model, data)
    if int(model.opt.enableflags) & int(mujoco.mjtEnableBit.mjENBL_FWDINV):
        mujoco.mj_compareFwdInv(model, data)

    pre_qvel = np.asarray(data.qvel, dtype=np.float64).copy()
    _require(
        bool(np.array_equal(entry_qvel, pre_qvel)) and float(data.time) == entry_time,
        "QSDK_R24D34_FORWARD_STAGE_MUTATED_INTEGRATION_STATE",
    )
    pre_actuator_velocity = np.asarray(
        data.actuator_velocity,
        dtype=np.float64,
    ).copy()
    pre_actuator_force = np.asarray(data.actuator_force, dtype=np.float64).copy()
    actuator_moment_expansion = expand_sparse_actuator_moment_v1(
        values=data.actuator_moment,
        rownnz=data.moment_rownnz,
        rowadr=data.moment_rowadr,
        colind=data.moment_colind,
        nout=int(model.nout),
        nv=int(model.nv),
        nJmom=int(model.nJmom),
    )
    actuator_moment = actuator_moment_expansion.dense_array()
    pre_qfrc_actuator = np.asarray(data.qfrc_actuator, dtype=np.float64).copy()
    pre_qfrc_constraint = np.asarray(data.qfrc_constraint, dtype=np.float64).copy()
    pre_qfrc_damper = np.asarray(data.qfrc_damper, dtype=np.float64).copy()
    pre_qfrc_fluid = np.asarray(data.qfrc_fluid, dtype=np.float64).copy()
    pre_qfrc_adhesion = np.asarray(data.qfrc_adhesion, dtype=np.float64).copy()

    _require(
        pre_actuator_force.shape == target.shape
        and pre_actuator_velocity.shape == target.shape
        and actuator_moment.shape == (target.size, pre_qvel.size),
        "QSDK_R24D34_PREINTEGRATION_ACTUATOR_SHAPE_MISMATCH",
    )
    for value in (
        pre_qfrc_actuator,
        pre_qfrc_constraint,
        pre_qfrc_damper,
        pre_qfrc_fluid,
        pre_qfrc_adhesion,
    ):
        _require(
            value.shape == pre_qvel.shape,
            "QSDK_R24D34_PREINTEGRATION_FORCE_SHAPE_MISMATCH",
        )

    # The sole state/time advancement in this route remains MuJoCo's own
    # implicitfast integrator.  All pre-step arrays above are independent copies.
    mujoco.mj_implicit(model, data)
    post_qvel = np.asarray(data.qvel, dtype=np.float64).copy()
    expected_time = entry_time + dt
    time_scale = max(abs(expected_time), abs(float(data.time)), 1.0)
    _require(
        post_qvel.shape == pre_qvel.shape
        and bool(np.all(np.isfinite(post_qvel)))
        and abs(float(data.time) - expected_time) <= 8 * math.ulp(time_scale),
        "QSDK_R24D34_POSTINTEGRATION_STATE_INVALID",
    )

    historical_v2 = measure_native_energy_work_v2(
        timestep_s=dt,
        actuator_force=pre_actuator_force,
        actuator_velocity=pre_actuator_velocity,
        generalized_velocity=pre_qvel,
        generalized_actuator_force=pre_qfrc_actuator,
        generalized_constraint_force=pre_qfrc_constraint,
        generalized_damper_force=pre_qfrc_damper,
        generalized_fluid_force=pre_qfrc_fluid,
        generalized_adhesion_force=pre_qfrc_adhesion,
    )
    implicit_v3 = measure_implicit_step_energy_work_v3(
        timestep_s=dt,
        target_actuator_velocity_rad_s=target,
        reported_pre_actuator_velocity_rad_s=pre_actuator_velocity,
        reported_pre_actuator_force_nm=pre_actuator_force,
        velocity_gain_nm_s_per_rad=gain,
        force_range_lower_nm=lower,
        force_range_upper_nm=upper,
        actuator_moment=actuator_moment,
        pre_generalized_velocity=pre_qvel,
        post_generalized_velocity=post_qvel,
        reported_pre_generalized_actuator_force=pre_qfrc_actuator,
        reported_pre_generalized_constraint_force=pre_qfrc_constraint,
        reported_pre_generalized_damper_force=pre_qfrc_damper,
        reported_pre_generalized_fluid_force=pre_qfrc_fluid,
        reported_pre_generalized_adhesion_force=pre_qfrc_adhesion,
    )
    _require(
        abs(historical_v2.actuator_work_j - implicit_v3.left_endpoint_actuator_work_j)
        <= ACTUATOR_WORK_CROSSCHECK_TOLERANCE_J
        and abs(
            historical_v2.generalized_actuator_work_j
            - implicit_v3.left_endpoint_generalized_actuator_work_j
        )
        <= ACTUATOR_WORK_CROSSCHECK_TOLERANCE_J
        and abs(
            historical_v2.constraint_work_j
            - implicit_v3.left_endpoint_constraint_work_j
        )
        <= ACTUATOR_WORK_CROSSCHECK_TOLERANCE_J,
        "QSDK_R24D34_V2_V3_LEFT_ENDPOINT_MISMATCH",
    )
    return NativeImplicitStepEnergyV3(
        native_timestep_s=dt,
        target_actuator_velocity_rad_s=tuple(float(value) for value in target),
        reported_pre_actuator_velocity_rad_s=tuple(
            float(value) for value in pre_actuator_velocity
        ),
        reported_pre_actuator_force_nm=tuple(
            float(value) for value in pre_actuator_force
        ),
        velocity_gain_nm_s_per_rad=tuple(float(value) for value in gain),
        force_range_lower_nm=tuple(float(value) for value in lower),
        force_range_upper_nm=tuple(float(value) for value in upper),
        actuator_moment=tuple(
            tuple(float(value) for value in row) for row in actuator_moment
        ),
        pre_generalized_velocity=tuple(float(value) for value in pre_qvel),
        post_generalized_velocity=tuple(float(value) for value in post_qvel),
        reported_pre_generalized_actuator_force=tuple(
            float(value) for value in pre_qfrc_actuator
        ),
        reported_pre_generalized_constraint_force=tuple(
            float(value) for value in pre_qfrc_constraint
        ),
        reported_pre_generalized_damper_force=tuple(
            float(value) for value in pre_qfrc_damper
        ),
        reported_pre_generalized_fluid_force=tuple(
            float(value) for value in pre_qfrc_fluid
        ),
        reported_pre_generalized_adhesion_force=tuple(
            float(value) for value in pre_qfrc_adhesion
        ),
        historical_v2=historical_v2,
        implicit_v3=implicit_v3,
        actuator_moment_expansion=actuator_moment_expansion,
    )


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise NativeRecoveryRouteError(code)


def require_supported_native_collection_v1(
    collected: Mapping[str, Any],
    *,
    refusal_context: Mapping[str, Any],
) -> Mapping[str, Any]:
    """Return an accepted receipt or raise with its exact diagnostic context."""

    if (
        collected.get("support_status") == "supported_exact"
        and collected.get("supplied_native_post_step_observation_validated") is True
    ):
        return collected
    diagnostic = {
        "schema_version": (
            "sporespore_mujoco_recovery_native_collection_refusal_diagnostic_v1"
        ),
        "error_code": "QSDK_R24D18_NATIVE_COLLECTION_REFUSED",
        "collector_support_status": collected.get("support_status"),
        "collector_refusal_reason": collected.get("refusal_reason"),
        "collector_supplied_native_post_step_observation_validated": collected.get(
            "supplied_native_post_step_observation_validated"
        ),
        "collector_receipt": deepcopy(dict(collected)),
        "refusal_context": deepcopy(dict(refusal_context)),
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    try:
        json.dumps(
            diagnostic,
            allow_nan=False,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
    except (TypeError, ValueError) as error:
        raise NativeRecoveryRouteError(
            "QSDK_R24D28_NATIVE_COLLECTION_REFUSAL_DIAGNOSTIC_NOT_JSON_SAFE"
        ) from error
    raise NativeRecoveryCollectionRefusal(diagnostic)


def _canonical_sha256(core: LocomotionCore, value: object) -> str:
    receipt = core.canonicalize_json(value)
    digest = receipt.get("sha256")
    _require(
        isinstance(digest, str) and len(digest) == 71 and digest.startswith("sha256:"),
        "QSDK_R24D18_CANONICAL_DIGEST_INVALID",
    )
    assert isinstance(digest, str)
    return digest


def _binary64_hex(value: float) -> str:
    return struct.pack("<d", float(value)).hex()


def _canonical_vector(value: Sequence[float]) -> dict[str, float]:
    vector = base._mujoco_to_canonical(value)
    return {"x": float(vector[0]), "y": float(vector[1]), "z": float(vector[2])}


def _zero_intervention_ledger() -> dict[str, int]:
    return {
        "root_force_application_count": 0,
        "root_torque_application_count": 0,
        "root_impulse_application_count": 0,
        "root_pose_write_count": 0,
        "root_velocity_write_count": 0,
        "pin_or_guide_constraint_count": 0,
        "hidden_body_actuation_count": 0,
        "pose_teleport_count": 0,
        "collision_disable_count": 0,
        "contact_relabel_count": 0,
        "gravity_mutation_count": 0,
        "time_scale_mutation_count": 0,
        "engine_specific_policy_branch_count": 0,
    }


def _controller_owner(arm_kind: str, phase: str) -> dict[str, Any]:
    if arm_kind == "matched_zero_command":
        return {
            "owner": "none",
            "recovery_controller_id": None,
            "stance_controller_id": None,
            "handoff_event_count": 0,
            "fallback_controller_active": False,
            "source_measurement": True,
        }
    if phase in _ACTIVE_RECOVERY_PHASES:
        return {
            "owner": "recovery",
            "recovery_controller_id": CONTROLLER_ID,
            "stance_controller_id": None,
            "handoff_event_count": 0,
            "fallback_controller_active": False,
            "source_measurement": True,
        }
    if phase in _STANCE_PHASES:
        return {
            "owner": "stance",
            "recovery_controller_id": None,
            "stance_controller_id": STANCE_CONTROLLER_ID,
            "handoff_event_count": 1,
            "fallback_controller_active": False,
            "source_measurement": True,
        }
    return {
        "owner": "none",
        "recovery_controller_id": None,
        "stance_controller_id": None,
        "handoff_event_count": 0,
        "fallback_controller_active": False,
        "source_measurement": True,
    }


def _bootstrap_control(
    core: LocomotionCore, arm_kind: str, phase: str
) -> dict[str, Any]:
    payload = {
        "schema_version": "sporespore_recovery_bootstrap_control_v1",
        "arm_kind": arm_kind,
        "phase": phase,
        "no_actuation_requested": True,
        "ordered_commands": [],
    }
    return {
        "schema_version": "sporespore_recovery_control_receipt_v1",
        "support_status": "supported_exact",
        "controller_id": CONTROLLER_ID,
        "semantic_step": 0,
        "phase": phase,
        "phase_step": 0,
        "matched_zero_command": arm_kind == "matched_zero_command",
        "no_actuation_requested": True,
        "ordered_commands": [],
        "command_sha256": _canonical_sha256(core, payload),
        "bootstrap": True,
    }


def prepare_active_recovery_host_command_v1(
    positions_rad: Sequence[float],
    commands: Sequence[Mapping[str, Any]],
) -> tuple[np.ndarray, list[bool]]:
    """Map one portable active command to production MuJoCo host values.

    This helper is deliberately model-free so the exact active mapping and its
    JSON scalar types can be qualified before any physics world is opened.
    """

    _require(
        len(positions_rad) == len(ORDERED_ACTUATOR_IDS),
        "QSDK_R24D26_POSITION_CARDINALITY",
    )
    _require(
        len(commands) == len(ORDERED_ACTUATOR_IDS),
        "QSDK_R24D26_COMMAND_CARDINALITY",
    )
    targets = np.zeros(len(ORDERED_ACTUATOR_IDS), dtype=np.float64)
    host_clamped: list[bool] = [False] * len(ORDERED_ACTUATOR_IDS)
    for index, (command, actuator_id, joint_id) in enumerate(
        zip(commands, ORDERED_ACTUATOR_IDS, ORDERED_JOINT_IDS, strict=True)
    ):
        _require(
            command.get("actuator_id") == actuator_id
            and command.get("joint_id") == joint_id,
            f"QSDK_R24D18_COMMAND_ORDER:{index}",
        )
        requested = (
            float(command["target_position_rad"]) - float(positions_rad[index])
        ) / OUTER_DT_S
        maximum = float(command["maximum_target_speed_rad_s"])
        targets[index] = float(np.clip(requested, -maximum, maximum))
        host_clamped[index] = bool(targets[index] != requested)
    _require(
        all(type(value) is bool for value in host_clamped),
        "QSDK_R24D26_HOST_CLAMP_SCALAR_TYPE",
    )
    return targets, host_clamped


def canonicalize_recovery_application_receipt_v1(
    core: LocomotionCore,
    *,
    route_id: str,
    semantic_step: int,
    phase: str,
    arm_kind: str,
    control: Mapping[str, Any],
    active: bool,
    targets: Sequence[float],
    host_clamped: Sequence[bool],
    signed_impulses: Sequence[float],
    maximum_forces: Sequence[float],
    step_actuator_work_j: float,
) -> tuple[dict[str, Any], str]:
    """Build and canonicalize the exact production application receipt."""

    for index, value in enumerate(host_clamped):
        _require(
            type(value) is bool,
            f"QSDK_R24D26_APPLICATION_HOST_CLAMP_TYPE:{index}",
        )
    application = {
        "schema_version": "sporespore_mujoco_recovery_application_receipt_v1",
        "route_id": route_id,
        "host_mapping_id": HOST_MAPPING_ID,
        "semantic_step": int(semantic_step),
        "phase": phase,
        "arm_kind": arm_kind,
        "controller_receipt_sha256": _canonical_sha256(core, dict(control)),
        "no_actuation_requested": not active,
        "ordered_host_target_velocity_rad_s": (
            np.asarray(targets, dtype=np.float64).tolist() if active else []
        ),
        "ordered_host_clamped": list(host_clamped),
        "ordered_signed_applied_impulse_nms": np.asarray(
            signed_impulses, dtype=np.float64
        ).tolist(),
        "ordered_maximum_absolute_force_nm": np.asarray(
            maximum_forces, dtype=np.float64
        ).tolist(),
        "step_actuator_work_j": float(step_actuator_work_j),
        "native_substep_count": NATIVE_SUBSTEPS_PER_OUTER_STEP,
    }
    return application, _canonical_sha256(core, application)


@dataclass(frozen=True)
class InitializerReceipt:
    manifest: dict[str, Any]
    manifest_sha256: str
    canonical_pre_step_state: dict[str, Any]
    canonical_pre_step_state_sha256: str


def validate_public_profile_model_identity_v2(
    model: Any,
    physical_binding: Mapping[str, Any],
    actuator_ids: Mapping[str, int],
) -> dict[str, Any]:
    """Validate the exact published cap vector without consulting base caps.

    The R24D18 route inherited a generic validator whose per-actuator branch
    recomputed force limits from the compiled base morphology. That is not the
    authority for the separately published public profile. This successor
    validates cardinality and solver configuration directly, then checks every
    native actuator against the already-qualified public cap vector and its
    independent physical readback receipt.
    """

    _require(
        int(model.nu) == len(ORDERED_ACTUATOR_IDS)
        and int(model.njnt) == len(ORDERED_JOINT_IDS) + 1
        and int(model.nbody) == 10,
        "QSDK_R24D19_MODEL_CARDINALITY_MISMATCH",
    )
    _require(
        float(model.opt.timestep) == OUTER_DT_S / NATIVE_SUBSTEPS_PER_OUTER_STEP,
        "QSDK_R24D19_MODEL_TIMESTEP_MISMATCH",
    )
    _require(
        int(model.opt.integrator) == int(mujoco.mjtIntegrator.mjINT_IMPLICITFAST),
        "QSDK_R24D19_MODEL_INTEGRATOR_MISMATCH",
    )
    ordered_binding = physical_binding.get("ordered_bindings")
    _require(
        physical_binding.get("ok") is True
        and physical_binding.get("profile_id") == PUBLIC_ACTUATOR_PROFILE_ID
        and physical_binding.get("completed_before_first_solver_step") is True
        and physical_binding.get("solver_step_count_at_binding") == 0
        and physical_binding.get("all_readbacks_match") is True
        and isinstance(ordered_binding, list)
        and len(ordered_binding) == len(ORDERED_ACTUATOR_IDS),
        "QSDK_R24D19_PUBLIC_BINDING_INVALID",
    )
    assert isinstance(ordered_binding, list)
    checked: list[dict[str, Any]] = []
    for index, (actuator_id, joint_id, cap) in enumerate(
        zip(ORDERED_ACTUATOR_IDS, ORDERED_JOINT_IDS, ORDERED_CAPS_NMS, strict=True)
    ):
        _require(actuator_id in actuator_ids, f"QSDK_R24D19_ACTUATOR_ID:{index}")
        native_id = int(actuator_ids[actuator_id])
        force_range = np.asarray(model.actuator_forcerange[native_id], dtype=np.float64)
        negative = float(force_range[0])
        positive = float(force_range[1])
        readback = positive * OUTER_DT_S
        binding = ordered_binding[index]
        _require(
            isinstance(binding, dict)
            and binding.get("profile_actuator_id") == actuator_id
            and binding.get("trace_actuator_id") == actuator_id
            and binding.get("joint_id") == joint_id
            and binding.get("declared_maximum_outer_step_impulse_nms") == cap
            and binding.get("readback_matches") is True,
            f"QSDK_R24D19_PUBLIC_BINDING_ORDER:{index}",
        )
        _require(
            float(model.actuator_gainprm[native_id, 0]) == VELOCITY_GAIN_NM_S_PER_RAD
            and float(model.actuator_biasprm[native_id, 2])
            == -VELOCITY_GAIN_NM_S_PER_RAD
            and bool(model.actuator_forcelimited[native_id])
            and negative == -positive
            and positive > 0.0
            and abs(readback - cap) <= CONFIGURATION_READBACK_TOLERANCE_NMS,
            f"QSDK_R24D19_PUBLIC_ACTUATOR_CONFIGURATION:{index}",
        )
        checked.append(
            {
                "actuator_id": actuator_id,
                "joint_id": joint_id,
                "maximum_outer_step_impulse_nms": cap,
                "native_positive_force_limit_nm": positive,
                "readback_outer_step_impulse_nms": readback,
            }
        )
    return {
        "schema_version": "sporespore_mujoco_public_profile_model_identity_v2",
        "ok": True,
        "profile_id": PUBLIC_ACTUATOR_PROFILE_ID,
        "validated_actuator_count": len(checked),
        "ordered_validated_actuators": checked,
        "base_morphology_force_caps_consulted": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def validate_public_profile_model_identity_v3(
    model: Any,
    physical_binding: Mapping[str, Any],
    actuator_ids: Mapping[str, int],
) -> dict[str, Any]:
    """Validate the public profile against the production-authored timestep.

    R24D19 reconstructed the internal timestep as ``(1/120)/5``. Although
    algebraically equal to ``1/600``, that evaluation order rounds one
    binary64 ULP below the value used by ``build_model_xml``. The production
    model author is the identity authority, so this successor consumes
    ``base.INTERNAL_DT_S`` directly and retains exact comparison.
    """

    _require(
        int(model.nu) == len(ORDERED_ACTUATOR_IDS)
        and int(model.njnt) == len(ORDERED_JOINT_IDS) + 1
        and int(model.nbody) == 10,
        "QSDK_R24D20_MODEL_CARDINALITY_MISMATCH",
    )
    _require(
        float(model.opt.timestep) == base.INTERNAL_DT_S,
        "QSDK_R24D20_MODEL_TIMESTEP_MISMATCH",
    )
    _require(
        int(model.opt.integrator) == int(mujoco.mjtIntegrator.mjINT_IMPLICITFAST),
        "QSDK_R24D20_MODEL_INTEGRATOR_MISMATCH",
    )
    ordered_binding = physical_binding.get("ordered_bindings")
    _require(
        physical_binding.get("ok") is True
        and physical_binding.get("profile_id") == PUBLIC_ACTUATOR_PROFILE_ID
        and physical_binding.get("completed_before_first_solver_step") is True
        and physical_binding.get("solver_step_count_at_binding") == 0
        and physical_binding.get("all_readbacks_match") is True
        and isinstance(ordered_binding, list)
        and len(ordered_binding) == len(ORDERED_ACTUATOR_IDS),
        "QSDK_R24D20_PUBLIC_BINDING_INVALID",
    )
    assert isinstance(ordered_binding, list)
    checked: list[dict[str, Any]] = []
    for index, (actuator_id, joint_id, cap) in enumerate(
        zip(ORDERED_ACTUATOR_IDS, ORDERED_JOINT_IDS, ORDERED_CAPS_NMS, strict=True)
    ):
        _require(actuator_id in actuator_ids, f"QSDK_R24D20_ACTUATOR_ID:{index}")
        native_id = int(actuator_ids[actuator_id])
        force_range = np.asarray(model.actuator_forcerange[native_id], dtype=np.float64)
        negative = float(force_range[0])
        positive = float(force_range[1])
        readback = positive * OUTER_DT_S
        binding = ordered_binding[index]
        _require(
            isinstance(binding, dict)
            and binding.get("profile_actuator_id") == actuator_id
            and binding.get("trace_actuator_id") == actuator_id
            and binding.get("joint_id") == joint_id
            and binding.get("declared_maximum_outer_step_impulse_nms") == cap
            and binding.get("readback_matches") is True,
            f"QSDK_R24D20_PUBLIC_BINDING_ORDER:{index}",
        )
        _require(
            float(model.actuator_gainprm[native_id, 0]) == VELOCITY_GAIN_NM_S_PER_RAD
            and float(model.actuator_biasprm[native_id, 2])
            == -VELOCITY_GAIN_NM_S_PER_RAD
            and bool(model.actuator_forcelimited[native_id])
            and negative == -positive
            and positive > 0.0
            and abs(readback - cap) <= CONFIGURATION_READBACK_TOLERANCE_NMS,
            f"QSDK_R24D20_PUBLIC_ACTUATOR_CONFIGURATION:{index}",
        )
        checked.append(
            {
                "actuator_id": actuator_id,
                "joint_id": joint_id,
                "maximum_outer_step_impulse_nms": cap,
                "native_positive_force_limit_nm": positive,
                "readback_outer_step_impulse_nms": readback,
            }
        )
    return {
        "schema_version": "sporespore_mujoco_public_profile_model_identity_v3",
        "ok": True,
        "profile_id": PUBLIC_ACTUATOR_PROFILE_ID,
        "timestep_authority": "selected_policy_development.INTERNAL_DT_S",
        "production_timestep_s": base.INTERNAL_DT_S,
        "validated_actuator_count": len(checked),
        "ordered_validated_actuators": checked,
        "base_morphology_force_caps_consulted": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


class MujocoNativeRecoveryWorld(base.MujocoBw19vRobot):
    """One exact public-profile model with measured recovery ledgers."""

    route_id = ROUTE_ID
    energy_ledger_profile_id = ENERGY_LEDGER_PROFILE_ID
    native_step_receipt_schema = "sporespore_mujoco_recovery_native_step_receipt_v1"
    energy_work_preprojection_required = False
    energy_work_preprojection_refusal_enabled = False
    initializer_id = INITIALIZER_ID
    known_initial_overlap = True
    nonfoot_classification_rule_id = NONFOOT_CLASSIFICATION_RULE_ID
    reconstruct_torso_contact_surface = False

    def __init__(
        self,
        core: LocomotionCore,
        route: PublicProfileModelRoute,
        capability_sha256: str,
    ) -> None:
        self.core = core
        self.profile_id = base.PER_ACTUATOR_VH5_CHARACTERIZED_PROFILE_ID
        self.descriptor = base.s169_descriptor()
        self.compiled = route.compiled
        self.morphology = self.compiled["morphology"]
        self.spec = self.morphology["morphology_spec"]
        self.model_xml = route.model_xml
        self.model = mujoco.MjModel.from_xml_string(self.model_xml)
        self.physical_binding = physical_binding_receipt(self.model, route)
        self.data = mujoco.MjData(self.model)
        self.ground_geom_id = int(self.model.geom("ground").id)
        self.body_geom_ids = {
            body_id: int(self.model.geom(f"{body_id}_geom").id)
            for body_id in self.morphology["ordered_body_ids"]
        }
        self.body_ids_by_geom = {
            geom_id: body_id for body_id, geom_id in self.body_geom_ids.items()
        }
        self.joint_ids = {
            joint_id: int(self.model.joint(joint_id).id)
            for joint_id in self.morphology["ordered_joint_ids"]
        }
        self.actuator_ids = {
            actuator_id: int(self.model.actuator(actuator_id).id)
            for actuator_id in self.morphology["ordered_actuator_ids"]
        }
        self.actuator_specs = {
            actuator["actuator_id"]: actuator for actuator in self.spec["actuators"]
        }
        self.contact_sites = {
            site["contact_site_id"]: site for site in self.spec["contact_sites"]
        }
        self.limbs = {limb["limb_id"]: limb for limb in self.spec["limbs"]}
        self.body_specs = {body["body_id"]: body for body in self.spec["bodies"]}
        self.capability_sha256 = capability_sha256
        self.initial_mechanical_energy_j = 0.0
        self.cumulative_actuator_work_j = 0.0
        self.cumulative_constraint_work_j = 0.0
        self.cumulative_damper_work_j = 0.0
        self.cumulative_fluid_work_j = 0.0
        self.cumulative_adhesion_work_j = 0.0
        self.cumulative_dissipated_energy_j = 0.0
        self.cumulative_effective_centered_actuator_work_j = 0.0
        self.cumulative_effective_centered_generalized_actuator_work_j = 0.0
        self.cumulative_centered_constraint_work_j = 0.0
        self.cumulative_centered_damper_work_j = 0.0
        self.cumulative_centered_fluid_work_j = 0.0
        self.cumulative_centered_adhesion_work_j = 0.0
        self.cumulative_centered_dissipated_energy_j = 0.0
        self.solver_step_count = 0
        self.host_step_count = 0
        self._validate_model_identity()
        _require(
            str(mujoco.__version__) == ENGINE_VERSION,
            "QSDK_R24D18_MUJOCO_VERSION_MISMATCH",
        )
        if self.energy_ledger_profile_id == IMPLICIT_STEP_ENERGY_LEDGER_PROFILE_ID:
            self._bind_implicit_step_energy_configuration_v1()

    def _validate_model_identity(self) -> None:
        self.model_identity = validate_public_profile_model_identity_v3(
            self.model,
            self.physical_binding,
            self.actuator_ids,
        )

    def _bind_implicit_step_energy_configuration_v1(self) -> None:
        """Bind the exact scalar velocity-servo layout consumed by the v3 observer."""

        native_ids = np.asarray(
            [self.actuator_ids[item] for item in ORDERED_ACTUATOR_IDS],
            dtype=np.int64,
        )
        expected_addresses = np.arange(len(ORDERED_ACTUATOR_IDS), dtype=np.int64)
        output_addresses = np.asarray(
            self.model.actuator_outadr[native_ids],
            dtype=np.int64,
        )
        output_counts = np.asarray(
            self.model.actuator_outnum[native_ids],
            dtype=np.int64,
        )
        control_addresses = np.asarray(
            self.model.actuator_ctrladr[native_ids],
            dtype=np.int64,
        )
        control_counts = np.asarray(
            self.model.actuator_ctrlnum[native_ids],
            dtype=np.int64,
        )
        _require(
            int(self.model.nout) == int(self.model.nu) == len(ORDERED_ACTUATOR_IDS)
            and bool(np.array_equal(output_addresses, expected_addresses))
            and bool(np.array_equal(control_addresses, expected_addresses))
            and bool(np.all(output_counts == 1))
            and bool(np.all(control_counts == 1)),
            "QSDK_R24D34_DIRECT_SCALAR_ACTUATOR_LAYOUT_MISMATCH",
        )
        gains = np.asarray(
            self.model.actuator_gainprm[native_ids, 0],
            dtype=np.float64,
        )
        velocity_bias = np.asarray(
            self.model.actuator_biasprm[native_ids, 2],
            dtype=np.float64,
        )
        force_ranges = np.asarray(
            self.model.actuator_forcerange[native_ids],
            dtype=np.float64,
        )
        force_limited = np.asarray(
            self.model.actuator_forcelimited[native_ids],
            dtype=bool,
        )
        control_limited = np.asarray(
            self.model.actuator_ctrllimited[native_ids],
            dtype=bool,
        )
        _require(
            gains.shape == (len(ORDERED_ACTUATOR_IDS),)
            and force_ranges.shape == (len(ORDERED_ACTUATOR_IDS), 2)
            and bool(np.all(gains == VELOCITY_GAIN_NM_S_PER_RAD))
            and bool(np.array_equal(velocity_bias, -gains))
            and bool(np.all(force_limited))
            and not bool(np.any(control_limited)),
            "QSDK_R24D34_DIRECT_VELOCITY_SERVO_CONFIGURATION_MISMATCH",
        )
        self.implicit_velocity_gain_nm_s_per_rad = gains.copy()
        self.implicit_force_range_lower_nm = force_ranges[:, 0].copy()
        self.implicit_force_range_upper_nm = force_ranges[:, 1].copy()

    def _mechanical_energy(self) -> float:
        mujoco.mj_energyPos(self.model, self.data)
        mujoco.mj_energyVel(self.model, self.data)
        value = float(np.sum(np.asarray(self.data.energy, dtype=np.float64)))
        _require(math.isfinite(value), "QSDK_R24D18_MECHANICAL_ENERGY_NONFINITE")
        return value

    def _joint_positions(self) -> np.ndarray:
        return np.asarray(
            [
                self.data.qpos[int(self.model.jnt_qposadr[self.joint_ids[joint_id]])]
                for joint_id in ORDERED_JOINT_IDS
            ],
            dtype=np.float64,
        )

    def _joint_velocities(self) -> np.ndarray:
        return np.asarray(
            [
                self.data.qvel[int(self.model.jnt_dofadr[self.joint_ids[joint_id]])]
                for joint_id in ORDERED_JOINT_IDS
            ],
            dtype=np.float64,
        )

    def _prone_joint_positions(self) -> list[float]:
        """Return the historical exact-s169 folded initializer positions."""

        return [0.72, 1.10, 0.72, 1.10, 0.72, 1.10, 0.72, 1.10]

    def _initializer_manifest_extension(self) -> dict[str, Any]:
        """Allow a versioned morphology route to bind extra initializer identity."""

        return {}

    def initialize_prone(
        self,
        *,
        cell_id: str,
        initial_state_id: str,
        seed: int,
        torso_roll_rad: float,
    ) -> InitializerReceipt:
        """Apply the one declared pre-step initializer before solver step zero."""

        _require(self.solver_step_count == 0, "QSDK_R24D18_INITIALIZER_AFTER_STEP")
        _require(math.isfinite(torso_roll_rad), "QSDK_R24D18_INITIALIZER_ROLL")
        mujoco.mj_resetData(self.model, self.data)
        free = int(self.model.joint("torso_free").id)
        free_qpos = int(self.model.jnt_qposadr[free])
        free_dof = int(self.model.jnt_dofadr[free])
        torso_size = self.compiled["geometry"]["torso_size_m"]
        half_y = float(torso_size["y"]) / 2.0
        half_z = float(torso_size["z"]) / 2.0
        torso_height_m = half_y * math.cos(abs(torso_roll_rad)) + half_z * math.sin(
            abs(torso_roll_rad)
        )
        canonical_position = np.asarray([0.0, torso_height_m, 0.0], dtype=np.float64)
        self.data.qpos[free_qpos : free_qpos + 3] = base._canonical_to_mujoco(
            canonical_position
        )
        half_roll = torso_roll_rad / 2.0
        self.data.qpos[free_qpos + 3 : free_qpos + 7] = [
            math.cos(half_roll),
            math.sin(half_roll),
            0.0,
            0.0,
        ]
        folded_positions = self._prone_joint_positions()
        _require(
            len(folded_positions) == len(ORDERED_JOINT_IDS),
            "QSDK_R24D18_INITIALIZER_JOINT_CARDINALITY",
        )
        for joint_id, value in zip(ORDERED_JOINT_IDS, folded_positions, strict=True):
            joint = self.joint_ids[joint_id]
            self.data.qpos[int(self.model.jnt_qposadr[joint])] = value
        self.data.qvel[:] = 0.0
        self.data.qvel[free_dof : free_dof + 6] = 0.0
        self.data.ctrl[:] = 0.0
        mujoco.mj_forward(self.model, self.data)
        self.initial_mechanical_energy_j = self._mechanical_energy()
        self.cumulative_actuator_work_j = 0.0
        self.cumulative_constraint_work_j = 0.0
        self.cumulative_damper_work_j = 0.0
        self.cumulative_fluid_work_j = 0.0
        self.cumulative_adhesion_work_j = 0.0
        self.cumulative_dissipated_energy_j = 0.0
        self.cumulative_effective_centered_actuator_work_j = 0.0
        self.cumulative_effective_centered_generalized_actuator_work_j = 0.0
        self.cumulative_centered_constraint_work_j = 0.0
        self.cumulative_centered_damper_work_j = 0.0
        self.cumulative_centered_fluid_work_j = 0.0
        self.cumulative_centered_adhesion_work_j = 0.0
        self.cumulative_centered_dissipated_energy_j = 0.0
        manifest = {
            "schema_version": "sporespore_recovery_initializer_manifest_v1",
            "initializer_id": self.initializer_id,
            "cell_id": cell_id,
            "initial_state_id": initial_state_id,
            "seed": seed,
            "random_draw_count": 0,
            "coordinate_frame_id": "right_handed_x_forward_y_up_z_right_si_v1",
            "torso_position_world_m": {
                "x": 0.0,
                "y": torso_height_m,
                "z": 0.0,
            },
            "torso_roll_rad": torso_roll_rad,
            "torso_orientation_rule_id": "canonical_x_axis_roll_to_mujoco_wxyz_v1",
            "ordered_joint_ids": list(ORDERED_JOINT_IDS),
            "ordered_joint_positions_rad": folded_positions,
            "all_generalized_velocities_zero": True,
            "initializer_writes_occur_before_solver_step_zero": True,
            "initializer_writes_count_as_in_run_interventions": False,
            "known_initial_overlap_is_a_development_observation_not_hidden": (
                self.known_initial_overlap
            ),
        }
        manifest.update(self._initializer_manifest_extension())
        pre_state = {
            "schema_version": "sporespore_recovery_canonical_pre_step_state_v1",
            "qpos_binary64_le_hex": [
                _binary64_hex(float(value)) for value in np.asarray(self.data.qpos)
            ],
            "qvel_binary64_le_hex": [
                _binary64_hex(float(value)) for value in np.asarray(self.data.qvel)
            ],
            "ctrl_binary64_le_hex": [
                _binary64_hex(float(value)) for value in np.asarray(self.data.ctrl)
            ],
            "mujoco_time_binary64_le_hex": _binary64_hex(float(self.data.time)),
            "active_contact_count_after_mj_forward": int(self.data.ncon),
            "solver_step_count": 0,
        }
        return InitializerReceipt(
            manifest=manifest,
            manifest_sha256=_canonical_sha256(self.core, manifest),
            canonical_pre_step_state=pre_state,
            canonical_pre_step_state_sha256=_canonical_sha256(self.core, pre_state),
        )

    def _body_local_canonical(
        self, body_id: str, point_mujoco: np.ndarray
    ) -> np.ndarray:
        body = int(self.model.body(body_id).id)
        rotation = np.asarray(self.data.xmat[body], dtype=np.float64).reshape(3, 3)
        local_mujoco = rotation.T @ (
            np.asarray(point_mujoco, dtype=np.float64)
            - np.asarray(self.data.xpos[body], dtype=np.float64)
        )
        return base._mujoco_to_canonical(local_mujoco)

    def _distal_foot_site_id(self, body_id: str) -> str | None:
        for site_id, site in self.contact_sites.items():
            if site["body_id"] == body_id:
                return site_id
        return None

    def _is_foot_cap_contact(self, body_id: str, point_mujoco: np.ndarray) -> bool:
        site_id = self._distal_foot_site_id(body_id)
        if site_id is None:
            return False
        site = self.contact_sites[site_id]
        local = self._body_local_canonical(body_id, point_mujoco)
        lower_endpoint_y = float(site["local_center_m"]["y"])
        return float(local[1]) <= lower_endpoint_y + CONTACT_CLASSIFICATION_TOLERANCE_M

    def _contact_surface_point_for_body_geom(
        self,
        contact: Any,
        body_geom_id: int,
    ) -> np.ndarray:
        """Recover the named geom's nearest point from one MuJoCo contact.

        MuJoCo publishes ``contact.pos`` as the midpoint between the two
        nearest surface points, ``contact.dist`` as their signed distance, and
        the first contact-frame vector as the normal from geom 0 to geom 1.
        Therefore the two surface points are ``pos +/- dist * normal / 2``.
        """

        midpoint = np.asarray(contact.pos, dtype=np.float64)
        frame = np.asarray(contact.frame, dtype=np.float64).reshape(3, 3)
        normal = frame[0]
        signed_distance_m = float(contact.dist)
        _require(
            midpoint.shape == (3,)
            and normal.shape == (3,)
            and bool(np.all(np.isfinite(midpoint)))
            and bool(np.all(np.isfinite(normal)))
            and math.isfinite(signed_distance_m),
            "QSDK_R24_NATIVE_CONTACT_GEOMETRY_NONFINITE",
        )
        half_separation = 0.5 * signed_distance_m * normal
        if body_geom_id == int(contact.geom1):
            return midpoint - half_separation
        if body_geom_id == int(contact.geom2):
            return midpoint + half_separation
        raise NativeRecoveryRouteError("QSDK_R24_NATIVE_CONTACT_GEOM_IDENTITY")

    def _is_torso_ventral_contact(self, point_mujoco: np.ndarray) -> bool:
        local = self._body_local_canonical("torso", point_mujoco)
        _require(
            bool(np.all(np.isfinite(local))),
            "QSDK_R24_NATIVE_CONTACT_GEOMETRY_NONFINITE",
        )
        half_height = float(self.compiled["geometry"]["torso_size_m"]["y"]) / 2.0
        return float(local[1]) <= -half_height + CONTACT_CLASSIFICATION_TOLERANCE_M

    def _nonfoot_clearance(self, body_id: str) -> float:
        site_id = self._distal_foot_site_id(body_id)
        if site_id is None:
            fromto = np.zeros(6, dtype=np.float64)
            distance = float(
                mujoco.mj_geomDistance(
                    self.model,
                    self.data,
                    self.ground_geom_id,
                    self.body_geom_ids[body_id],
                    10.0,
                    fromto,
                )
            )
            _require(math.isfinite(distance), "QSDK_R24D18_GEOM_DISTANCE_NONFINITE")
            return distance

        site = self.contact_sites[site_id]
        body = int(self.model.body(body_id).id)
        rotation = np.asarray(self.data.xmat[body], dtype=np.float64).reshape(3, 3)
        canonical_axis_mujoco = base._canonical_to_mujoco([0.0, 1.0, 0.0])
        axis_mujoco = rotation @ canonical_axis_mujoco
        axis_canonical = base._mujoco_to_canonical(axis_mujoco)
        lower_center = self._site_world(site)
        length = float(self.body_specs[body_id]["collision"]["length_m"])
        upper_center = lower_center + axis_mujoco * length
        radius = float(self.body_specs[body_id]["collision"]["radius_m"])
        radial_vertical = radius * math.sqrt(
            max(0.0, 1.0 - float(axis_canonical[1]) ** 2)
        )
        lower_seam_y = (
            float(base._mujoco_to_canonical(lower_center)[1]) - radial_vertical
        )
        upper_cap_y = float(base._mujoco_to_canonical(upper_center)[1]) - radius
        return min(lower_seam_y, upper_cap_y)

    def _capture_contacts(
        self,
        semantic_step: int,
        native_substep: int,
        foot_impulses: dict[str, float],
        foot_contact_ids: dict[str, list[str]],
        nonfoot_impulses: dict[str, float],
        nonfoot_contact_ids: dict[str, list[str]],
        nonfoot_minimum_distance: dict[str, float],
        torso_ventral: list[bool],
    ) -> None:
        force_torque = np.zeros(6, dtype=np.float64)
        for contact_index in range(int(self.data.ncon)):
            contact = self.data.contact[contact_index]
            geoms = {int(contact.geom1), int(contact.geom2)}
            if self.ground_geom_id not in geoms:
                continue
            body_geom = next(
                (value for value in geoms if value != self.ground_geom_id), None
            )
            body_id = (
                self.body_ids_by_geom.get(int(body_geom))
                if body_geom is not None
                else None
            )
            if body_id is None:
                continue
            mujoco.mj_contactForce(self.model, self.data, contact_index, force_torque)
            normal_force_n = max(0.0, abs(float(force_torque[0])))
            impulse_ns = normal_force_n * float(self.model.opt.timestep)
            contact_id = (
                f"mujoco_contact_{semantic_step}_{native_substep}_{contact_index}"
            )
            point = np.asarray(contact.pos, dtype=np.float64)
            site_id = self._distal_foot_site_id(body_id)
            if site_id is not None and self._is_foot_cap_contact(body_id, point):
                foot_impulses[site_id] += impulse_ns
                foot_contact_ids[site_id].append(contact_id)
                continue
            nonfoot_impulses[body_id] += impulse_ns
            nonfoot_contact_ids[body_id].append(contact_id)
            nonfoot_minimum_distance[body_id] = min(
                nonfoot_minimum_distance[body_id],
                float(contact.dist),
            )
            torso_point = (
                self._contact_surface_point_for_body_geom(contact, int(body_geom))
                if body_id == "torso" and self.reconstruct_torso_contact_surface
                else point
            )
            if body_id == "torso" and self._is_torso_ventral_contact(torso_point):
                torso_ventral[0] = True

    def _state_frame(
        self,
        semantic_step: int,
        foot_contact_ids: Mapping[str, Sequence[str]],
    ) -> dict[str, Any]:
        state = self.state_frame(semantic_step, np.zeros(3, dtype=np.float64))
        state["adapter_capability_sha256"] = self.capability_sha256
        for item in state["ordered_contact_observations"]:
            ids = list(foot_contact_ids[item["contact_site_id"]])
            present = bool(ids)
            item["presence"] = present
            item["bears_support"] = present
            item["provenance"] = {
                "adapter_id": ADAPTER_ID,
                "engine_contact_ids": ids,
                "aggregation_rule_id": FOOT_CLASSIFICATION_RULE_ID,
                "quality": "qualified_bearing",
            }
        return state

    def step_native(
        self,
        *,
        semantic_step: int,
        phase: str,
        arm_kind: str,
        control: Mapping[str, Any],
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        """Execute exactly one 120 Hz outer step and return its native observation."""

        _require(self.host_step_count == semantic_step, "QSDK_R24D18_HOST_STEP_ORDER")
        _require(phase not in _TERMINAL_PHASES, "QSDK_R24D18_TERMINAL_PHASE_STEPPED")
        commands = control.get("ordered_commands")
        _require(isinstance(commands, list), "QSDK_R24D18_COMMAND_CONTAINER")
        assert isinstance(commands, list)
        active = bool(commands)
        _require(
            not active or len(commands) == len(ORDERED_ACTUATOR_IDS),
            "QSDK_R24D18_COMMAND_CARDINALITY",
        )
        _require(
            arm_kind != "matched_zero_command" or not active,
            "QSDK_R24D18_MATCHED_ZERO_COMMAND_PRESENT",
        )

        targets = np.zeros(len(ORDERED_ACTUATOR_IDS), dtype=np.float64)
        host_clamped: list[bool] = [False] * len(ORDERED_ACTUATOR_IDS)
        if active:
            targets, host_clamped = prepare_active_recovery_host_command_v1(
                self._joint_positions(),
                commands,
            )

        signed_impulses = np.zeros(len(ORDERED_ACTUATOR_IDS), dtype=np.float64)
        maximum_forces = np.zeros(len(ORDERED_ACTUATOR_IDS), dtype=np.float64)
        implicit_v3_enabled = (
            self.energy_ledger_profile_id == IMPLICIT_STEP_ENERGY_LEDGER_PROFILE_ID
        )
        step_actuator_work_j = 0.0
        step_constraint_work_j = 0.0
        step_damper_work_j = 0.0
        step_fluid_work_j = 0.0
        step_adhesion_work_j = 0.0
        step_dissipated_energy_j = 0.0
        step_effective_centered_actuator_work_j = 0.0
        step_effective_centered_generalized_actuator_work_j = 0.0
        step_centered_constraint_work_j = 0.0
        step_centered_damper_work_j = 0.0
        step_centered_fluid_work_j = 0.0
        step_centered_adhesion_work_j = 0.0
        step_centered_dissipated_energy_j = 0.0
        implicit_substep_receipts: list[dict[str, Any]] = []
        foot_impulses = {
            site_id: 0.0 for site_id in self.morphology["ordered_contact_site_ids"]
        }
        foot_contact_ids = {
            site_id: [] for site_id in self.morphology["ordered_contact_site_ids"]
        }
        nonfoot_impulses = {
            body_id: 0.0 for body_id in self.morphology["ordered_body_ids"]
        }
        nonfoot_contact_ids = {
            body_id: [] for body_id in self.morphology["ordered_body_ids"]
        }
        nonfoot_minimum_distance = {
            body_id: math.inf for body_id in self.morphology["ordered_body_ids"]
        }
        torso_ventral = [False]
        time_before = float(self.data.time)
        for native_substep in range(NATIVE_SUBSTEPS_PER_OUTER_STEP):
            mujoco.mj_step1(self.model, self.data)
            pre_step_qvel = np.asarray(self.data.qvel, dtype=np.float64).copy()
            if active:
                native_targets = targets
            else:
                native_targets = self._joint_velocities()
            self.data.ctrl[:] = native_targets
            if implicit_v3_enabled:
                implicit_step = advance_implicitfast_after_control_v3(
                    model=self.model,
                    data=self.data,
                    target_actuator_velocity_rad_s=native_targets,
                    velocity_gain_nm_s_per_rad=(
                        self.implicit_velocity_gain_nm_s_per_rad
                    ),
                    force_range_lower_nm=self.implicit_force_range_lower_nm,
                    force_range_upper_nm=self.implicit_force_range_upper_nm,
                )
                forces = np.asarray(
                    implicit_step.reported_pre_actuator_force_nm,
                    dtype=np.float64,
                )
                velocities = np.asarray(
                    implicit_step.reported_pre_actuator_velocity_rad_s,
                    dtype=np.float64,
                )
                energy_work = implicit_step.historical_v2
                implicit_v3 = implicit_step.implicit_v3
                if (
                    self.implicit_substep_receipt_schema
                    == SIGNED_WORK_PREPROJECTION_SUBSTEP_RECEIPT_SCHEMA
                ):
                    implicit_substep_receipts.append(
                        implicit_step.receipt_v3(native_substep)
                    )
                elif (
                    self.implicit_substep_receipt_schema
                    == SPARSE_MOMENT_IMPLICIT_SUBSTEP_RECEIPT_SCHEMA
                ):
                    implicit_substep_receipts.append(
                        implicit_step.receipt_v2(native_substep)
                    )
                else:
                    implicit_substep_receipts.append(
                        implicit_step.receipt_v1(native_substep)
                    )
                step_effective_centered_actuator_work_j += (
                    implicit_v3.effective_centered_actuator_work_j
                )
                step_effective_centered_generalized_actuator_work_j += (
                    implicit_v3.effective_centered_generalized_actuator_work_j
                )
                step_centered_constraint_work_j += (
                    implicit_v3.centered_constraint_work_j
                )
                step_centered_damper_work_j += implicit_v3.centered_damper_work_j
                step_centered_fluid_work_j += implicit_v3.centered_fluid_work_j
                step_centered_adhesion_work_j += implicit_v3.centered_adhesion_work_j
                step_centered_dissipated_energy_j += (
                    implicit_v3.centered_dissipated_energy_j
                )
            else:
                mujoco.mj_step2(self.model, self.data)
                forces = np.asarray(
                    self.data.actuator_force,
                    dtype=np.float64,
                ).copy()
                velocities = np.asarray(
                    self.data.actuator_velocity,
                    dtype=np.float64,
                ).copy()
                energy_work = measure_native_energy_work_v2(
                    timestep_s=float(self.model.opt.timestep),
                    actuator_force=forces,
                    actuator_velocity=velocities,
                    generalized_velocity=pre_step_qvel,
                    generalized_actuator_force=np.asarray(
                        self.data.qfrc_actuator,
                        dtype=np.float64,
                    ),
                    generalized_constraint_force=np.asarray(
                        self.data.qfrc_constraint,
                        dtype=np.float64,
                    ),
                    generalized_damper_force=np.asarray(
                        self.data.qfrc_damper,
                        dtype=np.float64,
                    ),
                    generalized_fluid_force=np.asarray(
                        self.data.qfrc_fluid,
                        dtype=np.float64,
                    ),
                    generalized_adhesion_force=np.asarray(
                        self.data.qfrc_adhesion,
                        dtype=np.float64,
                    ),
                )
            if not active:
                _require(
                    bool(np.all(np.abs(forces) <= ZERO_ACTUATOR_FORCE_TOLERANCE_NM)),
                    "QSDK_R24D18_ZERO_COMMAND_ACTUATOR_FORCE_NONZERO",
                )
            signed_impulses += forces * float(self.model.opt.timestep)
            maximum_forces = np.maximum(maximum_forces, np.abs(forces))
            step_actuator_work_j += energy_work.actuator_work_j
            step_constraint_work_j += energy_work.constraint_work_j
            step_damper_work_j += energy_work.damper_work_j
            step_fluid_work_j += energy_work.fluid_work_j
            step_adhesion_work_j += energy_work.adhesion_work_j
            step_dissipated_energy_j += energy_work.dissipated_energy_j
            self._capture_contacts(
                semantic_step,
                native_substep,
                foot_impulses,
                foot_contact_ids,
                nonfoot_impulses,
                nonfoot_contact_ids,
                nonfoot_minimum_distance,
                torso_ventral,
            )
            self.solver_step_count += 1
        self.host_step_count += 1
        self.cumulative_actuator_work_j += step_actuator_work_j
        self.cumulative_constraint_work_j += step_constraint_work_j
        self.cumulative_damper_work_j += step_damper_work_j
        self.cumulative_fluid_work_j += step_fluid_work_j
        self.cumulative_adhesion_work_j += step_adhesion_work_j
        self.cumulative_dissipated_energy_j += step_dissipated_energy_j
        energy_preprojection_summary: dict[str, Any] | None = None
        if self.energy_work_preprojection_required:
            energy_preprojection_summary = summarize_energy_work_preprojections_v1(
                [
                    receipt["portable_v3_energy_preprojection"]
                    for receipt in implicit_substep_receipts
                ]
            )
            if (
                energy_preprojection_summary["support_status"] != "supported_exact"
                and self.energy_work_preprojection_refusal_enabled
            ):
                diagnostic = {
                    "schema_version": (
                        "sporespore_mujoco_energy_work_projection_refusal_diagnostic_v1"
                    ),
                    "error_code": "QSDK_R24D36_PORTABLE_ENERGY_PROJECTION_REFUSED",
                    "route_id": self.route_id,
                    "semantic_step": semantic_step,
                    "phase": phase,
                    "arm_kind": arm_kind,
                    "energy_work_preprojection_profile_id": (
                        ENERGY_WORK_PREPROJECTION_PROFILE_ID
                    ),
                    "portable_v3_preprojection_summary": energy_preprojection_summary,
                    "implicit_substep_energy_receipts": deepcopy(
                        implicit_substep_receipts
                    ),
                    "historical_v2_cumulative_signed_terms": {
                        "constraint_work_j": self.cumulative_constraint_work_j,
                        "damper_work_j": self.cumulative_damper_work_j,
                        "fluid_work_j": self.cumulative_fluid_work_j,
                        "adhesion_work_j": self.cumulative_adhesion_work_j,
                        "historical_derived_dissipated_energy_j": (
                            self.cumulative_dissipated_energy_j
                        ),
                    },
                    "execution_counts": {
                        "model_construction_count": 1,
                        "world_attempt_count": 1,
                        "world_build_count": 1,
                        "native_outer_steps_integrated": self.host_step_count,
                        "portable_observations_published": semantic_step,
                        "native_solver_step_count": self.solver_step_count,
                        "physics_state_modified": True,
                    },
                    "historical_v2_nonnegative_guard_invoked": False,
                    "portable_observation_constructed_for_current_step": False,
                    "source_values_retained_exactly": True,
                    "prone_to_standing_claimed": False,
                    "physical_acceptance_authority": False,
                    "release_authority": False,
                }
                try:
                    json.dumps(
                        diagnostic,
                        allow_nan=False,
                        ensure_ascii=False,
                        separators=(",", ":"),
                        sort_keys=True,
                    )
                except (TypeError, ValueError) as error:
                    raise NativeRecoveryRouteError(
                        "QSDK_R24D36_ENERGY_PROJECTION_DIAGNOSTIC_NOT_JSON_SAFE"
                    ) from error
                raise NativeEnergyProjectionRefusal(diagnostic)
            if energy_preprojection_summary["support_status"] == "supported_exact":
                step_centered_dissipated_energy_j = float(
                    energy_preprojection_summary[
                        "portable_v1_dissipated_energy_increment_j"
                    ]
                )
            else:
                # Observation V2 publishes the disjoint native terms through
                # the R24D38 mapper.  This accumulator is never used as its
                # passive source and therefore stays exact zero until the
                # mapper either accepts the qualified-zero subset or refuses.
                step_centered_dissipated_energy_j = 0.0
        else:
            _require(
                self.cumulative_dissipated_energy_j >= 0.0,
                "QSDK_R24D31_CUMULATIVE_DISSIPATION_NEGATIVE",
            )
        if implicit_v3_enabled:
            self.cumulative_effective_centered_actuator_work_j += (
                step_effective_centered_actuator_work_j
            )
            self.cumulative_effective_centered_generalized_actuator_work_j += (
                step_effective_centered_generalized_actuator_work_j
            )
            self.cumulative_centered_constraint_work_j += (
                step_centered_constraint_work_j
            )
            self.cumulative_centered_damper_work_j += step_centered_damper_work_j
            self.cumulative_centered_fluid_work_j += step_centered_fluid_work_j
            self.cumulative_centered_adhesion_work_j += step_centered_adhesion_work_j
            self.cumulative_centered_dissipated_energy_j += (
                step_centered_dissipated_energy_j
            )
            _require(
                self.cumulative_centered_dissipated_energy_j >= 0.0,
                "QSDK_R24D34_CUMULATIVE_CENTERED_DISSIPATION_NEGATIVE",
            )
            selected_step_actuator_work_j = step_effective_centered_actuator_work_j
            selected_cumulative_actuator_work_j = (
                self.cumulative_effective_centered_actuator_work_j
            )
            selected_step_constraint_work_j = step_centered_constraint_work_j
            selected_step_damper_work_j = step_centered_damper_work_j
            selected_step_fluid_work_j = step_centered_fluid_work_j
            selected_step_adhesion_work_j = step_centered_adhesion_work_j
            selected_step_dissipated_energy_j = step_centered_dissipated_energy_j
            selected_cumulative_constraint_work_j = (
                self.cumulative_centered_constraint_work_j
            )
            selected_cumulative_damper_work_j = self.cumulative_centered_damper_work_j
            selected_cumulative_fluid_work_j = self.cumulative_centered_fluid_work_j
            selected_cumulative_adhesion_work_j = (
                self.cumulative_centered_adhesion_work_j
            )
            selected_cumulative_dissipated_energy_j = (
                self.cumulative_centered_dissipated_energy_j
            )
        else:
            selected_step_actuator_work_j = step_actuator_work_j
            selected_cumulative_actuator_work_j = self.cumulative_actuator_work_j
            selected_step_constraint_work_j = step_constraint_work_j
            selected_step_damper_work_j = step_damper_work_j
            selected_step_fluid_work_j = step_fluid_work_j
            selected_step_adhesion_work_j = step_adhesion_work_j
            selected_step_dissipated_energy_j = step_dissipated_energy_j
            selected_cumulative_constraint_work_j = self.cumulative_constraint_work_j
            selected_cumulative_damper_work_j = self.cumulative_damper_work_j
            selected_cumulative_fluid_work_j = self.cumulative_fluid_work_j
            selected_cumulative_adhesion_work_j = self.cumulative_adhesion_work_j
            selected_cumulative_dissipated_energy_j = (
                self.cumulative_dissipated_energy_j
            )
        mujoco.mj_subtreeVel(self.model, self.data)
        current_energy = self._mechanical_energy()

        for body_id in self.morphology["ordered_body_ids"]:
            if math.isinf(nonfoot_minimum_distance[body_id]):
                nonfoot_minimum_distance[body_id] = self._nonfoot_clearance(body_id)
        application, application_sha256 = canonicalize_recovery_application_receipt_v1(
            self.core,
            route_id=self.route_id,
            semantic_step=semantic_step,
            phase=phase,
            arm_kind=arm_kind,
            control=control,
            active=active,
            targets=targets,
            host_clamped=host_clamped,
            signed_impulses=signed_impulses,
            maximum_forces=maximum_forces,
            step_actuator_work_j=selected_step_actuator_work_j,
        )
        command_sha256 = control.get("command_sha256")
        if not isinstance(command_sha256, str):
            command_sha256 = _canonical_sha256(
                self.core,
                {
                    "schema_version": "sporespore_recovery_no_command_v1",
                    "arm_kind": arm_kind,
                    "phase": phase,
                    "semantic_step": semantic_step,
                },
            )
        applied = {
            "adapter_id": ADAPTER_ID,
            "adapter_receipt_sha256": application_sha256,
            "source_semantic_step": semantic_step,
            "command_id": f"{arm_kind}_{phase}_{semantic_step}",
            "command_sha256": command_sha256,
            "actuator_profile_id": ACTUATOR_PROFILE_ID,
            "actuator_profile_sha256": self.physical_binding["profile_sha256"],
            "zero_command": arm_kind == "matched_zero_command",
            "ordered_applied_impulses": [
                {
                    "actuator_id": actuator_id,
                    "applied_angular_impulse_nms": float(signed_impulses[index]),
                    "host_clamped": bool(host_clamped[index]),
                }
                for index, actuator_id in enumerate(ORDERED_ACTUATOR_IDS)
            ],
            "source_measurement": True,
        }
        native_step = {
            "schema_version": self.native_step_receipt_schema,
            "route_id": self.route_id,
            "semantic_step": semantic_step,
            "host_step_before": semantic_step,
            "host_step_after": semantic_step + 1,
            "time_before_s": time_before,
            "time_after_s": float(self.data.time),
            "native_substep_count": NATIVE_SUBSTEPS_PER_OUTER_STEP,
            "solver_step_count_after": self.solver_step_count,
            "application_sha256": application_sha256,
            "foot_impulses_ns": foot_impulses,
            "nonfoot_impulses_ns": nonfoot_impulses,
            "current_mechanical_energy_j": current_energy,
            "cumulative_actuator_work_j": selected_cumulative_actuator_work_j,
            "energy_ledger_profile_id": self.energy_ledger_profile_id,
            "step_constraint_work_j": selected_step_constraint_work_j,
            "step_damper_work_j": selected_step_damper_work_j,
            "step_fluid_work_j": selected_step_fluid_work_j,
            "step_adhesion_work_j": selected_step_adhesion_work_j,
            "step_dissipated_energy_j": selected_step_dissipated_energy_j,
            "cumulative_constraint_work_j": selected_cumulative_constraint_work_j,
            "cumulative_damper_work_j": selected_cumulative_damper_work_j,
            "cumulative_fluid_work_j": selected_cumulative_fluid_work_j,
            "cumulative_adhesion_work_j": selected_cumulative_adhesion_work_j,
            "cumulative_dissipated_energy_j": (selected_cumulative_dissipated_energy_j),
        }
        if implicit_v3_enabled:
            native_step.update(
                {
                    "historical_v2_energy_ledger_profile_id": ENERGY_LEDGER_PROFILE_ID,
                    "historical_v2_step_actuator_work_j": step_actuator_work_j,
                    "historical_v2_step_constraint_work_j": step_constraint_work_j,
                    "historical_v2_step_damper_work_j": step_damper_work_j,
                    "historical_v2_step_fluid_work_j": step_fluid_work_j,
                    "historical_v2_step_adhesion_work_j": step_adhesion_work_j,
                    "historical_v2_step_dissipated_energy_j": (
                        step_dissipated_energy_j
                    ),
                    "historical_v2_cumulative_actuator_work_j": (
                        self.cumulative_actuator_work_j
                    ),
                    "historical_v2_cumulative_constraint_work_j": (
                        self.cumulative_constraint_work_j
                    ),
                    "historical_v2_cumulative_damper_work_j": (
                        self.cumulative_damper_work_j
                    ),
                    "historical_v2_cumulative_fluid_work_j": (
                        self.cumulative_fluid_work_j
                    ),
                    "historical_v2_cumulative_adhesion_work_j": (
                        self.cumulative_adhesion_work_j
                    ),
                    "historical_v2_cumulative_dissipated_energy_j": (
                        self.cumulative_dissipated_energy_j
                    ),
                    "step_effective_centered_actuator_work_j": (
                        step_effective_centered_actuator_work_j
                    ),
                    "step_effective_centered_generalized_actuator_work_j": (
                        step_effective_centered_generalized_actuator_work_j
                    ),
                    "cumulative_effective_centered_actuator_work_j": (
                        self.cumulative_effective_centered_actuator_work_j
                    ),
                    "cumulative_effective_centered_generalized_actuator_work_j": (
                        self.cumulative_effective_centered_generalized_actuator_work_j
                    ),
                    "portable_energy_selection": {
                        "actuator_work": "v3_effective_centered_actuator_work",
                        "dissipation": (
                            "r24d36_exact_zero_qualified_passive_dissipation"
                            if self.energy_work_preprojection_required
                            else "v3_centered_constraint_and_passive_work"
                        ),
                        "historical_v2_retained": True,
                    },
                    "implicit_substep_energy_receipts": implicit_substep_receipts,
                }
            )
            if energy_preprojection_summary is not None:
                native_step["portable_energy_preprojection_summary"] = (
                    energy_preprojection_summary
                )
        source_trace_sha256 = _canonical_sha256(self.core, native_step)
        state = self._state_frame(semantic_step, foot_contact_ids)
        torso = int(self.model.body("torso").id)
        observation = {
            "schema_version": "sporespore_recovery_observation_v1",
            "task_id": TASK_ID,
            "semantics_id": SEMANTICS_ID,
            "actuator_profile_id": ACTUATOR_PROFILE_ID,
            "semantic_step": semantic_step,
            "outer_step_duration_s": OUTER_DT_S,
            "state": state,
            "center_of_mass": {
                "position_world_m": _canonical_vector(self.data.subtree_com[torso]),
                "linear_velocity_world_m_s": _canonical_vector(
                    self.data.subtree_linvel[torso]
                ),
                "source_measurement": True,
            },
            "ordered_foot_bearing_observations": [
                {
                    "contact_site_id": site_id,
                    "bearing_normal_impulse_ns": float(foot_impulses[site_id]),
                    "ordinary_unilateral_contact": True,
                    "source_measurement": True,
                }
                for site_id in self.morphology["ordered_contact_site_ids"]
            ],
            "ordered_body_clearance_observations": [
                {
                    "adapter_id": ADAPTER_ID,
                    "body_id": body_id,
                    "nonfoot_contact_present": bool(nonfoot_contact_ids[body_id]),
                    "ventral_surface_contact": body_id == "torso" and torso_ventral[0],
                    "accumulated_nonfoot_normal_impulse_ns": float(
                        nonfoot_impulses[body_id]
                    ),
                    "minimum_nonfoot_clearance_m": float(
                        nonfoot_minimum_distance[body_id]
                    ),
                    "engine_contact_ids": list(nonfoot_contact_ids[body_id]),
                    "classification_rule_id": self.nonfoot_classification_rule_id,
                    "foot_site_contacts_excluded": True,
                    "source_measurement": True,
                }
                for body_id in self.morphology["ordered_body_ids"]
            ],
            "applied_actuation": applied,
            "external_interventions": _zero_intervention_ledger(),
            "controller_ownership": _controller_owner(arm_kind, phase),
            "energy_balance": {
                "initial_mechanical_energy_j": self.initial_mechanical_energy_j,
                "current_mechanical_energy_j": current_energy,
                "cumulative_applied_actuator_work_j": (
                    selected_cumulative_actuator_work_j
                ),
                "cumulative_external_work_j": 0.0,
                "cumulative_dissipated_energy_j": (
                    selected_cumulative_dissipated_energy_j
                ),
                "source_measurement": True,
            },
            "engine_step_identity": {
                "schema_version": "sporespore_recovery_engine_step_identity_v1",
                "source_kind": "native_post_step",
                "adapter_id": ADAPTER_ID,
                "engine": ENGINE_ID,
                "capability_sha256": self.capability_sha256,
                "source_trace_sha256": source_trace_sha256,
                "semantic_step": semantic_step,
                "host_step_before": semantic_step,
                "host_step_after": semantic_step + 1,
                "native_solver_substep_count": NATIVE_SUBSTEPS_PER_OUTER_STEP,
                "post_step_observation": True,
                "engine_identity_exposed_to_policy": False,
            },
        }
        return observation, {
            "native_step": native_step,
            "native_step_sha256": source_trace_sha256,
            "application": application,
            "application_sha256": application_sha256,
        }


class MujocoImplicitStepRecoveryWorld(MujocoNativeRecoveryWorld):
    """Production recovery world selecting the qualified v3 energy receipt."""

    route_id = IMPLICIT_STEP_ROUTE_ID
    energy_ledger_profile_id = IMPLICIT_STEP_ENERGY_LEDGER_PROFILE_ID
    native_step_receipt_schema = IMPLICIT_STEP_NATIVE_RECEIPT_SCHEMA
    implicit_substep_receipt_schema = IMPLICIT_SUBSTEP_RECEIPT_SCHEMA


class MujocoSparseMomentImplicitStepRecoveryWorld(MujocoImplicitStepRecoveryWorld):
    """R35 route retaining the validated MuJoCo sparse-expansion receipt."""

    route_id = SPARSE_MOMENT_IMPLICIT_STEP_ROUTE_ID
    native_step_receipt_schema = SPARSE_MOMENT_IMPLICIT_STEP_NATIVE_RECEIPT_SCHEMA
    implicit_substep_receipt_schema = SPARSE_MOMENT_IMPLICIT_SUBSTEP_RECEIPT_SCHEMA


class MujocoSignedWorkPreprojectionRecoveryWorld(
    MujocoSparseMomentImplicitStepRecoveryWorld
):
    """R36 route refusing unrepresentable signed work before portable v1."""

    route_id = SIGNED_WORK_PREPROJECTION_ROUTE_ID
    native_step_receipt_schema = SIGNED_WORK_PREPROJECTION_NATIVE_RECEIPT_SCHEMA
    implicit_substep_receipt_schema = SIGNED_WORK_PREPROJECTION_SUBSTEP_RECEIPT_SCHEMA
    energy_work_preprojection_required = True
    energy_work_preprojection_refusal_enabled = True


class MujocoObservationV2RecoveryWorld(MujocoSignedWorkPreprojectionRecoveryWorld):
    """Additive R24D39 consumer over the unchanged R24D36 native source."""

    publication_route_id = OBSERVATION_V2_CONSUMER_ROUTE_ID
    energy_work_preprojection_refusal_enabled = False

    def __init__(
        self,
        core: LocomotionCore,
        route: PublicProfileModelRoute,
        capability_sha256: str,
    ) -> None:
        super().__init__(core, route, capability_sha256)
        morphology_context = _portable_morphology_context(route)
        _require(
            morphology_context is not None,
            "QSDK_R24D39_RECOVERY_MORPHOLOGY_CONTEXT_REQUIRED",
        )
        self.observation_v2_morphology_context = morphology_context
        self.observation_v2_component_batches: list[dict[str, Any]] = []

    def step_native(
        self,
        *,
        semantic_step: int,
        phase: str,
        arm_kind: str,
        control: Mapping[str, Any],
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        observation_v1, native = super().step_native(
            semantic_step=semantic_step,
            phase=phase,
            arm_kind=arm_kind,
            control=control,
        )
        native_step = native.get("native_step")
        _require(isinstance(native_step, dict), "QSDK_R24D39_NATIVE_STEP_REQUIRED")
        substeps = native_step.get("implicit_substep_energy_receipts")
        _require(
            isinstance(substeps, list)
            and len(substeps) == NATIVE_SUBSTEPS_PER_OUTER_STEP,
            "QSDK_R24D39_NATIVE_COMPONENT_RECEIPTS_REQUIRED",
        )
        self.observation_v2_component_batches.append(
            {
                "semantic_step": semantic_step,
                "ordered_substep_receipts": deepcopy(substeps),
            }
        )
        observation_base = {
            key: deepcopy(value)
            for key, value in observation_v1.items()
            if key not in {"schema_version", "energy_balance"}
        }
        publication = publish_recovery_observation_v2(
            self.core,
            mapping_request={
                "schema_version": (
                    "sporespore_mujoco_recovery_energy_v2_mapping_request_v1"
                ),
                "source_route_id": SIGNED_WORK_PREPROJECTION_ROUTE_ID,
                "initial_mechanical_energy_j": self.initial_mechanical_energy_j,
                "current_mechanical_energy_j": observation_v1["energy_balance"][
                    "current_mechanical_energy_j"
                ],
                "observation_base": observation_base,
                "ordered_native_component_batches": deepcopy(
                    self.observation_v2_component_batches
                ),
            },
            descriptor=self.descriptor,
            morphology_context=self.observation_v2_morphology_context,
            capability_sha256=self.capability_sha256,
            runtime_qualification_sha256=R24D17_RUNTIME_QUALIFICATION_SHA256,
            arm_kind=arm_kind,
            phase=phase,
        )
        if publication.get("support_status") != "supported_exact":
            raise NativeObservationV2PublicationRefusal(publication)
        native["observation_v2_in_run_invariants"] = (
            validate_recovery_observation_v2_in_run_invariants_v1(
                self.core,
                publication=publication,
                native_step=native_step,
                ordered_native_component_batches=(
                    self.observation_v2_component_batches
                ),
                expected_arm_kind=arm_kind,
                expected_phase=phase,
            )
        )
        native["observation_v2_publication"] = publication
        native["native_source_route_id"] = self.route_id
        native["publication_route_id"] = self.publication_route_id
        return deepcopy(publication["portable_observation"]), native


def _physical_initialization_request(
    arm_kind: str,
    capability: Mapping[str, Any],
) -> dict[str, Any]:
    return {
        "schema_version": "sporespore_recovery_initialize_request_v1",
        "task_id": TASK_ID,
        "semantics_id": SEMANTICS_ID,
        "actuator_profile_id": ACTUATOR_PROFILE_ID,
        "threshold_profile_id": PHYSICAL_THRESHOLD_PROFILE_ID,
        "descriptor": base.s169_descriptor(),
        "adapter_capability": deepcopy(dict(capability)),
        "arm_kind": arm_kind,
    }


def _physical_initialization_request_v2(
    arm_kind: str,
    capability: Mapping[str, Any],
    morphology_context: Mapping[str, Any],
) -> dict[str, Any]:
    request = _physical_initialization_request(arm_kind, capability)
    request["schema_version"] = "sporespore_recovery_initialize_request_v2"
    request["morphology_context"] = deepcopy(dict(morphology_context))
    return request


def _portable_morphology_context(
    route: PublicProfileModelRoute | None,
) -> dict[str, Any] | None:
    if route is None or route.compiled.get("schema_version") != (
        "sporespore_recovery_morphology_receipt_v1"
    ):
        return None
    receipt = route.compiled
    return {
        "schema_version": RECOVERY_MORPHOLOGY_CONTEXT_SCHEMA,
        "recovery_morphology_id": receipt["recovery_morphology_id"],
        "recovery_descriptor": deepcopy(receipt["descriptor"]),
        "recovery_descriptor_sha256": receipt["descriptor_sha256"],
        "base_descriptor_sha256": receipt["base_descriptor_sha256"],
        "base_morphology_spec_sha256": receipt["base_morphology_spec_sha256"],
        "recovery_morphology_spec_sha256": receipt["recovery_morphology_spec_sha256"],
    }


def _initial_observation_projection(observation: Mapping[str, Any]) -> dict[str, Any]:
    state = observation["state"]
    energy = observation["energy_balance"]
    return {
        "base_pose_world": state["base_pose_world"],
        "base_twist_world": state["base_twist_world"],
        "ordered_joint_observations": state["ordered_joint_observations"],
        "ordered_contact_observations": state["ordered_contact_observations"],
        "gravity_world_m_s2": state["gravity_world_m_s2"],
        "task_frame": state["task_frame"],
        "center_of_mass": observation["center_of_mass"],
        "ordered_foot_bearing_observations": observation[
            "ordered_foot_bearing_observations"
        ],
        "ordered_body_clearance_observations": observation[
            "ordered_body_clearance_observations"
        ],
        "energy_initial_mechanical_j": energy["initial_mechanical_energy_j"],
        "energy_current_mechanical_j": energy["current_mechanical_energy_j"],
    }


def _run_arm(
    core: LocomotionCore,
    route: PublicProfileModelRoute,
    *,
    cell: Mapping[str, Any],
    arm_kind: str,
    horizon_steps: int,
    world_type: type[MujocoNativeRecoveryWorld] = MujocoNativeRecoveryWorld,
    continue_through_stance: bool = False,
) -> dict[str, Any]:
    capability = mujoco_recovery_capability_v1()
    morphology_context = _portable_morphology_context(route)
    initialize_request_schema = (
        "sporespore_recovery_initialize_request_v1"
        if morphology_context is None
        else "sporespore_recovery_initialize_request_v2"
    )
    collection_request_schemas: list[str] = []
    step_request_schemas: list[str] = []
    control_request_schemas: list[str] = []
    if morphology_context is None:
        initialized = core.recovery_initialize_v1(
            _physical_initialization_request(arm_kind, capability)
        )
    else:
        initialized = core.recovery_initialize_v2(
            _physical_initialization_request_v2(
                arm_kind,
                capability,
                morphology_context,
            )
        )
    _require(
        initialized.get("support_status") == "supported_exact"
        and initialized.get("physical_threshold_authority") is True
        and initialized.get("physical_question_opened") is False,
        "QSDK_R24D18_PORTABLE_INITIALIZATION_REFUSED",
    )
    capability_sha256 = str(initialized["capability_sha256"])
    world = world_type(core, route, capability_sha256)
    uses_observation_v2 = isinstance(world, MujocoObservationV2RecoveryWorld)
    initializer = world.initialize_prone(
        cell_id=str(cell["cell_id"]),
        initial_state_id=str(cell["initial_state_id"]),
        seed=int(cell["seed"]),
        torso_roll_rad=float(cell["torso_roll_rad"]),
    )
    memory = initialized["memory"]
    phase = str(memory["phase"])
    control = _bootstrap_control(core, arm_kind, phase)
    observations: list[dict[str, Any]] = []
    step_receipts: list[dict[str, Any]] = []
    native_receipts: list[dict[str, Any]] = []
    collector_receipts: list[dict[str, Any]] = []
    for semantic_step in range(horizon_steps):
        require_stance_continuation_commissioned_v1(
            phase,
            continue_through_stance,
        )
        observation, native = world.step_native(
            semantic_step=semantic_step,
            phase=phase,
            arm_kind=arm_kind,
            control=control,
        )
        collection_arguments = {
            "descriptor": base.s169_descriptor(),
            "observation": observation,
            "capability_sha256": capability_sha256,
            "runtime_qualification_sha256": R24D17_RUNTIME_QUALIFICATION_SHA256,
            "arm_kind": arm_kind,
            "phase": phase,
        }
        if uses_observation_v2:
            publication = native.get("observation_v2_publication")
            _require(
                isinstance(publication, dict)
                and publication.get("support_status") == "supported_exact",
                "QSDK_R24D39_PUBLICATION_RECEIPT_REQUIRED",
            )
            collection = deepcopy(publication["collection_request"])
            collected = deepcopy(publication["collection_receipt"])
        elif morphology_context is None:
            collection = collection_request_v1(**collection_arguments)
            collected = collect_native_v1(core, collection)
        else:
            collection = collection_request_v2(
                **collection_arguments,
                morphology_context=morphology_context,
            )
            collected = collect_native_v2(core, collection)
        collection_request_schemas.append(str(collection["schema_version"]))
        native_recovery_mapping = getattr(
            world,
            "native_recovery_morphology_readback",
            None,
        )
        require_supported_native_collection_v1(
            collected,
            refusal_context={
                "schema_version": ("sporespore_mujoco_recovery_arm_partial_state_v1"),
                "route_id": getattr(world, "publication_route_id", world.route_id),
                "cell_id": str(cell["cell_id"]),
                "arm_kind": arm_kind,
                "semantic_step": semantic_step,
                "phase": phase,
                "memory_before_current_step": memory,
                "control_applied_current_step": control,
                "current_collection_request": collection,
                "current_observation": observation,
                "current_native_receipt": native,
                "accepted_prefix": {
                    "observations": observations,
                    "native_receipts": native_receipts,
                    "collector_receipts": collector_receipts,
                    "portable_step_receipts": step_receipts,
                },
                "portable_request_trace": {
                    "initialize_request_schema": initialize_request_schema,
                    "collection_request_schemas": collection_request_schemas,
                    "step_request_schemas": step_request_schemas,
                    "control_request_schemas": control_request_schemas,
                },
                "portable_initialization_receipt": initialized,
                "portable_recovery_morphology_context": morphology_context,
                "initializer_manifest": initializer.manifest,
                "initializer_manifest_sha256": initializer.manifest_sha256,
                "canonical_pre_step_state": initializer.canonical_pre_step_state,
                "canonical_pre_step_state_sha256": (
                    initializer.canonical_pre_step_state_sha256
                ),
                "physical_binding": world.physical_binding,
                "model_identity": world.model_identity,
                "native_recovery_morphology_readback": native_recovery_mapping,
                "execution_counts": {
                    "model_construction_count": 1,
                    "world_attempt_count": 1,
                    "world_build_count": 1,
                    "native_outer_steps_completed": semantic_step + 1,
                    "portable_steps_accepted": len(observations),
                    "native_solver_step_count": world.solver_step_count,
                    "physics_state_modified": True,
                },
                "held_out_cell_access_count": 0,
                "held_out_selector_invocation_count": 0,
                "prone_to_standing_claimed": False,
                "physical_acceptance_authority": False,
                "release_authority": False,
            },
        )
        step_request: dict[str, Any] = {
            "schema_version": (
                "sporespore_recovery_step_request_v3"
                if uses_observation_v2
                else (
                    "sporespore_recovery_step_request_v1"
                    if morphology_context is None
                    else "sporespore_recovery_step_request_v2"
                )
            ),
            "descriptor": base.s169_descriptor(),
            "adapter_capability": capability,
            "memory": memory,
            "observation": observation,
        }
        if uses_observation_v2:
            step_request["morphology_context"] = deepcopy(morphology_context)
            stepped = core.recovery_step_v3(step_request)
        elif morphology_context is None:
            stepped = core.recovery_step_v1(step_request)
        else:
            step_request["morphology_context"] = deepcopy(morphology_context)
            stepped = core.recovery_step_v2(step_request)
        step_request_schemas.append(str(step_request["schema_version"]))
        _require(
            stepped.get("support_status") == "supported_exact",
            "QSDK_R24D18_PORTABLE_SUPERVISOR_REFUSED",
        )
        observations.append(observation)
        native_receipts.append(native)
        collector_receipts.append(collected)
        step_receipts.append(stepped)
        memory = stepped["memory"]
        phase = str(memory["phase"])
        if phase in _TERMINAL_PHASES:
            break
        if phase in _STANCE_PHASES and not continue_through_stance:
            break
        if phase in _STANCE_PHASES:
            _require(uses_observation_v2, "QSDK_R24D43_STANCE_REQUIRES_OBSERVATION_V2")
            control = plan_stance_control_v1(core, collection, stepped)
            control_request_schemas.append(
                "sporespore_recovery_stance_control_request_v1"
            )
        else:
            collection_arguments["phase"] = phase
            if uses_observation_v2:
                next_collection = deepcopy(collection)
                next_collection["phase"] = phase
                control = plan_control_v3(
                    core,
                    next_collection,
                    int(memory["phase_steps_observed"]),
                )
            elif morphology_context is None:
                next_collection = collection_request_v1(**collection_arguments)
                control = plan_control_v1(
                    core,
                    next_collection,
                    int(memory["phase_steps_observed"]),
                )
            else:
                next_collection = collection_request_v2(
                    **collection_arguments,
                    morphology_context=morphology_context,
                )
                control = plan_control_v2(
                    core,
                    next_collection,
                    int(memory["phase_steps_observed"]),
                )
            control_request_schemas.append(
                "sporespore_recovery_control_request_v3"
                if uses_observation_v2
                else (
                    "sporespore_recovery_control_request_v1"
                    if morphology_context is None
                    else "sporespore_recovery_control_request_v2"
                )
            )
        _require(
            control.get("support_status") == "supported_exact",
            "QSDK_R24D18_CONTROL_PLAN_REFUSED",
        )
    _require(bool(observations), "QSDK_R24D18_EMPTY_ARM_TRACE")
    initial_observation_sha256 = _canonical_sha256(
        core,
        _initial_observation_projection(observations[0]),
    )
    arm_result = {
        "schema_version": "sporespore_mujoco_recovery_arm_result_v1",
        "route_id": getattr(world, "publication_route_id", world.route_id),
        "native_source_route_id": world.route_id,
        "portable_observation_schema": (
            "sporespore_recovery_observation_v2"
            if uses_observation_v2
            else "sporespore_recovery_observation_v1"
        ),
        "cell_id": str(cell["cell_id"]),
        "arm_kind": arm_kind,
        "initializer_manifest": initializer.manifest,
        "initializer_manifest_sha256": initializer.manifest_sha256,
        "canonical_pre_step_state": initializer.canonical_pre_step_state,
        "canonical_pre_step_state_sha256": initializer.canonical_pre_step_state_sha256,
        "declared_initial_observation_sha256": initial_observation_sha256,
        "observations": observations,
        "native_receipts": native_receipts,
        "collector_receipts": collector_receipts,
        "portable_step_receipts": step_receipts,
        "final_phase": phase,
        "outer_step_count": len(observations),
        "native_solver_step_count": world.solver_step_count,
        "portable_recovery_context_bound": morphology_context is not None,
        "portable_recovery_morphology_context": (
            deepcopy(morphology_context) if morphology_context is not None else None
        ),
        "portable_initialization_receipt": initialized,
        "portable_request_trace": {
            "initialize_request_schema": initialize_request_schema,
            "collection_request_schemas": collection_request_schemas,
            "step_request_schemas": step_request_schemas,
            "control_request_schemas": control_request_schemas,
        },
        "model_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "stance_continuation_commissioned": continue_through_stance,
        "physics_state_modified": True,
        "physical_binding": world.physical_binding,
        "model_identity": world.model_identity,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    native_recovery_mapping = getattr(
        world,
        "native_recovery_morphology_readback",
        None,
    )
    if native_recovery_mapping is not None:
        arm_result["native_recovery_morphology_readback"] = deepcopy(
            native_recovery_mapping
        )
    return arm_result


def run_paired_development(
    core: LocomotionCore,
    *,
    cell: Mapping[str, Any],
    horizon_steps: int,
    route: PublicProfileModelRoute | None = None,
    world_type: type[MujocoNativeRecoveryWorld] = MujocoNativeRecoveryWorld,
    behavior_claim_authority: bool = True,
    continue_through_stance: bool = False,
) -> dict[str, Any]:
    """Run one paired repeatable development cell through genuine MuJoCo."""

    _require(1 <= horizon_steps <= 1200, "QSDK_R24D18_HORIZON")
    _require(
        str(cell.get("question_class")) == "development",
        "QSDK_R24D18_NONDEVELOPMENT_CELL",
    )
    exact_route = (
        compile_public_profile_model_route(
            core,
            descriptor=base.s169_descriptor(),
        )
        if route is None
        else route
    )
    candidate = _run_arm(
        core,
        exact_route,
        cell=cell,
        arm_kind="candidate_command",
        horizon_steps=horizon_steps,
        world_type=world_type,
        continue_through_stance=continue_through_stance,
    )
    matched_zero = _run_arm(
        core,
        exact_route,
        cell=cell,
        arm_kind="matched_zero_command",
        horizon_steps=horizon_steps,
        world_type=world_type,
        continue_through_stance=continue_through_stance,
    )
    initializer_identity_matched = (
        candidate["initializer_manifest_sha256"]
        == matched_zero["initializer_manifest_sha256"]
        and candidate["canonical_pre_step_state_sha256"]
        == matched_zero["canonical_pre_step_state_sha256"]
        and candidate["declared_initial_observation_sha256"]
        == matched_zero["declared_initial_observation_sha256"]
    )
    _require(initializer_identity_matched, "QSDK_R24D18_PAIRED_INITIAL_STATE_MISMATCH")
    capability = mujoco_recovery_capability_v1()
    morphology_context = _portable_morphology_context(exact_route)
    uses_observation_v2 = (
        candidate["portable_observation_schema"] == "sporespore_recovery_observation_v2"
    )
    _require(
        matched_zero["portable_observation_schema"]
        == candidate["portable_observation_schema"],
        "QSDK_R24D39_PAIRED_OBSERVATION_SCHEMA_MISMATCH",
    )
    evaluation_request = {
        "schema_version": (
            "sporespore_recovery_evaluation_request_v3"
            if uses_observation_v2
            else (
                "sporespore_recovery_evaluation_request_v1"
                if morphology_context is None
                else "sporespore_recovery_evaluation_request_v2"
            )
        ),
        "task_id": TASK_ID,
        "semantics_id": SEMANTICS_ID,
        "actuator_profile_id": ACTUATOR_PROFILE_ID,
        "threshold_profile_id": PHYSICAL_THRESHOLD_PROFILE_ID,
        "descriptor": base.s169_descriptor(),
        "adapter_capability": capability,
        "candidate_trace": {
            "schema_version": (
                "sporespore_recovery_trace_v2"
                if uses_observation_v2
                else "sporespore_recovery_trace_v1"
            ),
            "arm_kind": "candidate_command",
            "declared_initial_state_sha256": candidate[
                "declared_initial_observation_sha256"
            ],
            "observations": candidate["observations"],
        },
        "matched_zero_command_trace": {
            "schema_version": (
                "sporespore_recovery_trace_v2"
                if uses_observation_v2
                else "sporespore_recovery_trace_v1"
            ),
            "arm_kind": "matched_zero_command",
            "declared_initial_state_sha256": matched_zero[
                "declared_initial_observation_sha256"
            ],
            "observations": matched_zero["observations"],
        },
    }
    if uses_observation_v2:
        _require(
            morphology_context is not None,
            "QSDK_R24D39_RECOVERY_MORPHOLOGY_CONTEXT_REQUIRED",
        )
        evaluation_request["morphology_context"] = morphology_context
        evaluation = core.recovery_evaluate_trace_v3(evaluation_request)
    elif morphology_context is None:
        evaluation = core.recovery_evaluate_trace_v1(evaluation_request)
    else:
        evaluation_request["morphology_context"] = morphology_context
        evaluation = core.recovery_evaluate_trace_v2(evaluation_request)
    _require(
        evaluation.get("support_status") == "supported_exact"
        and evaluation.get("physical_development_trace_valid") is True,
        "QSDK_R24D18_PAIRED_EVALUATION_REFUSED",
    )
    physical_result = evaluation.get("verdict") == "physical_development_passed"
    return {
        "schema_version": "sporespore_mujoco_paired_recovery_development_result_v1",
        "route_id": candidate["route_id"],
        "question_class": "development",
        "cell": deepcopy(dict(cell)),
        "horizon_steps": horizon_steps,
        "model_xml_sha256": exact_route.model_xml_sha256,
        "model_xml_byte_length": len(exact_route.model_xml_bytes),
        "candidate": candidate,
        "matched_zero_command": matched_zero,
        "initializer_identity_matched": initializer_identity_matched,
        "evaluation": evaluation,
        "portable_evaluation_request_schema": str(evaluation_request["schema_version"]),
        "model_construction_count": 2,
        "world_attempt_count": 2,
        "world_build_count": 2,
        "outer_step_count": candidate["outer_step_count"]
        + matched_zero["outer_step_count"],
        "native_solver_step_count": candidate["native_solver_step_count"]
        + matched_zero["native_solver_step_count"],
        "physics_state_modified": True,
        "native_runtime_observation_collection_executed": True,
        "stance_continuation_commissioned": continue_through_stance,
        "physical_development_result_observed": physical_result,
        "controller_physical_viability_proven": (
            physical_result and behavior_claim_authority
        ),
        "prone_to_standing_claimed": physical_result and behavior_claim_authority,
        "repeatability_rate_claimed": False,
        "population_claimed": False,
        "cross_engine_recovery_claimed": False,
        "cross_engine_equivalence_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    """Check the exact production dependencies without constructing a model."""

    capability = mujoco_recovery_capability_v1()
    initialized = core.recovery_initialize_v1(
        _physical_initialization_request("candidate_command", capability)
    )
    _require(
        initialized.get("support_status") == "supported_exact"
        and initialized.get("physical_threshold_authority") is True
        and initialized.get("physical_question_opened") is False,
        "QSDK_R24D18_PHYSICAL_PROFILE_PREFLIGHT",
    )
    route = compile_public_profile_model_route(
        core,
        descriptor=base.s169_descriptor(),
    )
    required_data_fields = (
        "subtree_com",
        "subtree_linvel",
        "actuator_force",
        "actuator_velocity",
        "qfrc_actuator",
        "qfrc_constraint",
        "qfrc_damper",
        "qfrc_fluid",
        "qfrc_adhesion",
        "energy",
        "qpos",
        "qvel",
        "contact",
    )
    missing_data_fields = [
        field for field in required_data_fields if field not in dir(mujoco.MjData)
    ]
    required_functions = (
        "mj_step1",
        "mj_step2",
        "mj_contactForce",
        "mj_geomDistance",
        "mj_subtreeVel",
        "mj_energyPos",
        "mj_energyVel",
    )
    missing_functions = [
        name for name in required_functions if not callable(getattr(mujoco, name, None))
    ]
    constructor_callable = callable(getattr(mujoco.MjModel, "from_xml_string", None))
    step_callable = callable(getattr(MujocoNativeRecoveryWorld, "step_native", None))
    finalize_callable = callable(getattr(core, "recovery_evaluate_trace_v1", None))
    energy_work_measurement_callable = callable(measure_native_energy_work_v2)
    _require(not missing_data_fields, "QSDK_R24D18_MJDATA_API_MISSING")
    _require(not missing_functions, "QSDK_R24D18_MUJOCO_FUNCTION_MISSING")
    _require(constructor_callable, "QSDK_R24D18_MODEL_CONSTRUCTOR_MISSING")
    _require(step_callable, "QSDK_R24D18_PRODUCTION_STEP_MISSING")
    _require(finalize_callable, "QSDK_R24D18_PRODUCTION_FINALIZE_MISSING")
    _require(
        energy_work_measurement_callable,
        "QSDK_R24D31_ENERGY_WORK_MEASUREMENT_MISSING",
    )
    return {
        "schema_version": "sporespore_mujoco_native_recovery_zero_world_preflight_v1",
        "ok": True,
        "route_id": ROUTE_ID,
        "question_class": "non_physical_source_conformance",
        "engine": ENGINE_ID,
        "engine_version": str(mujoco.__version__),
        "threshold_profile_id": PHYSICAL_THRESHOLD_PROFILE_ID,
        "runtime_qualification_sha256": R24D17_RUNTIME_QUALIFICATION_SHA256,
        "energy_ledger_profile_id": ENERGY_LEDGER_PROFILE_ID,
        "model_xml_sha256": route.model_xml_sha256,
        "model_xml_byte_length": len(route.model_xml_bytes),
        "required_mjdata_field_count": len(required_data_fields),
        "required_function_count": len(required_functions),
        "missing_mjdata_fields": missing_data_fields,
        "missing_functions": missing_functions,
        "paired_arm_count": 2,
        "production_constructor_callable": constructor_callable,
        "production_step_callable": step_callable,
        "production_finalize_callable": finalize_callable,
        "energy_work_measurement_callable": energy_work_measurement_callable,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "native_runtime_observation_collection_executed": False,
        "physical_question_opened": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def run_implicit_step_energy_zero_world_preflight(
    core: LocomotionCore,
) -> dict[str, Any]:
    """Check the v3 production seam without constructing ``MjModel`` or ``MjData``."""

    receipt = run_zero_world_preflight(core)
    required_data_fields = (
        "actuator_moment",
        "flg_rnepost",
    )
    required_model_fields = (
        "actuator_outadr",
        "actuator_outnum",
        "actuator_ctrladr",
        "actuator_ctrlnum",
        "actuator_ctrllimited",
    )
    required_functions = (
        "mj_fwdActuation",
        "mj_fwdAcceleration",
        "mj_fwdConstraint",
        "mj_sensorAcc",
        "mj_checkAcc",
        "mj_compareFwdInv",
        "mj_implicit",
    )
    missing_data_fields = [
        name for name in required_data_fields if name not in dir(mujoco.MjData)
    ]
    missing_model_fields = [
        name for name in required_model_fields if name not in dir(mujoco.MjModel)
    ]
    missing_functions = [
        name for name in required_functions if not callable(getattr(mujoco, name, None))
    ]
    _require(not missing_data_fields, "QSDK_R24D34_MJDATA_API_MISSING")
    _require(not missing_model_fields, "QSDK_R24D34_MJMODEL_API_MISSING")
    _require(not missing_functions, "QSDK_R24D34_MUJOCO_FUNCTION_MISSING")
    _require(
        callable(advance_implicitfast_after_control_v3)
        and callable(MujocoImplicitStepRecoveryWorld.step_native),
        "QSDK_R24D34_PRODUCTION_ROUTE_MISSING",
    )
    receipt.update(
        {
            "schema_version": (
                "sporespore_mujoco_implicit_step_energy_zero_world_preflight_v1"
            ),
            "route_id": IMPLICIT_STEP_ROUTE_ID,
            "energy_ledger_profile_id": IMPLICIT_STEP_ENERGY_LEDGER_PROFILE_ID,
            "historical_v2_energy_ledger_profile_id": ENERGY_LEDGER_PROFILE_ID,
            "required_v3_mjdata_field_count": len(required_data_fields),
            "required_v3_mjmodel_field_count": len(required_model_fields),
            "required_v3_function_count": len(required_functions),
            "missing_v3_mjdata_fields": missing_data_fields,
            "missing_v3_mjmodel_fields": missing_model_fields,
            "missing_v3_functions": missing_functions,
            "preintegration_snapshot_callable": True,
            "historical_v2_retained": True,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
        }
    )
    return receipt


def run_sparse_actuator_moment_zero_world_preflight(
    core: LocomotionCore,
) -> dict[str, Any]:
    """Bind the R35 sparse representation seam without constructing a world."""

    receipt = run_implicit_step_energy_zero_world_preflight(core)
    required_data_fields = (
        "actuator_moment",
        "moment_rownnz",
        "moment_rowadr",
        "moment_colind",
    )
    required_model_fields = ("nout", "nv", "nJmom")
    missing_data_fields = [
        name for name in required_data_fields if name not in dir(mujoco.MjData)
    ]
    missing_model_fields = [
        name for name in required_model_fields if name not in dir(mujoco.MjModel)
    ]
    missing_functions = [
        name
        for name in ("mju_sparse2dense",)
        if not callable(getattr(mujoco, name, None))
    ]
    _require(not missing_data_fields, "QSDK_R24D35_MJDATA_API_MISSING")
    _require(not missing_model_fields, "QSDK_R24D35_MJMODEL_API_MISSING")
    _require(not missing_functions, "QSDK_R24D35_MUJOCO_FUNCTION_MISSING")
    _require(
        callable(expand_sparse_actuator_moment_v1)
        and callable(MujocoSparseMomentImplicitStepRecoveryWorld.step_native),
        "QSDK_R24D35_PRODUCTION_ROUTE_MISSING",
    )
    receipt.update(
        {
            "schema_version": (
                "sporespore_mujoco_sparse_actuator_moment_zero_world_preflight_v1"
            ),
            "route_id": SPARSE_MOMENT_IMPLICIT_STEP_ROUTE_ID,
            "native_step_receipt_schema": (
                SPARSE_MOMENT_IMPLICIT_STEP_NATIVE_RECEIPT_SCHEMA
            ),
            "implicit_substep_receipt_schema": (
                SPARSE_MOMENT_IMPLICIT_SUBSTEP_RECEIPT_SCHEMA
            ),
            "actuator_moment_expansion_profile_id": (SPARSE_ACTUATOR_MOMENT_PROFILE_ID),
            "required_sparse_mjdata_field_count": len(required_data_fields),
            "required_sparse_mjmodel_field_count": len(required_model_fields),
            "required_sparse_function_count": 1,
            "missing_sparse_mjdata_fields": missing_data_fields,
            "missing_sparse_mjmodel_fields": missing_model_fields,
            "missing_sparse_functions": missing_functions,
            "sparse_expansion_callable": True,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
        }
    )
    return receipt


def run_signed_work_preprojection_zero_world_preflight(
    core: LocomotionCore,
) -> dict[str, Any]:
    """Bind the R36 typed projection/refusal seam without constructing a world."""

    receipt = run_sparse_actuator_moment_zero_world_preflight(core)
    controls, details = energy_work_projection_zero_world_controls_v1()
    _require(
        len(controls) == sum(controls.values()),
        "QSDK_R24D36_ENERGY_WORK_PREPROJECTION_CONTROL_FAILED",
    )
    _require(
        callable(MujocoSignedWorkPreprojectionRecoveryWorld.step_native),
        "QSDK_R24D36_PRODUCTION_ROUTE_MISSING",
    )
    receipt.update(
        {
            "schema_version": (
                "sporespore_mujoco_signed_work_preprojection_zero_world_preflight_v1"
            ),
            "route_id": SIGNED_WORK_PREPROJECTION_ROUTE_ID,
            "native_step_receipt_schema": (
                SIGNED_WORK_PREPROJECTION_NATIVE_RECEIPT_SCHEMA
            ),
            "implicit_substep_receipt_schema": (
                SIGNED_WORK_PREPROJECTION_SUBSTEP_RECEIPT_SCHEMA
            ),
            "energy_work_preprojection_profile_id": (
                ENERGY_WORK_PREPROJECTION_PROFILE_ID
            ),
            "energy_work_preprojection_controls": controls,
            "energy_work_preprojection_control_details": details,
            "typed_preprojection_refusal_callable": True,
            "portable_v1_signed_constraint_channel_present": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "behavior_question_opened": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
    )
    return receipt
