extends "res://tests/test_sdk_qsdk_independent_morphology_v2.gd"
# gdlint: disable=max-line-length
# gdlint: disable=max-returns
# gdlint: disable=max-file-lines

## Paired BW17P portable-plan composition test on the now-outcome-exposed
## R05C cohort.
##
## Both arms retain the exact BW15F-B portable controller. Candidate A keeps
## its R05C P5I.3B shadow/post-settle-full route. Candidate B changes only the
## already-frozen P5I.3C stability policy and its commissioned typed overlay
## route. This is development evidence only; walking remains an observation.

const BW17P_PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw17p_morphology_development_preregistration.json"
const BW17P_CANDIDATES_PATH := "res://sdk/balanced_wave_bw17p_portable_plan_candidates.json"
const BW15F_SELECTED_POLICY_PATH := "res://sdk/balanced_wave_bw15f_selected_policy.json"
const BW17P_CANDIDATE_ENVIRONMENT_VARIABLE := "SPORESPORE_BW17P_CANDIDATE"
const BW17P_CANDIDATE_IDS := ["BW17P-A", "BW17P-B"]
const BW17P_COMPOSITION_DIGESTS := [
	"sha256:7093744b5fe5fcac36b59ba94741fc83b59e42c445d6b01b90711c5f71ba422e",
	"sha256:b25729d73a07007c5cb49d0fe522c3e9e574413ebb19167339091106ca5da212",
]
const BW17P_STABILITY_POLICY_IDS := [
	"p5i3b_weight_support_shadow_v1",
	"sporespore_scheduled_load_transfer_bw13p_a_v3",
]
const BW17P_AUTHORITY_SCOPES := ["post_settle_full", "post_settle_full"]
const BW17P_EXECUTION_MODES := [
	"native_authority_with_legacy_observer",
	"native_balanced_wave_base_with_stability_contribution",
]
const BW17P_CANDIDATES_RAW_SHA256 := "sha256:8f8b44d63acdb58513320a629eedd6709889a4d9f28726c698b2c6f81f910605"
const BW17P_IMPLEMENTATION_PARENT_COMMIT := "56dffd1fbb1533c5cc138109ccf95aa4dae66499"
const BW15F_CONTROLLER_CANDIDATE_ID := "BW15F-B"
const BW15F_CONTROLLER_POLICY_ID := "sporespore_balanced_wave_bw15f_b_v1"
const BW15F_CONTROLLER_POLICY_DIGEST := "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
const BW15F_RUNTIME_PROFILE_SHA256 := "sha256:1134302a1566e12d1e1179beebed893176eeed88065920855026e903738bb413"
const EXPECTED_ACTUATOR_COUNT_BW17P := 8


func _candidate_index() -> int:
	return (
		BW17P_CANDIDATE_IDS
		. find(
			OS.get_environment(BW17P_CANDIDATE_ENVIRONMENT_VARIABLE),
		)
	)


func _candidate_id() -> String:
	var index := _candidate_index()
	return String(BW17P_CANDIDATE_IDS[index]) if index >= 0 else ""


func _candidate_composition_digest() -> String:
	var index := _candidate_index()
	return String(BW17P_COMPOSITION_DIGESTS[index]) if index >= 0 else ""


func _candidate_authority_scope() -> String:
	var index := _candidate_index()
	return String(BW17P_AUTHORITY_SCOPES[index]) if index >= 0 else ""


func _campaign_contract() -> Dictionary:
	return {
		"preregistration_path": BW17P_PREREGISTRATION_PATH,
		"preregistration_schema":
		"sporespore_balanced_wave_bw17p_morphology_development_preregistration_v1",
		"preregistration_status": "frozen_before_first_bw17p_physics_world",
		"campaign_id": "BW17P-MORPHOLOGY-DEVELOPMENT",
		"gate_id": "BW17P",
		"generator_policy_id": ProportionSpecScript.QSDK_R05C_GENERATOR_POLICY_ID,
		"generator_indices": ProportionSpecScript.QSDK_R05C_INDEPENDENT_INDICES,
		"campaign_seeds": [38101, 38102, 38103],
		"generated_receipt_schema": "sporespore_bw17p_development_generated_cells_receipt_v1",
		"entrypoint_receipt_schema": "sporespore_bw17p_development_entrypoint_preflight_v1",
		"cell_receipt_schema": "sporespore_bw17p_morphology_development_cell_v1",
		"generated_prefix": "BW17P_DEVELOPMENT_GENERATED_CELLS ",
		"entrypoint_prefix": "BW17P_DEVELOPMENT_ENTRYPOINT_PREFLIGHT ",
		"cell_prefix": "BW17P_DEVELOPMENT_CELL ",
		"display_name": "BW17P portable-plan composition development",
	}


func _selected_policy_path() -> String:
	return BW15F_SELECTED_POLICY_PATH


func _controller_candidate_id() -> String:
	return BW15F_CONTROLLER_CANDIDATE_ID


func _controller_policy_id() -> String:
	return BW15F_CONTROLLER_POLICY_ID


func _controller_policy_digest() -> String:
	return BW15F_CONTROLLER_POLICY_DIGEST


func _stability_policy_id() -> String:
	var index := _candidate_index()
	return String(BW17P_STABILITY_POLICY_IDS[index]) if index >= 0 else ""


func _expected_full_authority_execution_mode() -> String:
	var index := _candidate_index()
	return String(BW17P_EXECUTION_MODES[index]) if index >= 0 else ""


func _walking_required_for_cell_success() -> bool:
	return false


func _compile_campaign_generation(generator_index: int) -> Dictionary:
	return ProportionSpecScript.compile_qsdk_r05c_generation(generator_index)


func _verify_campaign_generation(
	generator_index: int,
	expected_generator_receipt_sha256: String,
	expected_proportion_spec_sha256: String,
) -> Dictionary:
	return (
		ProportionSpecScript
		. verify_qsdk_r05c_generation(
			generator_index,
			expected_generator_receipt_sha256,
			expected_proportion_spec_sha256,
		)
	)


func _validate_controller_policy_contract(
	preregistration: Dictionary,
	selected_policy: Dictionary,
) -> bool:
	var index := _candidate_index()
	if index < 0:
		return false
	var declarations := _read_json(BW17P_CANDIDATES_PATH)
	var candidates: Array = declarations.get("candidates", [])
	var candidate_digests: Dictionary = (
		declarations
		. get(
			"candidate_composition_digests",
			{},
		)
	)
	var prereg_digests: Dictionary = (
		preregistration
		. get(
			"candidate_composition_digests",
			{},
		)
	)
	if candidates.size() != 2:
		return false
	var candidate: Dictionary = candidates[index]
	var selected_profile: Dictionary = selected_policy.get("selected_profile", {})
	var declaration_reference: Dictionary = (
		preregistration
		. get(
			"candidate_declarations",
			{},
		)
	)
	return (
		String(selected_policy.get("selected_candidate_id", "")) == BW15F_CONTROLLER_CANDIDATE_ID
		and String(selected_policy.get("selected_policy_id", "")) == BW15F_CONTROLLER_POLICY_ID
		and (
			String(selected_policy.get("selected_candidate_policy_digest", ""))
			== BW15F_CONTROLLER_POLICY_DIGEST
		)
		and (
			String(selected_profile.get("runtime_profile_sha256", ""))
			== BW15F_RUNTIME_PROFILE_SHA256
		)
		and (selected_profile.get("branch_surfaces", []) as Array).is_empty()
		and int(selected_profile.get("morphology_condition_count", -1)) == 0
		and int(selected_profile.get("material_condition_count", -1)) == 0
		and int(selected_profile.get("seed_condition_count", -1)) == 0
		and int(selected_profile.get("failure_identity_condition_count", -1)) == 0
		and int(selected_profile.get("outcome_condition_count", -1)) == 0
		and (
			String(declarations.get("schema_version", ""))
			== "sporespore_balanced_wave_bw17p_portable_plan_candidates_v1"
		)
		and String(declarations.get("status", "")) == "frozen_before_first_bw17p_physics_world"
		and (declarations.get("candidate_order", []) as Array) == BW17P_CANDIDATE_IDS
		and (
			String(declarations.get("implementation_parent_commit", ""))
			== BW17P_IMPLEMENTATION_PARENT_COMMIT
		)
		and (
			String(declaration_reference.get("path", ""))
			== "sdk/balanced_wave_bw17p_portable_plan_candidates.json"
		)
		and String(declaration_reference.get("raw_sha256", "")) == BW17P_CANDIDATES_RAW_SHA256
		and _raw_sha256(BW17P_CANDIDATES_PATH) == BW17P_CANDIDATES_RAW_SHA256
		and String(candidate.get("candidate_id", "")) == _candidate_id()
		and String(candidate.get("controller_candidate_id", "")) == BW15F_CONTROLLER_CANDIDATE_ID
		and String(candidate.get("controller_policy_id", "")) == BW15F_CONTROLLER_POLICY_ID
		and String(candidate.get("controller_policy_digest", "")) == BW15F_CONTROLLER_POLICY_DIGEST
		and String(candidate.get("stability_policy_id", "")) == _stability_policy_id()
		and bool(candidate.get("feedback_enabled", index == 0)) == (index == 1)
		and bool(candidate.get("physical_overlay_enabled", index == 0)) == (index == 1)
		and (
			String(candidate.get("feedback_gain_source", ""))
			== "portable_core_bw13p_a_v3_shared_baseline_plan"
		)
		and bool(candidate.get("portable_plan_enabled", index == 0)) == (index == 1)
		and (
			String(candidate.get("portable_plan_operation", ""))
			== ("plan_scheduled_load_transfer_v3_json" if index == 1 else "not_requested")
		)
		and (
			String(candidate.get("portable_plan_receipt_schema_version", ""))
			== ("sporespore_scheduled_load_transfer_receipt_v3" if index == 1 else "")
		)
		and bool(candidate.get("stability_contribution_authority", index == 0)) == (index == 1)
		and int(candidate.get("morphology_condition_count", -1)) == 0
		and int(candidate.get("material_condition_count", -1)) == 0
		and int(candidate.get("seed_condition_count", -1)) == 0
		and int(candidate.get("failure_identity_condition_count", -1)) == 0
		and int(candidate.get("outcome_condition_count", -1)) == 0
		and (candidate.get("branch_surfaces", []) as Array).is_empty()
		and not bool(candidate.get("physical_acceptance_authority", true))
		and String(candidate_digests.get(_candidate_id(), "")) == _candidate_composition_digest()
		and String(prereg_digests.get(_candidate_id(), "")) == _candidate_composition_digest()
		and CanonicalJsonScript.sha256(candidate) == _candidate_composition_digest()
	)


func _validate_contract(
	preregistration: Dictionary,
	selected_policy: Dictionary,
) -> bool:
	if not super._validate_contract(preregistration, selected_policy):
		return false
	var predecessor: Dictionary = preregistration.get("predecessor_interlocks", {})
	var hypothesis: Dictionary = preregistration.get("controlled_hypothesis", {})
	var portable_plan: Dictionary = preregistration.get("portable_plan_profile", {})
	var repetitions: Dictionary = preregistration.get("repetitions", {})
	var eligibility: Dictionary = (
		preregistration
		. get(
			"mechanism_receipt_eligibility",
			{},
		)
	)
	var aggregation: Dictionary = preregistration.get("report_aggregation", {})
	var selection: Dictionary = preregistration.get("selection", {})
	var claims: Dictionary = preregistration.get("claim_boundary", {})
	return (
		(
			String(preregistration.get("implementation_parent_commit", ""))
			== BW17P_IMPLEMENTATION_PARENT_COMMIT
		)
		and (
			String(preregistration.get("campaign_role", ""))
			== "paired_outcome_exposed_portable_core_plan_composition_development"
		)
		and bool(preregistration.get("development_data_only", false))
		and not bool(preregistration.get("development_candidate_selected", true))
		and (
			String(preregistration.get("selected_controller_candidate_id", ""))
			== BW15F_CONTROLLER_CANDIDATE_ID
		)
		and (
			String(preregistration.get("selected_controller_policy_id", ""))
			== BW15F_CONTROLLER_POLICY_ID
		)
		and (
			String(preregistration.get("selected_controller_policy_digest", ""))
			== BW15F_CONTROLLER_POLICY_DIGEST
		)
		and int(preregistration.get("policy_branch_surface_count", -1)) == 0
		and String(predecessor.get("qsdk_r05c_status", "")) == "rejected_complete_result"
		and not bool(predecessor.get("qsdk_r05c_accepted", true))
		and int(predecessor.get("qsdk_r05c_expected_world_count", -1)) == 36
		and int(predecessor.get("qsdk_r05c_integrity_pass_count", -1)) == 36
		and int(predecessor.get("qsdk_r05c_mechanism_pass_count", -1)) == 36
		and int(predecessor.get("qsdk_r05c_combined_application_pass_count", -1)) == 36
		and int(predecessor.get("qsdk_r05c_walking_pass_count", -1)) == 29
		and int(predecessor.get("qsdk_r05c_failed_cell_count", -1)) == 7
		and int(predecessor.get("qsdk_r05c_raw_false_walking_receipt_count", -1)) == 25
		and bool(predecessor.get("cohort_is_now_outcome_exposed", false))
		and bool(predecessor.get("cohort_may_be_reused_only_for_development", false))
		and bool(predecessor.get("failure_identity_conditioning_forbidden", false))
		and bool(
			(
				predecessor
				. get(
					"later_independent_validation_requires_unopened_morphologies_and_fresh_seeds",
					false,
				)
			)
		)
		and not bool(predecessor.get("unbiased_friction_reservation_opened", true))
		and bool(hypothesis.get("controller_held_identical", false))
		and bool(hypothesis.get("material_held_identical", false))
		and bool(hypothesis.get("morphology_seed_pairing_held_identical", false))
		and (
			String(hypothesis.get("control_stability_policy_id", ""))
			== String(BW17P_STABILITY_POLICY_IDS[0])
		)
		and (
			String(hypothesis.get("treatment_stability_policy_id", ""))
			== String(BW17P_STABILITY_POLICY_IDS[1])
		)
		and (
			String(hypothesis.get("control_authority_scope", ""))
			== String(BW17P_AUTHORITY_SCOPES[0])
		)
		and (
			String(hypothesis.get("treatment_authority_scope", ""))
			== String(BW17P_AUTHORITY_SCOPES[1])
		)
		and int(hypothesis.get("new_tunable_gain_count", -1)) == 0
		and int(hypothesis.get("morphology_condition_count", -1)) == 0
		and int(hypothesis.get("material_condition_count", -1)) == 0
		and int(hypothesis.get("seed_condition_count", -1)) == 0
		and int(hypothesis.get("failure_identity_condition_count", -1)) == 0
		and int(hypothesis.get("outcome_condition_count", -1)) == 0
		and (hypothesis.get("branch_surfaces", []) as Array).is_empty()
		and bool(
			(
				hypothesis
				. get(
					"portable_core_owns_controller_centroidal_plan_mapping_and_bounded_stability_contribution",
					false,
				)
			)
		)
		and bool(
			(
				hypothesis
				. get(
					"godot_adapter_owns_only_state_marshalling_characterized_actuator_conversion_bounded_composition_and_motor_write",
					false,
				)
			)
		)
		and bool(hypothesis.get("host_specific_balance_policy_or_gain_forbidden", false))
		and (
			String(portable_plan.get("source_policy_id", ""))
			== String(BW17P_STABILITY_POLICY_IDS[1])
		)
		and (
			String(portable_plan.get("plan_operation", ""))
			== "plan_scheduled_load_transfer_v3_json"
		)
		and (
			String(portable_plan.get("receipt_schema_version", ""))
			== "sporespore_scheduled_load_transfer_receipt_v3"
		)
		and String(portable_plan.get("mode", "")) == "control"
		and not bool(portable_plan.get("preferred_normal_force_factor", true))
		and not bool(portable_plan.get("remaining_support_centroid_factor", true))
		and bool(portable_plan.get("shared_baseline_centroidal_command", false))
		and bool(portable_plan.get("total_preferred_normal_force_conserved", false))
		and bool(portable_plan.get("activation_uses_scheduler_boundaries_only", false))
		and int(portable_plan.get("new_tunable_gain_count", -1)) == 0
		and not bool(portable_plan.get("fit_to_qsdk_r05c_or_bw16s_outcomes", true))
		and int(repetitions.get("expected_world_count_per_candidate", -1)) == 36
		and int(repetitions.get("expected_complete_world_count", -1)) == 72
		and bool(repetitions.get("early_stop_for_outcome_forbidden", false))
		and bool(
			(
				repetitions
				. get(
					"first_complete_result_is_final_for_each_candidate_source_identity",
					false,
				)
			)
		)
		and bool(
			(
				eligibility
				. get(
					"all_cells_require_bw15f_b_forward_velocity_receipt_per_sdk_step",
					false,
				)
			)
		)
		and bool(
			(
				eligibility
				. get(
					"candidate_a_requires_zero_overlay_application_steps_and_motor_writes",
					false,
				)
			)
		)
		and bool(
			(
				eligibility
				. get(
					"candidate_b_requires_one_typed_contribution_attempt_per_sdk_step",
					false,
				)
			)
		)
		and bool(
			(
				eligibility
				. get(
					"candidate_b_requires_eight_final_motor_writes_per_sdk_step",
					false,
				)
			)
		)
		and bool(
			(
				eligibility
				. get(
					"candidate_b_requires_nonzero_effective_stability_application",
					false,
				)
			)
		)
		and bool(
			(
				aggregation
				. get(
					"each_cell_must_export_exact_raw_false_walking_gate_count",
					false,
				)
			)
		)
		and bool(aggregation.get("each_cell_must_export_exact_release_timeout_count", false))
		and bool(
			(
				aggregation
				. get(
					"perfect_all_zero_36_cell_matrix_must_pass_exact_production_aggregate_gate",
					false,
				)
			)
		)
		and (
			(selection.get("metric_order", []) as Array)
			== [
				"walking_conjunction_failure_count",
				"aggregate_failed_production_walking_gate_count",
				"aggregate_release_timeout_count",
				"maximum_normalized_absolute_task_frame_lateral_displacement",
				"aggregate_normalized_absolute_task_frame_lateral_displacement",
				"aggregate_cumulative_absolute_cross_track_error_m_s",
			]
		)
		and bool(selection.get("all_candidate_reports_required", false))
		and bool(
			(
				selection
				. get(
					"all_reports_require_36_of_36_integrity_mechanism_and_combined_application",
					false,
				)
			)
		)
		and bool(
			(
				selection
				. get(
					"treatment_must_be_strictly_lexicographically_better_than_control",
					false,
				)
			)
		)
		and bool(selection.get("tie_or_control_win_rejects_treatment", false))
		and not bool(claims.get("walking_acceptance", true))
		and not bool(claims.get("balance_improvement", true))
		and not bool(claims.get("independent_morphology_validation", true))
		and bool(claims.get("finite_outcome_exposed_development_cohort_only", false))
		and not bool(claims.get("completed_engine_neutral_sdk", true))
		and not bool(claims.get("physical_acceptance_authority", true))
	)


func _prepare_cell(generator_index: int) -> Dictionary:
	var prepared := super._prepare_cell(generator_index)
	if not bool(prepared.get("ok", false)):
		return prepared
	var authority_options: Dictionary = (
		(prepared.get("authority_options", {}) as Dictionary).duplicate(true)
	)
	authority_options["authority_scope"] = _candidate_authority_scope()
	authority_options["stability_policy_id"] = _stability_policy_id()
	authority_options["controller_policy_id"] = _controller_policy_id()
	prepared["authority_options"] = authority_options
	return prepared


func _preflight_selected_policy_full_authority_start(
	prepared: Dictionary,
	initial_perturbation: Dictionary,
) -> Dictionary:
	var root_child_count_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var requested_phase_offset_ticks := int(initial_perturbation["gait_phase_offset_ticks"])
	var scope := _candidate_authority_scope()
	var execution_mode_plan := (
		WaveGaitScript
		. compile_sdk_execution_mode_plan(
			true,
			true,
			scope,
			_stability_policy_id(),
			requested_phase_offset_ticks,
		)
	)
	if not bool(execution_mode_plan.get("ok", false)):
		return execution_mode_plan
	var initial_gait_steps: Dictionary = (
		(execution_mode_plan.get("zero_base_initial_gait_steps", {}) as Dictionary).duplicate(true)
	)
	var adapter: RefCounted = AdapterScript.new()
	var start: Dictionary = (
		adapter
		. start(
			(prepared["authority_options"] as Dictionary)["descriptor"],
			initial_gait_steps,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			float(initial_perturbation["fixture_yaw_rad"]),
			120,
			SOLVER_POLICY_OPTIONS,
			SDK_COMPARISON_TOLERANCE,
			"clocked",
			true,
			requested_phase_offset_ticks,
			360,
			scope,
			_stability_policy_id(),
			prepared["material_profile"],
			_controller_policy_id(),
		)
	)
	var declared_policy_runtime_boundary: Dictionary = {}
	if bool(start.get("ok", false)):
		declared_policy_runtime_boundary = (
			adapter.preflight_perfect_declared_policy_runtime_boundary()
		)
	var manifest: Dictionary = start.get("adapter_manifest", {})
	var stability_v3: Dictionary = manifest.get("stability_v3", {})
	var feedback_policy: Dictionary = stability_v3.get("feedback_policy", {})
	var physical_overlay: Dictionary = stability_v3.get("physical_overlay", {})
	var scene_tree_insertion_count := root.get_child_count() - root_child_count_before
	var physics_state_modified := Engine.physics_ticks_per_second != physics_hz_before
	var index := _candidate_index()
	var route_exact := false
	if index == 0:
		route_exact = (
			bool(execution_mode_plan.get("full_post_settle_authority_enabled", false))
			and not bool(execution_mode_plan.get("stability_contribution_overlay_enabled", true))
			and not bool(execution_mode_plan.get("fixed_exposure_enabled", true))
			and not bool(execution_mode_plan.get("legacy_base_motor_writes_allowed", true))
			and bool(
				(
					execution_mode_plan
					. get(
						"exclusive_native_post_settle_motor_writes_required",
						false,
					)
				)
			)
			and (
				String(execution_mode_plan.get("phase_offset_application_mode", ""))
				== "scheduled_once_at_warmup_boundary"
			)
			and not bool(feedback_policy.get("enabled", true))
			and not bool(physical_overlay.get("enabled", true))
		)
	elif index == 1:
		route_exact = (
			bool(execution_mode_plan.get("full_post_settle_authority_enabled", false))
			and not bool(execution_mode_plan.get("stability_contribution_overlay_enabled", true))
			and not bool(execution_mode_plan.get("fixed_exposure_enabled", true))
			and bool(
				(
					execution_mode_plan
					. get(
						"exclusive_native_post_settle_motor_writes_required",
						false,
					)
				)
			)
			and bool(
				(
					execution_mode_plan
					. get(
						"full_authority_stability_contribution_enabled",
						false,
					)
				)
			)
			and not bool(execution_mode_plan.get("legacy_base_motor_writes_allowed", true))
			and (
				String(execution_mode_plan.get("phase_offset_application_mode", ""))
				== "scheduled_once_at_warmup_boundary"
			)
			and bool(feedback_policy.get("enabled", false))
			and bool(physical_overlay.get("enabled", false))
			and (
				String(physical_overlay.get("base_command", ""))
				== "portable_balanced_wave_ordered_command"
			)
		)
	var exact := (
		index >= 0
		and bool(start.get("ok", false))
		and String(start.get("controller_policy_id", "")) == _controller_policy_id()
		and String(start.get("authority_scope", "")) == scope
		and bool(start.get("actuation_authority", false))
		and String(start.get("stability_policy_id", "")) == _stability_policy_id()
		and String(manifest.get("controller_policy_id", "")) == _controller_policy_id()
		and String(manifest.get("authority_scope", "")) == scope
		and bool(manifest.get("actuation_authority", false))
		and String(manifest.get("execution_mode", "")) == _expected_full_authority_execution_mode()
		and int(start.get("world_build_count", -1)) == 0
		and route_exact
		and bool(declared_policy_runtime_boundary.get("ok", false))
		and (
			String(declared_policy_runtime_boundary.get("controller_policy_id", ""))
			== _controller_policy_id()
		)
		and (
			String(declared_policy_runtime_boundary.get("stability_policy_id", ""))
			== _stability_policy_id()
		)
		and (
			int(declared_policy_runtime_boundary.get("requested_phase_offset_ticks", -99))
			== requested_phase_offset_ticks
		)
		and int(declared_policy_runtime_boundary.get("actual_world_build_count", -1)) == 0
		and not bool(declared_policy_runtime_boundary.get("locomotion_outcome_exposed", true))
		and scene_tree_insertion_count == 0
		and not physics_state_modified
		and not bool(start.get("physical_acceptance_authority", true))
	)
	return {
		"schema_version": "sporespore_bw17p_candidate_adapter_start_preflight_v1",
		"ok": exact,
		"failure_code": "" if exact else "BW17P_CANDIDATE_ADAPTER_START_INVALID",
		"candidate_id": _candidate_id(),
		"candidate_composition_digest": _candidate_composition_digest(),
		"controller_policy_id": String(start.get("controller_policy_id", "")),
		"authority_scope": String(start.get("authority_scope", "")),
		"actuation_authority": bool(start.get("actuation_authority", false)),
		"stability_policy_id": String(start.get("stability_policy_id", "")),
		"adapter_capability_sha256": String(start.get("adapter_capability_sha256", "")),
		"requested_phase_offset_ticks": requested_phase_offset_ticks,
		"sdk_execution_mode_plan": execution_mode_plan.duplicate(true),
		"sdk_execution_mode_plan_passed": bool(execution_mode_plan.get("ok", false)),
		"declared_policy_runtime_boundary_preflight":
		declared_policy_runtime_boundary.duplicate(true),
		"declared_policy_runtime_boundary_preflight_passed":
		bool(declared_policy_runtime_boundary.get("ok", false)),
		"feedback_policy": feedback_policy.duplicate(true),
		"physical_overlay": physical_overlay.duplicate(true),
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": scene_tree_insertion_count,
		"physics_state_modified": physics_state_modified,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


func _physical_cell_receipt(
	cell: Dictionary,
	seed: int,
	summary: Dictionary,
) -> Dictionary:
	var receipt := super._physical_cell_receipt(cell, seed, summary)
	var index := _candidate_index()
	var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var sdk_steps := int(sdk_summary.get("step_count", -1))
	var expected_motor_writes := sdk_steps * EXPECTED_ACTUATOR_COUNT_BW17P
	var walking_gates: Dictionary = summary.get("walking_gate_receipts", {})
	var start_result: Dictionary = summary.get("sdk_authority_start_result", {})
	var manifest: Dictionary = start_result.get("adapter_manifest", {})
	var stability_v3: Dictionary = manifest.get("stability_v3", {})
	var feedback_policy: Dictionary = stability_v3.get("feedback_policy", {})
	var physical_overlay_manifest: Dictionary = stability_v3.get("physical_overlay", {})
	var controller_mechanism: Dictionary = (
		sdk_summary
		. get(
			"forward_velocity_foot_placement_summary",
			{},
		)
	)
	var load_transfer: Dictionary = (
		sdk_summary
		. get(
			"scheduled_load_transfer_summary",
			{},
		)
	)
	var contribution: Dictionary = (
		sdk_summary
		. get(
			"stability_contribution_shadow_summary",
			{},
		)
	)
	var overlay: Dictionary = sdk_summary.get("stability_overlay_summary", {})
	var direct_body_write_count := (
		int(summary.get("direct_torso_force_command_count", -1))
		+ int(summary.get("direct_torso_impulse_command_count", -1))
		+ int(summary.get("direct_torso_velocity_command_count", -1))
		+ int(summary.get("direct_torso_transform_command_count", -1))
	)
	var controller_mechanism_exact := (
		(
			String(controller_mechanism.get("schema_version", ""))
			== "sporespore_forward_velocity_foot_placement_execution_summary_v1"
		)
		and bool(controller_mechanism.get("enabled", false))
		and String(controller_mechanism.get("mode_id", "")) == "forward_velocity_foot_placement_v1"
		and (
			String(controller_mechanism.get("velocity_error_orientation_id", ""))
			== "desired_minus_measured_forward_velocity_error_v1"
		)
		and int(controller_mechanism.get("receipt_count", -1)) == sdk_steps
		and int(controller_mechanism.get("morphology_branch_surface_count", -1)) == 0
		and bool(controller_mechanism.get("controller_parameter", false))
		and is_finite(
			float(
				(
					controller_mechanism
					. get(
						"maximum_absolute_normalized_forward_velocity_error",
						NAN,
					)
				)
			)
		)
		and (
			float(
				(
					controller_mechanism
					. get(
						"maximum_absolute_normalized_forward_velocity_error",
						NAN,
					)
				)
			)
			<= 1.0 + 1.0e-12
		)
		and is_finite(
			float(
				(
					controller_mechanism
					. get(
						"maximum_absolute_hip_target_correction_rad",
						NAN,
					)
				)
			)
		)
		and (
			float(
				(
					controller_mechanism
					. get(
						"maximum_absolute_hip_target_correction_rad",
						NAN,
					)
				)
			)
			<= 0.03 + 1.0e-12
		)
		and is_equal_approx(
			float(
				(
					controller_mechanism
					. get(
						"maximum_declared_hip_target_correction_rad",
						NAN,
					)
				)
			),
			0.03
		)
		and not bool(controller_mechanism.get("walking_claim_authorized", true))
		and not bool(controller_mechanism.get("physical_acceptance_authority", true))
	)
	var common_execution := (
		index >= 0
		and int(summary.get("world_build_count", -1)) == 1
		and String(summary.get("physics_engine", "")) == "Jolt Physics"
		and int(summary.get("physics_hz", -1)) == 120
		and int(summary.get("solver_velocity_steps", -1)) == 20
		and int(summary.get("solver_position_steps", -1)) == 7
		and int(summary.get("body_count", -1)) == 9
		and int(summary.get("limb_count", -1)) == 4
		and int(summary.get("world_reset_count", -1)) == 0
		and direct_body_write_count == 0
		and bool(summary.get("sdk_authority_enabled", false))
		and String(summary.get("sdk_authority_scope", "")) == _candidate_authority_scope()
		and String(summary.get("sdk_authority_failure_code", "")).is_empty()
		and bool(sdk_summary.get("ok", false))
		and bool(sdk_summary.get("actuation_authority", false))
		and String(sdk_summary.get("controller_policy_id", "")) == BW15F_CONTROLLER_POLICY_ID
		and String(sdk_summary.get("stability_policy_id", "")) == _stability_policy_id()
		and String(sdk_summary.get("authority_scope", "")) == _candidate_authority_scope()
		and sdk_steps > 0
		and (
			int(sdk_summary.get("validated_balanced_wave_command_count", -1))
			== expected_motor_writes
		)
		and int(sdk_summary.get("native_actuation_application_count", -1)) == expected_motor_writes
		and int(sdk_summary.get("mismatch_count", -1)) == 0
		and int(sdk_summary.get("safe_no_actuation_count", -1)) == 0
		and int(sdk_summary.get("native_safe_disable_application_count", -1)) == 0
		and String(manifest.get("execution_mode", "")) == _expected_full_authority_execution_mode()
	)
	var stability_mechanism_exact := false
	var combined_application_exact := false
	if index == 0:
		stability_mechanism_exact = (
			not bool(feedback_policy.get("enabled", true))
			and not bool(physical_overlay_manifest.get("enabled", true))
			and (
				String(overlay.get("schema_version", ""))
				== "sporespore_godot_jolt_stability_overlay_summary_v1"
			)
			and bool(overlay.get("ok", false))
			and String(overlay.get("policy_id", "")) == _stability_policy_id()
			and int(overlay.get("application_step_count", -1)) == 0
			and int(overlay.get("motor_write_count", -1)) == 0
			and int(overlay.get("failure_count", -1)) == 0
			and not bool(overlay.get("physical_influence", true))
		)
		combined_application_exact = (
			common_execution
			and int(summary.get("legacy_post_settle_actuation_application_count", -1)) == 0
			and int(summary.get("legacy_evidence_actuation_application_count", -1)) == 0
			and int(summary.get("legacy_sdk_overlay_base_application_count", -1)) == 0
			and not bool(summary.get("sdk_p5i3c_fixed_exposure_enabled", true))
			and bool(
				(
					walking_gates
					. get(
						"native_sdk_exclusive_post_settle_actuation",
						false,
					)
				)
			)
		)
	elif index == 1:
		stability_mechanism_exact = (
			bool(feedback_policy.get("enabled", false))
			and (
				String(feedback_policy.get("portable_plan_operation", ""))
				== "plan_scheduled_load_transfer_v3_json"
			)
			and bool(load_transfer.get("enabled", false))
			and String(load_transfer.get("policy_id", "")) == _stability_policy_id()
			and (
				String(load_transfer.get("portable_plan_operation", ""))
				== "plan_scheduled_load_transfer_v3_json"
			)
			and (
				String(load_transfer.get("receipt_schema_version", ""))
				== "sporespore_scheduled_load_transfer_receipt_v3"
			)
			and int(load_transfer.get("receipt_count", -1)) == sdk_steps
			and int(load_transfer.get("receipt_count", -1)) > 0
			and int(load_transfer.get("active_step_count", -1)) == 0
			and int(load_transfer.get("preferred_normal_step_count", -1)) == 0
			and int(load_transfer.get("remaining_centroid_step_count", -1)) == 0
			and (
				(
					int(load_transfer.get("available_receipt_count", -1))
					+ int(load_transfer.get("observation_unavailable_receipt_count", -1))
					+ int(load_transfer.get("upstream_infeasible_receipt_count", -1))
				)
				== sdk_steps
			)
			and (
				int(load_transfer.get("fail_zero_receipt_count", -1))
				== (
					int(load_transfer.get("observation_unavailable_receipt_count", -1))
					+ int(load_transfer.get("upstream_infeasible_receipt_count", -1))
				)
			)
			and bool(load_transfer.get("activation_uses_scheduler_boundaries_only", false))
			and int(load_transfer.get("morphology_branch_surface_count", -1)) == 0
			and bool(physical_overlay_manifest.get("enabled", false))
			and (
				String(physical_overlay_manifest.get("base_command", ""))
				== "portable_balanced_wave_ordered_command"
			)
			and (
				String(contribution.get("schema_version", ""))
				== "sporespore_godot_jolt_stability_contribution_shadow_summary_v1"
			)
			and bool(contribution.get("ok", false))
			and int(contribution.get("attempt_count", -1)) == sdk_steps
			and int(contribution.get("influence_output_count", -1)) == expected_motor_writes
			and int(contribution.get("untyped_count", -1)) == 0
			and int(contribution.get("profile_conversion_failure_count", -1)) == 0
			and int(contribution.get("limiter_mismatch_count", -1)) == 0
			and int(contribution.get("inactive_zero_mismatch_count", -1)) == 0
			and int(contribution.get("mismatch_count", -1)) == 0
			and (contribution.get("failure_codes", []) as Array).is_empty()
			and int(contribution.get("feedback_nonzero_attempt_count", 0)) > 0
		)
		combined_application_exact = (
			common_execution
			and bool(summary.get("sdk_full_authority_stability_contribution_enabled", false))
			and not bool(summary.get("sdk_p5i3c_fixed_exposure_enabled", true))
			and int(summary.get("legacy_sdk_overlay_base_application_count", -1)) == 0
			and int(summary.get("legacy_post_settle_actuation_application_count", -1)) == 0
			and int(summary.get("legacy_evidence_actuation_application_count", -1)) == 0
			and (
				String(overlay.get("schema_version", ""))
				== "sporespore_godot_jolt_stability_overlay_summary_v1"
			)
			and bool(overlay.get("ok", false))
			and String(overlay.get("policy_id", "")) == _stability_policy_id()
			and String(overlay.get("authority_scope", "")) == "post_settle_full"
			and int(overlay.get("application_step_count", -1)) == sdk_steps
			and int(overlay.get("motor_write_count", -1)) == expected_motor_writes
			and (
				int(overlay.get("portable_controller_base_application_count", -1))
				== expected_motor_writes
			)
			and int(overlay.get("nonzero_effective_application_count", 0)) > 0
			and int(overlay.get("combined_speed_limit_violation_count", -1)) == 0
			and int(overlay.get("failure_count", -1)) == 0
			and (overlay.get("failure_codes", []) as Array).is_empty()
			and bool(overlay.get("physical_influence", false))
			and bool(sdk_summary.get("stability_overlay_runtime_ok", false))
			and bool(
				(
					walking_gates
					. get(
						"native_sdk_exclusive_post_settle_actuation",
						false,
					)
				)
			)
		)
	var mechanism_exact := controller_mechanism_exact and stability_mechanism_exact
	var prepared := _prepare_cell(int(cell["generator_index"]))
	var lateral_bound := float(
		(
			(prepared.get("evidence_threshold_options", {}) as Dictionary)
			. get(
				"maximum_lateral_drift_m",
				NAN,
			)
		)
	)
	var lateral_displacement := absf(
		float(receipt.get("final_task_frame_lateral_displacement_m", NAN))
	)
	var normalized_lateral := (
		lateral_displacement / lateral_bound
		if is_finite(lateral_displacement) and is_finite(lateral_bound) and lateral_bound > 0.0
		else NAN
	)
	var cumulative_cross_track := float(
		sdk_summary.get("cumulative_absolute_cross_track_error_m_s", NAN)
	)
	common_execution = (
		common_execution and is_finite(normalized_lateral) and is_finite(cumulative_cross_track)
	)
	var failed_walking_gate_count := 0
	for gate_value in walking_gates.values():
		if typeof(gate_value) != TYPE_BOOL or not bool(gate_value):
			failed_walking_gate_count += 1
	var release_timeout_count := 0
	for timeout_value in (
		(summary.get("contact_gate_timeout_count_by_limb", {}) as Dictionary).values()
	):
		release_timeout_count += int(timeout_value)
	var walking_observed := (
		common_execution
		and _all_true(walking_gates)
		and bool(summary.get("physical_wave_gait_walking_observed", false))
		and bool(summary.get("ok", false))
		and String(summary.get("failure_code", "")).is_empty()
	)
	receipt["campaign_role"] = ("paired_outcome_exposed_portable_core_plan_composition_development")
	receipt["candidate_id"] = _candidate_id()
	receipt["candidate_composition_digest"] = _candidate_composition_digest()
	receipt["selected_candidate_id"] = BW15F_CONTROLLER_CANDIDATE_ID
	receipt["selected_policy_digest"] = BW15F_CONTROLLER_POLICY_DIGEST
	receipt["controller_policy_id"] = BW15F_CONTROLLER_POLICY_ID
	receipt["stability_policy_id"] = _stability_policy_id()
	receipt["authority_scope"] = _candidate_authority_scope()
	receipt["execution_mode"] = _expected_full_authority_execution_mode()
	receipt["common_execution_integrity"] = common_execution
	receipt["walking_observed"] = walking_observed
	receipt["mechanism_gate_passed"] = mechanism_exact
	receipt["combined_application_gate_passed"] = combined_application_exact
	receipt["forward_velocity_foot_placement_summary"] = controller_mechanism.duplicate(true)
	receipt["stability_feedback_policy_manifest"] = feedback_policy.duplicate(true)
	receipt["stability_physical_overlay_manifest"] = (physical_overlay_manifest.duplicate(true))
	receipt["stability_contribution_shadow_summary"] = contribution.duplicate(true)
	receipt["scheduled_load_transfer_summary"] = load_transfer.duplicate(true)
	receipt["stability_overlay_summary"] = overlay.duplicate(true)
	receipt["failed_production_walking_gate_count"] = failed_walking_gate_count
	receipt["release_timeout_count"] = release_timeout_count
	receipt["maximum_lateral_drift_bound_m"] = lateral_bound
	receipt["normalized_absolute_task_frame_lateral_displacement"] = (
		normalized_lateral if is_finite(normalized_lateral) else null
	)
	receipt["cumulative_absolute_cross_track_error_m_s"] = (
		cumulative_cross_track if is_finite(cumulative_cross_track) else null
	)
	receipt["legacy_overlay_base_motor_write_count"] = int(
		summary.get("legacy_sdk_overlay_base_application_count", -1)
	)
	receipt["legacy_post_settle_motor_write_count"] = int(
		summary.get("legacy_post_settle_actuation_application_count", -1)
	)
	receipt["legacy_evidence_motor_write_count"] = int(
		summary.get("legacy_evidence_actuation_application_count", -1)
	)
	receipt["development_selection_authority"] = true
	receipt["walking_acceptance"] = false
	receipt["balance_improvement"] = false
	receipt["independent_morphology_validation"] = false
	receipt["physical_acceptance_authority"] = false
	return receipt


static func _raw_sha256(resource_path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var bytes := FileAccess.get_file_as_bytes(absolute_path)
	if bytes.is_empty():
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(bytes) != OK:
		return ""
	return "sha256:" + context.finish().hex_encode()
