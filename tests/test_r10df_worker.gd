extends SceneTree
# gdlint: disable=max-line-length
const Worker := preload("res://sdk/adapters/godot/gdscript/r10df_recovery_worker_v1.gd")
const Flow := Worker.R10DF
const Session := Worker.ReferenceSession
const Source := Session.Source
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Native := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const SHA := "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const ARM := "kick_passive_recovery_resume"
var checks := {}
var _probe: SceneTree
var _surface := {}

class Probe:
	extends "res://sdk/adapters/godot/gdscript/r10df_recovery_worker_v1.gd"
	var fixture_requests: Array = []
	var next_index := 0
	func _initialize() -> void: pass
	# Explicit source injection: synthetic observations cannot be presented as
	# native physics/energy measurements. The production event, state, command
	# session and terminal-installation hooks below remain unchanged.
	func _entry_packet_v1(bound: Dictionary, _prior: Dictionary) -> Dictionary:
		var request: Dictionary = fixture_requests[0]
		var session := ReferenceSession.execute_v1(_sdk, request)
		if not session.ok: return session
		var native: Dictionary = session.native_receipt
		var retained: Dictionary = native.original_entry_control
		return {"ok": true, "call": session.call, "native_receipt": native,
			"bound_observations": bound, "entry_kind": retained.entry.memory.route,
			"original_entry_control_receipt": retained, "original_control_receipt": retained.original_control,
			"original_passive_receipt": retained.original_control.entry.original_passive_receipt,
			"entry_state": {"schema_version": PartialBridge.STATE, "declaration": request.entry.original_request.passive_request.declaration,
				"selector_memory": retained.entry.memory}}
	func _partial_step_packet_v1(bound: Dictionary, declaration: Dictionary, memory: Dictionary) -> Dictionary:
		next_index += 1
		var request: Dictionary = fixture_requests[next_index].duplicate(true)
		if not ReferenceSession._same(request.step.declaration, declaration) or not ReferenceSession._same(request.step.memory, memory):
			return {"ok": false, "failure_code": "SYNTHETIC_WORKER_SOURCE_CROSSED"}
		var packet := ReferenceSession.execute_v1(_sdk, request, _reference_packets[-1])
		_reference_packets.append(packet.duplicate(true))
		packet["bound_observations"] = bound.duplicate(true)
		return packet
	func _arm_epoch_initializer_sha256_v1(_arm: Dictionary) -> String: return "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or FileAccess.file_exists(args[1]): quit(1); return
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old): checks.unload = GDExtensionManager.unload_extension(old) == GDExtensionManager.LOAD_STATUS_OK
	checks.load = GDExtensionManager.load_extension("res://sdk/adapters/godot/development_candidate_runtimes/r10dd-native-reference-core-v1.gdextension") == GDExtensionManager.LOAD_STATUS_OK
	if checks.values().has(false): _finish(args[1]); return
	_probe = Probe.new()
	_probe._sdk = ClassDB.instantiate("SporeLocomotionSdk")
	var sdk: Object = _probe._sdk
	for line in FileAccess.get_file_as_string(args[0]).split("\n", false):
		var packet: Dictionary = sdk.decode_exact_json_v1(line)
		_probe.fixture_requests.append(sdk.decode_exact_json_v1(packet.call.request.utf8_text))
	checks.population = _probe.fixture_requests.size() == 238
	checks.owner_registered = Route.CanonicalOwnershipL15.candidate_id_valid_v1(Source.RECOVERY)
	checks.owner_typo_refused = not Route.CanonicalOwnershipL15.candidate_id_valid_v1(Source.RECOVERY + "x")
	checks.original_v28_registered = Route.CanonicalOwnershipL15.candidate_id_valid_v1("sporespore_exact_s169_partial_progressive_headroom_controller_v28")
	checks.stance_mapping = Route.DevelopmentStanceProfile.for_recovery_v1(Source.RECOVERY) == Source.STANCE
	checks.no_launch_authority = not _probe._authorized_seed_binding_v1("51008", "", SHA)
	_probe._candidate_selection = {"post_kick_controller_id": Flow.CONTROLLER, "diagnostic_schedule": {"walking_policy_id": Flow.ROUTE}}
	_probe._attempt_id = "r10df-synthetic-worker"
	_probe._configuration_sha256 = SHA
	checks.explicit_host_selection = preload("res://tests/r10ap_gate_runtime.gd").select_v1()
	_probe._context = Route.prepare_complete_energy_context_v18(sdk, Route.RECOVERY_CONTROLLER_V6_ID)
	checks.native_context = _probe._context.get("ok") == true
	if not checks.explicit_host_selection or not checks.native_context:
		print("R10DF_CONTEXT_FAILURE ", Session.Transport.stringify(_probe._context))
		_finish(args[1]); return
	_surface = Route.zero_world_command_surface_v1(_probe._context)
	checks.motor_surface = _surface.get("ok") == true
	if not checks.motor_surface: _finish(args[1]); return
	var state: Dictionary = _probe._initialize_orchestrator_v1(ARM, "r10df-synthetic-model", SHA).state
	# Prospective synthetic prefix checkpoint, not a rewritten physical state.
	state.phase = Flow.Passive.PHASE_DESCENT
	state.previous_global_semantic_step = 511
	state.total_completed_solver_step_count = 511
	state.state_revision = 511
	state.precondition_recovery_step_count = 240
	state.precondition_pair_ready = true
	state.precondition_pair_release_step_count = 1
	state.walking_prefix_step_count = 30
	state.prefix_walking_session_id = "r10df-synthetic-prefix"
	state.interaction_effect_step_count = 1
	state.epoch_start_global_step = 272
	state.interaction_receipt_sha256 = SHA
	state.energy_initializer_sha256 = SHA
	state.passive_descent_step_count = 239
	state.recovery_epoch_step_count = 239
	state.r10v_entry_kind = "waiting"
	state.payload_sha256 = Flow.Prior._payload_sha256_v1(sdk, state)
	checks.synthetic_checkpoint_valid = Flow.state_valid_v1(sdk, state)
	if not checks.synthetic_checkpoint_valid: _finish(args[1]); return
	_probe._arms[ARM] = {"orchestrator_state": state, "recovery_memory": {}, "passive_entry_handoff_receipt": {},
		"passive_entry_state": {}, "pending_application": {}, "trace_rows": [], "next_recovery_control": {},
		"body_population_rebuild_count": 0, "body_transform_write_count": 0, "body_velocity_write_count": 0, "solver_reset_count": 0,
		"terminal": false, "r10k_partial_declaration": {}, "r10k_partial_memory": {}, "r10v_upright_memory": {}}
	for index in range(238):
		var request: Dictionary = _probe.fixture_requests[index]
		var observation: Dictionary = request.entry.original_request.passive_request.observation if index == 0 else request.step.observation
		var bound := {"observation_v2": request.collection.observation, "observation_v3": observation, "source_binding": request.collection.observation_source_binding}
		var step: int = observation.semantic_step
		var arm: Dictionary = _probe._arms[ARM]
		arm.last_collection = {"epoch_result": {"bound_epoch_observations": bound}, "global_result": {"bound": {"observation_v3": observation}}}
		arm.trace_rows.append({})
		arm.pending_application = {"synthetic_application_step": step}
		_probe._arms[ARM] = arm
		var result: Dictionary = _probe._process_descent_v1(ARM, step) if index == 0 else _probe._process_r10k_partial_v1(ARM, step)
		checks["worker_" + str(index)] = result.get("ok") == true
		if result.get("ok") != true:
			print("R10DF_WORKER_FAILURE ", Session.Transport.stringify(result))
			_finish(args[1]); return
		arm = _probe._arms[ARM]
		if index < 237:
			checks["active_" + str(index)] = not arm.terminal and arm.orchestrator_state.phase == Flow.PHASE_PARTIAL
			var control: Dictionary = arm.next_recovery_control
			for joint in observation.state.ordered_joint_observations:
				_surface.position_by_joint_id[joint.joint_id] = joint.position_rad
			var applied := Route.apply_behavior_control_solver_coupled_native_constraint_motor_v11(sdk, control,
				_surface.joint_by_actuator_id, _surface.position_by_joint_id, true, Source.RECOVERY)
			checks["motor_" + str(index)] = applied.get("ok") == true and applied.get("motor_enabled_count") == 8 and applied.get("solver_step_count") == 0
			if applied.get("ok") != true: print("R10DF_MOTOR_FAILURE ", Session.Transport.stringify(applied)); _finish(args[1]); return
		else:
			checks.finite_stop_installed = arm.terminal and arm.orchestrator_state.phase == Flow.Prior.PHASE_FAILED
			checks.original_task_preserved = arm.r10k_partial_memory.phase == "raise_body" and arm.orchestrator_state.partial_phase == "raise_body"
			checks.stop_reason = arm.orchestrator_state.diagnostic_stop_reason == "finite_reference_exhausted_not_recovery_completion"
			checks.no_next_command = arm.next_recovery_control.is_empty()
			checks.no_walking_resume = arm.orchestrator_state.walking_resume_step_count == 0
			checks.terminal_source_retained = arm.terminal_recovery_observation_sources.bound_recovery_observations == bound
			checks.reference_retention = _probe._reference_packets.size() == 238
			var invalid: Dictionary = arm.orchestrator_state.duplicate(true)
			invalid.phase = Flow.Prior.PHASE_WALKING_RESUME
			invalid.terminal_outcome = ""
			invalid.terminal_reason = ""
			invalid.payload_sha256 = Flow.Prior._payload_sha256_v1(sdk, invalid)
			checks.exhaustion_cannot_resume = not Flow.state_valid_v1(sdk, invalid)
	checks.actual_sampler_default_unchanged = Native.TaskSource.select_v1(sdk, {}, {}, 1).get("task_id") == Source.CANONICAL_TASK
	for key in Source.COMPETING_KEYS:
		checks["competing_" + key] = Native.TaskSource.select_v1(sdk, {Source.KEY: {}, key: {}}, {}, 1).get("failure_code") == "R10DE_PARTIAL_TASK_SOURCE_COMPETING_TASKS"
	checks.reference_replay = Session.replay_v1(sdk, _probe._reference_packets).get("ok") == true
	_finish(args[1])

func _finish(output: String) -> void:
	var result := {"ok": not checks.is_empty() and not checks.values().has(false), "checks": checks,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false,
		"synthetic_source_injection": true, "full_physical_source_collection_tested": false}
	var out := FileAccess.open(output, FileAccess.WRITE)
	if out != null: out.store_string(Session.Transport.stringify(result)); out.close()
	if not _surface.is_empty(): Route.free_zero_world_command_surface_v1(_surface)
	if _probe != null: _probe._sdk = null; _probe.free()
	print("R10DF_WORKER ", JSON.stringify({"ok": result.ok, "checks": checks.size()}))
	quit(0 if result.ok else 1)
