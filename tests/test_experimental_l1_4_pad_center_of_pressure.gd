extends SceneTree

## Experimental L1.4 foot-sized pad pressure/CoP commissioning.
##
## A static free pad under gravity has two independent equilibrium oracles:
## total normal load equals mg, and CoP lies below the projected COM. Seven
## fresh worlds move only the custom internal load location across the foot.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")
const RigFactoryScript := preload("res://scripts/lab/rig_factory.gd")
const PressureObserverScript := preload(
	"res://scripts/lab/mechanics/contact_pressure_observer.gd")
const PadCopAnalyzerScript := preload(
	"res://scripts/lab/mechanics/pad_cop_analyzer.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const PHYSICS_TICKS_PER_SECOND := 60
const SETTLE_TICKS := 90
const ANALYSIS_TICKS := 60
const COM_OFFSETS_X_M := [-0.12, -0.09, -0.045, 0.0, 0.045, 0.09, 0.12]
const ANALYZER_CONFIGURATION := {
	"required_offsets_x_m": COM_OFFSETS_X_M,
	"minimum_samples_per_trial": ANALYSIS_TICKS,
	"authored_half_width_x_m": 0.15,
	"authored_half_width_z_m": 0.10,
	"maximum_mean_cop_error_m": 0.006,
	"maximum_normal_load_error_n": 0.25,
	"maximum_tilt_rad": deg_to_rad(0.5),
	"maximum_slip_speed_mps": 0.005,
	"maximum_displacement_m": 0.002,
	"minimum_contact_span_x_m": 0.29,
	"minimum_contact_span_z_m": 0.19,
	"center_cop_tolerance_m": 0.005,
	"mirror_symmetry_tolerance_m": 0.005,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental L1.4 foot-pad center of pressure ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_TICKS_PER_SECOND
	var profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v2")
	_check(bool(profile.get("executable", false)),
		"full_contacts_v2 is executable for foot-pad pressure observations")
	_test_pressure_observer_refusal()
	_test_fixture_refusal(profile)

	var summaries: Array = []
	var all_complete := true
	for offset_value in COM_OFFSETS_X_M:
		var result: Dictionary = await _run_trial(profile, float(offset_value))
		all_complete = bool(result.get("complete", false)) and all_complete
		summaries.append(result["summary"])
	_check(all_complete,
		"all seven foot-pad trials retain complete finite pressure windows")
	_evaluate_pressure_response(summaries)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_pressure_observer_refusal() -> void:
	print("- pressure observer fails closed on missing weights and wrong frames")
	var no_contacts: Dictionary = PressureObserverScript.observe_raw_points(
		[], 1, "floor", 1.0 / 60.0, Vector3.UP)
	_check(not bool(no_contacts["observation_valid"])
		and (no_contacts["invalid_reasons"] as Array).has(
			"PRESSURE_NO_MATCHING_CONTACTS")
		and no_contacts["center_of_pressure_world_m"] == null,
		"no matching raw contacts cannot fabricate a center of pressure")
	var wrong_normal: Dictionary = PressureObserverScript.observe_raw_points([
		_raw_contact(2, Vector3.ZERO, Vector3.RIGHT, Vector3.RIGHT),
	], 2, "floor", 1.0 / 60.0, Vector3.UP)
	_check(not bool(wrong_normal["observation_valid"])
		and (wrong_normal["invalid_reasons"] as Array).has(
			"PRESSURE_NORMAL_FRAME_MISMATCH:0"),
		"a wrong normal frame cannot produce pressure evidence")


func _test_fixture_refusal(profile: Dictionary) -> void:
	print("- foot-pad fixture refuses clamps and out-of-foot loads")
	var clamped: Dictionary = RigFactoryScript.build(
		&"foot_press_v1",
		CaptureClockScript.new(),
		profile,
		{},
		{"custom_com_offset_x_m": 0.09, "clamp_to_floor": true})
	_check(not bool(clamped.get("ok", true))
		and _has_configuration_error(clamped, "UNSUPPORTED_PARAMETER"),
		"a hidden floor clamp cannot enter the foot-pressure fixture")
	var outside: Dictionary = RigFactoryScript.build(
		&"foot_press_v1",
		CaptureClockScript.new(),
		profile,
		{},
		{"custom_com_offset_x_m": 0.13})
	_check(not bool(outside.get("ok", true))
		and _has_configuration_error(outside, "COM_OFFSET_INVALID"),
		"load locations outside the preregistered foot range fail closed")


func _run_trial(profile: Dictionary, offset_x_m: float) -> Dictionary:
	var clock = CaptureClockScript.new()
	var rig: Dictionary = RigFactoryScript.build(
		&"foot_press_v1",
		clock,
		profile,
		{},
		{"custom_com_offset_x_m": offset_x_m})
	if not bool(rig.get("ok", false)):
		return {"complete": false, "summary": {}}
	var constraint: Dictionary = rig["constraint_contract"]
	if offset_x_m == 0.0:
		_check(not bool(constraint["hidden_rotation_constraint"])
			and not bool(constraint["hidden_translation_constraint"])
			and not bool(constraint["hidden_damping"])
			and not bool(constraint["custom_integrator"])
			and String(constraint["external_drive"]) == "gravity_only",
			"foot pad remains free, undamped, and gravity-loaded only")
	var world := rig["world"] as Node3D
	var body := rig["body"] as RigidBody3D
	root.add_child(world)
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	for step_id in SETTLE_TICKS:
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()

	var valid_samples := 0
	var capacity_complete := true
	var weighted_cop_sum := Vector3.ZERO
	var total_normal_impulse := 0.0
	var normal_load_sum := 0.0
	var expected_load_sum := 0.0
	var cop_error_sum := 0.0
	var cop_x_error_max := 0.0
	var cop_z_error_max := 0.0
	var max_tilt_rad := 0.0
	var max_slip_speed := 0.0
	var min_contact_span_x := INF
	var min_contact_span_z := INF
	var initial_position := body.global_position
	for local_step in ANALYSIS_TICKS:
		var step_id := SETTLE_TICKS + local_step
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()
		var diagnostics: Dictionary = body.latest_contact_v2_diagnostics
		var capacity: Dictionary = diagnostics.get("observation", {})
		capacity_complete = (
			bool(capacity.get("finite", false))
			and not bool(capacity.get("saturated_ever", true))
			and capacity_complete)
		var pressure: Dictionary = PressureObserverScript.observe_raw_points(
			body.latest_contacts_v2,
			step_id,
			String(rig["floor_id"]),
			step_s,
			Vector3.UP)
		if not bool(pressure.get("observation_valid", false)):
			continue
		valid_samples += 1
		var cop: Vector3 = pressure["center_of_pressure_world_m"]
		var normal_impulse := float(
			pressure["total_predicted_normal_impulse_ns"])
		weighted_cop_sum += normal_impulse * cop
		total_normal_impulse += normal_impulse
		normal_load_sum += float(pressure["predicted_normal_load_n"])
		var gravity: Vector3 = _vector3(
			body.latest_body_sample.get("total_gravity_world"))
		expected_load_sum += float(rig["pad_mass_kg"]) * gravity.length()
		var projected_com := body.global_transform * body.center_of_mass
		var cop_error := Vector2(cop.x, cop.z).distance_to(
			Vector2(projected_com.x, projected_com.z))
		cop_error_sum += cop_error
		cop_x_error_max = maxf(
			cop_x_error_max, absf(cop.x - projected_com.x))
		cop_z_error_max = maxf(
			cop_z_error_max, absf(cop.z - projected_com.z))
		var point_min: Vector3 = pressure["contact_point_min_world_m"]
		var point_max: Vector3 = pressure["contact_point_max_world_m"]
		min_contact_span_x = minf(
			min_contact_span_x, point_max.x - point_min.x)
		min_contact_span_z = minf(
			min_contact_span_z, point_max.z - point_min.z)
		var tilt := acos(clampf(
			body.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0))
		max_tilt_rad = maxf(max_tilt_rad, tilt)
		max_slip_speed = maxf(
			max_slip_speed, _max_post_step_slip(body, step_id))
	var mean_cop := (
		weighted_cop_sum / total_normal_impulse
		if total_normal_impulse > 0.0 else Vector3(INF, INF, INF))
	var denominator := float(maxi(valid_samples, 1))
	var displacement := body.global_position.distance_to(initial_position)
	var summary := {
		"trial_id": "load_%+.3fm" % offset_x_m,
		"custom_com_offset_x_m": offset_x_m,
		"support_half_width_x_m": float(rig["support_half_width_x_m"]),
		"support_half_width_z_m": float(rig["support_half_width_z_m"]),
		"valid_sample_count": valid_samples,
		"capacity_complete": capacity_complete,
		"impulse_weighted_mean_cop_world_m": mean_cop,
		"mean_predicted_normal_load_n": normal_load_sum / denominator,
		"mean_expected_gravity_load_n": expected_load_sum / denominator,
		"mean_cop_projection_error_m": cop_error_sum / denominator,
		"max_cop_x_error_m": cop_x_error_max,
		"max_cop_z_error_m": cop_z_error_max,
		"minimum_contact_span_x_m": min_contact_span_x,
		"minimum_contact_span_z_m": min_contact_span_z,
		"max_tilt_rad": max_tilt_rad,
		"max_post_step_slip_speed_mps": max_slip_speed,
		"body_displacement_m": displacement,
	}
	print(("  load=%+.3fm CoP=(%+.5f,%+.5f)m err(mean/max-x)=%.5f/%.5fm "
			+ "N=%.3f/%.3fN tilt=%.4fdeg slip=%.5fm/s span=%.3fx%.3fm") % [
		offset_x_m,
		mean_cop.x,
		mean_cop.z,
		float(summary["mean_cop_projection_error_m"]),
		cop_x_error_max,
		float(summary["mean_predicted_normal_load_n"]),
		float(summary["mean_expected_gravity_load_n"]),
		rad_to_deg(max_tilt_rad),
		max_slip_speed,
		min_contact_span_x,
		min_contact_span_z,
	])
	var complete := (
		capacity_complete
		and valid_samples == ANALYSIS_TICKS
		and mean_cop.is_finite()
		and total_normal_impulse > 0.0
		and min_contact_span_x > 0.0
		and min_contact_span_z > 0.0)
	world.queue_free()
	await process_frame
	return {"complete": complete, "summary": summary}


func _evaluate_pressure_response(summaries: Array) -> void:
	var all_stable := true
	var all_loads_balanced := true
	var all_cop_errors_bounded := true
	var previous_cop_x := -INF
	var monotonic_cop := true
	for summary_value in summaries:
		var summary: Dictionary = summary_value
		all_stable = (
			float(summary["max_tilt_rad"]) <= deg_to_rad(0.5)
			and float(summary["max_post_step_slip_speed_mps"]) <= 0.005
			and float(summary["body_displacement_m"]) <= 0.002
			and all_stable)
		all_loads_balanced = (
			absf(float(summary["mean_predicted_normal_load_n"])
				- float(summary["mean_expected_gravity_load_n"])) <= 0.25
			and all_loads_balanced)
		all_cop_errors_bounded = (
			float(summary["mean_cop_projection_error_m"]) <= 0.006
			and all_cop_errors_bounded)
		var cop: Vector3 = summary["impulse_weighted_mean_cop_world_m"]
		if cop.x <= previous_cop_x:
			monotonic_cop = false
		previous_cop_x = cop.x
	_check(all_stable,
		"CoP is measured while every free pad remains planted and untilted")
	_check(all_loads_balanced,
		"predicted total normal load balances measured gravity within 0.25 N")
	_check(all_cop_errors_bounded,
		"impulse-weighted CoP stays within 0.006 m of projected COM")
	_check(monotonic_cop,
		"measured CoP moves strictly monotonically with internal load location")
	var negative: Dictionary = summaries[0]
	var center: Dictionary = summaries[3]
	var positive: Dictionary = summaries[6]
	var negative_cop: Vector3 = negative["impulse_weighted_mean_cop_world_m"]
	var center_cop: Vector3 = center["impulse_weighted_mean_cop_world_m"]
	var positive_cop: Vector3 = positive["impulse_weighted_mean_cop_world_m"]
	_check(absf(center_cop.x) <= 0.005 and absf(center_cop.z) <= 0.005,
		"centered load produces centered pressure on both pad axes")
	_check(absf(negative_cop.x + positive_cop.x) <= 0.005
		and absf(negative_cop.z - positive_cop.z) <= 0.005,
		"equal-magnitude edgeward loads produce mirrored CoP")
	_check(negative_cop.x < 0.0 and positive_cop.x > 0.0,
		"CoP direction follows the independently authored load direction")
	_check(float(positive["minimum_contact_span_x_m"]) >= 0.29
		and float(positive["minimum_contact_span_z_m"]) >= 0.19,
		"raw contact manifold spans the authored 0.30 by 0.20 m foot")
	_evaluate_fail_closed_analyzer(summaries)


func _evaluate_fail_closed_analyzer(summaries: Array) -> void:
	var built: Dictionary = PadCopAnalyzerScript.build_config(
		ANALYZER_CONFIGURATION)
	_check(bool(built.get("ok", false)),
		"pad CoP gates form a valid digest-bound analysis contract")
	if not bool(built.get("ok", false)):
		return
	var extended: Dictionary = (built["config"] as Dictionary).duplicate(true)
	extended["automatic_standing_claim"] = true
	var payload := extended.duplicate(true)
	payload.erase("config_digest_sha256")
	extended["config_digest_sha256"] = CanonicalJsonScript.sha256(payload)
	var extended_result: Dictionary = PadCopAnalyzerScript.analyze(
		extended, summaries)
	_check(not bool(extended_result["ok"])
		and extended_result["invalid_reasons"] == ["PAD_COP_CONFIG_INVALID"],
		"coherently rehashed unknown CoP config fields fail closed")
	var corrupted_trials: Array = summaries.duplicate(true)
	(corrupted_trials[6] as Dictionary)["mean_cop_projection_error_m"] = 0.02
	var corrupted_result: Dictionary = PadCopAnalyzerScript.analyze(
		built["config"], corrupted_trials)
	_check(not bool(corrupted_result["ok"])
		and (corrupted_result["invalid_reasons"] as Array).has(
			"PAD_COP_PROJECTION_ERROR_EXCEEDED:6"),
		"a corrupted edge-load CoP cannot enter the admitted calibration")
	var analysis: Dictionary = PadCopAnalyzerScript.analyze(
		built["config"], summaries)
	_check(bool(analysis.get("ok", false))
		and bool(analysis.get("admitted", false))
		and float(analysis["maximum_mean_cop_projection_error_m"]) <= 0.006
		and float(analysis["maximum_mean_normal_load_error_n"]) <= 0.25,
		"complete real-Jolt pad grid is admitted inside preregistered error bounds")
	_check((analysis.get("does_not_establish", []) as Array).has("standing")
		and (analysis.get("does_not_establish", []) as Array).has("walking"),
		"L1.4 result explicitly excludes standing and walking")


func _max_post_step_slip(body: RigidBody3D, step_id: int) -> float:
	var center_of_mass_world := body.global_transform * body.center_of_mass
	var maximum := 0.0
	for raw_value in body.latest_contacts_v2:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value
		if int(raw.get("physics_step_id", -1)) != step_id \
				or not bool(raw.get("finite", false)):
			continue
		var point: Vector3 = raw["point_world"]
		var normal: Vector3 = raw["normal_world"]
		var point_velocity := body.linear_velocity \
			+ body.angular_velocity.cross(point - center_of_mass_world)
		var tangential := point_velocity \
			- point_velocity.dot(normal) * normal
		maximum = maxf(maximum, tangential.length())
	return maximum


static func _raw_contact(
		step_id: int,
		point: Vector3,
		normal: Vector3,
		impulse: Vector3) -> Dictionary:
	return {
		"physics_step_id": step_id,
		"counterparty_semantic_id": "floor",
		"finite": true,
		"impulse_quality": "jolt_predicted_estimate",
		"point_world": point,
		"normal_world": normal,
		"impulse_world_ns": impulse,
	}


static func _has_configuration_error(result: Dictionary, code: String) -> bool:
	for error_value in result.get("configuration_errors", []):
		var error: Dictionary = error_value
		if String(error.get("code", "")) == code:
			return true
	return false


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() == 3:
		var raw: Array = value
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(INF, INF, INF)


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
