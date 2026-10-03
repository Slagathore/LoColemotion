extends SceneTree

## M60 — undulation phase coherence. SimRollout now measures a real per-segment phase-coherence
## (variance of consecutive segment phase offsets) instead of the old theta_span-only proxy. A
## regular traveling body wave reads as coherent (~1.0); scrambling the segment phases drops it.

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _run() -> void:
	print("=== M60 undulation phase-coherence tests ===")
	var coherent = await SimRollout.run(PartCatalog.make_serpent_v2(), 2.0, 5, self)
	var scrambled = await SimRollout.run(_scramble(PartCatalog.make_serpent_v2()), 2.0, 5, self)
	var c_coh := float(coherent.get("phase_coherence", -1.0))
	var s_coh := float(scrambled.get("phase_coherence", -1.0))
	print("  coherent=%.3f scrambled=%.3f" % [c_coh, s_coh])
	_check(bool(coherent.get("ok", false)), "coherent serpent rollout is finite")
	_check(c_coh > 0.5, "a regular traveling wave reads as phase-coherent (>0.5)")
	_check(c_coh > s_coh + 0.05, "scrambling the segment phases measurably lowers coherence")
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _scramble(root_gene: PartGene) -> PartGene:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	if root_gene.gait != null:
		for k in root_gene.gait.assignments.keys():
			root_gene.gait.assignments[k] = rng.randf()
	return root_gene
