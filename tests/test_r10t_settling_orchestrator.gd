extends "res://sdk/trace_analysis/development_recovery_candidate_replay.gd"
const R10T := preload("res://sdk/adapters/godot/gdscript/r10t_recovery_orchestrator_v1.gd")
const EntrySource := preload("res://sdk/adapters/godot/gdscript/recovery_walking_entry_source_v1.gd")
const SHA := "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

static func _state(sdk: Object, original: Dictionary) -> Dictionary:
	var state := original.duplicate(true)
	state.schema_version = R10T.STATE
	state.orchestrator_id = R10T.ID
	state.r10t_entry_kind = state.r10s_entry_kind
	state.erase("r10s_entry_kind")
	state.post_recovery_settling = {}
	state.payload_sha256 = R10T.Prior._payload_sha256_v1(sdk, state)
	return state

static func _event(sdk: Object, original: Dictionary, source: Dictionary) -> Dictionary:
	var event := original.duplicate(true)
	event.schema_version = R10T.EVENT
	event.orchestrator_id = R10T.ID
	event.r10t_native_receipt = event.r10s_native_receipt
	event.erase("r10s_native_receipt")
	event.post_recovery_readiness = source.readiness.duplicate(true) if not source.is_empty() else {}
	event.post_recovery_readiness_source_sha256 = R10T.Source._sha(sdk, source) if not source.is_empty() else ""
	event.payload_sha256 = R10T.Prior._payload_sha256_v1(sdk, event)
	return event

static func _hold(sdk: Object, state: Dictionary, template: Dictionary, ready: bool, session: String = "fresh-post-recovery-hold") -> Dictionary:
	var sample := template.duplicate(true)
	sample.source_semantic_step = state.previous_global_semantic_step + 1
	sample.ready = ready
	sample.checks.horizontal_com_settled = ready
	sample.horizontal_com_speed_m_s = 0.02 if ready else 0.03400406676351237
	var event := R10T.build_event_v1(sdk, state, {"event_kind": "post_recovery_hold_step",
		"global_semantic_step": state.previous_global_semantic_step + 1, "control_owner": "stance", "actuation_owner": "stance",
		"walking_actuation_applied": true, "walking_session_id": session, "walking_session_local_step": state.post_recovery_settling.commands + 1,
		"recovery_epoch_local_step": state.previous_global_semantic_step + 1 - state.epoch_start_global_step,
		"energy_initializer_sha256": state.energy_initializer_sha256, "application_intent_sha256": SHA,
		"post_recovery_readiness": sample, "post_recovery_readiness_source_sha256": SHA})
	return R10T.advance_v1(sdk, state, event.event) if event.get("ok") == true else event

static func _walk(sdk: Object, state: Dictionary, session: String) -> Dictionary:
	var event := R10T.build_event_v1(sdk, state, {"event_kind": "walking_policy_step", "global_semantic_step": state.previous_global_semantic_step + 1,
		"control_owner": "stance", "actuation_owner": "stance", "walking_actuation_applied": true,
		"walking_session_id": session, "walking_session_local_step": state.walking_resume_step_count + 1,
		"recovery_epoch_local_step": state.previous_global_semantic_step + 1 - state.epoch_start_global_step, "application_intent_sha256": SHA})
	return R10T.advance_v1(sdk, state, event.event) if event.get("ok") == true else event

func _dispatch(sdk: Object, input: Dictionary, _binding: Dictionary) -> Dictionary:
	var before := Transport.stringify(input)
	var checks := {}
	var hold_start := {}
	var sample := {}
	var compiled: Dictionary = sdk.decode_exact_json_v1(sdk.compile_bounded_quadruped_json(
		Transport.stringify(R10T.Prior.LocomotionFacade.RecoveryRoute.exact_base_descriptor_v1())))
	if compiled.get("ok") != true: return {"ok": false, "failure_code": "EXACT_BASE_COMPILE"}
	for item in input.cases:
		var state := _state(sdk, item.transition.state_before)
		var event := _event(sdk, item.transition.event, item.source)
		if not item.source.is_empty():
			var projected := EntrySource.project_v1(sdk, item.source.packet, event.global_semantic_step, state.model_instance_id, state.body_population_instance_sha256)
			checks["recovery_source_"+item.case_id+"_projection_reproduced"] = projected.get("ok") == true and Transport.stringify(projected) == Transport.stringify(item.source.projection)
			if projected.get("ok") != true: return {"ok": false, "checks": checks, "failure": projected}
			var readiness := EntrySource.Readiness.measure_v1(projected.request, item.source.packet.native_source.observation.center_of_mass, compiled.value, R10T.Hold.R10S.task.stance_entry)
			checks["recovery_source_"+item.case_id+"_readiness_reproduced"] = Transport.stringify(readiness) == Transport.stringify(item.source.readiness)
		checks["recovery_source_"+item.case_id+"_state_valid"] = R10T.state_valid_v1(sdk, state)
		checks["recovery_source_"+item.case_id+"_event_valid"] = R10T.event_valid_v1(sdk, event)
		var result := R10T.advance_v1(sdk, state, event)
		checks["recovery_source_"+item.case_id+"_advances"] = result.get("ok") == true
		if result.get("ok") != true: return {"ok": false, "checks": checks, "failure": result, "case_id": item.case_id}
		if item.case_id == "phase245_upright":
			hold_start = result.state_after
			sample = item.source.readiness
			checks.hold_completed_upright_selects_pending = hold_start.phase == R10T.PHASE_SETTLING and hold_start.post_recovery_settling.outcome == "pending"
			checks.hold_does_not_reopen_recovery = hold_start.upright_phase == "complete" and hold_start.upright_recovery_step_count == 522 and hold_start.post_recovery_settling.commands == 0
			var missing := event.duplicate(true)
			missing.post_recovery_readiness_source_sha256 = ""
			missing.payload_sha256 = R10T.Prior._payload_sha256_v1(sdk, missing)
			checks.guards_missing_source_binding_refused = not R10T.event_valid_v1(sdk, missing)
		else:
			var expected: String = "matched_no_kick_continuation" if item.case_id == "no_kick" else R10T.Prior.PHASE_WALKING_RESUME
			checks["preservation_"+item.case_id+"_direct_transition"] = result.state_after.phase == expected and R10T._settling_commands(result.state_after) == 0
			checks["preservation_"+item.case_id+"_original_counter"] = result.state_after.previous_global_semantic_step == item.transition.advance.state_after.previous_global_semantic_step
			if item.case_id != "no_kick": checks["preservation_"+item.case_id+"_fresh_walk"] = _walk(sdk, result.state_after, "fresh-v56").get("ok") == true
	if hold_start.is_empty(): return {"ok": false, "failure_code": "MISSING_HOLD_FIXTURE"}
	checks.guards_prefix_session_reuse_refused = _hold(sdk, hold_start, sample, true, hold_start.prefix_walking_session_id).get("ok") == false
	var state: Dictionary = hold_start.duplicate(true)
	var result := {}
	for index in range(1,31):
		result = _hold(sdk, state, sample, true)
		if result.get("ok") != true: break
		state = result.state_after
	checks.hold_thirty_ready_releases = result.get("ok") == true and state.phase == R10T.Prior.PHASE_WALKING_RESUME and state.post_recovery_settling.commands == 30
	checks.hold_global_and_epoch_count_all_commands = state.previous_global_semantic_step == 1064 and state.recovery_epoch_step_count == 1064 - state.epoch_start_global_step
	checks.hold_recovery_and_walking_counters_unchanged = state.upright_recovery_step_count == 522 and state.walking_resume_step_count == 0
	checks.hold_terminal_memory_unchanged = state.upright_memory_sha256 == hold_start.upright_memory_sha256
	checks.handoff_reusing_hold_session_refused = _walk(sdk, state, "fresh-post-recovery-hold").get("ok") == false
	var walking := _walk(sdk, state, "fresh-v56")
	checks.handoff_fresh_walk_counts_from_one = walking.get("ok") == true and walking.state_after.walking_resume_step_count == 1 and walking.state_after.post_recovery_settling.commands == 30
	for boundary in ["success", "timeout"]:
		state = hold_start.duplicate(true)
		for index in range(1,241):
			result = _hold(sdk, state, sample, index >= (211 if boundary == "success" else 212))
			if result.get("ok") != true: break
			state = result.state_after
		checks["hold_exact_240_"+boundary] = (result.get("ok") == true and state.post_recovery_settling.commands == 240
			and state.phase == (R10T.Prior.PHASE_WALKING_RESUME if boundary == "success" else R10T.Prior.PHASE_FAILED))
		if boundary == "timeout":
			checks.guards_timeout_has_no_walking = state.walking_resume_step_count == 0 and state.resume_or_continuation_session_id == "" and state.terminal_reason == "post_recovery_hold_timeout"
			checks.guards_terminal_timeout_cannot_step = _hold(sdk, state, sample, true).get("ok") == false
	checks.preservation_original_inputs_unchanged = before == Transport.stringify(input)
	return {"ok": not checks.values().has(false), "checks": checks, "check_count": checks.size(),
		"retained_terminal_events_copied_with_new_orchestrator_identities": true,
		"post_recovery_hold_events_are_synthetic": true, "original_results_reclassified": false,
		"native_policy_calls": 0, "physical_route_qualified": false, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
