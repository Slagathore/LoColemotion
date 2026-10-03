extends SceneTree

const FinalizerScript := preload(
	"res://scripts/lab/lab_run_finalizer.gd")
const LauncherScript := preload(
	"res://scripts/lab/lab_process_launcher.gd")
const RunIndexScript := preload("res://scripts/lab/run_index.gd")
const TraceStoreScript := preload("res://scripts/lab/trace_store.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab nonzero-child partial preservation ===")
	var root := ProjectSettings.globalize_path(
		"res://.tmp/lab_nonzero_child_%d_%d" % [
			OS.get_process_id(),
			Time.get_ticks_usec(),
		]).replace("\\", "/")
	var reservation := RunIndexScript.reserve_partial(
		root, "nonzero_child", OS.get_process_id())
	_check(reservation["ok"], "parent reserves a candidate path")
	if not reservation["ok"]:
		_finish()
		return
	var plan_path := String(reservation["partial_path"]).path_join(
		"launch_plan.json")
	var engine_arguments := [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--log-file",
		String(reservation["partial_path"]).path_join("engine.log"),
		"--script",
		"res://tests/fixtures/lab_nonzero_adopt_child.gd",
	]
	var user_arguments := ["--child-launch-plan", plan_path]
	var plan := LauncherScript.build_launch_plan(
		reservation,
		OS.get_executable_path(),
		engine_arguments,
		user_arguments,
		[],
		ProjectSettings.globalize_path("res://"),
		{
			"engine_log": LauncherScript.captured_log(
				String(reservation["partial_path"]).path_join(
					"engine.log"),
				"godot_--log-file"),
			"stdout": LauncherScript.unavailable_log(
				"probe stdout is inherited"),
			"stderr": LauncherScript.unavailable_log(
				"probe stderr is inherited"),
		},
		{
			"resource_path": "res://tests/probe.tres",
			"resource_sha256":
				"sha256:0000000000000000000000000000000000000000000000000000000000000000",
			"expanded_spec_sha256":
				"sha256:1111111111111111111111111111111111111111111111111111111111111111",
			"experiment_id": "NONZERO_CHILD_PROBE",
			"root_seed": 42,
			"observer_profile_id": "probe_v1",
		})
	var plan_write := LauncherScript.write_launch_plan(plan_path, plan)
	var bound := RunIndexScript.bind_launch_plan(
		reservation["partial_path"],
		reservation["run_id"],
		reservation["adoption_token"],
		plan_path,
		plan_write.get("sha256", ""))
	_check(
		plan_write["ok"] and bound["ok"],
		"parent freezes and binds the exact child launch plan")
	if not plan_write["ok"] or not bound["ok"]:
		_remove_tree(root)
		_finish()
		return
	var launched := LauncherScript.launch_async(
		OS.get_executable_path(), plan["payload"]["arguments"])
	_check(launched["ok"], "fresh probe child starts")
	if not launched["ok"]:
		_remove_tree(root)
		_finish()
		return
	var child_pid := int(launched["child_process_id"])
	var running := LauncherScript.running_process_metadata(
		reservation["run_id"],
		OS.get_executable_path(),
		plan["payload"]["arguments"],
		ProjectSettings.globalize_path("res://"),
		plan["payload"]["log_paths"],
		OS.get_process_id(),
		user_arguments,
		"launcher_exact",
		child_pid,
		{
			"engine_arguments": engine_arguments,
			"requested_user_arguments": [],
			"reservation_id": reservation["reservation_id"],
			"launch_plan_path": plan_path,
			"launch_plan_sha256": plan_write["sha256"],
			"launch_plan_payload_sha256": plan["payload_sha256"],
			"adoption_token_sha256":
				reservation["adoption_token_sha256"],
			"partial_path": reservation["partial_path"],
			"final_path": reservation["final_path"],
		})
	var adoption_deadline := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < adoption_deadline:
		var control := RunIndexScript.read_control_state(
			reservation["partial_path"])
		if control["ok"] and String(
			control["reservation"].get("status", "")) == "ADOPTED":
			break
		await create_timer(0.01).timeout
	var premature := RunIndexScript.authorize_parent_finalization(
		reservation["partial_path"],
		reservation["run_id"],
		reservation["reservation_id"],
		child_pid)
	_check(
		not premature["ok"]
			and premature["error"] == "CHILD_STILL_RUNNING",
		"parent cannot publish while the adopted child is still alive")
	while OS.is_process_running(child_pid):
		await create_timer(0.02).timeout
	var child_exit := OS.get_process_exit_code(child_pid)
	_check(child_exit != 0, "parent observes the actual nonzero child exit")
	var terminal := LauncherScript.terminal_process_metadata(
		running,
		child_exit,
		"child_nonzero_exit",
		"ABORTED",
		OS.get_process_id())
	var recorded := FinalizerScript.record_terminal_metadata(
		reservation["partial_path"],
		reservation["run_id"],
		reservation["reservation_id"],
		child_pid,
		terminal)
	_check(recorded["ok"], "parent terminalizes nonzero process metadata")
	_check(
		DirAccess.dir_exists_absolute(reservation["partial_path"])
			and not DirAccess.dir_exists_absolute(
				reservation["final_path"]),
		"nonzero child remains inspectable .partial and is never renamed")
	_check(
		FileAccess.file_exists(
			String(reservation["partial_path"]).path_join(
				"child_probe.json"))
			and not FileAccess.file_exists(
				String(reservation["partial_path"]).path_join(
					"checksums.json")),
		"candidate bytes survive but child never creates checksums")
	_check(
		not FileAccess.file_exists(
			reservation["token_descriptor_path"])
			and FileAccess.file_exists(
				String(reservation["partial_path"]).path_join(
					".reservation.json")),
		"one-shot token is consumed while parent control state remains")
	var metadata := _read_json(
		String(reservation["partial_path"]).path_join(
			"process_metadata.json"))
	_check(
		metadata["status"] == "ABORTED"
			and int(metadata["exit_code"]) == child_exit
			and int(metadata["termination_observer_process_id"])
				== OS.get_process_id(),
		"terminal metadata preserves the exact observed exit and parent PID")
	_remove_tree(root)
	_finish()


static func _read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


static func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var child := absolute.path_join(name)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)
