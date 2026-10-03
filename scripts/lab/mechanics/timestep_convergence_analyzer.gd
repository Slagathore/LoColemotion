class_name LabTimestepConvergenceAnalyzer
extends RefCounted

## L1.5 physical-time-preserving timestep applicability analysis.
##
## A rate may be rejected without invalidating the sweep. Admission requires a
## contiguous accepted high-rate suffix, an accepted finest rate, static-pad
## calibration at every rate, and dynamic error contraction from the coarsest
## accepted cell to the finest cell.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const CONFIG_SCHEMA_VERSION := "timestep_convergence_config_v1"
const RESULT_SCHEMA_VERSION := "timestep_convergence_analysis_v1"
const ACCEPTED := "ACCEPTED"
const REJECTED := "REJECTED"


static func build_config(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var rates := _increasing_positive_int_array(
		configuration.get("required_rates_hz"), "/required_rates_hz", errors)
	var minimum_accepted_count := _positive_integer(
		configuration.get("minimum_accepted_rate_count"),
		"/minimum_accepted_rate_count", errors)
	if minimum_accepted_count > rates.size():
		_add_error(errors, "MINIMUM_ACCEPTED_COUNT_IMPOSSIBLE",
			"/minimum_accepted_rate_count",
			"Accepted-rate minimum cannot exceed the required grid")
	var fields := {
		"maximum_touch_interval_steps": _positive_float(
			configuration.get("maximum_touch_interval_steps"),
			"/maximum_touch_interval_steps", errors),
		"maximum_analytic_bracket_error_steps": _nonnegative_float(
			configuration.get("maximum_analytic_bracket_error_steps"),
			"/maximum_analytic_bracket_error_steps", errors),
		"maximum_impact_speed_error_gravity_steps": _positive_float(
			configuration.get("maximum_impact_speed_error_gravity_steps"),
			"/maximum_impact_speed_error_gravity_steps", errors),
		"minimum_arrest_impulse_ratio": _positive_float(
			configuration.get("minimum_arrest_impulse_ratio"),
			"/minimum_arrest_impulse_ratio", errors),
		"maximum_arrest_impulse_ratio": _positive_float(
			configuration.get("maximum_arrest_impulse_ratio"),
			"/maximum_arrest_impulse_ratio", errors),
		"maximum_penetration_m": _nonnegative_float(
			configuration.get("maximum_penetration_m"),
			"/maximum_penetration_m", errors),
		"maximum_rest_height_error_m": _nonnegative_float(
			configuration.get("maximum_rest_height_error_m"),
			"/maximum_rest_height_error_m", errors),
		"maximum_final_vertical_speed_mps": _nonnegative_float(
			configuration.get("maximum_final_vertical_speed_mps"),
			"/maximum_final_vertical_speed_mps", errors),
		"maximum_foot_cop_error_m": _positive_float(
			configuration.get("maximum_foot_cop_error_m"),
			"/maximum_foot_cop_error_m", errors),
		"maximum_foot_normal_load_error_n": _positive_float(
			configuration.get("maximum_foot_normal_load_error_n"),
			"/maximum_foot_normal_load_error_n", errors),
		"maximum_foot_tilt_rad": _nonnegative_float(
			configuration.get("maximum_foot_tilt_rad"),
			"/maximum_foot_tilt_rad", errors),
		"maximum_foot_slip_speed_mps": _nonnegative_float(
			configuration.get("maximum_foot_slip_speed_mps"),
			"/maximum_foot_slip_speed_mps", errors),
	}
	if float(fields["maximum_arrest_impulse_ratio"]) \
			<= float(fields["minimum_arrest_impulse_ratio"]):
		_add_error(errors, "ARREST_IMPULSE_RATIO_RANGE_INVALID",
			"/maximum_arrest_impulse_ratio",
			"Maximum arrest ratio must exceed the minimum")
	if not errors.is_empty():
		return FrozenValueScript.snapshot({
			"ok": false, "errors": errors, "config": null})
	var config := {
		"schema_version": CONFIG_SCHEMA_VERSION,
		"required_rates_hz": rates,
		"minimum_accepted_rate_count": minimum_accepted_count,
		"maximum_touch_interval_steps": fields["maximum_touch_interval_steps"],
		"maximum_analytic_bracket_error_steps": fields[
			"maximum_analytic_bracket_error_steps"],
		"maximum_impact_speed_error_gravity_steps": fields[
			"maximum_impact_speed_error_gravity_steps"],
		"minimum_arrest_impulse_ratio": fields[
			"minimum_arrest_impulse_ratio"],
		"maximum_arrest_impulse_ratio": fields[
			"maximum_arrest_impulse_ratio"],
		"maximum_penetration_m": fields["maximum_penetration_m"],
		"maximum_rest_height_error_m": fields[
			"maximum_rest_height_error_m"],
		"maximum_final_vertical_speed_mps": fields[
			"maximum_final_vertical_speed_mps"],
		"maximum_foot_cop_error_m": fields["maximum_foot_cop_error_m"],
		"maximum_foot_normal_load_error_n": fields[
			"maximum_foot_normal_load_error_n"],
		"maximum_foot_tilt_rad": fields["maximum_foot_tilt_rad"],
		"maximum_foot_slip_speed_mps": fields[
			"maximum_foot_slip_speed_mps"],
		"physical_time_held_constant": true,
		"contiguous_high_rate_envelope_required": true,
		"static_pressure_valid_at_every_rate_required": true,
	}
	config["config_digest_sha256"] = CanonicalJsonScript.sha256(config)
	return FrozenValueScript.snapshot({
		"ok": true, "errors": [], "config": config})


static func analyze(config: Dictionary, trial_summaries: Array) -> Dictionary:
	if not _config_valid(config):
		return _invalid(["TIMESTEP_CONFIG_INVALID"], [])
	var rates: Array = config["required_rates_hz"]
	if trial_summaries.size() != rates.size():
		return _invalid(["TIMESTEP_TRIAL_COUNT_MISMATCH"], [])
	var reasons: Array[String] = []
	var classified: Array = []
	var accepted_indices: Array[int] = []
	var rejected_rates: Array[int] = []
	for index in trial_summaries.size():
		var trial_value: Variant = trial_summaries[index]
		if not trial_value is Dictionary:
			reasons.append("TIMESTEP_TRIAL_INVALID:%d" % index)
			continue
		var trial: Dictionary = trial_value
		var validation := _validate_trial(config, trial, int(rates[index]), index)
		reasons.append_array(validation["fatal_reasons"] as Array[String])
		var classification := String(validation["classification"])
		var result := trial.duplicate(true)
		result["classification"] = classification
		result["rejection_reasons"] = validation["rejection_reasons"]
		classified.append(result)
		if classification == ACCEPTED:
			accepted_indices.append(index)
		else:
			rejected_rates.append(int(rates[index]))
	if not reasons.is_empty():
		return _invalid(reasons, classified)
	if accepted_indices.size() < int(config["minimum_accepted_rate_count"]):
		reasons.append("TIMESTEP_ACCEPTED_RATE_COUNT_INSUFFICIENT")
	if accepted_indices.is_empty() \
			or accepted_indices[accepted_indices.size() - 1] != rates.size() - 1:
		reasons.append("TIMESTEP_FINEST_RATE_NOT_ACCEPTED")
	if not accepted_indices.is_empty():
		var first_accepted := accepted_indices[0]
		for index in range(first_accepted, rates.size()):
			if not accepted_indices.has(index):
				reasons.append("TIMESTEP_ACCEPTED_ENVELOPE_NOT_CONTIGUOUS")
				break
	if not reasons.is_empty():
		return _invalid(reasons, classified)
	var coarse: Dictionary = classified[accepted_indices[0]]["drop"]
	var fine: Dictionary = classified[accepted_indices[accepted_indices.size() - 1]][
		"drop"]
	var coarse_impulse_error := absf(
		float(coarse["peak_contact_normal_impulse_ns"])
		- float(coarse["analytic_arrest_momentum_ns"]))
	var fine_impulse_error := absf(
		float(fine["peak_contact_normal_impulse_ns"])
		- float(fine["analytic_arrest_momentum_ns"]))
	if float(fine["impact_time_error_s"]) > float(coarse["impact_time_error_s"]) \
			or float(fine["impact_speed_error_mps"]) \
			> float(coarse["impact_speed_error_mps"]) + 1.0e-6 \
			or fine_impulse_error > coarse_impulse_error:
		return _invalid(["TIMESTEP_DYNAMIC_ERROR_DID_NOT_CONTRACT"], classified)
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": true,
		"converged_envelope_detected": true,
		"invalid_reasons": [],
		"config_digest_sha256": String(config["config_digest_sha256"]),
		"classified_rates": classified,
		"minimum_accepted_rate_hz": int(rates[accepted_indices[0]]),
		"maximum_tested_accepted_rate_hz": int(rates[rates.size() - 1]),
		"accepted_rate_count": accepted_indices.size(),
		"rejected_rates_hz": rejected_rates,
		"dynamic_error_contracted_coarse_to_fine": true,
		"interpretation": "bounded_timestep_envelope_for_exact_contact_fixtures_v1",
		"does_not_establish": [
			"universal_minimum_physics_rate",
			"articulated_solver_convergence",
			"load_bearing_limb",
			"bracing",
			"standing",
			"walking",
		],
	})


static func _validate_trial(
		config: Dictionary,
		trial: Dictionary,
		expected_hz: int,
		index: int) -> Dictionary:
	var fatal: Array[String] = []
	var rejection: Array[String] = []
	if int(trial.get("physics_ticks_per_second", -1)) != expected_hz:
		fatal.append("TIMESTEP_RATE_SCHEDULE_MISMATCH:%d" % index)
	var step_s := float(trial.get("step_s", NAN))
	if not is_finite(step_s) \
			or absf(step_s - 1.0 / float(expected_hz)) > 1.0e-9:
		fatal.append("TIMESTEP_STEP_DURATION_MISMATCH:%d" % index)
	var drop_value: Variant = trial.get("drop")
	var foot_value: Variant = trial.get("foot")
	if not drop_value is Dictionary or not foot_value is Dictionary:
		fatal.append("TIMESTEP_NESTED_SUMMARY_INVALID:%d" % index)
		return {
			"classification": REJECTED,
			"fatal_reasons": fatal,
			"rejection_reasons": rejection,
		}
	var drop: Dictionary = drop_value
	var foot: Dictionary = foot_value
	if drop.get("capacity_complete") != true \
			or foot.get("capacity_complete") != true \
			or int(foot.get("valid_sample_count", -1)) \
			!= int(foot.get("expected_sample_count", -2)):
		fatal.append("TIMESTEP_OBSERVATION_INCOMPLETE:%d" % index)
	if not _finite_nonnegative_fields(drop, [
		"touch_interval_s",
		"analytic_impact_bracket_error_s",
		"impact_time_error_s",
		"impact_speed_error_mps",
		"peak_contact_normal_impulse_ns",
		"analytic_arrest_momentum_ns",
		"final_vertical_speed_mps",
		"final_center_height_m",
		"expected_rest_center_height_m",
	]):
		fatal.append("TIMESTEP_DROP_METRIC_INVALID:%d" % index)
	if not is_finite(float(drop.get("minimum_bottom_height_m", NAN))):
		fatal.append("TIMESTEP_DROP_PENETRATION_INVALID:%d" % index)
	if not _finite_nonnegative_fields(foot, [
		"mean_cop_projection_error_m",
		"mean_normal_load_error_n",
		"max_tilt_rad",
		"max_post_step_slip_speed_mps",
	]):
		fatal.append("TIMESTEP_FOOT_METRIC_INVALID:%d" % index)
	if not fatal.is_empty():
		return {
			"classification": REJECTED,
			"fatal_reasons": fatal,
			"rejection_reasons": rejection,
		}
	if float(foot["mean_cop_projection_error_m"]) \
			> float(config["maximum_foot_cop_error_m"]) \
			or float(foot["mean_normal_load_error_n"]) \
			> float(config["maximum_foot_normal_load_error_n"]) \
			or float(foot["max_tilt_rad"]) > float(config["maximum_foot_tilt_rad"]) \
			or float(foot["max_post_step_slip_speed_mps"]) \
			> float(config["maximum_foot_slip_speed_mps"]):
		fatal.append("TIMESTEP_STATIC_PRESSURE_INVALID:%d" % index)
	var touch_steps := float(drop["touch_interval_s"]) / step_s
	if touch_steps > float(config["maximum_touch_interval_steps"]):
		rejection.append("TOUCH_INTERVAL_EXCEEDED")
	if float(drop["analytic_impact_bracket_error_s"]) / step_s \
			> float(config["maximum_analytic_bracket_error_steps"]):
		rejection.append("ANALYTIC_IMPACT_OUTSIDE_BRACKET")
	if float(drop["impact_speed_error_mps"]) / (9.8 * step_s) \
			> float(config["maximum_impact_speed_error_gravity_steps"]):
		rejection.append("PREIMPACT_SPEED_ERROR_EXCEEDED")
	var impulse_ratio := float(drop["peak_contact_normal_impulse_ns"]) \
		/ float(drop["analytic_arrest_momentum_ns"])
	if impulse_ratio < float(config["minimum_arrest_impulse_ratio"]) \
			or impulse_ratio > float(config["maximum_arrest_impulse_ratio"]):
		rejection.append("ARREST_IMPULSE_RATIO_EXCEEDED")
	if float(drop["minimum_bottom_height_m"]) \
			< -float(config["maximum_penetration_m"]):
		rejection.append("PENETRATION_EXCEEDED")
	if absf(float(drop["final_center_height_m"])
			- float(drop["expected_rest_center_height_m"])) \
			> float(config["maximum_rest_height_error_m"]):
		rejection.append("REST_HEIGHT_ERROR_EXCEEDED")
	if float(drop["final_vertical_speed_mps"]) \
			> float(config["maximum_final_vertical_speed_mps"]):
		rejection.append("FINAL_VERTICAL_SPEED_EXCEEDED")
	return {
		"classification": ACCEPTED if rejection.is_empty() else REJECTED,
		"fatal_reasons": fatal,
		"rejection_reasons": rejection,
	}


static func _finite_nonnegative_fields(value: Dictionary, fields: Array) -> bool:
	for field_value in fields:
		var number := float(value.get(String(field_value), NAN))
		if not is_finite(number) or number < 0.0:
			return false
	return true


static func _config_valid(config: Dictionary) -> bool:
	var exact_fields := [
		"config_digest_sha256",
		"contiguous_high_rate_envelope_required",
		"maximum_analytic_bracket_error_steps",
		"maximum_arrest_impulse_ratio",
		"maximum_final_vertical_speed_mps",
		"maximum_foot_cop_error_m",
		"maximum_foot_normal_load_error_n",
		"maximum_foot_slip_speed_mps",
		"maximum_foot_tilt_rad",
		"maximum_impact_speed_error_gravity_steps",
		"maximum_penetration_m",
		"maximum_rest_height_error_m",
		"maximum_touch_interval_steps",
		"minimum_accepted_rate_count",
		"minimum_arrest_impulse_ratio",
		"physical_time_held_constant",
		"required_rates_hz",
		"schema_version",
		"static_pressure_valid_at_every_rate_required",
	]
	var actual: Array = config.keys()
	actual.sort()
	if actual != exact_fields \
			or String(config.get("schema_version", "")) != CONFIG_SCHEMA_VERSION \
			or config.get("required_rates_hz") is not Array \
			or typeof(config.get("minimum_accepted_rate_count")) != TYPE_INT \
			or config.get("physical_time_held_constant") != true \
			or config.get("contiguous_high_rate_envelope_required") != true \
			or config.get("static_pressure_valid_at_every_rate_required") != true:
		return false
	var digest := String(config.get("config_digest_sha256", ""))
	var payload := config.duplicate(true)
	payload.erase("config_digest_sha256")
	return digest.begins_with("sha256:") and digest.length() == 71 \
		and digest == CanonicalJsonScript.sha256(payload)


static func _invalid(reasons: Array[String], classified: Array) -> Dictionary:
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": false,
		"converged_envelope_detected": false,
		"invalid_reasons": reasons,
		"classified_rates": classified,
	})


static func _increasing_positive_int_array(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> Array:
	var result: Array = []
	if not value is Array or (value as Array).size() < 2:
		_add_error(errors, "RATE_GRID_INVALID", path,
			"At least two timestep rates are required")
		return result
	var previous := 0
	for index in (value as Array).size():
		var item: Variant = (value as Array)[index]
		if typeof(item) != TYPE_INT or int(item) <= previous:
			_add_error(errors, "RATE_GRID_INVALID", "%s/%d" % [path, index],
				"Rates must be positive strictly increasing integers")
		previous = int(item)
		result.append(int(item))
	return result


static func _positive_integer(
		value: Variant, path: String, errors: Array[Dictionary]) -> int:
	if typeof(value) == TYPE_INT and int(value) > 0:
		return int(value)
	_add_error(errors, "POSITIVE_INTEGER_REQUIRED", path,
		"Expected a positive integer")
	return 0


static func _positive_float(
		value: Variant, path: String, errors: Array[Dictionary]) -> float:
	var number := _number(value)
	if is_finite(number) and number > 0.0:
		return number
	_add_error(errors, "POSITIVE_FLOAT_REQUIRED", path,
		"Expected a finite positive number")
	return 0.0


static func _nonnegative_float(
		value: Variant, path: String, errors: Array[Dictionary]) -> float:
	var number := _number(value)
	if is_finite(number) and number >= 0.0:
		return number
	_add_error(errors, "NONNEGATIVE_FLOAT_REQUIRED", path,
		"Expected a finite nonnegative number")
	return 0.0


static func _number(value: Variant) -> float:
	return float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] else NAN


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({"code": code, "path": path, "message": message})
