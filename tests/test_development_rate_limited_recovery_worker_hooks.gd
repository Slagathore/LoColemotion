extends "res://tests/test_development_passive_entry_worker_hooks.gd"
# gdlint: disable=max-line-length

## Inherit the actual descent/handoff/advance/retention checks, selecting the
## real new worker. Native observations stay explicitly synthetic. Hinges are
## never inserted into a world; only the actual motor application is exercised.
const Owner := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd")

class RateLimitedProbe:
	extends "res://sdk/adapters/godot/gdscript/development_rate_limited_recovery_smoke_worker_v1.gd"
	func _initialize() -> void:
		pass # Prevent automatic physical launch; do not replace worker methods.

class V6CompatibilityProbe:
	extends "res://sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd"
	func _initialize() -> void:
		pass
	func _entry_selection_v1() -> Dictionary:
		# Test the unchanged V6 behavior with the new compiled superset, not a
		# claim that the old binary's invalidated live-source key still matches.
		var selected := super._entry_selection_v1()
		selected["extension"] = "res://sdk/adapters/godot/development_rate_limited_recovery_runtime/runtime.gdextension"
		selected["binding"] = "res://sdk/development_rate_limited_recovery_runtime_binding_v1.json"
		return selected


class V7CompatibilityProbe:
	extends "res://sdk/adapters/godot/gdscript/development_rearward_fold_smoke_worker_v1.gd"
	func _initialize() -> void:
		pass
	func _entry_selection_v1() -> Dictionary:
		var selected := super._entry_selection_v1()
		selected["extension"] = "res://sdk/adapters/godot/development_rate_limited_recovery_runtime/runtime.gdextension"
		selected["binding"] = "res://sdk/development_rate_limited_recovery_runtime_binding_v1.json"
		return selected


func _make_probe_v1() -> SceneTree:
	if OS.get_cmdline_user_args() == PackedStringArray(["v7_compatibility"]):
		return V7CompatibilityProbe.new()
	if OS.get_cmdline_user_args() == PackedStringArray(["v6_compatibility"]):
		return V6CompatibilityProbe.new()
	return RateLimitedProbe.new()


func _additional_worker_checks_v1(probe: SceneTree, fixture: Dictionary) -> Dictionary:
	if probe._entry_controller_id_v1() == Route.RECOVERY_CONTROLLER_V7_ID:
		checks["v7_worker_keeps_original_controller_and_record_schema"] = probe._first_recovery_application["controller_owner"] == "recovery_v7" and probe._first_recovery_application["schema_version"] == Owner.profile_v1(Route.RECOVERY_CONTROLLER_V7_ID)["application_schema"] and Entry.state_valid_v1(probe._sdk, probe._arms[ARM]["orchestrator_state"], Route.RECOVERY_CONTROLLER_V7_ID)
		return {}
	if probe._entry_controller_id_v1() == Route.RECOVERY_CONTROLLER_V6_ID:
		checks["v6_worker_keeps_original_controller_and_record_schema"] = probe._first_recovery_application["controller_owner"] == "recovery_v6" and probe._first_recovery_application["schema_version"] == Owner.APPLICATION_SCHEMA and Entry.state_valid_v1(probe._sdk, probe._arms[ARM]["orchestrator_state"])
		return {}
	var id: String = Route.RECOVERY_CONTROLLER_V8_ID
	checks["setup_controller_remains_v6"] = probe._recovery_controller_for_phase_v1(Prior.PHASE_PRECONDITION_RECOVERY) == Route.RECOVERY_CONTROLLER_V6_ID
	checks["postkick_worker_selects_v8"] = probe._recovery_controller_for_phase_v1(Prior.PHASE_CONFIRM_PRONE) == id and probe._recovery_controller_for_phase_v1(Prior.PHASE_POST_KICK_RECOVERY) == id
	var first: Dictionary = probe._first_recovery_application
	checks["new_owner_and_canonical_owner_both_retained"] = first["controller_owner"] == "recovery_v8" and first["canonical_controller_owner"] == "recovery" and first["recovery_controller_id"] == id
	checks["old_mapping_reader_refuses_new_record"] = Owner.validate_v1(probe._sdk, first).get("ok") == false
	checks["explicit_v8_mapping_reader_accepts_exact_source"] = Owner.validate_v1(probe._sdk, first, null, id).get("ok") == true
	var state: Dictionary = probe._arms[ARM]["orchestrator_state"]
	checks["old_scheduler_refuses_new_state"] = not Entry.state_valid_v1(probe._sdk, state)
	checks["new_scheduler_accepts_exact_new_state"] = Entry.state_valid_v1(probe._sdk, state, id)
	var event_fields := {"event_kind": "passive_prone_observation", "global_semantic_step": ENTRY_STEP + 5,
		"recovery_epoch_local_step": 5, "control_owner": "recovery_v6", "actuation_owner": "none",
		"no_actuation_requested": true, "application_intent_sha256": SHA,
		"energy_initializer_sha256": state["energy_initializer_sha256"]}
	checks["crossed_v6_owner_refused_by_v8_scheduler"] = probe._build_orchestrator_event_v1(state, event_fields).get("ok") == false
	for offset in range(5, 14):
		var planned: Dictionary = probe._plan_next_process_isolated_frame_v1(ENTRY_STEP + offset - 1)
		if planned.get("ok") != true:
			return {"continued_v8_plan": planned, "offset": offset}
		var application: Dictionary = probe._arms[ARM]["pending_application"]
		var projected := _project(probe._sdk, probe._context, fixture, application, ENTRY_STEP + offset, true)
		if projected.get("ok") != true:
			return {"v8_source_projection": projected, "offset": offset}
		probe._arms[ARM]["last_collection"] = {"epoch_result": projected["epoch"], "epoch_local_step": offset, "global_result": projected["global_result"]}
		probe._arms[ARM]["trace_rows"].append({"synthetic_row": true})
		var processed: Dictionary = probe._process_completed_arm_step_v1(ARM, ENTRY_STEP + offset, false)
		if processed.get("ok") != true:
			return {"v8_worker_processing": processed, "offset": offset}
		fixture = projected["fixture_after"]
	var arm: Dictionary = probe._arms[ARM]
	checks["actual_worker_reaches_support_after_12_prone_samples"] = arm["recovery_memory"]["phase"] == "establish_distal_support" and arm["orchestrator_state"]["phase"] == Prior.PHASE_POST_KICK_RECOVERY and arm["orchestrator_state"]["confirm_prone_step_count"] == 12
	var control: Dictionary = arm["next_recovery_control"]
	checks["actual_worker_emits_four_rad_s_ceiling"] = control["ordered_commands"].all(func(command: Dictionary): return command["maximum_target_speed_rad_s"] == 4.0)
	checks["actual_worker_emits_front_mirrored_targets"] = control["controller_id"] == id and control["ordered_commands"].map(func(command: Dictionary): return command["target_position_rad"]) == [-0.6, 1.05, -0.6, 1.05, -0.6, 1.05, -0.6, 1.05]
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
	checks["actual_worker_applies_first_v8_support_command"] = applied.get("ok") == true
	if applied.get("ok") == true:
		var application: Dictionary = probe._arms[ARM]["pending_application"]
		checks["native_application_records_v8_and_global_step"] = application.get("portable_recovery_controller_id") == id and application.get("semantic_step") == ENTRY_STEP + 14
		checks["default_application_validator_refuses_v8"] = not Worker.BehaviorWorker.behavior_application_receipt_valid_v4(Worker.ACTUATOR_MODE, application, false, Worker.ENERGY_ROUTE_ID, true)
		checks["all_eight_actual_motors_enabled_by_worker"] = surface["joint_by_actuator_id"].values().all(func(joint): return joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR))
	Route.free_zero_world_command_surface_v1(surface)
	if applied.get("ok") != true:
		return {"first_native_application": applied}
	# Complete the next worker step with explicitly supplied observations, so
	# the independent reader can consume an active application in its timeline.
	var active_projection := _project(probe._sdk, probe._context, fixture,
		probe._arms[ARM]["pending_application"], ENTRY_STEP + 14, true)
	if active_projection.get("ok") != true:
		return {"active_v8_projection": active_projection}
	probe._arms[ARM]["last_collection"] = {"epoch_result": active_projection["epoch"],
		"epoch_local_step": 14, "global_result": active_projection["global_result"]}
	probe._arms[ARM]["trace_rows"].append({"synthetic_row": true})
	var active_processed: Dictionary = probe._process_completed_arm_step_v1(ARM, ENTRY_STEP + 14, false)
	if active_processed.get("ok") != true:
		return {"active_v8_processing": active_processed}
	checks["actual_worker_retains_completed_active_support_step"] = probe._canonical_packets[-1]["application"]["no_actuation_requested"] == false and probe._arms[ARM]["orchestrator_state"]["previous_global_semantic_step"] == ENTRY_STEP + 14
	var report := {}
	probe._attach_entry_retention_v1(report)
	checks["publication_keeps_both_controllers_and_exact_consumption_context"] = report["passive_entry"]["setup_controller_id"] == Route.RECOVERY_CONTROLLER_V6_ID and report["passive_entry"]["post_kick_controller_id"] == id and Route.rate_limited_recovery_context_binding_exact_v1(probe._sdk, report["passive_entry"]["post_kick_controller_context"])
	return {}
