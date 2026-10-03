extends SceneTree

## P5I.3C's first-result harness: two sequential, independently constructed
## Candidate 35 worlds. The control computes the feedback path in shadow; the
## treatment adds only the bounded characterized stability contribution to the
## unchanged legacy motor target during the exact evidence window.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const GaitClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")

const FEEDBACK_POLICY_ID := "p5i3c_support_centroid_tilt_feedback_v1"
const OVERLAY_RUNTIME_ID := "sporespore_godot_jolt_stability_overlay_runtime_v1"
const OVERLAY_MEMORY_ID := "sporespore_stability_overlay_memory_v1"
const EXPECTED_STEP_COUNT := 1514
const EXPECTED_MOTOR_WRITE_COUNT := EXPECTED_STEP_COUNT * 8
const MAXIMUM_OVERLAY_DELTA_RAD_S := 0.075
const MAXIMUM_READBACK_ERROR_RAD_S := 2.0e-8
const MAXIMUM_HOST_COMMAND_QUANTIZATION_ERROR_RAD_S := 1.2e-7

const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "godot_jolt_stability_physical_influence_reference",
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
const GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE := 2.0e-8
const CONTROL_SDK_OPTIONS := {
	"enabled": true,
	"descriptor": DESCRIPTOR,
	"comparison_tolerance": GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
	"stability_policy_id": FEEDBACK_POLICY_ID,
}
const TREATMENT_SDK_OPTIONS := {
	"enabled": true,
	"descriptor": DESCRIPTOR,
	"comparison_tolerance": GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
	"authority_scope": "stability_contribution_overlay",
	"stability_policy_id": FEEDBACK_POLICY_ID,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK Godot/Jolt P5I.3C bounded physical stability influence ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var clock_result := GaitClockSpecScript.compile(GaitClockSpecScript.gq15_clock())
	_check(bool(clock_result.get("ok", false)), "1 frozen GQ15 clock compiles")
	if not bool(clock_result.get("ok", false)):
		_finish()
		return
	var gait_clock_options: Dictionary = clock_result["gait_clock_options"]
	var control: Dictionary = await _run_cell(
		gait_clock_options,
		CONTROL_SDK_OPTIONS,
		{},
	)
	var treatment: Dictionary = await _run_cell(
		gait_clock_options,
		{},
		TREATMENT_SDK_OPTIONS,
	)

	_check(
		int(control.get("world_build_count", 0)) == 1,
		"2 control constructs exactly one independent world",
	)
	_check(
		int(treatment.get("world_build_count", 0)) == 1,
		"3 treatment constructs exactly one independent world",
	)
	var configuration_identical: bool = (
		String(control.get("fixture_spec_sha256", ""))
		== String(treatment.get("fixture_spec_sha256", ""))
		and String(control.get("controller_configuration_sha256", ""))
		== String(treatment.get("controller_configuration_sha256", ""))
		and String(control.get("evidence_threshold_configuration_sha256", ""))
		== String(treatment.get("evidence_threshold_configuration_sha256", ""))
		and String(control.get("solver_policy_configuration_sha256", ""))
		== String(treatment.get("solver_policy_configuration_sha256", ""))
		and control.get("gait_clock_options", {}) == treatment.get("gait_clock_options", {})
		and control.get("initial_perturbation", {})
		== treatment.get("initial_perturbation", {})
		and control.get("realized_solver_policy_options", {})
		== treatment.get("realized_solver_policy_options", {})
	)
	_check(configuration_identical, "4 paired configuration identities are exact")
	_check(
		bool(control.get("physical_wave_gait_walking_observed", false)),
		"5 control retains every Candidate 35 walking gate",
	)
	_check(
		bool(treatment.get("physical_wave_gait_walking_observed", false)),
		"6 treatment retains every Candidate 35 walking gate",
	)

	var control_sdk: Dictionary = control.get("sdk_shadow_summary", {})
	var treatment_sdk: Dictionary = treatment.get("sdk_authority_summary", {})
	var control_contribution: Dictionary = control_sdk.get(
		"stability_contribution_shadow_summary",
		{},
	)
	var treatment_contribution: Dictionary = treatment_sdk.get(
		"stability_contribution_shadow_summary",
		{},
	)
	var control_overlay: Dictionary = control_sdk.get("stability_overlay_summary", {})
	var treatment_overlay: Dictionary = treatment_sdk.get(
		"stability_overlay_summary",
		{},
	)
	_check(
		int(control_sdk.get("step_count", -1)) == EXPECTED_STEP_COUNT,
		"7 control records exactly 1514 feedback-shadow steps",
	)
	_check(
		int(treatment_sdk.get("step_count", -1)) == EXPECTED_STEP_COUNT,
		"8 treatment records exactly 1514 feedback-overlay steps",
	)
	_check(
		_contribution_coverage_passes(control_contribution)
		and _contribution_coverage_passes(treatment_contribution),
		"9 both cells have typed contribution coverage and nonzero feedback",
	)
	_check(
		int(control_sdk.get("native_actuation_application_count", -1)) == 0
		and int(control_overlay.get("motor_write_count", -1)) == 0,
		"10 control records zero SDK motor writes",
	)
	_check(
		int(treatment_sdk.get("native_actuation_application_count", -1))
		== EXPECTED_MOTOR_WRITE_COUNT
		and int(treatment_overlay.get("motor_write_count", -1))
		== EXPECTED_MOTOR_WRITE_COUNT
		and int(
			treatment.get(
				"legacy_sdk_overlay_base_application_count",
				-1,
			)
		)
		== EXPECTED_MOTOR_WRITE_COUNT,
		"11 treatment records exactly 12112 ordered overlay motor writes",
	)
	_check(
		int(treatment_overlay.get("nonzero_effective_application_count", 0)) > 0,
		"12 treatment applies at least one nonzero effective overlay",
	)
	_check(
		float(
			treatment_overlay.get(
				"maximum_absolute_requested_delta_rad_s",
				INF,
			)
		)
		<= MAXIMUM_OVERLAY_DELTA_RAD_S
		and float(
			treatment_overlay.get(
				"maximum_absolute_effective_delta_rad_s",
				INF,
			)
		)
		<= MAXIMUM_OVERLAY_DELTA_RAD_S,
		"13 requested and effective overlays remain inside 0.075 rad/s",
	)
	_check(
		int(
			treatment_overlay.get(
				"combined_speed_limit_violation_count",
				-1,
			)
		)
		== 0
		and float(treatment_overlay.get("maximum_readback_error_rad_s", INF))
		<= MAXIMUM_READBACK_ERROR_RAD_S
		and float(
			treatment_overlay.get(
				"maximum_host_command_quantization_error_rad_s",
				INF,
			)
		)
		<= MAXIMUM_HOST_COMMAND_QUANTIZATION_ERROR_RAD_S,
		"14 combined targets respect base limits and motor readback tolerance",
	)
	_check(
		_contribution_fail_zero_passes(control_contribution)
		and _contribution_fail_zero_passes(treatment_contribution),
		"15 inactive and infeasible paths retain exact fail-zero behavior",
	)
	var control_mapping: Dictionary = control_sdk.get("joint_mapping_shadow_summary", {})
	var treatment_mapping: Dictionary = treatment_sdk.get(
		"joint_mapping_shadow_summary",
		{},
	)
	_check(
		_contribution_integrity_passes(control_mapping, control_contribution)
		and _contribution_integrity_passes(treatment_mapping, treatment_contribution),
		"16 mapping, profile, order, and limiter mismatches remain zero",
	)
	_check(
		_direct_body_write_count(control) == 0
		and _direct_body_write_count(treatment) == 0
		and int(control_overlay.get("direct_body_write_count", -1)) == 0
		and int(treatment_overlay.get("direct_body_write_count", -1)) == 0,
		"17 both cells retain zero direct torso or body-state writes",
	)

	var initial_position_error_m := (
		(control["initial_torso_position_world_m"] as Vector3).distance_to(
			treatment["initial_torso_position_world_m"] as Vector3
		)
	)
	var initial_orientation_error := _orientation_error(
		control.get("initial_torso_orientation_xyzw", {}),
		treatment.get("initial_torso_orientation_xyzw", {}),
	)
	_check(
		initial_position_error_m <= 1.0e-9
		and initial_orientation_error <= 1.0e-9,
		"18 paired initial torso position and orientation are identical",
	)
	var terminal_position_delta_m := (
		(control["final_torso_position_world_m"] as Vector3).distance_to(
			treatment["final_torso_position_world_m"] as Vector3
		)
	)
	_check(
		terminal_position_delta_m >= 1.0e-5,
		"19 terminal positions establish a nonzero causal physical effect",
	)
	_check(
		float(treatment.get("maximum_tilt_rad", INF))
		<= float(control.get("maximum_tilt_rad", -INF)) + 0.02,
		"20 treatment tilt does not exceed the frozen paired allowance",
	)
	var control_final_displacement: Vector3 = control["final_torso_displacement_world_m"]
	var treatment_final_displacement: Vector3 = treatment[
		"final_torso_displacement_world_m"
	]
	_check(
		absf(treatment_final_displacement.z)
		<= absf(control_final_displacement.z) + 0.05,
		"21 treatment lateral drift does not exceed the frozen paired allowance",
	)
	_check(
		treatment_final_displacement.x >= control_final_displacement.x - 0.10,
		"22 treatment forward advance does not exceed the frozen regression allowance",
	)
	_check(
		float(treatment.get("maximum_anchor_error_m", INF))
		<= float(control.get("maximum_anchor_error_m", -INF)) + 0.005
		and float(treatment.get("maximum_hinge_axis_error_rad", INF))
		<= float(control.get("maximum_hinge_axis_error_rad", -INF)) + 0.02,
		"23 treatment joint geometry remains within the frozen paired allowances",
	)
	var treatment_manifest: Dictionary = treatment_sdk.get("adapter_manifest", {})
	var treatment_stability_v3: Dictionary = treatment_manifest.get("stability_v3", {})
	var treatment_feedback_manifest: Dictionary = treatment_stability_v3.get(
		"feedback_policy",
		{},
	)
	_check(
		String(control_sdk.get("stability_policy_id", "")) == FEEDBACK_POLICY_ID
		and String(treatment_sdk.get("stability_policy_id", "")) == FEEDBACK_POLICY_ID
		and String(treatment_sdk.get("authority_scope", ""))
		== "stability_contribution_overlay"
		and String(treatment_overlay.get("policy_id", "")) == FEEDBACK_POLICY_ID
		and String(treatment_overlay.get("runtime_id", "")) == OVERLAY_RUNTIME_ID
		and String(treatment_overlay.get("memory_id", "")) == OVERLAY_MEMORY_ID
		and String(treatment_feedback_manifest.get("policy_id", ""))
		== FEEDBACK_POLICY_ID
		and bool(treatment_overlay.get("physical_influence", false))
		and not bool(control_overlay.get("physical_influence", true))
		and not bool(treatment_overlay.get("physical_balance_recovery", true))
		and not bool(treatment_overlay.get("locomotion_robustness", true))
		and not bool(treatment_overlay.get("physical_acceptance_authority", true))
		and not bool(treatment_overlay.get("completed_sdk", true))
		and String(treatment.get("sdk_authority_failure_code", "")).is_empty()
		and bool(control_sdk.get("candidate35_shadow_parity_ok", false))
		and int(control_sdk.get("mismatch_count", -1)) == 0
		and bool(treatment_sdk.get("stability_overlay_runtime_ok", false))
		and int(treatment_sdk.get("maximum_absolute_phase_error_steps", -1)) == 0
		and float(
			treatment_sdk.get(
				"maximum_absolute_speed_limit_error_rad_s",
				INF,
			)
		)
		== 0.0
		and bool(treatment.get("sdk_p5i3c_fixed_exposure_enabled", false))
		and int(treatment.get("sdk_p5i3c_fixed_exposure_step_count", -1))
		== EXPECTED_STEP_COUNT,
		"24 identities, authority counters, and influence nonclaims are exact",
	)

	if _failed > 0:
		print(
			"SDK_STABILITY_PHYSICAL_INFLUENCE_FAILURE_DIAGNOSTIC ",
			{
				"control_failure_code": control.get("failure_code", ""),
				"control_walking_gates": control.get("walking_gate_receipts", {}),
				"control_sdk": control_sdk,
				"treatment_failure_code": treatment.get("failure_code", ""),
				"treatment_walking_gates": treatment.get("walking_gate_receipts", {}),
				"treatment_sdk": treatment_sdk,
				"initial_position_error_m": initial_position_error_m,
				"initial_orientation_error": initial_orientation_error,
				"terminal_position_delta_m": terminal_position_delta_m,
			},
		)

	print(
		"SDK_STABILITY_PHYSICAL_INFLUENCE_RECEIPT ",
		JSON.stringify(
			{
				"schema_version":
				"sporespore_godot_jolt_stability_physical_influence_receipt_v1",
				"ok": _failed == 0,
				"passed_gate_count": _passed,
				"failed_gate_count": _failed,
				"expected_gate_count": 24,
				"policy_id": FEEDBACK_POLICY_ID,
				"runtime_id": OVERLAY_RUNTIME_ID,
				"memory_id": OVERLAY_MEMORY_ID,
				"configuration_identity":
				{
					"fixture_spec_sha256":
					String(control.get("fixture_spec_sha256", "")),
					"controller_configuration_sha256":
					String(control.get("controller_configuration_sha256", "")),
					"evidence_threshold_configuration_sha256":
					String(
						control.get(
							"evidence_threshold_configuration_sha256",
							"",
						)
					),
					"solver_policy_configuration_sha256":
					String(control.get("solver_policy_configuration_sha256", "")),
				},
				"initial_position_error_m": initial_position_error_m,
				"initial_orientation_error": initial_orientation_error,
				"terminal_position_delta_m": terminal_position_delta_m,
				"control":
				_cell_receipt(control, control_sdk, control_contribution, control_overlay),
				"treatment":
				_cell_receipt(
					treatment,
					treatment_sdk,
					treatment_contribution,
					treatment_overlay,
				),
				"physical_influence": _failed == 0,
				"physical_balance_recovery": false,
				"balance_improvement": false,
				"locomotion_robustness": false,
				"friction_material_robustness": false,
				"rough_terrain_robustness": false,
				"external_push_recovery": false,
				"sensor_fault_robustness": false,
				"cross_engine_locomotion": false,
				"fresh_morphology_validation": false,
				"physical_acceptance_authority": false,
				"completed_sdk": false,
			},
			"",
			true,
			true,
		),
	)
	_finish()


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


static func _contribution_coverage_passes(contribution: Dictionary) -> bool:
	return (
		bool(contribution.get("ok", false))
		and int(contribution.get("attempt_count", -1)) == EXPECTED_STEP_COUNT
		and int(contribution.get("available_count", -1)) >= 1000
		and int(contribution.get("unavailable_count", -1)) == 0
		and int(contribution.get("untyped_count", -1)) == 0
		and int(contribution.get("feedback_nonzero_attempt_count", 0)) > 0
	)


static func _contribution_fail_zero_passes(contribution: Dictionary) -> bool:
	return (
		int(contribution.get("inactive_zero_mismatch_count", -1)) == 0
		and int(contribution.get("fallback_zero_output_count", -1))
		== int(contribution.get("upstream_infeasible_count", -2)) * 8
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


static func _orientation_error(a_value: Variant, b_value: Variant) -> float:
	if typeof(a_value) != TYPE_DICTIONARY or typeof(b_value) != TYPE_DICTIONARY:
		return INF
	var a: Dictionary = a_value
	var b: Dictionary = b_value
	var direct := sqrt(
		pow(float(a.get("x", INF)) - float(b.get("x", -INF)), 2.0)
		+ pow(float(a.get("y", INF)) - float(b.get("y", -INF)), 2.0)
		+ pow(float(a.get("z", INF)) - float(b.get("z", -INF)), 2.0)
		+ pow(float(a.get("w", INF)) - float(b.get("w", -INF)), 2.0)
	)
	var antipodal := sqrt(
		pow(float(a.get("x", INF)) + float(b.get("x", INF)), 2.0)
		+ pow(float(a.get("y", INF)) + float(b.get("y", INF)), 2.0)
		+ pow(float(a.get("z", INF)) + float(b.get("z", INF)), 2.0)
		+ pow(float(a.get("w", INF)) + float(b.get("w", INF)), 2.0)
	)
	return minf(direct, antipodal)


static func _cell_receipt(
	summary: Dictionary,
	sdk_summary: Dictionary,
	contribution: Dictionary,
	overlay: Dictionary,
) -> Dictionary:
	var initial_position: Vector3 = summary.get(
		"initial_torso_position_world_m",
		Vector3(INF, INF, INF),
	)
	var final_position: Vector3 = summary.get(
		"final_torso_position_world_m",
		Vector3(INF, INF, INF),
	)
	var final_displacement: Vector3 = summary.get(
		"final_torso_displacement_world_m",
		Vector3(INF, INF, INF),
	)
	return {
		"world_build_count": int(summary.get("world_build_count", -1)),
		"walking_observed":
		bool(summary.get("physical_wave_gait_walking_observed", false)),
		"walking_gate_receipts":
		(summary.get("walking_gate_receipts", {}) as Dictionary).duplicate(true),
		"step_count": int(sdk_summary.get("step_count", -1)),
		"authority_scope": String(sdk_summary.get("authority_scope", "")),
		"stability_policy_id": String(sdk_summary.get("stability_policy_id", "")),
		"native_actuation_application_count":
		int(sdk_summary.get("native_actuation_application_count", -1)),
		"legacy_sdk_overlay_base_application_count":
		int(summary.get("legacy_sdk_overlay_base_application_count", -1)),
		"sdk_p5i3c_fixed_exposure_enabled":
		bool(summary.get("sdk_p5i3c_fixed_exposure_enabled", false)),
		"sdk_p5i3c_fixed_exposure_step_count":
		int(summary.get("sdk_p5i3c_fixed_exposure_step_count", -1)),
		"candidate35_mismatch_count": int(sdk_summary.get("mismatch_count", -1)),
		"candidate35_shadow_parity_ok":
		bool(sdk_summary.get("candidate35_shadow_parity_ok", false)),
		"stability_overlay_runtime_ok":
		bool(sdk_summary.get("stability_overlay_runtime_ok", false)),
		"candidate35_maximum_absolute_target_position_error_rad":
		float(
			sdk_summary.get(
				"maximum_absolute_target_position_error_rad",
				INF,
			)
		),
		"candidate35_maximum_absolute_target_velocity_error_rad_s":
		float(
			sdk_summary.get(
				"maximum_absolute_target_velocity_error_rad_s",
				INF,
			)
		),
		"candidate35_maximum_absolute_speed_limit_error_rad_s":
		float(
			sdk_summary.get(
				"maximum_absolute_speed_limit_error_rad_s",
				INF,
			)
		),
		"candidate35_maximum_absolute_phase_error_steps":
		int(sdk_summary.get("maximum_absolute_phase_error_steps", -1)),
		"candidate35_maximum_absolute_steering_error":
		float(sdk_summary.get("maximum_absolute_steering_error", INF)),
		"stability_contribution_shadow": contribution.duplicate(true),
		"stability_overlay": overlay.duplicate(true),
		"initial_torso_position_world_m": _vector_dictionary(initial_position),
		"initial_torso_orientation_xyzw":
		(summary.get("initial_torso_orientation_xyzw", {}) as Dictionary).duplicate(true),
		"final_torso_position_world_m": _vector_dictionary(final_position),
		"final_torso_displacement_world_m": _vector_dictionary(final_displacement),
		"maximum_tilt_rad": float(summary.get("maximum_tilt_rad", INF)),
		"maximum_anchor_error_m": float(summary.get("maximum_anchor_error_m", INF)),
		"maximum_hinge_axis_error_rad":
		float(summary.get("maximum_hinge_axis_error_rad", INF)),
		"direct_body_write_count": _direct_body_write_count(summary),
		"sdk_authority_failure_code":
		String(summary.get("sdk_authority_failure_code", "")),
	}


static func _vector_dictionary(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print(
		"\nSDK Godot/Jolt P5I.3C summary: %d passed, %d failed"
		% [_passed, _failed]
	)
	quit(0 if _failed == 0 else 1)
