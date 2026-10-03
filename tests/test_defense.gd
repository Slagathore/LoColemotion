extends SceneTree

## M43 — defense & damage fidelity. (1) a part behind armor takes reduced damage (occlusion);
## (3) a blade striking edge-on out-damages the same blade landing flat (edge alignment); and
## the BlockController interposes a shield/weapon between a threat and a vital (training is M46).

const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const BlockControllerScript := preload("res://scripts/sim/block_controller.gd")
const SimWorldScript := preload("res://scripts/sim/sim_world.gd")

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
	print("=== M43 defense + damage fidelity tests ===")
	_test_shell_mitigates()
	_test_edge_beats_flat()
	await _test_block_controller_interposes()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_shell_mitigates() -> void:
	print("- a part behind an armor plate takes less damage than exposed")
	var attacker := PartCatalog.clone_template(&"blade_weapon")
	var bare := _defender(false)
	var armored := _defender(true)
	var contact := {"attacker_part_index": 0, "relative_speed": 6.0, "normal_impulse": 1.0}
	var d_bare := CombatResolver.resolve_contact(attacker, bare, contact)
	var d_armored := CombatResolver.resolve_contact(attacker, armored, contact)
	print("  damage exposed=%.3f behind-shell=%.3f mitigation=%.3f" % [
			float(d_bare["damage"]), float(d_armored["damage"]), float(d_armored["mitigation"])])
	_check(float(d_armored["mitigation"]) > 0.0, "occlusion reports positive mitigation behind the plate")
	_check(float(d_armored["damage"]) < float(d_bare["damage"]),
			"the shielded vital takes less damage than the exposed one")


func _test_edge_beats_flat() -> void:
	print("- the same blade does more damage edge-on than flat")
	var attacker := PartCatalog.clone_template(&"blade_weapon")
	var defender := PartCatalog.clone_template(&"body_small")
	var edge_on := CombatResolver.resolve_contact(attacker, defender,
			{"attacker_part_index": 0, "relative_speed": 6.0, "edge_align": 1.0})
	var flat := CombatResolver.resolve_contact(attacker, defender,
			{"attacker_part_index": 0, "relative_speed": 6.0, "edge_align": 0.05})
	print("  damage edge-on=%.3f flat=%.3f" % [float(edge_on["damage"]), float(flat["damage"])])
	_check(float(edge_on["damage"]) > float(flat["damage"]),
			"edge-on out-damages flat (edge alignment rewards technique)")


func _test_block_controller_interposes() -> void:
	print("- the block controller selects a blocker and interposes toward the threat")
	var gene := PartCatalog.make_scorpion_v2()
	var world := Node3D.new()
	root.add_child(world)
	SimWorldScript.add_floor(world, 1.0)
	var body: Node3D = CreatureBodyScript.build(gene, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0)))
	world.add_child(body)
	var ctrl := CpgControllerScript.new()
	ctrl.call("bind", body, gene, CpgControllerScript.Params.new())
	world.add_child(ctrl)
	for _i in 40:
		await physics_frame
	var threat := Node3D.new()
	world.add_child(threat)
	threat.global_position = Vector3(0.0, 1.0, -2.0)
	var block := BlockControllerScript.new()
	block.call("bind", body, gene, threat)
	world.add_child(block)
	_check(int(block.call("blocker_index")) >= 0, "block controller selects an actuatable blocker")
	var intents := 0
	for _j in 30:
		block.call("tick", 1.0 / 60.0)
		ctrl.call("tick", 1.0, 1.0 / 60.0)
		await physics_frame
		intents = maxi(intents, int(block.call("last_intent_count")))
	print("  blocker_idx=%d vital_idx=%d intents=%d" % [
			int(block.call("blocker_index")), int(block.call("vital_index")), intents])
	_check(intents > 0, "block controller publishes interposition overlays")
	world.queue_free()
	await physics_frame


# A defender = body with a heart at the origin, optionally shielded by an overlapping armor plate.
func _defender(with_armor: bool) -> PartGene:
	var root_gene := _gene(&"box", Vector3(0.30, 0.30, 0.30), 800.0, [&"spine"], &"def_body")
	var heart := _gene(&"box", Vector3(0.20, 0.20, 0.20), 800.0, [&"heart"], &"heart")
	heart.socket = _socket(Vector3.ZERO)
	root_gene.children.append(heart)
	if with_armor:
		var plate := _gene(&"box", Vector3(0.42, 0.06, 0.42), 1400.0, [&"armor", &"shell"], &"plate")
		plate.socket = _socket(Vector3.ZERO)   # overlaps the heart at the origin
		root_gene.children.append(plate)
	return root_gene


func _gene(part_type: StringName, extents: Vector3, density: float,
		tags: Array, part_id: StringName) -> PartGene:
	var g := PartGene.new()
	var d := PartDefinition.new()
	d.part_type = part_type
	d.density = density
	d.extents = extents
	g.definition = d
	var typed: Array[StringName] = []
	for t in tags:
		typed.append(t)
	g.tags = typed
	g.part_id = part_id
	return g


func _socket(pos: Vector3) -> SocketDef:
	var s := SocketDef.new()
	s.id = &"sock"
	s.parent_attachment = Transform3D(Basis.IDENTITY, pos)
	s.child_anchor = Transform3D.IDENTITY
	s.hinge_axis = Vector3.ZERO
	return s
