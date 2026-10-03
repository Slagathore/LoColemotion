class_name LegTracker
extends RefCounted

## Honest leg tracker — pulls the real foot toward the GaitPlanner target using ONLY capped joint
## torque (docs/LOCOMOTION_ARCHITECTURE.md, module 5 "ReferenceTracker"). This is Jacobian-transpose /
## virtual-model control: a virtual PD "spring" at the foot (F = K·(p_des − p_foot) − D·v_foot) is
## realized as joint torques τ_j = (a_j × r_j)·F — the j-th column of Jᵀ. NO foot is pinned in world
## space and NO central force is applied; the foot moves because the joints torque it, reacting against
## the body and (when the foot grips) against the ground. If it can't reach, it under-tracks honestly.
##
## On top of the task force each joint gets a gravity-compensation feed-forward (the CTC G(q) term):
## the torque that holds the distal sub-tree's weight at the current pose — what muscle tone does, honest
## because it's a joint torque whose reaction runs to the ground through the leg. Everything is clamped
## to the joint's muscle-derived tau_cap, so tracking under-shoots rather than overpowering contacts.

const GRAVITY_VEC := Vector3(0.0, -9.80665, 0.0)


# The virtual foot force: a PD "spring" pulling the foot to its planned position, magnitude-capped so a
# large error can't produce an impulsive blowup (the cap is a force ceiling, realized through tau_cap).
static func task_force(p_des: Vector3, p_foot: Vector3, v_foot: Vector3,
		k: float, d: float, max_force: float) -> Vector3:
	var f := (p_des - p_foot) * k - v_foot * d
	var m := f.length()
	if m > max_force and m > 1.0e-9:
		f = f * (max_force / m)
	return f


# The joint torque (about `axis`, at world `pivot`) that drives the foot at world `p_foot` along the
# task force `force`. This is one column of the Jacobian transpose: (axis × (p_foot − pivot)) · force.
static func joint_task_torque(axis: Vector3, pivot: Vector3, p_foot: Vector3,
		force: Vector3) -> float:
	var r := p_foot - pivot
	return axis.cross(r).dot(force)


# Gravity-compensation feed-forward: the joint torque (about `axis`, at `pivot`) needed to HOLD the
# distal sub-tree (mass `subtree_mass`, world CoM `subtree_com`) against gravity at the current pose.
# Gravity's moment about the joint is (c−o) × (m·g); muscle holds it by applying the negative along the
# hinge axis. Honest: it's a joint torque, reaction to ground through the limb (the deleted posture
# LIFT was a reaction-less central force — this is not that).
static func joint_gravity_torque(axis: Vector3, pivot: Vector3, subtree_com: Vector3,
		subtree_mass: float, gravity := GRAVITY_VEC) -> float:
	var moment := (subtree_com - pivot).cross(gravity * subtree_mass)
	return -moment.dot(axis)


# Mass-weighted world CoM of a set of live bodies (the distal sub-tree). Returns pivot as a safe
# fallback if the subtree is massless/empty.
static func subtree_com_world(bodies: Array, indices: PackedInt32Array, fallback: Vector3) -> Vector3:
	var m := 0.0
	var w := Vector3.ZERO
	for idx in indices:
		if idx < 0 or idx >= bodies.size():
			continue
		var rb := bodies[idx] as RigidBody3D
		if rb == null:
			continue
		m += rb.mass
		w += rb.global_position * rb.mass
	if m <= 1.0e-6:
		return fallback
	return w / m
