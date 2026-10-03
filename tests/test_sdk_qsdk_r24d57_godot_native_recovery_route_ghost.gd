extends SceneTree
# gdlint: disable=max-line-length

## One-world, two-step, non-held-out integration ghost for the production R57
## Godot/Jolt recovery route.  No behavior threshold or success evaluator is
## present.  Physics failure is retained data; route/integration failure blocks
## later recovery work until repaired.

const RouteScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const NativeWorldScript := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const RecoveryRuntimeScript := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const BoundaryTransportScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_contiguous_boundary_transport_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const BehaviorWorker := preload(
	"res://tests/test_sdk_qsdk_r24d65_godot_native_recovery_behavior.gd"
)

const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const RAW_MARKER := "QSDK_R24D57_GODOT_NATIVE_RECOVERY_ROUTE_GHOST_RAW "
const READY_MARKER := "QSDK_R24D57_GODOT_SUPERVISOR_TERMINATION_READY "
const TERMINATION_PROTOCOL_ID := "godot_4_7_gdscript_shutdown_containment_v1"
const AUTHORIZATION_ENV := "SPORESPORE_R24D57_PHYSICAL_AUTHORIZATION_SHA256"
const SOURCE_COMMIT_ENV := "SPORESPORE_R24D57_SOURCE_COMMIT"
const ATTEMPT_ID_ENV := "SPORESPORE_R24D57_ATTEMPT_ID"
const SUPERVISED_ENV := "SPORESPORE_R24D57_SUPERVISED_TERMINATION"
const NONCE_ENV := "SPORESPORE_R24D57_TERMINATION_NONCE"
const SEED := 1656561876
const SEED_LABEL := "QSDK-R24D57/ghost/godot/route-smoke-v1"
const SEED_SHA256 := "sha256:e2bd20d4ef59f793681f47e1639dcf4b4079f321368f85dd414ad08dd714669d"
const PHYSICS_HZ := 120
const MAXIMUM_SOLVER_STEPS := 2
const PHASE := "establish_distal_support"
const EXIT_DRAIN_PROCESS_FRAME_COUNT := 2
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
const GENERIC_SEED_ENV := "SPORESPORE_GODOT_RECOVERY_SEED"
const GENERIC_SEED_LABEL_ENV := "SPORESPORE_GODOT_RECOVERY_SEED_LABEL"
const GENERIC_SEED_SHA_ENV := "SPORESPORE_GODOT_RECOVERY_SEED_SHA256"
const GENERIC_ACTUATOR_MODE_ENV := "SPORESPORE_GODOT_RECOVERY_ACTUATOR_MODE"
const GENERIC_RECOVERY_CONTROLLER_ID_ENV := "SPORESPORE_GODOT_RECOVERY_CONTROLLER_ID"
const GENERIC_RECOVERY_ENERGY_ROUTE_ID_ENV := "SPORESPORE_GODOT_RECOVERY_ENERGY_ROUTE_ID"
const ACTUATOR_MODE_LEGACY := "legacy_velocity_motor_v1"
const ACTUATOR_MODE_FORCE_BASED := "force_based_joint_impulse_v1"
const ACTUATOR_MODE_FORCE_BASED_GUARDED := (
	"force_based_native_angular_velocity_guarded_v1"
)
const ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED := (
	"force_based_nested_native_angular_velocity_guarded_v1"
)
const ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED := (
	"force_based_order_neutral_population_native_angular_velocity_guarded_v1"
)
const ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED := (
	"force_based_order_neutral_joint_space_effective_inertia_native_angular_velocity_guarded_v3"
)
const ACTUATOR_MODE_SOLVER_COUPLED := "solver_coupled_native_constraint_motor_v1"

var _sdk: Object
var _context: Dictionary = {}
var _model: Dictionary = {}
var _application_intent: Dictionary = {}
var _boundary_transport_initialization: Dictionary = {}
var _first_step: Dictionary = {}
var _schedule_started := false
var _observed_physics_step_boundaries := 0
var _exit_scheduled := false
var _pending_exit_code := 1
var _pending_receipt_kind := "worker_failure"
var _pending_exit_process_frames := 0
var _gate_id := "QSDK-R24D57"
var _gate_token := "R24D57"
var _raw_schema := "sporespore_qsdk_r24d57_godot_native_recovery_route_ghost_raw_v1"
var _work_id := "QSDK-R24D57-GODOT-JOLT-NATIVE-RECOVERY-ROUTE-GHOST"
var _raw_marker := RAW_MARKER
var _ready_marker := READY_MARKER
var _authorization_env := AUTHORIZATION_ENV
var _source_commit_env := SOURCE_COMMIT_ENV
var _attempt_id_env := ATTEMPT_ID_ENV
var _supervised_env := SUPERVISED_ENV
var _nonce_env := NONCE_ENV
var _seed := SEED
var _seed_label := SEED_LABEL
var _seed_sha256 := SEED_SHA256
var _actuator_mode := ACTUATOR_MODE_LEGACY
var _recovery_controller_id := RouteScript.RECOVERY_CONTROLLER_ID
var _recovery_energy_route_id := RouteScript.ROUTE_ID


func _initialize() -> void:
	call_deferred("_run")


# The route worker intentionally fails closed at each construction boundary.
# gdlint: disable=max-returns
func _run() -> void:
	if not _load_campaign_binding():
		_abort("QSDK_R24D57_GHOST_CAMPAIGN_BINDING_INVALID")
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
	):
		_abort(_failure_code("GHOST_AUTHORIZATION_ENV_INVALID"))
		return
	seed(_seed)
	Engine.physics_ticks_per_second = PHYSICS_HZ
	if Engine.physics_ticks_per_second != PHYSICS_HZ:
		_abort(_failure_code("GHOST_PHYSICS_RATE_INVALID"))
		return
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		_abort(_failure_code("GHOST_EXTENSION_UNAVAILABLE"))
		return
	_sdk = ClassDB.instantiate(CLASS_NAME)
	if _sdk == null:
		_abort(_failure_code("GHOST_EXTENSION_INSTANTIATION_FAILED"))
		return
	_context = prepare_route_context_v1(
		_sdk,
		_recovery_controller_id,
		_recovery_energy_route_id,
		_gate_id,
	)
	if not bool(_context.get("ok", false)):
		_abort(_failure_code("GHOST_CONTEXT_FAILED"), _context)
		return
	_model = await RouteScript.build_native_world_v1(self, _sdk, _context)
	if not bool(_model.get("ok", false)):
		_abort(_failure_code("GHOST_WORLD_BUILD_FAILED"), _model)
		return
	if bool(_context.get("contiguous_boundary_transport_profile_selected", false)):
		_boundary_transport_initialization = (
			RouteScript
			. initialize_contiguous_boundary_transport_native_world_v1(
				_sdk,
				_context,
				_model,
				attempt_id,
				"route_ghost",
				"%s:route-ghost:model-0" % attempt_id,
			)
		)
		if not bool(_boundary_transport_initialization.get("ok", false)):
			_abort(
				_failure_code("GHOST_BOUNDARY_TRANSPORT_INITIALIZATION_FAILED"),
				_boundary_transport_initialization,
			)
			return
	_application_intent = initial_route_application_v1(
		_sdk,
		_model,
		_recovery_controller_id,
		_recovery_energy_route_id,
		_gate_id,
	)
	if not bool(_application_intent.get("ok", false)):
		_abort(_failure_code("GHOST_INITIAL_APPLICATION_FAILED"), _application_intent)
		return
	physics_frame.connect(_on_physics_frame)


# gdlint: enable=max-returns


func _on_physics_frame() -> void:
	if not _schedule_started:
		_schedule_started = true
		PhysicsServer3D.set_active(true)
		_model["physics_server_active"] = true
		return
	_observed_physics_step_boundaries += 1
	var completed_steps := int(_model.get("host_step_count", 0))
	if completed_steps == 0:
		_capture_first_step()
		return
	if completed_steps == 1:
		_capture_second_step_and_finish()
		return
	_abort(
		_failure_code("GHOST_STEP_BUDGET_EXCEEDED"),
		{"observed_host_step_count": completed_steps},
	)


func _capture_first_step() -> void:
	var native := collect_route_observation_v1(1)
	if not bool(native.get("ok", false)):
		_abort(_failure_code("GHOST_FIRST_NATIVE_SAMPLE_FAILED"), native)
		return
	var complete_energy_solver_projection := complete_energy_solver_projection_v1(
		native,
		1,
		_recovery_energy_route_id,
		_gate_id in ["QSDK-R24D163", "QSDK-R24D169"],
	)
	if not bool(complete_energy_solver_projection.get("ok", false)):
		_abort(
			_failure_code("GHOST_FIRST_POSITION_SOLVER_RECEIPT_INVALID"),
			complete_energy_solver_projection,
		)
		return
	var bound: Dictionary = native["bound"]
	var portable := (
		RouteScript
		. collect_and_plan_v1(
			_sdk,
			_context,
			bound,
			PHASE,
			0,
		)
	)
	if not bool(portable.get("ok", false)):
		_abort(_failure_code("GHOST_FIRST_PORTABLE_ROUTE_FAILED"), portable)
		return
	var positions: Dictionary = {}
	var observation: Dictionary = bound["observation_v2"]
	for row_value in (observation["state"] as Dictionary)["ordered_joint_observations"]:
		var row: Dictionary = row_value
		positions[String(row["joint_id"])] = float(row["position_rad"])
	var application: Dictionary
	if (
		_recovery_energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
		and _gate_id in ["QSDK-R24D152", "QSDK-R24D163", "QSDK-R24D169"]
	):
		application = (
			RouteScript
			. apply_behavior_control_route_aware_discrete_staging_v2(
				_sdk,
				portable["control_receipt"],
				_model,
				positions,
			)
		)
	elif _recovery_energy_route_id in [
		RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
		RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
	]:
		application = RouteScript.apply_behavior_control_solver_coupled_complete_energy_v1(
			_sdk,
			portable["control_receipt"],
			_model,
			positions,
		)
	elif _recovery_energy_route_id == RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID:
		application = RouteScript.apply_behavior_control_complete_energy_v2(
			_sdk,
			portable["control_receipt"],
			_model,
			positions,
		)
	elif (
		_actuator_mode
		== ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED
	):
		application = (
			RouteScript
			. apply_behavior_control_force_based_joint_space_effective_inertia_population_guarded_v9(
				_sdk,
				portable["control_receipt"],
				_model,
				positions,
			)
		)
	elif _actuator_mode == ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED:
		application = (
			RouteScript
			. apply_behavior_control_force_based_order_neutral_population_guarded_v7(
				_sdk,
				portable["control_receipt"],
				_model,
				positions,
			)
		)
	elif _actuator_mode == ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED:
		application = (
			RouteScript
			. apply_behavior_control_force_based_nested_guarded_v4(
				_sdk,
				portable["control_receipt"],
				_model,
				positions,
			)
		)
	elif _actuator_mode == ACTUATOR_MODE_FORCE_BASED_GUARDED:
		application = (
			RouteScript
			. apply_behavior_control_force_based_guarded_v3(
				_sdk,
				portable["control_receipt"],
				_model,
				positions,
			)
		)
	elif _actuator_mode == ACTUATOR_MODE_FORCE_BASED:
		application = (
			RouteScript
			. apply_behavior_control_force_based_v2(
				_sdk,
				portable["control_receipt"],
				_model,
				positions,
			)
		)
	else:
		application = (
			RouteScript
			. apply_control_v1(
				_sdk,
				portable["control_receipt"],
				_model["joint_by_actuator_id"],
				positions,
				false,
			)
		)
	var force_based_receipt_valid := (
		_actuator_mode == ACTUATOR_MODE_FORCE_BASED
		and (
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
	var guarded_receipt_valid := (
		_actuator_mode == ACTUATOR_MODE_FORCE_BASED_GUARDED
		and (
			String(application.get("actuator_mapping_id", ""))
			== NativeWorldScript.GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		)
		and (
			String(application.get("work_mapping_id", ""))
			== NativeWorldScript.GUARDED_FORCE_BASED_WORK_MAPPING_ID
		)
		and int(application.get("host_write_count", -1)) == 16
		and int(application.get("host_readback_count", -1)) == 8
		and int(application.get("motor_enabled_count", -1)) == 0
		and int(application.get("hard_constraint_motor_disabled_count", -1)) == 8
		and int(application.get("hard_constraint_motor_target_write_count", -1)) == 0
		and int(application.get("body_impulse_write_count", -1)) == 16
		and bool(application.get("native_angular_velocity_guard_required", false))
		and int(application.get("native_angular_velocity_guard_engagement_count", -1)) >= 0
		and int(application.get("native_angular_velocity_initial_readback_count", -1)) == 9
		and int(
			application.get("native_angular_velocity_post_application_readback_count", -1)
		)
		== 16
		and int(application.get("native_angular_velocity_total_readback_count", -1)) == 25
		and bool(application.get("all_immediate_native_readbacks_inside_guard", false))
		and bool(application.get("physics_state_modified", false))
	)
	var nested_guarded_receipt_valid := (
		_actuator_mode == ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED
		and (
			String(application.get("actuator_mapping_id", ""))
			== NativeWorldScript.NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		)
		and (
			String(application.get("work_mapping_id", ""))
			== NativeWorldScript.NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		)
		and int(application.get("host_write_count", -1)) == 16
		and int(application.get("host_readback_count", -1)) == 8
		and int(application.get("motor_enabled_count", -1)) == 0
		and int(application.get("hard_constraint_motor_disabled_count", -1)) == 8
		and int(application.get("hard_constraint_motor_target_write_count", -1)) == 0
		and int(application.get("body_impulse_write_count", -1)) == 16
		and bool(application.get("native_angular_velocity_guard_required", false))
		and bool(
			application.get("native_angular_velocity_nested_projection_required", false)
		)
		and bool(
			application.get(
				"projection_target_separated_from_native_readback_guard", false
			)
		)
		and application.get("native_angular_velocity_inner_projection_target") is Dictionary
		and int(application.get("native_angular_velocity_guard_engagement_count", -1)) >= 0
		and int(application.get("native_angular_velocity_initial_readback_count", -1)) == 9
		and int(
			application.get("native_angular_velocity_post_application_readback_count", -1)
		)
		== 16
		and int(application.get("native_angular_velocity_total_readback_count", -1)) == 25
		and bool(application.get("all_immediate_native_readbacks_inside_guard", false))
		and bool(application.get("physics_state_modified", false))
	)
	var legacy_receipt_valid := (
		_actuator_mode == ACTUATOR_MODE_LEGACY
		and int(application.get("host_write_count", -1)) == 8
		and int(application.get("host_readback_count", -1)) == 8
	)
	var order_neutral_population_receipt_valid := (
		_actuator_mode == ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED
		and validate_order_neutral_population_route_application_v1(application)
	)
	var effective_inertia_population_receipt_valid := (
		_actuator_mode
		== ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED
		and validate_joint_space_effective_inertia_population_route_application_v1(application)
	)
	var solver_coupled_receipt_valid := (
		_actuator_mode == ACTUATOR_MODE_SOLVER_COUPLED
		and _recovery_energy_route_id
		in [
			RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
			RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
		]
		and String(application.get("schema_version", ""))
		== (
			"sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_complete_energy_command_application_receipt_v1"
			if (
				_recovery_energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
				and _gate_id in ["QSDK-R24D152", "QSDK-R24D163", "QSDK-R24D169"]
			)
			else "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_command_application_receipt_v1"
		)
		and String(application.get("actuation_realization_id", ""))
		== RouteScript.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID
		and String(application.get("actuator_mapping_id", ""))
		== RouteScript.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID
		and String(application.get("work_mapping_id", ""))
		== RouteScript.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID
		and String(application.get("partition_rule_id", ""))
		== RouteScript.R144_PARTITION_RULE_ID
		and int(application.get("validated_command_count", -1)) == 8
		and int(application.get("host_write_count", -1)) == 8
		and int(application.get("host_readback_count", -1)) == 8
		and int(application.get("host_constraint_configuration_write_count", -1)) == 8
		and int(application.get("motor_enabled_count", -1)) == 8
		and int(application.get("native_joint_motor_enabled_count", -1)) == 8
		and int(application.get("body_impulse_write_count", 0)) == 0
		and int(application.get("pre_solver_direct_body_impulse_write_count", -1)) == 0
		and bool(application.get("active_constraint_motor_configuration_modified", false))
		and bool(application.get("native_contact_solver_coupled", false))
		and bool(application.get("physics_state_modified", false))
	)
	if (
		not bool(application.get("ok", false))
		or int(application.get("semantic_step", -1)) != 2
		or not (
			force_based_receipt_valid
			or guarded_receipt_valid
			or nested_guarded_receipt_valid
			or order_neutral_population_receipt_valid
			or effective_inertia_population_receipt_valid
			or solver_coupled_receipt_valid
			or legacy_receipt_valid
		)
	):
		_abort(_failure_code("GHOST_PORTABLE_COMMAND_APPLICATION_FAILED"), application)
		return
	_first_step = {
		"native_route": native,
		"portable_route": portable,
		"application_intent": application,
		"complete_energy_solver_projection": complete_energy_solver_projection,
	}
	_application_intent = application


func _capture_second_step_and_finish() -> void:
	var native := collect_route_observation_v1(2)
	if not bool(native.get("ok", false)):
		_abort(_failure_code("GHOST_SECOND_NATIVE_SAMPLE_FAILED"), native)
		return
	var complete_energy_solver_projection := complete_energy_solver_projection_v1(
		native,
		2,
		_recovery_energy_route_id,
		_gate_id in ["QSDK-R24D163", "QSDK-R24D169"],
	)
	if not bool(complete_energy_solver_projection.get("ok", false)):
		_abort(
			_failure_code("GHOST_SECOND_POSITION_SOLVER_RECEIPT_INVALID"),
			complete_energy_solver_projection,
		)
		return
	var bound: Dictionary = native["bound"]
	var portable := (
		RouteScript
		. collect_and_plan_v1(
			_sdk,
			_context,
			bound,
			PHASE,
			1,
		)
	)
	if not bool(portable.get("ok", false)):
		_abort(_failure_code("GHOST_SECOND_PORTABLE_ROUTE_FAILED"), portable)
		return
	PhysicsServer3D.set_active(false)
	_model["physics_server_active"] = false
	if physics_frame.is_connected(_on_physics_frame):
		physics_frame.disconnect(_on_physics_frame)
	var application: Dictionary = _first_step["application_intent"]
	var second_measurement: Dictionary = native["measurement"]
	var complete_energy_route_selected := _recovery_energy_route_id in [
		RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
		RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
		RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
	]
	var solver_coupled_complete_energy_route_selected := (
		_recovery_energy_route_id
		in [
			RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
			RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
		]
	)
	var discrete_staging_complete_energy_route_selected := (
		_recovery_energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
	)
	var rotation_aware_energy_ledger_profile_selected := (
		_gate_id in ["QSDK-R24D163", "QSDK-R24D169"]
	)
	var contiguous_boundary_transport_profile_selected := (
		_gate_id == "QSDK-R24D169"
	)
	var transport_state: Dictionary = (
		_model.get("contiguous_boundary_transport_state", {})
		if contiguous_boundary_transport_profile_selected
		else {}
	)
	var ordered_complete_energy_solver_projections: Array = []
	if complete_energy_route_selected:
		ordered_complete_energy_solver_projections = [
			(_first_step["complete_energy_solver_projection"] as Dictionary).duplicate(true),
			complete_energy_solver_projection.duplicate(true),
		]
	var report := {
		"schema_version": _raw_schema,
		"gate_id": _gate_id,
		"work_id": _work_id,
		"ledger_prefix": "[recovery/godot]",
		"question_class": "development",
		"status": "valid_complete_integration_ghost",
		"ok": true,
		"source_commit": OS.get_environment(_source_commit_env),
		"attempt_id": OS.get_environment(_attempt_id_env),
		"authorization_sha256": OS.get_environment(_authorization_env),
		"seed": _seed,
		"seed_label": _seed_label,
		"seed_sha256": _seed_sha256,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"outer_step_duration_s": 1.0 / float(PHYSICS_HZ),
		"held_out": false,
		"full_seeded_world_demo": false,
		"recovery_success_required": false,
		"actuator_mode": _actuator_mode,
		"recovery_controller_id": _recovery_controller_id,
		"energy_route_id": _recovery_energy_route_id,
		"recovery_energy_route_id": _recovery_energy_route_id,
		"complete_energy_profile_selected": complete_energy_route_selected,
		"solver_coupled_complete_energy_profile_selected": (
			solver_coupled_complete_energy_route_selected
		),
		"discrete_staging_complete_energy_profile_selected": (
			discrete_staging_complete_energy_route_selected
		),
		"rotation_aware_energy_ledger_profile_selected": (
			rotation_aware_energy_ledger_profile_selected
		),
		"contiguous_boundary_transport_profile_selected": (
			contiguous_boundary_transport_profile_selected
		),
		"contiguous_boundary_transport_design_id": (
			String(_context.get("contiguous_boundary_transport_design_id", ""))
			if contiguous_boundary_transport_profile_selected
			else ""
		),
		"contiguous_boundary_transport_profile_id": (
			String(_context.get("contiguous_boundary_transport_profile_id", ""))
			if contiguous_boundary_transport_profile_selected
			else ""
		),
		"boundary_transport_state_schema_version": (
			String(_context.get("boundary_transport_state_schema_version", ""))
			if contiguous_boundary_transport_profile_selected
			else ""
		),
		"boundary_transport_pair_schema_version": (
			String(_context.get("boundary_transport_pair_schema_version", ""))
			if contiguous_boundary_transport_profile_selected
			else ""
		),
		"legacy_aliased_boundary_transport_selected": (
			bool(_context.get("legacy_aliased_boundary_transport_selected", true))
			if contiguous_boundary_transport_profile_selected
			else true
		),
		"boundary_transport_initializer_receipt": (
			_boundary_transport_initialization.duplicate(true)
			if contiguous_boundary_transport_profile_selected
			else {}
		),
		"boundary_transport_initializer_native_readback_count": (
			int(_boundary_transport_initialization.get("native_readback_count", 0))
			if contiguous_boundary_transport_profile_selected
			else 0
		),
		"boundary_transport_completed_boundary_count": (
			2 if contiguous_boundary_transport_profile_selected else 0
		),
		"boundary_transport_cache_advance_commit_count": (
			int(
				bool(
					(_first_step["native_route"] as Dictionary).get(
						"contiguous_boundary_transport_cache_advance_committed", false
					)
				)
			)
			+ int(bool(native.get("contiguous_boundary_transport_cache_advance_committed", false)))
			if contiguous_boundary_transport_profile_selected
			else 0
		),
		"boundary_transport_terminal_cached_sequence": (
			int(transport_state.get("cached_boundary_sequence", -1))
			if contiguous_boundary_transport_profile_selected
			else -1
		),
		"boundary_transport_terminal_accepted_pair_count": (
			int(transport_state.get("accepted_pair_count", -1))
			if contiguous_boundary_transport_profile_selected
			else -1
		),
		"boundary_transport_terminal_state_revision": (
			int(transport_state.get("state_revision", -1))
			if contiguous_boundary_transport_profile_selected
			else -1
		),
		"recovery_energy_ledger_profile_id": (
			RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
			if rotation_aware_energy_ledger_profile_selected
			else ""
		),
		"position_solver_entry_receipt_count": (
			ordered_complete_energy_solver_projections.size()
		),
		"all_complete_energy_position_solver_receipts_passed": (
			ordered_complete_energy_solver_projections.size() == 2
			if complete_energy_route_selected
			else true
		),
		"ordered_complete_energy_solver_projections": (
			ordered_complete_energy_solver_projections
		),
		"actuator_mapping_id": String(application.get("actuator_mapping_id", "")),
		"work_mapping_id": String(application.get("work_mapping_id", "")),
		"actuation_realization_id": String(application.get("actuation_realization_id", "")),
		"partition_rule_id": String(application.get("partition_rule_id", "")),
		"behavior_evaluator_invocation_count": 0,
		"threshold_count": 0,
		"margin_count": 0,
		"native_world_route_id": String(_model.get("world_route_id", "")),
		"initializer_manifest": (_model["blueprint"] as Dictionary)["initializer_manifest"],
		"initializer_manifest_sha256":
		String((_model["blueprint"] as Dictionary)["initializer_manifest_sha256"]),
		"initializer_readback": _model["initializer_readback"],
		"first_step": _first_step,
		"second_step":
		{
			"native_route": native,
			"portable_route": portable,
		},
		"portable_collection_count": 2,
		"portable_control_plan_count": 2,
		"portable_command_application_count": 1,
		"validated_command_count": int(application["validated_command_count"]),
		"host_write_count": int(application["host_write_count"]),
		"host_readback_count": int(application["host_readback_count"]),
		"motor_enabled_count": int(application.get("motor_enabled_count", -1)),
		"hard_constraint_motor_disabled_count":
		int(application.get("hard_constraint_motor_disabled_count", 0)),
		"hard_constraint_motor_target_write_count":
		int(application.get("hard_constraint_motor_target_write_count", 0)),
		"body_impulse_write_count": int(application.get("body_impulse_write_count", 0)),
		"native_joint_motor_enabled_count": int(
			application.get("native_joint_motor_enabled_count", 0)
		),
		"host_constraint_configuration_write_count": int(
			application.get("host_constraint_configuration_write_count", 0)
		),
		"active_constraint_motor_configuration_modified": bool(
			application.get("active_constraint_motor_configuration_modified", false)
		),
		"pre_solver_direct_body_impulse_write_count": int(
			application.get("pre_solver_direct_body_impulse_write_count", 0)
		),
		"adapter_side_discrete_staging_event_count":
		int(
			(second_measurement["energy_source_receipt"] as Dictionary)["adapter_side_discrete_staging_event_count"]
		),
		"cumulative_signed_discrete_staging_exchange_j": float(
			(second_measurement["energy_source_receipt"] as Dictionary).get(
				"cumulative_signed_discrete_staging_exchange_j",
				0.0,
			)
		),
		"discrete_staging_observer_receipt_count": (
			2 if discrete_staging_complete_energy_route_selected else 0
		),
		"discrete_staging_boundary_capture_count": (
			2 if discrete_staging_complete_energy_route_selected else 0
		),
		"missing_measurement_synthesis_count":
		int((native["bound"] as Dictionary)["missing_measurement_synthesis_count"]),
		"held_out_cell_access_count": 0,
		"model_construction_attempt_count": int(_model.get("model_construction_attempt_count", 0)),
		"native_scene_node_construction_attempted":
		bool(_model.get("native_scene_node_construction_attempted", false)),
		"model_construction_count": int(_model["model_construction_count"]),
		"world_attempt_count": int(_model["world_attempt_count"]),
		"world_build_count": int(_model["world_build_count"]),
		"solver_step_count": int(_model["solver_step_count"]),
		"maximum_solver_step_count": MAXIMUM_SOLVER_STEPS,
		"physics_state_modified": true,
		"physical_question_opened": true,
		"physics_failure_is_valid_evidence": true,
		"in_run_physical_invariant_step_count": 2,
		"all_in_run_physical_invariants_passed": true,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	var force_based_mapping_exact := (
		_actuator_mode != ACTUATOR_MODE_FORCE_BASED
		or (
			(
				String(report["actuator_mapping_id"])
				== NativeWorldScript.FORCE_BASED_ACTUATOR_MAPPING_ID
			)
			and String(report["work_mapping_id"]) == NativeWorldScript.FORCE_BASED_WORK_MAPPING_ID
			and int(report["host_write_count"]) == 16
			and int(report["host_readback_count"]) == 8
			and int(report["motor_enabled_count"]) == 0
			and int(report["hard_constraint_motor_disabled_count"]) == 8
			and int(report["hard_constraint_motor_target_write_count"]) == 0
			and int(report["body_impulse_write_count"]) == 16
		)
	)
	var guarded_mapping_exact := (
		_actuator_mode != ACTUATOR_MODE_FORCE_BASED_GUARDED
		or (
			String(report["actuator_mapping_id"])
			== NativeWorldScript.GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
			and String(report["work_mapping_id"])
			== NativeWorldScript.GUARDED_FORCE_BASED_WORK_MAPPING_ID
			and int(report["host_write_count"]) == 16
			and int(report["host_readback_count"]) == 8
			and int(report["motor_enabled_count"]) == 0
			and int(report["hard_constraint_motor_disabled_count"]) == 8
			and int(report["hard_constraint_motor_target_write_count"]) == 0
			and int(report["body_impulse_write_count"]) == 16
		)
	)
	var nested_guarded_mapping_exact := (
		_actuator_mode != ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED
		or (
			String(report["actuator_mapping_id"])
			== NativeWorldScript.NESTED_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
			and String(report["work_mapping_id"])
			== NativeWorldScript.NESTED_GUARDED_FORCE_BASED_WORK_MAPPING_ID
			and int(report["host_write_count"]) == 16
			and int(report["host_readback_count"]) == 8
			and int(report["motor_enabled_count"]) == 0
			and int(report["hard_constraint_motor_disabled_count"]) == 8
			and int(report["hard_constraint_motor_target_write_count"]) == 0
			and int(report["body_impulse_write_count"]) == 16
		)
	)
	var order_neutral_population_mapping_exact := (
		_actuator_mode != ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED
		or validate_order_neutral_population_route_application_v1(application)
	)
	var effective_inertia_population_mapping_exact := (
		_actuator_mode
		!= ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED
		or validate_joint_space_effective_inertia_population_route_application_v1(application)
	)
	var r136_complete_energy_route_exact := (
		_recovery_energy_route_id != RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID
		or (
			_recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID
			and _actuator_mode
			== ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED
			and bool(report["complete_energy_profile_selected"])
			and int(report["position_solver_entry_receipt_count"]) == 2
			and bool(report["all_complete_energy_position_solver_receipts_passed"])
			and bool(application.get("complete_energy_sampler_representation", false))
			and String(application.get("complete_energy_wrapper_schema_version", ""))
			== "sporespore_qsdk_r24d136_godot_complete_energy_command_application_receipt_v1"
			and String(application.get("energy_route_id", ""))
			== RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID
			and String(application.get("portable_recovery_controller_id", ""))
			== RouteScript.RECOVERY_CONTROLLER_V6_ID
			and bool(application.get("native_joint_motors_disabled", false))
			and not bool(application.get("native_contact_solver_coupled", true))
		)
	)
	var r144_complete_energy_route_exact := (
		_recovery_energy_route_id != RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
		or (
			_recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID
			and _actuator_mode == ACTUATOR_MODE_SOLVER_COUPLED
			and bool(report["complete_energy_profile_selected"])
			and bool(report["solver_coupled_complete_energy_profile_selected"])
			and int(report["position_solver_entry_receipt_count"]) == 2
			and bool(report["all_complete_energy_position_solver_receipts_passed"])
			and bool(application.get("complete_energy_sampler_representation", false))
			and String(application.get("schema_version", ""))
			== "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_command_application_receipt_v1"
			and String(application.get("energy_route_id", ""))
			== RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
			and String(application.get("energy_mapping_profile_id", ""))
			== RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
			and String(application.get("partition_rule_id", ""))
			== RouteScript.R144_PARTITION_RULE_ID
			and String(application.get("portable_recovery_controller_id", ""))
			== RouteScript.RECOVERY_CONTROLLER_V6_ID
			and not bool(application.get("native_joint_motors_disabled", true))
			and bool(application.get("native_contact_solver_coupled", false))
			and bool(
				application.get("native_motor_work_partitioned_from_whole_joint_exchange", false)
			)
		)
	)
	var r148_complete_energy_route_exact := (
		_recovery_energy_route_id != RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
		or (
			_recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID
			and _actuator_mode == ACTUATOR_MODE_SOLVER_COUPLED
			and bool(report["complete_energy_profile_selected"])
			and bool(report["solver_coupled_complete_energy_profile_selected"])
			and bool(report["discrete_staging_complete_energy_profile_selected"])
			and int(report["position_solver_entry_receipt_count"]) == 2
			and bool(report["all_complete_energy_position_solver_receipts_passed"])
			and int(report["discrete_staging_observer_receipt_count"]) == 2
			and int(report["discrete_staging_boundary_capture_count"]) == 2
			and String(report["native_world_route_id"])
			== "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_complete_energy_native_world_v1"
			and String(application.get("schema_version", ""))
			== (
				"sporespore_qsdk_r24d152_godot_route_aware_discrete_staging_complete_energy_command_application_receipt_v1"
				if _gate_id in ["QSDK-R24D152", "QSDK-R24D163", "QSDK-R24D169"]
				else "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_command_application_receipt_v1"
			)
			and String(application.get("energy_route_id", ""))
			== (
				RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
				if _gate_id in ["QSDK-R24D152", "QSDK-R24D163", "QSDK-R24D169"]
				else RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
			)
			and String(application.get("energy_mapping_profile_id", ""))
			== (
				RouteScript.R148_COMPLETE_ENERGY_MAPPING_PROFILE_ID
				if _gate_id in ["QSDK-R24D152", "QSDK-R24D163", "QSDK-R24D169"]
				else RouteScript.R144_COMPLETE_ENERGY_MAPPING_PROFILE_ID
			)
			and String(application.get("partition_rule_id", ""))
			== RouteScript.R144_PARTITION_RULE_ID
			and (
				_gate_id not in ["QSDK-R24D152", "QSDK-R24D163", "QSDK-R24D169"]
				or (
					String(application.get("predecessor_complete_energy_route_id", ""))
					== RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID
					and String(application.get("application_provenance_profile_id", ""))
					== RouteScript.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID
				)
			)
			and validate_discrete_staging_route_step_v1(
				_first_step["native_route"],
				1,
				rotation_aware_energy_ledger_profile_selected,
			)
			and validate_discrete_staging_route_step_v1(
				native, 2, rotation_aware_energy_ledger_profile_selected
			)
		)
	)
	var complete_energy_route_exact := (
		r136_complete_energy_route_exact
		and r144_complete_energy_route_exact
		and r148_complete_energy_route_exact
	)
	if _actuator_mode in [
		ACTUATOR_MODE_FORCE_BASED_GUARDED,
		ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED,
		ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED,
		ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED,
	]:
		report["native_angular_velocity_guard_required"] = true
		report["native_angular_velocity_guard_engagement_count"] = int(
			application["native_angular_velocity_guard_engagement_count"]
		)
		report["native_angular_velocity_guard_minimum_applied_scale"] = float(
			application["native_angular_velocity_guard_minimum_applied_scale"]
		)
		report["native_angular_velocity_initial_readback_count"] = int(
			application["native_angular_velocity_initial_readback_count"]
		)
		report["native_angular_velocity_post_application_readback_count"] = int(
			application["native_angular_velocity_post_application_readback_count"]
		)
		report["native_angular_velocity_total_readback_count"] = int(
			application["native_angular_velocity_total_readback_count"]
		)
		report["all_immediate_native_readbacks_inside_guard"] = bool(
			application["all_immediate_native_readbacks_inside_guard"]
		)
	if _actuator_mode in [
		ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED,
		ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED,
		ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED,
	]:
		report["native_angular_velocity_nested_projection_required"] = true
		report["native_angular_velocity_inner_projection_target"] = application[
			"native_angular_velocity_inner_projection_target"
		]
		report["projection_target_separated_from_native_readback_guard"] = true
	if _actuator_mode == ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED:
		var population: Dictionary = application[
			"order_neutral_population_guard_projection"
		]
		report["order_neutral_population_projection_required"] = true
		report["aggregate_body_application_required"] = true
		report["per_actuator_attribution_required"] = true
		report["input_iteration_order_has_action_authority"] = false
		report["common_applied_scale"] = float(population["common_applied_scale"])
		report["population_actuator_count"] = int(population["actuator_count"])
		report["population_body_count"] = int(population["body_count"])
		report["ordered_body_application_receipt_count"] = (
			(application["ordered_body_application_receipts"] as Array).size()
		)
	elif (
		_actuator_mode
		== ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED
	):
		var population: Dictionary = application[
			"joint_space_effective_inertia_population_guard_projection"
		]
		var body_guard: Dictionary = population["body_guard_population_projection"]
		report["joint_space_effective_inertia_population_projection_required"] = true
		report["aggregate_body_application_required"] = true
		report["per_actuator_attribution_required"] = true
		report["input_iteration_order_has_action_authority"] = false
		report["joint_space_common_pre_scale"] = float(
			population["joint_space_common_pre_scale"]
		)
		report["body_guard_common_applied_scale"] = float(
			population["body_guard_common_applied_scale"]
		)
		report["nominal_composed_common_scale"] = float(
			population["nominal_composed_common_scale"]
		)
		report["representation_refinement_count"] = int(
			population["representation_refinement_count"]
		)
		report["all_joint_target_errors_nonincreasing"] = bool(
			population["all_joint_target_errors_nonincreasing"]
		)
		report["joint_target_crossing_count"] = int(population["joint_target_crossing_count"])
		report["population_actuator_count"] = int(population["actuator_count"])
		report["population_body_count"] = int(population["body_count"])
		report["body_guard_nonzero_body_impulse_count"] = int(
			body_guard["nonzero_body_impulse_count"]
		)
		report["ordered_body_application_receipt_count"] = (
			(application["ordered_body_application_receipts"] as Array).size()
		)
	var legacy_mapping_exact := (
		_actuator_mode != ACTUATOR_MODE_LEGACY
		or (
			int(report["host_write_count"]) == 8
			and int(report["host_readback_count"]) == 8
			and int(report["body_impulse_write_count"]) == 0
		)
	)
	var solver_coupled_mapping_exact := (
		_actuator_mode != ACTUATOR_MODE_SOLVER_COUPLED
		or (
			String(report["actuation_realization_id"])
			== RouteScript.R127_SOLVER_COUPLED_ACTUATION_REALIZATION_ID
			and String(report["actuator_mapping_id"])
			== RouteScript.R144_REQUIRED_ACTIVE_ACTUATOR_MAPPING_ID
			and String(report["work_mapping_id"])
			== RouteScript.R144_REQUIRED_ACTIVE_WORK_MAPPING_ID
			and String(report["partition_rule_id"]) == RouteScript.R144_PARTITION_RULE_ID
			and int(report["host_write_count"]) == 8
			and int(report["host_readback_count"]) == 8
			and int(report["host_constraint_configuration_write_count"]) == 8
			and int(report["motor_enabled_count"]) == 8
			and int(report["native_joint_motor_enabled_count"]) == 8
			and int(report["body_impulse_write_count"]) == 0
			and int(report["pre_solver_direct_body_impulse_write_count"]) == 0
			and bool(report["active_constraint_motor_configuration_modified"])
		)
	)
	var exact := (
		int(report["model_construction_count"]) == 1
		and int(report["world_attempt_count"]) == 1
		and int(report["world_build_count"]) == 1
		and int(report["solver_step_count"]) == 2
		and int(report["portable_command_application_count"]) == 1
		and force_based_mapping_exact
		and guarded_mapping_exact
		and nested_guarded_mapping_exact
		and order_neutral_population_mapping_exact
		and effective_inertia_population_mapping_exact
		and solver_coupled_mapping_exact
		and complete_energy_route_exact
		and legacy_mapping_exact
		and int(report["in_run_physical_invariant_step_count"]) == 2
		and bool(report["all_in_run_physical_invariants_passed"])
		and int(report["adapter_side_discrete_staging_event_count"])
		== (2 if discrete_staging_complete_energy_route_selected else 0)
		and int(report["missing_measurement_synthesis_count"]) == 0
		and (
			not contiguous_boundary_transport_profile_selected
			or (
				bool(_boundary_transport_initialization.get("ok", false))
				and int(
					_boundary_transport_initialization.get("initializer_boundary_sequence", -1)
				)
				== 0
				and int(_boundary_transport_initialization.get("state_revision", -1)) == 0
				and int(
					_boundary_transport_initialization.get("native_readback_count", -1)
				)
				== 9
				and int(report["boundary_transport_completed_boundary_count"]) == 2
				and int(report["boundary_transport_cache_advance_commit_count"]) == 2
				and int(report["boundary_transport_terminal_cached_sequence"]) == 2
				and int(report["boundary_transport_terminal_accepted_pair_count"]) == 2
				and int(report["boundary_transport_terminal_state_revision"]) == 2
				and not bool(report["legacy_aliased_boundary_transport_selected"])
			)
		)
	)
	if not exact:
		_abort(_failure_code("GHOST_FINAL_CONJUNCTION_INVALID"), report)
		return
	RouteScript.cleanup_native_world_v1(_model)
	print(_raw_marker, JsonTransportScript.stringify(report))
	_schedule_exit(0, "valid_complete_integration_ghost")


func _abort(code: String, detail: Dictionary = {}) -> void:
	PhysicsServer3D.set_active(false)
	if not _model.is_empty():
		_model["physics_server_active"] = false
	if physics_frame.is_connected(_on_physics_frame):
		physics_frame.disconnect(_on_physics_frame)
	var model_construction_count := int(_model.get("model_construction_count", 0))
	var model_construction_attempt_count := int(
		(
			_model
			. get(
				"model_construction_attempt_count",
				int(detail.get("model_construction_attempt_count", 0)),
			)
		)
	)
	var native_scene_node_construction_attempted := bool(
		(
			_model
			. get(
				"native_scene_node_construction_attempted",
				bool(detail.get("native_scene_node_construction_attempted", false)),
			)
		)
	)
	var world_attempt_count := int(_model.get("world_attempt_count", 0))
	var world_build_count := int(_model.get("world_build_count", 0))
	var solver_step_count := maxi(
		int(_model.get("solver_step_count", 0)),
		_observed_physics_step_boundaries,
	)
	if not _model.is_empty():
		RouteScript.cleanup_native_world_v1(_model)
	var report := {
		"schema_version": _raw_schema,
		"gate_id": _gate_id,
		"work_id": _work_id,
		"ledger_prefix": "[recovery/godot]",
		"question_class": "development",
		"status": "invalid_or_incomplete_integration_ghost",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"source_commit": OS.get_environment(_source_commit_env),
		"attempt_id": OS.get_environment(_attempt_id_env),
		"authorization_sha256": OS.get_environment(_authorization_env),
		"seed": _seed,
		"seed_label": _seed_label,
		"seed_sha256": _seed_sha256,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"outer_step_duration_s": 1.0 / float(PHYSICS_HZ),
		"held_out": false,
		"full_seeded_world_demo": false,
		"recovery_success_required": false,
		"actuator_mode": _actuator_mode,
		"recovery_controller_id": _recovery_controller_id,
		"energy_route_id": _recovery_energy_route_id,
		"recovery_energy_route_id": _recovery_energy_route_id,
		"complete_energy_profile_selected": (
			_recovery_energy_route_id
			in [
				RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
				RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
				RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
			]
		),
		"solver_coupled_complete_energy_profile_selected": (
			_recovery_energy_route_id
			in [
				RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
				RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
			]
		),
		"discrete_staging_complete_energy_profile_selected": (
			_recovery_energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
		),
		"rotation_aware_energy_ledger_profile_selected": (
			_gate_id in ["QSDK-R24D163", "QSDK-R24D169"]
		),
		"recovery_energy_ledger_profile_id": (
			RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
			if _gate_id in ["QSDK-R24D163", "QSDK-R24D169"]
			else ""
		),
		"contiguous_boundary_transport_profile_selected": (
			_gate_id == "QSDK-R24D169"
		),
		"behavior_evaluator_invocation_count": 0,
		"threshold_count": 0,
		"margin_count": 0,
		"held_out_cell_access_count": 0,
		"model_construction_attempt_count": model_construction_attempt_count,
		"native_scene_node_construction_attempted": native_scene_node_construction_attempted,
		"model_construction_count": model_construction_count,
		"world_attempt_count": world_attempt_count,
		"world_build_count": world_build_count,
		"solver_step_count": solver_step_count,
		"maximum_solver_step_count": MAXIMUM_SOLVER_STEPS,
		"physics_state_modified": solver_step_count > 0,
		"physical_question_opened": world_attempt_count > 0,
		"physics_failure_is_valid_evidence": true,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	print(_raw_marker, JsonTransportScript.stringify(report))
	_schedule_exit(1, "invalid_or_incomplete_integration_ghost")


func _schedule_exit(exit_code: int, receipt_kind: String) -> void:
	if _exit_scheduled:
		return
	_exit_scheduled = true
	_pending_exit_code = exit_code
	_pending_receipt_kind = receipt_kind
	_pending_exit_process_frames = EXIT_DRAIN_PROCESS_FRAME_COUNT
	process_frame.connect(_orderly_exit_process_frame, CONNECT_ONE_SHOT)


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
	var configured_seed := OS.get_environment(GENERIC_SEED_ENV)
	var configured_seed_label := OS.get_environment(GENERIC_SEED_LABEL_ENV)
	var configured_seed_sha := OS.get_environment(GENERIC_SEED_SHA_ENV)
	var configured_actuator_mode := OS.get_environment(GENERIC_ACTUATOR_MODE_ENV)
	var configured_recovery_controller_id := OS.get_environment(
		GENERIC_RECOVERY_CONTROLLER_ID_ENV
	)
	var configured_recovery_energy_route_id := OS.get_environment(
		GENERIC_RECOVERY_ENERGY_ROUTE_ID_ENV
	)
	if configured_actuator_mode.is_empty():
		configured_actuator_mode = ACTUATOR_MODE_LEGACY
	if (
		not configured_gate.begins_with("QSDK-R")
		or configured_token.is_empty()
		or configured_gate != "QSDK-%s" % configured_token
		or not configured_schema.begins_with("sporespore_qsdk_")
		or configured_work_id.is_empty()
		or configured_raw_marker.is_empty()
		or configured_ready_marker.is_empty()
		or not configured_seed.is_valid_int()
		or configured_seed.to_int() == 0
		or configured_seed_label.is_empty()
		or not _valid_sha256(configured_seed_sha)
		or not route_binding_valid_v1(
			configured_recovery_controller_id,
			configured_recovery_energy_route_id,
			configured_actuator_mode,
		)
		or (
			configured_actuator_mode
			not in [
				ACTUATOR_MODE_LEGACY,
				ACTUATOR_MODE_FORCE_BASED,
				ACTUATOR_MODE_FORCE_BASED_GUARDED,
				ACTUATOR_MODE_FORCE_BASED_NESTED_GUARDED,
				ACTUATOR_MODE_FORCE_BASED_ORDER_NEUTRAL_POPULATION_GUARDED,
				ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED,
				ACTUATOR_MODE_SOLVER_COUPLED,
			]
		)
	):
		return false
	_gate_id = configured_gate
	_gate_token = configured_token
	_raw_schema = configured_schema
	_work_id = configured_work_id
	_raw_marker = configured_raw_marker
	_ready_marker = configured_ready_marker
	_authorization_env = GENERIC_AUTHORIZATION_ENV
	_source_commit_env = GENERIC_SOURCE_COMMIT_ENV
	_attempt_id_env = GENERIC_ATTEMPT_ID_ENV
	_supervised_env = GENERIC_SUPERVISED_ENV
	_nonce_env = GENERIC_NONCE_ENV
	_seed = configured_seed.to_int()
	_seed_label = configured_seed_label
	_seed_sha256 = configured_seed_sha
	_actuator_mode = configured_actuator_mode
	_recovery_controller_id = configured_recovery_controller_id
	_recovery_energy_route_id = configured_recovery_energy_route_id
	return true


static func route_binding_valid_v1(
	recovery_controller_id: String,
	recovery_energy_route_id: String,
	actuator_mode: String,
) -> bool:
	if recovery_energy_route_id == RouteScript.ROUTE_ID:
		return recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_ID
	if recovery_energy_route_id == RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID:
		return (
			recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID
			and actuator_mode == ACTUATOR_MODE_SOLVER_COUPLED
		)
	if recovery_energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID:
		return (
			recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID
			and actuator_mode == ACTUATOR_MODE_SOLVER_COUPLED
		)
	return (
		recovery_energy_route_id == RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID
		and recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_V6_ID
		and actuator_mode
		== ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED
	)


static func prepare_route_context_v1(
	sdk: Object,
	recovery_controller_id: String,
	recovery_energy_route_id: String,
	gate_id: String = "",
) -> Dictionary:
	if recovery_energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID:
		if gate_id == "QSDK-R24D169":
			return RouteScript.prepare_complete_energy_context_v16(
				sdk, recovery_controller_id
			)
		if gate_id == "QSDK-R24D163":
			return RouteScript.prepare_complete_energy_context_v12(
				sdk, recovery_controller_id
			)
		if gate_id == "QSDK-R24D152":
			return RouteScript.prepare_complete_energy_context_v8(
				sdk, recovery_controller_id
			)
		if gate_id == "QSDK-R24D150":
			return RouteScript.prepare_complete_energy_context_v6(
				sdk, recovery_controller_id
			)
		return RouteScript.prepare_complete_energy_context_v5(sdk, recovery_controller_id)
	if recovery_energy_route_id == RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID:
		return RouteScript.prepare_complete_energy_context_v3(sdk, recovery_controller_id)
	if recovery_energy_route_id == RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID:
		return RouteScript.prepare_complete_energy_context_v2(sdk, recovery_controller_id)
	if (
		recovery_energy_route_id == RouteScript.ROUTE_ID
		and recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_ID
	):
		return RouteScript.prepare_context_v1(sdk)
	return {"ok": false, "failure_code": "QSDK_ROUTE_GHOST_CONTEXT_BINDING_INVALID"}


static func initial_route_application_v1(
	sdk: Object,
	model: Dictionary,
	recovery_controller_id: String,
	recovery_energy_route_id: String,
	gate_id: String = "",
) -> Dictionary:
	if (
		recovery_energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
		and gate_id in ["QSDK-R24D152", "QSDK-R24D163", "QSDK-R24D169"]
	):
		return RouteScript.initial_behavior_application_route_aware_discrete_staging_v2(
			sdk,
			model,
			"candidate_command",
			PHASE,
			recovery_controller_id,
		)
	if recovery_energy_route_id in [
		RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
		RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
	]:
		return RouteScript.initial_behavior_application_solver_coupled_complete_energy_v1(
			sdk,
			model,
			"candidate_command",
			PHASE,
			recovery_controller_id,
		)
	if recovery_energy_route_id == RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID:
		return RouteScript.initial_behavior_application_complete_energy_v1(
			sdk,
			model,
			"candidate_command",
			PHASE,
			recovery_controller_id,
		)
	if (
		recovery_energy_route_id == RouteScript.ROUTE_ID
		and recovery_controller_id == RouteScript.RECOVERY_CONTROLLER_ID
	):
		return RouteScript.initial_native_application_v1(sdk, model)
	return {"ok": false, "failure_code": "QSDK_ROUTE_GHOST_INITIAL_BINDING_INVALID"}


func collect_route_observation_v1(semantic_step: int) -> Dictionary:
	if _recovery_energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID:
		return RouteScript.collect_discrete_staging_complete_energy_native_world_observation_v1(
			_sdk,
			_context,
			_model,
			_application_intent,
			semantic_step,
			PHASE,
		)
	if _recovery_energy_route_id == RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID:
		return RouteScript.collect_solver_coupled_complete_energy_native_world_observation_v1(
			_sdk,
			_context,
			_model,
			_application_intent,
			semantic_step,
			PHASE,
		)
	if _recovery_energy_route_id == RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID:
		return RouteScript.collect_complete_energy_native_world_observation_v1(
			_sdk,
			_context,
			_model,
			_application_intent,
			semantic_step,
			PHASE,
		)
	return RouteScript.collect_native_world_observation_v1(
		_sdk,
		_context,
		_model,
		_application_intent,
		semantic_step,
		PHASE,
	)


static func validate_discrete_staging_route_step_v1(
	native_value: Variant,
	expected_semantic_step: int,
	rotation_aware_energy_ledger_profile: bool = false,
) -> bool:
	if not (native_value is Dictionary):
		return false
	var native: Dictionary = native_value
	var measurement_value: Variant = native.get("measurement")
	var capture_value: Variant = native.get("discrete_staging_boundary_capture")
	var observer_value: Variant = native.get("discrete_staging_observer_receipt")
	var accumulator_value: Variant = native.get("discrete_staging_accumulator_after")
	var bound_value: Variant = native.get("bound")
	if (
		not bool(native.get("ok", false))
		or not (measurement_value is Dictionary)
		or not (capture_value is Dictionary)
		or not (observer_value is Dictionary)
		or not (accumulator_value is Dictionary)
		or not (bound_value is Dictionary)
	):
		return false
	var measurement: Dictionary = measurement_value
	var capture: Dictionary = capture_value
	var observer: Dictionary = observer_value
	var accumulator: Dictionary = accumulator_value
	var bound: Dictionary = bound_value
	var energy_value: Variant = measurement.get("energy_source_receipt")
	var components_value: Variant = measurement.get("source_component_receipts")
	var mapping_value: Variant = bound.get("native_to_portable_staging_mapping")
	var rows_value: Variant = capture.get("ordered_body_boundaries")
	if (
		not (energy_value is Dictionary)
		or not (components_value is Dictionary)
		or not (mapping_value is Dictionary)
		or not (rows_value is Array)
	):
		return false
	var energy: Dictionary = energy_value
	var components: Dictionary = components_value
	var mapping: Dictionary = mapping_value
	var rows: Array = rows_value
	if (
		String(native.get("schema_version", ""))
		!= (
			"sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_native_bound_measurement_v1"
			if rotation_aware_energy_ledger_profile
			else "sporespore_qsdk_r24d149_godot_discrete_staging_complete_energy_native_bound_measurement_v1"
		)
		or int(native.get("solver_step_count", -1)) != expected_semantic_step
		or String(capture.get("schema_version", ""))
		!= (
			"sporespore_qsdk_r24d168_godot_jolt_contiguous_body_boundary_capture_v1"
			if bool(native.get("contiguous_boundary_transport_profile_selected", false))
			else "sporespore_qsdk_r24d149_godot_jolt_discrete_staging_body_boundary_capture_v1"
		)
		or int(capture.get("semantic_step", -1)) != expected_semantic_step
		or int(capture.get("previous_sequence", -1)) != expected_semantic_step - 1
		or int(capture.get("body_count", -1)) != 9
		or rows.size() != 9
		or (
			not bool(native.get("contiguous_boundary_transport_profile_selected", false))
			and not bool(capture.get("force_path_readback_complete", false))
		)
		or not bool(capture.get("source_measurement", false))
		or (
			bool(native.get("contiguous_boundary_transport_profile_selected", false))
			and (
				String(capture.get("transport_design_id", ""))
				!= BoundaryTransportScript.TRANSPORT_DESIGN_ID
				or String(capture.get("transport_profile_id", ""))
				!= RouteScript.R168_CONTIGUOUS_BOUNDARY_TRANSPORT_PROFILE_ID
				or int(capture.get("transport_state_revision_before", -1))
				!= expected_semantic_step - 1
				or int(capture.get("transport_state_revision_after", -1))
				!= expected_semantic_step
				or int(capture.get("cache_advance_count_pending_commit", -1)) != 1
				or capture.has("transport_state_after")
				or not bool(
					native.get(
						"contiguous_boundary_transport_cache_advance_committed", false
					)
				)
				or int(native.get("contiguous_boundary_transport_state_revision", -1))
				!= expected_semantic_step
			)
		)
		or String(observer.get("schema_version", ""))
		!= "sporespore_qsdk_r24d148_godot_jolt_discrete_staging_exchange_v1"
		or not bool(observer.get("ok", false))
		or int(observer.get("sequence", -1)) != expected_semantic_step
		or int(observer.get("previous_sequence", -1)) != expected_semantic_step - 1
		or int(observer.get("body_count", -1)) != 9
		or not bool(observer.get("source_measurement", false))
		or String(energy.get("schema_version", ""))
		!= "sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_source_receipt_v1"
		or int(energy.get("semantic_step", -1)) != expected_semantic_step
		or int(energy.get("adapter_side_discrete_staging_event_count", -1))
		!= expected_semantic_step
		or String(components.get("schema_version", ""))
		!= "sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_source_component_receipts_v1"
		or int(components.get("semantic_step", -1)) != expected_semantic_step
		or not bool(components.get("source_measurement", false))
		or int(accumulator.get("sequence", -1)) != expected_semantic_step
		or int(accumulator.get("event_count", -1)) != expected_semantic_step
		or not bool(mapping.get("ok", false))
		or mapping.get("accumulator_after", {}) != accumulator
		or native.get("discrete_staging_accumulator_after_sha256", null)
		!= mapping.get("accumulator_after_sha256", null)
		or measurement.get("discrete_staging_boundary_capture", {}) != capture
		or measurement.get("discrete_staging_observer_receipt", {}) != observer
		or (
			rotation_aware_energy_ledger_profile
			and (
				not bool(
					native.get("rotation_aware_energy_ledger_profile_selected", false)
				)
				or String(native.get("recovery_energy_ledger_profile_id", ""))
				!= RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
				or String(measurement.get("schema_version", ""))
				!= "sporespore_qsdk_r24d163_godot_rotation_aware_discrete_staging_native_measurement_v1"
				or String(measurement.get("recovery_energy_ledger_profile_id", ""))
				!= RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
				or String(energy.get("recovery_energy_ledger_profile_id", ""))
				!= RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
				or String(components.get("recovery_energy_ledger_profile_id", ""))
				!= RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
				or not bool(
					energy.get(
						"rotation_integration_exchange_included_exactly_once", false
					)
				)
				or not bool(
					components.get(
						"rotation_integration_exchange_included_exactly_once", false
					)
				)
			)
		)
	):
		return false
	for index in range(rows.size()):
		var row_value: Variant = rows[index]
		if not (row_value is Dictionary):
			return false
		var row: Dictionary = row_value
		if (
			int(row.get("body_index", -1)) != index
			or int(row.get("pre_boundary_sequence", -1))
			!= expected_semantic_step - 1
			or int(row.get("post_boundary_sequence", -1))
			!= expected_semantic_step
			or not bool(row.get("pre_source_measurement", false))
			or not bool(row.get("post_source_measurement", false))
		):
			return false
	return true


static func complete_energy_solver_projection_v1(
	native: Dictionary,
	expected_semantic_step: int,
	recovery_energy_route_id: String,
	rotation_aware_energy_ledger_profile: bool = false,
) -> Dictionary:
	var solver_coupled_complete_energy := (
		recovery_energy_route_id
		in [
			RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
			RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
		]
	)
	if (
		recovery_energy_route_id
		not in [
			RouteScript.R136_COMPLETE_ENERGY_ROUTE_ID,
			RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID,
			RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID,
		]
	):
		return {
			"schema_version": "sporespore_qsdk_godot_route_position_solver_projection_v1",
			"ok": true,
			"required": false,
			"semantic_step": expected_semantic_step,
			"physical_acceptance_authority": false,
			"release_authority": false,
		}
	var measurement_value: Variant = native.get("measurement")
	if not bool(native.get("ok", false)) or not (measurement_value is Dictionary):
		return {"ok": false, "failure_code": "QSDK_ROUTE_GHOST_MEASUREMENT_INVALID"}
	var measurement: Dictionary = measurement_value
	var components_value: Variant = measurement.get("source_component_receipts")
	if not (components_value is Dictionary):
		return {"ok": false, "failure_code": "QSDK_ROUTE_GHOST_COMPONENTS_INVALID"}
	var components: Dictionary = components_value
	var receipt_value: Variant = components.get("solver_energy_exchange_receipt")
	var receipt_sha := String(components.get("solver_energy_exchange_receipt_sha256", ""))
	if not (receipt_value is Dictionary) or not _valid_sha256(receipt_sha):
		return {"ok": false, "failure_code": "QSDK_ROUTE_GHOST_SOLVER_RECEIPT_INVALID"}
	var receipt: Dictionary = receipt_value
	var checks_value: Variant = receipt.get("ordered_checks")
	if not (checks_value is Dictionary):
		return {"ok": false, "failure_code": "QSDK_ROUTE_GHOST_SOLVER_CHECKS_INVALID"}
	var checks: Dictionary = checks_value
	var expected_component_schema := (
		"sporespore_qsdk_r24d148_godot_discrete_staging_complete_energy_source_component_receipts_v1"
		if recovery_energy_route_id == RouteScript.R148_COMPLETE_ENERGY_ROUTE_ID
		else "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_source_component_receipts_v1"
		if solver_coupled_complete_energy
		else "sporespore_qsdk_r24d136_godot_complete_energy_source_component_receipts_v1"
	)
	var required_checks := [
		"constrained_island_present",
		"velocity_coverage_complete",
		"position_coverage_complete",
		"joint_velocity_phase_present",
		"position_phase_present",
		"dynamic_body_observation_present",
		"invalid_body_measurement_zero",
		"large_island_velocity_zero",
		"large_island_position_zero",
		"ccd_active_body_zero",
		"active_soft_body_zero",
		"update_error_zero",
		"native_complete",
		"source_measurement",
		"residual_not_used",
	]
	for check_id in required_checks:
		if not bool(checks.get(check_id, false)):
			return {
				"ok": false,
				"failure_code": "QSDK_ROUTE_GHOST_SOLVER_CHECK_FAILED:%s" % check_id,
			}
	if (
		String(receipt.get("schema_version", ""))
		!= (
			RouteScript.R162_SOLVER_ENERGY_CONSUMER_CONTRACT_SCHEMA
			if rotation_aware_energy_ledger_profile
			else "sporespore_qsdk_r24d136_godot_solver_energy_exchange_contract_v1"
		)
		or not bool(receipt.get("ok", false))
		or int(receipt.get("expected_space_step_sequence", -1)) != expected_semantic_step
		or int(receipt.get("capture_space_step_sequence", -1)) != expected_semantic_step
		or int(receipt.get("read_space_step_sequence", -1)) != expected_semantic_step
		or int(receipt.get("check_count", -1)) != checks.size()
		or String(components.get("schema_version", ""))
		!= expected_component_schema
		or (
			rotation_aware_energy_ledger_profile
			and (
				String(receipt.get("recovery_energy_ledger_profile_id", ""))
				!= RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
				or String(receipt.get("telemetry_schema_version", ""))
				!= RouteScript.R162_SOLVER_ENERGY_TELEMETRY_SCHEMA
				or String(receipt.get("telemetry_profile_id", ""))
				!= RouteScript.R162_SOLVER_ENERGY_TELEMETRY_PROFILE_ID
				or not bool(
					receipt.get("rotation_integration_partition_complete", false)
				)
				or not is_finite(
					float(
						receipt.get(
							"rotation_integration_kinetic_exchange_j", NAN
						)
					)
				)
			)
		)
	):
		return {"ok": false, "failure_code": "QSDK_ROUTE_GHOST_SOLVER_IDENTITY_INVALID"}
	var partition: Dictionary = {}
	var partition_sha := ""
	if solver_coupled_complete_energy:
		var partition_value: Variant = components.get("solver_coupled_partition_receipt")
		partition_sha = String(components.get("solver_coupled_partition_receipt_sha256", ""))
		if not (partition_value is Dictionary) or not _valid_sha256(partition_sha):
			return {
				"ok": false,
				"failure_code": "QSDK_ROUTE_GHOST_PARTITION_RECEIPT_INVALID",
			}
		partition = partition_value
		var numerical_bound := float(partition.get("numerical_consistency_bound_j", NAN))
		if (
			String(partition.get("schema_version", ""))
			!= (
				RouteScript.R162_ROTATION_AWARE_PARTITION_CONTRACT_SCHEMA
				if rotation_aware_energy_ledger_profile
				else "sporespore_qsdk_r24d144_godot_solver_coupled_complete_energy_partition_contract_v1"
			)
			or not bool(partition.get("ok", false))
			or String(partition.get("partition_rule_id", ""))
			!= RouteScript.R144_PARTITION_RULE_ID
			or int(partition.get("expected_space_step_sequence", -1))
			!= expected_semantic_step
			or int(partition.get("motor_receipt_count", -1)) != 8
			or int(partition.get("numerical_term_count", -1))
			!= (14 if rotation_aware_energy_ledger_profile else 13)
			or not is_finite(numerical_bound)
			or numerical_bound < 0.0
			or absf(float(partition.get("raw_component_reconstruction_delta_j", NAN)))
			> numerical_bound
			or absf(float(partition.get("partition_reconstruction_delta_j", NAN)))
			> numerical_bound
			or not bool(partition.get("native_motor_work_subtracted_exactly_once", false))
			or bool(partition.get("motor_work_also_counted_as_constraint_exchange", true))
			or not bool(partition.get("constraint_exchange_partition_disjoint", false))
			or not bool(partition.get("component_partition_complete", false))
			or (
				rotation_aware_energy_ledger_profile
				and (
					String(partition.get("recovery_energy_ledger_profile_id", ""))
					!= RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
					or not bool(
						partition.get(
							"rotation_integration_exchange_included_exactly_once", false
						)
					)
					or not bool(
						partition.get("rotation_integration_partition_complete", false)
					)
					or not is_finite(
						float(
							partition.get(
								"rotation_integration_kinetic_exchange_j", NAN
							)
						)
					)
				)
			)
			or not bool(partition.get("source_measurement", false))
			or bool(partition.get("mechanical_energy_residual_used_as_work_source", true))
		):
			return {
				"ok": false,
				"failure_code": "QSDK_ROUTE_GHOST_PARTITION_IDENTITY_INVALID",
			}
	var projection := {
		"schema_version": "sporespore_qsdk_godot_route_position_solver_projection_v1",
		"ok": true,
		"required": true,
		"semantic_step": expected_semantic_step,
		"solver_energy_exchange_receipt_sha256": receipt_sha,
		"solver_energy_exchange_receipt": receipt.duplicate(true),
		"position_phase_present": true,
		"position_coverage_complete": true,
		"native_complete": true,
		"source_measurement": true,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if solver_coupled_complete_energy:
		projection["solver_coupled_partition_receipt_sha256"] = partition_sha
		projection["solver_coupled_partition_receipt"] = partition.duplicate(true)
		projection["partition_rule_id"] = RouteScript.R144_PARTITION_RULE_ID
		projection["native_motor_work_subtracted_exactly_once"] = true
		projection["motor_work_also_counted_as_constraint_exchange"] = false
		projection["constraint_exchange_partition_disjoint"] = true
		if rotation_aware_energy_ledger_profile:
			projection["recovery_energy_ledger_profile_id"] = (
				RouteScript.R162_ROTATION_AWARE_ENERGY_LEDGER_PROFILE_ID
			)
			projection["rotation_integration_exchange_included_exactly_once"] = true
			projection["rotation_integration_kinetic_exchange_j"] = float(
				partition["rotation_integration_kinetic_exchange_j"]
			)
	return projection


static func validate_order_neutral_population_route_application_v1(
	application: Dictionary,
) -> bool:
	if (
		not bool(application.get("ok", false))
		or (
			String(application.get("actuator_mapping_id", ""))
			!= NativeWorldScript.ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_ACTUATOR_MAPPING_ID
		)
		or (
			String(application.get("work_mapping_id", ""))
			!= NativeWorldScript.ORDER_NEUTRAL_POPULATION_GUARDED_FORCE_BASED_WORK_MAPPING_ID
		)
		or int(application.get("validated_command_count", -1)) != 8
		or int(application.get("host_readback_count", -1)) != 8
		or int(application.get("motor_enabled_count", -1)) != 0
		or int(application.get("hard_constraint_motor_disabled_count", -1)) != 8
		or int(application.get("hard_constraint_motor_target_write_count", -1)) != 0
		or not bool(application.get("native_angular_velocity_guard_required", false))
		or not bool(application.get("native_angular_velocity_nested_projection_required", false))
		or not bool(application.get("projection_target_separated_from_native_readback_guard", false))
		or not bool(application.get("all_immediate_native_readbacks_inside_guard", false))
		or int(application.get("native_angular_velocity_initial_readback_count", -1)) != 9
		or int(application.get("native_angular_velocity_post_application_readback_count", -1)) != 9
		or int(application.get("native_angular_velocity_total_readback_count", -1)) != 18
		or not bool(application.get("order_neutral_population_projection_required", false))
		or not bool(application.get("aggregate_body_application_required", false))
		or not bool(application.get("per_actuator_attribution_required", false))
		or bool(application.get("input_iteration_order_has_action_authority", true))
		or not bool(application.get("physics_state_modified", false))
		or not (application.get("ordered_receipts") is Array)
		or not (application.get("ordered_body_application_receipts") is Array)
		or not (application.get("order_neutral_population_guard_projection") is Dictionary)
		or not (application.get("order_neutral_population_native_angular_velocity_readback") is Dictionary)
	):
		return false
	var body_write_count := int(application.get("body_impulse_write_count", -1))
	if (
		body_write_count < 1
		or body_write_count > 9
		or int(application.get("host_write_count", -1)) != body_write_count
		or (application["ordered_receipts"] as Array).size() != 8
		or (application["ordered_body_application_receipts"] as Array).size() != 9
	):
		return false
	var population: Dictionary = application["order_neutral_population_guard_projection"]
	var common_scale := float(population.get("common_applied_scale", NAN))
	if (
		not bool(population.get("ok", false))
		or int(population.get("actuator_count", -1)) != 8
		or int(population.get("body_count", -1)) != 9
		or int(population.get("nonzero_body_impulse_count", -1)) != body_write_count
		or not is_finite(common_scale)
		or common_scale <= 0.0
		or common_scale > 1.0
	):
		return false
	var observed_write_count := 0
	for receipt_value in application["ordered_body_application_receipts"]:
		if not (receipt_value is Dictionary):
			return false
		var receipt: Dictionary = receipt_value
		var performed := bool(receipt.get("call_performed", false))
		if performed:
			if (
				not bool(receipt.get("call_returned", false))
				or int(receipt.get("body_impulse_write_count", -1)) != 1
			):
				return false
			observed_write_count += 1
		elif (
			bool(receipt.get("call_returned", true))
			or int(receipt.get("body_impulse_write_count", -1)) != 0
		):
			return false
	return observed_write_count == body_write_count


static func validate_joint_space_effective_inertia_population_route_application_v1(
	application: Dictionary,
) -> bool:
	return BehaviorWorker.behavior_application_receipt_valid_v2(
		ACTUATOR_MODE_FORCE_BASED_JOINT_SPACE_EFFECTIVE_INERTIA_POPULATION_GUARDED,
		application,
		false,
	)


func _failure_code(suffix: String) -> String:
	return "QSDK_%s_%s" % [_gate_token, suffix]


static func _valid_sha256(value: String) -> bool:
	return (
		value.length() == 71
		and value.begins_with("sha256:")
		and value.substr(7).is_valid_hex_number(false)
	)
