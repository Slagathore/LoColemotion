extends "res://sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd"
# gdlint: disable=max-line-length

## V6 constructs and gets the original model standing. Only the measured
## post-kick recovery uses V8. No pose rewrite, new world or energy reset.
var _rate_limited_context: Dictionary = {}
const Profile := preload("res://sdk/adapters/godot/gdscript/development_rate_limited_recovery_profile_v1.gd")


func _entry_controller_id_v1() -> String:
	return RouteScript.RECOVERY_CONTROLLER_V8_ID


func _entry_selection_v1() -> Dictionary:
	return Profile.value_v1()["worker_selection"]


func _recovery_controller_for_phase_v1(phase: String) -> String:
	return (RouteScript.RECOVERY_CONTROLLER_V8_ID
		if phase in [Orchestrator.PHASE_CONFIRM_PRONE, Orchestrator.PHASE_POST_KICK_RECOVERY]
		else RouteScript.RECOVERY_CONTROLLER_V6_ID)


func _advance_recovery_stage_v1(arm: Dictionary, bound: Dictionary, global_step: int) -> Dictionary:
	var phase: String = arm.get("orchestrator_state", {}).get("phase", "")
	if _recovery_controller_for_phase_v1(phase) == RouteScript.RECOVERY_CONTROLLER_V6_ID:
		return super._advance_recovery_stage_v1(arm, bound, global_step)
	if _rate_limited_context.is_empty():
		_rate_limited_context = RouteScript.prepare_rate_limited_recovery_context_v1(_sdk)
	if _rate_limited_context.get("source_native_context_sha256") != _canonical_sha256_v1(_context):
		return RecoveryAdvanceStageL15.retain_v1(arm, RecoveryAdvanceStageL15._not_called_v1(
			"DEVELOPMENT_RATE_LIMITED_RECOVERY_WORKER_CONTEXT_CROSSED", arm.get("pending_application"),
			arm.get("recovery_memory"), bound), global_step)
	return RecoveryAdvanceStageL15.advance_rate_limited_recovery_v1(_sdk, _rate_limited_context, arm, bound, global_step)


func _create_passive_recovery_observation_application_v1(completed_global_step: int) -> Dictionary:
	return _consume_l15_no_actuation_stage_v1(NoActuationStageL15.passive_v1(
		_sdk, _arms[EnergyInitializer.ACTIVE_ARM_ID], completed_global_step, _entry_controller_id_v1()))


func _attach_entry_retention_v1(report: Dictionary) -> void:
	super._attach_entry_retention_v1(report)
	report["passive_entry"]["schema_version"] = "sporespore_development_rate_limited_recovery_entry_retention_v1"
	report["passive_entry"]["setup_controller_id"] = RouteScript.RECOVERY_CONTROLLER_V6_ID
	report["passive_entry"]["post_kick_controller_id"] = _entry_controller_id_v1()
	report["passive_entry"]["post_kick_controller_context"] = _rate_limited_context.duplicate(true)
