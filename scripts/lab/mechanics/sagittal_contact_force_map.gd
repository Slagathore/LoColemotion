class_name LabSagittalContactForceMap
extends RefCounted

## Strict sagittal two-link J-transpose map for one commanded contact force.
##
## This is deliberately separate from force_to_joint_map.gd. The accepted v1
## mapper remains vertical-only; BR10 needs an explicit horizontal contact-force
## component to arrest root translation after a catch. These values are command
## feedforward terms. They are not measured per-foot or per-contact loads.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "sagittal_contact_force_map_request_v1"
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
	"tangent_force_n",
	"normal_force_n",
]
const NUMERIC_FIELDS: Array[String] = [
	"joint_1_angle_rad",
	"joint_2_angle_rad",
	"link_1_length_m",
	"link_2_length_m",
	"carriage_mass_kg",
	"link_1_mass_kg",
	"link_2_mass_kg",
	"gravity_m_s2",
	"tangent_force_n",
	"normal_force_n",
]
const POSITIVE_FIELDS: Array[String] = [
	"link_1_length_m",
	"link_2_length_m",
	"carriage_mass_kg",
	"link_1_mass_kg",
	"link_2_mass_kg",
	"gravity_m_s2",
]


static func map(request: Dictionary) -> Dictionary:
	var keys: Array = request.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("SAGITTAL_FORCE_MAP_FIELD_SET_MISMATCH")
	if String(request.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("SAGITTAL_FORCE_MAP_SCHEMA_UNSUPPORTED")
	for field in NUMERIC_FIELDS:
		var value: Variant = request.get(field)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return _failure("SAGITTAL_FORCE_MAP_NONFINITE_OR_NONNUMERIC:%s" % field)
	for field in POSITIVE_FIELDS:
		if float(request[field]) <= 0.0:
			return _failure("SAGITTAL_FORCE_MAP_POSITIVE_VALUE_INVALID:%s" % field)
	if float(request["normal_force_n"]) < 0.0:
		return _failure("SAGITTAL_FORCE_MAP_UNILATERAL_NORMAL_INVALID")

	var q1 := float(request["joint_1_angle_rad"])
	var q2 := float(request["joint_2_angle_rad"])
	var absolute_2 := q1 + q2
	var l1 := float(request["link_1_length_m"])
	var l2 := float(request["link_2_length_m"])
	var tangent := float(request["tangent_force_n"])
	var normal := float(request["normal_force_n"])
	var j_x_1 := l1 * cos(q1) + l2 * cos(absolute_2)
	var j_x_2 := l2 * cos(absolute_2)
	var j_y_1 := l1 * sin(q1) + l2 * sin(absolute_2)
	var j_y_2 := l2 * sin(absolute_2)
	var m1 := float(request["link_1_mass_kg"])
	var m2 := float(request["link_2_mass_kg"])
	var gravity := float(request["gravity_m_s2"])
	var gravity_q1 := gravity * ((0.5 * m1 + m2) * l1 * sin(q1) + 0.5 * m2 * l2 * sin(absolute_2))
	var gravity_q2 := gravity * 0.5 * m2 * l2 * sin(absolute_2)
	var contact_q1 := j_x_1 * tangent + j_y_1 * normal
	var contact_q2 := j_x_2 * tangent + j_y_2 * normal
	var payload := {
		"schema_version": "sagittal_contact_force_map_v1",
		"request_sha256": CanonicalJsonScript.sha256(request),
		"joint_1_tangent_jacobian_m": j_x_1,
		"joint_2_tangent_jacobian_m": j_x_2,
		"joint_1_normal_jacobian_m": j_y_1,
		"joint_2_normal_jacobian_m": j_y_2,
		"joint_1_contact_generalized_nm": contact_q1,
		"joint_2_contact_generalized_nm": contact_q2,
		"joint_1_link_gravity_nm": gravity_q1,
		"joint_2_link_gravity_nm": gravity_q2,
		"joint_1_feedforward_nm": gravity_q1 - contact_q1,
		"joint_2_feedforward_nm": gravity_q2 - contact_q2,
		"requested_tangent_force_n": tangent,
		"requested_normal_force_n": normal,
		"carriage_mass_enters_through_commanded_load_only": true,
		"commanded_force_is_measured_contact_load": false,
		"per_foot_measurement_established": false,
	}
	return {"ok": true, "mapping": FrozenValueScript.snapshot(payload)}


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
