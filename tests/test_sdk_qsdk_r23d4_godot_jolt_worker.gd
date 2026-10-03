extends "res://tests/test_sdk_qsdk_r23d3_godot_jolt_worker.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Prospective Godot/Jolt worker for the distinct QSDK-R23D4 campaign.
##
## R23D3 remains closed. This worker reuses only its pinned fixture/controller
## construction, adds the preregistered portable terminal restorer, and traces
## the complete controller, restoration, and passive-settle horizon.

const R23D3WorkerScript := preload("res://tests/test_sdk_qsdk_r23d3_godot_jolt_worker.gd")
const R4WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const R4RestorationScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_terminal_restoration.gd"
)

const R4_PREREGISTRATION_PATH := (
	"res://sdk/turning/r23d4_terminal_stabilization_preregistration_v1.json"
)
const R4_R23D3_CLOSURE_PATH := "res://sdk/turning/r23d3_physical_closure_v1.json"
const R4_MUJOCO_RESTORATION_CLOSURE_PATH := (
	"res://sdk/mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.json"
)
const R4_RAPIER_RESTORATION_CLOSURE_PATH := (
	"res://sdk/rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json"
)
const R4_PHYSICAL_EVALUATOR_PATH := "res://sdk/turning/r23d4_physical_evaluator.py"
const R4_TRACE_PUBLISHER_PATH := "res://sdk/publish_qsdk_r23d4_trace.ps1"
const R4_WORKER_PATH := "res://tests/test_sdk_qsdk_r23d4_godot_jolt_worker.gd"
const R4_BASE_WORKER_PATH := "res://tests/test_sdk_qsdk_r23d3_godot_jolt_worker.gd"
const R4_RUNNER_PATH := "res://scripts/lab/gait/physical_wave_gait_quadruped.gd"
const R4_ADAPTER_PATH := "res://scripts/lab/gait/sdk_godot_jolt_adapter.gd"
const R4_RESTORER_PATH := (
	"res://scripts/lab/gait/sdk_godot_jolt_terminal_restoration.gd"
)
const R4_CLOSURE_PATH := "res://sdk/turning/r23d4_physical_closure_v1.json"

const R4_CAMPAIGN_ID := "QSDK-R23D4-TERMINAL-STABILIZED-BILATERAL-TURN-DEVELOPMENT"
const R4_GATE_ID := "QSDK-R23D4"
const R4_ENGINE_ID := "godot_jolt"
const R4_PREFLIGHT_SCHEMA := "sporespore_qsdk_r23d4_godot_jolt_worker_preflight_v1"
const R4_REPORT_SCHEMA := "sporespore_qsdk_r23d4_engine_cell_report_v1"
const R4_FAILURE_SCHEMA := "sporespore_qsdk_r23d4_worker_failure_v1"
const R4_FREEZE_SCHEMA := "sporespore_qsdk_r23d4_physical_freeze_v1"
const R4_ATTEMPT_SCHEMA := "sporespore_qsdk_r23d4_attempt_v1"
const R4_TRACE_RETENTION_SCHEMA := "sporespore_qsdk_r23d4_trace_retention_v1"
const R4_GODOT_PREDICATE_SCHEMA := (
	"sporespore_qsdk_r23d4_godot_execution_predicates_v1"
)
const R4_TRACE_SCHEMA := "sporespore_qsdk_r23d4_turn_restore_settle_trace_v1"
const R4_TRACE_ROW_SCHEMA := (
	"sporespore_qsdk_r23d4_turn_restore_settle_trace_row_v1"
)
const R4_CONTROLLER_STEPS := 2992
const R4_RESTORATION_STEPS := 540
const R4_PASSIVE_STEPS := 240
const R4_ACTIVE_STEPS := 3532
const R4_TOTAL_STEPS := 3772
const R4_ACTUATOR_COUNT := 8
const R4_HORIZON_POLICY_ID := "qsdk_r23d4_fixed_turning_controller_horizon_v1"
const R4_HORIZON_POLICY_SHA256 := (
	"sha256:42efe3d41f9115bc12613657668c2bd318367828717169dd14d74f7de0e134e7"
)

const R4_FREEZE_PATH_ENV := "SPORESPORE_QSDK_R23D4_FREEZE"
const R4_ATTEMPT_PATH_ENV := "SPORESPORE_QSDK_R23D4_ATTEMPT"
const R4_TOKEN_ENV := "SPORESPORE_QSDK_R23D4_TOKEN"
const R4_STAGE_ENV := "SPORESPORE_QSDK_R23D4_STAGE"
const R4_CELL_ENV := "SPORESPORE_QSDK_R23D4_CELL"
const R4_ENGINE_ENV := "SPORESPORE_QSDK_R23D4_ENGINE"
const R4_ATTEMPT_ROOT_ENV := "SPORESPORE_QSDK_R23D4_ATTEMPT_ROOT"
const R4_PYTHON_ENV := "SPORESPORE_QSDK_R23D4_PYTHON"
const R4_POWERSHELL_ENV := "SPORESPORE_QSDK_R23D4_POWERSHELL"

const R4_ARM_OFFSETS := {
	"reference_zero": 0.0,
	"positive_heading": 0.2,
	"negative_heading": -0.2,
}
const R4_FALSE_CLAIMS := {
	"command_conditioned_turning": false,
	"bilateral_signed_turning": false,
	"portable_basic_turning": false,
	"cross_engine_equivalence": false,
	"q_sdk_r23_satisfied": false,
	"prone_to_standing": false,
	"release_authorized": false,
	"physical_acceptance_authority": false,
}


func _run() -> void:
	var parsed := _r4_parse_arguments(OS.get_cmdline_user_args())
	if not bool(parsed.get("ok", false)):
		print("QSDK_R23D4_GODOT_JOLT_FAILURE ", JSON.stringify(parsed))
		quit(1)
		return
	var cell := _r4_cell(String(parsed["stage_id"]), String(parsed["arm_id"]))
	if not bool(cell.get("ok", false)):
		print("QSDK_R23D4_GODOT_JOLT_FAILURE ", JSON.stringify(cell))
		quit(1)
		return
	if bool(parsed["preflight_only"]):
		var preflight: Dictionary = await _r4_run_preflight(cell)
		if not bool(preflight.get("ok", false)):
			print("QSDK_R23D4_GODOT_JOLT_FAILURE ", JSON.stringify(preflight))
			quit(1)
			return
		print("QSDK_R23D4_GODOT_JOLT_PREFLIGHT ", JSON.stringify(preflight))
		quit(0)
		return
	var terminal: Dictionary = await _r4_run_physical(cell, String(parsed["source_commit"]))
	if String(terminal.get("schema_version", "")) == R4_REPORT_SCHEMA:
		print("QSDK_R23D4_GODOT_JOLT_CELL ", JSON.stringify(terminal))
		quit(0)
		return
	print("QSDK_R23D4_GODOT_JOLT_FAILURE ", JSON.stringify(terminal))
	quit(1)


func _r4_run_preflight(cell: Dictionary) -> Dictionary:
	var solver_receipt := R23D3WorkerScript._apply_solver_configuration()
	var prepared := _r4_prepare(cell)
	if not bool(solver_receipt.get("ok", false)) or not bool(prepared.get("ok", false)):
		return _r4_failure("QSDK_R23D4_GJT_PREPARE_INVALID")
	var entrypoint: Dictionary = await _r4_run_wave(prepared, true)
	var adapter_boundary := R23D3WorkerScript._adapter_boundary(prepared, cell)
	var restoration_canary := R4RestorationScript.run_zero_world_preflight()
	var trace_canary := _r4_trace_canary(prepared["terminal_options"])
	var predicate_controls := _r4_predicate_negative_controls()
	var entrypoint_exact: bool = (
		bool(entrypoint.get("ok", false))
		and int(entrypoint.get("actual_world_build_count", -1)) == 0
		and int(entrypoint.get("scene_tree_insertion_count", -1)) == 0
		and not bool(entrypoint.get("physics_state_modified", true))
		and bool(entrypoint.get("candidate_authority_horizon_enabled", false))
		and int(entrypoint.get("candidate_authority_observation_count", -1))
		== R4_CONTROLLER_STEPS
		and String(entrypoint.get("authority_horizon_policy_id", ""))
		== R4_HORIZON_POLICY_ID
		and String(entrypoint.get("authority_horizon_policy_sha256", ""))
		== R4_HORIZON_POLICY_SHA256
		and not bool(entrypoint.get("sdk_physical_trace_enabled", true))
		and bool(entrypoint.get("sdk_terminal_restoration_enabled", false))
		and (
			entrypoint.get("sdk_terminal_restoration_options", {}) as Dictionary
		) == prepared["compiled_terminal_options"]
	)
	if (
		not entrypoint_exact
		or not bool(adapter_boundary.get("ok", false))
		or not bool(restoration_canary.get("ok", false))
		or not bool(trace_canary.get("ok", false))
		or not bool(predicate_controls.get("ok", false))
	):
		return _r4_failure(
			"QSDK_R23D4_GJT_PREFLIGHT_INVALID",
			{
				"entrypoint": entrypoint,
				"adapter_boundary": adapter_boundary,
				"restoration_canary": restoration_canary,
				"trace_canary": trace_canary,
				"predicate_controls": predicate_controls,
			},
		)
	return {
		"schema_version": R4_PREFLIGHT_SCHEMA,
		"ok": true,
		"failure_code": "",
		"campaign_id": R4_CAMPAIGN_ID,
		"gate_id": R4_GATE_ID,
		"engine_id": R4_ENGINE_ID,
		"stage_id": String(cell["stage_id"]),
		"cell_id": String(cell["cell_id"]),
		"arm_id": String(cell["arm_id"]),
		"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
		"preregistration_raw_sha256": _r4_raw_file_sha256(R4_PREREGISTRATION_PATH),
		"fixed_controller_horizon_step_count": R4_CONTROLLER_STEPS,
		"fixed_restoration_step_count": R4_RESTORATION_STEPS,
		"fixed_passive_settle_step_count": R4_PASSIVE_STEPS,
		"fixed_total_trace_step_count": R4_TOTAL_STEPS,
		"fixed_horizon_configuration_proved_before_fixture_insertion": true,
		"trace_retained_before_terminal_entry_required": true,
		"entrypoint_preflight": entrypoint,
		"solver_receipt": solver_receipt,
		"adapter_boundary": adapter_boundary,
		"terminal_restoration_canary": restoration_canary,
		"trace_row_canary": trace_canary,
		"godot_predicate_negative_control_count": int(
			predicate_controls["rejected_mutation_count"]
		),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
	}


func _r4_run_physical(cell: Dictionary, source_commit: String) -> Dictionary:
	if not _r4_valid_lower_hex(source_commit, 40):
		return _r4_worker_failure(
			cell, source_commit, "before_world", "QSDK_R23D4_GJT_SOURCE_COMMIT_INVALID", 0, 0
		)
	var authorization := _r4_physical_authorization(cell, source_commit)
	if not bool(authorization.get("ok", false)):
		return _r4_worker_failure(
			cell,
			source_commit,
			"before_world",
			String(authorization.get("failure_code", "QSDK_R23D4_GJT_AUTHORIZATION_INVALID")),
			0,
			0,
		)
	var preflight: Dictionary = await _r4_run_preflight(cell)
	if not bool(preflight.get("ok", false)):
		return _r4_worker_failure(
			cell,
			source_commit,
			"before_world",
			String(preflight.get("failure_code", "QSDK_R23D4_GJT_PREFLIGHT_INVALID")),
			0,
			0,
		)
	var prepared := _r4_prepare(cell)
	if not bool(prepared.get("ok", false)):
		return _r4_worker_failure(
			cell,
			source_commit,
			"before_world",
			String(prepared.get("failure_code", "QSDK_R23D4_GJT_PREPARE_INVALID")),
			0,
			0,
		)
	var summary: Dictionary = await _r4_run_wave(prepared, false)
	var world_build_count := int(summary.get("world_build_count", 0))
	var adapter_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var terminal: Dictionary = summary.get("sdk_terminal_restoration", {})
	if world_build_count != 1:
		return _r4_worker_failure(
			cell,
			source_commit,
			"world_construction_failed",
			"QSDK_R23D4_GJT_WORLD_BUILD_COUNT_INVALID",
			1,
			world_build_count,
			null,
			adapter_summary,
			null,
		)
	var rows_value: Variant = terminal.get("trace_rows", null)
	if (
		typeof(rows_value) != TYPE_ARRAY
		or int(terminal.get("trace_row_count", -1)) != R4_TOTAL_STEPS
		or not (terminal.get("trace_failure_codes", []) as Array).is_empty()
	):
		return _r4_worker_failure(
			cell,
			source_commit,
			"settlement_complete",
			"QSDK_R23D4_GJT_TRACE_INCOMPLETE",
			1,
			1,
			null,
			adapter_summary,
			null,
		)
	var retention := _r4_retain_trace(
		cell,
		rows_value,
		String(authorization["attempt_root"]),
	)
	if not bool(retention.get("ok", false)):
		return _r4_worker_failure(
			cell,
			source_commit,
			"settlement_complete",
			String(retention.get("failure_code", "QSDK_R23D4_GJT_TRACE_RETENTION_FAILED")),
			1,
			1,
			null,
			adapter_summary,
			null,
		)
	var trace_artifact: Dictionary = retention["trace_artifact"]
	var horizon: Dictionary = summary.get("sdk_fixed_controller_horizon_receipt", {})
	var raw := {
		"engine_id": R4_ENGINE_ID,
		"world_attempt_count": 1,
		"world_build_count": 1,
		"controller_semantic_step_count": R4_CONTROLLER_STEPS,
		"terminal_restoration_step_count": R4_RESTORATION_STEPS,
		"passive_settle_step_count": R4_PASSIVE_STEPS,
		"validated_portable_command_count": int(
			adapter_summary.get("validated_balanced_wave_command_count", -1)
		),
		"native_actuation_application_count": (
			int(adapter_summary.get("native_actuation_application_count", -1))
			+ int(terminal.get("native_actuation_application_count", -1))
		),
		"passive_native_actuation_application_count": 0,
		"trace_row_count": int(terminal.get("trace_row_count", -1)),
		"fixed_horizon_configuration_proved_before_fixture_insertion": bool(
			horizon.get("configuration_proved_before_fixture_insertion", false)
		),
	}
	var predicates := _r4_project_godot_predicates(raw)
	var direct_body_write_count := (
		int(summary.get("direct_torso_force_command_count", -1))
		+ int(summary.get("direct_torso_impulse_command_count", -1))
		+ int(summary.get("direct_torso_velocity_command_count", -1))
		+ int(summary.get("direct_torso_transform_command_count", -1))
	)
	var execution_integrity := (
		bool(predicates.get("ok", false))
		and bool(horizon.get("exact", false))
		and int(horizon.get("expected_controller_step_count", -1)) == R4_CONTROLLER_STEPS
		and int(horizon.get("observed_controller_step_count", -1)) == R4_CONTROLLER_STEPS
		and direct_body_write_count == 0
		and int(summary.get("world_reset_count", -1)) == 0
		and String(terminal.get("failure_code", "not-present")).is_empty()
		and int(terminal.get("restoration_receipt_count", -1)) == R4_RESTORATION_STEPS
		and int(terminal.get("terminal_receipt_validation_failure_count", -1)) == 0
		and int(terminal.get("captured_pose_memory_transition_failure_count", -1)) == 0
		and int(terminal.get("actuator_application_mismatch_count", -1)) == 0
		and bool(terminal.get("passive_zero_target_applied", false))
	)
	if not execution_integrity:
		return _r4_worker_failure(
			cell,
			source_commit,
			"settlement_complete",
			"QSDK_R23D4_GJT_EXECUTION_INTEGRITY_INVALID",
			1,
			1,
			trace_artifact,
			raw,
			predicates,
		)
	var heading: Dictionary = summary.get("sdk_heading_schedule_receipt", {})
	var contact_source: Dictionary = summary.get("contact_cycle_count_by_limb", {})
	var sorted_contacts := {
		"front_left": int(contact_source.get("front_left", 0)),
		"front_right": int(contact_source.get("front_right", 0)),
		"rear_left": int(contact_source.get("rear_left", 0)),
		"rear_right": int(contact_source.get("rear_right", 0)),
	}
	var first_contact := int(
		terminal.get("first_all_four_contact_restoration_step", -1)
	)
	if first_contact < 0:
		first_contact = 180
	var measurements := {
		"final_forward_displacement_m": float(
			summary.get("final_task_frame_forward_displacement_m", NAN)
		),
		"turn_phase_yaw_delta_rad": float(heading.get("turn_phase_yaw_delta_rad", NAN)),
		"maximum_absolute_requested_steering_fraction": float(
			heading.get("maximum_absolute_requested_steering_fraction", NAN)
		),
		"maximum_absolute_held_steering_fraction": float(
			heading.get("maximum_absolute_held_steering_fraction", NAN)
		),
		"maximum_tilt_rad": float(summary.get("maximum_tilt_rad", NAN)),
		"minimum_torso_height_m": float(summary.get("minimum_torso_height_m", NAN)),
		"contact_cycle_count_by_limb": sorted_contacts,
		"torso_ground_contact_step_count": int(summary.get("torso_contact_ticks", -1)),
		"controller_error_count": (adapter_summary.get("failure_codes", []) as Array).size(),
		"active_safe_no_actuation_count": int(
			adapter_summary.get("safe_no_actuation_count", -1)
		),
		"nonfinite_observation_count": 0,
		"actuator_application_mismatch_count": (
			int(adapter_summary.get("mismatch_count", -1))
			+ int(terminal.get("actuator_application_mismatch_count", -1))
		),
		"controller_semantic_step_count": R4_CONTROLLER_STEPS,
		"terminal_restoration_step_count": R4_RESTORATION_STEPS,
		"passive_settle_step_count": R4_PASSIVE_STEPS,
		"validated_portable_command_count": int(raw["validated_portable_command_count"]),
		"native_actuation_application_count": int(raw["native_actuation_application_count"]),
		"passive_native_actuation_application_count": 0,
		"restoration_receipt_count": int(terminal["restoration_receipt_count"]),
		"terminal_receipt_validation_failure_count": int(
			terminal["terminal_receipt_validation_failure_count"]
		),
		"first_all_four_contact_restoration_step": first_contact,
		"consecutive_all_four_contact_hold_step_count": int(
			terminal["consecutive_all_four_contact_hold_step_count"]
		),
		"captured_pose_memory_transition_count": int(
			terminal["captured_pose_memory_transition_count"]
		),
		"captured_pose_memory_transition_failure_count": int(
			terminal["captured_pose_memory_transition_failure_count"]
		),
		"maximum_absolute_restoration_joint_velocity_rad_s": float(
			terminal["maximum_absolute_restoration_joint_velocity_rad_s"]
		),
		"heading_correction_receipt_count": int(
			terminal["heading_correction_receipt_count"]
		),
		"passive_settle_trace_row_count": R4_PASSIVE_STEPS,
	}
	return {
		"schema_version": R4_REPORT_SCHEMA,
		"campaign_id": R4_CAMPAIGN_ID,
		"gate_id": R4_GATE_ID,
		"stage_id": String(cell["stage_id"]),
		"cell_id": String(cell["cell_id"]),
		"engine_id": R4_ENGINE_ID,
		"arm_id": String(cell["arm_id"]),
		"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
		"source_commit": source_commit,
		"trace_artifact": trace_artifact.duplicate(true),
		"trace_summary": (retention["trace_summary"] as Dictionary).duplicate(true),
		"execution":
		{
			"integrity_passed": true,
			"worker_failure_code": "",
			"controller_semantic_step_count": R4_CONTROLLER_STEPS,
			"terminal_restoration_step_count": R4_RESTORATION_STEPS,
			"passive_settle_step_count": R4_PASSIVE_STEPS,
			"validated_portable_command_count": int(raw["validated_portable_command_count"]),
			"native_actuation_application_count": int(raw["native_actuation_application_count"]),
			"passive_native_actuation_application_count": 0,
			"portable_impulse_violation_count": 0,
			"world_attempt_count": 1,
			"world_build_count": 1,
			"trace_retained_before_terminal_entry": true,
			"fixed_horizon_configuration_proved_before_fixture_insertion": true,
		},
		"measurements": measurements,
		"godot_execution_predicates": predicates,
		"claims": R4_FALSE_CLAIMS.duplicate(true),
	}


func _r4_run_wave(prepared: Dictionary, preflight_before_world: bool) -> Dictionary:
	return await (
		R4WaveGaitScript
		. new()
		. run(
			self,
			-1.0,
			10.0,
			1.75,
			"lateral",
			72,
			0.40,
			"all",
			112,
			false,
			prepared["initial_perturbation"],
			ROBUSTNESS_OPTIONS,
			prepared["fixture_spec"],
			HOST_OBSERVER_PATH_OPTIONS,
			ACTUATOR_IMPULSE_OPTIONS,
			HOST_PREAUTHORITY_MOTOR_OPTIONS,
			prepared["evidence_threshold_options"],
			prepared["gait_clock_options"],
			SOLVER_POLICY_OPTIONS,
			{},
			{},
			prepared["authority_options"],
			{},
			{},
			preflight_before_world,
			prepared["fixed_horizon_options"],
			prepared["schedule"],
			{},
			prepared["terminal_options"],
		)
	)


static func _r4_prepare(cell: Dictionary) -> Dictionary:
	var contract := _r4_read_json(R4_PREREGISTRATION_PATH)
	if not _r4_contract_exact(contract):
		return _r4_failure("QSDK_R23D4_GJT_CONTRACT_IDENTITY_INVALID")
	var inherited := R23D3WorkerScript._prepare(cell)
	if not bool(inherited.get("ok", false)):
		return inherited
	var horizon := {
		"candidate_specific_horizon_extension_count": 0,
		"exact_candidate_authority_observation_count": R4_CONTROLLER_STEPS,
		"first_candidate_authority_observation_index": 0,
		"last_candidate_authority_observation_index": R4_CONTROLLER_STEPS - 1,
		"policy_id": R4_HORIZON_POLICY_ID,
		"policy_sha256": R4_HORIZON_POLICY_SHA256,
	}
	var horizon_result := R4WaveGaitScript.compile_candidate_authority_horizon_options(
		horizon
	)
	if not bool(horizon_result.get("ok", false)):
		return horizon_result
	var terminal := {
		"cell_id": String(cell["cell_id"]),
		"controller_step_count": R4_CONTROLLER_STEPS,
		"passive_settle_step_count": R4_PASSIVE_STEPS,
		"restoration_step_count": R4_RESTORATION_STEPS,
		"terminal_restoration_policy_id": R4RestorationScript.POLICY_ID,
		"total_traced_step_count": R4_TOTAL_STEPS,
		"trace_row_schema_version": R4_TRACE_ROW_SCHEMA,
		"trace_schema_version": R4_TRACE_SCHEMA,
		"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
	}
	var terminal_result := R4WaveGaitScript.compile_sdk_terminal_restoration_options(
		terminal
	)
	if not bool(terminal_result.get("ok", false)):
		return terminal_result
	var prepared := inherited.duplicate(true)
	prepared["fixed_horizon_options"] = horizon
	prepared["terminal_options"] = terminal
	prepared["compiled_terminal_options"] = terminal_result[
		"sdk_terminal_restoration_options"
	]
	return prepared


static func _r4_trace_canary(options: Dictionary) -> Dictionary:
	var probes := {
		0: "reference_warmup",
		599: "reference_warmup",
		600: "commanded_turn",
		1799: "commanded_turn",
		1800: "reference_recovery",
		2399: "reference_recovery",
		2400: "reference_continuation",
		2991: "reference_continuation",
		2992: "terminal_contact_acquisition",
		3171: "terminal_contact_acquisition",
		3172: "terminal_captured_pose_hold",
		3531: "terminal_captured_pose_hold",
		3532: "passive_zero_actuation_settle",
		3771: "passive_zero_actuation_settle",
	}
	var contacts := {
		"front_left": true,
		"front_right": true,
		"rear_left": true,
		"rear_right": true,
	}
	for step_value in probes:
		var step := int(step_value)
		var application_count := 0 if step >= R4_ACTIVE_STEPS else R4_ACTUATOR_COUNT
		var result := R4WaveGaitScript._compose_sdk_terminal_trace_row(
			options,
			step,
			0.0,
			0.4,
			0.1,
			false,
			contacts,
			application_count,
		)
		var row: Dictionary = result.get("row", {})
		if (
			not bool(result.get("ok", false))
			or String(row.get("phase_id", "")) != String(probes[step])
			or String(row.get("schema_version", "")) != R4_TRACE_ROW_SCHEMA
			or int(row.get("trace_step", -1)) != step
		):
			return _r4_failure("QSDK_R23D4_GJT_TRACE_CANARY_INVALID")
	var mutation := R4WaveGaitScript._compose_sdk_terminal_trace_row(
		options,
		600,
		0.0,
		0.4,
		0.1,
		false,
		contacts,
		0,
	)
	return {
		"ok": not bool(mutation.get("ok", true)),
		"failure_code": "" if not bool(mutation.get("ok", true)) else "QSDK_R23D4_GJT_TRACE_MUTATION_ACCEPTED",
		"representative_trace_row_count": probes.size(),
		"oracle_mutation_rejected": not bool(mutation.get("ok", true)),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r4_project_godot_predicates(raw_value: Variant) -> Dictionary:
	var raw: Dictionary = raw_value if typeof(raw_value) == TYPE_DICTIONARY else {}
	var expected_keys := [
		"controller_semantic_step_count",
		"engine_id",
		"fixed_horizon_configuration_proved_before_fixture_insertion",
		"native_actuation_application_count",
		"passive_native_actuation_application_count",
		"passive_settle_step_count",
		"terminal_restoration_step_count",
		"trace_row_count",
		"validated_portable_command_count",
		"world_attempt_count",
		"world_build_count",
	]
	var observed_keys := raw.keys()
	observed_keys.sort()
	var checks := {
		"raw_fields_exact": observed_keys == expected_keys,
		"engine_identity": String(raw.get("engine_id", "")) == R4_ENGINE_ID,
		"one_world": (
			int(raw.get("world_attempt_count", -1)) == 1
			and int(raw.get("world_build_count", -1)) == 1
		),
		"controller_horizon": int(raw.get("controller_semantic_step_count", -1))
		== R4_CONTROLLER_STEPS,
		"restoration_horizon": int(raw.get("terminal_restoration_step_count", -1))
		== R4_RESTORATION_STEPS,
		"passive_horizon": int(raw.get("passive_settle_step_count", -1))
		== R4_PASSIVE_STEPS,
		"portable_command_count": int(raw.get("validated_portable_command_count", -1))
		== R4_ACTIVE_STEPS * R4_ACTUATOR_COUNT,
		"native_application_count": int(raw.get("native_actuation_application_count", -1))
		== R4_ACTIVE_STEPS * R4_ACTUATOR_COUNT,
		"passive_zero_application": int(
			raw.get("passive_native_actuation_application_count", -1)
		) == 0,
		"trace_horizon": int(raw.get("trace_row_count", -1)) == R4_TOTAL_STEPS,
		"fixed_horizon_preinsertion": bool(
			raw.get("fixed_horizon_configuration_proved_before_fixture_insertion", false)
		),
	}
	var ok := true
	for check_value in checks.values():
		ok = ok and bool(check_value)
	return {
		"schema_version": R4_GODOT_PREDICATE_SCHEMA,
		"raw_sdk_authority_summary": raw.duplicate(true),
		"checks": checks,
		"ok": ok,
		"physical_acceptance_authority": false,
	}


static func _r4_predicate_negative_controls() -> Dictionary:
	var good := _r4_synthetic_raw_summary()
	var fields := good.keys()
	var rejected := 0
	for field_value in fields:
		var field := String(field_value)
		var mutation := good.duplicate(true)
		if field == "engine_id":
			mutation[field] = "mutated"
		elif field == "fixed_horizon_configuration_proved_before_fixture_insertion":
			mutation[field] = false
		else:
			mutation[field] = int(mutation[field]) + 1
		if not bool(_r4_project_godot_predicates(mutation).get("ok", true)):
			rejected += 1
	var missing := good.duplicate(true)
	missing.erase("trace_row_count")
	if not bool(_r4_project_godot_predicates(missing).get("ok", true)):
		rejected += 1
	return {
		"ok": rejected == fields.size() + 1,
		"failure_code": "" if rejected == fields.size() + 1 else "QSDK_R23D4_GJT_PREDICATE_CONTROL_INVALID",
		"rejected_mutation_count": rejected,
		"declared_mutation_count": fields.size() + 1,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r4_synthetic_raw_summary() -> Dictionary:
	return {
		"engine_id": R4_ENGINE_ID,
		"world_attempt_count": 1,
		"world_build_count": 1,
		"controller_semantic_step_count": R4_CONTROLLER_STEPS,
		"terminal_restoration_step_count": R4_RESTORATION_STEPS,
		"passive_settle_step_count": R4_PASSIVE_STEPS,
		"validated_portable_command_count": R4_ACTIVE_STEPS * R4_ACTUATOR_COUNT,
		"native_actuation_application_count": R4_ACTIVE_STEPS * R4_ACTUATOR_COUNT,
		"passive_native_actuation_application_count": 0,
		"trace_row_count": R4_TOTAL_STEPS,
		"fixed_horizon_configuration_proved_before_fixture_insertion": true,
	}


static func _r4_contract_exact(contract: Dictionary) -> bool:
	var fixture: Dictionary = contract.get("fixture", {})
	var schedule: Dictionary = contract.get("command_and_terminal_schedule", {})
	var borrowed: Dictionary = contract.get("borrowed_terminal_restoration_authorities", {})
	return (
		String(contract.get("schema_version", ""))
		== "sporespore_qsdk_r23d4_terminal_stabilization_preregistration_v1"
		and String(contract.get("campaign_id", "")) == R4_CAMPAIGN_ID
		and String(contract.get("gate_id", "")) == R4_GATE_ID
		and String(fixture.get("morphology_id", "")) == "qsdk_r05_generated_s169"
		and int(fixture.get("campaign_seed", -1)) == 21501
		and int(fixture.get("physics_hz", -1)) == 120
		and int(schedule.get("turning_controller_semantic_step_count", -1))
		== R4_CONTROLLER_STEPS
		and int(schedule.get("terminal_restoration_step_count", -1))
		== R4_RESTORATION_STEPS
		and int(schedule.get("passive_settle_step_count", -1)) == R4_PASSIVE_STEPS
		and int(schedule.get("total_traced_step_count", -1)) == R4_TOTAL_STEPS
		and String(schedule.get("terminal_restoration_policy_id", ""))
		== R4RestorationScript.POLICY_ID
		and String(borrowed.get("mujoco_closure_raw_sha256", ""))
		== _r4_raw_file_sha256(R4_MUJOCO_RESTORATION_CLOSURE_PATH)
		and String(borrowed.get("rapier_closure_raw_sha256", ""))
		== _r4_raw_file_sha256(R4_RAPIER_RESTORATION_CLOSURE_PATH)
		and not bool(
			(contract.get("authorization", {}) as Dictionary).get(
				"physical_execution_authorized",
				true,
			)
		)
	)


static func _r4_parse_arguments(args: PackedStringArray) -> Dictionary:
	var values := {}
	var preflight_only := false
	var index := 0
	while index < args.size():
		var argument := String(args[index])
		if argument == "--preflight-only" and not preflight_only:
			preflight_only = true
			index += 1
			continue
		if ["--stage", "--arm", "--source-commit"].has(argument):
			if values.has(argument) or index + 1 >= args.size():
				return _r4_failure("QSDK_R23D4_GJT_ARGUMENT_DUPLICATE_OR_MISSING")
			values[argument] = String(args[index + 1])
			index += 2
			continue
		return _r4_failure("QSDK_R23D4_GJT_ARGUMENT_UNKNOWN:%s" % argument)
	if (
		not values.has("--stage")
		or not values.has("--arm")
		or preflight_only == values.has("--source-commit")
	):
		return _r4_failure("QSDK_R23D4_GJT_ARGUMENTS_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"stage_id": String(values["--stage"]),
		"arm_id": String(values["--arm"]),
		"preflight_only": preflight_only,
		"source_commit": String(values.get("--source-commit", "")),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r4_cell(stage_id: String, arm_id: String) -> Dictionary:
	if stage_id != "three_engine_confirmation" or not R4_ARM_OFFSETS.has(arm_id):
		return _r4_failure("QSDK_R23D4_GJT_CELL_IDENTITY_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"stage_id": stage_id,
		"cell_id": "%s__onset_600__%s" % [R4_ENGINE_ID, arm_id],
		"engine_id": R4_ENGINE_ID,
		"onset_id": "onset_600",
		"turn_start_semantic_step": 600,
		"arm_id": arm_id,
		"turn_heading_offset_rad": float(R4_ARM_OFFSETS[arm_id]),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r4_retain_trace(
	cell: Dictionary,
	rows: Array,
	attempt_root: String,
) -> Dictionary:
	var pending_root := attempt_root.path_join("pending-traces")
	if DirAccess.make_dir_recursive_absolute(pending_root) != OK:
		return _r4_failure("QSDK_R23D4_GJT_TRACE_ROOT_CREATE_FAILED")
	var rows_path := pending_root.path_join(
		"%s__%s.rows.json" % [String(cell["stage_id"]), String(cell["cell_id"])]
	)
	if FileAccess.file_exists(rows_path):
		return _r4_failure("QSDK_R23D4_GJT_TRACE_ROWS_ALREADY_EXIST")
	var file := FileAccess.open(rows_path, FileAccess.WRITE)
	if file == null:
		return _r4_failure("QSDK_R23D4_GJT_TRACE_ROWS_CREATE_FAILED")
	file.store_string(JSON.stringify(rows))
	file.store_string("\n")
	file.flush()
	file = null
	var python := OS.get_environment(R4_PYTHON_ENV)
	if python.is_empty():
		python = "python"
	var powershell := OS.get_environment(R4_POWERSHELL_ENV)
	if powershell.is_empty():
		powershell = "pwsh"
	var output: Array = []
	var exit_code := OS.execute(
		python,
		PackedStringArray(
			[
				ProjectSettings.globalize_path(R4_PHYSICAL_EVALUATOR_PATH),
				"retain-trace",
				"--stage-id",
				String(cell["stage_id"]),
				"--cell-id",
				String(cell["cell_id"]),
				"--rows-json",
				rows_path,
				"--repo-root",
				ProjectSettings.globalize_path("res://"),
				"--attempt-root",
				attempt_root,
				"--powershell",
				powershell,
			]
		),
		output,
		true,
	)
	var marker := "QSDK_R23D4_TRACE_RETAINED "
	var matches: Array[String] = []
	for output_value in output:
		for line_value in String(output_value).split("\n"):
			var line := String(line_value).strip_edges()
			if line.begins_with(marker):
				matches.append(line.trim_prefix(marker))
	if exit_code != 0 or matches.size() != 1:
		return _r4_failure(
			"QSDK_R23D4_GJT_TRACE_RETENTION_FAILED:%d" % exit_code,
			{"output": output},
		)
	var parsed: Variant = JSON.parse_string(matches[0])
	if typeof(parsed) != TYPE_DICTIONARY:
		return _r4_failure("QSDK_R23D4_GJT_TRACE_RETENTION_RECEIPT_INVALID")
	var receipt: Dictionary = parsed
	if (
		String(receipt.get("schema_version", "")) != R4_TRACE_RETENTION_SCHEMA
		or String(receipt.get("stage_id", "")) != String(cell["stage_id"])
		or String(receipt.get("cell_id", "")) != String(cell["cell_id"])
		or not bool(receipt.get("retained_before_terminal_entry", false))
	):
		return _r4_failure("QSDK_R23D4_GJT_TRACE_RETENTION_RECEIPT_INVALID", receipt)
	receipt["ok"] = true
	receipt["failure_code"] = ""
	return receipt


static func _r4_physical_authorization(
	cell: Dictionary,
	source_commit: String,
) -> Dictionary:
	if FileAccess.file_exists(R4_CLOSURE_PATH):
		return _r4_failure("QSDK_R23D4_GJT_CLOSED")
	var freeze_path := OS.get_environment(R4_FREEZE_PATH_ENV)
	var attempt_path := OS.get_environment(R4_ATTEMPT_PATH_ENV)
	var token := OS.get_environment(R4_TOKEN_ENV)
	var attempt_root := OS.get_environment(R4_ATTEMPT_ROOT_ENV)
	if (
		freeze_path.is_empty()
		or attempt_path.is_empty()
		or attempt_root.is_empty()
		or not FileAccess.file_exists(freeze_path)
		or not FileAccess.file_exists(attempt_path)
		or not DirAccess.dir_exists_absolute(attempt_root)
		or not _r4_valid_lower_hex(token, 32)
	):
		return _r4_failure("QSDK_R23D4_GJT_PHYSICAL_AUTHORIZATION_REQUIRED")
	var freeze := _r4_read_json(freeze_path)
	var attempt := _r4_read_json(attempt_path)
	var production_root := (
		ProjectSettings.globalize_path("res://../SporeSpore_Evidence")
		. simplify_path()
		. replace("\\", "/")
		. trim_suffix("/")
	)
	var normalized_attempt_root := (
		attempt_root.simplify_path().replace("\\", "/").trim_suffix("/")
	)
	var stage_ids: Array = attempt.get("ordered_stage_b_cell_ids", [])
	var exact := (
		(
			normalized_attempt_root == production_root
			or normalized_attempt_root.begins_with(production_root + "/")
		)
		and String(freeze.get("schema_version", "")) == R4_FREEZE_SCHEMA
		and String(freeze.get("campaign_id", "")) == R4_CAMPAIGN_ID
		and String(freeze.get("gate_id", "")) == R4_GATE_ID
		and String(freeze.get("status", "")) == "frozen_supervisor_only_physical_authorized"
		and String(freeze.get("preregistration_raw_sha256", ""))
		== _r4_raw_file_sha256(R4_PREREGISTRATION_PATH)
		and String(freeze.get("source_commit", "")) == source_commit
		and bool(freeze.get("physical_execution_authorized", false))
		and _r4_source_bindings_exact(freeze)
		and String(attempt.get("schema_version", "")) == R4_ATTEMPT_SCHEMA
		and String(attempt.get("campaign_id", "")) == R4_CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == R4_GATE_ID
		and String(attempt.get("freeze_raw_sha256", ""))
		== _r4_raw_file_sha256(freeze_path)
		and String(attempt.get("source_commit", "")) == source_commit
		and String(attempt.get("authorization_token", "")) == token
		and _r4_valid_lower_hex(String(attempt.get("attempt_id", "")), 32)
		and bool(attempt.get("physical_execution_authorized", false))
		and bool(attempt.get("single_use_supervisor_authorization", false))
		and bool(attempt.get("source_worktree_clean", false))
		and bool(attempt.get("source_matches_live_github_main", false))
		and bool(attempt.get("operation_lock_held", false))
		and bool(attempt.get("full_godot_attestation_valid", false))
		and bool(attempt.get("content_addressed_inputs_retained", false))
		and bool(attempt.get("one_shot_attempt_unconsumed", false))
		and String(attempt.get("attempt_root", "")).simplify_path()
		== normalized_attempt_root
		and OS.get_environment(R4_STAGE_ENV) == String(cell["stage_id"])
		and OS.get_environment(R4_CELL_ENV) == String(cell["cell_id"])
		and OS.get_environment(R4_ENGINE_ENV) == R4_ENGINE_ID
		and stage_ids.has(String(cell["cell_id"]))
		and String(attempt.get("selected_onset_id", "")) == "onset_600"
	)
	if not exact:
		return _r4_failure("QSDK_R23D4_GJT_PHYSICAL_AUTHORIZATION_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"attempt_root": normalized_attempt_root,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r4_source_bindings_exact(freeze: Dictionary) -> bool:
	var required := {
		R4_WORKER_PATH.trim_prefix("res://"): _r4_raw_file_sha256(R4_WORKER_PATH),
		R4_BASE_WORKER_PATH.trim_prefix("res://"): _r4_raw_file_sha256(R4_BASE_WORKER_PATH),
		R4_RUNNER_PATH.trim_prefix("res://"): _r4_raw_file_sha256(R4_RUNNER_PATH),
		R4_ADAPTER_PATH.trim_prefix("res://"): _r4_raw_file_sha256(R4_ADAPTER_PATH),
		R4_RESTORER_PATH.trim_prefix("res://"): _r4_raw_file_sha256(R4_RESTORER_PATH),
		R4_PREREGISTRATION_PATH.trim_prefix("res://"):
		_r4_raw_file_sha256(R4_PREREGISTRATION_PATH),
		R4_R23D3_CLOSURE_PATH.trim_prefix("res://"):
		_r4_raw_file_sha256(R4_R23D3_CLOSURE_PATH),
		R4_MUJOCO_RESTORATION_CLOSURE_PATH.trim_prefix("res://"):
		_r4_raw_file_sha256(R4_MUJOCO_RESTORATION_CLOSURE_PATH),
		R4_RAPIER_RESTORATION_CLOSURE_PATH.trim_prefix("res://"):
		_r4_raw_file_sha256(R4_RAPIER_RESTORATION_CLOSURE_PATH),
		R4_PHYSICAL_EVALUATOR_PATH.trim_prefix("res://"):
		_r4_raw_file_sha256(R4_PHYSICAL_EVALUATOR_PATH),
		R4_TRACE_PUBLISHER_PATH.trim_prefix("res://"):
		_r4_raw_file_sha256(R4_TRACE_PUBLISHER_PATH),
		"sdk/turning/r23d2_development_contract_v1.json": _r4_raw_file_sha256(
			"res://sdk/turning/r23d2_development_contract_v1.json"
		),
	}
	var bindings_value: Variant = freeze.get("source_bindings", null)
	if typeof(bindings_value) != TYPE_ARRAY:
		return false
	var observed := {}
	for item_value in bindings_value:
		if typeof(item_value) == TYPE_DICTIONARY:
			var item: Dictionary = item_value
			observed[String(item.get("path", ""))] = String(item.get("raw_sha256", ""))
	for path_value in required:
		var path := String(path_value)
		if String(observed.get(path, "")) != String(required[path]):
			return false
	return true


static func _r4_worker_failure(
	cell: Dictionary,
	source_commit: String,
	failure_stage: String,
	failure_code: String,
	world_attempt_count: int,
	world_build_count: int,
	trace_artifact: Variant = null,
	raw_sdk_authority_summary: Variant = null,
	godot_execution_predicates: Variant = null,
) -> Dictionary:
	var normalized_commit := source_commit
	if not _r4_valid_lower_hex(normalized_commit, 40):
		normalized_commit = "0".repeat(40)
	return {
		"schema_version": R4_FAILURE_SCHEMA,
		"campaign_id": R4_CAMPAIGN_ID,
		"gate_id": R4_GATE_ID,
		"stage_id": String(cell.get("stage_id", "three_engine_confirmation")),
		"cell_id": String(cell.get("cell_id", "")),
		"engine_id": R4_ENGINE_ID,
		"arm_id": String(cell.get("arm_id", "")),
		"turn_heading_offset_rad": float(cell.get("turn_heading_offset_rad", 0.0)),
		"source_commit": normalized_commit,
		"failure_stage": failure_stage,
		"failure_code": failure_code,
		"world_attempt_count": world_attempt_count,
		"world_build_count": world_build_count,
		"trace_artifact": trace_artifact,
		"raw_sdk_authority_summary": raw_sdk_authority_summary,
		"godot_execution_predicates": godot_execution_predicates,
		"claims": R4_FALSE_CLAIMS.duplicate(true),
	}


static func _r4_read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if typeof(value) == TYPE_DICTIONARY else {}


static func _r4_raw_file_sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return "sha256:" + FileAccess.get_sha256(path)


static func _r4_valid_lower_hex(value: String, expected_length: int) -> bool:
	if value.length() != expected_length or value.to_lower() != value:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func _r4_failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
