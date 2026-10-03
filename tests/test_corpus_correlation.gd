extends SceneTree

const ScienceCampaignScript := preload("res://scripts/sim/science_campaign.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Corpus/Correlation tests ===")
	_test_corpus_categories()
	_test_body_plan_labels_and_floors()
	_test_trained_roots_join_corpus()
	_test_default_corpus_hits_rev_floors()
	_test_gait_scales_and_params_affect_cache_keys()
	await _test_streaming_and_cache()
	await _test_science_campaign_report()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_corpus_categories() -> void:
	print("- corpus spans source categories")
	var cfg := CorpusBuilder.Config.new()
	cfg.seed = 5
	cfg.generated_count = 2
	cfg.mutation_count = 2
	var corpus := CorpusBuilder.build(cfg)
	var counts := CorpusBuilder.category_counts(corpus)
	_check(int(counts.get(&"hand_authored", 0)) >= 2, "corpus includes hand-authored controls")
	_check(int(counts.get(&"generated", 0)) == 2, "corpus includes generated creatures")
	_check(int(counts.get(&"random_mutation", 0)) == 2, "corpus includes mutation weirdos")
	_check(int(counts.get(&"known_bad", 0)) == 2, "corpus includes capped known-bad controls")


func _test_body_plan_labels_and_floors() -> void:
	print("- corpus labels body plans and reports numeric floor blockers")
	var cfg := CorpusBuilder.Config.new()
	cfg.seed = 6
	cfg.generated_count = 1
	cfg.mutation_count = 1
	cfg.known_bad_count = 1
	var corpus := CorpusBuilder.build(cfg)
	var body_counts := CorpusBuilder.body_plan_counts(corpus)
	_check(not body_counts.is_empty(), "body-plan counts are populated")
	var floors: Dictionary = CorpusBuilder.floor_report(corpus, 60, 10, 8)
	_check(not bool(floors["ok"]) and (floors["blockers"] as Array).size() > 0,
			"small smoke corpus is honestly below REV floors")


func _test_trained_roots_join_corpus() -> void:
	print("- trained root snapshots can enter the measured corpus")
	TrainingLog.base_dir = "user://corpus_training_test"
	TrainingLog.reset()
	var root := PartCatalog.make_quadruped(false)
	var root_snapshot := GenomeSnapshot.to_dictionary(root)
	TrainingLog.record_run({
		"creature_id": "trained_quad",
		"credible_walk": true,
		"fell": false,
		"forward": 3.5,
		"fitness": 7.0,
		"settings": {"gain": 8.0},
		"baseline_root": root_snapshot,
		"candidate_root": root_snapshot,
	}, 1.0)
	var cfg := CorpusBuilder.Config.new()
	cfg.generated_count = 0
	cfg.mutation_count = 0
	cfg.known_bad_count = 0
	cfg.include_builtins = false
	cfg.include_trained = true
	var corpus := CorpusBuilder.build(cfg)
	_check(corpus.size() == 1 and String(corpus[0].get("source_category", "")) == "trained",
			"trained root is restored into corpus as its own category")
	_check(corpus[0].get("root", null) is PartGene,
			"trained corpus row contains a reconstructed PartGene")
	TrainingLog.reset()


func _test_default_corpus_hits_rev_floors() -> void:
	print("- default corpus hits REV category/body-plan floors")
	var corpus := CorpusBuilder.build()
	var floors: Dictionary = CorpusBuilder.floor_report(corpus, 60, 10, 8)
	var counts: Dictionary = floors["category_counts"]
	var body_counts: Dictionary = floors["body_plan_counts"]
	_check(bool(floors["ok"]), "default corpus meets REV floors")
	_check(int(counts.get(&"known_bad", 0)) < 10, "known-bad controls stay capped/exempt")
	_check(int(body_counts.get("8_feet", 0)) >= 8, "eight-foot body plan is represented")


func _test_gait_scales_and_params_affect_cache_keys() -> void:
	print("- gait scales and explicit rollout params affect cache keys")
	var a := PartCatalog.make_quadruped(false)
	var b := GenomeSnapshot.deep_copy(a)
	b.gait.traction_scale *= 1.25
	_check(EvolutionEngine.genome_signature(a) != EvolutionEngine.genome_signature(b),
			"genome signature includes gait scale changes")
	var p1 := SimRolloutScript.Params.new()
	p1.controller_params = CpgControllerScript.Params.new()
	p1.controller_params.traction_scale = 1.0
	var p2 := SimRolloutScript.Params.new()
	p2.controller_params = CpgControllerScript.Params.new()
	p2.controller_params.traction_scale = 2.0
	var k1 := CorrelationRunner.measured_cache_key(a, 0.25, 99,
			CorrelationRunner.rollout_params_signature(p1))
	var k2 := CorrelationRunner.measured_cache_key(a, 0.25, 99,
			CorrelationRunner.rollout_params_signature(p2))
	_check(k1 != k2, "measured cache key includes explicit controller params")


func _test_streaming_and_cache() -> void:
	print("- correlation streams JSONL and caches measured rollouts")
	var cfg := CorpusBuilder.Config.new()
	cfg.seed = 7
	cfg.generated_count = 1
	cfg.mutation_count = 0
	cfg.include_builtins = false
	var corpus := CorpusBuilder.build(cfg)
	var rcfg := CorrelationRunner.Config.new()
	rcfg.seed = 9
	rcfg.horizon_s = 0.15
	rcfg.output_path = "user://_test_correlation.jsonl"
	var runner := CorrelationRunner.new()
	var summary: Dictionary = await runner.run(corpus, self, rcfg)
	_check(bool(summary["ok"]) and int(summary["rows"]) == corpus.size(), "small correlation run completes")
	_check(summary.has("kendall") and summary.has("by_category") and summary.has("by_body_plan"),
			"summary includes Kendall and per-slice correlations")
	_check(summary.has("row_data") and (summary["row_data"] as Array).size() == corpus.size(),
			"summary preserves measured rows for train/holdout science")
	var path := ProjectSettings.globalize_path(rcfg.output_path)
	_check(FileAccess.file_exists(path), "JSONL output is written incrementally")
	var first := await runner.measured_rollout(corpus[0]["root"], rcfg.horizon_s, 99, self)
	var second := await runner.measured_rollout(corpus[0]["root"], rcfg.horizon_s, 99, self)
	_check(not bool(first.get("cached", true)) and bool(second.get("cached", false)), "second identical rollout hits cache")


func _test_science_campaign_report() -> void:
	print("- M11 science campaign writes an honest report and calibration assessment")
	var cfg := ScienceCampaignScript.Config.new()
	cfg.seed = 12
	cfg.generated_count = 1
	cfg.mutation_count = 0
	cfg.known_bad_count = 1
	cfg.horizon_s = 0.15
	cfg.output_path = "user://_test_science_correlation.jsonl"
	cfg.report_path = "user://_test_correlation_finding.md"
	cfg.min_total = 60
	cfg.min_category = 10
	cfg.min_body_plan = 8
	var result: Dictionary = await ScienceCampaignScript.run(self, cfg)
	_check(bool(result["ok"]), "science campaign completes")
	_check(not bool((result["floors"] as Dictionary)["ok"]), "campaign preserves floor honesty")
	_check((result["calibration"] as Dictionary).has("decision"),
			"campaign returns calibration decision")
	var splits: Dictionary = result["splits"]
	_check(int((splits["train"] as Dictionary)["n"]) > 0 and int((splits["holdout"] as Dictionary)["n"]) > 0,
			"campaign uses real train and holdout rows")
	_check(FileAccess.file_exists(ProjectSettings.globalize_path(cfg.report_path)),
			"campaign writes a correlation report")
