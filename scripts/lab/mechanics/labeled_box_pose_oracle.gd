class_name LabLabeledBoxPoseOracle
extends RefCounted

## BR12 labeled-box pose oracle.
##
## The authored box basis is right-handed: +X is anatomical right, +Y is
## anatomical up, and -Z is anatomical forward. Known rotations therefore
## provide a geometry-independent sign oracle before a creature is involved.

const OBSERVATION_SCHEMA := "labeled_box_pose_observation_v1"
const REQUIRED_STATE_FIELDS: Array[String] = [
	"basis",
	"support_height_m",
	"reference_stance_height_m",
	"contact_regions",
	"has_foot_support",
	"linear_speed_m_s",
	"angular_speed_rad_s",
	"stable_for_ticks",
]


static func observe(state: Dictionary) -> Dictionary:
	if not _has_exact_fields(state, REQUIRED_STATE_FIELDS):
		return _failure("LABELED_BOX_STATE_FIELDS_INVALID")
	if typeof(state.get("basis")) != TYPE_BASIS:
		return _failure("LABELED_BOX_BASIS_INVALID")
	var basis: Basis = state["basis"]
	if not _basis_is_orthonormal(basis):
		return _failure("LABELED_BOX_BASIS_INVALID")
	for field in [
		"support_height_m",
		"reference_stance_height_m",
		"linear_speed_m_s",
		"angular_speed_rad_s",
	]:
		if not _finite_number(state.get(field)):
			return _failure("LABELED_BOX_NUMERIC_INVALID", {"field": field})
	if (
		float(state["support_height_m"]) < 0.0
		or float(state["reference_stance_height_m"]) <= 0.0
		or float(state["linear_speed_m_s"]) < 0.0
		or float(state["angular_speed_rad_s"]) < 0.0
		or typeof(state.get("has_foot_support")) != TYPE_BOOL
		or typeof(state.get("stable_for_ticks")) != TYPE_INT
		or int(state["stable_for_ticks"]) < 0
	):
		return _failure("LABELED_BOX_STATE_INVALID")
	var contacts := _normalize_contacts(state.get("contact_regions"))
	if not bool(contacts.get("ok", false)):
		return contacts
	return {
		"ok": true,
		"observation":
		{
			"schema_version": OBSERVATION_SCHEMA,
			"anatomical_right_world": basis.x.normalized(),
			"anatomical_up_world": basis.y.normalized(),
			"anatomical_forward_world": (-basis.z).normalized(),
			"support_height_m": float(state["support_height_m"]),
			"reference_stance_height_m": float(state["reference_stance_height_m"]),
			"contact_regions": contacts["roles"],
			"has_foot_support": bool(state["has_foot_support"]),
			"linear_speed_m_s": float(state["linear_speed_m_s"]),
			"angular_speed_rad_s": float(state["angular_speed_rad_s"]),
			"stable_for_ticks": int(state["stable_for_ticks"]),
			"sensor_valid": true,
		},
	}


static func _normalize_contacts(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return _failure("LABELED_BOX_CONTACT_REGIONS_INVALID")
	var seen: Dictionary = {}
	var roles: Array[String] = []
	for role_value in value:
		if typeof(role_value) != TYPE_STRING and typeof(role_value) != TYPE_STRING_NAME:
			return _failure("LABELED_BOX_CONTACT_REGIONS_INVALID")
		var role := String(role_value)
		if role.is_empty() or seen.has(role):
			return _failure("LABELED_BOX_CONTACT_REGIONS_INVALID")
		seen[role] = true
		roles.append(role)
	roles.sort()
	return {"ok": true, "roles": roles}


static func _basis_is_orthonormal(basis: Basis) -> bool:
	if not basis.is_finite():
		return false
	var x := basis.x
	var y := basis.y
	var z := basis.z
	return (
		absf(x.length() - 1.0) <= 1.0e-5
		and absf(y.length() - 1.0) <= 1.0e-5
		and absf(z.length() - 1.0) <= 1.0e-5
		and absf(x.dot(y)) <= 1.0e-5
		and absf(x.dot(z)) <= 1.0e-5
		and absf(y.dot(z)) <= 1.0e-5
		and basis.determinant() > 0.99999
	)


static func _finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


static func _has_exact_fields(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for field in expected:
		if not value.has(field):
			return false
	return true


static func _failure(code: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"ok": false, "failure_code": code}
	for key in extra:
		result[key] = extra[key]
	return result
