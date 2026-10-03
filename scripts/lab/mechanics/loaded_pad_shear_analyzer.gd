class_name LabLoadedPadShearAnalyzer
extends RefCounted

## L3.1 loaded-pad shear admission. It reuses the accepted staged-breakaway
## classifier while additionally pinning the imposed normal load, exact shear
## schedule, free-pad force path, reconstructed support load, and accepted L1
## friction-ratio envelope.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const BreakawayAnalyzerScript := preload(
	"res://scripts/lab/mechanics/friction_breakaway_analyzer.gd"
)

const CONFIG_SCHEMA_VERSION := "loaded_pad_shear_config_v1"
const RESULT_SCHEMA_VERSION := "loaded_pad_shear_analysis_v1"


static func build_config(configuration: Dictionary) -> Dictionary:
	var errors: Array[Dictionary] = []
	var downward_load := _positive_float(
		configuration.get("external_downward_load_n"), "/external_downward_load_n", errors
	)
	var friction := _positive_float(
		configuration.get("authored_friction"), "/authored_friction", errors
	)
	if friction > 1.0:
		_add_error(
			errors,
			"FRICTION_DOMAIN_INVALID",
			"/authored_friction",
			"Godot material friction cannot exceed one"
		)
	var schedule_value: Variant = configuration.get("required_shear_schedule_n")
	var schedule: Array = []
	if schedule_value is Array and (schedule_value as Array).size() >= 3:
		var previous := -INF
		for index in (schedule_value as Array).size():
			var shear := _number((schedule_value as Array)[index])
			if not is_finite(shear) or shear < 0.0 or shear <= previous:
				_add_error(
					errors,
					"SHEAR_SCHEDULE_INVALID",
					"/required_shear_schedule_n/%d" % index,
					"Shear stages must be finite, nonnegative, and strictly increasing"
				)
			previous = shear
			schedule.append(shear)
	else:
		_add_error(
			errors,
			"SHEAR_SCHEDULE_INVALID",
			"/required_shear_schedule_n",
			"At least three shear stages are required"
		)
	var normal_tolerance := _positive_float(
		configuration.get("maximum_normal_load_error_n"), "/maximum_normal_load_error_n", errors
	)
	var accepted_l1_lower := _positive_float(
		configuration.get("accepted_l1_ratio_lower"), "/accepted_l1_ratio_lower", errors
	)
	var accepted_l1_upper := _positive_float(
		configuration.get("accepted_l1_ratio_upper"), "/accepted_l1_ratio_upper", errors
	)
	if accepted_l1_upper <= accepted_l1_lower:
		_add_error(
			errors,
			"L1_RATIO_ENVELOPE_INVALID",
			"/accepted_l1_ratio_upper",
			"Accepted L1 ratio upper bound must exceed the lower bound"
		)
	var breakaway_result := BreakawayAnalyzerScript.build_config(
		configuration.get("breakaway_config", {})
	)
	if not bool(breakaway_result.get("ok", false)):
		_add_error(
			errors,
			"BREAKAWAY_CONFIG_INVALID",
			"/breakaway_config",
			"Nested staged-breakaway configuration is invalid"
		)
	if not errors.is_empty():
		return FrozenValueScript.snapshot({"ok": false, "errors": errors, "config": null})
	var config := {
		"schema_version": CONFIG_SCHEMA_VERSION,
		"external_downward_load_n": downward_load,
		"authored_friction": friction,
		"required_shear_schedule_n": schedule,
		"maximum_normal_load_error_n": normal_tolerance,
		"accepted_l1_ratio_lower": accepted_l1_lower,
		"accepted_l1_ratio_upper": accepted_l1_upper,
		"breakaway_config": breakaway_result["config"],
		"force_application_method": "RigidBody3D.apply_force",
		"free_pad_required": true,
		"centered_force_required": true,
		"general_contact_allocation_claim_forbidden": true,
	}
	config["config_digest_sha256"] = CanonicalJsonScript.sha256(config)
	return FrozenValueScript.snapshot({"ok": true, "errors": [], "config": config})


static func analyze(config: Dictionary, stage_summaries: Array) -> Dictionary:
	if not _config_valid(config):
		return _invalid(["LOADED_PAD_SHEAR_CONFIG_INVALID"])
	var schedule: Array = config["required_shear_schedule_n"]
	if stage_summaries.size() != schedule.size():
		return _invalid(["LOADED_PAD_SHEAR_STAGE_COUNT_MISMATCH"])
	var reasons: Array[String] = []
	var maximum_normal_error := 0.0
	for index in stage_summaries.size():
		var stage_value: Variant = stage_summaries[index]
		if not stage_value is Dictionary:
			reasons.append("LOADED_PAD_SHEAR_STAGE_INVALID:%d" % index)
			continue
		var stage: Dictionary = stage_value
		if absf(float(stage.get("applied_shear_force_n", NAN)) - float(schedule[index])) > 1.0e-9:
			reasons.append("LOADED_PAD_SHEAR_SCHEDULE_MISMATCH:%d" % index)
		if (
			absf(
				(
					float(stage.get("external_downward_load_n", NAN))
					- float(config["external_downward_load_n"])
				)
			)
			> 1.0e-9
		):
			reasons.append("LOADED_PAD_SHEAR_NORMAL_COMMAND_MISMATCH:%d" % index)
		if (
			stage.get("free_pad_contract") != true
			or stage.get("centered_force_contract") != true
			or stage.get("capacity_complete") != true
		):
			reasons.append("LOADED_PAD_SHEAR_CONTRACT_INVALID:%d" % index)
		var normal_error := absf(
			(
				float(stage.get("mean_normal_load_n", INF))
				- float(stage.get("mean_expected_normal_load_n", -INF))
			)
		)
		maximum_normal_error = maxf(maximum_normal_error, normal_error)
		if normal_error > float(config["maximum_normal_load_error_n"]):
			reasons.append("LOADED_PAD_SHEAR_NORMAL_LOAD_ERROR_EXCEEDED:%d" % index)
	var breakaway := BreakawayAnalyzerScript.analyze(config["breakaway_config"], stage_summaries)
	if not bool(breakaway.get("ok", false)):
		reasons.append("LOADED_PAD_SHEAR_BREAKAWAY_INVALID")
	if not reasons.is_empty():
		return _invalid(reasons, {"breakaway": breakaway})
	var ratio_lower := float(breakaway["empirical_static_ratio_lower"])
	var ratio_upper := float(breakaway["empirical_static_ratio_upper"])
	if (
		ratio_lower > float(config["authored_friction"])
		or ratio_upper < float(config["authored_friction"])
	):
		return _invalid(
			["LOADED_PAD_SHEAR_AUTHORED_FRICTION_OUTSIDE_BRACKET"], {"breakaway": breakaway}
		)
	if (
		ratio_lower < float(config["accepted_l1_ratio_lower"])
		or ratio_upper > float(config["accepted_l1_ratio_upper"])
	):
		return _invalid(["LOADED_PAD_SHEAR_OUTSIDE_ACCEPTED_L1_ENVELOPE"], {"breakaway": breakaway})
	return (
		FrozenValueScript
		. snapshot(
			{
				"schema_version": RESULT_SCHEMA_VERSION,
				"ok": true,
				"admitted": true,
				"invalid_reasons": [],
				"config_digest_sha256": config["config_digest_sha256"],
				"stage_count": stage_summaries.size(),
				"maximum_normal_load_error_n": maximum_normal_error,
				"breakaway": breakaway,
				"accepted_l1_ratio_envelope_retained": true,
				"interpretation": "free_unary_loaded_pad_shear_breakaway_v1",
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
				"accepted_l1_ratio_lower",
				"accepted_l1_ratio_upper",
				"authored_friction",
				"breakaway_config",
				"centered_force_required",
				"config_digest_sha256",
				"external_downward_load_n",
				"force_application_method",
				"free_pad_required",
				"general_contact_allocation_claim_forbidden",
				"maximum_normal_load_error_n",
				"required_shear_schedule_n",
				"schema_version",
			]
		)
		or String(config.get("schema_version", "")) != CONFIG_SCHEMA_VERSION
		or String(config.get("force_application_method", "")) != "RigidBody3D.apply_force"
		or config.get("free_pad_required") != true
		or config.get("centered_force_required") != true
		or config.get("general_contact_allocation_claim_forbidden") != true
	):
		return false
	var payload := config.duplicate(true)
	payload.erase("config_digest_sha256")
	return String(config.get("config_digest_sha256", "")) == CanonicalJsonScript.sha256(payload)


static func _invalid(reasons: Array[String], details: Dictionary = {}) -> Dictionary:
	return (
		FrozenValueScript
		. snapshot(
			{
				"schema_version": RESULT_SCHEMA_VERSION,
				"ok": false,
				"admitted": false,
				"invalid_reasons": reasons,
				"details": details,
			}
		)
	)


static func _positive_float(value: Variant, path: String, errors: Array[Dictionary]) -> float:
	var number := _number(value)
	if is_finite(number) and number > 0.0:
		return number
	_add_error(errors, "POSITIVE_FLOAT_REQUIRED", path, "Expected a finite positive number")
	return 0.0


static func _number(value: Variant) -> float:
	return float(value) if typeof(value) in [TYPE_FLOAT, TYPE_INT] else NAN


static func _add_error(
	errors: Array[Dictionary], code: String, path: String, message: String
) -> void:
	errors.append({"code": code, "path": path, "message": message})
