extends SceneTree

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Rollout isolation tests ===")
	await _test_same_body_seed_independent_of_process_position()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_same_body_seed_independent_of_process_position() -> void:
	print("- same body/seed is stable after unrelated rollout churn")
	var quad := PartCatalog.make_quadruped(false)
	var first := await _run_quad(quad)
	for i in 5:
		await SimRolloutScript.run(PartCatalog.clone_template(&"primitive_box"), 0.45, 100 + i, self)
	for i in 3:
		await _run_quad(PartCatalog.make_quadruped(false), 200 + i)
	var after := await _run_quad(quad)
	var diff := absf(float(first["forward"]) - float(after["forward"]))
	print("  first=%.3f after_churn=%.3f diff=%.5f" % [
		float(first["forward"]), float(after["forward"]), diff])
	_check(bool(first["credible_walk"]) and bool(after["credible_walk"]),
			"quad remains credible before and after rollout churn")
	_check(diff <= 0.05, "forward distance is independent of rollout position")
	_check(get_root().get_child_count() == 0, "rollout host is freed from the scene tree")


func _run_quad(root_gene: PartGene, seed := 123) -> Dictionary:
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = _params_from_gait(root_gene.gait)
	return await SimRolloutScript.run(root_gene, 5.0, seed, self, rp)


func _params_from_gait(gait: GaitDef) -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	if gait != null:
		p.amplitude_scale = gait.amplitude_scale
		p.frequency_scale = gait.frequency_scale
		p.gain_scale = gait.gain_scale
		p.traction_scale = gait.traction_scale
		p.posture_scale = gait.posture_scale
	return p
