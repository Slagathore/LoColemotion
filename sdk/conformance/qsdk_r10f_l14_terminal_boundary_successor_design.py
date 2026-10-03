#!/usr/bin/env python3
"""Qualify the narrow L14 design and reproduce its retained-data diagnosis."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import qsdk_r10f_l14_retained_terminal_diagnosis as diagnosis


ROOT = Path(__file__).resolve().parents[2]
DESIGN_PATH = ROOT / "sdk/qsdk_r10f_l14_terminal_boundary_successor_design_v1.json"
DIAGNOSIS_PATH = ROOT / "sdk/qsdk_r10f_l14_retained_terminal_diagnosis_v1.json"
DESIGN_BYTES = 13371
DESIGN_SHA256 = (
    "sha256:ef04ca607078dbd67e2944f5970ba100fd8cbf970539fccc4dabdfd5c2d5691f"
)
DIAGNOSIS_BYTES = 12116
DIAGNOSIS_SHA256 = (
    "sha256:bf9a344dd8d64e4af5f03307821b15c011c8ba9a743f78de5b606114a8626a15"
)
REPAIR_ID = "QSDK-R10F-L14"
MARKER = "QSDK_R10F_L14_TERMINAL_BOUNDARY_SUCCESSOR_DESIGN_PASS "


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError(code)


def exact(value: Any, expected: Any) -> bool:
    """Do not let Python's True == 1 or 240 == 240.0 erase source kinds."""
    if type(value) is not type(expected):
        return False
    if isinstance(value, dict):
        return value.keys() == expected.keys() and all(
            exact(value[k], expected[k]) for k in value
        )
    if isinstance(value, list):
        return len(value) == len(expected) and all(
            exact(a, b) for a, b in zip(value, expected)
        )
    return value == expected


def flags(value: dict[str, Any], expected: dict[str, Any], label: str) -> None:
    for key, required in expected.items():
        require(key in value and exact(value[key], required), f"{label}:{key}")


def validate_design(value: dict[str, Any]) -> None:
    flags(
        value,
        {
            "schema_version": "sporespore_qsdk_r10f_l14_terminal_boundary_successor_design_v1",
            "status": "prospective_zero_world_successor_design_complete_implementation_authorized_physics_blocked",
            "gate_id": "QSDK-R10F",
            "repair_id": REPAIR_ID,
            "parent_repair_id": "QSDK-R10F-L13",
            "authored_parent_commit": "b21beb90ab367e5bd1a74853394a84d9cee01811",
            "ledger_scope": {
                "subsystem": "recovery",
                "engine_scope": "godot_jolt",
                "authority_mode": "retained_evidence_diagnosis_and_prospective_successor_design",
                "question_class": "development",
            },
        },
        "IDENTITY",
    )
    flags(
        value["question_declaration"],
        {
            "scientific_question_changed_from_r10f": False,
            "development_question_declared": True,
            "finite_decision_declared": False,
            "superiority_question_declared": False,
            "equivalence_or_non_inferiority_question_declared": False,
            "population_inference_declared": False,
            "physical_question_declared": False,
            "physical_execution_authorized": False,
            "maximum_world_attempt_count_before_complete_new_authority_graph": 0,
            "maximum_world_build_count_before_complete_new_authority_graph": 0,
            "maximum_solver_step_count_before_complete_new_authority_graph": 0,
        },
        "QUESTION",
    )
    authorities = value["bound_authorities"]
    require(
        [a["role"] for a in authorities]
        == [
            "consumed_l13_physical_closure",
            "closed_retained_terminal_diagnosis",
            "retained_diagnosis_executable",
            "l13_transport_and_host_projection_design",
            "original_r10f_question_and_fixed_behavioral_limits",
        ],
        "AUTHORITY_ROLES",
    )
    require(authorities[0]["raw_sha256"] == diagnosis.CLOSURE_SHA, "PREDECESSOR_DIGEST")
    require(authorities[1]["raw_sha256"] == DIAGNOSIS_SHA256, "DIAGNOSIS_DIGEST")
    for authority in authorities:
        diagnosis.reopen_binding(authority)
    require(len(value["observed_source_bindings"]) == 5, "FROZEN_SOURCE_COUNT")
    for source in value["observed_source_bindings"]:
        blob, length, sha = diagnosis.SOURCE_BINDINGS[source["path"]]
        flags(
            source,
            {
                "source_commit": diagnosis.SOURCE,
                "git_blob_oid": blob,
                "git_blob_byte_length": length,
                "git_blob_raw_sha256": sha,
            },
            "FROZEN_SOURCE",
        )
    require(
        [b["boundary_id"] for b in value["diagnosed_boundaries"]]
        == [
            "initial_partial_contact_cycle",
            "native_terminal_number_kind",
            "interaction_start_receipt_binding",
        ],
        "THREE_BOUNDARIES",
    )
    changes = value["selected_changes"]
    flags(
        changes["walking_evaluator"],
        {
            "successor_path": "sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v2.gd",
            "preserve_v1_bytes": True,
            "versioned_evaluator_semantics_change": True,
            "initial_partial_flight_has_no_invented_liftoff_position": True,
            "no_cross_segment_release_position_or_coordinate_frame_carried": True,
            "initial_and_terminal_four_contact_receipts_remain_strict": True,
            "missing_or_malformed_observed_cycle_source_is_invalid_not_censored": True,
            "open_terminal_flight_is_not_a_completed_cycle": True,
            "expose_initial_partial_flight_and_open_terminal_cycle_bookkeeping": True,
            "all_27_behavioral_receipt_names_and_fixed_threshold_values_preserved": True,
            "source_controller_commands_and_solver_inputs_unchanged": True,
        },
        "WALKING",
    )
    flags(
        changes["terminal_consumer"],
        {
            "booleans_fractional_nonfinite_out_of_range_strings_and_cross_kind_sources_refused": True,
            "keep_original_retained_number_and_all_digest_checks": True,
            "do_not_relax_other_integer_counters": True,
            "emit_named_terminal_predicate_failures": True,
        },
        "TERMINAL",
    )
    flags(
        changes["interaction_consumer"],
        {
            "correct_synthetic_fixture_to_use_production_producer_shape": True,
            "malformed_missing_swapped_or_mismatched_start_receipts_refused": True,
            "native_interaction_producer_and_impulse_unchanged": True,
        },
        "INTERACTION",
    )
    flags(
        changes["failure_retention"],
        {
            "no_success_on_missing_or_incomplete_evaluation": True,
            "no_engine_health_bypass": True,
        },
        "RETENTION",
    )
    require(
        len(value["required_zero_world_coverage"]) == 12
        and all(
            type(item) is str and item for item in value["required_zero_world_coverage"]
        ),
        "COVERAGE",
    )
    flags(
        value["preserved_contract"],
        {
            "controller_policy_descriptor_materials_caps_impulse_and_solver_unchanged": True,
            "numerical_behavior_thresholds_unchanged": True,
            "process_isolated_child_order_unchanged": True,
            "schedule_horizon_seed_partition_and_timeout_unchanged_by_this_implementation_design": True,
            "historical_observed_evaluator_and_result_records_unchanged": True,
            "consumed_identities_may_not_repeat": True,
            "held_out_seeds_remain_sealed": True,
            "r173_three_engine_prone_to_standing_preserved": True,
            "sdk1_m07_satisfied": False,
            "force_aware_recovery": False,
            "support_matrix_changed": False,
            "release_contract_changed": False,
            "sdk1_score": "14/20",
            "full_program_score": "14/25",
        },
        "PRESERVED",
    )
    flags(
        value["authorization_boundary"],
        {
            "implementation_authorized": True,
            "physical_execution_authorized": False,
            "development_route_success_requires_complete_valid_execution_not_behavioral_success": True,
            "no_identity_no_world_and_no_current_physical_permission": True,
            "physical_acceptance_authority": False,
            "release_authority": False,
            "publication_authority": False,
        },
        "AUTHORIZATION",
    )


def audit() -> dict[str, Any]:
    raw = DESIGN_PATH.read_bytes()
    require(
        len(raw) == DESIGN_BYTES and diagnosis.digest(raw) == DESIGN_SHA256,
        "DESIGN_RAW_IDENTITY",
    )
    value = json.loads(raw)
    validate_design(value)
    mutations = [
        (("repair_id",), "QSDK-R10F-L13"),
        (("question_declaration", "physical_execution_authorized"), True),
        (
            (
                "question_declaration",
                "maximum_world_build_count_before_complete_new_authority_graph",
            ),
            1,
        ),
        (
            (
                "question_declaration",
                "maximum_world_build_count_before_complete_new_authority_graph",
            ),
            False,
        ),
        (("question_declaration", "finite_decision_declared"), True),
        (("selected_changes", "walking_evaluator", "preserve_v1_bytes"), False),
        (
            (
                "selected_changes",
                "walking_evaluator",
                "initial_partial_flight_has_no_invented_liftoff_position",
            ),
            False,
        ),
        (
            (
                "selected_changes",
                "walking_evaluator",
                "initial_and_terminal_four_contact_receipts_remain_strict",
            ),
            False,
        ),
        (
            (
                "selected_changes",
                "walking_evaluator",
                "all_27_behavioral_receipt_names_and_fixed_threshold_values_preserved",
            ),
            False,
        ),
        (
            (
                "selected_changes",
                "terminal_consumer",
                "keep_original_retained_number_and_all_digest_checks",
            ),
            False,
        ),
        (
            (
                "selected_changes",
                "terminal_consumer",
                "do_not_relax_other_integer_counters",
            ),
            False,
        ),
        (
            (
                "selected_changes",
                "interaction_consumer",
                "correct_synthetic_fixture_to_use_production_producer_shape",
            ),
            False,
        ),
        (("selected_changes", "failure_retention", "no_engine_health_bypass"), False),
        (("preserved_contract", "numerical_behavior_thresholds_unchanged"), False),
        (("preserved_contract", "consumed_identities_may_not_repeat"), False),
        (("preserved_contract", "sdk1_m07_satisfied"), True),
        (("authorization_boundary", "release_authority"), True),
        (("authorization_boundary", "physical_execution_authorized"), True),
    ]
    rejected = []
    for path, replacement in mutations:
        changed = copy.deepcopy(value)
        target = changed
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = replacement
        try:
            validate_design(changed)
        except ValueError:
            rejected.append(".".join(path))
        else:
            raise ValueError("MUTATION_ACCEPTED:" + ".".join(path))
    retained_raw = DIAGNOSIS_PATH.read_bytes()
    require(
        len(retained_raw) == DIAGNOSIS_BYTES
        and diagnosis.digest(retained_raw) == DIAGNOSIS_SHA256,
        "DIAGNOSIS_RAW_IDENTITY",
    )
    retained = json.loads(retained_raw)
    recomputed = diagnosis.diagnose()
    require(exact(recomputed, retained), "DIAGNOSIS_RECOMPUTATION_OR_NUMBER_KIND")
    return {
        "schema_version": "sporespore_qsdk_r10f_l14_terminal_boundary_successor_design_audit_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_successor_design_audit",
            "question_class": "development",
        },
        "ok": True,
        "design": diagnosis.identity(DESIGN_PATH),
        "retained_diagnosis": diagnosis.identity(DIAGNOSIS_PATH),
        "valid_design_control_count": 1,
        "mutation_rejection_count": len(rejected),
        "rejected_mutations": rejected,
        "retained_diagnosis_recomputed_exact_including_number_kinds": True,
        "retained_file_count": 10,
        "retained_byte_length": 87684710,
        "frozen_git_source_count": 5,
        "isolated_boundary_fault_count": 3,
        "implementation_authorized": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


if __name__ == "__main__":
    print(MARKER + json.dumps(audit(), sort_keys=True))
