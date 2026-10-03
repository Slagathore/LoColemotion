extends SceneTree
# gdlint: disable=max-line-length

## R165 directly exercises the consumer clause that invalidated R164. The
## production worker must accept the R162 rotation-aware native trace only for
## the distinct R165 context while preserving the consumed R164 and R154 schema
## semantics. Synthetic fixtures open no Node, RID, model, world, native read,
## body write, evaluator, or solver step.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const R151Worker := preload(
	"res://tests/test_sdk_qsdk_r24d151_godot_commissioned_discrete_staging_behavior_zero_world.gd"
)
const R153Worker := preload(
	"res://tests/test_sdk_qsdk_r24d153_godot_route_aware_discrete_staging_behavior_zero_world.gd"
)
const R163Worker := preload(
	"res://tests/test_sdk_qsdk_r24d163_godot_rotation_aware_recovery_route_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D165_GODOT_ROTATION_AWARE_SOURCE_TRACE_BEHAVIOR_ZERO_WORLD "
const GATE_ID := "QSDK-R24D165"
const CONTROLLER := RouteScript.RECOVERY_CONTROLLER_V6_ID
const ENERGY_ROUTE := RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
const R152_TRACE_SCHEMA := (
	"sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_native_source_trace_v1"
)
const R162_TRACE_SCHEMA := (
	"sporespore_qsdk_r24d162_godot_rotation_aware_complete_energy_native_source_trace_v1"
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
		return _failure("QSDK_R24D165_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D165_SDK_INSTANTIATION_FAILED")
	var context := BehaviorWorker.prepare_behavior_context_v1(
		sdk, CONTROLLER, ENERGY_ROUTE, GATE_ID
	)
	var r164_context := RouteScript.prepare_complete_energy_context_v13(sdk, CONTROLLER)
	# The retained R154 constructor is correctly runtime-v5-bound and therefore
	# cannot be reconstructed under v6. This minimal historical identity reaches
	# only the pure versioned schema selector below; it grants no route authority.
	var r154_context := {
		"schema_version": (
			"sporespore_qsdk_r24d154_godot_accumulator_aware_discrete_staging_behavior_context_v10"
		),
		"physical_world_construction_gate_id": "QSDK-R24D154",
	}
	if (
		not bool(context.get("ok", false))
		or not bool(r164_context.get("ok", false))
	):
		return _failure(
			"QSDK_R24D165_CONTEXT_PREPARATION_INVALID",
			{"r165": context, "r164": r164_context, "r154": r154_context},
		)
	var blueprint := RouteScript.native_world_blueprint_v1(sdk, context)
	var fixture := R163Worker._rotation_aware_bound_fixture_v1(sdk, context)
	if not bool(blueprint.get("ok", false)) or not bool(fixture.get("ok", false)):
		return _failure("QSDK_R24D165_BLUEPRINT_OR_FIXTURE_INVALID")
	var bound: Dictionary = fixture["bound"]
	var route := RouteScript.collect_and_plan_v1(
		sdk, context, bound, "establish_distal_support", 0
	)
	var initialized := RouteScript.initialize_behavior_arm_v1(
		sdk, context, "candidate_command"
	)
	var advanced := BehaviorWorker.production_advance_dispatch_v1(
		sdk,
		context,
		bound,
		initialized.get("memory", {}),
		"candidate_command",
		"confirm_prone",
		CONTROLLER,
		ENERGY_ROUTE,
	)
	var traces := BehaviorWorker.paired_zero_world_evaluation_traces_v1(sdk, bound)
	var evaluated := BehaviorWorker.production_evaluation_dispatch_v1(
		sdk,
		context,
		traces.get("candidate_trace", {}),
		traces.get("matched_zero_trace", {}),
		CONTROLLER,
		ENERGY_ROUTE,
	)
	var applications := R151Worker._application_fixtures_v1(sdk, context, bound, true)
	var initial_fixture := R153Worker._initial_application_fixture_v1(sdk, context)
	if (
		not bool(route.get("ok", false))
		or not bool(initialized.get("ok", false))
		or not bool(advanced.get("ok", false))
		or not bool(traces.get("ok", false))
		or not bool(evaluated.get("ok", false))
		or not bool(applications.get("ok", false))
		or not bool(initial_fixture.get("ok", false))
	):
		return _failure(
			"QSDK_R24D165_PRODUCTION_PATH_INVALID",
			{
				"route": route,
				"initialized": initialized,
				"advanced": advanced,
				"traces": traces,
				"evaluated": evaluated,
				"applications": applications,
				"initial_fixture": initial_fixture,
			},
		)
	var positive_checks := {
		"exact_r165_context": (
			RouteScript.rotation_aware_source_trace_behavior_context_binding_exact_v1(
				sdk, context
			)
			and _valid_sha256(String(context.get("r164_finite_behavior_context_sha256", "")))
		),
		"r162_trace_accepted_only_by_r165": (
			BehaviorWorker.native_source_trace_schema_valid_v1(context, R162_TRACE_SCHEMA)
			and not BehaviorWorker.native_source_trace_schema_valid_v1(
				r164_context, R162_TRACE_SCHEMA
			)
			and not BehaviorWorker.native_source_trace_schema_valid_v1(
				r154_context, R162_TRACE_SCHEMA
			)
		),
		"historical_r152_trace_semantics_preserved": (
			not BehaviorWorker.native_source_trace_schema_valid_v1(context, R152_TRACE_SCHEMA)
			and BehaviorWorker.native_source_trace_schema_valid_v1(
				r164_context, R152_TRACE_SCHEMA
			)
			and BehaviorWorker.native_source_trace_schema_valid_v1(
				r154_context, R152_TRACE_SCHEMA
			)
		),
		"validator_profile_selected": (
			BehaviorWorker.rotation_aware_native_source_trace_validation_selected_v1(context)
			and String(context.get("native_source_trace_validator_profile_id", ""))
			== RouteScript.R165_ROTATION_AWARE_SOURCE_TRACE_VALIDATOR_PROFILE_ID
		),
		"r165_invariant_schema_selected": (
			BehaviorWorker.complete_energy_invariant_schema_v5(ENERGY_ROUTE, context)
			== "sporespore_qsdk_r24d165_godot_rotation_aware_source_trace_behavior_in_run_invariant_receipt_v1"
			and BehaviorWorker.complete_energy_invariant_schema_v5(
				ENERGY_ROUTE, r164_context
			)
			== "sporespore_qsdk_r24d164_godot_rotation_aware_recovery_behavior_in_run_invariant_receipt_v1"
		),
		"rotation_aware_ledger_preserved": (
			BehaviorWorker.rotation_aware_behavior_ledger_selected_v1(context)
			and String(context.get("recovery_energy_ledger_profile_id", ""))
			== RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		),
		"production_blueprint_compiled_zero_world": _zero_world_receipt_v1(blueprint),
		"portable_collection_and_control_planned": (
			String(route["collection_receipt"].get("support_status", "")) == "supported_exact"
			and int((route["control_receipt"].get("ordered_commands", []) as Array).size()) == 8
			and _zero_world_receipt_v1(route)
		),
		"production_progression_dispatched": BehaviorWorker.production_advance_receipt_valid_v1(
			advanced, CONTROLLER, sdk, ENERGY_ROUTE
		),
		"production_evaluation_dispatched": BehaviorWorker.production_evaluation_receipt_valid_v1(
			evaluated, CONTROLLER, ENERGY_ROUTE
		),
		"behavior_applications_preserved": (
			R153Worker._initial_application_valid_v1(initial_fixture["initial"])
			and R153Worker._application_valid_v1(applications["active"], false)
			and R153Worker._application_valid_v1(applications["matched_zero"], true)
		),
	}
	var wrong_gate := context.duplicate(true)
	wrong_gate["physical_world_construction_gate_id"] = "QSDK-R24D164"
	var missing_selection := context.duplicate(true)
	missing_selection.erase("rotation_aware_source_trace_validation_selected")
	var wrong_profile := context.duplicate(true)
	wrong_profile["native_source_trace_validator_profile_id"] = "crossed_profile"
	var stale_predecessor := context.duplicate(true)
	stale_predecessor["r164_finite_behavior_context_sha256"] = _zero_sha256()
	var missing_ledger := context.duplicate(true)
	missing_ledger.erase("rotation_aware_energy_ledger_profile_selected")
	var forced_failure_checks := {
		"wrong_gate_refused": _context_refused_v1(sdk, wrong_gate),
		"missing_selection_refused": _context_refused_v1(sdk, missing_selection),
		"wrong_validator_profile_refused": _context_refused_v1(sdk, wrong_profile),
		"stale_r164_context_digest_refused": _context_refused_v1(sdk, stale_predecessor),
		"missing_rotation_ledger_refused": _context_refused_v1(sdk, missing_ledger),
		"legacy_r152_trace_refused_for_r165": (
			not BehaviorWorker.native_source_trace_schema_valid_v1(context, R152_TRACE_SCHEMA)
		),
		"missing_trace_schema_refused": (
			not BehaviorWorker.native_source_trace_schema_valid_v1(context, "")
		),
		"r164_context_not_promoted": (
			not BehaviorWorker.rotation_aware_native_source_trace_validation_selected_v1(
				r164_context
			)
		),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d165_godot_rotation_aware_source_trace_behavior_zero_world_v1",
		"gate_id": GATE_ID,
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D165_ZERO_WORLD_CONJUNCTION_INVALID",
		"status": "passed_zero_world_rotation_aware_native_source_trace_behavior_consumer",
		"question_class": "development",
		"native_source_trace_validator_profile_id": RouteScript.R165_ROTATION_AWARE_SOURCE_TRACE_VALIDATOR_PROFILE_ID,
		"recovery_controller_id": CONTROLLER,
		"actuator_mode": BehaviorWorker.ACTUATOR_MODE_SOLVER_COUPLED,
		"energy_route_id": ENERGY_ROUTE,
		"recovery_energy_ledger_profile_id": RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID,
		"positive_checks": positive_checks,
		"positive_case_count": positive_checks.size(),
		"positive_pass_count": positive_pass_count,
		"forced_failure_checks": forced_failure_checks,
		"forced_failure_case_count": forced_failure_checks.size(),
		"forced_failure_pass_count": forced_failure_pass_count,
		"historical_closure_audits_executed_count": 0,
		"bespoke_physical_canary_count": 0,
		"full_seeded_ghost_count": 0,
		"behavior_evaluator_invocation_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _context_refused_v1(sdk: Object, context: Dictionary) -> bool:
	return not RouteScript.rotation_aware_source_trace_behavior_context_binding_exact_v1(
		sdk, context
	)


static func _zero_world_receipt_v1(value: Dictionary) -> bool:
	return (
		int(value.get("model_construction_count", -1)) == 0
		and int(value.get("world_attempt_count", -1)) == 0
		and int(value.get("world_build_count", -1)) == 0
		and int(value.get("solver_step_count", -1)) == 0
		and not bool(value.get("physics_state_modified", true))
		and not bool(value.get("physical_acceptance_authority", true))
		and not bool(value.get("release_authority", true))
	)


static func _valid_sha256(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _zero_sha256() -> String:
	return "sha256:" + "0".repeat(64)


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Variant = null) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d165_godot_rotation_aware_source_trace_behavior_zero_world_v1",
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"positive_case_count": 11,
		"forced_failure_case_count": 8,
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
