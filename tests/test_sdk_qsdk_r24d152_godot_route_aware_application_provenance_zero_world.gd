extends SceneTree
# gdlint: disable=max-line-length

## Compact R152 proof for the exact seam missed by R150: the production R151
## bootstrap and active application wrappers are consumed by the same pure
## route-aware provenance projection used inside the native sampler. Hinge
## objects are unparented command surfaces only; no model, world, RID, native
## readback, or solver step is constructed.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const NativeWorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
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
const MARKER := "SPORESPORE_GODOT_R24D152_ROUTE_AWARE_APPLICATION_PROVENANCE_ZERO_WORLD "
const GATE_ID := "QSDK-R24D152"
const FAILURE_CODE := "QSDK_R24D152_ROUTE_AWARE_APPLICATION_PROVENANCE_INVALID"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate_v1()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate_v1() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D152_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D152_SDK_INSTANTIATION_FAILED")
	var context := RouteScript.prepare_complete_energy_context_v8(
		sdk,
		RouteScript.RECOVERY_CONTROLLER_V6_ID,
	)
	var predecessor_fixture := R150Worker._production_fixture_v1(sdk)
	if not bool(context.get("ok", false)) or not bool(
		predecessor_fixture.get("ok", false)
	):
		return _failure(
			"QSDK_R24D152_CONTEXT_OR_FIXTURE_INVALID",
			{"context": context, "predecessor_fixture": predecessor_fixture},
		)
	var surface := RouteScript.zero_world_command_surface_v1(context)
	if not bool(surface.get("ok", false)):
		return _failure("QSDK_R24D152_COMMAND_SURFACE_INVALID", surface)
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
	var initial := (
		RouteScript
		. initial_behavior_application_route_aware_discrete_staging_v2(
			sdk,
			model,
			"candidate_command",
			"confirm_prone",
			RouteScript.RECOVERY_CONTROLLER_V6_ID,
		)
	)
	var active_fixtures := R151Worker._application_fixtures_v1(
		sdk,
		context,
		predecessor_fixture["bound"],
		true,
	)
	RouteScript.free_zero_world_command_surface_v1(surface)
	if not bool(initial.get("ok", false)) or not bool(active_fixtures.get("ok", false)):
		return _failure(
			"QSDK_R24D152_PRODUCTION_APPLICATION_FIXTURE_INVALID",
			{"initial": initial, "active_fixtures": active_fixtures},
		)
	var active: Dictionary = active_fixtures["active"]
	var initial_projection := (
		NativeWorldScript
		. solver_coupled_complete_energy_application_provenance_v2(
			initial,
			1,
			true,
		)
	)
	var active_projection := (
		NativeWorldScript
		. solver_coupled_complete_energy_application_provenance_v2(
			active,
			int(active["semantic_step"]),
			true,
		)
	)
	var r144_application := initial.duplicate(true)
	r144_application["energy_route_id"] = RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
	r144_application["energy_mapping_profile_id"] = (
		RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	)
	for key in [
		"predecessor_complete_energy_route_id",
		"discrete_staging_complete_energy_profile_selected",
		"complete_energy_authority_profile_id",
		"application_provenance_profile_id",
	]:
		r144_application.erase(key)
	var r144_projection := (
		NativeWorldScript
		. solver_coupled_complete_energy_application_provenance_v2(
			r144_application,
			1,
			false,
		)
	)
	var positive_checks := {
		"exact_r152_context": (
			String(context.get("schema_version", ""))
			== "sporespore_qsdk_r24d152_godot_route_aware_application_provenance_context_v8"
			and String(context.get("physical_world_construction_gate_id", "")) == GATE_ID
			and bool(context.get("route_aware_application_provenance_selected", false))
			and String(context.get("application_provenance_profile_id", ""))
			== RouteScript.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
		),
		"production_initial_application": (
			bool(initial.get("bootstrap_application", false))
			and bool(initial.get("no_actuation_requested", false))
			and String(initial.get("energy_route_id", ""))
			== RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
			and String(initial.get("predecessor_complete_energy_route_id", ""))
			== RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
			and String(initial.get("application_provenance_profile_id", ""))
			== RouteScript.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
		),
		"initial_projection": _r148_projection_valid_v1(initial_projection, true),
		"active_projection": (
			String(active.get("schema_version", ""))
			== "sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_complete_energy_command_application_receipt_v1"
			and String(active.get("predecessor_route_aware_application_schema_version", ""))
			== "sporespore_qsdk_r24d151_godot_discrete_staging_complete_energy_command_application_receipt_v1"
			and String(active.get("predecessor_complete_energy_schema_version", ""))
			== "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_command_application_receipt_v1"
			and _r148_projection_valid_v1(active_projection, false)
		),
		"r144_projection_unchanged": (
			bool(r144_projection.get("ok", false))
			and String(r144_projection.get("route_id", ""))
			== RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
			and String(r144_projection.get("energy_mapping_profile_id", ""))
			== RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
			and String(r144_projection.get("native_application_receipt_schema", ""))
			== "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_native_application_receipt_v1"
			and _zero_world_projection_v1(r144_projection)
		),
	}
	var mutations: Array[Dictionary] = []
	var wrong_route := initial.duplicate(true)
	wrong_route["energy_route_id"] = RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
	mutations.append(wrong_route)
	var wrong_mapping := initial.duplicate(true)
	wrong_mapping["energy_mapping_profile_id"] = (
		RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	)
	mutations.append(wrong_mapping)
	var missing_predecessor := initial.duplicate(true)
	missing_predecessor.erase("predecessor_complete_energy_route_id")
	mutations.append(missing_predecessor)
	var wrong_authority := initial.duplicate(true)
	wrong_authority["complete_energy_authority_profile_id"] = (
		RouteScript.R148_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
	)
	mutations.append(wrong_authority)
	var missing_profile := initial.duplicate(true)
	missing_profile.erase("application_provenance_profile_id")
	mutations.append(missing_profile)
	var wrong_partition := initial.duplicate(true)
	wrong_partition["partition_rule_id"] = "crossed_partition"
	mutations.append(wrong_partition)
	var active_without_mutation := active.duplicate(true)
	active_without_mutation.erase("application_mutation_semantics_id")
	mutations.append(active_without_mutation)
	var forced_failure_checks: Dictionary = {}
	for index in range(mutations.size()):
		var semantic_step := (
			int(active["semantic_step"])
			if index == mutations.size() - 1
			else 1
		)
		var rejected := (
			NativeWorldScript
			. solver_coupled_complete_energy_application_provenance_v2(
				mutations[index],
				semantic_step,
				true,
			)
		)
		forced_failure_checks["mutation_%d_refused" % index] = (
			not bool(rejected.get("ok", true))
			and String(rejected.get("failure_code", "")) == FAILURE_CODE
			and _zero_world_projection_v1(rejected)
		)
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version":
		"sporespore_qsdk_r24d152_godot_route_aware_application_provenance_zero_world_v1",
		"gate_id": GATE_ID,
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_route_aware_application_provenance_zero_world",
			"question_class": "development",
		},
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D152_ZERO_WORLD_CONJUNCTION_INVALID",
		"application_provenance_profile_id": (
			RouteScript.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
		),
		"outer_energy_route_id": RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
		"outer_energy_mapping_profile_id": (
			RouteScript.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		),
		"predecessor_energy_route_id": RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
		"predecessor_energy_mapping_profile_id": (
			RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		),
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


static func _r148_projection_valid_v1(projection: Dictionary, bootstrap: bool) -> bool:
	return (
		bool(projection.get("ok", false))
		and String(projection.get("schema_version", ""))
		== "sporespore_qsdk_r24d152_godot_route_aware_application_provenance_projection_v1"
		and String(projection.get("route_id", ""))
		== RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
		and String(projection.get("world_route_id", ""))
		== NativeWorldScript.R148_COMPLETE_ENERGY_WORLD_ROUTE_ID
		and String(projection.get("energy_mapping_profile_id", ""))
		== RouteScript.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		and String(projection.get("predecessor_complete_energy_route_id", ""))
		== RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
		and String(projection.get("predecessor_complete_energy_mapping_profile_id", ""))
		== RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		and String(projection.get("native_application_receipt_schema", ""))
		== "sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_native_application_receipt_v1"
		and bool(projection.get("bootstrap_application", not bootstrap)) == bootstrap
		and bool(projection.get("route_aware_application_provenance_selected", false))
		and String(projection.get("application_provenance_profile_id", ""))
		== RouteScript.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
		and String(projection.get("complete_energy_authority_profile_id", ""))
		== RouteScript.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
		and _zero_world_projection_v1(projection)
	)


static func _zero_world_projection_v1(value: Dictionary) -> bool:
	return (
		int(value.get("model_construction_count", -1)) == 0
		and int(value.get("world_attempt_count", -1)) == 0
		and int(value.get("world_build_count", -1)) == 0
		and int(value.get("solver_step_count", -1)) == 0
		and not bool(value.get("physics_state_modified", true))
		and not bool(value.get("physical_acceptance_authority", true))
		and not bool(value.get("release_authority", true))
	)


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Variant = null) -> Dictionary:
	return {
		"schema_version":
		"sporespore_qsdk_r24d152_godot_route_aware_application_provenance_zero_world_v1",
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"positive_case_count": 5,
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
