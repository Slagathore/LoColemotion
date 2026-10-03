extends SceneTree

## BR3B/L3.1 shear breakaway under a separately measured imposed normal load.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload("res://scripts/lab/observer_profile.gd")
const RigFactoryScript := preload("res://scripts/lab/rig_factory.gd")
const ReconstructorScript := preload(
	"res://scripts/lab/mechanics/external_contact_impulse_reconstructor.gd"
)
const AnalyzerScript := preload("res://scripts/lab/mechanics/loaded_pad_shear_analyzer.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const PHYSICS_TICKS_PER_SECOND := 60
const SETTLE_TICKS := 90
const STAGE_TICKS := 60
const ANALYSIS_TICKS := 30
const EXTERNAL_DOWNWARD_LOAD_N := 40.0
const AUTHORED_FRICTION := 0.6
const SHEAR_STAGES_N := [0.0, 20.0, 30.0, 34.0, 36.0, 38.0, 42.0]
const ACCEPTED_L1_RATIO_LOWER := 22.0 / 39.2
const ACCEPTED_L1_RATIO_UPPER := 24.0 / 39.2
const BREAKAWAY_CONFIG := {
	"minimum_samples_per_stage": ANALYSIS_TICKS,
	"maximum_holding_speed_mps": 0.01,
	"maximum_holding_displacement_m": 0.003,
	"minimum_sliding_speed_mps": 0.05,
	"minimum_sliding_displacement_m": 0.01,
}
const ANALYZER_CONFIGURATION := {
	"external_downward_load_n": EXTERNAL_DOWNWARD_LOAD_N,
	"authored_friction": AUTHORED_FRICTION,
	"required_shear_schedule_n": SHEAR_STAGES_N,
	"maximum_normal_load_error_n": 0.05,
	"accepted_l1_ratio_lower": ACCEPTED_L1_RATIO_LOWER,
	"accepted_l1_ratio_upper": ACCEPTED_L1_RATIO_UPPER,
	"breakaway_config": BREAKAWAY_CONFIG,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental L3.1 loaded-pad shear breakaway ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_TICKS_PER_SECOND
	var profile: Dictionary = ObserverProfileScript.resolve(&"full_contacts_v2")
	_check(
		bool(profile.get("executable", false)),
		"full_contacts_v2 is executable for loaded shear observations"
	)
	var run := await _run_ramp(profile)
	_check(
		bool(run.get("complete", false)),
		"every loaded-pad shear stage retains complete contact and momentum evidence"
	)
	if bool(run.get("complete", false)):
		_evaluate(run["stage_summaries"])
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _run_ramp(profile: Dictionary) -> Dictionary:
	var clock = CaptureClockScript.new()
	var rig := RigFactoryScript.build(
		&"loaded_pad_v1", clock, profile, {}, {"friction": AUTHORED_FRICTION}
	)
	if not bool(rig.get("ok", false)):
		return {"complete": false}
	var contract: Dictionary = rig["load_application_contract"]
	var material: Dictionary = rig["material_contract"]
	var free_contract := (
		String(contract["method"]) == "RigidBody3D.apply_force"
		and not bool(contract["hidden_pin_constraint"])
		and not bool(contract["hidden_translation_constraint"])
		and not bool(contract["hidden_rotation_constraint"])
		and not bool(contract["hidden_damping"])
		and not bool(contract["built_in_motor"])
	)
	_check(
		free_contract and bool(contract["applied_moment_is_only_force_cross_declared_offset"]),
		"shear fixture has no hidden rail, pin, damping, motor, or moment"
	)
	_check(
		(
			String(material["godot_pair_rule"]) == "minimum_friction_both_nonrough_v1"
			and not bool(material["body_rough"])
			and not bool(material["floor_rough"])
		),
		"both surfaces retain the accepted non-rough minimum-friction rule"
	)
	var world := rig["world"] as Node3D
	var body := rig["body"] as RigidBody3D
	root.add_child(world)
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	var next_step := 0
	for offset in SETTLE_TICKS:
		var step_id := next_step + offset
		clock.open_epoch(step_id, float(step_id + 1) * step_s, &"integrate_callback")
		body.apply_force(Vector3(0.0, -EXTERNAL_DOWNWARD_LOAD_N, 0.0), Vector3.ZERO)
		await physics_frame
		clock.close_epoch()
	next_step += SETTLE_TICKS
	var summaries: Array = []
	var complete := true
	for stage_value in SHEAR_STAGES_N:
		var sampled := await _sample_stage(rig, clock, next_step, float(stage_value), free_contract)
		next_step = int(sampled["next_step"])
		complete = complete and bool(sampled.get("complete", false))
		summaries.append(sampled["summary"])
	world.queue_free()
	await process_frame
	return {"complete": complete, "stage_summaries": summaries}


func _sample_stage(
	rig: Dictionary, clock, start_step: int, shear_force_n: float, free_contract: bool
) -> Dictionary:
	var body := rig["body"] as RigidBody3D
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	var applied_force := Vector3(shear_force_n, -EXTERNAL_DOWNWARD_LOAD_N, 0.0)
	var sample_count := 0
	var valid_sample_count := 0
	var contact_sample_count := 0
	var capacity_complete := true
	var normal_sum := 0.0
	var opposition_sum := 0.0
	var maximum_normal_error := 0.0
	var maximum_slip_speed := 0.0
	var first_position := Vector3(INF, INF, INF)
	var last_position := Vector3(INF, INF, INF)
	var maximum_tilt := 0.0
	for local_step in STAGE_TICKS:
		var step_id := start_step + local_step
		var before := _momentum_sample(body, String(rig["body_id"]))
		clock.open_epoch(step_id, float(step_id + 1) * step_s, &"integrate_callback")
		body.apply_force(applied_force, Vector3.ZERO)
		await physics_frame
		clock.close_epoch()
		if local_step < STAGE_TICKS - ANALYSIS_TICKS:
			continue
		sample_count += 1
		var diagnostics: Dictionary = body.latest_contact_v2_diagnostics
		var capacity: Dictionary = diagnostics.get("observation", {})
		capacity_complete = (
			capacity_complete
			and bool(capacity.get("finite", false))
			and not bool(capacity.get("saturated_ever", true))
		)
		if not body.latest_contacts_v2.is_empty():
			contact_sample_count += 1
		var after := _momentum_sample(body, String(rig["body_id"]))
		var gravity := _gravity_acceleration_world()
		var known_impulse := (float(rig["pad_mass_kg"]) * gravity + applied_force) * step_s
		var reconstruction := ReconstructorScript.reconstruct(
			[before], [after], step_s, known_impulse, Vector3.UP
		)
		if not bool(reconstruction.get("reconstruction_valid", false)):
			continue
		valid_sample_count += 1
		var normal := float(reconstruction["reconstructed_step_average_normal_load_n"])
		var expected := float(rig["pad_mass_kg"]) * gravity.length() + EXTERNAL_DOWNWARD_LOAD_N
		normal_sum += normal
		maximum_normal_error = maxf(maximum_normal_error, absf(normal - expected))
		var tangential_impulse: Vector3 = reconstruction["reconstructed_tangential_impulse_world_ns"]
		opposition_sum += -tangential_impulse.x / step_s
		var position := body.global_position
		if not first_position.is_finite():
			first_position = position
		last_position = position
		maximum_slip_speed = maxf(maximum_slip_speed, absf(body.linear_velocity.x))
		maximum_tilt = maxf(maximum_tilt, _tilt_rad(body))
	var displacement := (
		absf(last_position.x - first_position.x)
		if first_position.is_finite() and last_position.is_finite()
		else INF
	)
	var denominator := float(maxi(valid_sample_count, 1))
	var expected_normal := (
		float(rig["pad_mass_kg"]) * _gravity_acceleration_world().length()
		+ EXTERNAL_DOWNWARD_LOAD_N
	)
	var summary := {
		"stage_id": "shear_%03dN" % int(shear_force_n),
		"applied_shear_force_n": shear_force_n,
		"external_downward_load_n": EXTERNAL_DOWNWARD_LOAD_N,
		"sample_count": sample_count,
		"valid_sample_count": valid_sample_count,
		"contact_sample_count": contact_sample_count,
		"capacity_complete": capacity_complete,
		"mean_normal_load_n": normal_sum / denominator,
		"mean_expected_normal_load_n": expected_normal,
		"maximum_normal_load_error_n": maximum_normal_error,
		"mean_contact_opposition_n": opposition_sum / denominator,
		"max_slip_speed_mps": maximum_slip_speed,
		"tangential_displacement_m": displacement,
		"maximum_tilt_rad": maximum_tilt,
		"free_pad_contract": free_contract,
		"centered_force_contract": true,
	}
	print(
		(
			(
				"  shear=%5.1fN normal=%8.4f/%8.4fN oppose=%8.4fN "
				+ "speed=%8.5fm/s dx=%8.5fm tilt=%7.4fdeg"
			)
			% [
				shear_force_n,
				float(summary["mean_normal_load_n"]),
				expected_normal,
				float(summary["mean_contact_opposition_n"]),
				maximum_slip_speed,
				displacement,
				rad_to_deg(maximum_tilt),
			]
		)
	)
	return {
		"complete":
		(
			capacity_complete
			and sample_count == ANALYSIS_TICKS
			and valid_sample_count == sample_count
			and contact_sample_count == sample_count
		),
		"summary": summary,
		"next_step": start_step + STAGE_TICKS,
	}


func _evaluate(summaries: Array) -> void:
	var all_normal := true
	var all_level := true
	for summary_value in summaries:
		var summary: Dictionary = summary_value
		all_normal = all_normal and float(summary["maximum_normal_load_error_n"]) <= 0.05
		all_level = all_level and float(summary["maximum_tilt_rad"]) <= deg_to_rad(0.5)
	_check(all_normal, "normal support remains reconstructed under every shear stage")
	_check(all_level, "centered normal and shear loads do not contaminate the ramp with rocking")
	var built := AnalyzerScript.build_config(ANALYZER_CONFIGURATION)
	_check(bool(built.get("ok", false)), "L3.1 gates form a digest-bound loaded-shear contract")
	if not bool(built.get("ok", false)):
		return
	var unknown: Dictionary = (built["config"] as Dictionary).duplicate(true)
	unknown["per_foot_allocator_enabled"] = true
	var unknown_payload := unknown.duplicate(true)
	unknown_payload.erase("config_digest_sha256")
	unknown["config_digest_sha256"] = CanonicalJsonScript.sha256(unknown_payload)
	var unknown_result := AnalyzerScript.analyze(unknown, summaries)
	_check(
		(
			not bool(unknown_result["ok"])
			and unknown_result["invalid_reasons"] == ["LOADED_PAD_SHEAR_CONFIG_INVALID"]
		),
		"coherently rehashed allocator or guidance fields fail closed"
	)
	var corrupted: Array = summaries.duplicate(true)
	(corrupted[3] as Dictionary)["mean_normal_load_n"] = 10.0
	var corrupted_result := AnalyzerScript.analyze(built["config"], corrupted)
	_check(
		(
			not bool(corrupted_result["ok"])
			and (corrupted_result["invalid_reasons"] as Array).has(
				"LOADED_PAD_SHEAR_NORMAL_LOAD_ERROR_EXCEEDED:3"
			)
		),
		"corrupting imposed-load reconstruction invalidates breakaway admission"
	)
	var analysis := AnalyzerScript.analyze(built["config"], summaries)
	_check(
		(
			bool(analysis.get("ok", false))
			and bool(analysis.get("admitted", false))
			and bool(analysis.get("accepted_l1_ratio_envelope_retained", false))
		),
		"complete loaded-shear ramp is admitted inside accepted L1 friction truth"
	)
	if bool(analysis.get("ok", false)):
		var breakaway: Dictionary = analysis["breakaway"]
		print(
			(
				("  bracket=%0.1f-%0.1fN ratio=%0.5f-%0.5f " + "L1=%0.5f-%0.5f")
				% [
					float(breakaway["breakaway_force_lower_n"]),
					float(breakaway["breakaway_force_upper_n"]),
					float(breakaway["empirical_static_ratio_lower"]),
					float(breakaway["empirical_static_ratio_upper"]),
					ACCEPTED_L1_RATIO_LOWER,
					ACCEPTED_L1_RATIO_UPPER,
				]
			)
		)
		_check(
			(
				float(breakaway["breakaway_force_lower_n"]) == 34.0
				and float(breakaway["breakaway_force_upper_n"]) == 36.0
			),
			"loaded pad brackets breakaway at the measured 34-36 N cells"
		)
		_check(
			(
				float(breakaway["empirical_static_ratio_lower"]) <= AUTHORED_FRICTION
				and float(breakaway["empirical_static_ratio_upper"]) >= AUTHORED_FRICTION
			),
			"measured loaded-pad ratio bracket contains authored friction 0.6"
		)
	var exclusions: Array = analysis.get("does_not_establish", [])
	_check(
		(
			exclusions.has("articulated_load_bearing_limb")
			and exclusions.has("standing")
			and exclusions.has("walking")
		),
		"L3.1 result excludes articulated support and locomotion claims"
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
