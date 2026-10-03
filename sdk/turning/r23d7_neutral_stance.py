"""Zero-world neutral-stance oracle and preregistration audit for QSDK-R23D7.

R23D7 is a prospective successor to the immutable R23D6 finite negative.  This
module deliberately constructs no physics model.  It validates the exact
morphology-neutral target equation against the portable compiler boundary and
discriminates the preregistered mutations before any worker may open a world.
"""

from __future__ import annotations

import copy
import hashlib
import json
import math
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parent
SDK_ROOT = ROOT.parent
REPO_ROOT = SDK_ROOT.parent
CONTRACT_PATH = ROOT / "r23d7_neutral_stance_preregistration_v1.json"
R23D6_CLOSURE_PATH = ROOT / "r23d6_physical_closure_v1.json"

SCHEMA_VERSION = "sporespore_qsdk_r23d7_neutral_stance_preregistration_v1"
CAMPAIGN_ID = "QSDK-R23D7-NEUTRAL-STANCE-ACQUISITION-BILATERAL-TURN-DEVELOPMENT"
GATE_ID = "QSDK-R23D7"
POLICY_ID = "sporespore_morphology_neutral_stance_bounded_pd_v1"
TARGET_POSITION_RAD = 0.0
POSITION_GAIN_PER_S = 8.0
RATE_DAMPING = 0.65
MAXIMUM_SPEED_RAD_S = 0.35
ACTUATOR_COUNT = 8
TOLERANCE = 1.0e-12
EXPECTED_R23D6_CLOSURE_SHA256 = (
    "sha256:8d3c1f2e916dc51fe44a3c549e26742f8b077e22f37fdba47191d8007a4c5dfd"
)


class R23D7Error(RuntimeError):
    """The prospective R23D7 design or a zero-world projection is invalid."""


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _close(left: Any, right: Any, tolerance: float = TOLERANCE) -> bool:
    return _finite(left) and _finite(right) and math.isclose(
        float(left), float(right), rel_tol=0.0, abs_tol=tolerance
    )


def bounded_neutral_velocity(
    measured_position_rad: float,
    measured_velocity_rad_s: float,
    *,
    target_position_rad: float = TARGET_POSITION_RAD,
    position_gain_per_s: float = POSITION_GAIN_PER_S,
    rate_damping: float = RATE_DAMPING,
    maximum_speed_rad_s: float = MAXIMUM_SPEED_RAD_S,
) -> dict[str, float]:
    """Evaluate the exact preregistered portable neutral-stance equation."""

    values = (
        measured_position_rad,
        measured_velocity_rad_s,
        target_position_rad,
        position_gain_per_s,
        rate_damping,
        maximum_speed_rad_s,
    )
    if not all(_finite(value) for value in values):
        raise R23D7Error("R23D7_NEUTRAL_NONFINITE")
    if position_gain_per_s <= 0.0 or rate_damping < 0.0 or maximum_speed_rad_s <= 0.0:
        raise R23D7Error("R23D7_NEUTRAL_PARAMETER_RANGE")
    position_error = float(target_position_rad) - float(measured_position_rad)
    unbounded = (
        float(position_gain_per_s) * position_error
        - float(rate_damping) * float(measured_velocity_rad_s)
    )
    bounded = max(-float(maximum_speed_rad_s), min(float(maximum_speed_rad_s), unbounded))
    return {
        "target_position_rad": float(target_position_rad),
        "measured_position_rad": float(measured_position_rad),
        "measured_velocity_rad_s": float(measured_velocity_rad_s),
        "position_error_rad": position_error,
        "unbounded_velocity_rad_s": unbounded,
        "bounded_velocity_rad_s": bounded,
    }


def compose_neutral_stance(
    ordered_actuators: list[dict[str, Any]],
    ordered_joint_observations: list[dict[str, Any]],
) -> dict[str, Any]:
    """Compose all eight ordered targets without starting an engine adapter."""

    if len(ordered_actuators) != ACTUATOR_COUNT:
        raise R23D7Error("R23D7_NEUTRAL_ACTUATOR_COUNT")
    actuator_ids = [item.get("actuator_id") for item in ordered_actuators]
    joint_ids = [item.get("joint_id") for item in ordered_actuators]
    if any(not isinstance(value, str) or not value for value in actuator_ids + joint_ids):
        raise R23D7Error("R23D7_NEUTRAL_ACTUATOR_IDENTITY")
    if len(set(actuator_ids)) != ACTUATOR_COUNT or len(set(joint_ids)) != ACTUATOR_COUNT:
        raise R23D7Error("R23D7_NEUTRAL_ACTUATOR_UNIQUENESS")
    observation_by_joint = {
        item.get("joint_id"): item for item in ordered_joint_observations
    }
    if list(observation_by_joint) != joint_ids:
        raise R23D7Error("R23D7_NEUTRAL_OBSERVATION_ORDER")

    solutions: list[dict[str, Any]] = []
    for actuator in ordered_actuators:
        lower = actuator.get("minimum_target_position_rad")
        upper = actuator.get("maximum_target_position_rad")
        if (
            not _finite(lower)
            or not _finite(upper)
            or float(lower) > TARGET_POSITION_RAD
            or float(upper) < TARGET_POSITION_RAD
        ):
            raise R23D7Error(
                f"R23D7_NEUTRAL_TARGET_OUTSIDE_LIMIT:{actuator['actuator_id']}"
            )
        observation = observation_by_joint[actuator["joint_id"]]
        solution = bounded_neutral_velocity(
            observation.get("position_rad"), observation.get("velocity_rad_s")
        )
        solutions.append(
            {
                "actuator_id": actuator["actuator_id"],
                "joint_id": actuator["joint_id"],
                "minimum_target_position_rad": float(lower),
                "maximum_target_position_rad": float(upper),
                **solution,
            }
        )
    return {
        "schema_version": "sporespore_morphology_neutral_stance_bounded_pd_receipt_v1",
        "policy_id": POLICY_ID,
        "target_source": "morphology_joint_coordinate_neutral_zero_v1",
        "position_gain_per_s": POSITION_GAIN_PER_S,
        "measured_rate_damping": RATE_DAMPING,
        "maximum_absolute_joint_velocity_rad_s": MAXIMUM_SPEED_RAD_S,
        "neutral_target_activation_count": len(solutions),
        "ordered_actuator_solutions": solutions,
        "physics_state_modified": False,
        "command_not_measurement": True,
        "physical_acceptance_authority": False,
    }


def receipt_failures(
    receipt: dict[str, Any], expected_actuator_ids: list[str]
) -> list[str]:
    failures: list[str] = []
    solutions = receipt.get("ordered_actuator_solutions")
    if receipt.get("schema_version") != "sporespore_morphology_neutral_stance_bounded_pd_receipt_v1":
        failures.append("schema_version")
    if receipt.get("policy_id") != POLICY_ID:
        failures.append("policy_id")
    if receipt.get("target_source") != "morphology_joint_coordinate_neutral_zero_v1":
        failures.append("target_source")
    if not isinstance(solutions, list) or len(solutions) != ACTUATOR_COUNT:
        failures.append("solution_count")
        return failures
    if [item.get("actuator_id") for item in solutions] != expected_actuator_ids:
        failures.append("actuator_order")
    if receipt.get("neutral_target_activation_count") != ACTUATOR_COUNT:
        failures.append("activation_count")
    for solution in solutions:
        actuator_id = str(solution.get("actuator_id", "unknown"))
        if not _close(solution.get("target_position_rad"), TARGET_POSITION_RAD):
            failures.append(f"target:{actuator_id}")
            continue
        expected = bounded_neutral_velocity(
            solution.get("measured_position_rad"),
            solution.get("measured_velocity_rad_s"),
        )
        for field in (
            "position_error_rad",
            "unbounded_velocity_rad_s",
            "bounded_velocity_rad_s",
        ):
            if not _close(solution.get(field), expected[field]):
                failures.append(f"{field}:{actuator_id}")
        bounded = solution.get("bounded_velocity_rad_s")
        if not _finite(bounded) or abs(float(bounded)) > MAXIMUM_SPEED_RAD_S + TOLERANCE:
            failures.append(f"speed_bound:{actuator_id}")
    if receipt.get("physics_state_modified") is not False:
        failures.append("physics_state_modified")
    if receipt.get("physical_acceptance_authority") is not False:
        failures.append("physical_acceptance_authority")
    return failures


def _load_and_validate_contract() -> dict[str, Any]:
    try:
        contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
        closure = json.loads(R23D6_CLOSURE_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D7Error(f"R23D7_DECLARATION_UNREADABLE:{type(error).__name__}") from error
    lineage = contract.get("lineage", {})
    inherited = contract.get("inherited_unchanged_scientific_contract", {})
    schedule = contract.get("frozen_schedule_and_gate_snapshot", {})
    policy = contract.get("neutral_stance_policy_contract", {})
    authorization = contract.get("authorization", {})
    claims = contract.get("claim_boundary", {})
    invalid = (
        contract.get("schema_version") != SCHEMA_VERSION
        or contract.get("campaign_id") != CAMPAIGN_ID
        or contract.get("gate_id") != GATE_ID
        or contract.get("status")
        != "stage_zero_preregistered_neutral_stance_successor_no_workers_no_physical_authorization"
        or lineage.get("predecessor_status") != closure.get("status")
        or lineage.get("predecessor_closure_raw_sha256") != EXPECTED_R23D6_CLOSURE_SHA256
        or _raw_sha256(R23D6_CLOSURE_PATH) != EXPECTED_R23D6_CLOSURE_SHA256
        or lineage.get("predecessor_same_identity_rerun_allowed") is not False
        or lineage.get("predecessor_scientific_negative") is not True
        or inherited.get("outcome_numeric_thresholds_changed") is not False
        or inherited.get("stage_a_selector_changed") is not False
        or inherited.get("only_scientific_policy_change")
        != "terminal_stance_acquisition_and_hold_mechanism"
        or schedule.get("turning_controller_semantic_step_count") != 2992
        or schedule.get("terminal_stance_step_count") != 540
        or schedule.get("maximum_four_contact_acquisition_steps") != 180
        or schedule.get("required_consecutive_all_four_contact_hold_steps") != 360
        or schedule.get("passive_settle_step_count") != 240
        or schedule.get("total_traced_step_count") != 3772
        or schedule.get("exact_active_native_application_count") != 28256
        or policy.get("policy_id") != POLICY_ID
        or not _close(policy.get("target_position_rad_for_every_ordered_actuator"), 0.0)
        or not _close(policy.get("position_gain_per_s"), POSITION_GAIN_PER_S)
        or not _close(policy.get("measured_rate_damping"), RATE_DAMPING)
        or not _close(policy.get("maximum_absolute_joint_velocity_rad_s"), MAXIMUM_SPEED_RAD_S)
        or policy.get("activation_is_atomic_for_all_eight_actuators") is not True
        or policy.get("dynamic_pose_capture") is not False
        or authorization.get("physical_execution_authorized") is not False
        or authorization.get("worker_implementation_authorized") is not True
        or claims.get("stage_zero_design_complete") is not True
        or claims.get("command_conditioned_turning") is not False
        or claims.get("physical_acceptance_authority") is not False
    )
    if invalid:
        raise R23D7Error("R23D7_DECLARATION_INVALID")
    return contract


def _compile_exact_s169() -> tuple[list[dict[str, Any]], dict[str, Any]]:
    import sys

    mujoco_adapter_root = SDK_ROOT / "adapters" / "mujoco"
    python_root = SDK_ROOT / "python"
    for path in (mujoco_adapter_root, python_root):
        if str(path) not in sys.path:
            sys.path.insert(0, str(path))
    from sporespore_locomotion import LocomotionCore
    from sporespore_mujoco_adapter import selected_policy_development as bridge

    core = LocomotionCore()
    compiled = core.compile_bounded_quadruped(bridge.s169_descriptor())
    morphology = compiled["morphology"]
    spec_by_id = {
        item["actuator_id"]: item for item in morphology["morphology_spec"]["actuators"]
    }
    ordered = [
        {
            "actuator_id": actuator_id,
            "joint_id": spec_by_id[actuator_id]["joint_id"],
            "minimum_target_position_rad": spec_by_id[actuator_id][
                "minimum_target_position_rad"
            ],
            "maximum_target_position_rad": spec_by_id[actuator_id][
                "maximum_target_position_rad"
            ],
        }
        for actuator_id in morphology["ordered_actuator_ids"]
    ]
    return ordered, compiled


def _mutation_receipts(
    receipt: dict[str, Any], expected_ids: list[str]
) -> dict[str, dict[str, Any]]:
    mutations: dict[str, dict[str, Any]] = {}

    def mutate(name: str, action: Callable[[dict[str, Any]], None]) -> None:
        value = copy.deepcopy(receipt)
        action(value)
        mutations[name] = value

    mutate(
        "reversed_position_error_sign",
        lambda value: value["ordered_actuator_solutions"][0].__setitem__(
            "position_error_rad", -value["ordered_actuator_solutions"][0]["position_error_rad"]
        ),
    )
    mutate(
        "omitted_measured_rate_damping",
        lambda value: value["ordered_actuator_solutions"][1].__setitem__(
            "unbounded_velocity_rad_s",
            POSITION_GAIN_PER_S * value["ordered_actuator_solutions"][1]["position_error_rad"],
        ),
    )
    mutate(
        "reversed_measured_rate_damping_sign",
        lambda value: value["ordered_actuator_solutions"][2].__setitem__(
            "bounded_velocity_rad_s",
            -value["ordered_actuator_solutions"][2]["bounded_velocity_rad_s"],
        ),
    )
    mutate(
        "used_current_position_as_target",
        lambda value: value["ordered_actuator_solutions"][3].__setitem__(
            "target_position_rad",
            value["ordered_actuator_solutions"][3]["measured_position_rad"],
        ),
    )
    mutate(
        "used_joint_limit_midpoint_as_target",
        lambda value: value["ordered_actuator_solutions"][1].__setitem__(
            "target_position_rad",
            0.5
            * (
                value["ordered_actuator_solutions"][1]["minimum_target_position_rad"]
                + value["ordered_actuator_solutions"][1]["maximum_target_position_rad"]
            ),
        ),
    )
    mutate(
        "skipped_velocity_clamp",
        lambda value: value["ordered_actuator_solutions"][0].__setitem__(
            "bounded_velocity_rad_s",
            value["ordered_actuator_solutions"][0]["unbounded_velocity_rad_s"],
        ),
    )
    mutate(
        "activated_only_the_missing_limb",
        lambda value: (
            value.__setitem__("ordered_actuator_solutions", value["ordered_actuator_solutions"][:2]),
            value.__setitem__("neutral_target_activation_count", 2),
        ),
    )
    mutate(
        "omitted_one_actuator",
        lambda value: value["ordered_actuator_solutions"].pop(),
    )
    mutate(
        "reordered_actuators",
        lambda value: value["ordered_actuator_solutions"].reverse(),
    )
    mutate(
        "accepted_nonzero_neutral_target",
        lambda value: value["ordered_actuator_solutions"][0].__setitem__(
            "target_position_rad", 0.01
        ),
    )
    if set(mutations) != set(_load_and_validate_contract()["required_mutation_controls"]):
        raise R23D7Error("R23D7_MUTATION_SET")
    for mutation_id, value in mutations.items():
        if not receipt_failures(value, expected_ids):
            raise R23D7Error(f"R23D7_MUTATION_SURVIVED:{mutation_id}")
    return mutations


def run_zero_world_preflight() -> dict[str, Any]:
    """Validate the declaration, compiler boundary, oracle, and mutations."""

    contract = _load_and_validate_contract()
    actuators, compiled = _compile_exact_s169()
    if len(actuators) != ACTUATOR_COUNT:
        raise R23D7Error("R23D7_COMPILED_ACTUATOR_COUNT")
    canaries = contract.get("independent_oracle_canaries", [])
    if len(canaries) != 5:
        raise R23D7Error("R23D7_CANARY_COUNT")
    canary_results: list[dict[str, Any]] = []
    for canary in canaries:
        observed = bounded_neutral_velocity(
            canary.get("measured_position_rad"), canary.get("measured_velocity_rad_s")
        )
        if not _close(
            observed["unbounded_velocity_rad_s"],
            canary.get("expected_unbounded_velocity_rad_s"),
        ) or not _close(
            observed["bounded_velocity_rad_s"],
            canary.get("expected_bounded_velocity_rad_s"),
        ):
            raise R23D7Error(f"R23D7_CANARY:{canary.get('canary_id')}")
        canary_results.append({"canary_id": canary["canary_id"], **observed})

    observations = [
        {
            "joint_id": actuator["joint_id"],
            "position_rad": canaries[index % len(canaries)]["measured_position_rad"],
            "velocity_rad_s": canaries[index % len(canaries)]["measured_velocity_rad_s"],
        }
        for index, actuator in enumerate(actuators)
    ]
    receipt = compose_neutral_stance(actuators, observations)
    expected_ids = [item["actuator_id"] for item in actuators]
    failures = receipt_failures(receipt, expected_ids)
    if failures:
        raise R23D7Error("R23D7_RECEIPT:" + ",".join(failures))
    mutations = _mutation_receipts(receipt, expected_ids)
    return {
        "schema_version": "sporespore_qsdk_r23d7_neutral_stance_zero_world_preflight_v1",
        "ok": True,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "contract_raw_sha256": _raw_sha256(CONTRACT_PATH),
        "r23d6_closure_raw_sha256": _raw_sha256(R23D6_CLOSURE_PATH),
        "compiled_morphology_id": compiled["descriptor"]["morphology_id"],
        "ordered_actuator_ids": expected_ids,
        "neutral_target_inside_all_joint_limits": True,
        "canary_count": len(canary_results),
        "mutation_control_count": len(mutations),
        "neutral_target_activation_count": receipt["neutral_target_activation_count"],
        "physics_adapter_start_count": 0,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }


if __name__ == "__main__":
    print(json.dumps(run_zero_world_preflight(), allow_nan=False, sort_keys=True))
