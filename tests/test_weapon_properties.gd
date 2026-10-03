extends SceneTree

const CombatResolverScript := preload("res://scripts/sim/combat.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Weapon property tests ===")
	_test_catalog_and_pregens_have_typed_weapons()
	_test_snapshot_preserves_weapon_def()
	_test_contact_damage_uses_weapon_type()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_catalog_and_pregens_have_typed_weapons() -> void:
	print("- catalog/pregen weapon resources")
	var blade := PartCatalog.clone_template(&"blade_weapon")
	var stinger := PartCatalog.clone_template(&"stinger_weapon")
	var club := PartCatalog.clone_template(&"bludgeon_club")
	_check(blade != null and blade.weapon != null and blade.weapon.kind == &"blade",
			"blade_weapon template carries blade WeaponDef")
	_check(stinger != null and stinger.weapon != null and stinger.weapon.kind == &"stinger",
			"stinger_weapon template carries stinger WeaponDef")
	_check(club != null and club.weapon != null and club.weapon.kind == &"bludgeon",
			"bludgeon_club template carries bludgeon WeaponDef")
	_check(_count_weapon_kind(PartCatalog.make_mantis_v2(), &"blade") >= 2,
			"mantis v2 raptorial arms carry blade WeaponDef")
	_check(_count_weapon_kind(PartCatalog.make_scorpion_v2(), &"stinger") >= 1,
			"scorpion v2 tail carries stinger WeaponDef")


func _test_snapshot_preserves_weapon_def() -> void:
	print("- WeaponDef snapshot round-trip")
	var root := PartCatalog.clone_template(&"stinger_weapon")
	root.weapon.venom = 0.88
	root.weapon.penetration = 1.15
	var packed := GenomeSnapshot.to_dictionary(root)
	var restored := GenomeSnapshot.from_dictionary(JSON.parse_string(JSON.stringify(packed)))
	_check(restored != null and restored.weapon != null, "weapon snapshot restores resource")
	_check(restored.weapon.kind == &"stinger" and is_equal_approx(restored.weapon.venom, 0.88)
			and is_equal_approx(restored.weapon.penetration, 1.15),
			"weapon kind and numeric properties survive JSON round-trip")
	_check(restored.weapon != root.weapon, "restored weapon resource is isolated")


func _test_contact_damage_uses_weapon_type() -> void:
	print("- combat contact reports weapon-specific effects")
	var defender := _defender()
	var contact := {"attacker_part_index": 0, "defender_part_index": 0,
		"relative_speed": 5.0, "normal_impulse": 1.0}
	var unarmed := CombatResolverScript.resolve_contact(_attacker(null), defender, contact)
	var blade := CombatResolverScript.resolve_contact(_attacker(_weapon(&"blade", 0.9, 0.35, 1.1, 0.45, 0.0)), defender, contact)
	var stinger := CombatResolverScript.resolve_contact(_attacker(_weapon(&"stinger", 0.1, 1.0, 1.05, 0.05, 0.75)), defender, contact)
	var club := CombatResolverScript.resolve_contact(_attacker(_weapon(&"bludgeon", 0.0, 0.1, 1.8, 0.0, 0.0)), defender, contact)
	_check(float(blade["damage"]) > float(unarmed["damage"])
			and blade["weapon_kind"] == &"blade" and blade["damage_type"] == &"cut",
			"blade contact increases damage and reports cut type")
	_check(float(stinger["venom"]) > 0.0 and stinger["weapon_kind"] == &"stinger"
			and stinger["damage_type"] == &"puncture",
			"stinger contact reports puncture plus venom")
	_check(float(club["damage"]) > float(unarmed["damage"])
			and club["weapon_kind"] == &"bludgeon" and club["damage_type"] == &"blunt",
			"bludgeon contact reports blunt impact damage")
	_check(float(blade["bleed"]) > float(club["bleed"]),
			"blade carries stronger bleed secondary than bludgeon")


func _weapon(kind: StringName, sharpness: float, penetration: float,
		impact: float, bleed: float, venom: float) -> WeaponDef:
	var w := WeaponDef.new()
	w.kind = kind
	w.sharpness = sharpness
	w.penetration = penetration
	w.impact_multiplier = impact
	w.bleed = bleed
	w.venom = venom
	w.reach = 0.12
	return w


func _attacker(weapon: WeaponDef) -> PartGene:
	var d := PartDefinition.new()
	d.part_type = &"sphere"
	d.density = 1200.0
	d.extents = Vector3(0.24, 0.24, 0.24)
	var g := PartGene.new()
	g.definition = d
	var tags: Array[StringName] = []
	if weapon != null:
		tags.append(&"attack")
	g.tags = tags
	g.weapon = weapon
	return g


func _defender() -> PartGene:
	var d := PartDefinition.new()
	d.part_type = &"box"
	d.density = 500.0
	d.extents = Vector3(0.24, 0.24, 0.24)
	var g := PartGene.new()
	g.definition = d
	var tags: Array[StringName] = [&"spine", &"heart", &"brain", &"lung"]
	g.tags = tags
	return g


func _count_weapon_kind(g: PartGene, kind: StringName) -> int:
	if g == null:
		return 0
	var count := 1 if g.weapon != null and g.weapon.kind == kind else 0
	for child in g.children:
		count += _count_weapon_kind(child, kind)
	return count
