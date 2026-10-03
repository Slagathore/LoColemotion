class_name LabWholeBodyState
extends RefCounted

## BR1 body-only whole-system aggregation. Rotational channels remain explicitly
## unavailable until BR2 certifies inertia and reference-frame handling.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")


static func from_frame(frame: Dictionary) -> Dictionary:
	var bodies: Dictionary = frame.get("bodies", {})
	if bodies.is_empty():
		return {}
	var total_mass := 0.0
	var weighted_com := Vector3.ZERO
	var linear_momentum := Vector3.ZERO
	var finite := true
	var body_ids: Array = bodies.keys()
	body_ids.sort()
	for body_id in body_ids:
		var body: Dictionary = bodies[body_id]
		var mass := float(body.get("mass_kg", 0.0))
		var com := _vector3(body.get("center_of_mass_world", []))
		var velocity := _vector3(body.get("linear_velocity", []))
		if (
			mass <= 0.0
			or not is_finite(mass)
			or not com.is_finite()
			or not velocity.is_finite()
			or not bool(body.get("finite", false))
		):
			finite = false
			continue
		total_mass += mass
		weighted_com += mass * com
		linear_momentum += mass * velocity
	if not finite or total_mass <= 0.0:
		return {}
	var center_of_mass := weighted_com / total_mass
	return FrozenValueScript.snapshot({
		"frame_id": int(frame.get("frame_id", -1)),
		"physics_step_id": int(frame.get("physics_step_id", -1)),
		"capture_epoch": int(frame.get("capture_epoch", -1)),
		"body_ids": body_ids,
		"total_mass_kg": total_mass,
		"center_of_mass_world_m": _array3(center_of_mass),
		"linear_momentum_world_n_s": _array3(linear_momentum),
		"center_of_mass_velocity_world_m_s": _array3(
			linear_momentum / total_mass),
		"angular_momentum_about_com_world_n_m_s": null,
		"availability": {
			"/angular_momentum_about_com_world_n_m_s": {
				"status": "unavailable",
				"reason": "BR1_INERTIA_CHANNEL_NOT_CERTIFIED",
				"source": "whole_body_state_v1",
			},
		},
		"finite": true,
	})


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3(INF, INF, INF)


static func _array3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
