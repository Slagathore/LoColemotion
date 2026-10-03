extends SceneTree

## Headless gait-optimization batch. Tunes each creature's gait for forward
## locomotion and prints the before/after. This is where the "1000 runs" lives:
## bump `iters` and the seed sweep for a deeper search; results can be saved by
## extending this to write GaitOptimizer.Result into the creature's GaitDef.

const GenScript := preload("res://scripts/sim/creature_generator.gd")
const OptScript := preload("res://scripts/sim/gait_optimizer.gd")

const ITERS := 30
const HORIZON := 2.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _tune("built-in quad", PartCatalog.make_quadruped(false))
	await _tune("biped", GenScript.make_biped(7))
	for s in [1, 42, 111]:
		var cfg := GenScript.Config.new()
		cfg.seed = s
		cfg.leg_segments = 2
		await _tune("gen seed %d" % s, GenScript.generate(cfg))
	quit(0)


func _tune(label: String, root_gene: PartGene) -> void:
	var r = await OptScript.optimize(root_gene, self, ITERS, HORIZON, 1)
	print("%-18s baseline forward=%+.3f  ->  tuned forward=%+.3f  (freq %.2f, gain %.2f)" % [
		label, r.baseline_forward, r.forward, r.frequency_scale, r.gain_scale])
