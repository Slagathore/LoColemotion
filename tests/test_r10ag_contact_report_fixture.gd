extends SceneTree

const Fixture := preload("res://tests/test_r10af_detection_frame_contacts.gd")
const Capture := preload("res://sdk/adapters/godot/gdscript/r10af_contact_frame_capture_v1.gd")
const Report := preload("res://sdk/adapters/godot/gdscript/r10af_contact_frame_report_v1.gd")
const Seed := preload("res://sdk/adapters/godot/gdscript/r10ag_development_seed_v1.gd")
const Json := Fixture.Transport


func _initialize() -> void: call_deferred("_run")


static func packet_v1(sdk: Object, case: Dictionary, step: int) -> Dictionary:
	var packet: Dictionary = case.legacy_packet.duplicate(true)
	packet.schema_version=Capture.SCHEMA
	packet.semantic_step=step
	packet.direct_state_source.semantic_step=step
	packet.source_component_binding.semantic_step=step
	for row in packet.direct_state_source.ordered_body_states: row.callback_sequence=step
	for row in packet.callback_bodies: row.callback_sequence=step
	packet.contact_source_receipt=case.source_receipt.duplicate(true)
	packet.contact_source_receipt.semantic_step=step
	packet.contact_source_receipt.native_space_step_sequence=step+6
	packet.contact_source_receipt.contact_detection_frame.native_space_step_sequence=step+6
	for snapshot in [packet.native_snapshot,packet.contact_source_receipt.contact_detection_frame.native_snapshot]:
		snapshot.capture_space_step_sequence=step+6;snapshot.read_space_step_sequence=step+6
	packet.source_component_binding.direct_state_source_sha256=Capture._sha(sdk,packet.direct_state_source)
	packet.source_component_binding.contact_source_sha256=Capture._sha(sdk,packet.contact_source_receipt)
	return packet


static func evaluate_v1(sdk: Object, declaration: Dictionary) -> Dictionary:
	var components := Fixture.evaluate_v1(sdk)
	if components.get("ok") != true: return components
	var packets := []
	for case in components.positive_cases:
		var packet := packet_v1(sdk,case,7)
		var replay := Capture.replay_v1(sdk,packet,7,Fixture.Fixture.MODEL,Fixture.Fixture.POPULATION)
		if replay.get("ok") != true: return {"ok":false,"stage":"packet","detail":replay}
		packets.append({"packet":packet,"replay":replay})
	var report := {"synthetic_fixture":true,"arm_id":Seed.ROLE,"source_commit":declaration.source_snapshot.head,
		"seed":Seed.SEED,"child_attempt_id":declaration.children[0].child_attempt_id,
		"parent_attempt_id":declaration.attempt_id,"solver_step_count":2,
		"retained_arm":{"model_instance_id":Fixture.Fixture.MODEL,"body_population_instance_sha256":Fixture.Fixture.POPULATION,"trace_rows":[]},
		"r10af_contact_frames":{"schema_version":"sporespore_r10af_contact_frame_retention_v1","record_count":2,"records":[],"controller_observation_changed":true,"physical_acceptance_authority":false,"release_authority":false},
		"r10af_contact_frame_links":{"schema_version":Report.LINKS_SCHEMA,"record_count":2,"records":[],"controller_observation_changed":true,"physical_acceptance_authority":false,"release_authority":false}}
	if not Seed.attach_report_context_v1(report,declaration,Seed.SEED): return {"ok":false,"stage":"identity"}
	for index in range(2):
		var step := index+1
		var packet := packet_v1(sdk,components.positive_cases[index],step)
		var replay := Capture.replay_v1(sdk,packet,step,Fixture.Fixture.MODEL,Fixture.Fixture.POPULATION)
		if replay.get("ok") != true: return {"ok":false,"stage":"report_packet","detail":replay}
		var source := {"semantic_step":step,"direct_state_callback_sequence":step,"host_step_before":step-1,"host_step_after":step,
			"source_measurement":true,"native_space_step_sequence":step+6,
			"direct_state_source_sha256":packet.source_component_binding.direct_state_source_sha256,
			"contact_source_sha256":packet.source_component_binding.contact_source_sha256}
		var observation := {"engine_step_identity":{"schema_version":"sporespore_recovery_engine_step_identity_v1",
			"semantic_step":step,"host_step_before":step-1,"host_step_after":step,"native_solver_substep_count":1,
			"post_step_observation":true,"source_trace_sha256":Capture._sha(sdk,source)}}
		report.retained_arm.trace_rows.append({"arm_id":Seed.ROLE,"global_semantic_step":step,
			"body_population_instance_sha256":Fixture.Fixture.POPULATION,"observation_sha256":Capture._sha(sdk,observation)})
		report.r10af_contact_frames.records.append({"ok":true,"packet":packet,"packet_sha256":Capture._sha(sdk,packet),
			"replay":replay,"controller_observation_changed":true,"world_build_count":0,"solver_step_count":0,
			"physical_acceptance_authority":false,"release_authority":false})
		report.r10af_contact_frame_links.records.append({"ok":true,"semantic_step":step,"global_observation":observation,"source_trace":source})
	var result := Report.replay_report_v1(sdk,report,declaration,Seed)
	if result.get("ok") != true: return {"ok":false,"stage":"report","detail":result}
	var mutations := []
	var bad: Dictionary = report.duplicate(true);bad.r10af_contact_frames.records.pop_back();mutations.append(bad)
	bad=report.duplicate(true);bad.r10af_contact_frame_links.records[0].source_trace.contact_source_sha256="sha256:"+"0".repeat(64);mutations.append(bad)
	bad=report.duplicate(true);bad.r10af_contact_frames.controller_observation_changed=false;mutations.append(bad)
	bad=report.duplicate(true);bad.r10af_contact_frames.records[0].controller_observation_changed=false;mutations.append(bad)
	bad=report.duplicate(true);bad.r10af_contact_frames.records[0].packet.contact_source_receipt.ordered_contact_samples[0].classified_as_foot=false;mutations.append(bad)
	bad=report.duplicate(true);bad.seed=63248;mutations.append(bad)
	bad=report.duplicate(true);bad.r10ag_development.contact_source_schema="old";mutations.append(bad)
	for index in range(mutations.size()):
		if Report.replay_report_v1(sdk,mutations[index],declaration,Seed).get("ok") == true:
			return {"ok":false,"stage":"negative","index":index}
	return {"ok":true,"packets":packets,"report":report,"replay":result,"negative_reports":mutations,
		"world_build_count":0,"solver_step_count":0,"controller_report_audited":false,
		"physical_acceptance_authority":false,"release_authority":false}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=2 or FileAccess.file_exists(args[1]): quit(1);return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixture.Fixture.PROFILE))
	if GDExtensionManager.is_extension_loaded(Fixture.Fixture.OLD): GDExtensionManager.unload_extension(Fixture.Fixture.OLD)
	if GDExtensionManager.load_extension(profile.extension)!=GDExtensionManager.LOAD_STATUS_OK: quit(1);return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var declaration: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	var result := evaluate_v1(sdk,declaration)
	var file := FileAccess.open(args[1],FileAccess.WRITE);file.store_string(Json.line(result));file.close()
	print("R10AG_REPORT_COMPONENT ",Json.stringify(result if result.get("ok")!=true else {"ok":true}))
	sdk=null;quit(0 if result.get("ok")==true else 1)
