extends SceneTree
# gdlint: disable=max-line-length

## Compact production-path control for R151. It reuses R150's already-shaped
## R148 bound observation, then exercises the exact behavior context, portable
## collect/step/evaluate dispatches, and native-motor application wrappers.
## No Node, RID, model, world, native readback, or solver step is constructed.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const R129Worker := preload(
	"res://tests/test_sdk_qsdk_r24d129_godot_solver_coupled_application_mutation_zero_world.gd"
)
const R150Worker := preload(
	"res://tests/test_sdk_qsdk_r24d150_godot_discrete_staging_core_binding_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "SPORESPORE_GODOT_R24D151_COMMISSIONED_DISCRETE_STAGING_BEHAVIOR_ZERO_WORLD "
const GATE_ID := "QSDK-R24D151"
const ACTUATOR_MODE := BehaviorWorker.ACTUATOR_MODE_SOLVER_COUPLED
const CONTROLLER := RouteScript.RECOVERY_CONTROLLER_V6_ID
const ENERGY_ROUTE := RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate_v1()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate_v1() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D151_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D151_SDK_INSTANTIATION_FAILED")
	var predecessor_fixture := R150Worker._production_fixture_v1(sdk)
	var context := (
		BehaviorWorker
		. prepare_behavior_context_v1(
			sdk,
			CONTROLLER,
			ENERGY_ROUTE,
			GATE_ID,
		)
	)
	if not bool(predecessor_fixture.get("ok", false)) or not bool(context.get("ok", false)):
		return _failure(
			"QSDK_R24D151_CONTEXT_OR_FIXTURE_INVALID",
			{"context": context, "predecessor_fixture": predecessor_fixture},
		)
	var bound: Dictionary = predecessor_fixture["bound"]
	var initialized := (
		RouteScript
		. initialize_behavior_arm_v1(
			sdk,
			context,
			"candidate_command",
		)
	)
	if not bool(initialized.get("ok", false)):
		return _failure("QSDK_R24D151_INITIALIZATION_FAILED", initialized)
	var advanced := (
		BehaviorWorker
		. production_advance_dispatch_v1(
			sdk,
			context,
			bound,
			initialized["memory"],
			"candidate_command",
			"confirm_prone",
			CONTROLLER,
			ENERGY_ROUTE,
		)
	)
	var traces := BehaviorWorker.paired_zero_world_evaluation_traces_v1(sdk, bound)
	var evaluated := (
		BehaviorWorker
		. production_evaluation_dispatch_v1(
			sdk,
			context,
			traces.get("candidate_trace", {}),
			traces.get("matched_zero_trace", {}),
			CONTROLLER,
			ENERGY_ROUTE,
		)
	)
	var applications := _application_fixtures_v1(sdk, context, bound)
	if (
		not bool(advanced.get("ok", false))
		or not bool(traces.get("ok", false))
		or not bool(evaluated.get("ok", false))
		or not bool(applications.get("ok", false))
	):
		return _failure(
			"QSDK_R24D151_PRODUCTION_PATH_FAILED",
			{
				"advanced": advanced,
				"evaluated": evaluated,
				"applications": applications,
			},
		)
	var authority: Dictionary = advanced.get("energy_partition_authority", {})
	var active_application: Dictionary = applications["active"]
	var zero_application: Dictionary = applications["matched_zero"]
	var positive_checks := {
		"exact_r151_context":
		(
			String(context.get("physical_world_construction_gate_id", "")) == GATE_ID
			and bool(context.get("finite_behavior_pair_selected", false))
			and (
				String(context.get("complete_energy_authority_profile_id", ""))
				== RouteScript.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
			)
		),
		"route_triplet":
		(
			BehaviorWorker
			. actuator_mode_controller_route_triplet_valid_v1(
				ACTUATOR_MODE,
				CONTROLLER,
				ENERGY_ROUTE,
			)
		),
		"advance":
		(
			BehaviorWorker
			. production_advance_receipt_valid_v1(
				advanced,
				CONTROLLER,
				sdk,
				ENERGY_ROUTE,
			)
		),
		"commissioned_authority":
		(
			(
				String(authority.get("authority_profile_id", ""))
				== RouteScript.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
			)
			and bool(authority.get("component_partition_complete", false))
			and bool(authority.get("exact_balance_safety_authority", false))
			and not bool(authority.get("physical_acceptance_authority", true))
			and not bool(authority.get("release_authority", true))
		),
		"evaluation":
		(
			BehaviorWorker
			. production_evaluation_receipt_valid_v1(
				evaluated,
				CONTROLLER,
				ENERGY_ROUTE,
			)
		),
		"active_application":
		(
			BehaviorWorker
			. behavior_application_receipt_valid_v3(
				ACTUATOR_MODE,
				active_application,
				false,
				ENERGY_ROUTE,
			)
		),
		"matched_zero_application":
		(
			BehaviorWorker
			. behavior_application_receipt_valid_v3(
				ACTUATOR_MODE,
				zero_application,
				true,
				ENERGY_ROUTE,
			)
		),
	}
	var wrong_gate := (
		BehaviorWorker
		. prepare_behavior_context_v1(
			sdk,
			CONTROLLER,
			ENERGY_ROUTE,
			"QSDK-R24D150",
		)
	)
	var prospective_authority := (
		RouteScript
		. commissioned_discrete_staging_complete_energy_partition_authority_v1(
			sdk,
			predecessor_fixture["context"],
			bound,
		)
	)
	var crossed_context := context.duplicate(true)
	crossed_context["complete_energy_authority_profile_id"] = (
		RouteScript.R148_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
	)
	var crossed_advance := (
		BehaviorWorker
		. production_advance_dispatch_v1(
			sdk,
			crossed_context,
			bound,
			initialized["memory"],
			"candidate_command",
			"confirm_prone",
			CONTROLLER,
			ENERGY_ROUTE,
		)
	)
	var mutated_advance := advanced.duplicate(true)
	mutated_advance["production_advance_dispatch_id"] = "mutated"
	var mutated_evaluation := evaluated.duplicate(true)
	mutated_evaluation["production_evaluation_dispatch_id"] = "mutated"
	var mutated_application := active_application.duplicate(true)
	mutated_application["energy_route_id"] = RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
	var forced_failure_checks := {
		"wrong_gate_refused": not bool(wrong_gate.get("ok", true)),
		"uncommissioned_context_authority_refused": prospective_authority.is_empty(),
		"crossed_authority_context_refused": not bool(crossed_advance.get("ok", true)),
		"mutated_advance_refused":
		not (
			BehaviorWorker
			. production_advance_receipt_valid_v1(
				mutated_advance,
				CONTROLLER,
				sdk,
				ENERGY_ROUTE,
			)
		),
		"mutated_evaluation_refused":
		not (
			BehaviorWorker
			. production_evaluation_receipt_valid_v1(
				mutated_evaluation,
				CONTROLLER,
				ENERGY_ROUTE,
			)
		),
		"mutated_application_refused":
		not (
			BehaviorWorker
			. behavior_application_receipt_valid_v3(
				ACTUATOR_MODE,
				mutated_application,
				false,
				ENERGY_ROUTE,
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
		"schema_version":
		"sporespore_qsdk_r24d151_godot_commissioned_discrete_staging_behavior_zero_world_v1",
		"gate_id": GATE_ID,
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_commissioned_discrete_staging_behavior_zero_world",
			"question_class": "development",
		},
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D151_ZERO_WORLD_CONJUNCTION_INVALID",
		"recovery_controller_id": CONTROLLER,
		"actuator_mode": ACTUATOR_MODE,
		"energy_route_id": ENERGY_ROUTE,
		"energy_mapping_profile_id": RouteScript.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"complete_energy_authority_profile_id":
		RouteScript.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID,
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


static func _application_fixtures_v1(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
	route_aware_application: bool = false,
) -> Dictionary:
	var planned := (
		RouteScript
		. collect_and_plan_v1(
			sdk,
			context,
			bound,
			"raise_body",
			0,
		)
	)
	var surface := RouteScript.zero_world_command_surface_v1(context)
	if not bool(planned.get("ok", false)) or not bool(surface.get("ok", false)):
		return {"ok": false, "planned": planned, "surface": surface}
	var model := {
		"complete_energy_profile_selected": true,
		"solver_coupled_complete_energy_profile_selected": true,
		"discrete_staging_complete_energy_profile_selected": true,
		"joint_by_actuator_id": surface["joint_by_actuator_id"],
	}
	var active := RouteScript.apply_behavior_control_route_aware_discrete_staging_v2(
		sdk,
		planned["control_receipt"],
		model,
		surface["position_by_joint_id"],
		true,
	) if route_aware_application else (
		RouteScript.apply_behavior_control_discrete_staging_complete_energy_v1(
			sdk, planned["control_receipt"], model, surface["position_by_joint_id"], true
		)
	)
	var matched_zero := RouteScript.apply_behavior_control_route_aware_discrete_staging_v2(
		sdk,
		R129Worker._matched_zero_control_v6(),
		model,
		surface["position_by_joint_id"],
		true,
	) if route_aware_application else (
		RouteScript.apply_behavior_control_discrete_staging_complete_energy_v1(
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
		"schema_version":
		"sporespore_qsdk_r24d151_godot_commissioned_discrete_staging_behavior_zero_world_v1",
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"positive_case_count": 7,
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
