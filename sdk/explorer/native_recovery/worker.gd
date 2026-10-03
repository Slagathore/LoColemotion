extends "res://sdk/explorer/native_recovery/r10ap_capture_worker_v1.gd"
## Fresh bounded showcase session through the native V28 controller. The
## display is in a separate process; this worker never renders or replays.
const PROFILE := "res://sdk/development/recovery_candidates/r10ap-progressive-headroom-v1.json"
const STARTUP := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd")
const RelocatedProfile := preload("res://sdk/explorer/native_recovery/relocated_profile.gd")
const PROTOCOL := "sporespore_live_explorer_protocol_v1"
var _diagnostic: Dictionary = {}
var _check_only := false
var _view_start := -1
var _finished := false
var _peer := StreamPeerTCP.new()
var _last_kicks := 0
var _stream_count := 0

class NativeContextCache extends CountedContextCache:
	func validate_v1(sdk: Object, context: Dictionary, predicate: int) -> bool:
		return super.validate_v1(sdk.native if sdk.get_script() != null else sdk, context, predicate)

func _initialize() -> void:
	var path := OS.get_environment("SPORESPORE_EXPLORER_CONFIG")
	if not FileAccess.file_exists(path): quit(2); return
	_diagnostic = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check_only = _diagnostic.get("validate_only",false)
	if not FileAccess.file_exists(_diagnostic.permit): quit(2); return
	if _diagnostic.phase < 0 or _diagnostic.phase > 359: quit(2); return
	var connect_parts: PackedStringArray = _diagnostic.connect.split(":")
	if _peer.connect_to_host(connect_parts[0],int(connect_parts[1])) != OK: quit(2); return
	STARTUP.r10ap_contract = JSON.parse_string(FileAccess.get_file_as_string(STARTUP.R10AP_CONTRACT_PATH))
	_candidate_selection = RelocatedProfile.load_v1({"resource":PROFILE,"raw_sha256":"sha256:"+FileAccess.get_sha256(PROFILE)})
	if _candidate_selection.is_empty(): print("EXPLORER_PROFILE_REFUSED"); quit(3); return
	_entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(_entry_selection_v1().binding))
	_seed = int(_diagnostic.phase)
	_attempt_id = _diagnostic.id
	_parent_attempt_id = _diagnostic.parent_id
	_authorized_arm_id = EnergyInitializer.ACTIVE_ARM_ID
	_repair_id = "QSDK-R10F-L15"
	_context_cache = NativeContextCache.new()
	_profile_start_us = Time.get_ticks_usec()
	call_deferred("_connect_and_run")

func _connect_and_run() -> void:
	for n in 100:
		_peer.poll()
		if _peer.get_status()==StreamPeerTCP.STATUS_CONNECTED: break
		await process_frame
	if _peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED: quit(2); return
	_send({"message_type":"hello","native_physics":true,"replay":false,"engine_version":Engine.get_version_info().string,
		"source_commit":_diagnostic.source_commit,"policy":"R10AP V28 native recovery; showcase 600-step prefix",
		"command_capabilities":{"scheduled_canonical_torso_impulse":false,"schedule":"0.25 N.s at prefix step 600"}})
	await _run()

func _send(value: Dictionary) -> void:
	value.merge({"schema_version":PROTOCOL,"session_id":_diagnostic.id,"engine_id":"godot_jolt","scientific_evidence_authority":false})
	if _peer.put_data((JSON.stringify(value)+"\n").to_utf8_buffer()) != OK:
		PhysicsServer3D.set_active(false); quit(8)

func _verify_l15_prepared_context_before_world_v1() -> bool:
	_sdk = preload("res://sdk/explorer/native_recovery/memoized_sdk.gd").new(_sdk)
	for value in [{"x":0.1,"y":-0.0,"nested":[1,1.0,1.2345678901234567]},_context]:
		var wire := JsonTransportScript.stringify({"schema_version":"sporespore_canonical_json_request_v1","value":value})
		var expected: String = _sdk.native.canonicalize_json(wire)
		if _sdk.canonicalize_json(wire) != expected or _sdk.canonicalize_json(wire) != expected:
			_abort("EXPLORER_CANONICAL_CACHE_MISMATCH"); return false
	if _check_only:
		var check: Dictionary = zero_world_contract_v12(_sdk,_context)
		var schedule := _check_diagnostic_schedule()
		check["explorer_schedule"] = schedule
		check.ok = check.get("ok") == true and schedule.get("ok") == true
		_send({"message_type":"completed","ok":check.ok,"outcome":"preflight_only","frame_count":0,"summary":check})
		print("EXPLORER_RECOVERY_PREFLIGHT ",JSON.stringify(check))
		_finished = true
		quit(0 if check.ok else 4)
		return false
	return _context.get("ok") == true and FileAccess.file_exists(_diagnostic.permit)

func _build_arm_v1(arm_id: String) -> Dictionary:
	if _check_only or not FileAccess.file_exists(_diagnostic.permit): return {"ok":false,"failure_code":"EXPLORER_WORLD_NOT_PERMITTED"}
	var result: Dictionary = await super._build_arm_v1(arm_id)
	if result.get("ok")!=true: return result
	var bodies := []
	for id in _arms[arm_id].model.body_nodes:
		var body: Node3D = _arms[arm_id].model.body_nodes[id]
		for child in body.get_children():
			if child is CollisionShape3D:
				var collision := {}
				if child.shape is BoxShape3D: collision={"kind":"box","size_m":_vec(child.shape.size)}
				elif child.shape is CapsuleShape3D: collision={"kind":"capsule","radius_m":child.shape.radius,"length_m":child.shape.height-2*child.shape.radius}
				elif child.shape is SphereShape3D: collision={"kind":"sphere","radius_m":child.shape.radius}
				if not collision.is_empty(): bodies.append({"body_id":id,"collision":collision})
	_send({"message_type":"scene","scene":{"morphology_spec":{"bodies":bodies}}})
	return result

func _vec(value: Vector3) -> Dictionary:
	return {"x":value.x,"y":value.y,"z":value.z}

func _after_completed_process_isolated_step_v1() -> bool:
	var arm: Dictionary = _arms[_authorized_arm_id]
	var phase_name: String = arm.orchestrator_state.phase
	if _view_start<0 and phase_name==Orchestrator.PHASE_WALKING_PREFIX: _view_start=_total_solver_step_count
	var bodies := []
	var contacts := []
	for id in arm.model.body_nodes:
		var body: RigidBody3D=arm.model.body_nodes[id]
		var q:=body.transform.basis.get_rotation_quaternion()
		bodies.append({"body_id":id,"position_m":_vec(body.position),"orientation_xyzw":{"x":q.x,"y":q.y,"z":q.z,"w":q.w}})
		contacts.append({"body_id":id,"present":body.get_contact_count()>0})
	var applied := []
	if _external_kick_application_count>_last_kicks:
		applied.append({"native_application":"production_recovery_impulse_route","count":_external_kick_application_count,"impulse_n_s":{"x":0,"y":0,"z":.25}})
		_last_kicks=_external_kick_application_count
	_send({"message_type":"frame","native_physics":true,"replay":false,"frame_index":_total_solver_step_count,
		"simulation_time_s":_total_solver_step_count/120.0,"physics_wall_time_s":(Time.get_ticks_usec()-_profile_start_us)/1000000.0,
		"phase":phase_name,"ordered_bodies":bodies,"ordered_body_ground_contacts":contacts,"applied_impulses":applied})
	_stream_count+=1
	if _total_solver_step_count>=2401 or (_view_start>=0 and _total_solver_step_count-_view_start>=1800):
		_finish_explorer("bounded_showcase_horizon"); return true
	return false

func _finish_explorer(reason: String) -> void:
	if _finished: return
	_finished=true; _finalizing=true
	PhysicsServer3D.set_active(false)
	var closed := _finish_walking_session_v1(_authorized_arm_id)
	var summary := {"diagnostic_only":true,"reason":reason,"walking_shutdown":closed,"solver_step_count":_total_solver_step_count,
		"terminal_state":_arms[_authorized_arm_id].orchestrator_state.duplicate(true),
		"kicks":_external_kick_application_count,"cost":_cost.sections,"physical_acceptance_authority":false,"release_authority":false}
	var file := FileAccess.open(_diagnostic.output,FileAccess.WRITE); file.store_string(JSON.stringify(summary)); file.close()
	_send({"message_type":"completed","ok":closed.get("ok")==true,"outcome":"development_observation","frame_count":_total_solver_step_count,"summary":summary})
	_cleanup_worlds_v1()
	quit(0 if closed.get("ok")==true else 5)

func _abort(code: String, detail: Dictionary = {}) -> void:
	# The inherited runner treats a deliberately stopped pre-world hook as a
	# refusal. Its expected unwind must not replace our completed check's exit.
	if _check_only and _finished: return
	PhysicsServer3D.set_active(false)
	_send({"message_type":"error","error":code,"detail":detail})
	print("EXPLORER_RECOVERY_ABORT ",code," ",JSON.stringify(detail))
	quit(6)

func _finalize_process_isolated_child_result_v1() -> void:
	_finish_explorer("production_controller_terminal")

func _load_campaign_binding_v1() -> bool:
	return not _diagnostic.is_empty()

func _load_runtime_extension_v1() -> bool:
	var profile: Script = RouteScript.ProfileCapabilityScript
	var images: Dictionary = _diagnostic.images
	for item in images.values():
		if FileAccess.get_sha256(item.path) != item.sha256: return false
	var identity: Dictionary = profile._runtime_identity_for_profile_v1(profile.ROTATION_AWARE_COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID,
		images.console.sha256, int(images.console.length), images.engine.sha256, int(images.engine.length), true)
	if identity.get("exact_binary_pair_match") != true: return false
	profile._rotation_aware_complete_energy_runtime_identity_cache = identity
	if GDExtensionManager.is_extension_loaded(EXTENSION_PATH):
		if GDExtensionManager.unload_extension(EXTENSION_PATH) != GDExtensionManager.LOAD_STATUS_OK: return false
	if GDExtensionManager.load_extension(_entry_selection_v1().extension) != GDExtensionManager.LOAD_STATUS_OK: return false
	var probe: Object = ClassDB.instantiate(CLASS_NAME)
	_entry_walking_runtime_preflight = LocomotionFacade.portable_session_preflight_v1(probe, _seed, true, "")
	return _entry_walking_runtime_preflight.get("ok") == true

func _walking_prefix_profile_id_v1(_segment: String) -> String:
	return ""

func _walking_session_step_limit_v1(segment: String) -> int:
	return 600 if segment == "walking_prefix" else super._walking_session_step_limit_v1(segment)

func _development_walking_diagnostic_maximum_steps_v1() -> int:
	return 1800

func _check_diagnostic_schedule() -> Dictionary:
	var sha := "sha256:"+"1".repeat(64)
	var initialized := R10AP.initialize_v1(_sdk,"ffffffffffffffffffffffffffffffff",EnergyInitializer.ACTIVE_ARM_ID,"explorer-synthetic",sha,sha)
	if initialized.get("ok") != true: return initialized
	var state: Dictionary = initialized.state
	state.phase = Orchestrator.PHASE_WALKING_PREFIX
	state.previous_global_semantic_step = 241
	state.total_completed_solver_step_count = 241
	state.state_revision = 241
	state.precondition_recovery_step_count = 240
	state.precondition_pair_ready = true
	state.precondition_pair_release_step_count = 1
	state.payload_sha256 = R10AP.Prior._payload_sha256_v1(_sdk,state)
	for n in range(1,601):
		var event := R10AP.build_event_v1(_sdk,state,{"event_kind":"walking_policy_step","global_semantic_step":241+n,
			"control_owner":"walking_bw5r_b","actuation_owner":"walking_bw5r_b","application_intent_sha256":sha,
			"walking_session_id":"explorer-synthetic-prefix","walking_session_local_step":n,"walking_actuation_applied":true})
		if event.get("ok") != true: return event
		if n == 1:
			for field in ["global_semantic_step","walking_session_local_step","event_kind"]:
				var crossed: Dictionary=event.event.duplicate(true)
				crossed[field]=0 if field!="event_kind" else "crossed"
				if R10AP.advance_v1(_sdk,state,crossed).get("ok")==true: return {"ok":false,"accepted_crossed_event":field}
		var result := R10AP.advance_v1(_sdk,state,event.event)
		if result.get("ok") != true: return result
		state = result.state_after
		if n < 600 and state.phase != Orchestrator.PHASE_WALKING_PREFIX: return {"ok":false,"early_kick":n}
	var steps := LocomotionFacade.initial_gait_steps_v1(_seed,"walking_prefix")
	return {"ok":state.phase == Orchestrator.PHASE_INTERACTION and steps.values() == [_seed,_seed,_seed,_seed],
		"kick_command":600,"total_timed_commands":1800,"negative_controls":3,"phase":steps,"world_build_count":0,"solver_step_count":0}

func _finish_walking_session_v1(arm_id: String) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var session: Dictionary = arm.active_walking_session
	if session.is_empty(): return {"ok":true,"session_closed":false}
	if arm.walking_session_completion_attempted: return {"ok":false,"failure_code":"EXPLORER_REPEATED_SHUTDOWN"}
	arm.walking_session_completion_attempted = true
	var completion: Dictionary = arm.facade.finish_walking_session_v1()
	if completion.get("ok") != true or completion.get("adapter_shutdown_receipt",{}).get("ok") != true: return completion
	arm.walking_sessions.append({"evaluation_segment_id":session.evaluation_segment_id,"session_id":session.session_id,
		"start_receipt":session.start_receipt,"completion_receipt":completion,"evaluation":{"diagnostic_only":true,"formal_evaluation_performed":false}})
	arm.active_walking_session = {}
	arm.last_walking_evaluation_failure = {}
	_arms[arm_id] = arm
	return {"ok":true,"session_closed":true,"formal_evaluation_performed":false}
