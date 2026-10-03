extends SceneTree

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const ReconcileScript := preload("res://scripts/sim/reconcile.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Reconcile tests ===")
	await _test_channel_separation()
	await _test_correlation_diagnostic()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_channel_separation() -> void:
	print("- reconciliation keeps analytic and measured separate")
	var root_gene := PartCatalog.make_quadruped(false)
	var analytic := CE.evaluate(root_gene)
	var measured: Dictionary = await SimRolloutScript.run(root_gene, 0.25, 9, self)
	var rec := ReconcileScript.compare(analytic, measured)
	_check(rec.has("analytic") and rec.has("measured") and rec.has("deltas"), "top-level channels exist")
	_check((rec["analytic"] as Dictionary).has("speed"), "analytic channel keeps evaluator speed")
	_check((rec["measured"] as Dictionary).has("forward"), "measured channel keeps signed forward distance")
	_check(not (rec["measured"] as Dictionary).has("speed"), "measured channel does not overwrite analytic speed")
	_check((rec["fidelity"] as Dictionary).has("straightness"), "reconcile reports straightness fidelity")
	_check((rec["fidelity"] as Dictionary).has("credible_walk"), "reconcile reports strict credible-walk gate")


func _test_correlation_diagnostic() -> void:
	print("- small-corpus correlation is diagnostic, not a gate")
	var corpus: Array[PartGene] = [
		PartCatalog.make_quadruped(false),
		PartCatalog.make_quadruped(true),
	]
	var mut_rng := RandomNumberGenerator.new()
	mut_rng.seed = 8181
	corpus.append(GenomeMutator.mutate(PartCatalog.make_quadruped(false), GenomeMutator.Config.new(), mut_rng))
	var analytic_scores := PackedFloat32Array()
	var measured_scores := PackedFloat32Array()
	for i in corpus.size():
		var analytic := CE.evaluate(corpus[i])
		var measured: Dictionary = await SimRolloutScript.run(corpus[i], 0.20, 100 + i, self)
		analytic_scores.append(float(analytic["speed"]["value"]))
		measured_scores.append(float(measured["forward"]))
	var rho := ReconcileScript.spearman(analytic_scores, measured_scores)
	print("  diagnostic Spearman analytic-vs-measured: %.4f" % rho)
	_check(is_finite(rho), "correlation diagnostic is finite")
	_check(rho >= -1.0 and rho <= 1.0, "correlation diagnostic lies in [-1, 1]")
