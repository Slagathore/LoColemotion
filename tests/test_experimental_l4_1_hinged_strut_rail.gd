extends SceneTree
# gdlint: disable=max-line-length

## BR6A/L4.1 one-hinge static loaded-support curve.

const AnalyzerScript := preload(
	"res://scripts/lab/mechanics/hinged_strut_rail_analyzer.gd"
)
const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const JointActuatorScript := preload("res://scripts/lab/mechanics/joint_actuator.gd")
const RigScript := preload("res://scripts/lab/rigs/hinged_strut_rail_rig.gd")

const PHYSICS_HZ := 60
const CONFIGURATION := {
	"schema_version": "hinged_strut_rail_configuration_v1",
	"physics_hz": PHYSICS_HZ,
	"settle_ticks": 60,
	"analysis_ticks": 120,
	"angles_deg": [0.0, 15.0, 30.0, 45.0],
	"control_angle_deg": 30.0,
	"carriage_mass_kg": 2.0,
	"link_mass_kg": 1.0,
	"link_length_m": 0.60,
	"maximum_torque_error_nm": 0.02,
	"maximum_support_load_error_n": 0.35,
	"maximum_angle_error_rad": 0.015,
	"maximum_height_drift_m": 0.01,
	"maximum_joint_rate_rad_s": 0.03,
	"minimum_floor_contact_fraction": 0.99,
	"maximum_abs_hold_work_j": 0.02,
	"minimum_control_angle_error_rad": 0.05,
	"hold_position_gain_nm_rad": 80.0,
	"hold_velocity_gain_nm_s_rad": 10.0,
	"built_in_motor_enabled": false,
	"hinge_limit_enabled": false,
	"passive_tissues_enabled": false,
	"controller_root_force_enabled": false,
}
const ACTUATOR_CONFIGURATION := {
	"schema_version": "actuator_spec_v1",
	"actuator_id": "l4_1_loaded_hinge_explicit_actuator",
	"enabled": true,
	"max_isometric_torque_nm": 20.0,
	"no_load_speed_rad_s": 50.0,
	"max_positive_power_w": 100.0,
	"max_absorption_power_w": 100.0,
	"max_eccentric_multiplier": 1.25,
	"activation_time_s": 0.0011,
	"deactivation_time_s": 100.0,
	"max_torque_rate_nm_s": 10000.0,
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
	print("=== Experimental BR6A/L4.1 hinged-strut static load curve ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	_test_configuration_refusals()
	var built := AnalyzerScript.build(CONFIGURATION)
	var actuator := ActuatorSpecScript.compile(ACTUATOR_CONFIGURATION)
	_check(
		bool(built.get("ok", false)) and bool(actuator.get("ok", false)),
		"strict L4.1 configuration and finite actuator seal"
	)
	if not bool(built.get("ok", false)) or not bool(actuator.get("ok", false)):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var rig = RigScript.new()
	var trials: Array = []
	var complete := true
	for angle_value in CONFIGURATION["angles_deg"]:
		var trial: Dictionary = await rig.run(
			self,
			built["configuration"],
			actuator["spec"],
			float(angle_value),
			true
		)
		complete = complete and bool(trial.get("ok", false))
		trials.append(trial.get("summary", {}))
	var control: Dictionary = await rig.run(
		self,
		built["configuration"],
		actuator["spec"],
		float(CONFIGURATION["control_angle_deg"]),
		false
	)
	complete = complete and bool(control.get("ok", false))
	trials.append(control.get("summary", {}))
	for trial in trials:
		_print_trial(trial)
	_check(complete, "all five real-Jolt loaded-hinge worlds retain complete receipts and samples")
	var analysis := AnalyzerScript.analyze(built["configuration"], trials)
	_check(bool(analysis.get("ok", false)), "digest-bound L4.1 analyzer accepts the exact grid")
	if not bool(analysis.get("ok", false)):
		printerr("  analysis_failure=", analysis)
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	_check(bool(analysis["accepted"]), "four static holds and the zero-torque control pass L4.1")
	_check(
		int(analysis["hold_trial_count"]) == 4
			and float(analysis["maximum_hold_torque_error_nm"]) <= 0.02,
		"paired finite actuator torque follows the analytic loaded-hinge curve"
	)
	_check(
		float(analysis["maximum_hold_support_error_n"]) <= 0.35,
		"whole-system reconstruction retains total weight support at every angle"
	)
	_check(
		float(analysis["maximum_hold_angle_error_rad"]) <= 0.015
			and float(analysis["maximum_abs_hold_work_j"]) <= 0.02,
		"static holds retain angle with near-zero actuator work"
	)
	_check(
		bool(analysis["control_failed_as_predicted"]),
		"the matched zero-torque control cannot masquerade as a supported hinge hold"
	)
	_check(
		bool(analysis["rail_scaffold_present"])
			and not bool(analysis["motor_or_passive_assist_present"]),
		"rail reaction remains explicit while built-in motor, passive, and root-force assist stay absent"
	)
	_test_analyzer_refusals(built["configuration"], trials)
	var exclusions: Array = analysis["does_not_establish"]
	_check(
		exclusions.has("two_link_leg")
			and exclusions.has("standing")
			and exclusions.has("walking")
			and exclusions.has("per_foot_load_allocation"),
		"L4.1 proves no two-link support, balance, standing, or walking"
	)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_configuration_refusals() -> void:
	var motor := CONFIGURATION.duplicate(true)
	motor["built_in_motor_enabled"] = true
	var root_force := CONFIGURATION.duplicate(true)
	root_force["controller_root_force_enabled"] = true
	var passive := CONFIGURATION.duplicate(true)
	passive["passive_tissues_enabled"] = true
	var grid := CONFIGURATION.duplicate(true)
	grid["angles_deg"] = [0.0, 30.0, 45.0]
	_check(
		not bool(AnalyzerScript.build(motor).get("ok", true))
			and not bool(AnalyzerScript.build(root_force).get("ok", true))
			and not bool(AnalyzerScript.build(passive).get("ok", true))
			and not bool(AnalyzerScript.build(grid).get("ok", true)),
		"configuration rejects motor, root-force, passive capacity, and incomplete angle grids"
	)


func _test_analyzer_refusals(configuration: Dictionary, trials: Array) -> void:
	var mutated := configuration.duplicate(true)
	mutated["maximum_torque_error_nm"] = 10.0
	var digest_failure := AnalyzerScript.analyze(mutated, trials)
	var missing := trials.duplicate(true)
	missing.pop_back()
	var missing_failure := AnalyzerScript.analyze(configuration, missing)
	var assisted := trials.duplicate(true)
	(assisted[0] as Dictionary)["root_assistance_operation_count"] = 1
	var assisted_failure := AnalyzerScript.analyze(configuration, assisted)
	_check(
		String(digest_failure.get("failure_code", ""))
				== "HINGED_STRUT_CONFIG_DIGEST_MISMATCH"
			and String(missing_failure.get("failure_code", ""))
				== "HINGED_STRUT_TRIAL_COUNT_MISMATCH"
			and (
				not bool(assisted_failure.get("accepted", true))
				and (assisted_failure.get("acceptance_failures", []) as Array).has(
					"HINGED_STRUT_HOLD_INTEGRITY:0.0"
				)
			),
		"digest mutation, missing control, and root-assist forgery fail closed"
	)


static func _print_trial(trial: Dictionary) -> void:
	print(
		(
			"  mode=%s angle=%5.1fdeg tau=%9.5f/%9.5fNm support=%8.4fN "
			+ "angle_err=%.6frad height=%.6fm rate=%.6frad/s contact=%.3f work=%.6fJ"
		)
		% [
			String(trial.get("mode", "")),
			float(trial.get("target_angle_deg", NAN)),
			float(trial.get("mean_applied_torque_nm", NAN)),
			float(trial.get("mean_expected_torque_nm", NAN)),
			float(trial.get("mean_reconstructed_support_n", NAN)),
			float(trial.get("maximum_angle_error_rad", NAN)),
			float(trial.get("maximum_height_drift_m", NAN)),
			float(trial.get("maximum_joint_rate_rad_s", NAN)),
			float(trial.get("floor_contact_fraction", NAN)),
			float(trial.get("active_work_j", NAN)),
		]
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
