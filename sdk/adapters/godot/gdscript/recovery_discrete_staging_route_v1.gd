class_name SporeGodotJoltRecoveryDiscreteStagingRouteV1
extends RefCounted
# gdlint: disable=max-line-length

## Pure R148 native-to-portable staging seam. The physical sampler will supply
## an independently measured observer receipt; this module validates that
## receipt, advances an append-only accumulator exactly once, and replaces the
## R144 structural-zero staging declaration without deriving anything from the
## mechanical-energy residual or a behavior threshold.

const Observer := preload(
	"res://sdk/adapters/godot/gdscript/recovery_discrete_staging_observer_v1.gd"
)
const RecoveryRuntimeScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_runtime.gd"
)

const GATE_ID := "QSDK-R24D148"
const ROUTE_ID := (
	"sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_recovery_observation_v3_route_v1"
)
const WORLD_ROUTE_ID := (
	"sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_native_world_v1"
)
const MAPPING_PROFILE_ID := (
	"godot_jolt_r24d148_discrete_staging_complete_native_recovery_energy_mapping_v1"
)
const COLLECTOR_ID := (
	"sporespore_godot_jolt_discrete_staging_complete_energy_v4_recovery_collector_v1"
)
const CAPABILITY_VARIANT_ID := (
	"godot_jolt_r24d148_discrete_staging_complete_energy_capability_v1"
)
const AUTHORITY_PROFILE_ID := (
	"godot_jolt_r24d148_discrete_staging_complete_energy_partition_authority_v1"
)
const SOURCE_RECEIPT_SCHEMA := (
	"sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_source_receipt_v1"
)
const SOURCE_COMPONENT_RECEIPTS_SCHEMA := (
	"sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_source_component_receipts_v1"
)
const MAPPING_RECEIPT_SCHEMA := (
	"sporespore_qsdk_r24d148_godot_discrete_staging_energy_mapping_receipt_v1"
)
const ACCUMULATOR_SCHEMA := (
	"sporespore_qsdk_r24d148_godot_discrete_staging_accumulator_v1"
)
const PREDECESSOR_SOURCE_RECEIPT_SCHEMA := (
	"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_source_receipt_v1"
)
const PREDECESSOR_SOURCE_COMPONENT_RECEIPTS_SCHEMA := (
	"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_source_component_receipts_v1"
)
const PREDECESSOR_PARTITION_RULE_ID := (
	"godot_jolt_r24d144_solver_joint_exchange_minus_native_motor_work_partition_v1"
)
const EXPECTED_BODY_COUNT := 9
const MAXIMUM_LINEAR_VELOCITY_M_S := 500.0


static func force_contract_v1() -> Dictionary:
	return {
		"schema_version": Observer.FORCE_CONTRACT_SCHEMA,
		"godot_source_commit": Observer.GODOT_SOURCE_COMMIT,
		"force_update_rule_id": "godot_total_gravity_as_accumulated_force_then_jolt_symplectic_euler_v1",
		"position_update_rule_id": "jolt_single_discrete_velocity_integration_then_position_constraints_v1",
		"expected_body_count": EXPECTED_BODY_COUNT,
		"non_gravity_force_write_count": 0,
		"maximum_linear_velocity_m_s": MAXIMUM_LINEAR_VELOCITY_M_S,
		"jolt_system_gravity_zero": true,
		"godot_total_gravity_added_as_body_force": true,
		"all_bodies_dynamic": true,
		"all_translation_dofs_unlocked": true,
		"all_body_gravity_scales_one": true,
		"constant_force_zero": true,
		"constant_torque_zero": true,
		"linear_damping_zero": true,
		"angular_damping_zero": true,
		"custom_integrator_disabled": true,
		"gyroscopic_forces_disabled": true,
		"sleeping_disabled": true,
		"continuous_collision_detection_disabled": true,
		"single_discrete_collision_step": true,
		"position_constraint_displacement_source_measurement": true,
		"source_measurement": true,
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"constraint_exchange_used_as_staging_input": false,
		"controller_or_behavior_result_used_as_input": false,
	}


static func initial_accumulator_v1() -> Dictionary:
	return {
		"schema_version": ACCUMULATOR_SCHEMA,
		"sequence": 0,
		"event_count": 0,
		"cumulative_signed_discrete_staging_exchange_j": 0.0,
		"last_observer_receipt_sha256": null,
		"previous_accumulator_sha256": null,
		"source_measurement": true,
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Keep the live route on the exact observer qualified by R148. R149 supplies
## only the source-measured boundary transport and existing solver displacement.
static func measure_native_step_v1(
	sequence: int,
	previous_sequence: int,
	solver_step_s: float,
	ordered_body_boundaries: Array,
	position_constraint_mass_weighted_displacement_kg_m: Vector3,
) -> Dictionary:
	return Observer.measure_v1(
		sequence,
		previous_sequence,
		solver_step_s,
		ordered_body_boundaries,
		position_constraint_mass_weighted_displacement_kg_m,
		force_contract_v1(),
	)


## Advance exactly one source-measured step. The predecessor receipt is the
## unchanged R144 solver/motor/constraint population for that same step; its
## structural-zero staging fields are replaced, never silently accumulated.
static func map_step_v1(
	sdk: Object,
	predecessor_energy_source_receipt: Dictionary,
	predecessor_source_component_receipts: Dictionary,
	observer_receipt: Dictionary,
	accumulator_before: Dictionary,
) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R24D148_SDK_MISSING")
	if not _predecessor_source_complete_v1(predecessor_energy_source_receipt):
		return _failure("QSDK_R24D148_PREDECESSOR_ENERGY_SOURCE_INVALID")
	if not _predecessor_components_complete_v1(
		predecessor_energy_source_receipt,
		predecessor_source_component_receipts,
	):
		return _failure("QSDK_R24D148_PREDECESSOR_COMPONENT_SOURCE_INVALID")
	if not _observer_receipt_complete_v1(observer_receipt):
		return _failure("QSDK_R24D148_OBSERVER_RECEIPT_INVALID")
	if not _accumulator_complete_v1(accumulator_before):
		return _failure("QSDK_R24D148_ACCUMULATOR_INVALID")

	var semantic_step := int(predecessor_energy_source_receipt["semantic_step"])
	if (
		int(observer_receipt["sequence"]) != semantic_step
		or int(observer_receipt["previous_sequence"]) != semantic_step - 1
		or int(accumulator_before["sequence"]) != semantic_step - 1
		or int(accumulator_before["event_count"]) != semantic_step - 1
		or float(observer_receipt["position_constraint_potential_exchange_j"])
		!= float(
			predecessor_energy_source_receipt[
				"step_position_constraint_potential_exchange_j"
			]
		)
	):
		return _failure("QSDK_R24D148_SOURCE_SEQUENCE_OR_PARTITION_MISMATCH")

	var predecessor_energy_sha256 := _sha256(sdk, predecessor_energy_source_receipt)
	var predecessor_components_sha256 := _sha256(
		sdk, predecessor_source_component_receipts
	)
	var observer_receipt_sha256 := _sha256(sdk, observer_receipt)
	var accumulator_before_sha256 := _sha256(sdk, accumulator_before)
	if (
		predecessor_energy_sha256.is_empty()
		or predecessor_components_sha256.is_empty()
		or observer_receipt_sha256.is_empty()
		or accumulator_before_sha256.is_empty()
	):
		return _failure("QSDK_R24D148_SOURCE_DIGEST_FAILED")

	var step_staging_j := float(observer_receipt["signed_discrete_staging_exchange_j"])
	var cumulative_staging_j := (
		float(accumulator_before["cumulative_signed_discrete_staging_exchange_j"])
		+ step_staging_j
	)
	if not is_finite(cumulative_staging_j):
		return _failure("QSDK_R24D148_CUMULATIVE_STAGING_NONFINITE")
	var accumulator_after := {
		"schema_version": ACCUMULATOR_SCHEMA,
		"sequence": semantic_step,
		"event_count": semantic_step,
		"cumulative_signed_discrete_staging_exchange_j": cumulative_staging_j,
		"last_observer_receipt_sha256": observer_receipt_sha256,
		"previous_accumulator_sha256": accumulator_before_sha256,
		"source_measurement": true,
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	var accumulator_after_sha256 := _sha256(sdk, accumulator_after)
	if accumulator_after_sha256.is_empty():
		return _failure("QSDK_R24D148_ACCUMULATOR_DIGEST_FAILED")

	var mapping_receipt := {
		"schema_version": MAPPING_RECEIPT_SCHEMA,
		"gate_id": GATE_ID,
		"route_id": ROUTE_ID,
		"mapping_profile_id": MAPPING_PROFILE_ID,
		"semantic_step": semantic_step,
		"predecessor_energy_source_receipt_sha256": predecessor_energy_sha256,
		"predecessor_source_component_receipts_sha256": predecessor_components_sha256,
		"observer_receipt_sha256": observer_receipt_sha256,
		"accumulator_before_sha256": accumulator_before_sha256,
		"accumulator_after_sha256": accumulator_after_sha256,
		"step_signed_discrete_staging_exchange_j": step_staging_j,
		"cumulative_signed_discrete_staging_exchange_j": cumulative_staging_j,
		"adapter_side_discrete_staging_event_count": semantic_step,
		"staging_mapped_to_external_work": false,
		"staging_mapped_to_passive_dissipation": false,
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"source_measurement": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	var mapping_receipt_sha256 := _sha256(sdk, mapping_receipt)
	if mapping_receipt_sha256.is_empty():
		return _failure("QSDK_R24D148_MAPPING_DIGEST_FAILED")

	var energy_source := predecessor_energy_source_receipt.duplicate(true)
	energy_source["schema_version"] = SOURCE_RECEIPT_SCHEMA
	energy_source["source_route_id"] = ROUTE_ID
	energy_source["energy_mapping_profile_id"] = MAPPING_PROFILE_ID
	energy_source["discrete_staging_rule_id"] = Observer.RULE_ID
	energy_source["step_signed_discrete_staging_exchange_j"] = step_staging_j
	energy_source["cumulative_signed_discrete_staging_exchange_j"] = cumulative_staging_j
	energy_source["adapter_side_discrete_staging_event_count"] = semantic_step
	energy_source["discrete_staging_observer_receipt_sha256"] = observer_receipt_sha256
	energy_source["discrete_staging_accumulator_sha256"] = accumulator_after_sha256
	energy_source["discrete_staging_mapping_receipt_sha256"] = mapping_receipt_sha256
	energy_source["predecessor_energy_source_receipt_sha256"] = predecessor_energy_sha256
	energy_source["staging_mapped_to_external_work"] = false
	energy_source["staging_mapped_to_passive_dissipation"] = false
	energy_source["mechanical_energy_change_used_as_staging_input"] = false
	energy_source["energy_balance_residual_used_as_staging_input"] = false
	energy_source["acceptance_threshold_used_as_staging_input"] = false

	var components := predecessor_source_component_receipts.duplicate(true)
	components["schema_version"] = SOURCE_COMPONENT_RECEIPTS_SCHEMA
	components["source_route_id"] = ROUTE_ID
	components["energy_mapping_profile_id"] = MAPPING_PROFILE_ID
	components["predecessor_source_component_receipts_sha256"] = (
		predecessor_components_sha256
	)
	components["discrete_staging_observer_receipt"] = observer_receipt.duplicate(true)
	components["discrete_staging_observer_receipt_sha256"] = observer_receipt_sha256
	components["discrete_staging_accumulator_before"] = accumulator_before.duplicate(true)
	components["discrete_staging_accumulator_before_sha256"] = accumulator_before_sha256
	components["discrete_staging_accumulator_after"] = accumulator_after.duplicate(true)
	components["discrete_staging_accumulator_after_sha256"] = accumulator_after_sha256
	components["discrete_staging_mapping_receipt"] = mapping_receipt.duplicate(true)
	components["discrete_staging_mapping_receipt_sha256"] = mapping_receipt_sha256
	components["source_measurement"] = true

	if not source_receipt_complete_v1(energy_source):
		return _failure("QSDK_R24D148_MAPPED_ENERGY_SOURCE_INVALID")
	if not source_components_complete_v1(sdk, energy_source, components):
		return _failure("QSDK_R24D148_MAPPED_COMPONENT_SOURCE_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r24d148_godot_discrete_staging_step_mapping_v1",
		"ok": true,
		"energy_source_receipt": energy_source,
		"source_component_receipts": components,
		"mapping_receipt": mapping_receipt,
		"mapping_receipt_sha256": mapping_receipt_sha256,
		"accumulator_after": accumulator_after,
		"accumulator_after_sha256": accumulator_after_sha256,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func source_receipt_complete_v1(value: Dictionary) -> bool:
	for key in [
		"semantic_step",
		"initial_mechanical_energy_j",
		"current_mechanical_energy_j",
		"cumulative_applied_actuator_work_j",
		"cumulative_signed_external_work_j",
		"step_signed_constraint_exchange_j",
		"step_position_constraint_potential_exchange_j",
		"cumulative_signed_constraint_exchange_j",
		"step_signed_discrete_staging_exchange_j",
		"cumulative_signed_discrete_staging_exchange_j",
		"cumulative_passive_dissipation_j",
		"adapter_side_discrete_staging_event_count",
	]:
		if not value.has(key) or not is_finite(float(value[key])):
			return false
	var semantic_step := int(value.get("semantic_step", 0))
	if (
		String(value.get("schema_version", "")) != SOURCE_RECEIPT_SCHEMA
		or String(value.get("source_route_id", "")) != ROUTE_ID
		or String(value.get("energy_mapping_profile_id", "")) != MAPPING_PROFILE_ID
		or String(value.get("discrete_staging_rule_id", "")) != Observer.RULE_ID
		or semantic_step <= 0
		or int(value.get("adapter_side_discrete_staging_event_count", -1))
		!= semantic_step
		or float(value.get("cumulative_signed_external_work_j", NAN)) != 0.0
		or float(value.get("cumulative_passive_dissipation_j", NAN)) != 0.0
		or String(value.get("partition_rule_id", ""))
		!= PREDECESSOR_PARTITION_RULE_ID
		or not bool(value.get("native_motor_work_subtracted_exactly_once", false))
		or bool(value.get("motor_work_also_counted_as_constraint_exchange", true))
		or not bool(value.get("constraint_exchange_partition_complete", false))
		or not bool(value.get("passive_dissipation_partition_complete", false))
		or not bool(value.get("component_partition_complete", false))
		or not bool(value.get("exact_balance_safety_authority", false))
		or bool(value.get("unclosed_energy_residual_preserved", true))
		or bool(value.get("mechanical_energy_residual_used_as_work_source", true))
		or bool(value.get("residual_balancing_permitted", true))
		or bool(value.get("staging_mapped_to_external_work", true))
		or bool(value.get("staging_mapped_to_passive_dissipation", true))
		or bool(value.get("mechanical_energy_change_used_as_staging_input", true))
		or bool(value.get("energy_balance_residual_used_as_staging_input", true))
		or bool(value.get("acceptance_threshold_used_as_staging_input", true))
		or not bool(value.get("source_measurement", false))
	):
		return false
	for key in [
		"solver_energy_exchange_receipt_sha256",
		"solver_coupled_partition_receipt_sha256",
		"world_energy_configuration_receipt_sha256",
		"actuator_constraint_disjointness_receipt_sha256",
		"discrete_staging_observer_receipt_sha256",
		"discrete_staging_accumulator_sha256",
		"discrete_staging_mapping_receipt_sha256",
		"predecessor_energy_source_receipt_sha256",
	]:
		if not _digest_valid(String(value.get(key, ""))):
			return false
	return true


static func source_components_complete_v1(
	sdk: Object,
	energy_source: Dictionary,
	components: Dictionary,
) -> bool:
	var observer_value: Variant = components.get("discrete_staging_observer_receipt")
	var before_value: Variant = components.get("discrete_staging_accumulator_before")
	var after_value: Variant = components.get("discrete_staging_accumulator_after")
	var mapping_value: Variant = components.get("discrete_staging_mapping_receipt")
	if (
		sdk == null
		or String(components.get("schema_version", ""))
		!= SOURCE_COMPONENT_RECEIPTS_SCHEMA
		or int(components.get("semantic_step", -1))
		!= int(energy_source.get("semantic_step", -2))
		or String(components.get("source_route_id", "")) != ROUTE_ID
		or String(components.get("energy_mapping_profile_id", ""))
		!= MAPPING_PROFILE_ID
		or not bool(components.get("source_measurement", false))
		or not (observer_value is Dictionary)
		or not (before_value is Dictionary)
		or not (after_value is Dictionary)
		or not (mapping_value is Dictionary)
	):
		return false
	var observer: Dictionary = observer_value
	var before: Dictionary = before_value
	var after: Dictionary = after_value
	var mapping: Dictionary = mapping_value
	return (
		_observer_receipt_complete_v1(observer)
		and _accumulator_complete_v1(before)
		and _accumulator_complete_v1(after)
		and int(after.get("sequence", -1)) == int(energy_source["semantic_step"])
		and int(after.get("event_count", -1))
		== int(energy_source["adapter_side_discrete_staging_event_count"])
		and float(after.get("cumulative_signed_discrete_staging_exchange_j", NAN))
		== float(energy_source["cumulative_signed_discrete_staging_exchange_j"])
		and String(mapping.get("schema_version", "")) == MAPPING_RECEIPT_SCHEMA
		and int(mapping.get("semantic_step", -1)) == int(energy_source["semantic_step"])
		and _sha256(sdk, observer)
		== String(components.get("discrete_staging_observer_receipt_sha256", ""))
		and _sha256(sdk, before)
		== String(components.get("discrete_staging_accumulator_before_sha256", ""))
		and _sha256(sdk, after)
		== String(components.get("discrete_staging_accumulator_after_sha256", ""))
		and _sha256(sdk, mapping)
		== String(components.get("discrete_staging_mapping_receipt_sha256", ""))
		and String(components.get("discrete_staging_observer_receipt_sha256", ""))
		== String(energy_source.get("discrete_staging_observer_receipt_sha256", ""))
		and String(components.get("discrete_staging_accumulator_after_sha256", ""))
		== String(energy_source.get("discrete_staging_accumulator_sha256", ""))
		and String(components.get("discrete_staging_mapping_receipt_sha256", ""))
		== String(energy_source.get("discrete_staging_mapping_receipt_sha256", ""))
	)


static func _predecessor_source_complete_v1(value: Dictionary) -> bool:
	for key in [
		"initial_mechanical_energy_j",
		"current_mechanical_energy_j",
		"cumulative_applied_actuator_work_j",
		"cumulative_signed_external_work_j",
		"step_signed_constraint_exchange_j",
		"step_position_constraint_potential_exchange_j",
		"cumulative_signed_constraint_exchange_j",
		"cumulative_signed_discrete_staging_exchange_j",
		"cumulative_passive_dissipation_j",
		"raw_step_signed_solver_exchange_j",
		"step_actuator_work_j",
	]:
		if not value.has(key) or not is_finite(float(value[key])):
			return false
	return (
		String(value.get("schema_version", "")) == PREDECESSOR_SOURCE_RECEIPT_SCHEMA
		and int(value.get("semantic_step", 0)) > 0
		and int(value.get("adapter_side_discrete_staging_event_count", -1)) == 0
		and float(value.get("cumulative_signed_discrete_staging_exchange_j", NAN)) == 0.0
		and float(value.get("cumulative_signed_external_work_j", NAN)) == 0.0
		and float(value.get("cumulative_passive_dissipation_j", NAN)) == 0.0
		and String(value.get("partition_rule_id", ""))
		== PREDECESSOR_PARTITION_RULE_ID
		and not bool(value.get("unclosed_energy_residual_preserved", true))
		and not bool(value.get("mechanical_energy_residual_used_as_work_source", true))
		and not bool(value.get("residual_balancing_permitted", true))
		and bool(value.get("source_measurement", false))
	)


static func _predecessor_components_complete_v1(
	energy_source: Dictionary,
	components: Dictionary,
) -> bool:
	return (
		String(components.get("schema_version", ""))
		== PREDECESSOR_SOURCE_COMPONENT_RECEIPTS_SCHEMA
		and int(components.get("semantic_step", -1))
		== int(energy_source.get("semantic_step", -2))
		and bool(components.get("component_partition_complete", false))
		and not bool(
			components.get("mechanical_energy_residual_used_as_work_source", true)
		)
		and bool(components.get("source_measurement", false))
	)


static func _observer_receipt_complete_v1(value: Dictionary) -> bool:
	for key in [
		"force_integration_kinetic_exchange_j",
		"position_constraint_potential_exchange_j",
		"position_integration_potential_exchange_j",
		"signed_discrete_staging_exchange_j",
	]:
		if not value.has(key) or not is_finite(float(value[key])):
			return false
	return (
		String(value.get("schema_version", "")) == Observer.RECEIPT_SCHEMA
		and bool(value.get("ok", false))
		and String(value.get("gate_id", "")) == GATE_ID
		and String(value.get("rule_id", "")) == Observer.RULE_ID
		and int(value.get("sequence", 0)) > 0
		and int(value.get("previous_sequence", -1))
		== int(value.get("sequence", 0)) - 1
		and int(value.get("body_count", -1)) == EXPECTED_BODY_COUNT
		and float(value["signed_discrete_staging_exchange_j"])
		== float(value["force_integration_kinetic_exchange_j"])
		+ float(value["position_integration_potential_exchange_j"])
		and bool(value.get("source_measurement", false))
		and not bool(value.get("mechanical_energy_change_used_as_input", true))
		and not bool(value.get("energy_balance_residual_used_as_input", true))
		and not bool(value.get("acceptance_threshold_used_as_input", true))
		and not bool(value.get("constraint_exchange_used_as_staging_input", true))
		and not bool(value.get("controller_or_behavior_result_used_as_input", true))
		and not bool(value.get("physical_acceptance_authority", true))
		and not bool(value.get("release_authority", true))
	)


static func _accumulator_complete_v1(value: Dictionary) -> bool:
	var sequence := int(value.get("sequence", -1))
	return (
		String(value.get("schema_version", "")) == ACCUMULATOR_SCHEMA
		and sequence >= 0
		and int(value.get("event_count", -1)) == sequence
		and is_finite(
			float(value.get("cumulative_signed_discrete_staging_exchange_j", NAN))
		)
		and bool(value.get("source_measurement", false))
		and not bool(value.get("mechanical_energy_change_used_as_input", true))
		and not bool(value.get("energy_balance_residual_used_as_input", true))
		and not bool(value.get("acceptance_threshold_used_as_input", true))
		and not bool(value.get("physical_acceptance_authority", true))
		and not bool(value.get("release_authority", true))
		and (
			sequence > 0
			or (
				value.get("last_observer_receipt_sha256") == null
				and value.get("previous_accumulator_sha256") == null
			)
		)
		and (
			sequence == 0
			or (
				_digest_valid(String(value.get("last_observer_receipt_sha256", "")))
				and _digest_valid(String(value.get("previous_accumulator_sha256", "")))
			)
		)
	)


static func _digest_valid(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _sha256(sdk: Object, value: Variant) -> String:
	var receipt := RecoveryRuntimeScript.canonicalize(sdk, value)
	var digest := String(receipt.get("sha256", ""))
	return digest if _digest_valid(digest) else ""


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d148_godot_discrete_staging_route_failure_v1",
		"ok": false,
		"gate_id": GATE_ID,
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
