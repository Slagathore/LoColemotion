class_name StrikeController
extends Node

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const LimbIKScript := preload("res://scripts/sim/limb_ik.gd")

## M41 — strike intent. Sibling to ReachController. The crucial difference: reach drives an
## end-effector TO a position and holds (zero velocity at target); a strike drives the weapon
## TIP THROUGH a waypoint at MAXIMUM velocity at the predicted contact instant. Like reach, it
## only publishes joint-target overlays via CpgController's _overlay_target channel — no direct
## force or velocity writes — so it composes with the gait and can't cheat damage-without-contact.
## The contact impulse is then read by combat.resolve_contact; damage = 1/2 m v^2 of the tip.

class Params:
	var overlay_weight := 1.0
	var overlay_ttl_ticks := 3
	var follow_through := 1.6      # waypoint distance BEYOND the target (drive through, not to)
	var windup_ticks := 14        # pull the tip back first to build a swing
	var windup_distance := 0.7


var _body: Node3D
var _root_gene: PartGene
var _target: Node3D
var _params := Params.new()
var _effector: RigidBody3D
var _effector_index := -1
var _controller: Node
var _tick := 0
var _peak_tip_speed := 0.0
var _last_intent_count := 0


func bind(body: Node3D, root_gene: PartGene, target: Node3D, params: Params = null) -> void:
	_body = body
	_root_gene = root_gene
	_target = target
	_params = params if params != null else Params.new()
	_effector = null
	_effector_index = -1
	_controller = null
	_tick = 0
	_peak_tip_speed = 0.0
	_last_intent_count = 0
	_select_weapon_tip()


func tick(delta: float) -> void:
	if _effector == null or _target == null:
		return
	if _controller == null:
		_controller = _find_controller()
	_peak_tip_speed = maxf(_peak_tip_speed, _effector.linear_velocity.length())
	if _controller == null or not _controller.has_method("set_joint_target_overlay"):
		return
	var tip := _effector.global_position
	var dir := (_target.global_position - tip)
	if dir.length() < 0.001:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	# Windup pulls the tip back along the strike line; the strike then aims at a waypoint BEYOND
	# the target so the tip is still accelerating when it reaches the contact point.
	var waypoint: Vector3
	if _tick < _params.windup_ticks:
		waypoint = tip - dir * _params.windup_distance
	else:
		waypoint = _target.global_position + dir * _params.follow_through
	_last_intent_count = 0
	var intents: Array = LimbIKScript.joint_targets(_body, _root_gene, _effector_index, waypoint)
	for intent in intents:
		_controller.call("set_joint_target_overlay", intent.part_index, intent.target_angle,
				_params.overlay_weight * intent.weight, _params.overlay_ttl_ticks, &"strike_intent")
		_last_intent_count += 1
	_tick += 1


func effector_index() -> int:
	return _effector_index


func tip_speed() -> float:
	return 0.0 if _effector == null else _effector.linear_velocity.length()


func peak_tip_speed() -> float:
	return _peak_tip_speed


func last_intent_count() -> int:
	return _last_intent_count


# The kinetic energy the tip would deliver on contact: 1/2 m v^2 (combat.gd reads the real
# contact impulse; this is the analytic upper bound used for fitness wiring in M46).
func tip_kinetic_energy() -> float:
	if _effector == null:
		return 0.0
	return 0.5 * _effector.mass * _peak_tip_speed * _peak_tip_speed


func _select_weapon_tip() -> void:
	if _body == null or _root_gene == null or not _body.has_method("part_bodies"):
		return
	var bodies: Array = _body.call("part_bodies")
	var parts: Array = CE.fold_graph(_root_gene, Transform3D.IDENTITY)["parts"]
	var driven := {}
	if _body.has_method("drive_joints"):
		for d in _body.call("drive_joints"):
			driven[int(d.get("part_index", -1))] = true
	var root_pos := (bodies[0] as RigidBody3D).global_position if not bodies.is_empty() else Vector3.ZERO
	var best_idx := -1
	var best_score := -INF
	for p in parts:
		var idx := int(p.index)
		if idx < 0 or idx >= bodies.size():
			continue
		if not _is_weapon(p):
			continue
		# A weapon tip is only useful if it sits on an ACTUATABLE chain — a fixed spike welded
		# to the root cannot be swung. Require a driven joint somewhere between it and the root.
		if not _chain_has_drive(parts, idx, driven):
			continue
		var rb := bodies[idx] as RigidBody3D
		var score := float(p.depth)
		if p.weapon != null:
			score += 100.0
		if driven.has(idx):
			score += 50.0                              # the tip itself swings
		if p.tags.has(&"stinger") or p.tags.has(&"blade") or p.tags.has(&"claw"):
			score += 10.0
		if rb != null:
			score += rb.global_position.distance_to(root_pos) * 0.5   # prefer the far (tip) end
		if score > best_score:
			best_score = score
			best_idx = idx
	if best_idx < 0:
		return
	_effector = bodies[best_idx] as RigidBody3D
	_effector_index = best_idx


func _chain_has_drive(parts: Array, idx: int, driven: Dictionary) -> bool:
	var cur := idx
	var guard := 0
	while cur >= 0 and cur < parts.size() and guard < parts.size():
		if driven.has(cur):
			return true
		cur = int(parts[cur].parent)
		guard += 1
	return false


func _is_weapon(p) -> bool:
	if p.weapon != null:
		return true
	return p.tags.has(&"attack") or p.tags.has(&"blade") or p.tags.has(&"stinger") \
			or p.tags.has(&"claw") or p.tags.has(&"spike")


func _find_controller() -> Node:
	if _body == null:
		return null
	var parent := _body.get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is CpgController:
			return child
	return null
