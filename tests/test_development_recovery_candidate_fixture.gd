extends "res://tests/test_development_passive_entry_worker_hooks.gd"
# gdlint: disable=max-line-length

const Owner := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd")
const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Exporter := preload("res://tests/test_development_passive_entry_replay_fixture.gd")

class CandidateProbe:
	extends "res://sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd"
	func _initialize() -> void:
		pass # Only suppress automatic launch. All called worker methods are real.

func _make_probe_v1() -> SceneTree:
	var args := OS.get_cmdline_user_args()
	var probe := CandidateProbe.new()
	probe._candidate_selection = Profile.load_v1({"resource": args[0], "raw_sha256": args[1]})
	probe._candidate_mode = Profile.contract_v1()["paired_mode"]
	return probe

func _fixture_configuration_v1(probe: SceneTree) -> Dictionary:
	var configuration := super._fixture_configuration_v1(probe)
	if Profile.WalkingPolicy.floor_selected_v1(probe._walking_policy_id_v1("walking_resume")):
		# The real facade configuration contains this descriptor. Supply the same
		# source before the fixture's configuration digest/initial state is made;
		# do not rewrite an exported report or relax the independent floor reader.
		configuration["base_descriptor"] = Route.exact_base_descriptor_v1()
	return configuration

func _finish(probe: SceneTree, failure: Dictionary) -> void:
	var exported := Exporter.export_v1(probe, checks, failure)
	if exported.get("ok") == true:
		for key in ["full_report_input", "baseline_report_input"]:
			exported[key]["report"]["candidate_profile"] = probe._candidate_selection["candidate_profile"]
			var additional := {}
			probe._attach_entry_retention_v1(additional)
			if additional.has("development_walking_entry"):
				exported[key]["report"]["development_walking_entry"] = additional["development_walking_entry"]
			if additional.has("development_walking_contacts"):
				exported[key]["report"]["development_walking_contacts"] = additional["development_walking_contacts"]
			if additional.has("development_native_walking_contacts"):
				exported[key]["report"]["development_native_walking_contacts"] = additional["development_native_walking_contacts"]
			if additional.has("stance_entry"):
				exported[key]["report"]["stance_entry"] = additional["stance_entry"]
			if additional.has("development_cycle_stop"):
				exported[key]["report"]["development_cycle_stop"] = additional["development_cycle_stop"]
			if additional.has("finite_recovery_task"):
				exported[key]["report"]["finite_recovery_task"] = Profile.WalkingPolicy.FiniteRoute.task_boundary_v1(exported[key]["report"], probe._cycle_stop_memory, probe._walking_policy_id_v1("walking_resume"))
	print("DEVELOPMENT_RECOVERY_CANDIDATE_FIXTURE ", Transport.stringify(exported))
	probe._sdk = null
	probe.free()
	quit(0 if exported["ok"] else 1)

func _additional_worker_checks_v1(probe: SceneTree, fixture: Dictionary) -> Dictionary:
	var id: String = probe._entry_controller_id_v1()
	checks["setup_controller_remains_v6"] = probe._recovery_controller_for_phase_v1(Prior.PHASE_PRECONDITION_RECOVERY) == Route.RECOVERY_CONTROLLER_V6_ID
	checks["postkick_worker_selects_candidate"] = probe._recovery_controller_for_phase_v1(Prior.PHASE_CONFIRM_PRONE) == id and probe._recovery_controller_for_phase_v1(Prior.PHASE_POST_KICK_RECOVERY) == id
	var first: Dictionary = probe._first_recovery_application
	checks["new_owner_and_canonical_owner_both_retained"] = first["controller_owner"] == Owner.profile_v1(id)["owner"] and first["canonical_controller_owner"] == "recovery" and first["recovery_controller_id"] == id
	checks["old_mapping_reader_refuses_new_record"] = Owner.validate_v1(probe._sdk, first).get("ok") == false
	checks["explicit_candidate_mapping_reader_accepts_exact_source"] = Owner.validate_v1(probe._sdk, first, null, id).get("ok") == true
	var state: Dictionary = probe._arms[ARM]["orchestrator_state"]
	checks["old_scheduler_refuses_new_state"] = not Entry.state_valid_v1(probe._sdk, state)
	checks["new_scheduler_accepts_exact_new_state"] = Entry.state_valid_v1(probe._sdk, state, id, probe._walking_policy_id_v1("walking_resume"))
	var event_fields := {"event_kind": "passive_prone_observation", "global_semantic_step": ENTRY_STEP + 5,
		"recovery_epoch_local_step": 5, "control_owner": "recovery_v6", "actuation_owner": "none",
		"no_actuation_requested": true, "application_intent_sha256": SHA,
		"energy_initializer_sha256": state["energy_initializer_sha256"]}
	checks["crossed_v6_owner_refused_by_candidate_scheduler"] = probe._build_orchestrator_event_v1(state, event_fields).get("ok") == false
	for offset in range(5, 14):
		var planned: Dictionary = probe._plan_next_process_isolated_frame_v1(ENTRY_STEP + offset - 1)
		if planned.get("ok") != true:
			return {"continued_candidate_plan": planned, "offset": offset}
		var application: Dictionary = probe._arms[ARM]["pending_application"]
		var projected := _project(probe._sdk, probe._context, fixture, application, ENTRY_STEP + offset, true)
		if projected.get("ok") != true:
			return {"candidate_source_projection": projected, "offset": offset}
		probe._arms[ARM]["last_collection"] = {"epoch_result": projected["epoch"], "epoch_local_step": offset, "global_result": projected["global_result"]}
		probe._arms[ARM]["trace_rows"].append({"synthetic_row": true})
		var processed: Dictionary = probe._process_completed_arm_step_v1(ARM, ENTRY_STEP + offset, false)
		if processed.get("ok") != true:
			return {"candidate_worker_processing": processed, "offset": offset}
		fixture = projected["fixture_after"]
	var arm: Dictionary = probe._arms[ARM]
	checks["actual_worker_reaches_support_after_12_prone_samples"] = arm["recovery_memory"]["phase"] == "establish_distal_support" and arm["orchestrator_state"]["phase"] == Prior.PHASE_POST_KICK_RECOVERY and arm["orchestrator_state"]["confirm_prone_step_count"] == 12
	var control: Dictionary = arm["next_recovery_control"]
	checks["selected_controller_emits_eight_finite_commands"] = control["controller_id"] == id and control["ordered_commands"].size() == 8 and control["ordered_commands"].all(func(command: Dictionary): return is_finite(command["target_position_rad"]) and command["maximum_target_speed_rad_s"] > 0.0)
	var surface := Route.zero_world_command_surface_v1(probe._context)
	if surface.get("ok") != true:
		return {"uninserted_surface": surface}
	# Supply the same native application surface as the production component
	# test; the worker itself chooses positions, controller, application and time.
	arm["model"].merge({"complete_energy_profile_selected": true,
		"solver_coupled_complete_energy_profile_selected": true,
		"discrete_staging_complete_energy_profile_selected": true,
		"route_aware_application_provenance_selected": true,
		"joint_by_actuator_id": surface["joint_by_actuator_id"]}, true)
	probe._arms[ARM] = arm
	var applied: Dictionary = probe._plan_next_process_isolated_frame_v1(ENTRY_STEP + 13)
	checks["actual_worker_applies_first_candidate_support_command"] = applied.get("ok") == true
	if applied.get("ok") == true:
		var application: Dictionary = probe._arms[ARM]["pending_application"]
		checks["native_application_records_candidate_and_global_step"] = application.get("portable_recovery_controller_id") == id and application.get("semantic_step") == ENTRY_STEP + 14
		checks["default_application_validator_refuses_candidate"] = not Worker.BehaviorWorker.behavior_application_receipt_valid_v4(Worker.ACTUATOR_MODE, application, false, Worker.ENERGY_ROUTE_ID, true)
		checks["all_eight_actual_motors_enabled_by_worker"] = surface["joint_by_actuator_id"].values().all(func(joint): return joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR))
	Route.free_zero_world_command_surface_v1(surface)
	if applied.get("ok") != true:
		return {"first_native_application": applied}
	# Complete the next worker step with explicitly supplied observations, so
	# the independent reader can consume an active application in its timeline.
	var active_projection := _project(probe._sdk, probe._context, fixture,
		probe._arms[ARM]["pending_application"], ENTRY_STEP + 14, true)
	if active_projection.get("ok") != true:
		return {"active_candidate_projection": active_projection}
	probe._arms[ARM]["last_collection"] = {"epoch_result": active_projection["epoch"],
		"epoch_local_step": 14, "global_result": active_projection["global_result"]}
	probe._arms[ARM]["trace_rows"].append({"synthetic_row": true})
	var active_processed: Dictionary = probe._process_completed_arm_step_v1(ARM, ENTRY_STEP + 14, false)
	if active_processed.get("ok") != true:
		return {"active_candidate_processing": active_processed}
	checks["actual_worker_retains_completed_active_support_step"] = probe._canonical_packets[-1]["application"]["no_actuation_requested"] == false and probe._arms[ARM]["orchestrator_state"]["previous_global_semantic_step"] == ENTRY_STEP + 14
	var report := {}
	probe._attach_entry_retention_v1(report)
	checks["publication_keeps_both_controllers_and_exact_consumption_context"] = report["passive_entry"]["setup_controller_id"] == Route.RECOVERY_CONTROLLER_V6_ID and report["passive_entry"]["post_kick_controller_id"] == id and Route.development_candidate_context_binding_exact_v1(probe._sdk, report["passive_entry"]["post_kick_controller_context"], id)
	return {}
