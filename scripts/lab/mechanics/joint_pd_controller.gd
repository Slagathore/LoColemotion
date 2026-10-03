class_name LabJointPdController
extends RefCounted

## Strict, side-effect-free PD request resolver for BR4 experiments.
##
## This object cannot touch a physics body. It only converts a digest-bound
## controller configuration and a complete joint observation into named torque
## components for LabJointActuator.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA_VERSION := "joint_pd_controller_configuration_v1"
const INPUT_SCHEMA_VERSION := "joint_pd_controller_input_v1"
const RESULT_SCHEMA_VERSION := "joint_pd_controller_resolution_v1"
const REQUIRED_CONFIGURATION_FIELDS: Array[String] = [
	"schema_version",
	"controller_id",
	"kp_nm_per_rad",
	"kd_nm_s_per_rad",
	"max_abs_position_error_rad",
	"max_abs_rate_rad_s",
]
const REQUIRED_INPUT_FIELDS: Array[String] = [
	"schema_version",
	"tick",
	"target_angle_rad",
	"measured_angle_rad",
	"measured_rate_rad_s",
]


static func compile(configuration: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_CONFIGURATION_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		errors.append("JOINT_PD_CONFIGURATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA_VERSION:
		errors.append("JOINT_PD_CONFIGURATION_SCHEMA_UNSUPPORTED")
	if not _is_stable_id(String(configuration.get("controller_id", ""))):
		errors.append("JOINT_PD_CONTROLLER_ID_INVALID")
	for field in [
		"kp_nm_per_rad",
		"kd_nm_s_per_rad",
		"max_abs_position_error_rad",
		"max_abs_rate_rad_s",
	]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) <= 0.0:
			errors.append("%s_INVALID" % String(field).to_upper())
	if not errors.is_empty():
		return {
			"ok": false,
			"failure_code": "JOINT_PD_CONFIGURATION_INVALID",
			"errors": errors,
		}
	var payload := configuration.duplicate(true)
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {
		"ok": true,
		"controller": FrozenValueScript.snapshot(payload),
	}


static func resolve(controller: Dictionary, input: Dictionary) -> Dictionary:
	var controller_check := verify(controller)
	if not bool(controller_check.get("ok", false)):
		return _failure("JOINT_PD_CONTROLLER_INVALID", controller_check)
	var input_check := _validate_input(input, controller)
	if not bool(input_check.get("ok", false)):
		return input_check
	var target := float(input["target_angle_rad"])
	var measured := float(input["measured_angle_rad"])
	var rate := float(input["measured_rate_rad_s"])
	var error := target - measured
	var proportional := float(controller["kp_nm_per_rad"]) * error
	var derivative := -float(controller["kd_nm_s_per_rad"]) * rate
	var requested := proportional + derivative
	var result := {
		"schema_version": RESULT_SCHEMA_VERSION,
		"controller_id": controller["controller_id"],
		"controller_configuration_sha256": controller["configuration_sha256"],
		"tick": input["tick"],
		"target_angle_rad": target,
		"measured_angle_rad": measured,
		"measured_rate_rad_s": rate,
		"position_error_rad": error,
		"proportional_torque_nm": proportional,
		"derivative_torque_nm": derivative,
		"requested_torque_nm": requested,
		"active_components":
		{
			"l2_2.pd_proportional": proportional,
			"l2_2.pd_derivative": derivative,
		},
	}
	result["resolution_sha256"] = CanonicalJsonScript.sha256(result)
	return {
		"ok": true,
		"resolution": FrozenValueScript.snapshot(result),
	}


static func verify(controller: Dictionary) -> Dictionary:
	var configuration: Dictionary = {}
	for field in REQUIRED_CONFIGURATION_FIELDS:
		if not controller.has(field):
			return _failure("JOINT_PD_CONTROLLER_INCOMPLETE")
		configuration[field] = controller[field]
	var rebuilt := compile(configuration)
	if not bool(rebuilt.get("ok", false)):
		return _failure("JOINT_PD_CONTROLLER_REBUILD_FAILED", rebuilt)
	if (
		CanonicalJsonScript.stringify(rebuilt["controller"])
		!= CanonicalJsonScript.stringify(controller)
	):
		return _failure("JOINT_PD_CONTROLLER_DIGEST_MISMATCH")
	return {"ok": true}


static func _validate_input(input: Dictionary, controller: Dictionary) -> Dictionary:
	var keys: Array = input.keys()
	keys.sort()
	var expected: Array = REQUIRED_INPUT_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("JOINT_PD_INPUT_FIELD_SET_MISMATCH")
	if String(input.get("schema_version", "")) != INPUT_SCHEMA_VERSION:
		return _failure("JOINT_PD_INPUT_SCHEMA_UNSUPPORTED")
	if not input.get("tick") is int or int(input["tick"]) < 0:
		return _failure("JOINT_PD_TICK_INVALID")
	for field in [
		"target_angle_rad",
		"measured_angle_rad",
		"measured_rate_rad_s",
	]:
		if not _finite_number(input.get(field)):
			return _failure("JOINT_PD_%s_NONFINITE" % String(field).to_upper())
	if (
		absf(float(input["target_angle_rad"]) - float(input["measured_angle_rad"]))
		> float(controller["max_abs_position_error_rad"])
	):
		return _failure("JOINT_PD_POSITION_ERROR_OUTSIDE_DECLARED_DOMAIN")
	if absf(float(input["measured_rate_rad_s"])) > float(controller["max_abs_rate_rad_s"]):
		return _failure("JOINT_PD_RATE_OUTSIDE_DECLARED_DOMAIN")
	return {"ok": true}


static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _is_stable_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z][A-Za-z0-9._:-]{0,159}$")
	return expression.search(value) != null


static func _failure(code: String, details: Variant = null) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"details": details,
	}
