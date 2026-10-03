class_name LabActuatorSpec
extends RefCounted

## Strict BR4 actuator specification compiler.
##
## No value is repaired or defaulted. In particular, active capacity is never
## manufactured for an absent muscle or malformed lab fixture.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "actuator_spec_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"actuator_id",
	"enabled",
	"max_isometric_torque_nm",
	"no_load_speed_rad_s",
	"max_positive_power_w",
	"max_absorption_power_w",
	"max_eccentric_multiplier",
	"activation_time_s",
	"deactivation_time_s",
	"max_torque_rate_nm_s",
	"structural_torque_limit_nm",
	"tear_dwell_s",
	"capacity_source",
	"muscle_pcsa_m2",
	"specific_tension_pa",
	"moment_arm_m",
]


static func compile(configuration: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		errors.append("ACTUATOR_SPEC_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != SCHEMA_VERSION:
		errors.append("ACTUATOR_SPEC_SCHEMA_UNSUPPORTED")
	if not _is_stable_id(String(configuration.get("actuator_id", ""))):
		errors.append("ACTUATOR_ID_INVALID")
	if not configuration.get("enabled") is bool:
		errors.append("ACTUATOR_ENABLED_TYPE_INVALID")

	for field in [
		"max_isometric_torque_nm",
		"max_positive_power_w",
		"max_absorption_power_w",
		"max_torque_rate_nm_s",
		"structural_torque_limit_nm",
		"tear_dwell_s",
		"muscle_pcsa_m2",
		"specific_tension_pa",
		"moment_arm_m",
	]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) < 0.0:
			errors.append("%s_INVALID" % String(field).to_upper())
	for field in [
		"no_load_speed_rad_s",
		"activation_time_s",
		"deactivation_time_s",
	]:
		if not _finite_number(configuration.get(field)) or float(configuration[field]) <= 0.001:
			errors.append("%s_INVALID" % String(field).to_upper())
	if (
		not _finite_number(configuration.get("max_eccentric_multiplier"))
		or float(configuration["max_eccentric_multiplier"]) < 1.0
	):
		errors.append("MAX_ECCENTRIC_MULTIPLIER_INVALID")

	var source := String(configuration.get("capacity_source", ""))
	if source not in ["explicit_lab", "anatomy"]:
		errors.append("CAPACITY_SOURCE_INVALID")
	elif source == "explicit_lab":
		if (
			float(configuration.get("muscle_pcsa_m2", NAN)) != 0.0
			or float(configuration.get("specific_tension_pa", NAN)) != 0.0
			or float(configuration.get("moment_arm_m", NAN)) != 0.0
		):
			errors.append("EXPLICIT_LAB_HAS_ANATOMY_DERIVATION")
	elif (
		float(configuration.get("muscle_pcsa_m2", 0.0)) <= 0.0
		or float(configuration.get("specific_tension_pa", 0.0)) <= 0.0
		or float(configuration.get("moment_arm_m", 0.0)) <= 0.0
	):
		errors.append("ANATOMY_DERIVATION_INCOMPLETE")
	else:
		var derived_torque := (
			float(configuration["muscle_pcsa_m2"])
			* float(configuration["specific_tension_pa"])
			* float(configuration["moment_arm_m"])
		)
		var declared_torque := float(configuration["max_isometric_torque_nm"])
		var scale := maxf(derived_torque, 1.0)
		if absf(derived_torque - declared_torque) / scale > 1.0e-9:
			errors.append("ANATOMY_TORQUE_DERIVATION_MISMATCH")

	if not errors.is_empty():
		return {
			"ok": false,
			"failure_code": "ACTUATOR_SPEC_INVALID",
			"errors": errors,
		}
	var payload := configuration.duplicate(true)
	payload["positive_power_cap_enabled"] = (float(configuration["max_positive_power_w"]) > 0.0)
	payload["absorption_power_cap_enabled"] = (float(configuration["max_absorption_power_w"]) > 0.0)
	payload["spec_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {
		"ok": true,
		"spec": FrozenValueScript.snapshot(payload),
	}


static func verify(spec: Dictionary) -> Dictionary:
	var source: Dictionary = {}
	for field in REQUIRED_FIELDS:
		if not spec.has(field):
			return {
				"ok": false,
				"failure_code": "ACTUATOR_SPEC_INCOMPLETE",
			}
		source[field] = spec[field]
	var rebuilt := compile(source)
	if not bool(rebuilt.get("ok", false)):
		return {
			"ok": false,
			"failure_code": "ACTUATOR_SPEC_REBUILD_FAILED",
			"details": rebuilt,
		}
	if CanonicalJsonScript.stringify(rebuilt["spec"]) != CanonicalJsonScript.stringify(spec):
		return {
			"ok": false,
			"failure_code": "ACTUATOR_SPEC_DIGEST_MISMATCH",
		}
	return {"ok": true}


static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _is_stable_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z][A-Za-z0-9._:-]{0,159}$")
	return expression.search(value) != null
