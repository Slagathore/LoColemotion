class_name SDFMesher
extends RefCounted

## Static-pose SDF surface extractor for M23 continuous skin.
##
## This is intentionally display-only. It samples the union of analytic part SDFs as
## continuous scalar values at grid corners and extracts interpolated iso-crossings
## with marching tetrahedra. That is the important M29 upgrade over the old binary
## occupied-cell shell: vertices live on the SDF surface, not on voxel faces.

static var _mesh_cache := {}
static var _last_build_info := {}


class Config:
	extends Resource
	var cell_size := 0.18
	var inflate := 0.08
	var max_cells_per_axis := 28
	var smooth_normals := true
	var weld_epsilon := 0.0015
	var smooth_iterations := 2
	var taubin_lambda := 0.45
	var taubin_mu := -0.47
	var material_regions := true


static func mesh_for_parts(parts: Array, cfg: Config = null) -> Mesh:
	var c := cfg if cfg != null else Config.new()
	var key := signature(parts, c)
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh := _build_mesh(parts, c)
	_mesh_cache[key] = mesh
	return mesh


static func cached_mesh_count() -> int:
	return _mesh_cache.size()


static func last_build_info() -> Dictionary:
	return _last_build_info.duplicate(true)


static func signature(parts: Array, cfg: Config = null) -> String:
	var c := cfg if cfg != null else Config.new()
	var rows: Array[String] = ["cell=%.3f|inflate=%.3f|weld=%.5f|smooth=%d|mat=%s" % [
		c.cell_size, c.inflate, c.weld_epsilon, c.smooth_iterations, str(c.material_regions)
	]]
	for p in parts:
		rows.append("%s:%s:%s:%s" % [
			String(p.definition.part_type),
			str(p.dims.snapped(Vector3.ONE * 0.001)),
			str(p.xform.origin.snapped(Vector3.ONE * 0.001)),
			str(p.xform.basis.get_rotation_quaternion()),
		])
	return "|".join(rows)


static func _build_mesh(parts: Array, cfg: Config) -> ArrayMesh:
	if parts.is_empty():
		return ArrayMesh.new()
	var bounds := _bounds(parts, cfg.inflate)
	var cell := maxf(cfg.cell_size, maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) / float(cfg.max_cells_per_axis))
	var dims := Vector3i(
			maxi(1, ceili(bounds.size.x / cell)),
			maxi(1, ceili(bounds.size.y / cell)),
			maxi(1, ceili(bounds.size.z / cell)))
	var scalars := _sample_scalar_field(parts, cfg, bounds, cell, dims)
	var raw_vertices: Array[Vector3] = []
	var tri_count := 0
	for x in dims.x:
		for y in dims.y:
			for z in dims.z:
				tri_count += _polygonize_cell(raw_vertices, scalars, bounds.position, cell, dims, x, y, z)
	var built := _build_indexed_mesh(raw_vertices, parts, cfg)
	var mesh: ArrayMesh = built["mesh"]
	_last_build_info = {
		"extractor": "marching_tetrahedra",
		"scalar_field": true,
		"interpolated_iso_edges": true,
		"indexed": true,
		"welded": true,
		"triangles": tri_count,
		"raw_vertices": raw_vertices.size(),
		"welded_vertices": int(built["vertex_count"]),
		"index_count": int(built["index_count"]),
		"cell_size": cell,
		"dims": [dims.x, dims.y, dims.z],
		"weld_epsilon": cfg.weld_epsilon,
		"smooth_iterations": cfg.smooth_iterations,
		"taubin_lambda": cfg.taubin_lambda,
		"taubin_mu": cfg.taubin_mu,
		"material_regions": cfg.material_regions,
		"region_count": int(built["region_count"]),
	}
	return mesh if mesh != null else ArrayMesh.new()


static func _sample_scalar_field(parts: Array, cfg: Config, bounds: AABB,
		cell: float, dims: Vector3i) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize((dims.x + 1) * (dims.y + 1) * (dims.z + 1))
	for x in range(dims.x + 1):
		for y in range(dims.y + 1):
			for z in range(dims.z + 1):
				var p := bounds.position + Vector3(x, y, z) * cell
				values[_corner_index(x, y, z, dims)] = _sdf(parts, p, cfg.inflate)
	return values


static func _polygonize_cell(raw_vertices: Array[Vector3], scalars: PackedFloat32Array,
		origin: Vector3, cell: float, dims: Vector3i, x: int, y: int, z: int) -> int:
	var pos := [
		origin + Vector3(x, y, z) * cell,
		origin + Vector3(x + 1, y, z) * cell,
		origin + Vector3(x + 1, y + 1, z) * cell,
		origin + Vector3(x, y + 1, z) * cell,
		origin + Vector3(x, y, z + 1) * cell,
		origin + Vector3(x + 1, y, z + 1) * cell,
		origin + Vector3(x + 1, y + 1, z + 1) * cell,
		origin + Vector3(x, y + 1, z + 1) * cell,
	]
	var val := [
		scalars[_corner_index(x, y, z, dims)],
		scalars[_corner_index(x + 1, y, z, dims)],
		scalars[_corner_index(x + 1, y + 1, z, dims)],
		scalars[_corner_index(x, y + 1, z, dims)],
		scalars[_corner_index(x, y, z + 1, dims)],
		scalars[_corner_index(x + 1, y, z + 1, dims)],
		scalars[_corner_index(x + 1, y + 1, z + 1, dims)],
		scalars[_corner_index(x, y + 1, z + 1, dims)],
	]
	var tetra := [
		[0, 5, 1, 6],
		[0, 1, 2, 6],
		[0, 2, 3, 6],
		[0, 3, 7, 6],
		[0, 7, 4, 6],
		[0, 4, 5, 6],
	]
	var tris := 0
	for t in tetra:
		tris += _polygonize_tetra(raw_vertices, pos, val, t)
	return tris


static func _polygonize_tetra(raw_vertices: Array[Vector3], pos: Array, val: Array, ids: Array) -> int:
	var points: Array[Vector3] = []
	for edge in [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3]]:
		var ia: int = ids[int(edge[0])]
		var ib: int = ids[int(edge[1])]
		var va := float(val[ia])
		var vb := float(val[ib])
		if (va <= 0.0 and vb <= 0.0) or (va > 0.0 and vb > 0.0):
			continue
		points.append(_interp_iso(pos[ia], pos[ib], va, vb))
	if points.size() == 3:
		return _append_tri_auto(raw_vertices, points[0], points[1], points[2])
	if points.size() == 4:
		return _append_tri_auto(raw_vertices, points[0], points[1], points[2]) \
				+ _append_tri_auto(raw_vertices, points[0], points[2], points[3])
	return 0


static func _interp_iso(a: Vector3, b: Vector3, va: float, vb: float) -> Vector3:
	var denom := va - vb
	var t := 0.5 if absf(denom) < 0.000001 else clampf(va / denom, 0.0, 1.0)
	return a.lerp(b, t)


static func _append_tri_auto(raw_vertices: Array[Vector3], a: Vector3, b: Vector3, c: Vector3) -> int:
	var n := (b - a).cross(c - a)
	if n.length() < 0.000001:
		return 0
	raw_vertices.append(a)
	raw_vertices.append(b)
	raw_vertices.append(c)
	return 1


static func _build_indexed_mesh(raw_vertices: Array[Vector3], parts: Array, cfg: Config) -> Dictionary:
	var mesh := ArrayMesh.new()
	if raw_vertices.size() < 3:
		return {"mesh": mesh, "vertex_count": 0, "index_count": 0, "region_count": 0}
	var vertices: Array[Vector3] = []
	var indices := PackedInt32Array()
	var map := {}
	var eps := maxf(cfg.weld_epsilon, 0.000001)
	for v in raw_vertices:
		var key := _vertex_key(v, eps)
		var idx: int
		if map.has(key):
			idx = int(map[key])
		else:
			idx = vertices.size()
			map[key] = idx
			vertices.append(v)
		indices.append(idx)
	if cfg.smooth_iterations > 0 and vertices.size() > 3:
		vertices = _taubin_smooth(vertices, indices, cfg.smooth_iterations,
				cfg.taubin_lambda, cfg.taubin_mu)
	var normals := _vertex_normals(vertices, indices)
	var packed_vertices := PackedVector3Array()
	packed_vertices.resize(vertices.size())
	for i in vertices.size():
		packed_vertices[i] = vertices[i]
	var packed_normals := PackedVector3Array()
	packed_normals.resize(normals.size())
	for i in normals.size():
		packed_normals[i] = normals[i]
	var colors := PackedColorArray()
	var region_keys := {}
	if cfg.material_regions:
		colors.resize(vertices.size())
		for i in vertices.size():
			var region := _region_for(parts, vertices[i])
			region_keys[region] = true
			colors[i] = _region_color(region)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = packed_vertices
	arrays[Mesh.ARRAY_NORMAL] = packed_normals
	arrays[Mesh.ARRAY_INDEX] = indices
	if cfg.material_regions:
		arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {
		"mesh": mesh,
		"vertex_count": vertices.size(),
		"index_count": indices.size(),
		"region_count": region_keys.size(),
	}


static func _vertex_key(v: Vector3, eps: float) -> String:
	return "%d,%d,%d" % [
		int(round(v.x / eps)),
		int(round(v.y / eps)),
		int(round(v.z / eps)),
	]


static func _taubin_smooth(vertices: Array[Vector3], indices: PackedInt32Array,
		iterations: int, lambda: float, mu: float) -> Array[Vector3]:
	var adjacency := _adjacency(vertices.size(), indices)
	var out := vertices.duplicate()
	for _i in iterations:
		out = _laplacian_pass(out, adjacency, lambda)
		out = _laplacian_pass(out, adjacency, mu)
	return out


static func _adjacency(vertex_count: int, indices: PackedInt32Array) -> Array:
	var neighbors: Array = []
	neighbors.resize(vertex_count)
	for i in vertex_count:
		neighbors[i] = {}
	for i in range(0, indices.size(), 3):
		if i + 2 >= indices.size():
			break
		var a := int(indices[i])
		var b := int(indices[i + 1])
		var c := int(indices[i + 2])
		if a == b or b == c or c == a:
			continue
		neighbors[a][b] = true
		neighbors[a][c] = true
		neighbors[b][a] = true
		neighbors[b][c] = true
		neighbors[c][a] = true
		neighbors[c][b] = true
	return neighbors


static func _laplacian_pass(vertices: Array[Vector3], adjacency: Array, factor: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.resize(vertices.size())
	for i in vertices.size():
		var neighbors: Dictionary = adjacency[i]
		if neighbors.is_empty():
			out[i] = vertices[i]
			continue
		var avg := Vector3.ZERO
		for n in neighbors.keys():
			avg += vertices[int(n)]
		avg /= float(neighbors.size())
		out[i] = vertices[i] + (avg - vertices[i]) * factor
	return out


static func _vertex_normals(vertices: Array[Vector3], indices: PackedInt32Array) -> Array[Vector3]:
	var normals: Array[Vector3] = []
	normals.resize(vertices.size())
	for i in vertices.size():
		normals[i] = Vector3.ZERO
	for i in range(0, indices.size(), 3):
		if i + 2 >= indices.size():
			break
		var ia := int(indices[i])
		var ib := int(indices[i + 1])
		var ic := int(indices[i + 2])
		var n := (vertices[ib] - vertices[ia]).cross(vertices[ic] - vertices[ia])
		if n.length() <= 0.000001:
			continue
		n = n.normalized()
		normals[ia] += n
		normals[ib] += n
		normals[ic] += n
	for i in normals.size():
		normals[i] = normals[i].normalized() if normals[i].length() > 0.000001 else Vector3.UP
	return normals


static func _region_for(parts: Array, point: Vector3) -> StringName:
	var best := INF
	var best_region: StringName = &"skin"
	for p in parts:
		var d := absf(_part_sdf(p, point, 0.0))
		if d < best:
			best = d
			best_region = _region_from_tags(p.tags)
	return best_region


static func _region_from_tags(tags: Dictionary) -> StringName:
	if tags.has(&"stinger"):
		return &"stinger"
	if tags.has(&"blade"):
		return &"blade"
	if tags.has(&"attack") or tags.has(&"spike") or tags.has(&"claw"):
		return &"weapon"
	if tags.has(&"armor") or tags.has(&"shell") or tags.has(&"carapace"):
		return &"armor"
	if tags.has(&"muscle") or tags.has(&"spring"):
		return &"muscle"
	if tags.has(&"heart") or tags.has(&"brain") or tags.has(&"lung"):
		return &"organ"
	if tags.has(&"foot") or tags.has(&"ground_contact"):
		return &"pad"
	return &"skin"


static func _region_color(region: StringName) -> Color:
	match region:
		&"armor":
			return Color(0.48, 0.53, 0.55, 1.0)
		&"muscle":
			return Color(0.72, 0.22, 0.20, 1.0)
		&"organ":
			return Color(0.95, 0.28, 0.48, 1.0)
		&"blade":
			return Color(0.78, 0.82, 0.84, 1.0)
		&"stinger":
			return Color(0.28, 0.13, 0.20, 1.0)
		&"weapon":
			return Color(0.38, 0.34, 0.30, 1.0)
		&"pad":
			return Color(0.25, 0.32, 0.25, 1.0)
	return Color(0.38, 0.62, 0.45, 1.0)


static func _corner_index(x: int, y: int, z: int, dims: Vector3i) -> int:
	return x + (dims.x + 1) * (y + (dims.y + 1) * z)


static func _bounds(parts: Array, inflate: float) -> AABB:
	var b: AABB = parts[0].world_aabb.grow(inflate)
	for i in range(1, parts.size()):
		b = b.merge(parts[i].world_aabb.grow(inflate))
	return b.grow(inflate)


static func _sdf(parts: Array, point: Vector3, inflate: float) -> float:
	var best := INF
	for p in parts:
		best = minf(best, _part_sdf(p, point, inflate))
	return best


static func _part_sdf(p, point: Vector3, inflate: float) -> float:
	var local: Vector3 = p.xform.affine_inverse() * point
	var part_type: StringName = p.definition.part_type
	match part_type:
		&"sphere":
			return local.length() - maxf(maxf(p.dims.x, maxf(p.dims.y, p.dims.z)) * 0.5 + inflate, 0.001)
		&"capsule":
			return _capsule_sdf(local, p.dims, inflate)
		&"cylinder":
			return _cylinder_sdf(local, p.dims, inflate)
	return _box_sdf(local, p.dims, inflate)


static func _box_sdf(local: Vector3, dims: Vector3, inflate: float) -> float:
	var q := Vector3(absf(local.x), absf(local.y), absf(local.z)) - dims * 0.5 - Vector3.ONE * inflate
	var outside := Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length()
	var inside := minf(maxf(q.x, maxf(q.y, q.z)), 0.0)
	return outside + inside


static func _capsule_sdf(local: Vector3, dims: Vector3, inflate: float) -> float:
	var r := maxf((dims.x + dims.z) * 0.25 + inflate, 0.001)
	var half_segment := maxf(dims.y * 0.5 - r, 0.0)
	var q := Vector3(local.x, local.y - clampf(local.y, -half_segment, half_segment), local.z)
	return q.length() - r


static func _cylinder_sdf(local: Vector3, dims: Vector3, inflate: float) -> float:
	var r := maxf((dims.x + dims.z) * 0.25 + inflate, 0.001)
	var h := maxf(dims.y * 0.5 + inflate, 0.001)
	var d := Vector2(Vector2(local.x, local.z).length() - r, absf(local.y) - h)
	return minf(maxf(d.x, d.y), 0.0) + Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()


static func _add_face(st: SurfaceTool, origin: Vector3, cell: float, normal: Vector3) -> void:
	var corners := _face_corners(origin, cell, normal)
	_add_tri(st, corners[0], corners[1], corners[2], normal)
	_add_tri(st, corners[0], corners[2], corners[3], normal)


static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


static func _face_corners(o: Vector3, s: float, n: Vector3) -> Array[Vector3]:
	var x0 := o.x
	var y0 := o.y
	var z0 := o.z
	var x1 := o.x + s
	var y1 := o.y + s
	var z1 := o.z + s
	if n == Vector3.RIGHT:
		return [Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x1, y0, z1)]
	if n == Vector3.LEFT:
		return [Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(x0, y0, z0)]
	if n == Vector3.UP:
		return [Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0)]
	if n == Vector3.DOWN:
		return [Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1)]
	if n == Vector3.BACK:
		return [Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(x0, y0, z1)]
	return [Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y0, z0)]


static func _key(x: int, y: int, z: int) -> String:
	return "%d,%d,%d" % [x, y, z]


static func _unkey(k: String) -> Vector3i:
	var p := k.split(",")
	return Vector3i(int(p[0]), int(p[1]), int(p[2]))
