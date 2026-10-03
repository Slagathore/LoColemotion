extends "res://sdk/explorer/native_recovery/worker_cached.gd"
## Fresh diagnostic: original setup, then real live walking on those same
## bodies. Walking skips the recovery ledger; recovery itself is unchanged.
const LiveWalk:=preload("res://sdk/explorer/studio/godot_live_walking.gd")
const LiveChecks:=preload("res://sdk/explorer/studio/test_godot_live_walking.gd")
const LiveCommands:=preload("res://sdk/explorer/studio/godot_live_commands.gd")
var _live_walking:=false
var _live_start_step:=0
var _live_start_us:=0
var _live_native_start:=0
var _live_commands:=0
var _live_contact_checks:=0
var _live_rows: Array=[]
var _live_cost: Dictionary={"contacts_us":0,"controller_and_application_us":0}
var _live_input:=PackedByteArray()
var _live_seen: Dictionary={}
var _live_events: Array=[]

func _verify_l15_prepared_context_before_world_v1() -> bool:
	_peer.set_no_delay(true)
	var tests:=LiveChecks.run()
	var commands:=LiveCommands.zero_world()
	if tests.get("ok")!=true or commands.get("ok")!=true:
		_abort("LIVE_WALK_ZERO_WORLD_REFUSED",tests);return false
	return super._verify_l15_prepared_context_before_world_v1()

func _plan_next_process_isolated_frame_v1(global_step: int) -> Dictionary:
	var result:=super._plan_next_process_isolated_frame_v1(global_step)
	if result.get("ok")!=true:return result
	var arm: Dictionary=_arms[_authorized_arm_id]
	if arm.orchestrator_state.phase==Orchestrator.PHASE_WALKING_PREFIX:
		# The full route has just sampled/applied walking command 1. Retain
		# that unmodified transition; take over its completed-step callback.
		if arm.active_walking_session.scheduled_step_count!=1:return {"ok":false,"failure_code":"LIVE_WALK_HANDOFF_STEP"}
		_live_walking=true;_live_start_step=global_step;_live_start_us=Time.get_ticks_usec()
		_live_native_start=int(arm.model.last_native_space_step_sequence)
		_live_commands=1
	return result

func _on_physics_frame() -> void:
	if not _live_walking:
		super._on_physics_frame();return
	if _finished or _finalizing:return
	_total_solver_step_count+=1
	var arm: Dictionary=_arms[_authorized_arm_id]
	var started:=Time.get_ticks_usec()
	var contacts:=LiveWalk.prepare_contacts(arm.model,arm.facade._binding,_total_solver_step_count,
		_live_native_start+_total_solver_step_count-_live_start_step)
	_live_cost.contacts_us+=Time.get_ticks_usec()-started
	if contacts.get("ok")!=true:_abort("LIVE_WALK_NATIVE_CONTACT_REFUSED",contacts);return
	_live_contact_checks+=1
	# Parent publisher samples current bodies. Its diagnostic cutoff remains
	# 360 steps, well before the original scheduled kick.
	if _after_completed_process_isolated_step_v1():return
	var next_local:=_live_commands+1
	started=Time.get_ticks_usec()
	var controlled:=LiveWalk.control_step(arm.facade,next_local,
		_walking_gait_amplitude_v1("walking_prefix",next_local),
		_walking_phase_progression_mode_v1("walking_prefix",next_local))
	_live_cost.controller_and_application_us+=Time.get_ticks_usec()-started
	if controlled.get("ok")!=true:_abort("LIVE_WALK_CONTROLLER_REFUSED",controlled);return
	_live_commands=next_local
	_live_rows.append({"global_step":_total_solver_step_count+1,"local_step":next_local,
		"request":controlled.sample.request,"native_output":controlled.step.native_output,
		"application":controlled.application})
	_poll_live_commands(arm.model.body_nodes.torso)

func _poll_live_commands(torso: RigidBody3D) -> void:
	_peer.poll()
	var available:=_peer.get_available_bytes()
	if available>65536 or _live_input.size()+available>65536:_abort("LIVE_WALK_COMMAND_BYTES");return
	if available>0:
		var read:=_peer.get_partial_data(available)
		if read[0]!=OK:_abort("LIVE_WALK_COMMAND_READ");return
		_live_input.append_array(read[1])
	while _live_input.has(10):
		var newline:=_live_input.find(10)
		var line:=_live_input.slice(0,newline).get_string_from_utf8()
		_live_input=_live_input.slice(newline+1)
		var command:=LiveCommands.decode(JSON.parse_string(line),_diagnostic.id,_live_seen,_total_solver_step_count)
		if command.get("ok")!=true:_abort("LIVE_WALK_COMMAND_REFUSED");return
		torso.apply_central_impulse(command.vector)
		_live_seen[command.event.command_id]=true
		_live_events.append(command.event)

func _send(value: Dictionary) -> void:
	if value.get("message_type")=="hello":
		value["policy"]="Fresh stand-up then native BW5R-B live walking; no recovery switch"
		value["command_capabilities"]={"next_native_step_torso_impulse":true,"maximum_impulse_magnitude_n_s":8.0,"maximum_commands":16}
	if value.get("message_type")=="frame" and _live_walking:
		value["telemetry_profile"]="live_walking_without_recovery_energy_ledger"
		value.applied_impulses=[]
		for event in _live_events:
			if event.apply_at_frame==value.frame_index:value.applied_impulses.append(event)
	if value.get("message_type")=="completed":
		var retained: Dictionary={}
		if _live_walking:
			var path: String=_diagnostic.output.get_base_dir().path_join("live-walking-controls.json")
			var file:=FileAccess.open(path,FileAccess.WRITE)
			file.store_string(JsonTransportScript.stringify(_live_rows));file.close()
			retained={"path":path,"sha256":FileAccess.get_sha256(path),"rows":_live_rows.size()}
		value.summary["studio_live_walking"]={"active":_live_walking,"handoff_completed_step":_live_start_step,
			"walking_commands":_live_commands,"contact_checks":_live_contact_checks,
			"walking_wall_time_s":(Time.get_ticks_usec()-_live_start_us)/1000000.0 if _live_walking else 0.0,
			"cost":_live_cost,"zero_world":LiveChecks.run(),"recovery_ledger_advanced_during_live_walking":false,
			"source_controller_sampler_command_validation_and_motor_application_unchanged":true,
			"controller_rows":retained,"impulses":_live_events,"command_zero_world":LiveCommands.zero_world()}
		if _live_walking:
			value.summary.kicks=_live_events.size()
			# The retained old orchestrator describes setup at the handoff,
			# and must not masquerade as a current recovery-experiment state.
			value.summary["setup_state_at_handoff"]=value.summary.get("terminal_state",{})
			value.summary.erase("terminal_state")
	super._send(value)
