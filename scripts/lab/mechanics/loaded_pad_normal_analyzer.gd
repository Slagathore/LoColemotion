class_name LabLoadedPadNormalAnalyzer
extends RefCounted

## L3.0 exact-cell admission for a free single-shape pad under centered
## downward external load.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIG_SCHEMA_VERSION := "loaded_pad_normal_config_v1"
const RESULT_SCHEMA_VERSION := "loaded_pad_normal_analysis_v1"


static func build_config(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var loads_value: Variant = configuration.get("required_downward_loads_n")
	var loads: Array = []
	if loads_value is Array and (loads_value as Array).size() >= 3:
		var previous := -INF
		for index in (loads_value as Array).size():
			var value: Variant = (loads_value as Array)[index]
			var load := _number(value)
			if not is_finite(load) or load < 0.0 or load <= previous:
				_add_error(
					errors,
					"LOAD_SCHEDULE_INVALID",
					"/required_downward_loads_n/%d" % index,
					"Loads must be finite, nonnegative, and strictly increasing"
				)
			previous = load
			loads.append(load)
	else:
		_add_error(
			errors,
			"LOAD_SCHEDULE_INVALID",
			"/required_downward_loads_n",
			"At least three exact downward-load cells are required"
		)
	var minimum_samples := _positive_integer(
		configuration.get("minimum_samples_per_trial"), "/minimum_samples_per_trial", errors
	)
	var reconstruction_tolerance := _positive_float(
		configuration.get("maximum_reconstructed_load_error_n"),
		"/maximum_reconstructed_load_error_n",
		errors
	)
	var pressure_tolerance := _positive_float(
		configuration.get("maximum_predicted_load_error_n"),
		"/maximum_predicted_load_error_n",
		errors
	)
	var tilt_tolerance := _nonnegative_float(
		configuration.get("maximum_tilt_rad"), "/maximum_tilt_rad", errors
	)
	var slip_tolerance := _nonnegative_float(
		configuration.get("maximum_slip_speed_mps"), "/maximum_slip_speed_mps", errors
	)
	if not errors.is_empty():
		return FrozenValueScript.snapshot({"ok": false, "errors": errors, "config": null})
	var config := {
		"schema_version": CONFIG_SCHEMA_VERSION,
		"required_downward_loads_n": loads,
		"minimum_samples_per_trial": minimum_samples,
		"maximum_reconstructed_load_error_n": reconstruction_tolerance,
		"maximum_predicted_load_error_n": pressure_tolerance,
		"maximum_tilt_rad": tilt_tolerance,
		"maximum_slip_speed_mps": slip_tolerance,
		"force_application_method": "RigidBody3D.apply_force",
		"centered_force_required": true,
		"free_pad_required": true,
		"whole_system_reconstruction_required": true,
		"raw_pressure_is_cross_check_only": true,
	}
	config["config_digest_sha256"] = CanonicalJsonScript.sha256(config)
	return FrozenValueScript.snapshot({"ok": true, "errors": [], "config": config})


static func analyze(config: Dictionary, trial_summaries: Array) -> Dictionary:
	if not _config_valid(config):
		return _invalid(["LOADED_PAD_NORMAL_CONFIG_INVALID"])
	var required_loads: Array = config["required_downward_loads_n"]
	if trial_summaries.size() != required_loads.size():
		return _invalid(["LOADED_PAD_NORMAL_TRIAL_COUNT_MISMATCH"])
	var reasons: Array[String] = []
	var maximum_reconstruction_error := 0.0
	var maximum_pressure_error := 0.0
	var previous_support := -INF
	for index in trial_summaries.size():
		var trial_value: Variant = trial_summaries[index]
		if not trial_value is Dictionary:
			reasons.append("LOADED_PAD_NORMAL_TRIAL_INVALID:%d" % index)
			continue
		var trial: Dictionary = trial_value
		var load := float(trial.get("external_downward_load_n", NAN))
		if not is_finite(load) or absf(load - float(required_loads[index])) > 1.0e-9:
			reasons.append("LOADED_PAD_NORMAL_LOAD_SCHEDULE_MISMATCH:%d" % index)
		for field in [
			"mean_expected_support_load_n",
			"mean_reconstructed_support_load_n",
			"mean_predicted_contact_load_n",
			"maximum_reconstructed_load_error_n",
			"maximum_predicted_load_error_n",
			"maximum_tilt_rad",
			"maximum_slip_speed_mps",
		]:
			var value := float(trial.get(field, NAN))
			if not is_finite(value) or value < 0.0:
				reasons.append("LOADED_PAD_NORMAL_%s_INVALID:%d" % [field.to_upper(), index])
		if (
			typeof(trial.get("valid_sample_count")) != TYPE_INT
			or int(trial.get("valid_sample_count", 0)) < int(config["minimum_samples_per_trial"])
		):
			reasons.append("LOADED_PAD_NORMAL_SAMPLE_WINDOW_INCOMPLETE:%d" % index)
		if (
			trial.get("capacity_complete") != true
			or trial.get("free_pad_contract") != true
			or trial.get("centered_force_contract") != true
			or (
				int(trial.get("force_application_count", -1))
				!= int(trial.get("physics_tick_count", -2))
			)
		):
			reasons.append("LOADED_PAD_NORMAL_CONTRACT_INVALID:%d" % index)
		var reconstruction_error := float(trial.get("maximum_reconstructed_load_error_n", INF))
		var pressure_error := float(trial.get("maximum_predicted_load_error_n", INF))
		maximum_reconstruction_error = maxf(maximum_reconstruction_error, reconstruction_error)
		maximum_pressure_error = maxf(maximum_pressure_error, pressure_error)
		if reconstruction_error > float(config["maximum_reconstructed_load_error_n"]):
			reasons.append("LOADED_PAD_NORMAL_RECONSTRUCTION_ERROR_EXCEEDED:%d" % index)
		if pressure_error > float(config["maximum_predicted_load_error_n"]):
			reasons.append("LOADED_PAD_NORMAL_PRESSURE_ERROR_EXCEEDED:%d" % index)
		if float(trial.get("maximum_tilt_rad", INF)) > float(config["maximum_tilt_rad"]):
			reasons.append("LOADED_PAD_NORMAL_TILT_CONTAMINATION:%d" % index)
		if (
			float(trial.get("maximum_slip_speed_mps", INF))
			> float(config["maximum_slip_speed_mps"])
		):
			reasons.append("LOADED_PAD_NORMAL_SLIP_CONTAMINATION:%d" % index)
		var support := float(trial.get("mean_reconstructed_support_load_n", NAN))
		if not is_finite(support) or support <= previous_support:
			reasons.append("LOADED_PAD_NORMAL_RESPONSE_NOT_MONOTONIC:%d" % index)
		previous_support = support
	if not reasons.is_empty():
		return _invalid(reasons)
	return (
		FrozenValueScript
		. snapshot(
			{
				"schema_version": RESULT_SCHEMA_VERSION,
				"ok": true,
				"admitted": true,
				"invalid_reasons": [],
				"config_digest_sha256": config["config_digest_sha256"],
				"trial_count": trial_summaries.size(),
				"maximum_reconstructed_load_error_n": maximum_reconstruction_error,
				"maximum_predicted_load_error_n": maximum_pressure_error,
				"support_response_strictly_monotonic": true,
				"interpretation": "free_unary_pad_centered_external_load_v1",
				"does_not_establish":
				[
					"general_per_foot_load_allocation",
					"articulated_load_bearing_limb",
					"standing",
					"bracing",
					"fall_arrest",
					"getting_up",
					"gait",
					"walking",
				],
			}
		)
	)


static func _config_valid(config: Dictionary) -> bool:
	var fields: Array = config.keys()
	fields.sort()
	if (
		(
			fields
			!= [
				"centered_force_required",
				"config_digest_sha256",
				"force_application_method",
				"free_pad_required",
				"maximum_predicted_load_error_n",
				"maximum_reconstructed_load_error_n",
				"maximum_slip_speed_mps",
				"maximum_tilt_rad",
				"minimum_samples_per_trial",
				"raw_pressure_is_cross_check_only",
				"required_downward_loads_n",
				"schema_version",
				"whole_system_reconstruction_required",
			]
		)
		or String(config.get("schema_version", "")) != CONFIG_SCHEMA_VERSION
		or String(config.get("force_application_method", "")) != "RigidBody3D.apply_force"
		or config.get("centered_force_required") != true
		or config.get("free_pad_required") != true
		or config.get("whole_system_reconstruction_required") != true
		or config.get("raw_pressure_is_cross_check_only") != true
	):
		return false
	var payload := config.duplicate(true)
	payload.erase("config_digest_sha256")
	return String(config.get("config_digest_sha256", "")) == CanonicalJsonScript.sha256(payload)


static func _invalid(reasons: Array[String]) -> Dictionary:
	return (
		FrozenValueScript
		. snapshot(
			{
				"schema_version": RESULT_SCHEMA_VERSION,
				"ok": false,
				"admitted": false,
				"invalid_reasons": reasons,
			}
		)
	)


static func _positive_integer(value: Variant, path: String, errors: Array[Dictionary]) -> int:
	if typeof(value) == TYPE_INT and int(value) > 0:
		return int(value)
	_add_error(errors, "POSITIVE_INTEGER_REQUIRED", path, "Expected a positive integer")
	return 0


static func _positive_float(value: Variant, path: String, errors: Array[Dictionary]) -> float:
	var number := _number(value)
	if is_finite(number) and number > 0.0:
		return number
	_add_error(errors, "POSITIVE_FLOAT_REQUIRED", path, "Expected a finite positive number")
	return 0.0


static func _nonnegative_float(value: Variant, path: String, errors: Array[Dictionary]) -> float:
	var number := _number(value)
	if is_finite(number) and number >= 0.0:
		return number
	_add_error(errors, "NONNEGATIVE_FLOAT_REQUIRED", path, "Expected a finite nonnegative number")
	return 0.0


static func _number(value: Variant) -> float:
	return float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] else NAN


static func _add_error(
	errors: Array[Dictionary], code: String, path: String, message: String
) -> void:
	errors.append({"code": code, "path": path, "message": message})
