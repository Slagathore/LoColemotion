class_name LabMassRatioStabilityAnalyzer
extends RefCounted

## L1.7 exact-cell directed mass-ratio stability analysis.
##
## The analyzer classifies body-state/contact metrics first, then derives the
## measured directional boundary. Ratio itself is never a pass/fail gate. A
## 1024:1 accepted cell is an admitted measured point, not an infinite upper
## bound and not evidence about joints or articulated parent/child systems.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const CONFIG_SCHEMA_VERSION := "mass_ratio_stability_config_v1"
const RESULT_SCHEMA_VERSION := "mass_ratio_stability_analysis_v1"
const ACCEPTED := "ACCEPTED"
const REJECTED := "REJECTED"


static func build_config(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var cells := _mass_ratio_cells(
		configuration.get("required_cells"), "/required_cells", errors)
	var total_mass := _positive_float(
		configuration.get("fixed_total_mass_kg"),
		"/fixed_total_mass_kg", errors)
	var total_mass_tolerance := _positive_float(
		configuration.get("total_mass_tolerance_kg"),
		"/total_mass_tolerance_kg", errors)
	var ratio_tolerance := _positive_float(
		configuration.get("mass_ratio_tolerance"),
		"/mass_ratio_tolerance", errors)
	var minimum_contact_fraction := _fraction(
		configuration.get("minimum_contact_fraction"),
		"/minimum_contact_fraction", errors)
	var thresholds := {
		"maximum_center_height_error_m": _positive_float(
			configuration.get("maximum_center_height_error_m"),
			"/maximum_center_height_error_m", errors),
		"maximum_pair_vertical_error_m": _positive_float(
			configuration.get("maximum_pair_vertical_error_m"),
			"/maximum_pair_vertical_error_m", errors),
		"maximum_pair_penetration_m": _positive_float(
			configuration.get("maximum_pair_penetration_m"),
			"/maximum_pair_penetration_m", errors),
		"maximum_floor_penetration_m": _positive_float(
			configuration.get("maximum_floor_penetration_m"),
			"/maximum_floor_penetration_m", errors),
		"maximum_linear_speed_mps": _positive_float(
			configuration.get("maximum_linear_speed_mps"),
			"/maximum_linear_speed_mps", errors),
		"maximum_angular_speed_rad_s": _positive_float(
			configuration.get("maximum_angular_speed_rad_s"),
			"/maximum_angular_speed_rad_s", errors),
		"maximum_tilt_rad": _positive_float(
			configuration.get("maximum_tilt_rad"),
			"/maximum_tilt_rad", errors),
		"maximum_lateral_drift_m": _positive_float(
			configuration.get("maximum_lateral_drift_m"),
			"/maximum_lateral_drift_m", errors),
		"maximum_pair_relative_speed_mps": _positive_float(
			configuration.get("maximum_pair_relative_speed_mps"),
			"/maximum_pair_relative_speed_mps", errors),
		"maximum_linear_kinetic_energy_j": _positive_float(
			configuration.get("maximum_linear_kinetic_energy_j"),
			"/maximum_linear_kinetic_energy_j", errors),
		"maximum_reconstructed_load_error_n": _positive_float(
			configuration.get("maximum_reconstructed_load_error_n"),
			"/maximum_reconstructed_load_error_n", errors),
		"maximum_raw_load_fraction_error": _positive_float(
			configuration.get("maximum_raw_load_fraction_error"),
			"/maximum_raw_load_fraction_error", errors),
	}
	if not errors.is_empty():
		return FrozenValueScript.snapshot({
			"ok": false, "errors": errors, "config": null})
	var config := {
		"schema_version": CONFIG_SCHEMA_VERSION,
		"required_cells": cells,
		"fixed_total_mass_kg": total_mass,
		"total_mass_tolerance_kg": total_mass_tolerance,
		"mass_ratio_tolerance": ratio_tolerance,
		"minimum_contact_fraction": minimum_contact_fraction,
		"maximum_center_height_error_m": thresholds[
			"maximum_center_height_error_m"],
		"maximum_pair_vertical_error_m": thresholds[
			"maximum_pair_vertical_error_m"],
		"maximum_pair_penetration_m": thresholds[
			"maximum_pair_penetration_m"],
		"maximum_floor_penetration_m": thresholds[
			"maximum_floor_penetration_m"],
		"maximum_linear_speed_mps": thresholds["maximum_linear_speed_mps"],
		"maximum_angular_speed_rad_s": thresholds[
			"maximum_angular_speed_rad_s"],
		"maximum_tilt_rad": thresholds["maximum_tilt_rad"],
		"maximum_lateral_drift_m": thresholds["maximum_lateral_drift_m"],
		"maximum_pair_relative_speed_mps": thresholds[
			"maximum_pair_relative_speed_mps"],
		"maximum_linear_kinetic_energy_j": thresholds[
			"maximum_linear_kinetic_energy_j"],
		"maximum_reconstructed_load_error_n": thresholds[
			"maximum_reconstructed_load_error_n"],
		"maximum_raw_load_fraction_error": thresholds[
			"maximum_raw_load_fraction_error"],
		"fixed_total_mass_required": true,
		"fresh_space_per_cell_required": true,
		"tagged_activation_warmup_required": true,
		"exact_cell_admission_only": true,
		"ratio_is_not_a_classification_gate": true,
		"whole_system_load_reconstruction_required": true,
		"raw_bottom_load_fraction_model_required": true,
		"joint_count_required": 0,
	}
	config["config_digest_sha256"] = CanonicalJsonScript.sha256(config)
	return FrozenValueScript.snapshot({
		"ok": true, "errors": [], "config": config})


static func analyze(config: Dictionary, trial_summaries: Array) -> Dictionary:
	if not _config_valid(config):
		return _invalid(["MASS_RATIO_CONFIG_INVALID"], [])
	var required_cells: Array = config["required_cells"]
	if trial_summaries.size() != required_cells.size():
		return _invalid(["MASS_RATIO_TRIAL_COUNT_MISMATCH"], [])
	var fatal: Array[String] = []
	var classified: Array = []
	var accepted_ids: Array[String] = []
	var rejected_ids: Array[String] = []
	var raw_model_valid := true
	for index in trial_summaries.size():
		var trial_value: Variant = trial_summaries[index]
		if not trial_value is Dictionary:
			fatal.append("MASS_RATIO_TRIAL_INVALID:%d" % index)
			continue
		var trial: Dictionary = trial_value
		var required: Dictionary = required_cells[index]
		var validation := _validate_trial(config, trial, required, index)
		fatal.append_array(validation["fatal_reasons"] as Array[String])
		var classification := String(validation["classification"])
		var result := trial.duplicate(true)
		result["classification"] = classification
		result["rejection_reasons"] = validation["rejection_reasons"]
		classified.append(result)
		if classification == ACCEPTED:
			accepted_ids.append(String(trial.get("cell_id", "")))
		else:
			rejected_ids.append(String(trial.get("cell_id", "")))
		raw_model_valid = (
			float(trial.get("raw_load_fraction_error", INF))
				<= float(config["maximum_raw_load_fraction_error"])
			and raw_model_valid)
	if not fatal.is_empty():
		return _invalid(fatal, classified)
	if not raw_model_valid:
		return _invalid(["MASS_RATIO_RAW_LOAD_MODEL_MISMATCH"], classified)

	var neutral_accepted := false
	var top_results: Array = []
	var bottom_results: Array = []
	for result_value in classified:
		var result: Dictionary = result_value
		match String(result["heavy_body"]):
			"neutral":
				neutral_accepted = String(result["classification"]) == ACCEPTED
			"top":
				top_results.append(result)
			"bottom":
				bottom_results.append(result)
	if not neutral_accepted:
		return _invalid(["MASS_RATIO_NEUTRAL_CONTROL_REJECTED"], classified)

	var maximum_accepted_top_ratio := -1.0
	var minimum_rejected_top_ratio := INF
	var top_contiguous_prefix := true
	var rejection_seen := false
	for result_value in top_results:
		var result: Dictionary = result_value
		var ratio := float(result["heavy_to_light_ratio"])
		if String(result["classification"]) == ACCEPTED:
			maximum_accepted_top_ratio = maxf(maximum_accepted_top_ratio, ratio)
			if rejection_seen:
				top_contiguous_prefix = false
		else:
			minimum_rejected_top_ratio = minf(minimum_rejected_top_ratio, ratio)
			rejection_seen = true
	var maximum_measured_accepted_bottom_ratio := -1.0
	var bottom_all_accepted := true
	for result_value in bottom_results:
		var result: Dictionary = result_value
		if String(result["classification"]) == ACCEPTED:
			maximum_measured_accepted_bottom_ratio = maxf(
				maximum_measured_accepted_bottom_ratio,
				float(result["heavy_to_light_ratio"]))
		else:
			bottom_all_accepted = false
	var first_directional_divergence_ratio := INF
	for top_value in top_results:
		var top_result: Dictionary = top_value
		var bottom_result := _result_at_ratio(
			bottom_results, float(top_result["heavy_to_light_ratio"]))
		if not bottom_result.is_empty() \
				and String(top_result["classification"]) \
				!= String(bottom_result["classification"]):
			first_directional_divergence_ratio = minf(
				first_directional_divergence_ratio,
				float(top_result["heavy_to_light_ratio"]))
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": true,
		"grid_complete": true,
		"invalid_reasons": [],
		"config_digest_sha256": String(config["config_digest_sha256"]),
		"classified_cells": classified,
		"accepted_cell_count": accepted_ids.size(),
		"accepted_cell_ids": accepted_ids,
		"rejected_cell_ids": rejected_ids,
		"neutral_control_accepted": neutral_accepted,
		"maximum_accepted_top_heavy_ratio": maximum_accepted_top_ratio,
		"minimum_rejected_top_heavy_ratio": (
			minimum_rejected_top_ratio
			if is_finite(minimum_rejected_top_ratio) else null),
		"top_heavy_response_contiguous_accepted_prefix": top_contiguous_prefix,
		"bottom_heavy_all_measured_cells_accepted": bottom_all_accepted,
		"maximum_measured_accepted_bottom_heavy_ratio": (
			maximum_measured_accepted_bottom_ratio),
		"bottom_heavy_upper_boundary_status": "open_beyond_measured_grid",
		"first_directional_class_divergence_ratio": (
			first_directional_divergence_ratio
			if is_finite(first_directional_divergence_ratio) else null),
		"raw_bottom_load_tracks_bottom_mass_fraction": raw_model_valid,
		"raw_load_interpretation": (
			"local_bottom_body_weight_diagnostic_not_transmitted_stack_load"),
		"interpolation_policy": "forbidden_exact_cells_only",
		"interpretation": "directed_two_body_contact_stack_mass_ratio_v1",
		"does_not_establish": [
			"unmeasured_mass_ratios",
			"bottom_heavy_failure_boundary",
			"articulated_mass_ratio_envelope",
			"joint_constraint_stability",
			"per_contact_reconstructed_load_allocation",
			"load_bearing_limb",
			"bracing",
			"standing",
			"walking",
		],
	})


static func _validate_trial(
		config: Dictionary,
		trial: Dictionary,
		required: Dictionary,
		index: int) -> Dictionary:
	var fatal: Array[String] = []
	var rejection: Array[String] = []
	for field in ["cell_id", "heavy_to_light_ratio", "heavy_body"]:
		if trial.get(field) != required.get(field):
			fatal.append("MASS_RATIO_CELL_SCHEDULE_MISMATCH:%d:%s" % [
				index, field])
	if trial.get("fresh_own_world_3d") != true \
			or trial.get("tagged_world_activation_warmup_excluded") != true:
		fatal.append("MASS_RATIO_WORLD_LIFECYCLE_UNPROVEN:%d" % index)
	if trial.get("all_body_samples_finite") != true \
			or trial.get("capacity_complete") != true:
		fatal.append("MASS_RATIO_OBSERVER_INCOMPLETE:%d" % index)
	if int(trial.get("joint_count", -1)) != int(config["joint_count_required"]):
		fatal.append("MASS_RATIO_JOINT_COUNT_MISMATCH:%d" % index)
	if int(trial.get("reconstructed_sample_count", -1)) \
			!= int(trial.get("expected_analysis_sample_count", -2)):
		fatal.append("MASS_RATIO_RECONSTRUCTION_INCOMPLETE:%d" % index)
	var bottom_mass := float(trial.get("bottom_mass_kg", NAN))
	var top_mass := float(trial.get("top_mass_kg", NAN))
	var total_mass := float(trial.get("total_mass_kg", NAN))
	var ratio := float(trial.get("heavy_to_light_ratio", NAN))
	if not is_finite(bottom_mass) or bottom_mass <= 0.0 \
			or not is_finite(top_mass) or top_mass <= 0.0 \
			or not is_finite(total_mass) or total_mass <= 0.0:
		fatal.append("MASS_RATIO_MASS_INVALID:%d" % index)
	else:
		if absf(total_mass - float(config["fixed_total_mass_kg"])) \
				> float(config["total_mass_tolerance_kg"]) \
				or absf(bottom_mass + top_mass - total_mass) \
				> float(config["total_mass_tolerance_kg"]):
			fatal.append("MASS_RATIO_TOTAL_MASS_MISMATCH:%d" % index)
		if absf(maxf(bottom_mass, top_mass) / minf(bottom_mass, top_mass)
				- ratio) > float(config["mass_ratio_tolerance"]):
			fatal.append("MASS_RATIO_BODY_MASS_RATIO_MISMATCH:%d" % index)
		match String(trial.get("heavy_body", "")):
			"neutral":
				if absf(bottom_mass - top_mass) \
						> float(config["total_mass_tolerance_kg"]):
					fatal.append("MASS_RATIO_NEUTRAL_MASSES_MISMATCH:%d" % index)
			"top":
				if top_mass <= bottom_mass:
					fatal.append("MASS_RATIO_DIRECTION_MISMATCH:%d" % index)
			"bottom":
				if bottom_mass <= top_mass:
					fatal.append("MASS_RATIO_DIRECTION_MISMATCH:%d" % index)
	var numeric_fields := [
		"floor_pressure_contact_fraction",
		"pair_contact_fraction",
		"mean_reconstructed_load_error_n",
		"raw_load_fraction_error",
		"maximum_center_height_error_m",
		"maximum_pair_vertical_error_m",
		"maximum_pair_penetration_m",
		"maximum_floor_penetration_m",
		"maximum_linear_speed_mps",
		"maximum_angular_speed_rad_s",
		"maximum_tilt_rad",
		"maximum_lateral_drift_m",
		"maximum_pair_relative_speed_mps",
		"maximum_linear_kinetic_energy_j",
	]
	for field in numeric_fields:
		var value := float(trial.get(field, NAN))
		if not is_finite(value) or value < 0.0:
			fatal.append("MASS_RATIO_METRIC_INVALID:%d:%s" % [index, field])
	if not fatal.is_empty():
		return {
			"classification": REJECTED,
			"fatal_reasons": fatal,
			"rejection_reasons": rejection,
		}
	if float(trial["floor_pressure_contact_fraction"]) \
			< float(config["minimum_contact_fraction"]):
		rejection.append("FLOOR_CONTACT_FRACTION_BELOW_MINIMUM")
	if float(trial["pair_contact_fraction"]) \
			< float(config["minimum_contact_fraction"]):
		rejection.append("PAIR_CONTACT_FRACTION_BELOW_MINIMUM")
	var gates := [
		["CENTER_HEIGHT_ERROR_EXCEEDED", "maximum_center_height_error_m",
			"maximum_center_height_error_m"],
		["PAIR_VERTICAL_ERROR_EXCEEDED", "maximum_pair_vertical_error_m",
			"maximum_pair_vertical_error_m"],
		["PAIR_PENETRATION_EXCEEDED", "maximum_pair_penetration_m",
			"maximum_pair_penetration_m"],
		["FLOOR_PENETRATION_EXCEEDED", "maximum_floor_penetration_m",
			"maximum_floor_penetration_m"],
		["LINEAR_SPEED_EXCEEDED", "maximum_linear_speed_mps",
			"maximum_linear_speed_mps"],
		["ANGULAR_SPEED_EXCEEDED", "maximum_angular_speed_rad_s",
			"maximum_angular_speed_rad_s"],
		["TILT_EXCEEDED", "maximum_tilt_rad", "maximum_tilt_rad"],
		["LATERAL_DRIFT_EXCEEDED", "maximum_lateral_drift_m",
			"maximum_lateral_drift_m"],
		["PAIR_RELATIVE_SPEED_EXCEEDED", "maximum_pair_relative_speed_mps",
			"maximum_pair_relative_speed_mps"],
		["LINEAR_KINETIC_ENERGY_EXCEEDED", "maximum_linear_kinetic_energy_j",
			"maximum_linear_kinetic_energy_j"],
		["RECONSTRUCTED_LOAD_ERROR_EXCEEDED",
			"mean_reconstructed_load_error_n",
			"maximum_reconstructed_load_error_n"],
		["RAW_LOAD_FRACTION_ERROR_EXCEEDED", "raw_load_fraction_error",
			"maximum_raw_load_fraction_error"],
	]
	for gate_value in gates:
		var gate: Array = gate_value
		if float(trial[String(gate[1])]) > float(config[String(gate[2])]):
			rejection.append(String(gate[0]))
	return {
		"classification": ACCEPTED if rejection.is_empty() else REJECTED,
		"fatal_reasons": fatal,
		"rejection_reasons": rejection,
	}


static func _config_valid(config: Dictionary) -> bool:
	var exact_fields := [
		"config_digest_sha256",
		"exact_cell_admission_only",
		"fixed_total_mass_kg",
		"fixed_total_mass_required",
		"fresh_space_per_cell_required",
		"joint_count_required",
		"mass_ratio_tolerance",
		"maximum_angular_speed_rad_s",
		"maximum_center_height_error_m",
		"maximum_floor_penetration_m",
		"maximum_lateral_drift_m",
		"maximum_linear_kinetic_energy_j",
		"maximum_linear_speed_mps",
		"maximum_pair_penetration_m",
		"maximum_pair_relative_speed_mps",
		"maximum_pair_vertical_error_m",
		"maximum_raw_load_fraction_error",
		"maximum_reconstructed_load_error_n",
		"maximum_tilt_rad",
		"minimum_contact_fraction",
		"ratio_is_not_a_classification_gate",
		"raw_bottom_load_fraction_model_required",
		"required_cells",
		"schema_version",
		"tagged_activation_warmup_required",
		"total_mass_tolerance_kg",
		"whole_system_load_reconstruction_required",
	]
	var actual: Array = config.keys()
	actual.sort()
	if actual != exact_fields \
			or String(config.get("schema_version", "")) \
			!= CONFIG_SCHEMA_VERSION \
			or config.get("fixed_total_mass_required") != true \
			or config.get("fresh_space_per_cell_required") != true \
			or config.get("tagged_activation_warmup_required") != true \
			or config.get("exact_cell_admission_only") != true \
			or config.get("ratio_is_not_a_classification_gate") != true \
			or config.get("whole_system_load_reconstruction_required") != true \
			or config.get("raw_bottom_load_fraction_model_required") != true \
			or int(config.get("joint_count_required", -1)) != 0:
		return false
	var digest := String(config.get("config_digest_sha256", ""))
	var payload := config.duplicate(true)
	payload.erase("config_digest_sha256")
	return digest.begins_with("sha256:") and digest.length() == 71 \
		and digest == CanonicalJsonScript.sha256(payload)


static func _mass_ratio_cells(
		value: Variant, path: String, errors: Array[Dictionary]) -> Array:
	var result: Array = []
	var ids: Dictionary = {}
	var schedules: Dictionary = {}
	if not value is Array or (value as Array).is_empty():
		_add_error(errors, "MASS_RATIO_CELL_GRID_INVALID", path,
			"At least one mass-ratio cell is required")
		return result
	for index in (value as Array).size():
		var cell_value: Variant = (value as Array)[index]
		if not cell_value is Dictionary:
			_add_error(errors, "MASS_RATIO_CELL_INVALID",
				"%s/%d" % [path, index], "Each cell must be a dictionary")
			continue
		var cell: Dictionary = cell_value
		var cell_id := String(cell.get("cell_id", ""))
		var ratio := float(cell.get("heavy_to_light_ratio", NAN))
		var direction := String(cell.get("heavy_body", ""))
		var schedule_key := "%s:%s" % [str(ratio), direction]
		if cell.keys().size() != 3 or cell_id.is_empty() or ids.has(cell_id) \
				or not is_finite(ratio) or ratio < 1.0 \
				or direction not in ["neutral", "top", "bottom"] \
				or schedules.has(schedule_key) \
				or (is_equal_approx(ratio, 1.0) and direction != "neutral") \
				or (ratio > 1.0 and direction == "neutral"):
			_add_error(errors, "MASS_RATIO_CELL_INVALID",
				"%s/%d" % [path, index],
				"Cells require unique ID, ratio >= 1, and valid direction")
			continue
		ids[cell_id] = true
		schedules[schedule_key] = true
		result.append({
			"cell_id": cell_id,
			"heavy_to_light_ratio": ratio,
			"heavy_body": direction,
		})
	var neutral_count := 0
	for cell_value in result:
		var cell: Dictionary = cell_value
		if String(cell["heavy_body"]) == "neutral":
			neutral_count += 1
		elif not schedules.has("%s:%s" % [
				str(float(cell["heavy_to_light_ratio"])),
				"bottom" if String(cell["heavy_body"]) == "top" else "top"]):
			_add_error(errors, "MASS_RATIO_DIRECTION_PAIR_MISSING", path,
				"Every unequal ratio requires top-heavy and bottom-heavy cells")
	if neutral_count != 1:
		_add_error(errors, "MASS_RATIO_NEUTRAL_CONTROL_INVALID", path,
			"Exactly one neutral 1:1 control is required")
	return result


static func _result_at_ratio(results: Array, ratio: float) -> Dictionary:
	for result_value in results:
		var result: Dictionary = result_value
		if is_equal_approx(float(result["heavy_to_light_ratio"]), ratio):
			return result
	return {}


static func _positive_float(
		value: Variant, path: String, errors: Array[Dictionary]) -> float:
	var number := float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] else NAN
	if is_finite(number) and number > 0.0:
		return number
	_add_error(errors, "POSITIVE_FLOAT_REQUIRED", path,
		"Expected a finite positive number")
	return 0.0


static func _fraction(
		value: Variant, path: String, errors: Array[Dictionary]) -> float:
	var number := float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] else NAN
	if is_finite(number) and number >= 0.0 and number <= 1.0:
		return number
	_add_error(errors, "FRACTION_REQUIRED", path,
		"Expected a finite fraction inside [0, 1]")
	return 0.0


static func _invalid(reasons: Array[String], classified: Array) -> Dictionary:
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": false,
		"grid_complete": false,
		"invalid_reasons": reasons,
		"classified_cells": classified,
	})


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({"code": code, "path": path, "message": message})
