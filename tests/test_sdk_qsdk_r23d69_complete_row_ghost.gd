extends SceneTree
# gdlint: disable=max-line-length

## Seven zero-world rows through the exact Godot production composer and the
## exact R23D69 projection used immediately before trace retention.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const WorkerScript := preload("res://tests/test_sdk_qsdk_r23d69_godot_jolt_worker.gd")

const STEPS := [599, 600, 1799, 1800, 2399, 2400, 2991]
const SEGMENTS := [
	"reference_warmup",
	"commanded_turn",
	"commanded_turn",
	"reference_recovery",
	"reference_recovery",
	"reference_continuation",
	"reference_continuation",
]
const LIMBS := ["rear_left", "front_left", "rear_right", "front_right"]
const ACTUATORS := [
	"rear_left_hip_motor",
	"rear_left_knee_motor",
	"front_left_hip_motor",
	"front_left_knee_motor",
	"rear_right_hip_motor",
	"rear_right_knee_motor",
	"front_right_hip_motor",
	"front_right_knee_motor",
]


func _initialize() -> void:
	call_deferred("_run")


func _fail(code: String, detail: Dictionary = {}) -> void:
	printerr("QSDK_R23D69_GODOT_COMPLETE_ROW_GHOST_FAILURE ", code, " ", JSON.stringify(detail))
	quit(1)


func _run() -> void:
	var rows: Array = []
	for index in range(STEPS.size()):
		var composed := _compose_complete_row(int(STEPS[index]))
		if not bool(composed.get("ok", false)):
			_fail("COMPOSITION_FAILED:%s" % int(STEPS[index]), composed)
			return
		var projection := WorkerScript._r23d69_project_complete_trace_row(
			composed["row"],
			int(STEPS[index]),
			{"cell_id": "r23d69__godot_jolt__s23187__reference_zero"},
		)
		if not bool(projection.get("ok", false)):
			_fail("PROJECTION_FAILED:%s" % int(STEPS[index]), projection)
			return
		var row: Dictionary = projection["row"]
		var strict_text := JSON.stringify(row, "", true, true)
		var strict_round_trip: Variant = JSON.parse_string(strict_text)
		var exact := (
			typeof(strict_round_trip) == TYPE_DICTIONARY
			and String(row.get("schema_version", ""))
			== "sporespore_qsdk_r23d69_turning_trace_row_v1"
			and String(row.get("campaign_id", ""))
			== "QSDK-R23D69-COMPLETE-PRODUCTION-ROW-CONFORMANCE-REPAIRED-THREE-ENGINE-TURNING-VALIDATION"
			and String(row.get("gate_id", "")) == "QSDK-R23D69"
			and String(row.get("stage_id", ""))
			== "complete_production_row_conformance_repaired_three_engine_turning_validation"
			and String(row.get("engine_id", "")) == "godot_jolt"
			and int(row.get("campaign_seed", -1)) == 23187
			and int(row.get("semantic_step", -1)) == int(STEPS[index])
			and int(row.get("trace_step", -1)) == int(STEPS[index])
			and String(row.get("segment_id", "")) == String(SEGMENTS[index])
			and typeof(row.get("actuator_phase_observation", null)) == TYPE_DICTIONARY
		)
		if not exact:
			_fail("ROW_CONTRACT_FAILED:%s" % int(STEPS[index]), row)
			return
		rows.append(row)
	print(
		"QSDK_R23D69_GODOT_COMPLETE_ROW_GHOST ",
		JSON.stringify(
			{
				"schema_version": "sporespore_qsdk_r23d69_godot_complete_row_ghost_v1",
				"ok": true,
				"representative_semantic_steps": STEPS,
				"representative_complete_row_count": rows.size(),
				"actual_shared_row_composer_used": true,
				"actual_production_projection_used": true,
				"actuator_phase_observation_validated_per_row": true,
				"strict_json_round_trip_count": rows.size(),
				"model_construction_count": 0,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			},
			"",
			true,
			true,
		),
	)
	quit(0)


static func _compose_complete_row(semantic_step: int) -> Dictionary:
	var trace_options := {
		"cell_id": "r23d69__godot_jolt__s23187__reference_zero",
		"exact_controller_step_count": 2992,
		"policy_id": "qsdk_r23d3_phase_balanced_trace_v1",
		"post_schedule_segment_id": "reference_continuation",
		"recovery_duration_steps": 600,
		"turn_duration_steps": 1200,
		"turn_heading_offset_rad": 0.0,
		"turn_start_semantic_step": 600,
		"trace_row_schema_version": "sporespore_qsdk_r23d69_turning_trace_row_v1",
		"actuator_phase_observation_schema_version": (
			WaveGaitScript.SDK_GODOT_ACTUATOR_PHASE_OBSERVATION_SCHEMA
		),
	}
	var compiled := WaveGaitScript.compile_sdk_physical_trace_options(trace_options)
	if not bool(compiled.get("ok", false)):
		return compiled
	var state := {
		"semantic_step": semantic_step,
		"base_pose_world": {
			"position_m": {"x": 0.0, "y": 0.4, "z": 0.0},
			"orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
		},
		"base_twist_world": {
			"linear_velocity_m_s": {"x": 0.1, "y": 0.0, "z": 0.0},
		},
		"task_frame": {
			"origin_world_m": {"x": 0.0, "y": 0.4, "z": 0.0},
			"forward_axis_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
			"lateral_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
			"reference_yaw_rad": 0.0,
		},
	}
	var command := {
		"desired_heading_rad": 0.0,
		"valid_from_step": semantic_step,
		"valid_through_step": semantic_step,
	}
	var profile := {
		"cross_track_frame_mode_id": "",
		"cross_track_heading_gain_rad_per_m": 0.0,
		"cross_track_velocity_heading_gain_rad_per_m_s": 0.0,
		"maximum_desired_heading_error_rad": 0.25,
	}
	var oracle := WaveGaitScript._r23d3_independent_oracle(state, command, profile)
	if not bool(oracle.get("ok", false)):
		return oracle
	var receipt: Dictionary = (oracle["expected_receipt"] as Dictionary).duplicate(true)
	receipt["requested_steering_fraction"] = 0.0
	receipt["held_steering_fraction"] = 0.0
	var memory_rows: Array = []
	for limb_id in LIMBS:
		memory_rows.append(
			{
				"limb_id": limb_id,
				"gait_step": semantic_step,
				"release_hold_step_count": 0,
			}
		)
	var sample_result := {
		"ok": true,
		"request": {
			"memory": {
				"schema_version": "sporespore_balanced_wave_controller_memory_v8",
				"ordered_limb_memory": memory_rows,
				"steering_guard_floor_hold_steps_remaining": 0,
			},
			"state": state,
			"command": command,
		},
		"heading_command_receipt": {
			"semantic_step": semantic_step,
			"heading_offset_rad": 0.0,
		},
	}
	var commands: Array = []
	var applications: Array = []
	for index in range(ACTUATORS.size()):
		var actuator_id := String(ACTUATORS[index])
		var limb_id := String(LIMBS[index / 2])
		commands.append(
			{
				"actuator_id": actuator_id,
				"target_velocity_rad_s": 0.1,
				"maximum_target_speed_rad_s": 1.0,
				"position_saturated": false,
				"velocity_saturated": false,
				"slew_limited": false,
			}
		)
		applications.append(
			{
				"actuator_id": actuator_id,
				"joint_id": "%s_joint" % actuator_id,
				"host_joint_id": "%s_joint" % actuator_id,
				"limb_id": limb_id,
				"limb_joint_index": index % 2,
				"requested_target_position_rad": 0.0,
				"clamped_target_position_rad": 0.0,
				"controller_target_velocity_rad_s": 0.1,
				"maximum_target_speed_rad_s": 1.0,
				"host_applied_target_velocity_rad_s": 0.1,
				"motor_target_velocity_readback_rad_s": 0.1,
				"motor_target_velocity_readback_error_rad_s": 0.0,
				"declared_maximum_impulse_nms": 0.01,
				"motor_maximum_impulse_readback_nms": 0.01,
				"motor_maximum_impulse_readback_error_nms": 0.0,
				"position_saturated": false,
				"velocity_saturated": false,
				"slew_limited": false,
				"host_additional_clamp_applied": false,
				"target_velocity_readback_matches": true,
				"maximum_impulse_readback_matches": true,
			}
		)
	var step_result := {
		"ok": true,
		"semantic_step": semantic_step,
		"controller_step_receipt_sha256": "sha256:" + "0".repeat(64),
		"native_output": {
			"actuation": {
				"receipt": receipt,
				"ordered_commands": commands,
			},
		},
	}
	var application := {
		"ok": true,
		"schema_version": "sporespore_godot_jolt_full_authority_application_receipt_v1",
		"semantic_step": semantic_step,
		"applied_command_count": ACTUATORS.size(),
		"ordered_actuator_ids": ACTUATORS,
		"readback_tolerance": 2.5e-7,
		"ordered_applications": applications,
		"configured_motor_parameters_only": true,
		"measured_motor_torque_available": false,
		"measured_motor_impulse_available": false,
	}
	var contacts := {
		"rear_left": true,
		"front_left": true,
		"rear_right": true,
		"front_right": true,
	}
	var composed := WaveGaitScript._compose_sdk_physical_trace_row(
		trace_options,
		sample_result,
		step_result,
		application,
		semantic_step,
		contacts,
		0.0,
		false,
		profile,
	)
	if not bool(composed.get("ok", false)):
		return composed
	return WaveGaitScript.complete_sdk_actuator_phase_observation(
		composed["row"],
		contacts,
	)
