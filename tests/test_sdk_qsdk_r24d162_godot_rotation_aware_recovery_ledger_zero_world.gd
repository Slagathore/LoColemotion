extends SceneTree
# gdlint: disable=max-line-length

## Compact R162 recovery-ledger integration gate. It calls the same route,
## consumer selector, and actuator/constraint partition selector used by the
## production native sampler. Every input is synthetic: no Node, RID, model,
## world, native read, native write, or solver step is created or executed.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const WorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const LedgerScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_rotation_aware_energy_ledger_v1.gd"
)
const ProfileScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D162_GODOT_ROTATION_AWARE_RECOVERY_LEDGER_ZERO_WORLD "
const SPACE_STEP_SEQUENCE := 7
const STEP_ACTUATOR_WORK_J := 0.25
const V1_RAW_SOLVER_EXCHANGE_J := 2.35125
const V2_RAW_SOLVER_EXCHANGE_J := 2.3825
const V1_PARTITIONED_CONSTRAINT_EXCHANGE_J := 2.10125
const V2_PARTITIONED_CONSTRAINT_EXCHANGE_J := 2.1325


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D162_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D162_SDK_INSTANTIATION_FAILED")

	var context := RouteScript.prepare_complete_energy_context_v11(
		sdk, RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	if (
		not bool(context.get("ok", false))
		or not RouteScript.rotation_aware_energy_ledger_context_binding_exact_v1(context)
		or not LedgerScript.context_authority_exact_v1(context)
		or bool(context.get("physical_world_construction_authorized", true))
		or context.has("physical_world_construction_gate_id")
		or bool(context.get("finite_behavior_pair_selected", true))
	):
		return _failure("QSDK_R24D162_CONTEXT_POSITIVE_INVALID", context)

	var profile_receipt: Dictionary = context.get("runtime_profile_receipt", {})
	var validation: Dictionary = profile_receipt.get("validation", {})
	if (
		String(profile_receipt.get("profile_id", ""))
		!= ProfileScript.ROTATION_AWARE_COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID
		or String(context.get("capability_variant_id", "")) != LedgerScript.CAPABILITY_VARIANT_ID
		or String(context.get("adapter_energy_mapping_profile_id", ""))
		!= LedgerScript.LEDGER_PROFILE_ID
		or String(context.get("energy_route_id", "")) != RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
		or String(context.get("energy_mapping_profile_id", ""))
		!= RouteScript.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		or String(context.get("partition_rule_id", "")) != RouteScript.R144_PARTITION_RULE_ID
		or int(validation.get("changed_channel_count", -1)) != 1
		or validation.get("changed_channel_ids", []) != ["energy_balance_ledger"]
		or not bool(validation.get("rotation_aware_energy_ledger_profile_selected", false))
	):
		return _failure("QSDK_R24D162_CAPABILITY_SCOPE_INVALID", profile_receipt)

	var gravity := Vector3(0.0, -9.81, 0.0)
	var selected_solver := WorldScript.native_solver_energy_exchange_for_recovery_route_v2(
		context,
		_telemetry_v2(),
		SPACE_STEP_SEQUENCE,
		gravity,
	)
	if (
		not bool(selected_solver.get("ok", false))
		or String(selected_solver.get("schema_version", ""))
		!= LedgerScript.CONSUMER_CONTRACT_SCHEMA_VERSION
		or String(selected_solver.get("recovery_energy_ledger_profile_id", ""))
		!= LedgerScript.LEDGER_PROFILE_ID
		or float(selected_solver.get("rotation_integration_kinetic_exchange_j", NAN)) != 0.03125
		or not is_equal_approx(
			float(selected_solver.get("step_signed_constraint_exchange_j", NAN)),
			V2_RAW_SOLVER_EXCHANGE_J,
		)
		or not bool(selected_solver.get("rotation_integration_partition_complete", false))
		or not bool(selected_solver.get("rotation_aware_energy_ledger_profile_selected", false))
		or bool(selected_solver.get("legacy_solver_energy_consumer_selected", true))
	):
		return _failure("QSDK_R24D162_SELECTED_CONSUMER_INVALID", selected_solver)

	var motor_receipts := _motor_receipts_v1()
	var selected_partition := (
		WorldScript.solver_coupled_complete_energy_partition_for_recovery_route_v2(
			context,
			selected_solver,
			motor_receipts,
			STEP_ACTUATOR_WORK_J,
			SPACE_STEP_SEQUENCE,
		)
	)
	if (
		not bool(selected_partition.get("ok", false))
		or String(selected_partition.get("schema_version", ""))
		!= LedgerScript.PARTITION_CONTRACT_SCHEMA_VERSION
		or int(selected_partition.get("numerical_term_count", -1)) != 14
		or not is_equal_approx(
			float(selected_partition.get("raw_step_signed_solver_exchange_j", NAN)),
			V2_RAW_SOLVER_EXCHANGE_J,
		)
		or float(selected_partition.get("step_actuator_work_j", NAN)) != STEP_ACTUATOR_WORK_J
		or not is_equal_approx(
			float(selected_partition.get("step_signed_constraint_exchange_j", NAN)),
			V2_PARTITIONED_CONSTRAINT_EXCHANGE_J,
		)
		or float(selected_partition.get("rotation_integration_kinetic_exchange_j", NAN))
		!= 0.03125
		or not bool(selected_partition.get("rotation_integration_exchange_included_exactly_once", false))
		or not bool(selected_partition.get("native_motor_work_subtracted_exactly_once", false))
		or bool(selected_partition.get("motor_work_also_counted_as_constraint_exchange", true))
		or not bool(selected_partition.get("component_partition_complete", false))
	):
		return _failure("QSDK_R24D162_SELECTED_PARTITION_INVALID", selected_partition)

	var legacy_context: Dictionary = {}
	var legacy_solver := WorldScript.native_solver_energy_exchange_for_recovery_route_v2(
		legacy_context,
		_telemetry_v1(),
		SPACE_STEP_SEQUENCE,
		gravity,
	)
	if (
		not bool(legacy_solver.get("ok", false))
		or String(legacy_solver.get("schema_version", ""))
		!= "sporespore_qsdk_r24d136_godot_solver_energy_exchange_contract_v1"
		or legacy_solver.has("rotation_integration_kinetic_exchange_j")
		or legacy_solver.has("recovery_energy_ledger_profile_id")
		or not is_equal_approx(
			float(legacy_solver.get("step_signed_constraint_exchange_j", NAN)),
			V1_RAW_SOLVER_EXCHANGE_J,
		)
	):
		return _failure("QSDK_R24D162_LEGACY_CONSUMER_CHANGED", legacy_solver)
	var legacy_partition := (
		WorldScript.solver_coupled_complete_energy_partition_for_recovery_route_v2(
			legacy_context,
			legacy_solver,
			motor_receipts,
			STEP_ACTUATOR_WORK_J,
			SPACE_STEP_SEQUENCE,
		)
	)
	if (
		not bool(legacy_partition.get("ok", false))
		or String(legacy_partition.get("schema_version", ""))
		!= "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_partition_contract_v1"
		or int(legacy_partition.get("numerical_term_count", -1)) != 13
		or legacy_partition.has("rotation_integration_kinetic_exchange_j")
		or legacy_partition.has("recovery_energy_ledger_profile_id")
		or not is_equal_approx(
			float(legacy_partition.get("step_signed_constraint_exchange_j", NAN)),
			V1_PARTITIONED_CONSTRAINT_EXCHANGE_J,
		)
	):
		return _failure("QSDK_R24D162_LEGACY_PARTITION_CHANGED", legacy_partition)

	var consumer_rejections := _consumer_rejection_count_v1(context, gravity)
	var partition_rejections := _partition_rejection_count_v1(
		context, selected_solver, motor_receipts
	)
	var selector_rejections := _selector_rejection_count_v1(gravity)
	var forced_failure_case_count := (
		consumer_rejections + partition_rejections + selector_rejections
	)
	var expected_forced_failure_case_count := 10
	var positive_case_count := 6
	var exact := forced_failure_case_count == expected_forced_failure_case_count
	return {
		"schema_version": "sporespore_qsdk_r24d162_godot_rotation_aware_recovery_ledger_zero_world_v1",
		"gate_id": "QSDK-R24D162",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D162_ZERO_WORLD_CONJUNCTION_INVALID",
		"status": "passed_zero_world_rotation_aware_recovery_ledger_integration",
		"ledger_scope": {
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_zero_world_implementation_qualification",
			"question_class": "development",
		},
		"question_class": "development",
		"runtime_profile_id": ProfileScript.ROTATION_AWARE_COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID,
		"capability_variant_id": LedgerScript.CAPABILITY_VARIANT_ID,
		"recovery_energy_ledger_profile_id": LedgerScript.LEDGER_PROFILE_ID,
		"consumer_contract_schema_version": LedgerScript.CONSUMER_CONTRACT_SCHEMA_VERSION,
		"telemetry_schema_version": LedgerScript.TELEMETRY_SCHEMA_VERSION,
		"telemetry_profile_id": LedgerScript.TELEMETRY_PROFILE_ID,
		"partition_contract_schema_version": LedgerScript.PARTITION_CONTRACT_SCHEMA_VERSION,
		"partition_rule_id": LedgerScript.PARTITION_RULE_ID,
		"selected_rotation_exchange_j": float(
			selected_solver["rotation_integration_kinetic_exchange_j"]
		),
		"selected_raw_solver_exchange_j": float(
			selected_partition["raw_step_signed_solver_exchange_j"]
		),
		"selected_partitioned_constraint_exchange_j": float(
			selected_partition["step_signed_constraint_exchange_j"]
		),
		"legacy_raw_solver_exchange_j": float(legacy_solver["step_signed_constraint_exchange_j"]),
		"legacy_partitioned_constraint_exchange_j": float(
			legacy_partition["step_signed_constraint_exchange_j"]
		),
		"rotation_integration_exchange_included_exactly_once": true,
		"native_motor_work_subtracted_exactly_once": true,
		"motor_work_also_counted_as_constraint_exchange": false,
		"legacy_consumer_preserved": true,
		"legacy_partition_preserved": true,
		"production_consumer_selector_exercised": true,
		"production_partition_selector_exercised": true,
		"consumer_rejection_count": consumer_rejections,
		"partition_rejection_count": partition_rejections,
		"selector_rejection_count": selector_rejections,
		"positive_case_count": positive_case_count,
		"forced_failure_case_count": forced_failure_case_count,
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


static func _telemetry_v2() -> Dictionary:
	var value := _telemetry_common_v1()
	value["schema"] = LedgerScript.TELEMETRY_SCHEMA_VERSION
	value["profile_id"] = LedgerScript.TELEMETRY_PROFILE_ID
	value["rotation_integration_kinetic_exchange_j"] = 0.03125
	value["rotation_integration_expected_active_body_count"] = 13
	value["rotation_integration_observed_active_body_count"] = 13
	value["rotation_integration_dynamic_body_count"] = 13
	value["rotation_integration_invalid_body_measurement_count"] = 0
	value["dynamic_body_observation_count"] = 52
	return value


static func _telemetry_v1() -> Dictionary:
	var value := _telemetry_common_v1()
	value["schema"] = "sporespore.godot_jolt_solver_energy_exchange_telemetry.v1"
	value["profile_id"] = "godot_4_7_jolt_sporespore_solver_energy_exchange_telemetry_v1"
	return value


static func _telemetry_common_v1() -> Dictionary:
	return {
		"telemetry_sequence": 11,
		"capture_space_step_sequence": SPACE_STEP_SEQUENCE,
		"read_space_step_sequence": SPACE_STEP_SEQUENCE,
		"captured_during_active_step": true,
		"snapshot_is_current_space_step": true,
		"joint_velocity_constraint_exchange_j": 0.75,
		"contact_velocity_constraint_exchange_j": -0.125,
		"position_constraint_kinetic_exchange_j": 0.5,
		"position_constraint_mass_weighted_displacement_kg_m": Vector3(0.0, 0.125, 0.0),
		"collision_step_count": 1,
		"constrained_island_count": 2,
		"velocity_measured_island_count": 2,
		"position_measured_island_count": 2,
		"joint_velocity_phase_count": 2,
		"contact_velocity_phase_count": 2,
		"position_constraint_phase_count": 2,
		"dynamic_body_observation_count": 13,
		"invalid_body_measurement_count": 0,
		"large_island_velocity_batch_count": 0,
		"large_island_position_batch_count": 0,
		"ccd_active_body_count": 0,
		"active_soft_body_count": 0,
		"update_error_bits": 0,
		"complete": true,
		"source_measurement": true,
		"mechanical_energy_residual_used_as_work_source": false,
	}


static func _motor_receipts_v1() -> Array:
	var rows: Array = []
	for index in range(LedgerScript.ORDERED_ACTUATOR_IDS.size()):
		rows.append(
			{
				"actuator_id": String(LedgerScript.ORDERED_ACTUATOR_IDS[index]),
				"joint_id": String(LedgerScript.ORDERED_JOINT_IDS[index]),
				"actuator_mapping_id": LedgerScript.ACTUATOR_MAPPING_ID,
				"work_mapping_id": LedgerScript.WORK_MAPPING_ID,
				"capture_space_step_sequence": SPACE_STEP_SEQUENCE,
				"read_space_step_sequence": SPACE_STEP_SEQUENCE,
				"net_motor_work_j": 0.03125,
				"source_measurement": true,
				"mechanical_energy_residual_used_as_work_source": false,
			}
		)
	return rows


static func _consumer_rejection_count_v1(context: Dictionary, gravity: Vector3) -> int:
	var mutations: Array = []
	var missing_rotation := _telemetry_v2()
	missing_rotation.erase("rotation_integration_kinetic_exchange_j")
	mutations.append(missing_rotation)
	var stale_capture := _telemetry_v2()
	stale_capture["capture_space_step_sequence"] = SPACE_STEP_SEQUENCE - 1
	mutations.append(stale_capture)
	var stale_read := _telemetry_v2()
	stale_read["read_space_step_sequence"] = SPACE_STEP_SEQUENCE + 1
	mutations.append(stale_read)
	var incomplete := _telemetry_v2()
	incomplete["complete"] = false
	mutations.append(incomplete)
	var crossed_profile := _telemetry_v2()
	crossed_profile["profile_id"] = "wrong"
	mutations.append(crossed_profile)
	var rejected := 0
	for mutation in mutations:
		var receipt := WorldScript.native_solver_energy_exchange_for_recovery_route_v2(
			context, mutation, SPACE_STEP_SEQUENCE, gravity
		)
		rejected += int(_zero_world_refusal_v1(receipt))
	return rejected


static func _partition_rejection_count_v1(
	context: Dictionary,
	solver_receipt: Dictionary,
	motor_receipts: Array,
) -> int:
	var rejected := 0
	var missing_motor := motor_receipts.duplicate(true)
	missing_motor.pop_back()
	rejected += int(
		_zero_world_refusal_v1(
			WorldScript.solver_coupled_complete_energy_partition_for_recovery_route_v2(
				context, solver_receipt, missing_motor, STEP_ACTUATOR_WORK_J, SPACE_STEP_SEQUENCE
			)
		)
	)
	var stale_motor := motor_receipts.duplicate(true)
	(stale_motor[0] as Dictionary)["read_space_step_sequence"] = SPACE_STEP_SEQUENCE - 1
	rejected += int(
		_zero_world_refusal_v1(
			WorldScript.solver_coupled_complete_energy_partition_for_recovery_route_v2(
				context, solver_receipt, stale_motor, STEP_ACTUATOR_WORK_J, SPACE_STEP_SEQUENCE
			)
		)
	)
	var missing_rotation := solver_receipt.duplicate(true)
	missing_rotation.erase("rotation_integration_kinetic_exchange_j")
	rejected += int(
		_zero_world_refusal_v1(
			WorldScript.solver_coupled_complete_energy_partition_for_recovery_route_v2(
				context, missing_rotation, motor_receipts, STEP_ACTUATOR_WORK_J, SPACE_STEP_SEQUENCE
			)
		)
	)
	return rejected


static func _selector_rejection_count_v1(gravity: Vector3) -> int:
	var partial_context := {
		"recovery_energy_ledger_profile_id": LedgerScript.LEDGER_PROFILE_ID,
	}
	var partial := WorldScript.native_solver_energy_exchange_for_recovery_route_v2(
		partial_context, _telemetry_v1(), SPACE_STEP_SEQUENCE, gravity
	)
	var crossed_context := {
		"rotation_aware_energy_ledger_profile_selected": true,
		"recovery_energy_ledger_profile_id": LedgerScript.LEDGER_PROFILE_ID,
		"capability_variant_id": LedgerScript.CAPABILITY_VARIANT_ID,
		"solver_energy_consumer_contract_schema_version": LedgerScript.CONSUMER_CONTRACT_SCHEMA_VERSION,
		"solver_energy_telemetry_schema_version": LedgerScript.TELEMETRY_SCHEMA_VERSION,
		"solver_energy_telemetry_profile_id": LedgerScript.TELEMETRY_PROFILE_ID,
		"r24d161_diagnosis_raw_sha256": "sha256:wrong",
		"partition_rule_id": LedgerScript.PARTITION_RULE_ID,
		"complete_energy_profile_selected": true,
		"solver_coupled_complete_energy_profile_selected": true,
		"discrete_staging_complete_energy_profile_selected": true,
	}
	var crossed := WorldScript.native_solver_energy_exchange_for_recovery_route_v2(
		crossed_context, _telemetry_v2(), SPACE_STEP_SEQUENCE, gravity
	)
	return int(_zero_world_refusal_v1(partial)) + int(_zero_world_refusal_v1(crossed))


static func _zero_world_refusal_v1(value: Dictionary) -> bool:
	return (
		not bool(value.get("ok", true))
		and int(value.get("model_construction_count", -1)) == 0
		and int(value.get("world_attempt_count", -1)) == 0
		and int(value.get("world_build_count", -1)) == 0
		and int(value.get("solver_step_count", -1)) == 0
		and not bool(value.get("physics_state_modified", true))
		and not bool(value.get("physical_acceptance_authority", true))
		and not bool(value.get("release_authority", true))
	)


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d162_godot_rotation_aware_recovery_ledger_zero_world_v1",
		"gate_id": "QSDK-R24D162",
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
