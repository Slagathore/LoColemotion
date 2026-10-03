extends SceneTree
const Guard := preload("res://sdk/adapters/godot/gdscript/r10dg_native_world_guard_v1.gd")
var checks := {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1: quit(2); return
	var pid := OS.get_process_id()
	checks.closed = not Guard.take_world_permission_v1()
	checks.fixture_refused = not Guard.authorize_worker_v1({"report_fixture_only": true})
	checks.still_closed = not Guard.take_world_permission_v1()
	var first := Guard.consume_permission_v1({"worker_process_id": pid, "consumed": false}, pid)
	checks.first_consumption = first.get("ok") == true
	checks.no_second_consumption = Guard.consume_permission_v1(first.next_permission, pid).get("ok") == false
	checks.wrong_owner = Guard.consume_permission_v1({"worker_process_id": pid+1, "consumed": false}, pid).get("ok") == false
	checks.wrong_type = Guard.consume_permission_v1({"worker_process_id": pid, "consumed": 0}, pid).get("ok") == false
	var host: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Guard.Runtime.CONTRACT))
	var output: Array = []
	var code := OS.execute(host.images.python_helper.path, PackedStringArray(["-B", "-X", "utf8",
		ProjectSettings.globalize_path(Guard.HELPER), "--probe-worker", "--worker-pid", str(pid)]), output, true, false)
	var result: Variant = JSON.parse_string(output[0]) if output.size() == 1 else null
	checks.actual_helper_parent = code == 0 and result is Dictionary and result.get("ok") == true
	checks.actual_helper_image = result is Dictionary and result.get("worker_image") == host.images.godot_engine
	checks.helper_no_world = result is Dictionary and result.get("world_build_count") == 0 and result.get("solver_step_count") == 0
	checks.probe_grants_no_permission = not Guard.take_world_permission_v1()
	var receipt := {"ok": not checks.values().has(false), "checks": checks, "helper_output": output,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt)); file.close()
	quit(0 if receipt.ok else 1)
