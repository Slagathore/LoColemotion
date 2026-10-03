extends "res://sdk/adapters/godot/gdscript/development_cached_recovery_smoke_worker_v1.gd"

var captured_stop := ""


class RetainedCompletionFacade:
	extends RefCounted
	var receipt: Dictionary
	var calls := 0

	func finish_walking_session_v1() -> Dictionary:
		calls += 1
		return receipt.duplicate(true)


func _finish_smoke_v1(reason: String) -> void:
	# Intercept only the physical finalizer. The real bounded-stop hook is tested
	# without constructing a body; production publication has its own full gate.
	captured_stop = reason


func _initialize() -> void:
	var checks := {}
	var declaration := {
		"maximum_precondition_steps": 320,
		"walking_prefix_steps": 30,
		"interaction_steps": 1,
		"after_interaction_steps": 30,
		"maximum_steps_per_child": 382,
	}
	checks["default_unchanged"] = (
		_configure_smoke_schedule_v1(declaration) and _smoke_after_interaction_steps_v1() == 30
	)
	declaration["diagnostic_schedule_id"] = PRONE_DEADLINE_SCHEDULE
	declaration["after_interaction_steps"] = 60
	declaration["maximum_steps_per_child"] = 412
	checks["declared_deadline_selected"] = (
		_configure_smoke_schedule_v1(declaration) and _smoke_after_interaction_steps_v1() == 60
	)
	checks["original_controller_deadline"] = Orchestrator.MAXIMUM_CONFIRM_PRONE_STEPS == 60
	checks["original_confirmation_dwell"] = Orchestrator.REQUIRED_CONSECUTIVE_PRONE_SAMPLES == 12
	checks["official_prefix_unchanged"] = Orchestrator.WALKING_PREFIX_STEPS == 720
	for key in declaration:
		for value in [null, false, "wrong", 61]:
			var bad := declaration.duplicate(true)
			bad[key] = value
			checks[key + "_" + str(value)] = not _configure_smoke_schedule_v1(bad)
	checks["refusal_preserves_selection"] = _smoke_after_interaction_steps_v1() == 60
	var state := {
		"epoch_start_global_step": 272,
		"phase": Orchestrator.PHASE_CONFIRM_PRONE,
		"precondition_pair_ready": true,
		"precondition_recovery_step_count": 240,
	}
	_authorized_arm_id = EnergyInitializer.ACTIVE_ARM_ID
	_arms[_authorized_arm_id] = {"orchestrator_state": state}
	_total_solver_step_count = 331
	checks["actual_hook_continues_at_59"] = not _after_completed_process_isolated_step_v1()
	_total_solver_step_count = 332
	checks["actual_hook_stops_at_60"] = (
		_after_completed_process_isolated_step_v1()
		and captured_stop == "diagnostic_after_interaction_horizon"
	)
	checks["default_still_stops_at_30"] = (
		diagnostic_stop_reason_v1(state, 302) == "diagnostic_after_interaction_horizon"
	)
	state["epoch_start_global_step"] = null
	state["phase"] = Orchestrator.PHASE_PRECONDITION_RECOVERY
	checks["new_total_cap_412"] = (
		diagnostic_stop_reason_v1(state, 411, 60).is_empty()
		and diagnostic_stop_reason_v1(state, 412, 60) == "diagnostic_setup_or_total_horizon"
	)
	state["precondition_pair_ready"] = false
	state["precondition_recovery_step_count"] = 320
	checks["setup_cap_unchanged"] = (
		diagnostic_stop_reason_v1(state, 320, 60) == "diagnostic_setup_or_total_horizon"
	)
	_finalize_process_isolated_child_result_v1()
	checks["early_terminal_still_finalizes"] = (
		captured_stop == "production_controller_terminal_before_diagnostic_horizon"
	)
	# Pure transition-branch fixture: it is not an observed physical result.
	var terminal_state := {
		"epoch_start_global_step": 272,
		"energy_initializer_sha256": "synthetic-initializer",
		"confirm_prone_step_count": 59,
		"consecutive_prone_sample_count": 0,
	}
	var event := {
		"global_semantic_step": 332,
		"event_kind": "passive_prone_observation",
		"control_owner": "recovery_v6",
		"actuation_owner": "none",
		"no_actuation_requested": true,
		"walking_actuation_applied": false,
		"recovery_actuation_applied": false,
		"walking_session_id": "",
		"walking_session_local_step": 0,
		"recovery_epoch_local_step": 60,
		"energy_initializer_sha256": "synthetic-initializer",
		"interaction_receipt_sha256": "",
		"kick_application_count": 0,
		"recovery_controller_terminal_phase": "failed",
		"recovery_controller_terminal_reason": "phase_timeout:confirm_prone",
		"prone_sample": false,
	}
	checks["actual_branch_preserves_controller_timeout"] = (
		Orchestrator._advance_confirm_prone_v1(terminal_state, event).is_empty()
		and terminal_state["phase"] == Orchestrator.PHASE_FAILED
		and terminal_state["terminal_reason"] == "phase_timeout:confirm_prone"
	)
	_replay_retained_close_v1(checks)
	var ok := not checks.values().has(false)
	print("DEVELOPMENT_PRONE_DEADLINE ", JsonTransportScript.stringify({
		"ok": ok, "checks": checks, "declaration_schedule": declaration,
		"world_build_count": 0, "solver_step_count": 0, "native_physics_read_count": 0,
	}))
	quit(0 if ok else 1)


func _replay_retained_close_v1(checks: Dictionary) -> void:
	var path := EVIDENCE_ROOT + (
		"development-recovery-smoke-0b0a56bac7614a32b588ae2810be0213/"
		+ "children/matched_no_kick_continuation/worker_report.json"
	)
	var retained: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var arm: Dictionary = retained["partial_arm"].duplicate(true)
	var failure: Dictionary = arm["last_walking_evaluation_failure"]
	checks["original_close_failure_preserved"] = (
		failure["evaluator_failure_code"] == "QSDK_R10F_WALKING_EVALUATION_SHAPE_INVALID"
	)
	# JSON.parse_string represents numbers as floats. Rehydrate only declared
	# integer counters/indexes; no observed angle, position or other float changes.
	for key in [
		"solver_reset_count", "body_population_rebuild_count", "direct_torso_force_command_count",
		"direct_torso_impulse_command_count", "direct_torso_velocity_command_count",
		"direct_torso_transform_command_count"
	]:
		arm[key] = int(arm[key])
	for key in ["trace_start_index", "scheduled_step_count"]:
		arm["active_walking_session"][key] = int(arm["active_walking_session"][key])
	var completion: Dictionary = failure["completion_receipt"]
	_sdk = ClassDB.instantiate("SporeLocomotionSdk")
	var default_close := close_walking_session_sources_v2(
		_sdk, EnergyInitializer.BASELINE_ARM_ID, arm.duplicate(true), completion, true
	)
	checks["default_30_still_reproduces_original_failure"] = (
		default_close.get("ok") == false
		and default_close["retained_failure"]["evaluator_failure_code"]
		== "QSDK_R10F_WALKING_EVALUATION_SHAPE_INVALID"
	)
	var facade := RetainedCompletionFacade.new()
	facade.receipt = completion
	arm["facade"] = facade
	arm["walking_session_completion_attempted"] = false  # Replay-only facade, not a native shutdown.
	var replay_arm := arm.duplicate(true)
	_arms[EnergyInitializer.BASELINE_ARM_ID] = arm
	var actual := _finish_walking_session_v1(EnergyInitializer.BASELINE_ARM_ID)
	checks["actual_finish_propagates_declared_60_to_evaluator"] = actual.get("ok") == true
	checks["retained_completion_used_once"] = facade.calls == 1
	var closed: Dictionary = _arms[EnergyInitializer.BASELINE_ARM_ID]
	checks["replayed_session_closed_no_behavior_claim"] = (
		closed["active_walking_session"].is_empty()
		and closed["last_walking_evaluation_failure"].is_empty()
		and closed["walking_sessions"][-1]["evaluation"].get("behavioral_conclusion") == "none"
	)
	for corruption in ["missing_row", "bad_shutdown_type"]:
		var bad_arm := replay_arm.duplicate(true)
		var bad_completion := completion.duplicate(true)
		if corruption == "missing_row":
			bad_arm["trace_rows"].pop_back()
		else:
			bad_completion["adapter_shutdown_receipt"]["explicit_shutdown_completed"] = "false"
		checks["declared_60_refuses_" + corruption] = (
			close_walking_session_sources_v2(
				_sdk, EnergyInitializer.BASELINE_ARM_ID, bad_arm, bad_completion, true, 60
			).get("ok") == false
		)
	var incomplete_arm := replay_arm.duplicate(true)
	var incomplete := completion.duplicate(true)
	incomplete["adapter_shutdown_receipt"]["explicit_shutdown_completed"] = false
	var incomplete_close := close_walking_session_sources_v2(
		_sdk, EnergyInitializer.BASELINE_ARM_ID, incomplete_arm, incomplete, true, 60
	)
	checks["incomplete_shutdown_remains_explicit_negative_receipt"] = (
		incomplete_close.get("ok") == true
		and incomplete_arm["walking_sessions"][-1]["evaluation"]["walking_gate_receipts"]
		.get("explicit_sdk_controller_session_shutdown") == false
	)
