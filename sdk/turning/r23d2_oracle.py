"""Independent zero-world oracle for the QSDK-R23D2 successor.

This module deliberately does not import the portable controller runtime.  It
recomputes the quantities that R23D1 incorrectly compared to the raw requested
heading.  Passing this module freezes a stronger test oracle; it does not
authorize a physics world or establish turning.
"""

from __future__ import annotations

import copy
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parent
CONTRACT_PATH = ROOT / "r23d2_oracle_preregistration.json"
PREDECESSOR_CONTRACT_PATH = ROOT / "physical_development_contract_v1.json"
PREDECESSOR_CLOSURE_PATH = ROOT / "physical_development_closure_v1.json"
SCHEMA_VERSION = "sporespore_qsdk_r23d2_oracle_preregistration_v1"
CAMPAIGN_ID = "QSDK-R23D2-THREE-ENGINE-HEADING-RESPONSE-DEVELOPMENT"
GATE_ID = "QSDK-R23D2"
RECEIPT_FIELDS = (
    "cross_track_error_m",
    "cross_track_velocity_m_s",
    "measured_yaw_error_rad",
    "desired_heading_error_rad",
    "yaw_tracking_error_rad",
)


class R23D2OracleError(RuntimeError):
    """The preregistration or an independently checked receipt is invalid."""


def _raw_sha256(path: Path) -> str:
    try:
        return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError as error:
        raise R23D2OracleError(
            f"R23D2_SOURCE_UNREADABLE:{path.name}:{type(error).__name__}"
        ) from error


def _finite_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _exact_keys(value: Any, keys: Iterable[str]) -> bool:
    return isinstance(value, dict) and set(value) == set(keys)


def _vector3(value: Any, field: str) -> tuple[float, float, float]:
    if (
        not isinstance(value, list)
        or len(value) != 3
        or any(not _finite_number(component) for component in value)
    ):
        raise R23D2OracleError(f"R23D2_{field.upper()}_INVALID")
    return tuple(float(component) for component in value)


def _dot(first: tuple[float, ...], second: tuple[float, ...]) -> float:
    return sum(left * right for left, right in zip(first, second, strict=True))


def wrap_angle(value: float) -> float:
    if not _finite_number(value):
        raise R23D2OracleError("R23D2_ANGLE_NONFINITE")
    return (float(value) + math.pi) % math.tau - math.pi


def load_contract() -> dict[str, Any]:
    try:
        contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise R23D2OracleError(
            f"R23D2_CONTRACT_UNREADABLE:{type(error).__name__}"
        ) from error
    profile = contract.get("selected_profile_oracle", {})
    expected_heading_gain = 1.0 / 1.0041015625
    expected_velocity_gain = 0.35 * math.sqrt(1.0041015625)
    if (
        contract.get("schema_version") != SCHEMA_VERSION
        or contract.get("status")
        != "stage_zero_oracle_preregistered_workers_not_frozen"
        or contract.get("campaign_id") != CAMPAIGN_ID
        or contract.get("gate_id") != GATE_ID
        or contract.get("release_gate_id") != "QSDK-R23"
        or contract.get("predecessor", {}).get("closure_sha256")
        != "sha256:022b42ae025abc3ee4eb502ee1857d5b43c1f6bc0e67b7e84c07bd6aa7076717"
        or _raw_sha256(PREDECESSOR_CLOSURE_PATH)
        != contract.get("predecessor", {}).get("closure_sha256")
        or _raw_sha256(PREDECESSOR_CONTRACT_PATH)
        != contract.get("predecessor", {}).get("source_contract_sha256")
        or contract.get("unchanged_question", {}).get("declared_cell_count") != 9
        or contract.get("unchanged_question", {}).get("engine_ids")
        != ["godot_jolt", "rapier_parry", "mujoco"]
        or contract.get("future_worker_requirements", {}).get(
            "actual_engine_worker_count"
        )
        != 0
        or contract.get("authorization", {}).get("physical_execution_authorized")
        is not False
        or contract.get("authorization", {}).get("world_build_count") != 0
        or contract.get("claim_boundary", {}).get("q_sdk_r23_satisfied") is not False
        or profile.get("required_receipt_predicates") != list(RECEIPT_FIELDS)
        or profile.get("raw_heading_offset_equality_is_forbidden_as_oracle") is not True
        or not math.isclose(
            float(profile.get("cross_track_heading_gain_rad_per_m", math.nan)),
            expected_heading_gain,
            rel_tol=0.0,
            abs_tol=1e-15,
        )
        or not math.isclose(
            float(
                profile.get("cross_track_velocity_heading_gain_rad_per_m_s", math.nan)
            ),
            expected_velocity_gain,
            rel_tol=0.0,
            abs_tol=1e-15,
        )
        or len(contract.get("oracle_canaries", [])) != 7
    ):
        raise R23D2OracleError("R23D2_CONTRACT_IDENTITY_INVALID")
    return contract


def recompute_oracle(
    state: dict[str, Any],
    command: dict[str, Any],
    profile: dict[str, Any],
) -> dict[str, float]:
    """Recompute the controller receipt without consuming receipt values."""

    required_state_keys = (
        "reference_yaw_rad",
        "measured_heading_world_rad",
        "task_origin_world_m",
        "task_lateral_axis_world_unit",
        "base_position_world_m",
        "base_linear_velocity_world_m_s",
    )
    if not _exact_keys(state, required_state_keys):
        raise R23D2OracleError("R23D2_STATE_KEYS_INVALID")
    if not _exact_keys(command, ("desired_heading_rad",)):
        raise R23D2OracleError("R23D2_COMMAND_KEYS_INVALID")
    for field in (
        "reference_yaw_rad",
        "measured_heading_world_rad",
    ):
        if not _finite_number(state[field]):
            raise R23D2OracleError(f"R23D2_{field.upper()}_INVALID")
    if not _finite_number(command["desired_heading_rad"]):
        raise R23D2OracleError("R23D2_DESIRED_HEADING_RAD_INVALID")

    origin = _vector3(state["task_origin_world_m"], "task_origin_world_m")
    lateral = _vector3(
        state["task_lateral_axis_world_unit"], "task_lateral_axis_world_unit"
    )
    position = _vector3(state["base_position_world_m"], "base_position_world_m")
    velocity = _vector3(
        state["base_linear_velocity_world_m_s"],
        "base_linear_velocity_world_m_s",
    )
    lateral_norm = math.sqrt(_dot(lateral, lateral))
    if not math.isclose(lateral_norm, 1.0, rel_tol=0.0, abs_tol=1e-12):
        raise R23D2OracleError("R23D2_TASK_LATERAL_AXIS_NOT_UNIT")

    gain_fields = (
        "cross_track_heading_gain_rad_per_m",
        "cross_track_velocity_heading_gain_rad_per_m_s",
        "maximum_desired_heading_error_rad",
    )
    if any(not _finite_number(profile.get(field)) for field in gain_fields):
        raise R23D2OracleError("R23D2_PROFILE_NONFINITE")
    maximum = float(profile["maximum_desired_heading_error_rad"])
    if maximum <= 0.0:
        raise R23D2OracleError("R23D2_PROFILE_MAXIMUM_INVALID")

    displacement = tuple(
        position_component - origin_component
        for position_component, origin_component in zip(position, origin, strict=True)
    )
    cross_track_error_m = _dot(displacement, lateral)
    cross_track_velocity_m_s = _dot(velocity, lateral)
    requested_heading_error_rad = wrap_angle(
        float(command["desired_heading_rad"]) - float(state["reference_yaw_rad"])
    )
    measured_yaw_error_rad = wrap_angle(
        float(state["measured_heading_world_rad"]) - float(state["reference_yaw_rad"])
    )
    unclamped_desired = (
        requested_heading_error_rad
        - float(profile["cross_track_heading_gain_rad_per_m"]) * cross_track_error_m
        - float(profile["cross_track_velocity_heading_gain_rad_per_m_s"])
        * cross_track_velocity_m_s
    )
    desired_heading_error_rad = max(-maximum, min(maximum, unclamped_desired))
    yaw_tracking_error_rad = wrap_angle(
        measured_yaw_error_rad - desired_heading_error_rad
    )
    return {
        "cross_track_error_m": cross_track_error_m,
        "cross_track_velocity_m_s": cross_track_velocity_m_s,
        "measured_yaw_error_rad": measured_yaw_error_rad,
        "desired_heading_error_rad": desired_heading_error_rad,
        "yaw_tracking_error_rad": yaw_tracking_error_rad,
    }


def canary_state(canary: dict[str, Any]) -> dict[str, Any]:
    return {
        "reference_yaw_rad": canary["reference_yaw_rad"],
        "measured_heading_world_rad": canary["measured_heading_world_rad"],
        "task_origin_world_m": copy.deepcopy(canary["task_origin_world_m"]),
        "task_lateral_axis_world_unit": copy.deepcopy(
            canary["task_lateral_axis_world_unit"]
        ),
        "base_position_world_m": copy.deepcopy(canary["base_position_world_m"]),
        "base_linear_velocity_world_m_s": copy.deepcopy(
            canary["base_linear_velocity_world_m_s"]
        ),
    }


def validate_receipt(
    receipt: dict[str, Any],
    state: dict[str, Any],
    command: dict[str, Any],
    profile: dict[str, Any],
) -> dict[str, Any]:
    expected = recompute_oracle(state, command, profile)
    tolerance = float(profile["comparison_absolute_tolerance"])
    failures: list[str] = []
    for field in RECEIPT_FIELDS:
        if not _finite_number(receipt.get(field)):
            failures.append(f"{field}:nonfinite_or_missing")
        elif not math.isclose(
            float(receipt[field]),
            expected[field],
            rel_tol=0.0,
            abs_tol=tolerance,
        ):
            failures.append(f"{field}:mismatch")
    return {
        "schema_version": "sporespore_qsdk_r23d2_oracle_evaluation_v1",
        "ok": not failures,
        "failed_predicates": failures,
        "expected_receipt": expected,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
    }


def validate_failure_provenance(
    stage_id: str,
    world_attempt_count: int,
    world_build_count: int,
    contract: dict[str, Any] | None = None,
) -> bool:
    contract = load_contract() if contract is None else contract
    if stage_id not in contract["failure_provenance"]["required_stage_ids"]:
        return False
    expected = {
        "before_world": (0, 0),
        "world_construction_failed": (1, 0),
        "world_constructed": (1, 1),
        "settlement_complete": (1, 1),
        "controller_validation_failed": (1, 1),
        "cell_report_complete": (1, 1),
    }
    return expected[stage_id] == (world_attempt_count, world_build_count)


def run_zero_world_preflight() -> dict[str, Any]:
    contract = load_contract()
    profile = contract["selected_profile_oracle"]
    canary_pass_count = 0
    nonzero_canary_count = 0
    legacy_oracle_rejection_count = 0
    predicate_mutation_rejection_count = 0
    for canary in contract["oracle_canaries"]:
        state = canary_state(canary)
        command = {"desired_heading_rad": canary["desired_heading_rad"]}
        expected = recompute_oracle(state, command, profile)
        if not math.isclose(
            expected["desired_heading_error_rad"],
            float(canary["expected_desired_heading_error_rad"]),
            rel_tol=0.0,
            abs_tol=float(profile["comparison_absolute_tolerance"]),
        ):
            raise R23D2OracleError(
                f"R23D2_CANARY_EXPECTATION_INVALID:{canary['canary_id']}"
            )
        evaluation = validate_receipt(expected, state, command, profile)
        if not evaluation["ok"]:
            raise R23D2OracleError(f"R23D2_CANARY_REJECTED:{canary['canary_id']}")
        canary_pass_count += 1
        if (
            abs(expected["cross_track_error_m"]) > 0.0
            or abs(expected["cross_track_velocity_m_s"]) > 0.0
        ):
            nonzero_canary_count += 1
            legacy_receipt = dict(expected)
            legacy_receipt["desired_heading_error_rad"] = wrap_angle(
                float(command["desired_heading_rad"])
                - float(state["reference_yaw_rad"])
            )
            legacy_receipt["yaw_tracking_error_rad"] = wrap_angle(
                expected["measured_yaw_error_rad"]
                - legacy_receipt["desired_heading_error_rad"]
            )
            if validate_receipt(legacy_receipt, state, command, profile)["ok"]:
                raise R23D2OracleError(
                    f"R23D2_LEGACY_ORACLE_NOT_REJECTED:{canary['canary_id']}"
                )
            legacy_oracle_rejection_count += 1
        for field in RECEIPT_FIELDS:
            mutated = dict(expected)
            mutated[field] += 1.0e-6
            mutation = validate_receipt(mutated, state, command, profile)
            if mutation["ok"] or mutation["failed_predicates"] != [f"{field}:mismatch"]:
                raise R23D2OracleError(
                    f"R23D2_PREDICATE_MUTATION_NOT_REJECTED:{canary['canary_id']}:{field}"
                )
            predicate_mutation_rejection_count += 1

    stage_controls = {
        "before_world": (0, 0),
        "world_construction_failed": (1, 0),
        "world_constructed": (1, 1),
        "settlement_complete": (1, 1),
        "controller_validation_failed": (1, 1),
        "cell_report_complete": (1, 1),
    }
    stage_pass_count = sum(
        validate_failure_provenance(stage, attempts, worlds, contract)
        for stage, (attempts, worlds) in stage_controls.items()
    )
    if stage_pass_count != len(stage_controls):
        raise R23D2OracleError("R23D2_STAGE_PROVENANCE_CONTROL_FAILED")
    if validate_failure_provenance("controller_validation_failed", 0, 0, contract):
        raise R23D2OracleError("R23D2_DANGLING_ZERO_FAILURE_COUNTS_ACCEPTED")

    return {
        "schema_version": "sporespore_qsdk_r23d2_oracle_preflight_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "canary_count": len(contract["oracle_canaries"]),
        "canary_pass_count": canary_pass_count,
        "nonzero_cross_track_canary_count": nonzero_canary_count,
        "legacy_raw_offset_oracle_rejection_count": legacy_oracle_rejection_count,
        "predicate_mutation_rejection_count": predicate_mutation_rejection_count,
        "failure_stage_control_pass_count": stage_pass_count,
        "actual_engine_worker_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "q_sdk_r23_satisfied": False,
        "physical_acceptance_authority": False,
    }


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if argv != ["preflight"]:
        print("usage: r23d2_oracle.py preflight", file=sys.stderr)
        return 2
    try:
        receipt = run_zero_world_preflight()
    except (R23D2OracleError, ValueError, TypeError, KeyError) as error:
        print(f"QSDK_R23D2_ORACLE_FAILURE {error}", file=sys.stderr)
        return 1
    print("QSDK_R23D2_ORACLE_PREFLIGHT " + json.dumps(receipt, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
