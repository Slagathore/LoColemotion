class_name BlockController
extends Node

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const LimbIKScript := preload("res://scripts/sim/limb_ik.gd")

## M43-2 active defense. Sibling to StrikeController. Orients an &"armor"/&"weapon" limb between
## the predicted incoming strike (a threat node) and the vital it protects, by publishing joint
## overlays only (no force writes). Dodge falls out of locomotion (a credible lateral burst);
## parry is a timed block. In an adversarial bout (M46) fitness = damage_dealt - damage_taken, so
## the block is LEARNED, not scripted — here we ship the controller + selection/interposition.

class Params:
	var overlay_weight := 1.0
	var overlay_ttl_ticks := 3
	var interpose := 0.6      # fraction along vital->threat to place the blocker (0=vital,1=threat)


var _body: Node3D
var _root_gene: PartGene
var _threat: Node3D
var _params := Params.new()
var _blocker: RigidBody3D
var _blocker_index := -1
var _vital_index := -1
var _controller: Node
var _last_intent_count := 0


func bind(body: Node3D, root_gene: PartGene, threat: Node3D, params: Params = null) -> void:
	_body = body
	_root_gene = root_gene
	_threat = threat
	_params = params if params != null else Params.new()
	_blocker = null
	_blocker_index = -1
	_vital_index = -1
	_controller = null
	_last_intent_count = 0
	_select_blocker_and_vital()


func tick(_delta: float) -> void:
	if _blocker == null or _threat == null:
		return
	if _controller == null:
		_controller = _find_controller()
	if _controller == null or not _controller.has_method("set_joint_target_overlay"):
		return
	var bodies: Array = _body.call("part_bodies")
	var vital_pos := _blocker.global_position
	if _vital_index >= 0 and _vital_index < bodies.size():
		vital_pos = (bodies[_vital_index] as RigidBody3D).global_position
	# Interpose the blocker on the line from the protected vital toward the threat.
	var guard_point := vital_pos.lerp(_threat.global_position, clampf(_params.interpose, 0.0, 1.0))
	_last_intent_count = 0
	var intents: Array = LimbIKScript.joint_targets(_body, _root_gene, _blocker_index, guard_point)
	for intent in intents:
		_controller.call("set_joint_target_overlay", intent.part_index, intent.target_angle,
				_params.overlay_weight * intent.weight, _params.overlay_ttl_ticks, &"block_intent")
		_last_intent_count += 1


func blocker_index() -> int:
	return _blocker_index


func vital_index() -> int:
	return _vital_index


func last_intent_count() -> int:
	return _last_intent_count


func _select_blocker_and_vital() -> void:
	if _body == null or _root_gene == null or not _body.has_method("part_bodies"):
		return
	var bodies: Array = _body.call("part_bodies")
	var parts: Array = CE.fold_graph(_root_gene, Transform3D.IDENTITY)["parts"]
	var driven := {}
	if _body.has_method("drive_joints"):
		for d in _body.call("drive_joints"):
			driven[int(d.get("part_index", -1))] = true
	var best_idx := -1
	var best_score := -INF
	for p in parts:
		var idx := int(p.index)
		if idx < 0 or idx >= bodies.size():
			continue
		if not _is_blocker(p) or not _chain_has_drive(parts, idx, driven):
			continue
		var score := float(p.depth)
		if p.tags.has(&"armor") or p.tags.has(&"shell"):
			score += 50.0          # a shield beats a weapon for blocking
		if score > best_score:
			best_score = score
			best_idx = idx
	_blocker_index = best_idx
	if best_idx >= 0:
		_blocker = bodies[best_idx] as RigidBody3D
	for p in parts:
		if p.tags.has(&"heart") or p.tags.has(&"brain") or p.tags.has(&"lung"):
			if int(p.index) >= 0 and int(p.index) < bodies.size():
				_vital_index = int(p.index)
				break


func _is_blocker(p) -> bool:
	return p.tags.has(&"armor") or p.tags.has(&"shell") or p.weapon != null \
			or p.tags.has(&"attack") or p.tags.has(&"blade") or p.tags.has(&"claw")


func _chain_has_drive(parts: Array, idx: int, driven: Dictionary) -> bool:
	var cur := idx
	var guard := 0
	while cur >= 0 and cur < parts.size() and guard < parts.size():
		if driven.has(cur):
			return true
		cur = int(parts[cur].parent)
		guard += 1
	return false


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
