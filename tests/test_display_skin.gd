extends SceneTree

## M10: the display skin mirrors the part bodies and FOLLOWS them each frame, while
## never adding physics bodies/collision or affecting score.

const SkinBuilderScript := preload("res://scripts/sim/skin_builder.gd")
const SDFMesherScript := preload("res://scripts/creature/sdf_mesher.gd")
const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")

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
	print("=== Display skin (M10) tests ===")
	var world := Node3D.new()
	root.add_child(world)
	var gene := PartCatalog.make_quadruped(false)
	var body := CreatureBodyScript.build(gene, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, 0.0)))
	world.add_child(body)
	var bodies: Array = body.call("part_bodies")
	var skin := SkinBuilderScript.build_display_skin(body)
	world.add_child(skin)

	_check(skin.get_child_count() == bodies.size(), "one skin mesh per part body")
	_check(bool(skin.get_meta("smoothed", false)), "default display skin uses smoothing pass")
	var phys_nodes := 0
	for c in skin.get_children():
		if c is RigidBody3D or c is CollisionShape3D or c is PhysicsBody3D:
			phys_nodes += 1
	_check(phys_nodes == 0, "skin is display-only (no physics/collision nodes)")
	var mesh0_pre := skin.get_child(0) as MeshInstance3D
	_check(mesh0_pre.mesh is SphereMesh and mesh0_pre.get_meta("skin_local_scale", Vector3.ONE) != Vector3.ONE,
			"box body is finished as a smoothed ellipsoid sleeve")

	# Let the creature fall a frame, then sync the skin and confirm it tracks the body.
	for _i in 20:
		await physics_frame
	SkinBuilderScript.update_display_skin(skin, body)
	var rb := bodies[0] as RigidBody3D
	var mesh0 := skin.get_child(0) as MeshInstance3D
	_check(mesh0.global_position.distance_to(rb.global_position) < 0.01,
			"skin mesh follows its body after update (drift %.4f)" %
			mesh0.global_position.distance_to(rb.global_position))
	var organic := SkinBuilderScript.build_baked_organic_skin(body, 4.0)
	world.add_child(organic)
	_check(bool(organic.get_meta("continuous_surface", false)),
			"close baked organic skin is a continuous SDF surface")
	_check(bool(organic.get_meta("static_preview_only", false)),
			"continuous skin declares the static-preview animation mechanism")
	_check(organic.get_child_count() == 1 and organic.get_child(0) is MeshInstance3D,
			"continuous skin is one display mesh")
	_check(not _has_physics_nodes(organic), "continuous skin has no physics/collision nodes")
	var info := SDFMesherScript.last_build_info()
	_check(String(info.get("extractor", "")) == "marching_tetrahedra"
			and bool(info.get("scalar_field", false))
			and bool(info.get("interpolated_iso_edges", false)),
			"continuous skin samples scalar corners and interpolates iso-crossings")
	_check(bool(info.get("indexed", false)) and bool(info.get("welded", false))
			and int(info.get("welded_vertices", 0)) < int(info.get("raw_vertices", 0))
			and int(info.get("index_count", 0)) >= 30,
			"continuous skin welds raw iso triangles into an indexed surface")
	_check(int(info.get("smooth_iterations", 0)) >= 1 and bool(info.get("material_regions", false))
			and int(info.get("region_count", 0)) >= 2,
			"continuous skin applies Taubin smoothing and material region colors")
	var faces := ((organic.get_child(0) as MeshInstance3D).mesh as Mesh).get_faces()
	_check(faces.size() >= 30 and faces.size() % 3 == 0,
			"continuous skin has a non-degenerate triangle surface")
	var mesh := ((organic.get_child(0) as MeshInstance3D).mesh as Mesh)
	var arrays := mesh.surface_get_arrays(0)
	_check(arrays[Mesh.ARRAY_INDEX] is PackedInt32Array
			and (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() == int(info.get("index_count", 0)),
			"continuous skin exposes an indexed ArrayMesh surface")
	_check(arrays[Mesh.ARRAY_COLOR] is PackedColorArray
			and (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() == int(info.get("welded_vertices", 0)),
			"continuous skin stores per-vertex material region colors")
	var cached_before := SDFMesherScript.cached_mesh_count()
	var organic_b := SkinBuilderScript.build_baked_organic_skin(body, 4.0)
	world.add_child(organic_b)
	var cached_after := SDFMesherScript.cached_mesh_count()
	_check(cached_after == cached_before and (organic.get_child(0) as MeshInstance3D).mesh == (organic_b.get_child(0) as MeshInstance3D).mesh,
			"continuous SDF skin reuses cached mesh")
	var mid_lod := SkinBuilderScript.build_baked_organic_skin(body, 20.0)
	world.add_child(mid_lod)
	var bridges := 0
	for child in mid_lod.get_children():
		if child.has_meta("skin_bridge"):
			bridges += 1
	_check(bool(mid_lod.get_meta("continuous_approximation", false)) and bridges > 0,
			"mid LOD keeps the animated sleeve and bridge fallback")
	var far_lod := SkinBuilderScript.build_lod_skin(body, 32.0)
	world.add_child(far_lod)
	_check(int(far_lod.get_meta("radial_segments", 99)) <= 8,
			"far LOD skin reduces mesh segment count")
	var cached_a := SkinBuilderScript.build_lod_skin(body, 32.0)
	var cached_b := SkinBuilderScript.build_lod_skin(body, 32.0)
	world.add_child(cached_a)
	world.add_child(cached_b)
	_check((cached_a.get_child(0) as MeshInstance3D).mesh == (cached_b.get_child(0) as MeshInstance3D).mesh,
			"LOD skin reuses cached primitive meshes")

	world.queue_free()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _has_physics_nodes(node: Node) -> bool:
	if node is PhysicsBody3D or node is CollisionShape3D:
		return true
	for child in node.get_children():
		if _has_physics_nodes(child):
			return true
	return false
