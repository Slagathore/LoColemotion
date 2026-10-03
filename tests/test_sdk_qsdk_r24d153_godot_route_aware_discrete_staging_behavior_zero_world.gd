extends SceneTree
# gdlint: disable=max-line-length

## Compact production-path control for R153. It exercises the exact finite
## behavior selector inherited from R151 while requiring the R152-commissioned
## route-aware application provenance at bootstrap, active application, and
## native-sampler projection. No RID, model, world, native readback, or solver
## step is constructed.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const NativeWorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const R129Worker := preload(
	"res://tests/test_sdk_qsdk_r24d129_godot_solver_coupled_application_mutation_zero_world.gd"
)
const R150Worker := preload(
	"res://tests/test_sdk_qsdk_r24d150_godot_discrete_staging_core_binding_zero_world.gd"
)
const R151Worker := preload(
	"res://tests/test_sdk_qsdk_r24d151_godot_commissioned_discrete_staging_behavior_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "SPORESPORE_GODOT_R24D153_ROUTE_AWARE_DISCRETE_STAGING_BEHAVIOR_ZERO_WORLD "
const GATE_ID := "QSDK-R24D153"
const ACTUATOR_MODE := BehaviorWorker.ACTUATOR_MODE_SOLVER_COUPLED
const CONTROLLER := RouteScript.RECOVERY_CONTROLLER_V6_ID
const ENERGY_ROUTE := RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
const APPLICATION_PROFILE := RouteScript.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
const APPLICATION_SCHEMA := "sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_complete_energy_command_application_receipt_v1"
const NATIVE_APPLICATION_SCHEMA := "sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_native_application_receipt_v1"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate_v1()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate_v1() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D153_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D153_SDK_INSTANTIATION_FAILED")
	var predecessor_fixture := R150Worker._production_fixture_v1(sdk)
	var context := BehaviorWorker.prepare_behavior_context_v1(
		sdk,
		CONTROLLER,
		ENERGY_ROUTE,
		GATE_ID,
	)
	if not bool(predecessor_fixture.get("ok", false)) or not bool(context.get("ok", false)):
		return _failure(
			"QSDK_R24D153_CONTEXT_OR_FIXTURE_INVALID",
			{"context": context, "predecessor_fixture": predecessor_fixture},
		)
	var bound: Dictionary = predecessor_fixture["bound"]
	var initialized := RouteScript.initialize_behavior_arm_v1(
		sdk,
		context,
		"candidate_command",
	)
	if not bool(initialized.get("ok", false)):
		return _failure("QSDK_R24D153_INITIALIZATION_FAILED", initialized)
	var advanced := BehaviorWorker.production_advance_dispatch_v1(
		sdk,
		context,
		bound,
		initialized["memory"],
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
		sdk,
		context,
		bound,
		true,
	)
	var initial_fixture := _initial_application_fixture_v1(sdk, context)
	if (
		not bool(advanced.get("ok", false))
		or not bool(traces.get("ok", false))
		or not bool(evaluated.get("ok", false))
		or not bool(applications.get("ok", false))
		or not bool(initial_fixture.get("ok", false))
	):
		return _failure(
			"QSDK_R24D153_PRODUCTION_PATH_FAILED",
			{
				"advanced": advanced,
				"evaluated": evaluated,
				"applications": applications,
				"initial_fixture": initial_fixture,
			},
		)
	var active: Dictionary = applications["active"]
	var matched_zero: Dictionary = applications["matched_zero"]
	var initial: Dictionary = initial_fixture["initial"]
	var active_projection := (
		NativeWorldScript
		. solver_coupled_complete_energy_application_provenance_v2(
			active,
			int(active["semantic_step"]),
			true,
		)
	)
	var initial_projection := (
		NativeWorldScript
		. solver_coupled_complete_energy_application_provenance_v2(
			initial,
			1,
			true,
		)
	)
	var authority: Dictionary = advanced.get("energy_partition_authority", {})
	var positive_checks := {
		"exact_r153_context": (
			String(context.get("schema_version", ""))
			== "sporespore_qsdk_r24d153_godot_route_aware_discrete_staging_behavior_context_v9"
			and String(context.get("physical_world_construction_gate_id", "")) == GATE_ID
			and bool(context.get("finite_behavior_pair_selected", false))
			and BehaviorWorker.route_aware_application_provenance_selected_v1(context)
			and String(context.get("complete_energy_authority_profile_id", ""))
			== RouteScript.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
		),
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
		"commissioned_authority": (
			String(authority.get("authority_profile_id", ""))
			== RouteScript.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
			and bool(authority.get("component_partition_complete", false))
			and bool(authority.get("exact_balance_safety_authority", false))
			and not bool(authority.get("physical_acceptance_authority", true))
			and not bool(authority.get("release_authority", true))
		),
		"evaluation": BehaviorWorker.production_evaluation_receipt_valid_v1(
			evaluated,
			CONTROLLER,
			ENERGY_ROUTE,
		),
		"initial_application": _initial_application_valid_v1(initial),
		"active_application": _application_valid_v1(active, false),
		"matched_zero_application": _application_valid_v1(matched_zero, true),
		"initial_native_projection": _projection_valid_v1(initial_projection, true),
		"active_native_projection": _projection_valid_v1(active_projection, false),
	}
	var wrong_gate := BehaviorWorker.prepare_behavior_context_v1(
		sdk,
		CONTROLLER,
		ENERGY_ROUTE,
		"QSDK-R24D152",
	)
	var missing_pair := context.duplicate(true)
	missing_pair.erase("finite_behavior_pair_selected")
	var wrong_context_profile := context.duplicate(true)
	wrong_context_profile["application_provenance_profile_id"] = "crossed_profile"
	var predecessor_active := active.duplicate(true)
	predecessor_active["schema_version"] = (
		"sporespore_qsdk_r24d151_godot_discrete_staging_complete_energy_command_application_receipt_v1"
	)
	predecessor_active.erase("predecessor_route_aware_application_schema_version")
	predecessor_active.erase("application_provenance_profile_id")
	var missing_application_profile := active.duplicate(true)
	missing_application_profile.erase("application_provenance_profile_id")
	var wrong_application_profile := active.duplicate(true)
	wrong_application_profile["application_provenance_profile_id"] = "crossed_profile"
	var crossed_route := active.duplicate(true)
	crossed_route["energy_route_id"] = RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
	var forced_failure_checks := {
		"wrong_gate_refused": not bool(wrong_gate.get("ok", true)),
		"missing_behavior_pair_context_refused": not (
			BehaviorWorker.route_aware_application_provenance_selected_v1(missing_pair)
		),
		"crossed_context_profile_refused": not (
			BehaviorWorker.route_aware_application_provenance_selected_v1(wrong_context_profile)
		),
		"predecessor_application_refused": not _application_valid_v1(
			predecessor_active,
			false,
		),
		"missing_application_profile_refused": not _application_valid_v1(
			missing_application_profile,
			false,
		),
		"wrong_application_profile_refused": not _application_valid_v1(
			wrong_application_profile,
			false,
		),
		"crossed_route_refused": not _application_valid_v1(crossed_route, false),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d153_godot_route_aware_discrete_staging_behavior_zero_world_v1",
		"gate_id": GATE_ID,
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_route_aware_discrete_staging_behavior_zero_world",
			"question_class": "development",
		},
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D153_ZERO_WORLD_CONJUNCTION_INVALID",
		"recovery_controller_id": CONTROLLER,
		"actuator_mode": ACTUATOR_MODE,
		"energy_route_id": ENERGY_ROUTE,
		"energy_mapping_profile_id": RouteScript.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"complete_energy_authority_profile_id": RouteScript.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID,
		"application_provenance_profile_id": APPLICATION_PROFILE,
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


static func _initial_application_fixture_v1(sdk: Object, context: Dictionary) -> Dictionary:
	var surface := RouteScript.zero_world_command_surface_v1(context)
	if not bool(surface.get("ok", false)):
		return {"ok": false, "surface": surface}
	var joint_nodes: Dictionary = {}
	var ordered_joints: Array = surface["ordered_joints"]
	for index in range(NativeWorldScript.ORDERED_JOINT_IDS.size()):
		joint_nodes[NativeWorldScript.ORDERED_JOINT_IDS[index]] = ordered_joints[index]
	var model := {
		"ok": true,
		"host_step_count": 0,
		"joint_nodes": joint_nodes,
		"complete_energy_profile_selected": true,
		"solver_coupled_complete_energy_profile_selected": true,
		"discrete_staging_complete_energy_profile_selected": true,
	}
	var initial := RouteScript.initial_behavior_application_route_aware_discrete_staging_v2(
		sdk,
		model,
		"candidate_command",
		"confirm_prone",
		CONTROLLER,
	)
	RouteScript.free_zero_world_command_surface_v1(surface)
	return {"ok": bool(initial.get("ok", false)), "initial": initial}


static func _application_valid_v1(application: Dictionary, no_actuation: bool) -> bool:
	return (
		String(application.get("schema_version", "")) == APPLICATION_SCHEMA
		and BehaviorWorker.behavior_application_receipt_valid_v4(
			ACTUATOR_MODE,
			application,
			no_actuation,
			ENERGY_ROUTE,
			true,
		)
	)


static func _initial_application_valid_v1(application: Dictionary) -> bool:
	return (
		bool(application.get("ok", false))
		and bool(application.get("bootstrap_application", false))
		and bool(application.get("no_actuation_requested", false))
		and String(application.get("energy_route_id", "")) == ENERGY_ROUTE
		and String(application.get("predecessor_complete_energy_route_id", ""))
		== RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
		and String(application.get("complete_energy_authority_profile_id", ""))
		== RouteScript.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
		and String(application.get("application_provenance_profile_id", ""))
		== APPLICATION_PROFILE
	)


static func _projection_valid_v1(projection: Dictionary, bootstrap: bool) -> bool:
	return (
		bool(projection.get("ok", false))
		and String(projection.get("route_id", "")) == ENERGY_ROUTE
		and String(projection.get("energy_mapping_profile_id", ""))
		== RouteScript.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		and String(projection.get("native_application_receipt_schema", ""))
		== NATIVE_APPLICATION_SCHEMA
		and bool(projection.get("bootstrap_application", not bootstrap)) == bootstrap
		and String(projection.get("application_provenance_profile_id", ""))
		== APPLICATION_PROFILE
		and int(projection.get("model_construction_count", -1)) == 0
		and int(projection.get("world_attempt_count", -1)) == 0
		and int(projection.get("world_build_count", -1)) == 0
		and int(projection.get("solver_step_count", -1)) == 0
		and not bool(projection.get("physics_state_modified", true))
		and not bool(projection.get("physical_acceptance_authority", true))
		and not bool(projection.get("release_authority", true))
	)


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Variant = null) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d153_godot_route_aware_discrete_staging_behavior_zero_world_v1",
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"positive_case_count": 10,
		"forced_failure_case_count": 7,
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
