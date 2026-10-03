class_name ModeTournament
extends RefCounted

## M42 — multi-mode search. For a body, derive plausible modes (affordances), run one rollout
## per mode with mode-appropriate controller params, score each under the M38 mode classifier,
## and pick the best mode that clears the universal floor (else the furthest-travelling). No
## hand-labeling: a hopper selects hop, a radial urchin selects pogo, from behaviour alone.
##
## Also hosts the assist-annealing curriculum: across generations, ramp traction/posture toward
## a floor (ratchet — only decreases), so a creature must learn to stand on its own legs.

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const CreatureAffordancesScript := preload("res://scripts/sim/creature_affordances.gd")


# Assist scale for a given generation: base at gen 0, linearly down to `floor` at the last gen.
# Monotonically NON-INCREASING by construction (the ratchet — assist only ever tightens).
static func anneal_assist(base_scale: float, generation: int, generations: int,
		floor_scale := 0.0) -> float:
	if generations <= 1:
		return base_scale
	var frac := clampf(float(generation) / float(generations - 1), 0.0, 1.0)
	return maxf(floor_scale, base_scale * (1.0 - frac))


# assist_scale reduces the locomotion assist so a body competes on its OWN actuation, not on the
# heading-aligned traction shove (which would let every body "win" walk by being dragged forward).
# Low assist is the honest judge of which mode a morphology actually affords (the curriculum's end).
static func run(root_gene: PartGene, tree: SceneTree, horizon := 2.5, seed := 7,
		assist_scale := 0.25) -> Dictionary:
	var modes := CreatureAffordancesScript.plausible_modes(root_gene)
	var results: Array[Dictionary] = []
	for mode in modes:
		var rp := SimRolloutScript.Params.new()
		rp.controller_params = _params_for_mode(root_gene, mode, assist_scale)
		var m: Dictionary = await SimRolloutScript.run(root_gene, horizon, seed, tree, rp)
		var verdict := SimRolloutScript.classify_mode(mode, m,
				float(m.get("assist_ratio_ceiling", SimRolloutScript.MAX_ASSIST_RATIO)),
				float(m.get("slip_ratio_ceiling", SimRolloutScript.MAX_SLIP_RATIO)))
		results.append({
			"mode": mode,
			"credible": bool(verdict["credible"]),
			"class": verdict["class"],
			"score": _mode_score(mode, m),
			"displacement": absf(float(m.get("distance_abs", 0.0))),
		})
	results.sort_custom(_better)
	var best: Dictionary = results[0] if not results.is_empty() else {"mode": &"walk"}
	return {
		"best_mode": best.get("mode", &"walk"),
		"best_credible": bool(best.get("credible", false)),
		"results": results,
	}


# A mode is judged in its OWN terms: walk/lateral by horizontal travel; hop/pogo also reward the
# vertical excursion (bounce) that distinguishes a real hop/pogo from being dragged along the floor.
static func _mode_score(mode: StringName, m: Dictionary) -> float:
	var disp := absf(float(m.get("distance_abs", 0.0)))
	match mode:
		&"hop", &"pogo", &"radial":
			return disp + 4.0 * float(m.get("bounce", 0.0))
		&"lateral":
			return absf(float(m.get("lateral", 0.0)))
		_:
			return disp


# Rank: a mode that clears the universal floor beats one that doesn't; then by mode-own score.
static func _better(a: Dictionary, b: Dictionary) -> bool:
	if bool(a["credible"]) != bool(b["credible"]):
		return bool(a["credible"])
	return float(a["score"]) > float(b["score"])


static func _params_for_mode(root_gene: PartGene, mode: StringName,
		assist_scale := 1.0) -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	var g: GaitDef = root_gene.gait
	if g != null:
		p.amplitude_scale = g.amplitude_scale
		p.frequency_scale = g.frequency_scale
		p.gain_scale = g.gain_scale
		p.traction_scale = g.traction_scale * assist_scale
		p.posture_scale = g.posture_scale * assist_scale
	match mode:
		&"hop", &"pogo", &"radial":
			p.locomotion_mode = &"hop"      # contact-subset/spring tags do the firing
		&"lateral":
			p.locomotion_mode = &"lateral"
		_:
			p.locomotion_mode = &"walk"     # walk / undulation / roll drive forward via legs/tags
	return p
