extends SceneTree

const LauncherScript := preload(
	"res://scripts/lab/lab_process_launcher.gd")
const FinalizerScript := preload(
	"res://scripts/lab/lab_run_finalizer.gd")
const RunIndexScript := preload("res://scripts/lab/run_index.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab launch reservation/adoption security contract ===")
	var generated_id := LauncherScript.make_run_id("L0_3", "42")
	_check(
		generated_id.contains("_L0_3_seed-42_"),
		"run-ID sanitization preserves L0_3 and seed 42")

	var root := ProjectSettings.globalize_path(
		"res://.tmp/lab_launch_adoption_%d_%d" % [
			OS.get_process_id(),
			Time.get_ticks_usec(),
		]).replace("\\", "/")
	var reservation := RunIndexScript.reserve_partial(
		root, "L0_3_seed_42", OS.get_process_id())
	_check(reservation["ok"], "one parent atomically reserves the partial path")
	if not reservation["ok"]:
		_finish()
		return
	var plan_path := String(reservation["partial_path"]).path_join(
		"launch_plan.json")
	var engine_arguments := [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		"res://scripts/lab/run_lab.gd",
	]
	var child_arguments := ["--child-launch-plan", plan_path]
	var plan := LauncherScript.build_launch_plan(
		reservation,
		OS.get_executable_path(),
		engine_arguments,
		child_arguments,
		["--experiment-spec", "res://planned.tres", "--seed", "42"],
		ProjectSettings.globalize_path("res://"),
		{
			"engine_log": LauncherScript.captured_log(
				"C:/tmp/lab.log", "godot_--log-file"),
			"stdout": LauncherScript.unavailable_log(
				"probe stdout is inherited"),
			"stderr": LauncherScript.unavailable_log(
				"probe stderr is inherited"),
		},
		{
			"resource_path": "res://planned.tres",
			"resource_sha256":
				"sha256:0000000000000000000000000000000000000000000000000000000000000000",
			"expanded_spec_sha256":
				"sha256:0000000000000000000000000000000000000000000000000000000000000000",
			"experiment_id": "L0_3",
			"root_seed": 42,
			"observer_profile_id": "full_contacts_v1",
		})
	var plan_write := LauncherScript.write_launch_plan(plan_path, plan)
	_check(plan_write["ok"], "parent writes one schema-valid frozen launch plan")
	if not plan_write["ok"]:
		_remove_tree(root)
		_finish()
		return
	var plan_text := FileAccess.get_file_as_string(plan_path)
	_check(
		not plan_text.contains("\"adoption_token\":")
			and not plan_text.contains(String(reservation["adoption_token"])),
		"public launch plan never stores the raw adoption token")
	_check(
		plan_text.contains("\"adoption_token_sha256\":"),
		"public launch plan stores only the token hash")
	_check(
		plan["payload"]["arguments"]
			== engine_arguments + ["--"] + child_arguments,
		"frozen launch plan retains the exact spawned argument vector")

	var forged_bind := RunIndexScript.bind_launch_plan(
		reservation["partial_path"],
		"L0_3_seed_42",
		"forged-token",
		plan_path,
		plan_write["sha256"])
	_check(
		not forged_bind["ok"]
			and forged_bind["error"] == "ADOPTION_TOKEN_MISMATCH",
		"forged token cannot bind the reservation")
	var bound := RunIndexScript.bind_launch_plan(
		reservation["partial_path"],
		"L0_3_seed_42",
		reservation["adoption_token"],
		plan_path,
		plan_write["sha256"])
	_check(bound["ok"], "authentic parent binds the exact launch-plan path/hash")

	var forged_run := RunIndexScript.adopt_partial(
		reservation["partial_path"],
		"forged_run_id",
		reservation["token_descriptor_path"],
		plan_path,
		OS.get_process_id())
	_check(
		not forged_run["ok"]
			and forged_run["error"] == "RUN_ID_MISMATCH",
		"forged run ID cannot consume adoption")
	var forged_path := RunIndexScript.adopt_partial(
		String(reservation["partial_path"]) + "_forged",
		"L0_3_seed_42",
		reservation["token_descriptor_path"],
		plan_path,
		OS.get_process_id())
	_check(not forged_path["ok"], "forged partial path cannot adopt")
	_check(
		FileAccess.file_exists(reservation["token_descriptor_path"]),
		"failed forgery does not consume the one-shot token descriptor")

	var adopted := RunIndexScript.adopt_partial(
		reservation["partial_path"],
		"L0_3_seed_42",
		reservation["token_descriptor_path"],
		plan_path,
		OS.get_process_id())
	_check(adopted["ok"], "authentic child adopts exactly once")
	_check(
		not FileAccess.file_exists(reservation["token_descriptor_path"]),
		"successful adoption deletes the raw-token descriptor")
	var second := RunIndexScript.adopt_partial(
		reservation["partial_path"],
		"L0_3_seed_42",
		reservation["token_descriptor_path"],
		plan_path,
		OS.get_process_id())
	_check(
		not second["ok"] and second["error"] == "RUN_ALREADY_ADOPTED",
		"second adoption is rejected even by the original child identity")
	_remove_tree(root)
	_test_spawn_failure_is_terminal()
	_finish()


func _test_spawn_failure_is_terminal() -> void:
	var root := ProjectSettings.globalize_path(
		"res://.tmp/lab_spawn_failure_%d_%d" % [
			OS.get_process_id(),
			Time.get_ticks_usec(),
		]).replace("\\", "/")
	var reservation := RunIndexScript.reserve_partial(
		root, "spawn_failure", OS.get_process_id())
	var plan_path := String(reservation.get("partial_path", "")).path_join(
		"launch_plan.json")
	var missing_executable := root.path_join("definitely_missing.exe")
	var engine_arguments := ["--headless"]
	var user_arguments := ["--child-launch-plan", plan_path]
	var plan := LauncherScript.build_launch_plan(
		reservation,
		missing_executable,
		engine_arguments,
		user_arguments,
		[],
		ProjectSettings.globalize_path("res://"),
		{
			"engine_log": LauncherScript.unavailable_log(
				"process was not created"),
			"stdout": LauncherScript.unavailable_log(
				"process was not created"),
			"stderr": LauncherScript.unavailable_log(
				"process was not created"),
		},
		{
			"resource_path": "res://tests/probe.tres",
			"resource_sha256":
				"sha256:0000000000000000000000000000000000000000000000000000000000000000",
			"expanded_spec_sha256":
				"sha256:1111111111111111111111111111111111111111111111111111111111111111",
			"experiment_id": "SPAWN_FAILURE_PROBE",
			"root_seed": 42,
			"observer_profile_id": "probe_v1",
		})
	var written := LauncherScript.write_launch_plan(plan_path, plan)
	var bound := RunIndexScript.bind_launch_plan(
		reservation["partial_path"],
		reservation["run_id"],
		reservation["adoption_token"],
		plan_path,
		written.get("sha256", ""))
	var running := LauncherScript.running_process_metadata(
		reservation["run_id"],
		missing_executable,
		plan["payload"]["arguments"],
		ProjectSettings.globalize_path("res://"),
		plan["payload"]["log_paths"],
		OS.get_process_id(),
		user_arguments,
		"launcher_exact",
		-1,
		{
			"engine_arguments": engine_arguments,
			"requested_user_arguments": [],
			"reservation_id": reservation["reservation_id"],
			"launch_plan_path": plan_path,
			"launch_plan_sha256": written.get("sha256"),
			"launch_plan_payload_sha256": plan["payload_sha256"],
			"adoption_token_sha256":
				reservation["adoption_token_sha256"],
			"partial_path": reservation["partial_path"],
			"final_path": reservation["final_path"],
		})
	print("HARNESS_EXPECT_ENGINE_ERROR=CHILD_PROCESS_CREATE_FAILED")
	var launch := LauncherScript.launch_async(
		missing_executable, plan["payload"]["arguments"])
	var terminal := LauncherScript.terminal_process_metadata(
		running,
		-1,
		"child_process_create_failed",
		"ABORTED",
		OS.get_process_id())
	var metadata_write := FinalizerScript.record_terminal_metadata(
		reservation["partial_path"],
		reservation["run_id"],
		reservation["reservation_id"],
		-1,
		terminal)
	var aborted := RunIndexScript.abort_before_adoption(
		reservation["partial_path"],
		reservation["run_id"],
		reservation["reservation_id"],
		"child_process_create_failed")
	_check(
		written["ok"] and bound["ok"] and not launch["ok"],
		"missing executable produces a real spawn failure after reservation")
	_check(
		metadata_write["ok"] and aborted["ok"],
		"parent writes terminal spawn-failure evidence and invalidates reservation")
	var control := RunIndexScript.read_control_state(
		reservation["partial_path"])
	_check(
		control["ok"]
			and control["reservation"]["status"] == "SPAWN_FAILED"
			and not FileAccess.file_exists(
				reservation["token_descriptor_path"]),
		"spawn failure consumes the raw token and leaves explicit control status")
	_check(
		DirAccess.dir_exists_absolute(reservation["partial_path"])
			and not DirAccess.dir_exists_absolute(
				reservation["final_path"]),
		"spawn failure remains inspectable and never publishes")
	_remove_tree(root)


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
