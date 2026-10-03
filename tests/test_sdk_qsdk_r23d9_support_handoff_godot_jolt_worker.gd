extends "res://tests/test_sdk_qsdk_r23d8_neutral_stance_godot_jolt_worker.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Dormant Godot/Jolt physical worker for prospective QSDK-R23D9.
##
## The worker reuses the qualified R23D8 fixture, adapter, controller, and
## neutral-stance equation. It changes only the terminal scheduler: 30
## consecutive completed all-four-contact observations trigger an irreversible
## transition, applied to the following step, from active neutral acquisition
## to native zero actuation. No world is reachable without source-exact
## single-supervisor authorization.

const R9WaveGaitScript := preload(
	"res://scripts/lab/gait/physical_wave_gait_quadruped.gd"
)
const R9NeutralStance := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_neutral_stance.gd"
)
const R9SupportHandoff := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_support_handoff.gd"
)
const R9_PREREGISTRATION_PATH := (
	"res://sdk/turning/r23d9_support_handoff_preregistration_v1.json"
)
const R9_IMPLEMENTATION_PATH := (
	"res://sdk/turning/r23d9_physical_implementation_contract_v1.json"
)
const R9_PHYSICAL_EVALUATOR_PATH := "res://sdk/turning/r23d9_physical_evaluator.py"
const R9_CLOSURE_PATH := "res://sdk/turning/r23d9_physical_closure_v1.json"
const R9_CAMPAIGN_ID := (
	"QSDK-R23D9-SUPPORT-CONFIRMED-ACTIVE-TO-PASSIVE-HANDOFF-"
	+ "BILATERAL-TURN-DEVELOPMENT"
)
const R9_GATE_ID := "QSDK-R23D9"
const R9_ENGINE_ID := "godot_jolt"
const R9_PREFLIGHT_SCHEMA := "sporespore_qsdk_r23d9_godot_jolt_worker_preflight_v1"
const R9_REPORT_SCHEMA := "sporespore_qsdk_r23d9_engine_cell_report_v1"
const R9_FAILURE_SCHEMA := "sporespore_qsdk_r23d9_worker_failure_v1"
const R9_FREEZE_SCHEMA := "sporespore_qsdk_r23d9_physical_freeze_v1"
const R9_ATTEMPT_SCHEMA := "sporespore_qsdk_r23d9_attempt_v1"
const R9_TRACE_RETENTION_SCHEMA := "sporespore_qsdk_r23d9_trace_retention_v1"
const R9_TRACE_SCHEMA := "sporespore_qsdk_r23d9_turn_support_handoff_trace_v1"
const R9_TRACE_ROW_SCHEMA := (
	"sporespore_qsdk_r23d9_turn_support_handoff_trace_row_v1"
)
const R9_CONTROLLER_STEPS := 2992
const R9_TERMINAL_STEPS := 780
const R9_TOTAL_STEPS := 3772
const R9_MAXIMUM_ACTIVE_STEPS := 420
const R9_SUPPORT_CONFIRMATION_STEPS := 30
const R9_MINIMUM_PASSIVE_STEPS := 360
const R9_HANDOFF_POLICY_ID := (
	"sporespore_support_confirmed_irreversible_passive_handoff_v1"
)

const R9_FREEZE_PATH_ENV := "SPORESPORE_QSDK_R23D9_FREEZE"
const R9_ATTEMPT_PATH_ENV := "SPORESPORE_QSDK_R23D9_ATTEMPT"
const R9_TOKEN_ENV := "SPORESPORE_QSDK_R23D9_TOKEN"
const R9_STAGE_ENV := "SPORESPORE_QSDK_R23D9_STAGE"
const R9_CELL_ENV := "SPORESPORE_QSDK_R23D9_CELL"
const R9_ENGINE_ENV := "SPORESPORE_QSDK_R23D9_ENGINE"
const R9_ATTEMPT_ROOT_ENV := "SPORESPORE_QSDK_R23D9_ATTEMPT_ROOT"
const R9_PYTHON_ENV := "SPORESPORE_QSDK_R23D9_PYTHON"
const R9_POWERSHELL_ENV := "SPORESPORE_QSDK_R23D9_POWERSHELL"

const R9_ARM_OFFSETS := {
	"reference_zero": 0.0,
	"positive_heading": 0.2,
	"negative_heading": -0.2,
}
const R9_FALSE_CLAIMS := {
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
	var parsed := _r9_parse_arguments(OS.get_cmdline_user_args())
	if not bool(parsed.get("ok", false)):
		print("QSDK_R23D9_GODOT_JOLT_FAILURE ", JSON.stringify(parsed))
		quit(1)
		return
	var cell := _r9_cell(String(parsed["stage_id"]), String(parsed["arm_id"]))
	if not bool(cell.get("ok", false)):
		print("QSDK_R23D9_GODOT_JOLT_FAILURE ", JSON.stringify(cell))
		quit(1)
		return
	if bool(parsed["preflight_only"]):
		var preflight: Dictionary = await _r9_run_preflight(cell)
		if not bool(preflight.get("ok", false)):
			print("QSDK_R23D9_GODOT_JOLT_FAILURE ", JSON.stringify(preflight))
			quit(1)
			return
		print("QSDK_R23D9_GODOT_JOLT_PREFLIGHT ", JSON.stringify(preflight))
		quit(0)
		return
	if bool(parsed["authorization_preflight"]):
		var authorization := _r9_physical_authorization(
			cell,
			String(parsed["source_commit"]),
		)
		if not bool(authorization.get("ok", false)):
			print("QSDK_R23D9_GODOT_JOLT_FAILURE ", JSON.stringify(authorization))
			quit(1)
			return
		var receipt := {
			"schema_version": (
				"sporespore_qsdk_r23d9_godot_jolt_production_"
				+ "authorization_preflight_v1"
			),
			"campaign_id": R9_CAMPAIGN_ID,
			"gate_id": R9_GATE_ID,
			"engine_id": R9_ENGINE_ID,
			"stage_id": String(cell["stage_id"]),
			"cell_id": String(cell["cell_id"]),
			"actual_production_authorization_function": "_r9_physical_authorization",
			"authorization_passed": true,
			"returned_before_model": true,
			"physical_process_launch_count": 0,
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
		print("QSDK_R23D9_GODOT_JOLT_AUTHORIZATION_PREFLIGHT ", JSON.stringify(receipt))
		quit(0)
		return
	var terminal: Dictionary = await _r9_run_physical(cell, String(parsed["source_commit"]))
	print("QSDK_R23D9_GODOT_JOLT_TERMINAL ", JSON.stringify(terminal))
	quit(0 if String(terminal.get("schema_version", "")) == R9_REPORT_SCHEMA else 1)


func _r9_run_preflight(cell: Dictionary) -> Dictionary:
	var solver_receipt := R23D3WorkerScript._apply_solver_configuration()
	var prepared := _r9_prepare(cell)
	if not bool(solver_receipt.get("ok", false)) or not bool(prepared.get("ok", false)):
		return _r9_failure(
			"QSDK_R23D9_GJT_PREPARE_INVALID",
			{"solver_receipt": solver_receipt, "prepared": prepared},
		)
	var entrypoint: Dictionary = await _r8_run_wave(prepared, true)
	var adapter_boundary := R23D3WorkerScript._adapter_boundary(prepared, cell)
	var neutral := R9NeutralStance.run_zero_world_preflight()
	var handoff := R9SupportHandoff.run_zero_world_preflight()
	var trace_canary: Dictionary = _r9_trace_canary(prepared["compiled_terminal_options"])
	var exact: bool = (
		bool(entrypoint.get("ok", false))
		and int(entrypoint.get("actual_world_build_count", -1)) == 0
		and int(entrypoint.get("scene_tree_insertion_count", -1)) == 0
		and not bool(entrypoint.get("physics_state_modified", true))
		and bool(entrypoint.get("candidate_authority_horizon_enabled", false))
		and int(entrypoint.get("candidate_authority_observation_count", -1))
		== R9_CONTROLLER_STEPS
		and not bool(entrypoint.get("sdk_physical_trace_enabled", true))
		and bool(entrypoint.get("sdk_terminal_restoration_enabled", false))
		and (
			entrypoint.get("sdk_terminal_restoration_options", {}) as Dictionary
		) == prepared["compiled_terminal_options"]
		and bool(adapter_boundary.get("ok", false))
		and bool(neutral.get("ok", false))
		and int(neutral.get("algebra_canary_count", -1)) == 5
		and int(neutral.get("mutation_control_count", -1)) == 10
		and bool(handoff.get("ok", false))
		and int(handoff.get("oracle_canary_count", -1)) == 5
		and int(handoff.get("mutation_control_count", -1)) == 12
		and bool(trace_canary.get("ok", false))
		and int(trace_canary.get("canary_count", -1)) == 4
	)
	if not exact:
		return _r9_failure(
			"QSDK_R23D9_GJT_PREFLIGHT_INVALID",
			{
				"entrypoint_ok": bool(entrypoint.get("ok", false)),
				"entrypoint_failure_code": String(entrypoint.get("failure_code", "")),
				"adapter_boundary_ok": bool(adapter_boundary.get("ok", false)),
				"neutral_ok": bool(neutral.get("ok", false)),
				"neutral_algebra_canary_count": int(neutral.get("algebra_canary_count", -1)),
				"neutral_mutation_control_count": int(neutral.get("mutation_control_count", -1)),
				"handoff_ok": bool(handoff.get("ok", false)),
				"handoff_oracle_canary_count": int(handoff.get("oracle_canary_count", -1)),
				"handoff_mutation_control_count": int(handoff.get("mutation_control_count", -1)),
				"trace_canary_ok": bool(trace_canary.get("ok", false)),
				"trace_canary_count": int(trace_canary.get("canary_count", -1)),
				"trace_canary_failure_code": String(
					trace_canary.get("failure_code", "")
				),
				"trace_canary_detail": trace_canary,
				"entrypoint_actual_world_build_count": int(
					entrypoint.get("actual_world_build_count", -1)
				),
				"entrypoint_scene_tree_insertion_count": int(
					entrypoint.get("scene_tree_insertion_count", -1)
				),
				"entrypoint_physics_state_modified": bool(
					entrypoint.get("physics_state_modified", true)
				),
				"entrypoint_candidate_authority_horizon_enabled": bool(
					entrypoint.get("candidate_authority_horizon_enabled", false)
				),
				"entrypoint_candidate_authority_observation_count": int(
					entrypoint.get("candidate_authority_observation_count", -1)
				),
				"entrypoint_sdk_physical_trace_enabled": bool(
					entrypoint.get("sdk_physical_trace_enabled", true)
				),
				"entrypoint_sdk_terminal_restoration_enabled": bool(
					entrypoint.get("sdk_terminal_restoration_enabled", false)
				),
				"entrypoint_terminal_options_match": (
					(entrypoint.get("sdk_terminal_restoration_options", {}) as Dictionary)
					== prepared["compiled_terminal_options"]
				),
			},
		)
	return {
		"schema_version": R9_PREFLIGHT_SCHEMA,
		"ok": true,
		"failure_code": "",
		"campaign_id": R9_CAMPAIGN_ID,
		"gate_id": R9_GATE_ID,
		"engine_id": R9_ENGINE_ID,
		"stage_id": String(cell["stage_id"]),
		"cell_id": String(cell["cell_id"]),
		"arm_id": String(cell["arm_id"]),
		"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
		"terminal_policy_id": R9_HANDOFF_POLICY_ID,
		"active_acquisition_policy_id": R9NeutralStance.POLICY_ID,
		"fixed_controller_horizon_step_count": R9_CONTROLLER_STEPS,
		"fixed_terminal_handoff_step_count": R9_TERMINAL_STEPS,
		"fixed_total_trace_step_count": R9_TOTAL_STEPS,
		"maximum_active_neutral_acquisition_step_count": R9_MAXIMUM_ACTIVE_STEPS,
		"support_confirmation_step_count": R9_SUPPORT_CONFIRMATION_STEPS,
		"minimum_post_handoff_zero_actuation_step_count": R9_MINIMUM_PASSIVE_STEPS,
		"neutral_stance_algebra_canary_count": int(neutral["algebra_canary_count"]),
		"neutral_stance_mutation_control_count": int(neutral["mutation_control_count"]),
		"support_handoff_oracle_canary_count": int(handoff["oracle_canary_count"]),
		"support_handoff_mutation_control_count": int(handoff["mutation_control_count"]),
		"production_trace_constructor_canary_count": int(trace_canary.get("canary_count", -1)),
		"native_temporal_mirror": true,
		"transition_applies_to_following_step": true,
		"handoff_is_irreversible": true,
		"post_handoff_native_actuation_permitted": false,
		"physical_worker_implemented": true,
		"physical_worker_dormant_behind_supervisor_authorization": true,
		"physics_adapter_start_count": 0,
		"physical_process_launch_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
	}


func _r9_run_physical(cell: Dictionary, source_commit: String) -> Dictionary:
	if not _r8_valid_lower_hex(source_commit, 40):
		return _r9_worker_failure(
			cell, source_commit, "before_world", "QSDK_R23D9_GJT_SOURCE_COMMIT_INVALID", 0, 0
		)
	var authorization := _r9_physical_authorization(cell, source_commit)
	if not bool(authorization.get("ok", false)):
		return _r9_worker_failure(
			cell,
			source_commit,
			"before_world",
			String(authorization.get("failure_code", "QSDK_R23D9_GJT_AUTHORIZATION_INVALID")),
			0,
			0,
		)
	var preflight: Dictionary = await _r9_run_preflight(cell)
	if not bool(preflight.get("ok", false)):
		return _r9_worker_failure(
			cell,
			source_commit,
			"before_world",
			String(preflight.get("failure_code", "QSDK_R23D9_GJT_PREFLIGHT_INVALID")),
			0,
			0,
		)
	var prepared := _r9_prepare(cell)
	if not bool(prepared.get("ok", false)):
		return _r9_worker_failure(
			cell,
			source_commit,
			"before_world",
			String(prepared.get("failure_code", "QSDK_R23D9_GJT_PREPARE_INVALID")),
			0,
			0,
		)
	var summary: Dictionary = await _r8_run_wave(prepared, false)
	var world_build_count := int(summary.get("world_build_count", 0))
	var adapter_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var terminal: Dictionary = summary.get("sdk_terminal_restoration", {})
	if world_build_count != 1:
		return _r9_worker_failure(
			cell,
			source_commit,
			"world_construction_failed",
			"QSDK_R23D9_GJT_WORLD_BUILD_COUNT_INVALID",
			1,
			world_build_count,
		)
	var rows_value: Variant = terminal.get("trace_rows", null)
	if (
		typeof(rows_value) != TYPE_ARRAY
		or int(terminal.get("trace_row_count", -1)) != R9_TOTAL_STEPS
		or not (terminal.get("trace_failure_codes", []) as Array).is_empty()
	):
		return _r9_worker_failure(
			cell,
			source_commit,
			"settlement_complete",
			"QSDK_R23D9_GJT_TRACE_INCOMPLETE",
			1,
			1,
		)
	var retention := _r9_retain_trace(
		cell,
		rows_value,
		String(authorization["attempt_root"]),
	)
	if not bool(retention.get("ok", false)):
		return _r9_worker_failure(
			cell,
			source_commit,
			"settlement_complete",
			String(retention.get("failure_code", "QSDK_R23D9_GJT_TRACE_RETENTION_FAILED")),
			1,
			1,
		)
	var trace_artifact: Dictionary = retention["trace_artifact"]
	var horizon: Dictionary = summary.get("sdk_fixed_controller_horizon_receipt", {})
	var active_steps := int(terminal.get("active_terminal_step_count", -1))
	var passive_steps := int(terminal.get("passive_terminal_step_count", -1))
	var expected_active_applications := (R9_CONTROLLER_STEPS + active_steps) * 8
	var validated_commands := int(
		adapter_summary.get("validated_balanced_wave_command_count", -1)
	)
	var native_applications := (
		int(adapter_summary.get("native_actuation_application_count", -1))
		+ int(terminal.get("native_actuation_application_count", -1))
	)
	var direct_body_write_count := (
		int(summary.get("direct_torso_force_command_count", -1))
		+ int(summary.get("direct_torso_impulse_command_count", -1))
		+ int(summary.get("direct_torso_velocity_command_count", -1))
		+ int(summary.get("direct_torso_transform_command_count", -1))
	)
	var execution_integrity := (
		bool(horizon.get("exact", false))
		and int(horizon.get("expected_controller_step_count", -1)) == R9_CONTROLLER_STEPS
		and int(horizon.get("observed_controller_step_count", -1)) == R9_CONTROLLER_STEPS
		and direct_body_write_count == 0
		and int(summary.get("world_reset_count", -1)) == 0
		and String(terminal.get("failure_code", "not-present")).is_empty()
		and int(terminal.get("terminal_receipt_validation_failure_count", -1)) == 0
		and int(terminal.get("neutral_target_activation_failure_count", -1)) == 0
		and int(terminal.get("actuator_application_mismatch_count", -1)) == 0
		and bool(terminal.get("passive_zero_target_applied", false))
		and bool(terminal.get("support_confirmed_handoff_enabled", false))
		and active_steps + passive_steps == R9_TERMINAL_STEPS
		and validated_commands == expected_active_applications
		and native_applications == expected_active_applications
	)
	if not execution_integrity:
		return _r9_worker_failure(
			cell,
			source_commit,
			"settlement_complete",
			"QSDK_R23D9_GJT_EXECUTION_INTEGRITY_INVALID",
			1,
			1,
			trace_artifact,
		)
	var heading: Dictionary = summary.get("sdk_heading_schedule_receipt", {})
	var contact_source: Dictionary = summary.get("contact_cycle_count_by_limb", {})
	var sorted_contacts := {
		"front_left": int(contact_source.get("front_left", 0)),
		"front_right": int(contact_source.get("front_right", 0)),
		"rear_left": int(contact_source.get("rear_left", 0)),
		"rear_right": int(contact_source.get("rear_right", 0)),
	}
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
		"actuator_application_mismatch_count": int(
			terminal.get("actuator_application_mismatch_count", -1)
		),
		"controller_semantic_step_count": R9_CONTROLLER_STEPS,
		"terminal_support_handoff_step_count": R9_TERMINAL_STEPS,
		"validated_portable_command_count": validated_commands,
		"native_actuation_application_count": native_applications,
		"post_handoff_native_actuation_application_count": 0,
		"support_confirmed": bool(terminal.get("support_confirmed", false)),
		"handoff_after_active_step": terminal.get("handoff_after_active_step"),
		"first_passive_step": terminal.get("first_passive_step"),
		"handoff_reason": terminal.get("handoff_reason"),
		"active_terminal_step_count": active_steps,
		"passive_terminal_step_count": passive_steps,
		"first_post_handoff_contact_loss_step": terminal.get(
			"first_post_handoff_contact_loss_step"
		),
		"post_handoff_contact_loss_step_count": int(
			terminal.get("post_handoff_contact_loss_step_count", -1)
		),
		"terminal_receipt_validation_failure_count": int(
			terminal.get("terminal_receipt_validation_failure_count", -1)
		),
		"maximum_absolute_terminal_active_joint_velocity_rad_s": float(
			terminal.get("maximum_absolute_terminal_stance_joint_velocity_rad_s", NAN)
		),
	}
	return {
		"schema_version": R9_REPORT_SCHEMA,
		"campaign_id": R9_CAMPAIGN_ID,
		"gate_id": R9_GATE_ID,
		"stage_id": String(cell["stage_id"]),
		"cell_id": String(cell["cell_id"]),
		"engine_id": R9_ENGINE_ID,
		"arm_id": String(cell["arm_id"]),
		"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
		"source_commit": source_commit,
		"trace_artifact": trace_artifact.duplicate(true),
		"trace_summary": (retention["trace_summary"] as Dictionary).duplicate(true),
		"execution":
		{
			"integrity_passed": true,
			"worker_failure_code": "",
			"controller_semantic_step_count": R9_CONTROLLER_STEPS,
			"terminal_support_handoff_step_count": R9_TERMINAL_STEPS,
			"validated_portable_command_count": validated_commands,
			"native_actuation_application_count": native_applications,
			"post_handoff_native_actuation_application_count": 0,
			"portable_impulse_violation_count": 0,
			"world_attempt_count": 1,
			"world_build_count": 1,
			"trace_retained_before_terminal_entry": true,
			"fixed_horizon_configuration_proved_before_fixture_insertion": true,
		},
		"measurements": measurements,
		"claims": R9_FALSE_CLAIMS.duplicate(true),
	}


static func _r9_prepare(cell: Dictionary) -> Dictionary:
	var declaration := _r8_read_json(R9_PREREGISTRATION_PATH)
	if not _r9_contract_exact(declaration):
		return _r9_failure("QSDK_R23D9_GJT_CONTRACT_IDENTITY_INVALID")
	var inherited := _r8_prepare(cell)
	if not bool(inherited.get("ok", false)):
		return inherited
	var terminal := {
		"cell_id": String(cell["cell_id"]),
		"controller_step_count": R9_CONTROLLER_STEPS,
		"maximum_active_neutral_acquisition_step_count": R9_MAXIMUM_ACTIVE_STEPS,
		"minimum_post_handoff_zero_actuation_step_count": R9_MINIMUM_PASSIVE_STEPS,
		"support_confirmation_step_count": R9_SUPPORT_CONFIRMATION_STEPS,
		"terminal_handoff_policy_id": R9_HANDOFF_POLICY_ID,
		"terminal_restoration_policy_id": R9NeutralStance.POLICY_ID,
		"terminal_step_count": R9_TERMINAL_STEPS,
		"total_traced_step_count": R9_TOTAL_STEPS,
		"trace_row_schema_version": R9_TRACE_ROW_SCHEMA,
		"trace_schema_version": R9_TRACE_SCHEMA,
		"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
	}
	var terminal_result := R9WaveGaitScript.compile_sdk_terminal_restoration_options(terminal)
	if not bool(terminal_result.get("ok", false)):
		return terminal_result
	var prepared := inherited.duplicate(true)
	prepared["terminal_options"] = terminal
	prepared["compiled_terminal_options"] = terminal_result[
		"sdk_terminal_restoration_options"
	]
	return prepared


static func _r9_trace_canary(options: Dictionary) -> Dictionary:
	var contacts := {
		"front_left": true,
		"front_right": true,
		"rear_left": true,
		"rear_right": true,
	}
	var probes := [
		{
			"step": 0,
			"applications": 8,
			"receipt": {},
			"phase": "reference_warmup",
			"zero": false,
		},
		{
			"step": R9_CONTROLLER_STEPS,
			"applications": 8,
			"receipt": {
				"mode": R9SupportHandoff.ACTIVE_MODE,
				"pre_step_support_counter": 0,
				"post_step_support_counter": 1,
				"transition_after_step": false,
				"next_mode": R9SupportHandoff.ACTIVE_MODE,
				"handoff_reason": null,
				"native_application_count": 8,
			},
			"phase": "terminal_neutral_acquisition",
			"zero": false,
		},
		{
			"step": R9_CONTROLLER_STEPS + R9_SUPPORT_CONFIRMATION_STEPS - 1,
			"applications": 8,
			"receipt": {
				"mode": R9SupportHandoff.ACTIVE_MODE,
				"pre_step_support_counter": 29,
				"post_step_support_counter": 30,
				"transition_after_step": true,
				"next_mode": R9SupportHandoff.PASSIVE_MODE,
				"handoff_reason": R9SupportHandoff.SUPPORT_REASON,
				"native_application_count": 8,
			},
			"phase": "terminal_neutral_acquisition",
			"zero": false,
		},
		{
			"step": R9_CONTROLLER_STEPS + R9_SUPPORT_CONFIRMATION_STEPS,
			"applications": 0,
			"receipt": {
				"mode": R9SupportHandoff.PASSIVE_MODE,
				"pre_step_support_counter": 30,
				"post_step_support_counter": 30,
				"transition_after_step": false,
				"next_mode": R9SupportHandoff.PASSIVE_MODE,
				"handoff_reason": null,
				"native_application_count": 0,
			},
			"phase": "terminal_irreversible_zero_actuation",
			"zero": true,
		},
	]
	for probe_index in range(probes.size()):
		var probe: Dictionary = probes[probe_index]
		var result := R9WaveGaitScript._compose_sdk_terminal_trace_row(
			options,
			int(probe["step"]),
			0.1,
			0.4,
			0.1,
			false,
			contacts,
			int(probe["applications"]),
			8,
			0.05,
			0.35,
			probe["receipt"],
		)
		var row: Dictionary = result.get("row", {})
		if (
			not bool(result.get("ok", false))
			or String(row.get("phase_id", "")) != String(probe["phase"])
			or bool(row.get("zero_actuation", false)) != bool(probe["zero"])
			or int(row.get("native_actuation_application_count", -1))
			!= int(probe["applications"])
		):
			return _r9_failure(
				"QSDK_R23D9_GJT_TRACE_CANARY_INVALID",
				{
					"probe_index": probe_index,
					"constructor_ok": bool(result.get("ok", false)),
					"constructor_failure_code": String(result.get("failure_code", "")),
					"expected_phase_id": String(probe["phase"]),
					"actual_phase_id": String(row.get("phase_id", "")),
					"expected_zero_actuation": bool(probe["zero"]),
					"actual_zero_actuation": bool(row.get("zero_actuation", false)),
					"expected_native_actuation_application_count": int(
						probe["applications"]
					),
					"actual_native_actuation_application_count": int(
						row.get("native_actuation_application_count", -1)
					),
				},
			)
	return {
		"ok": true,
		"failure_code": "",
		"canary_count": probes.size(),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r9_contract_exact(declaration: Dictionary) -> bool:
	var schedule: Dictionary = declaration.get("frozen_schedule_and_gate_snapshot", {})
	var machine: Dictionary = declaration.get("handoff_state_machine_contract", {})
	return (
		String(declaration.get("schema_version", ""))
		== "sporespore_qsdk_r23d9_support_handoff_preregistration_v1"
		and String(declaration.get("campaign_id", "")) == R9_CAMPAIGN_ID
		and String(declaration.get("gate_id", "")) == R9_GATE_ID
		and int(schedule.get("turning_controller_semantic_step_count", -1))
		== R9_CONTROLLER_STEPS
		and int(schedule.get("terminal_support_handoff_step_count", -1))
		== R9_TERMINAL_STEPS
		and int(schedule.get("maximum_active_neutral_acquisition_steps", -1))
		== R9_MAXIMUM_ACTIVE_STEPS
		and int(schedule.get("support_confirmation_step_count", -1))
		== R9_SUPPORT_CONFIRMATION_STEPS
		and int(schedule.get("minimum_post_handoff_zero_actuation_steps", -1))
		== R9_MINIMUM_PASSIVE_STEPS
		and int(schedule.get("total_traced_step_count", -1)) == R9_TOTAL_STEPS
		and String(machine.get("initial_mode", "")) == R9SupportHandoff.ACTIVE_MODE
		and String(machine.get("passive_mode", "")) == R9SupportHandoff.PASSIVE_MODE
		and bool(machine.get("transition_is_applied_to_next_step", false))
		and not bool(machine.get("mode_reactivation_permitted", true))
		and not bool(
			(declaration.get("authorization", {}) as Dictionary).get(
				"physical_execution_authorized", true
			)
		)
	)


static func _r9_parse_arguments(args: PackedStringArray) -> Dictionary:
	var values := {}
	var preflight_only := false
	var authorization_preflight := false
	var index := 0
	while index < args.size():
		var argument := String(args[index])
		if argument == "--preflight-only" and not preflight_only:
			preflight_only = true
			index += 1
			continue
		if argument == "--authorization-preflight" and not authorization_preflight:
			authorization_preflight = true
			index += 1
			continue
		if ["--stage", "--arm", "--source-commit"].has(argument):
			if values.has(argument) or index + 1 >= args.size():
				return _r9_failure("QSDK_R23D9_GJT_ARGUMENT_DUPLICATE_OR_MISSING")
			values[argument] = String(args[index + 1])
			index += 2
			continue
		return _r9_failure("QSDK_R23D9_GJT_ARGUMENT_UNKNOWN:%s" % argument)
	if (
		not values.has("--stage")
		or not values.has("--arm")
		or (preflight_only and (authorization_preflight or values.has("--source-commit")))
		or (authorization_preflight and not values.has("--source-commit"))
		or (not preflight_only and not values.has("--source-commit"))
	):
		return _r9_failure("QSDK_R23D9_GJT_ARGUMENTS_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"stage_id": String(values["--stage"]),
		"arm_id": String(values["--arm"]),
		"preflight_only": preflight_only,
		"authorization_preflight": authorization_preflight,
		"source_commit": String(values.get("--source-commit", "")),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r9_cell(stage_id: String, arm_id: String) -> Dictionary:
	if stage_id != "three_engine_confirmation" or not R9_ARM_OFFSETS.has(arm_id):
		return _r9_failure("QSDK_R23D9_GJT_CELL_IDENTITY_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"stage_id": stage_id,
		"cell_id": "%s__support_handoff__%s" % [R9_ENGINE_ID, arm_id],
		"engine_id": R9_ENGINE_ID,
		"onset_id": "onset_600",
		"turn_start_semantic_step": 600,
		"arm_id": arm_id,
		"turn_heading_offset_rad": float(R9_ARM_OFFSETS[arm_id]),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r9_retain_trace(
	cell: Dictionary,
	rows: Array,
	attempt_root: String,
) -> Dictionary:
	var pending_root := attempt_root.path_join("pending-traces")
	if DirAccess.make_dir_recursive_absolute(pending_root) != OK:
		return _r9_failure("QSDK_R23D9_GJT_TRACE_ROOT_CREATE_FAILED")
	var rows_path := pending_root.path_join(
		"%s__%s.rows.json" % [String(cell["stage_id"]), String(cell["cell_id"])]
	)
	if FileAccess.file_exists(rows_path):
		return _r9_failure("QSDK_R23D9_GJT_TRACE_ROWS_ALREADY_EXIST")
	var file := FileAccess.open(rows_path, FileAccess.WRITE)
	if file == null:
		return _r9_failure("QSDK_R23D9_GJT_TRACE_ROWS_CREATE_FAILED")
	file.store_string(JSON.stringify(rows))
	file.store_string("\n")
	file.flush()
	file = null
	var python := OS.get_environment(R9_PYTHON_ENV)
	if python.is_empty():
		python = "python"
	var powershell := OS.get_environment(R9_POWERSHELL_ENV)
	if powershell.is_empty():
		powershell = "pwsh"
	var output: Array = []
	var exit_code := OS.execute(
		python,
		PackedStringArray(
			[
				ProjectSettings.globalize_path(R9_PHYSICAL_EVALUATOR_PATH),
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
	var marker := "QSDK_R23D9_EVALUATION "
	var matches: Array[String] = []
	for output_value in output:
		for line_value in String(output_value).split("\n"):
			var line := String(line_value).strip_edges()
			if line.begins_with(marker):
				matches.append(line.trim_prefix(marker))
	if exit_code != 0 or matches.size() != 1:
		return _r9_failure(
			"QSDK_R23D9_GJT_TRACE_RETENTION_FAILED:%d" % exit_code,
			{"output": output},
		)
	var parsed: Variant = JSON.parse_string(matches[0])
	if typeof(parsed) != TYPE_DICTIONARY:
		return _r9_failure("QSDK_R23D9_GJT_TRACE_RETENTION_RECEIPT_INVALID")
	var receipt: Dictionary = parsed
	if (
		String(receipt.get("schema_version", "")) != R9_TRACE_RETENTION_SCHEMA
		or String(receipt.get("stage_id", "")) != String(cell["stage_id"])
		or String(receipt.get("cell_id", "")) != String(cell["cell_id"])
		or not bool(receipt.get("retained_before_terminal_entry", false))
	):
		return _r9_failure("QSDK_R23D9_GJT_TRACE_RETENTION_RECEIPT_INVALID", receipt)
	receipt["ok"] = true
	receipt["failure_code"] = ""
	return receipt


static func _r9_physical_authorization(
	cell: Dictionary,
	source_commit: String,
) -> Dictionary:
	if FileAccess.file_exists(R9_CLOSURE_PATH):
		return _r9_failure("QSDK_R23D9_GJT_CLOSED")
	var freeze_path := OS.get_environment(R9_FREEZE_PATH_ENV)
	var attempt_path := OS.get_environment(R9_ATTEMPT_PATH_ENV)
	var token := OS.get_environment(R9_TOKEN_ENV)
	var attempt_root := OS.get_environment(R9_ATTEMPT_ROOT_ENV)
	if (
		not FileAccess.file_exists(R9_IMPLEMENTATION_PATH)
		or freeze_path.is_empty()
		or attempt_path.is_empty()
		or attempt_root.is_empty()
		or not FileAccess.file_exists(freeze_path)
		or not FileAccess.file_exists(attempt_path)
		or not DirAccess.dir_exists_absolute(attempt_root)
		or not _r8_valid_lower_hex(token, 32)
	):
		return _r9_failure("QSDK_R23D9_GJT_PHYSICAL_AUTHORIZATION_REQUIRED")
	var freeze := _r8_read_json(freeze_path)
	var attempt := _r8_read_json(attempt_path)
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
		and String(freeze.get("schema_version", "")) == R9_FREEZE_SCHEMA
		and String(freeze.get("campaign_id", "")) == R9_CAMPAIGN_ID
		and String(freeze.get("gate_id", "")) == R9_GATE_ID
		and String(freeze.get("status", "")) == "frozen_supervisor_only_physical_authorized"
		and String(freeze.get("preregistration_raw_sha256", ""))
		== _r8_raw_file_sha256(R9_PREREGISTRATION_PATH)
		and String(freeze.get("implementation_contract_raw_sha256", ""))
		== _r8_raw_file_sha256(R9_IMPLEMENTATION_PATH)
		and String(freeze.get("source_commit", "")) == source_commit
		and bool(freeze.get("physical_execution_authorized", false))
		and _r9_source_bindings_exact(freeze)
		and String(attempt.get("schema_version", "")) == R9_ATTEMPT_SCHEMA
		and String(attempt.get("campaign_id", "")) == R9_CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == R9_GATE_ID
		and String(attempt.get("freeze_raw_sha256", ""))
		== _r8_raw_file_sha256(freeze_path)
		and String(attempt.get("source_commit", "")) == source_commit
		and String(attempt.get("authorization_token", "")) == token
		and _r8_valid_lower_hex(String(attempt.get("attempt_id", "")), 32)
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
		and OS.get_environment(R9_STAGE_ENV) == String(cell["stage_id"])
		and OS.get_environment(R9_CELL_ENV) == String(cell["cell_id"])
		and OS.get_environment(R9_ENGINE_ENV) == R9_ENGINE_ID
		and stage_ids.has(String(cell["cell_id"]))
	)
	if not exact:
		return _r9_failure("QSDK_R23D9_GJT_PHYSICAL_AUTHORIZATION_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"attempt_root": normalized_attempt_root,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r9_source_bindings_exact(freeze: Dictionary) -> bool:
	var contract := _r8_read_json(R9_IMPLEMENTATION_PATH)
	var dependency_contract: Dictionary = contract.get("dependency_closure", {})
	var paths_by_worker: Dictionary = dependency_contract.get(
		"required_dependency_paths_by_worker", {}
	)
	var declared_value: Variant = paths_by_worker.get(R9_ENGINE_ID, null)
	if typeof(declared_value) != TYPE_ARRAY or (declared_value as Array).is_empty():
		return false
	var required := {}
	for path_value in declared_value as Array:
		if typeof(path_value) != TYPE_STRING:
			return false
		var path := String(path_value)
		if path.is_empty() or required.has(path):
			return false
		var resource_path := "res://" + path
		if not FileAccess.file_exists(resource_path):
			return false
		var digest := _r8_raw_file_sha256(resource_path)
		if not _r8_valid_raw_sha256(digest):
			return false
		required[path] = digest
	var bindings_value: Variant = freeze.get("source_bindings", null)
	if typeof(bindings_value) != TYPE_ARRAY:
		return false
	var observed := {}
	for item_value in bindings_value:
		if typeof(item_value) != TYPE_DICTIONARY:
			return false
		var item: Dictionary = item_value
		var path := String(item.get("path", ""))
		var digest := String(item.get("raw_sha256", ""))
		if path.is_empty() or not _r8_valid_raw_sha256(digest) or observed.has(path):
			return false
		observed[path] = digest
	for path_value in required:
		var path := String(path_value)
		if String(observed.get(path, "")) != String(required[path]):
			return false
	return true


static func _r9_worker_failure(
	cell: Dictionary,
	source_commit: String,
	failure_stage: String,
	failure_code: String,
	world_attempt_count: int,
	world_build_count: int,
	trace_artifact: Variant = null,
) -> Dictionary:
	return {
		"schema_version": R9_FAILURE_SCHEMA,
		"campaign_id": R9_CAMPAIGN_ID,
		"gate_id": R9_GATE_ID,
		"stage_id": String(cell.get("stage_id", "")),
		"cell_id": String(cell.get("cell_id", "")),
		"engine_id": R9_ENGINE_ID,
		"arm_id": String(cell.get("arm_id", "")),
		"turn_heading_offset_rad": float(cell.get("turn_heading_offset_rad", 0.0)),
		"source_commit": source_commit,
		"failure_stage": failure_stage,
		"failure_code": failure_code,
		"world_attempt_count": world_attempt_count,
		"world_build_count": world_build_count,
		"trace_artifact": trace_artifact,
		"claims": R9_FALSE_CLAIMS.duplicate(true),
	}


static func _r9_failure(code: String, detail: Dictionary = {}) -> Dictionary:
	var failure := {
		"ok": false,
		"failure_code": code,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
	for key_value in detail:
		failure[key_value] = detail[key_value]
	# Detail is diagnostic-only and must never be able to turn a failure green.
	failure["ok"] = false
	failure["failure_code"] = code
	failure["world_attempt_count"] = int(detail.get("world_attempt_count", 0))
	failure["world_build_count"] = int(detail.get("world_build_count", 0))
	failure["physical_acceptance_authority"] = false
	return failure
