extends SceneTree
## Replay one retained startup input without constructing or stepping a world.
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Memo := preload("res://sdk/explorer/native_recovery/memoized_sdk.gd")
const Cache := preload("res://sdk/explorer/studio/immutable_context_cache.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const Collection := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_transport_v1.gd")

func _initialize() -> void:
	PhysicsServer3D.set_active(false)
	var result := _run_probe()
	var output := OS.get_environment("STUDIO_STARTUP_PROBE_OUTPUT")
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(Transport.stringify(result)+"\n")
	file.close()
	print(JSON.stringify({"ok":result.get("ok",false),"rows":result.get("rows",[]).size(),
		"failure":result.get("failure",""),"world_build_count":0,"solver_steps":0}))
	quit(0 if result.get("ok")==true else 1)

func _run_probe() -> Dictionary:
	var loaded := GDExtensionManager.load_extension("res://sdk/adapters/godot/development_candidate_runtimes/r10ap-progressive-headroom-core-v1.gdextension")
	if loaded != GDExtensionManager.LOAD_STATUS_OK:
		return {"ok":false,"failure":"native extension load","status":loaded}
	var native: Object = ClassDB.instantiate("SporeLocomotionSdk")
	if not is_instance_valid(native):return {"ok":false,"failure":"native SDK unavailable"}
	# Retained source bytes require the existing exact decoder: Godot's generic
	# JSON parser changes integer types and some binary64 values on round-trip.
	var packet: Dictionary = native.decode_exact_json_v1(FileAccess.get_file_as_string(OS.get_environment("STUDIO_STARTUP_PROBE_INPUT")))
	var context: Dictionary = native.decode_exact_json_v1(packet.context.utf8_text)
	var bound: Dictionary = native.decode_exact_json_v1(packet.sources.bound_observation.utf8_text)
	var memory: Dictionary = native.decode_exact_json_v1(packet.sources.source_memory.utf8_text)
	var application: Dictionary = native.decode_exact_json_v1(packet.sources.source_application.utf8_text)
	var expected_step := Transport.stringify(packet.expected_step)
	var input_identity := Transport.stringify([context,bound,memory,application])
	var rows: Array = []
	var sdk: Object
	for mode in ["fresh_cache","reused_cache"]:
		for repeat in 16:
			if mode == "fresh_cache" or repeat == 0:
				sdk = Memo.new(native)
				Cache.reset()
				Cache.enabled = true
			Runtime.startup_probe_profile = {}
			for module in [Runtime,Collection,Route,Cache]:module.startup_function_profile = {}
			Transport.profile = {"calls":0,"total_us":0,"maximum_us":0,"characters":0}
			sdk.bridge_profile.clear()
			var started := Time.get_ticks_usec()
			var result := Route.advance_behavior_solver_coupled_complete_energy_l15_v1(
				sdk,context,bound,memory,String(packet.get("arm_kind","candidate_command")),String(memory.phase),application)
			var elapsed := Time.get_ticks_usec()-started
			var costs: Dictionary = Runtime.startup_probe_profile.duplicate(true)
			var json_costs: Dictionary = Transport.profile.duplicate(true)
			var bridge_costs: Dictionary = sdk.bridge_profile.duplicate(true)
			var function_costs: Dictionary = {}
			for module in [Runtime,Collection,Route,Cache]:
				function_costs[module.resource_path] = module.startup_function_profile.duplicate(true)
			if result.get("ok") != true:
				return {"ok":false,"failure":"retained route refused","mode":mode,"repeat":repeat,"result":result,"rows":rows}
			var capture: Dictionary = result.collection_transport_retention
			if capture.request != packet.request or capture.response != packet.response:
				return {"ok":false,"failure":"native collection transport differs","mode":mode,"repeat":repeat,
					"actual_request":capture.request,"actual_response":capture.response,"rows":rows}
			if Transport.stringify(result.step_receipt) != expected_step:
				return {"ok":false,"failure":"retained step differs","mode":mode,"repeat":repeat,"actual_step":result.step_receipt,"rows":rows}
			if Transport.stringify([context,bound,memory,application]) != input_identity:
				return {"ok":false,"failure":"replay mutated source inputs","rows":rows}
			var route_text := Transport.stringify(result)
			if packet.has("expected_route") and route_text != packet.expected_route.utf8_text:
				return {"ok":false,"failure":"full retained route differs","mode":mode,"repeat":repeat,
					"actual_route":route_text,"rows":rows}
			rows.append({"mode":mode,"repeat":repeat,"elapsed_us":elapsed,
				"full_route_output_sha256":route_text.sha256_text(),
				"canonicalization":costs,"all_authoritative_stringify":json_costs,
				"native_bridge":bridge_costs,"cache":sdk.cache_summary(),
				"inclusive_function_costs":function_costs})
	Cache.enabled = false
	Cache.reset()
	return {"ok":true,"rows":rows,"global_step":packet.global_step,
		"full_retained_route_compared":packet.has("expected_route"),
		"collection_request_and_response_exact":true,"step_receipt_exact":true,"source_inputs_unchanged":true,
		"world_build_count":0,"solver_steps":0,"native_physics_reads":0,
		"scope":"Repeated computational replay of one retained startup packet. Fresh and reused cache modes are diagnostic bounds, not the live startup distribution or a speedup qualification.",
		"physical_acceptance_authority":false,"release_authority":false}
