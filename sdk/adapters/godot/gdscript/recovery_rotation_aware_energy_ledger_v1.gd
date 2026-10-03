extends RefCounted
# gdlint: disable=max-line-length

## Pure R162 recovery-ledger integration. The qualified R157 consumer owns the
## native-v6 telemetry validation. This module adds the unchanged R144
## actuator/constraint disjointness rule over the now-complete component set.
## It never constructs or steps a world, and it never treats the mechanical
## energy residual as a source term.

const SolverEnergyExchangeV2Script := preload(
	"res://sdk/adapters/godot/gdscript/recovery_solver_energy_exchange_v2.gd"
)

const LEDGER_PROFILE_ID := (
	"godot_jolt_r24d162_rotation_aware_recovery_energy_ledger_v1"
)
const CAPABILITY_VARIANT_ID := (
	"godot_jolt_r24d162_rotation_aware_discrete_staging_complete_energy_capability_v1"
)
const CONSUMER_CONTRACT_SCHEMA_VERSION := (
	"sporespore_qsdk_r24d157_godot_solver_energy_exchange_contract_v2"
)
const TELEMETRY_SCHEMA_VERSION := (
	"sporespore.godot_jolt_solver_energy_exchange_telemetry.v2"
)
const TELEMETRY_PROFILE_ID := (
	"godot_4_7_jolt_sporespore_solver_energy_exchange_telemetry_v6"
)
const PARTITION_RULE_ID := (
	"godot_jolt_r24d144_solver_joint_exchange_minus_native_motor_work_partition_v1"
)
const ACTUATOR_MAPPING_ID := (
	"godot_jolt_r24d144_solver_coupled_native_constraint_motor_mapping_v1"
)
const WORK_MAPPING_ID := (
	"godot_jolt_r24d144_current_step_native_hinge_motor_work_mapping_v1"
)
const R161_DIAGNOSIS_RAW_SHA256 := (
	"sha256:1f163c137f04b180ebbddbd4774641d54ac145e46bd302a607ea551d6a61984e"
)
const PARTITION_CONTRACT_SCHEMA_VERSION := (
	"sporespore_qsdk_r24d162_godot_rotation_aware_solver_coupled_complete_energy_partition_contract_v1"
)
const PARTITION_DECLARATION_SCHEMA_VERSION := (
	"sporespore_qsdk_r24d162_godot_rotation_aware_solver_coupled_complete_energy_partition_declaration_v1"
)
const PARTITION_NUMERICAL_TERM_COUNT := 14
const NATIVE_FLOAT32_EPSILON := 1.1920928955078125e-7

const ORDERED_ACTUATOR_IDS := [
	"front_left_hip_motor",
	"front_left_knee_motor",
	"front_right_hip_motor",
	"front_right_knee_motor",
	"rear_left_hip_motor",
	"rear_left_knee_motor",
	"rear_right_hip_motor",
	"rear_right_knee_motor",
]
const ORDERED_JOINT_IDS := [
	"front_left_hip",
	"front_left_knee",
	"front_right_hip",
	"front_right_knee",
	"rear_left_hip",
	"rear_left_knee",
	"rear_right_hip",
	"rear_right_knee",
]


static func context_authority_exact_v1(context: Dictionary) -> bool:
	return (
		bool(context.get("rotation_aware_energy_ledger_profile_selected", false))
		and String(context.get("recovery_energy_ledger_profile_id", ""))
		== LEDGER_PROFILE_ID
		and String(context.get("capability_variant_id", ""))
		== CAPABILITY_VARIANT_ID
		and String(context.get("adapter_energy_mapping_profile_id", ""))
		== LEDGER_PROFILE_ID
		and String(context.get("solver_energy_consumer_contract_schema_version", ""))
		== CONSUMER_CONTRACT_SCHEMA_VERSION
		and String(context.get("solver_energy_telemetry_schema_version", ""))
		== TELEMETRY_SCHEMA_VERSION
		and String(context.get("solver_energy_telemetry_profile_id", ""))
		== TELEMETRY_PROFILE_ID
		and String(context.get("r24d161_diagnosis_raw_sha256", ""))
		== R161_DIAGNOSIS_RAW_SHA256
		and String(context.get("partition_rule_id", "")) == PARTITION_RULE_ID
		and bool(context.get("complete_energy_profile_selected", false))
		and bool(context.get("solver_coupled_complete_energy_profile_selected", false))
		and bool(context.get("discrete_staging_complete_energy_profile_selected", false))
	)


static func native_solver_energy_exchange_contract_v1(
	context: Dictionary,
	telemetry_value: Variant,
	expected_space_step_sequence: int,
	uniform_gravity_world_m_s2: Vector3,
) -> Dictionary:
	if not context_authority_exact_v1(context):
		return _failure("QSDK_R24D162_RECOVERY_LEDGER_AUTHORITY_CROSSED")
	var receipt := SolverEnergyExchangeV2Script.native_solver_energy_exchange_contract_v2(
		telemetry_value,
		expected_space_step_sequence,
		uniform_gravity_world_m_s2,
	)
	if not bool(receipt.get("ok", false)):
		return receipt
	var integrated := receipt.duplicate(true)
	integrated["recovery_energy_ledger_profile_id"] = LEDGER_PROFILE_ID
	integrated["qualified_consumer_contract_schema_version"] = (
		CONSUMER_CONTRACT_SCHEMA_VERSION
	)
	integrated["rotation_aware_energy_ledger_profile_selected"] = true
	integrated["legacy_solver_energy_consumer_selected"] = false
	integrated["r24d161_diagnosis_raw_sha256"] = R161_DIAGNOSIS_RAW_SHA256
	return integrated


static func partition_declaration_v1() -> Dictionary:
	return {
		"schema_version": PARTITION_DECLARATION_SCHEMA_VERSION,
		"recovery_energy_ledger_profile_id": LEDGER_PROFILE_ID,
		"partition_rule_id": PARTITION_RULE_ID,
		"actuator_mapping_id": ACTUATOR_MAPPING_ID,
		"work_mapping_id": WORK_MAPPING_ID,
		"joint_velocity_exchange_includes_native_motor_work": true,
		"subtract_native_motor_work_exactly_once": true,
		"rotation_integration_exchange_included_exactly_once": true,
		"motor_work_also_counted_as_constraint_exchange": false,
		"whole_step_mechanical_residual_used_as_work_source": false,
		"numerical_bound_kind": "deterministic_ieee754_binary32_forward_error_bound",
		"numerical_term_count": PARTITION_NUMERICAL_TERM_COUNT,
		"native_float32_epsilon": NATIVE_FLOAT32_EPSILON,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func solver_coupled_complete_energy_partition_contract_v1(
	context: Dictionary,
	solver_receipt: Dictionary,
	ordered_motor_receipts: Array,
	step_actuator_work_j: float,
	expected_space_step_sequence: int,
	declaration: Dictionary,
) -> Dictionary:
	if not context_authority_exact_v1(context):
		return _failure("QSDK_R24D162_RECOVERY_LEDGER_AUTHORITY_CROSSED")
	if declaration != partition_declaration_v1():
		return _failure("QSDK_R24D162_PARTITION_DECLARATION_INVALID")
	if (
		String(solver_receipt.get("schema_version", ""))
		!= CONSUMER_CONTRACT_SCHEMA_VERSION
		or not bool(solver_receipt.get("ok", false))
		or expected_space_step_sequence <= 0
		or int(solver_receipt.get("expected_space_step_sequence", -1))
		!= expected_space_step_sequence
		or int(solver_receipt.get("capture_space_step_sequence", -1))
		!= expected_space_step_sequence
		or int(solver_receipt.get("read_space_step_sequence", -1))
		!= expected_space_step_sequence
		or String(solver_receipt.get("recovery_energy_ledger_profile_id", ""))
		!= LEDGER_PROFILE_ID
		or String(solver_receipt.get("qualified_consumer_contract_schema_version", ""))
		!= CONSUMER_CONTRACT_SCHEMA_VERSION
		or String(solver_receipt.get("telemetry_schema_version", ""))
		!= TELEMETRY_SCHEMA_VERSION
		or String(solver_receipt.get("telemetry_profile_id", "")) != TELEMETRY_PROFILE_ID
		or not bool(solver_receipt.get("rotation_aware_energy_ledger_profile_selected", false))
		or bool(solver_receipt.get("legacy_solver_energy_consumer_selected", true))
		or String(solver_receipt.get("r24d161_diagnosis_raw_sha256", ""))
		!= R161_DIAGNOSIS_RAW_SHA256
		or not bool(solver_receipt.get("rotation_integration_partition_complete", false))
		or not bool(solver_receipt.get("source_measurement", false))
		or bool(solver_receipt.get("mechanical_energy_residual_used_as_work_source", true))
	):
		return _failure("QSDK_R24D162_SOLVER_RECEIPT_IDENTITY_INVALID")
	if ordered_motor_receipts.size() != ORDERED_ACTUATOR_IDS.size():
		return _failure("QSDK_R24D162_MOTOR_RECEIPT_POPULATION_INVALID")

	var motor_work_sum := 0.0
	var motor_absolute_work_sum := 0.0
	for index in range(ordered_motor_receipts.size()):
		var row_value: Variant = ordered_motor_receipts[index]
		if not (row_value is Dictionary):
			return _failure("QSDK_R24D162_MOTOR_RECEIPT_INVALID:%d" % index)
		var row: Dictionary = row_value
		if (
			String(row.get("actuator_id", "")) != ORDERED_ACTUATOR_IDS[index]
			or String(row.get("joint_id", "")) != ORDERED_JOINT_IDS[index]
			or String(row.get("actuator_mapping_id", "")) != ACTUATOR_MAPPING_ID
			or String(row.get("work_mapping_id", "")) != WORK_MAPPING_ID
			or int(row.get("capture_space_step_sequence", -1))
			!= expected_space_step_sequence
			or int(row.get("read_space_step_sequence", -1))
			!= expected_space_step_sequence
			or typeof(row.get("net_motor_work_j")) not in [TYPE_FLOAT, TYPE_INT]
			or not is_finite(float(row.get("net_motor_work_j", NAN)))
			or not bool(row.get("source_measurement", false))
			or bool(row.get("mechanical_energy_residual_used_as_work_source", true))
		):
			return _failure("QSDK_R24D162_MOTOR_RECEIPT_IDENTITY_INVALID:%d" % index)
		var motor_work := float(row["net_motor_work_j"])
		motor_work_sum += motor_work
		motor_absolute_work_sum += absf(motor_work)
	if not is_finite(step_actuator_work_j) or motor_work_sum != step_actuator_work_j:
		return _failure("QSDK_R24D162_MOTOR_WORK_AGGREGATE_INVALID")

	var required_fields := [
		"joint_velocity_constraint_exchange_j",
		"contact_velocity_constraint_exchange_j",
		"rotation_integration_kinetic_exchange_j",
		"position_constraint_kinetic_exchange_j",
		"position_constraint_potential_exchange_j",
		"step_signed_constraint_exchange_j",
	]
	for key in required_fields:
		if (
			typeof(solver_receipt.get(key)) not in [TYPE_FLOAT, TYPE_INT]
			or not is_finite(float(solver_receipt.get(key, NAN)))
		):
			return _failure("QSDK_R24D162_SOLVER_COMPONENT_NONFINITE:%s" % key)

	var joint_exchange := float(solver_receipt["joint_velocity_constraint_exchange_j"])
	var contact_exchange := float(solver_receipt["contact_velocity_constraint_exchange_j"])
	var rotation_exchange := float(
		solver_receipt["rotation_integration_kinetic_exchange_j"]
	)
	var position_kinetic_exchange := float(
		solver_receipt["position_constraint_kinetic_exchange_j"]
	)
	var position_potential_exchange := float(
		solver_receipt["position_constraint_potential_exchange_j"]
	)
	var raw_solver_exchange := float(solver_receipt["step_signed_constraint_exchange_j"])
	var nonmotor_joint_exchange := joint_exchange - motor_work_sum
	var signed_constraint_exchange := (
		nonmotor_joint_exchange
		+ contact_exchange
		+ rotation_exchange
		+ position_kinetic_exchange
		+ position_potential_exchange
	)
	var raw_component_reconstruction := (
		joint_exchange
		+ contact_exchange
		+ rotation_exchange
		+ position_kinetic_exchange
		+ position_potential_exchange
	)
	var partition_reconstruction := motor_work_sum + signed_constraint_exchange
	var absolute_term_sum := (
		motor_absolute_work_sum
		+ absf(joint_exchange)
		+ absf(contact_exchange)
		+ absf(rotation_exchange)
		+ absf(position_kinetic_exchange)
		+ absf(position_potential_exchange)
	)
	var n := float(PARTITION_NUMERICAL_TERM_COUNT)
	var denominator := 1.0 - n * NATIVE_FLOAT32_EPSILON
	if denominator <= 0.0:
		return _failure("QSDK_R24D162_NUMERICAL_BOUND_DOMAIN_INVALID")
	var gamma_n := n * NATIVE_FLOAT32_EPSILON / denominator
	var consistency_bound := (
		(2.0 * gamma_n + NATIVE_FLOAT32_EPSILON) * maxf(absolute_term_sum, 1.0)
	)
	var raw_component_delta := raw_component_reconstruction - raw_solver_exchange
	var partition_reconstruction_delta := partition_reconstruction - raw_solver_exchange
	if (
		not is_finite(nonmotor_joint_exchange)
		or not is_finite(signed_constraint_exchange)
		or not is_finite(consistency_bound)
		or absf(raw_component_delta) > consistency_bound
		or absf(partition_reconstruction_delta) > consistency_bound
	):
		return _failure(
			"QSDK_R24D162_CONSTRAINT_PARTITION_RECONSTRUCTION_INVALID",
			{
				"raw_component_delta_j": raw_component_delta,
				"partition_reconstruction_delta_j": partition_reconstruction_delta,
				"numerical_consistency_bound_j": consistency_bound,
			},
		)

	return {
		"schema_version": PARTITION_CONTRACT_SCHEMA_VERSION,
		"ok": true,
		"recovery_energy_ledger_profile_id": LEDGER_PROFILE_ID,
		"partition_rule_id": PARTITION_RULE_ID,
		"expected_space_step_sequence": expected_space_step_sequence,
		"motor_receipt_count": ordered_motor_receipts.size(),
		"step_actuator_work_j": motor_work_sum,
		"motor_absolute_work_sum_j": motor_absolute_work_sum,
		"raw_joint_velocity_constraint_exchange_j": joint_exchange,
		"nonmotor_joint_constraint_exchange_j": nonmotor_joint_exchange,
		"contact_velocity_constraint_exchange_j": contact_exchange,
		"rotation_integration_kinetic_exchange_j": rotation_exchange,
		"position_constraint_kinetic_exchange_j": position_kinetic_exchange,
		"position_constraint_potential_exchange_j": position_potential_exchange,
		"raw_step_signed_solver_exchange_j": raw_solver_exchange,
		"step_signed_constraint_exchange_j": signed_constraint_exchange,
		"raw_component_reconstruction_delta_j": raw_component_delta,
		"partition_reconstruction_delta_j": partition_reconstruction_delta,
		"numerical_bound_kind": "deterministic_ieee754_binary32_forward_error_bound",
		"numerical_term_count": PARTITION_NUMERICAL_TERM_COUNT,
		"native_float32_epsilon": NATIVE_FLOAT32_EPSILON,
		"numerical_consistency_bound_j": consistency_bound,
		"joint_velocity_exchange_includes_native_motor_work": true,
		"native_motor_work_subtracted_exactly_once": true,
		"rotation_integration_exchange_included_exactly_once": true,
		"motor_work_also_counted_as_constraint_exchange": false,
		"constraint_exchange_partition_disjoint": true,
		"rotation_integration_partition_complete": true,
		"component_partition_complete": true,
		"source_measurement": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": PARTITION_CONTRACT_SCHEMA_VERSION,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
