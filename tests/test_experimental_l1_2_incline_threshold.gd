extends SceneTree

## Experimental L1.2 live incline threshold.
##
## Every angle is a separate free-body Godot/Jolt world. The test uses L1.1's
## post-step contact-point kinematics as slip authority and compares measured
## normal/shear loads with mg*cos(theta), mg*sin(theta), and tan(theta).

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")
const RigFactoryScript := preload("res://scripts/lab/rig_factory.gd")
const CanonicalizerScript := preload(
	"res://scripts/lab/mechanics/contact_canonicalizer.gd")
const SlipObserverScript := preload(
	"res://scripts/lab/mechanics/contact_slip_observer.gd")
const InclineAnalyzerScript := preload(
	"res://scripts/lab/mechanics/incline_threshold_analyzer.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const PHYSICS_TICKS_PER_SECOND := 60
const WARMUP_TICKS := 90
const TRIAL_TICKS := 30
const ANALYSIS_TICKS := 15
const FRICTION := 0.6
const SLOPE_ANGLES_DEG := [0.0, 20.0, 28.0, 30.0, 32.0, 34.0, 40.0]
const ANALYZER_CONFIGURATION := {
	"minimum_samples_per_trial": ANALYSIS_TICKS,
	"maximum_holding_speed_mps": 0.01,
	"maximum_holding_displacement_m": 0.003,
	"minimum_sliding_speed_mps": 0.05,
	"minimum_sliding_displacement_m": 0.01,
	"minimum_normal_alignment_dot": 0.999,
	"authored_pair_friction": FRICTION,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental L1.2 live incline threshold ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_TICKS_PER_SECOND
	var profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v2")
	_check(bool(profile.get("executable", false)),
		"full_contacts_v2 is executable for independent incline trials")
	_test_configuration_refusal(profile)

	var summaries: Array = []
	var all_complete := true
	for angle_value in SLOPE_ANGLES_DEG:
		var result: Dictionary = await _run_trial(
			profile, float(angle_value))
		all_complete = bool(result.get("complete", false)) and all_complete
		summaries.append(result["summary"])
	_check(all_complete,
		"all incline angles retain complete finite semantic contact windows")
	_evaluate_threshold(summaries)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_configuration_refusal(profile: Dictionary) -> void:
	print("- incline fixture refuses hidden support and invalid angles")
	var hidden_rail: Dictionary = RigFactoryScript.build(
		&"incline_block_v1",
		CaptureClockScript.new(),
		profile,
		{},
		{"friction": FRICTION, "slope_angle_deg": 30.0, "rail": true})
	_check(not bool(hidden_rail.get("ok", true))
		and _has_configuration_error(hidden_rail, "UNSUPPORTED_PARAMETER"),
		"a hidden incline rail cannot enter the fixture")
	var excessive_angle: Dictionary = RigFactoryScript.build(
		&"incline_block_v1",
		CaptureClockScript.new(),
		profile,
		{},
		{"friction": FRICTION, "slope_angle_deg": 61.0})
	_check(not bool(excessive_angle.get("ok", true))
		and _has_configuration_error(excessive_angle, "SLOPE_ANGLE_INVALID"),
		"angles outside the preregistered [0, 60] degree range fail closed")


func _run_trial(profile: Dictionary, angle_deg: float) -> Dictionary:
	var clock = CaptureClockScript.new()
	var rig: Dictionary = RigFactoryScript.build(
		&"incline_block_v1",
		clock,
		profile,
		{},
		{"friction": FRICTION, "slope_angle_deg": angle_deg})
	if not bool(rig.get("ok", false)):
		return {"complete": false, "summary": _invalid_summary(angle_deg)}
	var constraint: Dictionary = rig["constraint_contract"]
	if angle_deg == 0.0:
		_check(not bool(constraint["hidden_rotation_constraint"])
			and not bool(constraint["hidden_translation_constraint"])
			and not bool(constraint["hidden_damping"])
			and String(constraint["external_drive"]) == "gravity_only"
			and not bool(constraint["plane_rotated_during_trial"]),
			"incline trials declare a free body, static plane, and gravity-only drive")
	var world := rig["world"] as Node3D
	var body := rig["body"] as RigidBody3D
	root.add_child(world)
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	for step_id in WARMUP_TICKS:
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()

	var sample_count := 0
	var valid_sample_count := 0
	var contact_sample_count := 0
	var max_slip_speed := 0.0
	var max_solver_input_slip := 0.0
	var normal_load_sum := 0.0
	var contact_shear_sum := 0.0
	var gravity_normal_sum := 0.0
	var gravity_shear_sum := 0.0
	var normal_alignment_min := 1.0
	var solver_ratio_sum := 0.0
	var solver_ratio_count := 0
	var max_body_plane_tilt_rad := 0.0
	var capacity_complete := true
	var first_position := Vector3(INF, INF, INF)
	var last_position := Vector3(INF, INF, INF)
	var plane_normal: Vector3 = rig["plane_normal_world"]
	var downhill: Vector3 = rig["downhill_world"]
	for local_step in TRIAL_TICKS:
		var step_id := WARMUP_TICKS + local_step
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()
		if local_step < TRIAL_TICKS - ANALYSIS_TICKS:
			continue
		sample_count += 1
		var diagnostics: Dictionary = body.latest_contact_v2_diagnostics
		var capacity: Dictionary = diagnostics.get("observation", {})
		capacity_complete = (
			bool(capacity.get("finite", false))
			and not bool(capacity.get("saturated_ever", true))
			and capacity_complete)
		var canonical := _canonical_frame(rig, body, step_id)
		if not bool(canonical.get("ok", false)) \
				or int(canonical.get("canonical_patch_count", 0)) != 1:
			continue
		contact_sample_count += 1
		var patch: Dictionary = canonical["patches"][0]
		var gravity_acceleration := _vector3(
			body.latest_body_sample.get("total_gravity_world"))
		var gravity_force := gravity_acceleration * float(rig["body_mass_kg"])
		var slip: Dictionary = SlipObserverScript.observe(
			patch,
			step_s,
			gravity_force,
			_post_step_kinematics(body, patch))
		if not bool(slip.get("observation_valid", false)):
			continue
		valid_sample_count += 1
		max_slip_speed = maxf(max_slip_speed, float(slip["slip_speed_mps"]))
		max_solver_input_slip = maxf(
			max_solver_input_slip,
			float(slip["solver_input_slip_speed_mps"]))
		normal_load_sum += float(slip["predicted_normal_load_n"])
		contact_shear_sum += float(slip["predicted_tangential_load_n"])
		gravity_normal_sum += absf(gravity_force.dot(plane_normal))
		gravity_shear_sum += (
			gravity_force - gravity_force.dot(plane_normal) * plane_normal).length()
		normal_alignment_min = minf(
			normal_alignment_min,
			(patch["normal_world"] as Vector3).normalized().dot(plane_normal))
		var solver_ratio: Variant = slip["solver_friction_ratio"]
		if solver_ratio != null:
			solver_ratio_sum += float(solver_ratio)
			solver_ratio_count += 1
		var position := body.global_position
		if not first_position.is_finite():
			first_position = position
		last_position = position
		max_body_plane_tilt_rad = maxf(
			max_body_plane_tilt_rad,
			acos(clampf(
				body.global_basis.y.normalized().dot(plane_normal), -1.0, 1.0)))
	var displacement := (
		absf((last_position - first_position).dot(downhill))
		if first_position.is_finite() and last_position.is_finite()
		else INF)
	var cross_slope_displacement := (
		absf((last_position - first_position).dot(
			rig["cross_slope_world"] as Vector3))
		if first_position.is_finite() and last_position.is_finite()
		else INF)
	var complete := (
		capacity_complete
		and sample_count == ANALYSIS_TICKS
		and valid_sample_count == sample_count
		and contact_sample_count == sample_count
		and is_finite(displacement)
		and is_finite(cross_slope_displacement))
	var denominator := float(maxi(valid_sample_count, 1))
	var summary := {
		"trial_id": "slope_%02ddeg" % int(angle_deg),
		"slope_angle_deg": angle_deg,
		"sample_count": sample_count,
		"valid_sample_count": valid_sample_count,
		"contact_sample_count": contact_sample_count,
		"max_slip_speed_mps": max_slip_speed,
		"max_solver_input_slip_speed_mps": max_solver_input_slip,
		"tangential_displacement_m": displacement,
		"cross_slope_displacement_m": cross_slope_displacement,
		"mean_normal_load_n": normal_load_sum / denominator,
		"mean_predicted_contact_shear_n": contact_shear_sum / denominator,
		"mean_gravity_normal_force_n": gravity_normal_sum / denominator,
		"mean_gravity_shear_force_n": gravity_shear_sum / denominator,
		"mean_solver_friction_ratio": (
			solver_ratio_sum / float(solver_ratio_count)
			if solver_ratio_count > 0 else null),
		"minimum_contact_normal_alignment_dot": normal_alignment_min,
		"max_body_plane_tilt_rad": max_body_plane_tilt_rad,
		"capacity_complete": capacity_complete,
	}
	print(("  slope=%5.1fdeg valid=%d/%d slip(post/solver)=%.5f/%.5fm/s "
			+ "ds=%.5fm N=%.3f/%.3fN T=%.3f/%.3fN align=%.7f") % [
		angle_deg,
		valid_sample_count,
		sample_count,
		max_slip_speed,
		max_solver_input_slip,
		displacement,
		float(summary["mean_normal_load_n"]),
		float(summary["mean_gravity_normal_force_n"]),
		float(summary["mean_predicted_contact_shear_n"]),
		float(summary["mean_gravity_shear_force_n"]),
		normal_alignment_min,
	])
	world.queue_free()
	await process_frame
	return {"complete": complete, "summary": summary}


func _evaluate_threshold(summaries: Array) -> void:
	var built: Dictionary = InclineAnalyzerScript.build_config(
		ANALYZER_CONFIGURATION)
	_check(bool(built.get("ok", false)),
		"incline thresholds form a valid hysteretic independent-trial contract")
	if not bool(built.get("ok", false)):
		return
	var extended_config: Dictionary = (built["config"] as Dictionary).duplicate(true)
	extended_config["automatic_standing_claim"] = true
	var extended_payload := extended_config.duplicate(true)
	extended_payload.erase("config_digest_sha256")
	extended_config["config_digest_sha256"] = CanonicalJsonScript.sha256(
		extended_payload)
	var extended_result: Dictionary = InclineAnalyzerScript.analyze(
		extended_config, summaries)
	_check(not bool(extended_result["ok"])
		and extended_result["invalid_reasons"] == ["INCLINE_CONFIG_INVALID"],
		"coherently rehashed unknown incline config fields fail closed")
	var wrong_normal_trials: Array = summaries.duplicate(true)
	(wrong_normal_trials[3] as Dictionary)[
		"minimum_contact_normal_alignment_dot"] = 0.5
	var wrong_normal_result: Dictionary = InclineAnalyzerScript.analyze(
		built["config"], wrong_normal_trials)
	_check(not bool(wrong_normal_result["ok"])
		and (wrong_normal_result["invalid_reasons"] as Array).has(
			"INCLINE_TRIAL_NORMAL_FRAME_MISMATCH:3"),
		"a wrong contact-normal frame cannot produce an incline threshold")
	var analysis: Dictionary = InclineAnalyzerScript.analyze(
		built["config"], summaries)
	_check(bool(analysis.get("ok", false))
		and bool(analysis.get("threshold_detected", false)),
		"real Jolt trials bracket one monotonic incline hold-to-slide transition")
	if not bool(analysis.get("ok", false)):
		printerr("  incline_analysis=", analysis)
		return
	print("  incline_threshold=[%.3f, %.3f]deg ratio=[%.5f, %.5f] analytic=%.5fdeg" % [
		float(analysis["threshold_angle_lower_deg"]),
		float(analysis["threshold_angle_upper_deg"]),
		float(analysis["empirical_ratio_lower"]),
		float(analysis["empirical_ratio_upper"]),
		float(analysis["analytic_coulomb_threshold_deg"]),
	])
	_check(String(analysis["last_held_trial_id"]) == "slope_30deg"
		and String(analysis["first_sliding_trial_id"]) == "slope_32deg",
		"authored friction 0.6 holds 30 degrees and slides at 32 degrees")
	_check(bool(analysis["analytic_threshold_inside_empirical_bracket"])
		and absf(float(analysis["analytic_coulomb_threshold_deg"])
			- rad_to_deg(atan(FRICTION))) <= 1.0e-6,
		"analytic atan(mu) threshold lies inside the empirical angle bracket")
	_check(float(analysis["threshold_angle_bracket_width_deg"]) <= 2.0,
		"independent trials localize the incline threshold within two degrees")

	var held_20 := _trial_by_id(
		analysis["classified_trials"], "slope_20deg")
	_check(String(held_20.get("classification", "")) == InclineAnalyzerScript.HELD
		and absf(float(held_20["mean_predicted_contact_shear_n"])
			- float(held_20["mean_gravity_shear_force_n"])) <= 1.0,
		"held 20-degree trial balances tangential gravity within 1 N")
	_check(absf(float(held_20["mean_normal_load_n"])
			- float(held_20["mean_gravity_normal_force_n"])) <= 1.0,
		"held 20-degree trial balances normal gravity within 1 N")
	var sliding_40 := _trial_by_id(
		analysis["classified_trials"], "slope_40deg")
	_check(String(sliding_40.get("classification", ""))
			== InclineAnalyzerScript.SLIDING
		and absf(float(sliding_40["mean_solver_friction_ratio"]) - FRICTION)
			<= 0.02,
		"sliding 40-degree contact saturates near the authored friction ratio")
	var all_normals_aligned := true
	var all_cross_slope_bounded := true
	var all_untilted := true
	for trial_value in analysis["classified_trials"]:
		var trial: Dictionary = trial_value
		all_normals_aligned = (
			float(trial["minimum_contact_normal_alignment_dot"]) >= 0.999
			and all_normals_aligned)
		all_cross_slope_bounded = (
			float(trial["cross_slope_displacement_m"]) <= 0.001
			and all_cross_slope_bounded)
		all_untilted = (
			float(trial["max_body_plane_tilt_rad"]) <= deg_to_rad(3.0)
			and all_untilted)
	_check(all_normals_aligned,
		"every measured contact normal matches its authored rotated plane")
	_check(all_cross_slope_bounded,
		"all motion stays in the gravity-defined down-slope direction")
	_check(all_untilted,
		"hold/slide classification occurs before three-degree tip contamination")
	_check((analysis["does_not_establish"] as Array).has("walking")
		and (analysis["does_not_establish"] as Array).has("standing"),
		"L1.2 result explicitly excludes standing and walking")


func _canonical_frame(
		rig: Dictionary,
		body,
		step_id: int) -> Dictionary:
	var diagnostics: Dictionary = body.latest_contact_v2_diagnostics
	return CanonicalizerScript.canonicalize(
		body.latest_contacts_v2,
		diagnostics.get("observation", {}),
		{
			"physics_step_id": step_id,
			"capture_epoch": step_id,
			"sample_phase": "integrate_callback",
			"run_id": String(rig["run_id"]),
			"capture_stream_id": String(rig["capture_stream_id"]),
			"observer_profile_id": "full_contacts_v2",
			"observer_adapter_id": "rigid_body_integrate_forces_v2",
			"body_id": String(rig["body_id"]),
		})


static func _post_step_kinematics(
		body: RigidBody3D,
		patch: Dictionary) -> Dictionary:
	return {
		"physics_step_id": int(patch["physics_step_id"]),
		"capture_epoch": int(patch["capture_epoch"]),
		"sample_phase": "post_step",
		"body_linear_velocity_world_mps": body.linear_velocity,
		"body_angular_velocity_world_rad_s": body.angular_velocity,
		"body_center_of_mass_world_m": (
			body.global_transform * body.center_of_mass),
		"counterparty_velocity_world_mps": Vector3.ZERO,
	}


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


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() == 3:
		var raw: Array = value
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(INF, INF, INF)


static func _invalid_summary(angle_deg: float) -> Dictionary:
	return {
		"trial_id": "invalid_%s" % str(angle_deg),
		"slope_angle_deg": angle_deg,
		"sample_count": 0,
		"valid_sample_count": 0,
		"contact_sample_count": 0,
		"max_slip_speed_mps": INF,
		"tangential_displacement_m": INF,
		"mean_normal_load_n": 0.0,
		"minimum_contact_normal_alignment_dot": 0.0,
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
