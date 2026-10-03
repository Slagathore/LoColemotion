"""Zero-world R23D23 post-closure source-receipt compatibility repair.

This module does not reopen R23D23 and cannot construct a MuJoCo model. It
exercises the real R23D21 portable controller receipt, then composes the
inherited neutral restoration through the explicit opt-in source contract.
R23D8's historical default remains the no-forward-member contract.
"""

from __future__ import annotations

import copy
import json
import math
from typing import Any

from sporespore_locomotion import LocomotionCore

from . import qsdk_r23d2_heading_response as base
from . import qsdk_r23d6_policy_compatible_restoration as prior_shape
from . import qsdk_r23d8_neutral_stance_composition as restoration


GATE_ID = "QSDK-R23D23-MJC-FORWARD-RECEIPT-D1"
CONTROLLER_POLICY_ID = "sporespore_balanced_wave_r23d21_reduced_yaw_authority_v1"
SOURCE_CONTRACT_ID = restoration.R23D21_FORWARD_VELOCITY_SOURCE_CONTRACT_ID
ARM_OFFSETS = {
    "reference_zero": 0.0,
    "positive_heading": 0.2,
    "negative_heading": -0.2,
}


def _source_fixture(
    arm_id: str,
) -> tuple[
    LocomotionCore,
    dict[str, Any],
    dict[str, Any],
    dict[str, Any],
    dict[str, Any],
]:
    if arm_id not in ARM_OFFSETS:
        raise RuntimeError("R23D23_D1_ARM_ID")
    core = LocomotionCore()
    compiled, profile = base._compile_boundary(
        core,
        policy_id=CONTROLLER_POLICY_ID,
    )
    canary = {
        "task_lateral_axis_world_unit": [0.0, 0.0, 1.0],
        "base_position_world_m": [0.37, 0.5, 0.23],
        "base_linear_velocity_world_m_s": [0.19, 0.0, -0.11],
        "measured_heading_world_rad": 0.07,
        "task_origin_world_m": [0.0, 0.0, 0.0],
        "reference_yaw_rad": 0.0,
    }
    state = base._state_for_canary(compiled, canary)
    command = base._command(
        f"r23d23_postclosure_forward_receipt_{arm_id}",
        ARM_OFFSETS[arm_id],
    )
    output = core.balanced_wave_policy_step(
        CONTROLLER_POLICY_ID,
        {
            "descriptor": base.bridge.s169_descriptor(),
            "memory": core.balanced_wave_initial_memory(),
            "state": state,
            "command": command,
        },
    )
    return core, compiled, profile, state, output["actuation"]


def _compose(
    core: LocomotionCore,
    compiled: dict[str, Any],
    profile: dict[str, Any],
    state: dict[str, Any],
    actuation: dict[str, Any],
) -> dict[str, Any]:
    robot = restoration._ZeroWorldRobot(core, compiled)
    return restoration.terminal_restoration_composition(
        robot,
        actuation,
        profile,
        state,
        {
            site_id: True
            for site_id in compiled["morphology"]["ordered_contact_site_ids"]
        },
        prior_shape._production_kinematics(compiled),
        restoration.TerminalRestorationMemory(),
        supported_policy_id=CONTROLLER_POLICY_ID,
        source_forward_velocity_contract_id=SOURCE_CONTRACT_ID,
    )


def _raises(
    actuation: dict[str, Any],
    expected_code: str,
    *,
    contract_id: str = SOURCE_CONTRACT_ID,
    policy_id: str = CONTROLLER_POLICY_ID,
) -> bool:
    try:
        restoration._validate_source_actuation(
            actuation,
            supported_policy_id=policy_id,
            source_forward_velocity_contract_id=contract_id,
        )
    except RuntimeError as error:
        return expected_code in str(error)
    return False


def _source_mutation_controls(valid: dict[str, Any]) -> dict[str, bool]:
    controls: dict[str, bool] = {}

    controls["historical_default_rejects_forward_member"] = _raises(
        valid,
        "NEUTRAL_UNEXPECTED_FORWARD_RECEIPT",
        contract_id=restoration.NO_FORWARD_VELOCITY_SOURCE_CONTRACT_ID,
    )
    controls["unknown_contract_rejected"] = _raises(
        valid,
        "NEUTRAL_FORWARD_SOURCE_CONTRACT_ID",
        contract_id="unknown_forward_contract",
    )
    controls["wrong_policy_rejected"] = _raises(
        valid,
        "NEUTRAL_SOURCE_POLICY_ID",
        policy_id="sporespore_balanced_wave_bw5r_b_v1",
    )

    missing = copy.deepcopy(valid)
    del missing["receipt"][restoration.FORWARD_VELOCITY_RECEIPT_MEMBER]
    controls["required_member_missing_rejected"] = _raises(
        missing,
        "NEUTRAL_FORWARD_RECEIPT_SHAPE",
    )

    not_object = copy.deepcopy(valid)
    not_object["receipt"][restoration.FORWARD_VELOCITY_RECEIPT_MEMBER] = []
    controls["member_shape_rejected"] = _raises(
        not_object,
        "NEUTRAL_FORWARD_RECEIPT_SHAPE",
    )

    for control_id, field, value, expected in (
        (
            "schema_rejected",
            "schema_version",
            "mutated_schema",
            "NEUTRAL_FORWARD_RECEIPT_IDENTITY",
        ),
        (
            "mode_rejected",
            "mode_id",
            "mutated_mode",
            "NEUTRAL_FORWARD_RECEIPT_IDENTITY",
        ),
        (
            "orientation_rejected",
            "velocity_error_orientation_id",
            "mutated_orientation",
            "NEUTRAL_FORWARD_RECEIPT_IDENTITY",
        ),
        (
            "maximum_correction_rejected",
            "maximum_hip_target_correction_rad",
            0.031,
            "NEUTRAL_FORWARD_RECEIPT_IDENTITY",
        ),
        (
            "branch_surface_rejected",
            "morphology_branch_surface_count",
            1,
            "NEUTRAL_FORWARD_RECEIPT_IDENTITY",
        ),
        (
            "controller_parameter_rejected",
            "controller_parameter",
            False,
            "NEUTRAL_FORWARD_RECEIPT_IDENTITY",
        ),
        (
            "walking_claim_rejected",
            "walking_claim_authorized",
            True,
            "NEUTRAL_FORWARD_RECEIPT_IDENTITY",
        ),
        (
            "physical_authority_rejected",
            "physical_acceptance_authority",
            True,
            "NEUTRAL_FORWARD_RECEIPT_IDENTITY",
        ),
        (
            "nonfinite_error_rejected",
            "normalized_forward_velocity_error",
            math.inf,
            "NEUTRAL_FORWARD_RECEIPT_NONFINITE",
        ),
        (
            "error_equation_rejected",
            "normalized_forward_velocity_error",
            0.5,
            "NEUTRAL_FORWARD_RECEIPT_ERROR_EQUATION",
        ),
    ):
        mutant = copy.deepcopy(valid)
        mutant["receipt"][restoration.FORWARD_VELOCITY_RECEIPT_MEMBER][field] = value
        controls[control_id] = _raises(mutant, expected)

    wrong_count = copy.deepcopy(valid)
    wrong_count["receipt"][restoration.FORWARD_VELOCITY_RECEIPT_MEMBER][
        "ordered_limb_corrections"
    ].pop()
    controls["limb_count_rejected"] = _raises(
        wrong_count,
        "NEUTRAL_FORWARD_RECEIPT_LIMB_COUNT",
    )

    wrong_order = copy.deepcopy(valid)
    corrections = wrong_order["receipt"][restoration.FORWARD_VELOCITY_RECEIPT_MEMBER][
        "ordered_limb_corrections"
    ]
    corrections[0], corrections[1] = corrections[1], corrections[0]
    controls["limb_order_rejected"] = _raises(
        wrong_order,
        "NEUTRAL_FORWARD_RECEIPT_LIMB_ORDER",
    )

    wrong_envelope = copy.deepcopy(valid)
    wrong_envelope["receipt"][restoration.FORWARD_VELOCITY_RECEIPT_MEMBER][
        "ordered_limb_corrections"
    ][0]["cycle_envelope"] = 1.1
    controls["limb_value_rejected"] = _raises(
        wrong_envelope,
        "NEUTRAL_FORWARD_RECEIPT_LIMB_VALUE",
    )

    wrong_equation = copy.deepcopy(valid)
    wrong_equation["receipt"][restoration.FORWARD_VELOCITY_RECEIPT_MEMBER][
        "ordered_limb_corrections"
    ][0]["applied_hip_target_correction_rad"] += 1.0e-6
    controls["limb_equation_rejected"] = _raises(
        wrong_equation,
        "NEUTRAL_FORWARD_RECEIPT_LIMB_EQUATION",
    )
    return controls


def run_zero_world_preflight() -> dict[str, Any]:
    arm_receipts: list[dict[str, Any]] = []
    positive_actuation: dict[str, Any] | None = None
    positive_composed: dict[str, Any] | None = None
    for arm_id in ARM_OFFSETS:
        core, compiled, profile, state, actuation = _source_fixture(arm_id)
        source = restoration._validate_source_actuation(
            actuation,
            supported_policy_id=CONTROLLER_POLICY_ID,
            source_forward_velocity_contract_id=SOURCE_CONTRACT_ID,
        )
        composed = _compose(core, compiled, profile, state, actuation)
        receipt = composed["terminal_receipt"]
        failures = restoration.terminal_receipt_failures(
            receipt,
            composed["canonical_actuation"],
            composed["host_mapping"],
            supported_policy_id=CONTROLLER_POLICY_ID,
            source_forward_velocity_contract_id=SOURCE_CONTRACT_ID,
        )
        if failures:
            raise RuntimeError("R23D23_D1_TERMINAL_RECEIPT:" + ",".join(failures))
        forward = source[restoration.FORWARD_VELOCITY_RECEIPT_MEMBER]
        arm_receipts.append(
            {
                "arm_id": arm_id,
                "controller_receipt_schema": source["schema_version"],
                "forward_receipt_schema": forward["schema_version"],
                "forward_mode_id": forward["mode_id"],
                "forward_error_orientation_id": forward[
                    "velocity_error_orientation_id"
                ],
                "ordered_limb_correction_count": len(
                    forward["ordered_limb_corrections"]
                ),
                "terminal_source_contract_id": receipt[
                    "source_forward_velocity_contract_id"
                ],
                "terminal_source_member_present": receipt[
                    "source_receipt_forward_velocity_member_present"
                ],
                "terminal_solution_count": len(
                    receipt["ordered_actuator_solutions"]
                ),
            }
        )
        if arm_id == "positive_heading":
            positive_actuation = actuation
            positive_composed = composed

    if positive_actuation is None or positive_composed is None:
        raise RuntimeError("R23D23_D1_POSITIVE_FIXTURE_MISSING")
    mutation_controls = _source_mutation_controls(positive_actuation)

    terminal_mutations: dict[str, bool] = {}
    for control_id, field, value, expected_failure in (
        (
            "terminal_presence_mutation_rejected",
            "source_receipt_forward_velocity_member_present",
            False,
            "source_forward_velocity_member",
        ),
        (
            "terminal_contract_mutation_rejected",
            "source_forward_velocity_contract_id",
            "mutated_contract",
            "source_forward_velocity_contract_id",
        ),
        (
            "terminal_schema_mutation_rejected",
            "source_forward_velocity_receipt_schema_version",
            "mutated_schema",
            "source_forward_velocity_schema",
        ),
    ):
        mutant = copy.deepcopy(positive_composed["terminal_receipt"])
        mutant[field] = value
        failures = restoration.terminal_receipt_failures(
            mutant,
            positive_composed["canonical_actuation"],
            positive_composed["host_mapping"],
            supported_policy_id=CONTROLLER_POLICY_ID,
            source_forward_velocity_contract_id=SOURCE_CONTRACT_ID,
        )
        terminal_mutations[control_id] = expected_failure in failures

    legacy = {
        "receipt": {
            "policy_id": restoration.SUPPORTED_POLICY_ID,
            "held_steering_fraction": 0.2,
        },
        "ordered_commands": [{} for _ in range(8)],
    }
    legacy_preserved = (
        restoration._validate_source_actuation(legacy)["policy_id"]
        == restoration.SUPPORTED_POLICY_ID
    )
    controls = mutation_controls | terminal_mutations
    if not all(controls.values()) or not legacy_preserved:
        raise RuntimeError("R23D23_D1_MUTATION_CONTROL")

    return {
        "schema_version": "sporespore_qsdk_r23d23_postclosure_forward_receipt_preflight_v1",
        "status": "zero_world_compatibility_repair_passed",
        "gate_id": GATE_ID,
        "controller_policy_id": CONTROLLER_POLICY_ID,
        "source_forward_velocity_contract_id": SOURCE_CONTRACT_ID,
        "arm_count": len(arm_receipts),
        "arm_receipts": arm_receipts,
        "mutation_control_count": len(controls),
        "mutation_controls": controls,
        "historical_r23d8_default_preserved": legacy_preserved,
        "physics_adapter_start_count": 0,
        "physical_process_launch_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_execution_authorized": False,
        "turning_acceptance": False,
        "physical_acceptance_authority": False,
    }


if __name__ == "__main__":
    print(
        "QSDK_R23D23_MJC_FORWARD_RECEIPT_D1 "
        + json.dumps(
            run_zero_world_preflight(),
            allow_nan=False,
            separators=(",", ":"),
            sort_keys=True,
        )
    )
