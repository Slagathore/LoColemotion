class_name SporeGodotJoltRecoveryEpochNativeMeasurementRouteV1
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=function-arguments-number

## Additive R10F production wrapper around the already-qualified R148/R162
## native collector.
##
## The historical collector continues to own the one real post-solver sample,
## its global sequence, native motor telemetry, rotation-aware energy source,
## and global staging accumulator. This wrapper only (a) retains those global
## outputs, (b) starts a recovery-local epoch at the completed post-interaction
## boundary E, and (c) advances the local view as L = G - E. It never rewrites
## a native callback or engine sequence.
##
## The historical native sampler commits its global counters while collecting.
## Consequently a later local projection failure cannot be rolled back. Such a
## failure is terminal and explicitly reported as post-global-commit; no claim
## of cross-ledger atomic rollback is made.

const RecoveryRoute := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const QualifiedTransport := preload(
	"res://sdk/adapters/godot/gdscript/recovery_contiguous_boundary_transport_v1.gd"
)
const EpochTransport := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_boundary_transport_v1.gd"
)
const EnergyInitializer := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_energy_initializer_v1.gd"
)
const EpochStagingRoute := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_discrete_staging_route_v1.gd"
)
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")

const GATE_ID := "QSDK-R10F"
const ROUTE_ID := "sporespore_qsdk_r10f_godot_jolt_recovery_epoch_native_measurement_route_v1"
const MODE_GLOBAL_ONLY := "global_only"
const MODE_INITIALIZE_EPOCH := "initialize_epoch"
const MODE_GLOBAL_AND_EPOCH := "global_and_epoch"
const VALID_MODES := [MODE_GLOBAL_ONLY, MODE_INITIALIZE_EPOCH, MODE_GLOBAL_AND_EPOCH]
const PROJECTION_SCHEMA := "sporespore_qsdk_r10f_committed_global_rotation_source_projection_v1"
const INITIALIZATION_SCHEMA := "sporespore_qsdk_r10f_native_measurement_epoch_initialization_v1"
const ADVANCE_SCHEMA := "sporespore_qsdk_r10f_native_measurement_epoch_advance_v1"
const COLLECTION_SCHEMA := "sporespore_qsdk_r10f_native_measurement_collection_v1"
const FAILURE_SCHEMA := "sporespore_qsdk_r10f_native_measurement_route_failure_v1"
const MODEL_EPOCH_TRANSPORT_STATE_KEY := "r10f_recovery_epoch_transport_state"
const MODEL_EPOCH_INITIALIZER_KEY := "r10f_recovery_epoch_energy_initializer"
const MODEL_EPOCH_ACCUMULATOR_KEY := "r10f_recovery_epoch_discrete_staging_accumulator"
const MODEL_EPOCH_INTERACTION_KEY := "r10f_recovery_epoch_interaction_receipt"
const MODEL_EPOCH_INITIALIZED_KEY := "r10f_recovery_epoch_initialized"
const OUTCOME_DERIVED_KEYS := [
	"acceptance_threshold",
	"behavior_result",
	"energy_balance_residual_j",
	"physical_result",
	"recovery_success",
	"stable_stance_gate",
]


## One physical entry point. The caller invokes it only after applying the
## command for G and after the engine has completed that solver step. Exactly
## one call to the retained collector is made.
static func collect_completed_step_v1(
	sdk: Object,
	context: Dictionary,
	model: Dictionary,
	application_intent: Dictionary,
	global_semantic_step: int,
	phase: String,
	epoch_mode: String,
	interaction_receipt: Dictionary = {},
	development_profiler: RefCounted = null,
	development_context_cache: RefCounted = null,
) -> Dictionary:
	if development_profiler != null:
		development_profiler.begin_v1("epoch_preflight")
	var preflight := collection_preflight_v1(
		sdk,
		context,
		model,
		application_intent,
		global_semantic_step,
		phase,
		epoch_mode,
		interaction_receipt,
		development_context_cache,
	)
	if development_profiler != null:
		development_profiler.end_v1("epoch_preflight")
	if not bool(preflight.get("ok", false)):
		return preflight

	var global_result := (
		RecoveryRoute
		. collect_discrete_staging_complete_energy_native_world_observation_v1(
			sdk,
			context,
			model,
			application_intent,
			global_semantic_step,
			phase,
			development_profiler,
			development_context_cache,
		)
	)
	if not bool(global_result.get("ok", false)):
		return _post_collection_failure(
			"QSDK_R10F_GLOBAL_NATIVE_COLLECTOR_REFUSED",
			global_result,
			false,
		)
	if development_profiler != null:
		development_profiler.begin_v1("global_projection")
	var projection := project_committed_global_result_v1(sdk, global_result, global_semantic_step)
	if development_profiler != null:
		development_profiler.end_v1("global_projection")
	if not bool(projection.get("ok", false)):
		return _post_collection_failure(
			"QSDK_R10F_GLOBAL_ROTATION_SOURCE_PROJECTION_REFUSED",
			projection,
			true,
		)

	if epoch_mode == MODE_GLOBAL_ONLY:
		return {
			"schema_version": COLLECTION_SCHEMA,
			"gate_id": GATE_ID,
			"ok": true,
			"route_id": ROUTE_ID,
			"epoch_mode": epoch_mode,
			"global_semantic_step": global_semantic_step,
			"epoch_local_step": null,
			"global_result": global_result,
			"global_projection": projection,
			"epoch_result": null,
			"retained_global_collector_unchanged": true,
			"global_sequence_rewrite_permitted": false,
			"cross_ledger_atomic_rollback_claimed": false,
			"native_runtime_observation_collection_executed": true,
			"model_construction_count": int(global_result["model_construction_count"]),
			"world_attempt_count": int(global_result["world_attempt_count"]),
			"world_build_count": int(global_result["world_build_count"]),
			"solver_step_count": int(global_result["solver_step_count"]),
			"physics_state_modified": true,
			"physical_acceptance_authority": false,
			"release_authority": false,
		}

	var global_state_value: Variant = model.get("contiguous_boundary_transport_state")
	var global_accumulator_value: Variant = model.get("discrete_staging_accumulator")
	if not (global_state_value is Dictionary) or not (global_accumulator_value is Dictionary):
		return _post_collection_failure(
			"QSDK_R10F_COMMITTED_GLOBAL_STATE_MISSING",
			{},
			true,
		)
	var completed_boundary_value: Variant = (global_state_value as Dictionary).get(
		"cached_completed_boundary"
	)
	if not (completed_boundary_value is Dictionary):
		return _post_collection_failure(
			"QSDK_R10F_COMMITTED_GLOBAL_BOUNDARY_MISSING",
			{},
			true,
		)
	var completed_boundary: Dictionary = completed_boundary_value
	if (
		int(completed_boundary.get("boundary_sequence", -1)) != global_semantic_step
		or not QualifiedTransport.boundary_valid_v1(
			sdk, completed_boundary, QualifiedTransport.COMPLETED_STEP_SOURCE_KIND
		)
	):
		return _post_collection_failure(
			"QSDK_R10F_COMMITTED_GLOBAL_BOUNDARY_INVALID",
			completed_boundary,
			true,
		)

	var epoch_result: Dictionary
	if development_profiler != null:
		development_profiler.begin_v1("local_epoch_projection")
	if epoch_mode == MODE_INITIALIZE_EPOCH:
		epoch_result = initialize_epoch_projection_v1(
			sdk,
			completed_boundary,
			projection["rotation_aware_energy_source_receipt"],
			projection["rotation_aware_source_component_receipts"],
			global_accumulator_value,
			interaction_receipt,
		)
	else:
		epoch_result = advance_epoch_projection_v1(
			sdk,
			model[MODEL_EPOCH_TRANSPORT_STATE_KEY],
			model[MODEL_EPOCH_INITIALIZER_KEY],
			model[MODEL_EPOCH_ACCUMULATOR_KEY],
			completed_boundary,
			projection,
		)
	if development_profiler != null:
		development_profiler.end_v1("local_epoch_projection")
	if not bool(epoch_result.get("ok", false)):
		return _post_collection_failure(
			"QSDK_R10F_LOCAL_EPOCH_PROJECTION_REFUSED",
			epoch_result,
			true,
		)

	# Commit only after every local transport, source, observer, mapping, and
	# composition check accepts. The global collector has already committed.
	if epoch_mode == MODE_INITIALIZE_EPOCH:
		model[MODEL_EPOCH_TRANSPORT_STATE_KEY] = (
			(epoch_result["epoch_transport_state"] as Dictionary).duplicate(true)
		)
		model[MODEL_EPOCH_INITIALIZER_KEY] = (
			(epoch_result["energy_initializer"] as Dictionary).duplicate(true)
		)
		model[MODEL_EPOCH_ACCUMULATOR_KEY] = (
			(epoch_result["epoch_staging_accumulator"] as Dictionary).duplicate(true)
		)
		model[MODEL_EPOCH_INTERACTION_KEY] = interaction_receipt.duplicate(true)
		model[MODEL_EPOCH_INITIALIZED_KEY] = true
	else:
		model[MODEL_EPOCH_TRANSPORT_STATE_KEY] = (
			(epoch_result["epoch_transport_state_after"] as Dictionary).duplicate(true)
		)
		model[MODEL_EPOCH_ACCUMULATOR_KEY] = (
			(epoch_result["epoch_staging_accumulator_after"] as Dictionary).duplicate(true)
		)

	return {
		"schema_version": COLLECTION_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"route_id": ROUTE_ID,
		"epoch_mode": epoch_mode,
		"global_semantic_step": global_semantic_step,
		"epoch_local_step": int(epoch_result["epoch_local_step"]),
		"global_result": global_result,
		"global_projection": projection,
		"epoch_result": epoch_result,
		"retained_global_collector_unchanged": true,
		"global_sequence_rewrite_permitted": false,
		"local_epoch_commit_after_all_local_checks": true,
		"cross_ledger_atomic_rollback_claimed": false,
		"global_commit_precedes_local_projection": true,
		"native_runtime_observation_collection_executed": true,
		"model_construction_count": int(global_result["model_construction_count"]),
		"world_attempt_count": int(global_result["world_attempt_count"]),
		"world_build_count": int(global_result["world_build_count"]),
		"solver_step_count": int(global_result["solver_step_count"]),
		"physics_state_modified": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Pure preflight. It prevents a deliberate mode error from consuming a native
## step, while leaving post-solver source validation to the retained collector.
static func collection_preflight_v1(
	sdk: Object,
	context: Dictionary,
	model: Dictionary,
	application_intent: Dictionary,
	global_semantic_step: int,
	phase: String,
	epoch_mode: String,
	interaction_receipt: Dictionary = {},
	development_context_cache: RefCounted = null,
) -> Dictionary:
	if (
		sdk == null
		or not bool(context.get("ok", false))
		or not bool(model.get("ok", false))
		or not bool(application_intent.get("ok", false))
		or global_semantic_step <= 0
		or phase.is_empty()
		or epoch_mode not in VALID_MODES
		or int(model.get("host_step_count", -1)) + 1 != global_semantic_step
		or int(application_intent.get("semantic_step", -1)) != global_semantic_step
		or String(application_intent.get("phase", "")) != phase
		or _has_outcome_derived_top_level_v1(application_intent)
		or _has_outcome_derived_top_level_v1(interaction_receipt)
	):
		return _failure("QSDK_R10F_NATIVE_MEASUREMENT_PREFLIGHT_INPUT_INVALID")
	if (
		(
			String(context.get("schema_version", ""))
			!= "sporespore_qsdk_r24d172_godot_initializer_retention_recovery_behavior_context_v18"
		)
		or not (
			development_context_cache.validate_v1(sdk, context, 0)
			if development_context_cache != null
			else RecoveryRoute.contiguous_boundary_recovery_behavior_context_binding_exact_v1(
				sdk, context
			)
		)
		or not bool(context.get("rotation_aware_energy_ledger_profile_selected", false))
		or not bool(context.get("contiguous_boundary_transport_profile_selected", false))
	):
		return _failure("QSDK_R10F_NATIVE_MEASUREMENT_CONTEXT_INVALID")
	var initialized := bool(model.get(MODEL_EPOCH_INITIALIZED_KEY, false))
	if epoch_mode == MODE_GLOBAL_ONLY:
		if initialized or not interaction_receipt.is_empty():
			return _failure("QSDK_R10F_GLOBAL_ONLY_MODE_CROSSED_EPOCH")
	elif epoch_mode == MODE_INITIALIZE_EPOCH:
		if (
			initialized
			or not EnergyInitializer.interaction_receipt_valid_v1(sdk, interaction_receipt)
			or (
				int(interaction_receipt.get("completed_effect_global_step", -1))
				!= global_semantic_step
			)
		):
			return _failure("QSDK_R10F_EPOCH_INITIALIZATION_MODE_INVALID")
	else:
		if (
			not initialized
			or not interaction_receipt.is_empty()
			or not _model_epoch_state_valid_v1(sdk, model)
		):
			return _failure("QSDK_R10F_EPOCH_ADVANCE_MODE_INVALID")
	return {
		"schema_version": "sporespore_qsdk_r10f_native_measurement_collection_preflight_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"epoch_mode": epoch_mode,
		"global_semantic_step": global_semantic_step,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Pure extraction canary used by zero-world qualification. It verifies that
## the live R163 wrapper still retains the original R162 rotation-aware source
## and all hashes needed by the new epoch route.
static func project_committed_global_result_v1(
	sdk: Object,
	global_result: Dictionary,
	expected_global_semantic_step: int,
) -> Dictionary:
	if (
		sdk == null
		or expected_global_semantic_step <= 0
		or not bool(global_result.get("ok", false))
		or (
			String(global_result.get("schema_version", ""))
			!= "sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_native_bound_measurement_v1"
		)
		or not bool(global_result.get("rotation_aware_energy_ledger_profile_selected", false))
		or not bool(global_result.get("contiguous_boundary_transport_profile_selected", false))
		or (
			int(global_result.get("contiguous_boundary_transport_state_revision", -1))
			!= expected_global_semantic_step
		)
	):
		return _failure("QSDK_R10F_COMMITTED_GLOBAL_RESULT_INVALID")
	var bound_value: Variant = global_result.get("bound")
	var measurement_value: Variant = global_result.get("measurement")
	if not (bound_value is Dictionary) or not (measurement_value is Dictionary):
		return _failure("QSDK_R10F_COMMITTED_GLOBAL_RESULT_SHAPE_INVALID")
	var bound: Dictionary = bound_value
	var measurement: Dictionary = measurement_value
	var mapping_value: Variant = bound.get("native_to_portable_staging_mapping")
	var observation_base_value: Variant = measurement.get("observation_base")
	if not (mapping_value is Dictionary) or not (observation_base_value is Dictionary):
		return _failure("QSDK_R10F_COMMITTED_GLOBAL_SOURCE_MISSING")
	var mapping: Dictionary = mapping_value
	var energy_value: Variant = mapping.get("rotation_aware_predecessor_energy_source_receipt")
	var components_value: Variant = mapping.get(
		"rotation_aware_predecessor_source_component_receipts"
	)
	if not (energy_value is Dictionary) or not (components_value is Dictionary):
		return _failure("QSDK_R10F_ROTATION_AWARE_PREDECESSOR_MISSING")
	var energy: Dictionary = energy_value
	var components: Dictionary = components_value
	var energy_sha := _sha256_v1(sdk, energy)
	var components_sha := _sha256_v1(sdk, components)
	if (
		int(energy.get("semantic_step", -1)) != expected_global_semantic_step
		or not EnergyInitializer.rotation_aware_sources_valid_v1(sdk, energy, components)
		or (
			energy_sha
			!= String(mapping.get("rotation_aware_predecessor_energy_source_receipt_sha256", ""))
		)
		or (
			components_sha
			!= String(
				mapping.get("rotation_aware_predecessor_source_component_receipts_sha256", "")
			)
		)
	):
		return _failure("QSDK_R10F_ROTATION_AWARE_PREDECESSOR_INVALID")
	var solver_receipt_value: Variant = components.get("solver_energy_exchange_receipt")
	if not (solver_receipt_value is Dictionary):
		return _failure("QSDK_R10F_SOLVER_DISPLACEMENT_SOURCE_MISSING")
	var displacement := _vector3_from_json_v1(
		(solver_receipt_value as Dictionary).get(
			"position_constraint_mass_weighted_displacement_kg_m", null
		)
	)
	if not displacement.is_finite():
		return _failure("QSDK_R10F_SOLVER_DISPLACEMENT_SOURCE_INVALID")
	var observation_base: Dictionary = observation_base_value
	var engine_identity: Dictionary = observation_base.get("engine_step_identity", {})
	if int(engine_identity.get("semantic_step", -1)) != expected_global_semantic_step:
		return _failure("QSDK_R10F_GLOBAL_OBSERVATION_BASE_STEP_INVALID")
	return {
		"schema_version": PROJECTION_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"global_semantic_step": expected_global_semantic_step,
		"rotation_aware_energy_source_receipt": energy.duplicate(true),
		"rotation_aware_energy_source_receipt_sha256": energy_sha,
		"rotation_aware_source_component_receipts": components.duplicate(true),
		"rotation_aware_source_component_receipts_sha256": components_sha,
		"observation_base": observation_base.duplicate(true),
		"observation_base_sha256": _sha256_v1(sdk, observation_base),
		"position_constraint_mass_weighted_displacement_kg_m": displacement,
		"retained_r162_source_extracted_without_remeasurement": true,
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


## Pure local initialization from one already-completed global step E.
static func initialize_epoch_projection_v1(
	sdk: Object,
	completed_boundary: Dictionary,
	rotation_aware_energy_source_receipt: Dictionary,
	rotation_aware_source_component_receipts: Dictionary,
	global_discrete_staging_accumulator: Dictionary,
	interaction_receipt: Dictionary,
) -> Dictionary:
	if (
		sdk == null
		or not QualifiedTransport.boundary_valid_v1(
			sdk, completed_boundary, QualifiedTransport.COMPLETED_STEP_SOURCE_KIND
		)
		or not EnergyInitializer.interaction_receipt_valid_v1(sdk, interaction_receipt)
	):
		return _failure("QSDK_R10F_NATIVE_EPOCH_INITIALIZATION_INPUT_INVALID")
	var global_step := int(completed_boundary.get("boundary_sequence", -1))
	if (
		global_step <= 0
		or int(rotation_aware_energy_source_receipt.get("semantic_step", -1)) != global_step
		or int(interaction_receipt.get("completed_effect_global_step", -1)) != global_step
	):
		return _failure("QSDK_R10F_NATIVE_EPOCH_INITIALIZATION_SEQUENCE_INVALID")
	var transport_initialization := (
		EpochTransport
		. initialize_epoch_transport_v1(
			sdk,
			completed_boundary,
			String(interaction_receipt["payload_sha256"]),
		)
	)
	if not bool(transport_initialization.get("ok", false)):
		return transport_initialization
	var energy_initialization := (
		EnergyInitializer
		. initialize_energy_epoch_v1(
			sdk,
			transport_initialization["state"],
			rotation_aware_energy_source_receipt,
			rotation_aware_source_component_receipts,
			global_discrete_staging_accumulator,
			interaction_receipt,
		)
	)
	if not bool(energy_initialization.get("ok", false)):
		return energy_initialization
	var initializer: Dictionary = energy_initialization["initializer"]
	var accumulator := EpochStagingRoute.initial_accumulator_v1(initializer)
	if not EpochStagingRoute.accumulator_valid_v1(accumulator):
		return _failure("QSDK_R10F_NATIVE_EPOCH_INITIAL_ACCUMULATOR_INVALID")
	return {
		"schema_version": INITIALIZATION_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"epoch_start_global_step": global_step,
		"epoch_local_step": 0,
		"epoch_transport_initialization": transport_initialization,
		"energy_initialization": energy_initialization,
		"epoch_transport_state": (transport_initialization["state"] as Dictionary).duplicate(true),
		"energy_initializer": initializer.duplicate(true),
		"epoch_staging_accumulator": accumulator.duplicate(true),
		"global_sequence_rewrite_permitted": false,
		"kick_work_included_in_recovery_epoch_ledger": false,
		"force_aware_recovery_used": false,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Pure local successor projection for G = E + L. No model dictionary is
## mutated here; the physical entry point installs the returned state only
## after this function completes successfully.
static func advance_epoch_projection_v1(
	sdk: Object,
	epoch_transport_state: Dictionary,
	energy_initializer: Dictionary,
	epoch_staging_accumulator: Dictionary,
	completed_boundary: Dictionary,
	global_projection: Dictionary,
) -> Dictionary:
	if (
		sdk == null
		or not EpochTransport.state_valid_v1(sdk, epoch_transport_state)
		or not EnergyInitializer.initializer_valid_v1(sdk, energy_initializer)
		or not EpochStagingRoute.accumulator_valid_v1(epoch_staging_accumulator)
		or not QualifiedTransport.boundary_valid_v1(
			sdk, completed_boundary, QualifiedTransport.COMPLETED_STEP_SOURCE_KIND
		)
		or String(global_projection.get("schema_version", "")) != PROJECTION_SCHEMA
		or not bool(global_projection.get("ok", false))
	):
		return _failure("QSDK_R10F_NATIVE_EPOCH_ADVANCE_INPUT_INVALID")
	var global_step := int(completed_boundary.get("boundary_sequence", -1))
	if int(global_projection.get("global_semantic_step", -1)) != global_step:
		return _failure("QSDK_R10F_NATIVE_EPOCH_ADVANCE_GLOBAL_STEP_INVALID")
	var transport_advance := EpochTransport.advance_epoch_transport_v1(
		sdk, epoch_transport_state, completed_boundary
	)
	if not bool(transport_advance.get("ok", false)):
		return transport_advance
	var pair: Dictionary = transport_advance["pair"]
	var observer_binding := (
		EpochStagingRoute
		. measure_epoch_step_v1(
			sdk,
			pair,
			global_projection["position_constraint_mass_weighted_displacement_kg_m"],
		)
	)
	if not bool(observer_binding.get("ok", false)):
		return observer_binding
	var mapped := (
		EpochStagingRoute
		. map_epoch_step_v1(
			sdk,
			global_projection["rotation_aware_energy_source_receipt"],
			global_projection["rotation_aware_source_component_receipts"],
			observer_binding["observer_receipt"],
			epoch_staging_accumulator,
			energy_initializer,
		)
	)
	if not bool(mapped.get("ok", false)):
		return mapped
	var bound := EpochStagingRoute.compose_observations_v1(
		sdk, global_projection["observation_base"], mapped
	)
	if not bool(bound.get("ok", false)):
		return bound
	return {
		"schema_version": ADVANCE_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"epoch_start_global_step": int(pair["epoch_start_global_step"]),
		"global_semantic_step": global_step,
		"epoch_local_step": int(pair["epoch_local_step"]),
		"epoch_transport_advance": transport_advance,
		"epoch_transport_state_after":
		(transport_advance["state_after"] as Dictionary).duplicate(true),
		"observer_binding": observer_binding,
		"mapped_epoch_step": mapped,
		"epoch_staging_accumulator_after":
		(mapped["accumulator_after"] as Dictionary).duplicate(true),
		"bound_epoch_observations": bound,
		"global_sequence_rewrite_permitted": false,
		"global_counters_mutated_by_local_projection": false,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _model_epoch_state_valid_v1(sdk: Object, model: Dictionary) -> bool:
	var transport_value: Variant = model.get(MODEL_EPOCH_TRANSPORT_STATE_KEY)
	var initializer_value: Variant = model.get(MODEL_EPOCH_INITIALIZER_KEY)
	var accumulator_value: Variant = model.get(MODEL_EPOCH_ACCUMULATOR_KEY)
	var interaction_value: Variant = model.get(MODEL_EPOCH_INTERACTION_KEY)
	if (
		not (transport_value is Dictionary)
		or not (initializer_value is Dictionary)
		or not (accumulator_value is Dictionary)
		or not (interaction_value is Dictionary)
	):
		return false
	return (
		EpochTransport.state_valid_v1(sdk, transport_value)
		and EnergyInitializer.initializer_valid_v1(sdk, initializer_value)
		and EpochStagingRoute.accumulator_valid_v1(accumulator_value)
		and EnergyInitializer.interaction_receipt_valid_v1(sdk, interaction_value)
		and (
			String((transport_value as Dictionary).get("kick_interaction_receipt_sha256", ""))
			== String((interaction_value as Dictionary).get("payload_sha256", ""))
		)
		and (
			String((initializer_value as Dictionary).get("kick_interaction_receipt_sha256", ""))
			== String((interaction_value as Dictionary).get("payload_sha256", ""))
		)
	)


static func _vector3_from_json_v1(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		var mapping: Dictionary = value
		if mapping.has("x") and mapping.has("y") and mapping.has("z"):
			return Vector3(
				float(mapping.get("x", NAN)),
				float(mapping.get("y", NAN)),
				float(mapping.get("z", NAN)),
			)
	if value is Array and (value as Array).size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3(NAN, NAN, NAN)


static func _has_outcome_derived_top_level_v1(value: Dictionary) -> bool:
	for key in OUTCOME_DERIVED_KEYS:
		if value.has(key):
			return true
	return false


static func _sha256_v1(sdk: Object, value: Variant) -> String:
	if sdk == null:
		return ""
	var digest := String(RecoveryRuntimeScript.canonicalize(sdk, value).get("sha256", ""))
	return digest if _digest_valid_v1(digest) else ""


static func _digest_valid_v1(value: String) -> bool:
	return value.begins_with("sha256:") and value.length() == 71


static func _post_collection_failure(
	code: String,
	detail: Dictionary,
	global_commit_completed: bool,
) -> Dictionary:
	return {
		"schema_version": FAILURE_SCHEMA,
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"global_commit_completed": global_commit_completed,
		"terminal_failure_required": true,
		"cross_ledger_atomic_rollback_claimed": false,
		"model_construction_count": int(detail.get("model_construction_count", 0)),
		"world_attempt_count": int(detail.get("world_attempt_count", 0)),
		"world_build_count": int(detail.get("world_build_count", 0)),
		"solver_step_count": int(detail.get("solver_step_count", 0)),
		"physics_state_modified":
		bool(global_commit_completed or detail.get("physics_state_modified", false)),
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": FAILURE_SCHEMA,
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"global_commit_completed": false,
		"terminal_failure_required": false,
		"cross_ledger_atomic_rollback_claimed": false,
		"model_construction_count": 0,
		"native_readback_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
