extends SceneTree
# gdlint: disable=max-line-length
const Scheduler := preload("res://sdk/adapters/godot/gdscript/r10q_recovery_orchestrator_v1.gd")
const Bridge := preload("res://sdk/adapters/godot/gdscript/r10q_upright_recovery_stage_v1.gd")
const Transport := Bridge.Transport
const Prior := Scheduler.Prior
const SHA := "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const PROFILE := "res://sdk/development/recovery_candidates/r10q-upright-recovery-core-v1.json"
var checks := {}
var retained := []

func _initialize() -> void:
	call_deferred("_run")

func _send(sdk: Object, state: Dictionary, fields: Dictionary) -> Dictionary:
	if state.is_empty(): return {}
	fields.global_semantic_step = state.previous_global_semantic_step + 1
	fields.application_intent_sha256 = SHA
	var built := Scheduler.build_event_v1(sdk, state, fields)
	if built.get("ok") != true:
		retained.append({"failed_state": state, "fields": fields, "build": built})
		checks["event_build"] = false
		return {}
	var advanced := Scheduler.advance_v1(sdk, state, built.event)
	if advanced.get("ok") != true:
		retained.append({"failed_state": state, "event": built.event, "advance": advanced})
		checks["event_advance"] = false
		return {}
	checks["old_state_authority_closed"] = not Prior.state_valid_v1(sdk, state)
	return advanced.state_after

func _prefix(sdk: Object, arm: String = "kick_passive_recovery_resume") -> Dictionary:
	var initial := Scheduler.initialize_v1(sdk, "synthetic-r10q-scheduler", arm, "synthetic-model", SHA, SHA)
	var state: Dictionary = initial.get("state", {})
	checks["fresh_initialization"] = initial.get("ok") == true
	# Explicit synthetic setup events establish the fixture's epoch at 272.
	for index in 240:
		state = _send(sdk, state, {"event_kind": "precondition_pair_ready" if index == 239 else "recovery_controller_step",
			"control_owner": "recovery_v6", "actuation_owner": "recovery_v6", "recovery_actuation_applied": true,
			"stable_four_foot_stance": index == 239, "recovery_controller_terminal_phase": "complete" if index == 239 else ""})
	state = _send(sdk, state, {"event_kind": "precondition_pair_release_step", "no_actuation_requested": true})
	for index in range(1, 31):
		state = _send(sdk, state, {"event_kind": "walking_policy_step", "control_owner": "walking_bw5r_b",
			"actuation_owner": "walking_bw5r_b", "walking_actuation_applied": true,
			"walking_session_id": "synthetic-prefix", "walking_session_local_step": index})
	return _send(sdk, state, {"event_kind": "kick_effect_step" if arm == "kick_passive_recovery_resume" else "matched_no_kick_effect_step",
		"no_actuation_requested": true, "interaction_receipt_sha256": SHA, "energy_initializer_sha256": SHA,
		"kick_application_count": 1 if arm == "kick_passive_recovery_resume" else 0, "walking_motors_disabled_in_same_pre_solver_event": true})

func _entry_fields(native: Dictionary, state: Dictionary, sdk: Object) -> Dictionary:
	var original: Dictionary = native.original_control.entry.original_passive_receipt
	return {"event_kind": "passive_entry_observation", "no_actuation_requested": true,
		"recovery_epoch_local_step": state.passive_descent_step_count + 1, "energy_initializer_sha256": SHA,
		"r10q_native_receipt": native, "passive_entry_receipt_sha256": Bridge.Source._sha(sdk, original),
		"passive_entry_status": original.memory.status, "canonical_initialization_count": original.canonical_initialization_count,
		"prone_sample": native.entry.memory.route == "prone", "stable_four_foot_stance": original.classification.stable_stance_gate}

func _upright_fields(native: Dictionary, memory: Dictionary, sdk: Object) -> Dictionary:
	var terminal: String = native.step.next_phase
	return {"event_kind": "upright_recovery_controller_step", "control_owner": "recovery_candidate",
		"actuation_owner": "recovery_candidate", "recovery_actuation_applied": true,
		"recovery_epoch_local_step": int(native.step.memory.last_semantic_step) - 272,
		"energy_initializer_sha256": SHA, "r10q_native_receipt": native,
		"upright_prior_memory_sha256": Bridge.Source._sha(sdk, memory),
		"stable_four_foot_stance": native.step.classification.stable_stance_gate,
		"recovery_controller_terminal_phase": terminal if terminal in ["complete", "failed"] else "",
		"recovery_controller_terminal_reason": native.step.memory.terminal_failure_code if terminal == "failed" else ""}

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_profile_resource_v1()))
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old):
		checks["unload"] = GDExtensionManager.unload_extension(old) == GDExtensionManager.LOAD_STATUS_OK
	checks["load"] = GDExtensionManager.load_extension(profile.extension) == GDExtensionManager.LOAD_STATUS_OK
	if checks.values().has(false): _finish(args[1]); return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var input: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	var context: Dictionary = Bridge.Prior.Route.prepare_complete_energy_context_v18(sdk, Bridge.Prior.Route.RECOVERY_CONTROLLER_V6_ID)
	for population in input.cases:
		var state := _prefix(sdk)
		var entry_state := {}
		var count := 0
		var packets := []
		var original_state := {}
		for source in population.packets:
			var packet := Bridge.entry_v1(sdk, context, source.source_attempt_id, source.bound_observations, entry_state)
			if packet.get("ok") != true or state.is_empty():
				checks["entry_bridge_" + str(population.seed)] = false
				break
			state = _send(sdk, state, _entry_fields(packet.native_receipt, state, sdk))
			entry_state = packet.entry_state
			packets.append(packet)
			var expected: Dictionary
			if source.get("expected_original_control") is Dictionary:
				expected = source.expected_original_control
			else:
				var original_packet := Bridge.Original.entry_v1(sdk, context, source.source_attempt_id, source.bound_observations, original_state)
				if original_packet.get("ok") != true:
					checks["original_bridge_" + str(population.seed)] = false
					break
				original_state = original_packet.entry_state
				expected = original_packet.native_receipt
				packet["original_bridge_call"] = original_packet.call
			if SourceHash(sdk, packet.original_control_receipt) != SourceHash(sdk, expected):
				checks["original_control_preserved_" + str(population.seed)] = false
				break
			count += 1
		checks["entry_count_" + str(population.seed)] = count == population.expected_count
		checks["entry_branch_" + str(population.seed)] = state.get("r10q_entry_kind") == population.expected_branch
		checks["actual_confirmation_count_" + str(population.seed)] = state.get("confirm_prone_step_count") == (1 if population.expected_branch == "prone" else 0)
		retained.append({"exposed_seed": population.seed, "samples": count, "state": state, "packets": packets})
		for defect in ["missing_source", "missing_component", "crossed_observation", "wrong_attempt", "missing_prefix", "reused_entry", "malformed_prior"]:
			var first: Dictionary = population.packets[0]
			var bound: Dictionary = first.bound_observations.duplicate(true)
			var selected_attempt: String = first.source_attempt_id
			var selected_prior := {}
			match defect:
				"missing_source": bound.erase("source_binding")
				"missing_component": bound.source_component_receipts.erase("epoch_initializer")
				"crossed_observation": bound.observation_v3.state.base_pose_world.position_m.y += 0.001
				"wrong_attempt": selected_attempt = "unregistered_attempt"
				"missing_prefix": bound = population.packets[1].bound_observations.duplicate(true)
				"reused_entry": selected_prior = entry_state
				"malformed_prior": selected_prior = {"schema_version": Bridge.STATE, "declaration": {}, "selector_memory": {}}
			var refused := Bridge.entry_v1(sdk, context, selected_attempt, bound, selected_prior)
			checks["refuse_entry_" + str(population.seed) + "_" + defect] = refused.get("ok") == false
			checks["retained_input_" + str(population.seed) + "_" + defect] = refused.get("bound_observations") == bound

	var fixtures := []
	for line in FileAccess.get_file_as_string(input.step_fixtures_path).split("\n"):
		if line.begins_with("R10Q_UPRIGHT_FIXTURE "): fixtures.append(sdk.decode_exact_json_v1(line.trim_prefix("R10Q_UPRIGHT_FIXTURE ")))
	checks["three_native_fixtures"] = fixtures.size() == 3
	var state := _prefix(sdk)
	# This independent synthetic state starts immediately before the native
	# fixture's last passive sample. It is never presented as observed history.
	state.previous_global_semantic_step = 511
	state.total_completed_solver_step_count = 511
	state.state_revision = 511
	state.passive_descent_step_count = 239
	state.recovery_epoch_step_count = 239
	state.r10q_entry_kind = "waiting"
	state.payload_sha256 = Prior._payload_sha256_v1(sdk, state)
	var entry := Bridge.call_v1(sdk, "recovery_r10q_upright_entry_control_v1_json", fixtures[0].request)
	state = _send(sdk, state, _entry_fields(entry.value, state, sdk))
	checks["upright_starts_without_prone_history"] = state.get("phase") == Scheduler.PHASE_UPRIGHT and state.get("canonical_start_global_step") == null and state.get("confirm_prone_step_count") == 0
	for index in range(1, 3):
		var fixture: Dictionary = fixtures[index]
		var memory: Dictionary = fixture.request.step.memory
		if index == 2 and not state.is_empty():
			# The native completion fixture explicitly starts at 59 standing
			# samples; the skipped interval is not claimed as route coverage.
			state.previous_global_semantic_step = memory.last_semantic_step
			state.total_completed_solver_step_count = memory.last_semantic_step
			state.state_revision = memory.last_semantic_step
			state.upright_recovery_step_count = memory.total_steps_observed
			state.upright_phase = memory.phase
			state.upright_memory_sha256 = Bridge.Source._sha(sdk, memory)
			state.recovery_epoch_step_count = memory.last_semantic_step - 272
			state.payload_sha256 = Prior._payload_sha256_v1(sdk, state)
		var original: Dictionary = fixture.request
		var fixture_context := {"morphology_context": original.collection.morphology_context,
			"capability": original.collection.adapter_capability, "runtime_binding": original.collection.runtime_binding}
		var fixture_bound := {"observation_v2": original.collection.observation, "observation_v3": original.step.observation,
			"source_binding": original.collection.observation_source_binding}
		var fixture_source := {"energy_increment": original.step.energy_increment, "global_totals": original.step.native_global_energy}
		var request := Bridge.step_request_v1(fixture_context, fixture_bound, original.step.declaration, original.step.memory, fixture_source)
		checks["exact_step_request_" + str(index)] = SourceHash(sdk, request) == SourceHash(sdk, original)
		var called := Bridge.call_v1(sdk, "recovery_upright_step_control_v1_json", request)
		retained.append({"fixture_id": fixture.id, "call": called, "request_exact": request == original})
		checks["native_upright_" + str(index)] = called.get("ok") == true
		if state.is_empty() or called.get("ok") != true: continue
		var fields := _upright_fields(called.value, memory, sdk)
		fields.global_semantic_step = state.previous_global_semantic_step + 1
		fields.application_intent_sha256 = SHA
		var valid := Scheduler.build_event_v1(sdk, state, fields)
		checks["upright_event_" + str(index)] = valid.get("ok") == true
		for corruption in ["prior_memory", "declaration", "native_authority", "energy_reset", "semantic_step", "standing_gate", "partial_claim", "competing_history"]:
			var bad := fields.duplicate(true)
			match corruption:
				"prior_memory": bad.upright_prior_memory_sha256 = SHA
				"declaration": bad.r10q_native_receipt.step.memory.declaration_sha256 = SHA
				"native_authority": bad.r10q_native_receipt.physical_acceptance_authority = true
				"energy_reset": bad.r10q_native_receipt.step.energy_epoch_reset = true
				"semantic_step": bad.r10q_native_receipt.step.memory.last_semantic_step += 1
				"standing_gate": bad.stable_four_foot_stance = not bad.stable_four_foot_stance
				"partial_claim": bad.r10q_native_receipt.step.partial_fall_standing_claimed = true
				"competing_history": bad.partial_prior_memory_sha256 = SHA
			var built := Scheduler.build_event_v1(sdk, state, bad)
			checks["refuse_" + str(index) + "_" + corruption] = built.get("ok") != true or Scheduler.advance_v1(sdk, state, built.event).get("ok") != true
		state = _send(sdk, state, fields)
		retained.append({"synthetic_upright_step_fixture": index, "state": state})
	checks["completion_requires_60_standing"] = state.get("upright_stabilization_complete") == true and state.get("phase") == Prior.PHASE_WALKING_RESUME
	if not state.is_empty():
		state = _send(sdk, state, {"event_kind": "walking_policy_step", "control_owner": "stance", "actuation_owner": "stance",
			"walking_actuation_applied": true, "walking_session_id": "synthetic-fresh-resume", "walking_session_local_step": 1,
			"recovery_epoch_local_step": state.previous_global_semantic_step + 1 - 272})
	checks["fresh_walking_preserves_upright_history"] = state.get("walking_resume_step_count") == 1 and state.get("confirm_prone_step_count") == 0 and state.get("upright_stabilization_complete") == true
	var baseline := _prefix(sdk, "matched_no_kick_continuation")
	checks["no_kick_enters_unchanged_hold_route"] = baseline.get("phase") == Scheduler.Hold.PHASE and baseline.get("r10q_entry_kind") == "unselected"
	sdk = null
	_finish(args[1])

func _finish(path: String) -> void:
	var result := {"ok": not checks.values().has(false), "checks": checks, "results": retained,
		"synthetic_orchestration_events": true, "exposed_inputs_not_regraded": true,
		"completion_fixture_is_a_separate_memory_snapshot": true,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(Transport.stringify(result) + "\n")
	file.close()
	print("R10Q_ORCHESTRATOR ", JSON.stringify({"ok": result.ok, "checks": checks.size(), "failed": checks.keys().filter(func(key): return checks[key] != true)}))
	quit(0 if result.ok else 1)

func SourceHash(sdk: Object, value: Variant) -> String:
	return Bridge.Source._sha(sdk, value)

func _profile_resource_v1() -> String:
	return PROFILE
