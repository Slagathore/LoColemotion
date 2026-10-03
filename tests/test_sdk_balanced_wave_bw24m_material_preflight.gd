extends SceneTree

## BW24M prospective fresh-material declaration and fixture preflight.
##
## This path proves only that the declaration is internally exact, its bound
## sources still match, and all declared Godot/Jolt fixtures construct outside
## the SceneTree. It opens no physics or outcome world and cannot authorize the
## later ten-world characterization.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload("res://scripts/lab/observer_profile.gd")
const RigScript := preload("res://scripts/lab/rigs/sdk_bw24m_friction_ladder_sled_rig.gd")

const PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw24m_fresh_material_preregistration.json"
const RECEIPT_PREFIX := "BW24M_MATERIAL_DECLARATION_PREFLIGHT_RECEIPT "
const TERMINAL_MARKER := (
	"BW24M_MATERIAL_PREFLIGHT_PASS fixtures=4 positive_values=3 "
	+ "worlds=0 scene_insertions=0 wrong_value_rejected=true "
	+ "locomotion_exposed=false physical_authority=false"
)
const EXPECTED_SCHEMA := "sporespore_balanced_wave_bw24m_fresh_material_preregistration_v1"
const CAMPAIGN_ID := "BW24M-BW23Y-FRESH-MATERIAL-CHARACTERIZATION"
const GATE_ID := "BW24M"
const IMPLEMENTATION_PARENT_COMMIT := "f6667c153679adb8e66c3e95da30e77435a7976e"
const EXPECTED_VALUES := [0.59, 0.71, 0.83]
const EXPECTED_FIXTURE_VALUES := [0.0, 0.59, 0.71, 0.83]
const EXPECTED_SEEDS := [26011, 26012, 26013, 26014]
const GODOT_RUNTIME_EXECUTABLE_SHA256 := (
	"baa909d0a905021da80cfc831713e9d3" + "ba4bd0935ac3b93ba4c77dc140cfecc4"
)
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
	var engine_exact := (
		String(engine.get("operating_system_family", "")) == "windows"
		and (
			String(engine.get("godot_runtime_executable_sha256", ""))
			== GODOT_RUNTIME_EXECUTABLE_SHA256
		)
		and String(engine.get("physics_engine", "")) == "Jolt Physics"
		and String(engine.get("godot_runtime_version", "")) == "4.7-stable (official)"
		and int(engine.get("physics_hz", -1)) == PHYSICS_HZ
		and int(engine.get("solver_velocity_steps", -1)) == SOLVER_VELOCITY_STEPS
		and int(engine.get("solver_position_steps", -1)) == SOLVER_POSITION_STEPS
	)
	_check(engine_exact, "1 exact Godot/Jolt host configuration is realized")

	var profile: Dictionary = ObserverProfileScript.resolve(&"full_contacts_v2")
	var observer_exact := bool(profile.get("executable", false))
	_check(observer_exact, "2 full contact observer profile is executable")

	var preregistration := _load_json(PREREGISTRATION_PATH)
	var study: Dictionary = preregistration.get("study_class", {})
	var stages: Dictionary = preregistration.get("pipeline_stages", {})
	var stage_0: Dictionary = stages.get("stage_0_declaration_and_fixture_preflight", {})
	var stage_1: Dictionary = stages.get("stage_1_material_characterization", {})
	var identity_exact := (
		String(preregistration.get("schema_version", "")) == EXPECTED_SCHEMA
		and (
			String(preregistration.get("status", ""))
			== "prospective_declaration_preflight_only_physical_execution_blocked"
		)
		and String(preregistration.get("campaign_id", "")) == CAMPAIGN_ID
		and String(preregistration.get("gate_id", "")) == GATE_ID
		and (
			String(preregistration.get("implementation_parent_commit", ""))
			== IMPLEMENTATION_PARENT_COMMIT
		)
		and (
			String(study.get("classification", ""))
			== "exact_finite_cell_adapter_material_characterization"
		)
		and bool(study.get("finite_decision", false))
		and not bool(study.get("development_screen", true))
		and not bool(study.get("population_inference", true))
		and not bool(study.get("superiority_study", true))
		and not bool(study.get("noninferiority_or_equivalence_study", true))
		and int(study.get("expected_physical_world_count_after_complete_freeze", -1)) == 10
		and not bool(study.get("physical_execution_currently_authorized", true))
		and String(stage_0.get("status", "")) == "prospectively_declared_zero_world_only"
		and int(stage_0.get("physical_world_count", -1)) == 0
		and not bool(stage_0.get("physical_acceptance_authority", true))
		and (
			String(stage_1.get("status", ""))
			== "blocked_until_complete_production_gate_supervisor_and_freeze_are_committed_and_pushed"
		)
		and int(stage_1.get("physical_world_count", -1)) == 10
		and bool(stage_1.get("may_not_open_from_this_declaration_alone", false))
	)
	_check(identity_exact, "3 declaration identity and stage interlocks are exact")

	var successor: Dictionary = preregistration.get("successor_provenance", {})
	var bindings: Dictionary = successor.get("source_bindings", {})
	var sources_exact := (
		(
			String(successor.get("bw22l_disposition", ""))
			== "closed_infrastructure_invalid_not_a_controller_comparison_result"
		)
		and not bool(successor.get("bw22l_b_selected", true))
		and not bool(successor.get("bw22l_b_promoted", true))
		and (
			String(successor.get("bw23y_development_probe_disposition", ""))
			== "three_admissible_nonretained_outcome_exposed_development_worlds_plus_one_rejected_stale_adapter_world"
		)
		and not bool(successor.get("bw23y_selected", true))
		and not bool(successor.get("bw23y_promoted", true))
		and not bool(successor.get("bw22m_values_reused", true))
		and not bool(successor.get("bw22m_seeds_reused", true))
		and not bool(successor.get("same_identity_repair_or_rerun", true))
		and _all_bound_sources_exact(bindings)
	)
	_check(sources_exact, "4 predecessor boundary and source hashes remain exact")

	var reservation: Dictionary = preregistration.get("fresh_reservation", {})
	var reservation_exact := (
		_float_sequence_exact(reservation.get("authored_friction_values", []), EXPECTED_VALUES)
		and is_equal_approx(float(reservation.get("frictionless_safety_value", NAN)), 0.0)
		and _int_sequence_exact(
			reservation.get("downstream_locomotion_seeds", []),
			EXPECTED_SEEDS,
		)
		and bool(reservation.get("prior_informed_development_grid", false))
		and not bool(reservation.get("independent_validation_grid", true))
		and bool(
			reservation.get(
				"values_were_unopened_by_material_characterization_before_this_declaration",
				false,
			)
		)
		and bool(
			reservation.get(
				"values_were_unopened_by_locomotion_before_this_declaration",
				false,
			)
		)
		and bool(
			reservation.get(
				"seeds_were_unopened_by_locomotion_before_this_declaration",
				false,
			)
		)
		and bool(reservation.get("stage_0_opens_no_physics_outcomes", false))
		and bool(
			reservation.get(
				"stage_1_may_open_values_for_adapter_characterization_only",
				false,
			)
		)
		and bool(
			reservation.get(
				"stage_1_does_not_open_downstream_locomotion_seeds",
				false,
			)
		)
		and bool(reservation.get("axis_may_appear_in_no_controller_branch_condition", false))
	)
	_check(reservation_exact, "5 fresh prior-informed values and downstream seeds are sealed")

	var characterization: Dictionary = preregistration.get("material_characterization", {})
	var threshold_provenance: Dictionary = preregistration.get(
		"numeric_threshold_provenance",
		{},
	)
	var matrix_exact := (
		String(characterization.get("adapter_id", "")) == "godot_jolt_gdextension_v1"
		and String(characterization.get("physics_engine", "")) == "Jolt Physics"
		and int(characterization.get("physics_hz", -1)) == PHYSICS_HZ
		and int(characterization.get("solver_velocity_steps", -1)) == SOLVER_VELOCITY_STEPS
		and int(characterization.get("solver_position_steps", -1)) == SOLVER_POSITION_STEPS
		and String(characterization.get("fixture_id", "")) == RigScript.BW24M_FIXTURE_ID
		and _float_sequence_exact(
			characterization.get("authored_friction_values", []),
			EXPECTED_VALUES,
		)
		and int(characterization.get("replicate_count_per_value", -1)) == 3
		and int(characterization.get("frictionless_control_world_count", -1)) == 1
		and int(characterization.get("expected_world_count", -1)) == 10
		and int(characterization.get("expected_gate_count", -1)) == 19
		and int(characterization.get("settle_ticks", -1)) == 180
		and int(characterization.get("force_stage_ticks", -1)) == 60
		and int(characterization.get("analysis_ticks_per_stage", -1)) == 30
		and is_equal_approx(
			float(characterization.get("maximum_breakaway_bracket_width_n", NAN)),
			2.0,
		)
		and is_equal_approx(
			float(characterization.get("maximum_monotonic_ratio_decrease", NAN)),
			0.05,
		)
		and bool(characterization.get("post_result_gate_edit_forbidden", false))
		and not bool(
			threshold_provenance.get("new_bw24m_outcomes_used_to_choose_thresholds", true)
		)
		and _bound_source_exact(threshold_provenance.get("inherited_contract", {}))
		and _bound_source_exact(threshold_provenance.get("accepted_reference_manifest", {}))
		and _bound_source_exact(
			threshold_provenance.get("immediate_operational_precedent", {})
		)
	)
	_check(matrix_exact, "6 matrix and inherited numeric contract are exact")

	var future: Dictionary = preregistration.get("planned_future_bw25y_development_contract", {})
	var candidate_a: Dictionary = future.get("candidate_a", {})
	var candidate_b: Dictionary = future.get("candidate_b", {})
	var future_exact := (
		(
			String(future.get("study_classification", ""))
			== "paired_outcome_unexposed_finite_controller_development_screen"
		)
		and not bool(future.get("population_inference", true))
		and not bool(future.get("superiority_study", true))
		and not bool(future.get("noninferiority_or_equivalence_study", true))
		and _float_sequence_exact(future.get("authored_friction_values", []), EXPECTED_VALUES)
		and _int_sequence_exact(future.get("seeds", []), EXPECTED_SEEDS)
		and _string_sequence_exact(
			future.get("candidate_order", []),
			["BW25Y-A", "BW25Y-B"],
		)
		and (
			String(candidate_a.get("controller_policy_id", ""))
			== "sporespore_balanced_wave_bw15f_b_v1"
		)
		and is_equal_approx(
			float(candidate_a.get("yaw_error_stride_gain_per_rad", NAN)),
			1.3,
		)
		and (
			String(candidate_b.get("controller_policy_id", ""))
			== "sporespore_balanced_wave_bw23y_b_v1"
		)
		and (
			String(candidate_b.get("runtime_profile_sha256", ""))
			== "sha256:d345d9607bed545ee6c58a20055cd6258f38ed581dd3d9f6490a9ae7f1a57570"
		)
		and is_equal_approx(
			float(candidate_b.get("yaw_error_stride_gain_per_rad", NAN)),
			1.0,
		)
		and int(future.get("expected_candidate_world_count", -1)) == 24
		and int(future.get("expected_control_world_count", -1)) == 3
		and int(future.get("expected_zero_friction_safety_world_count", -1)) == 1
		and int(future.get("expected_world_count", -1)) == 28
		and bool(
			future.get(
				"selection_requires_every_candidate_cell_to_be_infrastructure_valid",
				false,
			)
		)
		and bool(
			future.get(
				"selection_requires_complete_policy_relative_receipt_composition",
				false,
			)
		)
		and bool(future.get("receipt_shape_requires_exact_four_walking_keys", false))
		and bool(
			future.get("receipt_shape_requires_controller_coefficient_in_all_worlds", false)
		)
		and bool(
			future.get(
				"receipt_shape_requires_common_identity_fields_in_zero_friction_safety_world",
				false,
			)
		)
		and bool(future.get("stale_debug_adapter_artifact_must_fail_before_any_world", false))
		and bool(
			future.get("selected_candidate_still_requires_distinct_independent_validation", false)
		)
	)
	_check(future_exact, "7 downstream paired development and repaired receipts are exact")

	var stage_0_contract: Dictionary = preregistration.get("stage_0_preflight_contract", {})
	var required_stage_1: Dictionary = preregistration.get(
		"required_stage_1_freeze_contract",
		{},
	)
	var current_claims: Dictionary = preregistration.get("current_claim_boundary", {})
	var blocked_exact := (
		int(stage_0_contract.get("world_build_count", -1)) == 0
		and int(stage_0_contract.get("scene_tree_insertion_count", -1)) == 0
		and int(stage_0_contract.get("physics_state_mutation_count", -1)) == 0
		and not bool(stage_0_contract.get("locomotion_outcome_exposed", true))
		and not bool(stage_0_contract.get("characterization_outcome_exposed", true))
		and not bool(stage_0_contract.get("physical_acceptance_authority", true))
		and bool(
			required_stage_1.get(
				"complete_production_receipt_gate_must_accept_perfect_synthetic_input",
				false,
			)
		)
		and bool(
			required_stage_1.get("complete_one_shot_supervisor_must_be_frozen", false)
		)
		and bool(
			required_stage_1.get(
				"complete_freeze_audit_must_bind_every_production_blob",
				false,
			)
		)
		and not bool(
			required_stage_1.get("physical_execution_authorized_by_this_document_alone", true)
		)
		and bool(current_claims.get("declaration_preflight_only", false))
		and not bool(current_claims.get("material_characterization_complete", true))
		and not bool(current_claims.get("controller_selection", true))
		and not bool(current_claims.get("physical_acceptance_authority", true))
	)
	_check(blocked_exact, "8 physical execution and scientific claims remain blocked")

	var invalid := RigScript.build(CaptureClockScript.new(), profile, 0.81)
	var invalid_rejected := (
		not bool(invalid.get("ok", true))
		and _has_configuration_error(invalid, "SDK_FRICTION_LADDER_VALUE_INVALID")
	)
	_check(invalid_rejected, "9 undeclared prior BW22M value fails closed")

	var fixtures_exact := _float_sequence_exact(
		RigScript.BW24M_AUTHORED_FRICTION_VALUES,
		EXPECTED_FIXTURE_VALUES,
	)
	var fixture_receipts: Array = []
	for friction_value in RigScript.BW24M_AUTHORED_FRICTION_VALUES:
		var friction := float(friction_value)
		var rig := RigScript.build(CaptureClockScript.new(), profile, friction)
		var world_value: Variant = rig.get("world")
		var outside_tree := world_value is Node and not (world_value as Node).is_inside_tree()
		var exact := (
			bool(rig.get("ok", false))
			and String(rig.get("fixture_id", "")) == RigScript.BW24M_FIXTURE_ID
			and outside_tree
			and _material_contract_exact(rig.get("material_contract", {}), friction)
		)
		fixtures_exact = fixtures_exact and exact
		fixture_receipts.append(
			{
				"authored_friction": friction,
				"fixture_id": String(rig.get("fixture_id", "")),
				"outside_scene_tree": outside_tree,
				"material_contract_exact": exact,
			}
		)
		if world_value is Node:
			(world_value as Node).free()
	_check(
		fixtures_exact and fixture_receipts.size() == 4,
		"10 all four fixtures construct without SceneTree insertion",
	)

	var receipt := {
		"schema_version": "sporespore_balanced_wave_bw24m_material_preflight_receipt_v1",
		"ok": _failed == 0,
		"campaign_id": CAMPAIGN_ID,
		"gate_id": GATE_ID,
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": 10,
		"engine": engine,
		"observer_profile_executable": observer_exact,
		"preregistration_identity_exact": identity_exact,
		"source_bindings_exact": sources_exact,
		"reservation_exact": reservation_exact,
		"matrix_contract_exact": matrix_exact,
		"future_development_boundary_exact": future_exact,
		"physical_execution_blocked": blocked_exact,
		"invalid_value_rejected": invalid_rejected,
		"fixture_receipts": fixture_receipts,
		"fixture_construction_count": fixture_receipts.size(),
		"positive_authored_value_count": EXPECTED_VALUES.size(),
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"physics_state_mutation_count": 0,
		"locomotion_outcome_exposed": false,
		"characterization_outcome_exposed": false,
		"physical_acceptance_authority": false,
		"completed_engine_neutral_sdk": false,
	}
	print(RECEIPT_PREFIX, JSON.stringify(receipt, "", true, true))
	if _failed == 0:
		print(TERMINAL_MARKER)
	Engine.physics_ticks_per_second = original_ticks
	quit(0 if _failed == 0 else 1)


static func _all_bound_sources_exact(bindings: Dictionary) -> bool:
	var expected_names := [
		"bw22l_closure",
		"bw22m_characterization_closure",
		"bw22m_profile_publication_closure",
		"bw23y_controller_source",
		"bw23y_runtime_source",
		"bw23y_zero_world_guard",
		"bw23y_profile_inspector",
		"policy_relative_execution_integrity",
		"policy_relative_integrity_test",
		"exact_receipt_composition_preflight",
		"immutable_parent_fixture_wrapper",
		"bw24m_successor_fixture_wrapper",
		"capture_clock",
		"observer_profile",
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


static func _string_sequence_exact(actual_value: Variant, expected: Array) -> bool:
	if not actual_value is Array:
		return false
	var actual: Array = actual_value
	if actual.size() != expected.size():
		return false
	for index in range(expected.size()):
		if String(actual[index]) != String(expected[index]):
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
		String(contract.get("godot_pair_rule", "")) == "highest_friction_both_rough_v1"
		and absf(float(contract.get("authored_friction_cell", NAN)) - friction) <= 1.0e-6
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
		"operating_system_family": OS.get_name().to_lower(),
		"godot_runtime_executable_sha256":
		FileAccess.get_sha256(OS.get_executable_path()).to_lower(),
		"physics_engine": String(ProjectSettings.get_setting("physics/3d/physics_engine", "")),
		"godot_runtime_version": String(Engine.get_version_info().get("string", "")),
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
