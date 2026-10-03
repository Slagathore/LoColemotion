extends SceneTree

## Headless runner for the REV-floor correlation/calibration campaign.
##
## Optional environment overrides:
## - SPORE_SCIENCE_HORIZON=3.0
## - SPORE_SCIENCE_SEED=7100
## - SPORE_SCIENCE_GENERATED=40
## - SPORE_SCIENCE_MUTATIONS=12


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cfg := ScienceCampaign.Config.new()
	cfg.horizon_s = _env_float("SPORE_SCIENCE_HORIZON", cfg.horizon_s)
	cfg.seed = _env_int("SPORE_SCIENCE_SEED", cfg.seed)
	cfg.generated_count = _env_int("SPORE_SCIENCE_GENERATED", cfg.generated_count)
	cfg.mutation_count = _env_int("SPORE_SCIENCE_MUTATIONS", cfg.mutation_count)
	cfg.output_path = "user://science_correlation_rev.jsonl"
	cfg.report_path = "res://docs/CORRELATION_FINDING.md"
	var result: Dictionary = await ScienceCampaign.run(self, cfg)
	print(JSON.stringify({
		"ok": bool(result.get("ok", false)),
		"corpus_size": int(result.get("corpus_size", 0)),
		"floors": result.get("floors", {}),
		"spearman": float((result.get("correlation", {}) as Dictionary).get("spearman", 0.0)),
		"kendall": float((result.get("correlation", {}) as Dictionary).get("kendall", 0.0)),
		"report_path": String(result.get("report_path", "")),
	}))
	quit(0 if bool(result.get("ok", false)) else 1)


func _env_int(name: String, fallback: int) -> int:
	var v := OS.get_environment(name)
	return int(v) if v != "" else fallback


func _env_float(name: String, fallback: float) -> float:
	var v := OS.get_environment(name)
	return float(v) if v != "" else fallback
