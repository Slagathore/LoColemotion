class_name LocomotionViewer
extends Node3D

const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const SimWorldScript := preload("res://scripts/sim/sim_world.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")

const SETTLE_FRAMES := 90

var _body: Node3D
var _controller: Node
var _forward_arrow: MeshInstance3D
var _t := 0.0
var _settle_left := 0


func _ready() -> void:
	var floor_body := SimWorldScript.add_floor(self, 1.0)
	_add_floor_mesh(floor_body)
	_forward_arrow = _make_forward_arrow()
	add_child(_forward_arrow)


func load_creature(root_gene: PartGene, build_params: CreatureBodyScript.BuildParams = null,
		controller_params: CpgControllerScript.Params = null) -> void:
	if _body != null:
		_body.queue_free()
	if _controller != null:
		_controller.queue_free()
	# Spawn at the SAME height SimRollout uses (single source of truth) so the editor's live "Watch it
	# walk" reproduces the measured rollout exactly: limp/dropped creatures get the clearance drop, honest
	# leg walkers spawn standing on their feet (a 0.4 m drop slams a tall-legged walker into a collapsed
	# pitched pose it can't recover from — the quad would look broken here while walking fine headless).
	var spawn_y: float = SimRolloutScript.spawn_y(root_gene)
	_body = CreatureBodyScript.build(root_gene, Transform3D(Basis.IDENTITY, Vector3(0.0, spawn_y, 0.0)),
			build_params)
	add_child(_body)
	_add_part_meshes(_body)
	_controller = CpgControllerScript.new()
	_controller.call("bind", _body, root_gene, controller_params)
	add_child(_controller)
	_t = 0.0
	_settle_left = SETTLE_FRAMES   # let it drop and stabilize before driving (matches SimRollout)
	_update_forward_arrow()


func forward_arrow() -> MeshInstance3D:
	return _forward_arrow


func body() -> Node3D:
	return _body


# M58: expose the live controller so the editor's force x-ray / sonification can read
# force_xray() / last_commands() / assist metrics during the sim (display-only, Principle 22).
func controller() -> Node:
	return _controller


func controller_energy() -> float:
	return 0.0 if _controller == null else float(_controller.call("total_energy"))


func _physics_process(delta: float) -> void:
	if _controller == null:
		return
	if _settle_left > 0:
		_settle_left -= 1   # drop/stabilize without driving, so it doesn't tumble into a jam
		# M60: a reference-tracking legged walker must HOLD its stance while settling (an animal doesn't
		# go limp when set down) — else its unbraced legs fold to belly before the walk starts. Matches
		# the settle-stand in SimRollout so the editor's live "Watch it walk" shows the same locomotion.
		if _controller.has_method("wants_settle_tick") and bool(_controller.call("wants_settle_tick")):
			_controller.call("settle_tick", delta)
		_update_forward_arrow()
		return
	_t += delta
	_controller.call("tick", _t, delta)
	_update_forward_arrow()


func _update_forward_arrow() -> void:
	if _forward_arrow == null or _body == null:
		return
	var bodies: Array = _body.call("part_bodies")
	if bodies.is_empty():
		return
	var rb := bodies[0] as RigidBody3D
	if rb == null:
		return
	var heading := rb.global_basis * Vector3.FORWARD
	heading.y = 0.0
	if heading.length() < 0.001:
		heading = Vector3.FORWARD
	_forward_arrow.global_position = rb.global_position + Vector3.UP * 0.8
	_forward_arrow.look_at(_forward_arrow.global_position + heading.normalized(), Vector3.UP)


func _add_part_meshes(body_node: Node3D) -> void:
	if body_node == null or not body_node.has_method("part_bodies"):
		return
	var bodies: Array = body_node.call("part_bodies")
	var parts: Array = body_node.call("parts")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.47, 0.74)
	mat.roughness = 0.75
	for i in bodies.size():
		var rb := bodies[i] as RigidBody3D
		if rb == null or i >= parts.size():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = PartMeshProvider.mesh_for(parts[i].definition.part_type, parts[i].dims)
		mi.material_override = mat
		rb.add_child(mi)


func _add_floor_mesh(floor_body: StaticBody3D) -> void:
	if floor_body == null:
		return
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(30.0, 0.2, 30.0)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.17, 0.20)
	mi.material_override = mat
	floor_body.add_child(mi)


func _make_forward_arrow() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "CanonicalForwardArrow"
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_add_vertex(Vector3(0.0, 0.0, -1.5))
	mesh.surface_add_vertex(Vector3(0.0, 0.0, -1.5))
	mesh.surface_add_vertex(Vector3(0.25, 0.0, -1.15))
	mesh.surface_add_vertex(Vector3(0.0, 0.0, -1.5))
	mesh.surface_add_vertex(Vector3(-0.25, 0.0, -1.15))
	mesh.surface_end()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.9, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.8, 0.25)
	mi.material_override = mat
	return mi
