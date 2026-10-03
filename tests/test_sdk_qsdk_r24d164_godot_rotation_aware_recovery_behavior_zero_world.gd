extends SceneTree
# gdlint: disable=max-line-length

## Compact R164 finite-behavior qualification. It combines the exact R154
## accumulator-aware behavior consumer with the R162 ledger and R163-commissioned
## production route, then reaches collection, planning, progression, evaluation,
## and application through synthetic source-bound fixtures. No Node, RID, model,
## world, native read, body write, behavior evaluator, or solver step is opened.

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
const MARKER := "QSDK_R24D164_GODOT_ROTATION_AWARE_RECOVERY_BEHAVIOR_ZERO_WORLD "
const GATE_ID := "QSDK-R24D164"
const CONTROLLER := RouteScript.RECOVERY_CONTROLLER_V6_ID
const ENERGY_ROUTE := RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
const LEGACY_COLLECTOR_ID := (
	"sporespore_godot_jolt_discrete_staging_complete_energy_v4_recovery_collector_v1"
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
		return _failure("QSDK_R24D164_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D164_SDK_INSTANTIATION_FAILED")
	var context := BehaviorWorker.prepare_behavior_context_v1(
		sdk, CONTROLLER, ENERGY_ROUTE, GATE_ID
	)
	if not bool(context.get("ok", false)):
		return _failure(
			"QSDK_R24D164_CONTEXT_PREPARATION_INVALID",
			{"context": context},
		)
	var blueprint := RouteScript.native_world_blueprint_v1(sdk, context)
	var fixture := R163Worker._rotation_aware_bound_fixture_v1(sdk, context)
	if not bool(blueprint.get("ok", false)) or not bool(fixture.get("ok", false)):
		return _failure(
			"QSDK_R24D164_BLUEPRINT_OR_FIXTURE_INVALID",
			{"blueprint": blueprint, "fixture": fixture},
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
	var applications := R151Worker._application_fixtures_v1(
		sdk, context, bound, true
	)
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
			"QSDK_R24D164_PRODUCTION_PATH_INVALID",
			{
				"route": route,
				"initialized": initialized,
				"advanced": advanced,
				"evaluated": evaluated,
				"applications": applications,
				"initial_fixture": initial_fixture,
			},
		)
	var collection: Dictionary = route["collection_receipt"]
	var control: Dictionary = route["control_receipt"]
	var mapping: Dictionary = bound["native_to_portable_staging_mapping"]
	var active: Dictionary = applications["active"]
	var matched_zero: Dictionary = applications["matched_zero"]
	var initial: Dictionary = initial_fixture["initial"]
	var positive_checks := {
		"exact_r164_finite_context": (
			RouteScript.rotation_aware_finite_behavior_context_binding_exact_v1(sdk, context)
			and String(context.get("physical_world_construction_gate_id", "")) == GATE_ID
			and bool(context.get("finite_behavior_pair_selected", false))
			and bool(context.get("recovery_behavior_evaluation_authorized", false))
			and not context.has("route_ghost_only")
		),
		"r163_route_context_content_bound": _valid_sha256(
			String(context.get("r163_route_ghost_context_sha256", ""))
		),
		"r154_accumulator_validator_preserved": (
			BehaviorWorker.accumulator_aware_invariant_validation_selected_v1(context)
			and BehaviorWorker.complete_energy_invariant_schema_v4(ENERGY_ROUTE, context)
			== "sporespore_qsdk_r24d164_godot_rotation_aware_recovery_behavior_in_run_invariant_receipt_v1"
		),
		"route_aware_application_provenance_preserved": (
			BehaviorWorker.route_aware_application_provenance_selected_v1(context)
		),
		"rotation_aware_behavior_ledger_selected": (
			BehaviorWorker.rotation_aware_behavior_ledger_selected_v1(context)
			and String(context.get("recovery_energy_ledger_profile_id", ""))
			== RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		),
		"production_blueprint_compiled_zero_world": _zero_world_receipt_v1(blueprint),
		"rotation_aware_mapping_bound": (
			String(mapping.get("schema_version", ""))
			== "sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_step_mapping_v1"
			and String(mapping.get("recovery_energy_ledger_profile_id", ""))
			== RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
			and bool(mapping.get("rotation_integration_exchange_included_exactly_once", false))
		),
		"portable_collection_supported_exact": (
			String(collection.get("support_status", "")) == "supported_exact"
			and String(collection.get("collector_id", ""))
			== RouteScript.R162_ROTATION_AWARE_COLLECTOR_ID
		),
		"portable_control_planned": (
			String(control.get("support_status", "")) == "supported_exact"
			and int((control.get("ordered_commands", []) as Array).size()) == 8
			and _zero_world_receipt_v1(route)
		),
		"production_progression_dispatched": BehaviorWorker.production_advance_receipt_valid_v1(
			advanced, CONTROLLER, sdk, ENERGY_ROUTE
		),
		"production_evaluation_dispatched": BehaviorWorker.production_evaluation_receipt_valid_v1(
			evaluated, CONTROLLER, ENERGY_ROUTE
		),
		"behavior_applications_preserved": (
			R153Worker._initial_application_valid_v1(initial)
			and R153Worker._application_valid_v1(active, false)
			and R153Worker._application_valid_v1(matched_zero, true)
		),
	}
	var wrong_gate := context.duplicate(true)
	wrong_gate["physical_world_construction_gate_id"] = "QSDK-R24D163"
	var missing_pair := context.duplicate(true)
	missing_pair.erase("finite_behavior_pair_selected")
	var missing_evaluation := context.duplicate(true)
	missing_evaluation["recovery_behavior_evaluation_authorized"] = false
	var leaked_ghost := context.duplicate(true)
	leaked_ghost["route_ghost_only"] = true
	var wrong_profile := context.duplicate(true)
	wrong_profile["finite_behavior_profile_id"] = "crossed_profile"
	var stale_predecessor := context.duplicate(true)
	stale_predecessor["r163_route_ghost_context_sha256"] = _zero_sha256()
	var missing_accumulator := context.duplicate(true)
	missing_accumulator.erase("accumulator_aware_invariant_validation_selected")
	var forced_failure_checks := {
		"wrong_gate_refused": _context_refused_v1(sdk, wrong_gate),
		"missing_behavior_pair_refused": _context_refused_v1(sdk, missing_pair),
		"missing_evaluation_authority_refused": _context_refused_v1(sdk, missing_evaluation),
		"route_ghost_leak_refused": _context_refused_v1(sdk, leaked_ghost),
		"crossed_behavior_profile_refused": _context_refused_v1(sdk, wrong_profile),
		"stale_r163_context_digest_refused": _context_refused_v1(sdk, stale_predecessor),
		"missing_accumulator_validator_refused": (
			_context_refused_v1(sdk, missing_accumulator)
			and not BehaviorWorker.accumulator_aware_invariant_validation_selected_v1(
				missing_accumulator
			)
		),
		"missing_rotation_source_refused": R163Worker._source_mutation_refused_v1(
			sdk, context, fixture, "missing_rotation"
		),
		"legacy_collector_cross_refused": R163Worker._core_context_refused_v1(
			sdk,
			context,
			bound,
			"collector_id",
			LEGACY_COLLECTOR_ID,
			"collector_or_runtime_profile_identity_invalid",
		),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d164_godot_rotation_aware_recovery_behavior_zero_world_v1",
		"gate_id": GATE_ID,
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D164_ZERO_WORLD_CONJUNCTION_INVALID",
		"status": "passed_zero_world_rotation_aware_finite_recovery_behavior",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_rotation_aware_finite_recovery_behavior_zero_world",
			"question_class": "development",
		},
		"question_class": "development",
		"finite_behavior_profile_id": RouteScript.R164_ROTATION_AWARE_FINITE_BEHAVIOR_PROFILE_ID,
		"recovery_controller_id": CONTROLLER,
		"actuator_mode": BehaviorWorker.ACTUATOR_MODE_SOLVER_COUPLED,
		"energy_route_id": ENERGY_ROUTE,
		"recovery_energy_ledger_profile_id": RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID,
		"in_run_invariant_validator_profile_id": RouteScript.R154_ACCUMULATOR_AWARE_INVARIANT_VALIDATOR_PROFILE_ID,
		"application_provenance_profile_id": RouteScript.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID,
		"production_advance_dispatch_id": BehaviorWorker.R151_PRODUCTION_ADVANCE_DISPATCH_ID,
		"production_evaluation_dispatch_id": BehaviorWorker.R151_PRODUCTION_EVALUATION_DISPATCH_ID,
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
	return not RouteScript.rotation_aware_finite_behavior_context_binding_exact_v1(
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
		"schema_version": "sporespore_qsdk_r24d164_godot_rotation_aware_recovery_behavior_zero_world_v1",
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"positive_case_count": 12,
		"forced_failure_case_count": 9,
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
