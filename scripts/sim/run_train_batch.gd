extends SceneTree

## Batch LLM-assisted training across varied builds AND cloud models (a model
## bake-off). model = models[i % M]; build = builds[(i / M) % B], so consecutive
## trainings pit every model against the SAME build for a fair head-to-head.
## LLM failures degrade gracefully to hill-climb, so the batch never stalls.
##
##   SPORE_LLM_MODELS=glm-5.2:cloud,deepseek-v4-pro:cloud godot --headless --path . \
##       --script res://scripts/sim/run_train_batch.gd
##   (optional) SPORE_TRAIN_COUNT=100  SPORE_TRAIN_ROUNDS=6  SPORE_LLM_HOST=...

const Gen := preload("res://scripts/sim/creature_generator.gd")

# Default director is the bake-off winner (see docs/MODEL_BAKEOFF.md). Override with
# SPORE_LLM_MODELS=a:cloud,b:cloud to run another head-to-head bake-off.
const DEFAULT_MODELS := "qwen3-coder-next:cloud"
const DEFAULT_COUNT := 100
const DEFAULT_ROUNDS := 6
const HORIZON := 4.0
const BUILD_COUNT := 18


func _initialize() -> void:
	call_deferred("_run")


func _build(idx: int, seed_value: int) -> Array:
	match idx % BUILD_COUNT:
		0: return ["quad", PartCatalog.make_quadruped(false)]
		1: return ["front_quad", PartCatalog.make_quadruped(true)]
		2: return ["biped", Gen.make_biped(seed_value)]
		3: return ["hexapod", Gen.make_hexapod(seed_value)]
		4: return ["segmented_quad", Gen.make_segmented_quadruped(seed_value)]
		5: return ["spider", Gen.make_spider(seed_value)]
		6: return ["frog", PartCatalog.make_frog()]
		7: return ["crab", PartCatalog.make_crab()]
		8: return ["gen_octopod", Gen.generate(_cfg(seed_value, 4, 1, 2, false))]
		9: return ["gen_decapod", Gen.generate(_cfg(seed_value, 5, 3, 1, false))]
		10: return ["gen_longspine_quad", Gen.generate(_cfg(seed_value, 2, 3, 2, false))]
		11: return ["gen_knee_biped", Gen.generate(_cfg(seed_value, 2, 1, 3, true))]
		12: return ["sea_urchin", PartCatalog.make_sea_urchin()]
		13: return ["starfish", PartCatalog.make_starfish()]
		14: return ["serpent", PartCatalog.make_serpent()]
		15: return ["tripod", PartCatalog.make_tripod()]
		16: return ["hopper", PartCatalog.make_hopper()]
		17: return ["stilt_walker", PartCatalog.make_stilt_walker()]
	return ["quad", PartCatalog.make_quadruped(false)]


func _cfg(seed_value: int, pairs: int, spine: int, leg_segs: int, biped: bool) -> Gen.Config:
	var c := Gen.Config.new()
	c.seed = seed_value
	c.limb_pairs_min = pairs
	c.limb_pairs_max = pairs
	c.spine_segments_min = spine
	c.spine_segments_max = spine
	c.leg_segments = leg_segs
	c.want_head = false
	c.want_organs = true
	c.max_parts = 80
	c.biped = biped
	if biped:
		c.arm_pairs = 1
		c.arm_segments = 2
	return c


func _run() -> void:
	var models_env := OS.get_environment("SPORE_LLM_MODELS")
	if models_env == "":
		models_env = OS.get_environment("SPORE_LLM_MODEL")   # single-model fallback
	if models_env == "":
		models_env = DEFAULT_MODELS
	var models := models_env.split(",", false)
	var host := OS.get_environment("SPORE_LLM_HOST")
	var count := int(OS.get_environment("SPORE_TRAIN_COUNT")) if OS.get_environment("SPORE_TRAIN_COUNT") != "" else DEFAULT_COUNT
	var rounds := int(OS.get_environment("SPORE_TRAIN_ROUNDS")) if OS.get_environment("SPORE_TRAIN_ROUNDS") != "" else DEFAULT_ROUNDS
	print("=== Batch model bake-off: models=%s count=%d rounds=%d ===" % [str(models), count, rounds])

	var per_model := {}
	for mdl in models:
		per_model[mdl] = {"n": 0, "credible": 0, "fwd_sum": 0.0, "impr": 0, "base_fwd": 0.0}
	var t_start := Time.get_unix_time_from_system()
	for i in count:
		var model: String = models[i % models.size()]
		@warning_ignore("integer_division")
		var build_idx := (i / models.size())
		var seed_value := 1000 + i * 7
		var entry := _build(build_idx, seed_value)
		var name: String = "%s_%03d" % [String(entry[0]), i]
		var root: PartGene = entry[1]
		var cfg := Trainer.Config.new()
		cfg.rounds = rounds
		cfg.horizon = HORIZON
		cfg.seed = seed_value
		cfg.creature_name = name
		cfg.proposer = &"llm"
		cfg.model = model
		if host != "":
			cfg.host = host
		var now := Time.get_unix_time_from_system()
		var best: Dictionary = await Trainer.train(root, self, cfg, now)
		var m: Dictionary = best.get("metrics", {})
		var ok := bool(m.get("credible_walk", false))
		var fwd := float(m.get("forward", 0.0))
		var stat: Dictionary = per_model[model]
		stat["n"] += 1
		stat["credible"] += (1 if ok else 0)
		stat["fwd_sum"] += fwd
		print("[%3d/%3d] %-14s %-22s fitness=%+7.2f forward=%+6.2f credible=%s class=%s" % [
			i + 1, count, model.replace(":cloud", ""), name,
			float(best.get("fitness", 0.0)), fwd, str(ok), String(m.get("locomotion_class", "?"))])

	var elapsed := Time.get_unix_time_from_system() - t_start
	print("\n=== MODEL BAKE-OFF RESULTS (%ds) ===" % int(elapsed))
	for mdl in models:
		var s: Dictionary = per_model[mdl]
		var n: int = s["n"]
		if n == 0:
			continue
		print("  %-26s n=%2d  credible=%2d/%2d (%2.0f%%)  mean_forward=%5.2f" % [
			mdl, n, s["credible"], n, 100.0 * float(s["credible"]) / float(n),
			float(s["fwd_sum"]) / float(n)])
	var agg := TrainingLog.aggregate()
	print("--- training log aggregate: %s ---" % str(agg))
	quit(0)
