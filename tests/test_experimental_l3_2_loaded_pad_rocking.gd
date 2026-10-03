extends SceneTree

## BR3B/L3.2 force-controlled rocking of a free, loaded rectangular pad.
##
## Every application offset receives a fresh world. The only authored moment is
## r x F from one downward force applied through RigidBody3D.apply_force.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload("res://scripts/lab/observer_profile.gd")
const RigFactoryScript := preload("res://scripts/lab/rig_factory.gd")
const PressureObserverScript := preload("res://scripts/lab/mechanics/contact_pressure_observer.gd")
const ReconstructorScript := preload(
	"res://scripts/lab/mechanics/external_contact_impulse_reconstructor.gd"
)
const AnalyzerScript := preload("res://scripts/lab/mechanics/loaded_pad_rocking_analyzer.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const PHYSICS_TICKS_PER_SECOND := 60
const SETTLE_TICKS := 90
const TRIAL_TICKS := 180
const COP_WARMUP_TICKS := 20
const EXTERNAL_DOWNWARD_LOAD_N := 40.0
const FRICTION := 1.0
const APPLICATION_OFFSETS_X_M := [0.0, 0.10, 0.18, 0.21, 0.24]
const MIRROR_APPLICATION_OFFSET_X_M := -0.24
const PREPIVOT_TILT_RAD := deg_to_rad(2.0)
const COP_WINDOW_MAX_TILT_RAD := deg_to_rad(5.0)
const ANALYZER_CONFIGURATION := {
	"pad_mass_kg": 2.0,
	"gravity_m_s2": 9.8,
	"external_downward_load_n": EXTERNAL_DOWNWARD_LOAD_N,
	"support_half_width_m": 0.15,
	"required_application_offsets_x_m": APPLICATION_OFFSETS_X_M,
	"minimum_contact_samples_per_trial": 12,
	"maximum_stable_cop_error_m": 0.008,
	"maximum_stable_normal_load_error_n": 0.05,
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
	print("=== Experimental L3.2 loaded-pad rocking edge ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_TICKS_PER_SECOND
	var profile: Dictionary = ObserverProfileScript.resolve(&"full_contacts_v2")
	_check(
		bool(profile.get("executable", false)),
		"full_contacts_v2 is executable for loaded rocking observations"
	)
	_test_configuration_refusal(profile)
	var summaries: Array = []
	var all_complete := true
	for offset_value in APPLICATION_OFFSETS_X_M:
		var trial := await _run_trial(profile, float(offset_value))
		all_complete = all_complete and bool(trial.get("complete", false))
		summaries.append(trial["summary"])
	_check(
		all_complete,
		"all primary application-offset trials retain complete pressure and momentum evidence"
	)
	_evaluate(summaries)
	var mirror := await _run_trial(profile, MIRROR_APPLICATION_OFFSET_X_M)
	var mirror_summary: Dictionary = mirror["summary"]
	var positive_summary: Dictionary = summaries[4]
	_check(
		(
			bool(mirror.get("complete", false))
			and bool(mirror_summary.get("pivot_observed", false))
			and float(mirror_summary.get("max_directional_up_x", 0.0)) >= 0.25
			and (float(mirror_summary.get("max_directional_angular_speed_rad_s", 0.0)) > 0.0)
		),
		"negative application offset rocks toward the negative edge with mirrored signs"
	)
	_check(
		(
			(
				absf(
					float(mirror_summary["max_tilt_rad"]) - float(positive_summary["max_tilt_rad"])
				)
				<= deg_to_rad(3.0)
			)
			and (
				absf(
					(
						float(mirror_summary["max_cop_toward_edge_fraction"])
						- float(positive_summary["max_cop_toward_edge_fraction"])
					)
				)
				<= 0.1
			)
		),
		"equal-magnitude positive and negative loads retain symmetric rocking response"
	)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_configuration_refusal(profile: Dictionary) -> void:
	var hidden := RigFactoryScript.build(
		&"loaded_pad_v1",
		CaptureClockScript.new(),
		profile,
		{"freeze": true},
		{"friction": FRICTION}
	)
	_check(
		(
			not bool(hidden.get("ok", true))
			and _has_configuration_error(hidden, "UNSUPPORTED_PARAMETER")
		),
		"loaded-pad rig refuses hidden body locks or balance parameters"
	)
	var hidden_fixture := RigFactoryScript.build(
		&"loaded_pad_v1",
		CaptureClockScript.new(),
		profile,
		{},
		{"friction": FRICTION, "balance_umbrella": true}
	)
	_check(
		(
			not bool(hidden_fixture.get("ok", true))
			and _has_configuration_error(hidden_fixture, "UNSUPPORTED_PARAMETER")
		),
		"loaded-pad rig refuses a hidden fixture-side balance umbrella"
	)


func _run_trial(profile: Dictionary, application_offset_x_m: float) -> Dictionary:
	var clock = CaptureClockScript.new()
	var rig := RigFactoryScript.build(&"loaded_pad_v1", clock, profile, {}, {"friction": FRICTION})
	if not bool(rig.get("ok", false)):
		return {"complete": false, "summary": _invalid_summary(application_offset_x_m)}
	var contract: Dictionary = rig["load_application_contract"]
	var free_contract := (
		String(contract["method"]) == "RigidBody3D.apply_force"
		and not bool(contract["hidden_pin_constraint"])
		and not bool(contract["hidden_translation_constraint"])
		and not bool(contract["hidden_rotation_constraint"])
		and not bool(contract["hidden_damping"])
		and not bool(contract["built_in_motor"])
	)
	var moment_contract := bool(contract["applied_moment_is_only_force_cross_declared_offset"])
	if application_offset_x_m == 0.0:
		_check(
			free_contract and moment_contract,
			"rocking fixture exposes a free pad and only the declared force-offset moment"
		)
	var world := rig["world"] as Node3D
	var body := rig["body"] as RigidBody3D
	root.add_child(world)
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	var force := Vector3(0.0, -EXTERNAL_DOWNWARD_LOAD_N, 0.0)
	var gravity := _gravity_acceleration_world()
	var force_application_count := 0
	for settle_step in SETTLE_TICKS:
		var before := _momentum_sample(body, String(rig["body_id"]))
		clock.open_epoch(settle_step, float(settle_step + 1) * step_s, &"integrate_callback")
		body.apply_force(force, Vector3.ZERO)
		force_application_count += 1
		await physics_frame
		clock.close_epoch()
		var after := _momentum_sample(body, String(rig["body_id"]))
		ReconstructorScript.reconstruct(
			[before],
			[after],
			step_s,
			(float(rig["pad_mass_kg"]) * gravity + force) * step_s,
			Vector3.UP
		)
	var initial_origin := body.global_position
	var direction := signf(application_offset_x_m)
	var measurement_direction := direction if direction != 0.0 else 1.0
	var predicted_cop := (
		EXTERNAL_DOWNWARD_LOAD_N
		* application_offset_x_m
		/ (float(rig["pad_mass_kg"]) * gravity.length() + EXTERNAL_DOWNWARD_LOAD_N)
	)
	var analytic_margin := float(rig["support_half_width_x_m"]) - absf(predicted_cop)
	var contact_sample_count := 0
	var cop_sample_count := 0
	var stable_cop_sample_count := 0
	var valid_reconstruction_sample_count := 0
	var capacity_complete := true
	var stable_cop_error_sum := 0.0
	var maximum_stable_normal_error := 0.0
	var max_tilt := 0.0
	var final_tilt := 0.0
	var max_angular_speed := 0.0
	var max_directional_up_x := 0.0
	var max_directional_angular_speed := 0.0
	var max_cop_toward_edge_fraction := 0.0
	var max_pretip_slip_speed := 0.0
	var pivot_observed := false
	var first_pivot_tick: Variant = null
	for local_step in TRIAL_TICKS:
		var step_id := SETTLE_TICKS + local_step
		var before := _momentum_sample(body, String(rig["body_id"]))
		clock.open_epoch(step_id, float(step_id + 1) * step_s, &"integrate_callback")
		body.apply_force(force, Vector3(application_offset_x_m, 0.0, 0.0))
		force_application_count += 1
		await physics_frame
		clock.close_epoch()
		var after := _momentum_sample(body, String(rig["body_id"]))
		var reconstruction := ReconstructorScript.reconstruct(
			[before],
			[after],
			step_s,
			(float(rig["pad_mass_kg"]) * gravity + force) * step_s,
			Vector3.UP
		)
		if bool(reconstruction.get("reconstruction_valid", false)):
			valid_reconstruction_sample_count += 1
		var diagnostics: Dictionary = body.latest_contact_v2_diagnostics
		var capacity: Dictionary = diagnostics.get("observation", {})
		capacity_complete = (
			capacity_complete
			and bool(capacity.get("finite", false))
			and not bool(capacity.get("saturated_ever", true))
		)
		var up_world := body.global_basis.y.normalized()
		var tilt := acos(clampf(up_world.dot(Vector3.UP), -1.0, 1.0))
		final_tilt = tilt
		max_tilt = maxf(max_tilt, tilt)
		max_angular_speed = maxf(max_angular_speed, body.angular_velocity.length())
		max_directional_up_x = maxf(max_directional_up_x, up_world.x * measurement_direction)
		max_directional_angular_speed = maxf(
			max_directional_angular_speed, -body.angular_velocity.z * measurement_direction
		)
		var pressure := PressureObserverScript.observe_raw_points(
			body.latest_contacts_v2, step_id, String(rig["floor_id"]), step_s, Vector3.UP
		)
		if not body.latest_contacts_v2.is_empty():
			contact_sample_count += 1
		if bool(pressure.get("observation_valid", false)):
			cop_sample_count += 1
			var cop_world: Vector3 = pressure["center_of_pressure_world_m"]
			var relative_cop_x := cop_world.x - body.global_position.x
			if tilt <= COP_WINDOW_MAX_TILT_RAD:
				max_cop_toward_edge_fraction = maxf(
					max_cop_toward_edge_fraction,
					relative_cop_x * measurement_direction / float(rig["support_half_width_x_m"])
				)
			if local_step >= COP_WARMUP_TICKS and tilt <= deg_to_rad(0.5):
				stable_cop_sample_count += 1
				stable_cop_error_sum += absf(relative_cop_x - predicted_cop)
		if tilt < PREPIVOT_TILT_RAD:
			max_pretip_slip_speed = maxf(
				max_pretip_slip_speed, _maximum_contact_slip_speed(body, step_id)
			)
		if (
			direction != 0.0
			and tilt >= PREPIVOT_TILT_RAD
			and max_directional_up_x > 0.0
			and max_cop_toward_edge_fraction >= 0.8
		):
			pivot_observed = true
			if first_pivot_tick == null:
				first_pivot_tick = local_step
		if tilt <= deg_to_rad(0.5) and bool(reconstruction.get("reconstruction_valid", false)):
			var normal := float(reconstruction["reconstructed_step_average_normal_load_n"])
			var expected := float(rig["pad_mass_kg"]) * gravity.length() + EXTERNAL_DOWNWARD_LOAD_N
			maximum_stable_normal_error = maxf(maximum_stable_normal_error, absf(normal - expected))
	var mean_cop_error := (
		stable_cop_error_sum / float(stable_cop_sample_count)
		if stable_cop_sample_count > 0
		else INF
	)
	var summary := {
		"trial_id": "application_%+.3fm" % application_offset_x_m,
		"application_offset_x_m": application_offset_x_m,
		"predicted_resultant_cop_x_m": predicted_cop,
		"analytic_support_margin_m": analytic_margin,
		"analytic_inside_support": analytic_margin >= 0.0,
		"sample_count": TRIAL_TICKS,
		"contact_sample_count": contact_sample_count,
		"cop_sample_count": cop_sample_count,
		"stable_cop_sample_count": stable_cop_sample_count,
		"valid_reconstruction_sample_count": valid_reconstruction_sample_count,
		"capacity_complete": capacity_complete,
		"mean_stable_cop_error_m": mean_cop_error,
		"maximum_stable_normal_load_error_n": maximum_stable_normal_error,
		"max_tilt_rad": max_tilt,
		"final_tilt_rad": final_tilt,
		"max_angular_speed_rad_s": max_angular_speed,
		"max_directional_up_x": max_directional_up_x,
		"max_directional_angular_speed_rad_s": max_directional_angular_speed,
		"max_cop_toward_edge_fraction": max_cop_toward_edge_fraction,
		"max_pretip_slip_speed_mps": max_pretip_slip_speed,
		"pivot_observed": pivot_observed,
		"first_pivot_tick": first_pivot_tick,
		"lateral_displacement_m": absf(body.global_position.x - initial_origin.x),
		"free_pad_contract": free_contract,
		"force_offset_contract":
		moment_contract and force_application_count == SETTLE_TICKS + TRIAL_TICKS,
	}
	print(
		(
			(
				"  offset=%+.3fm resultant=%+.4fm margin=%+.4fm contacts/CoP=%d/%d "
				+ "cop_err=%7.4fm edge=%5.3f tilt=%6.2fdeg pivot=%s@%s"
			)
			% [
				application_offset_x_m,
				predicted_cop,
				analytic_margin,
				contact_sample_count,
				cop_sample_count,
				mean_cop_error,
				max_cop_toward_edge_fraction,
				rad_to_deg(max_tilt),
				str(pivot_observed),
				str(first_pivot_tick),
			]
		)
	)
	var complete := (
		capacity_complete
		and valid_reconstruction_sample_count == TRIAL_TICKS
		and contact_sample_count >= 12
		and cop_sample_count >= 12
		and force_application_count == SETTLE_TICKS + TRIAL_TICKS
	)
	world.queue_free()
	await process_frame
	return {"complete": complete, "summary": summary}


func _evaluate(summaries: Array) -> void:
	var built := AnalyzerScript.build_config(ANALYZER_CONFIGURATION)
	_check(bool(built.get("ok", false)), "L3.2 gates form a digest-bound rocking contract")
	if not bool(built.get("ok", false)):
		return
	var unknown: Dictionary = (built["config"] as Dictionary).duplicate(true)
	unknown["automatic_bracing_claim"] = true
	var unknown_payload := unknown.duplicate(true)
	unknown_payload.erase("config_digest_sha256")
	unknown["config_digest_sha256"] = CanonicalJsonScript.sha256(unknown_payload)
	var unknown_result := AnalyzerScript.analyze(unknown, summaries)
	_check(
		(
			not bool(unknown_result["ok"])
			and unknown_result["invalid_reasons"] == ["LOADED_PAD_ROCKING_CONFIG_INVALID"]
		),
		"coherently rehashed bracing or guidance fields fail closed"
	)
	var corrupted: Array = summaries.duplicate(true)
	(corrupted[4] as Dictionary)["predicted_resultant_cop_x_m"] = 0.0
	var corrupted_result := AnalyzerScript.analyze(built["config"], corrupted)
	_check(
		(
			not bool(corrupted_result["ok"])
			and (corrupted_result["invalid_reasons"] as Array).has(
				"LOADED_PAD_ROCKING_RESULTANT_ORACLE_MISMATCH:4"
			)
		),
		"corrupting the force-resultant oracle invalidates rocking admission"
	)
	var analysis := AnalyzerScript.analyze(built["config"], summaries)
	_check(
		(
			bool(analysis.get("ok", false))
			and bool(analysis.get("admitted", false))
			and bool(analysis.get("threshold_detected", false))
		),
		"complete real-Jolt loaded-pad trials bracket one rocking transition"
	)
	if not bool(analysis.get("ok", false)):
		printerr("  rocking_analysis=", analysis)
		return
	print(
		(
			"  application_threshold=[%.3f, %.3f]m analytic=%.4fm"
			% [
				float(analysis["threshold_application_offset_lower_m"]),
				float(analysis["threshold_application_offset_upper_m"]),
				float(analysis["analytic_critical_application_offset_m"]),
			]
		)
	)
	_check(
		(
			String(analysis["last_stable_trial_id"]) == "application_+0.210m"
			and String(analysis["first_tipping_trial_id"]) == "application_+0.240m"
		),
		"0.21 m remains supported while 0.24 m rocks beyond the loaded edge"
	)
	_check(
		(
			bool(analysis["analytic_edge_inside_empirical_bracket"])
			and float(analysis["threshold_bracket_width_m"]) <= 0.03 + 1.0e-9
		),
		"analytic 0.2235 m force offset lies inside a 0.03 m empirical bracket"
	)
	var classifications: Array = analysis["classified_trials"]
	var last_stable: Dictionary = classifications[3]
	var first_tipping: Dictionary = classifications[4]
	_check(
		(
			float(last_stable["mean_stable_cop_error_m"]) <= 0.008
			and float(last_stable["max_cop_toward_edge_fraction"]) >= 0.8
		),
		"predicted CoP moves near the support edge before rocking"
	)
	_check(
		(
			bool(first_tipping["pivot_observed"])
			and float(first_tipping["max_pretip_slip_speed_mps"]) <= 0.05
		),
		"first unstable cell pivots at the predicted edge before appreciable slip"
	)
	var exclusions: Array = analysis["does_not_establish"]
	_check(
		(
			exclusions.has("general_per_foot_load_allocation")
			and exclusions.has("articulated_load_bearing_limb")
			and exclusions.has("standing")
			and exclusions.has("walking")
		),
		"L3.2 result excludes load allocation, articulated support, and locomotion claims"
	)


static func _maximum_contact_slip_speed(body: RigidBody3D, step_id: int) -> float:
	var maximum := 0.0
	var center_of_mass_world := body.global_transform * body.center_of_mass
	for raw_value in body.latest_contacts_v2:
		if not raw_value is Dictionary:
			continue
		var raw: Dictionary = raw_value
		if int(raw.get("physics_step_id", -1)) != step_id or not bool(raw.get("finite", false)):
			continue
		var point: Vector3 = raw["point_world"]
		var normal: Vector3 = (raw["normal_world"] as Vector3).normalized()
		var point_velocity := (
			body.linear_velocity + body.angular_velocity.cross(point - center_of_mass_world)
		)
		var tangential := point_velocity - point_velocity.dot(normal) * normal
		maximum = maxf(maximum, tangential.length())
	return maximum


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


static func _has_configuration_error(result: Dictionary, code: String) -> bool:
	for error_value in result.get("configuration_errors", []):
		if String((error_value as Dictionary).get("code", "")) == code:
			return true
	return false


static func _invalid_summary(offset_x_m: float) -> Dictionary:
	return {
		"trial_id": "invalid_%s" % str(offset_x_m),
		"application_offset_x_m": offset_x_m,
		"capacity_complete": false,
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
