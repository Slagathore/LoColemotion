class_name CoevolutionEngine
extends RefCounted

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")

## Body + controller co-evolution v1. Each generation mutates BOTH morphology and
## gait (GenomeMutator.Config perturbs scale/topology via param/topology rates AND
## the gait via gait_rate), then scores every candidate by a MEASURED rollout (not
## the analytic probe). The best candidate survives by elitism. Defaults are kept
## tiny so a headless test finishes in well under a minute.


static func evolve(seed_root: PartGene, tree: SceneTree, generations := 2,
		population_size := 4, horizon := 1.5, rng_seed := 1,
		mutation_cfg = null) -> Dictionary:
	if seed_root == null or tree == null:
		return {"champion": null, "champion_fitness": -INF, "history": []}
	var pop_size := maxi(1, population_size)
	var gens := maxi(1, generations)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	# Caller-supplied mutation rates (e.g. a tuned walker wants topology_rate near 0 —
	# add/remove parts rarely helps a converged rig and breaks gait socket references).
	var mut_cfg: GenomeMutator.Config = mutation_cfg if mutation_cfg != null \
			else GenomeMutator.Config.new()

	var champion := GenomeSnapshot.deep_copy(seed_root)
	var champion_fitness := await _measure(champion, tree, horizon, rng_seed)
	var history: Array = []

	for gen in gens:
		var population: Array[PartGene] = [GenomeSnapshot.deep_copy(champion)]
		while population.size() < pop_size:
			# Mutates BOTH morphology AND gait in one call (see Config rates above).
			var child := GenomeMutator.mutate(champion, mut_cfg, rng)
			if child == null:
				child = GenomeSnapshot.deep_copy(champion)
			population.append(child)

		var best_idx := -1
		var best_fit := -INF
		var fit_sum := 0.0
		var fit_count := 0
		for i in population.size():
			# Deterministic per-candidate seed keeps the rollout reproducible.
			var seed := int((rng_seed * 2654435761 + (gen + 1) * 40503 + (i + 1) * 97) & 0x7fffffff)
			var fit := await _measure(population[i], tree, horizon, seed)
			if is_finite(fit):
				fit_sum += fit
				fit_count += 1
			if fit > best_fit:
				best_fit = fit
				best_idx = i

		# Elitism: only adopt the generation's best if it does not regress the
		# champion. The champion was re-injected at index 0, so best_fit >= its
		# fresh score here, but guard against rollout noise anyway.
		if best_idx >= 0 and best_fit >= champion_fitness:
			champion = GenomeSnapshot.deep_copy(population[best_idx])
			champion_fitness = best_fit

		var mean := best_fit if fit_count == 0 else fit_sum / float(fit_count)
		history.append({"gen": gen, "best": best_fit, "mean": mean})

	return {
		"champion": champion,
		"champion_fitness": champion_fitness,
		"history": history,
	}


# Shaped rollout fitness, mirroring GaitOptimizer._evaluate's scoring: below the
# credible-walk gate, reward bounded forward progress + sustained tail and punish
# falls; above it, forward + heavily-weighted tail. Raw forward alone let a body
# search win by lurch-and-tip (a 3 m face-plant scored 3.0).
static func rollout_fitness(r: Dictionary) -> float:
	var forward := float(r.get("forward", -INF))
	if not bool(r.get("ok", false)) or not is_finite(forward):
		return -INF
	var tail := float(r.get("forward_tail", 0.0))
	var lateral := absf(float(r.get("lateral", 0.0)))
	var fell := bool(r.get("fell", false))
	if not bool(r.get("credible_walk", false)):
		return -10.0 + minf(forward, SimRolloutScript.CREDIBLE_FORWARD_M) + 0.25 * tail \
				- 0.3 * lateral - (5.0 if fell else 0.0)
	return forward + 3.0 * tail - 0.3 * lateral


static func _measure(gene: PartGene, tree: SceneTree, horizon: float, seed: int) -> float:
	if gene == null:
		return -INF
	var r: Dictionary = await SimRolloutScript.run(gene, horizon, seed, tree)
	return rollout_fitness(r)
