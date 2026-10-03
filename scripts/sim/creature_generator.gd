class_name CreatureGenerator
extends RefCounted

## Seeded procedural creature generator. It reuses catalog primitives and
## SocketCatalog attach points so generated bodies are editor-legal by default.
##
## Every seed varies body proportions and limb sizes (not just part counts), so
## different seeds produce visibly different creatures. Limbs can be multi-segment
## (knees/elbows) and a biped body plan is available.


class Config:
	extends Resource
	var seed := 1
	var spine_segments_min := 1
	var spine_segments_max := 3
	var limb_pairs_min := 2
	var limb_pairs_max := 3
	var leg_segments := 1          # capsule segments per leg (>=2 gives a knee)
	var arm_pairs := 0             # pairs of upper (non-foot) limbs
	var arm_segments := 0          # capsule segments per arm (>=2 gives an elbow)
	var want_head := true
	var want_organs := true
	var symmetry := true
	var max_parts := 48
	var biped := false


static func generate(cfg: Config = null) -> PartGene:
	var c := cfg if cfg != null else Config.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = c.seed
	var root: PartGene
	if c.biped:
		root = _build_biped(c, rng)
	else:
		root = _build_radial(c, rng)
	var chk := GenomeSnapshot.validate_unique(root)
	if not bool(chk["ok"]):
		return PartCatalog.make_quadruped(false)
	return root


static func make_biped(seed_value := 1) -> PartGene:
	var cfg := Config.new()
	cfg.seed = seed_value
	cfg.biped = true
	cfg.leg_segments = 2
	cfg.arm_pairs = 1
	cfg.arm_segments = 2
	# NOTE: honest bipedal walk/run is DEFERRED. Tagging the biped &"honest" drops it to ~0 net (it
	# falls in every amp/freq/gain/balance config tried) — it relied on the central-force assist far
	# more than its 0.10 ceiling suggested. Dynamic bipedal balance is a hard control problem the CPG +
	# balance-torque can't yet do (cf. the single-leg monopod). Left ASSISTED so it still walks; honest
	# biped run needs a dedicated balance controller. See docs/HONEST_MIGRATION.md.
	return generate(cfg)


static func make_hexapod(seed_value := 1) -> PartGene:
	var cfg := Config.new()
	cfg.seed = seed_value
	cfg.spine_segments_min = 3
	cfg.spine_segments_max = 3
	cfg.limb_pairs_min = 3
	cfg.limb_pairs_max = 3
	cfg.leg_segments = 1
	cfg.want_head = false
	cfg.want_organs = true
	cfg.max_parts = 48
	var root := generate(cfg)
	# The six-legged radial build has more contact points and lower per-leg load than
	# the quadruped; a low-gain, faster cadence is the current measured-walk recipe.
	if root != null and root.gait != null:
		_apply_walk_tuning(root.gait, 1.5, 1.13, 6.25, 1.755, 1.215)
	return root


static func make_segmented_quadruped(seed_value := 1) -> PartGene:
	var cfg := Config.new()
	cfg.seed = seed_value
	cfg.spine_segments_min = 1
	cfg.spine_segments_max = 1
	cfg.limb_pairs_min = 2
	cfg.limb_pairs_max = 2
	cfg.leg_segments = 3
	cfg.want_head = false
	cfg.want_organs = true
	cfg.max_parts = 48
	var root := generate(cfg)
	if root != null and root.gait != null:
		_apply_walk_tuning(root.gait, 2.2, 0.7, 8.0, 0.77, 1.21)
	return root


static func make_spider(seed_value := 1) -> PartGene:
	# Eight splayed, knee-jointed legs around a low compact body — an octopod radial walker.
	var cfg := Config.new()
	cfg.seed = seed_value
	cfg.spine_segments_min = 4
	cfg.spine_segments_max = 4
	cfg.limb_pairs_min = 4
	cfg.limb_pairs_max = 4
	cfg.leg_segments = 2
	cfg.want_head = false
	cfg.want_organs = true
	cfg.max_parts = 64
	var root := generate(cfg)
	# Many low-load contact points: a low-gain, brisk cadence like the hexapod recipe.
	if root != null and root.gait != null:
		_apply_walk_tuning(root.gait, 1.35, 1.2, 4.5, 1.045, 0.66)
	return root


static func limb_count(root: PartGene) -> int:
	var n := 0
	for g in _walk(root):
		if g.tags.has(&"locomotor"):
			n += 1
	return n


static func _build_radial(c: Config, rng: RandomNumberGenerator) -> PartGene:
	# Per-creature proportions so different seeds look genuinely different.
	var body_w := rng.randf_range(0.8, 1.5)
	var body_h := rng.randf_range(0.7, 1.2)
	var body_l := rng.randf_range(0.9, 1.6)
	var leg_len := rng.randf_range(0.75, 1.4)
	var leg_thick := rng.randf_range(0.8, 1.4)
	var head_size := rng.randf_range(0.8, 1.5)

	var root := _box_body(&"body", body_w, body_h, body_l)
	root.gait = GaitDef.new()
	root.gait.pattern = &"trot"
	_apply_walk_tuning(root.gait, 2.2, 0.7, 8.0, 1.4, 2.2)

	var bodies: Array[PartGene] = [root]
	var spine_n := clampi(rng.randi_range(c.spine_segments_min, c.spine_segments_max), 1, 8)
	var tail := root
	for i in range(1, spine_n):
		var seg := _box_body(StringName("body_%02d" % i),
				body_w * rng.randf_range(0.8, 1.05),
				body_h * rng.randf_range(0.8, 1.05),
				body_l * rng.randf_range(0.7, 1.0))
		_attach(tail, seg, &"body_back")
		tail.children.append(seg)
		bodies.append(seg)
		tail = seg

	if c.want_head and _part_count(root) < c.max_parts:
		var head := PartCatalog.clone_template(&"primitive_sphere")
		head.part_id = &"generated_head"
		head.tags = [&"brain", &"sensor"]
		head.definition.extents = Vector3.ONE * 0.16 * head_size
		_attach(root, head, &"body_front")
		root.children.append(head)

	if c.want_organs:
		_add_organ(root, &"organ_core", &"organ_heart")
		_add_organ(root, &"organ_top", &"organ_brain")
		_add_organ(root, &"organ_core", &"organ_lung")

	var leg_pairs := [
		[&"limb_left_front", &"limb_right_front"],
		[&"limb_left_back", &"limb_right_back"],
	]
	var pair_count := clampi(rng.randi_range(c.limb_pairs_min, c.limb_pairs_max), 1, 8)
	var limb_i := 0
	for pair_i in pair_count:
		if _part_count(root) + 2 * maxi(c.leg_segments, 1) > c.max_parts:
			break
		var parent: PartGene = bodies[pair_i % bodies.size()]
		var pair: Array = leg_pairs[pair_i % leg_pairs.size()]
		for side_i in pair.size():
			var point_id: StringName = pair[side_i]
			if SocketCatalog.occupancy(parent, point_id) > 0:
				continue
			var pair_phase := 0.0 if pair_i % 2 == 0 else 0.5
			var phase := pair_phase if side_i == 0 else wrapf(pair_phase + 0.5, 0.0, 1.0)
			_build_limb(parent, point_id, maxi(c.leg_segments, 1), true, rng, limb_i,
					root.gait, leg_len, leg_thick, phase)
			limb_i += 1

	if c.arm_pairs > 0 and c.arm_segments > 0:
		var arm_pts := [&"limb_left_upper", &"limb_right_upper"]
		for side_i in arm_pts.size():
			var point_id: StringName = arm_pts[side_i]
			if _part_count(root) + c.arm_segments > c.max_parts:
				break
			var phase := 0.0 if side_i == 0 else 0.5
			_build_limb(root, point_id, c.arm_segments, false, rng, limb_i,
					root.gait, leg_len * 0.8, leg_thick * 0.8, phase)
			limb_i += 1

	return root


static func _build_biped(c: Config, rng: RandomNumberGenerator) -> PartGene:
	var torso := _box_body(&"torso",
			rng.randf_range(0.7, 0.95), rng.randf_range(1.3, 1.9), rng.randf_range(0.55, 0.8))
	torso.gait = GaitDef.new()
	torso.gait.pattern = &"biped"
	_apply_walk_tuning(torso.gait, 1.7, 0.62, 8.5, 1.015, 2.8)

	if c.want_head:
		var head := PartCatalog.clone_template(&"primitive_sphere")
		head.part_id = &"head"
		head.tags = [&"brain", &"sensor"]
		head.definition.extents = Vector3.ONE * 0.16 * rng.randf_range(0.9, 1.3)
		_attach(torso, head, &"organ_top")
		torso.children.append(head)
	if c.want_organs:
		_add_organ(torso, &"organ_core", &"organ_heart")
		_add_organ(torso, &"organ_top", &"organ_brain")
		_add_organ(torso, &"organ_core", &"organ_lung")

	var leg_len := rng.randf_range(1.1, 1.6)
	var leg_thick := rng.randf_range(0.9, 1.3)
	var leg_pts := [&"limb_left_back", &"limb_right_back"]
	for i in leg_pts.size():
		var phase := 0.0 if i == 0 else 0.5
		_build_limb(torso, leg_pts[i], maxi(c.leg_segments, 2), true, rng, i,
				torso.gait, leg_len, leg_thick, phase, 0.0, 1.4, Vector2(0.34, 0.42))

	var arm_seg := maxi(c.arm_segments, 2)
	var arm_pts := [&"limb_left_upper", &"limb_right_upper"]
	for i in arm_pts.size():
		var phase := 0.5 if i == 0 else 0.0
		_build_limb(torso, arm_pts[i], arm_seg, false, rng, 10 + i,
				torso.gait, leg_len * 0.7, leg_thick * 0.7, phase)

	return torso


# Builds a chain of `segments` capsules. The first attaches to `parent` at
# `point_id`; each later segment hangs off the previous segment's bottom end,
# giving knees/elbows. Legs make their last segment a ground_contact foot.
static func _build_limb(parent: PartGene, point_id: StringName, segments: int, is_leg: bool,
		rng: RandomNumberGenerator, limb_index: int, gait: GaitDef,
		length: float, thick: float, phase_override := INF, root_z_override := INF,
		root_stance_scale := 0.0, foot_extents := Vector2.ZERO) -> void:
	var current := parent
	var attach_id := point_id
	var seg_count := maxi(segments, 1)
	var phase := phase_override if phase_override != INF else (0.5 if (limb_index % 2 == 1) else 0.0)
	var kind := "leg" if is_leg else "arm"
	var last_seg: PartGene = null
	var last_len := 0.0
	var last_rad := 0.0
	for seg_i in seg_count:
		var ankle_segment := is_leg and seg_count >= 3 and seg_i == seg_count - 1
		var seg := PartCatalog.clone_template(&"primitive_capsule")
		seg.part_id = StringName("%s_%02d_%02d" % [kind, limb_index, seg_i])
		seg.tags = [&"locomotor"]
		if is_leg:
			seg.tags.append(&"leg")
			if seg_i == 1:
				seg.tags.append(&"knee")
			if ankle_segment:
				seg.tags.append(&"ankle")
		else:
			seg.tags.append(&"arm")
			seg.tags.append(&"manipulator")
			if seg_i == seg_count - 1:
				seg.tags.append(&"hand")
		var seg_len := 0.18 * length if ankle_segment else 0.42 * length * (1.0 - 0.12 * seg_i)
		var seg_rad := 0.075 * thick if ankle_segment else 0.1 * thick
		seg.definition.extents = Vector3(seg_rad, seg_len, seg_rad)
		seg.joint = JointDef.new()
		seg.joint.amplitude = rng.randf_range(0.35, 0.6) if ankle_segment else rng.randf_range(0.8, 1.15)
		seg.joint.rest_angle = -0.35 if ankle_segment else (0.25 if seg_i > 0 else 0.0)
		seg.joint.angle_min = -0.75 if ankle_segment else -1.2
		seg.joint.angle_max = 0.75 if ankle_segment else 1.2
		_attach(current, seg, attach_id)
		if seg_i == 0 and seg.socket != null:
			var attach_pos := seg.socket.parent_attachment.origin
			if root_z_override != INF:
				attach_pos.z = root_z_override
			if root_stance_scale > 0.0 and parent != null and parent.definition != null:
				attach_pos.x = signf(attach_pos.x) * parent.definition.extents.x * root_stance_scale
			seg.socket.parent_attachment = Transform3D(seg.socket.parent_attachment.basis, attach_pos)
		# socket_id stays the occupancy-correct point id, but socket.id (the gait /
		# phase key) must be globally unique or chained segments collide on
		# "end_bottom". Use the already-unique part_id.
		if seg.socket != null:
			seg.socket.id = seg.part_id
		current.children.append(seg)
		if gait != null and seg.socket != null:
			gait.assignments[seg.socket.id] = wrapf(phase + 0.12 * seg_i, 0.0, 1.0)
		current = seg
		attach_id = &"end_bottom"
		last_seg = seg
		last_len = seg_len
		last_rad = seg_rad
	if is_leg and last_seg != null:
		_add_foot_pad(last_seg, limb_index, last_len, last_rad, foot_extents)


static func _apply_walk_tuning(gait: GaitDef, amplitude: float, frequency: float,
		gain: float, traction: float, posture: float) -> void:
	if gait == null:
		return
	gait.amplitude_scale = amplitude
	gait.frequency_scale = frequency
	gait.gain_scale = gain
	gait.traction_scale = traction
	gait.posture_scale = posture


static func _box_body(id: StringName, w: float, h: float, l: float) -> PartGene:
	var g := PartCatalog.clone_template(&"primitive_box")
	g.part_id = id
	g.tags = [&"spine"]
	g.definition.extents = Vector3(0.34 * w, 0.24 * h, 0.4 * l)
	return g


static func _add_organ(parent: PartGene, point_id: StringName, part_id: StringName) -> void:
	var organ := PartCatalog.clone_template(part_id)
	if organ == null:
		return
	var gate := SocketCatalog.can_attach(parent, point_id, organ.tags)
	if not bool(gate["ok"]):
		return
	var point := gate["point"] as AttachPoint
	var socket_id := SocketCatalog.next_socket_id(parent, point_id)
	organ.socket_id = socket_id
	organ.socket = SocketCatalog.socket_for_child(point, socket_id, organ, &"center")
	parent.children.append(organ)


static func _attach(parent: PartGene, child: PartGene, point_id: StringName) -> void:
	var point := SocketCatalog.point_for(parent, point_id)
	if point == null:
		return
	var socket_id := SocketCatalog.next_socket_id(parent, point_id)
	child.socket_id = socket_id
	child.socket = SocketCatalog.socket_for_child(point, socket_id, child,
			&"top" if child.tags.has(&"locomotor") or child.tags.has(&"ground_contact") else &"center")


static func _add_foot_pad(parent: PartGene, limb_index: int, parent_len: float,
		parent_rad: float, override_extents := Vector2.ZERO) -> void:
	var foot := PartCatalog.clone_template(&"primitive_box")
	foot.part_id = StringName("foot_%02d" % limb_index)
	foot.tags = [&"ground_contact", &"foot"]
	foot.definition.density = 650.0
	var foot_x := override_extents.x if override_extents.x > 0.0 else maxf(parent_rad * 1.9, 0.12)
	var foot_z := override_extents.y if override_extents.y > 0.0 else maxf(parent_len * 0.34, 0.18)
	foot.definition.extents = Vector3(foot_x, 0.035, foot_z)
	var point := SocketCatalog.point_for(parent, &"end_bottom")
	if point == null:
		return
	var sid := SocketCatalog.next_socket_id(parent, &"end_bottom")
	foot.socket_id = sid
	foot.socket = SocketCatalog.socket_for_child(point, sid, foot, &"top")
	parent.children.append(foot)


static func _part_count(root: PartGene) -> int:
	return _walk(root).size()


static func _walk(root: PartGene) -> Array[PartGene]:
	var out: Array[PartGene] = []
	_walk_into(root, out)
	return out


static func _walk_into(g: PartGene, out: Array[PartGene]) -> void:
	if g == null:
		return
	out.append(g)
	for child in g.children:
		_walk_into(child, out)
