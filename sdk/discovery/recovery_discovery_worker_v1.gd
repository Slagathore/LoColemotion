extends "res://sdk/adapters/godot/gdscript/r10ap_linked_capture_worker_v1.gd"
## Same production setup and prefix, followed by an explicitly distinct tail.
const Discovery := preload("res://sdk/discovery/recovery_discovery_context_v1.gd")
const Capture := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_context_v1.gd")
const SELF := "res://sdk/discovery/recovery_discovery_worker_v1.gd"
var _discovery_mode := "physical"
var _discovery_output := ""
var _tail_active := false
var _tail_start := 0
var _tail_rows: Array = []
var _disturbance: Dictionary = {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] in ["prepare", "preworld"]:
		_discovery_mode = args[0]
		_discovery_output = args[1]
	elif not args.is_empty():
		quit(2)
		return
	if not Discovery.initialize(OS.get_environment(Discovery.ENV), _discovery_mode != "physical") or not Discovery.install_walking_behavior():
		push_error("DISCOVERY_INITIALIZATION_REFUSED")
		quit(2)
		return
	if _discovery_mode == "prepare":
		call_deferred("_prepare_discovery_context")
		return
	super._initialize()

func _prepare_discovery_context() -> void:
	_campaign_declaration = Discovery.declaration
	_candidate_selection = CandidateProfile.load_v1(_campaign_declaration.candidate_profile)
	if _candidate_selection.is_empty():
		push_error("DISCOVERY_CANDIDATE_PROFILE")
		quit(3)
		return
	_entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(_entry_selection_v1().binding))
	_seed = int(_campaign_declaration.seed)
	if not _load_runtime_extension_v1():
		push_error("DISCOVERY_RUNTIME")
		quit(4)
		return
	_sdk = ClassDB.instantiate(CLASS_NAME)
	_context = RouteScript.prepare_complete_energy_context_v18(_sdk, RECOVERY_CONTROLLER_ID)
	var captured := Capture.capture_prepared_v1(_sdk, _context)
	if captured.get("ok") != true:
		push_error("DISCOVERY_CONTEXT")
		quit(5)
		return
	var snapshot := Capture.snapshot_v1(captured)
	var prefix_probe := _synthetic_prefix_probe()
	if prefix_probe.get("ok") != true:
		_write_probe({"ok": false, "failure_code": "DISCOVERY_PREFIX_INTERFACE", "detail": prefix_probe})
		return
	_write_probe({"ok": true, "world_build_count": 0, "solver_step_count": 0,
		"expectation": {"raw_capture_binding": {"utf8_byte_length": snapshot.utf8_byte_length,
		"raw_sha256": snapshot.raw_sha256}, "collection_identity": JSON.parse_string(captured.expected_identity.utf8_text)},
		"runtime_preflight": _entry_walking_runtime_preflight, "synthetic_prefix_probe": prefix_probe})

func _synthetic_prefix_probe() -> Dictionary:
	# A synthetic state exercises every real worker event builder and transition
	# in the prefix. It is never used to initialize a physical world.
	var sha := "sha256:" + "1".repeat(64)
	var initialized := R10AP.initialize_v1(_sdk, "ffffffffffffffffffffffffffffffff", "kick_passive_recovery_resume", "synthetic-discovery-model", sha, sha)
	if initialized.get("ok") != true: return initialized
	var state: Dictionary = initialized.state
	state.phase = Orchestrator.PHASE_WALKING_PREFIX
	state.previous_global_semantic_step = 241
	state.total_completed_solver_step_count = 241
	state.state_revision = 241
	state.precondition_recovery_step_count = 240
	state.precondition_pair_ready = true
	state.precondition_pair_release_step_count = 1
	state.payload_sha256 = R10AP.Prior._payload_sha256_v1(_sdk, state)
	var retained := []
	for local_step in range(1, 31):
		var fields := {"event_kind":"walking_policy_step", "global_semantic_step":241+local_step,
			"control_owner":"walking_bw5r_b", "actuation_owner":"walking_bw5r_b", "application_intent_sha256":sha,
			"walking_session_id":"synthetic-prefix", "walking_session_local_step":local_step,
			"walking_actuation_applied":_walking_owner_for_phase_v1(state.phase) == "walking_bw5r_b"}
		var event := _build_orchestrator_event_v1(state, fields)
		if event.get("ok") != true: return {"ok":false,"step":local_step,"detail":event,"state":state}
		var advanced := _advance_orchestrator_step_v1(state, event.event)
		if advanced.get("ok") != true: return advanced
		retained.append({"event":event.event,"advance":advanced})
		state = advanced.state_after
	return {"ok":state.phase == Orchestrator.PHASE_INTERACTION, "transitions":retained,"world_build_count":0,"solver_step_count":0}

func _write_probe(value: Dictionary) -> void:
	if FileAccess.file_exists(_discovery_output):
		quit(6)
		return
	var file := FileAccess.open(_discovery_output, FileAccess.WRITE)
	file.store_string(JsonTransportScript.stringify(value))
	file.close()
	quit(0 if value.get("ok") == true else 7)

func _build_arm_v1(arm_id: String) -> Dictionary:
	if _discovery_mode == "preworld":
		# Execute the real construction boundary with permission withheld.
		var world: Script = load("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
		var refusal: Dictionary = await world.build_world_v1(self, _sdk, _context)
		_write_probe({"ok": refusal.get("failure_code") == "DISCOVERY_WORLD_PERMISSION_REFUSED",
			"guard": refusal, "world_build_count": 0, "solver_step_count": 0,
			"l15_prepared_context_comparison": get_meta("l15_prepared_context_comparison", {})})
		return {"ok": false, "failure_code": "DISCOVERY_PREWORLD_COMPLETE"}
	return await super._build_arm_v1(arm_id)

func _abort(code: String, detail: Dictionary = {}) -> void:
	if _discovery_mode == "preworld" and detail.get("failure_code") == "DISCOVERY_PREWORLD_COMPLETE": return
	if _discovery_mode != "physical":
		_write_probe({"ok": false, "failure_code": code, "detail": detail, "world_build_count": 0, "solver_step_count": 0})
		return
	if _tail_active and not _finalizing and not _exit_scheduled:
		_finish_discovery(false, code, detail)
		return
	super._abort(code, detail)

func _declaration_path_v1() -> String:
	return OS.get_environment(Discovery.ENV)

func _entry_selection_v1() -> Dictionary:
	var selection := super._entry_selection_v1().duplicate(true)
	selection["worker"] = SELF
	return selection

func _authorized_seed_binding_v1(seed_text: String, label: String, digest: String) -> bool:
	if not Discovery.selected(): return false
	var value := Discovery.declaration
	var expected := "DISCOVERY-PHASE-" + str(int(value.discovery_cell.phase)) + "-V1"
	return (seed_text == str(int(value.seed)) and label == expected and digest == "sha256:" + expected.sha256_text()
		and OS.get_environment(PARENT_ATTEMPT_ID_ENV) == value.attempt_id
		and OS.get_environment(ATTEMPT_ID_ENV) == value.children[0].child_attempt_id
		and OS.get_environment(NONCE_ENV) == value.children[0].termination_nonce
		and OS.get_environment(SOURCE_COMMIT_ENV) == value.source_snapshot.head)

func _load_runtime_extension_v1() -> bool:
	if not Discovery.select_runtime(RouteScript.ProfileCapabilityScript) or _entry_runtime.is_empty(): return false
	# Exact retained DLL and current host source are already verified by the new
	# manifest. Historical Rust pins stay with that immutable DLL's provenance.
	var selected: Dictionary = _entry_runtime.runtime
	for path in ["res://" + String(_entry_runtime.local_build_path), selected.path]:
		if "sha256:" + FileAccess.get_sha256(path) != selected.raw_sha256: return false
	if GDExtensionManager.is_extension_loaded(EXTENSION_PATH):
		if GDExtensionManager.unload_extension(EXTENSION_PATH) != GDExtensionManager.LOAD_STATUS_OK: return false
	if GDExtensionManager.load_extension(_entry_selection_v1().extension) != GDExtensionManager.LOAD_STATUS_OK or not ClassDB.class_exists(CLASS_NAME): return false
	var probe: Object = ClassDB.instantiate(CLASS_NAME)
	_entry_walking_runtime_preflight = LocomotionFacade.portable_session_preflight_v1(probe, _seed, true, Discovery.PREFIX)
	return _entry_walking_runtime_preflight.get("ok") == true and not GDExtensionManager.is_extension_loaded(EXTENSION_PATH)

func _walking_prefix_profile_id_v1(segment: String) -> String:
	return Discovery.PREFIX if segment == "walking_prefix" else ""

func _attach_profile_seed_context_v1(report: Dictionary) -> bool:
	report["discovery_cell"] = Discovery.declaration.discovery_cell.duplicate(true)
	report["discovery_manifest"] = Discovery.declaration.discovery_manifest.duplicate(true)
	return true

func _plan_next_process_isolated_frame_v1(global_step: int) -> Dictionary:
	if _arms[_authorized_arm_id].orchestrator_state.phase != Orchestrator.PHASE_INTERACTION:
		return super._plan_next_process_isolated_frame_v1(global_step)
	if _tail_active: return {"ok": false, "failure_code": "DISCOVERY_REPEATED_DISTURBANCE"}
	var closed := _finish_walking_session_v1(_authorized_arm_id)
	if closed.get("ok") != true: return closed
	var arm: Dictionary = _arms[_authorized_arm_id]
	var cell: Dictionary = Discovery.declaration.discovery_cell
	var baseline := _measure_tail(0, global_step)
	if baseline.get("ok") != true: return baseline
	var motors: Dictionary = arm.facade.configure_all_motors_v1(cell.actuation == "zero_velocity_brake", global_step + 1, "discovery_declared_disturbance")
	if motors.get("ok") != true: return motors
	var lateral := _vector3_from_array_v1(arm.prefix_session_start_receipt.get("task_frame_lateral_axis_world_host_real"))
	if not lateral.is_finite() or absf(lateral.length() - 1.0) > 2.0e-6: return {"ok": false, "failure_code": "DISCOVERY_AXIS"}
	var impulse: Vector3 = lateral * float(cell.impulse_ns)
	_disturbance = {"baseline": baseline, "motor_configuration": motors, "impulse_world_ns": _vector3_array_v1(impulse),
		"application_count": 0, "completed_prefix_step": global_step, "cell": cell.duplicate(true)}
	if cell.impulse_ns > 0.0:
		_apply_discovery_impulse(arm.model.body_nodes.torso, impulse)
		_external_kick_application_count += 1
		_disturbance.application_count = 1
	_tail_start = global_step
	_tail_active = true
	return {"ok": true}

func _apply_discovery_impulse(torso: RigidBody3D, impulse: Vector3) -> void:
	torso.apply_central_impulse(impulse)

func _on_physics_frame() -> void:
	if not _tail_active:
		super._on_physics_frame()
		return
	if _finalizing or _exit_scheduled: return
	_observed_global_solver_frames += 1
	_total_solver_step_count += 1
	var step := _observed_global_solver_frames
	var local_step := step - _tail_start
	if step > 592 or local_step > int(Discovery.declaration.discovery_cell.tail_steps):
		_finish_discovery(false, "DISCOVERY_STEP_BOUND")
		return
	_arms[_authorized_arm_id].model.host_step_count = step
	var row := _measure_tail(local_step, step)
	_tail_rows.append(row)
	if row.get("ok") != true:
		_finish_discovery(false, "DISCOVERY_MEASUREMENT", row)
	elif local_step == int(Discovery.declaration.discovery_cell.tail_steps):
		_finish_discovery(true, "declared_observation_complete")

func _measure_tail(local_step: int, global_step: int) -> Dictionary:
	var model: Dictionary = _arms[_authorized_arm_id].model
	var bodies := []
	for body_id in ContactFrames.World.ORDERED_BODY_IDS:
		var body: RigidBody3D = model.body_nodes[body_id]
		var callback: Dictionary = body.latest_direct_state_snapshot
		if callback.get("callback_sequence") != global_step: return {"ok": false, "failure_code": "DISCOVERY_CALLBACK_STEP", "body_id": body_id, "expected": global_step, "actual": callback.get("callback_sequence")}
		if not body.global_transform.is_finite() or not body.linear_velocity.is_finite() or not body.angular_velocity.is_finite(): return {"ok": false, "failure_code": "DISCOVERY_NONFINITE_STATE"}
		bodies.append({"body_id": body_id, "instance_id": body.get_instance_id(), "callback_sequence": callback.callback_sequence,
			"callback_pose": ContactFrames._pack_pose(callback.transform), "pose": ContactFrames._pack_pose(body.global_transform),
			"linear_velocity": _vector3_array_v1(body.linear_velocity), "angular_velocity": _vector3_array_v1(body.angular_velocity),
			"up_dot": body.global_transform.basis.y.dot(Vector3.UP)})
	var motors := []
	for joint_id in model.joint_nodes:
		var joint: HingeJoint3D = model.joint_nodes[joint_id]
		motors.append({"joint_id": joint_id, "enabled": joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR),
			"target_velocity": joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY),
			"maximum_impulse": joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE)})
	var torso: RigidBody3D = model.body_nodes.torso
	var contacts: Dictionary = ClassDB.class_call_static("JoltPhysicsServer3D", "space_get_contact_frames", torso.get_world_3d().space)
	return {"ok": true, "local_step": local_step, "global_step": global_step, "bodies": bodies, "motors": motors,
		"contacts": ContactFrames.pack_native_v1(contacts)}

func _finish_discovery(valid: bool, reason: String, detail: Dictionary = {}) -> void:
	if _finalizing or _exit_scheduled: return
	_finalizing = true
	_quiesce_process_isolated_child_v1()
	var arm: Dictionary = _arms[_authorized_arm_id]
	var identity: Dictionary = arm.facade.same_body_identity_receipt_v1(_sdk, _observed_global_solver_frames, "discovery_terminal")
	valid = valid and identity.get("ok") == true and identity.get("body_population_instance_sha256") == arm.body_population_instance_sha256
	var report := {"schema_version": "sporespore_recovery_discovery_observation_v1", "ok": valid,
		"ledger_scope": Discovery.declaration.ledger_scope, "source_commit": _source_commit,
		"declaration_sha256": _authorization_sha256, "child_attempt_id": _attempt_id, "parent_attempt_id": _parent_attempt_id,
		"process_id": OS.get_process_id(), "cell": Discovery.declaration.discovery_cell,
		"manifest": Discovery.declaration.discovery_manifest, "reason": reason, "detail": detail,
		"world_build_count": _total_world_build_count, "solver_step_count": _total_solver_step_count,
		"global_solver_frame_count": _observed_global_solver_frames, "disturbance": _disturbance,
		"tail_rows": _tail_rows, "terminal_identity": identity,
		"setup_and_prefix": partial_arm_failure_retention_projection_l15_v1(arm, _authorized_arm_id),
		"contact_sites_by_body": arm.model.blueprint.contact_by_body_id,
		"setup_and_prefix_contact_frames": _r10af_contact_frame_records,
		"precondition_terminal_receipt": _process_isolated_precondition_terminal_receipt,
		"precondition_release_receipt": _process_isolated_precondition_release_receipt,
		"l15_prepared_context_comparison": get_meta("l15_prepared_context_comparison", {}),
		"complete_route_proven": false, "held_out": false, "official_qualification": false,
		"physical_acceptance_authority": false, "release_authority": false}
	_cleanup_worlds_v1()
	print(SMOKE_RAW_MARKER, JsonTransportScript.stringify(report))
	_schedule_exit_v1(0 if valid else 1, "development_discovery_only")
