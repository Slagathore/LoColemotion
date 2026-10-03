extends SceneTree

const Frame := preload("res://sdk/adapters/godot/gdscript/recovery_detection_frame_contacts_v1.gd")
const Fixture := preload("res://tests/test_r10ac_contact_frame_capture.gd")
const Capture := Fixture.Capture
const World := Capture.World
const Transport := Fixture.Transport


func _initialize() -> void:
	call_deferred("_run")


static func inputs_v1(sdk: Object, translation: float, center: float, angle: float = 0.0, detection_angle: float = 0.0) -> Dictionary:
	var packet := Fixture.fixture_v1(sdk,translation,angle,detection_angle)
	for body in packet.contact_sites_by_body:
		packet.contact_sites_by_body[body].local_center_m.y = center
	var row: Dictionary = packet.contact_source_receipt.ordered_contact_samples[0]
	row.classified_as_foot = Vector3(row.position_body_local_m.x,row.position_body_local_m.y,row.position_body_local_m.z).y <= Vector3(0,center,0).y+Frame.TOLERANCE_M
	packet.source_component_binding.contact_source_sha256 = Capture._sha(sdk,packet.contact_source_receipt)
	var native := Capture.unpack_native_v1(packet.native_snapshot)
	var instances := {}
	var samples := {}
	for body in packet.callback_bodies:
		instances[body.body_id] = body.instance_id
		samples[body.body_id] = []
	var point: Dictionary = native.points[0]
	samples.front_left_distal.append({"counterparty_id":"floor", "engine_contact_id":"front_left_distal:0|floor:0",
		"local_position_world_m":point.point1_world_m,"local_normal_world_unit":point.normal1_world_unit,
		"raw_impulse_world_nms":point.impulse1_world_ns})
	return {"packet":packet,"native":native,"instances":instances,"samples":samples,"floor":999}


static func prepare_v1(data: Dictionary) -> Dictionary:
	return Frame.prepare_v1(data.native,7,data.instances,data.floor,data.samples)


static func evaluate_v1(sdk: Object) -> Dictionary:
	var positive := []
	var cases := []
	for pair in [[-0.0001,-0.1],[0.0001,-0.10005],[0.0,-0.08365750000000001]]:
		cases.append(inputs_v1(sdk,pair[0],pair[1]))
	cases.append(inputs_v1(sdk,-0.0001,-0.1,0.11,0.07))
	var reverse := inputs_v1(sdk,-0.0001,-0.1)
	var swapped: Dictionary = reverse.native.points[0]
	for suffix in ["_jolt_id","_instance_id","_transform_at_detection"]:
		var first: Variant = swapped["body1"+suffix]
		swapped["body1"+suffix]=swapped["body2"+suffix];swapped["body2"+suffix]=first
	for prefix in ["subshape","shape"]:
		var suffix := "_id" if prefix == "subshape" else "_index"
		var first: Variant = swapped[prefix+"1"+suffix]
		swapped[prefix+"1"+suffix]=swapped[prefix+"2"+suffix];swapped[prefix+"2"+suffix]=first
	for pair in [["point","_world_m"],["point","_body_local_m"],["normal","_world_unit"],["impulse","_world_ns"]]:
		var first: Variant = swapped[pair[0]+"1"+pair[1]]
		swapped[pair[0]+"1"+pair[1]]=swapped[pair[0]+"2"+pair[1]];swapped[pair[0]+"2"+pair[1]]=first
	reverse.packet.native_snapshot=Capture.pack_native_v1(reverse.native)
	cases.append(reverse)
	var torso := inputs_v1(sdk,0.0,-0.1)
	torso.native.points[0].body1_instance_id=101
	torso.packet.native_snapshot=Capture.pack_native_v1(torso.native)
	torso.samples.torso=torso.samples.front_left_distal;torso.samples.front_left_distal=[]
	torso.samples.torso[0].engine_contact_id="torso:0|floor:0"
	torso.packet.contact_source_receipt.ordered_contact_samples[0].body_id="torso"
	torso.packet.contact_source_receipt.ordered_contact_samples[0].engine_contact_id="torso:0|floor:0"
	torso.packet.contact_source_receipt.ordered_contact_samples[0].classified_as_foot=false
	torso.packet.source_component_binding.contact_source_sha256=Capture._sha(sdk,torso.packet.contact_source_receipt)
	cases.append(torso)
	for data in cases:
		var legacy := Capture.replay_v1(sdk,data.packet,7,Fixture.MODEL,Fixture.POPULATION)
		if legacy.get("ok") != true: return {"ok":false,"stage":"legacy","detail":legacy}
		var prepared := prepare_v1(data)
		if prepared.get("ok") != true: return {"ok":false,"stage":"prepare","detail":prepared}
		var source: Dictionary = data.packet.contact_source_receipt.duplicate(true)
		var row: Dictionary = source.ordered_contact_samples[0]
		var callback := Vector3(row.position_body_local_m.x,row.position_body_local_m.y,row.position_body_local_m.z)
		var result := Frame.classify_v1(row.body_id,callback,data.packet.contact_sites_by_body.get(row.body_id),prepared.matches_by_body[row.body_id][0])
		if result.get("ok") != true: return {"ok":false,"stage":"classify","detail":result}
		for key in result:
			if key != "ok": row[key] = result[key]
		source.schema_version = Frame.SOURCE_SCHEMA
		source.contact_detection_frame = prepared.frame_binding
		source.solved_contact_telemetry_contract.schema_version = World.SOLVED_CONTACT_TELEMETRY_CONTRACT_SCHEMA
		var retained := World.retain_contact_source_receipt_v1(sdk,{"source_receipt":source})
		if retained.get("ok") != true: return {"ok":false,"stage":"retention","detail":retained}
		positive.append({"legacy_packet":data.packet,"source_receipt":source,"retained":retained,
			"callback_classified_as_foot":legacy.comparisons[0].original_classified_as_foot,
			"detection_classified_as_foot":result.classified_as_foot})
	if positive[0].callback_classified_as_foot != false or positive[0].detection_classified_as_foot != true:
		return {"ok":false,"stage":"positive_direction"}
	if positive[1].callback_classified_as_foot != true or positive[1].detection_classified_as_foot != false:
		return {"ok":false,"stage":"negative_direction"}
	var base := inputs_v1(sdk,-0.0001,-0.1)
	var mutations := []
	var bad := base.duplicate(true); bad.native.read_space_step_sequence=8; mutations.append(bad)
	bad=base.duplicate(true); bad.native.complete=false; mutations.append(bad)
	bad=base.duplicate(true); bad.native.points[0].point1_body_local_m.y+=0.001; mutations.append(bad)
	bad=base.duplicate(true); bad.samples.front_left_distal=[]; mutations.append(bad)
	bad=base.duplicate(true); bad.samples.front_left_distal.append(bad.samples.front_left_distal[0].duplicate(true)); mutations.append(bad)
	bad=base.duplicate(true); bad.samples.front_left_distal[0].engine_contact_id="front_left_distal:1|floor:0"; mutations.append(bad)
	bad=base.duplicate(true); bad.samples.front_left_distal[0].local_position_world_m.x+=0.001; mutations.append(bad)
	bad=base.duplicate(true); bad.samples.front_left_distal[0].raw_impulse_world_nms.y*=2; mutations.append(bad)
	bad=base.duplicate(true); bad.instances.front_left_distal=999; mutations.append(bad)
	bad=base.duplicate(true); bad.native.points[0].body1_instance_id=888; mutations.append(bad)
	bad=base.duplicate(true); bad.native.points.append(bad.native.points[0].duplicate(true)); bad.native.reported_point_count=2; mutations.append(bad)
	bad=base.duplicate(true); bad.samples.front_right_distal.append(bad.samples.front_left_distal[0].duplicate(true)); mutations.append(bad)
	var refused := 0
	for mutation in mutations:
		if prepare_v1(mutation).get("ok") == true: return {"ok":false,"stage":"negative_prepare","index":refused}
		refused+=1
	if Frame.selection_v1({}).get("selected") != false or Frame.selection_v1({Frame.MODEL_KEY:Frame.PROFILE}).get("selected") != true:
		return {"ok":false,"stage":"selection"}
	for profile in ["unknown",null,false,1]:
		if World._measure_contacts_v1({Frame.MODEL_KEY:profile},{},7,7).get("ok") != false:
			return {"ok":false,"stage":"unknown_profile"}
		refused+=1
	for field in ["profile_id","native_space_step_sequence","classification_scope","schema_version"]:
		var crossed: Dictionary = positive[0].source_receipt.duplicate(true)
		crossed.contact_detection_frame.erase(field)
		if World.retain_contact_source_receipt_v1(sdk,{"source_receipt":crossed}).get("ok") == true:
			return {"ok":false,"stage":"negative_retention","field":field}
		refused+=1
	var empty := base.duplicate(true)
	empty.native.points=[]; empty.native.reported_point_count=0; empty.samples.front_left_distal=[]
	if prepare_v1(empty).get("loaded_floor_contact_count") != 0: return {"ok":false,"stage":"empty"}
	return {"ok":true,"positive_cases":positive,"empty_population_passed":true,"negative_refusals":refused,
		"world_build_count":0,"solver_step_count":0,"physical_acceptance_authority":false,"release_authority":false}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or FileAccess.file_exists(args[0]): quit(1); return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixture.PROFILE))
	if GDExtensionManager.is_extension_loaded(Fixture.OLD): GDExtensionManager.unload_extension(Fixture.OLD)
	if GDExtensionManager.load_extension(profile.extension) != GDExtensionManager.LOAD_STATUS_OK: quit(1); return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var result := evaluate_v1(sdk)
	var file := FileAccess.open(args[0],FileAccess.WRITE)
	file.store_string(Transport.line(result)); file.close()
	print("R10AF_CONTACT_COMPONENT ",Transport.stringify(result if result.get("ok") != true else {"ok":true,"negative_refusals":result.negative_refusals}))
	sdk=null; quit(0 if result.get("ok") == true else 1)
