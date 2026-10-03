class_name Trainer
extends RefCounted

## Headless closed-loop gait trainer. For one creature it:
##   1. extracts a body feature vector and warm-starts from the nearest known body,
##   2. seeds candidates from the gait template library (trot/pace/bound/gallop/...),
##   3. evaluates each on a track (SimRollout), credibility-gated like the optimizer,
##   4. LOGS EVERY RUN (all settings + all metrics) and updates counters,
##   5. hill-climbs around the best, and remembers the winner in the warm-start library.
##
## Headless by design: rollouts run as fast as the CPU allows here (the editor's
## live sim is real-time-paced and is only for WATCHING the winner).

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

# The "known walking recipe" (from the hand-tuned built-in quad) — a sane default
# when the warm-start library is empty.
const DEFAULT_SCALES := {
	"amplitude": 2.2, "frequency": 0.7, "gain": 8.0, "traction": 1.4, "posture": 2.2, "turn": 0.0,
}


class Config:
	extends Resource
	var horizon := 5.0
	var seed := 1
	var rounds := 24            # total runs to log this session
	var track = null            # optional Track (Track.straight/obstacle/target/curved); null = straight
	var creature_name := "creature"
	var proposer := &"hill_climb"   # hill_climb | llm
	var model := ""                 # ollama model name, when proposer == llm
	var host := "http://localhost:11434"
	var goal := "maximize credible forward walking distance"


static func train(root_gene: PartGene, tree: SceneTree, cfg: Config = null,
		now_unix := 0.0, on_round := Callable(), propose_override := Callable()) -> Dictionary:
	var c := cfg if cfg != null else Config.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = c.seed
	var working := GenomeSnapshot.deep_copy(root_gene)
	if working.gait == null:
		working.gait = GaitDef.new()

	var features := CreatureFeatures.extract(working)
	var cid := EvolutionEngine.genome_signature(working)
	var baseline_root_snapshot := GenomeSnapshot.to_dictionary(working)
	var warm := WarmStartLibrary.best_seed_for(features)

	var base_scales := DEFAULT_SCALES.duplicate()
	var seed_patterns := GaitLibrary.PATTERNS.duplicate()
	if not warm.is_empty():
		base_scales = (warm.get("scales", DEFAULT_SCALES) as Dictionary).duplicate()
		seed_patterns.push_front(StringName(warm.get("pattern", "trot")))   # try the proven one first

	var best := {}
	var history: Array = []
	var round_idx := 0
	var llm := (c.proposer == &"llm" and c.model != "") or propose_override.is_valid()
	var baseline_cand := _candidate_from_gait(working)
	var baseline := await _run_and_log(working, baseline_cand, c, cid, features, now_unix,
			{}, -1, on_round, tree, history, baseline_root_snapshot)
	best = baseline

	# Phase 1: seed a few gait templates so the loop (and the LLM) starts with data.
	# With an LLM director we seed only a couple so it gets to drive most of the run.
	var seed_count := (2 if llm else c.rounds)
	for pattern in seed_patterns:
		if round_idx >= c.rounds or round_idx >= seed_count:
			break
		var cand := {
			"phases": GaitLibrary.phases_for(working, pattern),
			"scales": base_scales.duplicate(),
			"pattern": pattern,
		}
		best = await _run_and_log(working, cand, c, cid, features, now_unix, best,
				round_idx, on_round, tree, history, baseline_root_snapshot)
		round_idx += 1

	# Phase 2: each round, the PROPOSER picks the next candidate.
	#   propose_override (tests) > LLM director (Ollama) > hill-climb perturbation.
	var step := 0.3
	while round_idx < c.rounds and not best.is_empty():
		var cand := {}
		if propose_override.is_valid():
			cand = await _as_dict(propose_override.call(working, _llm_context(c, features, history, best)))
		elif c.proposer == &"llm" and c.model != "":
			cand = await LlmDirector.propose(tree, c.model, working,
					_llm_context(c, features, history, best), c.host)
		if cand.is_empty():
			cand = _perturb(best["candidate"], rng, step)   # fallback (also pure hill-climb mode)
			step = maxf(step * 0.94, 0.05)
		best = await _run_and_log(working, cand, c, cid, features, now_unix, best,
				round_idx, on_round, tree, history, baseline_root_snapshot)
		round_idx += 1

	# Do-no-harm: only replace the starting gait when fitness improves AND we don't
	# trade a credible walk for a non-credible one. (Fitness shaping already makes
	# this hold via the penalty gap; the conjunct makes it explicit + robust to retuning.)
	var best_credible := not best.is_empty() and bool((best["metrics"] as Dictionary).get("credible_walk", false))
	var base_credible := not baseline.is_empty() and bool((baseline["metrics"] as Dictionary).get("credible_walk", false))
	var improved: bool = not best.is_empty() and not baseline.is_empty() \
			and best.get("candidate", {}) != baseline.get("candidate", {}) \
			and float(best["fitness"]) > float(baseline["fitness"]) + 0.0001 \
			and (best_credible or not base_credible)
	if improved:
		WarmStartLibrary.remember(cid, features, best["candidate"]["scales"],
				best["candidate"]["pattern"], float(best["fitness"]),
				best.get("root_snapshot", {}))
		_apply(root_gene, best["candidate"])
	else:
		best = baseline
		best["no_improvement"] = true
	return best


# Compact per-run summary fed back to the LLM director as history.
static func _llm_context(cfg: Config, features: Dictionary, history: Array, best: Dictionary) -> Dictionary:
	var best_compact := {}
	if not best.is_empty():
		var m: Dictionary = best["metrics"]
		best_compact = {
			"pattern": String(best["candidate"]["pattern"]),
			"scales": best["candidate"]["scales"],
			"forward": float(m["forward"]),
			"credible_walk": bool(m["credible_walk"]),
		}
	return {
		"creature_name": cfg.creature_name,
		"features": features,
		"history": history,
		"best": best_compact,
		"goal": cfg.goal,
	}


static func _as_dict(v) -> Dictionary:
	return v if v is Dictionary else {}


static func _run_and_log(working: PartGene, cand: Dictionary, cfg: Config, cid: String,
		features: Dictionary, now_unix: float, best: Dictionary, round_idx: int,
		on_round: Callable, tree: SceneTree, history: Array,
		baseline_root_snapshot: Dictionary) -> Dictionary:
	var m := await _evaluate(working, cand, cfg, tree)
	var fitness := float(m["fitness"])
	var candidate_root_snapshot := GenomeSnapshot.to_dictionary(working)
	var record := {
		"creature_id": cid,
		"creature_name": cfg.creature_name,
		"round": round_idx,
		"track": String(cfg.track.kind) if cfg.track != null else "straight",
		"features": features,
		"baseline_root": baseline_root_snapshot,
		"candidate_root": candidate_root_snapshot,
		"settings": {
			"pattern": String(cand["pattern"]),
			"phases": cand["phases"],
			"scales": cand["scales"],
		},
		"forward": m["forward"],
		"forward_tail": m["forward_tail"],
		"heading": [m["heading"].x, m["heading"].z],
		"yaw_delta": m["yaw_delta"],
		"straightness": m["straightness"],
		"distance_abs": m["distance_abs"],
		"fell": m["fell"],
		"credible_walk": m["credible_walk"],
		"locomotion_class": m["locomotion_class"],
		"energy": m["energy"],
		"cost_of_transport": m["cost_of_transport"],
		"traction_impulse": m.get("traction_impulse", 0.0),
		"posture_impulse": m.get("posture_impulse", 0.0),
		"assist_work": m.get("assist_work", 0.0),
		"assist_per_meter": m.get("assist_per_meter", 0.0),
		"assist_ratio": m.get("assist_ratio", 0.0),
		"ticks": m["ticks"],
		"sim_seconds": float(m["ticks"]) / SimRolloutScript.TICK_RATE,
		"fitness": fitness,
	}
	TrainingLog.record_run(record, now_unix)
	var s: Dictionary = cand["scales"]
	history.append({
		"round": round_idx, "pattern": String(cand["pattern"]),
		"amplitude": float(s.get("amplitude", 0.0)), "frequency": float(s.get("frequency", 0.0)),
		"gain": float(s.get("gain", 0.0)), "traction": float(s.get("traction", 0.0)),
		"posture": float(s.get("posture", 0.0)),
		"forward": float(m["forward"]), "credible_walk": bool(m["credible_walk"]),
		"locomotion_class": String(m["locomotion_class"]), "rationale": cand.get("rationale", ""),
		"assist_ratio": float(m.get("assist_ratio", 0.0)),
	})
	var new_best := best
	if best.is_empty() or fitness > float(best["fitness"]):
		new_best = {"fitness": fitness, "candidate": cand, "metrics": m,
			"root_snapshot": candidate_root_snapshot}
	# Report the BEST-so-far forward distance (meters) + whether it's a credible
	# walk — not this round's raw fitness, which reads like a huge distance.
	if on_round.is_valid():
		var bm: Dictionary = new_best["metrics"]
		on_round.call(round_idx, cfg.rounds, float(bm["forward"]), bool(bm["credible_walk"]))
	return new_best


static func _candidate_from_gait(root_gene: PartGene) -> Dictionary:
	var gait: GaitDef = root_gene.gait
	var phases := {}
	var pattern := &"trot"
	if gait != null:
		pattern = gait.pattern if gait.pattern != &"" else &"trot"
		for sid in gait.assignments:
			phases[sid] = float(gait.assignments[sid])
	if phases.is_empty():
		phases = GaitLibrary.phases_for(root_gene, pattern)
	var scales := DEFAULT_SCALES.duplicate()
	if gait != null:
		scales = {
			"amplitude": gait.amplitude_scale,
			"frequency": gait.frequency_scale,
			"gain": gait.gain_scale,
			"traction": gait.traction_scale,
			"posture": gait.posture_scale,
			"turn": gait.turn_rate,
		}
	return {"phases": phases, "scales": scales, "pattern": pattern, "baseline": true}


static func _evaluate(working: PartGene, cand: Dictionary, cfg: Config, tree: SceneTree) -> Dictionary:
	for sid in cand["phases"]:
		working.gait.assignments[sid] = cand["phases"][sid]
	var s: Dictionary = cand["scales"]
	var params := CpgControllerScript.Params.new()
	params.amplitude_scale = float(s.get("amplitude", 1.0))
	params.frequency_scale = float(s.get("frequency", 1.0))
	params.gain_scale = float(s.get("gain", 8.0))
	params.traction_scale = float(s.get("traction", 1.4))
	params.posture_scale = float(s.get("posture", 2.2))
	params.turn_rate = float(s.get("turn", 0.0))
	var track = cfg.track if cfg.track != null else Track.straight()
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = params
	rp.track = track
	var m: Dictionary = await SimRolloutScript.run(working, cfg.horizon, cfg.seed, tree, rp)
	# The TRACK decides fitness + what "success" means for this objective.
	var sc: Dictionary = track.score(m)
	m["fitness"] = float(sc["fitness"])
	m["credible_walk"] = bool(sc["credible"])      # task success (reached target / followed curve / walked)
	m["locomotion_class"] = String(sc["class"])
	m["locomotion_reasons"] = sc["reasons"]
	m["track_progress"] = float(sc["progress"])
	return m


static func _perturb(cand: Dictionary, rng: RandomNumberGenerator, step: float) -> Dictionary:
	var phases := {}
	for sid in cand["phases"]:
		phases[sid] = wrapf(float(cand["phases"][sid]) + rng.randf_range(-step, step), 0.0, 1.0)
	var s: Dictionary = cand["scales"]
	var scales := {
		"amplitude": clampf(float(s.get("amplitude", 2.2)) + rng.randf_range(-0.3, 0.3), 0.8, 2.6),
		"frequency": clampf(float(s.get("frequency", 0.7)) + rng.randf_range(-0.2, 0.2), 0.4, 2.5),
		"gain": clampf(float(s.get("gain", 8.0)) + rng.randf_range(-3.0, 3.0), 0.5, 60.0),
		"traction": clampf(float(s.get("traction", 1.4)) + rng.randf_range(-0.25, 0.25), 0.0, 2.0),
		"posture": clampf(float(s.get("posture", 2.2)) + rng.randf_range(-0.35, 0.35), 0.0, 3.0),
		"turn": clampf(float(s.get("turn", 0.0)) + rng.randf_range(-0.3, 0.3), -1.5, 1.5),
	}
	return {"phases": phases, "scales": scales, "pattern": cand["pattern"]}


static func _apply(root_gene: PartGene, cand: Dictionary) -> void:
	if root_gene.gait == null:
		root_gene.gait = GaitDef.new()
	for sid in cand["phases"]:
		root_gene.gait.assignments[sid] = cand["phases"][sid]
	var s: Dictionary = cand["scales"]
	root_gene.gait.amplitude_scale = float(s.get("amplitude", 1.0))
	root_gene.gait.frequency_scale = float(s.get("frequency", 1.0))
	root_gene.gait.gain_scale = float(s.get("gain", 8.0))
	root_gene.gait.traction_scale = float(s.get("traction", 1.4))
	root_gene.gait.posture_scale = float(s.get("posture", 2.2))
	root_gene.gait.turn_rate = float(s.get("turn", 0.0))
