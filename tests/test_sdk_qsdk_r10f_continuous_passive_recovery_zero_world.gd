extends SceneTree
# gdlint: disable=max-line-length
# gdlint: disable=max-file-lines

## QSDK-R10F implementation gate. Every value below is synthetic. The gate
## opens one portable core controller session and closes it explicitly, but it
## creates only detached declaration nodes: eight command-surface hinges for
## the bootstrap composition plus the recovery producer's exact nine-body,
## eight-hinge source shape for the compact-geometry consumer. It inserts no
## node into a scene tree and creates no physics world, native sample, impulse,
## body write, or solver step.

const EpochTransport := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_boundary_transport_v1.gd"
)
const EnergyInitializer := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_energy_initializer_v1.gd"
)
const EpochStagingRoute := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_discrete_staging_route_v1.gd"
)
const NativeEpochRoute := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_native_measurement_route_v1.gd"
)
const LocomotionFacade := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd"
)
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MaterialProfiles := preload("res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd")
const Orchestrator := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1.gd"
)
const PreconditionPairBarrier := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_precondition_pair_barrier_v1.gd"
)
const ImpulsePairReceipt := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_native_impulse_pair_receipt_v1.gd"
)
const WalkingEvaluator := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v1.gd"
)
const PhysicalWorker := preload(
	"res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
)
const QualifiedTransport := preload(
	"res://sdk/adapters/godot/gdscript/recovery_contiguous_boundary_transport_v1.gd"
)
const QualifiedStagingRoute := preload(
	"res://sdk/adapters/godot/gdscript/recovery_discrete_staging_route_v1.gd"
)
const RecoveryRoute := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const RecoveryWorld := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const R148Worker := preload(
	"res://tests/test_sdk_qsdk_r24d148_godot_discrete_staging_observer_zero_world.gd"
)
const R162Worker := preload(
	"res://tests/test_sdk_qsdk_r24d162_godot_rotation_aware_recovery_ledger_zero_world.gd"
)
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const L15CollectionContext := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_context_v1.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const GATE_ID := "QSDK-R10F"
const MARKER := "QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_ZERO_WORLD "
const ATTEMPT_ID := "r10f-zero-world-attempt"
const MODEL_INSTANCE_ID := "r10f-one-synthetic-s169-population"
const BASELINE_MODEL_INSTANCE_ID := "r10f-second-synthetic-s169-population"
const EPOCH_START_GLOBAL_STEP := 508
const SOLVER_STEP_S := 1.0 / 120.0
const L15_CONTEXT_OPTION := "--r10f-l15-prepared-context"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var l15_context := arguments == PackedStringArray([L15_CONTEXT_OPTION])
	if not arguments.is_empty() and not l15_context:
		print(MARKER, JsonTransportScript.stringify(_failure("QSDK_R10F_ZERO_WORLD_ARGUMENTS")))
		quit(1)
		return
	var result := _evaluate_v1(l15_context)
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate_v1(require_l15_context: bool = false) -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R10F_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R10F_SDK_INSTANTIATION_FAILED")

	var configuration := LocomotionFacade.configuration_receipt_v1(sdk)
	var portable_preflight := LocomotionFacade.portable_session_preflight_v1(sdk, 137)
	if not bool(configuration.get("ok", false)) or not bool(portable_preflight.get("ok", false)):
		return _failure(
			"QSDK_R10F_LOCOMOTION_FACADE_PREFLIGHT_FAILED",
			{"configuration": configuration, "portable_preflight": portable_preflight},
		)
	var context := RecoveryRoute.prepare_complete_energy_context_v18(
		sdk, RecoveryRoute.RECOVERY_CONTROLLER_V6_ID
	)
	if (
		not bool(context.get("ok", false))
		or not RecoveryRoute.contiguous_boundary_recovery_behavior_context_binding_exact_v1(
			sdk, context
		)
	):
		return _failure("QSDK_R10F_RECOVERY_CONTEXT_INVALID", context)

	# Retain this gate's actual prepared context before its recovery observations
	# and recovery-stage calls. Default legacy output has no L15 capture field.
	var l15_capture := {}
	if require_l15_context:
		var prepared := L15CollectionContext.capture_prepared_v1(sdk, context)
		if prepared.get("ok") != true:
			return _failure("QSDK_R10F_L15_PREPARED_CONTEXT_INVALID", prepared)
		l15_capture = L15CollectionContext.snapshot_v1(prepared)

	var impulse_pair_source := _impulse_pair_source_fixture_v1()
	var impulse_pair_build := ImpulsePairReceipt.build_pair_receipt_v1(sdk, impulse_pair_source)
	if not bool(impulse_pair_build.get("ok", false)):
		return _failure("QSDK_R10F_IMPULSE_PAIR_BUILD_FAILED", impulse_pair_build)
	var impulse_pair_receipt: Dictionary = impulse_pair_build["pair_receipt"]
	var active_interaction_build := (
		EnergyInitializer
		. build_interaction_receipt_v1(
			sdk,
			ATTEMPT_ID,
			EnergyInitializer.ACTIVE_ARM_ID,
			MODEL_INSTANCE_ID,
			EPOCH_START_GLOBAL_STEP,
			EPOCH_START_GLOBAL_STEP,
			float(impulse_pair_build["active_native_effect_velocity_delta_m_s"]),
			String(impulse_pair_build["pair_receipt_sha256"]),
		)
	)
	var baseline_interaction_build := (
		EnergyInitializer
		. build_interaction_receipt_v1(
			sdk,
			ATTEMPT_ID,
			EnergyInitializer.BASELINE_ARM_ID,
			BASELINE_MODEL_INSTANCE_ID,
			EPOCH_START_GLOBAL_STEP,
			EPOCH_START_GLOBAL_STEP,
			float(impulse_pair_build["baseline_natural_velocity_delta_m_s"]),
			String(impulse_pair_build["pair_receipt_sha256"]),
		)
	)
	if (
		not bool(active_interaction_build.get("ok", false))
		or not bool(baseline_interaction_build.get("ok", false))
	):
		return _failure(
			"QSDK_R10F_INTERACTION_RECEIPT_BUILD_FAILED",
			{"active": active_interaction_build, "baseline": baseline_interaction_build},
		)
	var active_interaction: Dictionary = active_interaction_build["interaction_receipt"]
	var baseline_interaction: Dictionary = baseline_interaction_build["interaction_receipt"]

	var boundary_e_build := _completed_boundary_v1(
		sdk,
		EnergyInitializer.ACTIVE_ARM_ID,
		EPOCH_START_GLOBAL_STEP,
		"r10f-completed-interaction-effect-508",
	)
	var boundary_e1_build := _completed_boundary_v1(
		sdk,
		EnergyInitializer.ACTIVE_ARM_ID,
		EPOCH_START_GLOBAL_STEP + 1,
		"r10f-completed-recovery-509",
	)
	var boundary_e2_build := _completed_boundary_v1(
		sdk,
		EnergyInitializer.ACTIVE_ARM_ID,
		EPOCH_START_GLOBAL_STEP + 2,
		"r10f-completed-recovery-510",
	)
	if (
		not bool(boundary_e_build.get("ok", false))
		or not bool(boundary_e1_build.get("ok", false))
		or not bool(boundary_e2_build.get("ok", false))
	):
		return _failure("QSDK_R10F_BOUNDARY_FIXTURE_BUILD_FAILED")
	var boundary_e: Dictionary = boundary_e_build["boundary"]
	var boundary_e1: Dictionary = boundary_e1_build["boundary"]
	var boundary_e2: Dictionary = boundary_e2_build["boundary"]

	var transport_initialization := EpochTransport.initialize_epoch_transport_v1(
		sdk, boundary_e, String(active_interaction["payload_sha256"])
	)
	if not bool(transport_initialization.get("ok", false)):
		return _failure("QSDK_R10F_EPOCH_TRANSPORT_INITIALIZATION_FAILED", transport_initialization)
	var state_e: Dictionary = transport_initialization["state"]
	var advance_e1 := EpochTransport.advance_epoch_transport_v1(sdk, state_e, boundary_e1)
	if not bool(advance_e1.get("ok", false)):
		return _failure("QSDK_R10F_EPOCH_TRANSPORT_FIRST_ADVANCE_FAILED", advance_e1)
	var state_e1: Dictionary = advance_e1["state_after"]
	var pair_e1: Dictionary = advance_e1["pair"]
	var advance_e2 := EpochTransport.advance_epoch_transport_v1(sdk, state_e1, boundary_e2)
	if not bool(advance_e2.get("ok", false)):
		return _failure("QSDK_R10F_EPOCH_TRANSPORT_SECOND_ADVANCE_FAILED", advance_e2)

	var observer_e := _observer_for_global_step_v1(EPOCH_START_GLOBAL_STEP)
	var raw_sources_e := _rotation_sources_for_step_v1(
		sdk, context, observer_e, EPOCH_START_GLOBAL_STEP
	)
	if not bool(observer_e.get("ok", false)) or not bool(raw_sources_e.get("ok", false)):
		return _failure(
			"QSDK_R10F_EPOCH_INITIAL_SOURCE_FIXTURE_FAILED",
			{"observer": observer_e, "sources": raw_sources_e},
		)
	var global_accumulator_e := _global_staging_accumulator_v1(EPOCH_START_GLOBAL_STEP)
	var energy_initialization := (
		EnergyInitializer
		. initialize_energy_epoch_v1(
			sdk,
			state_e,
			raw_sources_e["energy_source_receipt"],
			raw_sources_e["source_component_receipts"],
			global_accumulator_e,
			active_interaction,
		)
	)
	if not bool(energy_initialization.get("ok", false)):
		return _failure("QSDK_R10F_EPOCH_ENERGY_INITIALIZATION_FAILED", energy_initialization)
	var initializer: Dictionary = energy_initialization["initializer"]
	var epoch_accumulator := EpochStagingRoute.initial_accumulator_v1(initializer)
	if not EpochStagingRoute.accumulator_valid_v1(epoch_accumulator):
		return _failure("QSDK_R10F_EPOCH_LOCAL_ACCUMULATOR_INVALID", epoch_accumulator)

	var observer_binding_e1 := EpochStagingRoute.measure_epoch_step_v1(sdk, pair_e1, Vector3.ZERO)
	if not bool(observer_binding_e1.get("ok", false)):
		return _failure("QSDK_R10F_EPOCH_OBSERVER_BINDING_FAILED", observer_binding_e1)
	var observer_e1: Dictionary = observer_binding_e1["observer_receipt"]
	var raw_sources_e1 := _rotation_sources_for_step_v1(
		sdk, context, observer_e1, EPOCH_START_GLOBAL_STEP + 1
	)
	if not bool(raw_sources_e1.get("ok", false)):
		return _failure("QSDK_R10F_EPOCH_STEP_SOURCE_FIXTURE_FAILED", raw_sources_e1)
	_rebase_fixture_cumulatives_after_initializer_v1(
		raw_sources_e1["energy_source_receipt"], initializer
	)
	if not (
		EnergyInitializer
		. rotation_aware_sources_valid_v1(
			sdk,
			raw_sources_e1["energy_source_receipt"],
			raw_sources_e1["source_component_receipts"],
		)
	):
		return _failure("QSDK_R10F_REBASED_RAW_SOURCE_INVALID", raw_sources_e1)
	var mapped_e1 := (
		EpochStagingRoute
		. map_epoch_step_v1(
			sdk,
			raw_sources_e1["energy_source_receipt"],
			raw_sources_e1["source_component_receipts"],
			observer_e1,
			epoch_accumulator,
			initializer,
		)
	)
	if not bool(mapped_e1.get("ok", false)):
		return _failure("QSDK_R10F_EPOCH_STEP_MAPPING_FAILED", mapped_e1)
	var observation_base_e1 := _observation_base_for_step_v1(
		sdk, context, EPOCH_START_GLOBAL_STEP + 1
	)
	if observation_base_e1.is_empty():
		return _failure("QSDK_R10F_OBSERVATION_BASE_FIXTURE_FAILED")
	var bound_e1 := EpochStagingRoute.compose_observations_v1(sdk, observation_base_e1, mapped_e1)
	if not bool(bound_e1.get("ok", false)):
		return _failure("QSDK_R10F_EPOCH_OBSERVATION_COMPOSITION_FAILED", bound_e1)
	var portable_route := RecoveryRoute.collect_and_plan_v1(
		sdk, context, bound_e1, "establish_distal_support", 0
	)
	if not bool(portable_route.get("ok", false)):
		return _failure("QSDK_R10F_NONZERO_PORTABLE_ROUTE_FAILED", portable_route)

	var walking_prefix_fixture := _walking_ledger_production_fixture_v2(
		sdk,
		EPOCH_START_GLOBAL_STEP + 1,
		"walking_prefix",
		"walking_prefix",
		"fresh_selected_policy_walking_prefix",
		"r10f-l13-zero-world-prefix",
	)
	var matched_continuation_fixture := _walking_ledger_production_fixture_v2(
		sdk,
		EPOCH_START_GLOBAL_STEP + 2,
		"walking_resume",
		"matched_continuation",
		"matched_no_kick_equal_horizon_continuation",
		"r10f-l13-zero-world-matched-continuation",
	)
	var walking_resume_fixture := _walking_ledger_production_fixture_v2(
		sdk,
		EPOCH_START_GLOBAL_STEP + 3,
		"walking_resume",
		"walking_resume",
		"fresh_post_recovery_walking_resume",
		"r10f-l13-zero-world-resume",
	)
	if (
		not bool(walking_prefix_fixture.get("ok", false))
		or not bool(matched_continuation_fixture.get("ok", false))
		or not bool(walking_resume_fixture.get("ok", false))
	):
		return _failure(
			"QSDK_R10F_L13_PRODUCTION_WALKING_LEDGER_FIXTURE_FAILED",
			{
				"walking_prefix": walking_prefix_fixture,
				"matched_continuation": matched_continuation_fixture,
				"walking_resume": walking_resume_fixture,
			},
		)
	var walking_intent: Dictionary = walking_prefix_fixture["ledger_application_intent"]
	# Retain the immutable L12-shaped dictionary only for predecessor mutation
	# controls; it is no longer the positive ledger-acceptance fixture.
	var walking_fixture := _walking_ledger_fixture_v1(sdk, EPOCH_START_GLOBAL_STEP + 1)
	var disabled_motor_readback := _motor_population_fixture_v1(EPOCH_START_GLOBAL_STEP, false, 0.0)
	var no_actuation_owner_source := {
		"schema_version": "sporespore_qsdk_r10f_zero_world_no_actuation_owner_source_v1",
		"ok": true,
		"controller_owner": "none",
		"global_semantic_step": EPOCH_START_GLOBAL_STEP,
		"source_measurement": true,
	}
	var no_actuation_intent := (
		LocomotionFacade
		. no_actuation_ledger_application_intent_v1(
			sdk,
			EPOCH_START_GLOBAL_STEP,
			"interaction_effect",
			"none",
			null,
			false,
			no_actuation_owner_source,
			disabled_motor_readback,
			active_interaction,
		)
	)
	if not bool(walking_intent.get("ok", false)) or not bool(no_actuation_intent.get("ok", false)):
		return _failure(
			"QSDK_R10F_LEDGER_APPLICATION_BRIDGE_FAILED",
			{"walking": walking_intent, "no_actuation": no_actuation_intent},
		)

	var native_observer_e1 := _observer_for_global_step_v1(
		EPOCH_START_GLOBAL_STEP + 1, Vector3(0.0, 0.125, 0.0)
	)
	var native_raw_sources_e1 := _rotation_sources_for_step_v1(
		sdk, context, native_observer_e1, EPOCH_START_GLOBAL_STEP + 1
	)
	if not bool(native_raw_sources_e1.get("ok", false)):
		return _failure("QSDK_R10F_NATIVE_ROUTE_SOURCE_FIXTURE_FAILED", native_raw_sources_e1)
	_rebase_fixture_cumulatives_after_initializer_v1(
		native_raw_sources_e1["energy_source_receipt"], initializer
	)
	var committed_global_fixture := _committed_global_result_fixture_v1(
		sdk,
		native_raw_sources_e1,
		observation_base_e1,
		EPOCH_START_GLOBAL_STEP + 1,
	)
	var committed_projection := NativeEpochRoute.project_committed_global_result_v1(
		sdk, committed_global_fixture, EPOCH_START_GLOBAL_STEP + 1
	)
	var native_epoch_initialization := (
		NativeEpochRoute
		. initialize_epoch_projection_v1(
			sdk,
			boundary_e,
			raw_sources_e["energy_source_receipt"],
			raw_sources_e["source_component_receipts"],
			global_accumulator_e,
			active_interaction,
		)
	)
	var native_epoch_advance := (
		NativeEpochRoute
		. advance_epoch_projection_v1(
			sdk,
			state_e,
			initializer,
			epoch_accumulator,
			boundary_e1,
			committed_projection,
		)
	)
	if (
		not bool(committed_projection.get("ok", false))
		or not bool(native_epoch_initialization.get("ok", false))
		or not bool(native_epoch_advance.get("ok", false))
	):
		return _failure(
			"QSDK_R10F_NATIVE_EPOCH_ROUTE_CANARY_FAILED",
			{
				"projection": committed_projection,
				"initialization": native_epoch_initialization,
				"advance": native_epoch_advance,
			},
		)

	var recovery_memory := RecoveryRoute.initialize_behavior_arm_v1(
		sdk, context, "candidate_command"
	)
	var production_advance := (
		BehaviorWorker
		. production_advance_dispatch_v1(
			sdk,
			context,
			native_epoch_advance["bound_epoch_observations"] as Dictionary,
			recovery_memory.get("memory", {}),
			"candidate_command",
			"confirm_prone",
			RecoveryRoute.RECOVERY_CONTROLLER_V6_ID,
			RecoveryRoute.R148_COMPLETE_ENERGY_ROUTE_ID,
		)
	)
	if (
		not bool(recovery_memory.get("ok", false))
		or not bool(production_advance.get("ok", false))
		or not (
			BehaviorWorker
			. production_advance_receipt_valid_v1(
				production_advance,
				RecoveryRoute.RECOVERY_CONTROLLER_V6_ID,
				sdk,
				RecoveryRoute.R148_COMPLETE_ENERGY_ROUTE_ID,
			)
		)
	):
		return _failure(
			"QSDK_R10F_OFFSET_BOUND_PRODUCTION_ADVANCE_FAILED",
			{"memory": recovery_memory, "advance": production_advance},
		)

	var lockstep_plan := _lockstep_pair_plan_v1(sdk)
	if not bool(lockstep_plan.get("ok", false)):
		return _failure("QSDK_R10F_LOCKSTEP_PAIR_PLAN_FAILED", lockstep_plan)
	var precondition_pair_barrier_contract := PreconditionPairBarrier.zero_world_contract_v1(sdk)
	if not bool(precondition_pair_barrier_contract.get("ok", false)):
		return _failure(
			"QSDK_R10F_L6_PRECONDITION_PAIR_BARRIER_CONTRACT_FAILED",
			precondition_pair_barrier_contract,
		)
	var physical_worker_contract := PhysicalWorker.zero_world_contract_v12(sdk, context)
	if not bool(physical_worker_contract.get("ok", false)):
		return _failure("QSDK_R10F_PHYSICAL_WORKER_CONTRACT_FAILED", physical_worker_contract)
	var walking_evaluator_controls := _walking_evaluator_controls_v1(sdk)
	if not bool(walking_evaluator_controls.get("ok", false)):
		return _failure("QSDK_R10F_WALKING_EVALUATOR_CONTROLS_FAILED", walking_evaluator_controls)

	var transport_controls := _transport_mutation_controls_v1(sdk, state_e, state_e1, pair_e1)
	var energy_controls := _energy_mutation_controls_v1(
		sdk,
		state_e,
		raw_sources_e,
		global_accumulator_e,
		active_interaction,
		baseline_interaction,
	)
	var staging_controls := _staging_mutation_controls_v1(
		sdk,
		raw_sources_e1,
		observer_e1,
		epoch_accumulator,
		initializer,
		bound_e1,
	)
	var active_orchestration := _orchestrator_path_v1(sdk, EnergyInitializer.ACTIVE_ARM_ID)
	var baseline_orchestration := _orchestrator_path_v1(sdk, EnergyInitializer.BASELINE_ARM_ID)
	var valid_negative_orchestration := _orchestrator_behavioral_failure_path_v1(sdk)
	var orchestrator_controls := _orchestrator_mutation_controls_v1(sdk)
	var impulse_pair_controls := _impulse_pair_mutation_controls_v1(sdk, impulse_pair_source)
	var ledger_bridge_controls := _ledger_bridge_mutation_controls_v1(
		sdk,
		walking_fixture,
		no_actuation_owner_source,
		disabled_motor_readback,
		active_interaction,
		committed_global_fixture,
	)
	var walking_ledger_l13_controls := _walking_ledger_l13_controls_v1(
		sdk,
		walking_prefix_fixture,
		matched_continuation_fixture,
		walking_resume_fixture,
		physical_worker_contract,
	)
	if (
		not bool(transport_controls.get("ok", false))
		or not bool(energy_controls.get("ok", false))
		or not bool(staging_controls.get("ok", false))
		or not bool(active_orchestration.get("ok", false))
		or not bool(baseline_orchestration.get("ok", false))
		or not bool(valid_negative_orchestration.get("ok", false))
		or not bool(orchestrator_controls.get("ok", false))
		or not bool(impulse_pair_controls.get("ok", false))
		or not bool(ledger_bridge_controls.get("ok", false))
		or not bool(walking_evaluator_controls.get("ok", false))
		or not bool(walking_ledger_l13_controls.get("ok", false))
	):
		return _failure(
			"QSDK_R10F_NEGATIVE_OR_ORCHESTRATION_CONTROL_FAILED",
			{
				"transport": transport_controls,
				"energy": energy_controls,
				"staging": staging_controls,
				"active": active_orchestration,
				"baseline": baseline_orchestration,
				"valid_negative": valid_negative_orchestration,
				"orchestrator": orchestrator_controls,
				"impulse_pair": impulse_pair_controls,
				"ledger_bridge": ledger_bridge_controls,
				"walking_evaluator": walking_evaluator_controls,
				"walking_ledger_l13": walking_ledger_l13_controls,
			},
		)

	var mapped_source: Dictionary = mapped_e1["energy_source_receipt"]
	var active_terminal: Dictionary = active_orchestration["terminal_state"]
	var baseline_terminal: Dictionary = baseline_orchestration["terminal_state"]
	var positive_checks := {
		"l13_walking_ledger_transport_projection_and_failure_retention_controls_pass":
		(
			int(walking_ledger_l13_controls.get("positive_control_count", -1)) == 15
			and int(walking_ledger_l13_controls.get("mutation_rejection_count", -1)) == 16
			and int(walking_ledger_l13_controls.get("world_build_count", -1)) == 0
			and int(walking_ledger_l13_controls.get("solver_step_count", -1)) == 0
		),
		"facade_binds_one_recovery_native_population":
		(
			int(configuration.get("same_body_node_identity_count", -1)) == 17
			and (
				configuration.get("ordered_same_body_node_ids")
				== LocomotionFacade.SAME_BODY_NODE_IDENTITY
			)
			and bool(configuration.get("physical_body_population_created_once", false))
			and not bool(configuration.get("walking_fixture_label_only_wrap_permitted", true))
		),
		"portable_session_preflight_created_and_destroyed_one_core_session":
		(
			int(portable_preflight.get("native_controller_session_create_count", -1)) == 1
			and int(portable_preflight.get("native_controller_session_destroy_count", -1)) == 1
			and int(portable_preflight.get("world_build_count", -1)) == 0
		),
		"offset_transport_preserves_global_and_derives_local":
		(
			int(state_e.get("epoch_start_global_step", -1)) == EPOCH_START_GLOBAL_STEP
			and int(pair_e1.get("global_semantic_step", -1)) == EPOCH_START_GLOBAL_STEP + 1
			and int(pair_e1.get("epoch_local_step", -1)) == 1
			and int((advance_e2["pair"] as Dictionary).get("epoch_local_step", -1)) == 2
			and bool(pair_e1.get("global_callback_sequence_preserved", false))
			and not bool(pair_e1.get("global_sequence_rewrite_permitted", true))
		),
		"energy_initializer_uses_live_post_interaction_measurement":
		(
			(
				float(initializer.get("initial_mechanical_energy_j", NAN))
				== float(
					(raw_sources_e["energy_source_receipt"] as Dictionary)["current_mechanical_energy_j"]
				)
			)
			and not bool(initializer.get("canonical_world_start_pose_reconstruction_used", true))
			and not bool(initializer.get("kick_work_included_in_recovery_epoch_ledger", true))
			and int(initializer.get("recovery_local_discrete_staging_event_count", -1)) == 0
		),
		"variable_step_kick_receipt_reuses_r10e_scalar_math_and_subtracts_baseline":
		(
			ImpulsePairReceipt.pair_receipt_valid_v1(sdk, impulse_pair_receipt)
			and (
				int(impulse_pair_receipt.get("completed_effect_global_step", -1))
				== EPOCH_START_GLOBAL_STEP
			)
			and not bool(impulse_pair_receipt.get("r10e_fixed_step_900_copied_into_r10f", true))
			and bool(impulse_pair_receipt.get("r10e_scalar_tolerance_math_reused", false))
			and bool(impulse_pair_receipt.get("matched_no_kick_delta_subtracted", false))
			and (
				String(active_interaction.get("interaction_source_receipt_sha256", ""))
				== String(impulse_pair_receipt.get("payload_sha256", ""))
			)
			and (
				String(baseline_interaction.get("interaction_source_receipt_sha256", ""))
				== String(impulse_pair_receipt.get("payload_sha256", ""))
			)
		),
		"recovery_local_energy_counters_rebased_without_mutating_global":
		(
			int(mapped_source.get("semantic_step", -1)) == EPOCH_START_GLOBAL_STEP + 1
			and int(mapped_source.get("epoch_local_step", -1)) == 1
			and int(mapped_source.get("adapter_side_discrete_staging_event_count", -1)) == 1
			and is_equal_approx(
				float(mapped_source.get("cumulative_applied_actuator_work_j", NAN)), 0.25
			)
			and not bool(mapped_source.get("global_counters_mutated", true))
		),
		"portable_core_accepts_nonzero_global_semantic_step":
		(
			(
				int((bound_e1["observation_v2"] as Dictionary).get("semantic_step", -1))
				== EPOCH_START_GLOBAL_STEP + 1
			)
			and (
				String((bound_e1["source_binding"] as Dictionary).get("source_route_id", ""))
				== EpochStagingRoute.PORTABLE_ROUTE_ID
			)
			and (
				String((bound_e1["epoch_source_binding"] as Dictionary).get("source_route_id", ""))
				== EpochStagingRoute.ROUTE_ID
			)
			and (
				String(
					(portable_route["collection_receipt"] as Dictionary).get("support_status", "")
				)
				== "supported_exact"
			)
		),
		"walking_and_no_actuation_ledger_intents_preserve_real_owners":
		(
			String(walking_intent.get("controller_owner", "")) == "walking_bw5r_b"
			and walking_intent.get("recovery_controller_id") == null
			and (
				String(walking_intent.get("walking_controller_policy_id", ""))
				== LocomotionFacade.SELECTED_POLICY_ID
			)
			and String(no_actuation_intent.get("controller_owner", "")) == "none"
			and int(no_actuation_intent.get("pre_solver_direct_body_impulse_write_count", -1)) == 0
			and (
				int(no_actuation_intent.get("external_intervention_body_impulse_write_count", -1))
				== 1
			)
			and not bool(
				no_actuation_intent.get("kick_work_included_in_recovery_epoch_ledger", true)
			)
		),
		"native_epoch_route_reuses_one_committed_global_measurement":
		(
			bool(
				committed_projection.get(
					"retained_r162_source_extracted_without_remeasurement", false
				)
			)
			and int(native_epoch_initialization.get("epoch_local_step", -1)) == 0
			and int(native_epoch_advance.get("epoch_local_step", -1)) == 1
			and (
				int(native_epoch_advance.get("global_semantic_step", -1))
				== EPOCH_START_GLOBAL_STEP + 1
			)
			and not bool(
				native_epoch_advance.get("global_counters_mutated_by_local_projection", true)
			)
		),
		"offset_bound_observation_advances_real_v6_production_dispatch":
		(
			(
				String(production_advance.get("energy_route_id", ""))
				== RecoveryRoute.R148_COMPLETE_ENERGY_ROUTE_ID
			)
			and bool(production_advance.get("development_progression_required", false))
		),
		"two_isolated_worlds_have_one_lockstep_terminal_frame":
		(
			int((lockstep_plan["plan"] as Dictionary).get("world_count", -1)) == 2
			and int((lockstep_plan["plan"] as Dictionary).get("distinct_world_3d_count", -1)) == 2
			and bool((lockstep_plan["plan"] as Dictionary).get("own_world_3d_required", false))
			and bool(
				(lockstep_plan["plan"] as Dictionary).get(
					"world_spaces_advance_on_same_global_physics_frames", false
				)
			)
			and bool(
				(lockstep_plan["plan"] as Dictionary).get(
					"active_terminal_frame_closes_both_arms", false
				)
			)
			and not bool(
				(lockstep_plan["plan"] as Dictionary).get(
					"hindsight_horizon_selection_permitted", true
				)
			)
		),
		"precondition_pair_barrier_accepts_all_frozen_timing_orders":
		(
			int(precondition_pair_barrier_contract.get("positive_sequence_control_count", -1)) == 4
			and int(precondition_pair_barrier_contract.get("mutation_rejection_count", -1)) == 9
			and (
				int(
					physical_worker_contract.get(
						"precondition_pair_application_positive_control_count", -1
					)
				)
				== 2
			)
			and (
				int(
					physical_worker_contract.get(
						"precondition_pair_application_mutation_rejection_count", -1
					)
				)
				== 3
			)
			and (
				int(
					physical_worker_contract.get(
						"precondition_pair_required_mutation_rejection_count", -1
					)
				)
				== 12
			)
			and (
				int(precondition_pair_barrier_contract.get("maximum_solver_steps_per_arm", -1))
				== 3842
			)
			and (
				int(precondition_pair_barrier_contract.get("maximum_total_solver_steps", -1))
				== 7684
			)
		),
		"precondition_terminal_dispositions_stop_on_one_arm_and_retain_both_sources":
		(
			(
				int(
					physical_worker_contract.get(
						"precondition_terminal_disposition_positive_control_count", -1
					)
				)
				== 6
			)
			and (
				int(
					physical_worker_contract.get(
						"precondition_terminal_disposition_mutation_rejection_count", -1
					)
				)
				== 16
			)
			and int(physical_worker_contract.get("maximum_total_solver_step_count", -1)) == 7684
			and int(physical_worker_contract.get("world_attempt_count", -1)) == 0
			and int(physical_worker_contract.get("solver_step_count", -1)) == 0
			and not bool(physical_worker_contract.get("physics_state_modified", true))
		),
		"integer_valued_native_recovery_step_domain_is_exact_and_source_preserving":
		(
			(
				int(
					physical_worker_contract.get(
						"integer_valued_native_step_domain_positive_control_count", -1
					)
				)
				== 6
			)
			and (
				int(
					physical_worker_contract.get(
						"integer_valued_native_step_domain_mutation_rejection_count", -1
					)
				)
				== 16
			)
			and bool(
				(
					(
						physical_worker_contract.get(
							"integer_valued_native_step_domain_positive_controls", {}
						)
						as Dictionary
					)
					. get(
						"all_existing_l7_terminal_disposition_positive_controls_still_pass", false
					)
				)
			)
			and bool(
				(
					(
						physical_worker_contract.get(
							"integer_valued_native_step_domain_negative_controls", {}
						)
						as Dictionary
					)
					. get(
						"all_existing_l7_terminal_disposition_negative_controls_still_pass", false
					)
				)
			)
		),
		"active_orchestrator_is_event_triggered_passive_and_same_body":
		(
			String(active_terminal.get("phase", "")) == Orchestrator.PHASE_COMPLETE
			and (
				String(active_terminal.get("terminal_reason", ""))
				== "kick_passive_recovery_and_walk_resume_complete"
			)
			and int(active_terminal.get("body_population_rebuild_count", -1)) == 0
			and int(active_terminal.get("body_transform_write_count", -1)) == 0
			and int(active_terminal.get("solver_reset_count", -1)) == 0
			and int(active_terminal.get("precondition_recovery_step_count", -1)) == 2
			and int(active_terminal.get("post_kick_recovery_step_count", -1)) == 2
			and bool(active_terminal.get("event_triggered_passive_recovery", false))
			and not bool(active_terminal.get("force_aware_recovery", true))
		),
		"physical_worker_is_parse_bound_and_zero_world_described":
		(
			(
				String(physical_worker_contract.get("schema_version", ""))
				== "sporespore_qsdk_r10f_worker_zero_world_contract_v12"
			)
			and (
				int(
					physical_worker_contract.get(
						"initial_bootstrap_producer_consumer_control_count", -1
					)
				)
				== 1
			)
			and (
				int(physical_worker_contract.get("initial_bootstrap_mutation_rejection_count", -1))
				== 6
			)
			and int(physical_worker_contract.get("detached_command_surface_node_count", -1)) == 8
			and (
				int(physical_worker_contract.get("joint_geometry_source_shape_control_count", -1))
				== 1
			)
			and (
				int(physical_worker_contract.get("joint_geometry_mutation_rejection_count", -1))
				== 16
			)
			and int(physical_worker_contract.get("detached_geometry_body_node_count", -1)) == 9
			and int(physical_worker_contract.get("detached_geometry_joint_node_count", -1)) == 8
			and (
				int(
					physical_worker_contract.get(
						"collection_solver_counter_consecutive_positive_count", -1
					)
				)
				== 2
			)
			and (
				int(
					physical_worker_contract.get(
						"collection_solver_counter_mutation_rejection_count", -1
					)
				)
				== 16
			)
			and (
				int(
					(
						(
							physical_worker_contract.get("collection_solver_counter_controls", {})
							as Dictionary
						)
						. get("accepted_completed_step_delta_sum", -1)
					)
				)
				== 2
			)
			and (
				int(
					(
						(
							physical_worker_contract.get("collection_solver_counter_controls", {})
							as Dictionary
						)
						. get("terminal_cumulative_solver_step_count", -1)
					)
				)
				== 2
			)
			and bool(
				(
					(
						physical_worker_contract.get("joint_geometry_source_shape_controls", {})
						as Dictionary
					)
					. get("exact_producer_shape_without_child_axis_accepted", false)
				)
			)
			and int(physical_worker_contract.get("world_attempt_count", -1)) == 0
			and int(physical_worker_contract.get("world_build_count", -1)) == 0
			and int(physical_worker_contract.get("solver_step_count", -1)) == 0
			and not bool(physical_worker_contract.get("physics_state_modified", true))
			and bool(physical_worker_contract.get("active_terminal_frame_closes_both_arms", false))
			and bool(
				physical_worker_contract.get("behavioral_failure_is_valid_complete_evidence", false)
			)
			and not bool(physical_worker_contract.get("force_aware_recovery", true))
		),
		"process_isolated_child_receipts_are_zero_world_bound_and_scope_closed":
		(
			int(physical_worker_contract.get("process_isolated_child_positive_case_count", -1)) == 8
			and (
				int(
					physical_worker_contract.get(
						"process_isolated_child_mutation_rejection_count", -1
					)
				)
				== 31
			)
			and bool(physical_worker_contract.get("one_authorized_arm_per_child_process", false))
			and bool(physical_worker_contract.get("one_native_world_per_child_process", false))
			and bool(
				physical_worker_contract.get(
					"failed_or_refused_precondition_is_valid_diagnostic_evidence", false
				)
			)
			and not bool(
				physical_worker_contract.get(
					"failed_or_refused_precondition_crosses_release_boundary", true
				)
			)
			and int(physical_worker_contract.get("maximum_solver_steps_per_child", -1)) == 3842
			and int(physical_worker_contract.get("maximum_total_solver_steps", -1)) == 7684
			and int(physical_worker_contract.get("world_attempt_count", -1)) == 0
			and int(physical_worker_contract.get("world_build_count", -1)) == 0
			and int(physical_worker_contract.get("solver_step_count", -1)) == 0
			and not bool(physical_worker_contract.get("physics_state_modified", true))
		),
		"nullable_terminal_failure_code_projection_is_source_typed_and_value_preserving":
		(
			(
				int(
					physical_worker_contract.get(
						"nullable_terminal_failure_code_positive_control_count", -1
					)
				)
				== 7
			)
			and (
				int(
					physical_worker_contract.get(
						"nullable_terminal_failure_code_mutation_rejection_count", -1
					)
				)
				== 17
			)
			and bool(
				(
					(
						physical_worker_contract.get(
							"nullable_terminal_failure_code_positive_controls", {}
						)
						as Dictionary
					)
					. get(
						"all_existing_l9_process_isolated_child_positive_controls_still_pass",
						false,
					)
				)
			)
			and bool(
				(
					(
						physical_worker_contract.get(
							"nullable_terminal_failure_code_negative_controls", {}
						)
						as Dictionary
					)
					. get(
						"all_existing_l9_process_isolated_child_negative_controls_still_pass",
						false,
					)
				)
			)
		),
		"precondition_release_owner_source_is_narrow_runtime_shaped_and_digest_bound":
		(
			(
				int(
					physical_worker_contract.get(
						"precondition_release_owner_source_positive_control_count", -1
					)
				)
				== 9
			)
			and (
				int(
					physical_worker_contract.get(
						"precondition_release_owner_source_mutation_rejection_count", -1
					)
				)
				== 23
			)
			and (
				String(
					physical_worker_contract.get(
						"precondition_release_component_schema_version", ""
					)
				)
				== "sporespore_qsdk_r10f_l11_process_isolated_precondition_release_receipt_v1"
			)
			and not bool(
				physical_worker_contract.get("broad_no_actuation_outcome_guard_changed", true)
			)
			and bool(
				(
					(
						physical_worker_contract.get(
							"precondition_release_owner_source_positive_controls", {}
						)
						as Dictionary
					)
					. get(
						"all_existing_l10_nullable_terminal_positive_controls_still_pass",
						false,
					)
				)
			)
			and bool(
				(
					(
						physical_worker_contract.get(
							"precondition_release_owner_source_negative_controls", {}
						)
						as Dictionary
					)
					. get(
						"all_existing_l10_nullable_terminal_negative_controls_still_pass",
						false,
					)
				)
			)
		),
		"walking_actuation_handoff_is_exact_r69_bound_and_precommand_zero_step":
		(
			(
				int(
					physical_worker_contract.get(
						"walking_actuation_handoff_positive_control_count", -1
					)
				)
				== 5
			)
			and (
				int(
					physical_worker_contract.get(
						"walking_actuation_handoff_mutation_rejection_count", -1
					)
				)
				== 22
			)
			and int(physical_worker_contract.get("qualified_r69_projection_count", -1)) == 8
			and not bool(
				physical_worker_contract.get("shared_adapter_motor_enable_behavior_changed", true)
			)
			and not bool(
				physical_worker_contract.get("published_actuator_cap_profile_changed", true)
			)
			and (
				int(physical_worker_contract.get("walking_handoff_extra_solver_step_count", -1))
				== 0
			)
			and bool(
				(
					(
						physical_worker_contract.get(
							"walking_actuation_handoff_positive_controls", {}
						)
						as Dictionary
					)
					. get(
						"all_existing_l11_release_owner_positive_controls_still_pass",
						false,
					)
				)
			)
			and bool(
				(
					(
						physical_worker_contract.get(
							"walking_actuation_handoff_negative_controls", {}
						)
						as Dictionary
					)
					. get(
						"all_existing_l11_release_owner_negative_controls_still_pass",
						false,
					)
				)
			)
		),
		"walking_evaluator_has_fixed_positive_and_valid_negative_canaries":
		(
			bool(walking_evaluator_controls.get("positive_behavior_passed", false))
			and bool(walking_evaluator_controls.get("valid_negative_retained", false))
			and int(walking_evaluator_controls.get("rejection_count", -1)) == 2
		),
		"controller_timeout_is_retained_as_valid_behavioral_negative":
		(
			(
				String(
					(valid_negative_orchestration["terminal_state"] as Dictionary).get("phase", "")
				)
				== Orchestrator.PHASE_FAILED
			)
			and (
				String(
					(valid_negative_orchestration["terminal_state"] as Dictionary).get(
						"terminal_reason", ""
					)
				)
				== "phase_timeout:establish_distal_support"
			)
		),
		"paired_arms_retain_equal_synthetic_horizon":
		(
			(
				int(active_terminal.get("total_completed_solver_step_count", -1))
				== int(baseline_terminal.get("total_completed_solver_step_count", -2))
			)
			and (
				int(active_terminal.get("previous_global_semantic_step", -1))
				== int(baseline_terminal.get("previous_global_semantic_step", -2))
			)
			and (
				String(baseline_terminal.get("terminal_reason", ""))
				== "matched_no_kick_equal_horizon_continuation_complete"
			)
		),
	}
	for control_id in positive_checks:
		if not bool(positive_checks[control_id]):
			return _failure(
				"QSDK_R10F_POSITIVE_CONTROL_FAILED:%s" % String(control_id),
				{"positive_checks": positive_checks},
			)
	var forced_failure_case_count := (
		int(transport_controls["rejection_count"])
		+ int(energy_controls["rejection_count"])
		+ int(staging_controls["rejection_count"])
		+ int(orchestrator_controls["rejection_count"])
		+ int(impulse_pair_controls["rejection_count"])
		+ int(ledger_bridge_controls["rejection_count"])
		+ int(walking_evaluator_controls["rejection_count"])
		+ int(walking_ledger_l13_controls["mutation_rejection_count"])
		+ int(physical_worker_contract["initial_bootstrap_mutation_rejection_count"])
		+ int(physical_worker_contract["joint_geometry_mutation_rejection_count"])
		+ int(physical_worker_contract["collection_solver_counter_mutation_rejection_count"])
		+ int(physical_worker_contract["precondition_pair_required_mutation_rejection_count"])
		+ int(
			physical_worker_contract["precondition_terminal_disposition_mutation_rejection_count"]
		)
		+ int(
			physical_worker_contract["integer_valued_native_step_domain_mutation_rejection_count"]
		)
		+ int(physical_worker_contract["process_isolated_child_mutation_rejection_count"])
		+ int(physical_worker_contract["nullable_terminal_failure_code_mutation_rejection_count"])
		+ int(
			physical_worker_contract["precondition_release_owner_source_mutation_rejection_count"]
		)
		+ int(physical_worker_contract["walking_actuation_handoff_mutation_rejection_count"])
	)
	var result := {
		"schema_version": "sporespore_qsdk_r10f_continuous_passive_recovery_zero_world_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"status":
		"passed_complete_zero_world_offset_epoch_same_body_passive_recovery_implementation",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prospective_zero_world_implementation",
			"question_class": "development",
		},
		"question_class": "development",
		"epoch_start_global_step_canary": EPOCH_START_GLOBAL_STEP,
		"first_recovery_global_step_canary": EPOCH_START_GLOBAL_STEP + 1,
		"first_recovery_local_step_canary": 1,
		"same_body_node_identity_count": LocomotionFacade.SAME_BODY_NODE_IDENTITY.size(),
		"walking_evaluator_fixed_receipt_count": WalkingEvaluator.RECEIPT_KEYS.size(),
		"initial_bootstrap_producer_consumer_control_count":
		int(physical_worker_contract["initial_bootstrap_producer_consumer_control_count"]),
		"initial_bootstrap_mutation_rejection_count":
		int(physical_worker_contract["initial_bootstrap_mutation_rejection_count"]),
		"detached_command_surface_node_count":
		int(physical_worker_contract["detached_command_surface_node_count"]),
		"joint_geometry_source_shape_control_count":
		int(physical_worker_contract["joint_geometry_source_shape_control_count"]),
		"joint_geometry_mutation_rejection_count":
		int(physical_worker_contract["joint_geometry_mutation_rejection_count"]),
		"detached_geometry_body_node_count":
		int(physical_worker_contract["detached_geometry_body_node_count"]),
		"detached_geometry_joint_node_count":
		int(physical_worker_contract["detached_geometry_joint_node_count"]),
		"collection_solver_counter_consecutive_positive_count":
		int(physical_worker_contract["collection_solver_counter_consecutive_positive_count"]),
		"collection_solver_counter_mutation_rejection_count":
		int(physical_worker_contract["collection_solver_counter_mutation_rejection_count"]),
		"precondition_pair_barrier_positive_sequence_control_count":
		int(precondition_pair_barrier_contract["positive_sequence_control_count"]),
		"precondition_pair_barrier_mutation_rejection_count":
		int(precondition_pair_barrier_contract["mutation_rejection_count"]),
		"precondition_pair_application_positive_control_count":
		int(physical_worker_contract["precondition_pair_application_positive_control_count"]),
		"precondition_pair_application_mutation_rejection_count":
		int(physical_worker_contract["precondition_pair_application_mutation_rejection_count"]),
		"precondition_pair_required_mutation_rejection_count":
		int(physical_worker_contract["precondition_pair_required_mutation_rejection_count"]),
		"precondition_terminal_disposition_positive_control_count":
		int(physical_worker_contract["precondition_terminal_disposition_positive_control_count"]),
		"precondition_terminal_disposition_mutation_rejection_count":
		int(physical_worker_contract["precondition_terminal_disposition_mutation_rejection_count"]),
		"integer_valued_native_step_domain_positive_control_count":
		int(physical_worker_contract["integer_valued_native_step_domain_positive_control_count"]),
		"integer_valued_native_step_domain_mutation_rejection_count":
		int(physical_worker_contract["integer_valued_native_step_domain_mutation_rejection_count"]),
		"process_isolated_child_positive_case_count":
		int(physical_worker_contract["process_isolated_child_positive_case_count"]),
		"process_isolated_child_mutation_rejection_count":
		int(physical_worker_contract["process_isolated_child_mutation_rejection_count"]),
		"nullable_terminal_failure_code_positive_control_count":
		int(physical_worker_contract["nullable_terminal_failure_code_positive_control_count"]),
		"nullable_terminal_failure_code_mutation_rejection_count":
		int(physical_worker_contract["nullable_terminal_failure_code_mutation_rejection_count"]),
		"precondition_release_owner_source_positive_control_count":
		int(physical_worker_contract["precondition_release_owner_source_positive_control_count"]),
		"precondition_release_owner_source_mutation_rejection_count":
		int(physical_worker_contract["precondition_release_owner_source_mutation_rejection_count"]),
		"walking_actuation_handoff_positive_control_count":
		int(physical_worker_contract["walking_actuation_handoff_positive_control_count"]),
		"walking_actuation_handoff_mutation_rejection_count":
		int(physical_worker_contract["walking_actuation_handoff_mutation_rejection_count"]),
		"walking_ledger_l13_positive_control_count":
		int(walking_ledger_l13_controls["positive_control_count"]),
		"walking_ledger_l13_mutation_rejection_count":
		int(walking_ledger_l13_controls["mutation_rejection_count"]),
		"walking_ledger_failure_retention_positive_control_count":
		int(physical_worker_contract["walking_ledger_failure_retention_positive_control_count"]),
		"walking_ledger_failure_retention_mutation_rejection_count":
		int(physical_worker_contract["walking_ledger_failure_retention_mutation_rejection_count"]),
		"production_shaped_l13_walking_fixture_count": 3,
		"detached_l13_hinge_parameter_container_count":
		(
			int(walking_prefix_fixture["detached_hinge_parameter_container_count"])
			+ int(matched_continuation_fixture["detached_hinge_parameter_container_count"])
			+ int(walking_resume_fixture["detached_hinge_parameter_container_count"])
		),
		"qualified_r69_projection_count":
		int(physical_worker_contract["qualified_r69_projection_count"]),
		"portable_nonzero_global_step_accepted": true,
		"active_terminal_global_step": int(active_terminal["previous_global_semantic_step"]),
		"baseline_terminal_global_step": int(baseline_terminal["previous_global_semantic_step"]),
		"active_terminal_local_recovery_step": int(active_terminal["recovery_epoch_step_count"]),
		"baseline_terminal_local_recovery_step":
		int(baseline_terminal["recovery_epoch_step_count"]),
		"positive_case_count": positive_checks.size(),
		"forced_failure_case_count": forced_failure_case_count,
		"historical_closure_audits_executed_count": 0,
		"bespoke_physical_canary_count": 0,
		"full_seeded_ghost_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_declared": true,
		"physical_question_opened": false,
		"physical_execution_authorized": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if require_l15_context:
		result["l15_prepared_collection_context"] = l15_capture
	return result


static func _walking_evaluator_controls_v1(sdk: Object) -> Dictionary:
	var evidence := _walking_evaluation_fixture_v1()
	var positive := WalkingEvaluator.evaluate_segment_v1(sdk, evidence)
	var valid_negative_evidence: Dictionary = evidence.duplicate(true)
	var valid_negative_rows: Array = valid_negative_evidence["rows"]
	(valid_negative_rows[18] as Dictionary)["maximum_anchor_error_m"] = 0.026
	valid_negative_evidence["rows"] = valid_negative_rows
	var valid_negative := WalkingEvaluator.evaluate_segment_v1(sdk, valid_negative_evidence)
	var threshold_override: Dictionary = evidence.duplicate(true)
	threshold_override["maximum_anchor_error_m"] = 1.0
	var threshold_override_result := WalkingEvaluator.evaluate_segment_v1(sdk, threshold_override)
	var incomplete: Dictionary = evidence.duplicate(true)
	var incomplete_rows: Array = incomplete["rows"]
	incomplete_rows.pop_back()
	incomplete["rows"] = incomplete_rows
	var incomplete_result := WalkingEvaluator.evaluate_segment_v1(sdk, incomplete)
	var controls := {
		"threshold_override_extra_input_rejected":
		_failure_exact_v1(
			threshold_override_result,
			"QSDK_R10F_WALKING_EVALUATION_INPUT_INVALID",
		),
		"incomplete_fixed_horizon_rejected":
		_failure_exact_v1(
			incomplete_result,
			"QSDK_R10F_WALKING_TRACE_LENGTH_INVALID",
		),
	}
	var control_result := _control_result_v1(controls)
	control_result["positive_behavior_passed"] = (
		bool(positive.get("ok", false))
		and bool(positive.get("evidence_valid", false))
		and bool(positive.get("outcome_complete", false))
		and bool(positive.get("behavior_passed", false))
		and int(positive.get("walking_receipt_count", -1)) == WalkingEvaluator.RECEIPT_KEYS.size()
		and int(positive.get("threshold_override_input_count", -1)) == 0
	)
	control_result["valid_negative_retained"] = (
		bool(valid_negative.get("ok", false))
		and bool(valid_negative.get("evidence_valid", false))
		and bool(valid_negative.get("outcome_complete", false))
		and not bool(valid_negative.get("behavior_passed", true))
		and valid_negative.get("false_walking_receipts", []).has("bounded_anchor_error")
		and is_equal_approx(float(valid_negative.get("maximum_anchor_error_m", NAN)), 0.026)
	)
	control_result["ok"] = (
		bool(control_result.get("ok", false))
		and bool(control_result["positive_behavior_passed"])
		and bool(control_result["valid_negative_retained"])
	)
	control_result["positive_evaluation_sha256"] = String(positive.get("payload_sha256", ""))
	control_result["valid_negative_evaluation_sha256"] = String(
		valid_negative.get("payload_sha256", "")
	)
	return control_result


static func _walking_evaluation_fixture_v1() -> Dictionary:
	var session_id := "r10f-zero-world-walking-evaluator-session"
	var arm_id := EnergyInitializer.ACTIVE_ARM_ID
	var contacts := {
		"front_left": true,
		"front_right": true,
		"rear_left": true,
		"rear_right": true,
	}
	var rows: Array = []
	for index in range(WalkingEvaluator.FIXED_SEGMENT_STEP_COUNT):
		var local_step := index + 1
		var airborne := local_step in [50, 51, 52, 200, 201, 202]
		var foot_advance := 0.0
		if local_step >= 203:
			foot_advance = 0.04
		elif local_step >= 53:
			foot_advance = 0.02
		var row_contacts := contacts.duplicate(true)
		if airborne:
			for limb_id in WalkingEvaluator.LIMB_ORDER:
				row_contacts[limb_id] = false
		var feet := {
			"front_left": [foot_advance, 0.0, -0.18],
			"front_right": [foot_advance, 0.0, 0.18],
			"rear_left": [foot_advance - 0.30, 0.0, -0.18],
			"rear_right": [foot_advance - 0.30, 0.0, 0.18],
		}
		(
			rows
			. append(
				{
					"schema_version": WalkingEvaluator.TRACE_ROW_SCHEMA,
					"arm_id": arm_id,
					"walking_session_id": session_id,
					"walking_session_local_step": local_step,
					"torso_position_world_m":
					[
						0.05 * float(local_step) / float(WalkingEvaluator.FIXED_SEGMENT_STEP_COUNT),
						0.35,
						0.0,
					],
					"torso_forward_axis_world_unit": [1.0, 0.0, 0.0],
					"contact_by_limb": row_contacts,
					"foot_position_world_m_by_limb": feet,
					"maximum_anchor_error_m": 0.001,
					"maximum_hinge_axis_error_rad": 0.01,
					"torso_tilt_rad": 0.02,
					"torso_contact": false,
					"observation_sha256": _filled_sha256("a"),
					"application_intent_sha256": _filled_sha256("b"),
					"body_population_instance_sha256": _filled_sha256("c"),
				}
			)
		)
	var expected_native_application_count := (
		WalkingEvaluator.FIXED_SEGMENT_STEP_COUNT * LocomotionFacade.JOINT_IDS.size()
	)
	return {
		"arm_id": arm_id,
		"segment_id": "walking_prefix",
		"session_id": session_id,
		"expected_step_count": WalkingEvaluator.FIXED_SEGMENT_STEP_COUNT,
		"start_receipt":
		{
			"session_id": session_id,
			"selected_policy_id": LocomotionFacade.SELECTED_POLICY_ID,
			"task_frame_origin_world_m": [0.0, 0.35, 0.0],
			"task_frame_forward_axis_world_host_real": [1.0, 0.0, 0.0],
			"task_frame_lateral_axis_world_host_real": [0.0, 0.0, 1.0],
			"task_frame_reanchored_in_controller_memory": true,
			"task_frame_frozen_for_walking_segment": true,
		},
		"completion_receipt":
		{
			"adapter_summary":
			{
				"ok": true,
				"step_count": WalkingEvaluator.FIXED_SEGMENT_STEP_COUNT,
				"controller_policy_id": LocomotionFacade.SELECTED_POLICY_ID,
				"validated_balanced_wave_command_count": expected_native_application_count,
				"native_actuation_application_count": expected_native_application_count,
				"mismatch_count": 0,
				"safe_no_actuation_count": 0,
				"native_safe_disable_application_count": 0,
				"balanced_wave_shadow_valid": true,
			},
			"adapter_shutdown_receipt":
			{
				"ok": true,
				"explicit_shutdown_completed": true,
				"native_controller_session_destroy_count": 1,
			},
		},
		"initial_contact_by_limb": contacts,
		"rows": rows,
		"world_build_count": 1,
		"world_reset_count": 0,
		"body_population_rebuild_count": 0,
		"direct_torso_force_command_count": 0,
		"direct_torso_impulse_command_count": 0,
		"direct_torso_velocity_command_count": 0,
		"direct_torso_transform_command_count": 0,
		"fixture_spec_compiled_before_world_creation": true,
		"initial_perturbation_application_count": 0,
		"physics_engine": "Jolt Physics",
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 7,
		"source_measurement": true,
	}


static func _completed_boundary_v1(
	sdk: Object, arm_id: String, sequence: int, event_id: String
) -> Dictionary:
	return (
		QualifiedTransport
		. build_completed_step_boundary_v1(
			sdk,
			ATTEMPT_ID,
			arm_id,
			MODEL_INSTANCE_ID,
			sequence,
			event_id,
			_fixture_samples_v1(sequence),
		)
	)


static func _fixture_samples_v1(sequence: int) -> Array:
	var samples: Array = []
	for index in range(QualifiedTransport.ORDERED_BODY_IDS.size()):
		var body_id := String(QualifiedTransport.ORDERED_BODY_IDS[index])
		(
			samples
			. append(
				{
					"body_id": body_id,
					"body_index": index,
					"boundary_sequence": sequence,
					"position_world_m":
					Vector3(
						index * 0.1 + sequence * 0.001,
						0.4 + index * 0.01 + sequence * 0.002,
						-index * 0.05 + sequence * 0.003,
					),
					"linear_velocity_world_m_s":
					Vector3(
						sequence * 0.0001,
						-sequence * 0.0002,
						index * 0.001,
					),
					"mass_kg": 1.2 if body_id == "torso" else 0.44,
					"callback_sequence": sequence,
					"total_gravity_world_m_s2": Vector3(0.0, -9.8, 0.0),
					"solver_step_s": SOLVER_STEP_S,
				}
			)
		)
	return samples


static func _observer_for_global_step_v1(
	sequence: int, position_constraint_mass_weighted_displacement_kg_m: Vector3 = Vector3.ZERO
) -> Dictionary:
	var before := _fixture_samples_v1(sequence - 1)
	var after := _fixture_samples_v1(sequence)
	var rows: Array = []
	for index in range(QualifiedTransport.ORDERED_BODY_IDS.size()):
		var pre: Dictionary = before[index]
		var post: Dictionary = after[index]
		(
			rows
			. append(
				{
					"body_id": String(post["body_id"]),
					"body_index": index,
					"pre_boundary_sequence": sequence - 1,
					"post_boundary_sequence": sequence,
					"pre_source_event_id": "r10f-synthetic-boundary-%d" % (sequence - 1),
					"post_source_event_id": "r10f-synthetic-boundary-%d" % sequence,
					"mass_kg": float(post["mass_kg"]),
					"pre_position_world_m": pre["position_world_m"],
					"post_position_world_m": post["position_world_m"],
					"pre_linear_velocity_world_m_s": pre["linear_velocity_world_m_s"],
					"post_linear_velocity_world_m_s": post["linear_velocity_world_m_s"],
					"total_gravity_world_m_s2": post["total_gravity_world_m_s2"],
					"solver_step_s": SOLVER_STEP_S,
					"pre_source_measurement": true,
					"post_source_measurement": true,
				}
			)
		)
	return (
		QualifiedStagingRoute
		. measure_native_step_v1(
			sequence,
			sequence - 1,
			SOLVER_STEP_S,
			rows,
			position_constraint_mass_weighted_displacement_kg_m,
		)
	)


static func _rotation_sources_for_step_v1(
	sdk: Object,
	context: Dictionary,
	observer: Dictionary,
	sequence: int,
) -> Dictionary:
	var telemetry := R162Worker._telemetry_v2()
	for key in ["telemetry_sequence", "capture_space_step_sequence", "read_space_step_sequence"]:
		telemetry[key] = sequence
	var solver := RecoveryWorld.native_solver_energy_exchange_for_recovery_route_v2(
		context, telemetry, sequence, Vector3(0.0, -9.81, 0.0)
	)
	var motor_receipts := R162Worker._motor_receipts_v1()
	for row_value in motor_receipts:
		var row: Dictionary = row_value
		row["capture_space_step_sequence"] = sequence
		row["read_space_step_sequence"] = sequence
	var partition := RecoveryWorld.solver_coupled_complete_energy_partition_for_recovery_route_v2(
		context, solver, motor_receipts, R162Worker.STEP_ACTUATOR_WORK_J, sequence
	)
	if not bool(solver.get("ok", false)) or not bool(partition.get("ok", false)):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_ROTATION_SOURCE_CONSUMER_FIXTURE_INVALID",
			"solver": solver,
			"partition": partition,
		}
	var predecessor := R148Worker._route_predecessor_v1(sdk, observer)
	var energy: Dictionary = predecessor["energy_source_receipt"]
	var components: Dictionary = predecessor["source_component_receipts"]
	var solver_sha256 := _sha256_v1(sdk, solver)
	var partition_sha256 := _sha256_v1(sdk, partition)
	var constraint_exchange := float(partition["step_signed_constraint_exchange_j"])
	var staging_exchange := float(observer["signed_discrete_staging_exchange_j"])
	energy["schema_version"] = RecoveryRoute.R162_ROTATION_AWARE_SOURCE_RECEIPT_SCHEMA
	energy["semantic_step"] = sequence
	energy["initial_mechanical_energy_j"] = 20.0
	energy["current_mechanical_energy_j"] = 20.0 + constraint_exchange + staging_exchange
	energy["cumulative_applied_actuator_work_j"] = sequence * 0.01
	energy["cumulative_signed_external_work_j"] = sequence * 0.002
	energy["step_signed_constraint_exchange_j"] = constraint_exchange
	energy["step_position_constraint_potential_exchange_j"] = float(
		observer["position_constraint_potential_exchange_j"]
	)
	energy["cumulative_signed_constraint_exchange_j"] = sequence * constraint_exchange
	energy["cumulative_passive_dissipation_j"] = sequence * 0.001
	energy["raw_step_signed_solver_exchange_j"] = float(
		partition["raw_step_signed_solver_exchange_j"]
	)
	energy["step_actuator_work_j"] = float(partition["step_actuator_work_j"])
	energy["solver_energy_exchange_receipt_sha256"] = solver_sha256
	energy["solver_coupled_partition_receipt_sha256"] = partition_sha256
	energy["recovery_energy_ledger_profile_id"] = (
		RecoveryRoute.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
	)
	energy["solver_energy_consumer_contract_schema_version"] = (
		RecoveryRoute.R162_SOLVER_ENERGY_CONSUMER_CONTRACT_SCHEMA
	)
	energy["solver_energy_telemetry_schema_version"] = (
		RecoveryRoute.R162_SOLVER_ENERGY_TELEMETRY_SCHEMA
	)
	energy["solver_energy_telemetry_profile_id"] = (
		RecoveryRoute.R162_SOLVER_ENERGY_TELEMETRY_PROFILE_ID
	)
	energy["rotation_integration_kinetic_exchange_j"] = float(
		partition["rotation_integration_kinetic_exchange_j"]
	)
	energy["rotation_integration_exchange_included_exactly_once"] = true

	components["schema_version"] = RecoveryRoute.R162_ROTATION_AWARE_COMPONENT_RECEIPTS_SCHEMA
	components["semantic_step"] = sequence
	components["solver_energy_exchange_receipt"] = solver
	components["solver_energy_exchange_receipt_sha256"] = solver_sha256
	components["solver_coupled_partition_receipt"] = partition
	components["solver_coupled_partition_receipt_sha256"] = partition_sha256
	components["recovery_energy_ledger_profile_id"] = (
		RecoveryRoute.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
	)
	components["rotation_integration_exchange_included_exactly_once"] = true
	return {
		"ok": EnergyInitializer.rotation_aware_sources_valid_v1(sdk, energy, components),
		"energy_source_receipt": energy,
		"source_component_receipts": components,
	}


static func _rebase_fixture_cumulatives_after_initializer_v1(
	energy: Dictionary, initializer: Dictionary
) -> void:
	energy["cumulative_applied_actuator_work_j"] = (
		float(initializer["global_cumulative_applied_actuator_work_at_epoch_start_j"]) + 0.25
	)
	energy["cumulative_signed_external_work_j"] = (
		float(initializer["global_cumulative_signed_external_work_at_epoch_start_j"]) + 0.0
	)
	energy["cumulative_signed_constraint_exchange_j"] = (
		float(initializer["global_cumulative_signed_constraint_exchange_at_epoch_start_j"])
		+ float(energy["step_signed_constraint_exchange_j"])
	)
	energy["cumulative_passive_dissipation_j"] = (
		float(initializer["global_cumulative_passive_dissipation_at_epoch_start_j"]) + 0.01
	)


static func _global_staging_accumulator_v1(sequence: int) -> Dictionary:
	return {
		"schema_version": QualifiedStagingRoute.ACCUMULATOR_SCHEMA,
		"sequence": sequence,
		"event_count": sequence,
		"cumulative_signed_discrete_staging_exchange_j": 0.125,
		"last_observer_receipt_sha256": _filled_sha256("c"),
		"previous_accumulator_sha256": _filled_sha256("d"),
		"source_measurement": true,
		"mechanical_energy_change_used_as_input": false,
		"energy_balance_residual_used_as_input": false,
		"acceptance_threshold_used_as_input": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _observation_base_for_step_v1(
	sdk: Object, context: Dictionary, sequence: int
) -> Dictionary:
	var fixture := RecoveryRoute._zero_world_fixture_for_controller_v1(
		sdk, context, RecoveryRoute.RECOVERY_CONTROLLER_V6_ID
	)
	if not bool(fixture.get("ok", false)):
		return {}
	var observation: Dictionary = (fixture["observation_v2"] as Dictionary).duplicate(true)
	observation.erase("schema_version")
	observation.erase("energy_balance")
	observation["semantic_step"] = sequence
	var engine_identity: Dictionary = observation["engine_step_identity"]
	engine_identity["semantic_step"] = sequence
	engine_identity["host_step_before"] = sequence - 1
	engine_identity["host_step_after"] = sequence
	engine_identity["capability_sha256"] = String(context["capability_sha256"])
	var state: Dictionary = observation["state"]
	state["semantic_step"] = sequence
	state["adapter_capability_sha256"] = String(context["capability_sha256"])
	(observation["applied_actuation"] as Dictionary)["source_semantic_step"] = sequence
	return observation


static func _walking_ledger_production_fixture_v2(
	sdk: Object,
	global_step: int,
	facade_segment_id: String,
	evaluation_segment_id: String,
	phase: String,
	session_id: String,
	development_policy_id: String = "",
	use_preloaded_native_runtime: bool = false,
	development_floor_source: Dictionary = {},
	development_body_fixture: Dictionary = {},
) -> Dictionary:
	var policy := LocomotionFacade.DevelopmentWalkingPolicy.binding_v1(development_policy_id, evaluation_segment_id)
	if policy.is_empty():
		return {"ok": false, "failure_code": "DEVELOPMENT_WALKING_POLICY_FIXTURE_SELECTION"}
	var detached_joints: Array[HingeJoint3D] = []
	var adapter := AdapterScript.new()
	adapter._development_native_step_failure_retention_enabled = development_policy_id in [LocomotionFacade.DevelopmentWalkingPolicy.FiniteRoute.StanceEntry.FLEXED_NEUTRAL_ID, LocomotionFacade.DevelopmentWalkingPolicy.R10K.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10L.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10M.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10N.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10O.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Q.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10R.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10S.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10T.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10U.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10V.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Y.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Z.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AA.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AB.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AG.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AI.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AP.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AM.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AJ.ENTRY_ALIAS]
	var material := MaterialProfiles.resolve(LocomotionFacade.MATERIAL_PROFILE_ID)
	if not bool(material.get("ok", false)):
		return {"ok": false, "failure_code": "QSDK_R10F_L13_MATERIAL_PROFILE_INVALID"}
	var gait_steps := (LocomotionFacade.DevelopmentWalkingPolicy.R10AP.post_hold_gait_steps_v1(facade_segment_id, "", "")
		if development_policy_id == LocomotionFacade.DevelopmentWalkingPolicy.R10AP.POST_HOLD_ALIAS else LocomotionFacade.DevelopmentWalkingPolicy.R10AM.post_hold_gait_steps_v1(facade_segment_id, "", "")
		if development_policy_id == LocomotionFacade.DevelopmentWalkingPolicy.R10AM.POST_HOLD_ALIAS else LocomotionFacade.DevelopmentWalkingPolicy.R10AJ.post_hold_gait_steps_v1(facade_segment_id, "", "")
		if development_policy_id == LocomotionFacade.DevelopmentWalkingPolicy.R10AJ.POST_HOLD_ALIAS else LocomotionFacade.DevelopmentWalkingPolicy.R10AI.post_hold_gait_steps_v1(facade_segment_id, "", "")
		if development_policy_id == LocomotionFacade.DevelopmentWalkingPolicy.R10AI.POST_HOLD_ALIAS else LocomotionFacade.DevelopmentWalkingPolicy.R10AG.post_hold_gait_steps_v1(facade_segment_id, "", "")
		if development_policy_id == LocomotionFacade.DevelopmentWalkingPolicy.R10AG.POST_HOLD_ALIAS else LocomotionFacade.DevelopmentWalkingPolicy.R10AB.post_hold_gait_steps_v1(facade_segment_id, "", "")
		if development_policy_id == LocomotionFacade.DevelopmentWalkingPolicy.R10AB.POST_HOLD_ALIAS else LocomotionFacade.DevelopmentWalkingPolicy.R10AA.post_hold_gait_steps_v1(facade_segment_id, "", "")
		if development_policy_id == LocomotionFacade.DevelopmentWalkingPolicy.R10AA.POST_HOLD_ALIAS else LocomotionFacade.DevelopmentWalkingPolicy.R10Z.post_hold_gait_steps_v1(facade_segment_id, "", "")
		if development_policy_id == LocomotionFacade.DevelopmentWalkingPolicy.R10Z.POST_HOLD_ALIAS else LocomotionFacade.DevelopmentWalkingPolicy.R10Y.post_hold_gait_steps_v1(facade_segment_id, "", "")
		if development_policy_id == LocomotionFacade.DevelopmentWalkingPolicy.R10Y.POST_HOLD_ALIAS else LocomotionFacade.DevelopmentWalkingPolicy.R10V.post_hold_gait_steps_v1(facade_segment_id, "", "")
		if development_policy_id == LocomotionFacade.DevelopmentWalkingPolicy.R10V.POST_HOLD_ALIAS else LocomotionFacade.DevelopmentWalkingPolicy.R10U.post_hold_gait_steps_v1(facade_segment_id, "", "")
		if development_policy_id == LocomotionFacade.DevelopmentWalkingPolicy.R10U.POST_HOLD_ALIAS else LocomotionFacade.DevelopmentWalkingPolicy.R10T.post_hold_gait_steps_v1(facade_segment_id, "", "")
		if development_policy_id == LocomotionFacade.DevelopmentWalkingPolicy.R10T.POST_HOLD_ALIAS
		else LocomotionFacade.initial_gait_steps_v1(40200, facade_segment_id))
	var started := (
		adapter
		. start(
			RecoveryRoute.exact_base_descriptor_v1(),
			gait_steps,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			0.0,
			LocomotionFacade.PHYSICS_HZ,
			LocomotionFacade.SOLVER_POLICY.duplicate(true),
			AdapterScript.DEFAULT_TOLERANCE,
			"contact_gated",
			true,
			0,
			-1,
			"post_settle_full",
			AdapterScript.P5I3B_WEIGHT_SUPPORT_POLICY_ID,
			(material["profile"] as Dictionary).duplicate(true),
			policy["policy_id"],
			-1.0, false, AdapterScript.FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID,
			use_preloaded_native_runtime,
		)
	)
	if not bool(started.get("ok", false)):
		return _walking_ledger_production_fixture_failure_v2(
			adapter,
			detached_joints,
			"QSDK_R10F_L13_ADAPTER_START_FAILED",
			started,
		)
	if not development_floor_source.is_empty():
		var bound := adapter.bind_development_floor_source_v1(development_floor_source, "r10f-l13-zero-world-%s" % evaluation_segment_id)
		if bound.get("ok") != true:
			return _walking_ledger_production_fixture_failure_v2(adapter, detached_joints, "FLOOR_FIXTURE_BINDING", bound)
	var compiled := adapter.compiled_morphology_for_conformance()
	var cap_binding := LocomotionFacade.walking_host_cap_projection_binding_v1(sdk)
	if not bool(compiled.get("ok", false)) or not bool(cap_binding.get("ok", false)):
		return _walking_ledger_production_fixture_failure_v2(
			adapter,
			detached_joints,
			"QSDK_R10F_L13_PRODUCTION_PREFLIGHT_FAILED",
			{"compiled": compiled, "cap_binding": cap_binding},
		)
	var morphology: Dictionary = compiled["morphology"]
	var authorized_caps: Dictionary = cap_binding["selected_host_cap_by_actuator_id"]
	var joint_state_by_legacy_id: Dictionary = {}
	var joint_nodes_by_recovery_id: Dictionary = {}
	var ordered_actuator_ids: Array = morphology.get("ordered_actuator_ids", [])
	for index in range(ordered_actuator_ids.size()):
		var actuator_id := String(ordered_actuator_ids[index])
		var legacy_joint_id := String(adapter.call("_legacy_joint_id_for_actuator", actuator_id))
		var recovery_joint_id := String(LocomotionFacade.JOINT_IDS[index])
		var joint := HingeJoint3D.new()
		joint.name = "r10f_l13_zero_world_%s_%s" % [evaluation_segment_id, recovery_joint_id]
		(
			joint
			. set_param(
				HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,
				float(authorized_caps.get(actuator_id, NAN)),
			)
		)
		joint_state_by_legacy_id[legacy_joint_id] = {"joint": joint}
		joint_nodes_by_recovery_id[recovery_joint_id] = joint
		detached_joints.append(joint)
	var facade := LocomotionFacade.new()
	(
		facade
		. set(
			"_binding",
			{
				"joint_nodes": joint_nodes_by_recovery_id,
				"model_instance_id": "r10f-l13-zero-world-%s" % evaluation_segment_id,
			},
		)
	)
	facade.set("_started", true)
	facade.set("_shutdown", false)
	facade.set("_walking_actuation_handoff_receipt", {})
	facade.set("_global_start_step", global_step - 1)
	facade.set("_segment_id", facade_segment_id)
	facade.set("_session_id", session_id)
	facade.set("_development_walking_policy_id", development_policy_id)
	var handoff := (
		facade
		. begin_walking_actuation_handoff_v1(
			sdk,
			evaluation_segment_id,
			global_step,
		)
	)
	if not bool(handoff.get("ok", false)):
		return _walking_ledger_production_fixture_failure_v2(
			adapter,
			detached_joints,
			"QSDK_R10F_L13_FRESH_HANDOFF_FAILED",
			handoff,
		)
	var state_value: Variant = (
		adapter
		. call(
			"_perfect_synthetic_controller_state_frame",
			1,
			morphology,
		)
	)
	var command_value: Variant = (
		adapter
		. call(
			"_perfect_synthetic_motion_command",
			1,
			"contact_gated",
		)
	)
	if not development_body_fixture.is_empty():
		var task: Dictionary = state_value["task_frame"].duplicate(true)
		var capability: String = state_value["adapter_capability_sha256"]
		state_value = development_body_fixture["state"].duplicate(true)
		state_value["task_frame"] = task
		state_value["adapter_capability_sha256"] = capability
		command_value["gait_amplitude"] = 0.0
	if development_policy_id in [LocomotionFacade.DevelopmentWalkingPolicy.FiniteRoute.StanceEntry.FLEXED_NEUTRAL_ID, LocomotionFacade.DevelopmentWalkingPolicy.R10K.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10L.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10M.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10N.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10O.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Q.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10R.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10S.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10T.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10U.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10V.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Y.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Z.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AA.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AB.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AG.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AI.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AP.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AM.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AJ.ENTRY_ALIAS]:
		command_value["gait_amplitude"] = 0.0
		command_value["desired_planar_velocity_task_m_s"] = {"x": 0.0, "y": 0.0, "z": 0.0}
	if development_policy_id in [LocomotionFacade.DevelopmentWalkingPolicy.R10K.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10L.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10M.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10N.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10O.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Q.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10R.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10S.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10T.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10U.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10T.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10U.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10V.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10V.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Y.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Z.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Y.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Z.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AA.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AA.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AB.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AB.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AG.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AI.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AP.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AM.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AJ.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AG.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AI.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AP.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AM.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AJ.POST_HOLD_ALIAS]:
		command_value["gait_amplitude"] = 0.0
		command_value["desired_planar_velocity_task_m_s"] = {"x": 0.0, "y": 0.0, "z": 0.0}
	if development_policy_id == LocomotionFacade.DevelopmentWalkingPolicy.FiniteRoute.StanceEntry.NEUTRAL_ID:
		command_value["gait_amplitude"] = 0.0
	var memory_value: Variant = adapter.get("_memory")
	if (
		not (state_value is Dictionary)
		or not (command_value is Dictionary)
		or not (memory_value is Dictionary)
	):
		return _walking_ledger_production_fixture_failure_v2(
			adapter,
			detached_joints,
			"QSDK_R10F_L13_SYNTHETIC_REQUEST_SOURCE_INVALID",
		)
	var request_value: Variant = (
		adapter
		. call(
			"_controller_step_request",
			(memory_value as Dictionary).duplicate(true),
			(state_value as Dictionary).duplicate(true),
			(command_value as Dictionary).duplicate(true),
		)
	)
	if not (request_value is Dictionary):
		return _walking_ledger_production_fixture_failure_v2(
			adapter,
			detached_joints,
			"QSDK_R10F_L13_SYNTHETIC_REQUEST_INVALID",
		)
	if not development_body_fixture.is_empty():
		request_value["measured_body_frame"] = AdapterScript.DevelopmentMeasuredBody.project_v1(state_value,
			{"semantic_step": 1, "adapter_capability_sha256": state_value["adapter_capability_sha256"],
			"ordered_body_states": development_body_fixture["measured_body_frame"]["ordered_body_states"]})
	var sample_result := {
		"ok": true,
		"failure_code": "",
		"request": (request_value as Dictionary).duplicate(true),
		"stability_shadow": {},
	}
	var step_result := (
		adapter
		. step(
			sample_result,
			1,
			{},
			gait_steps,
			0.0,
			{},
			true,
		)
	)
	if not bool(step_result.get("ok", false)):
		return _walking_ledger_production_fixture_failure_v2(
			adapter,
			detached_joints,
			"QSDK_R10F_L13_PRODUCTION_ADAPTER_STEP_FAILED",
			step_result,
		)
	var applied := (
		adapter
		. apply_authority(
			step_result,
			joint_state_by_legacy_id,
			true,
			authorized_caps,
		)
	)
	var readback := (
		facade
		. motor_population_readback_v1(
			global_step,
			true,
			"post_bw5r_b_authority_application",
		)
	)
	var ledger := (
		LocomotionFacade
		. walking_ledger_application_intent_v2(
			sdk,
			global_step,
			phase,
			session_id,
			1,
			step_result,
			applied,
			readback,
			handoff,
			development_policy_id,
		)
	)
	var shutdown := adapter.shutdown()
	for joint in detached_joints:
		joint.free()
	var result := {
		"ok":
		(
			bool(applied.get("ok", false))
			and bool(readback.get("ok", false))
			and bool(ledger.get("ok", false))
			and bool(shutdown.get("ok", false))
		),
		"failure_code":
		"" if bool(ledger.get("ok", false)) else String(ledger.get("failure_code", "")),
		"facade_segment_id": facade_segment_id,
		"evaluation_segment_id": evaluation_segment_id,
		"phase": phase,
		"session_id": session_id,
		"adapter_start_receipt": started,
		"walking_actuation_handoff_receipt": handoff,
		"portable_step_receipt": step_result,
		"native_step_transport_verification":
		step_result.get("native_step_transport_verification", {}),
		"authority_application_receipt": applied,
		"motor_population_readback": readback,
		"ledger_application_intent": ledger,
		"host_target_projection_receipt": ledger.get("host_target_projection_receipt", {}),
		"walking_ledger_predicate_receipt": ledger.get("walking_ledger_predicate_receipt", {}),
		"adapter_shutdown_receipt": shutdown,
		"fresh_handoff_constructed_by_production_facade": true,
		"detached_hinge_parameter_container_count": detached_joints.size(),
		"body_construction_count": 0,
		"scene_tree_insertion_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_frame_await_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if development_policy_id in [LocomotionFacade.DevelopmentWalkingPolicy.FiniteRoute.StanceEntry.FLEXED_NEUTRAL_ID, LocomotionFacade.DevelopmentWalkingPolicy.FiniteRoute.StanceEntry.NEUTRAL_ID, LocomotionFacade.DevelopmentWalkingPolicy.R10K.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10K.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10L.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10M.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10N.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10O.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Q.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10R.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10S.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10T.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10U.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10L.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10M.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10N.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10O.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Q.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10R.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10S.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10T.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10U.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10T.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10U.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Y.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Z.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10V.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10V.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10V.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Y.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Z.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Y.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10Z.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AA.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AA.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AA.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AB.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AB.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AB.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AG.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AI.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AP.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AM.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AJ.ENTRY_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AG.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AI.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AP.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AM.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AJ.HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AG.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AI.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AP.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AM.POST_HOLD_ALIAS, LocomotionFacade.DevelopmentWalkingPolicy.R10AJ.POST_HOLD_ALIAS]:
		result["sample_receipt"] = sample_result
	return result


static func _walking_ledger_production_fixture_failure_v2(
	adapter: RefCounted,
	detached_joints: Array[HingeJoint3D],
	failure_code: String,
	detail: Dictionary = {},
) -> Dictionary:
	var shutdown: Dictionary = {}
	if adapter != null:
		shutdown = adapter.shutdown()
	for joint in detached_joints:
		if is_instance_valid(joint):
			joint.free()
	return {
		"ok": false,
		"failure_code": failure_code,
		"detail": detail.duplicate(true),
		"adapter_shutdown_receipt": shutdown,
		"detached_hinge_parameter_container_count": detached_joints.size(),
		"body_construction_count": 0,
		"scene_tree_insertion_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_frame_await_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _walking_ledger_l13_controls_v1(
	sdk: Object,
	walking_prefix_fixture: Dictionary,
	matched_continuation_fixture: Dictionary,
	walking_resume_fixture: Dictionary,
	physical_worker_contract: Dictionary,
) -> Dictionary:
	var prefix_step: Dictionary = walking_prefix_fixture["portable_step_receipt"]
	var prefix_native_output: Dictionary = prefix_step["native_output"]
	var prefix_actuation: Dictionary = prefix_native_output["actuation"]
	var prefix_verification: Dictionary = prefix_step["native_step_transport_verification"]
	var prefix_projection: Dictionary = walking_prefix_fixture["host_target_projection_receipt"]
	var prefix_ledger: Dictionary = walking_prefix_fixture["ledger_application_intent"]
	var prefix_handoff: Dictionary = walking_prefix_fixture["walking_actuation_handoff_receipt"]
	var prefix_authority: Dictionary = walking_prefix_fixture["authority_application_receipt"]
	var prefix_population: Dictionary = walking_prefix_fixture["motor_population_readback"]
	var controller_receipt_sha256 := String(prefix_actuation.get("receipt_sha256", ""))
	var verification_valid := (
		AdapterScript
		. native_step_transport_verification_receipt_valid_v1(
			prefix_verification,
			LocomotionFacade.SELECTED_POLICY_ID,
			LocomotionFacade.SELECTED_CONTROLLER_RECEIPT_SCHEMA,
			1,
			controller_receipt_sha256,
		)
	)
	var projection_valid := (
		LocomotionFacade
		. walking_host_target_projection_receipt_valid_v1(
			sdk,
			prefix_projection,
		)
	)
	var projection_rows: Array = prefix_projection.get("ordered_target_projections", [])
	var exact_projection_count := 0
	var exact_readback_pair_count := 0
	var separately_retained_count := 0
	var r69_exact_count := 0
	for row_value in projection_rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var controller_target := float(row.get("controller_binary64_target_velocity_rad_s", NAN))
		var expected_host_target := float(PackedFloat32Array([controller_target])[0])
		exact_projection_count += int(
			(
				controller_target != 0.0
				and is_finite(controller_target)
				and (
					float(row.get("expected_binary32_host_target_velocity_rad_s", NAN))
					== expected_host_target
				)
			)
		)
		exact_readback_pair_count += int(
			(
				(
					float(row.get("application_motor_target_velocity_readback_rad_s", NAN))
					== expected_host_target
				)
				and (
					float(row.get("population_motor_target_velocity_readback_rad_s", NAN))
					== expected_host_target
				)
			)
		)
		separately_retained_count += int(
			(
				row.has("controller_binary64_target_velocity_rad_s")
				and row.has("expected_binary32_host_target_velocity_rad_s")
			)
		)
		r69_exact_count += int(bool(row.get("r69_host_cap_exact", false)))

	var retained_failure_portable: Dictionary = prefix_step.duplicate(true)
	retained_failure_portable["controller_policy_id"] = "mutated-policy-must-fail"
	var retained_failure := _walking_ledger_v2_for_fixture_sources_v1(
		sdk,
		walking_prefix_fixture,
		retained_failure_portable,
		prefix_authority,
		prefix_population,
		prefix_handoff,
	)
	var partial_failure_projection := (
		PhysicalWorker
		. partial_arm_failure_retention_projection_v1(
			{
				"active_walking_session":
				{
					"session_id": String(walking_prefix_fixture["session_id"]),
					"start_receipt": walking_prefix_fixture["adapter_start_receipt"],
					"walking_actuation_handoff_receipt": prefix_handoff,
				},
				"last_walking_step_failure": retained_failure,
			},
			EnergyInitializer.BASELINE_ARM_ID,
		)
	)
	var all_v2_segments := true
	for fixture in [
		walking_prefix_fixture,
		matched_continuation_fixture,
		walking_resume_fixture,
	]:
		var fixture_ledger: Dictionary = fixture.get("ledger_application_intent", {})
		var fixture_step: Dictionary = fixture.get("portable_step_receipt", {})
		var fixture_verification: Dictionary = fixture_step.get(
			"native_step_transport_verification", {}
		)
		var fixture_actuation: Dictionary = (
			(fixture_step.get("native_output", {}) as Dictionary).get("actuation", {})
		)
		all_v2_segments = (
			all_v2_segments
			and bool(fixture.get("ok", false))
			and bool(fixture_ledger.get("ok", false))
			and (
				String(fixture_ledger.get("schema_version", ""))
				== LocomotionFacade.WALKING_LEDGER_APPLICATION_SCHEMA_V2
			)
			and (
				AdapterScript
				. native_step_transport_verification_receipt_valid_v1(
					fixture_verification,
					LocomotionFacade.SELECTED_POLICY_ID,
					LocomotionFacade.SELECTED_CONTROLLER_RECEIPT_SCHEMA,
					1,
					String(fixture_actuation.get("receipt_sha256", "")),
				)
			)
			and (
				LocomotionFacade
				. walking_host_target_projection_receipt_valid_v1(
					sdk,
					fixture.get("host_target_projection_receipt", {}),
				)
			)
		)

	var positive_controls := {
		"exact_raw_native_bw5r_b_step_response_is_verified_before_json_parse_string":
		(
			verification_valid
			and bool(prefix_verification.get("preparse_native_response_verified", false))
			and not bool(prefix_verification.get("post_parse_dictionary_rehash_used", true))
			and not bool(prefix_verification.get("raw_native_response_rewritten", true))
		),
		"native_transport_verification_recomputes_the_nested_controller_receipt_digest_and_binds_the_raw_response_sha256":
		(
			bool(prefix_verification.get("native_canonical_receipt_digest_exact", false))
			and (
				String(prefix_verification.get("controller_receipt_sha256", ""))
				== controller_receipt_sha256
			)
			and (
				String(prefix_verification.get("native_actuation_receipt_sha256", ""))
				== controller_receipt_sha256
			)
			and _sha256_text_valid_v1(
				String(prefix_verification.get("raw_native_response_sha256", ""))
			)
			and int(prefix_verification.get("raw_native_response_byte_length", 0)) > 0
		),
		"transport_verification_receipt_contains_no_floating_point_measurement_fields":
		(
			int(prefix_verification.get("floating_point_measurement_field_count", -1)) == 0
			and _measurement_bearing_key_count_v1(prefix_verification) == 0
		),
		"production_adapter_step_exposes_the_successful_transport_verification_receipt":
		(
			prefix_step.has("native_step_transport_verification")
			and prefix_step["native_step_transport_verification"] is Dictionary
			and verification_valid
		),
		"production_facade_uses_a_fresh_real_walking_handoff_and_not_a_hand_built_handoff_dictionary":
		(
			bool(
				walking_prefix_fixture.get("fresh_handoff_constructed_by_production_facade", false)
			)
			and (
				LocomotionFacade
				. walking_actuation_handoff_receipt_valid_v1(
					sdk,
					prefix_handoff,
				)
			)
		),
		"production_apply_authority_runs_against_eight_detached_hinge_parameter_containers":
		(
			(
				int(walking_prefix_fixture.get("detached_hinge_parameter_container_count", -1))
				== LocomotionFacade.JOINT_IDS.size()
			)
			and (
				int(prefix_authority.get("applied_command_count", -1))
				== LocomotionFacade.JOINT_IDS.size()
			)
			and int(walking_prefix_fixture.get("scene_tree_insertion_count", -1)) == 0
		),
		"every_nonzero_controller_binary64_target_has_its_exact_packed_float32_host_projection_computed":
		(
			projection_valid
			and int(prefix_projection.get("nonzero_controller_target_count", -1)) > 0
			and (
				exact_projection_count
				== int(prefix_projection.get("nonzero_controller_target_count", -2))
			)
		),
		"application_and_population_target_readbacks_equal_the_exact_binary32_projection":
		(
			exact_readback_pair_count == LocomotionFacade.JOINT_IDS.size()
			and (
				int(prefix_projection.get("application_readback_equals_projection_count", -1))
				== LocomotionFacade.JOINT_IDS.size()
			)
			and (
				int(prefix_projection.get("population_readback_equals_projection_count", -1))
				== LocomotionFacade.JOINT_IDS.size()
			)
		),
		"controller_binary64_request_and_binary32_host_realization_are_both_retained_without_relabeling":
		(
			bool(prefix_projection.get("controller_binary64_target_retained_separately", false))
			and bool(
				prefix_projection.get("expected_binary32_host_target_retained_separately", false)
			)
			and separately_retained_count == LocomotionFacade.JOINT_IDS.size()
			and _first_binary32_difference_row_v1(prefix_projection) >= 0
		),
		"all_eight_existing_r69_host_caps_still_match_exactly":
		(
			r69_exact_count == LocomotionFacade.JOINT_IDS.size()
			and (
				int(prefix_projection.get("r69_host_cap_exact_count", -1))
				== LocomotionFacade.JOINT_IDS.size()
			)
			and (
				prefix_authority.get("authorized_maximum_impulse_by_actuator_id")
				== prefix_handoff.get("authorized_host_cap_by_actuator_id")
			)
		),
		"walking_ledger_v2_accepts_the_complete_production_shaped_first_step_without_a_world_or_solver":
		(
			bool(prefix_ledger.get("ok", false))
			and (
				String(prefix_ledger.get("schema_version", ""))
				== LocomotionFacade.WALKING_LEDGER_APPLICATION_SCHEMA_V2
			)
			and int(walking_prefix_fixture.get("world_build_count", -1)) == 0
			and int(walking_prefix_fixture.get("solver_step_count", -1)) == 0
		),
		"prefix_matched_continuation_and_resume_use_the_same_v2_transport_and_projection_contract":
		all_v2_segments,
		"a_failed_ledger_preflight_retains_every_named_predicate_and_all_already_observed_step_sources":
		_l13_ledger_failure_retained_v1(retained_failure),
		"the_partial_child_serializer_retains_the_active_walking_session_and_last_walking_step_failure":
		(
			PhysicalWorker.partial_walking_failure_retention_valid_v1(partial_failure_projection)
			and (
				int(
					physical_worker_contract.get(
						"walking_ledger_failure_retention_positive_control_count", -1
					)
				)
				== 1
			)
			and (
				int(
					physical_worker_contract.get(
						"walking_ledger_failure_retention_mutation_rejection_count", -1
					)
				)
				== 15
			)
		),
		"all_existing_l12_handoff_l11_release_l10_terminal_and_l9_process_isolation_controls_still_pass":
		bool(
			physical_worker_contract.get(
				"all_existing_l12_handoff_positive_controls_still_pass", false
			)
		),
	}

	var negative_controls := _walking_ledger_l13_negative_controls_v1(
		sdk,
		walking_prefix_fixture,
		retained_failure,
		physical_worker_contract,
	)
	var positive_count := 0
	for value in positive_controls.values():
		positive_count += int(bool(value))
	return {
		"schema_version":
		"sporespore_qsdk_r10f_l13_walking_ledger_transport_projection_zero_world_v1",
		"gate_id": GATE_ID,
		"repair_id": "QSDK-R10F-L13",
		"ok":
		(
			positive_count == positive_controls.size()
			and positive_controls.size() == 15
			and bool(negative_controls.get("ok", false))
			and int(negative_controls.get("rejection_count", -1)) == 16
		),
		"positive_control_count": positive_count,
		"expected_positive_control_count": positive_controls.size(),
		"positive_controls": positive_controls,
		"negative_controls": negative_controls.get("controls", {}),
		"mutation_rejection_count": int(negative_controls.get("rejection_count", -1)),
		"expected_mutation_rejection_count": 16,
		"representative_retained_failure": retained_failure,
		"representative_partial_child_projection": partial_failure_projection,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _walking_ledger_l13_negative_controls_v1(
	sdk: Object,
	walking_prefix_fixture: Dictionary,
	retained_failure: Dictionary,
	physical_worker_contract: Dictionary,
) -> Dictionary:
	var prefix_step: Dictionary = walking_prefix_fixture["portable_step_receipt"]
	var prefix_authority: Dictionary = walking_prefix_fixture["authority_application_receipt"]
	var prefix_population: Dictionary = walking_prefix_fixture["motor_population_readback"]
	var prefix_handoff: Dictionary = walking_prefix_fixture["walking_actuation_handoff_receipt"]
	var prefix_projection: Dictionary = walking_prefix_fixture["host_target_projection_receipt"]
	var prefix_actuation: Dictionary = (prefix_step["native_output"] as Dictionary)["actuation"]
	var prefix_verification: Dictionary = prefix_step["native_step_transport_verification"]
	var controller_receipt_sha256 := String(prefix_actuation.get("receipt_sha256", ""))

	var missing_verification_step: Dictionary = prefix_step.duplicate(true)
	missing_verification_step.erase("native_step_transport_verification")
	var missing_verification_failure := _walking_ledger_v2_for_fixture_sources_v1(
		sdk,
		walking_prefix_fixture,
		missing_verification_step,
		prefix_authority,
		prefix_population,
		prefix_handoff,
	)

	var wrong_raw_verification: Dictionary = prefix_verification.duplicate(true)
	wrong_raw_verification["raw_native_response_sha256"] = _filled_sha256("0")
	var wrong_controller_verification: Dictionary = prefix_verification.duplicate(true)
	wrong_controller_verification["controller_receipt_sha256"] = _filled_sha256("1")
	var wrong_policy_verification: Dictionary = prefix_verification.duplicate(true)
	wrong_policy_verification["policy_id"] = "mutated-policy-must-fail"
	var wrong_step_verification: Dictionary = prefix_verification.duplicate(true)
	wrong_step_verification["semantic_step"] = 2
	var floating_verification: Dictionary = prefix_verification.duplicate(true)
	floating_verification["floating_point_measurement_field_count"] = 1
	floating_verification["controller_target_velocity_rad_s"] = 0.25
	var postparse_verification: Dictionary = prefix_verification.duplicate(true)
	postparse_verification["post_parse_dictionary_rehash_used"] = true
	postparse_verification["post_parse_controller_receipt_sha256"] = controller_receipt_sha256

	var missing_target_step := _mutated_l13_controller_target_v1(prefix_step, 0, 0.0, true)
	var nonfinite_target_step := _mutated_l13_controller_target_v1(prefix_step, 0, NAN)
	var out_of_range_target_step := _mutated_l13_controller_target_v1(prefix_step, 0, 1.0e100)
	var target_shape_rejections := []
	for mutated_step in [missing_target_step, nonfinite_target_step, out_of_range_target_step]:
		(
			target_shape_rejections
			. append(
				_l13_ledger_failure_retained_v1(
					_walking_ledger_v2_for_fixture_sources_v1(
						sdk,
						walking_prefix_fixture,
						mutated_step,
						prefix_authority,
						prefix_population,
						prefix_handoff,
					)
				)
			)
		)

	var differing_row_index := _first_binary32_difference_row_v1(prefix_projection)
	var binary64_as_host_refused := false
	var adjacent_binary32_refused := false
	var application_population_cross_refused := false
	if differing_row_index >= 0:
		var projection_rows: Array = prefix_projection["ordered_target_projections"]
		var reference_row: Dictionary = projection_rows[differing_row_index]
		var controller_target := float(reference_row["controller_binary64_target_velocity_rad_s"])
		var expected_host_target := float(
			reference_row["expected_binary32_host_target_velocity_rad_s"]
		)
		var adjacent_host_target := _adjacent_binary32_v1(expected_host_target)
		var binary64_authority := _mutated_l13_application_readback_v1(
			prefix_authority,
			differing_row_index,
			controller_target,
		)
		var binary64_population := _mutated_l13_population_readback_v1(
			prefix_population,
			differing_row_index,
			controller_target,
		)
		binary64_as_host_refused = _l13_ledger_failure_retained_v1(
			_walking_ledger_v2_for_fixture_sources_v1(
				sdk,
				walking_prefix_fixture,
				prefix_step,
				binary64_authority,
				binary64_population,
				prefix_handoff,
			)
		)
		var adjacent_authority := _mutated_l13_application_readback_v1(
			prefix_authority,
			differing_row_index,
			adjacent_host_target,
		)
		var adjacent_population := _mutated_l13_population_readback_v1(
			prefix_population,
			differing_row_index,
			adjacent_host_target,
		)
		adjacent_binary32_refused = (
			adjacent_host_target != expected_host_target
			and _l13_ledger_failure_retained_v1(
				_walking_ledger_v2_for_fixture_sources_v1(
					sdk,
					walking_prefix_fixture,
					prefix_step,
					adjacent_authority,
					adjacent_population,
					prefix_handoff,
				)
			)
		)
		application_population_cross_refused = _l13_ledger_failure_retained_v1(
			_walking_ledger_v2_for_fixture_sources_v1(
				sdk,
				walking_prefix_fixture,
				prefix_step,
				prefix_authority,
				adjacent_population,
				prefix_handoff,
			)
		)

	var projection_shape_rejections := []
	var missing_projection_row: Dictionary = prefix_projection.duplicate(true)
	var missing_rows: Array = missing_projection_row["ordered_target_projections"]
	missing_rows.remove_at(0)
	missing_projection_row["ordered_target_projections"] = missing_rows
	(
		projection_shape_rejections
		. append(
			not (
				LocomotionFacade
				. walking_host_target_projection_receipt_valid_v1(
					sdk,
					_rehash_payload_receipt_v1(sdk, missing_projection_row),
				)
			)
		)
	)
	var extra_projection_row: Dictionary = prefix_projection.duplicate(true)
	var extra_rows: Array = extra_projection_row["ordered_target_projections"]
	extra_rows.append((extra_rows[0] as Dictionary).duplicate(true))
	extra_projection_row["ordered_target_projections"] = extra_rows
	(
		projection_shape_rejections
		. append(
			not (
				LocomotionFacade
				. walking_host_target_projection_receipt_valid_v1(
					sdk,
					_rehash_payload_receipt_v1(sdk, extra_projection_row),
				)
			)
		)
	)
	var reordered_projection: Dictionary = prefix_projection.duplicate(true)
	var reordered_rows: Array = reordered_projection["ordered_target_projections"]
	var first_row: Variant = reordered_rows[0]
	reordered_rows[0] = reordered_rows[1]
	reordered_rows[1] = first_row
	reordered_projection["ordered_target_projections"] = reordered_rows
	(
		projection_shape_rejections
		. append(
			not (
				LocomotionFacade
				. walking_host_target_projection_receipt_valid_v1(
					sdk,
					_rehash_payload_receipt_v1(sdk, reordered_projection),
				)
			)
		)
	)
	var duplicate_projection: Dictionary = prefix_projection.duplicate(true)
	var duplicate_rows: Array = duplicate_projection["ordered_target_projections"]
	duplicate_rows[1] = (duplicate_rows[0] as Dictionary).duplicate(true)
	duplicate_projection["ordered_target_projections"] = duplicate_rows
	(
		projection_shape_rejections
		. append(
			not (
				LocomotionFacade
				. walking_host_target_projection_receipt_valid_v1(
					sdk,
					_rehash_payload_receipt_v1(sdk, duplicate_projection),
				)
			)
		)
	)

	var projection_authority_rejections := []
	for forbidden_flag in [
		"empirical_margin_added",
		"tolerance_added",
		"raw_measurement_clamped",
	]:
		var forbidden_projection: Dictionary = prefix_projection.duplicate(true)
		forbidden_projection[forbidden_flag] = true
		(
			projection_authority_rejections
			. append(
				not (
					LocomotionFacade
					. walking_host_target_projection_receipt_valid_v1(
						sdk,
						_rehash_payload_receipt_v1(sdk, forbidden_projection),
					)
				)
			)
		)
	var outcome_projection: Dictionary = prefix_projection.duplicate(true)
	outcome_projection["behavior_result"] = "passed"
	(
		projection_authority_rejections
		. append(
			not (
				LocomotionFacade
				. walking_host_target_projection_receipt_valid_v1(
					sdk,
					_rehash_payload_receipt_v1(sdk, outcome_projection),
				)
			)
		)
	)

	var unnamed_partial_projection := (
		PhysicalWorker
		. partial_arm_failure_retention_projection_v1(
			{
				"active_walking_session":
				{
					"session_id": String(walking_prefix_fixture["session_id"]),
					"start_receipt": walking_prefix_fixture["adapter_start_receipt"],
					"walking_actuation_handoff_receipt": prefix_handoff,
				},
				"last_walking_step_failure": retained_failure.duplicate(true),
			},
			EnergyInitializer.BASELINE_ARM_ID,
		)
	)
	(unnamed_partial_projection["last_walking_step_failure"] as Dictionary)["failed_predicate_ids"] = [
	]

	var changed_controller_step: Dictionary = prefix_step.duplicate(true)
	changed_controller_step["controller_policy_id"] = "mutated-policy-must-fail"
	var changed_cap_handoff: Dictionary = prefix_handoff.duplicate(true)
	var changed_cap_map: Dictionary = changed_cap_handoff["authorized_host_cap_by_actuator_id"]
	changed_cap_map[String(RecoveryRoute.ORDERED_ACTUATOR_IDS[0])] = 0.05
	changed_cap_handoff["authorized_host_cap_by_actuator_id"] = changed_cap_map
	var threshold_step: Dictionary = prefix_step.duplicate(true)
	threshold_step["acceptance_threshold"] = 0.5
	var release_handoff: Dictionary = prefix_handoff.duplicate(true)
	release_handoff["motor_enabled_count"] = LocomotionFacade.JOINT_IDS.size() - 1
	var changed_schedule_authority: Dictionary = prefix_authority.duplicate(true)
	changed_schedule_authority["semantic_step"] = 2
	var frozen_contract_rejections := [
		_l13_ledger_failure_retained_v1(
			_walking_ledger_v2_for_fixture_sources_v1(
				sdk,
				walking_prefix_fixture,
				changed_controller_step,
				prefix_authority,
				prefix_population,
				prefix_handoff,
			)
		),
		_l13_ledger_failure_retained_v1(
			_walking_ledger_v2_for_fixture_sources_v1(
				sdk,
				walking_prefix_fixture,
				prefix_step,
				prefix_authority,
				prefix_population,
				changed_cap_handoff,
			)
		),
		_l13_ledger_failure_retained_v1(
			_walking_ledger_v2_for_fixture_sources_v1(
				sdk,
				walking_prefix_fixture,
				threshold_step,
				prefix_authority,
				prefix_population,
				prefix_handoff,
			)
		),
		_l13_ledger_failure_retained_v1(
			_walking_ledger_v2_for_fixture_sources_v1(
				sdk,
				walking_prefix_fixture,
				prefix_step,
				prefix_authority,
				prefix_population,
				prefix_handoff,
				2,
			)
		),
		_l13_ledger_failure_retained_v1(
			_walking_ledger_v2_for_fixture_sources_v1(
				sdk,
				walking_prefix_fixture,
				prefix_step,
				prefix_authority,
				prefix_population,
				release_handoff,
			)
		),
		_l13_ledger_failure_retained_v1(
			_walking_ledger_v2_for_fixture_sources_v1(
				sdk,
				walking_prefix_fixture,
				prefix_step,
				changed_schedule_authority,
				prefix_population,
				prefix_handoff,
			)
		),
	]

	var controls := {
		"native_step_response_not_verified_before_json_parse_string_is_refused":
		_l13_ledger_failure_retained_v1(missing_verification_failure),
		"native_transport_verification_with_wrong_raw_response_sha256_is_refused":
		_l13_transport_mutation_refused_v1(
			sdk,
			walking_prefix_fixture,
			wrong_raw_verification,
			controller_receipt_sha256,
		),
		"native_transport_verification_with_wrong_controller_receipt_sha256_is_refused":
		_l13_transport_mutation_refused_v1(
			sdk,
			walking_prefix_fixture,
			wrong_controller_verification,
			controller_receipt_sha256,
		),
		"native_transport_verification_with_wrong_policy_or_semantic_step_is_refused":
		(
			_l13_transport_mutation_refused_v1(
				sdk,
				walking_prefix_fixture,
				wrong_policy_verification,
				controller_receipt_sha256,
			)
			and _l13_transport_mutation_refused_v1(
				sdk,
				walking_prefix_fixture,
				wrong_step_verification,
				controller_receipt_sha256,
			)
		),
		"native_transport_verification_with_any_floating_measurement_field_is_refused":
		_l13_transport_mutation_refused_v1(
			sdk,
			walking_prefix_fixture,
			floating_verification,
			controller_receipt_sha256,
		),
		"post_parse_dictionary_rehash_presented_as_native_transport_authority_is_refused":
		_l13_transport_mutation_refused_v1(
			sdk,
			walking_prefix_fixture,
			postparse_verification,
			controller_receipt_sha256,
		),
		"missing_nonfinite_or_out_of_range_controller_target_is_refused":
		_all_true_v1(target_shape_rejections),
		"binary64_controller_target_presented_as_the_host_readback_when_its_binary32_projection_differs_is_refused":
		binary64_as_host_refused,
		"adjacent_binary32_target_instead_of_the_exact_projection_is_refused":
		adjacent_binary32_refused,
		"application_and_population_target_readbacks_that_differ_are_refused":
		application_population_cross_refused,
		"projection_receipts_with_missing_extra_reordered_or_duplicate_actuators_are_refused":
		_all_true_v1(projection_shape_rejections),
		"projection_receipt_with_empirical_margin_tolerance_clamp_or_outcome_field_is_refused":
		_all_true_v1(projection_authority_rejections),
		"walking_ledger_failure_without_a_named_failed_predicate_is_refused":
		not PhysicalWorker.partial_walking_failure_retention_valid_v1(unnamed_partial_projection),
		"partial_child_failure_that_omits_any_already_observed_walking_step_source_is_refused":
		(
			(
				int(
					physical_worker_contract.get(
						"walking_ledger_failure_retention_mutation_rejection_count", -1
					)
				)
				== 15
			)
			and bool(
				(
					(
						physical_worker_contract.get(
							"walking_ledger_failure_retention_controls", {}
						)
						as Dictionary
					)
					. get("ok", false)
				)
			)
		),
		"any_change_to_controller_caps_thresholds_handoff_frequency_release_semantics_or_solver_schedule_is_refused":
		_all_true_v1(frozen_contract_rejections),
		"all_existing_l12_handoff_l11_release_l10_terminal_and_l9_process_isolation_negative_controls_still_pass":
		bool(
			physical_worker_contract.get(
				"all_existing_l12_handoff_negative_controls_still_pass", false
			)
		),
	}
	return _control_result_v1(controls)


static func _walking_ledger_v2_for_fixture_sources_v1(
	sdk: Object,
	fixture: Dictionary,
	portable_step_receipt: Dictionary,
	authority_application_receipt: Dictionary,
	motor_population_readback: Dictionary,
	walking_actuation_handoff_receipt: Dictionary,
	session_local_step: int = 1,
) -> Dictionary:
	var accepted_ledger: Dictionary = fixture.get("ledger_application_intent", {})
	return (
		LocomotionFacade
		. walking_ledger_application_intent_v2(
			sdk,
			int(accepted_ledger.get("semantic_step", -1)),
			String(fixture.get("phase", "")),
			String(fixture.get("session_id", "")),
			session_local_step,
			portable_step_receipt,
			authority_application_receipt,
			motor_population_readback,
			walking_actuation_handoff_receipt,
		)
	)


static func _l13_transport_mutation_refused_v1(
	sdk: Object,
	fixture: Dictionary,
	mutated_verification: Dictionary,
	expected_controller_receipt_sha256: String,
) -> bool:
	var portable_step: Dictionary = (fixture["portable_step_receipt"] as Dictionary).duplicate(true)
	portable_step["native_step_transport_verification"] = mutated_verification.duplicate(true)
	var ledger := _walking_ledger_v2_for_fixture_sources_v1(
		sdk,
		fixture,
		portable_step,
		fixture["authority_application_receipt"],
		fixture["motor_population_readback"],
		fixture["walking_actuation_handoff_receipt"],
	)
	return (
		not (
			AdapterScript
			. native_step_transport_verification_receipt_valid_v1(
				mutated_verification,
				LocomotionFacade.SELECTED_POLICY_ID,
				LocomotionFacade.SELECTED_CONTROLLER_RECEIPT_SCHEMA,
				1,
				expected_controller_receipt_sha256,
			)
		)
		and _l13_ledger_failure_retained_v1(ledger)
	)


static func _l13_ledger_failure_retained_v1(failure: Dictionary) -> bool:
	if (
		bool(failure.get("ok", true))
		or not (failure.get("failed_predicate_ids") is Array)
		or (failure.get("failed_predicate_ids") as Array).is_empty()
		or bool(failure.get("generic_failure_without_predicate_detail", true))
	):
		return false
	for source_key in [
		"portable_step_receipt",
		"native_step_transport_verification",
		"controller_step_receipt",
		"authority_application_receipt",
		"motor_population_readback",
		"walking_actuation_handoff_receipt",
		"host_target_projection_receipt",
		"walking_ledger_predicate_receipt",
	]:
		if not (failure.get(source_key) is Dictionary):
			return false
	var predicate_receipt: Dictionary = failure["walking_ledger_predicate_receipt"]
	return (
		predicate_receipt.get("failed_predicate_ids") is Array
		and not (predicate_receipt.get("failed_predicate_ids") as Array).is_empty()
		and predicate_receipt.get("failed_predicate_ids") == failure.get("failed_predicate_ids")
		and bool(predicate_receipt.get("all_predicates_evaluated", false))
		and not bool(predicate_receipt.get("generic_failure_without_predicate_detail", true))
	)


static func _mutated_l13_controller_target_v1(
	portable_step: Dictionary,
	row_index: int,
	target_value: float,
	erase_target: bool = false,
) -> Dictionary:
	var result: Dictionary = portable_step.duplicate(true)
	var native_output: Dictionary = result["native_output"]
	var actuation: Dictionary = native_output["actuation"]
	var commands: Array = actuation["ordered_commands"]
	var command: Dictionary = commands[row_index]
	if erase_target:
		command.erase("target_velocity_rad_s")
	else:
		command["target_velocity_rad_s"] = target_value
	commands[row_index] = command
	actuation["ordered_commands"] = commands
	native_output["actuation"] = actuation
	result["native_output"] = native_output
	return result


static func _mutated_l13_application_readback_v1(
	authority_application_receipt: Dictionary,
	row_index: int,
	target_readback: float,
) -> Dictionary:
	var result: Dictionary = authority_application_receipt.duplicate(true)
	var rows: Array = result["ordered_applications"]
	var row: Dictionary = rows[row_index]
	row["motor_target_velocity_readback_rad_s"] = target_readback
	rows[row_index] = row
	result["ordered_applications"] = rows
	return result


static func _mutated_l13_population_readback_v1(
	motor_population_readback: Dictionary,
	row_index: int,
	target_readback: float,
) -> Dictionary:
	var result: Dictionary = motor_population_readback.duplicate(true)
	var rows: Array = result["ordered_joint_readbacks"]
	var row: Dictionary = rows[row_index]
	row["motor_target_velocity_rad_s"] = target_readback
	rows[row_index] = row
	result["ordered_joint_readbacks"] = rows
	return result


static func _first_binary32_difference_row_v1(projection: Dictionary) -> int:
	var rows_value: Variant = projection.get("ordered_target_projections")
	if not (rows_value is Array):
		return -1
	var rows: Array = rows_value
	for index in range(rows.size()):
		if not (rows[index] is Dictionary):
			continue
		var row: Dictionary = rows[index]
		if (
			float(row.get("controller_binary64_target_velocity_rad_s", NAN))
			!= float(row.get("expected_binary32_host_target_velocity_rad_s", NAN))
		):
			return index
	return -1


static func _adjacent_binary32_v1(value: float) -> float:
	var bytes := PackedFloat32Array([value]).to_byte_array()
	var bits := int(bytes.decode_u32(0))
	bytes.encode_u32(0, bits + 1)
	return float(bytes.decode_float(0))


static func _rehash_payload_receipt_v1(sdk: Object, receipt: Dictionary) -> Dictionary:
	var result: Dictionary = receipt.duplicate(true)
	result["payload_sha256"] = ""
	result["payload_sha256"] = _sha256_v1(sdk, result)
	return result


static func _sha256_text_valid_v1(value: String) -> bool:
	if not value.begins_with("sha256:") or value.length() != 71:
		return false
	const HEX_DIGITS := "0123456789abcdef"
	for index in range(7, value.length()):
		if HEX_DIGITS.find(value.substr(index, 1)) < 0:
			return false
	return true


static func _measurement_bearing_key_count_v1(value: Variant) -> int:
	var count := 0
	if value is Dictionary:
		for key_value in (value as Dictionary).keys():
			var key := String(key_value)
			for suffix in ["_rad", "_rad_s", "_nms", "_m_s", "_j"]:
				count += int(key.ends_with(suffix))
			count += _measurement_bearing_key_count_v1((value as Dictionary)[key_value])
	elif value is Array:
		for child in value:
			count += _measurement_bearing_key_count_v1(child)
	return count


static func _all_true_v1(values: Array) -> bool:
	if values.is_empty():
		return false
	for value in values:
		if not bool(value):
			return false
	return true


## Immutable L12 shaped fixture retained only for predecessor compatibility and
## mutation controls. The primary L13 ledger acceptance path above uses the
## real native adapter, production handoff, and detached HingeJoint3D readbacks.
static func _walking_ledger_fixture_v1(sdk: Object, global_step: int) -> Dictionary:
	var cap_binding := LocomotionFacade.walking_host_cap_projection_binding_v1(sdk)
	if not bool(cap_binding.get("ok", false)):
		return cap_binding
	var selected_host_caps: Dictionary = cap_binding["selected_host_cap_by_actuator_id"]
	var session_id := "r10f-zero-world-walking-session"
	var handoff_reason := "l12_walking_actuation_handoff_precommand:walking_prefix"
	var configuration_rows: Array = []
	for joint_id_value in LocomotionFacade.JOINT_IDS:
		(
			configuration_rows
			. append(
				{
					"joint_id": String(joint_id_value),
					"motor_enabled": true,
					"motor_target_velocity_rad_s": 0.0,
				}
			)
		)
	var handoff_configuration := {
		"schema_version": LocomotionFacade.MOTOR_CONFIGURATION_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"global_semantic_step": global_step,
		"reason": handoff_reason,
		"motor_enabled": true,
		"ordered_joint_receipts": configuration_rows,
		"motor_configuration_write_count": LocomotionFacade.JOINT_IDS.size() * 2,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"body_impulse_write_count": 0,
		"solver_reset_count": 0,
		"physics_state_modified": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	var precommand_readback := _motor_population_fixture_v1(
		global_step,
		true,
		0.0,
		selected_host_caps,
		handoff_reason,
	)
	var handoff := (
		LocomotionFacade
		. walking_actuation_handoff_receipt_v1(
			sdk,
			"r10f-zero-world-model",
			"walking_prefix",
			"walking_prefix",
			session_id,
			global_step,
			handoff_configuration,
			precommand_readback,
			cap_binding,
		)
	)
	if not bool(handoff.get("ok", false)):
		return handoff
	var controller_receipt := {
		"schema_version": "sporespore_qsdk_r10f_zero_world_bw5r_b_controller_receipt_v1",
		"semantic_step": 1,
		"controller_policy_id": LocomotionFacade.SELECTED_POLICY_ID,
		"source_measurement": true,
	}
	var controller_receipt_sha := _sha256_v1(sdk, controller_receipt)
	var commands: Array = []
	var applications: Array = []
	for index in range(LocomotionFacade.JOINT_IDS.size()):
		var actuator_id := String(RecoveryRoute.ORDERED_ACTUATOR_IDS[index])
		var joint_id := String(LocomotionFacade.JOINT_IDS[index])
		var host_cap := float(selected_host_caps[actuator_id])
		(
			commands
			. append(
				{
					"actuator_id": actuator_id,
					"mode": "position_velocity",
					"target_velocity_rad_s": 0.5,
				}
			)
		)
		(
			applications
			. append(
				{
					"actuator_id": actuator_id,
					"joint_id": joint_id,
					"host_applied_target_velocity_rad_s": 0.5,
					"motor_target_velocity_readback_rad_s": 0.5,
					"declared_maximum_impulse_nms": host_cap,
					"target_velocity_readback_matches": true,
					"maximum_impulse_readback_matches": true,
				}
			)
		)
	var portable_step := {
		"ok": true,
		"controller_policy_id": LocomotionFacade.SELECTED_POLICY_ID,
		"controller_profile_sha256": _filled_sha256("7"),
		"controller_step_receipt_sha256": controller_receipt_sha,
		"semantic_step": 1,
		"native_output":
		{
			"actuation":
			{
				"schema_version": "sporespore_actuation_frame_v1",
				"semantic_step": 1,
				"safe_no_actuation": false,
				"ordered_commands": commands,
				"receipt": controller_receipt,
				"receipt_sha256": controller_receipt_sha,
			},
		},
	}
	var authority := {
		"schema_version": "sporespore_godot_jolt_full_authority_application_receipt_v1",
		"ok": true,
		"semantic_step": 1,
		"applied_command_count": LocomotionFacade.JOINT_IDS.size(),
		"ordered_actuator_ids": RecoveryRoute.ORDERED_ACTUATOR_IDS.duplicate(),
		"ordered_applications": applications,
		"maximum_impulse_override_applied": true,
		"authorized_maximum_impulse_by_actuator_id": selected_host_caps.duplicate(true),
		"configured_motor_parameters_only": true,
		"physical_acceptance_authority": false,
	}
	return {
		"portable_step_receipt": portable_step,
		"authority_application_receipt": authority,
		"motor_population_readback":
		_motor_population_fixture_v1(
			global_step,
			true,
			0.5,
			selected_host_caps,
			"post_bw5r_b_authority_application",
		),
		"walking_actuation_handoff_receipt": handoff,
		"walking_host_cap_projection_binding": cap_binding,
	}


static func _motor_population_fixture_v1(
	global_step: int,
	enabled: bool,
	target_velocity_rad_s: float,
	maximum_impulse_by_actuator_id: Dictionary = {},
	reason: String = "zero_world_shaped_receipt_only",
) -> Dictionary:
	var rows: Array = []
	for index in range(LocomotionFacade.JOINT_IDS.size()):
		var actuator_id := String(RecoveryRoute.ORDERED_ACTUATOR_IDS[index])
		var maximum_impulse := 0.75
		if maximum_impulse_by_actuator_id.has(actuator_id):
			maximum_impulse = float(maximum_impulse_by_actuator_id[actuator_id])
		(
			rows
			. append(
				{
					"actuator_id": actuator_id,
					"joint_id": String(LocomotionFacade.JOINT_IDS[index]),
					"motor_enabled": enabled,
					"motor_target_velocity_rad_s": target_velocity_rad_s,
					"motor_maximum_impulse_nms": maximum_impulse,
				}
			)
		)
	return {
		"schema_version": LocomotionFacade.MOTOR_POPULATION_READBACK_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"global_semantic_step": global_step,
		"reason": reason,
		"expected_motor_enabled": enabled,
		"ordered_joint_readbacks": rows,
		"motor_enabled_count": LocomotionFacade.JOINT_IDS.size() if enabled else 0,
		"zero_target_velocity_count":
		LocomotionFacade.JOINT_IDS.size() if target_velocity_rad_s == 0.0 else 0,
		"native_readback_count": LocomotionFacade.JOINT_IDS.size() * 3,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"body_impulse_write_count": 0,
		"solver_reset_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _committed_global_result_fixture_v1(
	sdk: Object,
	raw_sources: Dictionary,
	observation_base: Dictionary,
	global_step: int,
) -> Dictionary:
	var energy: Dictionary = raw_sources["energy_source_receipt"]
	var components: Dictionary = raw_sources["source_component_receipts"]
	return {
		"schema_version":
		"sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_native_bound_measurement_v1",
		"ok": true,
		"rotation_aware_energy_ledger_profile_selected": true,
		"contiguous_boundary_transport_profile_selected": true,
		"contiguous_boundary_transport_state_revision": global_step,
		"measurement":
		{
			"observation_base": observation_base.duplicate(true),
		},
		"bound":
		{
			"native_to_portable_staging_mapping":
			{
				"rotation_aware_predecessor_energy_source_receipt": energy.duplicate(true),
				"rotation_aware_predecessor_source_component_receipts": components.duplicate(true),
				"rotation_aware_predecessor_energy_source_receipt_sha256": _sha256_v1(sdk, energy),
				"rotation_aware_predecessor_source_component_receipts_sha256":
				_sha256_v1(sdk, components),
			},
		},
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _lockstep_pair_plan_v1(sdk: Object) -> Dictionary:
	var active := (
		Orchestrator
		. initialize_v1(
			sdk,
			"r10f-zero-world-lockstep-pair",
			EnergyInitializer.ACTIVE_ARM_ID,
			"r10f-active-distinct-model",
			_filled_sha256("8"),
			_filled_sha256("9"),
			0,
		)
	)
	var baseline := (
		Orchestrator
		. initialize_v1(
			sdk,
			"r10f-zero-world-lockstep-pair",
			EnergyInitializer.BASELINE_ARM_ID,
			"r10f-baseline-distinct-model",
			_filled_sha256("8"),
			_filled_sha256("0"),
			0,
		)
	)
	if not bool(active.get("ok", false)) or not bool(baseline.get("ok", false)):
		return {"ok": false, "active": active, "baseline": baseline}
	return Orchestrator.isolated_lockstep_pair_plan_v1(sdk, active["state"], baseline["state"])


static func _ledger_bridge_mutation_controls_v1(
	sdk: Object,
	walking_fixture: Dictionary,
	no_actuation_owner_source: Dictionary,
	disabled_motor_readback: Dictionary,
	active_interaction: Dictionary,
	committed_global_fixture: Dictionary,
) -> Dictionary:
	var controls := {}
	var outcome_authority: Dictionary = (
		(walking_fixture["authority_application_receipt"] as Dictionary).duplicate(true)
	)
	outcome_authority["acceptance_threshold"] = 1.0
	controls["outcome_derived_walking_authority"] = not bool(
		(
			LocomotionFacade
			. walking_ledger_application_intent_v1(
				sdk,
				EPOCH_START_GLOBAL_STEP + 1,
				"walking_prefix",
				"r10f-zero-world-walking-session",
				1,
				walking_fixture["portable_step_receipt"],
				outcome_authority,
				walking_fixture["motor_population_readback"],
				walking_fixture["walking_actuation_handoff_receipt"],
			)
			. get("ok", true)
		)
	)
	var missing_override_authority: Dictionary = (
		(walking_fixture["authority_application_receipt"] as Dictionary).duplicate(true)
	)
	missing_override_authority.erase("maximum_impulse_override_applied")
	controls["walking_authority_missing_host_cap_override"] = not bool(
		(
			LocomotionFacade
			. walking_ledger_application_intent_v1(
				sdk,
				EPOCH_START_GLOBAL_STEP + 1,
				"walking_prefix",
				"r10f-zero-world-walking-session",
				1,
				walking_fixture["portable_step_receipt"],
				missing_override_authority,
				walking_fixture["motor_population_readback"],
				walking_fixture["walking_actuation_handoff_receipt"],
			)
			. get("ok", true)
		)
	)
	var crossed_authority_cap_map: Dictionary = (
		(walking_fixture["authority_application_receipt"] as Dictionary).duplicate(true)
	)
	var crossed_authorized_caps: Dictionary = crossed_authority_cap_map["authorized_maximum_impulse_by_actuator_id"]
	crossed_authorized_caps[String(RecoveryRoute.ORDERED_ACTUATOR_IDS[0])] = 0.05
	crossed_authority_cap_map["authorized_maximum_impulse_by_actuator_id"] = (crossed_authorized_caps)
	controls["walking_authority_host_cap_map_cross"] = not bool(
		(
			LocomotionFacade
			. walking_ledger_application_intent_v1(
				sdk,
				EPOCH_START_GLOBAL_STEP + 1,
				"walking_prefix",
				"r10f-zero-world-walking-session",
				1,
				walking_fixture["portable_step_receipt"],
				crossed_authority_cap_map,
				walking_fixture["motor_population_readback"],
				walking_fixture["walking_actuation_handoff_receipt"],
			)
			. get("ok", true)
		)
	)
	var corrupted_handoff: Dictionary = (
		(walking_fixture["walking_actuation_handoff_receipt"] as Dictionary).duplicate(true)
	)
	corrupted_handoff["model_instance_id"] = "crossed-r10f-model"
	controls["walking_handoff_content_address_cross"] = not bool(
		(
			LocomotionFacade
			. walking_ledger_application_intent_v1(
				sdk,
				EPOCH_START_GLOBAL_STEP + 1,
				"walking_prefix",
				"r10f-zero-world-walking-session",
				1,
				walking_fixture["portable_step_receipt"],
				walking_fixture["authority_application_receipt"],
				walking_fixture["motor_population_readback"],
				corrupted_handoff,
			)
			. get("ok", true)
		)
	)
	var crossed_readback: Dictionary = (
		(walking_fixture["motor_population_readback"] as Dictionary).duplicate(true)
	)
	((crossed_readback["ordered_joint_readbacks"] as Array)[0] as Dictionary)["motor_target_velocity_rad_s"] = 0.75
	controls["walking_target_readback_cross"] = not bool(
		(
			LocomotionFacade
			. walking_ledger_application_intent_v1(
				sdk,
				EPOCH_START_GLOBAL_STEP + 1,
				"walking_prefix",
				"r10f-zero-world-walking-session",
				1,
				walking_fixture["portable_step_receipt"],
				walking_fixture["authority_application_receipt"],
				crossed_readback,
				walking_fixture["walking_actuation_handoff_receipt"],
			)
			. get("ok", true)
		)
	)
	var published_cap_readback: Dictionary = (
		(walking_fixture["motor_population_readback"] as Dictionary).duplicate(true)
	)
	var published_caps: Dictionary = (
		walking_fixture["walking_actuation_handoff_receipt"] as Dictionary
	)["published_cap_by_actuator_id"]
	((published_cap_readback["ordered_joint_readbacks"] as Array)[0] as Dictionary)["motor_maximum_impulse_nms"] = float(
		published_caps[String(RecoveryRoute.ORDERED_ACTUATOR_IDS[0])]
	)
	controls["walking_published_cap_substitution_after_command"] = not bool(
		(
			LocomotionFacade
			. walking_ledger_application_intent_v1(
				sdk,
				EPOCH_START_GLOBAL_STEP + 1,
				"walking_prefix",
				"r10f-zero-world-walking-session",
				1,
				walking_fixture["portable_step_receipt"],
				walking_fixture["authority_application_receipt"],
				published_cap_readback,
				walking_fixture["walking_actuation_handoff_receipt"],
			)
			. get("ok", true)
		)
	)
	var outcome_disabled := disabled_motor_readback.duplicate(true)
	outcome_disabled["recovery_success"] = true
	controls["outcome_derived_no_actuation_readback"] = not bool(
		(
			LocomotionFacade
			. no_actuation_ledger_application_intent_v1(
				sdk,
				EPOCH_START_GLOBAL_STEP,
				"interaction_effect",
				"none",
				null,
				false,
				no_actuation_owner_source,
				outcome_disabled,
				active_interaction,
			)
			. get("ok", true)
		)
	)
	var crossed_interaction := active_interaction.duplicate(true)
	crossed_interaction["completed_effect_global_step"] = EPOCH_START_GLOBAL_STEP - 1
	crossed_interaction["payload_sha256"] = EnergyInitializer._payload_sha256_v1(
		sdk, crossed_interaction
	)
	controls["crossed_interaction_global_step"] = not bool(
		(
			LocomotionFacade
			. no_actuation_ledger_application_intent_v1(
				sdk,
				EPOCH_START_GLOBAL_STEP,
				"interaction_effect",
				"none",
				null,
				false,
				no_actuation_owner_source,
				disabled_motor_readback,
				crossed_interaction,
			)
			. get("ok", true)
		)
	)
	var crossed_global := committed_global_fixture.duplicate(true)
	((crossed_global["bound"] as Dictionary)["native_to_portable_staging_mapping"] as Dictionary)["rotation_aware_predecessor_energy_source_receipt_sha256"] = _filled_sha256(
		"e"
	)
	controls["crossed_retained_r162_source_digest"] = not bool(
		(
			NativeEpochRoute
			. project_committed_global_result_v1(sdk, crossed_global, EPOCH_START_GLOBAL_STEP + 1)
			. get("ok", true)
		)
	)
	var valid_lockstep := _lockstep_pair_plan_v1(sdk)
	var crossed_lockstep_state: Dictionary = (valid_lockstep["plan"] as Dictionary).duplicate(true)
	controls["lockstep_plan_is_content_addressed"] = (
		String(crossed_lockstep_state.get("payload_sha256", ""))
		== String(valid_lockstep.get("plan_sha256", ""))
	)
	return _control_result_v1(controls)


static func _transport_mutation_controls_v1(
	sdk: Object, state_e: Dictionary, state_e1: Dictionary, pair_e1: Dictionary
) -> Dictionary:
	var controls := {}
	controls["invalid_interaction_digest"] = not bool(
		(
			EpochTransport
			. initialize_epoch_transport_v1(sdk, state_e["cached_completed_boundary"], "bad")
			. get("ok", true)
		)
	)
	var duplicate_build := _completed_boundary_v1(
		sdk,
		EnergyInitializer.ACTIVE_ARM_ID,
		EPOCH_START_GLOBAL_STEP + 1,
		"r10f-distinct-duplicate-global-509",
	)
	controls["duplicate_global_boundary"] = _failure_exact_v1(
		EpochTransport.advance_epoch_transport_v1(sdk, state_e1, duplicate_build["boundary"]),
		"QSDK_R10F_EPOCH_DUPLICATE_GLOBAL_BOUNDARY",
	)
	var stale_build := _completed_boundary_v1(
		sdk,
		EnergyInitializer.ACTIVE_ARM_ID,
		EPOCH_START_GLOBAL_STEP,
		"r10f-distinct-stale-global-508",
	)
	controls["stale_global_boundary"] = _failure_exact_v1(
		EpochTransport.advance_epoch_transport_v1(sdk, state_e1, stale_build["boundary"]),
		"QSDK_R10F_EPOCH_STALE_GLOBAL_BOUNDARY",
	)
	var skipped_build := _completed_boundary_v1(
		sdk,
		EnergyInitializer.ACTIVE_ARM_ID,
		EPOCH_START_GLOBAL_STEP + 3,
		"r10f-skipped-global-511",
	)
	controls["skipped_global_boundary"] = _failure_exact_v1(
		EpochTransport.advance_epoch_transport_v1(sdk, state_e1, skipped_build["boundary"]),
		"QSDK_R10F_EPOCH_SKIPPED_GLOBAL_BOUNDARY",
	)
	var crossed_build := _completed_boundary_v1(
		sdk,
		EnergyInitializer.BASELINE_ARM_ID,
		EPOCH_START_GLOBAL_STEP + 1,
		"r10f-crossed-arm-509",
	)
	controls["crossed_arm_boundary"] = _failure_exact_v1(
		EpochTransport.advance_epoch_transport_v1(sdk, state_e, crossed_build["boundary"]),
		"QSDK_R10F_EPOCH_CROSSED_IDENTITY:arm_id",
	)
	var outcome_derived := pair_e1.duplicate(true)
	outcome_derived["recovery_success"] = true
	outcome_derived["payload_sha256"] = EpochTransport._payload_sha256_v1(sdk, outcome_derived)
	controls["outcome_derived_pair_field"] = not EpochTransport.pair_valid_v1(sdk, outcome_derived)
	return _control_result_v1(controls)


static func _energy_mutation_controls_v1(
	sdk: Object,
	state_e: Dictionary,
	raw_sources_e: Dictionary,
	global_accumulator_e: Dictionary,
	active_interaction: Dictionary,
	baseline_interaction: Dictionary,
) -> Dictionary:
	var controls := {}
	var wrong_sequence_energy: Dictionary = (
		(raw_sources_e["energy_source_receipt"] as Dictionary).duplicate(true)
	)
	wrong_sequence_energy["semantic_step"] = EPOCH_START_GLOBAL_STEP - 1
	controls["source_sequence_cross"] = not bool(
		(
			EnergyInitializer
			. initialize_energy_epoch_v1(
				sdk,
				state_e,
				wrong_sequence_energy,
				raw_sources_e["source_component_receipts"],
				global_accumulator_e,
				active_interaction,
			)
			. get("ok", true)
		)
	)
	var wrong_accumulator := global_accumulator_e.duplicate(true)
	wrong_accumulator["event_count"] = EPOCH_START_GLOBAL_STEP - 1
	controls["global_staging_count_cross"] = not bool(
		(
			EnergyInitializer
			. initialize_energy_epoch_v1(
				sdk,
				state_e,
				raw_sources_e["energy_source_receipt"],
				raw_sources_e["source_component_receipts"],
				wrong_accumulator,
				active_interaction,
			)
			. get("ok", true)
		)
	)
	var wrong_components: Dictionary = (
		(raw_sources_e["source_component_receipts"] as Dictionary).duplicate(true)
	)
	wrong_components["solver_coupled_partition_receipt_sha256"] = _filled_sha256("0")
	controls["partition_receipt_digest_cross"] = not bool(
		(
			EnergyInitializer
			. initialize_energy_epoch_v1(
				sdk,
				state_e,
				raw_sources_e["energy_source_receipt"],
				wrong_components,
				global_accumulator_e,
				active_interaction,
			)
			. get("ok", true)
		)
	)
	controls["active_state_with_baseline_interaction"] = not bool(
		(
			EnergyInitializer
			. initialize_energy_epoch_v1(
				sdk,
				state_e,
				raw_sources_e["energy_source_receipt"],
				raw_sources_e["source_component_receipts"],
				global_accumulator_e,
				baseline_interaction,
			)
			. get("ok", true)
		)
	)
	var subthreshold_effect := (
		EnergyInitializer
		. build_interaction_receipt_v1(
			sdk,
			ATTEMPT_ID,
			EnergyInitializer.ACTIVE_ARM_ID,
			MODEL_INSTANCE_ID,
			EPOCH_START_GLOBAL_STEP,
			EPOCH_START_GLOBAL_STEP,
			0.00001,
			_filled_sha256("e"),
		)
	)
	controls["active_native_effect_below_floor"] = not bool(subthreshold_effect.get("ok", true))
	return _control_result_v1(controls)


static func _staging_mutation_controls_v1(
	sdk: Object,
	raw_sources_e1: Dictionary,
	observer_e1: Dictionary,
	epoch_accumulator: Dictionary,
	initializer: Dictionary,
	bound_e1: Dictionary,
) -> Dictionary:
	var controls := {}
	var stale_accumulator := epoch_accumulator.duplicate(true)
	stale_accumulator["global_sequence"] = EPOCH_START_GLOBAL_STEP - 1
	controls["stale_epoch_accumulator"] = not bool(
		(
			EpochStagingRoute
			. map_epoch_step_v1(
				sdk,
				raw_sources_e1["energy_source_receipt"],
				raw_sources_e1["source_component_receipts"],
				observer_e1,
				stale_accumulator,
				initializer,
			)
			. get("ok", true)
		)
	)
	var outcome_observer := observer_e1.duplicate(true)
	outcome_observer["acceptance_threshold"] = 1.0
	controls["outcome_derived_observer_field"] = not bool(
		(
			EpochStagingRoute
			. map_epoch_step_v1(
				sdk,
				raw_sources_e1["energy_source_receipt"],
				raw_sources_e1["source_component_receipts"],
				outcome_observer,
				epoch_accumulator,
				initializer,
			)
			. get("ok", true)
		)
	)
	var crossed_initializer := initializer.duplicate(true)
	crossed_initializer["epoch_start_global_step"] = EPOCH_START_GLOBAL_STEP - 1
	crossed_initializer["payload_sha256"] = EnergyInitializer._payload_sha256_v1(
		sdk, crossed_initializer
	)
	controls["crossed_epoch_initializer"] = not bool(
		(
			EpochStagingRoute
			. map_epoch_step_v1(
				sdk,
				raw_sources_e1["energy_source_receipt"],
				raw_sources_e1["source_component_receipts"],
				observer_e1,
				epoch_accumulator,
				crossed_initializer,
			)
			. get("ok", true)
		)
	)
	var crossed_binding := bound_e1.duplicate(true)
	(crossed_binding["source_binding"] as Dictionary)["source_route_id"] = "crossed-route"
	var crossed_route := (
		RecoveryRoute
		. collect_and_plan_v1(
			sdk,
			RecoveryRoute.prepare_complete_energy_context_v18(
				sdk, RecoveryRoute.RECOVERY_CONTROLLER_V6_ID
			),
			crossed_binding,
			"establish_distal_support",
			0,
		)
	)
	controls["portable_source_route_cross"] = not bool(crossed_route.get("ok", true))
	return _control_result_v1(controls)


static func _impulse_pair_source_fixture_v1() -> Dictionary:
	return {
		"attempt_id": ATTEMPT_ID,
		"completed_effect_global_step": EPOCH_START_GLOBAL_STEP,
		"active_model_instance_id": MODEL_INSTANCE_ID,
		"baseline_model_instance_id": BASELINE_MODEL_INSTANCE_ID,
		"active_prefix_session_id": "r10f-zero-world-active-prefix-session",
		"baseline_prefix_session_id": "r10f-zero-world-baseline-prefix-session",
		"active_prefix_session_receipt_sha256": _filled_sha256("a"),
		"baseline_prefix_session_receipt_sha256": _filled_sha256("b"),
		"active_task_frame_forward_axis_world_host_real": [0.0, 0.0, -1.0],
		"active_task_frame_lateral_axis_world_host_real": [1.0, 0.0, 0.0],
		"baseline_task_frame_forward_axis_world_host_real": [0.0, 0.0, -1.0],
		"baseline_task_frame_lateral_axis_world_host_real": [1.0, 0.0, 0.0],
		"active_impulse_world_n_s": [0.25, 0.0, 0.0],
		"active_pre_application_velocity_world_m_s": [0.1, 0.0, 0.0],
		"active_completed_effect_velocity_world_m_s": [0.1125, 0.0, 0.0],
		"baseline_pre_event_velocity_world_m_s": [0.1, 0.0, 0.0],
		"baseline_completed_effect_velocity_world_m_s": [0.102, 0.0, 0.0],
		"active_application_count": 1,
		"baseline_application_count": 0,
	}


static func _impulse_pair_mutation_controls_v1(
	sdk: Object,
	valid_source: Dictionary,
) -> Dictionary:
	var controls := {}
	var zero_step := valid_source.duplicate(true)
	zero_step["completed_effect_global_step"] = 0
	controls["nonpositive_global_step_refused"] = not bool(
		ImpulsePairReceipt.build_pair_receipt_v1(sdk, zero_step).get("ok", true)
	)
	var active_count := valid_source.duplicate(true)
	active_count["active_application_count"] = 0
	controls["missing_active_application_refused"] = not bool(
		ImpulsePairReceipt.build_pair_receipt_v1(sdk, active_count).get("ok", true)
	)
	var baseline_count := valid_source.duplicate(true)
	baseline_count["baseline_application_count"] = 1
	controls["baseline_application_refused"] = not bool(
		ImpulsePairReceipt.build_pair_receipt_v1(sdk, baseline_count).get("ok", true)
	)
	var wrong_impulse := valid_source.duplicate(true)
	wrong_impulse["active_impulse_world_n_s"] = [0.2, 0.0, 0.0]
	controls["changed_impulse_magnitude_refused"] = not bool(
		ImpulsePairReceipt.build_pair_receipt_v1(sdk, wrong_impulse).get("ok", true)
	)
	var crossed_axis := valid_source.duplicate(true)
	crossed_axis["baseline_task_frame_forward_axis_world_host_real"] = [0.0, 0.0, 1.0]
	controls["crossed_prefix_task_frame_refused"] = not bool(
		ImpulsePairReceipt.build_pair_receipt_v1(sdk, crossed_axis).get("ok", true)
	)
	var below_floor := valid_source.duplicate(true)
	below_floor["active_completed_effect_velocity_world_m_s"] = [0.10205, 0.0, 0.0]
	controls["paired_effect_below_frozen_floor_refused"] = not bool(
		ImpulsePairReceipt.build_pair_receipt_v1(sdk, below_floor).get("ok", true)
	)
	var same_model := valid_source.duplicate(true)
	same_model["baseline_model_instance_id"] = String(valid_source["active_model_instance_id"])
	controls["same_model_label_for_two_worlds_refused"] = not bool(
		ImpulsePairReceipt.build_pair_receipt_v1(sdk, same_model).get("ok", true)
	)
	var outcome_derived := valid_source.duplicate(true)
	outcome_derived["recovery_success"] = true
	controls["outcome_derived_extra_field_refused"] = not bool(
		ImpulsePairReceipt.build_pair_receipt_v1(sdk, outcome_derived).get("ok", true)
	)
	return _control_result_v1(controls)


static func _orchestrator_path_v1(sdk: Object, arm_id: String) -> Dictionary:
	var initialized := (
		Orchestrator
		. initialize_v1(
			sdk,
			"r10f-orchestrator-%s" % arm_id,
			arm_id,
			"r10f-same-body-population",
			_filled_sha256("f"),
			_filled_sha256("1"),
			0,
		)
	)
	if not bool(initialized.get("ok", false)):
		return initialized
	var state: Dictionary = initialized["state"]
	var advanced := _advance_fields_v1(
		sdk,
		state,
		{
			"event_kind": "recovery_controller_step",
			"global_semantic_step": 1,
			"control_owner": "recovery_v6",
			"actuation_owner": "none",
			"no_actuation_requested": true,
			"application_intent_sha256": _filled_sha256("7"),
		},
	)
	if not bool(advanced.get("ok", false)):
		return advanced
	state = advanced["state_after"]
	advanced = _advance_fields_v1(
		sdk,
		state,
		{
			"event_kind": "precondition_pair_ready",
			"global_semantic_step": int(state["previous_global_semantic_step"]) + 1,
			"control_owner": "recovery_v6",
			"actuation_owner": "recovery_v6",
			"recovery_actuation_applied": true,
			"application_intent_sha256": _filled_sha256("8"),
			"stable_four_foot_stance": true,
			"recovery_controller_terminal_phase": "complete",
		},
	)
	if not bool(advanced.get("ok", false)):
		return advanced
	state = advanced["state_after"]
	advanced = _advance_fields_v1(
		sdk,
		state,
		{
			"event_kind": "precondition_pair_release_step",
			"global_semantic_step": int(state["previous_global_semantic_step"]) + 1,
			"control_owner": "none",
			"actuation_owner": "none",
			"no_actuation_requested": true,
			"application_intent_sha256": _filled_sha256("6"),
		},
	)
	if not bool(advanced.get("ok", false)):
		return advanced
	state = advanced["state_after"]
	for local_step in range(1, Orchestrator.WALKING_PREFIX_STEPS + 1):
		advanced = _advance_fields_v1(
			sdk,
			state,
			{
				"event_kind": "walking_policy_step",
				"global_semantic_step": int(state["previous_global_semantic_step"]) + 1,
				"control_owner": "walking_bw5r_b",
				"actuation_owner": "walking_bw5r_b",
				"application_intent_sha256": _filled_sha256("9"),
				"walking_session_id": "r10f-prefix-session-%s" % arm_id,
				"walking_session_local_step": local_step,
				"walking_actuation_applied": true,
			},
		)
		if not bool(advanced.get("ok", false)):
			return advanced
		state = advanced["state_after"]
	advanced = _advance_fields_v1(
		sdk,
		state,
		{
			"event_kind":
			(
				"kick_effect_step"
				if arm_id == EnergyInitializer.ACTIVE_ARM_ID
				else "matched_no_kick_effect_step"
			),
			"global_semantic_step": int(state["previous_global_semantic_step"]) + 1,
			"control_owner": "none",
			"actuation_owner": "none",
			"no_actuation_requested": true,
			"application_intent_sha256": _filled_sha256("a"),
			"interaction_receipt_sha256": _filled_sha256("2"),
			"energy_initializer_sha256": _filled_sha256("3"),
			"kick_application_count": 1 if arm_id == EnergyInitializer.ACTIVE_ARM_ID else 0,
			"walking_motors_disabled_in_same_pre_solver_event": true,
		},
	)
	if not bool(advanced.get("ok", false)):
		return advanced
	state = advanced["state_after"]
	var remaining_equal_horizon_steps := (
		Orchestrator.REQUIRED_CONSECUTIVE_PRONE_SAMPLES + 2 + Orchestrator.WALKING_RESUME_STEPS
	)
	if arm_id == EnergyInitializer.ACTIVE_ARM_ID:
		for _sample_index in range(Orchestrator.REQUIRED_CONSECUTIVE_PRONE_SAMPLES):
			advanced = _advance_fields_v1(
				sdk,
				state,
				{
					"event_kind": "passive_prone_observation",
					"global_semantic_step": int(state["previous_global_semantic_step"]) + 1,
					"recovery_epoch_local_step": int(state["recovery_epoch_step_count"]) + 1,
					"control_owner": "recovery_v6",
					"actuation_owner": "none",
					"no_actuation_requested": true,
					"application_intent_sha256": _filled_sha256("b"),
					"prone_sample": true,
					"energy_initializer_sha256": _filled_sha256("3"),
				},
			)
			if not bool(advanced.get("ok", false)):
				return advanced
			state = advanced["state_after"]
		advanced = _advance_fields_v1(
			sdk,
			state,
			{
				"event_kind": "recovery_controller_step",
				"global_semantic_step": int(state["previous_global_semantic_step"]) + 1,
				"recovery_epoch_local_step": int(state["recovery_epoch_step_count"]) + 1,
				"control_owner": "recovery_v6",
				"actuation_owner": "none",
				"no_actuation_requested": true,
				"application_intent_sha256": _filled_sha256("c"),
				"energy_initializer_sha256": _filled_sha256("3"),
			},
		)
		if not bool(advanced.get("ok", false)):
			return advanced
		state = advanced["state_after"]
		advanced = _advance_fields_v1(
			sdk,
			state,
			{
				"event_kind": "recovery_controller_step",
				"global_semantic_step": int(state["previous_global_semantic_step"]) + 1,
				"recovery_epoch_local_step": int(state["recovery_epoch_step_count"]) + 1,
				"control_owner": "recovery_v6",
				"actuation_owner": "recovery_v6",
				"recovery_actuation_applied": true,
				"application_intent_sha256": _filled_sha256("d"),
				"stable_four_foot_stance": true,
				"recovery_controller_terminal_phase": "complete",
				"energy_initializer_sha256": _filled_sha256("3"),
			},
		)
		if not bool(advanced.get("ok", false)):
			return advanced
		state = advanced["state_after"]
		var same_session_control := _advance_fields_v1(
			sdk,
			state,
			{
				"event_kind": "walking_policy_step",
				"global_semantic_step": int(state["previous_global_semantic_step"]) + 1,
				"recovery_epoch_local_step": int(state["recovery_epoch_step_count"]) + 1,
				"control_owner": "walking_bw5r_b",
				"actuation_owner": "walking_bw5r_b",
				"application_intent_sha256": _filled_sha256("e"),
				"walking_session_id": "r10f-prefix-session-%s" % arm_id,
				"walking_session_local_step": 1,
				"walking_actuation_applied": true,
			},
		)
		if bool(same_session_control.get("ok", true)):
			return {"ok": false, "failure_code": "QSDK_R10F_SAME_SESSION_RESUME_ACCEPTED"}
		for local_step in range(1, Orchestrator.WALKING_RESUME_STEPS + 1):
			advanced = _advance_fields_v1(
				sdk,
				state,
				{
					"event_kind": "walking_policy_step",
					"global_semantic_step": int(state["previous_global_semantic_step"]) + 1,
					"recovery_epoch_local_step": int(state["recovery_epoch_step_count"]) + 1,
					"control_owner": "walking_bw5r_b",
					"actuation_owner": "walking_bw5r_b",
					"application_intent_sha256": _filled_sha256("f"),
					"walking_session_id": "r10f-resume-session-active",
					"walking_session_local_step": local_step,
					"walking_actuation_applied": true,
				},
			)
			if not bool(advanced.get("ok", false)):
				return advanced
			state = advanced["state_after"]
	else:
		for local_step in range(1, remaining_equal_horizon_steps + 1):
			advanced = _advance_fields_v1(
				sdk,
				state,
				{
					"event_kind": "matched_continuation_step",
					"global_semantic_step": int(state["previous_global_semantic_step"]) + 1,
					"recovery_epoch_local_step": int(state["recovery_epoch_step_count"]) + 1,
					"control_owner": "walking_bw5r_b",
					"actuation_owner": "walking_bw5r_b",
					"application_intent_sha256": _filled_sha256("1"),
					"walking_session_id": "r10f-continuation-session-baseline",
					"walking_session_local_step": local_step,
					"walking_actuation_applied": true,
					"recovery_controller_terminal_phase":
					"complete" if local_step == remaining_equal_horizon_steps else "",
				},
			)
			if not bool(advanced.get("ok", false)):
				return advanced
			state = advanced["state_after"]
	return {
		"ok": String(state.get("phase", "")) == Orchestrator.PHASE_COMPLETE,
		"terminal_state": state,
		"same_prefix_session_resume_rejected": true,
	}


static func _orchestrator_mutation_controls_v1(sdk: Object) -> Dictionary:
	var initialized := (
		Orchestrator
		. initialize_v1(
			sdk,
			"r10f-orchestrator-negative-controls",
			EnergyInitializer.ACTIVE_ARM_ID,
			"r10f-negative-control-population",
			_filled_sha256("4"),
			_filled_sha256("5"),
			0,
		)
	)
	if not bool(initialized.get("ok", false)):
		return {"ok": false, "rejection_count": 0, "initialization": initialized}
	var state: Dictionary = initialized["state"]
	var valid_fields := {
		"event_kind": "precondition_pair_ready",
		"global_semantic_step": 1,
		"control_owner": "recovery_v6",
		"actuation_owner": "recovery_v6",
		"recovery_actuation_applied": true,
		"application_intent_sha256": _filled_sha256("7"),
		"stable_four_foot_stance": true,
		"recovery_controller_terminal_phase": "complete",
	}
	var controls := {}
	var duplicate_fields := valid_fields.duplicate(true)
	duplicate_fields["global_semantic_step"] = 0
	controls["duplicate_global_step"] = not bool(
		_advance_fields_v1(sdk, state, duplicate_fields).get("ok", true)
	)
	var force_aware_fields := valid_fields.duplicate(true)
	force_aware_fields["force_aware_recovery"] = true
	controls["force_aware_recovery_forbidden"] = not bool(
		_advance_fields_v1(sdk, state, force_aware_fields).get("ok", true)
	)
	var rebuild_fields := valid_fields.duplicate(true)
	rebuild_fields["body_population_rebuild_count"] = 1
	controls["body_population_rebuild_forbidden"] = not bool(
		_advance_fields_v1(sdk, state, rebuild_fields).get("ok", true)
	)
	var transform_fields := valid_fields.duplicate(true)
	transform_fields["body_transform_write_count"] = 1
	controls["post_construction_transform_write_forbidden"] = not bool(
		_advance_fields_v1(sdk, state, transform_fields).get("ok", true)
	)
	var dishonest_recovery_fields := valid_fields.duplicate(true)
	dishonest_recovery_fields["actuation_owner"] = "none"
	dishonest_recovery_fields["no_actuation_requested"] = true
	controls["recovery_actuation_claim_requires_recovery_actuation_owner"] = not bool(
		_advance_fields_v1(sdk, state, dishonest_recovery_fields).get("ok", true)
	)
	var missing_no_actuation_fields := valid_fields.duplicate(true)
	missing_no_actuation_fields["actuation_owner"] = "none"
	missing_no_actuation_fields["recovery_actuation_applied"] = false
	controls["none_actuation_owner_requires_explicit_no_actuation"] = not bool(
		_advance_fields_v1(sdk, state, missing_no_actuation_fields).get("ok", true)
	)
	var crossed_control_owner_fields := valid_fields.duplicate(true)
	crossed_control_owner_fields["control_owner"] = "none"
	controls["recovery_phase_requires_recovery_control_owner"] = not bool(
		_advance_fields_v1(sdk, state, crossed_control_owner_fields).get("ok", true)
	)
	var missing_application_intent_fields := valid_fields.duplicate(true)
	missing_application_intent_fields["application_intent_sha256"] = ""
	controls["application_intent_digest_required"] = not bool(
		_advance_fields_v1(sdk, state, missing_application_intent_fields).get("ok", true)
	)
	var failed_without_reason_fields := valid_fields.duplicate(true)
	failed_without_reason_fields["stable_four_foot_stance"] = false
	failed_without_reason_fields["recovery_controller_terminal_phase"] = "failed"
	controls["failed_recovery_requires_terminal_reason"] = not bool(
		_advance_fields_v1(sdk, state, failed_without_reason_fields).get("ok", true)
	)
	var reason_without_failure_fields := valid_fields.duplicate(true)
	reason_without_failure_fields["recovery_controller_terminal_reason"] = "unexpected"
	controls["terminal_reason_requires_failed_or_refused_phase"] = not bool(
		_advance_fields_v1(sdk, state, reason_without_failure_fields).get("ok", true)
	)
	var crossed_initialized := (
		Orchestrator
		. initialize_v1(
			sdk,
			"r10f-orchestrator-negative-controls",
			EnergyInitializer.ACTIVE_ARM_ID,
			"r10f-negative-control-population",
			_filled_sha256("6"),
			_filled_sha256("5"),
			0,
		)
	)
	var crossed_event_build := Orchestrator.build_event_v1(
		sdk, crossed_initialized["state"], valid_fields
	)
	controls["frozen_configuration_cross"] = not bool(
		Orchestrator.advance_v1(sdk, state, crossed_event_build["event"]).get("ok", true)
	)
	return _control_result_v1(controls)


static func _orchestrator_behavioral_failure_path_v1(sdk: Object) -> Dictionary:
	var initialized := (
		Orchestrator
		. initialize_v1(
			sdk,
			"r10f-orchestrator-valid-negative",
			EnergyInitializer.ACTIVE_ARM_ID,
			"r10f-valid-negative-population",
			_filled_sha256("4"),
			_filled_sha256("5"),
			0,
		)
	)
	if not bool(initialized.get("ok", false)):
		return initialized
	var advanced := _advance_fields_v1(
		sdk,
		initialized["state"],
		{
			"event_kind": "recovery_controller_step",
			"global_semantic_step": 1,
			"control_owner": "recovery_v6",
			"actuation_owner": "none",
			"no_actuation_requested": true,
			"application_intent_sha256": _filled_sha256("7"),
			"recovery_controller_terminal_phase": "failed",
			"recovery_controller_terminal_reason": "phase_timeout:establish_distal_support",
		},
	)
	var terminal: Dictionary = advanced.get("state_after", {})
	return {
		"ok":
		(
			bool(advanced.get("ok", false))
			and String(terminal.get("phase", "")) == Orchestrator.PHASE_FAILED
			and String(terminal.get("terminal_outcome", "")) == "failed"
			and (
				String(terminal.get("terminal_reason", ""))
				== "phase_timeout:establish_distal_support"
			)
		),
		"terminal_state": terminal,
	}


static func _advance_fields_v1(sdk: Object, state: Dictionary, fields: Dictionary) -> Dictionary:
	var built := Orchestrator.build_event_v1(sdk, state, fields)
	if not bool(built.get("ok", false)):
		return built
	return Orchestrator.advance_v1(sdk, state, built["event"])


static func _control_result_v1(controls: Dictionary) -> Dictionary:
	var rejection_count := 0
	for value in controls.values():
		rejection_count += int(bool(value))
	return {
		"ok": rejection_count == controls.size(),
		"rejection_count": rejection_count,
		"expected_rejection_count": controls.size(),
		"controls": controls,
	}


static func _failure_exact_v1(value: Dictionary, expected_code: String) -> bool:
	return (
		not bool(value.get("ok", true))
		and String(value.get("failure_code", "")) == expected_code
		and int(value.get("model_construction_count", -1)) == 0
		and int(value.get("world_attempt_count", -1)) == 0
		and int(value.get("world_build_count", -1)) == 0
		and int(value.get("solver_step_count", -1)) == 0
		and not bool(value.get("physics_state_modified", true))
	)


static func _sha256_v1(sdk: Object, value: Variant) -> String:
	return String(RecoveryRuntimeScript.canonicalize(sdk, value).get("sha256", ""))


static func _filled_sha256(character: String) -> String:
	return "sha256:" + character.repeat(64)


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10f_continuous_passive_recovery_zero_world_v1",
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"positive_case_count": 0,
		"forced_failure_case_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_declared": true,
		"physical_question_opened": false,
		"physical_execution_authorized": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
