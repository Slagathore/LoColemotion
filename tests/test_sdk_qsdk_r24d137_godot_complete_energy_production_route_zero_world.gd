extends SceneTree
# gdlint: disable=max-line-length

## Compact mutation control for the real R137 production selectors. R136 owns
## the complete partition's detailed controls; this worker checks only the new
## context, dispatch, sampler-representation, and refusal seams.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const BehaviorWorker := preload("res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd")
const R136Fixture := preload(
	"res://tests/test_sdk_qsdk_r24d136_godot_complete_energy_partition_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "SPORESPORE_GODOT_R24D137_COMPLETE_ENERGY_PRODUCTION_ROUTE_ZERO_WORLD "
const COMPLETE_ROUTE := RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID
const CONTROLLER := RouteScript.RECOVERY_CONTROLLER_V6_ID


func _initialize() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D137_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	var context := RouteScript.prepare_complete_energy_context_v2(sdk, CONTROLLER)
	var fixture := _complete_v6_fixture_v1(sdk, context)
	if sdk == null or not bool(context.get("ok", false)) or not bool(fixture.get("ok", false)):
		return _failure(
			"QSDK_R24D137_CONTEXT_OR_FIXTURE_INVALID",
			{"context": context, "fixture": fixture},
		)
	var bound: Dictionary = fixture["bound"]
	var initialized := RouteScript.initialize_behavior_arm_v1(sdk, context, "candidate_command")
	var advanced := BehaviorWorker.production_advance_dispatch_v1(
		sdk,
		context,
		bound,
		initialized.get("memory", {}),
		"candidate_command",
		"confirm_prone",
		CONTROLLER,
		COMPLETE_ROUTE,
	)
	var traces := BehaviorWorker.paired_zero_world_evaluation_traces_v1(sdk, bound)
	var evaluated := BehaviorWorker.production_evaluation_dispatch_v1(
		sdk,
		context,
		traces.get("candidate_trace", {}),
		traces.get("matched_zero_trace", {}),
		CONTROLLER,
		COMPLETE_ROUTE,
	)
	if (
		not bool(initialized.get("ok", false))
		or not bool(advanced.get("ok", false))
		or not bool(traces.get("ok", false))
		or not bool(evaluated.get("ok", false))
	):
		return _failure(
			"QSDK_R24D137_PRODUCTION_ROUTE_FAILED",
			{"advanced": advanced, "evaluated": evaluated},
		)

	var active_wrapper := _complete_wrapper_fixture_v1(false)
	var zero_wrapper := _complete_wrapper_fixture_v1(true)
	var active_sampler := RouteScript.complete_energy_sampler_application_receipt_v1(
		active_wrapper
	)
	var zero_sampler := RouteScript.complete_energy_sampler_application_receipt_v1(zero_wrapper)
	var positive_checks := {
		"route_triplet": BehaviorWorker.actuator_mode_controller_route_triplet_valid_v1(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED,
			CONTROLLER,
			COMPLETE_ROUTE,
		),
		"advance": BehaviorWorker.production_advance_receipt_valid_v1(
			advanced, CONTROLLER, sdk, COMPLETE_ROUTE
		),
		"evaluation": BehaviorWorker.production_evaluation_receipt_valid_v1(
			evaluated, CONTROLLER, COMPLETE_ROUTE
		),
		"sampler_representations": (
			bool(active_sampler.get("ok", false))
			and bool(zero_sampler.get("ok", false))
			and String(active_sampler.get("schema_version", ""))
			== String(active_wrapper.get("predecessor_schema_version", ""))
			and String(zero_sampler.get("schema_version", ""))
			== String(zero_wrapper.get("predecessor_schema_version", ""))
		),
	}

	var wrong_controller := BehaviorWorker.production_advance_dispatch_v1(
		sdk,
		context,
		bound,
		initialized["memory"],
		"candidate_command",
		"confirm_prone",
		RouteScript.RECOVERY_CONTROLLER_V5_ID,
		COMPLETE_ROUTE,
	)
	var mutated_advance := advanced.duplicate(true)
	mutated_advance["production_advance_dispatch_id"] = "mutated"
	var mutated_evaluation := evaluated.duplicate(true)
	mutated_evaluation["production_evaluation_dispatch_id"] = "mutated"
	var wrong_predecessor := active_wrapper.duplicate(true)
	wrong_predecessor["predecessor_schema_version"] = "mutated"
	var motor_enabled := active_wrapper.duplicate(true)
	motor_enabled["motor_enabled_count"] = 1
	var forced_failure_checks := {
		"solver_mode": not BehaviorWorker.actuator_mode_controller_route_triplet_valid_v1(
			BehaviorWorker.ACTUATOR_MODE_SOLVER_COUPLED, CONTROLLER, COMPLETE_ROUTE
		),
		"controller": not bool(wrong_controller.get("ok", true)),
		"advance": not BehaviorWorker.production_advance_receipt_valid_v1(
			mutated_advance, CONTROLLER, sdk, COMPLETE_ROUTE
		),
		"evaluation": not BehaviorWorker.production_evaluation_receipt_valid_v1(
			mutated_evaluation, CONTROLLER, COMPLETE_ROUTE
		),
		"predecessor": not bool(
			RouteScript.complete_energy_sampler_application_receipt_v1(wrong_predecessor).get(
				"ok", true
			)
		),
		"native_motor": not bool(
			RouteScript.complete_energy_sampler_application_receipt_v1(motor_enabled).get(
				"ok", true
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
		"schema_version": "sporespore_qsdk_r24d137_godot_complete_energy_production_route_zero_world_v1",
		"gate_id": "QSDK-R24D137",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_complete_energy_production_route_zero_world",
			"question_class": "development",
		},
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D137_ZERO_WORLD_CONJUNCTION_INVALID",
		"positive_checks": positive_checks,
		"positive_case_count": positive_checks.size(),
		"positive_pass_count": positive_pass_count,
		"forced_failure_checks": forced_failure_checks,
		"forced_failure_case_count": forced_failure_checks.size(),
		"forced_failure_pass_count": forced_failure_pass_count,
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


static func _complete_v6_fixture_v1(sdk: Object, context: Dictionary) -> Dictionary:
	var solver := WorldScript.native_solver_energy_exchange_contract_v1(
		R136Fixture._solver_telemetry_v1(), 7, Vector3(0.0, -9.81, 0.0)
	)
	var partition := WorldScript.complete_energy_partition_inputs_contract_v1(
		R136Fixture._partition_inputs_v1(true)
	)
	var energy := R136Fixture._complete_fixture_v1(sdk, context, solver, partition)
	var predecessor := RouteScript._zero_world_fixture_for_controller_v1(
		sdk, context, CONTROLLER
	)
	if not bool(energy.get("ok", false)) or not bool(predecessor.get("ok", false)):
		return {"ok": false, "energy": energy, "predecessor": predecessor}
	var base: Dictionary = (predecessor["observation_v3"] as Dictionary).duplicate(true)
	base.erase("schema_version")
	base.erase("energy_balance")
	var bound := RouteScript.compose_complete_energy_observations_v1(
		sdk, context, base, energy["energy_source_receipt"], energy["source_component_receipts"]
	)
	return {"ok": bool(bound.get("ok", false)), "bound": bound}


static func _complete_wrapper_fixture_v1(no_actuation: bool) -> Dictionary:
	var receipt := R136Fixture._application_receipt_v1(no_actuation)
	receipt["predecessor_schema_version"] = receipt["schema_version"]
	receipt["schema_version"] = "sporespore_qsdk_r24d136_godot_complete_energy_command_application_receipt_v1"
	receipt.merge(
		{
			"complete_energy_profile_selected": true,
			"energy_route_id": COMPLETE_ROUTE,
			"energy_mapping_profile_id": RouteScript.R136_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
			"no_actuation_requested": no_actuation,
			"native_joint_motors_disabled": true,
			"hard_constraint_motor_disabled_count": 8,
			"constraint_exchange_source_owned_by_native_solver_telemetry": true,
			"actuator_work_source_owned_by_r109_application": not no_actuation,
			"adapter_side_discrete_staging_event_count": 0,
		},
		true,
	)
	if no_actuation:
		receipt.merge(
			{"actuator_mapping_id": "", "work_mapping_id": "", "structural_zero_actuator_work": true},
			true,
		)
	return receipt


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Variant = null) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d137_godot_complete_energy_production_route_zero_world_v1",
		"gate_id": "QSDK-R24D137",
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"positive_case_count": 4,
		"forced_failure_case_count": 6,
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
