extends RefCounted
const FiniteRoute := preload("res://sdk/adapters/godot/gdscript/recovery_finite_cycle_route_v1.gd")
# gdlint: disable=max-line-length

const DetectionSelection := preload("res://sdk/adapters/godot/gdscript/r10af_contact_source_selection_v1.gd")
const CONTRACT_PATH := "res://sdk/development/recovery_native_walking_contact_contract_v1.json"
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const World := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const ShapeContacts := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_contacts_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
static var _contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))

static func selected_v1(id: Variant) -> bool:
	return id is String and id == _contract["profile_id"]

static func source_v1(arm: Dictionary) -> Dictionary:
	var global_result: Dictionary = arm.get("last_collection", {}).get("global_result", {})
	var components: Dictionary = global_result.get("measurement", {}).get("source_component_receipts", {})
	var trace: Array = arm.get("trace_rows", [])
	return {"model_instance_id": arm.get("model_instance_id"),
		"body_population_instance_sha256": arm.get("body_population_instance_sha256"),
		"precommand_trace": trace[-1].duplicate(true) if not trace.is_empty() else {},
		"observation": global_result.get("bound", {}).get("observation_v3", {}).duplicate(true),
		"contact_source_receipt": components.get("contact_source_receipt", {}).duplicate(true),
		"contact_source_sha256": components.get("contact_source_sha256", "")}

static func source_valid_v1(sdk: Object, source: Dictionary, commanded_global_step: int, model_instance_id: String, body_population_sha: String) -> bool:
	var observation: Dictionary = source.get("observation", {})
	var trace: Dictionary = source.get("precommand_trace", {})
	var contact_source: Dictionary = source.get("contact_source_receipt", {})
	var aggregation := DetectionSelection.aggregation_v1(contact_source, _contract["source_aggregation_rule_id"])
	if aggregation.is_empty(): return false
	var measured := commanded_global_step - 1
	if measured < 1 or source.get("model_instance_id") != model_instance_id or source.get("body_population_instance_sha256") != body_population_sha or trace.get("body_population_instance_sha256") != body_population_sha:
		return false
	if trace.get("global_semantic_step") != measured or observation.get("semantic_step") != measured or observation.get("state", {}).get("semantic_step") != measured or contact_source.get("semantic_step") != measured:
		return false
	if _sha(sdk, observation) != trace.get("observation_sha256") or _sha(sdk, contact_source) != source.get("contact_source_sha256"):
		return false
	var identity: Dictionary = observation.get("engine_step_identity", {})
	if identity.get("post_step_observation") != true or identity.get("source_kind") != "native_post_step" or identity.get("semantic_step") != measured:
		return false
	var contacts: Array = observation.get("state", {}).get("ordered_contact_observations", [])
	var bearings: Array = observation.get("ordered_foot_bearing_observations", [])
	if contacts.size() != 4 or bearings.size() != 4 or contact_source.get("source_measurement") != true:
		return false
	for index in range(4):
		var limb: String = _contract["ordered_limb_ids"][index]
		var contact: Dictionary = contacts[index]
		var bearing: Dictionary = bearings[index]
		var provenance: Dictionary = contact.get("provenance", {})
		if contact.get("contact_site_id") != limb + "_foot" or bearing.get("contact_site_id") != limb + "_foot" or bearing.get("source_measurement") != true:
			return false
		if provenance.get("adapter_id") != _contract["source_adapter_id"] or provenance.get("aggregation_rule_id") != aggregation or provenance.get("impulse_source_profile_id") != _contract["source_impulse_profile_id"] or provenance.get("impulse_source_kind") != _contract["source_impulse_kind"] or provenance.get("quality") != "qualified_bearing":
			return false
		if typeof(contact.get("presence")) != TYPE_BOOL or typeof(contact.get("bears_support")) != TYPE_BOOL or contact.get("normal_load_n") != null or not (provenance.get("engine_contact_ids") is Array):
			return false
		var impulse: Variant = bearing.get("bearing_normal_impulse_ns")
		if typeof(impulse) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(impulse) or impulse < 0:
			return false
		# These are the existing native observation's own identities and boolean
		# definitions, not the separate minimum impulse used by standing gates.
		var ids: Array = provenance["engine_contact_ids"]
		if contact["presence"] != (not ids.is_empty()) or contact["bears_support"] != (contact["presence"] and impulse > 0.0) or bearing.get("ordinary_unilateral_contact") != contact["presence"] or trace.get("contact_by_limb", {}).get(limb) != contact["bears_support"]:
			return false
	return true

## Stage every limb before mutating any adapter binding. Geometry is selected
## from already-cached callback samples using the native receipt's existing
## point/foot classification, never a new height, impulse or timing threshold.
static func prepare_v1(sdk: Object, source: Dictionary, binding: Dictionary, commanded_global_step: int, body_population_sha: String) -> Dictionary:
	if not source_valid_v1(sdk, source, commanded_global_step, binding.get("model_instance_id", ""), body_population_sha):
		return _failure("SOURCE_IDENTITY_OR_CLOCK")
	var limbs: Array = binding.get("limbs", [])
	var contacts: Array = source["observation"]["state"]["ordered_contact_observations"]
	var classified: Array = source["contact_source_receipt"].get("ordered_contact_samples", [])
	if limbs.size() != 4:
		return _failure("LIMB_POPULATION")
	var staged := []
	for index in range(4):
		var limb: Dictionary = limbs[index]
		var limb_id: String = _contract["ordered_limb_ids"][index]
		if limb.get("limb_id") != limb_id:
			return _failure("LIMB_IDENTITY")
		var foot: RigidBody3D = limb["foot"]
		if int(foot.get("semantic_contact_callback_count")) != commanded_global_step - 1:
			return _failure("CALLBACK_CLOCK")
		var matched: Array[Dictionary] = []
		var raw_ids: Array = []
		for point in classified:
			if point.get("body_id") != limb_id + "_distal" or point.get("classified_as_foot") != true:
				continue
			var position: Dictionary = point.get("position_world_m", {})
			if not position.has_all(["x", "y", "z"]):
				return _failure("SOURCE_POINT")
			var found := false
			for sample in foot.get("latest_semantic_contact_samples"):
				if sample.get("engine_contact_id") == point.get("engine_contact_id") and sample.get("local_position_world_m") == Vector3(position["x"], position["y"], position["z"]):
					matched.append(sample.duplicate(true))
					raw_ids.append(sample["engine_contact_id"])
					found = true
					break
			if not found:
				return _failure("NATIVE_POINT_NOT_IN_CALLBACK")
		var projection := World.native_contact_identity_projection_v2(raw_ids)
		if projection.get("ok") != true or projection.get("engine_contact_ids") != contacts[index]["provenance"]["engine_contact_ids"]:
			return _failure("CONTACT_PROVENANCE")
		staged.append({"observation": contacts[index].duplicate(true), "samples": matched})
	for index in range(4):
		limbs[index]["native_qualified_contact"] = staged[index]["observation"]
		limbs[index]["native_qualified_contact_samples"] = staged[index]["samples"]
	return {"ok": true, "source": source.duplicate(true), "additional_native_physics_read_count": 0}

static func retain_step_v1(segment: String, step: Dictionary, digest: String, route_id: String = "") -> Dictionary:
	var sample: Dictionary = step.get("sample_receipt", {})
	var request: Dictionary = sample.get("request", {})
	var portable: Dictionary = step.get("portable_step_receipt", {})
	var source: Dictionary = sample.get("development_native_contact_source", {})
	var contacts: Array = request.get("state", {}).get("ordered_contact_observations", [])
	if source.is_empty() or contacts.size() != 4 or Transport.stringify(contacts) != Transport.stringify(source.get("observation", {}).get("state", {}).get("ordered_contact_observations")):
		return _failure("PRODUCER_NATIVE_CONTACT_LINK")
	var row := {"segment_id": segment, "session_id": step["session_id"], "commanded_global_step": step["global_semantic_step"],
		"session_local_step": step["session_local_step"], "full_step_receipt_sha256": digest, "native_source": source.duplicate(true),
		"controller_contacts": contacts.duplicate(true),
		"stability_contacts": sample.get("stability_shadow", {}).get("stability_state", {}).get("ordered_support_contacts", []).duplicate(true),
		"native_limb_memory": portable.get("native_output", {}).get("next_memory", {}).get("ordered_limb_memory", []).duplicate(true)}
	# Resumed commands already have full source/output retention and replay in
	# WalkingEntry. Add that same raw-response boundary for the short prefix.
	if not FiniteRoute.segment_selected_v1(route_id, segment):
		row["prefix_control"] = {"request": request.duplicate(true), "native_output": portable["native_output"].duplicate(true),
			"raw_native_response_sha256": portable["native_step_transport_verification"]["raw_native_response_sha256"]}
	return {"ok": true, "row": row}

static func retention_v1(rows: Array) -> Dictionary:
	var result := ShapeContacts.retention_v1(rows, _contract["profile_id"])
	result["schema_version"] = _contract["retention_schema"]
	return result

static func validate_report_v1(sdk: Object, report: Dictionary, route_id: String = "") -> Dictionary:
	if report.has("development_walking_contacts"):
		return _failure("READER_CROSSED_RETENTION")
	var retained: Dictionary = report.get("development_native_walking_contacts", {})
	var rows: Array = retained.get("rows", [])
	for row in rows:
		if not (row is Dictionary) or not (row.get("native_limb_memory") is Array) or row["native_limb_memory"].size() != 4:
			return _failure("READER_MEMORY_POPULATION")
		var seen := {}
		for memory in row["native_limb_memory"]:
			var count: Variant = memory.get("gate_timeout_count")
			if memory.get("limb_id") not in _contract["ordered_limb_ids"] or seen.has(memory["limb_id"]) or typeof(count) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(count) or count != int(count) or count < 0:
				return _failure("READER_MEMORY_IDENTITY")
			seen[memory["limb_id"]] = true
	if Transport.stringify(retained) != Transport.stringify(retention_v1(rows)):
		return _failure("READER_RETENTION_OR_TIMEOUT")
	var arm: Dictionary = report["retained_arm"]
	var traces := {}
	var expected := []
	var sessions := {}
	for trace in arm["trace_rows"]:
		traces[trace["global_semantic_step"]] = trace
		if trace.get("walking_segment_id") in ShapeContacts._contract["segments"]:
			expected.append(trace)
	for session in arm.get("walking_sessions", []):
		# The explicitly selected neutral population is replayed by StanceEntryReplay.
		if FiniteRoute.StanceEntry.selected_v1(route_id) and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.SEGMENT:
			continue
		if FiniteRoute.StanceEntry.hold_selected_v1(route_id) and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.HOLD_SEGMENT:
			continue
		if route_id == FiniteRoute.StanceEntry.R10AP.ID and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.R10AP.POST_HOLD_SEGMENT:
			var start: Dictionary = session.get("start_receipt", {})
			if start.get("development_walking_policy_id") != FiniteRoute.StanceEntry.R10AP.POST_HOLD_ALIAS or start.has("development_walking_contact_profile_id"):
				return _failure("READER_POST_HOLD_SELECTION")
			# The separate R10AP hold reader replays this command/source population.
			continue
		if route_id == FiniteRoute.StanceEntry.R10AM.ID and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.R10AM.POST_HOLD_SEGMENT:
			var start: Dictionary = session.get("start_receipt", {})
			if start.get("development_walking_policy_id") != FiniteRoute.StanceEntry.R10AM.POST_HOLD_ALIAS or start.has("development_walking_contact_profile_id"):
				return _failure("READER_POST_HOLD_SELECTION")
			# The separate R10AM hold reader replays this command/source population.
			continue
		if route_id == FiniteRoute.StanceEntry.R10AJ.ID and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.R10AJ.POST_HOLD_SEGMENT:
			var start: Dictionary = session.get("start_receipt", {})
			if start.get("development_walking_policy_id") != FiniteRoute.StanceEntry.R10AJ.POST_HOLD_ALIAS or start.has("development_walking_contact_profile_id"):
				return _failure("READER_POST_HOLD_SELECTION")
			# The separate R10AJ hold reader replays this command/source population.
			continue
		if route_id == FiniteRoute.StanceEntry.R10AI.ID and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.R10AI.POST_HOLD_SEGMENT:
			var start: Dictionary = session.get("start_receipt", {})
			if start.get("development_walking_policy_id") != FiniteRoute.StanceEntry.R10AI.POST_HOLD_ALIAS or start.has("development_walking_contact_profile_id"):
				return _failure("READER_POST_HOLD_SELECTION")
			# The separate R10AI hold reader replays this command/source population.
			continue
		if route_id == FiniteRoute.StanceEntry.R10AG.ID and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.R10AG.POST_HOLD_SEGMENT:
			var start: Dictionary = session.get("start_receipt", {})
			if start.get("development_walking_policy_id") != FiniteRoute.StanceEntry.R10AG.POST_HOLD_ALIAS or start.has("development_walking_contact_profile_id"):
				return _failure("READER_POST_HOLD_SELECTION")
			# The separate R10AG hold reader replays this command/source population.
			continue
		if route_id == FiniteRoute.StanceEntry.R10AB.ID and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.R10AB.POST_HOLD_SEGMENT:
			var start: Dictionary = session.get("start_receipt", {})
			if start.get("development_walking_policy_id") != FiniteRoute.StanceEntry.R10AB.POST_HOLD_ALIAS or start.has("development_walking_contact_profile_id"):
				return _failure("READER_POST_HOLD_SELECTION")
			# The separate R10AB hold reader replays this command/source population.
			continue
		if route_id == FiniteRoute.StanceEntry.R10AA.ID and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.R10AA.POST_HOLD_SEGMENT:
			var start: Dictionary = session.get("start_receipt", {})
			if start.get("development_walking_policy_id") != FiniteRoute.StanceEntry.R10AA.POST_HOLD_ALIAS or start.has("development_walking_contact_profile_id"):
				return _failure("READER_POST_HOLD_SELECTION")
			# The separate R10AA hold reader replays this command/source population.
			continue
		if route_id == FiniteRoute.StanceEntry.R10Z.ID and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.R10Z.POST_HOLD_SEGMENT:
			var start: Dictionary = session.get("start_receipt", {})
			if start.get("development_walking_policy_id") != FiniteRoute.StanceEntry.R10Z.POST_HOLD_ALIAS or start.has("development_walking_contact_profile_id"):
				return _failure("READER_POST_HOLD_SELECTION")
			# The separate R10Z hold reader replays this command/source population.
			continue
		if route_id == FiniteRoute.StanceEntry.R10Y.ID and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.R10Y.POST_HOLD_SEGMENT:
			var start: Dictionary = session.get("start_receipt", {})
			if start.get("development_walking_policy_id") != FiniteRoute.StanceEntry.R10Y.POST_HOLD_ALIAS or start.has("development_walking_contact_profile_id"):
				return _failure("READER_POST_HOLD_SELECTION")
			# The separate R10Y hold reader replays this command/source population.
			continue
		if route_id == FiniteRoute.StanceEntry.R10V.ID and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.R10V.POST_HOLD_SEGMENT:
			var start: Dictionary = session.get("start_receipt", {})
			if start.get("development_walking_policy_id") != FiniteRoute.StanceEntry.R10V.POST_HOLD_ALIAS or start.has("development_walking_contact_profile_id"):
				return _failure("READER_POST_HOLD_SELECTION")
			# The separate R10V hold reader replays this command/source population.
			continue
		if route_id == FiniteRoute.StanceEntry.R10U.ID and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.R10U.POST_HOLD_SEGMENT:
			var start: Dictionary = session.get("start_receipt", {})
			if start.get("development_walking_policy_id") != FiniteRoute.StanceEntry.R10U.POST_HOLD_ALIAS or start.has("development_walking_contact_profile_id"):
				return _failure("READER_POST_HOLD_SELECTION")
			# The separate R10U hold reader replays this command/source population.
			continue
		if route_id == FiniteRoute.StanceEntry.R10T.ID and session.get("evaluation_segment_id") == FiniteRoute.StanceEntry.R10T.POST_HOLD_SEGMENT:
			var start: Dictionary = session.get("start_receipt", {})
			if start.get("development_walking_policy_id") != FiniteRoute.StanceEntry.R10T.POST_HOLD_ALIAS or start.has("development_walking_contact_profile_id"):
				return _failure("READER_POST_HOLD_SELECTION")
			# The separate R10T hold reader replays this command/source population.
			continue
		if session.get("start_receipt", {}).get("development_walking_contact_profile_id") != _contract["profile_id"]:
			return _failure("READER_SESSION_SELECTION")
		sessions[session["session_id"]] = session
	if expected.size() != rows.size():
		return _failure("READER_CONTACT_POPULATION")
	var resumed := {}
	for row in report.get("development_walking_entry", {}).get("rows", []):
		resumed[row["commanded_global_step"]] = row
	var previous_memory := {}
	var replayed_prefix := 0
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var trace: Dictionary = expected[index]
		var local_step := int(trace["walking_session_local_step"])
		var global_step := int(trace["global_semantic_step"])
		var session: Dictionary = sessions.get(trace["walking_session_id"], {})
		var source: Dictionary = row.get("native_source", {})
		if row.get("session_id") != trace["walking_session_id"] or row.get("segment_id") != trace["walking_segment_id"] or row.get("commanded_global_step") != global_step or row.get("session_local_step") != local_step:
			return _failure("READER_CLOCK")
		if local_step < 1 or session.get("step_receipt_sha256s", []).size() < local_step or row.get("full_step_receipt_sha256") != session["step_receipt_sha256s"][local_step - 1]:
			return _failure("READER_STEP_DIGEST")
		if not source_valid_v1(sdk, source, global_step, arm.get("model_instance_id", ""), arm.get("body_population_instance_sha256", "")) or Transport.stringify(source["precommand_trace"]) != Transport.stringify(traces.get(global_step - 1)):
			return _failure("READER_NATIVE_SOURCE")
		var contacts: Array = source["observation"]["state"]["ordered_contact_observations"]
		if Transport.stringify(row.get("controller_contacts")) != Transport.stringify(contacts) or row.get("stability_contacts", []).size() != 4:
			return _failure("READER_NATIVE_CONTACT_VALUES")
		for contact_index in range(4):
			var support: Dictionary = row["stability_contacts"][contact_index]
			var contact: Dictionary = contacts[contact_index]
			if support.get("contact_site_id") != contact["contact_site_id"] or support.get("presence") != contact["presence"] or support.get("engine_contact_ids") != contact["provenance"]["engine_contact_ids"] or (support.get("bears_support") == true and contact["bears_support"] != true):
				return _failure("READER_STABILITY_CONTACT_LINK")
		var full: Dictionary
		if FiniteRoute.segment_selected_v1(route_id, row["segment_id"]):
			full = resumed.get(global_step, {})
		else:
			full = row.get("prefix_control", {})
			var pure: Dictionary = full.get("request", {}).duplicate(true)
			if pure.get("state", {}).get("semantic_step") != local_step:
				return _failure("READER_PREFIX_CLOCK")
			if previous_memory.has(row["session_id"]) and Transport.stringify(pure.get("memory")) != Transport.stringify(previous_memory[row["session_id"]]):
				return _failure("READER_PREFIX_MEMORY_CHAIN")
			pure["schema_version"] = "sporespore_balanced_wave_policy_step_request_v1"
			pure["descriptor"] = report["configuration"]["base_descriptor"]
			pure["policy_id"] = "sporespore_balanced_wave_bw5r_b_v1"
			var raw: String = sdk.balanced_wave_policy_step_json(Transport.stringify(pure))
			var response: Variant = JSON.parse_string(raw)
			if "sha256:" + raw.sha256_text() != full.get("raw_native_response_sha256") or not (response is Dictionary) or response.get("ok") != true or Transport.stringify(response.get("value")) != Transport.stringify(full.get("native_output")):
				return _failure("READER_PREFIX_NATIVE_RESPONSE")
			previous_memory[row["session_id"]] = response["value"]["next_memory"]
			replayed_prefix += 1
		if Transport.stringify(full.get("request", {}).get("state", {}).get("ordered_contact_observations")) != Transport.stringify(contacts) or Transport.stringify(full.get("native_output", {}).get("next_memory", {}).get("ordered_limb_memory")) != Transport.stringify(row["native_limb_memory"]):
			return _failure("READER_CONTROLLER_SOURCE_LINK")
	return {"ok": true, "validated_native_contact_steps": rows.size(), "replayed_prefix_commands": replayed_prefix,
		"additional_native_physics_read_count": 0, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}

static func _sha(sdk: Object, value: Variant) -> String:
	return String(Runtime.canonicalize(sdk, value).get("sha256", ""))

static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": "DEVELOPMENT_NATIVE_WALKING_CONTACT_" + code}
