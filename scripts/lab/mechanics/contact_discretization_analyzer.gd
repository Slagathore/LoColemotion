class_name LabContactDiscretizationAnalyzer
extends RefCounted

## L1.8 equal-area contact-discretization admission analysis.
##
## One rigid pad is compared across 1/4/16/64/100 collision elements. Cells
## fall into exactly three honest classes:
##  - measured_contact: complete raw-contact evidence under the frozen policy;
##  - policy_refused: the a-priori 4-points-per-element declaration exceeds the
##    frozen 256-point observation ceiling, so contact enumeration must refuse;
##  - reconstruction_only: the same geometry measured without contact
##    enumeration, supported by whole-system momentum reconstruction only.
##
## The pack's central measured truth is negative: summing raw predicted
## contact impulses across multiple same-body shape-pair manifolds does NOT
## produce the external support load. The one-manifold control sums to mg, but
## the live 4-element pad summed to about 4.0x mg and the 16-element pad to
## about 11.2x mg while whole-system momentum reconstruction stayed at mg.
## Raw per-element sums are therefore admitted only as characterized manifold
## diagnostics inside preregistered ratio brackets, never as a load partition.
## Runtime cost is recorded, not gated: wall-clock is not physics evidence.
## Unknown config fields, forged cell classes, and unmeasured counts fail
## closed. Elements are collision geometry only; they are never actuators.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const CONFIG_SCHEMA_VERSION := "contact_discretization_config_v1"
const RESULT_SCHEMA_VERSION := "contact_discretization_analysis_v1"
const CLASS_MEASURED := "measured_contact"
const CLASS_POLICY_REFUSED := "policy_refused"
const CLASS_RECONSTRUCTION := "reconstruction_only"


static func build_config(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var measured := _element_count_schedule(
		configuration.get("required_measured_element_counts"),
		"/required_measured_element_counts", errors)
	var refused := _element_count_schedule(
		configuration.get("required_policy_refused_element_counts"),
		"/required_policy_refused_element_counts", errors)
	var reconstruction := _element_count_schedule(
		configuration.get("required_reconstruction_only_element_counts"),
		"/required_reconstruction_only_element_counts", errors)
	for count_value in refused:
		if not reconstruction.has(count_value):
			_add_error(errors, "REFUSED_COUNT_NOT_RECONSTRUCTED",
				"/required_policy_refused_element_counts",
				"Every policy-refused count needs a reconstruction-only cell")
	for count_value in measured:
		if refused.has(count_value) or reconstruction.has(count_value):
			_add_error(errors, "ELEMENT_CLASS_OVERLAP",
				"/required_measured_element_counts",
				"One element count cannot belong to two evidence classes")
	var control := _positive_integer(
		configuration.get("control_element_count"),
		"/control_element_count", errors)
	if control > 0 and not measured.has(control):
		_add_error(errors, "CONTROL_CELL_NOT_MEASURED",
			"/control_element_count",
			"The single-pad control must be a measured contact cell")
	var ratio_brackets := _ratio_bracket_schedule(
		configuration.get("required_raw_sum_ratio_brackets"),
		measured, control, errors)
	var minimum_samples := _positive_integer(
		configuration.get("minimum_samples_per_cell"),
		"/minimum_samples_per_cell", errors)
	var pad_mass := _positive_float(
		configuration.get("authored_pad_mass_kg"),
		"/authored_pad_mass_kg", errors)
	var gravity := _positive_float(
		configuration.get("authored_gravity_mps2"),
		"/authored_gravity_mps2", errors)
	var points_per_element := _positive_integer(
		configuration.get("expected_raw_points_per_element"),
		"/expected_raw_points_per_element", errors)
	var safety_margin := _positive_integer(
		configuration.get("safety_margin_raw_points"),
		"/safety_margin_raw_points", errors)
	var policy_max := _positive_integer(
		configuration.get("contact_policy_max_cap_per_body"),
		"/contact_policy_max_cap_per_body", errors)
	var maximum_control_raw_error := _positive_float(
		configuration.get("maximum_control_raw_sum_error_n"),
		"/maximum_control_raw_sum_error_n", errors)
	var maximum_cop_error := _positive_float(
		configuration.get("maximum_cop_error_m"),
		"/maximum_cop_error_m", errors)
	var maximum_tilt := _nonnegative_float(
		configuration.get("maximum_tilt_rad"),
		"/maximum_tilt_rad", errors)
	var maximum_slip := _nonnegative_float(
		configuration.get("maximum_slip_speed_mps"),
		"/maximum_slip_speed_mps", errors)
	var maximum_displacement := _nonnegative_float(
		configuration.get("maximum_displacement_m"),
		"/maximum_displacement_m", errors)
	var maximum_element_ratio := _positive_float(
		configuration.get("maximum_element_manifold_load_ratio"),
		"/maximum_element_manifold_load_ratio", errors)
	var maximum_load_chatter := _positive_float(
		configuration.get("maximum_load_chatter_fraction"),
		"/maximum_load_chatter_fraction", errors)
	var maximum_presence_churn := _nonnegative_float(
		configuration.get("maximum_element_presence_churn_fraction"),
		"/maximum_element_presence_churn_fraction", errors)
	var maximum_control_divergence_load := _positive_float(
		configuration.get("maximum_control_divergence_load_n"),
		"/maximum_control_divergence_load_n", errors)
	var maximum_reconstructed_error := _positive_float(
		configuration.get("maximum_reconstructed_load_error_n"),
		"/maximum_reconstructed_load_error_n", errors)
	for count_value in refused:
		var demand := points_per_element * int(count_value) + safety_margin
		if policy_max > 0 and demand <= policy_max:
			_add_error(errors, "REFUSED_COUNT_ARITHMETIC_INVALID",
				"/required_policy_refused_element_counts",
				"Count %d does not actually exceed the declared policy ceiling"
					% int(count_value))
	for count_value in measured:
		var demand := points_per_element * int(count_value) + safety_margin
		if policy_max > 0 and demand > policy_max:
			_add_error(errors, "MEASURED_COUNT_EXCEEDS_POLICY",
				"/required_measured_element_counts",
				"Count %d cannot be measured under the declared policy ceiling"
					% int(count_value))
	if not errors.is_empty():
		return FrozenValueScript.snapshot({
			"ok": false, "errors": errors, "config": null})
	var config := {
		"schema_version": CONFIG_SCHEMA_VERSION,
		"required_measured_element_counts": measured,
		"required_policy_refused_element_counts": refused,
		"required_reconstruction_only_element_counts": reconstruction,
		"control_element_count": control,
		"required_raw_sum_ratio_brackets": ratio_brackets,
		"minimum_samples_per_cell": minimum_samples,
		"authored_pad_mass_kg": pad_mass,
		"authored_gravity_mps2": gravity,
		"expected_raw_points_per_element": points_per_element,
		"safety_margin_raw_points": safety_margin,
		"contact_policy_max_cap_per_body": policy_max,
		"maximum_control_raw_sum_error_n": maximum_control_raw_error,
		"maximum_cop_error_m": maximum_cop_error,
		"maximum_tilt_rad": maximum_tilt,
		"maximum_slip_speed_mps": maximum_slip,
		"maximum_displacement_m": maximum_displacement,
		"maximum_element_manifold_load_ratio": maximum_element_ratio,
		"maximum_load_chatter_fraction": maximum_load_chatter,
		"maximum_element_presence_churn_fraction": maximum_presence_churn,
		"maximum_control_divergence_load_n": maximum_control_divergence_load,
		"maximum_reconstructed_load_error_n": maximum_reconstructed_error,
		"runtime_cost_gated": false,
		"raw_sum_is_load_partition_forbidden": true,
		"elements_are_actuators_forbidden": true,
		"continuous_force_claim_forbidden": true,
	}
	config["config_digest_sha256"] = CanonicalJsonScript.sha256(config)
	return FrozenValueScript.snapshot({
		"ok": true, "errors": [], "config": config})


static func analyze(config: Dictionary, cell_summaries: Array) -> Dictionary:
	if not _config_valid(config):
		return _invalid(["CONTACT_DISCRETIZATION_CONFIG_INVALID"])
	var reasons: Array[String] = []
	var measured_cells: Dictionary = {}
	var refused_cells: Dictionary = {}
	var reconstruction_cells: Dictionary = {}
	for index in cell_summaries.size():
		var cell_value: Variant = cell_summaries[index]
		if not cell_value is Dictionary:
			reasons.append("DISCRETIZATION_CELL_INVALID:%d" % index)
			continue
		var cell: Dictionary = cell_value
		var element_count := int(cell.get("contact_element_count", -1))
		var cell_class := String(cell.get("cell_class", ""))
		match cell_class:
			CLASS_MEASURED:
				if not (config["required_measured_element_counts"] as Array).has(
						element_count) or measured_cells.has(element_count):
					reasons.append(
						"DISCRETIZATION_CELL_IDENTITY_INVALID:%d" % index)
					continue
				measured_cells[element_count] = cell
				_validate_measured_cell(config, cell, index, reasons)
			CLASS_POLICY_REFUSED:
				if not (config[
						"required_policy_refused_element_counts"] as Array).has(
						element_count) or refused_cells.has(element_count):
					reasons.append(
						"DISCRETIZATION_CELL_IDENTITY_INVALID:%d" % index)
					continue
				refused_cells[element_count] = cell
				_validate_refused_cell(config, cell, index, reasons)
			CLASS_RECONSTRUCTION:
				if not (config[
						"required_reconstruction_only_element_counts"] as Array).has(
						element_count) \
						or reconstruction_cells.has(element_count):
					reasons.append(
						"DISCRETIZATION_CELL_IDENTITY_INVALID:%d" % index)
					continue
				reconstruction_cells[element_count] = cell
				_validate_reconstruction_cell(config, cell, index, reasons)
			_:
				reasons.append("DISCRETIZATION_CELL_CLASS_INVALID:%d" % index)
	if measured_cells.size() \
			!= (config["required_measured_element_counts"] as Array).size() \
			or refused_cells.size() \
			!= (config["required_policy_refused_element_counts"] as Array).size() \
			or reconstruction_cells.size() \
			!= (config[
				"required_reconstruction_only_element_counts"] as Array).size():
		reasons.append("DISCRETIZATION_GRID_INCOMPLETE")
	var divergences: Array = []
	if reasons.is_empty():
		divergences = _control_divergences(
			config, measured_cells, reconstruction_cells, reasons)
	if not reasons.is_empty():
		return _invalid(reasons)

	var raw_sum_ratios: Array = []
	var maximum_chatter := 0.0
	var cost_records: Array = []
	var measured_counts: Array = (
		config["required_measured_element_counts"] as Array).duplicate()
	for count_value in measured_counts:
		var cell: Dictionary = measured_cells[int(count_value)]
		maximum_chatter = maxf(maximum_chatter,
			float(cell["load_chatter_fraction"]))
		raw_sum_ratios.append({
			"contact_element_count": int(count_value),
			"raw_sum_to_reconstructed_ratio": float(
				cell["raw_sum_to_reconstructed_ratio"]),
		})
		cost_records.append({
			"contact_element_count": int(count_value),
			"cell_class": CLASS_MEASURED,
			"mean_physics_tick_cost_usec": float(
				cell["mean_physics_tick_cost_usec"]),
		})
	var reconstruction_counts: Array = (
		config["required_reconstruction_only_element_counts"] as Array
		).duplicate()
	for count_value in reconstruction_counts:
		var cell: Dictionary = reconstruction_cells[int(count_value)]
		cost_records.append({
			"contact_element_count": int(count_value),
			"cell_class": CLASS_RECONSTRUCTION,
			"mean_physics_tick_cost_usec": float(
				cell["mean_physics_tick_cost_usec"]),
		})
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": true,
		"admitted": true,
		"invalid_reasons": [],
		"config_digest_sha256": String(config["config_digest_sha256"]),
		"measured_element_counts": measured_counts,
		"policy_refused_element_counts": (
			config["required_policy_refused_element_counts"] as Array
			).duplicate(),
		"reconstruction_only_element_counts": reconstruction_counts,
		"raw_sum_to_reconstructed_ratios": raw_sum_ratios,
		"maximum_load_chatter_fraction": maximum_chatter,
		"control_divergences": divergences,
		"runtime_cost_records": cost_records,
		"runtime_cost_interpretation":
			"wall_clock_diagnostic_recorded_not_gated",
		"raw_impulse_summation_interpretation":
			"same_body_multi_manifold_raw_sum_is_not_external_support_load",
		"trusted_total_load_interpretation":
			"whole_system_momentum_reconstruction_only",
		"policy_refusal_interpretation":
			"contact_enumeration_beyond_frozen_policy_refuses_instead_of_truncating",
		"interpolation_policy": "forbidden_exact_cells_only",
		"does_not_establish": [
			"independent_actuators",
			"muscles",
			"toes_or_fingers",
			"per_element_force_control",
			"additive_per_element_load_partition_from_raw_impulse",
			"exact_continuous_contact_force",
			"per_foot_load_allocation_in_articulated_systems",
			"articulated_or_compliant_foot_behavior",
			"load_bearing_limb",
			"bracing",
			"standing",
			"walking",
		],
	})


static func _validate_measured_cell(
		config: Dictionary,
		cell: Dictionary,
		index: int,
		reasons: Array[String]) -> void:
	var element_count := int(cell.get("contact_element_count", 0))
	if typeof(cell.get("valid_sample_count")) != TYPE_INT \
			or int(cell.get("valid_sample_count", 0)) \
			< int(config["minimum_samples_per_cell"]):
		reasons.append("DISCRETIZATION_SAMPLE_WINDOW_INCOMPLETE:%d" % index)
	if typeof(cell.get("reconstructed_sample_count")) != TYPE_INT \
			or int(cell.get("reconstructed_sample_count", 0)) \
			< int(config["minimum_samples_per_cell"]):
		reasons.append(
			"DISCRETIZATION_RECONSTRUCTION_WINDOW_INCOMPLETE:%d" % index)
	if cell.get("capacity_complete") != true:
		reasons.append("DISCRETIZATION_CAPACITY_INCOMPLETE:%d" % index)
	var configured_cap := int(cell.get("configured_cap_per_body", -1))
	var peak := int(cell.get("peak_observed_count", -1))
	var expected_demand := (
		int(config["expected_raw_points_per_element"]) * element_count
		+ int(config["safety_margin_raw_points"]))
	if configured_cap != expected_demand:
		reasons.append("DISCRETIZATION_CAP_DECLARATION_MISMATCH:%d" % index)
	if peak <= 0 or peak >= configured_cap:
		reasons.append("DISCRETIZATION_CAP_UTILIZATION_INVALID:%d" % index)
	for field in [
		"mean_total_raw_predicted_load_n",
		"expected_static_normal_load_n",
		"mean_reconstructed_external_normal_load_n",
		"mean_reconstructed_load_error_n",
		"raw_sum_to_reconstructed_ratio",
		"load_chatter_fraction",
		"mean_cop_projection_error_m",
		"max_element_manifold_load_ratio",
		"element_presence_churn_fraction",
		"max_tilt_rad",
		"max_post_step_slip_speed_mps",
		"body_displacement_m",
		"mean_physics_tick_cost_usec",
	]:
		var value := float(cell.get(field, NAN))
		if not is_finite(value) or value < 0.0:
			reasons.append("DISCRETIZATION_%s_INVALID:%d" % [
				field.to_upper(), index])
	var expected_load := (
		float(config["authored_pad_mass_kg"])
		* float(config["authored_gravity_mps2"]))
	if absf(float(cell.get("expected_static_normal_load_n", INF))
			- expected_load) > 1.0e-6:
		reasons.append("DISCRETIZATION_EXPECTED_LOAD_MISMATCH:%d" % index)
	if float(cell.get("mean_reconstructed_load_error_n", INF)) \
			> float(config["maximum_reconstructed_load_error_n"]):
		reasons.append(
			"DISCRETIZATION_RECONSTRUCTED_LOAD_ERROR_EXCEEDED:%d" % index)
	if element_count == int(config["control_element_count"]) \
			and absf(float(cell.get("mean_total_raw_predicted_load_n", INF))
			- expected_load) \
			> float(config["maximum_control_raw_sum_error_n"]):
		reasons.append("DISCRETIZATION_CONTROL_RAW_SUM_ERROR_EXCEEDED:%d"
			% index)
	var bracket := _bracket_for(config, element_count)
	if not bracket.is_empty():
		var ratio := float(cell.get("raw_sum_to_reconstructed_ratio", NAN))
		if not is_finite(ratio) \
				or ratio < float(bracket["minimum_ratio"]) \
				or ratio > float(bracket["maximum_ratio"]):
			reasons.append(
				"DISCRETIZATION_RAW_SUM_RATIO_OUT_OF_BRACKET:%d" % index)
	if float(cell.get("mean_cop_projection_error_m", INF)) \
			> float(config["maximum_cop_error_m"]):
		reasons.append("DISCRETIZATION_COP_ERROR_EXCEEDED:%d" % index)
	if float(cell.get("max_tilt_rad", INF)) \
			> float(config["maximum_tilt_rad"]):
		reasons.append("DISCRETIZATION_TILT_CONTAMINATION:%d" % index)
	if float(cell.get("max_post_step_slip_speed_mps", INF)) \
			> float(config["maximum_slip_speed_mps"]):
		reasons.append("DISCRETIZATION_SLIP_CONTAMINATION:%d" % index)
	if float(cell.get("body_displacement_m", INF)) \
			> float(config["maximum_displacement_m"]):
		reasons.append("DISCRETIZATION_DISPLACEMENT_CONTAMINATION:%d" % index)
	var shares_value: Variant = cell.get("per_element_mean_raw_manifold_load_n")
	if not shares_value is Array \
			or (shares_value as Array).size() != element_count:
		reasons.append("DISCRETIZATION_ELEMENT_TABLE_INVALID:%d" % index)
	if int(cell.get("elements_ever_contacting_count", -1)) != element_count:
		reasons.append("DISCRETIZATION_ELEMENT_COVERAGE_INCOMPLETE:%d" % index)
	if float(cell.get("max_element_manifold_load_ratio", INF)) \
			> float(config["maximum_element_manifold_load_ratio"]):
		reasons.append(
			"DISCRETIZATION_ELEMENT_MANIFOLD_RATIO_EXCEEDED:%d" % index)
	if float(cell.get("load_chatter_fraction", INF)) \
			> float(config["maximum_load_chatter_fraction"]):
		reasons.append("DISCRETIZATION_LOAD_CHATTER_EXCEEDED:%d" % index)
	if float(cell.get("element_presence_churn_fraction", INF)) \
			> float(config["maximum_element_presence_churn_fraction"]):
		reasons.append("DISCRETIZATION_PRESENCE_CHURN_EXCEEDED:%d" % index)


static func _validate_refused_cell(
		config: Dictionary,
		cell: Dictionary,
		index: int,
		reasons: Array[String]) -> void:
	var element_count := int(cell.get("contact_element_count", 0))
	if String(cell.get("refusal_code", "")) \
			!= "DERIVED_CONTACT_CAP_EXCEEDS_POLICY":
		reasons.append("DISCRETIZATION_REFUSAL_CODE_INVALID:%d" % index)
	var declared := int(cell.get("declared_expected_raw_points", -1))
	if declared != int(config["expected_raw_points_per_element"]) \
			* element_count:
		reasons.append("DISCRETIZATION_REFUSAL_DECLARATION_INVALID:%d" % index)
	if int(cell.get("policy_max_cap_per_body", -1)) \
			!= int(config["contact_policy_max_cap_per_body"]):
		reasons.append("DISCRETIZATION_REFUSAL_POLICY_MISMATCH:%d" % index)
	if declared + int(config["safety_margin_raw_points"]) \
			<= int(config["contact_policy_max_cap_per_body"]):
		reasons.append("DISCRETIZATION_REFUSAL_NOT_JUSTIFIED:%d" % index)
	if cell.get("physics_ran", true) != false:
		reasons.append("DISCRETIZATION_REFUSED_CELL_RAN_PHYSICS:%d" % index)


static func _validate_reconstruction_cell(
		config: Dictionary,
		cell: Dictionary,
		index: int,
		reasons: Array[String]) -> void:
	if String(cell.get("observation_mode", "")) \
			!= "body_state_reconstruction_only_v1":
		reasons.append("DISCRETIZATION_OBSERVATION_MODE_INVALID:%d" % index)
	if cell.get("raw_contact_channel_available", true) != false:
		reasons.append(
			"DISCRETIZATION_RECONSTRUCTION_CLAIMS_CONTACTS:%d" % index)
	if cell.get("all_body_samples_finite") != true:
		reasons.append("DISCRETIZATION_BODY_SAMPLES_NONFINITE:%d" % index)
	if typeof(cell.get("reconstructed_sample_count")) != TYPE_INT \
			or int(cell.get("reconstructed_sample_count", 0)) \
			< int(config["minimum_samples_per_cell"]):
		reasons.append(
			"DISCRETIZATION_RECONSTRUCTION_WINDOW_INCOMPLETE:%d" % index)
	for field in [
		"mean_reconstructed_external_normal_load_n",
		"mean_reconstructed_load_error_n",
		"max_tilt_rad",
		"body_displacement_m",
		"max_vertical_speed_mps",
		"mean_physics_tick_cost_usec",
	]:
		var value := float(cell.get(field, NAN))
		if not is_finite(value) or value < 0.0:
			reasons.append("DISCRETIZATION_%s_INVALID:%d" % [
				field.to_upper(), index])
	if float(cell.get("mean_reconstructed_load_error_n", INF)) \
			> float(config["maximum_reconstructed_load_error_n"]):
		reasons.append(
			"DISCRETIZATION_RECONSTRUCTED_LOAD_ERROR_EXCEEDED:%d" % index)
	if float(cell.get("max_tilt_rad", INF)) \
			> float(config["maximum_tilt_rad"]):
		reasons.append("DISCRETIZATION_TILT_CONTAMINATION:%d" % index)
	if float(cell.get("body_displacement_m", INF)) \
			> float(config["maximum_displacement_m"]):
		reasons.append("DISCRETIZATION_DISPLACEMENT_CONTAMINATION:%d" % index)


static func _control_divergences(
		config: Dictionary,
		measured_cells: Dictionary,
		reconstruction_cells: Dictionary,
		reasons: Array[String]) -> Array:
	var control_count := int(config["control_element_count"])
	if not measured_cells.has(control_count):
		reasons.append("DISCRETIZATION_CONTROL_CELL_MISSING")
		return []
	var control: Dictionary = measured_cells[control_count]
	var control_load := float(
		control["mean_reconstructed_external_normal_load_n"])
	var divergences: Array = []
	for count_value in measured_cells.keys():
		if int(count_value) == control_count:
			continue
		var cell: Dictionary = measured_cells[count_value]
		var divergence := absf(
			float(cell["mean_reconstructed_external_normal_load_n"])
			- control_load)
		if divergence > float(config["maximum_control_divergence_load_n"]):
			reasons.append(
				"DISCRETIZATION_CONTROL_DIVERGENCE_EXCEEDED:%d"
					% int(count_value))
		divergences.append({
			"contact_element_count": int(count_value),
			"cell_class": CLASS_MEASURED,
			"reconstructed_load_divergence_from_control_n": divergence,
		})
	for count_value in reconstruction_cells.keys():
		var cell: Dictionary = reconstruction_cells[count_value]
		var divergence := absf(
			float(cell["mean_reconstructed_external_normal_load_n"])
			- control_load)
		if divergence > float(config["maximum_control_divergence_load_n"]):
			reasons.append(
				"DISCRETIZATION_CONTROL_DIVERGENCE_EXCEEDED:%d"
					% int(count_value))
		divergences.append({
			"contact_element_count": int(count_value),
			"cell_class": CLASS_RECONSTRUCTION,
			"reconstructed_load_divergence_from_control_n": divergence,
		})
	divergences.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["contact_element_count"]) \
			< int(b["contact_element_count"]))
	return divergences


static func _bracket_for(config: Dictionary, element_count: int) -> Dictionary:
	for bracket_value in config.get("required_raw_sum_ratio_brackets", []):
		var bracket: Dictionary = bracket_value
		if int(bracket.get("contact_element_count", -1)) == element_count:
			return bracket
	return {}


static func _config_valid(config: Dictionary) -> bool:
	var exact_fields := [
		"authored_gravity_mps2",
		"authored_pad_mass_kg",
		"config_digest_sha256",
		"contact_policy_max_cap_per_body",
		"continuous_force_claim_forbidden",
		"control_element_count",
		"elements_are_actuators_forbidden",
		"expected_raw_points_per_element",
		"maximum_control_divergence_load_n",
		"maximum_control_raw_sum_error_n",
		"maximum_cop_error_m",
		"maximum_displacement_m",
		"maximum_element_manifold_load_ratio",
		"maximum_element_presence_churn_fraction",
		"maximum_load_chatter_fraction",
		"maximum_reconstructed_load_error_n",
		"maximum_slip_speed_mps",
		"maximum_tilt_rad",
		"minimum_samples_per_cell",
		"raw_sum_is_load_partition_forbidden",
		"required_measured_element_counts",
		"required_policy_refused_element_counts",
		"required_raw_sum_ratio_brackets",
		"required_reconstruction_only_element_counts",
		"runtime_cost_gated",
		"safety_margin_raw_points",
		"schema_version",
	]
	var actual_fields: Array = config.keys()
	actual_fields.sort()
	if actual_fields != exact_fields \
			or String(config.get("schema_version", "")) != CONFIG_SCHEMA_VERSION \
			or config.get("runtime_cost_gated") != false \
			or config.get("raw_sum_is_load_partition_forbidden") != true \
			or config.get("elements_are_actuators_forbidden") != true \
			or config.get("continuous_force_claim_forbidden") != true \
			or not config.get("required_measured_element_counts") is Array \
			or not config.get(
				"required_policy_refused_element_counts") is Array \
			or not config.get(
				"required_reconstruction_only_element_counts") is Array \
			or not config.get("required_raw_sum_ratio_brackets") is Array:
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


static func _element_count_schedule(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> Array:
	var schedule: Array = []
	if not value is Array or (value as Array).is_empty():
		_add_error(errors, "ELEMENT_SCHEDULE_INVALID", path,
			"Expected a non-empty strictly increasing integer array")
		return schedule
	var previous := 0
	for index in (value as Array).size():
		var entry: Variant = (value as Array)[index]
		if typeof(entry) != TYPE_INT or int(entry) <= previous:
			_add_error(errors, "ELEMENT_SCHEDULE_INVALID",
				"%s/%d" % [path, index],
				"Element counts must be strictly increasing positive integers")
			continue
		previous = int(entry)
		schedule.append(int(entry))
	return schedule


static func _ratio_bracket_schedule(
		value: Variant,
		measured: Array,
		control: int,
		errors: Array[Dictionary]) -> Array:
	var brackets: Array = []
	if not value is Array:
		_add_error(errors, "RATIO_BRACKET_SCHEDULE_INVALID",
			"/required_raw_sum_ratio_brackets",
			"Expected one ratio bracket per measured element count")
		return brackets
	var seen: Dictionary = {}
	for index in (value as Array).size():
		var entry: Variant = (value as Array)[index]
		if not entry is Dictionary:
			_add_error(errors, "RATIO_BRACKET_SCHEDULE_INVALID",
				"/required_raw_sum_ratio_brackets/%d" % index,
				"Each bracket must be one object")
			continue
		var bracket: Dictionary = entry
		var count := int(bracket.get("contact_element_count", -1))
		var minimum := float(bracket.get("minimum_ratio", NAN))
		var maximum := float(bracket.get("maximum_ratio", NAN))
		if not measured.has(count) or seen.has(count) \
				or not is_finite(minimum) or not is_finite(maximum) \
				or minimum <= 0.0 or maximum <= minimum:
			_add_error(errors, "RATIO_BRACKET_SCHEDULE_INVALID",
				"/required_raw_sum_ratio_brackets/%d" % index,
				"Brackets must cover measured counts with 0 < min < max")
			continue
		if count == control and (minimum > 1.0 or maximum < 1.0):
			_add_error(errors, "CONTROL_RATIO_BRACKET_INVALID",
				"/required_raw_sum_ratio_brackets/%d" % index,
				"The one-manifold control bracket must contain ratio 1.0")
		seen[count] = true
		brackets.append({
			"contact_element_count": count,
			"minimum_ratio": minimum,
			"maximum_ratio": maximum,
		})
	if seen.size() != measured.size():
		_add_error(errors, "RATIO_BRACKET_SCHEDULE_INVALID",
			"/required_raw_sum_ratio_brackets",
			"Every measured element count needs exactly one ratio bracket")
	brackets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["contact_element_count"]) \
			< int(b["contact_element_count"]))
	return brackets


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
	var number := (
		float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] else NAN)
	if is_finite(number) and number > 0.0:
		return number
	_add_error(errors, "POSITIVE_FLOAT_REQUIRED", path,
		"Expected a finite positive number")
	return 0.0


static func _nonnegative_float(
		value: Variant,
		path: String,
		errors: Array[Dictionary]) -> float:
	var number := (
		float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] else NAN)
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
