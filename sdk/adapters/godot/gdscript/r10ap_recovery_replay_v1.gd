extends RefCounted
# gdlint: disable=max-line-length

## Independent consumer of serialized worker records. Calls only pure source
## validators, scheduler kernels and compiled controller APIs; never a worker,
## model constructor, native sampler, motor writer or physics step.
const StanceEntryReplay := preload("res://sdk/adapters/godot/gdscript/r10v_stance_entry_replay_v1.gd")
const Entry := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_orchestrator_v1.gd")
const Stage := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_stage_v1.gd")
const Canonical := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_recovery_advance_stage_v1.gd")
const Facade := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd")
const World := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const Bytes := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_transport_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const RETENTION_SCHEMA := "sporespore_development_measured_prone_entry_retention_v1"
const INPUT_SCHEMA := "sporespore_development_passive_entry_replay_input_v1"
const REPORT_INPUT_SCHEMA := "sporespore_development_passive_entry_report_replay_input_v1"
const Rearward := preload("res://sdk/adapters/godot/gdscript/development_rearward_fold_profile_v1.gd")
const RateLimited := preload("res://sdk/adapters/godot/gdscript/development_rate_limited_recovery_profile_v1.gd")
const CandidateProfile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const R10AP := preload("res://sdk/adapters/godot/gdscript/r10ap_recovery_orchestrator_v1.gd")
const UprightBridge := preload("res://sdk/adapters/godot/gdscript/r10r_upright_recovery_stage_v1.gd")
const PartialBridge := preload("res://sdk/adapters/godot/gdscript/r10ap_partial_recovery_stage_v1.gd")


static func selection_v1(controller_id: String = Canonical.Route.RECOVERY_CONTROLLER_V6_ID,
	candidate_selection: Dictionary = {}) -> Dictionary:
	if (_route_id_v1(candidate_selection) != R10AP.ROUTE
		or controller_id != R10AP.CONTROLLER or candidate_selection.get("post_kick_controller_id") != controller_id): return {}
	var selected := candidate_selection.duplicate(true)
	selected["retention_schema"] = "sporespore_r10ap_recovery_entry_retention_v1"
	selected["input_schema"] = "sporespore_r10ap_recovery_replay_input_v1"
	selected["report_input_schema"] = "sporespore_r10ap_recovery_report_replay_input_v1"
	selected["replay_receipt_schema"] = "sporespore_r10ap_recovery_replay_receipt_v1"
	return selected


## The enclosing smoke audit checks launch/source/runtime/file provenance. This
## boundary additionally requires the complete report's timeline to start at
## fresh initialization, not at a caller-selected convenient checkpoint.
static func replay_report_v1(sdk: Object, report: Dictionary, expected_runtime_binding: Dictionary,
	controller_id: String = Canonical.Route.RECOVERY_CONTROLLER_V6_ID, candidate_selection: Dictionary = {}, memory_transition_profile: String = "") -> Dictionary:
	var selection := selection_v1(controller_id, candidate_selection)
	var bounds := CandidateProfile.limits_v1(candidate_selection)
	if not candidate_selection.is_empty() and not _same(report.get("candidate_profile"), candidate_selection.get("candidate_profile")):
		return _failure("CANDIDATE_REPORT_PROFILE_CROSSED")
	if (selection.is_empty() or not _same(report.get("schema_version"), selection["worker_selection"]["report_schema"])
		or not _same(report.get("work_id"), selection["worker_selection"]["work_id"])):
		return _failure("REPORT_SCHEMA_OR_WORK")
	for key in ["configuration", "retained_arm", "passive_entry"]:
		if not (report.get(key) is Dictionary):
			return _failure("REPORT_SOURCE_MISSING:" + key)
	for key in ["arm_id", "child_attempt_id"]:
		if not (report.get(key) is String):
			return _failure("REPORT_IDENTITY_KIND:" + key)
	var arm: Dictionary = report["retained_arm"]
	var retained: Dictionary = report["passive_entry"]
	var start_id := CandidateProfile.walking_start_id_v1(candidate_selection, "walking_resume")
	var start_replay := CandidateProfile.WalkingStart.validate_report_v1(report, start_id)
	if start_replay.get("ok") != true:
		return start_replay
	var policy_replay := CandidateProfile.WalkingPolicy.validate_report_v1(report, _route_id_v1(candidate_selection))
	if policy_replay.get("ok") != true:
		return policy_replay
	if not CandidateProfile.WalkingFrame.report_selection_valid_v1(arm,
		CandidateProfile.walking_frame_id_v1(candidate_selection, "walking_resume"), _route_id_v1(candidate_selection)):
		return _failure("REPORT_WALKING_FRAME_SELECTION_CROSSED")
	if (not (arm.get("model_instance_id") is String) or not (arm.get("body_population_instance_sha256") is String)
		or not (arm.get("orchestrator_state") is Dictionary) or not (arm.get("trace_rows") is Array)
		or not (retained.get("orchestrator_transitions") is Array)):
		return _failure("REPORT_ARM_SHAPE")
	if (not _same(retained.get("maximum_passive_descent_steps"), 240)
		or not _same(retained.get("after_interaction_steps"), bounds["after_interaction_steps"])
		or typeof(report.get("solver_step_count")) != TYPE_INT
		or report["solver_step_count"] < 1 or report["solver_step_count"] > bounds["maximum_steps_per_child"]
		or arm["trace_rows"].size() != report["solver_step_count"]
		or retained["orchestrator_transitions"].size() != report["solver_step_count"]):
		return _failure("REPORT_PROFILE_OR_STEP_POPULATION")
	var stance_entry_replay := StanceEntryReplay.validate_report_v1(sdk, report, _route_id_v1(candidate_selection))
	if stance_entry_replay.get("ok") != true: return stance_entry_replay
	var walking_replay := CandidateProfile.WalkingEntry.validate_report_v1(sdk, report,
		CandidateProfile.walking_entry_id_v1(candidate_selection, "walking_resume"), memory_transition_profile,
		_route_id_v1(candidate_selection))
	if walking_replay.get("ok") != true:
		return walking_replay
	var contact_id := CandidateProfile.walking_contact_id_v1(candidate_selection, "walking_resume")
	if not CandidateProfile.NativeWalkingContacts.selected_v1(contact_id) and report.has("development_native_walking_contacts"):
		return _failure("UNSELECTED_NATIVE_CONTACT_RETENTION")
	var contact_replay := (CandidateProfile.NativeWalkingContacts.validate_report_v1(sdk, report, _route_id_v1(candidate_selection))
		if CandidateProfile.NativeWalkingContacts.selected_v1(contact_id)
		else CandidateProfile.WalkingContacts.validate_report_v1(report, contact_id))
	if contact_replay.get("ok") != true:
		return contact_replay
	var entry_index := 0
	var canonical_index := 0
	var partial_index := 0
	var upright_index := 0
	var r10v_selected := _route_id_v1(candidate_selection) in [R10AP.ROUTE]
	for index in range(arm["trace_rows"].size()):
		var row: Variant = arm["trace_rows"][index]
		var transition: Variant = retained["orchestrator_transitions"][index]
		if not (row is Dictionary) or not (transition is Dictionary) or not (transition.get("event") is Dictionary):
			return _failure("REPORT_STEP_SOURCE_SHAPE")
		var event: Dictionary = transition["event"]
		if (not _same(row.get("global_semantic_step"), index + 1)
			or not _same(row.get("arm_id"), report["arm_id"])
			or not _same(row.get("application_intent_sha256"), event.get("application_intent_sha256"))
			or not _same(row.get("orchestrator_phase"), event.get("source_phase"))):
			return _failure("REPORT_TRACE_EVENT_LINK")
		var classification: Variant = null
		if event.get("source_phase") == Entry.PHASE_DESCENT:
			var packets: Variant = retained.get("entry_packets")
			if not (packets is Array) or entry_index >= packets.size() or not (packets[entry_index] is Dictionary):
				return _failure("REPORT_ENTRY_CLASSIFICATION_SOURCE")
			classification = packets[entry_index].get("original_passive_receipt" if r10v_selected else "entry_receipt", {}).get("classification")
			entry_index += 1
		elif r10v_selected and event.get("source_phase") == R10AP.PHASE_PARTIAL:
			var packets: Variant = report.get("r10ap_partial_recovery", {}).get("step_packets")
			if not (packets is Array) or partial_index >= packets.size() or not (packets[partial_index] is Dictionary):
				return _failure("REPORT_PARTIAL_CLASSIFICATION_SOURCE")
			classification = packets[partial_index].get("native_receipt", {}).get("step", {}).get("classification")
			partial_index += 1
		elif r10v_selected and event.get("source_phase") == R10AP.PHASE_UPRIGHT:
			var packets: Variant = report.get("r10v_upright_recovery", {}).get("step_packets")
			if not (packets is Array) or upright_index >= packets.size() or not (packets[upright_index] is Dictionary):
				return _failure("REPORT_UPRIGHT_CLASSIFICATION_SOURCE")
			classification = packets[upright_index].get("native_receipt", {}).get("step", {}).get("classification")
			upright_index += 1
		elif event.get("source_phase") in [Entry.Prior.PHASE_CONFIRM_PRONE, Entry.Prior.PHASE_POST_KICK_RECOVERY]:
			var packets: Variant = retained.get("canonical_packets")
			if not (packets is Array) or canonical_index >= packets.size() or not (packets[canonical_index] is Dictionary):
				return _failure("REPORT_CANONICAL_CLASSIFICATION_SOURCE")
			classification = packets[canonical_index].get("step_receipt", {}).get("classification")
			canonical_index += 1
		if classification != null and not _same(classification, row.get("recovery_classification")):
			return _failure("REPORT_TRACE_CLASSIFICATION_LINK")
	var initialized := (R10AP.initialize_v1(sdk, report["child_attempt_id"], report["arm_id"],
		arm["model_instance_id"], _sha(sdk, report["configuration"]), arm["body_population_instance_sha256"])
		if r10v_selected else Entry.initialize_v1(sdk, report["child_attempt_id"], report["arm_id"],
		arm["model_instance_id"], _sha(sdk, report["configuration"]), arm["body_population_instance_sha256"], 240, controller_id, _route_id_v1(candidate_selection)))
	if initialized.get("ok") != true:
		return _failure("REPORT_INITIALIZATION")
	var context := Canonical.Route.prepare_complete_energy_context_v18(sdk, Canonical.Route.RECOVERY_CONTROLLER_V6_ID)
	if context.get("ok") != true:
		return _failure("REPORT_CONTEXT")
	var result := replay_v1(sdk, {"schema_version": selection["input_schema"], "initial_state": initialized["state"],
		"final_state": arm["orchestrator_state"], "context": context, "retention": retained,
		"partial_retention": report.get("r10ap_partial_recovery", {}),
		"upright_retention": report.get("r10v_upright_recovery", {}),
		"post_recovery_settling": report.get("post_recovery_settling", {})}, expected_runtime_binding, controller_id, candidate_selection)
	if result.get("ok") != true:
		return result
	var final_state: Dictionary = arm["orchestrator_state"]
	if final_state["precondition_recovery_step_count"] > 320 or final_state["recovery_epoch_step_count"] > bounds["after_interaction_steps"]:
		return _failure("REPORT_PHASE_BUDGET")
	result["ledger_scope"]["authority_mode"] = "independent_retained_report_replay"
	result["complete_report_timeline_replayed"] = true
	if stance_entry_replay.get("selected") == true: result["stance_entry_replay"] = stance_entry_replay
	if CandidateProfile.WalkingPolicy.FiniteRoute.selected_v1(_route_id_v1(candidate_selection)):
		var task := CandidateProfile.WalkingPolicy.FiniteRoute.task_boundary_v1(report, walking_replay.get("cycle_stop_final_memory", {}), _route_id_v1(candidate_selection))
		if not _same(report.get("finite_recovery_task"), task) or task["role_and_budget_valid"] != true:
			return _failure("FINITE_TASK_BOUNDARY_OR_ROLE_BUDGET")
		result["finite_recovery_task"] = task

	if not start_id.is_empty():
		result["walking_start_validation"] = start_replay
	if not _route_id_v1(candidate_selection).is_empty():
		result["walking_policy_validation"] = policy_replay
	if not CandidateProfile.walking_entry_id_v1(candidate_selection, "walking_resume").is_empty():
		result["walking_control_replay"] = walking_replay
	if not CandidateProfile.walking_contact_id_v1(candidate_selection, "walking_resume").is_empty():
		result["walking_contact_validation"] = contact_replay
	return result


static func replay_v1(sdk: Object, input: Dictionary, expected_runtime_binding: Dictionary,
	controller_id: String = Canonical.Route.RECOVERY_CONTROLLER_V6_ID, candidate_selection: Dictionary = {}) -> Dictionary:
	var walking_policy_id := _route_id_v1(candidate_selection)
	var r10v_selected := walking_policy_id in [R10AP.ROUTE]
	var selection := selection_v1(controller_id, candidate_selection)
	var bounds := CandidateProfile.limits_v1(candidate_selection)
	if selection.is_empty() or input.get("schema_version") != selection["input_schema"]:
		return _failure("INPUT_SCHEMA")
	for key in ["retention", "initial_state", "final_state", "context"]:
		if not (input.get(key) is Dictionary):
			return _failure("INPUT_MISSING:" + key)
	var retained: Dictionary = input["retention"]
	if not candidate_selection.is_empty() and not _same(retained.get("candidate_profile"), candidate_selection.get("candidate_profile")):
		return _failure("CANDIDATE_RETENTION_PROFILE_CROSSED")
	if expected_runtime_binding.is_empty() or not _same(retained.get("runtime_binding"), expected_runtime_binding):
		return _failure("RETAINED_RUNTIME_BINDING_CROSSED")
	if not _same(retained.get("schema_version"), selection["retention_schema"]):
		return _failure("RETENTION_SCHEMA")
	for key in ["canonical_initialization_permitted_before_prone", "energy_epoch_reset_permitted_at_handoff",
		"physical_acceptance_authority", "release_authority"]:
		if not _same(retained.get(key), false):
			return _failure("FORBIDDEN_PERMISSION:" + key)
	for key in ["entry_packets", "canonical_packets", "orchestrator_transitions"]:
		if not (retained.get(key) is Array):
			return _failure("PACKET_POPULATION:" + key)
	if not (retained.get("first_recovery_owned_application") is Dictionary):
		return _failure("FIRST_APPLICATION_MISSING")
	var state: Dictionary = input["initial_state"].duplicate(true)
	var final_state: Dictionary = input["final_state"]
	if not _state_valid_v1(sdk, state, controller_id, walking_policy_id) or not _state_valid_v1(sdk, final_state, controller_id, walking_policy_id):
		return _failure("ENDPOINT_STATE_INVALID")
	if not _same(state["maximum_passive_descent_steps"], retained.get("maximum_passive_descent_steps")):
		return _failure("DESCENT_LIMIT_CROSSED")
	if (not _same(retained.get("after_interaction_steps"), bounds["after_interaction_steps"])
		or final_state["previous_global_semantic_step"] > bounds["maximum_steps_per_child"]):
		return _failure("DIAGNOSTIC_LIMIT_CROSSED")
	var transitions: Array = retained["orchestrator_transitions"]
	if transitions.size() != final_state["previous_global_semantic_step"] - state["previous_global_semantic_step"]:
		return _failure("TRANSITION_POPULATION_INCOMPLETE")
	var context: Dictionary = input["context"]
	var canonical_context: Dictionary = context
	var rearward_selected := controller_id == Canonical.Route.RECOVERY_CONTROLLER_V7_ID
	var rate_limited_selected := controller_id == Canonical.Route.RECOVERY_CONTROLLER_V8_ID
	var candidate_selected := not candidate_selection.is_empty()
	if rearward_selected or rate_limited_selected or candidate_selected:
		if (not _same(retained.get("setup_controller_id"), Canonical.Route.RECOVERY_CONTROLLER_V6_ID)
			or not _same(retained.get("post_kick_controller_id"), controller_id)
			or not (retained.get("post_kick_controller_context") is Dictionary)):
			return _failure("REARWARD_CONTROLLER_SELECTION")
		canonical_context = retained["post_kick_controller_context"]
		if retained["canonical_packets"].is_empty():
			if not canonical_context.is_empty():
				return _failure("REARWARD_CONTEXT_BEFORE_CANONICAL_ADVANCE")
		elif (not (Canonical.Route.development_candidate_context_binding_exact_v1(sdk, canonical_context, controller_id)
			if candidate_selected else (Canonical.Route.rate_limited_recovery_context_binding_exact_v1(sdk, canonical_context)
			if rate_limited_selected else Canonical.Route.rearward_fold_context_binding_exact_v1(sdk, canonical_context)))
			or canonical_context.get("source_native_context_sha256") != _sha(sdk, context)):
			return _failure("REARWARD_CONTEXT_ANCESTRY")
	var prior_entry := {}
	var handoff := {}
	var memory := {}
	var control := {}
	var previous_bound := {}
	var entry_count := 0
	var canonical_count := 0
	var partial_count := 0
	var partial_memory := {}
	var partial_declaration := {}
	var partial_source := {}
	var partial_retained: Variant = input.get("partial_retention", {})
	if r10v_selected:
		if not _partial_retention_valid_v1(partial_retained): return _failure("PARTIAL_RETENTION_SHAPE_OR_AUTHORITY")
	elif not (partial_retained is Dictionary) or not partial_retained.is_empty():
		return _failure("UNSELECTED_PARTIAL_RETENTION")
	var settling_retained: Variant = input.get("post_recovery_settling", {})
	if not (settling_retained is Dictionary): return _failure("SETTLING_RETENTION_SHAPE")
	var settling_count := 0
	var completion_readiness_count := 0
	var compiled := sdk.decode_exact_json_v1(sdk.compile_bounded_quadruped_json(Transport.stringify(Facade.RecoveryRoute.exact_base_descriptor_v1()))) as Dictionary
	if compiled.get("ok") != true: return _failure("SETTLING_DESCRIPTOR")
	var upright_count := 0
	var upright_memory := {}
	var upright_declaration := {}
	var upright_source := {}
	var upright_retained: Variant = input.get("upright_retention", {})
	if r10v_selected:
		if not _upright_retention_valid_v1(upright_retained): return _failure("UPRIGHT_RETENTION_SHAPE_OR_AUTHORITY")
	elif not (upright_retained is Dictionary) or not upright_retained.is_empty():
		return _failure("UNSELECTED_UPRIGHT_RETENTION")
	for transition_value in transitions:
		if not (transition_value is Dictionary):
			return _failure("TRANSITION_SHAPE")
		var transition: Dictionary = transition_value
		for key in ["state_before", "event", "advance"]:
			if not (transition.get(key) is Dictionary):
				return _failure("TRANSITION_SOURCE_MISSING:" + key)
		if not _same(transition["state_before"], state):
			return _failure("TRANSITION_STATE_CHAIN")
		var event: Dictionary = transition["event"]
		if not _event_valid_v1(sdk, event, controller_id, walking_policy_id):
			return _failure("EVENT_INVALID")
		var phase: String = state["phase"]
		var step: int = state["previous_global_semantic_step"] + 1
		if phase == Entry.PHASE_DESCENT:
			if entry_count >= retained["entry_packets"].size():
				return _failure("ENTRY_PACKET_MISSING")
			var packet_value: Variant = retained["entry_packets"][entry_count]
			if not (packet_value is Dictionary):
				return _failure("ENTRY_PACKET_SHAPE")
			var packet: Dictionary = packet_value
			if not (packet.get("source_application") is Dictionary) or not (packet.get("bound_observations") is Dictionary):
				return _failure("ENTRY_PACKET_SOURCE_MISSING")
			var application: Dictionary = packet["source_application"]
			var bound: Dictionary = packet["bound_observations"]
			var checked := _application_link(sdk, state, application, bound, {}, {})
			if checked != "":
				return _failure(checked)
			checked = _epoch_link(sdk, state, bound, previous_bound)
			if checked != "":
				return _failure(checked)
			var replayed := (PartialBridge.entry_v1(sdk, context, state["attempt_id"], bound, prior_entry)
				if r10v_selected else Stage.advance_v1(sdk, context, state["attempt_id"],
				state["maximum_passive_descent_steps"], bound, prior_entry))
			replayed["source_application"] = application
			if replayed.get("ok") != true or not _same(replayed, packet):
				return _failure("ENTRY_REPLAY_OR_BYTES_MISMATCH")
			var receipt: Dictionary = replayed["original_passive_receipt" if r10v_selected else "entry_receipt"]
			var event_fields := {"event_kind": "passive_entry_observation",
				"global_semantic_step": step, "recovery_epoch_local_step": step - state["epoch_start_global_step"],
				"no_actuation_requested": true, "application_intent_sha256": _sha(sdk, application),
				"energy_initializer_sha256": state["energy_initializer_sha256"],
				"prone_sample": receipt["classification"]["entry_prone_gate"],
				"stable_four_foot_stance": receipt["classification"]["stable_stance_gate"],
				"passive_entry_receipt_sha256": _sha(sdk, receipt),
				"passive_entry_status": receipt["memory"]["status"],
				"canonical_initialization_count": receipt["canonical_initialization_count"]}
			if r10v_selected: event_fields["r10v_native_receipt"] = replayed.native_receipt
			var expected_event := _build_event_v1(sdk, state, event_fields, controller_id, walking_policy_id)
			if expected_event.get("ok") != true or not _same(expected_event["event"], event):
				return _failure("ENTRY_EVENT_NOT_FROM_RECEIPT")
			prior_entry = replayed["entry_state"]
			if receipt["canonical_memory"] is Dictionary:
				if not handoff.is_empty():
					return _failure("REPEATED_CANONICAL_INITIALIZATION")
				handoff = receipt
				memory = receipt["canonical_memory"]
			if r10v_selected and replayed.entry_kind == "partial":
				if not handoff.is_empty() or not partial_memory.is_empty(): return _failure("PARTIAL_REINITIALIZATION")
				partial_declaration = replayed.original_control_receipt.entry.partial_declaration
				partial_memory = replayed.original_control_receipt.entry.partial_memory
				partial_source = replayed.native_receipt
			if r10v_selected and replayed.entry_kind == "upright":
				if not handoff.is_empty() or not upright_memory.is_empty(): return _failure("UPRIGHT_REINITIALIZATION")
				upright_declaration = replayed.original_entry_control_receipt.entry.upright_declaration
				upright_memory = replayed.original_entry_control_receipt.entry.upright_memory
				upright_source = replayed.original_entry_control_receipt
			previous_bound = bound
			entry_count += 1
		elif r10v_selected and phase == R10AP.PHASE_PARTIAL:
			if partial_memory.is_empty() or not handoff.is_empty() or partial_count >= partial_retained.step_packets.size():
				return _failure("PARTIAL_WITHOUT_HANDOFF_OR_PACKET")
			var packet: Variant = partial_retained.step_packets[partial_count]
			if (not (packet is Dictionary) or not (packet.get("source_application") is Dictionary)
				or not (packet.get("bound_observations") is Dictionary) or not _same(packet.get("prior_memory"), partial_memory)):
				return _failure("PARTIAL_PACKET_OR_MEMORY_CHAIN")
			var application: Dictionary = packet.source_application
			var bound: Dictionary = packet.bound_observations
			var checked := _application_link(sdk, state, application, bound, partial_memory, {}, controller_id,
				int(bounds.maximum_steps_per_child), partial_source)
			if checked != "": return _failure(checked)
			checked = _epoch_link(sdk, state, bound, previous_bound)
			if checked != "": return _failure(checked)
			var replayed := PartialBridge.step_v1(sdk, context, state.attempt_id, bound, partial_declaration, partial_memory)
			replayed["source_application"] = application
			replayed["prior_memory"] = partial_memory
			if replayed.get("ok") != true or not _same(replayed, packet): return _failure("PARTIAL_REPLAY_OR_BYTES_MISMATCH")
			var native: Dictionary = replayed.native_receipt
			var receipt: Dictionary = native.step
			var terminal: bool = receipt.next_phase in ["complete", "failed"]
			var expected_event := _build_event_v1(sdk, state, {
				"event_kind": "partial_fall_controller_step", "global_semantic_step": step,
				"recovery_epoch_local_step": step - state.epoch_start_global_step,
				"control_owner": "recovery_candidate", "actuation_owner": "recovery_candidate", "recovery_actuation_applied": true,
				"application_intent_sha256": _sha(sdk, application), "energy_initializer_sha256": state.energy_initializer_sha256,
				"stable_four_foot_stance": receipt.classification.stable_stance_gate,
				"recovery_controller_terminal_phase": receipt.next_phase if terminal else "",
				"recovery_controller_terminal_reason": receipt.memory.terminal_failure_code if receipt.next_phase == "failed" else "",
				"r10v_native_receipt": native, "partial_prior_memory_sha256": _sha(sdk, partial_memory)}, controller_id, walking_policy_id)
			if expected_event.get("ok") != true or not _same(expected_event.event, event): return _failure("PARTIAL_EVENT_NOT_FROM_RECEIPT")
			if partial_count == 0 and not _same(application, partial_retained.first_partial_application): return _failure("FIRST_PARTIAL_APPLICATION_CROSSED")
			partial_memory = receipt.memory
			partial_source = native
			previous_bound = bound
			partial_count += 1
		elif r10v_selected and phase == R10AP.PHASE_UPRIGHT:
			if upright_memory.is_empty() or not handoff.is_empty() or upright_count >= upright_retained.step_packets.size():
				return _failure("UPRIGHT_WITHOUT_HANDOFF_OR_PACKET")
			var packet: Variant = upright_retained.step_packets[upright_count]
			if (not (packet is Dictionary) or not (packet.get("source_application") is Dictionary)
				or not (packet.get("bound_observations") is Dictionary) or not _same(packet.get("prior_memory"), upright_memory)):
				return _failure("UPRIGHT_PACKET_OR_MEMORY_CHAIN")
			var application: Dictionary = packet.source_application
			var bound: Dictionary = packet.bound_observations
			var checked := _application_link(sdk, state, application, bound, upright_memory, {}, UprightBridge.Source.recovery_controller_for_phase_v1(upright_memory.get("phase", "")),
				int(bounds.maximum_steps_per_child), {}, upright_source)
			if checked != "": return _failure(checked)
			checked = _epoch_link(sdk, state, bound, previous_bound)
			if checked != "": return _failure(checked)
			var replayed := UprightBridge.step_v1(sdk, context, state.attempt_id, bound, upright_declaration, upright_memory)
			replayed["source_application"] = application
			replayed["prior_memory"] = upright_memory
			if replayed.get("ok") != true or not _same(replayed, packet): return _failure("UPRIGHT_REPLAY_OR_BYTES_MISMATCH")
			var native: Dictionary = replayed.native_receipt
			var receipt: Dictionary = native.step
			var terminal: bool = receipt.next_phase in ["complete", "failed"]
			var fields := {
				"event_kind": "upright_recovery_controller_step", "global_semantic_step": step,
				"recovery_epoch_local_step": step - state.epoch_start_global_step,
				"control_owner": "recovery_candidate", "actuation_owner": "recovery_candidate", "recovery_actuation_applied": true,
				"application_intent_sha256": _sha(sdk, application), "energy_initializer_sha256": state.energy_initializer_sha256,
				"stable_four_foot_stance": receipt.classification.stable_stance_gate,
				"recovery_controller_terminal_phase": receipt.next_phase if terminal else "",
				"recovery_controller_terminal_reason": receipt.memory.terminal_failure_code if receipt.next_phase == "failed" else "",
				"r10v_native_receipt": native, "upright_prior_memory_sha256": _sha(sdk, upright_memory)}
			if receipt.next_phase == "complete":
				var source: Dictionary = settling_retained.get("entry_source", {})
				var ready := _settling_source_v1(sdk, source, compiled.value, state, step)
				if ready.get("ok") != true: return ready
				fields.post_recovery_readiness = ready.readiness
				fields.post_recovery_readiness_source_sha256 = _sha(sdk, source)
				completion_readiness_count += 1
			var expected_event := _build_event_v1(sdk, state, fields, controller_id, walking_policy_id)
			if expected_event.get("ok") != true or not _same(expected_event.event, event): return _failure("UPRIGHT_EVENT_NOT_FROM_RECEIPT")
			if upright_count == 0 and not _same(application, upright_retained.first_upright_application): return _failure("FIRST_UPRIGHT_APPLICATION_CROSSED")
			upright_memory = receipt.memory
			upright_source = native
			previous_bound = bound
			upright_count += 1
		elif phase in [Entry.Prior.PHASE_CONFIRM_PRONE, Entry.Prior.PHASE_POST_KICK_RECOVERY]:
			if handoff.is_empty() or canonical_count >= retained["canonical_packets"].size():
				return _failure("CANONICAL_WITHOUT_HANDOFF_OR_PACKET")
			var packet_value: Variant = retained["canonical_packets"][canonical_count]
			if not (packet_value is Dictionary):
				return _failure("CANONICAL_PACKET_SHAPE")
			var packet: Dictionary = packet_value
			if not _same(packet.get("global_semantic_step"), step) or not (packet.get("application") is Dictionary) or not (packet.get("collection_transport") is Dictionary):
				return _failure("CANONICAL_PACKET_STEP_OR_SOURCE")
			var transport: Dictionary = packet["collection_transport"]
			if not (transport.get("source_links") is Dictionary):
				return _failure("CANONICAL_SOURCE_LINKS_MISSING")
			var sources := {}
			for key in ["source_application", "source_memory", "bound_observation"]:
				var decoded := _source(sdk, transport["source_links"].get(key))
				if decoded.is_empty():
					return _failure("CANONICAL_SOURCE_BYTES:" + key)
				sources[key] = decoded
			var application: Dictionary = packet["application"]
			var bound: Dictionary = sources["bound_observation"]
			if not _same(application, sources["source_application"]) or not _same(memory, sources["source_memory"]):
				return _failure("CANONICAL_APPLICATION_OR_MEMORY_CHAIN")
			var owner_source: Dictionary = handoff if canonical_count == 0 else control
			var checked := _application_link(sdk, state, application, bound, memory, owner_source, controller_id, int(bounds["maximum_steps_per_child"]))
			if checked != "":
				return _failure(checked)
			checked = _epoch_link(sdk, state, bound, previous_bound)
			if checked != "":
				return _failure(checked)
			var source_arm := {"pending_application": application, "recovery_memory": memory}
			var replayed := (Canonical.advance_development_candidate_v1(sdk, canonical_context, source_arm, bound, step, controller_id)
				if candidate_selected else (Canonical.advance_rate_limited_recovery_v1(sdk, canonical_context, source_arm, bound, step)
				if rate_limited_selected else (Canonical.advance_rearward_fold_v1(sdk, canonical_context, source_arm, bound, step)
				if rearward_selected else Canonical.advance_v1(sdk, context, source_arm, bound, step))))
			if replayed.get("ok") != true:
				return _failure("CANONICAL_COMPILED_REPLAY_REFUSED")
			var advance: Dictionary = replayed["advance"]
			if (not _same(replayed["arm"]["last_recovery_collection_transport_retention"], transport)
				or not _same(advance["step_receipt"], packet.get("step_receipt"))
				or not _same(advance["next_memory"], packet.get("memory_after"))):
				return _failure("CANONICAL_REPLAY_OR_BYTES_MISMATCH")
			var classification: Dictionary = advance["step_receipt"]["classification"]
			var terminal_phase: String = advance["next_memory"]["phase"] if advance["terminal"] else ""
			var terminal_reason: String = ""
			if terminal_phase in ["failed", "refused"]:
				terminal_reason = advance["next_memory"]["terminal_failure_code"]
			var expected_event := _build_event_v1(sdk, state, {
				"event_kind": "passive_prone_observation" if phase == Entry.Prior.PHASE_CONFIRM_PRONE else "recovery_controller_step",
				"global_semantic_step": step, "recovery_epoch_local_step": step - state["epoch_start_global_step"],
				"control_owner": Entry.owner_for_phase_v1(phase, controller_id), "no_actuation_requested": application["no_actuation_requested"],
				"actuation_owner": "none" if application["no_actuation_requested"] else Entry.owner_for_phase_v1(phase, controller_id),
				"recovery_actuation_applied": not application["no_actuation_requested"],
				"application_intent_sha256": _sha(sdk, application), "energy_initializer_sha256": state["energy_initializer_sha256"],
				"prone_sample": classification["entry_prone_gate"], "stable_four_foot_stance": classification["stable_stance_gate"],
				"recovery_controller_terminal_phase": terminal_phase, "recovery_controller_terminal_reason": terminal_reason}, controller_id, walking_policy_id)
			if expected_event.get("ok") != true or not _same(expected_event["event"], event):
				return _failure("CANONICAL_EVENT_NOT_FROM_RECEIPT")
			if not (packet.get("worker_result") is Dictionary) or packet["worker_result"].get("ok") != true or not _same(packet["worker_result"].get("event_sha256"), event["payload_sha256"]):
				return _failure("CANONICAL_WORKER_RESULT")
			if canonical_count == 0 and not _same(application, retained["first_recovery_owned_application"]):
				return _failure("FIRST_RECOVERY_APPLICATION_CROSSED")
			memory = advance["next_memory"]
			control = advance["control_receipt"] if advance.get("control_receipt") is Dictionary else {}
			previous_bound = bound
			canonical_count += 1
		elif phase == R10AP.PHASE_SETTLING:
			var rows: Variant = settling_retained.get("readiness_rows")
			if not (rows is Array) or settling_count >= rows.size() or not (rows[settling_count] is Dictionary): return _failure("SETTLING_READINESS_POPULATION")
			var row: Dictionary = rows[settling_count]
			if row.get("role") != state.arm_id or row.get("purpose") != "post_recovery_hold_dwell" or row.get("global_semantic_step") != step: return _failure("SETTLING_READINESS_IDENTITY")
			var source: Dictionary = row.get("source", {})
			var ready := _settling_source_v1(sdk, source, compiled.value, state, step)
			if ready.get("ok") != true: return ready
			if not _same(ready.readiness, event.get("post_recovery_readiness")) or _sha(sdk, source) != event.get("post_recovery_readiness_source_sha256"): return _failure("SETTLING_SOURCE_EVENT")
			if _sha(sdk, upright_memory) != state.upright_memory_sha256 or upright_memory.get("phase") != "complete": return _failure("SETTLING_RECOVERY_MEMORY_CHANGED")
			settling_count += 1
		var advanced := (R10AP.advance_v1(sdk, state, event) if r10v_selected
			else Entry.advance_v1(sdk, state, event, controller_id, walking_policy_id))
		if advanced.get("ok") != true or not _same(advanced, transition["advance"]):
			return _failure("SCHEDULER_REPLAY_MISMATCH")
		state = advanced["state_after"]
	if (entry_count != retained["entry_packets"].size() or canonical_count != retained["canonical_packets"].size()
		or canonical_count == 0 and not retained["first_recovery_owned_application"].is_empty()
		or not _same(state, final_state)):
		return _failure("UNCONSUMED_PACKET_OR_FINAL_STATE")
	if r10v_selected and (partial_count != partial_retained.step_packets.size()
		or not _same(partial_retained.entry_kind, final_state.r10v_entry_kind)
		or not _same(partial_retained.declaration, partial_declaration) or not _same(partial_retained.final_memory, partial_memory)
		or partial_count == 0 and not partial_retained.first_partial_application.is_empty()):
		return _failure("UNCONSUMED_PARTIAL_PACKET_OR_FINAL_MEMORY")
	if r10v_selected and (upright_count != upright_retained.step_packets.size()
		or not _same(upright_retained.entry_kind, final_state.r10v_entry_kind)
		or not _same(upright_retained.declaration, upright_declaration) or not _same(upright_retained.final_memory, upright_memory)
		or upright_count == 0 and not upright_retained.first_upright_application.is_empty()):
		return _failure("UNCONSUMED_UPRIGHT_PACKET_OR_FINAL_MEMORY")
	if not _same(settling_retained.get("final_memory", {}), state.post_recovery_settling): return _failure("SETTLING_FINAL_MEMORY")
	if settling_count != settling_retained.get("readiness_rows", []).size(): return _failure("SETTLING_UNCONSUMED_SOURCE")
	if completion_readiness_count != (1 if state.upright_phase == "complete" else 0): return _failure("SETTLING_COMPLETION_POPULATION")
	if completion_readiness_count == 0 and not settling_retained.get("entry_source", {}).is_empty(): return _failure("SETTLING_UNSELECTED_SOURCE")
	var result := {"schema_version": selection["replay_receipt_schema"], "ok": true,
		"ledger_scope": {"subsystem": "recovery", "engine_scope": "godot_jolt", "question_class": "development", "authority_mode": "independent_retained_segment_replay"},
		"post_recovery_hold_commands": settling_count, "completion_readiness_count": completion_readiness_count,
		"transition_count": transitions.size(), "entry_observation_count": entry_count,
		"canonical_observation_count": canonical_count, "canonical_initialization_count": 0 if handoff.is_empty() else 1,
		"initial_global_semantic_step": input["initial_state"]["previous_global_semantic_step"],
		"final_global_semantic_step": state["previous_global_semantic_step"], "final_state_sha256": state["payload_sha256"],
		"world_build_count": 0, "native_physics_read_count": 0, "solver_step_count": 0,
		"complete_route_proven": false, "physical_acceptance_authority": false, "release_authority": false}
	if r10v_selected:
		result["partial_observation_count"] = partial_count
		result["partial_initialization_count"] = 0 if partial_declaration.is_empty() else 1
		result["upright_observation_count"] = upright_count
		result["upright_initialization_count"] = 0 if upright_declaration.is_empty() else 1
	return result


static func _application_link(sdk: Object, state: Dictionary, application: Dictionary, bound: Dictionary, memory: Dictionary, source: Dictionary,
	controller_id: String = Canonical.Route.RECOVERY_CONTROLLER_V6_ID, maximum_step: int = 832, partial_native_source: Dictionary = {}, upright_native_source: Dictionary = {}) -> String:
	var step: int = state["previous_global_semantic_step"] + 1
	if not _same(application.get("semantic_step"), step):
		return "APPLICATION_GLOBAL_STEP"
	if not (bound.get("observation_v2") is Dictionary) or not (bound.get("observation_v3") is Dictionary):
		return "BOUND_OBSERVATION_MISSING"
	if not Stage.representations_agree_v1(bound):
		return "BOUND_REPRESENTATIONS_CROSSED"
	var observation: Dictionary = bound["observation_v3"]
	var actuation: Variant = observation.get("applied_actuation")
	if not (actuation is Dictionary) or not _same(observation.get("semantic_step"), step):
		return "OBSERVATION_GLOBAL_STEP"
	# The observation binds the post-step native execution, not the pre-step
	# application intent. Validate both identities without conflating the records.
	var components: Variant = bound.get("source_component_receipts")
	if not (components is Dictionary):
		return "NATIVE_APPLICATION_SOURCE_MISSING"
	var native_components: Variant = components.get("rotation_aware_source_component_receipts")
	if not (native_components is Dictionary) or not (native_components.get("application_receipt") is Dictionary):
		return "NATIVE_APPLICATION_SOURCE_MISSING"
	var native_application: Dictionary = native_components["application_receipt"]
	var native_sha := _sha(sdk, native_application)
	if (not _same(actuation.get("adapter_receipt_sha256"), native_sha)
		or not _same(native_components.get("application_receipt_sha256"), native_sha)):
		return "APPLICATION_OBSERVATION_BINDING"
	for key in ["command_id", "command_sha256", "zero_command"]:
		if (not _same(actuation.get(key), application.get(key))
			or not _same(native_application.get(key), application.get(key))):
			return "APPLICATION_OBSERVATION_COMMAND:" + key
	if (not _same(native_application.get("semantic_step"), step)
		or not _same(actuation.get("source_semantic_step"), step)
		or not (native_application.get("ordered_applied_impulses") is Array)
		or not _same(native_application["ordered_applied_impulses"], actuation.get("ordered_applied_impulses"))):
		return "NATIVE_APPLICATION_STEP_OR_IMPULSES"
	var ownership := World.controller_ownership_observation_v1(sdk, application)
	if ownership.get("ok") != true or not _same(ownership["observation"], observation.get("controller_ownership")):
		return "APPLICATION_OBSERVATION_OWNER"
	if not upright_native_source.is_empty():
		var original := application.duplicate(true)
		original.erase(UprightBridge.Source.KEY)
		var tagged := UprightBridge.Source.bind_application_v1(sdk, upright_native_source, original)
		var context := UprightBridge.Source.control_context_v1(sdk, upright_native_source)
		if (tagged.get("ok") != true or context.get("ok") != true or not _same(tagged.get("application"), application)
			or context.get("memory_sha256") != _sha(sdk, memory)
			or not canonical_application_source_valid_v1(sdk, original, context.get("control", {}), controller_id, maximum_step)):
			return "ACTIVE_UPRIGHT_APPLICATION_SOURCE"
		return ""
	if not partial_native_source.is_empty():
		var original := application.duplicate(true)
		original.erase(PartialBridge.Source.KEY)
		var tagged := PartialBridge.Source.bind_application_v1(sdk, partial_native_source, original)
		var context := PartialBridge.Source.control_context_v1(sdk, partial_native_source)
		if (tagged.get("ok") != true or context.get("ok") != true or not _same(tagged.get("application"), application)
			or context.get("memory_sha256") != _sha(sdk, memory)
			or not canonical_application_source_valid_v1(sdk, original, context.get("control", {}), PartialBridge.Source.RECOVERY, maximum_step)):
			return "ACTIVE_PARTIAL_APPLICATION_SOURCE"
		return ""
	var descent: bool = state["phase"] == Entry.PHASE_DESCENT
	if descent or state["phase"] == Entry.Prior.PHASE_CONFIRM_PRONE:
		if not (application.get("motor_population_readback") is Dictionary):
			return "NO_ACTUATION_READBACK_MISSING"
		var expected := Facade.no_actuation_ledger_application_intent_v2(sdk, step,
			Entry.PHASE_DESCENT if descent else memory.get("phase", ""), "none" if descent else Entry.Owner.profile_v1(controller_id)["owner"],
			null if descent else controller_id, false,
			state if descent else source, application["motor_population_readback"], memory, {},
			Canonical.Route.RECOVERY_CONTROLLER_V6_ID if descent else controller_id)
		if expected.get("ok") != true or not _same(expected, application):
			return "NO_ACTUATION_SOURCE_MAPPING"
	else:
		if not canonical_application_source_valid_v1(sdk, application, source, controller_id, maximum_step):
			return "ACTIVE_CANONICAL_APPLICATION"
	return ""


static func canonical_application_source_valid_v1(sdk: Object, application: Dictionary, source: Dictionary,
	controller_id: String = Canonical.Route.RECOVERY_CONTROLLER_V6_ID, maximum_step: int = 832) -> bool:
	var no_actuation: bool = source.get("no_actuation_requested") == true
	# The unchanged canonical control decoder retains this counter as binary64;
	# its real applier explicitly projects an exactly integral step to int. Keep
	# the original source bytes/hash, and validate that bounded projection here.
	var source_step: Variant = source.get("semantic_step")
	if typeof(source_step) not in [TYPE_INT, TYPE_FLOAT] or source_step < 1 or source_step > maximum_step or source_step != int(source_step):
		return false
	if (not Canonical.Behavior.behavior_application_receipt_valid_v4("solver_coupled_native_constraint_motor_v1",
		application, no_actuation, Canonical.Route.R148_COMPLETE_ENERGY_ROUTE_ID, true, controller_id)
		or not _same(application.get("source_control_semantic_step"), int(source_step))):
		return false
	if not no_actuation:
		return _same(application.get("command_sha256"), source.get("command_sha256"))
	# The production disabled-motor path hashes a source-bound command record,
	# not the active controller's ordered-command array.
	var command := {"schema_version": "sporespore_qsdk_r24d65_godot_no_actuation_command_v1",
		"source_control_sha256": _sha(sdk, source), "source_control_semantic_step": int(source_step),
		"application_semantic_step": application.get("semantic_step"), "phase": source.get("phase"),
		"arm_kind": "matched_zero_command" if source.get("matched_zero_command") == true else "candidate_command",
		"ordered_intents": application.get("ordered_intents")}
	return _same(application.get("command_sha256"), _sha(sdk, command))


static func _epoch_link(sdk: Object, state: Dictionary, bound: Dictionary, previous: Dictionary) -> String:
	for key in ["energy_source_receipt", "source_component_receipts"]:
		if not (bound.get(key) is Dictionary):
			return "EPOCH_SOURCE_MISSING:" + key
	var energy: Dictionary = bound["energy_source_receipt"]
	var components: Dictionary = bound["source_component_receipts"]
	if not Stage.Epoch.source_components_complete_v1(sdk, energy, components):
		return "EPOCH_COMPONENTS_INVALID"
	var initializer: Dictionary = components["epoch_initializer"]
	if not Stage.Initializer.initializer_valid_v1(sdk, initializer):
		return "EPOCH_INITIALIZER_INVALID"
	for key in ["attempt_id", "arm_id", "model_instance_id", "epoch_start_global_step"]:
		if not _same(initializer.get(key), state.get(key)):
			return "EPOCH_IDENTITY_CROSSED:" + key
	if (not _same(initializer["payload_sha256"], state["energy_initializer_sha256"])
		or not _same(initializer["kick_interaction_receipt_sha256"], state["interaction_receipt_sha256"])):
		return "EPOCH_KICK_BINDING_CROSSED"
	# Reconstruct the actual offset/staging map rather than accepting a set of
	# self-consistent hashes for a ledger whose boundary or work was changed.
	var mapped := Stage.Epoch.map_epoch_step_v1(sdk, components["rotation_aware_energy_source_receipt"],
		components["rotation_aware_source_component_receipts"], components["discrete_staging_observer_receipt"],
		components["discrete_staging_accumulator_before"], initializer)
	if (mapped.get("ok") != true or not _same(mapped.get("energy_source_receipt"), energy)
		or not _same(mapped.get("source_component_receipts"), components)):
		return "EPOCH_SOURCE_RECONSTRUCTION"
	var base: Dictionary = bound["observation_v2"].duplicate(true)
	base.erase("schema_version")
	base.erase("energy_balance")
	var composed := Stage.Epoch.compose_observations_v1(sdk, base, mapped)
	for key in ["observation_v2", "observation_v3", "source_binding"]:
		if composed.get("ok") != true or not _same(composed.get(key), bound.get(key)):
			return "EPOCH_OBSERVATION_RECONSTRUCTION:" + key
	if not previous.is_empty():
		var prior: Dictionary = previous["source_component_receipts"]
		if (not _same(prior["epoch_initializer"], initializer)
			or not _same(prior["discrete_staging_accumulator_after"], components["discrete_staging_accumulator_before"])):
			return "EPOCH_STAGING_OR_INITIALIZER_CHAIN"
	var raw: Dictionary = components["rotation_aware_energy_source_receipt"]
	var native: Variant = components["rotation_aware_source_component_receipts"].get("complete_energy_inputs_receipt")
	if not (native is Dictionary):
		return "EPOCH_NATIVE_INCREMENT_INPUTS_MISSING"
	var totals := ["cumulative_applied_actuator_work_j", "cumulative_signed_external_work_j",
		"cumulative_signed_constraint_exchange_j", "cumulative_passive_dissipation_j"]
	var increments := [raw.get("step_actuator_work_j"), native.get("step_signed_external_work_j"),
		raw.get("step_signed_constraint_exchange_j"), native.get("step_passive_dissipation_j")]
	var boundary := ["global_cumulative_applied_actuator_work_at_epoch_start_j", "global_cumulative_signed_external_work_at_epoch_start_j",
		"global_cumulative_signed_constraint_exchange_at_epoch_start_j", "global_cumulative_passive_dissipation_at_epoch_start_j"]
	for index in range(totals.size()):
		var prior: Variant = initializer[boundary[index]] if previous.is_empty() else previous["source_component_receipts"]["rotation_aware_energy_source_receipt"][totals[index]]
		if typeof(increments[index]) != TYPE_FLOAT or raw[totals[index]] != prior + increments[index]:
			return "EPOCH_GLOBAL_INCREMENT_CHAIN:" + totals[index]
	return ""


static func _source(sdk: Object, binding: Variant) -> Dictionary:
	if not (binding is Dictionary) or not (binding.get("utf8_text") is String):
		return {}
	if not _same(binding, Bytes.bytes_v1(binding["utf8_text"])):
		return {}
	var decoded: Variant = sdk.decode_exact_json_v1(binding["utf8_text"])
	return decoded if decoded is Dictionary else {}


static func _state_valid_v1(sdk: Object, state: Dictionary, controller: String, walking: String) -> bool:
	return R10AP.state_valid_v1(sdk, state) if walking in [R10AP.ROUTE] else Entry.state_valid_v1(sdk, state, controller, walking)


static func _event_valid_v1(sdk: Object, event: Dictionary, controller: String, walking: String) -> bool:
	return R10AP.event_valid_v1(sdk, event) if walking in [R10AP.ROUTE] else Entry.event_valid_v1(sdk, event, controller, walking)


static func _build_event_v1(sdk: Object, state: Dictionary, fields: Dictionary, controller: String, walking: String) -> Dictionary:
	return R10AP.build_event_v1(sdk, state, fields) if walking in [R10AP.ROUTE] else Entry.build_event_v1(sdk, state, fields, controller, walking)


static func _partial_retention_valid_v1(value: Variant) -> bool:
	if not (value is Dictionary) or value.get("schema_version") != "sporespore_r10ap_partial_recovery_retention_v1": return false
	if value.get("control_composition_id") != PartialBridge.Source.COMPOSITION: return false
	for key in ["canonical_supervisor_synthesized", "source_observation_rewritten", "energy_epoch_reset", "physical_acceptance_authority", "release_authority"]:
		if value.get(key) != false: return false
	for key in ["declaration", "final_memory", "first_partial_application"]:
		if not (value.get(key) is Dictionary): return false
	return value.get("step_packets") is Array and value.get("entry_kind") in ["unselected", "waiting", "prone", "partial", "upright", "timeout"]


static func _upright_retention_valid_v1(value: Variant) -> bool:
	if not (value is Dictionary) or value.get("schema_version") != "sporespore_r10v_upright_recovery_retention_v1": return false
	for key in ["partial_supervisor_synthesized", "canonical_supervisor_synthesized", "source_observation_rewritten", "energy_epoch_reset", "physical_acceptance_authority", "release_authority"]:
		if value.get(key) != false: return false
	for key in ["declaration", "final_memory", "first_upright_application"]:
		if not (value.get(key) is Dictionary): return false
	return value.get("step_packets") is Array and value.get("entry_kind") in ["unselected", "waiting", "prone", "partial", "upright", "timeout"]


static func _same(left: Variant, right: Variant) -> bool:
	return Transport.stringify(left) == Transport.stringify(right)


static func _sha(sdk: Object, value: Variant) -> String:
	return Runtime.canonicalize(sdk, value).get("sha256", "")


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "failure_code": "R10AP_RECOVERY_REPLAY_" + code,
		"world_build_count": 0, "native_physics_read_count": 0, "solver_step_count": 0,
		"complete_route_proven": false, "physical_acceptance_authority": false, "release_authority": false}

## A segment reader checks the retained packet itself. The complete-report
## reader additionally binds its precommand trace to the original arm timeline.
static func _settling_source_v1(sdk: Object, source: Dictionary, compiled: Dictionary, state: Dictionary, step: int) -> Dictionary:
	var trace: Dictionary = source.get("packet", {}).get("native_source", {}).get("precommand_trace", {})
	if trace.get("global_semantic_step") != step or trace.get("arm_id") != state.arm_id: return _failure("SETTLING_SOURCE_CLOCK")
	return StanceEntryReplay.measurement_v1(sdk, source, trace, compiled, state.model_instance_id, state.body_population_instance_sha256, R10AP.ROUTE)

static func _route_id_v1(selection: Dictionary) -> String:
	var id: Variant = selection.get("diagnostic_schedule", {}).get("walking_policy_id")
	return R10AP.ROUTE if id == R10AP.ROUTE else ""
