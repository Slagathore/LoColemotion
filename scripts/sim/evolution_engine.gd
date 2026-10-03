class_name EvolutionEngine
extends RefCounted

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

## Analytic GA over PartGene trees. Fitness is probe-based and deterministic for
## a fixed seed/generation.

class FitnessSpec:
	extends Resource
	var speed_w := 1.0
	var debt_w := 0.35
	var balance_w := 0.35
	var require_stable := false
	var unstable_penalty := 0.35

	func score(eval: Dictionary) -> float:
		var speed := float(eval["speed"]["value"])
		var debt := float(eval["debt"]["debt_total"])
		var balance: Dictionary = eval["balance"]
		var stable := bool(balance["stable"])
		var margin := float(balance["balance_margin"])
		var stability_term := clampf(margin, -1.0, 1.0) * balance_w
		var raw := speed_w * speed + stability_term - debt_w * debt
		if require_stable and not stable:
			return raw - unstable_penalty
		if not stable:
			return raw - unstable_penalty * 0.5
		return raw


class Config:
	extends Resource
	var seed := 1
	var generation := 0
	var population_size := 24
	var elite_count := 2
	var tournament_size := 3
	var crossover_rate := 0.15
	var mutation_cfg = null
	var lineage = null


static func step(population: Array[PartGene], spec, cfg) -> Array[PartGene]:
	var c: Config = cfg as Config
	if c == null:
		c = Config.new()
	var s: FitnessSpec = spec as FitnessSpec
	if s == null:
		s = FitnessSpec.new()
	if population.is_empty():
		return []
	var fitness := evaluate_population_serial(population, s)
	var ranked := _ranked_indices(population, fitness)
	var next: Array[PartGene] = []
	var elite_n := clampi(c.elite_count, 1, population.size())
	for i in elite_n:
		next.append(GenomeSnapshot.deep_copy(population[ranked[i]]))
	var rng := RandomNumberGenerator.new()
	rng.seed = _generation_seed(c.seed, c.generation)
	while next.size() < c.population_size:
		var pa_idx := _tournament(ranked, fitness, c.tournament_size, rng)
		var pb_idx := _tournament(ranked, fitness, c.tournament_size, rng)
		var child: PartGene
		if rng.randf() < c.crossover_rate:
			child = GenomeMutator.crossover(population[pa_idx], population[pb_idx],
					c.mutation_cfg, rng)
		else:
			child = GenomeSnapshot.deep_copy(population[pa_idx])
		child = GenomeMutator.mutate(child, c.mutation_cfg, rng)
		next.append(child)
		if c.lineage != null:
			c.lineage.record_child(c.generation, genome_signature(population[pa_idx]),
					genome_signature(population[pb_idx]), genome_signature(child), s.score(CE.evaluate(child)))
	if c.lineage != null:
		var best_idx := ranked[0]
		c.lineage.record_best(c.generation, genome_signature(population[best_idx]), fitness[best_idx])
	c.generation += 1
	return next


static func evaluate_population_serial(population: Array[PartGene], spec) -> PackedFloat32Array:
	var s: FitnessSpec = spec as FitnessSpec
	if s == null:
		s = FitnessSpec.new()
	var out := PackedFloat32Array()
	out.resize(population.size())
	for i in population.size():
		out[i] = s.score(CE.evaluate(GenomeSnapshot.deep_copy(population[i])))
	return out


static func evaluate_population_parallel(population: Array[PartGene], spec) -> PackedFloat32Array:
	var s: FitnessSpec = spec as FitnessSpec
	if s == null:
		s = FitnessSpec.new()
	var boxes: Array[Dictionary] = []
	var tasks: Array[int] = []
	for i in population.size():
		var box := {"fitness": 0.0}
		boxes.append(box)
		var snap := GenomeSnapshot.deep_copy(population[i])
		var tid := WorkerThreadPool.add_task(func():
			box["fitness"] = s.score(CE.evaluate(snap))
		)
		tasks.append(tid)
	for tid in tasks:
		WorkerThreadPool.wait_for_task_completion(tid)
	var out := PackedFloat32Array()
	out.resize(population.size())
	for i in boxes.size():
		out[i] = float(boxes[i]["fitness"])
	return out


static func best_index(population: Array[PartGene], spec) -> int:
	if population.is_empty():
		return -1
	var fitness := evaluate_population_serial(population, spec)
	return _ranked_indices(population, fitness)[0]


static func best_fitness(population: Array[PartGene], spec) -> float:
	var idx := best_index(population, spec)
	if idx < 0:
		return -INF
	return evaluate_population_serial(population, spec)[idx]


static func initial_population(seed_root: PartGene, size: int, seed: int, mut_cfg = null) -> Array[PartGene]:
	var out: Array[PartGene] = []
	if seed_root == null:
		return out
	out.append(GenomeSnapshot.deep_copy(seed_root))
	for i in range(1, size):
		var rng := RandomNumberGenerator.new()
		rng.seed = _generation_seed(seed, i)
		out.append(GenomeMutator.mutate(seed_root, mut_cfg, rng))
	return out


static func save_champion(population: Array[PartGene], spec, path: String,
		display_name := "Analytic Champion") -> Error:
	var idx := best_index(population, spec)
	if idx < 0:
		return ERR_INVALID_PARAMETER
	var card := CreatureCard.new()
	card.display_name = display_name
	card.root = population[idx]
	card.notes = "Saved by EvolutionEngine analytic fitness."
	return CreatureIO.save(card, path)


static func genome_signature(root: PartGene) -> String:
	var parts: Array[String] = []
	_sig_gene(root, parts)
	return "|".join(parts)


static func _sig_gene(g: PartGene, out: Array[String]) -> void:
	if g == null:
		out.append("null")
		return
	var def_sig := "nodef"
	if g.definition != null:
		def_sig = "%s:%.4f:%s:%s" % [String(g.definition.part_type), g.definition.density,
				str(g.definition.extents), str(g.definition.centroid_offset)]
	var socket_sig := "nosocket"
	if g.socket != null:
		socket_sig = "%s:%s:%s" % [String(g.socket.id), str(g.socket.parent_attachment.origin),
				str(g.socket.hinge_axis)]
	var joint_sig := "nojoint"
	if g.joint != null:
		joint_sig = "%.4f:%.4f:%.4f:%.4f" % [g.joint.amplitude, g.joint.rest_angle,
				g.joint.angle_min, g.joint.angle_max]
	var gait_sig := "nogait"
	if g.gait != null:
		var assignments: Array[String] = []
		for key in g.gait.assignments.keys():
			assignments.append("%s=%.4f" % [String(key), float(g.gait.assignments[key])])
		assignments.sort()
		gait_sig = "%s:a=%.4f:f=%.4f:g=%.4f:t=%.4f:p=%.4f:turn=%.4f:%s" % [
			String(g.gait.pattern),
			g.gait.amplitude_scale,
			g.gait.frequency_scale,
			g.gait.gain_scale,
			g.gait.traction_scale,
			g.gait.posture_scale,
			g.gait.turn_rate,
			",".join(assignments),
		]
	out.append("%s;%s;%s;%s;%s;%s;%d" % [def_sig, socket_sig, joint_sig, gait_sig,
			str(g.scale), String(g.part_id), g.children.size()])
	for child in g.children:
		_sig_gene(child, out)


static func _ranked_indices(population: Array[PartGene], fitness: PackedFloat32Array) -> Array[int]:
	var idxs: Array[int] = []
	for i in population.size():
		idxs.append(i)
	idxs.sort_custom(func(a: int, b: int) -> bool:
		if fitness[a] == fitness[b]:
			return genome_signature(population[a]) < genome_signature(population[b])
		return fitness[a] > fitness[b]
	)
	return idxs


static func _tournament(ranked: Array[int], fitness: PackedFloat32Array, size: int,
		rng: RandomNumberGenerator) -> int:
	var best := ranked[ranked.size() - 1]
	var best_fit := -INF
	for _i in maxi(1, size):
		var candidate := ranked[rng.randi_range(0, ranked.size() - 1)]
		if fitness[candidate] > best_fit:
			best = candidate
			best_fit = fitness[candidate]
	return best


static func _generation_seed(seed: int, generation: int) -> int:
	return int((int(seed) * 1103515245 + int(generation) * 12345 + 0x5f3759df) & 0x7fffffff)
