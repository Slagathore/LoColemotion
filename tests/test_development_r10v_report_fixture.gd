extends "res://tests/test_development_r10v_worker_hooks.gd"
# gdlint: disable=max-line-length

## Complete serialized reports from an explicitly synthetic zero-world timeline.
## Real worker publication adds every selected retention family and seed binding.
var _declaration := {}
var _last_report_trace := {}

func _declared_v1() -> Dictionary:
	if _declaration.is_empty():
		_declaration = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SPORE_R10V_FIXTURE_DECLARATION")))
	return _declaration

func _profile_resource_v1() -> String:
	return _declared_v1().candidate_profile.resource

func _fixture_attempt_id_v1() -> String:
	return _declared_v1().children[1].child_attempt_id

func _configure_fixture_probe_v1(probe: SceneTree, _resource: String) -> void:
	var declaration := _declared_v1()
	probe._candidate_selection = R10VWorker.CandidateProfile.load_v1(declaration.candidate_profile)
	probe._candidate_mode = declaration.development_execution_mode
	probe._campaign_declaration = declaration
	probe._seed = int(declaration.seed)
	probe._source_commit = declaration.source_snapshot.head
	probe._parent_attempt_id = declaration.attempt_id
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(probe._candidate_selection.worker_selection.binding))
	probe._configuration = {"synthetic_worker_hook_configuration": true, "base_descriptor": Route.exact_base_descriptor_v1()}
	probe._configuration_sha256 = probe._canonical_sha256_v1(probe._configuration)

func _complete_synthetic_observation_v1(observation: Dictionary, _step: int) -> void:
	# These explicit synthetic source labels are supplied BEFORE native parsing
	# and hashing. They are never applied to an observed physical packet.
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Contacts.CONTRACT_PATH))
	for contact in observation.state.ordered_contact_observations:
		contact.provenance.merge({"adapter_id": contract.source_adapter_id, "aggregation_rule_id": contract.source_aggregation_rule_id,
			"impulse_source_profile_id": contract.source_impulse_profile_id, "impulse_source_kind": contract.source_impulse_kind}, true)

func _completed_fixture_trace_v1(sdk: Object, arm: Dictionary, projected: Dictionary, step: int) -> Dictionary:
	var observation: Dictionary = projected.global_result.bound.observation_v3
	var contacts := {}
	var positions := {}
	var base: Dictionary = observation.state.base_pose_world.position_m
	for index in 4:
		var limb: String = Contacts._contract.ordered_limb_ids[index]
		contacts[limb] = observation.state.ordered_contact_observations[index].bears_support
		positions[limb] = [base.x + (0.2 if index < 2 else -0.2), base.y - 0.33, base.z + (0.1 if index % 2 == 0 else -0.1)]
	return {"global_semantic_step": step, "arm_id": ARM, "orchestrator_phase": arm.orchestrator_state.phase,
		"application_intent_sha256": Runtime.canonicalize(sdk, arm.pending_application).get("sha256"),
		"body_population_instance_sha256": SHA, "observation_sha256": Runtime.canonicalize(sdk, observation).get("sha256"),
		"contact_by_limb": contacts, "foot_position_world_m_by_limb": positions, "synthetic_test_fixture": true}

func _prefix_v1(probe: SceneTree, role: String, attempt: String) -> Dictionary:
	var initialized := R10V.initialize_v1(probe._sdk, attempt, role, Sources.Prior.MODEL_INSTANCE_ID, probe._configuration_sha256, SHA)
	if initialized.get("ok") != true: return initialized
	var state: Dictionary = initialized.state
	var transitions := []
	for step in range(1, 272):
		var fields := {"global_semantic_step": step, "application_intent_sha256": SHA}
		if step <= 240:
			fields.merge({"event_kind": "precondition_pair_ready" if step == 240 else "recovery_controller_step",
				"control_owner": "recovery_v6", "actuation_owner": "recovery_v6", "recovery_actuation_applied": true,
				"stable_four_foot_stance": step == 240, "recovery_controller_terminal_phase": "complete" if step == 240 else ""})
		elif step == 241:
			fields.merge({"event_kind": "precondition_pair_release_step", "no_actuation_requested": true})
		else:
			fields.merge({"event_kind": "walking_policy_step", "control_owner": "walking_bw5r_b", "actuation_owner": "walking_bw5r_b",
				"walking_actuation_applied": true, "walking_session_id": "synthetic-prefix", "walking_session_local_step": step - 241})
		var event := R10V.build_event_v1(probe._sdk, state, fields)
		if event.get("ok") != true: return {"ok": false, "failure_code": "SYNTHETIC_PREFIX_EVENT", "step": step}
		var advanced := R10V.advance_v1(probe._sdk, state, event.event)
		if advanced.get("ok") != true: return advanced
		transitions.append({"state_before": state, "event": event.event, "advance": advanced})
		state = advanced.state_after
	return {"ok": true, "state": state, "transitions": transitions}


func _report_v1(probe: SceneTree, baseline: bool) -> Dictionary:
	var role: String = R10VWorker.R10VSeed.ROLES[0] if baseline else ARM
	if baseline: return {"ok": false, "failure_code": "SINGLE_FIXTURE_HAS_NO_BASELINE"}
	var descriptor: Dictionary = _declared_v1().children[1]
	var attempt: String = descriptor.child_attempt_id
	var prefix := _prefix_v1(probe, role, attempt)
	if prefix.get("ok") != true: return prefix
	var arm: Dictionary = probe._arms[ARM]
	var transitions: Array = prefix.transitions
	var final_state: Dictionary
	if baseline:
		var event := R10V.build_event_v1(probe._sdk, prefix.state, {"global_semantic_step": 272,
			"event_kind": "matched_no_kick_effect_step", "application_intent_sha256": SHA, "no_actuation_requested": true,
			"interaction_receipt_sha256": SHA, "energy_initializer_sha256": SHA, "walking_motors_disabled_in_same_pre_solver_event": true})
		if event.get("ok") != true: return event
		var advanced := R10V.advance_v1(probe._sdk, prefix.state, event.event)
		if advanced.get("ok") != true: return advanced
		transitions.append({"state_before": prefix.state, "event": event.event, "advance": advanced})
		final_state = advanced.state_after
	else:
		if Transport.stringify(prefix.state) != Transport.stringify(probe._entry_transitions[0].state_before):
			return {"ok": false, "failure_code": "SYNTHETIC_PREFIX_STATE_CROSSED"}
		transitions.append_array(probe._entry_transitions)
		final_state = arm.orchestrator_state
	var traces := []
	for transition in transitions:
		var event: Dictionary = transition.event
		if not baseline and event.global_semantic_step > 272:
			traces.append(arm.trace_rows[event.global_semantic_step - 273])
		else:
			traces.append({"global_semantic_step": event.global_semantic_step, "arm_id": role,
				"orchestrator_phase": event.source_phase, "application_intent_sha256": event.application_intent_sha256})
	var report := {"ok": true, "child_attempt_id": attempt, "arm_id": role, "source_commit": probe._source_commit,
		"parent_attempt_id": probe._parent_attempt_id, "seed": probe._seed, "configuration": probe._configuration,
		"external_kick_application_count": 0 if baseline else 1,
		"solver_step_count": traces.size(), "stop_reason": "synthetic_completed_step_boundary", "synthetic_test_fixture": true,
		"retained_arm": {"model_instance_id": Sources.Prior.MODEL_INSTANCE_ID, "body_population_instance_sha256": SHA,
			"orchestrator_state": final_state, "trace_rows": traces, "walking_sessions": arm.get("walking_sessions", []).duplicate(true),
			"walking_actuation_handoff_receipts": arm.get("walking_actuation_handoff_receipts", []).duplicate(true)}}
	var saved := {"entry": probe._entry_packets, "canonical": probe._canonical_packets, "transitions": probe._entry_transitions,
		"first": probe._first_recovery_application, "partial": probe._r10k_partial_packets,
		"upright": probe._r10v_upright_packets, "upright_first": probe._r10v_first_upright_application,
		"partial_first": probe._r10k_first_partial_application, "context": probe._candidate_context, "readiness": probe._entry_readiness_rows}
	probe._entry_transitions = transitions
	if baseline:
		probe._entry_packets = []; probe._canonical_packets = []; probe._first_recovery_application = {}
		probe._r10k_partial_packets = []; probe._r10k_first_partial_application = {}; probe._candidate_context = {}; probe._entry_readiness_rows = []
		probe._r10v_upright_packets = []; probe._r10v_first_upright_application = {}
		probe._arms[role] = {"orchestrator_state": final_state}
	probe._authorized_arm_id = role
	probe._attach_entry_retention_v1(report)
	probe._authorized_arm_id = ARM
	probe._entry_packets = saved.entry; probe._canonical_packets = saved.canonical; probe._entry_transitions = saved.transitions
	probe._first_recovery_application = saved.first; probe._r10k_partial_packets = saved.partial; probe._r10k_first_partial_application = saved.partial_first
	probe._r10v_upright_packets = saved.upright; probe._r10v_first_upright_application = saved.upright_first
	probe._candidate_context = saved.context; probe._entry_readiness_rows = saved.readiness
	return {"ok": report.ok, "report": report, "failure_code": report.get("failure_code", "")}

func _finish_r10v(probe: SceneTree, failure: Dictionary) -> void:
	var active := _report_v1(probe, false) if failure.is_empty() else failure
	var output := {"ok": failure.is_empty() and not checks.values().has(false) and active.get("ok") == true,
		"checks": checks, "failure": failure, "active": active,
		"branch": "upright", "synthetic_measurements_only": true,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(_output, FileAccess.WRITE)
	file.store_string(Transport.stringify(output) + "\n"); file.close()
	Route.free_zero_world_command_surface_v1(_surface)
	if probe._arms.get(ARM, {}).get("model", {}).has("floor"): probe._arms[ARM].model.floor.free()
	probe._sdk = null; probe.free()
	print("R10V_REPORT_FIXTURE ", JSON.stringify({"ok": output.ok, "failure": failure, "active_failure": active.get("failure_code")}))
	quit(0 if output.ok else 1)
