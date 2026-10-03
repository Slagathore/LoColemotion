extends SceneTree

## M51 — display layer. The per-part sleeve skin tracks the live body (kills the "shed skin"); the
## continuous baked skin is honestly static; palette round-trips; FUN-2 fossil ghost + FUN-1 force
## x-ray have real data feeds. (Overlay/wireframe/palette-picker RENDERING is play-tested.)

const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const FossilRecorderScript := preload("res://scripts/sim/fossil_recorder.gd")
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
	print("=== M51 display tests ===")
	await _test_sleeve_skin_tracks_body()
	_test_palette_round_trips()
	_test_fossil_ghost()
	await _test_force_xray()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


# B6/E11: the per-part sleeve follows the live body (so it doesn't get left behind at spawn).
func _test_sleeve_skin_tracks_body() -> void:
	print("- the per-part sleeve skin tracks the live body")
	var world := Node3D.new()
	root.add_child(world)
	var body: Node3D = CreatureBodyScript.build(PartCatalog.make_quadruped(false))
	world.add_child(body)
	var skin := SkinBuilder.build_display_skin(body)
	world.add_child(skin)
	var mesh := _first_part_mesh(skin)
	_check(mesh != null, "the display skin has a per-part mesh (trackable, not a static blob)")
	if mesh != null:
		var before := mesh.global_position
		var idx := int(mesh.get_meta("source_part_index"))
		var bodies: Array = body.call("part_bodies")
		(bodies[idx] as RigidBody3D).global_position += Vector3(3.0, 0.0, 0.0)
		SkinBuilder.update_display_skin(skin, body)
		var moved := mesh.global_position.distance_to(before)
		print("  skin mesh moved %.2f m with its body" % moved)
		_check(moved > 2.0, "the sleeve mesh follows its part (no shed skin)")
	world.queue_free()
	await physics_frame


func _test_palette_round_trips() -> void:
	print("- a display palette round-trips with the creature card")
	var card := CreatureCard.new()
	card.root = PartCatalog.make_quadruped(false)
	card.palette = {"base": Color(0.8, 0.2, 0.5).to_html(), "pattern": "stripes"}
	var path := "user://_test_palette_card.tres"
	_check(CreatureIO.save(card, path) == OK, "card with palette saves")
	var loaded := CreatureIO.load(path)
	_check(loaded != null and String(loaded.palette.get("pattern", "")) == "stripes"
			and String(loaded.palette.get("base", "")) == Color(0.8, 0.2, 0.5).to_html(),
			"palette base + pattern survive save/load")


func _test_fossil_ghost() -> void:
	print("- the fossil recorder records ancestors and replays their path")
	var rec = FossilRecorderScript.new()
	rec.record(0, PartCatalog.make_quadruped(false),
			[Vector3.ZERO, Vector3(0, 0, -2), Vector3(0, 0, -4)], 3.0)
	rec.record(1, PartCatalog.make_quadruped(false),
			[Vector3.ZERO, Vector3(0, 0, -6)], 6.0)
	_check(rec.count() == 2, "two fossils recorded")
	_check(rec.ghost_genome(0) != null, "ancestor genome reconstructs for the ghost body")
	var mid := rec.replay_position(0, 0.5)
	_check(mid.is_equal_approx(Vector3(0, 0, -2)), "ghost replays the midpoint of its path")
	_check(rec.improved(), "gen 1 (fitness 6) improved on gen 0 (fitness 3)")


func _test_force_xray() -> void:
	print("- force x-ray exposes per-joint torque vectors")
	var world := Node3D.new()
	root.add_child(world)
	SimWorldScript.add_floor(world, 1.0)
	var gene := PartCatalog.make_quadruped(false)
	var body: Node3D = CreatureBodyScript.build(gene, Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 0)))
	world.add_child(body)
	var ctrl := CpgControllerScript.new()
	ctrl.call("bind", body, gene, null)
	world.add_child(ctrl)
	for i in 20:
		ctrl.call("tick", float(i) / 60.0, 1.0 / 60.0)
		await physics_frame
	var xray: Array = ctrl.call("force_xray")
	_check(xray.size() >= 1, "force x-ray returns a vector per driven joint")
	if not xray.is_empty():
		_check((xray[0]["torque"] as Vector3).is_finite(), "torque vectors are finite")
	world.queue_free()
	await physics_frame


func _first_part_mesh(skin: Node) -> MeshInstance3D:
	for c in skin.get_children():
		if c is MeshInstance3D and c.has_meta("source_part_index"):
			return c
	return null
