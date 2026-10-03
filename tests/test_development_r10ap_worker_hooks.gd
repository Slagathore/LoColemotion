extends "res://tests/test_development_passive_entry_worker_hooks.gd"
# gdlint: disable=max-line-length

## Synthetic full partial/prone sequence through real R10AP worker hooks and
## native DLL, with real motor commands applied only to uninserted hinges.
const R10APWorker := preload("res://sdk/adapters/godot/gdscript/r10ap_recovery_worker_v1.gd")
const R10AP := R10APWorker.R10AP
const Bridge := R10APWorker.PartialBridge
var _pose: Dictionary = {}
var _surface: Dictionary = {}
var _output := ""
var _genuine_prone := false
var _legacy := false

class R10APBranchProbe:
	extends "res://sdk/adapters/godot/gdscript/r10ap_recovery_worker_v1.gd"
	func _initialize() -> void:
		pass

func _profile_resource_v1() -> String:
	return "res://sdk/development/recovery_candidates/r10ap-progressive-headroom-core-v1.runtime.json"

func _configure_fixture_probe_v1(probe: SceneTree, _resource: String) -> void:
	checks["explicit_v7_runtime_without_world_authority"] = preload("res://tests/r10ap_gate_runtime.gd").select_v1()
	# Explicit component configuration, not a qualified launchable profile.
	probe._candidate_selection = {
		"post_kick_controller_id": "sporespore_exact_s169_prone_to_standing_controller_v20",
		"diagnostic_schedule": {"walking_policy_id": R10AP.ROUTE}}
	probe._configuration_sha256 = SHA
	checks["component_cannot_authorize_launch"] = not probe._authorized_seed_binding_v1("51008", "", SHA)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3 or args[2] not in ["partial", "prone"]: quit(1); return
	_output = args[1]
	_legacy = false
	_genuine_prone = _legacy or args.size() == 3 and args[2] == "prone"
	var resource := _profile_resource_v1()
	var profile: Dictionary = {"extension": "res://sdk/adapters/godot/development_candidate_runtimes/r10ap-progressive-headroom-core-v1.gdextension",
		"post_kick_controller_id": "sporespore_exact_s169_prone_to_standing_controller_v20"}
	var old := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
	if GDExtensionManager.is_extension_loaded(old):
		checks["unload"] = GDExtensionManager.unload_extension(old) == GDExtensionManager.LOAD_STATUS_OK
	checks["load"] = GDExtensionManager.load_extension(profile.extension) == GDExtensionManager.LOAD_STATUS_OK
	var probe := R10APBranchProbe.new()
	probe._sdk = ClassDB.instantiate("SporeLocomotionSdk")
	var sdk: Object = probe._sdk
	for line in FileAccess.get_file_as_string(args[0]).split("\n"):
		if line.begins_with("R10K_CONTROL_FIXTURE "):
			var fixture: Dictionary = sdk.decode_exact_json_v1(line.trim_prefix("R10K_CONTROL_FIXTURE "))
			if fixture.kind != "entry":
				_pose = fixture.request.step.observation
				break
	if _pose.is_empty(): _finish_r10aa(probe, {"failure_code": "R10V_PARTIAL_FIXTURE_MISSING"}); return
	_configure_fixture_probe_v1(probe, resource)
	checks["explicit_component_configuration"] = not probe._candidate_selection.is_empty()
	probe._context = Route.prepare_complete_energy_context_v18(sdk, Route.RECOVERY_CONTROLLER_V6_ID)
	probe._attempt_id = _fixture_attempt_id_v1()
	probe._repair_id = "QSDK-R10F-L15"
	probe._authorized_arm_id = ARM
	var fixture := _initial_entry_fixture(sdk, probe._context)
	if fixture.get("ok") != true: _finish_r10aa(probe, {"initial_source": fixture}); return
	_surface = Route.zero_world_command_surface_v1(probe._context)
	if _surface.get("ok") != true: _finish_r10aa(probe, {"surface": _surface}); return
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
	if installed.get("ok") != true: _finish_r10aa(probe, {"interaction": installed}); return
	checks["interaction_clears_only_active_setup_memory"] = probe._arms[ARM].recovery_memory.is_empty() and probe._arms[ARM].get("r10k_partial_memory", {}).is_empty()
	for step in range(273, 287 if _genuine_prone else 576):
		var planned: Dictionary = probe._plan_next_process_isolated_frame_v1(step - 1)
		if planned.get("ok") != true: _finish_r10aa(probe, {"planned_step": step, "plan": planned}); return
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
			if _genuine_prone else _project_r10aa(sdk, probe._context, fixture, application, step, step > 512))
		if projected.get("ok") != true: _finish_r10aa(probe, {"projected_step": step, "projection": projected}); return
		probe._arms[ARM]["last_collection"] = {"epoch_result": projected.epoch, "global_result": projected.global_result,
			"epoch_local_step": step - 272}
		probe._arms[ARM].trace_rows.append(_completed_fixture_trace_v1(sdk, arm, projected, step))
		var processed: Dictionary = probe._process_completed_arm_step_v1(ARM, step, false)
		if processed.get("ok") != true: _finish_r10aa(probe, {"processed_step": step, "processing": processed}); return
		fixture = projected.fixture_after
		if step == 512:
			checks["worker_partial_handoff_after_240"] = probe._arms[ARM].orchestrator_state.phase == R10AP.PHASE_PARTIAL
			checks["worker_never_creates_canonical_memory"] = probe._arms[ARM].recovery_memory.is_empty() and probe._arms[ARM].orchestrator_state.confirm_prone_step_count == 0
		if probe._arms[ARM].orchestrator_state.phase == Prior.PHASE_FAILED:
			_finish_r10aa(probe, {"unexpected_synthetic_negative_step": step, "state": probe._arms[ARM].orchestrator_state}); return
	var final_arm: Dictionary = probe._arms[ARM]
	if _legacy:
		checks["unselected_worker_retains_original_state_authority"] = Entry.state_valid_v1(sdk, final_arm.orchestrator_state, profile.post_kick_controller_id)
		checks["unselected_worker_has_no_r10k_state"] = not final_arm.orchestrator_state.has("r10k_entry_kind") and not final_arm.has("r10k_partial_memory")
		checks["unselected_worker_keeps_12_confirmation_samples"] = final_arm.orchestrator_state.confirm_prone_step_count == 12
		checks["unselected_worker_advances_actual_v20"] = final_arm.orchestrator_state.post_kick_recovery_step_count == 2 and not final_arm.next_recovery_control.is_empty()
		checks["unselected_worker_retains_original_entry_calls"] = probe._entry_packets.size() == 1 and probe._entry_packets[0].has("entry_call") and probe._canonical_packets.size() == 13
		checks["unselected_worker_has_no_partial_packets"] = probe._r10k_partial_packets.is_empty() and probe._r10k_first_partial_application.is_empty()
		_finish_r10aa(probe, {})
		return
	if _genuine_prone:
		checks["genuine_prone_branch_selected"] = final_arm.orchestrator_state.r10v_entry_kind == "prone"
		checks["genuine_prone_keeps_12_confirmation_samples"] = final_arm.orchestrator_state.confirm_prone_step_count == 12
		checks["genuine_prone_advances_actual_v20"] = final_arm.orchestrator_state.post_kick_recovery_step_count == 2 and not final_arm.next_recovery_control.is_empty()
		checks["genuine_prone_creates_no_partial_history"] = final_arm.r10k_partial_memory.is_empty() and final_arm.orchestrator_state.partial_start_global_step == null and probe._r10k_partial_packets.is_empty()
		var declared: Dictionary = sdk.decode_exact_json_v1(probe._entry_packets[0].call.request.utf8_text)
		checks["genuine_prone_uses_prospective_standing_profile"] = declared.entry.original_request.passive_request.declaration.initialization.threshold_profile_id == Bridge.PROFILE
		checks["genuine_prone_native_packets_retained"] = probe._entry_packets.size() == 1 and probe._canonical_packets.size() == 13
		_finish_r10aa(probe, {})
		return
	checks["native_v28_receipts_only"] = probe._r10k_partial_packets.all(func(packet): return packet.native_receipt.get("control_composition_id") == Bridge.Source.COMPOSITION)
	checks["entry_geometry_retained"] = probe._entry_packets[-1].native_receipt.initial_load_plan.schema_version == "sporespore_r10ap_progressive_headroom_plan_v1"
	checks["geometry_present_only_in_controlled_pose_phases"] = probe._r10k_partial_packets.all(func(packet):
		var native: Dictionary = packet.native_receipt
		var phase: String = native.step.next_phase
		return (Bridge.Source._load_plan_valid(native.next_control, native.next_load_plan)
			if phase in Bridge.Source.PHASES else native.next_load_plan == null and native.next_control == null))
	checks["real_v28_first_application"] = probe._r10k_first_partial_application.get("recovery_controller_id") == Bridge.Source.RECOVERY
	checks["real_v7_stance_application"] = final_arm.pending_application.get("stance_controller_id") == Bridge.Source.STANCE
	checks["all_63_partial_worker_steps_retained"] = probe._r10k_partial_packets.size() == 63
	checks["all_240_original_passive_receipts_retained"] = probe._entry_packets.size() == 240
	checks["actual_worker_ready_for_fresh_walk"] = final_arm.orchestrator_state.phase == Prior.PHASE_WALKING_RESUME and final_arm.r10k_partial_memory.standing_samples_observed == 60
	checks["producer_tag_cleared_after_final_partial_observation"] = not final_arm.model.has(Bridge.Source.KEY) and final_arm.pending_application.has(Bridge.Source.KEY)
	checks["original_kick_epoch_persists"] = final_arm.orchestrator_state.epoch_start_global_step == 272 and final_arm.orchestrator_state.energy_initializer_sha256 == fixture.energy_initializer.payload_sha256
	checks["canonical_history_remains_absent"] = final_arm.recovery_memory.is_empty() and final_arm.orchestrator_state.confirm_prone_step_count == 0 and probe._canonical_packets.is_empty()
	checks["all_command_surfaces_uninserted"] = _surface.ordered_joints.all(func(joint): return not joint.is_inside_tree())
	_finish_r10aa(probe, {})

func _finish_r10aa(probe: SceneTree, failure: Dictionary) -> void:
	var arm: Dictionary = probe._arms.get(ARM, {})
	var result := {"ok": failure.is_empty() and not checks.values().has(false), "checks": checks, "failure": failure,
		"branch": "legacy" if _legacy else "prone" if _genuine_prone else "partial",
		"final_state": arm.get("orchestrator_state", {}), "final_partial_memory": arm.get("r10k_partial_memory", {}),
		"entry_packets": probe._entry_packets, "partial_packets": probe._r10k_partial_packets,
		"transitions": probe._entry_transitions, "first_partial_application": probe._r10k_first_partial_application,
		"synthetic_measurements_only": true, "selector_and_launcher_validation_exercised": false,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
	var file := FileAccess.open(_output, FileAccess.WRITE)
	file.store_string(Transport.stringify(result) + "\n")
	file.close()
	Route.free_zero_world_command_surface_v1(_surface)
	probe._sdk = null
	probe.free()
	print("R10AP_WORKER_HOOKS ", JSON.stringify({"ok": result.ok, "checks": checks.size(), "failure_keys": failure.keys(), "failed_checks": checks.keys().filter(func(key): return checks[key] != true)}))
	quit(0 if result.ok else 1)

func _project_r10aa(sdk: Object, context: Dictionary, fixture: Dictionary, application: Dictionary, step: int, partial: bool) -> Dictionary:
	var observer := Sources.Prior._observer_for_global_step_v1(step, Vector3(0.0, 0.125, 0.0))
	var staging: float = fixture["global_accumulator"]["cumulative_signed_discrete_staging_exchange_j"] + observer["signed_discrete_staging_exchange_j"]
	var sources := Sources._zero_actuation_sources_v1(sdk, context, observer, step, staging)
	var inputs := Inputs._partition_inputs_v1(true)
	inputs["semantic_step"] = step
	var input_receipt := Sources.World.solver_coupled_complete_energy_partition_inputs_contract_v1(inputs)
	sources["source_component_receipts"]["complete_energy_inputs_receipt"] = input_receipt
	sources["source_component_receipts"]["complete_energy_inputs_receipt_sha256"] = Sources.Runtime.canonicalize(sdk, input_receipt)["sha256"]
	var observation := Sources.Prior._observation_base_for_step_v1(sdk, context, step)
	# These measurements are constructed from explicit synthetic pose fields
	# before either source hashing or native validation. No observed record is edited.
	for key in ["base_pose_world", "base_twist_world", "ordered_contact_observations", "ordered_joint_observations"]:
		observation.state[key] = _pose.state[key].duplicate(true)
	for key in ["center_of_mass", "ordered_body_clearance_observations", "ordered_foot_bearing_observations"]:
		observation[key] = _pose[key].duplicate(true)
	observation.center_of_mass.position_world_m.y = 0.25 if partial else 0.125
	if not partial: observation.state.base_pose_world.position_m.y *= 0.5
	if partial:
		var selected := Bridge.Source.select_v1(sdk, {Bridge.Source.KEY: application.get(Bridge.Source.KEY)}, application, step)
		if selected.get("ok") != true: return selected
		observation.task_id = selected.task_id
		observation.semantics_id = selected.semantics_id
	observation["state"]["sample_time_s"] = step * Route.OUTER_STEP_DURATION_S
	_complete_synthetic_observation_v1(observation, step)
	var ownership := Sources.World.controller_ownership_observation_v1(sdk, application)
	if ownership.get("ok") != true:
		return {"ok": false, "failure_code": "SYNTHETIC_PROJECTION_NATIVE_OWNERSHIP_REFUSED", "detail": ownership}
	observation["controller_ownership"] = ownership["observation"]
	for key in ["command_id", "command_sha256", "zero_command"]:
		observation["applied_actuation"][key] = application[key]
	for impulse in observation["applied_actuation"]["ordered_applied_impulses"]:
		impulse["applied_angular_impulse_nms"] = 0.0
	# Synthetic execution remains separate from its command intent, just as in
	# the physical producer. Rebind this fixture's own sources before composing.
	var components: Dictionary = sources["source_component_receipts"]
	# The older energy-only fixture has no execution receipt. Supply an
	# explicitly synthetic execution for this test, never a physical claim.
	var native_application := {"schema_version": "sporespore_development_synthetic_native_execution_v1",
		"synthetic_test_fixture": true, "phase": application["phase"]}
	for key in ["command_id", "command_sha256", "zero_command", "semantic_step"]:
		native_application[key] = application[key]
	native_application["ordered_applied_impulses"] = observation["applied_actuation"]["ordered_applied_impulses"].duplicate(true)
	components["application_receipt"] = native_application
	components["application_receipt_sha256"] = Sources.Runtime.canonicalize(sdk, native_application)["sha256"]
	observation["applied_actuation"]["adapter_receipt_sha256"] = components["application_receipt_sha256"]
	var global_bound := Route.compose_discrete_staging_complete_energy_observations_v1(sdk, context, observation,
		sources["energy_source_receipt"], sources["source_component_receipts"], observer, fixture["global_accumulator"])
	if global_bound.get("ok") != true:
		return global_bound
	var global_result := Sources.Prior._committed_global_result_fixture_v1(sdk, sources, observation, step)
	global_result["bound"] = global_bound
	var projection := Sources.Epoch.project_committed_global_result_v1(sdk, global_result, step)
	var boundary := _completed_fixture_boundary_v1(sdk, step, "entry-synthetic-completed-%d" % step)
	var epoch := Sources.Epoch.advance_epoch_projection_v1(sdk, fixture["epoch_state"], fixture["energy_initializer"],
		fixture["epoch_accumulator"], boundary["boundary"], projection)
	if epoch.get("ok") != true:
		return epoch
	var after := fixture.duplicate(true)
	after["epoch_state"] = epoch["epoch_transport_state_after"]
	after["epoch_accumulator"] = epoch["epoch_staging_accumulator_after"]
	after["global_accumulator"] = global_bound["native_to_portable_staging_mapping"]["accumulator_after"]
	return {"ok": true, "epoch": epoch, "fixture_after": after, "global_result": global_result}

func _completed_fixture_trace_v1(_sdk: Object, _arm: Dictionary, _projected: Dictionary, step: int) -> Dictionary:
	return {"synthetic_step": step}
