extends SceneTree
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Prospective Godot/Jolt worker for QSDK-R23D3 Stage B.
##
## The predecessor R23D2 identity remains closed. This worker owns a distinct
## fixed-2,992-step controller horizon, full diagnostic trace, exact Godot
## execution-predicate projection, and future R23D3 freeze/attempt chain. No
## fixture can be constructed until that later chain exists and matches the
## live source bytes.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const ProportionSpecScript := preload(
	"res://scripts/lab/gait/physical_quadruped_proportion_spec.gd"
)
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const ClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const MaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)

const PREREGISTRATION_PATH := "res://sdk/turning/r23d3_phase_balanced_preregistration_v1.json"
const R23D2_DEVELOPMENT_CONTRACT_PATH := "res://sdk/turning/r23d2_development_contract_v1.json"
const PHYSICAL_EVALUATOR_PATH := "res://sdk/turning/r23d3_physical_evaluator.py"
const CLOSURE_PATH := "res://sdk/turning/r23d3_physical_closure_v1.json"
const TRACE_PUBLISHER_PATH := "res://sdk/publish_qsdk_r23d3_trace.ps1"
const WORKER_PATH := "res://tests/test_sdk_qsdk_r23d3_godot_jolt_worker.gd"
const RUNNER_PATH := "res://scripts/lab/gait/physical_wave_gait_quadruped.gd"
const ADAPTER_PATH := "res://scripts/lab/gait/sdk_godot_jolt_adapter.gd"

const CAMPAIGN_ID := "QSDK-R23D3-PHASE-BALANCED-BILATERAL-TURN-DEVELOPMENT"
const GATE_ID := "QSDK-R23D3"
const ENGINE_ID := "godot_jolt"
const POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const POLICY_DIGEST := "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f"
const MORPHOLOGY_ID := "qsdk_r05_generated_s169"
const MATERIAL_PROFILE_ID := "godot_jolt_bw5c_mu095_v1"
const STABILITY_POLICY_ID := "p5i3b_weight_support_shadow_v1"
const SCHEDULE_ID := "qsdk_r23d3_selected_onset_turn_return_v1"
const PREFLIGHT_SCHEMA := "sporespore_qsdk_r23d3_godot_jolt_worker_preflight_v1"
const REPORT_SCHEMA := "sporespore_qsdk_r23d3_engine_cell_report_v1"
const FAILURE_SCHEMA := "sporespore_qsdk_r23d3_worker_failure_v1"
const FREEZE_SCHEMA := "sporespore_qsdk_r23d3_physical_freeze_v1"
const ATTEMPT_SCHEMA := "sporespore_qsdk_r23d3_attempt_v1"
const GODOT_PREDICATE_SCHEMA := (
	"sporespore_qsdk_r23d3_godot_execution_predicate_summary_v1"
)
const TRACE_RETENTION_SCHEMA := "sporespore_qsdk_r23d3_trace_retention_v1"
const CONTROLLER_STEPS := 2992
const ACTUATOR_COUNT := 8
const TURN_DURATION_STEPS := 1200
const RECOVERY_DURATION_STEPS := 600
const PHYSICS_HZ := 120
const CAMPAIGN_SEED := 21501
const GENERATOR_INDEX := 169
const SDK_COMPARISON_TOLERANCE := 2.5e-7
const FIXED_HORIZON_POLICY_ID := "qsdk_r23d3_fixed_controller_horizon_v1"
const FIXED_HORIZON_POLICY_SHA256 := (
	"sha256:0ea68a8e22eba42ce786faf9256d7986a0f7b0ee2634353856f9f3504e1076db"
)
const TRACE_POLICY_ID := "qsdk_r23d3_phase_balanced_trace_v1"

const FREEZE_PATH_ENV := "SPORESPORE_QSDK_R23D3_FREEZE"
const ATTEMPT_PATH_ENV := "SPORESPORE_QSDK_R23D3_ATTEMPT"
const TOKEN_ENV := "SPORESPORE_QSDK_R23D3_TOKEN"
const STAGE_ENV := "SPORESPORE_QSDK_R23D3_STAGE"
const CELL_ENV := "SPORESPORE_QSDK_R23D3_CELL"
const ENGINE_ENV := "SPORESPORE_QSDK_R23D3_ENGINE"
const ATTEMPT_ROOT_ENV := "SPORESPORE_QSDK_R23D3_ATTEMPT_ROOT"
const PYTHON_ENV := "SPORESPORE_QSDK_R23D3_PYTHON"
const POWERSHELL_ENV := "SPORESPORE_QSDK_R23D3_POWERSHELL"

const ONSET_STEPS := {
	"onset_600": 600,
	"onset_690": 690,
	"onset_780": 780,
	"onset_870": 870,
}
const ARM_OFFSETS := {
	"reference_zero": 0.0,
	"positive_heading": 0.2,
	"negative_heading": -0.2,
}
const GAIT_STEPS := {
	"rear_left": 0,
	"front_left": 0,
	"rear_right": 0,
	"front_right": 0,
}
const ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const HOST_OBSERVER_PATH_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.25,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.40,
}
const ACTUATOR_IMPULSE_OPTIONS := {
	"mass_adaptive_actuator_enabled": true,
	"actuator_policy_id": "g3_gp3_global_actuator_margin_v1",
	"actuator_impulse_scale": 1.015,
}
const HOST_PREAUTHORITY_MOTOR_OPTIONS := {
	"mass_adaptive_motor_velocity_enabled": true,
	"motor_velocity_policy_id": "qsdk_r05_non_authoritative_host_preauthority_v1",
	"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s": 3.0,
	"anchor_error_guard_enabled": true,
	"morphology_interaction_score": 0.0,
	"anchor_error_guard_activation_fraction": 0.8,
	"anchor_error_guard_maximum_motor_target_speed_rad_s": 2.0,
}
const SOLVER_POLICY_OPTIONS := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": PHYSICS_HZ,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
const FALSE_CLAIMS := {
	"command_conditioned_turning": false,
	"bilateral_signed_turning": false,
	"portable_basic_turning": false,
	"cross_engine_equivalence": false,
	"q_sdk_r23_satisfied": false,
	"release_authorized": false,
	"physical_acceptance_authority": false,
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed := _parse_arguments(OS.get_cmdline_user_args())
	if not bool(parsed.get("ok", false)):
		print("QSDK_R23D3_GODOT_JOLT_FAILURE ", JSON.stringify(parsed))
		quit(1)
		return
	var cell := _cell(
		String(parsed["stage_id"]),
		String(parsed["onset_id"]),
		String(parsed["arm_id"]),
	)
	if not bool(cell.get("ok", false)):
		print("QSDK_R23D3_GODOT_JOLT_FAILURE ", JSON.stringify(cell))
		quit(1)
		return
	if bool(parsed["preflight_only"]):
		var preflight: Dictionary = await _run_preflight(cell)
		if not bool(preflight.get("ok", false)):
			print("QSDK_R23D3_GODOT_JOLT_FAILURE ", JSON.stringify(preflight))
			quit(1)
			return
		print("QSDK_R23D3_GODOT_JOLT_PREFLIGHT ", JSON.stringify(preflight))
		quit(0)
		return
	var source_commit := String(parsed["source_commit"])
	var terminal: Dictionary = await _run_physical(cell, source_commit)
	if String(terminal.get("schema_version", "")) == REPORT_SCHEMA:
		print("QSDK_R23D3_GODOT_JOLT_CELL ", JSON.stringify(terminal))
		quit(0)
		return
	print("QSDK_R23D3_GODOT_JOLT_FAILURE ", JSON.stringify(terminal))
	quit(1)


func _run_preflight(cell: Dictionary) -> Dictionary:
	var solver_receipt := _apply_solver_configuration()
	if not bool(solver_receipt.get("ok", false)):
		return solver_receipt
	var prepared := _prepare(cell)
	if not bool(prepared.get("ok", false)):
		return prepared
	var entrypoint: Dictionary = await _run_wave(prepared, true)
	var adapter_boundary := _adapter_boundary(prepared, cell)
	var trace_canary := _trace_row_canary(prepared, cell, adapter_boundary)
	var predicate_controls := _predicate_negative_controls()
	var expected_segments := _expected_segment_counts(cell)
	var entrypoint_exact := (
		bool(entrypoint.get("ok", false))
		and int(entrypoint.get("actual_world_build_count", -1)) == 0
		and int(entrypoint.get("scene_tree_insertion_count", -1)) == 0
		and not bool(entrypoint.get("physics_state_modified", true))
		and bool(entrypoint.get("candidate_authority_horizon_enabled", false))
		and int(entrypoint.get("candidate_authority_observation_count", -1))
		== CONTROLLER_STEPS
		and String(entrypoint.get("authority_horizon_policy_id", ""))
		== FIXED_HORIZON_POLICY_ID
		and String(entrypoint.get("authority_horizon_policy_sha256", ""))
		== FIXED_HORIZON_POLICY_SHA256
		and bool(entrypoint.get("sdk_physical_trace_enabled", false))
		and int(
			(entrypoint.get("sdk_physical_trace_options", {}) as Dictionary).get(
				"exact_controller_step_count",
				-1,
			)
		) == CONTROLLER_STEPS
		and String(
			(entrypoint.get("sdk_physical_trace_options", {}) as Dictionary).get(
				"cell_id",
				"",
			)
		) == String(cell["cell_id"])
	)
	if (
		not entrypoint_exact
		or not bool(adapter_boundary.get("ok", false))
		or not bool(trace_canary.get("ok", false))
		or not bool(predicate_controls.get("ok", false))
	):
		return _failure(
			"QSDK_R23D3_GJT_PREFLIGHT_INVALID",
			{
				"entrypoint": entrypoint,
				"adapter_boundary": adapter_boundary,
				"trace_canary": trace_canary,
				"predicate_controls": predicate_controls,
			},
		)
	return {
		"schema_version": PREFLIGHT_SCHEMA,
		"ok": true,
		"failure_code": "",
		"campaign_id": CAMPAIGN_ID,
		"gate_id": GATE_ID,
		"engine_id": ENGINE_ID,
		"stage_id": String(cell["stage_id"]),
		"cell_id": String(cell["cell_id"]),
		"onset_id": String(cell["onset_id"]),
		"turn_start_semantic_step": int(cell["turn_start_semantic_step"]),
		"arm_id": String(cell["arm_id"]),
		"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
		"preregistration_raw_sha256": _raw_file_sha256(PREREGISTRATION_PATH),
		"segment_counts": expected_segments,
		"fixed_controller_horizon_step_count": CONTROLLER_STEPS,
		"fixed_horizon_configuration_proved_before_fixture_insertion": true,
		"trace_retained_before_terminal_entry_required": true,
		"entrypoint_preflight": entrypoint,
		"solver_receipt": solver_receipt,
		"adapter_boundary": adapter_boundary,
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


func _run_physical(cell: Dictionary, source_commit: String) -> Dictionary:
	if not _valid_lower_hex(source_commit, 40):
		return _worker_failure(
			cell,
			source_commit,
			"before_world",
			"QSDK_R23D3_GJT_SOURCE_COMMIT_INVALID",
			0,
			0,
		)
	var authorization := _physical_authorization(cell, source_commit)
	if not bool(authorization.get("ok", false)):
		return _worker_failure(
			cell,
			source_commit,
			"before_world",
			String(authorization.get("failure_code", "QSDK_R23D3_GJT_AUTHORIZATION_INVALID")),
			0,
			0,
		)
	var preflight: Dictionary = await _run_preflight(cell)
	if not bool(preflight.get("ok", false)):
		return _worker_failure(
			cell,
			source_commit,
			"before_world",
			String(preflight.get("failure_code", "QSDK_R23D3_GJT_PREFLIGHT_INVALID")),
			0,
			0,
		)
	var prepared := _prepare(cell)
	if not bool(prepared.get("ok", false)):
		return _worker_failure(
			cell,
			source_commit,
			"before_world",
			String(prepared.get("failure_code", "QSDK_R23D3_GJT_PREPARE_INVALID")),
			0,
			0,
		)
	var summary: Dictionary = await _run_wave(prepared, false)
	var world_build_count := int(summary.get("world_build_count", 0))
	var raw_sdk_summary: Dictionary = summary.get("sdk_authority_summary", {})
	var predicates := _project_godot_predicates(raw_sdk_summary)
	if world_build_count != 1:
		return _worker_failure(
			cell,
			source_commit,
			"world_construction_failed",
			"QSDK_R23D3_GJT_WORLD_BUILD_COUNT_INVALID",
			1,
			world_build_count,
			null,
			raw_sdk_summary,
			predicates,
		)
	var trace_container: Dictionary = summary.get("sdk_physical_trace", {})
	var rows_value: Variant = trace_container.get("rows", null)
	if (
		typeof(rows_value) != TYPE_ARRAY
		or int(trace_container.get("row_count", -1)) != CONTROLLER_STEPS
		or not (trace_container.get("failure_codes", []) as Array).is_empty()
	):
		return _worker_failure(
			cell,
			source_commit,
			"settlement_complete",
			"QSDK_R23D3_GJT_TRACE_INCOMPLETE",
			1,
			1,
			null,
			raw_sdk_summary,
			predicates,
		)
	var retention := _retain_trace(
		cell,
		rows_value,
		String(authorization["attempt_root"]),
	)
	if not bool(retention.get("ok", false)):
		return _worker_failure(
			cell,
			source_commit,
			"settlement_complete",
			String(retention.get("failure_code", "QSDK_R23D3_GJT_TRACE_RETENTION_FAILED")),
			1,
			1,
			null,
			raw_sdk_summary,
			predicates,
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
	)
	if not execution_integrity:
		return _worker_failure(
			cell,
			source_commit,
			"settlement_complete",
			"QSDK_R23D3_GJT_EXECUTION_INTEGRITY_INVALID",
			1,
			1,
			trace_artifact,
			raw_sdk_summary,
			predicates,
		)
	var heading: Dictionary = summary.get("sdk_heading_schedule_receipt", {})
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
	}
	return {
		"schema_version": REPORT_SCHEMA,
		"campaign_id": CAMPAIGN_ID,
		"gate_id": GATE_ID,
		"stage_id": String(cell["stage_id"]),
		"cell_id": String(cell["cell_id"]),
		"engine_id": ENGINE_ID,
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
		"claims": FALSE_CLAIMS.duplicate(true),
	}


func _run_wave(prepared: Dictionary, preflight_before_world: bool) -> Dictionary:
	return await (
		WaveGaitScript
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
			prepared["trace_options"],
		)
	)


static func _prepare(cell: Dictionary) -> Dictionary:
	var contract := _read_json(PREREGISTRATION_PATH)
	var predecessor := _read_json(R23D2_DEVELOPMENT_CONTRACT_PATH)
	if not _contract_exact(contract, predecessor):
		return _failure("QSDK_R23D3_GJT_CONTRACT_IDENTITY_INVALID")
	var generation := ProportionSpecScript.compile_qsdk_r05_generation(GENERATOR_INDEX)
	if not bool(generation.get("ok", false)):
		return generation
	var proportion_spec: Dictionary = generation["proportion_spec"]
	var descriptor := {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": String(proportion_spec["morphology_id"]),
		"torso_length_scale": float(proportion_spec["torso_length_scale"]),
		"torso_width_scale": float(proportion_spec["torso_width_scale"]),
		"upper_length_fraction": float(proportion_spec["upper_length_fraction"]),
		"hip_span_scale": float(proportion_spec["hip_span_scale"]),
		"foot_radius_scale": float(proportion_spec["foot_radius_scale"]),
		"front_limb_mass_scale": float(proportion_spec["front_limb_mass_scale"]),
	}
	if CanonicalJsonScript.encode(descriptor) != CanonicalJsonScript.encode(
		(predecessor.get("fixture", {}) as Dictionary).get("descriptor", {})
	):
		return _failure("QSDK_R23D3_GJT_DESCRIPTOR_MISMATCH")
	var proportion_compilation := ProportionSpecScript.compile(proportion_spec)
	if not bool(proportion_compilation.get("ok", false)):
		return proportion_compilation
	var material_result := MaterialProfilesScript.resolve(MATERIAL_PROFILE_ID)
	if not bool(material_result.get("ok", false)):
		return material_result
	var fixture_candidate: Dictionary = (
		(proportion_compilation["fixture_spec"] as Dictionary).duplicate(true)
	)
	fixture_candidate["contact_material"] = (
		(material_result["profile"] as Dictionary)["body_material"] as Dictionary
	).duplicate(true)
	var fixture_result := FixtureSpecScript.compile(fixture_candidate)
	if not bool(fixture_result.get("ok", false)):
		return fixture_result
	var fixture: Dictionary = fixture_result["fixture_spec"]
	var perturbation_result := WaveGaitScript.compile_seeded_initial_perturbation(CAMPAIGN_SEED)
	if not bool(perturbation_result.get("ok", false)):
		return perturbation_result
	var initial_perturbation: Dictionary = perturbation_result["initial_perturbation"]
	if CanonicalJsonScript.encode(_json_initial_perturbation(initial_perturbation)) != (
		CanonicalJsonScript.encode(
			(predecessor.get("fixture", {}) as Dictionary).get("initial_perturbation", {})
		)
	):
		return _failure("QSDK_R23D3_GJT_INITIAL_PERTURBATION_MISMATCH")
	var clock_result := ClockSpecScript.compile(ClockSpecScript.gq15_clock())
	if not bool(clock_result.get("ok", false)):
		return clock_result
	var schedule := _schedule(cell)
	var schedule_result := WaveGaitScript.compile_sdk_heading_schedule_options(schedule)
	if not bool(schedule_result.get("ok", false)):
		return schedule_result
	var fixed_horizon_options := {
		"candidate_specific_horizon_extension_count": 0,
		"exact_candidate_authority_observation_count": CONTROLLER_STEPS,
		"first_candidate_authority_observation_index": 0,
		"last_candidate_authority_observation_index": CONTROLLER_STEPS - 1,
		"policy_id": FIXED_HORIZON_POLICY_ID,
		"policy_sha256": FIXED_HORIZON_POLICY_SHA256,
	}
	var horizon_result := WaveGaitScript.compile_candidate_authority_horizon_options(
		fixed_horizon_options
	)
	if not bool(horizon_result.get("ok", false)):
		return horizon_result
	var trace_options := {
		"cell_id": String(cell["cell_id"]),
		"exact_controller_step_count": CONTROLLER_STEPS,
		"policy_id": TRACE_POLICY_ID,
		"recovery_duration_steps": RECOVERY_DURATION_STEPS,
		"turn_duration_steps": TURN_DURATION_STEPS,
		"turn_heading_offset_rad": float(cell["turn_heading_offset_rad"]),
		"turn_start_semantic_step": int(cell["turn_start_semantic_step"]),
	}
	var trace_result := WaveGaitScript.compile_sdk_physical_trace_options(trace_options)
	if not bool(trace_result.get("ok", false)):
		return trace_result
	return {
		"ok": true,
		"failure_code": "",
		"descriptor": descriptor,
		"fixture_spec": fixture,
		"initial_perturbation": initial_perturbation,
		"gait_clock_options": clock_result["gait_clock_options"],
		"material_profile": material_result["profile"],
		"evidence_threshold_options": _evidence_thresholds(fixture),
		"authority_options":
		{
			"enabled": true,
			"descriptor": descriptor,
			"comparison_tolerance": SDK_COMPARISON_TOLERANCE,
			"authority_scope": "post_settle_full",
			"stability_policy_id": STABILITY_POLICY_ID,
			"material_profile_id": MATERIAL_PROFILE_ID,
			"controller_policy_id": POLICY_ID,
		},
		"fixed_horizon_options": fixed_horizon_options,
		"schedule": schedule,
		"schedule_sha256": String(schedule_result["sdk_heading_schedule_sha256"]),
		"trace_options": trace_options,
		"trace_configuration_sha256": String(
			trace_result["sdk_physical_trace_configuration_sha256"]
		),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _adapter_boundary(prepared: Dictionary, cell: Dictionary) -> Dictionary:
	var adapter: RefCounted = AdapterScript.new()
	var phase_offset := int(
		(prepared["initial_perturbation"] as Dictionary)["gait_phase_offset_ticks"]
	)
	var start: Dictionary = (
		adapter
		. start(
			prepared["descriptor"],
			GAIT_STEPS,
			0.0,
			Vector3.ZERO,
			Vector3.BACK,
			PI * 0.5,
			PHYSICS_HZ,
			SOLVER_POLICY_OPTIONS,
			SDK_COMPARISON_TOLERANCE,
			"clocked",
			true,
			phase_offset,
			360,
			"post_settle_full",
			STABILITY_POLICY_ID,
			prepared["material_profile"],
			POLICY_ID,
		)
	)
	if not bool(start.get("ok", false)):
		return _failure(
			"QSDK_R23D3_GJT_ADAPTER_START_INVALID:%s"
			% String(start.get("failure_code", "UNKNOWN"))
		)
	var command := {
		"schema_version": "sporespore_heading_offset_command_v1",
		"schedule_id": SCHEDULE_ID,
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
		and int(runtime.get("native_controller_command_count", -1)) == ACTUATOR_COUNT
		and int(runtime.get("actual_world_build_count", -1)) == 0
		and int(runtime.get("scene_tree_insertion_count", -1)) == 0
		and not bool(runtime.get("physics_state_modified", true))
		and String(start.get("controller_policy_id", "")) == POLICY_ID
		and String(manifest.get("physics_engine", "")) == "Jolt Physics"
		and is_finite(float(profile.get("cross_track_heading_gain_rad_per_m", NAN)))
		and is_finite(
			float(profile.get("cross_track_velocity_heading_gain_rad_per_m_s", NAN))
		)
	)
	adapter = null
	if not exact:
		return _failure(
			"QSDK_R23D3_GJT_ADAPTER_BOUNDARY_INVALID",
			{"start": start, "runtime": runtime, "morphology": morphology},
		)
	return {
		"ok": true,
		"failure_code": "",
		"controller_profile": profile.duplicate(true),
		"controller_profile_sha256": String(start["controller_profile_sha256"]),
		"adapter_capability_sha256": String(start["adapter_capability_sha256"]),
		"native_controller_command_count": ACTUATOR_COUNT,
		"host_parameter_write_count": int(runtime.get("host_parameter_write_count", -1)),
		"host_object_creation_count": int(runtime.get("host_object_creation_count", -1)),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _trace_row_canary(
	prepared: Dictionary,
	cell: Dictionary,
	adapter_boundary: Dictionary,
) -> Dictionary:
	if not bool(adapter_boundary.get("ok", false)):
		return _failure("QSDK_R23D3_GJT_TRACE_CANARY_ADAPTER_INVALID")
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
			"lateral_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
			"reference_yaw_rad": 0.0,
		},
	}
	var desired_error := clampf(
		offset
		- float(profile["cross_track_heading_gain_rad_per_m"]) * 0.05
		- float(profile["cross_track_velocity_heading_gain_rad_per_m_s"]) * -0.02,
		-0.25,
		0.25,
	)
	var receipt := {
		"cross_track_error_m": 0.05,
		"cross_track_velocity_m_s": -0.02,
		"measured_yaw_error_rad": 0.0,
		"desired_heading_error_rad": desired_error,
		"yaw_tracking_error_rad": -desired_error,
		"requested_steering_fraction": -desired_error,
		"held_steering_fraction": -desired_error * 0.5,
	}
	var memory_rows: Array[Dictionary] = []
	for index in range(4):
		memory_rows.append(
			{
				"limb_id": ["rear_left", "front_left", "rear_right", "front_right"][index],
				"gait_step": semantic_step + 3,
				"release_hold_step_count": 0,
			}
		)
	var request := {
		"memory": {"ordered_limb_memory": memory_rows},
		"state": state,
		"command":
		{
			"desired_heading_rad": offset,
			"valid_from_step": semantic_step,
			"valid_through_step": semantic_step,
		},
	}
	var commands: Array = []
	for index in range(ACTUATOR_COUNT):
		commands.append({"actuator_id": "canary_%d" % index})
	var sample_result := {
		"ok": true,
		"request": request,
		"heading_command_receipt":
		{
			"semantic_step": semantic_step,
			"heading_offset_rad": offset,
		},
	}
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
	var valid := WaveGaitScript._compose_sdk_physical_trace_row(
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
	)["desired_heading_error_rad"] = desired_error + 1.0e-6
	var rejected := WaveGaitScript._compose_sdk_physical_trace_row(
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
		"failure_code": "" if exact else "QSDK_R23D3_GJT_TRACE_ROW_CANARY_INVALID",
		"accepted_row_count": 1 if bool(valid.get("ok", false)) else 0,
		"oracle_mutation_rejected": not bool(rejected.get("ok", true)),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _predicate_negative_controls() -> Dictionary:
	var good := {
		"ok": true,
		"failure_code": "",
		"step_count": CONTROLLER_STEPS,
		"safe_no_actuation_count": 0,
		"mismatch_count": 0,
		"validated_balanced_wave_command_count": CONTROLLER_STEPS * ACTUATOR_COUNT,
		"native_actuation_application_count": CONTROLLER_STEPS * ACTUATOR_COUNT,
	}
	var fields := [
		"ok",
		"failure_code",
		"step_count",
		"safe_no_actuation_count",
		"mismatch_count",
		"validated_balanced_wave_command_count",
		"native_actuation_application_count",
	]
	var rejected := 0
	for field_value in fields:
		var field := String(field_value)
		var mutation := good.duplicate(true)
		match field:
			"ok": mutation[field] = false
			"failure_code": mutation[field] = "synthetic_failure"
			_: mutation[field] = int(mutation[field]) + 1
		var projection := _project_godot_predicates(mutation)
		if (
			not bool(projection.get("ok", true))
			and (projection.get("failed_predicate_ids", []) as Array).size() == 1
		):
			rejected += 1
	return {
		"ok": rejected == fields.size(),
		"failure_code": "" if rejected == fields.size() else "QSDK_R23D3_GJT_PREDICATE_CONTROL_INVALID",
		"rejected_mutation_count": rejected,
		"declared_mutation_count": fields.size(),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _project_godot_predicates(summary: Variant) -> Dictionary:
	var source: Dictionary = summary if typeof(summary) == TYPE_DICTIONARY else {}
	var declarations := [
		["sdk_summary_ok", "ok", true],
		["sdk_failure_code_empty", "failure_code", ""],
		["sdk_step_count", "step_count", CONTROLLER_STEPS],
		["sdk_safe_no_actuation_count", "safe_no_actuation_count", 0],
		["sdk_mismatch_count", "mismatch_count", 0],
		[
			"sdk_validated_command_count",
			"validated_balanced_wave_command_count",
			CONTROLLER_STEPS * ACTUATOR_COUNT,
		],
		[
			"sdk_native_application_count",
			"native_actuation_application_count",
			CONTROLLER_STEPS * ACTUATOR_COUNT,
		],
	]
	var rows: Array[Dictionary] = []
	var failed: Array[String] = []
	for declaration_value in declarations:
		var declaration: Array = declaration_value
		var predicate_id := String(declaration[0])
		var field := String(declaration[1])
		var expected: Variant = declaration[2]
		var present := source.has(field)
		var observed: Variant = source.get(field, null)
		var passed := present and _strict_equal(observed, expected)
		rows.append(
			{
				"predicate_id": predicate_id,
				"source_path": "sdk_authority_summary.%s" % field,
				"expected_value": expected,
				"observed_value": observed,
				"observed_value_type": _value_type(observed),
				"field_present": present,
				"passed": passed,
			}
		)
		if not passed:
			failed.append(predicate_id)
	return {
		"schema_version": GODOT_PREDICATE_SCHEMA,
		"ok": failed.is_empty(),
		"failed_predicate_ids": failed,
		"ordered_predicates": rows,
		"raw_sdk_authority_summary": source.duplicate(true),
		"physical_acceptance_authority": false,
	}


static func _retain_trace(
	cell: Dictionary,
	rows: Array,
	attempt_root: String,
) -> Dictionary:
	var pending_root := attempt_root.path_join("pending-traces")
	if DirAccess.make_dir_recursive_absolute(pending_root) != OK:
		return _failure("QSDK_R23D3_GJT_TRACE_ROOT_CREATE_FAILED")
	var rows_path := pending_root.path_join(
		"%s__%s.rows.json" % [String(cell["stage_id"]), String(cell["cell_id"])]
	)
	if FileAccess.file_exists(rows_path):
		return _failure("QSDK_R23D3_GJT_TRACE_ROWS_ALREADY_EXIST")
	var file := FileAccess.open(rows_path, FileAccess.WRITE)
	if file == null:
		return _failure("QSDK_R23D3_GJT_TRACE_ROWS_CREATE_FAILED")
	file.store_string(JSON.stringify(rows))
	file.store_string("\n")
	file.flush()
	file = null
	var python := OS.get_environment(PYTHON_ENV)
	if python.is_empty():
		python = "python"
	var powershell := OS.get_environment(POWERSHELL_ENV)
	if powershell.is_empty():
		powershell = "pwsh"
	var output: Array = []
	var exit_code := OS.execute(
		python,
		PackedStringArray(
			[
				ProjectSettings.globalize_path(PHYSICAL_EVALUATOR_PATH),
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
	var marker := "QSDK_R23D3_TRACE_RETAINED "
	var matches: Array[String] = []
	for output_value in output:
		for line_value in String(output_value).split("\n"):
			var line := String(line_value).strip_edges()
			if line.begins_with(marker):
				matches.append(line.trim_prefix(marker))
	if exit_code != 0 or matches.size() != 1:
		return _failure(
			"QSDK_R23D3_GJT_TRACE_RETENTION_FAILED:%d" % exit_code,
			{"output": output},
		)
	var parsed: Variant = JSON.parse_string(matches[0])
	if typeof(parsed) != TYPE_DICTIONARY:
		return _failure("QSDK_R23D3_GJT_TRACE_RETENTION_RECEIPT_INVALID")
	var receipt: Dictionary = parsed
	if (
		String(receipt.get("schema_version", "")) != TRACE_RETENTION_SCHEMA
		or String(receipt.get("stage_id", "")) != String(cell["stage_id"])
		or String(receipt.get("cell_id", "")) != String(cell["cell_id"])
		or not bool(receipt.get("retained_before_terminal_entry", false))
	):
		return _failure("QSDK_R23D3_GJT_TRACE_RETENTION_RECEIPT_INVALID", receipt)
	receipt["ok"] = true
	receipt["failure_code"] = ""
	return receipt


static func _physical_authorization(cell: Dictionary, source_commit: String) -> Dictionary:
	if FileAccess.file_exists(CLOSURE_PATH):
		return _failure("QSDK_R23D3_GJT_CLOSED")
	var freeze_path := OS.get_environment(FREEZE_PATH_ENV)
	var attempt_path := OS.get_environment(ATTEMPT_PATH_ENV)
	var token := OS.get_environment(TOKEN_ENV)
	var attempt_root := OS.get_environment(ATTEMPT_ROOT_ENV)
	if (
		freeze_path.is_empty()
		or attempt_path.is_empty()
		or attempt_root.is_empty()
		or not FileAccess.file_exists(freeze_path)
		or not FileAccess.file_exists(attempt_path)
		or not DirAccess.dir_exists_absolute(attempt_root)
		or not _valid_lower_hex(token, 32)
	):
		return _failure("QSDK_R23D3_GJT_PHYSICAL_AUTHORIZATION_REQUIRED")
	var freeze := _read_json(freeze_path)
	var attempt := _read_json(attempt_path)
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
	var stage_ids: Array = (
		attempt.get("ordered_stage_b_cell_ids", [])
		if String(cell["stage_id"]) == "three_engine_confirmation"
		else []
	)
	var exact := (
		durable
		and String(freeze.get("schema_version", "")) == FREEZE_SCHEMA
		and String(freeze.get("campaign_id", "")) == CAMPAIGN_ID
		and String(freeze.get("gate_id", "")) == GATE_ID
		and String(freeze.get("status", "")) == "frozen_supervisor_only_physical_authorized"
		and String(freeze.get("preregistration_raw_sha256", ""))
		== _raw_file_sha256(PREREGISTRATION_PATH)
		and String(freeze.get("source_commit", "")) == source_commit
		and bool(freeze.get("physical_execution_authorized", false))
		and _source_bindings_exact(freeze)
		and String(attempt.get("schema_version", "")) == ATTEMPT_SCHEMA
		and String(attempt.get("campaign_id", "")) == CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == GATE_ID
		and String(attempt.get("freeze_raw_sha256", "")) == _raw_file_sha256(freeze_path)
		and String(attempt.get("source_commit", "")) == source_commit
		and String(attempt.get("authorization_token", "")) == token
		and _valid_lower_hex(String(attempt.get("attempt_id", "")), 32)
		and bool(attempt.get("physical_execution_authorized", false))
		and bool(attempt.get("single_use_supervisor_authorization", false))
		and bool(attempt.get("source_worktree_clean", false))
		and bool(attempt.get("source_matches_live_github_main", false))
		and bool(attempt.get("operation_lock_held", false))
		and bool(attempt.get("full_godot_attestation_valid", false))
		and bool(attempt.get("content_addressed_inputs_retained", false))
		and bool(attempt.get("one_shot_attempt_unconsumed", false))
		and String(attempt.get("attempt_root", "")).simplify_path() == normalized_attempt_root
		and OS.get_environment(STAGE_ENV) == String(cell["stage_id"])
		and OS.get_environment(CELL_ENV) == String(cell["cell_id"])
		and OS.get_environment(ENGINE_ENV) == ENGINE_ID
		and stage_ids.has(String(cell["cell_id"]))
		and String(attempt.get("selected_onset_id", "")) == String(cell["onset_id"])
	)
	if not exact:
		return _failure("QSDK_R23D3_GJT_PHYSICAL_AUTHORIZATION_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"attempt_root": normalized_attempt_root,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _source_bindings_exact(freeze: Dictionary) -> bool:
	var required := {
		WORKER_PATH.trim_prefix("res://"): _raw_file_sha256(WORKER_PATH),
		RUNNER_PATH.trim_prefix("res://"): _raw_file_sha256(RUNNER_PATH),
		ADAPTER_PATH.trim_prefix("res://"): _raw_file_sha256(ADAPTER_PATH),
		PREREGISTRATION_PATH.trim_prefix("res://"): _raw_file_sha256(PREREGISTRATION_PATH),
		PHYSICAL_EVALUATOR_PATH.trim_prefix("res://"): _raw_file_sha256(PHYSICAL_EVALUATOR_PATH),
		TRACE_PUBLISHER_PATH.trim_prefix("res://"): _raw_file_sha256(TRACE_PUBLISHER_PATH),
		R23D2_DEVELOPMENT_CONTRACT_PATH.trim_prefix("res://"): _raw_file_sha256(
			R23D2_DEVELOPMENT_CONTRACT_PATH
		),
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


static func _worker_failure(
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
	if not _valid_lower_hex(normalized_commit, 40):
		normalized_commit = "0".repeat(40)
	return {
		"schema_version": FAILURE_SCHEMA,
		"campaign_id": CAMPAIGN_ID,
		"gate_id": GATE_ID,
		"stage_id": String(cell.get("stage_id", "three_engine_confirmation")),
		"cell_id": String(cell.get("cell_id", "")),
		"engine_id": ENGINE_ID,
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
		"raw_sdk_authority_summary": raw_sdk_authority_summary,
		"godot_execution_predicates": godot_execution_predicates,
		"claims": FALSE_CLAIMS.duplicate(true),
	}


static func _parse_arguments(args: PackedStringArray) -> Dictionary:
	var values := {}
	var preflight_only := false
	var index := 0
	while index < args.size():
		var argument := String(args[index])
		if argument == "--preflight-only" and not preflight_only:
			preflight_only = true
			index += 1
			continue
		if ["--stage", "--onset", "--arm", "--source-commit"].has(argument):
			if values.has(argument) or index + 1 >= args.size():
				return _argument_failure("QSDK_R23D3_GJT_ARGUMENT_DUPLICATE_OR_MISSING")
			values[argument] = String(args[index + 1])
			index += 2
			continue
		return _argument_failure("QSDK_R23D3_GJT_ARGUMENT_UNKNOWN:%s" % argument)
	if (
		not values.has("--stage")
		or not values.has("--onset")
		or not values.has("--arm")
		or preflight_only == values.has("--source-commit")
	):
		return _argument_failure("QSDK_R23D3_GJT_ARGUMENTS_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"stage_id": String(values["--stage"]),
		"onset_id": String(values["--onset"]),
		"arm_id": String(values["--arm"]),
		"preflight_only": preflight_only,
		"source_commit": String(values.get("--source-commit", "")),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _cell(stage_id: String, onset_id: String, arm_id: String) -> Dictionary:
	if (
		stage_id != "three_engine_confirmation"
		or not ONSET_STEPS.has(onset_id)
		or not ARM_OFFSETS.has(arm_id)
	):
		return _argument_failure("QSDK_R23D3_GJT_CELL_IDENTITY_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"stage_id": stage_id,
		"cell_id": "%s__%s__%s" % [ENGINE_ID, onset_id, arm_id],
		"engine_id": ENGINE_ID,
		"onset_id": onset_id,
		"turn_start_semantic_step": int(ONSET_STEPS[onset_id]),
		"arm_id": arm_id,
		"turn_heading_offset_rad": float(ARM_OFFSETS[arm_id]),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _contract_exact(contract: Dictionary, predecessor: Dictionary) -> bool:
	var fixture: Dictionary = contract.get("fixture", {})
	var schedule: Dictionary = contract.get("command_schedule", {})
	return (
		String(contract.get("schema_version", ""))
		== "sporespore_qsdk_r23d3_phase_balanced_preregistration_v1"
		and String(contract.get("campaign_id", "")) == CAMPAIGN_ID
		and String(contract.get("gate_id", "")) == GATE_ID
		and String(fixture.get("morphology_id", "")) == MORPHOLOGY_ID
		and int(fixture.get("campaign_seed", -1)) == CAMPAIGN_SEED
		and int(fixture.get("physics_hz", -1)) == PHYSICS_HZ
		and float(fixture.get("authored_sliding_friction", NAN)) == 0.95
		and String(fixture.get("selected_policy_id", "")) == POLICY_ID
		and String(fixture.get("selected_policy_digest", "")) == POLICY_DIGEST
		and int(schedule.get("controller_semantic_step_count", -1)) == CONTROLLER_STEPS
		and int(schedule.get("turn_duration_steps", -1)) == TURN_DURATION_STEPS
		and int(schedule.get("reference_recovery_duration_steps", -1))
		== RECOVERY_DURATION_STEPS
		and not bool((contract.get("authorization", {}) as Dictionary).get(
			"physical_execution_authorized",
			true,
		))
		and String(predecessor.get("schema_version", ""))
		== "sporespore_qsdk_r23d2_development_contract_v1"
	)


static func _schedule(cell: Dictionary) -> Dictionary:
	var onset := int(cell["turn_start_semantic_step"])
	var turn_end := onset + TURN_DURATION_STEPS
	var recovery_end := turn_end + RECOVERY_DURATION_STEPS
	return {
		"schema_version": "sporespore_heading_offset_schedule_v1",
		"schedule_id": SCHEDULE_ID,
		"domain": "controller_semantic_step",
		"reference_heading_source": "state.task_frame.reference_yaw_rad",
		"segments":
		[
			{
				"segment_id": "reference_warmup",
				"start_step_inclusive": 0,
				"end_step_exclusive": onset,
				"heading_offset_rad": 0.0,
				"command_role": "reference_heading",
			},
			{
				"segment_id": "commanded_turn",
				"start_step_inclusive": onset,
				"end_step_exclusive": turn_end,
				"heading_offset_rad": float(cell["turn_heading_offset_rad"]),
				"command_role": "turn_heading",
			},
			{
				"segment_id": "reference_recovery",
				"start_step_inclusive": turn_end,
				"end_step_exclusive": recovery_end,
				"heading_offset_rad": 0.0,
				"command_role": "reference_heading",
			},
		],
		"after_last_segment": "hold_reference_heading",
	}


static func _expected_segment_counts(cell: Dictionary) -> Dictionary:
	var onset := int(cell["turn_start_semantic_step"])
	return {
		"reference_warmup": onset,
		"commanded_turn": TURN_DURATION_STEPS,
		"reference_recovery": RECOVERY_DURATION_STEPS,
		"after_declared_schedule": CONTROLLER_STEPS - onset - TURN_DURATION_STEPS - RECOVERY_DURATION_STEPS,
	}


static func _apply_solver_configuration() -> Dictionary:
	Engine.physics_ticks_per_second = PHYSICS_HZ
	ProjectSettings.set_setting(
		"physics/jolt_physics_3d/simulation/velocity_steps",
		20,
	)
	ProjectSettings.set_setting(
		"physics/jolt_physics_3d/simulation/position_steps",
		7,
	)
	var realized := {
		"solver_policy_id": String(SOLVER_POLICY_OPTIONS["solver_policy_id"]),
		"physics_engine": String(ProjectSettings.get_setting("physics/3d/physics_engine", "")),
		"physics_hz": Engine.physics_ticks_per_second,
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
	}
	var exact := realized == SOLVER_POLICY_OPTIONS
	return {
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R23D3_GJT_SOLVER_POLICY_INVALID",
		"realized_solver_policy": realized,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _evidence_thresholds(fixture: Dictionary) -> Dictionary:
	var torso: Dictionary = fixture["torso"]
	var torso_size: Array = torso["size_m"]
	var initial_center: Array = torso["initial_center_m"]
	var first_limb: Dictionary = (fixture["limbs"] as Array)[0]
	return {
		"evidence_threshold_policy_id": "nonuniform_dimensionless_thresholds_v1",
		"minimum_foot_relocation_m": 0.0238 * float(torso_size[0]),
		"minimum_evidence_torso_advance_m": 0.080 * float(torso_size[0]),
		"minimum_final_torso_advance_m": 0.060 * float(torso_size[0]),
		"maximum_lateral_drift_m": 0.3125 * float(torso_size[2]),
		"maximum_yaw_drift_rad": 0.45,
		"maximum_tilt_rad": 0.60,
		"minimum_torso_height_m": (25.0 / 44.0) * float(initial_center[1]),
		"maximum_anchor_error_m": 0.14 * float(first_limb["upper_length_m"]),
		"maximum_hinge_axis_error_rad": 0.20,
	}


static func _json_initial_perturbation(value: Dictionary) -> Dictionary:
	var linear: Vector3 = value["initial_linear_velocity_world_m_s"]
	var angular: Vector3 = value["initial_torso_angular_velocity_world_rad_s"]
	return {
		"campaign_seed": int(value["campaign_seed"]),
		"fixture_vertical_clearance_m": float(value["fixture_vertical_clearance_m"]),
		"fixture_yaw_rad": float(value["fixture_yaw_rad"]),
		"initial_linear_velocity_world_m_s": [linear.x, linear.y, linear.z],
		"initial_torso_angular_velocity_world_rad_s": [angular.x, angular.y, angular.z],
		"gait_phase_offset_ticks": int(value["gait_phase_offset_ticks"]),
	}


static func _strict_equal(observed: Variant, expected: Variant) -> bool:
	return typeof(observed) == typeof(expected) and observed == expected


static func _value_type(value: Variant) -> String:
	match typeof(value):
		TYPE_BOOL: return "boolean"
		TYPE_INT: return "integer"
		TYPE_FLOAT: return "number"
		TYPE_STRING: return "string"
		TYPE_ARRAY: return "array"
		TYPE_DICTIONARY: return "object"
		TYPE_NIL: return "null"
	return type_string(typeof(value))


static func _raw_file_sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return "sha256:%s" % context.finish().hex_encode()


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _valid_lower_hex(value: String, expected_length: int) -> bool:
	if value.length() != expected_length:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _argument_failure(code: String) -> Dictionary:
	return {
		"schema_version": FAILURE_SCHEMA,
		"ok": false,
		"engine_id": ENGINE_ID,
		"failure_code": code,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}
