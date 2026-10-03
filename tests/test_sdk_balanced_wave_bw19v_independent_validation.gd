extends "res://tests/test_sdk_balanced_wave_bw17p_morphology_development.gd"
# gdlint: disable=max-line-length
# gdlint: disable=max-returns
# gdlint: disable=max-file-lines

## Two-arm BW19V independent morphology validation test.
##
## This reuses the production walking gates, but opens a prospectively frozen
## cohort that was not used by BW18G. Both arms use the exact same BW15F-B
## controller, BW13P-A portable plan, full native authority, material, and
## seeded perturbations. Only one core-owned global scale varies.

const Bw19CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const BW19V_PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw19v_independent_validation_preregistration.json"
const BW19V_CANDIDATES_PATH := "res://sdk/balanced_wave_bw19v_validation_candidates.json"
const BW19V_CANDIDATE_ENVIRONMENT_VARIABLE := "SPORESPORE_BW19V_CANDIDATE"
const BW19V_CANDIDATE_IDS := ["BW19V-A", "BW19V-B"]
const BW19V_GLOBAL_SCALES := [0.0, 0.5]
const BW19V_COMPOSITION_DIGESTS := [
	"sha256:2eb8621882b4ae4047821aca415ab1b67de3399d0ab272a91f57fb0fc2ada7a4",
	"sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77",
]
const BW19V_CANDIDATES_RAW_SHA256 := "sha256:02124811891638efaad30fc6e04b3a10b600a5eab913984c1d4c8abbd1a963a3"
const BW19V_IMPLEMENTATION_PARENT_COMMIT := "7024efdddde6c1ad889987f43c2018f4a6ac7069"
const BW19V_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_a_v3"
const BW19V_EXECUTION_MODE := "native_balanced_wave_base_with_stability_contribution"
const BW19V_DRAFT_STATUS := "frozen_before_first_bw19v_physics_world"
const BW19V_SCALE_TOLERANCE := 1.0e-12


func _bw19v_candidate_index() -> int:
	return (
		BW19V_CANDIDATE_IDS
		. find(
			OS.get_environment(BW19V_CANDIDATE_ENVIRONMENT_VARIABLE),
		)
	)


## The BW17P parent contains the proven full-contribution physical receipt
## logic in its treatment branch. Both BW19V arms use that same route,
## including the exact-zero control.
func _candidate_index() -> int:
	return 1 if _bw19v_candidate_index() >= 0 else -1


func _candidate_id() -> String:
	var index := _bw19v_candidate_index()
	return String(BW19V_CANDIDATE_IDS[index]) if index >= 0 else ""


func _candidate_composition_digest() -> String:
	var index := _bw19v_candidate_index()
	return String(BW19V_COMPOSITION_DIGESTS[index]) if index >= 0 else ""


func _candidate_global_scale() -> float:
	var index := _bw19v_candidate_index()
	return float(BW19V_GLOBAL_SCALES[index]) if index >= 0 else NAN


func _candidate_authority_scope() -> String:
	return "post_settle_full" if _bw19v_candidate_index() >= 0 else ""


func _stability_policy_id() -> String:
	return BW19V_STABILITY_POLICY_ID if _bw19v_candidate_index() >= 0 else ""


func _expected_full_authority_execution_mode() -> String:
	return BW19V_EXECUTION_MODE if _bw19v_candidate_index() >= 0 else ""


func _campaign_contract() -> Dictionary:
	return {
		"preregistration_path": BW19V_PREREGISTRATION_PATH,
		"preregistration_schema":
		"sporespore_balanced_wave_bw19v_independent_validation_preregistration_v1",
		"preregistration_status": BW19V_DRAFT_STATUS,
		"campaign_id": ProportionSpecScript.BW19V_CAMPAIGN_ID,
		"gate_id": "BW19V",
		"generator_policy_id": ProportionSpecScript.BW19V_GENERATOR_POLICY_ID,
		"generator_indices": ProportionSpecScript.BW19V_INDEPENDENT_INDICES,
		"campaign_seeds": [39101, 39102, 39103],
		"generated_receipt_schema":
		"sporespore_bw19v_generated_cells_receipt_v1",
		"entrypoint_receipt_schema":
		"sporespore_bw19v_independent_validation_entrypoint_preflight_v1",
		"cell_receipt_schema":
		"sporespore_bw19v_independent_validation_cell_v1",
		"generated_prefix": "BW19V_VALIDATION_GENERATED_CELLS ",
		"entrypoint_prefix": "BW19V_VALIDATION_ENTRYPOINT_PREFLIGHT ",
		"cell_prefix": "BW19V_VALIDATION_CELL ",
		"display_name": "BW19V independent morphology validation",
	}


func _compile_campaign_generation(generator_index: int) -> Dictionary:
	return ProportionSpecScript.compile_bw19v_generation(generator_index)


func _verify_campaign_generation(
	generator_index: int,
	expected_generator_receipt_sha256: String,
	expected_proportion_spec_sha256: String,
) -> Dictionary:
	return (
		ProportionSpecScript
		. verify_bw19v_generation(
			generator_index,
			expected_generator_receipt_sha256,
			expected_proportion_spec_sha256,
		)
	)


func _validate_controller_policy_contract(
	preregistration: Dictionary,
	selected_policy: Dictionary,
) -> bool:
	var index := _bw19v_candidate_index()
	if index < 0:
		return false
	var declarations := _read_json(BW19V_CANDIDATES_PATH)
	var candidates: Array = declarations.get("candidates", [])
	var declaration_digests: Dictionary = declarations.get(
		"candidate_composition_digests",
		{},
	)
	var preregistration_digests: Dictionary = preregistration.get(
		"candidate_composition_digests",
		{},
	)
	var declaration_reference: Dictionary = preregistration.get(
		"candidate_declarations",
		{},
	)
	if candidates.size() != 2:
		return false
	var candidate: Dictionary = candidates[index]
	var selected_profile: Dictionary = selected_policy.get("selected_profile", {})
	return (
		String(selected_policy.get("selected_candidate_id", ""))
		== BW15F_CONTROLLER_CANDIDATE_ID
		and String(selected_policy.get("selected_policy_id", ""))
		== BW15F_CONTROLLER_POLICY_ID
		and String(selected_policy.get("selected_candidate_policy_digest", ""))
		== BW15F_CONTROLLER_POLICY_DIGEST
		and String(selected_profile.get("runtime_profile_sha256", ""))
		== BW15F_RUNTIME_PROFILE_SHA256
		and (selected_profile.get("branch_surfaces", []) as Array).is_empty()
		and String(declarations.get("schema_version", ""))
		== "sporespore_balanced_wave_bw19v_validation_candidates_v1"
		and String(declarations.get("status", "")) == BW19V_DRAFT_STATUS
		and (declarations.get("candidate_order", []) as Array)
		== BW19V_CANDIDATE_IDS
		and String(declarations.get("implementation_parent_commit", ""))
		== BW19V_IMPLEMENTATION_PARENT_COMMIT
		and String(declaration_reference.get("path", ""))
		== "sdk/balanced_wave_bw19v_validation_candidates.json"
		and String(declaration_reference.get("raw_sha256", ""))
		== BW19V_CANDIDATES_RAW_SHA256
		and String(declaration_reference.get("status", ""))
		== BW19V_DRAFT_STATUS
		and _raw_sha256(BW19V_CANDIDATES_PATH)
		== BW19V_CANDIDATES_RAW_SHA256
		and String(candidate.get("candidate_id", "")) == _candidate_id()
		and String(candidate.get("controller_candidate_id", ""))
		== BW15F_CONTROLLER_CANDIDATE_ID
		and String(candidate.get("controller_policy_id", ""))
		== BW15F_CONTROLLER_POLICY_ID
		and String(candidate.get("controller_policy_digest", ""))
		== BW15F_CONTROLLER_POLICY_DIGEST
		and String(candidate.get("stability_policy_id", ""))
		== BW19V_STABILITY_POLICY_ID
		and String(candidate.get("authority_scope", "")) == "post_settle_full"
		and String(candidate.get("execution_mode", "")) == BW19V_EXECUTION_MODE
		and bool(candidate.get("portable_plan_enabled", false))
		and String(candidate.get("portable_plan_operation", ""))
		== "plan_scheduled_load_transfer_v3_json"
		and String(candidate.get("portable_plan_receipt_schema_version", ""))
		== "sporespore_scheduled_load_transfer_receipt_v3"
		and bool(candidate.get("stability_contribution_authority", false))
		and String(candidate.get("stability_influence_operation", ""))
		== "bound_stability_influence_v3_json"
		and String(candidate.get("stability_influence_receipt_schema_version", ""))
		== "sporespore_stability_influence_receipt_v3"
		and _near_scale(
			float(candidate.get("global_requested_correction_scale", NAN)),
			_candidate_global_scale(),
		)
		and bool(candidate.get("exact_zero_residual_control", index != 0))
		== (index == 0)
		and bool(candidate.get("nonzero_effective_application_required", index == 0))
		== (index > 0)
		and int(candidate.get("expected_application_pass_count", -1))
		== (0 if index == 0 else 36)
		and int(candidate.get("morphology_condition_count", -1)) == 0
		and int(candidate.get("material_condition_count", -1)) == 0
		and int(candidate.get("seed_condition_count", -1)) == 0
		and int(candidate.get("failure_identity_condition_count", -1)) == 0
		and int(candidate.get("outcome_condition_count", -1)) == 0
		and (candidate.get("branch_surfaces", []) as Array).is_empty()
		and not bool(candidate.get("physical_acceptance_authority", true))
		and String(declaration_digests.get(_candidate_id(), ""))
		== _candidate_composition_digest()
		and String(preregistration_digests.get(_candidate_id(), ""))
		== _candidate_composition_digest()
		and Bw19CanonicalJsonScript.sha256(candidate)
		== _candidate_composition_digest()
	)


func _validate_contract(
	preregistration: Dictionary,
	selected_policy: Dictionary,
) -> bool:
	if preregistration.is_empty() or selected_policy.is_empty():
		return false
	var generator: Dictionary = preregistration.get("morphology_generator", {})
	var repetitions: Dictionary = preregistration.get("repetitions", {})
	var material: Dictionary = preregistration.get("material", {})
	var hypothesis: Dictionary = preregistration.get("controlled_hypothesis", {})
	var selection: Dictionary = preregistration.get("selection", {})
	var claims: Dictionary = preregistration.get("claim_boundary", {})
	var predecessor: Dictionary = preregistration.get("predecessor_interlocks", {})
	return (
		String(preregistration.get("schema_version", ""))
		== "sporespore_balanced_wave_bw19v_independent_validation_preregistration_v1"
		and String(preregistration.get("status", "")) == BW19V_DRAFT_STATUS
		and String(preregistration.get("gate_id", "")) == "BW19V"
		and String(preregistration.get("campaign_id", ""))
		== ProportionSpecScript.BW19V_CAMPAIGN_ID
		and String(preregistration.get("implementation_parent_commit", ""))
		== BW19V_IMPLEMENTATION_PARENT_COMMIT
		and not bool(preregistration.get("validation_hypothesis_confirmed", true))
		and int(preregistration.get("policy_branch_surface_count", -1)) == 0
		and _validate_controller_policy_contract(
			preregistration,
			selected_policy,
		)
		and String(generator.get("generator_policy_id", ""))
		== ProportionSpecScript.BW19V_GENERATOR_POLICY_ID
		and _integer_array(generator.get("generator_indices", []))
		== _integer_array(ProportionSpecScript.BW19V_INDEPENDENT_INDICES)
		and (generator.get("cells", []) as Array).size() == 12
		and not bool(generator.get("cohort_was_outcome_exposed_before_this_freeze", true))
		and String(generator.get("cohort_role", ""))
		== "prospective_independent_validation"
		and _integer_array(repetitions.get("campaign_seeds", []))
		== [39101, 39102, 39103]
		and int(repetitions.get("expected_world_count", -1)) == 36
		and int(repetitions.get("expected_world_count_per_candidate", -1)) == 36
		and int(repetitions.get("expected_complete_world_count", -1)) == 72
		and bool(repetitions.get("early_stop_for_outcome_forbidden", false))
		and String(material.get("profile_id", "")) == _material_profile_id()
		and is_equal_approx(float(material.get("authored_friction", NAN)), 0.95)
		and bool(material.get("held_constant_across_every_cell", false))
		and String(hypothesis.get("only_declared_factor", ""))
		== "global_requested_correction_scale"
		and (hypothesis.get("branch_surfaces", []) as Array).is_empty()
		and int(hypothesis.get("morphology_condition_count", -1)) == 0
		and int(hypothesis.get("material_condition_count", -1)) == 0
		and int(hypothesis.get("seed_condition_count", -1)) == 0
		and int(hypothesis.get("failure_identity_condition_count", -1)) == 0
		and int(hypothesis.get("outcome_condition_count", -1)) == 0
		and String(selection.get("control_candidate", "")) == "BW19V-A"
		and (selection.get("selectable_treatments", []) as Array)
		== ["BW19V-B"]
		and bool(selection.get("all_candidate_reports_required", false))
		and bool(
			selection.get(
				"all_reports_require_36_of_36_integrity_and_mechanism",
				false,
			)
		)
		and _integer_array(
			selection.get(
				"policy_relative_expected_application_pass_counts",
				[],
			)
		)
		== [0, 36]
		and bool(
			selection.get(
				"treatment_walking_failure_count_must_be_strictly_lower_than_control",
				false,
			)
		)
		and bool(selection.get("walking_failure_tie_or_worse_rejects_hypothesis", false))
		and String(predecessor.get("bw18g_closure_manifest_sha256", ""))
		== "sha256:bd5f63f01daac4ddc3f666b15bc4e8743fea770c090af54b6611cc409c0e6104"
		and not bool(claims.get("walking_acceptance", true))
		and not bool(claims.get("balance_improvement", true))
		and not bool(claims.get("independent_morphology_validation", true))
		and bool(claims.get("finite_population_only", false))
		and bool(
			claims.get(
				"finite_prospectively_frozen_unopened_validation_cohort_only",
				false,
			)
		)
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
	authority_options["stability_influence_global_scale"] = (
		_candidate_global_scale()
	)
	prepared["authority_options"] = authority_options
	return prepared


func _preflight_selected_policy_full_authority_start(
	prepared: Dictionary,
	initial_perturbation: Dictionary,
) -> Dictionary:
	var root_child_count_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var requested_phase_offset_ticks := int(
		initial_perturbation["gait_phase_offset_ticks"]
	)
	var execution_mode_plan := (
		WaveGaitScript
		. compile_sdk_execution_mode_plan(
			true,
			true,
			"post_settle_full",
			BW19V_STABILITY_POLICY_ID,
			requested_phase_offset_ticks,
		)
	)
	if not bool(execution_mode_plan.get("ok", false)):
		return execution_mode_plan
	var adapter: RefCounted = AdapterScript.new()
	var start: Dictionary = (
		adapter
		. start(
			(prepared["authority_options"] as Dictionary)["descriptor"],
			(execution_mode_plan.get("zero_base_initial_gait_steps", {}) as Dictionary),
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
			"post_settle_full",
			BW19V_STABILITY_POLICY_ID,
			prepared["material_profile"],
			_controller_policy_id(),
			_candidate_global_scale(),
		)
	)
	var boundary: Dictionary = {}
	if bool(start.get("ok", false)):
		boundary = adapter.preflight_perfect_declared_policy_runtime_boundary()
	var manifest: Dictionary = start.get("adapter_manifest", {})
	var stability: Dictionary = manifest.get("stability_v3", {})
	var contribution: Dictionary = stability.get("contribution_shadow", {})
	var influence: Dictionary = boundary.get(
		"portable_stability_influence_receipt",
		{},
	)
	var exact := (
		_bw19v_candidate_index() >= 0
		and bool(start.get("ok", false))
		and String(start.get("controller_policy_id", ""))
		== _controller_policy_id()
		and String(start.get("authority_scope", "")) == "post_settle_full"
		and String(start.get("stability_policy_id", ""))
		== BW19V_STABILITY_POLICY_ID
		and String(manifest.get("execution_mode", "")) == BW19V_EXECUTION_MODE
		and String(manifest.get("stability_influence_scale_authority", ""))
		== "portable_core_v3"
		and _near_scale(
			float(manifest.get("stability_influence_global_scale", NAN)),
			_candidate_global_scale(),
		)
		and String(contribution.get("influence_operation", ""))
		== "bound_stability_influence_v3_json"
		and bool(boundary.get("ok", false))
		and bool(boundary.get("portable_stability_influence_required", false))
		and bool(boundary.get("portable_stability_influence_passed", false))
		and String(influence.get("stability_influence_operation", ""))
		== "bound_stability_influence_v3_json"
		and _near_scale(
			float(
				influence.get(
					"global_requested_correction_scale",
					NAN,
				)
			),
			_candidate_global_scale(),
		)
		and int(start.get("world_build_count", -1)) == 0
		and int(boundary.get("actual_world_build_count", -1)) == 0
		and root.get_child_count() == root_child_count_before
		and Engine.physics_ticks_per_second == physics_hz_before
		and not bool(start.get("physical_acceptance_authority", true))
	)
	return {
		"schema_version":
		"sporespore_bw19v_candidate_adapter_start_preflight_v1",
		"ok": exact,
		"failure_code":
		"" if exact else "BW19V_CANDIDATE_ADAPTER_START_INVALID",
		"candidate_id": _candidate_id(),
		"candidate_composition_digest": _candidate_composition_digest(),
		"controller_policy_id": String(start.get("controller_policy_id", "")),
		"authority_scope": String(start.get("authority_scope", "")),
		"actuation_authority": bool(start.get("actuation_authority", false)),
		"stability_policy_id": String(start.get("stability_policy_id", "")),
		"global_requested_correction_scale": _candidate_global_scale(),
		"adapter_capability_sha256":
		String(start.get("adapter_capability_sha256", "")),
		"requested_phase_offset_ticks": requested_phase_offset_ticks,
		"sdk_execution_mode_plan": execution_mode_plan.duplicate(true),
		"sdk_execution_mode_plan_passed":
		bool(execution_mode_plan.get("ok", false)),
		"declared_policy_runtime_boundary_preflight":
		boundary.duplicate(true),
		"declared_policy_runtime_boundary_preflight_passed":
		bool(boundary.get("ok", false)),
		"actual_world_build_count": 0,
		"scene_tree_insertion_count":
		root.get_child_count() - root_child_count_before,
		"physics_state_modified":
		Engine.physics_ticks_per_second != physics_hz_before,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


func _physical_cell_receipt(
	cell: Dictionary,
	seed: int,
	summary: Dictionary,
) -> Dictionary:
	var receipt := super._physical_cell_receipt(cell, seed, summary)
	var index := _bw19v_candidate_index()
	var scale := _candidate_global_scale()
	var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var contribution: Dictionary = sdk_summary.get(
		"stability_contribution_shadow_summary",
		{},
	)
	var overlay: Dictionary = sdk_summary.get(
		"stability_overlay_summary",
		{},
	)
	var start_result: Dictionary = summary.get(
		"sdk_authority_start_result",
		{},
	)
	var manifest: Dictionary = start_result.get("adapter_manifest", {})
	var sdk_steps := int(sdk_summary.get("step_count", -1))
	var expected_motor_writes := sdk_steps * 8
	var scale_contract_exact := (
		index >= 0
		and String(manifest.get("stability_influence_scale_authority", ""))
		== "portable_core_v3"
		and _near_scale(
			float(manifest.get("stability_influence_global_scale", NAN)),
			scale,
		)
		and String(contribution.get("influence_operation", ""))
		== "bound_stability_influence_v3_json"
		and bool(
			contribution.get(
				"global_scale_applied_before_magnitude_and_slew",
				false,
			)
		)
		and _near_scale(
			float(
				contribution.get(
					"global_requested_correction_scale",
					NAN,
				)
			),
			scale,
		)
		and int(contribution.get("attempt_count", -1)) == sdk_steps
		and int(contribution.get("influence_output_count", -1))
		== expected_motor_writes
		and int(contribution.get("mismatch_count", -1)) == 0
		and int(contribution.get("limiter_mismatch_count", -1)) == 0
		and int(contribution.get("profile_conversion_failure_count", -1)) == 0
	)
	var mechanism_exact := (
		bool(receipt.get("mechanism_gate_passed", false))
		and scale_contract_exact
	)
	var combined_exact := (
		bool(receipt.get("combined_application_gate_passed", false))
		and scale_contract_exact
	)
	if index == 0:
		combined_exact = (
			bool(receipt.get("common_execution_integrity", false))
			and scale_contract_exact
			and float(
				contribution.get(
					"maximum_absolute_proposed_velocity_rad_s",
					0.0,
				)
			)
			> 0.0
			and _near_scale(
				float(
					contribution.get(
						"maximum_absolute_applied_velocity_rad_s",
						NAN,
					)
				),
				0.0,
			)
			and int(overlay.get("application_step_count", -1)) == sdk_steps
			and int(overlay.get("motor_write_count", -1))
			== expected_motor_writes
			and int(
				overlay.get(
					"portable_controller_base_application_count",
					-1,
				)
			)
			== expected_motor_writes
			and int(
				overlay.get(
					"nonzero_effective_application_count",
					-1,
				)
			)
			== 0
			and not bool(overlay.get("physical_influence", true))
			and int(overlay.get("failure_count", -1)) == 0
		)
	else:
		combined_exact = (
			combined_exact
			and float(
				contribution.get(
					"maximum_absolute_applied_velocity_rad_s",
					0.0,
				)
			)
			> 0.0
			and int(
				overlay.get(
					"nonzero_effective_application_count",
					0,
				)
			)
			> 0
			and bool(overlay.get("physical_influence", false))
		)
	receipt["schema_version"] = (
		"sporespore_bw19v_independent_validation_cell_v1"
	)
	receipt["campaign_role"] = (
		"two_arm_prospective_independent_morphology_validation"
	)
	receipt["candidate_id"] = _candidate_id()
	receipt["candidate_composition_digest"] = (
		_candidate_composition_digest()
	)
	receipt["global_requested_correction_scale"] = scale
	receipt["stability_influence_operation"] = (
		"bound_stability_influence_v3_json"
	)
	receipt["scale_contract_passed"] = scale_contract_exact
	receipt["mechanism_gate_passed"] = mechanism_exact
	receipt["combined_application_gate_passed"] = combined_exact
	return receipt


static func _near_scale(actual: float, expected: float) -> bool:
	return (
		is_finite(actual)
		and is_finite(expected)
		and absf(actual - expected) <= BW19V_SCALE_TOLERANCE
	)
