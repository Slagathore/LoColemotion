class_name LabPlanarContactAllocator
extends RefCounted

## BR7 V2 two-contact planar wrench allocator.
##
## The allocator solves one exact planar wrench:
##
##   sum(Fx_i) = desired_force_x_n
##   sum(Fy_i) = desired_force_y_n
##   sum(x_i * Fy_i) = desired_moment_z_nm
##
## Horizontal force is distributed in proportion to nonnegative normal load.
## The result is feasible only when both unilateral normal bounds and both
## Coulomb friction cones are satisfied. Nothing is clamped into a plausible
## answer: an infeasible request remains explicitly infeasible.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const SCHEMA_VERSION := "planar_contact_allocation_request_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"tick",
	"desired_force_x_n",
	"desired_force_y_n",
	"desired_moment_z_nm",
	"left_support_x_m",
	"right_support_x_m",
	"left_bearing",
	"right_bearing",
	"friction_coefficient",
	"minimum_normal_n",
	"maximum_normal_n",
	"feasibility_tolerance",
]


static func allocate(request: Dictionary) -> Dictionary:
	var keys: Array = request.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("PLANAR_ALLOCATOR_FIELD_SET_MISMATCH")
	if String(request.get("schema_version", "")) != SCHEMA_VERSION:
		return _failure("PLANAR_ALLOCATOR_SCHEMA_UNSUPPORTED")
	if not request.get("tick") is int or int(request["tick"]) < 0:
		return _failure("PLANAR_ALLOCATOR_TICK_INVALID")
	for field in [
		"desired_force_x_n",
		"desired_force_y_n",
		"desired_moment_z_nm",
		"left_support_x_m",
		"right_support_x_m",
		"friction_coefficient",
		"minimum_normal_n",
		"maximum_normal_n",
		"feasibility_tolerance",
	]:
		if (
			typeof(request.get(field)) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(request[field]))
		):
			return _failure("PLANAR_ALLOCATOR_%s_NONFINITE" % field.to_upper())
	for field in ["left_bearing", "right_bearing"]:
		if typeof(request.get(field)) != TYPE_BOOL:
			return _failure("PLANAR_ALLOCATOR_%s_INVALID" % field.to_upper())
	var left_x := float(request["left_support_x_m"])
	var right_x := float(request["right_support_x_m"])
	var friction := float(request["friction_coefficient"])
	var lower := float(request["minimum_normal_n"])
	var upper := float(request["maximum_normal_n"])
	var tolerance := float(request["feasibility_tolerance"])
	if left_x >= right_x or friction < 0.0 or lower < 0.0 or upper <= lower or tolerance <= 0.0:
		return _failure("PLANAR_ALLOCATOR_BOUNDS_INVALID")
	var desired_x := float(request["desired_force_x_n"])
	var desired_y := float(request["desired_force_y_n"])
	var desired_moment := float(request["desired_moment_z_nm"])
	var left_bearing := bool(request["left_bearing"])
	var right_bearing := bool(request["right_bearing"])
	var left_normal := 0.0
	var right_normal := 0.0
	var reasons: Array[String] = []
	if desired_y < -tolerance:
		reasons.append("PULLING_TOTAL_NORMAL_REQUEST")
	if left_bearing and right_bearing:
		var span := right_x - left_x
		right_normal = (desired_moment - left_x * desired_y) / span
		left_normal = desired_y - right_normal
	elif left_bearing:
		left_normal = desired_y
	elif right_bearing:
		right_normal = desired_y
	else:
		reasons.append("NO_BEARING_SUPPORT")
	var total_normal := left_normal + right_normal
	var left_tangent := 0.0
	var right_tangent := 0.0
	if absf(total_normal) > tolerance:
		left_tangent = desired_x * left_normal / total_normal
		right_tangent = desired_x * right_normal / total_normal
	elif absf(desired_x) > tolerance:
		reasons.append("HORIZONTAL_FORCE_WITHOUT_NORMAL_SUPPORT")
	var realized_force_x := left_tangent + right_tangent
	var realized_force_y := total_normal
	var realized_moment := left_x * left_normal + right_x * right_normal
	if left_bearing:
		_check_contact_feasibility(
			"LEFT", left_normal, left_tangent, lower, upper, friction, tolerance, reasons
		)
	elif absf(left_normal) > tolerance or absf(left_tangent) > tolerance:
		reasons.append("LEFT_NONBEARING_LOAD")
	if right_bearing:
		_check_contact_feasibility(
			"RIGHT", right_normal, right_tangent, lower, upper, friction, tolerance, reasons
		)
	elif absf(right_normal) > tolerance or absf(right_tangent) > tolerance:
		reasons.append("RIGHT_NONBEARING_LOAD")
	var force_residual := Vector2(realized_force_x - desired_x, realized_force_y - desired_y)
	var moment_residual := realized_moment - desired_moment
	if force_residual.length() > tolerance:
		reasons.append("FORCE_RESIDUAL")
	if absf(moment_residual) > tolerance:
		reasons.append("PITCH_MOMENT_RESIDUAL")
	return {
		"ok": true,
		"allocation":
		(
			FrozenValueScript
			. snapshot(
				{
					"schema_version": "planar_contact_allocation_v1",
					"tick": int(request["tick"]),
					"feasible": reasons.is_empty(),
					"infeasibility_reasons": reasons,
					"left":
					{
						"bearing": left_bearing,
						"support_x_m": left_x,
						"tangent_force_n": left_tangent,
						"normal_force_n": left_normal,
						"friction_utilization":
						_friction_utilization(left_normal, left_tangent, friction),
					},
					"right":
					{
						"bearing": right_bearing,
						"support_x_m": right_x,
						"tangent_force_n": right_tangent,
						"normal_force_n": right_normal,
						"friction_utilization":
						_friction_utilization(right_normal, right_tangent, friction),
					},
					"desired_force_world_n": [desired_x, desired_y],
					"realized_force_world_n": [realized_force_x, realized_force_y],
					"force_residual_n": [force_residual.x, force_residual.y],
					"desired_moment_z_nm": desired_moment,
					"realized_moment_z_nm": realized_moment,
					"moment_residual_z_nm": moment_residual,
					"allocator_clamped": false,
					"per_contact_values_are_commands_not_measurements": true,
				}
			)
		),
	}


static func _check_contact_feasibility(
	label: String,
	normal: float,
	tangent: float,
	lower: float,
	upper: float,
	friction: float,
	tolerance: float,
	reasons: Array[String]
) -> void:
	if normal < lower - tolerance:
		reasons.append("%s_NORMAL_BELOW_MINIMUM" % label)
	if normal > upper + tolerance:
		reasons.append("%s_NORMAL_ABOVE_MAXIMUM" % label)
	if absf(tangent) > friction * maxf(normal, 0.0) + tolerance:
		reasons.append("%s_FRICTION_CONE_VIOLATION" % label)


static func _friction_utilization(normal: float, tangent: float, friction: float) -> Variant:
	var capacity := friction * maxf(normal, 0.0)
	if capacity <= 0.0:
		return 0.0 if absf(tangent) <= 1.0e-12 else null
	return absf(tangent) / capacity


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
