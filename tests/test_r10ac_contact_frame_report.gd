extends SceneTree
const Reader := preload("res://sdk/adapters/godot/gdscript/r10ac_contact_frame_report_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var checks := {}
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Reader.Seed.PROFILE))
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old):
		checks.unload = GDExtensionManager.unload_extension(old) == GDExtensionManager.LOAD_STATUS_OK
	checks.load = GDExtensionManager.load_extension(profile.extension) == GDExtensionManager.LOAD_STATUS_OK
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var fixture: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	var replays := {}
	var refusals := {}
	for row in fixture.positives:
		var before := Reader._sha(sdk, row.report)
		var result := Reader.replay_report_v1(sdk, row.report, fixture.declaration)
		checks[row.name] = Reader.Json.same_json_v1(result, row.expected)
		checks[row.name + "_unchanged"] = before == Reader._sha(sdk, row.report)
		replays[row.name] = result
	for row in fixture.negatives:
		var result := Reader.replay_report_v1(sdk, row.report, fixture.declaration)
		checks[row.name] = result.get("ok") == false
		refusals[row.name] = result
	# Exercise the actual worker link constructor with the same original source
	# layout the base worker exposes after compact trace retention.
	var report: Dictionary = fixture.positives[0].report
	var link: Dictionary = report.r10ac_contact_frame_links.records[0]
	var arm := {"trace_rows": [report.retained_arm.trace_rows[0]], "last_collection": {
		"global_result": {"bound": {"observation_v3": link.global_observation},
		"measurement": {"source_component_receipts": {"source_trace": link.source_trace}}}}}
	var built := Reader.link_v1(sdk, arm, 1)
	checks.actual_link_constructor = Reader.Json.same_json_v1(built, link)
	arm.last_collection.global_result.bound.observation_v3.engine_step_identity.semantic_step = 99
	checks.detached_link = built.global_observation.engine_step_identity.semantic_step == 1
	checks.crossed_link_refused = Reader.link_v1(sdk, arm, 1).get("ok") == false
	checks.missing_link_source_refused = Reader.link_v1(sdk, {}, 1).get("ok") == false
	var result := {"ok": not checks.values().has(false), "checks": checks, "replays": replays,
		"refusals": refusals, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(args[1],FileAccess.WRITE)
	file.store_string(Transport.stringify(result)+"\n");file.close()
	sdk = null
	print("R10AC_CONTACT_REPORT ", JSON.stringify({"ok": result.ok,"checks": checks}))
	quit(0 if result.ok else 1)
