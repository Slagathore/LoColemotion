class_name LabTippingThresholdAnalyzer
extends RefCounted

## L1.3 support-edge tipping analysis across independent COM-offset trials.
##
## For the fixed rectangular footprint used by the fixture:
##
##     static support margin = footprint_half_width - abs(COM_x)
##
## The analyzer independently classifies the live response from sustained body
## rotation, direction, CoP edge migration, and pre-pivot slip. Only afterward
## does it compare that response with the analytic support-margin prediction.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const CONFIG_SCHEMA_VERSION := "tipping_threshold_config_v1"
const RESULT_SCHEMA_VERSION := "tipping_threshold_analysis_v1"
const STABLE := "STABLE"
const AMBIGUOUS := "AMBIGUOUS"
const TIPPING := "TIPPING"


static func build_config(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var minimum_contact_samples := _positive_integer(
		configuration.get("minimum_contact_samples_per_trial"),
		"/minimum_contact_samples_per_trial", errors)
	var half_width := _positive_float(
		configuration.get("authored_support_half_width_m"),
		"/authored_support_half_width_m", errors)
	var margin_tolerance := _nonnegative_float(
		configuration.get("support_margin_tolerance_m"),
		"/support_margin_tolerance_m", errors)
	var maximum_stable_tilt := _nonnegative_float(
		configuration.get("maximum_stable_tilt_rad"),
		"/maximum_stable_tilt_rad", errors)
	var maximum_stable_angular_speed := _nonnegative_float(
		configuration.get("maximum_stable_angular_speed_rad_s"),
		"/maximum_stable_angular_speed_rad_s", errors)
	var maximum_stable_displacement := _nonnegative_float(
		configuration.get("maximum_stable_displacement_m"),
		"/maximum_stable_displacement_m", errors)
	var minimum_tipping_tilt := _positive_float(
		configuration.get("minimum_tipping_tilt_rad"),
		"/minimum_tipping_tilt_rad", errors)
	var minimum_directional_up_x := _positive_float(
		configuration.get("minimum_tipping_directional_up_x"),
		"/minimum_tipping_directional_up_x", errors)
	var minimum_edge_cop_fraction := _positive_float(
		configuration.get("minimum_edge_cop_fraction"),
		"/minimum_edge_cop_fraction", errors)
	var maximum_pretip_slip := _nonnegative_float(
		configuration.get("maximum_pretip_slip_speed_mps"),
		"/maximum_pretip_slip_speed_mps", errors)
	if minimum_tipping_tilt <= maximum_stable_tilt:
		_add_error(errors, "TILT_HYSTERESIS_INVALID",
			"/minimum_tipping_tilt_rad",
			"Tipping tilt must be strictly above the stable tilt ceiling")
	if minimum_directional_up_x > 1.0:
		_add_error(errors, "DIRECTIONAL_TILT_INVALID",
			"/minimum_tipping_directional_up_x",
			"A body-up x component cannot exceed one")
	if minimum_edge_cop_fraction > 1.25:
		_add_error(errors, "EDGE_COP_FRACTION_INVALID",
			"/minimum_edge_cop_fraction",
			"The CoP edge gate must remain inside the diagnostic [0, 1.25] range")
	if not errors.is_empty():
		return FrozenValueScript.snapshot({
			"ok": false, "errors": errors, "config": null})
	var config := {
		"schema_version": CONFIG_SCHEMA_VERSION,
		"minimum_contact_samples_per_trial": minimum_contact_samples,
		"authored_support_half_width_m": half_width,
		"support_margin_tolerance_m": margin_tolerance,
		"maximum_stable_tilt_rad": maximum_stable_tilt,
		"maximum_stable_angular_speed_rad_s": maximum_stable_angular_speed,
		"maximum_stable_displacement_m": maximum_stable_displacement,
		"minimum_tipping_tilt_rad": minimum_tipping_tilt,
		"minimum_tipping_directional_up_x": minimum_directional_up_x,
		"minimum_edge_cop_fraction": minimum_edge_cop_fraction,
		"maximum_pretip_slip_speed_mps": maximum_pretip_slip,
		"trial_schedule_policy": "strictly_increasing_nonnegative_com_offset_v1",
		"independent_worlds_required": true,
		"raw_point_cop_required": true,
		"post_step_slip_required": true,
	}
	config["config_digest_sha256"] = CanonicalJsonScript.sha256(config)
	return FrozenValueScript.snapshot({
		"ok": true, "errors": [], "config": config})


static func analyze(config: Dictionary, trial_summaries: Array) -> Dictionary:
	if not _config_valid(config):
		return _invalid(["TIPPING_CONFIG_INVALID"], [])
	if trial_summaries.size() < 2:
		return _invalid(["TIPPING_TRIAL_COUNT_INSUFFICIENT"], [])
	var reasons: Array[String] = []
	var classified: Array = []
	var previous_offset := -INF
	var last_stable_index := -1
	var first_tipping_index := -1
	var stable_after_tipping := false
	for index in trial_summaries.size():
		var trial_value: Variant = trial_summaries[index]
		if not trial_value is Dictionary:
			reasons.append("TIPPING_TRIAL_NOT_DICTIONARY:%d" % index)
			continue
		var trial: Dictionary = trial_value
		var validation := _validate_trial(config, trial, index)
		reasons.append_array(validation["reasons"] as Array[String])
		var offset := float(trial.get("custom_com_offset_x_m", NAN))
		if is_finite(offset) and offset <= previous_offset:
			reasons.append("TIPPING_OFFSET_SCHEDULE_NOT_STRICTLY_INCREASING:%d" % index)
		previous_offset = offset
		var classification := String(validation["classification"])
		var classified_trial := trial.duplicate(true)
		classified_trial["classification"] = classification
		classified.append(classified_trial)
		if classification == STABLE:
			if first_tipping_index >= 0:
				stable_after_tipping = true
			else:
				last_stable_index = index
		elif classification == TIPPING and first_tipping_index < 0:
			first_tipping_index = index
	if stable_after_tipping:
		reasons.append("TIPPING_STABLE_TRIAL_AFTER_TIPPING")
	if last_stable_index < 0:
		reasons.append("TIPPING_NO_COMPLETED_STABLE_TRIAL")
	if first_tipping_index < 0:
		reasons.append("TIPPING_NO_COMPLETED_TIPPING_TRIAL")
	if last_stable_index >= first_tipping_index and first_tipping_index >= 0:
		reasons.append("TIPPING_TRIAL_ORDER_INVALID")
	if not reasons.is_empty():
		return _invalid(reasons, classified)
	var lower: Dictionary = classified[last_stable_index]
	var upper: Dictionary = classified[first_tipping_index]
	var lower_offset := float(lower["custom_com_offset_x_m"])
	var upper_offset := float(upper["custom_com_offset_x_m"])
	var analytic_edge := float(config["authored_support_half_width_m"])
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": true,
		"threshold_detected": true,
		"invalid_reasons": [],
		"config_digest_sha256": String(config["config_digest_sha256"]),
		"classified_trials": classified,
		"last_stable_trial_id": String(lower["trial_id"]),
		"first_tipping_trial_id": String(upper["trial_id"]),
		"threshold_offset_lower_m": lower_offset,
		"threshold_offset_upper_m": upper_offset,
		"threshold_bracket_width_m": upper_offset - lower_offset,
		"analytic_support_edge_offset_m": analytic_edge,
		"analytic_edge_inside_empirical_bracket": (
			analytic_edge >= lower_offset and analytic_edge <= upper_offset),
		"interpretation": "gravity_driven_support_edge_pivot_bracket_v1",
		"does_not_establish": [
			"active_load_bearing",
			"disturbance_rejection",
			"bracing",
			"standing",
			"recovery",
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
		reasons.append("TIPPING_TRIAL_ID_INVALID:%d" % index)
	for field in [
		"custom_com_offset_x_m",
		"support_half_width_m",
		"max_tilt_rad",
		"final_tilt_rad",
		"max_angular_speed_rad_s",
		"max_directional_up_x",
		"max_directional_angular_speed_rad_s",
		"max_cop_toward_edge_fraction",
		"max_pretip_slip_speed_mps",
		"lateral_displacement_m",
		"geometry_oracle_error_m",
	]:
		var value := float(trial.get(field, NAN))
		if not is_finite(value) or value < 0.0:
			reasons.append("TIPPING_TRIAL_%s_INVALID:%d" % [
				field.to_upper(), index])
	var margin := float(trial.get("initial_support_margin_m", NAN))
	if not is_finite(margin):
		reasons.append("TIPPING_TRIAL_INITIAL_SUPPORT_MARGIN_INVALID:%d" % index)
	var offset := float(trial.get("custom_com_offset_x_m", NAN))
	var half_width := float(trial.get("support_half_width_m", NAN))
	if is_finite(offset) and offset < 0.0:
		reasons.append("TIPPING_TRIAL_NEGATIVE_OFFSET_IN_PRIMARY_SCHEDULE:%d" % index)
	if is_finite(half_width) and absf(
			half_width - float(config["authored_support_half_width_m"])) \
			> float(config["support_margin_tolerance_m"]):
		reasons.append("TIPPING_TRIAL_FOOTPRINT_MISMATCH:%d" % index)
	var analytic_margin := half_width - absf(offset)
	if is_finite(margin) and is_finite(analytic_margin) \
			and absf(margin - analytic_margin) \
			> float(config["support_margin_tolerance_m"]):
		reasons.append("TIPPING_TRIAL_MARGIN_ORACLE_MISMATCH:%d" % index)
	var predicted_inside := analytic_margin >= 0.0
	if typeof(trial.get("analytic_inside_support")) != TYPE_BOOL \
			or bool(trial.get("analytic_inside_support", false)) != predicted_inside:
		reasons.append("TIPPING_TRIAL_ANALYTIC_CLASS_MISMATCH:%d" % index)
	var sample_count := int(trial.get("sample_count", -1))
	if typeof(trial.get("sample_count")) != TYPE_INT or sample_count <= 0:
		reasons.append("TIPPING_TRIAL_SAMPLE_COUNT_INVALID:%d" % index)
	for field in ["contact_sample_count", "cop_sample_count"]:
		if typeof(trial.get(field)) != TYPE_INT \
				or int(trial.get(field, -1)) \
				< int(config["minimum_contact_samples_per_trial"]):
			reasons.append("TIPPING_TRIAL_%s_INCOMPLETE:%d" % [
				field.to_upper(), index])
	if trial.get("capacity_complete") != true:
		reasons.append("TIPPING_TRIAL_CONTACT_CAPACITY_INCOMPLETE:%d" % index)
	if float(trial.get("geometry_oracle_error_m", INF)) \
			> float(config["support_margin_tolerance_m"]):
		reasons.append("TIPPING_TRIAL_GEOMETRY_ORACLE_FAILED:%d" % index)
	if not reasons.is_empty():
		return {"classification": AMBIGUOUS, "reasons": reasons}

	var max_tilt := float(trial["max_tilt_rad"])
	var stable: bool = (
		max_tilt <= float(config["maximum_stable_tilt_rad"])
		and float(trial["final_tilt_rad"])
			<= float(config["maximum_stable_tilt_rad"])
		and float(trial["max_angular_speed_rad_s"])
			<= float(config["maximum_stable_angular_speed_rad_s"])
		and float(trial["lateral_displacement_m"])
			<= float(config["maximum_stable_displacement_m"]))
	var tipping: bool = (
		max_tilt >= float(config["minimum_tipping_tilt_rad"])
		and float(trial["max_directional_up_x"])
			>= float(config["minimum_tipping_directional_up_x"])
		and float(trial["max_directional_angular_speed_rad_s"]) > 0.0
		and float(trial["max_cop_toward_edge_fraction"])
			>= float(config["minimum_edge_cop_fraction"])
		and float(trial["max_pretip_slip_speed_mps"])
			<= float(config["maximum_pretip_slip_speed_mps"])
		and trial.get("pivot_observed") == true)
	var classification := TIPPING if tipping else STABLE if stable else AMBIGUOUS
	if (predicted_inside and classification != STABLE) \
			or (not predicted_inside and classification != TIPPING):
		reasons.append("TIPPING_PREDICTION_RESPONSE_MISMATCH:%d" % index)
	return {"classification": classification, "reasons": reasons}


static func _config_valid(config: Dictionary) -> bool:
	var exact_fields := [
		"authored_support_half_width_m",
		"config_digest_sha256",
		"independent_worlds_required",
		"maximum_pretip_slip_speed_mps",
		"maximum_stable_angular_speed_rad_s",
		"maximum_stable_displacement_m",
		"maximum_stable_tilt_rad",
		"minimum_contact_samples_per_trial",
		"minimum_edge_cop_fraction",
		"minimum_tipping_directional_up_x",
		"minimum_tipping_tilt_rad",
		"post_step_slip_required",
		"raw_point_cop_required",
		"schema_version",
		"support_margin_tolerance_m",
		"trial_schedule_policy",
	]
	var actual_fields: Array = config.keys()
	actual_fields.sort()
	if actual_fields != exact_fields \
			or String(config.get("schema_version", "")) != CONFIG_SCHEMA_VERSION \
			or typeof(config.get("minimum_contact_samples_per_trial")) != TYPE_INT \
			or int(config.get("minimum_contact_samples_per_trial", 0)) <= 0 \
			or String(config.get("trial_schedule_policy", "")) \
				!= "strictly_increasing_nonnegative_com_offset_v1" \
			or config.get("independent_worlds_required") != true \
			or config.get("raw_point_cop_required") != true \
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


static func _positive_float(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> float:
	var number := float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] else NAN
	if is_finite(number) and number > 0.0:
		return number
	_add_error(errors, "POSITIVE_FLOAT_REQUIRED", path,
		"Expected a finite positive number")
	return 0.0


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


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({"code": code, "path": path, "message": message})
