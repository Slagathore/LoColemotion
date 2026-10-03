class_name AdversarialTrainer
extends RefCounted

## M48 — self-play combat training. The combat fitness is ASYNC (each evaluation runs a physics
## bout in an isolated world), so it can't ride EvolutionEngine.step's synchronous analytic scorer.
## This is its explicit adapter: `BoutFitness` (a named Resource, not a bare closure) scores a genome
## by `AdversarialBout.run_bout` against a FIXED opponent pool (deterministic holdouts → repeatable
## fitness), and `train` runs a generational mutate→select loop on top. reward = damage_dealt -
## damage_taken + survival, so locomotion + strike + defense co-train. The M38 universal floor still
## gates each combatant (anti-flail). A `negative control` flag (random selection) proves SELECTION,
## not noise, drives any improvement (E6).

const AdversarialBoutScript := preload("res://scripts/sim/adversarial_bout.gd")


class BoutFitness:
	extends Resource
	var opponents: Array = []          # fixed opponent pool (PartGene) — the holdout
	var horizon_s := 1.2
	var seed := 7

	# Mean (damage_dealt - damage_taken) across the opponent pool. Deterministic for fixed pool+seed.
	func score(genome: PartGene, tree: SceneTree) -> float:
		if opponents.is_empty() or genome == null:
			return 0.0
		var total := 0.0
		for opp in opponents:
			var p := AdversarialBoutScript.BoutParams.new()
			p.horizon_s = horizon_s
			var r: Dictionary = await AdversarialBoutScript.run_bout(genome, opp, tree, p)
			# Anti-flail: a winner that teleported/exploded forfeits the round (M38 floor).
			var a_ok := bool(r.get("a_floor_ok", false))
			total += float(r.get("a_score", 0.0)) * (1.0 if a_ok else 0.25)
		return total / float(opponents.size())


static func score_population(population: Array, fitness: BoutFitness, tree: SceneTree) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(population.size())
	for i in population.size():
		out[i] = await fitness.score(population[i], tree)
	return out


# A generational self-play loop. `negative_control = true` disables selection (random parent) so a
# campaign can prove that selection — not mutation noise — is what improves combat fitness.
static func train(seed_root: PartGene, fitness: BoutFitness, tree: SceneTree,
		generations := 3, population_size := 6, mut_cfg = null,
		negative_control := false, rng_seed := 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var population := EvolutionEngine.initial_population(seed_root, population_size, rng_seed, mut_cfg)
	var history: Array = []
	var champion: PartGene = GenomeSnapshot.deep_copy(seed_root)
	var champion_fit := -INF
	for gen in maxi(generations, 1):
		var fits := await score_population(population, fitness, tree)
		var best_i := 0
		for i in fits.size():
			if fits[i] > fits[best_i]:
				best_i = i
		history.append({"gen": gen, "best": float(fits[best_i]), "mean": _mean(fits)})
		if float(fits[best_i]) > champion_fit:
			champion_fit = float(fits[best_i])
			champion = GenomeSnapshot.deep_copy(population[best_i])
		# Next generation: elite + offspring of selected (or random, for the negative control).
		var next: Array[PartGene] = [GenomeSnapshot.deep_copy(population[best_i])]
		while next.size() < population_size:
			var parent: PartGene
			if negative_control:
				parent = population[rng.randi_range(0, population.size() - 1)]   # no selection
			else:
				parent = population[_tournament(fits, rng)]
			next.append(GenomeMutator.mutate(parent, mut_cfg, rng))
		population = next
	return {"champion": champion, "champion_fit": champion_fit, "history": history}


static func _tournament(fits: PackedFloat32Array, rng: RandomNumberGenerator, size := 3) -> int:
	var best := rng.randi_range(0, fits.size() - 1)
	for _i in maxi(1, size):
		var c := rng.randi_range(0, fits.size() - 1)
		if fits[c] > fits[best]:
			best = c
	return best


static func _mean(fits: PackedFloat32Array) -> float:
	if fits.is_empty():
		return 0.0
	var s := 0.0
	for f in fits:
		s += f
	return s / float(fits.size())
