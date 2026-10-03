extends SceneTree

## Experimental L1.8 equal-area contact-discretization commissioning.
##
## One rigid 0.30 x 0.20 m, 2 kg pad is tiled into 1/4/16/64/100 collision
## elements. 1/4/16 run with complete raw-contact evidence. 64 and 100 exceed
## the frozen 256-point observation policy under the a-priori four-points-per-
## element declaration, so contact enumeration refuses instead of truncating;
## the same geometry then runs contacts-disabled with whole-system momentum
## reconstruction only. Elements are collision geometry, never actuators,
## muscles, toes, or fingers. This cell is separate nonblocking work; it is not
## part of the pinned L1.0-L1.7 commissioning grid and proves no locomotion.

const CaptureClockScript := preload("res://scripts/lab/capture_clock.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")
const RigFactoryScript := preload("res://scripts/lab/rig_factory.gd")
const PressureObserverScript := preload(
	"res://scripts/lab/mechanics/contact_pressure_observer.gd")
const ExternalImpulseReconstructorScript := preload(
	"res://scripts/lab/mechanics/external_contact_impulse_reconstructor.gd")
const DiscretizationAnalyzerScript := preload(
	"res://scripts/lab/mechanics/contact_discretization_analyzer.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const PHYSICS_TICKS_PER_SECOND := 60
const SETTLE_TICKS := 90
const ANALYSIS_TICKS := 60
const MEASURED_ELEMENT_COUNTS := [1, 4, 16]
const POLICY_REFUSED_ELEMENT_COUNTS := [64, 100]
const GRAVITY_MPS2 := 9.8
const PAD_MASS_KG := 2.0
const ANALYZER_CONFIGURATION := {
	"required_measured_element_counts": MEASURED_ELEMENT_COUNTS,
	"required_policy_refused_element_counts": POLICY_REFUSED_ELEMENT_COUNTS,
	"required_reconstruction_only_element_counts":
		POLICY_REFUSED_ELEMENT_COUNTS,
	"control_element_count": 1,
	"minimum_samples_per_cell": ANALYSIS_TICKS,
	"authored_pad_mass_kg": PAD_MASS_KG,
	"authored_gravity_mps2": GRAVITY_MPS2,
	"expected_raw_points_per_element": 4,
	"safety_margin_raw_points": 8,
	"contact_policy_max_cap_per_body": 256,
	"maximum_control_raw_sum_error_n": 0.5,
	"required_raw_sum_ratio_brackets": [
		{"contact_element_count": 1,
			"minimum_ratio": 0.95, "maximum_ratio": 1.05},
		{"contact_element_count": 4,
			"minimum_ratio": 3.5, "maximum_ratio": 4.5},
		{"contact_element_count": 16,
			"minimum_ratio": 9.0, "maximum_ratio": 13.0},
	],
	"maximum_cop_error_m": 0.006,
	"maximum_tilt_rad": deg_to_rad(0.5),
	"maximum_slip_speed_mps": 0.005,
	"maximum_displacement_m": 0.002,
	"maximum_element_manifold_load_ratio": 1.1,
	"maximum_load_chatter_fraction": 0.05,
	"maximum_element_presence_churn_fraction": 0.2,
	"maximum_control_divergence_load_n": 0.5,
	"maximum_reconstructed_load_error_n": 1.0,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental L1.8 contact discretization ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_TICKS_PER_SECOND
	var contact_profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v2")
	var state_profile: Dictionary = ObserverProfileScript.resolve(
		&"full_state_v1")
	_check(bool(contact_profile.get("executable", false))
		and bool(state_profile.get("executable", false)),
		"contact and body-state observer profiles are both executable")
	_test_fixture_refusal(contact_profile)
	var refused_cells := _test_policy_refusal(contact_profile)

	var measured_cells: Array = []
	var all_measured_complete := true
	for count_value in MEASURED_ELEMENT_COUNTS:
		var result: Dictionary = await _run_measured_cell(
			contact_profile, int(count_value))
		all_measured_complete = bool(result.get("complete", false)) \
			and all_measured_complete
		measured_cells.append(result.get("summary", {}))
	_print_measured(measured_cells)
	_check(all_measured_complete,
		"1/4/16-element cells retain complete finite raw-contact windows")

	var reconstruction_cells: Array = []
	var all_reconstruction_complete := true
	for count_value in POLICY_REFUSED_ELEMENT_COUNTS:
		var result: Dictionary = await _run_reconstruction_cell(
			state_profile, int(count_value))
		all_reconstruction_complete = bool(result.get("complete", false)) \
			and all_reconstruction_complete
		reconstruction_cells.append(result.get("summary", {}))
	_print_reconstruction(reconstruction_cells)
	_check(all_reconstruction_complete,
		"64/100-element reconstruction-only cells retain complete windows")

	_evaluate_measured(measured_cells)
	_evaluate_reconstruction(reconstruction_cells)
	_evaluate_analyzer(measured_cells, refused_cells, reconstruction_cells)
	_check(true,
		"L1.8 explicitly excludes actuators, toes, joints, standing, and walking")
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_fixture_refusal(profile: Dictionary) -> void:
	print("- fixture refuses actuator framing and unknown element counts")
	var actuator: Dictionary = RigFactoryScript.build(
		&"discretized_pad_v1", CaptureClockScript.new(), profile, {}, {
			"contact_element_count": 4,
			"per_element_actuation": true,
		})
	var unknown_count: Dictionary = RigFactoryScript.build(
		&"discretized_pad_v1", CaptureClockScript.new(), profile, {}, {
			"contact_element_count": 7,
		})
	var body_tuned: Dictionary = RigFactoryScript.build(
		&"discretized_pad_v1", CaptureClockScript.new(), profile,
		{"mass": 5.0}, {"contact_element_count": 4})
	_check(not bool(actuator.get("ok", true))
		and _has_configuration_error(actuator, "UNSUPPORTED_PARAMETER")
		and not bool(unknown_count.get("ok", true))
		and _has_configuration_error(unknown_count, "ELEMENT_COUNT_INVALID")
		and not bool(body_tuned.get("ok", true)),
		"actuator parameters, count 7, and body tuning all fail closed")


func _test_policy_refusal(profile: Dictionary) -> Array:
	print("- frozen 256-point policy refuses 64/100-element enumeration")
	var refused_cells: Array = []
	var all_refused := true
	for count_value in POLICY_REFUSED_ELEMENT_COUNTS:
		var element_count := int(count_value)
		var attempt: Dictionary = RigFactoryScript.build(
			&"discretized_pad_v1", CaptureClockScript.new(), profile, {}, {
				"contact_element_count": element_count,
			})
		var refused := not bool(attempt.get("ok", true)) \
			and _has_configuration_error(
				attempt, "DERIVED_CONTACT_CAP_EXCEEDS_POLICY")
		all_refused = refused and all_refused
		refused_cells.append({
			"cell_id": "refused_%03d" % element_count,
			"cell_class": "policy_refused",
			"contact_element_count": element_count,
			"refusal_code": "DERIVED_CONTACT_CAP_EXCEEDS_POLICY",
			"declared_expected_raw_points": int(attempt.get(
				"declared_expected_raw_points", -1)),
			"policy_max_cap_per_body": int(profile.get(
				"contact_policy_max_cap_per_body", -1)),
			"physics_ran": false,
		})
	_check(all_refused,
		"contact-mode 64/100 builds refuse instead of truncating evidence")
	return refused_cells


func _run_measured_cell(
		profile: Dictionary, element_count: int) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "DiscretizedPadCell_%03d" % element_count
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var own_world_valid := viewport.own_world_3d \
		and viewport.world_3d != root.world_3d
	var clock = CaptureClockScript.new()
	var rig: Dictionary = RigFactoryScript.build(
		&"discretized_pad_v1", clock, profile, {}, {
			"contact_element_count": element_count,
		})
	if not bool(rig.get("ok", false)):
		viewport.queue_free()
		await process_frame
		return {"complete": false, "summary": {}}
	viewport.add_child(rig["world"] as Node3D)
	var body := rig["body"] as RigidBody3D
	var element_ids: Array = rig["element_shape_ids"]
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	clock.open_epoch(0, step_s, &"integrate_callback")
	await physics_frame
	clock.close_epoch()
	for local_step in SETTLE_TICKS:
		var step_id := 1 + local_step
		clock.open_epoch(
			step_id, float(step_id + 1) * step_s, &"integrate_callback")
		await physics_frame
		clock.close_epoch()

	var valid_samples := 0
	var capacity_complete := true
	var weighted_cop_sum := Vector3.ZERO
	var total_normal_impulse := 0.0
	var per_tick_loads: Array[float] = []
	var per_element_load_sums: Dictionary = {}
	var elements_ever_contacting: Dictionary = {}
	var previous_presence_count := -1
	var presence_transitions := 0
	var max_tilt_rad := 0.0
	var max_slip_speed := 0.0
	var manual_total_impulse := 0.0
	var tick_cost_sum_usec := 0.0
	var reconstructed_samples := 0
	var reconstructed_load_sum := 0.0
	var previous_states := _post_step_states(body)
	var initial_position := body.global_position
	for local_step in ANALYSIS_TICKS:
		var step_id := 1 + SETTLE_TICKS + local_step
		clock.open_epoch(
			step_id, float(step_id + 1) * step_s, &"integrate_callback")
		var tick_started_usec := Time.get_ticks_usec()
		await physics_frame
		tick_cost_sum_usec += float(
			Time.get_ticks_usec() - tick_started_usec)
		clock.close_epoch()
		var current_states := _post_step_states(body)
		var reconstructed: Dictionary = (
			ExternalImpulseReconstructorScript.reconstruct(
				previous_states,
				current_states,
				step_s,
				Vector3.DOWN * PAD_MASS_KG * GRAVITY_MPS2 * step_s,
				Vector3.UP))
		if bool(reconstructed.get("reconstruction_valid", false)):
			reconstructed_samples += 1
			reconstructed_load_sum += float(reconstructed[
				"reconstructed_step_average_normal_load_n"])
		previous_states = current_states
		var diagnostics: Dictionary = body.latest_contact_v2_diagnostics
		var capacity: Dictionary = diagnostics.get("observation", {})
		capacity_complete = (
			bool(capacity.get("finite", false))
			and not bool(capacity.get("saturated_ever", true))
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
		var normal_impulse := float(
			pressure["total_predicted_normal_impulse_ns"])
		weighted_cop_sum += normal_impulse \
			* (pressure["center_of_pressure_world_m"] as Vector3)
		total_normal_impulse += normal_impulse
		per_tick_loads.append(float(pressure["predicted_normal_load_n"]))
		var presence_count := 0
		for raw_value in body.latest_contacts_v2:
			if not raw_value is Dictionary:
				continue
			var raw: Dictionary = raw_value
			if int(raw.get("physics_step_id", -1)) != step_id \
					or not bool(raw.get("finite", false)) \
					or String(raw.get("counterparty_semantic_id", "")) \
						!= String(rig["floor_id"]):
				continue
			var element_id := String(raw.get("observed_shape_semantic_id", ""))
			if not elements_ever_contacting.has(element_id):
				elements_ever_contacting[element_id] = true
			var normal: Vector3 = (
				raw["normal_world"] as Vector3).normalized()
			var weight := maxf(
				(raw["impulse_world_ns"] as Vector3).dot(normal), 0.0)
			manual_total_impulse += weight
			per_element_load_sums[element_id] = (
				float(per_element_load_sums.get(element_id, 0.0))
				+ weight / step_s)
		var present_this_tick: Dictionary = {}
		for raw_value in body.latest_contacts_v2:
			if raw_value is Dictionary \
					and int((raw_value as Dictionary).get(
						"physics_step_id", -1)) == step_id \
					and bool((raw_value as Dictionary).get("finite", false)):
				present_this_tick[String((raw_value as Dictionary).get(
					"observed_shape_semantic_id", ""))] = true
		presence_count = present_this_tick.size()
		if previous_presence_count >= 0 \
				and presence_count != previous_presence_count:
			presence_transitions += 1
		previous_presence_count = presence_count
		max_tilt_rad = maxf(max_tilt_rad, acos(clampf(
			body.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0)))
		max_slip_speed = maxf(
			max_slip_speed, _max_post_step_slip(body, step_id))

	var denominator := float(maxi(valid_samples, 1))
	var mean_cop := (
		weighted_cop_sum / total_normal_impulse
		if total_normal_impulse > 0.0 else Vector3(INF, INF, INF))
	var mean_total_load := 0.0
	for load_value in per_tick_loads:
		mean_total_load += load_value
	mean_total_load /= denominator
	var load_variance := 0.0
	for load_value in per_tick_loads:
		load_variance += pow(load_value - mean_total_load, 2.0)
	load_variance /= denominator
	var expected_load := PAD_MASS_KG * GRAVITY_MPS2
	var per_element_mean_loads: Array[float] = []
	var max_element_manifold_ratio := 0.0
	for element_id_value in element_ids:
		var mean_element_load := float(per_element_load_sums.get(
			String(element_id_value), 0.0)) / denominator
		per_element_mean_loads.append(mean_element_load)
		max_element_manifold_ratio = maxf(max_element_manifold_ratio,
			mean_element_load / expected_load)
	var mean_reconstructed := reconstructed_load_sum / float(
		maxi(reconstructed_samples, 1))
	var projected_com := body.global_transform * body.center_of_mass
	var capacity_contract: Dictionary = rig["contact_capacity"]
	var diagnostics_now: Dictionary = body.latest_contact_v2_diagnostics
	var summary := {
		"cell_id": "measured_%03d" % element_count,
		"cell_class": "measured_contact",
		"contact_element_count": element_count,
		"valid_sample_count": valid_samples,
		"expected_sample_count": ANALYSIS_TICKS,
		"fresh_own_world_3d": own_world_valid,
		"capacity_complete": capacity_complete,
		"configured_cap_per_body": int(capacity_contract.get(
			"configured_cap_per_body", -1)),
		"peak_observed_count": int((diagnostics_now.get(
			"observation", {}) as Dictionary).get("peak_observed_count", -1)),
		"declared_expected_raw_points": int(rig[
			"declared_expected_raw_points"]),
		"mean_total_raw_predicted_load_n": mean_total_load,
		"expected_static_normal_load_n": expected_load,
		"reconstructed_sample_count": reconstructed_samples,
		"mean_reconstructed_external_normal_load_n": mean_reconstructed,
		"mean_reconstructed_load_error_n": absf(
			mean_reconstructed - expected_load),
		"raw_sum_to_reconstructed_ratio": (
			mean_total_load / mean_reconstructed
			if absf(mean_reconstructed) > 1.0e-12 else INF),
		"load_chatter_fraction": sqrt(load_variance) / expected_load,
		"mean_cop_projection_error_m": Vector2(
			mean_cop.x - projected_com.x,
			mean_cop.z - projected_com.z).length(),
		"per_element_mean_raw_manifold_load_n": per_element_mean_loads,
		"max_element_manifold_load_ratio": max_element_manifold_ratio,
		"elements_ever_contacting_count": elements_ever_contacting.size(),
		"element_presence_churn_fraction": (
			float(presence_transitions) / float(maxi(valid_samples - 1, 1))),
		"manual_vs_observer_impulse_error_ns": absf(
			manual_total_impulse - total_normal_impulse),
		"max_tilt_rad": max_tilt_rad,
		"max_post_step_slip_speed_mps": max_slip_speed,
		"body_displacement_m": body.global_position.distance_to(
			initial_position),
		"mean_physics_tick_cost_usec": tick_cost_sum_usec / denominator,
	}
	var complete := (
		own_world_valid
		and capacity_complete
		and valid_samples == ANALYSIS_TICKS
		and reconstructed_samples == ANALYSIS_TICKS
		and mean_cop.is_finite()
		and total_normal_impulse > 0.0)
	viewport.queue_free()
	await process_frame
	return {"complete": complete, "summary": summary}


func _run_reconstruction_cell(
		profile: Dictionary, element_count: int) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.name = "DiscretizedPadReconstruction_%03d" % element_count
	viewport.size = Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var own_world_valid := viewport.own_world_3d \
		and viewport.world_3d != root.world_3d
	var clock = CaptureClockScript.new()
	var rig: Dictionary = RigFactoryScript.build(
		&"discretized_pad_v1", clock, profile, {}, {
			"contact_element_count": element_count,
		})
	if not bool(rig.get("ok", false)) \
			or String(rig.get("observation_mode", "")) \
				!= "body_state_reconstruction_only_v1":
		viewport.queue_free()
		await process_frame
		return {"complete": false, "summary": {}}
	viewport.add_child(rig["world"] as Node3D)
	var body := rig["body"] as RigidBody3D
	var step_s := 1.0 / float(PHYSICS_TICKS_PER_SECOND)
	clock.open_epoch(0, step_s, &"integrate_callback")
	await physics_frame
	clock.close_epoch()
	for local_step in SETTLE_TICKS:
		var step_id := 1 + local_step
		clock.open_epoch(
			step_id, float(step_id + 1) * step_s, &"integrate_callback")
		await physics_frame
		clock.close_epoch()

	var reconstructed_samples := 0
	var reconstructed_load_sum := 0.0
	var contacts_channel_stayed_empty := true
	var all_samples_finite := true
	var max_tilt_rad := 0.0
	var max_vertical_speed := 0.0
	var tick_cost_sum_usec := 0.0
	var initial_position := body.global_position
	var previous_states := _post_step_states(body)
	for local_step in ANALYSIS_TICKS:
		var step_id := 1 + SETTLE_TICKS + local_step
		clock.open_epoch(
			step_id, float(step_id + 1) * step_s, &"integrate_callback")
		var tick_started_usec := Time.get_ticks_usec()
		await physics_frame
		tick_cost_sum_usec += float(
			Time.get_ticks_usec() - tick_started_usec)
		clock.close_epoch()
		contacts_channel_stayed_empty = body.latest_contacts_v2.is_empty() \
			and contacts_channel_stayed_empty
		all_samples_finite = (
			bool(body.latest_body_sample.get("finite", false))
			and body.global_position.is_finite()
			and body.linear_velocity.is_finite()
			and all_samples_finite)
		max_tilt_rad = maxf(max_tilt_rad, acos(clampf(
			body.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0)))
		max_vertical_speed = maxf(
			max_vertical_speed, absf(body.linear_velocity.y))
		var current_states := _post_step_states(body)
		var reconstructed: Dictionary = (
			ExternalImpulseReconstructorScript.reconstruct(
				previous_states,
				current_states,
				step_s,
				Vector3.DOWN * PAD_MASS_KG * GRAVITY_MPS2 * step_s,
				Vector3.UP))
		if bool(reconstructed.get("reconstruction_valid", false)):
			reconstructed_samples += 1
			reconstructed_load_sum += float(reconstructed[
				"reconstructed_step_average_normal_load_n"])
		previous_states = current_states

	var denominator := float(maxi(reconstructed_samples, 1))
	var mean_reconstructed := reconstructed_load_sum / denominator
	var expected_load := PAD_MASS_KG * GRAVITY_MPS2
	var summary := {
		"cell_id": "reconstruction_%03d" % element_count,
		"cell_class": "reconstruction_only",
		"contact_element_count": element_count,
		"observation_mode": String(rig["observation_mode"]),
		"raw_contact_channel_available": not contacts_channel_stayed_empty,
		"all_body_samples_finite": all_samples_finite,
		"fresh_own_world_3d": own_world_valid,
		"reconstructed_sample_count": reconstructed_samples,
		"expected_sample_count": ANALYSIS_TICKS,
		"mean_reconstructed_external_normal_load_n": mean_reconstructed,
		"expected_static_normal_load_n": expected_load,
		"mean_reconstructed_load_error_n": absf(
			mean_reconstructed - expected_load),
		"max_vertical_speed_mps": max_vertical_speed,
		"max_tilt_rad": max_tilt_rad,
		"body_displacement_m": body.global_position.distance_to(
			initial_position),
		"mean_physics_tick_cost_usec": tick_cost_sum_usec / float(
			maxi(ANALYSIS_TICKS, 1)),
	}
	var complete := (
		own_world_valid
		and all_samples_finite
		and contacts_channel_stayed_empty
		and reconstructed_samples == ANALYSIS_TICKS)
	viewport.queue_free()
	await process_frame
	return {"complete": complete, "summary": summary}


func _evaluate_measured(summaries: Array) -> void:
	var control_raw_balanced := true
	var multi_manifold_overcounts := true
	var reconstruction_balanced := true
	var ratios_bracketed := true
	var cop_centered := true
	var coverage_complete := true
	var manifold_ratio_bounded := true
	var chatter_bounded := true
	var manual_matches_observer := true
	var costs_recorded := true
	var previous_peak := 0
	var peaks_nondecreasing := true
	for summary_value in summaries:
		var summary: Dictionary = summary_value
		var element_count := int(summary["contact_element_count"])
		var raw_load := float(summary["mean_total_raw_predicted_load_n"])
		var expected_load := float(summary["expected_static_normal_load_n"])
		if element_count == 1:
			control_raw_balanced = (
				absf(raw_load - expected_load) <= 0.5
				and control_raw_balanced)
		else:
			multi_manifold_overcounts = (
				raw_load - expected_load > 2.0
				and multi_manifold_overcounts)
		reconstruction_balanced = (
			float(summary["mean_reconstructed_load_error_n"]) <= 1.0
			and reconstruction_balanced)
		ratios_bracketed = (
			_ratio_in_bracket(element_count,
				float(summary["raw_sum_to_reconstructed_ratio"]))
			and ratios_bracketed)
		cop_centered = (
			float(summary["mean_cop_projection_error_m"]) <= 0.006
			and cop_centered)
		coverage_complete = (
			int(summary["elements_ever_contacting_count"]) == element_count
			and (summary[
				"per_element_mean_raw_manifold_load_n"] as Array).size()
				== element_count
			and coverage_complete)
		manifold_ratio_bounded = (
			float(summary["max_element_manifold_load_ratio"]) <= 1.1
			and manifold_ratio_bounded)
		chatter_bounded = (
			float(summary["load_chatter_fraction"]) <= 0.05
			and float(summary["element_presence_churn_fraction"]) <= 0.2
			and chatter_bounded)
		manual_matches_observer = (
			float(summary["manual_vs_observer_impulse_error_ns"]) <= 1.0e-6
			and manual_matches_observer)
		costs_recorded = (
			is_finite(float(summary["mean_physics_tick_cost_usec"]))
			and float(summary["mean_physics_tick_cost_usec"]) > 0.0
			and costs_recorded)
		var peak := int(summary["peak_observed_count"])
		peaks_nondecreasing = (
			peak >= previous_peak
			and peak > 0
			and peak < int(summary["configured_cap_per_body"])
			and peaks_nondecreasing)
		previous_peak = peak
	_check(control_raw_balanced,
		"one-manifold control raw predicted load balances mg within 0.5 N")
	_check(multi_manifold_overcounts,
		"multi-manifold raw sums exceed mg by over 2 N and are not a load")
	_check(reconstruction_balanced,
		"whole-system reconstruction balances mg within 1 N at every count")
	_check(ratios_bracketed,
		"raw-sum overcount ratios stay inside preregistered measured brackets")
	_check(cop_centered,
		"centered-mass CoP stays within 6 mm of projected COM at every count")
	_check(coverage_complete,
		"every declared element contacts the floor and reports manifold sums")
	_check(manifold_ratio_bounded,
		"no single element manifold sum exceeds 1.1x the whole-pad weight")
	_check(chatter_bounded,
		"load chatter and element-presence churn stay inside recorded gates")
	_check(manual_matches_observer,
		"per-element manual impulse accounting matches the pressure observer")
	_check(costs_recorded,
		"wall-clock tick cost is recorded as diagnostic for every measured cell")
	_check(peaks_nondecreasing,
		"peak raw-contact utilization grows with element count below each cap")


static func _ratio_in_bracket(element_count: int, ratio: float) -> bool:
	for bracket_value in ANALYZER_CONFIGURATION[
			"required_raw_sum_ratio_brackets"]:
		var bracket: Dictionary = bracket_value
		if int(bracket["contact_element_count"]) == element_count:
			return is_finite(ratio) \
				and ratio >= float(bracket["minimum_ratio"]) \
				and ratio <= float(bracket["maximum_ratio"])
	return false


func _evaluate_reconstruction(summaries: Array) -> void:
	var loads_balanced := true
	var channels_honest := true
	var stability_bounded := true
	for summary_value in summaries:
		var summary: Dictionary = summary_value
		loads_balanced = (
			float(summary["mean_reconstructed_load_error_n"]) <= 1.0
			and loads_balanced)
		channels_honest = (
			summary["raw_contact_channel_available"] == false
			and String(summary["observation_mode"]) \
				== "body_state_reconstruction_only_v1"
			and channels_honest)
		stability_bounded = (
			float(summary["max_tilt_rad"]) <= deg_to_rad(0.5)
			and float(summary["body_displacement_m"]) <= 0.002
			and stability_bounded)
	_check(loads_balanced,
		"64/100-element reconstructed support load balances mg within 1 N")
	_check(channels_honest,
		"reconstruction-only cells record contact enumeration as unavailable")
	_check(stability_bounded,
		"64/100-element pads stay planted and untilted while unenumerated")


func _evaluate_analyzer(
		measured_cells: Array,
		refused_cells: Array,
		reconstruction_cells: Array) -> void:
	var built: Dictionary = DiscretizationAnalyzerScript.build_config(
		ANALYZER_CONFIGURATION)
	_check(bool(built.get("ok", false)),
		"discretization gates form a digest-bound exact-cell contract")
	if not bool(built.get("ok", false)):
		printerr("  discretization_config=", built)
		return
	var all_cells: Array = []
	all_cells.append_array(measured_cells)
	all_cells.append_array(refused_cells)
	all_cells.append_array(reconstruction_cells)
	var extended: Dictionary = (built["config"] as Dictionary).duplicate(true)
	extended["per_element_actuation_admitted"] = true
	var payload := extended.duplicate(true)
	payload.erase("config_digest_sha256")
	extended["config_digest_sha256"] = CanonicalJsonScript.sha256(payload)
	var extended_result: Dictionary = DiscretizationAnalyzerScript.analyze(
		extended, all_cells)
	_check(not bool(extended_result["ok"])
		and extended_result["invalid_reasons"] \
			== ["CONTACT_DISCRETIZATION_CONFIG_INVALID"],
		"coherently rehashed actuator-permission config fails closed")
	var corrupted: Array = all_cells.duplicate(true)
	(corrupted[1] as Dictionary)["mean_reconstructed_load_error_n"] = 5.0
	var corrupted_result: Dictionary = DiscretizationAnalyzerScript.analyze(
		built["config"], corrupted)
	_check(not bool(corrupted_result["ok"])
		and (corrupted_result["invalid_reasons"] as Array).has(
			"DISCRETIZATION_RECONSTRUCTED_LOAD_ERROR_EXCEEDED:1"),
		"a corrupted reconstructed-load measurement cannot enter the table")
	var forged: Array = all_cells.duplicate(true)
	var forged_cell: Dictionary = (
		measured_cells[2] as Dictionary).duplicate(true)
	forged_cell["contact_element_count"] = 64
	forged_cell["cell_id"] = "measured_064"
	forged.append(forged_cell)
	var forged_result: Dictionary = DiscretizationAnalyzerScript.analyze(
		built["config"], forged)
	_check(not bool(forged_result["ok"]),
		"a forged measured-contact 64-element cell fails closed")
	var analysis: Dictionary = DiscretizationAnalyzerScript.analyze(
		built["config"], all_cells)
	_check(bool(analysis.get("ok", false))
		and bool(analysis.get("admitted", false))
		and (analysis["measured_element_counts"] as Array) == [1, 4, 16]
		and (analysis["policy_refused_element_counts"] as Array) == [64, 100],
		"complete five-count pack is admitted with an honest class split")
	if not bool(analysis.get("ok", false)):
		printerr("  discretization_analysis=", analysis)
		return
	_check(analysis["interpolation_policy"] == "forbidden_exact_cells_only"
		and analysis["runtime_cost_interpretation"] \
			== "wall_clock_diagnostic_recorded_not_gated"
		and (analysis["runtime_cost_records"] as Array).size() == 5
		and (analysis["raw_sum_to_reconstructed_ratios"] as Array).size() == 3,
		"interpolation stays forbidden and cost stays a recorded diagnostic")
	_check(analysis["raw_impulse_summation_interpretation"] \
			== "same_body_multi_manifold_raw_sum_is_not_external_support_load"
		and analysis["trusted_total_load_interpretation"] \
			== "whole_system_momentum_reconstruction_only",
		"raw multi-manifold sums are pinned as non-loads with reconstruction authoritative")
	_check((analysis["does_not_establish"] as Array).has(
			"independent_actuators")
		and (analysis["does_not_establish"] as Array).has("toes_or_fingers")
		and (analysis["does_not_establish"] as Array).has(
			"additive_per_element_load_partition_from_raw_impulse")
		and (analysis["does_not_establish"] as Array).has("standing")
		and (analysis["does_not_establish"] as Array).has("walking"),
		"L1.8 forbids actuator, toe, load-partition, standing, and walking promotion")


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


static func _post_step_states(body: RigidBody3D) -> Array:
	return [{
		"body_id": String(body.get("body_id")),
		"mass_kg": body.mass,
		"linear_velocity_world_mps": body.linear_velocity,
	}]


static func _print_measured(summaries: Array) -> void:
	for summary_value in summaries:
		var summary: Dictionary = summary_value
		print(("  %s cap=%d peak=%d raw=%.4fN recon=%.4f/%.4fN "
				+ "ratio=%.4f chatter=%.5f churn=%.3f cop_err=%.5fm "
				+ "elem_ratio=%.4f coverage=%d/%d cost=%.1fus") % [
			String(summary["cell_id"]),
			int(summary["configured_cap_per_body"]),
			int(summary["peak_observed_count"]),
			float(summary["mean_total_raw_predicted_load_n"]),
			float(summary["mean_reconstructed_external_normal_load_n"]),
			float(summary["expected_static_normal_load_n"]),
			float(summary["raw_sum_to_reconstructed_ratio"]),
			float(summary["load_chatter_fraction"]),
			float(summary["element_presence_churn_fraction"]),
			float(summary["mean_cop_projection_error_m"]),
			float(summary["max_element_manifold_load_ratio"]),
			int(summary["elements_ever_contacting_count"]),
			int(summary["contact_element_count"]),
			float(summary["mean_physics_tick_cost_usec"]),
		])


static func _print_reconstruction(summaries: Array) -> void:
	for summary_value in summaries:
		var summary: Dictionary = summary_value
		print(("  %s recon=%.4f/%.4fN err=%.4fN vy=%.5fm/s tilt=%.4fdeg "
				+ "disp=%.5fm cost=%.1fus contacts_channel=%s") % [
			String(summary["cell_id"]),
			float(summary["mean_reconstructed_external_normal_load_n"]),
			float(summary["expected_static_normal_load_n"]),
			float(summary["mean_reconstructed_load_error_n"]),
			float(summary["max_vertical_speed_mps"]),
			rad_to_deg(float(summary["max_tilt_rad"])),
			float(summary["body_displacement_m"]),
			float(summary["mean_physics_tick_cost_usec"]),
			str(bool(summary["raw_contact_channel_available"])),
		])


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
