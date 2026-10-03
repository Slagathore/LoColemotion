extends "res://sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd"

const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
var captured_stop := ""

class CompletionOnly:
	extends RefCounted
	var receipt: Dictionary
	var calls := 0
	func finish_walking_session_v1() -> Dictionary:
		calls += 1
		return receipt.duplicate(true)

func _finish_smoke_v1(reason: String) -> void:
	# Intercept the physical finalizer only; invoke the actual bounded-stop hook.
	captured_stop = reason

func _initialize() -> void:
	call_deferred("_test_profile")

func _test_profile() -> void:
	_entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(_entry_selection_v1()["binding"]))
	if not _load_runtime_extension_v1():
		_finish({"runtime_load": false})
		return
	_sdk = ClassDB.instantiate("SporeLocomotionSdk")
	var declaration := {"diagnostic_schedule_id": _entry_selection_v1()["schedule"],
		"maximum_passive_descent_steps": 240, "maximum_precondition_steps": 320, "walking_prefix_steps": 30,
		"interaction_steps": 1, "after_interaction_steps": 480, "maximum_steps_per_child": 832}
	var checks := {"actual_schedule_selected": _configure_smoke_schedule_v1(declaration),
		"physical_worker_selects_preloaded_walking_runtime": _walking_uses_preloaded_native_runtime_v1(),
		"actual_walking_start_and_shutdown_before_any_world": (_entry_walking_runtime_preflight.get("ok") == true
			and _entry_walking_runtime_preflight.get("native_controller_session_create_count") == 1
			and _entry_walking_runtime_preflight.get("native_controller_session_destroy_count") == 1
			and _entry_walking_runtime_preflight.get("world_build_count") == 0),
		"old_extension_not_reloaded_by_walking_start": not GDExtensionManager.is_extension_loaded(EXTENSION_PATH),
		"walking_close_inherits_480": _development_walking_diagnostic_maximum_steps_v1() == 480,
		"official_prefix_720_unchanged": Orchestrator.WALKING_PREFIX_STEPS == 720,
		"canonical_confirm_60_unchanged": Orchestrator.MAXIMUM_CONFIRM_PRONE_STEPS == 60}
	var state := {"epoch_start_global_step": 272, "phase": EntryOrchestrator.PHASE_DESCENT,
		"precondition_pair_ready": true, "precondition_recovery_step_count": 240}
	_authorized_arm_id = EnergyInitializer.ACTIVE_ARM_ID
	_arms[_authorized_arm_id] = {"orchestrator_state": state}
	_total_solver_step_count = 751
	checks["actual_stop_waits_through_479"] = not _after_completed_process_isolated_step_v1()
	_total_solver_step_count = 752
	checks["actual_stop_closes_at_480"] = _after_completed_process_isolated_step_v1() and captured_stop == "diagnostic_after_interaction_horizon"
	checks["resource_cap_832"] = diagnostic_stop_reason_v1({"epoch_start_global_step": null,
		"phase": Orchestrator.PHASE_WALKING_PREFIX}, 832, 480) == "diagnostic_setup_or_total_horizon"
	_arms[_authorized_arm_id] = {"orchestrator_state": {"phase": EntryOrchestrator.PHASE_DESCENT,
		"previous_global_semantic_step": 0}, "recovery_memory": {}, "next_recovery_control": {}}
	var refused_plan := _plan_next_process_isolated_frame_v1(1)
	var timing := _cost.snapshot_v1(0, Time.get_ticks_usec())
	checks["new_planner_keeps_profile_accounting_even_on_refusal"] = (refused_plan.get("ok") == false
		and timing.get("ok") == true and timing["sections"]["plan_step/" + EntryOrchestrator.PHASE_DESCENT]["sample_count"] == 1)
	_test_walking_close(checks)
	_finish(checks)

func _test_walking_close(checks: Dictionary) -> void:
	var path := EVIDENCE_ROOT + "development-recovery-smoke-0b0a56bac7614a32b588ae2810be0213/children/matched_no_kick_continuation/worker_report.json"
	checks["original_failure_bytes_unchanged"] = FileAccess.get_sha256(path) == "630c201257b4297256679c5c036e61bf222e77737089004e09427d36a18ac94e"
	if not checks["original_failure_bytes_unchanged"]:
		return
	var retained: Dictionary = _sdk.decode_exact_json_v1(FileAccess.get_file_as_string(path))
	var arm: Dictionary = retained["partial_arm"].duplicate(true)
	var completion: Dictionary = arm["last_walking_evaluation_failure"]["completion_receipt"].duplicate(true)
	for key in ["solver_reset_count", "body_population_rebuild_count", "direct_torso_force_command_count",
		"direct_torso_impulse_command_count", "direct_torso_velocity_command_count", "direct_torso_transform_command_count"]:
		arm[key] = int(arm[key])
	# Explicitly synthetic repeated-row population, not an extension or new
	# interpretation of the retained 60-step physical attempt. Only the actual
	# closing call's declared bound and complete-row checks are under test.
	var template: Dictionary = arm["trace_rows"][-1].duplicate(true)
	var rows := []
	for index in range(480):
		var row := template.duplicate(true)
		row["synthetic_test_row"] = true
		row["walking_session_local_step"] = index + 1
		rows.append(row)
	arm["trace_rows"] = rows
	arm["active_walking_session"]["trace_start_index"] = 0
	arm["active_walking_session"]["scheduled_step_count"] = 480
	for key in ["step_count", "validated_balanced_wave_command_count", "native_actuation_application_count"]:
		completion["adapter_summary"][key] = 480
	arm["walking_session_completion_attempted"] = false
	var facade := CompletionOnly.new()
	facade.receipt = completion
	arm["facade"] = facade
	var pristine := arm.duplicate(true)
	var role: String = EnergyInitializer.BASELINE_ARM_ID
	_arms[role] = arm
	var closed := _finish_walking_session_v1(role)
	checks["actual_finish_closes_synthetic_480_once"] = closed.get("ok") == true and facade.calls == 1
	checks["session_closed_with_no_behavior_claim"] = (_arms[role]["active_walking_session"].is_empty()
		and _arms[role]["walking_sessions"][-1]["evaluation"].get("behavioral_conclusion") == "none") if closed.get("ok") == true else false
	checks["default_still_refuses_480"] = close_walking_session_sources_v2(_sdk, role, pristine.duplicate(true), completion, true).get("ok") == false
	var official_prefix := pristine.duplicate(true)
	official_prefix["active_walking_session"]["evaluation_segment_id"] = "walking_prefix"
	checks["official_still_refuses_noncanonical_segment"] = close_walking_session_sources_v2(_sdk, role, official_prefix, completion, false).get("ok") == false
	for corruption in ["missing_row", "bad_shutdown", "outside_declared_bound"]:
		var changed := pristine.duplicate(true)
		var changed_completion := completion.duplicate(true)
		if corruption == "missing_row":
			changed["trace_rows"].pop_back()
		elif corruption == "bad_shutdown":
			changed_completion["adapter_shutdown_receipt"]["explicit_shutdown_completed"] = "false"
		else:
			changed["active_walking_session"]["scheduled_step_count"] = 481
			var extra := template.duplicate(true)
			extra["walking_session_local_step"] = 481
			changed["trace_rows"].append(extra)
		checks[corruption + "_refused"] = close_walking_session_sources_v2(_sdk, role, changed, changed_completion, true, 480).get("ok") == false

func _finish(checks: Dictionary) -> void:
	var ok := not checks.values().has(false)
	_sdk = null
	print("DEVELOPMENT_MEASURED_ENTRY_PROFILE ", Transport.stringify({"ok": ok, "checks": checks,
		"synthetic_test_only": true, "world_build_count": 0, "native_physics_read_count": 0,
		"solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	quit(0 if ok else 1)
