extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ccfg := CorpusBuilder.Config.new()
	ccfg.seed = 100
	ccfg.generated_count = 4
	ccfg.mutation_count = 4
	var corpus := CorpusBuilder.build(ccfg)
	var rcfg := CorrelationRunner.Config.new()
	rcfg.seed = 1000
	rcfg.horizon_s = 1.0
	rcfg.output_path = "user://correlation_run.jsonl"
	var runner := CorrelationRunner.new()
	var summary: Dictionary = await runner.run(corpus, self, rcfg)
	print(JSON.stringify(summary))
	quit(0 if bool(summary.get("ok", false)) else 1)
