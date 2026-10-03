extends SceneTree

## Generates a creature, optimizes its gait for sustained forward walking, saves
## it as a committed creature, then replays it through the EDITOR sim path to
## confirm it keeps walking (sustained, with settle).

const GenScript := preload("res://scripts/sim/creature_generator.gd")
const OptScript := preload("res://scripts/sim/gait_optimizer.gd")

const SAVE_PATH := "res://data/creatures/tuned_walker.tres"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cfg := GenScript.Config.new()
	cfg.seed = 1
	cfg.leg_segments = 2
	cfg.spine_segments_min = 1
	cfg.spine_segments_max = 1
	var creature := GenScript.generate(cfg)
	var r = await OptScript.optimize(creature, self, 24, 5.0, 1, 4)
	OptScript.apply_to(creature, r)
	print("optimized: fwd=%+.2f tail=%+.2f amp=%.2f freq=%.2f gain=%.2f" % [
		r.forward, r.forward_tail, r.amplitude_scale, r.frequency_scale, r.gain_scale])

	var card := CreatureCard.new()
	card.display_name = "Tuned Walker"
	card.root = creature
	card.notes = "Gait-optimized quad that walks forward (fwd %.2f, sustained %.2f)." % [
		r.forward, r.forward_tail]
	var err := CreatureIO.save(card, SAVE_PATH)
	print("saved %s  err=%s" % [SAVE_PATH, err])

	# Editor-path replay with settle.
	var bench := EditorBench.new()
	get_root().add_child(bench)
	bench.load_card(card)
	bench.start_simulation()
	var b = bench.sim_viewer().body()
	var prev = b.call("measure")["cog"] as Vector3
	for sec in 8:
		for _i in 60:
			await physics_frame
		var cog = b.call("measure")["cog"] as Vector3
		print("  editor t=%ds  moved-this-sec=%.3f  cog=(%.2f,%.2f,%.2f)" % [
			sec + 1, Vector2(cog.x - prev.x, cog.z - prev.z).length(), cog.x, cog.y, cog.z])
		prev = cog
	quit(0)
