extends SceneTree

const EvolutionEngineScript := preload("res://scripts/sim/evolution_engine.gd")
const GenomeMutatorScript := preload("res://scripts/sim/genome_mutator.gd")
const LineageScript := preload("res://scripts/sim/lineage.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== EvolutionEngine tests ===")
	_test_seed_replay_and_elitism()
	_test_parallel_equals_serial()
	_test_save_champion_reload_rescores()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _mut_cfg():
	var c = GenomeMutatorScript.Config.new()
	c.param_rate = 1.0
	c.gait_rate = 1.0
	c.topology_rate = 0.35
	return c


func _evo_cfg(seed: int, lineage: Resource = null):
	var c = EvolutionEngineScript.Config.new()
	c.seed = seed
	c.population_size = 18
	c.elite_count = 2
	c.tournament_size = 3
	c.crossover_rate = 0.20
	c.mutation_cfg = _mut_cfg()
	c.lineage = lineage
	return c


func _spec():
	var s = EvolutionEngineScript.FitnessSpec.new()
	s.require_stable = false
	return s


func _signature_population(pop: Array[PartGene]) -> String:
	var sigs: Array[String] = []
	for g in pop:
		sigs.append(EvolutionEngineScript.genome_signature(g))
	sigs.sort()
	return "\n".join(sigs)


func _test_seed_replay_and_elitism() -> void:
	print("- fixed seed replays and best-seen fitness is non-decreasing")
	var lineage_a: Resource = LineageScript.new()
	var lineage_b: Resource = LineageScript.new()
	var cfg_a = _evo_cfg(111, lineage_a)
	var cfg_b = _evo_cfg(111, lineage_b)
	var spec = _spec()
	var pop_a := EvolutionEngineScript.initial_population(PartCatalog.make_quadruped(false),
			cfg_a.population_size, cfg_a.seed, cfg_a.mutation_cfg)
	var pop_b := EvolutionEngineScript.initial_population(PartCatalog.make_quadruped(false),
			cfg_b.population_size, cfg_b.seed, cfg_b.mutation_cfg)
	var best_seen := -INF
	var monotonic := true
	for _i in 5:
		var before := EvolutionEngineScript.best_fitness(pop_a, spec)
		best_seen = maxf(best_seen, before)
		pop_a = EvolutionEngineScript.step(pop_a, spec, cfg_a)
		pop_b = EvolutionEngineScript.step(pop_b, spec, cfg_b)
		var after_best_seen := maxf(best_seen, EvolutionEngineScript.best_fitness(pop_a, spec))
		monotonic = monotonic and after_best_seen >= best_seen
		best_seen = after_best_seen
	_check(_signature_population(pop_a) == _signature_population(pop_b), "same seed -> identical final population")
	_check(lineage_a.edges.size() == lineage_b.edges.size(), "same seed -> identical lineage edge count")
	_check(monotonic, "best-seen-so-far fitness is non-decreasing")


func _test_parallel_equals_serial() -> void:
	print("- worker evaluation equals serial evaluation")
	var cfg = _evo_cfg(222)
	var spec = _spec()
	var pop := EvolutionEngineScript.initial_population(PartCatalog.make_quadruped(false),
			32, cfg.seed, cfg.mutation_cfg)
	var serial := EvolutionEngineScript.evaluate_population_serial(pop, spec)
	var parallel := EvolutionEngineScript.evaluate_population_parallel(pop, spec)
	var same := serial.size() == parallel.size()
	for i in serial.size():
		same = same and serial[i] == parallel[i]
	_check(same, "parallel fitness exactly equals serial fitness")


func _test_save_champion_reload_rescores() -> void:
	print("- saved champion reloads and rescoring is identical")
	var cfg = _evo_cfg(333)
	var spec = _spec()
	var pop := EvolutionEngineScript.initial_population(PartCatalog.make_quadruped(false),
			cfg.population_size, cfg.seed, cfg.mutation_cfg)
	pop = EvolutionEngineScript.step(pop, spec, cfg)
	var idx := EvolutionEngineScript.best_index(pop, spec)
	var before := spec.score(CharacteristicsEvaluator.evaluate(pop[idx]))
	var path := "user://_sporespore_champion.tres"
	_check(EvolutionEngineScript.save_champion(pop, spec, path, "Champion") == OK,
			"champion save returns OK")
	var loaded := CreatureIO.load(path)
	var after := spec.score(CharacteristicsEvaluator.evaluate(loaded.root))
	_check(loaded != null, "champion reloads through CreatureIO")
	_check(before == after, "reloaded champion fitness is identical")
