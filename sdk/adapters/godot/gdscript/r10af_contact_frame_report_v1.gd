extends RefCounted
## Complete diagnostic sidecar coverage, not the controller/task report audit.
## The ordinary controller reader must ALSO pass before accepting a route result.
const Capture := preload("res://sdk/adapters/godot/gdscript/r10af_contact_frame_capture_v1.gd")
const Seed := preload("res://sdk/adapters/godot/gdscript/r10af_development_seed_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Json := Seed.Json
const LINKS_SCHEMA := "sporespore_r10af_contact_frame_observation_links_v1"


static func link_v1(sdk: Object, arm: Dictionary, step: int) -> Dictionary:
	var collection: Dictionary = arm.get("last_collection", {})
	var observation: Variant = collection.get("global_result", {}).get("bound", {}).get("observation_v3")
	var source: Variant = collection.get("global_result", {}).get("measurement", {}).get("source_component_receipts", {}).get("source_trace")
	if not observation is Dictionary or not source is Dictionary:
		return _failure("LINK_SOURCE_MISSING")
	var rows: Variant = arm.get("trace_rows")
	if not rows is Array or rows.is_empty() or not rows[-1] is Dictionary:
		return _failure("LINK_TRACE_MISSING")
	var result := {"ok": true, "semantic_step": step,
		"global_observation": observation.duplicate(true), "source_trace": source.duplicate(true)}
	return result if _link_valid(sdk, result, rows[-1], step) else _failure("LINK_HASH_CHAIN")


static func _link_valid(sdk: Object, link: Dictionary, row: Dictionary, step: int) -> bool:
	var observation: Variant = link.get("global_observation")
	var source: Variant = link.get("source_trace")
	if (link.get("ok") != true or link.get("semantic_step") != step
		or row.get("global_semantic_step") != step or not observation is Dictionary or not source is Dictionary): return false
	var engine: Variant = observation.get("engine_step_identity")
	if not engine is Dictionary: return false
	return (_sha(sdk, observation) == row.get("observation_sha256")
		and _sha(sdk, source) == engine.get("source_trace_sha256")
		and source.get("semantic_step") == step and source.get("direct_state_callback_sequence") == step
		and source.get("host_step_before") == step-1 and source.get("host_step_after") == step
		and source.get("source_measurement") == true
		and engine.get("schema_version") == "sporespore_recovery_engine_step_identity_v1"
		and engine.get("semantic_step") == step and engine.get("host_step_before") == step-1
		and engine.get("host_step_after") == step and engine.get("native_solver_substep_count") == 1
		and engine.get("post_step_observation") == true)


static func replay_report_v1(sdk: Object, report: Dictionary, declaration: Dictionary, seed_guard: Script = Seed) -> Dictionary:
	var original := report.duplicate(false)
	if not seed_guard.attach_report_context_v1(original, declaration, seed_guard.SEED): return _failure("REPORT_IDENTITY")
	for key in [seed_guard.CONTEXT_KEY, "seed_label", "seed_sha256", "held_out", "held_out_cell_access_count"]:
		if not Json.same_json_v1(report.get(key), original.get(key)): return _failure("REPORT_CONTEXT")
	var count: Variant = report.get("solver_step_count")
	if typeof(count) != TYPE_INT or count < 1 or count > 3752: return _failure("STEP_BOUND")
	var arm: Variant = report.get("retained_arm")
	var capture: Variant = report.get("r10af_contact_frames")
	var links: Variant = report.get("r10af_contact_frame_links")
	if not arm is Dictionary or not capture is Dictionary or not links is Dictionary: return _failure("RETENTION_MISSING")
	if capture.get("schema_version") != "sporespore_r10af_contact_frame_retention_v1" or links.get("schema_version") != LINKS_SCHEMA: return _failure("RETENTION_SCHEMA")
	for retained in [capture, links]:
		if retained.get("controller_observation_changed") != true: return _failure("OBSERVATION_PROFILE")
		for key in ["physical_acceptance_authority", "release_authority"]:
			if typeof(retained.get(key)) != TYPE_BOOL or retained[key]: return _failure("AUTHORITY")
		if typeof(retained.get("record_count")) != TYPE_INT or retained.record_count != count or not retained.get("records") is Array or retained.records.size() != count: return _failure("RECORD_POPULATION")
	var rows: Variant = arm.get("trace_rows")
	var model: Variant = arm.get("model_instance_id")
	var population: Variant = arm.get("body_population_instance_sha256")
	if not rows is Array or rows.size() != count or not model is String or model.is_empty() or not population is String: return _failure("ARM_POPULATION")
	var identities := {}
	var matched := 0
	var changed := 0
	var native_sequence := -1
	for index in count:
		var step: int = index+1
		var row: Variant = rows[index]
		var record: Variant = capture.records[index]
		var link: Variant = links.records[index]
		if not row is Dictionary or not record is Dictionary or not link is Dictionary: return _failure("ROW_KIND")
		if row.get("arm_id") != Seed.ROLE or row.get("body_population_instance_sha256") != population or not _link_valid(sdk, link, row, step): return _failure("TRACE_LINK")
		if record.get("ok") != true or not record.get("packet") is Dictionary: return _failure("CAPTURE_REJECTED")
		if record.get("controller_observation_changed") != true: return _failure("CAPTURE_OBSERVATION_PROFILE")
		for key in ["physical_acceptance_authority", "release_authority"]:
			if typeof(record.get(key)) != TYPE_BOOL or record[key]: return _failure("CAPTURE_AUTHORITY")
		if typeof(record.get("world_build_count")) != TYPE_INT or typeof(record.get("solver_step_count")) != TYPE_INT or record.world_build_count != 0 or record.solver_step_count != 0: return _failure("CAPTURE_COUNTERS")
		var packet: Dictionary = record.packet
		if record.get("packet_sha256") != _sha(sdk, packet): return _failure("PACKET_HASH")
		var replay := Capture.replay_v1(sdk, packet, step, model, population)
		if replay.get("ok") != true or not Json.same_json_v1(record.get("replay"), replay): return _failure("PACKET_REPLAY")
		for key in ["direct_state_source_sha256", "contact_source_sha256"]:
			if packet.source_component_binding.get(key) != link.source_trace.get(key): return _failure("SOURCE_TRACE_HASH")
		var sequence: int = packet.contact_source_receipt.native_space_step_sequence
		if sequence != link.source_trace.get("native_space_step_sequence") or (index > 0 and sequence != native_sequence+1): return _failure("NATIVE_SEQUENCE")
		native_sequence = sequence
		var current := {"floor": packet.floor_instance_id}
		for body in packet.callback_bodies: current[body.body_id] = body.instance_id
		if index == 0: identities = current
		elif current != identities: return _failure("BODY_REPLACEMENT")
		matched += replay.matched_source_contacts
		for comparison in replay.comparisons:
			if comparison.membership_changed: changed += 1
	return {"ok": true, "diagnostic_steps_replayed": count, "matched_source_contacts": matched,
		"classification_changes": changed, "original_observation_hash_chain_verified": true,
		"complete_controller_report_audited": false, "controller_observation_changed": true,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}


static func _sha(sdk: Object, value: Variant) -> String:
	return Runtime.canonicalize(sdk, value).get("sha256", "")


static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "failure_code": "R10AF_CONTACT_REPORT_" + reason}
