"""Compact zero-world qualification for recovery-aware portable requests."""

from __future__ import annotations

from copy import deepcopy
import math
from types import SimpleNamespace
from typing import Any

import numpy as np

from sporespore_locomotion import LocomotionCore, LocomotionCoreError

from . import selected_policy_development as base
from .native_recovery_development import (
    CONTACT_CLASSIFICATION_TOLERANCE_M,
    MujocoNativeRecoveryWorld,
    NativeRecoveryRouteError,
    _physical_initialization_request,
    _physical_initialization_request_v2,
    _portable_morphology_context,
)
from .recovery_morphology_route import (
    MujocoRecoveryMorphologyWorld,
    compile_recovery_morphology_model_route,
    run_zero_world_preflight as run_inherited_zero_world_preflight,
)
from .recovery_capability import mujoco_recovery_capability_v1


PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r24d24_recovery_context_contact_observer_preflight_v1"
)
RECOVERY_CONTEXT_SCHEMA = "sporespore_recovery_morphology_context_v1"
V2_METHODS = (
    "recovery_initialize_v2",
    "recovery_step_v2",
    "recovery_evaluate_trace_v2",
    "recovery_collect_native_v2",
    "recovery_plan_control_v2",
)
SHA_A = "sha256:" + ("a" * 64)


class RecoveryContextQualificationError(RuntimeError):
    """Stable fail-closed qualification error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise RecoveryContextQualificationError(code)


def _exact(actual: object, expected: object, code: str) -> None:
    _require(actual == expected, f"{code}:expected={expected!r}:actual={actual!r}")


def _v2_dispatch_controls(core: LocomotionCore) -> dict[str, bool]:
    controls: dict[str, bool] = {}
    for method_name in V2_METHODS:
        rejected = False
        try:
            getattr(core, method_name)({})
        except LocomotionCoreError as error:
            rejected = error.failure_code == "SCHEMA_INVALID"
        _require(rejected, f"V2_MALFORMED_DISPATCH_ACCEPTED:{method_name}")
        controls[method_name] = True
    return controls


def _limit_comparison(core: LocomotionCore, route: Any) -> dict[str, Any]:
    context = _portable_morphology_context(route)
    _require(context is not None, "RECOVERY_CONTEXT_MISSING")
    assert context is not None
    recovery = context["recovery_descriptor"]
    pose = recovery["canonical_prone_pose"]
    authority = recovery["joint_authority"]
    recovery_positions = {
        "front_hip": abs(float(pose["front_hip_angle_rad"])),
        "rear_hip": abs(float(pose["rear_hip_angle_rad"])),
        "front_knee": abs(float(pose["front_knee_angle_rad"])),
        "rear_knee": abs(float(pose["rear_knee_angle_rad"])),
    }
    recovery_limits = {
        "front_hip": float(authority["hip_limit_magnitude_rad"]),
        "rear_hip": float(authority["hip_limit_magnitude_rad"]),
        "front_knee": float(authority["knee_limit_magnitude_rad"]),
        "rear_knee": float(authority["knee_limit_magnitude_rad"]),
    }
    base_compiled = core.compile_bounded_quadruped(base.s169_descriptor())
    base_limits: dict[str, float] = {}
    for joint in base_compiled["morphology"]["morphology_spec"]["joints"]:
        joint_id = str(joint["joint_id"])
        key = joint_id.replace("_left_", "_").replace("_right_", "_")
        _require(key in recovery_positions, f"LEGACY_JOINT_ID:{joint_id}")
        if key not in base_limits:
            base_limits[key] = max(
                abs(float(joint["lower_limit_rad"])),
                abs(float(joint["upper_limit_rad"])),
            )
    base_respected = all(
        recovery_positions[key] <= base_limits[key] for key in recovery_positions
    )
    recovery_respected = all(
        recovery_positions[key] <= recovery_limits[key]
        for key in recovery_positions
    )
    _exact(base_respected, False, "LEGACY_LIMIT_COMPARISON")
    _exact(recovery_respected, True, "RECOVERY_LIMIT_COMPARISON")
    return {
        "comparison_source": "content_addressed_compiled_receipts_zero_world",
        "recovery_pose_absolute_rad": recovery_positions,
        "legacy_limit_magnitude_rad": base_limits,
        "recovery_limit_magnitude_rad": recovery_limits,
        "legacy_limits_respected": base_respected,
        "recovery_limits_respected": recovery_respected,
    }


def _observer_controls(route: Any) -> dict[str, Any]:
    world = object.__new__(MujocoNativeRecoveryWorld)
    world.compiled = route.compiled
    world._body_local_canonical = lambda _body, point: np.asarray(
        point,
        dtype=np.float64,
    )
    half_height = float(route.compiled["geometry"]["torso_size_m"]["y"]) / 2.0
    midpoint_y = -half_height + 0.005
    contact = SimpleNamespace(
        pos=np.asarray([0.0, midpoint_y, 0.0], dtype=np.float64),
        frame=np.asarray(
            [[0.0, 1.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 1.0]],
            dtype=np.float64,
        ),
        dist=-0.010,
        geom1=10,
        geom2=20,
    )
    torso_surface = world._contact_surface_point_for_body_geom(contact, 20)
    reverse = SimpleNamespace(
        pos=contact.pos,
        frame=np.asarray(
            [[0.0, -1.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, -1.0]],
            dtype=np.float64,
        ),
        dist=contact.dist,
        geom1=20,
        geom2=10,
    )
    boundary = -half_height + CONTACT_CLASSIFICATION_TOLERANCE_M
    nonfinite_rejected = False
    invalid = SimpleNamespace(**vars(contact))
    invalid.dist = math.nan
    try:
        world._contact_surface_point_for_body_geom(invalid, 20)
    except NativeRecoveryRouteError as error:
        nonfinite_rejected = str(error) == "QSDK_R24_NATIVE_CONTACT_GEOMETRY_NONFINITE"
    identity_rejected = False
    try:
        world._contact_surface_point_for_body_geom(contact, 30)
    except NativeRecoveryRouteError as error:
        identity_rejected = str(error) == "QSDK_R24_NATIVE_CONTACT_GEOM_IDENTITY"
    checks = {
        "legacy_midpoint_rejected": not world._is_torso_ventral_contact(contact.pos),
        "reconstructed_named_surface_accepted": world._is_torso_ventral_contact(
            torso_surface
        ),
        "geom_order_invariant": bool(
            np.array_equal(
                world._contact_surface_point_for_body_geom(reverse, 20),
                torso_surface,
            )
        ),
        "inherited_boundary_accepted": world._is_torso_ventral_contact(
            np.asarray([0.0, boundary, 0.0], dtype=np.float64)
        ),
        "adjacent_outside_rejected": not world._is_torso_ventral_contact(
            np.asarray(
                [0.0, math.nextafter(boundary, math.inf), 0.0],
                dtype=np.float64,
            )
        ),
        "nonfinite_contact_rejected": nonfinite_rejected,
        "unrelated_geom_identity_rejected": identity_rejected,
    }
    _require(all(checks.values()), "CONTACT_OBSERVER_CONTROL_FAILED")
    return {
        "rule_id": MujocoRecoveryMorphologyWorld.nonfoot_classification_rule_id,
        "legacy_rule_id": MujocoNativeRecoveryWorld.nonfoot_classification_rule_id,
        "midpoint_semantics": "midpoint_between_geoms",
        "normal_semantics": "contact_frame_normal_geom0_to_geom1",
        "signed_distance_semantics": "nearest_point_distance_negative_on_penetration",
        "reconstruction_rule": "geom0=pos-dist*normal/2;geom1=pos+dist*normal/2",
        "new_empirical_threshold_count": 0,
        "new_margin_count": 0,
        "inherited_classification_tolerance_m": CONTACT_CLASSIFICATION_TOLERANCE_M,
        "checks": checks,
        "control_count": len(checks),
        "controls_passed": sum(checks.values()),
    }


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    """Qualify the R24D24 boundary without constructing MuJoCo state."""

    inherited = run_inherited_zero_world_preflight(core)
    route = compile_recovery_morphology_model_route(core)
    context = _portable_morphology_context(route)
    _require(context is not None, "RECOVERY_CONTEXT_MISSING")
    assert context is not None
    _exact(context["schema_version"], RECOVERY_CONTEXT_SCHEMA, "CONTEXT_SCHEMA")
    capability = mujoco_recovery_capability_v1()

    legacy_request = _physical_initialization_request(
        "candidate_command",
        capability,
    )
    _require("morphology_context" not in legacy_request, "V1_CONTEXT_FIELD_PRESENT")
    _exact(
        core.recovery_initialize_v1(legacy_request)["support_status"],
        "supported_exact",
        "V1_INITIALIZE",
    )
    malformed_v1 = deepcopy(legacy_request)
    malformed_v1["morphology_context"] = deepcopy(context)
    v1_unknown_field_rejected = False
    try:
        core.recovery_initialize_v1(malformed_v1)
    except LocomotionCoreError as error:
        v1_unknown_field_rejected = error.failure_code == "SCHEMA_INVALID"
    _require(v1_unknown_field_rejected, "V1_CONTEXT_FIELD_ACCEPTED")

    initialize_v2 = _physical_initialization_request_v2(
        "candidate_command",
        capability,
        context,
    )
    initialized = core.recovery_initialize_v2(initialize_v2)
    _exact(initialized["support_status"], "supported_exact", "V2_INITIALIZE")
    _exact(
        initialized["morphology_spec_sha256"],
        context["recovery_morphology_spec_sha256"],
        "V2_MORPHOLOGY",
    )
    mutated = deepcopy(initialize_v2)
    mutated["morphology_context"]["recovery_morphology_spec_sha256"] = SHA_A
    context_mutation_rejected = False
    try:
        core.recovery_initialize_v2(mutated)
    except LocomotionCoreError as error:
        context_mutation_rejected = error.failure_code == "IDENTITY_INVALID"
    _require(context_mutation_rejected, "V2_CONTEXT_MUTATION_ACCEPTED")

    dispatch = _v2_dispatch_controls(core)
    limits = _limit_comparison(core, route)
    observer = _observer_controls(route)
    negative_count = 4 + 1 + 1 + len(dispatch) + observer["control_count"]
    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "ok": True,
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": ["mujoco_native"],
            "authority_mode": "zero_world_qualification",
            "question_class": "development",
        },
        "engine": "mujoco_native",
        "engine_version": inherited["engine_version"],
        "numpy_version": inherited["numpy_version"],
        "route_id": inherited["route_id"],
        "recovery_morphology_context": context,
        "v1_request_shape_unchanged": True,
        "v1_unknown_context_field_rejected": v1_unknown_field_rejected,
        "v2_context_mutation_rejected": context_mutation_rejected,
        "v2_initialize_supported": True,
        "v2_malformed_dispatch_controls": dispatch,
        "v2_public_entrypoint_count": len(dispatch),
        "limit_comparison": limits,
        "v1_recovery_pose_joint_limits_respected": limits[
            "legacy_limits_respected"
        ],
        "v2_recovery_pose_joint_limits_respected": limits[
            "recovery_limits_respected"
        ],
        "positive_v2_semantics_covered_by_core_recovery_suite": True,
        "contact_observer": observer,
        "negative_control_count": negative_count,
        "negative_controls_passed": negative_count,
        "inherited_r24d23_negative_control_count": 4,
        "model_construction_count": 0,
        "data_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "native_runtime_observation_collection_executed": False,
        "physical_question_opened": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
