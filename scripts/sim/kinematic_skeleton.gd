class_name KinematicSkeleton
extends RefCounted

## The shared kinematic rig — the "backboard" for how a creature is SUPPOSED to move.
##
## Built from the SAME fold (CharacteristicsEvaluator.fold_graph) that produces the Jolt CreatureBody,
## so a plan generated here is always feasible on the real geometry — no separate "ideal" rig that can
## drift from the physics body (docs/LOCOMOTION_ARCHITECTURE.md, "Shared skeleton"). This class is pure
## geometry + topology; it holds NO physics state. The live joint angles / foot positions are read from
## the RigidBody3D bodies by the controller. What lives here is the static structure every planner needs:
## segment lengths, hinge axes + limits, which parts are feet, leg chains, leg reach, subtree mass.
##
## Index convention: segments[i] is index-aligned with fold parts[i] and CreatureBody.part_bodies()[i].

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

const EPS := 1.0e-6


class Segment:
	extends RefCounted
	var part_index := -1
	var parent_index := -1
	var depth := 0
	var rest_origin := Vector3.ZERO        # bind-time world origin of this part's frame
	var parent_origin := Vector3.ZERO      # bind-time world origin of the parent (≈ the hinge pivot)
	var length := 0.0                      # |rest_origin - parent_origin| (bone length toward parent)
	var hinge_axis_local := Vector3.ZERO   # socket hinge axis, parent-local (zero = no actuated hinge)
	var has_hinge := false
	var rest_angle := 0.0
	var angle_min := 0.0
	var angle_max := 0.0
	var amplitude := 0.0
	var is_foot := false                   # &"ground_contact"
	var is_locomotor := false              # &"locomotor"
	var is_spine := false                  # &"spine"
	var mass := 0.0
	var subtree_indices: PackedInt32Array  # this part + every descendant (topology, static)
	var subtree_mass := 0.0                # sum of masses over subtree_indices


var segments: Array[Segment] = []          # one per fold part, index-aligned
var foot_indices: PackedInt32Array         # parts tagged &"ground_contact"
var root_index := 0                        # the fold root (parts[0])
var warnings: Array = []
var _root_basis := Basis.IDENTITY          # bind-time root frame, for body-local conversions


# Build from a gene tree. root_xform lets a test place the creature; default identity matches the fold.
static func from_gene(root: PartGene, root_xform := Transform3D.IDENTITY) -> KinematicSkeleton:
	var fold := CE.fold_graph(root, root_xform)
	return from_fold(fold)


# Build from an already-computed fold (parts array). Lets callers that already folded reuse it.
static func from_fold(fold: Dictionary) -> KinematicSkeleton:
	var ks := KinematicSkeleton.new()
	var parts: Array = fold.get("parts", [])
	ks.warnings = (fold.get("warnings", []) as Array).duplicate()
	if parts.is_empty():
		ks.warnings.append("empty fold — no segments")
		return ks
	ks._root_basis = parts[0].xform.basis
	# Pass 1: one Segment per part (geometry + joint envelope + tags).
	for p in parts:
		var seg := Segment.new()
		seg.part_index = int(p.index)
		seg.parent_index = int(p.parent)
		seg.depth = int(p.depth)
		seg.rest_origin = p.xform.origin
		seg.mass = float(p.mass)
		if seg.parent_index >= 0 and seg.parent_index < parts.size():
			seg.parent_origin = parts[seg.parent_index].xform.origin
			seg.length = seg.rest_origin.distance_to(seg.parent_origin)
		else:
			seg.parent_origin = seg.rest_origin
			seg.length = 0.0
		seg.hinge_axis_local = p.hinge_axis
		seg.has_hinge = p.hinge_axis.length() > CE.EPS
		if p.joint != null:
			seg.rest_angle = p.joint.rest_angle
			seg.angle_min = p.joint.angle_min
			seg.angle_max = p.joint.angle_max
			seg.amplitude = p.joint.amplitude
		seg.is_foot = p.tags.has(&"ground_contact")
		seg.is_locomotor = p.tags.has(&"locomotor")
		seg.is_spine = p.tags.has(&"spine")
		ks.segments.append(seg)
		if seg.is_foot:
			ks.foot_indices.append(seg.part_index)
	# Pass 2: subtree indices + mass (static topology — used for gravity-comp + reach feasibility).
	for seg in ks.segments:
		var sub := ks._collect_subtree(seg.part_index)
		seg.subtree_indices = sub
		var m := 0.0
		for idx in sub:
			m += ks.segments[idx].mass
		seg.subtree_mass = m
	return ks


# Every part index in the subtree rooted at part_index (inclusive), depth-first.
func _collect_subtree(part_index: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var stack := [part_index]
	var seen := {}
	while not stack.is_empty():
		var u: int = stack.pop_back()
		if seen.has(u) or u < 0 or u >= segments.size():
			continue
		seen[u] = true
		out.append(u)
		for s in segments:
			if s.parent_index == u and not seen.has(s.part_index):
				stack.append(s.part_index)
	return out


func segment_count() -> int:
	return segments.size()


func joint_count() -> int:
	var n := 0
	for s in segments:
		if s.has_hinge:
			n += 1
	return n


func feet() -> PackedInt32Array:
	return foot_indices


# The leg chain for a foot: hip→…→foot, ordered from the body outward. Walks parent-ward from the foot
# collecting locomotor (or foot) segments, stopping at the first non-locomotor ancestor (the body/trunk).
# Returns part indices in hip→foot order — the order FABRIK and the tracker want.
func chain_to_foot(foot_index: int) -> PackedInt32Array:
	var rev := PackedInt32Array()
	var cur := foot_index
	var guard := 0
	while cur >= 0 and cur < segments.size() and guard < segments.size() + 1:
		guard += 1
		var s := segments[cur]
		rev.append(cur)
		# Stop once we've added a segment whose parent is NOT part of the limb (body root reached).
		var pi := s.parent_index
		if pi < 0 or pi >= segments.size():
			break
		var parent := segments[pi]
		if not (parent.is_locomotor or parent.is_foot):
			break
		cur = pi
	# rev is foot→hip; reverse to hip→foot.
	var out := PackedInt32Array()
	for i in range(rev.size() - 1, -1, -1):
		out.append(rev[i])
	return out


# Max straight-line extension of a leg = sum of its segment lengths. The reach budget FABRIK/the
# assembler check a foot target against (target farther than this → unreachable → the gait is infeasible).
func leg_reach(foot_index: int) -> float:
	var chain := chain_to_foot(foot_index)
	var total := 0.0
	for idx in chain:
		# Skip the hip segment's length-to-body; count the bones BETWEEN chain joints + the foot.
		total += segments[idx].length
	return total


# Bind-time foot position relative to the root body frame (the gait's body-relative rest offset). The
# planted-foot rest the GaitPlanner anchors each foot to before it triggers a step.
func foot_rest_local(foot_index: int) -> Vector3:
	if foot_index < 0 or foot_index >= segments.size() or segments.is_empty():
		return Vector3.ZERO
	var root_origin := segments[root_index].rest_origin
	var world_offset := segments[foot_index].rest_origin - root_origin
	return _root_basis.inverse() * world_offset


func subtree_indices(part_index: int) -> PackedInt32Array:
	if part_index < 0 or part_index >= segments.size():
		return PackedInt32Array()
	return segments[part_index].subtree_indices


func subtree_mass(part_index: int) -> float:
	if part_index < 0 or part_index >= segments.size():
		return 0.0
	return segments[part_index].subtree_mass


# The ordered spine chain (parts tagged &"spine"), root-ward to tip. For serpent/centipede the spine IS
# the body; for limbed creatures it's the trunk. Empty if the creature has no spine tag.
func spine_chain() -> PackedInt32Array:
	var spine: Array = []
	for s in segments:
		if s.is_spine:
			spine.append(s)
	spine.sort_custom(func(a, b): return a.depth < b.depth)
	var out := PackedInt32Array()
	for s in spine:
		out.append(s.part_index)
	return out
