"""R24D27 natural-terminal recovery-controller progression worker.

The production route already stops each arm at the first commissioned recovery
boundary: a portable terminal or the recovery-to-stance handoff.  This worker
changes no controller or physics code.  It gives that existing stop behavior a
finite development decision, validates every retained step, and keeps the
portable full-recovery verdict separate from the narrower progression result.
"""

from __future__ import annotations

import argparse
from copy import deepcopy
import json
from pathlib import Path
import sys
import traceback
from typing import Any, Mapping, Sequence

from sporespore_locomotion import LocomotionCore

from . import qsdk_r24d18_recovery_development_worker as shared
from . import qsdk_r24d26_active_receipt_serialization_worker as predecessor
from .recovery_morphology_route import (
    EXPECTED_RECOVERY_DESCRIPTOR_SHA256,
    EXPECTED_RECOVERY_MORPHOLOGY_ID,
    EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
    INITIALIZER_ID,
    ROUTE_ID,
    run_recovery_morphology_route_ghost,
)


CONTRACT_SCHEMA = (
    "sporespore_qsdk_r24d27_natural_recovery_progression_contract_v1"
)
CAMPAIGN_ID = "QSDK-R24D27-MUJOCO-NATURAL-RECOVERY-PROGRESSION-DEVELOPMENT"
GATE_ID = "QSDK-R24D27"
QUALIFICATION_RECEIPT_SCHEMA = (
    "sporespore_qsdk_r24d27_natural_recovery_progression_zero_world_receipt_v1"
)
PREFLIGHT_SCHEMA = (
    "sporespore_qsdk_r24d27_natural_recovery_progression_preflight_v1"
)
EXPECTED_CELL_ID = predecessor.EXPECTED_CELL_ID
EXPECTED_SEED = predecessor.EXPECTED_SEED
EXPECTED_CONFIRM_STEPS = predecessor.EXPECTED_CONFIRM_STEPS
EXPECTED_PAIRED_ARM_COUNT = predecessor.EXPECTED_PAIRED_ARM_COUNT
EXPECTED_MAXIMUM_HORIZON_STEPS = 1200
EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS = 2400
EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS = 12000
EXPECTED_OBSERVER_RULE_ID = predecessor.EXPECTED_OBSERVER_RULE_ID
EXPECTED_CANDIDATE_TRANSITIONS = [
    ["confirm_prone", "establish_distal_support"],
    ["establish_distal_support", "raise_body"],
    ["raise_body", "stance_handoff"],
]
NATURAL_STOP_PHASES = {"stance_handoff", "complete", "failed", "refused"}
R24D26_CLOSURE_SHA256 = (
    "sha256:d4a101b5f5f70ff14c6366674da594dafa3cb93b841653715cd81d5155aac98e"
)


class R24D27WorkerError(RuntimeError):
    """Stable fail-closed worker error."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R24D27WorkerError(code)


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
        and lineage.get("predecessor_gate_id") == "QSDK-R24D26"
        and lineage.get("predecessor_closure_raw_sha256") == R24D26_CLOSURE_SHA256
        and lineage.get("predecessor_result")
        == "closed_complete_execution_valid_first_active_command_positive_behavior_incomplete"
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
        and change.get("held_out_selector_changed") is False
        and change.get("development_execution_bound_changed") is True,
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
        and horizon.get("outer_steps_per_arm") == EXPECTED_MAXIMUM_HORIZON_STEPS
        and horizon.get("maximum_steps_per_arm")
        == EXPECTED_MAXIMUM_HORIZON_STEPS
        and horizon.get("paired_arm_count") == EXPECTED_PAIRED_ARM_COUNT
        and horizon.get("maximum_total_outer_steps")
        == EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS
        and horizon.get("maximum_total_native_solver_steps")
        == EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS
        and set(horizon.get("existing_route_stop_phases", []))
        == NATURAL_STOP_PHASES,
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


def evaluate_progression_facts_v1(facts: Mapping[str, Any]) -> dict[str, bool]:
    """Evaluate the declared finite progression question without physics."""

    candidate_steps = facts.get("candidate_outer_step_count")
    matched_steps = facts.get("matched_zero_outer_step_count")
    candidate_active = facts.get("candidate_active_application_count")
    candidate_transitions = facts.get("candidate_transition_pairs")
    return {
        "both_arms_stop_within_frozen_maximum": isinstance(candidate_steps, int)
        and isinstance(matched_steps, int)
        and EXPECTED_CONFIRM_STEPS < candidate_steps <= EXPECTED_MAXIMUM_HORIZON_STEPS
        and EXPECTED_CONFIRM_STEPS < matched_steps <= EXPECTED_MAXIMUM_HORIZON_STEPS,
        "candidate_reaches_stance_handoff_without_phase_skip": facts.get(
            "candidate_final_phase"
        )
        == "stance_handoff"
        and facts.get("candidate_terminal_failure_code") is None
        and candidate_transitions == EXPECTED_CANDIDATE_TRANSITIONS,
        "candidate_transition_gates_are_measured_true": facts.get(
            "candidate_distal_support_transition_gate"
        )
        is True
        and facts.get("candidate_handoff_raised_body_gate") is True
        and facts.get("candidate_handoff_safety_gate") is True,
        "candidate_controller_continues_beyond_first_application": isinstance(
            candidate_active, int
        )
        and isinstance(candidate_steps, int)
        and candidate_active == candidate_steps - EXPECTED_CONFIRM_STEPS
        and candidate_active > 1,
        "matched_zero_stops_failed": facts.get("matched_zero_final_phase")
        == "failed"
        and isinstance(facts.get("matched_zero_terminal_failure_code"), str)
        and bool(facts.get("matched_zero_terminal_failure_code")),
        "matched_zero_remains_unactuated": facts.get(
            "matched_zero_active_application_count"
        )
        == 0
        and facts.get("matched_zero_observations_all_zero_command") is True,
    }


def _positive_control_facts() -> dict[str, Any]:
    return {
        "candidate_outer_step_count": EXPECTED_CONFIRM_STEPS + 2,
        "matched_zero_outer_step_count": EXPECTED_CONFIRM_STEPS + 240,
        "candidate_final_phase": "stance_handoff",
        "candidate_terminal_failure_code": None,
        "candidate_transition_pairs": deepcopy(EXPECTED_CANDIDATE_TRANSITIONS),
        "candidate_distal_support_transition_gate": True,
        "candidate_handoff_raised_body_gate": True,
        "candidate_handoff_safety_gate": True,
        "candidate_active_application_count": 2,
        "matched_zero_final_phase": "failed",
        "matched_zero_terminal_failure_code": (
            "phase_timeout:establish_distal_support"
        ),
        "matched_zero_active_application_count": 0,
        "matched_zero_observations_all_zero_command": True,
    }


def run_zero_world_preflight(core: LocomotionCore) -> dict[str, Any]:
    inherited = predecessor.run_zero_world_preflight(core)
    positive = _positive_control_facts()
    _require(all(evaluate_progression_facts_v1(positive).values()), "POSITIVE")
    mutations = {
        "candidate_terminal_failure_rejected": ("candidate_final_phase", "failed"),
        "candidate_phase_skip_rejected": (
            "candidate_transition_pairs",
            [
                ["confirm_prone", "establish_distal_support"],
                ["establish_distal_support", "stance_handoff"],
            ],
        ),
        "unmeasured_handoff_gate_rejected": (
            "candidate_handoff_raised_body_gate",
            False,
        ),
        "first_application_only_rejected": (
            "candidate_active_application_count",
            1,
        ),
        "matched_zero_nonterminal_rejected": (
            "matched_zero_final_phase",
            "establish_distal_support",
        ),
        "matched_zero_actuation_rejected": (
            "matched_zero_active_application_count",
            1,
        ),
    }
    checks: dict[str, bool] = {}
    for name, (field, replacement) in mutations.items():
        mutated = deepcopy(positive)
        mutated[field] = replacement
        checks[name] = not all(evaluate_progression_facts_v1(mutated).values())
    _require(all(checks.values()), "PROGRESSION_MUTATION_ACCEPTED")
    receipt = deepcopy(inherited)
    receipt.update(
        {
            "schema_version": PREFLIGHT_SCHEMA,
            "natural_progression_decision_controls": checks,
            "natural_progression_control_count": len(checks),
            "natural_progression_controls_passed": sum(checks.values()),
            "inherited_r24d26_control_count": inherited["negative_control_count"],
            "negative_control_count": inherited["negative_control_count"]
            + len(checks),
            "negative_controls_passed": inherited["negative_controls_passed"]
            + sum(checks.values()),
            "maximum_horizon_steps_per_arm": EXPECTED_MAXIMUM_HORIZON_STEPS,
            "natural_stop_phases": sorted(NATURAL_STOP_PHASES),
            "production_route_stop_semantics_reused": True,
            "new_behavior_threshold_count": 0,
            "new_margin_count": 0,
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
    count = len(observations)
    torso = _torso_records(observations)
    final_phase = arm.get("final_phase")
    stopped = final_phase in NATURAL_STOP_PHASES
    expected_control_count = count - 1 if stopped else count
    final_memory = steps[-1].get("memory", {}) if steps else {}
    prior_phases = [
        item.get("memory", {}).get("phase") for item in steps[:-1]
    ]
    return {
        "trace_lengths_complete_and_bounded": 0 < count <= EXPECTED_MAXIMUM_HORIZON_STEPS
        and all(len(value) == count for value in (native, collectors, steps, torso)),
        "native_counts_exact": arm.get("outer_step_count") == count
        and arm.get("native_solver_step_count") == count * 5,
        "natural_stop_exact": stopped
        and final_memory.get("phase") == final_phase
        and not any(value in NATURAL_STOP_PHASES for value in prior_phases),
        "recovery_context_bound_exact": arm.get("portable_recovery_context_bound")
        is True
        and context.get("recovery_morphology_spec_sha256")
        == EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
        "v2_request_family_exact": trace.get("initialize_request_schema")
        == "sporespore_recovery_initialize_request_v2"
        and trace.get("collection_request_schemas")
        == ["sporespore_recovery_native_collection_request_v2"] * count
        and trace.get("step_request_schemas")
        == ["sporespore_recovery_step_request_v2"] * count
        and trace.get("control_request_schemas")
        == ["sporespore_recovery_control_request_v2"] * expected_control_count,
        "native_route_and_json_receipts_exact": all(
            isinstance(item, dict)
            and item.get("native_step", {}).get("route_id") == ROUTE_ID
            and item.get("application", {}).get("route_id") == ROUTE_ID
            and len(item.get("application", {}).get("ordered_host_clamped", []))
            == 8
            and all(
                type(value) is bool
                for value in item["application"]["ordered_host_clamped"]
            )
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
        "observer_rule_and_joint_limits_exact": all(
            item.get("classification_rule_id") == EXPECTED_OBSERVER_RULE_ID
            for item in torso
        )
        and all(
            item.get("classification", {}).get("joint_limits_respected") is True
            for item in steps
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
    transitions = [
        {
            "outer_index_zero_based": index,
            "prior_phase": item.get("prior_phase"),
            "next_phase": item.get("next_phase"),
            "classification": deepcopy(item.get("classification", {})),
        }
        for index, item in enumerate(steps)
        if item.get("transitioned") is True
    ]
    active_indices = [
        index
        for index, item in enumerate(native)
        if item.get("application", {}).get("no_actuation_requested") is False
    ]
    final_memory = steps[-1].get("memory", {}) if steps else {}
    return {
        "outer_step_count": len(observations),
        "final_phase": arm.get("final_phase"),
        "terminal_failure_code": final_memory.get("terminal_failure_code"),
        "transition_records": transitions,
        "transition_pairs": [
            [item["prior_phase"], item["next_phase"]] for item in transitions
        ],
        "active_application_count": len(active_indices),
        "first_active_outer_index_zero_based": (
            active_indices[0] if active_indices else None
        ),
        "last_active_outer_index_zero_based": (
            active_indices[-1] if active_indices else None
        ),
        "observations_all_zero_command": all(
            item.get("applied_actuation", {}).get("zero_command") is True
            for item in observations
        ),
        "all_joint_limits_respected": all(
            item.get("classification", {}).get("joint_limits_respected") is True
            for item in steps
        ),
    }


def _transition_classification(
    sequence: Mapping[str, Any], prior_phase: str, next_phase: str
) -> Mapping[str, Any]:
    records = sequence.get("transition_records")
    _require(isinstance(records, list), "RESULT_TRANSITIONS")
    matches = [
        item.get("classification", {})
        for item in records
        if isinstance(item, dict)
        and item.get("prior_phase") == prior_phase
        and item.get("next_phase") == next_phase
    ]
    return matches[0] if len(matches) == 1 and isinstance(matches[0], dict) else {}


def compact_projection_v1(full: Mapping[str, Any]) -> dict[str, Any]:
    candidate = full.get("candidate")
    matched = full.get("matched_zero_command")
    evaluation = full.get("evaluation")
    _require(isinstance(candidate, dict), "RESULT_CANDIDATE")
    _require(isinstance(matched, dict), "RESULT_MATCHED_ZERO")
    _require(isinstance(evaluation, dict), "RESULT_EVALUATION")
    candidate_checks = _arm_execution_checks(candidate)
    matched_checks = _arm_execution_checks(matched)
    candidate_sequence = _arm_sequences(candidate)
    matched_sequence = _arm_sequences(matched)
    distal = _transition_classification(
        candidate_sequence, "establish_distal_support", "raise_body"
    )
    handoff = _transition_classification(
        candidate_sequence, "raise_body", "stance_handoff"
    )
    total_outer = candidate_sequence["outer_step_count"] + matched_sequence[
        "outer_step_count"
    ]
    execution_checks = {
        "recovery_route_id_exact": full.get("route_id") == ROUTE_ID,
        "paired_initializer_identity_matched": full.get(
            "initializer_identity_matched"
        )
        is True,
        "model_world_counts_exact": full.get("model_construction_count") == 2
        and full.get("world_attempt_count") == 2
        and full.get("world_build_count") == 2,
        "outer_and_solver_counts_exact_bounded": full.get("outer_step_count")
        == total_outer
        and total_outer <= EXPECTED_MAXIMUM_TOTAL_OUTER_STEPS
        and full.get("native_solver_step_count") == total_outer * 5
        and full.get("native_solver_step_count")
        <= EXPECTED_MAXIMUM_TOTAL_NATIVE_SOLVER_STEPS,
        "candidate_in_run_invariants_pass": all(candidate_checks.values()),
        "matched_zero_in_run_invariants_pass": all(matched_checks.values()),
        "portable_evaluation_v2_supported_valid": full.get(
            "portable_evaluation_request_schema"
        )
        == "sporespore_recovery_evaluation_request_v2"
        and evaluation.get("support_status") == "supported_exact"
        and evaluation.get("physical_development_trace_valid") is True
        and evaluation.get("candidate_trace", {}).get("final_phase")
        == candidate_sequence["final_phase"]
        and evaluation.get("matched_zero_command_trace", {}).get("final_phase")
        == matched_sequence["final_phase"],
        "full_recovery_and_release_authority_absent": evaluation.get(
            "physical_result"
        )
        is False
        and full.get("prone_to_standing_claimed") is False
        and full.get("physical_acceptance_authority") is False
        and full.get("release_authority") is False,
    }
    facts = {
        "candidate_outer_step_count": candidate_sequence["outer_step_count"],
        "matched_zero_outer_step_count": matched_sequence["outer_step_count"],
        "candidate_final_phase": candidate_sequence["final_phase"],
        "candidate_terminal_failure_code": candidate_sequence[
            "terminal_failure_code"
        ],
        "candidate_transition_pairs": candidate_sequence["transition_pairs"],
        "candidate_distal_support_transition_gate": distal.get(
            "distal_support_gate"
        ),
        "candidate_handoff_raised_body_gate": handoff.get("raised_body_gate"),
        "candidate_handoff_safety_gate": handoff.get("safety_gate"),
        "candidate_active_application_count": candidate_sequence[
            "active_application_count"
        ],
        "matched_zero_final_phase": matched_sequence["final_phase"],
        "matched_zero_terminal_failure_code": matched_sequence[
            "terminal_failure_code"
        ],
        "matched_zero_active_application_count": matched_sequence[
            "active_application_count"
        ],
        "matched_zero_observations_all_zero_command": matched_sequence[
            "observations_all_zero_command"
        ],
    }
    target_checks = evaluate_progression_facts_v1(facts)
    execution_valid = all(execution_checks.values())
    decision_positive = execution_valid and all(target_checks.values())
    return {
        "schema_version": (
            "sporespore_qsdk_r24d27_natural_recovery_progression_"
            "compact_projection_v1"
        ),
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
        "maximum_horizon_steps_per_arm": EXPECTED_MAXIMUM_HORIZON_STEPS,
        "candidate": candidate_sequence,
        "matched_zero_command": matched_sequence,
        "portable_evaluation_verdict": evaluation.get("verdict"),
        "execution_checks": execution_checks,
        "target_facts": facts,
        "target_checks": target_checks,
        "execution_valid": execution_valid,
        "decision_positive": decision_positive,
        "valid_negative_if_decision_not_positive": execution_valid
        and not decision_positive,
        "full_prone_to_standing_success_required": False,
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
        horizon_steps=EXPECTED_MAXIMUM_HORIZON_STEPS,
    )
    projection = compact_projection_v1(result)
    envelope = {
        "schema_version": (
            "sporespore_qsdk_r24d27_natural_recovery_progression_full_result_v1"
        ),
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
        "schema_version": (
            "sporespore_qsdk_r24d27_natural_recovery_progression_manifest_v1"
        ),
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
            "schema_version": (
                "sporespore_qsdk_r24d27_natural_recovery_progression_invalid_v1"
            ),
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
