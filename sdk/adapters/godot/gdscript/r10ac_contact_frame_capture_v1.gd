extends RefCounted

## Read-only sidecar for a NEW diagnostic. Original controller observations,
## contact classifications and hashes remain authoritative and unchanged.
const World := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const Native := preload("res://sdk/adapters/godot/gdscript/recovery_contact_frames_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const SCHEMA := "sporespore_r10ac_contact_frame_capture_v1"
const TOLERANCE_M := 1.0e-6


static func enable_v1(model: Dictionary) -> Dictionary:
	var torso: Variant = model.get("body_nodes", {}).get("torso")
	if not torso is RigidBody3D or torso.get_world_3d() == null:
		return _failure("WORLD_MISSING")
	if not ClassDB.class_has_method(&"JoltPhysicsServer3D", &"space_set_contact_frames_enabled"):
		return _failure("NATIVE_METHOD_MISSING")
	if ClassDB.class_call_static(&"JoltPhysicsServer3D", &"space_set_contact_frames_enabled", torso.get_world_3d().space, true) != true:
		return _failure("ENABLE_REFUSED")
	model["development_retain_direct_state_source"] = true
	return {"ok": true, "world_build_count": 0, "solver_step_count": 0}


static func capture_v1(sdk: Object, arm: Dictionary, expected_step: int) -> Dictionary:
	var model: Dictionary = arm.get("model", {})
	var measurement: Dictionary = arm.get("last_collection", {}).get("global_result", {}).get("measurement", {})
	var components: Dictionary = measurement.get("source_component_receipts", {})
	var torso: Variant = model.get("body_nodes", {}).get("torso")
	var floor_body: Variant = model.get("floor")
	if not torso is RigidBody3D or not floor_body is StaticBody3D or torso.get_world_3d() == null:
		return _failure("BODY_OR_FLOOR_MISSING")
	var snapshot: Variant = ClassDB.class_call_static(&"JoltPhysicsServer3D", &"space_get_contact_frames", torso.get_world_3d().space)
	if not snapshot is Dictionary:
		return _failure("NATIVE_SNAPSHOT_MISSING")
	var callbacks := []
	for body_id in World.ORDERED_BODY_IDS:
		var body: Variant = model.get("body_nodes", {}).get(body_id)
		if not body is RigidBody3D or body.get_meta("lab_body_id", "") != body_id:
			return _failure("BODY_IDENTITY")
		var sample: Variant = body.get("latest_direct_state_snapshot")
		if not sample is Dictionary or not sample.get("transform") is Transform3D:
			return _failure("CALLBACK_MISSING")
		callbacks.append({"body_id": body_id, "instance_id": body.get_instance_id(),
			"callback_sequence": sample.get("callback_sequence"), "pose": _pack_pose(sample.transform)})
	var packet := {"schema_version": SCHEMA, "semantic_step": expected_step,
		"model_instance_id": arm.get("model_instance_id", ""),
		"body_population_instance_sha256": arm.get("body_population_instance_sha256", ""),
		"floor_instance_id": floor_body.get_instance_id(), "callback_bodies": callbacks,
		"contact_sites_by_body": model.get("blueprint", {}).get("contact_by_body_id", {}).duplicate(true),
		"direct_state_source": measurement.get("development_direct_state_source", {}).duplicate(true),
		"contact_source_receipt": components.get("contact_source_receipt", {}).duplicate(true),
		"source_component_binding": {"semantic_step": components.get("semantic_step"),
			"direct_state_source_sha256": components.get("direct_state_source_sha256"),
			"contact_source_sha256": components.get("contact_source_sha256")},
		"native_snapshot": pack_native_v1(snapshot)}
	var replay := replay_v1(sdk, packet, expected_step, packet.model_instance_id, packet.body_population_instance_sha256)
	return {"ok": replay.get("ok", false), "packet": packet,
		"packet_sha256": _sha(sdk, packet), "replay": replay,
		"controller_observation_changed": false, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}


static func pack_native_v1(snapshot: Dictionary) -> Dictionary:
	var packed := snapshot.duplicate(true)
	for point in packed.get("points", []):
		for side in ["1", "2"]:
			var pose_key: String = "body" + side + "_transform_at_detection"
			if point.get(pose_key) is Transform3D:
				point[pose_key] = _pack_pose(point[pose_key])
			for field in ["point"+side+"_world_m", "point"+side+"_body_local_m", "normal"+side+"_world_unit", "impulse"+side+"_world_ns"]:
				if point.get(field) is Vector3:
					point[field] = _pack_vec(point[field])
	return packed


static func unpack_native_v1(packed: Dictionary) -> Dictionary:
	var snapshot := packed.duplicate(true)
	if not snapshot.get("points") is Array:
		return {}
	for point in snapshot.points:
		if not point is Dictionary:
			return {}
		for side in ["1", "2"]:
			var pose_key: String = "body" + side + "_transform_at_detection"
			point[pose_key] = _unpack_pose(point.get(pose_key))
			for field in ["point"+side+"_world_m", "point"+side+"_body_local_m", "normal"+side+"_world_unit", "impulse"+side+"_world_ns"]:
				point[field] = _unpack_vec(point.get(field))
	return snapshot


static func replay_v1(sdk: Object, packet: Dictionary, step: int, model_id: String, population: String) -> Dictionary:
	if sdk == null or step < 1 or model_id.is_empty() or not population.begins_with("sha256:") or population.length() != 71:
		return _failure("EXPECTED_BINDING")
	if packet.get("schema_version") != SCHEMA or packet.get("semantic_step") != step or packet.get("model_instance_id") != model_id or packet.get("body_population_instance_sha256") != population:
		return _failure("PACKET_BINDING")
	for field in ["direct_state_source", "contact_source_receipt", "source_component_binding", "native_snapshot", "contact_sites_by_body"]:
		if not packet.get(field) is Dictionary:
			return _failure(field)
	var direct: Dictionary = packet.direct_state_source
	var contact: Dictionary = packet.contact_source_receipt
	var binding: Dictionary = packet.source_component_binding
	if contact.get("schema_version") != World.SOLVED_CONTACT_SOURCE_SCHEMA or contact.get("solved_contact_telemetry_contract", {}).get("ok") != true:
		return _failure("CONTACT_SCHEMA")
	if direct.get("schema_version") != "sporespore_qsdk_r24d57_godot_direct_state_source_v1" or direct.get("source_measurement") != true or direct.get("semantic_step") != step or contact.get("source_measurement") != true or contact.get("semantic_step") != step or binding.get("semantic_step") != step:
		return _failure("SOURCE_STEP")
	if _sha(sdk, direct) != binding.get("direct_state_source_sha256") or _sha(sdk, contact) != binding.get("contact_source_sha256"):
		return _failure("SOURCE_HASH")
	if not contact.get("native_space_step_sequence") is int or not contact.get("ordered_contact_samples") is Array:
		return _failure("CONTACT_SOURCE")
	var native := Native.validate_native_snapshot(unpack_native_v1(packet.native_snapshot), contact.native_space_step_sequence)
	if native.get("ok") != true:
		return _failure("NATIVE_REFUSED", native)
	if contact.get("solved_contact_telemetry_contract", {}).get("exact_contact_point_count") != native.point_count:
		return _failure("NATIVE_COUNT_BINDING")
	if not packet.get("callback_bodies") is Array or packet.callback_bodies.size() != 9 or not direct.get("ordered_body_states") is Array or direct.ordered_body_states.size() != 9 or not packet.get("floor_instance_id") is int or packet.floor_instance_id <= 0:
		return _failure("BODY_POPULATION")
	var by_instance := {}
	var poses := {}
	for index in range(9):
		var row: Variant = packet.callback_bodies[index]
		var original: Variant = direct.ordered_body_states[index]
		var body_id: String = World.ORDERED_BODY_IDS[index]
		if not row is Dictionary or not original is Dictionary:
			return _failure("BODY_ROW")
		if row.get("body_id") != body_id or original.get("body_id") != body_id or row.get("callback_sequence") != step or original.get("callback_sequence") != step or not row.get("instance_id") is int or row.instance_id <= 0 or row.instance_id == packet.floor_instance_id or by_instance.has(row.instance_id):
			return _failure("BODY_IDENTITY")
		var pose: Variant = _unpack_pose(row.get("pose"))
		if not pose is Transform3D or not pose.is_finite() or is_zero_approx(pose.basis.determinant()):
			return _failure("BODY_POSE")
		var position: Variant = _source_vec(original.get("position_world_m"))
		var projected := World.project_quaternion_to_unit_scalar_v1(pose.basis.get_rotation_quaternion())
		if position == null or pose.origin != position or projected.get("orientation_xyzw") != original.get("orientation_xyzw"):
			return _failure("DIRECT_POSE_BINDING")
		by_instance[row.instance_id] = body_id
		poses[body_id] = pose
	var sites: Dictionary = packet.contact_sites_by_body
	if sites.size() != 4:
		return _failure("FOOT_POPULATION")
	for body_id in sites:
		if not poses.has(body_id) or not String(body_id).ends_with("_distal") or not sites[body_id] is Dictionary or _source_vec(sites[body_id].get("local_center_m")) == null or sites[body_id].get("contact_site_id") != String(body_id).trim_suffix("_distal")+"_foot":
			return _failure("FOOT_SITE")
	var source_rows: Array = contact.ordered_contact_samples
	var used := {}
	var comparisons := []
	for point in native.points:
		for side in ["1", "2"]:
			var other: String = "2" if side == "1" else "1"
			var instance: int = point["body"+side+"_instance_id"]
			var counterparty: int = point["body"+other+"_instance_id"]
			if instance != packet.floor_instance_id and not by_instance.has(instance):
				return _failure("UNKNOWN_NATIVE_BODY")
			if counterparty != packet.floor_instance_id or not by_instance.has(instance):
				continue
			var body_id: String = by_instance[instance]
			var world_point: Vector3 = point["point"+side+"_world_m"]
			var detection_local: Vector3 = point["point"+side+"_body_local_m"]
			var normal: Vector3 = point["normal"+side+"_world_unit"]
			var impulse: Vector3 = point["impulse"+side+"_world_ns"]
			var normal_impulse := absf(impulse.dot(normal.normalized()))
			if normal_impulse == 0.0:
				continue
			var engine_id := "%s:%d|floor:%d" % [body_id, point["shape"+side+"_index"], point["shape"+other+"_index"]]
			var matches := []
			for i in range(source_rows.size()):
				var row: Variant = source_rows[i]
				if row is Dictionary and row.get("body_id") == body_id and row.get("engine_contact_id") == engine_id and _source_vec(row.get("position_world_m")) == world_point and row.get("normal_impulse_ns") == normal_impulse:
					matches.append(i)
			if matches.size() != 1 or used.has(matches[0]):
				return _failure("CONTACT_MATCH_NOT_UNIQUE")
			var matched: int = matches[0]
			used[matched] = true
			var callback_local: Vector3 = poses[body_id].affine_inverse() * world_point
			if _source_vec(source_rows[matched].get("position_body_local_m")) != callback_local:
				return _failure("ORIGINAL_LOCAL_POSITION")
			var legacy_foot := false
			var detection_foot := false
			var center: Variant = null
			if sites.has(body_id):
				center = _source_vec(sites[body_id].local_center_m)
				legacy_foot = callback_local.y <= center.y + TOLERANCE_M
				detection_foot = detection_local.y <= center.y + TOLERANCE_M
			if source_rows[matched].get("classified_as_foot") != legacy_foot:
				return _failure("ORIGINAL_CLASSIFICATION")
			comparisons.append({"body_id": body_id, "source_contact_index": matched,
				"engine_contact_id": engine_id, "body1_jolt_id": point.body1_jolt_id,
				"body2_jolt_id": point.body2_jolt_id, "subshape1_id": point.subshape1_id,
				"subshape2_id": point.subshape2_id, "manifold_point_index": point.manifold_point_index,
				"normal_impulse_ns": normal_impulse, "detection_local_y_m": detection_local.y,
				"callback_local_y_m": callback_local.y, "local_y_difference_m": callback_local.y-detection_local.y,
				"cap_center_y_m": null if center == null else center.y,
				"original_classified_as_foot": legacy_foot, "diagnostic_detection_frame_foot": detection_foot,
				"membership_changed": legacy_foot != detection_foot})
	if used.size() != source_rows.size():
		return _failure("UNMATCHED_SOURCE_CONTACT")
	comparisons.sort_custom(func(a, b): return a.source_contact_index < b.source_contact_index)
	return {"ok": true, "comparisons": comparisons, "matched_source_contacts": used.size(),
		"callback_body_count": 9, "classification_tolerance_m": TOLERANCE_M,
		"controller_observation_changed": false, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}


static func _pack_vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _pack_pose(value: Transform3D) -> Dictionary:
	return {"origin": _pack_vec(value.origin), "basis_columns": [_pack_vec(value.basis.x), _pack_vec(value.basis.y), _pack_vec(value.basis.z)]}


static func _unpack_vec(value: Variant) -> Variant:
	if not value is Array or value.size() != 3:
		return null
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)):
			return null
	var result := Vector3(value[0], value[1], value[2])
	return result if result.is_finite() else null


static func _source_vec(value: Variant) -> Variant:
	if not value is Dictionary or not value.has_all(["x", "y", "z"]):
		return null
	return _unpack_vec([value.x, value.y, value.z])


static func _unpack_pose(value: Variant) -> Variant:
	if not value is Dictionary or not value.get("basis_columns") is Array or value.basis_columns.size() != 3:
		return null
	var origin: Variant = _unpack_vec(value.get("origin"))
	var x: Variant = _unpack_vec(value.basis_columns[0])
	var y: Variant = _unpack_vec(value.basis_columns[1])
	var z: Variant = _unpack_vec(value.basis_columns[2])
	if origin == null or x == null or y == null or z == null:
		return null
	return Transform3D(Basis(x, y, z), origin)


static func _sha(sdk: Object, value: Variant) -> String:
	return Runtime.canonicalize(sdk, value).get("sha256", "")


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {"ok": false, "failure_code": "R10AC_CONTACT_CAPTURE_"+code, "detail": detail,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
