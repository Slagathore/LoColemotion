extends SceneTree
const Cycle := preload("res://sdk/adapters/godot/gdscript/development_recovery_cycle_stop_v1.gd")
const Prior := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
func _initialize() -> void:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	var checks := {}
	var memory := Cycle.initial_v1()
	var previous := {}
	for row in rows:
		previous = memory.duplicate(true)
		var result := Cycle.advance_v1(memory, row["control"], row["source"])
		if result.get("ok") != true:
			checks["complete_retained_projection"] = false
			_finish(checks, result)
			return
		memory = result["next_memory"]
		if memory["last_command"] == 1008: checks["no_early_cycle_cutoff"] = memory["cycle_end_command"] == 0 and Cycle.stop_reason_v1(memory).is_empty()
		if memory["last_command"] == 1009: checks["four_cycle_cutoff"] = memory["cycle_end_command"] == 1009 and memory["completed"].size() == 4 and memory["stopping_commands"] == 0
		if memory["last_command"] == 1128: checks["no_early_stop"] = memory["stopping_commands"] == 119 and Cycle.stop_reason_v1(memory).is_empty()
	checks["full_120_stop_and_30_settled"] = memory["stopping_commands"] == 120 and memory["consecutive_settled_commands"] >= 30 and Cycle.stop_reason_v1(memory) == "diagnostic_cycle_aligned_stop_complete"
	checks["no_extra_command_after_stop"] = Cycle.advance_v1(memory, rows[-1]["control"], rows[-1]["source"]).get("ok") == false
	for defect in ["clock", "contact", "motion", "source"]:
		var changed: Dictionary = rows[-1].duplicate(true)
		if defect == "clock": changed["control"]["session_local_step"] -= 1
		elif defect == "contact": changed["source"]["observation"]["state"]["ordered_contact_observations"][0]["bears_support"] = null
		elif defect == "motion": changed["source"]["observation"]["center_of_mass"]["linear_velocity_world_m_s"]["x"] = NAN
		else: changed["source"]["observation"]["center_of_mass"]["source_measurement"] = false
		checks[defect + "_refuses"] = Cycle.advance_v1(previous, changed["control"], changed["source"]).get("ok") == false
	var changed: Dictionary = rows[-1].duplicate(true)
	changed["source"]["observation"]["center_of_mass"]["linear_velocity_world_m_s"]["x"] = 0.031
	var unsettled := Cycle.advance_v1(previous, changed["control"], changed["source"])
	checks["moving_stop_is_valid_negative"] = unsettled.get("ok") == true and unsettled["next_memory"]["consecutive_settled_commands"] == 0
	changed = rows[-1].duplicate(true)
	changed["source"]["observation"]["state"]["ordered_contact_observations"][2]["presence"] = false
	changed["source"]["observation"]["state"]["ordered_contact_observations"][2]["bears_support"] = false
	var unsupported := Cycle.advance_v1(previous, changed["control"], changed["source"])
	checks["unsupported_stop_is_valid_negative"] = unsupported.get("ok") == true and unsupported["next_memory"]["consecutive_settled_commands"] == 0
	var limited := Cycle.initial_v1()
	limited["last_command"] = 1600
	checks["walking_limit_is_not_completed_cycle"] = Cycle.stop_reason_v1(limited) == "diagnostic_cycle_aligned_walking_limit" and limited["completed"].is_empty()
	var state := {"walking_resume_step_count": 719, "epoch_start_global_step": 0, "prefix_walking_session_id": "prefix", "resume_or_continuation_session_id": "resume", "phase": Prior.PHASE_WALKING_RESUME}
	var event := {"event_kind": "walking_policy_step", "control_owner": "stance", "actuation_owner": "stance", "no_actuation_requested": false, "walking_actuation_applied": true, "recovery_actuation_applied": false, "walking_session_id": "resume", "walking_session_local_step": 720, "global_semantic_step": 720, "recovery_epoch_local_step": 720, "energy_initializer_sha256": ""}
	var legacy := state.duplicate(true)
	checks["legacy_kernel_still_completes_at_720"] = Prior._advance_walking_resume_v1(legacy, event, "stance").is_empty() and legacy["phase"] == Prior.PHASE_COMPLETE
	checks["selected_kernel_continues_past_720"] = Prior._advance_walking_resume_v1(state, event, "stance", Cycle.MAX_WALK + Cycle.STOP_STEPS).is_empty() and state["phase"] == Prior.PHASE_WALKING_RESUME
	state["walking_resume_step_count"] = 1719
	for key in ["walking_session_local_step", "global_semantic_step", "recovery_epoch_local_step"]: event[key] = 1720
	checks["selected_kernel_has_finite_1720_bound"] = Prior._advance_walking_resume_v1(state, event, "stance", Cycle.MAX_WALK + Cycle.STOP_STEPS).is_empty() and state["phase"] == Prior.PHASE_COMPLETE
	for key in ["walking_session_local_step", "global_semantic_step", "recovery_epoch_local_step"]: event[key] = 1721
	checks["selected_kernel_refuses_beyond_bound"] = not Prior._advance_walking_resume_v1(state, event, "stance", Cycle.MAX_WALK + Cycle.STOP_STEPS).is_empty()
	_finish(checks, memory)
func _finish(checks: Dictionary, result: Dictionary) -> void:
	print("V50_CYCLE_STOP_CHECKS ", Transport.stringify({"ok": not checks.values().has(false), "checks": checks, "result": result,
		"retained_projection_only": true, "world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	quit(0 if not checks.values().has(false) else 1)
