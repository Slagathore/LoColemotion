extends RefCounted

## Source-only classification seam. It cannot construct, step or authorize a world.
const Native := preload("res://sdk/adapters/godot/gdscript/recovery_contact_frames_v1.gd")
const PROFILE := "godot_jolt_distal_contact_detection_frame_v1"
const MODEL_KEY := "contact_classification_frame_profile_id"
const SOURCE_SCHEMA := "sporespore_r10af_godot_detection_frame_contact_source_v1"
const FRAME_SCHEMA := "sporespore_r10af_contact_detection_frame_binding_v1"
const TOLERANCE_M := 1.0e-6
const BODIES := ["torso", "front_left_upper", "front_left_distal", "front_right_upper",
	"front_right_distal", "rear_left_upper", "rear_left_distal", "rear_right_upper", "rear_right_distal"]


static func selection_v1(model: Dictionary) -> Dictionary:
	if not model.has(MODEL_KEY):
		return {"ok":true,"selected":false}
	if not model[MODEL_KEY] is String or model[MODEL_KEY] != PROFILE:
		return _failure("UNKNOWN_PROFILE")
	return {"ok":true,"selected":true,"profile_id":PROFILE}


static func prepare_v1(snapshot: Variant, step: int, instances: Dictionary,
	floor_instance: int, samples: Dictionary) -> Dictionary:
	var checked := Native.validate_native_snapshot(snapshot,step)
	if checked.get("ok") != true:
		return _failure("NATIVE_SNAPSHOT",checked)
	if floor_instance <= 0 or instances.size() != BODIES.size() or samples.size() != BODIES.size():
		return _failure("BODY_POPULATION")
	var by_instance := {floor_instance:"floor"}
	var matches := {}
	var source := []
	for body in BODIES:
		if not instances.get(body) is int or instances[body] <= 0 or by_instance.has(instances[body]) or not samples.get(body) is Array:
			return _failure("BODY_IDENTITY")
		by_instance[instances[body]] = body
		matches[body] = []
		for index in range(samples[body].size()):
			matches[body].append({})
			var sample: Variant = samples[body][index]
			if not sample is Dictionary:
				return _failure("SAMPLE_KIND")
			if sample.get("counterparty_id") != "floor":
				continue
			var world: Variant = sample.get("local_position_world_m")
			var normal: Variant = sample.get("local_normal_world_unit")
			var impulse: Variant = sample.get("raw_impulse_world_nms")
			if not world is Vector3 or not normal is Vector3 or not impulse is Vector3:
				return _failure("SAMPLE_VECTOR")
			if not world.is_finite() or not normal.is_finite() or not impulse.is_finite() or normal.length_squared() <= 0.0:
				return _failure("SAMPLE_FINITE")
			var load := absf(impulse.dot(normal.normalized()))
			if load == 0.0:
				continue
			if not sample.get("engine_contact_id") is String or sample.engine_contact_id.is_empty():
				return _failure("SAMPLE_ID")
			source.append({"body_id":body,"index":index,"world":world,"load":load,"engine_id":sample.engine_contact_id})
	var used := {}
	for point_index in range(checked.points.size()):
		var point: Dictionary = checked.points[point_index]
		for side in ["1","2"]:
			var other := "2" if side == "1" else "1"
			var instance: int = point["body"+side+"_instance_id"]
			if not by_instance.has(instance):
				return _failure("UNKNOWN_NATIVE_BODY")
			if point["body"+other+"_instance_id"] != floor_instance or instance == floor_instance:
				continue
			var body: String = by_instance[instance]
			var normal: Vector3 = point["normal"+side+"_world_unit"]
			var impulse: Vector3 = point["impulse"+side+"_world_ns"]
			var load := absf(impulse.dot(normal.normalized()))
			if load == 0.0:
				continue
			var engine_id := "%s:%d|floor:%d" % [body,point["shape"+side+"_index"],point["shape"+other+"_index"]]
			var found := []
			for index in range(source.size()):
				var row: Dictionary = source[index]
				if row.body_id == body and row.engine_id == engine_id and row.world == point["point"+side+"_world_m"] and row.load == load:
					found.append(index)
			if found.size() != 1 or used.has(found[0]):
				return _failure("AMBIGUOUS_OR_MISSING_SOURCE_CONTACT")
			used[found[0]] = true
			matches[body][source[found[0]].index] = {"body_id":body,"native_point_index":point_index,
				"native_side":side,"engine_contact_id":engine_id,"normal_impulse_ns":load,
				"world_point":point["point"+side+"_world_m"],
				"detection_local_point":point["point"+side+"_body_local_m"]}
	if used.size() != source.size():
		return _failure("UNMATCHED_SOURCE_CONTACT")
	return {"ok":true,"profile_id":PROFILE,"matches_by_body":matches,
		"loaded_floor_contact_count":source.size(),"native_point_count":checked.point_count,
		"frame_binding":{"schema_version":FRAME_SCHEMA,"profile_id":PROFILE,
			"classification_scope":"distal_foot_cap_only","native_space_step_sequence":step,
			"body_instances":instances.duplicate(true),"floor_instance_id":floor_instance,
			"native_snapshot":pack_snapshot_v1(snapshot)},
		"world_build_count":0,"solver_step_count":0,
		"physical_acceptance_authority":false,"release_authority":false}


static func classify_v1(body: String, callback_point: Vector3, site: Variant, match_value: Variant) -> Dictionary:
	if not BODIES.has(body) or not callback_point.is_finite() or not match_value is Dictionary:
		return _failure("CLASSIFICATION_INPUT")
	var match_row: Dictionary = match_value
	if match_row.get("body_id") != body or not match_row.get("detection_local_point") is Vector3 or not match_row.detection_local_point.is_finite():
		return _failure("CLASSIFICATION_MATCH")
	var local := callback_point
	var foot := false
	if body.ends_with("_distal"):
		if not site is Dictionary or site.get("contact_site_id") != body.trim_suffix("_distal")+"_foot" or not site.get("local_center_m") is Dictionary:
			return _failure("FOOT_SITE")
		var center: Dictionary = site.local_center_m
		for axis in ["x","y","z"]:
			if not (center.get(axis) is int or center.get(axis) is float) or not is_finite(float(center[axis])):
				return _failure("FOOT_CENTER")
		var vector_center := Vector3(center.x,center.y,center.z)
		if not vector_center.is_finite():
			return _failure("FOOT_CENTER")
		local = match_row.detection_local_point
		foot = local.y <= vector_center.y+TOLERANCE_M
	elif site != null:
		return _failure("NON_DISTAL_SITE")
	return {"ok":true,"classified_as_foot":foot,
		"classification_position_body_local_m":pack_vec_v1(local),
		"detection_position_body_local_m":pack_vec_v1(match_row.detection_local_point),
		"native_point_index":match_row.native_point_index,"native_side":match_row.native_side}


static func pack_vec_v1(value: Vector3) -> Dictionary:
	return {"x":value.x,"y":value.y,"z":value.z}


static func pack_snapshot_v1(snapshot: Dictionary) -> Dictionary:
	var result := snapshot.duplicate(true)
	for point in result.points:
		for side in ["1","2"]:
			var pose: Transform3D = point["body"+side+"_transform_at_detection"]
			point["body"+side+"_transform_at_detection"] = {"origin":pack_vec_v1(pose.origin),
				"basis_columns":[pack_vec_v1(pose.basis.x),pack_vec_v1(pose.basis.y),pack_vec_v1(pose.basis.z)]}
			for name in ["point"+side+"_world_m","point"+side+"_body_local_m","normal"+side+"_world_unit","impulse"+side+"_world_ns"]:
				point[name] = pack_vec_v1(point[name])
	return result


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {"ok":false,"failure_code":"R10AF_CONTACT_FRAME_"+code,"detail":detail,
		"world_build_count":0,"solver_step_count":0,"physical_acceptance_authority":false,"release_authority":false}
