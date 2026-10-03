extends SceneTree
# gdlint: disable=max-line-length

## Compact mutation control for the real R146 behavior selectors. R144 owns
## the detailed partition controls and R145 owns the physical route ghost;
## this worker proves only that the shared full-behavior worker binds that
## route through context, advance, application, and evaluation without a
## model, world, native readback, or solver step.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const BehaviorWorker := preload("res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd")
const R129Worker := preload(
	"res://tests/test_sdk_qsdk_r24d129_godot_solver_coupled_application_mutation_zero_world.gd"
)
const R144Worker := preload(
	"res://tests/test_sdk_qsdk_r24d144_godot_solver_coupled_complete_energy_partition_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := (
	"SPORESPORE_GODOT_R24D146_SOLVER_COUPLED_COMPLETE_ENERGY_BEHAVIOR_ROUTE_ZERO_WORLD "
)
const ACTUATOR_MODE := BehaviorWorker.ACTUATOR_MODE_SOLVER_COUPLED
const CONTROLLER := RouteScript.RECOVERY_CONTROLLER_V6_ID
const ENERGY_ROUTE := RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D146_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D146_SDK_INSTANTIATION_FAILED")
	var context := RouteScript.prepare_complete_energy_context_v3(sdk, CONTROLLER)
	var fixture := _bound_fixture_v1(sdk, context)
	if not bool(context.get("ok", false)) or not bool(fixture.get("ok", false)):
		return _failure(
			"QSDK_R24D146_CONTEXT_OR_FIXTURE_INVALID",
			{"context": context, "fixture": fixture},
		)
	var bound: Dictionary = fixture["bound"]
	var initialized := RouteScript.initialize_behavior_arm_v1(
		sdk,
		context,
		"candidate_command",
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
	var applications := _application_fixtures_v1(sdk, context, bound)
	if (
		not bool(initialized.get("ok", false))
		or not bool(advanced.get("ok", false))
		or not bool(traces.get("ok", false))
		or not bool(evaluated.get("ok", false))
		or not bool(applications.get("ok", false))
	):
		return _failure(
			"QSDK_R24D146_PRODUCTION_ROUTE_FAILED",
			{
				"advanced": advanced,
				"evaluated": evaluated,
				"applications": applications,
			},
		)

	var active_application: Dictionary = applications["active"]
	var zero_application: Dictionary = applications["matched_zero"]
	var positive_checks := {
		"route_triplet": BehaviorWorker.actuator_mode_controller_route_triplet_valid_v1(
			ACTUATOR_MODE,
			CONTROLLER,
			ENERGY_ROUTE,
		),
		"advance": BehaviorWorker.production_advance_receipt_valid_v1(
			advanced,
			CONTROLLER,
			sdk,
			ENERGY_ROUTE,
		),
		"evaluation": BehaviorWorker.production_evaluation_receipt_valid_v1(
			evaluated,
			CONTROLLER,
			ENERGY_ROUTE,
		),
		"active_application": BehaviorWorker.behavior_application_receipt_valid_v3(
			ACTUATOR_MODE,
			active_application,
			false,
			ENERGY_ROUTE,
		),
		"matched_zero_application": BehaviorWorker.behavior_application_receipt_valid_v3(
			ACTUATOR_MODE,
			zero_application,
			true,
			ENERGY_ROUTE,
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
		ENERGY_ROUTE,
	)
	var mutated_context := context.duplicate(true)
	mutated_context["solver_coupled_complete_energy_profile_selected"] = false
	var wrong_context := BehaviorWorker.production_advance_dispatch_v1(
		sdk,
		mutated_context,
		bound,
		initialized["memory"],
		"candidate_command",
		"confirm_prone",
		CONTROLLER,
		ENERGY_ROUTE,
	)
	var mutated_advance := advanced.duplicate(true)
	mutated_advance["production_advance_dispatch_id"] = "mutated"
	var mutated_evaluation := evaluated.duplicate(true)
	mutated_evaluation["production_evaluation_dispatch_id"] = "mutated"
	var mutated_application := active_application.duplicate(true)
	mutated_application["partition_rule_id"] = "mutated"
	var forced_failure_checks := {
		"force_based_mode_refused": not BehaviorWorker.actuator_mode_controller_route_triplet_valid_v1(
			BehaviorWorker.ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED,
			CONTROLLER,
			ENERGY_ROUTE,
		),
		"wrong_controller_refused": not bool(wrong_controller.get("ok", true)),
		"wrong_context_profile_refused": not bool(wrong_context.get("ok", true)),
		"mutated_advance_refused": not BehaviorWorker.production_advance_receipt_valid_v1(
			mutated_advance,
			CONTROLLER,
			sdk,
			ENERGY_ROUTE,
		),
		"mutated_evaluation_refused": not BehaviorWorker.production_evaluation_receipt_valid_v1(
			mutated_evaluation,
			CONTROLLER,
			ENERGY_ROUTE,
		),
		"mutated_application_refused": not BehaviorWorker.behavior_application_receipt_valid_v3(
			ACTUATOR_MODE,
			mutated_application,
			false,
			ENERGY_ROUTE,
		),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d146_godot_solver_coupled_complete_energy_behavior_route_zero_world_v1",
		"gate_id": "QSDK-R24D146",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_solver_coupled_complete_energy_behavior_route_zero_world",
			"question_class": "development",
		},
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D146_ZERO_WORLD_CONJUNCTION_INVALID",
		"recovery_controller_id": CONTROLLER,
		"actuator_mode": ACTUATOR_MODE,
		"energy_route_id": ENERGY_ROUTE,
		"energy_mapping_profile_id": RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"actuation_realization_id": RouteScript.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID,
		"actuator_mapping_id": RouteScript.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID,
		"work_mapping_id": RouteScript.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID,
		"partition_rule_id": RouteScript.R144_PARTITION_RULE_ID,
		"production_advance_dispatch_id": BehaviorWorker.R146_PRODUCTION_ADVANCE_DISPATCH_ID,
		"production_evaluation_dispatch_id": BehaviorWorker.R146_PRODUCTION_EVALUATION_DISPATCH_ID,
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
		"body_impulse_write_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _bound_fixture_v1(sdk: Object, context: Dictionary) -> Dictionary:
	var solver := WorldScript.native_solver_energy_exchange_contract_v1(
		R144Worker._solver_telemetry_v1(),
		R144Worker.SPACE_STEP_SEQUENCE,
		Vector3(0.0, -9.81, 0.0),
	)
	var inputs := WorldScript.solver_coupled_complete_energy_partition_inputs_contract_v1(
		R144Worker._partition_inputs_v1(false)
	)
	var partition := WorldScript.solver_coupled_complete_energy_partition_contract_v1(
		solver,
		R144Worker._motor_receipts_v1(false),
		R144Worker.ACTIVE_STEP_MOTOR_WORK_J,
		R144Worker.SPACE_STEP_SEQUENCE,
		WorldScript.solver_coupled_complete_energy_partition_declaration_v1(),
	)
	if (
		not bool(solver.get("ok", false))
		or not bool(inputs.get("ok", false))
		or not bool(partition.get("ok", false))
	):
		return {"ok": false}
	return R144Worker._complete_fixture_v1(
		sdk,
		context,
		solver,
		inputs,
		partition,
	)


static func _application_fixtures_v1(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
) -> Dictionary:
	var planned := RouteScript.collect_and_plan_v1(
		sdk,
		context,
		bound,
		"raise_body",
		0,
	)
	var surface := RouteScript.zero_world_command_surface_v1(context)
	if not bool(planned.get("ok", false)) or not bool(surface.get("ok", false)):
		return {"ok": false, "planned": planned, "surface": surface}
	var model := {
		"complete_energy_profile_selected": true,
		"solver_coupled_complete_energy_profile_selected": true,
		"joint_by_actuator_id": surface["joint_by_actuator_id"],
	}
	var active := RouteScript.apply_behavior_control_solver_coupled_complete_energy_v1(
		sdk,
		planned["control_receipt"],
		model,
		surface["position_by_joint_id"],
		true,
	)
	var matched_zero := (
		RouteScript.apply_behavior_control_solver_coupled_complete_energy_v1(
			sdk,
			R129Worker._matched_zero_control_v6(),
			model,
			surface["position_by_joint_id"],
			true,
		)
	)
	RouteScript.free_zero_world_command_surface_v1(surface)
	return {
		"ok": bool(active.get("ok", false)) and bool(matched_zero.get("ok", false)),
		"active": active,
		"matched_zero": matched_zero,
	}


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Variant = null) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d146_godot_solver_coupled_complete_energy_behavior_route_zero_world_v1",
		"gate_id": "QSDK-R24D146",
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"positive_case_count": 5,
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
