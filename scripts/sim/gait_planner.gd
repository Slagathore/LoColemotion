class_name GaitPlanner
extends RefCounted

## The gait PLAN — where each foot is SUPPOSED to be over the stride cycle (docs/LOCOMOTION_ARCHITECTURE.md,
## module 4). This is the coordination the independent-sinusoid CPG could never hold: it keeps the planted
## foot at GROUND LEVEL through the whole power stroke (so it stays in contact and can propel), and only
## lifts the foot during swing. The tracker realizes it with honest joint torque (Jacobian-transpose);
## nothing here touches physics — it's pure geometry, one body-relative foot target per leg per tick.
##
## Trajectory (body frame, forward = local -Z):
##   STANCE (phase < duty): foot planted at rest height, sweeping ahead→behind. A planted foot swept
##     backward while gripping is what carries the body forward. y stays at the rest (ground) level.
##   SWING  (phase >= duty): foot lifts in an arc (sin) and returns behind→ahead to re-plant.
## The two phases meet continuously at the "behind" point (swing start = stance end) and at the "ahead"
## point across the wrap (stance start = swing end), so the target never jumps.

const TAU := PI * 2.0


class Leg:
	extends RefCounted
	var foot_index := -1               # part index of the foot (index-aligned with the fold / bodies)
	var rest_local := Vector3.ZERO     # neutral planted foot position, body-relative (from KinematicSkeleton)
	var phase_offset := 0.0            # [0,1) stride-cycle offset (trot diagonal pairs share a phase)
	var joint_indices: PackedInt32Array  # the leg's actuated joints, hip→foot (the tracker torques these)


var legs: Array[Leg] = []
var frequency := 1.2                  # stride cycles per second
var step_length := 0.22               # body-frame fore-aft sweep of the foot (m)
var step_height := 0.07               # swing-arc lift above the rest height (m)
var duty := 0.6                       # stance fraction of the cycle (>0.5 keeps >1 foot down for support)
var forward_local := Vector3(0.0, 0.0, -1.0)   # body-local heading the creature walks toward


func add_leg(foot_index: int, rest_local: Vector3, phase_offset: float,
		joint_indices := PackedInt32Array()) -> Leg:
	var leg := Leg.new()
	leg.foot_index = foot_index
	leg.rest_local = rest_local
	leg.phase_offset = wrapf(phase_offset, 0.0, 1.0)
	leg.joint_indices = joint_indices
	legs.append(leg)
	return leg


func leg_count() -> int:
	return legs.size()


# The neutral planted foot position (body-relative) for a leg — used to hold a standing pose while the
# creature settles, before the stride cycle starts.
func rest_local(leg_i: int) -> Vector3:
	if leg_i < 0 or leg_i >= legs.size():
		return Vector3.ZERO
	return legs[leg_i].rest_local


# The leg's position in its stride cycle at time t, in [0,1). 0 = start of stance.
func phase_of(leg_i: int, t: float) -> float:
	if leg_i < 0 or leg_i >= legs.size():
		return 0.0
	return wrapf(frequency * t + legs[leg_i].phase_offset, 0.0, 1.0)


func is_stance(leg_i: int, t: float) -> bool:
	return phase_of(leg_i, t) < duty


# Body-relative desired foot position for this leg at time t. This is the reference the tracker pulls
# the real foot toward with joint torque.
func foot_target_local(leg_i: int, t: float) -> Vector3:
	if leg_i < 0 or leg_i >= legs.size():
		return Vector3.ZERO
	var leg := legs[leg_i]
	var r := leg.rest_local
	var fwd := forward_local
	if fwd.length() < 1.0e-6:
		fwd = Vector3(0.0, 0.0, -1.0)
	else:
		fwd = fwd.normalized()
	var phase := phase_of(leg_i, t)
	var horiz := 0.0
	var lift := 0.0
	if phase < duty:
		# STANCE: ahead (+S/2 along fwd) → behind (-S/2), planted at rest height.
		var s := phase / maxf(duty, 1.0e-6)
		horiz = step_length * (0.5 - s)
	else:
		# SWING: behind (-S/2) → ahead (+S/2), arcing up.
		var w := (phase - duty) / maxf(1.0 - duty, 1.0e-6)
		horiz = step_length * (w - 0.5)
		lift = step_height * sin(PI * w)
	return r + fwd * horiz + Vector3.UP * lift


# The fraction of the swing arc completed (0 during stance, ramps 0→1 across swing). Lets the tracker
# ease grip/lift over the swing without recomputing the phase split.
func swing_progress(leg_i: int, t: float) -> float:
	var phase := phase_of(leg_i, t)
	if phase < duty:
		return 0.0
	return (phase - duty) / maxf(1.0 - duty, 1.0e-6)


# Configure the whole gait from a few knobs (used by the controller when it wires a creature's plan).
func configure(freq: float, step_len: float, step_h: float, duty_frac: float,
		fwd := Vector3(0.0, 0.0, -1.0)) -> void:
	frequency = maxf(freq, 0.0)
	step_length = maxf(step_len, 0.0)
	step_height = maxf(step_h, 0.0)
	duty = clampf(duty_frac, 0.05, 0.95)
	forward_local = fwd
