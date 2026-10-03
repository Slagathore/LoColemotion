class_name LabLoadedPadRockingAnalyzer
extends RefCounted

## L3.2 admission for a free rectangular pad loaded by one explicitly located
## downward force. The analytic static resultant is:
##
##     x_cop = F_external * x_application / (m * g + F_external)
##
## The result brackets the application offset at which that resultant reaches
## the authored support edge. It does not turn predicted contact impulses into
## a general wrench or per-foot load allocator.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIG_SCHEMA_VERSION := "loaded_pad_rocking_config_v1"
const RESULT_SCHEMA_VERSION := "loaded_pad_rocking_analysis_v1"
const STABLE := "STABLE"
const AMBIGUOUS := "AMBIGUOUS"
const TIPPING := "TIPPING"
const ORACLE_TOLERANCE := 1.0e-6


static func build_config(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var mass := _positive_float(configuration.get("pad_mass_kg"), "/pad_mass_kg", errors)
	var gravity := _positive_float(configuration.get("gravity_m_s2"), "/gravity_m_s2", errors)
	var load := _positive_float(
		configuration.get("external_downward_load_n"), "/external_downward_load_n", errors
	)
	var half_width := _positive_float(
		configuration.get("support_half_width_m"), "/support_half_width_m", errors
	)
	var schedule := _positive_schedule(
		configuration.get("required_application_offsets_x_m"),
		"/required_application_offsets_x_m",
		errors
	)
	var minimum_contact_samples := _positive_integer(
		configuration.get("minimum_contact_samples_per_trial"),
		"/minimum_contact_samples_per_trial",
		errors
	)
	var maximum_cop_error := _positive_float(
		configuration.get("maximum_stable_cop_error_m"), "/maximum_stable_cop_error_m", errors
	)
	var maximum_normal_error := _positive_float(
		configuration.get("maximum_stable_normal_load_error_n"),
		"/maximum_stable_normal_load_error_n",
		errors
	)
	var maximum_stable_tilt := _nonnegative_float(
		configuration.get("maximum_stable_tilt_rad"), "/maximum_stable_tilt_rad", errors
	)
	var maximum_stable_angular_speed := _nonnegative_float(
		configuration.get("maximum_stable_angular_speed_rad_s"),
		"/maximum_stable_angular_speed_rad_s",
		errors
	)
	var maximum_stable_displacement := _nonnegative_float(
		configuration.get("maximum_stable_displacement_m"), "/maximum_stable_displacement_m", errors
	)
	var minimum_tipping_tilt := _positive_float(
		configuration.get("minimum_tipping_tilt_rad"), "/minimum_tipping_tilt_rad", errors
	)
	var minimum_tipping_direction := _positive_float(
		configuration.get("minimum_tipping_directional_up_x"),
		"/minimum_tipping_directional_up_x",
		errors
	)
	var minimum_edge_cop_fraction := _positive_float(
		configuration.get("minimum_edge_cop_fraction"), "/minimum_edge_cop_fraction", errors
	)
	var maximum_pretip_slip := _nonnegative_float(
		configuration.get("maximum_pretip_slip_speed_mps"), "/maximum_pretip_slip_speed_mps", errors
	)
	if minimum_tipping_tilt <= maximum_stable_tilt:
		_add_error(
			errors,
			"TILT_HYSTERESIS_INVALID",
			"/minimum_tipping_tilt_rad",
			"Tipping tilt must exceed the stable tilt ceiling"
		)
	if minimum_tipping_direction > 1.0:
		_add_error(
			errors,
			"DIRECTIONAL_TILT_INVALID",
			"/minimum_tipping_directional_up_x",
			"Directional body-up magnitude cannot exceed one"
		)
	if minimum_edge_cop_fraction > 1.25:
		_add_error(
			errors,
			"EDGE_COP_FRACTION_INVALID",
			"/minimum_edge_cop_fraction",
			"The diagnostic CoP edge fraction cannot exceed 1.25"
		)
	if not errors.is_empty():
		return FrozenValueScript.snapshot({"ok": false, "errors": errors, "config": null})
	var total_normal := mass * gravity + load
	var config := {
		"schema_version": CONFIG_SCHEMA_VERSION,
		"pad_mass_kg": mass,
		"gravity_m_s2": gravity,
		"external_downward_load_n": load,
		"support_half_width_m": half_width,
		"required_application_offsets_x_m": schedule,
		"minimum_contact_samples_per_trial": minimum_contact_samples,
		"maximum_stable_cop_error_m": maximum_cop_error,
		"maximum_stable_normal_load_error_n": maximum_normal_error,
		"maximum_stable_tilt_rad": maximum_stable_tilt,
		"maximum_stable_angular_speed_rad_s": maximum_stable_angular_speed,
		"maximum_stable_displacement_m": maximum_stable_displacement,
		"minimum_tipping_tilt_rad": minimum_tipping_tilt,
		"minimum_tipping_directional_up_x": minimum_tipping_direction,
		"minimum_edge_cop_fraction": minimum_edge_cop_fraction,
		"maximum_pretip_slip_speed_mps": maximum_pretip_slip,
		"analytic_critical_application_offset_m": total_normal * half_width / load,
		"force_application_method": "RigidBody3D.apply_force",
		"independent_worlds_required": true,
		"free_pad_required": true,
		"whole_system_reconstruction_required": true,
		"raw_point_cop_is_predicted_cross_check": true,
	}
	config["config_digest_sha256"] = CanonicalJsonScript.sha256(config)
	return FrozenValueScript.snapshot({"ok": true, "errors": [], "config": config})


static func analyze(config: Dictionary, trial_summaries: Array) -> Dictionary:
	if not _config_valid(config):
		return _invalid(["LOADED_PAD_ROCKING_CONFIG_INVALID"], [])
	var schedule: Array = config["required_application_offsets_x_m"]
	if trial_summaries.size() != schedule.size():
		return _invalid(["LOADED_PAD_ROCKING_TRIAL_COUNT_MISMATCH"], [])
	var reasons: Array[String] = []
	var classified: Array = []
	var last_stable_index := -1
	var first_tipping_index := -1
	var stable_after_tipping := false
	for index in trial_summaries.size():
		var trial_value: Variant = trial_summaries[index]
		if not trial_value is Dictionary:
			reasons.append("LOADED_PAD_ROCKING_TRIAL_INVALID:%d" % index)
			continue
		var trial: Dictionary = trial_value
		var validation := _validate_trial(config, trial, float(schedule[index]), index)
		reasons.append_array(validation["reasons"] as Array[String])
		var classified_trial := trial.duplicate(true)
		classified_trial["classification"] = validation["classification"]
		classified.append(classified_trial)
		match String(validation["classification"]):
			STABLE:
				if first_tipping_index >= 0:
					stable_after_tipping = true
				else:
					last_stable_index = index
			TIPPING:
				if first_tipping_index < 0:
					first_tipping_index = index
	if stable_after_tipping:
		reasons.append("LOADED_PAD_ROCKING_STABLE_AFTER_TIPPING")
	if last_stable_index < 0:
		reasons.append("LOADED_PAD_ROCKING_NO_STABLE_TRIAL")
	if first_tipping_index < 0:
		reasons.append("LOADED_PAD_ROCKING_NO_TIPPING_TRIAL")
	if not reasons.is_empty():
		return _invalid(reasons, classified)
	var lower: Dictionary = classified[last_stable_index]
	var upper: Dictionary = classified[first_tipping_index]
	var critical := float(config["analytic_critical_application_offset_m"])
	var lower_offset := float(lower["application_offset_x_m"])
	var upper_offset := float(upper["application_offset_x_m"])
	if critical < lower_offset or critical > upper_offset:
		return _invalid(["LOADED_PAD_ROCKING_ANALYTIC_EDGE_OUTSIDE_BRACKET"], classified)
	return (
		FrozenValueScript
		. snapshot(
			{
				"schema_version": RESULT_SCHEMA_VERSION,
				"ok": true,
				"admitted": true,
				"threshold_detected": true,
				"invalid_reasons": [],
				"config_digest_sha256": config["config_digest_sha256"],
				"classified_trials": classified,
				"last_stable_trial_id": lower["trial_id"],
				"first_tipping_trial_id": upper["trial_id"],
				"threshold_application_offset_lower_m": lower_offset,
				"threshold_application_offset_upper_m": upper_offset,
				"threshold_bracket_width_m": upper_offset - lower_offset,
				"analytic_critical_application_offset_m": critical,
				"analytic_edge_inside_empirical_bracket": true,
				"interpretation": "free_unary_loaded_pad_rocking_edge_v1",
				"does_not_establish":
				[
					"general_per_foot_load_allocation",
					"general_contact_wrench_measurement",
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


static func _validate_trial(
	config: Dictionary, trial: Dictionary, required_offset: float, index: int
) -> Dictionary:
	var reasons: Array[String] = []
	var offset := float(trial.get("application_offset_x_m", NAN))
	if not is_finite(offset) or absf(offset - required_offset) > ORACLE_TOLERANCE:
		reasons.append("LOADED_PAD_ROCKING_OFFSET_SCHEDULE_MISMATCH:%d" % index)
	var total_normal := (
		float(config["pad_mass_kg"]) * float(config["gravity_m_s2"])
		+ float(config["external_downward_load_n"])
	)
	var predicted_cop := float(config["external_downward_load_n"]) * offset / total_normal
	var recorded_cop := float(trial.get("predicted_resultant_cop_x_m", NAN))
	if not is_finite(recorded_cop) or absf(recorded_cop - predicted_cop) > ORACLE_TOLERANCE:
		reasons.append("LOADED_PAD_ROCKING_RESULTANT_ORACLE_MISMATCH:%d" % index)
	var analytic_margin := float(config["support_half_width_m"]) - absf(predicted_cop)
	var recorded_margin := float(trial.get("analytic_support_margin_m", NAN))
	if not is_finite(recorded_margin) or absf(recorded_margin - analytic_margin) > ORACLE_TOLERANCE:
		reasons.append("LOADED_PAD_ROCKING_MARGIN_ORACLE_MISMATCH:%d" % index)
	if (
		typeof(trial.get("analytic_inside_support")) != TYPE_BOOL
		or bool(trial["analytic_inside_support"]) != (analytic_margin >= 0.0)
	):
		reasons.append("LOADED_PAD_ROCKING_ANALYTIC_CLASS_MISMATCH:%d" % index)
	if (
		trial.get("capacity_complete") != true
		or trial.get("free_pad_contract") != true
		or trial.get("force_offset_contract") != true
	):
		reasons.append("LOADED_PAD_ROCKING_CONTRACT_INVALID:%d" % index)
	for field in ["contact_sample_count", "cop_sample_count", "valid_reconstruction_sample_count"]:
		if (
			typeof(trial.get(field)) != TYPE_INT
			or int(trial.get(field, -1)) < int(config["minimum_contact_samples_per_trial"])
		):
			reasons.append("LOADED_PAD_ROCKING_%s_INCOMPLETE:%d" % [field.to_upper(), index])
	for field in [
		"max_tilt_rad",
		"final_tilt_rad",
		"max_angular_speed_rad_s",
		"max_directional_up_x",
		"max_directional_angular_speed_rad_s",
		"max_cop_toward_edge_fraction",
		"max_pretip_slip_speed_mps",
		"lateral_displacement_m",
	]:
		var value := float(trial.get(field, NAN))
		if not is_finite(value) or value < 0.0:
			reasons.append("LOADED_PAD_ROCKING_%s_INVALID:%d" % [field.to_upper(), index])
	if not reasons.is_empty():
		return {"classification": AMBIGUOUS, "reasons": reasons}
	var stable: bool = (
		float(trial["max_tilt_rad"]) <= float(config["maximum_stable_tilt_rad"])
		and float(trial["final_tilt_rad"]) <= float(config["maximum_stable_tilt_rad"])
		and (
			float(trial["max_angular_speed_rad_s"])
			<= float(config["maximum_stable_angular_speed_rad_s"])
		)
		and (
			float(trial["lateral_displacement_m"]) <= float(config["maximum_stable_displacement_m"])
		)
		and (
			float(trial.get("maximum_stable_normal_load_error_n", INF))
			<= float(config["maximum_stable_normal_load_error_n"])
		)
		and (
			float(trial.get("mean_stable_cop_error_m", INF))
			<= float(config["maximum_stable_cop_error_m"])
		)
	)
	var tipping: bool = (
		float(trial["max_tilt_rad"]) >= float(config["minimum_tipping_tilt_rad"])
		and (
			float(trial["max_directional_up_x"])
			>= float(config["minimum_tipping_directional_up_x"])
		)
		and float(trial["max_directional_angular_speed_rad_s"]) > 0.0
		and (
			float(trial["max_cop_toward_edge_fraction"])
			>= float(config["minimum_edge_cop_fraction"])
		)
		and (
			float(trial["max_pretip_slip_speed_mps"])
			<= float(config["maximum_pretip_slip_speed_mps"])
		)
		and trial.get("pivot_observed") == true
	)
	var classification := TIPPING if tipping else STABLE if stable else AMBIGUOUS
	if (
		((analytic_margin >= 0.0) and classification != STABLE)
		or ((analytic_margin < 0.0) and classification != TIPPING)
	):
		reasons.append("LOADED_PAD_ROCKING_PREDICTION_RESPONSE_MISMATCH:%d" % index)
	return {"classification": classification, "reasons": reasons}


static func _config_valid(config: Dictionary) -> bool:
	var fields: Array = config.keys()
	fields.sort()
	if (
		(
			fields
			!= [
				"analytic_critical_application_offset_m",
				"config_digest_sha256",
				"external_downward_load_n",
				"force_application_method",
				"free_pad_required",
				"gravity_m_s2",
				"independent_worlds_required",
				"maximum_pretip_slip_speed_mps",
				"maximum_stable_angular_speed_rad_s",
				"maximum_stable_cop_error_m",
				"maximum_stable_displacement_m",
				"maximum_stable_normal_load_error_n",
				"maximum_stable_tilt_rad",
				"minimum_contact_samples_per_trial",
				"minimum_edge_cop_fraction",
				"minimum_tipping_directional_up_x",
				"minimum_tipping_tilt_rad",
				"pad_mass_kg",
				"raw_point_cop_is_predicted_cross_check",
				"required_application_offsets_x_m",
				"schema_version",
				"support_half_width_m",
				"whole_system_reconstruction_required",
			]
		)
		or String(config.get("schema_version", "")) != CONFIG_SCHEMA_VERSION
		or String(config.get("force_application_method", "")) != "RigidBody3D.apply_force"
		or config.get("independent_worlds_required") != true
		or config.get("free_pad_required") != true
		or config.get("whole_system_reconstruction_required") != true
		or config.get("raw_point_cop_is_predicted_cross_check") != true
	):
		return false
	var payload := config.duplicate(true)
	payload.erase("config_digest_sha256")
	return String(config.get("config_digest_sha256", "")) == CanonicalJsonScript.sha256(payload)


static func _positive_schedule(value: Variant, path: String, errors: Array[Dictionary]) -> Array:
	var schedule: Array = []
	if not value is Array or (value as Array).size() < 3:
		_add_error(errors, "OFFSET_SCHEDULE_INVALID", path, "At least three offsets are required")
		return schedule
	var previous := -INF
	for index in (value as Array).size():
		var offset := _number((value as Array)[index])
		if not is_finite(offset) or offset < 0.0 or offset <= previous:
			_add_error(
				errors,
				"OFFSET_SCHEDULE_INVALID",
				"%s/%d" % [path, index],
				"Offsets must be finite, nonnegative, and strictly increasing"
			)
		previous = offset
		schedule.append(offset)
	return schedule


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


static func _invalid(reasons: Array[String], classified: Array) -> Dictionary:
	return (
		FrozenValueScript
		. snapshot(
			{
				"schema_version": RESULT_SCHEMA_VERSION,
				"ok": false,
				"admitted": false,
				"threshold_detected": false,
				"invalid_reasons": reasons,
				"classified_trials": classified,
			}
		)
	)


static func _add_error(
	errors: Array[Dictionary], code: String, path: String, message: String
) -> void:
	errors.append({"code": code, "path": path, "message": message})
