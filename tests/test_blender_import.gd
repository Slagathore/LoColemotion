extends SceneTree

## M45 — Blender import follow-through. Closes both standing gaps: (1) a REAL .glb is written and
## re-imported at runtime (not a manifest pointing at nonexistent files), and (2) the imported mesh
## DRIVES collision/physics via a convex hull — not just display. The creature using it produces a
## non-degenerate rollout.

const PartMeshProviderScript := preload("res://scripts/creature/part_mesh_provider.gd")
const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")
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
	print("=== M45 Blender import follow-through tests ===")
	var glb := _write_test_glb()
	_test_glb_imports(glb)
	await _test_collider_drives_physics(glb)
	PartMeshProviderScript.clear_authored()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


# Write a real binary .glb from a procedural mesh (stands in for a Blender export).
func _write_test_glb() -> String:
	var path := "user://_test_part.glb"
	var scene := Node3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.3, 0.5)
	mi.mesh = box
	scene.add_child(mi)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(scene, state)
	if err == OK:
		err = doc.write_to_filesystem(state, path)
	scene.queue_free()
	_check(err == OK and FileAccess.file_exists(path), "a real .glb is written to disk")
	return path


func _test_glb_imports(glb: String) -> void:
	print("- a real .glb imports at runtime and yields a mesh + convex collider")
	var mesh := PartMeshProviderScript.mesh_from_gltf(glb)
	_check(mesh != null, "the .glb re-imports into a Mesh at runtime")
	var shape := PartMeshProviderScript.collider_for_mesh(mesh, Vector3.ONE)
	_check(shape is ConvexPolygonShape3D, "the imported mesh becomes a convex collider")
	_check(shape is ConvexPolygonShape3D and (shape as ConvexPolygonShape3D).points.size() >= 4,
			"the convex collider has real geometry (not degenerate)")


func _test_collider_drives_physics(glb: String) -> void:
	print("- a creature built with the imported collider runs a non-degenerate sim")
	PartMeshProviderScript.register_authored(&"imported_body", glb)
	var gene := _two_part_creature()
	var bp := CreatureBodyScript.BuildParams.new()
	bp.use_authored_colliders = true
	var world := Node3D.new()
	root.add_child(world)
	SimWorldScript.add_floor(world, 1.0)
	var body: Node3D = CreatureBodyScript.build(gene, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0)), bp)
	world.add_child(body)
	# The mesh-derived collider drives physics for the registered part.
	var bodies: Array = body.call("part_bodies")
	var hull_count := 0
	for rb in bodies:
		for c in rb.get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape is ConvexPolygonShape3D:
				hull_count += 1
	_check(hull_count >= 1, "the imported mesh's convex hull is the part's collision shape")
	for _i in 40:
		await physics_frame
	var m: Dictionary = body.call("measure")
	_check(bool(m["finite"]), "the rollout stays finite (collider drives physics, no explosion)")
	_check(int(m["part_count"]) == 2, "both parts persist through the sim")
	world.queue_free()
	await physics_frame


func _two_part_creature() -> PartGene:
	var root_gene := _gene(&"box", Vector3(0.4, 0.3, 0.5), 800.0, [&"spine"], &"imported_body")
	var foot := _gene(&"box", Vector3(0.2, 0.05, 0.2), 700.0, [&"ground_contact", &"foot"], &"imported_foot")
	foot.socket = _socket(Vector3(0.0, -0.3, 0.0))
	root_gene.children.append(foot)
	return root_gene


func _gene(part_type: StringName, extents: Vector3, density: float,
		tags: Array, part_id: StringName) -> PartGene:
	var g := PartGene.new()
	var d := PartDefinition.new()
	d.part_type = part_type
	d.density = density
	d.extents = extents
	g.definition = d
	var typed: Array[StringName] = []
	for t in tags:
		typed.append(t)
	g.tags = typed
	g.part_id = part_id
	return g


func _socket(pos: Vector3) -> SocketDef:
	var s := SocketDef.new()
	s.id = &"sock"
	s.parent_attachment = Transform3D(Basis.IDENTITY, pos)
	s.child_anchor = Transform3D.IDENTITY
	s.hinge_axis = Vector3.ZERO
	return s
