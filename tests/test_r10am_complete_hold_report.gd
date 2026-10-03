extends "res://tests/test_development_r10am_upright_report_fixture.gd"
## Full report from newly executed native hold commands on explicitly synthetic
## observations. No sampler, physics world or settling behavior is asserted.
const Preparation := preload("res://tests/test_development_r10v_preparation_report.gd")
const Facade := Preparation.Facade
const POST := R10AMWorker.R10AMRoute.POST_HOLD_SEGMENT
class HoldProbe:
	extends "res://sdk/adapters/godot/gdscript/r10am_development_worker_v1.gd"
	var supplied_measurement := {}
	func _initialize() -> void: pass
	func _entry_measurement_v1(arm: Dictionary) -> Dictionary:
		if arm.orchestrator_state.phase == R10V.PHASE_SETTLING: return supplied_measurement
		return super._entry_measurement_v1(arm)
class HoldFacade:
	extends Preparation.MeasuredFacade
	func _sample_walking_input_v1(local_step: int, amplitude: float, phase_mode: String) -> Dictionary:
		var sample := super._sample_walking_input_v1(local_step, amplitude, phase_mode)
		sample.request.state.sample_time_s = float(local_step) / 120.0
		sample.request.measured_body_frame.semantic_step = local_step
		sample.request.measured_body_frame.sample_time_s = float(local_step) / 120.0
		if sample.get("stability_shadow", {}).has("stability_state"):
			sample.stability_shadow.stability_state.semantic_step = local_step
		return sample
var _floor: StaticBody3D
var _hinges: Array[HingeJoint3D] = []
var _facades: Array = []
var _hold_input := {}
func _new_fixture_probe_v1() -> SceneTree:
	return HoldProbe.new()
func _expected_recovery_phase_v1() -> String:
	return R10V.PHASE_SETTLING
func _complete_synthetic_observation_v1(observation: Dictionary, step: int) -> void:
	super._complete_synthetic_observation_v1(observation, step)
	if step == 575:
		observation.state.base_twist_world.linear_velocity_m_s = {"x":0.04,"y":0.0,"z":0.0}
		observation.center_of_mass.linear_velocity_world_m_s = {"x":0.04,"y":0.0,"z":0.0}
func _finish_r10v(probe: SceneTree, failure: Dictionary) -> void:
	if failure.is_empty(): failure = _exercise_hold(probe)
	for facade in _facades:
		if facade._adapter != null and not facade._shutdown: facade.finish_walking_session_v1()
	for joint in _hinges: joint.free()
	super._finish_r10v(probe, failure)
func _exercise_hold(probe: SceneTree) -> Dictionary:
	_hold_input = probe._sdk.decode_exact_json_v1(FileAccess.get_file_as_string(OS.get_environment("SPORE_R10AM_HOLD_REPORT_INPUT")))
	var arm: Dictionary = probe._arms[ARM]
	_floor = arm.model.floor
	probe._declared_after_interaction_steps = probe._entry_after_interaction_steps_v1()
	arm.arm_id = ARM
	for key in ["direct_torso_force_command_count", "direct_torso_impulse_command_count", "direct_torso_velocity_command_count", "direct_torso_transform_command_count"]: arm[key] = 0
	arm.walking_sessions = []
	arm.walking_actuation_handoff_receipts = []
	arm.active_walking_session = {}
	var opened := _open_synthetic_session(probe, _hold_input.segment)
	if opened.get("ok") != true: return opened
	var timeout: bool = _hold_input.timeout
	for local in range(1, 241):
		arm = probe._arms[ARM]
		arm.facade.supplied_sample = _hold_input.sample
		var global_step: int = arm.active_walking_session.start_receipt.global_start_step + local
		var applied: Dictionary = probe._apply_next_walking_step_v1(ARM, global_step - 1)
		if applied.get("ok") != true: return applied
		arm = probe._arms[ARM]
		var trace: Dictionary = _hold_input.trace.duplicate(true)
		trace.global_semantic_step = global_step
		trace.arm_id = ARM
		trace.orchestrator_phase = R10V.PHASE_SETTLING
		trace.walking_segment_id = POST
		trace.walking_session_local_step = local
		trace.application_intent_sha256 = probe._canonical_sha256_v1(arm.pending_application)
		trace.walking_session_id = arm.active_walking_session.session_id
		trace.body_population_instance_sha256 = SHA
		trace.synthetic_test_fixture = true
		var source: Dictionary = _hold_input.readiness.duplicate(true)
		var velocity := {"x":0.04 if timeout else 0.0,"y":0.0,"z":0.0}
		source.packet.native_source.observation.state.base_twist_world.linear_velocity_m_s = velocity.duplicate(true)
		source.packet.native_source.observation.center_of_mass.linear_velocity_world_m_s = velocity.duplicate(true)
		for body in source.packet.direct_state_source.ordered_body_states: body.linear_velocity_world_m_s = velocity.duplicate(true)
		var measured := _measurement(probe, source, trace, arm)
		if measured.get("ok") != true: return measured
		arm.trace_rows.append(trace)
		probe._arms[ARM] = arm
		probe.supplied_measurement = measured
		var processed: Dictionary = probe._process_completed_arm_step_v1(ARM, global_step, false)
		if processed.get("ok") != true: return processed
		if probe._arms[ARM].active_walking_session.is_empty(): break
	arm = probe._arms[ARM]
	checks.full_hold_native_finalization = arm.active_walking_session.is_empty() and arm.walking_sessions.size() == 1
	checks.full_hold_expected_count = probe._post_recovery_hold_control_rows.size() == (240 if timeout else 30)
	checks.full_hold_expected_outcome = arm.orchestrator_state.post_recovery_settling.outcome == ("timeout" if timeout else "ready")
	checks.full_hold_original_memory_preserved = probe._completed_upright_memory_preserved_v1(arm)
	return {}
func _report_v1(probe: SceneTree, baseline: bool) -> Dictionary:
	var result := super._report_v1(probe, baseline)
	if result.get("ok") == true and _hold_input.get("timeout") == true:
		result.report.stop_reason = "diagnostic_post_recovery_hold_timeout"
	return result

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
	var arm: Dictionary = probe._arms[ARM]
	var facade := HoldFacade.new()
	_facades.append(facade)
	var alias: String = probe._walking_policy_id_v1(segment.id)
	var start: Dictionary = segment.start.duplicate(true)
	start.global_start_step = arm.orchestrator_state.previous_global_semantic_step
	var lateral: Array = start.task_frame_lateral_axis_world_host_real
	var forward: Array = start.task_frame_forward_axis_world_host_real
	var origin: Array = start.task_frame_origin_world_m
	var phases := R10AMWorker.R10AMRoute.post_hold_gait_steps_v1("walking_resume", "", "")
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
	facade._session_id = "synthetic-r10am:" + probe._attempt_id + ":" + segment.id
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
	probe._arms[ARM] = arm
	return {"ok": true}
