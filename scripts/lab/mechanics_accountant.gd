class_name LabMechanicsAccountant
extends RefCounted

## BR1 body-only mechanics oracle. Articulated energy/contact accounting is
## deliberately blocked until the corresponding observers are calibrated.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")


static func body_transition(
		run_id: String,
		previous_frame: Dictionary,
		current_frame: Dictionary,
		gravity_world_m_s2: Vector3) -> Dictionary:
	var body_id := _first_body_id(previous_frame)
	var previous := _body_by_id(previous_frame, body_id)
	var current := _body_by_id(current_frame, body_id)
	if previous.is_empty() or current.is_empty():
		return {}
	var dt := float(current_frame.get("physics_time_s", 0.0)) - float(
		previous_frame.get("physics_time_s", 0.0))
	if dt <= 0.0 or not is_finite(dt):
		return {}
	var mass := float(current.get("mass_kg", 0.0))
	var v0 := _vec3(previous.get("linear_velocity", []))
	var v1 := _vec3(current.get("linear_velocity", []))
	var p0 := _body_position(previous)
	var p1 := _body_position(current)
	if mass <= 0.0 or not v0.is_finite() or not v1.is_finite():
		return {}
	var observed_acceleration := (v1 - v0) / dt
	var expected_position := p0 + v0 * dt + 0.5 * gravity_world_m_s2 * dt * dt
	var expected_velocity := v0 + gravity_world_m_s2 * dt
	return FrozenValueScript.snapshot({
		"schema": "sporespore.lab.mechanics.v1",
		"run_id": run_id,
		"transition": [
			int(previous_frame.get("frame_id", -1)),
			int(current_frame.get("frame_id", -1)),
		],
		"dt_s": dt,
		"body_id": body_id,
		"mass_kg": mass,
		"linear_momentum_before_n_s": _array3(mass * v0),
		"linear_momentum_after_n_s": _array3(mass * v1),
		"translational_kinetic_energy_before_j": 0.5 * mass * v0.length_squared(),
		"translational_kinetic_energy_after_j": 0.5 * mass * v1.length_squared(),
		"observed_acceleration_m_s2": _array3(observed_acceleration),
		"expected_acceleration_m_s2": _array3(gravity_world_m_s2),
		"acceleration_residual_m_s2": _array3(
			observed_acceleration - gravity_world_m_s2),
		"expected_position_m": _array3(expected_position),
		"position_residual_m": _array3(p1 - expected_position),
		"expected_velocity_m_s": _array3(expected_velocity),
		"velocity_residual_m_s": _array3(v1 - expected_velocity),
		"availability": {
			"/rotational_kinetic_energy_j": {
				"status": "unavailable",
				"reason": "BR1_BODY_ONLY_INERTIA_CHANNEL_NOT_CERTIFIED",
			},
		},
	})


static func _body_by_id(frame: Dictionary, body_id: String) -> Dictionary:
	var bodies: Variant = frame.get("bodies", {})
	if bodies is Dictionary:
		if bodies.has(body_id):
			return bodies[body_id]
		if bodies.size() == 1:
			return bodies.values()[0]
		return {}
	for raw in bodies:
		if raw is Dictionary and String(raw.get("body_id", "")) == body_id:
			return raw
	return {}


static func _first_body_id(frame: Dictionary) -> String:
	var bodies: Variant = frame.get("bodies", {})
	if bodies is Dictionary and not bodies.is_empty():
		var ids: Array = bodies.keys()
		ids.sort()
		return String(ids[0])
	if bodies is Array and not bodies.is_empty() and bodies[0] is Dictionary:
		return String(bodies[0].get("body_id", ""))
	return ""


static func _body_position(body: Dictionary) -> Vector3:
	var transform: Variant = body.get("transform", {})
	if transform is Transform3D:
		return transform.origin
	if transform is Dictionary:
		return _vec3(transform.get("origin", []))
	return _vec3(body.get("position_m", []))


static func _vec3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3(INF, INF, INF)


static func _array3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
