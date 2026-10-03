extends SceneTree

## BR3B/L3.0 centered external normal load on one completely free pad.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload("res://scripts/lab/observer_profile.gd")
const RigFactoryScript := preload("res://scripts/lab/rig_factory.gd")
const PressureObserverScript := preload("res://scripts/lab/mechanics/contact_pressure_observer.gd")
const ReconstructorScript := preload(
	"res://scripts/lab/mechanics/external_contact_impulse_reconstructor.gd"
)
const AnalyzerScript := preload("res://scripts/lab/mechanics/loaded_pad_normal_analyzer.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const PHYSICS_TICKS_PER_SECOND := 60
const SETTLE_TICKS := 90
const ANALYSIS_TICKS := 60
const DOWNWARD_LOADS_N := [0.0, 20.0, 40.0, 80.0]
const ANALYZER_CONFIGURATION := {
	"required_downward_loads_n": DOWNWARD_LOADS_N,
	"minimum_samples_per_trial": ANALYSIS_TICKS,
	"maximum_reconstructed_load_error_n": 0.05,
	"maximum_predicted_load_error_n": 1.0,
	"maximum_tilt_rad": deg_to_rad(0.5),
	"maximum_slip_speed_mps": 0.005,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental L3.0 loaded-pad normal transmission ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_TICKS_PER_SECOND
	var profile: Dictionary = ObserverProfileScript.resolve(&"full_contacts_v2")
	_check(
		bool(profile.get("executable", false)),
		"full_contacts_v2 is executable for loaded-pad observations"
	)
	_test_fixture_refusal(profile)

	var summaries: Array = []
	var complete := true
	for load_value in DOWNWARD_LOADS_N:
		var result := await _run_trial(profile, float(load_value))
		complete = complete and bool(result.get("complete", false))
		summaries.append(result.get("summary", {}))
	_check(complete, "all four centered-load cells retain complete finite observations")
	_evaluate(summaries)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_fixture_refusal(profile: Dictionary) -> void:
	var pinned := RigFactoryScript.build(
		&"loaded_pad_v1",
		CaptureClockScript.new(),
		profile,
		{},
		{"friction": 1.0, "pin_to_floor": true}
	)
	_check(
		(
			not bool(pinned.get("ok", true))
			and _has_configuration_error(pinned, "UNSUPPORTED_PARAMETER")
		),
		"a hidden floor pin cannot enter the loaded-pad fixture"
	)
	var invalid_friction := RigFactoryScript.build(
		&"loaded_pad_v1", CaptureClockScript.new(), profile, {}, {"friction": 1.1}
	)
	_check(
		(
			not bool(invalid_friction.get("ok", true))
			and _has_configuration_error(invalid_friction, "FRICTION_INVALID")
		),
		"friction outside the authored Godot domain fails closed"
	)


func _run_trial(profile: Dictionary, downward_load_n: float) -> Dictionary:
	var clock = CaptureClockScript.new()
	var rig := RigFactoryScript.build(&"loaded_pad_v1", clock, profile, {}, {"friction": 1.0})
	if not bool(rig.get("ok", false)):
		return {"complete": false, "summary": {}}
	var contract: Dictionary = rig["load_application_contract"]
	var free_contract := (
		String(contract["method"]) == "RigidBody3D.apply_force"
		and not bool(contract["hidden_pin_constraint"])
		and not bool(contract["hidden_translation_constraint"])
		and not bool(contract["hidden_rotation_constraint"])
		and not bool(contract["hidden_damping"])
		and not bool(contract["built_in_motor"])
	)
	if downward_load_n == 0.0:
		_check(
			free_contract and bool(contract["applied_moment_is_only_force_cross_declared_offset"]),
			"load boundary declares a free pad with no hidden rail force or moment"
		)
	var world := rig["world"] as Node3D
	var body := rig["body"] as RigidBody3D
	root.add_child(world)
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	var applied_force := Vector3(0.0, -downward_load_n, 0.0)
	var force_application_count := 0
	for step_id in SETTLE_TICKS:
		clock.open_epoch(step_id, float(step_id + 1) * step_s, &"integrate_callback")
		body.apply_force(applied_force, Vector3.ZERO)
		force_application_count += 1
		await physics_frame
		clock.close_epoch()

	var valid_samples := 0
	var capacity_complete := true
	var expected_sum := 0.0
	var reconstructed_sum := 0.0
	var predicted_sum := 0.0
	var maximum_reconstruction_error := 0.0
	var maximum_pressure_error := 0.0
	var maximum_tilt := 0.0
	var maximum_slip := 0.0
	for local_step in ANALYSIS_TICKS:
		var step_id := SETTLE_TICKS + local_step
		var before := _momentum_sample(body, String(rig["body_id"]))
		clock.open_epoch(step_id, float(step_id + 1) * step_s, &"integrate_callback")
		body.apply_force(applied_force, Vector3.ZERO)
		force_application_count += 1
		await physics_frame
		clock.close_epoch()
		var after := _momentum_sample(body, String(rig["body_id"]))
		var gravity_acceleration := _gravity_acceleration_world()
		var known_impulse := (
			(float(rig["pad_mass_kg"]) * gravity_acceleration + applied_force) * step_s
		)
		var reconstruction := ReconstructorScript.reconstruct(
			[before], [after], step_s, known_impulse, Vector3.UP
		)
		var pressure := PressureObserverScript.observe_raw_points(
			body.latest_contacts_v2, step_id, String(rig["floor_id"]), step_s, Vector3.UP
		)
		var diagnostics: Dictionary = body.latest_contact_v2_diagnostics
		var capacity: Dictionary = diagnostics.get("observation", {})
		capacity_complete = (
			capacity_complete
			and bool(capacity.get("finite", false))
			and not bool(capacity.get("saturated_ever", true))
		)
		if (
			not bool(reconstruction.get("reconstruction_valid", false))
			or not bool(pressure.get("observation_valid", false))
		):
			continue
		valid_samples += 1
		var expected := float(rig["pad_mass_kg"]) * gravity_acceleration.length() + downward_load_n
		var reconstructed := float(reconstruction["reconstructed_step_average_normal_load_n"])
		var predicted := float(pressure["predicted_normal_load_n"])
		expected_sum += expected
		reconstructed_sum += reconstructed
		predicted_sum += predicted
		maximum_reconstruction_error = maxf(
			maximum_reconstruction_error, absf(reconstructed - expected)
		)
		maximum_pressure_error = maxf(maximum_pressure_error, absf(predicted - expected))
		maximum_tilt = maxf(maximum_tilt, _tilt_rad(body))
		maximum_slip = maxf(maximum_slip, _horizontal_speed(body))
	var denominator := float(maxi(valid_samples, 1))
	var summary := {
		"trial_id": "centered_down_%03dN" % int(downward_load_n),
		"external_downward_load_n": downward_load_n,
		"valid_sample_count": valid_samples,
		"capacity_complete": capacity_complete,
		"mean_expected_support_load_n": expected_sum / denominator,
		"mean_reconstructed_support_load_n": reconstructed_sum / denominator,
		"mean_predicted_contact_load_n": predicted_sum / denominator,
		"maximum_reconstructed_load_error_n": maximum_reconstruction_error,
		"maximum_predicted_load_error_n": maximum_pressure_error,
		"maximum_tilt_rad": maximum_tilt,
		"maximum_slip_speed_mps": maximum_slip,
		"free_pad_contract": free_contract,
		"centered_force_contract": applied_force.x == 0.0 and applied_force.z == 0.0,
		"force_application_count": force_application_count,
		"physics_tick_count": SETTLE_TICKS + ANALYSIS_TICKS,
	}
	print(
		(
			(
				"  down=%5.1fN expected=%8.4fN reconstructed=%8.4fN predicted=%8.4fN "
				+ "max_err=%.6f/%.6fN tilt=%.5fdeg slip=%.6fm/s"
			)
			% [
				downward_load_n,
				float(summary["mean_expected_support_load_n"]),
				float(summary["mean_reconstructed_support_load_n"]),
				float(summary["mean_predicted_contact_load_n"]),
				maximum_reconstruction_error,
				maximum_pressure_error,
				rad_to_deg(maximum_tilt),
				maximum_slip,
			]
		)
	)
	var complete := (
		capacity_complete
		and valid_samples == ANALYSIS_TICKS
		and force_application_count == SETTLE_TICKS + ANALYSIS_TICKS
	)
	world.queue_free()
	await process_frame
	return {"complete": complete, "summary": summary}


func _evaluate(summaries: Array) -> void:
	var reconstructed := true
	var pressure := true
	var stable := true
	var monotonic := true
	var previous := -INF
	for summary_value in summaries:
		var summary: Dictionary = summary_value
		reconstructed = (
			reconstructed and float(summary["maximum_reconstructed_load_error_n"]) <= 0.05
		)
		pressure = pressure and float(summary["maximum_predicted_load_error_n"]) <= 1.0
		stable = (
			stable
			and float(summary["maximum_tilt_rad"]) <= deg_to_rad(0.5)
			and float(summary["maximum_slip_speed_mps"]) <= 0.005
		)
		var current := float(summary["mean_reconstructed_support_load_n"])
		monotonic = monotonic and current > previous
		previous = current
	_check(reconstructed, "whole-system reconstruction matches gravity plus imposed load")
	_check(pressure, "single-manifold predicted pressure remains a bounded cross-check")
	_check(stable, "every centered-load cell remains planted, level, and slip-free")
	_check(monotonic, "reconstructed support increases strictly with imposed normal load")

	var built := AnalyzerScript.build_config(ANALYZER_CONFIGURATION)
	_check(bool(built.get("ok", false)), "L3.0 gates form a digest-bound exact-cell contract")
	if not bool(built.get("ok", false)):
		return
	var unknown: Dictionary = (built["config"] as Dictionary).duplicate(true)
	unknown["automatic_standing_claim"] = true
	var unknown_payload := unknown.duplicate(true)
	unknown_payload.erase("config_digest_sha256")
	unknown["config_digest_sha256"] = CanonicalJsonScript.sha256(unknown_payload)
	var unknown_result := AnalyzerScript.analyze(unknown, summaries)
	_check(
		(
			not bool(unknown_result["ok"])
			and unknown_result["invalid_reasons"] == ["LOADED_PAD_NORMAL_CONFIG_INVALID"]
		),
		"coherently rehashed unknown admission fields fail closed"
	)
	var corrupted: Array = summaries.duplicate(true)
	(corrupted[-1] as Dictionary)["maximum_reconstructed_load_error_n"] = 2.0
	var corrupted_result := AnalyzerScript.analyze(built["config"], corrupted)
	_check(
		(
			not bool(corrupted_result["ok"])
			and (corrupted_result["invalid_reasons"] as Array).has(
				"LOADED_PAD_NORMAL_RECONSTRUCTION_ERROR_EXCEEDED:3"
			)
		),
		"forged high-load reconstruction cannot enter the admitted grid"
	)
	var analysis := AnalyzerScript.analyze(built["config"], summaries)
	_check(
		(
			bool(analysis.get("ok", false))
			and bool(analysis.get("admitted", false))
			and int(analysis["trial_count"]) == DOWNWARD_LOADS_N.size()
		),
		"complete real-Jolt centered-load grid is admitted"
	)
	var exclusions: Array = analysis.get("does_not_establish", [])
	_check(
		(
			exclusions.has("articulated_load_bearing_limb")
			and exclusions.has("standing")
			and exclusions.has("walking")
		),
		"L3.0 result excludes articulated support and locomotion claims"
	)


static func _momentum_sample(body: RigidBody3D, body_id: String) -> Dictionary:
	return {
		"body_id": body_id,
		"mass_kg": body.mass,
		"linear_velocity_world_mps": body.linear_velocity,
	}


static func _gravity_acceleration_world() -> Vector3:
	var magnitude := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var direction_value: Variant = ProjectSettings.get_setting(
		"physics/3d/default_gravity_vector", Vector3.DOWN
	)
	var direction := direction_value as Vector3 if direction_value is Vector3 else Vector3.DOWN
	return magnitude * direction.normalized()


static func _tilt_rad(body: RigidBody3D) -> float:
	return acos(clampf(body.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0))


static func _horizontal_speed(body: RigidBody3D) -> float:
	return Vector2(body.linear_velocity.x, body.linear_velocity.z).length()


static func _has_configuration_error(result: Dictionary, code: String) -> bool:
	for error_value in result.get("configuration_errors", []):
		if String((error_value as Dictionary).get("code", "")) == code:
			return true
	return false


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
