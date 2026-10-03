class_name CombatResolver
extends RefCounted

## Loop-2 combat/durability helper. It derives health from the same part graph,
## vital tags, debt, and tissue properties used elsewhere; no separate authored HP
## stat is introduced.


static func durability(root_gene: PartGene) -> Dictionary:
	var fold := CharacteristicsEvaluator.fold_graph(root_gene, Transform3D.IDENTITY)
	var total := 0.0
	var vital := 0.0
	var attack := 0.0
	for p in fold["parts"]:
		var tags: Array[StringName] = []
		for t in p.tags.keys():
			tags.append(t)
		var hp: float = float(p.mass) * TissueTypes.damage_threshold(1.0, tags)
		if p.tags.has(&"muscle"):
			hp *= 1.10
		total += hp
		if p.tags.has(&"heart") or p.tags.has(&"brain") or p.tags.has(&"lung"):
			vital += hp
		if p.tags.has(&"attack"):
			attack += hp
	var eval := CharacteristicsEvaluator.evaluate(root_gene)
	return {
		"hp": total,
		"vital_hp": vital,
		"attack_power": attack + float(eval["strength"]["value"]) * maxf(total, 1.0),
		"alive": bool(eval["debt"].get("alive", true)),
		"debt": float(eval["debt"]["debt_total"]),
	}


static func resolve_attack(attacker: PartGene, defender: PartGene,
		hazard_damage := 0.0) -> Dictionary:
	var atk := durability(attacker)
	var def := durability(defender)
	var damage := maxf(float(atk["attack_power"]) * 0.12 + hazard_damage, 0.0)
	var hp := maxf(float(def["hp"]), 0.001)
	var vital_hp := maxf(float(def["vital_hp"]), hp * 0.15)
	var post_hp := hp - damage
	var vital_loss := maxf(damage - hp * 0.55, 0.0)
	var alive := bool(def["alive"]) and post_hp > 0.0 and vital_loss < vital_hp
	var reasons: Array[String] = []
	if not bool(def["alive"]):
		reasons.append("defender already missing vital organs")
	if post_hp <= 0.0:
		reasons.append("body durability depleted")
	if vital_loss >= vital_hp:
		reasons.append("vital organ durability depleted")
	return {
		"damage": damage,
		"defender_hp_before": hp,
		"defender_hp_after": maxf(post_hp, 0.0),
		"defender_alive": alive,
		"reasons": reasons,
	}


static func resolve_contact(attacker: PartGene, defender: PartGene,
		contact: Dictionary) -> Dictionary:
	var atk_parts: Array = CharacteristicsEvaluator.fold_graph(attacker, Transform3D.IDENTITY)["parts"]
	var def_parts: Array = CharacteristicsEvaluator.fold_graph(defender, Transform3D.IDENTITY)["parts"]
	if atk_parts.is_empty() or def_parts.is_empty():
		return {"damage": 0.0, "defender_alive": false,
			"reasons": ["missing folded contact parts"], "contact_driven": true}
	var attacker_idx := _part_index_or_best(atk_parts, int(contact.get("attacker_part_index", -1)), true)
	var defender_idx := _part_index_or_best(def_parts, int(contact.get("defender_part_index", -1)), false)
	var atk_part = atk_parts[attacker_idx]
	var def_part = def_parts[defender_idx]
	var rel_speed := maxf(float(contact.get("relative_speed", 0.0)), 0.0)
	var impulse := maxf(float(contact.get("normal_impulse", 0.0)), 0.0)
	var atk_tags := _tags_for(atk_part)
	var def_tags := _tags_for(def_part)
	var atk_mass := maxf(float(atk_part.mass), 0.001)
	var def_mass := maxf(float(def_part.mass), 0.001)
	var reduced_mass := (atk_mass * def_mass) / maxf(atk_mass + def_mass, 0.001)
	var edge_align := clampf(float(contact.get("edge_align", 1.0)), 0.0, 1.0)
	var weapon := weapon_profile(atk_part, edge_align)
	var weapon_scale := float(weapon["multiplier"])
	var contact_energy := 0.5 * reduced_mass * rel_speed * rel_speed
	var raw_damage := (contact_energy + impulse * 0.15) * weapon_scale
	var bleed := raw_damage * float(weapon["bleed"])
	var venom := raw_damage * float(weapon["venom"])
	raw_damage += venom * 0.20
	# M43-1: a part behind armor (an armor ancestor or an overlapping plate) takes reduced
	# damage — shells/carapaces become defensive geometry, not just HP sponges.
	var mitigation := _occlusion_mitigation(def_parts, defender_idx)
	raw_damage *= (1.0 - mitigation)
	var part_hp := maxf(def_mass * TissueTypes.damage_threshold(1.0, def_tags), 0.001)
	var body := durability(defender)
	var body_hp := maxf(float(body["hp"]), 0.001)
	var part_after := part_hp - raw_damage
	var body_after := body_hp - raw_damage
	var vital_hit: bool = def_part.tags.has(&"heart") or def_part.tags.has(&"brain") or def_part.tags.has(&"lung")
	var alive: bool = bool(body["alive"]) and body_after > 0.0 and (not vital_hit or part_after > 0.0)
	var reasons: Array[String] = []
	if vital_hit and part_after <= 0.0:
		reasons.append("vital contact part destroyed")
	if body_after <= 0.0:
		reasons.append("body durability depleted")
	if not bool(body["alive"]):
		reasons.append("defender already missing vital organs")
	return {
		"contact_driven": true,
		"attacker_part_index": attacker_idx,
		"defender_part_index": defender_idx,
		"relative_speed": rel_speed,
		"normal_impulse": impulse,
		"weapon_kind": weapon["kind"],
		"damage_type": weapon["damage_type"],
		"weapon_multiplier": weapon_scale,
		"edge_align": edge_align,
		"mitigation": mitigation,
		"bleed": bleed,
		"venom": venom,
		"damage": raw_damage,
		"defender_part_hp_before": part_hp,
		"defender_part_hp_after": maxf(part_after, 0.0),
		"defender_hp_before": body_hp,
		"defender_hp_after": maxf(body_after, 0.0),
		"defender_alive": alive,
		"reasons": reasons,
	}


static func weapon_profile(part, edge_align := 1.0) -> Dictionary:
	var kind: StringName = &"unarmed"
	var sharpness := 0.0
	var penetration := 0.0
	var impact := 1.0
	var bleed := 0.0
	var venom := 0.0
	var reach := 0.0
	if part != null and part.weapon != null:
		var w: WeaponDef = part.weapon
		kind = w.kind
		sharpness = maxf(w.sharpness, 0.0)
		penetration = maxf(w.penetration, 0.0)
		impact = maxf(w.impact_multiplier, 0.0)
		bleed = maxf(w.bleed, 0.0)
		venom = maxf(w.venom, 0.0)
		reach = maxf(w.reach, 0.0)
	elif part != null and part.tags.has(&"attack"):
		if part.tags.has(&"blade") or part.tags.has(&"claw"):
			kind = &"blade"
			sharpness = 0.55
			penetration = 0.25
			impact = 1.15
			bleed = 0.20
		elif part.tags.has(&"stinger") or part.tags.has(&"spike"):
			kind = &"stinger"
			penetration = 0.70
			impact = 1.10
		else:
			kind = &"bludgeon"
			impact = 1.25
	var damage_type: StringName = &"blunt"
	var multiplier := impact
	# M43-3: a blade striking edge-on (cutting axis perpendicular to surface, parallel to the
	# velocity) does full sharpness; flat/oblique falls toward blunt. edge_align in [0,1]; 1.0
	# (default) preserves prior behaviour for callers with no orientation info.
	var ea := clampf(edge_align, 0.0, 1.0)
	match kind:
		&"blade", &"claw":
			damage_type = &"cut"
			multiplier += sharpness * 0.85 * ea + penetration * 0.35 + reach * 0.15
		&"stinger", &"spike":
			damage_type = &"puncture"
			multiplier += penetration * 1.10 + sharpness * 0.20 + reach * 0.20
		&"bludgeon":
			damage_type = &"blunt"
			multiplier += maxf(impact - 1.0, 0.0) * 0.55
		_:
			multiplier = 1.0
	if part != null and part.tags.has(&"muscle"):
		multiplier += 0.35
	return {
		"kind": kind,
		"damage_type": damage_type,
		"multiplier": maxf(multiplier, 1.0),
		"bleed": bleed,
		"venom": venom,
		"reach": reach,
	}


static func resolve_contact_row(attacker: PartGene, defender: PartGene,
		row: Dictionary) -> Dictionary:
	var contact := {
		"attacker_part_index": int(row.get("attacker_part_index", -1)),
		"defender_part_index": int(row.get("defender_part_index", -1)),
		"relative_speed": float(row.get("relative_speed", 0.0)),
		"normal_impulse": float(row.get("normal_impulse", row.get("normal_impulse_proxy", 0.0))),
	}
	var result := resolve_contact(attacker, defender, contact)
	result["attacker_creature"] = row.get("attacker_creature", &"attacker")
	result["defender_creature"] = row.get("defender_creature", &"defender")
	result["contact_row"] = row.duplicate(true)
	return result


static func capture_contact_rows(attacker_body: Node3D, defender_body: Node3D) -> Array[Dictionary]:
	if attacker_body == null or defender_body == null \
			or not attacker_body.has_method("part_bodies") or not defender_body.has_method("part_bodies"):
		return []
	var attacker_parts: Array = attacker_body.call("part_bodies")
	var defender_parts: Array = defender_body.call("part_bodies")
	var defender_index := {}
	for i in defender_parts.size():
		var rb := defender_parts[i] as RigidBody3D
		if rb != null:
			defender_index[rb.get_instance_id()] = i
	var rows: Array[Dictionary] = []
	for ai in attacker_parts.size():
		var a := attacker_parts[ai] as RigidBody3D
		if a == null or not a.contact_monitor:
			continue
		for other in a.get_colliding_bodies():
			var b := other as RigidBody3D
			if b == null or not defender_index.has(b.get_instance_id()):
				continue
			var bi := int(defender_index[b.get_instance_id()])
			var delta := b.global_position - a.global_position
			var normal := delta.normalized() if delta.length() > 0.001 else Vector3.FORWARD
			var rel_v := a.linear_velocity - b.linear_velocity
			var rel_speed := maxf(rel_v.length(), float(a.get_meta("pre_contact_speed", 0.0)))
			var normal_speed := maxf(absf(rel_v.dot(normal)), float(a.get_meta("pre_contact_speed", 0.0)))
			var reduced_mass := (a.mass * b.mass) / maxf(a.mass + b.mass, 0.001)
			rows.append({
				"attacker_creature": a.get_meta("creature_id", &"attacker"),
				"attacker_part_index": int(a.get_meta("part_index", ai)),
				"defender_creature": b.get_meta("creature_id", &"defender"),
				"defender_part_index": int(b.get_meta("part_index", bi)),
				"relative_speed": rel_speed,
				"normal_speed": normal_speed,
				"normal_impulse_proxy": reduced_mass * normal_speed,
				"attacker_body": a,
				"defender_body": b,
			})
	return rows


static func hazard_hit(root_gene: PartGene, severity: float) -> Dictionary:
	var dummy := PartCatalog.clone_template(&"spike")
	if dummy == null:
		return resolve_attack(root_gene, root_gene, severity)
	dummy.tags = [&"attack"]
	dummy.definition.density = 1200.0
	dummy.definition.extents = Vector3.ONE * maxf(severity, 0.05)
	return resolve_attack(dummy, root_gene, severity * 25.0)


static func hazard_contact(root_gene: PartGene, severity: float) -> Dictionary:
	var dummy := PartCatalog.clone_template(&"spike")
	if dummy == null:
		return resolve_contact(root_gene, root_gene, {
			"relative_speed": maxf(severity * 4.0, 0.1),
			"normal_impulse": severity * 20.0,
		})
	dummy.tags = [&"attack"]
	dummy.definition.density = 1200.0
	dummy.definition.extents = Vector3.ONE * maxf(severity, 0.05)
	return resolve_contact(dummy, root_gene, {
		"attacker_part_index": 0,
		"relative_speed": maxf(severity * 4.0, 0.1),
		"normal_impulse": severity * 20.0,
	})


static func _part_index_or_best(parts: Array, requested: int, prefer_attack: bool) -> int:
	if requested >= 0 and requested < parts.size():
		return requested
	var best := 0
	var best_score := -INF
	for i in parts.size():
		var p = parts[i]
		var score := float(p.mass)
		if prefer_attack and p.tags.has(&"attack"):
			score += 1000.0
		if not prefer_attack and (p.tags.has(&"heart") or p.tags.has(&"brain") or p.tags.has(&"lung")):
			score += 500.0
		if score > best_score:
			best_score = score
			best = i
	return best


static func _tags_for(part) -> Array[StringName]:
	var tags: Array[StringName] = []
	for t in part.tags.keys():
		tags.append(t)
	return tags


# M43-1: damage mitigation for a struck part shielded by armor. Two occluders count: an
# &"armor"/&"shell"-tagged ANCESTOR (armor wrapping a limb), and an overlapping plate (a shell
# whose world box intersects the struck part — a carapace over an organ). Returns the strongest
# mitigation in [0, 0.85] (armor can blunt, never fully negate).
static func _occlusion_mitigation(def_parts: Array, idx: int) -> float:
	if idx < 0 or idx >= def_parts.size():
		return 0.0
	var struck = def_parts[idx]
	var best := 0.0
	var cur := int(struck.parent)
	var guard := 0
	while cur >= 0 and cur < def_parts.size() and guard < def_parts.size():
		best = maxf(best, _plate_mitigation(def_parts[cur]))
		cur = int(def_parts[cur].parent)
		guard += 1
	for p in def_parts:
		if int(p.index) == idx:
			continue
		if (p.tags.has(&"armor") or p.tags.has(&"shell")) and p.world_aabb.intersects(struck.world_aabb):
			best = maxf(best, _plate_mitigation(p))
	return best


static func _plate_mitigation(part) -> float:
	if not (part.tags.has(&"armor") or part.tags.has(&"shell")):
		return 0.0
	var thr := float(TissueTypes.properties(_tags_for(part))["damage_threshold_scale"])
	var thickness := minf(part.dims.x, minf(part.dims.y, part.dims.z))
	return clampf(1.0 - 1.0 / maxf(thr, 1.0) + thickness * 0.5, 0.0, 0.85)
