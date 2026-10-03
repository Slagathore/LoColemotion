extends SceneTree

## M52 — flight. Aero lift/drag at the WING (never the root), scaling with v²·A·C and zero when
## airflow or area is zero (E12 anti-rocket). The fly mode is no longer unsupported, and a winged
## glider falls slower than the same body without wings.

const WingBodyScript := preload("res://scripts/sim/wing_body.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
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
	print("=== M52 flight tests ===")
	_test_no_root_force_flight()
	_test_fly_gesture_supported()
	await _test_glider_falls_slower()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


# E12: aero is a wing force scaling with v²·A·C, zero at zero airflow/area — never a root shove.
func _test_no_root_force_flight() -> void:
	print("- aero force is at the wing, scales with v^2/area, zero when still")
	var w = WingBodyScript.new()
	w.wing_area = 0.3
	_check(w.aero_force(Vector3.ZERO) == Vector3.ZERO, "no airflow => no aero force")
	var f1 := w.aero_force(Vector3(0.0, -3.0, 0.0))
	var f2 := w.aero_force(Vector3(0.0, -6.0, 0.0))
	_check(f1.length() > 0.0, "falling wing produces aero force (drag)")
	_check(f2.length() > 3.0 * f1.length(), "aero force scales ~v^2 (double speed -> ~4x)")
	w.wing_area = 0.0
	_check(w.aero_force(Vector3(0.0, -6.0, 0.0)) == Vector3.ZERO, "zero wing area => no aero force")
	# Source: aero is applied to the wing body (state), never a root up-force.
	var src := FileAccess.get_file_as_string("res://scripts/sim/wing_body.gd")
	_check(src.contains("state.apply_central_force") and not src.contains("_root"),
			"aero is applied at the wing body, not the root")


func _test_fly_gesture_supported() -> void:
	print("- fly is no longer an unsupported mode; the glider builds wings")
	var m := {"ok": true, "distance_abs": 5.0, "assist_ratio": 0.1, "slip_ratio": 0.1,
			"teleport": false, "spring_energy_stored": 0.0, "spring_energy_released": 0.0}
	var v := SimRolloutScript.classify_mode(&"fly", m)
	_check(v["class"] != &"unsupported_mode", "fly dispatches to a real gesture, not unsupported")
	_check(bool(v["credible"]), "a translating, finite flight clears the fly gesture")
	var body: Node3D = CreatureBodyScript.build(PartCatalog.make_glider_v2())
	var wings := 0
	for rb in body.call("part_bodies"):
		if rb != null and rb.get_script() == WingBodyScript:
			wings += 1
	body.queue_free()
	await physics_frame
	_check(wings >= 2, "the glider builds wing bodies")


func _test_glider_falls_slower() -> void:
	print("- a winged glider descends slower than the same body without wings")
	var with_drop := await _descent(PartCatalog.make_glider_v2())
	var without_drop := await _descent(_strip_wings(PartCatalog.make_glider_v2()))
	print("  descent with wings=%.3f  without=%.3f" % [with_drop, without_drop])
	_check(with_drop < without_drop, "wings slow the fall (aero drag/lift)")


func _descent(g: PartGene) -> float:
	var world := Node3D.new()
	root.add_child(world)
	var body: Node3D = CreatureBodyScript.build(g, Transform3D(Basis.IDENTITY, Vector3(0.0, 6.0, 0.0)))
	world.add_child(body)
	var bodies: Array = body.call("part_bodies")
	var rb := bodies[0] as RigidBody3D
	var y0 := rb.global_position.y
	for _i in 45:
		await physics_frame
	var drop := y0 - rb.global_position.y
	world.queue_free()
	await physics_frame
	return drop


func _strip_wings(g: PartGene) -> PartGene:
	if g == null:
		return null
	g.tags.erase(&"wing")
	for c in g.children:
		_strip_wings(c)
	return g
