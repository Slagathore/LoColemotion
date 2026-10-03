extends "res://sdk/explorer/phase74_diagnostic/r10ap_capture_worker_v1.gd"
## Cole's unofficial 15-second visual diagnostic. No acceptance publication.
const PROFILE := "res://sdk/development/recovery_candidates/r10ap-progressive-headroom-v1.json"
const STARTUP := preload("res://sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd")
var _diagnostic: Dictionary = {}
var _label: Label
var _start_button: Button
var _camera: Camera3D
var _view_start := -1
var _finished := false
var _started := false
var _samples: Array = []
var _check_only := false
var _pose_frames: Array = []
var _replay_nodes: Dictionary = {}
var _replaying := false
var _replay_time := 0.0
var _last_model: Dictionary = {}
class NativeContextCache extends CountedContextCache:
	func validate_v1(sdk: Object, context: Dictionary, predicate: int) -> bool:
		# Preserve the existing exact context cache's native-object eligibility.
		return super.validate_v1(sdk.native if sdk.get_script() != null else sdk, context, predicate)


func _initialize() -> void:
	_check_only = "--check" in OS.get_cmdline_user_args()
	var path := OS.get_environment("SPORESPORE_VISUAL_DIAGNOSTIC_CONFIG")
	if not FileAccess.file_exists(path): quit(2); return
	_diagnostic = JSON.parse_string(FileAccess.get_file_as_string(path))
	if _diagnostic.get("phase") != 74 or _diagnostic.get("seconds") != 15 or _diagnostic.get("kick_seconds") != 5:
		quit(2); return
	if not _check_only and not FileAccess.file_exists(_diagnostic.permit): quit(2); return
	STARTUP.r10ap_contract = JSON.parse_string(FileAccess.get_file_as_string(STARTUP.R10AP_CONTRACT_PATH))
	_candidate_selection = CandidateProfile.load_v1({"resource":PROFILE,"raw_sha256":"sha256:"+FileAccess.get_sha256(PROFILE)})
	if _candidate_selection.is_empty(): quit(3); return
	_entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(_entry_selection_v1().binding))
	_seed = 74
	_attempt_id = _diagnostic.id
	_parent_attempt_id = _diagnostic.parent_id
	_authorized_arm_id = EnergyInitializer.ACTIVE_ARM_ID
	_repair_id = "QSDK-R10F-L15"
	_context_cache = NativeContextCache.new()
	_profile_start_us = Time.get_ticks_usec()
	call_deferred("_run")

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

func _verify_l15_prepared_context_before_world_v1() -> bool:
	_sdk = preload("res://sdk/explorer/phase74_diagnostic/memoized_sdk.gd").new(_sdk)
	for value in [{"x":0.1,"y":-0.0,"nested":[1,1.0,1.2345678901234567]},_context]:
		var wire := JsonTransportScript.stringify({"schema_version":"sporespore_canonical_json_request_v1","value":value})
		var expected: String = _sdk.native.canonicalize_json(wire)
		if _sdk.canonicalize_json(wire) != expected or _sdk.canonicalize_json(wire) != expected:
			quit(6); return false
	if _check_only:
		var check: Dictionary = zero_world_contract_v1(_sdk)
		var probe := _check_diagnostic_schedule()
		check["diagnostic_schedule"] = probe
		check.ok = check.get("ok") == true and probe.get("ok") == true
		print("VISUAL_ZERO_WORLD ", JSON.stringify(check))
		quit(0 if check.get("ok") == true else 4)
		return false
	return _context.get("ok") == true and FileAccess.file_exists(_diagnostic.permit)

func _walking_prefix_profile_id_v1(_segment: String) -> String:
	return ""

func _walking_session_step_limit_v1(segment: String) -> int:
	return 600 if segment == "walking_prefix" else super._walking_session_step_limit_v1(segment)

func _development_walking_diagnostic_maximum_steps_v1() -> int:
	return 1800

func _after_completed_process_isolated_step_v1() -> bool:
	var arm: Dictionary = _arms[_authorized_arm_id]
	var phase: String = arm.orchestrator_state.phase
	if _view_start < 0 and phase == Orchestrator.PHASE_WALKING_PREFIX:
		_view_start = _total_solver_step_count
	var t := 0.0 if _view_start < 0 else float(_total_solver_step_count - _view_start)/120.0
	var torso: RigidBody3D = arm.model.body_nodes.torso
	if _view_start >= 0:
		var poses := {}
		for id in arm.model.body_nodes:
			var tr: Transform3D = arm.model.body_nodes[id].transform
			poses[id] = [tr.origin.x,tr.origin.y,tr.origin.z,tr.basis.x.x,tr.basis.x.y,tr.basis.x.z,tr.basis.y.x,tr.basis.y.y,tr.basis.y.z,tr.basis.z.x,tr.basis.z.y,tr.basis.z.z]
		_pose_frames.append({"t":t,"phase":phase,"poses":poses})
	_samples.append({"t":t,"step":_total_solver_step_count,"phase":phase,"position":[torso.position.x,torso.position.y,torso.position.z],"tilt":acos(clampf(torso.basis.y.dot(Vector3.UP),-1,1))})
	if is_instance_valid(_label):
		_label.text = "UNOFFICIAL | S169 phase 74 | kick 0.25 N.s at 5.0 s\n%.2f / 15.00 simulated seconds | %s\nTorso: x %.3f m   height %.3f m\nNative controller speed; no animation or speed adjustment" % [t,phase,torso.position.x,torso.position.y]
	if is_instance_valid(_camera):
		_camera.position = torso.position + Vector3(1.5,1.0,2.0)
		_camera.look_at(torso.position)
	if _view_start >= 0 and _total_solver_step_count - _view_start >= 1800:
		_finish_visual("15 simulated seconds completed")
		return true
	return false # Deliberately keep walking; no finite-cycle stop in this diagnostic.

func _build_arm_v1(arm_id: String) -> Dictionary:
	if _check_only or not FileAccess.file_exists(_diagnostic.permit): return {"ok":false,"failure_code":"VISUAL_WORLD_NOT_PERMITTED"}
	var result: Dictionary = await super._build_arm_v1(arm_id)
	if result.get("ok") != true: return result
	_build_view(_arms[arm_id].model)
	return result

func _build_view(model: Dictionary) -> void:
	_last_model = model
	root.title = "SporeSpore - phase 74 kick recovery - unofficial live physics"
	root.size = Vector2i(1100,760)
	var viewport: SubViewport = model.viewport
	viewport.size = root.size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var picture := TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(picture)
	for body in model.body_nodes.values():
		for child in body.get_children():
			if child is CollisionShape3D:
				var mesh := MeshInstance3D.new()
				if child.shape is BoxShape3D:
					var box := BoxMesh.new(); box.size = child.shape.size; mesh.mesh = box
				elif child.shape is CapsuleShape3D:
					var capsule := CapsuleMesh.new(); capsule.radius = child.shape.radius; capsule.height = child.shape.height; mesh.mesh = capsule
				elif child.shape is SphereShape3D:
					var sphere := SphereMesh.new(); sphere.radius = child.shape.radius; sphere.height = 2*child.shape.radius; mesh.mesh = sphere
				else: mesh.mesh = child.shape.get_debug_mesh()
				mesh.transform = child.transform
				var material := StandardMaterial3D.new()
				material.albedo_color = Color(0.2,0.75,0.9) if body != model.body_nodes.torso else Color(0.95,0.55,0.18)
				mesh.material_override = material
				body.add_child(mesh)
	var plane := MeshInstance3D.new()
	var geometry := PlaneMesh.new()
	geometry.size = Vector2(20,20)
	plane.mesh = geometry
	plane.position.y = -0.002
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22,0.25,0.28)
	plane.material_override = mat
	model.world.add_child(plane)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-25,0)
	light.light_energy = 1.6
	model.world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.08,0.10,0.14)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	model.world.add_child(environment)
	_camera = Camera3D.new()
	_camera.position = Vector3(1.5,1.2,2)
	model.world.add_child(_camera)
	_camera.look_at(Vector3(0,0.25,0))
	_label = Label.new()
	_label.position = Vector2(20,20)
	_label.add_theme_font_size_override("font_size",20)
	_label.text = "UNOFFICIAL | Preparing real phase-74 recovery world..."
	root.add_child(_label)
	_start_button = Button.new()
	_start_button.text = "Start 15-second diagnostic"
	_start_button.position = Vector2(20,145)
	_start_button.pressed.connect(func(): _started=true; _start_button.hide())
	root.add_child(_start_button)

func _on_physics_frame() -> void:
	if not _started or _finished: return
	super._on_physics_frame()
	if _total_solver_step_count > 0 and _total_solver_step_count % 60 == 0:
		print("VISUAL_SPEED ", JSON.stringify({"steps":_total_solver_step_count,"elapsed_s":(Time.get_ticks_usec()-_profile_start_us)/1000000.0,"cache_hits":_sdk.hits,"cache_misses":_sdk.misses,"saved_s":_sdk.saved_us/1000000.0,"phase":_arms[_authorized_arm_id].orchestrator_state.phase}))

func _finish_visual(reason: String) -> void:
	_finished = true
	_finalizing = true
	PhysicsServer3D.set_active(false)
	var output := {"diagnostic_only":true,"physical_acceptance_authority":false,"release_authority":false,"reason":reason,"samples":_samples,"cost":_cost.sections,"poses":_pose_frames,"kicks":_external_kick_application_count}
	var f := FileAccess.open(_diagnostic.output,FileAccess.WRITE)
	f.store_string(JSON.stringify(output)); f.close()
	print("VISUAL_FINISHED ",reason)
	if not _pose_frames.is_empty():
		for id in _last_model.body_nodes:
			var body: Node3D = _last_model.body_nodes[id]
			var ghost := Node3D.new()
			for child in body.get_children():
				if child is MeshInstance3D: ghost.add_child(child.duplicate())
			_last_model.world.add_child(ghost)
			ghost.hide()
			_replay_nodes[id] = ghost
		_start_button.text = "Watch computed physics at normal speed (1x)"
		_start_button.show()
		for connection in _start_button.pressed.get_connections(): _start_button.pressed.disconnect(connection.callable)
		_start_button.pressed.connect(_start_replay)

	if is_instance_valid(_label): _label.text += "\n"+reason+" — physics paused. Close window when done."

func _abort(code: String, detail: Dictionary = {}) -> void:
	if _check_only: print("VISUAL_CHECK_END ",code); return
	print("VISUAL_ABORT ",code," ",JSON.stringify(detail).left(6000))
	_finish_visual(code)

func _finalize_process_isolated_child_result_v1() -> void:
	_finish_visual("Controller terminal: "+str(_arms[_authorized_arm_id].orchestrator_state.phase))

func _check_diagnostic_schedule() -> Dictionary:
	var sha := "sha256:"+"1".repeat(64)
	var initialized := R10AP.initialize_v1(_sdk,"ffffffffffffffffffffffffffffffff",EnergyInitializer.ACTIVE_ARM_ID,"visual-synthetic",sha,sha)
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
			"walking_session_id":"visual-synthetic-prefix","walking_session_local_step":n,"walking_actuation_applied":true})
		if event.get("ok") != true: return event
		var result := R10AP.advance_v1(_sdk,state,event.event)
		if result.get("ok") != true: return result
		state = result.state_after
		if n < 600 and state.phase != Orchestrator.PHASE_WALKING_PREFIX: return {"ok":false,"early_kick":n}
	var steps := LocomotionFacade.initial_gait_steps_v1(74,"walking_prefix")
	return {"ok":state.phase == Orchestrator.PHASE_INTERACTION and steps.values() == [74,74,74,74],
		"kick_command":600,"total_timed_commands":1800,"phase":steps,"world_build_count":0,"solver_step_count":0}

func _finish_walking_session_v1(arm_id: String) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var session: Dictionary = arm.active_walking_session
	if session.is_empty(): return {"ok":true,"session_closed":false}
	if arm.walking_session_completion_attempted: return {"ok":false,"failure_code":"VISUAL_REPEATED_SHUTDOWN"}
	arm.walking_session_completion_attempted = true
	var completion: Dictionary = arm.facade.finish_walking_session_v1()
	if completion.get("ok") != true or completion.get("adapter_shutdown_receipt",{}).get("ok") != true: return completion
	arm.walking_sessions.append({"evaluation_segment_id":session.evaluation_segment_id,"session_id":session.session_id,
		"start_receipt":session.start_receipt,"completion_receipt":completion,"evaluation":{"diagnostic_only":true,"formal_evaluation_performed":false}})
	arm.active_walking_session = {}
	arm.last_walking_evaluation_failure = {}
	_arms[arm_id] = arm
	return {"ok":true,"session_closed":true,"formal_evaluation_performed":false}

func _start_replay() -> void:
	_replay_time = 0.0
	_replaying = true
	for body in _last_model.body_nodes.values(): body.hide()
	for body in _replay_nodes.values(): body.show()
	_start_button.hide()

func _process(delta: float) -> bool:
	if not _replaying: return false
	_replay_time += delta
	var index := mini(int(_replay_time*120.0),_pose_frames.size()-1)
	var frame: Dictionary = _pose_frames[index]
	for id in frame.poses:
		var v: Array = frame.poses[id]
		_replay_nodes[id].transform = Transform3D(Basis(Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8]),Vector3(v[9],v[10],v[11])),Vector3(v[0],v[1],v[2]))
	_camera.position = _replay_nodes.torso.position+Vector3(1.5,1.0,2.0)
	_camera.look_at(_replay_nodes.torso.position)
	_label.text = "UNOFFICIAL COMPUTED PHYSICS REPLAY — 1x simulated time\n%.2f / 15.00 seconds | %s\nKick scheduled at 5 seconds. Display meshes only; physics is paused." % [frame.t,frame.phase]
	if index == _pose_frames.size()-1:
		_replaying = false
		_start_button.show()
	return false
