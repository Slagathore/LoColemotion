extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sweep := TuningHarness.Sweep.new()
	sweep.horizon_s = 0.5
	var rows := await TuningHarness.run_sweep(PartCatalog.make_quadruped(false), self, sweep)
	for row in rows:
		print(JSON.stringify(row))
	quit(0)
