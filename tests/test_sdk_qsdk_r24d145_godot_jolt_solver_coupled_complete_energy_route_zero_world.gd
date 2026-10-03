extends SceneTree
# gdlint: disable=max-line-length

## R145 binds the already-qualified R144 solver-coupled complete-energy route
## into the shared production ghost. This gate calls the real shared binding
## and context seams but creates no model, node, RID, world, or solver step.

const RouteGhostScript := preload(
	"res://tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
)
const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const ProfileScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd"
)
const R144WorkerScript := preload(
	"res://tests/test_sdk_qsdk_r24d144_godot_solver_coupled_complete_energy_partition_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D145_GODOT_JOLT_SOLVER_COUPLED_COMPLETE_ENERGY_ROUTE_ZERO_WORLD "
const ACTUATOR_MODE := "solver_coupled_native_constraint_motor_v1"
const ROUTE_PROFILE_ID := (
	"godot_jolt_r24d145_solver_coupled_complete_energy_two_step_route_v1"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D145_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D145_SDK_INSTANTIATION_FAILED")

	var route_binding_passed := RouteGhostScript.route_binding_valid_v1(
		RouteScript.RECOVERY_CONTROLLER_V6_ID,
		RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
		ACTUATOR_MODE,
	)
	var context := RouteGhostScript.prepare_route_context_v1(
		sdk,
		RouteScript.RECOVERY_CONTROLLER_V6_ID,
		RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
	)
	var projection_fixture := _shared_projection_fixture_v1(sdk)
	var positive_checks := {
		"shared_route_binding": route_binding_passed,
		"shared_route_context": _context_exact_v1(context),
		"shared_partition_projection": bool(projection_fixture.get("positive_passed", false)),
		"zero_physics_boundary": _zero_physics_projection_valid_v1(context),
	}
	var forced_failure_checks := {
		"wrong_actuator_mode_refused": not RouteGhostScript.route_binding_valid_v1(
			RouteScript.RECOVERY_CONTROLLER_V6_ID,
			RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
			"legacy_velocity_motor_v1",
		),
		"wrong_controller_refused": not RouteGhostScript.route_binding_valid_v1(
			RouteScript.RECOVERY_CONTROLLER_V5_ID,
			RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
			ACTUATOR_MODE,
		),
		"unknown_route_refused": not RouteGhostScript.route_binding_valid_v1(
			RouteScript.RECOVERY_CONTROLLER_V6_ID,
			"unknown_energy_route",
			ACTUATOR_MODE,
		),
		"cross_profile_route_refused": not RouteGhostScript.route_binding_valid_v1(
			RouteScript.RECOVERY_CONTROLLER_V6_ID,
			RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
			ACTUATOR_MODE,
		),
		"mutated_partition_projection_refused": bool(
			projection_fixture.get("forced_failure_passed", false)
		),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d145_godot_jolt_solver_coupled_complete_energy_route_zero_world_v1",
		"gate_id": "QSDK-R24D145",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_shared_two_step_native_route_zero_world",
			"question_class": "development",
		},
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D145_ZERO_WORLD_CONJUNCTION_INVALID",
		"question_class": "development",
		"route_profile_id": ROUTE_PROFILE_ID,
		"actuator_mode": ACTUATOR_MODE,
		"recovery_controller_id": RouteScript.RECOVERY_CONTROLLER_V6_ID,
		"energy_route_id": RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
		"energy_mapping_profile_id": RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"actuation_realization_id": RouteScript.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID,
		"actuator_mapping_id": RouteScript.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID,
		"work_mapping_id": RouteScript.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID,
		"partition_rule_id": RouteScript.R144_PARTITION_RULE_ID,
		"shared_route_binding_passed": route_binding_passed,
		"shared_route_context_passed": positive_checks["shared_route_context"],
		"shared_partition_projection_passed": positive_checks[
			"shared_partition_projection"
		],
		"zero_physics_boundary_passed": positive_checks["zero_physics_boundary"],
		"positive_checks": positive_checks,
		"positive_case_count": positive_checks.size(),
		"positive_pass_count": positive_pass_count,
		"forced_failure_checks": forced_failure_checks,
		"forced_failure_case_count": forced_failure_checks.size(),
		"forced_failure_pass_count": forced_failure_pass_count,
		"sdk_instance_count": 1,
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


static func _shared_projection_fixture_v1(sdk: Object) -> Dictionary:
	var solver_receipt := WorldScript.native_solver_energy_exchange_contract_v1(
		R144WorkerScript._solver_telemetry_v1(),
		R144WorkerScript.SPACE_STEP_SEQUENCE,
		Vector3(0.0, -9.81, 0.0),
	)
	var inputs_receipt := (
		WorldScript.solver_coupled_complete_energy_partition_inputs_contract_v1(
			R144WorkerScript._partition_inputs_v1(false)
		)
	)
	var partition := WorldScript.solver_coupled_complete_energy_partition_contract_v1(
		solver_receipt,
		R144WorkerScript._motor_receipts_v1(false),
		R144WorkerScript.ACTIVE_STEP_MOTOR_WORK_J,
		R144WorkerScript.SPACE_STEP_SEQUENCE,
		WorldScript.solver_coupled_complete_energy_partition_declaration_v1(),
	)
	if (
		not bool(solver_receipt.get("ok", false))
		or not bool(inputs_receipt.get("ok", false))
		or not bool(partition.get("ok", false))
	):
		return {"positive_passed": false, "forced_failure_passed": false}
	var solver_sha := R144WorkerScript._sha256(sdk, solver_receipt)
	var partition_sha := R144WorkerScript._sha256(sdk, partition)
	var native := {
		"ok": true,
		"measurement": {
			"source_component_receipts": {
				"schema_version": "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_source_component_receipts_v1",
				"solver_energy_exchange_receipt": solver_receipt,
				"solver_energy_exchange_receipt_sha256": solver_sha,
				"solver_coupled_partition_receipt": partition,
				"solver_coupled_partition_receipt_sha256": partition_sha,
			}
		},
	}
	var positive := RouteGhostScript.complete_energy_solver_projection_v1(
		native,
		R144WorkerScript.SPACE_STEP_SEQUENCE,
		RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
	)
	var mutation := native.duplicate(true)
	var mutation_components: Dictionary = mutation["measurement"]["source_component_receipts"]
	var mutation_partition: Dictionary = mutation_components["solver_coupled_partition_receipt"]
	mutation_partition["motor_work_also_counted_as_constraint_exchange"] = true
	var rejected := RouteGhostScript.complete_energy_solver_projection_v1(
		mutation,
		R144WorkerScript.SPACE_STEP_SEQUENCE,
		RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
	)
	return {
		"positive_passed": (
			bool(positive.get("ok", false))
			and bool(positive.get("required", false))
			and String(positive.get("solver_coupled_partition_receipt_sha256", ""))
			== partition_sha
		),
		"forced_failure_passed": (
			not bool(rejected.get("ok", true))
			and String(rejected.get("failure_code", ""))
			== "QSDK_ROUTE_GHOST_PARTITION_IDENTITY_INVALID"
		),
	}


static func _context_exact_v1(context: Dictionary) -> bool:
	var runtime_binding: Dictionary = context.get("runtime_binding", {})
	var profile_receipt: Dictionary = context.get("runtime_profile_receipt", {})
	var validation: Dictionary = profile_receipt.get("validation", {})
	return (
		bool(context.get("ok", false))
		and String(context.get("schema_version", ""))
		== "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_recovery_route_context_v3"
		and String(context.get("recovery_controller_id", ""))
		== RouteScript.RECOVERY_CONTROLLER_V6_ID
		and bool(context.get("complete_energy_profile_selected", false))
		and bool(context.get("solver_coupled_complete_energy_profile_selected", false))
		and String(context.get("energy_route_id", ""))
		== RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
		and String(context.get("energy_mapping_profile_id", ""))
		== RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		and String(context.get("partition_rule_id", "")) == RouteScript.R144_PARTITION_RULE_ID
		and String(context.get("required_active_actuator_mapping_id", ""))
		== RouteScript.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID
		and String(context.get("required_active_work_mapping_id", ""))
		== RouteScript.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID
		and String(context.get("capability_variant_id", ""))
		== ProfileScript.SOLVER_COUPLED_COMPLETE_ENERGY_CAPABILITY_VARIANT_ID
		and String(runtime_binding.get("collector_id", ""))
		== RouteScript.R144_COMPLETE_ENERGY_COLLECTOR_ID
		and bool(validation.get("ok", false))
		and int(validation.get("changed_channel_count", -1)) == 1
		and validation.get("changed_channel_ids", []) == ["energy_balance_ledger"]
		and _zero_physics_projection_valid_v1(context)
	)


static func _zero_physics_projection_valid_v1(context: Dictionary) -> bool:
	var receipt: Dictionary = context.get("runtime_profile_receipt", {})
	var runtime: Dictionary = receipt.get("runtime_identity", {})
	for value in [context, receipt, runtime]:
		if (
			int(value.get("model_construction_count", -1)) != 0
			or int(value.get("world_attempt_count", -1)) != 0
			or int(value.get("world_build_count", -1)) != 0
			or int(value.get("solver_step_count", -1)) != 0
			or bool(value.get("physics_state_modified", true))
		):
			return false
	return (
		not bool(context.get("physical_acceptance_authority", true))
		and not bool(context.get("release_authority", true))
	)


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Variant = null) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d145_godot_jolt_solver_coupled_complete_energy_route_zero_world_v1",
		"gate_id": "QSDK-R24D145",
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"positive_case_count": 4,
		"forced_failure_case_count": 5,
		"sdk_instance_count": 0,
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
