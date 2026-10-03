extends SceneTree
# gdlint: disable=max-line-length

## One finite exact-nominal paired Godot/Jolt recovery development question.
## Candidate and matched-zero arms use separate genuine native worlds, the
## versioned portable supervisor/evaluator, and at most 1,200 steps each.
## Any valid positive, negative, or incomplete evaluator outcome is retained;
## only route, integration, evidence, or evaluator invalidity fails the worker.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const NativeWorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const RAW_MARKER := "QSDK_R24D65_GODOT_NATIVE_RECOVERY_BEHAVIOR_RAW "
const READY_MARKER := "QSDK_R24D65_GODOT_SUPERVISOR_TERMINATION_READY "
const TERMINATION_PROTOCOL_ID := "godot_4_7_gdscript_shutdown_containment_v1"
const AUTHORIZATION_ENV := "SPORESPORE_R24D65_PHYSICAL_AUTHORIZATION_SHA256"
const SOURCE_COMMIT_ENV := "SPORESPORE_R24D65_SOURCE_COMMIT"
const ATTEMPT_ID_ENV := "SPORESPORE_R24D65_ATTEMPT_ID"
const SUPERVISED_ENV := "SPORESPORE_R24D65_SUPERVISED_TERMINATION"
const NONCE_ENV := "SPORESPORE_R24D65_TERMINATION_NONCE"
const GENERIC_AUTHORIZATION_ENV := "SPORESPORE_GODOT_RECOVERY_AUTHORIZATION_SHA256"
const GENERIC_SOURCE_COMMIT_ENV := "SPORESPORE_GODOT_RECOVERY_SOURCE_COMMIT"
const GENERIC_ATTEMPT_ID_ENV := "SPORESPORE_GODOT_RECOVERY_ATTEMPT_ID"
const GENERIC_SUPERVISED_ENV := "SPORESPORE_GODOT_RECOVERY_SUPERVISED_TERMINATION"
const GENERIC_NONCE_ENV := "SPORESPORE_GODOT_RECOVERY_TERMINATION_NONCE"
const GENERIC_GATE_ID_ENV := "SPORESPORE_GODOT_RECOVERY_GATE_ID"
const GENERIC_GATE_TOKEN_ENV := "SPORESPORE_GODOT_RECOVERY_GATE_TOKEN"
const GENERIC_RAW_SCHEMA_ENV := "SPORESPORE_GODOT_RECOVERY_RAW_SCHEMA"
const GENERIC_WORK_ID_ENV := "SPORESPORE_GODOT_RECOVERY_WORK_ID"
const GENERIC_RAW_MARKER_ENV := "SPORESPORE_GODOT_RECOVERY_RAW_MARKER"
const GENERIC_READY_MARKER_ENV := "SPORESPORE_GODOT_RECOVERY_READY_MARKER"
const GENERIC_PROGRESS_MARKER_ENV := "SPORESPORE_GODOT_RECOVERY_PROGRESS_MARKER"
const GENERIC_PROGRESS_CADENCE_ENV := "SPORESPORE_GODOT_RECOVERY_PROGRESS_CADENCE_STEPS"
const GENERIC_SEED_ENV := "SPORESPORE_GODOT_RECOVERY_SEED"
const GENERIC_SEED_LABEL_ENV := "SPORESPORE_GODOT_RECOVERY_SEED_LABEL"
const GENERIC_SEED_SHA_ENV := "SPORESPORE_GODOT_RECOVERY_SEED_SHA256"
const GENERIC_ACTUATOR_MODE_ENV := "SPORESPORE_GODOT_RECOVERY_ACTUATOR_MODE"
const GENERIC_CONTROLLER_ID_ENV := "SPORESPORE_GODOT_RECOVERY_CONTROLLER_ID"
const GENERIC_ENERGY_ROUTE_ID_ENV := "SPORESPORE_GODOT_RECOVERY_ENERGY_ROUTE_ID"
const ACTUATOR_MODE_LEGACY := "legacy_velocity_motor_v1"
const ACTUATOR_MODE_SOLVER_COUPLED := "solver_coupled_native_constraint_motor_v1"
const ACTUATOR_MODE_FORCE_BASED := "force_based_joint_impulse_v1"
const R131_PRODUCTION_ADVANCE_DISPATCH_ID := "godot_jolt_r24d131_versioned_recovery_progression_dispatch_v1"
const R134_PRODUCTION_EVALUATION_DISPATCH_ID := "godot_jolt_r24d134_versioned_recovery_evaluation_dispatch_v1"
const R137_PRODUCTION_ADVANCE_DISPATCH_ID := "godot_jolt_r24d137_complete_energy_recovery_progression_dispatch_v1"
const R137_PRODUCTION_EVALUATION_DISPATCH_ID := "godot_jolt_r24d137_complete_energy_recovery_evaluation_dispatch_v1"
const R146_PRODUCTION_ADVANCE_DISPATCH_ID := "godot_jolt_r24d146_solver_coupled_complete_energy_recovery_progression_dispatch_v1"
const R146_PRODUCTION_EVALUATION_DISPATCH_ID := "godot_jolt_r24d146_solver_coupled_complete_energy_recovery_evaluation_dispatch_v1"
const R151_PRODUCTION_ADVANCE_DISPATCH_ID := "godot_jolt_r24d151_commissioned_discrete_staging_recovery_progression_dispatch_v1"
const R151_PRODUCTION_EVALUATION_DISPATCH_ID := "godot_jolt_r24d151_commissioned_discrete_staging_recovery_evaluation_dispatch_v1"
const ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED := "force_based_nested_native_angular_velocity_guarded_v1"
const ACTUATOR_MODE_FORCE_BASED_COMPONENT_NORM_NESTED_GUARDED := "force_based_component_norm_nested_native_angular_velocity_guarded_v1"
const ACTUATOR_MODE_FORCE_BASED_REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED := "force_based_refinement_safe_component_norm_nested_native_angular_velocity_guarded_v1"
const ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED := "force_based_order_neutral_population_native_angular_velocity_guarded_v1"
const ACTUATOR_MODE_FORCE_BASED_JOINT_TARGET_MONOTONE_POPULATION_GUARDED := "force_based_order_neutral_joint_target_monotone_population_native_angular_velocity_guarded_v2"
const ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED := "force_based_order_neutral_joint_space_effective_inertia_native_angular_velocity_guarded_v3"
const PHYSICS_HZ := 120
const MAXIMUM_OUTER_STEPS_PER_ARM := 1200
const MAXIMUM_TOTAL_OUTER_STEPS := 2400
const ARM_ORDER := ["candidate_command", "matched_zero_command"]
const TERMINAL_PHASES := ["complete", "failed", "refused"]
const EXIT_DRAIN_PROCESS_FRAME_COUNT := 2
const PROGRESS_PROTOCOL_ID := "godot_4_7_gdscript_non_evidentiary_progress_v1"
const DEFAULT_SEED := 260226999
const DEFAULT_SEED_LABEL := "QSDK-R24D65/development/godot/exact-nominal-paired-v1"
const DEFAULT_SEED_SHA256 := "sha256:0017cfd5c0c9868607a4655bb89fc74d2f3bfda437aac974b8ac928b5b69b4e7"

var _sdk: Object
var _context: Dictionary = {}
var _model: Dictionary = {}
var _memory: Dictionary = {}
var _application_intent: Dictionary = {}
var _initialization_receipt: Dictionary = {}
var _initial_application: Dictionary = {}
var _arm_index := 0
var _arm_observations: Array = []
var _arm_invariant_receipts: Array = []
var _arm_step_receipts: Array = []
var _arm_development_progression_receipts: Array = []
var _arm_stance_observation_binding_receipts: Array = []
var _arm_control_receipts: Array = []
var _arm_application_receipts: Array = []
var _arm_results: Dictionary = {}
var _arm_schedule_started := false
var _transitioning := false
var _total_model_construction_attempt_count := 0
var _total_model_construction_count := 0
var _total_world_attempt_count := 0
var _total_world_build_count := 0
var _total_solver_step_count := 0
var _observed_solver_step_boundaries := 0
var _exit_scheduled := false
var _pending_exit_code := 1
var _pending_receipt_kind := "worker_failure"
var _pending_exit_process_frames := 0
var _gate_id := "QSDK-R24D65"
var _gate_token := "R24D65"
var _raw_schema := "sporespore_qsdk_r24d65_godot_native_recovery_behavior_raw_v1"
var _work_id := "QSDK-R24D65-GODOT-JOLT-NATIVE-RECOVERY-BEHAVIOR"
var _raw_marker := RAW_MARKER
var _ready_marker := READY_MARKER
var _progress_marker := ""
var _progress_cadence_steps := 0
var _progress_sequence := 0
var _authorization_env := AUTHORIZATION_ENV
var _source_commit_env := SOURCE_COMMIT_ENV
var _attempt_id_env := ATTEMPT_ID_ENV
var _supervised_env := SUPERVISED_ENV
var _nonce_env := NONCE_ENV
var _seed := DEFAULT_SEED
var _seed_label := DEFAULT_SEED_LABEL
var _seed_sha256 := DEFAULT_SEED_SHA256
var _actuator_mode := ACTUATOR_MODE_LEGACY
var _recovery_controller_id := RouteScript.RECOVERY_CONTROLLER_ID
var _energy_route_id := RouteScript.ROUTE_ID


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _load_campaign_binding():
		_abort("QSDK_R24D65_BEHAVIOR_CAMPAIGN_BINDING_INVALID")
		return
	var authorization_sha256 := OS.get_environment(_authorization_env)
	var source_commit := OS.get_environment(_source_commit_env)
	var attempt_id := OS.get_environment(_attempt_id_env)
	if (
		not _valid_sha256(authorization_sha256)
		or source_commit.length() != 40
		or not source_commit.is_valid_hex_number(false)
		or attempt_id.length() != 32
		or not attempt_id.is_valid_hex_number(false)
		or (
			not _progress_marker.is_empty()
			and (
				OS.get_environment(_supervised_env) != "1"
				or OS.get_environment(_nonce_env).is_empty()
			)
		)
	):
		_abort(_failure_code("BEHAVIOR_AUTHORIZATION_ENV_INVALID"))
		return
	seed(_seed)
	Engine.physics_ticks_per_second = PHYSICS_HZ
	if Engine.physics_ticks_per_second != PHYSICS_HZ:
		_abort(_failure_code("BEHAVIOR_PHYSICS_RATE_INVALID"))
		return
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		_abort(_failure_code("BEHAVIOR_EXTENSION_UNAVAILABLE"))
		return
	_sdk = ClassDB.instantiate(CLASS_NAME)
	if _sdk == null:
		_abort(_failure_code("BEHAVIOR_EXTENSION_INSTANTIATION_FAILED"))
		return
	_context = prepare_behavior_context_v1(
		_sdk,
		_recovery_controller_id,
		_energy_route_id,
		_gate_id,
	)
	if not bool(_context.get("ok", false)):
		_abort(_failure_code("BEHAVIOR_CONTEXT_FAILED"), _context)
		return
	_emit_progress("worker_ready")
	await _start_arm(0)


static func prepare_behavior_context_v1(
	sdk: Object,
	recovery_controller_id: String,
	energy_route_id: String,
	gate_id: String = "",
) -> Dictionary:
	if energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID:
		if gate_id == "QSDK-R24D151":
			return RouteScript.prepare_complete_energy_context_v7(sdk, recovery_controller_id)
		if gate_id == "QSDK-R24D153":
			return RouteScript.prepare_complete_energy_context_v9(sdk, recovery_controller_id)
		if gate_id == "QSDK-R24D154":
			return RouteScript.prepare_complete_energy_context_v10(sdk, recovery_controller_id)
		if gate_id == "QSDK-R24D164":
			return RouteScript.prepare_complete_energy_context_v13(sdk, recovery_controller_id)
		if gate_id == "QSDK-R24D165":
			return RouteScript.prepare_complete_energy_context_v14(sdk, recovery_controller_id)
		if gate_id == "QSDK-R24D170":
			return RouteScript.prepare_complete_energy_context_v17(sdk, recovery_controller_id)
		if gate_id == "QSDK-R24D172":
			return RouteScript.prepare_complete_energy_context_v18(sdk, recovery_controller_id)
		return {
			"ok": false,
			"failure_code": "QSDK_R24D151_R24D153_R24D154_R24D164_R24D165_R24D170_OR_R24D172_GATE_ID_REQUIRED",
		}
	if energy_route_id == RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID:
		return RouteScript.prepare_complete_energy_context_v3(sdk, recovery_controller_id)
	if energy_route_id == RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID:
		return RouteScript.prepare_complete_energy_context_v2(sdk, recovery_controller_id)
	if recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID:
		return RouteScript.prepare_context_v6(sdk, recovery_controller_id)
	if recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V5_ID:
		return RouteScript.prepare_context_v5(sdk, recovery_controller_id)
	if recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V4_ID:
		return RouteScript.prepare_context_v4(sdk, recovery_controller_id)
	if recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V3_ID:
		return RouteScript.prepare_context_v3(sdk, recovery_controller_id)
	if recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V2_ID:
		return RouteScript.prepare_context_v2(sdk, recovery_controller_id)
	return RouteScript.prepare_context_v1(sdk)


static func route_aware_application_provenance_selected_v1(context: Dictionary) -> bool:
	var schema := String(context.get("schema_version", ""))
	var gate_id := String(context.get("physical_world_construction_gate_id", ""))
	var campaign_identity_valid := (
		(
			schema
			== "sporespore_qsdk_r24d153_godot_route_aware_discrete_staging_behavior_context_v9"
			and gate_id == "QSDK-R24D153"
		)
		or (
			schema
			== "sporespore_qsdk_r24d154_godot_accumulator_aware_discrete_staging_behavior_context_v10"
			and gate_id == "QSDK-R24D154"
		)
		or (
			schema
			== "sporespore_qsdk_r24d164_godot_rotation_aware_recovery_behavior_context_v13"
			and gate_id == "QSDK-R24D164"
		)
		or (
			schema
			== "sporespore_qsdk_r24d165_godot_rotation_aware_source_trace_behavior_context_v14"
			and gate_id == "QSDK-R24D165"
		)
		or (
			schema
			== "sporespore_qsdk_r24d170_godot_contiguous_boundary_recovery_behavior_context_v17"
			and gate_id == "QSDK-R24D170"
		)
		or (
			schema
			== "sporespore_qsdk_r24d172_godot_initializer_retention_recovery_behavior_context_v18"
			and gate_id == "QSDK-R24D172"
		)
	)
	return (
		campaign_identity_valid
		and bool(context.get("finite_behavior_pair_selected", false))
		and bool(context.get("route_aware_application_provenance_selected", false))
		and (
			String(context.get("application_provenance_profile_id", ""))
			== RouteScript.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
		)
		and String(context.get("complete_energy_authority_profile_id", ""))
		== RouteScript.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
	)


static func accumulator_aware_invariant_validation_selected_v1(context: Dictionary) -> bool:
	var schema := String(context.get("schema_version", ""))
	var gate_id := String(context.get("physical_world_construction_gate_id", ""))
	var campaign_identity_valid := (
		(
			schema
			== "sporespore_qsdk_r24d154_godot_accumulator_aware_discrete_staging_behavior_context_v10"
			and gate_id == "QSDK-R24D154"
		)
		or (
			schema
			== "sporespore_qsdk_r24d164_godot_rotation_aware_recovery_behavior_context_v13"
			and gate_id == "QSDK-R24D164"
		)
		or (
			schema
			== "sporespore_qsdk_r24d165_godot_rotation_aware_source_trace_behavior_context_v14"
			and gate_id == "QSDK-R24D165"
		)
		or (
			schema
			== "sporespore_qsdk_r24d170_godot_contiguous_boundary_recovery_behavior_context_v17"
			and gate_id == "QSDK-R24D170"
		)
		or (
			schema
			== "sporespore_qsdk_r24d172_godot_initializer_retention_recovery_behavior_context_v18"
			and gate_id == "QSDK-R24D172"
		)
	)
	return (
		campaign_identity_valid
		and bool(context.get("accumulator_aware_invariant_validation_selected", false))
		and (
			String(context.get("in_run_invariant_validator_profile_id", ""))
			== RouteScript.R154_ACCUMULATOR_AWARE_INVARIANT_VALIDATOR_PROFILE_ID
		)
		and route_aware_application_provenance_selected_v1(context)
	)


static func rotation_aware_behavior_ledger_selected_v1(context: Dictionary) -> bool:
	var schema := String(context.get("schema_version", ""))
	var gate_id := String(context.get("physical_world_construction_gate_id", ""))
	var campaign_identity_valid := (
		(
			schema
			== "sporespore_qsdk_r24d164_godot_rotation_aware_recovery_behavior_context_v13"
			and gate_id == "QSDK-R24D164"
		)
		or (
			schema
			== "sporespore_qsdk_r24d165_godot_rotation_aware_source_trace_behavior_context_v14"
			and gate_id == "QSDK-R24D165"
		)
		or (
			schema
			== "sporespore_qsdk_r24d170_godot_contiguous_boundary_recovery_behavior_context_v17"
			and gate_id == "QSDK-R24D170"
		)
		or (
			schema
			== "sporespore_qsdk_r24d172_godot_initializer_retention_recovery_behavior_context_v18"
			and gate_id == "QSDK-R24D172"
		)
	)
	return (
		campaign_identity_valid
		and bool(context.get("finite_behavior_pair_selected", false))
		and bool(context.get("recovery_behavior_evaluation_authorized", false))
		and bool(context.get("rotation_aware_energy_ledger_profile_selected", false))
		and String(context.get("recovery_energy_ledger_profile_id", ""))
		== RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
		and String(context.get("finite_behavior_profile_id", ""))
		== RouteScript.R164_ROTATION_AWARE_FINITE_BEHAVIOR_PROFILE_ID
		and accumulator_aware_invariant_validation_selected_v1(context)
		and route_aware_application_provenance_selected_v1(context)
	)


static func rotation_aware_native_source_trace_validation_selected_v1(
	context: Dictionary,
) -> bool:
	var schema := String(context.get("schema_version", ""))
	var gate_id := String(context.get("physical_world_construction_gate_id", ""))
	var campaign_identity_valid := (
		(
			schema
			== "sporespore_qsdk_r24d165_godot_rotation_aware_source_trace_behavior_context_v14"
			and gate_id == "QSDK-R24D165"
		)
		or (
			schema
			== "sporespore_qsdk_r24d170_godot_contiguous_boundary_recovery_behavior_context_v17"
			and gate_id == "QSDK-R24D170"
		)
		or (
			schema
			== "sporespore_qsdk_r24d172_godot_initializer_retention_recovery_behavior_context_v18"
			and gate_id == "QSDK-R24D172"
		)
	)
	return (
		campaign_identity_valid
		and bool(context.get("rotation_aware_source_trace_validation_selected", false))
		and String(context.get("native_source_trace_validator_profile_id", ""))
		== RouteScript.R165_ROTATION_AWARE_SOURCE_TRACE_VALIDATOR_PROFILE_ID
		and rotation_aware_behavior_ledger_selected_v1(context)
	)


static func native_source_trace_schema_valid_v1(
	context: Dictionary,
	observed_schema: String,
) -> bool:
	if rotation_aware_native_source_trace_validation_selected_v1(context):
		return (
			observed_schema
			== "sporespore_qsdk_r24d162_godot_rotation_aware_complete_energy_native_source_trace_v1"
		)
	return (
		observed_schema
		== "sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_native_source_trace_v1"
	)


func _start_arm(index: int) -> void:
	if index < 0 or index >= ARM_ORDER.size() or _transitioning:
		_abort(_failure_code("BEHAVIOR_ARM_START_IDENTITY_INVALID"))
		return
	_arm_index = index
	_arm_observations = []
	_arm_invariant_receipts = []
	_arm_step_receipts = []
	_arm_development_progression_receipts = []
	_arm_stance_observation_binding_receipts = []
	_arm_control_receipts = []
	_arm_application_receipts = []
	var arm_kind := String(ARM_ORDER[_arm_index])
	var initialized := RouteScript.initialize_behavior_arm_v1(_sdk, _context, arm_kind)
	if not bool(initialized.get("ok", false)):
		_abort(_failure_code("BEHAVIOR_INITIALIZATION_FAILED"), initialized)
		return
	_initialization_receipt = (initialized["initialization_receipt"] as Dictionary).duplicate(true)
	_memory = (initialized["memory"] as Dictionary).duplicate(true)
	_model = await RouteScript.build_native_world_v1(self, _sdk, _context)
	_total_model_construction_attempt_count += int(
		_model.get("model_construction_attempt_count", 0)
	)
	_total_world_attempt_count += int(_model.get("world_attempt_count", 0))
	if not bool(_model.get("ok", false)):
		_abort(_failure_code("BEHAVIOR_WORLD_BUILD_FAILED"), _model)
		return
	_total_model_construction_count += int(_model.get("model_construction_count", 0))
	_total_world_build_count += int(_model.get("world_build_count", 0))
	if bool(_context.get("contiguous_boundary_transport_profile_selected", false)):
		var boundary_transport_model_instance_id := (
			"%s:%s:model-%d"
			% [OS.get_environment(_attempt_id_env), arm_kind, _arm_index]
		)
		var transport_initialization := (
			RouteScript
			. initialize_contiguous_boundary_transport_native_world_v1(
				_sdk,
				_context,
				_model,
				OS.get_environment(_attempt_id_env),
				arm_kind,
				boundary_transport_model_instance_id,
			)
		)
		if not bool(transport_initialization.get("ok", false)):
			_abort(
				_failure_code("BEHAVIOR_BOUNDARY_TRANSPORT_INITIALIZATION_FAILED"),
				transport_initialization,
			)
			return
		if not RouteScript.contiguous_boundary_transport_initializer_receipt_retained_exact_v1(
			_sdk,
			_model,
			transport_initialization,
			OS.get_environment(_attempt_id_env),
			arm_kind,
			boundary_transport_model_instance_id,
		):
			_abort(
				_failure_code(
					"BEHAVIOR_BOUNDARY_TRANSPORT_INITIALIZER_RECEIPT_RETENTION_INVALID"
				),
				transport_initialization,
			)
			return
	_application_intent = (
		(
			(
				RouteScript
				. initial_behavior_application_route_aware_discrete_staging_v2(
					_sdk,
					_model,
					arm_kind,
					String(_memory["phase"]),
					_recovery_controller_id,
				)
			)
			if route_aware_application_provenance_selected_v1(_context)
			else (
				RouteScript
				. initial_behavior_application_discrete_staging_complete_energy_v1(
					_sdk,
					_model,
					arm_kind,
					String(_memory["phase"]),
					_recovery_controller_id,
				)
			)
		)
		if _energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
		else (
			(
				RouteScript
				. initial_behavior_application_solver_coupled_complete_energy_v1(
					_sdk,
					_model,
					arm_kind,
					String(_memory["phase"]),
					_recovery_controller_id,
				)
			)
			if _energy_route_id == RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
			else (
				(
					RouteScript
					. initial_behavior_application_complete_energy_v1(
						_sdk,
						_model,
						arm_kind,
						String(_memory["phase"]),
						_recovery_controller_id,
					)
				)
				if _energy_route_id == RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID
				else (
					(
						RouteScript
						. initial_behavior_application_v6(
							_sdk,
							_model,
							arm_kind,
							String(_memory["phase"]),
							_recovery_controller_id,
						)
					)
					if _recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID
					else (
						(
							RouteScript
							. initial_behavior_application_v5(
								_sdk,
								_model,
								arm_kind,
								String(_memory["phase"]),
								_recovery_controller_id,
							)
						)
						if _recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V5_ID
						else (
							(
								RouteScript
								. initial_behavior_application_v4(
									_sdk,
									_model,
									arm_kind,
									String(_memory["phase"]),
									_recovery_controller_id,
								)
							)
							if _recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V4_ID
							else (
								(
									RouteScript
									. initial_behavior_application_v3(
										_sdk,
										_model,
										arm_kind,
										String(_memory["phase"]),
										_recovery_controller_id,
									)
								)
								if _recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V3_ID
								else (
									(
										RouteScript
										. initial_behavior_application_v2(
											_sdk,
											_model,
											arm_kind,
											String(_memory["phase"]),
											_recovery_controller_id,
										)
									)
									if (
										_recovery_controller_id
										== RouteScript.RECOVERY_CONTROLLER_V2_ID
									)
									else (
										RouteScript
										. initial_behavior_application_v1(
											_sdk,
											_model,
											arm_kind,
											String(_memory["phase"]),
										)
									)
								)
							)
						)
					)
				)
			)
		)
	)
	if not bool(_application_intent.get("ok", false)):
		_abort(_failure_code("BEHAVIOR_INITIAL_APPLICATION_FAILED"), _application_intent)
		return
	_initial_application = _application_intent.duplicate(true)
	_arm_application_receipts.append(_application_intent.duplicate(true))
	_emit_progress("arm_world_ready", arm_kind, 0)
	_arm_schedule_started = false
	if not physics_frame.is_connected(_on_physics_frame):
		physics_frame.connect(_on_physics_frame)


func _on_physics_frame() -> void:
	if _transitioning or _exit_scheduled:
		return
	if not _arm_schedule_started:
		_arm_schedule_started = true
		PhysicsServer3D.set_active(true)
		_model["physics_server_active"] = true
		return
	_observed_solver_step_boundaries += 1
	_capture_completed_step()


# This production worker intentionally fails closed at every native-step boundary.
# gdlint: disable=max-returns
func _capture_completed_step() -> void:
	var arm_kind := String(ARM_ORDER[_arm_index])
	var phase := String(_memory.get("phase", ""))
	var semantic_step := int(_model.get("host_step_count", 0)) + 1
	if phase in TERMINAL_PHASES or semantic_step < 1 or semantic_step > MAXIMUM_OUTER_STEPS_PER_ARM:
		_abort(
			_failure_code("BEHAVIOR_STEP_BUDGET_OR_PHASE_INVALID"),
			{"arm_kind": arm_kind, "phase": phase, "semantic_step": semantic_step},
		)
		return
	var native := (
		(
			RouteScript
			. collect_discrete_staging_complete_energy_native_world_observation_v1(
				_sdk,
				_context,
				_model,
				_application_intent,
				semantic_step,
				phase,
			)
		)
		if _energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
		else (
			(
				RouteScript
				. collect_solver_coupled_complete_energy_native_world_observation_v1(
					_sdk,
					_context,
					_model,
					_application_intent,
					semantic_step,
					phase,
				)
			)
			if _energy_route_id == RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
			else (
				(
					RouteScript
					. collect_complete_energy_native_world_observation_v1(
						_sdk,
						_context,
						_model,
						_application_intent,
						semantic_step,
						phase,
					)
				)
				if _energy_route_id == RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID
				else (
					RouteScript
					. collect_native_world_observation_v1(
						_sdk,
						_context,
						_model,
						_application_intent,
						semantic_step,
						phase,
					)
				)
			)
		)
	)
	if not bool(native.get("ok", false)):
		_abort(_failure_code("BEHAVIOR_NATIVE_SAMPLE_FAILED"), native)
		return
	_total_solver_step_count += 1
	var bound: Dictionary = native["bound"]
	var observation: Dictionary = (bound["observation_v3"] as Dictionary).duplicate(true)
	var advanced := production_advance_dispatch_v1(
		_sdk,
		_context,
		bound,
		_memory,
		arm_kind,
		phase,
		_recovery_controller_id,
		_energy_route_id,
	)
	if not bool(advanced.get("ok", false)):
		_abort(_failure_code("BEHAVIOR_PORTABLE_ADVANCE_FAILED"), advanced)
		return
	if not production_advance_receipt_valid_v1(
		advanced,
		_recovery_controller_id,
		_sdk,
		_energy_route_id,
	):
		_abort(_failure_code("BEHAVIOR_PORTABLE_ADVANCE_ROUTE_INVALID"), advanced)
		return
	var measurement: Dictionary = native["measurement"]
	var components: Dictionary = measurement["source_component_receipts"]
	var source_trace: Dictionary = components.get("source_trace", {})
	var native_application_receipt: Dictionary = components.get("application_receipt", {})
	var native_engine_health_receipt: Dictionary = measurement["native_engine_health_receipt"]
	var engine_step: Dictionary = observation["engine_step_identity"]
	var external: Dictionary = observation["external_interventions"]
	var ownership: Dictionary = observation["controller_ownership"]
	var energy_source: Dictionary = measurement["energy_source_receipt"]
	var invariant := {
		"schema_version": "sporespore_qsdk_r24d65_godot_in_run_invariant_receipt_v1",
		"arm_kind": arm_kind,
		"semantic_step": semantic_step,
		"phase": phase,
		"application_receipt_sha256": String(components.get("application_receipt_sha256", "")),
		"direct_state_source_sha256": String(components.get("direct_state_source_sha256", "")),
		"contact_source_sha256": String(components.get("contact_source_sha256", "")),
		"telemetry_source_sha256": String(components.get("telemetry_source_sha256", "")),
		"native_engine_health_receipt": native_engine_health_receipt.duplicate(true),
		"native_engine_health_receipt_sha256":
		String(measurement.get("native_engine_health_receipt_sha256", "")),
		"native_engine_health_passed":
		bool(native_engine_health_receipt.get("native_engine_health_passed", false)),
		"source_trace_sha256": String(engine_step.get("source_trace_sha256", "")),
		"observation_sha256": _canonical_sha256(observation),
		"native_space_step_sequence": int(engine_step.get("semantic_step", -1)),
		"adapter_side_discrete_staging_event_count":
		int(
			measurement["energy_source_receipt"].get(
				"adapter_side_discrete_staging_event_count", -1
			)
		),
		"missing_measurement_synthesis_count":
		int(bound.get("missing_measurement_synthesis_count", -1)),
		"external_interventions": external.duplicate(true),
		"controller_ownership": ownership.duplicate(true),
		"all_in_run_physical_invariants_passed": true,
	}
	if complete_energy_route_selected_v1(_energy_route_id):
		invariant["schema_version"] = (
			complete_energy_invariant_schema_v5(
				_energy_route_id,
				_context,
			)
		)
		invariant["energy_route_id"] = _energy_route_id
		invariant["complete_energy_inputs_receipt_sha256"] = String(
			components.get("complete_energy_inputs_receipt_sha256", "")
		)
		invariant["solver_energy_exchange_receipt_sha256"] = String(
			components.get("solver_energy_exchange_receipt_sha256", "")
		)
		invariant["constraint_exchange_partition_complete"] = bool(
			energy_source.get("constraint_exchange_partition_complete", false)
		)
		invariant["passive_dissipation_partition_complete"] = bool(
			energy_source.get("passive_dissipation_partition_complete", false)
		)
		invariant["component_partition_complete"] = bool(
			energy_source.get("component_partition_complete", false)
		)
		invariant["exact_balance_safety_authority"] = bool(
			energy_source.get("exact_balance_safety_authority", false)
		)
		invariant["residual_balancing_permitted"] = bool(
			energy_source.get("residual_balancing_permitted", true)
		)
		invariant["complete_energy_invariants_passed"] = true
	if discrete_staging_complete_energy_route_selected_v1(_energy_route_id):
		invariant["discrete_staging_rule_id"] = String(
			energy_source.get("discrete_staging_rule_id", "")
		)
		invariant["discrete_staging_observer_receipt_sha256"] = String(
			components.get("discrete_staging_observer_receipt_sha256", "")
		)
		invariant["discrete_staging_mapping_receipt_sha256"] = String(
			components.get("discrete_staging_mapping_receipt_sha256", "")
		)
		invariant["discrete_staging_accumulator_before_sha256"] = String(
			components.get("discrete_staging_accumulator_before_sha256", "")
		)
		invariant["discrete_staging_accumulator_after_sha256"] = String(
			components.get("discrete_staging_accumulator_after_sha256", "")
		)
		invariant["step_signed_discrete_staging_exchange_j"] = float(
			energy_source.get("step_signed_discrete_staging_exchange_j", NAN)
		)
		invariant["cumulative_signed_discrete_staging_exchange_j"] = float(
			energy_source.get("cumulative_signed_discrete_staging_exchange_j", NAN)
		)
		invariant["discrete_staging_invariants_passed"] = true
		if accumulator_aware_invariant_validation_selected_v1(_context):
			invariant["in_run_invariant_validator_profile_id"] = (
				RouteScript.R154_ACCUMULATOR_AWARE_INVARIANT_VALIDATOR_PROFILE_ID
			)
		if route_aware_application_provenance_selected_v1(_context):
			invariant["application_provenance_profile_id"] = String(
				source_trace.get("application_provenance_profile_id", "")
			)
			invariant["native_application_receipt_schema"] = String(
				native_application_receipt.get("schema_version", "")
			)
			invariant["native_source_trace_schema"] = String(
				source_trace.get("schema_version", "")
			)
			invariant["route_aware_application_provenance_invariants_passed"] = true
		if rotation_aware_behavior_ledger_selected_v1(_context):
			invariant["recovery_energy_ledger_profile_id"] = String(
				energy_source.get("recovery_energy_ledger_profile_id", "")
			)
			invariant["rotation_integration_exchange_included_exactly_once"] = bool(
				energy_source.get("rotation_integration_exchange_included_exactly_once", false)
			)
			invariant["rotation_aware_energy_ledger_invariants_passed"] = (
				String(energy_source.get("recovery_energy_ledger_profile_id", ""))
				== RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
				and String(components.get("recovery_energy_ledger_profile_id", ""))
				== RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
				and bool(
					energy_source.get(
						"rotation_integration_exchange_included_exactly_once", false
					)
				)
				and bool(
					components.get(
						"rotation_integration_exchange_included_exactly_once", false
					)
				)
			)
		if rotation_aware_native_source_trace_validation_selected_v1(_context):
			invariant["native_source_trace_validator_profile_id"] = String(
				_context.get("native_source_trace_validator_profile_id", "")
			)
			invariant["rotation_aware_native_source_trace_schema_valid"] = (
				native_source_trace_schema_valid_v1(
					_context,
					String(invariant.get("native_source_trace_schema", "")),
				)
			)
		if bool(_context.get("contiguous_boundary_transport_profile_selected", false)):
			var boundary_capture_value: Variant = native.get(
				"discrete_staging_boundary_capture"
			)
			if not (boundary_capture_value is Dictionary):
				_abort(_failure_code("BEHAVIOR_BOUNDARY_TRANSPORT_CAPTURE_MISSING"), native)
				return
			var boundary_capture: Dictionary = boundary_capture_value
			invariant["contiguous_boundary_transport_profile_selected"] = true
			invariant["boundary_transport_capture_schema_version"] = String(
				boundary_capture.get("schema_version", "")
			)
			invariant["boundary_transport_design_id"] = String(
				boundary_capture.get("transport_design_id", "")
			)
			invariant["boundary_transport_profile_id"] = String(
				boundary_capture.get("transport_profile_id", "")
			)
			invariant["boundary_transport_capture_sha256"] = _canonical_sha256(
				boundary_capture
			)
			invariant["boundary_transport_previous_sequence"] = int(
				boundary_capture.get("previous_sequence", -1)
			)
			invariant["boundary_transport_state_revision_before"] = int(
				boundary_capture.get("transport_state_revision_before", -1)
			)
			invariant["boundary_transport_state_revision_after"] = int(
				boundary_capture.get("transport_state_revision_after", -1)
			)
			invariant["boundary_transport_pre_boundary_source_kind"] = String(
				boundary_capture.get("pre_boundary_source_kind", "")
			)
			invariant["boundary_transport_post_boundary_source_kind"] = String(
				boundary_capture.get("post_boundary_source_kind", "")
			)
			invariant["boundary_transport_cache_advance_count_pending_commit"] = int(
				boundary_capture.get("cache_advance_count_pending_commit", -1)
			)
			invariant["boundary_transport_cache_advance_committed"] = bool(
				native.get("contiguous_boundary_transport_cache_advance_committed", false)
			)
			invariant["boundary_transport_source_measurement"] = bool(
				boundary_capture.get("source_measurement", false)
			)
			invariant["boundary_transport_mechanical_energy_change_used_as_input"] = bool(
				boundary_capture.get("mechanical_energy_change_used_as_input", true)
			)
			invariant["boundary_transport_energy_balance_residual_used_as_input"] = bool(
				boundary_capture.get("energy_balance_residual_used_as_input", true)
			)
			invariant["boundary_transport_acceptance_threshold_used_as_input"] = bool(
				boundary_capture.get("acceptance_threshold_used_as_input", true)
			)
			invariant["boundary_transport_controller_or_behavior_result_used_as_input"] = bool(
				boundary_capture.get("controller_or_behavior_result_used_as_input", true)
			)
	if not _invariant_receipt_valid(invariant, semantic_step):
		_abort(_failure_code("BEHAVIOR_IN_RUN_INVARIANT_INVALID"), invariant)
		return
	_arm_observations.append(observation)
	_arm_invariant_receipts.append(invariant)
	_arm_step_receipts.append((advanced["step_receipt"] as Dictionary).duplicate(true))
	if _recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID:
		_arm_development_progression_receipts.append(
			(advanced["development_progression_receipt"] as Dictionary).duplicate(true)
		)
		var stance_binding_value: Variant = advanced.get("stance_observation_binding_receipt")
		if stance_binding_value is Dictionary:
			_arm_stance_observation_binding_receipts.append(
				(stance_binding_value as Dictionary).duplicate(true)
			)
	_memory = (advanced["next_memory"] as Dictionary).duplicate(true)
	var terminal := bool(advanced["terminal"])
	if (
		not _progress_marker.is_empty()
		and (
			semantic_step % _progress_cadence_steps == 0
			or terminal
			or semantic_step == MAXIMUM_OUTER_STEPS_PER_ARM
		)
	):
		_emit_progress("solver_progress", arm_kind, semantic_step)
	if terminal or semantic_step == MAXIMUM_OUTER_STEPS_PER_ARM:
		_complete_current_arm(terminal)
		return
	var control_value: Variant = advanced.get("control_receipt")
	if not (control_value is Dictionary):
		_abort(_failure_code("BEHAVIOR_NEXT_CONTROL_MISSING"), advanced)
		return
	var control: Dictionary = control_value
	var positions: Dictionary = {}
	for row_value in (observation["state"] as Dictionary)["ordered_joint_observations"]:
		var row: Dictionary = row_value
		positions[String(row["joint_id"])] = float(row["position_rad"])
	var application: Dictionary
	if _energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID:
		application = (
			RouteScript.apply_behavior_control_route_aware_discrete_staging_v2(
				_sdk,
				control,
				_model,
				positions,
			)
			if route_aware_application_provenance_selected_v1(_context)
			else RouteScript.apply_behavior_control_discrete_staging_complete_energy_v1(
				_sdk,
				control,
				_model,
				positions,
			)
		)
	elif _energy_route_id == RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID:
		application = (
			RouteScript
			. apply_behavior_control_solver_coupled_complete_energy_v1(
				_sdk,
				control,
				_model,
				positions,
			)
		)
	elif _energy_route_id == RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID:
		application = (
			RouteScript
			. apply_behavior_control_complete_energy_v2(
				_sdk,
				control,
				_model,
				positions,
			)
		)
	elif _actuator_mode == ACTUATOR_MODE_SOLVER_COUPLED:
		application = (
			RouteScript
			. apply_behavior_control_solver_coupled_native_constraint_motor_v11(
				_sdk,
				control,
				_model["joint_by_actuator_id"],
				positions,
				false,
			)
		)
	elif (
		_actuator_mode == ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED
	):
		application = (
			RouteScript
			. apply_behavior_control_force_based_joint_space_effective_inertia_population_guarded_v9(
				_sdk,
				control,
				_model,
				positions,
			)
		)
	elif _actuator_mode == ACTUATOR_MODE_FORCE_BASED_JOINT_TARGET_MONOTONE_POPULATION_GUARDED:
		application = (
			RouteScript
			. apply_behavior_control_force_based_joint_target_monotone_population_guarded_v8(
				_sdk,
				control,
				_model,
				positions,
			)
		)
	elif _actuator_mode == ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED:
		application = (
			RouteScript
			. apply_behavior_control_force_based_order_neutral_population_guarded_v7(
				_sdk,
				control,
				_model,
				positions,
			)
		)
	elif _actuator_mode == ACTUATOR_MODE_FORCE_BASED_REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED:
		application = (
			RouteScript
			. apply_behavior_control_force_based_refinement_safe_component_norm_nested_guarded_v6(
				_sdk,
				control,
				_model,
				positions,
			)
		)
	elif _actuator_mode == ACTUATOR_MODE_FORCE_BASED_COMPONENT_NORM_NESTED_GUARDED:
		application = (
			RouteScript
			. apply_behavior_control_force_based_component_norm_nested_guarded_v5(
				_sdk,
				control,
				_model,
				positions,
			)
		)
	elif _actuator_mode == ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED:
		application = (
			RouteScript
			. apply_behavior_control_force_based_nested_guarded_v4(
				_sdk,
				control,
				_model,
				positions,
			)
		)
	elif _actuator_mode == ACTUATOR_MODE_FORCE_BASED:
		application = (
			RouteScript
			. apply_behavior_control_force_based_v2(
				_sdk,
				control,
				_model,
				positions,
			)
		)
	else:
		application = (
			RouteScript
			. apply_behavior_control_v1(
				_sdk,
				control,
				_model["joint_by_actuator_id"],
				positions,
				false,
			)
		)
	var no_actuation := bool(control.get("no_actuation_requested", false))
	if (
		not bool(application.get("ok", false))
		or int(application.get("semantic_step", -1)) != semantic_step + 1
		or not behavior_application_receipt_valid_v4(
			_actuator_mode,
			application,
			no_actuation,
			_energy_route_id,
			route_aware_application_provenance_selected_v1(_context),
		)
	):
		_abort(_failure_code("BEHAVIOR_COMMAND_APPLICATION_FAILED"), application)
		return
	_arm_control_receipts.append(control.duplicate(true))
	_arm_application_receipts.append(application.duplicate(true))
	_application_intent = application


# gdlint: enable=max-returns


static func behavior_application_receipt_valid_v2(
	actuator_mode: String,
	application: Dictionary,
	no_actuation: bool,
	expected_recovery_controller_id: String = RouteScript.RECOVERY_CONTROLLER_V6_ID,
) -> bool:
	if no_actuation:
		if actuator_mode == ACTUATOR_MODE_SOLVER_COUPLED:
			return solver_coupled_application_receipt_valid_v2(application, true, expected_recovery_controller_id)
		return (
			String(application.get("actuator_mapping_id", "")).is_empty()
			and String(application.get("work_mapping_id", "")).is_empty()
			and int(application.get("host_write_count", -1)) == 8
			and int(application.get("host_readback_count", -1)) == 8
			and int(application.get("motor_enabled_count", -1)) == 0
			and int(application.get("body_impulse_write_count", 0)) == 0
		)
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED:
		return _joint_space_effective_inertia_population_application_receipt_valid_v1(application)
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_JOINT_TARGET_MONOTONE_POPULATION_GUARDED:
		return _joint_target_monotone_population_application_receipt_valid_v1(application)
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED:
		return _order_neutral_population_application_receipt_valid_v1(application)
	if (
		actuator_mode
		in [
			ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED,
			ACTUATOR_MODE_FORCE_BASED_COMPONENT_NORM_NESTED_GUARDED,
			ACTUATOR_MODE_FORCE_BASED_REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED,
		]
	):
		var refinement_safe_required := (
			actuator_mode == ACTUATOR_MODE_FORCE_BASED_REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED
		)
		var component_norm_required := (
			actuator_mode
			in [
				ACTUATOR_MODE_FORCE_BASED_COMPONENT_NORM_NESTED_GUARDED,
				ACTUATOR_MODE_FORCE_BASED_REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED,
			]
		)
		var expected_actuator_mapping_id := (
			(
				NativeWorldScript
				. REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
			)
			if refinement_safe_required
			else (
				NativeWorldScript.COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
				if component_norm_required
				else NativeWorldScript.NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
			)
		)
		var expected_work_mapping_id := (
			(
				NativeWorldScript
				. REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
			)
			if refinement_safe_required
			else (
				NativeWorldScript.COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
				if component_norm_required
				else NativeWorldScript.NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
			)
		)
		var minimum_applied_scale := float(
			application.get("native_angular_velocity_guard_minimum_applied_scale", NAN)
		)
		var guard_engagement_count := int(
			application.get("native_angular_velocity_guard_engagement_count", -1)
		)
		return (
			String(application.get("actuator_mapping_id", "")) == expected_actuator_mapping_id
			and String(application.get("work_mapping_id", "")) == expected_work_mapping_id
			and int(application.get("validated_command_count", -1)) == 8
			and int(application.get("host_write_count", -1)) == 16
			and int(application.get("host_readback_count", -1)) == 8
			and int(application.get("motor_enabled_count", -1)) == 0
			and int(application.get("hard_constraint_motor_disabled_count", -1)) == 8
			and int(application.get("hard_constraint_motor_target_write_count", -1)) == 0
			and int(application.get("body_impulse_write_count", -1)) == 16
			and bool(application.get("native_angular_velocity_guard_required", false))
			and bool(
				(
					application
					. get(
						"native_angular_velocity_nested_projection_required",
						false,
					)
				)
			)
			and bool(
				(
					application
					. get(
						"projection_target_separated_from_native_readback_guard",
						false,
					)
				)
			)
			and bool(application.get("all_immediate_native_readbacks_inside_guard", false))
			and application.get("native_angular_velocity_guard_limit_projection") is Dictionary
			and application.get("native_angular_velocity_inner_projection_target") is Dictionary
			and (
				int(application.get("native_angular_velocity_initial_readback_count", -1))
				== NativeWorldScript.ORDERED_BODY_IDS.size()
			)
			and (
				int(
					(
						application
						. get(
							"native_angular_velocity_post_application_readback_count",
							-1,
						)
					)
				)
				== 16
			)
			and (
				int(application.get("native_angular_velocity_total_readback_count", -1))
				== NativeWorldScript.ORDERED_BODY_IDS.size() + 16
			)
			and guard_engagement_count >= 0
			and guard_engagement_count <= 8
			and is_finite(minimum_applied_scale)
			and minimum_applied_scale >= 0.0
			and minimum_applied_scale <= 1.0
			and (
				not component_norm_required
				or (
					(
						String(application.get("numeric_predicate_id", ""))
						== NativeWorldScript.COMPONENT_NORM_NUMERIC_PREDICATE_ID
					)
					and bool(application.get("component_norm_numeric_predicate_required", false))
				)
			)
			and (
				bool(application.get("refinement_safe_guard_required", false))
				== refinement_safe_required
			)
			and bool(application.get("physics_state_modified", false))
		)
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED:
		return (
			(
				String(application.get("actuator_mapping_id", ""))
				== NativeWorldScript.FORCE_BASED_ACTUATOR_MAPPING_ID
			)
			and (
				String(application.get("work_mapping_id", ""))
				== NativeWorldScript.FORCE_BASED_WORK_MAPPING_ID
			)
			and int(application.get("host_write_count", -1)) == 16
			and int(application.get("host_readback_count", -1)) == 8
			and int(application.get("motor_enabled_count", -1)) == 0
			and int(application.get("hard_constraint_motor_disabled_count", -1)) == 8
			and int(application.get("hard_constraint_motor_target_write_count", -1)) == 0
			and int(application.get("body_impulse_write_count", -1)) == 16
			and bool(application.get("physics_state_modified", false))
		)
	if actuator_mode == ACTUATOR_MODE_SOLVER_COUPLED:
		return solver_coupled_application_receipt_valid_v2(application, false, expected_recovery_controller_id)
	if actuator_mode == ACTUATOR_MODE_LEGACY:
		return (
			String(application.get("actuator_mapping_id", "")).is_empty()
			and int(application.get("host_write_count", -1)) == 8
			and int(application.get("host_readback_count", -1)) == 8
			and int(application.get("motor_enabled_count", -1)) in [0, 8]
			and int(application.get("body_impulse_write_count", 0)) == 0
			and bool(application.get("physics_state_modified", false))
		)
	return false


## Route-aware wrapper validation is additive to the retained actuator-mode
## checks. It prevents a valid native-motor receipt from being accepted under
## the wrong complete-energy partition identity.
static func behavior_application_receipt_valid_v3(
	actuator_mode: String,
	application: Dictionary,
	no_actuation: bool,
	energy_route_id: String,
) -> bool:
	if not behavior_application_receipt_valid_v2(
		actuator_mode,
		application,
		no_actuation,
	):
		return false
	if energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID:
		return (
			(
				String(application.get("schema_version", ""))
				== "sporespore_qsdk_r24d151_godot_discrete_staging_complete_energy_command_application_receipt_v1"
			)
			and (
				String(application.get("predecessor_complete_energy_schema_version", ""))
				== "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_command_application_receipt_v1"
			)
			and String(application.get("energy_route_id", "")) == energy_route_id
			and (
				String(application.get("energy_mapping_profile_id", ""))
				== RouteScript.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
			)
			and (
				String(application.get("partition_rule_id", ""))
				== RouteScript.R144_PARTITION_RULE_ID
			)
			and (
				String(application.get("actuator_mapping_id", ""))
				== ("" if no_actuation else RouteScript.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID)
			)
			and (
				String(application.get("work_mapping_id", ""))
				== ("" if no_actuation else RouteScript.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID)
			)
			and bool(application.get("solver_coupled_complete_energy_profile_selected", false))
			and bool(application.get("discrete_staging_complete_energy_profile_selected", false))
			and (
				String(application.get("complete_energy_authority_profile_id", ""))
				== RouteScript.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
			)
		)
	if energy_route_id == RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID:
		return (
			(
				String(application.get("schema_version", ""))
				== "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_command_application_receipt_v1"
			)
			and String(application.get("energy_route_id", "")) == energy_route_id
			and (
				String(application.get("energy_mapping_profile_id", ""))
				== RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
			)
			and (
				String(application.get("partition_rule_id", ""))
				== RouteScript.R144_PARTITION_RULE_ID
			)
			and (
				String(application.get("actuator_mapping_id", ""))
				== ("" if no_actuation else RouteScript.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID)
			)
			and (
				String(application.get("work_mapping_id", ""))
				== ("" if no_actuation else RouteScript.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID)
			)
			and bool(application.get("solver_coupled_complete_energy_profile_selected", false))
		)
	if energy_route_id == RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID:
		return (
			String(application.get("energy_route_id", "")) == energy_route_id
			and bool(application.get("complete_energy_profile_selected", false))
		)
	return energy_route_id == RouteScript.ROUTE_ID


## R153 preserves the R151 actuator, energy, and authority checks while
## requiring the already-commissioned R152 provenance wrapper on the behavior
## path. The retained v3 predicate remains exact for historical R151 calls.
static func behavior_application_receipt_valid_v4(
	actuator_mode: String,
	application: Dictionary,
	no_actuation: bool,
	energy_route_id: String,
	route_aware_application_provenance: bool,
	expected_recovery_controller_id: String = RouteScript.RECOVERY_CONTROLLER_V6_ID,
) -> bool:
	if not route_aware_application_provenance:
		return behavior_application_receipt_valid_v3(
			actuator_mode,
			application,
			no_actuation,
			energy_route_id,
		)
	if (
		energy_route_id != RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
		or not behavior_application_receipt_valid_v2(
			actuator_mode,
			application,
			no_actuation,
			expected_recovery_controller_id,
		)
	):
		return false
	return (
		String(application.get("schema_version", ""))
		== "sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_complete_energy_command_application_receipt_v1"
		and String(application.get("predecessor_route_aware_application_schema_version", ""))
		== "sporespore_qsdk_r24d151_godot_discrete_staging_complete_energy_command_application_receipt_v1"
		and String(application.get("predecessor_complete_energy_schema_version", ""))
		== "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_command_application_receipt_v1"
		and String(application.get("energy_route_id", "")) == energy_route_id
		and String(application.get("energy_mapping_profile_id", ""))
		== RouteScript.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
		and String(application.get("partition_rule_id", "")) == RouteScript.R144_PARTITION_RULE_ID
		and String(application.get("actuator_mapping_id", ""))
		== ("" if no_actuation else RouteScript.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID)
		and String(application.get("work_mapping_id", ""))
		== ("" if no_actuation else RouteScript.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID)
		and bool(application.get("solver_coupled_complete_energy_profile_selected", false))
		and bool(application.get("discrete_staging_complete_energy_profile_selected", false))
		and String(application.get("complete_energy_authority_profile_id", ""))
		== RouteScript.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
		and String(application.get("application_provenance_profile_id", ""))
		== RouteScript.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
	)


static func _solver_coupled_application_receipt_valid_v1(
	application: Dictionary,
	no_actuation: bool,
	expected_recovery_controller_id: String = RouteScript.RECOVERY_CONTROLLER_V6_ID,
) -> bool:
	var expected_motor_count := 0 if no_actuation else 8
	return (
		(
			String(application.get("actuation_realization_id", ""))
			== RouteScript.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID
		)
		and (
			String(application.get("portable_recovery_controller_id", ""))
			== expected_recovery_controller_id
		)
		and (expected_recovery_controller_id in [RouteScript.RECOVERY_CONTROLLER_V6_ID, RouteScript.RECOVERY_CONTROLLER_V7_ID, RouteScript.RECOVERY_CONTROLLER_V8_ID]
			or RouteScript.CanonicalOwnershipL15.candidate_id_valid_v1(expected_recovery_controller_id))
		and bool(application.get("native_contact_solver_coupled", false))
		and (
			int(application.get("solver_coupled_motor_target_write_count", -1))
			== expected_motor_count
		)
		and int(application.get("pre_solver_direct_body_impulse_write_count", -1)) == 0
		and (
			String(application.get("energy_source_profile_id", ""))
			== RouteScript.ENERGY_MAPPING_PROFILE_ID
		)
		and bool(application.get("controller_realization_identity_checked", false))
		and int(application.get("host_write_count", -1)) == 8
		and int(application.get("host_readback_count", -1)) == 8
		and int(application.get("motor_enabled_count", -1)) == expected_motor_count
		and int(application.get("body_impulse_write_count", 0)) == 0
		and bool(application.get("physics_state_modified", false)) == (not no_actuation)
	)


## R129 consumes the versioned mutation semantics instead of inferring active
## solver-coupled mutation from the legacy receipt's ambiguous boolean alone.
## This stays public to the zero-world worker so the exact production consumer
## can be mutation-tested without constructing or stepping a physics world.
static func solver_coupled_application_receipt_valid_v2(
	application: Dictionary,
	no_actuation: bool,
	expected_recovery_controller_id: String = RouteScript.RECOVERY_CONTROLLER_V6_ID,
) -> bool:
	var active := not no_actuation
	return (
		_solver_coupled_application_receipt_valid_v1(application, no_actuation, expected_recovery_controller_id)
		and (
			String(application.get("application_mutation_semantics_id", ""))
			== RouteScript.R129_SOLVER_COUPLED_APPLICATION_MUTATION_SEMANTICS_ID
		)
		and int(application.get("host_constraint_configuration_write_count", -1)) == 8
		and bool(application.get("active_constraint_motor_configuration_modified", false)) == active
		and not bool(application.get("pre_solver_rigid_body_state_modified", true))
		and not bool(application.get("solver_state_advanced", true))
		and (
			String(application.get("physics_state_mutation_scope", ""))
			== ("constraint_motor_configuration_pre_solver" if active else "none")
		)
		and bool(application.get("application_mutation_semantics_checked", false))
	)


static func _order_neutral_population_application_receipt_valid_v1(
	application: Dictionary,
) -> bool:
	return _population_application_receipt_valid_common_v1(application, false)


static func _joint_target_monotone_population_application_receipt_valid_v1(
	application: Dictionary,
) -> bool:
	return _population_application_receipt_valid_common_v1(application, true)


static func _joint_space_effective_inertia_population_application_receipt_valid_v1(
	application: Dictionary,
) -> bool:
	return _population_application_receipt_valid_common_v1(application, false, true)


static func _population_application_receipt_valid_common_v1(
	application: Dictionary,
	joint_target_monotone_required: bool,
	joint_space_effective_inertia_required: bool = false,
) -> bool:
	var joint_target_population_value: Variant = application.get(
		"joint_target_monotone_population_guard_projection"
	)
	var joint_space_population_value: Variant = application.get(
		"joint_space_effective_inertia_population_guard_projection"
	)
	var solved_population_required := (
		joint_target_monotone_required or joint_space_effective_inertia_required
	)
	var population_value: Variant = (
		joint_space_population_value
		if joint_space_effective_inertia_required
		else (
			joint_target_population_value
			if joint_target_monotone_required
			else application.get("order_neutral_population_guard_projection")
		)
	)
	var population_readback_value: Variant = application.get(
		"order_neutral_population_native_angular_velocity_readback"
	)
	var ordered_receipts_value: Variant = application.get("ordered_receipts")
	var body_receipts_value: Variant = application.get("ordered_body_application_receipts")
	if (
		not (population_value is Dictionary)
		or not (population_readback_value is Dictionary)
		or not (ordered_receipts_value is Array)
		or not (body_receipts_value is Array)
	):
		return false
	var joint_target_population: Dictionary = population_value if solved_population_required else {}
	var population: Dictionary = (
		joint_target_population.get("body_guard_population_projection", {})
		if solved_population_required
		else population_value
	)
	var population_readback: Dictionary = population_readback_value
	var ordered_receipts: Array = ordered_receipts_value
	var body_receipts: Array = body_receipts_value
	var body_projection_values: Variant = population.get("ordered_body_projections")
	var population_validation := (
		NativeWorldScript.validate_joint_space_effective_inertia_population_guard_projection_v1(
			joint_target_population
		)
		if joint_space_effective_inertia_required
		else (
			NativeWorldScript.validate_joint_target_monotone_population_guard_projection_v1(
				joint_target_population
			)
			if joint_target_monotone_required
			else NativeWorldScript.validate_order_neutral_population_guard_projection_v1(population)
		)
	)
	var population_readback_validation := (
		NativeWorldScript
		. validate_order_neutral_population_native_angular_velocity_guard_readback_receipt_v1(
			population, population_readback
		)
	)
	if (
		not bool(population_validation.get("ok", false))
		or not bool(population_readback_validation.get("ok", false))
		or not (body_projection_values is Array)
		or ordered_receipts.size() != NativeWorldScript.ORDERED_ACTUATOR_IDS.size()
		or body_receipts.size() != NativeWorldScript.ORDERED_BODY_IDS.size()
		or (body_projection_values as Array).size() != NativeWorldScript.ORDERED_BODY_IDS.size()
	):
		return false
	var body_write_count := int(application.get("body_impulse_write_count", -1))
	var recomputed_body_write_count := 0
	for body_index in range(body_receipts.size()):
		var body_receipt_value: Variant = body_receipts[body_index]
		if not (body_receipt_value is Dictionary):
			return false
		var body_receipt: Dictionary = body_receipt_value
		var body_projection: Dictionary = (body_projection_values as Array)[body_index]
		var call_performed := bool(body_receipt.get("call_performed", false))
		if (
			int(body_receipt.get("body_index", -1)) != body_index
			or (
				String(body_receipt.get("body_id", ""))
				!= String(NativeWorldScript.ORDERED_BODY_IDS[body_index])
			)
			or String(body_receipt.get("api", "")) != "RigidBody3D.apply_torque_impulse"
			or bool(body_receipt.get("call_returned", false)) != call_performed
			or int(body_receipt.get("body_impulse_write_count", -1)) != int(call_performed)
			or not bool(body_receipt.get("canonical_body_order", false))
			or call_performed != bool(body_projection.get("nonzero_body_impulse", false))
			or (
				JsonTransportScript.stringify(body_receipt.get("aggregate_impulse_world_nms"))
				!= JsonTransportScript.stringify(
					body_projection.get("applied_aggregate_impulse_world_nms")
				)
			)
		):
			return false
		recomputed_body_write_count += int(call_performed)
	for actuator_index in range(ordered_receipts.size()):
		var receipt_value: Variant = ordered_receipts[actuator_index]
		if not (receipt_value is Dictionary):
			return false
		var receipt: Dictionary = receipt_value
		var readback_value: Variant = receipt.get("native_angular_velocity_readback")
		if not (readback_value is Dictionary):
			return false
		# The route adds application-only attribution metadata after the pure
		# projection. Validate the projection without those four receipt fields.
		var projection_source := receipt.duplicate(true)
		projection_source.erase("aggregate_body_application")
		projection_source.erase("joint_attribution_only")
		projection_source.erase("direct_joint_body_impulse_write_count")
		projection_source.erase("body_impulse_write_count")
		projection_source.erase("native_angular_velocity_readback")
		var projection_validation := (
			(
				NativeWorldScript
				. validate_joint_space_effective_inertia_population_guarded_force_based_joint_impulse_projection_v1(
					projection_source, joint_target_population
				)
			)
			if joint_space_effective_inertia_required
			else (
				(
					NativeWorldScript
					. validate_joint_target_monotone_population_guarded_force_based_joint_impulse_projection_v1(
						projection_source, joint_target_population
					)
				)
				if joint_target_monotone_required
				else (
					NativeWorldScript
					. validate_order_neutral_population_guarded_force_based_joint_impulse_projection_v1(
						projection_source, population
					)
				)
			)
		)
		var readback_validation := (
			(
				NativeWorldScript
				. validate_joint_space_effective_inertia_population_joint_angular_velocity_readback_receipt_v1(
					projection_source,
					joint_target_population,
					population_readback,
					readback_value,
				)
			)
			if joint_space_effective_inertia_required
			else (
				(
					NativeWorldScript
					. validate_joint_target_monotone_population_joint_angular_velocity_readback_receipt_v1(
						projection_source,
						joint_target_population,
						population_readback,
						readback_value,
					)
				)
				if joint_target_monotone_required
				else (
					NativeWorldScript
					. validate_order_neutral_population_joint_angular_velocity_readback_receipt_v1(
						projection_source,
						population,
						population_readback,
						readback_value,
					)
				)
			)
		)
		if (
			not bool(projection_validation.get("ok", false))
			or not bool(readback_validation.get("ok", false))
			or int(receipt.get("actuator_index", -1)) != actuator_index
			or not bool(receipt.get("aggregate_body_application", false))
			or not bool(receipt.get("joint_attribution_only", false))
			or int(receipt.get("direct_joint_body_impulse_write_count", -1)) != 0
			or int(receipt.get("body_impulse_write_count", -1)) != 0
		):
			return false
	var common_applied_scale := (
		float(joint_target_population.get("nominal_composed_common_scale", NAN))
		if solved_population_required
		else float(population.get("common_applied_scale", NAN))
	)
	var minimum_applied_scale := float(
		application.get("native_angular_velocity_guard_minimum_applied_scale", NAN)
	)
	var expected_guard_engagement_count := (
		NativeWorldScript.ORDERED_ACTUATOR_IDS.size()
		if (
			bool(population.get("population_guard_engaged", false))
			or (
				joint_space_effective_inertia_required
				and bool(joint_target_population.get("solver_guard_engaged", false))
			)
			or (
				joint_target_monotone_required
				and bool(joint_target_population.get("target_guard_engaged", false))
			)
		)
		else 0
	)
	var expected_schema := (
		"sporespore_qsdk_r24d109_godot_joint_space_effective_inertia_population_guarded_force_based_command_application_receipt_v1"
		if joint_space_effective_inertia_required
		else (
			"sporespore_qsdk_r24d107_godot_joint_target_monotone_population_guarded_force_based_command_application_receipt_v1"
			if joint_target_monotone_required
			else "sporespore_qsdk_r24d103_godot_order_neutral_population_guarded_force_based_command_application_receipt_v1"
		)
	)
	var expected_actuator_mapping_id := (
		(
			NativeWorldScript
			. JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		)
		if joint_space_effective_inertia_required
		else (
			(
				NativeWorldScript
				. JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
			)
			if joint_target_monotone_required
			else NativeWorldScript.ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		)
	)
	var expected_work_mapping_id := (
		(
			NativeWorldScript
			. JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		)
		if joint_space_effective_inertia_required
		else (
			NativeWorldScript.JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
			if joint_target_monotone_required
			else NativeWorldScript.ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		)
	)
	var target_binding_valid := (
		(
			bool(
				application.get(
					"joint_space_effective_inertia_population_projection_required", false
				)
			)
			and (
				float(application.get("joint_space_effective_inertia_common_pre_scale", NAN))
				== float(joint_target_population.get("joint_space_common_pre_scale", NAN))
			)
			and (
				float(application.get("body_guard_common_applied_scale", NAN))
				== float(joint_target_population.get("body_guard_common_applied_scale", NAN))
			)
			and (
				int(application.get("representation_refinement_count", -1))
				== int(joint_target_population.get("representation_refinement_count", -2))
			)
			and bool(application.get("all_joint_target_errors_nonincreasing", false))
			and int(application.get("joint_target_crossing_count", -1)) == 0
		)
		if joint_space_effective_inertia_required
		else (
			(
				bool(application.get("joint_target_monotone_population_projection_required", false))
				and (
					float(application.get("joint_target_monotone_common_pre_scale", NAN))
					== float(joint_target_population.get("target_common_pre_scale", NAN))
				)
				and (
					float(application.get("body_guard_common_applied_scale", NAN))
					== float(joint_target_population.get("body_guard_common_applied_scale", NAN))
				)
				and (
					bool(application.get("population_zero_hold_for_nonhelpful_joint_delta", false))
					== bool(
						joint_target_population.get(
							"population_zero_hold_for_nonhelpful_joint_delta", false
						)
					)
				)
				and bool(application.get("all_joint_target_errors_nonincreasing", false))
				and int(application.get("joint_target_crossing_count", -1)) == 0
			)
			if joint_target_monotone_required
			else not bool(
				application.get("joint_target_monotone_population_projection_required", false)
			)
		)
	)
	return (
		(String(application.get("schema_version", "")) == expected_schema)
		and (String(application.get("actuator_mapping_id", "")) == expected_actuator_mapping_id)
		and (String(application.get("work_mapping_id", "")) == expected_work_mapping_id)
		and (
			String(application.get("predecessor_actuator_mapping_id", ""))
			== NativeWorldScript.FORCE_BASED_ACTUATOR_MAPPING_ID
		)
		and (
			int(application.get("validated_command_count", -1))
			== NativeWorldScript.ORDERED_ACTUATOR_IDS.size()
		)
		and int(application.get("host_write_count", -1)) == body_write_count
		and (
			int(application.get("host_readback_count", -1))
			== NativeWorldScript.ORDERED_ACTUATOR_IDS.size()
		)
		and body_write_count == recomputed_body_write_count
		and body_write_count == int(population.get("nonzero_body_impulse_count", -1))
		and body_write_count >= 0
		and body_write_count <= NativeWorldScript.ORDERED_BODY_IDS.size()
		and int(application.get("motor_enabled_count", -1)) == 0
		and int(application.get("hard_constraint_motor_disabled_count", -1)) == 8
		and int(application.get("hard_constraint_motor_target_write_count", -1)) == 0
		and bool(application.get("native_angular_velocity_guard_required", false))
		and bool(application.get("native_angular_velocity_nested_projection_required", false))
		and bool(application.get("projection_target_separated_from_native_readback_guard", false))
		and bool(application.get("all_immediate_native_readbacks_inside_guard", false))
		and (
			int(application.get("native_angular_velocity_initial_readback_count", -1))
			== NativeWorldScript.ORDERED_BODY_IDS.size()
		)
		and (
			int(application.get("native_angular_velocity_post_application_readback_count", -1))
			== NativeWorldScript.ORDERED_BODY_IDS.size()
		)
		and (
			int(application.get("native_angular_velocity_total_readback_count", -1))
			== 2 * NativeWorldScript.ORDERED_BODY_IDS.size()
		)
		and (
			int(application.get("native_angular_velocity_guard_engagement_count", -1))
			== expected_guard_engagement_count
		)
		and is_finite(common_applied_scale)
		and common_applied_scale >= 0.0
		and common_applied_scale <= 1.0
		and minimum_applied_scale == common_applied_scale
		and (
			String(application.get("numeric_predicate_id", ""))
			== NativeWorldScript.COMPONENT_NORM_NUMERIC_PREDICATE_ID
		)
		and bool(application.get("component_norm_numeric_predicate_required", false))
		and bool(application.get("refinement_safe_guard_required", false))
		and bool(application.get("order_neutral_population_projection_required", false))
		and bool(application.get("aggregate_body_application_required", false))
		and bool(application.get("per_actuator_attribution_required", false))
		and not bool(application.get("input_iteration_order_has_action_authority", true))
		and target_binding_valid
		and bool(application.get("physics_state_modified", false)) == (body_write_count > 0)
	)


static func actuator_mapping_id_for_mode_v1(actuator_mode: String) -> String:
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED:
		return (
			NativeWorldScript
			. JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		)
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_JOINT_TARGET_MONOTONE_POPULATION_GUARDED:
		return (
			NativeWorldScript
			. JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		)
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED:
		return NativeWorldScript.ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED:
		return (
			NativeWorldScript
			. REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		)
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_COMPONENT_NORM_NESTED_GUARDED:
		return NativeWorldScript.COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED:
		return NativeWorldScript.NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED:
		return NativeWorldScript.FORCE_BASED_ACTUATOR_MAPPING_ID
	return ""


static func work_mapping_id_for_mode_v1(actuator_mode: String) -> String:
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED:
		return (
			NativeWorldScript
			. JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		)
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_JOINT_TARGET_MONOTONE_POPULATION_GUARDED:
		return (
			NativeWorldScript.JOINT_TARGET_MONOTONE_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		)
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED:
		return NativeWorldScript.ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED:
		return (
			NativeWorldScript
			. REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		)
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_COMPONENT_NORM_NESTED_GUARDED:
		return NativeWorldScript.COMPONENT_NORM_NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED:
		return NativeWorldScript.NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
	if actuator_mode == ACTUATOR_MODE_FORCE_BASED:
		return NativeWorldScript.FORCE_BASED_WORK_MAPPING_ID
	return ""


static func complete_energy_route_selected_v1(energy_route_id: String) -> bool:
	return (
		energy_route_id
		in [
			RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
			RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
			RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
		]
	)


static func solver_coupled_complete_energy_route_selected_v1(
	energy_route_id: String,
) -> bool:
	return (
		energy_route_id
		in [
			RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
			RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
		]
	)


static func discrete_staging_complete_energy_route_selected_v1(
	energy_route_id: String,
) -> bool:
	return energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID


static func complete_energy_invariant_schema_v1(energy_route_id: String) -> String:
	return (
		"sporespore_qsdk_r24d151_godot_discrete_staging_complete_energy_in_run_invariant_receipt_v1"
		if discrete_staging_complete_energy_route_selected_v1(energy_route_id)
		else (
			"sporespore_qsdk_r24d146_godot_solver_coupled_complete_energy_in_run_invariant_receipt_v1"
			if solver_coupled_complete_energy_route_selected_v1(energy_route_id)
			else "sporespore_qsdk_r24d137_godot_complete_energy_in_run_invariant_receipt_v1"
		)
	)


static func complete_energy_invariant_schema_v2(
	energy_route_id: String,
	route_aware_application_provenance: bool,
) -> String:
	if (
		route_aware_application_provenance
		and discrete_staging_complete_energy_route_selected_v1(energy_route_id)
	):
		return "sporespore_qsdk_r24d153_godot_route_aware_discrete_staging_complete_energy_in_run_invariant_receipt_v1"
	return complete_energy_invariant_schema_v1(energy_route_id)


static func complete_energy_invariant_schema_v3(
	energy_route_id: String,
	context: Dictionary,
) -> String:
	if (
		accumulator_aware_invariant_validation_selected_v1(context)
		and discrete_staging_complete_energy_route_selected_v1(energy_route_id)
	):
		return "sporespore_qsdk_r24d154_godot_accumulator_aware_discrete_staging_complete_energy_in_run_invariant_receipt_v2"
	return complete_energy_invariant_schema_v2(
		energy_route_id,
		route_aware_application_provenance_selected_v1(context),
	)


static func complete_energy_invariant_schema_v4(
	energy_route_id: String,
	context: Dictionary,
) -> String:
	if (
		rotation_aware_behavior_ledger_selected_v1(context)
		and discrete_staging_complete_energy_route_selected_v1(energy_route_id)
	):
		return "sporespore_qsdk_r24d164_godot_rotation_aware_recovery_behavior_in_run_invariant_receipt_v1"
	return complete_energy_invariant_schema_v3(energy_route_id, context)


static func complete_energy_invariant_schema_v5(
	energy_route_id: String,
	context: Dictionary,
) -> String:
	if (
		rotation_aware_native_source_trace_validation_selected_v1(context)
		and discrete_staging_complete_energy_route_selected_v1(energy_route_id)
	):
		return "sporespore_qsdk_r24d165_godot_rotation_aware_source_trace_behavior_in_run_invariant_receipt_v1"
	return complete_energy_invariant_schema_v4(energy_route_id, context)


static func production_advance_dispatch_id_for_route_v1(energy_route_id: String) -> String:
	return (
		R151_PRODUCTION_ADVANCE_DISPATCH_ID
		if discrete_staging_complete_energy_route_selected_v1(energy_route_id)
		else (
			R146_PRODUCTION_ADVANCE_DISPATCH_ID
			if solver_coupled_complete_energy_route_selected_v1(energy_route_id)
			else (
				R137_PRODUCTION_ADVANCE_DISPATCH_ID
				if complete_energy_route_selected_v1(energy_route_id)
				else R131_PRODUCTION_ADVANCE_DISPATCH_ID
			)
		)
	)


static func production_evaluation_dispatch_id_for_route_v1(
	energy_route_id: String,
) -> String:
	return (
		R151_PRODUCTION_EVALUATION_DISPATCH_ID
		if discrete_staging_complete_energy_route_selected_v1(energy_route_id)
		else (
			R146_PRODUCTION_EVALUATION_DISPATCH_ID
			if solver_coupled_complete_energy_route_selected_v1(energy_route_id)
			else (
				R137_PRODUCTION_EVALUATION_DISPATCH_ID
				if complete_energy_route_selected_v1(energy_route_id)
				else R134_PRODUCTION_EVALUATION_DISPATCH_ID
			)
		)
	)


static func selected_advance_route_for_energy_route_v1(energy_route_id: String) -> String:
	return (
		"r151_commissioned_discrete_staging_complete_energy_progression_v5"
		if discrete_staging_complete_energy_route_selected_v1(energy_route_id)
		else (
			"r144_solver_coupled_complete_energy_progression_v5"
			if solver_coupled_complete_energy_route_selected_v1(energy_route_id)
			else (
				"r136_complete_energy_progression_v5"
				if complete_energy_route_selected_v1(energy_route_id)
				else "r126_development_progression_v5"
			)
		)
	)


static func selected_evaluation_route_for_energy_route_v1(
	energy_route_id: String,
) -> String:
	return (
		"r151_commissioned_discrete_staging_complete_energy_authority_evaluation_v5"
		if discrete_staging_complete_energy_route_selected_v1(energy_route_id)
		else (
			"r144_solver_coupled_complete_energy_authority_evaluation_v5"
			if solver_coupled_complete_energy_route_selected_v1(energy_route_id)
			else (
				"r136_complete_energy_authority_evaluation_v5"
				if complete_energy_route_selected_v1(energy_route_id)
				else "r134_development_authority_evaluation_v5"
			)
		)
	)


static func actuator_mapping_id_for_route_v1(
	actuator_mode: String,
	energy_route_id: String,
) -> String:
	return (
		RouteScript.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID
		if solver_coupled_complete_energy_route_selected_v1(energy_route_id)
		else actuator_mapping_id_for_mode_v1(actuator_mode)
	)


static func work_mapping_id_for_route_v1(
	actuator_mode: String,
	energy_route_id: String,
) -> String:
	return (
		RouteScript.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID
		if solver_coupled_complete_energy_route_selected_v1(energy_route_id)
		else work_mapping_id_for_mode_v1(actuator_mode)
	)


static func actuation_realization_id_for_mode_v1(actuator_mode: String) -> String:
	return (
		RouteScript.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID
		if actuator_mode == ACTUATOR_MODE_SOLVER_COUPLED
		else ""
	)


static func actuation_realization_id_for_route_v1(
	actuator_mode: String,
	energy_route_id: String,
) -> String:
	return (
		RouteScript.R137_COMPLETE_ENERGY_ACTUATION_REALIZATION_ID
		if energy_route_id == RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID
		else actuation_realization_id_for_mode_v1(actuator_mode)
	)


static func actuator_mode_controller_pair_valid_v1(
	actuator_mode: String,
	recovery_controller_id: String,
) -> bool:
	return (
		(actuator_mode == ACTUATOR_MODE_SOLVER_COUPLED)
		== (recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID)
	)


static func actuator_mode_controller_route_triplet_valid_v1(
	actuator_mode: String,
	recovery_controller_id: String,
	energy_route_id: String,
) -> bool:
	if solver_coupled_complete_energy_route_selected_v1(energy_route_id):
		return (
			recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID
			and actuator_mode == ACTUATOR_MODE_SOLVER_COUPLED
		)
	if energy_route_id == RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID:
		return (
			recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID
			and (
				actuator_mode
				== ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED
			)
		)
	return (
		energy_route_id == RouteScript.ROUTE_ID
		and actuator_mode_controller_pair_valid_v1(
			actuator_mode,
			recovery_controller_id,
		)
	)


## R131 is the sole production selector for portable recovery advancement.
## The V6 solver-coupled controller requires the already-qualified R126
## incomplete-energy development progression; historical controllers retain
## the exact legacy V4 route. This function is public so zero-world tests call
## the same selector as the physical worker rather than a parallel canary.
static func production_advance_dispatch_v1(
	sdk: Object,
	context: Dictionary,
	bound: Dictionary,
	memory: Dictionary,
	arm_kind: String,
	phase: String,
	recovery_controller_id: String,
	energy_route_id: String = RouteScript.ROUTE_ID,
	l15_source_application: Variant = null,
) -> Dictionary:
	var context_controller_id := String(
		context.get("recovery_controller_id", RouteScript.RECOVERY_CONTROLLER_ID)
	)
	if context_controller_id != recovery_controller_id:
		return _production_advance_dispatch_failure("QSDK_R24D131_CONTROLLER_CONTEXT_MISMATCH")
	var requires_development_progression := (
		recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	var complete_energy_profile := complete_energy_route_selected_v1(energy_route_id)
	var solver_coupled_complete_energy_profile := solver_coupled_complete_energy_route_selected_v1(
		energy_route_id
	)
	var discrete_staging_complete_energy_profile := discrete_staging_complete_energy_route_selected_v1(
		energy_route_id
	)
	if (
		(
			energy_route_id
			not in [
				RouteScript.ROUTE_ID,
				RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
				RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
				RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
			]
		)
		or (
			complete_energy_profile
			and (
				not requires_development_progression
				or not bool(context.get("complete_energy_profile_selected", false))
				or String(context.get("energy_route_id", "")) != energy_route_id
				or (
					bool(context.get("solver_coupled_complete_energy_profile_selected", false))
					!= solver_coupled_complete_energy_profile
				)
				or (
					bool(context.get("discrete_staging_complete_energy_profile_selected", false))
					!= discrete_staging_complete_energy_profile
				)
			)
		)
	):
		return _production_advance_dispatch_failure(
			(
				"QSDK_R24D151_DISCRETE_STAGING_COMPLETE_ENERGY_DISPATCH_IDENTITY_INVALID"
				if discrete_staging_complete_energy_profile
				else (
					"QSDK_R24D146_SOLVER_COUPLED_COMPLETE_ENERGY_DISPATCH_IDENTITY_INVALID"
					if solver_coupled_complete_energy_profile
					else "QSDK_R24D137_COMPLETE_ENERGY_DISPATCH_IDENTITY_INVALID"
				)
			)
		)
	# Only the explicit R10F-L15 caller supplies the actual source application.
	# Other routes retain the previous dispatcher and return contracts.
	if l15_source_application != null:
		if (
			not (l15_source_application is Dictionary)
			or recovery_controller_id != RouteScript.RECOVERY_CONTROLLER_V6_ID
			or energy_route_id != RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
		):
			return _production_advance_dispatch_failure("QSDK_R10F_L15_DISPATCH_IDENTITY_INVALID")
	var advanced := (
		RouteScript.advance_behavior_solver_coupled_complete_energy_l15_v1(
			sdk, context, bound, memory, arm_kind, phase, l15_source_application
		)
		if l15_source_application is Dictionary
		else (
			(
				RouteScript
				. advance_behavior_solver_coupled_complete_energy_v1(
					sdk,
					context,
					bound,
					memory,
					arm_kind,
					phase,
				)
			)
			if solver_coupled_complete_energy_profile
			else (
				(
					RouteScript
					. advance_behavior_complete_energy_v1(
						sdk,
						context,
						bound,
						memory,
						arm_kind,
						phase,
					)
				)
				if complete_energy_profile
				else (
					(
						RouteScript
						. advance_behavior_v5(
							sdk,
							context,
							bound,
							memory,
							arm_kind,
							phase,
						)
					)
					if requires_development_progression
					else (
						RouteScript
						. advance_behavior_v4(
							sdk,
							context,
							bound,
							memory,
							arm_kind,
							phase,
						)
					)
				)
			)
		)
	)
	if not bool(advanced.get("ok", false)):
		return advanced
	advanced["production_advance_dispatch_id"] = (production_advance_dispatch_id_for_route_v1(
		energy_route_id
	))
	advanced["selected_portable_advance_route"] = (
		selected_advance_route_for_energy_route_v1(energy_route_id)
		if complete_energy_profile
		else (
			"r126_development_progression_v5"
			if requires_development_progression
			else "legacy_recovery_v4"
		)
	)
	advanced["development_progression_required"] = requires_development_progression
	if complete_energy_profile:
		advanced["complete_energy_authority_required"] = true
		advanced["energy_route_id"] = energy_route_id
	return advanced


## Keep evaluation on the same semantic generation selected for production
## stepping. V6 carries the qualified R126 development authority through V5;
## historical controllers retain the exact legacy V4 evaluator.
static func production_evaluation_dispatch_v1(
	sdk: Object,
	context: Dictionary,
	candidate_trace: Dictionary,
	matched_zero_trace: Dictionary,
	recovery_controller_id: String,
	energy_route_id: String = RouteScript.ROUTE_ID,
) -> Dictionary:
	var context_controller_id := String(
		context.get("recovery_controller_id", RouteScript.RECOVERY_CONTROLLER_ID)
	)
	if context_controller_id != recovery_controller_id:
		return _production_evaluation_dispatch_failure(
			"QSDK_R24D134_EVALUATOR_CONTROLLER_CONTEXT_MISMATCH"
		)
	var requires_development_authority := (
		recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	var complete_energy_profile := complete_energy_route_selected_v1(energy_route_id)
	var solver_coupled_complete_energy_profile := solver_coupled_complete_energy_route_selected_v1(
		energy_route_id
	)
	var discrete_staging_complete_energy_profile := discrete_staging_complete_energy_route_selected_v1(
		energy_route_id
	)
	if (
		(
			energy_route_id
			not in [
				RouteScript.ROUTE_ID,
				RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
				RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
				RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
			]
		)
		or (
			complete_energy_profile
			and (
				not requires_development_authority
				or not bool(context.get("complete_energy_profile_selected", false))
				or String(context.get("energy_route_id", "")) != energy_route_id
				or (
					bool(context.get("solver_coupled_complete_energy_profile_selected", false))
					!= solver_coupled_complete_energy_profile
				)
				or (
					bool(context.get("discrete_staging_complete_energy_profile_selected", false))
					!= discrete_staging_complete_energy_profile
				)
			)
		)
	):
		return _production_evaluation_dispatch_failure(
			(
				"QSDK_R24D151_DISCRETE_STAGING_COMPLETE_ENERGY_EVALUATOR_IDENTITY_INVALID"
				if discrete_staging_complete_energy_profile
				else (
					"QSDK_R24D146_SOLVER_COUPLED_COMPLETE_ENERGY_EVALUATOR_IDENTITY_INVALID"
					if solver_coupled_complete_energy_profile
					else "QSDK_R24D137_COMPLETE_ENERGY_EVALUATOR_IDENTITY_INVALID"
				)
			)
		)
	var evaluated := (
		(
			RouteScript
			. evaluate_behavior_v5(
				sdk,
				context,
				candidate_trace,
				matched_zero_trace,
			)
		)
		if requires_development_authority
		else (
			RouteScript
			. evaluate_behavior_v4(
				sdk,
				context,
				candidate_trace,
				matched_zero_trace,
			)
		)
	)
	if not bool(evaluated.get("ok", false)):
		return evaluated
	evaluated["production_evaluation_dispatch_id"] = (production_evaluation_dispatch_id_for_route_v1(
		energy_route_id
	))
	evaluated["selected_portable_evaluation_route"] = (
		selected_evaluation_route_for_energy_route_v1(energy_route_id)
		if complete_energy_profile
		else (
			"r134_development_authority_evaluation_v5"
			if requires_development_authority
			else "legacy_recovery_evaluation_v4"
		)
	)
	evaluated["development_replay_authority_required"] = requires_development_authority
	if complete_energy_profile:
		evaluated["complete_energy_authority_required"] = true
		evaluated["energy_route_id"] = energy_route_id
	return evaluated


static func production_evaluation_receipt_valid_v1(
	evaluated: Dictionary,
	recovery_controller_id: String,
	energy_route_id: String = RouteScript.ROUTE_ID,
) -> bool:
	var requires_development_authority := (
		recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID
	)
	var complete_energy_profile := complete_energy_route_selected_v1(energy_route_id)
	var solver_coupled_complete_energy_profile := solver_coupled_complete_energy_route_selected_v1(
		energy_route_id
	)
	var discrete_staging_complete_energy_profile := discrete_staging_complete_energy_route_selected_v1(
		energy_route_id
	)
	return (
		bool(evaluated.get("ok", false))
		and (
			String(evaluated.get("production_evaluation_dispatch_id", ""))
			== production_evaluation_dispatch_id_for_route_v1(energy_route_id)
		)
		and (
			bool(evaluated.get("development_replay_authority_required", false))
			== requires_development_authority
		)
		and (
			String(evaluated.get("selected_portable_evaluation_route", ""))
			== (
				selected_evaluation_route_for_energy_route_v1(energy_route_id)
				if complete_energy_profile
				else (
					"r134_development_authority_evaluation_v5"
					if requires_development_authority
					else "legacy_recovery_evaluation_v4"
				)
			)
		)
		and (
			String(evaluated.get("schema_version", ""))
			== (
				"sporespore_qsdk_r24d151_godot_commissioned_discrete_staging_behavior_evaluation_v1"
				if discrete_staging_complete_energy_profile
				else (
					"sporespore_qsdk_r24d146_godot_solver_coupled_complete_energy_behavior_evaluation_v1"
					if solver_coupled_complete_energy_profile
					else (
						"sporespore_qsdk_r24d136_godot_complete_energy_behavior_evaluation_v1"
						if complete_energy_profile
						else (
							"sporespore_qsdk_r24d134_godot_behavior_evaluation_v1"
							if requires_development_authority
							else "sporespore_qsdk_r24d65_godot_behavior_evaluation_v1"
						)
					)
				)
			)
		)
		and _valid_sha256(String(evaluated.get("request_sha256", "")))
		and evaluated.get("evaluation_receipt") is Dictionary
		and (
			_valid_sha256(String(evaluated.get("energy_partition_authority_sha256", "")))
			if requires_development_authority
			else not evaluated.has("energy_partition_authority_sha256")
		)
		and int(evaluated.get("model_construction_count", -1)) == 0
		and int(evaluated.get("world_attempt_count", -1)) == 0
		and int(evaluated.get("world_build_count", -1)) == 0
		and int(evaluated.get("solver_step_count", -1)) == 0
		and not bool(evaluated.get("physics_state_modified", true))
		and not bool(evaluated.get("physical_acceptance_authority", true))
		and not bool(evaluated.get("release_authority", true))
		and (
			(
				bool(evaluated.get("complete_energy_authority_required", false))
				and String(evaluated.get("energy_route_id", "")) == energy_route_id
			)
			if complete_energy_profile
			else not evaluated.has("complete_energy_authority_required")
		)
	)


## Smallest paired route fixture for evaluator integration. The source sample
## remains unchanged; only the control-arm identities differ, and the initial
## state digest deliberately excludes those post-initial control receipts.
static func paired_zero_world_evaluation_traces_v1(
	sdk: Object,
	bound: Dictionary,
) -> Dictionary:
	var candidate_value: Variant = bound.get("observation_v3")
	if not (candidate_value is Dictionary):
		return _production_evaluation_dispatch_failure("QSDK_R24D134_CANDIDATE_OBSERVATION_MISSING")
	var candidate: Dictionary = (candidate_value as Dictionary).duplicate(true)
	var matched_zero := candidate.duplicate(true)
	var zero_actuation: Dictionary = matched_zero["applied_actuation"]
	zero_actuation["zero_command"] = true
	zero_actuation["command_id"] = "matched_zero_command"
	matched_zero["controller_ownership"] = {
		"owner": "none",
		"recovery_controller_id": null,
		"stance_controller_id": null,
		"handoff_event_count": 0,
		"fallback_controller_active": false,
		"source_measurement": true,
	}
	var initial_sha256 := RouteScript.initial_state_sha256_v1(sdk, candidate)
	if (
		not _valid_sha256(initial_sha256)
		or initial_sha256 != RouteScript.initial_state_sha256_v1(sdk, matched_zero)
	):
		return _production_evaluation_dispatch_failure(
			"QSDK_R24D134_INITIAL_STATE_IDENTITY_INVALID"
		)
	return {
		"schema_version": "sporespore_qsdk_r24d134_paired_zero_world_evaluation_traces_v1",
		"ok": true,
		"candidate_trace":
		{
			"schema_version": "sporespore_recovery_trace_v3",
			"arm_kind": "candidate_command",
			"declared_initial_state_sha256": initial_sha256,
			"observations": [candidate],
		},
		"matched_zero_trace":
		{
			"schema_version": "sporespore_recovery_trace_v3",
			"arm_kind": "matched_zero_command",
			"declared_initial_state_sha256": initial_sha256,
			"observations": [matched_zero],
		},
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## Validate both dispatch identity and the separately retained R126 receipt.
## A future physical result cannot be valid merely because source intent says
## V5; every V6 observation must carry runtime evidence of that exact route.
static func production_advance_receipt_valid_v1(
	advanced: Dictionary,
	recovery_controller_id: String,
	sdk: Object = null,
	energy_route_id: String = RouteScript.ROUTE_ID,
) -> bool:
	var requires_development_progression := (
		recovery_controller_id in [RouteScript.RECOVERY_CONTROLLER_V6_ID, RouteScript.RECOVERY_CONTROLLER_V7_ID, RouteScript.RECOVERY_CONTROLLER_V8_ID]
		or RouteScript.CanonicalOwnershipL15.candidate_id_valid_v1(recovery_controller_id)
	)
	if (recovery_controller_id in [RouteScript.RECOVERY_CONTROLLER_V7_ID, RouteScript.RECOVERY_CONTROLLER_V8_ID]
		or RouteScript.CanonicalOwnershipL15.candidate_id_valid_v1(recovery_controller_id)):
		if advanced.get("selected_development_recovery_controller_id") != recovery_controller_id:
			return false
	elif advanced.has("selected_development_recovery_controller_id"):
		return false
	var complete_energy_profile := complete_energy_route_selected_v1(energy_route_id)
	var solver_coupled_complete_energy_profile := solver_coupled_complete_energy_route_selected_v1(
		energy_route_id
	)
	var discrete_staging_complete_energy_profile := discrete_staging_complete_energy_route_selected_v1(
		energy_route_id
	)
	if (
		(
			String(advanced.get("production_advance_dispatch_id", ""))
			!= production_advance_dispatch_id_for_route_v1(energy_route_id)
		)
		or (
			bool(advanced.get("development_progression_required", false))
			!= requires_development_progression
		)
		or (
			String(advanced.get("selected_portable_advance_route", ""))
			!= (
				selected_advance_route_for_energy_route_v1(energy_route_id)
				if complete_energy_profile
				else (
					"r126_development_progression_v5"
					if requires_development_progression
					else "legacy_recovery_v4"
				)
			)
		)
		or not (advanced.get("step_receipt") is Dictionary)
	):
		return false
	if requires_development_progression:
		var control_value: Variant = advanced.get("control_receipt")
		var stance_owned := (
			control_value is Dictionary
			and String((control_value as Dictionary).get("owner", "")) == "stance"
		)
		var binding_value: Variant = advanced.get("stance_observation_binding_receipt")
		return (
			(
				String(advanced.get("schema_version", ""))
				== (
					"sporespore_qsdk_r24d151_godot_commissioned_discrete_staging_behavior_advance_v1"
					if discrete_staging_complete_energy_profile
					else (
						"sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_behavior_advance_v1"
						if solver_coupled_complete_energy_profile
						else (
							"sporespore_qsdk_r24d136_godot_complete_energy_behavior_advance_v1"
							if complete_energy_profile
							else RouteScript.R126_DEVELOPMENT_ROUTE_ID
						)
					)
				)
			)
			and advanced.has("stance_observation_binding_receipt")
			and advanced.get("development_progression_receipt") is Dictionary
			and development_progression_receipt_valid_v2(
				advanced["development_progression_receipt"],
				advanced["step_receipt"],
				energy_route_id,
			)
			and (
				(
					bool(advanced.get("complete_energy_authority_required", false))
					and String(advanced.get("energy_route_id", "")) == energy_route_id
				)
				if complete_energy_profile
				else not advanced.has("complete_energy_authority_required")
			)
			and (
				stance_observation_binding_receipt_shape_valid_v1(advanced, sdk)
				if stance_owned
				else binding_value == null
			)
		)
	return (
		(
			String(advanced.get("schema_version", ""))
			== "sporespore_qsdk_r24d65_godot_behavior_advance_v1"
		)
		and not advanced.has("development_progression_receipt")
	)


static func stance_observation_binding_receipt_shape_valid_v1(
	advanced: Dictionary,
	sdk: Object,
) -> bool:
	var binding_value: Variant = advanced.get("stance_observation_binding_receipt")
	var control_value: Variant = advanced.get("control_receipt")
	var step_value: Variant = advanced.get("step_receipt")
	var collection_value: Variant = advanced.get("collection_request")
	if (
		not (binding_value is Dictionary)
		or not (control_value is Dictionary)
		or not (step_value is Dictionary)
		or not (collection_value is Dictionary)
		or sdk == null
	):
		return false
	var binding: Dictionary = binding_value
	var control: Dictionary = control_value
	var step: Dictionary = step_value
	var collection: Dictionary = collection_value
	var observation_value: Variant = collection.get("observation")
	var source_binding_value: Variant = collection.get("observation_source_binding")
	var authority_value: Variant = advanced.get("energy_partition_authority")
	var progression_value: Variant = advanced.get("development_progression_receipt")
	if (
		not (observation_value is Dictionary)
		or not (source_binding_value is Dictionary)
		or not (authority_value is Dictionary)
		or not (progression_value is Dictionary)
	):
		return false
	var observation: Dictionary = observation_value
	var source_binding: Dictionary = source_binding_value
	var progression: Dictionary = progression_value
	var observation_v3_sha256 := String(binding.get("portable_step_observation_v3_sha256", ""))
	return (
		(
			String(binding.get("schema_version", ""))
			== "sporespore_recovery_stance_observation_binding_receipt_v1"
		)
		and String(control.get("owner", "")) == "stance"
		and _valid_sha256(observation_v3_sha256)
		and String(step.get("observation_sha256", "")) == observation_v3_sha256
		and String(control.get("observation_sha256", "")) == observation_v3_sha256
		and (
			String(binding.get("collection_observation_v2_sha256", ""))
			== String(source_binding.get("portable_observation_sha256", ""))
		)
		and _valid_sha256(String(binding.get("observation_source_binding_sha256", "")))
		and _valid_sha256(String(binding.get("energy_partition_authority_sha256", "")))
		and _valid_sha256(String(binding.get("development_progression_receipt_sha256", "")))
		and (
			String(binding.get("energy_partition_authority_sha256", ""))
			== String(progression.get("energy_partition_authority_sha256", ""))
		)
		and (
			String(binding.get("observation_source_binding_sha256", ""))
			== RouteScript._sha256(sdk, source_binding)
		)
		and (
			String(binding.get("energy_partition_authority_sha256", ""))
			== RouteScript._sha256(sdk, authority_value)
		)
		and (
			String(binding.get("development_progression_receipt_sha256", ""))
			== RouteScript._sha256(sdk, progression)
		)
		and (
			String(binding.get("shared_observation_base_sha256", ""))
			== String(source_binding.get("observation_base_sha256", ""))
		)
		and int(binding.get("semantic_step", -1)) == int(observation.get("semantic_step", -2))
		and bool(binding.get("source_bound_v2_collection_validated", false))
		and bool(binding.get("portable_step_v3_validated", false))
		and bool(binding.get("cross_representation_base_binding_validated", false))
		and bool(binding.get("development_progression_validated", false))
		and (
			bool(binding.get("development_handoff_authorized", false))
			== bool(progression.get("development_progression_used", true))
		)
		and int(binding.get("model_construction_count", -1)) == 0
		and int(binding.get("world_attempt_count", -1)) == 0
		and int(binding.get("world_build_count", -1)) == 0
		and int(binding.get("solver_step_count", -1)) == 0
		and not bool(binding.get("physics_state_modified", true))
		and not bool(binding.get("physical_acceptance_authority", true))
		and not bool(binding.get("release_authority", true))
	)


static func development_progression_receipt_valid_v1(
	progression: Dictionary,
	step: Dictionary,
) -> bool:
	return development_progression_receipt_valid_v2(
		progression,
		step,
		RouteScript.ROUTE_ID,
	)


static func development_progression_receipt_valid_v2(
	progression: Dictionary,
	step: Dictionary,
	energy_route_id: String,
) -> bool:
	var complete_energy_profile := complete_energy_route_selected_v1(energy_route_id)
	var classification_value: Variant = step.get("classification")
	if not (classification_value is Dictionary):
		return false
	var classification: Dictionary = classification_value
	var development_nonenergy_safety_gate := (
		bool(classification.get("joint_limits_respected", false))
		and bool(classification.get("actuator_budget_respected", false))
		and float(classification.get("maximum_nonfoot_contact_impulse_ns", NAN)) == 0.0
		and bool(classification.get("no_cheat_gate", false))
	)
	var development_stance_handoff_gate := (
		not complete_energy_profile
		and bool(classification.get("raised_body_gate", false))
		and development_nonenergy_safety_gate
	)
	var development_progression_used := (
		not complete_energy_profile
		and (
			String(step.get("prior_phase", "")) == "raise_body"
			and String(step.get("next_phase", "")) == "stance_handoff"
			and bool(step.get("transitioned", false))
			and development_stance_handoff_gate
		)
	)
	var expected_authority_profile_id := (
		RouteScript.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
		if discrete_staging_complete_energy_route_selected_v1(energy_route_id)
		else (
			RouteScript.R144_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
			if solver_coupled_complete_energy_route_selected_v1(energy_route_id)
			else (
				RouteScript.R136_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
				if complete_energy_profile
				else RouteScript.R126_ENERGY_AUTHORITY_PROFILE_ID
			)
		)
	)
	return (
		(
			String(progression.get("schema_version", ""))
			== "sporespore_recovery_development_progression_receipt_v1"
		)
		and _valid_sha256(String(progression.get("energy_partition_authority_sha256", "")))
		and String(progression.get("authority_profile_id", "")) == expected_authority_profile_id
		and bool(progression.get("component_partition_complete", false)) == complete_energy_profile
		and (
			bool(progression.get("exact_balance_safety_authority", false))
			== complete_energy_profile
		)
		and (
			bool(progression.get("legacy_safety_gate", false))
			== bool(classification.get("safety_gate", false))
		)
		and (
			bool(progression.get("legacy_stable_stance_gate", false))
			== bool(classification.get("stable_stance_gate", false))
		)
		and (
			bool(progression.get("acceptance_safety_gate", false))
			== (bool(classification.get("safety_gate", false)) and complete_energy_profile)
		)
		and (
			bool(progression.get("development_nonenergy_safety_gate", false))
			== development_nonenergy_safety_gate
		)
		and (
			bool(progression.get("development_stance_handoff_gate", false))
			== development_stance_handoff_gate
		)
		and (
			bool(progression.get("development_progression_permitted", false))
			== (not complete_energy_profile)
		)
		and (
			bool(progression.get("development_progression_used", false))
			== development_progression_used
		)
		and (
			bool(progression.get("stable_stance_completion_authorized", false))
			== complete_energy_profile
		)
		and (
			bool(progression.get("physical_result_authorized", false))
			== (bool(step.get("physical_result", false)) and complete_energy_profile)
		)
		and not bool(progression.get("prone_to_standing_claimed", true))
		and not bool(progression.get("physical_acceptance_authority", true))
		and not bool(progression.get("release_authority", true))
		and int(progression.get("world_build_count", -1)) == 0
		and int(progression.get("solver_step_count", -1)) == 0
		and not bool(progression.get("physics_state_modified", true))
	)


static func development_progression_population_valid_v1(
	progression_receipts: Array,
	portable_step_count: int,
	recovery_controller_id: String,
) -> bool:
	if recovery_controller_id != RouteScript.RECOVERY_CONTROLLER_V6_ID:
		return progression_receipts.is_empty()
	if portable_step_count < 1 or progression_receipts.size() != portable_step_count:
		return false
	return progression_receipts.all(
		func(value: Variant) -> bool:
			return (
				value is Dictionary
				and (
					String((value as Dictionary).get("schema_version", ""))
					== "sporespore_recovery_development_progression_receipt_v1"
				)
			)
	)


static func _production_advance_dispatch_failure(code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d131_production_advance_dispatch_failure_v1",
		"ok": false,
		"failure_code": code,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _production_evaluation_dispatch_failure(code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d134_production_evaluation_dispatch_failure_v1",
		"ok": false,
		"failure_code": code,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


func _complete_current_arm(terminal_reached: bool) -> void:
	if _transitioning:
		return
	_transitioning = true
	PhysicsServer3D.set_active(false)
	if physics_frame.is_connected(_on_physics_frame):
		physics_frame.disconnect(_on_physics_frame)
	var arm_kind := String(ARM_ORDER[_arm_index])
	if _arm_observations.is_empty():
		_abort(_failure_code("BEHAVIOR_EMPTY_ARM_TRACE"))
		return
	var initial_state_sha256 := RouteScript.initial_state_sha256_v1(_sdk, _arm_observations[0])
	if not _valid_sha256(initial_state_sha256):
		_abort(_failure_code("BEHAVIOR_INITIAL_STATE_DIGEST_INVALID"))
		return
	var trace := {
		"schema_version": "sporespore_recovery_trace_v3",
		"arm_kind": arm_kind,
		"declared_initial_state_sha256": initial_state_sha256,
		"observations": _arm_observations.duplicate(true),
	}
	var trace_sha256 := _canonical_sha256(trace)
	if not _valid_sha256(trace_sha256):
		_abort(_failure_code("BEHAVIOR_TRACE_DIGEST_INVALID"))
		return
	var result := {
		"schema_version": "sporespore_qsdk_r24d65_godot_native_recovery_arm_result_v1",
		"gate_id": _gate_id,
		"cell_id": "r24d65_godot_development_exact_nominal",
		"seed": _seed,
		"arm_kind": arm_kind,
		"initializer_manifest": (_model["blueprint"] as Dictionary)["initializer_manifest"],
		"initializer_manifest_sha256":
		String((_model["blueprint"] as Dictionary)["initializer_manifest_sha256"]),
		"initializer_readback": _model["initializer_readback"],
		"strict_host_cap_projection_by_actuator_id":
		(_model["host_cap_projection_by_actuator_id"] as Dictionary).duplicate(true),
		"initialization_receipt": _initialization_receipt.duplicate(true),
		"initial_application": _initial_application.duplicate(true),
		"declared_initial_state_sha256": initial_state_sha256,
		"trace_v3": trace,
		"trace_v3_sha256": trace_sha256,
		"in_run_invariant_receipts": _arm_invariant_receipts.duplicate(true),
		"portable_step_receipts": _arm_step_receipts.duplicate(true),
		"planned_control_receipts": _arm_control_receipts.duplicate(true),
		"command_application_receipts": _arm_application_receipts.duplicate(true),
		"final_memory": _memory.duplicate(true),
		"final_phase": String(_memory.get("phase", "")),
		"terminal_failure_code": _memory.get("terminal_failure_code"),
		"terminal_reached": terminal_reached,
		"budget_exhausted": not terminal_reached,
		"outer_step_count": _arm_observations.size(),
		"native_solver_step_count": int(_model.get("solver_step_count", -1)),
		"in_run_invariant_receipt_count": _arm_invariant_receipts.size(),
		"model_construction_count": 1,
		"world_attempt_count": 1,
		"world_build_count": 1,
		"post_initialization_intervention_count": 0,
		"physics_state_modified": true,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if bool(_context.get("contiguous_boundary_transport_profile_selected", false)):
		result["boundary_transport_initializer_receipt"] = (
			_model.get("boundary_transport_initializer_receipt", {}) as Dictionary
		).duplicate(true)
		result["boundary_transport_terminal_state"] = (
			_model.get("contiguous_boundary_transport_state", {}) as Dictionary
		).duplicate(true)
	if _recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID:
		if not development_progression_population_valid_v1(
			_arm_development_progression_receipts,
			_arm_observations.size(),
			_recovery_controller_id,
		):
			_abort(
				_failure_code("BEHAVIOR_DEVELOPMENT_PROGRESSION_POPULATION_INVALID"),
				{
					"observation_count": _arm_observations.size(),
					"development_progression_receipt_count":
					_arm_development_progression_receipts.size(),
				},
			)
			return
		result["production_advance_dispatch_id"] = (production_advance_dispatch_id_for_route_v1(
			_energy_route_id
		))
		result["selected_portable_advance_route"] = (selected_advance_route_for_energy_route_v1(
			_energy_route_id
		))
		result["development_progression_receipts"] = (
			_arm_development_progression_receipts.duplicate(true)
		)
		result["development_progression_receipt_count"] = (
			_arm_development_progression_receipts.size()
		)
		result["development_progression_used_count"] = _true_field_count(
			_arm_development_progression_receipts,
			"development_progression_used",
		)
		result["stance_observation_binding_receipts"] = (
			_arm_stance_observation_binding_receipts.duplicate(true)
		)
		result["stance_observation_binding_receipt_count"] = (
			_arm_stance_observation_binding_receipts.size()
		)
	if (
		int(result["outer_step_count"]) < 1
		or int(result["outer_step_count"]) > MAXIMUM_OUTER_STEPS_PER_ARM
		or int(result["native_solver_step_count"]) != int(result["outer_step_count"])
		or int(result["in_run_invariant_receipt_count"]) != int(result["outer_step_count"])
	):
		_abort(_failure_code("BEHAVIOR_ARM_RESULT_INVALID"), result)
		return
	_arm_results[arm_kind] = result
	_emit_progress("arm_result_complete", arm_kind, int(result["outer_step_count"]))
	RouteScript.cleanup_native_world_v1(_model)
	_model = {}
	call_deferred("_continue_after_arm_cleanup")


func _continue_after_arm_cleanup() -> void:
	await process_frame
	await process_frame
	_transitioning = false
	if _arm_index + 1 < ARM_ORDER.size():
		await _start_arm(_arm_index + 1)
		return
	_finalize_pair()


func _finalize_pair() -> void:
	if not _arm_results.has("candidate_command") or not _arm_results.has("matched_zero_command"):
		_abort(_failure_code("BEHAVIOR_ARM_POPULATION_INCOMPLETE"))
		return
	var candidate: Dictionary = _arm_results["candidate_command"]
	var matched_zero: Dictionary = _arm_results["matched_zero_command"]
	if (
		(
			String(candidate["declared_initial_state_sha256"])
			!= String(matched_zero["declared_initial_state_sha256"])
		)
		or _total_model_construction_count != 2
		or _total_world_attempt_count != 2
		or _total_world_build_count != 2
		or _total_solver_step_count < 2
		or _total_solver_step_count > MAXIMUM_TOTAL_OUTER_STEPS
		or _observed_solver_step_boundaries != _total_solver_step_count
	):
		_abort(
			_failure_code("BEHAVIOR_PAIR_IDENTITY_OR_BUDGET_INVALID"),
			{
				"candidate_initial_state_sha256": candidate["declared_initial_state_sha256"],
				"matched_zero_initial_state_sha256": matched_zero["declared_initial_state_sha256"],
				"model_construction_count": _total_model_construction_count,
				"world_attempt_count": _total_world_attempt_count,
				"world_build_count": _total_world_build_count,
				"solver_step_count": _total_solver_step_count,
				"observed_solver_step_boundaries": _observed_solver_step_boundaries,
			},
		)
		return
	_emit_progress("pair_evaluation_started")
	var evaluated := production_evaluation_dispatch_v1(
		_sdk,
		_context,
		candidate["trace_v3"],
		matched_zero["trace_v3"],
		_recovery_controller_id,
		_energy_route_id,
	)
	if not bool(evaluated.get("ok", false)):
		_abort(_failure_code("BEHAVIOR_EVALUATOR_FAILED"), evaluated)
		return
	if not production_evaluation_receipt_valid_v1(
		evaluated,
		_recovery_controller_id,
		_energy_route_id,
	):
		_abort(_failure_code("BEHAVIOR_EVALUATOR_DISPATCH_INVALID"), evaluated)
		return
	var evaluation: Dictionary = evaluated["evaluation_receipt"]
	var acceptance := RouteScript.validate_physical_evaluation_receipt_v1(evaluation)
	if not bool(acceptance.get("ok", false)):
		_abort(
			_failure_code("BEHAVIOR_EVALUATOR_RECEIPT_INVALID"),
			{
				"acceptance_receipt": acceptance,
				"evaluation_receipt": evaluation,
			},
		)
		return
	var verdict := String(evaluation.get("verdict", ""))
	var claimed := bool(evaluation.get("prone_to_standing_claimed", false))
	var physical_result := bool(evaluation.get("physical_result", false))
	if claimed != physical_result or (claimed and verdict != "physical_development_passed"):
		_abort(
			_failure_code("BEHAVIOR_CLAIM_CONJUNCTION_INVALID"),
			{
				"acceptance_receipt": acceptance,
				"evaluation_receipt": evaluation,
			},
		)
		return
	var arm_execution_summary := (
		RouteScript
		. compact_behavior_arm_invariant_summary_v1(
			_sdk,
			_arm_results,
			ARM_ORDER,
			_total_solver_step_count,
		)
	)
	if not bool(arm_execution_summary.get("ok", false)):
		_abort(
			_failure_code("BEHAVIOR_ARM_INVARIANT_SUMMARY_INVALID"),
			arm_execution_summary,
		)
		return
	var report := {
		"schema_version": _raw_schema,
		"gate_id": _gate_id,
		"work_id": _work_id,
		"ledger_prefix": "[recovery/godot]",
		"question_class": "development",
		"recovery_controller_id": _recovery_controller_id,
		"status": "valid_complete_behavior_development",
		"ok": true,
		"scientific_outcome":
		(
			"positive"
			if physical_result
			else ("incomplete" if verdict == "physical_development_incomplete" else "negative")
		),
		"source_commit": OS.get_environment(_source_commit_env),
		"attempt_id": OS.get_environment(_attempt_id_env),
		"authorization_sha256": OS.get_environment(_authorization_env),
		"cell_id": "r24d65_godot_development_exact_nominal",
		"seed": _seed,
		"seed_label": _seed_label,
		"seed_sha256": _seed_sha256,
		"actuator_mode": _actuator_mode,
		"energy_route_id": _energy_route_id,
		"complete_energy_profile_selected": complete_energy_route_selected_v1(_energy_route_id),
		"solver_coupled_complete_energy_profile_selected":
		solver_coupled_complete_energy_route_selected_v1(_energy_route_id),
		"discrete_staging_complete_energy_profile_selected":
		discrete_staging_complete_energy_route_selected_v1(_energy_route_id),
		"route_aware_application_provenance_selected":
		route_aware_application_provenance_selected_v1(_context),
		"actuator_mapping_id":
		actuator_mapping_id_for_route_v1(
			_actuator_mode,
			_energy_route_id,
		),
		"work_mapping_id":
		work_mapping_id_for_route_v1(
			_actuator_mode,
			_energy_route_id,
		),
		"actuation_realization_id":
		actuation_realization_id_for_route_v1(
			_actuator_mode,
			_energy_route_id,
		),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"outer_step_duration_s": 1.0 / float(PHYSICS_HZ),
		"held_out": false,
		"population_inference_claimed": false,
		"full_seeded_world_demo": true,
		"recovery_success_required_for_valid_result": false,
		"recovery_success_observed": physical_result,
		"behavior_evaluator_invocation_count": 1,
		"production_evaluation_dispatch_id": evaluated["production_evaluation_dispatch_id"],
		"selected_portable_evaluation_route": evaluated["selected_portable_evaluation_route"],
		"development_replay_authority_required": evaluated["development_replay_authority_required"],
		"threshold_profile_id": RouteScript.THRESHOLD_PROFILE_ID,
		"threshold_profile_sha256":
		"sha256:3081621eb53f4d67bc1d8dc0f3a7d3ad7ae5ed829f902bce60b01ba1530bfb34",
		"maximum_energy_balance_residual_j": 0.25,
		"required_stance_dwell_steps": 60,
		"stance_dwell_timeout_steps": 240,
		"maximum_outer_steps_per_arm": MAXIMUM_OUTER_STEPS_PER_ARM,
		"maximum_total_outer_steps": MAXIMUM_TOTAL_OUTER_STEPS,
		"candidate_arm": candidate,
		"matched_zero_arm": matched_zero,
		"evaluation_request_sha256": evaluated["request_sha256"],
		"evaluation_receipt": evaluation,
		"evaluation_acceptance_receipt": acceptance,
		"arm_execution_summary": arm_execution_summary,
		"complete_trace_count": 2,
		"in_run_invariant_receipt_count": _total_solver_step_count,
		"all_in_run_physical_invariants_passed": true,
		"held_out_cell_access_count": 0,
		"model_construction_attempt_count": _total_model_construction_attempt_count,
		"native_scene_node_construction_attempted": true,
		"model_construction_count": _total_model_construction_count,
		"world_attempt_count": _total_world_attempt_count,
		"world_build_count": _total_world_build_count,
		"solver_step_count": _total_solver_step_count,
		"maximum_solver_step_count": MAXIMUM_TOTAL_OUTER_STEPS,
		"physics_state_modified": true,
		"physical_question_opened": true,
		"physics_failure_is_valid_evidence": true,
		"prone_to_standing_claimed": claimed,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if _recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID:
		report["production_advance_dispatch_id"] = (production_advance_dispatch_id_for_route_v1(
			_energy_route_id
		))
		report["selected_portable_advance_route"] = (selected_advance_route_for_energy_route_v1(
			_energy_route_id
		))
		report["development_progression_receipt_count"] = (
			int(candidate.get("development_progression_receipt_count", -1))
			+ int(matched_zero.get("development_progression_receipt_count", -1))
		)
		report["development_progression_used_count"] = (
			int(candidate.get("development_progression_used_count", -1))
			+ int(matched_zero.get("development_progression_used_count", -1))
		)
		report["stance_observation_binding_receipt_count"] = (
			int(candidate.get("stance_observation_binding_receipt_count", -1))
			+ int(matched_zero.get("stance_observation_binding_receipt_count", -1))
		)
		report["evaluation_energy_partition_authority_sha256"] = (evaluated["energy_partition_authority_sha256"])
		if complete_energy_route_selected_v1(_energy_route_id):
			report["complete_energy_authority_profile_id"] = (
				RouteScript.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
				if discrete_staging_complete_energy_route_selected_v1(_energy_route_id)
				else (
					RouteScript.R144_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
					if solver_coupled_complete_energy_route_selected_v1(_energy_route_id)
					else RouteScript.R136_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
				)
			)
			report["complete_energy_in_run_invariant_receipt_count"] = (_total_solver_step_count)
			if discrete_staging_complete_energy_route_selected_v1(_energy_route_id):
				report["discrete_staging_in_run_invariant_receipt_count"] = (_total_solver_step_count)
				report["adapter_side_discrete_staging_event_count"] = (_total_solver_step_count)
				if route_aware_application_provenance_selected_v1(_context):
					report["application_provenance_profile_id"] = (
						RouteScript.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
					)
	if bool(_context.get("contiguous_boundary_transport_profile_selected", false)):
		var candidate_initializer: Dictionary = candidate.get(
			"boundary_transport_initializer_receipt", {}
		)
		var matched_initializer: Dictionary = matched_zero.get(
			"boundary_transport_initializer_receipt", {}
		)
		var candidate_transport_state: Dictionary = candidate.get(
			"boundary_transport_terminal_state", {}
		)
		var matched_transport_state: Dictionary = matched_zero.get(
			"boundary_transport_terminal_state", {}
		)
		report["contiguous_boundary_transport_profile_selected"] = true
		report["contiguous_boundary_transport_design_id"] = String(
			_context.get("contiguous_boundary_transport_design_id", "")
		)
		report["contiguous_boundary_transport_profile_id"] = String(
			_context.get("contiguous_boundary_transport_profile_id", "")
		)
		report["boundary_transport_state_schema_version"] = String(
			_context.get("boundary_transport_state_schema_version", "")
		)
		report["boundary_transport_pair_schema_version"] = String(
			_context.get("boundary_transport_pair_schema_version", "")
		)
		report["legacy_aliased_boundary_transport_selected"] = bool(
			_context.get("legacy_aliased_boundary_transport_selected", true)
		)
		report["boundary_transport_initializer_native_readback_count"] = (
			int(candidate_initializer.get("native_readback_count", -1))
			+ int(matched_initializer.get("native_readback_count", -1))
		)
		report["boundary_transport_completed_boundary_count"] = _total_solver_step_count
		report["boundary_transport_cache_advance_commit_count"] = _total_solver_step_count
		report["candidate_boundary_transport_terminal_cached_sequence"] = int(
			candidate_transport_state.get("cached_boundary_sequence", -1)
		)
		report["candidate_boundary_transport_terminal_accepted_pair_count"] = int(
			candidate_transport_state.get("accepted_pair_count", -1)
		)
		report["candidate_boundary_transport_terminal_state_revision"] = int(
			candidate_transport_state.get("state_revision", -1)
		)
		report["matched_zero_boundary_transport_terminal_cached_sequence"] = int(
			matched_transport_state.get("cached_boundary_sequence", -1)
		)
		report["matched_zero_boundary_transport_terminal_accepted_pair_count"] = int(
			matched_transport_state.get("accepted_pair_count", -1)
		)
		report["matched_zero_boundary_transport_terminal_state_revision"] = int(
			matched_transport_state.get("state_revision", -1)
		)
	_emit_progress("raw_serialization_started")
	print(_raw_marker, JsonTransportScript.stringify(report))
	_schedule_exit(0, "valid_complete_behavior_development")


static func _true_field_count(rows: Array, field: String) -> int:
	var count := 0
	for value in rows:
		if value is Dictionary:
			count += int(bool((value as Dictionary).get(field, false)))
	return count


func _invariant_receipt_valid(receipt: Dictionary, semantic_step: int) -> bool:
	if (
		int(receipt.get("semantic_step", -1)) != semantic_step
		or int(receipt.get("native_space_step_sequence", -1)) != semantic_step
		or not adapter_side_discrete_staging_event_count_valid_v2(
			_context,
			_energy_route_id,
			semantic_step,
			int(receipt.get("adapter_side_discrete_staging_event_count", -1)),
		)
		or int(receipt.get("missing_measurement_synthesis_count", -1)) != 0
		or not bool(receipt.get("all_in_run_physical_invariants_passed", false))
		or not _valid_sha256(String(receipt.get("application_receipt_sha256", "")))
		or not _valid_sha256(String(receipt.get("direct_state_source_sha256", "")))
		or not _valid_sha256(String(receipt.get("contact_source_sha256", "")))
		or not _valid_sha256(String(receipt.get("telemetry_source_sha256", "")))
		or not _valid_sha256(String(receipt.get("native_engine_health_receipt_sha256", "")))
		or not bool(receipt.get("native_engine_health_passed", false))
		or not _valid_sha256(String(receipt.get("source_trace_sha256", "")))
		or not _valid_sha256(String(receipt.get("observation_sha256", "")))
	):
		return false
	var native_engine_health_value: Variant = receipt.get("native_engine_health_receipt")
	if not (native_engine_health_value is Dictionary):
		return false
	var native_engine_health: Dictionary = native_engine_health_value
	if (
		(
			_canonical_sha256(native_engine_health)
			!= String(receipt["native_engine_health_receipt_sha256"])
		)
		or not _native_engine_health_receipt_valid(native_engine_health, semantic_step)
	):
		return false
	if complete_energy_route_selected_v1(_energy_route_id):
		if (
			(
				String(receipt.get("schema_version", ""))
				!= complete_energy_invariant_schema_v5(
					_energy_route_id,
					_context,
				)
			)
			or String(receipt.get("energy_route_id", "")) != _energy_route_id
			or not _valid_sha256(String(receipt.get("complete_energy_inputs_receipt_sha256", "")))
			or not _valid_sha256(String(receipt.get("solver_energy_exchange_receipt_sha256", "")))
			or not bool(receipt.get("constraint_exchange_partition_complete", false))
			or not bool(receipt.get("passive_dissipation_partition_complete", false))
			or not bool(receipt.get("component_partition_complete", false))
			or not bool(receipt.get("exact_balance_safety_authority", false))
			or bool(receipt.get("residual_balancing_permitted", true))
			or not bool(receipt.get("complete_energy_invariants_passed", false))
		):
			return false
	if discrete_staging_complete_energy_route_selected_v1(_energy_route_id):
		if (
			String(receipt.get("discrete_staging_rule_id", "")) != RouteScript.R148_STAGING_RULE_ID
			or not _valid_sha256(
				String(receipt.get("discrete_staging_observer_receipt_sha256", ""))
			)
			or not _valid_sha256(String(receipt.get("discrete_staging_mapping_receipt_sha256", "")))
			or not _valid_sha256(
				String(receipt.get("discrete_staging_accumulator_before_sha256", ""))
			)
			or not _valid_sha256(
				String(receipt.get("discrete_staging_accumulator_after_sha256", ""))
			)
			or not is_finite(float(receipt.get("step_signed_discrete_staging_exchange_j", NAN)))
			or not is_finite(
				float(receipt.get("cumulative_signed_discrete_staging_exchange_j", NAN))
			)
			or not bool(receipt.get("discrete_staging_invariants_passed", false))
		):
			return false
		if (
			accumulator_aware_invariant_validation_selected_v1(_context)
			and (
				String(receipt.get("in_run_invariant_validator_profile_id", ""))
				!= RouteScript.R154_ACCUMULATOR_AWARE_INVARIANT_VALIDATOR_PROFILE_ID
			)
		):
			return false
		if route_aware_application_provenance_selected_v1(_context) and (
			String(receipt.get("application_provenance_profile_id", ""))
			!= RouteScript.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
			or String(receipt.get("native_application_receipt_schema", ""))
			!= "sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_native_application_receipt_v1"
			or not native_source_trace_schema_valid_v1(
				_context,
				String(receipt.get("native_source_trace_schema", "")),
			)
			or not bool(
				receipt.get("route_aware_application_provenance_invariants_passed", false)
			)
		):
			return false
		if rotation_aware_behavior_ledger_selected_v1(_context) and (
			String(receipt.get("recovery_energy_ledger_profile_id", ""))
			!= RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
			or not bool(
				receipt.get("rotation_integration_exchange_included_exactly_once", false)
			)
			or not bool(receipt.get("rotation_aware_energy_ledger_invariants_passed", false))
		):
			return false
		if rotation_aware_native_source_trace_validation_selected_v1(_context) and (
			String(receipt.get("native_source_trace_validator_profile_id", ""))
			!= RouteScript.R165_ROTATION_AWARE_SOURCE_TRACE_VALIDATOR_PROFILE_ID
			or not bool(
				receipt.get("rotation_aware_native_source_trace_schema_valid", false)
			)
		):
			return false
		if bool(_context.get("contiguous_boundary_transport_profile_selected", false)) and (
			String(receipt.get("boundary_transport_capture_schema_version", ""))
			!= "sporespore_qsdk_r24d168_godot_jolt_contiguous_body_boundary_capture_v1"
			or String(receipt.get("boundary_transport_design_id", ""))
			!= String(_context.get("contiguous_boundary_transport_design_id", ""))
			or String(receipt.get("boundary_transport_profile_id", ""))
			!= String(_context.get("contiguous_boundary_transport_profile_id", ""))
			or not _valid_sha256(
				String(receipt.get("boundary_transport_capture_sha256", ""))
			)
			or int(receipt.get("boundary_transport_previous_sequence", -1))
			!= semantic_step - 1
			or int(receipt.get("boundary_transport_state_revision_before", -1))
			!= semantic_step - 1
			or int(receipt.get("boundary_transport_state_revision_after", -1))
			!= semantic_step
			or String(receipt.get("boundary_transport_pre_boundary_source_kind", ""))
			!= (
				"inactive_physics_initializer_readback_v1"
				if semantic_step == 1
				else "completed_step_direct_state_callback_v1"
			)
			or String(receipt.get("boundary_transport_post_boundary_source_kind", ""))
			!= "completed_step_direct_state_callback_v1"
			or int(receipt.get("boundary_transport_cache_advance_count_pending_commit", -1))
			!= 1
			or not bool(
				receipt.get("boundary_transport_cache_advance_committed", false)
			)
			or not bool(receipt.get("boundary_transport_source_measurement", false))
			or bool(
				receipt.get(
					"boundary_transport_mechanical_energy_change_used_as_input", true
				)
			)
			or bool(
				receipt.get(
					"boundary_transport_energy_balance_residual_used_as_input", true
				)
			)
			or bool(
				receipt.get(
					"boundary_transport_acceptance_threshold_used_as_input", true
				)
			)
			or bool(
				receipt.get(
					"boundary_transport_controller_or_behavior_result_used_as_input", true
				)
			)
		):
			return false
	var external: Dictionary = receipt["external_interventions"]
	for value in external.values():
		if int(value) != 0:
			return false
	var ownership: Dictionary = receipt["controller_ownership"]
	return (
		not bool(ownership.get("fallback_controller_active", true))
		and bool(ownership.get("source_measurement", false))
	)


static func adapter_side_discrete_staging_event_count_valid_v2(
	context: Dictionary,
	energy_route_id: String,
	semantic_step: int,
	observed_event_count: int,
) -> bool:
	if semantic_step <= 0:
		return false
	if not discrete_staging_complete_energy_route_selected_v1(energy_route_id):
		return observed_event_count == 0
	if accumulator_aware_invariant_validation_selected_v1(context):
		return observed_event_count == semantic_step
	return observed_event_count == 1


func _native_engine_health_receipt_valid(
	receipt: Dictionary,
	semantic_step: int,
) -> bool:
	var maximum := float(receipt.get("effective_max_angular_velocity_rad_s", NAN))
	var rows_value: Variant = receipt.get("ordered_body_measurements")
	if (
		(
			String(receipt.get("schema_version", ""))
			!= NativeWorldScript.BODY_ANGULAR_VELOCITY_LIMIT_RECEIPT_SCHEMA
		)
		or not bool(receipt.get("ok", false))
		or int(receipt.get("semantic_step", -1)) != semantic_step
		or (
			String(receipt.get("comparison_rule", ""))
			!= "angular_speed_norm_lte_effective_runtime_limit"
		)
		or (
			int(receipt.get("body_measurement_count", -1))
			!= NativeWorldScript.ORDERED_BODY_IDS.size()
		)
		or int(receipt.get("within_limit_count", -1)) != NativeWorldScript.ORDERED_BODY_IDS.size()
		or not bool(receipt.get("native_engine_health_passed", false))
		or not bool(receipt.get("source_measurement", false))
		or not is_finite(maximum)
		or maximum <= 0.0
		or not (rows_value is Array)
	):
		return false
	var rows: Array = rows_value
	if rows.size() != NativeWorldScript.ORDERED_BODY_IDS.size():
		return false
	for index in rows.size():
		var row_value: Variant = rows[index]
		if not (row_value is Dictionary):
			return false
		var row: Dictionary = row_value
		var speed := float(row.get("angular_speed_rad_s", NAN))
		if (
			String(row.get("body_id", "")) != String(NativeWorldScript.ORDERED_BODY_IDS[index])
			or int(row.get("callback_sequence", -1)) != semantic_step
			or not bool(row.get("within_effective_runtime_limit", false))
			or not bool(row.get("source_measurement", false))
			or not is_finite(speed)
			or speed < 0.0
			or speed > maximum
			or float(row.get("effective_max_angular_velocity_rad_s", NAN)) != maximum
		):
			return false
	return true


func _canonical_sha256(value: Variant) -> String:
	var receipt := RecoveryRuntimeScript.canonicalize(_sdk, value)
	return String(receipt.get("sha256", ""))


func _terminal_summary_arm_results() -> Dictionary:
	var results := _arm_results.duplicate(true)
	if (
		_sdk == null
		or _arm_index < 0
		or _arm_index >= ARM_ORDER.size()
		or _arm_observations.is_empty()
	):
		return results
	var arm_kind := String(ARM_ORDER[_arm_index])
	if results.has(arm_kind):
		return results
	var initial_state_sha256 := RouteScript.initial_state_sha256_v1(_sdk, _arm_observations[0])
	var partial_trace := {
		"schema_version": "sporespore_recovery_trace_v3",
		"arm_kind": arm_kind,
		"declared_initial_state_sha256": initial_state_sha256,
		"observations": _arm_observations.duplicate(true),
	}
	results[arm_kind] = {
		"arm_kind": arm_kind,
		"outer_step_count": _arm_observations.size(),
		"native_solver_step_count": int(_model.get("solver_step_count", _arm_observations.size())),
		"in_run_invariant_receipt_count": _arm_invariant_receipts.size(),
		"in_run_invariant_receipts": _arm_invariant_receipts.duplicate(true),
		"final_phase": String(_memory.get("phase", "")),
		"terminal_failure_code": _memory.get("terminal_failure_code"),
		"trace_v3_sha256": _canonical_sha256(partial_trace),
		"declared_initial_state_sha256": initial_state_sha256,
	}
	return results


func _abort(code: String, detail: Dictionary = {}) -> void:
	PhysicsServer3D.set_active(false)
	if physics_frame.is_connected(_on_physics_frame):
		physics_frame.disconnect(_on_physics_frame)
	var terminal_arm_results := _terminal_summary_arm_results()
	var strict_host_cap_projection_by_actuator_id: Dictionary = {}
	if not _model.is_empty():
		strict_host_cap_projection_by_actuator_id = (
			(_model.get("host_cap_projection_by_actuator_id", {}) as Dictionary).duplicate(true)
		)
		_total_model_construction_attempt_count = maxi(
			_total_model_construction_attempt_count,
			int(_model.get("model_construction_attempt_count", 0)),
		)
		_total_world_attempt_count = maxi(
			_total_world_attempt_count,
			int(_model.get("world_attempt_count", 0)),
		)
		RouteScript.cleanup_native_world_v1(_model)
		_model = {}
	var solver_steps := maxi(_total_solver_step_count, _observed_solver_step_boundaries)
	var arm_execution_summary := (
		RouteScript
		. compact_behavior_arm_invariant_summary_v1(
			_sdk,
			terminal_arm_results,
			ARM_ORDER,
			solver_steps,
		)
	)
	var report := {
		"schema_version": _raw_schema,
		"gate_id": _gate_id,
		"work_id": _work_id,
		"ledger_prefix": "[recovery/godot]",
		"question_class": "development",
		"recovery_controller_id": _recovery_controller_id,
		"status": "invalid_or_incomplete_behavior_development",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"arm_execution_summary": arm_execution_summary,
		"source_commit": OS.get_environment(_source_commit_env),
		"attempt_id": OS.get_environment(_attempt_id_env),
		"authorization_sha256": OS.get_environment(_authorization_env),
		"cell_id": "r24d65_godot_development_exact_nominal",
		"seed": _seed,
		"seed_label": _seed_label,
		"seed_sha256": _seed_sha256,
		"actuator_mode": _actuator_mode,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"outer_step_duration_s": 1.0 / float(PHYSICS_HZ),
		"held_out": false,
		"population_inference_claimed": false,
		"recovery_success_required_for_valid_result": false,
		"behavior_evaluator_invocation_count": 0,
		"strict_host_cap_projection_by_actuator_id": strict_host_cap_projection_by_actuator_id,
		"held_out_cell_access_count": 0,
		"model_construction_attempt_count": _total_model_construction_attempt_count,
		"model_construction_count": _total_model_construction_count,
		"world_attempt_count": _total_world_attempt_count,
		"world_build_count": _total_world_build_count,
		"solver_step_count": solver_steps,
		"maximum_solver_step_count": MAXIMUM_TOTAL_OUTER_STEPS,
		"physics_state_modified": solver_steps > 0,
		"physical_question_opened": _total_world_attempt_count > 0,
		"physics_failure_is_valid_evidence": true,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	_emit_progress(
		"failure_serialization_started",
		String(ARM_ORDER[_arm_index]) if _arm_index >= 0 and _arm_index < ARM_ORDER.size() else "",
		_arm_observations.size(),
	)
	print(_raw_marker, JsonTransportScript.stringify(report))
	_schedule_exit(1, "invalid_or_incomplete_behavior_development")


func _schedule_exit(exit_code: int, receipt_kind: String) -> void:
	if _exit_scheduled:
		return
	_exit_scheduled = true
	_pending_exit_code = exit_code
	_pending_receipt_kind = receipt_kind
	_pending_exit_process_frames = EXIT_DRAIN_PROCESS_FRAME_COUNT
	process_frame.connect(_orderly_exit_process_frame, CONNECT_ONE_SHOT)


## Progress receipts are liveness-only. They never substitute for the final raw
## receipt, never authorize a physics inference, and never enter the evaluator.
func _emit_progress(milestone: String, arm_kind: String = "", arm_step_count: int = 0) -> void:
	if _progress_marker.is_empty():
		return
	_progress_sequence += 1
	print(
		_progress_marker,
		(
			JsonTransportScript
			. stringify(
				{
					"schema_version": "sporespore_godot_supervised_progress_v1",
					"progress_protocol_id": PROGRESS_PROTOCOL_ID,
					"termination_nonce": OS.get_environment(_nonce_env),
					"process_id": OS.get_process_id(),
					"gate_id": _gate_id,
					"question_class": "development",
					"source_commit": OS.get_environment(_source_commit_env),
					"attempt_id": OS.get_environment(_attempt_id_env),
					"authorization_sha256": OS.get_environment(_authorization_env),
					"seed": _seed,
					"seed_sha256": _seed_sha256,
					"progress_sequence": _progress_sequence,
					"milestone": milestone,
					"arm_kind": arm_kind,
					"arm_step_count": arm_step_count,
					"completed_solver_step_count": _total_solver_step_count,
					"maximum_solver_step_count": MAXIMUM_TOTAL_OUTER_STEPS,
					"physics_evidence_authority": false,
					"physical_acceptance_authority": false,
					"release_authority": false,
				}
			)
		),
	)


func _orderly_exit_process_frame() -> void:
	_pending_exit_process_frames -= 1
	if _pending_exit_process_frames > 0:
		process_frame.connect(_orderly_exit_process_frame, CONNECT_ONE_SHOT)
		return
	if OS.get_environment(_supervised_env) == "1":
		var nonce := OS.get_environment(_nonce_env)
		if nonce.is_empty():
			quit(1)
			return
		print(
			_ready_marker,
			(
				JsonTransportScript
				. stringify(
					{
						"schema_version": "sporespore_godot_supervised_termination_ready_v1",
						"termination_protocol_id": TERMINATION_PROTOCOL_ID,
						"termination_nonce": nonce,
						"process_id": OS.get_process_id(),
						"requested_exit_code": _pending_exit_code,
						"worker_receipt_kind": _pending_receipt_kind,
						"worker_receipt_emitted": true,
						"drained_process_frame_count": EXIT_DRAIN_PROCESS_FRAME_COUNT,
						"physics_evidence_authority": false,
					}
				)
			),
		)
		return
	quit(_pending_exit_code)


func _load_campaign_binding() -> bool:
	var configured_gate := OS.get_environment(GENERIC_GATE_ID_ENV)
	if configured_gate.is_empty():
		return true
	var configured_token := OS.get_environment(GENERIC_GATE_TOKEN_ENV)
	var configured_schema := OS.get_environment(GENERIC_RAW_SCHEMA_ENV)
	var configured_work_id := OS.get_environment(GENERIC_WORK_ID_ENV)
	var configured_raw_marker := OS.get_environment(GENERIC_RAW_MARKER_ENV)
	var configured_ready_marker := OS.get_environment(GENERIC_READY_MARKER_ENV)
	var configured_progress_marker := OS.get_environment(GENERIC_PROGRESS_MARKER_ENV)
	var configured_progress_cadence := OS.get_environment(GENERIC_PROGRESS_CADENCE_ENV)
	var configured_seed := OS.get_environment(GENERIC_SEED_ENV)
	var configured_seed_label := OS.get_environment(GENERIC_SEED_LABEL_ENV)
	var configured_seed_sha := OS.get_environment(GENERIC_SEED_SHA_ENV)
	var configured_actuator_mode := OS.get_environment(GENERIC_ACTUATOR_MODE_ENV)
	var configured_controller_id := OS.get_environment(GENERIC_CONTROLLER_ID_ENV)
	var configured_energy_route_id := OS.get_environment(GENERIC_ENERGY_ROUTE_ID_ENV)
	if configured_controller_id.is_empty():
		configured_controller_id = RouteScript.RECOVERY_CONTROLLER_ID
	if configured_energy_route_id.is_empty():
		configured_energy_route_id = RouteScript.ROUTE_ID
	if (
		not configured_gate.begins_with("QSDK-R")
		or configured_token.is_empty()
		or configured_gate != "QSDK-%s" % configured_token
		or not configured_schema.begins_with("sporespore_qsdk_")
		or configured_work_id.is_empty()
		or configured_raw_marker.is_empty()
		or configured_ready_marker.is_empty()
		or (configured_progress_marker.is_empty() and configured_progress_cadence not in ["", "0"])
		or (
			not configured_progress_marker.is_empty()
			and (
				not configured_progress_cadence.is_valid_int()
				or configured_progress_cadence.to_int() < 1
				or configured_progress_cadence.to_int() > MAXIMUM_OUTER_STEPS_PER_ARM
			)
		)
		or not configured_seed.is_valid_int()
		or configured_seed.to_int() == 0
		or configured_seed_label.is_empty()
		or not _valid_sha256(configured_seed_sha)
		or (
			configured_actuator_mode
			not in [
				ACTUATOR_MODE_LEGACY,
				ACTUATOR_MODE_SOLVER_COUPLED,
				ACTUATOR_MODE_FORCE_BASED,
				ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED,
				ACTUATOR_MODE_FORCE_BASED_COMPONENT_NORM_NESTED_GUARDED,
				ACTUATOR_MODE_FORCE_BASED_REFINEMENT_SAFE_COMPONENT_NORM_NESTED_GUARDED,
				ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED,
				ACTUATOR_MODE_FORCE_BASED_JOINT_TARGET_MONOTONE_POPULATION_GUARDED,
				ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED,
			]
		)
		or (
			configured_controller_id
			not in [
				RouteScript.RECOVERY_CONTROLLER_ID,
				RouteScript.RECOVERY_CONTROLLER_V2_ID,
				RouteScript.RECOVERY_CONTROLLER_V3_ID,
				RouteScript.RECOVERY_CONTROLLER_V4_ID,
				RouteScript.RECOVERY_CONTROLLER_V5_ID,
				RouteScript.RECOVERY_CONTROLLER_V6_ID,
			]
		)
		or (
			configured_energy_route_id
			not in [
				RouteScript.ROUTE_ID,
				RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
				RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
				RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
			]
		)
		or not actuator_mode_controller_route_triplet_valid_v1(
			configured_actuator_mode,
			configured_controller_id,
			configured_energy_route_id,
		)
	):
		return false
	_gate_id = configured_gate
	_gate_token = configured_token
	_raw_schema = configured_schema
	_work_id = configured_work_id
	_raw_marker = configured_raw_marker
	_ready_marker = configured_ready_marker
	_progress_marker = configured_progress_marker
	_progress_cadence_steps = (
		configured_progress_cadence.to_int() if not configured_progress_marker.is_empty() else 0
	)
	_authorization_env = GENERIC_AUTHORIZATION_ENV
	_source_commit_env = GENERIC_SOURCE_COMMIT_ENV
	_attempt_id_env = GENERIC_ATTEMPT_ID_ENV
	_supervised_env = GENERIC_SUPERVISED_ENV
	_nonce_env = GENERIC_NONCE_ENV
	_seed = configured_seed.to_int()
	_seed_label = configured_seed_label
	_seed_sha256 = configured_seed_sha
	_actuator_mode = configured_actuator_mode
	_recovery_controller_id = configured_controller_id
	_energy_route_id = configured_energy_route_id
	return true


func _failure_code(suffix: String) -> String:
	return "QSDK_%s_%s" % [_gate_token, suffix]


static func _valid_sha256(value: String) -> bool:
	return (
		value.length() == 71
		and value.begins_with("sha256:")
		and value.substr(7).is_valid_hex_number(false)
	)
