extends SceneTree

## Experimental BR4/L2.3 loaded horizontal-link gravity hold.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const AnalyzerScript := preload("res://scripts/lab/mechanics/gravity_hold_analyzer.gd")
const RigScript := preload("res://scripts/lab/rigs/fixed_hinge_gravity_rig.gd")

const PHYSICS_HZ := 120
const SAMPLE_TICKS := 30
const MASS_KG := 2.0
const LENGTH_M := 0.5
const WIDTH_M := 0.08
const DEPTH_M := 0.08
const GRAVITY_M_S2 := 9.8

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR4/L2.3 fixed-scaffold gravity hold ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var builds: Array[Dictionary] = []
	for trial in [
		["zero_compensation", 0.0],
		["under_compensation", 0.8],
		["exact_compensation", 1.0],
		["over_compensation", 1.2],
	]:
		builds.append(AnalyzerScript.build(_configuration(String(trial[0]), float(trial[1]))))
	_check(_all_builds_ok(builds), "zero, under, exact, and over compensation contracts seal")
	_test_configuration_refusals()
	var actuator_build: Dictionary = ActuatorSpecScript.compile(_actuator_configuration())
	_check(
		bool(actuator_build.get("ok", false)), "gravity-hold explicit laboratory actuator compiles"
	)
	if not _all_builds_ok(builds) or not bool(actuator_build.get("ok", false)):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var rig = RigScript.new()
	var trials: Array[Dictionary] = []
	for build in builds:
		trials.append(await rig.run(self, build["contract"], actuator_build["spec"]))
	for index in trials.size():
		_print_result(String(builds[index]["contract"]["trial_id"]), trials[index])
	_check(
		_all_trial_field_true(trials, "fixture_complete"),
		"all four fresh-world loaded fixtures retain complete command and joint evidence"
	)
	_check(
		_all_trial_field_true(trials, "analysis_ok"),
		"all four loaded traces satisfy their digest-bound analyzer contracts"
	)
	if not _all_trial_field_true(trials, "analysis_ok"):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var results: Array[Dictionary] = []
	for trial in trials:
		results.append(trial["result"])
	_check(
		_all_result_field_true(results, "accepted"),
		"zero, under, exact, and over compensation satisfy all L2.3 gates"
	)
	_check(
		(
			float(results[0]["final_angle_rad"]) < float(results[1]["final_angle_rad"])
			and float(results[1]["final_angle_rad"]) < -0.05
			and absf(float(results[2]["final_angle_rad"])) <= 0.01
			and float(results[3]["final_angle_rad"]) > 0.05
		),
		"measured final angles order monotonically around the exact gravity hold"
	)
	_check(
		(
			float(results[0]["measured_initial_acceleration_rad_s2"]) < 0.0
			and float(results[1]["measured_initial_acceleration_rad_s2"]) < 0.0
			and absf(float(results[2]["measured_initial_acceleration_rad_s2"])) <= 0.05
			and float(results[3]["measured_initial_acceleration_rad_s2"]) > 0.0
		),
		"initial acceleration signs match the preregistered residual gravity torque"
	)
	_check(
		_all_torque_paths_unsaturated(results),
		"requested and applied gravity torques agree without hidden actuator saturation"
	)
	_check(
		_all_execution_paths_complete(results),
		"every loaded transition retains exact torque pairing and two receipts"
	)
	_check(
		_all_fixture_exclusions_live(trials),
		"live fixture exposes the frozen scaffold and excludes motor, limit, and contact"
	)
	_test_analyzer_refusals(builds[2]["contract"], trials[2]["samples"])
	_check(
		(
			String(results[2]["claim_boundary"])
			== (
				"Exact single-link fixed-scaffold horizontal gravity-hold fixture only; "
				+ "no free-root load bearing, articulated limb, standing, bracing, recovery, "
				+ "gait, or walking claim."
			)
		),
		"L2.3 result carries the exact fixed-scaffold non-claim boundary"
	)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_configuration_refusals() -> void:
	var free_parent := _configuration("free_parent", 1.0)
	free_parent["fixed_parent"] = false
	var hidden_motor := _configuration("hidden_motor", 1.0)
	hidden_motor["built_in_motor_enabled"] = true
	var invalid_ratio := _configuration("invalid_ratio", 2.0)
	var unknown := _configuration("unknown", 1.0)
	unknown["support_contact"] = true
	_check(
		(
			not bool(AnalyzerScript.build(free_parent).get("ok", true))
			and not bool(AnalyzerScript.build(hidden_motor).get("ok", true))
			and not bool(AnalyzerScript.build(invalid_ratio).get("ok", true))
			and not bool(AnalyzerScript.build(unknown).get("ok", true))
		),
		"gravity contract rejects free parent, hidden motor, invalid ratio, and support fields"
	)


func _test_analyzer_refusals(contract: Dictionary, source_samples: Array) -> void:
	var mutated := contract.duplicate(true)
	mutated["compensation_ratio"] = 0.9
	var mutated_result: Dictionary = AnalyzerScript.analyze(mutated, source_samples)
	var short := source_samples.duplicate(true)
	short.pop_back()
	var short_result: Dictionary = AnalyzerScript.analyze(contract, short)
	var nonfinite := source_samples.duplicate(true)
	(nonfinite[2] as Dictionary)["angle_after_rad"] = NAN
	var nonfinite_result: Dictionary = AnalyzerScript.analyze(contract, nonfinite)
	_check(
		(
			(
				String(mutated_result.get("failure_code", ""))
				== "GRAVITY_HOLD_CONTRACT_DIGEST_MISMATCH"
			)
			and String(short_result.get("failure_code", "")) == "GRAVITY_HOLD_SAMPLE_COUNT_MISMATCH"
			and String(nonfinite_result.get("failure_code", "")) == "GRAVITY_HOLD_SAMPLE_NONFINITE"
		),
		"mutated contract, missing transition, and nonfinite loaded evidence fail closed"
	)
	var missing_receipt := source_samples.duplicate(true)
	(missing_receipt[3] as Dictionary)["receipt_count"] = 1
	var receipt_result: Dictionary = AnalyzerScript.analyze(contract, missing_receipt)
	_check(
		(
			bool(receipt_result.get("ok", false))
			and not bool(receipt_result["result"]["accepted"])
			and (receipt_result["result"]["acceptance_failures"] as Array).has(
				"EXECUTION_RECEIPT_INCOMPLETE"
			)
		),
		"missing paired receipt makes a complete gravity trace non-acceptable"
	)


static func _configuration(trial_id: String, ratio: float) -> Dictionary:
	return {
		"schema_version": "gravity_hold_configuration_v1",
		"trial_id": trial_id,
		"physics_hz": PHYSICS_HZ,
		"sample_ticks": SAMPLE_TICKS,
		"compensation_ratio": ratio,
		"child_mass_kg": MASS_KG,
		"link_length_m": LENGTH_M,
		"link_width_m": WIDTH_M,
		"link_depth_m": DEPTH_M,
		"gravity_m_s2": GRAVITY_M_S2,
		"fixed_parent": true,
		"contact_enabled": false,
		"built_in_motor_enabled": false,
		"limit_enabled": false,
	}


static func _actuator_configuration() -> Dictionary:
	return {
		"schema_version": "actuator_spec_v1",
		"actuator_id": "l2_3_explicit_gravity_hold_motor",
		"enabled": true,
		"max_isometric_torque_nm": 20.0,
		"no_load_speed_rad_s": 100.0,
		"max_positive_power_w": 0.0,
		"max_absorption_power_w": 0.0,
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


static func _print_result(label: String, trial: Dictionary) -> void:
	if not bool(trial.get("analysis_ok", false)):
		print("  %s analysis_failure=%s" % [label, str(trial.get("analysis_failure", {}))])
		return
	var result: Dictionary = trial["result"]
	print(
		(
			(
				"  %s accepted=%s ratio=%.2f tau=%.5fNm alpha=%.5f/%.5frad/s2 "
				+ "final=%.5frad rate=%.5frad/s failures=%s"
			)
			% [
				label,
				str(bool(result["accepted"])),
				float(result["compensation_ratio"]),
				float(result["requested_compensation_nm"]),
				float(result["measured_initial_acceleration_rad_s2"]),
				float(result["expected_initial_acceleration_rad_s2"]),
				float(result["final_angle_rad"]),
				float(result["final_rate_rad_s"]),
				str(result["acceptance_failures"]),
			]
		)
	)


static func _all_builds_ok(builds: Array[Dictionary]) -> bool:
	for build in builds:
		if not bool(build.get("ok", false)):
			return false
	return true


static func _all_trial_field_true(trials: Array[Dictionary], field: String) -> bool:
	for trial in trials:
		if not bool(trial.get(field, false)):
			return false
	return true


static func _all_result_field_true(results: Array[Dictionary], field: String) -> bool:
	for result in results:
		if not bool(result.get(field, false)):
			return false
	return true


static func _all_torque_paths_unsaturated(results: Array[Dictionary]) -> bool:
	for result in results:
		if (
			float(result["max_request_error_nm"]) > 1.0e-6
			or bool(result["active_envelope_saturated"])
			or bool(result["structural_guard_saturated"])
		):
			return false
	return true


static func _all_execution_paths_complete(results: Array[Dictionary]) -> bool:
	for result in results:
		if (
			not bool(result["all_execution_receipts_complete"])
			or float(result["max_pairing_residual_nm"]) > 1.0e-9
		):
			return false
	return true


static func _all_fixture_exclusions_live(trials: Array[Dictionary]) -> bool:
	for trial in trials:
		if (
			not bool(trial["parent_frozen"])
			or not bool(trial["motor_disabled"])
			or not bool(trial["limit_disabled"])
			or not bool(trial["contact_disabled"])
		):
			return false
	return true


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
