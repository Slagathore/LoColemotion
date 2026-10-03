extends SceneTree


func _initialize() -> void:
	var cfg := CorpusBuilder.Config.new()
	cfg.seed = 100
	cfg.generated_count = 6
	cfg.mutation_count = 6
	var corpus := CorpusBuilder.build(cfg)
	print("corpus rows=%d categories=%s" % [corpus.size(), str(CorpusBuilder.category_counts(corpus))])
	quit(0)
