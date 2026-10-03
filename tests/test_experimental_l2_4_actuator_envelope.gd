extends SceneTree

## Experimental BR4/L2.4 live torque/speed/power envelope.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const AnalyzerScript := preload("res://scripts/lab/mechanics/actuator_envelope_analyzer.gd")
const RigScript := preload("res://scripts/lab/rigs/free_hinge_envelope_rig.gd")

const PHYSICS_HZ := 120
const PARENT_MASS_KG := 2.0
const PARENT_SIZE_M := Vector3(0.5, 0.4, 0.2)
const CHILD_MASS_KG := 1.0
const CHILD_SIZE_M := Vector3(0.3, 0.2, 0.2)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR4/L2.4 actuator envelope ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var cases := [
		["isometric_cap", 2.0, 0.0],
		["speed_cap_low", 2.0, 2.0],
		["positive_power_cap", 2.0, 5.0],
		["near_no_load_speed", 2.0, 9.0],
		["no_load_speed", 2.0, 10.0],
		["negative_work_absorption", -2.0, 5.0],
	]
	var builds: Array[Dictionary] = []
	for case in cases:
		builds.append(
			AnalyzerScript.build(_configuration(String(case[0]), float(case[1]), float(case[2])))
		)
	_check(_all_builds_ok(builds), "all six envelope points seal into exact contracts")
	_test_configuration_refusals()
	var actuator_build: Dictionary = ActuatorSpecScript.compile(_actuator_configuration())
	_check(bool(actuator_build.get("ok", false)), "finite torque/speed/power actuator compiles")
	if not _all_builds_ok(builds) or not bool(actuator_build.get("ok", false)):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var rig = RigScript.new()
	var trials: Array[Dictionary] = []
	for build in builds:
		trials.append(await rig.run(self, build["contract"], actuator_build["spec"]))
	for index in trials.size():
		_print_result(String(builds[index]["contract"]["case_id"]), trials[index])
	_check(
		_all_trial_field(trials, "fixture_complete"), "all live envelope transitions are complete"
	)
	_check(
		_all_trial_field(trials, "analysis_ok"), "all live points satisfy digest-bound analyzers"
	)
	if not _all_trial_field(trials, "analysis_ok"):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var results: Array[Dictionary] = []
	for trial in trials:
		results.append(trial["result"])
	_check(_all_result_field(results, "accepted"), "all six measured envelope points pass L2.4")
	_check(
		(
			is_equal_approx(float(results[0]["applied_torque_nm"]), 1.0)
			and is_equal_approx(float(results[1]["applied_torque_nm"]), 0.8)
			and is_equal_approx(float(results[2]["applied_torque_nm"]), 0.4)
			and is_equal_approx(float(results[3]["applied_torque_nm"]), 0.1)
			and absf(float(results[4]["applied_torque_nm"])) <= 1.0e-9
			and is_equal_approx(float(results[5]["applied_torque_nm"]), -0.6)
		),
		"measured feasibility curve matches isometric, speed, power, no-load, and absorption caps"
	)
	_check(
		(
			bool(results[1]["speed_limited"])
			and bool(results[2]["power_limited"])
			and bool(results[3]["speed_limited"])
			and bool(results[4]["speed_limited"])
			and bool(results[5]["power_limited"])
		),
		"each non-isometric cap is classified by its actual limiting cause"
	)
	_check(
		_all_acceleration_oracles_match(results),
		"every applied cap produces the predicted live relative angular acceleration"
	)
	_check(
		_all_live_exclusions(trials),
		"live free-hinge cells exclude the built-in motor and hard limit"
	)
	_test_analyzer_refusals(builds[2]["contract"], trials[2]["sample"])
	_check(
		(
			String(results[2]["claim_boundary"])
			== (
				"Exact one-transition, gravity-off, contact-free free-hinge actuator-envelope "
				+ "fixture only; no endurance, load bearing, standing, bracing, recovery, "
				+ "gait, or walking claim."
			)
		),
		"L2.4 result carries the exact one-transition non-claim boundary"
	)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_configuration_refusals() -> void:
	var hidden_gravity := _configuration("hidden_gravity", 2.0, 2.0)
	hidden_gravity["gravity_enabled"] = true
	var excessive_rate := _configuration("excessive_rate", 2.0, 25.0)
	var unknown := _configuration("unknown", 2.0, 2.0)
	unknown["unbounded_power"] = true
	_check(
		(
			not bool(AnalyzerScript.build(hidden_gravity).get("ok", true))
			and not bool(AnalyzerScript.build(excessive_rate).get("ok", true))
			and not bool(AnalyzerScript.build(unknown).get("ok", true))
		),
		"envelope contract rejects hidden gravity, out-of-domain rate, and unknown fields"
	)


func _test_analyzer_refusals(contract: Dictionary, sample: Dictionary) -> void:
	var mutated := contract.duplicate(true)
	mutated["requested_torque_nm"] = 1.5
	var mutated_result: Dictionary = AnalyzerScript.analyze(mutated, sample)
	var nonfinite := sample.duplicate(true)
	nonfinite["relative_rate_after_rad_s"] = NAN
	var nonfinite_result: Dictionary = AnalyzerScript.analyze(contract, nonfinite)
	var missing_receipt := sample.duplicate(true)
	missing_receipt["receipt_count"] = 1
	var receipt_result: Dictionary = AnalyzerScript.analyze(contract, missing_receipt)
	_check(
		(
			(
				String(mutated_result.get("failure_code", ""))
				== "ACTUATOR_ENVELOPE_CONTRACT_DIGEST_MISMATCH"
			)
			and (
				String(nonfinite_result.get("failure_code", ""))
				== "ACTUATOR_ENVELOPE_SAMPLE_NONFINITE"
			)
			and bool(receipt_result.get("ok", false))
			and not bool(receipt_result["result"]["accepted"])
		),
		"mutated contract, nonfinite rate, and missing receipt all fail closed"
	)


static func _configuration(case_id: String, request_nm: float, rate_rad_s: float) -> Dictionary:
	return {
		"schema_version": "actuator_envelope_case_configuration_v1",
		"case_id": case_id,
		"physics_hz": PHYSICS_HZ,
		"requested_torque_nm": request_nm,
		"initial_relative_rate_rad_s": rate_rad_s,
		"max_isometric_torque_nm": 1.0,
		"no_load_speed_rad_s": 10.0,
		"max_positive_power_w": 2.0,
		"max_absorption_power_w": 3.0,
		"max_eccentric_multiplier": 1.5,
		"parent_mass_kg": PARENT_MASS_KG,
		"parent_size_m": PARENT_SIZE_M,
		"child_mass_kg": CHILD_MASS_KG,
		"child_size_m": CHILD_SIZE_M,
		"gravity_enabled": false,
		"contact_enabled": false,
		"built_in_motor_enabled": false,
		"limit_enabled": false,
	}


static func _actuator_configuration() -> Dictionary:
	return {
		"schema_version": "actuator_spec_v1",
		"actuator_id": "l2_4_finite_envelope_motor",
		"enabled": true,
		"max_isometric_torque_nm": 1.0,
		"no_load_speed_rad_s": 10.0,
		"max_positive_power_w": 2.0,
		"max_absorption_power_w": 3.0,
		"max_eccentric_multiplier": 1.5,
		"activation_time_s": 0.0011,
		"deactivation_time_s": 100.0,
		"max_torque_rate_nm_s": 10000.0,
		"structural_torque_limit_nm": 5.0,
		"tear_dwell_s": 0.05,
		"capacity_source": "explicit_lab",
		"muscle_pcsa_m2": 0.0,
		"specific_tension_pa": 0.0,
		"moment_arm_m": 0.0,
	}


static func _all_builds_ok(builds: Array[Dictionary]) -> bool:
	for build in builds:
		if not bool(build.get("ok", false)):
			return false
	return true


static func _all_trial_field(trials: Array[Dictionary], field: String) -> bool:
	for trial in trials:
		if not bool(trial.get(field, false)):
			return false
	return true


static func _all_result_field(results: Array[Dictionary], field: String) -> bool:
	for result in results:
		if not bool(result.get(field, false)):
			return false
	return true


static func _all_acceleration_oracles_match(results: Array[Dictionary]) -> bool:
	for result in results:
		if float(result["relative_rate_delta_error_fraction"]) > 0.02:
			return false
	return true


static func _all_live_exclusions(trials: Array[Dictionary]) -> bool:
	for trial in trials:
		if not bool(trial["motor_disabled"]) or not bool(trial["limit_disabled"]):
			return false
	return true


static func _print_result(label: String, trial: Dictionary) -> void:
	if not bool(trial.get("analysis_ok", false)):
		print("  %s analysis_failure=%s" % [label, str(trial.get("analysis_failure", {}))])
		return
	var result: Dictionary = trial["result"]
	print(
		(
			(
				"  %s accepted=%s qdot=%.2f req=%.3f applied=%.5fNm regime=%s "
				+ "speed=%s power=%s accel_err=%.4f%% failures=%s"
			)
			% [
				label,
				str(bool(result["accepted"])),
				float(result["initial_relative_rate_rad_s"]),
				float(result["requested_torque_nm"]),
				float(result["applied_torque_nm"]),
				String(result["selected_work_regime"]),
				str(bool(result["speed_limited"])),
				str(bool(result["power_limited"])),
				100.0 * float(result["relative_rate_delta_error_fraction"]),
				str(result["acceptance_failures"]),
			]
		)
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
