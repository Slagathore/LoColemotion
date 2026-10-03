extends SceneTree

## BR6A/L4.0 rigid-strut vertical-rail oracle.

const AnalyzerScript := preload(
	"res://scripts/lab/mechanics/rail_strut_support_analyzer.gd"
)
const RigScript := preload("res://scripts/lab/rigs/rail_strut_rig.gd")

const PHYSICS_HZ := 60
const CONFIGURATION := {
	"schema_version": "rail_strut_support_configuration_v1",
	"physics_hz": PHYSICS_HZ,
	"freefall_ticks": 30,
	"settle_ticks": 120,
	"analysis_ticks": 120,
	"body_mass_kg": 3.0,
	"maximum_freefall_velocity_error_mps": 0.03,
	"maximum_freefall_external_load_n": 0.05,
	"maximum_supported_load_error_n": 0.25,
	"maximum_supported_vertical_speed_mps": 0.005,
	"maximum_lateral_drift_m": 0.001,
	"maximum_tilt_rad": deg_to_rad(0.25),
	"minimum_floor_contact_fraction": 0.99,
	"built_in_motors_enabled": false,
	"joint_springs_enabled": false,
	"passive_tissues_enabled": false,
	"controller_root_force_enabled": false,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR6A/L4.0 rigid-strut rail oracle ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	_test_configuration_refusals()
	var built := AnalyzerScript.build(CONFIGURATION)
	_check(bool(built.get("ok", false)), "strict rail-strut configuration seals")
	if not bool(built.get("ok", false)):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var rig = RigScript.new()
	var freefall: Dictionary = await rig.run(
		self, built["configuration"], "freefall_no_floor"
	)
	var supported: Dictionary = await rig.run(
		self, built["configuration"], "supported_floor"
	)
	_print_summary(freefall)
	_print_summary(supported)
	_check(
		bool(freefall.get("ok", false)) and bool(supported.get("ok", false)),
		"both real-Jolt rail worlds retain complete momentum samples"
	)
	var summaries := [freefall.get("summary", {}), supported.get("summary", {})]
	var analysis := AnalyzerScript.analyze(built["configuration"], summaries)
	_check(bool(analysis.get("ok", false)), "digest-bound L4.0 analyzer accepts the exact pair")
	if not bool(analysis.get("ok", false)):
		printerr("  analysis_failure=", analysis)
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	_check(bool(analysis["accepted"]), "freefall honesty and rigid support satisfy every L4.0 gate")
	_check(
		float(analysis["freefall_vertical_velocity_error_mps"]) <= 0.03,
		"no-floor carriage free-falls at gravity along the unlocked vertical axis"
	)
	_check(
		absf(float(analysis["freefall_mean_external_normal_load_n"])) <= 0.05,
		"no-floor momentum balance detects no vertical rail support"
	)
	_check(
		float(analysis["supported_maximum_load_error_n"]) <= 0.25,
		"ordinary floor contact balances the rigid assembly weight"
	)
	_check(
		float(analysis["supported_floor_contact_fraction"]) >= 0.99,
		"the pad remains in ordinary unilateral floor contact through measurement"
	)
	_check(
		bool(analysis["rail_scaffold_present"])
			and not bool(analysis["motor_or_passive_work_present"]),
		"the explicit rail is retained while motor, spring, passive, and root-force work stay zero"
	)
	_test_analyzer_refusals(built["configuration"], summaries)
	var exclusions: Array = analysis["does_not_establish"]
	_check(
		exclusions.has("articulated_load_bearing_limb")
			and exclusions.has("standing")
			and exclusions.has("walking")
			and exclusions.has("per_foot_load_allocation"),
		"L4.0 remains a scaffolded rigid-geometry oracle, not articulated support or locomotion"
	)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_configuration_refusals() -> void:
	var motor := CONFIGURATION.duplicate(true)
	motor["built_in_motors_enabled"] = true
	var root_force := CONFIGURATION.duplicate(true)
	root_force["controller_root_force_enabled"] = true
	var passive := CONFIGURATION.duplicate(true)
	passive["passive_tissues_enabled"] = true
	var unknown := CONFIGURATION.duplicate(true)
	unknown["automatic_standing_claim"] = true
	_check(
		not bool(AnalyzerScript.build(motor).get("ok", true))
			and not bool(AnalyzerScript.build(root_force).get("ok", true))
			and not bool(AnalyzerScript.build(passive).get("ok", true))
			and not bool(AnalyzerScript.build(unknown).get("ok", true)),
		"configuration rejects motors, root force, passive capacity, and invented standing fields"
	)


func _test_analyzer_refusals(configuration: Dictionary, summaries: Array) -> void:
	var mutated := configuration.duplicate(true)
	mutated["maximum_supported_load_error_n"] = 999.0
	var digest_failure := AnalyzerScript.analyze(mutated, summaries)
	var missing := summaries.duplicate(true)
	missing.pop_back()
	var missing_failure := AnalyzerScript.analyze(configuration, missing)
	var assisted := summaries.duplicate(true)
	(assisted[1] as Dictionary)["controller_root_force_count"] = 1
	var assisted_failure := AnalyzerScript.analyze(configuration, assisted)
	_check(
		String(digest_failure.get("failure_code", ""))
				== "RAIL_STRUT_CONFIG_DIGEST_MISMATCH"
			and String(missing_failure.get("failure_code", ""))
				== "RAIL_STRUT_SUMMARY_COUNT_MISMATCH"
			and (
				not bool(assisted_failure.get("accepted", true))
				and (assisted_failure.get("acceptance_failures", []) as Array).has(
					"RAIL_STRUT_SCAFFOLD_OR_ASSIST_INVALID:supported_floor"
				)
			),
		"digest mutation, missing control, and root-force forgery fail closed"
	)


static func _print_summary(trial: Dictionary) -> void:
	var summary: Dictionary = trial.get("summary", {})
	print(
		(
			"  mode=%s dv=%.6f/%.6fm/s external=%.6fN error=%.6fN "
			+ "contact=%.3f drift=%.8fm tilt=%.6fdeg rail=%s"
		)
		% [
			String(summary.get("mode", "")),
			float(summary.get("observed_delta_velocity_mps", NAN)),
			float(summary.get("expected_delta_velocity_mps", NAN)),
			float(summary.get("mean_reconstructed_external_normal_load_n", NAN)),
			float(summary.get("maximum_support_load_error_n", NAN)),
			float(summary.get("floor_contact_fraction", NAN)),
			float(summary.get("maximum_lateral_drift_m", NAN)),
			rad_to_deg(float(summary.get("maximum_tilt_rad", NAN))),
			str(bool(summary.get("rail_contract_exact", false))),
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
