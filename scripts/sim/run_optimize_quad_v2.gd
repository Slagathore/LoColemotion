extends SceneTree

## Honest gait search for the flagship quad_v2 (the reference-tracked sagittal walker).
## Replaces hand-tuning: GaitOptimizer hill-climbs the FULL gait-shape space the leg
## tracker actually reads (phases, freq/gain/amplitude, step_len/step_h/duty, swing
## PD scales) with the assist forced OFF (max_assist=0), validates the winner at the
## official 10 s bar (CREDIBLE_FORWARD_M), and saves it as a CreatureCard.
##
## The stand-feasibility gate runs FIRST: no point searching a gait for a body whose
## leg muscles cannot hold it up mid-step (the 92 kg lesson, now a pre-flight check).
##
## Usage (headless):
##   godot --headless --path . --script res://scripts/sim/run_optimize_quad_v2.gd
##   godot --headless --path . --script res://scripts/sim/run_optimize_quad_v2.gd -- smoke
##   godot ... -- iters=40 restarts=4 horizon=8.0 seed=1
##   godot ... -- card=res://data/creatures/tuned_quad_v2.tres   (continue from a saved tune)

const OptScript := preload("res://scripts/sim/gait_optimizer.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

const SAVE_PATH := "res://data/creatures/tuned_quad_v2.tres"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var iters := int(args.get("iters", 40))
	var restarts := int(args.get("restarts", 4))
	var horizon := float(args.get("horizon", 8.0))
	var rng_seed := int(args.get("seed", 1))
	if bool(args.get("smoke", false)):
		iters = 6
		restarts = 1
		horizon = 2.0
	var root: PartGene = null
	var card_path := String(args.get("card", ""))
	if card_path != "":
		var seed_card := CreatureIO.load(card_path)
		if seed_card != null and seed_card.root != null:
			root = seed_card.root
			print("seeding search from %s" % card_path)
	if root == null:
		root = PartCatalog.make_quadruped_v2()

	var ev := CE.evaluate(root)
	var stand: Dictionary = ev["stand"]
	print("stand gate: feasible=%s worst=%.3f @ %s | mid-step worst=%.3f @ %s (lift %s)" % [
			str(stand["stand_feasible"]), float(stand["worst_margin"]),
			String(stand["worst_joint"]), float(stand["gait_worst_margin"]),
			String(stand["gait_worst_joint"]), String(stand["gait_worst_lifted"])])
	if not bool(stand["gait_feasible"]):
		print("REFUSING to tune: the mid-step torque gate fails — fix the body first")
		quit(1)
		return

	print("=== quad_v2 honest gait search: iters=%d restarts=%d horizon=%.1f seed=%d ===" % [
			iters, restarts, horizon, rng_seed])
	var t0 := Time.get_ticks_msec()
	var progress := func(done: int, total: int, best_fwd: float) -> void:
		if done % 10 == 0 or done == total:
			print("  [%3d/%3d] best_fwd=%+.2f m  (%.1f s elapsed)" % [
					done, total, best_fwd, (Time.get_ticks_msec() - t0) / 1000.0])
	var r = await OptScript.optimize(root, self, iters, horizon, rng_seed, restarts,
			progress, 0.0)                       # max_assist = 0.0 -> HONEST search
	OptScript.apply_to(root, r)
	print("tuned: fwd=%+.2f tail=%+.2f mode=%s | freq=%.2f gain=%.1f amp=%.2f" % [
			r.forward, r.forward_tail, String(r.mode),
			r.frequency_scale, r.gain_scale, r.amplitude_scale])
	print("shape: step_len=%.3f step_h=%.3f duty=%.2f swing_kq=%.2f swing_kd=%.2f ext=%.2f stance_kq=%.2f" % [
			r.step_len, r.step_h, r.duty, r.swing_kq_scale, r.swing_kd_scale,
			r.extensor_scale, r.stance_kq_scale])
	print("baseline was fwd=%+.2f (fitness %+.2f -> %+.2f)" % [
			r.baseline_forward, r.baseline_fitness, r.fitness])

	# Official 10 s validation, bench-equivalent: controller params come from the tuned
	# gait itself (null Params -> bind adopts the GaitDef), contacts sensed for the
	# honest motion-shape metrics.
	var rp := SimRolloutScript.Params.new()
	rp.sense_contacts = true
	var m: Dictionary = await SimRolloutScript.run(root, 10.0, rng_seed, self, rp)
	print("=== 10 s validation (the official bar) ===")
	print("forward=%+.3f m  tail=%+.3f  up_min=%.2f  plants=%d  body_drag=%.2f" % [
			float(m["forward"]), float(m["forward_tail"]), float(m["root_up_min"]),
			int(m["foot_plants"]), float(m["body_drag_frac"])])
	print("credible_walk=%s  class=%s" % [str(m["credible_walk"]), String(m["locomotion_class"])])
	if not bool(m["credible_walk"]):
		print("reasons: %s" % str(m["locomotion_reasons"]))

	var card := CreatureCard.new()
	card.display_name = "Tuned Quad v2 (honest)"
	card.root = root
	card.notes = "GaitOptimizer honest search (tuned fwd %+.2f m/%.1f s; 10 s validation fwd %+.2f m, credible=%s)." % [
			r.forward, horizon, float(m["forward"]), str(m["credible_walk"])]
	var err := CreatureIO.save(card, SAVE_PATH)
	print("saved %s err=%s" % [SAVE_PATH, str(err)])
	quit(0)


func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s == "smoke":
			out["smoke"] = true
		elif s.contains("="):
			var kv := s.split("=", false, 2)
			if kv.size() == 2:
				out[kv[0]] = kv[1]
	return out
