class_name JointModel
extends RefCounted

## Shared analytic/live joint helpers. Keep subtree quantities here so the
## evaluator probe and the live CPG controller cannot silently diverge.

const EPS := 1.0e-6
const MIN_MASS := 1.0e-3
const MIN_SIZE := 1.0e-3


static func subtree_inertia(parts: Array, root_idx: int, total_mass := 0.0,
		body_radius := 1.0) -> float:
	if root_idx < 0 or root_idx >= parts.size():
		return EPS
	var origin: Vector3 = parts[root_idx].xform.origin
	var m_sub := 0.0
	var i_sub := 0.0
	var stack := [root_idx]
	var seen := {}
	while not stack.is_empty():
		var u: int = stack.pop_back()
		if seen.has(u) or u < 0 or u >= parts.size():
			continue
		seen[u] = true
		var p = parts[u]
		var r: float = p.com_world.distance_to(origin)
		var inertia_vec := shape_inertia(p.definition.part_type, p.dims, p.mass)
		var i_own := (inertia_vec.x + inertia_vec.y + inertia_vec.z) / 3.0
		m_sub += p.mass
		i_sub += i_own + p.mass * r * r
		for c in parts:
			if int(c.parent) == u and not seen.has(int(c.index)):
				stack.append(int(c.index))
	if i_sub <= EPS or m_sub <= MIN_MASS:
		return maxf(total_mass * maxf(body_radius, MIN_SIZE) * maxf(body_radius, MIN_SIZE), EPS)
	return maxf(i_sub, EPS)


static func subtree_muscle_frac(parts: Array, root_idx: int) -> float:
	if root_idx < 0 or root_idx >= parts.size():
		return 0.0
	var m_sub := 0.0
	var m_mus := 0.0
	var subtree_seen := {}
	var stack := [root_idx]
	var seen := {}
	while not stack.is_empty():
		var u: int = stack.pop_back()
		if seen.has(u) or u < 0 or u >= parts.size():
			continue
		seen[u] = true
		subtree_seen[u] = true
		var p = parts[u]
		m_sub += p.mass
		if p.tags.has(&"muscle"):
			m_mus += p.mass * maxf(float(p.muscle_amount), 0.0)
		for c in parts:
			if int(c.parent) == u and not seen.has(int(c.index)):
				stack.append(int(c.index))
	var local_frac := m_mus / maxf(m_sub, MIN_MASS)
	if m_mus <= 0.0:
		return clampf(local_frac, 0.0, 4.0)
	return clampf(local_frac + 0.5 * core_muscle_frac(parts, subtree_seen), 0.0, 4.0)


static func core_muscle_frac(parts: Array, exclude_indices := {}) -> float:
	var core_mass := 0.0
	var core_muscle := 0.0
	for p in parts:
		var idx := int(p.index)
		if exclude_indices.has(idx):
			continue
		if _inside_locomotor_or_manipulator_subtree(parts, idx):
			continue
		core_mass += p.mass
		if p.tags.has(&"muscle"):
			core_muscle += p.mass * maxf(float(p.muscle_amount), 0.0)
	return clampf(core_muscle / maxf(core_mass, MIN_MASS), 0.0, 4.0)


static func _inside_locomotor_or_manipulator_subtree(parts: Array, idx: int) -> bool:
	var cur := idx
	while cur >= 0 and cur < parts.size():
		var p = parts[cur]
		if p.tags.has(&"locomotor") or p.tags.has(&"ground_contact") or p.tags.has(&"manipulator"):
			return true
		cur = int(p.parent)
	return false


static func shape_inertia(part_type: StringName, dims: Vector3, mass: float) -> Vector3:
	match part_type:
		&"box":
			var wx := dims.x
			var wy := dims.y
			var wz := dims.z
			return Vector3(
					mass / 12.0 * (wy * wy + wz * wz),
					mass / 12.0 * (wx * wx + wz * wz),
					mass / 12.0 * (wx * wx + wy * wy))
		&"sphere":
			var a := dims.x * 0.5
			var b := dims.y * 0.5
			var c := dims.z * 0.5
			return Vector3(
					mass / 5.0 * (b * b + c * c),
					mass / 5.0 * (a * a + c * c),
					mass / 5.0 * (a * a + b * b))
		&"cylinder", &"capsule":
			var rr := (dims.x + dims.z) * 0.25
			var hh := dims.y
			return Vector3(
					mass / 12.0 * (3.0 * rr * rr + hh * hh),
					mass / 2.0 * rr * rr,
					mass / 12.0 * (3.0 * rr * rr + hh * hh))
	return Vector3.ONE * mass
