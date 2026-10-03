extends SceneTree
const Frames := preload("res://sdk/adapters/godot/gdscript/r10af_contact_frame_capture_v1.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or FileAccess.file_exists(args[1]): quit(2); return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var rows: Array = [report.disturbance.baseline] + report.tail_rows
	var failures := []
	for row in rows:
		var replay := Frames.Native.validate_native_snapshot(Frames.unpack_native_v1(row.contacts), int(row.global_step))
		if replay.get("ok") != true: failures.append({"step": row.global_step, "failure": replay})
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": failures.is_empty(), "row_count": rows.size(), "failures": failures,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	file.close()
	quit(0 if failures.is_empty() else 1)
