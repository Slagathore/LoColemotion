class_name LabForceToJointMap
extends RefCounted

## Exact sagittal two-link J-transpose map plus declared link-gravity terms.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "two_link_force_map_request_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"joint_1_angle_rad",
	"joint_2_angle_rad",
	"link_1_length_m",
	"link_2_length_m",
	"carriage_mass_kg",
	"link_1_mass_kg",
	"link_2_mass_kg",
	"gravity_m_s2",
	"wrench",
]


static func map(request: Dictionary) -> Dictionary:
	var keys: Array = request.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("FORCE_MAP_FIELD_SET_MISMATCH")
	if String(request.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("FORCE_MAP_SCHEMA_UNSUPPORTED")
	for field in REQUIRED_FIELDS.slice(1, 9):
		if (
			typeof(request.get(field)) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(request[field]))
		):
			return _failure("FORCE_MAP_%s_NONFINITE" % field.to_upper())
	for field in [
		"link_1_length_m",
		"link_2_length_m",
		"carriage_mass_kg",
		"link_1_mass_kg",
		"link_2_mass_kg",
		"gravity_m_s2",
	]:
		if float(request[field]) <= 0.0:
			return _failure("FORCE_MAP_%s_INVALID" % field.to_upper())
	var wrench_value: Variant = request.get("wrench")
	if not wrench_value is Dictionary:
		return _failure("FORCE_MAP_WRENCH_INVALID")
	var wrench: Dictionary = wrench_value
	if (
		String(wrench.get("schema_version", "")) != "body_wrench_v1"
		or String(wrench.get("frame_id", "")) != "world"
	):
		return _failure("FORCE_MAP_WRENCH_INVALID")
	var force := _vector3(wrench.get("force_world_n"))
	var moment := _vector3(wrench.get("moment_world_nm"))
	if not force.is_finite() or not moment.is_finite():
		return _failure("FORCE_MAP_WRENCH_NONFINITE")
	if absf(force.x) > 1.0e-9 or absf(force.z) > 1.0e-9 or moment.length() > 1.0e-9:
		return _failure("FORCE_MAP_V1_VERTICAL_FORCE_ONLY")
	var q1 := float(request["joint_1_angle_rad"])
	var q2 := float(request["joint_2_angle_rad"])
	var absolute_2 := q1 + q2
	var l1 := float(request["link_1_length_m"])
	var l2 := float(request["link_2_length_m"])
	var j_y_1 := l1 * sin(q1) + l2 * sin(absolute_2)
	var j_y_2 := l2 * sin(absolute_2)
	var m1 := float(request["link_1_mass_kg"])
	var m2 := float(request["link_2_mass_kg"])
	var gravity := float(request["gravity_m_s2"])
	var gravity_q1 := gravity * (
		(0.5 * m1 + m2) * l1 * sin(q1)
		+ 0.5 * m2 * l2 * sin(absolute_2)
	)
	var gravity_q2 := gravity * 0.5 * m2 * l2 * sin(absolute_2)
	var load := force.y
	var contact_q1 := j_y_1 * load
	var contact_q2 := j_y_2 * load
	return {
		"ok": true,
		"mapping":
		FrozenValueScript.snapshot(
			{
				"schema_version": "two_link_force_map_v1",
				"joint_1_vertical_jacobian_m": j_y_1,
				"joint_2_vertical_jacobian_m": j_y_2,
				"joint_1_contact_generalized_nm": contact_q1,
				"joint_2_contact_generalized_nm": contact_q2,
				"joint_1_link_gravity_nm": gravity_q1,
				"joint_2_link_gravity_nm": gravity_q2,
				"joint_1_feedforward_nm": gravity_q1 - contact_q1,
				"joint_2_feedforward_nm": gravity_q2 - contact_q2,
				"requested_vertical_load_n": load,
				"carriage_mass_enters_through_load_only": true,
			}
		),
	}


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() == 3:
		var raw: Array = value
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(INF, INF, INF)


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
