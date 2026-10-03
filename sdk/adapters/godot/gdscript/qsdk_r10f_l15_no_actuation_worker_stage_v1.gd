class_name SporeQsdkR10fL15NoActuationWorkerStageV1
extends RefCounted
# gdlint: disable=max-line-length

## Complete opt-in worker stages. The supplied facade owns the single existing
## motor-population read; tests supply an explicitly synthetic readback facade.
## This module never constructs a world, applies a command or advances physics.
## Returned arm state is internal: the worker consumes it, never serializes it.
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Facade := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd"
)
const Owner := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd")


static func initialize_v1(
	sdk: Object, context: Dictionary, arm: Dictionary, completed_global_step: int
) -> Dictionary:
	var initialized := Route.initialize_behavior_arm_v1(sdk, context, "candidate_command")
	if initialized.get("ok") != true:
		return _stage_v1({}, initialized, 0, 1, 0)
	var memory: Dictionary = initialized["memory"].duplicate(true)
	# Only top-level slots change. Keep the existing trace/model objects rather
	# than copying the entire accumulated evidence on every passive frame.
	var next_arm := arm.duplicate(false)
	next_arm["recovery_memory"] = memory
	next_arm["postkick_recovery_initialization_receipt"] = (
		initialized["initialization_receipt"].duplicate(true)
	)
	return _build_application_v1(
		sdk,
		next_arm,
		completed_global_step + 1,
		memory,
		initialized["initialization_receipt"],
		false,
		"post_kick_passive_prone_first_observation",
		1
	)


static func passive_v1(sdk: Object, arm: Dictionary, completed_global_step: int,
	expected_controller_id: String = Owner.RECOVERY_CONTROLLER_ID) -> Dictionary:
	var control_value: Variant = arm.get("next_recovery_control")
	if not (control_value is Dictionary) or control_value.is_empty():
		return _stage_v1({}, _failure_v1("QSDK_R10F_PASSIVE_OWNER_SOURCE_MISSING"), 0, 0, 0)
	var memory_value: Variant = arm.get("recovery_memory")
	if not (memory_value is Dictionary) or memory_value.is_empty():
		return _stage_v1({}, _failure_v1("QSDK_R10F_L15_PASSIVE_MEMORY_SOURCE_MISSING"), 0, 0, 0)
	return _build_application_v1(
		sdk,
		arm.duplicate(false),
		completed_global_step + 1,
		memory_value,
		control_value,
		bool(control_value.get("matched_zero_command", false)),
		"continued_zero_actuation_passive_prone_observation",
		0,
		expected_controller_id
	)


## This external-source check is also called by the worker before any native
## sampling. A freshly rehashed mapping for a different arm memory is invalid.
static func validate_pending_v1(sdk: Object, arm: Dictionary, global_step: int,
	expected_controller_id: String = Owner.RECOVERY_CONTROLLER_ID) -> Dictionary:
	var application_value: Variant = arm.get("pending_application")
	if not (application_value is Dictionary) or application_value.is_empty():
		return _failure_v1("QSDK_R10F_PENDING_APPLICATION_STEP_INVALID")
	var application: Dictionary = application_value
	var has_mapping: bool = (
		application.get("schema_version") == Owner.APPLICATION_SCHEMA
		or application.has("canonical_controller_owner")
		or application.has("canonical_ownership_mapping")
		or application.has("canonical_ownership_mapping_sha256")
	)
	if has_mapping:
		if (
			typeof(application.get("semantic_step")) != TYPE_INT
			or application["semantic_step"] != global_step
		):
			return _failure_v1("QSDK_R10F_PENDING_APPLICATION_STEP_INVALID")
		var memory_value: Variant = arm.get("recovery_memory")
		if not (memory_value is Dictionary):
			return _failure_v1("QSDK_R10F_L15_PENDING_MEMORY_SOURCE_MISSING")
		return Owner.validate_v1(sdk, application, memory_value, expected_controller_id)
	if application.get("controller_owner") in ["recovery_v6", "recovery_v7", "recovery_v8", "recovery_candidate"]:
		return _failure_v1("QSDK_R10F_L15_PENDING_RECOVERY_MAPPING_REQUIRED")
	# Precondition recovery, walking, release and interaction retain their
	# existing non-L15 application contracts and native number kinds. The outer
	# worker keeps its original step check; this does not qualify those inputs.
	return {"ok": true, "canonical_ownership_mapping_required": false}


static func _build_application_v1(
	sdk: Object,
	next_arm: Dictionary,
	next_step: int,
	memory: Dictionary,
	owner_source: Dictionary,
	zero_command: bool,
	reason: String,
	initialization_count: int,
	expected_controller_id: String = Owner.RECOVERY_CONTROLLER_ID
) -> Dictionary:
	var profile := Owner.profile_v1(expected_controller_id)
	if profile.is_empty():
		return _stage_v1({}, _failure_v1("DEVELOPMENT_RECOVERY_OWNER_PROFILE_UNKNOWN"), 0, initialization_count, 0)
	var facade_value: Variant = next_arm.get("facade")
	if (
		not (facade_value is RefCounted)
		or not facade_value.has_method("motor_population_readback_v1")
	):
		return _stage_v1(
			{}, _failure_v1("QSDK_R10F_L15_MOTOR_FACADE_MISSING"), 0, initialization_count, 0
		)
	var readback: Dictionary = facade_value.motor_population_readback_v1(next_step, false, reason)
	if readback.get("ok") != true:
		return _stage_v1({}, readback, 0, initialization_count, 1)
	# Preserve the old caller's counter timing: a successful read is counted
	# even if application construction subsequently refuses.
	var consumed_reads := int(readback.get("native_readback_count", 0))
	var application := Facade.no_actuation_ledger_application_intent_v2(
		sdk,
		next_step,
		String(memory.get("phase", "")),
		profile["owner"],
		expected_controller_id,
		zero_command,
		owner_source,
		readback,
		memory,
		{},
		expected_controller_id
	)
	if application.get("ok") != true:
		return _stage_v1({}, application, consumed_reads, initialization_count, 1)
	next_arm["pending_application"] = application
	var checked := validate_pending_v1(sdk, next_arm, next_step, expected_controller_id)
	if checked.get("ok") != true:
		return _stage_v1({}, checked, consumed_reads, initialization_count, 1)
	next_arm["next_recovery_control"] = {}
	return _stage_v1(next_arm, {}, consumed_reads, initialization_count, 1)


static func _stage_v1(
	arm: Dictionary, failure: Dictionary, consumed_reads: int, initializations: int, read_calls: int
) -> Dictionary:
	# An unexpected empty return (for example after a script error) is not a
	# successful stage and must never install an empty arm in the worker.
	if arm.is_empty() and failure.is_empty():
		failure = _failure_v1("QSDK_R10F_L15_NO_ACTUATION_STAGE_EMPTY_RESULT")
	return {
		"schema_version": "sporespore_qsdk_r10f_l15_no_actuation_worker_stage_v1",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "development_no_actuation_worker_stage",
			"question_class": "development"
		},
		"ok": failure.is_empty(),
		"arm": arm,
		"failure": failure,
		"consumed_native_readback_count": consumed_reads,
		"portable_controller_initialization_call_count": initializations,
		"motor_population_readback_call_count": read_calls,
		"additional_controller_advance_count": 0,
		"additional_native_physics_read_count": 0,
		"additional_solver_step_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _failure_v1(code: String) -> Dictionary:
	return {"ok": false, "failure_code": code}
