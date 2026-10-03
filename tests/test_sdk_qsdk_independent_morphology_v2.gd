extends SceneTree
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Versioned independent-morphology gate for a frozen selected policy.
##
## No-argument, emit-cells, and preflight modes construct no physics world.
## Physical mode accepts exactly one preregistered morphology and seed so the
## PowerShell campaign runner can isolate, time-bound, and retain every world.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const ProportionSpecScript := preload(
	"res://scripts/lab/gait/physical_quadruped_proportion_spec_v2.gd"
)
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const ClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)

const SELECTED_POLICY_PATH := "res://sdk/balanced_wave_selected_policy.json"
const SELECTED_CANDIDATE_ID := "BW5R-B"
const SELECTED_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const SELECTED_POLICY_DIGEST := "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
const MATERIAL_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const SDK_COMPARISON_TOLERANCE := 2.5e-7
const EXPECTED_ACTUATOR_COUNT := 8
const EXPECTED_WORLD_COUNT := 36

## These are non-authoritative host-observer settings. Once the 240-tick
## settle period ends, the portable SDK has exclusive command authority.
const ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const HOST_OBSERVER_PATH_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.25,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.40,
}
const ACTUATOR_IMPULSE_OPTIONS := {
	"mass_adaptive_actuator_enabled": true,
	"actuator_policy_id": "g3_gp3_global_actuator_margin_v1",
	"actuator_impulse_scale": 1.015,
}
const HOST_PREAUTHORITY_MOTOR_OPTIONS := {
	"mass_adaptive_motor_velocity_enabled": true,
	"motor_velocity_policy_id": "qsdk_r05_non_authoritative_host_preauthority_v1",
	"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s": 3.0,
	"anchor_error_guard_enabled": true,
	"morphology_interaction_score": 0.0,
	"anchor_error_guard_activation_fraction": 0.8,
	"anchor_error_guard_maximum_motor_target_speed_rad_s": 2.0,
}
const SOLVER_POLICY_OPTIONS := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": 120,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}

var _passed := 0
var _failed := 0


func _campaign_contract() -> Dictionary:
	return {
		"preregistration_path": "res://sdk/qsdk_r05_independent_morphology_preregistration.json",
		"preregistration_schema": "sporespore_qsdk_r05_independent_morphology_preregistration_v1",
		"preregistration_status": "frozen_before_first_qsdk_r05_physics_world",
		"campaign_id": "QSDK-R05",
		"gate_id": "QSDK-R05",
		"generator_policy_id": ProportionSpecScript.QSDK_R05_GENERATOR_POLICY_ID,
		"generator_indices": ProportionSpecScript.QSDK_R05_INDEPENDENT_INDICES,
		"campaign_seeds": [21501, 21502, 21503],
		"generated_receipt_schema": "sporespore_qsdk_r05_generated_cells_receipt_v1",
		"entrypoint_receipt_schema": "sporespore_qsdk_r05_entrypoint_preflight_receipt_v1",
		"cell_receipt_schema": "sporespore_qsdk_r05_independent_morphology_cell_v1",
		"generated_prefix": "QSDK_R05_GENERATED_CELLS ",
		"entrypoint_prefix": "QSDK_R05_ENTRYPOINT_PREFLIGHT ",
		"cell_prefix": "QSDK_R05_CELL ",
		"display_name": "QSDK-R05 independent morphology",
	}


func _selected_policy_path() -> String:
	return SELECTED_POLICY_PATH


func _controller_candidate_id() -> String:
	return SELECTED_CANDIDATE_ID


func _controller_policy_id() -> String:
	return SELECTED_POLICY_ID


func _controller_policy_digest() -> String:
	return SELECTED_POLICY_DIGEST


func _material_profile_id() -> String:
	return MATERIAL_PROFILE_ID


func _expected_world_count() -> int:
	return EXPECTED_WORLD_COUNT


func _expected_morphology_count() -> int:
	return 12


func _stability_policy_id() -> String:
	return "p5i3b_weight_support_shadow_v1"


func _walking_required_for_cell_success() -> bool:
	return true


func _expected_full_authority_execution_mode() -> String:
	return "native_authority_with_legacy_observer"


func _physical_authorization(
	_cell: Dictionary,
	_seed: int,
	_authorization_preflight: bool,
) -> Dictionary:
	return {
		"ok": true,
		"failure_code": "",
		"required": false,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _environment_challenge_options_for_cell(
	_generator_index: int,
	_seed: int,
) -> Dictionary:
	return {}


func _sdk_physical_trace_options_for_cell(
	_generator_index: int,
	_seed: int,
) -> Dictionary:
	return {}


func _compile_campaign_generation(generator_index: int) -> Dictionary:
	return ProportionSpecScript.compile_qsdk_r05_generation(generator_index)


func _verify_campaign_generation(
	generator_index: int,
	expected_generator_receipt_sha256: String,
	expected_proportion_spec_sha256: String,
) -> Dictionary:
	return (
		ProportionSpecScript
		. verify_qsdk_r05_generation(
			generator_index,
			expected_generator_receipt_sha256,
			expected_proportion_spec_sha256,
		)
	)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var campaign := _campaign_contract()
	print("\n=== %s ===" % String(campaign["display_name"]))
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() == 1 and String(user_args[0]) == "emit-cells":
		print(
			String(campaign["generated_prefix"]),
			JSON.stringify(_generated_cells_receipt(), "", true, true),
		)
		_finish()
		return

	var preregistration := _read_json(String(campaign["preregistration_path"]))
	var selected_policy := _read_json(_selected_policy_path())
	var contract_ok := _validate_contract(preregistration, selected_policy)
	_check(contract_ok, "0 the frozen R05 campaign and selected policy identities are exact")
	if not contract_ok:
		_finish()
		return

	var generated_exact := _validate_generated_cells(preregistration)
	_check(
		generated_exact,
		"1 all frozen generated cells compile to their exact digests",
	)
	if not generated_exact:
		_finish()
		return

	var static_preflight_exact := _validate_static_preflight(preregistration)
	_check(
		static_preflight_exact,
		"2 every morphology, material fixture, threshold, clock, and authority option compiles without a world",
	)
	if not static_preflight_exact:
		_finish()
		return

	if user_args.is_empty():
		_check(
			root.get_child_count() == 0,
			"3 the contract-only invocation inserts no world into the SceneTree",
		)
		_finish()
		return

	if (
		bool(campaign.get("physical_authorization_required", false))
		and user_args.size() == 3
		and String(user_args[0]) == "authorization-preflight"
		and String(user_args[2]).is_valid_int()
	):
		var authorization_morphology_id := String(user_args[1])
		var authorization_seed_text := String(user_args[2])
		var authorization_request := _resolve_physical_request(
			preregistration,
			authorization_morphology_id,
			authorization_seed_text,
		)
		var authorization: Dictionary = {}
		if bool(authorization_request.get("ok", false)):
			authorization = _physical_authorization(
				authorization_request["cell"],
				int(authorization_request["seed"]),
				true,
			)
		var authorization_exact := (
			bool(authorization_request.get("ok", false))
			and bool(authorization.get("ok", false))
			and int(authorization.get("world_build_count", -1)) == 0
			and not bool(authorization.get("physical_acceptance_authority", true))
			and root.get_child_count() == 0
		)
		var authorization_receipt := {
			"schema_version": String(campaign["authorization_preflight_schema"]),
			"ok": authorization_exact,
			"campaign_id": String(campaign["campaign_id"]),
			"gate_id": String(campaign["gate_id"]),
			"morphology_id": authorization_morphology_id,
			"campaign_seed": authorization_seed_text.to_int(),
			"authorization": authorization.duplicate(true),
			"actual_world_build_count": 0,
			"scene_tree_insertion_count": root.get_child_count(),
			"physics_state_modified": false,
			"locomotion_outcome_exposed": false,
			"physical_acceptance_authority": false,
		}
		print(
			String(campaign["authorization_preflight_prefix"]),
			JSON.stringify(authorization_receipt, "", true, true),
		)
		_check(authorization_exact, "3 physical authorization fields reconcile before world entry")
		_finish()
		return

	if user_args.size() == 1 and String(user_args[0]) == "preflight":
		var entrypoint_receipts: Array = []
		var all_entrypoints_exact := true
		var runtime_boundary_pass_count := 0
		for cell_value in preregistration["morphology_generator"]["cells"]:
			var cell: Dictionary = cell_value
			for seed_value in preregistration["repetitions"]["campaign_seeds"]:
				var request := _resolve_physical_request(
					preregistration,
					String(cell["morphology_id"]),
					str(int(seed_value)),
				)
				if not bool(request.get("ok", false)):
					all_entrypoints_exact = false
					continue
				var receipt := await _run_cell(
					int((request["cell"] as Dictionary)["generator_index"]),
					int(request["seed"]),
					true,
				)
				entrypoint_receipts.append(receipt)
				var selected_start: Dictionary = receipt.get(
					"selected_policy_full_authority_start",
					{},
				)
				if bool(
					selected_start.get(
						"declared_policy_runtime_boundary_preflight_passed",
						false,
					)
				):
					runtime_boundary_pass_count += 1
				all_entrypoints_exact = (
					all_entrypoints_exact
					and bool(receipt.get("ok", false))
					and bool(receipt.get("entrypoint_control_flow_complete", false))
					and int(receipt.get("actual_world_build_count", -1)) == 0
					and int(receipt.get("scene_tree_insertion_count", -1)) == 0
					and not bool(receipt.get("physics_state_modified", true))
					and bool(
						(
							receipt
							. get(
								"selected_policy_full_authority_start_passed",
								false,
							)
						)
					)
					and bool(
						selected_start.get(
							"declared_policy_runtime_boundary_preflight_passed",
							false,
						)
					)
					and not bool(receipt.get("locomotion_outcome_exposed", true))
					and not bool(receipt.get("physical_acceptance_authority", true))
				)
		_check(
			all_entrypoints_exact and entrypoint_receipts.size() == _expected_world_count(),
			(
				"3 all %d cells traverse the real entrypoint and return before world construction"
				% _expected_world_count()
			),
		)
		var aggregate := {
			"schema_version": String(campaign["entrypoint_receipt_schema"]),
			"ok": _failed == 0,
			"campaign_id": String(campaign["campaign_id"]),
			"selected_policy_id": _controller_policy_id(),
			"stability_policy_id": _stability_policy_id(),
			"cell_count": entrypoint_receipts.size(),
			"entrypoint_receipts": entrypoint_receipts,
			"actual_world_build_count": 0,
			"scene_tree_insertion_count": 0,
			"physics_state_modified": false,
			"exact_selected_policy_full_authority_start_count": entrypoint_receipts.size(),
			"selected_policy_full_authority_start_passed": all_entrypoints_exact,
			"exact_declared_policy_runtime_boundary_count":
			runtime_boundary_pass_count,
			"declared_policy_runtime_boundary_preflight_passed":
			runtime_boundary_pass_count == _expected_world_count(),
			"locomotion_outcome_exposed": false,
			"physical_acceptance_authority": false,
		}
		print(
			String(campaign["entrypoint_prefix"]),
			JSON.stringify(aggregate, "", true, true),
		)
		_finish()
		return

	var physical_arguments_exact := (
		user_args.size() == 3
		and String(user_args[0]) == "physical"
		and String(user_args[2]).is_valid_int()
	)
	_check(
		physical_arguments_exact,
		"3 physical mode names exactly one preregistered morphology and seed",
	)
	if not physical_arguments_exact:
		_finish()
		return
	var morphology_id := String(user_args[1])
	var seed_text := String(user_args[2])
	var request := _resolve_physical_request(preregistration, morphology_id, seed_text)
	_check(
		bool(request.get("ok", false)),
		"4 the requested physical cell belongs to the frozen campaign matrix",
	)
	if not bool(request.get("ok", false)):
		_finish()
		return

	var cell: Dictionary = request["cell"]
	var seed := int(request["seed"])
	var physical_authorization: Dictionary = {}
	if bool(campaign.get("physical_authorization_required", false)):
		physical_authorization = _physical_authorization(cell, seed, false)
		_check(
			bool(physical_authorization.get("ok", false)),
			"5 the physical worker received exact supervisor authorization",
		)
		if not bool(physical_authorization.get("ok", false)):
			push_error(
				String(
					physical_authorization.get(
						"failure_code",
						"QSDK_PHYSICAL_AUTHORIZATION_REQUIRED",
					)
				)
			)
			_finish()
			return
	var summary := await _run_cell(int(cell["generator_index"]), seed, false)
	var receipt := _physical_cell_receipt(cell, seed, summary)
	if not physical_authorization.is_empty():
		receipt["physical_authorization"] = physical_authorization.duplicate(true)
	_check(
		bool(receipt.get("common_execution_integrity", false)),
		"6 one world retains exclusive SDK authority and complete integrity receipts",
	)
	if _walking_required_for_cell_success():
		_check(
			bool(receipt.get("walking_observed", false)),
			"7 every production walking gate passes in the same continuous world",
		)
	else:
		_check(
			bool(receipt.get("common_execution_integrity", false)),
			"7 the development cell records its walking outcome without promoting it",
		)
	_check(
		not bool(receipt.get("physical_acceptance_authority", true)),
		"8 the cell remains finite R05 evidence with no broader release authority",
	)
	receipt["harness_passed"] = _failed == 0
	receipt["assertions_passed"] = _passed
	receipt["assertions_failed"] = _failed
	print(String(campaign["cell_prefix"]), JSON.stringify(receipt, "", true, true))
	_finish()


func _validate_contract(preregistration: Dictionary, selected_policy: Dictionary) -> bool:
	if preregistration.is_empty() or selected_policy.is_empty():
		return false
	var campaign := _campaign_contract()
	var generator: Dictionary = preregistration.get("morphology_generator", {})
	var repetitions: Dictionary = preregistration.get("repetitions", {})
	var material: Dictionary = preregistration.get("material", {})
	var claim_boundary: Dictionary = preregistration.get("claim_boundary", {})
	return (
		(
			String(preregistration.get("schema_version", ""))
			== String(campaign["preregistration_schema"])
		)
		and (
			String(preregistration.get("status", "")) == String(campaign["preregistration_status"])
		)
		and String(preregistration.get("gate_id", "")) == String(campaign["gate_id"])
		and String(preregistration.get("campaign_id", "")) == String(campaign["campaign_id"])
		and _validate_controller_policy_contract(preregistration, selected_policy)
		and (
			String(generator.get("generator_policy_id", ""))
			== String(campaign["generator_policy_id"])
		)
		and (
			_integer_array(generator.get("generator_indices", []))
			== _integer_array(campaign["generator_indices"])
		)
		and (generator.get("cells", []) as Array).size() == _expected_morphology_count()
		and (
			_integer_array(repetitions.get("campaign_seeds", []))
			== _integer_array(campaign["campaign_seeds"])
		)
		and int(repetitions.get("expected_world_count", -1)) == _expected_world_count()
		and String(material.get("profile_id", "")) == _material_profile_id()
		and is_equal_approx(float(material.get("authored_friction", NAN)), 0.95)
		and bool(claim_boundary.get("finite_population_only", false))
		and not bool(claim_boundary.get("arbitrary_quadruped_coverage", true))
		and not bool(claim_boundary.get("continuous_full_volume_coverage", true))
		and not bool(claim_boundary.get("completed_engine_neutral_sdk", true))
		and not bool(claim_boundary.get("release_authorized", true))
	)


func _validate_controller_policy_contract(
	preregistration: Dictionary,
	selected_policy: Dictionary,
) -> bool:
	return (
		String(preregistration.get("selected_candidate_id", ""))
		== _controller_candidate_id()
		and String(preregistration.get("selected_policy_id", ""))
		== _controller_policy_id()
		and String(preregistration.get("selected_policy_digest", ""))
		== _controller_policy_digest()
		and int(preregistration.get("policy_branch_surface_count", -1)) == 0
		and String(selected_policy.get("selected_candidate_id", ""))
		== _controller_candidate_id()
		and String(selected_policy.get("selected_policy_id", ""))
		== _controller_policy_id()
		and (
			String(selected_policy.get("selected_candidate_policy_digest", ""))
			== _controller_policy_digest()
		)
		and (
			(selected_policy.get("selected_profile", {}) as Dictionary).get(
				"branch_surfaces",
				[1],
			)
			== []
		)
	)


func _generated_cells_receipt() -> Dictionary:
	var campaign := _campaign_contract()
	var cells: Array = []
	for generator_index in campaign["generator_indices"]:
		var result := _compile_campaign_generation(int(generator_index))
		(
			cells
			. append(
				{
					"generator_index": generator_index,
					"morphology_id":
					String(
						(result.get("proportion_spec", {}) as Dictionary).get("morphology_id", "")
					),
					"generator_receipt_sha256": String(result.get("generator_receipt_sha256", "")),
					"proportion_spec_sha256": String(result.get("proportion_spec_sha256", "")),
					"proportion_spec":
					(result.get("proportion_spec", {}) as Dictionary).duplicate(true),
				}
			)
		)
	return {
		"schema_version": String(campaign["generated_receipt_schema"]),
		"campaign_id": String(campaign["campaign_id"]),
		"cells": cells,
		"actual_world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _validate_generated_cells(preregistration: Dictionary) -> bool:
	var campaign := _campaign_contract()
	var generator_indices := _integer_array(campaign["generator_indices"])
	var expected_cells: Array = preregistration["morphology_generator"]["cells"]
	if expected_cells.size() != _expected_morphology_count():
		return false
	for index in range(expected_cells.size()):
		var expected: Dictionary = expected_cells[index]
		var generator_index := int(expected.get("generator_index", -1))
		if generator_index != int(generator_indices[index]):
			return false
		var result := _verify_campaign_generation(
			generator_index,
			String(expected.get("generator_receipt_sha256", "")),
			String(expected.get("proportion_spec_sha256", "")),
		)
		if (
			not bool(result.get("ok", false))
			or int(result.get("world_build_count", -1)) != 0
			or (
				String((result["proportion_spec"] as Dictionary)["morphology_id"])
				!= String(expected.get("morphology_id", ""))
			)
		):
			return false
	return true


func _validate_static_preflight(preregistration: Dictionary) -> bool:
	var profile_result := MaterialProfilesScript.resolve(_material_profile_id())
	var clock_result := ClockSpecScript.compile(ClockSpecScript.gq15_clock())
	var solver_result := WaveGaitScript.compile_solver_policy_options(SOLVER_POLICY_OPTIONS)
	if (
		not bool(profile_result.get("ok", false))
		or not bool(clock_result.get("ok", false))
		or not bool(solver_result.get("ok", false))
	):
		return false
	for cell_value in preregistration["morphology_generator"]["cells"]:
		var cell: Dictionary = cell_value
		var prepared := _prepare_cell(int(cell["generator_index"]))
		if not bool(prepared.get("ok", false)):
			return false
		var authority_result := (
			WaveGaitScript
			. _normalize_sdk_authority_options(
				prepared["authority_options"],
			)
		)
		var threshold_result := (
			WaveGaitScript
			. compile_evidence_threshold_options(
				prepared["evidence_threshold_options"],
			)
		)
		if (
			not bool(authority_result.get("ok", false))
			or int(authority_result.get("world_build_count", -1)) != 0
			or not bool(threshold_result.get("ok", false))
			or int(threshold_result.get("world_build_count", -1)) != 0
			or (
				String((prepared["authority_options"] as Dictionary)["controller_policy_id"])
				!= _controller_policy_id()
			)
		):
			return false
	for seed_value in preregistration["repetitions"]["campaign_seeds"]:
		var perturbation_result := (
			WaveGaitScript
			. compile_seeded_initial_perturbation(
				int(seed_value),
			)
		)
		if not bool(perturbation_result.get("ok", false)):
			return false
	return true


func _prepare_cell(generator_index: int) -> Dictionary:
	var generation := _compile_campaign_generation(generator_index)
	if not bool(generation.get("ok", false)):
		return generation
	var proportion_spec: Dictionary = generation["proportion_spec"]
	var proportion_compilation := ProportionSpecScript.compile(proportion_spec)
	if not bool(proportion_compilation.get("ok", false)):
		return proportion_compilation
	var profile_result := MaterialProfilesScript.resolve(_material_profile_id())
	if not bool(profile_result.get("ok", false)):
		return profile_result
	var profile: Dictionary = profile_result["profile"]
	var fixture_candidate: Dictionary = (
		(proportion_compilation["fixture_spec"] as Dictionary).duplicate(true)
	)
	fixture_candidate["contact_material"] = (profile["body_material"] as Dictionary).duplicate(true)
	var fixture_result := FixtureSpecScript.compile(fixture_candidate)
	if not bool(fixture_result.get("ok", false)):
		return fixture_result
	var fixture: Dictionary = fixture_result["fixture_spec"]
	var descriptor := {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": String(proportion_spec["morphology_id"]),
		"torso_length_scale": float(proportion_spec["torso_length_scale"]),
		"torso_width_scale": float(proportion_spec["torso_width_scale"]),
		"upper_length_fraction": float(proportion_spec["upper_length_fraction"]),
		"hip_span_scale": float(proportion_spec["hip_span_scale"]),
		"foot_radius_scale": float(proportion_spec["foot_radius_scale"]),
		"front_limb_mass_scale": float(proportion_spec["front_limb_mass_scale"]),
	}
	var authority_options := {
		"enabled": true,
		"descriptor": descriptor,
		"comparison_tolerance": SDK_COMPARISON_TOLERANCE,
		"authority_scope": "post_settle_full",
		"stability_policy_id": _stability_policy_id(),
		"material_profile_id": _material_profile_id(),
		"controller_policy_id": _controller_policy_id(),
	}
	return {
		"ok": true,
		"failure_code": "",
		"generation": generation,
		"proportion_compilation": proportion_compilation,
		"fixture_spec": fixture,
		"fixture_spec_sha256": String(fixture_result["fixture_spec_sha256"]),
		"material_profile": profile,
		"material_profile_sha256": String(profile_result["profile_sha256"]),
		"evidence_threshold_options": _evidence_thresholds(fixture),
		"authority_options": authority_options,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _run_cell(
	generator_index: int,
	seed: int,
	preflight_before_world: bool,
) -> Dictionary:
	var prepared := _prepare_cell(generator_index)
	if not bool(prepared.get("ok", false)):
		return prepared
	var perturbation_result := WaveGaitScript.compile_seeded_initial_perturbation(seed)
	if not bool(perturbation_result.get("ok", false)):
		return perturbation_result
	var clock_result := ClockSpecScript.compile(ClockSpecScript.gq15_clock())
	if not bool(clock_result.get("ok", false)):
		return clock_result
	var environment_challenge_options := _environment_challenge_options_for_cell(
		generator_index,
		seed,
	)
	var sdk_physical_trace_options := _sdk_physical_trace_options_for_cell(
		generator_index,
		seed,
	)
	var selected_policy_full_authority_start: Dictionary = {}
	if preflight_before_world:
		selected_policy_full_authority_start = (_preflight_selected_policy_full_authority_start(
			prepared,
			perturbation_result["initial_perturbation"],
		))
		if not bool(selected_policy_full_authority_start.get("ok", false)):
			return selected_policy_full_authority_start
	var root_child_count_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var summary: Dictionary = await (
		WaveGaitScript
		. new()
		. run(
			self,
			-1.0,
			10.0,
			1.75,
			"lateral",
			72,
			0.40,
			"all",
			112,
			false,
			perturbation_result["initial_perturbation"],
			ROBUSTNESS_OPTIONS,
			prepared["fixture_spec"],
			HOST_OBSERVER_PATH_OPTIONS,
			ACTUATOR_IMPULSE_OPTIONS,
			HOST_PREAUTHORITY_MOTOR_OPTIONS,
			prepared["evidence_threshold_options"],
			clock_result["gait_clock_options"],
			SOLVER_POLICY_OPTIONS,
			{},
			{},
			prepared["authority_options"],
			environment_challenge_options,
			{},
			preflight_before_world,
			{},
			{},
			sdk_physical_trace_options,
		)
	)
	if preflight_before_world:
		summary["selected_policy_full_authority_start"] = (
			selected_policy_full_authority_start.duplicate(true)
		)
		summary["selected_policy_full_authority_start_passed"] = true
		summary["scene_tree_insertion_count"] = (root.get_child_count() - root_child_count_before)
		summary["physics_state_modified"] = (Engine.physics_ticks_per_second != physics_hz_before)
	return summary


func _preflight_selected_policy_full_authority_start(
	prepared: Dictionary,
	initial_perturbation: Dictionary,
) -> Dictionary:
	var root_child_count_before := root.get_child_count()
	var physics_hz_before := Engine.physics_ticks_per_second
	var requested_phase_offset_ticks := int(
		initial_perturbation["gait_phase_offset_ticks"],
	)
	var execution_mode_plan := WaveGaitScript.compile_sdk_execution_mode_plan(
		true,
		true,
		"post_settle_full",
		_stability_policy_id(),
		requested_phase_offset_ticks,
	)
	if not bool(execution_mode_plan.get("ok", false)):
		return execution_mode_plan
	var initial_gait_steps: Dictionary = (
		execution_mode_plan.get("zero_base_initial_gait_steps", {}) as Dictionary
	).duplicate(true)
	var initial_gait_steps_zero := initial_gait_steps.size() == 4
	for initial_gait_step_value in initial_gait_steps.values():
		initial_gait_steps_zero = (
			initial_gait_steps_zero and int(initial_gait_step_value) == 0
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
			"post_settle_full",
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
	var scene_tree_insertion_count := root.get_child_count() - root_child_count_before
	var physics_state_modified := Engine.physics_ticks_per_second != physics_hz_before
	var exact := (
		bool(start.get("ok", false))
		and String(start.get("controller_policy_id", "")) == _controller_policy_id()
		and String(start.get("authority_scope", "")) == "post_settle_full"
		and bool(start.get("actuation_authority", false))
		and String(start.get("stability_policy_id", "")) == _stability_policy_id()
		and String(manifest.get("controller_policy_id", "")) == _controller_policy_id()
		and String(manifest.get("authority_scope", "")) == "post_settle_full"
		and bool(manifest.get("actuation_authority", false))
		and (
			String(manifest.get("execution_mode", ""))
			== _expected_full_authority_execution_mode()
		)
		and int(start.get("world_build_count", -1)) == 0
		and bool(execution_mode_plan.get("full_post_settle_authority_enabled", false))
		and not bool(execution_mode_plan.get("fixed_exposure_enabled", true))
		and not bool(
			execution_mode_plan.get(
				"legacy_base_motor_writes_allowed",
				true,
			)
		)
		and bool(
			execution_mode_plan.get(
				"exclusive_native_post_settle_motor_writes_required",
				false,
			)
		)
		and (
			String(execution_mode_plan.get("phase_offset_application_mode", ""))
			== "scheduled_once_at_warmup_boundary"
		)
		and initial_gait_steps_zero
		and bool(declared_policy_runtime_boundary.get("ok", false))
		and (
			String(
				declared_policy_runtime_boundary.get(
					"controller_policy_id",
					"",
				)
			)
			== _controller_policy_id()
		)
		and (
			String(
				declared_policy_runtime_boundary.get(
					"stability_policy_id",
					"",
				)
			)
			== _stability_policy_id()
		)
		and (
			int(
				declared_policy_runtime_boundary.get(
					"requested_phase_offset_ticks",
					-99,
				)
			)
			== requested_phase_offset_ticks
		)
		and (
			int(
				declared_policy_runtime_boundary.get(
					"actual_world_build_count",
					-1,
				)
			)
			== 0
		)
		and not bool(
			declared_policy_runtime_boundary.get(
				"locomotion_outcome_exposed",
				true,
			)
		)
		and scene_tree_insertion_count == 0
		and not physics_state_modified
		and not bool(start.get("physical_acceptance_authority", true))
	)
	return {
		"schema_version": "sporespore_qsdk_r05_full_authority_start_preflight_v3",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R05_FULL_AUTHORITY_START_INVALID",
		"controller_policy_id": String(start.get("controller_policy_id", "")),
		"authority_scope": String(start.get("authority_scope", "")),
		"actuation_authority": bool(start.get("actuation_authority", false)),
		"stability_policy_id": String(start.get("stability_policy_id", "")),
		"adapter_capability_sha256": String(start.get("adapter_capability_sha256", "")),
		"controller_profile_sha256": String(start.get("controller_profile_sha256", "")),
		"fixture_spec_sha256": String(prepared.get("fixture_spec_sha256", "")),
		"material_profile_sha256": String(prepared.get("material_profile_sha256", "")),
		"requested_phase_offset_ticks": requested_phase_offset_ticks,
		"phase_offset_activation_semantic_step": 360,
		"sdk_execution_mode_plan": execution_mode_plan.duplicate(true),
		"sdk_execution_mode_plan_passed":
		bool(execution_mode_plan.get("ok", false)),
		"declared_policy_runtime_boundary_preflight":
		declared_policy_runtime_boundary.duplicate(true),
		"declared_policy_runtime_boundary_preflight_passed":
		bool(declared_policy_runtime_boundary.get("ok", false)),
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
	var sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var walking_gate_receipts: Dictionary = summary.get("walking_gate_receipts", {})
	var sdk_steps := int(sdk_summary.get("step_count", -1))
	var direct_body_write_count := (
		int(summary.get("direct_torso_force_command_count", -1))
		+ int(summary.get("direct_torso_impulse_command_count", -1))
		+ int(summary.get("direct_torso_velocity_command_count", -1))
		+ int(summary.get("direct_torso_transform_command_count", -1))
	)
	var all_walking_gates_true := _all_true(walking_gate_receipts)
	var common_integrity := (
		int(summary.get("world_build_count", -1)) == 1
		and String(summary.get("physics_engine", "")) == "Jolt Physics"
		and int(summary.get("physics_hz", -1)) == 120
		and int(summary.get("solver_velocity_steps", -1)) == 20
		and int(summary.get("solver_position_steps", -1)) == 7
		and int(summary.get("body_count", -1)) == 9
		and int(summary.get("limb_count", -1)) == 4
		and int(summary.get("world_reset_count", -1)) == 0
		and direct_body_write_count == 0
		and bool(summary.get("sdk_authority_enabled", false))
		and String(summary.get("sdk_authority_scope", "")) == "post_settle_full"
		and String(summary.get("sdk_authority_failure_code", "")).is_empty()
		and bool(sdk_summary.get("ok", false))
		and bool(sdk_summary.get("actuation_authority", false))
		and String(sdk_summary.get("controller_policy_id", "")) == _controller_policy_id()
		and sdk_steps > 0
		and (
			sdk_steps
			== (
				int(summary.get("executed_ticks", -1))
				- int(summary.get("sdk_adapter_start_tick", -1))
			)
		)
		and (
			int(sdk_summary.get("validated_balanced_wave_command_count", -1))
			== sdk_steps * EXPECTED_ACTUATOR_COUNT
		)
		and (
			int(sdk_summary.get("native_actuation_application_count", -1))
			== sdk_steps * EXPECTED_ACTUATOR_COUNT
		)
		and int(summary.get("legacy_post_settle_actuation_application_count", -1)) == 0
		and int(summary.get("legacy_evidence_actuation_application_count", -1)) == 0
		and int(sdk_summary.get("mismatch_count", -1)) == 0
		and int(sdk_summary.get("safe_no_actuation_count", -1)) == 0
		and int(sdk_summary.get("native_safe_disable_application_count", -1)) == 0
		and bool(
			(
				walking_gate_receipts
				. get(
					"native_sdk_exclusive_post_settle_actuation",
					false,
				)
			)
		)
	)
	var walking_observed := (
		common_integrity
		and all_walking_gates_true
		and bool(summary.get("physical_wave_gait_walking_observed", false))
		and bool(summary.get("ok", false))
		and String(summary.get("failure_code", "")).is_empty()
	)
	var evidence: Vector3 = (
		summary
		. get(
			"evidence_torso_displacement_world_m",
			Vector3.ZERO,
		)
	)
	var final_displacement: Vector3 = (
		summary
		. get(
			"final_torso_displacement_world_m",
			Vector3.ZERO,
		)
	)
	var campaign := _campaign_contract()
	var generation := _compile_campaign_generation(int(cell["generator_index"]))
	return {
		"schema_version": String(campaign["cell_receipt_schema"]),
		"campaign_id": String(campaign["campaign_id"]),
		"gate_id": String(campaign["gate_id"]),
		"campaign_role": String(campaign.get("campaign_role", "independent_validation")),
		"morphology_id": String(cell["morphology_id"]),
		"generator_index": int(cell["generator_index"]),
		"campaign_seed": seed,
		"selected_candidate_id": _controller_candidate_id(),
		"controller_policy_id": String(sdk_summary.get("controller_policy_id", "")),
		"sdk_authority_enabled": bool(summary.get("sdk_authority_enabled", false)),
		"sdk_authority_scope": String(summary.get("sdk_authority_scope", "")),
		"sdk_authority_failure_code": String(summary.get("sdk_authority_failure_code", "")),
		"sdk_authority_start_result":
		(summary.get("sdk_authority_start_result", {}) as Dictionary).duplicate(true),
		"selected_policy_digest": _controller_policy_digest(),
		"generator_receipt_sha256": String(generation.get("generator_receipt_sha256", "")),
		"proportion_spec_sha256": String(generation.get("proportion_spec_sha256", "")),
		"fixture_spec_sha256": String(summary.get("fixture_spec_sha256", "")),
		"material_profile_id": _material_profile_id(),
		"material_profile_sha256": String(summary.get("sdk_material_profile_sha256", "")),
		"controller_profile_sha256": String(sdk_summary.get("controller_profile_sha256", "")),
		"adapter_capability_sha256": String(sdk_summary.get("adapter_capability_sha256", "")),
		"common_execution_integrity": common_integrity,
		"walking_observed": walking_observed,
		"walking_gate_receipts": walking_gate_receipts.duplicate(true),
		"world_build_count": int(summary.get("world_build_count", -1)),
		"direct_body_write_count": direct_body_write_count,
		"sdk_step_count": sdk_steps,
		"validated_balanced_wave_command_count":
		int(sdk_summary.get("validated_balanced_wave_command_count", -1)),
		"native_motor_write_count": int(sdk_summary.get("native_actuation_application_count", -1)),
		"legacy_post_settle_motor_write_count":
		int(summary.get("legacy_post_settle_actuation_application_count", -1)),
		"legacy_evidence_motor_write_count":
		int(summary.get("legacy_evidence_actuation_application_count", -1)),
		"sdk_mismatch_count": int(sdk_summary.get("mismatch_count", -1)),
		"sdk_safe_no_actuation_count": int(sdk_summary.get("safe_no_actuation_count", -1)),
		"sdk_safe_disable_count": int(sdk_summary.get("native_safe_disable_application_count", -1)),
		"evidence_displacement_world_m": _vector_dictionary(evidence),
		"final_displacement_world_m": _vector_dictionary(final_displacement),
		"evidence_task_frame_forward_displacement_m":
		float(summary.get("evidence_task_frame_forward_displacement_m", NAN)),
		"final_task_frame_forward_displacement_m":
		float(summary.get("final_task_frame_forward_displacement_m", NAN)),
		"final_task_frame_lateral_displacement_m":
		float(summary.get("final_task_frame_lateral_displacement_m", NAN)),
		"maximum_tilt_rad": float(summary.get("maximum_tilt_rad", NAN)),
		"minimum_torso_height_m": float(summary.get("minimum_torso_height_m", NAN)),
		"maximum_anchor_error_m": float(summary.get("maximum_anchor_error_m", NAN)),
		"maximum_hinge_axis_error_rad": float(summary.get("maximum_hinge_axis_error_rad", NAN)),
		"finite_population_only": true,
		"arbitrary_quadruped_coverage": false,
		"continuous_full_volume_coverage": false,
		"material_robustness": false,
		"cross_engine_c6": false,
		"completed_engine_neutral_sdk": false,
		"physical_acceptance_authority": false,
	}


func _evidence_thresholds(fixture: Dictionary) -> Dictionary:
	var torso: Dictionary = fixture["torso"]
	var torso_size: Array = torso["size_m"]
	var initial_center: Array = torso["initial_center_m"]
	var first_limb: Dictionary = (fixture["limbs"] as Array)[0]
	return {
		"evidence_threshold_policy_id": "nonuniform_dimensionless_thresholds_v1",
		"minimum_foot_relocation_m": 0.0238 * float(torso_size[0]),
		"minimum_evidence_torso_advance_m": 0.080 * float(torso_size[0]),
		"minimum_final_torso_advance_m": 0.060 * float(torso_size[0]),
		"maximum_lateral_drift_m": 0.3125 * float(torso_size[2]),
		"maximum_yaw_drift_rad": 0.45,
		"maximum_tilt_rad": 0.60,
		"minimum_torso_height_m": (25.0 / 44.0) * float(initial_center[1]),
		"maximum_anchor_error_m": 0.14 * float(first_limb["upper_length_m"]),
		"maximum_hinge_axis_error_rad": 0.20,
	}


func _cell_for_morphology(
	preregistration: Dictionary,
	morphology_id: String,
) -> Dictionary:
	for cell_value in preregistration["morphology_generator"]["cells"]:
		var cell: Dictionary = cell_value
		if String(cell.get("morphology_id", "")) == morphology_id:
			return cell
	return {}


func _resolve_physical_request(
	preregistration: Dictionary,
	morphology_id_value: Variant,
	seed_value: Variant,
) -> Dictionary:
	var morphology_id := String(morphology_id_value)
	var seed_text := String(seed_value)
	if not seed_text.is_valid_int():
		return {
			"ok": false,
			"failure_code": "INVALID_QSDK_R05_SEED",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var seed := seed_text.to_int()
	var cell := _cell_for_morphology(preregistration, morphology_id)
	var seed_allowed := (
		_integer_array(
			preregistration["repetitions"]["campaign_seeds"],
		)
		. has(seed)
	)
	if cell.is_empty() or not seed_allowed:
		return {
			"ok": false,
			"failure_code": "UNKNOWN_QSDK_R05_PHYSICAL_CELL",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	return {
		"ok": true,
		"failure_code": "",
		"cell": cell,
		"seed": seed,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _all_true(receipts_value: Variant) -> bool:
	if typeof(receipts_value) != TYPE_DICTIONARY:
		return false
	var receipts: Dictionary = receipts_value
	if receipts.is_empty():
		return false
	for value in receipts.values():
		if typeof(value) != TYPE_BOOL or not bool(value):
			return false
	return true


func _vector_dictionary(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _integer_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var result: Array = []
	for item in value:
		result.append(int(item))
	return result


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", message)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % message)


func _finish() -> void:
	print(
		(
			"\n%s: %d passed, %d failed"
			% [String(_campaign_contract()["display_name"]), _passed, _failed]
		)
	)
	quit(0 if _failed == 0 else 1)
