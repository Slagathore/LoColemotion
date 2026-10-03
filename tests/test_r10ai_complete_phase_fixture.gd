extends "res://tests/test_r10ai_complete_walking_report.gd"
## Synthetic upright/hold/walking branch coverage on the selected R10AI worker.
## Real controller sessions and report hooks; no solver or physical claim.
const AC := preload("res://sdk/adapters/godot/gdscript/r10ai_development_worker_v1.gd")
const FrameCapture := AC.ContactFrames
const FrameReport := AC.ContactReport
var _frame_template := {}
var _captures_by_step := {}
var _links_by_step := {}
var _rejected_collection_controls := {}

class R10AIProbe:
	extends "res://sdk/adapters/godot/gdscript/r10ai_development_worker_v1.gd"
	var supplied_measurement := {}
	var supplied_native_source := {}
	func _initialize() -> void: pass
	func _entry_measurement_v1(arm: Dictionary) -> Dictionary:
		return supplied_measurement if arm.orchestrator_state.phase == R10V.PHASE_SETTLING else super._entry_measurement_v1(arm)
	func _walking_native_contact_source_v1(_arm: Dictionary, segment: String) -> Dictionary:
		return supplied_native_source if segment == "walking_resume" else {}

func _new_fixture_probe_v1() -> SceneTree:
	return R10AIProbe.new()

func _branch_v1() -> String:
	return OS.get_environment("SPORE_R10AI_PHASE_BRANCH")

func _expected_recovery_phase_v1() -> String:
	return Prior.PHASE_WALKING_RESUME if _branch_v1() == "upright" else R10V.PHASE_SETTLING

func _complete_synthetic_observation_v1(observation: Dictionary, step: int) -> void:
	super._complete_synthetic_observation_v1(observation, step)
	if step == 575 and _branch_v1() == "upright":
		observation.state.base_twist_world.linear_velocity_m_s = {"x":0.0,"y":0.0,"z":0.0}
		observation.center_of_mass.linear_velocity_world_m_s = {"x":0.0,"y":0.0,"z":0.0}

func _declared_v1() -> Dictionary:
	if _declaration.is_empty():
		_declaration = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SPORE_R10AI_FIXTURE_DECLARATION")))
	return _declaration

func _configure_fixture_probe_v1(probe: SceneTree, resource: String) -> void:
	super._configure_fixture_probe_v1(probe, resource)
	checks["v7_default_native_profile_refuses"] = not Route.ProfileCapabilityScript.rotation_aware_complete_energy_runtime_identity_v1().get("exact_binary_pair_match", false)
	for key in ["seed", "candidate_profile", "runtime", "official_qualification", "source_snapshot"]:
		var crossed := _declared_v1().duplicate(true)
		if key == "seed": crossed.seed = 51008
		elif key == "official_qualification": crossed[key] = true
		else: crossed[key] = {}
		var refused := Route.ProfileCapabilityScript.select_r10ai_diagnostic_runtime_v1(crossed, probe._candidate_selection.candidate_profile)
		checks["native_runtime_refuses_" + key] = refused.get("ok") == false
		checks["refusal_preserves_default_" + key] = not Route.ProfileCapabilityScript.rotation_aware_complete_energy_runtime_identity_v1().get("exact_binary_pair_match", false)
	var selected := Route.ProfileCapabilityScript.select_r10ai_diagnostic_runtime_v1(
		_declared_v1(), probe._candidate_selection.candidate_profile)
	checks["explicit_v7_diagnostic_runtime_selected"] = selected.get("ok") == true
	checks["other_native_profile_stays_unselected"] = not Route.ProfileCapabilityScript.complete_energy_runtime_identity_v1().get("exact_binary_pair_match", false)
	checks["runtime_selection_has_no_world_authority"] = selected.get("physical_execution_authorized") == false
	var world_refusal: Dictionary = await Sources.World.build_world_v1(null, null, {})
	checks["native_world_stays_closed_after_runtime_selection"] = world_refusal.get("failure_code") == "R10AI_NATIVE_WORLD_QUALIFICATION_PENDING"
	if selected.get("ok") != true: push_error(str(selected))

func _crossed_upright_memory_probe_v1(probe: SceneTree, step: int) -> Dictionary:
	# A rejected collection is retained by the real diagnostic worker. Give the
	# negative control its own probe, preserving its rejection outside the valid
	# synthetic timeline instead of deleting it from a publication population.
	var negative := R10AIProbe.new()
	negative._sdk = probe._sdk
	negative._arms = probe._arms.duplicate(true)
	negative._candidate_selection = probe._candidate_selection.duplicate(true)
	negative._arms[ARM].r10v_upright_memory.last_semantic_step += 1
	var refused: Dictionary = negative._collect_arm_completed_step_v1(ARM, step)
	_rejected_collection_controls = {"result": refused,
		"capture_records": negative._r10af_contact_frame_records.duplicate(true),
		"link_records": negative._r10af_observation_links.duplicate(true),
		"synthetic_negative_control": true, "world_build_count": 0, "solver_step_count": 0}
	negative._sdk = null
	negative.free()
	var file := FileAccess.open(_output + ".rejected.json", FileAccess.WRITE)
	file.store_string(Transport.stringify(_rejected_collection_controls) + "\n"); file.close()
	return refused

func _packet_v1(sdk: Object, step: int) -> Dictionary:
	if _frame_template.is_empty():
		var raw := FileAccess.get_file_as_string(OS.get_environment("SPORE_R10AI_FRAME_FIXTURES"))
		var decoded: Dictionary = sdk.decode_exact_json_v1(raw)
		# The stationary packet supplies one explicitly synthetic loaded contact.
		_frame_template = decoded.packets[0].packet
	var packet := _frame_template.duplicate(true)
	packet.model_instance_id = Sources.Prior.MODEL_INSTANCE_ID
	packet.body_population_instance_sha256 = SHA
	packet.semantic_step = step
	for key in ["direct_state_source", "contact_source_receipt", "source_component_binding"]:
		packet[key].semantic_step = step
	packet.contact_source_receipt.native_space_step_sequence = step
	packet.contact_source_receipt.contact_detection_frame.native_space_step_sequence = step
	packet.contact_source_receipt.contact_detection_frame.native_snapshot.capture_space_step_sequence = step
	packet.contact_source_receipt.contact_detection_frame.native_snapshot.read_space_step_sequence = step
	for body in packet.callback_bodies + packet.direct_state_source.ordered_body_states:
		body.callback_sequence = step
	packet.native_snapshot.capture_space_step_sequence = step
	packet.native_snapshot.read_space_step_sequence = step
	packet.source_component_binding.direct_state_source_sha256 = Runtime.canonicalize(sdk, packet.direct_state_source).get("sha256")
	packet.source_component_binding.contact_source_sha256 = Runtime.canonicalize(sdk, packet.contact_source_receipt).get("sha256")
	var replay := FrameCapture.replay_v1(sdk, packet, step, Sources.Prior.MODEL_INSTANCE_ID, SHA)
	_captures_by_step[step] = {"ok": replay.get("ok") == true, "packet": packet,
		"packet_sha256": Runtime.canonicalize(sdk, packet).get("sha256"), "replay": replay,
		"controller_observation_changed": true, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
	return packet

func _bind_diagnostic_fixture_sources_v1(sdk: Object, sources: Dictionary, observation: Dictionary, step: int) -> Dictionary:
	var packet := _packet_v1(sdk, step)
	if _captures_by_step[step].get("ok") != true: return _captures_by_step[step].replay
	var components: Dictionary = sources.source_component_receipts
	# The inherited energy-only synthetic source has no body/contact trace.
	# Declare this fixture's trace before native observation hashing/composition.
	components["source_trace"] = {"schema_version": "sporespore_r10ai_synthetic_recovery_source_v1",
		"semantic_step": step, "synthetic_test_fixture": true}
	for key in ["direct_state_source_sha256", "contact_source_sha256"]:
		components[key] = packet.source_component_binding[key]
		components.source_trace[key] = packet.source_component_binding[key]
	components.source_trace.direct_state_callback_sequence = step
	components.source_trace.native_space_step_sequence = step
	components.source_trace.host_step_before = step - 1
	components.source_trace.host_step_after = step
	components.source_trace.source_measurement = true
	components.source_trace_sha256 = Runtime.canonicalize(sdk, components.source_trace).get("sha256")
	observation.engine_step_identity.source_trace_sha256 = components.source_trace_sha256
	return {"ok": true}

func _complete_fixture_collection_v1(_sdk: Object, result: Dictionary, _step: int) -> void:
	result.measurement.source_component_receipts = result.bound.native_to_portable_staging_mapping.rotation_aware_predecessor_source_component_receipts.duplicate(true)

func _completed_fixture_trace_v1(sdk: Object, arm: Dictionary, projected: Dictionary, step: int) -> Dictionary:
	var row := super._completed_fixture_trace_v1(sdk, arm, projected, step)
	var input := {"last_collection": {"global_result": projected.global_result}, "trace_rows": [row]}
	_links_by_step[step] = FrameReport.link_v1(sdk, input, step)
	return row

func _report_v1(probe: SceneTree, baseline: bool) -> Dictionary:
	# The inherited controller fixture declares setup/prefix events synthetically.
	# Give those steps their own source-linked captures before publication as well.
	for step in range(1, 273):
		var packet := _packet_v1(probe._sdk, step)
		var source := {"schema_version": "sporespore_r10ai_synthetic_setup_source_v1", "semantic_step": step,
			"direct_state_callback_sequence": step, "native_space_step_sequence": step,
			"host_step_before": step-1, "host_step_after": step, "source_measurement": true,
			"direct_state_source_sha256": packet.source_component_binding.direct_state_source_sha256,
			"contact_source_sha256": packet.source_component_binding.contact_source_sha256}
		var observation := {"engine_step_identity": {"schema_version": "sporespore_recovery_engine_step_identity_v1",
			"semantic_step": step, "host_step_before": step-1, "host_step_after": step,
			"native_solver_substep_count": 1, "post_step_observation": true,
			"source_trace_sha256": Runtime.canonicalize(probe._sdk, source).get("sha256")}}
		_links_by_step[step] = {"ok": true, "semantic_step": step, "source_trace": source, "global_observation": observation}
	var count: int = probe._arms[ARM].orchestrator_state.previous_global_semantic_step
	for step in range(1, count+1):
		if not _captures_by_step.has(step) or not _links_by_step.has(step):
			return {"ok": false, "failure_code": "R10AI_FIXTURE_CAPTURE_MISSING", "step": step}
		if _captures_by_step[step].get("ok") != true or _links_by_step[step].get("ok") != true:
			return {"ok": false, "failure_code": "R10AI_FIXTURE_LINK_REFUSED", "step": step,
				"capture": _captures_by_step[step].get("replay"), "link": _links_by_step[step]}
		probe._r10af_contact_frame_records.append(_captures_by_step[step])
		probe._r10af_observation_links.append(_links_by_step[step])
	var result := super._report_v1(probe, baseline)
	if result.get("ok") != true: return result
	# Complete the explicitly synthetic setup rows with the hashes declared above.
	for row in result.report.retained_arm.trace_rows:
		if row.global_semantic_step > 272: break
		row.body_population_instance_sha256 = SHA
		row.observation_sha256 = Runtime.canonicalize(probe._sdk,
			_links_by_step[row.global_semantic_step].global_observation).get("sha256")
	return result

func _exercise_hold(probe: SceneTree) -> Dictionary:
	if _branch_v1() == "upright": return {}
	_hold_input = probe._sdk.decode_exact_json_v1(FileAccess.get_file_as_string(OS.get_environment("SPORE_R10AI_HOLD_REPORT_INPUT")))
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
	return _exercise_walking_v1(probe) if _branch_v1() == "walking" else {}

func _exercise_walking_v1(probe: SceneTree) -> Dictionary:
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


func _native_source(probe: SceneTree, original: Dictionary, trace: Dictionary, arm: Dictionary) -> Dictionary:
	var value := super._native_source(probe, original, trace, arm)
	var step: int = trace.global_semantic_step
	var packet := _packet_v1(probe._sdk, step)
	var source := {"schema_version": "sporespore_r10ai_synthetic_walking_source_v1",
		"semantic_step": step, "direct_state_callback_sequence": step,
		"native_space_step_sequence": step, "host_step_before": step - 1,
		"host_step_after": step, "source_measurement": true, "synthetic_test_fixture": true,
		"direct_state_source_sha256": packet.source_component_binding.direct_state_source_sha256,
		"contact_source_sha256": packet.source_component_binding.contact_source_sha256}
	value.observation.engine_step_identity.merge({"schema_version": "sporespore_recovery_engine_step_identity_v1",
		"semantic_step": step, "host_step_before": step - 1, "host_step_after": step,
		"native_solver_substep_count": 1, "post_step_observation": true,
		"source_trace_sha256": Runtime.canonicalize(probe._sdk, source).get("sha256")}, true)
	trace.observation_sha256 = Runtime.canonicalize(probe._sdk, value.observation).get("sha256")
	value.precommand_trace = trace.duplicate(true)
	_links_by_step[step] = {"ok": true, "semantic_step": step,
		"source_trace": source, "global_observation": value.observation.duplicate(true)}
	return value
