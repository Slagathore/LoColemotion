class_name PartMeshProvider
extends RefCounted

## Maps a part_type + full scaled dims (ResolvedPart.dims) to a display Mesh.
##
## Visual approximation only — the evaluator computes volume / surface-area from
## `dims` itself, so the mesh need not be volumetrically exact, just representative.
## This is the Tier-1 primitive fallback: it unblocks "see the creature" with zero
## Blender dependency, and is the clean seam the Geometry-Nodes pipeline replaces later.

static var _authored: Dictionary = {}


static func register_authored(part_id: StringName, path: String) -> void:
	_authored[part_id] = path


static func authored_path(part_id: StringName) -> String:
	return String(_authored.get(part_id, ""))


static func has_authored(part_id: StringName) -> bool:
	return _authored.has(part_id)


static func clear_authored() -> void:
	_authored.clear()


static func mesh_for_part(gene: PartGene, dims: Vector3) -> Mesh:
	if gene != null and _authored.has(gene.part_id):
		var mesh := _load_authored_mesh(String(_authored[gene.part_id]))
		if mesh != null:
			return mesh
	var part_type := &"box" if gene == null or gene.definition == null else gene.definition.part_type
	return mesh_for(part_type, dims)


# M45: look up an authored mesh by part_id directly (CreatureBody works from ResolvedParts, which
# carry part_id but not the gene). Returns null if none registered.
static func mesh_for_part_id(part_id: StringName, _dims: Vector3) -> Mesh:
	if not _authored.has(part_id):
		return null
	return _load_authored_mesh(String(_authored[part_id]))


static func mesh_for(part_type: StringName, dims: Vector3) -> Mesh:
	match part_type:
		&"box":
			var b := BoxMesh.new()
			b.size = dims
			return b
		&"sphere":
			var s := SphereMesh.new()
			s.radius = maxf(dims.x, dims.z) * 0.5
			s.height = dims.y
			return s
		&"cylinder":
			var c := CylinderMesh.new()
			var r := maxf(dims.x, dims.z) * 0.5
			c.top_radius = r
			c.bottom_radius = r
			c.height = dims.y
			return c
		&"capsule":
			var cap := CapsuleMesh.new()
			cap.radius = maxf(dims.x, dims.z) * 0.5
			cap.height = maxf(dims.y, cap.radius * 2.0)   # Godot capsule height INCLUDES the caps
			return cap
		_:
			var fb := BoxMesh.new()
			fb.size = dims
			return fb


static func _load_authored_mesh(path: String) -> Mesh:
	# M45: a raw .glb/.gltf can be imported at RUNTIME via GLTFDocument (no editor .import step),
	# so the pipeline works for assets that aren't part of the project import database.
	if path.to_lower().ends_with(".glb") or path.to_lower().ends_with(".gltf"):
		var gmesh := mesh_from_gltf(path)
		if gmesh != null:
			return gmesh
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res is Mesh:
		return res
	if res is PackedScene:
		var inst := (res as PackedScene).instantiate()
		var mesh := _find_mesh(inst)
		inst.queue_free()
		return mesh
	return null


# M45: load a real .glb/.gltf at runtime and return its first mesh (or null).
static func mesh_from_gltf(path: String) -> Mesh:
	var scene := load_gltf_scene(path)
	if scene == null:
		return null
	var mesh := _find_mesh(scene)
	scene.queue_free()
	return mesh


static func load_gltf_scene(path: String) -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state)


# M45: mesh -> physics collider. A convex hull of the authored mesh DRIVES collision (not just
# display), closing the "meshes are display-only" gap. Falls back to the part's primitive box
# if the hull is degenerate, so a bad mesh can never produce a no-collision part.
static func collider_for_mesh(mesh: Mesh, fallback_dims := Vector3.ONE) -> Shape3D:
	if mesh != null:
		var shape := mesh.create_convex_shape(true, true)
		if shape is ConvexPolygonShape3D and (shape as ConvexPolygonShape3D).points.size() >= 4:
			return shape
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(fallback_dims.x, 0.001), maxf(fallback_dims.y, 0.001),
			maxf(fallback_dims.z, 0.001))
	return box


static func _find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and node.mesh != null:
		return node.mesh
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null
