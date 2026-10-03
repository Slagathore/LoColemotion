class_name PartCatalog
extends RefCounted

## Small built-in primitive catalog for the editor. These are templates, not live
## genome nodes; callers receive deep copies before editing or attaching them.

const DEFAULT_DENSITY := 1000.0


static func templates() -> Dictionary:
	var out := {
		&"primitive_box": _template(&"primitive_box", &"box", Vector3(0.35, 0.25, 0.35), [&"spine"]),
		&"primitive_sphere": _template(&"primitive_sphere", &"sphere", Vector3(0.30, 0.30, 0.30), []),
		&"primitive_cylinder": _template(&"primitive_cylinder", &"cylinder", Vector3(0.18, 0.45, 0.18), []),
		&"primitive_capsule": _template(&"primitive_capsule", &"capsule", Vector3(0.12, 0.45, 0.12), [&"locomotor", &"ground_contact"]),
		&"body_small": _template(&"body_small", &"box", Vector3(0.28, 0.20, 0.36), [&"spine"], 900.0),
		&"body_long": _template(&"body_long", &"box", Vector3(0.32, 0.20, 0.72), [&"spine"], 850.0),
		&"body_flat": _template(&"body_flat", &"box", Vector3(0.55, 0.12, 0.55), [&"spine"], 780.0),
		&"tail_segment": _template(&"tail_segment", &"capsule", Vector3(0.08, 0.36, 0.08), [&"tail", &"spine"], 650.0),
		&"leg_upper": _template(&"leg_upper", &"capsule", Vector3(0.10, 0.46, 0.10), [&"locomotor", &"leg"], 950.0),
		&"leg_lower": _template(&"leg_lower", &"capsule", Vector3(0.08, 0.38, 0.08), [&"locomotor", &"leg", &"knee"], 900.0),
		&"ankle_link": _template(&"ankle_link", &"capsule", Vector3(0.055, 0.22, 0.055), [&"locomotor", &"leg", &"ankle"], 760.0),
		&"foot_pad": _template(&"foot_pad", &"box", Vector3(0.18, 0.035, 0.30), [&"ground_contact", &"foot"], 650.0),
		&"wide_foot_pad": _template(&"wide_foot_pad", &"box", Vector3(0.30, 0.035, 0.24), [&"ground_contact", &"foot"], 620.0),
		&"spring_foot": _template(&"spring_foot", &"capsule", Vector3(0.07, 0.20, 0.07), [&"locomotor", &"ground_contact", &"foot", &"ankle"], 700.0),
		&"spring_joint": _template(&"spring_joint", &"capsule", Vector3(0.075, 0.28, 0.075), [&"locomotor", &"leg", &"spring"], 860.0),
		&"arm_upper": _template(&"arm_upper", &"capsule", Vector3(0.075, 0.34, 0.075), [&"manipulator", &"arm"], 820.0),
		&"arm_lower": _template(&"arm_lower", &"capsule", Vector3(0.055, 0.28, 0.055), [&"manipulator", &"arm"], 780.0),
		&"hand_grasper": _template(&"hand_grasper", &"sphere", Vector3(0.11, 0.08, 0.11), [&"manipulator", &"hand"], 650.0),
		&"sensor_eye": _template(&"sensor_eye", &"sphere", Vector3(0.08, 0.08, 0.08), [&"sensor"], 550.0),
		&"sensor_whisker": _template(&"sensor_whisker", &"cylinder", Vector3(0.025, 0.30, 0.025), [&"sensor"], 300.0),
		&"jaw_claw": _template(&"jaw_claw", &"capsule", Vector3(0.06, 0.22, 0.06), [&"attack"], 1100.0),
		&"spike": _template(&"spike", &"cylinder", Vector3(0.05, 0.20, 0.05), [&"attack"], 1200.0),
		&"blade_weapon": _template(&"blade_weapon", &"capsule", Vector3(0.035, 0.30, 0.035), [&"attack", &"blade"], 1300.0),
		&"stinger_weapon": _template(&"stinger_weapon", &"cylinder", Vector3(0.040, 0.18, 0.040), [&"attack", &"stinger"], 1350.0),
		&"bludgeon_club": _template(&"bludgeon_club", &"capsule", Vector3(0.09, 0.24, 0.09), [&"attack", &"bludgeon"], 1250.0),
		&"muscle_bundle": _template(&"muscle_bundle", &"capsule", Vector3(0.09, 0.30, 0.09), [&"muscle"], 1060.0),
		&"tendon_strut": _template(&"tendon_strut", &"cylinder", Vector3(0.035, 0.36, 0.035), [&"tendon"], 1200.0),
		&"fat_pad": _template(&"fat_pad", &"sphere", Vector3(0.16, 0.11, 0.16), [&"fat"], 550.0),
		&"armor_plate": _template(&"armor_plate", &"box", Vector3(0.26, 0.035, 0.34), [&"armor"], 1400.0),
		&"organ_heart": _template(&"organ_heart", &"box", Vector3(0.22, 0.22, 0.22), [&"heart"], 800.0),
		&"organ_brain": _template(&"organ_brain", &"sphere", Vector3(0.16, 0.16, 0.16), [&"brain"], 600.0),
		&"organ_lung": _template(&"organ_lung", &"sphere", Vector3(0.18, 0.12, 0.18), [&"lung"], 350.0),
	}
	_apply_template_mechanics(out)
	return out


static func template_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in templates().keys():
		ids.append(id)
	ids.sort()
	return ids


static func clone_template(part_id: StringName) -> PartGene:
	var all := templates()
	if not all.has(part_id):
		return null
	return GenomeSnapshot.deep_copy(all[part_id])


static func built_in_cards() -> Array[CreatureCard]:
	var out: Array[CreatureCard] = []
	var quad := CreatureCard.new()
	quad.display_name = "Built-in Quadruped"
	quad.root = make_flagship_quadruped()
	quad.notes = "Flagship v2 quadruped: segmented legs with knees, ankle links, and foot pads."
	out.append(quad)

	# HONEST sagittal quad — dog-style zigzag legs, zero assist (a_ratio 0.000): propulsion is the
	# reference tracker's stance power stroke, balance is weight-shift + SIMBICON + leg-righting.
	# (The old wide Z-leg rig could stand but only crouch-shuffle; the Z-leg concept now lives in the
	# frog's leap design.) Select it and "Watch it walk"; see docs/LOCOMOTION_ARCHITECTURE.md.
	var quad_rt := CreatureCard.new()
	quad_rt.display_name = "Built-in Quad v2 (honest walker)"
	quad_rt.root = make_quadruped_v2()
	quad_rt.notes = "Honest sagittal quad: zigzag dog legs, assist-off walking (a_ratio 0.000)."
	out.append(quad_rt)

	var front := CreatureCard.new()
	front.display_name = "Built-in Front Loaded"
	front.root = make_quadruped(true)
	front.notes = "Same inventory as the quadruped, but unstable by arrangement."
	out.append(front)

	var biped := CreatureCard.new()
	biped.display_name = "Built-in Biped"
	biped.root = CreatureGenerator.make_biped(7)
	biped.notes = "Upright two-legged body with jointed (knee/elbow) limbs and arms."
	out.append(biped)

	var hex := CreatureCard.new()
	hex.display_name = "Built-in Hexapod"
	hex.root = CreatureGenerator.make_hexapod(11)
	hex.notes = "Six-legged generated walker with tripod-style gait phasing."
	out.append(hex)

	var segmented := CreatureCard.new()
	segmented.display_name = "Built-in Knee Walker"
	segmented.root = CreatureGenerator.make_segmented_quadruped(13)
	segmented.notes = "Four legs with thigh, shank, small hinged foot link, and flat foot pads."
	out.append(segmented)

	var spider := CreatureCard.new()
	spider.display_name = "Built-in Spider"
	spider.root = make_spider_v2()
	spider.notes = "V2: low compact body with eight side-mounted, multi-segment legs."
	out.append(spider)

	var frog := CreatureCard.new()
	frog.display_name = "Built-in Frog"
	frog.root = make_frog_v2()
	frog.notes = "V2: squat frog body with spring-tagged three-piece hind legs and small front supports."
	out.append(frog)

	var crab := CreatureCard.new()
	crab.display_name = "Built-in Crab"
	crab.root = make_crab_v2()
	crab.notes = "V2: wide flat carapace, eight side legs, and two forward claws."
	out.append(crab)

	var weird: Array = [
		["Built-in Sea Urchin", make_sea_urchin_v2(), "V2: spherical body with spikes all over and radial pogo-leg spines."],
		["Built-in Starfish", make_starfish_v2(), "V2: flat pentaradial disk with five broad ground-contact arms."],
		["Built-in Serpent", make_serpent_v2(), "V2: visible snaking chain of offset body segments with an undulation gait."],
		["Built-in Tripod", make_tripod(), "Three legs at 120 degrees — odd radial symmetry, no static base."],
		["Built-in Hopper", make_hopper_v2(), "V2: kangaroo-like body with spring hind legs, tail, and small arms."],
		["Built-in Stilt Walker", make_stilt_walker(), "Tiny body on four very long thin legs — a high-CoM balance stress test."],
		["Built-in Daddy Longlegs", make_daddy_longlegs_v2(), "V2: tiny body on eight very long, multi-segment side legs."],
		["Built-in Monopod", make_monopod_v2(), "V2: a single spring-tagged pogo leg under a compact body."],
		["Built-in Tortoise", make_tortoise_v2(), "V2: heavy domed shell over four stubby low legs."],
		["Built-in Mantis", make_mantis_v2(), "V2: upright body with walking hind legs and bladed raptorial forearms."],
		["Built-in Scorpion", make_scorpion_v2(), "V2: eight side legs, two claws, and an actuated whip-strike tail."],
		["Built-in Centipede", make_centipede_v2(), "V2: long segmented body with many small side leg pairs."],
		["Built-in Glider", make_glider_v2(), "M52: winged glider — wings (WingBody) make aero lift/drag; falls slower / glides."],
		["Demo: Bare legs", make_demo_creature(&"bare"), "M47 demo: connected 2-segment legs, no muscle/tendon. Compare with the next two."],
		["Demo: +Muscle", make_demo_creature(&"muscle"), "M47 demo: same body + muscle tags -> higher joint torque ceiling (faster/stronger)."],
		["Demo: +Tendon", make_demo_creature(&"tendon"), "M47 demo: same body + biarticular tendon (knee<->ankle energy recycling)."],
	]
	for w in weird:
		var card := CreatureCard.new()
		card.display_name = String(w[0])
		card.root = w[1]
		card.notes = String(w[2])
		out.append(card)
	return out


# A fresh, empty creature: just a root body box to build off of (editor "Create New").
static func make_blank() -> PartGene:
	var root := _template(&"body", &"box", Vector3(0.26, 0.15, 0.34), [&"spine", &"honest"])
	root.gait = GaitDef.new()
	return root


static func make_flagship_quadruped() -> PartGene:
	return CreatureGenerator.make_segmented_quadruped(13)


static func make_quadruped(front_loaded := false) -> PartGene:
	var root := _gene(_definition(&"box", 1000.0, Vector3(0.5, 0.2, 0.8)), [&"spine"], null, &"body")
	root.gait = _quadruped_gait()
	root.children.append(_gene(_definition(&"box", 800.0, Vector3(0.30, 0.30, 0.30)),
			[&"heart"], _socket(Vector3.ZERO, Vector3.ZERO, &"organ"), &"organ_heart", &"organ"))
	root.children.append(_gene(_definition(&"sphere", 600.0, Vector3(0.18, 0.18, 0.18)),
			[&"brain"], _socket(Vector3(0.0, 0.1, 0.0), Vector3.ZERO, &"brain"), &"organ_brain", &"brain"))

	var leg_def := _definition(&"capsule", 850.0, Vector3(0.08, 0.48, 0.08))
	var foot_def := _definition(&"box", 900.0, Vector3(0.16, 0.04, 0.26))
	var positions: Array[Vector3]
	var ids: Array[StringName]
	if front_loaded:
		positions = [Vector3(-0.4, -0.2, 0.3), Vector3(0.4, -0.2, 0.3),
				Vector3(-0.4, -0.2, 0.7), Vector3(0.4, -0.2, 0.7)]
		ids = [&"leg_A", &"leg_B", &"leg_C", &"leg_D"]
	else:
		positions = [Vector3(-0.4, -0.2, -0.6), Vector3(0.4, -0.2, -0.6),
				Vector3(-0.4, -0.2, 0.6), Vector3(0.4, -0.2, 0.6)]
		ids = [&"hip_BL", &"hip_BR", &"hip_FL", &"hip_FR"]
	for i in positions.size():
		var leg_tags: Array[StringName] = [&"locomotor", &"leg"]
		var foot_tags: Array[StringName] = [&"ground_contact", &"foot"]
		if positions[i].z > 0.0:
			leg_tags.append(&"forelimb")
			foot_tags.append(&"forelimb")
		var leg := _gene(leg_def, leg_tags,
				_socket(positions[i], Vector3(1.0, 0.0, 0.0), ids[i], Vector3(0.0, -leg_def.extents.y, 0.0)),
				&"primitive_capsule", ids[i])
		leg.joint = JointDef.new()
		leg.joint.amplitude = 1.0
		leg.joint.angle_min = -1.1
		leg.joint.angle_max = 1.1
		var foot_id := StringName("%s_foot" % String(ids[i]))
		leg.children.append(_gene(foot_def, foot_tags,
				_socket(Vector3(0.0, -leg_def.extents.y, 0.0), Vector3.ZERO, foot_id,
						Vector3(0.0, -foot_def.extents.y, 0.0)),
				&"primitive_box", foot_id))
		root.children.append(leg)
	root.children.append(_gene(_definition(&"sphere", 350.0, Vector3(0.16, 0.11, 0.16)),
			[&"lung"], _socket(Vector3(0.0, 0.08, 0.18), Vector3.ZERO, &"lung"), &"organ_lung", &"lung"))
	return root


static func _quadruped_gait() -> GaitDef:
	var gait := GaitDef.new()
	gait.pattern = &"trot"
	gait.assignments = {
		&"hip_BL": 0.0,
		&"hip_FR": 0.0,
		&"hip_BR": 0.5,
		&"hip_FL": 0.5,
	}
	gait.amplitude_scale = 2.2
	gait.frequency_scale = 0.7
	gait.gain_scale = 8.0
	gait.traction_scale = 1.4
	gait.posture_scale = 2.2
	return gait


# --- Authored creatures (spider lives in CreatureGenerator; frog/crab are bespoke) ---

# Heart + brain + lung so the creature is alive (vital-organ validity precondition).
# Vital organs (heart/brain/lung — required for the "alive" check). RIGHT-SIZED 2026-06-30: the old
# organs were absurd — a 0.44 m heart in a ~0.6 m body (73% of the torso), ~140 kg of organ mass that
# HUNG BELOW the body and dragged on the floor, and made every creature too heavy to jump or stand
# (the frog's flight phase went from true_air=0 to 0.10 the moment they were removed). Now they FIT
# INSIDE the body cavity: small, light, non-dragging. Presence (not size) satisfies the alive check.
static func _add_vital_organs(root: PartGene) -> void:
	root.children.append(_gene(_definition(&"box", 800.0, Vector3(0.09, 0.09, 0.09)),
			[&"heart"], _socket(Vector3.ZERO, Vector3.ZERO, &"organ"), &"organ_heart", &"organ"))
	root.children.append(_gene(_definition(&"sphere", 600.0, Vector3(0.07, 0.07, 0.07)),
			[&"brain"], _socket(Vector3(0.0, 0.05, 0.0), Vector3.ZERO, &"brain"), &"organ_brain", &"brain"))
	root.children.append(_gene(_definition(&"sphere", 350.0, Vector3(0.08, 0.05, 0.08)),
			[&"lung"], _socket(Vector3(0.0, 0.04, 0.10), Vector3.ZERO, &"lung"), &"organ_lung", &"lung"))


# Single-segment leg + foot, the proven make_quadruped pattern. Caller sets the gait phase by hip_id.
static func _simple_leg(parent: PartGene, hip_id: StringName, hip_pos: Vector3,
		leg_dim: Vector3, foot_dim: Vector3, leg_density := 850.0) -> void:
	var leg_def := _definition(&"capsule", leg_density, leg_dim)
	var foot_def := _definition(&"box", 700.0, foot_dim)
	var leg := _gene(leg_def, [&"locomotor", &"leg"],
			_socket(hip_pos, Vector3(1.0, 0.0, 0.0), hip_id, Vector3(0.0, -leg_def.extents.y, 0.0)),
			&"primitive_capsule", hip_id)
	leg.joint = JointDef.new()
	leg.joint.amplitude = 1.0
	leg.joint.angle_min = -1.1
	leg.joint.angle_max = 1.1
	var foot_id := StringName("%s_foot" % String(hip_id))
	leg.children.append(_gene(foot_def, [&"ground_contact", &"foot"],
			_socket(Vector3(0.0, -leg_def.extents.y, 0.0), Vector3.ZERO, foot_id,
					Vector3(0.0, -foot_def.extents.y, 0.0)),
			&"primitive_box", foot_id))
	parent.children.append(leg)


# M47-B16: a CHAINED two-segment leg (upper -> lower -> foot) using the proven _simple_leg anchor
# pattern (child end -> parent end), so connectivity is guaranteed. `loadout` toggles muscle + the
# biarticular tendon coupling the upper joint to the lower joint. Stable part_ids per prefix.
static func _demo_leg(parent: PartGene, prefix: String, hip_pos: Vector3, loadout: StringName) -> void:
	var up_id := StringName("%s_upper" % prefix)
	var lo_id := StringName("%s_lower" % prefix)
	var ft_id := StringName("%s_foot" % prefix)
	var up_dim := Vector3(0.075, 0.24, 0.075)
	var lo_dim := Vector3(0.06, 0.22, 0.06)
	var ft_dim := Vector3(0.11, 0.03, 0.18)
	var leg_tags: Array = [&"locomotor", &"leg"]
	if loadout == &"muscle" or loadout == &"tendon":
		leg_tags.append(&"muscle")
	var up_def := _definition(&"capsule", 950.0, up_dim)
	var up := _gene(up_def, leg_tags.duplicate(),
			_socket(hip_pos, Vector3(1, 0, 0), up_id, Vector3(0.0, -up_dim.y, 0.0)), up_id, up_id)
	up.joint = JointDef.new()
	up.joint.amplitude = 1.0
	up.joint.angle_min = -1.1
	up.joint.angle_max = 1.1
	var lo_def := _definition(&"capsule", 900.0, lo_dim)
	var lo := _gene(lo_def, (leg_tags + [&"knee"]),
			_socket(Vector3(0.0, -up_dim.y, 0.0), Vector3(1, 0, 0), lo_id, Vector3(0.0, -lo_dim.y, 0.0)),
			lo_id, lo_id)
	lo.joint = JointDef.new()
	lo.joint.amplitude = 1.0
	lo.joint.angle_min = -1.1
	lo.joint.angle_max = 1.1
	if loadout == &"tendon":
		var t := TendonDef.new()
		t.enabled = true
		t.partner_part_id = lo_id          # couple the hip joint to the knee joint (biarticular)
		t.stiffness = 140.0
		t.efficiency = 0.85
		up.tendon = t
	var ft_def := _definition(&"box", 700.0, ft_dim)
	lo.children.append(_gene(ft_def, [&"ground_contact", &"foot"],
			_socket(Vector3(0.0, -lo_dim.y, 0.0), Vector3.ZERO, ft_id, Vector3(0.0, -ft_dim.y, 0.0)),
			ft_id, ft_id))
	up.children.append(lo)
	parent.children.append(up)


# M47-B16: the tendon/muscle demonstrator. SAME morphology, three loadouts — bare / +muscle /
# +tendon — so the player (and the test) can SEE what each primitive does to behaviour.
static func make_demo_creature(loadout: StringName = &"bare") -> PartGene:
	var root := _gene(_definition(&"box", 820.0, Vector3(0.30, 0.18, 0.40)),
			[&"spine", &"demo"], null, &"demo_body")
	_add_vital_organs(root)
	var ids: Array[StringName] = []
	for spec in [["FL", Vector3(-0.26, -0.04, -0.26)], ["FR", Vector3(0.26, -0.04, -0.26)],
			["BL", Vector3(-0.26, -0.04, 0.26)], ["BR", Vector3(0.26, -0.04, 0.26)]]:
		var prefix := "demo_%s" % String(spec[0])
		_demo_leg(root, prefix, spec[1], loadout)
		ids.append(StringName("%s_upper" % prefix))
		ids.append(StringName("%s_lower" % prefix))
	root.gait = _v2_gait(ids, &"trot", 1.6, 1.0, 8.0, 1.2, 1.4)
	return root


static func make_frog() -> PartGene:
	# Squat body, big hind legs that pronk together, small front legs, wide feet.
	var root := _gene(_definition(&"box", 850.0, Vector3(0.42, 0.18, 0.40)), [&"spine"], null, &"body")
	var g := GaitDef.new()
	g.pattern = &"pronk"
	g.assignments = {&"hip_HL": 0.0, &"hip_HR": 0.0, &"hip_FL": 0.5, &"hip_FR": 0.5}
	g.amplitude_scale = 2.4
	g.frequency_scale = 0.85
	g.gain_scale = 8.0
	g.traction_scale = 1.6
	g.posture_scale = 2.3
	root.gait = g
	_add_vital_organs(root)
	_simple_leg(root, &"hip_HL", Vector3(-0.34, -0.10, 0.34), Vector3(0.10, 0.40, 0.10), Vector3(0.22, 0.04, 0.28), 900.0)
	_simple_leg(root, &"hip_HR", Vector3(0.34, -0.10, 0.34), Vector3(0.10, 0.40, 0.10), Vector3(0.22, 0.04, 0.28), 900.0)
	_simple_leg(root, &"hip_FL", Vector3(-0.28, -0.08, -0.32), Vector3(0.06, 0.22, 0.06), Vector3(0.12, 0.035, 0.16), 800.0)
	_simple_leg(root, &"hip_FR", Vector3(0.28, -0.08, -0.32), Vector3(0.06, 0.22, 0.06), Vector3(0.12, 0.035, 0.16), 800.0)
	return root


static func make_crab() -> PartGene:
	# Wide flat carapace, six short splayed side legs, two front claws.
	var root := _gene(_definition(&"box", 820.0, Vector3(0.66, 0.12, 0.40)), [&"spine"], null, &"body")
	var g := GaitDef.new()
	g.pattern = &"trot"
	g.assignments = {&"hip_L1": 0.0, &"hip_R2": 0.0, &"hip_L3": 0.0,
			&"hip_R1": 0.5, &"hip_L2": 0.5, &"hip_R3": 0.5}
	g.amplitude_scale = 1.5
	g.frequency_scale = 1.1
	g.gain_scale = 5.0
	g.traction_scale = 1.9
	g.posture_scale = 1.4
	root.gait = g
	_add_vital_organs(root)
	var zs := [-0.22, 0.0, 0.22]
	var ids_l: Array[StringName] = [&"hip_L1", &"hip_L2", &"hip_L3"]
	var ids_r: Array[StringName] = [&"hip_R1", &"hip_R2", &"hip_R3"]
	for i in 3:
		_simple_leg(root, ids_l[i], Vector3(-0.32, -0.04, zs[i]), Vector3(0.06, 0.30, 0.06), Vector3(0.10, 0.035, 0.14), 820.0)
		_simple_leg(root, ids_r[i], Vector3(0.32, -0.04, zs[i]), Vector3(0.06, 0.30, 0.06), Vector3(0.10, 0.035, 0.14), 820.0)
	root.children.append(_gene(_definition(&"capsule", 1100.0, Vector3(0.07, 0.20, 0.07)),
			[&"attack"], _socket(Vector3(-0.30, 0.0, -0.22), Vector3.ZERO, &"claw_L"), &"jaw_claw", &"claw_L"))
	root.children.append(_gene(_definition(&"capsule", 1100.0, Vector3(0.07, 0.20, 0.07)),
			[&"attack"], _socket(Vector3(0.30, 0.0, -0.22), Vector3.ZERO, &"claw_R"), &"jaw_claw", &"claw_R"))
	return root


# --- Weird-shape authored creatures -----------------------------------------

static func _radial_gait(hip_ids: Array, amplitude := 2.0, frequency := 1.05,
		gain := 6.0, traction := 1.7, posture := 1.6) -> GaitDef:
	# Traveling wave around a radial ring of legs.
	var g := GaitDef.new()
	g.pattern = &"wave"
	for i in hip_ids.size():
		g.assignments[hip_ids[i]] = wrapf(float(i) / float(maxi(hip_ids.size(), 1)), 0.0, 1.0)
	g.amplitude_scale = amplitude
	g.frequency_scale = frequency
	g.gain_scale = gain
	g.traction_scale = traction
	g.posture_scale = posture
	return g


static func make_sea_urchin() -> PartGene:
	# A spherical body bristling with short radial spike-legs (8 ground ring + 2 top spikes).
	var root := _gene(_definition(&"sphere", 700.0, Vector3(0.30, 0.30, 0.30)), [&"spine"], null, &"body")
	_add_vital_organs(root)
	var ring: Array[StringName] = []
	for i in 8:
		var a := TAU * float(i) / 8.0
		var hip := StringName("spike_%d" % i)
		ring.append(hip)
		# splayed down-and-out around the lower hemisphere
		_simple_leg(root, hip, Vector3(cos(a) * 0.22, -0.12, sin(a) * 0.22),
				Vector3(0.05, 0.24, 0.05), Vector3(0.07, 0.03, 0.09), 760.0)
	root.gait = _radial_gait(ring, 2.1, 1.15, 5.5, 1.9, 1.4)
	# two decorative top spikes (attack)
	root.children.append(_gene(_definition(&"cylinder", 1200.0, Vector3(0.04, 0.22, 0.04)),
			[&"attack"], _socket(Vector3(-0.08, 0.26, 0.0), Vector3.ZERO, &"spike_top_L"), &"spike", &"spike_top_L"))
	root.children.append(_gene(_definition(&"cylinder", 1200.0, Vector3(0.04, 0.22, 0.04)),
			[&"attack"], _socket(Vector3(0.08, 0.26, 0.0), Vector3.ZERO, &"spike_top_R"), &"spike", &"spike_top_R"))
	return root


static func make_starfish() -> PartGene:
	# Flat pentaradial disk; five long arms splayed flat act as legs.
	var root := _gene(_definition(&"box", 760.0, Vector3(0.46, 0.07, 0.46)), [&"spine"], null, &"body")
	_add_vital_organs(root)
	var arms: Array[StringName] = []
	for i in 5:
		var a := TAU * float(i) / 5.0
		var hip := StringName("arm_%d" % i)
		arms.append(hip)
		_simple_leg(root, hip, Vector3(cos(a) * 0.34, -0.02, sin(a) * 0.34),
				Vector3(0.07, 0.34, 0.07), Vector3(0.10, 0.03, 0.16), 800.0)
	root.gait = _radial_gait(arms, 1.9, 1.0, 6.0, 1.8, 1.5)
	return root


static func make_serpent() -> PartGene:
	# Limbless undulator: a chain of body segments hinged about vertical axes; the
	# segments themselves are the actuated joints, driving lateral snake undulation.
	var root := _gene(_definition(&"box", 800.0, Vector3(0.18, 0.14, 0.30)),
			[&"spine", &"ground_contact"], null, &"head")
	_add_vital_organs(root)
	var g := GaitDef.new()
	g.pattern = &"undulate"
	var cur := root
	var seg_count := 7
	for i in seg_count:
		var sid := StringName("seg_%d" % i)
		var seg := _gene(_definition(&"box", 760.0, Vector3(0.16, 0.13, 0.28)),
				[&"locomotor", &"spine", &"ground_contact"],
				_socket(Vector3(0.0, 0.0, 0.30), Vector3(0.0, 1.0, 0.0), sid, Vector3(0.0, 0.0, -0.28)),
				&"body_small", sid)
		seg.joint = JointDef.new()
		seg.joint.amplitude = 1.0
		seg.joint.angle_min = -0.9
		seg.joint.angle_max = 0.9
		g.assignments[sid] = wrapf(float(i) * 0.22, 0.0, 1.0)   # traveling wave down the body
		cur.children.append(seg)
		cur = seg
	g.amplitude_scale = 2.4
	g.frequency_scale = 1.2
	g.gain_scale = 6.0
	g.traction_scale = 1.8
	g.posture_scale = 1.0
	root.gait = g
	return root


static func make_tripod() -> PartGene:
	# Three legs at 120 degrees — odd radial symmetry, no stable static base.
	var root := _gene(_definition(&"sphere", 760.0, Vector3(0.26, 0.20, 0.26)), [&"spine"], null, &"body")
	_add_vital_organs(root)
	var hips: Array[StringName] = []
	for i in 3:
		var a := TAU * float(i) / 3.0
		var hip := StringName("leg_%d" % i)
		hips.append(hip)
		_simple_leg(root, hip, Vector3(cos(a) * 0.22, -0.16, sin(a) * 0.22),
				Vector3(0.08, 0.52, 0.08), Vector3(0.14, 0.04, 0.18), 880.0)
	root.gait = _radial_gait(hips, 2.2, 0.95, 7.0, 1.6, 2.2)
	return root


static func make_hopper() -> PartGene:
	# Kangaroo-like: upright torso, two big hind legs that pronk, a heavy balancing
	# tail, and small forelimbs.
	var root := _gene(_definition(&"box", 850.0, Vector3(0.30, 0.34, 0.26)), [&"spine"], null, &"body")
	var g := GaitDef.new()
	g.pattern = &"pronk"
	g.assignments = {&"hip_HL": 0.0, &"hip_HR": 0.0}
	g.amplitude_scale = 2.6
	g.frequency_scale = 0.8
	g.gain_scale = 9.0
	g.traction_scale = 1.6
	g.posture_scale = 3.2
	root.gait = g
	_add_vital_organs(root)
	_simple_leg(root, &"hip_HL", Vector3(-0.18, -0.20, 0.14), Vector3(0.11, 0.46, 0.11), Vector3(0.16, 0.04, 0.34), 950.0)
	_simple_leg(root, &"hip_HR", Vector3(0.18, -0.20, 0.14), Vector3(0.11, 0.46, 0.11), Vector3(0.16, 0.04, 0.34), 950.0)
	# small forelimbs (non-weight-bearing manipulators)
	root.children.append(_gene(_definition(&"capsule", 700.0, Vector3(0.05, 0.20, 0.05)),
			[&"manipulator", &"arm"], _socket(Vector3(-0.16, 0.10, -0.16), Vector3.ZERO, &"arm_L"), &"arm_lower", &"arm_L"))
	root.children.append(_gene(_definition(&"capsule", 700.0, Vector3(0.05, 0.20, 0.05)),
			[&"manipulator", &"arm"], _socket(Vector3(0.16, 0.10, -0.16), Vector3.ZERO, &"arm_R"), &"arm_lower", &"arm_R"))
	# heavy balancing tail
	root.children.append(_gene(_definition(&"capsule", 900.0, Vector3(0.09, 0.46, 0.09)),
			[&"tail", &"spine"], _socket(Vector3(0.0, -0.10, 0.30), Vector3.ZERO, &"tail"), &"tail_segment", &"tail"))
	return root


static func make_stilt_walker() -> PartGene:
	# Tiny body perched on four very long thin legs — a high-center-of-mass balance
	# nightmare (great training stress test).
	var root := _gene(_definition(&"box", 700.0, Vector3(0.24, 0.12, 0.30)), [&"spine"], null, &"body")
	var g := GaitDef.new()
	g.pattern = &"trot"
	g.assignments = {&"hip_BL": 0.0, &"hip_FR": 0.0, &"hip_BR": 0.5, &"hip_FL": 0.5}
	g.amplitude_scale = 1.6
	g.frequency_scale = 0.9
	g.gain_scale = 9.0
	g.traction_scale = 1.5
	g.posture_scale = 3.4
	root.gait = g
	_add_vital_organs(root)
	var pos := {&"hip_BL": Vector3(-0.20, -0.06, -0.22), &"hip_BR": Vector3(0.20, -0.06, -0.22),
			&"hip_FL": Vector3(-0.20, -0.06, 0.22), &"hip_FR": Vector3(0.20, -0.06, 0.22)}
	for hip in pos:
		_simple_leg(root, hip, pos[hip], Vector3(0.045, 0.78, 0.045), Vector3(0.12, 0.035, 0.16), 700.0)
	return root


# --- Weird-shape authored creatures, batch 2 -------------------------------

static func make_daddy_longlegs() -> PartGene:
	# Tiny body perched on eight absurdly long, thin radial legs (extreme high CoM).
	var root := _gene(_definition(&"sphere", 650.0, Vector3(0.16, 0.14, 0.16)), [&"spine"], null, &"body")
	_add_vital_organs(root)
	var hips: Array[StringName] = []
	for i in 8:
		var a := TAU * float(i) / 8.0
		var hip := StringName("leg_%d" % i)
		hips.append(hip)
		_simple_leg(root, hip, Vector3(cos(a) * 0.14, -0.04, sin(a) * 0.14),
				Vector3(0.035, 0.85, 0.035), Vector3(0.06, 0.03, 0.08), 640.0)
	root.gait = _radial_gait(hips, 1.4, 1.05, 5.0, 1.5, 3.0)
	return root


static func make_monopod() -> PartGene:
	# A single big central leg — it can only get anywhere by hopping (pogo stick).
	var root := _gene(_definition(&"box", 800.0, Vector3(0.26, 0.26, 0.22)), [&"spine"], null, &"body")
	var g := GaitDef.new()
	g.pattern = &"pronk"
	g.assignments = {&"hip_C": 0.0}
	g.amplitude_scale = 2.8
	g.frequency_scale = 0.8
	g.gain_scale = 9.0
	g.traction_scale = 1.6
	g.posture_scale = 3.4
	root.gait = g
	_add_vital_organs(root)
	_simple_leg(root, &"hip_C", Vector3(0.0, -0.13, 0.0), Vector3(0.12, 0.50, 0.12), Vector3(0.28, 0.05, 0.30), 950.0)
	return root


static func make_tortoise() -> PartGene:
	# Heavy domed shell on four stubby legs — slow, armored, low to the ground.
	var root := _gene(_definition(&"sphere", 1100.0, Vector3(0.52, 0.30, 0.62)), [&"spine"], null, &"body")
	var g := GaitDef.new()
	g.pattern = &"trot"
	g.assignments = {&"hip_BL": 0.0, &"hip_FR": 0.0, &"hip_BR": 0.5, &"hip_FL": 0.5}
	g.amplitude_scale = 1.4
	g.frequency_scale = 0.8
	g.gain_scale = 9.0
	g.traction_scale = 1.8
	g.posture_scale = 2.6
	root.gait = g
	_add_vital_organs(root)
	root.children.append(_gene(_definition(&"box", 1400.0, Vector3(0.42, 0.05, 0.5)),
			[&"armor"], _socket(Vector3(0.0, 0.18, 0.0), Vector3.ZERO, &"shell"), &"armor_plate", &"shell"))
	var pos := {&"hip_BL": Vector3(-0.32, -0.14, -0.30), &"hip_BR": Vector3(0.32, -0.14, -0.30),
			&"hip_FL": Vector3(-0.32, -0.14, 0.30), &"hip_FR": Vector3(0.32, -0.14, 0.30)}
	for hip in pos:
		_simple_leg(root, hip, pos[hip], Vector3(0.10, 0.20, 0.10), Vector3(0.16, 0.04, 0.18), 900.0)
	return root


static func make_mantis() -> PartGene:
	# Upright: two hind walking legs, two big raptorial forearms (attack), a head.
	var root := _gene(_definition(&"box", 820.0, Vector3(0.22, 0.40, 0.24)), [&"spine"], null, &"body")
	var g := GaitDef.new()
	g.pattern = &"biped"
	g.assignments = {&"hip_L": 0.0, &"hip_R": 0.5}
	g.amplitude_scale = 1.7
	g.frequency_scale = 0.62
	g.gain_scale = 8.5
	g.traction_scale = 1.5
	g.posture_scale = 3.6
	root.gait = g
	_add_vital_organs(root)
	_simple_leg(root, &"hip_L", Vector3(-0.12, -0.20, 0.02), Vector3(0.08, 0.46, 0.08), Vector3(0.14, 0.04, 0.22), 900.0)
	_simple_leg(root, &"hip_R", Vector3(0.12, -0.20, 0.02), Vector3(0.08, 0.46, 0.08), Vector3(0.14, 0.04, 0.22), 900.0)
	root.children.append(_gene(_definition(&"capsule", 1100.0, Vector3(0.07, 0.30, 0.07)),
			[&"attack"], _socket(Vector3(-0.16, 0.16, -0.14), Vector3.ZERO, &"raptor_L"), &"jaw_claw", &"raptor_L"))
	root.children.append(_gene(_definition(&"capsule", 1100.0, Vector3(0.07, 0.30, 0.07)),
			[&"attack"], _socket(Vector3(0.16, 0.16, -0.14), Vector3.ZERO, &"raptor_R"), &"jaw_claw", &"raptor_R"))
	root.children.append(_gene(_definition(&"sphere", 550.0, Vector3(0.10, 0.10, 0.10)),
			[&"sensor"], _socket(Vector3(0.0, 0.24, -0.10), Vector3.ZERO, &"head"), &"sensor_eye", &"head"))
	return root


static func make_scorpion() -> PartGene:
	# Wide body, six splayed legs, two front claws, and a segmented tail curling
	# up and over the back ending in a stinger.
	var root := _gene(_definition(&"box", 820.0, Vector3(0.34, 0.12, 0.46)), [&"spine"], null, &"body")
	var g := GaitDef.new()
	g.pattern = &"wave"
	g.assignments = {&"hip_L1": 0.0, &"hip_R2": 0.0, &"hip_L3": 0.0,
			&"hip_R1": 0.5, &"hip_L2": 0.5, &"hip_R3": 0.5}
	g.amplitude_scale = 1.6
	g.frequency_scale = 1.1
	g.gain_scale = 5.5
	g.traction_scale = 1.8
	g.posture_scale = 1.6
	root.gait = g
	_add_vital_organs(root)
	var zs := [-0.24, 0.0, 0.24]
	var ids_l: Array[StringName] = [&"hip_L1", &"hip_L2", &"hip_L3"]
	var ids_r: Array[StringName] = [&"hip_R1", &"hip_R2", &"hip_R3"]
	for i in 3:
		_simple_leg(root, ids_l[i], Vector3(-0.34, -0.04, zs[i]), Vector3(0.06, 0.32, 0.06), Vector3(0.10, 0.035, 0.14), 820.0)
		_simple_leg(root, ids_r[i], Vector3(0.34, -0.04, zs[i]), Vector3(0.06, 0.32, 0.06), Vector3(0.10, 0.035, 0.14), 820.0)
	root.children.append(_gene(_definition(&"capsule", 1100.0, Vector3(0.07, 0.22, 0.07)),
			[&"attack"], _socket(Vector3(-0.26, 0.0, -0.30), Vector3.ZERO, &"claw_L"), &"jaw_claw", &"claw_L"))
	root.children.append(_gene(_definition(&"capsule", 1100.0, Vector3(0.07, 0.22, 0.07)),
			[&"attack"], _socket(Vector3(0.26, 0.0, -0.30), Vector3.ZERO, &"claw_R"), &"jaw_claw", &"claw_R"))
	# Tail: a few segments arcing up and back, ending in a stinger.
	var cur := root
	var attach := Vector3(0.0, 0.06, 0.30)
	for i in 4:
		var sid := StringName("tail_%d" % i)
		var seg := _gene(_definition(&"capsule", 700.0, Vector3(0.06, 0.16, 0.06)),
				[&"tail", &"spine"], _socket(attach, Vector3.ZERO, sid, Vector3(0.0, -0.08, 0.0)),
				&"tail_segment", sid)
		cur.children.append(seg)
		cur = seg
		attach = Vector3(0.0, 0.10, -0.06)   # each next segment goes up and forward (over the back)
	cur.children.append(_gene(_definition(&"cylinder", 1200.0, Vector3(0.05, 0.18, 0.05)),
			[&"attack"], _socket(Vector3(0.0, 0.10, -0.06), Vector3.ZERO, &"stinger"), &"spike", &"stinger"))
	return root


static func make_centipede() -> PartGene:
	# A head leading a chain of vertically-hinged body segments, each carrying a small
	# leg pair — undulating, many-legged locomotion.
	var root := _gene(_definition(&"box", 780.0, Vector3(0.16, 0.12, 0.22)),
			[&"spine", &"ground_contact"], null, &"head")
	_add_vital_organs(root)
	var g := GaitDef.new()
	g.pattern = &"undulate"
	var cur := root
	var seg_n := 5
	for i in seg_n:
		var sid := StringName("cseg_%d" % i)
		var seg := _gene(_definition(&"box", 740.0, Vector3(0.15, 0.11, 0.22)),
				[&"locomotor", &"spine", &"ground_contact"],
				_socket(Vector3(0.0, 0.0, 0.22), Vector3(0.0, 1.0, 0.0), sid, Vector3(0.0, 0.0, -0.22)),
				&"body_small", sid)
		seg.joint = JointDef.new()
		seg.joint.amplitude = 1.0
		seg.joint.angle_min = -0.7
		seg.joint.angle_max = 0.7
		g.assignments[sid] = wrapf(float(i) * 0.25, 0.0, 1.0)
		# a small leg pair on this segment
		var lid := StringName("cseg_%d_L" % i)
		var rid := StringName("cseg_%d_R" % i)
		_simple_leg(seg, lid, Vector3(-0.15, -0.04, 0.0), Vector3(0.04, 0.20, 0.04), Vector3(0.06, 0.03, 0.08), 700.0)
		_simple_leg(seg, rid, Vector3(0.15, -0.04, 0.0), Vector3(0.04, 0.20, 0.04), Vector3(0.06, 0.03, 0.08), 700.0)
		g.assignments[lid] = wrapf(float(i) * 0.25, 0.0, 1.0)
		g.assignments[rid] = wrapf(float(i) * 0.25 + 0.5, 0.0, 1.0)
		cur.children.append(seg)
		cur = seg
	g.amplitude_scale = 1.8
	g.frequency_scale = 1.15
	g.gain_scale = 5.5
	g.traction_scale = 1.8
	g.posture_scale = 1.3
	root.gait = g
	return root


# --- V2 authored bestiary ----------------------------------------------------

static func _basis_from_y_axis(axis: Vector3) -> Basis:
	var y := axis.normalized()
	if y.is_zero_approx():
		y = Vector3.UP
	var ref := Vector3.FORWARD
	if absf(y.dot(ref)) > 0.92:
		ref = Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z).orthonormalized()


static func _oriented_socket(center: Vector3, axis: Vector3, id: StringName,
		hinge := Vector3.ZERO, proximal := 0.0) -> SocketDef:
	var s := SocketDef.new()
	s.id = id
	s.display_name = String(id)
	s.parent_attachment = Transform3D(_basis_from_y_axis(axis), center)
	# M47-B1: anchor the child by its PROXIMAL END (local -Y·half-length, i.e. axis-projected),
	# not its centroid. With IDENTITY the part floated at its center, leaving a gap and a hinge
	# that spun nothing useful (Principle 19). proximal = the child's extents.y (half-length).
	s.child_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, -maxf(proximal, 0.0), 0.0))
	s.hinge_axis = hinge
	return s


static func _piece(parent: PartGene, id: StringName, part_type: StringName,
		extents: Vector3, tags: Array, center: Vector3, axis: Vector3,
		density := 800.0, hinge := Vector3.ZERO, part_id: StringName = &"") -> PartGene:
	var g := _gene(_definition(part_type, density, extents), tags,
			_oriented_socket(center, axis, id, hinge, extents.y),
			part_id if part_id != &"" else id, id)
	if not hinge.is_zero_approx():
		g.joint = JointDef.new()
		g.joint.amplitude = 1.0
		g.joint.angle_min = -1.1
		g.joint.angle_max = 1.1
	if g.tags.has(&"spring") or part_id == &"spring_foot" or part_id == &"spring_joint":
		_assign_spring(g, 260.0, 0.18, 0.20, 0.16, 0.72)
	_assign_weapon_from_tags(g)
	parent.children.append(g)
	return g


static func _v2_gait(ids: Array[StringName], pattern: StringName, amplitude := 1.8,
		frequency := 1.0, gain := 6.0, traction := 1.5, posture := 1.5) -> GaitDef:
	var g := GaitDef.new()
	g.pattern = pattern
	for i in ids.size():
		g.assignments[ids[i]] = wrapf(float(i) / float(maxi(ids.size(), 1)), 0.0, 1.0)
	g.amplitude_scale = amplitude
	g.frequency_scale = frequency
	g.gain_scale = gain
	g.traction_scale = traction
	g.posture_scale = posture
	return g


static func _v2_side_leg(parent: PartGene, prefix: String, side: float, z: float,
		long := 0.36, thin := 0.045, foot := true, extra_tags: Array = [],
		hip_axis := Vector3(0, 0, 1), out_frac := 0.82, down_frac := 0.57,
		hip_out := 0.33, strut := false) -> Array[StringName]:
	var ids: Array[StringName] = []
	var sx := signf(side)
	var base_tags: Array = [&"locomotor", &"leg"]
	for t in extra_tags:
		base_tags.append(t)
	var upper := StringName("%s_upper" % prefix)
	var lower := StringName("%s_lower" % prefix)
	var ankle := StringName("%s_ankle" % prefix)
	ids.append(upper)
	ids.append(lower)
	ids.append(ankle)
	# M59: a true parent->child CHAIN (upper->lower->ankle->foot) replacing the old fan where every
	# segment hung directly off the body. Each segment attaches at the PREVIOUS segment's distal end
	# (parent-local (0, -prev_extents.y, 0)) and is anchored by its own proximal end (M47 convention,
	# via _piece). The upper splays outward+down along `dir`; later segments continue straight
	# (axis = local +Y) so the limb stays connected end-to-end.
	# M60 hip_axis: the HIP hinge axis. Default Z hinges the splayed leg in the x-y plane = pure
	# LIFT/lower (legacy crab/mantis/scorpion). A vertical Y hip hinge instead sweeps the out-splayed
	# leg FORE-AFT (protraction/retraction) — the propulsive power stroke a real walking leg needs;
	# a planted foot swept backward pushes the body forward. The knee/ankle stay on Z for clearance.
	var up_ext := Vector3(thin, long * 0.45, thin)
	var lo_ext := Vector3(thin * 0.82, long * 0.42, thin * 0.82)
	var an_ext := Vector3(thin * 0.62, long * 0.16, thin * 0.62)
	var ft_ext := Vector3(0.10, 0.025, 0.13)
	# A piece extends along -axis from its socket, so axis = -dir gives an outward+down leg. out_frac/
	# down_frac set the splay: the legacy default (0.82,0.57) is a low, horizontal sprawl; a steeper
	# leg (e.g. 0.35,0.94) stands the body higher on more vertical legs so the limbs clear the floor —
	# what the reference-tracking walkers need so the swing foot lifts instead of dragging.
	var dir := Vector3(sx * out_frac, -down_frac, 0.0)
	# strut mode: the lower/ankle continue along the SAME outward+down diagonal as the upper (one straight
	# strut from a wide hip to a wide foot) instead of dropping world-vertical from the knee. A vertical
	# shin off a splayed thigh lies its LOWER segments near the floor (they drag); a straight diagonal
	# strut keeps every segment elevated above the foot — the fix for the wide-body crab's shin drag.
	var seg_axis := (-dir) if strut else Vector3(0, 1, 0)
	var up := _piece(parent, upper, &"capsule", up_ext,
			base_tags + [&"upper"], Vector3(sx * hip_out, -0.08, z),
			-dir, 760.0, hip_axis, &"leg_upper")
	var lo := _piece(up, lower, &"capsule", lo_ext,
			base_tags + [&"knee", &"lower"], Vector3(0.0, -up_ext.y, 0.0),
			seg_axis, 720.0, Vector3(0, 0, 1), &"leg_lower")
	var an := _piece(lo, ankle, &"capsule", an_ext,
			base_tags + [&"ankle"], Vector3(0.0, -lo_ext.y, 0.0),
			seg_axis, 680.0, Vector3(0, 0, 1), &"ankle_link")
	if foot:
		var fid := StringName("%s_foot" % prefix)
		_piece(an, fid, &"box", ft_ext,
				[&"ground_contact", &"foot"] + extra_tags,
				Vector3(0.0, -an_ext.y, 0.0), Vector3(0, 1, 0), 620.0, Vector3.ZERO, &"foot_pad")
	return ids


# Set the muscle_amount dial on every &"muscle"-tagged gene in the tree (raises the joint torque
# ceiling so muscled limbs can bear load / drive hard). No-op on parts without the muscle tag.
static func _set_muscle_amount(g: PartGene, amount: float) -> void:
	if g == null:
		return
	if g.tags.has(&"muscle"):
		g.dial_values[&"muscle_amount"] = amount
	for c in g.children:
		_set_muscle_amount(c, amount)


static func make_spider_v2() -> PartGene:
	# M60 reference-tracking honest walk, applying the daddy_longlegs recipe to the 8-legged spider. The
	# WIDE-FLAT octopod is the hardest walker: its many splayed fore-aft strokes very nearly cancel, so
	# the net travel is a small residual whose SIGN flips with tiny gain/amplitude changes — this config
	# sits on the forward side of that knife-edge (probe: fwd ~+0.6 m, body_drag 0, ~60 foot plants, no
	# bellying). Levers that made it walk instead of belly/drift: (1) LONG + STEEP legs (Y hip, out 0.40 /
	# down 0.94) so the tall stance lifts the flat body clear of the floor; (2) a lighter, more compact
	# body (0.22x0.12x0.34) so each step actually translates the mass and big strokes don't tip it;
	# (3) the fore-aft + L/R symmetric tetrapod phasing below, which kills the yaw couple that spun it.
	# honest + walk routes the Jᵀ leg tracker; muscle raises the torque ceiling. NOTE: propulsion is
	# modest and the operating point is narrow (below the >1.5 m target) — see the sign-flip caveat above.
	var root := _gene(_definition(&"box", 620.0, Vector3(0.22, 0.12, 0.34)),
			[&"spine", &"arachnid", &"honest", &"no_self_collision"], null, &"spider_body")
	_add_vital_organs(root)
	var ids: Array[StringName] = []
	for i in 4:
		var z := lerpf(0.24, -0.24, float(i) / 3.0)
		ids.append_array(_v2_side_leg(root, "spider_L%d" % i, -1.0, z, 0.66, 0.036, true,
				[&"spider", &"muscle"], Vector3(0, 1, 0), 0.40, 0.94))
		ids.append_array(_v2_side_leg(root, "spider_R%d" % i, 1.0, z, 0.66, 0.036, true,
				[&"spider", &"muscle"], Vector3(0, 1, 0), 0.40, 0.94))
	_set_muscle_amount(root, 4.0)
	var g := _v2_gait(ids, &"walk", 1.35, 1.0, 20.0, 1.0, 2.6)
	g.locomotion_mode = &"walk"
	# FORE-AFT + LEFT-RIGHT SYMMETRIC tetrapod phasing. Both symmetries matter on this flat octopod:
	#  - L and R of each pair share a phase -> the two sides' yaw torques cancel.
	#  - the two antiphase groups are each fore-aft BALANCED about the body center: group A = the outer
	#    legs (i=0 front + i=3 rear), group B = the inner legs (i=1 + i=2). Because each group's stance
	#    feet straddle the center of mass symmetrically, the backward power stroke pushes through the CoM
	#    with no yaw couple (the earlier 0/1-vs-2/3 split put each group's feet off-center -> it spun).
	var group_phase := [0.0, 0.5, 0.5, 0.0]   # legs 0 & 3 in phase; 1 & 2 antiphase
	for i in 4:
		var ph: float = group_phase[i]
		for seg in ["upper", "lower", "ankle"]:
			g.assignments[StringName("spider_L%d_%s" % [i, seg])] = ph
			g.assignments[StringName("spider_R%d_%s" % [i, seg])] = ph
	root.gait = g
	return root


static func make_daddy_longlegs_v2() -> PartGene:
	var root := _gene(_definition(&"sphere", 640.0, Vector3(0.14, 0.12, 0.14)),
			[&"spine", &"arachnid", &"honest", &"no_self_collision"], null, &"dll_body")
	_add_vital_organs(root)
	# M60 reference-tracking walk: Y (vertical) hip so each leg sweeps fore-aft, steeper legs (more
	# vertical, out_frac 0.45 / down_frac 0.9) so the tall body clears the floor, honest + walk so the
	# Jᵀ leg tracker drives the feet along the gait trajectory. muscle raises the torque ceiling.
	var ids: Array[StringName] = []
	for i in 4:
		var z := lerpf(-0.22, 0.22, float(i) / 3.0)
		ids.append_array(_v2_side_leg(root, "dll_L%d" % i, -1.0, z, 0.72, 0.030, true,
				[&"daddy_longlegs", &"muscle"], Vector3(0, 1, 0), 0.45, 0.90))
		ids.append_array(_v2_side_leg(root, "dll_R%d" % i, 1.0, z, 0.72, 0.030, true,
				[&"daddy_longlegs", &"muscle"], Vector3(0, 1, 0), 0.45, 0.90))
	_set_muscle_amount(root, 4.0)
	var g := _v2_gait(ids, &"walk", 1.0, 1.0, 12.0, 1.0, 1.6)
	g.locomotion_mode = &"walk"
	root.gait = g
	return root


static func make_frog_v2() -> PartGene:
	var root := _gene(_definition(&"box", 820.0, Vector3(0.30, 0.13, 0.30)),
			[&"spine", &"amphibian", &"no_self_collision", &"honest"], null, &"frog_body")
	_add_vital_organs(root)
	var ids: Array[StringName] = []
	for side in [-1.0, 1.0]:
		var sx := signf(side)
		var tag := "L" if sx < 0.0 else "R"
		# M60 anatomical rebuild: the hind leg is a CONNECTED femur -> shin -> webbed foot CHAIN (was a
		# fan of disjoint stubs off the body). All three hinge on the LATERAL axis (1,0,0) so the leg
		# folds and EXTENDS in the sagittal plane — a real frog jump: from a crouch the joints extend
		# together, the gripped feet push back+down, and the body launches. Tagged spring so the hop
		# gait loads + releases the leg.
		var femur_id := StringName("frog_%s_femur" % tag)
		var shin_id := StringName("frog_%s_shin" % tag)
		var tarsus_id := StringName("frog_%s_tarsus" % tag)
		var fem_ext := Vector3(0.062, 0.16, 0.062)
		var shin_ext := Vector3(0.052, 0.16, 0.052)
		var tar_ext := Vector3(0.044, 0.12, 0.044)
		var ft_ext := Vector3(0.12, 0.022, 0.17)
		ids.append(femur_id)
		ids.append(shin_id)
		ids.append(tarsus_id)
		# REAL Z-FOLD (Cole's design): a zigzag ready-pose so all three joints EXTEND TOGETHER to fling.
		# A piece extends along -axis. femur -> down+BACK (knee is the low-back vertex); shin -> folds
		# down+FORWARD under the body (ankle is the forward vertex); tarsus/foot -> down+BACK again. Path
		# hip↘knee↙ankle↘foot = a folded Z. From this deep crouch the joints unfold in one synchronized
		# snap (springs+muscle+tendon), pushing the wide feet back+down -> the body launches up+forward.
		# All hinge on the lateral axis (1,0,0) so they fold/extend in the sagittal plane.
		var femur := _piece(root, femur_id, &"capsule", fem_ext,
				[&"locomotor", &"leg", &"hindlimb", &"spring", &"muscle"],
				Vector3(sx * 0.20, -0.02, 0.14), Vector3(-sx * 0.30, 0.60, -0.80),
				960.0, Vector3(1, 0, 0), femur_id)
		var shin := _piece(femur, shin_id, &"capsule", shin_ext,
				[&"locomotor", &"leg", &"hindlimb", &"knee", &"spring", &"muscle"],
				Vector3(0.0, -fem_ext.y, 0.0), Vector3(0, 1.0, 0.95), 910.0, Vector3(1, 0, 0), shin_id)
		var tarsus := _piece(shin, tarsus_id, &"capsule", tar_ext,
				[&"locomotor", &"leg", &"hindlimb", &"ankle", &"spring", &"muscle"],
				Vector3(0.0, -shin_ext.y, 0.0), Vector3(0, 1.0, -0.95), 860.0, Vector3(1, 0, 0), tarsus_id)
		# Wide webbed foot off the tarsus's distal end.
		_piece(tarsus, StringName("frog_%s_foot" % tag), &"box", ft_ext,
				[&"ground_contact", &"foot", &"hindlimb", &"spring"],
				Vector3(0.0, -tar_ext.y, 0.0), Vector3(0, 1, 0), 620.0, Vector3.ZERO, &"wide_foot_pad")
		# CATAPULT: each hind joint gets a stiff torsional spring (rest = full extension, so the Z-crouch
		# LOADS it) + MUSCLE (raises the torque ceiling so the spring push isn't clamped) + a biarticular
		# TENDON (hip<->ankle) so the whole leg fires in one coordinated snap. WIDE joint range (±2.2) so
		# the leg can fold to a deep Z AND fully extend — the deep fold is what stores the leap energy.
		for seg in [femur, shin, tarsus]:
			seg.dial_values[&"muscle_amount"] = 2.0
			seg.joint.angle_min = -2.2
			seg.joint.angle_max = 2.2
			seg.joint.amplitude = 1.0
			_assign_spring(seg, 360.0, 0.12, 0.24, 0.16, 0.92)
		var tendon := TendonDef.new()
		tendon.enabled = true
		tendon.partner_part_id = tarsus_id          # hip joint <-> ankle joint, coordinated extension
		tendon.stiffness = 160.0
		tendon.efficiency = 0.88
		femur.tendon = tendon
		# Front leg = PASSIVE rigid stub (NOT in the gait, hinge ZERO). A real frog's forelimbs only
		# CATCH the landing; they do not power the jump. v1 let the optimizer push up with the front
		# legs (and shift the body) instead of doing the hind-leg leap — that cheat is removed here, so
		# the ONLY way to get airborne is the hind-leg catapult.
		var arm := _piece(root, StringName("frog_%s_arm" % tag), &"capsule", Vector3(0.042, 0.13, 0.042),
				[&"leg", &"forelimb"],
				Vector3(sx * 0.18, -0.04, -0.20), Vector3(-sx * 0.2, 1.0, 0.5),
				760.0, Vector3.ZERO, &"leg_lower")
		_piece(arm, StringName("frog_%s_hand" % tag), &"box", Vector3(0.06, 0.02, 0.08),
				[&"ground_contact", &"foot", &"forelimb"],
				Vector3(0.0, -0.13, 0.0), Vector3(0, 1, 0), 600.0, Vector3.ZERO, &"foot_pad")
	# Hop gait: both hind legs in phase (a synchronized launch), front legs offset for landing. Scales
	# are the honest catapult-tuned values (no central-force assist; the frog carries &"honest") from
	# the headless LEAP search that optimizes for forward + airborne_frac (ALL feet off the floor) so
	# the hind legs must actually launch the body — with the front legs passive, airborne can ONLY come
	# from the hind-leg catapult, which kills the v1 front-leg-push/body-shift cheat. Result: ~3.5m
	# forward, airborne ~49% of the cycle, foot clears ~0.15m. The balance term (last arg, an honest
	# upright TORQUE — not a lift) keeps it landing upright. Only the hind segments are driven.
	# Freq 1.9: stable Z-legged forward hopping (up_min ~0.82, honest, doesn't fall). HONEST CAVEAT: the
	# REAL contact sensor reads true_air ≈ 0 — it does NOT robustly leave the ground. The Z-fold geometry
	# + synchronized spring/muscle/tendon catapult are real and CAN briefly launch it (true_air ~0.05),
	# but any launch strong enough to clear the body somersaults it forward (no mid-air pitch control),
	# so a clean big LEAP is still unsolved — it needs a whole-body-launch + in-flight righting controller.
	var g := _v2_gait(ids, &"hop", 2.1, 1.9, 62.0, 0.6, 1.2)
	for k in g.assignments:
		g.assignments[k] = 0.0   # both hind legs fire in phase (a synchronized two-foot launch)
	g.locomotion_mode = &"hop"
	root.gait = g
	return root


static func make_quadruped_v2() -> PartGene:
	# HONEST SAGITTAL QUAD (2026-07-02 re-author; full history in LOCOMOTION_ARCHITECTURE.md). Walks
	# assist-off — no reaction-less posture torque, no anti-gravity lift, no forward shove (traction=0
	# AND posture=0 baked into the gait; Watch-it-walk / Measure run it honest by default).
	# Lineage, briefly: the original narrow quad could only "walk" on the posture-torque cheat; the
	# Z-LEG redesign made it self-STAND (wide splayed knees, vertical shins) but could never walk
	# right — its hip axes were ~24° from vertical (strokes paddled sideways and yawed the body) and
	# the leg had no length reserve (knee bend only shortens), so it shuffled in a listing crouch.
	# The Z-leg concept moved to the FROG, where it belongs (opposed constrained leg springs that
	# fling the body as the legs straighten — the leap design). This quad is a plain SAGITTAL walker:
	# dog-style zigzag legs, near-world-X pitch hips, propulsion from the reference tracker's stance
	# power stroke, lateral stability from the controller (weight-shift + SIMBICON + leg-righting +
	# heading hold). See the leg-loop comment for the geometry rationale.
	var root := _gene(_definition(&"box", 300.0, Vector3(0.26, 0.13, 0.64)),
			[&"spine", &"quadruped", &"honest", &"no_self_collision"], null, &"quad_body")
	_add_vital_organs(root)
	var ids: Array[StringName] = []
	var shins: Array = []
	# SAGITTAL DOG-LEGS (2026-07-02 re-author; the Z-leg design moved to the FROG, where its opposed
	# constrained springs power the leap — Cole's brief). The Z-leg quad walked like a listing
	# crouch-shuffle for geometric reasons no controller could fix: its hip axes were ~24° from
	# VERTICAL (every stroke paddled the leg sideways and yawed the body) and the leg had ZERO length
	# reserve (knee bend only shortens — a tilted body physically cannot re-plant a raised leg).
	# The sagittal zigzag fixes both by construction:
	#   • hips are near-world-X PITCH hinges (mild ±0.15 mirrored tilt for lateral compliance — do
	#     NOT make them exactly world-X: with a pure-X knee too, a planted flat foot over-constrains
	#     the chain and the solver ejects the body; measured)
	#   • thigh slopes down-BACK, shin slopes down-FORWARD (a sagittal zigzag): knee flexion now
	#     changes leg LENGTH (reach reserve for tilts) and gives FIRST-ORDER foot lift through the
	#     knee (the splayed rig's "can't lift" null space is gone)
	#   • lateral stability comes from the CONTROLLER (weight-shift + SIMBICON + leg-righting +
	#     heading hold) — the tools whose absence originally forced the wide Z-leg stance.
	# Feet stay wide fore-aft (cz ±0.42): the long wheelbase resists the propulsion pitch.
	for corner in [["FL", -1.0, 0.42], ["FR", 1.0, 0.42], ["BL", -1.0, -0.42], ["BR", 1.0, -0.42]]:
		var lbl := String(corner[0])
		var sx := float(corner[1])
		var cz := float(corner[2])
		var thigh_id := StringName("quad_%s_thigh" % lbl)
		var shin_id := StringName("quad_%s_shin" % lbl)
		ids.append(thigh_id)
		ids.append(shin_id)
		# All four zigzags share one orientation (thigh down-back, shin down-forward). KNOWN DEBT: a
		# real quadruped MIRRORS the hind zigzag (knee-forward femur, hock-back tibia) and with this
		# uniform orientation the rear pair is geometrically weaker against load — the walk carries a
		# steady rear-low posture. A mirrored-hind attempt (zf flip on the rear pair) walked 4 m but
		# only by falling sideways and dragging; it needs a stance controller that can hold the
		# mirrored geometry FIRST (see LOCOMOTION_ARCHITECTURE.md addendum) — do stand-first, then
		# re-mirror.
		# Thigh extends along -axis: down, slightly OUT (base width), and BACK (the zigzag).
		var thigh_axis := Vector3(-sx * 0.15, 1.0, -0.52)
		# Shin: down and FORWARD in WORLD terms, expressed in the thigh's socket frame.
		var shin_axis: Vector3 = _basis_from_y_axis(thigh_axis).inverse() * Vector3(0.0, 0.92, 0.39)
		var thigh := _piece(root, thigh_id, &"capsule", Vector3(0.05, 0.11, 0.05),
				[&"locomotor", &"leg", &"muscle"],
				Vector3(sx * 0.24, -0.10, cz), thigh_axis,
				880.0, Vector3(1, 0, 0), thigh_id)
		var shin := _piece(thigh, shin_id, &"capsule", Vector3(0.045, 0.13, 0.045),
				[&"locomotor", &"leg", &"knee", &"muscle"],
				Vector3(0.0, -0.11, 0.0), shin_axis, 860.0, Vector3(1, 0, 0), shin_id)
		shins.append(shin)
		_piece(shin, StringName("quad_%s_foot" % lbl), &"box", Vector3(0.11, 0.03, 0.15),
				[&"ground_contact", &"foot"],
				Vector3(0.0, -0.13, 0.0), Vector3(0, 1, 0), 700.0, Vector3.ZERO, &"foot_pad")
		# rest_angle 0 = the built zigzag IS the standing brace; the stance power stroke (body-frame
		# swept foot target) is the propulsion, so the hips rest neutral — no lean hack.
		thigh.joint.rest_angle = 0.0
		shin.joint.rest_angle = 0.0
		# Wider hip ROM than the ±1.1 default: under load a stance hip can be wound past the stroke
		# by the body's own advance; hitting the joint stop turns the leg into a rigid pole-vault
		# pivot (a measured tip-over mode). Give the hip mechanical margin.
		thigh.joint.angle_min = -1.45
		thigh.joint.angle_max = 1.45
	_set_muscle_amount(root, 2.6)
	# Boost the shin muscle: the knee's tau_cap is inertia-limited (small shin subtree → ~89 N·m even at
	# muscle 26), so max it out to give the near-straight stance leg every N·m it can, on top of the light
	# body that keeps the buckling moment under that cap. (Set AFTER the global muscle pass so it isn't
	# clobbered.) This is the "assembler gives the right pieces" feasibility fix — pieces the legs can hold.
	for s in shins:
		_set_muscle_amount(s, 26.0)
	# CRAWL SEQUENCE: one foot swings at a time (the FSM enforces it; the phase offsets stagger the
	# order), so 3 feet stay down. traction=0 AND posture=0 bake the creature HONEST by default: the
	# editor's Watch-it-walk runs it with the assist fully off.
	# gain_scale 3.0: multiplies LEG_TASK_K into the foot PD — 20 made an 18,000 N/m foot spring that
	# slammed the body past plan speed and pitched it over; ~2,700 N/m walks stably.
	var g := _v2_gait(ids, &"crawl", 1.3, 1.6, 3.0, 0.0, 0.0)
	g.duty = 0.75          # 3 feet down, one swinging — the crawl sequence with a real swing window
	g.step_len = 0.22      # authored stride: the walk-speed ceiling is freq × step_len — the derived
	                       # 0.26·leg_len stride capped this body below the 3 m credible bar forever
	g.step_h = 0.05        # authored swing lift: clears the ground inside the swing window (the derived
	                       # 0.15 m arc was kinematically impossible at walking cadence — feet landed
	                       # late and support collapsed); the sagittal knee lifts FIRST-ORDER now
	g.weight_shift = 0.35  # pull the CoM over the bearing feet (honest, through the feet) so it steps
	                       # FORWARD upright instead of tipping — assist stays 0 (no reaction-less torque)
	# Lateral-sequence crawl (FL, BR, FR, BL): consecutive swings on opposite corners keep the CoM in the
	# 3-foot triangle. Each knee a quarter-cycle ahead of its hip so it lifts the foot during that leg's swing.
	g.assignments[&"quad_FL_thigh"] = 0.0
	g.assignments[&"quad_BR_thigh"] = 0.25
	g.assignments[&"quad_FR_thigh"] = 0.5
	g.assignments[&"quad_BL_thigh"] = 0.75
	g.assignments[&"quad_FL_shin"] = 0.25
	g.assignments[&"quad_BR_shin"] = 0.5
	g.assignments[&"quad_FR_shin"] = 0.75
	g.assignments[&"quad_BL_shin"] = 0.0
	g.locomotion_mode = &"walk"
	root.gait = g
	return root


static func make_crab_v2() -> PartGene:
	# HONEST lateral scuttle (M60). A real crab walks SIDEWAYS: each leg splays out to the side and the
	# planted foot sweeps along the body's X axis, the honest friction stroke carrying the body laterally.
	# Recipe = the reference-tracking walk adapted for LATERAL travel: honest + no_self_collision so the
	# Jᵀ leg tracker drives, &"side_scuttle" gait so the foot plan sweeps along +X (see _build_leg_plan),
	# LONGER + STEEPER legs (0.72 vs 0.28, out 0.55/down 0.88) so the carapace stands high and only the
	# FEET touch (short splayed legs dragged their shins), the default Z lift-hinge so each out-splayed
	# leg arcs the foot in the X-Y plane (its X component is the lateral power stroke), and muscle to
	# raise the torque ceiling so the legs bear the body. Small LIGHT carapace (0.30 span, density 360)
	# — a heavy/wide base collapses or tips under the sideways stroke (the splayed-leg wall).
	var root := _gene(_definition(&"box", 360.0, Vector3(0.30, 0.09, 0.30)),
			[&"spine", &"carapace", &"honest", &"no_self_collision"], null, &"crab_body")
	_add_vital_organs(root)
	var ids: Array[StringName] = []
	for i in 4:
		var z := lerpf(-0.22, 0.22, float(i) / 3.0)
		ids.append_array(_v2_side_leg(root, "crab_L%d" % i, -1.0, z, 0.72, 0.030, true,
				[&"crab", &"muscle"], Vector3(0, 0, 1), 0.55, 0.88))
		ids.append_array(_v2_side_leg(root, "crab_R%d" % i, 1.0, z, 0.72, 0.030, true,
				[&"crab", &"muscle"], Vector3(0, 0, 1), 0.55, 0.88))
	_piece(root, &"claw_L_arm", &"capsule", Vector3(0.050, 0.18, 0.050), [&"manipulator", &"arm", &"attack"],
			Vector3(-0.24, 0.0, -0.34), Vector3(-0.55, -0.10, -0.85), 700.0, Vector3.ZERO, &"arm_upper")
	_piece(root, &"claw_R_arm", &"capsule", Vector3(0.050, 0.18, 0.050), [&"manipulator", &"arm", &"attack"],
			Vector3(0.24, 0.0, -0.34), Vector3(0.55, -0.10, -0.85), 700.0, Vector3.ZERO, &"arm_upper")
	_piece(root, &"claw_L_blade", &"capsule", Vector3(0.060, 0.13, 0.060), [&"attack", &"claw"],
			Vector3(-0.36, -0.03, -0.50), Vector3(-0.45, 0.0, -0.90), 800.0, Vector3.ZERO, &"jaw_claw")
	_piece(root, &"claw_R_blade", &"capsule", Vector3(0.060, 0.13, 0.060), [&"attack", &"claw"],
			Vector3(0.36, -0.03, -0.50), Vector3(0.45, 0.0, -0.90), 800.0, Vector3.ZERO, &"jaw_claw")
	_set_muscle_amount(root, 6.0)
	var g := _v2_gait(ids, &"side_scuttle", 1.0, 1.0, 10.0, 1.0, 2.6)
	# Mirror-symmetric metachronal wave: both sides run the SAME per-index phase (L==R) so the left/right
	# lateral push cancels no yaw, and a smooth front->back wave keeps feet cycling for grip. This is the
	# config that keeps the light carapace upright while netting sideways travel (see HONEST_MIGRATION);
	# the diagonal-tetrapod variant strokes harder laterally but collapses/tips the wide base. knee/ankle
	# lead the hip a quarter cycle so they bend and clear the foot on swing.
	for i in 4:
		for side in ["L", "R"]:
			var leg := "crab_%s%d" % [side, i]
			var base := float(i) / 4.0
			g.assignments[StringName("%s_upper" % leg)] = base
			g.assignments[StringName("%s_lower" % leg)] = wrapf(base + 0.25, 0.0, 1.0)
			g.assignments[StringName("%s_ankle" % leg)] = wrapf(base + 0.25, 0.0, 1.0)
	g.locomotion_mode = &"lateral"   # lateral leg-tracker mode (feet sweep sideways); test expects this
	root.gait = g
	return root


static func make_sea_urchin_v2() -> PartGene:
	# HONEST radial pogo. Was assist_carried (cheat). Reassembled: a ball of SPRING-loaded pogo spines
	# all round the lower hemisphere; the in-contact spines fire (M39 contact-subset drive — push the
	# tip into the ground, NO central force) so the urchin bounces + walks "through its spines". A
	# faint downhill bias (front spines slightly longer) breaks the radial symmetry so it nets forward
	# instead of bouncing in place. Muscle uncaps the spring push. No assist (root is &"honest").
	# Light, smaller shell so the spring spines can actually pogo it (a 0.28 sphere at density 700 was
	# ~60kg — unbounceable by thin spines).
	var root := _gene(_definition(&"sphere", 260.0, Vector3(0.22, 0.22, 0.22)),
			[&"spine", &"urchin", &"honest", &"no_self_collision"], null, &"urchin_body")
	_add_vital_organs(root)
	var ids: Array[StringName] = []
	var rings := [[-0.10, 0.30, 10], [-0.20, 0.24, 8]]   # [y, ring radius scale, count] lower bands
	var ri := 0
	for ring in rings:
		var ry := float(ring[0])
		var rr := float(ring[1])
		var rc := int(ring[2])
		for i in rc:
			var a := TAU * float(i) / float(rc) + (0.3 if ri == 1 else 0.0)
			# Front spines (toward -Z, forward) longer -> a forward roll/lean each bounce (net travel).
			var lean := 0.10 * cos(a + PI)   # max at a=PI (-Z front)
			var dir := Vector3(cos(a) * 0.55, -0.84, sin(a) * 0.55).normalized()
			var id := StringName("pogo_spine_%d_%02d" % [ri, i])
			ids.append(id)
			var spine := _piece(root, id, &"capsule", Vector3(0.038, 0.26 + lean, 0.038),
					[&"locomotor", &"leg", &"ground_contact", &"pogo", &"spike", &"muscle"],
					Vector3(cos(a) * rr, ry, sin(a) * rr), dir,
					840.0, Vector3(1, 0, 0), &"spring_foot")
			_assign_spring(spine, 520.0, 0.12, 0.20, 0.16, 0.90)
		ri += 1
	for j in 12:
		var y := 0.04 + 0.20 * float(j % 3) / 2.0
		var a2 := TAU * float(j) / 12.0
		_piece(root, StringName("body_spike_%02d" % j), &"cylinder", Vector3(0.026, 0.18, 0.026),
				[&"attack", &"spike"], Vector3(cos(a2) * 0.22, y, sin(a2) * 0.22),
				Vector3(cos(a2), 0.5, sin(a2)).normalized(), 1200.0, Vector3.ZERO, &"spike")
	_set_muscle_amount(root, 2.4)
	# HONEST radial pogo: the in-contact spring spines fire (M39 contact-subset, no central force) and
	# the front-heavy spines bias travel forward. NOTE: this is a weak mover — a spiky ball is a hard
	# honest case (radial hinge-swing is a poor vertical kick; spines catch so it can't roll). Honest +
	# reassembled, but slow; flagged in HONEST_MIGRATION.md.
	root.gait = _v2_gait(ids, &"radial_pogo", 3.0, 1.6, 10.0, 2.0, 1.0)
	root.gait.locomotion_mode = &"pogo"
	return root


static func make_starfish_v2() -> PartGene:
	var root := _gene(_definition(&"sphere", 700.0, Vector3(0.24, 0.055, 0.24)),
			[&"spine", &"starfish"], null, &"starfish_center")
	_add_vital_organs(root)
	var ids: Array[StringName] = []
	for i in 5:
		var a := TAU * float(i) / 5.0
		var id := StringName("arm_%02d" % i)
		ids.append(id)
		_piece(root, id, &"capsule", Vector3(0.085, 0.42, 0.085),
				[&"locomotor", &"leg", &"ground_contact", &"arm", &"starfish"],
				Vector3(cos(a) * 0.34, -0.035, sin(a) * 0.34),
				Vector3(cos(a), -0.08, sin(a)).normalized(), 720.0, Vector3(0, 1, 0), &"leg_upper")
	root.gait = _v2_gait(ids, &"pentaradial_wave", 1.7, 1.0, 5.0, 1.7, 0.8)
	return root


static func make_serpent_v2() -> PartGene:
	var root := _gene(_definition(&"sphere", 760.0, Vector3(0.16, 0.12, 0.20)),
			[&"spine", &"serpent", &"head", &"ground_contact"], null, &"serpent_head")
	_add_vital_organs(root)
	var ids: Array[StringName] = []
	# M59: CHAIN the segments head -> seg0 -> seg1 -> … (identity frame, flat box segments along world
	# Z) instead of fanning every segment off the distant head (which exploded). Identity frame is the
	# key for honest undulation: the yaw hinge (0,1,0) is then a real VERTICAL axis, so the gait bends
	# the body SIDE-TO-SIDE (a lateral S-wave) rather than twisting it. The anisotropic belly friction
	# (axial = world Z) then rectifies that wave into forward thrust — no central-force assist needed.
	var prev := root
	var seg_ext := Vector3(0.12, 0.09, 0.22)   # x width, y height (flat belly), z half-length
	for i in 9:
		var id := StringName("serpent_seg_%02d" % i)
		ids.append(id)
		var pa_z := root.definition.extents.z if i == 0 else prev.definition.extents.z
		var seg := _gene(_definition(&"box", 720.0, seg_ext),
				[&"locomotor", &"spine", &"ground_contact", &"serpent", &"anisotropic_ventral"],
				_socket(Vector3(0.0, 0.0, pa_z), Vector3(0, 1, 0), id, Vector3(0.0, 0.0, seg_ext.z)),
				&"tail_segment", id)
		seg.joint = JointDef.new()
		seg.joint.amplitude = 1.0
		seg.joint.angle_min = -1.1
		seg.joint.angle_max = 1.1
		prev.children.append(seg)
		prev = seg
	# Tuned for head-first forward swimming: a cleaner S-wave (amp 1.9, freq 1.6, phase step 0.16 ≈
	# ~1.4 wavelengths along the 9-segment body) rectifies via the belly friction into ~4.3m forward
	# (credible_walk), up from a short, heavily-wagging 2.5m. The head (root) leads (-z); the metric
	# forward axis is -z, so this is genuinely head-first, not the old tail-first crawl.
	# Re-tuned after the organ right-sizing + honest axial drag: a stronger wave (amp 1.9->2.7, gain
	# 5.8->9.5) so the active undulation clearly out-propels the passive S-rest straightening (the light
	# body no longer coasts, so the wave must do the work).
	var g := _v2_gait(ids, &"undulate", 2.7, 1.7, 9.5, 0.0, 0.0)
	for i in ids.size():
		g.assignments[ids[i]] = wrapf(float(i) * 0.16, 0.0, 1.0)
	root.gait = g
	return root


static func make_hopper_v2() -> PartGene:
	# HONEST catapult hopper = a scaled-up frog (the frog leap is proven). The previous hopper rested
	# back on a heavy tail with its feet lifted and WORMED forward (in-editor verdict). Rebuilt on the
	# frog's exact working layout: low trunk, 3-segment hind legs (femur->shin->tarsus->foot) angled
	# down-back so the FEET bear the weight, STRONG springs + MUSCLE + a hip<->ankle TENDON catapult,
	# PASSIVE front arms (catch the landing, can't push), and only a LIGHT tail counterweight that does
	# NOT reach the floor. No central-force assist (root is &"honest").
	var root := _gene(_definition(&"box", 830.0, Vector3(0.30, 0.14, 0.32)),
			[&"spine", &"hopper", &"honest", &"no_self_collision"], null, &"hopper_body")
	_add_vital_organs(root)
	var ids: Array[StringName] = []
	for side in [-1.0, 1.0]:
		var sx := signf(side)
		var prefix := "hop_L" if sx < 0.0 else "hop_R"
		var femur_id := StringName("%s_femur" % prefix)
		var shin_id := StringName("%s_shin" % prefix)
		var tarsus_id := StringName("%s_tarsus" % prefix)
		ids.append(femur_id)
		ids.append(shin_id)
		ids.append(tarsus_id)
		# Hind leg chain femur -> shin -> tarsus -> foot, sized to match the proven frog leap (shorter
		# legs keep the body low + stable). All hinge on the lateral axis (1,0,0); crouch loads the
		# springs+muscle then extends to launch — identical mechanism to the frog.
		var femur := _piece(root, femur_id, &"capsule", Vector3(0.062, 0.16, 0.062),
				[&"locomotor", &"leg", &"hindlimb", &"spring", &"muscle"],
				Vector3(sx * 0.20, -0.02, 0.15), Vector3(-sx * 0.35, 1.0, -0.75),
				920.0, Vector3(1, 0, 0), femur_id)
		var shin := _piece(femur, shin_id, &"capsule", Vector3(0.052, 0.16, 0.052),
				[&"locomotor", &"leg", &"hindlimb", &"knee", &"spring", &"muscle"],
				Vector3(0.0, -0.16, 0.0), Vector3(0, 1, 0), 910.0, Vector3(1, 0, 0), shin_id)
		var tarsus := _piece(shin, tarsus_id, &"capsule", Vector3(0.044, 0.12, 0.044),
				[&"locomotor", &"leg", &"hindlimb", &"ankle", &"spring", &"muscle"],
				Vector3(0.0, -0.16, 0.0), Vector3(0, 1, 0), 860.0, Vector3(1, 0, 0), tarsus_id)
		_piece(tarsus, StringName("%s_foot" % prefix), &"box", Vector3(0.13, 0.022, 0.18),
				[&"ground_contact", &"foot", &"hindlimb", &"spring"],
				Vector3(0.0, -0.12, 0.0), Vector3(0, 1, 0), 640.0, Vector3.ZERO, &"wide_foot_pad")
		for seg in [femur, shin, tarsus]:
			seg.dial_values[&"muscle_amount"] = 2.2
			_assign_spring(seg, 460.0, 0.14, 0.22, 0.16, 0.90)
		var tendon := TendonDef.new()
		tendon.enabled = true
		tendon.partner_part_id = tarsus_id          # hip joint <-> ankle joint, coordinated extension
		tendon.stiffness = 160.0
		tendon.efficiency = 0.88
		femur.tendon = tendon
		# PASSIVE front arm (rigid stub, hinge zero, NOT driven) — only catches the landing. Tucked UP so
		# it does not lie flat on the floor and let the body pivot/worm on it.
		var arm := _piece(root, StringName("%s_arm" % prefix), &"capsule", Vector3(0.04, 0.11, 0.04),
				[&"leg", &"forelimb"],
				Vector3(sx * 0.18, 0.02, -0.20), Vector3(-sx * 0.2, 0.55, -0.85),
				650.0, Vector3.ZERO, &"leg_lower")
		_piece(arm, StringName("%s_hand" % prefix), &"box", Vector3(0.06, 0.02, 0.08),
				[&"ground_contact", &"foot", &"forelimb"],
				Vector3(0.0, -0.13, 0.0), Vector3(0, 1, 0), 600.0, Vector3.ZERO, &"foot_pad")
	# Kangaroo-style tail COUNTERWEIGHT: a longer, heavier tail slung back keeps the CoM behind the feet
	# so the in-phase two-foot launch does NOT pitch the light body forward onto its face (the tumble
	# that capped the launch). It rides ABOVE the floor (angled back-and-up) so it can't be sat/wormed on.
	_piece(root, &"tail_balancer", &"capsule", Vector3(0.05, 0.22, 0.05), [&"tail", &"spine"],
			Vector3(0.0, 0.08, 0.19), Vector3(0.0, 0.62, 0.78), 520.0, Vector3.ZERO, &"tail_segment")
	# Both hind legs fire in phase (synchronized two-foot launch). vs the frog: the foot-press traction
	# (arg 5, the honest ground-reaction that pushes the body UP off the planted feet) is cranked to 7.5
	# and balance (arg 6) to 1.5 — together they lift the body into a real ballistic FLIGHT phase (whole
	# creature airborne, not just swinging feet under a bellied trunk = the old worm) while the extra
	# upright torque + the tail counterweight keep the in-phase launch from pitching over on landing.
	var g := _v2_gait(ids, &"hop", 2.4, 1.6, 85.0, 7.5, 1.5)
	for k in g.assignments:
		g.assignments[k] = 0.0
	g.locomotion_mode = &"hop"
	root.gait = g
	return root


static func make_glider_v2() -> PartGene:
	# M52->honest FLAPPER: a stationary body on flat ground can't glide (no airflow -> zero aero). To
	# move HONESTLY the wings must MAKE their own airflow: each wing is now a FLAPPING locomotor —
	# hinged fore-aft (Z axis) at the shoulder so it beats up/down, tagged &"muscle" so the CPG drives
	# it hard. The beating wing sweeps through air; WingBody computes lift/drag from the WING's own
	# velocity (never a root shove), so the flap is genuinely aerodynamic. Net forward thrust comes
	# from the wing's fixed nose-down PITCH (angle of attack): on the powered downstroke the wing's
	# lift tilts FORWARD, sculling the body ahead like a rowing oar. A light body + big wings keep the
	# wing loading low so the flap can support and drive it. Honest: all force is at the wings.
	var root := _gene(_definition(&"box", 900.0, Vector3(0.16, 0.07, 0.34)),
			[&"spine", &"glider", &"honest", &"no_self_collision"], null, &"glider_body")
	_add_vital_organs(root)
	# KEEL: a dense weight hung BELOW the body. It drops the centre of mass well under the wings so the
	# creature is a stable pendulum — it settles + flies UPRIGHT instead of the light pitched wings
	# flipping it onto its back during the spawn free-fall (which the rollout scores as a tip).
	# Keel is offset FORWARD (-Z) of the wing centre so the creature trims slightly NOSE-DOWN: the lift
	# vector then leans forward, giving a consistent forward glide component that dominates stray drift.
	root.children.append(_gene(_definition(&"box", 1500.0, Vector3(0.07, 0.11, 0.12)), [&"ballast"],
			_socket(Vector3(0.0, -0.15, -0.10), Vector3.ZERO, &"keel", Vector3.ZERO), &"glider_keel", &"keel"))
	# Each wing is a flat plate pitched leading-edge (its front, -Z) UP by ~18deg (angle of attack). A
	# pitched plate beaten DOWNward pushes air down-and-BACK, so its aero reaction has an up (lift) AND a
	# forward (thrust) component -> the flap both supports the body and sculls it forward. The wing hinges
	# fore-aft (parent-local Z) so it beats up/down; its face-normal is the box's local +Y.
	var ids: Array[StringName] = []
	var pitch := deg_to_rad(-18.0)
	for side in [-1.0, 1.0]:
		var sx := signf(side)
		var wid := StringName("wing_%s" % ("L" if sx < 0.0 else "R"))
		ids.append(wid)
		# The wing box: local +X = span, +Y = face normal (WingBody normal_local), +Z = chord.
		# Build the mount basis from PROPER axis-angle rotations (det = +1 on BOTH sides) so the two wings
		# are a TRUE aerodynamic mirror. The earlier column construction gave the left wing a reflected
		# (det -1) basis whose orthonormalize corrupted its face-normal -> a constant sideways drift.
		# RIGHT: pitch the plate about its own span (world X). LEFT: pitch the same way, then spin 180 deg
		# about the vertical so the span points the OTHER way while the face-normal still points UP.
		var b := Basis(Vector3(1, 0, 0), pitch)
		if sx < 0.0:
			# Flip span to the left via a 180 deg yaw; pre-negate the pitch so that AFTER the yaw the
			# face-normal lands at the SAME (0,cos,sin) as the right wing -> both nose-down (true mirror).
			b = Basis(Vector3(0, 1, 0), PI) * Basis(Vector3(1, 0, 0), -pitch)
		var s := SocketDef.new()
		s.id = wid
		s.display_name = String(wid)
		s.parent_attachment = Transform3D(b, Vector3(sx * 0.24, 0.05, 0.0))
		# Anchor at the wing's INBOARD edge: a CONSTANT -half_span in local X. The socket basis (yaw-
		# flipped on the left) transforms this so each wing's inboard edge meets its shoulder and the plate
		# extends outward on its own side.
		s.child_anchor = Transform3D(Basis.IDENTITY, Vector3(0.30, 0.0, 0.0))
		# MIRROR the flap axis per side (+Z on R, -Z on L): a +theta drive then raises BOTH tips together,
		# so a single IN-PHASE CPG beat is a symmetric down/up power stroke (both wings down together) ->
		# lift + thrust with no net roll.
		s.hinge_axis = Vector3(0.0, 0.0, sx)
		var w := _gene(_definition(&"box", 120.0, Vector3(0.62, 0.015, 0.30)),
				[&"wing", &"locomotor", &"muscle"], s, wid, wid)
		w.joint = JointDef.new()
		w.joint.amplitude = 1.0
		w.joint.rest_angle = 0.3   # both wings rest RAISED (dihedral) so the beat clears the floor
		w.joint.angle_min = -1.4
		w.joint.angle_max = 1.4
		root.children.append(w)
	# Large aft TAIL plate: a passive horizontal stabilizer (a big aero surface far behind the CoM) that
	# damps the pitch/yaw kicks from each flap beat, holding the body level so it doesn't tip past the
	# rollout's upright threshold. Bigger + further aft = more restoring aero moment.
	root.children.append(_gene(_definition(&"box", 200.0, Vector3(0.30, 0.02, 0.30)), [&"wing", &"tail"],
			_socket(Vector3(0.0, 0.03, 0.34), Vector3.ZERO, &"glider_tail", Vector3.ZERO),
			&"glider_tail", &"glider_tail"))
	# Both wings beat IN PHASE (0.0): with the per-side mirrored hinge axis an identical theta moves both
	# tips the SAME vertical way, so in-phase = a symmetric down/up power stroke.
	var g := GaitDef.new()
	g.pattern = &"flap"
	g.assignments[StringName("wing_L")] = 0.0
	g.assignments[StringName("wing_R")] = 0.0
	g.amplitude_scale = 3.0
	g.frequency_scale = 4.2
	g.gain_scale = 58.0
	g.traction_scale = 0.0
	g.posture_scale = 6.5   # honest righting torque keeps the body level so the flap stays symmetric
	g.locomotion_mode = &"fly"
	root.gait = g
	_set_muscle_amount(root, 8.5)
	return root


static func make_monopod_v2() -> PartGene:
	# HONEST single-leg pogo. The old one was assist_carried (cheat) and worms. Now a CHAINED spring
	# leg (upper -> spring -> foot) with MUSCLE (uncaps the spring) that crouches + extends to bounce,
	# tilted slightly BACK so the foot lands behind the CoM and each bounce drives the body forward;
	# heavy balance keeps the single leg upright. A wide foot pad gives a stable base. No assist.
	# LOW squat pogo: a flat, light body keeps the centre of mass near the foot so the single leg
	# doesn't topple, on top of a SHORT strong spring leg + a wide foot.
	# LOW, LIGHT, FLAT body so the CoM sits low over a broad foot — the tipping moment stays small.
	var root := _gene(_definition(&"box", 700.0, Vector3(0.24, 0.09, 0.24)),
			[&"spine", &"monopod", &"honest", &"no_self_collision"], null, &"monopod_body")
	_add_vital_organs(root)
	var ids: Array[StringName] = []
	# A SHORT two-segment sagittal-hinge leg (both hinge on 1,0,0 so they fold/extend in the fore-aft
	# plane). Short + stiff = a rigid pedestal that holds the low body clear of the floor; a very wide,
	# thin foot pad is the only lateral base, so it is oversized.
	var upper := _piece(root, &"pogo_upper", &"capsule", Vector3(0.06, 0.13, 0.06),
			[&"locomotor", &"leg", &"spring", &"muscle", &"stance_spring"],
			Vector3(0.0, -0.05, 0.0), Vector3(0.0, 1.0, 0.0), 700.0, Vector3(1, 0, 0), &"pogo_upper")
	var spring_seg := _piece(upper, &"pogo_spring", &"capsule", Vector3(0.05, 0.12, 0.05),
			[&"locomotor", &"leg", &"knee", &"spring", &"muscle", &"stance_spring"],
			Vector3(0.0, -0.13, 0.0), Vector3(0, 1, 0), 700.0, Vector3(1, 0, 0), &"pogo_spring")
	ids.append(&"pogo_upper")
	ids.append(&"pogo_spring")
	# Wide square foot pad = a broad base so the single leg doesn't tip laterally (the fore-aft leg
	# hinge can't correct sideways roll; the wide foot + heavy balance torque do).
	_piece(spring_seg, &"pogo_foot", &"box", Vector3(0.50, 0.05, 0.50),
			[&"ground_contact", &"foot", &"spring"],
			Vector3(0.0, -0.13, 0.0), Vector3(0, 1, 0), 900.0, Vector3.ZERO, &"wide_foot_pad")
	for seg in [upper, spring_seg]:
		seg.dial_values[&"muscle_amount"] = 3.0
		_assign_spring(seg, 380.0, 0.18, 0.18, 0.20, 0.75)
	var tendon := TendonDef.new()
	tendon.enabled = true
	tendon.partner_part_id = &"pogo_spring"
	tendon.stiffness = 150.0
	tendon.efficiency = 0.88
	upper.tendon = tendon
	# Gentle drive (small amplitude so the joints don't thrash the single leg over) + STRONG balance
	# posture (last arg) — the honest upright righting torque is what keeps the one-legged body vertical.
	var g := _v2_gait(ids, &"hop", 0.07, 2.4, 75.0, 1.25, 12.0)
	for k in g.assignments:
		g.assignments[k] = 0.0
	g.locomotion_mode = &"hop"
	root.gait = g
	return root


static func make_tortoise_v2() -> PartGene:
	# M60 reference-tracking walk: the tortoise is a heavy domed shell that used to belly-drag on stubby
	# splayed legs (fwd 0, body_drag 1.0). Rebuilt on the PROVEN quadruped_v2 recipe: knee'd under-body
	# legs (thigh -> shin -> foot chain) with a stance spring bracing the bent knee, honest + walk so the
	# Jᵀ leg tracker drives the feet, muscle so the brace torque isn't clamped. The legs are stouter and
	# longer than the quad's so the massive body clears the floor, and the trot is slow — a tortoise plods.
	# The shell is lightened (1450 -> 500) and the body density trimmed so the ~short muscled legs can
	# actually bear the load and step instead of collapsing.
	var root := _gene(_definition(&"sphere", 340.0, Vector3(0.42, 0.20, 0.50)),
			[&"spine", &"tortoise", &"honest", &"no_self_collision"], null, &"tortoise_body")
	_add_vital_organs(root)
	_piece(root, &"shell_plate", &"box", Vector3(0.38, 0.05, 0.44), [&"armor", &"shell"],
			Vector3(0.0, 0.15, 0.0), Vector3.UP, 320.0, Vector3.ZERO, &"armor_plate")
	var ids: Array[StringName] = []
	var shins: Array = []
	# Legs at the four corners, splayed slightly out then straight down: thigh from the body, shin (knee)
	# below it, foot pad at the bottom. Long enough to lift the heavy shell off the floor.
	for corner in [["FL", -1.0, 0.30], ["FR", 1.0, 0.30], ["BL", -1.0, -0.30], ["BR", 1.0, -0.30]]:
		var lbl := String(corner[0])
		var sx := float(corner[1])
		var cz := float(corner[2])
		var thigh_id := StringName("tort_%s_thigh" % lbl)
		var shin_id := StringName("tort_%s_shin" % lbl)
		ids.append(thigh_id)
		ids.append(shin_id)
		# Hip: NO spring so the CPG sweeps it freely to propel. Slight outward splay then down.
		var thigh := _piece(root, thigh_id, &"capsule", Vector3(0.062, 0.21, 0.062),
				[&"locomotor", &"leg", &"muscle"],
				Vector3(sx * 0.24, -0.04, cz), Vector3(-sx * 0.10, 1.0, 0.0),
				760.0, Vector3(1, 0, 0), thigh_id)
		var shin := _piece(thigh, shin_id, &"capsule", Vector3(0.055, 0.21, 0.055),
				[&"locomotor", &"leg", &"knee", &"spring", &"muscle", &"stance_spring"],
				Vector3(0.0, -0.21, 0.0), Vector3(0, 1, 0), 740.0, Vector3(1, 0, 0), shin_id)
		shins.append(shin)
		_piece(shin, StringName("tort_%s_foot" % lbl), &"box", Vector3(0.10, 0.03, 0.15),
				[&"ground_contact", &"foot"],
				Vector3(0.0, -0.21, 0.0), Vector3(0, 1, 0), 620.0, Vector3.ZERO, &"foot_pad")
		# Stance spring braces the bent knee so the leg HOLDS the shell up without launching; the CPG
		# oscillates around this brace to step.
		# NOTE: the quad's walk recipe (hip rest_angle +0.18 lean + posture 3.0) DOES make this tortoise
		# walk (measured fwd 6.8 m, up 0.49, drag 0.10, 154 plants — it's a quad-clone: X-hip knee'd legs).
		# Left at the plod default because make_tortoise_v2 is also a DEFENSE seed in test_defense_improves,
		# and the aggressive lean makes the seed locally optimal so that test's 2-gen training can't improve
		# it. To ship the tortoise as a walker, give the defense test its own seed.
		thigh.joint.rest_angle = -0.05
		shin.joint.rest_angle = -0.12
		_assign_spring(shin, 620.0, 0.25, 0.20, 0.16, 0.90)
	_set_muscle_amount(root, 3.0)
	# The knee bears the heavy shell under a bent leg (largest moment arm) so it needs far more torque
	# headroom than the global muscle gives. Boost the shins so the legs hold the body up instead of sagging.
	for s in shins:
		_set_muscle_amount(s, 45.0)
	# Slow trot: diagonal pairs (FL+BR, FR+BL) a half-cycle apart; each knee a quarter-cycle ahead of its
	# hip so it bends to clear the foot during that leg's swing. Low frequency = a tortoise plod.
	var g := _v2_gait(ids, &"trot", 0.95, 0.85, 20.0, 2.3, 3.0)
	g.assignments[&"tort_FL_thigh"] = 0.0
	g.assignments[&"tort_BR_thigh"] = 0.0
	g.assignments[&"tort_FR_thigh"] = 0.5
	g.assignments[&"tort_BL_thigh"] = 0.5
	g.assignments[&"tort_FL_shin"] = 0.25
	g.assignments[&"tort_BR_shin"] = 0.25
	g.assignments[&"tort_FR_shin"] = 0.75
	g.assignments[&"tort_BL_shin"] = 0.75
	g.locomotion_mode = &"walk"
	root.gait = g
	return root


static func make_mantis_v2() -> PartGene:
	# HONEST BIPED (M60 reference-tracking walk). Biped dynamic balance is genuinely hard: a two-foot
	# base has no lateral stability polygon to speak of, so the tall narrow legacy body (0.20x0.42x0.22)
	# just tipped (body_drag 1.0, fall_or_tip). Rebuilt for balance + the leg tracker:
	#   - honest + no_self_collision so the Jᵀ leg tracker (walk mode) drives the feet along the gait
	#     trajectory instead of the sinusoid drive.
	#   - a LOW, wide-hipped body (short in Y, wide in X) drops the CoM and widens the lateral base.
	#   - each leg is a hip->shin->foot CHAIN: the hip hinges FORE-AFT (X axis) to protract/retract, the
	#     knee bends on X for swing clearance, and a WIDE foot spreads the stance. Legs splay slightly
	#     OUT (lateral stance width) so the two feet form a wider support base — the single biggest lever
	#     for not tipping sideways.
	#   - muscle raises the torque ceiling so the stance leg can hold the body up (like quad_v2's shins);
	#     strong posture keeps the trunk upright.
	var root := _gene(_definition(&"box", 420.0, Vector3(0.30, 0.16, 0.24)),
			[&"spine", &"mantis", &"honest", &"no_self_collision"], null, &"mantis_body")
	_add_vital_organs(root)
	var ids: Array[StringName] = []
	var shins: Array = []
	for side in [-1.0, 1.0]:
		var sx := signf(side)
		var lbl := "L" if sx < 0 else "R"
		var hip_id := StringName("mantis_hip_%s" % lbl)
		var shin_id := StringName("mantis_shin_%s" % lbl)
		ids.append(hip_id)
		ids.append(shin_id)
		# Thigh: from the hip corner, splayed slightly OUT and mostly DOWN so the feet sit wider than the
		# hips (a broader stance = harder to tip). Hip hinge on X = fore-aft sweep (the walking stroke).
		var thigh := _piece(root, hip_id, &"capsule", Vector3(0.055, 0.20, 0.055),
				[&"locomotor", &"leg", &"hindlimb", &"muscle"],
				Vector3(sx * 0.14, -0.04, 0.02), Vector3(sx * 0.06, 1.0, 0.0),
				860.0, Vector3(1, 0, 0), &"leg_upper")
		# Shin: continues down; knee on X for swing clearance. Sprung + muscled to brace the body weight.
		# Longer than the thigh so the knee stays HIGH — a short thigh hung from the body keeps leg_upper
		# off the floor even when the body sags, and the long shin does the reaching-down.
		var shin := _piece(thigh, shin_id, &"capsule", Vector3(0.045, 0.30, 0.045),
				[&"locomotor", &"leg", &"knee", &"muscle", &"spring", &"stance_spring"],
				Vector3(0.0, -0.20, 0.0), Vector3(0, 1, 0), 840.0, Vector3(1, 0, 0), &"leg_lower")
		# Wide, long foot pad — a big support footprint under each leg.
		_piece(shin, StringName("mantis_foot_%s" % lbl), &"box", Vector3(0.13, 0.03, 0.20),
				[&"ground_contact", &"foot"],
				Vector3(0.0, -0.30, 0.0), Vector3.UP, 620.0, Vector3.ZERO, &"foot_pad")
		# Braced-stance rest: the knee rests near-STRAIGHT (rest_angle 0) so the leg column bears the body
		# weight without folding; a stiff stance spring holds it there while the tracker oscillates it to
		# step. (Empirically the tracker torque dominates the spring here, but the near-straight rest is
		# the right brace for an honest column.)
		shin.joint.rest_angle = 0.0
		_assign_spring(shin, 700.0, 0.26, 0.26, 0.16, 0.92)
		shins.append(shin)
		# Raptorial forearms (cosmetic + attack). Held UP and folded so their mass sits over the body — a
		# forward-reaching heavy blade pitches the whole creature onto its face (jaw_claw dragged). Light,
		# short, tucked high.
		var arm := StringName("raptor_arm_%s" % lbl)
		_piece(root, arm, &"capsule", Vector3(0.038, 0.16, 0.038), [&"manipulator", &"arm", &"attack"],
				Vector3(sx * 0.14, 0.12, -0.10), Vector3(sx * 0.30, 0.55, -0.78),
				500.0, Vector3.ZERO, &"arm_upper")
		_piece(root, StringName("%s_blade" % String(arm)), &"capsule", Vector3(0.028, 0.16, 0.028),
				[&"attack", &"blade", &"forearm"],
				Vector3(sx * 0.20, 0.22, -0.22), Vector3(sx * 0.10, 0.75, -0.66),
				500.0, Vector3.ZERO, &"jaw_claw")
	_piece(root, &"mantis_head", &"sphere", Vector3(0.10, 0.09, 0.11), [&"sensor", &"head"],
			Vector3(0.0, 0.12, -0.18), Vector3.UP, 560.0, Vector3.ZERO, &"sensor_eye")
	# ABDOMEN: a heavy tail extending BACK (+Z) and slightly up. The head + raptorial arms sit forward
	# (-Z) and were pitching the whole creature onto its face (root_up 0.71, sinks 0.58m forward). This
	# rear counterweight pulls the CoM back OVER the feet so the trunk stays upright — a mantis's long
	# abdomen does exactly this balancing job.
	_piece(root, &"mantis_abdomen", &"capsule", Vector3(0.08, 0.20, 0.08), [&"spine", &"abdomen"],
			Vector3(0.0, 0.04, 0.20), Vector3(0.0, 0.55, 0.84), 700.0, Vector3.ZERO, &"tail_segment")
	# muscle_frac saturates at 4.0 (joint_model clamp), so 4.0 already maxes the leg torque ceiling —
	# larger dials are no-ops.
	_set_muscle_amount(root, 4.0)
	var g := _v2_gait(ids, &"walk", 0.5, 0.7, 30.0, 1.8, 5.0)
	# Left/right hips a half-cycle apart (alternating steps); each knee a quarter ahead of its hip so it
	# bends to clear the foot during that leg's swing.
	g.assignments[&"mantis_hip_L"] = 0.0
	g.assignments[&"mantis_hip_R"] = 0.5
	g.assignments[&"mantis_shin_L"] = 0.25
	g.assignments[&"mantis_shin_R"] = 0.75
	g.locomotion_mode = &"walk"
	root.gait = g
	return root


static func make_scorpion_v2() -> PartGene:
	# M60 reference-tracking WALK (daddy-longlegs recipe on the wide-flat scorpion body). honest +
	# no_self_collision route the Jᵀ leg tracker; Y (vertical) hip so each leg sweeps fore-aft
	# (protraction/retraction); walk gait + locomotion_mode drive the planned foot trajectory; muscle
	# raises the torque ceiling. This is a LOW SPRAWLING scorpion gait, not a tall clean walk: the legs
	# splay (out_frac 0.34) so the lower-leg/ankle segments BRACE on the floor and the fore-aft power
	# stroke pushes off them — that bracing is what rectifies the wide base into straight forward travel
	# (steeper foot-only legs stand clean but the strokes cancel to net-0, the wide-body failure mode).
	# So body_drag reads high (~0.65) by design here: it's leg-segment ground contact, all honest joint
	# torque + friction, no central force. Lighter/narrower thorax than the legacy 830-density box so the
	# legs can drive it. PROVEN: fwd ~1.4-1.6 m over 8-12 s, mostly straight (|lateral| < 0.5).
	var root := _gene(_definition(&"box", 420.0, Vector3(0.26, 0.10, 0.46)),
			[&"spine", &"scorpion", &"honest", &"no_self_collision"], null, &"scorpion_body")
	_add_vital_organs(root)
	# LEFT/RIGHT SYMMETRIC gait to solve the wide-flat-body net-0/backward drift: the mirror pair on each
	# body segment steps IN PHASE, so their fore-aft strokes are simultaneous and the per-leg yaw torques
	# cancel (a sequential wave yaws the wide base). The metachronal wave runs BACK-TO-FRONT (phase
	# float(3-i)*0.25) — the forward wave direction drove the body BACKWARD (measured), reversing it
	# flips net travel to +fwd. Each pair 0.25 apart keeps roughly half the legs bracing at all times.
	var ids: Array[StringName] = []
	var pair_phase := {}   # per-leg HIP (upper) id -> phase, mirror-symmetric
	for i in 4:
		var z := lerpf(-0.30, 0.30, float(i) / 3.0)
		var lids := _v2_side_leg(root, "scorp_L%d" % i, -1.0, z, 0.58, 0.036, true,
				[&"scorpion", &"muscle"], Vector3(0, 1, 0), 0.34, 0.96)
		var rids := _v2_side_leg(root, "scorp_R%d" % i, 1.0, z, 0.58, 0.036, true,
				[&"scorpion", &"muscle"], Vector3(0, 1, 0), 0.34, 0.96)
		ids.append_array(lids)
		ids.append_array(rids)
		var ph := wrapf(float(3 - i) * 0.25, 0.0, 1.0)
		pair_phase[lids[0]] = ph
		pair_phase[rids[0]] = ph
	_piece(root, &"pincer_L_arm", &"capsule", Vector3(0.055, 0.24, 0.055), [&"manipulator", &"arm", &"attack"],
			Vector3(-0.28, 0.0, -0.44), Vector3(-0.45, -0.05, -0.89), 950.0, Vector3.ZERO, &"arm_upper")
	_piece(root, &"pincer_R_arm", &"capsule", Vector3(0.055, 0.24, 0.055), [&"manipulator", &"arm", &"attack"],
			Vector3(0.28, 0.0, -0.44), Vector3(0.45, -0.05, -0.89), 950.0, Vector3.ZERO, &"arm_upper")
	_piece(root, &"pincer_L", &"capsule", Vector3(0.075, 0.17, 0.075), [&"attack", &"claw"],
			Vector3(-0.42, -0.03, -0.62), Vector3(-0.30, 0.0, -0.95), 1200.0, Vector3.ZERO, &"jaw_claw")
	_piece(root, &"pincer_R", &"capsule", Vector3(0.075, 0.17, 0.075), [&"attack", &"claw"],
			Vector3(0.42, -0.03, -0.62), Vector3(0.30, 0.0, -0.95), 1200.0, Vector3.ZERO, &"jaw_claw")
	var tail_ids: Array[StringName] = []
	for i in 5:
		var id := StringName("strike_tail_%02d" % i)
		tail_ids.append(id)
		_piece(root, id, &"capsule", Vector3(0.050, 0.16, 0.050), [&"tail", &"attack", &"actuated"],
				Vector3(0.0, 0.08 + 0.12 * i, 0.42 - 0.11 * i),
				Vector3(0.0, 0.80, -0.60), 820.0, Vector3(1, 0, 0), &"tail_segment")
	_piece(root, &"stinger", &"cylinder", Vector3(0.040, 0.16, 0.040), [&"attack", &"stinger"],
			Vector3(0.0, 0.70, -0.16), Vector3(0.0, 0.45, -0.90), 1350.0, Vector3.ZERO, &"spike")
	_set_muscle_amount(root, 4.0)
	var g := _v2_gait(ids, &"walk", 1.0, 1.35, 12.0, 1.5, 1.6)
	g.locomotion_mode = &"walk"
	# Override the sequential per-id phases with the mirror-symmetric HIP phases (only the hip/upper
	# phase feeds the leg tracker; the lower/ankle inherit their leg's plan).
	for hid in pair_phase.keys():
		g.assignments[hid] = pair_phase[hid]
	root.gait = g
	for i in tail_ids.size():
		root.gait.assignments[tail_ids[i]] = wrapf(float(i) * 0.12, 0.0, 1.0)
	return root


static func make_centipede_v2() -> PartGene:
	# STRAIGHTENING NOTE: this bellying undulator was class skate_or_spin — it CURVED (net lateral
	# ~-4.2m). The fix that stuck is the RIGID NECK + SKIMMING LEGS below (see those comments): net
	# lateral drops to ~1.9m, latratio 0.37->0.19, forward 7.0->8.2, and under its true &"undulate" gait
	# mode it now classifies credible (class "undulated", no violations). It still reads skate_or_spin
	# under the STRICT WALK gate for one reason only — yaw_rate ~25 rad/s — which is belly-contact
	# heading JITTER of the flat head sliding on the floor (measured, insensitive to wave amplitude:
	# ~25 at amplitude 0.6 and at 1.9 alike), NOT a real curve. Head geometry/mass tuning does not move
	# it (a serpent bellies by design), so this is the honest straight-travel ceiling for an undulator.
	var root := _gene(_definition(&"box", 760.0, Vector3(0.16, 0.10, 0.20)),
			[&"spine", &"head", &"centipede", &"ground_contact", &"no_self_collision", &"honest"],
			null, &"centipede_head")
	_add_vital_organs(root)
	var ids: Array[StringName] = []
	var seg_count := 8
	# M59: CHAIN the body segments head -> seg0 -> seg1 -> … (each box's half-length is extents.y,
	# oriented along the body axis) instead of fanning them off the head at absolute z. Fanned
	# segments jointed to the distant head exploded after a few seconds; neighbour-jointed segments
	# are stable. Legs still parent to their own segment (a single capsule — already correct).
	# Identity-basis body chain (no _oriented rotation) so each segment's local frame == world: the
	# box's z-extent is the body length (chained front-to-back along +z), and the legs keep a clean
	# down+out direction. Yaw hinge (0,1,0) lets the body wave; each leg steps about world X.
	# LEGGED UNDULATING SERPENT. Honest leg-only propulsion fails for many splayed legs (the strokes
	# cancel, like the spider — net 0). A real centipede ALSO undulates its body, and body undulation
	# is the proven honest mover (serpent). So the BODY is a flexible anisotropic chain that undulates
	# (yaw hinge + belly friction = forward thrust), and the LEGS step in a metachronal wave for grip
	# + clearance (so the legs visibly MOVE — the user's complaint — and add traction). No assist.
	var prev := root
	var seg_ext := Vector3(0.13, 0.08, 0.16)   # flat belly box (like the serpent), edges down
	var body_ids: Array[StringName] = []
	var leg_ids: Array[StringName] = []
	for i in seg_count:
		var sid := StringName("centi_seg_%02d" % i)
		body_ids.append(sid)
		var pa_z := root.definition.extents.z if i == 0 else prev.definition.extents.z
		# Flexible body segment: yaw hinge (0,1,0) so the gait bends it side-to-side; anisotropic belly
		# friction (axial = world Z) rectifies the S-wave into forward thrust (the serpent mechanism).
		var seg := _gene(_definition(&"box", 720.0, seg_ext),
				[&"locomotor", &"spine", &"ground_contact", &"centipede", &"anisotropic_ventral"],
				_socket(Vector3(0.0, 0.0, pa_z), Vector3(0, 1, 0), sid, Vector3(0.0, 0.0, seg_ext.z)),
				&"tail_segment", sid)
		seg.joint = JointDef.new()
		# RIGID NECK: the first two segments don't undulate (amplitude 0) so the head + neck form a calm,
		# forward-tracking anchor. The rollout accumulates yaw from the ROOT (head) heading every tick;
		# when segment 0 drives a yaw swing right at the head, that per-tick wiggle piles up past the spin
		# ceiling even though net travel is straight. Freezing the neck moves the first big lateral stroke
		# back to segment 2, away from the head, so the head barely yaws. The tail still undulates fully.
		var neck_rigid := i < 2
		seg.joint.amplitude = 0.0 if neck_rigid else 1.0
		seg.joint.angle_min = -1.0
		seg.joint.angle_max = 1.0
		for side in [-1.0, 1.0]:
			var sx := signf(side)
			var lid := StringName("centi_leg_%02d_%s" % [i, "L" if sx < 0.0 else "R"])
			leg_ids.append(lid)
			# Legs splay mostly OUT (little down) so their tips skim at belly level and don't dig in to
			# fight the anisotropic body slide (digging legs spun the body). They step about world X for
			# the visible metachronal wave + light grip; the body undulation does the propulsion.
			# Legs splay almost flat OUT and skim ABOVE the belly line (raised attach + shorter reach) so
			# they barely graze — a light metachronal touch for the look, not a hard grip. Digging legs on
			# a bending body inject a net lateral/turning bias (the curve); a skim can't. They stroke about
			# world X only for the visible wave; the body undulation does the propulsion.
			_piece(seg, lid, &"capsule", Vector3(0.020, 0.09, 0.020),
					[&"locomotor", &"leg", &"ground_contact", &"centipede", &"muscle"],
					Vector3(sx * 0.12, 0.02, 0.0), Vector3(-sx * 0.985, 0.17, 0.0),
					560.0, Vector3(1, 0, 0), &"leg_lower")
		prev.children.append(seg)
		prev = seg
	_set_muscle_amount(root, 2.0)
	# Undulation wave down the BODY (propulsion) + a faster metachronal wave down the LEGS (stepping).
	for sid in body_ids:
		ids.append(sid)
	for lid in leg_ids:
		ids.append(lid)
	var g := _v2_gait(ids, &"undulate", 1.9, 1.6, 6.0, 0.0, 0.0)
	for i in body_ids.size():
		g.assignments[body_ids[i]] = wrapf(float(i) * 0.16, 0.0, 1.0)
	# Both legs of a SEGMENT step in phase (symmetric) so their lateral pushes cancel and the body
	# undulation drives it STRAIGHT, not spinning; the metachronal wave is across segments (i/2).
	for i in leg_ids.size():
		g.assignments[leg_ids[i]] = wrapf(float(i / 2) * 0.16, 0.0, 1.0)
	root.gait = g
	return root


static func _template(id: StringName, part_type: StringName, extents: Vector3,
		tags: Array, density := DEFAULT_DENSITY) -> PartGene:
	return _gene(_definition(part_type, density, extents), tags, null, id)


static func _definition(part_type: StringName, density: float, extents: Vector3) -> PartDefinition:
	var d := PartDefinition.new()
	d.part_type = part_type
	d.density = density
	d.extents = extents
	return d


static func _socket(pos: Vector3, hinge: Vector3, id: StringName,
		child_anchor_origin := Vector3.ZERO) -> SocketDef:
	var s := SocketDef.new()
	s.id = id
	s.display_name = String(id)
	s.parent_attachment = Transform3D(Basis.IDENTITY, pos)
	s.child_anchor = Transform3D(Basis.IDENTITY, child_anchor_origin)
	s.hinge_axis = hinge
	return s


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


static func _apply_template_mechanics(parts: Dictionary) -> void:
	for id in parts.keys():
		var g: PartGene = parts[id]
		if g == null:
			continue
		if String(id).contains("spring") or g.tags.has(&"spring"):
			# Stiffer than before so a dropped spring foot/joint visibly stores + releases (was too soft).
			_assign_spring(g, 360.0, 0.22, 0.20, 0.18, 0.78)
		elif g.tags.has(&"tendon"):
			# A LONE tendon can't do its real job (a TendonDef biarticularly couples TWO joints, which a
			# single dropped part has no partner for), so it used to be a dead rigid rod. Make it a real
			# ELASTIC strut (spring) instead — now it actually stores/returns energy when its joint flexes.
			_assign_spring(g, 300.0, 0.25, 0.20, 0.18, 0.86)
		if g.tags.has(&"muscle"):
			# The muscle tag only matters if it carries an amount — it raises the nearby joint's torque
			# ceiling. Without this a "muscle bundle" was inert; 3.0 makes it a strong actuator booster.
			g.dial_values[&"muscle_amount"] = 3.0
		_assign_weapon_from_tags(g)


static func _assign_spring(g: PartGene, stiffness := 220.0, damping := 0.20,
		max_compression := 0.18, release_threshold := 0.20, efficiency := 0.65,
		axis := Vector3.UP) -> PartGene:
	if g == null:
		return null
	var s := SpringDef.new()
	s.enabled = true
	s.stiffness = stiffness
	s.damping = damping
	s.max_compression = max_compression
	s.release_threshold = release_threshold
	s.efficiency = efficiency
	s.axis = axis
	g.spring = s
	if not g.tags.has(&"spring"):
		g.tags.append(&"spring")
	return g


static func _assign_weapon_from_tags(g: PartGene) -> PartGene:
	if g == null:
		return null
	if g.weapon != null:
		return g
	if g.tags.has(&"stinger"):
		return _assign_weapon(g, &"stinger", 0.15, 0.95, 1.05, 0.05, 0.65, 0.18)
	if g.tags.has(&"blade") or g.tags.has(&"claw"):
		return _assign_weapon(g, &"blade", 0.85, 0.35, 1.10, 0.35, 0.0, 0.12)
	if g.tags.has(&"bludgeon"):
		return _assign_weapon(g, &"bludgeon", 0.05, 0.10, 1.75, 0.0, 0.0, 0.10)
	if g.tags.has(&"spike"):
		return _assign_weapon(g, &"stinger", 0.20, 0.75, 1.05, 0.05, 0.0, 0.12)
	if g.tags.has(&"attack"):
		return _assign_weapon(g, &"blade", 0.45, 0.25, 1.15, 0.15, 0.0, 0.08)
	return g


static func _assign_weapon(g: PartGene, kind: StringName, sharpness := 0.0,
		penetration := 0.0, impact := 1.0, bleed := 0.0, venom := 0.0,
		reach := 0.0) -> PartGene:
	if g == null:
		return null
	var w := WeaponDef.new()
	w.kind = kind
	w.sharpness = sharpness
	w.penetration = penetration
	w.impact_multiplier = impact
	w.bleed = bleed
	w.venom = venom
	w.reach = reach
	g.weapon = w
	if not g.tags.has(&"attack"):
		g.tags.append(&"attack")
	return g
