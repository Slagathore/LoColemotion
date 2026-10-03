extends "res://tests/test_sdk_qsdk_r24d13_godot_jolt_braking_mechanism_activation_worker.gd"

## QSDK-R24D14 zero-step native float-projection worker.
##
## This worker deliberately cannot open a physical mode. It allocates one
## unconfigured native hinge RID outside the SceneTree, exercises the same
## real_t property readback that appeared in the R24D13 physical report, and
## projects the Jolt telemetry timestep through two independent float32 stores.

const R24D14Rig := preload(
	"res://scripts/lab/rigs/r24d13_godot_jolt_braking_mechanism_activation_rig.gd"
)
const R24D14_RAW_SCHEMA := (
	"sporespore_qsdk_r24d14_godot_jolt_braking_mechanism_activation_raw_report_v1"
)
const R24D14_SUPERVISED_TERMINATION_ENV := (
	"SPORESPORE_R24D14_SUPERVISED_TERMINATION"
)
const R24D14_TERMINATION_NONCE_ENV := "SPORESPORE_R24D14_TERMINATION_NONCE"
const R24D14_EXECUTION_NONCE_ENV := "SPORESPORE_R24D14_EXECUTION_NONCE"
const R24D14_SOURCE_COMMIT_ENV := "SPORESPORE_R24D14_SOURCE_COMMIT"
const R24D14_TERMINATION_PROTOCOL_ID := (
	"godot_4_7_gdscript_shutdown_containment_v1"
)
const R24D14_EXIT_DRAIN_PROCESS_FRAME_COUNT := 2
const R24D14_REJECTED_R24D13_IMPULSE := 0.0020000000949949
const R24D14_REJECTED_R24D13_TIMESTEP := 0.00833333376795053

var _r24d14_exit_scheduled := false
var _r24d14_pending_exit_code := 1
var _r24d14_pending_receipt_kind := "worker_failure"
var _r24d14_pending_exit_process_frames := 0


func _run() -> void:
	var arguments := _parse_user_arguments(OS.get_cmdline_user_args())
	var mode := String(arguments.get("mode", ""))
	var source_commit := String(arguments.get("source_commit", ""))
	var nonce := String(arguments.get("nonce", ""))
	var report_path := String(arguments.get("report_path", ""))
	if mode != "native_projection_preflight":
		_r24d14_emit_failure("R24D14_MODE_REFUSED", 0, 0, 0)
		return
	if (
		source_commit.length() != 40
		or nonce.length() != 32
		or report_path.is_empty()
		or OS.get_environment(R24D14_SOURCE_COMMIT_ENV) != source_commit
		or OS.get_environment(R24D14_EXECUTION_NONCE_ENV) != nonce
	):
		_r24d14_emit_failure("R24D14_AUTHORIZATION_HANDSHAKE_INVALID", 0, 0, 0)
		return
	_r24d14_run_native_projection_preflight(source_commit, nonce, report_path)


func _r24d14_run_native_projection_preflight(
	source_commit: String,
	nonce: String,
	report_path: String,
) -> void:
	PhysicsServer3D.set_active(false)
	var engine := _engine_receipt()
	var description := R24D14Rig.describe()
	var active_objects_before := float(
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	)
	var invalid_rid_refused := false
	if _engine_receipt_is_frozen(engine):
		invalid_rid_refused = (
			JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(RID()) == null
		)

	var joint := HingeJoint3D.new()
	var native_joint_rid_valid := joint.get_rid().is_valid()
	joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 0.002)
	var native_impulse_readback := joint.get_param(
		HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE
	)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 1.0 / 120.0)
	var native_timestep_carrier_readback := joint.get_param(
		HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY
	)
	var timestep_float32_store := PackedFloat32Array([1.0 / 120.0])
	var native_timestep_projection := timestep_float32_store[0]
	var impulse_float32_store := PackedFloat32Array([0.002])
	var native_impulse_projection := impulse_float32_store[0]

	var native_inertia_readback: Array = description.get(
		"child_inertia_diagonal_kg_m2",
		[],
	)
	var cells: Array[Dictionary] = _r24d13_zero_world_cells(
		native_inertia_readback
	)
	for cell in cells:
		var parameter_readback: Dictionary = cell["parameter_readback"]
		parameter_readback["public_maximum_motor_impulse_nms"] = (
			native_impulse_readback
		)
		var sample: Dictionary = (cell["samples"] as Array)[0]
		var telemetry: Dictionary = sample["telemetry"]
		telemetry["solver_step_s"] = native_timestep_projection
		if bool(cell["motor_enabled"]):
			var pre_rate := float(sample["pre_canonical_relative_rate_rad_s"])
			var signed_impulse := (
				-native_impulse_readback if pre_rate > 0.0
				else native_impulse_readback
			)
			telemetry["signed_motor_impulse_nms"] = signed_impulse
			sample["post_canonical_relative_rate_rad_s"] = (
				pre_rate + signed_impulse / 0.05
			)

	var report := super._r24d13_report(
		"synthetic_zero_world",
		source_commit,
		nonce,
		engine,
		description,
		invalid_rid_refused,
		{
			"brake_positive": true,
			"brake_negative": true,
			"disabled_positive": true,
			"disabled_negative": true,
		},
		_r24d13_zero_world_activation_receipts(),
		cells,
	)
	report["schema_version"] = R24D14_RAW_SCHEMA
	report["gate_id"] = "QSDK-R24D14"
	var report_fixture: Dictionary = (report["fixture"] as Dictionary).duplicate(true)
	report_fixture["fixture_id"] = (
		"QSDK.R24D14.godot_jolt_braking_mechanism_activation.v1"
	)
	report["fixture"] = report_fixture

	var serialized_report := JSON.stringify(report, "", true, true)
	var reparsed_value: Variant = JSON.parse_string(serialized_report)
	var godot_reparsed_impulse := 0.0
	var godot_reparsed_timestep := 0.0
	if reparsed_value is Dictionary:
		var reparsed_cells: Array = (reparsed_value as Dictionary).get("cells", [])
		if reparsed_cells.size() == 4:
			var reparsed_cell: Dictionary = reparsed_cells[0]
			var reparsed_parameter: Dictionary = reparsed_cell.get(
				"parameter_readback",
				{},
			)
			godot_reparsed_impulse = float(
				reparsed_parameter.get("public_maximum_motor_impulse_nms", 0.0)
			)
			var reparsed_samples: Array = reparsed_cell.get("samples", [])
			if reparsed_samples.size() == 1:
				var reparsed_telemetry: Dictionary = (
					(reparsed_samples[0] as Dictionary).get("telemetry", {})
				)
				godot_reparsed_timestep = float(
					reparsed_telemetry.get("solver_step_s", 0.0)
				)

	var native_impulse_matches := (
		native_impulse_readback == native_impulse_projection
	)
	var native_timestep_matches := (
		native_timestep_carrier_readback == native_timestep_projection
	)
	var adjacent_negative_controls_pass := (
		native_impulse_readback != R24D14_REJECTED_R24D13_IMPULSE
		and native_timestep_projection != R24D14_REJECTED_R24D13_TIMESTEP
	)
	var full_precision_text_matches := (
		serialized_report.find("0.0020000000949949026") >= 0
		and serialized_report.find("0.008333333767950535") >= 0
	)
	var godot_json_round_trip_matches_native := (
		godot_reparsed_impulse == native_impulse_readback
		and godot_reparsed_timestep == native_timestep_projection
	)
	var report_written := _write_json_report(report_path, report)
	joint.free()
	var active_objects_after := float(
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	)
	var engine_freeze_matches := _engine_receipt_is_frozen(engine)
	var fixture_description_matches := (
		_r24d13_fixture_description_is_frozen(description)
	)
	var ok := (
		engine_freeze_matches
		and fixture_description_matches
		and invalid_rid_refused
		and native_joint_rid_valid
		and native_impulse_matches
		and native_timestep_matches
		and adjacent_negative_controls_pass
		and full_precision_text_matches
		and report_written
		and active_objects_before == 0.0
		and active_objects_after == 0.0
	)
	print(
		"QSDK_R24D14_NATIVE_PROJECTION ",
		JSON.stringify(
			{
				"ok": ok,
				"source_commit": source_commit,
				"execution_nonce": nonce,
				"engine_freeze_matches": engine_freeze_matches,
				"fixture_description_matches": fixture_description_matches,
				"invalid_rid_refused": invalid_rid_refused,
				"native_joint_rid_valid": native_joint_rid_valid,
				"native_joint_allocation_count": 1,
				"native_joint_release_call_count": 1,
				"native_impulse_readback_nms": native_impulse_readback,
				"native_impulse_float32_projection_nms": (
					native_impulse_projection
				),
				"native_timestep_carrier_readback_s": (
					native_timestep_carrier_readback
				),
				"native_timestep_float32_projection_s": (
					native_timestep_projection
				),
				"godot_reparsed_impulse_nms": godot_reparsed_impulse,
				"godot_reparsed_timestep_s": godot_reparsed_timestep,
				"godot_json_round_trip_matches_native": (
					godot_json_round_trip_matches_native
				),
				"godot_json_parser_is_production_evaluator": false,
				"production_evaluator_parser": "python_json",
				"adjacent_negative_controls_pass": (
					adjacent_negative_controls_pass
				),
				"full_precision_text_matches": full_precision_text_matches,
				"native_impulse_matches": native_impulse_matches,
				"native_timestep_matches": native_timestep_matches,
				"report_written": report_written,
				"active_physics_object_count_before": active_objects_before,
				"active_physics_object_count_after": active_objects_after,
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
	_r24d14_schedule_quit(0 if ok else 1, "native_projection_preflight")


func _r24d14_emit_failure(
	code: String,
	world_attempt_count: int,
	world_build_count: int,
	solver_step_count: int,
) -> void:
	PhysicsServer3D.set_active(false)
	print(
		"QSDK_R24D14_WORKER_FAILURE ",
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
	_r24d14_schedule_quit(1, "worker_failure")


func _r24d14_schedule_quit(exit_code: int, receipt_kind: String) -> void:
	if _r24d14_exit_scheduled:
		push_error("QSDK-R24D14 duplicate orderly-exit schedule")
		return
	_r24d14_exit_scheduled = true
	_r24d14_pending_exit_code = exit_code
	_r24d14_pending_receipt_kind = receipt_kind
	_r24d14_pending_exit_process_frames = R24D14_EXIT_DRAIN_PROCESS_FRAME_COUNT
	process_frame.connect(_r24d14_orderly_exit_process_frame, CONNECT_ONE_SHOT)


func _r24d14_orderly_exit_process_frame() -> void:
	_r24d14_pending_exit_process_frames -= 1
	if _r24d14_pending_exit_process_frames > 0:
		process_frame.connect(_r24d14_orderly_exit_process_frame, CONNECT_ONE_SHOT)
		return
	if OS.get_environment(R24D14_SUPERVISED_TERMINATION_ENV) == "1":
		var termination_nonce := OS.get_environment(R24D14_TERMINATION_NONCE_ENV)
		if termination_nonce.is_empty():
			quit(1)
			return
		print(
			"QSDK_R24D14_GODOT_SUPERVISOR_TERMINATION_READY ",
			JSON.stringify(
				{
					"schema_version": (
						"sporespore_godot_supervised_termination_ready_v1"
					),
					"termination_protocol_id": R24D14_TERMINATION_PROTOCOL_ID,
					"termination_nonce": termination_nonce,
					"process_id": OS.get_process_id(),
					"requested_exit_code": _r24d14_pending_exit_code,
					"worker_receipt_kind": _r24d14_pending_receipt_kind,
					"worker_receipt_emitted": true,
					"drained_process_frame_count": (
						R24D14_EXIT_DRAIN_PROCESS_FRAME_COUNT
					),
					"physics_evidence_authority": false,
				},
				"",
				true,
				true,
			),
		)
		return
	quit(_r24d14_pending_exit_code)
