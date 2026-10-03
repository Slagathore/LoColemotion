extends SceneTree
# gdlint: disable=max-line-length

## R163 prospective route-activation gate. It compiles the exact native world
## blueprint, maps one synthetic rotation-aware native source population
## through the production R148 staging seam, and calls the genuine portable
## collection/control entry points. It creates no Node, RID, model, world,
## native read, body write, or solver step.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const StagingRoute := preload(
	"res://sdk/adapters/godot/gdscript/recovery_discrete_staging_route_v1.gd"
)
const R148Worker := preload(
	"res://tests/test_sdk_qsdk_r24d148_godot_discrete_staging_observer_zero_world.gd"
)
const R149Worker := preload(
	"res://tests/test_sdk_qsdk_r24d149_godot_jolt_discrete_staging_live_route_zero_world.gd"
)
const R162Worker := preload(
	"res://tests/test_sdk_qsdk_r24d162_godot_rotation_aware_recovery_ledger_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D163_GODOT_ROTATION_AWARE_RECOVERY_ROUTE_ZERO_WORLD "
const GATE_ID := "QSDK-R24D163"
const ACTUATOR_MODE := "solver_coupled_native_constraint_motor_v1"
const LEGACY_COLLECTOR_ID := "sporespore_godot_jolt_discrete_staging_complete_energy_v4_recovery_collector_v1"
const LEGACY_RUNTIME_PROFILE_ID := "godot_4_7_jolt_sporespore_motor_solved_contact_and_solver_energy_telemetry_v4"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate_v1()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate_v1() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D163_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D163_SDK_INSTANTIATION_FAILED")
	var context := RouteScript.prepare_complete_energy_context_v12(
		sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	if not bool(context.get("ok", false)):
		return _failure("QSDK_R24D163_CONTEXT_INVALID", context)
	var blueprint := RouteScript.native_world_blueprint_v1(sdk, context)
	var fixture := _rotation_aware_bound_fixture_v1(sdk, context)
	if not bool(blueprint.get("ok", false)) or not bool(fixture.get("ok", false)):
		return _failure(
			"QSDK_R24D163_BLUEPRINT_OR_FIXTURE_INVALID",
			{"blueprint": blueprint, "fixture": fixture},
		)
	var bound: Dictionary = fixture["bound"]
	var route := RouteScript.collect_and_plan_v1(sdk, context, bound, "establish_distal_support", 0)
	var collection: Dictionary = route.get("collection_receipt", {})
	var control: Dictionary = route.get("control_receipt", {})
	var mapping: Dictionary = bound.get("native_to_portable_staging_mapping", {})
	var mapped_energy: Dictionary = mapping.get("energy_source_receipt", {})
	var mapped_components: Dictionary = mapping.get("source_component_receipts", {})

	var positive_checks := {
		"exact_r163_construction_context":
		(
			RouteScript.rotation_aware_route_ghost_context_binding_exact_v1(sdk, context)
			and String(context.get("physical_world_construction_gate_id", "")) == GATE_ID
			and bool(context.get("physical_world_construction_authorized", false))
			and bool(context.get("route_ghost_only", false))
			and not bool(context.get("recovery_behavior_evaluation_authorized", true))
		),
		"r162_predecessor_content_bound":
		_valid_sha256(String(context.get("r162_zero_world_context_sha256", ""))),
		"production_blueprint_compiled_zero_world":
		(
			bool(blueprint.get("ok", false))
			and int(blueprint.get("model_construction_count", -1)) == 0
			and int(blueprint.get("world_attempt_count", -1)) == 0
			and int(blueprint.get("world_build_count", -1)) == 0
			and int(blueprint.get("solver_step_count", -1)) == 0
			and not bool(blueprint.get("physics_state_modified", true))
		),
		"rotation_aware_staging_mapping_content_bound":
		(
			(
				String(mapping.get("schema_version", ""))
				== "sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_step_mapping_v1"
			)
			and (
				String(mapping.get("recovery_energy_ledger_profile_id", ""))
				== RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
			)
			and bool(mapping.get("rotation_integration_exchange_included_exactly_once", false))
			and _valid_sha256(
				String(mapping.get("rotation_aware_predecessor_energy_source_receipt_sha256", ""))
			)
			and _valid_sha256(
				String(
					mapping.get("rotation_aware_predecessor_source_component_receipts_sha256", "")
				)
			)
			and bool(
				mapped_energy.get("rotation_integration_exchange_included_exactly_once", false)
			)
			and bool(
				mapped_components.get("rotation_integration_exchange_included_exactly_once", false)
			)
		),
		"production_portable_collection_supported_exact":
		(
			bool(route.get("ok", false))
			and String(collection.get("support_status", "")) == "supported_exact"
			and (
				String(collection.get("collector_id", ""))
				== RouteScript.R162_ROTATION_AWARE_COLLECTOR_ID
			)
			and bool(collection.get("supplied_native_post_step_observation_validated", false))
		),
		"production_portable_control_planned":
		(
			String(control.get("support_status", "")) == "supported_exact"
			and int((control.get("ordered_commands", []) as Array).size()) == 8
			and _zero_world_receipt_v1(route)
		),
	}

	var forced_failure_checks := {
		"wrong_gate_context_refused":
		_context_mutation_refused_v1(
			sdk, context, "physical_world_construction_gate_id", "QSDK-R24D162"
		),
		"missing_construction_authority_refused":
		_context_mutation_refused_v1(sdk, context, "physical_world_construction_authorized", false),
		"missing_rotation_source_refused":
		_source_mutation_refused_v1(sdk, context, fixture, "missing_rotation"),
		"stale_partition_digest_refused":
		_source_mutation_refused_v1(sdk, context, fixture, "stale_partition_digest"),
		"legacy_collector_cross_refused":
		_core_context_refused_v1(
			sdk,
			context,
			bound,
			"collector_id",
			LEGACY_COLLECTOR_ID,
			"collector_or_runtime_profile_identity_invalid",
		),
		"legacy_runtime_cross_refused":
		_core_context_refused_v1(
			sdk,
			context,
			bound,
			"runtime_profile_id",
			LEGACY_RUNTIME_PROFILE_ID,
			"collector_or_runtime_profile_identity_invalid",
		),
		"source_mapping_cross_refused": _source_binding_cross_refused_v1(sdk, context, bound),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version":
		"sporespore_qsdk_r24d163_godot_rotation_aware_recovery_route_zero_world_v1",
		"gate_id": GATE_ID,
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D163_ZERO_WORLD_CONJUNCTION_INVALID",
		"status": "passed_zero_world_rotation_aware_production_route_activation",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_smallest_production_route_ghost_zero_world",
			"question_class": "development",
		},
		"question_class": "development",
		"route_ghost_profile_id": RouteScript.R163_ROTATION_AWARE_ROUTE_GHOST_PROFILE_ID,
		"actuator_mode": ACTUATOR_MODE,
		"recovery_controller_id": RouteScript.RECOVERY_CONTROLLER_V6_ID,
		"collector_id": RouteScript.R162_ROTATION_AWARE_COLLECTOR_ID,
		"runtime_profile_id":
		String((context["runtime_binding"] as Dictionary)["runtime_profile_id"]),
		"energy_route_id": RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
		"energy_mapping_profile_id": RouteScript.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"recovery_energy_ledger_profile_id":
		RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID,
		"solver_energy_consumer_contract_schema_version":
		RouteScript.R162_SOLVER_ENERGY_CONSUMER_CONTRACT_SCHEMA,
		"partition_contract_schema_version":
		RouteScript.R162_ROTATION_AWARE_PARTITION_CONTRACT_SCHEMA,
		"partition_numerical_term_count": 14,
		"production_collection_method": "SporeLocomotionSdk.recovery_collect_native_v3_json",
		"production_control_method": "SporeLocomotionSdk.recovery_plan_control_v3_json",
		"production_collect_and_plan_invocation_count": 1,
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


static func _rotation_aware_bound_fixture_v1(sdk: Object, context: Dictionary) -> Dictionary:
	var predecessor_fixture := RouteScript._zero_world_fixture_for_controller_v1(
		sdk, context, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	var projection := R149Worker._boundary_projection_v1(1)
	if not bool(predecessor_fixture.get("ok", false)) or not bool(projection.get("ok", false)):
		return {"ok": false, "failure_code": "R163_PREDECESSOR_FIXTURE_INVALID"}
	var observer := (
		StagingRoute
		. measure_native_step_v1(
			1,
			0,
			1.0 / 120.0,
			projection["ordered_body_boundaries"],
			Vector3.ZERO,
		)
	)
	if not bool(observer.get("ok", false)):
		return {"ok": false, "failure_code": "R163_OBSERVER_FIXTURE_INVALID"}
	var sources := _rotation_sources_v1(sdk, context, observer)
	if not bool(sources.get("ok", false)):
		return sources
	var observation_base: Dictionary = (
		(predecessor_fixture["observation_v2"] as Dictionary).duplicate(true)
	)
	observation_base.erase("schema_version")
	observation_base.erase("energy_balance")
	observation_base["semantic_step"] = 1
	(observation_base["engine_step_identity"] as Dictionary)["semantic_step"] = 1
	(observation_base["engine_step_identity"] as Dictionary)["capability_sha256"] = (String(
		context["capability_sha256"]
	))
	(observation_base["state"] as Dictionary)["adapter_capability_sha256"] = (String(
		context["capability_sha256"]
	))
	var bound := (
		RouteScript
		. compose_discrete_staging_complete_energy_observations_v1(
			sdk,
			context,
			observation_base,
			sources["energy_source_receipt"],
			sources["source_component_receipts"],
			observer,
			StagingRoute.initial_accumulator_v1(),
		)
	)
	return {
		"ok": bool(bound.get("ok", false)),
		"bound": bound,
		"observation_base": observation_base,
		"energy_source_receipt": sources["energy_source_receipt"],
		"source_component_receipts": sources["source_component_receipts"],
		"observer_receipt": observer,
	}


static func _rotation_sources_v1(
	sdk: Object, context: Dictionary, observer: Dictionary
) -> Dictionary:
	var telemetry := R162Worker._telemetry_v2()
	for key in [
		"telemetry_sequence",
		"capture_space_step_sequence",
		"read_space_step_sequence",
	]:
		telemetry[key] = 1
	var solver := WorldScript.native_solver_energy_exchange_for_recovery_route_v2(
		context, telemetry, 1, Vector3(0.0, -9.81, 0.0)
	)
	var motor_receipts := R162Worker._motor_receipts_v1()
	for row_value in motor_receipts:
		var row: Dictionary = row_value
		row["capture_space_step_sequence"] = 1
		row["read_space_step_sequence"] = 1
	var partition := WorldScript.solver_coupled_complete_energy_partition_for_recovery_route_v2(
		context, solver, motor_receipts, R162Worker.STEP_ACTUATOR_WORK_J, 1
	)
	if not bool(solver.get("ok", false)) or not bool(partition.get("ok", false)):
		return {
			"ok": false,
			"failure_code": "R163_ROTATION_CONSUMER_FIXTURE_INVALID",
			"solver": solver,
			"partition": partition,
		}
	var predecessor := R148Worker._route_predecessor_v1(sdk, observer)
	var energy: Dictionary = predecessor["energy_source_receipt"]
	var components: Dictionary = predecessor["source_component_receipts"]
	var solver_sha256 := R148Worker._sha256(sdk, solver)
	var partition_sha256 := R148Worker._sha256(sdk, partition)
	var constraint_exchange := float(partition["step_signed_constraint_exchange_j"])
	var staging_exchange := float(observer["signed_discrete_staging_exchange_j"])
	energy["schema_version"] = RouteScript.R162_ROTATION_AWARE_SOURCE_RECEIPT_SCHEMA
	energy["current_mechanical_energy_j"] = (
		float(energy["initial_mechanical_energy_j"]) + constraint_exchange + staging_exchange
	)
	energy["step_signed_constraint_exchange_j"] = constraint_exchange
	energy["cumulative_signed_constraint_exchange_j"] = constraint_exchange
	energy["raw_step_signed_solver_exchange_j"] = float(
		partition["raw_step_signed_solver_exchange_j"]
	)
	energy["step_actuator_work_j"] = float(partition["step_actuator_work_j"])
	energy["solver_energy_exchange_receipt_sha256"] = solver_sha256
	energy["solver_coupled_partition_receipt_sha256"] = partition_sha256
	energy["recovery_energy_ledger_profile_id"] = (
		RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
	)
	energy["solver_energy_consumer_contract_schema_version"] = (
		RouteScript.R162_SOLVER_ENERGY_CONSUMER_CONTRACT_SCHEMA
	)
	energy["solver_energy_telemetry_schema_version"] = (
		RouteScript.R162_SOLVER_ENERGY_TELEMETRY_SCHEMA
	)
	energy["solver_energy_telemetry_profile_id"] = (
		RouteScript.R162_SOLVER_ENERGY_TELEMETRY_PROFILE_ID
	)
	energy["rotation_integration_kinetic_exchange_j"] = float(
		partition["rotation_integration_kinetic_exchange_j"]
	)
	energy["rotation_integration_exchange_included_exactly_once"] = true

	components["schema_version"] = (RouteScript.R162_ROTATION_AWARE_COMPONENT_RECEIPTS_SCHEMA)
	components["solver_energy_exchange_receipt"] = solver
	components["solver_energy_exchange_receipt_sha256"] = solver_sha256
	components["solver_coupled_partition_receipt"] = partition
	components["solver_coupled_partition_receipt_sha256"] = partition_sha256
	components["recovery_energy_ledger_profile_id"] = (
		RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
	)
	components["rotation_integration_exchange_included_exactly_once"] = true
	return {
		"ok": true,
		"energy_source_receipt": energy,
		"source_component_receipts": components,
	}


static func _context_mutation_refused_v1(
	sdk: Object, context: Dictionary, key: String, value: Variant
) -> bool:
	var mutation := context.duplicate(true)
	mutation[key] = value
	return not RouteScript.rotation_aware_route_ghost_context_binding_exact_v1(sdk, mutation)


static func _source_mutation_refused_v1(
	sdk: Object, context: Dictionary, fixture: Dictionary, mutation_id: String
) -> bool:
	var energy: Dictionary = (fixture["energy_source_receipt"] as Dictionary).duplicate(true)
	var components: Dictionary = (fixture["source_component_receipts"] as Dictionary).duplicate(
		true
	)
	if mutation_id == "missing_rotation":
		energy.erase("rotation_integration_kinetic_exchange_j")
	else:
		components["solver_coupled_partition_receipt_sha256"] = ("sha256:0000000000000000000000000000000000000000000000000000000000000000")
	var refused := (
		RouteScript
		. compose_discrete_staging_complete_energy_observations_v1(
			sdk,
			context,
			fixture["observation_base"],
			energy,
			components,
			fixture["observer_receipt"],
			StagingRoute.initial_accumulator_v1(),
		)
	)
	return _zero_world_refusal_v1(refused)


static func _core_context_refused_v1(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
	key: String,
	value: String,
	expected_reason: String,
) -> bool:
	var mutation := context.duplicate(true)
	(mutation["runtime_binding"] as Dictionary)[key] = value
	return _core_refusal_exact_v1(
		RouteScript.collect_and_plan_v1(sdk, mutation, bound, "establish_distal_support", 0),
		expected_reason,
	)


static func _source_binding_cross_refused_v1(
	sdk: Object, context: Dictionary, bound: Dictionary
) -> bool:
	var mutation := bound.duplicate(true)
	(mutation["source_binding"] as Dictionary)["mapping_profile_id"] = (
		RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
	)
	return _core_refusal_exact_v1(
		RouteScript.collect_and_plan_v1(sdk, context, mutation, "establish_distal_support", 0),
		"observation_v2_source_identity_invalid",
	)


static func _core_refusal_exact_v1(route: Dictionary, reason: String) -> bool:
	var detail: Dictionary = route.get("detail", {})
	return (
		not bool(route.get("ok", true))
		and String(route.get("failure_code", "")) == "QSDK_R24D57_NATIVE_COLLECTION_REFUSED"
		and String(detail.get("refusal_reason", "")) == reason
		and _zero_world_receipt_v1(route)
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


static func _zero_world_refusal_v1(value: Dictionary) -> bool:
	return not bool(value.get("ok", true)) and _zero_world_receipt_v1(value)


static func _valid_sha256(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version":
		"sporespore_qsdk_r24d163_godot_rotation_aware_recovery_route_zero_world_v1",
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"positive_case_count": 0,
		"forced_failure_case_count": 0,
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
