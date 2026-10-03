class_name LabFrictionBreakawayAnalyzer
extends RefCounted

## Staged L1.1 static-to-sliding breakaway analysis.
##
## One physics frame cannot distinguish solver jitter, elastic micro-motion,
## and sustained sliding. The runner therefore applies monotonically increasing
## constant-force stages and summarizes a fixed observation window per stage.
## This analyzer classifies each completed stage as HELD, AMBIGUOUS, or SLIDING
## and reports the operational breakaway bracket:
##
##     last completed HELD stage <= breakaway <= first completed SLIDING stage
##
## The ratio endpoints divide commanded shear by the observed mean predicted
## normal load. They are empirical bounds for this exact engine/material/
## timestep/solver configuration, not a universal Coulomb coefficient.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const CONFIG_SCHEMA_VERSION := "friction_breakaway_config_v1"
const RESULT_SCHEMA_VERSION := "friction_breakaway_analysis_v1"
const HELD := "HELD"
const AMBIGUOUS := "AMBIGUOUS"
const SLIDING := "SLIDING"


static func build_config(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var minimum_samples := _positive_integer(
		configuration.get("minimum_samples_per_stage"),
		"/minimum_samples_per_stage", errors)
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
	if minimum_sliding_speed <= maximum_holding_speed:
		_add_error(
			errors,
			"SPEED_HYSTERESIS_INVALID",
			"/minimum_sliding_speed_mps",
			"Sliding speed must be strictly above the holding ceiling")
	if minimum_sliding_displacement <= maximum_holding_displacement:
		_add_error(
			errors,
			"DISPLACEMENT_HYSTERESIS_INVALID",
			"/minimum_sliding_displacement_m",
			"Sliding displacement must be strictly above the holding ceiling")
	if not errors.is_empty():
		return FrozenValueScript.snapshot({
			"ok": false,
			"errors": errors,
			"config": null,
		})
	var config := {
		"schema_version": CONFIG_SCHEMA_VERSION,
		"minimum_samples_per_stage": minimum_samples,
		"maximum_holding_speed_mps": maximum_holding_speed,
		"maximum_holding_displacement_m": maximum_holding_displacement,
		"minimum_sliding_speed_mps": minimum_sliding_speed,
		"minimum_sliding_displacement_m": minimum_sliding_displacement,
		"force_schedule_policy": "strictly_increasing_nonnegative_stages_v1",
		"contact_completeness_required": true,
		"single_frame_breakaway_forbidden": true,
	}
	config["config_digest_sha256"] = CanonicalJsonScript.sha256(config)
	return FrozenValueScript.snapshot({
		"ok": true,
		"errors": [],
		"config": config,
	})


static func analyze(config: Dictionary, stage_summaries: Array) -> Dictionary:
	var reasons: Array[String] = []
	if not _config_valid(config):
		return FrozenValueScript.snapshot({
			"schema_version": RESULT_SCHEMA_VERSION,
			"ok": false,
			"breakaway_detected": false,
			"invalid_reasons": ["BREAKAWAY_CONFIG_INVALID"],
			"classified_stages": [],
		})
	if stage_summaries.size() < 2:
		reasons.append("BREAKAWAY_STAGE_COUNT_INSUFFICIENT")
	var classified: Array = []
	var previous_force := -INF
	var first_sliding_index := -1
	var last_held_index := -1
	var held_after_sliding := false
	for index in stage_summaries.size():
		var stage_value: Variant = stage_summaries[index]
		if not stage_value is Dictionary:
			reasons.append("BREAKAWAY_STAGE_NOT_DICTIONARY:%d" % index)
			continue
		var stage: Dictionary = stage_value
		var validation := _validate_stage(config, stage, index)
		reasons.append_array(validation["reasons"] as Array[String])
		var applied_force := float(stage.get("applied_shear_force_n", NAN))
		if is_finite(applied_force) and applied_force <= previous_force:
			reasons.append("BREAKAWAY_FORCE_SCHEDULE_NOT_STRICTLY_INCREASING:%d" % index)
		previous_force = applied_force
		var classification := String(validation["classification"])
		var ratio: Variant = null
		var mean_normal_load := float(stage.get("mean_normal_load_n", NAN))
		if is_finite(applied_force) and is_finite(mean_normal_load) \
				and mean_normal_load > 0.0:
			ratio = applied_force / mean_normal_load
		var classified_stage := stage.duplicate(true)
		classified_stage["classification"] = classification
		classified_stage["applied_to_normal_ratio"] = ratio
		classified.append(classified_stage)
		if classification == HELD:
			if first_sliding_index >= 0:
				held_after_sliding = true
			else:
				last_held_index = index
		elif classification == SLIDING and first_sliding_index < 0:
			first_sliding_index = index
	if held_after_sliding:
		reasons.append("BREAKAWAY_HELD_STAGE_AFTER_SLIDING")
	if last_held_index < 0:
		reasons.append("BREAKAWAY_NO_COMPLETED_HOLD_STAGE")
	if first_sliding_index < 0:
		reasons.append("BREAKAWAY_NO_COMPLETED_SLIDING_STAGE")
	if last_held_index >= first_sliding_index and first_sliding_index >= 0:
		reasons.append("BREAKAWAY_STAGE_ORDER_INVALID")
	if not reasons.is_empty():
		return FrozenValueScript.snapshot({
			"schema_version": RESULT_SCHEMA_VERSION,
			"ok": false,
			"breakaway_detected": false,
			"invalid_reasons": reasons,
			"classified_stages": classified,
		})

	var lower_stage: Dictionary = classified[last_held_index]
	var upper_stage: Dictionary = classified[first_sliding_index]
	var lower_force := float(lower_stage["applied_shear_force_n"])
	var upper_force := float(upper_stage["applied_shear_force_n"])
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": true,
		"breakaway_detected": true,
		"invalid_reasons": [],
		"config_digest_sha256": String(config["config_digest_sha256"]),
		"classified_stages": classified,
		"last_held_stage_id": String(lower_stage["stage_id"]),
		"first_sliding_stage_id": String(upper_stage["stage_id"]),
		"breakaway_force_lower_n": lower_force,
		"breakaway_force_upper_n": upper_force,
		"breakaway_force_bracket_width_n": upper_force - lower_force,
		"empirical_static_ratio_lower": float(
			lower_stage["applied_to_normal_ratio"]),
		"empirical_static_ratio_upper": float(
			upper_stage["applied_to_normal_ratio"]),
		"interpretation": "operational_stage_bracket_for_exact_configuration_v1",
		"does_not_establish": [
			"exact_continuous_contact_force",
			"universal_material_coefficient",
			"load_bearing_limb",
			"bracing",
			"standing",
			"walking",
		],
	})


static func _validate_stage(
		config: Dictionary,
		stage: Dictionary,
		index: int) -> Dictionary:
	var reasons: Array[String] = []
	var stage_id_value: Variant = stage.get("stage_id")
	if not (stage_id_value is String or stage_id_value is StringName) \
			or String(stage_id_value).is_empty():
		reasons.append("BREAKAWAY_STAGE_ID_INVALID:%d" % index)
	for field in [
		"applied_shear_force_n",
		"max_slip_speed_mps",
		"tangential_displacement_m",
		"mean_normal_load_n",
	]:
		var value := float(stage.get(field, NAN))
		if not is_finite(value) or value < 0.0:
			reasons.append("BREAKAWAY_STAGE_%s_INVALID:%d" % [
				field.to_upper(), index])
	var sample_count := int(stage.get("sample_count", -1))
	var valid_sample_count := int(stage.get("valid_sample_count", -1))
	var contact_sample_count := int(stage.get("contact_sample_count", -1))
	if typeof(stage.get("sample_count")) != TYPE_INT \
			or sample_count < int(config.get("minimum_samples_per_stage", 1)):
		reasons.append("BREAKAWAY_STAGE_SAMPLE_COUNT_INVALID:%d" % index)
	if typeof(stage.get("valid_sample_count")) != TYPE_INT \
			or valid_sample_count != sample_count:
		reasons.append("BREAKAWAY_STAGE_VALID_SAMPLE_INCOMPLETE:%d" % index)
	if typeof(stage.get("contact_sample_count")) != TYPE_INT \
			or contact_sample_count != sample_count:
		reasons.append("BREAKAWAY_STAGE_CONTACT_INCOMPLETE:%d" % index)
	var normal_load := float(stage.get("mean_normal_load_n", NAN))
	if not is_finite(normal_load) or normal_load <= 0.0:
		reasons.append("BREAKAWAY_STAGE_NORMAL_LOAD_UNAVAILABLE:%d" % index)
	if not reasons.is_empty():
		return {"classification": AMBIGUOUS, "reasons": reasons}
	var max_speed := float(stage["max_slip_speed_mps"])
	var displacement := float(stage["tangential_displacement_m"])
	var held := max_speed <= float(config["maximum_holding_speed_mps"]) \
		and displacement <= float(config["maximum_holding_displacement_m"])
	var sliding := max_speed >= float(config["minimum_sliding_speed_mps"]) \
		and displacement >= float(config["minimum_sliding_displacement_m"])
	return {
		"classification": SLIDING if sliding else HELD if held else AMBIGUOUS,
		"reasons": [],
	}


static func _config_valid(config: Dictionary) -> bool:
	var exact_fields := [
		"config_digest_sha256",
		"contact_completeness_required",
		"force_schedule_policy",
		"maximum_holding_displacement_m",
		"maximum_holding_speed_mps",
		"minimum_samples_per_stage",
		"minimum_sliding_displacement_m",
		"minimum_sliding_speed_mps",
		"schema_version",
		"single_frame_breakaway_forbidden",
	]
	var actual_fields: Array = config.keys()
	actual_fields.sort()
	if actual_fields != exact_fields \
			or String(config.get("schema_version", "")) \
				!= CONFIG_SCHEMA_VERSION \
			or typeof(config.get("minimum_samples_per_stage")) != TYPE_INT \
			or int(config.get("minimum_samples_per_stage", 0)) <= 0 \
			or String(config.get("force_schedule_policy", "")) \
				!= "strictly_increasing_nonnegative_stages_v1" \
			or config.get("contact_completeness_required") != true \
			or config.get("single_frame_breakaway_forbidden") != true:
		return false
	var hold_speed := float(config.get("maximum_holding_speed_mps", NAN))
	var hold_displacement := float(config.get(
		"maximum_holding_displacement_m", NAN))
	var slide_speed := float(config.get("minimum_sliding_speed_mps", NAN))
	var slide_displacement := float(config.get(
		"minimum_sliding_displacement_m", NAN))
	if not is_finite(hold_speed) or hold_speed < 0.0 \
			or not is_finite(hold_displacement) or hold_displacement < 0.0 \
			or not is_finite(slide_speed) or slide_speed <= hold_speed \
			or not is_finite(slide_displacement) \
			or slide_displacement <= hold_displacement:
		return false
	var digest := String(config.get("config_digest_sha256", ""))
	var payload := config.duplicate(true)
	payload.erase("config_digest_sha256")
	return digest.begins_with("sha256:") \
		and digest.length() == 71 \
		and digest == CanonicalJsonScript.sha256(payload)


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


static func _add_error(
		errors: Array[Dictionary],
		code: String,
		path: String,
		message: String) -> void:
	errors.append({"code": code, "path": path, "message": message})
