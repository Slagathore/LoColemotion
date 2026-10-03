extends SceneTree
## No recovery worker or world guard is loaded. Exercise only helper transport.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var rows: Array = []
	for capture_stderr in [false, true]:
		var output: Array = []
		var code := OS.execute("C:/Program Files/Python311/python.exe",
			PackedStringArray(["-B", ProjectSettings.globalize_path("res://tests/r10ad_helper_stdio.py")]),
			output, capture_stderr, false)
		rows.append({"capture_stderr": capture_stderr, "exit_code": code, "output": output})
	var result := {"diagnosis_only": true, "modes": rows, "world_build_count": 0, "solver_step_count": 0}
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(result) + "\n"); file.close()
	print("R10AD_HELPER_STDIO " + JSON.stringify(result))
	quit(0)
