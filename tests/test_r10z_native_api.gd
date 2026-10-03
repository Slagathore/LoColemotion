extends SceneTree
# gdlint: disable=max-line-length

## Actual GDExtension calls on synthetic fixtures; no model or solver work.
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const PROFILE := "res://sdk/development/recovery_candidates/r10z-partial-pose-geometry-core-v1.json"
const OLD := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or FileAccess.file_exists(args[1]):
		quit(1)
		return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	var checks := {}
	checks["extension_hash"] = "sha256:" + FileAccess.get_sha256(profile.extension) == profile.extension_sha256
	checks["binding_hash"] = "sha256:" + FileAccess.get_sha256(profile.runtime_binding) == profile.runtime_binding_sha256
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile.runtime_binding))
	checks["runtime_hash"] = "sha256:" + FileAccess.get_sha256(binding.runtime.path) == profile.runtime_sha256
	checks["fixture_hash"] = "sha256:" + FileAccess.get_sha256(args[0]) == binding.compiled_fixtures.raw_sha256
	if GDExtensionManager.is_extension_loaded(OLD):
		checks["unload_default"] = GDExtensionManager.unload_extension(OLD) == GDExtensionManager.LOAD_STATUS_OK
	checks["load_candidate"] = GDExtensionManager.load_extension(profile.extension) == GDExtensionManager.LOAD_STATUS_OK
	if checks.values().has(false):
		_finish(checks, args[1])
		return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var fixtures := []
	for line in FileAccess.get_file_as_string(args[0]).split("\n"):
		if line.begins_with("R10Z_PARTIAL_FIXTURE "):
			fixtures.append(sdk.decode_exact_json_v1(line.trim_prefix("R10Z_PARTIAL_FIXTURE ")))
	checks["five_compiled_fixtures"] = fixtures.size() == 5
	for item in fixtures:
		var method: String = item.method + "_json"
		checks[item.id + "_method"] = sdk.has_method(method)
		if not sdk.has_method(method):
			continue
		var envelope: Dictionary = sdk.decode_exact_json_v1(sdk.call(method, Transport.stringify(item.request)))
		checks[item.id + "_native_success"] = envelope.get("ok") == true
		checks[item.id + "_exact_value"] = Runtime.canonicalize(sdk, envelope.get("value", {})).get("sha256") == Runtime.canonicalize(sdk, item.expected).get("sha256")
		var bad: Dictionary = item.request.duplicate(true)
		bad.schema_version = "crossed_r10z_schema"
		var refused: Dictionary = sdk.decode_exact_json_v1(sdk.call(method, Transport.stringify(bad)))
		checks[item.id + "_crossed_schema_refused"] = refused.get("ok") == false
	_finish(checks, args[1])

func _finish(checks: Dictionary, output: String) -> void:
	var result := {"ok": not checks.is_empty() and not checks.values().has(false), "checks": checks,
		"new_fixture_calls": 5, "negative_calls": 5, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
	var stream := FileAccess.open(output, FileAccess.WRITE)
	if stream == null:
		quit(1)
		return
	stream.store_string(JSON.stringify(result))
	stream.close()
	print("R10Z_NATIVE_API ", JSON.stringify(result))
	quit(0 if result.ok else 1)
