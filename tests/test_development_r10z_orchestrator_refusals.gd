extends SceneTree
# gdlint: disable=max-line-length
const Route := preload("res://sdk/adapters/godot/gdscript/r10z_recovery_orchestrator_v1.gd")
const Original := preload("res://sdk/adapters/godot/gdscript/r10v_recovery_orchestrator_v1.gd")
var checks := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_candidates/r10z-partial-pose-geometry-core-v1.json"))
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old):
		checks["unload"] = GDExtensionManager.unload_extension(old) == GDExtensionManager.LOAD_STATUS_OK
	checks["load"] = GDExtensionManager.load_extension(profile.extension) == GDExtensionManager.LOAD_STATUS_OK
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var cases: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	for name in cases:
		var row: Dictionary = cases[name]
		checks[name + "_valid"] = Route.advance_v1(sdk, row.state_before, row.event) == row.advance
		checks[name + "_original_rejects_successor"] = not Original.state_valid_v1(sdk, row.state_before)
		var bad: Dictionary = row.event.duplicate(true)
		bad.global_semantic_step += 1
		bad.payload_sha256 = Route.Prior._payload_sha256_v1(sdk, bad)
		checks[name + "_skipped_clock"] = Route.advance_v1(sdk, row.state_before, bad).get("ok") != true
		for flag in ["body_population_rebuild_count", "body_transform_write_count", "body_velocity_write_count", "solver_reset_count"]:
			bad = row.event.duplicate(true)
			bad[flag] = 1
			bad.payload_sha256 = Route.Prior._payload_sha256_v1(sdk, bad)
			checks[name + "_" + flag] = Route.advance_v1(sdk, row.state_before, bad).get("ok") != true
		if name in ["entry", "handoff", "partial", "complete", "prone"]:
			bad = row.event.duplicate(true)
			bad.r10v_native_receipt.control_composition_id = "crossed"
			bad.payload_sha256 = Route.Prior._payload_sha256_v1(sdk, bad)
			checks[name + "_composition"] = not Route.event_valid_v1(sdk, bad)
			bad = row.event.duplicate(true)
			bad.r10v_native_receipt.physical_acceptance_authority = true
			bad.payload_sha256 = Route.Prior._payload_sha256_v1(sdk, bad)
			checks[name + "_authority"] = not Route.event_valid_v1(sdk, bad)
			bad = row.event.duplicate(true)
			if name in ["entry", "handoff", "prone"]:
				bad.r10v_native_receipt = bad.r10v_native_receipt.original_entry_control
			else:
				bad.r10v_native_receipt.schema_version = "sporespore_partial_fall_step_control_receipt_v1"
			bad.payload_sha256 = Route.Prior._payload_sha256_v1(sdk, bad)
			checks[name + "_original_receipt"] = not Route.event_valid_v1(sdk, bad)
		if name in ["partial", "complete"]:
			bad = row.event.duplicate(true)
			bad.partial_prior_memory_sha256 = "sha256:" + "0".repeat(64)
			bad.payload_sha256 = Route.Prior._payload_sha256_v1(sdk, bad)
			checks[name + "_crossed_memory"] = Route.advance_v1(sdk, row.state_before, bad).get("ok") != true
		# Geometry belongs only to active support/rise control and must retain
		# the exact source observation identity selected before motor application.
		if name in ["handoff", "partial"]:
			var geometry_key := "initial_geometry_plan" if name == "handoff" else "next_geometry_plan"
			bad = row.event.duplicate(true)
			bad.r10v_native_receipt[geometry_key] = null
			bad.payload_sha256 = Route.Prior._payload_sha256_v1(sdk, bad)
			checks[name + "_missing_geometry"] = not Route.event_valid_v1(sdk, bad)
			bad = row.event.duplicate(true)
			bad.r10v_native_receipt[geometry_key].source_observation_sha256 = "sha256:" + "0".repeat(64)
			bad.payload_sha256 = Route.Prior._payload_sha256_v1(sdk, bad)
			checks[name + "_crossed_geometry_source"] = not Route.event_valid_v1(sdk, bad)
		elif name in ["entry", "prone", "complete"]:
			var geometry_key := "next_geometry_plan" if name == "complete" else "initial_geometry_plan"
			bad = row.event.duplicate(true)
			bad.r10v_native_receipt[geometry_key] = {"unexpected_geometry": true}
			bad.payload_sha256 = Route.Prior._payload_sha256_v1(sdk, bad)
			checks[name + "_inactive_geometry"] = not Route.event_valid_v1(sdk, bad)
	var result := {"ok": not checks.values().has(false), "checks": checks,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	file.store_string(JSON.stringify(result) + "\n")
	file.close()
	sdk = null
	print("R10Z_ORCHESTRATOR_REFUSALS ", JSON.stringify(result))
	quit(0 if result.ok else 1)
