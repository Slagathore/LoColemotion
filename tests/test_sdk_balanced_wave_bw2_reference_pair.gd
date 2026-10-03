extends SceneTree

## BW2 opened-data reference pair. The control observes the selected frozen
## balanced-wave candidate while
## the legacy host remains the motor source. The treatment uses portable
## balanced-wave ordered commands as the motor base and adds the unchanged,
## bounded P5I.3C stability contribution. Walking is an observed development
## outcome, not an assertion in this integrity harness.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const GaitClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")

const EXPECTED_GATE_COUNT := 20
const EXPECTED_STEP_COUNT := 1514
const EXPECTED_COMMAND_COUNT := EXPECTED_STEP_COUNT * 8
const BALANCED_POLICY_ID := "sporespore_balanced_wave_v1"
const BALANCED_B_POLICY_ID := "sporespore_balanced_wave_bw2_b_v1"
const BALANCED_C_POLICY_ID := "sporespore_balanced_wave_bw2_c_v1"
const BALANCED_BW2R_A_POLICY_ID := "sporespore_balanced_wave_bw2r_a_v1"
const BALANCED_BW2R_B_POLICY_ID := "sporespore_balanced_wave_bw2r_b_v1"
const BALANCED_BW2R_C_POLICY_ID := "sporespore_balanced_wave_bw2r_c_v1"
const BALANCED_BW4R_A_POLICY_ID := "sporespore_balanced_wave_bw4r_a_v1"
const BALANCED_BW4R_B_POLICY_ID := "sporespore_balanced_wave_bw4r_b_v1"
const BALANCED_BW5R_A_POLICY_ID := "sporespore_balanced_wave_bw5r_a_v1"
const BALANCED_BW5R_B_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const BALANCED_BW5R_C_POLICY_ID := "sporespore_balanced_wave_bw5r_c_v1"
const BALANCED_RUNTIME_ID := "sporespore_balanced_wave_runtime_v1"
const FEEDBACK_POLICY_ID := "p5i3c_support_centroid_tilt_feedback_v1"
const OVERLAY_RUNTIME_ID := "sporespore_godot_jolt_stability_overlay_runtime_v1"
const OVERLAY_MEMORY_ID := "sporespore_stability_overlay_memory_v1"
const PORTABLE_BASE_SOURCE := "portable_controller_ordered_commands"
const MAXIMUM_READBACK_ERROR_RAD_S := 2.0e-8
const MAXIMUM_HOST_COMMAND_QUANTIZATION_ERROR_RAD_S := 1.2e-7

const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "balanced_wave_bw2_reference",
	"torso_length_scale": 1.0,
	"torso_width_scale": 1.0,
	"upper_length_fraction": 18.0 / 35.0,
	"hip_span_scale": 1.0,
	"foot_radius_scale": 1.0,
	"front_limb_mass_scale": 1.0,
}
const ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
# These two option dictionaries intentionally retain the matched legacy
# Candidate 35 control configuration. In the treatment, the rig computes that
# observer/scaffold command before the adapter call, but the selected candidate's
# Rust output supplies both the base target velocity and its speed limit and
# overwrites every motor before the next physics frame. Gates 10-13 prove that
# all 12,112 treatment writes use that portable base; the no-world authority
# contract separately proves the exact frozen A, B, and C profile values.
const PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 1.0,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.275,
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
const MOTOR_VELOCITY_OPTIONS := {
	"mass_adaptive_motor_velocity_enabled": true,
	"motor_velocity_policy_id": "g3_gp5_morphology_interaction_anchor_guard_v1",
	"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s": 3.5,
	"anchor_error_guard_enabled": true,
	"morphology_interaction_score": 0.0,
	"anchor_error_guard_activation_fraction": 0.90,
	"anchor_error_guard_maximum_motor_target_speed_rad_s": 2.5,
}
const SOLVER_POLICY_OPTIONS := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": 120,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
const CONTROL_SDK_OPTIONS := {
	"enabled": true,
	"descriptor": DESCRIPTOR,
	"comparison_tolerance": 2.0e-8,
	"stability_policy_id": FEEDBACK_POLICY_ID,
	"controller_policy_id": BALANCED_POLICY_ID,
}
const TREATMENT_SDK_OPTIONS := {
	"enabled": true,
	"descriptor": DESCRIPTOR,
	"comparison_tolerance": 2.0e-8,
	"authority_scope": "stability_contribution_overlay",
	"stability_policy_id": FEEDBACK_POLICY_ID,
	"controller_policy_id": BALANCED_POLICY_ID,
}

var _passed := 0
var _failed := 0
var _candidate_id := "BW2-A"
var _policy_id := BALANCED_POLICY_ID


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var candidate_result := _select_candidate()
	if not bool(candidate_result.get("ok", false)):
		push_error(String(candidate_result.get("failure_code", "INVALID_BW2_CANDIDATE_ARGUMENT")))
		quit(1)
		return
	print("\n=== SDK balanced-wave %s opened reference pair ===" % _candidate_id)
	if OS.get_cmdline_user_args().has("--preflight-only"):
		print(
			"BALANCED_WAVE_BW2_REFERENCE_PREFLIGHT ",
			JSON.stringify(
				{
					"ok": true,
					"candidate_id": _candidate_id,
					"policy_id": _policy_id,
					"world_build_count": 0,
				},
				"",
				true,
				true,
			),
		)
		quit(0)
		return
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var clock_result := GaitClockSpecScript.compile(GaitClockSpecScript.gq15_clock())
	_check(bool(clock_result.get("ok", false)), "1 frozen GQ15 clock compiles")
	if not bool(clock_result.get("ok", false)):
		_finish({}, {})
		return
	var gait_clock_options: Dictionary = clock_result["gait_clock_options"]
	var control_options := CONTROL_SDK_OPTIONS.duplicate(true)
	control_options["controller_policy_id"] = _policy_id
	var treatment_options := TREATMENT_SDK_OPTIONS.duplicate(true)
	treatment_options["controller_policy_id"] = _policy_id
	var control: Dictionary = await _run_cell(gait_clock_options, control_options, {})
	var treatment: Dictionary = await _run_cell(gait_clock_options, {}, treatment_options)

	_check(
		int(control.get("world_build_count", 0)) == 1,
		"2 control constructs exactly one independent world",
	)
	_check(
		int(treatment.get("world_build_count", 0)) == 1,
		"3 treatment constructs exactly one independent world",
	)
	_check(
		(
			(
				String(control.get("fixture_spec_sha256", ""))
				== String(treatment.get("fixture_spec_sha256", ""))
			)
			and (
				String(control.get("controller_configuration_sha256", ""))
				== String(treatment.get("controller_configuration_sha256", ""))
			)
			and (
				String(control.get("evidence_threshold_configuration_sha256", ""))
				== String(treatment.get("evidence_threshold_configuration_sha256", ""))
			)
			and (
				String(control.get("solver_policy_configuration_sha256", ""))
				== String(treatment.get("solver_policy_configuration_sha256", ""))
			)
			and control.get("gait_clock_options", {}) == treatment.get("gait_clock_options", {})
			and control.get("initial_perturbation", {}) == treatment.get("initial_perturbation", {})
		),
		"4 control and treatment fixture, clock, thresholds, solver, and start are identical",
	)

	var control_sdk: Dictionary = control.get("sdk_shadow_summary", {})
	var treatment_sdk: Dictionary = treatment.get("sdk_authority_summary", {})
	var control_contribution: Dictionary = control_sdk.get(
		"stability_contribution_shadow_summary", {}
	)
	var treatment_contribution: Dictionary = treatment_sdk.get(
		"stability_contribution_shadow_summary", {}
	)
	var control_mapping: Dictionary = control_sdk.get("joint_mapping_shadow_summary", {})
	var treatment_mapping: Dictionary = treatment_sdk.get("joint_mapping_shadow_summary", {})
	var control_overlay: Dictionary = control_sdk.get("stability_overlay_summary", {})
	var treatment_overlay: Dictionary = treatment_sdk.get("stability_overlay_summary", {})

	_check(
		_outcome_is_complete(control),
		"5 control returns a complete walking or nonwalking outcome",
	)
	_check(
		_outcome_is_complete(treatment),
		"6 treatment returns a complete walking or nonwalking outcome",
	)
	_check(
		int(control_sdk.get("step_count", -1)) == EXPECTED_STEP_COUNT,
		"7 control records exactly 1514 balanced-wave shadow steps",
	)
	_check(
		int(treatment_sdk.get("step_count", -1)) == EXPECTED_STEP_COUNT,
		"8 treatment records exactly 1514 balanced-wave authority steps",
	)
	_check(
		(
			bool(control_sdk.get("balanced_wave_shadow_valid", false))
			and (
				int(control_sdk.get("validated_balanced_wave_command_count", -1))
				== EXPECTED_COMMAND_COUNT
			)
			and int(control_sdk.get("native_actuation_application_count", -1)) == 0
			and int(control_overlay.get("motor_write_count", -1)) == 0
		),
		"9 control validates 12112 portable commands and writes zero motors",
	)
	_check(
		(
			bool(treatment_sdk.get("balanced_wave_shadow_valid", false))
			and (
				int(treatment_sdk.get("validated_balanced_wave_command_count", -1))
				== EXPECTED_COMMAND_COUNT
			)
			and (
				int(treatment_sdk.get("native_actuation_application_count", -1))
				== EXPECTED_COMMAND_COUNT
			)
			and int(treatment_overlay.get("motor_write_count", -1)) == EXPECTED_COMMAND_COUNT
		),
		"10 treatment validates and writes exactly 12112 portable-base commands",
	)
	_check(
		(
			String(treatment_overlay.get("base_command_source", "")) == PORTABLE_BASE_SOURCE
			and (
				int(
					(
						treatment_overlay
						. get(
							"portable_controller_base_application_count",
							-1,
						)
					)
				)
				== EXPECTED_COMMAND_COUNT
			)
		),
		"11 every treatment motor write uses the portable controller base",
	)
	_check(
		_controller_identity_passes(control_sdk, false),
		"12 control carries balanced policy, runtime, receipt, and no Candidate parity",
	)
	_check(
		_controller_identity_passes(treatment_sdk, true),
		"13 treatment carries balanced policy, runtime, receipt, and authority",
	)
	_check(
		(
			_contribution_coverage_passes(control_contribution)
			and _contribution_coverage_passes(treatment_contribution)
		),
		"14 both cells execute typed stability contribution coverage",
	)
	_check(
		int(treatment_overlay.get("nonzero_effective_application_count", 0)) > 0,
		"15 treatment applies at least one nonzero bounded stability contribution",
	)
	_check(
		(
			_contribution_fail_zero_passes(control_contribution)
			and _contribution_fail_zero_passes(treatment_contribution)
		),
		"16 unavailable and inactive contribution outputs remain exact zero",
	)
	_check(
		(
			_contribution_integrity_passes(control_mapping, control_contribution)
			and _contribution_integrity_passes(treatment_mapping, treatment_contribution)
		),
		"17 mapping, limiter, order, and profile conversion remain exact",
	)
	_check(
		(
			_direct_body_write_count(control) == 0
			and _direct_body_write_count(treatment) == 0
			and int(control_overlay.get("direct_body_write_count", -1)) == 0
			and int(treatment_overlay.get("direct_body_write_count", -1)) == 0
		),
		"18 both cells retain zero direct body-state writes",
	)
	_check(
		(
			bool(treatment_overlay.get("ok", false))
			and int(treatment_overlay.get("failure_count", -1)) == 0
			and int(treatment_overlay.get("combined_speed_limit_violation_count", -1)) == 0
			and (
				float(treatment_overlay.get("maximum_readback_error_rad_s", INF))
				<= MAXIMUM_READBACK_ERROR_RAD_S
			)
			and (
				float(
					(
						treatment_overlay
						. get(
							"maximum_host_command_quantization_error_rad_s",
							INF,
						)
					)
				)
				<= MAXIMUM_HOST_COMMAND_QUANTIZATION_ERROR_RAD_S
			)
		),
		"19 treatment overlay is bounded, readable, and failure-free",
	)
	_check(
		(
			not bool(treatment_overlay.get("physical_balance_recovery", true))
			and not bool(treatment_overlay.get("locomotion_robustness", true))
			and not bool(treatment_overlay.get("physical_acceptance_authority", true))
			and not bool(treatment_sdk.get("physical_acceptance_authority", true))
		),
		"20 all acceptance, recovery, and robustness claims remain false",
	)
	_finish(control, treatment)


func _run_cell(
	gait_clock_options: Dictionary,
	sdk_shadow_options: Dictionary,
	sdk_authority_options: Dictionary,
) -> Dictionary:
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
			{},
			ROBUSTNESS_OPTIONS,
			FixtureSpecScript.reference_spec(),
			PATH_STEERING_OPTIONS,
			ACTUATOR_IMPULSE_OPTIONS,
			MOTOR_VELOCITY_OPTIONS,
			{},
			gait_clock_options,
			SOLVER_POLICY_OPTIONS,
			{},
			sdk_shadow_options,
			sdk_authority_options,
		)
	)


static func _outcome_is_complete(summary: Dictionary) -> bool:
	return (
		summary.has("physical_wave_gait_walking_observed")
		and typeof(summary.get("physical_wave_gait_walking_observed")) == TYPE_BOOL
		and typeof(summary.get("failure_code", "")) == TYPE_STRING
	)


func _controller_identity_passes(sdk_summary: Dictionary, authority: bool) -> bool:
	return (
		String(sdk_summary.get("controller_policy_id", "")) == _policy_id
		and String(sdk_summary.get("controller_runtime_version", "")) == BALANCED_RUNTIME_ID
		and bool(sdk_summary.get("balanced_wave_shadow_valid", false))
		and not bool(sdk_summary.get("candidate35_shadow_parity_ok", true))
		and bool(sdk_summary.get("actuation_authority", not authority)) == authority
	)


static func _contribution_coverage_passes(contribution: Dictionary) -> bool:
	var attempt_count := int(contribution.get("attempt_count", -1))
	var available_count := int(contribution.get("available_count", -1))
	var infeasible_count := int(contribution.get("upstream_infeasible_count", -1))
	var unavailable_count := int(contribution.get("unavailable_count", -1))
	return (
		bool(contribution.get("ok", false))
		and attempt_count == EXPECTED_STEP_COUNT
		and available_count > 0
		and available_count + infeasible_count + unavailable_count == attempt_count
		and int(contribution.get("untyped_count", -1)) == 0
		and int(contribution.get("influence_output_count", -1)) == EXPECTED_COMMAND_COUNT
		and int(contribution.get("feedback_nonzero_attempt_count", 0)) > 0
	)


static func _contribution_fail_zero_passes(contribution: Dictionary) -> bool:
	var typed_fallback_attempt_count := (
		int(contribution.get("upstream_infeasible_count", -1))
		+ int(contribution.get("unavailable_count", -1))
	)
	return (
		int(contribution.get("inactive_zero_mismatch_count", -1)) == 0
		and (
			int(contribution.get("fallback_zero_output_count", -1))
			== typed_fallback_attempt_count * 8
		)
	)


static func _contribution_integrity_passes(
	mapping: Dictionary,
	contribution: Dictionary,
) -> bool:
	return (
		int(mapping.get("mismatch_count", -1)) == 0
		and int(contribution.get("mismatch_count", -1)) == 0
		and int(contribution.get("profile_conversion_failure_count", -1)) == 0
		and int(contribution.get("limiter_mismatch_count", -1)) == 0
		and (contribution.get("failure_codes", []) as Array).is_empty()
	)


static func _direct_body_write_count(summary: Dictionary) -> int:
	return (
		int(summary.get("direct_torso_force_command_count", -1))
		+ int(summary.get("direct_torso_impulse_command_count", -1))
		+ int(summary.get("direct_torso_velocity_command_count", -1))
		+ int(summary.get("direct_torso_transform_command_count", -1))
	)


static func _vector_dictionary(vector: Vector3) -> Dictionary:
	return {"x": vector.x, "y": vector.y, "z": vector.z}


static func _cell_receipt(summary: Dictionary, sdk_summary: Dictionary) -> Dictionary:
	var overlay: Dictionary = sdk_summary.get("stability_overlay_summary", {})
	var contribution: Dictionary = sdk_summary.get("stability_contribution_shadow_summary", {})
	return {
		"world_build_count": int(summary.get("world_build_count", -1)),
		"walking_observed": bool(summary.get("physical_wave_gait_walking_observed", false)),
		"failure_code": String(summary.get("failure_code", "")),
		"walking_gate_receipts":
		(summary.get("walking_gate_receipts", {}) as Dictionary).duplicate(true),
		"step_count": int(sdk_summary.get("step_count", -1)),
		"validated_balanced_wave_command_count":
		int(sdk_summary.get("validated_balanced_wave_command_count", -1)),
		"steering_feedback_update_count":
		int(sdk_summary.get("steering_feedback_update_count", -1)),
		"steering_filter_application_count":
		int(sdk_summary.get("steering_filter_application_count", -1)),
		"steering_saturation_count":
		int(sdk_summary.get("steering_saturation_count", -1)),
		"steering_slew_limited_count":
		int(sdk_summary.get("steering_slew_limited_count", -1)),
		"maximum_absolute_requested_steering_fraction":
		float(sdk_summary.get("maximum_absolute_requested_steering_fraction", INF)),
		"maximum_absolute_filtered_steering_fraction":
		float(sdk_summary.get("maximum_absolute_filtered_steering_fraction", INF)),
		"maximum_absolute_steering_delta_per_step":
		float(sdk_summary.get("maximum_absolute_steering_delta_per_step", INF)),
		"cumulative_absolute_cross_track_error_m_s":
		float(sdk_summary.get("cumulative_absolute_cross_track_error_m_s", INF)),
		"minimum_cross_track_error_m":
		float(sdk_summary.get("minimum_cross_track_error_m", INF)),
		"maximum_cross_track_error_m":
		float(sdk_summary.get("maximum_cross_track_error_m", INF)),
		"native_motor_write_count": int(sdk_summary.get("native_actuation_application_count", -1)),
		"portable_controller_base_application_count":
		int(overlay.get("portable_controller_base_application_count", -1)),
		"base_command_source": String(overlay.get("base_command_source", "")),
		"nonzero_stability_application_count":
		int(overlay.get("nonzero_effective_application_count", -1)),
		"stability_fallback_zero_output_count":
		int(contribution.get("fallback_zero_output_count", -1)),
		"stability_contribution_shadow_summary": contribution.duplicate(true),
		"joint_mapping_shadow_summary":
		(sdk_summary.get("joint_mapping_shadow_summary", {}) as Dictionary).duplicate(true),
		"maximum_tilt_rad": float(summary.get("maximum_tilt_rad", INF)),
		"minimum_torso_height_m": float(summary.get("minimum_torso_height_m", -INF)),
		"maximum_anchor_error_m": float(summary.get("maximum_anchor_error_m", INF)),
		"maximum_hinge_axis_error_rad": float(summary.get("maximum_hinge_axis_error_rad", INF)),
		"final_torso_displacement_world_m":
		_vector_dictionary(summary.get("final_torso_displacement_world_m", Vector3.ZERO)),
		"evidence_task_frame_forward_displacement_m":
		float(summary.get("evidence_task_frame_forward_displacement_m", NAN)),
		"final_task_frame_forward_displacement_m":
		float(summary.get("final_task_frame_forward_displacement_m", NAN)),
		"final_task_frame_lateral_displacement_m":
		float(summary.get("final_task_frame_lateral_displacement_m", NAN)),
		"task_frame_forward_axis_world_unit":
		_vector_dictionary(summary.get("task_frame_forward_axis_world_unit", Vector3.INF)),
		"task_frame_lateral_axis_world_unit":
		_vector_dictionary(summary.get("task_frame_lateral_axis_world_unit", Vector3.INF)),
		"controller_policy_id": String(sdk_summary.get("controller_policy_id", "")),
		"controller_profile_sha256": String(sdk_summary.get("controller_profile_sha256", "")),
		"adapter_capability_sha256": String(sdk_summary.get("adapter_capability_sha256", "")),
		"direct_body_write_count": _direct_body_write_count(summary),
		"physical_acceptance_authority": false,
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish(control: Dictionary, treatment: Dictionary) -> void:
	if _passed != EXPECTED_GATE_COUNT:
		_failed += 1
		push_error("Expected %d gates, observed %d" % [EXPECTED_GATE_COUNT, _passed])
	var control_sdk: Dictionary = control.get("sdk_shadow_summary", {})
	var treatment_sdk: Dictionary = treatment.get("sdk_authority_summary", {})
	var receipt := {
		"schema_version": "sporespore_balanced_wave_bw2_reference_pair_receipt_v2",
		"ok": _failed == 0,
		"candidate_id": _candidate_id,
		"policy_id": _policy_id,
		"passed_gate_count": _passed,
		"failed_gate_count": _failed,
		"expected_gate_count": EXPECTED_GATE_COUNT,
		"world_count":
		int(control.get("world_build_count", 0)) + int(treatment.get("world_build_count", 0)),
		"control": _cell_receipt(control, control_sdk),
		"treatment": _cell_receipt(treatment, treatment_sdk),
		"walking_acceptance": false,
		"material_robustness": false,
		"arbitrary_quadruped_coverage": false,
		"continuous_full_volume_coverage": false,
		"cross_engine_c6": false,
		"completed_engine_neutral_sdk": false,
		"physical_acceptance_authority": false,
	}
	print("BALANCED_WAVE_BW2_REFERENCE_RECEIPT ", JSON.stringify(receipt))
	print("\nSDK balanced-wave BW2 reference summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _select_candidate() -> Dictionary:
	var user_args := OS.get_cmdline_user_args()
	var selected: Array[String] = []
	for argument_value in user_args:
		var argument := String(argument_value)
		if [
			"--bw2-a",
			"--bw2-b",
			"--bw2-c",
			"--bw2r-a",
			"--bw2r-b",
			"--bw2r-c",
			"--bw4r-a",
			"--bw4r-b",
			"--bw5r-a",
			"--bw5r-b",
			"--bw5r-c",
		].has(argument):
			selected.append(argument)
	if selected.size() > 1:
		return {"ok": false, "failure_code": "MULTIPLE_BW2_CANDIDATE_ARGUMENTS"}
	if selected.is_empty() or String(selected[0]) == "--bw2-a":
		_candidate_id = "BW2-A"
		_policy_id = BALANCED_POLICY_ID
	elif String(selected[0]) == "--bw2-b":
		_candidate_id = "BW2-B"
		_policy_id = BALANCED_B_POLICY_ID
	elif String(selected[0]) == "--bw2-c":
		_candidate_id = "BW2-C"
		_policy_id = BALANCED_C_POLICY_ID
	elif String(selected[0]) == "--bw2r-a":
		_candidate_id = "BW2R-A"
		_policy_id = BALANCED_BW2R_A_POLICY_ID
	elif String(selected[0]) == "--bw2r-b":
		_candidate_id = "BW2R-B"
		_policy_id = BALANCED_BW2R_B_POLICY_ID
	elif String(selected[0]) == "--bw2r-c":
		_candidate_id = "BW2R-C"
		_policy_id = BALANCED_BW2R_C_POLICY_ID
	elif String(selected[0]) == "--bw4r-a":
		_candidate_id = "BW4R-A"
		_policy_id = BALANCED_BW4R_A_POLICY_ID
	elif String(selected[0]) == "--bw4r-b":
		_candidate_id = "BW4R-B"
		_policy_id = BALANCED_BW4R_B_POLICY_ID
	elif String(selected[0]) == "--bw5r-a":
		_candidate_id = "BW5R-A"
		_policy_id = BALANCED_BW5R_A_POLICY_ID
	elif String(selected[0]) == "--bw5r-b":
		_candidate_id = "BW5R-B"
		_policy_id = BALANCED_BW5R_B_POLICY_ID
	else:
		_candidate_id = "BW5R-C"
		_policy_id = BALANCED_BW5R_C_POLICY_ID
	return {"ok": true, "failure_code": ""}
