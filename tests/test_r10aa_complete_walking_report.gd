extends "res://tests/test_r10aa_complete_hold_report.gd"
## Complete synthetic kicked timeline through a fresh post-hold V56 session.
## Native session stepping and worker publication are real; poses are supplied.
const HoldFixture := preload("res://tests/test_r10aa_complete_hold_report.gd")
class WalkingProbe:
	extends HoldFixture.HoldProbe
	var supplied_native_source := {}
	func _walking_native_contact_source_v1(_arm: Dictionary, segment: String) -> Dictionary:
		return supplied_native_source if segment == "walking_resume" else {}

func _new_fixture_probe_v1() -> SceneTree:
	return WalkingProbe.new()

func _exercise_hold(probe: SceneTree) -> Dictionary:
	var held := super._exercise_hold(probe)
	if not held.is_empty(): return held
	var segment: Dictionary = _hold_input.walking_segment
	var opened := _open_synthetic_session(probe, segment)
	if opened.get("ok") != true: return opened
	for index in range(segment.samples.size()):
		var arm: Dictionary = probe._arms[ARM]
		arm.facade.supplied_sample = segment.samples[index]
		var global_step: int = arm.active_walking_session.start_receipt.global_start_step + index + 1
		# The first walking input observes the exact final hold sample. A copied
		# predecessor walking sample has different synthetic velocity and must
		# never replace that already-retained hold trace or its readiness source.
		probe.supplied_native_source = (probe._post_recovery_hold_readiness_rows[-1].source.packet.native_source.duplicate(true)
			if index == 0 else _native_source(probe, segment.native_sources[index], arm.trace_rows[-1], arm))
		var applied: Dictionary = probe._apply_next_walking_step_v1(ARM, global_step - 1)
		if applied.get("ok") != true: return applied
		arm = probe._arms[ARM]
		var trace: Dictionary = segment.traces[index].duplicate(true)
		trace.global_semantic_step = global_step
		trace.arm_id = ARM
		trace.orchestrator_phase = arm.orchestrator_state.phase
		trace.walking_segment_id = "walking_resume"
		trace.walking_session_local_step = index + 1
		trace.application_intent_sha256 = probe._canonical_sha256_v1(arm.pending_application)
		trace.walking_session_id = arm.active_walking_session.session_id
		trace.body_population_instance_sha256 = SHA
		trace.synthetic_test_fixture = true
		arm.trace_rows.append(trace)
		probe._arms[ARM] = arm
		var state: Dictionary = arm.orchestrator_state
		var fields := {"global_semantic_step": global_step, "event_kind": "walking_policy_step",
			"recovery_epoch_local_step": global_step - state.epoch_start_global_step,
			"control_owner": probe._walking_owner_for_phase_v1(state.phase),
			"actuation_owner": probe._walking_owner_for_phase_v1(state.phase), "walking_actuation_applied": true,
			"application_intent_sha256": trace.application_intent_sha256,
			"walking_session_id": trace.walking_session_id, "walking_session_local_step": index + 1}
		var built: Dictionary = probe._build_orchestrator_event_v1(state, fields)
		var processed: Dictionary = probe._install_orchestrator_event_v1(ARM, state, arm.pending_application, {}, null, built)
		if processed.get("ok") != true: return processed
		var post := _native_source(probe, segment.post_sources[index], trace, arm)
		var row: Dictionary = probe._walking_control_sources[-1]
		var cycle: Dictionary = probe.CycleStop.advance_v1(probe._cycle_stop_memory, row, post)
		if cycle.get("ok") != true: return cycle
		probe._cycle_stop_memory = cycle.next_memory
		probe._cycle_stop_sources.append({"session_local_step": index + 1,
			"full_step_receipt_sha256": row.full_step_receipt_sha256, "post_native_source": post, "advance_receipt": cycle})
	var closed: Dictionary = probe._finish_walking_session_v1(ARM)
	if closed.get("ok") != true: return closed
	var repeated: Dictionary = probe._finish_walking_session_v1(ARM)
	checks.walking_session_closed_once = closed.get("session_closed") == true and repeated.get("session_closed") == false
	checks.walking_two_commands_retained = probe._walking_control_sources.size() == 2
	checks.walking_did_not_reset_kick_epoch = probe._arms[ARM].orchestrator_state.epoch_start_global_step == 272
	return {}

func _open_synthetic_session(probe: SceneTree, segment: Dictionary) -> Dictionary:
	if segment.id == POST: return super._open_synthetic_session(probe, segment)
	var arm: Dictionary = probe._arms[ARM]
	var facade := HoldFacade.new()
	_facades.append(facade)
	var alias: String = probe._walking_policy_id_v1(segment.id)
	var start: Dictionary = segment.start.duplicate(true)
	start.global_start_step = arm.orchestrator_state.previous_global_semantic_step
	var lateral: Array = start.task_frame_lateral_axis_world_host_real
	var forward: Array = start.task_frame_forward_axis_world_host_real
	var origin: Array = start.task_frame_origin_world_m
	var phases := Facade.initial_gait_steps_v1(probe._seed, "walking_resume", probe._walking_start_profile_id_v1(segment.id))
	facade._binding = {"floor": _floor, "model_instance_id": arm.model_instance_id, "joint_nodes": {}, "joint_state_by_legacy_id": {}}
	var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID).profile
	var started := facade._start_adapter_from_frame_v1({"lateral": Vector3(lateral[0], lateral[1], lateral[2]),
		"forward": Vector3(forward[0], forward[1], forward[2]), "legacy_yaw_rad": start.task_frame_initial_yaw_rad},
		Vector3(origin[0], origin[1], origin[2]), phases, material, true, alias, "walking_resume")
	if started.get("ok") != true: return started
	var caps := Facade.walking_host_cap_projection_binding_v1(probe._sdk)
	for index in range(8):
		var joint := HingeJoint3D.new()
		_hinges.append(joint)
		var actuator: String = Facade.RecoveryRoute.ORDERED_ACTUATOR_IDS[index]
		joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, caps.selected_host_cap_by_actuator_id[actuator])
		facade._binding.joint_nodes[Facade.JOINT_IDS[index]] = joint
		facade._binding.joint_state_by_legacy_id[facade._adapter._legacy_joint_id_for_actuator(actuator)] = {"joint": joint}
	facade._started = true
	facade._session_id = "synthetic-r10aa:" + probe._attempt_id + ":" + segment.id
	facade._segment_id = "walking_resume"
	facade._global_start_step = int(start.global_start_step)
	facade._initial_gait_steps = phases
	facade._development_walking_policy_id = alias
	var handoff := facade.begin_walking_actuation_handoff_v1(probe._sdk, "walking_resume", facade._global_start_step + 1)
	if handoff.get("ok") != true: return handoff
	var policy := Facade.DevelopmentWalkingPolicy.binding_v1(alias, segment.id)
	start.session_id = facade._session_id
	start.schema_version = Facade.DevelopmentWalkingPolicy.schema_v1(Facade.SESSION_SCHEMA, "session", policy)
	start.model_instance_id = arm.model_instance_id
	start.initial_gait_steps = phases
	start.selected_policy_id = policy.policy_id
	start.selected_policy_digest = policy.policy_digest
	start.development_walking_policy_id = alias
	start.controller_profile_sha256 = started.controller_profile_sha256
	start.synthetic_test_fixture = true
	start.development_walking_start_profile_id = probe._walking_start_profile_id_v1(segment.id)
	start.gait_phase_seed = probe._seed
	if Facade.DevelopmentWalkingPolicy.floor_selected_v1(alias): start.development_floor_source = facade._adapter._development_floor_source.duplicate(true)
	arm.facade = facade
	arm.walking_actuation_handoff_receipts.append(handoff)
	arm.active_walking_session = {"evaluation_segment_id": segment.id, "facade_segment_id": "walking_resume",
		"session_id": facade._session_id, "start_receipt": start, "walking_actuation_handoff_receipt": handoff,
		"initial_contact_by_limb": segment.initial_contact_by_limb, "trace_start_index": arm.trace_rows.size(),
		"scheduled_step_count": 0, "step_receipt_sha256s": []}
	arm.walking_session_completion_attempted = false
	probe._arms[ARM] = arm
	return {"ok": true}
