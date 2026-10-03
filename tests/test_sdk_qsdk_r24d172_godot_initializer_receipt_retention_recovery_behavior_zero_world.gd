extends SceneTree
# gdlint: disable=max-line-length

## R172 declares one finite behavior successor over R171-qualified initializer
## receipt retention. It preserves R170's exact physical question under a new
## identity. This worker uses synthetic boundaries and portable calls only: no
## Node, RID, model, world, native read, body write, behavior evaluator
## invocation, or solver step is created.

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
const R169Worker := preload(
	"res://tests/test_sdk_qsdk_r24d169_godot_contiguous_boundary_route_ghost_zero_world.gd"
)
const StagingRoute := preload(
	"res://sdk/adapters/godot/gdscript/recovery_discrete_staging_route_v1.gd"
)
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := (
	"QSDK_R24D172_GODOT_INITIALIZER_RECEIPT_RETENTION_RECOVERY_BEHAVIOR_ZERO_WORLD "
)
const GATE_ID := "QSDK-R24D172"
const CONTROLLER := RouteScript.RECOVERY_CONTROLLER_V6_ID
const ENERGY_ROUTE := RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
const SOLVER_STEP_S := 1.0 / 120.0
const EXPECTED_INVARIANT_SCHEMA := (
	"sporespore_qsdk_r24d165_godot_rotation_aware_source_trace_behavior_in_run_invariant_receipt_v1"
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
		return _failure("QSDK_R24D172_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D172_SDK_INSTANTIATION_FAILED")

	var predecessor_context := RouteScript.prepare_complete_energy_context_v14(
		sdk, CONTROLLER
	)
	var route_ghost_context := RouteScript.prepare_complete_energy_context_v16(
		sdk, CONTROLLER
	)
	var r170_context := RouteScript.prepare_complete_energy_context_v17(
		sdk, CONTROLLER
	)
	var context := BehaviorWorker.prepare_behavior_context_v1(
		sdk, CONTROLLER, ENERGY_ROUTE, GATE_ID
	)
	if (
		not bool(predecessor_context.get("ok", false))
		or not bool(route_ghost_context.get("ok", false))
		or not bool(r170_context.get("ok", false))
		or not bool(context.get("ok", false))
		or not RouteScript.contiguous_boundary_recovery_behavior_context_binding_exact_v1(
			sdk, context
		)
	):
		return _failure(
			"QSDK_R24D172_CONTEXT_INVALID",
			{
				"predecessor": predecessor_context,
				"route_ghost": route_ghost_context,
				"r170_context": r170_context,
				"context": context,
			},
		)

	var blueprint := RouteScript.native_world_blueprint_v1(sdk, context)
	var transport := R169Worker._transport_sequence_v1(sdk)
	if (
		not bool(blueprint.get("ok", false))
		or not bool(transport.get("ok", false))
	):
		return _failure(
			"QSDK_R24D172_BLUEPRINT_OR_TRANSPORT_INVALID",
			{"blueprint": blueprint, "transport": transport},
		)
	var pair_one: Dictionary = transport["pair_one"]
	var observer := (
		StagingRoute
		. measure_native_step_v1(
			1,
			0,
			SOLVER_STEP_S,
			(pair_one["ordered_body_boundaries"] as Array).duplicate(true),
			Vector3.ZERO,
		)
	)
	var fixture := R169Worker._rotation_aware_bound_fixture_v1(sdk, context, observer)
	if not bool(observer.get("ok", false)) or not bool(fixture.get("ok", false)):
		return _failure(
			"QSDK_R24D172_OBSERVER_OR_BOUND_FIXTURE_INVALID",
			{"observer": observer, "fixture": fixture},
		)
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
			"QSDK_R24D172_PRODUCTION_PATH_INVALID",
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

	var mapping: Dictionary = bound["native_to_portable_staging_mapping"]
	var state_two: Dictionary = transport["state_two"]
	var positive_checks := {
		"exact_r172_behavior_context": (
			RouteScript.contiguous_boundary_recovery_behavior_context_binding_exact_v1(
				sdk, context
			)
			and _valid_sha256(String(context.get("r165_behavior_context_sha256", "")))
		),
		"consumed_r170_behavior_context_bound": (
			_sha256(sdk, r170_context)
			== String(context.get("r170_behavior_context_sha256", ""))
			and _valid_sha256(String(context.get("r170_behavior_context_sha256", "")))
		),
		"consumed_r170_physical_closure_bound_without_outcome_input": (
			String(context.get("r170_physical_closure_raw_sha256", ""))
			== RouteScript.R172_R170_PHYSICAL_CLOSURE_RAW_SHA256
		),
		"r171_initializer_receipt_retention_qualification_bound": (
			String(
				context.get("r171_initializer_receipt_retention_closure_raw_sha256", "")
			)
			== RouteScript.R172_R171_ZERO_WORLD_CLOSURE_RAW_SHA256
		),
		"consumed_r165_behavior_context_bound": (
			_sha256(sdk, predecessor_context)
			== String(context.get("r165_behavior_context_sha256", ""))
			and String(context.get("r165_physical_closure_raw_sha256", ""))
			== RouteScript.R170_R165_PHYSICAL_CLOSURE_RAW_SHA256
		),
		"consumed_r169_route_closure_bound": (
			String(context.get("r169_route_ghost_physical_closure_raw_sha256", ""))
			== RouteScript.R170_R169_PHYSICAL_CLOSURE_RAW_SHA256
			and RouteScript.contiguous_boundary_transport_route_ghost_context_binding_exact_v1(
				sdk, route_ghost_context
			)
		),
		"exact_transport_profile_selected": (
			bool(context.get("contiguous_boundary_transport_profile_selected", false))
			and not bool(context.get("legacy_aliased_boundary_transport_selected", true))
			and String(context.get("contiguous_boundary_transport_profile_id", ""))
			== RouteScript.R168_CONTIGUOUS_BOUNDARY_TRANSPORT_PROFILE_ID
		),
		"inactive_initializer_and_two_contiguous_pairs": (
			int(transport["state_zero"].get("cached_boundary_sequence", -1)) == 0
			and int(state_two.get("cached_boundary_sequence", -1)) == 2
			and int(state_two.get("accepted_pair_count", -1)) == 2
			and int(state_two.get("state_revision", -1)) == 2
		),
		"rotation_aware_mapping_preserved": (
			bool(mapping.get("rotation_integration_exchange_included_exactly_once", false))
			and BehaviorWorker.rotation_aware_native_source_trace_validation_selected_v1(
				context
			)
			and BehaviorWorker.complete_energy_invariant_schema_v5(
				ENERGY_ROUTE, context
			)
			== EXPECTED_INVARIANT_SCHEMA
		),
		"production_blueprint_compiled_zero_world": _zero_world_receipt_v1(blueprint),
		"portable_collection_and_control_planned": (
			String(route["collection_receipt"].get("support_status", "")) == "supported_exact"
			and int((route["control_receipt"].get("ordered_commands", []) as Array).size()) == 8
			and _zero_world_receipt_v1(route)
		),
		"production_progression_and_evaluation_dispatched": (
			BehaviorWorker.production_advance_receipt_valid_v1(
				advanced, CONTROLLER, sdk, ENERGY_ROUTE
			)
			and BehaviorWorker.production_evaluation_receipt_valid_v1(
				evaluated, CONTROLLER, ENERGY_ROUTE
			)
		),
		"behavior_applications_preserved": (
			R153Worker._initial_application_valid_v1(initial_fixture["initial"])
			and R153Worker._application_valid_v1(applications["active"], false)
			and R153Worker._application_valid_v1(applications["matched_zero"], true)
		),
	}
	var forced_failure_checks := {
		"wrong_gate_refused": _context_mutation_refused_v1(
			sdk, context, "physical_world_construction_gate_id", "QSDK-R24D169"
		),
		"stale_r170_context_digest_refused": _context_mutation_refused_v1(
			sdk, context, "r170_behavior_context_sha256", _filled_sha256("3")
		),
		"crossed_r170_physical_closure_refused": _context_mutation_refused_v1(
			sdk, context, "r170_physical_closure_raw_sha256", _filled_sha256("4")
		),
		"crossed_r171_qualification_closure_refused": _context_mutation_refused_v1(
			sdk,
			context,
			"r171_initializer_receipt_retention_closure_raw_sha256",
			_filled_sha256("5"),
		),
		"stale_r165_context_digest_refused": _context_mutation_refused_v1(
			sdk, context, "r165_behavior_context_sha256", _filled_sha256("0")
		),
		"crossed_r165_closure_refused": _context_mutation_refused_v1(
			sdk, context, "r165_physical_closure_raw_sha256", _filled_sha256("1")
		),
		"crossed_r169_closure_refused": _context_mutation_refused_v1(
			sdk,
			context,
			"r169_route_ghost_physical_closure_raw_sha256",
			_filled_sha256("2"),
		),
		"transport_selection_removed": _context_mutation_refused_v1(
			sdk, context, "contiguous_boundary_transport_profile_selected", false
		),
		"transport_design_crossed": _context_mutation_refused_v1(
			sdk, context, "contiguous_boundary_transport_design_id", "crossed_design"
		),
		"transport_profile_crossed": _context_mutation_refused_v1(
			sdk,
			context,
			"contiguous_boundary_transport_profile_id",
			RouteScript.R149_LIVE_BOUNDARY_TRANSPORT_ID,
		),
		"legacy_transport_selected": _context_mutation_refused_v1(
			sdk, context, "legacy_aliased_boundary_transport_selected", true
		),
		"behavior_profile_crossed": _context_mutation_refused_v1(
			sdk, context, "contiguous_boundary_behavior_profile_id", "crossed_profile"
		),
		"behavior_evaluation_removed": _context_mutation_refused_v1(
			sdk, context, "recovery_behavior_evaluation_authorized", false
		),
		"source_trace_validator_removed": _context_mutation_refused_v1(
			sdk, context, "rotation_aware_source_trace_validation_selected", false
		),
		"matched_zero_population_removed": _context_mutation_refused_v1(
			sdk, context, "finite_behavior_pair_selected", false
		),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version": (
			"sporespore_qsdk_r24d172_godot_initializer_receipt_retention_recovery_behavior_zero_world_v1"
		),
		"gate_id": GATE_ID,
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D172_ZERO_WORLD_CONJUNCTION_INVALID",
		"status": "passed_zero_world_initializer_retention_recovery_behavior_declaration",
		"question_class": "development",
		"behavior_profile_id": RouteScript.R172_INITIALIZER_RETENTION_RECOVERY_BEHAVIOR_PROFILE_ID,
		"transport_design_id": String(context.get("contiguous_boundary_transport_design_id", "")),
		"transport_profile_id": String(context.get("contiguous_boundary_transport_profile_id", "")),
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


static func _context_mutation_refused_v1(
	sdk: Object,
	context: Dictionary,
	key: String,
	value: Variant,
) -> bool:
	var mutation := context.duplicate(true)
	mutation[key] = value
	return not RouteScript.contiguous_boundary_recovery_behavior_context_binding_exact_v1(
		sdk, mutation
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


static func _sha256(sdk: Object, value: Variant) -> String:
	return String(RecoveryRuntimeScript.canonicalize(sdk, value).get("sha256", ""))


static func _valid_sha256(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _filled_sha256(character: String) -> String:
	return "sha256:" + character.repeat(64)


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": (
			"sporespore_qsdk_r24d172_godot_initializer_receipt_retention_recovery_behavior_zero_world_v1"
		),
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"positive_case_count": 13,
		"forced_failure_case_count": 15,
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

