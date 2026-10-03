"""Shared zero-world contract and evaluator for the QSDK-R23D1 screen.

This module never launches physics. It freezes the normalized nine-cell
question that future Godot/Jolt, Rapier/Parry, and MuJoCo workers must answer.
Passing it cannot authorize a physical process or the release gate QSDK-R23.
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
CONTRACT_PATH = ROOT / "physical_development_contract_v1.json"
REPORT_SCHEMA = "sporespore_qsdk_r23d1_engine_cell_report_v2"


class PhysicalDevelopmentContractError(RuntimeError):
    """A fixture or retained projection violates the frozen design contract."""


def _raw_sha256(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def load_contract() -> dict[str, Any]:
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    authorization = contract.get("authorization", {})
    physical_authorized = authorization.get("physical_execution_authorized")
    expected_status = {
        False: "implemented_prephysical_development_contract",
        True: "frozen_physical_authorization_pending_exact_source_attestation",
    }.get(physical_authorized)
    engine_status = {
        engine.get("engine_id"): (
            engine.get("host_binding_status"),
            engine.get("actual_worker_path"),
            engine.get("actual_route_preflight_path"),
            engine.get("actual_route_zero_world_commissioned"),
        )
        for engine in contract.get("engines", [])
    }
    if (
        contract.get("schema_version")
        != "sporespore_qsdk_r23d1_physical_development_contract_v1"
        or contract.get("status") != expected_status
        or contract.get("gate_id") != "QSDK-R23D1"
        or contract.get("release_gate_id") != "QSDK-R23"
        or contract.get("fixture", {}).get("initial_condition_seed") != 21501
        or engine_status
        != {
            "godot_jolt": (
                "actual_route_zero_world_commissioned",
                "tests/test_sdk_qsdk_r23d1_godot_jolt_worker.gd",
                "sdk/run_qsdk_r23d1_godot_jolt_worker_preflight.ps1",
                True,
            ),
            "rapier_parry": (
                "actual_route_zero_world_commissioned",
                "sdk/adapters/rapier/src/bin/qsdk_r23d1_heading_response.rs",
                "sdk/run_qsdk_r23d1_rapier_worker_preflight.ps1",
                True,
            ),
            "mujoco": (
                "actual_route_zero_world_commissioned",
                "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d1_heading_response.py",
                "sdk/run_qsdk_r23d1_mujoco_worker_preflight.ps1",
                True,
            ),
        }
        or not isinstance(physical_authorized, bool)
        or authorization.get("q_sdk_r23_satisfied") is not False
        or contract.get("required_normalized_report_schema") != REPORT_SCHEMA
        or contract.get("required_command_validation", {}).get("schema_version")
        != "sporespore_qsdk_r23d1_command_validation_v1"
        or contract.get("required_command_validation", {}).get(
            "normalized_validation_mode"
        )
        != "native_adapter_structure_and_receipts_v1"
    ):
        raise PhysicalDevelopmentContractError("R23D1_CONTRACT_IDENTITY_INVALID")
    return contract


def contract_sha256() -> str:
    return _raw_sha256(CONTRACT_PATH)


def compile_cell_matrix(contract: dict[str, Any] | None = None) -> list[dict[str, Any]]:
    contract = load_contract() if contract is None else contract
    matrix = [
        {
            "ordinal": ordinal,
            "cell_id": f"{engine['engine_id']}__{arm['arm_id']}",
            "engine_id": engine["engine_id"],
            "arm_id": arm["arm_id"],
            "turn_heading_offset_rad": arm["turn_heading_offset_rad"],
        }
        for ordinal, (engine, arm) in enumerate(
            (
                (engine, arm)
                for engine in contract["engines"]
                for arm in contract["arms"]
            ),
            start=1,
        )
    ]
    declared = contract["cell_matrix"]
    if (
        len(matrix) != declared["declared_cell_count"]
        or len(contract["engines"]) != declared["engine_count"]
        or len(contract["arms"]) != declared["arm_count"]
        or len({cell["cell_id"] for cell in matrix}) != len(matrix)
    ):
        raise PhysicalDevelopmentContractError("R23D1_CELL_MATRIX_INVALID")
    return matrix


def _arm(arm_id: str, contract: dict[str, Any]) -> dict[str, Any]:
    matches = [arm for arm in contract["arms"] if arm["arm_id"] == arm_id]
    if len(matches) != 1:
        raise PhysicalDevelopmentContractError(f"R23D1_ARM_UNKNOWN:{arm_id}")
    return matches[0]


def heading_offset_for_step(
    arm_id: str,
    semantic_step: int,
    contract: dict[str, Any] | None = None,
) -> tuple[str, float]:
    contract = load_contract() if contract is None else contract
    if (
        isinstance(semantic_step, bool)
        or not isinstance(semantic_step, int)
        or semantic_step < 0
    ):
        raise PhysicalDevelopmentContractError("R23D1_SEMANTIC_STEP_INVALID")
    arm = _arm(arm_id, contract)
    for segment in contract["command_schedule"]["segments"]:
        if (
            segment["start_step_inclusive"]
            <= semantic_step
            < segment["end_step_exclusive"]
        ):
            offset = (
                0.0
                if segment["heading_offset_source"] == "zero"
                else float(arm["turn_heading_offset_rad"])
            )
            return segment["segment_id"], offset
    return "reference_continuation", 0.0


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _exact_keys(value: Any, expected: Iterable[str]) -> bool:
    return isinstance(value, dict) and set(value) == set(expected)


def evaluate_cell(
    report: dict[str, Any], contract: dict[str, Any] | None = None
) -> dict[str, Any]:
    """Cold-evaluate one normalized report without reading mutable engine logs."""

    contract = load_contract() if contract is None else contract
    matrix = {cell["cell_id"]: cell for cell in compile_cell_matrix(contract)}
    failures: list[str] = []

    def require(condition: bool, code: str) -> None:
        if not condition:
            failures.append(code)

    cell_id = str(report.get("cell_id", ""))
    expected = matrix.get(cell_id)
    require(expected is not None, "R23D1_CELL_ID_UNKNOWN")
    if expected is None:
        return _cell_result(cell_id, failures)

    source = contract["source_contract"]
    fixture = contract["fixture"]
    detection = contract["development_detection_gates"]
    execution = report.get("execution", {})
    command_validation = report.get("command_validation", {})
    schedule = report.get("schedule", {})
    controller = report.get("controller", {})
    physics = report.get("physics", {})

    require(report.get("schema_version") == REPORT_SCHEMA, "R23D1_SCHEMA")
    require(report.get("campaign_id") == contract["campaign_id"], "R23D1_CAMPAIGN")
    require(report.get("gate_id") == contract["gate_id"], "R23D1_GATE")
    require(report.get("engine_id") == expected["engine_id"], "R23D1_ENGINE")
    require(report.get("arm_id") == expected["arm_id"], "R23D1_ARM")
    require(
        report.get("selected_policy_id") == source["selected_policy_id"], "R23D1_POLICY"
    )
    require(
        report.get("selected_policy_digest") == source["selected_policy_digest"],
        "R23D1_POLICY_DIGEST",
    )
    require(report.get("morphology_id") == fixture["morphology_id"], "R23D1_MORPHOLOGY")
    require(
        report.get("campaign_seed") == fixture["initial_condition_seed"],
        "R23D1_CAMPAIGN_SEED",
    )
    require(report.get("contract_sha256") == contract_sha256(), "R23D1_CONTRACT_DIGEST")
    source_commit = report.get("source_commit")
    require(
        isinstance(source_commit, str)
        and len(source_commit) == 40
        and all(character in "0123456789abcdef" for character in source_commit),
        "R23D1_SOURCE_COMMIT",
    )

    step_count = execution.get("controller_semantic_step_count")
    exact_execution = {
        "world_attempt_count": 1,
        "world_build_count": 1,
        "world_reset_count": 0,
        "direct_body_write_count": 0,
        "controller_error_count": 0,
        "safe_no_actuation_count": 0,
        "nonfinite_observation_count": 0,
        "actuator_application_mismatch_count": 0,
    }
    for field, value in exact_execution.items():
        require(execution.get(field) == value, f"R23D1_EXECUTION_{field.upper()}")
    require(
        isinstance(step_count, int)
        and not isinstance(step_count, bool)
        and step_count
        >= contract["command_schedule"]["minimum_required_controller_step_count"],
        "R23D1_CONTROLLER_HORIZON",
    )
    require(
        isinstance(step_count, int)
        and execution.get("validated_portable_command_count") == step_count * 8,
        "R23D1_PORTABLE_COMMAND_COUNT",
    )
    require(
        isinstance(step_count, int)
        and execution.get("native_actuation_application_count") == step_count * 8,
        "R23D1_NATIVE_APPLICATION_COUNT",
    )
    validation_keys = (
        "schema_version",
        "normalized_validation_mode",
        "source_validation_mode",
        "native_validation_step_count",
        "heading_command_conditioned_step_count",
        "unconditioned_step_count",
        "legacy_command_parity_applicable",
        "legacy_command_parity_checked_step_count",
        "legacy_command_parity_waived_step_count",
    )
    require(
        _exact_keys(command_validation, validation_keys),
        "R23D1_COMMAND_VALIDATION_KEYS",
    )
    require(
        command_validation.get("schema_version")
        == contract["required_command_validation"]["schema_version"],
        "R23D1_COMMAND_VALIDATION_SCHEMA",
    )
    require(
        command_validation.get("normalized_validation_mode")
        == contract["required_command_validation"]["normalized_validation_mode"],
        "R23D1_COMMAND_VALIDATION_MODE",
    )
    source_validation_mode = command_validation.get("source_validation_mode")
    require(
        isinstance(source_validation_mode, str) and bool(source_validation_mode),
        "R23D1_SOURCE_VALIDATION_MODE",
    )
    require(
        isinstance(step_count, int)
        and command_validation.get("native_validation_step_count") == step_count,
        "R23D1_NATIVE_VALIDATION_STEP_COUNT",
    )
    require(
        isinstance(step_count, int)
        and command_validation.get("heading_command_conditioned_step_count")
        == step_count
        and command_validation.get("unconditioned_step_count") == 0,
        "R23D1_HEADING_CONDITIONED_STEP_COUNT",
    )
    require(
        command_validation.get("legacy_command_parity_applicable") is False
        and command_validation.get("legacy_command_parity_checked_step_count") == 0
        and command_validation.get("legacy_command_parity_waived_step_count") == 0,
        "R23D1_LEGACY_PARITY_BOUNDARY",
    )

    expected_counts = contract["command_schedule"]["expected_segment_sample_counts"]
    require(
        schedule.get("schedule_id") == contract["command_schedule"]["schedule_id"],
        "R23D1_SCHEDULE_ID",
    )
    require(
        schedule.get("observed_segment_sample_counts") == expected_counts,
        "R23D1_SEGMENT_COUNTS",
    )
    require(
        _finite(schedule.get("turn_heading_offset_rad"))
        and math.isclose(
            float(schedule["turn_heading_offset_rad"]),
            float(expected["turn_heading_offset_rad"]),
            rel_tol=0.0,
            abs_tol=1.0e-15,
        ),
        "R23D1_TURN_COMMAND",
    )
    require(
        schedule.get("reference_heading_sample_count") == 1_200,
        "R23D1_REFERENCE_SAMPLE_COUNT",
    )
    require(
        schedule.get("turn_heading_sample_count") == 1_200, "R23D1_TURN_SAMPLE_COUNT"
    )

    steering_limit = detection["maximum_absolute_requested_or_held_steering_fraction"]
    requested = controller.get("maximum_absolute_requested_steering_fraction")
    held = controller.get("maximum_absolute_held_steering_fraction")
    mean_turn = controller.get("mean_turn_held_steering_fraction")
    require(
        _finite(requested) and 0.0 <= float(requested) <= steering_limit,
        "R23D1_REQUESTED_STEERING_BOUND",
    )
    require(
        _finite(held) and 0.0 <= float(held) <= steering_limit,
        "R23D1_HELD_STEERING_BOUND",
    )
    require(_finite(mean_turn), "R23D1_MEAN_TURN_STEERING")

    for field in (
        "turn_phase_yaw_delta_rad",
        "final_reference_heading_error_rad",
        "final_forward_displacement_m",
        "maximum_tilt_rad",
        "minimum_torso_height_m",
    ):
        require(_finite(physics.get(field)), f"R23D1_PHYSICS_{field.upper()}_FINITE")
    require(physics.get("torso_ground_contact_step_count") == 0, "R23D1_TORSO_GROUND")
    require(
        _finite(physics.get("maximum_tilt_rad"))
        and float(physics["maximum_tilt_rad"]) <= detection["maximum_tilt_rad"],
        "R23D1_TILT",
    )
    require(
        _finite(physics.get("minimum_torso_height_m"))
        and float(physics["minimum_torso_height_m"])
        >= detection["minimum_torso_height_m"],
        "R23D1_TORSO_HEIGHT",
    )
    require(
        _finite(physics.get("final_forward_displacement_m"))
        and float(physics["final_forward_displacement_m"])
        >= detection["minimum_final_forward_displacement_m"],
        "R23D1_FORWARD_PROGRESS",
    )
    contacts = physics.get("contact_cycles_by_limb", {})
    require(
        _exact_keys(contacts, ("front_left", "front_right", "rear_left", "rear_right"))
        and all(
            isinstance(value, int)
            and not isinstance(value, bool)
            and value >= detection["minimum_contact_cycles_per_limb"]
            for value in contacts.values()
        ),
        "R23D1_CONTACT_CYCLES",
    )

    offset = float(expected["turn_heading_offset_rad"])
    if offset == 0.0:
        require(
            physics.get("engine_production_straight_walking_gate_passed") is True,
            "R23D1_ZERO_STRAIGHT_WALK",
        )
    else:
        yaw_delta = physics.get("turn_phase_yaw_delta_rad")
        require(
            _finite(yaw_delta)
            and math.copysign(1.0, float(yaw_delta)) == math.copysign(1.0, offset)
            and abs(float(yaw_delta))
            >= detection["minimum_absolute_signed_turn_phase_yaw_delta_rad"],
            "R23D1_SIGNED_YAW_RESPONSE",
        )
        require(
            _finite(mean_turn)
            and math.copysign(1.0, float(mean_turn)) == -math.copysign(1.0, offset)
            and abs(float(mean_turn)) > 1.0e-12,
            "R23D1_SIGNED_CONTROLLER_RESPONSE",
        )
        require(
            physics.get("commanded_turn_walk_gate_passed") is True, "R23D1_TURN_WALK"
        )

    require(
        report.get("claims")
        == {
            "development_screen_only": True,
            "q_sdk_r23_satisfied": False,
            "command_conditioned_turning": False,
            "cross_engine_equivalence": False,
            "release_authorized": False,
            "physical_acceptance_authority": False,
        },
        "R23D1_CLAIM_BOUNDARY",
    )
    return _cell_result(cell_id, failures)


def _cell_result(cell_id: str, failures: list[str]) -> dict[str, Any]:
    return {
        "cell_id": cell_id,
        "execution_valid": not failures,
        "screen_cell_passed": not failures,
        "failed_gate_count": len(failures),
        "failure_codes": failures,
        "q_sdk_r23_satisfied": False,
        "physical_acceptance_authority": False,
    }


def evaluate_aggregate(
    reports: list[dict[str, Any]], contract: dict[str, Any] | None = None
) -> dict[str, Any]:
    contract = load_contract() if contract is None else contract
    expected_ids = [cell["cell_id"] for cell in compile_cell_matrix(contract)]
    observed_ids = [str(report.get("cell_id", "")) for report in reports]
    failures: list[str] = []
    if len(reports) != len(expected_ids):
        failures.append("R23D1_AGGREGATE_REPORT_COUNT")
    if observed_ids != expected_ids:
        failures.append("R23D1_AGGREGATE_ORDER_OR_COMPLETENESS")
    if len(set(observed_ids)) != len(observed_ids):
        failures.append("R23D1_AGGREGATE_DUPLICATE_CELL")
    evaluations = [evaluate_cell(report, contract) for report in reports]
    if any(not evaluation["screen_cell_passed"] for evaluation in evaluations):
        failures.append("R23D1_AGGREGATE_CELL_FAILURE")
    return {
        "schema_version": "sporespore_qsdk_r23d1_aggregate_evaluation_v1",
        "campaign_id": contract["campaign_id"],
        "gate_id": contract["gate_id"],
        "report_count": len(reports),
        "cell_evaluations": evaluations,
        "development_screen_passed": not failures,
        "failed_gate_count": len(failures),
        "failure_codes": failures,
        "world_build_count": 0,
        "q_sdk_r23_satisfied": False,
        "command_conditioned_turning": False,
        "cross_engine_equivalence": False,
        "release_authorized": False,
        "physical_acceptance_authority": False,
    }


def perfect_report(
    cell: dict[str, Any], contract: dict[str, Any] | None = None
) -> dict[str, Any]:
    """Build a real-shaped synthetic report for negative-control evaluation."""

    contract = load_contract() if contract is None else contract
    offset = float(cell["turn_heading_offset_rad"])
    step_count = 2_400
    return {
        "schema_version": REPORT_SCHEMA,
        "campaign_id": contract["campaign_id"],
        "gate_id": contract["gate_id"],
        "cell_id": cell["cell_id"],
        "engine_id": cell["engine_id"],
        "arm_id": cell["arm_id"],
        "source_commit": "a" * 40,
        "contract_sha256": contract_sha256(),
        "selected_policy_id": contract["source_contract"]["selected_policy_id"],
        "selected_policy_digest": contract["source_contract"]["selected_policy_digest"],
        "morphology_id": contract["fixture"]["morphology_id"],
        "campaign_seed": contract["fixture"]["initial_condition_seed"],
        "execution": {
            "world_attempt_count": 1,
            "world_build_count": 1,
            "world_reset_count": 0,
            "direct_body_write_count": 0,
            "controller_error_count": 0,
            "safe_no_actuation_count": 0,
            "nonfinite_observation_count": 0,
            "actuator_application_mismatch_count": 0,
            "controller_semantic_step_count": step_count,
            "validated_portable_command_count": step_count * 8,
            "native_actuation_application_count": step_count * 8,
        },
        "command_validation": {
            "schema_version": contract["required_command_validation"]["schema_version"],
            "normalized_validation_mode": contract["required_command_validation"][
                "normalized_validation_mode"
            ],
            "source_validation_mode": "synthetic_native_adapter_validation_v1",
            "native_validation_step_count": step_count,
            "heading_command_conditioned_step_count": step_count,
            "unconditioned_step_count": 0,
            "legacy_command_parity_applicable": False,
            "legacy_command_parity_checked_step_count": 0,
            "legacy_command_parity_waived_step_count": 0,
        },
        "schedule": {
            "schedule_id": contract["command_schedule"]["schedule_id"],
            "turn_heading_offset_rad": offset,
            "observed_segment_sample_counts": copy.deepcopy(
                contract["command_schedule"]["expected_segment_sample_counts"]
            ),
            "reference_heading_sample_count": 1_200,
            "turn_heading_sample_count": 1_200,
        },
        "controller": {
            "maximum_absolute_requested_steering_fraction": 0.3,
            "maximum_absolute_held_steering_fraction": 0.25,
            "mean_turn_held_steering_fraction": (
                0.0 if offset == 0.0 else -math.copysign(0.2, offset)
            ),
        },
        "physics": {
            "turn_phase_yaw_delta_rad": (
                0.0 if offset == 0.0 else math.copysign(0.1, offset)
            ),
            "final_reference_heading_error_rad": 0.02,
            "final_forward_displacement_m": 0.5,
            "maximum_tilt_rad": 0.2,
            "minimum_torso_height_m": 0.4,
            "torso_ground_contact_step_count": 0,
            "contact_cycles_by_limb": {
                "front_left": 3,
                "front_right": 3,
                "rear_left": 3,
                "rear_right": 3,
            },
            "engine_production_straight_walking_gate_passed": offset == 0.0,
            "commanded_turn_walk_gate_passed": offset != 0.0,
        },
        "claims": {
            "development_screen_only": True,
            "q_sdk_r23_satisfied": False,
            "command_conditioned_turning": False,
            "cross_engine_equivalence": False,
            "release_authorized": False,
            "physical_acceptance_authority": False,
        },
    }


def run_zero_world_preflight() -> dict[str, Any]:
    contract = load_contract()
    matrix = compile_cell_matrix(contract)
    commissioned_workers = sum(
        engine.get("actual_route_zero_world_commissioned") is True
        for engine in contract["engines"]
    )
    schedule_checks = 0
    for arm in contract["arms"]:
        expected = (
            (0, "reference_warmup", 0.0),
            (599, "reference_warmup", 0.0),
            (600, "commanded_turn", float(arm["turn_heading_offset_rad"])),
            (1799, "commanded_turn", float(arm["turn_heading_offset_rad"])),
            (1800, "reference_recovery", 0.0),
            (2399, "reference_recovery", 0.0),
            (2400, "reference_continuation", 0.0),
        )
        for step, segment, offset in expected:
            if heading_offset_for_step(arm["arm_id"], step, contract) != (
                segment,
                offset,
            ):
                raise PhysicalDevelopmentContractError(
                    f"R23D1_SCHEDULE_BOUNDARY:{arm['arm_id']}:{step}"
                )
            schedule_checks += 1

    perfect_reports = [perfect_report(cell, contract) for cell in matrix]
    perfect_cell_passes = sum(
        evaluate_cell(report, contract)["screen_cell_passed"]
        for report in perfect_reports
    )
    perfect_aggregate = evaluate_aggregate(perfect_reports, contract)
    if perfect_cell_passes != 9 or not perfect_aggregate["development_screen_passed"]:
        raise PhysicalDevelopmentContractError("R23D1_PERFECT_FIXTURE_REJECTED")

    base_turn = perfect_report(matrix[1], contract)
    base_zero = perfect_report(matrix[0], contract)
    mutations: list[tuple[str, dict[str, Any]]] = []

    def mutate(
        name: str, source: dict[str, Any], path: tuple[str, ...], value: Any
    ) -> None:
        candidate = copy.deepcopy(source)
        target = candidate
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = value
        mutations.append((name, candidate))

    mutation_specs = (
        ("wrong_schema", base_turn, ("schema_version",), "wrong"),
        ("wrong_policy", base_turn, ("selected_policy_id",), "wrong"),
        ("wrong_morphology", base_turn, ("morphology_id",), "wrong"),
        ("wrong_seed", base_turn, ("campaign_seed",), 21502),
        ("wrong_contract_digest", base_turn, ("contract_sha256",), "sha256:00"),
        ("world_count", base_turn, ("execution", "world_build_count"), 2),
        ("controller_error", base_turn, ("execution", "controller_error_count"), 1),
        (
            "portable_count",
            base_turn,
            ("execution", "validated_portable_command_count"),
            1,
        ),
        (
            "native_count",
            base_turn,
            ("execution", "native_actuation_application_count"),
            1,
        ),
        (
            "native_validation_count",
            base_turn,
            ("command_validation", "native_validation_step_count"),
            2399,
        ),
        (
            "heading_conditioned_count",
            base_turn,
            ("command_validation", "heading_command_conditioned_step_count"),
            2399,
        ),
        (
            "legacy_parity_waiver",
            base_turn,
            ("command_validation", "legacy_command_parity_waived_step_count"),
            1,
        ),
        (
            "segment_count",
            base_turn,
            ("schedule", "observed_segment_sample_counts", "commanded_turn"),
            1199,
        ),
        ("turn_command", base_turn, ("schedule", "turn_heading_offset_rad"), -0.2),
        (
            "steering_bound",
            base_turn,
            ("controller", "maximum_absolute_held_steering_fraction"),
            0.41,
        ),
        (
            "steering_sign",
            base_turn,
            ("controller", "mean_turn_held_steering_fraction"),
            0.2,
        ),
        ("yaw_sign", base_turn, ("physics", "turn_phase_yaw_delta_rad"), -0.1),
        ("yaw_floor", base_turn, ("physics", "turn_phase_yaw_delta_rad"), 0.001),
        ("torso_ground", base_turn, ("physics", "torso_ground_contact_step_count"), 1),
        ("tilt", base_turn, ("physics", "maximum_tilt_rad"), 0.61),
        ("height", base_turn, ("physics", "minimum_torso_height_m"), 0.1),
        ("forward", base_turn, ("physics", "final_forward_displacement_m"), 0.0),
        ("contacts", base_turn, ("physics", "contact_cycles_by_limb", "front_left"), 1),
        ("turn_walk", base_turn, ("physics", "commanded_turn_walk_gate_passed"), False),
        (
            "zero_walk",
            base_zero,
            ("physics", "engine_production_straight_walking_gate_passed"),
            False,
        ),
        ("claim_inflation", base_turn, ("claims", "q_sdk_r23_satisfied"), True),
    )
    for spec in mutation_specs:
        mutate(*spec)
    rejected_mutations = [
        name
        for name, report in mutations
        if not evaluate_cell(report, contract)["screen_cell_passed"]
    ]
    if len(rejected_mutations) != len(mutations):
        raise PhysicalDevelopmentContractError("R23D1_CELL_NEGATIVE_CONTROL_ACCEPTED")

    aggregate_mutations = (
        perfect_reports[:-1],
        [*perfect_reports[:-1], copy.deepcopy(perfect_reports[0])],
        list(reversed(perfect_reports)),
    )
    aggregate_rejections = sum(
        not evaluate_aggregate(reports, contract)["development_screen_passed"]
        for reports in aggregate_mutations
    )
    if aggregate_rejections != len(aggregate_mutations):
        raise PhysicalDevelopmentContractError(
            "R23D1_AGGREGATE_NEGATIVE_CONTROL_ACCEPTED"
        )

    return {
        "schema_version": "sporespore_qsdk_r23d1_zero_world_preflight_receipt_v1",
        "campaign_id": contract["campaign_id"],
        "gate_id": contract["gate_id"],
        "contract_sha256": contract_sha256(),
        "declared_engine_count": 3,
        "declared_arm_count": 3,
        "declared_cell_count": 9,
        "schedule_boundary_check_count": schedule_checks,
        "perfect_cell_pass_count": perfect_cell_passes,
        "perfect_aggregate_passed": perfect_aggregate["development_screen_passed"],
        "cell_negative_control_count": len(mutations),
        "cell_negative_control_rejection_count": len(rejected_mutations),
        "aggregate_negative_control_count": len(aggregate_mutations),
        "aggregate_negative_control_rejection_count": aggregate_rejections,
        "actual_engine_worker_count": commissioned_workers,
        "actual_worker_entrypoint_count_exercised_by_design_preflight": 0,
        "world_build_count": 0,
        "physical_process_launch_count": 0,
        "physical_execution_authorized": bool(
            contract["authorization"]["physical_execution_authorized"]
        ),
        "q_sdk_r23_satisfied": False,
        "command_conditioned_turning": False,
        "cross_engine_equivalence": False,
        "release_authorized": False,
        "physical_acceptance_authority": False,
    }


def main(argv: list[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    if arguments:
        if len(arguments) == 2 and arguments[0] == "evaluate-cell":
            report_path = Path(arguments[1]).resolve()
            report = json.loads(report_path.read_text(encoding="utf-8"))
            evaluation = evaluate_cell(report)
            print(
                "QSDK_R23D1_CELL_EVALUATION " + json.dumps(evaluation, sort_keys=True)
            )
            return 0 if evaluation["screen_cell_passed"] else 1
        if len(arguments) >= 2 and arguments[0] == "evaluate-aggregate":
            reports = [
                json.loads(Path(path).resolve().read_text(encoding="utf-8"))
                for path in arguments[1:]
            ]
            evaluation = evaluate_aggregate(reports)
            print(
                "QSDK_R23D1_AGGREGATE_EVALUATION "
                + json.dumps(evaluation, sort_keys=True)
            )
            return 0 if evaluation["development_screen_passed"] else 1
        else:
            raise PhysicalDevelopmentContractError("R23D1_CLI_ARGUMENTS_INVALID")
    print(
        "QSDK_R23D1_ZERO_WORLD_DESIGN "
        + json.dumps(run_zero_world_preflight(), sort_keys=True)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
