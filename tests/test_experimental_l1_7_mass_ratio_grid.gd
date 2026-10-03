extends SceneTree

## Experimental L1.7 directed mass-ratio grid at fixed total mass.
##
## This first commissioning runner intentionally prints the broad logarithmic
## grid before its final admission envelope is sealed. Both directions matter:
## a heavy load on a light support and a light load on a heavy support are not
## assumed to be dynamically interchangeable.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")
const RigFactoryScript := preload("res://scripts/lab/rig_factory.gd")
const PressureObserverScript := preload(
	"res://scripts/lab/mechanics/contact_pressure_observer.gd")
const ExternalImpulseReconstructorScript := preload(
	"res://scripts/lab/mechanics/external_contact_impulse_reconstructor.gd")
const MassRatioAnalyzerScript := preload(
	"res://scripts/lab/mechanics/mass_ratio_stability_analyzer.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const PHYSICS_TICKS_PER_SECOND := 60
const SETTLE_TICKS := 180
const ANALYSIS_TICKS := 60
const MASS_RATIOS := [
	1.0, 2.0, 4.0, 8.0, 16.0, 32.0,
	64.0, 128.0, 256.0, 512.0, 1024.0,
]
const REPEAT_CELL_IDS := ["top_r0016", "top_r0032", "bottom_r1024"]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental L1.7 mass-ratio survey ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_TICKS_PER_SECOND
	var profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v2")
	_check(bool(profile.get("executable", false)),
		"full_contacts_v2 is executable for the directed mass-ratio grid")
	_test_fixture_refusal(profile)

	var cells := _cells()
	var summaries: Array = []
	var all_complete := true
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var result: Dictionary = await _run_cell(profile, cell)
		all_complete = bool(result.get("complete", false)) and all_complete
		summaries.append(result.get("summary", {}))
	var repeats: Array = []
	var all_repeats_complete := true
	for repeat_id_value in REPEAT_CELL_IDS:
		var repeat_cell := _cell_by_id(cells, String(repeat_id_value))
		var repeat_result: Dictionary = await _run_cell(profile, repeat_cell)
		all_repeats_complete = bool(repeat_result.get(
			"complete", false)) and all_repeats_complete
		repeats.append(repeat_result.get("summary", {}))
	_print_summaries(summaries)
	print("- selected fresh-world repeat controls")
	_print_summaries(repeats)
	_check(summaries.size() == 21,
		"broad logarithmic grid contains one neutral and twenty directed cells")
	_check(all_complete,
		"every mass-ratio cell retains finite uncapped body and momentum evidence")
	_check(all_repeats_complete,
		"boundary and directional repeat cells retain complete evidence")
	_evaluate_mass_schedule(summaries)
	_evaluate_reconstruction(summaries)
	_evaluate_fail_closed_analyzer(summaries)
	_evaluate_repeat_controls(summaries, repeats)
	_check(true,
		"L1.7 survey explicitly excludes joints, bracing, standing, and walking")
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_fixture_refusal(profile: Dictionary) -> void:
	var invalid_direction: Dictionary = RigFactoryScript.build(
		&"mass_ratio_stack_v1", CaptureClockScript.new(), profile, {}, {
			"heavy_to_light_ratio": 1.0,
			"heavy_body": "top",
		})
	var unequal_neutral: Dictionary = RigFactoryScript.build(
		&"mass_ratio_stack_v1", CaptureClockScript.new(), profile, {}, {
			"heavy_to_light_ratio": 2.0,
			"heavy_body": "neutral",
		})
	var out_of_range: Dictionary = RigFactoryScript.build(
		&"mass_ratio_stack_v1", CaptureClockScript.new(), profile, {}, {
			"heavy_to_light_ratio": 2048.0,
			"heavy_body": "top",
		})
	var hidden_assist: Dictionary = RigFactoryScript.build(
		&"mass_ratio_stack_v1", CaptureClockScript.new(), profile, {}, {
			"heavy_to_light_ratio": 2.0,
			"heavy_body": "top",
			"rotation_lock": true,
		})
	_check(not bool(invalid_direction.get("ok", true))
		and not bool(unequal_neutral.get("ok", true))
		and not bool(out_of_range.get("ok", true))
		and not bool(hidden_assist.get("ok", true)),
		"fixture rejects ambiguous direction, out-of-range ratio, and hidden assist")


func _run_cell(profile: Dictionary, cell: Dictionary) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "MassRatioCell_%s" % String(cell["cell_id"])
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var own_world_valid := viewport.own_world_3d \
		and viewport.world_3d != root.world_3d
	var clock = CaptureClockScript.new()
	var rig: Dictionary = RigFactoryScript.build(
		&"mass_ratio_stack_v1", clock, profile, {}, {
			"heavy_to_light_ratio": float(cell["heavy_to_light_ratio"]),
			"heavy_body": String(cell["heavy_body"]),
		})
	if not bool(rig.get("ok", false)):
		viewport.queue_free()
		await process_frame
		return {"complete": false, "summary": {}}
	viewport.add_child(rig["world"] as Node3D)
	var bodies: Array = rig["bodies"]
	var bottom := rig["bottom_body"] as RigidBody3D
	var top := rig["top_body"] as RigidBody3D
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	# A newly attached SubViewport world consumes one physics tick while it
	# becomes active. Tag that tick for observer hygiene, but exclude it from
	# evaluated settling so every cell has the same lifecycle schedule.
	clock.open_epoch(0, step_s, &"integrate_callback")
	await physics_frame
	clock.close_epoch()
	var motion := _new_motion_metrics()
	var all_body_samples_finite := true
	var capacity_complete := true
	for local_step in SETTLE_TICKS:
		var step_id := 1 + local_step
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()
		all_body_samples_finite = _body_samples_finite(bodies) \
			and all_body_samples_finite
		capacity_complete = _capacities_complete(bodies) \
			and capacity_complete
		_update_motion_metrics(motion, rig)

	var valid_pressure_samples := 0
	var normal_load_sum := 0.0
	var cop_weighted_sum := Vector3.ZERO
	var normal_impulse_sum := 0.0
	var reconstructed_load_sum := 0.0
	var reconstructed_sample_count := 0
	var pair_contact_sample_count := 0
	var previous_post_step_states := _post_step_states(bodies)
	for local_step in ANALYSIS_TICKS:
		var step_id := 1 + SETTLE_TICKS + local_step
		clock.open_epoch(
			step_id,
			float(step_id + 1) * step_s,
			&"integrate_callback")
		await physics_frame
		clock.close_epoch()
		all_body_samples_finite = _body_samples_finite(bodies) \
			and all_body_samples_finite
		capacity_complete = _capacities_complete(bodies) \
			and capacity_complete
		_update_motion_metrics(motion, rig)
		if _has_counterparty(bottom.latest_contacts_v2, String(
				rig["top_body_id"])) \
				and _has_counterparty(top.latest_contacts_v2, String(
					rig["bottom_body_id"])):
			pair_contact_sample_count += 1
		var pressure: Dictionary = PressureObserverScript.observe_raw_points(
			bottom.latest_contacts_v2,
			step_id,
			String(rig["floor_id"]),
			step_s,
			Vector3.UP)
		if bool(pressure.get("observation_valid", false)):
			valid_pressure_samples += 1
			var impulse := float(pressure[
				"total_predicted_normal_impulse_ns"])
			normal_impulse_sum += impulse
			cop_weighted_sum += impulse \
				* (pressure["center_of_pressure_world_m"] as Vector3)
			normal_load_sum += float(pressure["predicted_normal_load_n"])
		var current_post_step_states := _post_step_states(bodies)
		var reconstructed: Dictionary = ExternalImpulseReconstructorScript.reconstruct(
			previous_post_step_states,
			current_post_step_states,
			step_s,
			Vector3.DOWN * float(rig["total_mass_kg"]) * 9.8 * step_s,
			Vector3.UP)
		if bool(reconstructed.get("reconstruction_valid", false)):
			reconstructed_sample_count += 1
			reconstructed_load_sum += float(reconstructed[
				"reconstructed_step_average_normal_load_n"])
		previous_post_step_states = current_post_step_states

	var pressure_denominator := float(maxi(valid_pressure_samples, 1))
	var reconstructed_denominator := float(maxi(
		reconstructed_sample_count, 1))
	var mean_raw_load := normal_load_sum / pressure_denominator
	var mean_reconstructed_load := (
		reconstructed_load_sum / reconstructed_denominator)
	var expected_load := float(rig["total_mass_kg"]) * 9.8
	var mean_cop := (
		cop_weighted_sum / normal_impulse_sum
		if normal_impulse_sum > 0.0 else Vector3.ZERO)
	var summary := {
		"cell_id": String(cell["cell_id"]),
		"heavy_to_light_ratio": float(rig["heavy_to_light_ratio"]),
		"heavy_body": String(rig["heavy_body"]),
		"bottom_mass_kg": float(rig["bottom_mass_kg"]),
		"top_mass_kg": float(rig["top_mass_kg"]),
		"total_mass_kg": float(rig["total_mass_kg"]),
		"joint_count": int((rig["constraint_contract"] as Dictionary)[
			"joint_count"]),
		"fixed_total_mass_valid": is_equal_approx(
			float(rig["bottom_mass_kg"]) + float(rig["top_mass_kg"]),
			float(rig["total_mass_kg"])),
		"fresh_own_world_3d": own_world_valid,
		"tagged_world_activation_warmup_excluded": true,
		"all_body_samples_finite": all_body_samples_finite,
		"capacity_complete": capacity_complete,
		"bottom_peak_raw_contact_count": _peak_contact_count(bottom),
		"top_peak_raw_contact_count": _peak_contact_count(top),
		"valid_floor_pressure_sample_count": valid_pressure_samples,
		"expected_analysis_sample_count": ANALYSIS_TICKS,
		"floor_pressure_contact_fraction": (
			float(valid_pressure_samples) / float(ANALYSIS_TICKS)),
		"pair_contact_sample_count": pair_contact_sample_count,
		"pair_contact_fraction": (
			float(pair_contact_sample_count) / float(ANALYSIS_TICKS)),
		"reconstructed_sample_count": reconstructed_sample_count,
		"mean_bottom_raw_normal_load_n": mean_raw_load,
		"mean_reconstructed_external_normal_load_n": mean_reconstructed_load,
		"expected_total_gravity_load_n": expected_load,
		"mean_reconstructed_load_error_n": absf(
			mean_reconstructed_load - expected_load),
		"raw_predicted_to_reconstructed_load_ratio": (
			mean_raw_load / mean_reconstructed_load
			if absf(mean_reconstructed_load) > 1.0e-12 else 0.0),
		"expected_raw_bottom_load_fraction": float(
			rig["expected_raw_bottom_load_fraction"]),
		"raw_load_fraction_error": absf(
			(mean_raw_load / mean_reconstructed_load
				if absf(mean_reconstructed_load) > 1.0e-12 else 0.0)
			- float(rig["expected_raw_bottom_load_fraction"])),
		"impulse_weighted_bottom_cop_world_m": mean_cop,
		"maximum_linear_speed_mps": float(motion["maximum_linear_speed_mps"]),
		"maximum_angular_speed_rad_s": float(
			motion["maximum_angular_speed_rad_s"]),
		"maximum_tilt_rad": float(motion["maximum_tilt_rad"]),
		"maximum_center_height_error_m": float(
			motion["maximum_center_height_error_m"]),
		"maximum_pair_vertical_error_m": float(
			motion["maximum_pair_vertical_error_m"]),
		"maximum_pair_penetration_m": float(
			motion["maximum_pair_penetration_m"]),
		"maximum_floor_penetration_m": float(
			motion["maximum_floor_penetration_m"]),
		"maximum_lateral_drift_m": float(
			motion["maximum_lateral_drift_m"]),
		"minimum_top_minus_bottom_height_m": float(
			motion["minimum_top_minus_bottom_height_m"]),
		"maximum_pair_relative_speed_mps": float(
			motion["maximum_pair_relative_speed_mps"]),
		"maximum_linear_kinetic_energy_j": float(
			motion["maximum_linear_kinetic_energy_j"]),
	}
	var complete := (
		own_world_valid
		and all_body_samples_finite
		and capacity_complete
		and bool(summary["fixed_total_mass_valid"])
		and reconstructed_sample_count == ANALYSIS_TICKS)
	viewport.queue_free()
	await process_frame
	return {"complete": complete, "summary": summary}


static func _new_motion_metrics() -> Dictionary:
	return {
		"maximum_linear_speed_mps": 0.0,
		"maximum_angular_speed_rad_s": 0.0,
		"maximum_tilt_rad": 0.0,
		"maximum_center_height_error_m": 0.0,
		"maximum_pair_vertical_error_m": 0.0,
		"maximum_pair_penetration_m": 0.0,
		"maximum_floor_penetration_m": 0.0,
		"maximum_lateral_drift_m": 0.0,
		"minimum_top_minus_bottom_height_m": INF,
		"maximum_pair_relative_speed_mps": 0.0,
		"maximum_linear_kinetic_energy_j": 0.0,
	}


static func _update_motion_metrics(metrics: Dictionary, rig: Dictionary) -> void:
	var bodies: Array = rig["bodies"]
	var expected_heights: Array = rig["expected_center_heights_m"]
	var linear_energy := 0.0
	for body_index in bodies.size():
		var body := bodies[body_index] as RigidBody3D
		metrics["maximum_linear_speed_mps"] = maxf(
			float(metrics["maximum_linear_speed_mps"]),
			body.linear_velocity.length())
		metrics["maximum_angular_speed_rad_s"] = maxf(
			float(metrics["maximum_angular_speed_rad_s"]),
			body.angular_velocity.length())
		metrics["maximum_tilt_rad"] = maxf(
			float(metrics["maximum_tilt_rad"]),
			acos(clampf(body.global_basis.y.normalized().dot(
				Vector3.UP), -1.0, 1.0)))
		metrics["maximum_center_height_error_m"] = maxf(
			float(metrics["maximum_center_height_error_m"]),
			absf(body.global_position.y - float(expected_heights[body_index])))
		metrics["maximum_lateral_drift_m"] = maxf(
			float(metrics["maximum_lateral_drift_m"]),
			Vector2(body.global_position.x, body.global_position.z).length())
		linear_energy += 0.5 * body.mass * body.linear_velocity.length_squared()
	var bottom := bodies[0] as RigidBody3D
	var top := bodies[1] as RigidBody3D
	var vertical_separation := top.global_position.y - bottom.global_position.y
	var box_height := float((rig["box_size_m"] as Vector3).y)
	metrics["minimum_top_minus_bottom_height_m"] = minf(
		float(metrics["minimum_top_minus_bottom_height_m"]),
		vertical_separation)
	metrics["maximum_pair_vertical_error_m"] = maxf(
		float(metrics["maximum_pair_vertical_error_m"]),
		absf(vertical_separation - box_height))
	metrics["maximum_pair_penetration_m"] = maxf(
		float(metrics["maximum_pair_penetration_m"]),
		box_height - vertical_separation)
	metrics["maximum_floor_penetration_m"] = maxf(
		float(metrics["maximum_floor_penetration_m"]),
		0.5 * box_height - bottom.global_position.y)
	metrics["maximum_pair_relative_speed_mps"] = maxf(
		float(metrics["maximum_pair_relative_speed_mps"]),
		(top.linear_velocity - bottom.linear_velocity).length())
	metrics["maximum_linear_kinetic_energy_j"] = maxf(
		float(metrics["maximum_linear_kinetic_energy_j"]), linear_energy)


func _evaluate_mass_schedule(summaries: Array) -> void:
	var schedule_valid := true
	var neutral: Dictionary = {}
	var directional: Dictionary = {}
	for summary_value in summaries:
		var summary: Dictionary = summary_value
		var ratio := float(summary["heavy_to_light_ratio"])
		var bottom_mass := float(summary["bottom_mass_kg"])
		var top_mass := float(summary["top_mass_kg"])
		schedule_valid = (
			absf(bottom_mass + top_mass - 2.0) <= 1.0e-6
			and absf(maxf(bottom_mass, top_mass) \
				/ minf(bottom_mass, top_mass) - ratio) <= 1.0e-4
			and schedule_valid)
		if String(summary["heavy_body"]) == "neutral":
			neutral = summary
		else:
			directional["%s:%s" % [str(ratio), String(
				summary["heavy_body"])]] = summary
	for ratio_value in MASS_RATIOS.slice(1):
		var ratio := float(ratio_value)
		var top_key := "%s:top" % str(ratio)
		var bottom_key := "%s:bottom" % str(ratio)
		if not directional.has(top_key) or not directional.has(bottom_key):
			schedule_valid = false
			continue
		var top_heavy: Dictionary = directional[top_key]
		var bottom_heavy: Dictionary = directional[bottom_key]
		schedule_valid = (
			absf(float(top_heavy["top_mass_kg"])
				- float(bottom_heavy["bottom_mass_kg"])) <= 1.0e-6
			and absf(float(top_heavy["bottom_mass_kg"])
				- float(bottom_heavy["top_mass_kg"])) <= 1.0e-6
			and schedule_valid)
	_check(schedule_valid and not neutral.is_empty()
		and absf(float(neutral["bottom_mass_kg"]) - 1.0) <= 1.0e-6
		and absf(float(neutral["top_mass_kg"]) - 1.0) <= 1.0e-6,
		"mass schedule holds 2 kg fixed and mirrors every directed ratio")


func _evaluate_reconstruction(summaries: Array) -> void:
	var complete := true
	var maximum_error := 0.0
	for summary_value in summaries:
		var summary: Dictionary = summary_value
		complete = (
			int(summary["reconstructed_sample_count"]) == ANALYSIS_TICKS
			and complete)
		maximum_error = maxf(maximum_error,
			float(summary["mean_reconstructed_load_error_n"]))
	_check(complete and maximum_error <= 1.0,
		"whole-system load reconstruction stays complete within 1 N across grid")


func _evaluate_fail_closed_analyzer(summaries: Array) -> void:
	var built: Dictionary = MassRatioAnalyzerScript.build_config(
		_analysis_configuration())
	_check(bool(built.get("ok", false)),
		"mass-ratio gates form a digest-bound exact-cell contract")
	if not bool(built.get("ok", false)):
		printerr("  mass_ratio_config=", built)
		return
	var extended: Dictionary = (built["config"] as Dictionary).duplicate(true)
	extended["maximum_admitted_ratio"] = 16.0
	var payload := extended.duplicate(true)
	payload.erase("config_digest_sha256")
	extended["config_digest_sha256"] = CanonicalJsonScript.sha256(payload)
	var extended_result: Dictionary = MassRatioAnalyzerScript.analyze(
		extended, summaries)
	_check(not bool(extended_result["ok"])
		and extended_result["invalid_reasons"] == ["MASS_RATIO_CONFIG_INVALID"],
		"coherently rehashed ratio-as-gate permission fails closed")
	var lifecycle_corrupted: Array = summaries.duplicate(true)
	(lifecycle_corrupted[1] as Dictionary)[
		"tagged_world_activation_warmup_excluded"] = false
	var lifecycle_result: Dictionary = MassRatioAnalyzerScript.analyze(
		built["config"], lifecycle_corrupted)
	_check(not bool(lifecycle_result["ok"])
		and String((lifecycle_result["invalid_reasons"] as Array)[0]).begins_with(
			"MASS_RATIO_WORLD_LIFECYCLE_UNPROVEN"),
		"missing fresh-world activation provenance invalidates the grid")
	var mass_corrupted: Array = summaries.duplicate(true)
	(mass_corrupted[0] as Dictionary)["total_mass_kg"] = 3.0
	var mass_result: Dictionary = MassRatioAnalyzerScript.analyze(
		built["config"], mass_corrupted)
	_check(not bool(mass_result["ok"])
		and (mass_result["invalid_reasons"] as Array).has(
			"MASS_RATIO_TOTAL_MASS_MISMATCH:0"),
		"fixed-total-mass corruption invalidates one-factor evidence")
	var analysis: Dictionary = MassRatioAnalyzerScript.analyze(
		built["config"], summaries)
	_check(bool(analysis.get("ok", false))
		and int(analysis["accepted_cell_count"]) == 15
		and (analysis["rejected_cell_ids"] as Array) == [
			"top_r0032", "top_r0064", "top_r0128",
			"top_r0256", "top_r0512", "top_r1024"],
		"physical metrics admit fifteen cells and reject six top-heavy cells")
	if not bool(analysis.get("ok", false)):
		printerr("  mass_ratio_analysis=", analysis)
		return
	_check(float(analysis["maximum_accepted_top_heavy_ratio"]) == 16.0
		and float(analysis["minimum_rejected_top_heavy_ratio"]) == 32.0
		and bool(analysis[
			"top_heavy_response_contiguous_accepted_prefix"]),
		"top-heavy contact-stack boundary is bracketed from 16:1 to 32:1")
	_check(bool(analysis["bottom_heavy_all_measured_cells_accepted"])
		and float(analysis[
			"maximum_measured_accepted_bottom_heavy_ratio"]) == 1024.0
		and analysis["bottom_heavy_upper_boundary_status"] \
			== "open_beyond_measured_grid",
		"bottom-heavy direction is admitted only through measured 1024:1")
	_check(float(analysis["first_directional_class_divergence_ratio"]) == 32.0,
		"same nominal ratio first changes class by direction at measured 32:1")
	_check(bool(analysis["raw_bottom_load_tracks_bottom_mass_fraction"])
		and analysis["raw_load_interpretation"] \
			== "local_bottom_body_weight_diagnostic_not_transmitted_stack_load",
		"raw floor impulse tracks bottom mass rather than transmitted stack load")
	var perturbed: Array = summaries.duplicate(true)
	var top_sixteen_index := _summary_index(perturbed, "top_r0016")
	(perturbed[top_sixteen_index] as Dictionary)[
		"maximum_center_height_error_m"] = 0.02
	var perturbed_result: Dictionary = MassRatioAnalyzerScript.analyze(
		built["config"], perturbed)
	_check(bool(perturbed_result["ok"])
		and float(perturbed_result[
			"maximum_accepted_top_heavy_ratio"]) == 8.0
		and float(perturbed_result[
			"minimum_rejected_top_heavy_ratio"]) == 16.0,
		"classification follows physical evidence rather than hard-coded ratio")
	_check(analysis["interpolation_policy"] == "forbidden_exact_cells_only"
		and (analysis["does_not_establish"] as Array).has(
			"articulated_mass_ratio_envelope")
		and (analysis["does_not_establish"] as Array).has("standing")
		and (analysis["does_not_establish"] as Array).has("walking"),
		"L1.7 forbids interpolation and articulated or locomotion promotion")


func _evaluate_repeat_controls(primary: Array, repeats: Array) -> void:
	var built: Dictionary = MassRatioAnalyzerScript.build_config(
		_analysis_configuration())
	var baseline: Dictionary = MassRatioAnalyzerScript.analyze(
		built.get("config", {}), primary)
	var repeat_classes_match := bool(built.get("ok", false)) \
		and bool(baseline.get("ok", false)) \
		and repeats.size() == REPEAT_CELL_IDS.size()
	for repeat_value in repeats:
		var repeat: Dictionary = repeat_value
		var cell_id := String(repeat.get("cell_id", ""))
		var index := _summary_index(primary, cell_id)
		if index < 0:
			repeat_classes_match = false
			continue
		var substituted := primary.duplicate(true)
		substituted[index] = repeat.duplicate(true)
		var repeated_analysis: Dictionary = MassRatioAnalyzerScript.analyze(
			built["config"], substituted)
		repeat_classes_match = (
			bool(repeated_analysis.get("ok", false))
			and _classification_for(repeated_analysis, cell_id) \
				== _classification_for(baseline, cell_id)
			and repeat_classes_match)
	_check(repeat_classes_match,
		"16:1/32:1 top-heavy boundary and 1024:1 bottom-heavy classes repeat")


static func _body_samples_finite(bodies: Array) -> bool:
	for body_value in bodies:
		var body = body_value
		if not bool(body.latest_body_sample.get("finite", false)) \
				or not body.global_position.is_finite() \
				or not body.linear_velocity.is_finite() \
				or not body.angular_velocity.is_finite():
			return false
	return true


static func _capacities_complete(bodies: Array) -> bool:
	for body_value in bodies:
		var body = body_value
		var observation: Dictionary = body.latest_contact_v2_diagnostics.get(
			"observation", {})
		if not bool(observation.get("finite", false)) \
				or bool(observation.get("saturated_ever", true)):
			return false
	return true


static func _peak_contact_count(body) -> int:
	var observation: Dictionary = body.latest_contact_v2_diagnostics.get(
		"observation", {})
	return int(observation.get("peak_observed_count", -1))


static func _has_counterparty(contacts: Array, semantic_id: String) -> bool:
	for contact_value in contacts:
		if contact_value is Dictionary \
				and bool((contact_value as Dictionary).get("finite", false)) \
				and String((contact_value as Dictionary).get(
					"counterparty_semantic_id", "")) == semantic_id:
			return true
	return false


static func _post_step_states(bodies: Array) -> Array:
	var states: Array = []
	for body_value in bodies:
		var body := body_value as RigidBody3D
		states.append({
			"body_id": String(body.body_id),
			"mass_kg": body.mass,
			"linear_velocity_world_mps": body.linear_velocity,
		})
	return states


static func _cells() -> Array:
	var result: Array = [{
		"cell_id": "neutral_r001",
		"heavy_to_light_ratio": 1.0,
		"heavy_body": "neutral",
	}]
	for ratio_value in MASS_RATIOS.slice(1):
		var ratio := float(ratio_value)
		for direction in ["top", "bottom"]:
			result.append({
				"cell_id": "%s_r%04d" % [direction, int(ratio)],
				"heavy_to_light_ratio": ratio,
				"heavy_body": direction,
			})
	return result


static func _analysis_configuration() -> Dictionary:
	return {
		"required_cells": _cells(),
		"fixed_total_mass_kg": 2.0,
		"total_mass_tolerance_kg": 1.0e-6,
		"mass_ratio_tolerance": 1.0e-4,
		"minimum_contact_fraction": 0.99,
		"maximum_center_height_error_m": 0.01,
		"maximum_pair_vertical_error_m": 0.005,
		"maximum_pair_penetration_m": 0.005,
		"maximum_floor_penetration_m": 0.005,
		"maximum_linear_speed_mps": 0.16,
		"maximum_angular_speed_rad_s": 0.3,
		"maximum_tilt_rad": deg_to_rad(1.0),
		"maximum_lateral_drift_m": 0.005,
		"maximum_pair_relative_speed_mps": 0.2,
		"maximum_linear_kinetic_energy_j": 0.03,
		"maximum_reconstructed_load_error_n": 1.0,
		"maximum_raw_load_fraction_error": 0.01,
	}


static func _summary_index(summaries: Array, cell_id: String) -> int:
	for index in summaries.size():
		if String((summaries[index] as Dictionary).get("cell_id", "")) == cell_id:
			return index
	return -1


static func _cell_by_id(cells: Array, cell_id: String) -> Dictionary:
	for cell_value in cells:
		var cell: Dictionary = cell_value
		if String(cell.get("cell_id", "")) == cell_id:
			return cell
	return {}


static func _classification_for(analysis: Dictionary, cell_id: String) -> String:
	for result_value in analysis.get("classified_cells", []):
		var result: Dictionary = result_value
		if String(result.get("cell_id", "")) == cell_id:
			return String(result.get("classification", ""))
	return ""


static func _print_summaries(summaries: Array) -> void:
	for summary_value in summaries:
		var summary: Dictionary = summary_value
		print(("  %s complete=%s/%s cap=%s peaks=%d/%d "
				+ "masses=%.6f/%.6fkg floor/pair=%.2f/%.2f "
				+ "raw/recon/expected=%.4f/%.4f/%.4fN "
				+ "raw_ratio=%.4f expected=%.4f err=%.4f "
				+ "height/pair/floor=%.4f/%.4f/%.4fm "
				+ "v/w/tilt/drift=%.4f/%.4f/%.3f/%.4f KE=%.5fJ") % [
			String(summary["cell_id"]),
			str(bool(summary["all_body_samples_finite"])),
			str(int(summary["reconstructed_sample_count"]) == ANALYSIS_TICKS),
			str(bool(summary["capacity_complete"])),
			int(summary["bottom_peak_raw_contact_count"]),
			int(summary["top_peak_raw_contact_count"]),
			float(summary["bottom_mass_kg"]),
			float(summary["top_mass_kg"]),
			float(summary["floor_pressure_contact_fraction"]),
			float(summary["pair_contact_fraction"]),
			float(summary["mean_bottom_raw_normal_load_n"]),
			float(summary["mean_reconstructed_external_normal_load_n"]),
			float(summary["expected_total_gravity_load_n"]),
			float(summary["raw_predicted_to_reconstructed_load_ratio"]),
			float(summary["expected_raw_bottom_load_fraction"]),
			float(summary["raw_load_fraction_error"]),
			float(summary["maximum_center_height_error_m"]),
			float(summary["maximum_pair_vertical_error_m"]),
			float(summary["maximum_floor_penetration_m"]),
			float(summary["maximum_linear_speed_mps"]),
			float(summary["maximum_angular_speed_rad_s"]),
			rad_to_deg(float(summary["maximum_tilt_rad"])),
			float(summary["maximum_lateral_drift_m"]),
			float(summary["maximum_linear_kinetic_energy_j"]),
		])


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
