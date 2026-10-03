extends "res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
# gdlint: disable=max-line-length

## Same production setup, native collection, controller, launcher and shutdown.
## Only schedule selection and the explicitly non-authoritative endpoint differ.
const SMOKE_SCHEMA := "sporespore_sdk1_development_recovery_smoke_child_v1"
const SMOKE_WORK_ID := "SDK1-GODOT-RECOVERY-DEVELOPMENT-SMOKE-V1"
const SMOKE_RAW_MARKER := "SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW "
const SMOKE_MAX_PRECONDITION_STEPS := 320
const SMOKE_PREFIX_STEPS := 30
const SMOKE_AFTER_INTERACTION_STEPS := 30
const SMOKE_MAX_STEPS := 382


func _initialize() -> void:
	_raw_schema = SMOKE_SCHEMA
	_work_id = SMOKE_WORK_ID
	_raw_marker = SMOKE_RAW_MARKER
	super._initialize()


func _worker_route_tags_v1() -> Dictionary:
	return {
		"raw_schema": SMOKE_SCHEMA,
		"work_ids": [SMOKE_WORK_ID],
		"raw_marker": SMOKE_RAW_MARKER,
		"ready_marker": READY_MARKER,
		"implementation_family": "QSDK-R10F-L15",
	}


func _advance_orchestrator_step_v1(state: Dictionary, event: Dictionary) -> Dictionary:
	return Orchestrator.advance_development_smoke_v1(_sdk, state, event)


func _walking_evaluation_is_development_smoke_v1() -> bool:
	return true


func _smoke_after_interaction_steps_v1() -> int:
	return SMOKE_AFTER_INTERACTION_STEPS


func _development_walking_diagnostic_maximum_steps_v1() -> int:
	return _smoke_after_interaction_steps_v1()


func _after_completed_process_isolated_step_v1() -> bool:
	var state: Dictionary = _arms[_authorized_arm_id]["orchestrator_state"]
	var reason := diagnostic_stop_reason_v1(
		state, _total_solver_step_count, _smoke_after_interaction_steps_v1()
	)
	if not reason.is_empty():
		_finish_smoke_v1(reason)
		return true
	return false


static func diagnostic_stop_reason_v1(
	state: Dictionary, solver_steps: int, after_interaction_steps: int = SMOKE_AFTER_INTERACTION_STEPS
) -> String:
	var epoch: Variant = state["epoch_start_global_step"]
	if epoch is int and solver_steps - int(epoch) >= after_interaction_steps:
		return "diagnostic_after_interaction_horizon"
	if (
		solver_steps >= SMOKE_MAX_STEPS - SMOKE_AFTER_INTERACTION_STEPS + after_interaction_steps
		or (
			state["phase"] == Orchestrator.PHASE_PRECONDITION_RECOVERY
			and not bool(state["precondition_pair_ready"])
			and int(state["precondition_recovery_step_count"]) >= SMOKE_MAX_PRECONDITION_STEPS
		)
	):
		return "diagnostic_setup_or_total_horizon"
	return ""


func _finalize_process_isolated_child_result_v1() -> void:
	_finish_smoke_v1("production_controller_terminal_before_diagnostic_horizon")


func _finish_smoke_v1(stop_reason: String) -> void:
	if _finalizing or _exit_scheduled:
		return
	_finalizing = true
	_quiesce_process_isolated_child_v1()
	var walking_close := _finish_walking_session_v1(_authorized_arm_id)
	if walking_close.get("ok") != true:
		_abort("DEVELOPMENT_SMOKE_WALKING_CLOSE_INVALID", walking_close)
		return
	var arm: Dictionary = _arms[_authorized_arm_id]
	var facade: RefCounted = arm["facade"]
	var terminal_identity: Dictionary = facade.same_body_identity_receipt_v1(
		_sdk, _observed_global_solver_frames, "development_smoke_terminal_boundary"
	)
	if (
		terminal_identity.get("ok") != true
		or (
			terminal_identity.get("body_population_instance_sha256")
			!= arm["body_population_instance_sha256"]
		)
	):
		_abort("DEVELOPMENT_SMOKE_BODY_IDENTITY_INVALID", terminal_identity)
		return
	arm["terminal_same_body_identity_receipt"] = terminal_identity
	_arms[_authorized_arm_id] = arm
	var state: Dictionary = arm["orchestrator_state"]
	var after_steps := 0
	if state["epoch_start_global_step"] is int:
		after_steps = _total_solver_step_count - int(state["epoch_start_global_step"])
	var expected_kicks := 1 if _authorized_arm_id == EnergyInitializer.ACTIVE_ARM_ID else 0
	var covered := (
		int(state["walking_prefix_step_count"]) == SMOKE_PREFIX_STEPS
		and int(state["interaction_effect_step_count"]) == 1
		and after_steps == _smoke_after_interaction_steps_v1()
		and _external_kick_application_count == expected_kicks
	)
	var report := {
		"schema_version": SMOKE_SCHEMA,
		"work_id": SMOKE_WORK_ID,
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "unofficial_physical_smoke",
			"question_class": "development"
		},
		"status":
		"development_smoke_complete" if covered else "development_smoke_coverage_incomplete",
		"ok": true,
		"coverage_complete": covered,
		"stop_reason": stop_reason,
		"source_commit": _source_commit,
		"diagnostic_declaration_sha256": _authorization_sha256,
		"parent_attempt_id": _parent_attempt_id,
		"child_attempt_id": _attempt_id,
		"arm_id": _authorized_arm_id,
		"process_id": OS.get_process_id(),
		"seed": _seed,
		"model_construction_attempt_count": _total_model_construction_attempt_count,
		"model_construction_count": _total_model_construction_count,
		"world_attempt_count": _total_world_attempt_count,
		"world_build_count": _total_world_build_count,
		"solver_step_count": _total_solver_step_count,
		"global_solver_frame_count": _observed_global_solver_frames,
		"maximum_solver_step_count":
		SMOKE_MAX_STEPS - SMOKE_AFTER_INTERACTION_STEPS + _smoke_after_interaction_steps_v1(),
		"after_interaction_step_count": after_steps,
		"external_kick_application_count": _external_kick_application_count,
		"explicit_worker_extra_native_readback_count": _total_native_readback_count,
		"configuration": _configuration,
		"l15_prepared_context_comparison": get_meta("l15_prepared_context_comparison", {}),
		"precondition_terminal_receipt": _process_isolated_precondition_terminal_receipt,
		"precondition_release_receipt": _process_isolated_precondition_release_receipt,
		"interaction_source": _process_isolated_interaction_source,
		"retained_arm": partial_arm_failure_retention_projection_l15_v1(arm, _authorized_arm_id),
		"terminal_same_body_identity_receipt": terminal_identity,
		"telemetry_profile": "unchanged_full_per_step_capture",
		"complete_route_proven": false,
		"behavioral_conclusion": "none",
		"held_out": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	_cleanup_worlds_v1()
	_publish_smoke_report_v1(report)
	_schedule_exit_v1(0, "development_smoke_diagnostic_only")


func _publish_smoke_report_v1(report: Dictionary) -> String:
	var raw := JsonTransportScript.stringify(report)
	print(SMOKE_RAW_MARKER, raw)
	return raw
