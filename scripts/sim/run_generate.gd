extends SceneTree

const CreatureGeneratorScript := preload("res://scripts/sim/creature_generator.gd")


func _initialize() -> void:
	var cfg := CreatureGeneratorScript.Config.new()
	cfg.seed = 42
	var count := 8
	for i in count:
		cfg.seed = 42 + i
		var root := CreatureGeneratorScript.generate(cfg)
		var eval := CharacteristicsEvaluator.evaluate(root)
		print("%02d parts=%d limbs=%d speed=%.3f probe=%s" % [
			i,
			CharacteristicsEvaluator.fold_graph(root, Transform3D.IDENTITY)["parts"].size(),
			CreatureGeneratorScript.limb_count(root),
			float(eval["speed"]["value"]),
			str(eval["probe"]["verdict"]),
		])
	quit(0)
