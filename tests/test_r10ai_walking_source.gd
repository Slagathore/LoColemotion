extends "res://tests/test_r10ai_contact_report_fixture.gd"
## Pure contact transport through the production preparation and adapter hooks.
const Contact := preload("res://sdk/adapters/godot/gdscript/development_recovery_native_walking_contacts_v1.gd")
const Body := preload("res://scripts/lab/mechanics/semantic_contact_rigid_body.gd")
const Adapter := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")

static func source_v1(sdk: Object, receipt: Dictionary, aggregation: String) -> Dictionary:
	var observation := {"semantic_step":7,"state":{"semantic_step":7,"ordered_contact_observations":[]},
		"engine_step_identity":{"post_step_observation":true,"source_kind":"native_post_step","semantic_step":7},
		"ordered_foot_bearing_observations":[]}
	var trace := {"global_semantic_step":7,"body_population_instance_sha256":Fixture.Fixture.POPULATION,"contact_by_limb":{}}
	for limb in Contact._contract.ordered_limb_ids:
		var ids := []
		var impulse := 0.0
		for sample in receipt.ordered_contact_samples:
			if sample.body_id == limb+"_distal" and sample.classified_as_foot:
				ids.append(sample.engine_contact_id);impulse+=sample.normal_impulse_ns
		ids=Contact.World.native_contact_identity_projection_v2(ids).engine_contact_ids
		var present := not ids.is_empty()
		observation.state.ordered_contact_observations.append({"contact_site_id":limb+"_foot",
			"presence":present,"bears_support":present and impulse>0.0,"normal_load_n":null,
			"provenance":{"adapter_id":Contact._contract.source_adapter_id,"aggregation_rule_id":aggregation,
				"engine_contact_ids":ids,"quality":"qualified_bearing","impulse_source_profile_id":Contact._contract.source_impulse_profile_id,
				"impulse_source_kind":Contact._contract.source_impulse_kind}})
		observation.ordered_foot_bearing_observations.append({"contact_site_id":limb+"_foot",
			"source_measurement":true,"bearing_normal_impulse_ns":impulse,"ordinary_unilateral_contact":present})
		trace.contact_by_limb[limb]=present and impulse>0.0
	trace.observation_sha256=Capture._sha(sdk,observation)
	return {"model_instance_id":Fixture.Fixture.MODEL,"body_population_instance_sha256":Fixture.Fixture.POPULATION,
		"observation":observation,"precommand_trace":trace,"contact_source_receipt":receipt.duplicate(true),
		"contact_source_sha256":Capture._sha(sdk,receipt)}

static func valid_v1(sdk: Object, source: Dictionary) -> bool:
	return Contact.source_valid_v1(sdk,source,8,Fixture.Fixture.MODEL,Fixture.Fixture.POPULATION)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or FileAccess.file_exists(args[0]): quit(1);return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixture.Fixture.PROFILE))
	if GDExtensionManager.is_extension_loaded(Fixture.Fixture.OLD): GDExtensionManager.unload_extension(Fixture.Fixture.OLD)
	if GDExtensionManager.load_extension(profile.extension)!=GDExtensionManager.LOAD_STATUS_OK: quit(1);return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var fixed := Fixture.evaluate_v1(sdk)
	var checks := {}
	var cases := []
	for index in fixed.positive_cases.size():
		var case: Dictionary = fixed.positive_cases[index]
		var source := source_v1(sdk,case.source_receipt,Contact.DetectionSelection.AGGREGATION)
		checks["source_"+str(index)]=valid_v1(sdk,source)
		var legacy := source_v1(sdk,case.legacy_packet.contact_source_receipt,Contact._contract.source_aggregation_rule_id)
		checks["legacy_"+str(index)]=valid_v1(sdk,legacy)
		var limbs := []
		for limb in Contact._contract.ordered_limb_ids:
			var body := Body.new();body.semantic_contact_callback_count=7
			var samples: Array[Dictionary] = []
			for point in case.source_receipt.ordered_contact_samples:
				if point.body_id != limb+"_distal": continue
				samples.append({"engine_contact_id":point.engine_contact_id,"local_position_world_m":Vector3(point.position_world_m.x,point.position_world_m.y,point.position_world_m.z),
					"local_normal_world_unit":Vector3.UP,"relative_velocity_world_m_s":Vector3.ZERO,"counterparty_id":"floor"})
			body.latest_semantic_contact_samples=samples
			limbs.append({"limb_id":limb,"foot":body})
		var binding := {"model_instance_id":Fixture.Fixture.MODEL,"limbs":limbs}
		var prepared := Contact.prepare_v1(sdk,source,binding,8,Fixture.Fixture.POPULATION)
		checks["prepared_"+str(index)]=prepared.get("ok")==true
		var floor := StaticBody3D.new();floor.set_meta("lab_body_id","floor")
		for limb_index in limbs.size():
			var observed := Adapter._walking_contact_observation(limbs[limb_index].limb_id+"_foot",limbs[limb_index],floor)
			checks["adapter_%d_%d" % [index,limb_index]]=Seed.Json.same_json_v1(observed,source.observation.state.ordered_contact_observations[limb_index])
		for limb in limbs: limb.foot.free()
		floor.free()
		cases.append({"source":source,"legacy":legacy,"prepared":prepared})
	var base: Dictionary=cases[0].source
	var mutations := []
	for mode in ["profile","scope","schema","sequence","native_sequence","missing_frame","legacy_label"]:
		var bad: Dictionary=base.duplicate(true)
		var frame: Dictionary=bad.contact_source_receipt.contact_detection_frame
		if mode=="profile": frame.profile_id="unknown"
		elif mode=="scope": frame.classification_scope="whole_body"
		elif mode=="schema": bad.contact_source_receipt.schema_version="legacy"
		elif mode=="sequence": frame.native_space_step_sequence+=1
		elif mode=="native_sequence": frame.native_snapshot.read_space_step_sequence+=1
		elif mode=="missing_frame": bad.contact_source_receipt.erase("contact_detection_frame")
		elif mode=="legacy_label": bad.observation.state.ordered_contact_observations[0].provenance.aggregation_rule_id=Contact._contract.source_aggregation_rule_id
		bad.contact_source_sha256=Capture._sha(sdk,bad.contact_source_receipt)
		bad.precommand_trace.observation_sha256=Capture._sha(sdk,bad.observation)
		checks["refuses_"+mode]=not valid_v1(sdk,bad);mutations.append(bad)
	var result := {"ok":not checks.values().has(false),"checks":checks,"cases":cases,"negative_controls":mutations.size(),
		"synthetic_sources_and_uninserted_bodies":true,"world_build_count":0,"solver_step_count":0,
		"physical_acceptance_authority":false,"release_authority":false}
	var file := FileAccess.open(args[0],FileAccess.WRITE);file.store_string(Json.line(result));file.close()
	print("R10AF_WALKING_SOURCE ",Json.stringify({"ok":result.ok,"checks":checks}))
	sdk=null;quit(0 if result.ok else 1)
