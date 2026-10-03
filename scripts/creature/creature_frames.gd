class_name CreatureFrames
extends RefCounted

## Shared frame-law helpers. Transforms stay rigid; scale is accumulated as data
## and applied to dimensions/CoM, never baked into Transform3D.basis.

const MIN_SCALE := 0.001


static func child_world(parent_world: Transform3D, socket: SocketDef) -> Transform3D:
	if socket == null:
		return parent_world
	return parent_world * socket.parent_attachment * socket.child_anchor


static func accumulated_scale(parent_scale: Vector3, gene_scale: Vector3) -> Vector3:
	var s := parent_scale * gene_scale
	return Vector3(maxf(s.x, MIN_SCALE), maxf(s.y, MIN_SCALE), maxf(s.z, MIN_SCALE))


static func dims_for(defn: PartDefinition, scale: Vector3) -> Vector3:
	return defn.extents * 2.0 * scale


static func com_local(defn: PartDefinition, scale: Vector3) -> Vector3:
	return defn.centroid_offset * scale


static func com_world(world: Transform3D, defn: PartDefinition, scale: Vector3) -> Vector3:
	return world * com_local(defn, scale)


## Model-B "snap onto spine": produce a socket on a spine/body part, expressed as
## parent-local attachment data, so the editor still commits a normal PartGene socket.
static func spine_socket(parent: PartGene, id: StringName, z_fraction: float,
		side := -1.0, hinge_axis := Vector3.ZERO) -> SocketDef:
	var s := SocketDef.new()
	s.id = id
	s.display_name = String(id)
	var e := Vector3.ONE
	if parent != null and parent.definition != null:
		e = parent.definition.extents
	var z := lerpf(-e.z, e.z, clampf(z_fraction, 0.0, 1.0))
	var x := signf(side) * e.x
	var y := -e.y
	s.parent_attachment = Transform3D(Basis.IDENTITY, Vector3(x, y, z))
	s.child_anchor = Transform3D.IDENTITY
	s.hinge_axis = hinge_axis
	return s
