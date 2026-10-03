extends SceneTree
# gdlint: disable=max-line-length

## L4.2/L4.5 real Godot/Jolt two-link target placement and swing clearance.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const AnalyzerScript := preload("res://scripts/lab/mechanics/suspended_swing_analyzer.gd")
const RigScript := preload("res://scripts/lab/rigs/suspended_two_link_swing_rig.gd")

const PHYSICS_HZ := 120
const ACTUATOR_CONFIGURATION := {
	"schema_version": "actuator_spec_v1",
	"actuator_id": "l4_2_l4_5_suspended_swing_actuator",
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
	print("=== Experimental L4.2/L4.5 suspended two-link swing ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var actuator := ActuatorSpecScript.compile(ACTUATOR_CONFIGURATION)
	_check(bool(actuator.get("ok", false)), "finite two-joint swing actuator seals")
	if not bool(actuator.get("ok", false)):
		printerr("  actuator_failure=", actuator)
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var configuration := _configuration(String(actuator["spec"]["spec_sha256"]))
	var built := AnalyzerScript.build(configuration)
	_check(bool(built.get("ok", false)), "digest-bound suspended-swing contract seals")
	_test_configuration_refusals(configuration)
	if not bool(built.get("ok", false)):
		printerr("  contract_failure=", built)
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var contract: Dictionary = built["contract"]
	var rig = RigScript.new()
	var run: Dictionary = await rig.run(self, contract, actuator["spec"])
	_check(bool(run.get("ok", false)), "fresh Godot/Jolt swing world returns one complete summary")
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
		"sealed analyzer accepts finite-actuator target placement and positive clearance"
	)
	if not bool(analysis.get("ok", false)) or not bool(analysis["result"]["accepted"]):
		printerr("  analysis_failure=", analysis)
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
			int(summary["first_target_tick"]) >= 0
			and float(summary["final_target_error_m"]) <= 0.012
			and float(summary["final_foot_speed_m_s"]) <= 0.08
		),
		"measured endpoint reaches and settles inside the declared target envelope"
	)
	_check(
		(
			(
				float(summary["first_target_tick"]) / float(PHYSICS_HZ)
				<= float(contract["predicted_reach_upper_s"])
			)
			and float(summary["minimum_clearance_m"]) >= 0.04
			and int(summary["contact_observation_count"]) == 0
		),
		"measured reach fits conservative clock with positive measured clearance and no scuff"
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
			int(summary["root_assist_operation_count"]) == 0
			and int(summary["foot_pin_operation_count"]) == 0
			and int(summary["pose_teleport_operation_count"]) == 0
			and int(summary["automatic_creature_guidance_operation_count"]) == 0
		),
		"fixture contains no root rescue, foot pin, pose teleport, or guidance operation"
	)
	_check(
		(
			not bool(analysis["result"]["touchdown_established"])
			and not bool(analysis["result"]["bearing_established"])
			and not bool(analysis["result"]["catch_step_established"])
		),
		"contact-free swing evidence cannot become touchdown, bearing, or a catch step"
	)
	_test_analyzer_refusals(contract, summary)
	Engine.physics_ticks_per_second = original_hz
	_finish()


static func _configuration(actuator_sha: String) -> Dictionary:
	return {
		"schema_version": "suspended_swing_configuration_v1",
		"physics_hz": PHYSICS_HZ,
		"trial_ticks": 300,
		"root_height_m": 0.70,
		"root_mass_kg": 2.0,
		"link_mass_kg": 0.25,
		"link_length_m": 0.40,
		"foot_radius_m": 0.055,
		"initial_q1_rad": 1.40,
		"target_q1_rad": 1.246,
		"target_q2_rad": -1.445,
		"joint_position_gain_nm_rad": 6.0,
		"joint_velocity_gain_nm_s_rad": 0.8,
		"target_position_tolerance_m": 0.012,
		"target_rate_tolerance_m_s": 0.08,
		"minimum_clearance_m": 0.04,
		"predicted_reach_upper_s": 1.50,
		"actuator_spec_sha256": actuator_sha,
		"root_frozen_scaffold": true,
		"gravity_enabled": true,
		"contact_enabled": false,
		"built_in_motors_enabled": false,
		"joint_limits_enabled": false,
		"root_assist_enabled": false,
		"foot_pin_enabled": false,
		"pose_teleport_enabled": false,
		"automatic_creature_guidance_enabled": false,
	}


func _test_configuration_refusals(source: Dictionary) -> void:
	var unfrozen := source.duplicate(true)
	unfrozen["root_frozen_scaffold"] = false
	var contact := source.duplicate(true)
	contact["contact_enabled"] = true
	var teleport := source.duplicate(true)
	teleport["pose_teleport_enabled"] = true
	_check(
		(
			(
				String(AnalyzerScript.build(unfrozen).get("failure_code", ""))
				== "SUSPENDED_SWING_FIXTURE_MODE_INVALID"
			)
			and (
				String(AnalyzerScript.build(contact).get("failure_code", ""))
				== "SUSPENDED_SWING_FIXTURE_MODE_INVALID"
			)
			and String(AnalyzerScript.build(teleport).get("failure_code", "")).begins_with(
				"SUSPENDED_SWING_FORBIDDEN_ASSIST_OR_AUTHORITY"
			)
		),
		"hidden scaffold change, contact, and pose teleport fail configuration"
	)


func _test_analyzer_refusals(contract: Dictionary, source: Dictionary) -> void:
	var mutated := contract.duplicate(true)
	mutated["target_q1_rad"] = 1.0
	var scuff := source.duplicate(true)
	scuff["minimum_clearance_m"] = -0.001
	var fake_contact := source.duplicate(true)
	fake_contact["contact_observation_count"] = 1
	var missing_receipts := source.duplicate(true)
	missing_receipts["all_receipts_complete"] = false
	_check(
		(
			(
				String(AnalyzerScript.analyze(mutated, source).get("failure_code", ""))
				== "SUSPENDED_SWING_CONTRACT_DIGEST_MISMATCH"
			)
			and not bool(AnalyzerScript.analyze(contract, scuff)["result"]["accepted"])
			and not bool(AnalyzerScript.analyze(contract, fake_contact)["result"]["accepted"])
			and not bool(AnalyzerScript.analyze(contract, missing_receipts)["result"]["accepted"])
		),
		"digest mutation, scuff, forged contact, and missing receipts fail closed"
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
