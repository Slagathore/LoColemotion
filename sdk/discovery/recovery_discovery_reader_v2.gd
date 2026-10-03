extends SceneTree
## Prospective reader successor: preserve JSON integer types through the native
## exact decoder. V1 and its observed rejection remain retained unchanged.
const Frames := preload("res://sdk/adapters/godot/gdscript/r10af_contact_frame_capture_v1.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or FileAccess.file_exists(args[1]): quit(2); return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_candidates/r10ap-progressive-headroom-v1.json"))
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile.runtime_binding))
	if "sha256:" + FileAccess.get_sha256("res://" + String(binding.local_build_path)) != profile.runtime_sha256: quit(3); return
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old):
		if GDExtensionManager.unload_extension(old) != GDExtensionManager.LOAD_STATUS_OK: quit(4); return
	if GDExtensionManager.load_extension(profile.extension) != GDExtensionManager.LOAD_STATUS_OK: quit(5); return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var report: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	var rows: Array = [report.disturbance.baseline] + report.tail_rows
	var failures := []
	for row in rows:
		var replay := Frames.Native.validate_native_snapshot(Frames.unpack_native_v1(row.contacts), int(row.global_step))
		if replay.get("ok") != true: failures.append({"step": row.global_step, "failure": replay})
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": failures.is_empty(), "reader_version": 2, "row_count": rows.size(), "failures": failures,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	file.close()
	sdk = null
	quit(0 if failures.is_empty() else 1)
