extends "res://tests/test_development_r10k_worker_hooks.gd"
# gdlint: disable=max-line-length

## Exercise unchanged partial/prone synthetic observations through the actual
## R10T worker and its nested original native control receipts.
const R10TWorker := preload("res://sdk/adapters/godot/gdscript/r10t_recovery_worker_v1.gd")
const R10T := R10TWorker.R10T

class R10TBranchProbe:
	extends "res://sdk/adapters/godot/gdscript/r10t_recovery_worker_v1.gd"
	func _initialize() -> void:
		pass

func _profile_resource_v1() -> String:
	return "res://sdk/development/recovery_candidates/r10t-v56-post-recovery-hold-integrated-v1.json"

func _configure_fixture_probe_v1(probe: SceneTree, resource: String) -> void:
	probe._candidate_selection = R10TWorker.CandidateProfile.load_v1({"resource": resource, "raw_sha256": "sha256:" + FileAccess.get_sha256(resource)})
	probe._configuration_sha256 = SHA

func _finish_r10t(probe: SceneTree, failure: Dictionary) -> void:
	super._finish_r10k(probe, failure)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3 or args[2] not in ["partial", "prone"]: quit(1); return
	_output = args[1]
	_legacy = false
	_genuine_prone = _legacy or args.size() == 3 and args[2] == "prone"
	var resource := _profile_resource_v1()
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(resource))
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old):
		checks["unload"] = GDExtensionManager.unload_extension(old) == GDExtensionManager.LOAD_STATUS_OK
	checks["load"] = GDExtensionManager.load_extension(profile.extension) == GDExtensionManager.LOAD_STATUS_OK
	var probe := R10TBranchProbe.new()
	probe._sdk = ClassDB.instantiate("SporeLocomotionSdk")
	var sdk: Object = probe._sdk
	for line in FileAccess.get_file_as_string(args[0]).split("\n"):
		if line.begins_with("R10K_CONTROL_FIXTURE "):
			var fixture: Dictionary = sdk.decode_exact_json_v1(line.trim_prefix("R10K_CONTROL_FIXTURE "))
			if fixture.kind != "entry":
				_pose = fixture.request.step.observation
				break
	if _pose.is_empty(): _finish_r10t(probe, {"failure_code": "R10T_PARTIAL_FIXTURE_MISSING"}); return
	_configure_fixture_probe_v1(probe, resource)
	checks["immutable_core_profile_loads"] = not probe._candidate_selection.is_empty()
	probe._context = Route.prepare_complete_energy_context_v18(sdk, Route.RECOVERY_CONTROLLER_V6_ID)
	probe._attempt_id = _fixture_attempt_id_v1()
	probe._repair_id = "QSDK-R10F-L15"
	probe._authorized_arm_id = ARM
	var fixture := _initial_entry_fixture(sdk, probe._context)
	if fixture.get("ok") != true: _finish_r10t(probe, {"initial_source": fixture}); return
	_surface = Route.zero_world_command_surface_v1(probe._context)
	if _surface.get("ok") != true: _finish_r10t(probe, {"surface": _surface}); return
	var initial: Dictionary = probe._initialize_orchestrator_v1(ARM, Sources.Prior.MODEL_INSTANCE_ID, SHA)
	var state: Dictionary = initial.get("state", {})
	# Explicit synthetic pre-kick state; no observed campaign is converted.
	state.phase = Prior.PHASE_INTERACTION
	state.previous_global_semantic_step = 271
	state.total_completed_solver_step_count = 271
	state.state_revision = 271
	state.precondition_recovery_step_count = 240
	state.precondition_pair_ready = true
	state.precondition_pair_release_step_count = 1
	state.walking_prefix_step_count = 30
	state.prefix_walking_session_id = "synthetic-prefix"
	state.payload_sha256 = Prior._payload_sha256_v1(sdk, state)
	var model := {Worker.NativeEpochRoute.MODEL_EPOCH_INITIALIZER_KEY: fixture.energy_initializer,
		"complete_energy_profile_selected": true, "solver_coupled_complete_energy_profile_selected": true,
		"discrete_staging_complete_energy_profile_selected": true, "route_aware_application_provenance_selected": true,
		"joint_by_actuator_id": _surface.joint_by_actuator_id}
	probe._arms[ARM] = {"facade": Sources.SyntheticMotorReadback.new(), "model": model, "orchestrator_state": state,
		"recovery_memory": {"synthetic_completed_setup_memory": true}, "next_recovery_control": {"synthetic_completed_setup_control": true},
		"last_recovery_terminal": false, "last_recovery_classification": {}, "last_recovery_global_semantic_step": 0,
		"last_recovery_terminal_phase": "", "last_recovery_terminal_failure_code": "", "terminal": false,
		"recovery_step_receipts": [], "recovery_development_progression_receipts": [], "trace_rows": [],
		"body_population_rebuild_count": 0, "body_transform_write_count": 0, "body_velocity_write_count": 0, "solver_reset_count": 0}
	var kick: Dictionary = probe._build_orchestrator_event_v1(state, {"event_kind": "kick_effect_step",
		"global_semantic_step": 272, "application_intent_sha256": SHA, "no_actuation_requested": true,
		"interaction_receipt_sha256": fixture.energy_initializer.kick_interaction_receipt_sha256,
		"energy_initializer_sha256": fixture.energy_initializer.payload_sha256, "kick_application_count": 1,
		"walking_motors_disabled_in_same_pre_solver_event": true})
	var installed: Dictionary = probe._install_orchestrator_event_v1(ARM, state, {}, {}, {}, kick)
	if installed.get("ok") != true: _finish_r10t(probe, {"interaction": installed}); return
	checks["interaction_clears_only_active_setup_memory"] = probe._arms[ARM].recovery_memory.is_empty() and probe._arms[ARM].get("r10k_partial_memory", {}).is_empty()
	for step in range(273, 287 if _genuine_prone else 576):
		var planned: Dictionary = probe._plan_next_process_isolated_frame_v1(step - 1)
		if planned.get("ok") != true: _finish_r10t(probe, {"planned_step": step, "plan": planned}); return
		var arm: Dictionary = probe._arms[ARM]
		var application: Dictionary = arm.pending_application
		if step == 513:
			checks["first_partial_actual_motors_enabled"] = _surface.joint_by_actuator_id.values().all(func(joint): return joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR))
			checks["actual_applier_source_selected"] = Bridge.Source.select_v1(sdk, arm.model, application, step).get("partial_task_selected") == true
			var original_memory: Dictionary = arm.r10k_partial_memory
			var bad := original_memory.duplicate(true)
			bad.last_semantic_step += 1
			probe._arms[ARM].r10k_partial_memory = bad
			checks["crossed_memory_refused_before_native_read"] = probe._collect_arm_completed_step_v1(ARM, step).get("failure_code") == "R10K_PENDING_PARTIAL_SOURCE_CROSSED"
			probe._arms[ARM].r10k_partial_memory = original_memory
		var projected := (super._project(sdk, probe._context, fixture, application, step, true)
			if _genuine_prone else _project_r10k(sdk, probe._context, fixture, application, step, step > 512))
		if projected.get("ok") != true: _finish_r10t(probe, {"projected_step": step, "projection": projected}); return
		probe._arms[ARM]["last_collection"] = {"epoch_result": projected.epoch, "global_result": projected.global_result,
			"epoch_local_step": step - 272}
		probe._arms[ARM].trace_rows.append(_completed_fixture_trace_v1(sdk, arm, projected, step))
		var processed: Dictionary = probe._process_completed_arm_step_v1(ARM, step, false)
		if processed.get("ok") != true: _finish_r10t(probe, {"processed_step": step, "processing": processed}); return
		fixture = projected.fixture_after
		if step == 512:
			checks["worker_partial_handoff_after_240"] = probe._arms[ARM].orchestrator_state.phase == R10T.PHASE_PARTIAL
			checks["worker_never_creates_canonical_memory"] = probe._arms[ARM].recovery_memory.is_empty() and probe._arms[ARM].orchestrator_state.confirm_prone_step_count == 0
		if probe._arms[ARM].orchestrator_state.phase == Prior.PHASE_FAILED:
			_finish_r10t(probe, {"unexpected_synthetic_negative_step": step, "state": probe._arms[ARM].orchestrator_state}); return
	var final_arm: Dictionary = probe._arms[ARM]
	if _legacy:
		checks["unselected_worker_retains_original_state_authority"] = Entry.state_valid_v1(sdk, final_arm.orchestrator_state, profile.post_kick_controller_id)
		checks["unselected_worker_has_no_r10k_state"] = not final_arm.orchestrator_state.has("r10k_entry_kind") and not final_arm.has("r10k_partial_memory")
		checks["unselected_worker_keeps_12_confirmation_samples"] = final_arm.orchestrator_state.confirm_prone_step_count == 12
		checks["unselected_worker_advances_actual_v20"] = final_arm.orchestrator_state.post_kick_recovery_step_count == 2 and not final_arm.next_recovery_control.is_empty()
		checks["unselected_worker_retains_original_entry_calls"] = probe._entry_packets.size() == 1 and probe._entry_packets[0].has("entry_call") and probe._canonical_packets.size() == 13
		checks["unselected_worker_has_no_partial_packets"] = probe._r10k_partial_packets.is_empty() and probe._r10k_first_partial_application.is_empty()
		_finish_r10t(probe, {})
		return
	if _genuine_prone:
		checks["genuine_prone_branch_selected"] = final_arm.orchestrator_state.r10t_entry_kind == "prone"
		checks["genuine_prone_keeps_12_confirmation_samples"] = final_arm.orchestrator_state.confirm_prone_step_count == 12
		checks["genuine_prone_advances_actual_v20"] = final_arm.orchestrator_state.post_kick_recovery_step_count == 2 and not final_arm.next_recovery_control.is_empty()
		checks["genuine_prone_creates_no_partial_history"] = final_arm.r10k_partial_memory.is_empty() and final_arm.orchestrator_state.partial_start_global_step == null and probe._r10k_partial_packets.is_empty()
		var declared: Dictionary = sdk.decode_exact_json_v1(probe._entry_packets[0].call.request.utf8_text)
		checks["genuine_prone_uses_prospective_standing_profile"] = declared.entry.original_request.passive_request.declaration.initialization.threshold_profile_id == Bridge.PROFILE
		checks["genuine_prone_native_packets_retained"] = probe._entry_packets.size() == 1 and probe._canonical_packets.size() == 13
		_finish_r10t(probe, {})
		return
	checks["all_63_partial_worker_steps_retained"] = probe._r10k_partial_packets.size() == 63
	checks["all_240_original_passive_receipts_retained"] = probe._entry_packets.size() == 240
	checks["actual_worker_ready_for_fresh_walk"] = final_arm.orchestrator_state.phase == Prior.PHASE_WALKING_RESUME and final_arm.r10k_partial_memory.standing_samples_observed == 60
	checks["producer_tag_cleared_after_final_partial_observation"] = not final_arm.model.has(Bridge.Source.KEY) and final_arm.pending_application.has(Bridge.Source.KEY)
	checks["original_kick_epoch_persists"] = final_arm.orchestrator_state.epoch_start_global_step == 272 and final_arm.orchestrator_state.energy_initializer_sha256 == fixture.energy_initializer.payload_sha256
	checks["canonical_history_remains_absent"] = final_arm.recovery_memory.is_empty() and final_arm.orchestrator_state.confirm_prone_step_count == 0 and probe._canonical_packets.is_empty()
	checks["all_command_surfaces_uninserted"] = _surface.ordered_joints.all(func(joint): return not joint.is_inside_tree())
	_finish_r10t(probe, {})
