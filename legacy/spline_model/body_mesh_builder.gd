class_name BodyMeshBuilder
extends RefCounted

## Generates a swept-tube ("lofted") body mesh from a CreatureSpine.
##
## A ring of `ring_segments` vertices is swept along the spine's Curve3D, its
## radius varying per the spine's radius profile, with end caps. Frames are built
## with a propagated up-vector so the cross-section does not twist along bends.
## Returns an ArrayMesh ready to drop on a MeshInstance3D.
##
## This is the M1 body-skin technique. A metaball / marching-cubes variant for the
## gooier organic look is a later stretch goal (see docs/DESIGN.md).

static func build(spine: CreatureSpine, ring_segments: int = 16, length_samples: int = 48) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	if spine == null or spine.size() < 2:
		return st.commit()

	var curve := spine.to_curve()
	var total_len := curve.get_baked_length()
	if total_len <= 0.0:
		return st.commit()

	var rings := maxi(2, length_samples)
	var seg := maxi(3, ring_segments)
	var eps := total_len * 0.001

	# Per-ring frame: position, the two in-plane axes (right/up), and radius.
	var frame_pos: Array[Vector3] = []
	var frame_right: Array[Vector3] = []
	var frame_up: Array[Vector3] = []
	var frame_radius: Array[float] = []

	var prev_up := Vector3.UP
	for i in rings:
		var u := float(i) / float(rings - 1)        # 0..1 along the backbone
		var offset := u * total_len
		var pos := curve.sample_baked(offset)

		# Tangent via a small central difference along the curve.
		var ahead := curve.sample_baked(minf(offset + eps, total_len))
		var behind := curve.sample_baked(maxf(offset - eps, 0.0))
		var tangent := ahead - behind
		if tangent.length() < 1e-6:
			tangent = Vector3.FORWARD
		tangent = tangent.normalized()

		# Build an orthonormal frame, carrying `prev_up` forward to avoid twist.
		var right := tangent.cross(prev_up)
		if right.length() < 1e-4:
			right = tangent.cross(Vector3.RIGHT)
			if right.length() < 1e-4:
				right = tangent.cross(Vector3.FORWARD)
		right = right.normalized()
		var up := right.cross(tangent).normalized()
		prev_up = up

		frame_pos.append(pos)
		frame_right.append(right)
		frame_up.append(up)
		frame_radius.append(spine.radius_at(u))

	# Ring vertices (rings * seg of them).
	var verts: Array[Vector3] = []
	for i in rings:
		for j in seg:
			var ang := TAU * float(j) / float(seg)
			var dir := frame_right[i] * cos(ang) + frame_up[i] * sin(ang)
			verts.append(frame_pos[i] + dir * frame_radius[i])

	# Side quads, two triangles each, wound for outward-facing normals.
	for i in rings - 1:
		var v0 := float(i) / float(rings - 1)
		var v1 := float(i + 1) / float(rings - 1)
		for j in seg:
			var j2 := (j + 1) % seg
			var a := i * seg + j
			var b := i * seg + j2
			var c := (i + 1) * seg + j
			var d := (i + 1) * seg + j2
			var u0 := float(j) / float(seg)
			var u1 := float(j + 1) / float(seg)
			_tri(st, verts, a, c, b, Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v0))
			_tri(st, verts, b, c, d, Vector2(u1, v0), Vector2(u0, v1), Vector2(u1, v1))

	# End caps: simple triangle fans to each end-ring center.
	_cap(st, verts, frame_pos[0], 0, seg, true)
	_cap(st, verts, frame_pos[rings - 1], (rings - 1) * seg, seg, false)

	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, verts: Array, ia: int, ib: int, ic: int, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(verts[ia])
	st.set_uv(ub)
	st.add_vertex(verts[ib])
	st.set_uv(uc)
	st.add_vertex(verts[ic])


static func _cap(st: SurfaceTool, verts: Array, center: Vector3, base: int, seg: int, front: bool) -> void:
	for j in seg:
		var a := base + j
		var b := base + (j + 1) % seg
		st.set_uv(Vector2(0.5, 0.5))
		if front:
			st.add_vertex(center)
			st.add_vertex(verts[a])
			st.add_vertex(verts[b])
		else:
			st.add_vertex(center)
			st.add_vertex(verts[b])
			st.add_vertex(verts[a])
