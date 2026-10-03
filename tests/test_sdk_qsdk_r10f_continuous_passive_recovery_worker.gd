extends SceneTree
# gdlint: disable=max-line-length
# gdlint: disable=max-file-lines
# gdlint: disable=max-returns

## One prospective QSDK-R10F development route ghost.
##
## One L9 child builds exactly one recovery-native S169 world for exactly one
## supervisor-authorized role. A separate fresh process runs the other role.
## Within this child the same nine bodies and eight hinges survive V6
## precondition recovery, BW5R-B walking, the kick or matched no-kick event,
## the offset recovery epoch, and the role terminal boundary. Behavioral
## failure is retained as valid development evidence; malformed routing or
## measurement aborts the child as infrastructure-invalid.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const NativeWorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const NativeEpochRoute := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_native_measurement_route_v1.gd"
)
const EnergyInitializer := preload(
	"res://sdk/adapters/godot/gdscript/recovery_epoch_energy_initializer_v1.gd"
)
const LocomotionFacade := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd"
)
const NoActuationStageL15 := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_no_actuation_worker_stage_v1.gd"
)
const RecoveryAdvanceStageL15 := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_recovery_advance_stage_v1.gd"
)
const PreWorldContextL15 := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_pre_world_context_v1.gd"
)
const Orchestrator := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1.gd"
)
const PreconditionPairBarrier := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_precondition_pair_barrier_v1.gd"
)
const PreconditionTerminalDisposition := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_precondition_terminal_disposition_v1.gd"
)
const ProcessIsolatedChildContract := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_process_isolated_child_contract_v1.gd"
)
const ImpulsePairReceipt := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_native_impulse_pair_receipt_v1.gd"
)
const WalkingEvaluator := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v2.gd"
)
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const GATE_ID := "QSDK-R10F"
const GATE_TOKEN := "R10F"
const RAW_MARKER := "QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_RAW "
const READY_MARKER := "QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_READY "
const RAW_SCHEMA := "sporespore_qsdk_r10f_process_isolated_child_raw_v1"
const WORK_ID := "QSDK-R10F-L14-GODOT-JOLT-PROCESS-ISOLATED-CHILD-DEVELOPMENT"
const L15_WORK_ID := "QSDK-R10F-L15-GODOT-JOLT-PROCESS-ISOLATED-CHILD-DEVELOPMENT"
const TERMINATION_PROTOCOL_ID := "godot_4_7_gdscript_shutdown_containment_v1"
const EXIT_DRAIN_PROCESS_FRAME_COUNT := 2
const PHYSICS_HZ := 120
const ACTUATOR_MODE := "solver_coupled_native_constraint_motor_v1"
const RECOVERY_CONTROLLER_ID := "sporespore_exact_s169_prone_to_standing_controller_v6"
const ENERGY_ROUTE_ID := "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_recovery_observation_v3_route_v1"
const REPAIR_ID := "QSDK-R10F-L14"
const DEVELOPMENT_SEED := 40200
const DEVELOPMENT_SEED_LABEL := "QSDK-R10F/development/godot/event-triggered-passive-recovery-v1"
const DEVELOPMENT_SEED_SHA256 := "sha256:efa3c38b428cc5f2daa6b156a8e3e35769623c7c23af6f9079b1d27c66e190fa"
const ARM_ORDER := [EnergyInitializer.BASELINE_ARM_ID, EnergyInitializer.ACTIVE_ARM_ID]
const INTERNAL_RECOVERY_ARM_KIND := "candidate_command"
const MAXIMUM_TOTAL_SOLVER_STEPS := Orchestrator.MAXIMUM_ACTIVE_ARM_SOLVER_STEPS * 2
const MAXIMUM_CHILD_SOLVER_STEPS := Orchestrator.MAXIMUM_ACTIVE_ARM_SOLVER_STEPS
const PROCESS_ISOLATED_MATCHED_CONTINUATION_STEPS := (
	Orchestrator.MAXIMUM_POST_KICK_RECOVERY_EPOCH_STEPS + Orchestrator.WALKING_RESUME_STEPS
)
const TRACE_SCHEMA := "sporespore_qsdk_r10f_l9_process_isolated_compact_native_trace_v1"
const INVARIANT_SCHEMA := "sporespore_qsdk_r10f_in_run_native_invariant_v1"
const PRECONDITION_PAIR_APPLICATION_SCHEMA := "sporespore_qsdk_r10f_precondition_pair_barrier_application_v1"
const PRECONDITION_PAIR_APPLICATION_KEYS := [
	"schema_version",
	"gate_id",
	"repair_id",
	"ok",
	"attempt_id",
	"arm_id",
	"model_instance_id",
	"global_semantic_step",
	"action_kind",
	"terminal_source_sha256",
	"pair_plan_receipt",
	"pair_plan_receipt_sha256",
	"motor_configuration_receipt",
	"motor_configuration_receipt_sha256",
	"motor_population_readback",
	"motor_population_readback_sha256",
	"ledger_application_intent",
	"ledger_application_intent_sha256",
	"ordered_motor_readbacks",
	"control_owner",
	"actuation_owner",
	"no_actuation_requested",
	"source_measurement",
	"outcome_derived_readiness",
	"body_transform_write_count",
	"body_velocity_write_count",
	"solver_reset_count",
	"physical_acceptance_authority",
	"release_authority",
	"payload_sha256",
]

const AUTHORIZATION_ENV := "SPORESPORE_GODOT_RECOVERY_AUTHORIZATION_SHA256"
const SOURCE_COMMIT_ENV := "SPORESPORE_GODOT_RECOVERY_SOURCE_COMMIT"
const ATTEMPT_ID_ENV := "SPORESPORE_GODOT_RECOVERY_ATTEMPT_ID"
const SUPERVISED_ENV := "SPORESPORE_GODOT_RECOVERY_SUPERVISED_TERMINATION"
const NONCE_ENV := "SPORESPORE_GODOT_RECOVERY_TERMINATION_NONCE"
const GATE_ID_ENV := "SPORESPORE_GODOT_RECOVERY_GATE_ID"
const GATE_TOKEN_ENV := "SPORESPORE_GODOT_RECOVERY_GATE_TOKEN"
const RAW_SCHEMA_ENV := "SPORESPORE_GODOT_RECOVERY_RAW_SCHEMA"
const WORK_ID_ENV := "SPORESPORE_GODOT_RECOVERY_WORK_ID"
const RAW_MARKER_ENV := "SPORESPORE_GODOT_RECOVERY_RAW_MARKER"
const READY_MARKER_ENV := "SPORESPORE_GODOT_RECOVERY_READY_MARKER"
const PROGRESS_MARKER_ENV := "SPORESPORE_GODOT_RECOVERY_PROGRESS_MARKER"
const PROGRESS_CADENCE_ENV := "SPORESPORE_GODOT_RECOVERY_PROGRESS_CADENCE_STEPS"
const SEED_ENV := "SPORESPORE_GODOT_RECOVERY_SEED"
const SEED_LABEL_ENV := "SPORESPORE_GODOT_RECOVERY_SEED_LABEL"
const SEED_SHA_ENV := "SPORESPORE_GODOT_RECOVERY_SEED_SHA256"
const ACTUATOR_MODE_ENV := "SPORESPORE_GODOT_RECOVERY_ACTUATOR_MODE"
const CONTROLLER_ID_ENV := "SPORESPORE_GODOT_RECOVERY_CONTROLLER_ID"
const ENERGY_ROUTE_ID_ENV := "SPORESPORE_GODOT_RECOVERY_ENERGY_ROUTE_ID"
const PARENT_ATTEMPT_ID_ENV := "SPORESPORE_GODOT_RECOVERY_PARENT_ATTEMPT_ID"
const CHILD_ROLE_ENV := "SPORESPORE_GODOT_RECOVERY_CHILD_ROLE"

var _sdk: Object
var _context: Dictionary = {}
var _configuration: Dictionary = {}
var _configuration_sha256 := ""
var _arms: Dictionary = {}
var _lockstep_plan: Dictionary = {}
var _precondition_pair_state: Dictionary = {}
var _precondition_terminal_disposition_by_arm: Dictionary = {}
var _precondition_terminal_disposition_pair_state: Dictionary = {}
var _precondition_terminal_abort_population: Dictionary = {}
var _interaction_pair_receipt: Dictionary = {}
var _interaction_pair_source: Dictionary = {}
var _process_isolated_interaction_source: Dictionary = {}
var _process_isolated_precondition_terminal_receipt: Dictionary = {}
var _process_isolated_precondition_release_receipt: Dictionary = {}
var _interaction_scheduled := false
var _interaction_completed := false
var _physics_schedule_started := false
var _finalizing := false
var _exit_scheduled := false
var _pending_exit_code := 1
var _pending_receipt_kind := "worker_failure"
var _pending_exit_process_frames := 0
var _observed_global_solver_frames := 0
var _total_model_construction_attempt_count := 0
var _total_model_construction_count := 0
var _total_world_attempt_count := 0
var _total_world_build_count := 0
var _total_solver_step_count := 0
var _total_native_readback_count := 0
var _external_kick_application_count := 0

var _authorization_sha256 := ""
var _source_commit := ""
var _attempt_id := ""
var _parent_attempt_id := ""
var _authorized_arm_id := ""
var _termination_nonce := ""
var _raw_schema := RAW_SCHEMA
var _work_id := WORK_ID
var _repair_id := REPAIR_ID
var _raw_marker := RAW_MARKER
var _ready_marker := READY_MARKER
var _seed := DEVELOPMENT_SEED
var _seed_label := DEVELOPMENT_SEED_LABEL
var _seed_sha256 := DEVELOPMENT_SEED_SHA256


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _load_campaign_binding_v1():
		_abort("QSDK_R10F_CAMPAIGN_BINDING_INVALID")
		return
	Engine.physics_ticks_per_second = PHYSICS_HZ
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	if (
		Engine.physics_ticks_per_second != PHYSICS_HZ
		or (
			int(
				ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/velocity_steps", -1)
			)
			!= 20
		)
		or (
			int(
				ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/position_steps", -1)
			)
			!= 7
		)
	):
		_abort("QSDK_R10F_PHYSICS_CONFIGURATION_INVALID")
		return
	if not _load_runtime_extension_v1():
		_abort("QSDK_R10F_EXTENSION_UNAVAILABLE")
		return
	_sdk = ClassDB.instantiate(CLASS_NAME)
	if _sdk == null:
		_abort("QSDK_R10F_EXTENSION_INSTANTIATION_FAILED")
		return
	_context = RouteScript.prepare_complete_energy_context_v18(_sdk, RECOVERY_CONTROLLER_ID)
	if (
		not bool(_context.get("ok", false))
		or not RouteScript.contiguous_boundary_recovery_behavior_context_binding_exact_v1(
			_sdk, _context
		)
	):
		_abort("QSDK_R10F_RECOVERY_CONTEXT_INVALID", _context)
		return
	if not _verify_l15_prepared_context_before_world_v1():
		_abort(
			"QSDK_R10F_L15_PRE_WORLD_CONTEXT_INVALID",
			get_meta("l15_prepared_context_comparison", {})
		)
		return
	_configuration = LocomotionFacade.configuration_receipt_v1(_sdk)
	_configuration_sha256 = _canonical_sha256_v1(_configuration)
	if not bool(_configuration.get("ok", false)) or not _valid_sha256(_configuration_sha256):
		_abort("QSDK_R10F_CONFIGURATION_INVALID", _configuration)
		return
	seed(_seed)
	PhysicsServer3D.set_active(false)
	var setup := await _build_arm_v1(_authorized_arm_id)
	if not bool(setup.get("ok", false)):
		_abort("QSDK_R10F_L9_CHILD_ARM_SETUP_INVALID:%s" % _authorized_arm_id, setup)
		return
	if _arms.size() != 1 or not _arms.has(_authorized_arm_id):
		_abort("QSDK_R10F_L9_ONE_ARM_POPULATION_INVALID")
		return
	if not physics_frame.is_connected(_on_physics_frame):
		physics_frame.connect(_on_physics_frame)


func _verify_l15_prepared_context_before_world_v1() -> bool:
	if _repair_id != "QSDK-R10F-L15":
		return true
	var expected := PreWorldContextL15.launch_binding_v1(
		OS.get_environment(PreWorldContextL15.LENGTH_ENV),
		OS.get_environment(PreWorldContextL15.SHA_ENV)
	)
	var comparison := PreWorldContextL15.compare_prepared_v1(_sdk, _context, expected)
	set_meta("l15_prepared_context_comparison", comparison)
	return comparison.get("ok") == true


static func _initial_bootstrap_ordered_intents_valid_v1(application: Dictionary) -> bool:
	var intents_value: Variant = application.get("ordered_intents")
	if not (intents_value is Array):
		return false
	var intents: Array = intents_value
	if intents.size() != NativeWorldScript.ORDERED_ACTUATOR_IDS.size():
		return false
	for index in range(intents.size()):
		var intent_value: Variant = intents[index]
		if not (intent_value is Dictionary):
			return false
		var intent: Dictionary = intent_value
		if (
			intent.size() != 4
			or (
				String(intent.get("actuator_id", ""))
				!= String(NativeWorldScript.ORDERED_ACTUATOR_IDS[index])
			)
			or (
				String(intent.get("joint_id", ""))
				!= String(NativeWorldScript.ORDERED_JOINT_IDS[index])
			)
			or bool(intent.get("motor_enabled", true))
			or float(intent.get("host_target_velocity_rad_s", NAN)) != 0.0
		):
			return false
	return true


## The actuation-free bootstrap intent is deliberately not an active
## application receipt. Keep its consumer separate from v4, which validates
## receipts produced after apply_behavior_control_route_aware_discrete_staging_v2.
static func initial_bootstrap_application_validation_v1(
	application: Dictionary,
	expected_arm_kind: String,
	expected_phase: String,
	expected_controller_id: String,
) -> Dictionary:
	var candidate_expected := expected_arm_kind == INTERNAL_RECOVERY_ARM_KIND
	var checks := {
		"expected_input_contract":
		(
			candidate_expected
			and expected_phase in ["confirm_prone", "establish_distal_support"]
			and expected_controller_id == RECOVERY_CONTROLLER_ID
		),
		"producer_ok": bool(application.get("ok", false)),
		"bootstrap_schema_stage":
		(
			(
				String(application.get("schema_version", ""))
				== "sporespore_qsdk_r24d57_godot_application_intent_v1"
			)
			and not application.has("predecessor_route_aware_application_schema_version")
			and not application.has("predecessor_complete_energy_schema_version")
		),
		"semantic_boundary":
		(
			int(application.get("semantic_step", -1)) == 1
			and int(application.get("source_control_semantic_step", -1)) == 0
			and String(application.get("phase", "")) == expected_phase
		),
		"command_identity":
		(
			(
				String(application.get("command_id", ""))
				== "r24d62_godot_initializer_candidate_bootstrap_step_1"
			)
			and _valid_sha256_static_v1(String(application.get("command_sha256", "")))
		),
		"arm_and_controller_identity":
		(
			String(application.get("arm_kind", "")) == expected_arm_kind
			and not bool(application.get("zero_command", true))
			and String(application.get("controller_owner", "")) == "recovery"
			and String(application.get("recovery_controller_id", "")) == expected_controller_id
			and application.get("stance_controller_id", "unexpected") == null
			and int(application.get("handoff_event_count", -1)) == 0
			and not bool(application.get("fallback_controller_active", true))
		),
		"actuation_free_bootstrap":
		(
			bool(application.get("no_actuation_requested", false))
			and int(application.get("motor_enabled_count", -1)) == 0
			and bool(application.get("native_joint_motors_disabled", false))
			and bool(application.get("structural_zero_actuator_work", false))
			and bool(application.get("bootstrap_application", false))
			and String(application.get("actuator_mapping_id", "not-empty")).is_empty()
			and String(application.get("work_mapping_id", "not-empty")).is_empty()
			and int(application.get("pre_solver_direct_body_impulse_write_count", -1)) == 0
		),
		"ordered_motor_intents": _initial_bootstrap_ordered_intents_valid_v1(application),
		"solver_coupled_route_identity":
		(
			(
				String(application.get("actuation_realization_id", ""))
				== RouteScript.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID
			)
			and bool(application.get("native_contact_solver_coupled", false))
			and bool(application.get("complete_energy_profile_selected", false))
			and bool(application.get("solver_coupled_complete_energy_profile_selected", false))
		),
		"discrete_staging_route_identity":
		(
			(
				String(application.get("predecessor_complete_energy_route_id", ""))
				== RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
			)
			and String(application.get("energy_route_id", "")) == ENERGY_ROUTE_ID
			and (
				String(application.get("energy_mapping_profile_id", ""))
				== RouteScript.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
			)
			and (
				String(application.get("partition_rule_id", ""))
				== RouteScript.R144_PARTITION_RULE_ID
			)
			and bool(application.get("discrete_staging_complete_energy_profile_selected", false))
			and (
				String(application.get("complete_energy_authority_profile_id", ""))
				== RouteScript.R151_COMPLETE_ENERGY_AUTHORITY_PROFILE_ID
			)
		),
		"route_aware_provenance_identity":
		(
			String(application.get("application_provenance_profile_id", ""))
			== RouteScript.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
		),
	}
	var failed_checks: Array = []
	for check_id in checks:
		if not bool(checks[check_id]):
			failed_checks.append(String(check_id))
	return {
		"schema_version": "sporespore_qsdk_r10f_initial_bootstrap_application_validation_v1",
		"gate_id": GATE_ID,
		"ok": failed_checks.is_empty(),
		"check_count": checks.size(),
		"failed_checks": failed_checks,
		"observed_application_schema": String(application.get("schema_version", "")),
		"expected_application_schema": "sporespore_qsdk_r24d57_godot_application_intent_v1",
		"active_application_validator_applicable": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


func _build_arm_v1(arm_id: String) -> Dictionary:
	var recovery_initialization := RouteScript.initialize_behavior_arm_v1(
		_sdk, _context, INTERNAL_RECOVERY_ARM_KIND
	)
	if not bool(recovery_initialization.get("ok", false)):
		return recovery_initialization
	var model: Dictionary = await RouteScript.build_native_world_v1(self, _sdk, _context)
	_total_model_construction_attempt_count += int(model.get("model_construction_attempt_count", 0))
	_total_world_attempt_count += int(model.get("world_attempt_count", 0))
	if not bool(model.get("ok", false)):
		return model
	_total_model_construction_count += int(model.get("model_construction_count", 0))
	_total_world_build_count += int(model.get("world_build_count", 0))
	var model_instance_id := "%s:%s" % [_attempt_id, arm_id]
	var transport_initialization := (
		RouteScript
		. initialize_contiguous_boundary_transport_native_world_v1(
			_sdk,
			_context,
			model,
			_attempt_id,
			arm_id,
			model_instance_id,
		)
	)
	if (
		not bool(transport_initialization.get("ok", false))
		or not (
			RouteScript
			. contiguous_boundary_transport_initializer_receipt_retained_exact_v1(
				_sdk,
				model,
				transport_initialization,
				_attempt_id,
				arm_id,
				model_instance_id,
			)
		)
	):
		RouteScript.cleanup_native_world_v1(model)
		return {"ok": false, "failure_code": "QSDK_R10F_GLOBAL_TRANSPORT_INITIALIZATION_INVALID"}
	var facade: RefCounted = LocomotionFacade.new()
	var binding: Dictionary = facade.bind_live_model_v1(model, model_instance_id)
	if not bool(binding.get("ok", false)):
		RouteScript.cleanup_native_world_v1(model)
		return binding
	var identity: Dictionary = facade.same_body_identity_receipt_v1(
		_sdk, 0, "initial_inactive_world"
	)
	if not bool(identity.get("ok", false)):
		RouteScript.cleanup_native_world_v1(model)
		return identity
	var orchestrator_initialization := _initialize_orchestrator_v1(
		arm_id, model_instance_id, String(identity["body_population_instance_sha256"])
	)
	if not bool(orchestrator_initialization.get("ok", false)):
		RouteScript.cleanup_native_world_v1(model)
		return orchestrator_initialization
	var memory: Dictionary = (recovery_initialization["memory"] as Dictionary).duplicate(true)
	var initial_application := (
		RouteScript
		. initial_behavior_application_route_aware_discrete_staging_v2(
			_sdk,
			model,
			INTERNAL_RECOVERY_ARM_KIND,
			String(memory["phase"]),
			RECOVERY_CONTROLLER_ID,
		)
	)
	var initial_application_validation := initial_bootstrap_application_validation_v1(
		initial_application,
		INTERNAL_RECOVERY_ARM_KIND,
		String(memory["phase"]),
		RECOVERY_CONTROLLER_ID,
	)
	if not bool(initial_application_validation.get("ok", false)):
		RouteScript.cleanup_native_world_v1(model)
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_INITIAL_APPLICATION_INVALID",
			"initial_application": initial_application.duplicate(true),
			"initial_application_validation": initial_application_validation.duplicate(true),
		}
	_arms[arm_id] = {
		"arm_id": arm_id,
		"model_instance_id": model_instance_id,
		"model": model,
		"facade": facade,
		"body_population_instance_sha256": String(identity["body_population_instance_sha256"]),
		"initial_same_body_identity_receipt": identity.duplicate(true),
		"initial_application_validation_receipt": initial_application_validation.duplicate(true),
		"terminal_same_body_identity_receipt": {},
		"orchestrator_state": (orchestrator_initialization["state"] as Dictionary).duplicate(true),
		"recovery_memory": memory,
		"recovery_initialization_receipt":
		(recovery_initialization["initialization_receipt"] as Dictionary).duplicate(true),
		"postkick_recovery_initialization_receipt": {},
		"pending_application": initial_application.duplicate(true),
		"next_recovery_control": {},
		"precondition_pair_action": PreconditionPairBarrier.ACTION_RECOVERY,
		"precondition_terminal_source": {},
		"precondition_terminal_disposition": {},
		"precondition_pair_barrier_application_projection": {},
		"precondition_pair_barrier_application_projections": [],
		"last_recovery_global_semantic_step": 0,
		"last_recovery_terminal": false,
		"last_recovery_terminal_phase": "",
		"last_recovery_terminal_failure_code": "",
		"last_recovery_step_receipt": {},
		"last_recovery_classification": {},
		"trace_rows": [],
		"invariant_receipts": [],
		"recovery_step_receipts": [],
		"recovery_development_progression_receipts": [],
		"walking_sessions": [],
		"walking_actuation_handoff_receipts": [],
		"active_walking_session": {},
		"last_walking_step_failure": {},
		"last_walking_evaluation_failure": {},
		"walking_session_completion_attempted": false,
		"prefix_session_start_receipt": {},
		"last_collection": {},
		"interaction_receipt": {},
		"pre_interaction_velocity_world_m_s": [],
		"scheduled_impulse_world_n_s": [0.0, 0.0, 0.0],
		"motor_configuration_receipts": [],
		"terminal": false,
		"behavior_terminal_reason": "",
		"external_kick_application_count": 0,
		"direct_torso_force_command_count": 0,
		"direct_torso_impulse_command_count": 0,
		"direct_torso_velocity_command_count": 0,
		"direct_torso_transform_command_count": 0,
		"body_population_rebuild_count": 0,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"solver_reset_count": 0,
	}
	return {"ok": true}


func _on_physics_frame() -> void:
	if _exit_scheduled or _finalizing:
		return
	if not _physics_schedule_started:
		_physics_schedule_started = true
		PhysicsServer3D.set_active(true)
		var initial_arm: Dictionary = _arms[_authorized_arm_id]
		(initial_arm["model"] as Dictionary)["physics_server_active"] = true
		return
	_observed_global_solver_frames += 1
	var arm: Dictionary = _arms[_authorized_arm_id]
	var active_step := int((arm["model"] as Dictionary).get("host_step_count", -1)) + 1
	if (
		active_step != _observed_global_solver_frames
		or active_step < 1
		or active_step > MAXIMUM_CHILD_SOLVER_STEPS
	):
		_abort(
			"QSDK_R10F_L9_CHILD_GLOBAL_SEQUENCE_INVALID",
			{
				"arm_id": _authorized_arm_id,
				"model_step": active_step,
				"observed_global_solver_frames": _observed_global_solver_frames,
			},
		)
		return
	var phase := String((arm["orchestrator_state"] as Dictionary)["phase"])
	if phase == Orchestrator.PHASE_INTERACTION:
		var interaction_prepare := _prepare_completed_process_isolated_interaction_v1(active_step)
		if not bool(interaction_prepare.get("ok", false)):
			_abort("QSDK_R10F_L9_CHILD_INTERACTION_RECEIPT_INVALID", interaction_prepare)
			return
	var captured := _collect_arm_completed_step_v1(_authorized_arm_id, active_step)
	if not bool(captured.get("ok", false)):
		_abort("QSDK_R10F_L9_CHILD_NATIVE_STEP_INVALID:%s" % _authorized_arm_id, captured)
		return
	if phase == Orchestrator.PHASE_INTERACTION:
		_interaction_completed = true
	var processed := _process_completed_arm_step_v1(_authorized_arm_id, active_step, false)
	if not bool(processed.get("ok", false)):
		_abort("QSDK_R10F_L9_CHILD_STEP_PROCESSING_INVALID", processed)
		return
	arm = _arms[_authorized_arm_id]
	if _after_completed_process_isolated_step_v1():
		return
	if bool(arm["terminal"]):
		_finalize_process_isolated_child_result_v1()
		return
	var planned := _plan_next_process_isolated_frame_v1(active_step)
	if not bool(planned.get("ok", false)):
		_abort("QSDK_R10F_L9_CHILD_NEXT_FRAME_PLAN_INVALID", planned)
		return


## Default production execution never shortens its schedule. The diagnostic
## subclass can stop only after a complete measured step, before the next plan.
func _after_completed_process_isolated_step_v1() -> bool:
	return false


func _advance_orchestrator_step_v1(state: Dictionary, event: Dictionary) -> Dictionary:
	return Orchestrator.advance_v1(_sdk, state, event)


func _load_runtime_extension_v1() -> bool:
	return load(EXTENSION_PATH) != null and ClassDB.class_exists(CLASS_NAME)


func _initialize_orchestrator_v1(arm_id: String, model_id: String, population: String) -> Dictionary:
	return Orchestrator.initialize_v1(_sdk, _attempt_id, arm_id, model_id, _configuration_sha256, population, 0)


func _build_orchestrator_event_v1(state: Dictionary, fields: Dictionary) -> Dictionary:
	return Orchestrator.build_event_v1(_sdk, state, fields)


func _development_step_profiler_v1() -> RefCounted:
	return null


func _development_context_cache_v1() -> RefCounted:
	return null


func _prepare_completed_process_isolated_interaction_v1(global_step: int) -> Dictionary:
	if not _interaction_scheduled or _interaction_completed or global_step <= 1:
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L9_CHILD_INTERACTION_LIFECYCLE_INVALID",
		}
	var arm: Dictionary = _arms[_authorized_arm_id]
	var model: Dictionary = arm["model"]
	var torso: RigidBody3D = (model["body_nodes"] as Dictionary)["torso"]
	var post_velocity := _vector3_array_v1(torso.linear_velocity)
	_total_native_readback_count += 1
	var prefix: Dictionary = arm["prefix_session_start_receipt"]
	var source_build := (
		ProcessIsolatedChildContract
		. build_interaction_source_v1(
			_sdk,
			_parent_attempt_id,
			_attempt_id,
			_authorized_arm_id,
			String(arm["model_instance_id"]),
			global_step,
			prefix,
			(arm["scheduled_impulse_world_n_s"] as Array).duplicate(),
			(arm["pre_interaction_velocity_world_m_s"] as Array).duplicate(),
			post_velocity,
			int(arm["external_kick_application_count"]),
		)
	)
	if not bool(source_build.get("ok", false)):
		return source_build
	_process_isolated_interaction_source = (source_build["source"] as Dictionary).duplicate(true)
	var interaction_build := (
		EnergyInitializer
		. build_interaction_receipt_v1(
			_sdk,
			_attempt_id,
			_authorized_arm_id,
			String(arm["model_instance_id"]),
			global_step,
			global_step,
			float(source_build["raw_velocity_delta_magnitude_m_s"]),
			String(source_build["source_sha256"]),
		)
	)
	if not bool(interaction_build.get("ok", false)):
		return interaction_build
	var interaction: Dictionary = interaction_build["interaction_receipt"]
	var facade: RefCounted = arm["facade"]
	var motor_readback: Dictionary = facade.motor_population_readback_v1(
		global_step, false, "l9_process_isolated_post_interaction_pre_epoch_collection"
	)
	if not bool(motor_readback.get("ok", false)):
		return motor_readback
	_total_native_readback_count += int(motor_readback.get("native_readback_count", 0))
	var no_actuation_intent := (
		LocomotionFacade
		. no_actuation_ledger_application_intent_v1(
			_sdk,
			global_step,
			Orchestrator.PHASE_INTERACTION,
			"none",
			null,
			false,
			interaction,
			motor_readback,
			interaction,
		)
	)
	if not bool(no_actuation_intent.get("ok", false)):
		return no_actuation_intent
	arm["interaction_receipt"] = interaction.duplicate(true)
	arm["pending_application"] = no_actuation_intent.duplicate(true)
	_arms[_authorized_arm_id] = arm
	return {
		"ok": true,
		"interaction_source_sha256": String(source_build["source_sha256"]),
		"interaction_receipt_sha256": String(interaction["payload_sha256"]),
	}


func _prepare_completed_interaction_v1(global_step: int) -> Dictionary:
	if not _interaction_scheduled or _interaction_completed or global_step <= 1:
		return {"ok": false, "failure_code": "QSDK_R10F_INTERACTION_LIFECYCLE_INVALID"}
	var active: Dictionary = _arms[EnergyInitializer.ACTIVE_ARM_ID]
	var baseline: Dictionary = _arms[EnergyInitializer.BASELINE_ARM_ID]
	var active_model: Dictionary = active["model"]
	var baseline_model: Dictionary = baseline["model"]
	var active_torso: RigidBody3D = (active_model["body_nodes"] as Dictionary)["torso"]
	var baseline_torso: RigidBody3D = (baseline_model["body_nodes"] as Dictionary)["torso"]
	var active_post_velocity := _vector3_array_v1(active_torso.linear_velocity)
	var baseline_post_velocity := _vector3_array_v1(baseline_torso.linear_velocity)
	_total_native_readback_count += 2
	var active_prefix: Dictionary = active["prefix_session_start_receipt"]
	var baseline_prefix: Dictionary = baseline["prefix_session_start_receipt"]
	_interaction_pair_source = {
		"attempt_id": _attempt_id,
		"completed_effect_global_step": global_step,
		"active_model_instance_id": String(active["model_instance_id"]),
		"baseline_model_instance_id": String(baseline["model_instance_id"]),
		"active_prefix_session_id": String(active_prefix["session_id"]),
		"baseline_prefix_session_id": String(baseline_prefix["session_id"]),
		"active_prefix_session_receipt_sha256": _canonical_sha256_v1(active_prefix),
		"baseline_prefix_session_receipt_sha256": _canonical_sha256_v1(baseline_prefix),
		"active_task_frame_forward_axis_world_host_real":
		(active_prefix["task_frame_forward_axis_world_host_real"] as Array).duplicate(),
		"active_task_frame_lateral_axis_world_host_real":
		(active_prefix["task_frame_lateral_axis_world_host_real"] as Array).duplicate(),
		"baseline_task_frame_forward_axis_world_host_real":
		(baseline_prefix["task_frame_forward_axis_world_host_real"] as Array).duplicate(),
		"baseline_task_frame_lateral_axis_world_host_real":
		(baseline_prefix["task_frame_lateral_axis_world_host_real"] as Array).duplicate(),
		"active_impulse_world_n_s": (active["scheduled_impulse_world_n_s"] as Array).duplicate(),
		"active_pre_application_velocity_world_m_s":
		(active["pre_interaction_velocity_world_m_s"] as Array).duplicate(),
		"active_completed_effect_velocity_world_m_s": active_post_velocity,
		"baseline_pre_event_velocity_world_m_s":
		(baseline["pre_interaction_velocity_world_m_s"] as Array).duplicate(),
		"baseline_completed_effect_velocity_world_m_s": baseline_post_velocity,
		"active_application_count": int(active["external_kick_application_count"]),
		"baseline_application_count": int(baseline["external_kick_application_count"]),
	}
	var pair_build := ImpulsePairReceipt.build_pair_receipt_v1(_sdk, _interaction_pair_source)
	if not bool(pair_build.get("ok", false)):
		return pair_build
	_interaction_pair_receipt = (pair_build["pair_receipt"] as Dictionary).duplicate(true)
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var arm: Dictionary = _arms[arm_id]
		var model_instance_id := String(arm["model_instance_id"])
		var native_delta := (
			float(pair_build["active_native_effect_velocity_delta_m_s"])
			if arm_id == EnergyInitializer.ACTIVE_ARM_ID
			else float(pair_build["baseline_natural_velocity_delta_m_s"])
		)
		var interaction_build := (
			EnergyInitializer
			. build_interaction_receipt_v1(
				_sdk,
				_attempt_id,
				arm_id,
				model_instance_id,
				global_step,
				global_step,
				native_delta,
				String(pair_build["pair_receipt_sha256"]),
			)
		)
		if not bool(interaction_build.get("ok", false)):
			return interaction_build
		var interaction: Dictionary = interaction_build["interaction_receipt"]
		var facade: RefCounted = arm["facade"]
		var motor_readback: Dictionary = facade.motor_population_readback_v1(
			global_step, false, "post_interaction_effect_pre_epoch_collection"
		)
		if not bool(motor_readback.get("ok", false)):
			return motor_readback
		_total_native_readback_count += LocomotionFacade.JOINT_IDS.size() * 3
		var no_actuation_intent := (
			LocomotionFacade
			. no_actuation_ledger_application_intent_v1(
				_sdk,
				global_step,
				Orchestrator.PHASE_INTERACTION,
				"none",
				null,
				false,
				_interaction_pair_receipt,
				motor_readback,
				interaction,
			)
		)
		if not bool(no_actuation_intent.get("ok", false)):
			return no_actuation_intent
		arm["interaction_receipt"] = interaction.duplicate(true)
		arm["pending_application"] = no_actuation_intent
		_arms[arm_id] = arm
	return {"ok": true}


func _collect_arm_completed_step_v1(arm_id: String, global_step: int) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	if bool(arm["terminal"]):
		return {"ok": false, "failure_code": "QSDK_R10F_TERMINAL_ARM_STEPPED"}
	var state: Dictionary = arm["orchestrator_state"]
	var orchestrator_phase := String(state["phase"])
	var application: Dictionary = arm["pending_application"]
	if application.is_empty() or int(application.get("semantic_step", -1)) != global_step:
		return {"ok": false, "failure_code": "QSDK_R10F_PENDING_APPLICATION_STEP_INVALID"}
	if _repair_id == "QSDK-R10F-L15":
		var ownership := NoActuationStageL15.validate_pending_v1(_sdk, arm, global_step,
			_recovery_controller_for_phase_v1(orchestrator_phase))
		if ownership.get("ok") != true:
			return ownership
	var epoch_mode := NativeEpochRoute.MODE_GLOBAL_ONLY
	var interaction: Dictionary = {}
	if orchestrator_phase == Orchestrator.PHASE_INTERACTION:
		epoch_mode = NativeEpochRoute.MODE_INITIALIZE_EPOCH
		interaction = arm["interaction_receipt"]
	elif state.get("epoch_start_global_step") != null:
		epoch_mode = NativeEpochRoute.MODE_GLOBAL_AND_EPOCH
	var collection := (
		NativeEpochRoute
		. collect_completed_step_v1(
			_sdk,
			_context,
			arm["model"],
			application,
			global_step,
			String(application["phase"]),
			epoch_mode,
			interaction,
			_development_step_profiler_v1(),
			_development_context_cache_v1(),
		)
	)
	if not bool(collection.get("ok", false)):
		return collection
	var solver_counter := _collection_solver_counter_projection_v1(collection, global_step)
	if not bool(solver_counter.get("ok", false)):
		return solver_counter
	collection["worker_solver_counter_projection_v1"] = solver_counter.duplicate(true)
	_total_solver_step_count += int(solver_counter["completed_step_delta"])
	var retained := _retain_compact_step_v1(arm_id, collection, application, orchestrator_phase)
	if not bool(retained.get("ok", false)):
		return retained
	arm = _arms[arm_id]
	arm["last_collection"] = collection
	_arms[arm_id] = arm
	return {"ok": true}


func _retain_compact_step_v1(
	arm_id: String,
	collection: Dictionary,
	application: Dictionary,
	orchestrator_phase: String,
) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var global_result: Dictionary = collection["global_result"]
	var measurement: Dictionary = global_result["measurement"]
	var bound: Dictionary = global_result["bound"]
	var observation: Dictionary = bound["observation_v3"]
	var state_frame: Dictionary = observation["state"]
	var engine_identity: Dictionary = observation["engine_step_identity"]
	var energy_source: Dictionary = measurement["energy_source_receipt"]
	var components: Dictionary = measurement["source_component_receipts"]
	var native_health: Dictionary = measurement["native_engine_health_receipt"]
	var solver_counter: Dictionary = collection["worker_solver_counter_projection_v1"]
	var global_step := int(collection["global_semantic_step"])
	var identity_facade: RefCounted = arm["facade"]
	var identity: Dictionary = identity_facade.same_body_identity_receipt_v1(
		_sdk, global_step, orchestrator_phase
	)
	if not bool(identity.get("ok", false)):
		return identity
	var geometry := _joint_geometry_summary_v2(arm["model"], observation)
	if not bool(geometry.get("ok", false)):
		return geometry
	var contacts := _contact_map_v1(observation)
	var foot_positions := _foot_position_map_v1(arm["model"])
	if contacts.is_empty() or foot_positions.is_empty():
		return {"ok": false, "failure_code": "QSDK_R10F_COMPACT_CONTACT_SOURCE_INVALID"}
	var base_pose: Dictionary = state_frame["base_pose_world"]
	var position := _vector_dictionary_array_v1(base_pose["position_m"])
	var torso: RigidBody3D = ((arm["model"] as Dictionary)["body_nodes"] as Dictionary)["torso"]
	var frame_id := _walking_frame_id_v1(String(arm["active_walking_session"].get("evaluation_segment_id", "")))
	var torso_forward := _vector3_array_v1(LocomotionFacade.DevelopmentWalkingFrame.trace_forward_v1(torso.global_basis, frame_id))
	var torso_up := torso.global_basis.y.normalized()
	var torso_tilt := acos(clampf(torso_up.dot(Vector3.UP), -1.0, 1.0))
	var torso_contact := _torso_contact_v1(observation)
	var application_sha := _canonical_sha256_v1(application)
	var observation_sha := _canonical_sha256_v1(observation)
	var native_health_sha := String(measurement.get("native_engine_health_receipt_sha256", ""))
	var external: Dictionary = observation["external_interventions"]
	var precondition_pair_action := String(arm.get("precondition_pair_action", ""))
	var precondition_pair_application_sha := ""
	var precondition_pair_application_valid := true
	if (
		orchestrator_phase == Orchestrator.PHASE_PRECONDITION_RECOVERY
		and (
			precondition_pair_action
			in [PreconditionPairBarrier.ACTION_WAIT, PreconditionPairBarrier.ACTION_RELEASE]
		)
	):
		var pair_application_value: Variant = arm.get(
			"precondition_pair_barrier_application_projection"
		)
		precondition_pair_application_valid = pair_application_value is Dictionary
		if precondition_pair_application_valid:
			if precondition_pair_action == PreconditionPairBarrier.ACTION_RELEASE:
				precondition_pair_application_valid = (
					ProcessIsolatedChildContract
					. precondition_release_receipt_valid_v1(
						_sdk, pair_application_value as Dictionary
					)
				)
			else:
				precondition_pair_application_valid = precondition_pair_barrier_application_valid_v1(
					_sdk,
					pair_application_value as Dictionary,
					_precondition_pair_state,
					arm_id,
					global_step,
					precondition_pair_action,
				)
		if pair_application_value is Dictionary:
			precondition_pair_application_sha = String(
				(pair_application_value as Dictionary).get("payload_sha256", "")
			)
	var predicates := {
		"global_step_exact": int(engine_identity.get("semantic_step", -1)) == global_step,
		"host_step_before_exact":
		int(engine_identity.get("host_step_before", -1)) == global_step - 1,
		"host_step_after_exact": int(engine_identity.get("host_step_after", -1)) == global_step,
		"model_host_step_exact":
		int((arm["model"] as Dictionary).get("host_step_count", -1)) == global_step,
		"application_step_exact": int(application.get("semantic_step", -1)) == global_step,
		"application_digest_valid": _valid_sha256(application_sha),
		"observation_digest_valid": _valid_sha256(observation_sha),
		"same_body_population_exact":
		(
			String(identity.get("body_population_instance_sha256", ""))
			== String(arm["body_population_instance_sha256"])
		),
		"missing_measurement_synthesis_zero":
		int(bound.get("missing_measurement_synthesis_count", -1)) == 0,
		"energy_semantic_step_exact": int(energy_source.get("semantic_step", -1)) == global_step,
		"component_partition_complete":
		bool(energy_source.get("component_partition_complete", false)),
		"constraint_exchange_partition_complete":
		bool(energy_source.get("constraint_exchange_partition_complete", false)),
		"passive_dissipation_partition_complete":
		bool(energy_source.get("passive_dissipation_partition_complete", false)),
		"exact_balance_safety_authority":
		bool(energy_source.get("exact_balance_safety_authority", false)),
		"residual_balancing_forbidden":
		not bool(energy_source.get("residual_balancing_permitted", true)),
		"rotation_integration_included_once":
		bool(energy_source.get("rotation_integration_exchange_included_exactly_once", false)),
		"native_engine_health_receipt_digest_exact":
		(
			_valid_sha256(native_health_sha)
			and _canonical_sha256_v1(native_health) == native_health_sha
		),
		"native_engine_health_passed": _native_engine_health_valid_v1(native_health, global_step),
		"global_boundary_transport_revision_exact":
		int(global_result.get("contiguous_boundary_transport_state_revision", -1)) == global_step,
		"collector_cumulative_solver_step_exact":
		int(solver_counter.get("cumulative_solver_step_count", -1)) == global_step,
		"collector_global_counter_binding_exact":
		int(solver_counter.get("retained_global_cumulative_solver_step_count", -1)) == global_step,
		"accepted_collection_step_delta_exact":
		int(solver_counter.get("completed_step_delta", -1)) == 1,
		"collector_counter_outcome_correction_zero":
		not bool(solver_counter.get("outcome_derived_correction", true)),
		"no_root_force_or_torque":
		(
			int(external.get("root_force_application_count", -1)) == 0
			and int(external.get("root_torque_application_count", -1)) == 0
		),
		"no_root_pose_or_velocity_write":
		(
			int(external.get("root_pose_write_count", -1)) == 0
			and int(external.get("root_velocity_write_count", -1)) == 0
			and int(external.get("pose_teleport_count", -1)) == 0
		),
		"no_hidden_or_relabelled_actuation":
		(
			int(external.get("hidden_body_actuation_count", -1)) == 0
			and int(external.get("collision_disable_count", -1)) == 0
			and int(external.get("contact_relabel_count", -1)) == 0
		),
		"joint_geometry_finite": bool(geometry["ok"]),
	}
	if (
		orchestrator_phase == Orchestrator.PHASE_PRECONDITION_RECOVERY
		and (
			precondition_pair_action
			in [PreconditionPairBarrier.ACTION_WAIT, PreconditionPairBarrier.ACTION_RELEASE]
		)
	):
		predicates["precondition_pair_application_live_valid"] = (precondition_pair_application_valid)
		predicates["precondition_pair_application_digest_valid"] = _valid_sha256(
			precondition_pair_application_sha
		)
		predicates["precondition_pair_application_matches_pending_intent"] = (
			String(
				(arm["precondition_pair_barrier_application_projection"] as Dictionary).get(
					"ledger_application_intent_sha256", ""
				)
			)
			== application_sha
		)
	if collection["epoch_mode"] == NativeEpochRoute.MODE_INITIALIZE_EPOCH:
		predicates["epoch_initializer_local_step_zero"] = int(collection["epoch_local_step"]) == 0
	elif collection["epoch_mode"] == NativeEpochRoute.MODE_GLOBAL_AND_EPOCH:
		predicates["epoch_local_step_exact"] = (
			int(collection["epoch_local_step"])
			== (
				global_step
				- int((arm["orchestrator_state"] as Dictionary)["epoch_start_global_step"])
			)
		)
	var failed: Array = []
	for predicate_value in predicates.keys():
		var predicate := String(predicate_value)
		if not bool(predicates[predicate]):
			failed.append(predicate)
	if not failed.is_empty():
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_IN_RUN_INVARIANT_FAILED",
			"failed_predicates": failed,
			"predicates": predicates,
		}
	var walking_session: Dictionary = arm["active_walking_session"]
	var row := {
		"schema_version": WalkingEvaluator.TRACE_ROW_SCHEMA,
		"arm_id": arm_id,
		"global_semantic_step": global_step,
		"recovery_epoch_local_step": collection.get("epoch_local_step"),
		"orchestrator_phase": orchestrator_phase,
		"application_phase": String(application["phase"]),
		"control_owner": String(application.get("controller_owner", "none")),
		"no_actuation_requested": bool(application.get("no_actuation_requested", false)),
		"walking_segment_id": String(walking_session.get("evaluation_segment_id", "")),
		"walking_session_id": String(application.get("walking_session_id", "")),
		"walking_session_local_step": int(application.get("walking_session_local_step", 0)),
		"torso_position_world_m": position,
		"torso_forward_axis_world_unit": torso_forward,
		"torso_tilt_rad": torso_tilt,
		"torso_contact": torso_contact,
		"contact_by_limb": contacts,
		"foot_position_world_m_by_limb": foot_positions,
		"maximum_anchor_error_m": float(geometry["maximum_anchor_error_m"]),
		"maximum_hinge_axis_error_rad": float(geometry["maximum_hinge_axis_error_rad"]),
		"application_intent_sha256": application_sha,
		"observation_sha256": observation_sha,
		"body_population_instance_sha256": String(arm["body_population_instance_sha256"]),
		"native_engine_health_receipt_sha256": native_health_sha,
		"precondition_pair_action": precondition_pair_action,
		"precondition_pair_barrier_application_sha256": precondition_pair_application_sha,
		"recovery_classification": null,
		"source_measurement": true,
	}
	if not frame_id.is_empty():
		row["development_walking_frame_id"] = frame_id
	var invariant := {
		"schema_version": INVARIANT_SCHEMA,
		"arm_id": arm_id,
		"global_semantic_step": global_step,
		"orchestrator_phase": orchestrator_phase,
		"application_intent_sha256": application_sha,
		"observation_sha256": observation_sha,
		"body_population_instance_sha256": String(arm["body_population_instance_sha256"]),
		"native_engine_health_receipt_sha256": native_health_sha,
		"precondition_pair_action": precondition_pair_action,
		"precondition_pair_barrier_application_sha256": precondition_pair_application_sha,
		"solver_counter_projection": solver_counter.duplicate(true),
		"predicates": predicates,
		"all_in_run_physical_invariants_passed": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	(arm["trace_rows"] as Array).append(row)
	(arm["invariant_receipts"] as Array).append(invariant)
	_arms[arm_id] = arm
	return {"ok": true}


static func _collection_solver_counter_failure_v1(
	failure_code: String,
	expected_global_step: int,
	collection_counter_value: Variant,
	retained_global_counter_value: Variant,
	failed_fields: Array,
) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10f_collection_solver_counter_failure_v1",
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": failure_code,
		"expected_global_semantic_step": expected_global_step,
		"collection_counter_variant_type": type_string(typeof(collection_counter_value)),
		"retained_global_counter_variant_type": type_string(typeof(retained_global_counter_value)),
		"failed_fields": failed_fields.duplicate(),
		"source_counter_semantics": "cumulative_completed_global_solver_step_sequence",
		"aggregate_counter_semantics": "one_delta_per_accepted_arm_collection",
		"outcome_derived_correction": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


## The retained native route reports a cumulative completed-step sequence, not
## a per-call delta. Authenticate that source value against G, then expose a
## separate literal one-step delta for the worker's cross-arm aggregate.
static func _collection_solver_counter_projection_v1(
	collection: Dictionary,
	expected_global_step: int,
) -> Dictionary:
	var collection_counter_value: Variant = collection.get("solver_step_count")
	var retained_global_value: Variant = collection.get("global_result")
	var retained_global_counter_value: Variant = (
		(retained_global_value as Dictionary).get("solver_step_count")
		if retained_global_value is Dictionary
		else null
	)
	if (
		typeof(collection.get("schema_version")) != TYPE_STRING
		or String(collection.get("schema_version")) != NativeEpochRoute.COLLECTION_SCHEMA
		or typeof(collection.get("gate_id")) != TYPE_STRING
		or String(collection.get("gate_id")) != GATE_ID
		or typeof(collection.get("ok")) != TYPE_BOOL
		or not bool(collection.get("ok"))
		or typeof(collection.get("retained_global_collector_unchanged")) != TYPE_BOOL
		or not bool(collection.get("retained_global_collector_unchanged"))
		or not (retained_global_value is Dictionary)
	):
		return _collection_solver_counter_failure_v1(
			"QSDK_R10F_COLLECTION_SOLVER_COUNTER_SHAPE_INVALID",
			expected_global_step,
			collection_counter_value,
			retained_global_counter_value,
			[
				"schema_version",
				"gate_id",
				"ok",
				"retained_global_collector_unchanged",
				"global_result",
			],
		)
	if expected_global_step <= 0:
		return _collection_solver_counter_failure_v1(
			"QSDK_R10F_COLLECTION_SOLVER_COUNTER_EXPECTED_STEP_INVALID",
			expected_global_step,
			collection_counter_value,
			retained_global_counter_value,
			["expected_global_semantic_step"],
		)
	var collection_global_step_value: Variant = collection.get("global_semantic_step")
	if (
		typeof(collection_global_step_value) != TYPE_INT
		or typeof(collection_counter_value) != TYPE_INT
	):
		return _collection_solver_counter_failure_v1(
			"QSDK_R10F_COLLECTION_SOLVER_COUNTER_TYPE_INVALID",
			expected_global_step,
			collection_counter_value,
			retained_global_counter_value,
			["global_semantic_step", "solver_step_count"],
		)
	if (
		int(collection_global_step_value) != expected_global_step
		or int(collection_counter_value) != expected_global_step
	):
		return _collection_solver_counter_failure_v1(
			"QSDK_R10F_COLLECTION_SOLVER_COUNTER_SEQUENCE_INVALID",
			expected_global_step,
			collection_counter_value,
			retained_global_counter_value,
			["global_semantic_step", "solver_step_count", "expected_global_semantic_step"],
		)
	if (
		typeof(retained_global_counter_value) != TYPE_INT
		or int(retained_global_counter_value) != int(collection_counter_value)
	):
		return _collection_solver_counter_failure_v1(
			"QSDK_R10F_COLLECTION_SOLVER_COUNTER_GLOBAL_BINDING_INVALID",
			expected_global_step,
			collection_counter_value,
			retained_global_counter_value,
			["global_result.solver_step_count", "solver_step_count"],
		)
	return {
		"schema_version": "sporespore_qsdk_r10f_collection_solver_counter_projection_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"global_semantic_step": expected_global_step,
		"cumulative_solver_step_count": int(collection_counter_value),
		"retained_global_cumulative_solver_step_count": int(retained_global_counter_value),
		"completed_step_delta": 1,
		"source_counter_semantics": "cumulative_completed_global_solver_step_sequence",
		"aggregate_counter_semantics": "one_delta_per_accepted_arm_collection",
		"retained_global_collector_unchanged": true,
		"source_measurement": true,
		"outcome_derived_correction": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


func _process_completed_arm_step_v1(
	arm_id: String,
	global_step: int,
	active_terminal_after_step: bool,
) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var state_before: Dictionary = arm["orchestrator_state"]
	var phase := String(state_before["phase"])
	var selected_recovery_controller := _recovery_controller_for_phase_v1(phase)
	var selected_recovery_owner: String = NoActuationStageL15.Owner.profile_v1(selected_recovery_controller).get("owner", "")
	var application: Dictionary = arm["pending_application"]
	var collection: Dictionary = arm["last_collection"]
	var precondition_action := String(arm.get("precondition_pair_action", ""))
	if (
		phase == Orchestrator.PHASE_PRECONDITION_RECOVERY
		and (
			precondition_action
			not in [PreconditionPairBarrier.ACTION_RECOVERY, PreconditionPairBarrier.ACTION_RELEASE]
		)
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L9_CHILD_PRECONDITION_ACTION_INVALID",
		}
	if (
		phase == Orchestrator.PHASE_PRECONDITION_RECOVERY
		and precondition_action == PreconditionPairBarrier.ACTION_RELEASE
		and not (ProcessIsolatedChildContract.precondition_release_receipt_valid_v1(
			_sdk, arm.get("precondition_pair_barrier_application_projection", {})
		))
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L9_CHILD_PRECONDITION_RELEASE_INVALID",
		}
	var recovery_advance: Dictionary = {}
	var classification: Dictionary = {}
	var terminal_phase := ""
	var terminal_reason := ""
	var recovery_bound_value: Variant = null
	if (
		phase in [Orchestrator.PHASE_CONFIRM_PRONE, Orchestrator.PHASE_POST_KICK_RECOVERY]
		or (
			phase == Orchestrator.PHASE_PRECONDITION_RECOVERY
			and precondition_action == PreconditionPairBarrier.ACTION_RECOVERY
		)
	):
		if phase == Orchestrator.PHASE_PRECONDITION_RECOVERY:
			recovery_bound_value = (collection["global_result"] as Dictionary).get("bound")
		else:
			var epoch_result_value: Variant = collection.get("epoch_result")
			if epoch_result_value is Dictionary:
				recovery_bound_value = (epoch_result_value as Dictionary).get(
					"bound_epoch_observations"
				)
		if not (recovery_bound_value is Dictionary):
			return {
				"ok": false,
				"failure_code": "QSDK_R10F_RECOVERY_BOUND_OBSERVATION_MISSING",
			}
		var memory: Dictionary = arm["recovery_memory"]
		var portable_phase := String(memory.get("phase", ""))
		if _repair_id == "QSDK-R10F-L15":
			var retained_stage := _advance_recovery_stage_v1(arm, recovery_bound_value, global_step)
			# Install retained bytes before either this stage or the unchanged
			# advance-receipt validator can return failure to the abort path.
			arm = retained_stage["arm"]
			_arms[arm_id] = arm
			recovery_advance = retained_stage["advance"]
		else:
			recovery_advance = (
				BehaviorWorker
				. production_advance_dispatch_v1(
					_sdk,
					_context,
					recovery_bound_value,
					memory,
					INTERNAL_RECOVERY_ARM_KIND,
					portable_phase,
					RECOVERY_CONTROLLER_ID,
					ENERGY_ROUTE_ID,
				)
			)
		if (
			not bool(recovery_advance.get("ok", false))
			or not (
				BehaviorWorker
				. production_advance_receipt_valid_v1(
					recovery_advance,
					selected_recovery_controller,
					_sdk,
					ENERGY_ROUTE_ID,
				)
			)
		):
			return {
				"ok": false,
				"failure_code": "QSDK_R10F_RECOVERY_PRODUCTION_ADVANCE_INVALID",
				"advance": recovery_advance,
			}
		var step_receipt: Dictionary = recovery_advance["step_receipt"]
		var classification_value: Variant = step_receipt.get("classification")
		if not (classification_value is Dictionary):
			return {
				"ok": false,
				"failure_code": "QSDK_R10F_RECOVERY_CLASSIFICATION_MISSING",
			}
		classification = (classification_value as Dictionary).duplicate(true)
		(arm["recovery_step_receipts"] as Array).append(step_receipt.duplicate(true))
		var progression_value: Variant = recovery_advance.get("development_progression_receipt")
		if progression_value is Dictionary:
			(arm["recovery_development_progression_receipts"] as Array).append(
				(progression_value as Dictionary).duplicate(true)
			)
		arm["recovery_memory"] = ((recovery_advance["next_memory"] as Dictionary).duplicate(true))
		var next_control_value: Variant = recovery_advance.get("control_receipt")
		arm["next_recovery_control"] = (
			(next_control_value as Dictionary).duplicate(true)
			if next_control_value is Dictionary
			else {}
		)
		if bool(recovery_advance.get("terminal", false)):
			terminal_phase = String((arm["recovery_memory"] as Dictionary).get("phase", ""))
			terminal_reason = _terminal_failure_reason_v1(arm["recovery_memory"])
			if phase == Orchestrator.PHASE_PRECONDITION_RECOVERY:
				var terminal_build := (
					ProcessIsolatedChildContract
					. build_precondition_terminal_receipt_v1(
						_sdk,
						_parent_attempt_id,
						_attempt_id,
						arm_id,
						String(arm["model_instance_id"]),
						global_step,
						RECOVERY_CONTROLLER_ID,
						arm["recovery_memory"],
						step_receipt,
						classification,
						int(arm["body_transform_write_count"]),
						int(arm["body_velocity_write_count"]),
						int(arm["solver_reset_count"]),
					)
				)
				if not bool(terminal_build.get("ok", false)):
					return terminal_build
				_process_isolated_precondition_terminal_receipt = (
					(terminal_build["receipt"] as Dictionary).duplicate(true)
				)
				arm["precondition_terminal_source"] = (
					_process_isolated_precondition_terminal_receipt.duplicate(true)
				)
		arm["last_recovery_global_semantic_step"] = global_step
		arm["last_recovery_terminal"] = bool(recovery_advance.get("terminal", false))
		arm["last_recovery_terminal_phase"] = terminal_phase
		arm["last_recovery_terminal_failure_code"] = terminal_reason
		arm["last_recovery_step_receipt"] = step_receipt.duplicate(true)
		arm["last_recovery_classification"] = classification.duplicate(true)
		var rows: Array = arm["trace_rows"]
		var latest_row: Dictionary = rows[rows.size() - 1]
		latest_row["recovery_classification"] = classification.duplicate(true)
		rows[rows.size() - 1] = latest_row
		arm["trace_rows"] = rows
		_arms[arm_id] = arm

	var recovery_epoch_local_step := 0
	if collection.get("epoch_local_step") != null:
		recovery_epoch_local_step = int(collection["epoch_local_step"])
	var no_actuation := bool(application.get("no_actuation_requested", false))
	var event_kind := ""
	var control_owner := "none"
	var actuation_owner := "none"
	var walking_session_id := ""
	var walking_session_local_step := 0
	var interaction_sha := ""
	var initializer_sha := ""
	var kick_application_count := 0
	var motors_disabled_for_interaction := false
	if phase == Orchestrator.PHASE_PRECONDITION_RECOVERY:
		if precondition_action == PreconditionPairBarrier.ACTION_RECOVERY:
			event_kind = (
				"precondition_pair_ready"
				if terminal_phase == "complete"
				else "recovery_controller_step"
			)
			control_owner = "recovery_v6"
			actuation_owner = "none" if no_actuation else "recovery_v6"
		elif precondition_action == PreconditionPairBarrier.ACTION_WAIT:
			event_kind = "precondition_pair_wait_step"
		elif precondition_action == PreconditionPairBarrier.ACTION_RELEASE:
			event_kind = "precondition_pair_release_step"
	elif phase == Orchestrator.PHASE_WALKING_PREFIX:
		event_kind = "walking_policy_step"
		control_owner = "walking_bw5r_b"
		actuation_owner = "walking_bw5r_b"
		walking_session_id = String(application.get("walking_session_id", ""))
		walking_session_local_step = int(application.get("walking_session_local_step", 0))
	elif phase == Orchestrator.PHASE_INTERACTION:
		event_kind = (
			"kick_effect_step"
			if arm_id == EnergyInitializer.ACTIVE_ARM_ID
			else "matched_no_kick_effect_step"
		)
		interaction_sha = String((arm["interaction_receipt"] as Dictionary)["payload_sha256"])
		var epoch_initialization: Dictionary = collection["epoch_result"]
		initializer_sha = String(
			(epoch_initialization["energy_initializer"] as Dictionary)["payload_sha256"]
		)
		kick_application_count = int(arm["external_kick_application_count"])
		motors_disabled_for_interaction = true
	elif phase == Orchestrator.PHASE_CONFIRM_PRONE:
		event_kind = "passive_prone_observation"
		control_owner = selected_recovery_owner
		initializer_sha = _arm_epoch_initializer_sha256_v1(arm)
	elif phase == Orchestrator.PHASE_POST_KICK_RECOVERY:
		event_kind = "recovery_controller_step"
		control_owner = selected_recovery_owner
		actuation_owner = "none" if no_actuation else selected_recovery_owner
		initializer_sha = _arm_epoch_initializer_sha256_v1(arm)
	elif phase == Orchestrator.PHASE_WALKING_RESUME:
		event_kind = "walking_policy_step"
		control_owner = _walking_owner_for_phase_v1(phase)
		actuation_owner = _walking_owner_for_phase_v1(phase)
		walking_session_id = String(application.get("walking_session_id", ""))
		walking_session_local_step = int(application.get("walking_session_local_step", 0))
	elif phase == Orchestrator.PHASE_MATCHED_CONTINUATION:
		event_kind = "matched_continuation_step"
		control_owner = _walking_owner_for_phase_v1(phase)
		actuation_owner = _walking_owner_for_phase_v1(phase)
		walking_session_id = String(application.get("walking_session_id", ""))
		walking_session_local_step = int(application.get("walking_session_local_step", 0))
		if (
			active_terminal_after_step
			or walking_session_local_step == PROCESS_ISOLATED_MATCHED_CONTINUATION_STEPS
		):
			terminal_phase = "complete"
	else:
		return {"ok": false, "failure_code": "QSDK_R10F_PROCESS_PHASE_INVALID"}

	var event_build := (
		_build_orchestrator_event_v1(
			state_before,
			{
				"event_kind": event_kind,
				"global_semantic_step": global_step,
				"recovery_epoch_local_step": recovery_epoch_local_step,
				"control_owner": control_owner,
				"actuation_owner": actuation_owner,
				"no_actuation_requested": no_actuation,
				"application_intent_sha256": _canonical_sha256_v1(application),
				"walking_session_id": walking_session_id,
				"walking_session_local_step": walking_session_local_step,
				"walking_actuation_applied": actuation_owner == _walking_owner_for_phase_v1(phase),
				"recovery_actuation_applied": actuation_owner == selected_recovery_owner,
				"stable_four_foot_stance": bool(classification.get("stable_stance_gate", false)),
				"prone_sample": bool(classification.get("entry_prone_gate", false)),
				"recovery_controller_terminal_phase": terminal_phase,
				"recovery_controller_terminal_reason": terminal_reason,
				"interaction_receipt_sha256": interaction_sha,
				"energy_initializer_sha256": initializer_sha,
				"kick_application_count": kick_application_count,
				"walking_motors_disabled_in_same_pre_solver_event": motors_disabled_for_interaction,
				"walking_motors_enabled_during_interaction_solve": false,
				"body_population_rebuild_count": int(arm["body_population_rebuild_count"]),
				"body_transform_write_count": int(arm["body_transform_write_count"]),
				"body_velocity_write_count": int(arm["body_velocity_write_count"]),
				"solver_reset_count": int(arm["solver_reset_count"]),
			},
		)
	)
	return _install_orchestrator_event_v1(arm_id, state_before, application, collection,
		recovery_bound_value, event_build)


func _install_orchestrator_event_v1(
	arm_id: String, state_before: Dictionary, application: Dictionary,
	collection: Dictionary, recovery_bound_value: Variant, event_build: Dictionary,
) -> Dictionary:
	if not bool(event_build.get("ok", false)):
		return event_build
	var orchestrator_advance := _advance_orchestrator_step_v1(state_before, event_build["event"])
	if not bool(orchestrator_advance.get("ok", false)):
		return orchestrator_advance
	var arm: Dictionary = _arms[arm_id]
	arm["orchestrator_state"] = ((orchestrator_advance["state_after"] as Dictionary).duplicate(
		true
	))
	var next_phase := String((arm["orchestrator_state"] as Dictionary)["phase"])
	arm["terminal"] = next_phase in [Orchestrator.PHASE_COMPLETE, Orchestrator.PHASE_FAILED]
	if bool(arm["terminal"]):
		# Keep the actual submitted/returned objects, before cleanup. The
		# independent consumer must prove a failed pre-resume branch from these
		# sources; it may not infer that branch from a missing walking session.
		arm["terminal_orchestrator_transition"] = terminal_orchestrator_transition_projection_v1(
			state_before, event_build["event"], orchestrator_advance
		)
		arm["terminal_recovery_observation_sources"] = terminal_recovery_observation_sources_projection_v1(
			application,
			(collection["global_result"] as Dictionary)["bound"]["observation_v3"],
			recovery_bound_value if recovery_bound_value is Dictionary else {},
		)
		arm["behavior_terminal_reason"] = String(
			(arm["orchestrator_state"] as Dictionary)["terminal_reason"]
		)
	_arms[arm_id] = arm
	return {
		"ok": true,
		"phase_before": String(state_before["phase"]),
		"phase_after": next_phase,
		"event_sha256": String(event_build["event_sha256"]),
		"process_isolated_precondition_terminal_sha256":
		String(_process_isolated_precondition_terminal_receipt.get("payload_sha256", "")),
	}


static func terminal_orchestrator_transition_projection_v1(
	state_before: Dictionary, event: Dictionary, advance_receipt: Dictionary
) -> Dictionary:
	return {
		"state_before": state_before.duplicate(true),
		"event": event.duplicate(true),
		"advance_receipt": advance_receipt.duplicate(true),
	}


static func terminal_recovery_observation_sources_projection_v1(
	application: Dictionary, global_observation: Dictionary, recovery_bound: Dictionary
) -> Dictionary:
	# Recovery rebases energy, not the retained global observation sequence.
	# Retain both existing observations and their existing epoch binding so the
	# checker can prove their relationship without equating different hashes.
	# This copies sources only: no new collection, controller call or solver step.
	return {
		"application_intent": application.duplicate(true),
		"global_observation": global_observation.duplicate(true),
		"bound_recovery_observations": recovery_bound.duplicate(true),
	}


func _refresh_precondition_terminal_dispositions_v1(global_step: int) -> Dictionary:
	if (
		_sdk == null
		or not PreconditionPairBarrier.state_valid_v1(_sdk, _precondition_pair_state)
		or bool(_precondition_pair_state.get("released", false))
		or (
			global_step
			!= int(_precondition_pair_state.get("last_completed_global_semantic_step", -1))
		)
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L7_PRECONDITION_DISPOSITION_STATE_INVALID",
		}
	var disposition_by_arm := {}
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var arm: Dictionary = _arms[arm_id]
		var state_value: Variant = arm.get("orchestrator_state")
		var memory_value: Variant = arm.get("recovery_memory")
		var step_value: Variant = arm.get("last_recovery_step_receipt")
		var classification_value: Variant = arm.get("last_recovery_classification")
		if (
			not (state_value is Dictionary)
			or not (memory_value is Dictionary)
			or not (step_value is Dictionary)
			or (step_value as Dictionary).is_empty()
			or not (classification_value is Dictionary)
			or (classification_value as Dictionary).is_empty()
		):
			return {
				"ok": false,
				"failure_code": "QSDK_R10F_L7_PRECONDITION_ARM_SOURCE_MISSING",
				"arm_id": arm_id,
			}
		var state: Dictionary = state_value
		var route_terminal := bool(arm.get("terminal", false))
		var route_terminal_reason := String(arm.get("behavior_terminal_reason", ""))
		var built := (
			PreconditionTerminalDisposition
			. build_disposition_v1(
				_sdk,
				_precondition_pair_state,
				{
					"arm_id": arm_id,
					"global_semantic_step": global_step,
					"orchestrator_phase": String(state.get("phase", "")),
					"route_terminal": route_terminal,
					"route_terminal_reason": route_terminal_reason,
					"recovery_controller_id": RECOVERY_CONTROLLER_ID,
					"recovery_terminal": bool(arm.get("last_recovery_terminal", false)),
					"recovery_terminal_phase": String(arm.get("last_recovery_terminal_phase", "")),
					"recovery_terminal_failure_code":
					String(arm.get("last_recovery_terminal_failure_code", "")),
					"recovery_step_global_semantic_step":
					int(arm.get("last_recovery_global_semantic_step", -1)),
					"recovery_memory": (memory_value as Dictionary).duplicate(true),
					"recovery_step_receipt": (step_value as Dictionary).duplicate(true),
					"recovery_classification": (classification_value as Dictionary).duplicate(true),
					"body_transform_write_count": int(arm.get("body_transform_write_count", -1)),
					"body_velocity_write_count": int(arm.get("body_velocity_write_count", -1)),
					"solver_reset_count": int(arm.get("solver_reset_count", -1)),
				},
			)
		)
		if not bool(built.get("ok", false)):
			return {
				"ok": false,
				"failure_code": "QSDK_R10F_L7_PRECONDITION_DISPOSITION_BUILD_INVALID",
				"arm_id": arm_id,
				"build": built,
			}
		var disposition: Dictionary = built["disposition"]
		arm["precondition_terminal_disposition"] = disposition.duplicate(true)
		_arms[arm_id] = arm
		disposition_by_arm[arm_id] = disposition
	_precondition_terminal_disposition_by_arm = disposition_by_arm.duplicate(true)
	_precondition_terminal_disposition_pair_state = _precondition_pair_state.duplicate(true)
	var failing_arm_ids := (
		PreconditionTerminalDisposition
		. failing_arm_ids_v1(
			_sdk,
			_precondition_terminal_disposition_by_arm,
			_precondition_pair_state,
			global_step,
		)
	)
	return {
		"ok": true,
		"disposition_by_arm": disposition_by_arm,
		"failing_arm_ids": failing_arm_ids,
	}


func _plan_next_process_isolated_frame_v1(global_step: int) -> Dictionary:
	if _arms.size() != 1 or not _arms.has(_authorized_arm_id):
		return {"ok": false, "failure_code": "QSDK_R10F_L9_CHILD_POPULATION_INVALID"}
	var arm: Dictionary = _arms[_authorized_arm_id]
	var phase := String((arm["orchestrator_state"] as Dictionary)["phase"])
	if phase == Orchestrator.PHASE_PRECONDITION_RECOVERY:
		if bool(arm.get("last_recovery_terminal", false)):
			if not (ProcessIsolatedChildContract.precondition_terminal_receipt_valid_v1(
				_sdk, _process_isolated_precondition_terminal_receipt
			)):
				return {
					"ok": false,
					"failure_code": "QSDK_R10F_L9_CHILD_PRECONDITION_SOURCE_INVALID",
				}
			if (
				String(_process_isolated_precondition_terminal_receipt.get("disposition", ""))
				!= ProcessIsolatedChildContract.DISPOSITION_COMPLETE
			):
				return {
					"ok": false,
					"failure_code": "QSDK_R10F_L9_CHILD_PRECONDITION_NEGATIVE_NOT_TERMINAL",
				}
			arm["precondition_pair_action"] = PreconditionPairBarrier.ACTION_RELEASE
			_arms[_authorized_arm_id] = arm
			return _apply_process_isolated_precondition_release_v1(global_step)
		arm["precondition_pair_action"] = PreconditionPairBarrier.ACTION_RECOVERY
		_arms[_authorized_arm_id] = arm
		return _apply_recovery_control_v1(_authorized_arm_id, global_step)

	if phase == Orchestrator.PHASE_WALKING_PREFIX:
		return (
			_start_walking_session_v1(_authorized_arm_id, "walking_prefix", global_step)
			if (arm["active_walking_session"] as Dictionary).is_empty()
			else _apply_next_walking_step_v1(_authorized_arm_id, global_step)
		)

	if phase == Orchestrator.PHASE_INTERACTION:
		return _schedule_process_isolated_interaction_v1(global_step)

	if phase in [Orchestrator.PHASE_CONFIRM_PRONE, Orchestrator.PHASE_POST_KICK_RECOVERY]:
		if _authorized_arm_id != EnergyInitializer.ACTIVE_ARM_ID:
			return {
				"ok": false,
				"failure_code": "QSDK_R10F_L9_BASELINE_ENTERED_ACTIVE_RECOVERY_PHASE",
			}
		if (arm["postkick_recovery_initialization_receipt"] as Dictionary).is_empty():
			return _initialize_postkick_recovery_v1(global_step)
		return (
			_create_passive_recovery_observation_application_v1(global_step)
			if phase == Orchestrator.PHASE_CONFIRM_PRONE
			else _apply_recovery_control_v1(_authorized_arm_id, global_step)
		)

	if phase == Orchestrator.PHASE_WALKING_RESUME:
		if _authorized_arm_id != EnergyInitializer.ACTIVE_ARM_ID:
			return {
				"ok": false,
				"failure_code": "QSDK_R10F_L9_BASELINE_ENTERED_WALKING_RESUME",
			}
		return (
			_start_walking_session_v1(_authorized_arm_id, "walking_resume", global_step)
			if (arm["active_walking_session"] as Dictionary).is_empty()
			else _apply_next_walking_step_v1(_authorized_arm_id, global_step)
		)

	if phase == Orchestrator.PHASE_MATCHED_CONTINUATION:
		if _authorized_arm_id != EnergyInitializer.BASELINE_ARM_ID:
			return {
				"ok": false,
				"failure_code": "QSDK_R10F_L9_ACTIVE_ENTERED_MATCHED_CONTINUATION",
			}
		return (
			_start_walking_session_v1(_authorized_arm_id, "matched_continuation", global_step)
			if (arm["active_walking_session"] as Dictionary).is_empty()
			else _apply_next_walking_step_v1(_authorized_arm_id, global_step)
		)

	return {
		"ok": false,
		"failure_code": "QSDK_R10F_L9_CHILD_UNPLANNED_PHASE",
		"arm_id": _authorized_arm_id,
		"phase": phase,
	}


func _apply_process_isolated_precondition_release_v1(
	completed_global_step: int,
) -> Dictionary:
	if not (ProcessIsolatedChildContract.precondition_terminal_receipt_valid_v1(
		_sdk, _process_isolated_precondition_terminal_receipt
	)):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L9_CHILD_RELEASE_SOURCE_INVALID",
		}
	var next_step := completed_global_step + 1
	if (
		next_step
		!= (
			int(
				_process_isolated_precondition_terminal_receipt.get(
					"completed_global_semantic_step", -2
				)
			)
			+ 1
		)
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L9_CHILD_RELEASE_STEP_INVALID",
		}
	var arm: Dictionary = _arms[_authorized_arm_id]
	var facade: RefCounted = arm["facade"]
	var configuration: Dictionary = facade.configure_all_motors_v1(
		false, next_step, "l9_process_isolated_precondition_release_motors_disabled"
	)
	if not bool(configuration.get("ok", false)):
		return configuration
	(arm["motor_configuration_receipts"] as Array).append(configuration.duplicate(true))
	var motor_readback: Dictionary = facade.motor_population_readback_v1(
		next_step, false, "l9_process_isolated_precondition_release_pre_solver_readback"
	)
	if not bool(motor_readback.get("ok", false)):
		return motor_readback
	_total_native_readback_count += int(motor_readback.get("native_readback_count", 0))
	var owner_source_build := (
		ProcessIsolatedChildContract
		. precondition_release_owner_source_projection_v1(
			_sdk, _process_isolated_precondition_terminal_receipt
		)
	)
	if not bool(owner_source_build.get("ok", false)):
		return owner_source_build
	var no_actuation := (
		LocomotionFacade
		. no_actuation_ledger_application_intent_v1(
			_sdk,
			next_step,
			Orchestrator.PHASE_PRECONDITION_RECOVERY,
			"none",
			null,
			true,
			owner_source_build.get("source", {}),
			motor_readback,
		)
	)
	if not bool(no_actuation.get("ok", false)):
		return no_actuation
	var release_build := (
		ProcessIsolatedChildContract
		. build_precondition_release_receipt_v1(
			_sdk,
			_process_isolated_precondition_terminal_receipt,
			next_step,
			configuration,
			motor_readback,
			no_actuation,
		)
	)
	if not bool(release_build.get("ok", false)):
		return release_build
	_process_isolated_precondition_release_receipt = (
		(release_build["receipt"] as Dictionary).duplicate(true)
	)
	arm["pending_application"] = no_actuation.duplicate(true)
	arm["next_recovery_control"] = {}
	arm["precondition_pair_barrier_application_projection"] = (
		_process_isolated_precondition_release_receipt.duplicate(true)
	)
	(arm["precondition_pair_barrier_application_projections"] as Array).append(
		_process_isolated_precondition_release_receipt.duplicate(true)
	)
	_arms[_authorized_arm_id] = arm
	return {
		"ok": true,
		"release_receipt_sha256":
		String(_process_isolated_precondition_release_receipt["payload_sha256"]),
	}


func _plan_next_lockstep_frame_v1(global_step: int) -> Dictionary:
	var active: Dictionary = _arms[EnergyInitializer.ACTIVE_ARM_ID]
	var baseline: Dictionary = _arms[EnergyInitializer.BASELINE_ARM_ID]
	var active_terminal := bool(active["terminal"])
	var baseline_terminal := bool(baseline["terminal"])
	if not bool(_precondition_pair_state.get("released", false)):
		var refreshed := _refresh_precondition_terminal_dispositions_v1(global_step)
		if not bool(refreshed.get("ok", false)):
			return refreshed
		var failing_arm_ids: Array = refreshed["failing_arm_ids"]
		if not failing_arm_ids.is_empty():
			var abort_build := (
				PreconditionTerminalDisposition
				. build_abort_population_v1(
					_sdk,
					_precondition_pair_state,
					_precondition_terminal_disposition_by_arm,
					global_step,
					_observed_global_solver_frames,
					_total_solver_step_count,
				)
			)
			if not bool(abort_build.get("ok", false)):
				return {
					"ok": false,
					"failure_code": "QSDK_R10F_L7_PRECONDITION_ABORT_BUILD_INVALID",
					"abort_build": abort_build,
				}
			_precondition_terminal_abort_population = (
				(abort_build["abort_population"] as Dictionary).duplicate(true)
			)
			return {
				"ok": false,
				"failure_code": PreconditionTerminalDisposition.FAILURE_CODE,
				"failing_arm_ids": failing_arm_ids.duplicate(),
				"precondition_terminal_abort_population":
				_precondition_terminal_abort_population.duplicate(true),
				"precondition_terminal_abort_population_sha256":
				String(_precondition_terminal_abort_population.get("payload_sha256", "")),
			}
	if active_terminal or baseline_terminal:
		if not active_terminal or not baseline_terminal:
			return {"ok": false, "failure_code": "QSDK_R10F_TERMINAL_FRAME_NOT_LOCKSTEP"}
		return _finish_all_open_walking_sessions_v1()

	var active_phase := String((active["orchestrator_state"] as Dictionary)["phase"])
	var baseline_phase := String((baseline["orchestrator_state"] as Dictionary)["phase"])
	if active_phase == Orchestrator.PHASE_PRECONDITION_RECOVERY:
		if baseline_phase != active_phase:
			return {"ok": false, "failure_code": "QSDK_R10F_PRECONDITION_NOT_LOCKSTEP"}
		var barrier_plan_build := (
			PreconditionPairBarrier
			. plan_next_frame_v1(
				_sdk,
				_precondition_pair_state,
				global_step,
			)
		)
		if not bool(barrier_plan_build.get("ok", false)):
			return barrier_plan_build
		_precondition_pair_state = (barrier_plan_build["state_after"] as Dictionary).duplicate(true)
		for arm_id_value in ARM_ORDER:
			var arm_id := String(arm_id_value)
			var arm: Dictionary = _arms[arm_id]
			var next_action := String(
				(_precondition_pair_state["planned_action_by_arm"] as Dictionary)[arm_id]
			)
			arm["precondition_pair_action"] = next_action
			_arms[arm_id] = arm
			var applied := (
				_apply_recovery_control_v1(arm_id, global_step)
				if next_action == PreconditionPairBarrier.ACTION_RECOVERY
				else _apply_precondition_pair_barrier_application_v1(arm_id, global_step)
			)
			if not bool(applied.get("ok", false)):
				return applied
		return {
			"ok": true,
			"precondition_pair_plan_sha256": String(barrier_plan_build["plan_sha256"]),
		}

	if active_phase == Orchestrator.PHASE_WALKING_PREFIX:
		if baseline_phase != active_phase:
			return {"ok": false, "failure_code": "QSDK_R10F_PREFIX_NOT_LOCKSTEP"}
		for arm_id_value in ARM_ORDER:
			var arm_id := String(arm_id_value)
			var arm: Dictionary = _arms[arm_id]
			var planned := (
				_start_walking_session_v1(arm_id, "walking_prefix", global_step)
				if (arm["active_walking_session"] as Dictionary).is_empty()
				else _apply_next_walking_step_v1(arm_id, global_step)
			)
			if not bool(planned.get("ok", false)):
				return planned
		return {"ok": true}

	if active_phase == Orchestrator.PHASE_INTERACTION:
		if baseline_phase != active_phase:
			return {"ok": false, "failure_code": "QSDK_R10F_INTERACTION_NOT_LOCKSTEP"}
		return _schedule_interaction_v1(global_step)

	if active_phase in [Orchestrator.PHASE_CONFIRM_PRONE, Orchestrator.PHASE_POST_KICK_RECOVERY]:
		if baseline_phase != Orchestrator.PHASE_MATCHED_CONTINUATION:
			return {"ok": false, "failure_code": "QSDK_R10F_POST_INTERACTION_PAIR_INVALID"}
		if (active["postkick_recovery_initialization_receipt"] as Dictionary).is_empty():
			var initialized := _initialize_postkick_recovery_v1(global_step)
			if not bool(initialized.get("ok", false)):
				return initialized
			var baseline_started := _start_walking_session_v1(
				EnergyInitializer.BASELINE_ARM_ID,
				"matched_continuation",
				global_step,
			)
			if not bool(baseline_started.get("ok", false)):
				return baseline_started
			return {"ok": true}
		var active_planned := (
			_create_passive_recovery_observation_application_v1(global_step)
			if active_phase == Orchestrator.PHASE_CONFIRM_PRONE
			else _apply_recovery_control_v1(EnergyInitializer.ACTIVE_ARM_ID, global_step)
		)
		if not bool(active_planned.get("ok", false)):
			return active_planned
		return _apply_next_walking_step_v1(EnergyInitializer.BASELINE_ARM_ID, global_step)

	if active_phase == Orchestrator.PHASE_WALKING_RESUME:
		if baseline_phase != Orchestrator.PHASE_MATCHED_CONTINUATION:
			return {"ok": false, "failure_code": "QSDK_R10F_RESUME_PAIR_INVALID"}
		active = _arms[EnergyInitializer.ACTIVE_ARM_ID]
		var active_walking := (
			_start_walking_session_v1(
				EnergyInitializer.ACTIVE_ARM_ID,
				"walking_resume",
				global_step,
			)
			if (active["active_walking_session"] as Dictionary).is_empty()
			else _apply_next_walking_step_v1(EnergyInitializer.ACTIVE_ARM_ID, global_step)
		)
		if not bool(active_walking.get("ok", false)):
			return active_walking
		return _apply_next_walking_step_v1(EnergyInitializer.BASELINE_ARM_ID, global_step)

	return {
		"ok": false,
		"failure_code": "QSDK_R10F_UNPLANNED_PHASE_PAIR",
		"active_phase": active_phase,
		"baseline_phase": baseline_phase,
	}


func _apply_precondition_pair_barrier_application_v1(
	arm_id: String,
	completed_global_step: int,
) -> Dictionary:
	if (
		arm_id not in ARM_ORDER
		or not PreconditionPairBarrier.current_plan_valid_v1(_sdk, _precondition_pair_state)
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L6_PRECONDITION_PAIR_PLAN_STATE_INVALID",
		}
	var next_step := completed_global_step + 1
	var arm: Dictionary = _arms[arm_id]
	var action := String(arm.get("precondition_pair_action", ""))
	if (
		action not in [PreconditionPairBarrier.ACTION_WAIT, PreconditionPairBarrier.ACTION_RELEASE]
		or int(_precondition_pair_state.get("planned_global_semantic_step", -1)) != next_step
		or (
			String(
				(_precondition_pair_state["planned_action_by_arm"] as Dictionary).get(arm_id, "")
			)
			!= action
		)
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L6_PRECONDITION_PAIR_APPLICATION_ACTION_INVALID",
		}
	var facade: RefCounted = arm["facade"]
	var configuration: Dictionary = (
		facade
		. configure_all_motors_v1(
			false,
			next_step,
			"l6_precondition_pair_%s_motors_disabled" % action,
		)
	)
	if not bool(configuration.get("ok", false)):
		return configuration
	(arm["motor_configuration_receipts"] as Array).append(configuration.duplicate(true))
	var motor_readback: Dictionary = (
		facade
		. motor_population_readback_v1(
			next_step,
			false,
			"l6_precondition_pair_%s_pre_solver_readback" % action,
		)
	)
	if not bool(motor_readback.get("ok", false)):
		return motor_readback
	_total_native_readback_count += int(motor_readback.get("native_readback_count", 0))
	var pair_plan: Dictionary = _precondition_pair_state["current_plan"]
	var no_actuation_intent := (
		LocomotionFacade
		. no_actuation_ledger_application_intent_v1(
			_sdk,
			next_step,
			Orchestrator.PHASE_PRECONDITION_RECOVERY,
			"none",
			null,
			true,
			pair_plan,
			motor_readback,
		)
	)
	if not bool(no_actuation_intent.get("ok", false)):
		return no_actuation_intent
	var projection := _build_precondition_pair_barrier_application_projection_v1(
		_sdk,
		_precondition_pair_state,
		arm_id,
		next_step,
		action,
		configuration,
		motor_readback,
		no_actuation_intent,
	)
	if not bool(projection.get("ok", false)):
		return projection
	arm["pending_application"] = no_actuation_intent.duplicate(true)
	arm["next_recovery_control"] = {}
	arm["precondition_pair_barrier_application_projection"] = projection.duplicate(true)
	(arm["precondition_pair_barrier_application_projections"] as Array).append(
		projection.duplicate(true)
	)
	_arms[arm_id] = arm
	return {
		"ok": true,
		"application_projection_sha256": String(projection["payload_sha256"]),
	}


static func _build_precondition_pair_barrier_application_projection_v1(
	sdk: Object,
	pair_state: Dictionary,
	arm_id: String,
	global_step: int,
	action: String,
	configuration: Dictionary,
	motor_readback: Dictionary,
	ledger_intent: Dictionary,
) -> Dictionary:
	var readback_rows_value: Variant = motor_readback.get("ordered_joint_readbacks")
	if not (readback_rows_value is Array):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L6_PRECONDITION_PAIR_READBACK_ROWS_MISSING",
		}
	var ordered_motor_readbacks: Array = []
	for row_value in readback_rows_value as Array:
		if not (row_value is Dictionary):
			return {
				"ok": false,
				"failure_code": "QSDK_R10F_L6_PRECONDITION_PAIR_READBACK_ROW_INVALID",
			}
		var row: Dictionary = row_value
		(
			ordered_motor_readbacks
			. append(
				{
					"joint_id": String(row.get("joint_id", "")),
					"motor_enabled": bool(row.get("motor_enabled", true)),
					"motor_target_velocity_rad_s":
					float(row.get("motor_target_velocity_rad_s", NAN)),
				}
			)
		)
	var pair_plan: Dictionary = pair_state.get("current_plan", {})
	var projection := {
		"schema_version": PRECONDITION_PAIR_APPLICATION_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": PreconditionPairBarrier.REPAIR_ID,
		"ok": true,
		"attempt_id": String(pair_state.get("attempt_id", "")),
		"arm_id": arm_id,
		"model_instance_id":
		String((pair_state.get("model_instance_id_by_arm", {}) as Dictionary).get(arm_id, "")),
		"global_semantic_step": global_step,
		"action_kind": action,
		"terminal_source_sha256":
		String((pair_state.get("terminal_source_sha256_by_arm", {}) as Dictionary).get(arm_id, "")),
		"pair_plan_receipt": pair_plan.duplicate(true),
		"pair_plan_receipt_sha256": String(pair_plan.get("payload_sha256", "")),
		"motor_configuration_receipt": configuration.duplicate(true),
		"motor_configuration_receipt_sha256": _canonical_sha256_static_v1(sdk, configuration),
		"motor_population_readback": motor_readback.duplicate(true),
		"motor_population_readback_sha256": _canonical_sha256_static_v1(sdk, motor_readback),
		"ledger_application_intent": ledger_intent.duplicate(true),
		"ledger_application_intent_sha256": _canonical_sha256_static_v1(sdk, ledger_intent),
		"ordered_motor_readbacks": ordered_motor_readbacks,
		"control_owner": "none",
		"actuation_owner": "none",
		"no_actuation_requested": true,
		"source_measurement": true,
		"outcome_derived_readiness": false,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"solver_reset_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	projection["payload_sha256"] = _payload_sha256_static_v1(sdk, projection)
	if not precondition_pair_barrier_application_valid_v1(
		sdk,
		projection,
		pair_state,
		arm_id,
		global_step,
		action,
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L6_PRECONDITION_PAIR_APPLICATION_BUILD_INVALID",
			"application_projection": projection,
		}
	return projection


## Validate a retained wait/release application from only the bytes carried by
## that application. Historical pair states advance after each arm completes a
## frame, so terminal validation must not depend on the worker's later mutable
## state. The live validator below adds that state binding at execution time.
static func precondition_pair_barrier_application_retained_valid_v1(
	sdk: Object,
	application: Dictionary,
) -> bool:
	if (
		sdk == null
		or not _dictionary_keys_exact_v1(application, PRECONDITION_PAIR_APPLICATION_KEYS)
		or String(application.get("schema_version", "")) != PRECONDITION_PAIR_APPLICATION_SCHEMA
		or String(application.get("gate_id", "")) != GATE_ID
		or String(application.get("repair_id", "")) != PreconditionPairBarrier.REPAIR_ID
		or typeof(application.get("ok")) != TYPE_BOOL
		or not bool(application.get("ok"))
		or String(application.get("attempt_id", "")).is_empty()
		or String(application.get("arm_id", "")) not in ARM_ORDER
		or String(application.get("model_instance_id", "")).is_empty()
		or typeof(application.get("global_semantic_step")) != TYPE_INT
		or int(application.get("global_semantic_step", -1)) < 2
		or (
			String(application.get("action_kind", ""))
			not in [PreconditionPairBarrier.ACTION_WAIT, PreconditionPairBarrier.ACTION_RELEASE]
		)
		or not _valid_sha256_static_v1(String(application.get("terminal_source_sha256", "")))
		or typeof(application.get("no_actuation_requested")) != TYPE_BOOL
		or not bool(application.get("no_actuation_requested"))
		or String(application.get("control_owner", "")) != "none"
		or String(application.get("actuation_owner", "")) != "none"
		or typeof(application.get("source_measurement")) != TYPE_BOOL
		or not bool(application.get("source_measurement"))
		or typeof(application.get("outcome_derived_readiness")) != TYPE_BOOL
		or bool(application.get("outcome_derived_readiness"))
		or int(application.get("body_transform_write_count", -1)) != 0
		or int(application.get("body_velocity_write_count", -1)) != 0
		or int(application.get("solver_reset_count", -1)) != 0
		or bool(application.get("physical_acceptance_authority", true))
		or bool(application.get("release_authority", true))
	):
		return false
	var arm_id := String(application["arm_id"])
	var global_step := int(application["global_semantic_step"])
	var action := String(application["action_kind"])
	var pair_plan_value: Variant = application.get("pair_plan_receipt")
	if not (pair_plan_value is Dictionary):
		return false
	var pair_plan: Dictionary = pair_plan_value
	var action_map_value: Variant = pair_plan.get("action_by_arm")
	var ready_map_value: Variant = pair_plan.get("ready_by_arm")
	var source_map_value: Variant = pair_plan.get("terminal_source_sha256_by_arm")
	if (
		not _dictionary_keys_exact_v1(pair_plan, PreconditionPairBarrier.PLAN_KEYS)
		or String(pair_plan.get("schema_version", "")) != PreconditionPairBarrier.PLAN_SCHEMA
		or String(pair_plan.get("gate_id", "")) != GATE_ID
		or String(pair_plan.get("repair_id", "")) != PreconditionPairBarrier.REPAIR_ID
		or String(pair_plan.get("barrier_id", "")) != PreconditionPairBarrier.BARRIER_ID
		or String(pair_plan.get("attempt_id", "")) != String(application["attempt_id"])
		or typeof(pair_plan.get("completed_global_semantic_step")) != TYPE_INT
		or int(pair_plan.get("completed_global_semantic_step", -1)) != global_step - 1
		or typeof(pair_plan.get("planned_global_semantic_step")) != TYPE_INT
		or int(pair_plan.get("planned_global_semantic_step", -1)) != global_step
		or pair_plan.get("ordered_arm_ids") != ARM_ORDER
		or not (action_map_value is Dictionary)
		or not (ready_map_value is Dictionary)
		or not (source_map_value is Dictionary)
		or not _dictionary_keys_exact_v1(action_map_value as Dictionary, ARM_ORDER)
		or not _dictionary_keys_exact_v1(ready_map_value as Dictionary, ARM_ORDER)
		or not _dictionary_keys_exact_v1(source_map_value as Dictionary, ARM_ORDER)
		or not _valid_sha256_static_v1(String(pair_plan.get("state_before_sha256", "")))
		or typeof(pair_plan.get("common_solver_frame_required")) != TYPE_BOOL
		or not bool(pair_plan.get("common_solver_frame_required"))
		or typeof(pair_plan.get("world_pause_or_step_skip_permitted")) != TYPE_BOOL
		or bool(pair_plan.get("world_pause_or_step_skip_permitted"))
		or typeof(pair_plan.get("motors_enabled_for_wait_or_release_permitted")) != TYPE_BOOL
		or bool(pair_plan.get("motors_enabled_for_wait_or_release_permitted"))
		or typeof(pair_plan.get("outcome_derived_readiness")) != TYPE_BOOL
		or bool(pair_plan.get("outcome_derived_readiness"))
		or typeof(pair_plan.get("physical_acceptance_authority")) != TYPE_BOOL
		or bool(pair_plan.get("physical_acceptance_authority"))
		or typeof(pair_plan.get("release_authority")) != TYPE_BOOL
		or bool(pair_plan.get("release_authority"))
		or (
			String(pair_plan.get("payload_sha256", "")) != _payload_sha256_static_v1(sdk, pair_plan)
		)
		or (
			String(application.get("pair_plan_receipt_sha256", ""))
			!= String(pair_plan.get("payload_sha256", ""))
		)
	):
		return false
	var actions: Dictionary = action_map_value
	var ready: Dictionary = ready_map_value
	var terminal_sources: Dictionary = source_map_value
	var ready_count := 0
	for arm_id_value in ARM_ORDER:
		var candidate_arm_id := String(arm_id_value)
		if (
			typeof(ready.get(candidate_arm_id)) != TYPE_BOOL
			or typeof(actions.get(candidate_arm_id)) != TYPE_STRING
			or typeof(terminal_sources.get(candidate_arm_id)) != TYPE_STRING
		):
			return false
		var candidate_ready := bool(ready[candidate_arm_id])
		if candidate_ready:
			ready_count += 1
			if not _valid_sha256_static_v1(String(terminal_sources[candidate_arm_id])):
				return false
		elif not String(terminal_sources[candidate_arm_id]).is_empty():
			return false
	if ready_count not in [1, ARM_ORDER.size()]:
		return false
	for arm_id_value in ARM_ORDER:
		var candidate_arm_id := String(arm_id_value)
		var expected_action := (
			PreconditionPairBarrier.ACTION_RELEASE
			if ready_count == ARM_ORDER.size()
			else (
				PreconditionPairBarrier.ACTION_WAIT
				if bool(ready[candidate_arm_id])
				else PreconditionPairBarrier.ACTION_RECOVERY
			)
		)
		if String(actions[candidate_arm_id]) != expected_action:
			return false
	if (
		not bool(ready[arm_id])
		or String(actions[arm_id]) != action
		or String(terminal_sources[arm_id]) != String(application["terminal_source_sha256"])
		or (action == PreconditionPairBarrier.ACTION_WAIT and ready_count != 1)
		or (action == PreconditionPairBarrier.ACTION_RELEASE and ready_count != ARM_ORDER.size())
	):
		return false
	var configuration_value: Variant = application.get("motor_configuration_receipt")
	var readback_value: Variant = application.get("motor_population_readback")
	var ledger_value: Variant = application.get("ledger_application_intent")
	var ordered_value: Variant = application.get("ordered_motor_readbacks")
	if (
		not (configuration_value is Dictionary)
		or not (readback_value is Dictionary)
		or not (ledger_value is Dictionary)
		or not (ordered_value is Array)
	):
		return false
	var configuration: Dictionary = configuration_value
	var readback: Dictionary = readback_value
	var ledger: Dictionary = ledger_value
	var ordered: Array = ordered_value
	if (
		(
			String(configuration.get("schema_version", ""))
			!= "sporespore_qsdk_r10f_recovery_native_motor_configuration_v1"
		)
		or not bool(configuration.get("ok", false))
		or int(configuration.get("global_semantic_step", -1)) != global_step
		or bool(configuration.get("motor_enabled", true))
		or (
			int(configuration.get("motor_configuration_write_count", -1))
			!= LocomotionFacade.JOINT_IDS.size() * 2
		)
		or int(configuration.get("body_transform_write_count", -1)) != 0
		or int(configuration.get("body_velocity_write_count", -1)) != 0
		or int(configuration.get("solver_reset_count", -1)) != 0
		or not bool(configuration.get("physics_state_modified", false))
		or bool(configuration.get("physical_acceptance_authority", true))
		or bool(configuration.get("release_authority", true))
		or (
			String(application.get("motor_configuration_receipt_sha256", ""))
			!= _canonical_sha256_static_v1(sdk, configuration)
		)
		or not bool(readback.get("ok", false))
		or int(readback.get("global_semantic_step", -1)) != global_step
		or bool(readback.get("expected_motor_enabled", true))
		or int(readback.get("motor_enabled_count", -1)) != 0
		or int(readback.get("zero_target_velocity_count", -1)) != LocomotionFacade.JOINT_IDS.size()
		or int(readback.get("native_readback_count", -1)) != LocomotionFacade.JOINT_IDS.size() * 3
		or bool(readback.get("physics_state_modified", true))
		or bool(readback.get("physical_acceptance_authority", true))
		or bool(readback.get("release_authority", true))
		or (
			String(application.get("motor_population_readback_sha256", ""))
			!= _canonical_sha256_static_v1(sdk, readback)
		)
		or (
			String(ledger.get("schema_version", ""))
			!= LocomotionFacade.NO_ACTUATION_LEDGER_APPLICATION_SCHEMA
		)
		or not bool(ledger.get("ok", false))
		or int(ledger.get("semantic_step", -1)) != global_step
		or String(ledger.get("phase", "")) != Orchestrator.PHASE_PRECONDITION_RECOVERY
		or String(ledger.get("controller_owner", "")) != "none"
		or ledger.get("recovery_controller_id") != null
		or not bool(ledger.get("no_actuation_requested", false))
		or int(ledger.get("motor_enabled_count", -1)) != 0
		or not bool(ledger.get("native_joint_motors_disabled", false))
		or ledger.get("owner_source_receipt") != pair_plan
		or (
			String(ledger.get("owner_source_receipt_sha256", ""))
			!= _canonical_sha256_static_v1(sdk, pair_plan)
		)
		or ledger.get("motor_population_readback") != readback
		or (
			String(ledger.get("motor_population_readback_sha256", ""))
			!= String(application.get("motor_population_readback_sha256", ""))
		)
		or bool(ledger.get("force_aware_recovery_used", true))
		or bool(ledger.get("physical_acceptance_authority", true))
		or bool(ledger.get("release_authority", true))
		or (
			String(application.get("ledger_application_intent_sha256", ""))
			!= _canonical_sha256_static_v1(sdk, ledger)
		)
		or ordered.size() != LocomotionFacade.JOINT_IDS.size()
	):
		return false
	var configuration_rows_value: Variant = configuration.get("ordered_joint_receipts")
	var native_rows_value: Variant = readback.get("ordered_joint_readbacks")
	if not (configuration_rows_value is Array) or not (native_rows_value is Array):
		return false
	var configuration_rows: Array = configuration_rows_value
	var native_rows: Array = native_rows_value
	if (
		configuration_rows.size() != LocomotionFacade.JOINT_IDS.size()
		or native_rows.size() != LocomotionFacade.JOINT_IDS.size()
	):
		return false
	for index in range(LocomotionFacade.JOINT_IDS.size()):
		if (
			not (configuration_rows[index] is Dictionary)
			or not (native_rows[index] is Dictionary)
			or not (ordered[index] is Dictionary)
		):
			return false
		var configured: Dictionary = configuration_rows[index]
		var native: Dictionary = native_rows[index]
		var projected: Dictionary = ordered[index]
		var joint_id := String(LocomotionFacade.JOINT_IDS[index])
		var actuator_id := String(NativeWorldScript.ORDERED_ACTUATOR_IDS[index])
		if (
			String(configured.get("joint_id", "")) != joint_id
			or bool(configured.get("motor_enabled", true))
			or float(configured.get("motor_target_velocity_rad_s", NAN)) != 0.0
			or String(native.get("actuator_id", "")) != actuator_id
			or String(native.get("joint_id", "")) != joint_id
			or bool(native.get("motor_enabled", true))
			or float(native.get("motor_target_velocity_rad_s", NAN)) != 0.0
			or not is_finite(float(native.get("motor_maximum_impulse_nms", NAN)))
			or float(native.get("motor_maximum_impulse_nms", NAN)) <= 0.0
			or not _dictionary_keys_exact_v1(
				projected,
				["joint_id", "motor_enabled", "motor_target_velocity_rad_s"],
			)
			or String(projected.get("joint_id", "")) != joint_id
			or bool(projected.get("motor_enabled", true))
			or float(projected.get("motor_target_velocity_rad_s", NAN)) != 0.0
		):
			return false
	return (
		String(application.get("payload_sha256", "")) == _payload_sha256_static_v1(sdk, application)
	)


static func precondition_pair_barrier_application_valid_v1(
	sdk: Object,
	application: Dictionary,
	pair_state: Dictionary,
	expected_arm_id: String,
	expected_global_step: int,
	expected_action: String,
) -> bool:
	if (
		sdk == null
		or not precondition_pair_barrier_application_retained_valid_v1(sdk, application)
		or expected_arm_id not in ARM_ORDER
		or (
			expected_action
			not in [PreconditionPairBarrier.ACTION_WAIT, PreconditionPairBarrier.ACTION_RELEASE]
		)
		or not PreconditionPairBarrier.current_plan_valid_v1(sdk, pair_state)
		or not _dictionary_keys_exact_v1(application, PRECONDITION_PAIR_APPLICATION_KEYS)
		or String(application.get("schema_version", "")) != PRECONDITION_PAIR_APPLICATION_SCHEMA
		or String(application.get("gate_id", "")) != GATE_ID
		or String(application.get("repair_id", "")) != PreconditionPairBarrier.REPAIR_ID
		or typeof(application.get("ok")) != TYPE_BOOL
		or not bool(application.get("ok"))
		or String(application.get("attempt_id", "")) != String(pair_state.get("attempt_id", ""))
		or String(application.get("arm_id", "")) != expected_arm_id
		or (
			String(application.get("model_instance_id", ""))
			!= String(
				(pair_state.get("model_instance_id_by_arm", {}) as Dictionary).get(
					expected_arm_id, ""
				)
			)
		)
		or typeof(application.get("global_semantic_step")) != TYPE_INT
		or int(application.get("global_semantic_step")) != expected_global_step
		or expected_global_step != int(pair_state.get("planned_global_semantic_step", -1))
		or String(application.get("action_kind", "")) != expected_action
		or (
			String(
				(pair_state.get("planned_action_by_arm", {}) as Dictionary).get(expected_arm_id, "")
			)
			!= expected_action
		)
		or not bool((pair_state.get("ready_by_arm", {}) as Dictionary).get(expected_arm_id, false))
		or (
			String(application.get("terminal_source_sha256", ""))
			!= String(
				(pair_state.get("terminal_source_sha256_by_arm", {}) as Dictionary).get(
					expected_arm_id, ""
				)
			)
		)
		or not (application.get("pair_plan_receipt") is Dictionary)
		or application.get("pair_plan_receipt") != pair_state.get("current_plan")
		or (
			String(application.get("pair_plan_receipt_sha256", ""))
			!= String(pair_state.get("current_plan_sha256", ""))
		)
		or typeof(application.get("no_actuation_requested")) != TYPE_BOOL
		or not bool(application.get("no_actuation_requested"))
		or String(application.get("control_owner", "")) != "none"
		or String(application.get("actuation_owner", "")) != "none"
		or typeof(application.get("source_measurement")) != TYPE_BOOL
		or not bool(application.get("source_measurement"))
		or typeof(application.get("outcome_derived_readiness")) != TYPE_BOOL
		or bool(application.get("outcome_derived_readiness"))
		or int(application.get("body_transform_write_count", -1)) != 0
		or int(application.get("body_velocity_write_count", -1)) != 0
		or int(application.get("solver_reset_count", -1)) != 0
		or bool(application.get("physical_acceptance_authority", true))
		or bool(application.get("release_authority", true))
	):
		return false
	var configuration_value: Variant = application.get("motor_configuration_receipt")
	var readback_value: Variant = application.get("motor_population_readback")
	var ledger_value: Variant = application.get("ledger_application_intent")
	var ordered_value: Variant = application.get("ordered_motor_readbacks")
	if (
		not (configuration_value is Dictionary)
		or not (readback_value is Dictionary)
		or not (ledger_value is Dictionary)
		or not (ordered_value is Array)
	):
		return false
	var configuration: Dictionary = configuration_value
	var readback: Dictionary = readback_value
	var ledger: Dictionary = ledger_value
	var ordered: Array = ordered_value
	if (
		(
			String(configuration.get("schema_version", ""))
			!= "sporespore_qsdk_r10f_recovery_native_motor_configuration_v1"
		)
		or not bool(configuration.get("ok", false))
		or int(configuration.get("global_semantic_step", -1)) != expected_global_step
		or bool(configuration.get("motor_enabled", true))
		or (
			int(configuration.get("motor_configuration_write_count", -1))
			!= LocomotionFacade.JOINT_IDS.size() * 2
		)
		or int(configuration.get("body_transform_write_count", -1)) != 0
		or int(configuration.get("body_velocity_write_count", -1)) != 0
		or int(configuration.get("solver_reset_count", -1)) != 0
		or not bool(configuration.get("physics_state_modified", false))
		or bool(configuration.get("physical_acceptance_authority", true))
		or bool(configuration.get("release_authority", true))
		or (
			String(application.get("motor_configuration_receipt_sha256", ""))
			!= _canonical_sha256_static_v1(sdk, configuration)
		)
		or not bool(readback.get("ok", false))
		or int(readback.get("global_semantic_step", -1)) != expected_global_step
		or bool(readback.get("expected_motor_enabled", true))
		or int(readback.get("motor_enabled_count", -1)) != 0
		or int(readback.get("zero_target_velocity_count", -1)) != LocomotionFacade.JOINT_IDS.size()
		or int(readback.get("native_readback_count", -1)) != LocomotionFacade.JOINT_IDS.size() * 3
		or bool(readback.get("physics_state_modified", true))
		or bool(readback.get("physical_acceptance_authority", true))
		or bool(readback.get("release_authority", true))
		or (
			String(application.get("motor_population_readback_sha256", ""))
			!= _canonical_sha256_static_v1(sdk, readback)
		)
		or (
			String(ledger.get("schema_version", ""))
			!= LocomotionFacade.NO_ACTUATION_LEDGER_APPLICATION_SCHEMA
		)
		or not bool(ledger.get("ok", false))
		or int(ledger.get("semantic_step", -1)) != expected_global_step
		or String(ledger.get("phase", "")) != Orchestrator.PHASE_PRECONDITION_RECOVERY
		or String(ledger.get("controller_owner", "")) != "none"
		or ledger.get("recovery_controller_id") != null
		or not bool(ledger.get("no_actuation_requested", false))
		or int(ledger.get("motor_enabled_count", -1)) != 0
		or not bool(ledger.get("native_joint_motors_disabled", false))
		or ledger.get("owner_source_receipt") != pair_state.get("current_plan")
		or (
			String(ledger.get("owner_source_receipt_sha256", ""))
			!= _canonical_sha256_static_v1(sdk, pair_state.get("current_plan"))
		)
		or ledger.get("motor_population_readback") != readback
		or (
			String(ledger.get("motor_population_readback_sha256", ""))
			!= String(application.get("motor_population_readback_sha256", ""))
		)
		or bool(ledger.get("force_aware_recovery_used", true))
		or bool(ledger.get("physical_acceptance_authority", true))
		or bool(ledger.get("release_authority", true))
		or (
			String(application.get("ledger_application_intent_sha256", ""))
			!= _canonical_sha256_static_v1(sdk, ledger)
		)
		or ordered.size() != LocomotionFacade.JOINT_IDS.size()
	):
		return false
	var configuration_rows_value: Variant = configuration.get("ordered_joint_receipts")
	var native_rows_value: Variant = readback.get("ordered_joint_readbacks")
	if not (configuration_rows_value is Array) or not (native_rows_value is Array):
		return false
	var configuration_rows: Array = configuration_rows_value
	var native_rows: Array = native_rows_value
	if (
		configuration_rows.size() != LocomotionFacade.JOINT_IDS.size()
		or native_rows.size() != LocomotionFacade.JOINT_IDS.size()
	):
		return false
	for index in range(LocomotionFacade.JOINT_IDS.size()):
		if (
			not (configuration_rows[index] is Dictionary)
			or not (native_rows[index] is Dictionary)
			or not (ordered[index] is Dictionary)
		):
			return false
		var configured: Dictionary = configuration_rows[index]
		var native: Dictionary = native_rows[index]
		var projected: Dictionary = ordered[index]
		var joint_id := String(LocomotionFacade.JOINT_IDS[index])
		var actuator_id := String(NativeWorldScript.ORDERED_ACTUATOR_IDS[index])
		if (
			String(configured.get("joint_id", "")) != joint_id
			or bool(configured.get("motor_enabled", true))
			or float(configured.get("motor_target_velocity_rad_s", NAN)) != 0.0
			or String(native.get("actuator_id", "")) != actuator_id
			or String(native.get("joint_id", "")) != joint_id
			or bool(native.get("motor_enabled", true))
			or float(native.get("motor_target_velocity_rad_s", NAN)) != 0.0
			or not is_finite(float(native.get("motor_maximum_impulse_nms", NAN)))
			or float(native.get("motor_maximum_impulse_nms", NAN)) <= 0.0
			or not _dictionary_keys_exact_v1(
				projected,
				["joint_id", "motor_enabled", "motor_target_velocity_rad_s"],
			)
			or String(projected.get("joint_id", "")) != joint_id
			or bool(projected.get("motor_enabled", true))
			or float(projected.get("motor_target_velocity_rad_s", NAN)) != 0.0
		):
			return false
	return (
		String(application.get("payload_sha256", "")) == _payload_sha256_static_v1(sdk, application)
	)


## Explicit overridable selection; every existing worker remains V6.
func _recovery_controller_for_phase_v1(_phase: String) -> String:
	return RECOVERY_CONTROLLER_ID


func _advance_recovery_stage_v1(arm: Dictionary, bound: Dictionary, global_step: int) -> Dictionary:
	return RecoveryAdvanceStageL15.advance_v1(_sdk, _context, arm, bound, global_step)


func _apply_recovery_control_v1(arm_id: String, completed_global_step: int) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var selected_controller := _recovery_controller_for_phase_v1(String(arm.get("orchestrator_state", {}).get("phase", "")))
	var control_value: Variant = arm.get("next_recovery_control")
	if not (control_value is Dictionary) or (control_value as Dictionary).is_empty():
		return {"ok": false, "failure_code": "QSDK_R10F_NEXT_RECOVERY_CONTROL_MISSING"}
	var control: Dictionary = control_value
	var observation := _global_observation_from_collection_v1(arm["last_collection"])
	var positions := _joint_position_map_v1(observation)
	if positions.size() != LocomotionFacade.JOINT_IDS.size():
		return {"ok": false, "failure_code": "QSDK_R10F_RECOVERY_JOINT_POSITION_MAP_INVALID"}
	var application := (
		RouteScript
		. apply_behavior_control_route_aware_discrete_staging_v2(
			_sdk,
			control,
			arm["model"],
			positions,
			false,
			selected_controller,
		)
	)
	var no_actuation := bool(control.get("no_actuation_requested", false))
	if (
		not bool(application.get("ok", false))
		or int(application.get("semantic_step", -1)) != completed_global_step + 1
		or not (
			BehaviorWorker
			. behavior_application_receipt_valid_v4(
				ACTUATOR_MODE,
				application,
				no_actuation,
				ENERGY_ROUTE_ID,
				true,
				selected_controller,
			)
		)
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_RECOVERY_CONTROL_APPLICATION_INVALID",
			"application": application,
		}
	arm["pending_application"] = application.duplicate(true)
	arm["next_recovery_control"] = {}
	_arms[arm_id] = arm
	return {"ok": true}


func _initialize_postkick_recovery_v1(completed_global_step: int) -> Dictionary:
	if _repair_id == "QSDK-R10F-L15":
		return _consume_l15_no_actuation_stage_v1(
			NoActuationStageL15.initialize_v1(
				_sdk, _context, _arms[EnergyInitializer.ACTIVE_ARM_ID], completed_global_step
			)
		)
	var arm_id := EnergyInitializer.ACTIVE_ARM_ID
	var arm: Dictionary = _arms[arm_id]
	var initialized := RouteScript.initialize_behavior_arm_v1(
		_sdk, _context, INTERNAL_RECOVERY_ARM_KIND
	)
	if not bool(initialized.get("ok", false)):
		return initialized
	var memory: Dictionary = (initialized["memory"] as Dictionary).duplicate(true)
	var facade: RefCounted = arm["facade"]
	var next_step := completed_global_step + 1
	var motor_readback: Dictionary = facade.motor_population_readback_v1(
		next_step, false, "post_kick_passive_prone_first_observation"
	)
	if not bool(motor_readback.get("ok", false)):
		return motor_readback
	_total_native_readback_count += int(motor_readback.get("native_readback_count", 0))
	var no_actuation := (
		LocomotionFacade
		. no_actuation_ledger_application_intent_v1(
			_sdk,
			next_step,
			String(memory["phase"]),
			"recovery_v6",
			RECOVERY_CONTROLLER_ID,
			false,
			initialized["initialization_receipt"],
			motor_readback,
		)
	)
	if not bool(no_actuation.get("ok", false)):
		return no_actuation
	arm["recovery_memory"] = memory
	arm["postkick_recovery_initialization_receipt"] = (
		(initialized["initialization_receipt"] as Dictionary).duplicate(true)
	)
	arm["pending_application"] = no_actuation
	arm["next_recovery_control"] = {}
	_arms[arm_id] = arm
	return {"ok": true}


func _create_passive_recovery_observation_application_v1(
	completed_global_step: int,
) -> Dictionary:
	if _repair_id == "QSDK-R10F-L15":
		return _consume_l15_no_actuation_stage_v1(
			NoActuationStageL15.passive_v1(
				_sdk, _arms[EnergyInitializer.ACTIVE_ARM_ID], completed_global_step
			)
		)
	var arm_id := EnergyInitializer.ACTIVE_ARM_ID
	var arm: Dictionary = _arms[arm_id]
	var control_value: Variant = arm.get("next_recovery_control")
	if not (control_value is Dictionary) or (control_value as Dictionary).is_empty():
		return {"ok": false, "failure_code": "QSDK_R10F_PASSIVE_OWNER_SOURCE_MISSING"}
	var control: Dictionary = control_value
	var facade: RefCounted = arm["facade"]
	var next_step := completed_global_step + 1
	var motor_readback: Dictionary = facade.motor_population_readback_v1(
		next_step, false, "continued_zero_actuation_passive_prone_observation"
	)
	if not bool(motor_readback.get("ok", false)):
		return motor_readback
	_total_native_readback_count += int(motor_readback.get("native_readback_count", 0))
	var no_actuation := (
		LocomotionFacade
		. no_actuation_ledger_application_intent_v1(
			_sdk,
			next_step,
			String((arm["recovery_memory"] as Dictionary)["phase"]),
			"recovery_v6",
			RECOVERY_CONTROLLER_ID,
			bool(control.get("matched_zero_command", false)),
			control,
			motor_readback,
		)
	)
	if not bool(no_actuation.get("ok", false)):
		return no_actuation
	arm["pending_application"] = no_actuation
	arm["next_recovery_control"] = {}
	_arms[arm_id] = arm
	return {"ok": true}


func _consume_l15_no_actuation_stage_v1(stage: Dictionary) -> Dictionary:
	_total_native_readback_count += int(stage["consumed_native_readback_count"])
	if stage.get("ok") != true:
		return stage["failure"]
	_arms[EnergyInitializer.ACTIVE_ARM_ID] = stage["arm"]
	# Internal state contains live facade/model objects. Do not leak it into
	# the serializable worker result or any abort/envelope projection.
	return {"ok": true}


func _walking_uses_preloaded_native_runtime_v1() -> bool:
	return false


func _walking_frame_id_v1(_evaluation_segment_id: String) -> String:
	return "" # Official and historical development routes remain unchanged.


func _walking_gait_amplitude_v1(_segment_id: String, _local_step: int) -> float:
	return 1.0


func _walking_phase_progression_mode_v1(_segment_id: String, _local_step: int) -> String:
	return "contact_gated" # Official and historical development routes unchanged.


func _walking_contact_profile_id_v1(_segment_id: String) -> String:
	return ""


func _walking_start_profile_id_v1(_segment_id: String) -> String:
	return ""


func _walking_session_step_limit_v1(_segment_id: String) -> int:
	return WalkingEvaluator.FIXED_SEGMENT_STEP_COUNT


func _walking_policy_id_v1(_segment_id: String) -> String:
	return ""


func _walking_owner_for_phase_v1(_phase: String) -> String:
	return "walking_bw5r_b"


func _walking_native_contact_source_v1(_arm: Dictionary, _segment_id: String) -> Dictionary:
	return {}


func _retain_development_walking_source_v1(_segment_id: String, _step: Dictionary, _step_sha: String) -> Dictionary:
	return {"ok": true}


func _walking_segment_valid_v1(segment: String) -> bool:
	return segment in WalkingEvaluator.SEGMENT_IDS


func _walking_prefix_profile_id_v1(_segment: String) -> String:
	return ""


func _walking_facade_evaluation_segment_v1(segment: String) -> String:
	return segment


func _start_walking_session_v1(
	arm_id: String,
	evaluation_segment_id: String,
	completed_global_step: int,
) -> Dictionary:
	if not _walking_segment_valid_v1(evaluation_segment_id):
		return {"ok": false, "failure_code": "QSDK_R10F_WALKING_SEGMENT_ID_INVALID"}
	var arm: Dictionary = _arms[arm_id]
	if not (arm["active_walking_session"] as Dictionary).is_empty():
		return {"ok": false, "failure_code": "QSDK_R10F_WALKING_SESSION_ALREADY_ACTIVE"}
	var facade: RefCounted
	if evaluation_segment_id == "walking_prefix":
		facade = arm["facade"]
	else:
		facade = LocomotionFacade.new()
		var binding: Dictionary = facade.bind_live_model_v1(arm["model"], arm["model_instance_id"])
		if not bool(binding.get("ok", false)):
			return binding
		var identity: Dictionary = facade.same_body_identity_receipt_v1(
			_sdk, completed_global_step, "fresh_%s_session_binding" % evaluation_segment_id
		)
		if (
			not bool(identity.get("ok", false))
			or (
				String(identity.get("body_population_instance_sha256", ""))
				!= String(arm["body_population_instance_sha256"])
			)
		):
			return {
				"ok": false,
				"failure_code": "QSDK_R10F_FRESH_SESSION_BODY_IDENTITY_INVALID",
			}
		arm["facade"] = facade
	var facade_segment_id := (
		"walking_prefix" if evaluation_segment_id == "walking_prefix" else "walking_resume"
	)
	var session_id := "r10f:%s:%s:%d" % [arm_id, evaluation_segment_id, completed_global_step]
	var started: Dictionary = (
		facade
		. start_walking_session_v1(
			facade_segment_id,
			session_id,
			_seed,
			completed_global_step,
			_walking_uses_preloaded_native_runtime_v1(),
			_walking_frame_id_v1(evaluation_segment_id),
			_walking_contact_profile_id_v1(evaluation_segment_id),
			_walking_start_profile_id_v1(evaluation_segment_id),
			_walking_policy_id_v1(evaluation_segment_id),
			_walking_prefix_profile_id_v1(evaluation_segment_id),
		)
	)
	if not bool(started.get("ok", false)):
		return started
	var handoff: Dictionary = (
		facade
		. begin_walking_actuation_handoff_v1(
			_sdk,
			_walking_facade_evaluation_segment_v1(evaluation_segment_id),
			completed_global_step + 1,
		)
	)
	if not bool(handoff.get("ok", false)):
		return handoff
	(arm["walking_actuation_handoff_receipts"] as Array).append(handoff.duplicate(true))
	(arm["motor_configuration_receipts"] as Array).append(
		(handoff["motor_configuration_receipt"] as Dictionary).duplicate(true)
	)
	_total_native_readback_count += int(handoff.get("native_readback_count", 0))
	var observation := _global_observation_from_collection_v1(arm["last_collection"])
	var initial_contacts := _contact_map_v1(observation)
	if initial_contacts.size() != WalkingEvaluator.LIMB_ORDER.size():
		return {"ok": false, "failure_code": "QSDK_R10F_WALKING_INITIAL_CONTACTS_INVALID"}
	arm["active_walking_session"] = {
		"evaluation_segment_id": evaluation_segment_id,
		"facade_segment_id": facade_segment_id,
		"session_id": session_id,
		"start_receipt": started.duplicate(true),
		"walking_actuation_handoff_receipt": handoff.duplicate(true),
		"initial_contact_by_limb": initial_contacts.duplicate(true),
		"trace_start_index": (arm["trace_rows"] as Array).size(),
		"scheduled_step_count": 0,
		"step_receipt_sha256s": [],
	}
	arm["walking_session_completion_attempted"] = false
	arm["last_walking_evaluation_failure"] = {}
	if evaluation_segment_id == "walking_prefix":
		arm["prefix_session_start_receipt"] = started.duplicate(true)
	_arms[arm_id] = arm
	return _apply_next_walking_step_v1(arm_id, completed_global_step)


func _apply_next_walking_step_v1(arm_id: String, completed_global_step: int) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var session: Dictionary = arm["active_walking_session"]
	if session.is_empty():
		return {"ok": false, "failure_code": "QSDK_R10F_ACTIVE_WALKING_SESSION_MISSING"}
	var local_step := int(session["scheduled_step_count"]) + 1
	var segment_id := String(session["evaluation_segment_id"])
	if (
		segment_id != "matched_continuation"
		and local_step > _walking_session_step_limit_v1(segment_id)
	):
		return {"ok": false, "failure_code": "QSDK_R10F_WALKING_SESSION_HORIZON_EXCEEDED"}
	var facade: RefCounted = arm["facade"]
	var phase := String((arm["orchestrator_state"] as Dictionary)["phase"])
	var step: Dictionary = (
		facade
		. sample_step_apply_v1(
			_sdk,
			completed_global_step + 1,
			local_step,
			phase,
			_walking_gait_amplitude_v1(segment_id, local_step),
			_walking_native_contact_source_v1(arm, segment_id),
			_walking_phase_progression_mode_v1(segment_id, local_step),
		)
	)
	if not bool(step.get("ok", false)):
		arm["last_walking_step_failure"] = step.duplicate(true)
		_arms[arm_id] = arm
		return step
	var application_value: Variant = step.get("ledger_application_intent")
	if not (application_value is Dictionary):
		var missing_ledger_failure := {
			"ok": false,
			"failure_code": "QSDK_R10F_WALKING_LEDGER_INTENT_MISSING",
			"portable_step_sources": step.duplicate(true),
		}
		arm["last_walking_step_failure"] = missing_ledger_failure.duplicate(true)
		_arms[arm_id] = arm
		return missing_ledger_failure
	var application: Dictionary = application_value
	if (
		int(application.get("semantic_step", -1)) != completed_global_step + 1
		or String(application.get("walking_session_id", "")) != String(session["session_id"])
		or int(application.get("walking_session_local_step", -1)) != local_step
	):
		var sequence_failure := {
			"ok": false,
			"failure_code": "QSDK_R10F_WALKING_LEDGER_SEQUENCE_INVALID",
			"portable_step_sources": step.duplicate(true),
			"ledger_application_intent": application.duplicate(true),
		}
		arm["last_walking_step_failure"] = sequence_failure.duplicate(true)
		_arms[arm_id] = arm
		return sequence_failure
	var step_sha := _canonical_sha256_v1(step)
	var development_retention := _retain_development_walking_source_v1(segment_id, step, step_sha)
	if development_retention.get("ok") != true:
		arm["last_walking_step_failure"] = development_retention.duplicate(true)
		_arms[arm_id] = arm
		return development_retention
	_total_native_readback_count += int(
		(step["motor_population_readback"] as Dictionary).get("native_readback_count", 0)
	)
	session["scheduled_step_count"] = local_step
	(session["step_receipt_sha256s"] as Array).append(step_sha)
	arm["active_walking_session"] = session
	arm["last_walking_step_failure"] = {}
	arm["pending_application"] = application.duplicate(true)
	_arms[arm_id] = arm
	return {"ok": true}


func _finish_walking_session_v1(arm_id: String) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var session: Dictionary = arm["active_walking_session"]
	if session.is_empty():
		return {"ok": true, "session_closed": false}
	if not walking_session_needs_shutdown_v2(arm):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L14_WALKING_COMPLETION_ALREADY_ATTEMPTED",
			"retained_failure": arm.get("last_walking_evaluation_failure", {}).duplicate(true),
		}
	# The facade shuts down the SDK session. Evaluation may fail afterward, so
	# record this attempt before calling it and never repeat shutdown in cleanup.
	arm["walking_session_completion_attempted"] = true
	_arms[arm_id] = arm
	var facade: RefCounted = arm["facade"]
	var completion: Dictionary = facade.finish_walking_session_v1()
	var result := close_walking_session_sources_v2(
		_sdk, arm_id, arm, completion, _walking_evaluation_is_development_smoke_v1(),
		_development_walking_diagnostic_maximum_steps_v1(), _walking_policy_id_v1(session["evaluation_segment_id"])
	)
	_arms[arm_id] = arm
	return result


func _walking_evaluation_is_development_smoke_v1() -> bool:
	return false


func _development_walking_diagnostic_maximum_steps_v1() -> int:
	return 30


static func walking_session_needs_shutdown_v2(arm: Dictionary) -> bool:
	return (
		arm.get("active_walking_session") is Dictionary
		and not (arm["active_walking_session"] as Dictionary).is_empty()
		and typeof(arm.get("walking_session_completion_attempted", false)) == TYPE_BOOL
		and arm.get("walking_session_completion_attempted", false) == false
	)


static func walking_terminal_input_v2(
	arm_id: String, arm: Dictionary, completion: Dictionary
) -> Dictionary:
	# This is the production input projection, also exercised without a world.
	# Do not cast malformed rows or source numbers into plausible measurements.
	var session: Dictionary = arm.get("active_walking_session", {})
	var all_rows: Array = arm.get("trace_rows", [])
	var start_value: Variant = session.get("trace_start_index")
	var count_value: Variant = session.get("scheduled_step_count")
	var slice_valid: bool = (
		typeof(start_value) == TYPE_INT
		and typeof(count_value) == TYPE_INT
		and start_value >= 0
		and count_value >= 1
		and start_value + count_value == all_rows.size()
	)
	var rows: Array = []
	if slice_valid:
		rows = all_rows.slice(start_value).duplicate(true)
	return {
		"trace_slice_valid": slice_valid,
		"evidence":
		{
			"arm_id": arm_id,
			"segment_id": session.get("evaluation_segment_id"),
			"session_id": session.get("session_id"),
			"expected_step_count": count_value,
			"start_receipt": session.get("start_receipt"),
			"completion_receipt": completion.duplicate(true),
			"initial_contact_by_limb": session.get("initial_contact_by_limb"),
			"rows": rows,
			"world_build_count": 1,
			"world_reset_count": arm.get("solver_reset_count"),
			"body_population_rebuild_count": arm.get("body_population_rebuild_count"),
			"direct_torso_force_command_count": arm.get("direct_torso_force_command_count"),
			"direct_torso_impulse_command_count": arm.get("direct_torso_impulse_command_count"),
			"direct_torso_velocity_command_count": arm.get("direct_torso_velocity_command_count"),
			"direct_torso_transform_command_count": arm.get("direct_torso_transform_command_count"),
			"fixture_spec_compiled_before_world_creation": true,
			"initial_perturbation_application_count": 0,
			"physics_engine": "Jolt Physics",
			"physics_hz": PHYSICS_HZ,
			"solver_velocity_steps": 20,
			"solver_position_steps": 7,
			"source_measurement": true,
		},
	}


static func close_walking_session_sources_v2(
	sdk: Object,
	arm_id: String,
	arm: Dictionary,
	completion: Dictionary,
	development_smoke: bool = false,
	maximum_diagnostic_steps: int = 30,
	development_policy_id: String = "",
) -> Dictionary:
	var session: Dictionary = arm["active_walking_session"]
	var projected := walking_terminal_input_v2(arm_id, arm, completion)
	var evidence: Dictionary = projected["evidence"]
	var failure_code := ""
	var evaluation := {}
	if (
		not (completion.get("adapter_summary") is Dictionary)
		or not (completion.get("adapter_shutdown_receipt") is Dictionary)
	):
		failure_code = "QSDK_R10F_WALKING_COMPLETION_RECEIPT_INVALID"
	elif not bool(projected["trace_slice_valid"]):
		failure_code = "QSDK_R10F_WALKING_TRACE_SLICE_INVALID"
	else:
		evaluation = (
			WalkingEvaluator.evaluate_development_smoke_segment_v1(sdk, evidence, maximum_diagnostic_steps, development_policy_id)
			if development_smoke
			else WalkingEvaluator.evaluate_segment_v2(sdk, evidence)
		)
		if not bool(evaluation.get("ok", false)):
			failure_code = "QSDK_R10F_WALKING_EVALUATION_INVALID"
	if not failure_code.is_empty():
		var failure := {
			"schema_version": "sporespore_qsdk_r10f_l14_walking_terminal_failure_retention_v1",
			"gate_id": GATE_ID,
			"repair_id": REPAIR_ID,
			"ledger_scope":
			{
				"subsystem": "recovery",
				"engine_scope": "godot_jolt",
				"authority_mode": "invalid_walking_terminal_source_retention",
				"question_class": "development",
			},
			"ok": false,
			"measurement_complete": false,
			"failure_code": failure_code,
			"evaluator_failure_code": evaluation.get("failure_code", ""),
			"arm_id": arm_id,
			"active_walking_session": session.duplicate(true),
			"all_observed_trace_rows": (arm["trace_rows"] as Array).duplicate(true),
			"completion_receipt": completion.duplicate(true),
			"walking_evaluation_input": evidence.duplicate(true),
			"evaluation": evaluation.duplicate(true),
			"trace_slice_valid": projected["trace_slice_valid"],
			"walking_session_completion_attempted": true,
			"physical_acceptance_authority": false,
			"release_authority": false,
		}
		failure["payload_sha256"] = _payload_sha256_static_v1(sdk, failure)
		arm["last_walking_evaluation_failure"] = failure
		return {"ok": false, "failure_code": failure_code, "retained_failure": failure}
	(
		(arm["walking_sessions"] as Array)
		. append(
			{
				"evaluation_segment_id": String(session["evaluation_segment_id"]),
				"session_id": String(session["session_id"]),
				"start_receipt": (session["start_receipt"] as Dictionary).duplicate(true),
				"completion_receipt": completion.duplicate(true),
				"step_receipt_sha256s": (session["step_receipt_sha256s"] as Array).duplicate(),
				"evaluation": evaluation.duplicate(true),
			}
		)
	)
	arm["active_walking_session"] = {}
	arm["last_walking_evaluation_failure"] = {}
	return {"ok": true, "session_closed": true}


func _finish_all_open_walking_sessions_v1() -> Dictionary:
	for arm_id_value in ARM_ORDER:
		var finished := _finish_walking_session_v1(String(arm_id_value))
		if not bool(finished.get("ok", false)):
			return finished
	return {"ok": true}


func _schedule_process_isolated_interaction_v1(completed_global_step: int) -> Dictionary:
	if _interaction_scheduled or _interaction_completed:
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L9_CHILD_INTERACTION_ALREADY_SCHEDULED",
		}
	var finished := _finish_walking_session_v1(_authorized_arm_id)
	if not bool(finished.get("ok", false)):
		return finished
	var arm: Dictionary = _arms[_authorized_arm_id]
	var facade: RefCounted = arm["facade"]
	var configuration: Dictionary = (
		facade
		. configure_all_motors_v1(
			false,
			completed_global_step + 1,
			"l9_process_isolated_walking_disabled_before_interaction",
		)
	)
	if not bool(configuration.get("ok", false)):
		return configuration
	(arm["motor_configuration_receipts"] as Array).append(configuration.duplicate(true))
	var torso: RigidBody3D = (arm["model"]["body_nodes"] as Dictionary)["torso"]
	arm["pre_interaction_velocity_world_m_s"] = _vector3_array_v1(torso.linear_velocity)
	arm["scheduled_impulse_world_n_s"] = [0.0, 0.0, 0.0]
	_total_native_readback_count += 1
	if _authorized_arm_id == EnergyInitializer.ACTIVE_ARM_ID:
		var prefix: Dictionary = arm["prefix_session_start_receipt"]
		var lateral_axis := _vector3_from_array_v1(
			prefix.get("task_frame_lateral_axis_world_host_real")
		)
		if not lateral_axis.is_finite() or absf(lateral_axis.length() - 1.0) > 2.0e-6:
			return {
				"ok": false,
				"failure_code": "QSDK_R10F_L9_CHILD_INTERACTION_LATERAL_AXIS_INVALID",
			}
		var impulse_world := lateral_axis * EnergyInitializer.KICK_IMPULSE_MAGNITUDE_N_S
		torso.apply_central_impulse(impulse_world)
		arm["external_kick_application_count"] = 1
		arm["scheduled_impulse_world_n_s"] = _vector3_array_v1(impulse_world)
		_external_kick_application_count = 1
	_arms[_authorized_arm_id] = arm
	_interaction_scheduled = true
	return {"ok": true}


func _schedule_interaction_v1(completed_global_step: int) -> Dictionary:
	if _interaction_scheduled or _interaction_completed:
		return {"ok": false, "failure_code": "QSDK_R10F_INTERACTION_ALREADY_SCHEDULED"}
	for arm_id_value in ARM_ORDER:
		var finished := _finish_walking_session_v1(String(arm_id_value))
		if not bool(finished.get("ok", false)):
			return finished
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var arm: Dictionary = _arms[arm_id]
		var facade: RefCounted = arm["facade"]
		var configuration: Dictionary = (
			facade
			. configure_all_motors_v1(
				false,
				completed_global_step + 1,
				"walking_disabled_before_frozen_interaction_event",
			)
		)
		if not bool(configuration.get("ok", false)):
			return configuration
		(arm["motor_configuration_receipts"] as Array).append(configuration.duplicate(true))
		var torso: RigidBody3D = (arm["model"]["body_nodes"] as Dictionary)["torso"]
		arm["pre_interaction_velocity_world_m_s"] = _vector3_array_v1(torso.linear_velocity)
		arm["scheduled_impulse_world_n_s"] = [0.0, 0.0, 0.0]
		_arms[arm_id] = arm
		_total_native_readback_count += 1
	var active: Dictionary = _arms[EnergyInitializer.ACTIVE_ARM_ID]
	var prefix: Dictionary = active["prefix_session_start_receipt"]
	var lateral_axis := _vector3_from_array_v1(
		prefix.get("task_frame_lateral_axis_world_host_real")
	)
	if not lateral_axis.is_finite() or absf(lateral_axis.length() - 1.0) > 2.0e-6:
		return {"ok": false, "failure_code": "QSDK_R10F_INTERACTION_LATERAL_AXIS_INVALID"}
	var impulse_world := lateral_axis * EnergyInitializer.KICK_IMPULSE_MAGNITUDE_N_S
	var active_torso: RigidBody3D = (active["model"]["body_nodes"] as Dictionary)["torso"]
	active_torso.apply_central_impulse(impulse_world)
	active["external_kick_application_count"] = 1
	active["scheduled_impulse_world_n_s"] = _vector3_array_v1(impulse_world)
	_arms[EnergyInitializer.ACTIVE_ARM_ID] = active
	_external_kick_application_count = 1
	_interaction_scheduled = true
	return {"ok": true}


func _global_observation_from_collection_v1(collection_value: Variant) -> Dictionary:
	if not (collection_value is Dictionary):
		return {}
	var collection: Dictionary = collection_value
	var global_value: Variant = collection.get("global_result")
	if not (global_value is Dictionary):
		return {}
	var bound_value: Variant = (global_value as Dictionary).get("bound")
	if not (bound_value is Dictionary):
		return {}
	var observation_value: Variant = (bound_value as Dictionary).get("observation_v3")
	return (
		(observation_value as Dictionary).duplicate(true) if observation_value is Dictionary else {}
	)


func _joint_position_map_v1(observation: Dictionary) -> Dictionary:
	var state_value: Variant = observation.get("state")
	if not (state_value is Dictionary):
		return {}
	var rows_value: Variant = (state_value as Dictionary).get("ordered_joint_observations")
	if not (rows_value is Array):
		return {}
	var positions: Dictionary = {}
	for row_value in rows_value:
		if not (row_value is Dictionary):
			return {}
		var row: Dictionary = row_value
		var joint_id := String(row.get("joint_id", ""))
		var position := float(row.get("position_rad", NAN))
		if joint_id not in LocomotionFacade.JOINT_IDS or not is_finite(position):
			return {}
		positions[joint_id] = position
	return positions if positions.size() == LocomotionFacade.JOINT_IDS.size() else {}


func _arm_epoch_initializer_sha256_v1(arm: Dictionary) -> String:
	var model_value: Variant = arm.get("model")
	if not (model_value is Dictionary):
		return ""
	var initializer_value: Variant = (model_value as Dictionary).get(
		NativeEpochRoute.MODEL_EPOCH_INITIALIZER_KEY
	)
	if not (initializer_value is Dictionary):
		return ""
	return String((initializer_value as Dictionary).get("payload_sha256", ""))


func _terminal_failure_reason_v1(memory_value: Variant) -> String:
	if not (memory_value is Dictionary):
		return ""
	var value: Variant = (memory_value as Dictionary).get("terminal_failure_code")
	return String(value) if value is String and not String(value).is_empty() else ""


static func _joint_geometry_failure_v2(
	failure_code: String,
	joint_id: String,
	failed_fields: Array,
) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10f_compact_joint_geometry_failure_v2",
		"gate_id": GATE_ID,
		"ok": false,
		"failure_code": failure_code,
		"joint_id": joint_id,
		"failed_fields": failed_fields.duplicate(),
		"producer_schema": "sporespore_qsdk_r24d57_godot_recovery_native_world_v1",
		"joint_state_contract": "parent_axis_is_shared_planar_hinge_axis_v1",
		"axis_child_local_required": false,
		"axis_child_local_consumed": false,
		"outcome_derived_correction": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _vector3_dictionary_v1(value: Variant) -> Vector3:
	if not (value is Dictionary):
		return Vector3(NAN, NAN, NAN)
	var source: Dictionary = value
	return Vector3(
		float(source.get("x", NAN)),
		float(source.get("y", NAN)),
		float(source.get("z", NAN)),
	)


## Consume the exact historical recovery-world shape. Anchor separation is
## already source-measured in the completed observation. The recovery body is
## planar: its one retained parent-local hinge axis is the shared local axis in
## both body frames, so a second axis_child_local storage field is neither
## produced nor synthesized from the outcome.
static func _joint_geometry_summary_v2(
	model: Dictionary,
	observation: Dictionary,
) -> Dictionary:
	var blueprint_value: Variant = model.get("blueprint")
	var body_nodes_value: Variant = model.get("body_nodes")
	var joint_nodes_value: Variant = model.get("joint_nodes")
	var states_value: Variant = model.get("joint_states")
	var observation_state_value: Variant = observation.get("state")
	if (
		(
			String(model.get("schema_version", ""))
			!= "sporespore_qsdk_r24d57_godot_recovery_native_world_v1"
		)
		or not (blueprint_value is Dictionary)
		or not (body_nodes_value is Dictionary)
		or not (joint_nodes_value is Dictionary)
		or not (states_value is Dictionary)
		or not (observation_state_value is Dictionary)
	):
		return _joint_geometry_failure_v2(
			"QSDK_R10F_COMPACT_GEOMETRY_MODEL_OR_OBSERVATION_SHAPE_INVALID",
			"",
			[
				"model_schema",
				"blueprint",
				"body_nodes",
				"joint_nodes",
				"joint_states",
				"observation.state"
			],
		)
	var blueprint: Dictionary = blueprint_value
	var body_nodes: Dictionary = body_nodes_value
	var joint_nodes: Dictionary = joint_nodes_value
	var states: Dictionary = states_value
	var observation_state: Dictionary = observation_state_value
	if String(observation_state.get("schema_version", "")) != "sporespore_state_frame_v1":
		return _joint_geometry_failure_v2(
			"QSDK_R10F_COMPACT_GEOMETRY_MODEL_OR_OBSERVATION_SHAPE_INVALID",
			"",
			["observation.state.schema_version"],
		)
	var joint_specs_value: Variant = blueprint.get("joint_by_id")
	var rows_value: Variant = observation_state.get("ordered_joint_observations")
	if not (joint_specs_value is Dictionary) or not (rows_value is Array):
		return _joint_geometry_failure_v2(
			"QSDK_R10F_COMPACT_GEOMETRY_SOURCE_COLLECTION_MISSING",
			"",
			["blueprint.joint_by_id", "observation.state.ordered_joint_observations"],
		)
	var joint_specs: Dictionary = joint_specs_value
	var rows: Array = rows_value
	if (
		body_nodes.size() != LocomotionFacade.BODY_IDS.size()
		or joint_nodes.size() != LocomotionFacade.JOINT_IDS.size()
		or states.size() != LocomotionFacade.JOINT_IDS.size()
		or joint_specs.size() != LocomotionFacade.JOINT_IDS.size()
		or rows.size() != LocomotionFacade.JOINT_IDS.size()
	):
		return _joint_geometry_failure_v2(
			"QSDK_R10F_COMPACT_GEOMETRY_CARDINALITY_INVALID",
			"",
			[
				"body_nodes",
				"joint_nodes",
				"joint_states",
				"joint_by_id",
				"ordered_joint_observations"
			],
		)
	var maximum_anchor_error_m := 0.0
	var maximum_hinge_axis_error_rad := 0.0
	var ordered_joint_geometry: Array = []
	for index in range(LocomotionFacade.JOINT_IDS.size()):
		var joint_id := String(LocomotionFacade.JOINT_IDS[index])
		var state_value: Variant = states.get(joint_id)
		var spec_value: Variant = joint_specs.get(joint_id)
		var row_value: Variant = rows[index]
		if (
			not (state_value is Dictionary)
			or not (spec_value is Dictionary)
			or not (row_value is Dictionary)
		):
			return _joint_geometry_failure_v2(
				"QSDK_R10F_COMPACT_GEOMETRY_JOINT_SOURCE_SHAPE_INVALID",
				joint_id,
				["joint_state", "joint_spec", "ordered_joint_observation"],
			)
		var state: Dictionary = state_value
		var spec: Dictionary = spec_value
		var row: Dictionary = row_value
		var expected_state_keys := [
			"anchor_child_local",
			"anchor_parent_local",
			"axis_parent_local",
			"child",
			"joint",
			"joint_id",
			"parent",
		]
		var observed_state_keys: Array = state.keys()
		observed_state_keys.sort()
		if observed_state_keys != expected_state_keys:
			return _joint_geometry_failure_v2(
				"QSDK_R10F_COMPACT_GEOMETRY_JOINT_STATE_CONTRACT_INVALID",
				joint_id,
				["exact_joint_state_keys", "axis_child_local_absent"],
			)
		var parent_value: Variant = state.get("parent")
		var child_value: Variant = state.get("child")
		var joint_value: Variant = state.get("joint")
		var parent_anchor_value: Variant = state.get("anchor_parent_local")
		var child_anchor_value: Variant = state.get("anchor_child_local")
		var parent_axis_value: Variant = state.get("axis_parent_local")
		if (
			String(state.get("joint_id", "")) != joint_id
			or not (parent_value is RigidBody3D)
			or not (child_value is RigidBody3D)
			or not (joint_value is HingeJoint3D)
			or not (parent_anchor_value is Vector3)
			or not (child_anchor_value is Vector3)
			or not (parent_axis_value is Vector3)
		):
			return _joint_geometry_failure_v2(
				"QSDK_R10F_COMPACT_GEOMETRY_JOINT_BINDING_TYPE_INVALID",
				joint_id,
				["joint_id", "parent", "child", "joint", "anchors", "axis_parent_local"],
			)
		var parent: RigidBody3D = parent_value
		var child: RigidBody3D = child_value
		var joint: HingeJoint3D = joint_value
		var parent_id := String(spec.get("parent_body_id", ""))
		var child_id := String(spec.get("child_body_id", ""))
		if (
			parent_id.is_empty()
			or child_id.is_empty()
			or body_nodes.get(parent_id) != parent
			or body_nodes.get(child_id) != child
			or joint_nodes.get(joint_id) != joint
			or String(parent.get_meta("lab_body_id", "")) != parent_id
			or String(child.get_meta("lab_body_id", "")) != child_id
			or String(joint.get_meta("lab_joint_id", "")) != joint_id
		):
			return _joint_geometry_failure_v2(
				"QSDK_R10F_COMPACT_GEOMETRY_NODE_IDENTITY_INVALID",
				joint_id,
				["parent_body_id", "child_body_id", "body_nodes", "joint_nodes", "node_metadata"],
			)
		var parent_anchor: Vector3 = parent_anchor_value
		var child_anchor: Vector3 = child_anchor_value
		var expected_parent_anchor := _vector3_dictionary_v1(spec.get("anchor_parent_m"))
		var expected_child_anchor := _vector3_dictionary_v1(spec.get("anchor_child_m"))
		if (
			not parent_anchor.is_finite()
			or not child_anchor.is_finite()
			or not expected_parent_anchor.is_finite()
			or not expected_child_anchor.is_finite()
			or parent_anchor != expected_parent_anchor
			or child_anchor != expected_child_anchor
		):
			return _joint_geometry_failure_v2(
				"QSDK_R10F_COMPACT_GEOMETRY_ANCHOR_CONTRACT_INVALID",
				joint_id,
				["anchor_parent_local", "anchor_child_local", "blueprint_anchors"],
			)
		var shared_axis_local: Vector3 = parent_axis_value
		if not shared_axis_local.is_finite() or shared_axis_local != Vector3.BACK:
			return _joint_geometry_failure_v2(
				"QSDK_R10F_COMPACT_GEOMETRY_SHARED_PLANAR_AXIS_INVALID",
				joint_id,
				["axis_parent_local", "shared_planar_axis"],
			)
		var row_joint_id_value: Variant = row.get("joint_id")
		var row_validity_value: Variant = row.get("validity")
		var anchor_error_value: Variant = row.get("anchor_error_m")
		var anchor_validity_value: Variant = (
			(row_validity_value as Dictionary).get("anchor_error")
			if row_validity_value is Dictionary
			else null
		)
		if (
			typeof(row_joint_id_value) != TYPE_STRING
			or String(row_joint_id_value) != joint_id
			or not (row_validity_value is Dictionary)
			or typeof(anchor_validity_value) != TYPE_BOOL
			or not bool(anchor_validity_value)
			or typeof(anchor_error_value) != TYPE_FLOAT
			or not is_finite(float(anchor_error_value))
			or float(anchor_error_value) < 0.0
		):
			return _joint_geometry_failure_v2(
				"QSDK_R10F_COMPACT_GEOMETRY_ANCHOR_MEASUREMENT_INVALID",
				joint_id,
				["ordered_joint_observation.joint_id", "anchor_error_m", "validity.anchor_error"],
			)
		var anchor_error_m := float(anchor_error_value)
		var parent_basis := parent.global_basis if parent.is_inside_tree() else parent.basis
		var child_basis := child.global_basis if child.is_inside_tree() else child.basis
		if (
			not parent_basis.x.is_finite()
			or not parent_basis.y.is_finite()
			or not parent_basis.z.is_finite()
			or not child_basis.x.is_finite()
			or not child_basis.y.is_finite()
			or not child_basis.z.is_finite()
		):
			return _joint_geometry_failure_v2(
				"QSDK_R10F_COMPACT_GEOMETRY_BODY_BASIS_NONFINITE",
				joint_id,
				["parent.global_basis", "child.global_basis"],
			)
		var parent_axis := parent_basis * shared_axis_local
		var child_axis := child_basis * shared_axis_local
		if (
			not parent_axis.is_finite()
			or not child_axis.is_finite()
			or parent_axis.length_squared() <= 1.0e-18
			or child_axis.length_squared() <= 1.0e-18
		):
			return _joint_geometry_failure_v2(
				"QSDK_R10F_COMPACT_GEOMETRY_WORLD_AXIS_INVALID",
				joint_id,
				["parent_axis_world", "child_axis_world"],
			)
		parent_axis = parent_axis.normalized()
		child_axis = child_axis.normalized()
		var axis_error_rad := acos(clampf(absf(parent_axis.dot(child_axis)), 0.0, 1.0))
		if not is_finite(axis_error_rad):
			return _joint_geometry_failure_v2(
				"QSDK_R10F_COMPACT_GEOMETRY_AXIS_MEASUREMENT_NONFINITE",
				joint_id,
				["hinge_axis_error_rad"],
			)
		maximum_anchor_error_m = maxf(maximum_anchor_error_m, anchor_error_m)
		maximum_hinge_axis_error_rad = maxf(maximum_hinge_axis_error_rad, axis_error_rad)
		(
			ordered_joint_geometry
			. append(
				{
					"joint_id": joint_id,
					"anchor_error_m": anchor_error_m,
					"hinge_axis_error_rad": axis_error_rad,
					"anchor_error_source": "observation_v3.state.ordered_joint_observations",
					"hinge_axis_source": "shared_planar_axis_and_live_body_bases",
				}
			)
		)
	return {
		"schema_version": "sporespore_qsdk_r10f_compact_joint_geometry_summary_v2",
		"gate_id": GATE_ID,
		"ok": true,
		"joint_count": ordered_joint_geometry.size(),
		"ordered_joint_geometry": ordered_joint_geometry,
		"maximum_anchor_error_m": maximum_anchor_error_m,
		"maximum_hinge_axis_error_rad": maximum_hinge_axis_error_rad,
		"anchor_error_source": "observation_v3.state.ordered_joint_observations.anchor_error_m",
		"hinge_axis_source": "recovery_joint_state.axis_parent_local_shared_in_both_body_frames",
		"joint_state_contract": "parent_axis_is_shared_planar_hinge_axis_v1",
		"axis_child_local_required": false,
		"axis_child_local_consumed": false,
		"source_measurement": true,
		"outcome_derived_correction": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


func _contact_map_v1(observation: Dictionary) -> Dictionary:
	var state_value: Variant = observation.get("state")
	if not (state_value is Dictionary):
		return {}
	var rows_value: Variant = (state_value as Dictionary).get("ordered_contact_observations")
	if not (rows_value is Array):
		return {}
	var result: Dictionary = {}
	for row_value in rows_value:
		if not (row_value is Dictionary):
			return {}
		var row: Dictionary = row_value
		var contact_site_id := String(row.get("contact_site_id", ""))
		if not contact_site_id.ends_with("_foot"):
			return {}
		var limb_id := contact_site_id.trim_suffix("_foot")
		if (
			limb_id not in WalkingEvaluator.LIMB_ORDER
			or typeof(row.get("bears_support")) != TYPE_BOOL
		):
			return {}
		result[limb_id] = bool(row["bears_support"])
	return result if result.size() == WalkingEvaluator.LIMB_ORDER.size() else {}


func _foot_position_map_v1(model: Dictionary) -> Dictionary:
	var nodes_value: Variant = model.get("body_nodes")
	if not (nodes_value is Dictionary):
		return {}
	var nodes: Dictionary = nodes_value
	var result: Dictionary = {}
	for limb_id_value in WalkingEvaluator.LIMB_ORDER:
		var limb_id := String(limb_id_value)
		var body_value: Variant = nodes.get("%s_distal" % limb_id)
		if not (body_value is RigidBody3D):
			return {}
		var body: RigidBody3D = body_value
		if not body.global_position.is_finite():
			return {}
		result[limb_id] = _vector3_array_v1(body.global_position)
	return result


func _torso_contact_v1(observation: Dictionary) -> bool:
	var rows_value: Variant = observation.get("ordered_body_clearance_observations")
	if not (rows_value is Array):
		return true
	for row_value in rows_value:
		if (
			row_value is Dictionary
			and String((row_value as Dictionary).get("body_id", "")) == "torso"
		):
			return bool((row_value as Dictionary).get("nonfoot_contact_present", true))
	return true


func _native_engine_health_valid_v1(receipt: Dictionary, semantic_step: int) -> bool:
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
	for index in range(rows.size()):
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


func _vector_dictionary_array_v1(value: Variant) -> Array:
	if not (value is Dictionary):
		return []
	var source: Dictionary = value
	var vector := Vector3(
		float(source.get("x", NAN)),
		float(source.get("y", NAN)),
		float(source.get("z", NAN)),
	)
	return _vector3_array_v1(vector) if vector.is_finite() else []


func _vector3_from_array_v1(value: Variant) -> Vector3:
	if not (value is Array) or (value as Array).size() != 3:
		return Vector3(NAN, NAN, NAN)
	var source: Array = value
	return Vector3(float(source[0]), float(source[1]), float(source[2]))


func _vector3_array_v1(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _canonical_sha256_v1(value: Variant) -> String:
	if _sdk == null:
		return ""
	return String(RecoveryRuntimeScript.canonicalize(_sdk, value).get("sha256", ""))


func _valid_sha256(value: String) -> bool:
	return (
		value.length() == 71
		and value.begins_with("sha256:")
		and value.substr(7).is_valid_hex_number(false)
	)


func _precondition_pair_final_state_valid_v1() -> bool:
	if (
		_precondition_pair_state.is_empty()
		or not PreconditionPairBarrier.state_valid_v1(_sdk, _precondition_pair_state)
		or not bool(_precondition_pair_state.get("released", false))
		or typeof(_precondition_pair_state.get("release_planned_global_step")) != TYPE_INT
		or typeof(_precondition_pair_state.get("release_completed_global_step")) != TYPE_INT
		or (
			int(_precondition_pair_state.get("release_planned_global_step", -1))
			!= int(_precondition_pair_state.get("release_completed_global_step", -2))
		)
	):
		return false
	var ready_value: Variant = _precondition_pair_state.get("ready_by_arm")
	var source_value: Variant = _precondition_pair_state.get("terminal_source_by_arm")
	var source_sha_value: Variant = _precondition_pair_state.get("terminal_source_sha256_by_arm")
	var source_step_value: Variant = _precondition_pair_state.get("terminal_global_step_by_arm")
	if (
		not (ready_value is Dictionary)
		or not (source_value is Dictionary)
		or not (source_sha_value is Dictionary)
		or not (source_step_value is Dictionary)
	):
		return false
	var ready: Dictionary = ready_value
	var sources: Dictionary = source_value
	var source_shas: Dictionary = source_sha_value
	var source_steps: Dictionary = source_step_value
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		if (
			not bool(ready.get(arm_id, false))
			or not (sources.get(arm_id) is Dictionary)
			or typeof(source_steps.get(arm_id)) != TYPE_INT
			or not (
				PreconditionPairBarrier
				. terminal_source_valid_v1(
					_sdk,
					sources[arm_id],
					_precondition_pair_state,
					arm_id,
					int(source_steps[arm_id]),
				)
			)
			or (
				String(source_shas.get(arm_id, ""))
				!= String((sources[arm_id] as Dictionary).get("payload_sha256", ""))
			)
		):
			return false
	return true


func _precondition_pair_evidence_by_arm_v1() -> Dictionary:
	var evidence := {}
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var terminal_source: Dictionary = {}
		var applications: Array = []
		if _arms.has(arm_id) and _arms[arm_id] is Dictionary:
			var arm: Dictionary = _arms[arm_id]
			var terminal_value: Variant = arm.get("precondition_terminal_source")
			var applications_value: Variant = arm.get(
				"precondition_pair_barrier_application_projections"
			)
			if terminal_value is Dictionary:
				terminal_source = (terminal_value as Dictionary).duplicate(true)
			if applications_value is Array:
				applications = (applications_value as Array).duplicate(true)
		evidence[arm_id] = {
			"precondition_terminal_source": terminal_source,
			"precondition_terminal_source_sha256":
			String(terminal_source.get("payload_sha256", "")),
			"precondition_pair_barrier_application_projections": applications,
			"precondition_pair_barrier_application_projection_count": applications.size(),
		}
	return evidence


func _precondition_terminal_disposition_population_valid_v1() -> bool:
	if (
		_sdk == null
		or not PreconditionPairBarrier.state_valid_v1(
			_sdk, _precondition_terminal_disposition_pair_state
		)
		or bool(_precondition_terminal_disposition_pair_state.get("released", false))
		or _precondition_terminal_disposition_by_arm.size() != ARM_ORDER.size()
	):
		return false
	var global_step := int(
		_precondition_terminal_disposition_pair_state.get("last_completed_global_semantic_step", -1)
	)
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var disposition_value: Variant = _precondition_terminal_disposition_by_arm.get(arm_id)
		if (
			not (disposition_value is Dictionary)
			or not (
				PreconditionTerminalDisposition
				. disposition_valid_v1(
					_sdk,
					disposition_value,
					_precondition_terminal_disposition_pair_state,
					arm_id,
					global_step,
				)
			)
		):
			return false
	return true


func _precondition_terminal_disposition_sha256_by_arm_v1() -> Dictionary:
	var digests := {}
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var disposition_value: Variant = _precondition_terminal_disposition_by_arm.get(arm_id)
		digests[arm_id] = (
			String((disposition_value as Dictionary).get("payload_sha256", ""))
			if disposition_value is Dictionary
			else ""
		)
	return digests


func _finalize_process_isolated_child_result_v1() -> void:
	if _finalizing or _exit_scheduled:
		return
	_finalizing = true
	_quiesce_process_isolated_child_v1()
	var walking_close := _finish_walking_session_v1(_authorized_arm_id)
	if not bool(walking_close.get("ok", false)):
		_abort("QSDK_R10F_L9_CHILD_WALKING_CLOSE_INVALID", walking_close)
		return
	var arm: Dictionary = _arms[_authorized_arm_id]
	var facade: RefCounted = arm["facade"]
	var terminal_identity: Dictionary = facade.same_body_identity_receipt_v1(
		_sdk, _observed_global_solver_frames, "l9_process_isolated_child_terminal_boundary"
	)
	if (
		not bool(terminal_identity.get("ok", false))
		or (
			String(terminal_identity.get("body_population_instance_sha256", ""))
			!= String(arm["body_population_instance_sha256"])
		)
	):
		_abort("QSDK_R10F_L9_CHILD_TERMINAL_IDENTITY_INVALID", terminal_identity)
		return
	arm["terminal_same_body_identity_receipt"] = terminal_identity.duplicate(true)
	_arms[_authorized_arm_id] = arm
	var projected := _process_isolated_arm_result_projection_v1(_authorized_arm_id)
	if not bool(projected.get("ok", false)):
		_abort("QSDK_R10F_L9_CHILD_RESULT_PROJECTION_INVALID", projected)
		return
	var disposition := String(
		_process_isolated_precondition_terminal_receipt.get("disposition", "")
	)
	var final_state: Dictionary = projected["final_orchestrator_state"]
	var reached_interaction := not _process_isolated_interaction_source.is_empty()
	var role_outcome := ""
	if (
		disposition
		in [
			ProcessIsolatedChildContract.DISPOSITION_FAILED,
			ProcessIsolatedChildContract.DISPOSITION_REFUSED,
		]
	):
		role_outcome = "precondition_negative"
	elif _authorized_arm_id == EnergyInitializer.BASELINE_ARM_ID:
		role_outcome = "matched_reference_complete"
	elif String(final_state.get("phase", "")) == Orchestrator.PHASE_COMPLETE:
		role_outcome = "behavior_positive"
	else:
		role_outcome = "behavior_negative"
	if (
		_total_model_construction_attempt_count != 1
		or _total_model_construction_count != 1
		or _total_world_attempt_count != 1
		or _total_world_build_count != 1
		or _total_solver_step_count != _observed_global_solver_frames
		or _total_solver_step_count <= 0
		or _total_solver_step_count > MAXIMUM_CHILD_SOLVER_STEPS
		or int(projected.get("in_run_invariant_receipt_count", -1)) != _total_solver_step_count
		or not bool(projected.get("all_in_run_physical_invariants_passed", false))
		or not bool(projected.get("same_body_identity_preserved", false))
	):
		_abort(
			"QSDK_R10F_L9_CHILD_TERMINAL_POPULATION_INVARIANT_INVALID",
			{
				"model_construction_count": _total_model_construction_count,
				"world_build_count": _total_world_build_count,
				"solver_step_count": _total_solver_step_count,
				"global_solver_frames": _observed_global_solver_frames,
			},
		)
		return
	var report := {
		"schema_version": _raw_schema,
		"gate_id": GATE_ID,
		"repair_id": _repair_id,
		"work_id": _work_id,
		"ledger_prefix": "[recovery/godot]",
		"question_class": "development",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "consumed_process_isolated_child_physical_development_raw",
			"question_class": "development",
		},
		"status": "valid_complete_process_isolated_child_development",
		"ok": true,
		"measurement_complete": true,
		"scientific_outcome": "none",
		"role_outcome": role_outcome,
		"source_commit": _source_commit,
		"authorization_sha256": _authorization_sha256,
		"parent_attempt_id": _parent_attempt_id,
		"child_attempt_id": _attempt_id,
		"attempt_id": _attempt_id,
		"arm_id": _authorized_arm_id,
		"process_id": OS.get_process_id(),
		"cell_id": "r10f_godot_l9_process_isolated_%s" % _authorized_arm_id,
		"seed": _seed,
		"seed_label": _seed_label,
		"seed_sha256": _seed_sha256,
		"actuator_mode": ACTUATOR_MODE,
		"recovery_controller_id": RECOVERY_CONTROLLER_ID,
		"energy_route_id": ENERGY_ROUTE_ID,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"outer_step_duration_s": 1.0 / float(PHYSICS_HZ),
		"held_out": false,
		"held_out_cell_access_count": 0,
		"population_inference_claimed": false,
		"one_arm_per_process": _arms.size() == 1,
		"one_world_per_process": _total_world_build_count == 1,
		"world_or_body_state_imported_from_peer": false,
		"configuration": _configuration.duplicate(true),
		"configuration_sha256": _configuration_sha256,
		"precondition_terminal_receipt":
		_process_isolated_precondition_terminal_receipt.duplicate(true),
		"precondition_terminal_receipt_sha256":
		String(_process_isolated_precondition_terminal_receipt.get("payload_sha256", "")),
		"precondition_release_receipt":
		_process_isolated_precondition_release_receipt.duplicate(true),
		"precondition_release_receipt_sha256":
		String(_process_isolated_precondition_release_receipt.get("payload_sha256", "")),
		"interaction_source": _process_isolated_interaction_source.duplicate(true),
		"interaction_source_sha256":
		String(_process_isolated_interaction_source.get("payload_sha256", "")),
		"arm_result": projected,
		"reached_walking_prefix": int(final_state.get("walking_prefix_step_count", 0)) > 0,
		"reached_interaction": reached_interaction,
		"reached_post_kick_recovery": int(final_state.get("post_kick_recovery_step_count", 0)) > 0,
		"reached_walking_resume": int(final_state.get("walking_resume_step_count", 0)) > 0,
		"behavior_evaluator_invocation_count": 0,
		"complete_trace_count": 1,
		"in_run_invariant_receipt_count": int(projected["in_run_invariant_receipt_count"]),
		"all_in_run_physical_invariants_passed": true,
		"same_body_identity_preserved": true,
		"model_construction_attempt_count": _total_model_construction_attempt_count,
		"model_construction_count": _total_model_construction_count,
		"world_attempt_count": _total_world_attempt_count,
		"world_build_count": _total_world_build_count,
		"solver_step_count": _total_solver_step_count,
		"maximum_solver_step_count": MAXIMUM_CHILD_SOLVER_STEPS,
		"global_solver_frame_count": _observed_global_solver_frames,
		"external_kick_application_count": _external_kick_application_count,
		"explicit_worker_extra_native_readback_count": _total_native_readback_count,
		"physical_question_opened": true,
		"physics_state_modified": true,
		"event_triggered_passive_recovery_observed": role_outcome == "behavior_positive",
		"recovery_success_observed": role_outcome == "behavior_positive",
		"prone_to_standing_claimed": false,
		"kick_impulse_alone_causes_fall_claimed": false,
		"force_aware_recovery": false,
		"force_aware_bracing": false,
		"arbitrary_fall_recovery_claimed": false,
		"cross_engine_push_recovery_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if _repair_id == "QSDK-R10F-L15":
		report["l15_prepared_context_comparison"] = _json_safe_v1(
			(
				get_meta("l15_prepared_context_comparison")
				if has_meta("l15_prepared_context_comparison")
				else null
			)
		)
	_cleanup_worlds_v1()
	print(_raw_marker, JsonTransportScript.stringify(report))
	_schedule_exit_v1(0, "valid_complete_process_isolated_child_development")


func _process_isolated_arm_result_projection_v1(arm_id: String) -> Dictionary:
	if arm_id != _authorized_arm_id or _arms.size() != 1:
		return {"ok": false, "failure_code": "QSDK_R10F_L9_CHILD_RESULT_ARM_INVALID"}
	var arm: Dictionary = _arms[arm_id]
	var rows: Array = arm["trace_rows"]
	var invariants: Array = arm["invariant_receipts"]
	var state: Dictionary = arm["orchestrator_state"]
	var model: Dictionary = arm["model"]
	var terminal := _process_isolated_precondition_terminal_receipt
	if not ProcessIsolatedChildContract.precondition_terminal_receipt_valid_v1(_sdk, terminal):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L9_CHILD_PRECONDITION_TERMINAL_INVALID",
		}
	var complete_precondition := (
		String(terminal.get("disposition", "")) == ProcessIsolatedChildContract.DISPOSITION_COMPLETE
	)
	var release_boundary_valid := (
		ProcessIsolatedChildContract.precondition_release_receipt_valid_v1(
			_sdk, _process_isolated_precondition_release_receipt
		)
		if complete_precondition
		else _process_isolated_precondition_release_receipt.is_empty()
	)
	var release_receipt_valid := complete_precondition and release_boundary_valid
	var interaction_valid := true
	if not _process_isolated_interaction_source.is_empty():
		interaction_valid = ProcessIsolatedChildContract.interaction_source_valid_v1(
			_sdk, _process_isolated_interaction_source
		)
		interaction_valid = (
			interaction_valid
			and EnergyInitializer.interaction_receipt_valid_v1(_sdk, arm["interaction_receipt"])
			and (
				String(
					(arm["interaction_receipt"] as Dictionary).get(
						"interaction_source_receipt_sha256", ""
					)
				)
				== String(_process_isolated_interaction_source.get("payload_sha256", ""))
			)
		)
	var all_invariants := true
	for invariant_value in invariants:
		all_invariants = (
			all_invariants
			and invariant_value is Dictionary
			and bool(
				(invariant_value as Dictionary).get("all_in_run_physical_invariants_passed", false)
			)
		)
	var initial_identity: Dictionary = arm["initial_same_body_identity_receipt"]
	var final_identity: Dictionary = arm["terminal_same_body_identity_receipt"]
	var identity_preserved := (
		(
			String(initial_identity.get("body_population_instance_sha256", ""))
			== String(arm["body_population_instance_sha256"])
		)
		and (
			String(final_identity.get("body_population_instance_sha256", ""))
			== String(arm["body_population_instance_sha256"])
		)
	)
	var trace := {
		"schema_version": TRACE_SCHEMA,
		"gate_id": GATE_ID,
		"repair_id": _repair_id,
		"parent_attempt_id": _parent_attempt_id,
		"child_attempt_id": _attempt_id,
		"arm_id": arm_id,
		"model_instance_id": String(arm["model_instance_id"]),
		"body_population_instance_sha256": String(arm["body_population_instance_sha256"]),
		"rows": rows.duplicate(true),
	}
	var trace_sha := _canonical_sha256_v1(trace)
	var final_phase := String(state.get("phase", ""))
	var precondition_negative := (
		String(terminal.get("disposition", ""))
		in [
			ProcessIsolatedChildContract.DISPOSITION_FAILED,
			ProcessIsolatedChildContract.DISPOSITION_REFUSED,
		]
	)
	if (
		not _valid_sha256(trace_sha)
		or rows.is_empty()
		or rows.size() != invariants.size()
		or rows.size() != int(state.get("total_completed_solver_step_count", -1))
		or int(model.get("solver_step_count", -1)) != rows.size()
		or not bool(arm["terminal"])
		or not bool((arm["initial_application_validation_receipt"] as Dictionary).get("ok", false))
		or not Orchestrator.state_valid_v1(_sdk, state)
		or not all_invariants
		or not identity_preserved
		or not release_boundary_valid
		or not interaction_valid
		or (
			complete_precondition
			and int(state.get("precondition_pair_release_step_count", -1)) != 1
		)
		or (complete_precondition and int(state.get("precondition_pair_wait_step_count", -1)) != 0)
		or (complete_precondition and not bool(state.get("precondition_pair_ready", false)))
		or (precondition_negative and final_phase != Orchestrator.PHASE_FAILED)
		or (precondition_negative and not _process_isolated_interaction_source.is_empty())
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L9_CHILD_TERMINAL_INVARIANT_INVALID",
			"arm_id": arm_id,
		}
	return {
		"schema_version": "sporespore_qsdk_r10f_l9_process_isolated_arm_result_v1",
		"gate_id": GATE_ID,
		"repair_id": _repair_id,
		"ok": true,
		"parent_attempt_id": _parent_attempt_id,
		"child_attempt_id": _attempt_id,
		"arm_id": arm_id,
		"model_instance_id": String(arm["model_instance_id"]),
		"body_population_instance_sha256": String(arm["body_population_instance_sha256"]),
		"initial_same_body_identity_receipt": initial_identity.duplicate(true),
		"terminal_same_body_identity_receipt": final_identity.duplicate(true),
		"same_body_identity_preserved": identity_preserved,
		"initial_application_validation_receipt":
		(arm["initial_application_validation_receipt"] as Dictionary).duplicate(true),
		"initial_recovery_initialization_receipt":
		(arm["recovery_initialization_receipt"] as Dictionary).duplicate(true),
		"postkick_recovery_initialization_receipt":
		(arm["postkick_recovery_initialization_receipt"] as Dictionary).duplicate(true),
		"precondition_terminal_receipt": terminal.duplicate(true),
		"precondition_terminal_receipt_sha256": String(terminal["payload_sha256"]),
		"precondition_release_receipt":
		_process_isolated_precondition_release_receipt.duplicate(true),
		"precondition_release_receipt_sha256":
		String(_process_isolated_precondition_release_receipt.get("payload_sha256", "")),
		"precondition_release_receipt_valid": release_receipt_valid,
		"recovery_step_receipts": (arm["recovery_step_receipts"] as Array).duplicate(true),
		"recovery_development_progression_receipts":
		(arm["recovery_development_progression_receipts"] as Array).duplicate(true),
		"walking_sessions": (arm["walking_sessions"] as Array).duplicate(true),
		"walking_actuation_handoff_receipts":
		(arm["walking_actuation_handoff_receipts"] as Array).duplicate(true),
		"interaction_source": _process_isolated_interaction_source.duplicate(true),
		"interaction_receipt": (arm["interaction_receipt"] as Dictionary).duplicate(true),
		"motor_configuration_receipts":
		(arm["motor_configuration_receipts"] as Array).duplicate(true),
		"trace": trace,
		"trace_sha256": trace_sha,
		"outer_step_count": rows.size(),
		"native_solver_step_count": int(model["solver_step_count"]),
		"in_run_invariant_receipts": invariants.duplicate(true),
		"in_run_invariant_receipt_count": invariants.size(),
		"all_in_run_physical_invariants_passed": all_invariants,
		"final_recovery_memory": (arm["recovery_memory"] as Dictionary).duplicate(true),
		"final_orchestrator_state": state.duplicate(true),
		"terminal_orchestrator_transition":
		(arm.get("terminal_orchestrator_transition", {}) as Dictionary).duplicate(true),
		"terminal_recovery_observation_sources":
		(arm.get("terminal_recovery_observation_sources", {}) as Dictionary).duplicate(true),
		"final_phase": final_phase,
		"terminal_reason": String(state.get("terminal_reason", "")),
		"external_kick_application_count": int(arm["external_kick_application_count"]),
		"body_population_rebuild_count": int(arm["body_population_rebuild_count"]),
		"body_transform_write_count": int(arm["body_transform_write_count"]),
		"body_velocity_write_count": int(arm["body_velocity_write_count"]),
		"solver_reset_count": int(arm["solver_reset_count"]),
		"global_step_values_rewritten_for_pair_alignment": false,
		"full_trace_retained": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


func _finalize_valid_result_v1() -> void:
	if _finalizing or _exit_scheduled:
		return
	_finalizing = true
	PhysicsServer3D.set_active(false)
	if physics_frame.is_connected(_on_physics_frame):
		physics_frame.disconnect(_on_physics_frame)
	if not _precondition_pair_final_state_valid_v1():
		_abort(
			"QSDK_R10F_L6_PRECONDITION_PAIR_TERMINAL_STATE_INVALID",
			{"precondition_pair_state": _json_safe_v1(_precondition_pair_state)},
		)
		return
	if not _precondition_terminal_disposition_population_valid_v1():
		_abort(
			"QSDK_R10F_L7_PRECONDITION_DISPOSITION_TERMINAL_STATE_INVALID",
			{
				"precondition_terminal_disposition_by_arm":
				_precondition_terminal_disposition_by_arm.duplicate(true),
				"precondition_terminal_disposition_pair_state":
				_precondition_terminal_disposition_pair_state.duplicate(true),
			},
		)
		return
	var arm_results: Dictionary = {}
	var complete_trace_count := 0
	var invariant_count := 0
	var all_invariants_passed := true
	var all_same_body_identities_passed := true
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var arm: Dictionary = _arms[arm_id]
		var facade: RefCounted = arm["facade"]
		var terminal_identity: Dictionary = (
			facade
			. same_body_identity_receipt_v1(
				_sdk,
				_observed_global_solver_frames,
				"terminal_result_boundary",
			)
		)
		if (
			not bool(terminal_identity.get("ok", false))
			or (
				String(terminal_identity.get("body_population_instance_sha256", ""))
				!= String(arm["body_population_instance_sha256"])
			)
		):
			_abort("QSDK_R10F_TERMINAL_SAME_BODY_IDENTITY_INVALID", terminal_identity)
			return
		arm["terminal_same_body_identity_receipt"] = terminal_identity.duplicate(true)
		_arms[arm_id] = arm
		var projected := _arm_result_projection_v1(arm_id)
		if not bool(projected.get("ok", false)):
			_abort("QSDK_R10F_ARM_RESULT_PROJECTION_INVALID:%s" % arm_id, projected)
			return
		arm_results[arm_id] = projected
		complete_trace_count += 1
		invariant_count += int(projected["in_run_invariant_receipt_count"])
		all_invariants_passed = (
			all_invariants_passed and bool(projected["all_in_run_physical_invariants_passed"])
		)
		all_same_body_identities_passed = (
			all_same_body_identities_passed and bool(projected["same_body_identity_preserved"])
		)
	if (
		complete_trace_count != 2
		or invariant_count != _total_solver_step_count
		or _total_solver_step_count != _observed_global_solver_frames * 2
		or _total_solver_step_count > MAXIMUM_TOTAL_SOLVER_STEPS
		or _total_model_construction_attempt_count != 2
		or _total_model_construction_count != 2
		or _total_world_attempt_count != 2
		or _total_world_build_count != 2
		or not all_invariants_passed
		or not all_same_body_identities_passed
	):
		_abort(
			"QSDK_R10F_TERMINAL_POPULATION_INVARIANT_INVALID",
			{
				"complete_trace_count": complete_trace_count,
				"invariant_count": invariant_count,
				"solver_step_count": _total_solver_step_count,
				"global_solver_frames": _observed_global_solver_frames,
			},
		)
		return
	var evaluation := _evaluate_route_result_v1(arm_results)
	if not bool(evaluation.get("ok", false)):
		_abort("QSDK_R10F_ROUTE_EVALUATION_INVALID", evaluation)
		return
	var behavior_passed := bool(evaluation["behavior_passed"])
	var report := {
		"schema_version": _raw_schema,
		"gate_id": GATE_ID,
		"work_id": _work_id,
		"ledger_prefix": "[recovery/godot]",
		"question_class": "development",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "consumed_physical_development_raw",
			"question_class": "development",
		},
		"status": "valid_complete_behavior_development",
		"ok": true,
		"scientific_outcome": "positive" if behavior_passed else "negative",
		"source_commit": _source_commit,
		"attempt_id": _attempt_id,
		"authorization_sha256": _authorization_sha256,
		"cell_id": "r10f_godot_development_continuous_passive_recovery",
		"seed": _seed,
		"seed_label": _seed_label,
		"seed_sha256": _seed_sha256,
		"actuator_mode": ACTUATOR_MODE,
		"recovery_controller_id": RECOVERY_CONTROLLER_ID,
		"energy_route_id": ENERGY_ROUTE_ID,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"outer_step_duration_s": 1.0 / float(PHYSICS_HZ),
		"held_out": false,
		"held_out_cell_access_count": 0,
		"population_inference_claimed": false,
		"recovery_success_required_for_valid_result": false,
		"physics_failure_is_valid_evidence": true,
		"configuration": _configuration.duplicate(true),
		"configuration_sha256": _configuration_sha256,
		"lockstep_plan": _lockstep_plan.duplicate(true),
		"precondition_pair_barrier_state": _precondition_pair_state.duplicate(true),
		"precondition_pair_barrier_state_sha256":
		String(_precondition_pair_state.get("payload_sha256", "")),
		"precondition_pair_barrier_state_valid": true,
		"precondition_pair_barrier_released": true,
		"precondition_pair_barrier_evidence_by_arm": _precondition_pair_evidence_by_arm_v1(),
		"precondition_terminal_disposition_by_arm":
		_precondition_terminal_disposition_by_arm.duplicate(true),
		"precondition_terminal_disposition_sha256_by_arm":
		_precondition_terminal_disposition_sha256_by_arm_v1(),
		"precondition_terminal_disposition_pair_state":
		_precondition_terminal_disposition_pair_state.duplicate(true),
		"precondition_terminal_disposition_pair_state_sha256":
		String(_precondition_terminal_disposition_pair_state.get("payload_sha256", "")),
		"precondition_terminal_disposition_population_valid": true,
		"interaction_pair_source": _interaction_pair_source.duplicate(true),
		"interaction_pair_receipt": _interaction_pair_receipt.duplicate(true),
		"arm_results": arm_results,
		"route_evaluation": evaluation,
		"behavior_evaluator_invocation_count": 1,
		"complete_trace_count": complete_trace_count,
		"in_run_invariant_receipt_count": invariant_count,
		"all_in_run_physical_invariants_passed": all_invariants_passed,
		"same_body_identity_preserved": all_same_body_identities_passed,
		"model_construction_attempt_count": _total_model_construction_attempt_count,
		"model_construction_count": _total_model_construction_count,
		"world_attempt_count": _total_world_attempt_count,
		"world_build_count": _total_world_build_count,
		"solver_step_count": _total_solver_step_count,
		"maximum_solver_step_count": MAXIMUM_TOTAL_SOLVER_STEPS,
		"global_lockstep_solver_frame_count": _observed_global_solver_frames,
		"external_kick_application_count": _external_kick_application_count,
		"explicit_worker_extra_native_readback_count": _total_native_readback_count,
		"physical_question_opened": true,
		"physics_state_modified": true,
		"event_triggered_passive_recovery_observed": behavior_passed,
		"recovery_success_observed": behavior_passed,
		"prone_to_standing_claimed": behavior_passed,
		"kick_impulse_alone_causes_fall_claimed": false,
		"force_aware_recovery": false,
		"force_aware_bracing": false,
		"arbitrary_fall_recovery_claimed": false,
		"cross_engine_push_recovery_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	_cleanup_worlds_v1()
	print(_raw_marker, JsonTransportScript.stringify(report))
	_schedule_exit_v1(0, "valid_complete_behavior_development")


func _arm_result_projection_v1(arm_id: String) -> Dictionary:
	var arm: Dictionary = _arms[arm_id]
	var rows: Array = arm["trace_rows"]
	var invariants: Array = arm["invariant_receipts"]
	var state: Dictionary = arm["orchestrator_state"]
	var model: Dictionary = arm["model"]
	var initial_application_validation: Dictionary = arm["initial_application_validation_receipt"]
	var terminal_source_value: Variant = arm.get("precondition_terminal_source")
	var pair_applications_value: Variant = arm.get(
		"precondition_pair_barrier_application_projections"
	)
	var terminal_source: Dictionary = (
		(terminal_source_value as Dictionary).duplicate(true)
		if terminal_source_value is Dictionary
		else {}
	)
	var pair_applications: Array = (
		(pair_applications_value as Array).duplicate(true)
		if pair_applications_value is Array
		else []
	)
	var trace := {
		"schema_version": TRACE_SCHEMA,
		"gate_id": GATE_ID,
		"arm_id": arm_id,
		"model_instance_id": String(arm["model_instance_id"]),
		"body_population_instance_sha256": String(arm["body_population_instance_sha256"]),
		"rows": rows.duplicate(true),
	}
	var trace_sha := _canonical_sha256_v1(trace)
	var all_invariants := true
	for invariant_value in invariants:
		all_invariants = (
			all_invariants
			and invariant_value is Dictionary
			and bool(
				(invariant_value as Dictionary).get("all_in_run_physical_invariants_passed", false)
			)
		)
	var identity_preserved := (
		(
			String(
				(arm["initial_same_body_identity_receipt"] as Dictionary).get(
					"body_population_instance_sha256", ""
				)
			)
			== String(arm["body_population_instance_sha256"])
		)
		and (
			String(
				(arm["terminal_same_body_identity_receipt"] as Dictionary).get(
					"body_population_instance_sha256", ""
				)
			)
			== String(arm["body_population_instance_sha256"])
		)
	)
	var terminal_source_sha := String(terminal_source.get("payload_sha256", ""))
	var terminal_source_step := int(terminal_source.get("global_semantic_step", -1))
	var pair_state_source_value: Variant = (
		(_precondition_pair_state.get("terminal_source_by_arm", {}) as Dictionary).get(arm_id)
	)
	var pair_state_source_sha := String(
		(_precondition_pair_state.get("terminal_source_sha256_by_arm", {}) as Dictionary).get(
			arm_id, ""
		)
	)
	var pair_state_source_step_value: Variant = (
		(_precondition_pair_state.get("terminal_global_step_by_arm", {}) as Dictionary).get(arm_id)
	)
	var pair_wait_count_value: Variant = (
		(_precondition_pair_state.get("completed_wait_step_count_by_arm", {}) as Dictionary)
		. get(arm_id)
	)
	var pair_applications_valid := not pair_applications.is_empty()
	var pair_wait_application_count := 0
	var pair_release_application_count := 0
	var previous_pair_application_step := 0
	for application_value in pair_applications:
		if not (application_value is Dictionary):
			pair_applications_valid = false
			continue
		var pair_application: Dictionary = application_value
		var application_step := int(pair_application.get("global_semantic_step", -1))
		var application_action := String(pair_application.get("action_kind", ""))
		if (
			not precondition_pair_barrier_application_retained_valid_v1(_sdk, pair_application)
			or String(pair_application.get("attempt_id", "")) != _attempt_id
			or String(pair_application.get("arm_id", "")) != arm_id
			or (
				String(pair_application.get("model_instance_id", ""))
				!= String(arm["model_instance_id"])
			)
			or String(pair_application.get("terminal_source_sha256", "")) != terminal_source_sha
			or application_step <= previous_pair_application_step
			or application_step <= terminal_source_step
		):
			pair_applications_valid = false
		previous_pair_application_step = application_step
		if application_action == PreconditionPairBarrier.ACTION_WAIT:
			pair_wait_application_count += 1
			if (
				typeof(_precondition_pair_state.get("release_completed_global_step")) != TYPE_INT
				or (
					application_step
					>= int(_precondition_pair_state.get("release_completed_global_step", -1))
				)
			):
				pair_applications_valid = false
		elif application_action == PreconditionPairBarrier.ACTION_RELEASE:
			pair_release_application_count += 1
			if (
				typeof(_precondition_pair_state.get("release_completed_global_step")) != TYPE_INT
				or (
					application_step
					!= int(_precondition_pair_state.get("release_completed_global_step", -1))
				)
			):
				pair_applications_valid = false
		else:
			pair_applications_valid = false
	var current_pair_projection_value: Variant = arm.get(
		"precondition_pair_barrier_application_projection"
	)
	var precondition_pair_retention_valid: bool = (
		_precondition_pair_final_state_valid_v1()
		and not terminal_source.is_empty()
		and pair_state_source_value is Dictionary
		and pair_state_source_value == terminal_source
		and _valid_sha256(terminal_source_sha)
		and pair_state_source_sha == terminal_source_sha
		and typeof(pair_state_source_step_value) == TYPE_INT
		and int(pair_state_source_step_value) == terminal_source_step
		and (
			PreconditionPairBarrier
			. terminal_source_valid_v1(
				_sdk,
				terminal_source,
				_precondition_pair_state,
				arm_id,
				terminal_source_step,
			)
		)
		and bool(state.get("precondition_pair_ready", false))
		and int(state.get("precondition_recovery_step_count", -1)) == terminal_source_step
		and int(state.get("precondition_pair_release_step_count", -1)) == 1
		and typeof(pair_wait_count_value) == TYPE_INT
		and int(pair_wait_count_value) == int(state.get("precondition_pair_wait_step_count", -1))
		and pair_applications_valid
		and pair_wait_application_count == int(pair_wait_count_value)
		and pair_release_application_count == 1
		and pair_applications.size() == pair_wait_application_count + 1
		and current_pair_projection_value is Dictionary
		and current_pair_projection_value == pair_applications[pair_applications.size() - 1]
	)
	if (
		not _valid_sha256(trace_sha)
		or rows.is_empty()
		or rows.size() != invariants.size()
		or rows.size() != int(state.get("total_completed_solver_step_count", -1))
		or int(model.get("solver_step_count", -1)) != rows.size()
		or not bool(arm["terminal"])
		or not bool(initial_application_validation.get("ok", false))
		or not Orchestrator.state_valid_v1(_sdk, state)
		or not all_invariants
		or not identity_preserved
		or not precondition_pair_retention_valid
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_ARM_TERMINAL_INVARIANT_INVALID",
			"arm_id": arm_id,
		}
	return {
		"schema_version": "sporespore_qsdk_r10f_continuous_passive_recovery_arm_result_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"arm_id": arm_id,
		"model_instance_id": String(arm["model_instance_id"]),
		"body_population_instance_sha256": String(arm["body_population_instance_sha256"]),
		"initial_same_body_identity_receipt":
		(arm["initial_same_body_identity_receipt"] as Dictionary).duplicate(true),
		"initial_application_validation_receipt": initial_application_validation.duplicate(true),
		"terminal_same_body_identity_receipt":
		(arm["terminal_same_body_identity_receipt"] as Dictionary).duplicate(true),
		"same_body_identity_preserved": identity_preserved,
		"initial_recovery_initialization_receipt":
		(arm["recovery_initialization_receipt"] as Dictionary).duplicate(true),
		"postkick_recovery_initialization_receipt":
		(arm["postkick_recovery_initialization_receipt"] as Dictionary).duplicate(true),
		"precondition_terminal_source": terminal_source,
		"precondition_terminal_source_sha256": terminal_source_sha,
		"precondition_pair_barrier_application_projections": pair_applications,
		"precondition_pair_barrier_application_projection_count": pair_applications.size(),
		"precondition_pair_barrier_wait_application_count": pair_wait_application_count,
		"precondition_pair_barrier_release_application_count": pair_release_application_count,
		"precondition_pair_barrier_retention_valid": precondition_pair_retention_valid,
		"recovery_step_receipts": (arm["recovery_step_receipts"] as Array).duplicate(true),
		"recovery_development_progression_receipts":
		(arm["recovery_development_progression_receipts"] as Array).duplicate(true),
		"walking_sessions": (arm["walking_sessions"] as Array).duplicate(true),
		"walking_actuation_handoff_receipts":
		(arm["walking_actuation_handoff_receipts"] as Array).duplicate(true),
		"interaction_receipt": (arm["interaction_receipt"] as Dictionary).duplicate(true),
		"motor_configuration_receipts":
		(arm["motor_configuration_receipts"] as Array).duplicate(true),
		"trace": trace,
		"trace_sha256": trace_sha,
		"outer_step_count": rows.size(),
		"native_solver_step_count": int(model["solver_step_count"]),
		"in_run_invariant_receipts": invariants.duplicate(true),
		"in_run_invariant_receipt_count": invariants.size(),
		"all_in_run_physical_invariants_passed": all_invariants,
		"final_recovery_memory": (arm["recovery_memory"] as Dictionary).duplicate(true),
		"final_orchestrator_state": state.duplicate(true),
		"final_phase": String(state["phase"]),
		"terminal_reason": String(state["terminal_reason"]),
		"external_kick_application_count": int(arm["external_kick_application_count"]),
		"body_population_rebuild_count": int(arm["body_population_rebuild_count"]),
		"body_transform_write_count": int(arm["body_transform_write_count"]),
		"body_velocity_write_count": int(arm["body_velocity_write_count"]),
		"solver_reset_count": int(arm["solver_reset_count"]),
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


func _evaluate_route_result_v1(arm_results: Dictionary) -> Dictionary:
	var active: Dictionary = arm_results[EnergyInitializer.ACTIVE_ARM_ID]
	var baseline: Dictionary = arm_results[EnergyInitializer.BASELINE_ARM_ID]
	var active_state: Dictionary = active["final_orchestrator_state"]
	var baseline_state: Dictionary = baseline["final_orchestrator_state"]
	var active_prefix := _walking_evaluation_v1(active, "walking_prefix")
	var baseline_prefix := _walking_evaluation_v1(baseline, "walking_prefix")
	var active_resume := _walking_evaluation_v1(active, "walking_resume")
	var baseline_continuation := _walking_evaluation_v1(baseline, "matched_continuation")
	var pair_valid := (
		not _interaction_pair_receipt.is_empty()
		and ImpulsePairReceipt.pair_receipt_valid_v1(_sdk, _interaction_pair_receipt)
	)
	var precondition_pair_valid := _precondition_pair_final_state_valid_v1()
	var precondition_ready: Dictionary = _precondition_pair_state.get("ready_by_arm", {})
	var precondition_source_shas: Dictionary = _precondition_pair_state.get(
		"terminal_source_sha256_by_arm", {}
	)
	var precondition_release_step_value: Variant = _precondition_pair_state.get(
		"release_completed_global_step"
	)
	var receipts := {
		"two_complete_equal_horizon_traces":
		int(active["outer_step_count"]) == int(baseline["outer_step_count"]),
		"same_body_population_preserved_both_arms":
		(
			bool(active["same_body_identity_preserved"])
			and bool(baseline["same_body_identity_preserved"])
		),
		"all_native_in_run_invariants_passed":
		(
			bool(active["all_in_run_physical_invariants_passed"])
			and bool(baseline["all_in_run_physical_invariants_passed"])
		),
		"both_precondition_recoveries_completed":
		(
			precondition_pair_valid
			and bool(active.get("precondition_pair_barrier_retention_valid", false))
			and bool(baseline.get("precondition_pair_barrier_retention_valid", false))
			and int(active_state.get("walking_prefix_step_count", 0)) > 0
			and int(baseline_state.get("walking_prefix_step_count", 0)) > 0
		),
		"precondition_pair_barrier_released_from_two_source_terminals":
		(
			precondition_pair_valid
			and typeof(precondition_release_step_value) == TYPE_INT
			and bool(precondition_ready.get(EnergyInitializer.ACTIVE_ARM_ID, false))
			and bool(precondition_ready.get(EnergyInitializer.BASELINE_ARM_ID, false))
			and (
				String(precondition_source_shas.get(EnergyInitializer.ACTIVE_ARM_ID, ""))
				== String(active.get("precondition_terminal_source_sha256", ""))
			)
			and (
				String(precondition_source_shas.get(EnergyInitializer.BASELINE_ARM_ID, ""))
				== String(baseline.get("precondition_terminal_source_sha256", ""))
			)
			and int(active_state.get("precondition_pair_release_step_count", 0)) == 1
			and int(baseline_state.get("precondition_pair_release_step_count", 0)) == 1
		),
		"both_walking_prefixes_passed":
		(
			bool(active_prefix.get("behavior_passed", false))
			and bool(baseline_prefix.get("behavior_passed", false))
		),
		"one_frozen_active_kick_and_matched_baseline_no_kick":
		(
			pair_valid
			and int(active["external_kick_application_count"]) == 1
			and int(baseline["external_kick_application_count"]) == 0
		),
		"active_native_kick_effect_source_measured":
		(
			pair_valid
			and (
				float(_interaction_pair_receipt.get("paired_native_effect_velocity_delta_m_s", 0.0))
				>= ImpulsePairReceipt.NATIVE_EFFECT_FLOOR_M_S
			)
		),
		"required_passive_prone_confirmation_observed":
		(
			int(active_state.get("consecutive_prone_sample_count", 0))
			>= Orchestrator.REQUIRED_CONSECUTIVE_PRONE_SAMPLES
		),
		"post_kick_v6_recovery_completed":
		(
			int(active_state.get("post_kick_recovery_step_count", 0)) > 0
			and String(active_state.get("phase", "")) == Orchestrator.PHASE_COMPLETE
		),
		"active_fresh_walking_resume_passed": bool(active_resume.get("behavior_passed", false)),
		"baseline_equal_horizon_continuation_valid":
		(
			bool(baseline_continuation.get("evidence_valid", false))
			and String(baseline_state.get("phase", "")) == Orchestrator.PHASE_COMPLETE
		),
		"zero_transform_velocity_or_solver_reset_rewrite":
		(
			int(active["body_population_rebuild_count"]) == 0
			and int(active["body_transform_write_count"]) == 0
			and int(active["body_velocity_write_count"]) == 0
			and int(active["solver_reset_count"]) == 0
			and int(baseline["body_population_rebuild_count"]) == 0
			and int(baseline["body_transform_write_count"]) == 0
			and int(baseline["body_velocity_write_count"]) == 0
			and int(baseline["solver_reset_count"]) == 0
		),
		"event_triggered_not_force_aware":
		(
			bool(active_state.get("event_triggered_passive_recovery", false))
			and not bool(active_state.get("force_aware_recovery", true))
		),
	}
	var false_receipts: Array = []
	for receipt_id in receipts:
		if not bool(receipts[receipt_id]):
			false_receipts.append(String(receipt_id))
	var evaluation := {
		"schema_version": "sporespore_qsdk_r10f_continuous_passive_recovery_evaluation_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"evidence_valid": true,
		"outcome_complete": true,
		"behavior_passed": false_receipts.is_empty(),
		"route_receipts": receipts,
		"false_route_receipts": false_receipts,
		"active_prefix_evaluation": active_prefix,
		"baseline_prefix_evaluation": baseline_prefix,
		"active_resume_evaluation": active_resume,
		"baseline_continuation_evaluation": baseline_continuation,
		"interaction_pair_receipt_sha256":
		String(_interaction_pair_receipt.get("payload_sha256", "")),
		"precondition_pair_barrier_state_sha256":
		String(_precondition_pair_state.get("payload_sha256", "")),
		"precondition_pair_barrier_released": precondition_pair_valid,
		"precondition_pair_barrier_release_global_step": precondition_release_step_value,
		"threshold_override_input_count": 0,
		"event_triggered_passive_recovery": true,
		"force_aware_recovery": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"payload_sha256": "",
	}
	evaluation["payload_sha256"] = _canonical_sha256_v1(evaluation)
	if not _valid_sha256(String(evaluation["payload_sha256"])):
		return {"ok": false, "failure_code": "QSDK_R10F_ROUTE_EVALUATION_DIGEST_INVALID"}
	return evaluation


func _walking_evaluation_v1(arm_result: Dictionary, segment_id: String) -> Dictionary:
	var sessions_value: Variant = arm_result.get("walking_sessions")
	if not (sessions_value is Array):
		return {}
	for session_value in sessions_value:
		if (
			session_value is Dictionary
			and String((session_value as Dictionary).get("evaluation_segment_id", "")) == segment_id
		):
			var evaluation_value: Variant = (session_value as Dictionary).get("evaluation")
			return (
				(evaluation_value as Dictionary).duplicate(true)
				if evaluation_value is Dictionary
				else {}
			)
	return {}


func _cleanup_worlds_v1() -> void:
	PhysicsServer3D.set_active(false)
	if physics_frame.is_connected(_on_physics_frame):
		physics_frame.disconnect(_on_physics_frame)
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		if not _arms.has(arm_id) or not (_arms[arm_id] is Dictionary):
			continue
		var arm: Dictionary = _arms[arm_id]
		var active_session_value: Variant = arm.get("active_walking_session")
		var facade_value: Variant = arm.get("facade")
		if (
			active_session_value is Dictionary
			and not (active_session_value as Dictionary).is_empty()
			and facade_value is RefCounted
			and walking_session_needs_shutdown_v2(arm)
		):
			(facade_value as RefCounted).finish_walking_session_v1()
			arm["active_walking_session"] = {}
		var model_value: Variant = arm.get("model")
		if model_value is Dictionary and not (model_value as Dictionary).is_empty():
			RouteScript.cleanup_native_world_v1(model_value as Dictionary)
			arm["model"] = {}
		_arms[arm_id] = arm


func _quiesce_process_isolated_child_v1() -> void:
	PhysicsServer3D.set_active(false)
	if physics_frame.is_connected(_on_physics_frame):
		physics_frame.disconnect(_on_physics_frame)


func _quiesce_process_isolated_child_before_abort_v1() -> void:
	_quiesce_process_isolated_child_v1()


func _publish_process_isolated_child_abort_v1(report: Dictionary) -> void:
	print(_raw_marker, JsonTransportScript.stringify(report))


func _abort_process_isolated_child_v1(code: String, detail: Dictionary = {}) -> void:
	_quiesce_process_isolated_child_before_abort_v1()
	var model_solver_steps := 0
	var model_world_attempts := 0
	var model_construction_attempts := 0
	var partial_arm := {}
	if _arms.has(_authorized_arm_id) and _arms[_authorized_arm_id] is Dictionary:
		var arm: Dictionary = _arms[_authorized_arm_id]
		var model_value: Variant = arm.get("model")
		if model_value is Dictionary:
			var model: Dictionary = model_value
			model_solver_steps = int(model.get("solver_step_count", 0))
			model_world_attempts = int(model.get("world_attempt_count", 0))
			model_construction_attempts = int(model.get("model_construction_attempt_count", 0))
		partial_arm = (
			partial_arm_failure_retention_projection_l15_v1(arm, _authorized_arm_id)
			if _repair_id == "QSDK-R10F-L15"
			else partial_arm_failure_retention_projection_v1(arm, _authorized_arm_id)
		)
	var solver_steps := maxi(_total_solver_step_count, model_solver_steps)
	var world_attempts := maxi(_total_world_attempt_count, model_world_attempts)
	var model_attempts := maxi(_total_model_construction_attempt_count, model_construction_attempts)
	var report := {
		"schema_version": _raw_schema,
		"gate_id": GATE_ID,
		"repair_id": _repair_id,
		"work_id": _work_id,
		"ledger_prefix": "[recovery/godot]",
		"question_class": "development",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "consumed_process_isolated_child_incomplete_raw",
			"question_class": "development",
		},
		"status": "invalid_or_incomplete_process_isolated_child_development",
		"ok": false,
		"measurement_complete": false,
		"scientific_outcome": "none",
		"role_outcome": "none",
		"failure_code": code,
		"detail": _json_safe_v1(detail),
		"source_commit": _source_commit,
		"authorization_sha256": _authorization_sha256,
		"parent_attempt_id": _parent_attempt_id,
		"child_attempt_id": _attempt_id,
		"attempt_id": _attempt_id,
		"arm_id": _authorized_arm_id,
		"process_id": OS.get_process_id(),
		"seed": _seed,
		"seed_label": _seed_label,
		"seed_sha256": _seed_sha256,
		"actuator_mode": ACTUATOR_MODE,
		"recovery_controller_id": RECOVERY_CONTROLLER_ID,
		"energy_route_id": ENERGY_ROUTE_ID,
		"precondition_terminal_receipt":
		_json_safe_v1(_process_isolated_precondition_terminal_receipt),
		"precondition_terminal_receipt_sha256":
		String(_process_isolated_precondition_terminal_receipt.get("payload_sha256", "")),
		"precondition_release_receipt":
		_json_safe_v1(_process_isolated_precondition_release_receipt),
		"interaction_source": _json_safe_v1(_process_isolated_interaction_source),
		"partial_arm": partial_arm,
		"behavior_evaluator_invocation_count": 0,
		"model_construction_attempt_count": model_attempts,
		"model_construction_count": _total_model_construction_count,
		"world_attempt_count": world_attempts,
		"world_build_count": _total_world_build_count,
		"solver_step_count": solver_steps,
		"maximum_solver_step_count": MAXIMUM_CHILD_SOLVER_STEPS,
		"global_solver_frame_count": _observed_global_solver_frames,
		"external_kick_application_count": _external_kick_application_count,
		"explicit_worker_extra_native_readback_count": _total_native_readback_count,
		"one_arm_per_process": _arms.size() <= 1,
		"one_world_per_process": _total_world_build_count <= 1,
		"world_or_body_state_imported_from_peer": false,
		"physical_question_opened": world_attempts > 0,
		"physics_state_modified": solver_steps > 0,
		"event_triggered_passive_recovery_observed": false,
		"recovery_success_observed": false,
		"prone_to_standing_claimed": false,
		"kick_impulse_alone_causes_fall_claimed": false,
		"force_aware_recovery": false,
		"force_aware_bracing": false,
		"arbitrary_fall_recovery_claimed": false,
		"cross_engine_push_recovery_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if _repair_id == "QSDK-R10F-L15":
		report["l15_prepared_context_comparison"] = _json_safe_v1(
			(
				get_meta("l15_prepared_context_comparison")
				if has_meta("l15_prepared_context_comparison")
				else null
			)
		)
	_cleanup_worlds_v1()
	_publish_process_isolated_child_abort_v1(report)
	_schedule_exit_v1(1, "invalid_or_incomplete_process_isolated_child_development")


static func partial_arm_failure_retention_projection_v1(
	arm: Dictionary,
	arm_id: String,
) -> Dictionary:
	return {
		"arm_id": arm_id,
		"model_instance_id": String(arm.get("model_instance_id", "")),
		"body_population_instance_sha256": String(arm.get("body_population_instance_sha256", "")),
		"orchestrator_state": _json_safe_v1(arm.get("orchestrator_state", {})),
		"recovery_memory": _json_safe_v1(arm.get("recovery_memory", {})),
		"last_recovery_step_receipt": _json_safe_v1(arm.get("last_recovery_step_receipt", {})),
		"last_recovery_classification": _json_safe_v1(arm.get("last_recovery_classification", {})),
		"terminal_orchestrator_transition":
		_json_safe_v1(arm.get("terminal_orchestrator_transition", {})),
		"terminal_recovery_observation_sources":
		_json_safe_v1(arm.get("terminal_recovery_observation_sources", {})),
		"trace_rows": _json_safe_v1(arm.get("trace_rows", [])),
		"invariant_receipts": _json_safe_v1(arm.get("invariant_receipts", [])),
		"walking_sessions": _json_safe_v1(arm.get("walking_sessions", [])),
		"walking_actuation_handoff_receipts":
		_json_safe_v1(arm.get("walking_actuation_handoff_receipts", [])),
		"active_walking_session": _json_safe_v1(arm.get("active_walking_session", {})),
		"last_walking_step_failure": _json_safe_v1(arm.get("last_walking_step_failure", {})),
		"last_walking_evaluation_failure":
		_json_safe_v1(arm.get("last_walking_evaluation_failure", {})),
		"walking_session_completion_attempted":
		arm.get("walking_session_completion_attempted", false),
		"interaction_receipt": _json_safe_v1(arm.get("interaction_receipt", {})),
		"external_kick_application_count": int(arm.get("external_kick_application_count", 0)),
		"body_population_rebuild_count": int(arm.get("body_population_rebuild_count", 0)),
		"body_transform_write_count": int(arm.get("body_transform_write_count", 0)),
		"body_velocity_write_count": int(arm.get("body_velocity_write_count", 0)),
		"solver_reset_count": int(arm.get("solver_reset_count", 0)),
		"direct_torso_force_command_count": arm.get("direct_torso_force_command_count", 0),
		"direct_torso_impulse_command_count": arm.get("direct_torso_impulse_command_count", 0),
		"direct_torso_velocity_command_count": arm.get("direct_torso_velocity_command_count", 0),
		"direct_torso_transform_command_count": arm.get("direct_torso_transform_command_count", 0),
	}


## Exact collection bytes are strings inside the existing JSON-safe projection;
## it never re-parses or reserializes the original request/response payloads.
static func partial_arm_failure_retention_projection_l15_v1(
	arm: Dictionary, arm_id: String
) -> Dictionary:
	var partial := partial_arm_failure_retention_projection_v1(arm, arm_id)
	for key in [
		"last_recovery_collection_transport_retention",
		"last_recovery_collection_transport_global_semantic_step",
		"last_recovery_advance_failure",
	]:
		# A missing current record remains null; a previous step's record must
		# never be substituted or synthesized during abort projection.
		partial[key] = _json_safe_v1(arm.get(key))
	return partial


static func partial_walking_failure_retention_valid_v1(partial_arm: Dictionary) -> bool:
	var session_value: Variant = partial_arm.get("active_walking_session")
	var failure_value: Variant = partial_arm.get("last_walking_step_failure")
	if not (session_value is Dictionary) or not (failure_value is Dictionary):
		return false
	var session: Dictionary = session_value
	var failure: Dictionary = failure_value
	if session.is_empty() or failure.is_empty():
		return false
	for session_key in ["session_id", "start_receipt", "walking_actuation_handoff_receipt"]:
		if not session.has(session_key) or session.get(session_key) == null:
			return false
	for failure_key in [
		"portable_step_receipt",
		"native_step_transport_verification",
		"controller_step_receipt",
		"authority_application_receipt",
		"motor_population_readback",
		"walking_actuation_handoff_receipt",
		"host_target_projection_receipt",
		"walking_ledger_predicate_receipt",
	]:
		if not (failure.get(failure_key) is Dictionary):
			return false
	return (
		failure.get("failed_predicate_ids") is Array
		and not (failure.get("failed_predicate_ids") as Array).is_empty()
		and not bool(failure.get("generic_failure_without_predicate_detail", true))
	)


func _abort(code: String, detail: Dictionary = {}) -> void:
	if _exit_scheduled:
		return
	if _authorized_arm_id in ARM_ORDER and not _parent_attempt_id.is_empty():
		_abort_process_isolated_child_v1(code, detail)
		return
	PhysicsServer3D.set_active(false)
	if physics_frame.is_connected(_on_physics_frame):
		physics_frame.disconnect(_on_physics_frame)
	var solver_steps := _total_solver_step_count
	var world_attempts := _total_world_attempt_count
	var world_builds := _total_world_build_count
	var model_attempts := _total_model_construction_attempt_count
	var model_builds := _total_model_construction_count
	var model_solver_steps := 0
	var model_world_attempts := 0
	var model_construction_attempts := 0
	for arm_value in _arms.values():
		if not (arm_value is Dictionary):
			continue
		var model_value: Variant = (arm_value as Dictionary).get("model")
		if not (model_value is Dictionary):
			continue
		var model: Dictionary = model_value
		model_solver_steps += int(model.get("solver_step_count", 0))
		model_world_attempts += int(model.get("world_attempt_count", 0))
		model_construction_attempts += int(model.get("model_construction_attempt_count", 0))
	solver_steps = maxi(solver_steps, model_solver_steps)
	world_attempts = maxi(world_attempts, model_world_attempts)
	model_attempts = maxi(model_attempts, model_construction_attempts)
	var precondition_pair_state_valid := (
		_sdk != null
		and not _precondition_pair_state.is_empty()
		and PreconditionPairBarrier.state_valid_v1(_sdk, _precondition_pair_state)
	)
	var precondition_terminal_disposition_population_valid := _precondition_terminal_disposition_population_valid_v1()
	var precondition_terminal_abort_population_valid := (
		_sdk != null
		and not _precondition_terminal_abort_population.is_empty()
		and not _precondition_terminal_disposition_pair_state.is_empty()
		and (
			PreconditionTerminalDisposition
			. abort_population_valid_v1(
				_sdk,
				_precondition_terminal_abort_population,
				_precondition_terminal_disposition_pair_state,
			)
		)
	)
	var report := {
		"schema_version": _raw_schema,
		"gate_id": GATE_ID,
		"work_id": _work_id,
		"ledger_prefix": "[recovery/godot]",
		"question_class": "development",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "consumed_physical_development_raw",
			"question_class": "development",
		},
		"status": "invalid_or_incomplete_behavior_development",
		"ok": false,
		"failure_code": code,
		"detail": _json_safe_v1(detail),
		"source_commit": _source_commit,
		"attempt_id": _attempt_id,
		"authorization_sha256": _authorization_sha256,
		"cell_id": "r10f_godot_development_continuous_passive_recovery",
		"seed": _seed,
		"seed_label": _seed_label,
		"seed_sha256": _seed_sha256,
		"actuator_mode": ACTUATOR_MODE,
		"recovery_controller_id": RECOVERY_CONTROLLER_ID,
		"energy_route_id": ENERGY_ROUTE_ID,
		"precondition_pair_barrier_state": _json_safe_v1(_precondition_pair_state),
		"precondition_pair_barrier_state_sha256":
		String(_precondition_pair_state.get("payload_sha256", "")),
		"precondition_pair_barrier_state_valid": precondition_pair_state_valid,
		"precondition_pair_barrier_released": bool(_precondition_pair_state.get("released", false)),
		"precondition_pair_barrier_evidence_by_arm":
		_json_safe_v1(_precondition_pair_evidence_by_arm_v1()),
		"precondition_terminal_disposition_by_arm":
		_json_safe_v1(_precondition_terminal_disposition_by_arm),
		"precondition_terminal_disposition_sha256_by_arm":
		_json_safe_v1(_precondition_terminal_disposition_sha256_by_arm_v1()),
		"precondition_terminal_disposition_pair_state":
		_json_safe_v1(_precondition_terminal_disposition_pair_state),
		"precondition_terminal_disposition_pair_state_sha256":
		String(_precondition_terminal_disposition_pair_state.get("payload_sha256", "")),
		"precondition_terminal_disposition_population_valid":
		precondition_terminal_disposition_population_valid,
		"precondition_terminal_abort_population":
		_json_safe_v1(_precondition_terminal_abort_population),
		"precondition_terminal_abort_population_sha256":
		String(_precondition_terminal_abort_population.get("payload_sha256", "")),
		"precondition_terminal_abort_population_valid":
		precondition_terminal_abort_population_valid,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"outer_step_duration_s": 1.0 / float(PHYSICS_HZ),
		"held_out": false,
		"held_out_cell_access_count": 0,
		"population_inference_claimed": false,
		"recovery_success_required_for_valid_result": false,
		"physics_failure_is_valid_evidence": true,
		"behavior_evaluator_invocation_count": 0,
		"model_construction_attempt_count": model_attempts,
		"model_construction_count": model_builds,
		"world_attempt_count": world_attempts,
		"world_build_count": world_builds,
		"solver_step_count": solver_steps,
		"maximum_solver_step_count": MAXIMUM_TOTAL_SOLVER_STEPS,
		"global_lockstep_solver_frame_count": _observed_global_solver_frames,
		"external_kick_application_count": _external_kick_application_count,
		"explicit_worker_extra_native_readback_count": _total_native_readback_count,
		"physical_question_opened": world_attempts > 0,
		"physics_state_modified": solver_steps > 0,
		"event_triggered_passive_recovery_observed": false,
		"recovery_success_observed": false,
		"prone_to_standing_claimed": false,
		"kick_impulse_alone_causes_fall_claimed": false,
		"force_aware_recovery": false,
		"force_aware_bracing": false,
		"arbitrary_fall_recovery_claimed": false,
		"cross_engine_push_recovery_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	_cleanup_worlds_v1()
	print(_raw_marker, JsonTransportScript.stringify(report))
	_schedule_exit_v1(1, "invalid_or_incomplete_behavior_development")


func _schedule_exit_v1(exit_code: int, receipt_kind: String) -> void:
	if _exit_scheduled:
		return
	_exit_scheduled = true
	_pending_exit_code = exit_code
	_pending_receipt_kind = receipt_kind
	_pending_exit_process_frames = EXIT_DRAIN_PROCESS_FRAME_COUNT
	process_frame.connect(_orderly_exit_process_frame_v1, CONNECT_ONE_SHOT)


func _orderly_exit_process_frame_v1() -> void:
	_pending_exit_process_frames -= 1
	if _pending_exit_process_frames > 0:
		process_frame.connect(_orderly_exit_process_frame_v1, CONNECT_ONE_SHOT)
		return
	if OS.get_environment(SUPERVISED_ENV) == "1":
		if _termination_nonce.is_empty():
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
						"termination_nonce": _termination_nonce,
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


func _worker_route_tags_v1() -> Dictionary:
	return {
		"raw_schema": RAW_SCHEMA,
		"work_ids": [WORK_ID, L15_WORK_ID],
		"raw_marker": RAW_MARKER,
		"ready_marker": READY_MARKER,
	}


func _authorized_seed_binding_v1(seed_text: String, label: String, digest: String) -> bool:
	# Historical/default workers retain their exact development-only seed rule.
	return (seed_text.is_valid_int() and seed_text.to_int() == DEVELOPMENT_SEED
		and label == DEVELOPMENT_SEED_LABEL and digest == DEVELOPMENT_SEED_SHA256)


func _load_campaign_binding_v1() -> bool:
	var route_tags := _worker_route_tags_v1()
	var authorization := OS.get_environment(AUTHORIZATION_ENV)
	var source_commit := OS.get_environment(SOURCE_COMMIT_ENV)
	var attempt_id := OS.get_environment(ATTEMPT_ID_ENV)
	var supervised := OS.get_environment(SUPERVISED_ENV)
	var nonce := OS.get_environment(NONCE_ENV)
	var configured_gate := OS.get_environment(GATE_ID_ENV)
	var configured_token := OS.get_environment(GATE_TOKEN_ENV)
	var configured_schema := OS.get_environment(RAW_SCHEMA_ENV)
	var configured_work_id := OS.get_environment(WORK_ID_ENV)
	var configured_raw_marker := OS.get_environment(RAW_MARKER_ENV)
	var configured_ready_marker := OS.get_environment(READY_MARKER_ENV)
	var configured_progress_marker := OS.get_environment(PROGRESS_MARKER_ENV)
	var configured_progress_cadence := OS.get_environment(PROGRESS_CADENCE_ENV)
	var configured_seed := OS.get_environment(SEED_ENV)
	var configured_seed_label := OS.get_environment(SEED_LABEL_ENV)
	var configured_seed_sha := OS.get_environment(SEED_SHA_ENV)
	var configured_actuator_mode := OS.get_environment(ACTUATOR_MODE_ENV)
	var configured_controller_id := OS.get_environment(CONTROLLER_ID_ENV)
	var configured_energy_route_id := OS.get_environment(ENERGY_ROUTE_ID_ENV)
	var parent_attempt_id := OS.get_environment(PARENT_ATTEMPT_ID_ENV)
	var child_role := OS.get_environment(CHILD_ROLE_ENV)
	if (
		not _valid_sha256(authorization)
		or not _is_lower_hex_v1(source_commit, 40)
		or not _is_lower_hex_v1(attempt_id, 32)
		or supervised != "1"
		or not _is_lower_hex_v1(nonce, 32)
		or configured_gate != GATE_ID
		or configured_token != GATE_TOKEN
		or configured_schema != route_tags["raw_schema"]
		or configured_work_id not in route_tags["work_ids"]
		or configured_raw_marker != route_tags["raw_marker"]
		or configured_ready_marker != route_tags["ready_marker"]
		or not configured_progress_marker.is_empty()
		or configured_progress_cadence not in ["", "0"]
		or not _authorized_seed_binding_v1(configured_seed, configured_seed_label, configured_seed_sha)
		or configured_actuator_mode != ACTUATOR_MODE
		or configured_controller_id != RECOVERY_CONTROLLER_ID
		or configured_energy_route_id != ENERGY_ROUTE_ID
		or not _is_lower_hex_v1(parent_attempt_id, 32)
		or parent_attempt_id == attempt_id
		or child_role not in ARM_ORDER
	):
		return false
	_authorization_sha256 = authorization
	_source_commit = source_commit
	_attempt_id = attempt_id
	_termination_nonce = nonce
	_raw_schema = configured_schema
	_work_id = configured_work_id
	# Family is fixed once, after the complete supervisor envelope passes, before any world.
	_repair_id = "QSDK-R10F-L15" if configured_work_id == L15_WORK_ID else REPAIR_ID
	if route_tags.has("implementation_family"):
		_repair_id = String(route_tags["implementation_family"])
	_raw_marker = configured_raw_marker
	_ready_marker = configured_ready_marker
	_seed = configured_seed.to_int()
	_seed_label = configured_seed_label
	_seed_sha256 = configured_seed_sha
	_parent_attempt_id = parent_attempt_id
	_authorized_arm_id = child_role
	return true


static func zero_world_contract_v1(sdk: Object) -> Dictionary:
	if sdk == null:
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_WORKER_ZERO_WORLD_SDK_MISSING",
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"solver_step_count": 0,
			"physics_state_modified": false,
		}
	var configuration := LocomotionFacade.configuration_receipt_v1(sdk)
	var configuration_sha := String(
		RecoveryRuntimeScript.canonicalize(sdk, configuration).get("sha256", "")
	)
	var active := (
		Orchestrator
		. initialize_v1(
			sdk,
			"r10f-worker-zero-world-lockstep-contract",
			EnergyInitializer.ACTIVE_ARM_ID,
			"r10f-worker-zero-world-active-model",
			configuration_sha,
			"sha256:" + "a".repeat(64),
			0,
		)
	)
	var baseline := (
		Orchestrator
		. initialize_v1(
			sdk,
			"r10f-worker-zero-world-lockstep-contract",
			EnergyInitializer.BASELINE_ARM_ID,
			"r10f-worker-zero-world-baseline-model",
			configuration_sha,
			"sha256:" + "b".repeat(64),
			0,
		)
	)
	var pair_plan := (
		(
			Orchestrator
			. isolated_lockstep_pair_plan_v1(
				sdk,
				active.get("state", {}),
				baseline.get("state", {}),
			)
		)
		if bool(active.get("ok", false)) and bool(baseline.get("ok", false))
		else {"ok": false}
	)
	var ok := (
		bool(configuration.get("ok", false))
		and _valid_sha256_static_v1(configuration_sha)
		and bool(active.get("ok", false))
		and bool(baseline.get("ok", false))
		and bool(pair_plan.get("ok", false))
	)
	return {
		"schema_version": "sporespore_qsdk_r10f_worker_zero_world_contract_v1",
		"gate_id": GATE_ID,
		"ok": ok,
		"configuration_sha256": configuration_sha,
		"lockstep_plan": (pair_plan.get("plan", {}) as Dictionary).duplicate(true),
		"development_seed": DEVELOPMENT_SEED,
		"maximum_global_lockstep_solver_frame_count": Orchestrator.MAXIMUM_ACTIVE_ARM_SOLVER_STEPS,
		"maximum_total_solver_step_count": MAXIMUM_TOTAL_SOLVER_STEPS,
		"active_terminal_frame_closes_both_arms":
		bool(
			(pair_plan.get("plan", {}) as Dictionary).get(
				"active_terminal_frame_closes_both_arms", false
			)
		),
		"behavioral_failure_is_valid_complete_evidence": true,
		"infrastructure_failure_is_invalid_or_incomplete": true,
		"event_triggered_passive_recovery": true,
		"force_aware_recovery": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"body_impulse_write_count": 0,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
	}


static func _initial_bootstrap_zero_world_controls_v1(
	sdk: Object,
	context: Dictionary,
) -> Dictionary:
	var surface := RouteScript.zero_world_command_surface_v1(context)
	if not bool(surface.get("ok", false)):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_BOOTSTRAP_COMMAND_SURFACE_INVALID",
			"surface": surface,
		}
	var ordered_joints: Array = surface["ordered_joints"]
	var joint_nodes: Dictionary = {}
	for index in range(NativeWorldScript.ORDERED_JOINT_IDS.size()):
		joint_nodes[NativeWorldScript.ORDERED_JOINT_IDS[index]] = ordered_joints[index]
	var model := {
		"ok": true,
		"host_step_count": 0,
		"joint_nodes": joint_nodes,
		"complete_energy_profile_selected": true,
		"solver_coupled_complete_energy_profile_selected": true,
		"discrete_staging_complete_energy_profile_selected": true,
	}
	var initial := (
		RouteScript
		. initial_behavior_application_route_aware_discrete_staging_v2(
			sdk,
			model,
			INTERNAL_RECOVERY_ARM_KIND,
			"confirm_prone",
			RECOVERY_CONTROLLER_ID,
		)
	)
	var positive := initial_bootstrap_application_validation_v1(
		initial,
		INTERNAL_RECOVERY_ARM_KIND,
		"confirm_prone",
		RECOVERY_CONTROLLER_ID,
	)
	var active_validator_rejected := not (
		BehaviorWorker
		. behavior_application_receipt_valid_v4(
			ACTUATOR_MODE,
			initial,
			true,
			ENERGY_ROUTE_ID,
			true,
		)
	)
	var mutations: Array = []
	var missing_bootstrap := initial.duplicate(true)
	missing_bootstrap.erase("bootstrap_application")
	mutations.append(missing_bootstrap)
	var forged_active_schema := initial.duplicate(true)
	forged_active_schema["schema_version"] = ("sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_complete_energy_command_application_receipt_v1")
	forged_active_schema["predecessor_route_aware_application_schema_version"] = ("sporespore_qsdk_r24d151_godot_discrete_staging_complete_energy_command_application_receipt_v1")
	forged_active_schema["predecessor_complete_energy_schema_version"] = ("sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_command_application_receipt_v1")
	mutations.append(forged_active_schema)
	var wrong_route := initial.duplicate(true)
	wrong_route["energy_route_id"] = RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
	mutations.append(wrong_route)
	var missing_provenance := initial.duplicate(true)
	missing_provenance.erase("application_provenance_profile_id")
	mutations.append(missing_provenance)
	var enabled_motor_count := initial.duplicate(true)
	enabled_motor_count["motor_enabled_count"] = 1
	mutations.append(enabled_motor_count)
	var enabled_motor_intent := initial.duplicate(true)
	var enabled_intents: Array = enabled_motor_intent["ordered_intents"]
	var enabled_first_intent: Dictionary = enabled_intents[0]
	enabled_first_intent["motor_enabled"] = true
	enabled_intents[0] = enabled_first_intent
	enabled_motor_intent["ordered_intents"] = enabled_intents
	mutations.append(enabled_motor_intent)
	var rejection_count := 0
	for mutation_value in mutations:
		var mutation: Dictionary = mutation_value
		var receipt := initial_bootstrap_application_validation_v1(
			mutation,
			INTERNAL_RECOVERY_ARM_KIND,
			"confirm_prone",
			RECOVERY_CONTROLLER_ID,
		)
		if not bool(receipt.get("ok", false)):
			rejection_count += 1
	RouteScript.free_zero_world_command_surface_v1(surface)
	return {
		"schema_version": "sporespore_qsdk_r10f_initial_bootstrap_zero_world_controls_v1",
		"gate_id": GATE_ID,
		"ok":
		(
			bool(initial.get("ok", false))
			and bool(positive.get("ok", false))
			and active_validator_rejected
			and rejection_count == mutations.size()
		),
		"producer_schema": String(initial.get("schema_version", "")),
		"consumer_validation": positive,
		"active_application_validator_rejected_bootstrap": active_validator_rejected,
		"mutation_rejection_count": rejection_count,
		"detached_command_surface_node_count": ordered_joints.size(),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func zero_world_contract_v2(sdk: Object, context: Dictionary) -> Dictionary:
	var predecessor := zero_world_contract_v1(sdk)
	var bootstrap_controls := _initial_bootstrap_zero_world_controls_v1(sdk, context)
	var result: Dictionary = predecessor.duplicate(true)
	result["schema_version"] = "sporespore_qsdk_r10f_worker_zero_world_contract_v2"
	result["ok"] = (
		bool(predecessor.get("ok", false)) and bool(bootstrap_controls.get("ok", false))
	)
	result["predecessor_contract_schema_version"] = String(predecessor.get("schema_version", ""))
	result["initial_bootstrap_controls"] = bootstrap_controls
	result["initial_bootstrap_producer_consumer_control_count"] = 1
	result["initial_bootstrap_mutation_rejection_count"] = int(
		bootstrap_controls.get("mutation_rejection_count", -1)
	)
	result["detached_command_surface_node_count"] = int(
		bootstrap_controls.get("detached_command_surface_node_count", -1)
	)
	return result


static func _joint_geometry_source_shape_fixture_v1(
	sdk: Object,
	context: Dictionary,
) -> Dictionary:
	var blueprint := RouteScript.native_world_blueprint_v1(sdk, context)
	var positions_value: Variant = blueprint.get("positions")
	var bases_value: Variant = blueprint.get("bases")
	var joint_specs_value: Variant = blueprint.get("joint_by_id")
	if (
		not bool(blueprint.get("ok", false))
		or not (positions_value is Dictionary)
		or not (bases_value is Dictionary)
		or not (joint_specs_value is Dictionary)
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_GEOMETRY_ZERO_WORLD_BLUEPRINT_INVALID",
			"blueprint": blueprint,
		}
	var positions: Dictionary = positions_value
	var bases: Dictionary = bases_value
	var joint_specs: Dictionary = joint_specs_value
	var body_nodes: Dictionary = {}
	var joint_nodes: Dictionary = {}
	var joint_states: Dictionary = {}
	var detached_nodes: Array = []
	for body_id_value in NativeWorldScript.ORDERED_BODY_IDS:
		var body_id := String(body_id_value)
		var position_value: Variant = positions.get(body_id)
		var basis_value: Variant = bases.get(body_id)
		if not (position_value is Vector3) or not (basis_value is Basis):
			for node_value in detached_nodes:
				(node_value as Node).free()
			return {
				"ok": false,
				"failure_code":
				"QSDK_R10F_GEOMETRY_ZERO_WORLD_BODY_DECLARATION_INVALID:%s" % body_id,
			}
		var body := RigidBody3D.new()
		body.name = "r10f_zero_world_%s" % body_id
		body.set_meta("lab_body_id", body_id)
		body.position = position_value
		body.basis = basis_value
		body_nodes[body_id] = body
		detached_nodes.append(body)
	var ordered_joint_rows: Array = []
	for index in range(NativeWorldScript.ORDERED_JOINT_IDS.size()):
		var joint_id := String(NativeWorldScript.ORDERED_JOINT_IDS[index])
		var spec_value: Variant = joint_specs.get(joint_id)
		if not (spec_value is Dictionary):
			for node_value in detached_nodes:
				(node_value as Node).free()
			return {
				"ok": false,
				"failure_code":
				"QSDK_R10F_GEOMETRY_ZERO_WORLD_JOINT_DECLARATION_INVALID:%s" % joint_id,
			}
		var spec: Dictionary = spec_value
		var parent_id := String(spec.get("parent_body_id", ""))
		var child_id := String(spec.get("child_body_id", ""))
		var joint := HingeJoint3D.new()
		joint.name = "r10f_zero_world_%s" % joint_id
		joint.set_meta("lab_joint_id", joint_id)
		joint_nodes[joint_id] = joint
		detached_nodes.append(joint)
		joint_states[joint_id] = {
			"joint_id": joint_id,
			"parent": body_nodes.get(parent_id),
			"child": body_nodes.get(child_id),
			"joint": joint,
			"anchor_parent_local": _vector3_dictionary_v1(spec.get("anchor_parent_m")),
			"anchor_child_local": _vector3_dictionary_v1(spec.get("anchor_child_m")),
			"axis_parent_local": Vector3.BACK,
		}
		(
			ordered_joint_rows
			. append(
				{
					"joint_id": joint_id,
					"position_rad": 0.0,
					"velocity_rad_s": 0.0,
					"anchor_error_m": float(index + 1) * 0.001,
					"validity": {"position": true, "velocity": true, "anchor_error": true},
				}
			)
		)
	return {
		"ok": true,
		"model":
		{
			"schema_version": "sporespore_qsdk_r24d57_godot_recovery_native_world_v1",
			"blueprint": blueprint,
			"body_nodes": body_nodes,
			"joint_nodes": joint_nodes,
			"joint_states": joint_states,
		},
		"observation":
		{
			"state":
			{
				"schema_version": "sporespore_state_frame_v1",
				"semantic_step": 1,
				"ordered_joint_observations": ordered_joint_rows,
			}
		},
		"detached_nodes": detached_nodes,
		"detached_body_node_count": body_nodes.size(),
		"detached_joint_node_count": joint_nodes.size(),
	}


static func _joint_geometry_zero_world_controls_v1(
	sdk: Object,
	context: Dictionary,
) -> Dictionary:
	var fixture := _joint_geometry_source_shape_fixture_v1(sdk, context)
	if not bool(fixture.get("ok", false)):
		return fixture
	var model: Dictionary = fixture["model"]
	var observation: Dictionary = fixture["observation"]
	var positive := _joint_geometry_summary_v2(model, observation)
	var first_joint_id := String(LocomotionFacade.JOINT_IDS[0])
	var first_state: Dictionary = (model["joint_states"] as Dictionary)[first_joint_id]
	var first_child: RigidBody3D = first_state["child"]
	var original_child_basis := first_child.basis
	first_child.basis = Basis(Vector3.RIGHT, 0.125) * original_child_basis
	var axis_canary := _joint_geometry_summary_v2(model, observation)
	first_child.basis = original_child_basis

	var mutations: Array = []
	var wrong_model_schema := model.duplicate(true)
	wrong_model_schema["schema_version"] = "forged_recovery_world"
	mutations.append(
		{
			"model": wrong_model_schema,
			"observation": observation,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_MODEL_OR_OBSERVATION_SHAPE_INVALID"
		}
	)
	var missing_joint_state := model.duplicate(true)
	var missing_states: Dictionary = missing_joint_state["joint_states"]
	missing_states.erase(first_joint_id)
	missing_joint_state["joint_states"] = missing_states
	mutations.append(
		{
			"model": missing_joint_state,
			"observation": observation,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_CARDINALITY_INVALID"
		}
	)
	var reordered_observation := observation.duplicate(true)
	var reordered_rows: Array = (reordered_observation["state"] as Dictionary)["ordered_joint_observations"]
	var first_row: Variant = reordered_rows[0]
	reordered_rows[0] = reordered_rows[1]
	reordered_rows[1] = first_row
	(reordered_observation["state"] as Dictionary)["ordered_joint_observations"] = reordered_rows
	mutations.append(
		{
			"model": model,
			"observation": reordered_observation,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_ANCHOR_MEASUREMENT_INVALID"
		}
	)
	var nonfinite_observation := observation.duplicate(true)
	var nonfinite_rows: Array = (nonfinite_observation["state"] as Dictionary)["ordered_joint_observations"]
	(nonfinite_rows[0] as Dictionary)["anchor_error_m"] = NAN
	(nonfinite_observation["state"] as Dictionary)["ordered_joint_observations"] = nonfinite_rows
	mutations.append(
		{
			"model": model,
			"observation": nonfinite_observation,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_ANCHOR_MEASUREMENT_INVALID"
		}
	)
	var negative_observation := observation.duplicate(true)
	var negative_rows: Array = (negative_observation["state"] as Dictionary)["ordered_joint_observations"]
	(negative_rows[0] as Dictionary)["anchor_error_m"] = -0.001
	(negative_observation["state"] as Dictionary)["ordered_joint_observations"] = negative_rows
	mutations.append(
		{
			"model": model,
			"observation": negative_observation,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_ANCHOR_MEASUREMENT_INVALID"
		}
	)
	var invalid_anchor_flag := observation.duplicate(true)
	var invalid_flag_rows: Array = (invalid_anchor_flag["state"] as Dictionary)["ordered_joint_observations"]
	var invalid_validity: Dictionary = (invalid_flag_rows[0] as Dictionary)["validity"]
	invalid_validity["anchor_error"] = false
	(invalid_flag_rows[0] as Dictionary)["validity"] = invalid_validity
	(invalid_anchor_flag["state"] as Dictionary)["ordered_joint_observations"] = invalid_flag_rows
	mutations.append(
		{
			"model": model,
			"observation": invalid_anchor_flag,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_ANCHOR_MEASUREMENT_INVALID"
		}
	)
	var injected_child_axis := model.duplicate(true)
	var injected_states: Dictionary = injected_child_axis["joint_states"]
	var injected_state: Dictionary = injected_states[first_joint_id]
	injected_state["axis_child_local"] = Vector3.BACK
	injected_states[first_joint_id] = injected_state
	injected_child_axis["joint_states"] = injected_states
	mutations.append(
		{
			"model": injected_child_axis,
			"observation": observation,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_JOINT_STATE_CONTRACT_INVALID"
		}
	)
	var missing_parent_axis := model.duplicate(true)
	var missing_axis_states: Dictionary = missing_parent_axis["joint_states"]
	var missing_axis_state: Dictionary = missing_axis_states[first_joint_id]
	missing_axis_state.erase("axis_parent_local")
	missing_axis_states[first_joint_id] = missing_axis_state
	missing_parent_axis["joint_states"] = missing_axis_states
	mutations.append(
		{
			"model": missing_parent_axis,
			"observation": observation,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_JOINT_STATE_CONTRACT_INVALID"
		}
	)
	var wrong_parent_axis := model.duplicate(true)
	var wrong_axis_states: Dictionary = wrong_parent_axis["joint_states"]
	var wrong_axis_state: Dictionary = wrong_axis_states[first_joint_id]
	wrong_axis_state["axis_parent_local"] = Vector3.RIGHT
	wrong_axis_states[first_joint_id] = wrong_axis_state
	wrong_parent_axis["joint_states"] = wrong_axis_states
	mutations.append(
		{
			"model": wrong_parent_axis,
			"observation": observation,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_SHARED_PLANAR_AXIS_INVALID"
		}
	)
	var wrong_anchor := model.duplicate(true)
	var wrong_anchor_states: Dictionary = wrong_anchor["joint_states"]
	var wrong_anchor_state: Dictionary = wrong_anchor_states[first_joint_id]
	wrong_anchor_state["anchor_parent_local"] = Vector3.ZERO
	wrong_anchor_states[first_joint_id] = wrong_anchor_state
	wrong_anchor["joint_states"] = wrong_anchor_states
	mutations.append(
		{
			"model": wrong_anchor,
			"observation": observation,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_ANCHOR_CONTRACT_INVALID"
		}
	)
	var wrong_parent_binding := model.duplicate(true)
	var wrong_parent_states: Dictionary = wrong_parent_binding["joint_states"]
	var wrong_parent_state: Dictionary = wrong_parent_states[first_joint_id]
	wrong_parent_state["parent"] = first_state["child"]
	wrong_parent_states[first_joint_id] = wrong_parent_state
	wrong_parent_binding["joint_states"] = wrong_parent_states
	mutations.append(
		{
			"model": wrong_parent_binding,
			"observation": observation,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_NODE_IDENTITY_INVALID"
		}
	)
	var invalid_row_shape := observation.duplicate(true)
	var invalid_shape_rows: Array = (invalid_row_shape["state"] as Dictionary)["ordered_joint_observations"]
	invalid_shape_rows[0] = "not-a-joint-observation"
	(invalid_row_shape["state"] as Dictionary)["ordered_joint_observations"] = invalid_shape_rows
	mutations.append(
		{
			"model": model,
			"observation": invalid_row_shape,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_JOINT_SOURCE_SHAPE_INVALID"
		}
	)
	var wrong_state_schema := observation.duplicate(true)
	(wrong_state_schema["state"] as Dictionary)["schema_version"] = "forged_state_frame"
	mutations.append(
		{
			"model": model,
			"observation": wrong_state_schema,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_MODEL_OR_OBSERVATION_SHAPE_INVALID"
		}
	)
	var textual_anchor := observation.duplicate(true)
	var textual_anchor_rows: Array = (textual_anchor["state"] as Dictionary)["ordered_joint_observations"]
	(textual_anchor_rows[0] as Dictionary)["anchor_error_m"] = "0.001"
	(textual_anchor["state"] as Dictionary)["ordered_joint_observations"] = textual_anchor_rows
	mutations.append(
		{
			"model": model,
			"observation": textual_anchor,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_ANCHOR_MEASUREMENT_INVALID"
		}
	)
	var numeric_validity := observation.duplicate(true)
	var numeric_validity_rows: Array = (numeric_validity["state"] as Dictionary)["ordered_joint_observations"]
	var numeric_validity_flags: Dictionary = (numeric_validity_rows[0] as Dictionary)["validity"]
	numeric_validity_flags["anchor_error"] = 1
	(numeric_validity_rows[0] as Dictionary)["validity"] = numeric_validity_flags
	(numeric_validity["state"] as Dictionary)["ordered_joint_observations"] = numeric_validity_rows
	mutations.append(
		{
			"model": model,
			"observation": numeric_validity,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_ANCHOR_MEASUREMENT_INVALID"
		}
	)
	var numeric_joint_id := observation.duplicate(true)
	var numeric_joint_id_rows: Array = (numeric_joint_id["state"] as Dictionary)["ordered_joint_observations"]
	(numeric_joint_id_rows[0] as Dictionary)["joint_id"] = 1
	(numeric_joint_id["state"] as Dictionary)["ordered_joint_observations"] = numeric_joint_id_rows
	mutations.append(
		{
			"model": model,
			"observation": numeric_joint_id,
			"expected": "QSDK_R10F_COMPACT_GEOMETRY_ANCHOR_MEASUREMENT_INVALID"
		}
	)

	var mutation_receipts: Array = []
	var rejection_count := 0
	for mutation_value in mutations:
		var mutation: Dictionary = mutation_value
		var refusal := _joint_geometry_summary_v2(mutation["model"], mutation["observation"])
		var refused_exactly := (
			not bool(refusal.get("ok", false))
			and String(refusal.get("failure_code", "")) == String(mutation["expected"])
			and not (refusal.get("failed_fields", []) as Array).is_empty()
			and not bool(refusal.get("axis_child_local_required", true))
			and not bool(refusal.get("axis_child_local_consumed", true))
		)
		if refused_exactly:
			rejection_count += 1
		(
			mutation_receipts
			. append(
				{
					"expected_failure_code": mutation["expected"],
					"observed_failure_code": refusal.get("failure_code"),
					"refused_exactly": refused_exactly,
				}
			)
		)

	for node_value in fixture["detached_nodes"]:
		(node_value as Node).free()
	return {
		"schema_version": "sporespore_qsdk_r10f_joint_geometry_zero_world_controls_v1",
		"gate_id": GATE_ID,
		"ok":
		(
			bool(positive.get("ok", false))
			and int(positive.get("joint_count", -1)) == LocomotionFacade.JOINT_IDS.size()
			and is_equal_approx(float(positive.get("maximum_anchor_error_m", NAN)), 0.008)
			and is_zero_approx(float(positive.get("maximum_hinge_axis_error_rad", NAN)))
			and not bool(positive.get("axis_child_local_required", true))
			and not bool(positive.get("axis_child_local_consumed", true))
			and bool(positive.get("source_measurement", false))
			and not bool(positive.get("outcome_derived_correction", true))
			and bool(axis_canary.get("ok", false))
			and float(axis_canary.get("maximum_hinge_axis_error_rad", NAN)) > 0.12
			and float(axis_canary.get("maximum_hinge_axis_error_rad", NAN)) < 0.13
			and rejection_count == mutations.size()
		),
		"producer_schema": String(model.get("schema_version", "")),
		"consumer_schema": String(positive.get("schema_version", "")),
		"exact_producer_shape_without_child_axis_accepted": bool(positive.get("ok", false)),
		"source_anchor_measurement_maximum_m": positive.get("maximum_anchor_error_m"),
		"shared_planar_axis_measurement_canary_rad":
		axis_canary.get("maximum_hinge_axis_error_rad"),
		"mutation_rejection_count": rejection_count,
		"mutation_receipts": mutation_receipts,
		"detached_body_node_count": int(fixture["detached_body_node_count"]),
		"detached_joint_node_count": int(fixture["detached_joint_node_count"]),
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func zero_world_contract_v3(sdk: Object, context: Dictionary) -> Dictionary:
	var predecessor := zero_world_contract_v2(sdk, context)
	var geometry_controls := _joint_geometry_zero_world_controls_v1(sdk, context)
	var result: Dictionary = predecessor.duplicate(true)
	result["schema_version"] = "sporespore_qsdk_r10f_worker_zero_world_contract_v3"
	result["ok"] = (bool(predecessor.get("ok", false)) and bool(geometry_controls.get("ok", false)))
	result["predecessor_contract_schema_version"] = String(predecessor.get("schema_version", ""))
	result["joint_geometry_source_shape_controls"] = geometry_controls
	result["joint_geometry_source_shape_control_count"] = 1
	result["joint_geometry_mutation_rejection_count"] = int(
		geometry_controls.get("mutation_rejection_count", -1)
	)
	result["detached_geometry_body_node_count"] = int(
		geometry_controls.get("detached_body_node_count", -1)
	)
	result["detached_geometry_joint_node_count"] = int(
		geometry_controls.get("detached_joint_node_count", -1)
	)
	return result


static func _solver_counter_collection_fixture_v1(global_step: int) -> Dictionary:
	return {
		"schema_version": NativeEpochRoute.COLLECTION_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"epoch_mode": NativeEpochRoute.MODE_GLOBAL_ONLY,
		"global_semantic_step": global_step,
		"solver_step_count": global_step,
		"global_result": {"solver_step_count": global_step},
		"retained_global_collector_unchanged": true,
	}


static func _collection_solver_counter_zero_world_controls_v1() -> Dictionary:
	var step_one_fixture := _solver_counter_collection_fixture_v1(1)
	var step_two_fixture := _solver_counter_collection_fixture_v1(2)
	var step_one := _collection_solver_counter_projection_v1(step_one_fixture, 1)
	var step_two := _collection_solver_counter_projection_v1(step_two_fixture, 2)

	var mutations: Array = []
	var wrong_schema := step_two_fixture.duplicate(true)
	wrong_schema["schema_version"] = "forged_collection"
	(
		mutations
		. append(
			{
				"collection": wrong_schema,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_SHAPE_INVALID",
			}
		)
	)
	var wrong_gate := step_two_fixture.duplicate(true)
	wrong_gate["gate_id"] = "QSDK-R10"
	(
		mutations
		. append(
			{
				"collection": wrong_gate,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_SHAPE_INVALID",
			}
		)
	)
	var numeric_ok := step_two_fixture.duplicate(true)
	numeric_ok["ok"] = 1
	(
		mutations
		. append(
			{
				"collection": numeric_ok,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_SHAPE_INVALID",
			}
		)
	)
	var false_ok := step_two_fixture.duplicate(true)
	false_ok["ok"] = false
	(
		mutations
		. append(
			{
				"collection": false_ok,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_SHAPE_INVALID",
			}
		)
	)
	var rewritten_global := step_two_fixture.duplicate(true)
	rewritten_global["retained_global_collector_unchanged"] = false
	(
		mutations
		. append(
			{
				"collection": rewritten_global,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_SHAPE_INVALID",
			}
		)
	)
	var missing_global_result := step_two_fixture.duplicate(true)
	missing_global_result.erase("global_result")
	(
		mutations
		. append(
			{
				"collection": missing_global_result,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_SHAPE_INVALID",
			}
		)
	)
	(
		mutations
		. append(
			{
				"collection": step_one_fixture,
				"expected_global_step": 0,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_EXPECTED_STEP_INVALID",
			}
		)
	)
	var missing_counter := step_two_fixture.duplicate(true)
	missing_counter.erase("solver_step_count")
	(
		mutations
		. append(
			{
				"collection": missing_counter,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_TYPE_INVALID",
			}
		)
	)
	var boolean_counter := step_two_fixture.duplicate(true)
	boolean_counter["solver_step_count"] = true
	(
		mutations
		. append(
			{
				"collection": boolean_counter,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_TYPE_INVALID",
			}
		)
	)
	var floating_counter := step_two_fixture.duplicate(true)
	floating_counter["solver_step_count"] = 2.0
	(
		mutations
		. append(
			{
				"collection": floating_counter,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_TYPE_INVALID",
			}
		)
	)
	var textual_counter := step_two_fixture.duplicate(true)
	textual_counter["solver_step_count"] = "2"
	(
		mutations
		. append(
			{
				"collection": textual_counter,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_TYPE_INVALID",
			}
		)
	)
	var floating_global_step := step_two_fixture.duplicate(true)
	floating_global_step["global_semantic_step"] = 2.0
	(
		mutations
		. append(
			{
				"collection": floating_global_step,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_TYPE_INVALID",
			}
		)
	)
	var stale_counter := step_two_fixture.duplicate(true)
	stale_counter["solver_step_count"] = 1
	(stale_counter["global_result"] as Dictionary)["solver_step_count"] = 1
	(
		mutations
		. append(
			{
				"collection": stale_counter,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_SEQUENCE_INVALID",
			}
		)
	)
	var future_counter := step_two_fixture.duplicate(true)
	future_counter["solver_step_count"] = 3
	(future_counter["global_result"] as Dictionary)["solver_step_count"] = 3
	(
		mutations
		. append(
			{
				"collection": future_counter,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_SEQUENCE_INVALID",
			}
		)
	)
	var boolean_global_counter := step_two_fixture.duplicate(true)
	(boolean_global_counter["global_result"] as Dictionary)["solver_step_count"] = true
	(
		mutations
		. append(
			{
				"collection": boolean_global_counter,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_GLOBAL_BINDING_INVALID",
			}
		)
	)
	var mismatched_global_counter := step_two_fixture.duplicate(true)
	(mismatched_global_counter["global_result"] as Dictionary)["solver_step_count"] = 1
	(
		mutations
		. append(
			{
				"collection": mismatched_global_counter,
				"expected_global_step": 2,
				"expected": "QSDK_R10F_COLLECTION_SOLVER_COUNTER_GLOBAL_BINDING_INVALID",
			}
		)
	)

	var rejection_count := 0
	var mutation_receipts: Array = []
	for mutation_value in mutations:
		var mutation: Dictionary = mutation_value
		var refusal := _collection_solver_counter_projection_v1(
			mutation["collection"],
			int(mutation["expected_global_step"]),
		)
		var refused_exactly := (
			not bool(refusal.get("ok", false))
			and String(refusal.get("failure_code", "")) == String(mutation["expected"])
			and not (refusal.get("failed_fields", []) as Array).is_empty()
			and not bool(refusal.get("outcome_derived_correction", true))
		)
		if refused_exactly:
			rejection_count += 1
		(
			mutation_receipts
			. append(
				{
					"expected_failure_code": mutation["expected"],
					"observed_failure_code": refusal.get("failure_code"),
					"refused_exactly": refused_exactly,
				}
			)
		)
	return {
		"schema_version": "sporespore_qsdk_r10f_collection_solver_counter_zero_world_v1",
		"gate_id": GATE_ID,
		"ok":
		(
			bool(step_one.get("ok", false))
			and int(step_one.get("cumulative_solver_step_count", -1)) == 1
			and int(step_one.get("retained_global_cumulative_solver_step_count", -1)) == 1
			and int(step_one.get("completed_step_delta", -1)) == 1
			and bool(step_two.get("ok", false))
			and int(step_two.get("cumulative_solver_step_count", -1)) == 2
			and int(step_two.get("retained_global_cumulative_solver_step_count", -1)) == 2
			and int(step_two.get("completed_step_delta", -1)) == 1
			and (
				(
					int(step_one.get("completed_step_delta", -1))
					+ int(step_two.get("completed_step_delta", -1))
				)
				== 2
			)
			and bool(step_one.get("source_measurement", false))
			and bool(step_two.get("source_measurement", false))
			and not bool(step_one.get("outcome_derived_correction", true))
			and not bool(step_two.get("outcome_derived_correction", true))
			and rejection_count == mutations.size()
		),
		"consecutive_positive_projection_count": 2,
		"accepted_completed_step_delta_sum":
		(
			int(step_one.get("completed_step_delta", -1))
			+ int(step_two.get("completed_step_delta", -1))
		),
		"terminal_cumulative_solver_step_count": step_two.get("cumulative_solver_step_count"),
		"mutation_rejection_count": rejection_count,
		"mutation_receipts": mutation_receipts,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func zero_world_contract_v4(sdk: Object, context: Dictionary) -> Dictionary:
	var predecessor := zero_world_contract_v3(sdk, context)
	var counter_controls := _collection_solver_counter_zero_world_controls_v1()
	var result: Dictionary = predecessor.duplicate(true)
	result["schema_version"] = "sporespore_qsdk_r10f_worker_zero_world_contract_v4"
	result["ok"] = (bool(predecessor.get("ok", false)) and bool(counter_controls.get("ok", false)))
	result["predecessor_contract_schema_version"] = String(predecessor.get("schema_version", ""))
	result["collection_solver_counter_controls"] = counter_controls
	result["collection_solver_counter_consecutive_positive_count"] = int(
		counter_controls.get("consecutive_positive_projection_count", -1)
	)
	result["collection_solver_counter_mutation_rejection_count"] = int(
		counter_controls.get("mutation_rejection_count", -1)
	)
	return result


static func _precondition_pair_terminal_advance_fixture_v1(
	arm_id: String,
	global_step: int,
) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10f_l6_zero_world_recovery_advance_v1",
		"ok": true,
		"terminal": true,
		"step_receipt":
		{
			"schema_version": "sporespore_qsdk_r10f_l6_zero_world_recovery_step_v1",
			"arm_id": arm_id,
			"global_semantic_step": global_step,
			"memory": {"phase": "complete"},
		},
		"next_memory": {"phase": "complete"},
		"control_receipt": null,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _precondition_pair_classification_fixture_v1(arm_id: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10f_l6_zero_world_stance_classification_v1",
		"arm_id": arm_id,
		"stable_stance_gate": true,
		"source_measurement": true,
	}


static func _precondition_pair_planned_state_fixture_v1(
	sdk: Object,
	ready_arm_ids: Array,
) -> Dictionary:
	var initialized := (
		PreconditionPairBarrier
		. initialize_v1(
			sdk,
			"r10f-l6-worker-application-zero-world",
			{
				EnergyInitializer.BASELINE_ARM_ID: "r10f-l6-zero-world-baseline-model",
				EnergyInitializer.ACTIVE_ARM_ID: "r10f-l6-zero-world-active-model",
			},
		)
	)
	if not bool(initialized.get("ok", false)):
		return initialized
	var state: Dictionary = initialized["state"]
	for arm_id_value in ready_arm_ids:
		var arm_id := String(arm_id_value)
		var source_build := (
			PreconditionPairBarrier
			. build_terminal_source_v1(
				sdk,
				state,
				arm_id,
				1,
				RECOVERY_CONTROLLER_ID,
				_precondition_pair_terminal_advance_fixture_v1(arm_id, 1),
				_precondition_pair_classification_fixture_v1(arm_id),
			)
		)
		if not bool(source_build.get("ok", false)):
			return source_build
		var observed := (
			PreconditionPairBarrier
			. observe_terminal_v1(
				sdk,
				state,
				source_build["source"],
			)
		)
		if not bool(observed.get("ok", false)):
			return observed
		state = observed["state_after"]
	for arm_id_value in ARM_ORDER:
		var arm_id := String(arm_id_value)
		var completed := (
			PreconditionPairBarrier
			. complete_planned_action_v1(
				sdk,
				state,
				arm_id,
				1,
				PreconditionPairBarrier.ACTION_RECOVERY,
				"sha256:" + ("a" if arm_id == EnergyInitializer.ACTIVE_ARM_ID else "b").repeat(64),
			)
		)
		if not bool(completed.get("ok", false)):
			return completed
		state = completed["state_after"]
	var planned := PreconditionPairBarrier.plan_next_frame_v1(sdk, state, 1)
	if not bool(planned.get("ok", false)):
		return planned
	return {
		"ok": true,
		"state": (planned["state_after"] as Dictionary).duplicate(true),
	}


static func _precondition_pair_motor_configuration_fixture_v1(global_step: int) -> Dictionary:
	var rows: Array = []
	for joint_id_value in LocomotionFacade.JOINT_IDS:
		(
			rows
			. append(
				{
					"joint_id": String(joint_id_value),
					"motor_enabled": false,
					"motor_target_velocity_rad_s": 0.0,
				}
			)
		)
	return {
		"schema_version": "sporespore_qsdk_r10f_recovery_native_motor_configuration_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"global_semantic_step": global_step,
		"reason": "l6_zero_world_motors_disabled",
		"motor_enabled": false,
		"ordered_joint_receipts": rows,
		"motor_configuration_write_count": LocomotionFacade.JOINT_IDS.size() * 2,
		"body_transform_write_count": 0,
		"body_velocity_write_count": 0,
		"body_impulse_write_count": 0,
		"solver_reset_count": 0,
		"physics_state_modified": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _precondition_pair_motor_readback_fixture_v1(global_step: int) -> Dictionary:
	var rows: Array = []
	for index in range(LocomotionFacade.JOINT_IDS.size()):
		(
			rows
			. append(
				{
					"actuator_id": String(NativeWorldScript.ORDERED_ACTUATOR_IDS[index]),
					"joint_id": String(LocomotionFacade.JOINT_IDS[index]),
					"motor_enabled": false,
					"motor_target_velocity_rad_s": 0.0,
					"motor_maximum_impulse_nms": 0.5,
				}
			)
		)
	return {
		"schema_version": "sporespore_qsdk_r10f_recovery_native_motor_population_readback_v1",
		"gate_id": GATE_ID,
		"ok": true,
		"global_semantic_step": global_step,
		"reason": "l6_zero_world_pre_solver_readback",
		"expected_motor_enabled": false,
		"ordered_joint_readbacks": rows,
		"motor_enabled_count": 0,
		"zero_target_velocity_count": LocomotionFacade.JOINT_IDS.size(),
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


static func _precondition_pair_application_fixture_v1(
	sdk: Object,
	pair_state: Dictionary,
	arm_id: String,
	action: String,
) -> Dictionary:
	var global_step := int(pair_state.get("planned_global_semantic_step", -1))
	var configuration := _precondition_pair_motor_configuration_fixture_v1(global_step)
	var readback := _precondition_pair_motor_readback_fixture_v1(global_step)
	var plan: Dictionary = pair_state.get("current_plan", {})
	var ledger := (
		LocomotionFacade
		. no_actuation_ledger_application_intent_v1(
			sdk,
			global_step,
			Orchestrator.PHASE_PRECONDITION_RECOVERY,
			"none",
			null,
			true,
			plan,
			readback,
		)
	)
	if not bool(ledger.get("ok", false)):
		return ledger
	return _build_precondition_pair_barrier_application_projection_v1(
		sdk,
		pair_state,
		arm_id,
		global_step,
		action,
		configuration,
		readback,
		ledger,
	)


static func _precondition_pair_application_zero_world_controls_v1(sdk: Object) -> Dictionary:
	var wait_state_build := _precondition_pair_planned_state_fixture_v1(
		sdk,
		[EnergyInitializer.BASELINE_ARM_ID],
	)
	var release_state_build := _precondition_pair_planned_state_fixture_v1(
		sdk,
		[EnergyInitializer.BASELINE_ARM_ID, EnergyInitializer.ACTIVE_ARM_ID],
	)
	if (
		not bool(wait_state_build.get("ok", false))
		or not bool(release_state_build.get("ok", false))
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L6_APPLICATION_STATE_FIXTURE_INVALID",
			"wait_state": wait_state_build,
			"release_state": release_state_build,
		}
	var wait_state: Dictionary = wait_state_build["state"]
	var release_state: Dictionary = release_state_build["state"]
	var wait_application := _precondition_pair_application_fixture_v1(
		sdk,
		wait_state,
		EnergyInitializer.BASELINE_ARM_ID,
		PreconditionPairBarrier.ACTION_WAIT,
	)
	var release_application := _precondition_pair_application_fixture_v1(
		sdk,
		release_state,
		EnergyInitializer.ACTIVE_ARM_ID,
		PreconditionPairBarrier.ACTION_RELEASE,
	)
	var wait_positive := (
		precondition_pair_barrier_application_retained_valid_v1(sdk, wait_application)
		and precondition_pair_barrier_application_valid_v1(
			sdk,
			wait_application,
			wait_state,
			EnergyInitializer.BASELINE_ARM_ID,
			2,
			PreconditionPairBarrier.ACTION_WAIT,
		)
	)
	var release_positive := (
		precondition_pair_barrier_application_retained_valid_v1(sdk, release_application)
		and precondition_pair_barrier_application_valid_v1(
			sdk,
			release_application,
			release_state,
			EnergyInitializer.ACTIVE_ARM_ID,
			2,
			PreconditionPairBarrier.ACTION_RELEASE,
		)
	)
	var controls := {}
	var enabled_motor := wait_application.duplicate(true)
	(enabled_motor["ordered_motor_readbacks"] as Array)[0]["motor_enabled"] = true
	enabled_motor["payload_sha256"] = _payload_sha256_static_v1(sdk, enabled_motor)
	controls["enabled_motor_wait_refused"] = (
		not precondition_pair_barrier_application_retained_valid_v1(sdk, enabled_motor)
		and not precondition_pair_barrier_application_valid_v1(
			sdk,
			enabled_motor,
			wait_state,
			EnergyInitializer.BASELINE_ARM_ID,
			2,
			PreconditionPairBarrier.ACTION_WAIT,
		)
	)
	var nonzero_target := wait_application.duplicate(true)
	(nonzero_target["ordered_motor_readbacks"] as Array)[0]["motor_target_velocity_rad_s"] = 0.1
	nonzero_target["payload_sha256"] = _payload_sha256_static_v1(sdk, nonzero_target)
	controls["nonzero_target_velocity_wait_refused"] = (
		not precondition_pair_barrier_application_retained_valid_v1(sdk, nonzero_target)
		and not precondition_pair_barrier_application_valid_v1(
			sdk,
			nonzero_target,
			wait_state,
			EnergyInitializer.BASELINE_ARM_ID,
			2,
			PreconditionPairBarrier.ACTION_WAIT,
		)
	)
	var actuation_owned := wait_application.duplicate(true)
	actuation_owned["control_owner"] = "recovery_v6"
	actuation_owned["actuation_owner"] = "recovery_v6"
	actuation_owned["no_actuation_requested"] = false
	actuation_owned["payload_sha256"] = _payload_sha256_static_v1(sdk, actuation_owned)
	controls["actuation_owned_wait_refused"] = (
		not precondition_pair_barrier_application_retained_valid_v1(sdk, actuation_owned)
		and not precondition_pair_barrier_application_valid_v1(
			sdk,
			actuation_owned,
			wait_state,
			EnergyInitializer.BASELINE_ARM_ID,
			2,
			PreconditionPairBarrier.ACTION_WAIT,
		)
	)
	var rejection_count := 0
	for control_value in controls.values():
		if bool(control_value):
			rejection_count += 1
	return {
		"schema_version": "sporespore_qsdk_r10f_l6_precondition_pair_application_zero_world_v1",
		"gate_id": GATE_ID,
		"repair_id": PreconditionPairBarrier.REPAIR_ID,
		"ok": wait_positive and release_positive and rejection_count == controls.size(),
		"positive_application_control_count": int(wait_positive) + int(release_positive),
		"mutation_rejection_count": rejection_count,
		"controls": controls,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func zero_world_contract_v5(sdk: Object, context: Dictionary) -> Dictionary:
	var predecessor := zero_world_contract_v4(sdk, context)
	var pair_controls := PreconditionPairBarrier.zero_world_contract_v1(sdk)
	var application_controls := _precondition_pair_application_zero_world_controls_v1(sdk)
	var result: Dictionary = predecessor.duplicate(true)
	result["schema_version"] = "sporespore_qsdk_r10f_worker_zero_world_contract_v5"
	result["ok"] = (
		bool(predecessor.get("ok", false))
		and bool(pair_controls.get("ok", false))
		and bool(application_controls.get("ok", false))
	)
	result["predecessor_contract_schema_version"] = String(predecessor.get("schema_version", ""))
	result["precondition_pair_barrier_controls"] = pair_controls
	result["precondition_pair_barrier_positive_sequence_control_count"] = int(
		pair_controls.get("positive_sequence_control_count", -1)
	)
	result["precondition_pair_barrier_source_mutation_rejection_count"] = int(
		pair_controls.get("mutation_rejection_count", -1)
	)
	result["precondition_pair_application_controls"] = application_controls
	result["precondition_pair_application_positive_control_count"] = int(
		application_controls.get("positive_application_control_count", -1)
	)
	result["precondition_pair_application_mutation_rejection_count"] = int(
		application_controls.get("mutation_rejection_count", -1)
	)
	result["precondition_pair_required_mutation_rejection_count"] = (
		int(pair_controls.get("mutation_rejection_count", -1))
		+ int(application_controls.get("mutation_rejection_count", -1))
	)
	return result


static func zero_world_contract_v6(sdk: Object, context: Dictionary) -> Dictionary:
	var predecessor := zero_world_contract_v5(sdk, context)
	var disposition_controls := PreconditionTerminalDisposition.zero_world_contract_v1(sdk)
	var result: Dictionary = predecessor.duplicate(true)
	result["schema_version"] = "sporespore_qsdk_r10f_worker_zero_world_contract_v6"
	result["ok"] = (
		bool(predecessor.get("ok", false)) and bool(disposition_controls.get("ok", false))
	)
	result["predecessor_contract_schema_version"] = String(predecessor.get("schema_version", ""))
	result["precondition_terminal_disposition_controls"] = disposition_controls
	result["precondition_terminal_disposition_positive_control_count"] = int(
		disposition_controls.get("positive_control_count", -1)
	)
	result["precondition_terminal_disposition_mutation_rejection_count"] = int(
		disposition_controls.get("mutation_rejection_count", -1)
	)
	return result


static func zero_world_contract_v7(sdk: Object, context: Dictionary) -> Dictionary:
	var predecessor := zero_world_contract_v6(sdk, context)
	var step_domain := PreconditionTerminalDisposition.integer_valued_native_step_zero_world_v1(sdk)
	var legacy_positive_retained := (
		bool(predecessor.get("ok", false))
		and (
			int(predecessor.get("precondition_terminal_disposition_positive_control_count", -1))
			== 6
		)
	)
	var legacy_negative_retained := (
		bool(predecessor.get("ok", false))
		and (
			int(predecessor.get("precondition_terminal_disposition_mutation_rejection_count", -1))
			== 16
		)
	)
	var result: Dictionary = predecessor.duplicate(true)
	result["schema_version"] = "sporespore_qsdk_r10f_worker_zero_world_contract_v7"
	result["ok"] = (
		bool(predecessor.get("ok", false))
		and bool(step_domain.get("ok", false))
		and legacy_positive_retained
		and legacy_negative_retained
	)
	result["predecessor_contract_schema_version"] = String(predecessor.get("schema_version", ""))
	result["integer_valued_native_step_domain_controls"] = step_domain
	result["integer_valued_native_step_domain_positive_controls"] = {
		"focused_domain_controls": int(step_domain.get("positive_control_count", -1)) == 5,
		"all_existing_l7_terminal_disposition_positive_controls_still_pass":
		legacy_positive_retained,
	}
	result["integer_valued_native_step_domain_negative_controls"] = {
		"focused_domain_controls": int(step_domain.get("mutation_rejection_count", -1)) == 15,
		"all_existing_l7_terminal_disposition_negative_controls_still_pass":
		legacy_negative_retained,
	}
	result["integer_valued_native_step_domain_positive_control_count"] = (
		int(step_domain.get("positive_control_count", -1)) + int(legacy_positive_retained)
	)
	result["integer_valued_native_step_domain_mutation_rejection_count"] = (
		int(step_domain.get("mutation_rejection_count", -1)) + int(legacy_negative_retained)
	)
	return result


static func zero_world_contract_v8(sdk: Object, context: Dictionary) -> Dictionary:
	var predecessor := zero_world_contract_v7(sdk, context)
	var child_contract := ProcessIsolatedChildContract.zero_world_contract_v1(sdk)
	var result: Dictionary = predecessor.duplicate(true)
	result["schema_version"] = "sporespore_qsdk_r10f_worker_zero_world_contract_v8"
	result["ok"] = (
		bool(predecessor.get("ok", false))
		and bool(child_contract.get("ok", false))
		and int(child_contract.get("positive_case_count", -1)) == 8
		and int(child_contract.get("mutation_rejection_count", -1)) == 31
		and bool(child_contract.get("one_arm_per_process", false))
		and bool(child_contract.get("one_world_per_process", false))
		and int(child_contract.get("model_construction_count", -1)) == 0
		and int(child_contract.get("world_attempt_count", -1)) == 0
		and int(child_contract.get("world_build_count", -1)) == 0
		and int(child_contract.get("scene_tree_insertion_count", -1)) == 0
		and int(child_contract.get("native_readback_count", -1)) == 0
		and int(child_contract.get("solver_step_count", -1)) == 0
		and not bool(child_contract.get("physics_state_modified", true))
		and not bool(child_contract.get("physical_acceptance_authority", true))
		and not bool(child_contract.get("release_authority", true))
	)
	result["predecessor_contract_schema_version"] = String(predecessor.get("schema_version", ""))
	result["process_isolated_child_contract"] = child_contract
	result["process_isolated_child_positive_case_count"] = int(
		child_contract.get("positive_case_count", -1)
	)
	result["process_isolated_child_mutation_rejection_count"] = int(
		child_contract.get("mutation_rejection_count", -1)
	)
	result["one_authorized_arm_per_child_process"] = bool(
		child_contract.get("one_arm_per_process", false)
	)
	result["one_native_world_per_child_process"] = bool(
		child_contract.get("one_world_per_process", false)
	)
	result["failed_or_refused_precondition_is_valid_diagnostic_evidence"] = bool(
		child_contract.get("failed_or_refused_precondition_is_valid_diagnostic_evidence", false)
	)
	result["failed_or_refused_precondition_crosses_release_boundary"] = bool(
		child_contract.get("failed_or_refused_precondition_crosses_release_boundary", true)
	)
	result["maximum_solver_steps_per_child"] = MAXIMUM_CHILD_SOLVER_STEPS
	result["maximum_total_solver_steps"] = MAXIMUM_CHILD_SOLVER_STEPS * 2
	return result


static func zero_world_contract_v9(sdk: Object, context: Dictionary) -> Dictionary:
	var predecessor := zero_world_contract_v8(sdk, context)
	var nullable_failure_code := (
		ProcessIsolatedChildContract.nullable_terminal_failure_code_zero_world_v1(sdk)
	)
	var legacy_positive_retained := (
		bool(predecessor.get("ok", false))
		and int(predecessor.get("process_isolated_child_positive_case_count", -1)) == 8
	)
	var legacy_negative_retained := (
		bool(predecessor.get("ok", false))
		and int(predecessor.get("process_isolated_child_mutation_rejection_count", -1)) == 31
	)
	var result: Dictionary = predecessor.duplicate(true)
	result["schema_version"] = "sporespore_qsdk_r10f_worker_zero_world_contract_v9"
	result["ok"] = (
		bool(predecessor.get("ok", false))
		and bool(nullable_failure_code.get("ok", false))
		and int(nullable_failure_code.get("positive_control_count", -1)) == 6
		and int(nullable_failure_code.get("mutation_rejection_count", -1)) == 16
		and legacy_positive_retained
		and legacy_negative_retained
	)
	result["predecessor_contract_schema_version"] = String(predecessor.get("schema_version", ""))
	result["nullable_terminal_failure_code_controls"] = nullable_failure_code
	result["nullable_terminal_failure_code_positive_controls"] = {
		"focused_nullable_source_controls":
		int(nullable_failure_code.get("positive_control_count", -1)) == 6,
		"all_existing_l9_process_isolated_child_positive_controls_still_pass":
		legacy_positive_retained,
	}
	result["nullable_terminal_failure_code_negative_controls"] = {
		"focused_nullable_source_controls":
		int(nullable_failure_code.get("mutation_rejection_count", -1)) == 16,
		"all_existing_l9_process_isolated_child_negative_controls_still_pass":
		legacy_negative_retained,
	}
	result["nullable_terminal_failure_code_positive_control_count"] = (
		int(nullable_failure_code.get("positive_control_count", -1)) + int(legacy_positive_retained)
	)
	result["nullable_terminal_failure_code_mutation_rejection_count"] = (
		int(nullable_failure_code.get("mutation_rejection_count", -1))
		+ int(legacy_negative_retained)
	)
	return result


static func zero_world_contract_v10(sdk: Object, context: Dictionary) -> Dictionary:
	var predecessor := zero_world_contract_v9(sdk, context)
	var release_owner_source := (
		ProcessIsolatedChildContract.precondition_release_owner_source_zero_world_v1(sdk)
	)
	var l10_positive_retained := (
		bool(predecessor.get("ok", false))
		and int(predecessor.get("nullable_terminal_failure_code_positive_control_count", -1)) == 7
	)
	var l10_negative_retained := (
		bool(predecessor.get("ok", false))
		and (
			int(predecessor.get("nullable_terminal_failure_code_mutation_rejection_count", -1))
			== 17
		)
	)
	var result: Dictionary = predecessor.duplicate(true)
	result["schema_version"] = "sporespore_qsdk_r10f_worker_zero_world_contract_v10"
	result["repair_id"] = REPAIR_ID
	result["ok"] = (
		bool(predecessor.get("ok", false))
		and bool(release_owner_source.get("ok", false))
		and int(release_owner_source.get("positive_control_count", -1)) == 8
		and int(release_owner_source.get("mutation_rejection_count", -1)) == 22
		and l10_positive_retained
		and l10_negative_retained
	)
	result["predecessor_contract_schema_version"] = String(predecessor.get("schema_version", ""))
	result["precondition_release_owner_source_controls"] = release_owner_source
	result["precondition_release_owner_source_positive_controls"] = {
		"focused_release_owner_source_controls":
		int(release_owner_source.get("positive_control_count", -1)) == 8,
		"all_existing_l10_nullable_terminal_positive_controls_still_pass": l10_positive_retained,
	}
	result["precondition_release_owner_source_negative_controls"] = {
		"focused_release_owner_source_controls":
		int(release_owner_source.get("mutation_rejection_count", -1)) == 22,
		"all_existing_l10_nullable_terminal_negative_controls_still_pass": l10_negative_retained,
	}
	result["precondition_release_owner_source_positive_control_count"] = (
		int(release_owner_source.get("positive_control_count", -1)) + int(l10_positive_retained)
	)
	result["precondition_release_owner_source_mutation_rejection_count"] = (
		int(release_owner_source.get("mutation_rejection_count", -1)) + int(l10_negative_retained)
	)
	result["precondition_release_component_schema_version"] = (
		ProcessIsolatedChildContract.RELEASE_SCHEMA
	)
	result["broad_no_actuation_outcome_guard_changed"] = false
	return result


static func _walking_actuation_handoff_fixture_v1(
	sdk: Object,
	evaluation_segment_id: String,
	global_semantic_step: int,
) -> Dictionary:
	var cap_binding := LocomotionFacade.walking_host_cap_projection_binding_v1(sdk)
	if not bool(cap_binding.get("ok", false)):
		return cap_binding
	var facade_segment_id := (
		"walking_prefix" if evaluation_segment_id == "walking_prefix" else "walking_resume"
	)
	var reason := "l12_walking_actuation_handoff_precommand:%s" % evaluation_segment_id
	var configuration_rows: Array = []
	var readback_rows: Array = []
	var selected_caps: Dictionary = cap_binding["selected_host_cap_by_actuator_id"]
	for index in range(LocomotionFacade.JOINT_IDS.size()):
		var joint_id := String(LocomotionFacade.JOINT_IDS[index])
		var actuator_id := String(NativeWorldScript.ORDERED_ACTUATOR_IDS[index])
		(
			configuration_rows
			. append(
				{
					"joint_id": joint_id,
					"motor_enabled": true,
					"motor_target_velocity_rad_s": 0.0,
				}
			)
		)
		(
			readback_rows
			. append(
				{
					"actuator_id": actuator_id,
					"joint_id": joint_id,
					"motor_enabled": true,
					"motor_target_velocity_rad_s": 0.0,
					"motor_maximum_impulse_nms": float(selected_caps[actuator_id]),
				}
			)
		)
	var configuration := {
		"schema_version": LocomotionFacade.MOTOR_CONFIGURATION_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"global_semantic_step": global_semantic_step,
		"reason": reason,
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
	var readback := {
		"schema_version": LocomotionFacade.MOTOR_POPULATION_READBACK_SCHEMA,
		"gate_id": GATE_ID,
		"ok": true,
		"global_semantic_step": global_semantic_step,
		"reason": reason,
		"expected_motor_enabled": true,
		"ordered_joint_readbacks": readback_rows,
		"motor_enabled_count": LocomotionFacade.JOINT_IDS.size(),
		"zero_target_velocity_count": LocomotionFacade.JOINT_IDS.size(),
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
	var model_instance_id := "r10f-l12-zero-world-model:%s" % evaluation_segment_id
	var session_id := "r10f-l12-zero-world-session:%s" % evaluation_segment_id
	var handoff := (
		LocomotionFacade
		. walking_actuation_handoff_receipt_v1(
			sdk,
			model_instance_id,
			facade_segment_id,
			evaluation_segment_id,
			session_id,
			global_semantic_step,
			configuration,
			readback,
			cap_binding,
		)
	)
	return {
		"ok": bool(handoff.get("ok", false)),
		"model_instance_id": model_instance_id,
		"facade_segment_id": facade_segment_id,
		"evaluation_segment_id": evaluation_segment_id,
		"session_id": session_id,
		"global_semantic_step": global_semantic_step,
		"configuration": configuration,
		"readback": readback,
		"cap_binding": cap_binding,
		"handoff": handoff,
	}


static func _walking_actuation_handoff_zero_world_controls_v1(sdk: Object) -> Dictionary:
	var prefix := _walking_actuation_handoff_fixture_v1(sdk, "walking_prefix", 242)
	var continuation := _walking_actuation_handoff_fixture_v1(
		sdk,
		"matched_continuation",
		963,
	)
	var resume := _walking_actuation_handoff_fixture_v1(sdk, "walking_resume", 2164)
	if (
		not bool(prefix.get("ok", false))
		or not bool(continuation.get("ok", false))
		or not bool(resume.get("ok", false))
	):
		return {
			"ok": false,
			"failure_code": "QSDK_R10F_L12_HANDOFF_POSITIVE_FIXTURE_INVALID",
			"prefix": prefix,
			"continuation": continuation,
			"resume": resume,
		}
	var positive_controls := {
		"qualified_all_eight_host_cap_projection":
		(
			LocomotionFacade
			. walking_host_cap_projection_binding_valid_v1(
				sdk,
				prefix["cap_binding"],
			)
		),
		"walking_prefix_handoff":
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_valid_v1(
				sdk,
				prefix["handoff"],
			)
		),
		"matched_continuation_handoff":
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_valid_v1(
				sdk,
				continuation["handoff"],
			)
		),
		"walking_resume_handoff":
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_valid_v1(
				sdk,
				resume["handoff"],
			)
		),
	}
	var controls := {}
	var disabled_configuration: Dictionary = prefix["configuration"].duplicate(true)
	disabled_configuration["motor_enabled"] = false
	controls["disabled_configuration_refused"] = not bool(
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_v1(
				sdk,
				prefix["model_instance_id"],
				prefix["facade_segment_id"],
				prefix["evaluation_segment_id"],
				prefix["session_id"],
				prefix["global_semantic_step"],
				disabled_configuration,
				prefix["readback"],
				prefix["cap_binding"],
			)
			. get("ok", true)
		)
	)
	var disabled_configuration_row: Dictionary = prefix["configuration"].duplicate(true)
	(disabled_configuration_row["ordered_joint_receipts"] as Array)[0]["motor_enabled"] = false
	controls["disabled_configuration_row_refused"] = not bool(
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_v1(
				sdk,
				prefix["model_instance_id"],
				prefix["facade_segment_id"],
				prefix["evaluation_segment_id"],
				prefix["session_id"],
				prefix["global_semantic_step"],
				disabled_configuration_row,
				prefix["readback"],
				prefix["cap_binding"]
			)
			. get("ok", true)
		)
	)
	var nonzero_configuration: Dictionary = prefix["configuration"].duplicate(true)
	(nonzero_configuration["ordered_joint_receipts"] as Array)[0]["motor_target_velocity_rad_s"] = 0.125
	controls["nonzero_configuration_target_refused"] = not bool(
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_v1(
				sdk,
				prefix["model_instance_id"],
				prefix["facade_segment_id"],
				prefix["evaluation_segment_id"],
				prefix["session_id"],
				prefix["global_semantic_step"],
				nonzero_configuration,
				prefix["readback"],
				prefix["cap_binding"]
			)
			. get("ok", true)
		)
	)
	var disabled_readback: Dictionary = prefix["readback"].duplicate(true)
	(disabled_readback["ordered_joint_readbacks"] as Array)[0]["motor_enabled"] = false
	controls["disabled_readback_refused"] = not bool(
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_v1(
				sdk,
				prefix["model_instance_id"],
				prefix["facade_segment_id"],
				prefix["evaluation_segment_id"],
				prefix["session_id"],
				prefix["global_semantic_step"],
				prefix["configuration"],
				disabled_readback,
				prefix["cap_binding"]
			)
			. get("ok", true)
		)
	)
	var nonzero_readback: Dictionary = prefix["readback"].duplicate(true)
	(nonzero_readback["ordered_joint_readbacks"] as Array)[0]["motor_target_velocity_rad_s"] = 0.125
	controls["nonzero_readback_target_refused"] = not bool(
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_v1(
				sdk,
				prefix["model_instance_id"],
				prefix["facade_segment_id"],
				prefix["evaluation_segment_id"],
				prefix["session_id"],
				prefix["global_semantic_step"],
				prefix["configuration"],
				nonzero_readback,
				prefix["cap_binding"]
			)
			. get("ok", true)
		)
	)
	var published_as_host: Dictionary = prefix["readback"].duplicate(true)
	(published_as_host["ordered_joint_readbacks"] as Array)[0]["motor_maximum_impulse_nms"] = float(
		NativeWorldScript.ORDERED_PUBLISHED_CAPS_NMS[0]
	)
	controls["published_binary64_as_host_refused"] = not bool(
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_v1(
				sdk,
				prefix["model_instance_id"],
				prefix["facade_segment_id"],
				prefix["evaluation_segment_id"],
				prefix["session_id"],
				prefix["global_semantic_step"],
				prefix["configuration"],
				published_as_host,
				prefix["cap_binding"]
			)
			. get("ok", true)
		)
	)
	var arbitrary_lower_host: Dictionary = prefix["readback"].duplicate(true)
	(arbitrary_lower_host["ordered_joint_readbacks"] as Array)[0]["motor_maximum_impulse_nms"] = 0.05
	controls["arbitrary_lower_host_cap_refused"] = not bool(
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_v1(
				sdk,
				prefix["model_instance_id"],
				prefix["facade_segment_id"],
				prefix["evaluation_segment_id"],
				prefix["session_id"],
				prefix["global_semantic_step"],
				prefix["configuration"],
				arbitrary_lower_host,
				prefix["cap_binding"]
			)
			. get("ok", true)
		)
	)
	var adjacent_higher_host: Dictionary = prefix["readback"].duplicate(true)
	var first_projection: Dictionary = (
		prefix["cap_binding"]["ordered_projection_receipts"] as Array
	)[0]
	(adjacent_higher_host["ordered_joint_readbacks"] as Array)[0]["motor_maximum_impulse_nms"] = float(
		first_projection["next_binary32_host_maximum_impulse_nms"]
	)
	controls["adjacent_higher_host_cap_refused"] = not bool(
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_v1(
				sdk,
				prefix["model_instance_id"],
				prefix["facade_segment_id"],
				prefix["evaluation_segment_id"],
				prefix["session_id"],
				prefix["global_semantic_step"],
				prefix["configuration"],
				adjacent_higher_host,
				prefix["cap_binding"]
			)
			. get("ok", true)
		)
	)
	var missing_readback_row: Dictionary = prefix["readback"].duplicate(true)
	(missing_readback_row["ordered_joint_readbacks"] as Array).pop_back()
	controls["missing_readback_row_refused"] = not bool(
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_v1(
				sdk,
				prefix["model_instance_id"],
				prefix["facade_segment_id"],
				prefix["evaluation_segment_id"],
				prefix["session_id"],
				prefix["global_semantic_step"],
				prefix["configuration"],
				missing_readback_row,
				prefix["cap_binding"]
			)
			. get("ok", true)
		)
	)
	var reordered_readback: Dictionary = prefix["readback"].duplicate(true)
	var reordered_rows: Array = reordered_readback["ordered_joint_readbacks"]
	var first_row: Variant = reordered_rows[0]
	reordered_rows[0] = reordered_rows[1]
	reordered_rows[1] = first_row
	controls["reordered_readback_refused"] = not bool(
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_v1(
				sdk,
				prefix["model_instance_id"],
				prefix["facade_segment_id"],
				prefix["evaluation_segment_id"],
				prefix["session_id"],
				prefix["global_semantic_step"],
				prefix["configuration"],
				reordered_readback,
				prefix["cap_binding"]
			)
			. get("ok", true)
		)
	)
	var wrong_projection_id: Dictionary = prefix["cap_binding"].duplicate(true)
	wrong_projection_id["projection_id"] = "forged_projection"
	wrong_projection_id["payload_sha256"] = _payload_sha256_static_v1(sdk, wrong_projection_id)
	controls["wrong_projection_id_refused"] = not (
		LocomotionFacade.walking_host_cap_projection_binding_valid_v1(sdk, wrong_projection_id)
	)
	var wrong_projection_scope: Dictionary = prefix["cap_binding"].duplicate(true)
	wrong_projection_scope["scope"] = "arbitrary_morphology"
	wrong_projection_scope["payload_sha256"] = _payload_sha256_static_v1(
		sdk, wrong_projection_scope
	)
	controls["wrong_projection_scope_refused"] = not (
		LocomotionFacade.walking_host_cap_projection_binding_valid_v1(sdk, wrong_projection_scope)
	)
	var wrong_published_map: Dictionary = prefix["cap_binding"].duplicate(true)
	var published_map: Dictionary = wrong_published_map["published_cap_by_actuator_id"]
	published_map[String(NativeWorldScript.ORDERED_ACTUATOR_IDS[0])] = 0.5
	wrong_published_map["published_cap_by_actuator_id"] = published_map
	wrong_published_map["payload_sha256"] = _payload_sha256_static_v1(sdk, wrong_published_map)
	controls["wrong_published_cap_map_refused"] = not (
		LocomotionFacade.walking_host_cap_projection_binding_valid_v1(sdk, wrong_published_map)
	)
	var wrong_selected_map: Dictionary = prefix["cap_binding"].duplicate(true)
	var selected_map: Dictionary = wrong_selected_map["selected_host_cap_by_actuator_id"]
	selected_map[String(NativeWorldScript.ORDERED_ACTUATOR_IDS[0])] = 0.05
	wrong_selected_map["selected_host_cap_by_actuator_id"] = selected_map
	wrong_selected_map["payload_sha256"] = _payload_sha256_static_v1(sdk, wrong_selected_map)
	controls["wrong_selected_host_cap_map_refused"] = not (
		LocomotionFacade.walking_host_cap_projection_binding_valid_v1(sdk, wrong_selected_map)
	)
	var wrong_projection_row: Dictionary = prefix["cap_binding"].duplicate(true)
	var projection_rows: Array = wrong_projection_row["ordered_projection_receipts"]
	(projection_rows[0] as Dictionary)["native_effective_limit_not_above_published"] = false
	wrong_projection_row["ordered_projection_receipts"] = projection_rows
	wrong_projection_row["payload_sha256"] = _payload_sha256_static_v1(sdk, wrong_projection_row)
	controls["false_projection_safety_refused"] = not (
		LocomotionFacade.walking_host_cap_projection_binding_valid_v1(sdk, wrong_projection_row)
	)
	var missing_projection_row: Dictionary = prefix["cap_binding"].duplicate(true)
	(missing_projection_row["ordered_projection_receipts"] as Array).pop_back()
	missing_projection_row["payload_sha256"] = _payload_sha256_static_v1(
		sdk, missing_projection_row
	)
	controls["missing_projection_row_refused"] = not (
		LocomotionFacade.walking_host_cap_projection_binding_valid_v1(sdk, missing_projection_row)
	)
	controls["wrong_facade_segment_pair_refused"] = not bool(
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_v1(
				sdk,
				prefix["model_instance_id"],
				"walking_resume",
				"walking_prefix",
				prefix["session_id"],
				prefix["global_semantic_step"],
				prefix["configuration"],
				prefix["readback"],
				prefix["cap_binding"]
			)
			. get("ok", true)
		)
	)
	controls["wrong_semantic_step_refused"] = not bool(
		(
			LocomotionFacade
			. walking_actuation_handoff_receipt_v1(
				sdk,
				prefix["model_instance_id"],
				prefix["facade_segment_id"],
				prefix["evaluation_segment_id"],
				prefix["session_id"],
				243,
				prefix["configuration"],
				prefix["readback"],
				prefix["cap_binding"]
			)
			. get("ok", true)
		)
	)
	var outcome_injection: Dictionary = prefix["handoff"].duplicate(true)
	outcome_injection["physical_result"] = true
	outcome_injection["payload_sha256"] = _payload_sha256_static_v1(sdk, outcome_injection)
	controls["outcome_injection_refused"] = not (
		LocomotionFacade.walking_actuation_handoff_receipt_valid_v1(sdk, outcome_injection)
	)
	var authority_injection: Dictionary = prefix["handoff"].duplicate(true)
	authority_injection["release_authority"] = true
	authority_injection["payload_sha256"] = _payload_sha256_static_v1(sdk, authority_injection)
	controls["release_authority_refused"] = not (
		LocomotionFacade.walking_actuation_handoff_receipt_valid_v1(sdk, authority_injection)
	)
	var stale_digest: Dictionary = prefix["handoff"].duplicate(true)
	stale_digest["model_instance_id"] = "mutated-model"
	controls["stale_handoff_digest_refused"] = not (
		LocomotionFacade.walking_actuation_handoff_receipt_valid_v1(sdk, stale_digest)
	)
	var positive_count := 0
	for value in positive_controls.values():
		positive_count += int(bool(value))
	var rejection_count := 0
	for value in controls.values():
		rejection_count += int(bool(value))
	return {
		"schema_version": "sporespore_qsdk_r10f_l12_walking_actuation_handoff_zero_world_v1",
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok":
		(
			positive_count == positive_controls.size()
			and rejection_count == controls.size()
			and int((prefix["cap_binding"] as Dictionary).get("projection_count", -1)) == 8
		),
		"positive_controls": positive_controls,
		"positive_control_count": positive_count,
		"negative_controls": controls,
		"mutation_rejection_count": rejection_count,
		"r69_projection_count": int((prefix["cap_binding"] as Dictionary)["projection_count"]),
		"covered_evaluation_segments": ["walking_prefix", "matched_continuation", "walking_resume"],
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func zero_world_contract_v11(sdk: Object, context: Dictionary) -> Dictionary:
	var predecessor := zero_world_contract_v10(sdk, context)
	var handoff_controls := _walking_actuation_handoff_zero_world_controls_v1(sdk)
	var l11_positive_retained := (
		bool(predecessor.get("ok", false))
		and (
			int(predecessor.get("precondition_release_owner_source_positive_control_count", -1))
			== 9
		)
	)
	var l11_negative_retained := (
		bool(predecessor.get("ok", false))
		and (
			int(predecessor.get("precondition_release_owner_source_mutation_rejection_count", -1))
			== 23
		)
	)
	var result: Dictionary = predecessor.duplicate(true)
	result["schema_version"] = "sporespore_qsdk_r10f_worker_zero_world_contract_v11"
	result["repair_id"] = REPAIR_ID
	result["ok"] = (
		bool(predecessor.get("ok", false))
		and bool(handoff_controls.get("ok", false))
		and int(handoff_controls.get("positive_control_count", -1)) == 4
		and int(handoff_controls.get("mutation_rejection_count", -1)) == 21
		and l11_positive_retained
		and l11_negative_retained
	)
	result["predecessor_contract_schema_version"] = String(predecessor.get("schema_version", ""))
	result["walking_actuation_handoff_controls"] = handoff_controls
	result["walking_actuation_handoff_positive_controls"] = {
		"focused_handoff_controls": int(handoff_controls.get("positive_control_count", -1)) == 4,
		"all_existing_l11_release_owner_positive_controls_still_pass": l11_positive_retained,
	}
	result["walking_actuation_handoff_negative_controls"] = {
		"focused_handoff_controls": int(handoff_controls.get("mutation_rejection_count", -1)) == 21,
		"all_existing_l11_release_owner_negative_controls_still_pass": l11_negative_retained,
	}
	result["walking_actuation_handoff_positive_control_count"] = (
		int(handoff_controls.get("positive_control_count", -1)) + int(l11_positive_retained)
	)
	result["walking_actuation_handoff_mutation_rejection_count"] = (
		int(handoff_controls.get("mutation_rejection_count", -1)) + int(l11_negative_retained)
	)
	result["qualified_r69_projection_count"] = int(handoff_controls.get("r69_projection_count", -1))
	result["shared_adapter_motor_enable_behavior_changed"] = false
	result["published_actuator_cap_profile_changed"] = false
	result["walking_handoff_extra_solver_step_count"] = 0
	return result


static func _walking_failure_retention_zero_world_controls_v1() -> Dictionary:
	var source_keys := [
		"portable_step_receipt",
		"native_step_transport_verification",
		"controller_step_receipt",
		"authority_application_receipt",
		"motor_population_readback",
		"walking_actuation_handoff_receipt",
		"host_target_projection_receipt",
		"walking_ledger_predicate_receipt",
	]
	var failure := {
		"failed_predicate_ids": ["row.0.application_readback_equals_projection_exactly"],
		"generic_failure_without_predicate_detail": false,
	}
	for source_key in source_keys:
		failure[source_key] = {"source_id": source_key}
	var active_session := {
		"session_id": "r10f-l13-zero-world-session",
		"start_receipt": {"source_id": "walking_session_start"},
		"walking_actuation_handoff_receipt": {"source_id": "walking_handoff"},
	}
	var arm := {
		"active_walking_session": active_session,
		"last_walking_step_failure": failure,
	}
	var projection := partial_arm_failure_retention_projection_v1(
		arm,
		EnergyInitializer.BASELINE_ARM_ID,
	)
	var negative_controls := {}
	for top_level_key in ["active_walking_session", "last_walking_step_failure"]:
		var mutation: Dictionary = projection.duplicate(true)
		mutation.erase(top_level_key)
		negative_controls["missing_%s_refused" % top_level_key] = not (partial_walking_failure_retention_valid_v1(
			mutation
		))
	for session_key in ["session_id", "start_receipt", "walking_actuation_handoff_receipt"]:
		var mutation: Dictionary = projection.duplicate(true)
		var mutated_session: Dictionary = mutation["active_walking_session"]
		mutated_session.erase(session_key)
		mutation["active_walking_session"] = mutated_session
		negative_controls["missing_session_%s_refused" % session_key] = not (partial_walking_failure_retention_valid_v1(
			mutation
		))
	for source_key in source_keys:
		var mutation: Dictionary = projection.duplicate(true)
		var mutated_failure: Dictionary = mutation["last_walking_step_failure"]
		mutated_failure.erase(source_key)
		mutation["last_walking_step_failure"] = mutated_failure
		negative_controls["missing_failure_%s_refused" % source_key] = not (partial_walking_failure_retention_valid_v1(
			mutation
		))
	var unnamed_failure: Dictionary = projection.duplicate(true)
	(unnamed_failure["last_walking_step_failure"] as Dictionary)["failed_predicate_ids"] = []
	negative_controls["unnamed_failure_refused"] = not (partial_walking_failure_retention_valid_v1(
		unnamed_failure
	))
	var generic_failure: Dictionary = projection.duplicate(true)
	(generic_failure["last_walking_step_failure"] as Dictionary)["generic_failure_without_predicate_detail"] = true
	negative_controls["generic_failure_refused"] = not (partial_walking_failure_retention_valid_v1(
		generic_failure
	))
	var rejection_count := 0
	for value in negative_controls.values():
		rejection_count += int(bool(value))
	return {
		"schema_version":
		"sporespore_qsdk_r10f_l13_partial_walking_failure_retention_zero_world_v1",
		"gate_id": GATE_ID,
		"repair_id": REPAIR_ID,
		"ok":
		(
			partial_walking_failure_retention_valid_v1(projection)
			and rejection_count == negative_controls.size()
		),
		"positive_control": projection,
		"positive_control_count": int(partial_walking_failure_retention_valid_v1(projection)),
		"negative_controls": negative_controls,
		"mutation_rejection_count": rejection_count,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func zero_world_contract_v12(sdk: Object, context: Dictionary) -> Dictionary:
	var predecessor := zero_world_contract_v11(sdk, context)
	var retention_controls := _walking_failure_retention_zero_world_controls_v1()
	var result: Dictionary = predecessor.duplicate(true)
	result["schema_version"] = "sporespore_qsdk_r10f_worker_zero_world_contract_v12"
	result["repair_id"] = REPAIR_ID
	result["ok"] = (
		bool(predecessor.get("ok", false))
		and bool(retention_controls.get("ok", false))
		and int(retention_controls.get("positive_control_count", -1)) == 1
		and int(retention_controls.get("mutation_rejection_count", -1)) == 15
	)
	result["predecessor_contract_schema_version"] = String(predecessor.get("schema_version", ""))
	result["walking_ledger_failure_retention_controls"] = retention_controls
	result["walking_ledger_failure_retention_positive_control_count"] = int(
		retention_controls.get("positive_control_count", -1)
	)
	result["walking_ledger_failure_retention_mutation_rejection_count"] = int(
		retention_controls.get("mutation_rejection_count", -1)
	)
	result["partial_child_retains_active_walking_session"] = true
	result["partial_child_retains_last_walking_step_failure"] = true
	result["all_existing_l12_handoff_positive_controls_still_pass"] = bool(
		predecessor.get("ok", false)
	)
	result["all_existing_l12_handoff_negative_controls_still_pass"] = bool(
		predecessor.get("ok", false)
	)
	return result


static func _json_safe_v1(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR3:
			var vector: Vector3 = value
			return [vector.x, vector.y, vector.z]
		TYPE_VECTOR2:
			var vector: Vector2 = value
			return [vector.x, vector.y]
		TYPE_QUATERNION:
			var quaternion: Quaternion = value
			return [quaternion.x, quaternion.y, quaternion.z, quaternion.w]
		TYPE_ARRAY:
			var output: Array = []
			for item in value:
				output.append(_json_safe_v1(item))
			return output
		TYPE_DICTIONARY:
			var output := {}
			for key in value:
				output[String(key)] = _json_safe_v1(value[key])
			return output
		TYPE_OBJECT:
			var object_value: Object = value
			return {"object_class": object_value.get_class() if object_value != null else "null"}
	return value


static func _is_lower_hex_v1(value: String, expected_length: int) -> bool:
	if value.length() != expected_length:
		return false
	for codepoint in value.to_ascii_buffer():
		var digit := codepoint >= 48 and codepoint <= 57
		var lower_hex_letter := codepoint >= 97 and codepoint <= 102
		if not digit and not lower_hex_letter:
			return false
	return true


static func _valid_sha256_static_v1(value: String) -> bool:
	return value.begins_with("sha256:") and _is_lower_hex_v1(value.trim_prefix("sha256:"), 64)


static func _canonical_sha256_static_v1(sdk: Object, value: Variant) -> String:
	if sdk == null:
		return ""
	return String(RecoveryRuntimeScript.canonicalize(sdk, value).get("sha256", ""))


static func _payload_sha256_static_v1(sdk: Object, value: Dictionary) -> String:
	var payload := value.duplicate(true)
	payload.erase("payload_sha256")
	return _canonical_sha256_static_v1(sdk, payload)


static func _dictionary_keys_exact_v1(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true
