extends "res://sdk/explorer/studio/godot_live_walking_worker.gd"
## One development episode on the original bodies, with current phase ownership.
const LiveRecovery := preload("res://sdk/adapters/godot/gdscript/live_recovery_controller_v1.gd")
const Fall := preload("res://sdk/adapters/godot/gdscript/live_fall_detector_v1.gd")
const LiveEpoch := LiveRecovery.Epoch
const LiveEnergy := LiveRecovery.Energy
const LiveBound := LiveRecovery.Bound
const HandoffChecks := preload("res://sdk/explorer/studio/test_live_handoff.gd")
var _handoff_gate := {}
var _handoff_mode := "walking_prefix"
var _fall_state := {}
var _handoff_epoch := {}
var _handoff_energy := {}
var _handoff_controller := {}
var _handoff_application := {}
var _handoff_rows: Array = []
var _fall_rows: Array = []
var _handoff_session_open := true
var _handoff_resume_step := -1
var _handoff_cost_us := 0
var _handoff_episode_count := 0
var _handoff_prefix_commands := 0


func _verify_l15_prepared_context_before_world_v1() -> bool:
	# The contained owner runs the complete synthetic population in a separate
	# preflight process. Reopen that qualification and every source binding here;
	# do not put hundreds of synthetic controller steps in the live startup path.
	_handoff_gate = HandoffChecks.run(_sdk,_context) if _check_only else _reopen_handoff_qualification()
	if _handoff_gate.get("ok") != true: _abort("LIVE_HANDOFF_GATE",_handoff_gate); return false
	return super._verify_l15_prepared_context_before_world_v1()


func _reopen_handoff_qualification() -> Dictionary:
	var binding: Variant = _diagnostic.get("live_handoff_qualification")
	if not (binding is Dictionary) or not (binding.get("path") is String) or FileAccess.get_sha256(binding.path) != binding.get("sha256"):
		return {"ok":false,"failure_code":"LIVE_HANDOFF_QUALIFICATION_BINDING"}
	var receipt: Variant = _sdk.decode_exact_json_v1(FileAccess.get_file_as_string(binding.path))
	if (not (receipt is Dictionary) or receipt.get("schema_version") != "sporespore_live_handoff_preflight_qualification_v1"
		or receipt.get("source_commit") != _diagnostic.source_commit or receipt.get("world_build_count") != 0
		or receipt.get("zero_world",{}).get("ok") != true or receipt.zero_world.get("compiled_calls") != 486
		or receipt.get("reader",{}).get("ok") != true or receipt.reader.get("negative_controls_refused") != 8
		or receipt.reader.get("positive",{}).get("compiled_calls_replayed") != 486
		or not (receipt.get("dependency_binding") is Dictionary) or receipt.dependency_binding.is_empty()):
		return {"ok":false,"failure_code":"LIVE_HANDOFF_QUALIFICATION_CONTENT"}
	for path in receipt.dependency_binding:
		if FileAccess.get_sha256(path) != receipt.dependency_binding[path]: return {"ok":false,"failure_code":"LIVE_HANDOFF_SOURCE_DRIFT","path":path}
	var result: Dictionary = receipt.zero_world.duplicate(true)
	result.preflight_qualification = binding
	result.synthetic_population_reexecuted_in_live_child = false
	return result


func _on_physics_frame() -> void:
	if not _live_walking: super._on_physics_frame(); return
	if _finished or _finalizing: return
	_total_solver_step_count += 1
	var arm: Dictionary = _arms[_authorized_arm_id]
	var step := _total_solver_step_count
	var native_step := _live_native_start+step-_live_start_step
	var started := Time.get_ticks_usec()
	var contacts := LiveWalk.prepare_contacts(arm.model,arm.facade._binding,step,native_step)
	_live_cost.contacts_us += Time.get_ticks_usec()-started
	if contacts.get("ok") != true: _abort("LIVE_HANDOFF_CONTACT",contacts); return
	_live_contact_checks += 1
	var observed: Dictionary
	var owned := false
	started = Time.get_ticks_usec()
	if _handoff_mode in ["walking_prefix","walking_resume"]:
		var torso: RigidBody3D = arm.model.body_nodes.torso
		var snapshot: Dictionary = torso.get("latest_direct_state_snapshot")
		var torso_contact: Dictionary = contacts.measured.ordered_body_clearance_observations[0]
		observed = Fall.advance_v1(_fall_state,{"global_step":step,"callback_sequence":snapshot.callback_sequence,
			"torso_up_world":snapshot.transform.basis.y.normalized(),"torso_nonfoot_contact":torso_contact.nonfoot_contact_present,
			"source_measurement":snapshot.source_measurement,"torso_clearance_source":torso_contact})
		_fall_rows.append(observed)
		if observed.get("ok") == true:
			_fall_state = observed.state_after
			if _fall_state.triggered:
				if _handoff_episode_count != 0: _abort("LIVE_HANDOFF_SECOND_FALL",observed); return
				observed = _begin_live_recovery(arm,step,native_step,observed); owned = true
	else:
		observed = _advance_live_recovery(arm,step,native_step); owned = true
	_handoff_cost_us += Time.get_ticks_usec()-started
	if observed.get("ok") != true: _abort("LIVE_HANDOFF_TRANSITION",observed); return
	if _after_completed_process_isolated_step_v1(): return
	if not owned:
		var controlled := _live_walking_command(arm,step)
		if controlled.get("ok") != true: _abort("LIVE_HANDOFF_WALKING",controlled); return
	_poll_live_commands(arm.model.body_nodes.torso)


func _begin_live_recovery(arm: Dictionary, step: int, native_step: int, trigger: Dictionary) -> Dictionary:
	var row := {"kind":"begin","global_step":step,"trigger":trigger}
	_handoff_rows.append(row)
	row.capture = LiveEpoch.capture_v1(_sdk,arm.model,step,native_step)
	if row.capture.get("ok") != true: return row.capture
	row.walking_completion = arm.facade.finish_walking_session_v1()
	if row.walking_completion.get("ok") != true: return row.walking_completion
	_handoff_prefix_commands = _live_commands
	_handoff_session_open = false
	row.motor_disable = arm.facade.configure_all_motors_v1(false,step+1,"live_fall_recovery_entry")
	if row.motor_disable.get("ok") != true: return row.motor_disable
	row.epoch = LiveEpoch.begin_v1(_sdk,row.capture,_diagnostic.id+"_live_recovery_1",LiveBound._sha(_sdk,trigger))
	if row.epoch.get("ok") != true: return row.epoch
	_handoff_epoch = row.epoch.state
	row.energy = LiveEnergy.begin_v1(_sdk,_context,_handoff_epoch)
	if row.energy.get("ok") != true: return row.energy
	_handoff_energy = row.energy.state
	row.controller = LiveRecovery.begin_v1(_sdk,_context,_handoff_epoch,_handoff_energy,_diagnostic.id+"_live_recovery_1")
	if row.controller.get("ok") != true: return row.controller
	_handoff_controller = row.controller.state
	_handoff_mode = "recovery_entry"; _handoff_episode_count += 1
	row.application = _passive_application(arm,step+1,row.controller)
	if row.application.get("ok") != true: return row.application
	_handoff_application = row.application
	return {"ok":true}


func _advance_live_recovery(arm: Dictionary, step: int, native_step: int) -> Dictionary:
	var row := {"kind":"recovery_step","global_step":step,"application":_handoff_application}
	_handoff_rows.append(row)
	row.capture = LiveEpoch.capture_v1(_sdk,arm.model,step,native_step)
	if row.capture.get("ok") != true: return row.capture
	row.epoch = LiveEpoch.advance_v1(_sdk,_handoff_epoch,row.capture)
	if row.epoch.get("ok") != true: return row.epoch
	var events: Array = []
	for event in _live_events:
		if event.apply_at_frame == step: events.append(event)
	row.sources = LiveEnergy.capture_sources_v1(_sdk,_context,arm.model,row.capture,_handoff_application.no_actuation_requested,events)
	if row.sources.get("ok") != true: return row.sources
	row.energy = LiveEnergy.advance_v1(_sdk,_handoff_energy,row.epoch,row.sources)
	if row.energy.get("ok") != true: return row.energy
	row.bound = LiveBound.capture_v1(_sdk,_context,arm.model,row.epoch,row.energy,row.sources,_handoff_application)
	if row.bound.get("ok") != true: return row.bound
	row.controller = LiveRecovery.advance_v1(_sdk,_context,_handoff_controller,row.bound)
	if row.controller.get("ok") != true: return row.controller
	_handoff_epoch = row.epoch.state_after; _handoff_energy = row.energy.state_after
	_handoff_controller = row.controller.state_after
	_handoff_mode = "recovery_"+_handoff_controller.route
	if _handoff_controller.terminal:
		if _handoff_controller.terminal_phase != "complete": return {"ok":false,"failure_code":"LIVE_HANDOFF_RECOVERY_TERMINAL","controller":_handoff_controller}
		row.resume = _resume_live_walking(arm,step)
		return row.resume
	row.next_application = _recovery_application(arm,step+1,row.controller,row.bound)
	if row.next_application.get("ok") != true: return row.next_application
	_handoff_application = row.next_application
	return {"ok":true}


func _passive_application(arm: Dictionary, next_step: int, owner_source: Dictionary) -> Dictionary:
	var readback: Dictionary = arm.facade.motor_population_readback_v1(next_step,false,"live_recovery_passive_interval")
	if readback.get("ok") != true: return readback
	var prone: bool = _handoff_controller.route == "prone"
	var controller: String = LiveRecovery.PRONE_CONTROLLER if prone else LocomotionFacade.RECOVERY_CONTROLLER_ID
	var profile := LocomotionFacade.CanonicalOwnershipL15.profile_v1(controller)
	return LocomotionFacade.no_actuation_ledger_application_intent_v2(_sdk,next_step,
		_handoff_controller.memory.phase if prone else EntryOrchestrator.PHASE_DESCENT,
		profile.owner if prone else "none",controller if prone else null,false,owner_source,readback,
		_handoff_controller.memory if prone else {},{},controller)


func _recovery_application(arm: Dictionary, next_step: int, transition: Dictionary, bound: Dictionary) -> Dictionary:
	if transition.control == null: return _passive_application(arm,next_step,transition.native_receipt)
	var kind: String = _handoff_controller.route
	var source: Variant = LiveRecovery.Partial.Source if kind == "partial" else LiveRecovery.Upright.Source if kind == "upright" else null
	var controller: String = LiveRecovery.PRONE_CONTROLLER
	if source != null:
		var checked: Dictionary = source.control_context_v1(_sdk,transition.native_receipt)
		if checked.get("ok") != true or checked.get("semantic_step") != next_step: return {"ok":false,"failure_code":"LIVE_HANDOFF_CONTROL_SOURCE","source":checked}
		controller = source.RECOVERY
	var positions := {}
	for joint in bound.observation_v3.state.ordered_joint_observations: positions[joint.joint_id] = joint.position_rad
	var applied := LiveRecovery.Route.apply_behavior_control_route_aware_discrete_staging_v2(_sdk,transition.control,arm.model,positions,false,controller)
	if applied.get("ok") != true: return applied
	if source != null:
		var tagged: Dictionary = source.bind_application_v1(_sdk,transition.native_receipt,applied)
		if tagged.get("ok") != true: return tagged
		arm.model[source.KEY] = tagged.model_binding
		return tagged.application
	return applied


func _resume_live_walking(arm: Dictionary, step: int) -> Dictionary:
	var row := {"ok":false,"global_step":step}
	var previous: Dictionary = arm.facade.same_body_identity_receipt_v1(_sdk,step,"live_recovery_complete")
	if previous.get("ok") != true: return previous
	row.previous_body_identity = previous
	var facade := LocomotionFacade.new()
	var binding := facade.bind_live_model_v1(arm.model,arm.facade._binding.model_instance_id)
	if binding.get("ok") != true: return binding
	row.binding = {"ok":true,"model_instance_id":binding.model_instance_id,
		"instance_id_by_node_id":binding.instance_id_by_node_id.duplicate(true)}
	row.same_body = facade.same_body_identity_receipt_v1(_sdk,step,"live_walking_resume")
	if (row.same_body.get("ok") != true or not previous.has("body_population_instance_sha256")
		or row.same_body.get("body_population_instance_sha256") != previous.body_population_instance_sha256): return {"ok":false,"failure_code":"LIVE_HANDOFF_BODY_IDENTITY"}
	row.start = facade.start_walking_session_v1("walking_resume",_diagnostic.id+"_live_resume",_seed,step,true,
		_walking_frame_id_v1("walking_resume"),_walking_contact_profile_id_v1("walking_resume"),
		_walking_start_profile_id_v1("walking_resume"),_walking_policy_id_v1("walking_resume"),_walking_prefix_profile_id_v1("walking_resume"))
	if row.start.get("ok") != true: return row.start
	row.handoff = facade.begin_walking_actuation_handoff_v1(_sdk,"walking_resume",step+1)
	if row.handoff.get("ok") != true: return row.handoff
	# A fresh facade owns fresh sampler bindings. Populate those bindings from
	# this completed callback before its first resumed command is sampled.
	row.contacts = LiveWalk.prepare_contacts(arm.model,facade._binding,step,_live_native_start+step-_live_start_step)
	if row.contacts.get("ok") != true: return row.contacts
	arm.facade = facade
	for key in [LiveRecovery.Partial.Source.KEY,LiveRecovery.Upright.Source.KEY]: arm.model.erase(key)
	_handoff_session_open = true; _handoff_mode = "walking_resume"; _live_commands = 0
	_handoff_resume_step = step; _fall_state = {}
	row.first_command = _live_walking_command(arm,step)
	if row.first_command.get("ok") != true: return row.first_command
	row.ok = true
	return row


func _live_walking_command(arm: Dictionary, step: int) -> Dictionary:
	var next := _live_commands+1
	var started := Time.get_ticks_usec()
	var command := LiveWalk.control_step(arm.facade,next,_walking_gait_amplitude_v1(_handoff_mode,next),_walking_phase_progression_mode_v1(_handoff_mode,next))
	_live_cost.controller_and_application_us += Time.get_ticks_usec()-started
	if command.get("ok") != true: return command
	_live_commands = next
	_live_rows.append({"global_step":step+1,"local_step":next,"segment":_handoff_mode,
		"request":command.sample.request,"native_output":command.step.native_output,"application":command.application})
	return command


func _finish_walking_session_v1(arm_id: String) -> Dictionary:
	if not _live_walking: return super._finish_walking_session_v1(arm_id)
	if not _handoff_session_open: return {"ok":true,"session_closed":false,"live_mode":_handoff_mode}
	var result: Dictionary = _arms[arm_id].facade.finish_walking_session_v1()
	if result.get("ok") == true: _handoff_session_open = false
	return result


func _poll_live_commands(torso: RigidBody3D) -> void:
	_peer.poll()
	var available := _peer.get_available_bytes()
	if available > 65536 or _live_input.size()+available > 65536: _abort("LIVE_HANDOFF_COMMAND_BYTES"); return
	if available > 0:
		var read := _peer.get_partial_data(available)
		if read[0] != OK: _abort("LIVE_HANDOFF_COMMAND_READ"); return
		_live_input.append_array(read[1])
	while _live_input.has(10):
		var newline := _live_input.find(10)
		var line := _live_input.slice(0,newline).get_string_from_utf8()
		_live_input = _live_input.slice(newline+1)
		var command := LiveCommands.decode(JSON.parse_string(line),_diagnostic.id,_live_seen,_total_solver_step_count)
		if command.get("ok") != true: _abort("LIVE_HANDOFF_COMMAND_REFUSED",command); return
		_live_seen[command.event.command_id] = true
		if _handoff_mode not in ["walking_prefix","walking_resume"]:
			_handoff_rows.append({"kind":"command_rejected","global_step":_total_solver_step_count,
				"reason":"recovery_owns_motors","requested_event":command.event,"applied":false})
			continue
		torso.apply_central_impulse(command.vector)
		_live_events.append(command.event)


func _send(value: Dictionary) -> void:
	if value.get("message_type") == "frame" and _live_walking:
		value.phase = _handoff_mode
		value.phase_scope = "following_native_interval"
	if value.get("message_type") in ["completed","error"]:
		var retained := _retain_live_handoff()
		if value.get("message_type") == "completed":
			var gate := _handoff_gate.duplicate(true)
			if gate.has("fixture"):
				var fixture_path: String = _diagnostic.output.get_base_dir().path_join("live-handoff-controls.json")
				var fixture_file := FileAccess.open(fixture_path,FileAccess.WRITE)
				fixture_file.store_string(JsonTransportScript.stringify(LiveEpoch.json_safe_v1(gate.fixture))); fixture_file.close()
				gate.fixture_retained = {"path":fixture_path,"sha256":FileAccess.get_sha256(fixture_path)}
				gate.erase("fixture")
			value.summary.live_handoff = {"mode":_handoff_mode,"episodes":_handoff_episode_count,"resume_completed_step":_handoff_resume_step,
				"prefix_commands":_handoff_prefix_commands,"resume_commands":_live_commands if _handoff_resume_step >= 0 else 0,
				"recovery_capture_and_control_us":_handoff_cost_us,"retained":retained,"zero_world":gate,
				"physical_acceptance_authority":false,"release_authority":false}
		else: value.retained_live_handoff = retained
	super._send(value)


func _live_policy_description_v1() -> String:
	return "Stand up, walk, recover after a detected fall, then resume walking"

func _live_telemetry_profile_v1() -> String:
	return "live_walking" if _handoff_mode in ["walking_prefix","walking_resume"] else "live_recovery_full_capture"

func _live_summary_scope_v1(summary: Dictionary) -> Dictionary:
	summary.live_interval_wall_time_s = summary.walking_wall_time_s
	summary.walking_commands_current_session = summary.walking_commands
	summary.erase("walking_wall_time_s"); summary.erase("walking_commands")
	summary.current_phase = _handoff_mode
	return summary


func _retain_live_handoff() -> Dictionary:
	var path: String = _diagnostic.output.get_base_dir().path_join("live-handoff.json")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JsonTransportScript.stringify(LiveEpoch.json_safe_v1({"transitions":_handoff_rows,"fall_samples":_fall_rows}))); file.close()
	return {"path":path,"sha256":FileAccess.get_sha256(path),"transitions":_handoff_rows.size(),"fall_samples":_fall_rows.size()}
