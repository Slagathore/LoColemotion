extends SceneTree
# gdlint: disable=max-line-length

## Compact R154 correction control. It invokes the exact production context
## selector and the pure event-count predicate called by the in-run behavior
## validator. No model, world, native readback, or solver step is constructed.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "SPORESPORE_GODOT_R24D154_ACCUMULATOR_AWARE_INVARIANT_VALIDATOR_ZERO_WORLD "
const GATE_ID := "QSDK-R24D154"
const CONTROLLER := RouteScript.RECOVERY_CONTROLLER_V6_ID
const ENERGY_ROUTE := RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
const LEGACY_ROUTE := RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate_v1()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate_v1() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D154_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D154_SDK_INSTANTIATION_FAILED")
	var context := BehaviorWorker.prepare_behavior_context_v1(
		sdk,
		CONTROLLER,
		ENERGY_ROUTE,
		GATE_ID,
	)
	var r153_context := BehaviorWorker.prepare_behavior_context_v1(
		sdk,
		CONTROLLER,
		ENERGY_ROUTE,
		"QSDK-R24D153",
	)
	if not bool(context.get("ok", false)) or not bool(r153_context.get("ok", false)):
		return _failure(
			"QSDK_R24D154_CONTEXT_PREPARATION_INVALID",
			{"context": context, "r153_context": r153_context},
		)
	var positive_checks := {
		"exact_r154_context": (
			String(context.get("schema_version", ""))
			== "sporespore_qsdk_r24d154_godot_accumulator_aware_discrete_staging_behavior_context_v10"
			and String(context.get("physical_world_construction_gate_id", "")) == GATE_ID
			and bool(context.get("finite_behavior_pair_selected", false))
		),
		"route_aware_provenance_preserved": (
			BehaviorWorker.route_aware_application_provenance_selected_v1(context)
		),
		"accumulator_aware_validator_selected": (
			BehaviorWorker.accumulator_aware_invariant_validation_selected_v1(context)
		),
		"successive_step_one_count_accepted": _count_valid(context, ENERGY_ROUTE, 1, 1),
		"successive_step_two_count_accepted": _count_valid(context, ENERGY_ROUTE, 2, 2),
		"legacy_r153_step_one_semantics_preserved": _count_valid(
			r153_context,
			ENERGY_ROUTE,
			1,
			1,
		),
		"legacy_r153_step_two_semantics_preserved": not _count_valid(
			r153_context,
			ENERGY_ROUTE,
			2,
			2,
		),
		"non_staging_zero_count_preserved": _count_valid(context, LEGACY_ROUTE, 2, 0),
		"r154_invariant_schema_selected": (
			BehaviorWorker.complete_energy_invariant_schema_v3(ENERGY_ROUTE, context)
			== "sporespore_qsdk_r24d154_godot_accumulator_aware_discrete_staging_complete_energy_in_run_invariant_receipt_v2"
		),
	}
	var missing_selection := context.duplicate(true)
	missing_selection.erase("accumulator_aware_invariant_validation_selected")
	var wrong_profile := context.duplicate(true)
	wrong_profile["in_run_invariant_validator_profile_id"] = "crossed_profile"
	var wrong_gate := context.duplicate(true)
	wrong_gate["physical_world_construction_gate_id"] = "QSDK-R24D153"
	var forced_failure_checks := {
		"missing_accumulator_selection_refused": not (
			BehaviorWorker.accumulator_aware_invariant_validation_selected_v1(missing_selection)
		),
		"wrong_validator_profile_refused": not (
			BehaviorWorker.accumulator_aware_invariant_validation_selected_v1(wrong_profile)
		),
		"crossed_gate_refused": not (
			BehaviorWorker.accumulator_aware_invariant_validation_selected_v1(wrong_gate)
		),
		"step_two_stale_count_refused": not _count_valid(context, ENERGY_ROUTE, 2, 1),
		"step_two_future_count_refused": not _count_valid(context, ENERGY_ROUTE, 2, 3),
		"step_one_future_count_refused": not _count_valid(context, ENERGY_ROUTE, 1, 2),
		"nonpositive_semantic_step_refused": not _count_valid(context, ENERGY_ROUTE, 0, 0),
		"non_staging_nonzero_count_refused": not _count_valid(context, LEGACY_ROUTE, 2, 1),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d154_godot_accumulator_aware_invariant_validator_zero_world_v1",
		"gate_id": GATE_ID,
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_accumulator_aware_invariant_validator_zero_world",
			"question_class": "development",
		},
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D154_ZERO_WORLD_CONJUNCTION_INVALID",
		"recovery_controller_id": CONTROLLER,
		"actuator_mode": BehaviorWorker.ACTUATOR_MODE_SOLVER_COUPLED,
		"energy_route_id": ENERGY_ROUTE,
		"application_provenance_profile_id": RouteScript.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID,
		"in_run_invariant_validator_profile_id": RouteScript.R154_ACCUMULATOR_AWARE_INVARIANT_VALIDATOR_PROFILE_ID,
		"positive_checks": positive_checks,
		"positive_case_count": positive_checks.size(),
		"positive_pass_count": positive_pass_count,
		"forced_failure_checks": forced_failure_checks,
		"forced_failure_case_count": forced_failure_checks.size(),
		"forced_failure_pass_count": forced_failure_pass_count,
		"historical_closure_audits_executed_count": 0,
		"bespoke_physical_canary_count": 0,
		"full_seeded_ghost_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _count_valid(
	context: Dictionary,
	energy_route_id: String,
	semantic_step: int,
	observed_event_count: int,
) -> bool:
	return BehaviorWorker.adapter_side_discrete_staging_event_count_valid_v2(
		context,
		energy_route_id,
		semantic_step,
		observed_event_count,
	)


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Variant = null) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d154_godot_accumulator_aware_invariant_validator_zero_world_v1",
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
