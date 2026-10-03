extends RefCounted
## Retain the already sampled native callback population. Projection changes
## coordinate representation only; original source bytes remain alongside it.
const World := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const NativeContacts := preload("res://sdk/adapters/godot/gdscript/development_recovery_native_walking_contacts_v1.gd")
const Floor := preload("res://sdk/adapters/godot/gdscript/development_recovery_floor_source_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const Readiness := preload("res://sdk/adapters/godot/gdscript/recovery_walking_readiness_v1.gd")

static func capture_v1(sdk: Object, arm: Dictionary, compiled: Dictionary, limits: Dictionary) -> Dictionary:
	var source := NativeContacts.source_v1(arm)
	var measured: int = source.get("observation", {}).get("semantic_step", -1)
	var measurement: Dictionary = arm.get("last_collection", {}).get("global_result", {}).get("measurement", {})
	var floor := Floor.capture_v1(sdk, arm.get("model", {}).get("floor"), arm.get("model_instance_id", ""))
	var packet := {"native_source": source, "floor_source": floor,
		"direct_state_source": measurement.get("development_direct_state_source", {}).duplicate(true),
		"source_component_receipts": measurement.get("source_component_receipts", {}).duplicate(true)}
	var projected := project_v1(sdk, packet, measured, arm.get("model_instance_id", ""), arm.get("body_population_instance_sha256", ""))
	if projected.get("ok") != true: return projected
	var readiness := Readiness.measure_v1(projected.request, source.observation.center_of_mass, compiled, limits)
	if not readiness.has("ready"): return readiness
	return {"ok": true, "packet": packet, "projection": projected, "readiness": readiness,
		"readiness_sha256": Runtime.canonicalize(sdk, readiness).get("sha256", ""),
		"new_world_count": 0, "new_solver_step_count": 0, "physics_state_modified": false}

static func _walking_q_v1(q: Dictionary) -> Dictionary:
	# R_native * Ry(+90 degrees): canonical body z is native anatomical x.
	var h := sqrt(0.5)
	return {"x": (q.x-q.z)*h, "y": (q.y+q.w)*h, "z": (q.z+q.x)*h, "w": (q.w-q.y)*h}

static func project_v1(sdk: Object, packet: Dictionary, measured: int, model_id: String, population: String) -> Dictionary:
	var native: Dictionary = packet.get("native_source", {})
	if not NativeContacts.source_valid_v1(sdk, native, measured+1, model_id, population): return _failure("NATIVE_SOURCE")
	var direct: Dictionary = packet.get("direct_state_source", {})
	var components: Dictionary = packet.get("source_component_receipts", {})
	if (direct.get("schema_version") != "sporespore_qsdk_r24d57_godot_direct_state_source_v1"
		or direct.get("semantic_step") != measured or direct.get("source_measurement") != true
		or components.get("semantic_step") != measured or components.get("source_measurement") != true
		or Runtime.canonicalize(sdk, direct).get("sha256") != components.get("direct_state_source_sha256")
		or Transport.stringify(components.get("contact_source_receipt")) != Transport.stringify(native.get("contact_source_receipt"))
		or components.get("contact_source_sha256") != native.get("contact_source_sha256")):
		return _failure("DIRECT_BINDING")
	var floor: Dictionary = packet.get("floor_source", {})
	if not Floor.verify_v1(sdk, floor, model_id): return _failure("FLOOR_SOURCE")
	var rows: Array = direct.get("ordered_body_states", [])
	if rows.size() != 9: return _failure("BODY_POPULATION")
	var state: Dictionary = native.observation.state.duplicate(true)
	var body_rows := []
	for i in range(9):
		var row: Dictionary = rows[i]
		if row.get("body_id") != World.ORDERED_BODY_IDS[i] or row.get("callback_sequence") != measured: return _failure("BODY_IDENTITY")
		var q: Dictionary = row.get("orientation_xyzw", {})
		if Readiness._rotate(q, [0.0, 1.0, 0.0]).is_empty(): return _failure("BODY_QUATERNION")
		for key in ["position_world_m", "linear_velocity_world_m_s", "angular_velocity_world_rad_s"]:
			if Readiness._vector(row.get(key, {})).is_empty(): return _failure("BODY_VECTOR")
		if i > 0 and i % 2 == 0:
			var limb: String = row.body_id.trim_suffix("_distal")
			if Readiness._vector(row.position_world_m) != native.precommand_trace.get("foot_position_world_m_by_limb", {}).get(limb): return _failure("TRACE_DISTAL_POSITION")
		var pose := {"position_m": row.position_world_m, "orientation_xyzw": q}
		var twist := {"linear_velocity_m_s": row.linear_velocity_world_m_s, "angular_velocity_rad_s": row.angular_velocity_world_rad_s}
		if i == 0 and (pose != state.base_pose_world or twist != state.base_twist_world): return _failure("TORSO_SOURCE")
		pose.orientation_xyzw = _walking_q_v1(q)
		body_rows.append({"body_id": row.body_id, "pose_world": pose, "twist_world": twist})
	state.base_pose_world = body_rows[0].pose_world.duplicate(true)
	state.base_twist_world = body_rows[0].twist_world.duplicate(true)
	var frame := {"schema_version": "sporespore_measured_walking_body_frame_v1", "frame_id": "sporespore_state_world_y_up_metres_v1",
		"semantic_step": measured, "sample_time_s": state.sample_time_s, "adapter_capability_sha256": state.adapter_capability_sha256,
		"source_measurement": true, "ordered_body_states": body_rows}
	return {"ok": true, "coordinate_projection": "native_body_to_anatomical_walking_body_Ry_positive_90_v1",
		"request": {"state": state, "measured_body_frame": frame, "floor_reference": floor.floor_reference},
		"source_global_step": measured, "controller_invoked": false, "controller_memory_created": false,
		"original_native_observation_mutated": false, "new_world_count": 0, "new_solver_step_count": 0}

static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": "R10H_ENTRY_SOURCE_"+code}
