extends RefCounted
## Cold source and command replay. This consumer never constructs a world.
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_stance_entry_route_v1.gd")
const Source := preload("res://sdk/adapters/godot/gdscript/recovery_walking_entry_source_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const Facade := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd")

static func _same(a: Variant, b: Variant) -> bool:
	return Transport.stringify(a) == Transport.stringify(b)

static func _sha(sdk: Object, value: Variant) -> String:
	return Runtime.canonicalize(sdk, value).get("sha256", "")

static func measurement_v1(sdk: Object, retained: Dictionary, trace: Dictionary, compiled: Dictionary, model: String, population: String, selected: String = Route.ID) -> Dictionary:
	var packet: Dictionary = retained.get("packet", {})
	var native: Dictionary = packet.get("native_source", {})
	if not _same(native.get("precommand_trace"), trace): return _failure("TRACE_SOURCE")
	var projected := Source.project_v1(sdk, packet, int(trace.get("global_semantic_step", -1)), model, population)
	if projected.get("ok") != true or not _same(projected, retained.get("projection")): return _failure("SOURCE_PROJECTION")
	var ready := Route.Readiness.measure_v1(projected.request, native.observation.center_of_mass, compiled, Route.task_for_v1(selected).stance_entry)
	if not ready.has("ready") or not _same(ready, retained.get("readiness")) or _sha(sdk, ready) != retained.get("readiness_sha256"):
		return _failure("READINESS_RECOMPUTATION")
	if retained.get("ok") != true or retained.get("new_world_count") != 0 or retained.get("new_solver_step_count") != 0 or retained.get("physics_state_modified") != false:
		return _failure("SOURCE_SIDE_EFFECTS")
	return {"ok": true, "readiness": ready, "readiness_sha256": _sha(sdk, ready)}

static func neutral_command_v1(sdk: Object, row: Dictionary, trace: Dictionary, session: Dictionary, descriptor: Dictionary, previous: Dictionary, selected: String = Route.ID) -> Dictionary:
	var step: Dictionary = row.get("step", {})
	var local: int = trace.get("walking_session_local_step", -1)
	var global: int = trace.get("global_semantic_step", -1)
	var start: Dictionary = session.get("start_receipt", {})
	var hold: bool = Route.hold_selected_v1(selected) and session.get("evaluation_segment_id") == Route.HOLD_SEGMENT
	var flexed: bool = Route.ramped_selected_v1(selected) and not hold
	var policy := Facade.DevelopmentWalkingPolicy.STARTUP_VELOCITY_POLICY_ID if hold else Route.FLEXED_NATIVE_ID if flexed else "sporespore_balanced_wave_bw5r_b_v1"
	var segment := Route.HOLD_SEGMENT if hold else Route.SEGMENT
	var alias := Route.hold_alias_for_v1(selected) if hold else Route.entry_selection_for_v1(selected)
	if local < 1 or local > 240 or session.get("step_receipt_sha256s", []).size() < local: return _failure("COMMAND_POPULATION")
	if row.get("segment_id") != segment or _sha(sdk, step) != row.get("full_step_receipt_sha256") or row.get("full_step_receipt_sha256") != session.step_receipt_sha256s[local-1]: return _failure("COMMAND_DIGEST")
	if step.get("ok") != true or step.get("session_id") != session.get("session_id") or step.get("session_id") != trace.get("walking_session_id") or step.get("global_semantic_step") != global or step.get("session_local_step") != local or step.get("segment_id") != "walking_resume": return _failure("COMMAND_CLOCK")
	if (start.get("selected_policy_id") != policy or start.get("global_start_step") != global-local
		or (start.get("development_walking_policy_id") != alias if (flexed or hold) else start.has("development_walking_policy_id"))): return _failure("SESSION_SELECTION")
	if hold:
		var hold_binding := Facade.DevelopmentWalkingPolicy.binding_v1(alias, Route.HOLD_SEGMENT)
		if hold_binding.is_empty() or start.get("selected_policy_digest") != hold_binding.get("policy_digest") or start.get("controller_profile_sha256") != Facade.DevelopmentWalkingPolicy.contract_for_v1(alias).native_profile_sha256: return _failure("HOLD_SESSION_IDENTITY")
	if flexed:
		var binding := Facade.DevelopmentWalkingPolicy.binding_v1(alias, Route.SEGMENT)
		if start.get("selected_policy_digest") != binding.get("policy_digest") or start.get("controller_profile_sha256") != Facade.DevelopmentWalkingPolicy.contract_for_v1(alias).native_profile_sha256: return _failure("ENTRY_POLICY_BINDING")
	var request: Dictionary = step.get("sample_receipt", {}).get("request", {})
	if request.get("state", {}).get("semantic_step") != local or request.get("command", {}).get("gait_amplitude") != 0.0 or request.get("command", {}).get("phase_progression_mode") != "contact_gated": return _failure("NEUTRAL_SCHEDULE")
	if (flexed or hold) and (not _same(request.command.get("desired_planar_velocity_task_m_s"), {"x": 0.0, "y": 0.0, "z": 0.0}) or request.command.get("desired_yaw_rate_rad_s") != null): return _failure("ENTRY_STATIONARY_COMMAND")
	if hold and (not request.has("measured_body_frame") or not request.has("floor_reference")): return _failure("HOLD_REQUEST_SHAPE")
	var lateral: Variant = start.get("task_frame_lateral_axis_world_host_real")
	if not (lateral is Array) or lateral.size() != 3: return _failure("NEUTRAL_FRAME_SOURCE")
	var axes := Facade.neutral_task_frame_axes_v1(Vector3(lateral[0], lateral[1], lateral[2]))
	for axis in axes:
		if not _same(axes[axis], request.get("state", {}).get("task_frame", {}).get(axis)): return _failure("NEUTRAL_FRAME_AXES")
	var memory := previous.duplicate(true)
	if local == 1:
		var envelope: Variant = JSON.parse_string(sdk.balanced_wave_policy_initial_memory_json(Transport.stringify({"schema_version": "sporespore_balanced_wave_policy_initial_memory_request_v1", "descriptor": descriptor, "policy_id": policy})))
		if not (envelope is Dictionary) or envelope.get("ok") != true: return _failure("NATIVE_INITIALIZATION")
		memory = envelope.value
		for limb in memory.ordered_limb_memory:
			if not start.get("initial_gait_steps", {}).has(limb.limb_id): return _failure("INITIAL_PHASE")
			limb.gait_step = start.initial_gait_steps[limb.limb_id]
			limb.evidence_gait_step_limit = limb.gait_step + 1440
		memory.held_path_steering_fraction = 0.0
	if not _same(memory, request.get("memory")): return _failure("FRESH_MEMORY_OR_CHAIN")
	var pure := request.duplicate(true)
	pure.schema_version = "sporespore_balanced_wave_policy_step_request_v3" if hold else "sporespore_balanced_wave_policy_step_request_v1"
	pure["descriptor"] = descriptor
	pure["policy_id"] = policy
	var raw: String = sdk.balanced_wave_policy_step_json(Transport.stringify(pure))
	# The production adapter parses V50 hold responses with the generic parser; compare the same projection.
	var response: Variant = sdk.decode_exact_json_v1(raw) if flexed else JSON.parse_string(raw)
	var portable: Dictionary = step.get("portable_step_receipt", {})
	if "sha256:"+raw.sha256_text() != portable.get("native_step_transport_verification", {}).get("raw_native_response_sha256") or not (response is Dictionary) or response.get("ok") != true or not _same(response.get("value"), portable.get("native_output")): return _failure("NATIVE_RESPONSE")
	var handoff: Dictionary = step.get("walking_actuation_handoff_receipt", {})
	if handoff.get("evaluation_segment_id") != "matched_continuation" or not _same(handoff, session.get("walking_actuation_handoff_receipt")): return _failure("NATIVE_FACADE_ALIAS")
	var ledger := Facade.walking_ledger_application_intent_v2(sdk, global, Route.PHASE, step.session_id, local, portable, step.get("authority_application_receipt", {}), step.get("motor_population_readback", {}), handoff, alias)
	if ledger.get("ok") != true or not _same(ledger, step.get("ledger_application_intent")) or _sha(sdk, ledger) != trace.get("application_intent_sha256"): return _failure("ACTUATION_LINK")
	return {"ok": true, "next_memory": response.value.next_memory}

static func validate_report_v1(sdk: Object, report: Dictionary, selected: String) -> Dictionary:
	if not Route.selected_v1(selected):
		return _failure("UNSELECTED_RETENTION") if report.has("stance_entry") else {"ok": true, "selected": false}
	var retained: Dictionary = report.get("stance_entry", {})
	if retained.get("schema_version") != Route.retention_schema_v1(selected) or retained.get("task_contract_sha256") != "sha256:"+FileAccess.get_sha256(Route.task_path_for_v1(selected)) or retained.get("physical_acceptance_authority") != false or retained.get("release_authority") != false: return _failure("RETENTION")
	var arm: Dictionary = report.retained_arm
	var descriptor: Dictionary = report.configuration.base_descriptor
	var compiled_raw: String = sdk.compile_bounded_quadruped_json(Transport.stringify(descriptor))
	var compiled_envelope: Variant = sdk.decode_exact_json_v1(compiled_raw) if Route.ramped_selected_v1(selected) else JSON.parse_string(compiled_raw)
	if not (compiled_envelope is Dictionary) or compiled_envelope.get("ok") != true: return _failure("COMPILED_DESCRIPTOR")
	var traces: Array = arm.trace_rows
	var transitions: Array = report.passive_entry.orchestrator_transitions
	var expected := []
	var neutral_traces := []
	var hold_traces := []
	var post_sessions := []
	var neutral_sessions := []
	var hold_sessions := []
	var hold_route := Route.hold_selected_v1(selected)
	for session in arm.get("walking_sessions", []):
		if session.get("evaluation_segment_id") == Route.SEGMENT:
			var bound := session_with_handoff_v1(arm, session, selected)
			if bound.get("ok") != true: return bound
			neutral_sessions.append(bound.session)
		elif hold_route and session.get("evaluation_segment_id") == Route.HOLD_SEGMENT:
			var bound := session_with_handoff_v1(arm, session, selected)
			if bound.get("ok") != true: return bound
			hold_sessions.append(bound.session)
		elif session.get("evaluation_segment_id") in ["walking_resume", "matched_continuation"]: post_sessions.append(session)
	for trace in traces:
		if trace.get("orchestrator_phase") == Route.PHASE:
			if hold_route and trace.get("walking_segment_id") == Route.HOLD_SEGMENT:
				expected.append({"trace": trace, "purpose": "hold_dwell"})
				hold_traces.append(trace)
			else:
				expected.append({"trace": trace, "purpose": "neutral_dwell"})
				neutral_traces.append(trace)
	# The guard is on the actual recovery-completion transition, before V50 start.
	if report.arm_id == "kick_passive_recovery_resume":
		for index in recovery_completion_indices_v1(transitions, selected):
			if index >= traces.size(): return _failure("RECOVERY_COMPLETION_TRACE")
			expected.append({"trace": traces[index], "purpose": "post_recovery_entry"})
	if not (retained.get("readiness_rows") is Array) or not (retained.get("neutral_control_rows") is Array) or expected.size() != retained.readiness_rows.size() or neutral_traces.size() != retained.neutral_control_rows.size(): return _failure("RETAINED_POPULATION")
	var hold_rows: Array = retained.get("hold_control_rows", []) if hold_route else []
	if hold_route and (not (retained.get("hold_control_rows") is Array) or hold_traces.size() != hold_rows.size()): return _failure("HOLD_RETENTION_POPULATION")
	if not hold_route and retained.has("hold_control_rows"): return _failure("UNSELECTED_HOLD_RETENTION")
	if neutral_sessions.size() != (1 if not neutral_traces.is_empty() else 0) or post_sessions.size() > 1: return _failure("SESSION_POPULATION")
	if hold_sessions.size() != (1 if not hold_traces.is_empty() else 0): return _failure("HOLD_SESSION_POPULATION")
	if not hold_traces.is_empty() and (neutral_traces.is_empty() or hold_traces[0].global_semantic_step <= neutral_traces[-1].global_semantic_step
		or neutral_sessions[0].session_id == hold_sessions[0].session_id
		or neutral_sessions[0].get("completion_receipt", {}).get("adapter_shutdown_receipt", {}).get("native_controller_session_destroy_count") != 1): return _failure("HOLD_AFTER_RAMP")
	var previous := {}
	var hold_previous := {}
	var last_ready := false
	var last_step := -1
	var neutral_index := 0
	var hold_index := 0
	for index in range(expected.size()):
		var item: Dictionary = expected[index]
		var trace: Dictionary = item.trace
		var row: Dictionary = retained.readiness_rows[index]
		var global: int = trace.global_semantic_step
		if row.get("role") != report.arm_id or row.get("purpose") != item.purpose or row.get("global_semantic_step") != global: return _failure("MEASUREMENT_IDENTITY")
		var measured := measurement_v1(sdk, row.get("source", {}), trace, compiled_envelope.value, arm.model_instance_id, arm.body_population_instance_sha256, selected)
		if measured.get("ok") != true: return measured
		last_ready = measured.readiness.ready
		last_step = global
		if item.purpose == "neutral_dwell":
			var event: Dictionary = transitions[global-1].event
			var command := neutral_command_v1(sdk, retained.neutral_control_rows[neutral_index], trace, neutral_sessions[0], descriptor, previous, selected)
			if command.get("ok") != true: return command
			neutral_index += 1
			previous = command.next_memory
			if Route.ramped_selected_v1(selected):
				var entry: Dictionary = previous.get("joint_pose_entry", {})
				if typeof(entry.get("reference_ramp_complete")) != TYPE_BOOL: return _failure("ENTRY_MEMORY")
				if hold_route:
					# R10J ramp readiness: native ramp complete with four native supports; settling belongs to the hold.
					last_ready = (entry.reference_ramp_complete and measured.readiness.checks.get("upright") == true
						and measured.readiness.checks.get("zero_bias_reference_path_feasible") == true) if selected in [Route.R10Q.ID, Route.R10R.ID, Route.R10S.ID] else (entry.reference_ramp_complete and measured.readiness.checks.get("four_native_supports", false) == true)
				else:
					last_ready = last_ready and entry.reference_ramp_complete
			if event.get("neutral_entry_readiness_sha256") != measured.readiness_sha256 or event.get("neutral_entry_ready") != last_ready: return _failure("EVENT_READINESS_LINK")
		elif item.purpose == "hold_dwell":
			var event: Dictionary = transitions[global-1].event
			if event.get("event_kind") != Route.HOLD_EVENT: return _failure("HOLD_EVENT_KIND")
			var command := neutral_command_v1(sdk, hold_rows[hold_index], trace, hold_sessions[0], descriptor, hold_previous, selected)
			if command.get("ok") != true: return command
			hold_index += 1
			hold_previous = command.next_memory
			if event.get("neutral_entry_readiness_sha256") != measured.readiness_sha256 or event.get("neutral_entry_ready") != last_ready: return _failure("EVENT_READINESS_LINK")
	if hold_route and report.arm_id == "matched_no_kick_continuation" and not post_sessions.is_empty() and hold_traces.is_empty(): return _failure("WALKING_WITHOUT_HOLD")
	if not post_sessions.is_empty():
		if not last_ready or last_step != post_sessions[0].start_receipt.global_start_step: return _failure("WALKING_STARTED_WITHOUT_READY_ENTRY")
		for session in neutral_sessions + hold_sessions:
			if session.session_id == post_sessions[0].session_id or session.get("completion_receipt", {}).get("adapter_shutdown_receipt", {}).get("native_controller_session_destroy_count") != 1: return _failure("SESSION_NOT_FRESH")
	elif report.get("stop_reason") == "diagnostic_walking_entry_not_ready":
		if report.arm_id != "kick_passive_recovery_resume" or expected.size() != 1 or last_ready: return _failure("FALSE_ENTRY_NEGATIVE")
	return {"ok": true, "selected": true, "replayed_neutral_commands": neutral_traces.size(), "replayed_hold_commands": hold_traces.size(), "recomputed_readiness_samples": expected.size(), "world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}

static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": "R10H_ENTRY_REPLAY_"+code}

static func session_with_handoff_v1(arm: Dictionary, session: Dictionary, selected: String) -> Dictionary:
	var local_session := session.duplicate(true)
	if Route.ramped_selected_v1(selected):
		var matches: Array = arm.get("walking_actuation_handoff_receipts", []).filter(func(h): return h is Dictionary and h.get("walking_session_id") == session.get("session_id"))
		if matches.size() != 1: return _failure("HANDOFF_POPULATION")
		local_session["walking_actuation_handoff_receipt"] = matches[0]
	return {"ok": true, "session": local_session}

static func recovery_completion_indices_v1(transitions: Array, selected: String) -> Array:
	var result := []
	var resume_phase := "fresh_selected_policy_walking_resume" if Route.ramped_selected_v1(selected) else "walking_resume"
	for index in range(transitions.size()):
		var transition: Dictionary = transitions[index]
		if transition.get("advance", {}).get("next_phase") == resume_phase and transition.get("event", {}).get("source_phase") != resume_phase:
			result.append(index)
	return result
