extends SceneTree

## BW20F prospective Godot/Jolt material-characterization preflight.
##
## This path parses and hash-binds the frozen declaration, constructs every
## declared fixture without SceneTree insertion, and rejects an undeclared
## authored value. It deliberately performs no physics step and opens no
## characterization or locomotion outcome.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload("res://scripts/lab/observer_profile.gd")
const RigScript := preload("res://scripts/lab/rigs/sdk_friction_ladder_sled_rig.gd")

const PREREGISTRATION_PATH := (
	"res://sdk/balanced_wave_bw20f_cold_material_preregistration.json"
)
const RECEIPT_PREFIX := "BW20F_MATERIAL_CHARACTERIZATION_PREFLIGHT_RECEIPT "
const EXPECTED_SCHEMA := (
	"sporespore_balanced_wave_bw20f_cold_material_preregistration_v1"
)
const CAMPAIGN_ID := "BW20F-BW19V-COLD-MATERIAL"
const GATE_ID := "BW20F"
const EXPECTED_VALUES := [0.09, 0.37, 0.76, 1.18]
const EXPECTED_SEEDS := [23001, 23002, 23003]
const PHYSICS_HZ := 120
const SOLVER_VELOCITY_STEPS := 20
const SOLVER_POSITION_STEPS := 7

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	ProjectSettings.set_setting(
		"physics/jolt_physics_3d/simulation/velocity_steps",
		SOLVER_VELOCITY_STEPS,
	)
	ProjectSettings.set_setting(
		"physics/jolt_physics_3d/simulation/position_steps",
		SOLVER_POSITION_STEPS,
	)
	var engine := _engine_receipt()
	_check(
		String(engine.get("physics_engine", "")) == "Jolt Physics"
		and String(engine.get("godot_runtime_version", ""))
		== "4.7-stable (official)"
		and int(engine.get("physics_hz", -1)) == PHYSICS_HZ
		and int(engine.get("solver_velocity_steps", -1))
		== SOLVER_VELOCITY_STEPS
		and int(engine.get("solver_position_steps", -1))
		== SOLVER_POSITION_STEPS,
		"1 exact Godot/Jolt host configuration is realized",
	)

	var profile: Dictionary = ObserverProfileScript.resolve(&"full_contacts_v2")
	var observer_exact := bool(profile.get("executable", false))
	_check(observer_exact, "2 full contact observer profile is executable")

	var preregistration := _load_json(PREREGISTRATION_PATH)
	var study_class: Dictionary = preregistration.get("study_class", {})
	var stages: Dictionary = preregistration.get("pipeline_stages", {})
	var identity_exact := (
		String(preregistration.get("schema_version", "")) == EXPECTED_SCHEMA
		and String(preregistration.get("status", ""))
		== "frozen_before_first_bw20f_characterization_world"
		and String(preregistration.get("campaign_id", "")) == CAMPAIGN_ID
		and String(preregistration.get("gate_id", "")) == GATE_ID
		and String(preregistration.get("implementation_parent_commit", ""))
		== "23f76a41ba0f96a56094350632081acffcc96abe"
		and String(study_class.get("classification", ""))
		== "exact_finite_cell_adapter_material_characterization"
		and bool(study_class.get("finite_decision", false))
		and not bool(study_class.get("development_screen", true))
		and not bool(study_class.get("population_inference", true))
		and not bool(study_class.get("superiority_study", true))
		and not bool(
			study_class.get("noninferiority_or_equivalence_study", true)
		)
		and int(study_class.get("expected_world_count", -1)) == 13
		and String(
			stages.get("stage_1_material_characterization", {}).get(
				"status",
				"",
			)
		)
		== "prospectively_frozen_unopened"
		and String(
			stages.get("stage_3_bw19v_b_cold_locomotion", {}).get(
				"status",
				"",
			)
		)
		== "blocked_until_stage_2_closes_positive_and_a_distinct_manifest_is_frozen"
	)
	_check(identity_exact, "3 study class, identity, and staged interlocks are exact")

	var candidate: Dictionary = preregistration.get("candidate_identity", {})
	var source_bindings: Dictionary = candidate.get("source_bindings", {})
	var sources_exact: bool = (
		String(candidate.get("candidate_id", "")) == "BW19V-B"
		and String(candidate.get("candidate_composition_digest", ""))
		== "sha256:3d0fc7ac8da2de811bbc890a4a2a7b32ffc5f59fb9ee36a3e391cdec65548c77"
		and String(candidate.get("controller_candidate_id", "")) == "BW15F-B"
		and String(candidate.get("controller_policy_id", ""))
		== "sporespore_balanced_wave_bw15f_b_v1"
		and String(candidate.get("controller_policy_digest", ""))
		== "sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd"
		and String(candidate.get("stability_policy_id", ""))
		== "sporespore_scheduled_load_transfer_bw13p_a_v3"
		and is_equal_approx(
			float(candidate.get("global_requested_correction_scale", NAN)),
			0.5,
		)
		and int(candidate.get("policy_branch_surface_count", -1)) == 0
		and candidate.get("branch_surfaces", []).is_empty()
		and _all_bound_sources_exact(source_bindings)
	)
	_check(sources_exact, "4 BW19V-B identity and immutable source bindings are exact")

	var reservation: Dictionary = preregistration.get("cold_reservation", {})
	var continuity: Array = reservation.get("unopened_continuity", [])
	var reservation_exact: bool = (
		_float_sequence_exact(
			reservation.get("authored_friction_values", []),
			EXPECTED_VALUES,
		)
		and _int_sequence_exact(
			reservation.get("locomotion_campaign_seeds", []),
			EXPECTED_SEEDS,
		)
		and bool(
			reservation.get(
				"values_were_unopened_by_locomotion_before_this_freeze",
				false,
			)
		)
		and bool(
			reservation.get(
				"seeds_were_unopened_by_locomotion_before_this_freeze",
				false,
			)
		)
		and bool(
			reservation.get(
				"stage_1_opens_values_for_adapter_characterization_only",
				false,
			)
		)
		and bool(reservation.get("stage_1_does_not_open_locomotion_seeds", false))
		and bool(reservation.get("axis_appears_in_no_controller_branch_condition", false))
		and _bound_source_exact(reservation.get("initial_reservation", {}))
		and continuity.size() == 6
	)
	for entry_value in continuity:
		reservation_exact = (
			reservation_exact
			and entry_value is Dictionary
			and _bound_source_exact(entry_value)
		)
	_check(reservation_exact, "5 cold values and locomotion seeds retain sealed provenance")

	var characterization: Dictionary = preregistration.get(
		"material_characterization",
		{},
	)
	var preflight: Dictionary = preregistration.get("preflight_contract", {})
	var future: Dictionary = preregistration.get(
		"future_bw19v_b_cold_locomotion_contract",
		{},
	)
	var matrix_exact: bool = (
		String(characterization.get("adapter_id", ""))
		== "godot_jolt_gdextension_v1"
		and String(characterization.get("physics_engine", "")) == "Jolt Physics"
		and int(characterization.get("physics_hz", -1)) == PHYSICS_HZ
		and int(characterization.get("solver_velocity_steps", -1))
		== SOLVER_VELOCITY_STEPS
		and int(characterization.get("solver_position_steps", -1))
		== SOLVER_POSITION_STEPS
		and String(characterization.get("fixture_id", ""))
		== RigScript.BW20F_FIXTURE_ID
		and _float_sequence_exact(
			characterization.get("authored_friction_values", []),
			EXPECTED_VALUES,
		)
		and int(characterization.get("replicate_count_per_value", -1)) == 3
		and int(characterization.get("frictionless_control_world_count", -1)) == 1
		and int(characterization.get("expected_world_count", -1)) == 13
		and int(characterization.get("expected_gate_count", -1)) == 23
		and is_equal_approx(
			float(characterization.get("maximum_breakaway_bracket_width_n", NAN)),
			2.0,
		)
		and is_equal_approx(
			float(characterization.get("maximum_monotonic_ratio_decrease", NAN)),
			0.05,
		)
		and bool(characterization.get("post_result_gate_edit_forbidden", false))
		and bool(
			preflight.get(
				"complete_production_receipt_gate_must_accept_perfect_synthetic_input",
				false,
			)
		)
		and int(preflight.get("world_build_count", -1)) == 0
		and int(preflight.get("scene_tree_insertion_count", -1)) == 0
		and _float_sequence_exact(
			future.get("authored_friction_values", []),
			EXPECTED_VALUES,
		)
		and _int_sequence_exact(future.get("seeds", []), EXPECTED_SEEDS)
		and int(future.get("expected_treatment_world_count", -1)) == 12
		and int(future.get("expected_control_world_count", -1)) == 4
		and int(future.get("expected_zero_friction_safety_world_count", -1)) == 1
		and int(future.get("expected_world_count", -1)) == 17
		and int(future.get("treatment_expected_nonzero_application_world_count", -1))
		== 12
		and int(future.get("control_expected_nonzero_application_world_count", -1))
		== 0
		and not bool(future.get("population_inference", true))
		and not bool(future.get("superiority_study", true))
		and not bool(future.get("noninferiority_or_equivalence_study", true))
	)
	_check(matrix_exact, "6 characterization and future policy-relative matrices are frozen")

	var invalid := RigScript.build_bw20f(
		CaptureClockScript.new(),
		profile,
		0.25,
	)
	var invalid_rejected := (
		not bool(invalid.get("ok", true))
		and _has_configuration_error(invalid, "SDK_FRICTION_LADDER_VALUE_INVALID")
	)
	_check(invalid_rejected, "7 undeclared authored friction fails closed")

	var fixtures_exact := true
	var fixture_receipts: Array = []
	for friction_value in RigScript.BW20F_AUTHORED_FRICTION_VALUES:
		var friction := float(friction_value)
		var rig := RigScript.build_bw20f(
			CaptureClockScript.new(),
			profile,
			friction,
		)
		var exact := (
			bool(rig.get("ok", false))
			and String(rig.get("fixture_id", "")) == RigScript.BW20F_FIXTURE_ID
			and _material_contract_exact(rig.get("material_contract", {}), friction)
		)
		fixtures_exact = fixtures_exact and exact
		fixture_receipts.append(
			{
				"authored_friction": friction,
				"fixture_id": String(rig.get("fixture_id", "")),
				"material_contract_exact": exact,
			}
		)
		var world_value: Variant = rig.get("world")
		if world_value is Node:
			(world_value as Node).free()
	_check(
		fixtures_exact and fixture_receipts.size() == 5,
		"8 all five fixtures compile without SceneTree insertion",
	)

	var receipt := {
		"schema_version": "sporespore_balanced_wave_bw20f_preflight_receipt_v1",
		"ok": _failed == 0,
		"campaign_id": CAMPAIGN_ID,
		"gate_id": GATE_ID,
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": 8,
		"engine": engine,
		"observer_profile_executable": observer_exact,
		"preregistration_identity_exact": identity_exact,
		"candidate_source_bindings_exact": sources_exact,
		"reservation_provenance_exact": reservation_exact,
		"matrix_contract_exact": matrix_exact,
		"invalid_value_rejected": invalid_rejected,
		"fixture_receipts": fixture_receipts,
		"fixture_construction_count": fixture_receipts.size(),
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"physics_state_mutation_count": 0,
		"locomotion_outcome_exposed": false,
		"characterization_outcome_exposed": false,
		"physical_acceptance_authority": false,
		"completed_engine_neutral_sdk": false,
	}
	print(RECEIPT_PREFIX, JSON.stringify(receipt, "", true, true))
	Engine.physics_ticks_per_second = original_ticks
	quit(0 if _failed == 0 else 1)


static func _all_bound_sources_exact(bindings: Dictionary) -> bool:
	var expected_names := [
		"bw19v_closure",
		"bw19v_preregistration",
		"bw19v_candidates",
		"bw15f_selected_policy",
	]
	if bindings.size() != expected_names.size():
		return false
	for name in expected_names:
		if not _bound_source_exact(bindings.get(name, {})):
			return false
	return true


static func _float_sequence_exact(actual_value: Variant, expected: Array) -> bool:
	if not actual_value is Array:
		return false
	var actual: Array = actual_value
	if actual.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not is_equal_approx(float(actual[index]), float(expected[index])):
			return false
	return true


static func _int_sequence_exact(actual_value: Variant, expected: Array) -> bool:
	if not actual_value is Array:
		return false
	var actual: Array = actual_value
	if actual.size() != expected.size():
		return false
	for index in range(expected.size()):
		var numeric_value := float(actual[index])
		if not is_equal_approx(numeric_value, float(expected[index])):
			return false
		if not is_equal_approx(numeric_value, roundf(numeric_value)):
			return false
	return true


static func _bound_source_exact(binding_value: Variant) -> bool:
	if not binding_value is Dictionary:
		return false
	var binding: Dictionary = binding_value
	var relative_path := String(binding.get("path", ""))
	var expected_sha256 := String(binding.get("raw_sha256", ""))
	if relative_path.is_empty() or expected_sha256.length() != 64:
		return false
	var resource_path := "res://%s" % relative_path
	return (
		FileAccess.file_exists(resource_path)
		and FileAccess.get_sha256(resource_path).to_lower() == expected_sha256
	)


static func _material_contract_exact(contract: Dictionary, friction: float) -> bool:
	for side_name in ["body", "floor"]:
		var material: Dictionary = contract.get(side_name, {})
		if (
			absf(float(material.get("friction", NAN)) - friction) > 1.0e-6
			or not bool(material.get("rough", false))
			or absf(float(material.get("bounce", NAN))) > 1.0e-9
			or not bool(material.get("absorbent", false))
		):
			return false
	return (
		String(contract.get("godot_pair_rule", ""))
		== "highest_friction_both_rough_v1"
		and absf(float(contract.get("authored_friction_cell", NAN)) - friction)
		<= 1.0e-6
		and not bool(contract.get("portable_material_coefficient", true))
		and not bool(contract.get("locomotion_robustness", true))
	)


static func _has_configuration_error(result: Dictionary, code: String) -> bool:
	for error_value in result.get("configuration_errors", []):
		var error: Dictionary = error_value
		if String(error.get("code", "")) == code:
			return true
	return false


static func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return value if value is Dictionary else {}


static func _engine_receipt() -> Dictionary:
	return {
		"physics_engine": String(
			ProjectSettings.get_setting("physics/3d/physics_engine", "")
		),
		"godot_runtime_version": String(
			Engine.get_version_info().get("string", "")
		),
		"physics_hz": Engine.physics_ticks_per_second,
		"solver_velocity_steps": int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/velocity_steps",
				-1,
			)
		),
		"solver_position_steps": int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/position_steps",
				-1,
			)
		),
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)
