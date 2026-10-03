extends SceneTree
# gdlint: disable=max-line-length

## L4.6 live Godot/Jolt fixed-root touchdown and observed phase transition.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const AnalyzerScript := preload("res://scripts/lab/mechanics/bounded_touchdown_analyzer.gd")
const RigScript := preload("res://scripts/lab/rigs/bounded_touchdown_rig.gd")

const PHYSICS_HZ := 120
const ACTUATOR_CONFIGURATION := {
	"schema_version": "actuator_spec_v1",
	"actuator_id": "l4_6_bounded_touchdown_actuator",
	"enabled": true,
	"max_isometric_torque_nm": 20.0,
	"no_load_speed_rad_s": 50.0,
	"max_positive_power_w": 0.0,
	"max_absorption_power_w": 0.0,
	"max_eccentric_multiplier": 1.25,
	"activation_time_s": 0.0011,
	"deactivation_time_s": 100.0,
	"max_torque_rate_nm_s": 3000.0,
	"structural_torque_limit_nm": 25.0,
	"tear_dwell_s": 0.05,
	"capacity_source": "explicit_lab",
	"muscle_pcsa_m2": 0.0,
	"specific_tension_pa": 0.0,
	"moment_arm_m": 0.0,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental L4.6 bounded articulated touchdown ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var actuator := ActuatorSpecScript.compile(ACTUATOR_CONFIGURATION)
	_check(bool(actuator.get("ok", false)), "finite two-joint touchdown actuator seals")
	if not bool(actuator.get("ok", false)):
		printerr("  actuator_failure=", actuator)
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var configuration := _configuration(String(actuator["spec"]["spec_sha256"]))
	var built := AnalyzerScript.build(configuration)
	_check(bool(built.get("ok", false)), "digest-bound bounded-touchdown contract seals")
	_test_configuration_refusals(configuration)
	if not bool(built.get("ok", false)):
		printerr("  contract_failure=", built)
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var contract: Dictionary = built["contract"]
	var rig = RigScript.new()
	var run: Dictionary = await rig.run(self, contract, actuator["spec"])
	_check(bool(run.get("ok", false)), "fresh Godot/Jolt touchdown world returns one summary")
	if not bool(run.get("ok", false)):
		printerr("  rig_failure=", run)
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var summary: Dictionary = run["summary"]
	print("  summary=", summary)
	var analysis := AnalyzerScript.analyze(contract, summary)
	_check(
		bool(analysis.get("ok", false)) and bool(analysis["result"]["accepted"]),
		"sealed analyzer accepts the bounded known-floor touchdown"
	)
	if not bool(analysis.get("ok", false)) or not bool(analysis["result"]["accepted"]):
		printerr("  analysis_failure=", analysis)
	_check(
		(
			int(summary["first_touch_tick"]) >= 0
			and int(summary["first_load_tick"]) > int(summary["first_touch_tick"])
			and int(summary["first_bearing_tick"]) > int(summary["first_load_tick"])
			and String(summary["final_phase"]) == "BEARING"
		),
		"real semantic floor evidence advances strictly TOUCH then LOAD then BEARING"
	)
	_check(
		(
			float(summary["touchdown_approach_speed_m_s"]) <= 0.45
			and float(summary["peak_predicted_local_normal_load_n"]) <= 80.0
			and float(summary["maximum_penetration_m"]) <= 0.012
		),
		"landing approach, local predicted load, and penetration remain bounded"
	)
	_check(
		(
			float(summary["final_foot_speed_m_s"]) <= 0.05
			and float(summary["final_horizontal_error_m"]) <= 0.02
		),
		"distal endpoint settles at the declared horizontal landing target"
	)
	_check(
		(
			bool(summary["contact_capacity_complete"])
			and int(summary["non_distal_contact_count"]) == 0
			and not bool(summary["local_load_is_generalized_per_foot_allocation"])
		),
		"only the semantic distal sphere supplies the unsaturated unary load witness"
	)
	_check(
		(
			float(summary["first_touch_tick"]) / float(PHYSICS_HZ)
			<= float(contract["predicted_first_contact_upper_s"])
		),
		"measured first contact stays inside the preregistered reach clock"
	)
	_check(
		(
			float(summary["maximum_pairing_residual_nm"]) <= 1.0e-9
			and int(summary["actuator_saturation_count"]) == 0
			and float(summary["maximum_applied_torque_nm"]) <= 25.0
		),
		"both joint drives remain paired and inside the finite actuator envelope"
	)
	_check(
		(
			bool(summary["fixture_complete"])
			and bool(summary["root_frozen"])
			and bool(summary["motors_disabled"])
			and bool(summary["limits_disabled"])
			and bool(summary["all_receipts_complete"])
		),
		"material root scaffold, passive hinges, and every paired receipt remain explicit"
	)
	_check(
		(
			int(summary["root_assist_operation_count"]) == 0
			and int(summary["foot_pin_operation_count"]) == 0
			and int(summary["pose_teleport_operation_count"]) == 0
			and int(summary["automatic_creature_guidance_operation_count"]) == 0
		),
		"fixture contains no root rescue, foot pin, pose teleport, or guidance operation"
	)
	_check(
		(
			bool(analysis["result"]["touchdown_established"])
			and bool(analysis["result"]["known_landing_bearing_established"])
			and not bool(analysis["result"]["catch_step_established"])
			and not bool(analysis["result"]["support_polygon_improvement_established"])
		),
		"known-floor touchdown cannot become a reachable catch or support improvement"
	)
	_test_analyzer_refusals(contract, summary)
	Engine.physics_ticks_per_second = original_hz
	_finish()


static func _configuration(actuator_sha: String) -> Dictionary:
	return {
		"schema_version": "bounded_touchdown_configuration_v1",
		"physics_hz": PHYSICS_HZ,
		"trial_ticks": 360,
		"target_ramp_ticks": 120,
		"root_height_m": 0.70,
		"root_mass_kg": 2.0,
		"link_mass_kg": 0.25,
		"link_length_m": 0.40,
		"foot_radius_m": 0.055,
		"initial_q1_rad": 1.246,
		"initial_q2_rad": -1.445,
		"target_q1_rad": 0.880,
		"target_q2_rad": -0.901,
		"joint_position_gain_nm_rad": 6.0,
		"joint_velocity_gain_nm_s_rad": 0.8,
		"maximum_touchdown_approach_speed_m_s": 0.45,
		"maximum_predicted_normal_load_n": 80.0,
		"maximum_final_foot_speed_m_s": 0.05,
		"maximum_final_horizontal_error_m": 0.02,
		"maximum_penetration_m": 0.012,
		"predicted_first_contact_upper_s": 1.50,
		"contact_confirm_ticks": 1,
		"load_confirm_ticks": 1,
		"bearing_confirm_ticks": 3,
		"load_enter_n": 0.5,
		"bearing_enter_n": 1.0,
		"maximum_separating_speed_m_s": 0.05,
		"actuator_spec_sha256": actuator_sha,
		"root_frozen_scaffold": true,
		"gravity_enabled": true,
		"contact_enabled": true,
		"built_in_motors_enabled": false,
		"joint_limits_enabled": false,
		"root_assist_enabled": false,
		"foot_pin_enabled": false,
		"pose_teleport_enabled": false,
		"automatic_creature_guidance_enabled": false,
	}


func _test_configuration_refusals(source: Dictionary) -> void:
	var no_contact := source.duplicate(true)
	no_contact["contact_enabled"] = false
	var free_root := source.duplicate(true)
	free_root["root_frozen_scaffold"] = false
	var teleport := source.duplicate(true)
	teleport["pose_teleport_enabled"] = true
	var no_landing := source.duplicate(true)
	no_landing["target_q1_rad"] = 1.246
	no_landing["target_q2_rad"] = -1.445
	_check(
		(
			(
				String(AnalyzerScript.build(no_contact).get("failure_code", ""))
				== "BOUNDED_TOUCHDOWN_FIXTURE_MODE_INVALID"
			)
			and (
				String(AnalyzerScript.build(free_root).get("failure_code", ""))
				== "BOUNDED_TOUCHDOWN_FIXTURE_MODE_INVALID"
			)
			and String(AnalyzerScript.build(teleport).get("failure_code", "")).begins_with(
				"BOUNDED_TOUCHDOWN_FORBIDDEN_ASSIST_OR_AUTHORITY"
			)
			and (
				String(AnalyzerScript.build(no_landing).get("failure_code", ""))
				== "BOUNDED_TOUCHDOWN_LANDING_GEOMETRY_INVALID"
			)
		),
		"missing contact, free root, teleport, and non-landing target fail configuration"
	)


func _test_analyzer_refusals(contract: Dictionary, source: Dictionary) -> void:
	var mutated := contract.duplicate(true)
	mutated["target_q1_rad"] = 0.9
	var phase_skip := source.duplicate(true)
	phase_skip["first_load_tick"] = phase_skip["first_touch_tick"]
	var overload := source.duplicate(true)
	overload["peak_predicted_local_normal_load_n"] = 81.0
	var wrong_shape := source.duplicate(true)
	wrong_shape["non_distal_contact_count"] = 1
	var fake_allocation := source.duplicate(true)
	fake_allocation["local_load_is_generalized_per_foot_allocation"] = true
	_check(
		(
			(
				String(AnalyzerScript.analyze(mutated, source).get("failure_code", ""))
				== "BOUNDED_TOUCHDOWN_CONTRACT_DIGEST_MISMATCH"
			)
			and not bool(AnalyzerScript.analyze(contract, phase_skip)["result"]["accepted"])
			and not bool(AnalyzerScript.analyze(contract, overload)["result"]["accepted"])
			and not bool(AnalyzerScript.analyze(contract, wrong_shape)["result"]["accepted"])
			and not bool(AnalyzerScript.analyze(contract, fake_allocation)["result"]["accepted"])
		),
		"digest mutation, phase skip, overload, wrong shape, and fake allocation fail closed"
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
