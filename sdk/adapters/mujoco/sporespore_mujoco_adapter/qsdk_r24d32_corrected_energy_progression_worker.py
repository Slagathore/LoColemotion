"""R24D32 corrected-energy physical progression worker.

The worker reuses the complete R24D30 production route and R24D31 correction.
It adds only a distinct campaign identity, per-step native-energy invariants,
and a two-step-per-arm pre-freeze integration smoke that has no behavior or
official-decision authority.
"""

from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import traceback
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import native_recovery_development as runtime
from . import qsdk_r24d18_recovery_development_worker as shared
from . import qsdk_r24d27_natural_recovery_progression_worker as progression
from . import qsdk_r24d28_collection_refusal_observability_worker as observability
from . import qsdk_r24d30_natural_recovery_progression_worker as r24d30
from . import qsdk_r24d31_energy_ledger_correction_worker as r24d31
from .recovery_morphology_route import run_recovery_morphology_route_ghost


GATE_ID = "QSDK-R24D32"
CAMPAIGN_ID = "QSDK-R24D32-MUJOCO-CORRECTED-ENERGY-PROGRESSION-DEVELOPMENT"
CONTRACT_SCHEMA = "sporespore_qsdk_r24d32_corrected_energy_progression_contract_v1"
PREFLIGHT_SCHEMA = "sporespore_qsdk_r24d32_corrected_energy_progression_preflight_v1"
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d32_corrected_energy_progression_zero_world_receipt_v1"
)
COMPACT_PROJECTION_SCHEMA = (
    "sporespore_qsdk_r24d32_corrected_energy_progression_compact_projection_v1"
)
FULL_RESULT_SCHEMA = (
    "sporespore_qsdk_r24d32_corrected_energy_progression_full_result_v1"
)
MANIFEST_SCHEMA = "sporespore_qsdk_r24d32_corrected_energy_progression_manifest_v1"
PARTIAL_RESULT_SCHEMA = (
    "sporespore_qsdk_r24d32_corrected_energy_progression_partial_result_v1"
)
INVALID_RESULT_SCHEMA = (
    "sporespore_qsdk_r24d32_corrected_energy_progression_invalid_v1"
)
SMOKE_RESULT_SCHEMA = (
    "sporespore_qsdk_r24d32_corrected_energy_progression_integration_smoke_v1"
)
SMOKE_MANIFEST_SCHEMA = (
    "sporespore_qsdk_r24d32_corrected_energy_progression_integration_smoke_manifest_v1"
)
R24D30_CLOSURE_SHA256 = (
    "sha256:6055133c41179c1d58d0c79e453a8089ee2d4b3dfcf5a90fabfbc6b70aba7a1a"
)
R24D31_CLOSURE_SHA256 = (
    "sha256:88bf89c1694ebc84d0bbf61e653b6ec744d645ffa8d1d98cc78ce678d2d1f248"
)
ENERGY_IDENTITY_TOLERANCE_J = runtime.ACTUATOR_WORK_CROSSCHECK_TOLERANCE_J
EXPECTED_CELL_ID = progression.EXPECTED_CELL_ID
EXPECTED_SEED = progression.EXPECTED_SEED
EXPECTED_MAXIMUM_HORIZON_STEPS = progression.EXPECTED_MAXIMUM_HORIZON_STEPS
EXPECTED_PAIRED_ARM_COUNT = progression.EXPECTED_PAIRED_ARM_COUNT
REPO_ROOT = Path(__file__).resolve().parents[4]
CONTRACT_PATH = REPO_ROOT / "sdk/recovery/r24d32_corrected_energy_progression_contract_v1.json"
R24D30_CONTRACT_PATH = (
    REPO_ROOT / "sdk/recovery/r24d30_natural_recovery_progression_contract_v1.json"
)
R24D30_CLOSURE_PATH = (
    REPO_ROOT / "sdk/recovery/r24d30_natural_recovery_progression_physical_closure_v1.json"
)
R24D31_CLOSURE_PATH = (
    REPO_ROOT
    / "sdk/recovery/r24d31_mujoco_energy_ledger_correction_qualification_closure_v1.json"
)


class R24D32WorkerError(RuntimeError):
    """Stable fail-closed R24D32 worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D32WorkerError(code)


def _load(path: Path) -> dict[str, Any]:
    return shared._load_json(path)


def _sha256(path: Path) -> str:
    return shared._sha256_path(path)


def _finite_number(value: Any, code: str) -> float:
    _require(isinstance(value, (int, float)) and not isinstance(value, bool), code)
    number = float(value)
    _require(math.isfinite(number), code)
    return number


def load_contract_v1(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    contract = _load(path)
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "CONTRACT_QUESTION")
    _require(contract.get("physical_question_declared") is True, "CONTRACT_PHYSICAL")
    _require(
        contract["lineage"]["energy_correction_closure_raw_sha256"]
        == R24D31_CLOSURE_SHA256
        and _sha256(R24D31_CLOSURE_PATH) == R24D31_CLOSURE_SHA256
        and contract["lineage"]["energy_correction_may_requalify"] is False,
        "CONTRACT_R24D31_LINEAGE",
    )
    _require(
        contract["physical_lineage"]["predecessor_closure_raw_sha256"]
        == R24D30_CLOSURE_SHA256
        and _sha256(R24D30_CLOSURE_PATH) == R24D30_CLOSURE_SHA256
        and contract["physical_lineage"]["predecessor_may_rerun"] is False,
        "CONTRACT_R24D30_LINEAGE",
    )
    change = contract["controlled_change"]
    _require(
        change["energy_ledger_profile_id"] == runtime.ENERGY_LEDGER_PROFILE_ID
        and change["in_run_energy_component_validation_added"] is True
        and change["controller_changed"] is False
        and change["native_physics_changed"] is False
        and change["behavior_thresholds_changed"] is False
        and change["cell_changed"] is False
        and change["seed_changed"] is False
        and change["horizon_changed"] is False,
        "CONTRACT_CHANGE",
    )
    threshold = contract["threshold_and_adequacy_authority"]
    _require(
        threshold["maximum_energy_balance_residual_j"] == 0.25
        and threshold["native_component_identity_tolerance_j"]
        == ENERGY_IDENTITY_TOLERANCE_J
        and threshold["new_behavior_threshold_count"] == 0
        and threshold["new_empirical_threshold_count"] == 0
        and threshold["new_inference_margin_count"] == 0,
        "CONTRACT_THRESHOLD",
    )
    cell = contract["selected_development_cell"]
    horizon = contract["ghost_horizon"]
    _require(
        cell["cell_id"] == EXPECTED_CELL_ID
        and cell["seed"] == EXPECTED_SEED
        and cell["random_draw_count"] == 0,
        "CONTRACT_CELL",
    )
    _require(
        horizon["outer_steps_per_arm"] == EXPECTED_MAXIMUM_HORIZON_STEPS
        and horizon["paired_arm_count"] == EXPECTED_PAIRED_ARM_COUNT
        and set(horizon["existing_route_stop_phases"])
        == progression.NATURAL_STOP_PHASES,
        "CONTRACT_HORIZON",
    )
    _require(
        contract["held_out_seal"]["held_out_cell_access_count"] == 0
        and contract["held_out_seal"]["held_out_selector_invocation_count"] == 0
        and contract["held_out_seal"]["held_out_data_use_permitted"] is False,
        "CONTRACT_HELDOUT",
    )
    _require(
        len(contract["source_inventory"])
        == contract["prospective_freeze"]["source_inventory_count"]
        == len(set(contract["source_inventory"])),
        "CONTRACT_SOURCE_INVENTORY",
    )
    return contract


def retarget_projection_v1(value: Mapping[str, Any]) -> dict[str, Any]:
    projection = r24d30.retarget_projection_v1(value)
    projection.update(
        {
            "schema_version": COMPACT_PROJECTION_SCHEMA,
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "qualified_energy_correction_gate_id": "QSDK-R24D31",
            "energy_ledger_profile_id": runtime.ENERGY_LEDGER_PROFILE_ID,
        }
    )
    return projection


def compact_projection_v1(full: Mapping[str, Any]) -> dict[str, Any]:
    return retarget_projection_v1(progression.compact_projection_v1(full))


def build_collection_refusal_partial_v1(
    error: runtime.NativeRecoveryCollectionRefusal,
    *,
    source_commit: str,
    contract_path: str,
    qualification_receipt_path: str,
    operation_lock: Mapping[str, Any],
) -> dict[str, Any]:
    """Retarget the already-qualified R24D30 refusal receipt without loss."""

    partial = r24d30.build_collection_refusal_partial_v1(
        error,
        source_commit=source_commit,
        contract_path=contract_path,
        qualification_receipt_path=qualification_receipt_path,
        operation_lock=operation_lock,
    )
    partial.update(
        {
            "schema_version": PARTIAL_RESULT_SCHEMA,
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "qualified_energy_correction_gate_id": "QSDK-R24D31",
            "energy_ledger_profile_id": runtime.ENERGY_LEDGER_PROFILE_ID,
        }
    )
    shared._canonical_bytes(partial)
    return partial


def build_collection_refusal_invalid_v1(
    error: runtime.NativeRecoveryCollectionRefusal,
    *,
    source_commit: str,
    traceback_text: str,
    partial_result_path: str,
    partial_result_raw_sha256: str,
    partial_result_byte_length: int,
) -> dict[str, Any]:
    invalid = r24d30.build_collection_refusal_invalid_v1(
        error,
        source_commit=source_commit,
        traceback_text=traceback_text,
        partial_result_path=partial_result_path,
        partial_result_raw_sha256=partial_result_raw_sha256,
        partial_result_byte_length=partial_result_byte_length,
    )
    invalid.update(
        {
            "schema_version": INVALID_RESULT_SCHEMA,
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "qualified_energy_correction_gate_id": "QSDK-R24D31",
            "energy_ledger_profile_id": runtime.ENERGY_LEDGER_PROFILE_ID,
        }
    )
    shared._canonical_bytes(invalid)
    return invalid


def publish_collection_refusal_v1(
    error: runtime.NativeRecoveryCollectionRefusal,
    *,
    output_directory: Path,
    source_commit: str,
    contract_path: Path,
    qualification_receipt_path: Path,
    operation_lock_receipt_path: Path,
    traceback_text: str,
) -> dict[str, Any]:
    operation_lock = _load(operation_lock_receipt_path)
    partial = build_collection_refusal_partial_v1(
        error,
        source_commit=source_commit,
        contract_path=contract_path.as_posix(),
        qualification_receipt_path=str(qualification_receipt_path),
        operation_lock=operation_lock,
    )
    partial_path = output_directory / "partial_result.json"
    partial_sha256 = shared._write_json_exclusive(partial_path, partial)
    invalid = build_collection_refusal_invalid_v1(
        error,
        source_commit=source_commit,
        traceback_text=traceback_text,
        partial_result_path=partial_path.name,
        partial_result_raw_sha256=partial_sha256,
        partial_result_byte_length=partial_path.stat().st_size,
    )
    shared._write_json_exclusive(output_directory / "invalid_result.json", invalid)
    return invalid


def validate_energy_trace_v2(result: Mapping[str, Any]) -> dict[str, Any]:
    """Validate every independently sourced energy field on a paired trace."""

    component_fields = (
        "step_constraint_work_j",
        "step_damper_work_j",
        "step_fluid_work_j",
        "step_adhesion_work_j",
        "step_dissipated_energy_j",
        "cumulative_constraint_work_j",
        "cumulative_damper_work_j",
        "cumulative_fluid_work_j",
        "cumulative_adhesion_work_j",
        "cumulative_dissipated_energy_j",
    )
    total_steps = 0
    arm_step_counts: dict[str, int] = {}
    maximum_absolute_residual_j = 0.0
    minimum_raised_absolute_residual_j = math.inf
    raised_observation_count = 0
    for arm_key in ("candidate", "matched_zero_command"):
        arm = result[arm_key]
        observations = arm["observations"]
        native_receipts = arm["native_receipts"]
        portable_receipts = arm["portable_step_receipts"]
        _require(
            len(observations) == len(native_receipts) == len(portable_receipts),
            f"R24D32_{arm_key.upper()}_COUNT_MISMATCH",
        )
        arm_step_counts[arm_key] = len(observations)
        for observation, native_receipt, portable in zip(
            observations,
            native_receipts,
            portable_receipts,
            strict=True,
        ):
            native = native_receipt["native_step"]
            _require(
                native["energy_ledger_profile_id"]
                == runtime.ENERGY_LEDGER_PROFILE_ID,
                "R24D32_ENERGY_PROFILE_IDENTITY",
            )
            values = {
                field: _finite_number(native[field], f"R24D32_NONFINITE:{field}")
                for field in component_fields
            }
            step_sum = -(
                values["step_constraint_work_j"]
                + values["step_damper_work_j"]
                + values["step_fluid_work_j"]
                + values["step_adhesion_work_j"]
            )
            cumulative_sum = -(
                values["cumulative_constraint_work_j"]
                + values["cumulative_damper_work_j"]
                + values["cumulative_fluid_work_j"]
                + values["cumulative_adhesion_work_j"]
            )
            _require(
                abs(step_sum - values["step_dissipated_energy_j"])
                <= ENERGY_IDENTITY_TOLERANCE_J,
                "R24D32_STEP_COMPONENT_IDENTITY",
            )
            _require(
                abs(cumulative_sum - values["cumulative_dissipated_energy_j"])
                <= ENERGY_IDENTITY_TOLERANCE_J,
                "R24D32_CUMULATIVE_COMPONENT_IDENTITY",
            )
            _require(
                values["cumulative_dissipated_energy_j"] >= 0.0,
                "R24D32_CUMULATIVE_DISSIPATION_NEGATIVE",
            )
            energy = observation["energy_balance"]
            initial = _finite_number(
                energy["initial_mechanical_energy_j"],
                "R24D32_INITIAL_ENERGY_NONFINITE",
            )
            current = _finite_number(
                energy["current_mechanical_energy_j"],
                "R24D32_CURRENT_ENERGY_NONFINITE",
            )
            actuator = _finite_number(
                energy["cumulative_applied_actuator_work_j"],
                "R24D32_ACTUATOR_WORK_NONFINITE",
            )
            external = _finite_number(
                energy["cumulative_external_work_j"],
                "R24D32_EXTERNAL_WORK_NONFINITE",
            )
            dissipated = _finite_number(
                energy["cumulative_dissipated_energy_j"],
                "R24D32_PORTABLE_DISSIPATION_NONFINITE",
            )
            _require(
                energy["source_measurement"] is True
                and external == 0.0
                and actuator == native["cumulative_actuator_work_j"]
                and dissipated == values["cumulative_dissipated_energy_j"],
                "R24D32_NATIVE_PORTABLE_ENERGY_IDENTITY",
            )
            residual = current - initial - actuator - external + dissipated
            _require(math.isfinite(residual), "R24D32_RESIDUAL_NONFINITE")
            absolute_residual = abs(residual)
            maximum_absolute_residual_j = max(
                maximum_absolute_residual_j,
                absolute_residual,
            )
            if portable["classification"]["pose_class"] == "raised_body":
                raised_observation_count += 1
                minimum_raised_absolute_residual_j = min(
                    minimum_raised_absolute_residual_j,
                    absolute_residual,
                )
            total_steps += 1
    return {
        "ok": True,
        "energy_ledger_profile_id": runtime.ENERGY_LEDGER_PROFILE_ID,
        "native_component_identity_tolerance_j": ENERGY_IDENTITY_TOLERANCE_J,
        "validated_step_count": total_steps,
        "arm_step_counts": arm_step_counts,
        "raised_observation_count": raised_observation_count,
        "minimum_raised_absolute_residual_j": (
            None
            if math.isinf(minimum_raised_absolute_residual_j)
            else minimum_raised_absolute_residual_j
        ),
        "maximum_absolute_residual_j": maximum_absolute_residual_j,
        "all_components_finite": True,
        "all_component_identities_exact": True,
        "native_portable_energy_identity_exact": True,
        "cumulative_dissipation_nonnegative": True,
    }


def _synthetic_energy_result() -> dict[str, Any]:
    native = {
        "energy_ledger_profile_id": runtime.ENERGY_LEDGER_PROFILE_ID,
        "step_constraint_work_j": -0.04,
        "step_damper_work_j": -0.01,
        "step_fluid_work_j": 0.0,
        "step_adhesion_work_j": 0.0,
        "step_dissipated_energy_j": 0.05,
        "cumulative_constraint_work_j": -0.04,
        "cumulative_damper_work_j": -0.01,
        "cumulative_fluid_work_j": 0.0,
        "cumulative_adhesion_work_j": 0.0,
        "cumulative_dissipated_energy_j": 0.05,
        "cumulative_actuator_work_j": 0.02,
    }
    observation = {
        "energy_balance": {
            "initial_mechanical_energy_j": 1.0,
            "current_mechanical_energy_j": 0.97,
            "cumulative_applied_actuator_work_j": 0.02,
            "cumulative_external_work_j": 0.0,
            "cumulative_dissipated_energy_j": 0.05,
            "source_measurement": True,
        }
    }
    portable = {"classification": {"pose_class": "transitional"}}
    arm = {
        "observations": [observation],
        "native_receipts": [{"native_step": native}],
        "portable_step_receipts": [portable],
    }
    return {"candidate": deepcopy(arm), "matched_zero_command": deepcopy(arm)}


def _mutation_rejected(mutator: Any, expected_code: str) -> bool:
    value = _synthetic_energy_result()
    mutator(value)
    try:
        validate_energy_trace_v2(value)
    except R24D32WorkerError as error:
        return str(error) == expected_code
    return False


def _r24d32_controls() -> tuple[dict[str, bool], dict[str, Any]]:
    contract = load_contract_v1()
    closure31 = _load(R24D31_CLOSURE_PATH)
    contract30 = _load(R24D30_CONTRACT_PATH)
    base_facts = progression._positive_control_facts()
    base_projection = {
        "schema_version": (
            progression.COMPACT_PROJECTION_SCHEMA
            if hasattr(progression, "COMPACT_PROJECTION_SCHEMA")
            else "sporespore_qsdk_r24d27_natural_recovery_progression_compact_projection_v1"
        ),
        "gate_id": progression.GATE_ID,
        "campaign_id": progression.CAMPAIGN_ID,
        "target_facts": deepcopy(base_facts),
        "target_checks": progression.evaluate_progression_facts_v1(base_facts),
        "execution_valid": True,
        "decision_positive": True,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    retargeted = retarget_projection_v1(base_projection)
    refusal = observability._synthetic_refusal_receipt()
    refusal_context = observability._synthetic_refusal_context()
    caught_refusal: runtime.NativeRecoveryCollectionRefusal | None = None
    try:
        runtime.require_supported_native_collection_v1(
            refusal,
            refusal_context=refusal_context,
        )
    except runtime.NativeRecoveryCollectionRefusal as error:
        caught_refusal = error
    _require(caught_refusal is not None, "R24D32_FORCED_REFUSAL_NOT_RAISED")
    refusal_partial = build_collection_refusal_partial_v1(
        caught_refusal,
        source_commit="0" * 40,
        contract_path=CONTRACT_PATH.as_posix(),
        qualification_receipt_path="synthetic-zero-world",
        operation_lock={
            "acquired": True,
            "role": "physical",
            "test_only": True,
            "physical_acceptance_authority": False,
        },
    )
    refusal_invalid = build_collection_refusal_invalid_v1(
        caught_refusal,
        source_commit="0" * 40,
        traceback_text="synthetic-zero-world",
        partial_result_path="partial_result.json",
        partial_result_raw_sha256="sha256:" + "1" * 64,
        partial_result_byte_length=123,
    )

    def wrong_profile(value: dict[str, Any]) -> None:
        value["candidate"]["native_receipts"][0]["native_step"][
            "energy_ledger_profile_id"
        ] = "mutated"

    def wrong_sum(value: dict[str, Any]) -> None:
        value["candidate"]["native_receipts"][0]["native_step"][
            "step_dissipated_energy_j"
        ] = 0.04

    def wrong_portable(value: dict[str, Any]) -> None:
        value["candidate"]["observations"][0]["energy_balance"][
            "cumulative_dissipated_energy_j"
        ] = 0.04

    def negative_cumulative(value: dict[str, Any]) -> None:
        native = value["candidate"]["native_receipts"][0]["native_step"]
        native["cumulative_constraint_work_j"] = 0.04
        native["cumulative_damper_work_j"] = 0.01
        native["cumulative_dissipated_energy_j"] = -0.05
        value["candidate"]["observations"][0]["energy_balance"][
            "cumulative_dissipated_energy_j"
        ] = -0.05

    synthetic = validate_energy_trace_v2(_synthetic_energy_result())
    checks = {
        "closed_r24d31_zero_world_correction_is_content_addressed": (
            _sha256(R24D31_CLOSURE_PATH) == R24D31_CLOSURE_SHA256
            and closure31["source"]["commit"]
            == contract["lineage"]["energy_correction_source_commit"]
            and closure31["qualification"]["controls_passed"] == 12
            and closure31["qualification"]["world_attempt_count"] == 0
            and closure31["claim_boundary"][
                "independent_native_work_source_correction_qualified"
            ]
            is True
        ),
        "r24d30_cell_horizon_threshold_controller_and_decision_are_unchanged": (
            all(
                contract["selected_development_cell"][key]
                == contract30["selected_development_cell"][key]
                for key in (
                    "cohort_id",
                    "question_class",
                    "cell_id",
                    "initial_state_id",
                    "torso_roll_rad",
                    "seed_label",
                    "seed_sha256",
                    "seed",
                    "random_draw_count",
                )
            )
            and contract["ghost_horizon"]["outer_steps_per_arm"]
            == contract30["ghost_horizon"]["outer_steps_per_arm"]
            and contract["threshold_and_adequacy_authority"][
                "maximum_energy_balance_residual_j"
            ]
            == 0.25
            and contract["controlled_change"]["controller_changed"] is False
            and contract["controlled_change"][
                "progression_evaluator_meaning_changed"
            ]
            is False
        ),
        "r24d30_progression_projection_retargets_without_changing_decision_facts": (
            retargeted["gate_id"] == GATE_ID
            and retargeted["campaign_id"] == CAMPAIGN_ID
            and retargeted["target_facts"] == base_projection["target_facts"]
            and retargeted["target_checks"] == base_projection["target_checks"]
            and all(retargeted["target_checks"].values())
        ),
        "collection_refusal_retargets_preserving_exact_diagnostic_and_zero_claims": (
            refusal_partial["schema_version"] == PARTIAL_RESULT_SCHEMA
            and refusal_partial["gate_id"] == GATE_ID
            and refusal_partial["campaign_id"] == CAMPAIGN_ID
            and refusal_partial["native_collection_refusal"]["collector_receipt"]
            == refusal
            and refusal_partial["native_collection_refusal"]["refusal_context"]
            == refusal_context
            and refusal_partial["prone_to_standing_claimed"] is False
            and refusal_partial["physical_acceptance_authority"] is False
            and refusal_partial["release_authority"] is False
            and refusal_invalid["schema_version"] == INVALID_RESULT_SCHEMA
            and refusal_invalid["gate_id"] == GATE_ID
            and refusal_invalid["campaign_id"] == CAMPAIGN_ID
            and refusal_invalid["collector_support_status"]
            == caught_refusal.diagnostic["collector_support_status"]
            and refusal_invalid["collector_refusal_reason"]
            == caught_refusal.diagnostic["collector_refusal_reason"]
            and refusal_invalid["accepted_prefix_retained"] is True
            and refusal_invalid["current_observation_retained"] is True
            and refusal_invalid["current_native_receipt_retained"] is True
            and refusal_invalid["valid_physical_behavior_result_observed"] is False
            and refusal_invalid["prone_to_standing_claimed"] is False
            and refusal_invalid["physical_acceptance_authority"] is False
            and refusal_invalid["release_authority"] is False
        ),
        "energy_invariant_validator_accepts_exact_components_and_rejects_profile_sum_portable_and_sign_mutations": (
            synthetic["validated_step_count"] == 2
            and _mutation_rejected(wrong_profile, "R24D32_ENERGY_PROFILE_IDENTITY")
            and _mutation_rejected(wrong_sum, "R24D32_STEP_COMPONENT_IDENTITY")
            and _mutation_rejected(
                wrong_portable,
                "R24D32_NATIVE_PORTABLE_ENERGY_IDENTITY",
            )
            and _mutation_rejected(
                negative_cumulative,
                "R24D32_CUMULATIVE_DISSIPATION_NEGATIVE",
            )
        ),
    }
    return checks, {
        "r24d30_closure_raw_sha256": R24D30_CLOSURE_SHA256,
        "r24d31_closure_raw_sha256": R24D31_CLOSURE_SHA256,
        "energy_ledger_profile_id": runtime.ENERGY_LEDGER_PROFILE_ID,
        "native_component_identity_tolerance_j": ENERGY_IDENTITY_TOLERANCE_J,
        "synthetic_validated_step_count": synthetic["validated_step_count"],
        "forced_refusal_semantic_step": refusal_context["semantic_step"],
    }


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    preflight31 = r24d31.run_zero_world_preflight(core)
    checks, details = _r24d32_controls()
    _require(all(checks.values()), "R24D32_ZERO_WORLD_CONTROL_FAILED")
    _require(
        preflight31["negative_control_count"] == 12,
        "R24D32_INHERITED_CONTROL_COUNT",
    )
    receipt = deepcopy(preflight31)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "gate_id": GATE_ID,
            "historical_r24d30_control_count_bound_by_immutable_closure": 48,
            "historical_r24d30_controls_reexecuted": False,
            "executed_r24d31_control_count": 12,
            "r24d32_integration_controls": checks,
            "r24d32_integration_control_details": details,
            "r24d32_integration_control_count": len(checks),
            "r24d32_integration_controls_passed": sum(checks.values()),
            "negative_control_count": 12 + len(checks),
            "negative_controls_passed": 12 + sum(checks.values()),
            "development_integration_smoke_executed": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
    )
    return receipt


def _source_state(contract: Mapping[str, Any]) -> dict[str, Any]:
    entries = []
    for relative in contract["source_inventory"]:
        path = REPO_ROOT / relative
        _require(path.is_file(), f"R24D32_SOURCE_MISSING:{relative}")
        raw = path.read_bytes()
        entries.append(
            {
                "path": relative,
                "byte_length": len(raw),
                "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
            }
        )
    canonical = shared._canonical_bytes(entries)
    status = subprocess.run(
        ["git", "status", "--porcelain=v1"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()
    return {
        "head_commit": subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip(),
        "worktree_clean": not status,
        "status_entries": status,
        "source_manifest": entries,
        "source_manifest_entry_count": len(entries),
        "source_manifest_canonical_byte_length": len(canonical),
        "source_manifest_canonical_sha256": (
            "sha256:" + hashlib.sha256(canonical).hexdigest()
        ),
    }


def _run_route(core_library: Path, contract: Mapping[str, Any], horizon: int) -> dict[str, Any]:
    result = run_recovery_morphology_route_ghost(
        LocomotionCore(core_library),
        cell=deepcopy(contract["selected_development_cell"]),
        horizon_steps=horizon,
    )
    invariants = validate_energy_trace_v2(result)
    return {"result": result, "energy_invariants": invariants}


def run_integration_smoke_v1(
    *,
    core_library: Path,
    contract_path: Path,
    output_directory: Path,
) -> dict[str, Any]:
    _require(output_directory.is_dir(), "SMOKE_OUTPUT_DIRECTORY_MISSING")
    contract = load_contract_v1(contract_path)
    smoke = contract["development_integration_smoke"]
    _require(
        smoke["maximum_outer_steps_per_arm"] == 2
        and smoke["paired_arm_count"] == 2
        and smoke["maximum_total_native_solver_steps"] == 20,
        "SMOKE_CONTRACT",
    )
    source_state = _source_state(contract)
    execution = _run_route(core_library, contract, 2)
    result = execution["result"]
    envelope = {
        "schema_version": SMOKE_RESULT_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "question_class": "repeatable_development_integration_not_finite_decision",
        "source_state": source_state,
        "contract_path": contract_path.as_posix(),
        "contract_raw_sha256": _sha256(contract_path),
        "horizon_steps_per_arm": 2,
        "result": result,
        "energy_invariants": execution["energy_invariants"],
        "code_path_integration_passed": True,
        "behavior_success_predicted_or_claimed": False,
        "official_physical_identity_consumed": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    result_path = output_directory / "integration_smoke_result.json"
    result_sha256 = shared._write_json_exclusive(result_path, envelope)
    manifest = {
        "schema_version": SMOKE_MANIFEST_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "source_manifest_canonical_sha256": source_state[
            "source_manifest_canonical_sha256"
        ],
        "artifacts": [
            {
                "path": result_path.name,
                "byte_length": result_path.stat().st_size,
                "raw_sha256": result_sha256,
            }
        ],
        "model_construction_count": result["model_construction_count"],
        "world_attempt_count": result["world_attempt_count"],
        "world_build_count": result["world_build_count"],
        "outer_step_count": result["outer_step_count"],
        "native_solver_step_count": result["native_solver_step_count"],
        "code_path_integration_passed": True,
        "official_physical_identity_consumed": False,
        "behavior_success_predicted_or_claimed": False,
        "held_out_cell_access_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    manifest_path = output_directory / "manifest.json"
    manifest_sha256 = shared._write_json_exclusive(manifest_path, manifest)
    return {
        "ok": True,
        "code_path_integration_passed": True,
        "evidence_root": str(output_directory),
        "result_path": str(result_path),
        "result_raw_sha256": result_sha256,
        "manifest_path": str(manifest_path),
        "manifest_raw_sha256": manifest_sha256,
        "models": result["model_construction_count"],
        "worlds": result["world_attempt_count"],
        "outer_steps": result["outer_step_count"],
        "solver_steps": result["native_solver_step_count"],
        "official_physical_identity_consumed": False,
    }


def run_and_publish_v1(
    *,
    core_library: Path,
    contract_path: Path,
    output_directory: Path,
    source_commit: str,
    qualification_receipt_path: Path,
    operation_lock_receipt_path: Path,
) -> dict[str, Any]:
    _require(output_directory.is_dir(), "OUTPUT_DIRECTORY_MISSING")
    contract = load_contract_v1(contract_path)
    qualification = _load(qualification_receipt_path)
    operation_lock = _load(operation_lock_receipt_path)
    _require(
        qualification.get("schema_version") == QUALIFICATION_RECEIPT_SCHEMA
        and qualification.get("gate_id") == GATE_ID
        and qualification.get("ok") is True
        and qualification.get("mode") == "qualification"
        and qualification.get("source_commit") == source_commit,
        "QUALIFICATION_RECEIPT_INVALID",
    )
    _require(
        operation_lock.get("acquired") is True
        and operation_lock.get("role") == "physical"
        and operation_lock.get("test_only") is False,
        "OPERATION_LOCK_RECEIPT_INVALID",
    )
    execution = _run_route(
        core_library,
        contract,
        EXPECTED_MAXIMUM_HORIZON_STEPS,
    )
    result = execution["result"]
    projection = compact_projection_v1(result)
    projection["energy_invariants"] = execution["energy_invariants"]
    envelope = {
        "schema_version": FULL_RESULT_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "ledger_scope": deepcopy(contract["ledger_scope"]),
        "source_commit": source_commit,
        "contract_path": contract_path.as_posix(),
        "contract_raw_sha256": _sha256(contract_path),
        "qualification_receipt_path": str(qualification_receipt_path),
        "qualification_receipt_raw_sha256": _sha256(qualification_receipt_path),
        "operation_lock": operation_lock,
        "qualified_energy_correction_gate_id": "QSDK-R24D31",
        "energy_ledger_profile_id": runtime.ENERGY_LEDGER_PROFILE_ID,
        "result": result,
        "energy_invariants": execution["energy_invariants"],
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    full_path = output_directory / "paired_full_result.json"
    full_sha256 = shared._write_json_exclusive(full_path, envelope)
    projection["source_commit"] = source_commit
    projection["full_result_path"] = full_path.name
    projection["full_result_raw_sha256"] = full_sha256
    summary_path = output_directory / "paired_summary.json"
    summary_sha256 = shared._write_json_exclusive(summary_path, projection)
    manifest = {
        "schema_version": MANIFEST_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "source_commit": source_commit,
        "artifacts": [
            {
                "path": full_path.name,
                "raw_sha256": full_sha256,
                "byte_length": full_path.stat().st_size,
            },
            {
                "path": summary_path.name,
                "raw_sha256": summary_sha256,
                "byte_length": summary_path.stat().st_size,
            },
        ],
        "execution_valid": projection["execution_valid"],
        "decision_positive": projection["decision_positive"],
        "energy_invariants_passed": True,
        "complete_trace_retained": True,
        "compact_projection_retained": True,
        "held_out_cell_access_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    manifest_path = output_directory / "manifest.json"
    manifest_sha256 = shared._write_json_exclusive(manifest_path, manifest)
    return {
        "ok": bool(projection["execution_valid"]),
        "execution_valid": bool(projection["execution_valid"]),
        "decision_positive": bool(projection["decision_positive"]),
        "summary_path": str(summary_path),
        "summary_raw_sha256": summary_sha256,
        "manifest_path": str(manifest_path),
        "manifest_raw_sha256": manifest_sha256,
        "prone_to_standing_claimed": False,
    }


def _generic_invalid(error: Exception, *, source_commit: str) -> dict[str, Any]:
    return {
        "schema_version": INVALID_RESULT_SCHEMA,
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "source_commit": source_commit,
        "error_type": type(error).__name__,
        "error": str(error),
        "traceback": traceback.format_exc(),
        "exact_native_collection_refusal_retained": False,
        "invalid_but_retained": True,
        "valid_physical_behavior_result_observed": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    preflight = commands.add_parser("preflight")
    preflight.add_argument("--core-library", type=Path, required=True)
    smoke = commands.add_parser("smoke")
    smoke.add_argument("--core-library", type=Path, required=True)
    smoke.add_argument("--contract", type=Path, required=True)
    smoke.add_argument("--output-directory", type=Path, required=True)
    run = commands.add_parser("run")
    run.add_argument("--core-library", type=Path, required=True)
    run.add_argument("--contract", type=Path, required=True)
    run.add_argument("--output-directory", type=Path, required=True)
    run.add_argument("--source-commit", required=True)
    run.add_argument("--qualification-receipt", type=Path, required=True)
    run.add_argument("--operation-lock-receipt", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    if arguments.command == "preflight":
        receipt = run_zero_world_preflight(
            LocomotionCore(arguments.core_library.resolve())
        )
        print(json.dumps(receipt, allow_nan=False, separators=(",", ":"), sort_keys=True))
        return 0
    source_commit = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    try:
        if arguments.command == "smoke":
            completion = run_integration_smoke_v1(
                core_library=arguments.core_library.resolve(),
                contract_path=arguments.contract.resolve(),
                output_directory=arguments.output_directory.resolve(),
            )
        else:
            completion = run_and_publish_v1(
                core_library=arguments.core_library.resolve(),
                contract_path=arguments.contract.resolve(),
                output_directory=arguments.output_directory.resolve(),
                source_commit=str(arguments.source_commit),
                qualification_receipt_path=arguments.qualification_receipt.resolve(),
                operation_lock_receipt_path=arguments.operation_lock_receipt.resolve(),
            )
        print(json.dumps(completion, sort_keys=True))
        return 0 if completion["ok"] else 3
    except runtime.NativeRecoveryCollectionRefusal as error:
        trace = traceback.format_exc()
        output_directory = arguments.output_directory.resolve()
        if arguments.command == "run":
            try:
                invalid = publish_collection_refusal_v1(
                    error,
                    output_directory=output_directory,
                    source_commit=str(arguments.source_commit),
                    contract_path=arguments.contract.resolve(),
                    qualification_receipt_path=arguments.qualification_receipt.resolve(),
                    operation_lock_receipt_path=arguments.operation_lock_receipt.resolve(),
                    traceback_text=trace,
                )
            except Exception as publication_error:
                invalid = _generic_invalid(
                    publication_error,
                    source_commit=source_commit,
                )
                invalid.update(
                    {
                        "original_error_type": type(error).__name__,
                        "original_error": str(error),
                        "original_collector_support_status": error.diagnostic.get(
                            "collector_support_status"
                        ),
                        "original_collector_refusal_reason": error.diagnostic.get(
                            "collector_refusal_reason"
                        ),
                        "refusal_publication_error": str(publication_error),
                    }
                )
                invalid_path = output_directory / "invalid_result.json"
                if output_directory.is_dir() and not invalid_path.exists():
                    shared._write_json_exclusive(invalid_path, invalid)
        else:
            invalid = _generic_invalid(error, source_commit=source_commit)
            invalid.update(
                {
                    "native_collection_refusal": deepcopy(error.diagnostic),
                    "exact_native_collection_refusal_retained": True,
                    "question_class": (
                        "repeatable_development_integration_not_finite_decision"
                    ),
                    "official_physical_identity_consumed": False,
                }
            )
            invalid_path = output_directory / "invalid_result.json"
            if output_directory.is_dir() and not invalid_path.exists():
                shared._write_json_exclusive(invalid_path, invalid)
        print(json.dumps(invalid, sort_keys=True), file=sys.stderr)
        return 2
    except Exception as error:
        invalid = _generic_invalid(error, source_commit=source_commit)
        output_directory = arguments.output_directory.resolve()
        invalid_path = output_directory / "invalid_result.json"
        if output_directory.is_dir() and not invalid_path.exists():
            shared._write_json_exclusive(invalid_path, invalid)
        print(json.dumps(invalid, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
