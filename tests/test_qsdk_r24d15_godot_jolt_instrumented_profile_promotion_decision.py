#!/usr/bin/env python3
"""Audit the QSDK-R24D15 finite instrumented-profile promotion decision.

The audit is read-only. It binds the immutable R24D2, R24D3, R24D10, R24D11,
and R24D14 authorities, recomputes the complete mechanism-coverage conjunction,
and mutation-tests the claim boundary. It does not launch Godot, construct a
model, open a physics world, or execute a solver step.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[1]
DECISION_REL = (
    "sdk/recovery/"
    "r24d15_godot_jolt_instrumented_profile_promotion_decision_v1.json"
)
DECISION_PATH = ROOT / DECISION_REL
PARENT_COMMIT = "540ad05b0dc2627bedeeb04a21a3d6f2ea11ab6a"
PARENT_TREE = "7e243e9a5c1d5dd4ef65a33b0eaa0bcff2b6f0ef"
PROFILE_ID = "godot_4_7_jolt_sporespore_motor_telemetry_active_step_snapshot_v2"
CONSOLE_SHA = "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
ENGINE_SHA = "sha256:2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
PATCH_SHA = "sha256:9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"


class AuditError(RuntimeError):
    """Stable audit failure."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def exact(value: Any, expected: Any, code: str) -> None:
    require(value == expected, f"{code}:expected={expected!r}:actual={value!r}")


def mapping(value: Any, code: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{code}:mapping_required")
    return value


def sequence(value: Any, code: str) -> list[Any]:
    require(isinstance(value, list), f"{code}:list_required")
    return value


def require_true_fields(record: dict[str, Any], fields: list[str], prefix: str) -> None:
    for field in fields:
        exact(record.get(field), True, f"{prefix}_{field.upper()}")


def require_false_fields(record: dict[str, Any], fields: list[str], prefix: str) -> None:
    for field in fields:
        exact(record.get(field), False, f"{prefix}_{field.upper()}")


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        ["git", *args],
        cwd=ROOT,
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def git_text(*args: str) -> str:
    return git(*args).stdout.decode("utf-8").strip()


def git_bytes(*args: str) -> bytes:
    return git(*args).stdout


def load_json_bytes(path: Path) -> tuple[dict[str, Any], bytes]:
    payload = path.read_bytes()
    parsed = json.loads(payload)
    require(isinstance(parsed, dict), f"JSON_OBJECT_REQUIRED:{path}")
    return parsed, payload


def sha256_bytes(payload: bytes) -> str:
    return f"sha256:{hashlib.sha256(payload).hexdigest()}"


def load_bound_authorities(
    decision: dict[str, Any],
) -> dict[str, dict[str, Any]]:
    expected_roles = [
        "portable_recovery_semantics",
        "instrumented_profile_source_contract",
        "exact_step_characterization_closure",
        "prior_profile_promotion_refusal",
        "braking_mechanism_characterization_closure",
    ]
    bound = sequence(decision.get("bound_authorities"), "BOUND_AUTHORITIES")
    exact([item.get("role") for item in bound], expected_roles, "BOUND_AUTHORITY_ORDER")
    loaded: dict[str, dict[str, Any]] = {}
    for item_value in bound:
        item = mapping(item_value, "BOUND_AUTHORITY_RECORD")
        role = str(item.get("role"))
        relative = str(item.get("path"))
        path = ROOT / relative
        parsed, payload = load_json_bytes(path)
        exact(sha256_bytes(payload), item.get("raw_sha256"), f"BOUND_SHA:{role}")
        exact(len(payload), item.get("byte_length"), f"BOUND_BYTES:{role}")
        exact(git_text("hash-object", relative), item.get("git_blob_oid"), f"BOUND_BLOB:{role}")
        exact(git_bytes("show", f"{PARENT_COMMIT}:{relative}"), payload, f"PARENT_BYTES:{role}")
        loaded[role] = {"record": item, "json": parsed}
    return loaded


def braking_witness_counts(closure: dict[str, Any]) -> tuple[int, int]:
    cells = sequence(closure.get("cell_observation_summary"), "R24D14_CELLS")
    exact(
        [cell.get("cell_id") for cell in cells],
        ["brake_positive", "brake_negative", "disabled_positive", "disabled_negative"],
        "R24D14_CELL_ORDER",
    )
    enabled = 0
    disabled = 0
    for cell_value in cells:
        cell = mapping(cell_value, "R24D14_CELL")
        cell_id = str(cell["cell_id"])
        pre_rate = float(cell["pre_canonical_relative_rate_rad_s"])
        impulse = float(cell["signed_motor_impulse_nms"])
        positive_work = float(cell["positive_motor_work_j"])
        absorbed_work = float(cell["absorbed_motor_work_j"])
        net_work = float(cell["net_motor_work_j"])
        if bool(cell["motor_enabled"]):
            opposing = (pre_rate > 0.0 and impulse < 0.0) or (
                pre_rate < 0.0 and impulse > 0.0
            )
            require(pre_rate != 0.0, f"R24D14_ENABLED_PRE_RATE_ZERO:{cell_id}")
            require(opposing, f"R24D14_ENABLED_IMPULSE_NOT_OPPOSING:{cell_id}")
            require(positive_work == 0.0, f"R24D14_ENABLED_POSITIVE_WORK:{cell_id}")
            require(absorbed_work > 0.0, f"R24D14_ENABLED_ABSORBED_WORK:{cell_id}")
            require(net_work < 0.0, f"R24D14_ENABLED_NET_WORK:{cell_id}")
            require(bool(cell["mechanism_witness"]), f"R24D14_ENABLED_WITNESS:{cell_id}")
            enabled += 1
        else:
            require(pre_rate != 0.0, f"R24D14_DISABLED_PRE_RATE_ZERO:{cell_id}")
            exact(impulse, 0.0, f"R24D14_DISABLED_IMPULSE:{cell_id}")
            exact(positive_work, 0.0, f"R24D14_DISABLED_POSITIVE_WORK:{cell_id}")
            exact(absorbed_work, 0.0, f"R24D14_DISABLED_ABSORBED_WORK:{cell_id}")
            exact(net_work, 0.0, f"R24D14_DISABLED_NET_WORK:{cell_id}")
            require(bool(cell["mechanism_witness"]), f"R24D14_DISABLED_WITNESS:{cell_id}")
            disabled += 1
    return enabled, disabled


def validate_authorities(authorities: dict[str, dict[str, Any]]) -> None:
    r24d2 = authorities["portable_recovery_semantics"]["json"]
    conjunction = mapping(r24d2.get("native_capability_conjunction"), "R24D2_CONJUNCTION")
    exact(conjunction.get("required_engine_count"), 3, "R24D2_ENGINE_COUNT")
    exact(conjunction.get("required_channel_count_per_engine"), 10, "R24D2_CHANNEL_COUNT")
    exact(conjunction.get("complete"), False, "R24D2_COMPLETE")
    exact(conjunction.get("blocking_engine"), "godot_jolt4_7", "R24D2_BLOCKING_ENGINE")
    exact(
        conjunction.get("blocking_channels"),
        ["applied_actuation_receipts", "energy_balance_ledger"],
        "R24D2_BLOCKING_CHANNELS",
    )
    adapters = mapping(r24d2.get("adapter_capabilities"), "R24D2_ADAPTERS")
    godot = mapping(adapters.get("godot_jolt4_7"), "R24D2_GODOT")
    exact(godot.get("supported_channel_count"), 8, "R24D2_GODOT_SUPPORTED")
    exact(godot.get("unsupported_channel_count"), 2, "R24D2_GODOT_UNSUPPORTED")
    exact(godot.get("solved_hinge_motor_impulse_public_api_reachable"), False, "R24D2_STOCK_IMPULSE")
    exact(godot.get("solved_actuator_work_public_api_reachable"), False, "R24D2_STOCK_WORK")

    r24d3 = authorities["instrumented_profile_source_contract"]["json"]
    expected_requirements = [
        "canonical_to_host_to_jolt_sign",
        "signed_impulse_against_independent_angular_momentum_change",
        "torque_cap_times_step_bound",
        "positive_and_absorbed_work_against_independent_kinetic_energy change",
        "limit_active separation",
        "motor-disabled zero",
        "invalid timing and invalid RID refusal",
        "sequence freshness and sleeping-stale detection",
    ]
    exact(
        r24d3["next_permitted_work"]["required_characterizations"],
        expected_requirements,
        "R24D3_REQUIREMENTS",
    )
    exact(r24d3["claims"]["instrumented_godot_capability_promoted"], False, "R24D3_PROMOTION")
    exact(r24d3["claims"]["native_measurement_accuracy_claimed"], False, "R24D3_ACCURACY")

    r24d10 = authorities["exact_step_characterization_closure"]["json"]
    exact(r24d10["runtime"]["profile_id"], PROFILE_ID, "R24D10_PROFILE")
    exact(r24d10["runtime"]["executed_console_binary_raw_sha256"], CONSOLE_SHA, "R24D10_CONSOLE")
    exact(r24d10["runtime"]["executed_engine_binary_raw_sha256"], ENGINE_SHA, "R24D10_ENGINE")
    exact(r24d10["runtime"]["physics_engine"], "Jolt Physics", "R24D10_PHYSICS")
    exact(r24d10["physical_attempt"]["world_attempt_count"], 1, "R24D10_WORLDS")
    exact(r24d10["physical_attempt"]["world_build_count"], 1, "R24D10_BUILDS")
    exact(r24d10["physical_attempt"]["solver_step_count"], 20, "R24D10_STEPS")
    exact(r24d10["physical_attempt"]["retained_sample_count"], 68, "R24D10_SAMPLES")
    exact(r24d10["descriptive_summary"]["within_source_derived_hard_cap_count"], 65, "R24D10_CAP_PASS")
    exact(r24d10["claims"]["valid_finite_descriptive_development_result"], True, "R24D10_VALID")
    exact(r24d10["claims"]["native_numerical_telemetry_characterized_for_exact_fixture"], True, "R24D10_CHARACTERIZED")
    exact(r24d10["claims"]["numerical_accuracy_accepted"], False, "R24D10_ACCURACY")
    exact(r24d10["claims"]["instrumented_profile_promoted"], False, "R24D10_PROMOTION")

    r24d11 = authorities["prior_profile_promotion_refusal"]["json"]
    exact(r24d11["question_class"], "finite_decision", "R24D11_CLASS")
    exact(
        r24d11["status"],
        "complete_finite_decision_instrumented_profile_promotion_refused_missing_absorbed_motor_work_witness",
        "R24D11_STATUS",
    )
    prior_coverage = mapping(r24d11.get("mechanism_coverage_decision"), "R24D11_COVERAGE")
    require_true_fields(
        prior_coverage,
        [
            "signed_drive_impulse_observed",
            "positive_motor_work_observed",
            "source_derived_hard_cap_observed",
            "motor_disabled_zero_observed",
            "limit_active_motor_and_constraint_separation_observed",
            "invalid_timing_and_invalid_rid_refusal_observed",
            "current_and_sleeping_stale_semantics_observed",
        ],
        "R24D11_COVERAGE",
    )
    require_false_fields(
        prior_coverage,
        [
            "signed_absorbed_motor_work_observed",
            "motor_enabled_braking_distinguished_from_paired_disabled_cells",
            "all_previously_declared_r24d3_mechanism_requirements_observed",
        ],
        "R24D11_COVERAGE",
    )
    exact(r24d11["decision"]["outcome"], "refuse_instrumented_profile_promotion", "R24D11_OUTCOME")
    exact(r24d11["decision"]["instrumented_profile_promoted"], False, "R24D11_PROMOTION")
    exact(r24d11["next_boundary"]["work"], "distinct_minimal_native_braking_mechanism_activation_characterization", "R24D11_NEXT")
    exact(r24d11["decision_rule_provenance"]["source_requirement_declared_before_r24d10_result"], True, "R24D11_RULE_TIMING")

    r24d14 = authorities["braking_mechanism_characterization_closure"]["json"]
    exact(r24d14["question_class"], "development", "R24D14_CLASS")
    exact(
        r24d14["status"],
        "closed_complete_valid_finite_native_braking_mechanism_activation_positive_profile_promotion_decision_next",
        "R24D14_STATUS",
    )
    exact(r24d14["runtime"]["profile_id"], PROFILE_ID, "R24D14_PROFILE")
    exact(r24d14["runtime"]["godot_source_commit"], "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88", "R24D14_SOURCE")
    exact(r24d14["runtime"]["combined_patch_raw_sha256"], PATCH_SHA, "R24D14_PATCH")
    exact(r24d14["runtime"]["executed_console_binary_raw_sha256"], CONSOLE_SHA, "R24D14_CONSOLE")
    exact(r24d14["runtime"]["executed_engine_binary_raw_sha256"], ENGINE_SHA, "R24D14_ENGINE")
    exact(r24d14["runtime"]["physics_engine"], "Jolt Physics", "R24D14_PHYSICS")
    exact(r24d14["physical_attempt"]["world_attempt_count"], 1, "R24D14_WORLDS")
    exact(r24d14["physical_attempt"]["world_build_count"], 1, "R24D14_BUILDS")
    exact(r24d14["physical_attempt"]["solver_step_count"], 1, "R24D14_STEPS")
    exact(r24d14["physical_attempt"]["retained_sample_count"], 4, "R24D14_SAMPLES")
    exact(braking_witness_counts(r24d14), (2, 2), "R24D14_RECOMPUTED_WITNESSES")
    exact(r24d14["claims"]["accepted_physical_characterization"], True, "R24D14_ACCEPTED")
    exact(r24d14["claims"]["native_braking_mechanism_activation_observed"], True, "R24D14_ACTIVATION")
    exact(r24d14["claims"]["numerical_accuracy_accepted"], False, "R24D14_ACCURACY")
    exact(r24d14["claims"]["instrumented_profile_promoted"], False, "R24D14_PROMOTION")
    exact(r24d14["next_boundary"]["gate_id"], "QSDK-R24D15", "R24D14_NEXT_GATE")
    exact(r24d14["next_boundary"]["question_class"], "finite_decision", "R24D14_NEXT_CLASS")
    exact(r24d14["next_boundary"]["new_physical_execution_required"], False, "R24D14_NEXT_PHYSICS")


def expected_prior_coverage() -> dict[str, Any]:
    return {
        "source_gate": "QSDK-R24D11",
        "complete_r24d10_population_used": True,
        "cell_count": 9,
        "retained_sample_count": 68,
        "signed_drive_impulse_observed": True,
        "positive_motor_work_observed": True,
        "source_derived_hard_cap_observed": True,
        "motor_disabled_zero_observed": True,
        "limit_active_motor_and_constraint_separation_observed": True,
        "invalid_timing_and_invalid_rid_refusal_observed": True,
        "current_and_sleeping_stale_semantics_observed": True,
        "signed_absorbed_motor_work_observed": False,
        "motor_enabled_braking_distinguished_from_paired_disabled_cells": False,
        "instrumented_profile_promotion_refused": True,
    }


def expected_successor_coverage() -> dict[str, Any]:
    return {
        "source_gate": "QSDK-R24D14",
        "complete_r24d14_population_used": True,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "solver_step_count": 1,
        "retained_sample_count": 4,
        "motor_enabled_braking_witness_count": 2,
        "motor_disabled_zero_witness_count": 2,
        "signed_enabled_directions_observed": 2,
        "paired_disabled_directions_observed": 2,
        "native_braking_mechanism_activation_observed": True,
        "numerical_accuracy_accepted": False,
    }


def expected_combined_decision() -> dict[str, Any]:
    return {
        "canonical_to_host_to_jolt_sign_characterized": True,
        "signed_impulse_against_independent_angular_momentum_change_characterized": True,
        "torque_cap_times_step_bound_characterized": True,
        "positive_and_absorbed_work_against_independent_kinetic_energy_change_characterized": True,
        "limit_active_separation_characterized": True,
        "motor_disabled_zero_characterized": True,
        "invalid_timing_and_invalid_rid_refusal_characterized": True,
        "sequence_freshness_and_sleeping_stale_detection_characterized": True,
        "required_characterization_count": 8,
        "satisfied_characterization_count": 8,
        "all_previously_declared_r24d3_mechanism_requirements_observed": True,
        "combination_used_only_for_mechanism_coverage": True,
        "combined_fixtures_reinterpreted_as_one_population": False,
        "descriptive_residuals_used_as_acceptance_thresholds": False,
    }


def validate_decision(
    decision: dict[str, Any], authorities: dict[str, dict[str, Any]]
) -> None:
    exact(
        decision.get("schema_version"),
        "sporespore_qsdk_r24d15_godot_jolt_instrumented_profile_promotion_decision_v1",
        "SCHEMA",
    )
    exact(decision.get("decision_id"), "QSDK-R24D15-PROFILE-PROMOTION-DECISION", "DECISION_ID")
    exact(decision.get("gate_id"), "QSDK-R24D15", "GATE_ID")
    exact(decision.get("question_class"), "finite_decision", "QUESTION_CLASS")
    exact(
        decision.get("status"),
        "complete_finite_decision_exact_instrumented_profile_promoted_mapping_implementation_next",
        "STATUS",
    )

    source = mapping(decision.get("source_boundary"), "SOURCE_BOUNDARY")
    exact(source.get("decision_parent_commit"), PARENT_COMMIT, "PARENT_COMMIT")
    exact(source.get("decision_parent_tree_git_oid"), PARENT_TREE, "PARENT_TREE")
    require_false_fields(
        source,
        [
            "historical_r24d10_result_rewritten",
            "historical_r24d11_decision_rewritten",
            "historical_r24d14_result_rewritten",
            "observed_threshold_rewritten",
            "observed_selector_rewritten",
            "observed_evaluator_rewritten",
            "observed_result_reinterpreted_as_numerical_accuracy",
            "same_source_physical_rerun_permitted",
        ],
        "SOURCE",
    )
    exact(
        decision.get("bound_authorities"),
        [
            authorities[role]["record"]
            for role in (
                "portable_recovery_semantics",
                "instrumented_profile_source_contract",
                "exact_step_characterization_closure",
                "prior_profile_promotion_refusal",
                "braking_mechanism_characterization_closure",
            )
        ],
        "BOUND_AUTHORITIES",
    )

    expected_runtime = {
        "profile_id": PROFILE_ID,
        "godot_source_commit": "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88",
        "combined_patch_raw_sha256": PATCH_SHA,
        "executed_console_binary_raw_sha256": CONSOLE_SHA,
        "executed_console_binary_byte_length": 293376,
        "executed_engine_binary_raw_sha256": ENGINE_SHA,
        "executed_engine_binary_byte_length": 188829184,
        "physics_engine": "Jolt Physics",
        "r24d10_profile_identity_matches": True,
        "r24d14_profile_identity_matches": True,
        "executed_binary_pair_matches": True,
        "combined_evidence_crosses_runtime_profiles": False,
        "stock_godot_substitution_permitted": False,
    }
    exact(decision.get("runtime_identity_conjunction"), expected_runtime, "RUNTIME_IDENTITY")
    exact(decision.get("prior_mechanism_coverage"), expected_prior_coverage(), "PRIOR_COVERAGE")
    exact(decision.get("successor_braking_mechanism_coverage"), expected_successor_coverage(), "SUCCESSOR_COVERAGE")
    exact(decision.get("combined_requirement_decision"), expected_combined_decision(), "COMBINED_COVERAGE")

    provenance = mapping(decision.get("decision_rule_provenance"), "PROVENANCE")
    exact(provenance.get("statistical_test"), False, "PROVENANCE_STATISTICAL")
    exact(provenance.get("empirical_performance_threshold_count"), 0, "PROVENANCE_THRESHOLDS")
    exact(provenance.get("superiority_margin_count"), 0, "PROVENANCE_SUPERIORITY")
    exact(provenance.get("equivalence_or_non_inferiority_margin_count"), 0, "PROVENANCE_EQUIVALENCE")
    exact(provenance.get("held_out_validation_cohort_count"), 0, "PROVENANCE_COHORTS")
    exact(provenance.get("population_claim_count"), 0, "PROVENANCE_POPULATION")
    exact(provenance.get("source_requirement_count"), 8, "PROVENANCE_REQUIREMENT_COUNT")
    exact(provenance.get("source_requirement_declared_by_gate"), "QSDK-R24D3", "PROVENANCE_REQUIREMENT_GATE")
    exact(provenance.get("source_requirements_declared_before_both_physical_results"), True, "PROVENANCE_REQUIREMENT_TIMING")
    exact(provenance.get("braking_witness_rule_declared_by_gate"), "QSDK-R24D11", "PROVENANCE_WITNESS_GATE")
    exact(provenance.get("braking_witness_rule_declared_before_r24d14_result"), True, "PROVENANCE_WITNESS_TIMING")
    require("Both signed motor-enabled braking cells" in str(provenance.get("braking_witness_rule")), "PROVENANCE_WITNESS_RULE")
    require("not a repeated or held-out cohort" in str(provenance.get("adequacy_argument")), "PROVENANCE_ADEQUACY")

    outcome = mapping(decision.get("decision"), "DECISION")
    exact(outcome.get("outcome"), "promote_exact_instrumented_profile_for_recovery_capability_mapping", "OUTCOME")
    exact(
        outcome.get("reason_code"),
        "R24D15_ALL_PREDECLARED_MECHANISM_FAMILIES_OBSERVED_ACROSS_IMMUTABLE_EXACT_RUNTIME_RECORDS",
        "REASON_CODE",
    )
    exact(outcome.get("instrumented_profile_id"), PROFILE_ID, "OUTCOME_PROFILE")
    require_true_fields(
        outcome,
        [
            "instrumented_profile_promoted",
            "applied_actuation_receipts_measurement_profile_promoted",
            "energy_balance_ledger_measurement_profile_promoted",
        ],
        "OUTCOME",
    )
    require_false_fields(
        outcome,
        [
            "stock_godot_profile_promoted",
            "numerical_accuracy_accepted",
            "adapter_capability_mapping_implemented",
            "adapter_capability_mapping_qualified",
            "three_engine_native_capability_conjunction_complete",
            "r24d10_result_rethresholded",
            "r24d10_result_reinterpreted",
            "r24d11_refusal_rewritten",
            "r24d14_result_rethresholded",
            "r24d14_result_reinterpreted",
        ],
        "OUTCOME",
    )

    immutability = mapping(decision.get("immutability"), "IMMUTABILITY")
    require_true_fields(
        immutability,
        [
            "r24d10_closure_and_evidence_remain_immutable",
            "r24d11_refusal_remains_the_correct_decision_for_r24d10_alone",
            "r24d14_closure_and_evidence_remain_immutable",
            "r24d10_same_source_rerun_forbidden",
            "r24d14_same_source_rerun_forbidden",
            "this_decision_adds_a_successor_authority_without_rewriting_predecessors",
        ],
        "IMMUTABILITY",
    )

    next_boundary = mapping(decision.get("next_boundary"), "NEXT_BOUNDARY")
    exact(next_boundary.get("gate_id"), "QSDK-R24D16", "NEXT_GATE")
    exact(
        next_boundary.get("work"),
        "profile_scoped_godot_jolt_recovery_capability_mapping_and_zero_world_typed_support_refusal_conformance",
        "NEXT_WORK",
    )
    exact(next_boundary.get("question_class"), "non_physical_source_conformance", "NEXT_CLASS")
    require_true_fields(
        next_boundary,
        [
            "source_mapping_implementation_authorized",
            "complete_zero_world_gate_required",
            "exact_instrumented_runtime_identity_required",
            "stock_runtime_negative_control_required",
        ],
        "NEXT",
    )
    require_false_fields(
        next_boundary,
        [
            "new_physical_execution_required",
            "physical_execution_authorized",
            "recovery_world_authorized",
            "prone_to_standing_world_authorized",
        ],
        "NEXT",
    )

    claims = mapping(decision.get("claims"), "CLAIMS")
    require_true_fields(
        claims,
        [
            "finite_profile_promotion_decision_complete",
            "decision_used_complete_immutable_r24d10_and_r24d14_records",
            "instrumented_profile_promoted",
        ],
        "CLAIM",
    )
    require_false_fields(
        claims,
        [
            "new_physical_world_opened",
            "new_model_constructed",
            "new_solver_step_executed",
            "stock_godot_profile_promoted",
            "numerical_accuracy_accepted",
            "adapter_capability_mapping_implemented",
            "native_capability_conjunction_complete",
            "native_recovery_collector_implemented",
            "recovery_controller_implemented",
            "recovery_world_opened",
            "prone_to_standing_world_opened",
            "turning_claim_changed",
            "cross_engine_equivalence_claimed",
            "q_sdk_r24_satisfied",
            "physical_acceptance_authority",
            "release_authority",
        ],
        "CLAIM",
    )
    exact(claims.get("sdk1_milestone_score_before"), "11/20", "SDK1_SCORE_BEFORE")
    exact(claims.get("sdk1_milestone_score_after"), "11/20", "SDK1_SCORE_AFTER")
    exact(claims.get("full_program_score_before"), "11/25", "PROGRAM_SCORE_BEFORE")
    exact(claims.get("full_program_score_after"), "11/25", "PROGRAM_SCORE_AFTER")
    exact(
        decision.get("decision_audit_path"),
        "tests/test_qsdk_r24d15_godot_jolt_instrumented_profile_promotion_decision.py",
        "AUDIT_PATH",
    )

    # The outcome must remain a pure consequence of the immutable authorities.
    r24d11 = authorities["prior_profile_promotion_refusal"]["json"]
    r24d14 = authorities["braking_mechanism_characterization_closure"]["json"]
    prior = r24d11["mechanism_coverage_decision"]
    exact(
        all(
            prior[field] is True
            for field in (
                "signed_drive_impulse_observed",
                "positive_motor_work_observed",
                "source_derived_hard_cap_observed",
                "motor_disabled_zero_observed",
                "limit_active_motor_and_constraint_separation_observed",
                "invalid_timing_and_invalid_rid_refusal_observed",
                "current_and_sleeping_stale_semantics_observed",
            )
        ),
        True,
        "DERIVED_PRIOR_SEVEN",
    )
    exact(braking_witness_counts(r24d14), (2, 2), "DERIVED_BRAKING_WITNESSES")


def mutation_cases() -> list[tuple[str, Callable[[dict[str, Any]], None]]]:
    return [
        ("question_class", lambda d: d.__setitem__("question_class", "development")),
        ("status", lambda d: d.__setitem__("status", "refused")),
        ("parent_commit", lambda d: d["source_boundary"].__setitem__("decision_parent_commit", "0" * 40)),
        ("rewrite_r24d11", lambda d: d["source_boundary"].__setitem__("historical_r24d11_decision_rewritten", True)),
        ("same_source_rerun", lambda d: d["source_boundary"].__setitem__("same_source_physical_rerun_permitted", True)),
        ("authority_sha", lambda d: d["bound_authorities"][0].__setitem__("raw_sha256", "sha256:" + "0" * 64)),
        ("runtime_profile", lambda d: d["runtime_identity_conjunction"].__setitem__("profile_id", "stock")),
        ("runtime_binary", lambda d: d["runtime_identity_conjunction"].__setitem__("executed_engine_binary_raw_sha256", "sha256:" + "0" * 64)),
        ("runtime_cross_profile", lambda d: d["runtime_identity_conjunction"].__setitem__("combined_evidence_crosses_runtime_profiles", True)),
        ("prior_drive", lambda d: d["prior_mechanism_coverage"].__setitem__("signed_drive_impulse_observed", False)),
        ("successor_enabled_count", lambda d: d["successor_braking_mechanism_coverage"].__setitem__("motor_enabled_braking_witness_count", 1)),
        ("successor_accuracy", lambda d: d["successor_braking_mechanism_coverage"].__setitem__("numerical_accuracy_accepted", True)),
        ("combined_absorbed", lambda d: d["combined_requirement_decision"].__setitem__("positive_and_absorbed_work_against_independent_kinetic_energy_change_characterized", False)),
        ("combined_satisfied_count", lambda d: d["combined_requirement_decision"].__setitem__("satisfied_characterization_count", 7)),
        ("combined_population", lambda d: d["combined_requirement_decision"].__setitem__("combined_fixtures_reinterpreted_as_one_population", True)),
        ("threshold_count", lambda d: d["decision_rule_provenance"].__setitem__("empirical_performance_threshold_count", 1)),
        ("requirement_timing", lambda d: d["decision_rule_provenance"].__setitem__("source_requirements_declared_before_both_physical_results", False)),
        ("witness_timing", lambda d: d["decision_rule_provenance"].__setitem__("braking_witness_rule_declared_before_r24d14_result", False)),
        ("outcome", lambda d: d["decision"].__setitem__("outcome", "refuse_instrumented_profile_promotion")),
        ("instrumented_promotion", lambda d: d["decision"].__setitem__("instrumented_profile_promoted", False)),
        ("stock_promotion", lambda d: d["decision"].__setitem__("stock_godot_profile_promoted", True)),
        ("accuracy", lambda d: d["decision"].__setitem__("numerical_accuracy_accepted", True)),
        ("mapping_implemented", lambda d: d["decision"].__setitem__("adapter_capability_mapping_implemented", True)),
        ("conjunction", lambda d: d["decision"].__setitem__("three_engine_native_capability_conjunction_complete", True)),
        ("r24d11_rewrite", lambda d: d["decision"].__setitem__("r24d11_refusal_rewritten", True)),
        ("immutability", lambda d: d["immutability"].__setitem__("r24d14_closure_and_evidence_remain_immutable", False)),
        ("next_class", lambda d: d["next_boundary"].__setitem__("question_class", "development")),
        ("next_physics", lambda d: d["next_boundary"].__setitem__("physical_execution_authorized", True)),
        ("next_recovery", lambda d: d["next_boundary"].__setitem__("recovery_world_authorized", True)),
        ("claim_mapping", lambda d: d["claims"].__setitem__("adapter_capability_mapping_implemented", True)),
        ("claim_prone", lambda d: d["claims"].__setitem__("prone_to_standing_world_opened", True)),
        ("claim_release", lambda d: d["claims"].__setitem__("release_authority", True)),
        ("score", lambda d: d["claims"].__setitem__("sdk1_milestone_score_after", "12/20")),
    ]


def verify_commit_boundary(
    decision_bytes: bytes, allow_prospective: bool, require_committed: bool
) -> None:
    exact(git_text("rev-parse", f"{PARENT_COMMIT}^{{tree}}"), PARENT_TREE, "PARENT_TREE_GIT")
    require(
        git("merge-base", "--is-ancestor", PARENT_COMMIT, "HEAD", check=False).returncode == 0,
        "PARENT_NOT_ANCESTOR_OF_HEAD",
    )
    if allow_prospective:
        exact(git_text("rev-parse", "HEAD"), PARENT_COMMIT, "PROSPECTIVE_HEAD")
    if require_committed:
        exact(git_bytes("show", f"HEAD:{DECISION_REL}"), decision_bytes, "COMMITTED_DECISION_BYTES")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--allow-prospective-uncommitted", action="store_true")
    parser.add_argument("--require-committed-decision", action="store_true")
    args = parser.parse_args()
    require(
        not (args.allow_prospective_uncommitted and args.require_committed_decision),
        "COMMIT_MODE_CONFLICT",
    )

    exact(Path(git_text("rev-parse", "--show-toplevel")).resolve(), ROOT.resolve(), "ROOT")
    exact(git_text("remote", "get-url", "origin"), "https://github.com/Slagathore/sporespore.git", "REMOTE")
    decision, decision_bytes = load_json_bytes(DECISION_PATH)
    verify_commit_boundary(
        decision_bytes,
        args.allow_prospective_uncommitted,
        args.require_committed_decision,
    )
    authorities = load_bound_authorities(decision)
    validate_authorities(authorities)
    validate_decision(decision, authorities)

    rejected: list[str] = []
    for mutation_id, mutate in mutation_cases():
        candidate = copy.deepcopy(decision)
        mutate(candidate)
        try:
            validate_decision(candidate, authorities)
        except AuditError:
            rejected.append(mutation_id)
        else:
            raise AuditError(f"MUTATION_ACCEPTED:{mutation_id}")
    exact(rejected, [name for name, _ in mutation_cases()], "MUTATION_REJECTION_ORDER")

    print(
        "QSDK_R24D15_PROFILE_PROMOTION_DECISION_PASS "
        f"requirements=8/8 enabled_braking_witnesses=2 disabled_controls=2 "
        f"mutations={len(rejected)} instrumented_profile_promoted=true "
        "stock_profile_promoted=false numerical_accuracy=false "
        "mapping_implemented=false conjunction_complete=false "
        "worlds=0 builds=0 solver_steps=0"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        AuditError,
        KeyError,
        TypeError,
        ValueError,
        OSError,
        subprocess.CalledProcessError,
    ) as error:
        print(f"QSDK_R24D15_PROFILE_PROMOTION_DECISION_FAIL error={error}", file=sys.stderr)
        raise SystemExit(1)
