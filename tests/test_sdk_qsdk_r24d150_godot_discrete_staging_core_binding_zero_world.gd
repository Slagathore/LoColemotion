extends SceneTree
# gdlint: disable=max-line-length

## Compact R150 zero-world control for the R149 integration omission. It builds
## the exact synthetic R148 bound observation and calls the production
## collect_and_plan_v1 entry point. No Node, RID, model, world, or solver step
## is constructed.

const RouteGhostScript := preload(
	"res://tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
)
const R149Worker := preload(
	"res://tests/test_sdk_qsdk_r24d149_godot_jolt_discrete_staging_live_route_zero_world.gd"
)
const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const StagingRoute := preload(
	"res://sdk/adapters/godot/gdscript/recovery_discrete_staging_route_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D150_GODOT_DISCRETE_STAGING_CORE_BINDING_ZERO_WORLD "
const ACTUATOR_MODE := "solver_coupled_native_constraint_motor_v1"
const R144_COLLECTOR_ID := (
	"sporespore_godot_jolt_solver_coupled_complete_energy_v4_recovery_collector_v1"
)
const INSTRUMENTED_RUNTIME_PROFILE_ID := (
	"godot_4_7_jolt_sporespore_motor_and_solved_contact_telemetry_v3"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate_v1()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate_v1() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D150_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D150_SDK_INSTANTIATION_FAILED")
	var fixture := _production_fixture_v1(sdk)
	if not bool(fixture.get("ok", false)):
		return _failure("QSDK_R24D150_PRODUCTION_FIXTURE_FAILED", fixture)
	var context: Dictionary = fixture["context"]
	var bound: Dictionary = fixture["bound"]
	var route := RouteScript.collect_and_plan_v1(
		sdk, context, bound, "establish_distal_support", 0
	)
	var collection: Dictionary = route.get("collection_receipt", {})
	var control: Dictionary = route.get("control_receipt", {})
	var production_detail: Dictionary = route.get("detail", {})
	var positive_checks := {
		"production_collect_and_plan_accepted": bool(route.get("ok", false)),
		"exact_r148_collection_identity": (
			String(collection.get("support_status", "")) == "supported_exact"
			and String(collection.get("collector_id", ""))
			== RouteScript.R148_COMPLETE_ENERGY_COLLECTOR_ID
			and bool(collection.get("supplied_native_post_step_observation_validated", false))
		),
		"portable_control_planned": (
			String(control.get("support_status", "")) == "supported_exact"
			and int((control.get("ordered_commands", []) as Array).size()) == 8
		),
		"production_call_remained_zero_world": _zero_world_receipt_v1(route),
	}
	var forced_failure_checks := {
		"r144_collector_cross_refused": _collector_cross_refused_v1(sdk, context, bound),
		"runtime_profile_cross_refused": _runtime_cross_refused_v1(sdk, context, bound),
		"source_route_cross_refused": _source_route_cross_refused_v1(sdk, context, bound),
		"mapping_profile_cross_refused": _mapping_cross_refused_v1(sdk, context, bound),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d150_godot_discrete_staging_core_binding_zero_world_v1",
		"gate_id": "QSDK-R24D150",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_portable_core_identity_binding_zero_world",
			"question_class": "development",
		},
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D150_ZERO_WORLD_CONJUNCTION_INVALID",
		"question_class": "development",
		"actuator_mode": ACTUATOR_MODE,
		"recovery_controller_id": RouteScript.RECOVERY_CONTROLLER_V6_ID,
		"collector_id": RouteScript.R148_COMPLETE_ENERGY_COLLECTOR_ID,
		"runtime_profile_id": String((context["runtime_binding"] as Dictionary)["runtime_profile_id"]),
		"energy_route_id": RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
		"energy_mapping_profile_id": RouteScript.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"production_collection_method": "SporeLocomotionSdk.recovery_collect_native_v3_json",
		"production_control_method": "SporeLocomotionSdk.recovery_plan_control_v3_json",
		"production_collect_and_plan_invocation_count": 1,
		"production_route_failure_code": String(route.get("failure_code", "")),
		"production_detail_failure_code": String(
			production_detail.get("failure_code", "")
		),
		"production_detail_text": String(production_detail.get("detail", "")),
		"production_collection_support_status": String(
			production_detail.get("support_status", collection.get("support_status", ""))
		),
		"production_collection_refusal_reason": String(
			production_detail.get("refusal_reason", "")
		),
		"positive_checks": positive_checks,
		"positive_case_count": positive_checks.size(),
		"positive_pass_count": positive_pass_count,
		"forced_failure_checks": forced_failure_checks,
		"forced_failure_case_count": forced_failure_checks.size(),
		"forced_failure_pass_count": forced_failure_pass_count,
		"sdk_instance_count": 1,
		"historical_closure_audits_executed_count": 0,
		"bespoke_physical_canary_count": 0,
		"full_seeded_ghost_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _production_fixture_v1(sdk: Object) -> Dictionary:
	var context := RouteGhostScript.prepare_route_context_v1(
		sdk,
		RouteScript.RECOVERY_CONTROLLER_V6_ID,
		RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
		"QSDK-R24D150",
	)
	var projection := R149Worker._boundary_projection_v1(1)
	var mapping := R149Worker._mapping_chain_v1(sdk, context, projection)
	var predecessor_context := RouteScript.prepare_complete_energy_context_v3(
		sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	var predecessor_bound := (
		RouteScript.zero_world_fixture_solver_coupled_complete_energy_v1(
			sdk, predecessor_context
		)
	)
	if (
		not bool(context.get("ok", false))
		or not bool(mapping.get("fixture_ready", false))
		or not bool(predecessor_bound.get("ok", false))
	):
		return {"ok": false, "context": context, "mapping": mapping}
	var observation_base: Dictionary = (
		predecessor_bound["observation_v2"] as Dictionary
	).duplicate(true)
	observation_base.erase("schema_version")
	observation_base.erase("energy_balance")
	(observation_base["engine_step_identity"] as Dictionary)["capability_sha256"] = (
		String(context.get("capability_sha256", ""))
	)
	(observation_base["state"] as Dictionary)["adapter_capability_sha256"] = (
		String(context.get("capability_sha256", ""))
	)
	var bound := RouteScript.compose_discrete_staging_complete_energy_observations_v1(
		sdk,
		context,
		observation_base,
		mapping["predecessor_energy_source"],
		mapping["predecessor_components"],
		mapping["observer_step_1"],
		StagingRoute.initial_accumulator_v1(),
	)
	return {
		"ok": bool(bound.get("ok", false)),
		"context": context,
		"bound": bound,
	}


static func _collector_cross_refused_v1(
	sdk: Object, context: Dictionary, bound: Dictionary
) -> bool:
	var mutation := context.duplicate(true)
	(mutation["runtime_binding"] as Dictionary)["collector_id"] = R144_COLLECTOR_ID
	return _refusal_exact_v1(
		RouteScript.collect_and_plan_v1(
			sdk, mutation, bound, "establish_distal_support", 0
		),
		"observation_v2_source_identity_invalid",
	)


static func _runtime_cross_refused_v1(
	sdk: Object, context: Dictionary, bound: Dictionary
) -> bool:
	var mutation := context.duplicate(true)
	(mutation["runtime_binding"] as Dictionary)["runtime_profile_id"] = (
		INSTRUMENTED_RUNTIME_PROFILE_ID
	)
	return _refusal_exact_v1(
		RouteScript.collect_and_plan_v1(
			sdk, mutation, bound, "establish_distal_support", 0
		),
		"collector_or_runtime_profile_identity_invalid",
	)


static func _source_route_cross_refused_v1(
	sdk: Object, context: Dictionary, bound: Dictionary
) -> bool:
	var mutation := bound.duplicate(true)
	(mutation["source_binding"] as Dictionary)["source_route_id"] = (
		RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
	)
	return _refusal_exact_v1(
		RouteScript.collect_and_plan_v1(
			sdk, context, mutation, "establish_distal_support", 0
		),
		"observation_v2_source_identity_invalid",
	)


static func _mapping_cross_refused_v1(
	sdk: Object, context: Dictionary, bound: Dictionary
) -> bool:
	var mutation := bound.duplicate(true)
	(mutation["source_binding"] as Dictionary)["mapping_profile_id"] = (
		RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	)
	return _refusal_exact_v1(
		RouteScript.collect_and_plan_v1(
			sdk, context, mutation, "establish_distal_support", 0
		),
		"observation_v2_source_identity_invalid",
	)


static func _refusal_exact_v1(route: Dictionary, reason: String) -> bool:
	var detail: Dictionary = route.get("detail", {})
	return (
		not bool(route.get("ok", true))
		and String(route.get("failure_code", "")) == "QSDK_R24D57_NATIVE_COLLECTION_REFUSED"
		and String(detail.get("refusal_reason", "")) == reason
		and int(detail.get("model_construction_count", -1)) == 0
		and int(detail.get("world_attempt_count", -1)) == 0
		and int(detail.get("world_build_count", -1)) == 0
		and int(detail.get("solver_step_count", -1)) == 0
		and not bool(detail.get("physics_state_modified", true))
	)


static func _zero_world_receipt_v1(route: Dictionary) -> bool:
	return (
		int(route.get("model_construction_count", -1)) == 0
		and int(route.get("world_attempt_count", -1)) == 0
		and int(route.get("world_build_count", -1)) == 0
		and int(route.get("solver_step_count", -1)) == 0
		and not bool(route.get("physics_state_modified", true))
		and not bool(route.get("physical_acceptance_authority", true))
		and not bool(route.get("release_authority", true))
	)


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Variant = null) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d150_godot_discrete_staging_core_binding_zero_world_v1",
		"gate_id": "QSDK-R24D150",
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"positive_case_count": 4,
		"forced_failure_case_count": 4,
		"sdk_instance_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
