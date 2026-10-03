extends SceneTree

## Experimental L1.6 Jolt velocity/position solver-step sensitivity.
##
## Godot 4.7 constructs each JoltSpace3D with a snapshot of the current project
## settings. ProjectSettings emits its settings_changed notification on the
## next process boundary, so each cell changes settings, crosses that boundary,
## and only then creates a fresh SubViewport with own_world_3d=true. Skipping
## either part produces a mislabeled, physically shifted sweep.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")
const RigFactoryScript := preload("res://scripts/lab/rig_factory.gd")
const PressureObserverScript := preload(
	"res://scripts/lab/mechanics/contact_pressure_observer.gd")
const ExternalImpulseReconstructorScript := preload(
	"res://scripts/lab/mechanics/external_contact_impulse_reconstructor.gd")
const SolverAnalyzerScript := preload(
	"res://scripts/lab/mechanics/solver_step_sensitivity_analyzer.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const VELOCITY_STEPS_SETTING := (
	"physics/jolt_physics_3d/simulation/velocity_steps")
const POSITION_STEPS_SETTING := (
	"physics/jolt_physics_3d/simulation/position_steps")
const PHYSICS_TICKS_PER_SECOND := 60
const SETTLE_TICKS := 180
const ANALYSIS_TICKS := 60
const SOLVER_CELLS := [
	{"cell_id": "v02_p04", "velocity_steps": 2, "position_steps": 4},
	{"cell_id": "v04_p04", "velocity_steps": 4, "position_steps": 4},
	{"cell_id": "v10_p04", "velocity_steps": 10, "position_steps": 4},
	{"cell_id": "v20_p01", "velocity_steps": 20, "position_steps": 1},
	{"cell_id": "v20_p02", "velocity_steps": 20, "position_steps": 2},
	{"cell_id": "v20_p04", "velocity_steps": 20, "position_steps": 4},
	{"cell_id": "v20_p08", "velocity_steps": 20, "position_steps": 8},
	{"cell_id": "v40_p04", "velocity_steps": 40, "position_steps": 4},
]
const REPEAT_CELL_IDS := ["v02_p04", "v04_p04", "v20_p04"]
const ANALYZER_CONFIGURATION := {
	"required_cells": SOLVER_CELLS,
	"minimum_accepted_cell_count": 5,
	"project_velocity_steps": 20,
	"project_position_steps": 4,
	"maximum_center_height_error_m": 0.025,
	"maximum_pair_penetration_m": 0.006,
	"maximum_floor_penetration_m": 0.005,
	"maximum_linear_speed_mps": 0.06,
	"maximum_angular_speed_rad_s": 0.05,
	"maximum_tilt_rad": deg_to_rad(1.0),
	"maximum_lateral_drift_m": 0.025,
	"maximum_reconstructed_load_error_n": 1.0,
	"maximum_centered_cop_radius_m": 0.005,
	"expected_raw_load_fraction": 0.1,
	"raw_load_fraction_tolerance": 0.03,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental L1.6 solver-step sensitivity ===")
	var original_ticks := Engine.physics_ticks_per_second
	var original_velocity_steps := int(ProjectSettings.get_setting(
		VELOCITY_STEPS_SETTING))
	var original_position_steps := int(ProjectSettings.get_setting(
		POSITION_STEPS_SETTING))
	Engine.physics_ticks_per_second = PHYSICS_TICKS_PER_SECOND
	var profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v2")
	_check(bool(profile.get("executable", false)),
		"full_contacts_v2 is executable for every fresh solver space")
	_test_external_impulse_reconstructor()
	_test_fixture_refusal(profile)
	var summaries: Array = []
	var all_complete := true
	for cell_value in SOLVER_CELLS:
		var cell: Dictionary = cell_value
		var result: Dictionary = await _run_cell(profile, cell)
		all_complete = bool(result.get("complete", false)) and all_complete
		summaries.append(result.get("summary", {}))
	var repeats: Array = []
	for repeat_id_value in REPEAT_CELL_IDS:
		var repeat_cell := _cell_by_id(String(repeat_id_value))
		var repeat_result: Dictionary = await _run_cell(profile, repeat_cell)
		all_complete = bool(repeat_result.get("complete", false)) and all_complete
		repeats.append(repeat_result.get("summary", {}))
	_print_summaries(summaries)
	print("- selected fresh-space repeat controls")
	_print_summaries(repeats)
	_check(all_complete,
		"all eight fresh-space solver cells retain complete finite observations")
	_evaluate_provisional_bounds(summaries)
	_evaluate_repeat_controls(summaries, repeats)
	_evaluate_fail_closed_analyzer(summaries)
	ProjectSettings.set_setting(
		VELOCITY_STEPS_SETTING, original_velocity_steps)
	ProjectSettings.set_setting(
		POSITION_STEPS_SETTING, original_position_steps)
	# Restore the Jolt-side cache too, not merely ProjectSettings' readback.
	await process_frame
	Engine.physics_ticks_per_second = original_ticks
	_check(int(ProjectSettings.get_setting(VELOCITY_STEPS_SETTING))
			== original_velocity_steps
		and int(ProjectSettings.get_setting(POSITION_STEPS_SETTING))
			== original_position_steps,
		"process-local solver settings are restored after the sweep")
	_finish()


func _test_fixture_refusal(profile: Dictionary) -> void:
	var unequal_mass: Dictionary = RigFactoryScript.build(
		&"solver_stack_v1",
		CaptureClockScript.new(),
		profile,
		{"top_mass_kg": 10.0},
		{})
	_check(not bool(unequal_mass.get("ok", true))
		and _has_configuration_error(unequal_mass, "UNSUPPORTED_PARAMETER"),
		"L1.6 refuses mass-ratio contamination reserved for L1.7")


func _test_external_impulse_reconstructor() -> void:
	var before := [
		{"body_id": "a", "mass_kg": 2.0,
			"linear_velocity_world_mps": Vector3.ZERO},
	]
	var after := [
		{"body_id": "a", "mass_kg": 2.0,
			"linear_velocity_world_mps": Vector3.ZERO},
	]
	var result: Dictionary = ExternalImpulseReconstructorScript.reconstruct(
		before,
		after,
		0.1,
		Vector3(0.0, -1.96, 0.0),
		Vector3.UP)
	_check(bool(result.get("reconstruction_valid", false))
		and absf(float(result["reconstructed_step_average_normal_load_n"])
			- 19.6) <= 1.0e-5
		and result["contact_allocation_available"] == false
		and result["center_of_pressure_available"] == false,
		"whole-system momentum balance reconstructs net load without fake allocation")
	var mismatched: Dictionary = ExternalImpulseReconstructorScript.reconstruct(
		before,
		[{"body_id": "b", "mass_kg": 2.0,
			"linear_velocity_world_mps": Vector3.ZERO}],
		0.1,
		Vector3.ZERO,
		Vector3.UP)
	_check(not bool(mismatched["reconstruction_valid"])
		and (mismatched["invalid_reasons"] as Array).has(
			"EXTERNAL_IMPULSE_BODY_SET_MISMATCH"),
		"momentum reconstruction rejects incoherent body identity")


func _run_cell(profile: Dictionary, cell: Dictionary) -> Dictionary:
	var requested_velocity_steps := int(cell["velocity_steps"])
	var requested_position_steps := int(cell["position_steps"])
	ProjectSettings.set_setting(
		VELOCITY_STEPS_SETTING, requested_velocity_steps)
	ProjectSettings.set_setting(
		POSITION_STEPS_SETTING, requested_position_steps)
	# JoltProjectSettings listens to ProjectSettings.settings_changed. The
	# notification is observed at a process boundary; constructing the space
	# before this await makes it snapshot the preceding cell's solver values.
	await process_frame
	var settings_readback_valid := (
		int(ProjectSettings.get_setting(VELOCITY_STEPS_SETTING))
			== requested_velocity_steps
		and int(ProjectSettings.get_setting(POSITION_STEPS_SETTING))
			== requested_position_steps)

	# This object creates the new World3D/JoltSpace3D only after the setting
	# write and its notification boundary. Godot 4.7's JoltSpace3D constructor
	# copies both cached values once.
	var viewport := SubViewport.new()
	viewport.name = "SolverCell_%s" % String(cell["cell_id"])
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var own_world_valid := viewport.own_world_3d \
		and viewport.world_3d != root.world_3d
	var clock = CaptureClockScript.new()
	var rig: Dictionary = RigFactoryScript.build(
		&"solver_stack_v1", clock, profile)
	if not bool(rig.get("ok", false)):
		viewport.queue_free()
		await process_frame
		return {"complete": false, "summary": {}}
	var world := rig["world"] as Node3D
	var bodies: Array = rig["bodies"]
	var bottom := rig["bottom_body"] as RigidBody3D
	viewport.add_child(world)
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	for step_id in SETTLE_TICKS:
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()

	var valid_pressure_samples := 0
	var capacity_complete := true
	var normal_load_sum := 0.0
	var reconstructed_normal_load_sum := 0.0
	var reconstructed_sample_count := 0
	var cop_weighted_sum := Vector3.ZERO
	var normal_impulse_sum := 0.0
	var maximum_linear_speed := 0.0
	var maximum_angular_speed := 0.0
	var maximum_tilt_rad := 0.0
	var maximum_height_error := 0.0
	var maximum_pair_penetration := 0.0
	var maximum_floor_penetration := 0.0
	var maximum_lateral_drift := 0.0
	var previous_post_step_states := _post_step_states(bodies)
	for local_step in ANALYSIS_TICKS:
		var step_id := SETTLE_TICKS + local_step
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()
		for body_index in bodies.size():
			var body := bodies[body_index] as RigidBody3D
			var observed = bodies[body_index]
			var observation: Dictionary = observed.latest_contact_v2_diagnostics.get(
				"observation", {})
			capacity_complete = (
				bool(observation.get("finite", false))
				and not bool(observation.get("saturated_ever", true))
				and capacity_complete)
			maximum_linear_speed = maxf(
				maximum_linear_speed, body.linear_velocity.length())
			maximum_angular_speed = maxf(
				maximum_angular_speed, body.angular_velocity.length())
			maximum_tilt_rad = maxf(maximum_tilt_rad, acos(clampf(
				body.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0)))
			maximum_height_error = maxf(
				maximum_height_error,
				absf(body.global_position.y
					- float(rig["expected_center_heights_m"][body_index])))
			maximum_lateral_drift = maxf(
				maximum_lateral_drift,
				Vector2(body.global_position.x, body.global_position.z).length())
			if body_index == 0:
				maximum_floor_penetration = maxf(
					maximum_floor_penetration,
					0.5 * float(rig["box_size_m"].y) - body.global_position.y)
			else:
				var lower := bodies[body_index - 1] as RigidBody3D
				maximum_pair_penetration = maxf(
					maximum_pair_penetration,
					float(rig["box_size_m"].y)
						- (body.global_position.y - lower.global_position.y))
		var pressure: Dictionary = PressureObserverScript.observe_raw_points(
			bottom.latest_contacts_v2,
			step_id,
			String(rig["floor_id"]),
			step_s,
			Vector3.UP)
		if bool(pressure.get("observation_valid", false)):
			valid_pressure_samples += 1
			var impulse := float(pressure["total_predicted_normal_impulse_ns"])
			normal_impulse_sum += impulse
			cop_weighted_sum += impulse \
				* (pressure["center_of_pressure_world_m"] as Vector3)
			normal_load_sum += float(pressure["predicted_normal_load_n"])
		var current_post_step_states := _post_step_states(bodies)
		var reconstructed: Dictionary = ExternalImpulseReconstructorScript.reconstruct(
			previous_post_step_states,
			current_post_step_states,
			step_s,
			Vector3.DOWN * float(rig["total_stack_mass_kg"]) * 9.8 * step_s,
			Vector3.UP)
		if bool(reconstructed.get("reconstruction_valid", false)):
			reconstructed_sample_count += 1
			reconstructed_normal_load_sum += float(
				reconstructed["reconstructed_step_average_normal_load_n"])
		previous_post_step_states = current_post_step_states
	var denominator := float(maxi(valid_pressure_samples, 1))
	var mean_cop := (
		cop_weighted_sum / normal_impulse_sum
		if normal_impulse_sum > 0.0 else Vector3(INF, INF, INF))
	var expected_load := float(rig["total_stack_mass_kg"]) * 9.8
	var mean_load := normal_load_sum / denominator
	var reconstructed_denominator := float(maxi(reconstructed_sample_count, 1))
	var mean_reconstructed_load := (
		reconstructed_normal_load_sum / reconstructed_denominator)
	var summary := {
		"cell_id": String(cell["cell_id"]),
		"velocity_steps": requested_velocity_steps,
		"position_steps": requested_position_steps,
		"settings_readback_valid": settings_readback_valid,
		"settings_change_boundary_observed": true,
		"fresh_own_world_3d": own_world_valid,
		"world_constructed_after_setting_write": true,
		"valid_pressure_sample_count": valid_pressure_samples,
		"expected_pressure_sample_count": ANALYSIS_TICKS,
		"capacity_complete": capacity_complete,
		"mean_bottom_normal_load_n": mean_load,
		"expected_total_gravity_load_n": expected_load,
		"mean_bottom_load_error_n": absf(mean_load - expected_load),
		"reconstructed_sample_count": reconstructed_sample_count,
		"mean_reconstructed_external_normal_load_n": mean_reconstructed_load,
		"mean_reconstructed_load_error_n": absf(
			mean_reconstructed_load - expected_load),
		"raw_predicted_to_reconstructed_load_ratio": (
			mean_load / mean_reconstructed_load
			if absf(mean_reconstructed_load) > 1.0e-12 else INF),
		"impulse_weighted_bottom_cop_world_m": mean_cop,
		"maximum_linear_speed_mps": maximum_linear_speed,
		"maximum_angular_speed_rad_s": maximum_angular_speed,
		"maximum_tilt_rad": maximum_tilt_rad,
		"maximum_center_height_error_m": maximum_height_error,
		"maximum_pair_penetration_m": maxf(maximum_pair_penetration, 0.0),
		"maximum_floor_penetration_m": maxf(maximum_floor_penetration, 0.0),
		"maximum_lateral_drift_m": maximum_lateral_drift,
	}
	var complete := (
		settings_readback_valid
		and own_world_valid
		and capacity_complete
		and valid_pressure_samples == ANALYSIS_TICKS
		and reconstructed_sample_count == ANALYSIS_TICKS
		and mean_cop.is_finite()
		and normal_impulse_sum > 0.0)
	viewport.queue_free()
	await process_frame
	return {"complete": complete, "summary": summary}


func _evaluate_provisional_bounds(summaries: Array) -> void:
	var all_finite := true
	var current_configuration_stable := false
	for summary_value in summaries:
		var summary: Dictionary = summary_value
		all_finite = (
			is_finite(float(summary["maximum_center_height_error_m"]))
			and is_finite(float(summary["maximum_lateral_drift_m"]))
			and is_finite(float(summary["mean_reconstructed_load_error_n"]))
			and all_finite)
		if String(summary["cell_id"]) == "v20_p04":
			current_configuration_stable = (
				float(summary["maximum_tilt_rad"]) <= deg_to_rad(2.0)
			and float(summary["maximum_linear_speed_mps"]) <= 0.06
				and float(summary["maximum_center_height_error_m"]) <= 0.025
				and float(summary["mean_reconstructed_load_error_n"]) <= 1.0)
	_check(all_finite,
		"every solver cell stays finite inside provisional commissioning bounds")
	_check(current_configuration_stable,
		"the project's current 20/4 solver configuration supports the equal stack")


func _evaluate_repeat_controls(primary: Array, repeats: Array) -> void:
	var repeat_match := repeats.size() == REPEAT_CELL_IDS.size()
	for repeat_value in repeats:
		var repeat: Dictionary = repeat_value
		var original := _summary_by_id(primary, String(repeat.get("cell_id", "")))
		repeat_match = (
			not original.is_empty()
			and _provisional_accepted(repeat) \
				== _provisional_accepted(original)
			and repeat_match)
	_check(repeat_match,
		"2/4 and 4/4 rejected while 20/4 bounded classes repeat in fresh spaces")


func _evaluate_fail_closed_analyzer(summaries: Array) -> void:
	var built: Dictionary = SolverAnalyzerScript.build_config(
		ANALYZER_CONFIGURATION)
	_check(bool(built.get("ok", false)),
		"solver-step gates form a valid digest-bound exact-cell contract")
	if not bool(built.get("ok", false)):
		return
	var extended: Dictionary = (built["config"] as Dictionary).duplicate(true)
	extended["interpolation_allowed"] = true
	var payload := extended.duplicate(true)
	payload.erase("config_digest_sha256")
	extended["config_digest_sha256"] = CanonicalJsonScript.sha256(payload)
	var extended_result: Dictionary = SolverAnalyzerScript.analyze(
		extended, summaries)
	_check(not bool(extended_result["ok"])
		and extended_result["invalid_reasons"] == ["SOLVER_CONFIG_INVALID"],
		"coherently rehashed solver interpolation permission fails closed")
	var corrupted: Array = summaries.duplicate(true)
	(corrupted[5] as Dictionary)["maximum_center_height_error_m"] = 1.0
	var corrupted_result: Dictionary = SolverAnalyzerScript.analyze(
		built["config"], corrupted)
	_check(not bool(corrupted_result["ok"])
		and (corrupted_result["invalid_reasons"] as Array).has(
			"SOLVER_PROJECT_CONFIGURATION_REJECTED"),
		"corrupting the project 20/4 cell invalidates solver admission")
	var analysis: Dictionary = SolverAnalyzerScript.analyze(
		built["config"], summaries)
	_check(bool(analysis.get("ok", false))
		and int(analysis["accepted_cell_count"]) == 5
		and analysis["accepted_cell_ids"] == [
			"v20_p01", "v20_p02", "v20_p04", "v20_p08", "v40_p04"]
		and analysis["rejected_cell_ids"] == [
			"v02_p04", "v04_p04", "v10_p04"],
		"analyzer admits five exact cells and rejects the three unstable cells")
	if not bool(analysis.get("ok", false)):
		printerr("  solver_analysis=", analysis)
		return
	_check(not bool(analysis["velocity_response_nonmonotonic"])
		and int(analysis["velocity_class_transition_count"]) == 1
		and analysis["interpolation_policy"] == "forbidden_exact_cells_only"
		and analysis["interpolation_evidence"] \
			== "absent_unmeasured_cells_forbidden",
		"monotonic measurements still forbid unmeasured solver interpolation")
	_check(int(analysis[
			"minimum_accepted_position_steps_at_project_velocity"]) == 1,
		"position sweep admits measured 20/1, 20/2, 20/4, and 20/8 cells")
	_check(bool(analysis["raw_predicted_load_transmission_blind"])
		and float(analysis["project_raw_to_reconstructed_load_ratio"]) < 0.11
		and float(analysis["project_reconstructed_load_error_n"]) <= 1.0,
		"whole-system reconstruction closes the ten-body raw-load transmission gap")
	_check((analysis["does_not_establish"] as Array).has("standing")
		and (analysis["does_not_establish"] as Array).has("walking"),
		"L1.6 result explicitly excludes standing and walking")


func _print_summaries(summaries: Array) -> void:
	for summary_value in summaries:
		var summary: Dictionary = summary_value
		var cop: Vector3 = summary["impulse_weighted_bottom_cop_world_m"]
		print(("  %s V/P=%d/%d raw/recon/expected=%.3f/%.3f/%.3fN "
				+ "raw_ratio=%.3f CoP=(%+.4f,%+.4f)m "
				+ "height_err=%.4fm pair/floor_pen=%.4f/%.4fm "
				+ "v/w=%.4f/%.4f tilt=%.3fdeg drift=%.4fm") % [
			String(summary["cell_id"]),
			int(summary["velocity_steps"]),
			int(summary["position_steps"]),
			float(summary["mean_bottom_normal_load_n"]),
			float(summary["mean_reconstructed_external_normal_load_n"]),
			float(summary["expected_total_gravity_load_n"]),
			float(summary["raw_predicted_to_reconstructed_load_ratio"]),
			cop.x,
			cop.z,
			float(summary["maximum_center_height_error_m"]),
			float(summary["maximum_pair_penetration_m"]),
			float(summary["maximum_floor_penetration_m"]),
			float(summary["maximum_linear_speed_mps"]),
			float(summary["maximum_angular_speed_rad_s"]),
			rad_to_deg(float(summary["maximum_tilt_rad"])),
			float(summary["maximum_lateral_drift_m"]),
		])


static func _post_step_states(bodies: Array) -> Array:
	var states: Array = []
	for body_value in bodies:
		var body := body_value as RigidBody3D
		states.append({
			"body_id": String(body_value.body_id),
			"mass_kg": body.mass,
			"linear_velocity_world_mps": body.linear_velocity,
		})
	return states


static func _summary_by_id(summaries: Array, cell_id: String) -> Dictionary:
	for summary_value in summaries:
		var summary: Dictionary = summary_value
		if String(summary.get("cell_id", "")) == cell_id:
			return summary
	return {}


static func _cell_by_id(cell_id: String) -> Dictionary:
	for cell_value in SOLVER_CELLS:
		var cell: Dictionary = cell_value
		if String(cell["cell_id"]) == cell_id:
			return cell
	return {}


static func _provisional_accepted(summary: Dictionary) -> bool:
	var cop: Vector3 = summary["impulse_weighted_bottom_cop_world_m"]
	return (
		float(summary["maximum_center_height_error_m"])
			<= float(ANALYZER_CONFIGURATION["maximum_center_height_error_m"])
		and float(summary["maximum_pair_penetration_m"])
			<= float(ANALYZER_CONFIGURATION["maximum_pair_penetration_m"])
		and float(summary["maximum_floor_penetration_m"])
			<= float(ANALYZER_CONFIGURATION["maximum_floor_penetration_m"])
		and float(summary["maximum_linear_speed_mps"])
			<= float(ANALYZER_CONFIGURATION["maximum_linear_speed_mps"])
		and float(summary["maximum_angular_speed_rad_s"])
			<= float(ANALYZER_CONFIGURATION["maximum_angular_speed_rad_s"])
		and float(summary["maximum_tilt_rad"])
			<= float(ANALYZER_CONFIGURATION["maximum_tilt_rad"])
		and float(summary["maximum_lateral_drift_m"])
			<= float(ANALYZER_CONFIGURATION["maximum_lateral_drift_m"])
		and float(summary["mean_reconstructed_load_error_n"])
			<= float(ANALYZER_CONFIGURATION[
				"maximum_reconstructed_load_error_n"])
		and Vector2(cop.x, cop.z).length()
			<= float(ANALYZER_CONFIGURATION["maximum_centered_cop_radius_m"]))


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
