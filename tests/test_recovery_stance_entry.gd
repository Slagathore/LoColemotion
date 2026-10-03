extends SceneTree
const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Route := Profile.WalkingPolicy.FiniteRoute.StanceEntry
const Source := preload("res://sdk/adapters/godot/gdscript/recovery_walking_entry_source_v1.gd")
const Replay := preload("res://sdk/adapters/godot/gdscript/recovery_stance_entry_replay_v1.gd")
const Fixture := preload("res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd")
const Entry := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_orchestrator_v1.gd")
const Transport := Replay.Transport
class Probe:
	extends "res://sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd"
	func _initialize() -> void: pass

var route_id := Route.ID
var neutral_id := Route.NEUTRAL_ID

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var selection := Profile.load_v1({"resource": args[0], "raw_sha256": args[1]})
	var probe := Probe.new()
	probe._candidate_selection = selection
	route_id = selection.get("diagnostic_schedule", {}).get("walking_policy_id", Route.ID)
	neutral_id = Route.entry_selection_for_v1(route_id)
	var checks := {"selection": not selection.is_empty()}
	if selection.is_empty():
		_finish(probe, checks, {})
		return
	if probe._r10k_selected_v1(): probe._seed = 40741 if probe._r10o_selected_v1() else 40641 if probe._r10n_selected_v1() else 40541 if probe._r10m_selected_v1() else 40441 if probe._r10l_selected_v1() else 40341 # Declared R10K prefix preflight, still zero worlds.
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(selection.worker_selection.binding))
	checks.runtime = probe._load_runtime_extension_v1()
	if not checks.runtime:
		_finish(probe, checks, {})
		return
	probe._sdk = ClassDB.instantiate("SporeLocomotionSdk")
	var sdk: Object = probe._sdk
	var input: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[2]))
	var frame_regression := _frame_regression_v1(sdk, input)
	checks.merge(frame_regression.checks)
	checks.neutral_worker_selection = probe._walking_policy_id_v1(Route.SEGMENT) == neutral_id and probe._walking_gait_amplitude_v1(Route.SEGMENT, 1) == 0.0 and probe._walking_session_step_limit_v1(Route.SEGMENT) == 240
	checks.neutral_native_alias = probe._walking_facade_evaluation_segment_v1(Route.SEGMENT) == "matched_continuation"
	var floor := Source.World.create_floor_v1()
	var arm: Dictionary = input.arm
	arm["model"] = {"floor": floor}
	var measured := probe._entry_measurement_v1(arm) if Route.ramped_selected_v1(route_id) else Source.capture_v1(sdk, arm, input.compiled, Route.task.stance_entry)
	checks.source_capture = measured.get("ok") == true
	var result := {"measurement": measured, "frame_regression": frame_regression, "worker_compiled": probe._entry_compiled, "fixture_compiled": input.compiled}
	if checks.source_capture:
		checks.source_replay = Replay.measurement_v1(sdk, measured, arm.trace_rows[-1], input.compiled, arm.model_instance_id, arm.body_population_instance_sha256, route_id).get("ok") == true
		for name in ["direct_digest", "clock", "population", "distal_trace", "readiness", "readiness_digest", "floor"]:
			var bad := measured.duplicate(true)
			match name:
				"direct_digest": bad.packet.direct_state_source.ordered_body_states[2].position_world_m.x += 0.1
				"clock": bad.packet.direct_state_source.semantic_step += 1
				"population": bad.packet.direct_state_source.ordered_body_states.pop_back()
				"distal_trace": bad.packet.native_source.precommand_trace.foot_position_world_m_by_limb.front_left[0] += 0.1
				"readiness": bad.readiness.ready = not bad.readiness.ready
				"readiness_digest": bad.readiness_sha256 = "sha256:"+"0".repeat(64)
				"floor": bad.packet.floor_source.floor_reference.height_world_m += 0.1
			checks["source_refuses_"+name] = Replay.measurement_v1(sdk, bad, arm.trace_rows[-1], input.compiled, arm.model_instance_id, arm.body_population_instance_sha256, route_id).get("ok") == false
	floor.free()
	var neutral := Fixture._walking_ledger_production_fixture_v2(sdk, 321, "walking_resume", "matched_continuation", Route.PHASE, "synthetic-fresh-neutral", neutral_id, true)
	checks.native_neutral_application = neutral.get("ok") == true
	result["native_fixture"] = neutral
	if checks.native_neutral_application:
		var step := {"ok": true, "session_id": neutral.session_id, "global_semantic_step": 321, "session_local_step": 1, "segment_id": "walking_resume"}
		for key in ["sample_receipt", "portable_step_receipt", "authority_application_receipt", "motor_population_readback", "walking_actuation_handoff_receipt", "ledger_application_intent"]: step[key] = neutral[key]
		var trace := {"global_semantic_step": 321, "walking_session_local_step": 1, "walking_session_id": step.session_id, "application_intent_sha256": Replay._sha(sdk, step.ledger_application_intent)}
		var session := {"session_id": step.session_id, "walking_actuation_handoff_receipt": neutral.walking_actuation_handoff_receipt, "step_receipt_sha256s": [Replay._sha(sdk, step)], "start_receipt": {"selected_policy_id": "sporespore_balanced_wave_bw5r_b_v1", "global_start_step": 320, "initial_gait_steps": Fixture.LocomotionFacade.initial_gait_steps_v1(40200, "walking_resume"), "task_frame_lateral_axis_world_host_real": [0.0, 0.0, 1.0]}}
		if Route.ramped_selected_v1(route_id):
			session.start_receipt.merge({"selected_policy_id": Route.FLEXED_NATIVE_ID, "development_walking_policy_id": neutral_id, "selected_policy_digest": Profile.WalkingPolicy.binding_v1(neutral_id, Route.SEGMENT).policy_digest, "controller_profile_sha256": Profile.WalkingPolicy.joint_entry_contract.native_profile_sha256}, true)
		var row := {"segment_id": Route.SEGMENT, "step": step, "full_step_receipt_sha256": Replay._sha(sdk, step)}
		var replayed := Replay.neutral_command_v1(sdk, row, trace, session, input.compiled.descriptor, {}, route_id)
		checks.native_neutral_replay = replayed.get("ok") == true
		result["native_replay"] = replayed
		for name in ["amplitude", "first_memory", "native_digest", "motor", "alias", "session", "frame"]:
			var bad := row.duplicate(true)
			var bad_session := session.duplicate(true)
			match name:
				"amplitude": bad.step.sample_receipt.request.command.gait_amplitude = 1.0
				"first_memory": bad.step.sample_receipt.request.memory.ordered_limb_memory[0].gait_step += 1
				"native_digest": bad.step.portable_step_receipt.native_step_transport_verification.raw_native_response_sha256 = "sha256:"+"0".repeat(64)
				"motor": bad.step.authority_application_receipt.ordered_applications[0].host_applied_target_velocity_rad_s += 0.1
				"alias": bad.step.walking_actuation_handoff_receipt.evaluation_segment_id = "walking_resume"
				"session": bad.step.session_id = "reused-prefix"
				"frame": bad.step.sample_receipt.request.state.task_frame.lateral_axis_world_unit.x += 0.01
			bad.full_step_receipt_sha256 = Replay._sha(sdk, bad.step)
			bad_session.step_receipt_sha256s[0] = bad.full_step_receipt_sha256
			checks["command_refuses_"+name] = Replay.neutral_command_v1(sdk, bad, trace, bad_session, input.compiled.descriptor, {}, route_id).get("ok") == false
		result["neutral_command_row"] = row
	var sha := "sha256:"+"a".repeat(64)
	var initial := (probe.R10K.initialize_v1(sdk, "synthetic-neutral-timeout", "matched_no_kick_continuation", "synthetic-model", sha, sha)
		if probe._r10k_selected_v1() else Entry.initialize_v1(sdk, "synthetic-neutral-timeout", "matched_no_kick_continuation", "synthetic-model", sha, sha, 240, probe._entry_controller_id_v1(), route_id))
	var state: Dictionary = initial.state
	# Synthetic checkpoint for the bounded phase. No observed state is edited.
	state.merge({"phase": Route.PHASE, "previous_global_semantic_step": 272, "total_completed_solver_step_count": 272, "state_revision": 272, "precondition_recovery_step_count": 240, "precondition_pair_ready": true, "precondition_pair_release_step_count": 1, "walking_prefix_step_count": 30, "prefix_walking_session_id": "prefix", "interaction_effect_step_count": 1, "epoch_start_global_step": 272, "interaction_receipt_sha256": sha, "energy_initializer_sha256": sha}, true)
	state.payload_sha256 = Entry.Prior._payload_sha256_v1(sdk, state)
	checks.timeout_initial_state = (probe.R10K.state_valid_v1(sdk, state) if probe._r10k_selected_v1()
		else Entry.state_valid_v1(sdk, state, probe._entry_controller_id_v1(), route_id))
	for index in range(1, 241):
		var fields := {"global_semantic_step": 272+index, "event_kind": "neutral_stance_entry_step", "control_owner": Route.entry_owner_for_v1(route_id), "actuation_owner": Route.entry_owner_for_v1(route_id), "walking_actuation_applied": true, "walking_session_id": "fresh-neutral", "walking_session_local_step": index, "recovery_epoch_local_step": index, "energy_initializer_sha256": sha, "application_intent_sha256": sha, "neutral_entry_readiness_sha256": sha, "neutral_entry_ready": (false if Route.hold_selected_v1(route_id) else index % 30 != 0)}
		var built := probe._build_orchestrator_event_v1(state, fields)
		if built.get("ok") != true:
			checks.timeout_event = false
			result["timeout_failure"] = built
			break
		var advanced := probe._advance_orchestrator_step_v1(state, built.event)
		if advanced.get("ok") != true:
			checks.timeout_advance = false
			result["timeout_failure"] = advanced
			break
		state = advanced.state_after
	checks.exact_timeout = state.phase == "failed" and state.neutral_entry_step_count == 240 and state.consecutive_neutral_ready == 0 and state.terminal_reason == "neutral_stance_entry_timeout"
	checks.timeout_has_no_v50_memory = state.resume_or_continuation_session_id.is_empty() and state.matched_continuation_step_count == 0
	checks.legacy_refuses_neutral_state = not Entry.state_valid_v1(sdk, state, probe._entry_controller_id_v1())
	result["timeout_state"] = state
	_finish(probe, checks, result)

func _frame_regression_v1(sdk: Object, input: Dictionary) -> Dictionary:
	var retained: Dictionary = input.retained_refusal
	var original: Dictionary = sdk.decode_exact_json_v1(retained.request.utf8_text)
	original.schema_version = "sporespore_balanced_wave_policy_step_request_v1"
	original["policy_id"] = "sporespore_balanced_wave_bw5r_b_v1"
	original["descriptor"] = input.compiled.descriptor
	var response: Dictionary = sdk.decode_exact_json_v1(sdk.balanced_wave_policy_step_json(Transport.stringify(original)))
	var checks := {"frame_original_refusal_reproduced": response.get("ok") == true and response.get("value", {}).get("actuation", {}).get("receipt", {}).get("controller_error") == retained.reported_native_controller_error}
	var results := {"checks": checks, "original_response": response}
	var start: Dictionary = input.retained_start
	var lateral: Array = start.task_frame_lateral_axis_world_host_real
	var origin: Array = start.task_frame_origin_world_m
	var frame := {"lateral": Vector3(lateral[0], lateral[1], lateral[2]), "legacy_yaw_rad": start.task_frame_initial_yaw_rad}
	var material: Dictionary = Fixture.MaterialProfiles.resolve(Fixture.LocomotionFacade.MATERIAL_PROFILE_ID).profile
	for selection in ["", Route.NEUTRAL_ID]:
		var label: String = "legacy" if selection.is_empty() else "neutral"
		var facade := Fixture.LocomotionFacade.new()
		var started := facade._start_adapter_from_frame_v1(frame, Vector3(origin[0], origin[1], origin[2]), start.initial_gait_steps, material, true, selection, "walking_resume")
		checks["frame_"+label+"_start"] = started.get("ok") == true
		if started.get("ok") != true: continue
		var generated: Dictionary = facade._adapter._perfect_synthetic_controller_state_frame(1, input.compiled.morphology).task_frame
		var request := original.duplicate(true)
		for axis in ["forward_axis_world_unit", "lateral_axis_world_unit", "up_axis_world_unit"]:
			request.state.task_frame[axis] = generated[axis]
		var output: Dictionary = sdk.decode_exact_json_v1(sdk.balanced_wave_policy_step_json(Transport.stringify(request)))
		results[label] = {"task_frame": request.state.task_frame, "response": output}
		if label == "legacy":
			checks.frame_legacy_axes_exact = Transport.stringify(request.state.task_frame) == Transport.stringify(original.state.task_frame)
			checks.frame_legacy_refusal_preserved = output.get("value", {}).get("actuation", {}).get("receipt", {}).get("controller_error") == retained.reported_native_controller_error
		else:
			var actuation: Dictionary = output.get("value", {}).get("actuation", {})
			checks.frame_neutral_native_accepts = output.get("ok") == true and actuation.get("safe_no_actuation") == false and actuation.get("failure_codes") == [] and actuation.get("receipt", {}).get("controller_error") == null
			var axes := Fixture.LocomotionFacade.neutral_task_frame_axes_v1(frame.lateral)
			checks.frame_neutral_reconstructible = true
			for axis in axes:
				checks.frame_neutral_reconstructible = checks.frame_neutral_reconstructible and Transport.stringify(axes[axis]) == Transport.stringify(generated[axis])
			var f: Dictionary = generated.forward_axis_world_unit
			var l: Dictionary = generated.lateral_axis_world_unit
			checks.frame_neutral_orthogonal = absf(f.x*l.x+f.z*l.z) <= 1e-15
		checks["frame_"+label+"_shutdown"] = facade._adapter.shutdown().get("ok") == true
	return results

func _finish(probe: Probe, checks: Dictionary, result: Dictionary) -> void:
	probe._sdk = null
	probe.free()
	print("R10H_STANCE_ENTRY_INTERFACES ", Transport.stringify({"ok": not checks.values().has(false), "checks": checks, "result": result, "synthetic_native_observations_only": true, "world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false}))
	quit(0 if not checks.values().has(false) else 1)
