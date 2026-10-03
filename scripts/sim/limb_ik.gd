class_name LimbIK
extends RefCounted

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const JointKinematicsScript := preload("res://scripts/sim/joint_kinematics.gd")
const DriveIntentScript := preload("res://scripts/sim/drive_intent.gd")

## Lightweight one-step CCD-style IK. It does not move bodies. It estimates which
## hinge target angles would reduce end-effector distance, then CpgController's
## normal torque loop tries to realize those targets.

const CANDIDATE_DELTAS := [-0.75, -0.45, -0.22, 0.0, 0.22, 0.45, 0.75]


static func joint_targets(body: Node3D, root_gene: PartGene, effector_idx: int,
		target_pos: Vector3) -> Array:
	if body == null or root_gene == null or not body.has_method("part_bodies"):
		return []
	var bodies: Array = body.call("part_bodies")
	if effector_idx < 0 or effector_idx >= bodies.size():
		return []
	var fold := CE.fold_graph(root_gene, Transform3D.IDENTITY)
	var parts: Array = fold["parts"]
	var drives: Array = body.call("drive_joints") if body.has_method("drive_joints") else []
	var drive_by_part := {}
	for d in drives:
		drive_by_part[int(d.get("part_index", -1))] = d
	var chain := _chain_to_root(parts, effector_idx)
	var eff := bodies[effector_idx] as RigidBody3D
	if eff == null:
		return []
	var eff_pos := eff.global_position
	var intents: Array = []
	for part_idx in chain:
		if not drive_by_part.has(part_idx):
			continue
		var d: Dictionary = drive_by_part[part_idx]
		var child := d.get("child_body") as RigidBody3D
		var parent := d.get("parent_body") as RigidBody3D
		var joint := d.get("hinge_node") as Joint3D
		if child == null or parent == null or joint == null:
			continue
		var axis: Vector3 = d.get("axis_world", Vector3.ZERO)
		if axis.length() < 0.001:
			continue
		axis = axis.normalized()
		var current := JointKinematicsScript.hinge_angle(parent.global_basis, child.global_basis,
				d.get("rest_rel", Basis.IDENTITY), d.get("axis_parent_local", Vector3.RIGHT))
		var limits: Dictionary = d.get("limits", {})
		var low := float(limits.get("lower", -PI))
		var high := float(limits.get("upper", PI))
		var pivot := joint.global_position
		var best_target := current
		var best_score := eff_pos.distance_to(target_pos)
		for delta in CANDIDATE_DELTAS:
			var candidate := clampf(current + float(delta), low, high)
			var rotated := pivot + Basis(axis, candidate - current) * (eff_pos - pivot)
			var score := rotated.distance_to(target_pos)
			if score < best_score:
				best_score = score
				best_target = candidate
		if absf(best_target - current) > 0.001:
			intents.append(DriveIntentScript.make(part_idx, best_target, 1.0, 4, &"reach_ik"))
	return intents


static func _chain_to_root(parts: Array, effector_idx: int) -> Array[int]:
	var out: Array[int] = []
	var idx := effector_idx
	var guard := 0
	while idx >= 0 and idx < parts.size() and guard < parts.size():
		out.append(idx)
		idx = int(parts[idx].parent)
		guard += 1
	out.reverse()
	return out
