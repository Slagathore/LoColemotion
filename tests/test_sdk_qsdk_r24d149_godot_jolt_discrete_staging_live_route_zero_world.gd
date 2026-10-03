extends SceneTree
# gdlint: disable=max-line-length

## Compact R149 zero-world gate. It exercises the real shared route selector,
## the V5 context transition, the pure production boundary projector, the
## already-qualified R148 observer/mapping chain, and the shared solver receipt
## projection. It constructs no node, RID, model, world, or solver step.

const RouteGhostScript := preload(
	"res://tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_ghost.gd"
)
const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const StagingRoute := preload(
	"res://sdk/adapters/godot/gdscript/recovery_discrete_staging_route_v1.gd"
)
const R144Worker := preload(
	"res://tests/test_sdk_qsdk_r24d144_godot_solver_coupled_complete_energy_partition_zero_world.gd"
)
const R148Worker := preload(
	"res://tests/test_sdk_qsdk_r24d148_godot_discrete_staging_observer_zero_world.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D149_GODOT_JOLT_DISCRETE_STAGING_LIVE_ROUTE_ZERO_WORLD "
const ACTUATOR_MODE := "solver_coupled_native_constraint_motor_v1"
const ROUTE_PROFILE_ID := "godot_jolt_r24d149_discrete_staging_two_step_live_route_v1"
const DT := 1.0 / 120.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate_v1()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate_v1() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D149_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D149_SDK_INSTANTIATION_FAILED")
	var context := RouteGhostScript.prepare_route_context_v1(
		sdk,
		RouteScript.RECOVERY_CONTROLLER_V6_ID,
		RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
	)
	var projection := _boundary_projection_v1(1)
	var mapping := _mapping_chain_v1(sdk, context, projection)
	var solver_projection := _solver_projection_v1(sdk)
	var positive_checks := {
		"shared_route_binding": RouteGhostScript.route_binding_valid_v1(
			RouteScript.RECOVERY_CONTROLLER_V6_ID,
			RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
			ACTUATOR_MODE,
		),
		"r149_context_transition": _context_exact_v1(context),
		"production_boundary_projection": bool(projection.get("ok", false)),
		"two_step_observer_mapping_chain": bool(mapping.get("ok", false)),
		"shared_solver_projection": bool(solver_projection.get("positive_passed", false)),
	}
	var missing_body := _boundary_fixture_v1(1)
	missing_body["post"].erase(String(WorldScript.ORDERED_BODY_IDS[0]))
	var stale_callback := _boundary_fixture_v1(1)
	(stale_callback["pre"][String(WorldScript.ORDERED_BODY_IDS[0])] as Dictionary)[
		"callback_sequence"
	] = 7
	var force_path_mutation := _boundary_fixture_v1(1)
	(force_path_mutation["post"][String(WorldScript.ORDERED_BODY_IDS[0])] as Dictionary)[
		"constant_force_zero"
	] = false
	var mutated_context := context.duplicate(true)
	mutated_context["live_boundary_transport_id"] = "wrong_transport"
	var mutated_context_result: Dictionary = {}
	if bool(mapping.get("fixture_ready", false)):
		mutated_context_result = RouteScript.compose_discrete_staging_complete_energy_observations_v1(
			sdk,
			mutated_context,
			mapping["observation_base"],
			mapping["predecessor_energy_source"],
			mapping["predecessor_components"],
			mapping["observer_step_1"],
			StagingRoute.initial_accumulator_v1(),
		)
	var forced_failure_checks := {
		"wrong_actuator_mode_refused": not RouteGhostScript.route_binding_valid_v1(
			RouteScript.RECOVERY_CONTROLLER_V6_ID,
			RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
			"legacy_velocity_motor_v1",
		),
		"wrong_controller_refused": not RouteGhostScript.route_binding_valid_v1(
			RouteScript.RECOVERY_CONTROLLER_V5_ID,
			RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
			ACTUATOR_MODE,
		),
		"r148_context_remains_physics_closed": _r148_context_still_closed_v1(sdk),
		"missing_post_body_refused": not bool(
			_project_fixture_v1(missing_body, 1).get("ok", true)
		),
		"stale_callback_refused": not bool(
			_project_fixture_v1(stale_callback, 1).get("ok", true)
		),
		"force_path_mutation_refused": not bool(
			_project_fixture_v1(force_path_mutation, 1).get("ok", true)
		),
		"mutated_transport_context_refused": (
			not bool(mutated_context_result.get("ok", true))
			and String(mutated_context_result.get("failure_code", ""))
			== "QSDK_R24D148_COMPLETE_ENERGY_CONTEXT_REQUIRED"
		),
		"stale_accumulator_refused": bool(
			mapping.get("stale_accumulator_refused", false)
		),
		"mutated_solver_partition_refused": bool(
			solver_projection.get("forced_failure_passed", false)
		),
	}
	var positive_pass_count := _true_count(positive_checks)
	var forced_failure_pass_count := _true_count(forced_failure_checks)
	var ok := (
		positive_pass_count == positive_checks.size()
		and forced_failure_pass_count == forced_failure_checks.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d149_godot_jolt_discrete_staging_live_route_zero_world_v1",
		"gate_id": "QSDK-R24D149",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_shared_two_step_native_route_zero_world",
			"question_class": "development",
		},
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D149_ZERO_WORLD_CONJUNCTION_INVALID",
		"question_class": "development",
		"route_profile_id": ROUTE_PROFILE_ID,
		"actuator_mode": ACTUATOR_MODE,
		"recovery_controller_id": RouteScript.RECOVERY_CONTROLLER_V6_ID,
		"energy_route_id": RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
		"energy_mapping_profile_id": RouteScript.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID,
		"live_boundary_transport_id": RouteScript.R149_LIVE_BOUNDARY_TRANSPORT_ID,
		"actuation_realization_id": RouteScript.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID,
		"actuator_mapping_id": RouteScript.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID,
		"work_mapping_id": RouteScript.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID,
		"partition_rule_id": RouteScript.R144_PARTITION_RULE_ID,
		"shared_route_binding_passed": positive_checks["shared_route_binding"],
		"shared_route_context_passed": positive_checks["r149_context_transition"],
		"boundary_projection_passed": positive_checks["production_boundary_projection"],
		"two_step_mapping_chain_passed": positive_checks["two_step_observer_mapping_chain"],
		"shared_partition_projection_passed": positive_checks["shared_solver_projection"],
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


static func _context_exact_v1(context: Dictionary) -> bool:
	return (
		bool(context.get("ok", false))
		and String(context.get("schema_version", ""))
		== "sporespore_qsdk_r24d149_godot_discrete_staging_live_transport_recovery_route_context_v5"
		and String(context.get("energy_route_id", ""))
		== RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
		and String(context.get("energy_mapping_profile_id", ""))
		== RouteScript.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		and String(context.get("live_boundary_transport_id", ""))
		== RouteScript.R149_LIVE_BOUNDARY_TRANSPORT_ID
		and bool(context.get("live_boundary_transport_selected", false))
		and not bool(context.get("live_boundary_transport_commissioned", true))
		and bool(context.get("physical_world_construction_authorized", false))
		and String(context.get("physical_world_construction_gate_id", ""))
		== "QSDK-R24D149"
		and _valid_sha256(String(context.get("r148_zero_world_context_sha256", "")))
	)


static func _r148_context_still_closed_v1(sdk: Object) -> bool:
	var context := RouteScript.prepare_complete_energy_context_v4(
		sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	return (
		bool(context.get("ok", false))
		and not bool(context.get("physical_world_construction_authorized", true))
		and String(context.get("physical_world_construction_next_gate", ""))
		== "QSDK-R24D149"
	)


static func _boundary_fixture_v1(semantic_step: int) -> Dictionary:
	var pre: Dictionary = {}
	var post: Dictionary = {}
	var gravity := Vector3(0.0, -9.800000190734863, 0.0)
	for index in range(WorldScript.ORDERED_BODY_IDS.size()):
		var body_id := String(WorldScript.ORDERED_BODY_IDS[index])
		var mass_kg := 0.5 + float(index) * 0.01
		var pre_velocity := gravity * DT * float(semantic_step - 1)
		var post_velocity := pre_velocity + gravity * DT
		var pre_position := Vector3(float(index) * 0.1, 1.0, 0.0)
		pre[body_id] = {
			"callback_sequence": semantic_step,
			"transform": Transform3D(Basis.IDENTITY, pre_position),
			"linear_velocity_world_m_s": pre_velocity,
			"total_gravity_world_m_s2": gravity,
			"mass_kg": mass_kg,
			"source_measurement": true,
		}
		post[body_id] = {
			"body_id": body_id,
			"boundary_sequence": semantic_step,
			"position_world_m": pre_position + post_velocity * DT,
			"linear_velocity_world_m_s": post_velocity,
			"mass_kg": mass_kg,
			"body_dynamic": true,
			"translation_dofs_unlocked": true,
			"gravity_scale_one": true,
			"constant_force_zero": true,
			"constant_torque_zero": true,
			"linear_damping_zero": true,
			"angular_damping_zero": true,
			"custom_integrator_disabled": true,
			"sleeping_disabled": true,
			"continuous_collision_detection_disabled": true,
			"source_measurement": true,
		}
	return {"pre": pre, "post": post}


static func _project_fixture_v1(fixture: Dictionary, semantic_step: int) -> Dictionary:
	return WorldScript.discrete_staging_body_boundary_projection_v1(
		fixture["pre"], fixture["post"], semantic_step
	)


static func _boundary_projection_v1(semantic_step: int) -> Dictionary:
	return _project_fixture_v1(_boundary_fixture_v1(semantic_step), semantic_step)


static func _mapping_chain_v1(
	sdk: Object,
	context: Dictionary,
	projection_step_1: Dictionary,
) -> Dictionary:
	if not bool(context.get("ok", false)) or not bool(projection_step_1.get("ok", false)):
		return {"ok": false, "fixture_ready": false}
	var observer_step_1 := StagingRoute.measure_native_step_v1(
		1, 0, DT, projection_step_1["ordered_body_boundaries"], Vector3.ZERO
	)
	if not bool(observer_step_1.get("ok", false)):
		return {"ok": false, "fixture_ready": false}
	var predecessor_step_1 := R148Worker._route_predecessor_v1(sdk, observer_step_1)
	var observation_base_1: Dictionary = predecessor_step_1["observation_base"]
	(observation_base_1["engine_step_identity"] as Dictionary)["capability_sha256"] = (
		String(context.get("capability_sha256", ""))
	)
	var accumulator_0 := StagingRoute.initial_accumulator_v1()
	var bound_step_1 := RouteScript.compose_discrete_staging_complete_energy_observations_v1(
		sdk,
		context,
		observation_base_1,
		predecessor_step_1["energy_source_receipt"],
		predecessor_step_1["source_component_receipts"],
		observer_step_1,
		accumulator_0,
	)
	var projection_step_2 := _boundary_projection_v1(2)
	if not bool(bound_step_1.get("ok", false)) or not bool(projection_step_2.get("ok", false)):
		return {"ok": false, "fixture_ready": false}
	var observer_step_2 := StagingRoute.measure_native_step_v1(
		2, 1, DT, projection_step_2["ordered_body_boundaries"], Vector3.ZERO
	)
	var predecessor_step_2 := R148Worker._route_predecessor_v1(sdk, observer_step_2)
	(predecessor_step_2["energy_source_receipt"] as Dictionary)["semantic_step"] = 2
	(predecessor_step_2["source_component_receipts"] as Dictionary)["semantic_step"] = 2
	var observation_base_2: Dictionary = predecessor_step_2["observation_base"]
	observation_base_2["semantic_step"] = 2
	(observation_base_2["engine_step_identity"] as Dictionary)["semantic_step"] = 2
	(observation_base_2["engine_step_identity"] as Dictionary)["capability_sha256"] = (
		String(context.get("capability_sha256", ""))
	)
	var accumulator_1: Dictionary = bound_step_1["discrete_staging_accumulator_after"]
	var bound_step_2 := RouteScript.compose_discrete_staging_complete_energy_observations_v1(
		sdk,
		context,
		observation_base_2,
		predecessor_step_2["energy_source_receipt"],
		predecessor_step_2["source_component_receipts"],
		observer_step_2,
		accumulator_1,
	)
	var stale_accumulator := RouteScript.compose_discrete_staging_complete_energy_observations_v1(
		sdk,
		context,
		observation_base_2,
		predecessor_step_2["energy_source_receipt"],
		predecessor_step_2["source_component_receipts"],
		observer_step_2,
		accumulator_0,
	)
	return {
		"ok": (
			bool(bound_step_2.get("ok", false))
			and int(
				(bound_step_2["discrete_staging_accumulator_after"] as Dictionary).get(
					"event_count", -1
				)
			) == 2
		),
		"fixture_ready": true,
		"observation_base": observation_base_1,
		"predecessor_energy_source": predecessor_step_1["energy_source_receipt"],
		"predecessor_components": predecessor_step_1["source_component_receipts"],
		"observer_step_1": observer_step_1,
		"stale_accumulator_refused": (
			not bool(stale_accumulator.get("ok", true))
			and String(stale_accumulator.get("failure_code", ""))
			== "QSDK_R24D148_SOURCE_SEQUENCE_OR_PARTITION_MISMATCH"
		),
	}


static func _solver_projection_v1(sdk: Object) -> Dictionary:
	var solver_receipt := WorldScript.native_solver_energy_exchange_contract_v1(
		R144Worker._solver_telemetry_v1(),
		R144Worker.SPACE_STEP_SEQUENCE,
		Vector3(0.0, -9.81, 0.0),
	)
	var partition := WorldScript.solver_coupled_complete_energy_partition_contract_v1(
		solver_receipt,
		R144Worker._motor_receipts_v1(false),
		R144Worker.ACTIVE_STEP_MOTOR_WORK_J,
		R144Worker.SPACE_STEP_SEQUENCE,
		WorldScript.solver_coupled_complete_energy_partition_declaration_v1(),
	)
	if not bool(solver_receipt.get("ok", false)) or not bool(partition.get("ok", false)):
		return {"positive_passed": false, "forced_failure_passed": false}
	var native := {
		"ok": true,
		"measurement": {
			"source_component_receipts": {
				"schema_version": StagingRoute.SOURCE_COMPONENT_RECEIPTS_SCHEMA,
				"solver_energy_exchange_receipt": solver_receipt,
				"solver_energy_exchange_receipt_sha256": R148Worker._sha256(sdk, solver_receipt),
				"solver_coupled_partition_receipt": partition,
				"solver_coupled_partition_receipt_sha256": R148Worker._sha256(sdk, partition),
			}
		},
	}
	var positive := RouteGhostScript.complete_energy_solver_projection_v1(
		native, R144Worker.SPACE_STEP_SEQUENCE, RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
	)
	var mutation := native.duplicate(true)
	var mutation_partition: Dictionary = mutation["measurement"]["source_component_receipts"]["solver_coupled_partition_receipt"]
	mutation_partition["motor_work_also_counted_as_constraint_exchange"] = true
	var rejected := RouteGhostScript.complete_energy_solver_projection_v1(
		mutation, R144Worker.SPACE_STEP_SEQUENCE, RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
	)
	return {
		"positive_passed": bool(positive.get("ok", false)),
		"forced_failure_passed": (
			not bool(rejected.get("ok", true))
			and String(rejected.get("failure_code", ""))
			== "QSDK_ROUTE_GHOST_PARTITION_IDENTITY_INVALID"
		),
	}


static func _valid_sha256(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _true_count(checks: Dictionary) -> int:
	var count := 0
	for value in checks.values():
		count += int(bool(value))
	return count


static func _failure(code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d149_godot_jolt_discrete_staging_live_route_zero_world_v1",
		"gate_id": "QSDK-R24D149",
		"ok": false,
		"failure_code": code,
		"positive_case_count": 5,
		"forced_failure_case_count": 9,
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
