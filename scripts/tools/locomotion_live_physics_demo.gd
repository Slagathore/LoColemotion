extends SceneTree
# gdlint: disable=function-arguments-number
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Repeatable, non-authoritative visual physics sandbox for the workbench.
##
## It reuses the repository's real quadruped fixture and controller. It does
## not invoke a campaign supervisor, create retained evidence, select a policy,
## or claim to reproduce an unconsumed frozen candidate.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const CameraControlsScript := preload("res://scripts/tools/locomotion_live_physics_camera.gd")

const CONFIG_SCHEMA := "sporespore_workbench_live_physics_configuration_v1"
const SOLVER_POLICY_ID := "jolt_120hz_20v_7p_v1"
const MAXIMUM_ROUGHNESS_M := 0.025
const MAXIMUM_PUSH_IMPULSE_N_S := 0.40

var _configuration: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var validate_only := arguments.has("--validate-only")
	var config_path := ""
	for argument_value in arguments:
		var argument := String(argument_value)
		if not argument.begins_with("--"):
			config_path = argument
	if config_path.is_empty():
		_fail("LIVE_PHYSICS_CONFIGURATION_PATH_MISSING")
		return
	var loaded := _load_configuration(config_path)
	if not bool(loaded.get("ok", false)):
		_fail(String(loaded.get("failure_code", "LIVE_PHYSICS_CONFIGURATION_INVALID")))
		return
	_configuration = loaded["configuration"]
	var prepared := _prepare_configuration(_configuration)
	if not bool(prepared.get("ok", false)):
		_fail(String(prepared.get("failure_code", "LIVE_PHYSICS_PREPARATION_FAILED")))
		return

	# BW22L and the current accepted Jolt lineage use this isolated solver policy.
	# The setting is scoped to this child Godot process and never saved.
	ProjectSettings.set_setting("physics/3d/physics_engine", "Jolt Physics")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)

	if validate_only:
		var preflight := await _execute_walker(prepared, false, true)
		var passed := (
			bool(preflight.get("ok", false))
			and int(preflight.get("actual_world_build_count", -1)) == 0
			and int(preflight.get("scene_tree_insertion_count", -1)) == 0
			and not bool(preflight.get("physics_state_modified", true))
		)
		print(
			(
				"LOCOMOTION_LIVE_PHYSICS_PREFLIGHT_%s worlds=0 fixture=%s solver=%s failure=%s"
				% [
					"PASS" if passed else "FAIL",
					String(preflight.get("fixture_spec_sha256", "missing")),
					SOLVER_POLICY_ID,
					String(preflight.get("failure_code", "")),
				]
			)
		)
		quit(0 if passed else 1)
		return

	call_deferred("_decorate_live_world")
	var result := await _execute_walker(prepared, true, false)
	var execution_complete := (
		int(result.get("world_build_count", 0)) == 1
		and int(result.get("executed_ticks", 0)) > 0
		and String(result.get("physics_engine", "")) == "Jolt Physics"
	)
	var outcome := (
		"positive" if bool(result.get("physical_wave_gait_walking_observed", false)) else "negative"
	)
	var failed_gates := _failed_walking_gates(result)
	print(
		(
			"LOCOMOTION_LIVE_PHYSICS_COMPLETE execution=%s outcome=%s walking=%s displacement=%s failed_gates=%s authority=false"
			% [
				str(execution_complete),
				outcome,
				str(result.get("physical_wave_gait_walking_observed", false)),
				str(result.get("final_torso_displacement_world_m", Vector3.ZERO)),
				str(failed_gates),
			]
		)
	)
	_show_completion(result, execution_complete, outcome, failed_gates)
	await create_timer(12.0).timeout
	quit(0 if execution_complete else 1)


func _execute_walker(prepared: Dictionary, visible: bool, preflight: bool) -> Dictionary:
	return await (
		WaveGaitScript
		. new()
		. run(
			self,
			-1.0,
			10.0,
			1.75,
			"lateral",
			72,
			0.40,
			"all",
			112,
			visible,
			prepared["initial_perturbation"],
			{},
			prepared["fixture_spec"],
			{},
			{},
			{},
			{},
			{},
			{
				"solver_policy_id": SOLVER_POLICY_ID,
				"physics_engine": "Jolt Physics",
				"physics_hz": 120,
				"solver_velocity_steps": 20,
				"solver_position_steps": 7,
			},
			{},
			{},
			{},
			prepared["environment_challenge_options"],
			{},
			preflight,
		)
	)


func _load_configuration(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "failure_code": "LIVE_PHYSICS_CONFIGURATION_MISSING"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "failure_code": "LIVE_PHYSICS_CONFIGURATION_UNREADABLE"}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "failure_code": "LIVE_PHYSICS_CONFIGURATION_NOT_OBJECT"}
	var envelope := parsed as Dictionary
	if String(envelope.get("schema_version", "")) != CONFIG_SCHEMA:
		return {"ok": false, "failure_code": "LIVE_PHYSICS_CONFIGURATION_SCHEMA_MISMATCH"}
	var values: Variant = envelope.get("values", {})
	if not values is Dictionary:
		return {"ok": false, "failure_code": "LIVE_PHYSICS_VALUES_NOT_OBJECT"}
	return {"ok": true, "configuration": (values as Dictionary).duplicate(true)}


func _prepare_configuration(values: Dictionary) -> Dictionary:
	if int(values.get("limb_count", -1)) != 4:
		return {"ok": false, "failure_code": "LIVE_PHYSICS_REQUIRES_QUADRUPED"}
	if String(values.get("locomotion_mode", "")) != "balanced_wave_walk":
		return {"ok": false, "failure_code": "LIVE_PHYSICS_REQUIRES_BALANCED_WAVE_WALK"}
	if absf(float(values.get("slope_degrees", 0.0))) > 0.000001:
		return {"ok": false, "failure_code": "LIVE_PHYSICS_SLOPE_NOT_IMPLEMENTED"}
	if float(values.get("obstacle_height_m", 0.0)) > 0.000001:
		return {"ok": false, "failure_code": "LIVE_PHYSICS_OBSTACLE_NOT_IMPLEMENTED"}
	if bool(values.get("sensor_noise_enabled", false)):
		return {"ok": false, "failure_code": "LIVE_PHYSICS_SENSOR_NOISE_NOT_IMPLEMENTED"}
	if bool(values.get("sensor_latency_enabled", false)):
		return {"ok": false, "failure_code": "LIVE_PHYSICS_SENSOR_LATENCY_NOT_IMPLEMENTED"}
	if int(values.get("physics_hz", 0)) != 120:
		return {"ok": false, "failure_code": "LIVE_PHYSICS_REQUIRES_120_HZ"}

	var terrain_kind := String(values.get("terrain_kind", "flat"))
	if not ["flat", "rough"].has(terrain_kind):
		return {"ok": false, "failure_code": "LIVE_PHYSICS_TERRAIN_NOT_IMPLEMENTED"}
	var roughness := float(values.get("terrain_roughness", 0.0))
	if roughness < 0.0 or roughness > MAXIMUM_ROUGHNESS_M:
		return {"ok": false, "failure_code": "LIVE_PHYSICS_ROUGHNESS_OUT_OF_BOUNDS"}
	var push_impulse := float(values.get("push_impulse_ns", 0.0))
	if (
		bool(values.get("external_push_enabled", false))
		and (push_impulse <= 0.0 or push_impulse > MAXIMUM_PUSH_IMPULSE_N_S)
	):
		return {"ok": false, "failure_code": "LIVE_PHYSICS_PUSH_OUT_OF_BOUNDS"}

	var fixture := FixtureSpecScript.reference_spec()
	var torso: Dictionary = fixture["torso"]
	var reference_torso_size: Array = torso["size_m"]
	var length_scale := float(values.get("torso_length_scale", 1.0))
	var width_scale := float(values.get("torso_width_scale", 1.0))
	var hip_span_scale := float(values.get("hip_span_scale", 1.0))
	var upper_fraction := float(values.get("upper_length_fraction", 18.0 / 35.0))
	var foot_radius_scale := float(values.get("foot_radius_scale", 1.0))
	var front_mass_scale := float(values.get("front_limb_mass_scale", 1.0))
	if (
		length_scale <= 0.0
		or width_scale <= 0.0
		or hip_span_scale <= 0.0
		or upper_fraction <= 0.0
		or upper_fraction >= 1.0
		or foot_radius_scale <= 0.0
		or front_mass_scale <= 0.0
	):
		return {"ok": false, "failure_code": "LIVE_PHYSICS_MORPHOLOGY_OUT_OF_BOUNDS"}
	torso["size_m"] = [
		float(reference_torso_size[0]) * length_scale,
		float(reference_torso_size[1]),
		float(reference_torso_size[2]) * width_scale,
	]
	var reference_foot_radius := 0.05
	torso["initial_center_m"][1] = (
		float(torso["initial_center_m"][1]) + reference_foot_radius * (foot_radius_scale - 1.0)
	)
	for limb_value in fixture["limbs"]:
		var limb: Dictionary = limb_value
		var hip: Array = limb["hip_offset_from_torso_center_m"]
		hip[0] = float(hip[0]) * length_scale
		hip[2] = float(hip[2]) * width_scale * hip_span_scale
		var total_leg_length := float(limb["upper_length_m"]) + float(limb["lower_length_m"])
		limb["upper_length_m"] = total_leg_length * upper_fraction
		limb["lower_length_m"] = total_leg_length * (1.0 - upper_fraction)
		limb["foot_radius_m"] = float(limb["foot_radius_m"]) * foot_radius_scale
		if String(limb["limb_id"]).begins_with("front_"):
			limb["upper_mass_kg"] = float(limb["upper_mass_kg"]) * front_mass_scale
			limb["distal_mass_kg"] = float(limb["distal_mass_kg"]) * front_mass_scale
	fixture["contact_material"]["friction"] = float(values.get("authored_friction", 1.8))
	var compiled_fixture := FixtureSpecScript.compile(fixture)
	if not bool(compiled_fixture.get("ok", false)):
		return {
			"ok": false,
			"failure_code":
			(
				"LIVE_PHYSICS_FIXTURE_INVALID:%s"
				% String(compiled_fixture.get("failure_code", "unknown"))
			),
		}

	var seeded := WaveGaitScript.compile_seeded_initial_perturbation(
		int(values.get("random_seed", 1))
	)
	if not bool(seeded.get("ok", false)):
		return seeded
	var environment := _environment_options(values)
	var compiled_environment := WaveGaitScript.compile_environment_challenge_options(environment)
	if not bool(compiled_environment.get("ok", false)):
		return compiled_environment
	return {
		"ok": true,
		"fixture_spec": compiled_fixture["fixture_spec"],
		"initial_perturbation": seeded["initial_perturbation"],
		"environment_challenge_options": compiled_environment["environment_challenge_options"],
	}


func _environment_options(values: Dictionary) -> Dictionary:
	var terrain_kind := String(values.get("terrain_kind", "flat"))
	var roughness := float(values.get("terrain_roughness", 0.0))
	var terrain_heights: Array = [0.0]
	var tile_count := 1
	var tile_length := 20.0
	var terrain_origin := -10.0
	if terrain_kind == "rough":
		var rng := RandomNumberGenerator.new()
		rng.seed = int(values.get("terrain_seed", 1))
		terrain_heights = []
		for _index in 16:
			terrain_heights.append(rng.randf_range(-roughness, roughness))
		tile_count = 64
		tile_length = 0.125
		terrain_origin = -2.0
	var push_enabled := bool(values.get("external_push_enabled", false))
	var push_impulse := float(values.get("push_impulse_ns", 0.0))
	return {
		"challenge_profile_id": "workbench_live_sandbox_v1",
		"terrain_profile_id": "rough_height_strip_v1" if terrain_kind == "rough" else "flat_v1",
		"terrain_tile_length_m": tile_length,
		"terrain_tile_count": tile_count,
		"terrain_origin_x_m": terrain_origin,
		"terrain_heights_m": terrain_heights,
		"push_profile_id": "lateral_impulse_v1" if push_enabled else "none",
		"push_step_from_sdk_start": 360 if push_enabled else -1,
		"push_impulse_task_n_s": [0.0, 0.0, push_impulse if push_enabled else 0.0],
		"observation_fault_profile_id": "none",
		"observation_noise_period_steps": 120,
		"base_position_noise_amplitude_m": 0.0,
		"base_linear_velocity_noise_amplitude_m_s": 0.0,
		"joint_position_noise_amplitude_rad": 0.0,
		"joint_velocity_noise_amplitude_rad_s": 0.0,
		"stability_body_position_noise_amplitude_m": 0.0,
		"stability_body_velocity_noise_amplitude_m_s": 0.0,
		"support_point_noise_amplitude_m": 0.0,
	}


func _decorate_live_world() -> void:
	var demo: Node = null
	for _frame in 240:
		demo = root.find_child("PhysicalWaveGaitQuadrupedDemo", true, false)
		if demo != null:
			break
		await process_frame
	if demo == null:
		return
	var boundary_label := demo.find_child("EvidenceBoundaryLabel", true, false) as Label
	if boundary_label != null:
		boundary_label.text = (
			"SporeSpore real-physics workbench sandbox\n"
			+ "Same physical walker architecture • repeatable development run\n"
			+ "Not the closed BW22L A/B campaign • not retained evidence • claims=false"
		)
	var camera := demo.find_child("DemoCamera", true, false) as Camera3D
	var torso := demo.find_child("wave_gait_torso", true, false) as RigidBody3D
	if camera != null and torso != null:
		var controls := CameraControlsScript.new()
		controls.name = "LivePhysicsCameraAndDiagnostics"
		demo.add_child(controls)
		controls.configure(camera, torso, _configuration)


func _show_completion(
	result: Dictionary,
	execution_complete: bool,
	outcome: String,
	failed_gates: Array[String],
) -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("0b1020")
	root.add_child(background)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-430.0, -180.0)
	panel.custom_minimum_size = Vector2(860.0, 360.0)
	background.add_child(panel)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override(
		"font_color", Color("55c99a") if execution_complete else Color("fb7185")
	)
	label.text = (
		"REAL-PHYSICS SANDBOX COMPLETE\n\n"
		+ (
			"Execution: %s    Development outcome: %s\n"
			% [
				"complete" if execution_complete else "infrastructure failure",
				outcome,
			]
		)
		+ (
			"Walking predicate: %s    Steps: %d    Worlds: %d\n"
			% [
				str(result.get("physical_wave_gait_walking_observed", false)),
				int(result.get("executed_ticks", 0)),
				int(result.get("world_build_count", 0)),
			]
		)
		+ (
			"Final displacement: %s\n\n"
			% str(result.get("final_torso_displacement_world_m", Vector3.ZERO))
		)
		+ (
			"Failed walking gates: %s\n\n"
			% ("none" if failed_gates.is_empty() else ", ".join(failed_gates))
		)
		+ "A negative outcome is still useful diagnostic evidence inside this session, "
		+ "but this sandbox is not retained scientific evidence and grants no claim authority.\n"
		+ "This window will close automatically."
	)
	panel.add_child(label)


func _failed_walking_gates(result: Dictionary) -> Array[String]:
	var failed: Array[String] = []
	var receipts: Dictionary = result.get("walking_gate_receipts", {})
	for gate_value in receipts.keys():
		var gate := String(gate_value)
		if not bool(receipts[gate]):
			failed.append(gate)
	failed.sort()
	return failed


func _fail(code: String) -> void:
	printerr("LOCOMOTION_LIVE_PHYSICS_ERROR %s" % code)
	quit(1)
