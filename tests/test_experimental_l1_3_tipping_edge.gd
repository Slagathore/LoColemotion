extends SceneTree

## Experimental L1.3 live Godot/Jolt support-edge tipping commissioning.
##
## Each horizontal COM offset is a fresh free-body world. The test compares the
## authored rectangular-footprint margin with the live transition from stable
## support to same-direction edge pivot. Raw per-point predicted normal impulse
## weights produce CoP; post-step rigid kinematics decide slip and rotation.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")
const RigFactoryScript := preload("res://scripts/lab/rig_factory.gd")
const SupportGeometryScript := preload(
	"res://scripts/lab/mechanics/support_geometry.gd")
const TippingAnalyzerScript := preload(
	"res://scripts/lab/mechanics/tipping_threshold_analyzer.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const PHYSICS_TICKS_PER_SECOND := 60
const TRIAL_TICKS := 180
const FRICTION := 1.0
const PRIMARY_COM_OFFSETS_X_M := [0.0, 0.15, 0.24, 0.28, 0.32, 0.36]
const MIRROR_OFFSET_X_M := -0.36
const PIVOT_TILT_RAD := deg_to_rad(2.0)
const PREPIVOT_COP_WINDOW_MAX_TILT_RAD := deg_to_rad(5.0)
const ANALYZER_CONFIGURATION := {
	"minimum_contact_samples_per_trial": 12,
	"authored_support_half_width_m": 0.3,
	"support_margin_tolerance_m": 1.0e-5,
	"maximum_stable_tilt_rad": deg_to_rad(0.5),
	"maximum_stable_angular_speed_rad_s": 0.02,
	"maximum_stable_displacement_m": 0.002,
	"minimum_tipping_tilt_rad": deg_to_rad(20.0),
	"minimum_tipping_directional_up_x": 0.25,
	"minimum_edge_cop_fraction": 0.8,
	"maximum_pretip_slip_speed_mps": 0.05,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental L1.3 live support-edge tipping ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_TICKS_PER_SECOND
	var profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v2")
	_check(bool(profile.get("executable", false)),
		"full_contacts_v2 is executable for per-point tipping observations")
	_test_configuration_refusal(profile)

	var summaries: Array = []
	var all_complete := true
	for offset_value in PRIMARY_COM_OFFSETS_X_M:
		var result: Dictionary = await _run_trial(profile, float(offset_value))
		all_complete = bool(result.get("complete", false)) and all_complete
		summaries.append(result["summary"])
	_check(all_complete,
		"all primary COM-offset trials retain finite unsaturated observations")
	_evaluate_threshold(summaries)

	var mirror_result: Dictionary = await _run_trial(
		profile, MIRROR_OFFSET_X_M)
	var mirror: Dictionary = mirror_result["summary"]
	var positive: Dictionary = summaries[summaries.size() - 1]
	_check(bool(mirror_result.get("complete", false))
		and bool(mirror.get("pivot_observed", false))
		and float(mirror.get("max_directional_up_x", 0.0)) >= 0.25
		and float(mirror.get("max_directional_angular_speed_rad_s", 0.0)) > 0.0,
		"negative COM offset pivots toward the negative edge with mirrored signs")
	_check(absf(float(mirror["max_tilt_rad"])
			- float(positive["max_tilt_rad"])) <= deg_to_rad(3.0)
		and absf(float(mirror["max_cop_toward_edge_fraction"])
			- float(positive["max_cop_toward_edge_fraction"])) <= 0.1,
		"equal-magnitude positive and negative offsets have symmetric tip/CoP response")
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_configuration_refusal(profile: Dictionary) -> void:
	print("- tipping fixture refuses hidden support and invalid COM offsets")
	var hidden_umbrella: Dictionary = RigFactoryScript.build(
		&"tipping_prism_v1",
		CaptureClockScript.new(),
		profile,
		{},
		{"custom_com_offset_x_m": 0.32, "balance_umbrella": true})
	_check(not bool(hidden_umbrella.get("ok", true))
		and _has_configuration_error(hidden_umbrella, "UNSUPPORTED_PARAMETER"),
		"a hidden balance umbrella cannot enter the tipping fixture")
	var excessive_offset: Dictionary = RigFactoryScript.build(
		&"tipping_prism_v1",
		CaptureClockScript.new(),
		profile,
		{},
		{"custom_com_offset_x_m": 0.46})
	_check(not bool(excessive_offset.get("ok", true))
		and _has_configuration_error(excessive_offset, "COM_OFFSET_INVALID"),
		"COM offsets outside the preregistered range fail closed")


func _run_trial(profile: Dictionary, offset_x_m: float) -> Dictionary:
	var clock = CaptureClockScript.new()
	var rig: Dictionary = RigFactoryScript.build(
		&"tipping_prism_v1",
		clock,
		profile,
		{},
		{"friction": FRICTION, "custom_com_offset_x_m": offset_x_m})
	if not bool(rig.get("ok", false)):
		return {"complete": false, "summary": _invalid_summary(offset_x_m)}
	var constraint: Dictionary = rig["constraint_contract"]
	if offset_x_m == 0.0:
		_check(not bool(constraint["hidden_rotation_constraint"])
			and not bool(constraint["hidden_translation_constraint"])
			and not bool(constraint["hidden_damping"])
			and not bool(constraint["custom_integrator"])
			and String(constraint["external_drive"]) == "gravity_only"
			and not bool(constraint["center_of_mass_changed_during_trial"]),
			"trials declare a free undamped prism, fixed COM, and gravity-only drive")
	var geometry: Dictionary = SupportGeometryScript.analyze(
		rig["support_footprint_world_m"],
		rig["plane_origin_world_m"],
		rig["plane_normal_world"],
		rig["initial_center_of_mass_world_m"])
	var geometry_error := (
		absf(float(geometry.get("signed_margin_m", INF))
			- float(rig["analytic_support_margin_m"]))
		if bool(geometry.get("finite", false)) else INF)
	var geometry_class_matches := (
		bool(geometry.get("query_inside_support", false))
		== bool(rig["analytic_inside_support"]))

	var world := rig["world"] as Node3D
	var body := rig["body"] as RigidBody3D
	root.add_child(world)
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	var sample_count := 0
	var contact_sample_count := 0
	var cop_sample_count := 0
	var body_sample_count := 0
	var capacity_observation_count := 0
	var capacity_complete := true
	var max_tilt_rad := 0.0
	var final_tilt_rad := 0.0
	var max_angular_speed_rad_s := 0.0
	var max_directional_up_x := 0.0
	var max_directional_angular_speed := 0.0
	var max_cop_toward_edge_fraction := 0.0
	var max_pretip_slip_speed := 0.0
	var pivot_observed := false
	var first_pivot_tick: Variant = null
	var initial_origin_x := body.global_position.x
	var tip_direction := signf(offset_x_m)
	var measurement_direction := tip_direction if tip_direction != 0.0 else 1.0
	var com_oracle_error_max := 0.0
	for step_id in TRIAL_TICKS:
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()
		sample_count += 1
		var body_sample: Dictionary = body.latest_body_sample
		if int(body_sample.get("physics_step_id", -1)) == step_id:
			body_sample_count += 1
			com_oracle_error_max = maxf(
				com_oracle_error_max,
				float(body_sample.get("com_frame_oracle_error_m", INF)))
		var diagnostics: Dictionary = body.latest_contact_v2_diagnostics
		var capacity: Dictionary = diagnostics.get("observation", {})
		if not capacity.is_empty():
			capacity_observation_count += 1
			capacity_complete = (
				bool(capacity.get("finite", false))
				and not bool(capacity.get("saturated_ever", true))
				and capacity_complete)
		var up_world := body.global_basis.y.normalized()
		var tilt_rad := acos(clampf(up_world.dot(Vector3.UP), -1.0, 1.0))
		final_tilt_rad = tilt_rad
		max_tilt_rad = maxf(max_tilt_rad, tilt_rad)
		max_angular_speed_rad_s = maxf(
			max_angular_speed_rad_s, body.angular_velocity.length())
		max_directional_up_x = maxf(
			max_directional_up_x, up_world.x * measurement_direction)
		max_directional_angular_speed = maxf(
			max_directional_angular_speed,
			-body.angular_velocity.z * measurement_direction)

		var contact_frame := _raw_contact_frame(rig, body, step_id)
		if bool(contact_frame["has_contacts"]):
			contact_sample_count += 1
		if bool(contact_frame["cop_valid"]):
			cop_sample_count += 1
			# A later side/ground collision lies outside the original footprint
			# and is not evidence of the initiating bottom-edge pivot.
			if tilt_rad <= PREPIVOT_COP_WINDOW_MAX_TILT_RAD:
				var cop: Vector3 = contact_frame["center_of_pressure_world_m"]
				max_cop_toward_edge_fraction = maxf(
					max_cop_toward_edge_fraction,
					cop.x * measurement_direction
						/ float(rig["support_half_width_m"]))
		if tilt_rad < PIVOT_TILT_RAD:
			max_pretip_slip_speed = maxf(
				max_pretip_slip_speed,
				float(contact_frame["max_post_step_slip_speed_mps"]))
		if tip_direction != 0.0 \
				and tilt_rad >= PIVOT_TILT_RAD \
				and max_directional_up_x > 0.0 \
				and max_cop_toward_edge_fraction >= 0.8:
			pivot_observed = true
			if first_pivot_tick == null:
				first_pivot_tick = step_id

	var lateral_displacement := absf(body.global_position.x - initial_origin_x)
	var complete := (
		capacity_complete
		and geometry_class_matches
		and geometry_error <= 1.0e-5
		and com_oracle_error_max <= 1.0e-5
		and sample_count == TRIAL_TICKS
		and body_sample_count >= TRIAL_TICKS - 1
		and capacity_observation_count >= TRIAL_TICKS - 1
		and contact_sample_count >= 12
		and cop_sample_count >= 12)
	var summary := {
		"trial_id": "com_%+.3fm" % offset_x_m,
		"custom_com_offset_x_m": offset_x_m,
		"support_half_width_m": float(rig["support_half_width_m"]),
		"initial_support_margin_m": float(rig["analytic_support_margin_m"]),
		"analytic_inside_support": bool(rig["analytic_inside_support"]),
		"sample_count": sample_count,
		"body_sample_count": body_sample_count,
		"capacity_observation_count": capacity_observation_count,
		"contact_sample_count": contact_sample_count,
		"cop_sample_count": cop_sample_count,
		"capacity_complete": capacity_complete,
		"max_tilt_rad": max_tilt_rad,
		"final_tilt_rad": final_tilt_rad,
		"max_angular_speed_rad_s": max_angular_speed_rad_s,
		"max_directional_up_x": max_directional_up_x,
		"max_directional_angular_speed_rad_s": max_directional_angular_speed,
		"max_cop_toward_edge_fraction": max_cop_toward_edge_fraction,
		"max_pretip_slip_speed_mps": max_pretip_slip_speed,
		"pivot_observed": pivot_observed,
		"first_pivot_tick": first_pivot_tick,
		"lateral_displacement_m": lateral_displacement,
		"geometry_oracle_error_m": geometry_error,
		"com_frame_oracle_error_m": com_oracle_error_max,
	}
	print(("  COM=%+.3fm margin=%+.3fm contacts/CoP=%d/%d "
			+ "tilt=%.2fdeg dir_up=%.3f edge_CoP=%.3f "
			+ "pretip_slip=%.5fm/s pivot=%s@%s") % [
		offset_x_m,
		float(summary["initial_support_margin_m"]),
		contact_sample_count,
		cop_sample_count,
		rad_to_deg(max_tilt_rad),
		max_directional_up_x,
		max_cop_toward_edge_fraction,
		max_pretip_slip_speed,
		str(pivot_observed),
		str(first_pivot_tick),
	])
	world.queue_free()
	await process_frame
	return {"complete": complete, "summary": summary}


func _raw_contact_frame(
		rig: Dictionary,
		body: RigidBody3D,
		step_id: int) -> Dictionary:
	var cop_samples: Array = []
	var max_slip_speed := 0.0
	var center_of_mass_world := body.global_transform * body.center_of_mass
	for raw_value in body.latest_contacts_v2:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value
		if int(raw.get("physics_step_id", -1)) != step_id \
				or String(raw.get("counterparty_semantic_id", "")) \
				!= String(rig["floor_id"]) \
				or not bool(raw.get("finite", false)):
			continue
		var point: Vector3 = raw["point_world"]
		var normal: Vector3 = raw["normal_world"]
		var impulse: Vector3 = raw["impulse_world_ns"]
		var normal_weight := maxf(impulse.dot(normal), 0.0)
		cop_samples.append({
			"point_world": point,
			"normal_weight": normal_weight,
		})
		var point_velocity := body.linear_velocity \
			+ body.angular_velocity.cross(point - center_of_mass_world)
		var tangential_velocity := point_velocity \
			- point_velocity.dot(normal) * normal
		max_slip_speed = maxf(max_slip_speed, tangential_velocity.length())
	var cop: Dictionary = SupportGeometryScript.center_of_pressure(cop_samples)
	return {
		"has_contacts": not cop_samples.is_empty(),
		"cop_valid": bool(cop.get("finite", false)),
		"center_of_pressure_world_m": cop.get(
			"center_of_pressure_world", Vector3.ZERO),
		"max_post_step_slip_speed_mps": max_slip_speed,
	}


func _evaluate_threshold(summaries: Array) -> void:
	var built: Dictionary = TippingAnalyzerScript.build_config(
		ANALYZER_CONFIGURATION)
	_check(bool(built.get("ok", false)),
		"tipping thresholds form a valid independent-trial contract")
	if not bool(built.get("ok", false)):
		return
	var extended_config: Dictionary = (built["config"] as Dictionary).duplicate(true)
	extended_config["automatic_standing_claim"] = true
	var extended_payload := extended_config.duplicate(true)
	extended_payload.erase("config_digest_sha256")
	extended_config["config_digest_sha256"] = CanonicalJsonScript.sha256(
		extended_payload)
	var extended_result: Dictionary = TippingAnalyzerScript.analyze(
		extended_config, summaries)
	_check(not bool(extended_result["ok"])
		and extended_result["invalid_reasons"] == ["TIPPING_CONFIG_INVALID"],
		"coherently rehashed unknown tipping config fields fail closed")
	var false_geometry_trials: Array = summaries.duplicate(true)
	(false_geometry_trials[3] as Dictionary)["initial_support_margin_m"] = 0.2
	var false_geometry_result: Dictionary = TippingAnalyzerScript.analyze(
		built["config"], false_geometry_trials)
	_check(not bool(false_geometry_result["ok"])
		and (false_geometry_result["invalid_reasons"] as Array).has(
			"TIPPING_TRIAL_MARGIN_ORACLE_MISMATCH:3"),
		"a corrupted support margin cannot produce a tipping threshold")

	var analysis: Dictionary = TippingAnalyzerScript.analyze(
		built["config"], summaries)
	_check(bool(analysis.get("ok", false))
		and bool(analysis.get("threshold_detected", false)),
		"real Jolt trials bracket one monotonic stable-to-edge-pivot transition")
	if not bool(analysis.get("ok", false)):
		printerr("  tipping_analysis=", analysis)
		return
	print("  tipping_threshold=[%.3f, %.3f]m analytic_edge=%.3fm" % [
		float(analysis["threshold_offset_lower_m"]),
		float(analysis["threshold_offset_upper_m"]),
		float(analysis["analytic_support_edge_offset_m"]),
	])
	_check(String(analysis["last_stable_trial_id"]) == "com_+0.280m"
		and String(analysis["first_tipping_trial_id"]) == "com_+0.320m",
		"0.28 m remains supported while 0.32 m pivots beyond the 0.30 m edge")
	_check(bool(analysis["analytic_edge_inside_empirical_bracket"])
		and float(analysis["threshold_bracket_width_m"]) <= 0.04 + 1.0e-6,
		"analytic footprint edge lies inside a 0.04 m empirical bracket")
	var first_tipping := _trial_by_id(
		analysis["classified_trials"], "com_+0.320m")
	_check(bool(first_tipping.get("pivot_observed", false))
		and float(first_tipping["max_cop_toward_edge_fraction"]) >= 0.8
		and float(first_tipping["max_pretip_slip_speed_mps"]) <= 0.05,
		"first unstable trial loads the predicted edge before appreciable slip")
	_check((analysis["does_not_establish"] as Array).has("standing")
		and (analysis["does_not_establish"] as Array).has("walking"),
		"L1.3 result explicitly excludes standing and walking")


static func _trial_by_id(trials: Array, trial_id: String) -> Dictionary:
	for trial_value in trials:
		var trial: Dictionary = trial_value
		if String(trial.get("trial_id", "")) == trial_id:
			return trial
	return {}


static func _has_configuration_error(result: Dictionary, code: String) -> bool:
	for error_value in result.get("configuration_errors", []):
		var error: Dictionary = error_value
		if String(error.get("code", "")) == code:
			return true
	return false


static func _invalid_summary(offset_x_m: float) -> Dictionary:
	return {
		"trial_id": "invalid_%s" % str(offset_x_m),
		"custom_com_offset_x_m": offset_x_m,
		"sample_count": 0,
		"contact_sample_count": 0,
		"cop_sample_count": 0,
		"capacity_complete": false,
		"geometry_oracle_error_m": INF,
	}


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
