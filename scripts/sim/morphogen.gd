class_name Morphogen
extends RefCounted

## Procedural morphogenesis v1 — grows a creature body from a seed using a SMALL
## L-system grammar. The alphabet is three rule-symbols expanded by a seeded RNG:
##   SEGMENT   — extend the spine by one body segment (parent distal end -> child).
##   BRANCH    — spawn a SYMMETRIC limb pair off the current spine segment (a multi-
##               part chain per side: upper -> lower -> foot).
##   TERMINATE — cap the spine tip with a sensor/foot, ending growth.
##
## Connectivity uses the M47 PROXIMAL-END anchor convention (mirroring PartCatalog):
## a child's socket.child_anchor sits at its own proximal end (0, -child.extents.y, 0)
## and parent_attachment.origin sits at the parent's distal end, so consecutive segment
## centers are exactly (a.dims.y + b.dims.y) * 0.5 apart with NO gap.
##
## Deterministic: same seed -> byte-identical tree (single seeded RandomNumberGenerator,
## never Time/randf without a seed).


## Tiny knob set; callers may pass null and get sensible defaults.
class Config:
	extends RefCounted
	var max_depth: int = 5       ## max spine segments to grow (hard cap on body length)
	var branch_rate: float = 0.6 ## probability a spine segment spawns a limb pair
	var min_parts: int = 5       ## keep growing/branching until at least this many parts


# --- Public API -------------------------------------------------------------

static func grow(seed: int, cfg = null) -> PartGene:
	var c: Config = cfg if cfg is Config else Config.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# Root body: a box trunk. The spine grows along -Y so segments stack downward
	# (matching the straight-chain example: parent distal end at (0, -extents.y, 0)).
	var root := _gene(_definition(&"box", 900.0, Vector3(0.30, 0.22, 0.34)),
			[&"spine", &"morphogen", &"vital"], null, &"morpho_root")

	# Build an L-system instruction stream, then realize it into a tree. The stream is
	# a flat list of symbols; SEGMENT pushes the spine tip forward, BRANCH decorates the
	# current tip, TERMINATE caps and stops.
	var program := _derive(rng, c)

	var spine_tip := root
	var spine_index := 0
	var made_pair := false
	for symbol in program:
		match symbol:
			&"SEGMENT":
				spine_index += 1
				spine_tip = _add_segment(spine_tip, spine_index, rng)
			&"BRANCH":
				_add_limb_pair(spine_tip, spine_index, rng)
				made_pair = true
			&"TERMINATE":
				_cap_tip(spine_tip, spine_index, rng)

	# Safety net: guarantee a non-degenerate, >= min_parts body even for pathological
	# seeds. If the grammar under-produced, force a limb pair + a cap so the result is
	# always a valid walker-ish body rather than a bare trunk.
	if not made_pair:
		_add_limb_pair(spine_tip, spine_index + 1, rng)
	while _count(root) < c.min_parts:
		spine_index += 1
		spine_tip = _add_segment(spine_tip, spine_index, rng)
		_add_limb_pair(spine_tip, spine_index, rng)

	return root


# --- L-system derivation ----------------------------------------------------

# Produce a flat symbol stream. We keep it intentionally small: start from a SEGMENT
# axiom and, per step, decide SEGMENT-then-maybe-BRANCH until depth runs out, then
# TERMINATE. All choices come from `rng`, so the stream (and thus the tree) is
# fully determined by the seed.
static func _derive(rng: RandomNumberGenerator, c: Config) -> Array[StringName]:
	var out: Array[StringName] = []
	var depth := maxi(c.max_depth, 1)
	# Vary the actual length per-seed (1..depth) so different seeds give different bodies.
	var segments := rng.randi_range(1, depth)
	for i in segments:
		out.append(&"SEGMENT")
		# Limb pair on this segment? Bias the first couple of segments to branch so the
		# creature reliably has legs near the front/middle.
		var p := c.branch_rate + (0.25 if i == 0 else 0.0)
		if rng.randf() < clampf(p, 0.0, 1.0):
			out.append(&"BRANCH")
	out.append(&"TERMINATE")
	return out


# --- Realization (SEGMENT / BRANCH / TERMINATE) -----------------------------

# SEGMENT: append a straight spine box at the parent's distal end. Centers end up
# (parent.dims.y + child.dims.y) * 0.5 apart — the M47 colinear-chain invariant.
static func _add_segment(parent: PartGene, index: int, rng: RandomNumberGenerator) -> PartGene:
	var hy := rng.randf_range(0.16, 0.24)
	var extents := Vector3(rng.randf_range(0.18, 0.26), hy, rng.randf_range(0.22, 0.30))
	var sid := StringName("morpho_seg_%d" % index)
	var defn := _definition(&"box", 820.0, extents)
	var seg := _gene(defn, [&"spine", &"locomotor"],
			# parent_attachment at parent's distal end; child anchored by its proximal end.
			_straight_socket(parent, extents, sid),
			sid, sid)
	# A gentle vertical-axis hinge so the spine can flex (undulation potential).
	seg.joint = JointDef.new()
	seg.joint.amplitude = 1.0
	seg.joint.angle_min = -0.6
	seg.joint.angle_max = 0.6
	parent.children.append(seg)
	return seg


# BRANCH: a SYMMETRIC limb pair (left + right). Each side is a 2-segment chain
# (upper -> lower) capped with a foot, all proximal-end anchored off each other.
static func _add_limb_pair(spine: PartGene, index: int, rng: RandomNumberGenerator) -> void:
	var thin := rng.randf_range(0.045, 0.075)
	var up_h := rng.randf_range(0.16, 0.24)
	var lo_h := rng.randf_range(0.14, 0.20)
	for side in [-1.0, 1.0]:
		var sx := signf(side)
		var tag := "L" if sx < 0.0 else "R"
		var prefix := "morpho_limb_%d_%s" % [index, tag]
		var up_ext := Vector3(thin, up_h, thin)
		var lo_ext := Vector3(thin * 0.85, lo_h, thin * 0.85)
		var ft_ext := Vector3(0.11, 0.03, 0.16)

		# Upper segment hangs off the side of the spine, splayed out and down. We anchor
		# it by its proximal end and place parent_attachment on the spine's side wall.
		var up_id := StringName("%s_upper" % prefix)
		var hip_pos := Vector3(sx * (spine.definition.extents.x), -0.02, 0.0)
		var up_def := _definition(&"capsule", 760.0, up_ext)
		var up := _gene(up_def, [&"locomotor", &"leg", &"upper"],
				_proximal_socket(hip_pos, Vector3(0, 0, 1), up_id, up_ext.y),
				up_id, up_id)
		up.joint = JointDef.new()
		up.joint.amplitude = 1.0
		up.joint.angle_min = -1.1
		up.joint.angle_max = 1.1

		# Lower segment continues straight down off the upper's distal end.
		var lo_id := StringName("%s_lower" % prefix)
		var lo_def := _definition(&"capsule", 720.0, lo_ext)
		var lo := _gene(lo_def, [&"locomotor", &"leg", &"knee", &"lower"],
				_straight_socket(up, lo_ext, lo_id, Vector3(0, 0, 1)),
				lo_id, lo_id)
		lo.joint = JointDef.new()
		lo.joint.amplitude = 1.0
		lo.joint.angle_min = -1.1
		lo.joint.angle_max = 1.1

		# Foot at the lower's distal end (ground contact).
		var ft_id := StringName("%s_foot" % prefix)
		var ft_def := _definition(&"box", 620.0, ft_ext)
		var foot := _gene(ft_def, [&"ground_contact", &"foot"],
				_straight_socket(lo, ft_ext, ft_id),
				ft_id, ft_id)

		lo.children.append(foot)
		up.children.append(lo)
		spine.children.append(up)


# TERMINATE: cap the current spine tip with a small sensor at its distal end.
static func _cap_tip(tip: PartGene, index: int, rng: RandomNumberGenerator) -> void:
	var r := rng.randf_range(0.06, 0.10)
	var ext := Vector3(r, r, r)
	var sid := StringName("morpho_sensor_%d" % index)
	var sensor := _gene(_definition(&"sphere", 550.0, ext),
			[&"sensor"], _straight_socket(tip, ext, sid), sid, sid)
	tip.children.append(sensor)


# --- Anchor helpers (M47 proximal-end convention) ---------------------------

# Straight colinear chain: parent_attachment at the parent's distal end (0, -parent.extents.y, 0)
# and child anchored by its proximal end (0, -child.extents.y, 0). Center-to-center distance is
# therefore parent.extents.y + child.extents.y == (parent.dims.y + child.dims.y) * 0.5.
static func _straight_socket(parent: PartGene, child_extents: Vector3, id: StringName,
		hinge := Vector3.ZERO) -> SocketDef:
	var s := SocketDef.new()
	s.id = id
	s.display_name = String(id)
	s.parent_attachment = Transform3D(Basis.IDENTITY, Vector3(0.0, -parent.definition.extents.y, 0.0))
	s.child_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, -child_extents.y, 0.0))
	s.hinge_axis = hinge
	return s


# Generic proximal-end socket at an arbitrary parent-local attachment point (used for limbs
# that branch off a side wall rather than continuing the colinear spine).
static func _proximal_socket(center: Vector3, hinge: Vector3, id: StringName,
		proximal: float) -> SocketDef:
	var s := SocketDef.new()
	s.id = id
	s.display_name = String(id)
	s.parent_attachment = Transform3D(Basis.IDENTITY, center)
	s.child_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, -maxf(proximal, 0.0), 0.0))
	s.hinge_axis = hinge
	return s


# --- Gene construction (mirrors PartCatalog helpers) ------------------------

static func _definition(part_type: StringName, density: float, extents: Vector3) -> PartDefinition:
	var d := PartDefinition.new()
	d.part_type = part_type
	d.density = density
	d.extents = extents
	return d


static func _gene(defn: PartDefinition, tags: Array, socket: SocketDef = null,
		part_id: StringName = &"", socket_id: StringName = &"") -> PartGene:
	var g := PartGene.new()
	g.definition = defn
	var typed: Array[StringName] = []
	for t in tags:
		typed.append(t)
	g.tags = typed
	g.socket = socket
	g.part_id = part_id
	g.socket_id = socket_id
	return g


static func _count(root: PartGene) -> int:
	if root == null:
		return 0
	var n := 1
	for ch in root.children:
		n += _count(ch)
	return n
