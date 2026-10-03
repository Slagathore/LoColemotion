class_name LabPadCopAnalyzer
extends RefCounted

## L1.4 independent-trial foot-pad CoP admission analysis.
##
## The live result is admissible only when the entire preregistered load grid is
## complete, planted, load-balanced, monotonic, centered, and mirror-symmetric.
## Unknown config fields and corrupted trial measurements fail closed.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const CONFIG_SCHEMA_VERSION := "pad_cop_config_v1"
const RESULT_SCHEMA_VERSION := "pad_cop_analysis_v1"


static func build_config(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var offsets_value: Variant = configuration.get("required_offsets_x_m")
	var offsets: Array = []
	if offsets_value is Array and (offsets_value as Array).size() >= 3:
		var previous := -INF
		for index in (offsets_value as Array).size():
			var value: Variant = (offsets_value as Array)[index]
			var offset := _number(value)
			if not is_finite(offset) or offset <= previous:
				_add_error(errors, "OFFSET_SCHEDULE_INVALID",
					"/required_offsets_x_m/%d" % index,
					"Offsets must be finite and strictly increasing")
			previous = offset
			offsets.append(offset)
	else:
		_add_error(errors, "OFFSET_SCHEDULE_INVALID", "/required_offsets_x_m",
			"At least three load offsets are required")
	var minimum_samples := _positive_integer(
		configuration.get("minimum_samples_per_trial"),
		"/minimum_samples_per_trial", errors)
	var half_width_x := _positive_float(
		configuration.get("authored_half_width_x_m"),
		"/authored_half_width_x_m", errors)
	var half_width_z := _positive_float(
		configuration.get("authored_half_width_z_m"),
		"/authored_half_width_z_m", errors)
	var maximum_mean_cop_error := _positive_float(
		configuration.get("maximum_mean_cop_error_m"),
		"/maximum_mean_cop_error_m", errors)
	var maximum_normal_load_error := _positive_float(
		configuration.get("maximum_normal_load_error_n"),
		"/maximum_normal_load_error_n", errors)
	var maximum_tilt := _nonnegative_float(
		configuration.get("maximum_tilt_rad"),
		"/maximum_tilt_rad", errors)
	var maximum_slip := _nonnegative_float(
		configuration.get("maximum_slip_speed_mps"),
		"/maximum_slip_speed_mps", errors)
	var maximum_displacement := _nonnegative_float(
		configuration.get("maximum_displacement_m"),
		"/maximum_displacement_m", errors)
	var minimum_span_x := _positive_float(
		configuration.get("minimum_contact_span_x_m"),
		"/minimum_contact_span_x_m", errors)
	var minimum_span_z := _positive_float(
		configuration.get("minimum_contact_span_z_m"),
		"/minimum_contact_span_z_m", errors)
	var center_tolerance := _positive_float(
		configuration.get("center_cop_tolerance_m"),
		"/center_cop_tolerance_m", errors)
	var symmetry_tolerance := _positive_float(
		configuration.get("mirror_symmetry_tolerance_m"),
		"/mirror_symmetry_tolerance_m", errors)
	if minimum_span_x > 2.0 * half_width_x:
		_add_error(errors, "CONTACT_SPAN_X_IMPOSSIBLE",
			"/minimum_contact_span_x_m",
			"Minimum x span cannot exceed the authored pad width")
	if minimum_span_z > 2.0 * half_width_z:
		_add_error(errors, "CONTACT_SPAN_Z_IMPOSSIBLE",
			"/minimum_contact_span_z_m",
			"Minimum z span cannot exceed the authored pad width")
	if not errors.is_empty():
		return FrozenValueScript.snapshot({
			"ok": false, "errors": errors, "config": null})
	var config := {
		"schema_version": CONFIG_SCHEMA_VERSION,
		"required_offsets_x_m": offsets,
		"minimum_samples_per_trial": minimum_samples,
		"authored_half_width_x_m": half_width_x,
		"authored_half_width_z_m": half_width_z,
		"maximum_mean_cop_error_m": maximum_mean_cop_error,
		"maximum_normal_load_error_n": maximum_normal_load_error,
		"maximum_tilt_rad": maximum_tilt,
		"maximum_slip_speed_mps": maximum_slip,
		"maximum_displacement_m": maximum_displacement,
		"minimum_contact_span_x_m": minimum_span_x,
		"minimum_contact_span_z_m": minimum_span_z,
		"center_cop_tolerance_m": center_tolerance,
		"mirror_symmetry_tolerance_m": symmetry_tolerance,
		"raw_point_pressure_required": true,
		"independent_worlds_required": true,
		"continuous_force_claim_forbidden": true,
	}
	config["config_digest_sha256"] = CanonicalJsonScript.sha256(config)
	return FrozenValueScript.snapshot({
		"ok": true, "errors": [], "config": config})


static func analyze(config: Dictionary, trial_summaries: Array) -> Dictionary:
	if not _config_valid(config):
		return _invalid(["PAD_COP_CONFIG_INVALID"])
	var required_offsets: Array = config["required_offsets_x_m"]
	if trial_summaries.size() != required_offsets.size():
		return _invalid(["PAD_COP_TRIAL_COUNT_MISMATCH"])
	var reasons: Array[String] = []
	var maximum_cop_error := 0.0
	var maximum_load_error := 0.0
	var previous_cop_x := -INF
	var cops: Array[Vector3] = []
	for index in trial_summaries.size():
		var trial_value: Variant = trial_summaries[index]
		if not trial_value is Dictionary:
			reasons.append("PAD_COP_TRIAL_INVALID:%d" % index)
			cops.append(Vector3(INF, INF, INF))
			continue
		var trial: Dictionary = trial_value
		_validate_trial(config, trial, index, reasons)
		var offset := float(trial.get("custom_com_offset_x_m", NAN))
		if not is_finite(offset) \
				or absf(offset - float(required_offsets[index])) > 1.0e-9:
			reasons.append("PAD_COP_OFFSET_SCHEDULE_MISMATCH:%d" % index)
		var cop_value: Variant = trial.get("impulse_weighted_mean_cop_world_m")
		var cop := (
			cop_value as Vector3
			if cop_value is Vector3 else Vector3(INF, INF, INF))
		cops.append(cop)
		if cop.is_finite():
			if cop.x <= previous_cop_x:
				reasons.append("PAD_COP_RESPONSE_NOT_STRICTLY_MONOTONIC:%d" % index)
			previous_cop_x = cop.x
		maximum_cop_error = maxf(
			maximum_cop_error,
			float(trial.get("mean_cop_projection_error_m", INF)))
		maximum_load_error = maxf(
			maximum_load_error,
			absf(float(trial.get("mean_predicted_normal_load_n", INF))
				- float(trial.get("mean_expected_gravity_load_n", -INF))))
	if reasons.is_empty():
		_validate_center_and_symmetry(config, required_offsets, cops, reasons)
	if not reasons.is_empty():
		return _invalid(reasons)
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": true,
		"admitted": true,
		"invalid_reasons": [],
		"config_digest_sha256": String(config["config_digest_sha256"]),
		"trial_count": trial_summaries.size(),
		"maximum_mean_cop_projection_error_m": maximum_cop_error,
		"maximum_mean_normal_load_error_n": maximum_load_error,
		"cop_response_strictly_monotonic": true,
		"center_and_mirror_checks_passed": true,
		"interpretation": "static_free_pad_predicted_impulse_cop_calibration_v1",
		"does_not_establish": [
			"exact_continuous_contact_force",
			"dynamic_center_of_pressure",
			"compliant_or_articulated_foot_pressure",
			"load_bearing_limb",
			"bracing",
			"standing",
			"walking",
		],
	})


static func _validate_trial(
		config: Dictionary,
		trial: Dictionary,
		index: int,
		reasons: Array[String]) -> void:
	if String(trial.get("trial_id", "")).is_empty():
		reasons.append("PAD_COP_TRIAL_ID_INVALID:%d" % index)
	if typeof(trial.get("valid_sample_count")) != TYPE_INT \
			or int(trial.get("valid_sample_count", 0)) \
			< int(config["minimum_samples_per_trial"]):
		reasons.append("PAD_COP_SAMPLE_WINDOW_INCOMPLETE:%d" % index)
	if trial.get("capacity_complete") != true:
		reasons.append("PAD_COP_CONTACT_CAPACITY_INCOMPLETE:%d" % index)
	var cop_value: Variant = trial.get("impulse_weighted_mean_cop_world_m")
	if not cop_value is Vector3 or not (cop_value as Vector3).is_finite():
		reasons.append("PAD_COP_MEAN_INVALID:%d" % index)
	for field in [
		"support_half_width_x_m",
		"support_half_width_z_m",
		"mean_predicted_normal_load_n",
		"mean_expected_gravity_load_n",
		"mean_cop_projection_error_m",
		"max_cop_x_error_m",
		"max_cop_z_error_m",
		"minimum_contact_span_x_m",
		"minimum_contact_span_z_m",
		"max_tilt_rad",
		"max_post_step_slip_speed_mps",
		"body_displacement_m",
	]:
		var value := float(trial.get(field, NAN))
		if not is_finite(value) or value < 0.0:
			reasons.append("PAD_COP_%s_INVALID:%d" % [field.to_upper(), index])
	if absf(float(trial.get("support_half_width_x_m", INF))
			- float(config["authored_half_width_x_m"])) > 1.0e-6 \
			or absf(float(trial.get("support_half_width_z_m", INF))
			- float(config["authored_half_width_z_m"])) > 1.0e-6:
		reasons.append("PAD_COP_FOOTPRINT_MISMATCH:%d" % index)
	if float(trial.get("mean_cop_projection_error_m", INF)) \
			> float(config["maximum_mean_cop_error_m"]):
		reasons.append("PAD_COP_PROJECTION_ERROR_EXCEEDED:%d" % index)
	if absf(float(trial.get("mean_predicted_normal_load_n", INF))
			- float(trial.get("mean_expected_gravity_load_n", -INF))) \
			> float(config["maximum_normal_load_error_n"]):
		reasons.append("PAD_COP_NORMAL_LOAD_ERROR_EXCEEDED:%d" % index)
	if float(trial.get("max_tilt_rad", INF)) > float(config["maximum_tilt_rad"]):
		reasons.append("PAD_COP_TILT_CONTAMINATION:%d" % index)
	if float(trial.get("max_post_step_slip_speed_mps", INF)) \
			> float(config["maximum_slip_speed_mps"]):
		reasons.append("PAD_COP_SLIP_CONTAMINATION:%d" % index)
	if float(trial.get("body_displacement_m", INF)) \
			> float(config["maximum_displacement_m"]):
		reasons.append("PAD_COP_DISPLACEMENT_CONTAMINATION:%d" % index)
	if float(trial.get("minimum_contact_span_x_m", -INF)) \
			< float(config["minimum_contact_span_x_m"]) \
			or float(trial.get("minimum_contact_span_z_m", -INF)) \
			< float(config["minimum_contact_span_z_m"]):
		reasons.append("PAD_COP_MANIFOLD_SPAN_INCOMPLETE:%d" % index)


static func _validate_center_and_symmetry(
		config: Dictionary,
		offsets: Array,
		cops: Array[Vector3],
		reasons: Array[String]) -> void:
	var center_found := false
	for index in offsets.size():
		if absf(float(offsets[index])) <= 1.0e-9:
			center_found = true
			if absf(cops[index].x) > float(config["center_cop_tolerance_m"]) \
					or absf(cops[index].z) \
					> float(config["center_cop_tolerance_m"]):
				reasons.append("PAD_COP_CENTER_LOAD_NOT_CENTERED")
	if not center_found:
		reasons.append("PAD_COP_CENTER_TRIAL_MISSING")
	for left_index in offsets.size():
		var left_offset := float(offsets[left_index])
		if left_offset >= 0.0:
			continue
		for right_index in offsets.size():
			if absf(float(offsets[right_index]) + left_offset) <= 1.0e-9:
				if absf(cops[left_index].x + cops[right_index].x) \
						> float(config["mirror_symmetry_tolerance_m"]) \
						or absf(cops[left_index].z - cops[right_index].z) \
						> float(config["mirror_symmetry_tolerance_m"]):
					reasons.append("PAD_COP_MIRROR_SYMMETRY_FAILED:%d:%d" % [
						left_index, right_index])


static func _config_valid(config: Dictionary) -> bool:
	var exact_fields := [
		"authored_half_width_x_m",
		"authored_half_width_z_m",
		"center_cop_tolerance_m",
		"config_digest_sha256",
		"continuous_force_claim_forbidden",
		"independent_worlds_required",
		"maximum_displacement_m",
		"maximum_mean_cop_error_m",
		"maximum_normal_load_error_n",
		"maximum_slip_speed_mps",
		"maximum_tilt_rad",
		"minimum_contact_span_x_m",
		"minimum_contact_span_z_m",
		"minimum_samples_per_trial",
		"mirror_symmetry_tolerance_m",
		"raw_point_pressure_required",
		"required_offsets_x_m",
		"schema_version",
	]
	var actual_fields: Array = config.keys()
	actual_fields.sort()
	if actual_fields != exact_fields \
			or String(config.get("schema_version", "")) != CONFIG_SCHEMA_VERSION \
			or typeof(config.get("minimum_samples_per_trial")) != TYPE_INT \
			or int(config.get("minimum_samples_per_trial", 0)) <= 0 \
			or not config.get("required_offsets_x_m") is Array \
			or config.get("raw_point_pressure_required") != true \
			or config.get("independent_worlds_required") != true \
			or config.get("continuous_force_claim_forbidden") != true:
		return false
	var digest := String(config.get("config_digest_sha256", ""))
	var payload := config.duplicate(true)
	payload.erase("config_digest_sha256")
	return digest.begins_with("sha256:") and digest.length() == 71 \
		and digest == CanonicalJsonScript.sha256(payload)


static func _invalid(reasons: Array[String]) -> Dictionary:
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": false,
		"admitted": false,
		"invalid_reasons": reasons,
	})


static func _number(value: Variant) -> float:
	return float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] else NAN


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
	var number := _number(value)
	if is_finite(number) and number > 0.0:
		return number
	_add_error(errors, "POSITIVE_FLOAT_REQUIRED", path,
		"Expected a finite positive number")
	return 0.0


static func _nonnegative_float(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> float:
	var number := _number(value)
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
