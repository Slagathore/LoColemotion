#!/usr/bin/env python3
"""Materialize the prospective zero-world R23D71 declaration.

This script creates declaration bytes only. It does not import an engine,
construct a model, open a world, interpret R23D70 behavior, or authorize
physical execution.
"""

from __future__ import annotations

import copy
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
PARENT_COMMIT = "69e1c46c66ef2ec65f6886db7e5cbeda36168163"
PARENT_TREE = "fc73cee9c11744b7a5563e0e7b990873e6427287"
CAMPAIGN_ID = (
    "QSDK-R23D71-SUCCESS-TERMINAL-PROJECTION-REPAIRED-"
    "THREE-ENGINE-TURNING-VALIDATION"
)
GATE_ID = "QSDK-R23D71"
STATUS = (
    "prospective_declaration_complete_compact_success_terminal_projection_"
    "ghost_and_implementation_pending_physical_not_authorized"
)
DECLARATION_PATH = REPO_ROOT / (
    "sdk/turning/r23d71_success_terminal_projection_repaired_"
    "three_engine_turning_preregistration_v1.json"
)
AUDIT_PATH = REPO_ROOT / "tests/test_qsdk_r23d71_preregistration.ps1"
COMPILER_PATH = REPO_ROOT / "sdk/turning/r23d71_seed_fixture_compiler.gd"
R70_DECLARATION_PATH = REPO_ROOT / (
    "sdk/turning/r23d70_trace_retention_receipt_contract_repaired_"
    "three_engine_turning_preregistration_v1.json"
)
R70_CLOSURE_PATH = REPO_ROOT / (
    "sdk/turning/r23d70_trace_retention_receipt_contract_repaired_"
    "three_engine_turning_validation_closure_v1.json"
)
R70_CLOSURE_AUDIT_PATH = REPO_ROOT / "tests/test_qsdk_r23d70_physical_closure.ps1"
PROJECTOR_PATH = REPO_ROOT / "sdk/locomotion_terminal_execution_projection.ps1"


def raw_sha256(path: Path) -> str:
    return f"sha256:{hashlib.sha256(path.read_bytes()).hexdigest()}"


def git(*arguments: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(REPO_ROOT), *arguments],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(f"QSDK-R23D71 DECLARATION MATERIALIZER: {message}")


def main() -> int:
    require(git("rev-parse", "--show-toplevel").replace("\\", "/") == str(REPO_ROOT).replace("\\", "/"), "wrong repository")
    require(git("remote", "get-url", "origin") == "https://github.com/Slagathore/sporespore.git", "wrong origin")
    require(git("rev-parse", "HEAD") == PARENT_COMMIT, "declaration parent changed")
    require(git("rev-parse", "HEAD^{tree}") == PARENT_TREE, "declaration parent tree changed")
    require(git("rev-parse", "origin/main") == PARENT_COMMIT, "declaration parent is not origin/main")

    for path in (
        AUDIT_PATH,
        COMPILER_PATH,
        R70_DECLARATION_PATH,
        R70_CLOSURE_PATH,
        R70_CLOSURE_AUDIT_PATH,
        PROJECTOR_PATH,
    ):
        require(path.is_file(), f"missing authority: {path}")

    require(
        raw_sha256(COMPILER_PATH)
        == "sha256:9a5becd07d86afd553fc5197c06be0e06ab76b3a8757aefed81d413d70922876",
        "seed compiler bytes changed",
    )
    require(
        raw_sha256(R70_DECLARATION_PATH)
        == "sha256:622ad55225d3735aefb8babddf263e16c748decd1a8cf533f4753e8fac7cc6d1",
        "R23D70 declaration bytes changed",
    )
    require(
        raw_sha256(R70_CLOSURE_PATH)
        == "sha256:a67ae88c274360841a77bbb3a36973da78a4cf7e1c82391eee31af4156976b2e",
        "R23D70 closure bytes changed",
    )
    require(
        raw_sha256(R70_CLOSURE_AUDIT_PATH)
        == "sha256:0025953ab00fe1489c01d7c026759c0718e05939f0e076964d39416cc209d6d9",
        "R23D70 closure audit bytes changed",
    )
    require(
        raw_sha256(PROJECTOR_PATH)
        == "sha256:6d167f802c8c2aa804e8444429af5b13ed7c072c4001e0bd9df921b1ab4e8bf6",
        "shared terminal projector bytes changed",
    )

    r70 = json.loads(R70_DECLARATION_PATH.read_text(encoding="utf-8"))
    inherited = copy.deepcopy(r70["inherited_behavior_contract"])
    inherited.update(
        immediate_base_path=str(R70_DECLARATION_PATH.relative_to(REPO_ROOT)).replace("\\", "/"),
        immediate_base_raw_sha256=raw_sha256(R70_DECLARATION_PATH),
    )

    fixture = {
        "campaign_seed": 23191,
        "cohort": "r23d71_unopened_three_engine_held_out_turning",
        "fixture_vertical_clearance_m": 0.0002604132751002908,
        "fixture_yaw_rad": -0.0049262382090091705,
        "gait_phase_offset_ticks": -1,
        "initial_linear_velocity_world_m_s": [
            0.002370542846620083,
            0.0,
            0.0037111244164407253,
        ],
        "initial_torso_angular_velocity_world_rad_s": [
            -0.0003552224952727556,
            -0.0022123241797089577,
            0.00008024764247238636,
        ],
    }
    engines = ["godot_jolt", "rapier_parry", "mujoco"]
    arms = ["reference_zero", "positive_heading", "negative_heading"]
    cell_ids = [
        f"r23d71__{engine}__s23191__{arm}"
        for engine in engines
        for arm in arms
    ]
    forbidden_root_count_keys = [
        "world_attempt_count",
        "world_build_count",
        "world_build_count_exact",
        "world_build_count_lower_bound",
        "world_build_count_upper_bound",
    ]
    producer_population = [
        {
            "engine_id": "godot_jolt",
            "successor_path": "tests/test_sdk_qsdk_r23d71_godot_jolt_worker.gd",
            "successor_function": "_r23d71_terminal",
            "observed_predecessor_path": "tests/test_sdk_qsdk_r23d70_godot_jolt_worker.gd",
            "observed_predecessor_git_blob_oid": "bbfd9505c3b371feeb925b24825d982931ef5e8d",
            "predecessor_physical_shape_observed": True,
        },
        {
            "engine_id": "rapier_parry",
            "successor_path": "sdk/adapters/rapier/src/qsdk_r23d71_turning_route.rs",
            "successor_function": "normalize_terminal",
            "observed_predecessor_path": "sdk/adapters/rapier/src/qsdk_r23d70_turning_route.rs",
            "observed_predecessor_git_blob_oid": "8281e79e7dba2c943e0401744f57d45154c3641d",
            "predecessor_physical_shape_observed": False,
        },
        {
            "engine_id": "mujoco",
            "successor_path": "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d71_turning_route.py",
            "successor_function": "_normalize_success_terminal",
            "observed_predecessor_path": "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d70_turning_route.py",
            "observed_predecessor_git_blob_oid": "7ecfd7ac4a826275a33a4a1c467fc1cffee8243f",
            "predecessor_physical_shape_observed": False,
        },
    ]

    declaration: dict[str, Any] = {
        "schema_version": "sporespore_qsdk_r23d71_success_terminal_projection_repaired_three_engine_turning_preregistration_v1",
        "status": STATUS,
        "declared_utc": "2026-08-26T05:05:47.1373253Z",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "release_gate_id": "QSDK-R23",
        "ledger_scope": {
            "subsystem": "turning",
            "engine_scope": "3e",
            "authority_mode": "prospective_declaration",
            "question_class": "finite_decision",
        },
        "question": (
            "On the prospectively reserved seed-23191 exact-s169 perturbation, "
            "does the unchanged R23D70 intended behavior contract pass the "
            "reference, +0.2 rad, and -0.2 rad heading arms independently in "
            "genuine Godot/Jolt, Rapier/Parry, and MuJoCo physics after an exact "
            "zero-world development population proves that all three native "
            "success-terminal producers emit one unambiguous nested execution "
            "shape accepted by the actual shared terminal projector?"
        ),
        "physical_question_class": "finite_decision",
        "integration_repair_work_class": "development_then_complete_population_equivalence_non_inferiority",
        "not_superiority_work": True,
        "not_physical_equivalence_or_non_inferiority_work": True,
        "declaration_parent": {
            "commit": PARENT_COMMIT,
            "tree_git_oid": PARENT_TREE,
            "clean_pushed_live_equal": True,
        },
        "declaration_materializer": {
            "path": str(Path(__file__).resolve().relative_to(REPO_ROOT)).replace("\\", "/"),
            "raw_sha256": raw_sha256(Path(__file__).resolve()),
        },
        "declaration_audit": {
            "path": str(AUDIT_PATH.relative_to(REPO_ROOT)).replace("\\", "/"),
            "raw_sha256": raw_sha256(AUDIT_PATH),
        },
        "immutable_predecessor": {
            "gate_id": "QSDK-R23D70",
            "closure_path": str(R70_CLOSURE_PATH.relative_to(REPO_ROOT)).replace("\\", "/"),
            "closure_raw_sha256": raw_sha256(R70_CLOSURE_PATH),
            "closure_audit_path": str(R70_CLOSURE_AUDIT_PATH.relative_to(REPO_ROOT)).replace("\\", "/"),
            "closure_audit_raw_sha256": raw_sha256(R70_CLOSURE_AUDIT_PATH),
            "status": "closed_consumed_invalid_incomplete_after_one_native_world_success_terminal_execution_projection_shape_ambiguity",
            "campaign_identity_consumed": True,
            "same_identity_rerun_allowed": False,
            "replacement_or_selective_completion_allowed": False,
            "physical_worker_process_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "complete_native_horizon_count": 1,
            "complete_retained_trace_count": 1,
            "retained_trace_row_count": 2992,
            "execution_valid_cell_count": 0,
            "unopened_cell_count": 8,
            "turning_result_created": False,
        },
        "inherited_behavior_contract": inherited,
        "scientific_distinction_and_change_budget": {
            "fresh_campaign_identity": CAMPAIGN_ID,
            "fresh_seed": 23191,
            "first_candidate_after_consumed_seed": 23191,
            "first_candidate_token_occurrence_count_at_declaration_parent": 0,
            "seed_selection_rule": (
                "First odd positive candidate after consumed seed 23189 whose "
                "exact decimal or grouped identity has zero token-bounded "
                "occurrences at the clean-pushed declaration parent; 23191 is "
                "the first candidate and has zero occurrences."
            ),
            "allowed_behavioral_input_change": "fresh_seed_23191_and_its_purely_compiled_initial_perturbation",
            "allowed_integration_changes": [
                "successor_godot_success_terminal_rebranding_removes_inherited_root_model_and_world_counts_after_canonical_nested_execution_is_present",
                "successor_rapier_success_terminal_rebranding_removes_inherited_root_model_and_world_counts_after_canonical_nested_execution_is_present",
                "successor_mujoco_success_terminal_rebranding_removes_inherited_root_model_and_world_counts_after_canonical_nested_execution_is_present",
                "successor_supervisor_accepts_only_successor_terminal_identities_through_the_unchanged_shared_projector",
            ],
            "forbidden_changes": [
                "physical_command_change",
                "behavior_threshold_change",
                "selector_change",
                "behavior_evaluator_change",
                "controller_change",
                "profile_change",
                "schedule_change",
                "engine_or_arm_population_change",
                "shared_terminal_projector_semantic_change",
                "failure_terminal_root_count_semantic_change",
                "posthoc_r23d70_interpretation_change",
                "r23d70_seed_attempt_trace_or_evidence_reuse",
            ],
        },
        "seed_fixture_compilation": {
            "compiler_path": str(COMPILER_PATH.relative_to(REPO_ROOT)).replace("\\", "/"),
            "compiler_raw_sha256": raw_sha256(COMPILER_PATH),
            "seed": 23191,
            "compiled_initial_perturbation": fixture,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
        },
        "observed_predecessor_integration_population": {
            "complete_observed_population_required": True,
            "sampling_used": False,
            "population_size": 1,
            "items": [
                {
                    "failure_id": "success_terminal_nested_execution_plus_stale_root_execution_counts",
                    "observed_engine_count": 1,
                    "observed_cell_count": 1,
                    "observed_complete_trace_count": 1,
                    "observed_trace_row_count": 2992,
                    "unobserved_engine_count": 2,
                    "unopened_cell_count": 8,
                    "observed_producer_path": "tests/test_sdk_qsdk_r23d70_godot_jolt_worker.gd",
                    "observed_producer_git_blob_oid": "bbfd9505c3b371feeb925b24825d982931ef5e8d",
                    "shared_projector_path": str(PROJECTOR_PATH.relative_to(REPO_ROOT)).replace("\\", "/"),
                    "shared_projector_git_blob_oid": "502317e88272dd928ff8bc6096e852f7b18dcc6a",
                    "observed_success_shape": "nested_execution_attempt_and_build_are_1_while_root_model_attempt_and_build_are_0",
                    "observed_rejection": "TERMINAL_EXECUTION_PROJECTION_SUCCESS_SHAPE_INVALID:sporespore_qsdk_r23d70_engine_cell_report_v1",
                    "required_conformance": "each_successor_native_success_producer_emits_only_nested_execution_counts_and_the_actual_shared_projector_returns_exact_attempt_1_build_1",
                }
            ],
            "conformance_margin": 0,
            "physical_world_count": 0,
        },
        "success_terminal_projection_contract": {
            "producer_population": producer_population,
            "producer_population_size": 3,
            "producer_population_complete": True,
            "shared_projector_path": str(PROJECTOR_PATH.relative_to(REPO_ROOT)).replace("\\", "/"),
            "shared_projector_raw_sha256": raw_sha256(PROJECTOR_PATH),
            "shared_projector_git_blob_oid": "502317e88272dd928ff8bc6096e852f7b18dcc6a",
            "shared_projector_semantic_change_allowed": False,
            "success_execution_object_required": True,
            "success_execution_world_attempt_count": 1,
            "success_execution_world_build_count": 1,
            "success_root_model_construction_count_forbidden": True,
            "forbidden_success_root_count_keys": forbidden_root_count_keys,
            "forbidden_success_root_count_key_count": 5,
            "failure_terminal_root_count_contract_inherited_unchanged": True,
        },
        "compact_success_terminal_projection_ghost": {
            "purpose": (
                "Prove that each exact production success-terminal rebranding "
                "path emits the canonical shape consumed by the actual shared "
                "projector; do not predict physical success."
            ),
            "native_success_producer_count": 3,
            "shared_projector_count": 1,
            "complete_contract_surface_count": 4,
            "synthetic_input_execution_world_attempt_count": 1,
            "synthetic_input_execution_world_build_count": 1,
            "positive_projection_decision_count": 3,
            "positive_requirements": [
                "each_actual_successor_rebranding_function_is_invoked",
                "nested_execution_is_an_object_with_integer_attempt_1_and_build_1",
                "root_model_construction_count_is_absent",
                "all_five_shared_projector_root_count_keys_are_absent",
                "actual_shared_projector_returns_exact_attempt_1_and_build_1",
            ],
            "negative_root_count_mutations": forbidden_root_count_keys,
            "negative_root_count_mutation_count": 5,
            "negative_projection_decision_count": 15,
            "negative_controls_are_direct_contract_mutations_not_campaign_rehearsals": True,
            "full_seeded_world_required": False,
            "behavioral_success_prediction_allowed": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        "frozen_matrix": {
            "campaign_seed": 23191,
            "engine_order": engines,
            "arm_order": arms,
            "arm_heading_offsets_rad": {
                "reference_zero": 0.0,
                "positive_heading": 0.2,
                "negative_heading": -0.2,
            },
            "ordered_cell_ids": cell_ids,
            "declared_cell_count": 9,
            "complete_population_required": True,
            "sampling_used": False,
        },
        "prephysical_requirements": {
            "implementation_content_addressed": False,
            "compact_success_terminal_projection_ghost_passed": False,
            "complete_zero_world_gate_passed": False,
            "complete_nine_cell_production_supervisor_authorization_ghost_passed": False,
            "fresh_clean_pushed_qualification_required": True,
            "separate_exact_source_adoption_required": True,
            "physical_execution_authorized": False,
        },
        "decision_rule": {
            "inherit_exactly_from_base_contract": True,
            "all_nine_cells_must_be_execution_valid_and_pass": True,
            "all_cells_run_regardless_of_intermediate_outcome": True,
            "same_identity_rerun_allowed": False,
            "selective_completion_allowed": False,
            "positive_classification": "valid_complete_positive_exact_seed_23191_three_engine_portable_turning",
            "negative_classification": "valid_complete_negative_exact_seed_23191_three_engine_portable_turning",
            "invalid_or_incomplete_classification": "invalid_or_incomplete_exact_seed_23191_three_engine_portable_turning",
        },
        "threshold_and_population_provenance": {
            "behavior_threshold_origin": "inherited_byte_exact_from_the_r23d70_intended_behavior_contract_and_its_r23d66_root_with_historical_prospective_provenance",
            "integration_conformance_threshold_origin": "exact_r23d70_observed_success_terminal_and_the_complete_three_producer_one_projector_source_population",
            "equivalence_margin": 0,
            "non_inferiority_margin": 0,
            "physical_cohort_size": 9,
            "success_terminal_producer_population_size": 3,
            "shared_projector_population_size": 1,
            "success_terminal_positive_decision_population_size": 3,
            "forbidden_root_count_key_population_size": 5,
            "negative_projection_decision_population_size": 15,
            "population_claim": (
                "This finite complete-population decision can establish only "
                "whether the exact seed-23191, exact-s169 fixture passes all "
                "nine declared cells after all three native success producers "
                "conform to the unchanged shared projector. It cannot estimate "
                "repeatability, robustness, morphology coverage, engine-effect "
                "equality, or a broader population success rate."
            ),
            "adequacy_argument": (
                "R23D70 observed one complete Godot/Jolt horizon and retained "
                "trace before the actual shared projector rejected an ambiguous "
                "success shape. Rapier and MuJoCo remained unopened, so no claim "
                "is made that their physical terminals were observed. The "
                "successor software population nevertheless enumerates all three "
                "distinct native producer implementations because any may be the "
                "next physical success. Each actual producer is fed one synthetic "
                "production-shaped success payload and then the actual unchanged "
                "shared projector must return exact counts 1/1. Re-adding each "
                "of the projector's five forbidden root count keys to each of "
                "the three outputs yields all 15 named negative decisions. This "
                "is complete and zero-margin for the coding seam, while a full "
                "seeded ghost world would test physics rather than additional "
                "success-terminal code. The later physical decision still runs "
                "all three engines by all three arms exactly once."
            ),
        },
        "claims": {
            "declaration_complete": True,
            "integration_conformance_contract_complete": True,
            "implementation_complete": False,
            "compact_success_terminal_projection_ghost_passed": False,
            "complete_zero_world_gate_passed": False,
            "qualification_passed": False,
            "campaign_attestation_adopted": False,
            "physical_execution_authorized": False,
            "physical_campaign_opened": False,
            "turning_claimed": False,
            "q_sdk_r23_satisfied": False,
            "cross_engine_equivalence": False,
            "prone_to_standing": False,
            "release_score_before": "10/25",
            "release_score_after": "10/25",
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
    }

    payload = json.dumps(declaration, indent=2, ensure_ascii=False) + "\n"
    DECLARATION_PATH.write_text(payload, encoding="utf-8", newline="\n")
    print(
        "[turning/3e] MATERIALIZED R23D71 prospective declaration: "
        f"{raw_sha256(DECLARATION_PATH)} models=0 worlds=0 physics=False"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
