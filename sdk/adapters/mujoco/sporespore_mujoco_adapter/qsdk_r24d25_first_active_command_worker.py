"""R24D25 first-active-recovery-command development worker."""

from __future__ import annotations

import argparse
from copy import deepcopy
import json
import math
from pathlib import Path
import sys
import traceback
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import qsdk_r24d18_recovery_development_worker as shared
from .recovery_context_qualification import (
    run_zero_world_preflight as run_inherited_zero_world_preflight,
)
from .recovery_morphology_route import (
    EXPECTED_RECOVERY_DESCRIPTOR_SHA256,
    EXPECTED_RECOVERY_MORPHOLOGY_ID,
    EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
    INITIALIZER_ID,
    ROUTE_ID,
    run_recovery_morphology_route_ghost,
)


CONTRACT_SCHEMA = "sporespore_qsdk_r24d25_first_active_command_contract_v1"
CAMPAIGN_ID = "QSDK-R24D25-MUJOCO-FIRST-ACTIVE-RECOVERY-COMMAND-GHOST"
GATE_ID = "QSDK-R24D25"
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d25_first_active_command_zero_world_receipt_v1"
)
PREFLIGHT_SCHEMA = "sporespore_qsdk_r24d25_first_active_command_preflight_v1"
EXPECTED_CELL_ID = "development_recovery_morphology_nominal"
EXPECTED_SEED = 1129522465
EXPECTED_HORIZON_STEPS = 13
EXPECTED_CONFIRM_STEPS = 12
EXPECTED_FIRST_ACTIVE_INDEX = 12
EXPECTED_PAIRED_ARM_COUNT = 2
EXPECTED_TOTAL_OUTER_STEPS = 26
EXPECTED_TOTAL_NATIVE_SOLVER_STEPS = 130
EXPECTED_OBSERVER_RULE_ID = (
    "mujoco_contact_midpoint_normal_distance_reconstructed_torso_surface_v1"
)
R24D24_CLOSURE_SHA256 = (
    "sha256:835914dc66bcb006dc5d2d0c644f50b69b76d3edb5744ffaa2242d3925ea9c99"
)


class R24D25WorkerError(RuntimeError):
    """Stable fail-closed worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D25WorkerError(code)


def load_contract_v1(path: Path) -> dict[str, Any]:
    contract = shared._load_json(path)
    ledger = contract.get("ledger_scope")
    lineage = contract.get("lineage")
    change = contract.get("controlled_change")
    cell = contract.get("selected_development_cell")
    horizon = contract.get("ghost_horizon")
    held_out = contract.get("held_out_seal")
    _require(contract.get("schema_version") == CONTRACT_SCHEMA, "CONTRACT_SCHEMA")
    _require(contract.get("gate_id") == GATE_ID, "CONTRACT_GATE")
    _require(contract.get("campaign_id") == CAMPAIGN_ID, "CONTRACT_CAMPAIGN")
    _require(contract.get("question_class") == "development", "CONTRACT_QUESTION")
    _require(
        isinstance(ledger, dict)
        and ledger.get("subsystem") == "recovery"
        and ledger.get("engine_scope") == ["mujoco_native"]
        and ledger.get("authority_mode") == "development_ghost"
        and ledger.get("question_class") == "development",
        "CONTRACT_LEDGER",
    )
    _require(
        isinstance(lineage, dict)
        and lineage.get("predecessor_gate_id") == "QSDK-R24D24"
        and lineage.get("predecessor_closure_raw_sha256") == R24D24_CLOSURE_SHA256
        and lineage.get("predecessor_may_rerun") is False,
        "CONTRACT_LINEAGE",
    )
    _require(
        isinstance(change, dict)
        and change.get("route_id") == ROUTE_ID
        and change.get("recovery_morphology_id") == EXPECTED_RECOVERY_MORPHOLOGY_ID
        and change.get("recovery_descriptor_sha256")
        == EXPECTED_RECOVERY_DESCRIPTOR_SHA256
        and change.get("recovery_morphology_spec_sha256")
        == EXPECTED_RECOVERY_MORPHOLOGY_SHA256
        and change.get("contact_observer_rule_id") == EXPECTED_OBSERVER_RULE_ID
        and change.get("production_runtime_changed") is False
        and change.get("controller_changed") is False
        and change.get("behavior_thresholds_changed") is False
        and change.get("margins_changed") is False
        and change.get("held_out_selector_changed") is False,
        "CONTRACT_CHANGE",
    )
    _require(
        isinstance(cell, dict)
        and cell.get("cell_id") == EXPECTED_CELL_ID
        and cell.get("seed") == EXPECTED_SEED
        and cell.get("random_draw_count") == 0,
        "CONTRACT_CELL",
    )
    _require(
        isinstance(horizon, dict)
        and horizon.get("outer_steps_per_arm") == EXPECTED_HORIZON_STEPS
        and horizon.get("entry_prone_confirm_steps") == EXPECTED_CONFIRM_STEPS
        and horizon.get("first_active_native_application_outer_index_zero_based")
        == EXPECTED_FIRST_ACTIVE_INDEX
        and horizon.get("paired_arm_count") == EXPECTED_PAIRED_ARM_COUNT
        and horizon.get("maximum_total_outer_steps") == EXPECTED_TOTAL_OUTER_STEPS
        and horizon.get("maximum_total_native_solver_steps")
        == EXPECTED_TOTAL_NATIVE_SOLVER_STEPS,
        "CONTRACT_HORIZON",
    )
    _require(
        isinstance(held_out, dict)
        and held_out.get("held_out_cell_access_count") == 0
        and held_out.get("held_out_selector_invocation_count") == 0
        and held_out.get("held_out_data_use_permitted") is False,
        "CONTRACT_HELDOUT",
    )
    return contract


def evaluate_command_coverage_facts_v1(facts: Mapping[str, Any]) -> dict[str, bool]:
    expected_confirm = list(range(1, EXPECTED_CONFIRM_STEPS + 1))
    return {
        "horizon_is_shortest_application_horizon": facts.get("horizon_steps")
        == EXPECTED_HORIZON_STEPS,
        "both_arms_complete_exact_prone_confirmation": facts.get(
            "candidate_confirm_counts"
        )
        == expected_confirm
        and facts.get("matched_zero_confirm_counts") == expected_confirm,
        "both_arms_first_transition_after_twelfth_observation": isinstance(
            facts.get("candidate_transition_indices"), list
        )
        and facts["candidate_transition_indices"][:1]
        == [EXPECTED_CONFIRM_STEPS - 1]
        and isinstance(facts.get("matched_zero_transition_indices"), list)
        and facts["matched_zero_transition_indices"][:1]
        == [EXPECTED_CONFIRM_STEPS - 1]
        and facts.get("candidate_transition")
        == ["confirm_prone", "establish_distal_support"]
        and facts.get("matched_zero_transition")
        == ["confirm_prone", "establish_distal_support"],
        "candidate_first_active_application_is_step_thirteen": facts.get(
            "candidate_active_indices"
        )
        == [EXPECTED_FIRST_ACTIVE_INDEX]
        and facts.get("candidate_active_phases") == ["establish_distal_support"],
        "candidate_active_application_is_native_and_nonzero": facts.get(
            "candidate_target_velocity_count"
        )
        == 8
        and int(facts.get("candidate_nonzero_target_velocity_count", 0)) >= 1
        and facts.get("candidate_positive_force_cap_count") == 8
        and facts.get("candidate_applied_impulse_count") == 8
        and int(facts.get("candidate_nonzero_applied_impulse_count", 0)) >= 1
        and facts.get("candidate_observation_zero_command") is False
        and int(facts.get("candidate_observation_nonzero_impulse_count", 0)) >= 1,
        "matched_zero_remains_unactuated": facts.get("matched_zero_active_indices")
        == []
        and facts.get("matched_zero_observations_all_zero_command") is True,
        "first_twelve_samples_preserve_entry_prone": facts.get(
            "candidate_first_twelve_entry_prone"
        )
        is True
        and facts.get("matched_zero_first_twelve_entry_prone") is True,
        "all_steps_respect_recovery_joint_limits": facts.get(
            "candidate_all_joint_limits_respected"
        )
        is True
        and facts.get("matched_zero_all_joint_limits_respected") is True,
    }


def _positive_control_facts() -> dict[str, Any]:
    confirm = list(range(1, EXPECTED_CONFIRM_STEPS + 1))
    return {
        "horizon_steps": EXPECTED_HORIZON_STEPS,
        "candidate_confirm_counts": confirm,
        "matched_zero_confirm_counts": confirm,
        "candidate_transition_indices": [EXPECTED_CONFIRM_STEPS - 1],
        "matched_zero_transition_indices": [EXPECTED_CONFIRM_STEPS - 1],
        "candidate_transition": ["confirm_prone", "establish_distal_support"],
        "matched_zero_transition": ["confirm_prone", "establish_distal_support"],
        "candidate_active_indices": [EXPECTED_FIRST_ACTIVE_INDEX],
        "candidate_active_phases": ["establish_distal_support"],
        "candidate_target_velocity_count": 8,
        "candidate_nonzero_target_velocity_count": 8,
        "candidate_positive_force_cap_count": 8,
        "candidate_applied_impulse_count": 8,
        "candidate_nonzero_applied_impulse_count": 1,
        "candidate_observation_zero_command": False,
        "candidate_observation_nonzero_impulse_count": 1,
        "matched_zero_active_indices": [],
        "matched_zero_observations_all_zero_command": True,
        "candidate_first_twelve_entry_prone": True,
        "matched_zero_first_twelve_entry_prone": True,
        "candidate_all_joint_limits_respected": True,
        "matched_zero_all_joint_limits_respected": True,
    }


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    inherited = run_inherited_zero_world_preflight(core)
    positive = _positive_control_facts()
    _require(all(evaluate_command_coverage_facts_v1(positive).values()), "POSITIVE")
    mutations = {
        "twelve_step_horizon_rejected": ("horizon_steps", 12),
        "missing_candidate_application_rejected": ("candidate_active_indices", []),
        "early_candidate_application_rejected": ("candidate_active_indices", [11]),
        "matched_zero_actuation_rejected": ("matched_zero_active_indices", [12]),
        "zero_native_impulse_rejected": ("candidate_nonzero_applied_impulse_count", 0),
    }
    checks: dict[str, bool] = {}
    for name, (field, replacement) in mutations.items():
        mutated = deepcopy(positive)
        mutated[field] = replacement
        checks[name] = not all(evaluate_command_coverage_facts_v1(mutated).values())
    _require(all(checks.values()), "COMMAND_COVERAGE_MUTATION_ACCEPTED")
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "command_coverage_decision_controls": checks,
            "command_coverage_control_count": len(checks),
            "command_coverage_controls_passed": sum(checks.values()),
            "entry_prone_confirm_steps": EXPECTED_CONFIRM_STEPS,
            "shortest_first_active_application_horizon_steps": EXPECTED_HORIZON_STEPS,
            "first_active_native_application_outer_index_zero_based": EXPECTED_FIRST_ACTIVE_INDEX,
            "inherited_r24d24_control_count": inherited["negative_control_count"],
            "negative_control_count": inherited["negative_control_count"]
            + len(checks),
            "negative_controls_passed": inherited["negative_controls_passed"]
            + sum(checks.values()),
            "core_command_semantics_covered_by_recovery_suite": True,
        }
    )
    return receipt


def _as_list(arm: Mapping[str, Any], key: str) -> list[Any]:
    value = arm.get(key)
    _require(isinstance(value, list), f"RESULT_{key.upper()}")
    return value


def _torso_records(observations: Sequence[Mapping[str, Any]]) -> list[Mapping[str, Any]]:
    records: list[Mapping[str, Any]] = []
    for observation in observations:
        clearances = observation.get("ordered_body_clearance_observations")
        _require(isinstance(clearances, list), "RESULT_CLEARANCES")
        torso = [
            value
            for value in clearances
            if isinstance(value, dict) and value.get("body_id") == "torso"
        ]
        _require(len(torso) == 1, "RESULT_TORSO_CLEARANCE")
        records.append(torso[0])
    return records


def _arm_execution_checks(arm: Mapping[str, Any]) -> dict[str, bool]:
    observations = _as_list(arm, "observations")
    native = _as_list(arm, "native_receipts")
    collectors = _as_list(arm, "collector_receipts")
    steps = _as_list(arm, "portable_step_receipts")
    context = arm.get("portable_recovery_morphology_context")
    trace = arm.get("portable_request_trace")
    mapping = arm.get("native_recovery_morphology_readback")
    initializer = arm.get("initializer_manifest")
    _require(isinstance(context, dict), "RESULT_CONTEXT")
    _require(isinstance(trace, dict), "RESULT_REQUEST_TRACE")
    _require(isinstance(mapping, dict), "RESULT_MAPPING")
    _require(isinstance(initializer, dict), "RESULT_INITIALIZER")
    torso = _torso_records(observations)
    return {
        "trace_lengths_exact": all(
            len(value) == EXPECTED_HORIZON_STEPS
            for value in (observations, native, collectors, steps, torso)
        ),
        "native_counts_exact": arm.get("outer_step_count")
        == EXPECTED_HORIZON_STEPS
        and arm.get("native_solver_step_count") == EXPECTED_HORIZON_STEPS * 5,
        "recovery_context_bound_exact": arm.get("portable_recovery_context_bound")
        is True
        and context.get("recovery_morphology_spec_sha256")
        == EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
        "v2_request_family_exact": trace.get("initialize_request_schema")
        == "sporespore_recovery_initialize_request_v2"
        and trace.get("collection_request_schemas")
        == ["sporespore_recovery_native_collection_request_v2"]
        * EXPECTED_HORIZON_STEPS
        and trace.get("step_request_schemas")
        == ["sporespore_recovery_step_request_v2"] * EXPECTED_HORIZON_STEPS
        and trace.get("control_request_schemas")
        == ["sporespore_recovery_control_request_v2"] * EXPECTED_HORIZON_STEPS,
        "native_route_exact": all(
            isinstance(item, dict)
            and item.get("native_step", {}).get("route_id") == ROUTE_ID
            and item.get("application", {}).get("route_id") == ROUTE_ID
            for item in native
        ),
        "portable_and_collector_receipts_supported": all(
            isinstance(item, dict) and item.get("support_status") == "supported_exact"
            for item in steps
        )
        and all(
            isinstance(item, dict)
            and item.get("support_status") == "supported_exact"
            and item.get("supplied_native_post_step_observation_validated") is True
            for item in collectors
        ),
        "all_external_interventions_zero": all(
            isinstance(item.get("external_interventions"), dict)
            and all(value == 0 for value in item["external_interventions"].values())
            for item in observations
        ),
        "observer_rule_exact": all(
            item.get("classification_rule_id") == EXPECTED_OBSERVER_RULE_ID
            for item in torso
        ),
        "native_mapping_and_initializer_exact": mapping.get("ok") is True
        and mapping.get("recovery_morphology_spec_sha256")
        == EXPECTED_RECOVERY_MORPHOLOGY_SHA256
        and mapping.get("ordered_joint_readback_count") == 8
        and initializer.get("initializer_id") == INITIALIZER_ID
        and initializer.get("recovery_morphology_spec_sha256")
        == EXPECTED_RECOVERY_MORPHOLOGY_SHA256
        and initializer.get("native_joint_position_readback_matches") is True,
    }


def _arm_sequences(arm: Mapping[str, Any]) -> dict[str, Any]:
    observations = _as_list(arm, "observations")
    native = _as_list(arm, "native_receipts")
    steps = _as_list(arm, "portable_step_receipts")
    active_indices = [
        index
        for index, item in enumerate(native)
        if item.get("application", {}).get("no_actuation_requested") is False
    ]
    transitions = [
        index for index, item in enumerate(steps) if item.get("transitioned") is True
    ]
    transition = None
    if EXPECTED_CONFIRM_STEPS - 1 < len(steps):
        item = steps[EXPECTED_CONFIRM_STEPS - 1]
        transition = [item.get("prior_phase"), item.get("next_phase")]
    active_application: Mapping[str, Any] = {}
    active_observation: Mapping[str, Any] = {}
    if len(active_indices) == 1:
        active_application = native[active_indices[0]].get("application", {})
        active_observation = observations[active_indices[0]].get("applied_actuation", {})
    target_velocity = active_application.get("ordered_host_target_velocity_rad_s", [])
    force_caps = active_application.get("ordered_maximum_absolute_force_nm", [])
    impulses = active_application.get("ordered_signed_applied_impulse_nms", [])
    observed_impulses = active_observation.get("ordered_applied_impulses", [])
    first_twelve = steps[:EXPECTED_CONFIRM_STEPS]
    classifications = [item.get("classification", {}) for item in steps]
    return {
        "confirm_counts": [
            item.get("memory", {}).get("prone_confirm_steps_observed")
            for item in first_twelve
        ],
        "transition_indices": transitions,
        "transition": transition,
        "active_indices": active_indices,
        "active_phases": [
            native[index].get("application", {}).get("phase")
            for index in active_indices
        ],
        "target_velocity_count": len(target_velocity),
        "nonzero_target_velocity_count": sum(
            math.isfinite(float(value)) and float(value) != 0.0
            for value in target_velocity
        ),
        "positive_force_cap_count": sum(
            math.isfinite(float(value)) and float(value) > 0.0 for value in force_caps
        ),
        "applied_impulse_count": len(impulses),
        "nonzero_applied_impulse_count": sum(
            math.isfinite(float(value)) and float(value) != 0.0 for value in impulses
        ),
        "active_observation_zero_command": active_observation.get("zero_command"),
        "active_observation_nonzero_impulse_count": sum(
            isinstance(value, dict)
            and math.isfinite(float(value.get("applied_angular_impulse_nms", math.nan)))
            and float(value.get("applied_angular_impulse_nms", 0.0)) != 0.0
            for value in observed_impulses
        ),
        "observations_all_zero_command": all(
            item.get("applied_actuation", {}).get("zero_command") is True
            for item in observations
        ),
        "first_twelve_entry_prone": all(
            item.get("pose_class") == "ventral_prone"
            and item.get("torso_ventral_contact") is True
            and item.get("entry_prone_gate") is True
            for item in (step.get("classification", {}) for step in first_twelve)
        ),
        "all_joint_limits_respected": all(
            item.get("joint_limits_respected") is True for item in classifications
        ),
    }


def compact_projection_v1(full: Mapping[str, Any]) -> dict[str, Any]:
    candidate = full.get("candidate")
    matched = full.get("matched_zero_command")
    evaluation = full.get("evaluation")
    _require(isinstance(candidate, dict), "RESULT_CANDIDATE")
    _require(isinstance(matched, dict), "RESULT_MATCHED_ZERO")
    _require(isinstance(evaluation, dict), "RESULT_EVALUATION")
    candidate_checks = _arm_execution_checks(candidate)
    matched_checks = _arm_execution_checks(matched)
    candidate_sequences = _arm_sequences(candidate)
    matched_sequences = _arm_sequences(matched)
    execution_checks = {
        "recovery_route_id_exact": full.get("route_id") == ROUTE_ID,
        "paired_initializer_identity_matched": full.get("initializer_identity_matched")
        is True,
        "model_world_counts_exact": full.get("model_construction_count") == 2
        and full.get("world_attempt_count") == 2
        and full.get("world_build_count") == 2,
        "outer_and_solver_counts_exact": full.get("outer_step_count")
        == EXPECTED_TOTAL_OUTER_STEPS
        and full.get("native_solver_step_count")
        == EXPECTED_TOTAL_NATIVE_SOLVER_STEPS,
        "candidate_in_run_invariants_pass": all(candidate_checks.values()),
        "matched_zero_in_run_invariants_pass": all(matched_checks.values()),
        "portable_evaluation_v2_supported_valid": full.get(
            "portable_evaluation_request_schema"
        )
        == "sporespore_recovery_evaluation_request_v2"
        and evaluation.get("support_status") == "supported_exact"
        and evaluation.get("physical_development_trace_valid") is True,
        "behavior_and_release_authority_absent": evaluation.get("physical_result")
        is False
        and full.get("prone_to_standing_claimed") is False
        and full.get("physical_acceptance_authority") is False
        and full.get("release_authority") is False,
    }
    facts = {
        "horizon_steps": EXPECTED_HORIZON_STEPS,
        "candidate_confirm_counts": candidate_sequences["confirm_counts"],
        "matched_zero_confirm_counts": matched_sequences["confirm_counts"],
        "candidate_transition_indices": candidate_sequences["transition_indices"],
        "matched_zero_transition_indices": matched_sequences["transition_indices"],
        "candidate_transition": candidate_sequences["transition"],
        "matched_zero_transition": matched_sequences["transition"],
        "candidate_active_indices": candidate_sequences["active_indices"],
        "candidate_active_phases": candidate_sequences["active_phases"],
        "candidate_target_velocity_count": candidate_sequences[
            "target_velocity_count"
        ],
        "candidate_nonzero_target_velocity_count": candidate_sequences[
            "nonzero_target_velocity_count"
        ],
        "candidate_positive_force_cap_count": candidate_sequences[
            "positive_force_cap_count"
        ],
        "candidate_applied_impulse_count": candidate_sequences[
            "applied_impulse_count"
        ],
        "candidate_nonzero_applied_impulse_count": candidate_sequences[
            "nonzero_applied_impulse_count"
        ],
        "candidate_observation_zero_command": candidate_sequences[
            "active_observation_zero_command"
        ],
        "candidate_observation_nonzero_impulse_count": candidate_sequences[
            "active_observation_nonzero_impulse_count"
        ],
        "matched_zero_active_indices": matched_sequences["active_indices"],
        "matched_zero_observations_all_zero_command": matched_sequences[
            "observations_all_zero_command"
        ],
        "candidate_first_twelve_entry_prone": candidate_sequences[
            "first_twelve_entry_prone"
        ],
        "matched_zero_first_twelve_entry_prone": matched_sequences[
            "first_twelve_entry_prone"
        ],
        "candidate_all_joint_limits_respected": candidate_sequences[
            "all_joint_limits_respected"
        ],
        "matched_zero_all_joint_limits_respected": matched_sequences[
            "all_joint_limits_respected"
        ],
    }
    target_checks = evaluate_command_coverage_facts_v1(facts)
    execution_valid = all(execution_checks.values())
    decision_positive = execution_valid and all(target_checks.values())
    return {
        "schema_version": "sporespore_qsdk_r24d25_first_active_command_compact_projection_v1",
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": ["mujoco_native"],
            "authority_mode": "development_ghost",
            "question_class": "development",
        },
        "route_id": ROUTE_ID,
        "cell_id": EXPECTED_CELL_ID,
        "seed": EXPECTED_SEED,
        "horizon_steps_per_arm": EXPECTED_HORIZON_STEPS,
        "candidate": candidate_sequences,
        "matched_zero_command": matched_sequences,
        "execution_checks": execution_checks,
        "target_checks": target_checks,
        "execution_valid": execution_valid,
        "decision_positive": decision_positive,
        "valid_negative_if_decision_not_positive": execution_valid
        and not decision_positive,
        "behavior_success_required": False,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
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
    qualification = shared._load_json(qualification_receipt_path)
    operation_lock = shared._load_json(operation_lock_receipt_path)
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
    result = run_recovery_morphology_route_ghost(
        LocomotionCore(core_library),
        cell=deepcopy(contract["selected_development_cell"]),
        horizon_steps=EXPECTED_HORIZON_STEPS,
    )
    projection = compact_projection_v1(result)
    envelope = {
        "schema_version": "sporespore_qsdk_r24d25_first_active_command_full_result_v1",
        "gate_id": GATE_ID,
        "campaign_id": CAMPAIGN_ID,
        "ledger_scope": deepcopy(contract["ledger_scope"]),
        "source_commit": source_commit,
        "contract_path": contract_path.as_posix(),
        "contract_raw_sha256": shared._sha256_path(contract_path),
        "qualification_receipt_path": str(qualification_receipt_path),
        "qualification_receipt_raw_sha256": shared._sha256_path(
            qualification_receipt_path
        ),
        "operation_lock": operation_lock,
        "result": result,
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
        "schema_version": "sporespore_qsdk_r24d25_first_active_command_manifest_v1",
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


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    preflight = subparsers.add_parser("preflight")
    preflight.add_argument("--core-library", type=Path, required=True)
    run = subparsers.add_parser("run")
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
        print(
            json.dumps(
                run_zero_world_preflight(
                    LocomotionCore(arguments.core_library.resolve())
                ),
                sort_keys=True,
            )
        )
        return 0
    try:
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
    except Exception as error:
        invalid = {
            "schema_version": "sporespore_qsdk_r24d25_first_active_command_invalid_v1",
            "gate_id": GATE_ID,
            "campaign_id": CAMPAIGN_ID,
            "source_commit": str(arguments.source_commit),
            "error_type": type(error).__name__,
            "error": str(error),
            "traceback": traceback.format_exc(),
            "invalid_but_retained": True,
            "held_out_cell_access_count": 0,
            "prone_to_standing_claimed": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }
        output_directory = arguments.output_directory.resolve()
        if output_directory.is_dir():
            invalid_path = output_directory / "invalid_result.json"
            if not invalid_path.exists():
                shared._write_json_exclusive(invalid_path, invalid)
        print(json.dumps(invalid, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
