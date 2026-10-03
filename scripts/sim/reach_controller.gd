class_name ReachController
extends Node

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const LimbIKScript := preload("res://scripts/sim/limb_ik.gd")

## Separate limb-intent layer for deliberate reaching. This intentionally does
## not mutate CPG gait math; it selects a manipulator end body and publishes
## joint target overlays that the CPG's normal torque drive must realize.

class Params:
	var hold_radius := 0.35
	var overlay_weight := 1.0
	var overlay_ttl_ticks := 4
	var allow_forelimb_reach := true


var _body: Node3D
var _root_gene: PartGene
var _target: Node3D
var _params := Params.new()
var _effector: RigidBody3D
var _effector_index := -1
var _controller: Node
var _last_distance := INF
var _active := false
var _last_intent_count := 0


func bind(body: Node3D, root_gene: PartGene, target: Node3D, params: Params = null) -> void:
	_body = body
	_root_gene = root_gene
	_target = target
	_params = params if params != null else Params.new()
	_effector = null
	_effector_index = -1
	_controller = null
	_last_distance = INF
	_active = false
	_last_intent_count = 0
	_select_effector()


func tick(delta: float) -> void:
	if _effector == null or _target == null:
		return
	if _controller == null:
		_controller = _find_controller()
	var to_target := _target.global_position - _effector.global_position
	_last_distance = to_target.length()
	if _last_distance <= _params.hold_radius:
		_active = false
		if _controller != null and _controller.has_method("clear_joint_target_overlay"):
			_controller.call("clear_joint_target_overlay")
		return
	_active = true
	_last_intent_count = 0
	if _controller == null or not _controller.has_method("set_joint_target_overlay"):
		return
	var intents: Array = LimbIKScript.joint_targets(_body, _root_gene, _effector_index,
			_target.global_position)
	for intent in intents:
		_controller.call("set_joint_target_overlay", intent.part_index, intent.target_angle,
				_params.overlay_weight * intent.weight, _params.overlay_ttl_ticks, &"reach_ik")
		_last_intent_count += 1


func effector_index() -> int:
	return _effector_index


func last_distance() -> float:
	return _last_distance


func active() -> bool:
	return _active


func last_intent_count() -> int:
	return _last_intent_count


func reached() -> bool:
	return _last_distance <= _params.hold_radius


func _select_effector() -> void:
	if _body == null or _root_gene == null or not _body.has_method("part_bodies"):
		return
	var bodies: Array = _body.call("part_bodies")
	var parts: Array = CE.fold_graph(_root_gene, Transform3D.IDENTITY)["parts"]
	var best_idx := -1
	for p in parts:
		var idx := int(p.index)
		if idx < 0 or idx >= bodies.size():
			continue
		if _is_reach_effector(p):
			best_idx = idx
			if p.tags.has(&"hand"):
				break
	if best_idx < 0:
		return
	_effector = bodies[best_idx] as RigidBody3D
	_effector_index = best_idx


func _is_reach_effector(p) -> bool:
	if p.tags.has(&"hand") or p.tags.has(&"manipulator"):
		return true
	if not _params.allow_forelimb_reach:
		return false
	return p.tags.has(&"forelimb") or p.tags.has(&"claw")


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
