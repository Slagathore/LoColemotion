class_name CreatureStageLoop
extends RefCounted

const CombatResolverScript := preload("res://scripts/sim/combat.gd")

## Headless creature-stage MVP loop: locomotion score -> food gathered -> energy
## -> reproduction -> selection. This is the game-loop contract before a scene UI.


class Config:
	extends Resource
	var seed := 1
	var population_size := 6
	var food_count := 10
	var generations := 1
	var mutation_cfg = null
	var horizon := 3.0          # measured rollout length per creature (run_measured)
	var prescreen_keep := 0     # measured: analytic finalists to physically measure (0 = half pop)
	var hazard_count := 2       # Loop-2 ecology pressure
	var agent_count := 2        # Loop-2 other-creature encounters
	var hazard_severity := 0.35
	var selection_mode: StringName = &"fitness"  # fitness | random (M26 degraded control)


static func run(seed_root: PartGene, cfg: Config = null) -> Dictionary:
	var c := cfg if cfg != null else Config.new()
	var pop := EvolutionEngine.initial_population(seed_root, c.population_size, c.seed, c.mutation_cfg)
	var rng := RandomNumberGenerator.new()
	rng.seed = c.seed
	var history: Array = []
	for gen in c.generations:
		var scored := _score_population(pop, c.food_count)
		scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["energy"]) > float(b["energy"])
		)
		var survivors := _select_survivors(scored, c, rng)
		var next: Array[PartGene] = []
		for s in survivors:
			next.append(GenomeSnapshot.deep_copy(s))
		while next.size() < c.population_size and not survivors.is_empty():
			var parent: PartGene = survivors[rng.randi_range(0, survivors.size() - 1)]
			next.append(GenomeMutator.mutate(parent, c.mutation_cfg, rng))
		history.append({
			"generation": gen,
			"best_energy": float(scored[0]["energy"]) if not scored.is_empty() else 0.0,
			"best_food": int(scored[0]["food"]) if not scored.is_empty() else 0,
			"survivors": survivors.size(),
			"population": next.size(),
		})
		pop = next
	return {
		"ok": not pop.is_empty(),
		"population": pop,
		"history": history,
		"generations": c.generations,
	}


# Measured Loop-1: each generation the analytic evaluator PRE-SCREENS (cheap cull),
# then finalists are physically MEASURED with SimRollout — real locomotion decides who
# eats and reproduces. Survival is earned in physics, not asserted by the probe.
# (REV M12: "the evaluator pre-screens; the trainer tunes survivors' gaits.")
static func run_measured(seed_root: PartGene, cfg: Config, tree: SceneTree) -> Dictionary:
	var c := cfg if cfg != null else Config.new()
	if tree == null:
		return {"ok": false, "error": "run_measured needs a SceneTree"}
	var pop := EvolutionEngine.initial_population(seed_root, c.population_size, c.seed, c.mutation_cfg)
	var rng := RandomNumberGenerator.new()
	rng.seed = c.seed
	var history: Array = []
	for gen in c.generations:
		var scored := await measure_population(pop, c, tree, gen)
		var survivors: Array[PartGene] = []
		for i in mini(scored.size(), maxi(1, c.population_size / 2)):
			survivors.append(scored[i]["root"])
		var next: Array[PartGene] = []
		for s in survivors:
			next.append(GenomeSnapshot.deep_copy(s))
		while next.size() < c.population_size and not survivors.is_empty():
			var parent: PartGene = survivors[rng.randi_range(0, survivors.size() - 1)]
			next.append(GenomeMutator.mutate(parent, c.mutation_cfg, rng))
		var row := {
			"generation": gen,
			"best_energy": float(scored[0]["energy"]) if not scored.is_empty() else 0.0,
			"best_food": int(scored[0]["food"]) if not scored.is_empty() else 0,
			"best_forward": float(scored[0]["forward"]) if not scored.is_empty() else 0.0,
			"survivors": survivors.size(),
			"population": next.size(),
			"selection_mode": String(c.selection_mode),
		}
		row.merge(_population_stats(scored), true)
		history.append(row)
		pop = next
	return {"ok": not pop.is_empty(), "population": pop, "history": history,
		"generations": c.generations, "measured": true}


# Loop-2 deterministic ecology/combat layer. This runs after Loop 1 exists: food
# still rewards locomotion, hazards punish fragile bodies, and other creatures act
# as agents that can fight or be avoided. It is headless so tuning can run in CI.
static func run_loop2(seed_root: PartGene, cfg: Config = null) -> Dictionary:
	var c := cfg if cfg != null else Config.new()
	var pop := EvolutionEngine.initial_population(seed_root, c.population_size, c.seed, c.mutation_cfg)
	var rng := RandomNumberGenerator.new()
	rng.seed = c.seed
	var history: Array = []
	for gen in c.generations:
		var scored := _score_population_loop2(pop, c, rng)
		scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["energy"]) > float(b["energy"])
		)
		var survivors := _select_survivors(scored, c, rng, true)
		if survivors.is_empty() and not scored.is_empty():
			survivors.append(scored[0]["root"])
		var next: Array[PartGene] = []
		for s in survivors:
			next.append(GenomeSnapshot.deep_copy(s))
		while next.size() < c.population_size and not survivors.is_empty():
			var parent: PartGene = survivors[rng.randi_range(0, survivors.size() - 1)]
			next.append(GenomeMutator.mutate(parent, c.mutation_cfg, rng))
		history.append({
			"generation": gen,
			"best_energy": float(scored[0]["energy"]) if not scored.is_empty() else 0.0,
			"best_food": int(scored[0]["food"]) if not scored.is_empty() else 0,
			"deaths": _count_dead(scored),
			"combat_events": _sum_int(scored, "combat_events"),
			"contact_events": _sum_int(scored, "contact_events"),
			"hazard_hits": _sum_int(scored, "hazard_hits"),
			"contact_damage": _sum_float(scored, "contact_damage"),
			"survivors": survivors.size(),
			"population": next.size(),
		})
		pop = next
	return {"ok": not pop.is_empty(), "population": pop, "history": history,
		"generations": c.generations, "loop": 2}


# Measured Loop-2: locomotion/food is measured through SimRollout and ecology/combat
# pressure is measured through the real contact primitive added in M20. The older
# run_loop2() remains as an analytic preview; this is the stage-truth path.
static func run_measured_loop2(seed_root: PartGene, cfg: Config, tree: SceneTree) -> Dictionary:
	var c := cfg if cfg != null else Config.new()
	if tree == null:
		return {"ok": false, "error": "run_measured_loop2 needs a SceneTree"}
	var pop := EvolutionEngine.initial_population(seed_root, c.population_size, c.seed, c.mutation_cfg)
	var rng := RandomNumberGenerator.new()
	rng.seed = c.seed
	var history: Array = []
	for gen in c.generations:
		var scored := await measure_population_loop2(pop, c, tree, rng, gen)
		var survivors: Array[PartGene] = []
		for i in mini(scored.size(), maxi(1, c.population_size / 2)):
			if bool(scored[i].get("alive", false)):
				survivors.append(scored[i]["root"])
		if survivors.is_empty() and not scored.is_empty():
			survivors.append(scored[0]["root"])
		var next: Array[PartGene] = []
		for s in survivors:
			next.append(GenomeSnapshot.deep_copy(s))
		while next.size() < c.population_size and not survivors.is_empty():
			var parent: PartGene = survivors[rng.randi_range(0, survivors.size() - 1)]
			next.append(GenomeMutator.mutate(parent, c.mutation_cfg, rng))
		var row := {
			"generation": gen,
			"best_energy": float(scored[0]["energy"]) if not scored.is_empty() else 0.0,
			"best_food": int(scored[0]["food"]) if not scored.is_empty() else 0,
			"best_forward": float(scored[0]["forward"]) if not scored.is_empty() else 0.0,
			"deaths": _count_dead(scored),
			"combat_events": _sum_int(scored, "combat_events"),
			"contact_events": _sum_int(scored, "contact_events"),
			"hazard_hits": _sum_int(scored, "hazard_hits"),
			"contact_damage": _sum_float(scored, "contact_damage"),
			"survivors": survivors.size(),
			"population": next.size(),
			"synthetic_contact": false,
			"selection_mode": String(c.selection_mode),
		}
		row.merge(_population_stats(scored), true)
		history.append(row)
		pop = next
	return {"ok": not pop.is_empty(), "population": pop, "history": history,
		"generations": c.generations, "loop": 2, "measured": true, "synthetic_contact": false}


static func run_measured_loop2_campaign(seed_root: PartGene, cfg: Config,
		tree: SceneTree, seeds: Array[int] = []) -> Dictionary:
	var base := cfg if cfg != null else Config.new()
	var seed_list := seeds if not seeds.is_empty() else [base.seed]
	var normal_runs: Array = []
	var control_runs: Array = []
	for seed_value in seed_list:
		var normal := _copy_config(base)
		normal.seed = int(seed_value)
		normal.selection_mode = &"fitness"
		normal_runs.append(await run_measured_loop2(seed_root, normal, tree))
		var control := _copy_config(base)
		control.seed = int(seed_value)
		control.selection_mode = &"random"
		control_runs.append(await run_measured_loop2(seed_root, control, tree))
	var normal_summary := _campaign_summary(normal_runs)
	var control_summary := _campaign_summary(control_runs)
	return {
		"ok": bool(normal_summary.get("ok", false)) and bool(control_summary.get("ok", false)),
		"normal": normal_summary,
		"control": control_summary,
		"normal_runs": normal_runs,
		"control_runs": control_runs,
		"control_arm": "random_selection",
		"selection_beats_control": float(normal_summary.get("median_energy_delta", 0.0)) \
				>= float(control_summary.get("median_energy_delta", 0.0)),
	}


# Analytic pre-screen -> physically measure finalists -> rank by measured energy.
# Returns [{root, food, energy, forward, credible}] sorted by energy desc.
static func measure_population(pop: Array[PartGene], cfg: Config, tree: SceneTree,
		gen := 0) -> Array[Dictionary]:
	var c := cfg if cfg != null else Config.new()
	var keep := c.prescreen_keep if c.prescreen_keep > 0 else maxi(1, pop.size() / 2)
	# Cheap analytic cull first.
	var pre := _score_population(pop, c.food_count)
	pre.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["energy"]) > float(b["energy"]))
	var finalists := pre.slice(0, mini(keep, pre.size()))
	var out: Array[Dictionary] = []
	for entry in finalists:
		var root: PartGene = entry["root"]
		var m: Dictionary = await SimRollout.run(root, c.horizon, c.seed + gen, tree)
		var fwd := float(m.get("forward", 0.0))
		var credible := bool(m.get("credible_walk", false))
		# Food gathered = ground covered foraging, but only if it really walked.
		var food := clampi(int(round(fwd)), 0, c.food_count) if credible else 0
		var debt := float(CharacteristicsEvaluator.evaluate(root)["debt"]["debt_total"])
		var energy := float(food) - debt * 2.0
		out.append({"root": root, "food": food, "energy": energy,
			"forward": fwd, "credible": credible})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["energy"]) > float(b["energy"]))
	return out


static func measure_population_loop2(pop: Array[PartGene], cfg: Config, tree: SceneTree,
		rng: RandomNumberGenerator, gen := 0) -> Array[Dictionary]:
	var c := cfg if cfg != null else Config.new()
	var measured := await measure_population(pop, c, tree, gen)
	var hazard := _hazard_spike()
	for row in measured:
		var root: PartGene = row["root"]
		var eval := CharacteristicsEvaluator.evaluate(root)
		var alive := bool(eval["debt"].get("alive", true))
		var durability: Dictionary = CombatResolverScript.durability(root)
		var contact_damage := 0.0
		var contact_events := 0
		var hazard_hits := 0
		var combat_events := 0
		for _h in c.hazard_count:
			var hit := await _measured_contact(hazard, root, tree, 2.5 + c.hazard_severity * 8.0)
			if bool(hit.get("ok", false)):
				hazard_hits += 1
				contact_events += int(hit.get("contact_count", 0))
				contact_damage += float(hit.get("damage", 0.0))
				alive = alive and bool(hit.get("defender_alive", true))
		for _a in c.agent_count:
			if pop.size() <= 1:
				break
			var opponent := pop[rng.randi_range(0, pop.size() - 1)]
			if opponent == root:
				continue
			var flee_margin := _analytic_speed(root) - _analytic_speed(opponent)
			if flee_margin > 0.15 and rng.randf() < 0.65:
				continue
			var hit := await _measured_contact(opponent, root, tree, 2.25 + absf(flee_margin) * 2.0)
			combat_events += 1
			if bool(hit.get("ok", false)):
				contact_events += int(hit.get("contact_count", 0))
				contact_damage += float(hit.get("damage", 0.0))
				alive = alive and bool(hit.get("defender_alive", true))
		var damage_penalty := contact_damage / maxf(float(durability.get("hp", 1.0)), 1.0)
		row["alive"] = alive
		row["hazard_hits"] = hazard_hits
		row["combat_events"] = combat_events
		row["contact_events"] = contact_events
		row["contact_damage"] = contact_damage
		row["damage_penalty"] = damage_penalty
		row["synthetic_contact"] = false
		row["energy"] = float(row.get("energy", 0.0)) - damage_penalty * 3.0 - (10.0 if not alive else 0.0)
	measured.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["energy"]) > float(b["energy"]))
	return measured


static func _select_survivors(scored: Array[Dictionary], cfg: Config,
		rng: RandomNumberGenerator, require_alive := false) -> Array[PartGene]:
	var survivors: Array[PartGene] = []
	var keep := maxi(1, cfg.population_size / 2)
	if scored.is_empty():
		return survivors
	if cfg.selection_mode == &"random":
		var pool: Array[Dictionary] = []
		for row in scored:
			if require_alive and not bool(row.get("alive", true)):
				continue
			pool.append(row)
		if pool.is_empty():
			pool = scored.duplicate()
		while survivors.size() < mini(keep, pool.size()):
			var idx := rng.randi_range(0, pool.size() - 1)
			survivors.append(pool[idx]["root"])
			pool.remove_at(idx)
		return survivors
	for i in mini(scored.size(), keep):
		if require_alive and not bool(scored[i].get("alive", false)):
			continue
		survivors.append(scored[i]["root"])
	if survivors.is_empty() and not scored.is_empty():
		survivors.append(scored[0]["root"])
	return survivors


static func _population_stats(scored: Array[Dictionary]) -> Dictionary:
	if scored.is_empty():
		return {
			"median_energy": 0.0, "median_forward": 0.0, "credible_rate": 0.0,
			"alive_rate": 0.0, "death_rate": 0.0,
		}
	var energies: Array[float] = []
	var forwards: Array[float] = []
	var credible := 0
	var alive := 0
	for row in scored:
		energies.append(float(row.get("energy", 0.0)))
		forwards.append(float(row.get("forward", 0.0)))
		if bool(row.get("credible", false)):
			credible += 1
		if bool(row.get("alive", true)):
			alive += 1
	return {
		"median_energy": _median(energies),
		"median_forward": _median(forwards),
		"credible_rate": float(credible) / float(scored.size()),
		"alive_rate": float(alive) / float(scored.size()),
		"death_rate": 1.0 - float(alive) / float(scored.size()),
	}


static func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	values.sort()
	var mid := int(values.size() / 2)
	if values.size() % 2 == 1:
		return values[mid]
	return 0.5 * (values[mid - 1] + values[mid])


static func _copy_config(src: Config) -> Config:
	var c := Config.new()
	c.seed = src.seed
	c.population_size = src.population_size
	c.food_count = src.food_count
	c.generations = src.generations
	c.mutation_cfg = src.mutation_cfg
	c.horizon = src.horizon
	c.prescreen_keep = src.prescreen_keep
	c.hazard_count = src.hazard_count
	c.agent_count = src.agent_count
	c.hazard_severity = src.hazard_severity
	c.selection_mode = src.selection_mode
	return c


static func _campaign_summary(runs: Array) -> Dictionary:
	var deltas: Array[float] = []
	var credible_deltas: Array[float] = []
	var ok := true
	for res in runs:
		var r: Dictionary = res
		ok = ok and bool(r.get("ok", false))
		var hist: Array = r.get("history", [])
		if hist.is_empty():
			deltas.append(0.0)
			credible_deltas.append(0.0)
			continue
		var first: Dictionary = hist[0]
		var last: Dictionary = hist[-1]
		deltas.append(float(last.get("median_energy", 0.0)) - float(first.get("median_energy", 0.0)))
		credible_deltas.append(float(last.get("credible_rate", 0.0)) - float(first.get("credible_rate", 0.0)))
	return {
		"ok": ok,
		"runs": runs.size(),
		"median_energy_delta": _median(deltas),
		"credible_rate_delta": _median(credible_deltas),
	}


static func _score_population(pop: Array[PartGene], food_count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for root in pop:
		var eval := CharacteristicsEvaluator.evaluate(root)
		var speed := float(eval["speed"]["value"])
		var debt := float(eval["debt"]["debt_total"])
		var stable := bool(eval["balance"]["stable"])
		var food := clampi(int(floor(speed * float(food_count) * (1.0 - minf(debt, 0.95)))), 0, food_count)
		var energy := float(food) - debt * 2.0 - (0.0 if stable else 1.0)
		out.append({"root": root, "food": food, "energy": energy})
	return out


static func _score_population_loop2(pop: Array[PartGene], cfg: Config,
		rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in pop.size():
		var root := pop[i]
		var eval := CharacteristicsEvaluator.evaluate(root)
		var debt := float(eval["debt"]["debt_total"])
		var speed := float(eval["speed"]["value"])
		var strength := float(eval["strength"]["value"])
		var alive := bool(eval["debt"].get("alive", true))
		var food := clampi(int(floor(speed * float(cfg.food_count) * (1.0 - minf(debt, 0.95)))),
				0, cfg.food_count)
		var hazard_hits := 0
		var combat_events := 0
		var contact_events := 0
		var contact_damage := 0.0
		var damage_penalty := 0.0
		for _h in cfg.hazard_count:
			if rng.randf() < clampf(0.65 - speed * 0.45, 0.05, 0.85):
				var hit := CombatResolverScript.hazard_contact(root, cfg.hazard_severity)
				hazard_hits += 1
				contact_events += 1
				contact_damage += float(hit["damage"])
				damage_penalty += float(hit["damage"]) / maxf(float(hit["defender_hp_before"]), 1.0)
				alive = alive and bool(hit["defender_alive"])
		for _a in cfg.agent_count:
			if pop.size() <= 1:
				break
			var opponent := pop[rng.randi_range(0, pop.size() - 1)]
			if opponent == root:
				continue
			var mine := CombatResolverScript.durability(root)
			var theirs := CombatResolverScript.durability(opponent)
			var flee_margin := speed - float(CharacteristicsEvaluator.evaluate(opponent)["speed"]["value"])
			if flee_margin > 0.15 and rng.randf() < 0.65:
				continue
			combat_events += 1
			contact_events += 1
			var result := CombatResolverScript.resolve_contact(opponent, root, {
				"relative_speed": maxf(absf(flee_margin), 0.05) + float(theirs["attack_power"]) / maxf(float(mine["hp"]), 1.0),
				"normal_impulse": maxf(float(theirs["attack_power"]) * 0.08, 0.01),
			})
			contact_damage += float(result["damage"])
			damage_penalty += float(result["damage"]) / maxf(float(mine["hp"]), 1.0)
			alive = alive and (bool(result["defender_alive"]) or strength > float(theirs["attack_power"]) / maxf(float(mine["hp"]), 1.0))
		var energy := float(food) + strength * 2.0 - debt * 2.0 - damage_penalty * 3.0
		if not alive:
			energy -= 10.0
		out.append({"root": root, "food": food, "energy": energy, "alive": alive,
			"hazard_hits": hazard_hits, "combat_events": combat_events,
			"contact_events": contact_events, "contact_damage": contact_damage,
			"damage_penalty": damage_penalty})
	return out


static func _count_dead(rows: Array[Dictionary]) -> int:
	var n := 0
	for row in rows:
		if not bool(row.get("alive", true)):
			n += 1
	return n


static func _sum_int(rows: Array[Dictionary], key: String) -> int:
	var n := 0
	for row in rows:
		n += int(row.get(key, 0))
	return n


static func _sum_float(rows: Array[Dictionary], key: String) -> float:
	var n := 0.0
	for row in rows:
		n += float(row.get(key, 0.0))
	return n


static func _measured_contact(attacker: PartGene, defender: PartGene, tree: SceneTree,
		strike_speed: float) -> Dictionary:
	var cp := SimRollout.CombatParams.new()
	cp.strike_speed = strike_speed
	cp.horizon_s = 0.7
	cp.impulse_threshold = 0.02
	return await SimRollout.run_combat_contact(attacker, defender, tree, cp)


static func _analytic_speed(root: PartGene) -> float:
	return float(CharacteristicsEvaluator.evaluate(root)["speed"]["value"])


static func _hazard_spike() -> PartGene:
	var d := PartDefinition.new()
	d.part_type = &"box"
	d.density = 4500.0
	d.extents = Vector3(0.16, 0.16, 0.42)
	var g := PartGene.new()
	g.definition = d
	g.tags = [&"spine", &"attack"]
	g.part_id = &"hazard_spike"
	return g
