extends SceneTree

## M60 — authored-mesh colliders default. CreatureBody.build honors a per-creature `authored_colliders`
## tag (set by the editor's .glb import) so imported meshes drive collision WITHOUT a manual
## BuildParams toggle. Mirrors test_blender_import's hull check, but builds with params=null and the
## tag as the only trigger.

const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")
const PartMeshProviderScript := preload("res://scripts/creature/part_mesh_provider.gd")
const SimWorldScript := preload("res://scripts/sim/sim_world.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _run() -> void:
	print("=== M60 authored-colliders-default tests ===")
	var glb := _write_test_glb()
	PartMeshProviderScript.register_authored(&"imported_body", glb)
	# Tagged creature, built with NO params -> the tag alone must turn authored colliders on.
	var tagged := _two_part_creature(true)
	var hulls_tagged := await _build_and_count_hulls(tagged)
	_check(hulls_tagged >= 1, "root authored_colliders tag drives a convex hull collider (params=null)")
	# Control: the same creature WITHOUT the tag falls back to primitive colliders.
	var plain := _two_part_creature(false)
	var hulls_plain := await _build_and_count_hulls(plain)
	_check(hulls_plain == 0, "untagged creature keeps primitive colliders (no authored hull)")
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	if FileAccess.file_exists(glb):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(glb))
	quit(0 if _failed == 0 else 1)


func _build_and_count_hulls(gene: PartGene) -> int:
	var world := Node3D.new()
	root.add_child(world)
	SimWorldScript.add_floor(world, 1.0)
	var body: Node3D = CreatureBodyScript.build(gene, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0)))
	world.add_child(body)
	var hull_count := 0
	for rb in body.call("part_bodies"):
		for c in rb.get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape is ConvexPolygonShape3D:
				hull_count += 1
	await physics_frame
	world.queue_free()
	await physics_frame
	return hull_count


func _two_part_creature(tagged: bool) -> PartGene:
	var rootg := PartGene.new()
	var rd := PartDefinition.new()
	rd.part_type = &"box"
	rd.density = 800.0
	rd.extents = Vector3(0.3, 0.2, 0.4)
	rootg.definition = rd
	rootg.part_id = &"imported_body"
	var rtags: Array[StringName] = [&"spine"]
	if tagged:
		rtags.append(&"authored_colliders")
	rootg.tags = rtags
	var child := PartGene.new()
	var cd := PartDefinition.new()
	cd.part_type = &"box"
	cd.density = 800.0
	cd.extents = Vector3(0.1, 0.2, 0.1)
	child.definition = cd
	child.part_id = &"leg"
	child.tags = [&"locomotor"]
	var s := SocketDef.new()
	s.id = &"hip"
	s.parent_attachment = Transform3D(Basis.IDENTITY, Vector3(0.0, -0.2, 0.0))
	s.child_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, -0.2, 0.0))
	child.socket = s
	child.socket_id = &"hip"
	rootg.children.append(child)
	return rootg


func _write_test_glb() -> String:
	var path := "user://_test_collider_default.glb"
	var scene := Node3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.4, 0.6)
	mi.mesh = box
	scene.add_child(mi)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(scene, state)
	if err == OK:
		err = doc.write_to_filesystem(state, path)
	scene.queue_free()
	return path
