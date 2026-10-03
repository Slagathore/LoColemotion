class_name Track
extends RefCounted

## A training track = a world to build + a way to score the measured rollout. The
## trainer/optimizer evaluate `score(measured)` instead of hardcoding "forward",
## so the same loop can chase different objectives.
##
## Note: the curved and off-axis target tracks are only PASSABLE once the
## controller can steer (CpgController.Params.turn_rate, M7's steering step) — the
## scoring here is the well-defined gradient that steering then climbs. The
## straight and obstacle tracks work with today's straight-only gait.

const SimWorldScript := preload("res://scripts/sim/sim_world.gd")
const WorldObjectScript := preload("res://scripts/sim/world_object.gd")
const PUSH_MIN_ROOT_UP_DOT := 0.45

# M36-1 Economy reward (Principle 18): make the optimizer KEEP honest springs instead of
# deleting them. Gated behind `credible` so a non-mover earns nothing. Additive + capped so
# distance still dominates; a more-efficient walker of equal distance now wins.
const ECON_W := 0.5
# COT_REF tuned 2026-06-28 to the MEASURED median credible-walker cost-of-transport after the
# M36 honest-spring swap: quad 0.13, hex 0.03, spider 1.34, segmented 7.83 -> median 0.74.
# (Cole's note: 6.0 was a placeholder; this is the data-driven value.) Below-reference CoT pays,
# so the two efficient walkers (quad/hex) earn a modest tiebreaker bonus and the inefficient
# ones earn nothing. See the doc impl log (§7, M36-1) for the measurement run.
const COT_REF := 0.74
# SPRING_RET_W raised 0.4 -> 0.6 so the elastic-return reward strictly EXCEEDS an honest
# spring's un-optimized gait drag (measured ~1.5-1.6 on monopod/frog). Without this the
# optimizer would delete the spring (Principle 18 regression). Still capped, so non-locomoting
# spring-wiggle can't farm it (and the bonus is gated behind `credible`).
const SPRING_RET_W := 0.6
const SPRING_RET_CAP := 4.0

var kind := &"straight"
var mode: StringName = &""      # M38: objective-mode hint; "" = infer from kind. The ACHIEVED
                               # mode is detected from behaviour by SimRollout, not from this.
var friction := 1.0
var obstacles: Array = []      # [{pos:Vector3, size:Vector3}]
var target_distance := 6.0     # target track: meters ahead of spawn (along heading)
var target_radius := 1.0
var curve_radius := 8.0         # curved track: arc radius
var curve_dir := 1.0            # +1 = turn left, -1 = turn right
var push_distance := 2.0
var push_target := 1.0
var hop_min_bounce := 0.25
var apply_radius := 0.75
var runtime_objects: Array[RigidBody3D] = []


static func straight() -> Track:
	var t := Track.new()
	t.kind = &"straight"
	return t


static func obstacle(rows := 4, spacing := 1.6, height := 0.18) -> Track:
	var t := Track.new()
	t.kind = &"obstacle"
	for i in rows:
		var z := -(2.0 + i * spacing)          # ahead of spawn (-Z is forward)
		t.obstacles.append({"pos": Vector3(0.0, height * 0.5, z),
				"size": Vector3(4.0, height, 0.3)})
	return t


static func target(distance := 6.0, radius := 1.0) -> Track:
	var t := Track.new()
	t.kind = &"target"
	t.target_distance = distance
	t.target_radius = radius
	return t


static func curved(radius := 8.0, dir := 1.0) -> Track:
	var t := Track.new()
	t.kind = &"curved"
	t.curve_radius = radius
	t.curve_dir = signf(dir) if dir != 0.0 else 1.0
	return t


static func push_object(distance := 2.0, target_move := 1.0) -> Track:
	var t := Track.new()
	t.kind = &"push"
	t.push_distance = distance
	t.push_target = target_move
	return t


static func grasp_carry(carry_target := 1.0) -> Track:
	var t := Track.new()
	t.kind = &"grasp"
	t.push_target = carry_target   # reuse push_target as the carry-distance goal (meters)
	return t


static func tool_use(target_distance := 2.0, radius := 0.75) -> Track:
	var t := Track.new()
	t.kind = &"tool"
	t.target_distance = target_distance
	t.apply_radius = radius
	t.push_target = target_distance * 0.5
	return t


# M53 Toybox — arena hazards. Each is a Track variant + a physics tweak; they test robustness AND
# are fun to watch. friction/linear_damp/wind/gravity_scale are applied by SimRollout to the body.
var linear_damp := 0.0          # mud: per-body velocity damping
var wind := Vector3.ZERO        # wind: steady lateral force per unit mass (accel)
var gravity_scale := 1.0        # low_g: per-body gravity multiplier


static func ice(distance := 4.0) -> Track:
	var t := Track.new()
	t.kind = &"straight"
	t.friction = 0.04            # slick — feet skate unless the gait plants hard
	t.target_distance = distance
	return t


static func mud(distance := 4.0) -> Track:
	var t := Track.new()
	t.kind = &"straight"
	t.linear_damp = 2.5          # thick — every motion is dragged
	t.target_distance = distance
	return t


static func wind_track(force := Vector3(3.0, 0.0, 0.0)) -> Track:
	var t := Track.new()
	t.kind = &"straight"
	t.wind = force               # steady sideways gust (accel, m/s²)
	return t


static func low_g(scale := 0.35) -> Track:
	var t := Track.new()
	t.kind = &"straight"
	t.gravity_scale = clampf(scale, 0.0, 1.0)
	return t


# Hazard parameters SimRollout applies to the creature's rigid bodies. {} when there's nothing to do.
func hazard_physics() -> Dictionary:
	return {
		"linear_damp": linear_damp,
		"wind": wind,
		"gravity_scale": gravity_scale,
	}


func has_hazard() -> bool:
	return linear_damp > 0.0 or wind != Vector3.ZERO or not is_equal_approx(gravity_scale, 1.0)


static func hop(distance := 2.5, min_bounce := 0.25) -> Track:
	var t := Track.new()
	t.kind = &"hop"
	t.target_distance = distance
	t.hop_min_bounce = min_bounce
	return t


static func lateral(distance := 2.0) -> Track:
	var t := Track.new()
	t.kind = &"lateral"
	t.target_distance = distance
	return t


# SimRollout asks this whether to run contact-triggered grasp during the rollout.
func auto_grasp() -> bool:
	return kind == &"grasp" or kind == &"tool"


# M38: the objective mode this track trains for. Explicit `mode` wins; otherwise inferred
# from kind. Locomotion tracks that aren't hop/lateral default to walk.
func objective_mode() -> StringName:
	if mode != &"":
		return mode
	match kind:
		&"hop":
			return &"hop"
		&"lateral":
			return &"lateral"
		_:
			return &"walk"


func build_world(world: Node3D) -> void:
	runtime_objects.clear()
	SimWorldScript.add_floor(world, friction)
	match kind:
		&"obstacle":
			for ob in obstacles:
				var sb := StaticBody3D.new()
				sb.position = ob["pos"]
				sb.physics_material_override = SimWorldScript.make_physics_material(friction, 0.0)
				var cs := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = ob["size"]
				cs.shape = box
				sb.add_child(cs)
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = ob["size"]
				mi.mesh = bm
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.30, 0.22, 0.22)
				mi.material_override = mat
				sb.add_child(mi)
				world.add_child(sb)
		&"push":
			var obj := WorldObjectScript.make_push_block(Vector3(0.0, 0.25, -push_distance))
			world.add_child(obj)
			runtime_objects.append(obj)
		&"grasp":
			# A graspable morsel placed at the carrier's spawn so contact forms on the
			# first ticks; SimRollout welds it on proximity, then it is carried.
			var food := WorldObjectScript.make_food(Vector3(0.0, 0.55, -0.2))
			world.add_child(food)
			runtime_objects.append(food)
		&"tool":
			var tool := WorldObjectScript.make_tool(Vector3(0.0, 0.55, -0.2))
			var target := WorldObjectScript.make_tool_target(Vector3(0.0, 0.25, -target_distance))
			world.add_child(tool)
			world.add_child(target)
			runtime_objects.append(tool)
			runtime_objects.append(target)


func collect_metrics(m: Dictionary) -> Dictionary:
	if runtime_objects.is_empty():
		return {}
	if kind == &"tool":
		return _collect_tool_metrics(m)
	if kind != &"push":
		return {}
	var heading: Vector3 = m.get("heading", Vector3.FORWARD)
	var rows: Array = []
	var best_forward := 0.0
	for rb in runtime_objects:
		if rb == null:
			continue
		var start: Vector3 = rb.get_meta("start_pos", rb.global_position)
		var delta := rb.global_position - start
		var fwd := Vector3(delta.x, 0.0, delta.z).dot(heading)
		best_forward = maxf(best_forward, fwd)
		rows.append({
			"kind": String(rb.get_meta("world_object_kind", &"object")),
			"start": start,
			"end": rb.global_position,
			"forward": fwd,
			"graspable": bool(rb.get_meta("graspable", false)),
		})
	return {
		"objects": rows,
		"object_forward": best_forward,
		"object_target": push_target,
	}


func _collect_tool_metrics(m: Dictionary) -> Dictionary:
	var tool: RigidBody3D = null
	var target: RigidBody3D = null
	for rb in runtime_objects:
		if rb == null:
			continue
		var k: StringName = rb.get_meta("world_object_kind", &"object")
		if k == &"tool":
			tool = rb
		elif k == &"tool_target":
			target = rb
	if tool == null or target == null:
		return {"tool_applied": false, "tool_reasons": ["missing tool or target"]}
	var dist := tool.global_position.distance_to(target.global_position)
	var carried := bool(m.get("grasp_grasped", false)) and bool(m.get("grasp_follows", false)) \
			and float(m.get("grasp_carry", 0.0)) >= push_target
	var applied := carried and dist <= apply_radius
	var flung := dist <= apply_radius and not carried
	var progress := (1 if bool(m.get("grasp_grasped", false)) else 0) + (1 if carried else 0) + (1 if applied else 0)
	return {
		"tool_applied": applied,
		"tool_carried": carried,
		"tool_flung": flung,
		"tool_distance_to_target": dist,
		"tool_progress": progress,
		"tool_target_radius": apply_radius,
	}


# {fitness, credible, class, reasons, progress} from a SimRollout measured dict.
func score(m: Dictionary) -> Dictionary:
	match kind:
		&"target":
			return _score_target(m)
		&"curved":
			return _score_curved(m)
		&"push":
			return _score_push(m)
		&"grasp":
			return _score_grasp(m)
		&"tool":
			return _score_tool(m)
		&"hop":
			return _score_hop(m)
		&"lateral":
			return _score_lateral(m)
	return _score_distance(m)   # straight + obstacle


# Straight/obstacle: reuse the credibility gate; reward sustained forward distance.
func _score_distance(m: Dictionary) -> Dictionary:
	var fwd := float(m.get("forward", 0.0))
	var tail := float(m.get("forward_tail", 0.0))
	var lateral := absf(float(m.get("lateral", 0.0)))
	var credible := bool(m.get("credible_walk", false))
	var fitness := fwd + 3.0 * tail - 0.3 * lateral
	if credible:
		fitness += _economy_bonus(m)
	else:
		fitness = -10.0 + minf(fwd, 3.0) + 0.25 * tail - 0.3 * lateral
	return {"fitness": fitness, "credible": credible,
		"class": String(m.get("locomotion_class", "?")),
		"reasons": m.get("locomotion_reasons", []), "progress": fwd}


# M36-1: economy + elastic-return reward. Only for gaits past the credible floor, so a
# non-mover (huge cot, zero return work) earns nothing. cot carries distance in its
# denominator -> standing still is penalised, not rewarded. Capped so distance dominates.
func _economy_bonus(m: Dictionary) -> float:
	var cot := float(m.get("cost_of_transport", INF))
	var ret := float(m.get("spring_return_work", 0.0))
	var bonus := ECON_W * maxf(0.0, COT_REF - cot)          # below-reference CoT pays
	bonus += SPRING_RET_W * minf(ret, SPRING_RET_CAP)       # returned elastic work pays
	return bonus


# Target: get within radius of a point `target_distance` ahead and stay upright.
func _score_target(m: Dictionary) -> Dictionary:
	var fwd := float(m.get("forward", 0.0))
	var lateral := float(m.get("lateral", 0.0))
	var fell := bool(m.get("fell", false))
	var dist := sqrt(pow(target_distance - fwd, 2.0) + lateral * lateral)
	var reached := dist <= target_radius and not fell
	var fitness := -dist + (5.0 if reached else 0.0)
	var cls := "reached" if reached else ("fell" if fell else "missed")
	var reasons: Array = []
	if fell:
		reasons.append("fell before reaching target")
	elif not reached:
		reasons.append("stopped %.2fm from target" % dist)
	return {"fitness": fitness, "credible": reached, "class": cls,
		"reasons": reasons, "progress": maxf(0.0, target_distance - dist)}


# Curved: follow an arc of `curve_radius` turning in `curve_dir`. Progress = arc
# length swept in the turn direction; penalize cross-track error and falls.
func _score_curved(m: Dictionary) -> Dictionary:
	var traj: Array = m.get("trajectory", [])
	var fell := bool(m.get("fell", false))
	if traj.size() < 2:
		return {"fitness": -10.0, "credible": false, "class": "no_path",
			"reasons": ["no trajectory"], "progress": 0.0}
	var start: Vector3 = traj[0]
	var heading: Vector3 = m.get("heading", Vector3.FORWARD)
	var left := Vector3(heading.z, 0.0, -heading.x).normalized()   # 90deg left of heading
	var center := start + left * (curve_dir * curve_radius)
	var prev := atan2(start.x - center.x, start.z - center.z)
	var swept := 0.0
	var cross_sum := 0.0
	for i in range(1, traj.size()):
		var p: Vector3 = traj[i]
		var theta := atan2(p.x - center.x, p.z - center.z)
		swept += wrapf(theta - prev, -PI, PI) * curve_dir   # turn-direction progress
		prev = theta
		cross_sum += absf(Vector2(p.x - center.x, p.z - center.z).length() - curve_radius)
	var progress := curve_radius * maxf(swept, 0.0)
	var cross := cross_sum / float(traj.size() - 1)
	var fitness := progress - 0.5 * cross - (5.0 if fell else 0.0)
	var credible := progress > curve_radius * 0.3 and not fell and cross < curve_radius * 0.4
	var reasons: Array = []
	if fell:
		reasons.append("fell")
	if cross >= curve_radius * 0.4:
		reasons.append("drifted off the curve (cross-track %.2fm)" % cross)
	return {"fitness": fitness, "credible": credible,
		"class": "followed_curve" if credible else "off_curve",
		"reasons": reasons, "progress": progress}


# Grasp/carry: a graspable object must be welded to a carrier (grasp joint existed),
# move WITH the hand (object_follows_hand), and be carried at least push_target meters,
# all without the creature falling. Phantom-grasp / carry-by-clipping are rejected
# because they break the follows-hand or grasped invariants.
func _score_grasp(m: Dictionary) -> Dictionary:
	var grasped := bool(m.get("grasp_grasped", false))
	var follows := bool(m.get("grasp_follows", false))
	var carry := float(m.get("grasp_carry", 0.0))
	var fell := bool(m.get("fell", false))
	var finite := bool(m.get("ok", true))
	var credible := grasped and follows and carry >= push_target and not fell and finite
	var fitness := (carry * 5.0 if grasped and follows else -5.0) - (8.0 if fell or not finite else 0.0)
	var reasons: Array = []
	if not grasped:
		reasons.append("never grasped the object")
	elif not follows:
		reasons.append("object did not move with the hand (phantom/clipping grasp)")
	elif carry < push_target:
		reasons.append("carried %.2fm, below %.2fm target" % [carry, push_target])
	if fell:
		reasons.append("creature fell while carrying")
	if not finite:
		reasons.append("non-finite sim")
	return {"fitness": fitness, "credible": credible,
		"class": "carried" if credible else "grasp_failed",
		"reasons": reasons, "progress": carry}


func _score_tool(m: Dictionary) -> Dictionary:
	var base: Dictionary = WorldObjectScript.tool_sequence_score(
			bool(m.get("grasp_grasped", false)),
			bool(m.get("tool_carried", false)),
			bool(m.get("tool_applied", false)),
			bool(m.get("tool_flung", false)),
			bool(m.get("fell", false)))
	var dist := float(m.get("tool_distance_to_target", target_distance))
	base["fitness"] = float(base["fitness"]) + maxf(0.0, target_distance - dist)
	base["progress"] = int(m.get("tool_progress", base.get("progress", 0)))
	base["distance_to_target"] = dist
	return base


func _score_hop(m: Dictionary) -> Dictionary:
	var fwd := float(m.get("forward", 0.0))
	var bounce := float(m.get("bounce", 0.0))
	var fell := bool(m.get("fell", false))
	var theta := float(m.get("theta_span", 0.0))
	var omega := float(m.get("max_omega", 0.0))
	var reached := fwd >= target_distance
	var bounced := bounce >= hop_min_bounce
	var actuated := theta >= 0.20 and omega >= 0.35
	var credible := reached and bounced and actuated and not fell
	var fitness := fwd + bounce * 4.0 - (6.0 if fell else 0.0)
	if credible:
		fitness += _economy_bonus(m)
	var reasons: Array = []
	if not reached:
		reasons.append("hop distance %.2fm below %.2fm target" % [fwd, target_distance])
	if not bounced:
		reasons.append("vertical hop %.2fm below %.2fm target" % [bounce, hop_min_bounce])
	if not actuated:
		reasons.append("no spring-leg actuation")
	if fell:
		reasons.append("fell during hop")
	return {"fitness": fitness, "credible": credible,
		"class": "hopped" if credible else "hop_failed",
		"reasons": reasons, "progress": fwd}


func _score_lateral(m: Dictionary) -> Dictionary:
	var lateral := absf(float(m.get("lateral", 0.0)))
	var fwd := absf(float(m.get("forward", 0.0)))
	var ratio := float(m.get("lateral_ratio", 0.0))
	var fell := bool(m.get("fell", false))
	var theta := float(m.get("theta_span", 0.0))
	var omega := float(m.get("max_omega", 0.0))
	var reached := lateral >= target_distance
	var side_dominant := ratio >= 0.65 and lateral > fwd
	var actuated := theta >= 0.20 and omega >= 0.35
	var credible := reached and side_dominant and actuated and not fell
	var fitness := lateral - 0.35 * fwd - (6.0 if fell else 0.0)
	var reasons: Array = []
	if not reached:
		reasons.append("lateral distance %.2fm below %.2fm target" % [lateral, target_distance])
	if not side_dominant:
		reasons.append("movement was not side-dominant")
	if not actuated:
		reasons.append("no side-leg actuation")
	if fell:
		reasons.append("fell during lateral gait")
	return {"fitness": fitness, "credible": credible,
		"class": "lateral_scuttle" if credible else "lateral_failed",
		"reasons": reasons, "progress": lateral}


func _score_push(m: Dictionary) -> Dictionary:
	var obj_forward := float(m.get("object_forward", 0.0))
	var fell := bool(m.get("fell", false))
	var finite := bool(m.get("ok", true))
	var root_up := float(m.get("root_up_min", 1.0))
	var credible := obj_forward >= push_target and not fell and finite and root_up >= PUSH_MIN_ROOT_UP_DOT
	var fitness := obj_forward * 5.0 + float(m.get("forward", 0.0)) * 0.25 - (8.0 if fell or not finite else 0.0)
	var reasons: Array = []
	if obj_forward < push_target:
		reasons.append("object moved %.2fm, below %.2fm target" % [obj_forward, push_target])
	if fell:
		reasons.append("creature fell during push")
	if not finite:
		reasons.append("non-finite sim")
	if root_up < PUSH_MIN_ROOT_UP_DOT:
		reasons.append("root tipped during push")
	return {"fitness": fitness, "credible": credible,
		"class": "pushed_object" if credible else "push_failed",
		"reasons": reasons, "progress": obj_forward}
