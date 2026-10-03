class_name SporeQsdkR10fL15RecoveryAdvanceStageV1
extends RefCounted
# gdlint: disable=max-line-length

## One actual production advance, retained before its caller can abort. Arm
## state is internal and shallow-copied; accumulated traces/model objects are
## neither reserialized nor duplicated. No physics surface is invoked here.
const Behavior := preload("res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd")
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Transport := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_transport_v1.gd"
)
const PRECOLLECTION_DISPATCH_REFUSALS := [
	"QSDK_R24D131_CONTROLLER_CONTEXT_MISMATCH",
	"QSDK_R24D151_DISCRETE_STAGING_COMPLETE_ENERGY_DISPATCH_IDENTITY_INVALID",
	"QSDK_R10F_L15_DISPATCH_IDENTITY_INVALID",
]


static func advance_v1(
	sdk: Object, context: Dictionary, arm: Dictionary, bound: Dictionary, global_step: int
) -> Dictionary:
	var application: Variant = arm.get("pending_application")
	var memory: Variant = arm.get("recovery_memory")
	var advance: Dictionary
	if not (application is Dictionary) or not (memory is Dictionary):
		advance = _not_called_v1(
			"QSDK_R10F_L15_ADVANCE_ARM_SOURCE_MISSING", application, memory, bound
		)
	else:
		advance = Behavior.production_advance_dispatch_v1(
			sdk,
			context,
			bound,
			memory,
			"candidate_command",
			String(memory.get("phase", "")),
			Route.RECOVERY_CONTROLLER_V6_ID,
			Route.R148_COMPLETE_ENERGY_ROUTE_ID,
			application
		)
		if (
			not advance.has("collection_transport_retention")
			and advance.get("failure_code") in PRECOLLECTION_DISPATCH_REFUSALS
		):
			# These exact dispatcher branches return before the route call. An
			# arbitrary missing capture is never assigned an invented zero count.
			advance["collection_transport_retention"] = Transport.route_not_called_v1(
				advance["failure_code"], _sources_v1(application, memory, bound)
			)
	return retain_v1(arm, advance, global_step)


static func retain_v1(arm: Dictionary, advance: Dictionary, global_step: int) -> Dictionary:
	var next_arm := arm.duplicate(false)
	var packet: Variant = advance.get("collection_transport_retention")
	var available: bool = packet is Dictionary and not packet.is_empty()
	var result := advance
	if not available:
		result = {
			"ok": false,
			"failure_code": "QSDK_R10F_L15_ADVANCE_RETENTION_MISSING",
			"unretained_advance": advance.duplicate(true)
		}
	# Replace, never reuse a previous step's capture. A missing current packet
	# stays missing even if the preceding step had a perfectly valid record.
	next_arm["last_recovery_collection_transport_retention"] = (
		packet.duplicate(true) if available else {}
	)
	next_arm["last_recovery_collection_transport_global_semantic_step"] = global_step
	next_arm["last_recovery_advance_failure"] = (
		{} if result.get("ok") == true else result.duplicate(true)
	)
	return {
		"schema_version": "sporespore_qsdk_r10f_l15_recovery_advance_stage_v1",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "development_worker_advance_retention",
			"question_class": "development"
		},
		"ok": result.get("ok") == true and available,
		"arm": next_arm,
		"advance": result,
		"collection_transport_retention_available": available,
		"additional_collection_call_count": 0,
		"additional_controller_advance_count": 0,
		"additional_native_physics_read_count": 0,
		"additional_solver_step_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Same retained production advance machinery, explicitly selected for V7.
## This is not a world-construction or official behavior entrypoint.
static func advance_rearward_fold_v1(sdk: Object, context: Dictionary,
	arm: Dictionary, bound: Dictionary, global_step: int) -> Dictionary:
	var application: Variant = arm.get("pending_application")
	var memory: Variant = arm.get("recovery_memory")
	var advance: Dictionary
	if not (application is Dictionary) or not (memory is Dictionary):
		advance = _not_called_v1("QSDK_R10F_L15_ADVANCE_ARM_SOURCE_MISSING", application, memory, bound)
	elif not Route.rearward_fold_context_binding_exact_v1(sdk, context):
		advance = _not_called_v1("DEVELOPMENT_REARWARD_FOLD_CONTEXT_INVALID", application, memory, bound)
	else:
		advance = Route.advance_rearward_fold_control_v1(sdk, context, bound, memory, application)
		if advance.get("ok") == true:
			advance["production_advance_dispatch_id"] = Behavior.production_advance_dispatch_id_for_route_v1(Route.R148_COMPLETE_ENERGY_ROUTE_ID)
			advance["selected_portable_advance_route"] = Behavior.selected_advance_route_for_energy_route_v1(Route.R148_COMPLETE_ENERGY_ROUTE_ID)
			advance["development_progression_required"] = true
			advance["complete_energy_authority_required"] = true
			advance["energy_route_id"] = Route.R148_COMPLETE_ENERGY_ROUTE_ID
			advance["selected_development_recovery_controller_id"] = Route.RECOVERY_CONTROLLER_V7_ID
	return retain_v1(arm, advance, global_step)


static func advance_rate_limited_recovery_v1(sdk: Object, context: Dictionary,
	arm: Dictionary, bound: Dictionary, global_step: int) -> Dictionary:
	var application: Variant = arm.get("pending_application")
	var memory: Variant = arm.get("recovery_memory")
	var advance: Dictionary
	if not (application is Dictionary) or not (memory is Dictionary):
		advance = _not_called_v1("QSDK_R10F_L15_ADVANCE_ARM_SOURCE_MISSING", application, memory, bound)
	elif not Route.rate_limited_recovery_context_binding_exact_v1(sdk, context):
		advance = _not_called_v1("DEVELOPMENT_RATE_LIMITED_RECOVERY_CONTEXT_INVALID", application, memory, bound)
	else:
		advance = Route.advance_rate_limited_recovery_control_v1(sdk, context, bound, memory, application)
		if advance.get("ok") == true:
			advance["production_advance_dispatch_id"] = Behavior.production_advance_dispatch_id_for_route_v1(Route.R148_COMPLETE_ENERGY_ROUTE_ID)
			advance["selected_portable_advance_route"] = Behavior.selected_advance_route_for_energy_route_v1(Route.R148_COMPLETE_ENERGY_ROUTE_ID)
			advance["development_progression_required"] = true
			advance["complete_energy_authority_required"] = true
			advance["energy_route_id"] = Route.R148_COMPLETE_ENERGY_ROUTE_ID
			advance["selected_development_recovery_controller_id"] = Route.RECOVERY_CONTROLLER_V8_ID
	return retain_v1(arm, advance, global_step)


static func advance_development_candidate_v1(sdk: Object, context: Dictionary,
	arm: Dictionary, bound: Dictionary, global_step: int, controller_id: String) -> Dictionary:
	var application: Variant = arm.get("pending_application")
	var memory: Variant = arm.get("recovery_memory")
	var advance: Dictionary
	if not (application is Dictionary) or not (memory is Dictionary):
		advance = _not_called_v1("QSDK_R10F_L15_ADVANCE_ARM_SOURCE_MISSING", application, memory, bound)
	elif not Route.development_candidate_context_binding_exact_v1(sdk, context, controller_id):
		advance = _not_called_v1("DEVELOPMENT_CANDIDATE_CONTEXT_INVALID", application, memory, bound)
	else:
		advance = Route.advance_behavior_solver_coupled_complete_energy_l15_v1(
			sdk, context, bound, memory, "candidate_command", String(memory.get("phase", "")), application)
		if advance.get("ok") == true:
			advance["production_advance_dispatch_id"] = Behavior.production_advance_dispatch_id_for_route_v1(Route.R148_COMPLETE_ENERGY_ROUTE_ID)
			advance["selected_portable_advance_route"] = Behavior.selected_advance_route_for_energy_route_v1(Route.R148_COMPLETE_ENERGY_ROUTE_ID)
			advance["development_progression_required"] = true
			advance["complete_energy_authority_required"] = true
			advance["energy_route_id"] = Route.R148_COMPLETE_ENERGY_ROUTE_ID
			advance["selected_development_recovery_controller_id"] = controller_id
	return retain_v1(arm, advance, global_step)


static func _not_called_v1(
	code: String, application: Variant, memory: Variant, bound: Dictionary
) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"collection_transport_retention":
		Transport.route_not_called_v1(code, _sources_v1(application, memory, bound))
	}


static func _sources_v1(application: Variant, memory: Variant, bound: Dictionary) -> Dictionary:
	return {"source_application": application, "source_memory": memory, "bound_observation": bound}
