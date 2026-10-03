#!/usr/bin/env python3
"""Audit the closed QSDK-R24D11 finite profile-promotion decision.

This audit is read-only. It binds the immutable R24D2/R24D3 authorities, the
R24D10 declaration and closures, and the exact retained R24D10 evaluation. It
then recomputes the finite mechanism-coverage decision without constructing a
model, launching Godot, or opening a physics world.
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
DECISION_PATH = ROOT / (
    "sdk/recovery/"
    "r24d11_godot_jolt_instrumented_profile_promotion_decision_v1.json"
)


class AuditError(RuntimeError):
    """Stable audit failure."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def sha256_bytes(payload: bytes) -> str:
    return f"sha256:{hashlib.sha256(payload).hexdigest()}"


def load_json_bytes(path: Path) -> tuple[dict[str, Any], bytes]:
    payload = path.read_bytes()
    parsed = json.loads(payload)
    require(isinstance(parsed, dict), f"JSON_OBJECT_REQUIRED:{path}")
    return parsed, payload


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


def git_object_bytes(commit: str, path: str) -> bytes:
    return git("show", f"{commit}:{path}").stdout


def exact(value: Any, expected: Any, code: str) -> None:
    require(value == expected, f"{code}:expected={expected!r}:actual={value!r}")


def require_false_fields(record: dict[str, Any], fields: list[str], prefix: str) -> None:
    for field in fields:
        exact(record.get(field), False, f"{prefix}_{field.upper()}")


def require_true_fields(record: dict[str, Any], fields: list[str], prefix: str) -> None:
    for field in fields:
        exact(record.get(field), True, f"{prefix}_{field.upper()}")


def cells_by_id(evaluation: dict[str, Any]) -> dict[str, dict[str, Any]]:
    cells = evaluation.get("cells")
    require(isinstance(cells, list), "EVALUATION_CELLS_INVALID")
    result: dict[str, dict[str, Any]] = {}
    for cell in cells:
        require(isinstance(cell, dict), "EVALUATION_CELL_RECORD_INVALID")
        cell_id = cell.get("cell_id")
        require(isinstance(cell_id, str) and cell_id, "EVALUATION_CELL_ID_INVALID")
        require(cell_id not in result, f"EVALUATION_CELL_DUPLICATE:{cell_id}")
        samples = cell.get("samples")
        require(isinstance(samples, list), f"EVALUATION_SAMPLES_INVALID:{cell_id}")
        require(all(isinstance(sample, dict) for sample in samples), f"EVALUATION_SAMPLE_RECORD_INVALID:{cell_id}")
        result[cell_id] = cell
    return result


def compute_observation(evaluation: dict[str, Any]) -> dict[str, Any]:
    ordered_ids = [
        "drive_positive",
        "drive_negative",
        "brake_positive",
        "brake_negative",
        "disabled_positive",
        "disabled_negative",
        "limit_positive",
        "limit_negative",
        "sleep_stale",
    ]
    expected_counts = {
        "drive_positive": 4,
        "drive_negative": 4,
        "brake_positive": 4,
        "brake_negative": 4,
        "disabled_positive": 4,
        "disabled_negative": 4,
        "limit_positive": 20,
        "limit_negative": 20,
        "sleep_stale": 4,
    }
    cells = cells_by_id(evaluation)
    exact(list(cells), ordered_ids, "EVALUATION_CELL_ORDER")
    for cell_id, expected_count in expected_counts.items():
        exact(len(cells[cell_id]["samples"]), expected_count, f"SAMPLE_COUNT_{cell_id}")

    all_samples = [sample for cell in cells.values() for sample in cell["samples"]]
    current = [sample for sample in all_samples if sample.get("numerical_aggregate_included") is True]
    stale = [sample for sample in all_samples if sample.get("numerical_aggregate_included") is False]

    def samples(cell_id: str) -> list[dict[str, Any]]:
        return cells[cell_id]["samples"]

    drive_positive = samples("drive_positive")
    drive_negative = samples("drive_negative")
    brake_positive = samples("brake_positive")
    brake_negative = samples("brake_negative")
    disabled_positive = samples("disabled_positive")
    disabled_negative = samples("disabled_negative")
    limit_positive = samples("limit_positive")
    limit_negative = samples("limit_negative")
    sleep = samples("sleep_stale")

    positive_drive_witnesses = sum(
        sample["signed_motor_impulse_nms"] > 0.0 for sample in drive_positive
    )
    negative_drive_witnesses = sum(
        sample["signed_motor_impulse_nms"] < 0.0 for sample in drive_negative
    )
    positive_work_witnesses = sum(
        sample["positive_motor_work_j"] > 0.0 for sample in current
    )
    brake_positive_absorbed = sum(
        sample["absorbed_motor_work_j"] > 0.0 for sample in brake_positive
    )
    brake_negative_absorbed = sum(
        sample["absorbed_motor_work_j"] > 0.0 for sample in brake_negative
    )
    brake_positive_opposing = sum(
        sample["signed_motor_impulse_nms"] < 0.0 for sample in brake_positive
    )
    brake_negative_opposing = sum(
        sample["signed_motor_impulse_nms"] > 0.0 for sample in brake_negative
    )
    disabled = [*disabled_positive, *disabled_negative]
    disabled_nonzero_impulse = sum(
        sample["signed_motor_impulse_nms"] != 0.0 for sample in disabled
    )
    disabled_nonzero_work = sum(
        any(
            sample[field] != 0.0
            for field in (
                "positive_motor_work_j",
                "absorbed_motor_work_j",
                "net_motor_work_j",
            )
        )
        for sample in disabled
    )
    limit_positive_nonzero = sum(
        sample["signed_motor_impulse_nms"] > 0.0 for sample in limit_positive
    )
    limit_negative_nonzero = sum(
        sample["signed_motor_impulse_nms"] < 0.0 for sample in limit_negative
    )

    telemetry_fields = (
        "signed_motor_impulse_nms",
        "positive_motor_work_j",
        "absorbed_motor_work_j",
        "net_motor_work_j",
    )
    paired_vectors_identical = all(
        [sample[field] for sample in brake_positive]
        == [sample[field] for sample in disabled_positive]
        and [sample[field] for sample in brake_negative]
        == [sample[field] for sample in disabled_negative]
        for field in telemetry_fields
    )

    summary = evaluation.get("summary")
    require(isinstance(summary, dict), "EVALUATION_SUMMARY_INVALID")
    return {
        "cell_ids_in_order": ordered_ids,
        "cell_count": len(cells),
        "retained_sample_count": len(all_samples),
        "current_numerical_sample_count": len(current),
        "sleeping_stale_excluded_sample_count": len(stale),
        "source_derived_hard_cap_observation_count": len(current),
        "within_source_derived_hard_cap_count": sum(
            sample["within_source_derived_hard_solver_cap"] is True
            for sample in current
        ),
        "positive_drive_signed_impulse_witness_count": positive_drive_witnesses,
        "negative_drive_signed_impulse_witness_count": negative_drive_witnesses,
        "positive_motor_work_witness_count": positive_work_witnesses,
        "brake_positive_absorbed_work_witness_count": brake_positive_absorbed,
        "brake_negative_absorbed_work_witness_count": brake_negative_absorbed,
        "brake_positive_nonzero_opposing_motor_impulse_witness_count": brake_positive_opposing,
        "brake_negative_nonzero_opposing_motor_impulse_witness_count": brake_negative_opposing,
        "disabled_nonzero_motor_impulse_count": disabled_nonzero_impulse,
        "disabled_nonzero_motor_work_count": disabled_nonzero_work,
        "limit_positive_nonzero_motor_impulse_count": limit_positive_nonzero,
        "limit_negative_nonzero_motor_impulse_count": limit_negative_nonzero,
        "sleep_current_sample_count": sum(
            sample["snapshot_current"] is True for sample in sleep
        ),
        "sleep_stale_sample_count": sum(
            sample["snapshot_current"] is False for sample in sleep
        ),
        "brake_and_paired_disabled_motor_telemetry_vectors_identical": paired_vectors_identical,
        "maximum_absolute_impulse_residual_nms": summary.get(
            "maximum_absolute_impulse_residual_nms"
        ),
        "maximum_absolute_work_residual_j": summary.get(
            "maximum_absolute_work_residual_j"
        ),
        "descriptive_residuals_used_as_decision_thresholds": False,
    }


def validate_decision(
    decision: dict[str, Any],
    evaluation: dict[str, Any],
    authorities: dict[str, dict[str, Any]],
) -> None:
    exact(
        decision.get("schema_version"),
        "sporespore_qsdk_r24d11_godot_jolt_instrumented_profile_promotion_decision_v1",
        "SCHEMA",
    )
    exact(decision.get("decision_id"), "QSDK-R24D11-PROFILE-PROMOTION-DECISION", "DECISION_ID")
    exact(decision.get("gate_id"), "QSDK-R24D11", "GATE_ID")
    exact(decision.get("question_class"), "finite_decision", "QUESTION_CLASS")
    exact(
        decision.get("status"),
        "complete_finite_decision_instrumented_profile_promotion_refused_missing_absorbed_motor_work_witness",
        "STATUS",
    )

    source = decision.get("source_boundary")
    require(isinstance(source, dict), "SOURCE_BOUNDARY_INVALID")
    exact(source.get("decision_parent_commit"), "5a84c60844c5186084e2d3e4a3f06a79252b8d20", "PARENT_COMMIT")
    exact(source.get("decision_parent_tree_git_oid"), "a8d9d7acd6470a2117e7b07286fe146dd5565dae", "PARENT_TREE")
    require_false_fields(
        source,
        [
            "historical_result_rewritten",
            "observed_threshold_rewritten",
            "observed_selector_rewritten",
            "observed_evaluator_rewritten",
            "observed_result_reinterpreted_as_numerical_accuracy",
            "same_source_physical_rerun_permitted",
        ],
        "SOURCE_BOUNDARY",
    )

    required_authority_roles = [
        "portable_recovery_semantics",
        "instrumented_profile_source_contract",
        "exact_step_characterization_preregistration",
        "exact_step_zero_world_qualification_closure",
        "exact_step_physical_characterization_closure",
    ]
    bound = decision.get("bound_authorities")
    require(isinstance(bound, list), "BOUND_AUTHORITIES_INVALID")
    exact([item.get("role") for item in bound], required_authority_roles, "BOUND_AUTHORITY_ORDER")
    for item in bound:
        role = item["role"]
        authority = authorities.get(role)
        require(isinstance(authority, dict), f"BOUND_AUTHORITY_MISSING:{role}")
        exact(item.get("path"), authority["path"], f"BOUND_PATH:{role}")
        exact(item.get("raw_sha256"), authority["raw_sha256"], f"BOUND_SHA:{role}")
        exact(item.get("byte_length"), authority["byte_length"], f"BOUND_BYTES:{role}")
        exact(item.get("git_blob_oid"), authority["git_blob_oid"], f"BOUND_BLOB:{role}")

    r24d2 = authorities["portable_recovery_semantics"]["json"]
    conjunction = r24d2.get("native_capability_conjunction")
    require(isinstance(conjunction, dict), "R24D2_CONJUNCTION_INVALID")
    exact(conjunction.get("blocking_engine"), "godot_jolt4_7", "R24D2_BLOCKING_ENGINE")
    exact(
        conjunction.get("blocking_channels"),
        ["applied_actuation_receipts", "energy_balance_ledger"],
        "R24D2_BLOCKING_CHANNELS",
    )
    exact(conjunction.get("complete"), False, "R24D2_CONJUNCTION_COMPLETE")

    r24d3 = authorities["instrumented_profile_source_contract"]["json"]
    required_characterizations = r24d3["next_permitted_work"]["required_characterizations"]
    requirement = "positive_and_absorbed_work_against_independent_kinetic_energy change"
    require(requirement in required_characterizations, "R24D3_ABSORBED_WORK_REQUIREMENT_MISSING")
    exact(r24d3["claims"]["instrumented_godot_capability_promoted"], False, "R24D3_PREDECESSOR_PROMOTION")

    r24d10_prereg = authorities["exact_step_characterization_preregistration"]["json"]
    exact(r24d10_prereg["evaluation_contract"]["valid_complete_result_cannot_promote_runtime_profile"], True, "R24D10_PREREG_PROMOTION_BOUNDARY")
    exact(r24d10_prereg["evaluation_contract"]["valid_complete_result_can_authorize_only_a_distinct_profile_promotion_decision_declaration"], True, "R24D10_PREREG_NEXT_DECISION")

    zero_world = authorities["exact_step_zero_world_qualification_closure"]["json"]
    exact(zero_world["claims"]["complete_zero_world_gate_passed"], True, "R24D10_ZERO_WORLD_GATE")
    exact(zero_world["zero_world_worker"]["invalid_rid_refused"], True, "R24D10_INVALID_RID_REFUSAL")
    exact(zero_world["zero_world_worker"]["active_physics_object_count"], 0, "R24D10_ZERO_OBJECT_COUNT")

    physical = authorities["exact_step_physical_characterization_closure"]["json"]
    exact(physical["claims"]["valid_finite_descriptive_development_result"], True, "R24D10_VALID_RESULT")
    exact(physical["claims"]["native_numerical_telemetry_characterized_for_exact_fixture"], True, "R24D10_CHARACTERIZED")
    exact(physical["claims"]["instrumented_profile_promoted"], False, "R24D10_PROFILE_UNPROMOTED")
    exact(physical["next_boundary"]["question_class"], "finite_decision", "R24D10_NEXT_CLASS")
    exact(physical["next_boundary"]["declaration_authorized"], True, "R24D10_DECISION_AUTHORIZED")

    retained = decision.get("retained_evidence")
    require(isinstance(retained, dict), "RETAINED_EVIDENCE_INVALID")
    exact(retained.get("result"), evaluation.get("result"), "EVIDENCE_RESULT")
    exact(retained.get("execution_nonce"), evaluation.get("execution_nonce"), "EVIDENCE_NONCE")
    exact(retained.get("raw_report_canonical_sha256"), evaluation.get("raw_report_canonical_sha256"), "EVIDENCE_CANONICAL_SHA")
    exact(retained.get("execution_valid"), True, "EVIDENCE_EXECUTION_VALID")
    exact(retained.get("world_attempt_count"), 1, "EVIDENCE_ATTEMPT_COUNT")
    exact(retained.get("world_build_count"), 1, "EVIDENCE_BUILD_COUNT")
    exact(retained.get("solver_step_count"), 20, "EVIDENCE_STEP_COUNT")
    exact(retained.get("retained_sample_count"), 68, "EVIDENCE_SAMPLE_COUNT")
    exact(retained.get("same_source_rerun_allowed"), False, "EVIDENCE_RERUN")

    exact(evaluation.get("ok"), True, "EVALUATION_OK")
    exact(evaluation.get("question_class"), "development", "EVALUATION_CLASS")
    exact(evaluation.get("execution_valid"), True, "EVALUATION_VALID")
    exact(evaluation.get("native_numerical_telemetry_characterized"), True, "EVALUATION_CHARACTERIZED")
    require_false_fields(
        evaluation,
        [
            "descriptive_findings_are_acceptance_gates",
            "numerical_accuracy_accepted",
            "instrumented_profile_promoted",
            "recovery_claimed",
            "prone_to_standing_claimed",
            "turning_claim_changed",
            "cross_engine_equivalence_claimed",
            "physical_acceptance_authority",
            "release_authority",
        ],
        "EVALUATION",
    )
    exact(evaluation.get("empirical_acceptance_threshold_count"), 0, "EVALUATION_THRESHOLD_COUNT")
    exact(evaluation.get("superiority_margin_count"), 0, "EVALUATION_SUPERIORITY_COUNT")
    exact(evaluation.get("equivalence_or_non_inferiority_margin_count"), 0, "EVALUATION_EQUIVALENCE_COUNT")
    exact(evaluation.get("held_out_validation_cohort_count"), 0, "EVALUATION_COHORT_COUNT")
    exact(evaluation.get("population_claim_count"), 0, "EVALUATION_POPULATION_COUNT")
    exact(evaluation["exact_step_execution"]["first_retained_space_step_sequence"], 1, "EVALUATION_FIRST_TOKEN")
    exact(evaluation["exact_step_execution"]["last_retained_space_step_sequence"], 20, "EVALUATION_LAST_TOKEN")

    provenance = decision.get("decision_rule_provenance")
    require(isinstance(provenance, dict), "DECISION_PROVENANCE_INVALID")
    exact(provenance.get("statistical_test"), False, "DECISION_STATISTICAL_TEST")
    exact(provenance.get("empirical_performance_threshold_count"), 0, "DECISION_THRESHOLD_COUNT")
    exact(provenance.get("superiority_margin_count"), 0, "DECISION_SUPERIORITY_COUNT")
    exact(provenance.get("equivalence_or_non_inferiority_margin_count"), 0, "DECISION_EQUIVALENCE_COUNT")
    exact(provenance.get("held_out_validation_cohort_count"), 0, "DECISION_COHORT_COUNT")
    exact(provenance.get("population_claim_count"), 0, "DECISION_POPULATION_COUNT")
    exact(provenance.get("source_derived_mechanism_witness_rule_count"), 1, "DECISION_WITNESS_RULE_COUNT")
    exact(provenance.get("source_requirement"), requirement, "DECISION_SOURCE_REQUIREMENT")
    exact(provenance.get("source_requirement_declared_by_gate"), "QSDK-R24D3", "DECISION_SOURCE_GATE")
    exact(provenance.get("source_requirement_declared_before_r24d10_result"), True, "DECISION_REQUIREMENT_TIMING")

    observed = compute_observation(evaluation)
    exact(decision.get("complete_finite_observation"), observed, "RECOMPUTED_FINITE_OBSERVATION")
    exact(observed["positive_drive_signed_impulse_witness_count"], 4, "POSITIVE_DRIVE_WITNESSES")
    exact(observed["negative_drive_signed_impulse_witness_count"], 4, "NEGATIVE_DRIVE_WITNESSES")
    exact(observed["positive_motor_work_witness_count"], 48, "POSITIVE_WORK_WITNESSES")
    exact(observed["brake_positive_absorbed_work_witness_count"], 0, "BRAKE_POSITIVE_ABSORBED")
    exact(observed["brake_negative_absorbed_work_witness_count"], 0, "BRAKE_NEGATIVE_ABSORBED")
    exact(observed["brake_positive_nonzero_opposing_motor_impulse_witness_count"], 0, "BRAKE_POSITIVE_OPPOSING")
    exact(observed["brake_negative_nonzero_opposing_motor_impulse_witness_count"], 0, "BRAKE_NEGATIVE_OPPOSING")
    exact(observed["brake_and_paired_disabled_motor_telemetry_vectors_identical"], True, "BRAKE_DISABLED_IDENTITY")

    coverage = decision.get("mechanism_coverage_decision")
    require(isinstance(coverage, dict), "MECHANISM_COVERAGE_INVALID")
    require_true_fields(
        coverage,
        [
            "signed_drive_impulse_observed",
            "positive_motor_work_observed",
            "source_derived_hard_cap_observed",
            "motor_disabled_zero_observed",
            "limit_active_motor_and_constraint_separation_observed",
            "invalid_timing_and_invalid_rid_refusal_observed",
            "current_and_sleeping_stale_semantics_observed",
        ],
        "COVERAGE",
    )
    require_false_fields(
        coverage,
        [
            "signed_absorbed_motor_work_observed",
            "motor_enabled_braking_distinguished_from_paired_disabled_cells",
            "all_previously_declared_r24d3_mechanism_requirements_observed",
        ],
        "COVERAGE",
    )

    outcome = decision.get("decision")
    require(isinstance(outcome, dict), "DECISION_OUTCOME_INVALID")
    exact(outcome.get("outcome"), "refuse_instrumented_profile_promotion", "DECISION_OUTCOME")
    exact(outcome.get("reason_code"), "R24D11_ABSORBED_MOTOR_WORK_MECHANISM_NOT_OBSERVED", "DECISION_REASON")
    require_false_fields(
        outcome,
        [
            "instrumented_profile_promoted",
            "stock_godot_profile_promoted",
            "applied_actuation_receipts_promoted_for_r24_recovery",
            "energy_balance_ledger_promoted_for_r24_recovery",
            "three_engine_native_capability_conjunction_complete",
            "numerical_accuracy_accepted",
            "r24d10_result_rethresholded",
            "r24d10_result_reinterpreted",
        ],
        "DECISION",
    )

    immutability = decision.get("immutability")
    require(isinstance(immutability, dict), "IMMUTABILITY_INVALID")
    require_true_fields(
        immutability,
        [
            "r24d10_closure_and_evidence_remain_immutable",
            "r24d10_valid_exact_fixture_characterization_preserved",
            "r24d10_same_source_rerun_forbidden",
            "this_decision_does_not_turn_the_valid_result_into_a_negative_physics_result",
            "this_decision_refuses_only_profile_promotion",
        ],
        "IMMUTABILITY",
    )

    next_boundary = decision.get("next_boundary")
    require(isinstance(next_boundary, dict), "NEXT_BOUNDARY_INVALID")
    exact(next_boundary.get("work"), "distinct_minimal_native_braking_mechanism_activation_characterization", "NEXT_WORK")
    exact(next_boundary.get("question_class"), "development", "NEXT_CLASS")
    require_true_fields(
        next_boundary,
        [
            "new_scientific_identity_required",
            "complete_zero_world_gate_required_before_physics",
            "zero_object_production_route_preflight_required",
        ],
        "NEXT",
    )
    require_false_fields(
        next_boundary,
        [
            "same_r24d10_source_rerun_allowed",
            "shortened_physics_ghost_required",
            "physical_execution_authorized_now",
            "recovery_world_authorized_now",
            "prone_to_standing_world_authorized_now",
        ],
        "NEXT",
    )

    claims = decision.get("claims")
    require(isinstance(claims, dict), "CLAIMS_INVALID")
    require_true_fields(
        claims,
        ["finite_profile_promotion_decision_complete", "decision_used_complete_r24d10_population"],
        "CLAIM",
    )
    require_false_fields(
        claims,
        [
            "new_physical_world_opened",
            "new_model_constructed",
            "new_solver_step_executed",
            "instrumented_profile_promoted",
            "stock_godot_profile_promoted",
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
    exact(
        decision.get("decision_audit_path"),
        "tests/test_qsdk_r24d11_godot_jolt_instrumented_profile_promotion_decision.py",
        "AUDIT_PATH",
    )


def mutation_cases() -> list[tuple[str, Callable[[dict[str, Any]], None]]]:
    return [
        ("question_class", lambda d: d.__setitem__("question_class", "development")),
        ("status", lambda d: d.__setitem__("status", "promoted")),
        ("parent_commit", lambda d: d["source_boundary"].__setitem__("decision_parent_commit", "0" * 40)),
        ("historical_rewrite", lambda d: d["source_boundary"].__setitem__("historical_result_rewritten", True)),
        ("same_source_rerun", lambda d: d["source_boundary"].__setitem__("same_source_physical_rerun_permitted", True)),
        ("authority_digest", lambda d: d["bound_authorities"][0].__setitem__("raw_sha256", "sha256:" + "0" * 64)),
        ("threshold_count", lambda d: d["decision_rule_provenance"].__setitem__("empirical_performance_threshold_count", 1)),
        ("source_requirement", lambda d: d["decision_rule_provenance"].__setitem__("source_requirement", "changed")),
        ("absorbed_witness", lambda d: d["complete_finite_observation"].__setitem__("brake_positive_absorbed_work_witness_count", 1)),
        ("paired_vector_identity", lambda d: d["complete_finite_observation"].__setitem__("brake_and_paired_disabled_motor_telemetry_vectors_identical", False)),
        ("coverage_promotion", lambda d: d["mechanism_coverage_decision"].__setitem__("signed_absorbed_motor_work_observed", True)),
        ("outcome", lambda d: d["decision"].__setitem__("outcome", "promote_instrumented_profile")),
        ("instrumented_promotion", lambda d: d["decision"].__setitem__("instrumented_profile_promoted", True)),
        ("stock_promotion", lambda d: d["decision"].__setitem__("stock_godot_profile_promoted", True)),
        ("conjunction", lambda d: d["decision"].__setitem__("three_engine_native_capability_conjunction_complete", True)),
        ("accuracy", lambda d: d["decision"].__setitem__("numerical_accuracy_accepted", True)),
        ("reinterpretation", lambda d: d["decision"].__setitem__("r24d10_result_reinterpreted", True)),
        ("next_class", lambda d: d["next_boundary"].__setitem__("question_class", "finite_decision")),
        ("physical_authority", lambda d: d["next_boundary"].__setitem__("physical_execution_authorized_now", True)),
        ("prone_authority", lambda d: d["next_boundary"].__setitem__("prone_to_standing_world_authorized_now", True)),
        ("release_authority", lambda d: d["claims"].__setitem__("release_authority", True)),
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-committed-decision", action="store_true")
    args = parser.parse_args()

    decision, decision_bytes = load_json_bytes(DECISION_PATH)
    parent = decision["source_boundary"]["decision_parent_commit"]
    exact(git_text("rev-parse", f"{parent}^{{tree}}"), decision["source_boundary"]["decision_parent_tree_git_oid"], "PARENT_TREE_GIT")
    require(git("merge-base", "--is-ancestor", parent, "HEAD", check=False).returncode == 0, "PARENT_NOT_ANCESTOR_OF_HEAD")

    if args.require_committed_decision:
        relative = DECISION_PATH.relative_to(ROOT).as_posix()
        exact(git_object_bytes("HEAD", relative), decision_bytes, "COMMITTED_DECISION_BYTES")

    authorities: dict[str, dict[str, Any]] = {}
    for item in decision["bound_authorities"]:
        path = ROOT / item["path"]
        parsed, payload = load_json_bytes(path)
        exact(sha256_bytes(payload), item["raw_sha256"], f"LIVE_SHA:{item['role']}")
        exact(len(payload), item["byte_length"], f"LIVE_BYTES:{item['role']}")
        exact(git_text("hash-object", item["path"]), item["git_blob_oid"], f"LIVE_BLOB:{item['role']}")
        parent_payload = git_object_bytes(parent, item["path"])
        exact(parent_payload, payload, f"PARENT_BYTES:{item['role']}")
        authorities[item["role"]] = {
            **item,
            "json": parsed,
        }

    evidence = decision["retained_evidence"]
    evaluation_path = Path(evidence["evaluation_path"])
    evaluation, evaluation_bytes = load_json_bytes(evaluation_path)
    exact(sha256_bytes(evaluation_bytes), evidence["evaluation_raw_sha256"], "EVALUATION_RAW_SHA")
    exact(len(evaluation_bytes), evidence["evaluation_byte_length"], "EVALUATION_BYTES")

    validate_decision(decision, evaluation, authorities)

    rejected: list[str] = []
    for mutation_id, apply_mutation in mutation_cases():
        mutated = copy.deepcopy(decision)
        apply_mutation(mutated)
        try:
            validate_decision(mutated, evaluation, authorities)
        except AuditError:
            rejected.append(mutation_id)
        else:
            raise AuditError(f"MUTATION_ACCEPTED:{mutation_id}")

    expected_mutations = [mutation_id for mutation_id, _ in mutation_cases()]
    exact(rejected, expected_mutations, "MUTATION_REJECTION_ORDER")
    print(
        "QSDK_R24D11_PROFILE_PROMOTION_DECISION_AUDIT "
        f"ok=true outcome=refuse_instrumented_profile_promotion "
        f"braking_absorbed_witnesses=0/2 mutation_rejections={len(rejected)} "
        "worlds=0 builds=0 solver_steps=0"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditError, KeyError, TypeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"QSDK_R24D11_PROFILE_PROMOTION_DECISION_AUDIT ok=false error={error}", file=sys.stderr)
        raise SystemExit(1)
