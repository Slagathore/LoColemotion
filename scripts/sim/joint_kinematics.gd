class_name JointKinematics
extends RefCounted

## Reads hinge motion from body bases. Godot exposes hinge limits and motors, but
## not a direct hinge-angle getter in GDScript.


static func rest_rel(parent_basis: Basis, child_basis: Basis) -> Basis:
	return parent_basis.inverse() * child_basis


static func hinge_angle(parent_basis: Basis, child_basis: Basis, rest_rel_basis: Basis,
		axis_parent_local: Vector3) -> float:
	var axis := axis_parent_local.normalized()
	if axis.is_zero_approx():
		return 0.0
	var rel := parent_basis.inverse() * child_basis
	var delta := rest_rel_basis.inverse() * rel
	var q := delta.get_rotation_quaternion().normalized()
	var v := Vector3(q.x, q.y, q.z)
	var angle := 2.0 * atan2(v.dot(axis), q.w)
	return wrapf(angle, -PI, PI)
