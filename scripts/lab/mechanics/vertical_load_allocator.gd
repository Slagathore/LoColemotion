class_name LabVerticalLoadAllocator
extends RefCounted

## BR6A V1 single-contact vertical load allocator.
##
## This allocator has no integral state. Saturation therefore cannot wind up;
## the returned anti-windup flag makes that policy explicit rather than hidden.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "vertical_load_allocation_request_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"tick",
	"mass_kg",
	"gravity_m_s2",
	"height_error_m",
	"vertical_velocity_m_s",
	"position_gain_n_m",
	"velocity_gain_n_s_m",
	"minimum_load_n",
	"maximum_load_n",
	"previous_load_n",
	"maximum_load_rate_n_s",
	"step_s",
]


static func allocate(request: Dictionary) -> Dictionary:
	var keys: Array = request.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("VERTICAL_ALLOCATOR_FIELD_SET_MISMATCH")
	if String(request.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("VERTICAL_ALLOCATOR_SCHEMA_UNSUPPORTED")
	if not request.get("tick") is int or int(request["tick"]) < 0:
		return _failure("VERTICAL_ALLOCATOR_TICK_INVALID")
	for field in REQUIRED_FIELDS.slice(2):
		if (
			typeof(request.get(field)) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(request[field]))
		):
			return _failure("VERTICAL_ALLOCATOR_%s_NONFINITE" % field.to_upper())
	for field in [
		"mass_kg",
		"gravity_m_s2",
		"position_gain_n_m",
		"velocity_gain_n_s_m",
		"maximum_load_rate_n_s",
		"step_s",
	]:
		if float(request[field]) <= 0.0:
			return _failure("VERTICAL_ALLOCATOR_%s_INVALID" % field.to_upper())
	var lower := float(request["minimum_load_n"])
	var upper := float(request["maximum_load_n"])
	var previous := float(request["previous_load_n"])
	if lower < 0.0 or upper <= lower or previous < lower or previous > upper:
		return _failure("VERTICAL_ALLOCATOR_BOUNDS_INVALID")
	var gravity_load := float(request["mass_kg"]) * float(request["gravity_m_s2"])
	var feedback_load := (
		float(request["position_gain_n_m"]) * float(request["height_error_m"])
		- float(request["velocity_gain_n_s_m"]) * float(request["vertical_velocity_m_s"])
	)
	var requested_load := gravity_load + feedback_load
	var bounded_load := clampf(requested_load, lower, upper)
	var maximum_step := float(request["maximum_load_rate_n_s"]) * float(request["step_s"])
	var applied_load := clampf(bounded_load, previous - maximum_step, previous + maximum_step)
	applied_load = clampf(applied_load, lower, upper)
	var causes: Array[String] = []
	if not is_equal_approx(bounded_load, requested_load):
		causes.append("LOAD_BOUNDS")
	if not is_equal_approx(applied_load, bounded_load):
		causes.append("LOAD_RATE")
	return {
		"ok": true,
		"allocation":
		FrozenValueScript.snapshot(
			{
				"schema_version": "vertical_load_allocation_v1",
				"tick": int(request["tick"]),
				"gravity_load_n": gravity_load,
				"feedback_load_n": feedback_load,
				"requested_load_n": requested_load,
				"applied_load_n": applied_load,
				"saturated": not causes.is_empty(),
				"saturation_causes": causes,
				"anti_windup_active": not causes.is_empty(),
				"integrator_present": false,
			}
		),
	}


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
