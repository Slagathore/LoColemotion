class_name LabInclineThresholdAnalyzer
extends RefCounted

## L1.2 independent-trial incline hold/slide analysis.
##
## For a gravity-loaded block on slope theta, the ideal demand ratio is:
##
##     Ft/Fn = (m g sin(theta)) / (m g cos(theta)) = tan(theta)
##
## Each angle is a fresh world. This analyzer brackets the empirical threshold
## between the steepest completed HELD trial and the shallowest completed
## SLIDING trial. It never treats a one-frame velocity or a height heuristic as
## slip, and it rejects incomplete contact or normal-frame disagreement.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const CONFIG_SCHEMA_VERSION := "incline_threshold_config_v1"
const RESULT_SCHEMA_VERSION := "incline_threshold_analysis_v1"
const HELD := "HELD"
const AMBIGUOUS := "AMBIGUOUS"
const SLIDING := "SLIDING"


static func build_config(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var minimum_samples := _positive_integer(
		configuration.get("minimum_samples_per_trial"),
		"/minimum_samples_per_trial", errors)
	var maximum_holding_speed := _nonnegative_float(
		configuration.get("maximum_holding_speed_mps"),
		"/maximum_holding_speed_mps", errors)
	var maximum_holding_displacement := _nonnegative_float(
		configuration.get("maximum_holding_displacement_m"),
		"/maximum_holding_displacement_m", errors)
	var minimum_sliding_speed := _nonnegative_float(
		configuration.get("minimum_sliding_speed_mps"),
		"/minimum_sliding_speed_mps", errors)
	var minimum_sliding_displacement := _nonnegative_float(
		configuration.get("minimum_sliding_displacement_m"),
		"/minimum_sliding_displacement_m", errors)
	var minimum_normal_alignment := _unit_interval_float(
		configuration.get("minimum_normal_alignment_dot"),
		"/minimum_normal_alignment_dot", errors)
	var authored_friction := _unit_interval_float(
		configuration.get("authored_pair_friction"),
		"/authored_pair_friction", errors)
	if minimum_sliding_speed <= maximum_holding_speed:
		_add_error(errors, "SPEED_HYSTERESIS_INVALID",
			"/minimum_sliding_speed_mps",
			"Sliding speed must be strictly above the holding ceiling")
	if minimum_sliding_displacement <= maximum_holding_displacement:
		_add_error(errors, "DISPLACEMENT_HYSTERESIS_INVALID",
			"/minimum_sliding_displacement_m",
			"Sliding displacement must be strictly above the holding ceiling")
	if not errors.is_empty():
		return FrozenValueScript.snapshot({
			"ok": false, "errors": errors, "config": null})
	var config := {
		"schema_version": CONFIG_SCHEMA_VERSION,
		"minimum_samples_per_trial": minimum_samples,
		"maximum_holding_speed_mps": maximum_holding_speed,
		"maximum_holding_displacement_m": maximum_holding_displacement,
		"minimum_sliding_speed_mps": minimum_sliding_speed,
		"minimum_sliding_displacement_m": minimum_sliding_displacement,
		"minimum_normal_alignment_dot": minimum_normal_alignment,
		"authored_pair_friction": authored_friction,
		"analytic_coulomb_threshold_deg": rad_to_deg(atan(authored_friction)),
		"trial_schedule_policy": "strictly_increasing_independent_angles_v1",
		"contact_completeness_required": true,
		"post_step_slip_required": true,
	}
	config["config_digest_sha256"] = CanonicalJsonScript.sha256(config)
	return FrozenValueScript.snapshot({"ok": true, "errors": [], "config": config})


static func analyze(config: Dictionary, trial_summaries: Array) -> Dictionary:
	if not _config_valid(config):
		return _invalid(["INCLINE_CONFIG_INVALID"], [])
	if trial_summaries.size() < 2:
		return _invalid(["INCLINE_TRIAL_COUNT_INSUFFICIENT"], [])
	var reasons: Array[String] = []
	var classified: Array = []
	var previous_angle := -INF
	var first_sliding_index := -1
	var last_held_index := -1
	var held_after_sliding := false
	for index in trial_summaries.size():
		var trial_value: Variant = trial_summaries[index]
		if not trial_value is Dictionary:
			reasons.append("INCLINE_TRIAL_NOT_DICTIONARY:%d" % index)
			continue
		var trial: Dictionary = trial_value
		var validation := _validate_trial(config, trial, index)
		reasons.append_array(validation["reasons"] as Array[String])
		var angle_deg := float(trial.get("slope_angle_deg", NAN))
		if is_finite(angle_deg) and angle_deg <= previous_angle:
			reasons.append("INCLINE_ANGLE_SCHEDULE_NOT_STRICTLY_INCREASING:%d" % index)
		previous_angle = angle_deg
		var classification := String(validation["classification"])
		var classified_trial := trial.duplicate(true)
		classified_trial["classification"] = classification
		classified_trial["analytic_gravity_ratio"] = (
			tan(deg_to_rad(angle_deg)) if is_finite(angle_deg) else null)
		classified.append(classified_trial)
		if classification == HELD:
			if first_sliding_index >= 0:
				held_after_sliding = true
			else:
				last_held_index = index
		elif classification == SLIDING and first_sliding_index < 0:
			first_sliding_index = index
	if held_after_sliding:
		reasons.append("INCLINE_HELD_TRIAL_AFTER_SLIDING")
	if last_held_index < 0:
		reasons.append("INCLINE_NO_COMPLETED_HOLD_TRIAL")
	if first_sliding_index < 0:
		reasons.append("INCLINE_NO_COMPLETED_SLIDING_TRIAL")
	if last_held_index >= first_sliding_index and first_sliding_index >= 0:
		reasons.append("INCLINE_TRIAL_ORDER_INVALID")
	if not reasons.is_empty():
		return _invalid(reasons, classified)
	var lower: Dictionary = classified[last_held_index]
	var upper: Dictionary = classified[first_sliding_index]
	var lower_deg := float(lower["slope_angle_deg"])
	var upper_deg := float(upper["slope_angle_deg"])
	var analytic_deg := float(config["analytic_coulomb_threshold_deg"])
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": true,
		"threshold_detected": true,
		"invalid_reasons": [],
		"config_digest_sha256": String(config["config_digest_sha256"]),
		"classified_trials": classified,
		"last_held_trial_id": String(lower["trial_id"]),
		"first_sliding_trial_id": String(upper["trial_id"]),
		"threshold_angle_lower_deg": lower_deg,
		"threshold_angle_upper_deg": upper_deg,
		"threshold_angle_bracket_width_deg": upper_deg - lower_deg,
		"empirical_ratio_lower": tan(deg_to_rad(lower_deg)),
		"empirical_ratio_upper": tan(deg_to_rad(upper_deg)),
		"analytic_coulomb_threshold_deg": analytic_deg,
		"analytic_threshold_inside_empirical_bracket": (
			analytic_deg >= lower_deg and analytic_deg <= upper_deg),
		"interpretation": "independent_trial_angle_bracket_for_exact_configuration_v1",
		"does_not_establish": [
			"universal_material_coefficient",
			"uneven_terrain_support",
			"load_bearing_limb",
			"bracing",
			"standing",
			"walking",
		],
	})


static func _validate_trial(
		config: Dictionary,
		trial: Dictionary,
		index: int) -> Dictionary:
	var reasons: Array[String] = []
	var trial_id_value: Variant = trial.get("trial_id")
	if not (trial_id_value is String or trial_id_value is StringName) \
			or String(trial_id_value).is_empty():
		reasons.append("INCLINE_TRIAL_ID_INVALID:%d" % index)
	for field in [
		"slope_angle_deg",
		"max_slip_speed_mps",
		"tangential_displacement_m",
		"mean_normal_load_n",
		"minimum_contact_normal_alignment_dot",
	]:
		var value := float(trial.get(field, NAN))
		if not is_finite(value) or value < 0.0:
			reasons.append("INCLINE_TRIAL_%s_INVALID:%d" % [
				field.to_upper(), index])
	var angle_deg := float(trial.get("slope_angle_deg", NAN))
	if is_finite(angle_deg) and (angle_deg < 0.0 or angle_deg > 60.0):
		reasons.append("INCLINE_TRIAL_ANGLE_OUT_OF_RANGE:%d" % index)
	var sample_count := int(trial.get("sample_count", -1))
	if typeof(trial.get("sample_count")) != TYPE_INT \
			or sample_count < int(config["minimum_samples_per_trial"]):
		reasons.append("INCLINE_TRIAL_SAMPLE_COUNT_INVALID:%d" % index)
	if typeof(trial.get("valid_sample_count")) != TYPE_INT \
			or int(trial.get("valid_sample_count", -1)) != sample_count:
		reasons.append("INCLINE_TRIAL_VALID_SAMPLE_INCOMPLETE:%d" % index)
	if typeof(trial.get("contact_sample_count")) != TYPE_INT \
			or int(trial.get("contact_sample_count", -1)) != sample_count:
		reasons.append("INCLINE_TRIAL_CONTACT_INCOMPLETE:%d" % index)
	if float(trial.get("mean_normal_load_n", NAN)) <= 0.0:
		reasons.append("INCLINE_TRIAL_NORMAL_LOAD_UNAVAILABLE:%d" % index)
	if float(trial.get("minimum_contact_normal_alignment_dot", -1.0)) \
			< float(config["minimum_normal_alignment_dot"]):
		reasons.append("INCLINE_TRIAL_NORMAL_FRAME_MISMATCH:%d" % index)
	if not reasons.is_empty():
		return {"classification": AMBIGUOUS, "reasons": reasons}
	var speed := float(trial["max_slip_speed_mps"])
	var displacement := float(trial["tangential_displacement_m"])
	var held := speed <= float(config["maximum_holding_speed_mps"]) \
		and displacement <= float(config["maximum_holding_displacement_m"])
	var sliding := speed >= float(config["minimum_sliding_speed_mps"]) \
		and displacement >= float(config["minimum_sliding_displacement_m"])
	return {
		"classification": SLIDING if sliding else HELD if held else AMBIGUOUS,
		"reasons": [],
	}


static func _config_valid(config: Dictionary) -> bool:
	var exact_fields := [
		"analytic_coulomb_threshold_deg",
		"authored_pair_friction",
		"config_digest_sha256",
		"contact_completeness_required",
		"maximum_holding_displacement_m",
		"maximum_holding_speed_mps",
		"minimum_normal_alignment_dot",
		"minimum_samples_per_trial",
		"minimum_sliding_displacement_m",
		"minimum_sliding_speed_mps",
		"post_step_slip_required",
		"schema_version",
		"trial_schedule_policy",
	]
	var actual_fields: Array = config.keys()
	actual_fields.sort()
	if actual_fields != exact_fields \
			or String(config.get("schema_version", "")) != CONFIG_SCHEMA_VERSION \
			or typeof(config.get("minimum_samples_per_trial")) != TYPE_INT \
			or int(config.get("minimum_samples_per_trial", 0)) <= 0 \
			or String(config.get("trial_schedule_policy", "")) \
				!= "strictly_increasing_independent_angles_v1" \
			or config.get("contact_completeness_required") != true \
			or config.get("post_step_slip_required") != true:
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
		"threshold_detected": false,
		"invalid_reasons": reasons,
		"classified_trials": classified,
	})


static func _positive_integer(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> int:
	if typeof(value) == TYPE_INT and int(value) > 0:
		return int(value)
	_add_error(errors, "POSITIVE_INTEGER_REQUIRED", path,
		"Expected a positive integer")
	return 0


static func _nonnegative_float(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> float:
	var number := float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] else NAN
	if is_finite(number) and number >= 0.0:
		return number
	_add_error(errors, "NONNEGATIVE_FLOAT_REQUIRED", path,
		"Expected a finite nonnegative number")
	return 0.0


static func _unit_interval_float(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> float:
	var number := float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] else NAN
	if is_finite(number) and number >= 0.0 and number <= 1.0:
		return number
	_add_error(errors, "UNIT_INTERVAL_FLOAT_REQUIRED", path,
		"Expected a finite number inside [0, 1]")
	return 0.0


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({"code": code, "path": path, "message": message})
