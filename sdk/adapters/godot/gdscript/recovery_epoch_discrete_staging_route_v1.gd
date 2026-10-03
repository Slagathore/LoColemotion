class_name SporeGodotJoltRecoveryEpochDiscreteStagingRouteV1
extends RefCounted
# gdlint: disable=max-line-length

## Offset-aware, append-only staging and energy projection for R10F.
##
## Global engine sequence G is never rewritten. Recovery-local step L is
## derived only as G - E, where E is the immutable post-interaction boundary.
## The qualified R148 observer still measures each physical pair; this module
## changes only the accumulator origin and rebases cumulative energy channels
## against the source-measured R10F initializer.

const EpochTransport := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_boundary_transport_v1.gd"
)
const EnergyInitializer := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_energy_initializer_v1.gd"
)
const QualifiedStagingRoute := preload(
	"res://sdk/adapters/godot/gdscript/recovery_discrete_staging_route_v1.gd"
)
const Observer := preload(
	"res://sdk/adapters/godot/gdscript/recovery_discrete_staging_observer_v1.gd"
)
const RecoveryRoute := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")

const GATE_ID := "QSDK-R10F"
const ROUTE_ID := "sporespore_qsdk_r10f_godot_jolt_offset_epoch_discrete_staging_route_v1"
const MAPPING_PROFILE_ID := "godot_jolt_r10f_offset_epoch_rotation_aware_energy_mapping_v1"
const ACCUMULATOR_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_discrete_staging_accumulator_v1"
const OBSERVER_BINDING_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_observer_binding_v1"
const MAPPING_RECEIPT_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_energy_mapping_receipt_v1"
const SOURCE_RECEIPT_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_energy_source_receipt_v1"
const SOURCE_COMPONENT_RECEIPTS_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_source_component_receipts_v1"
const BOUND_OBSERVATIONS_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_bound_observations_v1"
const FAILURE_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_discrete_staging_route_failure_v1"
const PORTABLE_ROUTE_ID := QualifiedStagingRoute.ROUTE_ID
const PORTABLE_MAPPING_PROFILE_ID := QualifiedStagingRoute.MAPPING_PROFILE_ID
const EXPECTED_BODY_COUNT := 9
const OUTCOME_DERIVED_KEYS := [
	"acceptance_threshold",
	"behavior_result",
	"energy_balance_residual_j",
	"physical_result",
	"recovery_success",
	"stable_stance_gate",
]

const ACCUMULATOR_KEYS := [
	"schema_version",
	"epoch_contract_id",
	"epoch_start_global_step",
	"global_sequence",
	"epoch_local_event_count",
	"cumulative_signed_discrete_staging_exchange_j",
	"last_observer_receipt_sha256",
	"previous_accumulator_sha256",
	"epoch_initializer_sha256",
	"source_measurement",
	"global_sequence_rewrite_permitted",
	"unobserved_pre_epoch_event_count_claimed",
	"mechanical_energy_change_used_as_input",
	"energy_balance_residual_used_as_input",
	"acceptance_threshold_used_as_input",
	"physical_acceptance_authority",
	"release_authority",
]


static func initial_accumulator_v1(initializer: Dictionary) -> Dictionary:
	if not _initializer_shape_valid_v1(initializer):
		return _failure("QSDK_R10F_EPOCH_ACCUMULATOR_INITIALIZER_INVALID")
	return {
		"schema_version": ACCUMULATOR_SCHEMA,
		"epoch_contract_id": EpochTransport.EPOCH_CONTRACT_ID,
		"epoch_start_global_step": int(initializer["epoch_start_global_step"]),
		"global_sequence": int(initializer["epoch_start_global_step"]),
		"epoch_local_event_count": 0,
		"cumulative_signed_discrete_staging_exchange_j": 0.0,
		"last_observer_receipt_sha256": null,
		"previous_accumulator_sha256": null,
		"epoch_initializer_sha256": String(initializer["payload_sha256"]),
		"source_measurement": true,
		"global_sequence_rewrite_permitted": false,
		"unobserved_pre_epoch_event_count_claimed": false,
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Adapt only field names around the R148 observer. All positions, velocities,
## masses, gravity, time step, and global sequence values remain unchanged.
static func measure_epoch_step_v1(
	sdk: Object,
	epoch_pair: Dictionary,
	position_constraint_mass_weighted_displacement_kg_m: Vector3,
) -> Dictionary:
	if sdk == null or not EpochTransport.pair_valid_v1(sdk, epoch_pair):
		return _failure("QSDK_R10F_EPOCH_OBSERVER_PAIR_INVALID")
	if not position_constraint_mass_weighted_displacement_kg_m.is_finite():
		return _failure("QSDK_R10F_EPOCH_OBSERVER_DISPLACEMENT_INVALID")
	var projected_boundaries: Array = []
	var solver_step_s := NAN
	for row_value in epoch_pair["ordered_body_boundaries"]:
		var row: Dictionary = row_value
		solver_step_s = float(row["solver_step_s"])
		(
			projected_boundaries
			. append(
				{
					"body_id": String(row["body_id"]),
					"body_index": int(row["body_index"]),
					"pre_boundary_sequence": int(row["pre_global_boundary_step"]),
					"post_boundary_sequence": int(row["post_global_boundary_step"]),
					"pre_source_event_id": String(row["pre_source_event_id"]),
					"post_source_event_id": String(row["post_source_event_id"]),
					"mass_kg": float(row["mass_kg"]),
					"pre_position_world_m": row["pre_position_world_m"],
					"post_position_world_m": row["post_position_world_m"],
					"pre_linear_velocity_world_m_s": row["pre_linear_velocity_world_m_s"],
					"post_linear_velocity_world_m_s": row["post_linear_velocity_world_m_s"],
					"total_gravity_world_m_s2": row["total_gravity_world_m_s2"],
					"solver_step_s": solver_step_s,
					"pre_source_measurement": true,
					"post_source_measurement": true,
				}
			)
		)
	var observer := (
		QualifiedStagingRoute
		. measure_native_step_v1(
			int(epoch_pair["global_semantic_step"]),
			int(epoch_pair["previous_global_semantic_step"]),
			solver_step_s,
			projected_boundaries,
			position_constraint_mass_weighted_displacement_kg_m,
		)
	)
	if not _observer_receipt_valid_v1(observer):
		return _failure("QSDK_R10F_EPOCH_OBSERVER_REFUSED")
	var pair_sha256 := String(epoch_pair["payload_sha256"])
	var projection_sha256 := _sha256_v1(sdk, projected_boundaries)
	var observer_sha256 := _sha256_v1(sdk, observer)
	if projection_sha256.is_empty() or observer_sha256.is_empty():
		return _failure("QSDK_R10F_EPOCH_OBSERVER_DIGEST_FAILED")
	return {
		"schema_version": OBSERVER_BINDING_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"epoch_start_global_step": int(epoch_pair["epoch_start_global_step"]),
		"global_semantic_step": int(epoch_pair["global_semantic_step"]),
		"epoch_local_step": int(epoch_pair["epoch_local_step"]),
		"epoch_pair_sha256": pair_sha256,
		"qualified_observer_input_projection_sha256": projection_sha256,
		"observer_receipt": observer,
		"observer_receipt_sha256": observer_sha256,
		"qualified_r148_observer_unchanged": true,
		"global_sequence_rewrite_permitted": false,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func map_epoch_step_v1(
	sdk: Object,
	rotation_aware_energy_source_receipt: Dictionary,
	rotation_aware_source_component_receipts: Dictionary,
	observer_receipt: Dictionary,
	accumulator_before: Dictionary,
	initializer: Dictionary,
) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_EPOCH_STAGING_SDK_MISSING")
	if not EnergyInitializer.initializer_valid_v1(sdk, initializer):
		return _failure("QSDK_R10F_EPOCH_STAGING_INITIALIZER_INVALID")
	if not (
		EnergyInitializer
		. rotation_aware_sources_valid_v1(
			sdk,
			rotation_aware_energy_source_receipt,
			rotation_aware_source_component_receipts,
		)
	):
		return _failure("QSDK_R10F_EPOCH_STAGING_ROTATION_SOURCE_INVALID")
	if not _observer_receipt_valid_v1(observer_receipt):
		return _failure("QSDK_R10F_EPOCH_STAGING_OBSERVER_INVALID")
	if not accumulator_valid_v1(accumulator_before):
		return _failure("QSDK_R10F_EPOCH_STAGING_ACCUMULATOR_INVALID")

	var epoch_start := int(initializer["epoch_start_global_step"])
	var global_step := int(rotation_aware_energy_source_receipt["semantic_step"])
	var local_step := global_step - epoch_start
	if (
		(
			String(accumulator_before.get("epoch_initializer_sha256", ""))
			!= String(initializer["payload_sha256"])
		)
		or int(accumulator_before.get("epoch_start_global_step", -1)) != epoch_start
		or int(observer_receipt.get("sequence", -1)) != global_step
		or int(observer_receipt.get("previous_sequence", -1)) != global_step - 1
		or int(accumulator_before.get("global_sequence", -1)) != global_step - 1
		or int(accumulator_before.get("epoch_local_event_count", -1)) != local_step - 1
		or local_step <= 0
		or (
			float(observer_receipt["position_constraint_potential_exchange_j"])
			!= float(
				rotation_aware_energy_source_receipt["step_position_constraint_potential_exchange_j"]
			)
		)
	):
		return _failure("QSDK_R10F_EPOCH_STAGING_SEQUENCE_OR_PARTITION_MISMATCH")

	var raw_energy_sha256 := _sha256_v1(sdk, rotation_aware_energy_source_receipt)
	var raw_components_sha256 := _sha256_v1(sdk, rotation_aware_source_component_receipts)
	var observer_sha256 := _sha256_v1(sdk, observer_receipt)
	var before_sha256 := _sha256_v1(sdk, accumulator_before)
	if (
		raw_energy_sha256.is_empty()
		or raw_components_sha256.is_empty()
		or observer_sha256.is_empty()
		or before_sha256.is_empty()
	):
		return _failure("QSDK_R10F_EPOCH_STAGING_SOURCE_DIGEST_FAILED")

	var step_staging_j := float(observer_receipt["signed_discrete_staging_exchange_j"])
	var cumulative_staging_j := (
		float(accumulator_before["cumulative_signed_discrete_staging_exchange_j"]) + step_staging_j
	)
	if not is_finite(cumulative_staging_j):
		return _failure("QSDK_R10F_EPOCH_STAGING_CUMULATIVE_NONFINITE")
	var accumulator_after := {
		"schema_version": ACCUMULATOR_SCHEMA,
		"epoch_contract_id": EpochTransport.EPOCH_CONTRACT_ID,
		"epoch_start_global_step": epoch_start,
		"global_sequence": global_step,
		"epoch_local_event_count": local_step,
		"cumulative_signed_discrete_staging_exchange_j": cumulative_staging_j,
		"last_observer_receipt_sha256": observer_sha256,
		"previous_accumulator_sha256": before_sha256,
		"epoch_initializer_sha256": String(initializer["payload_sha256"]),
		"source_measurement": true,
		"global_sequence_rewrite_permitted": false,
		"unobserved_pre_epoch_event_count_claimed": false,
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if not accumulator_valid_v1(accumulator_after):
		return _failure("QSDK_R10F_EPOCH_STAGING_SUCCESSOR_ACCUMULATOR_INVALID")
	var after_sha256 := _sha256_v1(sdk, accumulator_after)
	if after_sha256.is_empty():
		return _failure("QSDK_R10F_EPOCH_STAGING_SUCCESSOR_DIGEST_FAILED")

	var local_actuator_work := (
		float(rotation_aware_energy_source_receipt["cumulative_applied_actuator_work_j"])
		- float(initializer["global_cumulative_applied_actuator_work_at_epoch_start_j"])
	)
	var local_external_work := (
		float(rotation_aware_energy_source_receipt["cumulative_signed_external_work_j"])
		- float(initializer["global_cumulative_signed_external_work_at_epoch_start_j"])
	)
	var local_constraint_exchange := (
		float(rotation_aware_energy_source_receipt["cumulative_signed_constraint_exchange_j"])
		- float(initializer["global_cumulative_signed_constraint_exchange_at_epoch_start_j"])
	)
	var local_passive_dissipation := (
		float(rotation_aware_energy_source_receipt["cumulative_passive_dissipation_j"])
		- float(initializer["global_cumulative_passive_dissipation_at_epoch_start_j"])
	)
	for rebased_value in [
		local_actuator_work,
		local_external_work,
		local_constraint_exchange,
		local_passive_dissipation,
	]:
		if not is_finite(float(rebased_value)):
			return _failure("QSDK_R10F_EPOCH_STAGING_REBASED_ENERGY_NONFINITE")

	var mapping_receipt := {
		"schema_version": MAPPING_RECEIPT_SCHEMA,
		"gate_id": GATE_ID,
		"route_id": ROUTE_ID,
		"mapping_profile_id": MAPPING_PROFILE_ID,
		"portable_route_id": PORTABLE_ROUTE_ID,
		"portable_mapping_profile_id": PORTABLE_MAPPING_PROFILE_ID,
		"epoch_contract_id": EpochTransport.EPOCH_CONTRACT_ID,
		"epoch_start_global_step": epoch_start,
		"global_semantic_step": global_step,
		"epoch_local_step": local_step,
		"rotation_aware_energy_source_receipt_sha256": raw_energy_sha256,
		"rotation_aware_source_component_receipts_sha256": raw_components_sha256,
		"observer_receipt_sha256": observer_sha256,
		"accumulator_before_sha256": before_sha256,
		"accumulator_after_sha256": after_sha256,
		"epoch_initializer_sha256": String(initializer["payload_sha256"]),
		"step_signed_discrete_staging_exchange_j": step_staging_j,
		"cumulative_signed_discrete_staging_exchange_j": cumulative_staging_j,
		"adapter_side_discrete_staging_event_count": local_step,
		"global_engine_sequence_preserved": true,
		"pre_epoch_staging_events_claimed": false,
		"staging_mapped_to_external_work": false,
		"staging_mapped_to_passive_dissipation": false,
		"rotation_integration_exchange_included_exactly_once": true,
		"portable_energy_route_changed": false,
		"portable_energy_mapping_profile_changed": false,
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"source_measurement": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	var mapping_sha256 := _sha256_v1(sdk, mapping_receipt)
	if mapping_sha256.is_empty():
		return _failure("QSDK_R10F_EPOCH_STAGING_MAPPING_DIGEST_FAILED")

	var source := {
		"schema_version": SOURCE_RECEIPT_SCHEMA,
		"source_route_id": ROUTE_ID,
		"energy_mapping_profile_id": MAPPING_PROFILE_ID,
		"portable_route_id": PORTABLE_ROUTE_ID,
		"portable_energy_mapping_profile_id": PORTABLE_MAPPING_PROFILE_ID,
		"epoch_contract_id": EpochTransport.EPOCH_CONTRACT_ID,
		"semantic_step": global_step,
		"global_semantic_step": global_step,
		"epoch_start_global_step": epoch_start,
		"epoch_local_step": local_step,
		"initial_mechanical_energy_j": float(initializer["initial_mechanical_energy_j"]),
		"current_mechanical_energy_j":
		float(rotation_aware_energy_source_receipt["current_mechanical_energy_j"]),
		"cumulative_applied_actuator_work_j": local_actuator_work,
		"cumulative_signed_external_work_j": local_external_work,
		"step_signed_constraint_exchange_j":
		float(rotation_aware_energy_source_receipt["step_signed_constraint_exchange_j"]),
		"step_position_constraint_potential_exchange_j":
		float(
			rotation_aware_energy_source_receipt["step_position_constraint_potential_exchange_j"]
		),
		"cumulative_signed_constraint_exchange_j": local_constraint_exchange,
		"step_signed_discrete_staging_exchange_j": step_staging_j,
		"cumulative_signed_discrete_staging_exchange_j": cumulative_staging_j,
		"cumulative_passive_dissipation_j": local_passive_dissipation,
		"adapter_side_discrete_staging_event_count": local_step,
		"discrete_staging_rule_id": Observer.RULE_ID,
		"recovery_energy_ledger_profile_id":
		RecoveryRoute.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID,
		"rotation_integration_kinetic_exchange_j":
		float(rotation_aware_energy_source_receipt["rotation_integration_kinetic_exchange_j"]),
		"rotation_integration_exchange_included_exactly_once": true,
		"partition_rule_id": QualifiedStagingRoute.PREDECESSOR_PARTITION_RULE_ID,
		"raw_step_signed_solver_exchange_j":
		float(rotation_aware_energy_source_receipt["raw_step_signed_solver_exchange_j"]),
		"step_actuator_work_j": float(rotation_aware_energy_source_receipt["step_actuator_work_j"]),
		"native_motor_work_subtracted_exactly_once": true,
		"motor_work_also_counted_as_constraint_exchange": false,
		"constraint_exchange_partition_complete": true,
		"passive_dissipation_partition_complete": true,
		"component_partition_complete": true,
		"exact_balance_safety_authority": true,
		"unclosed_energy_residual_preserved": false,
		"mechanical_energy_residual_used_as_work_source": false,
		"residual_balancing_permitted": false,
		"staging_mapped_to_external_work": false,
		"staging_mapped_to_passive_dissipation": false,
		"mechanical_energy_change_used_as_staging_input": false,
		"energy_balance_residual_used_as_staging_input": false,
		"acceptance_threshold_used_as_staging_input": false,
		"rotation_aware_energy_source_receipt_sha256": raw_energy_sha256,
		"rotation_aware_source_component_receipts_sha256": raw_components_sha256,
		"discrete_staging_observer_receipt_sha256": observer_sha256,
		"discrete_staging_accumulator_sha256": after_sha256,
		"discrete_staging_mapping_receipt_sha256": mapping_sha256,
		"epoch_initializer_sha256": String(initializer["payload_sha256"]),
		"kick_interaction_receipt_sha256": String(initializer["kick_interaction_receipt_sha256"]),
		"source_measurement": true,
		"global_counters_mutated": false,
		"kick_work_included_in_recovery_epoch_ledger": false,
		"force_aware_recovery_used": false,
	}
	var components := {
		"schema_version": SOURCE_COMPONENT_RECEIPTS_SCHEMA,
		"source_route_id": ROUTE_ID,
		"energy_mapping_profile_id": MAPPING_PROFILE_ID,
		"semantic_step": global_step,
		"epoch_start_global_step": epoch_start,
		"epoch_local_step": local_step,
		"rotation_aware_energy_source_receipt":
		rotation_aware_energy_source_receipt.duplicate(true),
		"rotation_aware_energy_source_receipt_sha256": raw_energy_sha256,
		"rotation_aware_source_component_receipts":
		rotation_aware_source_component_receipts.duplicate(true),
		"rotation_aware_source_component_receipts_sha256": raw_components_sha256,
		"discrete_staging_observer_receipt": observer_receipt.duplicate(true),
		"discrete_staging_observer_receipt_sha256": observer_sha256,
		"discrete_staging_accumulator_before": accumulator_before.duplicate(true),
		"discrete_staging_accumulator_before_sha256": before_sha256,
		"discrete_staging_accumulator_after": accumulator_after.duplicate(true),
		"discrete_staging_accumulator_after_sha256": after_sha256,
		"discrete_staging_mapping_receipt": mapping_receipt.duplicate(true),
		"discrete_staging_mapping_receipt_sha256": mapping_sha256,
		"epoch_initializer": initializer.duplicate(true),
		"epoch_initializer_sha256": String(initializer["payload_sha256"]),
		"component_partition_complete": true,
		"rotation_integration_exchange_included_exactly_once": true,
		"mechanical_energy_residual_used_as_work_source": false,
		"source_measurement": true,
	}
	if not source_receipt_complete_v1(source):
		return _failure("QSDK_R10F_EPOCH_STAGING_MAPPED_SOURCE_INVALID")
	if not source_components_complete_v1(sdk, source, components):
		return _failure("QSDK_R10F_EPOCH_STAGING_MAPPED_COMPONENTS_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r10f_recovery_epoch_discrete_staging_step_mapping_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"energy_source_receipt": source,
		"source_component_receipts": components,
		"mapping_receipt": mapping_receipt,
		"mapping_receipt_sha256": mapping_sha256,
		"accumulator_after": accumulator_after,
		"accumulator_after_sha256": after_sha256,
		"epoch_start_global_step": epoch_start,
		"global_semantic_step": global_step,
		"epoch_local_step": local_step,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func compose_observations_v1(
	sdk: Object,
	observation_base: Dictionary,
	mapped_step: Dictionary,
) -> Dictionary:
	if sdk == null or not bool(mapped_step.get("ok", false)):
		return _failure("QSDK_R10F_EPOCH_OBSERVATION_MAPPING_INVALID")
	var source_value: Variant = mapped_step.get("energy_source_receipt")
	var components_value: Variant = mapped_step.get("source_component_receipts")
	if not (source_value is Dictionary) or not (components_value is Dictionary):
		return _failure("QSDK_R10F_EPOCH_OBSERVATION_SOURCE_MISSING")
	var source: Dictionary = source_value
	var components: Dictionary = components_value
	if (
		not source_receipt_complete_v1(source)
		or not source_components_complete_v1(sdk, source, components)
	):
		return _failure("QSDK_R10F_EPOCH_OBSERVATION_SOURCE_INVALID")
	var engine_identity: Dictionary = observation_base.get("engine_step_identity", {})
	if (
		int(engine_identity.get("semantic_step", -1)) != int(source["global_semantic_step"])
		or not bool(engine_identity.get("post_step_observation", false))
	):
		return _failure("QSDK_R10F_EPOCH_OBSERVATION_GLOBAL_STEP_MISMATCH")

	var source_sha256 := _sha256_v1(sdk, source)
	var components_sha256 := _sha256_v1(sdk, components)
	var mapping_sha256 := String(mapped_step.get("mapping_receipt_sha256", ""))
	if (
		source_sha256.is_empty()
		or components_sha256.is_empty()
		or not _digest_valid_v1(mapping_sha256)
	):
		return _failure("QSDK_R10F_EPOCH_OBSERVATION_DIGEST_FAILED")
	var energy_v2 := {
		"schema_version": "sporespore_recovery_energy_balance_ledger_v2",
		"equation_id":
		"current_minus_initial_minus_actuator_minus_external_minus_constraint_plus_passive_v2",
		"component_partition_id":
		"sporespore_disjoint_actuator_external_constraint_passive_energy_partition_v2",
		"source_profile_id": PORTABLE_MAPPING_PROFILE_ID,
		"source_values_sha256": source_sha256,
		"initial_mechanical_energy_j": float(source["initial_mechanical_energy_j"]),
		"current_mechanical_energy_j": float(source["current_mechanical_energy_j"]),
		"cumulative_applied_actuator_work_j": float(source["cumulative_applied_actuator_work_j"]),
		"cumulative_signed_external_work_j": float(source["cumulative_signed_external_work_j"]),
		"cumulative_signed_constraint_exchange_j":
		float(source["cumulative_signed_constraint_exchange_j"]),
		"cumulative_passive_dissipation_j": float(source["cumulative_passive_dissipation_j"]),
		"source_measurement": true,
	}
	var energy_v3 := energy_v2.duplicate(true)
	energy_v3["schema_version"] = "sporespore_recovery_energy_balance_ledger_v3"
	energy_v3["equation_id"] = "current_minus_initial_minus_actuator_minus_external_minus_constraint_minus_discrete_staging_plus_passive_v3"
	energy_v3["component_partition_id"] = "sporespore_disjoint_actuator_external_constraint_discrete_staging_passive_energy_partition_v3"
	energy_v3["cumulative_signed_discrete_staging_exchange_j"] = float(
		source["cumulative_signed_discrete_staging_exchange_j"]
	)
	var observation_v2 := observation_base.duplicate(true)
	observation_v2["schema_version"] = "sporespore_recovery_observation_v2"
	observation_v2["energy_balance"] = energy_v2
	var observation_v3 := observation_base.duplicate(true)
	observation_v3["schema_version"] = "sporespore_recovery_observation_v3"
	observation_v3["energy_balance"] = energy_v3
	# Retain the richer epoch provenance next to, rather than in place of, the
	# public V2 source-binding ABI. The portable core deliberately knows only
	# the already-qualified R148 route/profile tuple; exposing the R10F route in
	# that field would make a valid offset observation look like an unqualified
	# collector. The two bindings share the same measured payload hashes.
	var epoch_binding := {
		"schema_version": "sporespore_qsdk_r10f_recovery_epoch_observation_source_binding_v1",
		"producer_adapter_id": RecoveryRoute.ADAPTER_ID,
		"source_route_id": ROUTE_ID,
		"portable_source_route_id": PORTABLE_ROUTE_ID,
		"mapping_profile_id": MAPPING_PROFILE_ID,
		"portable_mapping_profile_id": PORTABLE_MAPPING_PROFILE_ID,
		"global_semantic_step": int(source["global_semantic_step"]),
		"epoch_start_global_step": int(source["epoch_start_global_step"]),
		"epoch_local_step": int(source["epoch_local_step"]),
		"source_values_sha256": source_sha256,
		"source_component_receipts_sha256": components_sha256,
		"mapping_receipt_sha256": mapping_sha256,
		"observation_base_sha256": _sha256_v1(sdk, observation_base),
		"ledger_v2_sha256": _sha256_v1(sdk, energy_v2),
		"ledger_v3_sha256": _sha256_v1(sdk, energy_v3),
		"portable_observation_v2_sha256": _sha256_v1(sdk, observation_v2),
		"portable_observation_v3_sha256": _sha256_v1(sdk, observation_v3),
		"global_sequence_rewrite_permitted": false,
		"source_measurement": true,
	}
	for digest_key in [
		"observation_base_sha256",
		"ledger_v2_sha256",
		"ledger_v3_sha256",
		"portable_observation_v2_sha256",
		"portable_observation_v3_sha256",
	]:
		if not _digest_valid_v1(String(epoch_binding[digest_key])):
			return _failure("QSDK_R10F_EPOCH_OBSERVATION_BINDING_DIGEST_FAILED")
	var source_binding := {
		"schema_version": "sporespore_recovery_observation_v2_source_binding_v1",
		"producer_adapter_id": RecoveryRoute.ADAPTER_ID,
		"source_route_id": PORTABLE_ROUTE_ID,
		"mapping_profile_id": PORTABLE_MAPPING_PROFILE_ID,
		"mapping_receipt_sha256": mapping_sha256,
		"source_component_receipts_sha256": components_sha256,
		"observation_base_sha256": String(epoch_binding["observation_base_sha256"]),
		"ledger_sha256": String(epoch_binding["ledger_v2_sha256"]),
		"portable_observation_sha256": String(epoch_binding["portable_observation_v2_sha256"]),
	}
	source_binding["source_chain_sha256"] = _sha256_v1(sdk, source_binding)
	if not _digest_valid_v1(String(source_binding["source_chain_sha256"])):
		return _failure("QSDK_R10F_EPOCH_PORTABLE_SOURCE_CHAIN_DIGEST_FAILED")
	return {
		"schema_version": BOUND_OBSERVATIONS_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"observation_v2": observation_v2,
		"observation_v3": observation_v3,
		"source_binding": source_binding,
		"epoch_source_binding": epoch_binding,
		"mapping_receipt": mapped_step["mapping_receipt"],
		"energy_source_receipt": source,
		"source_component_receipts": components,
		"adapter_side_discrete_staging_event_count":
		int(source["adapter_side_discrete_staging_event_count"]),
		"missing_measurement_synthesis_count": 0,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func accumulator_valid_v1(value: Dictionary) -> bool:
	if not _keys_exact_v1(value, ACCUMULATOR_KEYS):
		return false
	var epoch_start := int(value.get("epoch_start_global_step", -1))
	var global_sequence := int(value.get("global_sequence", -1))
	var local_count := int(value.get("epoch_local_event_count", -1))
	if (
		String(value.get("schema_version", "")) != ACCUMULATOR_SCHEMA
		or String(value.get("epoch_contract_id", "")) != EpochTransport.EPOCH_CONTRACT_ID
		or epoch_start <= 0
		or global_sequence < epoch_start
		or local_count != global_sequence - epoch_start
		or not is_finite(float(value.get("cumulative_signed_discrete_staging_exchange_j", NAN)))
		or not _digest_valid_v1(String(value.get("epoch_initializer_sha256", "")))
		or not bool(value.get("source_measurement", false))
		or bool(value.get("global_sequence_rewrite_permitted", true))
		or bool(value.get("unobserved_pre_epoch_event_count_claimed", true))
		or bool(value.get("mechanical_energy_change_used_as_input", true))
		or bool(value.get("energy_balance_residual_used_as_input", true))
		or bool(value.get("acceptance_threshold_used_as_input", true))
		or bool(value.get("physical_acceptance_authority", true))
		or bool(value.get("release_authority", true))
	):
		return false
	if local_count == 0:
		return (
			float(value["cumulative_signed_discrete_staging_exchange_j"]) == 0.0
			and value.get("last_observer_receipt_sha256") == null
			and value.get("previous_accumulator_sha256") == null
		)
	return (
		_digest_valid_v1(String(value.get("last_observer_receipt_sha256", "")))
		and _digest_valid_v1(String(value.get("previous_accumulator_sha256", "")))
	)


static func source_receipt_complete_v1(value: Dictionary) -> bool:
	for key in [
		"semantic_step",
		"global_semantic_step",
		"epoch_start_global_step",
		"epoch_local_step",
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
		"rotation_integration_kinetic_exchange_j",
		"raw_step_signed_solver_exchange_j",
		"step_actuator_work_j",
	]:
		if not value.has(key) or not is_finite(float(value[key])):
			return false
	var global_step := int(value.get("global_semantic_step", -1))
	var epoch_start := int(value.get("epoch_start_global_step", -1))
	var local_step := int(value.get("epoch_local_step", -1))
	if (
		String(value.get("schema_version", "")) != SOURCE_RECEIPT_SCHEMA
		or String(value.get("source_route_id", "")) != ROUTE_ID
		or String(value.get("energy_mapping_profile_id", "")) != MAPPING_PROFILE_ID
		or String(value.get("portable_route_id", "")) != PORTABLE_ROUTE_ID
		or (
			String(value.get("portable_energy_mapping_profile_id", ""))
			!= PORTABLE_MAPPING_PROFILE_ID
		)
		or String(value.get("epoch_contract_id", "")) != EpochTransport.EPOCH_CONTRACT_ID
		or int(value.get("semantic_step", -1)) != global_step
		or local_step != global_step - epoch_start
		or local_step <= 0
		or int(value.get("adapter_side_discrete_staging_event_count", -1)) != local_step
		or String(value.get("discrete_staging_rule_id", "")) != Observer.RULE_ID
		or (
			String(value.get("recovery_energy_ledger_profile_id", ""))
			!= RecoveryRoute.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		)
		or (
			String(value.get("partition_rule_id", ""))
			!= QualifiedStagingRoute.PREDECESSOR_PARTITION_RULE_ID
		)
		or not bool(value.get("rotation_integration_exchange_included_exactly_once", false))
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
		or bool(value.get("global_counters_mutated", true))
		or bool(value.get("kick_work_included_in_recovery_epoch_ledger", true))
		or bool(value.get("force_aware_recovery_used", true))
	):
		return false
	for digest_key in [
		"rotation_aware_energy_source_receipt_sha256",
		"rotation_aware_source_component_receipts_sha256",
		"discrete_staging_observer_receipt_sha256",
		"discrete_staging_accumulator_sha256",
		"discrete_staging_mapping_receipt_sha256",
		"epoch_initializer_sha256",
		"kick_interaction_receipt_sha256",
	]:
		if not _digest_valid_v1(String(value.get(digest_key, ""))):
			return false
	return true


static func source_components_complete_v1(
	sdk: Object,
	source: Dictionary,
	components: Dictionary,
) -> bool:
	if sdk == null or not source_receipt_complete_v1(source):
		return false
	for key in [
		"rotation_aware_energy_source_receipt",
		"rotation_aware_source_component_receipts",
		"discrete_staging_observer_receipt",
		"discrete_staging_accumulator_before",
		"discrete_staging_accumulator_after",
		"discrete_staging_mapping_receipt",
		"epoch_initializer",
	]:
		if not (components.get(key) is Dictionary):
			return false
	var raw_energy: Dictionary = components["rotation_aware_energy_source_receipt"]
	var raw_components: Dictionary = components["rotation_aware_source_component_receipts"]
	var observer: Dictionary = components["discrete_staging_observer_receipt"]
	var before: Dictionary = components["discrete_staging_accumulator_before"]
	var after: Dictionary = components["discrete_staging_accumulator_after"]
	var mapping: Dictionary = components["discrete_staging_mapping_receipt"]
	var initializer: Dictionary = components["epoch_initializer"]
	return (
		String(components.get("schema_version", "")) == SOURCE_COMPONENT_RECEIPTS_SCHEMA
		and String(components.get("source_route_id", "")) == ROUTE_ID
		and String(components.get("energy_mapping_profile_id", "")) == MAPPING_PROFILE_ID
		and int(components.get("semantic_step", -1)) == int(source["semantic_step"])
		and (
			int(components.get("epoch_start_global_step", -1))
			== int(source["epoch_start_global_step"])
		)
		and int(components.get("epoch_local_step", -1)) == int(source["epoch_local_step"])
		and EnergyInitializer.rotation_aware_sources_valid_v1(sdk, raw_energy, raw_components)
		and _observer_receipt_valid_v1(observer)
		and accumulator_valid_v1(before)
		and accumulator_valid_v1(after)
		and EnergyInitializer.initializer_valid_v1(sdk, initializer)
		and int(after["global_sequence"]) == int(source["global_semantic_step"])
		and (
			int(after["epoch_local_event_count"])
			== int(source["adapter_side_discrete_staging_event_count"])
		)
		and (
			float(after["cumulative_signed_discrete_staging_exchange_j"])
			== float(source["cumulative_signed_discrete_staging_exchange_j"])
		)
		and String(mapping.get("schema_version", "")) == MAPPING_RECEIPT_SCHEMA
		and int(mapping.get("global_semantic_step", -1)) == int(source["global_semantic_step"])
		and int(mapping.get("epoch_local_step", -1)) == int(source["epoch_local_step"])
		and (
			_sha256_v1(sdk, raw_energy)
			== String(components.get("rotation_aware_energy_source_receipt_sha256", ""))
		)
		and (
			_sha256_v1(sdk, raw_components)
			== String(components.get("rotation_aware_source_component_receipts_sha256", ""))
		)
		and (
			_sha256_v1(sdk, observer)
			== String(components.get("discrete_staging_observer_receipt_sha256", ""))
		)
		and (
			_sha256_v1(sdk, before)
			== String(components.get("discrete_staging_accumulator_before_sha256", ""))
		)
		and (
			_sha256_v1(sdk, after)
			== String(components.get("discrete_staging_accumulator_after_sha256", ""))
		)
		and (
			_sha256_v1(sdk, mapping)
			== String(components.get("discrete_staging_mapping_receipt_sha256", ""))
		)
		and (
			String(initializer["payload_sha256"])
			== String(components.get("epoch_initializer_sha256", ""))
		)
		and (
			String(components.get("discrete_staging_observer_receipt_sha256", ""))
			== String(source["discrete_staging_observer_receipt_sha256"])
		)
		and (
			String(components.get("discrete_staging_accumulator_after_sha256", ""))
			== String(source["discrete_staging_accumulator_sha256"])
		)
		and (
			String(components.get("discrete_staging_mapping_receipt_sha256", ""))
			== String(source["discrete_staging_mapping_receipt_sha256"])
		)
		and bool(components.get("component_partition_complete", false))
		and bool(components.get("rotation_integration_exchange_included_exactly_once", false))
		and not bool(components.get("mechanical_energy_residual_used_as_work_source", true))
		and bool(components.get("source_measurement", false))
	)


static func _observer_receipt_valid_v1(value: Dictionary) -> bool:
	for outcome_key in OUTCOME_DERIVED_KEYS:
		if value.has(outcome_key):
			return false
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
		and String(value.get("gate_id", "")) == QualifiedStagingRoute.GATE_ID
		and String(value.get("rule_id", "")) == Observer.RULE_ID
		and int(value.get("sequence", 0)) > 0
		and int(value.get("previous_sequence", -1)) == int(value.get("sequence", 0)) - 1
		and int(value.get("body_count", -1)) == EXPECTED_BODY_COUNT
		and (
			float(value["signed_discrete_staging_exchange_j"])
			== (
				float(value["force_integration_kinetic_exchange_j"])
				+ float(value["position_integration_potential_exchange_j"])
			)
		)
		and bool(value.get("source_measurement", false))
		and not bool(value.get("mechanical_energy_change_used_as_input", true))
		and not bool(value.get("energy_balance_residual_used_as_input", true))
		and not bool(value.get("acceptance_threshold_used_as_input", true))
		and not bool(value.get("constraint_exchange_used_as_staging_input", true))
		and not bool(value.get("controller_or_behavior_result_used_as_input", true))
		and not bool(value.get("physical_acceptance_authority", true))
		and not bool(value.get("release_authority", true))
	)


static func _initializer_shape_valid_v1(value: Dictionary) -> bool:
	return (
		String(value.get("schema_version", "")) == EnergyInitializer.INITIALIZER_SCHEMA
		and int(value.get("epoch_start_global_step", -1)) > 0
		and _digest_valid_v1(String(value.get("payload_sha256", "")))
		and int(value.get("recovery_local_discrete_staging_event_count", -1)) == 0
		and (
			float(value.get("recovery_local_cumulative_signed_discrete_staging_exchange_j", NAN))
			== 0.0
		)
		and not bool(value.get("kick_work_included_in_recovery_epoch_ledger", true))
		and not bool(value.get("force_aware_recovery_used", true))
	)


static func _sha256_v1(sdk: Object, value: Variant) -> String:
	if sdk == null:
		return ""
	var receipt := RecoveryRuntimeScript.canonicalize(sdk, _json_safe_v1(value))
	var digest := String(receipt.get("sha256", ""))
	return digest if _digest_valid_v1(digest) else ""


static func _json_safe_v1(value: Variant) -> Variant:
	if value is Vector3:
		var vector: Vector3 = value
		return [vector.x, vector.y, vector.z]
	if value is Dictionary:
		var mapped: Dictionary = {}
		for key in (value as Dictionary).keys():
			mapped[key] = _json_safe_v1((value as Dictionary)[key])
		return mapped
	if value is Array:
		var mapped_array: Array = []
		for item in value:
			mapped_array.append(_json_safe_v1(item))
		return mapped_array
	return value


static func _keys_exact_v1(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _digest_valid_v1(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _failure(code: String) -> Dictionary:
	return {
		"schema_version": FAILURE_SCHEMA,
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
