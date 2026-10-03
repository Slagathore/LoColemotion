extends SceneTree

const CanonicalJsonScript := preload(
	"res://scripts/lab/canonical_json.gd")
const LauncherScript := preload(
	"res://scripts/lab/lab_process_launcher.gd")
const RunIndexScript := preload("res://scripts/lab/run_index.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2 \
			or String(arguments[0]) != "--child-launch-plan":
		quit(4)
		return
	var plan_path := String(arguments[1])
	var loaded := LauncherScript.load_launch_plan(plan_path)
	if not loaded["ok"]:
		quit(4)
		return
	var plan: Dictionary = loaded["plan"]
	var payload: Dictionary = plan["payload"]
	var adoption := RunIndexScript.adopt_partial(
		payload["partial_path"],
		plan["run_id"],
		payload["token_descriptor_path"],
		plan_path,
		OS.get_process_id())
	if not adoption["ok"]:
		quit(5)
		return
	var marker := {
		"run_id": plan["run_id"],
		"child_process_id": OS.get_process_id(),
		"status": "ADOPTED_THEN_FORCED_NONZERO",
	}
	var file := FileAccess.open(
		String(payload["partial_path"]).path_join("child_probe.json"),
		FileAccess.WRITE)
	if file == null:
		quit(5)
		return
	file.store_string(CanonicalJsonScript.stringify(marker) + "\n")
	file.close()
	await create_timer(0.5).timeout
	quit(7)
