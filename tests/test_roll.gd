extends SceneTree

## M60 — rolling controller. A curlable (sphere) body in locomotion_mode "roll" pumps angular
## momentum about its lateral axis; ground friction converts the spin into forward translation.
## Honest locomotion (no central-force translation cheat): the body must out-travel a no-drive control.

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
	print("=== M60 rolling controller tests ===")
	await _test_roll()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _ball(mode: StringName) -> PartGene:
	var root := PartGene.new()
	var d := PartDefinition.new()
	d.part_type = &"sphere"
	d.density = 700.0
	d.extents = Vector3(0.35, 0.35, 0.35)
	root.definition = d
	root.tags = [&"spine", &"curlable"]
	var g := GaitDef.new()
	g.locomotion_mode = mode
	g.amplitude_scale = 1.0
	g.frequency_scale = 1.0
	root.gait = g
	return root


func _test_roll() -> void:
	var rolled = await SimRollout.run(_ball(&"roll"), 4.0, 11, self)
	var control = await SimRollout.run(_ball(&""), 4.0, 11, self)
	var roll_dist := float(rolled.get("distance_abs", 0.0))
	var ctrl_dist := float(control.get("distance_abs", 0.0))
	print("  roll distance_abs=%.2f mode_class=%s | control=%.2f" % [
		roll_dist, String(rolled.get("mode_class", "?")), ctrl_dist])
	_check(bool(rolled.get("ok", false)), "roll rollout is finite")
	_check(roll_dist > 0.3, "roll nets real displacement (>0.3m)")
	_check(roll_dist > ctrl_dist + 0.25, "roll drive out-travels the no-drive control")
	_check(not bool(rolled.get("teleport", false)), "roll motion is physical (no teleport)")
