class_name LabSolverStepSensitivityAnalyzer
extends RefCounted

## L1.6 exact-cell solver sensitivity and coupled-load channel analysis.
##
## Solver iteration response is not assumed monotonic. The analyzer admits only
## measured cells, requires the project's current cell to pass, and reports
## whether the fixed-position velocity sweep changes class more than once.
## Interpolation remains forbidden even for a monotonic measured sweep because
## no unmeasured solver combination has supplied evidence. The analyzer also
## compares local raw predicted load with reconstructed whole-system external
## load so transmission blindness cannot be hidden.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const CONFIG_SCHEMA_VERSION := "solver_step_sensitivity_config_v1"
const RESULT_SCHEMA_VERSION := "solver_step_sensitivity_analysis_v1"
const ACCEPTED := "ACCEPTED"
const REJECTED := "REJECTED"


static func build_config(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var cells := _solver_cells(
		configuration.get("required_cells"), "/required_cells", errors)
	var minimum_accepted := _positive_integer(
		configuration.get("minimum_accepted_cell_count"),
		"/minimum_accepted_cell_count", errors)
	var project_velocity := _positive_integer(
		configuration.get("project_velocity_steps"),
		"/project_velocity_steps", errors)
	var project_position := _positive_integer(
		configuration.get("project_position_steps"),
		"/project_position_steps", errors)
	var thresholds := {
		"maximum_center_height_error_m": _positive_float(
			configuration.get("maximum_center_height_error_m"),
			"/maximum_center_height_error_m", errors),
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
		"maximum_reconstructed_load_error_n": _positive_float(
			configuration.get("maximum_reconstructed_load_error_n"),
			"/maximum_reconstructed_load_error_n", errors),
		"maximum_centered_cop_radius_m": _positive_float(
			configuration.get("maximum_centered_cop_radius_m"),
			"/maximum_centered_cop_radius_m", errors),
		"expected_raw_load_fraction": _positive_float(
			configuration.get("expected_raw_load_fraction"),
			"/expected_raw_load_fraction", errors),
		"raw_load_fraction_tolerance": _positive_float(
			configuration.get("raw_load_fraction_tolerance"),
			"/raw_load_fraction_tolerance", errors),
	}
	if minimum_accepted > cells.size():
		_add_error(errors, "MINIMUM_ACCEPTED_COUNT_IMPOSSIBLE",
			"/minimum_accepted_cell_count",
			"Accepted-cell minimum cannot exceed the required grid")
	var project_cell_found := false
	for cell_value in cells:
		var cell: Dictionary = cell_value
		if int(cell["velocity_steps"]) == project_velocity \
				and int(cell["position_steps"]) == project_position:
			project_cell_found = true
	if not project_cell_found:
		_add_error(errors, "PROJECT_CELL_MISSING", "/required_cells",
			"The current project solver configuration must be in the grid")
	if not errors.is_empty():
		return FrozenValueScript.snapshot({
			"ok": false, "errors": errors, "config": null})
	var config := {
		"schema_version": CONFIG_SCHEMA_VERSION,
		"required_cells": cells,
		"minimum_accepted_cell_count": minimum_accepted,
		"project_velocity_steps": project_velocity,
		"project_position_steps": project_position,
		"maximum_center_height_error_m": thresholds[
			"maximum_center_height_error_m"],
		"maximum_pair_penetration_m": thresholds[
			"maximum_pair_penetration_m"],
		"maximum_floor_penetration_m": thresholds[
			"maximum_floor_penetration_m"],
		"maximum_linear_speed_mps": thresholds["maximum_linear_speed_mps"],
		"maximum_angular_speed_rad_s": thresholds[
			"maximum_angular_speed_rad_s"],
		"maximum_tilt_rad": thresholds["maximum_tilt_rad"],
		"maximum_lateral_drift_m": thresholds["maximum_lateral_drift_m"],
		"maximum_reconstructed_load_error_n": thresholds[
			"maximum_reconstructed_load_error_n"],
		"maximum_centered_cop_radius_m": thresholds[
			"maximum_centered_cop_radius_m"],
		"expected_raw_load_fraction": thresholds["expected_raw_load_fraction"],
		"raw_load_fraction_tolerance": thresholds[
			"raw_load_fraction_tolerance"],
		"fresh_space_per_cell_required": true,
		"exact_cell_admission_only": true,
		"whole_system_load_reconstruction_required": true,
	}
	config["config_digest_sha256"] = CanonicalJsonScript.sha256(config)
	return FrozenValueScript.snapshot({
		"ok": true, "errors": [], "config": config})


static func analyze(config: Dictionary, trial_summaries: Array) -> Dictionary:
	if not _config_valid(config):
		return _invalid(["SOLVER_CONFIG_INVALID"], [])
	var required_cells: Array = config["required_cells"]
	if trial_summaries.size() != required_cells.size():
		return _invalid(["SOLVER_TRIAL_COUNT_MISMATCH"], [])
	var fatal: Array[String] = []
	var classified: Array = []
	var accepted_ids: Array[String] = []
	var rejected_ids: Array[String] = []
	var project_result: Dictionary = {}
	var raw_transmission_blind := true
	for index in trial_summaries.size():
		var trial_value: Variant = trial_summaries[index]
		if not trial_value is Dictionary:
			fatal.append("SOLVER_TRIAL_INVALID:%d" % index)
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
		var cell_id := String(trial.get("cell_id", ""))
		if classification == ACCEPTED:
			accepted_ids.append(cell_id)
		else:
			rejected_ids.append(cell_id)
		if int(trial.get("velocity_steps", -1)) \
				== int(config["project_velocity_steps"]) \
				and int(trial.get("position_steps", -1)) \
				== int(config["project_position_steps"]):
			project_result = result
		var ratio := float(trial.get(
			"raw_predicted_to_reconstructed_load_ratio", INF))
		raw_transmission_blind = (
			absf(ratio - float(config["expected_raw_load_fraction"]))
				<= float(config["raw_load_fraction_tolerance"])
			and raw_transmission_blind)
	if not fatal.is_empty():
		return _invalid(fatal, classified)
	var reasons: Array[String] = []
	if accepted_ids.size() < int(config["minimum_accepted_cell_count"]):
		reasons.append("SOLVER_ACCEPTED_CELL_COUNT_INSUFFICIENT")
	if project_result.is_empty() \
			or String(project_result.get("classification", "")) != ACCEPTED:
		reasons.append("SOLVER_PROJECT_CONFIGURATION_REJECTED")
	if not raw_transmission_blind:
		reasons.append("SOLVER_RAW_LOAD_FRACTION_ORACLE_MISMATCH")
	if not reasons.is_empty():
		return _invalid(reasons, classified)
	var velocity_classes: Array[String] = []
	for result_value in classified:
		var result: Dictionary = result_value
		if int(result["position_steps"]) == int(config["project_position_steps"]):
			velocity_classes.append(String(result["classification"]))
	var transitions := 0
	for index in range(1, velocity_classes.size()):
		if velocity_classes[index] != velocity_classes[index - 1]:
			transitions += 1
	var nonmonotonic := transitions > 1
	var minimum_position_at_project_velocity := -1
	for result_value in classified:
		var result: Dictionary = result_value
		if int(result["velocity_steps"]) == int(config["project_velocity_steps"]) \
				and String(result["classification"]) == ACCEPTED:
			var position_steps := int(result["position_steps"])
			if minimum_position_at_project_velocity < 0 \
					or position_steps < minimum_position_at_project_velocity:
				minimum_position_at_project_velocity = position_steps
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": true,
		"sensitivity_grid_complete": true,
		"invalid_reasons": [],
		"config_digest_sha256": String(config["config_digest_sha256"]),
		"classified_cells": classified,
		"accepted_cell_count": accepted_ids.size(),
		"accepted_cell_ids": accepted_ids,
		"rejected_cell_ids": rejected_ids,
		"project_cell_id": String(project_result["cell_id"]),
		"project_configuration_accepted": true,
		"velocity_response_nonmonotonic": nonmonotonic,
		"velocity_class_transition_count": transitions,
		"interpolation_policy": "forbidden_exact_cells_only",
		"interpolation_evidence": "absent_unmeasured_cells_forbidden",
		"minimum_accepted_position_steps_at_project_velocity": (
			minimum_position_at_project_velocity),
		"raw_predicted_load_transmission_blind": raw_transmission_blind,
		"project_raw_to_reconstructed_load_ratio": float(
			project_result["raw_predicted_to_reconstructed_load_ratio"]),
		"project_reconstructed_load_error_n": float(
			project_result["mean_reconstructed_load_error_n"]),
		"interpretation": "exact_solver_cells_for_equal_stack_and_load_channels_v1",
		"does_not_establish": [
			"solver_interpolation",
			"articulated_constraint_convergence",
			"per_contact_reconstructed_load_allocation",
			"mass_ratio_envelope",
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
	for field in ["cell_id", "velocity_steps", "position_steps"]:
		if trial.get(field) != required.get(field):
			fatal.append("SOLVER_CELL_SCHEDULE_MISMATCH:%d:%s" % [index, field])
	if trial.get("settings_readback_valid") != true \
			or trial.get("settings_change_boundary_observed") != true \
			or trial.get("fresh_own_world_3d") != true \
			or trial.get("world_constructed_after_setting_write") != true:
		fatal.append("SOLVER_SETTING_APPLICATION_UNPROVEN:%d" % index)
	if trial.get("capacity_complete") != true \
			or int(trial.get("valid_pressure_sample_count", -1)) \
			!= int(trial.get("expected_pressure_sample_count", -2)) \
			or int(trial.get("reconstructed_sample_count", -1)) \
			!= int(trial.get("expected_pressure_sample_count", -2)):
		fatal.append("SOLVER_OBSERVATION_INCOMPLETE:%d" % index)
	var cop_value: Variant = trial.get("impulse_weighted_bottom_cop_world_m")
	if not cop_value is Vector3 or not (cop_value as Vector3).is_finite():
		fatal.append("SOLVER_COP_INVALID:%d" % index)
	for field in [
		"mean_bottom_normal_load_n",
		"mean_reconstructed_external_normal_load_n",
		"expected_total_gravity_load_n",
		"mean_reconstructed_load_error_n",
		"raw_predicted_to_reconstructed_load_ratio",
		"maximum_linear_speed_mps",
		"maximum_angular_speed_rad_s",
		"maximum_tilt_rad",
		"maximum_center_height_error_m",
		"maximum_pair_penetration_m",
		"maximum_floor_penetration_m",
		"maximum_lateral_drift_m",
	]:
		var value := float(trial.get(field, NAN))
		if not is_finite(value) or value < 0.0:
			fatal.append("SOLVER_METRIC_INVALID:%d:%s" % [index, field])
	if not fatal.is_empty():
		return {
			"classification": REJECTED,
			"fatal_reasons": fatal,
			"rejection_reasons": rejection,
		}
	var cop: Vector3 = cop_value
	var gates := [
		["CENTER_HEIGHT_ERROR_EXCEEDED", "maximum_center_height_error_m",
			"maximum_center_height_error_m"],
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
		["RECONSTRUCTED_LOAD_ERROR_EXCEEDED", "mean_reconstructed_load_error_n",
			"maximum_reconstructed_load_error_n"],
	]
	for gate_value in gates:
		var gate: Array = gate_value
		if float(trial[String(gate[1])]) > float(config[String(gate[2])]):
			rejection.append(String(gate[0]))
	if Vector2(cop.x, cop.z).length() \
			> float(config["maximum_centered_cop_radius_m"]):
		rejection.append("CENTERED_COP_RADIUS_EXCEEDED")
	return {
		"classification": ACCEPTED if rejection.is_empty() else REJECTED,
		"fatal_reasons": fatal,
		"rejection_reasons": rejection,
	}


static func _config_valid(config: Dictionary) -> bool:
	var exact_fields := [
		"config_digest_sha256",
		"exact_cell_admission_only",
		"expected_raw_load_fraction",
		"fresh_space_per_cell_required",
		"maximum_angular_speed_rad_s",
		"maximum_center_height_error_m",
		"maximum_centered_cop_radius_m",
		"maximum_floor_penetration_m",
		"maximum_lateral_drift_m",
		"maximum_linear_speed_mps",
		"maximum_pair_penetration_m",
		"maximum_reconstructed_load_error_n",
		"maximum_tilt_rad",
		"minimum_accepted_cell_count",
		"project_position_steps",
		"project_velocity_steps",
		"raw_load_fraction_tolerance",
		"required_cells",
		"schema_version",
		"whole_system_load_reconstruction_required",
	]
	var actual: Array = config.keys()
	actual.sort()
	if actual != exact_fields \
			or String(config.get("schema_version", "")) != CONFIG_SCHEMA_VERSION \
			or not config.get("required_cells") is Array \
			or config.get("fresh_space_per_cell_required") != true \
			or config.get("exact_cell_admission_only") != true \
			or config.get("whole_system_load_reconstruction_required") != true:
		return false
	var digest := String(config.get("config_digest_sha256", ""))
	var payload := config.duplicate(true)
	payload.erase("config_digest_sha256")
	return digest.begins_with("sha256:") and digest.length() == 71 \
		and digest == CanonicalJsonScript.sha256(payload)


static func _solver_cells(
		value: Variant, path: String, errors: Array[Dictionary]) -> Array:
	var result: Array = []
	var ids: Dictionary = {}
	if not value is Array or (value as Array).is_empty():
		_add_error(errors, "SOLVER_CELL_GRID_INVALID", path,
			"At least one solver cell is required")
		return result
	for index in (value as Array).size():
		var cell_value: Variant = (value as Array)[index]
		if not cell_value is Dictionary:
			_add_error(errors, "SOLVER_CELL_INVALID", "%s/%d" % [path, index],
				"Each solver cell must be a dictionary")
			continue
		var cell: Dictionary = cell_value
		var cell_id := String(cell.get("cell_id", ""))
		var velocity := int(cell.get("velocity_steps", 0))
		var position := int(cell.get("position_steps", 0))
		if cell.keys().size() != 3 \
				or cell_id.is_empty() or ids.has(cell_id) \
				or typeof(cell.get("velocity_steps")) != TYPE_INT or velocity < 2 \
				or typeof(cell.get("position_steps")) != TYPE_INT or position < 1:
			_add_error(errors, "SOLVER_CELL_INVALID", "%s/%d" % [path, index],
				"Cells require unique ID, velocity >= 2, and position >= 1")
			continue
		ids[cell_id] = true
		result.append({
			"cell_id": cell_id,
			"velocity_steps": velocity,
			"position_steps": position,
		})
	return result


static func _invalid(reasons: Array[String], classified: Array) -> Dictionary:
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": false,
		"sensitivity_grid_complete": false,
		"invalid_reasons": reasons,
		"classified_cells": classified,
	})


static func _positive_integer(
		value: Variant, path: String, errors: Array[Dictionary]) -> int:
	if typeof(value) == TYPE_INT and int(value) > 0:
		return int(value)
	_add_error(errors, "POSITIVE_INTEGER_REQUIRED", path,
		"Expected a positive integer")
	return 0


static func _positive_float(
		value: Variant, path: String, errors: Array[Dictionary]) -> float:
	var number := float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] else NAN
	if is_finite(number) and number > 0.0:
		return number
	_add_error(errors, "POSITIVE_FLOAT_REQUIRED", path,
		"Expected a finite positive number")
	return 0.0


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({"code": code, "path": path, "message": message})
