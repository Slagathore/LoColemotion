extends SceneTree

const OUT_PATH := "res://data/creatures/analytic_champion.tres"


func _initialize() -> void:
	var mut_cfg := GenomeMutator.Config.new()
	var cfg := EvolutionEngine.Config.new()
	cfg.seed = 4242
	cfg.population_size = 24
	cfg.elite_count = 2
	cfg.tournament_size = 3
	cfg.mutation_cfg = mut_cfg
	cfg.lineage = Lineage.new()
	var spec := EvolutionEngine.FitnessSpec.new()
	spec.require_stable = false
	var pop := EvolutionEngine.initial_population(PartCatalog.make_quadruped(false),
			cfg.population_size, cfg.seed, mut_cfg)
	for _g in 8:
		pop = EvolutionEngine.step(pop, spec, cfg)
	var err := EvolutionEngine.save_champion(pop, spec, OUT_PATH, "Analytic Champion")
	print("Evolution run complete: save=%s best=%.5f path=%s" %
			[err, EvolutionEngine.best_fitness(pop, spec), OUT_PATH])
	quit(0 if err == OK else 1)
