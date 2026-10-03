class_name LabJointActuator
extends RefCounted

## BR4 active-torque resolver and paired-operation planner.
##
## The result is only a sealed value plan. Physics mutation remains exclusively
## owned by LabActuationExecutor after LabCommandLedger hashes the envelope.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const INPUT_SCHEMA_VERSION := "joint_actuator_input_v1"
const RESULT_SCHEMA_VERSION := "joint_actuator_resolution_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"tick",
	"joint_id",
	"parent_body_id",
	"child_body_id",
	"source_id",
	"behavior_state",
	"axis_world",
	"pivot_world",
	"angular_velocity_rad_s",
	"active_components",
	"passive_components",
	"previous_active_nm",
	"previous_activation",
	"step_s",
]


static func resolve_and_plan(input: Dictionary, spec: Dictionary) -> Dictionary:
	var spec_check := ActuatorSpecScript.verify(spec)
	if not bool(spec_check.get("ok", false)):
		return _failure("JOINT_ACTUATOR_SPEC_INVALID", spec_check)
	var input_check := _validate_input(input)
	if not bool(input_check.get("ok", false)):
		return input_check

	var tick := int(input["tick"])
	var axis := _vector3(input["axis_world"]).normalized()
	var qdot := float(input["angular_velocity_rad_s"])
	var step_s := float(input["step_s"])
	var requested_active := _component_sum(input["active_components"])
	var requested_passive := _component_sum(input["passive_components"])
	var full_bounds := active_bounds_nm(1.0, qdot, spec)
	var requested_direction_cap := (
		float(full_bounds["upper_nm"])
		if requested_active >= 0.0
		else -float(full_bounds["lower_nm"])
	)
	var activation_requested := 0.0
	if absf(requested_active) > 1.0e-9:
		activation_requested = (
			1.0
			if requested_direction_cap <= 1.0e-9
			else clampf(absf(requested_active) / requested_direction_cap, 0.0, 1.0)
		)
	var activation := activation_step(
		float(input["previous_activation"]), activation_requested, step_s, spec
	)
	var bounds := active_bounds_nm(float(activation["activation_applied"]), qdot, spec)
	var rate_step := float(spec["max_torque_rate_nm_s"]) * step_s
	var rate_limited := clampf(
		requested_active,
		float(input["previous_active_nm"]) - rate_step,
		float(input["previous_active_nm"]) + rate_step
	)
	var applied_active := clampf(rate_limited, float(bounds["lower_nm"]), float(bounds["upper_nm"]))
	var candidate_power_w := rate_limited * qdot
	var work_regime := "isometric"
	if candidate_power_w > 1.0e-9:
		work_regime = "positive_work"
	elif candidate_power_w < -1.0e-9:
		work_regime = "negative_work"
	var selected_curve: Dictionary = bounds["positive_work"]
	if work_regime == "negative_work":
		selected_curve = bounds["negative_work"]

	var rate_limited_flag := not is_equal_approx(rate_limited, requested_active)
	var envelope_clamped := not is_equal_approx(applied_active, rate_limited)
	var limit_causes: Array[String] = []
	if rate_limited_flag:
		limit_causes.append("TORQUE_RATE")
	if envelope_clamped:
		var full_direction_bound := (
			float(full_bounds["upper_nm"])
			if rate_limited >= 0.0
			else -float(full_bounds["lower_nm"])
		)
		var applied_direction_bound := (
			float(bounds["upper_nm"]) if rate_limited >= 0.0 else -float(bounds["lower_nm"])
		)
		if applied_direction_bound < full_direction_bound - 1.0e-9:
			limit_causes.append("ACTIVATION")
		if work_regime == "isometric":
			limit_causes.append("ISOMETRIC_TORQUE_CAP")
		else:
			if bool(selected_curve["speed_limited"]):
				limit_causes.append(
					(
						"POSITIVE_WORK_SPEED_CURVE"
						if work_regime == "positive_work"
						else "NEGATIVE_WORK_SPEED_CURVE"
					)
				)
			if bool(selected_curve["power_limited"]):
				limit_causes.append(
					(
						"POSITIVE_POWER_CAP"
						if work_regime == "positive_work"
						else "ABSORPTION_POWER_CAP"
					)
				)

	var total_pre_structure := applied_active + requested_passive
	var structural_cap := float(spec["structural_torque_limit_nm"])
	var applied_total := clampf(total_pre_structure, -structural_cap, structural_cap)
	var structural_reaction := applied_total - total_pre_structure
	var structural_saturated := absf(total_pre_structure) > structural_cap + 1.0e-6
	if structural_saturated:
		limit_causes.append("STRUCTURAL_GUARD")

	var child_torque := axis * applied_total
	var parent_torque := -child_torque
	var joint_id := String(input["joint_id"])
	var resolution := {
		"schema_version": RESULT_SCHEMA_VERSION,
		"tick": tick,
		"joint_id": joint_id,
		"parent_body_id": String(input["parent_body_id"]),
		"child_body_id": String(input["child_body_id"]),
		"source_id": String(input["source_id"]),
		"behavior_state": String(input["behavior_state"]),
		"actuator_id": String(spec["actuator_id"]),
		"actuator_spec_sha256": String(spec["spec_sha256"]),
		"axis_world": axis,
		"pivot_world": _vector3(input["pivot_world"]),
		"angular_velocity_rad_s": qdot,
		"active_components": input["active_components"],
		"passive_components": input["passive_components"],
		"requested_active_nm": requested_active,
		"rate_limited_active_nm": rate_limited,
		"applied_active_nm": applied_active,
		"requested_passive_nm": requested_passive,
		"applied_passive_nm": requested_passive,
		"total_pre_structure_nm": total_pre_structure,
		"structural_guard_reaction_nm": structural_reaction,
		"applied_total_nm": applied_total,
		"structural_cap_nm": structural_cap,
		"active_lower_bound_nm": float(bounds["lower_nm"]),
		"active_upper_bound_nm": float(bounds["upper_nm"]),
		"selected_work_regime": work_regime,
		"limit_causes": limit_causes,
		"activation_previous": float(activation["activation_previous"]),
		"activation_requested": float(activation["activation_requested"]),
		"activation_applied": float(activation["activation_applied"]),
		"activation_next": float(activation["activation_next"]),
		"activation_update_phase": "transition_mean",
		"active_saturated": envelope_clamped,
		"torque_rate_limited": rate_limited_flag,
		"speed_limited":
		envelope_clamped and work_regime != "isometric" and bool(selected_curve["speed_limited"]),
		"power_limited":
		envelope_clamped and work_regime != "isometric" and bool(selected_curve["power_limited"]),
		"structural_saturated": structural_saturated,
		"active_power_w": applied_active * qdot,
		"passive_power_w": requested_passive * qdot,
		"structural_guard_power_w": structural_reaction * qdot,
		"applied_total_power_w": applied_total * qdot,
	}
	var command := resolution.duplicate(true)
	command.erase("schema_version")
	command["planned_application_operations"] = [
		{
			"operation_id": "%s.%06d.child" % [joint_id, tick],
			"body_id": String(input["child_body_id"]),
			"api": "RigidBody3D.apply_torque",
			"torque_world_nm": child_torque,
			"arguments": {"torque_world_nm": child_torque},
		},
		{
			"operation_id": "%s.%06d.parent" % [joint_id, tick],
			"body_id": String(input["parent_body_id"]),
			"api": "RigidBody3D.apply_torque",
			"torque_world_nm": parent_torque,
			"arguments": {"torque_world_nm": parent_torque},
		},
	]
	command["diagnostics"] = {
		"pairing_contract": "equal_opposite_v1",
		"pairing_residual_nm": (child_torque + parent_torque).length(),
	}
	return {
		"ok": true,
		"resolution": FrozenValueScript.snapshot(resolution),
		"command": FrozenValueScript.snapshot(command),
	}


static func activation_step(
	current: float, requested: float, step_s: float, spec: Dictionary
) -> Dictionary:
	var target := clampf(requested, 0.0, 1.0)
	var time_constant := (
		float(spec["activation_time_s"]) if target > current else float(spec["deactivation_time_s"])
	)
	var decay := exp(-step_s / time_constant)
	var next := target + (current - target) * decay
	var mean := target + (current - target) * (time_constant / step_s) * (1.0 - decay)
	return {
		"activation_previous": current,
		"activation_requested": target,
		"activation_applied": clampf(mean, 0.0, 1.0),
		"activation_next": clampf(next, 0.0, 1.0),
	}


static func active_bounds_nm(activation: float, omega_rad_s: float, spec: Dictionary) -> Dictionary:
	var positive_work := _capacity_for_work_sign_nm(activation, omega_rad_s, false, spec)
	var negative_work := _capacity_for_work_sign_nm(activation, omega_rad_s, true, spec)
	var lower_nm := 0.0
	var upper_nm := 0.0
	if omega_rad_s > 0.001:
		lower_nm = -float(negative_work["cap_nm"])
		upper_nm = float(positive_work["cap_nm"])
	elif omega_rad_s < -0.001:
		lower_nm = -float(positive_work["cap_nm"])
		upper_nm = float(negative_work["cap_nm"])
	else:
		var isometric := (
			clampf(activation, 0.0, 1.0) * float(spec["max_isometric_torque_nm"])
			if bool(spec["enabled"])
			else 0.0
		)
		lower_nm = -isometric
		upper_nm = isometric
	return {
		"lower_nm": lower_nm,
		"upper_nm": upper_nm,
		"positive_work": positive_work,
		"negative_work": negative_work,
	}


static func _capacity_for_work_sign_nm(
	activation: float, omega_rad_s: float, negative_work: bool, spec: Dictionary
) -> Dictionary:
	if not bool(spec["enabled"]):
		return {
			"cap_nm": 0.0,
			"speed_limited": false,
			"power_limited": false,
		}
	var speed_ratio := absf(omega_rad_s) / float(spec["no_load_speed_rad_s"])
	var speed_factor := clampf(1.0 - speed_ratio, 0.0, 1.0)
	if negative_work:
		speed_factor = minf(float(spec["max_eccentric_multiplier"]), 1.0 + 0.25 * speed_ratio)
	var speed_cap := float(spec["max_isometric_torque_nm"]) * speed_factor
	var selected_power := (
		float(spec["max_absorption_power_w"])
		if negative_work
		else float(spec["max_positive_power_w"])
	)
	var power_cap := INF
	if selected_power > 0.0 and absf(omega_rad_s) > 0.001:
		power_cap = selected_power / absf(omega_rad_s)
	var cap := minf(speed_cap, power_cap) * clampf(activation, 0.0, 1.0)
	return {
		"cap_nm": cap,
		"speed_limited": speed_cap <= power_cap + 1.0e-9,
		"power_limited": power_cap <= speed_cap + 1.0e-9,
	}


static func _validate_input(input: Dictionary) -> Dictionary:
	var keys: Array = input.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		return _failure("JOINT_ACTUATOR_INPUT_FIELD_SET_MISMATCH")
	if String(input.get("schema_version", "")) != INPUT_SCHEMA_VERSION:
		return _failure("JOINT_ACTUATOR_INPUT_SCHEMA_UNSUPPORTED")
	if not input.get("tick") is int or int(input["tick"]) < 0:
		return _failure("JOINT_ACTUATOR_TICK_INVALID")
	for field in [
		"joint_id",
		"parent_body_id",
		"child_body_id",
		"source_id",
		"behavior_state",
	]:
		if not _is_stable_id(String(input.get(field, ""))):
			return _failure("JOINT_ACTUATOR_%s_INVALID" % String(field).to_upper())
	if String(input["parent_body_id"]) == String(input["child_body_id"]):
		return _failure("JOINT_ACTUATOR_SELF_PAIR_FORBIDDEN")
	var axis := _vector3(input.get("axis_world"))
	var pivot := _vector3(input.get("pivot_world"))
	if not axis.is_finite() or absf(axis.length() - 1.0) > 1.0e-4 or not pivot.is_finite():
		return _failure("JOINT_ACTUATOR_FRAME_INVALID")
	for field in [
		"angular_velocity_rad_s",
		"previous_active_nm",
		"previous_activation",
		"step_s",
	]:
		if not _finite_number(input.get(field)):
			return _failure("JOINT_ACTUATOR_%s_NONFINITE" % String(field).to_upper())
	if float(input["step_s"]) <= 0.0:
		return _failure("JOINT_ACTUATOR_STEP_INVALID")
	if float(input["previous_activation"]) < 0.0 or float(input["previous_activation"]) > 1.0:
		return _failure("JOINT_ACTUATOR_PREVIOUS_ACTIVATION_INVALID")
	for field in ["active_components", "passive_components"]:
		if not input.get(field) is Dictionary:
			return _failure("JOINT_ACTUATOR_COMPONENTS_INVALID")
		for key in (input[field] as Dictionary).keys():
			if (
				not _is_stable_id(String(key))
				or not _finite_number((input[field] as Dictionary)[key])
			):
				return _failure("JOINT_ACTUATOR_COMPONENT_INVALID")
	return {"ok": true}


static func _component_sum(components: Dictionary) -> float:
	var total := 0.0
	for value in components.values():
		total += float(value)
	return total


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() == 3:
		var raw: Array = value
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(INF, INF, INF)


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
