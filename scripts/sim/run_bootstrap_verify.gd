extends SceneTree

## Fast M7 trust-gate verifier.
##
## Run:
##   godot --headless --path . --script res://scripts/sim/run_bootstrap_verify.gd
##
## This is not a replacement for the full test suite. It is the cheap proof row
## for the bootstrap: credibility rejects assist-carried motion, rollouts expose
## assist debt, fixed-seed physics stays deterministic within tolerance, and the
## trainer logs a baseline row before it can mutate a gait.

const SimRolloutScript := preload("res://scripts/sim/sim_rollout.gd")

var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Bootstrap M7 verifier ===")
	_check_assist_gauntlet()
	_check_failure_stream()
	await _check_determinism()
	await _check_trainer_baseline()
	if _failed == 0:
		print("BOOTSTRAP VERIFY PASS")
	else:
		printerr("BOOTSTRAP VERIFY FAIL: %d checks failed" % _failed)
	quit(0 if _failed == 0 else 1)


func _ok(label: String, cond: bool, details := "") -> void:
	if cond:
		print("  PASS  %s%s" % [label, "  " + details if details != "" else ""])
	else:
		_failed += 1
		printerr("  FAIL  %s%s" % [label, "  " + details if details != "" else ""])


func _check_assist_gauntlet() -> void:
	var assisted := SimRolloutScript.classify_locomotion(3.6, 1.7, 0.8, 0.0, 0.9, 0.1,
			true, SimRolloutScript.MAX_ASSIST_PER_METER * 2.0, 1.0)
	_ok("assist-carried walk rejected", not bool(assisted["credible_walk"])
			and assisted["class"] == &"assist_carried", str(assisted["reasons"]))


func _check_failure_stream() -> void:
	TrainingLog.base_dir = "user://bootstrap_verify"
	TrainingLog.reset()
	TrainingLog.record_run({"creature_id": "verify", "creature_name": "verify", "round": 0,
			"track": "straight", "credible_walk": false, "fell": true, "forward": 1.0,
			"forward_tail": 0.0, "locomotion_class": "fall_or_tip",
			"locomotion_reasons": ["root tipped over"], "settings": {}}, 1.0)
	_ok("failure stream records non-credible rows", TrainingLog.load_failures().size() == 1)


func _check_determinism() -> void:
	var root := PartCatalog.clone_template(&"primitive_box")
	var a: Dictionary = await SimRolloutScript.run(root, 0.35, 42, self)
	var b: Dictionary = await SimRolloutScript.run(root, 0.35, 42, self)
	_ok("fixed-seed rollout deterministic",
			absf(float(a["forward"]) - float(b["forward"])) < 0.00001
			and absf(float(a["energy"]) - float(b["energy"])) < 0.00001)
	_ok("rollout exposes assist fields",
			a.has("traction_impulse") and a.has("posture_impulse") and a.has("assist_ratio"))


func _check_trainer_baseline() -> void:
	TrainingLog.base_dir = "user://bootstrap_verify"
	TrainingLog.reset()
	WarmStartLibrary.reset()
	var quad := PartCatalog.make_quadruped(false)
	var cfg := Trainer.Config.new()
	cfg.rounds = 0
	cfg.horizon = 0.6
	cfg.seed = 7
	cfg.creature_name = "baseline_verify"
	var best := await Trainer.train(quad, self, cfg, 1.0)
	var runs := TrainingLog.load_runs()
	_ok("trainer logs baseline before proposals", runs.size() == 1 and int(runs[0]["round"]) == -1)
	_ok("trainer reports no-improvement when only baseline ran", bool(best.get("no_improvement", false)))
