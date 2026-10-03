class_name GaitOptimizer
extends RefCounted

## Per-creature gait tuner. Hill-climbs the per-limb phases and global CPG
## frequency/gain to maximize SIGNED forward distance (so "head-first" falls out
## of the fitness, not a hand-tuned constant). Runs headless rollouts, so it is a
## script/tool concern, never part of the commit-gated fast suite.

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const ModeTournamentScript := preload("res://scripts/sim/mode_tournament.gd")


class Result:
	extends Resource
	var phases := {}              # socket_id (StringName) -> phase 0..1
	var frequency_scale := 1.0
	var gain_scale := 1.0
	var amplitude_scale := 1.0
	var traction_scale := 0.0
	var posture_scale := 0.0
	# Reference-tracking gait shape (2026-07-03). These are what a leg-tracked walker
	# (quad_v2) ACTUALLY reads — the scales above barely touch it (gain_scale reaches only
	# the stance task-PD; the derived stride is overridden by authored step_len). 0 on the
	# timing trio = GaitDef's "derived default" sentinel, preserved until a perturb adopts
	# a real value; the swing scales default 1.0 = engine constants unchanged.
	var step_len := 0.0
	var step_h := 0.0
	var duty := 0.0
	var swing_kq_scale := 1.0
	var swing_kd_scale := 1.0
	var extensor_scale := 1.0
	var stance_kq_scale := 1.0
	var forward := 0.0
	var forward_tail := 0.0
	var fitness := -INF
	var baseline_forward := 0.0
	var baseline_fitness := -INF
	var mode: StringName = &"walk"        # M47/E2: tournament-selected achieved mode
	var assist_ceiling := 2.0             # M47/E2: per-generation assist-anneal ceiling (ratchets down)
	var tournament: Array = []            # M47/E2: per-mode tournament candidates (provenance)


# Socket ids of the joints the controller actually drives (locomotor + real hinge).
static func driven_sockets(root_gene: PartGene) -> Array[StringName]:
	var out: Array[StringName] = []
	var fold := CE.fold_graph(root_gene, Transform3D.IDENTITY)
	for p in fold["parts"]:
		if p.tags.has(&"locomotor") and p.socket != null and p.hinge_axis.length() > CE.EPS:
			out.append(p.socket.id)
	return out


static func optimize(root_gene: PartGene, tree: SceneTree, iterations := 40,
		horizon := 5.0, seed := 1, restarts := 3, on_progress := Callable(),
		max_assist := 2.0) -> Result:
	# max_assist caps the central-force assist (traction/posture) the search may use. 2.0 = legacy
	# (assisted). 0.0 = HONEST: the assist is forced off, so the optimizer can only win by real
	# foot-ground locomotion (the body must stand + push off on its own).
	# A long horizon is deliberate: a gait that jams after 2s scores far worse over
	# 5s than one that keeps walking, so the search rewards SUSTAINED locomotion.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var working := GenomeSnapshot.deep_copy(root_gene)
	if working.gait == null:
		working.gait = GaitDef.new()
	var sockets := driven_sockets(working)

	# M47/E2: pick the achieved MODE from a multi-mode tournament FIRST, then tune within it. The
	# tournament also tells us this body's affordances; we tune the mode it actually affords instead
	# of forcing walk on a hopper/urchin/serpent.
	var tourney: Dictionary = await ModeTournamentScript.run(working, tree, minf(horizon, 2.5), seed)
	var sel_mode: StringName = tourney.get("best_mode", &"walk")

	# Baseline (the creature's current/golden gait) anchors "did we improve?".
	var seed_phases := {}
	for i in sockets.size():
		seed_phases[sockets[i]] = float(working.gait.assignments.get(sockets[i],
				fmod(i * 0.61803, 1.0)))
	var baseline := Result.new()
	baseline.phases = seed_phases.duplicate()
	baseline.amplitude_scale = working.gait.amplitude_scale
	baseline.frequency_scale = working.gait.frequency_scale
	baseline.gain_scale = working.gait.gain_scale
	baseline.step_len = working.gait.step_len
	baseline.step_h = working.gait.step_h
	baseline.duty = working.gait.duty
	baseline.swing_kq_scale = working.gait.swing_kq_scale
	baseline.swing_kd_scale = working.gait.swing_kd_scale
	baseline.extensor_scale = working.gait.extensor_scale
	baseline.stance_kq_scale = working.gait.stance_kq_scale
	# In honest mode (max_assist<=0) the baseline is judged WITHOUT its assist too, else the assisted
	# baseline always beats every honest candidate and the search just returns the cheat.
	var assist_cap := maxf(max_assist, 0.0)
	baseline.traction_scale = minf(working.gait.traction_scale, assist_cap)
	baseline.posture_scale = minf(working.gait.posture_scale, assist_cap)
	baseline.assist_ceiling = assist_cap
	baseline.mode = sel_mode
	baseline.tournament = tourney.get("results", [])
	baseline.fitness = await _evaluate(working, baseline, tree, horizon, seed)

	var best := baseline
	var counter := [0]
	var gens := maxi(restarts, 1)
	var total := gens * iterations
	for restart in gens:
		# M47/E2 assist-anneal curriculum: each restart is a generation; the assist ceiling
		# ratchets DOWN, so later generations must stand on their own legs (not the traction shove).
		var ceil := 0.0 if max_assist <= 0.0 else ModeTournamentScript.anneal_assist(max_assist, restart, gens, 0.3)
		var start := Result.new()
		start.mode = sel_mode
		start.assist_ceiling = ceil
		if restart == 0:
			start.phases = seed_phases.duplicate()
			start.amplitude_scale = baseline.amplitude_scale
			start.frequency_scale = baseline.frequency_scale
			start.gain_scale = baseline.gain_scale
			start.step_len = baseline.step_len
			start.step_h = baseline.step_h
			start.duty = baseline.duty
			start.swing_kq_scale = baseline.swing_kq_scale
			start.swing_kd_scale = baseline.swing_kd_scale
			start.extensor_scale = baseline.extensor_scale
			start.stance_kq_scale = baseline.stance_kq_scale
			start.traction_scale = minf(baseline.traction_scale, ceil)
			start.posture_scale = minf(baseline.posture_scale, ceil)
		else:
			for sid in sockets:
				start.phases[sid] = rng.randf()         # fresh random gait
			start.frequency_scale = rng.randf_range(0.6, 1.8)
			start.gain_scale = rng.randf_range(1.0, 35.0)
			start.amplitude_scale = rng.randf_range(1.0, 2.4)
			start.step_len = rng.randf_range(0.06, 0.32)
			start.step_h = rng.randf_range(0.03, 0.12)
			start.duty = rng.randf_range(0.55, 0.85)
			start.swing_kq_scale = rng.randf_range(0.6, 2.0)
			start.swing_kd_scale = rng.randf_range(0.6, 2.0)
			start.extensor_scale = rng.randf_range(0.7, 1.8)
			start.stance_kq_scale = rng.randf_range(0.7, 1.8)
			start.traction_scale = rng.randf_range(0.0, ceil)
			start.posture_scale = rng.randf_range(0.0, ceil)
		start.fitness = await _evaluate(working, start, tree, horizon, seed)
		var local := await _hill_climb(working, start, rng, iterations, horizon, seed, tree,
				counter, total, best.forward, on_progress)
		if local.fitness > best.fitness:
			best = local

	best.baseline_forward = baseline.forward
	best.baseline_fitness = baseline.fitness
	best.mode = sel_mode
	best.tournament = tourney.get("results", [])
	return best


static func _hill_climb(working: PartGene, start: Result,
		rng: RandomNumberGenerator, iterations: int, horizon: float, seed: int,
		tree: SceneTree, counter: Array, total: int, prior_best_fwd: float,
		on_progress: Callable) -> Result:
	var best := start
	var scale := 0.35
	for _it in iterations:
		var cand := _perturb(best, rng, scale)
		var fit := await _evaluate(working, cand, tree, horizon, seed)
		if fit > best.fitness:
			cand.fitness = fit
			best = cand
		scale = maxf(scale * 0.96, 0.05)
		counter[0] = int(counter[0]) + 1
		if on_progress.is_valid():
			on_progress.call(int(counter[0]), total, maxf(best.forward, prior_best_fwd))
	return best


# Copies a tuned Result's phases into a genome's GaitDef (mutates in place).
static func apply_to(root_gene: PartGene, result: Result) -> void:
	if root_gene == null or result == null:
		return
	if root_gene.gait == null:
		root_gene.gait = GaitDef.new()
	for sid in result.phases:
		root_gene.gait.assignments[sid] = result.phases[sid]
	root_gene.gait.amplitude_scale = result.amplitude_scale
	root_gene.gait.frequency_scale = result.frequency_scale
	root_gene.gait.gain_scale = result.gain_scale
	# Gait-shape fields: 0 on the timing trio = "derived default" sentinel, never
	# written over an authored value with a sentinel.
	if result.step_len > 0.0:
		root_gene.gait.step_len = result.step_len
	if result.step_h > 0.0:
		root_gene.gait.step_h = result.step_h
	if result.duty > 0.0:
		root_gene.gait.duty = result.duty
	root_gene.gait.swing_kq_scale = result.swing_kq_scale
	root_gene.gait.swing_kd_scale = result.swing_kd_scale
	root_gene.gait.extensor_scale = result.extensor_scale
	root_gene.gait.stance_kq_scale = result.stance_kq_scale
	root_gene.gait.traction_scale = result.traction_scale
	root_gene.gait.posture_scale = result.posture_scale
	root_gene.gait.locomotion_mode = result.mode    # M47/E2: persist the tournament-selected mode


static func _evaluate(working: PartGene, cand: Result, tree: SceneTree,
		horizon: float, seed: int) -> float:
	for sid in cand.phases:
		working.gait.assignments[sid] = cand.phases[sid]
	# Gait-shape fields live on the GaitDef (the leg tracker reads them at bind, not from
	# Params). 0 = sentinel: leave the gait's value alone so derived defaults survive.
	if cand.step_len > 0.0:
		working.gait.step_len = cand.step_len
	if cand.step_h > 0.0:
		working.gait.step_h = cand.step_h
	if cand.duty > 0.0:
		working.gait.duty = cand.duty
	working.gait.swing_kq_scale = cand.swing_kq_scale
	working.gait.swing_kd_scale = cand.swing_kd_scale
	working.gait.extensor_scale = cand.extensor_scale
	working.gait.stance_kq_scale = cand.stance_kq_scale
	var params := CpgControllerScript.Params.new()
	params.frequency_scale = cand.frequency_scale
	params.gain_scale = cand.gain_scale
	params.amplitude_scale = cand.amplitude_scale
	params.traction_scale = cand.traction_scale
	params.posture_scale = cand.posture_scale
	# Honest search must stay honest for creatures without the &"honest" root tag too.
	params.honest = cand.assist_ceiling <= 0.0
	params.locomotion_mode = cand.mode        # M47/E2: tune within the tournament-selected mode
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = params
	var m: Dictionary = await SimRolloutScript.run(working, horizon, seed, tree, rp)
	cand.forward = float(m.get("forward", 0.0))
	cand.forward_tail = float(m.get("forward_tail", 0.0))
	var lateral := absf(float(m.get("lateral", 0.0)))
	var fell := bool(m.get("fell", false))
	var credible := bool(m.get("credible_walk", false))
	# Raw forward is a diagnostic, not proof. Anything below the credible-walk
	# gate is suspicious by design: a fall, lurch, slide, or jam must not win the
	# optimizer just because the root translated.
	if not credible:
		return -10.0 + minf(cand.forward, SimRolloutScript.CREDIBLE_FORWARD_M) \
				+ 0.25 * cand.forward_tail - 0.3 * lateral - (5.0 if fell else 0.0)
	return cand.forward + 3.0 * cand.forward_tail - 0.3 * lateral


static func _perturb(base: Result, rng: RandomNumberGenerator, scale: float) -> Result:
	var r := Result.new()
	r.mode = base.mode                          # M47/E2: stay in the selected mode
	r.assist_ceiling = base.assist_ceiling
	for sid in base.phases:
		r.phases[sid] = wrapf(float(base.phases[sid]) + rng.randf_range(-scale, scale), 0.0, 1.0)
	r.frequency_scale = clampf(base.frequency_scale + rng.randf_range(-0.2, 0.2), 0.4, 2.5)
	r.gain_scale = clampf(base.gain_scale + rng.randf_range(-4.0, 4.0), 0.5, 60.0)
	r.amplitude_scale = clampf(base.amplitude_scale + rng.randf_range(-0.3, 0.3), 0.8, 2.6)
	# Gait-shape fields. A 0 base (the "derived default" sentinel) adopts a fresh uniform
	# value instead of perturbing from 0 — an additive step from 0 would clamp to the range
	# minimum and lock the search into a degenerate stride.
	r.step_len = (rng.randf_range(0.06, 0.32) if base.step_len <= 0.0
			else clampf(base.step_len + rng.randf_range(-0.04, 0.04), 0.05, 0.35))
	r.step_h = (rng.randf_range(0.03, 0.12) if base.step_h <= 0.0
			else clampf(base.step_h + rng.randf_range(-0.02, 0.02), 0.02, 0.15))
	r.duty = (rng.randf_range(0.55, 0.85) if base.duty <= 0.0
			else clampf(base.duty + rng.randf_range(-0.06, 0.06), 0.5, 0.9))
	r.swing_kq_scale = clampf(base.swing_kq_scale + rng.randf_range(-0.25, 0.25), 0.4, 2.5)
	r.swing_kd_scale = clampf(base.swing_kd_scale + rng.randf_range(-0.25, 0.25), 0.4, 2.5)
	# Stance strut: the knee's tau_ext is cap-clamped anyway, so past ~2x the tone
	# saturates — keep the range tight and let the damping ratio ride along.
	r.extensor_scale = clampf(base.extensor_scale + rng.randf_range(-0.2, 0.2), 0.5, 2.0)
	r.stance_kq_scale = clampf(base.stance_kq_scale + rng.randf_range(-0.2, 0.2), 0.5, 2.0)
	# assist stays under the generation's annealed ceiling (the ratchet)
	r.traction_scale = clampf(base.traction_scale + rng.randf_range(-0.25, 0.25), 0.0, base.assist_ceiling)
	r.posture_scale = clampf(base.posture_scale + rng.randf_range(-0.35, 0.35), 0.0, base.assist_ceiling)
	return r
