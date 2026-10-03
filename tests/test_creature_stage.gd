extends SceneTree

## M12 Loop-1 scene smoke: the creature actually locomotes to food, eats it, and the
## generation loop advances. Headless (no window) — proves the scene logic is wired.

const CreatureStageScript := preload("res://scripts/game/creature_stage.gd")

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
	print("=== Creature stage (Loop-1) smoke ===")
	var stage = CreatureStageScript.new()
	stage.food_count = 2
	stage.population_size = 3
	stage.food_radius = 3.5     # close patch so foraging completes within the smoke window
	root.add_child(stage)
	# Settle (90) + foraging. Run past GEN_TIME (20s) so the generation loop advances
	# even if the patch isn't fully cleared.
	for _i in 1500:
		await physics_frame
	print("  eaten total=%d  generation=%d" % [stage.total_eaten(), stage.generation()])
	_check(stage.visible_agent_count() >= 3, "stage renders a visible population")
	_check(stage.total_eaten() > 0, "creature locomotes to food and eats at least one morsel")
	_check(stage.generation() >= 1, "clearing/timeout reproduces into the next generation")
	var hist: Array = stage.selection_history()
	if not hist.is_empty():
		_check(bool(hist[-1].get("measured", false)) and not bool(hist[-1].get("synthetic_contact", true)),
				"rendered generation handoff uses measured non-synthetic selection")
	stage.queue_free()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
