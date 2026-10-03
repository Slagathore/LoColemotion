extends SceneTree

## Experimental BR4/L2.5 hard-limit approach and reaction classification.

const AnalyzerScript := preload("res://scripts/lab/mechanics/hard_limit_reaction_analyzer.gd")
const RigScript := preload("res://scripts/lab/rigs/free_hinge_limit_rig.gd")

const PHYSICS_HZ := 120
const SAMPLE_TICKS := 30
const PARENT_MASS_KG := 2.0
const PARENT_SIZE_M := Vector3(0.5, 0.4, 0.2)
const CHILD_MASS_KG := 1.0
const CHILD_SIZE_M := Vector3(0.3, 0.2, 0.2)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR4/L2.5 hard-limit reaction ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var positive_build: Dictionary = AnalyzerScript.build(
		_configuration("positive_limit", 4.0, true)
	)
	var negative_build: Dictionary = AnalyzerScript.build(
		_configuration("negative_limit", -4.0, true)
	)
	var control_build: Dictionary = AnalyzerScript.build(
		_configuration("limit_disabled_control", 4.0, false)
	)
	_check(
		(
			bool(positive_build.get("ok", false))
			and bool(negative_build.get("ok", false))
			and bool(control_build.get("ok", false))
		),
		"positive, negative, and limit-disabled contracts seal"
	)
	_test_configuration_refusals()
	if (
		not bool(positive_build.get("ok", false))
		or not bool(negative_build.get("ok", false))
		or not bool(control_build.get("ok", false))
	):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var rig = RigScript.new()
	var positive: Dictionary = await rig.run(self, positive_build["contract"])
	var negative: Dictionary = await rig.run(self, negative_build["contract"])
	var control: Dictionary = await rig.run(self, control_build["contract"])
	_print_result("positive", positive)
	_print_result("negative", negative)
	_print_result("control", control)
	_check(
		(
			bool(positive["fixture_complete"])
			and bool(negative["fixture_complete"])
			and bool(control["fixture_complete"])
		),
		"all hard-limit worlds retain complete joint observations"
	)
	_check(
		(
			bool(positive["analysis_ok"])
			and bool(negative["analysis_ok"])
			and bool(control["analysis_ok"])
		),
		"all hard-limit traces satisfy digest-bound analyzers"
	)
	if (
		not bool(positive["analysis_ok"])
		or not bool(negative["analysis_ok"])
		or not bool(control["analysis_ok"])
	):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var p: Dictionary = positive["result"]
	var n: Dictionary = negative["result"]
	var c: Dictionary = control["result"]
	_check(
		bool(p["accepted"]) and bool(n["accepted"]) and bool(c["accepted"]),
		"both mirrored hard limits and the disabled control pass L2.5"
	)
	_check(
		(
			float(p["max_directional_angle_rad"]) <= 0.28
			and float(n["max_directional_angle_rad"]) <= 0.28
			and float(c["max_directional_angle_rad"]) >= 0.45
		),
		"enabled boundaries arrest both directions while the disabled control crosses"
	)
	_check(
		(
			absf(float(p["max_constraint_reaction_impulse_n_m_s"])) >= 0.005
			and absf(float(n["max_constraint_reaction_impulse_n_m_s"])) >= 0.005
			and absf(float(c["max_constraint_reaction_impulse_n_m_s"])) <= 1.0e-4
		),
		"momentum balance detects mirrored boundary impulses and no control impulse"
	)
	_check(
		(
			String(p["reaction_classification"]) == "hard_limit_constraint_reaction"
			and String(n["reaction_classification"]) == "hard_limit_constraint_reaction"
			and String(c["reaction_classification"]) == "none"
			and float(p["active_torque_nm"]) == 0.0
			and float(p["passive_torque_nm"]) == 0.0
		),
		"limit impulses are classified only as constraint reactions, never motor or passive strength"
	)
	_check(
		(
			float(p["max_total_axis_angular_momentum_abs_n_m_s"]) <= 1.0e-4
			and float(n["max_total_axis_angular_momentum_abs_n_m_s"]) <= 1.0e-4
		),
		"free-floating pair retains total angular momentum through internal limit reactions"
	)
	_check(
		(
			bool(positive["motor_disabled"])
			and bool(negative["motor_disabled"])
			and bool(positive["limit_enabled"])
			and bool(negative["limit_enabled"])
			and not bool(control["limit_enabled"])
		),
		"live flags match the preregistered motor and limit states"
	)
	_test_analyzer_refusals(positive_build["contract"], positive["samples"])
	_check(
		(
			String(p["claim_boundary"])
			== (
				"Exact gravity-off, contact-free coaxial free-hinge hard-limit fixture only; "
				+ "the inferred boundary impulse is a constraint reaction, never motor torque "
				+ "or passive strength, and proves no load bearing, standing, bracing, recovery, "
				+ "gait, or walking."
			)
		),
		"L2.5 result carries the exact classification and non-claim boundary"
	)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_configuration_refusals() -> void:
	var hidden_motor := _configuration("hidden_motor", 4.0, true)
	hidden_motor["built_in_motor_enabled"] = true
	var hidden_passive := _configuration("hidden_passive", 4.0, true)
	hidden_passive["passive_torque_enabled"] = true
	var unknown := _configuration("unknown", 4.0, true)
	unknown["limit_is_muscle"] = true
	_check(
		(
			not bool(AnalyzerScript.build(hidden_motor).get("ok", true))
			and not bool(AnalyzerScript.build(hidden_passive).get("ok", true))
			and not bool(AnalyzerScript.build(unknown).get("ok", true))
		),
		"limit contract rejects hidden motor/passive torque and strength aliases"
	)


func _test_analyzer_refusals(contract: Dictionary, source_samples: Array) -> void:
	var mutated := contract.duplicate(true)
	mutated["upper_limit_rad"] = 0.3
	var mutated_result: Dictionary = AnalyzerScript.analyze(mutated, source_samples)
	var short := source_samples.duplicate(true)
	short.pop_back()
	var short_result: Dictionary = AnalyzerScript.analyze(contract, short)
	var hidden_torque := source_samples.duplicate(true)
	(hidden_torque[2] as Dictionary)["passive_torque_nm"] = 0.1
	var hidden_result: Dictionary = AnalyzerScript.analyze(contract, hidden_torque)
	_check(
		(
			String(mutated_result.get("failure_code", "")) == "HARD_LIMIT_CONTRACT_DIGEST_MISMATCH"
			and String(short_result.get("failure_code", "")) == "HARD_LIMIT_SAMPLE_COUNT_MISMATCH"
			and (
				String(hidden_result.get("failure_code", ""))
				== "HARD_LIMIT_HIDDEN_TORQUE_OR_COMMAND"
			)
		),
		"mutated limit, missing transition, and hidden passive torque fail closed"
	)


static func _configuration(trial_id: String, rate: float, enabled: bool) -> Dictionary:
	return {
		"schema_version": "hard_limit_reaction_configuration_v1",
		"trial_id": trial_id,
		"physics_hz": PHYSICS_HZ,
		"sample_ticks": SAMPLE_TICKS,
		"initial_relative_rate_rad_s": rate,
		"lower_limit_rad": -0.25,
		"upper_limit_rad": 0.25,
		"limit_enabled": enabled,
		"parent_mass_kg": PARENT_MASS_KG,
		"parent_size_m": PARENT_SIZE_M,
		"child_mass_kg": CHILD_MASS_KG,
		"child_size_m": CHILD_SIZE_M,
		"gravity_enabled": false,
		"contact_enabled": false,
		"built_in_motor_enabled": false,
		"active_torque_enabled": false,
		"passive_torque_enabled": false,
	}


static func _print_result(label: String, trial: Dictionary) -> void:
	if not bool(trial.get("analysis_ok", false)):
		print("  %s analysis_failure=%s" % [label, str(trial.get("analysis_failure", {}))])
		return
	var result: Dictionary = trial["result"]
	print(
		(
			(
				"  %s accepted=%s limit=%s max_angle=%.5frad final_rate=%.5frad/s "
				+ "reaction=%.7fNms tick=%d class=%s failures=%s"
			)
			% [
				label,
				str(bool(result["accepted"])),
				str(bool(result["limit_enabled"])),
				float(result["max_directional_angle_rad"]),
				float(result["final_rate_rad_s"]),
				float(result["max_constraint_reaction_impulse_n_m_s"]),
				int(result["constraint_reaction_tick"]),
				String(result["reaction_classification"]),
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
