extends "res://tests/test_sdk_qsdk_r23d9_support_handoff_godot_jolt_worker.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Dormant Godot/Jolt production worker for prospective QSDK-R23D20.
##
## The inherited R23D8 fixture and R23D19 heading-aligned walking controller
## remain exact. R23D20 repairs only adapter-session and evidence integration.
## During the active terminal only, the preexisting BW13P-A support/tilt plan
## is composed with bounded neutral velocity, and the complete sum is tapered
## before one host mapping. No world is reachable without exact supervisor
## authorization.

const R23D20WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const R23D20AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const R23D20NeutralStance := preload("res://scripts/lab/gait/sdk_godot_jolt_neutral_stance.gd")
const R23D20Taper := preload("res://scripts/lab/gait/sdk_godot_jolt_r23d14_tight_gated_horizon.gd")
const InheritedR23D11TaperActuation := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_stability_assisted_taper_actuation.gd"
)
const InheritedR23D11Composition := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_stability_assisted_taper.gd"
)
const InheritedR23D12Diagnostics := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_r23d12_measurement_semantics.gd"
)
const InheritedR23D13Authority := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_r23d13_residual_pose_authority.gd"
)

const R23D20_PREREGISTRATION_PATH := "res://sdk/turning/r23d20_actual_session_integration_recovery_preregistration_v1.json"
const R23D20_TEMPORAL_PREREGISTRATION_PATH := "res://sdk/turning/r23d14_tight_gated_horizon_preregistration_v1.json"
const R23D20_INHERITED_PREREGISTRATION_PATH := "res://sdk/turning/r23d11_stability_assisted_taper_preregistration_v1.json"
const R23D20_IMPLEMENTATION_PATH := "res://sdk/turning/r23d20_physical_implementation_contract_v1.json"
const R23D20_PHYSICAL_EVALUATOR_PATH := "res://sdk/turning/r23d20_physical_evaluator.py"
const R23D20_CLOSURE_PATH := "res://sdk/turning/r23d20_physical_closure_v1.json"
const R23D20_CAMPAIGN_ID := "QSDK-R23D20-ACTUAL-SESSION-INTEGRATION-RECOVERY-GODOT-DEVELOPMENT"
const R23D20_GATE_ID := "QSDK-R23D20"
const R23D20_ENGINE_ID := "godot_jolt"
const R23D20_PREFLIGHT_SCHEMA := "sporespore_qsdk_r23d20_godot_jolt_worker_preflight_v1"
const R23D20_REPORT_SCHEMA := "sporespore_qsdk_r23d20_engine_cell_report_v1"
const R23D20_FAILURE_SCHEMA := "sporespore_qsdk_r23d20_worker_failure_v1"
const R23D20_FREEZE_SCHEMA := "sporespore_qsdk_r23d20_physical_freeze_v1"
const R23D20_ATTEMPT_SCHEMA := "sporespore_qsdk_r23d20_attempt_v1"
const R23D20_TRACE_RETENTION_SCHEMA := "sporespore_qsdk_r23d20_trace_retention_v1"
const R23D20_TRACE_SCHEMA := "sporespore_qsdk_r23d20_physical_trace_v1"
const R23D20_TRACE_ROW_SCHEMA := "sporespore_qsdk_r23d20_physical_trace_row_v1"
const R23D20_CONTROLLER_STEPS := 2992
const R23D20_TERMINAL_STEPS := 960
const R23D20_TOTAL_STEPS := 3952
const R23D20_MAXIMUM_ACTIVE_STEPS := 600
const R23D20_MINIMUM_TAPER_STEPS := 120
const R23D20_MINIMUM_PASSIVE_STEPS := 360
const R23D20_TAPER_POLICY_ID := "sporespore_tight_gated_acquisition_active600_v1"
const R23D20_POLICY_ID := "sporespore_residual_pose_authority_quiescent_taper_v1"
const R23D20_CONTROLLER_POLICY_ID := "sporespore_balanced_wave_r23d19_heading_aligned_path_v1"
const R23D20_CROSS_TRACK_FRAME_MODE_ID := "command_heading_aligned_task_frame_v1"

const R23D20_FREEZE_PATH_ENV := "SPORESPORE_QSDK_R23D20_FREEZE"
const R23D20_ATTEMPT_PATH_ENV := "SPORESPORE_QSDK_R23D20_ATTEMPT"
const R23D20_TOKEN_ENV := "SPORESPORE_QSDK_R23D20_TOKEN"
const R23D20_STAGE_ENV := "SPORESPORE_QSDK_R23D20_STAGE"
const R23D20_CELL_ENV := "SPORESPORE_QSDK_R23D20_CELL"
const R23D20_ENGINE_ENV := "SPORESPORE_QSDK_R23D20_ENGINE"
const R23D20_ATTEMPT_ROOT_ENV := "SPORESPORE_QSDK_R23D20_ATTEMPT_ROOT"
const R23D20_PYTHON_ENV := "SPORESPORE_QSDK_R23D20_PYTHON"
const R23D20_POWERSHELL_ENV := "SPORESPORE_QSDK_R23D20_POWERSHELL"

const R23D20_ARM_OFFSETS := {
	"reference_zero": 0.0,
	"positive_heading": 0.2,
	"negative_heading": -0.2,
}
const R23D20_FALSE_CLAIMS := {
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
	var parsed := _r23d20_parse_arguments(OS.get_cmdline_user_args())
	if not bool(parsed.get("ok", false)):
		print("QSDK_R23D20_GODOT_JOLT_FAILURE ", JSON.stringify(parsed))
		quit(1)
		return
	var cell := _r23d20_cell(String(parsed["stage_id"]), String(parsed["arm_id"]))
	if not bool(cell.get("ok", false)):
		print("QSDK_R23D20_GODOT_JOLT_FAILURE ", JSON.stringify(cell))
		quit(1)
		return
	if bool(parsed["preflight_only"]):
		var preflight: Dictionary = await _r23d20_run_preflight(cell)
		if not bool(preflight.get("ok", false)):
			print("QSDK_R23D20_GODOT_JOLT_FAILURE ", JSON.stringify(preflight))
			quit(1)
			return
		print("QSDK_R23D20_GODOT_JOLT_PREFLIGHT ", JSON.stringify(preflight))
		quit(0)
		return
	if bool(parsed["authorization_preflight"]):
		var authorization := _r23d20_physical_authorization(
			cell,
			String(parsed["source_commit"]),
		)
		if not bool(authorization.get("ok", false)):
			print("QSDK_R23D20_GODOT_JOLT_FAILURE ", JSON.stringify(authorization))
			quit(1)
			return
		var receipt := {
			"schema_version":
			"sporespore_qsdk_r23d20_godot_jolt_production_" + "authorization_preflight_v1",
			"campaign_id": R23D20_CAMPAIGN_ID,
			"gate_id": R23D20_GATE_ID,
			"engine_id": R23D20_ENGINE_ID,
			"stage_id": String(cell["stage_id"]),
			"cell_id": String(cell["cell_id"]),
			"actual_production_authorization_function": "_r23d20_physical_authorization",
			"authorization_passed": true,
			"returned_before_model": true,
			"physical_process_launch_count": 0,
			"model_construction_count": 0,
			"world_attempt_count": 0,
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
		print("QSDK_R23D20_GODOT_JOLT_AUTHORIZATION_PREFLIGHT ", JSON.stringify(receipt))
		quit(0)
		return
	var terminal: Dictionary = await _r23d20_run_physical(
		cell,
		String(parsed["source_commit"]),
	)
	print("QSDK_R23D20_GODOT_JOLT_TERMINAL ", JSON.stringify(terminal))
	quit(0 if String(terminal.get("schema_version", "")) == R23D20_REPORT_SCHEMA else 1)


func _r23d20_run_preflight(cell: Dictionary) -> Dictionary:
	var solver_receipt := R23D3WorkerScript._apply_solver_configuration()
	var prepared := _r23d20_prepare(cell)
	if not bool(solver_receipt.get("ok", false)) or not bool(prepared.get("ok", false)):
		return _r23d20_failure(
			"QSDK_R23D20_GJT_PREPARE_INVALID",
			{"solver_receipt": solver_receipt, "prepared": prepared},
		)
	var entrypoint: Dictionary = await _r8_run_wave(prepared, true)
	var inherited_adapter_boundary := R23D3WorkerScript._adapter_boundary(prepared, cell)
	var selected_policy_adapter_boundary := _r23d20_selected_policy_adapter_boundary(
		prepared,
		cell,
	)
	var neutral := R23D20NeutralStance.run_zero_world_preflight()
	var taper := R23D20Taper.preflight()
	var composition := InheritedR23D11Composition.run_zero_world_preflight()
	var actuation := InheritedR23D11TaperActuation.run_zero_world_preflight()
	var diagnostics := InheritedR23D12Diagnostics.preflight()
	var authority := InheritedR23D13Authority.preflight()
	var composition_recovery := R23D20WaveGaitScript.run_sdk_terminal_handoff_reason_canary()
	var diagnostics_schema_canary := (
		R23D20WaveGaitScript.run_sdk_terminal_diagnostics_schema_canary()
	)
	var authority_envelope_canary := (
		R23D20WaveGaitScript.run_sdk_terminal_authority_input_envelope_canary()
	)
	var trace_canary: Dictionary = _r23d20_trace_canary(prepared["compiled_terminal_options"])
	var actual_diagnostics_canary := _r23d20_actual_diagnostics_composition_canary()
	var receipt_projection_canary := _r23d20_receipt_projection_canary()
	var exact: bool = (
		bool(entrypoint.get("ok", false))
		and int(entrypoint.get("actual_world_build_count", -1)) == 0
		and int(entrypoint.get("scene_tree_insertion_count", -1)) == 0
		and not bool(entrypoint.get("physics_state_modified", true))
		and bool(entrypoint.get("candidate_authority_horizon_enabled", false))
		and (
			int(entrypoint.get("candidate_authority_observation_count", -1))
			== R23D20_CONTROLLER_STEPS
		)
		and not bool(entrypoint.get("sdk_physical_trace_enabled", true))
		and bool(entrypoint.get("sdk_terminal_restoration_enabled", false))
		and (
			(entrypoint.get("sdk_terminal_restoration_options", {}) as Dictionary)
			== prepared["compiled_terminal_options"]
		)
		and bool(
			(
				(prepared["compiled_terminal_options"] as Dictionary)
				. get(
					"stability_assisted_taper_enabled",
					false,
				)
			)
		)
		and (
			String((prepared["authority_options"] as Dictionary).get("controller_policy_id", ""))
			== R23D20_CONTROLLER_POLICY_ID
		)
		and (
			String((prepared["authority_options"] as Dictionary).get("stability_policy_id", ""))
			== InheritedR23D11TaperActuation.STABILITY_POLICY_ID
		)
		and (
			float(
				(
					(prepared["authority_options"] as Dictionary)
					. get(
						"stability_influence_global_scale",
						NAN,
					)
				)
			)
			== InheritedR23D11Composition.GLOBAL_SCALE
		)
		and bool(inherited_adapter_boundary.get("ok", false))
		and bool(selected_policy_adapter_boundary.get("ok", false))
		and (
			String(selected_policy_adapter_boundary.get("controller_policy_id", ""))
			== R23D20_CONTROLLER_POLICY_ID
		)
		and int(selected_policy_adapter_boundary.get("native_controller_command_count", -1)) == 8
		and bool(neutral.get("ok", false))
		and int(neutral.get("algebra_canary_count", -1)) == 5
		and int(neutral.get("mutation_control_count", -1)) == 10
		and bool(taper.get("ok", false))
		and int(taper.get("valid_canary_count", -1)) == 12
		and int(taper.get("mutation_control_count", -1)) == 14
		and bool(taper.get("retained_positive_timing_shape_passed", false))
		and bool(taper.get("retained_negative_timing_shape_passed", false))
		and bool(composition.get("ok", false))
		and int(composition.get("composition_canary_count", -1)) == 7
		and int(composition.get("mutation_control_count", -1)) == 18
		and int(composition.get("inherited_temporal_canary_count", -1)) == 5
		and bool(actuation.get("ok", false))
		and int(actuation.get("actuation_bridge_canary_count", -1)) == 3
		and int(actuation.get("host_mapping_mutation_control_count", -1)) == 1
		and bool(diagnostics.get("ok", false))
		and int(diagnostics.get("valid_canary_count", -1)) == 7
		and int(diagnostics.get("active_cross_product_count", -1)) == 6
		and int(diagnostics.get("mutation_control_count", -1)) == 14
		and bool(diagnostics.get("critical_r23d11_failure_shape_passed", false))
		and bool(diagnostics.get("planner_and_support_margin_availability_are_independent", false))
		and bool(authority.get("ok", false))
		and int(authority.get("valid_canary_count", -1)) == 10
		and int(authority.get("mutation_control_count", -1)) == 20
		and not bool(authority.get("physical_worker_implemented", true))
		and bool(composition_recovery.get("ok", false))
		and int(composition_recovery.get("valid_canary_count", -1)) == 2
		and int(composition_recovery.get("mutation_control_count", -1)) == 1
		and int(composition_recovery.get("model_construction_count", -1)) == 0
		and int(composition_recovery.get("world_build_count", -1)) == 0
		and bool(diagnostics_schema_canary.get("ok", false))
		and int(diagnostics_schema_canary.get("positive_canary_count", -1)) == 3
		and int(diagnostics_schema_canary.get("mutation_control_count", -1)) == 1
		and int(diagnostics_schema_canary.get("model_construction_count", -1)) == 0
		and int(diagnostics_schema_canary.get("world_build_count", -1)) == 0
		and bool(authority_envelope_canary.get("ok", false))
		and int(authority_envelope_canary.get("positive_canary_count", -1)) == 8
		and int(authority_envelope_canary.get("mutation_control_count", -1)) == 8
		and bool(authority_envelope_canary.get("nested_compiled_morphology_unwrapped", false))
		and bool(authority_envelope_canary.get("missing_morphology_envelope_refused", false))
		and int(authority_envelope_canary.get("world_build_count", -1)) == 0
		and bool(trace_canary.get("ok", false))
		and int(trace_canary.get("canary_count", -1)) == 4
		and bool(actual_diagnostics_canary.get("ok", false))
		and int(actual_diagnostics_canary.get("positive_canary_count", -1)) == 2
		and int(actual_diagnostics_canary.get("mutation_control_count", -1)) == 1
		and bool(receipt_projection_canary.get("ok", false))
		and int(receipt_projection_canary.get("positive_canary_count", -1)) == 3
		and int(receipt_projection_canary.get("mutation_control_count", -1)) == 6
	)
	if not exact:
		return _r23d20_failure(
			"QSDK_R23D20_GJT_PREFLIGHT_INVALID",
			{
				"entrypoint": entrypoint,
				"inherited_adapter_boundary": inherited_adapter_boundary,
				"selected_policy_adapter_boundary": selected_policy_adapter_boundary,
				"neutral": neutral,
				"taper": taper,
				"composition": composition,
				"actuation": actuation,
				"diagnostics": diagnostics,
				"authority": authority,
				"composition_recovery": composition_recovery,
				"diagnostics_schema_canary": diagnostics_schema_canary,
				"authority_envelope_canary": authority_envelope_canary,
				"trace_canary": trace_canary,
				"actual_diagnostics_canary": actual_diagnostics_canary,
				"receipt_projection_canary": receipt_projection_canary,
			},
		)
	return {
		"schema_version": R23D20_PREFLIGHT_SCHEMA,
		"ok": true,
		"failure_code": "",
		"campaign_id": R23D20_CAMPAIGN_ID,
		"gate_id": R23D20_GATE_ID,
		"engine_id": R23D20_ENGINE_ID,
		"stage_id": String(cell["stage_id"]),
		"cell_id": String(cell["cell_id"]),
		"arm_id": String(cell["arm_id"]),
		"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
		"controller_policy_id": R23D20_CONTROLLER_POLICY_ID,
		"cross_track_frame_mode_id": R23D20_CROSS_TRACK_FRAME_MODE_ID,
		"terminal_policy_id": R23D20_TAPER_POLICY_ID,
		"residual_pose_authority_policy_id": R23D20_POLICY_ID,
		"active_acquisition_policy_id": R23D20NeutralStance.POLICY_ID,
		"fixed_controller_horizon_step_count": R23D20_CONTROLLER_STEPS,
		"fixed_terminal_quiescent_taper_step_count": R23D20_TERMINAL_STEPS,
		"fixed_total_trace_step_count": R23D20_TOTAL_STEPS,
		"maximum_active_neutral_acquisition_step_count": R23D20_MAXIMUM_ACTIVE_STEPS,
		"minimum_quiescent_taper_step_count": R23D20_MINIMUM_TAPER_STEPS,
		"minimum_post_handoff_zero_actuation_step_count": R23D20_MINIMUM_PASSIVE_STEPS,
		"neutral_stance_algebra_canary_count": int(neutral["algebra_canary_count"]),
		"neutral_stance_mutation_control_count": int(neutral["mutation_control_count"]),
		"tight_gated_temporal_canary_count": int(taper["valid_canary_count"]),
		"quiescent_taper_mutation_control_count": int(taper["mutation_control_count"]),
		"stability_composition_canary_count": int(composition["composition_canary_count"]),
		"stability_composition_mutation_control_count": int(composition["mutation_control_count"]),
		"stability_actuation_bridge_canary_count": int(actuation["actuation_bridge_canary_count"]),
		"diagnostic_valid_canary_count": int(diagnostics["valid_canary_count"]),
		"diagnostic_active_cross_product_count": int(diagnostics["active_cross_product_count"]),
		"diagnostic_mutation_control_count": int(diagnostics["mutation_control_count"]),
		"critical_r23d11_failure_shape_passed":
		bool(diagnostics["critical_r23d11_failure_shape_passed"]),
		"planner_and_support_margin_availability_are_independent": true,
		"inherited_r23d13_residual_pose_authority": true,
		"r23d14_tight_gated_horizon_inherited_unchanged": true,
		"r23d20_composition_recovery_identity_enabled": true,
		"nullable_terminal_summary_valid_canary_count":
		int(composition_recovery["valid_canary_count"]),
		"nullable_terminal_summary_mutation_control_count":
		int(composition_recovery["mutation_control_count"]),
		"production_diagnostics_schema_positive_canary_count":
		int(diagnostics_schema_canary["positive_canary_count"]),
		"production_diagnostics_schema_mutation_control_count":
		int(diagnostics_schema_canary["mutation_control_count"]),
		"live_authority_input_positive_canary_count":
		int(authority_envelope_canary["positive_canary_count"]),
		"live_authority_input_mutation_control_count":
		int(authority_envelope_canary["mutation_control_count"]),
		"command_time_feedback_is_previous_completed_step": true,
		"production_trace_constructor_canary_count": int(trace_canary["canary_count"]),
		"selected_policy_adapter_start_canary_count": 1,
		"actual_diagnostics_composition_positive_canary_count": int(
			actual_diagnostics_canary["positive_canary_count"]
		),
		"actual_diagnostics_composition_mutation_control_count": int(
			actual_diagnostics_canary["mutation_control_count"]
		),
		"receipt_integer_projection_positive_canary_count":
		int(receipt_projection_canary["positive_canary_count"]),
		"receipt_integer_projection_mutation_control_count":
		int(receipt_projection_canary["mutation_control_count"]),
		"projected_receipt_json": String(receipt_projection_canary["projected_receipt_json"]),
		"native_temporal_mirror": true,
		"canonical_scale_applied_before_host_mapping": true,
		"transition_applies_to_following_step": true,
		"handoff_is_irreversible": true,
		"post_handoff_native_actuation_permitted": false,
		"physical_worker_implemented": true,
		"physical_worker_dormant_behind_supervisor_authorization": true,
		"physics_adapter_start_count": 1,
		"physical_process_launch_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
	}


func _r23d20_run_physical(cell: Dictionary, source_commit: String) -> Dictionary:
	if not _r8_valid_lower_hex(source_commit, 40):
		return _r23d20_worker_failure(
			cell, source_commit, "before_world", "QSDK_R23D20_GJT_SOURCE_COMMIT_INVALID", 0, 0
		)
	var authorization := _r23d20_physical_authorization(cell, source_commit)
	if not bool(authorization.get("ok", false)):
		return _r23d20_worker_failure(
			cell,
			source_commit,
			"before_world",
			String(authorization.get("failure_code", "QSDK_R23D20_GJT_AUTHORIZATION_INVALID")),
			0,
			0,
		)
	var preflight: Dictionary = await _r23d20_run_preflight(cell)
	if not bool(preflight.get("ok", false)):
		return _r23d20_worker_failure(
			cell,
			source_commit,
			"before_world",
			String(preflight.get("failure_code", "QSDK_R23D20_GJT_PREFLIGHT_INVALID")),
			0,
			0,
		)
	var prepared := _r23d20_prepare(cell)
	if not bool(prepared.get("ok", false)):
		return _r23d20_worker_failure(
			cell,
			source_commit,
			"before_world",
			String(prepared.get("failure_code", "QSDK_R23D20_GJT_PREPARE_INVALID")),
			0,
			0,
		)
	var summary: Dictionary = await _r8_run_wave(prepared, false)
	var world_build_count := int(summary.get("world_build_count", 0))
	var adapter_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var terminal: Dictionary = summary.get("sdk_terminal_restoration", {})
	if world_build_count != 1:
		return _r23d20_worker_failure(
			cell,
			source_commit,
			"world_construction_failed",
			"QSDK_R23D20_GJT_WORLD_BUILD_COUNT_INVALID",
			1,
			world_build_count,
		)
	var rows_value: Variant = terminal.get("trace_rows", null)
	var trace_failure_codes_value: Variant = terminal.get("trace_failure_codes", null)
	var trace_failure_codes: Array = (
		(trace_failure_codes_value as Array).duplicate(true)
		if typeof(trace_failure_codes_value) == TYPE_ARRAY
		else ["QSDK_R23D20_GJT_TRACE_FAILURE_CODES_TYPE_INVALID"]
	)
	if (
		typeof(rows_value) != TYPE_ARRAY
		or int(terminal.get("trace_row_count", -1)) != R23D20_TOTAL_STEPS
		or not trace_failure_codes.is_empty()
	):
		return _r23d20_worker_failure(
			cell,
			source_commit,
			"settlement_complete",
			"QSDK_R23D20_GJT_TRACE_INCOMPLETE",
			1,
			1,
			{
				"diagnostic_only": true,
				"observed_trace_value_type": type_string(typeof(rows_value)),
				"observed_trace_row_count": int(terminal.get("trace_row_count", -1)),
				"trace_failure_codes": trace_failure_codes,
			},
		)
	var retention := _r23d20_retain_trace(
		cell,
		rows_value,
		String(authorization["attempt_root"]),
	)
	if not bool(retention.get("ok", false)):
		return _r23d20_worker_failure(
			cell,
			source_commit,
			"settlement_complete",
			String(retention.get("failure_code", "QSDK_R23D20_GJT_TRACE_RETENTION_FAILED")),
			1,
			1,
		)
	var trace_artifact: Dictionary = retention["trace_artifact"]
	var horizon: Dictionary = summary.get("sdk_fixed_controller_horizon_receipt", {})
	var active_steps := int(terminal.get("active_terminal_step_count", -1))
	var passive_steps := int(terminal.get("passive_terminal_step_count", -1))
	var expected_active_applications := (R23D20_CONTROLLER_STEPS + active_steps) * 8
	var validated_commands := int(adapter_summary.get("validated_balanced_wave_command_count", -1))
	var active_terminal_applications := int(
		terminal.get("active_terminal_native_actuation_application_count", -1)
	)
	var post_handoff_applications := int(
		terminal.get("post_handoff_native_actuation_application_count", -1)
	)
	var native_applications := int(adapter_summary.get("native_actuation_application_count", -1))
	var direct_body_write_count := (
		int(summary.get("direct_torso_force_command_count", -1))
		+ int(summary.get("direct_torso_impulse_command_count", -1))
		+ int(summary.get("direct_torso_velocity_command_count", -1))
		+ int(summary.get("direct_torso_transform_command_count", -1))
	)
	var execution_integrity := (
		bool(adapter_summary.get("ok", false))
		and bool(
			(
				adapter_summary
				. get(
					"stability_contribution_shadow_only_until_terminal",
					false,
				)
			)
		)
		and int(adapter_summary.get("external_terminal_application_step_count", -1)) == active_steps
		and (
			int(adapter_summary.get("external_terminal_motor_write_count", -1))
			== active_terminal_applications
		)
		and bool(horizon.get("exact", false))
		and int(horizon.get("expected_controller_step_count", -1)) == R23D20_CONTROLLER_STEPS
		and int(horizon.get("observed_controller_step_count", -1)) == R23D20_CONTROLLER_STEPS
		and direct_body_write_count == 0
		and int(summary.get("world_reset_count", -1)) == 0
		and String(terminal.get("failure_code", "not-present")).is_empty()
		and int(terminal.get("terminal_receipt_validation_failure_count", -1)) == 0
		and int(terminal.get("neutral_target_activation_failure_count", -1)) == 0
		and int(terminal.get("actuator_application_mismatch_count", -1)) == 0
		and bool(terminal.get("passive_zero_target_applied", false))
		and bool(terminal.get("quiescent_taper_enabled", false))
		and active_steps + passive_steps == R23D20_TERMINAL_STEPS
		and active_terminal_applications == active_steps * 8
		and post_handoff_applications == 0
		and validated_commands == expected_active_applications
		and native_applications == expected_active_applications
	)
	if not execution_integrity:
		return _r23d20_worker_failure(
			cell,
			source_commit,
			"settlement_complete",
			"QSDK_R23D20_GJT_EXECUTION_INTEGRITY_INVALID",
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
		"final_forward_displacement_m":
		float(summary.get("final_task_frame_forward_displacement_m", NAN)),
		"turn_phase_yaw_delta_rad": float(heading.get("turn_phase_yaw_delta_rad", NAN)),
		"maximum_absolute_requested_steering_fraction":
		float(heading.get("maximum_absolute_requested_steering_fraction", NAN)),
		"maximum_absolute_held_steering_fraction":
		float(heading.get("maximum_absolute_held_steering_fraction", NAN)),
		"maximum_tilt_rad": float(summary.get("maximum_tilt_rad", NAN)),
		"minimum_torso_height_m": float(summary.get("minimum_torso_height_m", NAN)),
		"contact_cycle_count_by_limb": sorted_contacts,
		"torso_ground_contact_step_count": int(summary.get("torso_contact_ticks", -1)),
		"controller_error_count": (adapter_summary.get("failure_codes", []) as Array).size(),
		"active_safe_no_actuation_count": int(adapter_summary.get("safe_no_actuation_count", -1)),
		"nonfinite_observation_count": 0,
		"actuator_application_mismatch_count":
		int(terminal.get("actuator_application_mismatch_count", -1)),
		"controller_semantic_step_count": R23D20_CONTROLLER_STEPS,
		"terminal_quiescent_taper_step_count": R23D20_TERMINAL_STEPS,
		"validated_portable_command_count": validated_commands,
		"native_actuation_application_count": native_applications,
		"post_handoff_native_actuation_application_count": post_handoff_applications,
		"confirmation_satisfied": bool(terminal.get("confirmation_satisfied", false)),
		"handoff_after_active_step": terminal.get("handoff_after_active_step"),
		"first_passive_step": terminal.get("first_passive_step"),
		"handoff_reason": terminal.get("handoff_reason"),
		"active_terminal_step_count": active_steps,
		"quiescent_taper_step_count": int(terminal.get("quiescent_taper_step_count", -1)),
		"passive_terminal_step_count": passive_steps,
		"taper_reset_count": int(terminal.get("taper_reset_count", -1)),
		"active_terminal_native_actuation_application_count": active_terminal_applications,
		"quiescent_taper_gate_passed": bool(terminal.get("quiescent_taper_gate_passed", false)),
		"first_post_handoff_contact_loss_step":
		terminal.get("first_post_handoff_contact_loss_step"),
		"post_handoff_contact_loss_step_count":
		int(terminal.get("post_handoff_contact_loss_step_count", -1)),
		"terminal_receipt_validation_failure_count":
		int(terminal.get("terminal_receipt_validation_failure_count", -1)),
		"maximum_absolute_terminal_active_joint_velocity_rad_s":
		float(terminal.get("maximum_absolute_terminal_stance_joint_velocity_rad_s", NAN)),
	}
	return {
		"schema_version": R23D20_REPORT_SCHEMA,
		"campaign_id": R23D20_CAMPAIGN_ID,
		"gate_id": R23D20_GATE_ID,
		"stage_id": String(cell["stage_id"]),
		"cell_id": String(cell["cell_id"]),
		"engine_id": R23D20_ENGINE_ID,
		"arm_id": String(cell["arm_id"]),
		"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
		"source_commit": source_commit,
		"trace_artifact": trace_artifact.duplicate(true),
		"trace_summary": (retention["trace_summary"] as Dictionary).duplicate(true),
		"execution":
		{
			"integrity_passed": true,
			"worker_failure_code": "",
			"controller_semantic_step_count": R23D20_CONTROLLER_STEPS,
			"terminal_quiescent_taper_step_count": R23D20_TERMINAL_STEPS,
			"validated_portable_command_count": validated_commands,
			"native_actuation_application_count": native_applications,
			"post_handoff_native_actuation_application_count": post_handoff_applications,
			"portable_impulse_violation_count": 0,
			"world_attempt_count": 1,
			"world_build_count": 1,
			"trace_retained_before_terminal_entry": true,
			"fixed_horizon_configuration_proved_before_fixture_insertion": true,
		},
		"measurements": measurements,
		"claims": R23D20_FALSE_CLAIMS.duplicate(true),
	}


static func _r23d20_selected_policy_adapter_boundary(
	prepared: Dictionary,
	cell: Dictionary,
) -> Dictionary:
	var adapter: RefCounted = R23D20AdapterScript.new()
	var phase_offset := int(
		(prepared["initial_perturbation"] as Dictionary)["gait_phase_offset_ticks"]
	)
	var authority_options: Dictionary = prepared["authority_options"]
	var start: Dictionary = (
		adapter
		. start(
			prepared["descriptor"],
			R23D3WorkerScript.GAIT_STEPS,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			PI * 0.5,
			R23D3WorkerScript.PHYSICS_HZ,
			R23D3WorkerScript.SOLVER_POLICY_OPTIONS,
			R23D3WorkerScript.SDK_COMPARISON_TOLERANCE,
			"clocked",
			true,
			phase_offset,
			360,
			"post_settle_full",
			String(authority_options["stability_policy_id"]),
			prepared["material_profile"],
			R23D20_CONTROLLER_POLICY_ID,
			float(authority_options["stability_influence_global_scale"]),
			true,
		)
	)
	if not bool(start.get("ok", false)):
		return _r23d20_failure(
			"QSDK_R23D20_GJT_SELECTED_POLICY_ADAPTER_START_INVALID:%s"
			% String(start.get("failure_code", "UNKNOWN")),
			{"start": start},
		)
	var command := {
		"schema_version": "sporespore_heading_offset_command_v1",
		"schedule_id": "qsdk_r23_three_phase_heading_v1",
		"segment_id": "commanded_turn",
		"command_role": "turn_heading",
		"heading_offset_rad": float(cell["turn_heading_offset_rad"]),
	}
	var runtime: Dictionary = adapter.preflight_perfect_declared_policy_runtime_boundary(command)
	var morphology: Dictionary = adapter.preflight_compiled_morphology_boundary()
	var manifest: Dictionary = start.get("adapter_manifest", {})
	var profile: Dictionary = manifest.get("controller_profile", {})
	var exact := (
		bool(runtime.get("ok", false))
		and bool(morphology.get("ok", false))
		and int(runtime.get("native_controller_command_count", -1)) == 8
		and int(runtime.get("actual_world_build_count", -1)) == 0
		and int(runtime.get("scene_tree_insertion_count", -1)) == 0
		and not bool(runtime.get("physics_state_modified", true))
		and String(start.get("controller_policy_id", "")) == R23D20_CONTROLLER_POLICY_ID
		and String(profile.get("policy_id", "")) == R23D20_CONTROLLER_POLICY_ID
		and (
			String(profile.get("cross_track_frame_mode_id", ""))
			== R23D20_CROSS_TRACK_FRAME_MODE_ID
		)
		and String(start.get("authority_scope", "")) == "post_settle_full"
	)
	adapter = null
	if not exact:
		return _r23d20_failure(
			"QSDK_R23D20_GJT_SELECTED_POLICY_ADAPTER_BOUNDARY_INVALID",
			{
				"start": start,
				"runtime": runtime,
				"morphology": morphology,
			},
		)
	return {
		"ok": true,
		"failure_code": "",
		"controller_policy_id": R23D20_CONTROLLER_POLICY_ID,
		"cross_track_frame_mode_id": R23D20_CROSS_TRACK_FRAME_MODE_ID,
		"native_controller_command_count": 8,
		"actual_world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _r23d20_actual_diagnostics_composition_canary() -> Dictionary:
	var sample_result := {
		"request": {
			"state": {
				"base_pose_world": {"position_m": {"x": 0.2, "y": 0.4, "z": 0.05}},
				"base_twist_world": {
					"linear_velocity_m_s": {"x": 0.1, "y": 0.0, "z": -0.02}
				},
				"task_frame": {
					"origin_world_m": {"x": 0.0, "y": 0.4, "z": 0.0},
					"lateral_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
					"reference_yaw_rad": 0.0,
				},
			},
			"command": {"desired_heading_rad": 0.2},
		},
		"stability_shadow": {
			"native_observation": {"minimum_dynamic_support_margin_m": 0.05}
		},
	}
	var step_result := {
		"native_output": {
			"actuation": {
				"receipt": {
					"cross_track_error_m": 0.01,
					"cross_track_velocity_m_s": -0.02,
					"measured_yaw_error_rad": 0.03,
					"desired_heading_error_rad": 0.18,
					"yaw_tracking_error_rad": -0.15,
					"requested_steering_fraction": -0.15,
					"held_steering_fraction": -0.075,
				}
			}
		},
		"stability_contribution_shadow": {
			"influence_receipt": {"availability": InheritedR23D11Composition.AVAILABLE}
		},
	}
	var controller := (
		R23D20WaveGaitScript
		. _r23d11_physical_trace_diagnostics_from_task_velocities(
			sample_result,
			step_result,
			{},
			0.1,
			-0.02,
			0.04,
			true,
			false,
			R23D20_TRACE_ROW_SCHEMA,
		)
	)
	var terminal := (
		R23D20WaveGaitScript
		. _r23d11_physical_trace_diagnostics_from_task_velocities(
			{},
			{},
			{},
			0.0,
			0.0,
			0.0,
			false,
			true,
			R23D20_TRACE_ROW_SCHEMA,
		)
	)
	var mutation := (
		R23D20WaveGaitScript
		. _r23d11_physical_trace_diagnostics_from_task_velocities(
			{},
			{},
			{},
			0.1,
			-0.02,
			0.04,
			true,
			false,
			R23D20_TRACE_ROW_SCHEMA,
		)
	)
	var exact := (
		bool(controller.get("ok", false))
		and is_finite(float(controller.get("cross_track_error_m", NAN)))
		and float(controller.get("legacy_fixed_axis_cross_track_error_m", NAN)) == 0.05
		and bool(terminal.get("ok", false))
		and terminal.get("requested_heading_error_rad") == null
		and not bool(mutation.get("ok", true))
		and (
			String(mutation.get("failure_code", ""))
			== "R23D19_GJT_PATH_DIAGNOSTIC_INPUT_INVALID"
		)
		and float(mutation.get("base_linear_velocity_task_forward_m_s", NAN)) == 0.1
	)
	return {
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R23D20_GJT_DIAGNOSTICS_CANARY_INVALID",
		"positive_canary_count": 2,
		"mutation_control_count": 1,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d20_prepare(cell: Dictionary) -> Dictionary:
	var declaration := _r8_read_json(R23D20_PREREGISTRATION_PATH)
	var temporal_declaration := _r8_read_json(R23D20_TEMPORAL_PREREGISTRATION_PATH)
	var inherited_declaration := _r8_read_json(R23D20_INHERITED_PREREGISTRATION_PATH)
	if not _r23d20_contract_exact(declaration, temporal_declaration, inherited_declaration):
		return _r23d20_failure("QSDK_R23D20_GJT_CONTRACT_IDENTITY_INVALID")
	var inherited := _r8_prepare(cell)
	if not bool(inherited.get("ok", false)):
		return inherited
	var terminal := {
		"cell_id": String(cell["cell_id"]),
		"controller_step_count": R23D20_CONTROLLER_STEPS,
		"maximum_active_neutral_acquisition_step_count": R23D20_MAXIMUM_ACTIVE_STEPS,
		"minimum_post_handoff_zero_actuation_step_count": R23D20_MINIMUM_PASSIVE_STEPS,
		"minimum_quiescent_taper_step_count": R23D20_MINIMUM_TAPER_STEPS,
		"terminal_restoration_policy_id": R23D20NeutralStance.POLICY_ID,
		"terminal_step_count": R23D20_TERMINAL_STEPS,
		"terminal_taper_policy_id": R23D20_TAPER_POLICY_ID,
		"residual_pose_authority_policy_id": R23D20_POLICY_ID,
		"total_traced_step_count": R23D20_TOTAL_STEPS,
		"trace_row_schema_version": R23D20_TRACE_ROW_SCHEMA,
		"trace_schema_version": R23D20_TRACE_SCHEMA,
		"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
	}
	var terminal_result := R23D20WaveGaitScript.compile_sdk_terminal_restoration_options(terminal)
	if not bool(terminal_result.get("ok", false)):
		return terminal_result
	var prepared := inherited.duplicate(true)
	var authority_options: Dictionary = prepared["authority_options"]
	authority_options["controller_policy_id"] = R23D20_CONTROLLER_POLICY_ID
	authority_options["stability_policy_id"] = InheritedR23D11TaperActuation.STABILITY_POLICY_ID
	authority_options["stability_influence_global_scale"] = InheritedR23D11Composition.GLOBAL_SCALE
	prepared["authority_options"] = authority_options
	prepared["terminal_options"] = terminal
	prepared["compiled_terminal_options"] = terminal_result["sdk_terminal_restoration_options"]
	return prepared


static func _r23d20_trace_canary(options: Dictionary) -> Dictionary:
	var contacts := {
		"front_left": true,
		"front_right": true,
		"rear_left": true,
		"rear_right": true,
	}
	var state := R23D20Taper.initial_state()
	var tight_observation := R23D20Taper.tight_observation()
	var active_scale := R23D20Taper.expected_velocity_scale(state)
	var active_transition := (
		R23D20Taper
		. observe_completed_step(
			state,
			tight_observation,
			8,
			int(active_scale["numerator"]),
			int(active_scale["denominator"]),
		)
	)
	state = active_transition["state"]
	var taper_scale := R23D20Taper.expected_velocity_scale(state)
	var taper_transition := (
		R23D20Taper
		. observe_completed_step(
			state,
			tight_observation,
			8,
			int(taper_scale["numerator"]),
			int(taper_scale["denominator"]),
		)
	)
	var passive_state := R23D20Taper.initial_state()
	passive_state["next_step"] = 700
	passive_state["mode"] = R23D20Taper.PASSIVE_MODE
	passive_state["confirmation_satisfied"] = true
	passive_state["handoff_after_active_step"] = 120
	passive_state["first_passive_step"] = 121
	passive_state["handoff_reason"] = R23D20Taper.CONFIRMED_REASON
	var passive_transition := (
		R23D20Taper
		. observe_completed_step(
			passive_state,
			tight_observation,
			0,
			0,
			120,
		)
	)
	var probes := [
		{"step": 0, "applications": 8, "receipt": {}, "phase": "reference_warmup"},
		{
			"step": R23D20_CONTROLLER_STEPS,
			"applications": 8,
			"receipt": active_transition["receipt"],
			"phase": "terminal_neutral_acquisition",
		},
		{
			"step": R23D20_CONTROLLER_STEPS + 1,
			"applications": 8,
			"receipt": taper_transition["receipt"],
			"phase": "terminal_quiescent_taper",
		},
		{
			"step": R23D20_CONTROLLER_STEPS + 700,
			"applications": 0,
			"receipt": passive_transition["receipt"],
			"phase": "terminal_irreversible_zero_actuation",
		},
	]
	for probe_index in range(probes.size()):
		var probe: Dictionary = probes[probe_index]
		var receipt: Dictionary = probe["receipt"]
		var passive := int(probe["applications"]) == 0
		var diagnostics := {
			"base_linear_velocity_task_forward_m_s": 0.0,
			"base_linear_velocity_task_lateral_m_s": 0.0,
			"base_angular_velocity_task_yaw_rad_s": 0.0,
			"minimum_dynamic_support_margin_m": null if passive else 0.05,
			"stability_planning_availability":
			null if passive else InheritedR23D11Composition.AVAILABLE,
			"ordered_applied_stability_velocity_deltas_rad_s":
			[
				0.0,
				0.0,
				0.0,
				0.0,
				0.0,
				0.0,
				0.0,
				0.0,
			],
		}
		for field_value in [
			"requested_heading_error_rad",
			"cross_track_error_m",
			"cross_track_velocity_m_s",
			"legacy_fixed_axis_cross_track_error_m",
			"legacy_fixed_axis_cross_track_velocity_m_s",
			"measured_yaw_error_rad",
			"desired_heading_error_rad",
			"yaw_tracking_error_rad",
			"requested_steering_fraction",
			"held_steering_fraction",
		]:
			diagnostics[String(field_value)] = (
				0.0 if int(probe["step"]) < R23D20_CONTROLLER_STEPS else null
			)
		var command_feedback: Dictionary = {}
		var authority_receipt: Dictionary = {}
		if not receipt.is_empty():
			var actuator_ids: Array = []
			var pre_taper: Array = []
			for actuator_index in range(8):
				actuator_ids.append("actuator_%d" % actuator_index)
				pre_taper.append(null if passive else 0.2)
			command_feedback = {
				"trace_step": int(probe["step"]) - 1,
				"contacts": [true, true, true, true],
				"ordered_foot_contacts": contacts.duplicate(true),
				"torso_tilt_rad": 0.005,
				"maximum_absolute_joint_position_error_rad": 0.1,
			}
			var authority_input := command_feedback.duplicate(true)
			authority_input["mode"] = String(receipt["mode"])
			authority_input["temporal_scale_numerator"] = int(receipt["velocity_scale_numerator"])
			authority_input["temporal_scale_denominator"] = int(
				receipt["velocity_scale_denominator"]
			)
			authority_input["actuator_ids"] = actuator_ids
			authority_input["combined_pre_taper_velocities_rad_s"] = pre_taper
			authority_receipt = InheritedR23D13Authority.apply_residual_pose_authority(
				authority_input
			)
			authority_receipt["pose_feedback"] = (
				InheritedR23D13Authority.pose_authority_floor(authority_input)
				if not passive
				else null
			)
			authority_receipt["combined_pre_taper_velocities_rad_s"] = pre_taper.duplicate()
		var result := (
			R23D20WaveGaitScript
			. _compose_sdk_r23d13_trace_row(
				options,
				int(probe["step"]),
				0.1,
				0.4,
				float(receipt.get("torso_tilt_rad", 0.1)),
				false,
				contacts,
				int(probe["applications"]),
				float(receipt.get("maximum_absolute_joint_position_error_rad", 0.0)),
				0.35,
				receipt,
				diagnostics,
				command_feedback,
				authority_receipt,
			)
		)
		var row: Dictionary = result.get("row", {})
		var diagnostic_result := (
			InheritedR23D12Diagnostics
			. validate_diagnostic_semantics(
				{
					"phase_class": "passive_observation" if passive else "active_control",
					"stability_planning_availability":
					(
						row.get("stability_planning_availability")
						if passive
						else str(row.get("stability_planning_availability", ""))
					),
					"minimum_dynamic_support_margin_availability":
					str(row.get("minimum_dynamic_support_margin_availability")),
					"minimum_dynamic_support_margin_m": row.get("minimum_dynamic_support_margin_m"),
					"ordered_applied_stability_velocity_deltas_rad_s":
					row.get("ordered_applied_stability_velocity_deltas_rad_s"),
				}
			)
		)
		if (
			not bool(result.get("ok", false))
			or not bool(diagnostic_result.get("ok", false))
			or String(row.get("phase_id", "")) != String(probe["phase"])
			or int(row.get("native_actuation_application_count", -1)) != int(probe["applications"])
			or row.keys().size() != 61
		):
			return _r23d20_failure(
				"QSDK_R23D20_GJT_TRACE_CANARY_INVALID",
				{
					"probe_index": probe_index,
					"result": result,
					"diagnostic_result": diagnostic_result,
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


static func _r23d20_contract_exact(
	declaration: Dictionary,
	temporal_declaration: Dictionary,
	inherited_declaration: Dictionary,
) -> bool:
	var successor: Dictionary = declaration.get("scientifically_distinct_successor", {})
	var mechanism: Dictionary = declaration.get("observed_failure_mechanism", {})
	var authorized: Dictionary = declaration.get("authorized_implementation_changes", {})
	var inherited: Dictionary = declaration.get("inherited_physical_contract", {})
	var matrix: Dictionary = declaration.get("prospective_screen", {})
	var qualification: Dictionary = declaration.get("zero_world_entry_gate", {})
	var temporal: Dictionary = temporal_declaration.get("terminal_policy_contract", {})
	var composition: Dictionary = temporal_declaration.get("inherited_whole_body_composition", {})
	var authority: Dictionary = temporal_declaration.get("inherited_residual_pose_authority", {})
	return (
		(
			String(declaration.get("schema_version", ""))
			== "sporespore_qsdk_r23d20_actual_session_integration_recovery_preregistration_v1"
		)
		and String(declaration.get("campaign_id", "")) == R23D20_CAMPAIGN_ID
		and String(declaration.get("gate_id", "")) == R23D20_GATE_ID
		and (
			String(temporal_declaration.get("schema_version", ""))
			== "sporespore_qsdk_r23d14_tight_gated_horizon_preregistration_v1"
		)
		and (
			String(temporal_declaration.get("campaign_id", ""))
			== "QSDK-R23D14-TIGHT-GATED-HORIZON-THREE-ENGINE-TURN-CONFIRMATION"
		)
		and (
			String(composition.get("preregistration_raw_sha256", ""))
			== _r8_raw_file_sha256(R23D20_INHERITED_PREREGISTRATION_PATH)
		)
		and String(successor.get("controller_policy_id", "")) == R23D20_CONTROLLER_POLICY_ID
		and not bool(successor.get("controller_policy_changed", true))
		and not bool(successor.get("controller_semantics_changed", true))
		and not bool(successor.get("controller_gain_changed", true))
		and not bool(successor.get("steering_filter_changed", true))
		and not bool(successor.get("stride_transform_changed", true))
		and not bool(successor.get("engine_specific_gait_logic_permitted", true))
		and not bool(successor.get("arm_identity_or_outcome_branching_permitted", true))
		and (
			String(mechanism.get("godot_adapter_missing_policy_id", ""))
			== R23D20_CONTROLLER_POLICY_ID
		)
		and String(mechanism.get("adapter_start_failure_code", "")) == "ADAPTER_START_INPUT_INVALID"
		and bool(mechanism.get("adapter_start_failed_before_compiled_morphology", false))
		and not bool(mechanism.get("physics_or_controller_outcome_inference_permitted", true))
		and bool(
			authorized.get(
				"add_selected_policy_to_godot_adapter_balanced_wave_and_full_authority_allowlists",
				false,
			)
		)
		and bool(
			authorized.get(
				"preserve_specific_path_diagnostic_failure_while_retaining_inherited_diagnostics",
				false,
			)
		)
		and bool(
			authorized.get(
				"parse_exactly_one_structured_worker_terminal_independent_of_process_exit_code",
				false,
			)
		)
		and not bool(authorized.get("change_physics_or_controller_output", true))
		and not bool(authorized.get("change_outcome_evaluator_rules", true))
		and String(inherited.get("terminal_policy_id", "")) == R23D20_TAPER_POLICY_ID
		and int(inherited.get("controller_step_count", -1)) == R23D20_CONTROLLER_STEPS
		and int(inherited.get("terminal_step_count", -1)) == R23D20_TERMINAL_STEPS
		and int(inherited.get("total_trace_row_count_per_cell", -1)) == R23D20_TOTAL_STEPS
		and (
			int(inherited.get("maximum_active_neutral_acquisition_step_count", -1))
			== R23D20_MAXIMUM_ACTIVE_STEPS
		)
		and (
			int(inherited.get("minimum_confirmed_taper_step_count", -1))
			== R23D20_MINIMUM_TAPER_STEPS
		)
		and (
			int(inherited.get("minimum_post_handoff_zero_actuation_step_count", -1))
			== R23D20_MINIMUM_PASSIVE_STEPS
		)
		and float(inherited.get("tight_maximum_torso_tilt_rad", NAN)) == 0.01
		and float(inherited.get("tight_maximum_joint_position_error_rad", NAN)) == 0.2
		and not bool(successor.get("fixture_changed", true))
		and not bool(successor.get("morphology_changed", true))
		and not bool(successor.get("threshold_changed", true))
		and not bool(successor.get("horizon_changed", true))
		and int(temporal.get("terminal_step_count", -1)) == R23D20_TERMINAL_STEPS
		and int(temporal.get("maximum_active_step_count", -1)) == R23D20_MAXIMUM_ACTIVE_STEPS
		and (
			int(temporal.get("minimum_quiescent_taper_step_count", -1))
			== R23D20_MINIMUM_TAPER_STEPS
		)
		and int(temporal.get("minimum_passive_step_count", -1)) == R23D20_MINIMUM_PASSIVE_STEPS
		and String(temporal.get("initial_mode", "")) == R23D20Taper.ACTIVE_MODE
		and String(temporal.get("quiescent_mode", "")) == R23D20Taper.TAPER_MODE
		and String(temporal.get("passive_mode", "")) == R23D20Taper.PASSIVE_MODE
		and (
			float(composition.get("maximum_absolute_stability_velocity_delta_rad_s", NAN))
			== InheritedR23D11Composition.MAXIMUM_STABILITY_DELTA
		)
		and (
			float(composition.get("neutral_base_velocity_limit_rad_s", NAN))
			== InheritedR23D11Composition.MAXIMUM_NEUTRAL_VELOCITY
		)
		and (
			float(composition.get("maximum_pre_taper_combined_velocity_magnitude_rad_s", NAN))
			== InheritedR23D11Composition.MAXIMUM_COMBINED_VELOCITY
		)
		and bool(
			composition.get("complete_neutral_plus_stability_command_is_feedback_scaled", false)
		)
		and bool(composition.get("host_mapping_applied_once_after_feedback_scale", false))
		and (
			int(authority.get("scale_denominator", -1))
			== InheritedR23D13Authority.SCALE_DENOMINATOR
		)
		and (
			int(authority.get("maximum_floor_numerator", -1))
			== InheritedR23D13Authority.SCALE_DENOMINATOR
		)
		and bool(authority.get("authority_floor_may_never_reduce_temporal_authority", false))
		and bool(authority.get("complete_combined_velocity_scaled_once_before_host_mapping", false))
		and not bool(authority.get("arm_identity_heading_sign_or_outcome_branching", true))
		and bool(temporal.get("tight_pose_loss_resets_to_full_acquisition", false))
		and bool(temporal.get("all_960_terminal_steps_execute", false))
		and String(matrix.get("stage_id", "")) == "godot_jolt_actual_session_integration_recovery_development"
		and int(matrix.get("declared_cell_count", -1)) == 3
		and (matrix.get("ordered_engine_ids", []) as Array) == [R23D20_ENGINE_ID]
		and (
			(matrix.get("ordered_arm_ids", []) as Array)
			== ["reference_zero", "positive_heading", "negative_heading"]
		)
		and bool(matrix.get("serialized_execution_required", false))
		and bool(matrix.get("all_cells_run_without_outcome_early_stop", false))
		and not bool(matrix.get("selective_replacement_or_rerun_permitted", true))
		and bool(qualification.get("exact_selected_policy_adapter_start_required", false))
		and bool(qualification.get("actual_diagnostics_composition_path_required", false))
		and bool(
			qualification.get(
				"nonzero_exit_structured_failure_terminal_reproduction_required",
				false,
			)
		)
		and not bool(qualification.get("physical_execution_authorized", true))
		and _r23d20_inherited_contract_exact(inherited_declaration)
	)


static func _r23d20_inherited_contract_exact(declaration: Dictionary) -> bool:
	var inherited: Dictionary = declaration.get("inherited_unchanged_scientific_contract", {})
	var terminal: Dictionary = declaration.get("inherited_temporal_contract", {})
	var composition: Dictionary = declaration.get("stability_assisted_composition_contract", {})
	return (
		(
			String(declaration.get("schema_version", ""))
			== "sporespore_qsdk_r23d11_stability_assisted_taper_preregistration_v1"
		)
		and (
			String(declaration.get("campaign_id", ""))
			== (
				"QSDK-R23D11-SUPPORT-CENTROID-ASSISTED-QUIESCENT-TAPER-"
				+ "BILATERAL-TURN-DEVELOPMENT"
			)
		)
		and String(declaration.get("gate_id", "")) == "QSDK-R23D11"
		and (
			int(inherited.get("turning_controller_semantic_step_count", -1))
			== R23D20_CONTROLLER_STEPS
		)
		and int(terminal.get("terminal_step_count", -1)) == 900
		and int(terminal.get("maximum_active_step_count", -1)) == 540
		and int(terminal.get("minimum_quiescent_taper_step_count", -1)) == 120
		and int(terminal.get("minimum_passive_step_count", -1)) == 360
		and String(terminal.get("initial_mode", "")) == R23D20Taper.ACTIVE_MODE
		and String(terminal.get("quiescent_mode", "")) == R23D20Taper.TAPER_MODE
		and String(terminal.get("passive_mode", "")) == R23D20Taper.PASSIVE_MODE
		and not bool(terminal.get("mode_reactivation_after_passive_handoff_permitted", true))
		and bool(terminal.get("all_900_terminal_steps_execute", false))
		and (
			String(composition.get("stability_policy_id", ""))
			== InheritedR23D11TaperActuation.STABILITY_POLICY_ID
		)
		and (
			float(composition.get("global_requested_correction_scale", NAN))
			== InheritedR23D11Composition.GLOBAL_SCALE
		)
		and (
			float(composition.get("maximum_absolute_velocity_delta_rad_s", NAN))
			== InheritedR23D11Composition.MAXIMUM_STABILITY_DELTA
		)
		and (
			float(composition.get("maximum_velocity_delta_slew_per_step_rad_s", NAN))
			== InheritedR23D11Composition.MAXIMUM_STABILITY_SLEW
		)
		and (
			float(composition.get("neutral_base_velocity_limit_rad_s", NAN))
			== InheritedR23D11Composition.MAXIMUM_NEUTRAL_VELOCITY
		)
		and (
			float(composition.get("maximum_pre_taper_combined_velocity_magnitude_rad_s", NAN))
			== InheritedR23D11Composition.MAXIMUM_COMBINED_VELOCITY
		)
		and bool(composition.get("canonical_velocity_composed_once", false))
		and bool(composition.get("host_mapping_applied_once", false))
		and bool(
			(
				composition
				. get(
					"complete_combined_canonical_velocity_tapered_before_host_mapping",
					false,
				)
			)
		)
		and not bool(composition.get("arm_id_heading_sign_or_outcome_may_branch_composition", true))
		and not bool(
			(declaration.get("stage_zero_authority", {}) as Dictionary).get(
				"physical_execution_authorized", true
			)
		)
	)


static func _r23d20_parse_arguments(args: PackedStringArray) -> Dictionary:
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
				return _r23d20_failure("QSDK_R23D20_GJT_ARGUMENT_DUPLICATE_OR_MISSING")
			values[argument] = String(args[index + 1])
			index += 2
			continue
		return _r23d20_failure("QSDK_R23D20_GJT_ARGUMENT_UNKNOWN:%s" % argument)
	if (
		not values.has("--stage")
		or not values.has("--arm")
		or (preflight_only and (authorization_preflight or values.has("--source-commit")))
		or (authorization_preflight and not values.has("--source-commit"))
		or (not preflight_only and not values.has("--source-commit"))
	):
		return _r23d20_failure("QSDK_R23D20_GJT_ARGUMENTS_INVALID")
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


static func _r23d20_cell(stage_id: String, arm_id: String) -> Dictionary:
	if (
		stage_id != "godot_jolt_actual_session_integration_recovery_development"
		or not R23D20_ARM_OFFSETS.has(arm_id)
	):
		return _r23d20_failure("QSDK_R23D20_GJT_CELL_IDENTITY_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"stage_id": stage_id,
		"cell_id": "%s__tight_gated_horizon__%s" % [R23D20_ENGINE_ID, arm_id],
		"engine_id": R23D20_ENGINE_ID,
		"onset_id": "onset_600",
		"turn_start_semantic_step": 600,
		"arm_id": arm_id,
		"turn_heading_offset_rad": float(R23D20_ARM_OFFSETS[arm_id]),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d20_retain_trace(
	cell: Dictionary,
	rows: Array,
	attempt_root: String,
) -> Dictionary:
	var pending_root := attempt_root.path_join("pending-traces")
	if DirAccess.make_dir_recursive_absolute(pending_root) != OK:
		return _r23d20_failure("QSDK_R23D20_GJT_TRACE_ROOT_CREATE_FAILED")
	var rows_path := pending_root.path_join(
		"%s__%s.rows.json" % [String(cell["stage_id"]), String(cell["cell_id"])]
	)
	if FileAccess.file_exists(rows_path):
		return _r23d20_failure("QSDK_R23D20_GJT_TRACE_ROWS_ALREADY_EXIST")
	var file := FileAccess.open(rows_path, FileAccess.WRITE)
	if file == null:
		return _r23d20_failure("QSDK_R23D20_GJT_TRACE_ROWS_CREATE_FAILED")
	file.store_string(JSON.stringify(rows))
	file.store_string("\n")
	file.flush()
	file = null
	var python := OS.get_environment(R23D20_PYTHON_ENV)
	if python.is_empty():
		python = "python"
	var powershell := OS.get_environment(R23D20_POWERSHELL_ENV)
	if powershell.is_empty():
		powershell = "pwsh"
	var output: Array = []
	var exit_code := (
		OS
		. execute(
			python,
			PackedStringArray(
				[
					ProjectSettings.globalize_path(R23D20_PHYSICAL_EVALUATOR_PATH),
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
	)
	var marker := "QSDK_R23D20_TRACE_RETENTION "
	var matches: Array[String] = []
	for output_value in output:
		for line_value in String(output_value).split("\n"):
			var line := String(line_value).strip_edges()
			if line.begins_with(marker):
				matches.append(line.trim_prefix(marker))
	if exit_code != 0 or matches.size() != 1:
		return _r23d20_failure(
			"QSDK_R23D20_GJT_TRACE_RETENTION_FAILED:%d" % exit_code,
			{"output": output},
		)
	var parsed: Variant = JSON.parse_string(matches[0])
	if typeof(parsed) != TYPE_DICTIONARY:
		return _r23d20_failure("QSDK_R23D20_GJT_TRACE_RETENTION_RECEIPT_INVALID")
	var receipt: Dictionary = parsed
	if (
		String(receipt.get("schema_version", "")) != R23D20_TRACE_RETENTION_SCHEMA
		or String(receipt.get("stage_id", "")) != String(cell["stage_id"])
		or String(receipt.get("cell_id", "")) != String(cell["cell_id"])
		or not bool(receipt.get("retained_before_terminal_entry", false))
	):
		return _r23d20_failure("QSDK_R23D20_GJT_TRACE_RETENTION_RECEIPT_INVALID", receipt)
	var projected := _r23d20_integer_receipt_projection(receipt)
	if not bool(projected.get("ok", false)):
		return projected
	receipt = (projected["receipt"] as Dictionary).duplicate(true)
	receipt["ok"] = true
	receipt["failure_code"] = ""
	return receipt


static func _r23d20_integer_receipt_projection(receipt_value: Variant) -> Dictionary:
	if typeof(receipt_value) != TYPE_DICTIONARY:
		return _r23d20_failure("QSDK_R23D20_GJT_TRACE_ARTIFACT_RECEIPT_TYPE_INVALID")
	var receipt := (receipt_value as Dictionary).duplicate(true)
	var artifact_value: Variant = receipt.get("trace_artifact", null)
	if typeof(artifact_value) != TYPE_DICTIONARY:
		return _r23d20_failure("QSDK_R23D20_GJT_TRACE_ARTIFACT_RECEIPT_TYPE_INVALID")
	var artifact := (artifact_value as Dictionary).duplicate(true)
	var byte_length_value: Variant = artifact.get("byte_length", null)
	if typeof(byte_length_value) != TYPE_INT and typeof(byte_length_value) != TYPE_FLOAT:
		return _r23d20_failure("QSDK_R23D20_GJT_TRACE_ARTIFACT_BYTE_LENGTH_INVALID")
	var byte_length_number := float(byte_length_value)
	if (
		not is_finite(byte_length_number)
		or byte_length_number < 0.0
		or byte_length_number > 9007199254740991.0
		or byte_length_number != floorf(byte_length_number)
	):
		return _r23d20_failure("QSDK_R23D20_GJT_TRACE_ARTIFACT_BYTE_LENGTH_INVALID")
	artifact["byte_length"] = int(byte_length_number)
	receipt["trace_artifact"] = artifact
	return {"ok": true, "failure_code": "", "receipt": receipt}


static func _r23d20_receipt_projection_canary() -> Dictionary:
	var base := {
		"trace_artifact":
		{
			"schema_version": "sporespore_content_addressed_artifact_receipt_v1",
			"sha256": "sha256:" + "0".repeat(64),
			"byte_length": 17.0,
			"payload_path": "C:/evidence/payload.bin",
			"manifest_path": "C:/evidence/manifest.json",
			"already_present": false,
			"test_only": true,
			"physical_acceptance_authority": false,
		}
	}
	var projected := _r23d20_integer_receipt_projection(base)
	var projected_receipt: Dictionary = projected.get("receipt", {})
	var projected_artifact: Dictionary = projected_receipt.get("trace_artifact", {})
	var projected_json := JSON.stringify(projected_receipt)
	var positive_canary_count := 0
	positive_canary_count += int(bool(projected.get("ok", false)))
	positive_canary_count += int(typeof(projected_artifact.get("byte_length")) == TYPE_INT)
	positive_canary_count += int(projected_json.contains('"byte_length":17'))
	var mutations: Array[Variant] = [null, "17", -1, 17.5, NAN, INF]
	var mutation_control_count := 0
	for mutation in mutations:
		var candidate := base.duplicate(true)
		(candidate["trace_artifact"] as Dictionary)["byte_length"] = mutation
		var result := _r23d20_integer_receipt_projection(candidate)
		mutation_control_count += int(
			(
				not bool(result.get("ok", false))
				and (
					String(result.get("failure_code", ""))
					== "QSDK_R23D20_GJT_TRACE_ARTIFACT_BYTE_LENGTH_INVALID"
				)
			)
		)
	return {
		"ok": positive_canary_count == 3 and mutation_control_count == mutations.size(),
		"positive_canary_count": positive_canary_count,
		"mutation_control_count": mutation_control_count,
		"projected_receipt_json": projected_json,
		"model_construction_count": 0,
		"world_build_count": 0,
	}


static func _r23d20_physical_authorization(
	cell: Dictionary,
	source_commit: String,
) -> Dictionary:
	if FileAccess.file_exists(R23D20_CLOSURE_PATH):
		return _r23d20_failure("QSDK_R23D20_GJT_CLOSED")
	var freeze_path := OS.get_environment(R23D20_FREEZE_PATH_ENV)
	var attempt_path := OS.get_environment(R23D20_ATTEMPT_PATH_ENV)
	var token := OS.get_environment(R23D20_TOKEN_ENV)
	var attempt_root := OS.get_environment(R23D20_ATTEMPT_ROOT_ENV)
	if (
		not FileAccess.file_exists(R23D20_IMPLEMENTATION_PATH)
		or freeze_path.is_empty()
		or attempt_path.is_empty()
		or attempt_root.is_empty()
		or not FileAccess.file_exists(freeze_path)
		or not FileAccess.file_exists(attempt_path)
		or not DirAccess.dir_exists_absolute(attempt_root)
		or not _r8_valid_lower_hex(token, 32)
	):
		return _r23d20_failure("QSDK_R23D20_GJT_PHYSICAL_AUTHORIZATION_REQUIRED")
	var freeze := _r8_read_json(freeze_path)
	var attempt := _r8_read_json(attempt_path)
	var production_root := (
		ProjectSettings
		. globalize_path("res://../SporeSpore_Evidence")
		. simplify_path()
		. replace("\\", "/")
		. trim_suffix("/")
	)
	var normalized_attempt_root := attempt_root.simplify_path().replace("\\", "/").trim_suffix("/")
	var matrix_ids: Array = attempt.get("ordered_matrix_cell_ids", [])
	var expected_matrix_ids := [
		"godot_jolt__tight_gated_horizon__reference_zero",
		"godot_jolt__tight_gated_horizon__positive_heading",
		"godot_jolt__tight_gated_horizon__negative_heading",
	]
	var exact := (
		(
			normalized_attempt_root == production_root
			or normalized_attempt_root.begins_with(production_root + "/")
		)
		and String(freeze.get("schema_version", "")) == R23D20_FREEZE_SCHEMA
		and String(freeze.get("campaign_id", "")) == R23D20_CAMPAIGN_ID
		and String(freeze.get("gate_id", "")) == R23D20_GATE_ID
		and String(freeze.get("status", "")) == "frozen_supervisor_only_physical_authorized"
		and (
			String(freeze.get("preregistration_raw_sha256", ""))
			== _r8_raw_file_sha256(R23D20_PREREGISTRATION_PATH)
		)
		and (
			String(freeze.get("implementation_contract_raw_sha256", ""))
			== _r8_raw_file_sha256(R23D20_IMPLEMENTATION_PATH)
		)
		and String(freeze.get("source_commit", "")) == source_commit
		and bool(freeze.get("physical_execution_authorized", false))
		and _r23d20_source_bindings_exact(freeze)
		and String(attempt.get("schema_version", "")) == R23D20_ATTEMPT_SCHEMA
		and String(attempt.get("campaign_id", "")) == R23D20_CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == R23D20_GATE_ID
		and String(attempt.get("freeze_raw_sha256", "")) == _r8_raw_file_sha256(freeze_path)
		and String(attempt.get("source_commit", "")) == source_commit
		and String(attempt.get("authorization_token", "")) == token
		and _r8_valid_lower_hex(String(attempt.get("attempt_id", "")), 32)
		and bool(attempt.get("physical_execution_authorized", false))
		and bool(attempt.get("single_use_supervisor_authorization", false))
		and bool(attempt.get("matrix_authorization_immutable_before_first_world", false))
		and matrix_ids == expected_matrix_ids
		and bool(attempt.get("source_worktree_clean", false))
		and bool(attempt.get("source_matches_live_github_main", false))
		and bool(attempt.get("operation_lock_held", false))
		and bool(attempt.get("campaign_attestation_adoption_valid", false))
		and bool(attempt.get("content_addressed_inputs_retained", false))
		and bool(attempt.get("one_shot_attempt_unconsumed", false))
		and String(attempt.get("attempt_root", "")).simplify_path() == normalized_attempt_root
		and OS.get_environment(R23D20_STAGE_ENV) == String(cell["stage_id"])
		and OS.get_environment(R23D20_CELL_ENV) == String(cell["cell_id"])
		and OS.get_environment(R23D20_ENGINE_ENV) == R23D20_ENGINE_ID
	)
	if not exact:
		return _r23d20_failure("QSDK_R23D20_GJT_PHYSICAL_AUTHORIZATION_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"attempt_root": normalized_attempt_root,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d20_source_bindings_exact(freeze: Dictionary) -> bool:
	var contract := _r8_read_json(R23D20_IMPLEMENTATION_PATH)
	var dependency_contract: Dictionary = contract.get("dependency_closure", {})
	var paths_by_worker: Dictionary = dependency_contract.get(
		"required_dependency_paths_by_worker", {}
	)
	var declared_value: Variant = paths_by_worker.get(R23D20_ENGINE_ID, null)
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


static func _r23d20_worker_failure(
	cell: Dictionary,
	source_commit: String,
	failure_stage: String,
	failure_code: String,
	world_attempt_count: int,
	world_build_count: int,
	trace_artifact: Variant = null,
) -> Dictionary:
	return {
		"schema_version": R23D20_FAILURE_SCHEMA,
		"campaign_id": R23D20_CAMPAIGN_ID,
		"gate_id": R23D20_GATE_ID,
		"stage_id": String(cell.get("stage_id", "")),
		"cell_id": String(cell.get("cell_id", "")),
		"engine_id": R23D20_ENGINE_ID,
		"arm_id": String(cell.get("arm_id", "")),
		"turn_heading_offset_rad": float(cell.get("turn_heading_offset_rad", 0.0)),
		"source_commit": source_commit,
		"failure_stage": failure_stage,
		"failure_code": failure_code,
		"world_attempt_count": world_attempt_count,
		"world_build_count": world_build_count,
		"trace_artifact": trace_artifact,
		"claims": R23D20_FALSE_CLAIMS.duplicate(true),
	}


static func _r23d20_failure(code: String, detail: Dictionary = {}) -> Dictionary:
	var failure := {
		"ok": false,
		"failure_code": code,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
	for key_value in detail:
		failure[key_value] = detail[key_value]
	failure["ok"] = false
	failure["failure_code"] = code
	failure["world_attempt_count"] = int(detail.get("world_attempt_count", 0))
	failure["world_build_count"] = int(detail.get("world_build_count", 0))
	failure["physical_acceptance_authority"] = false
	return failure
