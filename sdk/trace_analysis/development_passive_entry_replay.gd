extends SceneTree

## Read-only CLI: --script <this resource> -- <JSON input file>.
## The input is one replay request or a finite test batch. No worker is created.
const Replay := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_replay_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const BINDING := "res://sdk/development_passive_entry_runtime_binding_v1.json"
const OLD := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const NEW := "res://sdk/adapters/godot/development_passive_entry_runtime/runtime.gdextension"

func _initialize() -> void:
	call_deferred("_run")

func _selection_v1() -> Dictionary:
	return {"binding": BINDING, "extension": NEW, "controller_id": Replay.Canonical.Route.RECOVERY_CONTROLLER_V6_ID,
		"marker": "DEVELOPMENT_PASSIVE_ENTRY_REPLAY "}

func _input_arguments_v1() -> PackedStringArray:
	return OS.get_cmdline_user_args()

func _run() -> void:
	var args := _input_arguments_v1()
	if args.size() != 1 or not FileAccess.file_exists(args[0]):
		_finish({"ok": false, "failure_code": "PASSIVE_REPLAY_INPUT_PATH"})
		return
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_selection_v1()["binding"]))
	for path in ["res://" + binding["local_build_path"], binding["runtime"]["path"]]:
		if not FileAccess.file_exists(path) or "sha256:" + FileAccess.get_sha256(path) != binding["runtime"]["raw_sha256"]:
			_finish({"ok": false, "failure_code": "PASSIVE_REPLAY_RUNTIME_DRIFT"})
			return
	for source in binding["source_files"]:
		if "sha256:" + FileAccess.get_sha256("res://" + source["path"]) != source["raw_sha256"]:
			_finish({"ok": false, "failure_code": "PASSIVE_REPLAY_COMPILED_SOURCE_DRIFT"})
			return
	if GDExtensionManager.is_extension_loaded(OLD) and GDExtensionManager.unload_extension(OLD) != GDExtensionManager.LOAD_STATUS_OK:
		_finish({"ok": false, "failure_code": "PASSIVE_REPLAY_OLD_EXTENSION_UNLOAD"})
		return
	if GDExtensionManager.load_extension(_selection_v1()["extension"]) != GDExtensionManager.LOAD_STATUS_OK:
		_finish({"ok": false, "failure_code": "PASSIVE_REPLAY_NEW_EXTENSION_LOAD"})
		return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var raw := FileAccess.get_file_as_string(args[0])
	var input: Variant = sdk.decode_exact_json_v1(raw)
	if not (input is Dictionary):
		_finish({"ok": false, "failure_code": "PASSIVE_REPLAY_INPUT_JSON"})
		return
	var result: Dictionary
	if input.get("schema_version") == "sporespore_development_passive_entry_replay_test_batch_v1":
		var rows := []
		for item in input["cases"]:
			rows.append({"case_id": item["case_id"], "replay": _dispatch(sdk, item["input"], binding)})
		result = {"ok": true, "cases": rows, "synthetic_test_batch": true}
	else:
		result = _dispatch(sdk, input, binding)
	result["input_raw_sha256"] = "sha256:" + raw.sha256_text()
	result["runtime_raw_sha256"] = binding["runtime"]["raw_sha256"]
	result["process_id"] = OS.get_process_id()
	sdk = null
	_finish(result)

func _dispatch(sdk: Object, input: Dictionary, binding: Dictionary) -> Dictionary:
	var controller_id: String = _selection_v1()["controller_id"]
	var profile := Replay.selection_v1(controller_id)
	if input.get("schema_version") == profile["worker_selection"]["report_schema"]:
		return Replay.replay_report_v1(sdk, input, binding, controller_id)
	if input.get("schema_version") == profile["report_input_schema"]:
		if not (input.get("report") is Dictionary):
			return {"ok": false, "failure_code": "PASSIVE_REPLAY_REPORT_MISSING"}
		return Replay.replay_report_v1(sdk, input["report"], binding, controller_id)
	return Replay.replay_v1(sdk, input, binding, controller_id)

func _finish(result: Dictionary) -> void:
	result["world_build_count"] = 0
	result["native_physics_read_count"] = 0
	result["solver_step_count"] = 0
	result["physical_acceptance_authority"] = false
	result["release_authority"] = false
	print(_selection_v1()["marker"], Transport.stringify(result))
	quit(0 if result.get("ok") == true else 1)
