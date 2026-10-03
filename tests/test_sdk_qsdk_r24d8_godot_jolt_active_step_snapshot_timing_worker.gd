extends SceneTree

## QSDK-R24D8 dual-mode worker.
##
## `zero_world_preflight` creates and serializes the exact evaluator-shaped
## synthetic report without constructing any physics object. `physical` is
## reachable only through the supervisor's source/nonce handshake and consumes
## the single declared timing-control world.

const RigScript := preload(
	"res://scripts/lab/rigs/r24d8_godot_jolt_active_step_snapshot_timing_rig.gd"
)

const RAW_SCHEMA := "sporespore_qsdk_r24d8_godot_jolt_active_step_snapshot_timing_raw_report_v1"
const TELEMETRY_SCHEMA := "sporespore.godot_jolt_hinge_motor_telemetry.v2"
const CLASS_NAME := &"JoltPhysicsServer3D"
const METHOD_NAME := &"hinge_joint_get_motor_telemetry"
const TERMINATION_PROTOCOL_ID := "godot_4_7_gdscript_shutdown_containment_v1"
const SUPERVISED_TERMINATION_ENV := "SPORESPORE_R24D8_SUPERVISED_TERMINATION"
const TERMINATION_NONCE_ENV := "SPORESPORE_R24D8_TERMINATION_NONCE"
const EXECUTION_NONCE_ENV := "SPORESPORE_R24D8_EXECUTION_NONCE"
const SOURCE_COMMIT_ENV := "SPORESPORE_R24D8_SOURCE_COMMIT"
const EXIT_DRAIN_PROCESS_FRAME_COUNT := 2
const TELEMETRY_FIELDS := [
	"schema",
	"telemetry_sequence",
	"capture_space_step_sequence",
	"read_space_step_sequence",
	"captured_during_active_step",
	"snapshot_is_current_space_step",
	"solver_step_s",
	"motor_state",
	"target_angular_velocity_rad_s",
	"min_torque_limit_nm",
	"max_torque_limit_nm",
	"signed_motor_impulse_nms",
	"positive_motor_work_j",
	"absorbed_motor_work_j",
	"net_motor_work_j",
]

var _exit_scheduled := false
var _pending_exit_code := 1
var _pending_receipt_kind := ""
var _pending_exit_process_frames := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := _parse_user_arguments(OS.get_cmdline_user_args())
	var mode := String(arguments.get("mode", ""))
	var source_commit := String(arguments.get("source_commit", ""))
	var nonce := String(arguments.get("nonce", ""))
	var report_path := String(arguments.get("report_path", ""))
	if mode != "zero_world_preflight" and mode != "physical":
		_emit_failure("R24D8_MODE_INVALID", 0, 0, 0)
		return
	if (
		source_commit.length() != 40
		or nonce.length() != 32
		or report_path.is_empty()
		or OS.get_environment(SOURCE_COMMIT_ENV) != source_commit
		or OS.get_environment(EXECUTION_NONCE_ENV) != nonce
	):
		_emit_failure("R24D8_AUTHORIZATION_HANDSHAKE_INVALID", 0, 0, 0)
		return
	if mode == "zero_world_preflight":
		_run_zero_world_preflight(source_commit, nonce, report_path)
		return
	await _run_physical(source_commit, nonce, report_path)


func _run_zero_world_preflight(
	source_commit: String,
	nonce: String,
	report_path: String,
) -> void:
	var engine := _engine_receipt()
	var description := RigScript.describe()
	var invalid_rid_refused := false
	if _engine_receipt_is_frozen(engine):
		invalid_rid_refused = (
			JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(RID()) == null
		)
	var report := _synthetic_report(
		source_commit,
		nonce,
		engine,
		description,
		invalid_rid_refused,
	)
	var active_physics_object_count := float(
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	)
	var ok := (
		_engine_receipt_is_frozen(engine)
		and _fixture_description_is_frozen(description)
		and invalid_rid_refused
		and TELEMETRY_FIELDS.size() == 15
		and active_physics_object_count == 0.0
		and _write_json_report(report_path, report)
	)
	print(
		"QSDK_R24D8_WORKER_ZERO_WORLD ",
		JSON.stringify(
			{
				"ok": ok,
				"source_commit": source_commit,
				"execution_nonce": nonce,
				"telemetry_schema": TELEMETRY_SCHEMA,
				"telemetry_field_count": TELEMETRY_FIELDS.size(),
				"engine_freeze_matches": _engine_receipt_is_frozen(engine),
				"fixture_description_matches": (
					_fixture_description_is_frozen(description)
				),
				"invalid_rid_refused": invalid_rid_refused,
				"synthetic_report_written": FileAccess.file_exists(report_path),
				"synthetic_embedded_world_count": 1,
				"synthetic_embedded_physics_step_count": 8,
				"synthetic_embedded_retained_sample_count": 8,
				"synthetic_envelope_is_physical_observation": false,
				"active_physics_object_count": active_physics_object_count,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"solver_step_count": 0,
				"physical_acceptance_authority": false,
				"release_authority": false,
			},
			"",
			true,
			true,
		),
	)
	_schedule_quit(0 if ok else 1, "zero_world_preflight")


func _synthetic_report(
	source_commit: String,
	nonce: String,
	engine: Dictionary,
	description: Dictionary,
	invalid_rid_refused: bool,
) -> Dictionary:
	var samples: Array[Dictionary] = []
	var final_fresh_sequence := RigScript.FRESH_ACTIVE_SAMPLE_COUNT
	for step_index in range(1, RigScript.MAXIMUM_PHYSICS_STEP_COUNT + 1):
		var is_fresh := step_index <= RigScript.FRESH_ACTIVE_SAMPLE_COUNT
		var capture_sequence := step_index if is_fresh else final_fresh_sequence
		var telemetry_sequence := step_index if is_fresh else final_fresh_sequence
		samples.append(
			{
				"step_index": step_index,
				"phase": "fresh_active" if is_fresh else "sleeping_stale",
				"child_sleeping": not is_fresh,
				"telemetry": _synthetic_telemetry(
					telemetry_sequence,
					capture_sequence,
					step_index,
					is_fresh,
				),
			}
		)
	return _report(
		"synthetic_zero_world",
		source_commit,
		nonce,
		engine,
		description,
		invalid_rid_refused,
		true,
		{
			"child_mass_kg": RigScript.CHILD_MASS_KG,
			"child_inertia_diagonal_kg_m2": _vector(
				RigScript.CHILD_INERTIA_KG_M2
			),
			"host_target_velocity_readback_rad_s": (
				RigScript.CANONICAL_TARGET_VELOCITY_RAD_S
			),
			"public_maximum_motor_impulse_readback_nms": (
				RigScript.PUBLIC_MAXIMUM_MOTOR_IMPULSE_NMS
			),
			"motor_enabled_readback": true,
			"joint_limits_enabled_readback": false,
		},
		samples,
	)


func _synthetic_telemetry(
	telemetry_sequence: int,
	capture_space_step_sequence: int,
	read_space_step_sequence: int,
	is_current: bool,
) -> Dictionary:
	return {
		"schema": TELEMETRY_SCHEMA,
		"telemetry_sequence": telemetry_sequence,
		"capture_space_step_sequence": capture_space_step_sequence,
		"read_space_step_sequence": read_space_step_sequence,
		"captured_during_active_step": true,
		"snapshot_is_current_space_step": is_current,
		"solver_step_s": 1.0 / 120.0,
		"motor_state": "velocity",
		"target_angular_velocity_rad_s": 0.0,
		"min_torque_limit_nm": -0.24,
		"max_torque_limit_nm": 0.24,
		"signed_motor_impulse_nms": 0.0,
		"positive_motor_work_j": 0.0,
		"absorbed_motor_work_j": 0.0,
		"net_motor_work_j": 0.0,
	}


func _run_physical(
	source_commit: String,
	nonce: String,
	report_path: String,
) -> void:
	var engine := _engine_receipt()
	var description := RigScript.describe()
	if not _engine_receipt_is_frozen(engine):
		_emit_failure("R24D8_ENGINE_OR_SOLVER_FREEZE_DRIFT", 0, 0, 0)
		return
	if not _fixture_description_is_frozen(description):
		_emit_failure("R24D8_FIXTURE_DECLARATION_DRIFT", 0, 0, 0)
		return
	var invalid_rid_refused := (
		JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(RID()) == null
	)
	var rig := RigScript.build()
	if not bool(rig.get("ok", false)):
		_emit_failure(
			"R24D8_FIXTURE_BUILD_FAILED",
			int(rig.get("world_attempt_count", 1)),
			int(rig.get("world_build_count", 0)),
			0,
		)
		return
	var viewport: SubViewport = rig["viewport"]
	root.add_child(viewport)
	RigScript.activate(rig)
	var samples: Array[Dictionary] = []
	var sleep_input_write_count := 0
	var pre_sample_physics_frame_count := 0
	var terminal_physics_server_deactivation_count := 0
	# SceneTree.physics_frame is emitted before PhysicsServer3D.step. Consume the
	# first boundary without sampling so sample 1 observes the completed first
	# solve at the next boundary instead of reading before any solve occurred.
	await physics_frame
	pre_sample_physics_frame_count += 1
	for step_index in range(1, RigScript.MAXIMUM_PHYSICS_STEP_COUNT + 1):
		await physics_frame
		var joint: HingeJoint3D = rig["joint"]
		var child: RigidBody3D = rig["child"]
		var telemetry_value: Variant = (
			JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(joint.get_rid())
		)
		var telemetry: Variant = null
		if telemetry_value is Dictionary:
			telemetry = (telemetry_value as Dictionary).duplicate(true)
		var is_fresh_phase := step_index <= RigScript.FRESH_ACTIVE_SAMPLE_COUNT
		samples.append(
			{
				"step_index": step_index,
				"phase": (
					"fresh_active" if is_fresh_phase else "sleeping_stale"
				),
				"child_sleeping": child.sleeping,
				"telemetry": telemetry,
			}
		)
		if step_index == RigScript.FRESH_ACTIVE_SAMPLE_COUNT:
			RigScript.force_declared_sleep(rig)
			sleep_input_write_count += 1
	# This callback is running at the boundary immediately after solve 8 and
	# before solve 9. Disable the isolated server now so shutdown/drain frames
	# cannot add an unreported ninth JoltSpace3D step.
	PhysicsServer3D.set_active(false)
	terminal_physics_server_deactivation_count += 1
	var report := _report(
		"native_physical",
		source_commit,
		nonce,
		engine,
		description,
		invalid_rid_refused,
		bool(rig["pre_tree_read_refused"]),
		RigScript.parameter_readback(rig),
		samples,
	)
	report["execution"]["declared_sleep_input_write_count"] = (
		sleep_input_write_count
	)
	report["execution"]["pre_sample_physics_frame_count"] = (
		pre_sample_physics_frame_count
	)
	report["execution"]["terminal_physics_server_deactivation_count"] = (
		terminal_physics_server_deactivation_count
	)
	var wrote_report := _write_json_report(report_path, report)
	print(
		"QSDK_R24D8_PHYSICAL_RAW_REPORT ",
		JSON.stringify(
			{
				"ok": wrote_report,
				"source_commit": source_commit,
				"execution_nonce": nonce,
				"report_path": report_path,
				"world_attempt_count": 1,
				"world_build_count": 1,
				"solver_step_count": RigScript.MAXIMUM_PHYSICS_STEP_COUNT,
				"retained_sample_count": samples.size(),
				"pre_sample_physics_frame_count": (
					pre_sample_physics_frame_count
				),
				"terminal_physics_server_deactivation_count": (
					terminal_physics_server_deactivation_count
				),
				"physical_acceptance_authority": false,
				"release_authority": false,
			},
			"",
			true,
			true,
		),
	)
	viewport.queue_free()
	_schedule_quit(0 if wrote_report else 1, "physical_raw_report")


func _report(
	evidence_kind: String,
	source_commit: String,
	nonce: String,
	engine: Dictionary,
	description: Dictionary,
	invalid_rid_refused: bool,
	pre_tree_read_refused: bool,
	parameter_readback: Dictionary,
	samples: Array[Dictionary],
) -> Dictionary:
	return {
		"schema_version": RAW_SCHEMA,
		"gate_id": "QSDK-R24D8",
		"question_class": "development",
		"evidence_kind": evidence_kind,
		"source_commit": source_commit,
		"execution_nonce": nonce,
		"engine": engine,
		"fixture": description,
		"refusals": {
			"invalid_rid_refused": invalid_rid_refused,
			"not_in_tree_joint_read_refused": pre_tree_read_refused,
		},
		"parameter_readback": parameter_readback,
		"samples": samples,
		"execution": {
			"world_attempt_count": 1,
			"world_build_count": 1,
			"physics_step_count": RigScript.MAXIMUM_PHYSICS_STEP_COUNT,
			"retained_sample_count": samples.size(),
			"direct_force_write_count": 0,
			"direct_torque_write_count": 0,
			"direct_impulse_write_count": 0,
			"post_activation_transform_write_count": 0,
			"declared_sleep_input_write_count": 1,
			"pre_sample_physics_frame_count": 1,
			"terminal_physics_server_deactivation_count": 1,
			"outcome_dependent_early_stop_count": 0,
		},
		"evidence_provenance": {
			"synthetic_shape_only": evidence_kind == "synthetic_zero_world",
			"native_physical_observation": evidence_kind == "native_physical",
		},
		"claims": {
			"descriptive_development_timing_only": true,
			"instrumented_profile_promoted": false,
			"stock_godot_profile_promoted": false,
			"native_numerical_telemetry_characterized": false,
			"recovery_claimed": false,
			"prone_to_standing_claimed": false,
			"turning_claim_changed": false,
			"cross_engine_equivalence_claimed": false,
			"physical_acceptance_authority": false,
			"release_authority": false,
		},
	}


func _engine_receipt() -> Dictionary:
	var separate_thread := bool(
		ProjectSettings.get_setting("physics/3d/run_on_separate_thread", false)
	)
	return {
		"physics_engine": String(
			ProjectSettings.get_setting("physics/3d/physics_engine", "")
		),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"solver_velocity_steps": int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/velocity_steps",
				-1,
			)
		),
		"solver_position_steps": int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/position_steps",
				-1,
			)
		),
		"thread_model": "separate" if separate_thread else "single_safe",
		"telemetry_class_registered": ClassDB.class_exists(CLASS_NAME),
		"telemetry_method_registered": ClassDB.class_has_method(
			CLASS_NAME,
			METHOD_NAME,
		),
	}


func _engine_receipt_is_frozen(engine: Dictionary) -> bool:
	return (
		String(engine.get("physics_engine", "")) == "Jolt Physics"
		and int(engine.get("physics_ticks_per_second", -1)) == 120
		and int(engine.get("solver_velocity_steps", -1)) == 20
		and int(engine.get("solver_position_steps", -1)) == 7
		and String(engine.get("thread_model", "")) == "single_safe"
		and bool(engine.get("telemetry_class_registered", false))
		and bool(engine.get("telemetry_method_registered", false))
	)


func _fixture_description_is_frozen(description: Dictionary) -> bool:
	return (
		String(description.get("fixture_id", "")) == RigScript.FIXTURE_ID
		and int(description.get("world_count", -1)) == 1
		and int(description.get("isolated_hinge_count", -1)) == 1
		and int(description.get("dynamic_body_count", -1)) == 1
		and int(description.get("static_parent_count", -1)) == 1
		and description.get("hinge_axis_parent_local", []) == [0.0, 0.0, 1.0]
		and int(description.get("fresh_active_sample_count", -1)) == 4
		and int(description.get("sleeping_stale_sample_count", -1)) == 4
		and int(description.get("maximum_physics_step_count", -1)) == 8
		and int(description.get("retained_sample_count", -1)) == 8
		and int(description.get("world_attempt_count", -1)) == 0
		and int(description.get("world_build_count", -1)) == 0
		and int(description.get("solver_step_count", -1)) == 0
	)


func _write_json_report(path: String, report: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(report, "", true, true) + "\n")
	file.close()
	return FileAccess.file_exists(path)


func _emit_failure(
	code: String,
	world_attempt_count: int,
	world_build_count: int,
	solver_step_count: int,
) -> void:
	print(
		"QSDK_R24D8_WORKER_FAILURE ",
		JSON.stringify(
			{
				"ok": false,
				"failure_code": code,
				"world_attempt_count": world_attempt_count,
				"world_build_count": world_build_count,
				"solver_step_count": solver_step_count,
				"physical_acceptance_authority": false,
				"release_authority": false,
			},
			"",
			true,
			true,
		),
	)
	_schedule_quit(1, "worker_failure")


func _schedule_quit(exit_code: int, receipt_kind: String) -> void:
	if _exit_scheduled:
		push_error("QSDK-R24D8 duplicate orderly-exit schedule")
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
	if OS.get_environment(SUPERVISED_TERMINATION_ENV) == "1":
		var termination_nonce := OS.get_environment(TERMINATION_NONCE_ENV)
		if termination_nonce.is_empty():
			quit(1)
			return
		print(
			"QSDK_R24D8_GODOT_SUPERVISOR_TERMINATION_READY ",
			JSON.stringify(
				{
					"schema_version": (
						"sporespore_godot_supervised_termination_ready_v1"
					),
					"termination_protocol_id": TERMINATION_PROTOCOL_ID,
					"termination_nonce": termination_nonce,
					"process_id": OS.get_process_id(),
					"requested_exit_code": _pending_exit_code,
					"worker_receipt_kind": _pending_receipt_kind,
					"worker_receipt_emitted": true,
					"drained_process_frame_count": (
						EXIT_DRAIN_PROCESS_FRAME_COUNT
					),
					"physics_evidence_authority": false,
				},
				"",
				true,
				true,
			),
		)
		return
	quit(_pending_exit_code)


func _parse_user_arguments(arguments: PackedStringArray) -> Dictionary:
	var parsed := {}
	for argument in arguments:
		var separator := argument.find("=")
		if not argument.begins_with("--") or separator <= 2:
			continue
		parsed[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
	return parsed


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
