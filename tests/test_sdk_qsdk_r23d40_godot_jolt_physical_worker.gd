extends "res://tests/test_sdk_qsdk_r23d3_godot_jolt_worker.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Godot/Jolt worker for the fresh QSDK-R23D40 three-engine validation.
##
## The 2,992-step horizon, R23D29 controller, measurement, and native physics
## path are inherited. The selected one-cycle startup transform is applied to
## the portable velocity commands before each native motor write.

const R23D3WorkerScript := preload("res://tests/test_sdk_qsdk_r23d3_godot_jolt_worker.gd")
const R23D40WaveGaitScript := preload(
	"res://scripts/lab/gait/physical_wave_gait_quadruped.gd"
)
const R23D40AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const R23D40StartupRampScript := preload(
	"res://scripts/lab/gait/sdk_startup_velocity_ramp.gd"
)
const R23D40TraceCompositionBoundaryScript := preload(
	"res://tests/test_sdk_qsdk_r23d40_godot_trace_composition_boundary.gd"
)

const R23D40_PREREGISTRATION_PATH := (
	"res://sdk/turning/r23d40_three_engine_startup_ramp_turning_preregistration_v1.json"
)
const R23D40_IMPLEMENTATION_PATH := (
	"res://sdk/turning/r23d40_three_engine_startup_ramp_turning_implementation_v1.json"
)
const R23D40_EVALUATOR_PATH := (
	"res://sdk/turning/r23d40_three_engine_startup_ramp_turning_evaluator.py"
)
const R23D40_CLOSURE_PATH := (
	"res://sdk/turning/r23d40_three_engine_startup_ramp_turning_closure_v1.json"
)
const R23D40_PUBLISHER_PATH := "res://sdk/publish_qsdk_r23d40_trace.ps1"
const R23D40_WORKER_PATH := (
	"res://tests/test_sdk_qsdk_r23d40_godot_jolt_physical_worker.gd"
)
const R23D40_TRACE_COMPOSITION_BOUNDARY_PATH := (
	"res://tests/test_sdk_qsdk_r23d40_godot_trace_composition_boundary.gd"
)
const R23D40_BASE_WORKER_PATH := "res://tests/test_sdk_qsdk_r23d3_godot_jolt_worker.gd"
const R23D40_RUNNER_PATH := "res://scripts/lab/gait/physical_wave_gait_quadruped.gd"
const R23D40_ADAPTER_PATH := "res://scripts/lab/gait/sdk_godot_jolt_adapter.gd"
const R23D40_GDEXTENSION_PATH := (
	"res://sdk/adapters/godot/sporespore_locomotion.gdextension"
)
const R23D40_DESIGN_PATH := "res://sdk/turning/r23d40_three_engine_startup_ramp_turning.py"

const R23D40_CAMPAIGN_ID := "QSDK-R23D40-THREE-ENGINE-STARTUP-RAMP-TURNING-VALIDATION"
const R23D40_GATE_ID := "QSDK-R23D40"
const R23D40_STAGE_ID := "three_engine_startup_ramp_turning_validation"
const R23D40_ENGINE_ID := "godot_jolt"
const R23D40_POLICY_ID := (
	"sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_"
	+ "stability_guarded_steering_v1"
)
const R23D40_MEMORY_SCHEMA := (
	"sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
)
const R23D40_CANDIDATE_ID := (
	"r23d29_startup_ramp_turning_validation"
)
const R23D40_SEED := 21508
const R23D40_ONSET_ID := "onset_600"
const R23D40_TURN_START_STEP := 600
const R23D40_PREFLIGHT_SCHEMA := (
	"sporespore_qsdk_r23d40_godot_jolt_worker_preflight_v1"
)
const R23D40_REPORT_SCHEMA := "sporespore_qsdk_r23d40_engine_cell_report_v1"
const R23D40_FAILURE_SCHEMA := "sporespore_qsdk_r23d40_worker_failure_v1"
const R23D40_TRACE_RETENTION_SCHEMA := "sporespore_qsdk_r23d40_trace_retention_v1"
const R23D40_FREEZE_SCHEMA := "sporespore_qsdk_r23d40_physical_freeze_v1"
const R23D40_ATTEMPT_SCHEMA := "sporespore_qsdk_r23d40_attempt_v1"

const R23D40_FREEZE_PATH_ENV := "SPORESPORE_QSDK_R23D40_FREEZE"
const R23D40_ATTEMPT_PATH_ENV := "SPORESPORE_QSDK_R23D40_ATTEMPT"
const R23D40_TOKEN_ENV := "SPORESPORE_QSDK_R23D40_TOKEN"
const R23D40_STAGE_ENV := "SPORESPORE_QSDK_R23D40_STAGE"
const R23D40_CELL_ENV := "SPORESPORE_QSDK_R23D40_CELL"
const R23D40_ENGINE_ENV := "SPORESPORE_QSDK_R23D40_ENGINE"
const R23D40_ATTEMPT_ROOT_ENV := "SPORESPORE_QSDK_R23D40_ATTEMPT_ROOT"
const R23D40_PYTHON_ENV := "SPORESPORE_QSDK_R23D40_PYTHON"
const R23D40_POWERSHELL_ENV := "SPORESPORE_QSDK_R23D40_POWERSHELL"

const R23D40_ARM_OFFSETS := {
	"reference_zero": 0.0,
	"positive_heading": 0.2,
	"negative_heading": -0.2,
}
const R23D40_GAIT_STEPS := {
	"rear_left": 0,
	"front_left": 0,
	"rear_right": 0,
	"front_right": 0,
}
const R23D40_SOLVER_OPTIONS := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": 120,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
const R23D40_FALSE_CLAIMS := {
	"rapier_parry_r23d29_turning": false,
	"godot_jolt_r23d29_turning": false,
	"mujoco_r23d29_turning": false,
	"finite_three_engine_turning": false,
	"portable_basic_turning": false,
	"cross_engine_equivalence": false,
	"population_robustness": false,
	"prone_to_standing": false,
	"release_authorized": false,
	"physical_acceptance_authority": false,
}
const R23D40_STARTUP_RAMP_OPTIONS := {
	"enabled": true,
	"policy_id": "canonical_velocity_smoothstep_one_gait_cycle_v1",
}


func _run() -> void:
	var parsed := R23D3WorkerScript._parse_arguments(OS.get_cmdline_user_args())
	if not bool(parsed.get("ok", false)):
		print("QSDK_R23D40_GODOT_JOLT_FAILURE ", JSON.stringify(parsed))
		quit(1)
		return
	var cell := _r23d40_cell(
		String(parsed["stage_id"]),
		String(parsed["onset_id"]),
		String(parsed["arm_id"]),
	)
	if not bool(cell.get("ok", false)):
		print("QSDK_R23D40_GODOT_JOLT_FAILURE ", JSON.stringify(cell))
		quit(1)
		return
	if bool(parsed["preflight_only"]):
		var preflight: Dictionary = await _r23d40_run_preflight(cell)
		if not bool(preflight.get("ok", false)):
			print("QSDK_R23D40_GODOT_JOLT_FAILURE ", JSON.stringify(preflight))
			quit(1)
			return
		print("QSDK_R23D40_GODOT_JOLT_PREFLIGHT ", JSON.stringify(preflight))
		quit(0)
		return
	var terminal: Dictionary = await _r23d40_run_physical(
		cell,
		String(parsed["source_commit"]),
	)
	if String(terminal.get("schema_version", "")) == R23D40_REPORT_SCHEMA:
		print("QSDK_R23D40_GODOT_JOLT_TERMINAL ", JSON.stringify(terminal))
		quit(0)
		return
	print("QSDK_R23D40_GODOT_JOLT_TERMINAL ", JSON.stringify(terminal))
	quit(1)


func _r23d40_run_preflight(cell: Dictionary) -> Dictionary:
	var solver_receipt := R23D3WorkerScript._apply_solver_configuration()
	if not bool(solver_receipt.get("ok", false)):
		return solver_receipt
	var prepared := _r23d40_prepare(cell)
	if not bool(prepared.get("ok", false)):
		return prepared
	var entrypoint: Dictionary = await _run_wave(prepared, true)
	var adapter_boundary := _r23d40_adapter_boundary(prepared, cell)
	var trace_canary := _r23d40_trace_row_canary(
		prepared,
		cell,
		adapter_boundary,
	)
	var trace_composition_horizon := R23D40TraceCompositionBoundaryScript._diagnose(
		String(cell["arm_id"])
	)
	var trace_diagnostic_canary := _r23d40_trace_diagnostic(
		cell,
		{
			"schema_version": "sporespore_sdk_physical_trace_v1",
			"row_count": 2,
			"failure_codes": ["SDK_PHYSICAL_TRACE_CANARY"],
			"rows": [{"semantic_step": 0}, {"semantic_step": 1}],
		},
	)
	var trace_diagnostic_summary := _r23d40_trace_diagnostic_summary(
		trace_diagnostic_canary
	)
	var predicate_controls := R23D3WorkerScript._predicate_negative_controls()
	var trace_options: Dictionary = entrypoint.get("sdk_physical_trace_options", {})
	var ramp_preflight: Dictionary = entrypoint.get(
		"sdk_startup_velocity_ramp_preflight",
		{},
	)
	var exact := (
		bool(entrypoint.get("ok", false))
		and int(entrypoint.get("actual_world_build_count", -1)) == 0
		and int(entrypoint.get("scene_tree_insertion_count", -1)) == 0
		and not bool(entrypoint.get("physics_state_modified", true))
		and bool(entrypoint.get("candidate_authority_horizon_enabled", false))
		and int(entrypoint.get("candidate_authority_observation_count", -1))
		== CONTROLLER_STEPS
		and bool(entrypoint.get("sdk_physical_trace_enabled", false))
		and int(trace_options.get("exact_controller_step_count", -1)) == CONTROLLER_STEPS
		and String(trace_options.get("cell_id", "")) == String(cell["cell_id"])
		and bool(entrypoint.get("sdk_startup_velocity_ramp_enabled", false))
		and bool(ramp_preflight.get("ok", false))
		and String(ramp_preflight.get("policy_id", ""))
		== String(R23D40_STARTUP_RAMP_OPTIONS["policy_id"])
		and bool(adapter_boundary.get("ok", false))
		and bool(trace_canary.get("ok", false))
		and bool(trace_composition_horizon.get("ok", false))
		and int(trace_composition_horizon.get("controller_step_count", -1))
		== CONTROLLER_STEPS
		and int(trace_composition_horizon.get("native_controller_command_count", -1))
		== CONTROLLER_STEPS * ACTUATOR_COUNT
		and not bool(trace_diagnostic_canary.get("complete", true))
		and int(trace_diagnostic_canary.get("declared_row_count", -1))
		== CONTROLLER_STEPS
		and int(trace_diagnostic_canary.get("reported_row_count", -1)) == 2
		and int(trace_diagnostic_canary.get("actual_row_count", -1)) == 2
		and int(trace_diagnostic_canary.get("first_missing_semantic_step", -1)) == 2
		and (trace_diagnostic_canary.get("failure_codes", []) as Array)
		== ["SDK_PHYSICAL_TRACE_CANARY"]
		and not trace_diagnostic_summary.has("rows")
		and bool(predicate_controls.get("ok", false))
	)
	if not exact:
		return _r23d40_failure(
			"QSDK_R23D40_GJT_PREFLIGHT_INVALID",
			{
				"entrypoint": entrypoint,
				"adapter_boundary": adapter_boundary,
				"trace_canary": trace_canary,
				"trace_composition_horizon": trace_composition_horizon,
				"trace_diagnostic_canary": trace_diagnostic_canary,
				"trace_diagnostic_summary": trace_diagnostic_summary,
				"predicate_controls": predicate_controls,
			},
		)
	return {
		"schema_version": R23D40_PREFLIGHT_SCHEMA,
		"ok": true,
		"failure_code": "",
		"campaign_id": R23D40_CAMPAIGN_ID,
		"gate_id": R23D40_GATE_ID,
		"engine_id": R23D40_ENGINE_ID,
		"stage_id": String(cell["stage_id"]),
		"cell_id": String(cell["cell_id"]),
		"arm_id": String(cell["arm_id"]),
		"controller_policy_id": R23D40_POLICY_ID,
		"controller_memory_schema": R23D40_MEMORY_SCHEMA,
		"fixed_controller_horizon_step_count": CONTROLLER_STEPS,
		"terminal_restoration_or_taper_invoked": false,
		"preregistration_raw_sha256": R23D3WorkerScript._raw_file_sha256(
			R23D40_PREREGISTRATION_PATH
		),
		"entrypoint_preflight": entrypoint,
		"solver_receipt": solver_receipt,
		"adapter_boundary": adapter_boundary,
		"trace_row_canary": trace_canary,
		"trace_composition_horizon": trace_composition_horizon,
		"trace_diagnostic_canary": trace_diagnostic_summary,
		"godot_predicate_negative_control_count": int(
			predicate_controls["rejected_mutation_count"]
		),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
	}


func _r23d40_run_physical(cell: Dictionary, source_commit: String) -> Dictionary:
	if not R23D3WorkerScript._valid_lower_hex(source_commit, 40):
		return _r23d40_worker_failure(
			cell,
			source_commit,
			"before_world",
			"QSDK_R23D40_GJT_SOURCE_COMMIT_INVALID",
			0,
			0,
		)
	var authorization := _r23d40_physical_authorization(cell, source_commit)
	if not bool(authorization.get("ok", false)):
		return _r23d40_worker_failure(
			cell,
			source_commit,
			"before_world",
			String(authorization.get("failure_code", "QSDK_R23D40_GJT_AUTHORIZATION_INVALID")),
			0,
			0,
		)
	var preflight: Dictionary = await _r23d40_run_preflight(cell)
	if not bool(preflight.get("ok", false)):
		return _r23d40_worker_failure(
			cell,
			source_commit,
			"before_world",
			String(preflight.get("failure_code", "QSDK_R23D40_GJT_PREFLIGHT_INVALID")),
			0,
			0,
		)
	var prepared := _r23d40_prepare(cell)
	if not bool(prepared.get("ok", false)):
		return _r23d40_worker_failure(
			cell,
			source_commit,
			"before_world",
			String(prepared.get("failure_code", "QSDK_R23D40_GJT_PREPARE_INVALID")),
			0,
			0,
		)
	var summary: Dictionary = await _run_wave(prepared, false)
	var world_build_count := int(summary.get("world_build_count", 0))
	var raw_sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var predicates := R23D3WorkerScript._project_godot_predicates(raw_sdk_summary)
	if world_build_count != 1:
		return _r23d40_worker_failure(
			cell,
			source_commit,
			"world_construction_failed",
			"QSDK_R23D40_GJT_WORLD_BUILD_COUNT_INVALID",
			1,
			world_build_count,
			null,
			raw_sdk_summary,
			predicates,
		)
	var trace_container: Dictionary = summary.get("sdk_physical_trace", {})
	var rows_value: Variant = trace_container.get("rows", null)
	var trace_diagnostic := _r23d40_trace_diagnostic(cell, trace_container)
	if not bool(trace_diagnostic.get("complete", false)):
		var diagnostic_retention := _r23d40_retain_trace_diagnostic(
			cell,
			trace_diagnostic,
			String(authorization["attempt_root"]),
		)
		if not bool(diagnostic_retention.get("ok", false)):
			return _r23d40_worker_failure(
				cell,
				source_commit,
				"controller_horizon_complete",
				String(
					diagnostic_retention.get(
						"failure_code",
						"QSDK_R23D40_GJT_TRACE_DIAGNOSTIC_RETENTION_FAILED",
					)
				),
				1,
				1,
				null,
				raw_sdk_summary,
				predicates,
				_r23d40_trace_diagnostic_summary(trace_diagnostic),
			)
		return _r23d40_worker_failure(
			cell,
			source_commit,
			"controller_horizon_complete",
			"QSDK_R23D40_GJT_TRACE_INCOMPLETE",
			1,
			1,
			null,
			raw_sdk_summary,
			predicates,
			_r23d40_trace_diagnostic_summary(trace_diagnostic),
			diagnostic_retention["trace_diagnostic_artifact"],
		)
	var retention := _r23d40_retain_trace(
		cell,
		rows_value,
		String(authorization["attempt_root"]),
	)
	if not bool(retention.get("ok", false)):
		trace_diagnostic["trace_retention_failure_code"] = String(
			retention.get("failure_code", "QSDK_R23D40_GJT_TRACE_RETENTION_FAILED")
		)
		var diagnostic_retention := _r23d40_retain_trace_diagnostic(
			cell,
			trace_diagnostic,
			String(authorization["attempt_root"]),
		)
		return _r23d40_worker_failure(
			cell,
			source_commit,
			"controller_horizon_complete",
			String(retention.get("failure_code", "QSDK_R23D40_GJT_TRACE_RETENTION_FAILED")),
			1,
			1,
			null,
			raw_sdk_summary,
			predicates,
			_r23d40_trace_diagnostic_summary(trace_diagnostic),
			diagnostic_retention.get("trace_diagnostic_artifact", null),
		)
	var trace_artifact: Dictionary = retention["trace_artifact"]
	var horizon: Dictionary = summary.get("sdk_fixed_controller_horizon_receipt", {})
	var direct_body_write_count := (
		int(summary.get("direct_torso_force_command_count", -1))
		+ int(summary.get("direct_torso_impulse_command_count", -1))
		+ int(summary.get("direct_torso_velocity_command_count", -1))
		+ int(summary.get("direct_torso_transform_command_count", -1))
	)
	var execution_integrity := (
		bool(predicates.get("ok", false))
		and bool(horizon.get("exact", false))
		and int(horizon.get("expected_controller_step_count", -1)) == CONTROLLER_STEPS
		and int(horizon.get("observed_controller_step_count", -1)) == CONTROLLER_STEPS
		and bool(horizon.get("configuration_proved_before_fixture_insertion", false))
		and direct_body_write_count == 0
		and int(summary.get("world_reset_count", -1)) == 0
		and int(raw_sdk_summary.get("native_actuation_application_count", -1))
		== CONTROLLER_STEPS * ACTUATOR_COUNT
		and bool(summary.get("sdk_startup_velocity_ramp", {}).get("enabled", false))
		and int(
			(summary.get("sdk_startup_velocity_ramp", {}) as Dictionary).get(
				"composition_step_count",
				-1,
			)
		) == CONTROLLER_STEPS
		and int(
			(summary.get("sdk_startup_velocity_ramp", {}) as Dictionary).get(
				"active_step_count",
				-1,
			)
		) == 359
		and int(
			(summary.get("sdk_startup_velocity_ramp", {}) as Dictionary).get(
				"exact_zero_scale_step_count",
				-1,
			)
		) == 1
		and int(
			(summary.get("sdk_startup_velocity_ramp", {}) as Dictionary).get(
				"exact_unity_scale_step_count",
				-1,
			)
		) == CONTROLLER_STEPS - 359
	)
	if not execution_integrity:
		return _r23d40_worker_failure(
			cell,
			source_commit,
			"controller_horizon_complete",
			"QSDK_R23D40_GJT_EXECUTION_INTEGRITY_INVALID",
			1,
			1,
			trace_artifact,
			raw_sdk_summary,
			predicates,
		)
	var heading: Dictionary = summary.get("sdk_heading_schedule_receipt", {})
	var startup: Dictionary = summary.get("sdk_startup_velocity_ramp", {})
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
		"contact_cycle_count_by_limb": (
			(summary.get("contact_cycle_count_by_limb", {}) as Dictionary).duplicate(true)
		),
		"torso_ground_contact_step_count": int(summary.get("torso_contact_ticks", -1)),
		"controller_error_count": (raw_sdk_summary.get("failure_codes", []) as Array).size(),
		"safe_no_actuation_count": int(raw_sdk_summary.get("safe_no_actuation_count", -1)),
		"nonfinite_observation_count": 0,
		"actuator_application_mismatch_count": int(raw_sdk_summary.get("mismatch_count", -1)),
		"controller_semantic_step_count": int(raw_sdk_summary.get("step_count", -1)),
		"validated_portable_command_count": int(
			raw_sdk_summary.get("validated_balanced_wave_command_count", -1)
		),
		"native_actuation_application_count": int(
			raw_sdk_summary.get("native_actuation_application_count", -1)
		),
		"startup_ramp_id": String(startup.get("policy_id", "")),
		"startup_ramp_step_count": int(startup.get("ramp_step_count", -1)),
		"startup_ramp_composition_step_count": int(
			startup.get("composition_step_count", -1)
		),
		"startup_ramp_active_step_count": int(startup.get("active_step_count", -1)),
		"startup_ramp_exact_zero_scale_step_count": int(
			startup.get("exact_zero_scale_step_count", -1)
		),
		"startup_ramp_exact_unity_scale_step_count": int(
			startup.get("exact_unity_scale_step_count", -1)
		),
		"maximum_absolute_startup_ramp_residual_rad_s": float(
			startup.get("maximum_absolute_residual_rad_s", NAN)
		),
		"startup_ramp_composition_integrity_passed": (
			int(startup.get("composition_step_count", -1)) == CONTROLLER_STEPS
		),
	}
	return {
		"schema_version": R23D40_REPORT_SCHEMA,
		"campaign_id": R23D40_CAMPAIGN_ID,
		"gate_id": R23D40_GATE_ID,
		"stage_id": String(cell["stage_id"]),
		"cell_id": String(cell["cell_id"]),
		"engine_id": R23D40_ENGINE_ID,
		"onset_id": String(cell["onset_id"]),
		"turn_start_semantic_step": int(cell["turn_start_semantic_step"]),
		"arm_id": String(cell["arm_id"]),
		"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
		"source_commit": source_commit,
		"trace_artifact": trace_artifact.duplicate(true),
		"trace_summary": (retention["trace_summary"] as Dictionary).duplicate(true),
		"execution":
		{
			"integrity_passed": true,
			"worker_failure_code": "",
			"controller_semantic_step_count": int(measurements["controller_semantic_step_count"]),
			"validated_portable_command_count": int(measurements["validated_portable_command_count"]),
			"native_actuation_application_count": int(measurements["native_actuation_application_count"]),
			"portable_impulse_violation_count": 0,
			"world_attempt_count": 1,
			"world_build_count": 1,
			"trace_retained_before_terminal_entry": true,
			"fixed_horizon_configuration_proved_before_fixture_insertion": true,
		},
		"measurements": measurements,
		"godot_execution_predicates": predicates,
		"claims": R23D40_FALSE_CLAIMS.duplicate(true),
	}


static func _r23d40_prepare(cell: Dictionary) -> Dictionary:
	var declaration := R23D3WorkerScript._read_json(R23D40_PREREGISTRATION_PATH)
	var matrix: Dictionary = declaration.get("frozen_matrix", {})
	var candidate: Dictionary = declaration.get("candidate", {})
	if (
		String(declaration.get("campaign_id", "")) != R23D40_CAMPAIGN_ID
		or String(declaration.get("gate_id", "")) != R23D40_GATE_ID
		or String(declaration.get("status", "")) != "prospective_zero_world_only"
		or String(matrix.get("stage_id", "")) != R23D40_STAGE_ID
		or int(matrix.get("seed", -1)) != R23D40_SEED
		or int(matrix.get("controller_step_count", -1)) != CONTROLLER_STEPS
		or bool(matrix.get("terminal_restoration_or_taper_invoked", true))
		or String(candidate.get("controller_policy_id", "")) != R23D40_POLICY_ID
		or String(candidate.get("controller_memory_schema", "")) != R23D40_MEMORY_SCHEMA
	):
		return _r23d40_failure("QSDK_R23D40_GJT_DECLARATION_INVALID")
	var prepared := R23D3WorkerScript._prepare(cell)
	if not bool(prepared.get("ok", false)):
		return prepared
	var perturbation_result := R23D40WaveGaitScript.compile_seeded_initial_perturbation(
		R23D40_SEED
	)
	if not bool(perturbation_result.get("ok", false)):
		return perturbation_result
	var perturbation: Dictionary = perturbation_result["initial_perturbation"]
	if not _r23d40_perturbation_exact(perturbation, matrix.get("initial_perturbation", {})):
		return _r23d40_failure(
			"QSDK_R23D40_GJT_INITIAL_PERTURBATION_MISMATCH",
			{
				"compiled": R23D3WorkerScript._json_initial_perturbation(perturbation),
				"declared": matrix.get("initial_perturbation", {}),
			},
		)
	prepared["initial_perturbation"] = perturbation
	(prepared["authority_options"] as Dictionary)["controller_policy_id"] = R23D40_POLICY_ID
	return prepared


func _run_wave(prepared: Dictionary, preflight_before_world: bool) -> Dictionary:
	return await (
		R23D40WaveGaitScript
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
			R23D40_SOLVER_OPTIONS,
			{},
			{},
			prepared["authority_options"],
			{},
			{},
			preflight_before_world,
			prepared["fixed_horizon_options"],
			prepared["schedule"],
			prepared["trace_options"],
			{},
			R23D40_STARTUP_RAMP_OPTIONS,
		)
	)


static func _r23d40_adapter_boundary(prepared: Dictionary, cell: Dictionary) -> Dictionary:
	var adapter: RefCounted = R23D40AdapterScript.new()
	var phase_offset := int(
		(prepared["initial_perturbation"] as Dictionary)["gait_phase_offset_ticks"]
	)
	var start: Dictionary = (
		adapter
		. start(
			prepared["descriptor"],
			R23D40_GAIT_STEPS,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			PI * 0.5,
			120,
			R23D40_SOLVER_OPTIONS,
			2.5e-7,
			"clocked",
			true,
			phase_offset,
			360,
			"post_settle_full",
			"p5i3b_weight_support_shadow_v1",
			prepared["material_profile"],
			R23D40_POLICY_ID,
		)
	)
	if not bool(start.get("ok", false)):
		return _r23d40_failure(
			"QSDK_R23D40_GJT_ADAPTER_START_INVALID:%s"
			% String(start.get("failure_code", "UNKNOWN")),
		)
	var memory_value: Variant = adapter.get("_memory")
	var memory: Dictionary = memory_value if typeof(memory_value) == TYPE_DICTIONARY else {}
	var command := {
		"schema_version": "sporespore_heading_offset_command_v1",
		"schedule_id": String((prepared["schedule"] as Dictionary)["schedule_id"]),
		"segment_id": "commanded_turn",
		"command_role": "turn_heading",
		"heading_offset_rad": float(cell["turn_heading_offset_rad"]),
	}
	var runtime: Dictionary = adapter.preflight_perfect_declared_policy_runtime_boundary(command)
	var production: Dictionary = runtime.get("production_post_step_validation", {})
	var memory_receipt: Dictionary = production.get(
		"balanced_wave_memory_schema_receipt",
		{},
	)
	var native_output: Dictionary = production.get("native_output", {})
	var actuation: Dictionary = native_output.get("actuation", {})
	var controller_receipt: Dictionary = actuation.get("receipt", {})
	var morphology: Dictionary = adapter.preflight_compiled_morphology_boundary()
	var manifest: Dictionary = start.get("adapter_manifest", {})
	var profile: Dictionary = manifest.get("controller_profile", {})
	var exact := (
		bool(runtime.get("ok", false))
		and bool(production.get("ok", false))
		and (production.get("failure_codes", []) as Array).is_empty()
		and bool(memory_receipt.get("ok", false))
		and String(memory_receipt.get("expected_memory_schema_version", ""))
		== R23D40_MEMORY_SCHEMA
		and String(memory_receipt.get("observed_memory_schema_version", ""))
		== R23D40_MEMORY_SCHEMA
		and String(controller_receipt.get("schema_version", ""))
		== "sporespore_controller_step_receipt_v8"
		and bool(morphology.get("ok", false))
		and int(runtime.get("native_controller_command_count", -1)) == ACTUATOR_COUNT
		and int(runtime.get("actual_world_build_count", -1)) == 0
		and int(runtime.get("scene_tree_insertion_count", -1)) == 0
		and not bool(runtime.get("physics_state_modified", true))
		and String(start.get("controller_policy_id", "")) == R23D40_POLICY_ID
		and String(runtime.get("controller_policy_id", "")) == R23D40_POLICY_ID
		and String(manifest.get("physics_engine", "")) == "Jolt Physics"
		and String(profile.get("policy_id", "")) == R23D40_POLICY_ID
		and float(profile.get("minimum_steering_fraction", NAN)) == 0.20
		and float(profile.get("maximum_steering_fraction", NAN)) == 0.28
		and int(profile.get("steering_guard_floor_hold_steps", -1)) == 144
		and String(memory.get("schema_version", "")) == R23D40_MEMORY_SCHEMA
		and int(memory.get("steering_guard_floor_hold_steps_remaining", -1)) == 0
	)
	adapter = null
	if not exact:
		return _r23d40_failure(
			"QSDK_R23D40_GJT_ADAPTER_BOUNDARY_INVALID",
			{
				"start": start,
				"runtime": runtime,
				"morphology": morphology,
				"initial_memory": memory,
			},
		)
	return {
		"ok": true,
		"failure_code": "",
		"controller_policy_id": R23D40_POLICY_ID,
		"controller_memory_schema": String(memory["schema_version"]),
		"controller_profile": profile.duplicate(true),
		"controller_profile_sha256": String(start["controller_profile_sha256"]),
		"adapter_capability_sha256": String(start["adapter_capability_sha256"]),
		"native_controller_command_count": ACTUATOR_COUNT,
		"production_post_step_validation": {
			"ok": bool(production.get("ok", false)),
			"controller_receipt_schema": String(
				controller_receipt.get("schema_version", "")
			),
			"expected_memory_schema": String(
				memory_receipt.get("expected_memory_schema_version", "")
			),
			"observed_memory_schema": String(
				memory_receipt.get("observed_memory_schema_version", "")
			),
		},
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d40_trace_row_canary(
	prepared: Dictionary,
	cell: Dictionary,
	adapter_boundary: Dictionary,
) -> Dictionary:
	if not bool(adapter_boundary.get("ok", false)):
		return _r23d40_failure("QSDK_R23D40_GJT_TRACE_CANARY_ADAPTER_INVALID")
	var profile: Dictionary = adapter_boundary["controller_profile"]
	var semantic_step := int(cell["turn_start_semantic_step"])
	var offset := float(cell["turn_heading_offset_rad"])
	var state := {
		"semantic_step": semantic_step,
		"base_pose_world":
		{
			"position_m": {"x": 0.10, "y": 0.40, "z": 0.05},
			"orientation_xyzw": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0},
		},
		"base_twist_world":
		{
			"linear_velocity_m_s": {"x": 0.2, "y": 0.0, "z": -0.02},
		},
		"task_frame":
		{
			"origin_world_m": {"x": 0.0, "y": 0.40, "z": 0.0},
			"forward_axis_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
			"lateral_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
			"reference_yaw_rad": 0.0,
		},
	}
	var command := {
		"desired_heading_rad": offset,
		"valid_from_step": semantic_step,
		"valid_through_step": semantic_step,
	}
	var oracle := R23D40WaveGaitScript._r23d3_independent_oracle(
		state,
		command,
		profile,
	)
	if not bool(oracle.get("ok", false)):
		return _r23d40_failure(
			"QSDK_R23D40_GJT_TRACE_CANARY_ORACLE_INVALID",
			oracle,
		)
	var receipt: Dictionary = (oracle["expected_receipt"] as Dictionary).duplicate(true)
	receipt["requested_steering_fraction"] = 0.0
	receipt["held_steering_fraction"] = 0.0
	var memory_rows: Array[Dictionary] = []
	for index in range(4):
		memory_rows.append(
			{
				"limb_id": ["rear_left", "front_left", "rear_right", "front_right"][index],
				"gait_step": semantic_step + 3,
				"release_hold_step_count": 0,
			}
		)
	var sample_result := {
		"ok": true,
		"request":
		{
			"memory":
			{
				"schema_version": R23D40_MEMORY_SCHEMA,
				"ordered_limb_memory": memory_rows,
				"steering_guard_floor_hold_steps_remaining": 0,
			},
			"state": state,
			"command": command,
		},
		"heading_command_receipt":
		{
			"semantic_step": semantic_step,
			"heading_offset_rad": offset,
		},
	}
	var commands: Array = []
	for index in range(ACTUATOR_COUNT):
		commands.append({"actuator_id": "canary_%d" % index})
	var step_result := {
		"ok": true,
		"semantic_step": semantic_step,
		"native_output":
		{
			"actuation":
			{
				"receipt": receipt,
				"ordered_commands": commands,
			},
		},
	}
	var application := {
		"ok": true,
		"semantic_step": semantic_step,
		"applied_command_count": ACTUATOR_COUNT,
	}
	var contacts := {
		"rear_left": true,
		"front_left": true,
		"rear_right": true,
		"front_right": true,
	}
	var valid := R23D40WaveGaitScript._compose_sdk_physical_trace_row(
		prepared["trace_options"],
		sample_result,
		step_result,
		application,
		semantic_step,
		contacts,
		0.1,
		false,
		profile,
	)
	var rejected_step := step_result.duplicate(true)
	(
		(
			(rejected_step["native_output"] as Dictionary)["actuation"] as Dictionary
		)["receipt"] as Dictionary
	)["desired_heading_error_rad"] = float(receipt["desired_heading_error_rad"]) + 1.0e-6
	var rejected := R23D40WaveGaitScript._compose_sdk_physical_trace_row(
		prepared["trace_options"],
		sample_result,
		rejected_step,
		application,
		semantic_step,
		contacts,
		0.1,
		false,
		profile,
	)
	var exact := (
		bool(valid.get("ok", false))
		and String((valid.get("row", {}) as Dictionary).get("cell_id", ""))
		== String(cell["cell_id"])
		and String((valid.get("row", {}) as Dictionary).get("segment_id", ""))
		== "commanded_turn"
		and not bool(rejected.get("ok", true))
		and String(rejected.get("failure_code", "")).begins_with(
			"SDK_PHYSICAL_TRACE_ORACLE_MISMATCH:"
		)
	)
	return {
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R23D40_GJT_TRACE_ROW_CANARY_INVALID",
		"valid_detail": valid,
		"rejected_detail": rejected,
		"accepted_row_count": 1 if bool(valid.get("ok", false)) else 0,
		"oracle_mutation_rejected": not bool(rejected.get("ok", true)),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d40_retain_trace(
	cell: Dictionary,
	rows: Array,
	attempt_root: String,
) -> Dictionary:
	var pending_root := attempt_root.path_join("pending-traces")
	if DirAccess.make_dir_recursive_absolute(pending_root) != OK:
		return _r23d40_failure("QSDK_R23D40_GJT_TRACE_ROOT_CREATE_FAILED")
	var rows_path := pending_root.path_join("%s.rows.json" % String(cell["cell_id"]))
	if FileAccess.file_exists(rows_path):
		return _r23d40_failure("QSDK_R23D40_GJT_TRACE_ROWS_ALREADY_EXIST")
	var file := FileAccess.open(rows_path, FileAccess.WRITE)
	if file == null:
		return _r23d40_failure("QSDK_R23D40_GJT_TRACE_ROWS_CREATE_FAILED")
	file.store_string(JSON.stringify(rows))
	file.store_string("\n")
	file.flush()
	file = null
	var python := OS.get_environment(R23D40_PYTHON_ENV)
	if python.is_empty():
		python = "python"
	var powershell := OS.get_environment(R23D40_POWERSHELL_ENV)
	if powershell.is_empty():
		powershell = "pwsh"
	var output: Array = []
	var exit_code := OS.execute(
		python,
		PackedStringArray(
			[
				ProjectSettings.globalize_path(R23D40_EVALUATOR_PATH),
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
	var marker := "QSDK_R23D40_TRACE_RETAINED "
	var matches: Array[String] = []
	for output_value in output:
		for line_value in String(output_value).split("\n"):
			var line := String(line_value).strip_edges()
			if line.begins_with(marker):
				matches.append(line.trim_prefix(marker))
	if exit_code != 0 or matches.size() != 1:
		return _r23d40_failure(
			"QSDK_R23D40_GJT_TRACE_RETENTION_FAILED:%d" % exit_code,
			{"output": output},
		)
	var parsed: Variant = JSON.parse_string(matches[0])
	if typeof(parsed) != TYPE_DICTIONARY:
		return _r23d40_failure("QSDK_R23D40_GJT_TRACE_RETENTION_RECEIPT_INVALID")
	var receipt: Dictionary = parsed
	if (
		String(receipt.get("schema_version", "")) != R23D40_TRACE_RETENTION_SCHEMA
		or String(receipt.get("stage_id", "")) != String(cell["stage_id"])
		or String(receipt.get("cell_id", "")) != String(cell["cell_id"])
		or not bool(receipt.get("retained_before_terminal_entry", false))
	):
		return _r23d40_failure(
			"QSDK_R23D40_GJT_TRACE_RETENTION_RECEIPT_INVALID",
			receipt,
		)
	receipt["ok"] = true
	receipt["failure_code"] = ""
	return receipt


static func _r23d40_trace_diagnostic(
	cell: Dictionary,
	trace_container: Dictionary,
) -> Dictionary:
	var rows_value: Variant = trace_container.get("rows", null)
	var failures_value: Variant = trace_container.get("failure_codes", null)
	var rows: Array = []
	if typeof(rows_value) == TYPE_ARRAY:
		rows = (rows_value as Array).duplicate(true)
	var failure_codes: Array = []
	if typeof(failures_value) == TYPE_ARRAY:
		failure_codes = (failures_value as Array).duplicate(true)
	else:
		failure_codes.append(
			"SDK_PHYSICAL_TRACE_FAILURE_CODES_TYPE_%s" % type_string(typeof(failures_value))
		)
	var contiguous_row_count := 0
	for row_index in range(rows.size()):
		var row_value: Variant = rows[row_index]
		if (
			typeof(row_value) != TYPE_DICTIONARY
			or int((row_value as Dictionary).get("semantic_step", -1)) != row_index
		):
			break
		contiguous_row_count += 1
	var reported_row_count := int(trace_container.get("row_count", -1))
	var complete := (
		typeof(rows_value) == TYPE_ARRAY
		and typeof(failures_value) == TYPE_ARRAY
		and failure_codes.is_empty()
		and reported_row_count == CONTROLLER_STEPS
		and rows.size() == CONTROLLER_STEPS
		and contiguous_row_count == CONTROLLER_STEPS
	)
	return {
		"schema_version": "sporespore_qsdk_r23d40_trace_diagnostic_v1",
		"campaign_id": R23D40_CAMPAIGN_ID,
		"gate_id": R23D40_GATE_ID,
		"stage_id": String(cell["stage_id"]),
		"cell_id": String(cell["cell_id"]),
		"arm_id": String(cell["arm_id"]),
		"trace_container_schema": String(trace_container.get("schema_version", "")),
		"rows_variant_type": type_string(typeof(rows_value)),
		"failure_codes_variant_type": type_string(typeof(failures_value)),
		"declared_row_count": CONTROLLER_STEPS,
		"reported_row_count": reported_row_count,
		"actual_row_count": rows.size(),
		"contiguous_row_count": contiguous_row_count,
		"first_valid_semantic_step": 0 if contiguous_row_count > 0 else -1,
		"last_valid_semantic_step": contiguous_row_count - 1,
		"first_missing_semantic_step": contiguous_row_count,
		"failure_codes": failure_codes,
		"complete": complete,
		"rows": rows,
		"partial_rows_retained": true,
		"retained_before_terminal_entry": true,
		"physical_acceptance_authority": false,
	}


static func _r23d40_retain_trace_diagnostic(
	cell: Dictionary,
	diagnostic: Dictionary,
	attempt_root: String,
) -> Dictionary:
	var pending_root := attempt_root.path_join("pending-traces")
	if DirAccess.make_dir_recursive_absolute(pending_root) != OK:
		return _r23d40_failure("QSDK_R23D40_GJT_TRACE_DIAGNOSTIC_ROOT_CREATE_FAILED")
	var diagnostic_path := pending_root.path_join(
		"%s.trace-diagnostic.json" % String(cell["cell_id"])
	)
	if FileAccess.file_exists(diagnostic_path):
		return _r23d40_failure("QSDK_R23D40_GJT_TRACE_DIAGNOSTIC_ALREADY_EXISTS")
	var file := FileAccess.open(diagnostic_path, FileAccess.WRITE)
	if file == null:
		return _r23d40_failure("QSDK_R23D40_GJT_TRACE_DIAGNOSTIC_CREATE_FAILED")
	file.store_string(JSON.stringify(diagnostic))
	file.store_string("\n")
	file.flush()
	file = null
	var raw_sha256 := R23D3WorkerScript._raw_file_sha256(diagnostic_path)
	var byte_length := FileAccess.get_file_as_bytes(diagnostic_path).size()
	var powershell := OS.get_environment(R23D40_POWERSHELL_ENV)
	if powershell.is_empty():
		powershell = "pwsh"
	var output: Array = []
	var exit_code := OS.execute(
		powershell,
		PackedStringArray(
			[
				"-NoLogo",
				"-NoProfile",
				"-File",
				ProjectSettings.globalize_path(R23D40_PUBLISHER_PATH),
				"-RepoRoot",
				ProjectSettings.globalize_path("res://"),
				"-ArtifactPath",
				diagnostic_path,
				"-ExpectedSha256",
				raw_sha256,
				"-ExpectedByteLength",
				str(byte_length),
				"-MediaType",
				"application/json",
			]
		),
		output,
		true,
	)
	var marker := "QSDK_R23D40_EVIDENCE_CAS "
	var matches: Array[String] = []
	for output_value in output:
		for line_value in String(output_value).split("\n"):
			var line := String(line_value).strip_edges()
			if line.begins_with(marker):
				matches.append(line.trim_prefix(marker))
	if exit_code != 0 or matches.size() != 1:
		return _r23d40_failure(
			"QSDK_R23D40_GJT_TRACE_DIAGNOSTIC_RETENTION_FAILED:%d" % exit_code,
			{"output": output},
		)
	var parsed: Variant = JSON.parse_string(matches[0])
	if typeof(parsed) != TYPE_DICTIONARY:
		return _r23d40_failure(
			"QSDK_R23D40_GJT_TRACE_DIAGNOSTIC_RETENTION_RECEIPT_INVALID"
		)
	var artifact: Dictionary = parsed
	if (
		String(artifact.get("schema_version", ""))
		!= "sporespore_content_addressed_artifact_receipt_v1"
		or String(artifact.get("sha256", "")) != raw_sha256
		or int(artifact.get("byte_length", -1)) != byte_length
		or bool(artifact.get("physical_acceptance_authority", true))
	):
		return _r23d40_failure(
			"QSDK_R23D40_GJT_TRACE_DIAGNOSTIC_RETENTION_RECEIPT_INVALID",
			artifact,
		)
	return {
		"ok": true,
		"failure_code": "",
		"trace_diagnostic_artifact": artifact.duplicate(true),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d40_trace_diagnostic_summary(diagnostic: Dictionary) -> Dictionary:
	var summary := diagnostic.duplicate(true)
	summary.erase("rows")
	return summary


static func _r23d40_physical_authorization(
	cell: Dictionary,
	source_commit: String,
) -> Dictionary:
	if FileAccess.file_exists(R23D40_CLOSURE_PATH):
		return _r23d40_failure("QSDK_R23D40_GJT_CLOSED")
	var freeze_path := OS.get_environment(R23D40_FREEZE_PATH_ENV)
	var attempt_path := OS.get_environment(R23D40_ATTEMPT_PATH_ENV)
	var token := OS.get_environment(R23D40_TOKEN_ENV)
	var attempt_root := OS.get_environment(R23D40_ATTEMPT_ROOT_ENV)
	if (
		freeze_path.is_empty()
		or attempt_path.is_empty()
		or attempt_root.is_empty()
		or not FileAccess.file_exists(freeze_path)
		or not FileAccess.file_exists(attempt_path)
		or not DirAccess.dir_exists_absolute(attempt_root)
		or not R23D3WorkerScript._valid_lower_hex(token, 32)
	):
		return _r23d40_failure("QSDK_R23D40_GJT_PHYSICAL_AUTHORIZATION_REQUIRED")
	var freeze := R23D3WorkerScript._read_json(freeze_path)
	var attempt := R23D3WorkerScript._read_json(attempt_path)
	var production_root := (
		ProjectSettings.globalize_path("res://../SporeSpore_Evidence")
		. simplify_path()
		. replace("\\", "/")
		. trim_suffix("/")
	)
	var normalized_attempt_root := attempt_root.simplify_path().replace("\\", "/").trim_suffix("/")
	var durable := (
		normalized_attempt_root == production_root
		or normalized_attempt_root.begins_with(production_root + "/")
	)
	var expected_cells: Array[String] = []
	for arm_id in ["reference_zero", "positive_heading", "negative_heading"]:
		expected_cells.append(
			"%s__%s__%s" % [R23D40_ENGINE_ID, R23D40_CANDIDATE_ID, arm_id]
		)
	var exact: bool = (
		durable
		and String(freeze.get("schema_version", "")) == R23D40_FREEZE_SCHEMA
		and String(freeze.get("campaign_id", "")) == R23D40_CAMPAIGN_ID
		and String(freeze.get("gate_id", "")) == R23D40_GATE_ID
		and String(freeze.get("status", ""))
		== "frozen_supervisor_only_physical_authorized"
		and String(freeze.get("preregistration_raw_sha256", ""))
		== R23D3WorkerScript._raw_file_sha256(R23D40_PREREGISTRATION_PATH)
		and String(freeze.get("implementation_contract_raw_sha256", ""))
		== R23D3WorkerScript._raw_file_sha256(R23D40_IMPLEMENTATION_PATH)
		and String(freeze.get("source_commit", "")) == source_commit
		and bool(freeze.get("physical_execution_authorized", false))
		and _r23d40_source_bindings_exact(freeze)
		and String(attempt.get("schema_version", "")) == R23D40_ATTEMPT_SCHEMA
		and String(attempt.get("campaign_id", "")) == R23D40_CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == R23D40_GATE_ID
		and String(attempt.get("freeze_raw_sha256", ""))
		== R23D3WorkerScript._raw_file_sha256(freeze_path)
		and String(attempt.get("source_commit", "")) == source_commit
		and String(attempt.get("authorization_token", "")) == token
		and R23D3WorkerScript._valid_lower_hex(String(attempt.get("attempt_id", "")), 32)
		and bool(attempt.get("physical_execution_authorized", false))
		and bool(attempt.get("single_use_supervisor_authorization", false))
		and bool(attempt.get("source_worktree_clean", false))
		and bool(attempt.get("source_matches_live_github_main", false))
		and bool(attempt.get("operation_lock_held", false))
		and bool(attempt.get("campaign_attestation_adoption_valid", false))
		and bool(attempt.get("content_addressed_inputs_retained", false))
		and bool(attempt.get("one_shot_attempt_unconsumed", false))
		and String(attempt.get("attempt_root", "")).simplify_path()
		== normalized_attempt_root
		and attempt.get("ordered_matrix_cell_ids", []) == expected_cells
		and OS.get_environment(R23D40_STAGE_ENV) == String(cell["stage_id"])
		and OS.get_environment(R23D40_CELL_ENV) == String(cell["cell_id"])
		and OS.get_environment(R23D40_ENGINE_ENV) == R23D40_ENGINE_ID
	)
	if not exact:
		return _r23d40_failure("QSDK_R23D40_GJT_PHYSICAL_AUTHORIZATION_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"attempt_root": normalized_attempt_root,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d40_source_bindings_exact(freeze: Dictionary) -> bool:
	var required := {
		R23D40_WORKER_PATH.trim_prefix("res://"): R23D3WorkerScript._raw_file_sha256(R23D40_WORKER_PATH),
		R23D40_TRACE_COMPOSITION_BOUNDARY_PATH.trim_prefix("res://"): R23D3WorkerScript._raw_file_sha256(R23D40_TRACE_COMPOSITION_BOUNDARY_PATH),
		R23D40_BASE_WORKER_PATH.trim_prefix("res://"): R23D3WorkerScript._raw_file_sha256(R23D40_BASE_WORKER_PATH),
		R23D40_RUNNER_PATH.trim_prefix("res://"): R23D3WorkerScript._raw_file_sha256(R23D40_RUNNER_PATH),
		R23D40_ADAPTER_PATH.trim_prefix("res://"): R23D3WorkerScript._raw_file_sha256(R23D40_ADAPTER_PATH),
		R23D40_GDEXTENSION_PATH.trim_prefix("res://"): R23D3WorkerScript._raw_file_sha256(R23D40_GDEXTENSION_PATH),
		R23D40_PREREGISTRATION_PATH.trim_prefix("res://"): R23D3WorkerScript._raw_file_sha256(R23D40_PREREGISTRATION_PATH),
		R23D40_IMPLEMENTATION_PATH.trim_prefix("res://"): R23D3WorkerScript._raw_file_sha256(R23D40_IMPLEMENTATION_PATH),
		R23D40_DESIGN_PATH.trim_prefix("res://"): R23D3WorkerScript._raw_file_sha256(R23D40_DESIGN_PATH),
		R23D40_EVALUATOR_PATH.trim_prefix("res://"): R23D3WorkerScript._raw_file_sha256(R23D40_EVALUATOR_PATH),
		R23D40_PUBLISHER_PATH.trim_prefix("res://"): R23D3WorkerScript._raw_file_sha256(R23D40_PUBLISHER_PATH),
	}
	var bindings_value: Variant = freeze.get("source_bindings", null)
	if typeof(bindings_value) != TYPE_ARRAY:
		return false
	var observed := {}
	for item_value in bindings_value:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		observed[String(item.get("path", ""))] = String(item.get("raw_sha256", ""))
	for path_value in required:
		var path := String(path_value)
		if String(observed.get(path, "")) != String(required[path]):
			return false
	return true


static func _r23d40_perturbation_exact(value: Dictionary, expected_value: Variant) -> bool:
	if typeof(expected_value) != TYPE_DICTIONARY:
		return false
	var expected: Dictionary = expected_value
	var linear: Vector3 = value.get("initial_linear_velocity_world_m_s", Vector3.INF)
	var angular: Vector3 = value.get(
		"initial_torso_angular_velocity_world_rad_s",
		Vector3.INF,
	)
	var expected_linear: Array = expected.get("initial_linear_velocity_world_m_s", [])
	var expected_angular: Array = expected.get(
		"initial_torso_angular_velocity_world_rad_s",
		[],
	)
	return (
		int(value.get("campaign_seed", -1)) == int(expected.get("campaign_seed", -2))
		and _r23d40_close(
			float(value.get("fixture_vertical_clearance_m", NAN)),
			float(expected.get("fixture_vertical_clearance_m", NAN)),
		)
		and _r23d40_close(
			float(value.get("fixture_yaw_rad", NAN)),
			float(expected.get("fixture_yaw_rad", NAN)),
		)
		and expected_linear.size() == 3
		and _r23d40_close(linear.x, float(expected_linear[0]))
		and _r23d40_close(linear.y, float(expected_linear[1]))
		and _r23d40_close(linear.z, float(expected_linear[2]))
		and expected_angular.size() == 3
		and _r23d40_close(angular.x, float(expected_angular[0]))
		and _r23d40_close(angular.y, float(expected_angular[1]))
		and _r23d40_close(angular.z, float(expected_angular[2]))
		and int(value.get("gait_phase_offset_ticks", 9999))
		== int(expected.get("gait_phase_offset_ticks", -9999))
	)


static func _r23d40_close(observed: float, expected: float) -> bool:
	# Godot's JSON parser rounds the final printed decimal on two of the seeded
	# values, while the pure compiler retains the binary float used physically.
	# This is validation tolerance only; the world consumes the compiler output.
	return is_finite(observed) and is_finite(expected) and absf(observed - expected) <= 1.0e-15


static func _r23d40_cell(stage_id: String, onset_id: String, arm_id: String) -> Dictionary:
	if (
		stage_id != R23D40_STAGE_ID
		or onset_id != R23D40_ONSET_ID
		or not R23D40_ARM_OFFSETS.has(arm_id)
	):
		return _r23d40_failure("QSDK_R23D40_GJT_CELL_IDENTITY_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"stage_id": stage_id,
		"cell_id": "%s__%s__%s" % [R23D40_ENGINE_ID, R23D40_CANDIDATE_ID, arm_id],
		"engine_id": R23D40_ENGINE_ID,
		"onset_id": onset_id,
		"turn_start_semantic_step": R23D40_TURN_START_STEP,
		"arm_id": arm_id,
		"turn_heading_offset_rad": float(R23D40_ARM_OFFSETS[arm_id]),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _r23d40_worker_failure(
	cell: Dictionary,
	source_commit: String,
	failure_stage: String,
	failure_code: String,
	world_attempt_count: int,
	world_build_count: int,
	trace_artifact: Variant = null,
	raw_sdk_authority_summary: Variant = null,
	godot_execution_predicates: Variant = null,
	trace_diagnostic: Variant = null,
	trace_diagnostic_artifact: Variant = null,
) -> Dictionary:
	var normalized_commit := source_commit
	if not R23D3WorkerScript._valid_lower_hex(normalized_commit, 40):
		normalized_commit = "0".repeat(40)
	return {
		"schema_version": R23D40_FAILURE_SCHEMA,
		"campaign_id": R23D40_CAMPAIGN_ID,
		"gate_id": R23D40_GATE_ID,
		"stage_id": String(cell.get("stage_id", R23D40_STAGE_ID)),
		"cell_id": String(cell.get("cell_id", "")),
		"engine_id": R23D40_ENGINE_ID,
		"onset_id": String(cell.get("onset_id", "")),
		"turn_start_semantic_step": int(cell.get("turn_start_semantic_step", -1)),
		"arm_id": String(cell.get("arm_id", "")),
		"turn_heading_offset_rad": float(cell.get("turn_heading_offset_rad", 0.0)),
		"source_commit": normalized_commit,
		"failure_stage": failure_stage,
		"failure_code": failure_code,
		"world_attempt_count": world_attempt_count,
		"world_build_count": world_build_count,
		"trace_artifact": trace_artifact,
		"trace_diagnostic": trace_diagnostic,
		"trace_diagnostic_artifact": trace_diagnostic_artifact,
		"raw_sdk_authority_summary": raw_sdk_authority_summary,
		"godot_execution_predicates": godot_execution_predicates,
		"claims": R23D40_FALSE_CLAIMS.duplicate(true),
	}


static func _r23d40_failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
