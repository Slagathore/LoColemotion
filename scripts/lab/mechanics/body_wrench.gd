class_name LabBodyWrench
extends RefCounted

## Strict world-frame wrench value used by the BR6A support allocator.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "body_wrench_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"wrench_id",
	"source_id",
	"frame_id",
	"application_point_world_m",
	"force_world_n",
	"moment_world_nm",
]


static func compile(configuration: Dictionary) -> Dictionary:
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("BODY_WRENCH_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("BODY_WRENCH_SCHEMA_UNSUPPORTED")
	for field in ["wrench_id", "source_id"]:
		if not _stable_id(String(configuration.get(field, ""))):
			return _failure("BODY_WRENCH_%s_INVALID" % field.to_upper())
	if String(configuration.get("frame_id", "")) != "world":
		return _failure("BODY_WRENCH_FRAME_UNSUPPORTED")
	for field in ["application_point_world_m", "force_world_n", "moment_world_nm"]:
		if not _vector3(configuration.get(field)).is_finite():
			return _failure("BODY_WRENCH_%s_NONFINITE" % field.to_upper())
	var value := configuration.duplicate(true)
	value["wrench_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {"ok": true, "wrench": FrozenValueScript.snapshot(value)}


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() == 3:
		var raw: Array = value
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(INF, INF, INF)


static func _stable_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z][A-Za-z0-9._:-]{0,159}$")
	return expression.search(value) != null


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
