extends RefCounted

## Pure consumer for the v6 native solver-energy snapshot. This successor keeps
## the observed R136 v1 contract intact while adding the independently measured
## rotation-integration boundary. Production and zero-world qualification call
## this same function; missing, stale, nonfinite, or incomplete telemetry is
## refused instead of being projected as zero work.

const TELEMETRY_SCHEMA_VERSION := (
	"sporespore.godot_jolt_solver_energy_exchange_telemetry.v2"
)
const TELEMETRY_PROFILE_ID := (
	"godot_4_7_jolt_sporespore_solver_energy_exchange_telemetry_v6"
)
const CONTRACT_SCHEMA_VERSION := (
	"sporespore_qsdk_r24d157_godot_solver_energy_exchange_contract_v2"
)

const REQUIRED_NUMERIC_FIELDS := [
	"joint_velocity_constraint_exchange_j",
	"contact_velocity_constraint_exchange_j",
	"rotation_integration_kinetic_exchange_j",
	"position_constraint_kinetic_exchange_j",
]
const REQUIRED_INTEGER_FIELDS := [
	"telemetry_sequence",
	"capture_space_step_sequence",
	"read_space_step_sequence",
	"collision_step_count",
	"constrained_island_count",
	"velocity_measured_island_count",
	"position_measured_island_count",
	"joint_velocity_phase_count",
	"contact_velocity_phase_count",
	"position_constraint_phase_count",
	"rotation_integration_expected_active_body_count",
	"rotation_integration_observed_active_body_count",
	"rotation_integration_dynamic_body_count",
	"rotation_integration_invalid_body_measurement_count",
	"dynamic_body_observation_count",
	"invalid_body_measurement_count",
	"large_island_velocity_batch_count",
	"large_island_position_batch_count",
	"ccd_active_body_count",
	"active_soft_body_count",
	"update_error_bits",
]
const REQUIRED_BOOLEAN_FIELDS := [
	"captured_during_active_step",
	"snapshot_is_current_space_step",
	"complete",
	"source_measurement",
	"mechanical_energy_residual_used_as_work_source",
]


static func native_solver_energy_exchange_contract_v2(
	telemetry_value: Variant,
	expected_space_step_sequence: int,
	uniform_gravity_world_m_s2: Vector3,
) -> Dictionary:
	if not (telemetry_value is Dictionary):
		return _failure("QSDK_R24D157_SOLVER_ENERGY_TELEMETRY_NOT_DICTIONARY")
	var telemetry: Dictionary = telemetry_value
	for key in REQUIRED_NUMERIC_FIELDS:
		if not telemetry.has(key) or typeof(telemetry[key]) not in [TYPE_FLOAT, TYPE_INT]:
			return _failure("QSDK_R24D157_SOLVER_ENERGY_NUMERIC_FIELD_INVALID:%s" % key)
	for key in REQUIRED_INTEGER_FIELDS:
		if not telemetry.has(key) or typeof(telemetry[key]) != TYPE_INT:
			return _failure("QSDK_R24D157_SOLVER_ENERGY_INTEGER_FIELD_INVALID:%s" % key)
	for key in REQUIRED_BOOLEAN_FIELDS:
		if not telemetry.has(key) or typeof(telemetry[key]) != TYPE_BOOL:
			return _failure("QSDK_R24D157_SOLVER_ENERGY_BOOLEAN_FIELD_INVALID:%s" % key)

	var displacement_value: Variant = telemetry.get(
		"position_constraint_mass_weighted_displacement_kg_m"
	)
	if not (displacement_value is Vector3):
		return _failure("QSDK_R24D157_SOLVER_ENERGY_DISPLACEMENT_INVALID")
	var displacement: Vector3 = displacement_value
	var joint_exchange := float(telemetry["joint_velocity_constraint_exchange_j"])
	var contact_exchange := float(telemetry["contact_velocity_constraint_exchange_j"])
	var rotation_exchange := float(telemetry["rotation_integration_kinetic_exchange_j"])
	var position_kinetic_exchange := float(
		telemetry["position_constraint_kinetic_exchange_j"]
	)
	var position_potential_exchange := -uniform_gravity_world_m_s2.dot(displacement)
	var step_constraint_exchange := (
		joint_exchange
		+ contact_exchange
		+ rotation_exchange
		+ position_kinetic_exchange
		+ position_potential_exchange
	)
	var expected_active := int(
		telemetry["rotation_integration_expected_active_body_count"]
	)
	var observed_active := int(
		telemetry["rotation_integration_observed_active_body_count"]
	)
	var rotation_dynamic := int(telemetry["rotation_integration_dynamic_body_count"])

	var checks := {
		"schema_exact": String(telemetry.get("schema", "")) == TELEMETRY_SCHEMA_VERSION,
		"profile_exact": String(telemetry.get("profile_id", "")) == TELEMETRY_PROFILE_ID,
		"expected_sequence_positive": expected_space_step_sequence > 0,
		"telemetry_sequence_positive": int(telemetry["telemetry_sequence"]) > 0,
		"capture_sequence_exact": (
			int(telemetry["capture_space_step_sequence"]) == expected_space_step_sequence
		),
		"read_sequence_exact": (
			int(telemetry["read_space_step_sequence"]) == expected_space_step_sequence
		),
		"captured_during_active_step": bool(telemetry["captured_during_active_step"]),
		"snapshot_current": bool(telemetry["snapshot_is_current_space_step"]),
		"collision_step_exact": int(telemetry["collision_step_count"]) == 1,
		"constrained_island_present": int(telemetry["constrained_island_count"]) > 0,
		"velocity_coverage_complete": (
			int(telemetry["velocity_measured_island_count"])
			== int(telemetry["constrained_island_count"])
		),
		"position_coverage_complete": (
			int(telemetry["position_measured_island_count"])
			== int(telemetry["constrained_island_count"])
		),
		"joint_velocity_phase_present": int(telemetry["joint_velocity_phase_count"]) > 0,
		"contact_velocity_phase_nonnegative": (
			int(telemetry["contact_velocity_phase_count"]) >= 0
		),
		"position_phase_present": int(telemetry["position_constraint_phase_count"]) > 0,
		"rotation_expected_active_present": expected_active > 0,
		"rotation_observed_active_exact": observed_active == expected_active,
		"rotation_dynamic_present": rotation_dynamic > 0,
		"rotation_dynamic_within_observed": rotation_dynamic <= observed_active,
		"rotation_invalid_measurement_zero": (
			int(telemetry["rotation_integration_invalid_body_measurement_count"]) == 0
		),
		"dynamic_body_observation_present": (
			int(telemetry["dynamic_body_observation_count"]) > 0
		),
		"invalid_body_measurement_zero": int(telemetry["invalid_body_measurement_count"]) == 0,
		"large_island_velocity_zero": int(telemetry["large_island_velocity_batch_count"]) == 0,
		"large_island_position_zero": int(telemetry["large_island_position_batch_count"]) == 0,
		"ccd_active_body_zero": int(telemetry["ccd_active_body_count"]) == 0,
		"active_soft_body_zero": int(telemetry["active_soft_body_count"]) == 0,
		"update_error_zero": int(telemetry["update_error_bits"]) == 0,
		"gravity_finite": uniform_gravity_world_m_s2.is_finite(),
		"joint_exchange_finite": is_finite(joint_exchange),
		"contact_exchange_finite": is_finite(contact_exchange),
		"rotation_exchange_finite": is_finite(rotation_exchange),
		"position_kinetic_exchange_finite": is_finite(position_kinetic_exchange),
		"position_displacement_finite": displacement.is_finite(),
		"position_potential_exchange_finite": is_finite(position_potential_exchange),
		"step_constraint_exchange_finite": is_finite(step_constraint_exchange),
		"native_complete": bool(telemetry["complete"]),
		"source_measurement": bool(telemetry["source_measurement"]),
		"residual_not_used": not bool(
			telemetry["mechanical_energy_residual_used_as_work_source"]
		),
	}
	for invariant_id in checks:
		if not bool(checks[invariant_id]):
			return _failure(
				"QSDK_R24D157_SOLVER_ENERGY_TELEMETRY_INCOMPLETE:%s" % invariant_id,
				{"ordered_checks": checks},
			)

	return {
		"schema_version": CONTRACT_SCHEMA_VERSION,
		"ok": true,
		"telemetry_schema_version": TELEMETRY_SCHEMA_VERSION,
		"telemetry_profile_id": TELEMETRY_PROFILE_ID,
		"expected_space_step_sequence": expected_space_step_sequence,
		"telemetry_sequence": int(telemetry["telemetry_sequence"]),
		"capture_space_step_sequence": int(telemetry["capture_space_step_sequence"]),
		"read_space_step_sequence": int(telemetry["read_space_step_sequence"]),
		"joint_velocity_constraint_exchange_j": joint_exchange,
		"contact_velocity_constraint_exchange_j": contact_exchange,
		"rotation_integration_kinetic_exchange_j": rotation_exchange,
		"position_constraint_kinetic_exchange_j": position_kinetic_exchange,
		"position_constraint_mass_weighted_displacement_kg_m": _vector_json(displacement),
		"uniform_gravity_world_m_s2": _vector_json(uniform_gravity_world_m_s2),
		"position_constraint_potential_exchange_j": position_potential_exchange,
		"step_signed_constraint_exchange_j": step_constraint_exchange,
		"rotation_integration_expected_active_body_count": expected_active,
		"rotation_integration_observed_active_body_count": observed_active,
		"rotation_integration_dynamic_body_count": rotation_dynamic,
		"rotation_integration_invalid_body_measurement_count": int(
			telemetry["rotation_integration_invalid_body_measurement_count"]
		),
		"rotation_integration_partition_complete": true,
		"ordered_checks": checks,
		"check_count": checks.size(),
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


static func _vector_json(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": CONTRACT_SCHEMA_VERSION,
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
