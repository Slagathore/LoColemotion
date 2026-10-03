extends SceneTree
## Same uncaptured helper stderr as R10AC, with a source-only Git probe.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var output: Array = []
	var code := OS.execute("C:/Program Files/Python311/python.exe",
		PackedStringArray(["-B", ProjectSettings.globalize_path("res://tests/r10ad_startup_transport_probe.py")]), output, false, false)
	var result := {"exit_code": code, "helper_output": output, "world_build_count": 0, "solver_step_count": 0}
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(result) + "\n"); file.close()
	print("R10AD_STARTUP_TRANSPORT " + JSON.stringify(result))
	quit(0 if code == 0 else 1)
