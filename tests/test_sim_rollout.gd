extends SceneTree

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== SimRollout tests ===")
	await _test_rollout_reproducible()
	await _test_rollout_channels_are_measured()
	await _test_builtin_quadruped_clears_credible_walk_gate()
	_test_forward_metric_sign_fixture()
	_test_credible_walk_classifier()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _approx(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _test_rollout_reproducible() -> void:
	print("- rollout is reproducible for fixed seed")
	var root_gene := PartCatalog.clone_template(&"primitive_box")
	var a: Dictionary = await SimRolloutScript.run(root_gene, 0.45, 123, self)
	var b: Dictionary = await SimRolloutScript.run(root_gene, 0.45, 123, self)
	_check(bool(a["ok"]) and bool(b["ok"]), "rollouts complete")
	_check(_approx(float(a["forward"]), float(b["forward"]), 0.00001),
			"forward distance repeats within tolerance")
	_check(_approx(float(a["energy"]), float(b["energy"]), 0.00001),
			"energy repeats within tolerance")


func _test_rollout_channels_are_measured() -> void:
	print("- rollout returns measured-only keys")
	var r: Dictionary = await SimRolloutScript.run(PartCatalog.clone_template(&"primitive_box"), 0.25, 456, self)
	_check(r.has("forward") and r.has("distance_abs") and r.has("energy") and r.has("fell"), "measured rollout keys exist")
	_check(r.has("path_len") and r.has("straightness") and r.has("yaw_delta"), "diagnostic movement bundle exists")
	_check(r.has("credible_walk") and r.has("locomotion_class") and r.has("root_up_min"), "strict locomotion classification exists")
	_check(r.has("traction_impulse") and r.has("posture_impulse") and r.has("assist_work")
			and r.has("assist_per_meter") and r.has("assist_ratio"),
			"assist debt fields are reported on every rollout")
	_check(not r.has("speed") and not r.has("balance"), "analytic evaluator keys are not blended into rollout")


func _test_builtin_quadruped_clears_credible_walk_gate() -> void:
	print("- built-in quadruped actually walks past the strict 3m gate")
	var root_gene := PartCatalog.make_quadruped(false)
	var rp := SimRolloutScript.Params.new()
	rp.controller_params = _params_from_gait(root_gene.gait)
	var r: Dictionary = await SimRolloutScript.run(root_gene, 5.0, 123, self, rp)
	print("  measured walk: credible=%s forward=%.3f tail=%.3f up=%.3f drop=%.3f class=%s reasons=%s" % [
		str(r["credible_walk"]), float(r["forward"]), float(r["forward_tail"]),
		float(r["root_up_min"]), float(r["root_height_drop"]),
		String(r["locomotion_class"]), str(r["locomotion_reasons"])])
	_check(bool(r["credible_walk"]), "built-in quadruped is a credible walk, not a fall/lurch")
	_check(float(r["forward"]) >= SimRolloutScript.CREDIBLE_FORWARD_M,
			"credible walk covers at least 3m forward")
	_check(float(r["forward_tail"]) >= SimRolloutScript.CREDIBLE_TAIL_M,
			"credible walk has sustained back-half progress")
	_check(float(r["root_up_min"]) >= SimRolloutScript.MIN_ROOT_UP_DOT,
			"credible walk keeps the root upright")


func _test_forward_metric_sign_fixture() -> void:
	print("- canonical forward metric signs displacement")
	var heading := SimRolloutScript._horizontal_axis(Basis.IDENTITY, Vector3.FORWARD)
	var forward_delta := Vector3.FORWARD * 2.0
	var backward_delta := Vector3.BACK * 2.0
	_check(forward_delta.dot(heading) > 0.0, "canonical local forward displacement is positive")
	_check(backward_delta.dot(heading) < 0.0, "canonical local backward displacement is negative")


func _test_credible_walk_classifier() -> void:
	print("- credible walk rejects short, falling, and lurch-only movement")
	var short := SimRolloutScript.classify_locomotion(2.99, 1.5, 0.8, 0.0, 0.9, 0.1, true)
	_check(not bool(short["credible_walk"]) and short["class"] == &"too_short", "sub-3m forward is suspicious")
	var fall := SimRolloutScript.classify_locomotion(3.5, 1.6, 0.8, 0.0, 0.2, 0.1, true)
	_check(not bool(fall["credible_walk"]) and fall["class"] == &"fall_or_tip", "falling-forward displacement is rejected")
	var jam := SimRolloutScript.classify_locomotion(3.5, 0.05, 0.8, 0.0, 0.9, 0.1, true)
	_check(not bool(jam["credible_walk"]) and jam["class"] == &"lurch_or_jam", "lurch then jam is rejected")
	var walk := SimRolloutScript.classify_locomotion(3.5, 1.5, 0.8, 0.2, 0.9, 0.1, true)
	_check(bool(walk["credible_walk"]), "3m sustained upright progress can be credible")
	var assisted := SimRolloutScript.classify_locomotion(3.5, 1.5, 0.8, 0.2, 0.9, 0.1, true,
			SimRolloutScript.MAX_ASSIST_PER_METER * 2.0, 1.0)
	_check(not bool(assisted["credible_walk"]) and assisted["class"] == &"assist_carried",
			"assist-carried displacement is not a credible walk")


func _params_from_gait(gait: GaitDef) -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	if gait != null:
		p.amplitude_scale = gait.amplitude_scale
		p.frequency_scale = gait.frequency_scale
		p.gain_scale = gait.gain_scale
		p.traction_scale = gait.traction_scale
		p.posture_scale = gait.posture_scale
	return p
