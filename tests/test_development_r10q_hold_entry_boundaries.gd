extends "res://sdk/trace_analysis/development_recovery_candidate_replay.gd"
## Selected settled hold: retained R10I observations and a detached native V50 hold session only; no world or step.
const EntryReplay := preload("res://sdk/adapters/godot/gdscript/recovery_stance_entry_replay_v1.gd")
const Route := EntryReplay.Route
const Facade := EntryReplay.Facade
const Entry := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_orchestrator_v1.gd")
const SHA := "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

func _dispatch(sdk: Object, input: Dictionary, _binding: Dictionary) -> Dictionary:
	var checks := {}
	var route_id: String = _candidate_selection.diagnostic_schedule.walking_policy_id
	var hold_alias := Route.R10Q.HOLD_ALIAS if route_id == Route.R10Q.ID else Route.R10N.HOLD_ALIAS if route_id == Route.R10N.ID else Route.R10M.HOLD_ALIAS if route_id == Route.R10M.ID else Route.R10L.HOLD_ALIAS if route_id == Route.R10L.ID else Route.R10K.HOLD_ALIAS if route_id == Route.R10K.ID else Route.HOLD_ALIAS
	var entry_alias := Route.R10Q.ENTRY_ALIAS if route_id == Route.R10Q.ID else Route.R10N.ENTRY_ALIAS if route_id == Route.R10N.ID else Route.R10M.ENTRY_ALIAS if route_id == Route.R10M.ID else Route.R10L.ENTRY_ALIAS if route_id == Route.R10L.ID else Route.R10K.ENTRY_ALIAS if route_id == Route.R10K.ID else Route.FLEXED_NEUTRAL_ID
	var original_arm: Dictionary = input.arm
	var original_session: Dictionary = original_arm.walking_sessions[0]
	var original_bytes := EntryReplay.Transport.stringify(original_arm)
	var bound := EntryReplay.session_with_handoff_v1(original_arm, original_session, Route.HOLD_ID)
	checks.handoff_actual_arm_location = bound.get("ok") == true and bound.session.walking_actuation_handoff_receipt.walking_session_id == original_session.session_id
	for kind in ["missing", "duplicate", "crossed"]:
		var bad := original_arm.duplicate(true)
		if kind == "missing": bad.walking_actuation_handoff_receipts = []
		elif kind == "duplicate": bad.walking_actuation_handoff_receipts.append(bound.session.walking_actuation_handoff_receipt)
		else:
			for handoff in bad.walking_actuation_handoff_receipts: handoff.walking_session_id = "crossed"
		checks["handoff_refuses_"+kind] = EntryReplay.session_with_handoff_v1(bad, original_session, Route.HOLD_ID).get("ok") == false
	checks.handoff_original_unmodified = EntryReplay.Transport.stringify(original_arm) == original_bytes
	checks.recovery_actual_completion = EntryReplay.recovery_completion_indices_v1(input.kicked_transitions, Route.HOLD_ID) == [857]
	var policy := Facade.DevelopmentWalkingPolicy.binding_v1(hold_alias, Route.HOLD_SEGMENT)
	checks.hold_binding_is_unchanged_v50 = (policy.get("policy_id") == Facade.DevelopmentWalkingPolicy.STARTUP_VELOCITY_POLICY_ID and policy.get("development") == true
		and policy.get("policy_digest") == "sha256:" + FileAccess.get_sha256(Route.R10Q.HOLD_PATH if route_id == Route.R10Q.ID else Route.R10N.HOLD_PATH if route_id == Route.R10N.ID else Route.R10M.HOLD_PATH if route_id == Route.R10M.ID else Route.R10L.HOLD_PATH if route_id == Route.R10L.ID else Route.R10K.HOLD_PATH if route_id == Route.R10K.ID else Route.HOLD_PATH))
	checks.hold_binding_refuses_prefix_segment = Facade.DevelopmentWalkingPolicy.binding_v1(hold_alias, "walking_prefix").is_empty()
	checks.hold_alias_selected_only_for_hold_segment = (Facade.DevelopmentWalkingPolicy.selected_id_v1(_candidate_selection, Route.HOLD_SEGMENT) == hold_alias
		and Facade.DevelopmentWalkingPolicy.selected_id_v1(_candidate_selection, Route.SEGMENT) == entry_alias
		and Facade.DevelopmentWalkingPolicy.selected_id_v1(_candidate_selection, "walking_resume") == route_id)
	# Detached native V50 hold session on the retained R10I flexed end states. Counterfactual only.
	var facade := Facade.new()
	# V50 is floor-referenced: bind an actual static floor body without any creature or solver step.
	var floor: StaticBody3D = Facade.RecoveryWorld.create_floor_v1()
	facade._binding = {"floor": floor, "model_instance_id": "r10j-zero-world-body"}
	var start: Dictionary = original_session.start_receipt
	var lateral: Array = start.task_frame_lateral_axis_world_host_real
	var origin: Array = start.task_frame_origin_world_m
	var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID).profile
	var started := facade._start_adapter_from_frame_v1({"lateral": Vector3(lateral[0], lateral[1], lateral[2]), "legacy_yaw_rad": start.task_frame_initial_yaw_rad}, Vector3(origin[0], origin[1], origin[2]), start.initial_gait_steps, material, true, hold_alias, "walking_resume")
	checks.transport_real_adapter_start = started.get("ok") == true
	var failure := {}
	if not checks.transport_real_adapter_start: failure = {"reason": "adapter_start", "started": started}
	checks.transport_stationary_hold_flag = checks.transport_real_adapter_start and facade._adapter._development_stationary_hold == true
	var count := 0
	var first_error := 0.0
	var last_error := 0.0
	if checks.transport_real_adapter_start:
		var memory: Dictionary = facade._adapter._memory.duplicate(true)
		var t0: float = input.requests[0].state.sample_time_s
		for index in range(input.requests.size()):
			var retained_request: Dictionary = input.requests[index]
			var frame_source: Dictionary = input.frames[index]
			# Same-instant pair: the readiness projection's measured state and body frame, under the
			# retained ramp session's task frame and adapter capability, re-based to the hold clock.
			var request: Dictionary = retained_request.duplicate(true)
			request.state = frame_source.state.duplicate(true)
			request.state.task_frame = retained_request.state.task_frame.duplicate(true)
			request.state.adapter_capability_sha256 = retained_request.state.adapter_capability_sha256
			request.memory = memory
			request.schema_version = "sporespore_balanced_wave_policy_session_step_request_v3"
			request.command.gait_amplitude = 0.0
			request.command.desired_planar_velocity_task_m_s = {"x": 0.0, "y": 0.0, "z": 0.0}
			request.state.semantic_step = index + 1
			request.state.sample_time_s = t0 + float(index) / 120.0
			request.command.valid_from_step = index + 1
			request.command.valid_through_step = index + 1
			request["floor_reference"] = frame_source.floor_reference
			var body: Dictionary = frame_source.measured_body_frame.duplicate(true)
			body.semantic_step = request.state.semantic_step
			body.sample_time_s = request.state.sample_time_s
			body.adapter_capability_sha256 = request.state.adapter_capability_sha256
			request["measured_body_frame"] = body
			var native: Dictionary = facade._adapter._call_balanced_wave_session_step_with_transport_verification(request, int(request.state.semantic_step))
			if native.get("ok") != true or native.get("value", {}).get("actuation", {}).get("safe_no_actuation") != false:
				failure = native
				break
			var pure := request.duplicate(true)
			pure.schema_version = "sporespore_balanced_wave_policy_step_request_v3"
			pure["descriptor"] = facade._adapter._descriptor
			pure["policy_id"] = Facade.DevelopmentWalkingPolicy.STARTUP_VELOCITY_POLICY_ID
			var raw: String = sdk.balanced_wave_policy_step_json(EntryReplay.Transport.stringify(pure))
			# V50 responses are parsed the same way the production adapter parses them; the raw bytes are compared exactly.
			var decoded: Variant = JSON.parse_string(raw)
			var raw_equal: bool = "sha256:"+raw.sha256_text() == native.native_step_transport_verification.raw_native_response_sha256
			if not raw_equal or not (decoded is Dictionary) or not EntryReplay._same(decoded.get("value"), native.value):
				failure = {"reason": "cached_stateless_transport_crossed", "command": count+1, "raw_equal": raw_equal}
				break
			var error := 0.0
			for joint_index in range(8):
				error = maxf(error, absf(native.value.actuation.ordered_commands[joint_index].clamped_target_position_rad - request.state.ordered_joint_observations[joint_index].position_rad))
			if count == 0: first_error = error
			last_error = error
			memory = native.value.next_memory
			count += 1
		checks.transport_shutdown = facade._adapter.shutdown().get("ok") == true
	floor.free()
	checks.transport_all_retained_observations = count == input.requests.size() and count == input.expected_count and count >= 60
	# V50's canonical initial memory targets neutral joints; the hold must pull the targets back onto the measured flexed pose.
	checks.transport_targets_converge_to_measured_flexed_pose = checks.transport_all_retained_observations and first_error > 0.5 and last_error < 0.15 and last_error * 3.0 < first_error
	# Real scheduler: ramp closes on its ready event, the separate hold dwells for thirty ready samples, and both budgets stop exactly.
	var probe := Probe.new()
	probe._candidate_selection = _candidate_selection
	probe._sdk = sdk
	var controller: String = _candidate_selection.post_kick_controller_id
	checks.merge(_scheduler_checks_v1(sdk, probe, controller))
	probe._sdk = null
	probe.free()
	return {"ok": not checks.values().has(false), "checks": checks, "native_commands": count, "first_target_error_rad": first_error, "last_target_error_rad": last_error, "failure": failure,
		"counterfactual_commands_on_retained_states": true, "world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}

class Probe:
	extends "res://sdk/adapters/godot/gdscript/r10q_recovery_worker_v1.gd"
	func _initialize() -> void: pass

static func _entry_state_v1(sdk: Object, probe: Probe, controller: String, label: String) -> Dictionary:
	var initial := (probe.R10Q.initialize_v1(sdk, "synthetic-"+label, "matched_no_kick_continuation", "synthetic-model", SHA, SHA)
		if probe._r10k_selected_v1() else Entry.initialize_v1(sdk, "synthetic-"+label, "matched_no_kick_continuation", "synthetic-model", SHA, SHA, 240, controller, Route.HOLD_ID))
	var state: Dictionary = initial.state
	state.merge({"phase": Route.PHASE, "previous_global_semantic_step": 272, "total_completed_solver_step_count": 272, "state_revision": 272, "precondition_recovery_step_count": 240, "precondition_pair_ready": true, "precondition_pair_release_step_count": 1,
		"precondition_pair_wait_step_count": 0, "walking_prefix_step_count": 30, "prefix_walking_session_id": "synthetic-prefix", "interaction_effect_step_count": 1, "interaction_receipt_sha256": SHA, "energy_initializer_sha256": SHA, "epoch_start_global_step": 272, "recovery_epoch_step_count": 0}, true)
	state.payload_sha256 = Entry.Prior._payload_sha256_v1(sdk, state)
	return state

static func _entry_event_v1(probe: Probe, state: Dictionary, kind: String, session: String, local_step: int, ready: bool) -> Dictionary:
	var fields := {"global_semantic_step": state.previous_global_semantic_step + 1, "event_kind": kind, "control_owner": Route.entry_owner_for_v1(Route.R10Q.ID), "actuation_owner": Route.entry_owner_for_v1(Route.R10Q.ID), "walking_actuation_applied": true,
		"walking_session_id": session, "walking_session_local_step": local_step, "recovery_epoch_local_step": state.previous_global_semantic_step + 1 - state.epoch_start_global_step,
		"energy_initializer_sha256": SHA, "application_intent_sha256": SHA, "neutral_entry_readiness_sha256": SHA, "neutral_entry_ready": ready}
	var built := probe._build_orchestrator_event_v1(state, fields)
	if built.get("ok") != true: return built
	return probe._advance_orchestrator_step_v1(state, built.event)

static func _scheduler_checks_v1(sdk: Object, probe: Probe, controller: String) -> Dictionary:
	var checks := {}
	var state := _entry_state_v1(sdk, probe, controller, "hold-dwell")
	checks.scheduler_initial_state = (probe.R10Q.state_valid_v1(sdk, state) if probe._r10k_selected_v1() else Entry.state_valid_v1(sdk, state, controller, Route.HOLD_ID))
	var advanced := _entry_event_v1(probe, state, Route.HOLD_EVENT, "fresh-hold", 1, true)
	checks.scheduler_refuses_hold_before_ramp = advanced.get("ok") != true
	for index in range(1, 4):
		advanced = _entry_event_v1(probe, state, "neutral_stance_entry_step", "fresh-ramp", index, index == 3)
		if advanced.get("ok") != true: break
		state = advanced.state_after
	checks.scheduler_ramp_closes_on_ready = advanced.get("ok") == true and state.entry_ramp_complete == true and state.neutral_entry_step_count == 3 and state.phase == Route.PHASE
	checks.scheduler_refuses_ramp_after_completion = _entry_event_v1(probe, state, "neutral_stance_entry_step", "fresh-ramp", 4, true).get("ok") != true
	checks.scheduler_refuses_hold_reusing_ramp_session = _entry_event_v1(probe, state, Route.HOLD_EVENT, "fresh-ramp", 1, true).get("ok") != true
	var ready_count := 0
	for index in range(1, 61):
		var ready := index != 20
		advanced = _entry_event_v1(probe, state, Route.HOLD_EVENT, "fresh-hold", index, ready)
		if advanced.get("ok") != true: break
		state = advanced.state_after
		ready_count = state.consecutive_neutral_ready
		if state.phase != Route.PHASE: break
	checks.scheduler_dwell_resets_and_hands_off_after_thirty = advanced.get("ok") == true and state.phase == "matched_no_kick_continuation" and state.hold_entry_step_count == 50 and ready_count == 30 and state.consecutive_neutral_ready == 30
	checks.scheduler_handoff_state_valid = (probe.R10Q.state_valid_v1(sdk, state) if probe._r10k_selected_v1() else Entry.state_valid_v1(sdk, state, controller, Route.HOLD_ID))
	var timeout_state := _entry_state_v1(sdk, probe, controller, "hold-timeout")
	advanced = _entry_event_v1(probe, timeout_state, "neutral_stance_entry_step", "fresh-ramp", 1, true)
	timeout_state = advanced.state_after if advanced.get("ok") == true else timeout_state
	for index in range(1, 241):
		advanced = _entry_event_v1(probe, timeout_state, Route.HOLD_EVENT, "fresh-hold", index, false)
		if advanced.get("ok") != true: break
		timeout_state = advanced.state_after
	checks.scheduler_hold_timeout_exact = advanced.get("ok") == true and timeout_state.phase == "failed" and timeout_state.terminal_reason == "v50_hold_entry_timeout" and timeout_state.hold_entry_step_count == 240 and timeout_state.consecutive_neutral_ready == 0
	checks.scheduler_timeout_has_no_v50_memory = timeout_state.resume_or_continuation_session_id.is_empty() and timeout_state.matched_continuation_step_count == 0
	var ramp_timeout := _entry_state_v1(sdk, probe, controller, "ramp-timeout")
	for index in range(1, 241):
		advanced = _entry_event_v1(probe, ramp_timeout, "neutral_stance_entry_step", "fresh-ramp", index, false)
		if advanced.get("ok") != true: break
		ramp_timeout = advanced.state_after
	checks.scheduler_ramp_timeout_exact = advanced.get("ok") == true and ramp_timeout.phase == "failed" and ramp_timeout.terminal_reason == "neutral_stance_entry_timeout" and ramp_timeout.neutral_entry_step_count == 240 and ramp_timeout.hold_entry_step_count == 0
	checks.scheduler_r10i_reader_refuses_hold_state = not Entry.state_valid_v1(sdk, state, controller, Route.FLEXED_ID)
	return checks
