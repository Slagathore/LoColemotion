extends SceneTree

## Body+gait co-evolution for quad_v2 — the escalation past GaitOptimizer when the
## scalar gait space is tapped out (three searches converged ~2.2-2.3 m in a nose-down
## crouch; the strut knobs came back neutral, so the crouch is a geometry/controller
## attractor, not a tuning miss). GenomeMutator can move sockets (CoM shifts), resize
## parts, and re-angle joints — the levers a scalar search cannot reach. Elitism-gated,
## shaped rollout fitness (falls punished, sustained tail rewarded), honest via the
## root &"honest" tag. Validates the champion at the official 10 s bar, prints its
## stand-gate margins (the evolved BODY must still hold itself), and saves a card.
##
## Usage (headless):
##   godot --headless --path . --script res://scripts/sim/run_coevolve_quad_v2.gd
##   godot ... -- gens=8 pop=8 horizon=8.0 seed=1 card=res://data/creatures/tuned_quad_v2.tres

const CoevoScript := preload("res://scripts/sim/coevolution_engine.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

const DEFAULT_SEED_CARD := "res://data/creatures/tuned_quad_v2.tres"
const SAVE_PATH := "res://data/creatures/tuned_quad_v2_evo.tres"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var gens := int(args.get("gens", 8))
	var pop := int(args.get("pop", 8))
	var horizon := float(args.get("horizon", 8.0))
	var rng_seed := int(args.get("seed", 1))
	var card_path := String(args.get("card", DEFAULT_SEED_CARD))

	var root: PartGene = null
	var seed_card := CreatureIO.load(card_path)
	if seed_card != null and seed_card.root != null:
		root = seed_card.root
		print("seeding coevolution from %s" % card_path)
	if root == null:
		root = PartCatalog.make_quadruped_v2()
		print("seeding coevolution from the built-in quad_v2")

	_print_stand("seed", CE.evaluate(root))

	# A tuned rig wants parameter/gait drift, not part add/remove (topology changes
	# break the authored gait's socket references and rarely help a converged walker).
	var mut := GenomeMutator.Config.new()
	mut.topology_rate = 0.05
	mut.param_rate = 0.85
	mut.gait_rate = 0.35

	print("=== quad_v2 coevolution: gens=%d pop=%d horizon=%.1f seed=%d ===" % [
			gens, pop, horizon, rng_seed])
	var t0 := Time.get_ticks_msec()
	var result: Dictionary = await CoevoScript.evolve(root, self, gens, pop, horizon,
			rng_seed, mut)
	var champion: PartGene = result.get("champion", null)
	print("evolved: champion_fitness=%+.2f  (%.1f s elapsed)" % [
			float(result.get("champion_fitness", -INF)),
			(Time.get_ticks_msec() - t0) / 1000.0])
	for h in result.get("history", []):
		print("  gen %d: best=%+.2f mean=%+.2f" % [int(h["gen"]), float(h["best"]), float(h["mean"])])
	if champion == null:
		print("no champion returned")
		quit(1)
		return

	_print_stand("champion", CE.evaluate(champion))

	var rp := SimRolloutScript.Params.new()
	rp.sense_contacts = true
	var m: Dictionary = await SimRolloutScript.run(champion, 10.0, rng_seed, self, rp)
	print("=== 10 s validation (the official bar) ===")
	print("forward=%+.3f m  tail=%+.3f  up_min=%.2f  plants=%d  body_drag=%.2f" % [
			float(m["forward"]), float(m["forward_tail"]), float(m["root_up_min"]),
			int(m["foot_plants"]), float(m["body_drag_frac"])])
	print("credible_walk=%s  class=%s" % [str(m["credible_walk"]), String(m["locomotion_class"])])
	if not bool(m["credible_walk"]):
		print("reasons: %s" % str(m["locomotion_reasons"]))

	var card := CreatureCard.new()
	card.display_name = "Tuned Quad v2 (coevolved)"
	card.root = champion
	card.notes = "CoevolutionEngine champion (10 s validation fwd %+.2f m, credible=%s)." % [
			float(m["forward"]), str(m["credible_walk"])]
	var err := CreatureIO.save(card, SAVE_PATH)
	print("saved %s err=%s" % [SAVE_PATH, str(err)])
	quit(0)


func _print_stand(label: String, ev: Dictionary) -> void:
	var s: Dictionary = ev["stand"]
	print("%s stand gate: feasible=%s worst=%.3f @ %s | mid-step worst=%.3f @ %s | mass=%.1f kg" % [
			label, str(s["stand_feasible"]), float(s["worst_margin"]),
			String(s["worst_joint"]), float(s["gait_worst_margin"]),
			String(s["gait_worst_joint"]), float(ev["total_mass"])])


func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.contains("="):
			var kv := s.split("=", false, 2)
			if kv.size() == 2:
				out[kv[0]] = kv[1]
	return out
