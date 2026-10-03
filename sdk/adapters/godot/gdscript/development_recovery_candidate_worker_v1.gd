extends "res://sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd"
# gdlint: disable=max-line-length

## One worker for prospectively bound candidates. Setup stays V6; the profile
## selects only the post-kick controller and its exact compiled runtime.
const CandidateProfile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const CampaignSeed := preload("res://sdk/adapters/godot/gdscript/r10j_campaign_seed_v1.gd")
const R10OSeed := preload("res://sdk/adapters/godot/gdscript/r10o_development_seed_v1.gd")
const R10NSeed := preload("res://sdk/adapters/godot/gdscript/r10n_development_seed_v1.gd")
const R10MSeed := preload("res://sdk/adapters/godot/gdscript/r10m_development_seed_v1.gd")
const R10LSeed := preload("res://sdk/adapters/godot/gdscript/r10l_development_seed_v1.gd")
const R10KSeed := preload("res://sdk/adapters/godot/gdscript/r10k_development_seed_v1.gd")
var _campaign_declaration: Dictionary = {}
var _candidate_selection: Dictionary = {}
var _candidate_context: Dictionary = {}
var _candidate_mode := ""
const CycleStop := preload("res://sdk/adapters/godot/gdscript/development_recovery_cycle_stop_v1.gd")
var _cycle_stop_memory: Dictionary = CycleStop.initial_v1()
var _cycle_stop_sources: Array = []
var _walking_control_sources: Array = []
var _walking_contact_sources: Array = []
const StanceEntry := preload("res://sdk/adapters/godot/gdscript/recovery_stance_entry_route_v1.gd")
const EntrySource := preload("res://sdk/adapters/godot/gdscript/recovery_walking_entry_source_v1.gd")
const EntryTransport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
var _entry_readiness_rows: Array = []
var _neutral_control_rows: Array = []
var _hold_control_rows: Array = []
var _entry_compiled: Dictionary = {}
var _kicked_entry_checked := false
const R10K := preload("res://sdk/adapters/godot/gdscript/r10k_recovery_orchestrator_v1.gd")
const R10KBridge := preload("res://sdk/adapters/godot/gdscript/r10k_partial_recovery_stage_v1.gd")
var _r10k_partial_packets: Array = []
var _r10k_first_partial_application: Dictionary = {}

func _r10o_selected_v1() -> bool:
	return _candidate_selection.get("diagnostic_schedule", {}).get("walking_policy_id") == StanceEntry.R10O.ID

func _r10n_selected_v1() -> bool:
	return _candidate_selection.get("diagnostic_schedule", {}).get("walking_policy_id") == StanceEntry.R10N.ID

func _r10m_selected_v1() -> bool:
	return _candidate_selection.get("diagnostic_schedule", {}).get("walking_policy_id") == StanceEntry.R10M.ID

func _r10l_selected_v1() -> bool:
	return _candidate_selection.get("diagnostic_schedule", {}).get("walking_policy_id") == StanceEntry.R10L.ID

func _r10k_selected_v1() -> bool:
	# R10L reuses the unchanged partial/prone recovery component.
	return _r10o_selected_v1() or _r10n_selected_v1() or _r10m_selected_v1() or _r10l_selected_v1() or _candidate_selection.get("diagnostic_schedule", {}).get("walking_policy_id") == R10K.ROUTE

func _initialize_orchestrator_v1(arm_id: String, model_id: String, population: String) -> Dictionary:
	return (R10K.initialize_v1(_sdk, _attempt_id, arm_id, model_id, _configuration_sha256, population)
		if _r10k_selected_v1() else super._initialize_orchestrator_v1(arm_id, model_id, population))

func _build_orchestrator_event_v1(state: Dictionary, fields: Dictionary) -> Dictionary:
	return R10K.build_event_v1(_sdk, state, fields) if _r10k_selected_v1() else super._build_orchestrator_event_v1(state, fields)

func _advance_orchestrator_step_v1(state: Dictionary, event: Dictionary) -> Dictionary:
	if not _r10k_selected_v1(): return super._advance_orchestrator_step_v1(state, event)
	var result := R10K.advance_v1(_sdk, state, event)
	_entry_transitions.append({"state_before": state.duplicate(true), "event": event.duplicate(true), "advance": result.duplicate(true)})
	if result.get("ok") == true and state.phase == Orchestrator.PHASE_INTERACTION and result.next_phase == EntryOrchestrator.PHASE_DESCENT:
		# Setup remains retained in its genuine terminal source. Neither post-kick
		# branch owns canonical memory while passive descent is still running.
		var arm: Dictionary = _arms[state.arm_id]
		arm.recovery_memory = {}
		arm.next_recovery_control = {}
		arm.last_recovery_terminal = false
		arm["passive_entry_state"] = {}
		arm["passive_entry_handoff_receipt"] = {}
		arm["r10k_partial_declaration"] = {}
		arm["r10k_partial_memory"] = {}
		arm["r10k_native_receipt"] = {}
		_arms[state.arm_id] = arm
	return result

func _process_descent_v1(arm_id: String, global_step: int) -> Dictionary:
	if not _r10k_selected_v1(): return super._process_descent_v1(arm_id, global_step)
	var arm: Dictionary = _arms[arm_id]
	var state: Dictionary = arm.orchestrator_state
	var collection: Dictionary = arm.last_collection
	var bound: Dictionary = collection.get("epoch_result", {}).get("bound_epoch_observations", {})
	var packet := R10KBridge.entry_v1(_sdk, _context, _attempt_id, bound, arm.get("passive_entry_state", {}))
	packet["source_application"] = arm.pending_application.duplicate(true)
	_entry_packets.append(packet)
	if packet.get("ok") != true: return packet
	var original: Dictionary = packet.original_passive_receipt
	arm.passive_entry_state = packet.entry_state
	arm.last_recovery_classification = original.classification.duplicate(true)
	arm.trace_rows[-1]["recovery_classification"] = original.classification.duplicate(true)
	var kind: String = packet.entry_kind
	if kind in ["prone", "partial"]:
		if (not arm.recovery_memory.is_empty() or not arm.passive_entry_handoff_receipt.is_empty()
			or not arm.get("r10k_partial_memory", {}).is_empty()):
			return {"ok": false, "failure_code": "R10K_RECOVERY_REINITIALIZATION"}
		if kind == "prone":
			if not (original.get("canonical_memory") is Dictionary): return {"ok": false, "failure_code": "R10K_PRONE_MEMORY_MISSING"}
			arm.recovery_memory = original.canonical_memory.duplicate(true)
			arm.passive_entry_handoff_receipt = original.duplicate(true)
			arm["first_post_entry_application_pending"] = true
		else:
			var entry: Dictionary = packet.native_receipt.entry
			arm.r10k_partial_declaration = entry.partial_declaration.duplicate(true)
			arm.r10k_partial_memory = entry.partial_memory.duplicate(true)
			arm.r10k_native_receipt = packet.native_receipt.duplicate(true)
			arm.next_recovery_control = packet.native_receipt.initial_partial_control.duplicate(true)
	_arms[arm_id] = arm
	var event := _build_orchestrator_event_v1(state, {
		"event_kind": "passive_entry_observation", "global_semantic_step": global_step,
		"recovery_epoch_local_step": global_step - state.epoch_start_global_step,
		"control_owner": "none", "actuation_owner": "none", "no_actuation_requested": true,
		"application_intent_sha256": _canonical_sha256_v1(arm.pending_application),
		"energy_initializer_sha256": _arm_epoch_initializer_sha256_v1(arm),
		"prone_sample": original.classification.entry_prone_gate, "stable_four_foot_stance": original.classification.stable_stance_gate,
		"passive_entry_receipt_sha256": _canonical_sha256_v1(original), "passive_entry_status": original.memory.status,
		"canonical_initialization_count": original.canonical_initialization_count, "r10k_native_receipt": packet.native_receipt,
		"body_population_rebuild_count": arm.body_population_rebuild_count, "body_transform_write_count": arm.body_transform_write_count,
		"body_velocity_write_count": arm.body_velocity_write_count, "solver_reset_count": arm.solver_reset_count})
	return _install_orchestrator_event_v1(arm_id, state, arm.pending_application, collection, bound, event)

func _apply_recovery_control_v1(arm_id: String, completed_global_step: int) -> Dictionary:
	var partial: bool = _r10k_selected_v1() and _arms[arm_id].orchestrator_state.phase == R10K.PHASE_PARTIAL
	if not partial: return super._apply_recovery_control_v1(arm_id, completed_global_step)
	var arm: Dictionary = _arms[arm_id]
	var context := _partial_control_context_v1(arm.get("r10k_native_receipt", {}))
	if (context.get("ok") != true or context.get("memory_sha256") != _canonical_sha256_v1(arm.get("r10k_partial_memory", {}))
		or context.get("declaration_sha256") != _canonical_sha256_v1(arm.get("r10k_partial_declaration", {}))
		or context.get("semantic_step") != completed_global_step + 1):
		return {"ok": false, "failure_code": "R10K_APPLY_PARTIAL_SOURCE_CROSSED"}
	# Apply the selected native partial control through the unchanged motor applier.
	var applied := super._apply_recovery_control_v1(arm_id, completed_global_step)
	if applied.get("ok") != true: return applied
	arm = _arms[arm_id]
	var tagged := _bind_partial_application_v1(arm.r10k_native_receipt, arm.pending_application)
	if tagged.get("ok") != true: return tagged
	arm.pending_application = tagged.application
	arm.model[_partial_source_key_v1()] = tagged.model_binding
	if _r10k_first_partial_application.is_empty(): _r10k_first_partial_application = tagged.application.duplicate(true)
	_arms[arm_id] = arm
	return {"ok": true}

func _process_r10k_partial_v1(arm_id: String, global_step: int) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var state: Dictionary = arm.orchestrator_state
	var collection: Dictionary = arm.last_collection
	var bound: Dictionary = collection.get("epoch_result", {}).get("bound_epoch_observations", {})
	var prior_memory: Dictionary = arm.get("r10k_partial_memory", {})
	var packet := _partial_step_packet_v1(bound, arm.get("r10k_partial_declaration", {}), prior_memory)
	packet["source_application"] = arm.pending_application.duplicate(true)
	packet["prior_memory"] = prior_memory.duplicate(true)
	_r10k_partial_packets.append(packet)
	if packet.get("ok") != true: return packet
	var native: Dictionary = packet.native_receipt
	var step: Dictionary = native.step
	var terminal: bool = step.next_phase in ["complete", "failed"]
	arm.r10k_partial_memory = step.memory.duplicate(true)
	arm.r10k_native_receipt = native.duplicate(true)
	arm.next_recovery_control = native.next_control.duplicate(true) if native.next_control is Dictionary else {}
	arm.last_recovery_global_semantic_step = global_step
	arm.last_recovery_terminal = terminal
	arm.last_recovery_terminal_phase = step.next_phase if terminal else ""
	arm.last_recovery_terminal_failure_code = step.memory.terminal_failure_code if step.next_phase == "failed" else ""
	arm.last_recovery_classification = step.classification.duplicate(true)
	arm.trace_rows[-1]["recovery_classification"] = step.classification.duplicate(true)
	_arms[arm_id] = arm
	var event := _build_orchestrator_event_v1(state, {
		"event_kind": "partial_fall_controller_step", "global_semantic_step": global_step,
		"recovery_epoch_local_step": global_step - state.epoch_start_global_step,
		"control_owner": "recovery_candidate", "actuation_owner": "recovery_candidate", "recovery_actuation_applied": true,
		"application_intent_sha256": _canonical_sha256_v1(arm.pending_application),
		"energy_initializer_sha256": _arm_epoch_initializer_sha256_v1(arm),
		"stable_four_foot_stance": step.classification.stable_stance_gate,
		"recovery_controller_terminal_phase": arm.last_recovery_terminal_phase,
		"recovery_controller_terminal_reason": arm.last_recovery_terminal_failure_code,
		"r10k_native_receipt": native, "partial_prior_memory_sha256": _canonical_sha256_v1(prior_memory),
		"body_population_rebuild_count": arm.body_population_rebuild_count, "body_transform_write_count": arm.body_transform_write_count,
		"body_velocity_write_count": arm.body_velocity_write_count, "solver_reset_count": arm.solver_reset_count})
	var result := _install_orchestrator_event_v1(arm_id, state, arm.pending_application, collection, bound, event)
	if result.get("ok") == true and result.phase_after == Orchestrator.PHASE_WALKING_RESUME:
		# The next application belongs to a fresh walking task. Keep the final
		# partial observation and memory in retention, and end only its producer tag.
		_arms[arm_id].model.erase(_partial_source_key_v1())
	return result

func _stance_entry_selected_v1() -> bool:
	return StanceEntry.selected_v1(_walking_policy_id_v1("walking_resume"))

func _hold_route_selected_v1() -> bool:
	return StanceEntry.hold_selected_v1(_walking_policy_id_v1("walking_resume"))

func _entry_segments_v1() -> Array:
	return [StanceEntry.SEGMENT, StanceEntry.HOLD_SEGMENT] if _hold_route_selected_v1() else [StanceEntry.SEGMENT]

func _walking_segment_valid_v1(segment: String) -> bool:
	return (_stance_entry_selected_v1() and segment in _entry_segments_v1()) or super._walking_segment_valid_v1(segment)

func _walking_facade_evaluation_segment_v1(segment: String) -> String:
	# The existing native BW5 facade calls this matched continuation. Its public
	# task segment remains explicitly neutral_stance_entry in every task record.
	return "matched_continuation" if _stance_entry_selected_v1() and segment in _entry_segments_v1() else segment

func _collect_arm_completed_step_v1(arm_id: String, global_step: int) -> Dictionary:
	if _r10k_selected_v1() and _arms[arm_id].orchestrator_state.phase == R10K.PHASE_PARTIAL:
		var arm: Dictionary = _arms[arm_id]
		var selected := _select_partial_source_v1(arm.model, arm.pending_application, global_step)
		var binding: Dictionary = arm.pending_application.get(_partial_source_key_v1(), {})
		if (selected.get("ok") != true or selected.get("partial_task_selected") != true
			or binding.get("memory_sha256") != _canonical_sha256_v1(arm.get("r10k_partial_memory", {}))
			or binding.get("declaration_sha256") != _canonical_sha256_v1(arm.get("r10k_partial_declaration", {}))):
			return {"ok": false, "failure_code": "R10K_PENDING_PARTIAL_SOURCE_CROSSED"}
	if _stance_entry_selected_v1():
		_arms[arm_id]["model"]["development_retain_direct_state_source"] = true
	return super._collect_arm_completed_step_v1(arm_id, global_step)

func _ramp_to_hold_ready_v1(entry_memory: Dictionary, measured: Dictionary) -> bool:
	return entry_memory.reference_ramp_complete and measured.readiness.checks.get("four_native_supports", false)

func _entry_measurement_v1(arm: Dictionary) -> Dictionary:
	if _entry_compiled.is_empty():
		var flexed := StanceEntry.ramped_selected_v1(_walking_policy_id_v1("walking_resume"))
		var raw: String = _sdk.compile_bounded_quadruped_json(EntryTransport.stringify(RouteScript.exact_base_descriptor_v1()) if flexed else JSON.stringify(RouteScript.exact_base_descriptor_v1()))
		var response: Dictionary = _sdk.decode_exact_json_v1(raw) if flexed else JSON.parse_string(raw)
		if response.get("ok") != true: return {"ok": false, "failure_code": "R10H_ENTRY_COMPILE"}
		_entry_compiled = response.value
	return EntrySource.capture_v1(_sdk, arm, _entry_compiled, StanceEntry.task_for_v1(_walking_policy_id_v1("walking_resume")).stance_entry)

func _plan_next_process_isolated_frame_v1(global_step: int) -> Dictionary:
	var arm: Dictionary = _arms.get(_authorized_arm_id, {})
	if _r10k_selected_v1() and arm.get("orchestrator_state", {}).get("phase") == R10K.PHASE_PARTIAL:
		_cost.begin_v1("plan_step/" + R10K.PHASE_PARTIAL)
		var result := _apply_recovery_control_v1(_authorized_arm_id, global_step)
		_cost.end_v1("plan_step/" + R10K.PHASE_PARTIAL)
		return result
	if not _stance_entry_selected_v1() or arm.get("orchestrator_state", {}).get("phase") != StanceEntry.PHASE:
		return super._plan_next_process_isolated_frame_v1(global_step)
	var label := "plan_step/"+StanceEntry.PHASE
	_cost.begin_v1(label)
	var entry_segment := StanceEntry.SEGMENT
	if _hold_route_selected_v1() and arm.get("orchestrator_state", {}).get("entry_ramp_complete", false):
		entry_segment = StanceEntry.HOLD_SEGMENT
	var result := (_start_walking_session_v1(_authorized_arm_id, entry_segment, global_step)
		if arm.get("active_walking_session", {}).is_empty() else _apply_next_walking_step_v1(_authorized_arm_id, global_step))
	_cost.end_v1(label)
	return result

func _process_completed_arm_step_v1(arm_id: String, global_step: int, active_terminal_after_step: bool) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var state: Dictionary = arm.orchestrator_state
	if _r10k_selected_v1() and state.phase == R10K.PHASE_PARTIAL:
		_cost.begin_v1("process_step/" + R10K.PHASE_PARTIAL)
		var result := _process_r10k_partial_v1(arm_id, global_step)
		_cost.end_v1("process_step/" + R10K.PHASE_PARTIAL)
		return result
	if not _stance_entry_selected_v1() or state.phase != StanceEntry.PHASE:
		return super._process_completed_arm_step_v1(arm_id, global_step, active_terminal_after_step)
	var label := "process_step/"+StanceEntry.PHASE
	_cost.begin_v1(label)
	var measured := _entry_measurement_v1(arm)
	if measured.get("ok") != true:
		_cost.end_v1(label)
		return measured
	var route := _walking_policy_id_v1("walking_resume")
	var hold_segment: bool = _hold_route_selected_v1() and arm.get("active_walking_session", {}).get("evaluation_segment_id") == StanceEntry.HOLD_SEGMENT
	_entry_readiness_rows.append({"role": arm_id, "purpose": "hold_dwell" if hold_segment else "neutral_dwell", "global_semantic_step": global_step,
		"source": measured})
	var entry_ready: bool = measured.readiness.ready
	if StanceEntry.ramped_selected_v1(route) and not hold_segment:
		if _neutral_control_rows.is_empty() or _neutral_control_rows[-1].step.get("global_semantic_step") != global_step:
			_cost.end_v1(label)
			return {"ok": false, "failure_code": "R10I_ENTRY_APPLIED_COMMAND_MISSING"}
		var entry_memory: Dictionary = _neutral_control_rows[-1].step.get("portable_step_receipt", {}).get("native_output", {}).get("next_memory", {}).get("joint_pose_entry", {})
		if typeof(entry_memory.get("reference_ramp_complete")) != TYPE_BOOL:
			_cost.end_v1(label)
			return {"ok": false, "failure_code": "R10I_ENTRY_APPLIED_MEMORY_MISSING"}
		if StanceEntry.hold_selected_v1(route):
			# R10J ramp readiness: native reference ramp complete with four native
			# supports. Settling is measured inside the separate V50 hold session.
			entry_ready = _ramp_to_hold_ready_v1(entry_memory, measured)
		else:
			entry_ready = entry_ready and entry_memory.reference_ramp_complete
	elif hold_segment:
		if _hold_control_rows.is_empty() or _hold_control_rows[-1].step.get("global_semantic_step") != global_step:
			_cost.end_v1(label)
			return {"ok": false, "failure_code": "R10J_HOLD_APPLIED_COMMAND_MISSING"}
	var application: Dictionary = arm.pending_application
	var collection: Dictionary = arm.last_collection
	var event := _build_orchestrator_event_v1(state, {
		"event_kind": StanceEntry.HOLD_EVENT if hold_segment else "neutral_stance_entry_step", "global_semantic_step": global_step,
		"recovery_epoch_local_step": global_step-state.epoch_start_global_step,
		"control_owner": StanceEntry.entry_owner_for_v1(route), "actuation_owner": StanceEntry.entry_owner_for_v1(route), "no_actuation_requested": false,
		"application_intent_sha256": _canonical_sha256_v1(application),
		"walking_session_id": application.get("walking_session_id", ""),
		"walking_session_local_step": application.get("walking_session_local_step", 0),
		"walking_actuation_applied": true, "recovery_actuation_applied": false,
		"energy_initializer_sha256": state.energy_initializer_sha256,
		"neutral_entry_readiness_sha256": measured.readiness_sha256, "neutral_entry_ready": entry_ready,
		"body_population_rebuild_count": arm.body_population_rebuild_count, "body_transform_write_count": arm.body_transform_write_count,
		"body_velocity_write_count": arm.body_velocity_write_count, "solver_reset_count": arm.solver_reset_count})
	var result := _install_orchestrator_event_v1(arm_id, state, application, collection, null, event)
	if result.get("ok") == true and result.get("phase_after") != StanceEntry.PHASE:
		var closed := _finish_walking_session_v1(arm_id)
		if closed.get("ok") != true: result = closed
	elif result.get("ok") == true and not hold_segment and StanceEntry.hold_selected_v1(route) and _arms[arm_id].get("orchestrator_state", {}).get("entry_ramp_complete", false):
		# R10J: the ramp session finalizes here; the next frame opens the hold session.
		var closed := _finish_walking_session_v1(arm_id)
		if closed.get("ok") != true: result = closed
	_cost.end_v1(label)
	return result

func _candidate_roles_valid_v1(declaration: Dictionary) -> bool:
	return CandidateProfile.roles_valid_v1(declaration)

func _initialize() -> void:
	var declaration_path := _declaration_path_v1()
	var raw := FileAccess.get_file_as_string(declaration_path)
	var declaration: Variant = JSON.parse_string(raw)
	if (not (declaration is Dictionary) or "sha256:" + raw.sha256_text() != OS.get_environment(AUTHORIZATION_ENV)
		or not _candidate_roles_valid_v1(declaration)):
		push_error("DEVELOPMENT_CANDIDATE_DECLARATION_INVALID")
		quit(1)
		return
	_candidate_selection = CandidateProfile.load_v1(declaration.get("candidate_profile"))
	if _candidate_selection.is_empty():
		push_error("DEVELOPMENT_CANDIDATE_PROFILE_INVALID")
		quit(1)
		return
	_candidate_mode = declaration["development_execution_mode"]
	_campaign_declaration = declaration
	super._initialize()

func _authorized_seed_binding_v1(seed_text: String, label: String, digest: String) -> bool:
	# The launcher remains gated until complete safety integration. This guard
	# validates the exact selected development identity before SDK construction.
	if _campaign_declaration.has("r10o_development") and not _r10o_selected_v1(): return false
	if _campaign_declaration.has("r10n_development") and not _r10n_selected_v1(): return false
	if _campaign_declaration.has("r10m_development") and not _r10m_selected_v1(): return false
	if _campaign_declaration.has("r10l_development") and not _r10l_selected_v1(): return false
	if _campaign_declaration.has("r10k_development") and not _r10k_selected_v1(): return false
	if not _r10k_selected_v1() and not _campaign_declaration.has("r10j_campaign"):
		return super._authorized_seed_binding_v1(seed_text, label, digest)
	var role := OS.get_environment(CHILD_ROLE_ENV)
	var descriptors: Array = _campaign_declaration.get("children", []).filter(func(child): return child.get("role") == role)
	if descriptors.size() != 1 or _campaign_declaration.get("attempt_id") != OS.get_environment(PARENT_ATTEMPT_ID_ENV):
		return false
	if descriptors[0].get("child_attempt_id") != OS.get_environment(ATTEMPT_ID_ENV) or descriptors[0].get("termination_nonce") != OS.get_environment(NONCE_ENV):
		return false
	if _r10o_selected_v1():
		return R10OSeed.authorized_v1(_campaign_declaration, seed_text, label, digest, role, OS.get_environment(SOURCE_COMMIT_ENV))
	if _r10n_selected_v1():
		return R10NSeed.authorized_v1(_campaign_declaration, seed_text, label, digest, role, OS.get_environment(SOURCE_COMMIT_ENV))
	if _r10m_selected_v1():
		return R10MSeed.authorized_v1(_campaign_declaration, seed_text, label, digest, role, OS.get_environment(SOURCE_COMMIT_ENV))
	if _r10l_selected_v1():
		return R10LSeed.authorized_v1(_campaign_declaration, seed_text, label, digest, role, OS.get_environment(SOURCE_COMMIT_ENV))
	if _r10k_selected_v1():
		return R10KSeed.authorized_v1(_campaign_declaration, seed_text, label, digest, role, OS.get_environment(SOURCE_COMMIT_ENV))
	return CampaignSeed.authorized_v1(_campaign_declaration, seed_text, label, digest,
		role, OS.get_environment(SOURCE_COMMIT_ENV))

func _entry_controller_id_v1() -> String:
	return _candidate_selection.get("post_kick_controller_id", "")

func _entry_selection_v1() -> Dictionary:
	return _candidate_selection.get("worker_selection", {})

func _entry_after_interaction_steps_v1() -> int:
	return int(CandidateProfile.limits_v1(_candidate_selection)["after_interaction_steps"])

func _walking_frame_id_v1(evaluation_segment_id: String) -> String:
	return CandidateProfile.walking_frame_id_v1(_candidate_selection, evaluation_segment_id)

func _walking_gait_amplitude_v1(segment_id: String, local_step: int) -> float:
	if _stance_entry_selected_v1() and segment_id in _entry_segments_v1(): return 0.0
	if CycleStop.selected_policy_v1(_walking_policy_id_v1(segment_id)) and CycleStop.stopping_v1(_cycle_stop_memory):
		return 0.0
	return CandidateProfile.WalkingEntry.amplitude_v1(local_step,
		CandidateProfile.walking_entry_id_v1(_candidate_selection, segment_id))

func _walking_contact_profile_id_v1(segment_id: String) -> String:
	return CandidateProfile.walking_contact_id_v1(_candidate_selection, segment_id)

func _walking_phase_progression_mode_v1(segment_id: String, local_step: int) -> String:
	return CandidateProfile.WalkingEntry.phase_mode_v1(local_step,
		CandidateProfile.walking_entry_id_v1(_candidate_selection, segment_id))

func _walking_native_contact_source_v1(arm: Dictionary, segment_id: String) -> Dictionary:
	return CandidateProfile.NativeWalkingContacts.source_v1(arm) if CandidateProfile.NativeWalkingContacts.selected_v1(_walking_contact_profile_id_v1(segment_id)) else {}

func _walking_prefix_profile_id_v1(segment_id: String) -> String:
	if segment_id != "walking_prefix": return ""
	return StanceEntry.R10O.PREFIX_PROFILE if _r10o_selected_v1() else StanceEntry.R10N.PREFIX_PROFILE if _r10n_selected_v1() else StanceEntry.R10M.PREFIX_PROFILE if _r10m_selected_v1() else StanceEntry.R10L.PREFIX_PROFILE if _r10l_selected_v1() else StanceEntry.R10K.PREFIX_PROFILE if _r10k_selected_v1() else ""

func _walking_start_profile_id_v1(segment_id: String) -> String:
	return CandidateProfile.walking_start_id_v1(_candidate_selection, segment_id)

func _walking_policy_id_v1(segment_id: String) -> String:
	return CandidateProfile.WalkingPolicy.selected_id_v1(_candidate_selection, segment_id)

func _walking_owner_for_phase_v1(phase: String) -> String:
	return CandidateProfile.WalkingPolicy.owner_for_phase_v1(phase, _walking_policy_id_v1("walking_resume"))

func _retain_development_walking_source_v1(segment_id: String, step: Dictionary, step_sha: String) -> Dictionary:
	if _stance_entry_selected_v1() and segment_id == StanceEntry.SEGMENT:
		_neutral_control_rows.append({"segment_id": segment_id, "full_step_receipt_sha256": step_sha, "step": step.duplicate(true)})
		return {"ok": true}
	if _hold_route_selected_v1() and segment_id == StanceEntry.HOLD_SEGMENT:
		_hold_control_rows.append({"segment_id": segment_id, "full_step_receipt_sha256": step_sha, "step": step.duplicate(true)})
		return {"ok": true}
	if not _walking_contact_profile_id_v1(segment_id).is_empty():
		var contacts := (CandidateProfile.NativeWalkingContacts.retain_step_v1(segment_id, step, step_sha, _walking_policy_id_v1("walking_resume"))
			if CandidateProfile.NativeWalkingContacts.selected_v1(_walking_contact_profile_id_v1(segment_id))
			else CandidateProfile.WalkingContacts.retain_step_v1(segment_id, step, step_sha))
		if contacts.get("ok") != true:
			return contacts
		_walking_contact_sources.append(contacts["row"])
	var id := CandidateProfile.walking_entry_id_v1(_candidate_selection, segment_id)
	if id.is_empty():
		return {"ok": true}
	var retained := CandidateProfile.WalkingEntry.retain_step_v1(step, id, step_sha, CycleStop.selected_entry_v1(id) and CycleStop.stopping_v1(_cycle_stop_memory))
	if retained.get("ok") == true:
		_walking_control_sources.append(retained["row"])
	return retained

func _development_declaration_valid_v1(raw: String) -> bool:
	var declaration: Variant = JSON.parse_string(raw)
	return (declaration is Dictionary and _candidate_roles_valid_v1(declaration)
		and declaration.get("candidate_profile") == _candidate_selection.get("candidate_profile")
		and super._development_declaration_valid_v1(raw))

func _recovery_controller_for_phase_v1(phase: String) -> String:
	if _r10k_selected_v1() and phase == R10K.PHASE_PARTIAL: return _entry_controller_id_v1()
	return (_entry_controller_id_v1()
		if phase in [Orchestrator.PHASE_CONFIRM_PRONE, Orchestrator.PHASE_POST_KICK_RECOVERY]
		else RouteScript.RECOVERY_CONTROLLER_V6_ID)

func _advance_recovery_stage_v1(arm: Dictionary, bound: Dictionary, global_step: int) -> Dictionary:
	var phase: String = arm.get("orchestrator_state", {}).get("phase", "")
	if _recovery_controller_for_phase_v1(phase) == RouteScript.RECOVERY_CONTROLLER_V6_ID:
		return super._advance_recovery_stage_v1(arm, bound, global_step)
	if _candidate_context.is_empty():
		_candidate_context = RouteScript.prepare_development_candidate_context_v1(_sdk, _entry_controller_id_v1())
	if _candidate_context.get("source_native_context_sha256") != _canonical_sha256_v1(_context):
		return RecoveryAdvanceStageL15.retain_v1(arm, RecoveryAdvanceStageL15._not_called_v1(
			"DEVELOPMENT_CANDIDATE_WORKER_CONTEXT_CROSSED", arm.get("pending_application"), arm.get("recovery_memory"), bound), global_step)
	return RecoveryAdvanceStageL15.advance_development_candidate_v1(_sdk, _candidate_context, arm, bound, global_step, _entry_controller_id_v1())

func _create_passive_recovery_observation_application_v1(completed_global_step: int) -> Dictionary:
	return _consume_l15_no_actuation_stage_v1(NoActuationStageL15.passive_v1(
		_sdk, _arms[EnergyInitializer.ACTIVE_ARM_ID], completed_global_step, _entry_controller_id_v1()))

func _attach_entry_retention_v1(report: Dictionary) -> void:
	super._attach_entry_retention_v1(report)
	report["candidate_profile"] = _candidate_selection["candidate_profile"].duplicate(true)
	report["development_execution_mode"] = _candidate_mode
	report["comparative_authority"] = false
	report["baseline_reused"] = false
	if not _attach_profile_seed_context_v1(report):
		report["ok"] = false
		report["failure_code"] = "R10O_DEVELOPMENT_PUBLICATION_CONTEXT_INVALID" if _r10o_selected_v1() else "R10N_DEVELOPMENT_PUBLICATION_CONTEXT_INVALID" if _r10n_selected_v1() else "R10M_DEVELOPMENT_PUBLICATION_CONTEXT_INVALID" if _r10m_selected_v1() else "R10L_DEVELOPMENT_PUBLICATION_CONTEXT_INVALID" if _r10l_selected_v1() else "R10K_DEVELOPMENT_PUBLICATION_CONTEXT_INVALID" if _r10k_selected_v1() else "R10J_CAMPAIGN_PUBLICATION_CONTEXT_INVALID"
	if CandidateProfile.WalkingPolicy.FiniteRoute.selected_v1(_walking_policy_id_v1("walking_resume")):
		report["finite_recovery_task"] = CandidateProfile.WalkingPolicy.FiniteRoute.task_boundary_v1(report, _cycle_stop_memory, _walking_policy_id_v1("walking_resume"))
	if _stance_entry_selected_v1():
		report["stance_entry"] = {"schema_version": StanceEntry.retention_schema_v1(_walking_policy_id_v1("walking_resume")),
			"readiness_rows": _entry_readiness_rows.duplicate(true), "neutral_control_rows": _neutral_control_rows.duplicate(true),
			"task_contract_sha256": "sha256:"+FileAccess.get_sha256(StanceEntry.task_path_for_v1(_walking_policy_id_v1("walking_resume"))),
			"physical_acceptance_authority": false, "release_authority": false}
		if _hold_route_selected_v1():
			report["stance_entry"]["hold_control_rows"] = _hold_control_rows.duplicate(true)
	report["passive_entry"]["schema_version"] = _candidate_selection["retention_schema"]
	report["passive_entry"]["candidate_profile"] = _candidate_selection["candidate_profile"].duplicate(true)
	report["passive_entry"]["setup_controller_id"] = RouteScript.RECOVERY_CONTROLLER_V6_ID
	report["passive_entry"]["post_kick_controller_id"] = _entry_controller_id_v1()
	report["passive_entry"]["post_kick_controller_context"] = _candidate_context.duplicate(true)
	_attach_profile_recovery_retention_v1(report)
	if CycleStop.selected_policy_v1(_walking_policy_id_v1("walking_resume")):
		report["development_cycle_stop"] = {"schema_version": CycleStop.retention_schema_v1(_walking_policy_id_v1("walking_resume")),
			"final_memory": _cycle_stop_memory.duplicate(true), "rows": _cycle_stop_sources.duplicate(true),
			"physical_acceptance_authority": false, "release_authority": false}
	var entry_id := CandidateProfile.walking_entry_id_v1(_candidate_selection, "walking_resume")
	if not entry_id.is_empty():
		report["development_walking_entry"] = CandidateProfile.WalkingEntry.retention_v1(_walking_control_sources, entry_id)
	var contact_id := _walking_contact_profile_id_v1("walking_resume")
	if not contact_id.is_empty():
		if CandidateProfile.NativeWalkingContacts.selected_v1(contact_id):
			report["development_native_walking_contacts"] = CandidateProfile.NativeWalkingContacts.retention_v1(_walking_contact_sources)
		else:
			report["development_walking_contacts"] = CandidateProfile.WalkingContacts.retention_v1(_walking_contact_sources, contact_id)

func _walking_session_step_limit_v1(segment_id: String) -> int:
	if _stance_entry_selected_v1() and segment_id in _entry_segments_v1(): return 240
	return CycleStop.MAX_WALK + CycleStop.STOP_STEPS if CycleStop.selected_policy_v1(_walking_policy_id_v1(segment_id)) else super._walking_session_step_limit_v1(segment_id)

func _after_completed_process_isolated_step_v1() -> bool:
	if _stance_entry_selected_v1() and not _kicked_entry_checked:
		var arm: Dictionary = _arms[_authorized_arm_id]
		if arm.get("orchestrator_state", {}).get("phase") == Orchestrator.PHASE_WALKING_RESUME and arm.get("active_walking_session", {}).is_empty():
			var measured := _entry_measurement_v1(arm)
			if measured.get("ok") != true:
				_abort("R10H_ENTRY_SOURCE_INVALID", measured)
				return true
			_kicked_entry_checked = true
			_entry_readiness_rows.append({"role": _authorized_arm_id, "purpose": "post_recovery_entry",
				"global_semantic_step": arm.orchestrator_state.previous_global_semantic_step, "source": measured})
			if not measured.readiness.ready:
				_finish_smoke_v1("diagnostic_walking_entry_not_ready")
				return true
	if CycleStop.selected_policy_v1(_walking_policy_id_v1("walking_resume")):
		var arm: Dictionary = _arms[_authorized_arm_id]
		var session: Dictionary = arm.get("active_walking_session", {})
		if CandidateProfile.WalkingPolicy.FiniteRoute.segment_selected_v1(_walking_policy_id_v1("walking_resume"), session.get("evaluation_segment_id", "")) and not _walking_control_sources.is_empty():
			var control: Dictionary = _walking_control_sources[-1]
			var source := CandidateProfile.NativeWalkingContacts.source_v1(arm)
			var advanced := CycleStop.advance_v1(_cycle_stop_memory, control, source)
			if advanced.get("ok") != true:
				_abort("V49_CYCLE_STOP_SOURCE_INVALID", advanced)
				return true
			_cycle_stop_memory = advanced["next_memory"]
			_cycle_stop_sources.append({"session_local_step": control["session_local_step"],
				"full_step_receipt_sha256": control["full_step_receipt_sha256"], "post_native_source": source,
				"advance_receipt": advanced})
			var reason := CycleStop.stop_reason_v1(_cycle_stop_memory)
			if not reason.is_empty():
				_finish_smoke_v1(reason)
				return true
	return super._after_completed_process_isolated_step_v1()

func _attach_profile_seed_context_v1(report: Dictionary) -> bool:
	return (R10OSeed.attach_report_context_v1(report, _campaign_declaration, _seed) if _r10o_selected_v1()
		else R10NSeed.attach_report_context_v1(report, _campaign_declaration, _seed) if _r10n_selected_v1()
		else R10MSeed.attach_report_context_v1(report, _campaign_declaration, _seed) if _r10m_selected_v1()
		else R10LSeed.attach_report_context_v1(report, _campaign_declaration, _seed) if _r10l_selected_v1()
		else R10KSeed.attach_report_context_v1(report, _campaign_declaration, _seed) if _r10k_selected_v1()
		else CampaignSeed.attach_report_context_v1(report, _campaign_declaration, _seed))

func _attach_profile_recovery_retention_v1(report: Dictionary) -> void:
	if _r10k_selected_v1():
		var arm: Dictionary = _arms.get(_authorized_arm_id, {})
		report.passive_entry.schema_version = "sporespore_r10k_recovery_entry_retention_v1"
		report["r10k_partial_recovery"] = {"schema_version": "sporespore_r10k_partial_recovery_retention_v1",
			"entry_kind": arm.get("orchestrator_state", {}).get("r10k_entry_kind", "unselected"),
			"declaration": arm.get("r10k_partial_declaration", {}).duplicate(true),
			"final_memory": arm.get("r10k_partial_memory", {}).duplicate(true),
			"first_partial_application": _r10k_first_partial_application.duplicate(true),
			"step_packets": _r10k_partial_packets.duplicate(true),
			"canonical_supervisor_synthesized": false, "source_observation_rewritten": false,
			"energy_epoch_reset": false, "physical_acceptance_authority": false, "release_authority": false}

# Explicit extension points keep the original partial implementation as the
# default. Successor workers select their own receipt before applying or reading.
func _partial_control_context_v1(native: Dictionary) -> Dictionary:
	return R10KBridge.Source.control_context_v1(_sdk, native)

func _bind_partial_application_v1(native: Dictionary, application: Dictionary) -> Dictionary:
	return R10KBridge.Source.bind_application_v1(_sdk, native, application)

func _select_partial_source_v1(model: Dictionary, application: Dictionary, step: int) -> Dictionary:
	return R10KBridge.Source.select_v1(_sdk, model, application, step)

func _partial_source_key_v1() -> String:
	return R10KBridge.Source.KEY

func _partial_step_packet_v1(bound: Dictionary, declaration: Dictionary, memory: Dictionary) -> Dictionary:
	return R10KBridge.step_v1(_sdk, _context, _attempt_id, bound, declaration, memory)
