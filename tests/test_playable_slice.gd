extends SceneTree

## Playable-slice end-to-end: editor card -> evolve -> bout. This stitches the three
## player-facing stages together on a tiny config to prove the whole loop holds:
##   1. An "edited" creature comes off the editor (PartCatalog.make_quadruped(false)).
##   2. CreatureStageLoop.run_measured_loop2 evolves a small population around it.
##   3. AdversarialBout.run_bout pits the edited creature against an evolved champion.
## It asserts the stage loop returns ok with a non-empty population, and the bout returns
## ok with a legal winner and a non-empty quip — i.e. the slice is wired end to end.

const CSL := preload("res://scripts/sim/creature_stage_loop.gd")
const AdversarialBoutScript := preload("res://scripts/sim/adversarial_bout.gd")

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
	print("=== Playable slice (editor -> evolve -> bout) tests ===")
	await _test_slice_end_to_end()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_slice_end_to_end() -> void:
	# 1. Editor card: the creature the player just finished editing.
	var edited: PartGene = PartCatalog.make_quadruped(false)
	_check(edited != null, "editor card produces a creature to evolve")

	# 2. Evolve a tiny population around the edited creature.
	var cfg := CSL.Config.new()
	cfg.population_size = 4
	cfg.generations = 1
	cfg.horizon = 1.5
	cfg.prescreen_keep = 2     # keep the physical-measure work small/fast
	cfg.food_count = 4
	cfg.hazard_count = 1
	cfg.agent_count = 1
	cfg.seed = 31
	var loop: Dictionary = await CSL.run_measured_loop2(edited, cfg, self)
	_check(bool(loop.get("ok", false)), "stage loop returns ok")
	var population: Array = loop.get("population", [])
	_check(not population.is_empty(),
			"stage loop returns a non-empty population (%d)" % population.size())

	# 3. Bout: the edited creature vs. an evolved champion from the population.
	#    population[0] is the top survivor (selection ranks survivors first).
	var champion: PartGene = population[0] if not population.is_empty() else edited
	_check(champion != null, "an evolved champion is available for the bout")
	var bout: Dictionary = await AdversarialBoutScript.run_bout(edited, champion, self)
	print("  bout: winner=%s a_score=%.2f b_score=%.2f quip=%s" % [
			String(bout.get("winner", "?")), float(bout.get("a_score", 0.0)),
			float(bout.get("b_score", 0.0)), String(bout.get("quip", ""))])
	_check(bool(bout.get("ok", false)), "bout returns ok")
	var winner: StringName = bout.get("winner", &"")
	_check(winner == &"a" or winner == &"b" or winner == &"draw",
			"bout winner is one of {a, b, draw} (got '%s')" % String(winner))
	_check(not String(bout.get("quip", "")).is_empty(), "bout returns a non-empty quip")
