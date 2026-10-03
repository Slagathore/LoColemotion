extends SceneTree

const Capture := preload("res://sdk/adapters/godot/gdscript/r10ac_contact_frame_capture_v1.gd")
const NativeFixture := preload("res://tests/test_r10ac_contact_frames_zero_world.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const PROFILE := "res://sdk/development/recovery_candidates/r10ab-partial-downward-rise-core-v1.json"
const OLD := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const MODEL := "r10ac-synthetic-no-world"
const POPULATION := "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"


func _initialize() -> void:
	call_deferred("_run")


static func _source_vec(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


static func fixture_v1(sdk: Object, translation: float = -0.0001, angle: float = 0.0, detection_angle: float = 0.0) -> Dictionary:
	var native := NativeFixture._snapshot()
	var point: Dictionary = native.points[0]
	var detection_pose := Transform3D.IDENTITY
	if detection_angle != 0.0:
		detection_pose = Transform3D(Basis.from_euler(Vector3(detection_angle*0.7,detection_angle,-detection_angle*0.9)),Vector3(0.11,0.02,-0.13))
	var world := detection_pose * Vector3(0.02, -0.1, 0.0)
	point.body1_instance_id = 103
	point.body2_instance_id = 999
	point.body1_transform_at_detection = detection_pose
	point.body2_transform_at_detection = Transform3D.IDENTITY
	for key in ["point1_world_m", "point2_world_m", "point1_body_local_m", "point2_body_local_m"]:
		point[key] = world
	point.point1_body_local_m = detection_pose.affine_inverse() * world
	point.impulse1_world_ns = Vector3(0, 0.02, 0)
	point.impulse2_world_ns = Vector3(0, -0.02, 0)
	var callbacks := []
	var states := []
	var sites := {}
	var callback_local := Vector3.ZERO
	for index in range(9):
		var body_id: String = Capture.World.ORDERED_BODY_IDS[index]
		var pose := Transform3D.IDENTITY
		if index == 2:
			if angle != 0.0:
				pose.basis = Basis.from_euler(Vector3(angle*0.7,angle,-angle*0.9))
			pose.origin.y = translation
			callback_local = pose.affine_inverse() * world
		callbacks.append({"body_id": body_id, "instance_id": 101+index,
			"callback_sequence": 7, "pose": Capture._pack_pose(pose)})
		states.append({"body_id": body_id, "callback_sequence": 7,
			"position_world_m": _source_vec(pose.origin),
			"orientation_xyzw": Capture.World.project_quaternion_to_unit_scalar_v1(pose.basis.get_rotation_quaternion()).orientation_xyzw,
			"linear_velocity_world_m_s": _source_vec(Vector3.ZERO),
			"angular_velocity_world_rad_s": _source_vec(Vector3.ZERO), "mass_kg": 1.0})
		if body_id.ends_with("_distal"):
			sites[body_id] = {"contact_site_id": body_id.trim_suffix("_distal")+"_foot", "local_center_m": _source_vec(Vector3(0,-0.1,0))}
	var direct := {"schema_version": "sporespore_qsdk_r24d57_godot_direct_state_source_v1", "semantic_step": 7,
		"ordered_body_states": states, "gravity_world_m_s2": _source_vec(Vector3(0,-9.81,0)), "source_measurement": true}
	var contact := {"schema_version": Capture.World.SOLVED_CONTACT_SOURCE_SCHEMA,
		"semantic_step": 7, "native_space_step_sequence": 7, "source_measurement": true,
		"solved_contact_telemetry_contract": {"ok": true, "exact_contact_point_count": 1},
		"ordered_contact_samples": [{"body_id": "front_left_distal", "engine_contact_id": "front_left_distal:0|floor:0",
			"position_world_m": _source_vec(world), "position_body_local_m": _source_vec(callback_local),
			"normal_impulse_ns": float(point.impulse1_world_ns.y),
			"classified_as_foot": callback_local.y <= Vector3(0,-0.1,0).y+Capture.TOLERANCE_M}]}
	return {"schema_version": Capture.SCHEMA, "semantic_step": 7, "model_instance_id": MODEL,
		"body_population_instance_sha256": POPULATION, "floor_instance_id": 999, "callback_bodies": callbacks,
		"contact_sites_by_body": sites, "direct_state_source": direct, "contact_source_receipt": contact,
		"source_component_binding": {"semantic_step": 7, "direct_state_source_sha256": Capture._sha(sdk,direct),
			"contact_source_sha256": Capture._sha(sdk,contact)}, "native_snapshot": Capture.pack_native_v1(native)}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or FileAccess.file_exists(args[0]):
		quit(1); return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	if GDExtensionManager.is_extension_loaded(OLD):
		GDExtensionManager.unload_extension(OLD)
	if GDExtensionManager.load_extension(profile.extension) != GDExtensionManager.LOAD_STATUS_OK:
		quit(1); return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var result := _evaluate(sdk)
	var file := FileAccess.open(args[0],FileAccess.WRITE)
	file.store_string(Transport.line(result)); file.close()
	print("R10AC_CONTACT_FRAME_CAPTURE ",Transport.stringify(result.get("summary", result)))
	sdk = null
	quit(0 if result.get("ok",false) else 1)


static func _evaluate(sdk: Object) -> Dictionary:
	var base := fixture_v1(sdk)
	var replay := Capture.replay_v1(sdk,base,7,MODEL,POPULATION)
	if replay.get("ok") != true:
		return {"ok":false,"reason":"positive", "detail":replay}
	if replay.matched_source_contacts != 1 or replay.comparisons[0].original_classified_as_foot != false or replay.comparisons[0].diagnostic_detection_frame_foot != true or replay.comparisons[0].membership_changed != true:
		return {"ok":false,"reason":"expected_membership_difference"}
	var stationary := fixture_v1(sdk,0.0)
	var stationary_replay := Capture.replay_v1(sdk,stationary,7,MODEL,POPULATION)
	if stationary_replay.get("ok") != true or stationary_replay.comparisons[0].membership_changed != false:
		return {"ok":false,"reason":"stationary_control"}
	var rotated := fixture_v1(sdk,-0.0001,0.11,0.07)
	var rotated_replay := Capture.replay_v1(sdk,rotated,7,MODEL,POPULATION)
	if rotated_replay.get("ok") != true:
		return {"ok":false,"reason":"rotated_control","detail":rotated_replay}
	var empty := base.duplicate(true)
	empty.native_snapshot.points=[]; empty.native_snapshot.reported_point_count=0
	empty.contact_source_receipt.ordered_contact_samples=[]
	empty.contact_source_receipt.solved_contact_telemetry_contract.exact_contact_point_count=0
	empty.source_component_binding.contact_source_sha256=Capture._sha(sdk,empty.contact_source_receipt)
	var empty_replay := Capture.replay_v1(sdk,empty,7,MODEL,POPULATION)
	if empty_replay.get("ok") != true or empty_replay.matched_source_contacts != 0:
		return {"ok":false,"reason":"complete_empty_control","detail":empty_replay}
	var decoded: Dictionary = sdk.decode_exact_json_v1(Transport.stringify(base))
	var transported := Capture.replay_v1(sdk,decoded,7,MODEL,POPULATION)
	if transported != replay or Capture._sha(sdk,decoded) != Capture._sha(sdk,base):
		return {"ok":false,"reason":"transport_roundtrip", "detail":transported}
	var mutations: Array = []
	for field in ["direct_state_source", "contact_source_receipt", "source_component_binding", "native_snapshot", "callback_bodies", "contact_sites_by_body"]:
		var bad := base.duplicate(true); bad.erase(field); mutations.append(bad)
	for pair in [["semantic_step",8],["model_instance_id","other"],["body_population_instance_sha256","sha256:"+"b".repeat(64)],["floor_instance_id",103]]:
		var bad := base.duplicate(true); bad[pair[0]]=pair[1]; mutations.append(bad)
	var bad := base.duplicate(true); bad.callback_bodies.pop_back(); mutations.append(bad)
	bad=base.duplicate(true); bad.callback_bodies[2].instance_id=102; mutations.append(bad)
	bad=base.duplicate(true); bad.callback_bodies[2].callback_sequence=6; mutations.append(bad)
	bad=base.duplicate(true); bad.callback_bodies[2].pose.origin[1]=0.0; mutations.append(bad)
	bad=base.duplicate(true); bad.direct_state_source.ordered_body_states[2].position_world_m.y=0.0; mutations.append(bad)
	bad=base.duplicate(true); bad.contact_source_receipt.ordered_contact_samples[0].classified_as_foot=true; mutations.append(bad)
	bad=base.duplicate(true); bad.source_component_binding.direct_state_source_sha256="sha256:"+"0".repeat(64); mutations.append(bad)
	for pair in [["read_space_step_sequence",8],["missing_frame_count",1],["duplicate_callback_count",1],["reported_point_count",2]]:
		bad=base.duplicate(true); bad.native_snapshot[pair[0]]=pair[1]; mutations.append(bad)
	bad=base.duplicate(true); bad.native_snapshot.points[0].body1_instance_id=888; mutations.append(bad)
	bad=base.duplicate(true); bad.native_snapshot.points[0].shape1_index=1; mutations.append(bad)
	bad=base.duplicate(true); bad.native_snapshot.points[0].point1_body_local_m[1]=-0.2; mutations.append(bad)
	bad=base.duplicate(true); bad.contact_sites_by_body.erase("rear_right_distal"); mutations.append(bad)
	bad=base.duplicate(true); bad.contact_sites_by_body.front_left_distal.local_center_m.y=0.1; mutations.append(bad)
	# Rehashing a crossed source does not bypass point identity or classification.
	bad=base.duplicate(true); bad.contact_source_receipt.ordered_contact_samples[0].classified_as_foot=true
	bad.source_component_binding.contact_source_sha256=Capture._sha(sdk,bad.contact_source_receipt); mutations.append(bad)
	bad=empty.duplicate(true); bad.floor_instance_id=0; mutations.append(bad)
	bad=base.duplicate(true); bad.contact_source_receipt.ordered_contact_samples.append(bad.contact_source_receipt.ordered_contact_samples[0].duplicate(true))
	bad.source_component_binding.contact_source_sha256=Capture._sha(sdk,bad.contact_source_receipt); mutations.append(bad)
	var refused := 0
	for mutation in mutations:
		if Capture.replay_v1(sdk,mutation,7,MODEL,POPULATION).get("ok") == true:
			return {"ok":false,"reason":"mutation_accepted","index":refused}
		refused+=1
	if Capture.enable_v1({}).get("ok") != false:
		return {"ok":false,"reason":"empty_model_enable_accepted"}
	return {"ok":true, "summary":{"ok":true,"positive_cases":5,"negative_cases":refused,
		"missing_model_refused":true,"callback_bodies_checked":9,"serialized_roundtrip_exact":true,
		"world_build_count":0,"solver_step_count":0,"physical_acceptance_authority":false,"release_authority":false},
		"fixtures":[{"packet":base,"packet_sha256":Capture._sha(sdk,base),"replay":replay},
			{"packet":stationary,"packet_sha256":Capture._sha(sdk,stationary),"replay":stationary_replay},
			{"packet":rotated,"packet_sha256":Capture._sha(sdk,rotated),"replay":rotated_replay},
			{"packet":empty,"packet_sha256":Capture._sha(sdk,empty),"replay":empty_replay}],
		"negative_packets":mutations}
