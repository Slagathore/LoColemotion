extends "res://tests/test_sdk_balanced_wave_bw17p_morphology_development.gd"
# gdlint: disable=max-line-length
# gdlint: disable=max-returns
# gdlint: disable=max-file-lines

## Four-arm BW18G global residual-scale development test.
##
## This intentionally reuses the already-closed BW17P physical cohort harness
## and production walking gates. All arms now use the exact same BW15F-B
## controller, BW13P-A portable plan, full native authority, and v3 bounded
## contribution path. Only one core-owned global scale varies.

const Bw18CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const BW18G_PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw18g_morphology_development_preregistration.json"
const BW18G_CANDIDATES_PATH := "res://sdk/balanced_wave_bw18g_residual_scale_candidates.json"
const BW18G_CANDIDATE_ENVIRONMENT_VARIABLE := "SPORESPORE_BW18G_CANDIDATE"
const BW18G_CANDIDATE_IDS := ["BW18G-A", "BW18G-B", "BW18G-C", "BW18G-D"]
const BW18G_GLOBAL_SCALES := [0.0, 0.25, 0.5, 1.0]
const BW18G_COMPOSITION_DIGESTS := [
	"sha256:1bbb4e46b3d3e2d70bf17eb86717df19942912280a56e534aa3d47dee2e814e1",
	"sha256:45826fbec95b544186a2dd9822bb1d641c3359120e900aeda729ba691b927446",
	"sha256:1707317f2e1c74adcdd5908ea7daf845233afda42d2f08d0b2a9007480bb2e1e",
	"sha256:8f27e50fa5d6033bf1a5ca69588c246d9a395f331ed6ba4cd405fd69b985641e",
]
const BW18G_CANDIDATES_RAW_SHA256 := "sha256:a6bc578006217c8bea3601c1de2b62bbcaaa6fbb5809679d8bd97a2fac9e3d7f"
const BW18G_IMPLEMENTATION_PARENT_COMMIT := "4f3b9d6ec5aaedb37c07fa26fdb0478f1de74624"
const BW18G_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_a_v3"
const BW18G_EXECUTION_MODE := "native_balanced_wave_base_with_stability_contribution"
const BW18G_DRAFT_STATUS := "frozen_before_first_bw18g_physics_world"
const BW18G_SCALE_TOLERANCE := 1.0e-12


func _bw18g_candidate_index() -> int:
	return (
		BW18G_CANDIDATE_IDS
		. find(
			OS.get_environment(BW18G_CANDIDATE_ENVIRONMENT_VARIABLE),
		)
	)


## The BW17P parent contains the proven full-contribution physical receipt
## logic in its treatment branch. Every BW18G arm uses that same route,
## including the exact-zero arm; a separate index above retains four-arm
## identity and scale selection.
func _candidate_index() -> int:
	return 1 if _bw18g_candidate_index() >= 0 else -1


func _candidate_id() -> String:
	var index := _bw18g_candidate_index()
	return String(BW18G_CANDIDATE_IDS[index]) if index >= 0 else ""


func _candidate_composition_digest() -> String:
	var index := _bw18g_candidate_index()
	return String(BW18G_COMPOSITION_DIGESTS[index]) if index >= 0 else ""


func _candidate_global_scale() -> float:
	var index := _bw18g_candidate_index()
	return float(BW18G_GLOBAL_SCALES[index]) if index >= 0 else NAN


func _candidate_authority_scope() -> String:
	return "post_settle_full" if _bw18g_candidate_index() >= 0 else ""


func _stability_policy_id() -> String:
	return BW18G_STABILITY_POLICY_ID if _bw18g_candidate_index() >= 0 else ""


func _expected_full_authority_execution_mode() -> String:
	return BW18G_EXECUTION_MODE if _bw18g_candidate_index() >= 0 else ""


func _campaign_contract() -> Dictionary:
	return {
		"preregistration_path": BW18G_PREREGISTRATION_PATH,
		"preregistration_schema":
		"sporespore_balanced_wave_bw18g_morphology_development_preregistration_v1",
		"preregistration_status": BW18G_DRAFT_STATUS,
		"campaign_id": "BW18G-MORPHOLOGY-DEVELOPMENT",
		"gate_id": "BW18G",
		"generator_policy_id": ProportionSpecScript.QSDK_R05C_GENERATOR_POLICY_ID,
		"generator_indices": ProportionSpecScript.QSDK_R05C_INDEPENDENT_INDICES,
		"campaign_seeds": [38101, 38102, 38103],
		"generated_receipt_schema":
		"sporespore_bw18g_development_generated_cells_receipt_v1",
		"entrypoint_receipt_schema":
		"sporespore_bw18g_development_entrypoint_preflight_v1",
		"cell_receipt_schema":
		"sporespore_bw18g_morphology_development_cell_v1",
		"generated_prefix": "BW18G_DEVELOPMENT_GENERATED_CELLS ",
		"entrypoint_prefix": "BW18G_DEVELOPMENT_ENTRYPOINT_PREFLIGHT ",
		"cell_prefix": "BW18G_DEVELOPMENT_CELL ",
		"display_name": "BW18G global residual-scale development",
	}


func _validate_controller_policy_contract(
	preregistration: Dictionary,
	selected_policy: Dictionary,
) -> bool:
	var index := _bw18g_candidate_index()
	if index < 0:
		return false
	var declarations := _read_json(BW18G_CANDIDATES_PATH)
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
	if candidates.size() != 4:
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
		== "sporespore_balanced_wave_bw18g_residual_scale_candidates_v1"
		and String(declarations.get("status", "")) == BW18G_DRAFT_STATUS
		and (declarations.get("candidate_order", []) as Array)
		== BW18G_CANDIDATE_IDS
		and String(declarations.get("implementation_parent_commit", ""))
		== BW18G_IMPLEMENTATION_PARENT_COMMIT
		and String(declaration_reference.get("path", ""))
		== "sdk/balanced_wave_bw18g_residual_scale_candidates.json"
		and String(declaration_reference.get("raw_sha256", ""))
		== BW18G_CANDIDATES_RAW_SHA256
		and String(declaration_reference.get("status", ""))
		== BW18G_DRAFT_STATUS
		and _raw_sha256(BW18G_CANDIDATES_PATH)
		== BW18G_CANDIDATES_RAW_SHA256
		and String(candidate.get("candidate_id", "")) == _candidate_id()
		and String(candidate.get("controller_candidate_id", ""))
		== BW15F_CONTROLLER_CANDIDATE_ID
		and String(candidate.get("controller_policy_id", ""))
		== BW15F_CONTROLLER_POLICY_ID
		and String(candidate.get("controller_policy_digest", ""))
		== BW15F_CONTROLLER_POLICY_DIGEST
		and String(candidate.get("stability_policy_id", ""))
		== BW18G_STABILITY_POLICY_ID
		and String(candidate.get("authority_scope", "")) == "post_settle_full"
		and String(candidate.get("execution_mode", "")) == BW18G_EXECUTION_MODE
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
		and Bw18CanonicalJsonScript.sha256(candidate)
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
		== "sporespore_balanced_wave_bw18g_morphology_development_preregistration_v1"
		and String(preregistration.get("status", "")) == BW18G_DRAFT_STATUS
		and String(preregistration.get("gate_id", "")) == "BW18G"
		and String(preregistration.get("campaign_id", ""))
		== "BW18G-MORPHOLOGY-DEVELOPMENT"
		and String(preregistration.get("implementation_parent_commit", ""))
		== BW18G_IMPLEMENTATION_PARENT_COMMIT
		and not bool(preregistration.get("development_candidate_selected", true))
		and int(preregistration.get("policy_branch_surface_count", -1)) == 0
		and _validate_controller_policy_contract(
			preregistration,
			selected_policy,
		)
		and String(generator.get("generator_policy_id", ""))
		== ProportionSpecScript.QSDK_R05C_GENERATOR_POLICY_ID
		and _integer_array(generator.get("generator_indices", []))
		== _integer_array(ProportionSpecScript.QSDK_R05C_INDEPENDENT_INDICES)
		and (generator.get("cells", []) as Array).size() == 12
		and bool(generator.get("cohort_was_outcome_exposed_before_this_freeze", false))
		and String(generator.get("cohort_role", ""))
		== "paired_development_only"
		and _integer_array(repetitions.get("campaign_seeds", []))
		== [38101, 38102, 38103]
		and int(repetitions.get("expected_world_count", -1)) == 36
		and int(repetitions.get("expected_world_count_per_candidate", -1)) == 36
		and int(repetitions.get("expected_complete_world_count", -1)) == 144
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
		and String(selection.get("control_candidate", "")) == "BW18G-A"
		and (selection.get("selectable_treatments", []) as Array)
		== ["BW18G-B", "BW18G-C", "BW18G-D"]
		and bool(selection.get("all_candidate_reports_required", false))
		and bool(
			selection.get(
				"all_reports_require_36_of_36_integrity_mechanism_and_combined_application",
				false,
			)
		)
		and bool(
			selection.get(
				"best_treatment_must_be_strictly_lexicographically_better_than_control",
				false,
			)
		)
		and bool(selection.get("tie_or_control_win_rejects_family", false))
		and String(predecessor.get("bw17p_closure_manifest_sha256", ""))
		== "sha256:742240d12102be6b957267981b5ab5b28eefe4d0c5138d10f20d2de9b16fc905"
		and not bool(claims.get("walking_acceptance", true))
		and not bool(claims.get("balance_improvement", true))
		and not bool(claims.get("independent_morphology_validation", true))
		and bool(claims.get("finite_population_only", false))
		and bool(
			claims.get(
				"finite_outcome_exposed_development_cohort_only",
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
			BW18G_STABILITY_POLICY_ID,
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
			BW18G_STABILITY_POLICY_ID,
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
		_bw18g_candidate_index() >= 0
		and bool(start.get("ok", false))
		and String(start.get("controller_policy_id", ""))
		== _controller_policy_id()
		and String(start.get("authority_scope", "")) == "post_settle_full"
		and String(start.get("stability_policy_id", ""))
		== BW18G_STABILITY_POLICY_ID
		and String(manifest.get("execution_mode", "")) == BW18G_EXECUTION_MODE
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
		"sporespore_bw18g_candidate_adapter_start_preflight_v1",
		"ok": exact,
		"failure_code":
		"" if exact else "BW18G_CANDIDATE_ADAPTER_START_INVALID",
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
	var index := _bw18g_candidate_index()
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
		"sporespore_bw18g_morphology_development_cell_v1"
	)
	receipt["campaign_role"] = (
		"four_arm_outcome_exposed_global_portable_residual_scale_development"
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
		and absf(actual - expected) <= BW18G_SCALE_TOLERANCE
	)
