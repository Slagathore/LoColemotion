extends SceneTree

## Headless training batch — the "background runs" entry point. Trains a set of
## creatures; each session warm-starts from the cross-creature library, logs
## every run to user://training/runs.jsonl, and updates the counters. Bump ROUNDS
## (or wrap the body in a `while true`) for indefinite training.
##
## Defaults to the evidence-chosen LLM director (LlmDirector.DEFAULT_MODEL =
## qwen3-coder-next:cloud, see docs/MODEL_BAKEOFF.md). If Ollama is unreachable
## the trainer degrades to hill-climb per round, so this is safe with no server.
##   godot --headless --path . --script res://scripts/sim/run_train.gd
## Override the director (or force plain hill-climb) via env var:
##   SPORE_LLM_MODEL=glm-5.2:cloud godot --headless --path . --script res://scripts/sim/run_train.gd
##   SPORE_LLM_MODEL=none ...   # any unreachable name -> pure hill-climb fallback
##   (optional SPORE_LLM_HOST=http://host:11434)

const GenScript := preload("res://scripts/sim/creature_generator.gd")

const ROUNDS := 12
const HORIZON := 4.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var llm_model := OS.get_environment("SPORE_LLM_MODEL")
	if llm_model == "":
		llm_model = LlmDirector.DEFAULT_MODEL   # evidence-chosen default director
	var llm_host := OS.get_environment("SPORE_LLM_HOST")
	print("LLM director: model=%s host=%s (falls back to hill-climb if unreachable)" % [
		llm_model, llm_host if llm_host != "" else "default"])

	var roster := [
		["builtin_quad", PartCatalog.make_quadruped(false)],
		["gen_quad_knees", _gen(1, 2)],          # similar to the quad -> should warm-start from it
		["biped", GenScript.make_biped(7)],
		["hexapod", GenScript.make_hexapod(11)],
	]
	for entry in roster:
		var name: String = entry[0]
		var root: PartGene = entry[1]
		var cfg := Trainer.Config.new()
		cfg.rounds = ROUNDS
		cfg.horizon = HORIZON
		cfg.seed = 2025
		cfg.creature_name = name
		if llm_model != "":
			cfg.proposer = &"llm"
			cfg.model = llm_model
			if llm_host != "":
				cfg.host = llm_host
		var now := Time.get_unix_time_from_system()
		var best := await Trainer.train(root, self, cfg, now)
		var m: Dictionary = best.get("metrics", {})
		print("%-16s best fitness=%+.2f  forward=%+.2f  credible=%s  pattern=%s" % [
			name, float(best.get("fitness", 0.0)), float(m.get("forward", 0.0)),
			str(m.get("credible_walk", false)),
			String((best.get("candidate", {}) as Dictionary).get("pattern", "?"))])

	var agg := TrainingLog.aggregate()
	print("--- aggregate: runs=%d credible=%d falls=%d creatures=%d ---" % [
		int(agg["total_runs"]), int(agg["total_credible"]), int(agg["total_falls"]),
		int(agg["creatures_trained"])])
	quit(0)


func _gen(seed_value: int, leg_segments: int) -> PartGene:
	var cfg := GenScript.Config.new()
	cfg.seed = seed_value
	cfg.leg_segments = leg_segments
	cfg.spine_segments_min = 1
	cfg.spine_segments_max = 1
	return GenScript.generate(cfg)
