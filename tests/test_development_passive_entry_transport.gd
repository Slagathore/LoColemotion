extends SceneTree

const Stage := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_stage_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const OLD_EXTENSION := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const NEW_EXTENSION := "res://sdk/adapters/godot/development_passive_entry_runtime/runtime.gdextension"
const RETAINED_REPORT := "C:/Users/Cole/CodeStuff/games/SporeSpore_Evidence/development-recovery-smoke-4b4c9c059591449a92c32c131239c487/children/kick_passive_recovery_resume/worker_report.json"


func _initialize() -> void:
	call_deferred("_run")

func _extension_v1() -> String:
	return NEW_EXTENSION


func _run() -> void:
	# Only this fresh test process swaps extensions, before creating any SDK
	# instance. The old DLL/resource and editor processes remain untouched.
	if GDExtensionManager.is_extension_loaded(OLD_EXTENSION):
		var unloaded := GDExtensionManager.unload_extension(OLD_EXTENSION)
		if unloaded != GDExtensionManager.LOAD_STATUS_OK:
			_finish({"unload_old_extension": false}, unloaded)
			return
	var loaded := GDExtensionManager.load_extension(_extension_v1())
	if loaded != GDExtensionManager.LOAD_STATUS_OK:
		_finish({"load_new_extension": false}, loaded)
		return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var checks := {}
	checks["new_methods_present"] = sdk.has_method("recovery_collect_passive_native_v1_json") and sdk.has_method("decode_passive_recovery_response_v1")
	var exact := "{\"ok\":true,\"value\":{\"schema_version\":\"sporespore_recovery_passive_entry_receipt_v1\",\"numbers\":[-1077.495694072387,-0.02255246071647088,1085.0814377148167,0.3235965073108673],\"nested\":{\"flag\":true,\"empty\":null,\"step\":334}}}"
	var decoded: Variant = sdk.decode_passive_recovery_response_v1(exact)
	checks["typed_decode_valid"] = decoded is Dictionary
	if decoded is Dictionary:
		# Re-encode actual binary64 values into full-precision JSON. Python checks
		# their bits against the original request; Godot parsing is not the oracle.
		checks["roundtrip_json"] = Transport.stringify(decoded)
		checks["source_json"] = exact
	checks["unknown_schema_refused"] = sdk.decode_passive_recovery_response_v1("{\"ok\":true,\"value\":{\"schema_version\":\"unknown\"}}") == null
	checks["malformed_response_refused"] = sdk.decode_passive_recovery_response_v1("{") == null
	checks["malformed_entry_refused"] = Runtime.passive_entry_step_v1(sdk, {"schema_version": Runtime.PASSIVE_ENTRY_REQUEST_V1_SCHEMA}).get("ok") == false
	checks["malformed_collection_refused"] = Runtime.collect_passive_native_v1(sdk, {"schema_version": "sporespore_recovery_passive_native_collection_request_v1"}).get("ok") == false
	checks["bridge_missing_source_refused"] = Stage.advance_v1(sdk, {}, "test", 120, {}).get("failure_code") == "PASSIVE_ENTRY_BOUND_SOURCE_MISSING:observation_v2"
	var retained: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(RETAINED_REPORT))
	var arm: Dictionary = retained["retained_arm"]
	var bound: Dictionary = arm["terminal_recovery_observation_sources"]["bound_recovery_observations"]
	checks["retained_representations_agree"] = Stage.representations_agree_v1(bound)
	var crossed := bound.duplicate(true)
	crossed["observation_v3"]["center_of_mass"]["position_world_m"]["y"] += 0.1
	checks["crossed_pose_refused"] = not Stage.representations_agree_v1(crossed)
	crossed = bound.duplicate(true)
	crossed["observation_v3"]["energy_balance"]["cumulative_signed_discrete_staging_exchange_j"] += 0.1
	checks["crossed_staging_refused"] = not Stage.representations_agree_v1(crossed)
	var original: Dictionary = sdk.decode_exact_json_v1(arm["last_recovery_collection_transport_retention"]["request"]["utf8_text"])
	var context := {"morphology_context": original["morphology_context"],
		"capability": original["adapter_capability"], "runtime_binding": original["runtime_binding"]}
	var attempt: String = bound["source_component_receipts"]["epoch_initializer"]["attempt_id"]
	var packet := Stage.advance_v1(sdk, context, attempt, 120, bound)
	checks["actual_bridge_preserves_original_owner_refusal"] = packet.get("failure_code") == "PASSIVE_ENTRY_NATIVE_COLLECTION_REFUSED"
	checks["actual_bridge_retains_collection_not_entry"] = packet.get("collection_call") is Dictionary and packet["collection_call"].get("compiled_call_count") == 1 and packet["entry_call"] == null
	checks["actual_bridge_refusal_json"] = Transport.stringify({"failure_code": packet["failure_code"], "collection_call": packet["collection_call"]})
	sdk = null
	_finish(checks, 0)


func _finish(checks: Dictionary, load_status: int) -> void:
	var ok := load_status == 0
	for key in checks:
		if not key.ends_with("_json") and checks[key] != true:
			ok = false
	print("DEVELOPMENT_PASSIVE_ENTRY_TRANSPORT ", Transport.stringify({
		"ok": ok, "checks": checks, "load_status": load_status,
		"world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false,
	}))
	quit(0 if ok else 1)
