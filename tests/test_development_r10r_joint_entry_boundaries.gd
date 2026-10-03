extends "res://sdk/trace_analysis/development_recovery_candidate_replay.gd"
## Retained observations and detached native sessions only; no world or step.
const EntryReplay := preload("res://sdk/adapters/godot/gdscript/recovery_stance_entry_replay_v1.gd")
const Route := EntryReplay.Route
const Facade := EntryReplay.Facade

func _dispatch(sdk: Object, input: Dictionary, _binding: Dictionary) -> Dictionary:
	var checks := {}
	var original_arm: Dictionary = input.arm
	var original_session: Dictionary = original_arm.walking_sessions[0]
	var original_bytes := EntryReplay.Transport.stringify(original_arm)
	var bound := EntryReplay.session_with_handoff_v1(original_arm, original_session, Route.FLEXED_ID)
	checks.handoff_actual_arm_location = bound.get("ok") == true and not original_session.has("walking_actuation_handoff_receipt") and bound.session.walking_actuation_handoff_receipt.walking_session_id == original_session.session_id
	for kind in ["missing", "duplicate", "crossed"]:
		var bad := original_arm.duplicate(true)
		if kind == "missing": bad.walking_actuation_handoff_receipts = []
		elif kind == "duplicate": bad.walking_actuation_handoff_receipts.append(bound.session.walking_actuation_handoff_receipt)
		else:
			for handoff in bad.walking_actuation_handoff_receipts: handoff.walking_session_id = "crossed"
		checks["handoff_refuses_"+kind] = EntryReplay.session_with_handoff_v1(bad, original_session, Route.FLEXED_ID).get("ok") == false
	checks.handoff_original_unmodified = EntryReplay.Transport.stringify(original_arm) == original_bytes
	var indices := EntryReplay.recovery_completion_indices_v1(input.kicked_transitions, Route.FLEXED_ID)
	checks.recovery_actual_completion = indices == [857]
	checks.recovery_legacy_phase_is_distinct = EntryReplay.recovery_completion_indices_v1(input.kicked_transitions, Route.ID).is_empty()
	var transitions: Array = input.kicked_transitions.duplicate(true)
	transitions[857].advance.next_phase = "walking_resume"
	checks.recovery_refuses_short_phase_alias = EntryReplay.recovery_completion_indices_v1(transitions, Route.FLEXED_ID).is_empty()
	var route_id: String = _candidate_selection.diagnostic_schedule.walking_policy_id
	var alias := Route.R10R.ENTRY_ALIAS if route_id == Route.R10R.ID else Route.R10N.ENTRY_ALIAS if route_id == Route.R10N.ID else Route.R10M.ENTRY_ALIAS if route_id == Route.R10M.ID else Route.R10L.ENTRY_ALIAS if route_id == Route.R10L.ID else Route.R10K.ENTRY_ALIAS if route_id == Route.R10K.ID else Route.FLEXED_NEUTRAL_ID
	checks.selected_entry_alias = Facade.DevelopmentWalkingPolicy.selected_id_v1(_candidate_selection, Route.SEGMENT) == alias
	var facade := Facade.new()
	var start: Dictionary = original_session.start_receipt
	var lateral: Array = start.task_frame_lateral_axis_world_host_real
	var origin: Array = start.task_frame_origin_world_m
	var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID).profile
	var started := facade._start_adapter_from_frame_v1({"lateral": Vector3(lateral[0], lateral[1], lateral[2]), "legacy_yaw_rad": start.task_frame_initial_yaw_rad}, Vector3(origin[0], origin[1], origin[2]), start.initial_gait_steps, material, true, alias, "walking_resume")
	checks.transport_real_adapter_start = started.get("ok") == true
	var count := 0
	var first_complete := 0
	var failure := {}
	if checks.transport_real_adapter_start:
		var memory: Dictionary = facade._adapter._memory.duplicate(true)
		for retained_request in input.requests:
			var request: Dictionary = retained_request.duplicate(true)
			request.memory = memory
			request.command.desired_planar_velocity_task_m_s = {"x": 0.0, "y": 0.0, "z": 0.0}
			var native: Dictionary = facade._adapter._call_balanced_wave_session_step_with_transport_verification(request, int(request.state.semantic_step))
			if native.get("ok") != true or native.get("value", {}).get("actuation", {}).get("safe_no_actuation") != false:
				failure = native
				break
			var pure := request.duplicate(true)
			pure.schema_version = "sporespore_balanced_wave_policy_step_request_v1"
			pure["descriptor"] = facade._adapter._descriptor
			pure["policy_id"] = Route.FLEXED_NATIVE_ID
			var raw: String = sdk.balanced_wave_policy_step_json(EntryReplay.Transport.stringify(pure))
			var decoded: Dictionary = sdk.decode_exact_json_v1(raw)
			if "sha256:"+raw.sha256_text() != native.native_step_transport_verification.raw_native_response_sha256 or not EntryReplay._same(decoded.get("value"), native.value):
				failure = {"reason": "cached_stateless_transport_crossed", "command": count+1}
				break
			memory = native.value.next_memory
			count += 1
			if first_complete == 0 and memory.joint_pose_entry.reference_ramp_complete: first_complete = count
		checks.transport_shutdown = facade._adapter.shutdown().get("ok") == true
	checks.transport_all_retained_observations = count == 240 and input.requests.size() == 240
	checks.transport_ramp_completes_within_bound = first_complete > 1 and first_complete < 240
	return {"ok": not checks.values().has(false), "checks": checks, "native_commands": count, "first_complete_command": first_complete, "failure": failure, "counterfactual_commands_on_retained_states": true, "world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
