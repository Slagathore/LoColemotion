extends SceneTree

## BW27M zero-world declaration and actual-fixture constructor preflight.
##
## Every declared rig is built as an object graph outside the SceneTree and
## freed without a physics step. This proves constructor reachability and the
## authored-value firewall only; it cannot characterize friction or authorize
## the later one-shot supervisor.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload("res://scripts/lab/observer_profile.gd")
const RigScript := preload("res://scripts/lab/rigs/sdk_bw27m_friction_ladder_sled_rig.gd")

const PREREGISTRATION_PATH := "res://sdk/balanced_wave_bw27m_fresh_material_preregistration.json"
const RECEIPT_PREFIX := "BW27M_MATERIAL_DECLARATION_PREFLIGHT_RECEIPT "
const TERMINAL_MARKER := (
	"BW27M_MATERIAL_PREFLIGHT_PASS fixtures=4 positive_values=3 "
	+ "worlds=0 scene_insertions=0 wrong_value_rejected=true "
	+ "locomotion_exposed=false physical_authority=false"
)
const EXPECTED_SCHEMA := "sporespore_balanced_wave_bw27m_fresh_material_preregistration_v1"
const CAMPAIGN_ID := "BW27M-BW25Y-FRESH-MATERIAL-CHARACTERIZATION"
const GATE_ID := "BW27M"
const EXPECTED_VALUES := [0.62, 0.74, 0.86]
const EXPECTED_FIXTURE_VALUES := [0.0, 0.62, 0.74, 0.86]
const EXPECTED_SEEDS := [27011, 27012, 27013, 27014]
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
		and String(engine.get("godot_runtime_executable_sha256", ""))
		== GODOT_RUNTIME_EXECUTABLE_SHA256
		and String(engine.get("physics_engine", "")) == "Jolt Physics"
		and String(engine.get("godot_runtime_version", "")) == "4.7-stable (official)"
		and int(engine.get("physics_hz", -1)) == PHYSICS_HZ
		and int(engine.get("solver_velocity_steps", -1)) == SOLVER_VELOCITY_STEPS
		and int(engine.get("solver_position_steps", -1)) == SOLVER_POSITION_STEPS
	)
	_check(engine_exact, "1 exact Godot/Jolt host configuration is realized")

	var preregistration := _load_json(PREREGISTRATION_PATH)
	var reservation: Dictionary = preregistration.get("fresh_reservation", {})
	var planned: Dictionary = preregistration.get("planned_material_characterization", {})
	var identity_exact := (
		String(preregistration.get("schema_version", "")) == EXPECTED_SCHEMA
		and String(preregistration.get("campaign_id", "")) == CAMPAIGN_ID
		and String(preregistration.get("gate_id", "")) == GATE_ID
		and String(preregistration.get("status", ""))
		== "prospective_reservation_and_stage_order_only_physical_execution_blocked"
	)
	_check(identity_exact, "2 declaration identity is exact")

	var reservation_exact := (
		_float_sequence_exact(reservation.get("authored_friction_values", []), EXPECTED_VALUES)
		and _int_sequence_exact(reservation.get("downstream_locomotion_seeds", []), EXPECTED_SEEDS)
		and bool(reservation.get("values_were_absent_from_parent_authored_and_reserved_friction_set", false))
		and bool(reservation.get("seeds_were_absent_from_parent_campaign_and_reserved_seed_set", false))
		and bool(reservation.get("stage_0_opens_no_physics_outcomes", false))
		and bool(reservation.get("axis_may_appear_in_no_controller_branch_condition", false))
	)
	_check(reservation_exact, "3 fresh value and seed reservation is exact")

	var planned_exact := (
		String(planned.get("fixture_id", "")) == RigScript.BW27M_FIXTURE_ID
		and _float_sequence_exact(planned.get("authored_friction_values", []), EXPECTED_VALUES)
		and int(planned.get("replicate_count_per_value", -1)) == 3
		and int(planned.get("frictionless_control_world_count", -1)) == 1
		and int(planned.get("expected_world_count", -1)) == 10
		and int(planned.get("expected_gate_count", -1)) == 19
		and bool(planned.get("characterization_may_not_run_locomotion", false))
		and not bool(planned.get("locomotion_robustness", true))
	)
	_check(planned_exact, "4 planned exact finite characterization is bounded")

	var stage_1: Dictionary = preregistration.get("pipeline_stages", {}).get(
		"stage_1_material_characterization",
		{},
	)
	var claims: Dictionary = preregistration.get("current_claim_boundary", {})
	var blocked_exact := (
		bool(stage_1.get("may_not_open_from_this_document", false))
		and not bool(claims.get("material_characterization_complete", true))
		and not bool(claims.get("walking_acceptance", true))
		and not bool(claims.get("turning_acceptance", true))
		and not bool(claims.get("physical_acceptance_authority", true))
	)
	_check(blocked_exact, "5 physical execution and claims remain blocked")

	var profile: Dictionary = ObserverProfileScript.resolve(&"full_contacts_v2")
	var invalid := RigScript.build(CaptureClockScript.new(), profile, 0.83)
	var invalid_rejected := (
		not bool(invalid.get("ok", true))
		and _has_configuration_error(invalid, "SDK_FRICTION_LADDER_VALUE_INVALID")
	)
	_check(invalid_rejected, "6 an undeclared predecessor value fails closed")

	var fixtures_exact := _float_sequence_exact(
		RigScript.BW27M_AUTHORED_FRICTION_VALUES,
		EXPECTED_FIXTURE_VALUES,
	)
	var fixture_receipts: Array = []
	for friction_value in RigScript.BW27M_AUTHORED_FRICTION_VALUES:
		var friction := float(friction_value)
		var rig := RigScript.build(CaptureClockScript.new(), profile, friction)
		var world_value: Variant = rig.get("world")
		var outside_tree := world_value is Node and not (world_value as Node).is_inside_tree()
		var exact := (
			bool(rig.get("ok", false))
			and String(rig.get("fixture_id", "")) == RigScript.BW27M_FIXTURE_ID
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
	_check(fixtures_exact and fixture_receipts.size() == 4, "7 all fixtures construct outside SceneTree")

	var receipt := {
		"schema_version": "sporespore_balanced_wave_bw27m_material_preflight_receipt_v1",
		"ok": _failed == 0,
		"campaign_id": CAMPAIGN_ID,
		"gate_id": GATE_ID,
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": 7,
		"engine": engine,
		"preregistration_identity_exact": identity_exact,
		"reservation_exact": reservation_exact,
		"planned_characterization_exact": planned_exact,
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
	}
	print(RECEIPT_PREFIX, JSON.stringify(receipt, "", true, true))
	if _failed == 0:
		print(TERMINAL_MARKER)
	Engine.physics_ticks_per_second = original_ticks
	quit(0 if _failed == 0 else 1)


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


static func _float_sequence_exact(actual_value: Variant, expected: Array) -> bool:
	if not actual_value is Array:
		return false
	var actual: Array = actual_value
	if actual.size() != expected.size():
		return false
	for index in range(expected.size()):
		if absf(float(actual[index]) - float(expected[index])) > 1.0e-12:
			return false
	return true


static func _int_sequence_exact(actual_value: Variant, expected: Array) -> bool:
	if not actual_value is Array:
		return false
	var actual: Array = actual_value
	if actual.size() != expected.size():
		return false
	for index in range(expected.size()):
		if int(actual[index]) != int(expected[index]):
			return false
	return true


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
		"godot_runtime_executable_sha256": FileAccess.get_sha256(OS.get_executable_path()).to_lower(),
		"physics_engine": String(ProjectSettings.get_setting("physics/3d/physics_engine", "")),
		"godot_runtime_version": String(Engine.get_version_info().get("string", "")),
		"physics_hz": Engine.physics_ticks_per_second,
		"solver_velocity_steps": int(
			ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/velocity_steps", -1)
		),
		"solver_position_steps": int(
			ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/position_steps", -1)
		),
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)
