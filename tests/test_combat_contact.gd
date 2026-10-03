extends SceneTree

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CombatResolverScript := preload("res://scripts/sim/combat.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Combat contact tests ===")
	await _test_real_contact_row_is_attributed()
	await _test_measured_contact_damages_defender()
	await _test_organ_contact_can_kill()
	await _test_damage_without_contact_is_rejected()
	_test_non_vital_hit_does_not_claim_vital_kill()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_real_contact_row_is_attributed() -> void:
	print("- co-sim strike produces an attributed physics contact row")
	var p := SimRolloutScript.CombatParams.new()
	p.strike_speed = 7.0
	var m: Dictionary = await SimRolloutScript.run_combat_contact(_spike(), _vital_blob(), self, p)
	_check(bool(m["ok"]) and int(m["contact_count"]) > 0, "strike records at least one real contact row")
	var rows: Array = m["contact_rows"]
	var row: Dictionary = rows[0]
	_check(row.get("attacker_creature") == &"attacker" and row.get("defender_creature") == &"defender",
			"contact row attributes attacker and defender creatures")
	_check(row.has("attacker_part_index") and row.has("defender_part_index")
			and float(row.get("relative_speed", 0.0)) > 0.0,
			"contact row carries part indices and relative speed")


func _test_measured_contact_damages_defender() -> void:
	print("- measured contact feeds the combat damage model")
	var p := SimRolloutScript.CombatParams.new()
	p.strike_speed = 8.0
	var m: Dictionary = await SimRolloutScript.run_combat_contact(_spike(), _vital_blob(), self, p)
	_check(not bool(m.get("synthetic_contact", true)), "combat rollout is not synthetic contact")
	_check(float(m.get("damage", 0.0)) > 0.0, "real contact produces positive damage")


func _test_organ_contact_can_kill() -> void:
	print("- high-energy contact against a vital part can kill")
	var p := SimRolloutScript.CombatParams.new()
	p.strike_speed = 22.0
	var m: Dictionary = await SimRolloutScript.run_combat_contact(_spike(), _fragile_vital_blob(), self, p)
	_check(float(m.get("damage", 0.0)) > 0.0, "high-energy contact produces damage")
	_check(not bool(m.get("defender_alive", true)), "vital contact can kill the defender")
	_check((m.get("reasons", []) as Array).has("vital contact part destroyed")
			or (m.get("reasons", []) as Array).has("body durability depleted"),
			"kill explains vital/body durability loss")


func _test_damage_without_contact_is_rejected() -> void:
	print("- no contact cannot create measured combat damage")
	var p := SimRolloutScript.CombatParams.new()
	p.strike_speed = 0.0
	p.horizon_s = 0.25
	var m: Dictionary = await SimRolloutScript.run_combat_contact(_spike(), _vital_blob(), self, p)
	_check(int(m.get("contact_count", 0)) == 0, "no-contact rollout records zero contacts")
	_check(float(m.get("damage", 0.0)) == 0.0, "no-contact rollout records zero damage")


func _test_non_vital_hit_does_not_claim_vital_kill() -> void:
	print("- non-vital contact cannot claim a vital kill reason")
	var defender := _vital_with_tail()
	var result: Dictionary = CombatResolverScript.resolve_contact(_spike(), defender, {
		"attacker_part_index": 0,
		"defender_part_index": 3,
		"relative_speed": 0.5,
		"normal_impulse": 0.1,
	})
	_check(bool(result.get("defender_alive", false)), "low-energy non-vital hit leaves defender alive")
	_check(not (result.get("reasons", []) as Array).has("vital contact part destroyed"),
			"non-vital hit does not report vital destruction")


func _spike() -> PartGene:
	var d := PartDefinition.new()
	d.part_type = &"sphere"
	d.density = 1600.0
	d.extents = Vector3(0.24, 0.24, 0.24)
	var g := PartGene.new()
	g.definition = d
	g.tags = [&"attack"]
	return g


func _vital_blob() -> PartGene:
	return _blob(500.0, Vector3(0.24, 0.24, 0.24))


func _fragile_vital_blob() -> PartGene:
	return _blob(60.0, Vector3(0.12, 0.12, 0.12))


func _blob(density: float, extents: Vector3) -> PartGene:
	var d := PartDefinition.new()
	d.part_type = &"box"
	d.density = density
	d.extents = extents
	var g := PartGene.new()
	g.definition = d
	g.tags = [&"spine", &"heart", &"brain", &"lung"]
	return g


func _vital_with_tail() -> PartGene:
	var root := _vital_blob()
	var d := PartDefinition.new()
	d.part_type = &"box"
	d.density = 500.0
	d.extents = Vector3(0.18, 0.10, 0.18)
	for i in 3:
		var child := PartGene.new()
		child.definition = d
		child.tags = [&"armor"]
		child.socket_id = StringName("tail_%d" % i)
		var s := SocketDef.new()
		s.id = child.socket_id
		s.parent_attachment = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.2 + i * 0.2))
		child.socket = s
		root.children.append(child)
	return root
