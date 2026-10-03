extends SceneTree

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Tuning/Calibration tests ===")
	await _test_tuning_sweep_small()
	_test_viewer_forward_arrow()
	_test_calibration_ceiling_branch()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_tuning_sweep_small() -> void:
	print("- tuning harness sweeps body/controller params")
	var sweep := TuningHarness.Sweep.new()
	sweep.foot_frictions = [0.9]
	sweep.gain_scales = [1.0, 1.1]
	sweep.horizon_s = 0.12
	var rows := await TuningHarness.run_sweep(PartCatalog.make_quadruped(false), self, sweep)
	_check(rows.size() == 2, "sweep returns one row per parameter combination")
	_check(rows[0].has("forward") and rows[0].has("straightness"), "sweep rows include movement diagnostics")


func _test_viewer_forward_arrow() -> void:
	print("- locomotion viewer exposes canonical forward arrow")
	var viewer := LocomotionViewer.new()
	root.add_child(viewer)
	viewer.load_creature(PartCatalog.make_quadruped(false))
	_check(viewer.forward_arrow() != null, "viewer creates forward arrow")
	_check(viewer.forward_arrow().name == "CanonicalForwardArrow", "forward arrow is named for debug lookup")
	viewer.queue_free()


func _test_calibration_ceiling_branch() -> void:
	print("- calibration names structural ceiling below target")
	var history: Array[Dictionary] = [
		{"spearman": 0.20},
		{"spearman": 0.24},
		{"spearman": 0.23},
	]
	var cfg := CalibrationRunner.Config.new()
	cfg.target_spearman = 0.5
	var result := CalibrationRunner.assess(history, cfg)
	_check(result["decision"] == &"structural_ceiling", "plateau below target returns structural ceiling decision")
	_check(String(result["reason"]).contains("contact/thrust"), "ceiling reason points at probe structure")
