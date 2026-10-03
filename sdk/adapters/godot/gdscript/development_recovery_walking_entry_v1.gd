extends RefCounted
# gdlint: disable=max-line-length

## Reuse existing sampled data and a published launcher amplitude function.
## No model, body lookup, native measurement, or motor write is available here.
const CONTRACT_PATH := "res://sdk/development/recovery_walking_entry_contract_v1.json"
const Launcher := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const MemoryTransition := preload("res://sdk/adapters/godot/gdscript/development_walking_memory_transition_v1.gd")
const Startup := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd")
const Policy := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_policy_v1.gd")
const CycleStop := preload("res://sdk/adapters/godot/gdscript/development_recovery_cycle_stop_v1.gd")
const NativeContacts := preload("res://sdk/adapters/godot/gdscript/development_recovery_native_walking_contacts_v1.gd")
const MeasuredBody := preload("res://sdk/adapters/godot/gdscript/development_recovery_measured_body_source_v1.gd")
const Floor := preload("res://sdk/adapters/godot/gdscript/development_recovery_floor_source_v1.gd")
static var _contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
static var _clocked_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_clocked_walking_entry_contract_v1.json"))

static func valid_selection_v1(id: Variant) -> bool:
	return id is String and (id in ["", _contract["profile_id"], _clocked_contract["profile_id"]] or Startup.selected_v1(id))

static func phase_mode_v1(local_step: int, id: String = "") -> String:
	if not valid_selection_v1(id) or local_step < 1:
		return ""
	if Startup.phase_family_id_v1(id) == _clocked_contract["profile_id"] and local_step < int(_clocked_contract["first_contact_gated_local_step"]):
		return _clocked_contract["warmup_phase_progression_mode"]
	return "contact_gated"

static func amplitude_v1(local_step: int, id: String = "") -> float:
	if not valid_selection_v1(id) or local_step < 1:
		return NAN
	if id.is_empty():
		return 1.0
	# Select duration and a separately versioned scalar; phase clocks stay exact.
	var ramp_steps := Launcher.SWING_TICKS if Startup.selected_v1(id) else Launcher.CYCLE_TICKS
	return Startup.maximum_amplitude_v1(id) * Launcher._gait_amplitude(Launcher.SETTLE_TICKS + local_step - 1,
		10000, 11000, Launcher.SETTLE_TICKS, Launcher.WARMUP_CYCLES, Launcher.COOLDOWN_CYCLES, ramp_steps)

static func retain_step_v1(step: Dictionary, id: String, full_step_sha: String, stopping: bool = false) -> Dictionary:
	if (stopping and not CycleStop.selected_entry_v1(id)) or not valid_selection_v1(id) or id.is_empty() or step.get("ok") != true:
		return _failure("PRODUCER_SELECTION_OR_STEP")
	var sample: Variant = step.get("sample_receipt")
	var portable: Variant = step.get("portable_step_receipt")
	if not (sample is Dictionary) or not (portable is Dictionary):
		return _failure("PRODUCER_SOURCE_SHAPE")
	var request: Variant = sample.get("request")
	var output: Variant = portable.get("native_output")
	var bodies: Variant = sample.get("stability_shadow", {}).get("stability_state", {}).get("ordered_body_states")
	if not (request is Dictionary) or not (output is Dictionary) or not (bodies is Array) or bodies.size() != 9:
		return _failure("PRODUCER_SAMPLED_POPULATION")
	var local_step: int = step.get("session_local_step", -1)
	if request.get("state", {}).get("semantic_step") != local_step or request.get("command", {}).get("gait_amplitude") != (0.0 if stopping else amplitude_v1(local_step, id)) or request.get("command", {}).get("phase_progression_mode") != phase_mode_v1(local_step, id):
		return _failure("PRODUCER_SCHEDULE_CROSSED")
	var result := {"ok": true, "row": {"schema_version": _contract["step_schema"],
		"session_id": step["session_id"], "commanded_global_step": step["global_semantic_step"],
		"measured_global_step": int(step["global_semantic_step"]) - 1,
		"session_local_step": local_step, "request": request.duplicate(true),
		"native_output": output.duplicate(true), "ordered_body_states": bodies.duplicate(true),
		"raw_native_response_sha256": portable["native_step_transport_verification"]["raw_native_response_sha256"],
		"ordered_motor_applications": step["authority_application_receipt"]["ordered_applications"].duplicate(true),
		"full_step_receipt_sha256": full_step_sha}}
	if CycleStop.selected_entry_v1(id):
		result["row"]["development_cycle_stopping"] = stopping
	if sample.has("development_floor_source"):
		result["row"]["development_floor_source"] = sample["development_floor_source"].duplicate(true)
	return result

static func retention_v1(rows: Array, id: String) -> Dictionary:
	return {"schema_version": _contract["retention_schema"], "profile_id": id,
		"rows": rows.duplicate(true), "sample_count": rows.size(),
		"additional_native_physics_read_count": 0, "physical_acceptance_authority": false, "release_authority": false}

static func validate_report_v1(sdk: Object, report: Dictionary, id: String, memory_transition_profile: String = "", development_policy_id: String = "") -> Dictionary:
	var policy := Policy.binding_v1(development_policy_id, "walking_resume")
	if policy.is_empty() or (policy["development"] and (id.is_empty() or not memory_transition_profile.is_empty())):
		return _failure("READER_POLICY_SELECTION")
	if not valid_selection_v1(id):
		return _failure("READER_SELECTION")
	if not memory_transition_profile.is_empty() and not MemoryTransition.selection_valid_v1(memory_transition_profile, id):
		return _failure("READER_MEMORY_TRANSITION_SELECTION")
	if id.is_empty():
		return {"ok": not report.has("development_walking_entry"), "replayed_walking_steps": 0}
	var retained: Variant = report.get("development_walking_entry")
	if not (retained is Dictionary) or retained.get("schema_version") != _contract["retention_schema"] or retained.get("profile_id") != id:
		return _failure("READER_RETENTION")
	if retained.get("physical_acceptance_authority") != false or retained.get("release_authority") != false or retained.get("additional_native_physics_read_count") != 0:
		return _failure("READER_AUTHORITY")
	var rows: Variant = retained.get("rows")
	if not (rows is Array) or retained.get("sample_count") != rows.size():
		return _failure("READER_POPULATION")
	var expected := []
	var arm: Dictionary = report["retained_arm"]
	var floor_geometry := {}
	if Policy.floor_selected_v1(development_policy_id):
		var compiled: Variant = JSON.parse_string(sdk.compile_bounded_quadruped_json(Transport.stringify(report.get("configuration", {}).get("base_descriptor", {}))))
		if not (compiled is Dictionary) or compiled.get("ok") != true:
			return _failure("FLOOR_COMPILED_GEOMETRY")
		floor_geometry = compiled["value"]["geometry"]
	for row in arm["trace_rows"]:
		if Policy.FiniteRoute.segment_selected_v1(development_policy_id, row.get("walking_segment_id", "")):
			expected.append(row)
	if rows.size() != expected.size():
		return _failure("READER_MISSING_WALKING_STEP")
	var sessions := {}
	for session in arm.get("walking_sessions", []):
		sessions[session["session_id"]] = session
	var cycle_memory := CycleStop.initial_v1()
	var cycle_rows: Array = report.get("development_cycle_stop", {}).get("rows", [])
	if CycleStop.selected_policy_v1(development_policy_id) and cycle_rows.size() != rows.size():
		return _failure("READER_CYCLE_POPULATION")
	var previous_output_by_session := {}
	var adapter_transition_count := 0
	for index in range(rows.size()):
		var row: Variant = rows[index]
		if not (row is Dictionary) or row.get("schema_version") != _contract["step_schema"]:
			return _failure("READER_ROW_SHAPE")
		var post: Dictionary = expected[index]
		var local_step := int(post["walking_session_local_step"])
		var session: Dictionary = sessions.get(post["walking_session_id"], {})
		if policy["development"]:
			var start: Dictionary = session.get("start_receipt", {})
			if not Policy.FiniteRoute.segment_selected_v1(development_policy_id, session.get("evaluation_segment_id", "")) or start.get("development_walking_policy_id") != development_policy_id or start.get("selected_policy_id") != policy["policy_id"] or start.get("selected_policy_digest") != policy["policy_digest"]:
				return _failure("READER_POLICY_SESSION_CROSSED")
		if row.get("commanded_global_step") != post["global_semantic_step"] or row.get("measured_global_step") != int(post["global_semantic_step"]) - 1 or row.get("session_local_step") != local_step or row.get("session_id") != post["walking_session_id"]:
			return _failure("READER_STEP_LINK")
		if session.get("step_receipt_sha256s", []).size() < local_step or row.get("full_step_receipt_sha256") != session["step_receipt_sha256s"][local_step - 1]:
			return _failure("READER_FULL_STEP_LINK")
		var stopping: bool = CycleStop.selected_policy_v1(development_policy_id) and CycleStop.stopping_v1(cycle_memory)
		if CycleStop.selected_policy_v1(development_policy_id) and row.get("development_cycle_stopping") != stopping:
			return _failure("READER_STOP_COMMAND_BOUNDARY")
		var request: Variant = row.get("request")
		if not (request is Dictionary) or request.get("state", {}).get("semantic_step") != local_step or request.get("command", {}).get("gait_amplitude") != (0.0 if stopping else amplitude_v1(local_step, id)) or request.get("command", {}).get("phase_progression_mode") != phase_mode_v1(local_step, id):
			return _failure("READER_COMMAND_SCHEDULE")
		if CycleStop.selected_policy_v1(development_policy_id) and request.get("command", {}).get("desired_planar_velocity_task_m_s") != {"x": 0.0 if stopping else 0.2, "y": 0.0, "z": 0.0}:
			return _failure("READER_STOP_SPEED")
		if Policy.floor_selected_v1(development_policy_id):
			var source: Dictionary = row.get("development_floor_source", {})
			var start: Dictionary = session.get("start_receipt", {})
			if not Floor.verify_v1(sdk, source, arm.get("model_instance_id", "")) or start.get("model_instance_id") != arm.get("model_instance_id") or Transport.stringify(start.get("development_floor_source")) != Transport.stringify(source):
				return _failure("FLOOR_SOURCE_OR_MODEL_CROSSED")
			if request.get("schema_version") != ("sporespore_balanced_wave_policy_session_step_request_v3" if Policy.measured_body_selected_v1(development_policy_id) else "sporespore_balanced_wave_policy_session_step_request_v2") or Transport.stringify(request.get("floor_reference")) != Transport.stringify(source["floor_reference"]) or not Floor.applicable_v1(source, request.get("state", {}), floor_geometry):
				return _failure("FLOOR_REQUEST_OR_EXTENT_CROSSED")
		elif row.has("development_floor_source") or request.has("floor_reference"):
			return _failure("UNSELECTED_FLOOR_CONTEXT")
		if not (row.get("ordered_body_states") is Array) or row["ordered_body_states"].size() != 9 or not (row.get("ordered_motor_applications") is Array) or row["ordered_motor_applications"].size() != 8:
			return _failure("READER_OBSERVATION_POPULATION")
		if Policy.measured_body_selected_v1(development_policy_id) and not MeasuredBody.retained_valid_v1(request, row["ordered_body_states"]):
			return _failure("READER_MEASURED_BODY_SOURCE")
		if previous_output_by_session.has(row["session_id"]):
			var previous: Dictionary = previous_output_by_session[row["session_id"]]
			if memory_transition_profile.is_empty():
				if Transport.stringify(request.get("memory")) != Transport.stringify(previous["next_memory"]):
					return _failure("READER_MEMORY_CHAIN")
			else:
				var transition := MemoryTransition.verify_v1(previous, request, local_step)
				if transition.get("ok") != true:
					return transition
				adapter_transition_count += int(transition["adapter_mode_transition_count"])
		var pure: Dictionary = request.duplicate(true)
		pure["schema_version"] = "sporespore_balanced_wave_policy_step_request_v3" if Policy.measured_body_selected_v1(development_policy_id) else "sporespore_balanced_wave_policy_step_request_v2" if Policy.floor_selected_v1(development_policy_id) else "sporespore_balanced_wave_policy_step_request_v1"
		pure["descriptor"] = report["configuration"]["base_descriptor"]
		pure["policy_id"] = policy["policy_id"]
		var raw_response: String = sdk.balanced_wave_policy_step_json(Transport.stringify(pure))
		if "sha256:" + raw_response.sha256_text() != row.get("raw_native_response_sha256"):
			return _failure("READER_RAW_NATIVE_RESPONSE_MISMATCH")
		# Match the production adapter's post-verification decoder exactly. Its
		# parsed numeric representation is not the raw native response authority;
		# the pre-parse byte digest above verifies that distinct boundary.
		var response: Variant = sdk.decode_exact_json_v1(raw_response) if policy["policy_id"] in [Policy.JOINT_HEIGHT_POLICY_ID, Policy.EXTENDED_TRANSFER_POLICY_ID, Policy.BOUNDED_STOP_POLICY_ID, Policy.ZERO_BRAKE_POLICY_ID, Policy.INITIALIZED_BRAKE_POLICY_ID, Policy.EXTENDED_PREPARATION_POLICY_ID] else JSON.parse_string(raw_response)
		if not (response is Dictionary) or response.get("ok") != true or Transport.stringify(response.get("value")) != Transport.stringify(row.get("native_output")):
			var failure := _failure("READER_NATIVE_OUTPUT_MISMATCH")
			failure["row_index"] = index
			failure["native_response"] = response
			return failure
		previous_output_by_session[row["session_id"]] = response["value"]
		var commands: Array = response["value"]["actuation"]["ordered_commands"]
		for joint_index in range(commands.size()):
			var command: Dictionary = commands[joint_index]
			var applied: Dictionary = row["ordered_motor_applications"][joint_index]
			if applied.get("actuator_id") != command.get("actuator_id") or applied.get("host_applied_target_velocity_rad_s") != command.get("target_velocity_rad_s"):
				return _failure("READER_MOTOR_COMMAND_LINK")
		if CycleStop.selected_policy_v1(development_policy_id):
			var cycle_row: Dictionary = cycle_rows[index]
			var source: Dictionary = cycle_row.get("post_native_source", {})
			if cycle_row.get("session_local_step") != local_step or cycle_row.get("full_step_receipt_sha256") != row.get("full_step_receipt_sha256") or Transport.stringify(source.get("precommand_trace")) != Transport.stringify(post) or not NativeContacts.source_valid_v1(sdk, source, int(post["global_semantic_step"]) + 1, arm["model_instance_id"], arm["body_population_instance_sha256"]):
				return _failure("READER_CYCLE_POST_SOURCE")
			var advanced := CycleStop.advance_v1(cycle_memory, row, source)
			if advanced.get("ok") != true or Transport.stringify(advanced) != Transport.stringify(cycle_row.get("advance_receipt")):
				return _failure("READER_CYCLE_TRANSITION")
			cycle_memory = advanced["next_memory"]
	if CycleStop.selected_policy_v1(development_policy_id):
		var retained_cycle: Dictionary = report.get("development_cycle_stop", {})
		if retained_cycle.get("schema_version") != CycleStop.retention_schema_v1(development_policy_id) or retained_cycle.get("physical_acceptance_authority") != false or retained_cycle.get("release_authority") != false or Transport.stringify(retained_cycle.get("final_memory")) != Transport.stringify(cycle_memory):
			return _failure("READER_CYCLE_FINAL_MEMORY")
		if String(report.get("stop_reason", "")).begins_with("diagnostic_cycle_aligned_") and report["stop_reason"] != CycleStop.stop_reason_v1(cycle_memory):
			return _failure("READER_CYCLE_EARLY_STOP")
	var result := {"ok": true, "replayed_walking_steps": rows.size(), "additional_native_physics_read_count": 0,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
	if CycleStop.selected_policy_v1(development_policy_id):
		result["cycle_stop_final_memory"] = cycle_memory
		result["final_30_stop_commands_settled"] = cycle_memory["stopping_commands"] == CycleStop.STOP_STEPS and cycle_memory["consecutive_settled_commands"] >= CycleStop.SETTLED_STEPS
	if not memory_transition_profile.is_empty():
		result["memory_transition_profile_id"] = memory_transition_profile
		result["adapter_mode_transition_count"] = adapter_transition_count
	return result

static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": "DEVELOPMENT_WALKING_ENTRY_" + code}
