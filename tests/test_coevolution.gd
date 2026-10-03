extends SceneTree

const CoevolutionEngineScript := preload("res://scripts/sim/coevolution_engine.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Coevolution tests ===")
	await _test_coevolution_returns_non_regressing_champion()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_coevolution_returns_non_regressing_champion() -> void:
	print("- body+controller co-evolution yields a finite, non-regressing champion")
	var seed_root := PartCatalog.make_quadruped(false)
	var rng_seed := 1

	# Baseline: the engine measures the seed root at seed == rng_seed; mirror that
	# exactly (same shaped fitness) so the no-regression comparison is apples-to-apples.
	var seed_r: Dictionary = await SimRolloutScript.run(seed_root, 1.5, rng_seed, self)
	var initial_fitness := CoevolutionEngineScript.rollout_fitness(seed_r)
	print("  seed root measured fitness = %.4f (forward %.4f)" % [
			initial_fitness, float(seed_r.get("forward", 0.0))])

	var result: Dictionary = await CoevolutionEngineScript.evolve(
			seed_root, self, 2, 4, 1.5, rng_seed)
	var champion = result.get("champion", null)
	var champion_fitness := float(result.get("champion_fitness", -INF))
	var history: Array = result.get("history", [])
	print("  champion_fitness = %.4f over %d generations" % [champion_fitness, history.size()])

	# (a) non-null champion PartGene and finite fitness
	_check(champion != null and champion is PartGene, "evolve returns a non-null champion PartGene")
	_check(is_finite(champion_fitness), "champion_fitness is finite")

	# history shape: per-gen {gen, best, mean}
	_check(history.size() == 2, "history has one entry per generation")
	var shape_ok := true
	for h in history:
		if not (h is Dictionary and h.has("gen") and h.has("best") and h.has("mean")):
			shape_ok = false
	_check(shape_ok, "each history row has gen/best/mean")

	# (b) co-evolution does not regress: champion >= seed root - small epsilon
	_check(champion_fitness >= initial_fitness - 0.05,
			"champion does not regress below seed root (within 0.05m epsilon)")
