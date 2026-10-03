#!/usr/bin/env python3
"""Audit the QSDK-R10F continuous passive-recovery design at zero worlds."""

from __future__ import annotations

import copy
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
AUTHORED_PARENT = "21a1019bc170c2f09125896df6b3e0934b217812"
DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10f_continuous_passive_fall_recovery_successor_design_v1.json"
)
EXPECTED_DESIGN_BYTES = 25_621
EXPECTED_DESIGN_SHA256 = (
    "sha256:696cc5ee80002e39968d27c6f21fa97f9309b7f08d3caad2961699ceb7184dfa"
)
PASS_MARKER = "QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_SUCCESSOR_DESIGN_PASS "

EXPECTED_TOP_LEVEL = {
    "schema_version",
    "status",
    "gate_id",
    "parent_gate_id",
    "design_id",
    "authored_parent_commit",
    "authored_local_date",
    "ledger_scope",
    "question_declaration",
    "release_milestone_context",
    "bound_authorities",
    "preserved_predecessor_results",
    "identity_reconciliation",
    "rejected_composition",
    "selected_same_body_route",
    "recovery_epoch_contract",
    "prospective_population",
    "prospective_behavior_contract",
    "implementation_surface",
    "forward_authority_sequence",
    "required_zero_world_controls",
    "claim_boundary",
    "decision",
}

EXPECTED_AUTHORITIES: dict[str, tuple[str, str, int, str]] = {
    "consumed_r10e_l3_finite_negative": (
        "sdk/qsdk_r10e_held_out_finite_decision_physical_closure_v3.json",
        "3fe5fb0b5527c2b950effc3e0e40f1191e3322d6",
        12_565,
        "sha256:f764a112b2a3037506d29cced838901e6346027aac1529e39a89da9028abbded",
    ),
    "three_engine_canonical_prone_to_standing_decision": (
        "sdk/recovery/r24d173_three_engine_canonical_prone_to_standing_decision_v1.json",
        "9a84d2891ffc042537faef325468843e5a499054",
        13_023,
        "sha256:c2d6edf090ab80a55eb8a6996f52984c14c453bf513e9d8d058d81603817425f",
    ),
    "consumed_exact_nominal_godot_recovery_positive": (
        "sdk/recovery/r24d172_godot_jolt_initializer_receipt_retention_recovery_behavior_physical_closure_v1.json",
        "fab6a752688a5ca8cd471ea24f0c8d267f2e741a",
        29_920,
        "sha256:87b0c9497ab4fa91da8d58f9cba1be9ab906a0d2603cedd5b8abc92231f36fe8",
    ),
    "frozen_selected_locomotion_policy": (
        "sdk/balanced_wave_selected_policy.json",
        "0cdb2b41cf062915ad65a757d75a6eee1f3c306d",
        4_935,
        "sha256:8e111aa9a0b3c7182d4bd7021f6652c50e9d678ff95a6d06d5056e94f7e299b6",
    ),
    "finite_selected_policy_morphology_walking_closure": (
        "sdk/qsdk_r05e_exact_finite_morphology_physical_closure_v1.json",
        "090979d8998711c84daef7b07d97c0afb0ff1441",
        49_049,
        "sha256:dac4ac8790cd74d89da0286c36aaf541fbfe7011d2bea66077b941363d47b33e",
    ),
    "bounded_three_engine_turning_closure": (
        "sdk/turning/r23d78_production_route_three_engine_turning_validation_closure_v1.json",
        "59b6a5320efc4a67eb7a0f5d8bf6be8c5776490d",
        103_019,
        "sha256:fb3b2addaa352529b43aee1906877084ef474f4ecdcf5752d54139b7818bd58e",
    ),
    "sdk1_milestone_mapping": (
        "sdk/release/quadruped_sdk1_milestone_mapping_v1.json",
        "abadde74e619ae0a12818c367ab75fe68f6bf135",
        12_351,
        "sha256:bab238448639d90415d0ce4341a78278536fe7561075a92ec408b1674bce63bd",
    ),
    "qualified_recovery_native_world_source": (
        "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
        "c418010d7dd22baf00af8ad6f4cd9f0b870957f0",
        605_131,
        "sha256:c7b84a7fd0c59904e0f9619dfd0fa4ed559d3fd370ad2b54601e4948c3ac751a",
    ),
    "qualified_recovery_native_route_source": (
        "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd",
        "d1e4c5a9e61dac7f1e82643b09d92789dbb77855",
        337_301,
        "sha256:cd76c658ea378930621e1855ebb7705581c98d4791b0e25b4eb2dc60a3d0cf38",
    ),
    "qualified_contiguous_boundary_transport_source": (
        "sdk/adapters/godot/gdscript/recovery_contiguous_boundary_transport_v1.gd",
        "60f99099274ab304de39c4b335f3d6c60f24152c",
        19_902,
        "sha256:8b95f3ca513b3667c6363000ebd2a47b21dde64044687a350fe56b15e1349a84",
    ),
    "qualified_discrete_staging_route_source": (
        "sdk/adapters/godot/gdscript/recovery_discrete_staging_route_v1.gd",
        "668a7a6b14bbb3658b03b5f34241cc2053c368b4",
        23_306,
        "sha256:d0800c97920d96566fca186f54d40d8d0ab37069af8707977052da28d8e699fd",
    ),
    "portable_recovery_supervisor_source": (
        "sdk/core/src/recovery.rs",
        "b6660a0b4d972ada92afd18e487146d68a5e0fc4",
        240_774,
        "sha256:9ab3a478e7fbfb610b5110ddce90879f7f1c19006462fa5916a205a8053399c2",
    ),
    "portable_recovery_command_policy_source": (
        "sdk/core/src/recovery_runtime.rs",
        "1df4722ca859e9421ca4bffa039f1917619758d0",
        229_800,
        "sha256:08ced1fc6f31437f671e5811bb1eb2a6527f6b7c987d7f0106525a5d470eb6e3",
    ),
    "selected_policy_godot_adapter_source": (
        "scripts/lab/gait/sdk_godot_jolt_adapter.gd",
        "ef793ede82d63ee266ee815f2b0dd19866ef9596",
        331_602,
        "sha256:10679c11476f9b83cd23205580313caba9b348e1bee2bb8473189f8f05f61e63",
    ),
    "historical_walking_fixture_source": (
        "scripts/lab/gait/physical_wave_gait_quadruped.gd",
        "c7e146bd2487e9c72c0577db5d7604d03a137e75",
        450_383,
        "sha256:80f5197940e971dbff6bba0720eb92d72843386754f327e5c533f3737fdf17eb",
    ),
}

EXPECTED_PATH_VALUES: dict[str, Any] = {
    "schema_version": "sporespore_qsdk_r10f_continuous_passive_fall_recovery_successor_design_v1",
    "status": "prospective_zero_world_successor_design_complete_implementation_authorized_physics_blocked",
    "gate_id": "QSDK-R10F",
    "parent_gate_id": "QSDK-R10",
    "design_id": "QSDK-R10F-CONTINUOUS-S169-KICK-PASSIVE-FALL-RECOVERY-RESUME",
    "authored_parent_commit": AUTHORED_PARENT,
    "authored_local_date": "2026-09-04",
    "ledger_scope.subsystem": "recovery",
    "ledger_scope.engine_scope": "godot_jolt",
    "ledger_scope.authority_mode": "retained_evidence_diagnosis_and_prospective_successor_design",
    "ledger_scope.question_class": "development",
    "question_declaration.physical_question_declared": False,
    "question_declaration.finite_decision_declared": False,
    "question_declaration.superiority_question_declared": False,
    "question_declaration.equivalence_or_non_inferiority_question_declared": False,
    "question_declaration.population_inference_declared": False,
    "question_declaration.physical_work_authorized": False,
    "question_declaration.maximum_world_attempt_count_before_complete_new_authority_graph": 0,
    "question_declaration.maximum_world_build_count_before_complete_new_authority_graph": 0,
    "question_declaration.maximum_solver_step_count_before_complete_new_authority_graph": 0,
    "release_milestone_context.sdk1_milestone_id": "SDK1-M07",
    "release_milestone_context.sdk1_milestone_label": "Push interaction and recovery path",
    "release_milestone_context.source_gate_id": "QSDK-R10",
    "release_milestone_context.score_before_design": "14/20",
    "release_milestone_context.full_program_score_before_design": "14/25",
    "release_milestone_context.other_current_candidate_blockers": ["SDK1-M14", "SDK1-M20"],
    "release_milestone_context.m07_should_precede_m20": True,
    "release_milestone_context.this_design_advances_m07": False,
    "preserved_predecessor_results.r10e_l3.classification": "valid_complete_behavior_finite_negative",
    "preserved_predecessor_results.r10e_l3.declared_world_count": 6,
    "preserved_predecessor_results.r10e_l3.valid_world_count": 6,
    "preserved_predecessor_results.r10e_l3.valid_pair_count": 3,
    "preserved_predecessor_results.r10e_l3.native_effect_confirmed_pair_count": 3,
    "preserved_predecessor_results.r10e_l3.local_recovery_window_found_pair_count": 3,
    "preserved_predecessor_results.r10e_l3.only_false_behavior_receipt": "bounded_anchor_error",
    "preserved_predecessor_results.r10e_l3.first_over_limit_samples_preceded_push": True,
    "preserved_predecessor_results.r10e_l3.same_identity_rerun_permitted": False,
    "preserved_predecessor_results.r10e_l3.result_reclassification_permitted": False,
    "preserved_predecessor_results.r10e_l3.threshold_relaxation_permitted": False,
    "preserved_predecessor_results.r10e_l3.local_window_only_promotion_permitted": False,
    "preserved_predecessor_results.r172.candidate_terminal_phase": "complete",
    "preserved_predecessor_results.r172.candidate_terminal_step": 240,
    "preserved_predecessor_results.r172.matched_zero_terminal_phase": "failed",
    "preserved_predecessor_results.r172.matched_zero_terminal_step": 268,
    "preserved_predecessor_results.r172.total_solver_step_count": 508,
    "preserved_predecessor_results.r172.all_in_run_invariant_receipt_count": 508,
    "preserved_predecessor_results.r172.all_in_run_physical_invariants_passed": True,
    "preserved_predecessor_results.r172.same_identity_rerun_permitted": False,
    "preserved_predecessor_results.r172.kick_or_push_entry_observed": False,
    "preserved_predecessor_results.r172.arbitrary_fall_state_observed": False,
    "preserved_predecessor_results.r173.q_sdk_r24_satisfied": True,
    "preserved_predecessor_results.r173.sdk1_m19_satisfied": True,
    "preserved_predecessor_results.r173.godot_candidate_terminal_step": 240,
    "preserved_predecessor_results.r173.new_physical_evidence_collected": False,
    "preserved_predecessor_results.r173.cross_engine_equivalence_claimed": False,
    "preserved_predecessor_results.r173.kick_or_push_recovery_claimed": False,
    "identity_reconciliation.base_morphology_id": "qsdk_r05_generated_s169",
    "identity_reconciliation.base_descriptor_sha256": "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0",
    "identity_reconciliation.base_morphology_spec_sha256": "sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e",
    "identity_reconciliation.actuator_profile_id": "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1",
    "identity_reconciliation.actuator_profile_sha256": "sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964",
    "identity_reconciliation.recovery_morphology_id": "qsdk_r24_recovery_s169_v1",
    "identity_reconciliation.recovery_descriptor_sha256": "sha256:431a9c8001931e751bb2f1f2750c31650dd2d994575a736c53adbef1b27a71f6",
    "identity_reconciliation.recovery_morphology_spec_sha256": "sha256:926551af3a72eb1fd1f3b71bfb103587a0b906a116775551a2463792e2c160f9",
    "identity_reconciliation.selected_locomotion_policy_id": "sporespore_balanced_wave_bw5r_b_v1",
    "identity_reconciliation.selected_locomotion_policy_sha256": "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f",
    "identity_reconciliation.recovery_controller_id": "sporespore_exact_s169_prone_to_standing_controller_v6",
    "identity_reconciliation.recovery_task_id": "sporespore_canonical_ventral_prone_to_four_foot_stance_v1",
    "identity_reconciliation.shared_base_identity_established": True,
    "identity_reconciliation.shared_physical_fixture_identity_established": False,
    "identity_reconciliation.shared_dynamic_outcome_established": False,
    "identity_reconciliation.r23d78_turning_behavior_reused_as_r10f_controller": False,
    "identity_reconciliation.r23d78_returns_at_sdk1_m20": True,
    "rejected_composition.old_walking_fixture_reused_as_recovery_fixture": False,
    "rejected_composition.walking_fixture_upper_collision_kind": "box",
    "rejected_composition.walking_fixture_distal_collision_kind": "sphere",
    "rejected_composition.recovery_fixture_upper_collision_kind": "capsule",
    "rejected_composition.recovery_fixture_distal_collision_kind": "capsule",
    "rejected_composition.walking_fixture_direct_state_body_count": 5,
    "rejected_composition.recovery_fixture_direct_state_body_count": 9,
    "rejected_composition.walking_fixture_friction": 0.95,
    "rejected_composition.recovery_fixture_friction": 1.8,
    "rejected_composition.label_only_adapter_wrap_permitted": False,
    "rejected_composition.retained_kick_plus_retained_prone_to_standing_composition_satisfies_m07": False,
    "selected_same_body_route.world_builder": "qualified_recovery_native_world_v1",
    "selected_same_body_route.physical_body_population_created_once": True,
    "selected_same_body_route.body_count": 9,
    "selected_same_body_route.joint_count": 8,
    "selected_same_body_route.body_node_identity_must_remain_constant": True,
    "selected_same_body_route.joint_node_identity_must_remain_constant": True,
    "selected_same_body_route.scene_tree_reparenting_after_world_start_permitted": False,
    "selected_same_body_route.post_construction_transform_write_permitted": False,
    "selected_same_body_route.post_construction_velocity_write_permitted": False,
    "selected_same_body_route.teleport_or_pose_reset_permitted": False,
    "selected_same_body_route.solver_state_reset_permitted": False,
    "selected_same_body_route.contact_state_synthesis_permitted": False,
    "selected_same_body_route.missing_measurement_synthesis_permitted": False,
    "selected_same_body_route.ordered_phases": [
        "canonical_prone_precondition_recovery",
        "fresh_selected_policy_walking_prefix",
        "native_kick_or_matched_no_kick_step",
        "kick_triggered_zero_actuation_passive_fall",
        "offset_bound_recovery_epoch",
        "stable_stance_completion",
        "fresh_selected_policy_walking_resume",
    ],
    "selected_same_body_route.canonical_prone_precondition_recovery.uses_v6_controller": True,
    "selected_same_body_route.canonical_prone_precondition_recovery.maximum_outer_steps": 1200,
    "selected_same_body_route.canonical_prone_precondition_recovery.must_complete_before_locomotion": True,
    "selected_same_body_route.canonical_prone_precondition_recovery.counts_as_post_kick_recovery_evidence": False,
    "selected_same_body_route.walking_session_rule.pre_kick_session_is_fresh": True,
    "selected_same_body_route.walking_session_rule.post_recovery_session_is_fresh": True,
    "selected_same_body_route.walking_session_rule.controller_memory_continues_across_recovery": False,
    "selected_same_body_route.walking_session_rule.native_body_state_continues_across_recovery": True,
    "selected_same_body_route.walking_session_rule.local_policy_semantic_step_restarts_at_zero": True,
    "selected_same_body_route.walking_session_rule.global_native_solver_sequence_restarts": False,
    "selected_same_body_route.walking_session_rule.task_frame_reanchor_at_each_fresh_session": True,
    "selected_same_body_route.walking_session_rule.task_frame_reanchor_moves_or_rotates_body": False,
    "selected_same_body_route.walking_session_rule.selected_policy_or_profile_changes": False,
    "selected_same_body_route.native_kick.application_api": "RigidBody3D.apply_central_impulse",
    "selected_same_body_route.native_kick.target_body_id": "torso",
    "selected_same_body_route.native_kick.task_frame_impulse_n_s": [0.0, 0.0, 0.25],
    "selected_same_body_route.native_kick.magnitude_n_s": 0.25,
    "selected_same_body_route.native_kick.application_count_active_arm": 1,
    "selected_same_body_route.native_kick.application_count_baseline_arm": 0,
    "selected_same_body_route.native_kick.native_effect_floor_m_s": 0.0001,
    "selected_same_body_route.native_kick.effect_measured_on_first_completed_step_after_application": True,
    "selected_same_body_route.native_kick.impulse_magnitude_or_direction_selected_from_r10f_outcome": False,
    "selected_same_body_route.passive_fall_rule.walking_motors_disabled_in_same_pre_solver_event_as_kick_application": True,
    "selected_same_body_route.passive_fall_rule.walking_motors_remain_enabled_through_kick_effect_solve": False,
    "selected_same_body_route.passive_fall_rule.walking_or_recovery_actuation_during_first_completed_kick_step": False,
    "selected_same_body_route.passive_fall_rule.recovery_epoch_opens_after_first_completed_kick_step": True,
    "selected_same_body_route.passive_fall_rule.recovery_confirm_prone_phase_emits_zero_actuation": True,
    "selected_same_body_route.passive_fall_rule.required_consecutive_prone_samples_before_active_recovery": 12,
    "selected_same_body_route.passive_fall_rule.maximum_confirm_prone_steps": 60,
    "selected_same_body_route.passive_fall_rule.kick_impulse_alone_mechanically_causes_fall_claimed": False,
    "selected_same_body_route.passive_fall_rule.continuous_force_estimation_used": False,
    "selected_same_body_route.passive_fall_rule.force_aware_bracing_used": False,
    "selected_same_body_route.passive_fall_rule.force_aware_recovery_used": False,
    "recovery_epoch_contract.epoch_local_step_definition": "L = G - E",
    "recovery_epoch_contract.first_recovery_observation_global_step": "E + 1",
    "recovery_epoch_contract.first_recovery_observation_local_step": 1,
    "recovery_epoch_contract.portable_recovery_memory_uses_global_semantic_steps": True,
    "recovery_epoch_contract.portable_recovery_memory_allows_nonzero_first_global_step": True,
    "recovery_epoch_contract.global_callback_sequence_preserved": True,
    "recovery_epoch_contract.global_native_space_sequence_preserved": True,
    "recovery_epoch_contract.global_host_step_sequence_preserved": True,
    "recovery_epoch_contract.callback_or_space_sequence_rewrite_permitted": False,
    "recovery_epoch_contract.boundary_transport.initializer_source_kind": "completed_step_direct_state_callback_v1",
    "recovery_epoch_contract.boundary_transport.initializer_boundary_sequence": "E",
    "recovery_epoch_contract.boundary_transport.initializer_body_count": 9,
    "recovery_epoch_contract.boundary_transport.accepted_pair_count_at_initializer": 0,
    "recovery_epoch_contract.boundary_transport.state_revision_at_initializer": 0,
    "recovery_epoch_contract.boundary_transport.first_pair_sequences": ["E", "E + 1"],
    "recovery_epoch_contract.boundary_transport.pair_count_after_global_step_G": "G - E",
    "recovery_epoch_contract.boundary_transport.state_revision_after_global_step_G": "G - E",
    "recovery_epoch_contract.boundary_transport.skipped_or_duplicate_global_boundary_permitted": False,
    "recovery_epoch_contract.energy_baseline.baseline_boundary_sequence": "E",
    "recovery_epoch_contract.energy_baseline.baseline_is_source_measured": True,
    "recovery_epoch_contract.energy_baseline.translational_kinetic_energy_included": True,
    "recovery_epoch_contract.energy_baseline.rotational_kinetic_energy_included": True,
    "recovery_epoch_contract.energy_baseline.gravitational_potential_energy_included": True,
    "recovery_epoch_contract.energy_baseline.canonical_world_start_pose_reconstruction_used": False,
    "recovery_epoch_contract.energy_baseline.initial_mechanical_energy_equals_live_boundary_E_energy": True,
    "recovery_epoch_contract.energy_baseline.cumulative_actuator_work_at_epoch_start_j": 0.0,
    "recovery_epoch_contract.energy_baseline.cumulative_external_work_at_epoch_start_j": 0.0,
    "recovery_epoch_contract.energy_baseline.cumulative_constraint_exchange_at_epoch_start_j": 0.0,
    "recovery_epoch_contract.energy_baseline.cumulative_discrete_staging_exchange_at_epoch_start_j": 0.0,
    "recovery_epoch_contract.energy_baseline.cumulative_passive_dissipation_at_epoch_start_j": 0.0,
    "recovery_epoch_contract.energy_baseline.kick_work_included_in_recovery_epoch_ledger": False,
    "recovery_epoch_contract.staging_accumulator.sequence_at_initializer": "E",
    "recovery_epoch_contract.staging_accumulator.event_count_at_initializer": 0,
    "recovery_epoch_contract.staging_accumulator.sequence_after_global_step_G": "G",
    "recovery_epoch_contract.staging_accumulator.event_count_after_global_step_G": "G - E",
    "recovery_epoch_contract.staging_accumulator.event_count_claims_unobserved_walking_or_kick_steps": False,
    "recovery_epoch_contract.staging_accumulator.previous_accumulator_digest_chain_required": True,
    "recovery_epoch_contract.staging_accumulator.observer_receipt_digest_chain_required": True,
    "recovery_epoch_contract.old_world_start_transport_or_accumulator_mutated": False,
    "recovery_epoch_contract.new_versioned_transport_and_accumulator_required": True,
    "prospective_population.development_route_ghost.question_class": "development",
    "prospective_population.development_route_ghost.campaign_seed": 40200,
    "prospective_population.development_route_ghost.ordered_arm_ids": ["matched_no_kick_continuation", "kick_passive_recovery_resume"],
    "prospective_population.development_route_ghost.world_count": 2,
    "prospective_population.development_route_ghost.behavioral_success_required_to_complete_route": False,
    "prospective_population.development_route_ghost.complete_valid_physics_negative_counts_as_route_success": True,
    "prospective_population.development_route_ghost.held_out_cells_accessible": False,
    "prospective_population.development_route_ghost.maximum_campaign_attempt_count": 1,
    "prospective_population.held_out_finite_decision.question_class": "finite decision",
    "prospective_population.held_out_finite_decision.campaign_seeds": [40201, 40202, 40203],
    "prospective_population.held_out_finite_decision.ordered_arm_ids": ["matched_no_kick_continuation", "kick_passive_recovery_resume"],
    "prospective_population.held_out_finite_decision.world_count": 6,
    "prospective_population.held_out_finite_decision.all_cells_run_regardless_of_intermediate_behavior": True,
    "prospective_population.held_out_finite_decision.pooling_across_seeds_permitted": False,
    "prospective_population.held_out_finite_decision.selective_completion_or_failed_cell_replacement_permitted": False,
    "prospective_population.held_out_finite_decision.sealed_until_development_route_positive_and_new_authority_graph_complete": True,
    "prospective_population.held_out_finite_decision.maximum_campaign_attempt_count": 1,
    "prospective_population.campaign_seed_controls_only_gait_phase_fixture": True,
    "prospective_population.campaign_seed_changes_canonical_prone_initializer": False,
    "prospective_population.r10f_physical_outcome_known": False,
    "prospective_behavior_contract.physics_hz": 120,
    "prospective_behavior_contract.maximum_canonical_precondition_recovery_steps": 1200,
    "prospective_behavior_contract.walking_prefix_steps": 720,
    "prospective_behavior_contract.kick_effect_step_count": 1,
    "prospective_behavior_contract.maximum_passive_confirm_prone_steps": 60,
    "prospective_behavior_contract.maximum_post_kick_recovery_epoch_steps": 1200,
    "prospective_behavior_contract.post_kick_recovery_epoch_includes_passive_confirm_prone_steps": True,
    "prospective_behavior_contract.walking_resume_steps": 720,
    "prospective_behavior_contract.maximum_active_arm_solver_steps": 3841,
    "prospective_behavior_contract.baseline_arm_runs_equal_global_horizon": True,
    "prospective_behavior_contract.ordinary_walking_receipt_count": 27,
    "prospective_behavior_contract.bounded_anchor_error_limit_m": 0.025,
    "prospective_behavior_contract.bounded_anchor_error_receipt_removed_or_relaxed": False,
    "prospective_behavior_contract.full_world_anchor_error_history_preserved": True,
    "prospective_behavior_contract.minimum_walking_prefix_forward_advance_m": 0.02,
    "prospective_behavior_contract.minimum_walking_resume_forward_advance_m": 0.02,
    "prospective_behavior_contract.maximum_walking_segment_absolute_lateral_drift_m": 0.25,
    "prospective_behavior_contract.pre_kick_stable_stance_required": True,
    "prospective_behavior_contract.native_kick_effect_required": True,
    "prospective_behavior_contract.ventral_prone_confirmation_required": True,
    "prospective_behavior_contract.post_kick_v6_terminal_phase_required": "complete",
    "prospective_behavior_contract.stable_four_foot_stance_required": True,
    "prospective_behavior_contract.post_recovery_forward_resume_required": True,
    "prospective_behavior_contract.same_body_identity_across_every_phase_required": True,
    "prospective_behavior_contract.zero_root_actuation_required": True,
    "prospective_behavior_contract.zero_transform_or_velocity_rewrite_required": True,
    "prospective_behavior_contract.all_native_engine_health_receipts_required": True,
    "prospective_behavior_contract.all_recovery_energy_invariants_required": True,
    "prospective_behavior_contract.threshold_controller_impulse_material_solver_or_policy_change_after_outcome_permitted": False,
    "forward_authority_sequence.maximum_development_route_ghost_campaign_attempt_count": 1,
    "forward_authority_sequence.maximum_development_route_ghost_world_count": 2,
    "forward_authority_sequence.held_out_cells_remain_sealed": True,
    "forward_authority_sequence.physical_execution_blocked_until_sequence_complete": True,
    "forward_authority_sequence.development_result_may_be_negative_without_being_infrastructure_invalid": True,
    "decision.selected_successor_gate_id": "QSDK-R10F",
    "decision.selected_successor_kind": "continuous_same_body_event_triggered_passive_fall_recovery_resume",
    "decision.q_sdk_r10f_zero_world_implementation_authorized": True,
    "decision.q_sdk_r10f_physical_execution_authorized": False,
    "decision.sdk1_m07_satisfied": False,
    "decision.scores_unchanged": True,
}

EXPECTED_CLAIM_BOUNDARY = {
    "design_complete": True,
    "retained_diagnosis_complete": True,
    "zero_world_implementation_authorized": True,
    "physical_execution_authorized": False,
    "r10e_l3_finite_negative_preserved": True,
    "r172_exact_nominal_positive_preserved": True,
    "r173_three_engine_prone_to_standing_preserved": True,
    "selected_policy_identity_preserved": True,
    "r10f_behavior_observed": False,
    "r10f_continuous_same_body_path_observed": False,
    "event_triggered_passive_recovery": False,
    "external_push_recovery": False,
    "kick_impulse_alone_causes_fall": False,
    "force_aware_recovery": False,
    "force_aware_bracing": False,
    "arbitrary_fall_recovery": False,
    "general_self_righting": False,
    "arbitrary_push_direction_or_magnitude": False,
    "cross_engine_push_recovery": False,
    "cross_engine_effect_equivalence": False,
    "population_robustness": False,
    "sdk1_m07_advanced": False,
    "q_sdk_r10_advanced": False,
    "sdk1_m20_advanced": False,
    "clean_room_candidate_authorized": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}

EXPECTED_FORWARD_SEQUENCE = [
    "commit_and_push_r10f_design",
    "implement_complete_zero_world_source_and_negative_controls",
    "commit_and_push_implementation_source",
    "run_one_official_development_zero_world_qualification",
    "commit_and_push_development_freeze_only_child",
    "commit_and_push_development_execution_authority_only_child",
    "pass_committed_graph_check",
    "run_one_two_world_development_route_ghost",
    "close_and_preserve_development_result",
    "only_if_development_positive_declare_a_distinct_held_out_finite_decision_graph",
]


class AuditFailure(RuntimeError):
    """Raised when a bound byte, scientific limit, or design invariant drifts."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditFailure(code)


def sha256_bytes(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def git_blob_oid(raw: bytes) -> str:
    header = f"blob {len(raw)}\0".encode("ascii")
    return hashlib.sha1(header + raw).hexdigest()  # noqa: S324 - Git object identity


def git_text(args: tuple[str, ...]) -> str:
    completed = subprocess.run(
        ["git", *args], cwd=ROOT, check=False, capture_output=True, text=True
    )
    require(completed.returncode == 0, f"GIT_FAILED:{' '.join(args)}")
    return completed.stdout.strip()


def git_bytes(args: tuple[str, ...]) -> bytes:
    completed = subprocess.run(
        ["git", *args], cwd=ROOT, check=False, capture_output=True
    )
    require(completed.returncode == 0, f"GIT_FAILED:{' '.join(args)}")
    return completed.stdout


def read_json(raw: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise AuditFailure(f"{label}_JSON_INVALID:{exc}") from exc
    require(isinstance(value, dict), f"{label}_NOT_OBJECT")
    return value


def exact_equal(actual: Any, expected: Any) -> bool:
    if type(actual) is not type(expected):
        return False
    if isinstance(actual, dict):
        return set(actual) == set(expected) and all(
            exact_equal(actual[key], expected[key]) for key in actual
        )
    if isinstance(actual, list):
        return len(actual) == len(expected) and all(
            exact_equal(left, right) for left, right in zip(actual, expected)
        )
    return bool(actual == expected)


def dotted(value: Any, path: str) -> Any:
    current = value
    for part in path.split("."):
        require(isinstance(current, dict) and part in current, f"DOTTED_MISSING:{path}")
        current = current[part]
    return current


def set_dotted(value: dict[str, Any], path: str, replacement: Any) -> None:
    parts = path.split(".")
    current: dict[str, Any] = value
    for part in parts[:-1]:
        nested = current.get(part)
        require(isinstance(nested, dict), f"SET_DOTTED_MISSING:{path}")
        current = nested
    require(parts[-1] in current, f"SET_DOTTED_LEAF_MISSING:{path}")
    current[parts[-1]] = replacement


def validate_authority_declarations(design: dict[str, Any]) -> None:
    authorities = design.get("bound_authorities")
    require(isinstance(authorities, list), "AUTHORITIES_TYPE")
    require(len(authorities) == len(EXPECTED_AUTHORITIES), "AUTHORITIES_COUNT")
    seen_roles: set[str] = set()
    seen_paths: set[str] = set()
    for entry in authorities:
        require(isinstance(entry, dict), "AUTHORITY_ENTRY_TYPE")
        require(
            set(entry) == {"role", "path", "git_blob_oid", "byte_length", "raw_sha256"},
            "AUTHORITY_ENTRY_FIELDS",
        )
        role = entry.get("role")
        require(isinstance(role, str) and role in EXPECTED_AUTHORITIES, "AUTHORITY_ROLE")
        require(role not in seen_roles, f"AUTHORITY_ROLE_DUPLICATE:{role}")
        path, blob, length, digest = EXPECTED_AUTHORITIES[role]
        require(entry.get("path") == path, f"{role}:PATH")
        require(entry.get("git_blob_oid") == blob, f"{role}:BLOB")
        require(entry.get("byte_length") == length, f"{role}:BYTES")
        require(entry.get("raw_sha256") == digest, f"{role}:SHA256")
        require(path not in seen_paths, f"AUTHORITY_PATH_DUPLICATE:{path}")
        require("\\" not in path and not Path(path).is_absolute(), f"{role}:PATH_KIND")
        require(".." not in Path(path).parts, f"{role}:PATH_ESCAPE")
        seen_roles.add(role)
        seen_paths.add(path)
    require(seen_roles == set(EXPECTED_AUTHORITIES), "AUTHORITY_ROLE_SET")


def validate_design_contract(design: dict[str, Any]) -> None:
    require(set(design) == EXPECTED_TOP_LEVEL, "DESIGN_TOP_LEVEL")
    for path, expected in EXPECTED_PATH_VALUES.items():
        require(exact_equal(dotted(design, path), expected), f"DESIGN_VALUE:{path}")
    validate_authority_declarations(design)
    question = dotted(design, "question_declaration.question")
    require(isinstance(question, str), "QUESTION_TYPE")
    for phrase in (
        "one continuously simulated exact S169 Godot/Jolt body",
        "zero-actuation passive fall",
        "fresh BW5R-B session",
        "without a transform, velocity, contact, or solver-state rewrite",
    ):
        require(phrase in question, f"QUESTION_SCOPE:{phrase}")
    require(
        exact_equal(design.get("claim_boundary"), EXPECTED_CLAIM_BOUNDARY),
        "CLAIM_BOUNDARY",
    )
    require(
        exact_equal(
            dotted(design, "forward_authority_sequence.ordered_steps"),
            EXPECTED_FORWARD_SEQUENCE,
        ),
        "FORWARD_SEQUENCE",
    )
    controls = design.get("required_zero_world_controls")
    require(isinstance(controls, dict), "ZERO_WORLD_CONTROLS_TYPE")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(controls.get(key) == 0, f"ZERO_WORLD_NONZERO:{key}")
    for key in (
        "bound_authority_digest_checks",
        "repository_root_and_remote_checks",
        "portable_nonzero_first_semantic_step_canary",
        "epoch_boundary_initializer_canary",
        "epoch_boundary_duplicate_stale_and_skipped_refusals",
        "epoch_accumulator_offset_and_digest_chain_canary",
        "live_energy_baseline_projection_canary",
        "kick_work_exclusion_and_separate_receipt_binding_canary",
        "same_body_identity_transition_canary",
        "walking_fixture_label_only_wrap_refusal",
        "post_construction_transform_velocity_and_solver_reset_refusals",
        "force_aware_claim_refusal",
        "outcome_derived_threshold_mutation_refusal",
    ):
        require(controls.get(key) is True, f"ZERO_WORLD_CONTROL_FALSE:{key}")
    require(controls.get("physics_state_modified") is False, "ZERO_WORLD_STATE")
    require(controls.get("physical_acceptance_authority") is False, "ZERO_WORLD_PHYSICAL")
    require(controls.get("release_authority") is False, "ZERO_WORLD_RELEASE")
    implementation = design.get("implementation_surface")
    require(isinstance(implementation, dict), "IMPLEMENTATION_TYPE")
    for key in (
        "new_versioned_epoch_boundary_transport_module_required",
        "new_versioned_epoch_staging_accumulator_module_required",
        "new_recovery_epoch_initializer_required",
        "new_same_body_locomotion_facade_required",
        "new_event_triggered_orchestrator_required",
        "new_zero_world_source_and_negative_controls_required",
        "new_dependency_manifest_required",
        "new_development_supervisor_required",
    ):
        require(implementation.get(key) is True, f"IMPLEMENTATION_REQUIRED:{key}")
    for key in (
        "existing_r172_world_start_transport_changed",
        "existing_r172_accumulator_changed",
        "existing_r172_physical_result_changed",
        "existing_r173_decision_changed",
        "existing_r10e_result_changed",
        "core_recovery_threshold_values_changed",
        "selected_locomotion_policy_changed",
        "native_kick_magnitude_or_direction_changed_from_r10e",
    ):
        require(implementation.get(key) is False, f"IMPLEMENTATION_MUTATION:{key}")
    behavior = design["prospective_behavior_contract"]
    calculated_maximum = (
        int(behavior["maximum_canonical_precondition_recovery_steps"])
        + int(behavior["walking_prefix_steps"])
        + int(behavior["kick_effect_step_count"])
        + int(behavior["maximum_post_kick_recovery_epoch_steps"])
        + int(behavior["walking_resume_steps"])
    )
    require(calculated_maximum == 3_841, "ACTIVE_HORIZON_CALCULATION")
    require(
        behavior["maximum_passive_confirm_prone_steps"]
        <= behavior["maximum_post_kick_recovery_epoch_steps"],
        "CONFIRM_PRONE_OUTSIDE_RECOVERY_EPOCH",
    )


def load_bound_authorities(design: dict[str, Any]) -> dict[str, bytes]:
    loaded: dict[str, bytes] = {}
    for entry in design["bound_authorities"]:
        role = str(entry["role"])
        path = str(entry["path"])
        raw = (ROOT / path).read_bytes()
        require(len(raw) == entry["byte_length"], f"{role}:DISK_BYTES")
        require(sha256_bytes(raw) == entry["raw_sha256"], f"{role}:DISK_SHA256")
        require(
            git_text(("hash-object", "--", path)) == entry["git_blob_oid"],
            f"{role}:FILTERED_DISK_BLOB",
        )
        require(
            git_text(("rev-parse", f"{AUTHORED_PARENT}:{path}"))
            == entry["git_blob_oid"],
            f"{role}:AUTHORED_PARENT_BLOB",
        )
        parent_raw = git_bytes(("show", f"{AUTHORED_PARENT}:{path}"))
        require(git_blob_oid(parent_raw) == entry["git_blob_oid"], f"{role}:PARENT_RAW_BLOB")
        loaded[role] = raw
    return loaded


def _safe_child(root: Path, relative: str) -> Path:
    require(relative and "\\" not in relative, f"EVIDENCE_PATH_KIND:{relative}")
    rel = Path(relative)
    require(not rel.is_absolute() and ".." not in rel.parts, f"EVIDENCE_PATH_ESCAPE:{relative}")
    path = (root / rel).resolve()
    try:
        path.relative_to(root.resolve())
    except ValueError as exc:
        raise AuditFailure(f"EVIDENCE_PATH_OUTSIDE:{relative}") from exc
    return path


def validate_r10e_retained_negative(raw: bytes) -> dict[str, Any]:
    closure = read_json(raw, "R10E_CLOSURE")
    outcome = closure.get("outcome")
    require(isinstance(outcome, dict), "R10E_OUTCOME_TYPE")
    require(outcome.get("classification") == "valid_complete_behavior_finite_negative", "R10E_CLASSIFICATION")
    require(outcome.get("attempted_cell_count") == 6, "R10E_ATTEMPTED")
    require(outcome.get("valid_complete_cell_count") == 6, "R10E_VALID_CELLS")
    require(outcome.get("valid_complete_pair_count") == 3, "R10E_VALID_PAIRS")
    require(outcome.get("native_effect_pair_count") == 3, "R10E_NATIVE_PAIRS")
    require(outcome.get("behavior_passed") is False, "R10E_BEHAVIOR")
    for key in ("route_execution_valid", "evidence_valid", "outcome_complete"):
        require(closure.get(key) is True, f"R10E_{key.upper()}")
    require(closure.get("physical_identity_consumed") is True, "R10E_CONSUMED")
    require(closure.get("same_identity_rerun_permitted") is False, "R10E_RERUN")
    require(closure["decision"]["q_sdk_r10_gate_advanced_by_this_closure"] is False, "R10E_GATE")
    retained = closure.get("retained_evidence")
    require(isinstance(retained, dict), "R10E_RETAINED_TYPE")
    evidence_root = Path(str(retained.get("output_root", "")))
    require(evidence_root.is_dir(), "R10E_EVIDENCE_ROOT")
    tree = retained.get("retained_tree")
    require(isinstance(tree, dict), "R10E_TREE_TYPE")
    require(Path(str(tree.get("root", ""))).resolve() == evidence_root.resolve(), "R10E_TREE_ROOT")
    files = tree.get("files")
    require(isinstance(files, list) and len(files) == 35, "R10E_TREE_FILES")
    observed_total = 0
    observed_paths: set[str] = set()
    for entry in files:
        require(isinstance(entry, dict), "R10E_TREE_ENTRY_TYPE")
        relative = str(entry.get("path", ""))
        require(relative not in observed_paths, f"R10E_TREE_DUPLICATE:{relative}")
        evidence_path = _safe_child(evidence_root, relative)
        evidence_raw = evidence_path.read_bytes()
        require(len(evidence_raw) == entry.get("byte_length"), f"R10E_TREE_BYTES:{relative}")
        require(sha256_bytes(evidence_raw) == entry.get("raw_sha256"), f"R10E_TREE_SHA:{relative}")
        observed_total += len(evidence_raw)
        observed_paths.add(relative)
    require(observed_total == tree.get("total_byte_length") == 79_688_410, "R10E_TREE_TOTAL")
    terminal_binding = retained.get("terminal_report")
    require(isinstance(terminal_binding, dict), "R10E_TERMINAL_BINDING")
    terminal_path = Path(str(terminal_binding.get("path", "")))
    terminal_raw = terminal_path.read_bytes()
    require(len(terminal_raw) == terminal_binding.get("byte_length") == 18_001, "R10E_TERMINAL_BYTES")
    require(sha256_bytes(terminal_raw) == terminal_binding.get("raw_sha256"), "R10E_TERMINAL_SHA")
    terminal = read_json(terminal_raw, "R10E_TERMINAL")
    require(terminal.get("world_attempt_count") == 6, "R10E_TERMINAL_ATTEMPTS")
    require(terminal.get("world_build_count") == 6, "R10E_TERMINAL_WORLDS")
    require(terminal.get("campaign_attempt_count") == 1, "R10E_TERMINAL_CAMPAIGNS")
    require(terminal.get("physical_identity_consumed") is True, "R10E_TERMINAL_CONSUMED")
    require(terminal.get("same_identity_rerun_permitted") is False, "R10E_TERMINAL_RERUN")
    pairs = terminal.get("pairs")
    require(isinstance(pairs, list) and len(pairs) == 3, "R10E_TERMINAL_PAIRS")
    require(all(pair["evaluation"]["native_effect_confirmed"] is True for pair in pairs), "R10E_PAIR_EFFECT")
    require(all(pair["evaluation"]["behavior_passed"] is False for pair in pairs), "R10E_PAIR_BEHAVIOR")

    cells = terminal.get("cells")
    require(isinstance(cells, list) and len(cells) == 6, "R10E_TERMINAL_CELLS")
    by_seed: dict[int, dict[str, dict[str, Any]]] = {}
    effect_magnitudes: list[float] = []
    local_recovery_count = 0
    pre_push_crossing_count = 0
    for cell in cells:
        require(cell.get("process_completed") is True and cell.get("worker_ok") is True, "R10E_CELL_EXECUTION")
        receipt_binding = cell.get("receipt_binding")
        require(isinstance(receipt_binding, dict), "R10E_CELL_RECEIPT_BINDING")
        receipt_raw = _safe_child(evidence_root, str(receipt_binding["path"])).read_bytes()
        require(len(receipt_raw) == receipt_binding["byte_length"], "R10E_CELL_RECEIPT_BYTES")
        require(sha256_bytes(receipt_raw) == receipt_binding["raw_sha256"], "R10E_CELL_RECEIPT_SHA")
        receipt = read_json(receipt_raw, f"R10E_{cell['cell_id']}")
        evaluation = receipt.get("evaluation")
        require(isinstance(evaluation, dict), "R10E_CELL_EVALUATION")
        require(evaluation.get("ok") is True and evaluation.get("evidence_valid") is True, "R10E_CELL_VALID")
        require(evaluation.get("outcome_complete") is True, "R10E_CELL_COMPLETE")
        require(evaluation.get("behavior_passed") is False, "R10E_CELL_BEHAVIOR")
        gates = evaluation.get("walking_gate_receipts")
        require(isinstance(gates, dict) and len(gates) == 27, "R10E_WALKING_GATE_COUNT")
        false_gates = [key for key, value in gates.items() if value is not True]
        require(false_gates == ["bounded_anchor_error"], "R10E_ONLY_FALSE_GATE")
        require(evaluation["pre_push_window"]["passed"] is True, "R10E_PRE_WINDOW")
        arm_id = str(receipt.get("arm_id", ""))
        seed = int(receipt.get("campaign_seed", -1))
        by_seed.setdefault(seed, {})[arm_id] = receipt
        application = evaluation.get("application_receipt")
        require(isinstance(application, dict), "R10E_APPLICATION_TYPE")
        if arm_id == "lateral_upright_impulse":
            require(application.get("application_count") == 1, "R10E_ACTIVE_APPLICATION")
            require(application.get("effect_sampled") is True, "R10E_ACTIVE_EFFECT")
            effect_magnitudes.append(float(application["effect_magnitude_m_s"]))
            recovery = evaluation.get("recovery_search")
            require(isinstance(recovery, dict) and recovery.get("found") is True, "R10E_RECOVERY_FOUND")
            require(recovery.get("reentry_latency_steps") == 0, "R10E_RECOVERY_LATENCY")
            require(recovery["window"]["passed"] is True, "R10E_RECOVERY_WINDOW")
            local_recovery_count += 1
        else:
            require(arm_id == "matched_no_impulse_control", "R10E_ARM_ID")
            require(application.get("application_count") == 0, "R10E_BASELINE_APPLICATION")
            require(evaluation["baseline_post_marker_window"]["passed"] is True, "R10E_BASELINE_WINDOW")

        marker_tick = (
            int(receipt["runtime_summary_projection"]["sdk_adapter_start_tick"])
            + int(receipt["sdk_physical_trace"]["options"]["push_marker_semantic_step"])
        )
        stdout_path = _safe_child(evidence_root, str(cell["stdout_binding"]["path"]))
        first_crossing: tuple[int, float] | None = None
        with stdout_path.open("r", encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("QSDK_R10E_PHYSICAL_CELL "):
                    break
                match = re.search(r"wave_tick=(\d+).* anchor=([0-9.]+)", line)
                if match and float(match.group(2)) > 0.025 and first_crossing is None:
                    first_crossing = (int(match.group(1)), float(match.group(2)))
        require(first_crossing is not None, "R10E_LOGGED_ANCHOR_CROSSING")
        require(first_crossing[0] < marker_tick, "R10E_ANCHOR_CROSSING_NOT_PRE_PUSH")
        pre_push_crossing_count += 1

    require(sorted(by_seed) == [40101, 40102, 40103], "R10E_SEEDS")
    for arms in by_seed.values():
        require(set(arms) == {"matched_no_impulse_control", "lateral_upright_impulse"}, "R10E_PAIRED_ARMS")
        baseline = arms["matched_no_impulse_control"]
        active = arms["lateral_upright_impulse"]
        require(
            baseline["evaluation"]["initial_perturbation_sha256"]
            == active["evaluation"]["initial_perturbation_sha256"],
            "R10E_PAIRED_INITIAL",
        )
        require(exact_equal(baseline["evaluation"]["pre_push_window"], active["evaluation"]["pre_push_window"]), "R10E_PAIRED_PREFIX")
    expected_effects = [0.06441572308540344, 0.060107264667749405, 0.08401905745267868]
    require(effect_magnitudes == expected_effects, "R10E_EFFECT_MAGNITUDES")
    return {
        "retained_file_count": len(files),
        "retained_byte_length": observed_total,
        "valid_world_count": len(cells),
        "valid_pair_count": len(pairs),
        "native_effect_pair_count": len(effect_magnitudes),
        "local_recovery_window_count": local_recovery_count,
        "pre_push_anchor_crossing_world_count": pre_push_crossing_count,
    }


def validate_predecessor_authorities(loaded: dict[str, bytes]) -> int:
    r172 = read_json(loaded["consumed_exact_nominal_godot_recovery_positive"], "R172")
    raw = r172["observed_behavior"]["raw_exact"]
    require(raw["world_build_count"] == 2 and raw["solver_step_count"] == 508, "R172_COUNTS")
    require(raw["in_run_invariant_receipt_count"] == 508, "R172_INVARIANTS")
    require(raw["all_in_run_physical_invariants_passed"] is True, "R172_INVARIANT_PASS")
    arms = r172["observed_behavior"]["arm_summaries"]
    require([arm["final_phase"] for arm in arms] == ["complete", "failed"], "R172_PHASES")
    require([arm["native_solver_step_count"] for arm in arms] == [240, 268], "R172_STEPS")
    require(r172["decision"]["same_identity_rerun_permitted"] is False, "R172_RERUN")

    r173 = read_json(loaded["three_engine_canonical_prone_to_standing_decision"], "R173")
    require(r173["new_physical_evidence_collected"] is False, "R173_NEW_PHYSICS")
    require(r173["finite_decision_rule"]["q_sdk_r24_satisfied"] is True, "R173_R24")
    require(r173["finite_decision_rule"]["sdk1_m19_satisfied"] is True, "R173_M19")
    require(r173["claim_boundary"]["cross_engine_equivalence_claimed"] is False, "R173_EQUIVALENCE")
    engines = r173["immutable_engine_results"]
    require([entry["engine_id"] for entry in engines] == ["mujoco", "rapier_parry", "godot_jolt"], "R173_ENGINES")
    require([entry["candidate_terminal_phase"] for entry in engines] == ["complete"] * 3, "R173_TERMINALS")
    require([entry["candidate_terminal_step"] for entry in engines] == [373, 787, 240], "R173_TERMINAL_STEPS")
    require([entry["matched_zero_terminal_phase"] for entry in engines] == ["failed"] * 3, "R173_CONTROLS")

    policy = read_json(loaded["frozen_selected_locomotion_policy"], "SELECTED_POLICY")
    require(policy["selected_candidate_id"] == "BW5R-B", "SELECTED_CANDIDATE")
    require(policy["selected_policy_id"] == "sporespore_balanced_wave_bw5r_b_v1", "SELECTED_POLICY_ID")
    require(policy["selected_candidate_policy_digest"] == "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f", "SELECTED_POLICY_SHA")

    r05e = read_json(loaded["finite_selected_policy_morphology_walking_closure"], "R05E")
    require(r05e["selected_policy"]["candidate_id"] == "BW5R-B", "R05E_CANDIDATE")
    require(r05e["selected_policy"]["controller_policy_id"] == policy["selected_policy_id"], "R05E_POLICY")
    require(r05e["selected_policy"]["candidate_policy_digest"] == policy["selected_candidate_policy_digest"], "R05E_POLICY_SHA")
    require(r05e["engine_and_material"]["authored_friction"] == 0.95, "R05E_FRICTION")

    turning = read_json(loaded["bounded_three_engine_turning_closure"], "R23D78")
    require(turning["official_result"]["q_sdk_r23_satisfied"] is True, "R23D78_GATE")
    require(turning["official_result"]["cross_engine_equivalence_test_invoked"] is False, "R23D78_EQUIVALENCE")
    require(turning["official_result"]["same_identity_rerun_allowed"] is False, "R23D78_RERUN")

    mapping = read_json(loaded["sdk1_milestone_mapping"], "SDK1_MAPPING")
    milestones = mapping["sdk1_contract"]["milestones"]
    m07 = [entry for entry in milestones if entry.get("milestone_id") == "SDK1-M07"]
    require(len(m07) == 1, "M07_CARDINALITY")
    require(m07[0]["label"] == "Push interaction and recovery path", "M07_LABEL")
    require(m07[0]["source"] == {"kind": "full_program_gate", "gate_id": "QSDK-R10"}, "M07_SOURCE")
    return 6


SOURCE_MARKERS: dict[str, tuple[str, ...]] = {
    "portable_recovery_supervisor_source": (
        "if let Some(last) = memory.last_semantic_step",
        "memory.start_semantic_step = Some(semantic_step);",
        "entry_prone_height_ratio_max: 0.25,",
        "entry_torso_up_dot_max: 1.0,",
        "entry_prone_confirm_steps: 12,",
    ),
    "qualified_contiguous_boundary_transport_source": (
        'const INITIALIZER_SOURCE_KIND := "inactive_physics_initializer_readback_v1"',
        'if int(initializer_boundary.get("boundary_sequence", -1)) != 0:',
        '"cached_boundary_sequence": 0,',
        'or int(state["accepted_pair_count"]) != sequence',
        'int(state["state_revision"]) != sequence',
    ),
    "qualified_discrete_staging_route_source": (
        '"sequence": 0,',
        '"event_count": 0,',
        'or int(accumulator_before["event_count"]) != semantic_step - 1',
        '"event_count": semantic_step,',
        'int(value.get("event_count", -1)) == sequence',
    ),
    "qualified_recovery_native_world_source": (
        'semantic_step != int(model.get("host_step_count", -1)) + 1',
        "initial_mechanical_energy_value = _initial_mechanical_energy_j(model, snapshots)",
        "var translational := 0.5 * mass * linear.length_squared()",
        "var rotational := 0.5 * angular.dot(inertia_world * angular)",
        "var potential := -mass * gravity.dot(transform.origin)",
        'var initial_position: Vector3 = model["blueprint"]["positions"][body_id]',
        "var body := SemanticContactRigidBodyScript.new() as RigidBody3D",
        "body.contact_monitor = true",
        "var shape := CapsuleShape3D.new()",
        'shape_node.set_meta("lab_shape_id", body_id)',
        "material.friction = 1.8",
        "material.rough = true",
        "material.bounce = 0.0",
        "material.absorbent = true",
    ),
    "qualified_recovery_native_route_source": (
        'const RECOVERY_CONTROLLER_V6_ID := "sporespore_exact_s169_prone_to_standing_controller_v6"',
        'const RECOVERY_MORPHOLOGY_ID := "qsdk_r24_recovery_s169_v1"',
        'const BASE_DESCRIPTOR_SHA256 := "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0"',
        'const BASE_MORPHOLOGY_SPEC_SHA256 := "sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e"',
        'const RECOVERY_MORPHOLOGY_SPEC_SHA256 := "sha256:926551af3a72eb1fd1f3b71bfb103587a0b906a116775551a2463792e2c160f9"',
    ),
    "selected_policy_godot_adapter_source": (
        "func sample(",
        "func apply_authority(",
        'String(sample.get("local_shape_id", "")) == "foot"',
        "static func _legacy_joint_id_for_actuator(actuator_id: String) -> String:",
        'return "%s.hip_pitch" % joint_id.trim_suffix("_hip")',
        'return "%s.knee_pitch" % joint_id.trim_suffix("_knee")',
    ),
    "historical_walking_fixture_source": (
        "var upper_shape := BoxShape3D.new()",
        "var foot_shape := SphereShape3D.new()",
        "if monitor_contacts:",
        "body = SemanticContactRigidBodyScript.new()",
        "body = RigidBody3D.new()",
    ),
}


def validate_source_seams(loaded: dict[str, bytes]) -> int:
    marker_count = 0
    for role, markers in SOURCE_MARKERS.items():
        text = loaded[role].decode("utf-8")
        for marker in markers:
            require(marker in text, f"SOURCE_MARKER:{role}:{marker}")
            marker_count += 1
    walking = loaded["historical_walking_fixture_source"].decode("utf-8")
    require(
        re.search(r"var torso := _rigid_body\(.*?\n\s*true,\n\s*contact_material", walking, re.S)
        is not None,
        "WALKING_TORSO_CALLBACK",
    )
    require(
        re.search(r"var upper := _rigid_body\(.*?\n\s*false,\n\s*contact_material", walking, re.S)
        is not None,
        "WALKING_UPPER_NO_CALLBACK",
    )
    require(
        re.search(r"var foot := _rigid_body\(.*?\n\s*true,\n\s*contact_material", walking, re.S)
        is not None,
        "WALKING_FOOT_CALLBACK",
    )
    calculated_walking_callback_body_count = 1 + 4
    calculated_recovery_callback_body_count = 1 + 4 * 2
    require(calculated_walking_callback_body_count == 5, "WALKING_CALLBACK_COUNT")
    require(calculated_recovery_callback_body_count == 9, "RECOVERY_CALLBACK_COUNT")
    return marker_count + 3


def canonical_sha256(value: Any) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return sha256_bytes(raw)


def initialize_epoch_transport(epoch_start: int) -> dict[str, int]:
    require(epoch_start > 0, "CANARY_EPOCH_START")
    return {
        "epoch_start": epoch_start,
        "cached_global_sequence": epoch_start,
        "accepted_pair_count": 0,
        "state_revision": 0,
    }


def advance_epoch_transport(state: dict[str, int], global_step: int) -> dict[str, int]:
    require(global_step == state["cached_global_sequence"] + 1, "CANARY_TRANSPORT_CONTIGUITY")
    result = dict(state)
    result["cached_global_sequence"] = global_step
    result["accepted_pair_count"] += 1
    result["state_revision"] += 1
    local_step = global_step - result["epoch_start"]
    require(result["accepted_pair_count"] == local_step, "CANARY_TRANSPORT_PAIR_OFFSET")
    require(result["state_revision"] == local_step, "CANARY_TRANSPORT_REVISION_OFFSET")
    return result


def initialize_epoch_accumulator(epoch_start: int) -> dict[str, Any]:
    value = {
        "epoch_start": epoch_start,
        "global_sequence": epoch_start,
        "event_count": 0,
        "cumulative_signed_discrete_staging_exchange_j": 0.0,
        "last_observer_receipt_sha256": None,
        "previous_accumulator_sha256": None,
    }
    value["self_sha256"] = canonical_sha256(value)
    return value


def advance_epoch_accumulator(
    before: dict[str, Any], global_step: int, observer_receipt: dict[str, Any]
) -> dict[str, Any]:
    require(global_step == before["global_sequence"] + 1, "CANARY_ACCUMULATOR_CONTIGUITY")
    require(observer_receipt.get("global_sequence") == global_step, "CANARY_OBSERVER_SEQUENCE")
    require(observer_receipt.get("previous_global_sequence") == global_step - 1, "CANARY_OBSERVER_PREVIOUS")
    observer_sha = canonical_sha256(observer_receipt)
    result = {
        "epoch_start": before["epoch_start"],
        "global_sequence": global_step,
        "event_count": before["event_count"] + 1,
        "cumulative_signed_discrete_staging_exchange_j": (
            float(before["cumulative_signed_discrete_staging_exchange_j"])
            + float(observer_receipt["step_signed_discrete_staging_exchange_j"])
        ),
        "last_observer_receipt_sha256": observer_sha,
        "previous_accumulator_sha256": before["self_sha256"],
    }
    require(result["event_count"] == global_step - result["epoch_start"], "CANARY_ACCUMULATOR_OFFSET")
    result["self_sha256"] = canonical_sha256(result)
    return result


def expect_refusal(action: Any, code: str) -> None:
    try:
        action()
    except AuditFailure:
        return
    raise AuditFailure(code)


def validate_epoch_canaries() -> dict[str, Any]:
    epoch_start = 508
    transport_0 = initialize_epoch_transport(epoch_start)
    transport_1 = advance_epoch_transport(transport_0, 509)
    transport_2 = advance_epoch_transport(transport_1, 510)
    require(transport_2["accepted_pair_count"] == 2, "CANARY_TRANSPORT_FINAL_PAIR")
    refusal_count = 0
    for bad_step in (508, 509, 511):
        expect_refusal(
            lambda bad_step=bad_step: advance_epoch_transport(transport_1, bad_step),
            f"CANARY_TRANSPORT_NOT_REFUSED:{bad_step}",
        )
        refusal_count += 1

    accumulator_0 = initialize_epoch_accumulator(epoch_start)
    observer_1 = {
        "global_sequence": 509,
        "previous_global_sequence": 508,
        "step_signed_discrete_staging_exchange_j": 0.125,
    }
    accumulator_1 = advance_epoch_accumulator(accumulator_0, 509, observer_1)
    observer_2 = {
        "global_sequence": 510,
        "previous_global_sequence": 509,
        "step_signed_discrete_staging_exchange_j": -0.025,
    }
    accumulator_2 = advance_epoch_accumulator(accumulator_1, 510, observer_2)
    require(accumulator_2["event_count"] == 2, "CANARY_ACCUMULATOR_FINAL_COUNT")
    require(math.isclose(accumulator_2["cumulative_signed_discrete_staging_exchange_j"], 0.1), "CANARY_ACCUMULATOR_SUM")
    require(accumulator_2["previous_accumulator_sha256"] == accumulator_1["self_sha256"], "CANARY_ACCUMULATOR_CHAIN")
    for global_step, observer in (
        (509, observer_1),
        (508, {**observer_1, "global_sequence": 508, "previous_global_sequence": 507}),
        (511, {**observer_1, "global_sequence": 511, "previous_global_sequence": 510}),
    ):
        expect_refusal(
            lambda global_step=global_step, observer=observer: advance_epoch_accumulator(
                accumulator_1, global_step, observer
            ),
            f"CANARY_ACCUMULATOR_NOT_REFUSED:{global_step}",
        )
        refusal_count += 1

    # The portable supervisor's existing rule permits any positive first global
    # semantic step, then requires strict global consecutiveness.
    portable_last: int | None = None
    for step in (509, 510):
        if portable_last is not None:
            require(step == portable_last + 1, "CANARY_PORTABLE_CONSECUTIVE")
        portable_last = step
    require(portable_last == 510, "CANARY_PORTABLE_NONZERO_FIRST")

    kick_receipt = {
        "application_method": "RigidBody3D.apply_central_impulse",
        "target_body_id": "torso",
        "global_effect_boundary_sequence": epoch_start,
        "impulse_task_n_s": [0.0, 0.0, 0.25],
        "native_effect_measured": True,
    }
    epoch_binding = {
        "epoch_start": epoch_start,
        "kick_receipt_sha256": canonical_sha256(kick_receipt),
        "initial_mechanical_energy_source": "live_completed_boundary_E",
        "cumulative_external_work_at_epoch_start_j": 0.0,
    }
    require(epoch_binding["kick_receipt_sha256"] == canonical_sha256(kick_receipt), "CANARY_KICK_BINDING")
    require(epoch_binding["cumulative_external_work_at_epoch_start_j"] == 0.0, "CANARY_KICK_LEDGER_EXCLUSION")

    node_population = tuple(object() for _ in range(17))
    before_identity = tuple(id(node) for node in node_population)
    after_identity = tuple(id(node) for node in node_population)
    rebuilt_identity = tuple(id(object()) for _ in range(17))
    require(before_identity == after_identity, "CANARY_SAME_BODY_IDENTITY")
    require(before_identity != rebuilt_identity, "CANARY_REBUILD_NOT_DETECTED")
    return {
        "epoch_start_global_step": epoch_start,
        "first_recovery_global_step": 509,
        "terminal_canary_global_step": 510,
        "terminal_canary_local_step": 2,
        "sequence_refusal_count": refusal_count,
        "same_body_node_identity_count": len(before_identity),
    }


def validate_energy_canary() -> dict[str, float]:
    bodies = (
        {
            "mass": 2.0,
            "position": (0.0, 1.0, 0.0),
            "linear": (3.0, 0.0, 0.0),
            "angular": (0.0, 2.0, 0.0),
            "inertia": (1.0, 2.0, 3.0),
        },
        {
            "mass": 1.0,
            "position": (0.0, 0.5, 0.0),
            "linear": (0.0, 0.0, 2.0),
            "angular": (1.0, 0.0, 0.0),
            "inertia": (0.5, 0.75, 1.0),
        },
    )
    gravity = (0.0, -9.81, 0.0)
    translational = 0.0
    rotational = 0.0
    potential = 0.0
    for body in bodies:
        mass = float(body["mass"])
        linear = body["linear"]
        angular = body["angular"]
        inertia = body["inertia"]
        position = body["position"]
        translational += 0.5 * mass * sum(float(value) ** 2 for value in linear)
        rotational += 0.5 * sum(
            float(angular[index]) ** 2 * float(inertia[index]) for index in range(3)
        )
        potential += -mass * sum(
            float(gravity[index]) * float(position[index]) for index in range(3)
        )
    live_energy = translational + rotational + potential
    reconstructed_world_start_energy = potential
    require(math.isclose(translational, 11.0), "ENERGY_TRANSLATIONAL")
    require(math.isclose(rotational, 4.25), "ENERGY_ROTATIONAL")
    require(math.isclose(potential, 24.525), "ENERGY_POTENTIAL")
    require(math.isclose(live_energy, 39.775), "ENERGY_TOTAL")
    require(not math.isclose(live_energy, reconstructed_world_start_energy), "ENERGY_BASELINE_DISTINCTION")
    return {
        "translational_kinetic_energy_j": translational,
        "rotational_kinetic_energy_j": rotational,
        "gravitational_potential_energy_j": potential,
        "live_boundary_energy_j": live_energy,
    }


def mutated_value(value: Any) -> Any:
    if isinstance(value, bool):
        return not value
    if isinstance(value, int):
        return value + 1
    if isinstance(value, float):
        return value + 0.125
    if isinstance(value, str):
        return value + "_mutated"
    if isinstance(value, list):
        return [*value, "mutation"]
    raise AuditFailure(f"UNSUPPORTED_MUTATION_TYPE:{type(value).__name__}")


def validate_mutation_refusals(design: dict[str, Any]) -> int:
    refused = 0
    for path, expected in EXPECTED_PATH_VALUES.items():
        candidate = copy.deepcopy(design)
        set_dotted(candidate, path, mutated_value(expected))
        expect_refusal(lambda candidate=candidate: validate_design_contract(candidate), f"MUTATION_NOT_REFUSED:{path}")
        refused += 1
    for key, expected in EXPECTED_CLAIM_BOUNDARY.items():
        candidate = copy.deepcopy(design)
        candidate["claim_boundary"][key] = mutated_value(expected)
        expect_refusal(lambda candidate=candidate: validate_design_contract(candidate), f"CLAIM_MUTATION_NOT_REFUSED:{key}")
        refused += 1
    candidate = copy.deepcopy(design)
    candidate["unexpected_top_level"] = True
    expect_refusal(lambda: validate_design_contract(candidate), "TOP_LEVEL_ADDITION_NOT_REFUSED")
    refused += 1
    for mutation_name, mutation in (
        ("authority_sha", lambda value: value["bound_authorities"][0].__setitem__("raw_sha256", "sha256:" + "0" * 64)),
        ("authority_remove", lambda value: value["bound_authorities"].pop()),
        ("authority_duplicate", lambda value: value["bound_authorities"].append(copy.deepcopy(value["bound_authorities"][0]))),
    ):
        candidate = copy.deepcopy(design)
        mutation(candidate)
        expect_refusal(lambda candidate=candidate: validate_design_contract(candidate), f"{mutation_name.upper()}_NOT_REFUSED")
        refused += 1
    return refused


def main() -> int:
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "REPOSITORY_ROOT")
    require(git_text(("rev-parse", "--show-toplevel")) == ROOT.as_posix(), "GIT_TOPLEVEL")
    require(git_text(("remote", "get-url", "origin")) == EXPECTED_REMOTE, "GIT_REMOTE")
    require(git_text(("cat-file", "-t", AUTHORED_PARENT)) == "commit", "AUTHORED_PARENT_COMMIT")

    design_raw = DESIGN_PATH.read_bytes()
    require(len(design_raw) == EXPECTED_DESIGN_BYTES, "DESIGN_BYTES")
    require(sha256_bytes(design_raw) == EXPECTED_DESIGN_SHA256, "DESIGN_SHA256")
    design = read_json(design_raw, "DESIGN")
    validate_design_contract(design)
    loaded = load_bound_authorities(design)
    r10e = validate_r10e_retained_negative(loaded["consumed_r10e_l3_finite_negative"])
    predecessor_authority_count = validate_predecessor_authorities(loaded)
    source_marker_count = validate_source_seams(loaded)
    epoch = validate_epoch_canaries()
    energy = validate_energy_canary()
    mutation_refusal_count = validate_mutation_refusals(design)

    result = {
        "schema_version": "sporespore_qsdk_r10f_continuous_passive_recovery_successor_design_audit_v1",
        "gate_id": "QSDK-R10F",
        "ok": True,
        "design_path": DESIGN_PATH.relative_to(ROOT).as_posix(),
        "design_byte_length": len(design_raw),
        "design_raw_sha256": sha256_bytes(design_raw),
        "bound_authority_count": len(loaded),
        "predecessor_authority_count": predecessor_authority_count,
        "source_seam_marker_count": source_marker_count,
        "design_mutation_refusal_count": mutation_refusal_count,
        "retained_r10e_file_count": r10e["retained_file_count"],
        "retained_r10e_total_byte_length": r10e["retained_byte_length"],
        "retained_r10e_valid_world_count": r10e["valid_world_count"],
        "retained_r10e_valid_pair_count": r10e["valid_pair_count"],
        "retained_r10e_native_effect_pair_count": r10e["native_effect_pair_count"],
        "retained_r10e_local_recovery_window_count": r10e["local_recovery_window_count"],
        "retained_r10e_pre_push_anchor_crossing_world_count": r10e["pre_push_anchor_crossing_world_count"],
        "epoch_start_global_step_canary": epoch["epoch_start_global_step"],
        "first_recovery_global_step_canary": epoch["first_recovery_global_step"],
        "terminal_recovery_local_step_canary": epoch["terminal_canary_local_step"],
        "epoch_sequence_refusal_count": epoch["sequence_refusal_count"],
        "same_body_node_identity_count": epoch["same_body_node_identity_count"],
        "live_energy_canary_j": energy["live_boundary_energy_j"],
        "rotational_energy_canary_j": energy["rotational_kinetic_energy_j"],
        "selected_policy_id": "sporespore_balanced_wave_bw5r_b_v1",
        "selected_recovery_controller_id": "sporespore_exact_s169_prone_to_standing_controller_v6",
        "selected_recovery_kind": "event_triggered_passive_not_force_aware",
        "maximum_active_arm_solver_steps_if_later_authorized": 3_841,
        "q_sdk_r10_satisfied": False,
        "sdk1_m07_satisfied": False,
        "sdk1_score": "14/20",
        "full_program_score": "14/25",
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    print(PASS_MARKER + json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditFailure, FileNotFoundError, OSError) as exc:
        print(f"QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_SUCCESSOR_DESIGN_FAIL {exc}")
        raise SystemExit(1) from exc
