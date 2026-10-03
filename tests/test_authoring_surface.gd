extends SceneTree

## M44 — authoring surface. Author a SpringDef + WeaponDef + locomotion mode through the editor
## (EditorBench / EditSession), save, reload, and confirm the rollout reads the authored values.
## Ties the new authoring API to the existing GenomeSnapshot round-trip.

const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _run() -> void:
	print("=== M44 authoring surface tests ===")
	_test_author_save_reload_rollout()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_author_save_reload_rollout() -> void:
	print("- author spring/weapon/mode, save, reload, rollout reads authored values")
	var bench := EditorBench.new()
	root.add_child(bench)
	var card := CreatureCard.new()
	card.root = PartCatalog.make_quadruped(false)
	bench.load_card(card)

	# Author on a leg part.
	bench.select_part(3)
	_check(bench.edit_selected_spring(275.0, 0.25, 0.7), "spring authored on selected part")
	_check(bench.edit_selected_weapon(&"blade", 0.9, 0.3, 1.1, 0.15), "weapon authored on selected part")
	_check(bench.set_root_locomotion_mode(&"hop"), "locomotion mode authored on the root gait")

	var summary := bench.part_authoring_summary(3)
	_check(bool(summary.get("has_spring", false))
			and is_equal_approx(float(summary.get("spring_stiffness", 0.0)), 275.0),
			"per-part overlay summary reflects the authored spring")
	_check(bool(summary.get("has_weapon", false)), "overlay summary reflects the authored weapon")

	# Save -> JSON -> reload (the GenomeSnapshot round-trip).
	var authored := bench.current_root()
	_check(authored != null, "bench exposes the authored genome")
	var packed := GenomeSnapshot.to_dictionary(authored)
	var restored := GenomeSnapshot.from_dictionary(JSON.parse_string(JSON.stringify(packed)))
	_check(restored != null, "authored genome round-trips through JSON")
	_check(restored.gait != null and restored.gait.locomotion_mode == &"hop",
			"authored locomotion_mode survives the round-trip")

	# The authored spring/weapon survive and are found on a part of the reloaded genome.
	var found_spring := _find_spring_stiffness(restored)
	var found_weapon := _find_weapon_kind(restored)
	_check(is_equal_approx(found_spring, 275.0), "authored spring stiffness survives reload")
	_check(found_weapon == &"blade", "authored weapon kind survives reload")

	# The live controller reads the authored mode + binds the authored spring from the reload.
	var ctrl := CpgControllerScript.new()
	ctrl.call("bind", CreatureBodyScript.build(restored), restored, null)
	_check(ctrl.call("locomotion_mode") == &"hop", "controller honors the authored locomotion mode")
	_check(int(ctrl.call("spring_drive_count")) >= 1, "controller binds the authored spring drive")
	bench.queue_free()


func _find_spring_stiffness(g: PartGene) -> float:
	if g == null:
		return -1.0
	if g.spring != null:
		return g.spring.stiffness
	for c in g.children:
		var v := _find_spring_stiffness(c)
		if v >= 0.0:
			return v
	return -1.0


func _find_weapon_kind(g: PartGene) -> StringName:
	if g == null:
		return &"none"
	if g.weapon != null:
		return g.weapon.kind
	for c in g.children:
		var k := _find_weapon_kind(c)
		if k != &"none":
			return k
	return &"none"
