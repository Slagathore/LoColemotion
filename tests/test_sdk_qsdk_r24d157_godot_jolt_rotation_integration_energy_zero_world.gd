extends SceneTree

## R157 is deliberately zero-world. It proves that the exact native method is
## registered, refuses an invalid RID, and that the shared v2 consumer accepts
## one complete synthetic snapshot while rejecting coverage/completeness
## mutations. It does not claim that native field population was observed;
## that requires the separately authorized one-world/two-step route smoke.

const ContractScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_solver_energy_exchange_v2.gd"
)
const MARKER := "QSDK_R24D157_GODOT_JOLT_ROTATION_INTEGRATION_ENERGY_ZERO_WORLD "
const TELEMETRY_CLASS_NAME := &"JoltPhysicsServer3D"
const TELEMETRY_METHOD_NAME := &"space_get_solver_energy_exchange_telemetry"
const EXPECTED_SPACE_STEP_SEQUENCE := 7
const EXPECTED_STEP_CONSTRAINT_EXCHANGE_J := 2.3825


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JSON.stringify(result, "", false, true))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var class_registered := ClassDB.class_exists(TELEMETRY_CLASS_NAME)
	var method_registered := (
		class_registered
		and ClassDB.class_has_method(TELEMETRY_CLASS_NAME, TELEMETRY_METHOD_NAME)
	)
	if not method_registered:
		return _failure("QSDK_R24D157_NATIVE_METHOD_UNAVAILABLE")

	var invalid_rid_value: Variant = ClassDB.class_call_static(
		TELEMETRY_CLASS_NAME,
		TELEMETRY_METHOD_NAME,
		RID(),
	)
	var invalid_rid_refused := invalid_rid_value == null
	if not invalid_rid_refused:
		return _failure("QSDK_R24D157_INVALID_RID_NOT_REFUSED")

	var gravity := Vector3(0.0, -9.81, 0.0)
	var accepted := ContractScript.native_solver_energy_exchange_contract_v2(
		_telemetry_v2(),
		EXPECTED_SPACE_STEP_SEQUENCE,
		gravity,
	)
	if (
		not bool(accepted.get("ok", false))
		or int(accepted.get("check_count", -1)) != 38
		or not is_equal_approx(
			float(accepted.get("step_signed_constraint_exchange_j", NAN)),
			EXPECTED_STEP_CONSTRAINT_EXCHANGE_J,
		)
		or not bool(accepted.get("rotation_integration_partition_complete", false))
	):
		return _failure("QSDK_R24D157_SYNTHETIC_POSITIVE_INVALID", accepted)

	var mutation_rejection_count := _mutation_rejection_count_v1(gravity)
	var expected_mutation_rejection_count := 17
	if mutation_rejection_count != expected_mutation_rejection_count:
		return _failure(
			"QSDK_R24D157_MUTATION_REJECTION_COUNT_INVALID",
			{
				"observed": mutation_rejection_count,
				"expected": expected_mutation_rejection_count,
			},
		)

	return {
		"schema_version": (
			"sporespore_qsdk_r24d157_godot_jolt_rotation_integration_energy_zero_world_v1"
		),
		"gate_id": "QSDK-R24D157",
		"ok": true,
		"status": "passed_zero_world_native_v6_binding_and_consumer_controls",
		"telemetry_class_registered": class_registered,
		"telemetry_method_registered": method_registered,
		"invalid_rid_refusal_observed": invalid_rid_refused,
		"telemetry_schema_version": ContractScript.TELEMETRY_SCHEMA_VERSION,
		"telemetry_profile_id": ContractScript.TELEMETRY_PROFILE_ID,
		"consumer_contract_schema_version": ContractScript.CONTRACT_SCHEMA_VERSION,
		"synthetic_rotation_exchange_j": float(
			accepted["rotation_integration_kinetic_exchange_j"]
		),
		"synthetic_step_constraint_exchange_j": float(
			accepted["step_signed_constraint_exchange_j"]
		),
		"consumer_check_count": int(accepted["check_count"]),
		"consumer_mutation_rejection_count": mutation_rejection_count,
		"native_field_population_observed": false,
		"native_field_population_claimed": false,
		"native_field_population_requires_physical_step": true,
		"positive_case_count": 2,
		"forced_failure_case_count": mutation_rejection_count + 1,
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
	return {
		"schema": ContractScript.TELEMETRY_SCHEMA_VERSION,
		"profile_id": ContractScript.TELEMETRY_PROFILE_ID,
		"telemetry_sequence": 11,
		"capture_space_step_sequence": EXPECTED_SPACE_STEP_SEQUENCE,
		"read_space_step_sequence": EXPECTED_SPACE_STEP_SEQUENCE,
		"captured_during_active_step": true,
		"snapshot_is_current_space_step": true,
		"joint_velocity_constraint_exchange_j": 0.75,
		"contact_velocity_constraint_exchange_j": -0.125,
		"rotation_integration_kinetic_exchange_j": 0.03125,
		"position_constraint_kinetic_exchange_j": 0.5,
		"position_constraint_mass_weighted_displacement_kg_m": Vector3(0.0, 0.125, 0.0),
		"collision_step_count": 1,
		"constrained_island_count": 2,
		"velocity_measured_island_count": 2,
		"position_measured_island_count": 2,
		"joint_velocity_phase_count": 2,
		"contact_velocity_phase_count": 2,
		"position_constraint_phase_count": 2,
		"rotation_integration_expected_active_body_count": 13,
		"rotation_integration_observed_active_body_count": 13,
		"rotation_integration_dynamic_body_count": 13,
		"rotation_integration_invalid_body_measurement_count": 0,
		"dynamic_body_observation_count": 52,
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


static func _mutation_rejection_count_v1(gravity: Vector3) -> int:
	var mutations: Array = [null]
	var wrong_schema := _telemetry_v2()
	wrong_schema["schema"] = "wrong"
	mutations.append(wrong_schema)
	var wrong_profile := _telemetry_v2()
	wrong_profile["profile_id"] = "wrong"
	mutations.append(wrong_profile)
	var missing_rotation := _telemetry_v2()
	missing_rotation.erase("rotation_integration_kinetic_exchange_j")
	mutations.append(missing_rotation)
	var nonfinite_rotation := _telemetry_v2()
	nonfinite_rotation["rotation_integration_kinetic_exchange_j"] = NAN
	mutations.append(nonfinite_rotation)
	var stale_capture := _telemetry_v2()
	stale_capture["capture_space_step_sequence"] = EXPECTED_SPACE_STEP_SEQUENCE - 1
	mutations.append(stale_capture)
	var stale_read := _telemetry_v2()
	stale_read["read_space_step_sequence"] = EXPECTED_SPACE_STEP_SEQUENCE + 1
	mutations.append(stale_read)
	var missing_expectation := _telemetry_v2()
	missing_expectation["rotation_integration_expected_active_body_count"] = 0
	mutations.append(missing_expectation)
	var incomplete_population := _telemetry_v2()
	incomplete_population["rotation_integration_observed_active_body_count"] = 12
	mutations.append(incomplete_population)
	var no_dynamic_rotation := _telemetry_v2()
	no_dynamic_rotation["rotation_integration_dynamic_body_count"] = 0
	mutations.append(no_dynamic_rotation)
	var impossible_dynamic_population := _telemetry_v2()
	impossible_dynamic_population["rotation_integration_dynamic_body_count"] = 14
	mutations.append(impossible_dynamic_population)
	var invalid_rotation_measurement := _telemetry_v2()
	invalid_rotation_measurement["rotation_integration_invalid_body_measurement_count"] = 1
	mutations.append(invalid_rotation_measurement)
	var native_incomplete := _telemetry_v2()
	native_incomplete["complete"] = false
	mutations.append(native_incomplete)
	var synthetic_source := _telemetry_v2()
	synthetic_source["source_measurement"] = false
	mutations.append(synthetic_source)
	var residual_source := _telemetry_v2()
	residual_source["mechanical_energy_residual_used_as_work_source"] = true
	mutations.append(residual_source)
	var invalid_displacement := _telemetry_v2()
	invalid_displacement["position_constraint_mass_weighted_displacement_kg_m"] = {
		"x": 0.0, "y": 0.125, "z": 0.0
	}
	mutations.append(invalid_displacement)
	var invalid_general_measurement := _telemetry_v2()
	invalid_general_measurement["invalid_body_measurement_count"] = 1
	mutations.append(invalid_general_measurement)

	var rejected := 0
	for mutation in mutations:
		var receipt := ContractScript.native_solver_energy_exchange_contract_v2(
			mutation,
			EXPECTED_SPACE_STEP_SEQUENCE,
			gravity,
		)
		rejected += int(_zero_world_refusal_v1(receipt))
	return rejected


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
		"schema_version": (
			"sporespore_qsdk_r24d157_godot_jolt_rotation_integration_energy_zero_world_v1"
		),
		"gate_id": "QSDK-R24D157",
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
