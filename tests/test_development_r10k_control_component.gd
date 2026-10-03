extends SceneTree
# gdlint: disable=max-line-length

## Actual native JSON and unloaded-extension boundary. Creates no physics world.
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const OLD := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		quit(1)
		return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile.runtime_binding))
	var checks := {}
	checks["binding_hash"] = "sha256:" + FileAccess.get_sha256(profile.runtime_binding) == profile.runtime_binding_sha256
	checks["extension_hash"] = "sha256:" + FileAccess.get_sha256(profile.extension) == profile.extension_sha256
	for path in ["res://" + binding.local_build_path, binding.runtime.path]:
		checks["dll_" + path] = "sha256:" + FileAccess.get_sha256(path) == profile.runtime_sha256
	for source in binding.source_files:
		checks["source_" + source.path] = "sha256:" + FileAccess.get_sha256("res://" + source.path) == source.raw_sha256
	if checks.values().has(false):
		_finish(checks, [], args[2])
		return
	if GDExtensionManager.is_extension_loaded(OLD):
		checks["unload"] = GDExtensionManager.unload_extension(OLD) == GDExtensionManager.LOAD_STATUS_OK
	checks["load"] = GDExtensionManager.load_extension(profile.extension) == GDExtensionManager.LOAD_STATUS_OK
	if checks.values().has(false):
		_finish(checks, [], args[2])
		return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var input: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[1]))
	var rows := []
	for item in input.cases:
		var request_raw := Transport.stringify(item.request)
		var response_raw: String = sdk.call(item.method, request_raw)
		var response: Dictionary = sdk.decode_exact_json_v1(response_raw)
		var canonical_raw: String = sdk.canonicalize_json(Transport.stringify({"schema_version": "sporespore_canonical_json_request_v1", "value": response}))
		var canonical: Dictionary = sdk.decode_exact_json_v1(canonical_raw)
		checks[item.id] = canonical.get("ok") == true and canonical.get("value", {}).get("sha256") == item.expected_sha256
		rows.append({"id": item.id, "method": item.method, "request_utf8": request_raw,
			"response_utf8": response_raw, "matches": checks[item.id]})
	sdk = null
	_finish(checks, rows, args[2])

func _finish(checks: Dictionary, rows: Array, output: String) -> void:
	var ok := not checks.is_empty() and not checks.values().has(false)
	if FileAccess.file_exists(output):
		quit(1)
		return
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(Transport.stringify({"ok": ok, "checks": checks, "rows": rows,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	file.close()
	print("R10K_CONTROL_COMPONENT " + JSON.stringify({"ok": ok, "cases": rows.size(), "failed": checks.keys().filter(func(key): return not checks[key]), "world_build_count": 0, "solver_step_count": 0}))
	quit(0 if ok else 1)
