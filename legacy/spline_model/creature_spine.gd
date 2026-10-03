class_name CreatureSpine
extends RefCounted

## The creature backbone: a chain of "vertebrae", each a control point (position)
## with a body radius. The body skin is lofted along a smooth Curve3D that passes
## through these points. This is the data model only — see BodyMeshBuilder for the
## mesh generation that consumes it.

var points: PackedVector3Array = PackedVector3Array()
var radii: PackedFloat32Array = PackedFloat32Array()


func add_vertebra(pos: Vector3, radius: float) -> void:
	points.append(pos)
	radii.append(radius)


func clear() -> void:
	points = PackedVector3Array()
	radii = PackedFloat32Array()


func size() -> int:
	return points.size()


## Build a default worm-like spine: a straight chain along the +Z axis, centered
## on the origin, with a "belly bulge" radius profile (thin at head/tail, fat in
## the middle). A good starting blob to reshape interactively.
static func make_default(segments: int = 8, length: float = 4.0, max_radius: float = 0.6) -> CreatureSpine:
	var spine := CreatureSpine.new()
	var n := maxi(2, segments)
	for i in n:
		var t := float(i) / float(n - 1)            # 0..1 from head to tail
		var z := (t - 0.5) * length                 # centered on the origin
		# Bell-ish profile: sin(t*PI) is 0 at the ends, 1 in the middle.
		var r := max_radius * (0.25 + 0.75 * sin(t * PI))
		spine.add_vertebra(Vector3(0.0, 0.0, z), r)
	return spine


## A Curve3D passing through the vertebra points, for smooth sampling along the
## backbone (position + arc-length lookups).
func to_curve() -> Curve3D:
	var curve := Curve3D.new()
	for p in points:
		curve.add_point(p)
	return curve


## Interpolated body radius at normalized position u in [0,1] across the control
## points (linear blend between the two nearest vertebrae).
func radius_at(u: float) -> float:
	if radii.is_empty():
		return 0.0
	if radii.size() == 1:
		return radii[0]
	var f := clampf(u, 0.0, 1.0) * float(radii.size() - 1)
	var i := int(floor(f))
	if i >= radii.size() - 1:
		return radii[radii.size() - 1]
	return lerpf(radii[i], radii[i + 1], f - float(i))
