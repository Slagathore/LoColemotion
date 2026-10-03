extends SceneTree

## Experimental L1.5 physical-time-preserving timestep sweep.
##
## The 30/60/120/240 Hz worlds hold seconds, geometry, mass, material, and
## solver-step settings fixed. Each rate runs both a dynamic box impact and the
## L1.4 eccentric static foot-pad pressure oracle.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")
const RigFactoryScript := preload("res://scripts/lab/rig_factory.gd")
const PressureObserverScript := preload(
	"res://scripts/lab/mechanics/contact_pressure_observer.gd")
const TimestepAnalyzerScript := preload(
	"res://scripts/lab/mechanics/timestep_convergence_analyzer.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const TIMESTEP_RATES_HZ := [30, 60, 120, 240]
const DROP_DURATION_S := 2.0
const FOOT_SETTLE_DURATION_S := 1.5
const FOOT_ANALYSIS_DURATION_S := 1.0
const FOOT_COM_OFFSET_X_M := 0.12
const ANALYZER_CONFIGURATION := {
	"required_rates_hz": TIMESTEP_RATES_HZ,
	"minimum_accepted_rate_count": 3,
	"maximum_touch_interval_steps": 1.1,
	"maximum_analytic_bracket_error_steps": 1.0,
	"maximum_impact_speed_error_gravity_steps": 1.1,
	"minimum_arrest_impulse_ratio": 0.9,
	"maximum_arrest_impulse_ratio": 1.15,
	"maximum_penetration_m": 0.005,
	"maximum_rest_height_error_m": 0.005,
	"maximum_final_vertical_speed_mps": 0.01,
	"maximum_foot_cop_error_m": 0.008,
	"maximum_foot_normal_load_error_n": 0.35,
	"maximum_foot_tilt_rad": deg_to_rad(0.5),
	"maximum_foot_slip_speed_mps": 0.005,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental L1.5 timestep convergence ===")
	var original_ticks := Engine.physics_ticks_per_second
	var profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v2")
	_check(bool(profile.get("executable", false)),
		"full_contacts_v2 is executable throughout the timestep sweep")
	var summaries: Array = []
	var all_complete := true
	for hz_value in TIMESTEP_RATES_HZ:
		var hz := int(hz_value)
		Engine.physics_ticks_per_second = hz
		var drop: Dictionary = await _run_drop(profile, hz)
		var foot: Dictionary = await _run_foot(profile, hz)
		var complete := bool(drop.get("complete", false)) \
			and bool(foot.get("complete", false))
		all_complete = complete and all_complete
		var summary := {
			"physics_ticks_per_second": hz,
			"step_s": 1.0 / float(hz),
			"drop": drop.get("summary", {}),
			"foot": foot.get("summary", {}),
		}
		summaries.append(summary)
		_print_summary(summary)
	_check(all_complete,
		"every rate completes both dynamic-impact and static-pressure windows")
	_evaluate_first_principles(summaries)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _run_drop(profile: Dictionary, hz: int) -> Dictionary:
	var clock = CaptureClockScript.new()
	var rig: Dictionary = RigFactoryScript.build(
		&"box_drop_contact_v1", clock, profile)
	if not bool(rig.get("ok", false)):
		return {"complete": false, "summary": {}}
	var world := rig["world"] as Node3D
	var body := rig["body"] as RigidBody3D
	root.add_child(world)
	var step_s := 1.0 / float(hz)
	var tick_count := ceili(DROP_DURATION_S * float(hz))
	var first_contact_step := -1
	var first_contact_time_s := INF
	var first_loaded_step := -1
	var first_loaded_time_s := INF
	var last_airborne_speed_mps := 0.0
	var last_airborne_time_s := 0.0
	var peak_contact_normal_impulse_ns := 0.0
	var first_contact_point_count := 0
	var capacity_complete := true
	var minimum_bottom_height_m := INF
	var final_vertical_speed_mps := INF
	var final_center_height_m := INF
	for step_id in tick_count:
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()
		var observation: Dictionary = body.latest_contact_v2_diagnostics.get(
			"observation", {})
		if not observation.is_empty():
			capacity_complete = (
				bool(observation.get("finite", false))
				and not bool(observation.get("saturated_ever", true))
				and capacity_complete)
		minimum_bottom_height_m = minf(
			minimum_bottom_height_m,
			body.global_position.y - 0.5 * float(rig["body_size_m"].y))
		var raw_contact_count := _matching_raw_contact_count(
			body.latest_contacts_v2, step_id, String(rig["floor_id"]))
		if first_contact_step < 0 and raw_contact_count == 0:
			last_airborne_speed_mps = absf(body.linear_velocity.y)
			last_airborne_time_s = float(step_id + 1) * step_s
		elif first_contact_step < 0:
			first_contact_step = step_id
			first_contact_time_s = float(step_id + 1) * step_s
			first_contact_point_count = raw_contact_count
		var pressure: Dictionary = PressureObserverScript.observe_raw_points(
			body.latest_contacts_v2,
			step_id,
			String(rig["floor_id"]),
			step_s,
			Vector3.UP)
		if bool(pressure.get("observation_valid", false)):
			var normal_impulse := float(
				pressure["total_predicted_normal_impulse_ns"])
			peak_contact_normal_impulse_ns = maxf(
				peak_contact_normal_impulse_ns, normal_impulse)
			if first_loaded_step < 0:
				first_loaded_step = step_id
				first_loaded_time_s = float(step_id + 1) * step_s
		final_vertical_speed_mps = absf(body.linear_velocity.y)
		final_center_height_m = body.global_position.y
	var analytic_impact_time_s := sqrt(
		2.0 * float(rig["initial_clearance_m"]) / 9.8)
	var analytic_impact_speed_mps := sqrt(
		2.0 * 9.8 * float(rig["initial_clearance_m"]))
	var analytic_bracket_error_s := 0.0
	if analytic_impact_time_s < last_airborne_time_s:
		analytic_bracket_error_s = last_airborne_time_s - analytic_impact_time_s
	elif analytic_impact_time_s > first_contact_time_s:
		analytic_bracket_error_s = analytic_impact_time_s - first_contact_time_s
	var summary := {
		"first_contact_step": first_contact_step,
		"first_contact_time_s": first_contact_time_s,
		"first_loaded_step": first_loaded_step,
		"first_loaded_time_s": first_loaded_time_s,
		"touch_to_load_delay_s": first_loaded_time_s - first_contact_time_s,
		"analytic_impact_time_s": analytic_impact_time_s,
		"impact_time_error_s": absf(
			first_contact_time_s - analytic_impact_time_s),
		"last_airborne_time_s": last_airborne_time_s,
		"touch_interval_s": first_contact_time_s - last_airborne_time_s,
		"analytic_impact_bracket_error_s": analytic_bracket_error_s,
		"last_airborne_speed_mps": last_airborne_speed_mps,
		"analytic_impact_speed_mps": analytic_impact_speed_mps,
		"impact_speed_error_mps": absf(
			last_airborne_speed_mps - analytic_impact_speed_mps),
		"peak_contact_normal_impulse_ns": peak_contact_normal_impulse_ns,
		"analytic_arrest_momentum_ns": (
			float(rig["body_mass_kg"]) * analytic_impact_speed_mps),
		"first_contact_point_count": first_contact_point_count,
		"minimum_bottom_height_m": minimum_bottom_height_m,
		"final_vertical_speed_mps": final_vertical_speed_mps,
		"final_center_height_m": final_center_height_m,
		"expected_rest_center_height_m": 0.5 * float(rig["body_size_m"].y),
		"capacity_complete": capacity_complete,
	}
	var complete := (
		capacity_complete
		and first_contact_step >= 0
		and first_loaded_step >= first_contact_step
		and first_contact_time_s < INF
		and last_airborne_speed_mps > 0.0
		and peak_contact_normal_impulse_ns > 0.0
		and first_contact_point_count > 0)
	world.queue_free()
	await process_frame
	return {"complete": complete, "summary": summary}


func _run_foot(profile: Dictionary, hz: int) -> Dictionary:
	var clock = CaptureClockScript.new()
	var rig: Dictionary = RigFactoryScript.build(
		&"foot_press_v1",
		clock,
		profile,
		{},
		{"custom_com_offset_x_m": FOOT_COM_OFFSET_X_M})
	if not bool(rig.get("ok", false)):
		return {"complete": false, "summary": {}}
	var world := rig["world"] as Node3D
	var body := rig["body"] as RigidBody3D
	root.add_child(world)
	var step_s := 1.0 / float(hz)
	var settle_ticks := ceili(FOOT_SETTLE_DURATION_S * float(hz))
	var analysis_ticks := ceili(FOOT_ANALYSIS_DURATION_S * float(hz))
	for step_id in settle_ticks:
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()
	var valid_samples := 0
	var capacity_complete := true
	var weighted_cop_sum := Vector3.ZERO
	var normal_impulse_sum := 0.0
	var normal_load_sum := 0.0
	var expected_load_sum := 0.0
	var cop_projection_error_sum := 0.0
	var max_tilt_rad := 0.0
	var max_slip_speed := 0.0
	for local_step in analysis_ticks:
		var step_id := settle_ticks + local_step
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()
		var observation: Dictionary = body.latest_contact_v2_diagnostics.get(
			"observation", {})
		capacity_complete = (
			bool(observation.get("finite", false))
			and not bool(observation.get("saturated_ever", true))
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
		var impulse := float(pressure["total_predicted_normal_impulse_ns"])
		var cop: Vector3 = pressure["center_of_pressure_world_m"]
		weighted_cop_sum += impulse * cop
		normal_impulse_sum += impulse
		normal_load_sum += float(pressure["predicted_normal_load_n"])
		var gravity := _vector3(
			body.latest_body_sample.get("total_gravity_world"))
		expected_load_sum += float(rig["pad_mass_kg"]) * gravity.length()
		var projected_com := body.global_transform * body.center_of_mass
		cop_projection_error_sum += Vector2(cop.x, cop.z).distance_to(
			Vector2(projected_com.x, projected_com.z))
		max_tilt_rad = maxf(max_tilt_rad, acos(clampf(
			body.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0)))
		max_slip_speed = maxf(
			max_slip_speed, _max_post_step_slip(body, step_id))
	var denominator := float(maxi(valid_samples, 1))
	var mean_cop := (
		weighted_cop_sum / normal_impulse_sum
		if normal_impulse_sum > 0.0 else Vector3(INF, INF, INF))
	var summary := {
		"valid_sample_count": valid_samples,
		"expected_sample_count": analysis_ticks,
		"capacity_complete": capacity_complete,
		"impulse_weighted_mean_cop_world_m": mean_cop,
		"mean_cop_projection_error_m": (
			cop_projection_error_sum / denominator),
		"mean_predicted_normal_load_n": normal_load_sum / denominator,
		"mean_expected_gravity_load_n": expected_load_sum / denominator,
		"mean_normal_load_error_n": absf(
			normal_load_sum / denominator - expected_load_sum / denominator),
		"max_tilt_rad": max_tilt_rad,
		"max_post_step_slip_speed_mps": max_slip_speed,
	}
	var complete := (
		capacity_complete
		and valid_samples == analysis_ticks
		and mean_cop.is_finite()
		and normal_impulse_sum > 0.0)
	world.queue_free()
	await process_frame
	return {"complete": complete, "summary": summary}


func _evaluate_first_principles(summaries: Array) -> void:
	var all_analytic_envelopes := true
	var all_contacts_arrest := true
	var all_foot_windows_valid := true
	for summary_value in summaries:
		var summary: Dictionary = summary_value
		var hz := int(summary["physics_ticks_per_second"])
		var drop: Dictionary = summary["drop"]
		var foot: Dictionary = summary["foot"]
		if hz >= 60:
			all_analytic_envelopes = (
			float(drop["analytic_impact_bracket_error_s"]) <= 1.0 / float(hz)
			and float(drop["touch_interval_s"]) <= 1.1 / float(hz)
			and float(drop["impact_speed_error_mps"]) <= 10.0 / float(hz)
			and all_analytic_envelopes)
			var impulse_ratio := float(drop["peak_contact_normal_impulse_ns"]) \
				/ float(drop["analytic_arrest_momentum_ns"])
			all_contacts_arrest = (
			impulse_ratio >= 0.9
			and impulse_ratio <= 1.15
			and float(drop["minimum_bottom_height_m"]) >= -0.005
			and float(drop["final_vertical_speed_mps"]) <= 0.01
			and absf(float(drop["final_center_height_m"])
				- float(drop["expected_rest_center_height_m"])) <= 0.005
			and all_contacts_arrest)
		all_foot_windows_valid = (
			float(foot["mean_cop_projection_error_m"]) <= 0.008
			and float(foot["mean_normal_load_error_n"]) <= 0.35
			and float(foot["max_tilt_rad"]) <= deg_to_rad(0.5)
			and float(foot["max_post_step_slip_speed_mps"]) <= 0.005
			and all_foot_windows_valid)
	_check(all_analytic_envelopes,
		"60/120/240 Hz impact brackets and speeds fit first-order envelopes")
	_check(all_contacts_arrest,
		"60/120/240 Hz report bounded arrest impulse, penetration, and rest pose")
	_check(all_foot_windows_valid,
		"static eccentric-pad CoP/load calibration remains valid at every rate")
	var coarse: Dictionary = summaries[0]
	var fine: Dictionary = summaries[summaries.size() - 1]
	_check(float(fine["drop"]["impact_time_error_s"])
			< float(coarse["drop"]["impact_time_error_s"])
		and float(fine["drop"]["impact_speed_error_mps"])
			< float(coarse["drop"]["impact_speed_error_mps"]),
		"240 Hz dynamic timing and speed errors are smaller than 30 Hz errors")
	var coarse_drop: Dictionary = coarse["drop"]
	_check(float(coarse_drop["analytic_impact_bracket_error_s"]) > 0.13
		and float(coarse_drop["minimum_bottom_height_m"]) < -0.09
		and absf(float(coarse_drop["final_center_height_m"])
			- float(coarse_drop["expected_rest_center_height_m"])) > 0.019,
		"30 Hz is rejected for missed impact bracket, deep tunneling, and biased rest")
	_evaluate_fail_closed_analyzer(summaries)


func _evaluate_fail_closed_analyzer(summaries: Array) -> void:
	var built: Dictionary = TimestepAnalyzerScript.build_config(
		ANALYZER_CONFIGURATION)
	_check(bool(built.get("ok", false)),
		"timestep gates form a valid digest-bound analysis contract")
	if not bool(built.get("ok", false)):
		return
	var extended: Dictionary = (built["config"] as Dictionary).duplicate(true)
	extended["automatic_universal_rate_claim"] = true
	var payload := extended.duplicate(true)
	payload.erase("config_digest_sha256")
	extended["config_digest_sha256"] = CanonicalJsonScript.sha256(payload)
	var extended_result: Dictionary = TimestepAnalyzerScript.analyze(
		extended, summaries)
	_check(not bool(extended_result["ok"])
		and extended_result["invalid_reasons"] == ["TIMESTEP_CONFIG_INVALID"],
		"coherently rehashed unknown timestep config fields fail closed")
	var corrupted: Array = summaries.duplicate(true)
	(corrupted[3]["foot"] as Dictionary)["mean_cop_projection_error_m"] = 0.02
	var corrupted_result: Dictionary = TimestepAnalyzerScript.analyze(
		built["config"], corrupted)
	_check(not bool(corrupted_result["ok"])
		and (corrupted_result["invalid_reasons"] as Array).has(
			"TIMESTEP_STATIC_PRESSURE_INVALID:3"),
		"a corrupted finest-rate pressure channel invalidates convergence")
	var analysis: Dictionary = TimestepAnalyzerScript.analyze(
		built["config"], summaries)
	_check(bool(analysis.get("ok", false))
		and bool(analysis.get("converged_envelope_detected", false))
		and int(analysis["minimum_accepted_rate_hz"]) == 60
		and int(analysis["accepted_rate_count"]) == 3
		and analysis["rejected_rates_hz"] == [30],
		"analyzer admits contiguous 60-240 Hz envelope and rejects 30 Hz")
	if not bool(analysis.get("ok", false)):
		printerr("  timestep_analysis=", analysis)
		return
	var rejected: Dictionary = analysis["classified_rates"][0]
	_check(String(rejected["classification"]) == "REJECTED"
		and (rejected["rejection_reasons"] as Array).has("PENETRATION_EXCEEDED")
		and (rejected["rejection_reasons"] as Array).has(
			"ANALYTIC_IMPACT_OUTSIDE_BRACKET")
		and (rejected["rejection_reasons"] as Array).has(
			"REST_HEIGHT_ERROR_EXCEEDED"),
		"30 Hz rejection retains named causal failure channels")
	_check((analysis["does_not_establish"] as Array).has(
			"universal_minimum_physics_rate")
		and (analysis["does_not_establish"] as Array).has("standing")
		and (analysis["does_not_establish"] as Array).has("walking"),
		"L1.5 result excludes universal-rate, standing, and walking claims")


func _print_summary(summary: Dictionary) -> void:
	var drop: Dictionary = summary["drop"]
	var foot: Dictionary = summary["foot"]
	var cop: Vector3 = foot["impulse_weighted_mean_cop_world_m"]
	print(("  %3dHz dt=%.6fs touch/load=%.6f/%.6fs analytic=%.6fs err=%.6fs "
			+ "v_air=%.5f/%.5fm/s Jn_peak=%.5f/%.5fNs bottom=%.5fm "
			+ "interval=%.3fsteps final_v/y=%.5f/%.5f "
			+ "foot_CoP=%+.5fm err=%.5fm Nerr=%.4fN") % [
		int(summary["physics_ticks_per_second"]),
		float(summary["step_s"]),
		float(drop["first_contact_time_s"]),
		float(drop["first_loaded_time_s"]),
		float(drop["analytic_impact_time_s"]),
		float(drop["impact_time_error_s"]),
		float(drop["last_airborne_speed_mps"]),
		float(drop["analytic_impact_speed_mps"]),
		float(drop["peak_contact_normal_impulse_ns"]),
		float(drop["analytic_arrest_momentum_ns"]),
		float(drop["minimum_bottom_height_m"]),
		float(drop["touch_interval_s"]) / float(summary["step_s"]),
		float(drop["final_vertical_speed_mps"]),
		float(drop["final_center_height_m"]),
		cop.x,
		float(foot["mean_cop_projection_error_m"]),
		float(foot["mean_normal_load_error_n"]),
	])


static func _matching_raw_contact_count(
		raw_contacts: Array,
		step_id: int,
		counterparty_id: String) -> int:
	var count := 0
	for raw_value in raw_contacts:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value
		if int(raw.get("physics_step_id", -1)) == step_id \
				and String(raw.get("counterparty_semantic_id", "")) \
				== counterparty_id \
				and bool(raw.get("finite", false)):
			count += 1
	return count


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
