class_name SkinBuilder
extends RefCounted

## Display-only creature sleeve. This mirrors current part bodies with meshes but
## creates no physics bodies, no collision shapes, and no score-affecting state.
## build_display_skin() snapshots the pose; update_display_skin() re-syncs each skin
## mesh to its live body every frame so the sleeve animates with the sim.

const SKIN_INFLATE := 1.1   # sleeve slightly larger than the collision part, so it reads as skin
const SDFMesherScript := preload("res://scripts/creature/sdf_mesher.gd")
static var _mesh_cache := {}


class Config:
	extends Resource
	var smooth_boxes := true
	var radial_segments := 24
	var rings := 12
	var organic_bridges := false
	var cache_meshes := true
	var lod_distance := 0.0


# M58 (B7): tint a display skin from a CreatureCard palette {base, secondary, pattern}. Display-only
# (Principle 22): touches only skin-mesh materials, never physics or scoring. Alternates base /
# secondary across parts so a two-tone palette reads; unknown/empty palette is a no-op.
static func apply_palette(skin: Node3D, palette: Dictionary) -> void:
	if skin == null or palette == null or palette.is_empty():
		return
	var base := _palette_color(palette.get("base", "#9c78bd"), Color(0.62, 0.47, 0.74))
	var secondary := _palette_color(palette.get("secondary", base), base)
	var metallic := 0.0
	var rough := 0.7
	if String(palette.get("pattern", "")) == "glossy":
		rough = 0.25
	var i := 0
	for child in skin.get_children():
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = base if (i % 2 == 0) else secondary
		mat.roughness = rough
		mat.metallic = metallic
		mi.material_override = mat
		i += 1


static func _palette_color(v, fallback: Color) -> Color:
	if v is Color:
		return v
	if v is String and String(v) != "":
		return Color.from_string(String(v), fallback)
	return fallback


static func build_display_skin(body: Node3D, cfg: Config = null) -> Node3D:
	var c := cfg if cfg != null else Config.new()
	_apply_lod(c)
	var skin := Node3D.new()
	skin.name = "DisplaySkin"
	skin.set_meta("display_only", true)
	skin.set_meta("smoothed", c.smooth_boxes)
	skin.set_meta("organic_bridges", c.organic_bridges)
	skin.set_meta("radial_segments", c.radial_segments)
	if body == null or not body.has_method("part_bodies"):
		return skin
	var parts: Array = body.call("parts") if body.has_method("parts") else []
	var bodies: Array = body.call("part_bodies")
	for i in bodies.size():
		var rb := bodies[i] as RigidBody3D
		if rb == null:
			continue
		var dims := Vector3.ONE * 0.2
		var part_type := &"box"
		if i < parts.size():
			dims = parts[i].dims
			part_type = parts[i].definition.part_type
		var mi := MeshInstance3D.new()
		mi.name = "Skin_%02d" % i
		var mesh_data := _mesh_for(part_type, dims * SKIN_INFLATE, c)
		mi.mesh = mesh_data["mesh"]
		mi.transform = rb.transform
		mi.scale = mesh_data["scale"]
		mi.set_meta("source_part_index", i)
		mi.set_meta("skin_local_scale", mesh_data["scale"])
		skin.add_child(mi)
	if c.organic_bridges:
		_add_connective_bridges(skin, parts, bodies, c)
	return skin


static func build_smoothed_skin(body: Node3D) -> Node3D:
	var cfg := Config.new()
	cfg.smooth_boxes = true
	return build_display_skin(body, cfg)


static func build_baked_organic_skin(body: Node3D, lod_distance := 0.0) -> Node3D:
	if lod_distance <= 12.0:
		return build_continuous_skin(body)
	var cfg := Config.new()
	cfg.smooth_boxes = true
	cfg.organic_bridges = true
	cfg.cache_meshes = true
	cfg.lod_distance = lod_distance
	var skin := build_display_skin(body, cfg)
	skin.name = "BakedOrganicSkin"
	skin.set_meta("continuous_approximation", true)
	return skin


static func build_continuous_skin(body: Node3D) -> Node3D:
	var skin := Node3D.new()
	skin.name = "ContinuousSkin"
	skin.set_meta("display_only", true)
	skin.set_meta("continuous_surface", true)
	skin.set_meta("static_preview_only", true)
	skin.set_meta("animated_fallback", "display_sleeve")
	if body == null or not body.has_method("parts"):
		return skin
	var parts: Array = body.call("parts")
	var mi := MeshInstance3D.new()
	mi.name = "SDFSurface"
	mi.mesh = SDFMesherScript.mesh_for_parts(parts)
	mi.set_meta("sdf_surface", true)
	skin.add_child(mi)
	return skin


static func build_lod_skin(body: Node3D, distance: float) -> Node3D:
	if distance <= 12.0:
		return build_continuous_skin(body)
	var cfg := Config.new()
	cfg.lod_distance = distance
	cfg.organic_bridges = distance < 18.0
	return build_display_skin(body, cfg)


# Re-sync each skin mesh to its source body's live world transform. Call per frame
# while the sim runs so the sleeve deforms with the creature. Cheap: no remeshing.
static func update_display_skin(skin: Node3D, body: Node3D) -> void:
	if skin == null or body == null or not body.has_method("part_bodies"):
		return
	var bodies: Array = body.call("part_bodies")
	for child in skin.get_children():
		if child is MeshInstance3D and child.has_meta("source_child_index"):
			_update_bridge(child as MeshInstance3D, bodies)
		elif child is MeshInstance3D and child.has_meta("source_part_index"):
			var idx := int(child.get_meta("source_part_index"))
			if idx >= 0 and idx < bodies.size() and bodies[idx] != null:
				var scale: Vector3 = child.get_meta("skin_local_scale", Vector3.ONE)
				(child as MeshInstance3D).global_transform = (bodies[idx] as RigidBody3D).global_transform.scaled_local(scale)


static func _mesh_for(part_type: StringName, dims: Vector3, cfg: Config) -> Dictionary:
	var key := "%s|%s|seg=%d|rings=%d|smooth=%s" % [
		String(part_type),
		str(dims.snapped(Vector3.ONE * 0.001)),
		cfg.radial_segments,
		cfg.rings,
		str(cfg.smooth_boxes),
	]
	if cfg.cache_meshes and _mesh_cache.has(key):
		return {"mesh": _mesh_cache[key], "scale": _scale_for(part_type, dims, cfg)}
	var mesh: Mesh
	var scale := Vector3.ONE
	match part_type:
		&"sphere":
			var s := SphereMesh.new()
			s.radius = maxf(maxf(dims.x, maxf(dims.y, dims.z)) * 0.5, 0.001)
			s.height = s.radius * 2.0
			s.radial_segments = maxi(cfg.radial_segments, 8)
			s.rings = maxi(cfg.rings, 4)
			mesh = s
		&"capsule":
			var c := CapsuleMesh.new()
			c.radius = maxf((dims.x + dims.z) * 0.25, 0.001)
			c.height = maxf(dims.y, c.radius * 2.0)
			c.radial_segments = maxi(cfg.radial_segments, 8)
			c.rings = maxi(cfg.rings, 4)
			mesh = c
		&"cylinder":
			var cy := CylinderMesh.new()
			cy.top_radius = maxf((dims.x + dims.z) * 0.25, 0.001)
			cy.bottom_radius = cy.top_radius
			cy.height = maxf(dims.y, 0.001)
			cy.radial_segments = maxi(cfg.radial_segments, 8)
			mesh = cy
		_:
			if cfg.smooth_boxes:
				var s := SphereMesh.new()
				s.radius = 0.5
				s.height = 1.0
				s.radial_segments = maxi(cfg.radial_segments, 8)
				s.rings = maxi(cfg.rings, 4)
				mesh = s
				scale = Vector3(maxf(dims.x, 0.001), maxf(dims.y, 0.001), maxf(dims.z, 0.001))
			else:
				var b := BoxMesh.new()
				b.size = Vector3(maxf(dims.x, 0.001), maxf(dims.y, 0.001), maxf(dims.z, 0.001))
				mesh = b
	if cfg.cache_meshes:
		_mesh_cache[key] = mesh
	return {"mesh": mesh, "scale": scale}


static func _scale_for(part_type: StringName, dims: Vector3, cfg: Config) -> Vector3:
	if part_type == &"box" and cfg.smooth_boxes:
		return Vector3(maxf(dims.x, 0.001), maxf(dims.y, 0.001), maxf(dims.z, 0.001))
	return Vector3.ONE


static func _apply_lod(cfg: Config) -> void:
	if cfg.lod_distance <= 0.0:
		return
	if cfg.lod_distance > 26.0:
		cfg.radial_segments = mini(cfg.radial_segments, 8)
		cfg.rings = mini(cfg.rings, 4)
	elif cfg.lod_distance > 14.0:
		cfg.radial_segments = mini(cfg.radial_segments, 12)
		cfg.rings = mini(cfg.rings, 6)


static func _add_connective_bridges(skin: Node3D, parts: Array, bodies: Array, cfg: Config) -> void:
	for i in parts.size():
		var p = parts[i]
		var parent_idx := int(p.parent)
		if parent_idx < 0 or parent_idx >= bodies.size() or i >= bodies.size():
			continue
		var parent_body := bodies[parent_idx] as RigidBody3D
		var child_body := bodies[i] as RigidBody3D
		if parent_body == null or child_body == null:
			continue
		var bridge := MeshInstance3D.new()
		bridge.name = "SkinBridge_%02d_%02d" % [parent_idx, i]
		bridge.mesh = _bridge_mesh(cfg)
		bridge.set_meta("source_parent_index", parent_idx)
		bridge.set_meta("source_child_index", i)
		bridge.set_meta("skin_bridge", true)
		var radius := maxf(minf(p.dims.x, minf(p.dims.y, p.dims.z)) * 0.22, 0.025)
		bridge.set_meta("bridge_radius", radius)
		skin.add_child(bridge)
		_update_bridge(bridge, bodies)


static func _bridge_mesh(cfg: Config) -> Mesh:
	var key := "bridge|seg=%d" % maxi(cfg.radial_segments, 8)
	if cfg.cache_meshes and _mesh_cache.has(key):
		return _mesh_cache[key]
	var cy := CylinderMesh.new()
	cy.top_radius = 1.0
	cy.bottom_radius = 1.0
	cy.height = 1.0
	cy.radial_segments = maxi(cfg.radial_segments, 8)
	if cfg.cache_meshes:
		_mesh_cache[key] = cy
	return cy


static func _update_bridge(bridge: MeshInstance3D, bodies: Array) -> void:
	var parent_idx := int(bridge.get_meta("source_parent_index", -1))
	var child_idx := int(bridge.get_meta("source_child_index", -1))
	if parent_idx < 0 or child_idx < 0 or parent_idx >= bodies.size() or child_idx >= bodies.size():
		return
	var parent_body := bodies[parent_idx] as RigidBody3D
	var child_body := bodies[child_idx] as RigidBody3D
	if parent_body == null or child_body == null:
		return
	var start := parent_body.global_position
	var finish := child_body.global_position
	var delta := finish - start
	var length := maxf(delta.length(), 0.001)
	var y_axis := delta / length
	var x_axis := y_axis.cross(Vector3.FORWARD)
	if x_axis.length() < 0.001:
		x_axis = y_axis.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	var radius := float(bridge.get_meta("bridge_radius", 0.03))
	bridge.global_transform = Transform3D(
			Basis(x_axis * radius, y_axis * length, z_axis * radius),
			start + delta * 0.5)
