extends RefCounted
# gdlint: disable=max-line-length

const CONTRACT_PATH := "res://sdk/development/recovery_walking_contact_contract_v1.json"
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
static var _contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))

static func valid_selection_v1(id: Variant) -> bool:
	return id is String and id in ["", _contract["profile_id"]]

## Validate all four existing shapes before changing any binding dictionary.
## This neither renames a node nor writes physics state.
static func bind_v1(binding: Dictionary, id: String) -> Dictionary:
	if not valid_selection_v1(id):
		return _failure("SELECTION")
	if id.is_empty():
		return {"ok": true}
	var limbs: Array = binding.get("limbs", [])
	var floor: Variant = binding.get("floor")
	if limbs.size() != 4 or not (floor is StaticBody3D) or floor.get_meta("lab_body_id", "") != _contract["floor_body_id"]:
		return _failure("POPULATION_OR_FLOOR")
	for index in range(4):
		var limb: Dictionary = limbs[index]
		var limb_id: String = _contract["ordered_limb_ids"][index]
		var shape_id := limb_id + String(_contract["shape_id_suffix"])
		var foot: Variant = limb.get("foot")
		if limb.get("limb_id") != limb_id or not (foot is RigidBody3D) or foot.get_meta("lab_body_id", "") != shape_id or not foot.has_method("has_semantic_contact"):
			return _failure("BODY_IDENTITY")
		var shapes := 0
		for child in foot.get_children():
			if child is CollisionShape3D and child.shape != null and not child.disabled:
				if child.get_meta("lab_shape_id", "") != shape_id:
					return _failure("SHAPE_IDENTITY")
				shapes += 1
		if shapes != 1:
			return _failure("SHAPE_POPULATION")
		if int(foot.get("semantic_contact_callback_count")) <= 0:
			return _failure("CALLBACK_MISSING")
	for limb in limbs:
		limb["contact_shape_id"] = String(limb["limb_id"]) + String(_contract["shape_id_suffix"])
	return {"ok": true, "profile_id": id, "body_property_write_count": 0, "additional_native_physics_read_count": 0}

## Copy already available callback properties, not PhysicsServer state.
static func sources_v1(limbs: Array) -> Array:
	var rows := []
	for limb in limbs:
		var foot: RigidBody3D = limb["foot"]
		var samples := []
		for sample in foot.get("latest_semantic_contact_samples"):
			var normal: Vector3 = sample["local_normal_world_unit"]
			samples.append({"local_shape_id": sample["local_shape_id"], "counterparty_id": sample["counterparty_id"],
				"local_shape_index": sample["local_shape_index"], "collider_shape_index": sample["collider_shape_index"],
				"normal": [normal.x, normal.y, normal.z]})
		rows.append({"limb_id": limb["limb_id"], "shape_id": limb["contact_shape_id"], "foot_node_name": String(foot.name),
			"callback_sequence": foot.get("semantic_contact_callback_count"),
			"semantic_contacts": foot.get("latest_semantic_contacts").duplicate(true), "samples": samples})
	return rows

static func retain_step_v1(segment: String, step: Dictionary, digest: String) -> Dictionary:
	var sample: Dictionary = step.get("sample_receipt", {})
	var row := {"segment_id": segment, "session_id": step.get("session_id"),
		"commanded_global_step": step.get("global_semantic_step"), "session_local_step": step.get("session_local_step"),
		"full_step_receipt_sha256": digest, "sources": sample.get("development_contact_sources", []),
		"controller_contacts": sample.get("request", {}).get("state", {}).get("ordered_contact_observations", []),
		"stability_contacts": sample.get("stability_shadow", {}).get("stability_state", {}).get("ordered_support_contacts", []),
		"native_limb_memory": step.get("portable_step_receipt", {}).get("native_output", {}).get("next_memory", {}).get("ordered_limb_memory", [])}
	if not row_valid_v1(row):
		return _failure("PRODUCER_CONTACTS")
	return {"ok": true, "row": row.duplicate(true)}

static func row_valid_v1(row: Dictionary) -> bool:
	if row.get("segment_id") not in _contract["segments"]:
		return false
	for key in ["sources", "controller_contacts", "stability_contacts", "native_limb_memory"]:
		if not (row.get(key) is Array) or row[key].size() != 4:
			return false
	# Native memory follows gait order, not contact-observation order. Keep its
	# retained order exact and join by explicit limb identity, never array index.
	var memory_by_limb := {}
	for memory in row["native_limb_memory"]:
		if not (memory is Dictionary) or memory_by_limb.has(memory.get("limb_id")):
			return false
		memory_by_limb[memory.get("limb_id")] = memory
	for index in range(4):
		var limb_id: String = _contract["ordered_limb_ids"][index]
		var shape_id := limb_id + String(_contract["shape_id_suffix"])
		var source: Dictionary = row["sources"][index]
		var contact: Dictionary = row["controller_contacts"][index]
		var support: Dictionary = row["stability_contacts"][index]
		var memory: Dictionary = memory_by_limb.get(limb_id, {})
		if source.get("limb_id") != limb_id or source.get("shape_id") != shape_id or int(source.get("callback_sequence", 0)) <= 0 or not (source.get("semantic_contacts") is Dictionary) or not (source.get("samples") is Array):
			return false
		var bearing: bool = source["semantic_contacts"].has(shape_id + "|floor")
		var ids: Array[String] = []
		var normal := Vector3.ZERO
		for sample in source["samples"]:
			if sample.get("local_shape_id") == shape_id and sample.get("counterparty_id") == "floor" and int(sample.get("local_shape_index", -1)) >= 0 and int(sample.get("collider_shape_index", -1)) >= 0:
				ids.append("%s_local_shape_%d_floor_shape_%d" % [source["foot_node_name"], sample["local_shape_index"], sample["collider_shape_index"]])
				var values: Array = sample.get("normal", [])
				if values.size() != 3:
					return false
				normal += Vector3(values[0], values[1], values[2])
		ids.sort()
		var unique: Array[String] = []
		for value in ids:
			if not unique.has(value):
				unique.append(value)
		if contact.get("contact_site_id") != limb_id + "_foot" or contact.get("presence") != bearing or contact.get("bears_support") != bearing or contact.get("provenance", {}).get("engine_contact_ids") != ids:
			return false
		if support.get("contact_site_id") != limb_id + "_foot" or support.get("presence") != (not ids.is_empty()) or support.get("bears_support") != (bearing and not ids.is_empty() and normal.normalized().dot(Vector3.UP) >= 0.5) or support.get("engine_contact_ids") != unique:
			return false
		var count: Variant = memory.get("gate_timeout_count")
		if memory.get("limb_id") != limb_id or typeof(count) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(count) or count < 0 or count != int(count):
			return false
	return true

static func retention_v1(rows: Array, id: String) -> Dictionary:
	var terminal_by_session := {}
	for row in rows:
		var total := 0
		for memory in row["native_limb_memory"]:
			total += int(memory["gate_timeout_count"])
		terminal_by_session[row["session_id"]] = {"segment_id": row["segment_id"], "actual_native_gate_timeout_total": total,
			"actual_native_contact_gating_without_timeout": total == 0, "original_evaluator_replaced": false}
	return {"schema_version": _contract["retention_schema"], "profile_id": id, "rows": rows.duplicate(true),
		"sample_count": rows.size(), "terminal_timeout_diagnostics_by_session": terminal_by_session,
		"additional_native_physics_read_count": 0, "physical_acceptance_authority": false, "release_authority": false}

static func validate_report_v1(report: Dictionary, id: String) -> Dictionary:
	if not valid_selection_v1(id):
		return _failure("READER_SELECTION")
	if id.is_empty():
		return {"ok": not report.has("development_walking_contacts")}
	var retained: Dictionary = report.get("development_walking_contacts", {})
	var rows: Array = retained.get("rows", [])
	for row in rows:
		if not (row is Dictionary) or not row_valid_v1(row):
			return _failure("READER_CONTACT_SOURCE")
	if Transport.stringify(retained) != Transport.stringify(retention_v1(rows, id)):
		return _failure("READER_RETENTION_OR_TIMEOUT_DIAGNOSIS")
	var expected := []
	var sessions := {}
	for session in report["retained_arm"].get("walking_sessions", []):
		sessions[session["session_id"]] = session
		if session.get("start_receipt", {}).get("development_walking_contact_profile_id") != id:
			return _failure("READER_SESSION_SELECTION")
	for trace in report["retained_arm"]["trace_rows"]:
		if trace.get("walking_segment_id") in _contract["segments"]:
			expected.append(trace)
	if rows.size() != expected.size():
		return _failure("READER_POPULATION")
	var resumed := {}
	for row in report.get("development_walking_entry", {}).get("rows", []):
		resumed[row["commanded_global_step"]] = row
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var trace: Dictionary = expected[index]
		var local_step := int(trace["walking_session_local_step"])
		var session: Dictionary = sessions.get(trace["walking_session_id"], {})
		if not row_valid_v1(row) or row.get("commanded_global_step") != trace["global_semantic_step"] or row.get("session_local_step") != local_step or row.get("session_id") != trace["walking_session_id"] or row.get("segment_id") != trace["walking_segment_id"]:
			return _failure("READER_SOURCE_OR_STEP_LINK")
		if local_step < 1 or session.get("step_receipt_sha256s", []).size() < local_step or row.get("full_step_receipt_sha256") != session["step_receipt_sha256s"][local_step - 1]:
			return _failure("READER_FULL_STEP_LINK")
		if row["segment_id"] == "walking_resume":
			var full: Dictionary = resumed.get(row["commanded_global_step"], {})
			if Transport.stringify(row["controller_contacts"]) != Transport.stringify(full.get("request", {}).get("state", {}).get("ordered_contact_observations")) or Transport.stringify(row["native_limb_memory"]) != Transport.stringify(full.get("native_output", {}).get("next_memory", {}).get("ordered_limb_memory")):
				return _failure("READER_NATIVE_INPUT_OR_MEMORY_LINK")
	return {"ok": true, "validated_contact_steps": rows.size(), "additional_native_physics_read_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}

static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": "DEVELOPMENT_WALKING_CONTACT_" + code}
