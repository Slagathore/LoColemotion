class_name LabFallArrestController
extends RefCounted

## Pure finite request generator for one declared BR11 protective hinge.
##
## The controller emits a torque component request. LabJointActuator and the
## command/receipt seam remain the only path to physics mutation.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA := "fall_arrest_controller_configuration_v1"
const INPUT_SCHEMA := "fall_arrest_controller_input_v1"
const CONFIGURATION_FIELDS: Array[String] = [
	"schema_version",
	"controller_id",
	"target_relative_angle_rad",
	"kp_nm_per_rad",
	"kd_nm_s_per_rad",
	"maximum_abs_angle_error_rad",
	"maximum_abs_rate_rad_s",
	"automatic_creature_guidance_allowed",
]
const INPUT_FIELDS: Array[String] = [
	"schema_version",
	"tick",
	"supervisor_phase",
	"measured_relative_angle_rad",
	"measured_relative_rate_rad_s",
]


static func compile(configuration: Dictionary) -> Dictionary:
	var keys := _sorted_keys(configuration)
	var expected: Array = CONFIGURATION_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("FALL_ARREST_CONTROLLER_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA:
		return _failure("FALL_ARREST_CONTROLLER_CONFIGURATION_SCHEMA_UNSUPPORTED")
	if not _stable_id(String(configuration.get("controller_id", ""))):
		return _failure("FALL_ARREST_CONTROLLER_ID_INVALID")
	for field in [
		"target_relative_angle_rad",
		"kp_nm_per_rad",
		"kd_nm_s_per_rad",
		"maximum_abs_angle_error_rad",
		"maximum_abs_rate_rad_s",
	]:
		if not _finite_number(configuration.get(field)):
			return _failure("FALL_ARREST_CONTROLLER_NUMBER_INVALID:%s" % field)
	if (
		float(configuration["kp_nm_per_rad"]) < 0.0
		or float(configuration["kd_nm_s_per_rad"]) < 0.0
		or float(configuration["maximum_abs_angle_error_rad"]) <= 0.0
		or float(configuration["maximum_abs_rate_rad_s"]) <= 0.0
	):
		return _failure("FALL_ARREST_CONTROLLER_BOUND_INVALID")
	if (
		not configuration.get("automatic_creature_guidance_allowed") is bool
		or bool(configuration["automatic_creature_guidance_allowed"])
	):
		return _failure("FALL_ARREST_CONTROLLER_GUIDANCE_FORBIDDEN")
	var payload := configuration.duplicate(true)
	payload["controller_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {"ok": true, "controller": FrozenValueScript.snapshot(payload)}


static func resolve(controller: Dictionary, input: Dictionary) -> Dictionary:
	var source: Dictionary = {}
	for field in CONFIGURATION_FIELDS:
		if not controller.has(field):
			return _failure("FALL_ARREST_CONTROLLER_INCOMPLETE")
		source[field] = controller[field]
	var rebuilt := compile(source)
	if (
		not bool(rebuilt.get("ok", false))
		or (
			CanonicalJsonScript.stringify(rebuilt["controller"])
			!= CanonicalJsonScript.stringify(controller)
		)
	):
		return _failure("FALL_ARREST_CONTROLLER_DIGEST_MISMATCH")
	var keys := _sorted_keys(input)
	var expected: Array = INPUT_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("FALL_ARREST_CONTROLLER_INPUT_FIELD_SET_MISMATCH")
	if String(input.get("schema_version", "")) != INPUT_SCHEMA:
		return _failure("FALL_ARREST_CONTROLLER_INPUT_SCHEMA_UNSUPPORTED")
	if typeof(input.get("tick")) != TYPE_INT or int(input["tick"]) < 0:
		return _failure("FALL_ARREST_CONTROLLER_TICK_INVALID")
	var angle: Variant = input.get("measured_relative_angle_rad")
	var rate: Variant = input.get("measured_relative_rate_rad_s")
	if not _finite_number(angle) or not _finite_number(rate):
		return _failure("FALL_ARREST_CONTROLLER_OBSERVATION_NONFINITE")
	if (
		absf(float(angle)) > float(controller["maximum_abs_angle_error_rad"])
		or absf(float(rate)) > float(controller["maximum_abs_rate_rad_s"])
	):
		return _failure("FALL_ARREST_CONTROLLER_OBSERVATION_OUT_OF_DOMAIN")
	var phase := String(input.get("supervisor_phase", ""))
	if phase not in ["MONITOR", "FALL_ARREST", "FALLEN"]:
		return _failure("FALL_ARREST_CONTROLLER_PHASE_INVALID")
	var position_error := float(controller["target_relative_angle_rad"]) - float(angle)
	var requested := 0.0
	if phase == "FALL_ARREST":
		requested = (
			float(controller["kp_nm_per_rad"]) * position_error
			- float(controller["kd_nm_s_per_rad"]) * float(rate)
		)
	return {
		"ok": true,
		"resolution":
		(
			FrozenValueScript
			. snapshot(
				{
					"schema_version": "fall_arrest_controller_resolution_v1",
					"tick": int(input["tick"]),
					"supervisor_phase": phase,
					"target_relative_angle_rad": float(controller["target_relative_angle_rad"]),
					"measured_relative_angle_rad": float(angle),
					"measured_relative_rate_rad_s": float(rate),
					"position_error_rad": position_error,
					"requested_torque_nm": requested,
					"active_components": {"protective_pd_nm": requested},
					"controller_sha256": controller["controller_sha256"],
					"physics_mutation_authority": false,
				}
			)
		),
	}


static func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys


static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _stable_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z][A-Za-z0-9._:-]{0,159}$")
	return expression.search(value) != null


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
