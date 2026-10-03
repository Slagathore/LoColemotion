extends SceneTree

## Prospective P5M isolated characterization of Candidate 35's legacy
## Godot/Jolt material. This is a force-driven sled, never a gait.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload("res://scripts/lab/observer_profile.gd")
const RigScript := preload("res://scripts/lab/rigs/sdk_legacy_material_sled_rig.gd")
const CanonicalizerScript := preload(
	"res://scripts/lab/mechanics/contact_canonicalizer.gd"
)
const SlipObserverScript := preload(
	"res://scripts/lab/mechanics/contact_slip_observer.gd"
)
const BreakawayAnalyzerScript := preload(
	"res://scripts/lab/mechanics/friction_breakaway_analyzer.gd"
)

const RECEIPT_SCHEMA_VERSION := "sporespore_godot_jolt_legacy_material_receipt_v1"
const PHYSICS_TICKS_PER_SECOND := 120
const SOLVER_VELOCITY_STEPS := 20
const SOLVER_POSITION_STEPS := 7
const SETTLE_TICKS := 180
const STAGE_TICKS := 60
const ANALYSIS_TICKS := 30
const FRICTIONLESS_FORCE_N := 20.0
const FORCE_STAGES_N := [
	0.0,
	20.0,
	40.0,
	50.0,
	55.0,
	60.0,
	65.0,
	68.0,
	70.0,
	72.0,
	75.0,
	80.0,
	90.0,
	110.0,
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
	print("\n=== SDK Godot/Jolt legacy-material characterization ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_TICKS_PER_SECOND
	ProjectSettings.set_setting(
		"physics/jolt_physics_3d/simulation/velocity_steps",
		SOLVER_VELOCITY_STEPS,
	)
	ProjectSettings.set_setting(
		"physics/jolt_physics_3d/simulation/position_steps",
		SOLVER_POSITION_STEPS,
	)
	var engine_receipt := {
		"physics_engine": String(
			ProjectSettings.get_setting("physics/3d/physics_engine", "")
		),
		"physics_hz": Engine.physics_ticks_per_second,
		"solver_velocity_steps":
		int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/velocity_steps",
				-1,
			)
		),
		"solver_position_steps":
		int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/position_steps",
				-1,
			)
		),
	}
	_check(
		String(engine_receipt["physics_engine"]) == "Jolt Physics"
		and int(engine_receipt["physics_hz"]) == PHYSICS_TICKS_PER_SECOND
		and int(engine_receipt["solver_velocity_steps"]) == SOLVER_VELOCITY_STEPS
		and int(engine_receipt["solver_position_steps"]) == SOLVER_POSITION_STEPS,
		"the realized engine receipt is exactly Jolt 120 Hz with 20/7 solver steps",
	)
	var profile: Dictionary = ObserverProfileScript.resolve(&"full_contacts_v2")
	_check(
		bool(profile.get("executable", false)),
		"the full contact observer is executable",
	)
	var invalid := RigScript.build(CaptureClockScript.new(), profile, 0.6)
	_check(
		not bool(invalid.get("ok", true))
		and _has_configuration_error(invalid, "SDK_LEGACY_FRICTION_PROFILE_INVALID"),
		"the fixture rejects every material except the frozen legacy pair and A/B control",
	)

	var frictionless := await _run_frictionless(profile)
	_check(
		bool(frictionless.get("ok", false))
		and String(frictionless.get("classification", "")) == BreakawayAnalyzerScript.SLIDING,
		"the 0.0-friction A/B world slides under 20 N",
	)

	var replicates: Array[Dictionary] = []
	for replicate_index in range(3):
		var replicate := await _run_legacy_ramp(profile, replicate_index + 1)
		replicates.append(replicate)
		_check(
			bool(replicate.get("ok", false)),
			"legacy-material replicate %d completes its frozen bracket"
			% (replicate_index + 1),
		)
		var stage_20: Dictionary = _stage_by_id(
			replicate.get("classified_stages", []),
			"load_020N",
		)
		_check(
			not stage_20.is_empty()
			and String(stage_20.get("classification", ""))
			== BreakawayAnalyzerScript.HELD,
			"legacy-material replicate %d holds the same 20 N A/B force"
			% (replicate_index + 1),
		)

	var coefficient_result := _derive_controller_coefficient(replicates)
	_check(
		bool(coefficient_result.get("ok", false))
		and float(coefficient_result.get("controller_mu", 0.0)) >= 0.50
		and float(coefficient_result.get("controller_mu", INF)) <= 1.0,
		"the frozen conservative controller coefficient rule yields [0.50, 1.00]",
	)

	var receipt := {
		"schema_version": RECEIPT_SCHEMA_VERSION,
		"ok": _failed == 0,
		"engine": engine_receipt,
		"fixture":
		{
			"fixture_id": RigScript.FIXTURE_ID,
			"legacy_friction": RigScript.LEGACY_FRICTION,
			"frictionless_control": RigScript.FRICTIONLESS_CONTROL,
			"floor_size_m": _vector(RigScript.FLOOR_SIZE_M),
			"settle_ticks": SETTLE_TICKS,
			"stage_ticks": STAGE_TICKS,
			"analysis_ticks": ANALYSIS_TICKS,
			"force_stages_n": FORCE_STAGES_N.duplicate(),
			"force_application": "RigidBody3D.apply_central_force_once_per_tick",
			"hidden_rotation_constraint": false,
			"hidden_damping": false,
		},
		"breakaway_config": BREAKAWAY_CONFIG.duplicate(true),
		"frictionless_control": frictionless,
		"legacy_material_replicates": replicates,
		"coefficient_derivation": coefficient_result,
		"adapter_actuation_applied": false,
		"physics_transform_or_velocity_written": false,
		"physical_balance_recovery": false,
		"walking": false,
		"friction_material_locomotion_robustness": false,
		"cross_engine_authority": false,
		"physical_acceptance_authority": false,
		"completed_engine_neutral_sdk": false,
	}
	print(
		"SDK_LEGACY_MATERIAL_RECEIPT ",
		JSON.stringify(receipt, "", true, true),
	)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _run_frictionless(profile: Dictionary) -> Dictionary:
	var clock = CaptureClockScript.new()
	var rig: Dictionary = RigScript.build(
		clock,
		profile,
		RigScript.FRICTIONLESS_CONTROL,
	)
	if not bool(rig.get("ok", false)) or not _material_contract_exact(rig, 0.0):
		return {
			"ok": false,
			"failure_code": "FRICTIONLESS_FIXTURE_INVALID",
			"rig": rig,
		}
	var world := rig["world"] as Node3D
	root.add_child(world)
	var next_step := await _settle(rig, clock, 0)
	var stage := await _sample_stage(
		rig,
		clock,
		next_step,
		"frictionless_020N",
		FRICTIONLESS_FORCE_N,
	)
	world.queue_free()
	await process_frame
	var summary: Dictionary = stage.get("summary", {})
	return {
		"ok": bool(stage.get("complete", false)),
		"classification": _classify(summary),
		"material_contract": rig["material_contract"],
		"stage": summary,
	}


func _run_legacy_ramp(profile: Dictionary, replicate_index: int) -> Dictionary:
	var clock = CaptureClockScript.new()
	var rig: Dictionary = RigScript.build(
		clock,
		profile,
		RigScript.LEGACY_FRICTION,
	)
	if (
		not bool(rig.get("ok", false))
		or not _material_contract_exact(rig, RigScript.LEGACY_FRICTION)
	):
		return {
			"ok": false,
			"failure_code": "LEGACY_FIXTURE_INVALID",
			"replicate_index": replicate_index,
			"rig": rig,
		}
	var world := rig["world"] as Node3D
	root.add_child(world)
	var next_step := await _settle(rig, clock, 0)
	var stages: Array = []
	var complete := true
	for force_value in FORCE_STAGES_N:
		var force_n := float(force_value)
		var sampled := await _sample_stage(
			rig,
			clock,
			next_step,
			"load_%03dN" % int(force_n),
			force_n,
		)
		next_step = int(sampled.get("next_step", next_step))
		complete = complete and bool(sampled.get("complete", false))
		stages.append(sampled.get("summary", {}))
	world.queue_free()
	await process_frame

	var built := BreakawayAnalyzerScript.build_config(BREAKAWAY_CONFIG)
	if not bool(built.get("ok", false)):
		return {
			"ok": false,
			"failure_code": "BREAKAWAY_CONFIG_INVALID",
			"replicate_index": replicate_index,
			"stage_summaries": stages,
		}
	var analysis: Dictionary = BreakawayAnalyzerScript.analyze(
		built["config"],
		stages,
	)
	var first_sliding := _stage_by_id(
		analysis.get("classified_stages", []),
		String(analysis.get("first_sliding_stage_id", "")),
	)
	var lower_force := float(analysis.get("breakaway_force_lower_n", NAN))
	var upper_force := float(analysis.get("breakaway_force_upper_n", NAN))
	var lower_ratio := float(analysis.get("empirical_static_ratio_lower", NAN))
	var upper_ratio := float(analysis.get("empirical_static_ratio_upper", NAN))
	var acceptance := (
		complete
		and bool(analysis.get("ok", false))
		and bool(analysis.get("breakaway_detected", false))
		and is_finite(lower_force)
		and is_finite(upper_force)
		and lower_force >= 40.0
		and upper_force <= 110.0
		and upper_force - lower_force <= 12.0
		and is_finite(lower_ratio)
		and is_finite(upper_ratio)
		and lower_ratio >= 0.50
		and upper_ratio <= 3.00
		and lower_ratio < upper_ratio
		and not first_sliding.is_empty()
		and float(first_sliding.get("max_body_tilt_rad", INF))
		< deg_to_rad(5.0)
	)
	return {
		"ok": acceptance,
		"failure_code": "" if acceptance else "LEGACY_BREAKAWAY_ACCEPTANCE_FAILED",
		"replicate_index": replicate_index,
		"material_contract": rig["material_contract"],
		"contact_cap_per_body": int(rig["contact_cap_per_body"]),
		"breakaway_analysis": analysis,
		"classified_stages": analysis.get("classified_stages", []),
		"breakaway_force_lower_n": lower_force,
		"breakaway_force_upper_n": upper_force,
		"empirical_static_ratio_lower": lower_ratio,
		"empirical_static_ratio_upper": upper_ratio,
		"first_sliding_max_body_tilt_rad":
		float(first_sliding.get("max_body_tilt_rad", INF)),
		"all_stage_observations_complete": complete,
	}


func _settle(rig: Dictionary, clock, start_step: int) -> int:
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	for offset in range(SETTLE_TICKS):
		var step_id := start_step + offset
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback",
		)
		await physics_frame
		clock.close_epoch()
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
	var maximum_slip_speed_mps := 0.0
	var normal_load_sum_n := 0.0
	var first_position := Vector3(INF, INF, INF)
	var last_position := Vector3(INF, INF, INF)
	var maximum_body_tilt_rad := 0.0
	var capacity_complete := true
	for local_step in range(STAGE_TICKS):
		var step_id := start_step + local_step
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback",
		)
		body.apply_central_force(Vector3(force_n, 0.0, 0.0))
		await physics_frame
		clock.close_epoch()
		if local_step < STAGE_TICKS - ANALYSIS_TICKS:
			continue
		sample_count += 1
		var diagnostics: Dictionary = body.latest_contact_v2_diagnostics
		var capacity_observation: Dictionary = diagnostics.get("observation", {})
		capacity_complete = (
			capacity_complete
			and bool(capacity_observation.get("finite", false))
			and not bool(capacity_observation.get("saturated_ever", true))
		)
		var canonical := _canonical_frame(rig, body, step_id)
		if (
			not bool(canonical.get("ok", false))
			or int(canonical.get("canonical_patch_count", 0)) != 1
		):
			continue
		contact_sample_count += 1
		var patch: Dictionary = canonical["patches"][0]
		var slip: Dictionary = SlipObserverScript.observe(
			patch,
			step_s,
			Vector3(force_n, 0.0, 0.0),
			_post_step_kinematics(body, patch),
		)
		if not bool(slip.get("observation_valid", false)):
			continue
		valid_sample_count += 1
		maximum_slip_speed_mps = maxf(
			maximum_slip_speed_mps,
			float(slip["slip_speed_mps"]),
		)
		normal_load_sum_n += float(slip["predicted_normal_load_n"])
		var position := _sample_position(body.latest_body_sample)
		if not first_position.is_finite():
			first_position = position
		last_position = position
		maximum_body_tilt_rad = maxf(
			maximum_body_tilt_rad,
			_sample_tilt_rad(body.latest_body_sample),
		)
	var displacement_m := (
		Vector2(
			last_position.x - first_position.x,
			last_position.z - first_position.z,
		).length()
		if first_position.is_finite() and last_position.is_finite()
		else INF
	)
	var complete := (
		capacity_complete
		and sample_count == ANALYSIS_TICKS
		and valid_sample_count == sample_count
		and contact_sample_count == sample_count
		and is_finite(displacement_m)
	)
	var summary := {
		"stage_id": stage_id,
		"applied_shear_force_n": force_n,
		"sample_count": sample_count,
		"valid_sample_count": valid_sample_count,
		"contact_sample_count": contact_sample_count,
		"max_slip_speed_mps": maximum_slip_speed_mps,
		"tangential_displacement_m": displacement_m,
		"mean_normal_load_n":
		normal_load_sum_n / float(maxi(valid_sample_count, 1)),
		"max_body_tilt_rad": maximum_body_tilt_rad,
		"capacity_complete": capacity_complete,
	}
	print(
		(
			"  %s F=%6.1fN samples=%d/%d slip=%.5fm/s dx=%.5fm "
			+ "normal=%.3fN tilt=%.3fdeg"
		)
		% [
			stage_id,
			force_n,
			valid_sample_count,
			sample_count,
			maximum_slip_speed_mps,
			displacement_m,
			float(summary["mean_normal_load_n"]),
			rad_to_deg(maximum_body_tilt_rad),
		],
	)
	return {
		"complete": complete,
		"summary": summary,
		"next_step": start_step + STAGE_TICKS,
	}


func _derive_controller_coefficient(replicates: Array[Dictionary]) -> Dictionary:
	if replicates.size() != 3:
		return {"ok": false, "failure_code": "REPLICATE_COUNT_INVALID"}
	var minimum_lower_ratio := INF
	for replicate in replicates:
		if not bool(replicate.get("ok", false)):
			return {"ok": false, "failure_code": "REPLICATE_INVALID"}
		minimum_lower_ratio = minf(
			minimum_lower_ratio,
			float(replicate.get("empirical_static_ratio_lower", NAN)),
		)
	if not is_finite(minimum_lower_ratio):
		return {"ok": false, "failure_code": "LOWER_RATIO_INVALID"}
	var controller_mu := minf(1.0, floorf(100.0 * minimum_lower_ratio) / 100.0)
	return {
		"ok": controller_mu >= 0.50,
		"failure_code": "" if controller_mu >= 0.50 else "CONTROLLER_MU_BELOW_MINIMUM",
		"minimum_lower_ratio": minimum_lower_ratio,
		"rounding_rule": "min(1.0,floor(100*minimum_lower_ratio)/100)",
		"documented_godot_maximum_cap": 1.0,
		"controller_mu": controller_mu,
		"cross_engine_portable": false,
		"locomotion_robustness": false,
	}


func _material_contract_exact(rig: Dictionary, expected_friction: float) -> bool:
	var contract: Dictionary = rig.get("material_contract", {})
	for side in ["body", "floor"]:
		var material: Dictionary = contract.get(side, {})
		if (
			absf(float(material.get("friction", NAN)) - expected_friction) > 1.0e-6
			or not bool(material.get("rough", false))
			or absf(float(material.get("bounce", NAN))) > 1.0e-9
			or not bool(material.get("absorbent", false))
		):
			return false
	return (
		String(contract.get("godot_pair_rule", ""))
		== "highest_friction_both_rough_v1"
	)


func _canonical_frame(rig: Dictionary, body, step_id: int) -> Dictionary:
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
		},
	)


static func _post_step_kinematics(
		body: RigidBody3D,
		patch: Dictionary) -> Dictionary:
	return {
		"physics_step_id": int(patch["physics_step_id"]),
		"capture_epoch": int(patch["capture_epoch"]),
		"sample_phase": "post_step",
		"body_linear_velocity_world_mps": body.linear_velocity,
		"body_angular_velocity_world_rad_s": body.angular_velocity,
		"body_center_of_mass_world_m": body.global_transform * body.center_of_mass,
		"counterparty_velocity_world_mps": Vector3.ZERO,
	}


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
		float(origin_value[2]),
	)


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
		float(y_value[0]),
		float(y_value[1]),
		float(y_value[2]),
	)
	if not local_up.is_finite() or local_up.length_squared() <= 1.0e-8:
		return INF
	return acos(clampf(local_up.normalized().dot(Vector3.UP), -1.0, 1.0))


static func _classify(stage: Dictionary) -> String:
	var speed := float(stage.get("max_slip_speed_mps", NAN))
	var displacement := float(stage.get("tangential_displacement_m", NAN))
	if (
		speed <= float(BREAKAWAY_CONFIG["maximum_holding_speed_mps"])
		and displacement
		<= float(BREAKAWAY_CONFIG["maximum_holding_displacement_m"])
	):
		return BreakawayAnalyzerScript.HELD
	if (
		speed >= float(BREAKAWAY_CONFIG["minimum_sliding_speed_mps"])
		and displacement
		>= float(BREAKAWAY_CONFIG["minimum_sliding_displacement_m"])
	):
		return BreakawayAnalyzerScript.SLIDING
	return BreakawayAnalyzerScript.AMBIGUOUS


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


static func _vector(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print(
		"\nSDK Godot/Jolt legacy-material summary: %d passed, %d failed"
		% [_passed, _failed],
	)
	quit(0 if _failed == 0 else 1)
