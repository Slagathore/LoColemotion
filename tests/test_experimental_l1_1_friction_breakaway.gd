extends SceneTree

## Experimental L1.1 live Godot/Jolt friction-sled commissioning.
##
## This file intentionally remains outside test_lab_*.gd so it cannot mutate
## BR1's released 62-test report-v2 inventory. It drives a free, low/wide sled
## with a center-of-mass force once per physics tick, observes real semantic
## contact patches, compares frictionless and finite-friction behavior, and
## brackets finite-friction breakaway across completed force stages.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")
const RigFactoryScript := preload("res://scripts/lab/rig_factory.gd")
const CanonicalizerScript := preload(
	"res://scripts/lab/mechanics/contact_canonicalizer.gd")
const SlipObserverScript := preload(
	"res://scripts/lab/mechanics/contact_slip_observer.gd")
const BreakawayAnalyzerScript := preload(
	"res://scripts/lab/mechanics/friction_breakaway_analyzer.gd")

const PHYSICS_TICKS_PER_SECOND := 60
const SETTLE_TICKS := 90
const STAGE_TICKS := 30
const ANALYSIS_TICKS := 15
const CONTROL_FORCE_N := 8.0
const FINITE_FRICTION := 0.6
const FINITE_FORCE_STAGES_N := [
	0.0,
	8.0,
	16.0,
	20.0,
	22.0,
	24.0,
	26.0,
	28.0,
	32.0,
	40.0,
]
const BREAKAWAY_CONFIG := {
	"minimum_samples_per_stage": ANALYSIS_TICKS,
	"maximum_holding_speed_mps": 0.01,
	"maximum_holding_displacement_m": 0.003,
	"minimum_sliding_speed_mps": 0.05,
	"minimum_sliding_displacement_m": 0.01,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental L1.1 live friction breakaway ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_TICKS_PER_SECOND
	var profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v2")
	_check(bool(profile.get("executable", false)),
		"full_contacts_v2 is executable for the live friction fixture")

	_test_configuration_refusal(profile)
	var frictionless: Dictionary = await _run_single_stage_trial(
		profile, 0.0, CONTROL_FORCE_N, "frictionless_control")
	_check(bool(frictionless.get("ok", false)),
		"frictionless control completed with a full contact observation window")
	if bool(frictionless.get("ok", false)):
		_check(float(frictionless["max_slip_speed_mps"])
				>= float(BREAKAWAY_CONFIG["minimum_sliding_speed_mps"])
			and float(frictionless["tangential_displacement_m"])
				>= float(BREAKAWAY_CONFIG["minimum_sliding_displacement_m"]),
			"8 N produces sustained sliding when both authored frictions are zero")

	var finite_run: Dictionary = await _run_finite_ramp(
		profile, FINITE_FRICTION)
	_check(bool(finite_run.get("ok", false)),
		"finite-friction ramp completed every preregistered load stage")
	if bool(finite_run.get("ok", false)):
		_evaluate_finite_ramp(frictionless, finite_run)

	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_configuration_refusal(profile: Dictionary) -> void:
	print("- fixture refuses hidden supports and invalid material input")
	var unknown_parameter: Dictionary = RigFactoryScript.build(
		&"friction_sled_v1",
		CaptureClockScript.new(),
		profile,
		{},
		{"friction": 0.6, "rotation_rail": true})
	_check(not bool(unknown_parameter.get("ok", true))
		and _has_configuration_error(
			unknown_parameter, "UNSUPPORTED_PARAMETER"),
		"an undeclared rotation rail cannot enter the friction fixture")
	var invalid_friction: Dictionary = RigFactoryScript.build(
		&"friction_sled_v1",
		CaptureClockScript.new(),
		profile,
		{},
		{"friction": 1.1})
	_check(not bool(invalid_friction.get("ok", true))
		and _has_configuration_error(invalid_friction, "FRICTION_INVALID"),
		"friction outside Godot's authored [0, 1] range fails closed")


func _run_single_stage_trial(
		profile: Dictionary,
		friction: float,
		force_n: float,
		stage_id: String) -> Dictionary:
	var clock = CaptureClockScript.new()
	var rig: Dictionary = RigFactoryScript.build(
		&"friction_sled_v1",
		clock,
		profile,
		{},
		{"friction": friction})
	if not bool(rig.get("ok", false)):
		return {"ok": false, "rig": rig}
	var contract: Dictionary = rig["force_application_contract"]
	var material: Dictionary = rig["material_contract"]
	_check(String(contract["method"]) == "RigidBody3D.apply_central_force"
		and String(contract["application_point"]) == "center_of_mass"
		and not bool(contract["hidden_rotation_constraint"])
		and not bool(contract["hidden_damping"]),
		"sled force path declares no rail, rotation lock, or hidden damping")
	_check(String(material["godot_pair_rule"])
			== "minimum_friction_both_nonrough_v1"
		and not bool(material["body_rough"])
		and not bool(material["floor_rough"]),
		"both surfaces pin Godot's non-rough minimum-friction combine rule")

	var world := rig["world"] as Node3D
	root.add_child(world)
	var next_step := await _settle(rig, clock, 0)
	var sampled: Dictionary = await _sample_stage(
		rig, clock, next_step, stage_id, force_n)
	world.queue_free()
	await process_frame
	return {
		"ok": bool(sampled.get("complete", false)),
		"stage": sampled["summary"],
		"max_slip_speed_mps": float(
			sampled["summary"]["max_slip_speed_mps"]),
		"tangential_displacement_m": float(
			sampled["summary"]["tangential_displacement_m"]),
	}


func _run_finite_ramp(
		profile: Dictionary,
		friction: float) -> Dictionary:
	print("- finite-friction sled holds, breaks away, and slides under a force ramp")
	var clock = CaptureClockScript.new()
	var rig: Dictionary = RigFactoryScript.build(
		&"friction_sled_v1",
		clock,
		profile,
		{},
		{"friction": friction})
	if not bool(rig.get("ok", false)):
		return {"ok": false, "rig": rig}
	var world := rig["world"] as Node3D
	root.add_child(world)
	var next_step := await _settle(rig, clock, 0)
	var summaries: Array = []
	var complete := true
	for stage_index in FINITE_FORCE_STAGES_N.size():
		var force_n := float(FINITE_FORCE_STAGES_N[stage_index])
		var sampled: Dictionary = await _sample_stage(
			rig,
			clock,
			next_step,
			"load_%02dN" % int(force_n),
			force_n)
		next_step = int(sampled["next_step"])
		complete = bool(sampled.get("complete", false)) and complete
		summaries.append(sampled["summary"])
	var final_position := (rig["body"] as RigidBody3D).global_position
	world.queue_free()
	await process_frame
	return {
		"ok": complete,
		"rig_contract": {
			"body_mass_kg": float(rig["body_mass_kg"]),
			"body_size_m": rig["body_size_m"],
			"material_contract": rig["material_contract"],
			"contact_cap_per_body": int(rig["contact_cap_per_body"]),
		},
		"stage_summaries": summaries,
		"final_position_world_m": final_position,
	}


func _settle(rig: Dictionary, clock, start_step: int) -> int:
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	var body = rig["body"]
	for offset in SETTLE_TICKS:
		var step_id := start_step + offset
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()
	# Settling itself is not a load stage, but it must end with complete contact
	# before any friction conclusion is eligible.
	var canonical := _canonical_frame(rig, body, start_step + SETTLE_TICKS - 1)
	_check(bool(canonical.get("ok", false))
		and int(canonical.get("canonical_patch_count", 0)) == 1,
		"settling ends on one complete semantic sled-floor contact patch")
	return start_step + SETTLE_TICKS


func _sample_stage(
		rig: Dictionary,
		clock,
		start_step: int,
		stage_id: String,
		force_n: float) -> Dictionary:
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	var body = rig["body"]
	var sample_count := 0
	var valid_sample_count := 0
	var contact_sample_count := 0
	var max_slip_speed := 0.0
	var max_solver_input_slip_speed := 0.0
	var normal_load_sum := 0.0
	var predicted_shear_sum := 0.0
	var opposition_sum := 0.0
	var opposition_count := 0
	var balance_residual_sum := 0.0
	var solver_ratio_sum := 0.0
	var solver_ratio_count := 0
	var first_position := Vector3(INF, INF, INF)
	var last_position := Vector3(INF, INF, INF)
	var max_tilt_rad := 0.0
	var capacity_complete := true
	for local_step in STAGE_TICKS:
		var step_id := start_step + local_step
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback")
		# Godot defines apply_central_force as time-dependent and intended for
		# every physics update. One call here is one declared world-space tick.
		body.apply_central_force(Vector3(force_n, 0.0, 0.0))
		await physics_frame
		clock.close_epoch()
		if local_step < STAGE_TICKS - ANALYSIS_TICKS:
			continue
		sample_count += 1
		var diagnostics: Dictionary = body.latest_contact_v2_diagnostics
		var capacity_observation: Dictionary = diagnostics.get(
			"observation", {})
		capacity_complete = (
			bool(capacity_observation.get("finite", false))
			and not bool(capacity_observation.get("saturated_ever", true))
			and capacity_complete)
		var canonical := _canonical_frame(rig, body, step_id)
		if not bool(canonical.get("ok", false)) \
				or int(canonical.get("canonical_patch_count", 0)) != 1:
			continue
		contact_sample_count += 1
		var patch: Dictionary = canonical["patches"][0]
		var slip: Dictionary = SlipObserverScript.observe(
			patch,
			step_s,
			Vector3(force_n, 0.0, 0.0),
			_post_step_kinematics(body, patch))
		if not bool(slip.get("observation_valid", false)):
			continue
		valid_sample_count += 1
		max_slip_speed = maxf(
			max_slip_speed, float(slip["slip_speed_mps"]))
		max_solver_input_slip_speed = maxf(
			max_solver_input_slip_speed,
			float(slip["solver_input_slip_speed_mps"]))
		normal_load_sum += float(slip["predicted_normal_load_n"])
		predicted_shear_sum += float(
			slip["predicted_tangential_load_n"])
		var opposition: Variant = slip[
			"contact_opposes_applied_shear_cosine"]
		if opposition != null:
			opposition_sum += float(opposition)
			opposition_count += 1
		var residual: Vector3 = slip[
			"predicted_tangential_force_balance_residual_world_n"]
		balance_residual_sum += residual.length()
		var solver_ratio: Variant = slip["solver_friction_ratio"]
		if solver_ratio != null:
			solver_ratio_sum += float(solver_ratio)
			solver_ratio_count += 1
		var position := _sample_position(body.latest_body_sample)
		if not first_position.is_finite():
			first_position = position
		last_position = position
		max_tilt_rad = maxf(
			max_tilt_rad, _sample_tilt_rad(body.latest_body_sample))
	var displacement := (
		Vector2(
			last_position.x - first_position.x,
			last_position.z - first_position.z).length()
		if first_position.is_finite() and last_position.is_finite()
		else INF)
	var complete := (
		capacity_complete
		and sample_count == ANALYSIS_TICKS
		and valid_sample_count == sample_count
		and contact_sample_count == sample_count
		and displacement < INF)
	var denominator := float(maxi(valid_sample_count, 1))
	var summary := {
		"stage_id": stage_id,
		"applied_shear_force_n": force_n,
		"sample_count": sample_count,
		"valid_sample_count": valid_sample_count,
		"contact_sample_count": contact_sample_count,
		"max_slip_speed_mps": max_slip_speed,
		"max_solver_input_slip_speed_mps": max_solver_input_slip_speed,
		"tangential_displacement_m": displacement,
		"mean_normal_load_n": normal_load_sum / denominator,
		"mean_predicted_contact_shear_n": predicted_shear_sum / denominator,
		"mean_contact_opposition_cosine": (
			opposition_sum / float(opposition_count)
			if opposition_count > 0 else null),
		"mean_tangential_force_balance_residual_n": (
			balance_residual_sum / denominator),
		"mean_solver_friction_ratio": (
			solver_ratio_sum / float(solver_ratio_count)
			if solver_ratio_count > 0 else null),
		"max_body_tilt_rad": max_tilt_rad,
		"capacity_complete": capacity_complete,
	}
	print(("  stage=%s force=%.1fN valid=%d/%d slip(post/solver)="
			+ "%.5f/%.5fm/s "
			+ "dx=%.5fm normal=%.3fN shear=%.3fN tilt=%.3fdeg") % [
		stage_id,
		force_n,
		valid_sample_count,
		sample_count,
		max_slip_speed,
		max_solver_input_slip_speed,
		displacement,
		float(summary["mean_normal_load_n"]),
		float(summary["mean_predicted_contact_shear_n"]),
		rad_to_deg(max_tilt_rad),
	])
	return {
		"complete": complete,
		"summary": summary,
		"next_step": start_step + STAGE_TICKS,
	}


func _evaluate_finite_ramp(
		frictionless: Dictionary,
		finite_run: Dictionary) -> void:
	var built: Dictionary = BreakawayAnalyzerScript.build_config(
		BREAKAWAY_CONFIG)
	_check(bool(built.get("ok", false)),
		"live staged-breakaway thresholds form a valid hysteretic contract")
	if not bool(built.get("ok", false)):
		return
	var analysis: Dictionary = BreakawayAnalyzerScript.analyze(
		built["config"], finite_run["stage_summaries"])
	_check(bool(analysis.get("ok", false))
		and bool(analysis.get("breakaway_detected", false)),
		"real Jolt run brackets one monotonic static-to-sliding transition")
	if not bool(analysis.get("ok", false)):
		printerr("  breakaway_analysis=", analysis)
		return
	print("  breakaway=[%.3f, %.3f]N ratio=[%.5f, %.5f] held=%s sliding=%s" % [
		float(analysis["breakaway_force_lower_n"]),
		float(analysis["breakaway_force_upper_n"]),
		float(analysis["empirical_static_ratio_lower"]),
		float(analysis["empirical_static_ratio_upper"]),
		String(analysis["last_held_stage_id"]),
		String(analysis["first_sliding_stage_id"]),
	])
	var stages: Array = analysis["classified_stages"]
	var finite_eight := _stage_by_id(stages, "load_08N")
	_check(not finite_eight.is_empty()
		and String(finite_eight["classification"])
			== BreakawayAnalyzerScript.HELD
		and float(frictionless.get("max_slip_speed_mps", 0.0))
			> float(finite_eight["max_slip_speed_mps"]),
		"same 8 N shear slides at friction 0.0 but holds at friction 0.6")
	var lower := float(analysis["breakaway_force_lower_n"])
	var upper := float(analysis["breakaway_force_upper_n"])
	_check(lower >= 16.0 and upper <= 32.0 and upper - lower <= 8.0,
		"measured breakaway lies in the preregistered finite-force search band "
			+ "with width at most 8 N")
	_check(float(analysis["empirical_static_ratio_lower"])
			< float(analysis["empirical_static_ratio_upper"])
		and float(analysis["empirical_static_ratio_lower"]) > 0.25
		and float(analysis["empirical_static_ratio_upper"]) < 0.9,
		"empirical shear/normal bracket is ordered and physically bounded")
	_check(float(finite_eight.get("mean_contact_opposition_cosine", -1.0))
			> 0.95,
		"held contact's predicted tangential impulse opposes applied shear")
	_check(float(finite_eight[
		"mean_tangential_force_balance_residual_n"]) <= 1.0,
		"held 8 N stage closes predicted tangential balance within 1 N")
	_check(float(finite_eight["max_slip_speed_mps"]) <= 0.01
		and float(finite_eight["max_solver_input_slip_speed_mps"]) > 0.02,
		"post-step kinematics correctly reject pre-constraint velocity as slip")
	var upper_stage := _stage_by_id(
		stages, String(analysis["first_sliding_stage_id"]))
	_check(not upper_stage.is_empty()
		and float(upper_stage["max_body_tilt_rad"]) < deg_to_rad(5.0),
		"breakaway occurs before a five-degree tip contaminates the sled result")
	_check((analysis["does_not_establish"] as Array).has("walking")
		and (analysis["does_not_establish"] as Array).has("bracing"),
		"live L1.1 result explicitly excludes bracing and walking")


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


static func _sample_position(body_sample: Dictionary) -> Vector3:
	var transform_value: Variant = body_sample.get("transform")
	if not transform_value is Dictionary:
		return Vector3(INF, INF, INF)
	var origin_value: Variant = (transform_value as Dictionary).get("origin")
	if not origin_value is Array or (origin_value as Array).size() != 3:
		return Vector3(INF, INF, INF)
	return Vector3(
		float(origin_value[0]),
		float(origin_value[1]),
		float(origin_value[2]))


static func _sample_tilt_rad(body_sample: Dictionary) -> float:
	var transform_value: Variant = body_sample.get("transform")
	if not transform_value is Dictionary:
		return INF
	var basis_value: Variant = (transform_value as Dictionary).get("basis")
	if not basis_value is Array or (basis_value as Array).size() != 3:
		return INF
	var y_value: Variant = (basis_value as Array)[1]
	if not y_value is Array or (y_value as Array).size() != 3:
		return INF
	var local_up := Vector3(
		float(y_value[0]), float(y_value[1]), float(y_value[2]))
	if not local_up.is_finite() or local_up.length_squared() <= 1.0e-8:
		return INF
	return acos(clampf(local_up.normalized().dot(Vector3.UP), -1.0, 1.0))


static func _post_step_kinematics(
		body: RigidBody3D,
		patch: Dictionary) -> Dictionary:
	# This fixture's counterparty is a StaticBody3D, so its post-step point
	# velocity is exactly zero. Future moving-ground fixtures must sample and
	# supply the counterparty velocity rather than inheriting this oracle.
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


static func _stage_by_id(stages: Array, stage_id: String) -> Dictionary:
	for stage_value in stages:
		var stage: Dictionary = stage_value
		if String(stage.get("stage_id", "")) == stage_id:
			return stage
	return {}


static func _has_configuration_error(result: Dictionary, code: String) -> bool:
	for error_value in result.get("configuration_errors", []):
		var error: Dictionary = error_value
		if String(error.get("code", "")) == code:
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
