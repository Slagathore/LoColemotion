class_name LabPlanarSupportSegment
extends RefCounted

## BR7 sagittal support and linear capture-point oracle.
##
## This is a declared planar approximation, not a 3D support polygon and not a
## general viability kernel. It exists to make the first expected loss
## direction and the effect of one missing support explicit.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "planar_support_segment_request_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"com_x_m",
	"com_velocity_x_m_s",
	"com_height_m",
	"gravity_m_s2",
	"left_support_x_m",
	"right_support_x_m",
	"left_bearing",
	"right_bearing",
]


static func evaluate(request: Dictionary) -> Dictionary:
	var keys: Array = request.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("SUPPORT_SEGMENT_FIELD_SET_MISMATCH")
	if String(request.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("SUPPORT_SEGMENT_SCHEMA_UNSUPPORTED")
	for field in [
		"com_x_m",
		"com_velocity_x_m_s",
		"com_height_m",
		"gravity_m_s2",
		"left_support_x_m",
		"right_support_x_m",
	]:
		if (
			typeof(request.get(field)) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(request[field]))
		):
			return _failure("SUPPORT_SEGMENT_%s_NONFINITE" % field.to_upper())
	for field in ["left_bearing", "right_bearing"]:
		if typeof(request.get(field)) != TYPE_BOOL:
			return _failure("SUPPORT_SEGMENT_%s_INVALID" % field.to_upper())
	var height := float(request["com_height_m"])
	var gravity := float(request["gravity_m_s2"])
	var left_x := float(request["left_support_x_m"])
	var right_x := float(request["right_support_x_m"])
	if height <= 0.0 or gravity <= 0.0 or left_x >= right_x:
		return _failure("SUPPORT_SEGMENT_BOUNDS_INVALID")
	var left_bearing := bool(request["left_bearing"])
	var right_bearing := bool(request["right_bearing"])
	var com_x := float(request["com_x_m"])
	var capture_x := com_x + float(request["com_velocity_x_m_s"]) / sqrt(gravity / height)
	var support_min := NAN
	var support_max := NAN
	var support_count := int(left_bearing) + int(right_bearing)
	if left_bearing and right_bearing:
		support_min = left_x
		support_max = right_x
	elif left_bearing:
		support_min = left_x
		support_max = left_x
	elif right_bearing:
		support_min = right_x
		support_max = right_x
	var static_margin := -INF
	var capture_margin := -INF
	var static_direction := "no_support"
	var capture_direction := "no_support"
	if support_count > 0:
		static_margin = minf(com_x - support_min, support_max - com_x)
		capture_margin = minf(capture_x - support_min, support_max - capture_x)
		static_direction = _direction(com_x, support_min, support_max)
		capture_direction = _direction(capture_x, support_min, support_max)
	return {
		"ok": true,
		"support":
		(
			FrozenValueScript
			. snapshot(
				{
					"schema_version": "planar_support_segment_v1",
					"bearing_support_count": support_count,
					"support_min_x_m": support_min,
					"support_max_x_m": support_max,
					"com_x_m": com_x,
					"capture_point_x_m": capture_x,
					"static_margin_m": static_margin,
					"capture_margin_m": capture_margin,
					"static_loss_direction": static_direction,
					"capture_loss_direction": capture_direction,
					"static_inside": static_margin >= 0.0,
					"capture_inside": capture_margin >= 0.0,
					"planar_approximation_only": true,
				}
			)
		),
	}


static func _direction(value: float, support_min: float, support_max: float) -> String:
	if value < support_min:
		return "left"
	if value > support_max:
		return "right"
	return "inside"


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
