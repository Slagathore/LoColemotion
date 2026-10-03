extends SceneTree
# gdlint: disable=max-line-length
## Synthetic interface probes only; no bodies, worlds or solver calls.
const Source := preload("res://sdk/adapters/godot/gdscript/r10aa_partial_task_source_v1.gd")
const Native := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const PROFILE := "res://sdk/development/recovery_candidates/r10ap-progressive-headroom-v1.json"
const OLD := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"

func _initialize() -> void:
	call_deferred("_run")

func _sha(sdk: Object, value: Variant) -> String:
	return Runtime.canonicalize(sdk, value).get("sha256", "")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or FileAccess.file_exists(args[1]): quit(1); return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	if GDExtensionManager.is_extension_loaded(OLD): GDExtensionManager.unload_extension(OLD)
	if GDExtensionManager.load_extension(profile.extension) != GDExtensionManager.LOAD_STATUS_OK: quit(1); return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var value: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	var checks := {}
	var negatives := 0
	checks["fixture_population"] = value.fixtures.size() == 44
	checks["runtime_hash"] = "sha256:" + FileAccess.get_sha256(JSON.parse_string(FileAccess.get_file_as_string(profile.runtime_binding)).runtime.path) == profile.runtime_sha256
	for index in range(value.fixtures.size()):
		var fixture: Dictionary = value.fixtures[index]
		var prefix := str(index) + "_"
		var envelope: Dictionary = sdk.decode_exact_json_v1(sdk.recovery_r10aa_partial_step_control_v1_json(Transport.stringify(fixture.request)))
		checks[prefix + "native_exact"] = envelope.get("ok") == true and _sha(sdk, envelope.get("value")) == _sha(sdk, fixture.expected)
		if envelope.get("ok") != true: continue
		var receipt: Dictionary = envelope.value
		var context := Source.control_context_v1(sdk, receipt)
		checks[prefix + "source_context"] = context.get("ok") == true
		checks[prefix + "loaded_mode"] = receipt.next_load_plan.mode == "loaded_geometry_rise"
		if context.get("ok") != true: continue
		var application := {"ok": true, "semantic_step": int(context.control.semantic_step) + 1, "phase": context.control.phase,
			"command_sha256": context.control.command_sha256, "controller_owner": "recovery",
			"recovery_controller_id": Source.RECOVERY, "stance_controller_id": null, "fallback_controller_active": false,
			"zero_command": false, "physical_acceptance_authority": false, "release_authority": false,
			"synthetic_application_fixture": true}
		var bound := Source.bind_application_v1(sdk, receipt, application)
		checks[prefix + "binding"] = bound.get("ok") == true
		if bound.get("ok") == true:
			checks[prefix + "sampler_selection"] = Native.TaskSource.select_v1(sdk, {Source.KEY: bound.model_binding}, bound.application, context.semantic_step).get("ok") == true
		for defect in range(8):
			var bad: Dictionary = receipt.duplicate(true)
			if defect < 4: bad.next_load_plan.qualified_support[defect] = 1
			elif defect == 4: bad.next_load_plan.rise_geometry.schema_version = "crossed_geometry"
			elif defect == 5: bad.next_load_plan.mode = "loaded_downward_rise"
			elif defect == 6: bad.next_load_plan.rise_geometry.source_observation_sha256 = "sha256:" + "0".repeat(64)
			else: bad.next_load_plan.physical_acceptance_authority = true
			checks[prefix + "refuse_" + str(defect)] = Source.control_context_v1(sdk, bad).get("ok") == false
			negatives += 1
	var result := {"ok": not checks.values().has(false) and checks.size() == 574, "checks": checks,
		"loaded_inputs": value.fixtures.size(), "negative_checks": negatives, "synthetic_inputs": true,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
	var stream := FileAccess.open(args[1], FileAccess.WRITE)
	if stream == null: quit(1); return
	stream.store_string(Transport.stringify(result))
	stream.close()
	quit(0 if result.ok else 1)
