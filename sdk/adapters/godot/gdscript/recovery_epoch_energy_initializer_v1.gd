class_name SporeGodotJoltRecoveryEpochEnergyInitializerV1
extends RefCounted
# gdlint: disable=max-line-length

## Source-measured energy zero point for the R10F post-interaction epoch.
##
## The live world keeps its original counters. This receipt snapshots them at
## completed global step E and defines recovery-local deltas relative to that
## immutable snapshot. The kick (or matched no-kick event) remains a separate,
## content-addressed interaction record and is never reconstructed from an
## energy residual.

const EpochTransport := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_boundary_transport_v1.gd"
)
const QualifiedStagingRoute := preload(
	"res://sdk/adapters/godot/gdscript/recovery_discrete_staging_route_v1.gd"
)
const RecoveryRoute := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")

const GATE_ID := "QSDK-R10F"
const INITIALIZER_PROFILE_ID := "godot_jolt_r10f_live_post_interaction_energy_epoch_initializer_v1"
const INTERACTION_RECEIPT_SCHEMA := "sporespore_qsdk_r10f_kick_or_matched_no_kick_interaction_receipt_v1"
const INITIALIZER_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_energy_initializer_v1"
const INITIALIZATION_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_energy_initialization_v1"
const FAILURE_SCHEMA := "sporespore_qsdk_r10f_recovery_epoch_energy_initializer_failure_v1"
const ACTIVE_ARM_ID := "kick_passive_recovery_resume"
const BASELINE_ARM_ID := "matched_no_kick_continuation"
const ACTIVE_INTERACTION_KIND := "kick_impulse"
const BASELINE_INTERACTION_KIND := "matched_no_kick"
const KICK_IMPULSE_MAGNITUDE_N_S := 0.25
const NATIVE_EFFECT_FLOOR_M_S := 0.0001
const OUTCOME_DERIVED_KEYS := [
	"acceptance_threshold",
	"behavior_result",
	"energy_balance_residual_j",
	"physical_result",
	"recovery_success",
	"stable_stance_gate",
]

const INTERACTION_KEYS := [
	"schema_version",
	"attempt_id",
	"arm_id",
	"model_instance_id",
	"interaction_kind",
	"application_global_step",
	"completed_effect_global_step",
	"application_count",
	"requested_impulse_magnitude_n_s",
	"applied_impulse_magnitude_n_s",
	"native_effect_velocity_delta_m_s",
	"native_effect_measured",
	"matched_no_kick_observation_retained",
	"interaction_source_receipt_sha256",
	"source_measurement",
	"interaction_retained_separately",
	"kick_work_included_in_recovery_epoch_ledger",
	"mechanical_energy_residual_used_as_work_source",
	"force_aware_recovery_used",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]
const INITIALIZER_KEYS := [
	"schema_version",
	"initializer_profile_id",
	"epoch_contract_id",
	"attempt_id",
	"arm_id",
	"model_instance_id",
	"epoch_start_global_step",
	"initial_mechanical_energy_j",
	"world_start_initial_mechanical_energy_j",
	"global_cumulative_applied_actuator_work_at_epoch_start_j",
	"global_cumulative_signed_external_work_at_epoch_start_j",
	"global_cumulative_signed_constraint_exchange_at_epoch_start_j",
	"global_cumulative_signed_discrete_staging_exchange_at_epoch_start_j",
	"global_cumulative_passive_dissipation_at_epoch_start_j",
	"global_discrete_staging_event_count_at_epoch_start",
	"recovery_local_cumulative_applied_actuator_work_j",
	"recovery_local_cumulative_signed_external_work_j",
	"recovery_local_cumulative_signed_constraint_exchange_j",
	"recovery_local_cumulative_signed_discrete_staging_exchange_j",
	"recovery_local_cumulative_passive_dissipation_j",
	"recovery_local_discrete_staging_event_count",
	"completed_boundary_payload_sha256",
	"epoch_transport_state_sha256",
	"rotation_aware_energy_source_receipt_sha256",
	"rotation_aware_source_component_receipts_sha256",
	"global_discrete_staging_accumulator_sha256",
	"kick_interaction_receipt_sha256",
	"source_measurement",
	"translational_kinetic_energy_included",
	"rotational_kinetic_energy_included",
	"gravitational_potential_energy_included",
	"canonical_world_start_pose_reconstruction_used",
	"kick_work_included_in_recovery_epoch_ledger",
	"interaction_retained_separately",
	"global_counters_mutated",
	"mechanical_energy_residual_used_as_work_source",
	"force_aware_recovery_used",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]


static func build_interaction_receipt_v1(
	sdk: Object,
	attempt_id: String,
	arm_id: String,
	model_instance_id: String,
	application_global_step: int,
	completed_effect_global_step: int,
	native_effect_velocity_delta_m_s: float,
	interaction_source_receipt_sha256: String,
) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_INTERACTION_SDK_MISSING")
	var interaction_kind := ""
	var application_count := -1
	var requested_impulse_magnitude_n_s := NAN
	var applied_impulse_magnitude_n_s := NAN
	var native_effect_measured := false
	var matched_no_kick_observation_retained := false
	if arm_id == ACTIVE_ARM_ID:
		interaction_kind = ACTIVE_INTERACTION_KIND
		application_count = 1
		requested_impulse_magnitude_n_s = KICK_IMPULSE_MAGNITUDE_N_S
		applied_impulse_magnitude_n_s = KICK_IMPULSE_MAGNITUDE_N_S
		native_effect_measured = true
	elif arm_id == BASELINE_ARM_ID:
		interaction_kind = BASELINE_INTERACTION_KIND
		application_count = 0
		requested_impulse_magnitude_n_s = 0.0
		applied_impulse_magnitude_n_s = 0.0
		matched_no_kick_observation_retained = true
	else:
		return _failure("QSDK_R10F_INTERACTION_ARM_INVALID")
	var receipt := {
		"schema_version": INTERACTION_RECEIPT_SCHEMA,
		"attempt_id": attempt_id,
		"arm_id": arm_id,
		"model_instance_id": model_instance_id,
		"interaction_kind": interaction_kind,
		"application_global_step": application_global_step,
		"completed_effect_global_step": completed_effect_global_step,
		"application_count": application_count,
		"requested_impulse_magnitude_n_s": requested_impulse_magnitude_n_s,
		"applied_impulse_magnitude_n_s": applied_impulse_magnitude_n_s,
		"native_effect_velocity_delta_m_s": native_effect_velocity_delta_m_s,
		"native_effect_measured": native_effect_measured,
		"matched_no_kick_observation_retained": matched_no_kick_observation_retained,
		"interaction_source_receipt_sha256": interaction_source_receipt_sha256,
		"source_measurement": true,
		"interaction_retained_separately": true,
		"kick_work_included_in_recovery_epoch_ledger": false,
		"mechanical_energy_residual_used_as_work_source": false,
		"force_aware_recovery_used": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	receipt["payload_sha256"] = _payload_sha256_v1(sdk, receipt)
	if not interaction_receipt_valid_v1(sdk, receipt):
		return _failure("QSDK_R10F_INTERACTION_RECEIPT_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r10f_interaction_receipt_build_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"interaction_receipt": receipt,
		"interaction_receipt_sha256": String(receipt["payload_sha256"]),
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func initialize_energy_epoch_v1(
	sdk: Object,
	epoch_transport_state: Dictionary,
	rotation_aware_energy_source_receipt: Dictionary,
	rotation_aware_source_component_receipts: Dictionary,
	global_discrete_staging_accumulator: Dictionary,
	interaction_receipt: Dictionary,
) -> Dictionary:
	if sdk == null:
		return _failure("QSDK_R10F_EPOCH_ENERGY_SDK_MISSING")
	if not EpochTransport.state_valid_v1(sdk, epoch_transport_state):
		return _failure("QSDK_R10F_EPOCH_ENERGY_TRANSPORT_STATE_INVALID")
	if not interaction_receipt_valid_v1(sdk, interaction_receipt):
		return _failure("QSDK_R10F_EPOCH_ENERGY_INTERACTION_INVALID")
	if not rotation_aware_sources_valid_v1(
		sdk,
		rotation_aware_energy_source_receipt,
		rotation_aware_source_component_receipts,
	):
		return _failure("QSDK_R10F_EPOCH_ENERGY_ROTATION_AWARE_SOURCE_INVALID")
	if not global_staging_accumulator_valid_v1(global_discrete_staging_accumulator):
		return _failure("QSDK_R10F_EPOCH_ENERGY_GLOBAL_STAGING_ACCUMULATOR_INVALID")

	var epoch_start_global_step := int(epoch_transport_state["epoch_start_global_step"])
	if (
		int(epoch_transport_state["cached_global_boundary_step"]) != epoch_start_global_step
		or int(epoch_transport_state["accepted_epoch_pair_count"]) != 0
		or int(epoch_transport_state["state_revision"]) != 0
		or (
			int(rotation_aware_energy_source_receipt.get("semantic_step", -1))
			!= epoch_start_global_step
		)
		or int(global_discrete_staging_accumulator.get("sequence", -1)) != epoch_start_global_step
		or (
			int(global_discrete_staging_accumulator.get("event_count", -1))
			!= epoch_start_global_step
		)
		or (
			int(interaction_receipt.get("completed_effect_global_step", -1))
			!= epoch_start_global_step
		)
	):
		return _failure("QSDK_R10F_EPOCH_ENERGY_SEQUENCE_MISMATCH")
	for identity_key in ["attempt_id", "arm_id", "model_instance_id"]:
		if epoch_transport_state.get(identity_key) != interaction_receipt.get(identity_key):
			return _failure("QSDK_R10F_EPOCH_ENERGY_CROSSED_IDENTITY:%s" % identity_key)
	if (
		String(epoch_transport_state["kick_interaction_receipt_sha256"])
		!= String(interaction_receipt["payload_sha256"])
	):
		return _failure("QSDK_R10F_EPOCH_ENERGY_INTERACTION_DIGEST_MISMATCH")

	var energy_source_sha256 := _sha256_v1(sdk, rotation_aware_energy_source_receipt)
	var components_sha256 := _sha256_v1(sdk, rotation_aware_source_component_receipts)
	var staging_accumulator_sha256 := _sha256_v1(sdk, global_discrete_staging_accumulator)
	var transport_state_sha256 := String(epoch_transport_state["payload_sha256"])
	if (
		energy_source_sha256.is_empty()
		or components_sha256.is_empty()
		or staging_accumulator_sha256.is_empty()
		or not _digest_valid_v1(transport_state_sha256)
	):
		return _failure("QSDK_R10F_EPOCH_ENERGY_SOURCE_DIGEST_FAILED")

	var initializer := {
		"schema_version": INITIALIZER_SCHEMA,
		"initializer_profile_id": INITIALIZER_PROFILE_ID,
		"epoch_contract_id": EpochTransport.EPOCH_CONTRACT_ID,
		"attempt_id": String(epoch_transport_state["attempt_id"]),
		"arm_id": String(epoch_transport_state["arm_id"]),
		"model_instance_id": String(epoch_transport_state["model_instance_id"]),
		"epoch_start_global_step": epoch_start_global_step,
		"initial_mechanical_energy_j":
		float(rotation_aware_energy_source_receipt["current_mechanical_energy_j"]),
		"world_start_initial_mechanical_energy_j":
		float(rotation_aware_energy_source_receipt["initial_mechanical_energy_j"]),
		"global_cumulative_applied_actuator_work_at_epoch_start_j":
		float(rotation_aware_energy_source_receipt["cumulative_applied_actuator_work_j"]),
		"global_cumulative_signed_external_work_at_epoch_start_j":
		float(rotation_aware_energy_source_receipt["cumulative_signed_external_work_j"]),
		"global_cumulative_signed_constraint_exchange_at_epoch_start_j":
		float(rotation_aware_energy_source_receipt["cumulative_signed_constraint_exchange_j"]),
		"global_cumulative_signed_discrete_staging_exchange_at_epoch_start_j":
		float(global_discrete_staging_accumulator["cumulative_signed_discrete_staging_exchange_j"]),
		"global_cumulative_passive_dissipation_at_epoch_start_j":
		float(rotation_aware_energy_source_receipt["cumulative_passive_dissipation_j"]),
		"global_discrete_staging_event_count_at_epoch_start":
		int(global_discrete_staging_accumulator["event_count"]),
		"recovery_local_cumulative_applied_actuator_work_j": 0.0,
		"recovery_local_cumulative_signed_external_work_j": 0.0,
		"recovery_local_cumulative_signed_constraint_exchange_j": 0.0,
		"recovery_local_cumulative_signed_discrete_staging_exchange_j": 0.0,
		"recovery_local_cumulative_passive_dissipation_j": 0.0,
		"recovery_local_discrete_staging_event_count": 0,
		"completed_boundary_payload_sha256":
		String(epoch_transport_state["cached_completed_boundary_sha256"]),
		"epoch_transport_state_sha256": transport_state_sha256,
		"rotation_aware_energy_source_receipt_sha256": energy_source_sha256,
		"rotation_aware_source_component_receipts_sha256": components_sha256,
		"global_discrete_staging_accumulator_sha256": staging_accumulator_sha256,
		"kick_interaction_receipt_sha256": String(interaction_receipt["payload_sha256"]),
		"source_measurement": true,
		"translational_kinetic_energy_included": true,
		"rotational_kinetic_energy_included": true,
		"gravitational_potential_energy_included": true,
		"canonical_world_start_pose_reconstruction_used": false,
		"kick_work_included_in_recovery_epoch_ledger": false,
		"interaction_retained_separately": true,
		"global_counters_mutated": false,
		"mechanical_energy_residual_used_as_work_source": false,
		"force_aware_recovery_used": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	initializer["payload_sha256"] = _payload_sha256_v1(sdk, initializer)
	if not initializer_valid_v1(sdk, initializer):
		return _failure("QSDK_R10F_EPOCH_ENERGY_INITIALIZER_INVALID")
	return {
		"schema_version": INITIALIZATION_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"initializer": initializer,
		"initializer_sha256": String(initializer["payload_sha256"]),
		"epoch_start_global_step": epoch_start_global_step,
		"recovery_local_step": 0,
		"global_counters_mutated": false,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func interaction_receipt_valid_v1(sdk: Object, receipt: Dictionary) -> bool:
	if (
		sdk == null
		or not _keys_exact_v1(receipt, INTERACTION_KEYS)
		or String(receipt.get("schema_version", "")) != INTERACTION_RECEIPT_SCHEMA
	):
		return false
	for identity_key in ["attempt_id", "arm_id", "model_instance_id"]:
		if (
			typeof(receipt.get(identity_key)) != TYPE_STRING
			or String(receipt[identity_key]).is_empty()
		):
			return false
	var arm_id := String(receipt["arm_id"])
	var active := arm_id == ACTIVE_ARM_ID
	var baseline := arm_id == BASELINE_ARM_ID
	if not active and not baseline:
		return false
	var application_step := int(receipt.get("application_global_step", -1))
	var effect_step := int(receipt.get("completed_effect_global_step", -1))
	var effect_delta := float(receipt.get("native_effect_velocity_delta_m_s", NAN))
	if (
		application_step <= 0
		or effect_step != application_step
		or not is_finite(effect_delta)
		or effect_delta < 0.0
		or not _digest_valid_v1(String(receipt.get("interaction_source_receipt_sha256", "")))
		or not bool(receipt.get("source_measurement", false))
		or not bool(receipt.get("interaction_retained_separately", false))
		or bool(receipt.get("kick_work_included_in_recovery_epoch_ledger", true))
		or bool(receipt.get("mechanical_energy_residual_used_as_work_source", true))
		or bool(receipt.get("force_aware_recovery_used", true))
		or bool(receipt.get("physical_acceptance_authority", true))
		or bool(receipt.get("release_authority", true))
	):
		return false
	if active:
		if (
			String(receipt.get("interaction_kind", "")) != ACTIVE_INTERACTION_KIND
			or int(receipt.get("application_count", -1)) != 1
			or (
				float(receipt.get("requested_impulse_magnitude_n_s", NAN))
				!= KICK_IMPULSE_MAGNITUDE_N_S
			)
			or (
				float(receipt.get("applied_impulse_magnitude_n_s", NAN))
				!= KICK_IMPULSE_MAGNITUDE_N_S
			)
			or effect_delta < NATIVE_EFFECT_FLOOR_M_S
			or not bool(receipt.get("native_effect_measured", false))
			or bool(receipt.get("matched_no_kick_observation_retained", true))
		):
			return false
	else:
		if (
			String(receipt.get("interaction_kind", "")) != BASELINE_INTERACTION_KIND
			or int(receipt.get("application_count", -1)) != 0
			or float(receipt.get("requested_impulse_magnitude_n_s", NAN)) != 0.0
			or float(receipt.get("applied_impulse_magnitude_n_s", NAN)) != 0.0
			or bool(receipt.get("native_effect_measured", true))
			or not bool(receipt.get("matched_no_kick_observation_retained", false))
		):
			return false
	return String(receipt.get("payload_sha256", "")) == _payload_sha256_v1(sdk, receipt)


static func initializer_valid_v1(sdk: Object, initializer: Dictionary) -> bool:
	if (
		sdk == null
		or not _keys_exact_v1(initializer, INITIALIZER_KEYS)
		or String(initializer.get("schema_version", "")) != INITIALIZER_SCHEMA
		or String(initializer.get("initializer_profile_id", "")) != INITIALIZER_PROFILE_ID
		or String(initializer.get("epoch_contract_id", "")) != EpochTransport.EPOCH_CONTRACT_ID
		or int(initializer.get("epoch_start_global_step", -1)) <= 0
	):
		return false
	for identity_key in ["attempt_id", "arm_id", "model_instance_id"]:
		if (
			typeof(initializer.get(identity_key)) != TYPE_STRING
			or String(initializer[identity_key]).is_empty()
		):
			return false
	for numeric_key in [
		"initial_mechanical_energy_j",
		"world_start_initial_mechanical_energy_j",
		"global_cumulative_applied_actuator_work_at_epoch_start_j",
		"global_cumulative_signed_external_work_at_epoch_start_j",
		"global_cumulative_signed_constraint_exchange_at_epoch_start_j",
		"global_cumulative_signed_discrete_staging_exchange_at_epoch_start_j",
		"global_cumulative_passive_dissipation_at_epoch_start_j",
		"recovery_local_cumulative_applied_actuator_work_j",
		"recovery_local_cumulative_signed_external_work_j",
		"recovery_local_cumulative_signed_constraint_exchange_j",
		"recovery_local_cumulative_signed_discrete_staging_exchange_j",
		"recovery_local_cumulative_passive_dissipation_j",
	]:
		if not initializer.has(numeric_key) or not is_finite(float(initializer[numeric_key])):
			return false
	for local_zero_key in [
		"recovery_local_cumulative_applied_actuator_work_j",
		"recovery_local_cumulative_signed_external_work_j",
		"recovery_local_cumulative_signed_constraint_exchange_j",
		"recovery_local_cumulative_signed_discrete_staging_exchange_j",
		"recovery_local_cumulative_passive_dissipation_j",
	]:
		if float(initializer[local_zero_key]) != 0.0:
			return false
	if (
		(
			int(initializer.get("global_discrete_staging_event_count_at_epoch_start", -1))
			!= int(initializer["epoch_start_global_step"])
		)
		or int(initializer.get("recovery_local_discrete_staging_event_count", -1)) != 0
	):
		return false
	for digest_key in [
		"completed_boundary_payload_sha256",
		"epoch_transport_state_sha256",
		"rotation_aware_energy_source_receipt_sha256",
		"rotation_aware_source_component_receipts_sha256",
		"global_discrete_staging_accumulator_sha256",
		"kick_interaction_receipt_sha256",
	]:
		if not _digest_valid_v1(String(initializer.get(digest_key, ""))):
			return false
	if (
		not bool(initializer.get("source_measurement", false))
		or not bool(initializer.get("translational_kinetic_energy_included", false))
		or not bool(initializer.get("rotational_kinetic_energy_included", false))
		or not bool(initializer.get("gravitational_potential_energy_included", false))
		or bool(initializer.get("canonical_world_start_pose_reconstruction_used", true))
		or bool(initializer.get("kick_work_included_in_recovery_epoch_ledger", true))
		or not bool(initializer.get("interaction_retained_separately", false))
		or bool(initializer.get("global_counters_mutated", true))
		or bool(initializer.get("mechanical_energy_residual_used_as_work_source", true))
		or bool(initializer.get("force_aware_recovery_used", true))
		or bool(initializer.get("physical_acceptance_authority", true))
		or bool(initializer.get("release_authority", true))
	):
		return false
	return String(initializer.get("payload_sha256", "")) == _payload_sha256_v1(sdk, initializer)


static func rotation_aware_sources_valid_v1(
	sdk: Object,
	energy_source: Dictionary,
	components: Dictionary,
) -> bool:
	if sdk == null:
		return false
	for outcome_key in OUTCOME_DERIVED_KEYS:
		if energy_source.has(outcome_key) or components.has(outcome_key):
			return false
	var solver_value: Variant = components.get("solver_energy_exchange_receipt")
	var partition_value: Variant = components.get("solver_coupled_partition_receipt")
	if not (solver_value is Dictionary) or not (partition_value is Dictionary):
		return false
	var solver: Dictionary = solver_value
	var partition: Dictionary = partition_value
	var semantic_step := int(energy_source.get("semantic_step", -1))
	for key in [
		"initial_mechanical_energy_j",
		"current_mechanical_energy_j",
		"cumulative_applied_actuator_work_j",
		"cumulative_signed_external_work_j",
		"cumulative_signed_constraint_exchange_j",
		"cumulative_passive_dissipation_j",
		"step_signed_constraint_exchange_j",
		"step_position_constraint_potential_exchange_j",
		"raw_step_signed_solver_exchange_j",
		"step_actuator_work_j",
		"rotation_integration_kinetic_exchange_j",
	]:
		if not energy_source.has(key) or not is_finite(float(energy_source[key])):
			return false
	return (
		(
			String(energy_source.get("schema_version", ""))
			== RecoveryRoute.R162_ROTATION_AWARE_SOURCE_RECEIPT_SCHEMA
		)
		and (
			String(components.get("schema_version", ""))
			== RecoveryRoute.R162_ROTATION_AWARE_COMPONENT_RECEIPTS_SCHEMA
		)
		and semantic_step > 0
		and int(components.get("semantic_step", -1)) == semantic_step
		and int(energy_source.get("adapter_side_discrete_staging_event_count", -1)) == 0
		and float(energy_source.get("cumulative_signed_discrete_staging_exchange_j", NAN)) == 0.0
		and (
			String(energy_source.get("recovery_energy_ledger_profile_id", ""))
			== RecoveryRoute.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		)
		and (
			String(components.get("recovery_energy_ledger_profile_id", ""))
			== RecoveryRoute.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		)
		and (
			String(solver.get("schema_version", ""))
			== RecoveryRoute.R162_SOLVER_ENERGY_CONSUMER_CONTRACT_SCHEMA
		)
		and (
			String(solver.get("telemetry_schema_version", ""))
			== RecoveryRoute.R162_SOLVER_ENERGY_TELEMETRY_SCHEMA
		)
		and (
			String(solver.get("telemetry_profile_id", ""))
			== RecoveryRoute.R162_SOLVER_ENERGY_TELEMETRY_PROFILE_ID
		)
		and (
			String(partition.get("schema_version", ""))
			== RecoveryRoute.R162_ROTATION_AWARE_PARTITION_CONTRACT_SCHEMA
		)
		and (
			String(partition.get("recovery_energy_ledger_profile_id", ""))
			== RecoveryRoute.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		)
		and int(partition.get("expected_space_step_sequence", -1)) == semantic_step
		and int(partition.get("numerical_term_count", -1)) == 14
		and bool(solver.get("rotation_integration_partition_complete", false))
		and bool(partition.get("rotation_integration_partition_complete", false))
		and bool(partition.get("rotation_integration_exchange_included_exactly_once", false))
		and bool(energy_source.get("rotation_integration_exchange_included_exactly_once", false))
		and bool(components.get("rotation_integration_exchange_included_exactly_once", false))
		and bool(energy_source.get("source_measurement", false))
		and bool(components.get("source_measurement", false))
		and not bool(energy_source.get("mechanical_energy_residual_used_as_work_source", true))
		and not bool(components.get("mechanical_energy_residual_used_as_work_source", true))
		and (
			_sha256_v1(sdk, solver)
			== String(components.get("solver_energy_exchange_receipt_sha256", ""))
		)
		and (
			_sha256_v1(sdk, partition)
			== String(components.get("solver_coupled_partition_receipt_sha256", ""))
		)
		and (
			String(components.get("solver_energy_exchange_receipt_sha256", ""))
			== String(energy_source.get("solver_energy_exchange_receipt_sha256", ""))
		)
		and (
			String(components.get("solver_coupled_partition_receipt_sha256", ""))
			== String(energy_source.get("solver_coupled_partition_receipt_sha256", ""))
		)
		and (
			float(energy_source.get("rotation_integration_kinetic_exchange_j", NAN))
			== float(partition.get("rotation_integration_kinetic_exchange_j", NAN))
		)
		and (
			float(energy_source.get("step_signed_constraint_exchange_j", NAN))
			== float(partition.get("step_signed_constraint_exchange_j", NAN))
		)
		and (
			float(energy_source.get("raw_step_signed_solver_exchange_j", NAN))
			== float(partition.get("raw_step_signed_solver_exchange_j", NAN))
		)
		and (
			float(energy_source.get("step_actuator_work_j", NAN))
			== float(partition.get("step_actuator_work_j", NAN))
		)
	)


static func global_staging_accumulator_valid_v1(value: Dictionary) -> bool:
	for outcome_key in OUTCOME_DERIVED_KEYS:
		if value.has(outcome_key):
			return false
	var sequence := int(value.get("sequence", -1))
	return (
		String(value.get("schema_version", "")) == QualifiedStagingRoute.ACCUMULATOR_SCHEMA
		and sequence > 0
		and int(value.get("event_count", -1)) == sequence
		and is_finite(float(value.get("cumulative_signed_discrete_staging_exchange_j", NAN)))
		and _digest_valid_v1(String(value.get("last_observer_receipt_sha256", "")))
		and _digest_valid_v1(String(value.get("previous_accumulator_sha256", "")))
		and bool(value.get("source_measurement", false))
		and not bool(value.get("mechanical_energy_change_used_as_input", true))
		and not bool(value.get("energy_balance_residual_used_as_input", true))
		and not bool(value.get("acceptance_threshold_used_as_input", true))
		and not bool(value.get("physical_acceptance_authority", true))
		and not bool(value.get("release_authority", true))
	)


static func _payload_sha256_v1(sdk: Object, value: Dictionary) -> String:
	var payload := value.duplicate(true)
	payload.erase("payload_sha256")
	return _sha256_v1(sdk, payload)


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
