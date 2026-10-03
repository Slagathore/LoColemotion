extends "res://tests/test_development_r10t_report_fixture.gd"
# gdlint: disable=max-line-length
## Counterfactual retained measurements, fresh native sessions and real worker
## retention/finalization. No live sampler, physical trajectory or acceptance.
const Facade := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd")
const EntryReplay := preload("res://sdk/adapters/godot/gdscript/r10t_stance_entry_replay_v1.gd")
const ROLE := "matched_no_kick_continuation"

class PreparationProbe:
	extends "res://sdk/adapters/godot/gdscript/r10t_recovery_worker_v1.gd"
	var supplied_measurement := {}
	var supplied_native_source := {}
	func _initialize() -> void:
		pass
	func _attach_profile_seed_context_v1(report: Dictionary) -> bool:
		# Isolate publication from a deliberately unavailable launch prerequisite.
		# The real production guard MUST refuse this synthetic declaration.
		if R10TSeed.attach_report_context_v1(report, _campaign_declaration, _seed): return false
		if report.get("synthetic_test_fixture") != true or report.get("arm_id") != "matched_no_kick_continuation": return false
		var identity := R10TSeed.seed_identity_v1(_seed)
		report.r10t_development = _campaign_declaration.r10t_development.duplicate(true)
		report.seed_label = identity.label
		report.seed_sha256 = identity.sha256
		report.held_out = false
		report.held_out_cell_access_count = 0
		report.synthetic_launch_prerequisite_standin = true
		return true
	func _entry_measurement_v1(_arm: Dictionary) -> Dictionary:
		return supplied_measurement
	func _walking_native_contact_source_v1(_arm: Dictionary, segment: String) -> Dictionary:
		return supplied_native_source if segment == "matched_continuation" else {}

class MeasuredFacade:
	extends "res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd"
	var supplied_sample := {}
	func _sample_walking_input_v1(local_step: int, amplitude: float, phase_mode: String) -> Dictionary:
		# Only the input sampler is synthetic. Adapter.step, motor application,
		# native transport, ledger production and shutdown execute normally.
		var sample: Dictionary = supplied_sample.duplicate(true)
		var request: Dictionary = sample.request
		request.memory = _adapter._memory.duplicate(true)
		request.state.adapter_capability_sha256 = _adapter._adapter_capability_sha256
		request.state.semantic_step = local_step
		request.command.valid_from_step = local_step
		request.command.valid_through_step = local_step
		request.command.gait_amplitude = amplitude
		request.command.phase_progression_mode = phase_mode
		if request.has("measured_body_frame"):
			request.measured_body_frame.adapter_capability_sha256 = request.state.adapter_capability_sha256
		if request.has("floor_reference"):
			request.floor_reference = _adapter._development_floor_source.floor_reference.duplicate(true)
			sample["development_floor_source"] = _adapter._development_floor_source.duplicate(true)
		return sample
	func sample_step_apply_v1(sdk: Object, global_step: int, local_step: int, phase: String,
		amplitude: float = 1.0, native_source: Dictionary = {}, phase_mode: String = "contact_gated") -> Dictionary:
		# Live callback preparation has separate interface coverage. Here its
		# source is the declared retained population, independently checked below.
		var result := super.sample_step_apply_v1(sdk, global_step, local_step, phase, amplitude, {}, phase_mode)
		if result.get("ok") == true and not native_source.is_empty():
			if not NativeWalkingContacts.source_valid_v1(sdk, native_source, global_step, _binding.model_instance_id, native_source.body_population_instance_sha256):
				return {"ok": false, "failure_code": "R10T_FIXTURE_NATIVE_SOURCE"}
			result.sample_receipt["development_native_contact_source"] = native_source.duplicate(true)
		return result

var _input := {}
var _hinges: Array[HingeJoint3D] = []
var _floor: StaticBody3D
var _facades: Array = []
var _original_policy_validation := {}

func _initialize() -> void:
	call_deferred("_run_preparation")

func _run_preparation() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	_output = args[1]
	var declared := _declared_v1()
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(declared.candidate_profile.resource))
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old):
		GDExtensionManager.unload_extension(old)
	if GDExtensionManager.load_extension(profile.extension) != GDExtensionManager.LOAD_STATUS_OK:
		quit(1); return
	var probe := PreparationProbe.new()
	probe._sdk = ClassDB.instantiate("SporeLocomotionSdk")
	_input = probe._sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	# Exercise the policy reader on the unmodified retained predecessor session
	# population too. This is an interface regression check, never a regrading.
	_original_policy_validation = Facade.DevelopmentWalkingPolicy.validate_report_v1(_input.original_policy_report, EntryReplay.Route.HOLD_ID)
	if _original_policy_validation.get("ok") != true: _complete_preparation(probe, _original_policy_validation); return
	_configure_fixture_probe_v1(probe, declared.candidate_profile.resource)
	probe._authorized_arm_id = ROLE
	probe._attempt_id = declared.children[0].child_attempt_id
	probe._seed = int(declared.seed)
	probe._declared_after_interaction_steps = probe._entry_after_interaction_steps_v1()
	_floor = Facade.RecoveryWorld.create_floor_v1()
	var prefix := _prefix_v1(probe, ROLE, probe._attempt_id)
	if prefix.get("ok") != true: _complete_preparation(probe, prefix); return
	var event := R10T.build_event_v1(probe._sdk, prefix.state, {"global_semantic_step": 272,
		"event_kind": "matched_no_kick_effect_step", "application_intent_sha256": SHA, "no_actuation_requested": true,
		"interaction_receipt_sha256": SHA, "energy_initializer_sha256": SHA, "walking_motors_disabled_in_same_pre_solver_event": true})
	var advanced := R10T.advance_v1(probe._sdk, prefix.state, event.event)
	if advanced.get("ok") != true: _complete_preparation(probe, advanced); return
	prefix.transitions.append({"state_before": prefix.state, "event": event.event, "advance": advanced})
	probe._entry_transitions = prefix.transitions
	var traces := []
	for transition in prefix.transitions:
		traces.append({"global_semantic_step": transition.event.global_semantic_step, "arm_id": ROLE,
			"orchestrator_phase": transition.event.source_phase, "application_intent_sha256": transition.event.application_intent_sha256})
	var arm := {"arm_id": ROLE, "model_instance_id": Sources.Prior.MODEL_INSTANCE_ID, "body_population_instance_sha256": SHA,
		"orchestrator_state": advanced.state_after, "trace_rows": traces, "walking_sessions": [], "active_walking_session": {},
		"walking_actuation_handoff_receipts": [], "last_collection": {}, "body_population_rebuild_count": 0,
		"body_transform_write_count": 0, "body_velocity_write_count": 0, "solver_reset_count": 0,
		"direct_torso_force_command_count": 0, "direct_torso_impulse_command_count": 0,
		"direct_torso_velocity_command_count": 0, "direct_torso_transform_command_count": 0}
	probe._arms[ROLE] = arm
	for segment in _input.segments:
		var started := _open_synthetic_session(probe, segment)
		if started.get("ok") != true: _complete_preparation(probe, started); return
		for index in range(segment.samples.size()):
			arm = probe._arms[ROLE]
			var facade: MeasuredFacade = arm.facade
			facade.supplied_sample = segment.samples[index]
			var global_step: int = arm.active_walking_session.start_receipt.global_start_step + index + 1
			if segment.id == "matched_continuation":
				probe.supplied_native_source = _native_source(probe, segment.native_sources[index], arm.trace_rows[-1], arm)
			var applied: Dictionary = probe._apply_next_walking_step_v1(ROLE, global_step - 1)
			if applied.get("ok") != true: _complete_preparation(probe, applied); return
			arm = probe._arms[ROLE]
			var trace: Dictionary = segment.traces[index].duplicate(true)
			trace.global_semantic_step = global_step
			trace.walking_session_local_step = index + 1
			trace.application_intent_sha256 = probe._canonical_sha256_v1(arm.pending_application)
			trace.walking_session_id = arm.active_walking_session.session_id
			trace.body_population_instance_sha256 = SHA
			trace["synthetic_test_fixture"] = true
			arm.trace_rows.append(trace)
			probe._arms[ROLE] = arm
			if segment.id != "matched_continuation":
				var measured := _measurement(probe, segment.readiness[index], trace, arm)
				if measured.get("ok") != true: _complete_preparation(probe, measured); return
				probe.supplied_measurement = measured
				var processed: Dictionary = probe._process_completed_arm_step_v1(ROLE, global_step, false)
				if processed.get("ok") != true: _complete_preparation(probe, processed); return
				if probe._arms[ROLE].active_walking_session.is_empty(): break
			else:
				var state: Dictionary = arm.orchestrator_state
				var fields := {"global_semantic_step": global_step, "event_kind": "matched_continuation_step",
					"recovery_epoch_local_step": global_step - state.epoch_start_global_step,
					"control_owner": probe._walking_owner_for_phase_v1(state.phase), "actuation_owner": probe._walking_owner_for_phase_v1(state.phase),
					"walking_actuation_applied": true, "application_intent_sha256": trace.application_intent_sha256,
					"walking_session_id": trace.walking_session_id, "walking_session_local_step": index + 1}
				var built: Dictionary = probe._build_orchestrator_event_v1(state, fields)
				var processed: Dictionary = probe._install_orchestrator_event_v1(ROLE, state, arm.pending_application, {}, null, built)
				if processed.get("ok") != true: _complete_preparation(probe, processed); return
				var post := _native_source(probe, segment.post_sources[index], trace, arm)
				var row: Dictionary = probe._walking_control_sources[-1]
				var cycle := probe.CycleStop.advance_v1(probe._cycle_stop_memory, row, post)
				if cycle.get("ok") != true: _complete_preparation(probe, cycle); return
				probe._cycle_stop_memory = cycle.next_memory
				probe._cycle_stop_sources.append({"session_local_step": index + 1, "full_step_receipt_sha256": row.full_step_receipt_sha256,
					"post_native_source": post, "advance_receipt": cycle})
		if segment.id == "matched_continuation":
			var closed: Dictionary = probe._finish_walking_session_v1(ROLE)
			if closed.get("ok") != true: _complete_preparation(probe, closed); return
		if not probe._arms[ROLE].active_walking_session.is_empty():
			_complete_preparation(probe, {"ok": false, "failure_code": "R10T_FIXTURE_SESSION_DID_NOT_CLOSE", "segment": segment.id}); return
		var repeated: Dictionary = probe._finish_walking_session_v1(ROLE)
		if repeated.get("ok") != true or repeated.get("session_closed") != false:
			_complete_preparation(probe, {"ok": false, "failure_code": "R10T_FIXTURE_REPEATED_FINALIZATION"}); return
	_complete_preparation(probe, {})

func _native_source(probe: SceneTree, original: Dictionary, trace: Dictionary, arm: Dictionary) -> Dictionary:
	# A fresh counterfactual clock binds copied measurements before hashing.
	# The original retained report remains unchanged in the input artifact.
	var value: Dictionary = original.duplicate(true)
	var step: int = trace.global_semantic_step
	value.model_instance_id = arm.model_instance_id
	value.body_population_instance_sha256 = SHA
	value.observation.semantic_step = step
	value.observation.state.semantic_step = step
	value.observation.state.sample_time_s = float(step) / 120.0
	value.observation.engine_step_identity.semantic_step = step
	value.contact_source_receipt.semantic_step = step
	value.contact_source_sha256 = probe._canonical_sha256_v1(value.contact_source_receipt)
	trace.observation_sha256 = probe._canonical_sha256_v1(value.observation)
	value.precommand_trace = trace.duplicate(true)
	return value

func _measurement(probe: SceneTree, original: Dictionary, trace: Dictionary, arm: Dictionary) -> Dictionary:
	var packet: Dictionary = original.packet.duplicate(true)
	packet.native_source = _native_source(probe, packet.native_source, trace, arm)
	packet.direct_state_source.semantic_step = int(trace.global_semantic_step)
	for body in packet.direct_state_source.ordered_body_states:
		body.callback_sequence = int(trace.global_semantic_step)
	# Readiness consumes this explicitly synthetic minimal source binding, not
	# unrelated predecessor energy receipts whose hashes refer to the old clock.
	packet.source_component_receipts = {"semantic_step": int(trace.global_semantic_step), "source_measurement": true,
		"synthetic_test_fixture": true, "direct_state_source_sha256": probe._canonical_sha256_v1(packet.direct_state_source),
		"contact_source_receipt": packet.native_source.contact_source_receipt.duplicate(true),
		"contact_source_sha256": packet.native_source.contact_source_sha256}
	packet.floor_source = Facade.SdkAdapterScript.DevelopmentFloor.capture_v1(probe._sdk, _floor, arm.model_instance_id)
	var projected := EntrySource.project_v1(probe._sdk, packet, int(trace.global_semantic_step), arm.model_instance_id, SHA)
	if projected.get("ok") != true: return projected
	var compiled: Dictionary = probe._sdk.decode_exact_json_v1(probe._sdk.compile_bounded_quadruped_json(Transport.stringify(Route.exact_base_descriptor_v1()))).value
	var ready := EntrySource.Readiness.measure_v1(projected.request, packet.native_source.observation.center_of_mass, compiled, probe.StanceEntry.task_for_v1(probe._walking_policy_id_v1("walking_resume")).stance_entry)
	return {"ok": true, "packet": packet, "projection": projected, "readiness": ready,
		"readiness_sha256": probe._canonical_sha256_v1(ready), "new_world_count": 0, "new_solver_step_count": 0, "physics_state_modified": false}

func _open_synthetic_session(probe: SceneTree, segment: Dictionary) -> Dictionary:
	var arm: Dictionary = probe._arms[ROLE]
	var facade := MeasuredFacade.new()
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
	facade._session_id = "synthetic-r10t:" + probe._attempt_id + ":" + segment.id
	facade._segment_id = "walking_resume"
	facade._global_start_step = int(start.global_start_step)
	facade._initial_gait_steps = phases
	facade._development_walking_policy_id = alias
	var handoff := facade.begin_walking_actuation_handoff_v1(probe._sdk, "matched_continuation", facade._global_start_step + 1)
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
	start["synthetic_test_fixture"] = true
	if segment.id == "matched_continuation":
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
	probe._arms[ROLE] = arm
	return {"ok": true}

func _complete_preparation(probe: SceneTree, failure: Dictionary) -> void:
	var report := {}
	if probe._arms.has(ROLE):
		var arm: Dictionary = probe._arms[ROLE].duplicate(true)
		arm.erase("facade")
		report = {"ok": failure.is_empty(), "child_attempt_id": probe._attempt_id, "arm_id": ROLE, "source_commit": probe._source_commit,
			"parent_attempt_id": probe._parent_attempt_id, "seed": probe._seed, "configuration": probe._configuration,
			"external_kick_application_count": 0, "solver_step_count": arm.trace_rows.size(),
			"stop_reason": "synthetic_preparation_and_two_walking_commands", "synthetic_test_fixture": true, "retained_arm": arm}
		probe._attach_entry_retention_v1(report)
	for facade in _facades:
		if facade._adapter != null and not facade._shutdown: facade.finish_walking_session_v1()
	for joint in _hinges: joint.free()
	if is_instance_valid(_floor): _floor.free()
	var output := {"ok": failure.is_empty() and report.get("ok") == true, "failure": failure, "report": report,
		"original_policy_validation": _original_policy_validation,
		"synthetic_measurements_only": true, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(_output, FileAccess.WRITE)
	file.store_string(Transport.stringify(output) + "\n"); file.close()
	print("R10T_PREPARATION_REPORT ", JSON.stringify({"ok": output.ok, "failure": failure.get("failure_code", ""), "detail": failure.get("evaluator_failure_code", "")}))
	probe._sdk = null; probe.free()
	quit(0 if output.ok else 1)
