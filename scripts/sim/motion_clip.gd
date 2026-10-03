class_name MotionClip
extends Resource

## A KINESTHETIC recording of a walk: for each actuated joint, the angle it held at each point in the
## gait cycle (a phase→angle curve), plus the mean torque it needed there (the feed-forward term). It is
## captured while a demonstrator drives the creature to walk under the REAL muscle cap (so every recorded
## force is one a real leg can produce), then baked onto the creature and REPLAYED: each joint is driven
## toward its recorded angle for the current phase with the recorded torque as feed-forward. Feedback
## (SIMBICON) still rides on top. This is the "record what walking needs, then reproduce it" loop.
##
## Keyed by part index (stable within a creature). angles[j] is a bins-long curve for joint j; phase p in
## [0,1) samples bin int(p*bins). torque_ff[j] is that joint's mean |torque| over the cycle (N·m).

@export var bins: int = 24
@export var frequency: float = 1.0                 # cycles/second the clip was captured at
@export var joint_indices: PackedInt32Array = PackedInt32Array()
@export var angles: Array = []                     # per joint: PackedFloat32Array[bins] — angle per phase
@export var torques: Array = []                    # per joint: PackedFloat32Array[bins] — signed N·m per phase


func joint_count() -> int:
	return joint_indices.size()


func has_joint(part_index: int) -> bool:
	return joint_indices.has(part_index)


func _slot(part_index: int) -> int:
	for i in joint_indices.size():
		if joint_indices[i] == part_index:
			return i
	return -1


func _sample(curves: Array, part_index: int, phase: float) -> float:
	var j := _slot(part_index)
	if j < 0 or j >= curves.size():
		return 0.0
	var curve: PackedFloat32Array = curves[j]
	if curve.is_empty():
		return 0.0
	var n := curve.size()
	var x := wrapf(phase, 0.0, 1.0) * float(n)
	var i0 := int(floor(x)) % n
	var i1 := (i0 + 1) % n
	return lerpf(curve[i0], curve[i1], x - floor(x))


# Recorded angle for `part_index` at gait phase p∈[0,1), interpolated between bins.
func angle_at(part_index: int, phase: float) -> float:
	return _sample(angles, part_index, phase)


# Recorded feed-forward torque (signed, N·m) for `part_index` at phase p — what the joint actually
# applied there while walking (so replaying it reproduces both the motion AND the load-bearing).
func torque_at(part_index: int, phase: float) -> float:
	return _sample(torques, part_index, phase)


# Peak |torque| across the whole clip — a quick "how hard did this walk push" readout.
func peak_torque() -> float:
	var pk := 0.0
	for c in torques:
		for v in (c as PackedFloat32Array):
			pk = maxf(pk, absf(v))
	return pk
