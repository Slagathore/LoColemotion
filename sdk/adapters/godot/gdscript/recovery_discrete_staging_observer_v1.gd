class_name SporeGodotJoltRecoveryDiscreteStagingObserverV1
extends RefCounted

## Pure adapter-side observer for the discrete gravity staging that Godot's
## Jolt integration contributes outside the already measured constraint
## phases. The observer accepts only ordered, source-measured step boundaries
## and a source-measured position-constraint displacement. It never accepts a
## whole-step energy change, residual, threshold, or behavior result as an
## input, so the term cannot be manufactured to close an energy ledger.

const GATE_ID := "QSDK-R24D148"
const RULE_ID := "godot_jolt_gravity_force_and_position_staging_exchange_v1"
const FORCE_CONTRACT_SCHEMA := (
	"sporespore_qsdk_r24d148_godot_jolt_gravity_force_integration_contract_v1"
)
const RECEIPT_SCHEMA := (
	"sporespore_qsdk_r24d148_godot_jolt_discrete_staging_exchange_v1"
)
const GODOT_SOURCE_COMMIT := "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"

const FORBIDDEN_OBSERVER_INPUT_KEYS := [
	"whole_step_mechanical_energy_change_j",
	"mechanical_energy_change_j",
	"energy_balance_residual_j",
	"signed_energy_balance_residual_j",
	"acceptance_threshold_j",
	"constraint_exchange_j",
	"controller_result",
	"behavior_result",
]


## Measure one completed outer step. Body rows are generic and ordered by a
## caller-supplied contiguous body_index, so the observer is reusable without
## embedding the current nine-body morphology. The route contract supplies
## the exact expected population and engine envelope.
static func measure_v1(
	sequence: int,
	previous_sequence: int,
	solver_step_s: float,
	ordered_body_boundaries: Array,
	position_constraint_mass_weighted_displacement_kg_m: Vector3,
	force_contract: Dictionary,
) -> Dictionary:
	if previous_sequence < 0 or sequence != previous_sequence + 1:
		return _failure("QSDK_R24D148_SEQUENCE_INVALID")
	if not is_finite(solver_step_s) or solver_step_s <= 0.0:
		return _failure("QSDK_R24D148_SOLVER_STEP_INVALID")
	var contract_check := _validate_force_contract_v1(force_contract)
	if not bool(contract_check.get("ok", false)):
		return contract_check
	var expected_body_count := int(force_contract["expected_body_count"])
	if ordered_body_boundaries.size() != expected_body_count:
		return _failure("QSDK_R24D148_BODY_POPULATION_INVALID")
	if not position_constraint_mass_weighted_displacement_kg_m.is_finite():
		return _failure("QSDK_R24D148_POSITION_CONSTRAINT_DISPLACEMENT_NONFINITE")

	var maximum_linear_velocity_m_s := float(
		force_contract["maximum_linear_velocity_m_s"]
	)
	var seen_body_ids: Dictionary = {}
	var uniform_gravity := Vector3(NAN, NAN, NAN)
	var force_kinetic_exchange_j := 0.0
	var total_mass_weighted_displacement := Vector3.ZERO
	var maximum_predicted_force_velocity_m_s := 0.0
	var maximum_boundary_velocity_m_s := 0.0
	for index in range(ordered_body_boundaries.size()):
		var row_value: Variant = ordered_body_boundaries[index]
		if not (row_value is Dictionary):
			return _failure("QSDK_R24D148_BODY_BOUNDARY_INVALID:%d" % index)
		var row: Dictionary = row_value
		for forbidden_key in FORBIDDEN_OBSERVER_INPUT_KEYS:
			if row.has(forbidden_key):
				return _failure("QSDK_R24D148_RESIDUAL_DERIVED_INPUT_REFUSED")
		var body_id := String(row.get("body_id", ""))
		if (
			body_id.is_empty()
			or seen_body_ids.has(body_id)
			or typeof(row.get("body_index")) != TYPE_INT
			or int(row["body_index"]) != index
		):
			return _failure("QSDK_R24D148_BODY_ORDER_INVALID:%d" % index)
		seen_body_ids[body_id] = true
		if (
			typeof(row.get("pre_boundary_sequence")) != TYPE_INT
			or typeof(row.get("post_boundary_sequence")) != TYPE_INT
			or int(row["pre_boundary_sequence"]) != previous_sequence
			or int(row["post_boundary_sequence"]) != sequence
		):
			return _failure("QSDK_R24D148_BODY_BOUNDARY_SEQUENCE_INVALID:%d" % index)
		if (
			not bool(row.get("pre_source_measurement", false))
			or not bool(row.get("post_source_measurement", false))
		):
			return _failure("QSDK_R24D148_BODY_BOUNDARY_NOT_SOURCE_MEASURED:%d" % index)
		if typeof(row.get("mass_kg")) not in [TYPE_FLOAT, TYPE_INT]:
			return _failure("QSDK_R24D148_BODY_MASS_INVALID:%d" % index)
		var mass_kg := float(row["mass_kg"])
		var pre_position_value: Variant = row.get("pre_position_world_m")
		var post_position_value: Variant = row.get("post_position_world_m")
		var pre_velocity_value: Variant = row.get("pre_linear_velocity_world_m_s")
		var post_velocity_value: Variant = row.get("post_linear_velocity_world_m_s")
		var gravity_value: Variant = row.get("total_gravity_world_m_s2")
		if (
			not is_finite(mass_kg)
			or mass_kg <= 0.0
			or not (pre_position_value is Vector3)
			or not (post_position_value is Vector3)
			or not (pre_velocity_value is Vector3)
			or not (post_velocity_value is Vector3)
			or not (gravity_value is Vector3)
		):
			return _failure("QSDK_R24D148_BODY_BOUNDARY_SHAPE_INVALID:%d" % index)
		var pre_position: Vector3 = pre_position_value
		var post_position: Vector3 = post_position_value
		var pre_velocity: Vector3 = pre_velocity_value
		var post_velocity: Vector3 = post_velocity_value
		var gravity: Vector3 = gravity_value
		if (
			not pre_position.is_finite()
			or not post_position.is_finite()
			or not pre_velocity.is_finite()
			or not post_velocity.is_finite()
			or not gravity.is_finite()
		):
			return _failure("QSDK_R24D148_BODY_BOUNDARY_NONFINITE:%d" % index)
		if index == 0:
			uniform_gravity = gravity
		elif gravity != uniform_gravity:
			return _failure("QSDK_R24D148_BODY_GRAVITY_NOT_UNIFORM:%d" % index)

		var velocity_after_gravity_force := pre_velocity + gravity * solver_step_s
		var predicted_speed := velocity_after_gravity_force.length()
		var boundary_speed := maxf(pre_velocity.length(), post_velocity.length())
		if (
			not velocity_after_gravity_force.is_finite()
			or not is_finite(predicted_speed)
			or predicted_speed >= maximum_linear_velocity_m_s
			or boundary_speed >= maximum_linear_velocity_m_s
		):
			return _failure("QSDK_R24D148_LINEAR_VELOCITY_CLAMP_NOT_EXCLUDED:%d" % index)
		maximum_predicted_force_velocity_m_s = maxf(
			maximum_predicted_force_velocity_m_s, predicted_speed
		)
		maximum_boundary_velocity_m_s = maxf(
			maximum_boundary_velocity_m_s, boundary_speed
		)
		var pre_speed_squared := pre_velocity.length_squared()
		var post_force_speed_squared := velocity_after_gravity_force.length_squared()
		force_kinetic_exchange_j += (
			0.5 * mass_kg * (post_force_speed_squared - pre_speed_squared)
		)
		total_mass_weighted_displacement += mass_kg * (post_position - pre_position)

	if (
		not is_finite(force_kinetic_exchange_j)
		or not total_mass_weighted_displacement.is_finite()
	):
		return _failure("QSDK_R24D148_AGGREGATE_NONFINITE")
	var integration_displacement := (
		total_mass_weighted_displacement
		- position_constraint_mass_weighted_displacement_kg_m
	)
	var whole_step_potential_exchange_j := -uniform_gravity.dot(
		total_mass_weighted_displacement
	)
	var position_constraint_potential_exchange_j := -uniform_gravity.dot(
		position_constraint_mass_weighted_displacement_kg_m
	)
	var position_integration_potential_exchange_j := -uniform_gravity.dot(
		integration_displacement
	)
	var signed_staging_exchange_j := (
		force_kinetic_exchange_j + position_integration_potential_exchange_j
	)
	for value in [
		whole_step_potential_exchange_j,
		position_constraint_potential_exchange_j,
		position_integration_potential_exchange_j,
		signed_staging_exchange_j,
	]:
		if not is_finite(float(value)):
			return _failure("QSDK_R24D148_STAGING_EXCHANGE_NONFINITE")

	return {
		"schema_version": RECEIPT_SCHEMA,
		"ok": true,
		"gate_id": GATE_ID,
		"rule_id": RULE_ID,
		"sequence": sequence,
		"previous_sequence": previous_sequence,
		"solver_step_s": solver_step_s,
		"body_count": ordered_body_boundaries.size(),
		"uniform_gravity_world_m_s2": _vector_json(uniform_gravity),
		"force_integration_kinetic_exchange_j": force_kinetic_exchange_j,
		"whole_step_gravity_potential_exchange_j": whole_step_potential_exchange_j,
		"position_constraint_potential_exchange_j": (
			position_constraint_potential_exchange_j
		),
		"position_integration_potential_exchange_j": (
			position_integration_potential_exchange_j
		),
		"total_mass_weighted_displacement_kg_m": _vector_json(
			total_mass_weighted_displacement
		),
		"position_constraint_mass_weighted_displacement_kg_m": _vector_json(
			position_constraint_mass_weighted_displacement_kg_m
		),
		"position_integration_mass_weighted_displacement_kg_m": _vector_json(
			integration_displacement
		),
		"signed_discrete_staging_exchange_j": signed_staging_exchange_j,
		"maximum_linear_velocity_m_s": maximum_linear_velocity_m_s,
		"maximum_predicted_force_velocity_m_s": maximum_predicted_force_velocity_m_s,
		"maximum_boundary_velocity_m_s": maximum_boundary_velocity_m_s,
		"source_measurement": true,
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"constraint_exchange_used_as_staging_input": false,
		"controller_or_behavior_result_used_as_input": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _validate_force_contract_v1(value: Dictionary) -> Dictionary:
	for forbidden_key in FORBIDDEN_OBSERVER_INPUT_KEYS:
		if value.has(forbidden_key):
			return _failure("QSDK_R24D148_RESIDUAL_DERIVED_INPUT_REFUSED")
	if (
		String(value.get("schema_version", "")) != FORCE_CONTRACT_SCHEMA
		or String(value.get("godot_source_commit", "")) != GODOT_SOURCE_COMMIT
		or String(value.get("force_update_rule_id", ""))
		!= "godot_total_gravity_as_accumulated_force_then_jolt_symplectic_euler_v1"
		or String(value.get("position_update_rule_id", ""))
		!= "jolt_single_discrete_velocity_integration_then_position_constraints_v1"
		or typeof(value.get("expected_body_count")) != TYPE_INT
		or int(value.get("expected_body_count", 0)) <= 0
		or typeof(value.get("non_gravity_force_write_count")) != TYPE_INT
		or int(value.get("non_gravity_force_write_count", -1)) != 0
		or typeof(value.get("maximum_linear_velocity_m_s"))
		not in [TYPE_FLOAT, TYPE_INT]
		or not is_finite(float(value.get("maximum_linear_velocity_m_s", NAN)))
		or float(value.get("maximum_linear_velocity_m_s", NAN)) <= 0.0
	):
		return _failure("QSDK_R24D148_FORCE_CONTRACT_IDENTITY_INVALID")
	for key in [
		"jolt_system_gravity_zero",
		"godot_total_gravity_added_as_body_force",
		"all_bodies_dynamic",
		"all_translation_dofs_unlocked",
		"all_body_gravity_scales_one",
		"constant_force_zero",
		"constant_torque_zero",
		"linear_damping_zero",
		"angular_damping_zero",
		"custom_integrator_disabled",
		"gyroscopic_forces_disabled",
		"sleeping_disabled",
		"continuous_collision_detection_disabled",
		"single_discrete_collision_step",
		"position_constraint_displacement_source_measurement",
		"source_measurement",
	]:
		if typeof(value.get(key)) != TYPE_BOOL or not bool(value[key]):
			return _failure("QSDK_R24D148_FORCE_CONTRACT_CAPABILITY_INVALID:%s" % key)
	for key in [
		"mechanical_energy_change_used_as_input",
		"energy_balance_residual_used_as_input",
		"acceptance_threshold_used_as_input",
		"constraint_exchange_used_as_staging_input",
		"controller_or_behavior_result_used_as_input",
	]:
		if typeof(value.get(key)) != TYPE_BOOL or bool(value[key]):
			return _failure("QSDK_R24D148_FORCE_CONTRACT_FORBIDDEN_INPUT:%s" % key)
	return {"ok": true}


static func _vector_json(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


static func _failure(code: String) -> Dictionary:
	return {
		"schema_version": RECEIPT_SCHEMA,
		"ok": false,
		"gate_id": GATE_ID,
		"failure_code": code,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
