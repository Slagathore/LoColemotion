extends SceneTree
# gdlint: disable=max-line-length

## Compact R126 production-route check. It reuses the qualified R57 fixture and
## opens no Node, RID, model, world, or solver step.

const RouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
)
const RecoveryRuntimeScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_runtime.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D126_GODOT_ENERGY_AUTHORITY_ZERO_WORLD "


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D126_GODOT_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D126_GODOT_EXTENSION_INSTANTIATION_FAILED")

	var context := RouteScript.prepare_context_v5(sdk, RouteScript.RECOVERY_CONTROLLER_V5_ID)
	if not bool(context.get("ok", false)):
		return _failure("QSDK_R24D126_CONTEXT_FAILED", context)
	var bound := RouteScript.zero_world_fixture_v5(sdk, context)
	if not bool(bound.get("ok", false)):
		return _failure("QSDK_R24D126_FIXTURE_FAILED", bound)
	var authority := RouteScript.incomplete_energy_partition_authority_v1(context, bound)
	if authority.is_empty():
		return _failure("QSDK_R24D126_AUTHORITY_BINDING_FAILED")

	var initialized := RouteScript.initialize_behavior_arm_v1(
		sdk, context, "candidate_command"
	)
	if not bool(initialized.get("ok", false)):
		return _failure("QSDK_R24D126_INITIALIZATION_FAILED", initialized)
	var advanced := RouteScript.advance_behavior_v5(
		sdk,
		context,
		bound,
		initialized["memory"],
		"candidate_command",
		"confirm_prone",
	)
	if not bool(advanced.get("ok", false)):
		return _failure("QSDK_R24D126_ADVANCE_FAILED", advanced)
	var step: Dictionary = advanced.get("step_receipt", {})
	var progression: Dictionary = advanced.get("development_progression_receipt", {})

	var base_request := {
		"schema_version": "sporespore_recovery_step_request_v5",
		"descriptor": RouteScript.exact_base_descriptor_v1(),
		"morphology_context": (context["morphology_context"] as Dictionary).duplicate(true),
		"adapter_capability": (context["capability"] as Dictionary).duplicate(true),
		"memory": (initialized["memory"] as Dictionary).duplicate(true),
		"observation": (bound["observation_v3"] as Dictionary).duplicate(true),
		"energy_partition_authority": authority.duplicate(true),
	}
	var mutation_rejection_count := 0
	var mutations: Array[Dictionary] = []

	var missing_authority := base_request.duplicate(true)
	missing_authority.erase("energy_partition_authority")
	mutations.append(missing_authority)

	var wrong_source := base_request.duplicate(true)
	(wrong_source["energy_partition_authority"] as Dictionary)["authority_source_sha256"] = (
		"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	)
	mutations.append(wrong_source)

	var residual_balancing := base_request.duplicate(true)
	(residual_balancing["energy_partition_authority"] as Dictionary)[
		"residual_balancing_permitted"
	] = true
	mutations.append(residual_balancing)

	var self_asserted_complete := base_request.duplicate(true)
	var complete: Dictionary = self_asserted_complete["energy_partition_authority"]
	complete["constraint_exchange_partition_complete"] = true
	complete["passive_dissipation_partition_complete"] = true
	complete["component_partition_complete"] = true
	complete["exact_balance_safety_authority"] = true
	complete["unclosed_energy_residual_preserved"] = false
	complete["development_progression_permitted"] = false
	mutations.append(self_asserted_complete)

	var wrong_observation_binding := base_request.duplicate(true)
	(wrong_observation_binding["energy_partition_authority"] as Dictionary)[
		"energy_source_profile_id"
	] = "wrong_energy_source_profile"
	mutations.append(wrong_observation_binding)

	var unknown_field := base_request.duplicate(true)
	(unknown_field["energy_partition_authority"] as Dictionary)["manufactured_balance"] = true
	mutations.append(unknown_field)

	for mutation in mutations:
		var refused := RecoveryRuntimeScript.step_v5(sdk, mutation)
		mutation_rejection_count += int(
			not bool(refused.get("ok", true))
			and int(refused.get("world_build_count", -1)) == 0
			and int(refused.get("solver_step_count", -1)) == 0
			and not bool(refused.get("physics_state_modified", true))
		)

	var wrong_context := context.duplicate(true)
	wrong_context["capability_sha256"] = (
		"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
	)
	var helper_cross_binding_refused := (
		RouteScript.incomplete_energy_partition_authority_v1(wrong_context, bound).is_empty()
	)

	var exact := (
		String(advanced.get("schema_version", "")) == RouteScript.R126_DEVELOPMENT_ROUTE_ID
		and String(authority.get("authority_profile_id", ""))
		== RouteScript.R126_ENERGY_AUTHORITY_PROFILE_ID
		and not bool(authority.get("component_partition_complete", true))
		and not bool(authority.get("exact_balance_safety_authority", true))
		and bool(authority.get("unclosed_energy_residual_preserved", false))
		and not bool(authority.get("residual_balancing_permitted", true))
		and bool(authority.get("development_progression_permitted", false))
		and String(step.get("schema_version", "")) == "sporespore_recovery_step_receipt_v1"
		and String(step.get("support_status", "")) == "supported_exact"
		and not bool(step.get("physical_result", true))
		and not bool(step.get("prone_to_standing_claimed", true))
		and String(progression.get("schema_version", ""))
		== "sporespore_recovery_development_progression_receipt_v1"
		and not bool(progression.get("acceptance_safety_gate", true))
		and not bool(progression.get("development_progression_used", true))
		and not bool(progression.get("stable_stance_completion_authorized", true))
		and not bool(progression.get("physical_result_authorized", true))
		and not bool(progression.get("prone_to_standing_claimed", true))
		and not bool(progression.get("physical_acceptance_authority", true))
		and not bool(progression.get("release_authority", true))
		and mutation_rejection_count == mutations.size()
		and helper_cross_binding_refused
		and int(advanced.get("model_construction_count", -1)) == 0
		and int(advanced.get("world_attempt_count", -1)) == 0
		and int(advanced.get("world_build_count", -1)) == 0
		and int(advanced.get("solver_step_count", -1)) == 0
		and not bool(advanced.get("physics_state_modified", true))
	)
	return {
		"schema_version": "sporespore_qsdk_r24d126_godot_energy_authority_zero_world_v1",
		"gate_id": "QSDK-R24D126",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D126_ZERO_WORLD_CONJUNCTION_INVALID",
		"authority_profile_id": String(authority.get("authority_profile_id", "")),
		"legacy_step_schema": String(step.get("schema_version", "")),
		"progression_schema": String(progression.get("schema_version", "")),
		"development_progression_used": bool(
			progression.get("development_progression_used", true)
		),
		"mutation_control_count": mutations.size() + 1,
		"mutation_rejection_count": mutation_rejection_count + int(helper_cross_binding_refused),
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


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d126_godot_energy_authority_zero_world_v1",
		"gate_id": "QSDK-R24D126",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
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
