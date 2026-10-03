extends SceneTree
# gdlint: disable=max-line-length

## Actual worker methods, source composers and compiled entry calls. Only motor
## readback and supplied solver observations are synthetic; no model is built.
const Worker := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd")
const Entry := Worker.EntryOrchestrator
const Prior := Entry.Prior
const Sources := preload("res://tests/test_sdk_qsdk_r10f_l15_worker_ownership_zero_world.gd")
const Inputs := preload("res://tests/test_sdk_qsdk_r24d144_godot_solver_coupled_complete_energy_partition_zero_world.gd")
const Route := Sources.Route
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const SHA := "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const ARM := "kick_passive_recovery_resume"
const ENTRY_STEP := 272 # Synthetic setup 240 + release 1 + prefix 30 + interaction 1.
var checks := {}

class Probe:
	extends "res://sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd"
	func _initialize() -> void:
		# Suppress only automatic physical launch. Tests call real worker hooks.
		pass

func _initialize() -> void:
	call_deferred("_run")

func _make_probe_v1() -> SceneTree:
	return Probe.new()

func _additional_worker_checks_v1(_probe: SceneTree, _fixture: Dictionary) -> Dictionary:
	return {}

func _fixture_configuration_v1(_probe: SceneTree) -> Dictionary:
	return {"synthetic_worker_hook_configuration": true}

func _fixture_attempt_id_v1() -> String:
	return Sources.Prior.ATTEMPT_ID

func _completed_fixture_boundary_v1(sdk: Object, step: int, event_id: String) -> Dictionary:
	return Sources.Prior.QualifiedTransport.build_completed_step_boundary_v1(sdk,
		_fixture_attempt_id_v1(), ARM, Sources.Prior.MODEL_INSTANCE_ID, step, event_id,
		Sources.Prior._fixture_samples_v1(step))

func _complete_synthetic_observation_v1(_observation: Dictionary, _step: int) -> void:
	pass

func _run() -> void:
	var probe := _make_probe_v1()
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(probe._entry_selection_v1()["binding"]))
	if not probe._load_runtime_extension_v1():
		_finish(probe, {"runtime_load": false})
		return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	probe._sdk = sdk
	probe._context = Route.prepare_complete_energy_context_v18(sdk, Route.RECOVERY_CONTROLLER_V6_ID)
	probe._attempt_id = Sources.Prior.ATTEMPT_ID
	probe._repair_id = "QSDK-R10F-L15"
	probe._authorized_arm_id = ARM
	probe._configuration = _fixture_configuration_v1(probe)
	probe._configuration_sha256 = probe._canonical_sha256_v1(probe._configuration)
	var fixture := _initial_entry_fixture(sdk, probe._context)
	if fixture.get("ok") != true:
		_finish(probe, {"source_fixture": fixture})
		return
	var motor := Sources.SyntheticMotorReadback.new()
	var initial: Dictionary = probe._initialize_orchestrator_v1(ARM, Sources.Prior.MODEL_INSTANCE_ID, SHA)
	# Explicitly synthetic pre-interaction scheduler state, not an observed run.
	var state: Dictionary = initial["state"]
	state["phase"] = Prior.PHASE_INTERACTION
	state["previous_global_semantic_step"] = ENTRY_STEP - 1
	state["total_completed_solver_step_count"] = ENTRY_STEP - 1
	state["state_revision"] = ENTRY_STEP - 1
	state["precondition_recovery_step_count"] = ENTRY_STEP - 32
	state["precondition_pair_ready"] = true
	state["precondition_pair_release_step_count"] = 1
	state["walking_prefix_step_count"] = 30
	state["prefix_walking_session_id"] = "synthetic_prefix"
	state["payload_sha256"] = Prior._payload_sha256_v1(sdk, state)
	var model := {Worker.NativeEpochRoute.MODEL_EPOCH_INITIALIZER_KEY: fixture["energy_initializer"]}
	probe._arms[ARM] = {"facade": motor, "model": model, "orchestrator_state": state,
		"recovery_memory": {"synthetic_completed_setup_memory": true},
		"next_recovery_control": {"synthetic_completed_setup_control": true},
		"recovery_step_receipts": [], "recovery_development_progression_receipts": [],
		"trace_rows": [], "terminal": false, "body_population_rebuild_count": 0,
		"body_transform_write_count": 0, "body_velocity_write_count": 0, "solver_reset_count": 0}
	var kick: Dictionary = probe._build_orchestrator_event_v1(state, {"event_kind": "kick_effect_step",
		"global_semantic_step": ENTRY_STEP, "application_intent_sha256": SHA,
		"no_actuation_requested": true, "interaction_receipt_sha256": fixture["energy_initializer"]["kick_interaction_receipt_sha256"],
		"energy_initializer_sha256": fixture["energy_initializer"]["payload_sha256"],
		"kick_application_count": 1, "walking_motors_disabled_in_same_pre_solver_event": true})
	if kick.get("ok") != true:
		_finish(probe, {"kick_event": kick})
		return
	var installed: Dictionary = probe._install_orchestrator_event_v1(ARM, state, {}, {}, {}, kick)
	checks["actual_interaction_hook_installs_descent"] = installed.get("ok") == true and probe._arms[ARM]["orchestrator_state"]["phase"] == Entry.PHASE_DESCENT
	checks["no_active_getup_memory_or_control_during_descent"] = probe._arms[ARM]["recovery_memory"].is_empty() and probe._arms[ARM]["next_recovery_control"].is_empty()
	checks["wrong_descent_clock_refuses_before_read"] = probe._plan_descent_application_v1(ENTRY_STEP + 1).get("ok") == false and motor.calls.is_empty()
	motor.forced_failure = true
	checks["motor_read_failure_kept_before_application"] = probe._plan_next_process_isolated_frame_v1(ENTRY_STEP).get("failure_code") == "SYNTHETIC_MOTOR_READ_REFUSAL" and not probe._arms[ARM].has("pending_application")
	motor.forced_failure = false
	motor.calls.clear()
	var planned: Dictionary = probe._plan_next_process_isolated_frame_v1(ENTRY_STEP)
	if planned.get("ok") != true:
		_finish(probe, {"descent_application": planned})
		return
	var application: Dictionary = probe._arms[ARM]["pending_application"]
	checks["actual_descent_application_has_no_controller_not_matched_zero"] = application["controller_owner"] == "none" and application["zero_command"] == false and application["recovery_controller_id"] == null
	checks["one_synthetic_motor_read_at_next_global_step"] = motor.calls.size() == 1 and motor.calls[0]["step"] == ENTRY_STEP + 1 and motor.calls[0]["enabled"] == false
	var incomplete := Sources._advance_epoch_fixture_v1(sdk, probe._context, fixture, application, ENTRY_STEP + 1)
	var missing_inputs := Worker.EntryStage.advance_v1(sdk, probe._context, probe._attempt_id,
		Worker.MAX_DESCENT_STEPS, incomplete["epoch"]["bound_epoch_observations"])
	checks["missing_native_input_receipt_refuses_without_script_error"] = missing_inputs.get("failure_code") == "PASSIVE_ENTRY_NATIVE_ENERGY_INPUTS_MISSING" and missing_inputs["entry_call"] == null
	var projected := _project(sdk, probe._context, fixture, application, ENTRY_STEP + 1, false)
	if projected.get("ok") != true:
		_finish(probe, {"source_projection": projected})
		return
	probe._arms[ARM]["last_collection"] = {"epoch_result": projected["epoch"]}
	probe._arms[ARM]["trace_rows"].append({"synthetic_row": true})
	var processed: Dictionary = probe._process_completed_arm_step_v1(ARM, ENTRY_STEP + 1, false)
	if processed.get("ok") != true:
		_finish(probe, {"descent_processing": processed, "retained_packet": probe._entry_packets})
		return
	checks["actual_descent_processing_succeeds"] = true
	checks["compiled_entry_packet_retained"] = probe._entry_packets.size() == 1 and probe._entry_packets[0]["entry_call"]["compiled_call_count"] == 1
	checks["nonprone_sample_does_not_initialize"] = probe._arms[ARM]["recovery_memory"].is_empty() and probe._arms[ARM]["orchestrator_state"]["confirm_prone_step_count"] == 0
	fixture = projected["fixture_after"]
	planned = probe._plan_next_process_isolated_frame_v1(ENTRY_STEP + 1)
	if planned.get("ok") != true:
		_finish(probe, {"second_descent_application": planned})
		return
	application = probe._arms[ARM]["pending_application"]
	projected = _project(sdk, probe._context, fixture, application, ENTRY_STEP + 2, true)
	if projected.get("ok") != true:
		_finish(probe, {"prone_source_projection": projected})
		return
	probe._arms[ARM]["last_collection"] = {"epoch_result": projected["epoch"], "global_result": projected["global_result"]}
	probe._arms[ARM]["trace_rows"].append({"synthetic_row": true})
	processed = probe._process_completed_arm_step_v1(ARM, ENTRY_STEP + 2, false)
	if processed.get("ok") != true:
		_finish(probe, {"prone_processing": processed, "retained_packet": probe._entry_packets})
		return
	var handoff: Dictionary = probe._arms[ARM]["passive_entry_handoff_receipt"]
	checks["actual_prone_handoff_initializes_once"] = not handoff.is_empty() and handoff.get("canonical_initialization_count") == 1
	if handoff.is_empty():
		_finish(probe, {"expected_prone_handoff": probe._entry_packets[-1]["entry_receipt"]})
		return
	checks["source_attempt_projection_lossless"] = probe._entry_packets[-1]["source_attempt_id"] == probe._attempt_id and probe._entry_packets[-1]["entry_state"]["declaration"]["attempt_id"].trim_prefix("passive_entry_").hex_decode().get_string_from_utf8() == probe._attempt_id
	checks["handoff_keeps_kick_epoch_and_starts_one_prone_sample"] = probe._arms[ARM]["orchestrator_state"]["epoch_start_global_step"] == ENTRY_STEP and probe._arms[ARM]["orchestrator_state"]["canonical_start_global_step"] == ENTRY_STEP + 2 and probe._arms[ARM]["orchestrator_state"]["confirm_prone_step_count"] == 1
	var memory_before: Dictionary = probe._arms[ARM]["recovery_memory"].duplicate(true)
	planned = probe._plan_next_process_isolated_frame_v1(ENTRY_STEP + 2)
	checks["first_recovery_owned_application_uses_handoff_not_reinitialize"] = planned.get("ok") == true and probe._arms[ARM]["recovery_memory"] == memory_before and probe._arms[ARM]["pending_application"]["owner_source_receipt"] == handoff and probe._arms[ARM]["pending_application"]["canonical_controller_owner"] == "recovery"
	checks["first_application_retained_with_no_fake_control"] = probe._first_recovery_application == probe._arms[ARM]["pending_application"] and probe._arms[ARM]["next_recovery_control"].is_empty() and not probe._arms[ARM].has("postkick_recovery_initialization_receipt")
	checks["repeated_planning_without_new_observation_refuses"] = probe._plan_next_process_isolated_frame_v1(ENTRY_STEP + 2).get("ok") == false
	fixture = projected["fixture_after"]
	for offset in [3, 4]:
		if offset == 4:
			planned = probe._plan_next_process_isolated_frame_v1(ENTRY_STEP + offset - 1)
			if planned.get("ok") != true:
				_finish(probe, {"continued_application": planned})
				return
		application = probe._arms[ARM]["pending_application"]
		projected = _project(sdk, probe._context, fixture, application, ENTRY_STEP + offset, true)
		if projected.get("ok") != true:
			_finish(probe, {"canonical_projection": projected})
			return
		probe._arms[ARM]["last_collection"] = {"epoch_result": projected["epoch"], "epoch_local_step": offset, "global_result": projected["global_result"]}
		probe._arms[ARM]["trace_rows"].append({"synthetic_row": true})
		processed = probe._process_completed_arm_step_v1(ARM, ENTRY_STEP + offset, false)
		if processed.get("ok") != true:
			_finish(probe, {"canonical_processing": processed})
			return
		fixture = projected["fixture_after"]
	checks["next_two_actual_canonical_steps_continue_same_clock"] = probe._arms[ARM]["orchestrator_state"]["confirm_prone_step_count"] == 3 and probe._canonical_packets.size() == 2 and probe._arms[ARM]["orchestrator_state"]["canonical_start_global_step"] == ENTRY_STEP + 2
	var report := {}
	probe._attach_entry_retention_v1(report)
	checks["publication_projection_retains_entry_and_canonical_prefix"] = report["schema_version"] == probe._entry_selection_v1()["report_schema"] and report["passive_entry"]["entry_packets"].size() == 2 and report["passive_entry"]["canonical_packets"].size() == 2 and report["passive_entry"]["orchestrator_transitions"].size() == 5
	_declaration_controls(probe)
	_finish(probe, _additional_worker_checks_v1(probe, fixture))

func _declaration_controls(probe: SceneTree) -> void:
	probe._source_commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	probe._parent_attempt_id = "synthetic_parent"
	probe._termination_nonce = "synthetic_nonce"
	var declaration := {"schema_version": probe._entry_selection_v1()["declaration_schema"],
		"context_cache_profile_id": Worker.CACHE_PROFILE_ID, "context_cache_call_sites": Worker.CACHE_CALL_SITES,
		"worker_resource": probe._entry_selection_v1()["worker"], "step_cost_profile_id": Worker.PROFILE_ID,
		"attempt_id": probe._parent_attempt_id, "source_snapshot": {"head": probe._source_commit},
		"official_qualification": false, "physical_acceptance_authority": false, "release_authority": false,
		"children": [{"child_attempt_id": probe._attempt_id, "role": ARM, "termination_nonce": probe._termination_nonce}],
		"diagnostic_schedule_id": probe._entry_selection_v1()["schedule"],
		"maximum_passive_descent_steps": 240, "maximum_precondition_steps": 320,
		"walking_prefix_steps": 30, "interaction_steps": 1, "after_interaction_steps": 480,
		"maximum_steps_per_child": 832, "passive_entry_runtime": probe._entry_runtime["runtime"]}
	var candidate: Variant = probe.get("_candidate_selection")
	if candidate is Dictionary:
		var limits: Dictionary = candidate.get("diagnostic_schedule", {}).get("limits", {})
		declaration.merge(limits, true)
		declaration["candidate_profile"] = candidate["candidate_profile"].duplicate(true)
		declaration["development_execution_mode"] = candidate["single_mode"]
		declaration["comparative_authority"] = false
		declaration["baseline_reused"] = false
	var raw := Transport.stringify(declaration)
	probe._authorization_sha256 = "sha256:" + raw.sha256_text()
	checks["actual_declaration_hook_accepts_only_new_profile"] = probe._development_declaration_valid_v1(raw)
	for key in ["schema_version", "worker_resource", "maximum_passive_descent_steps", "after_interaction_steps", "maximum_steps_per_child", "passive_entry_runtime", "physical_acceptance_authority"]:
		var changed := declaration.duplicate(true)
		changed[key] = "wrong_profile"
		raw = Transport.stringify(changed)
		probe._authorization_sha256 = "sha256:" + raw.sha256_text()
		checks["declaration_refuses_changed_" + key] = not probe._development_declaration_valid_v1(raw)
	raw = Transport.stringify(declaration)
	probe._authorization_sha256 = SHA
	checks["declaration_refuses_wrong_raw_hash"] = not probe._development_declaration_valid_v1(raw)

func _project(sdk: Object, context: Dictionary, fixture: Dictionary, application: Dictionary, step: int, prone: bool) -> Dictionary:
	var observer := Sources.Prior._observer_for_global_step_v1(step, Vector3(0.0, 0.125, 0.0))
	var staging: float = fixture["global_accumulator"]["cumulative_signed_discrete_staging_exchange_j"] + observer["signed_discrete_staging_exchange_j"]
	var sources := Sources._zero_actuation_sources_v1(sdk, context, observer, step, staging)
	var inputs := Inputs._partition_inputs_v1(true)
	inputs["semantic_step"] = step
	var input_receipt := Sources.World.solver_coupled_complete_energy_partition_inputs_contract_v1(inputs)
	sources["source_component_receipts"]["complete_energy_inputs_receipt"] = input_receipt
	sources["source_component_receipts"]["complete_energy_inputs_receipt_sha256"] = Sources.Runtime.canonicalize(sdk, input_receipt)["sha256"]
	var observation := Sources.Prior._observation_base_for_step_v1(sdk, context, step)
	if not prone:
		observation["state"]["base_pose_world"]["position_m"]["y"] = 0.3
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

func _finish(probe: SceneTree, failure: Dictionary) -> void:
	var ok := failure.is_empty()
	for value in checks.values():
		ok = ok and value == true
	probe._sdk = null
	probe.free()
	print("DEVELOPMENT_PASSIVE_ENTRY_WORKER_HOOKS ", Transport.stringify({"ok": ok, "checks": checks,
		"failure": failure, "synthetic_native_observations_only": true,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	quit(0 if ok else 1)

func _initial_entry_fixture(sdk: Object, context: Dictionary) -> Dictionary:
	# Use the real source builders with this test's own valid smoke timeline.
	# Historical L15 fixtures and retained observations keep their original clock.
	var pair := Sources.Prior.ImpulsePairReceipt.build_pair_receipt_v1(
		sdk, Sources.Prior._impulse_pair_source_fixture_v1())
	if pair.get("ok") != true:
		return pair
	var interaction := Sources.Prior.EnergyInitializer.build_interaction_receipt_v1(
		sdk, _fixture_attempt_id_v1(), ARM, Sources.Prior.MODEL_INSTANCE_ID,
		ENTRY_STEP, ENTRY_STEP, pair["active_native_effect_velocity_delta_m_s"], pair["pair_receipt_sha256"])
	var boundary := _completed_fixture_boundary_v1(sdk, ENTRY_STEP, "passive-entry-synthetic-boundary")
	var observer := Sources.Prior._observer_for_global_step_v1(ENTRY_STEP, Vector3(0.0, 0.125, 0.0))
	var sources := Sources._zero_actuation_sources_v1(sdk, context, observer, ENTRY_STEP, 0.125)
	if interaction.get("ok") != true or boundary.get("ok") != true or sources.get("ok") != true:
		return {"ok": false, "interaction": interaction, "boundary": boundary, "sources": sources}
	var global_accumulator := Sources.Prior._global_staging_accumulator_v1(ENTRY_STEP)
	var initialized := Sources.Epoch.initialize_epoch_projection_v1(sdk, boundary["boundary"],
		sources["energy_source_receipt"], sources["source_component_receipts"], global_accumulator,
		interaction["interaction_receipt"])
	if initialized.get("ok") != true:
		return initialized
	return {"ok": true, "epoch_state": initialized["epoch_transport_state"],
		"energy_initializer": initialized["energy_initializer"],
		"epoch_accumulator": initialized["epoch_staging_accumulator"], "global_accumulator": global_accumulator}
