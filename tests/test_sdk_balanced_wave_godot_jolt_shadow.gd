extends SceneTree

## BW1 same-world Godot/Jolt shadow. The legacy GDScript walker retains all
## motor authority; balanced-wave is sampled only through the explicit native
## policy route and must emit complete, ordered, bounded, no-authority frames.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const GaitClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")

const BALANCED_WAVE_POLICY_ID := "sporespore_balanced_wave_v1"
const BALANCED_WAVE_RUNTIME_VERSION := "sporespore_balanced_wave_runtime_v1"
const EXPECTED_EXPOSURE_STEPS := 1514
const EXPECTED_COMMANDS := EXPECTED_EXPOSURE_STEPS * 8

const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "godot_jolt_balanced_wave_bw1_reference",
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
const SDK_SHADOW_OPTIONS := {
	"enabled": true,
	"descriptor": DESCRIPTOR,
	"comparison_tolerance": 2.0e-8,
	"stability_policy_id": "p5i3c_support_centroid_tilt_feedback_v1",
	"controller_policy_id": BALANCED_WAVE_POLICY_ID,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK Godot/Jolt balanced-wave BW1 shadow ===")
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/velocity_steps", 20)
	ProjectSettings.set_setting("physics/jolt_physics_3d/simulation/position_steps", 7)
	var clock_result := GaitClockSpecScript.compile(GaitClockSpecScript.gq15_clock())
	_check(bool(clock_result.get("ok", false)), "the frozen GQ15 clock compiles")
	if not bool(clock_result.get("ok", false)):
		_finish()
		return
	var summary: Dictionary = await (
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
			clock_result["gait_clock_options"],
			SOLVER_POLICY_OPTIONS,
			{},
			SDK_SHADOW_OPTIONS,
		)
	)
	_check(
		int(summary.get("world_build_count", 0)) == 1,
		"one private Godot/Jolt world executes",
	)
	var start_result: Dictionary = summary.get("sdk_shadow_start_result", {})
	var manifest: Dictionary = start_result.get("adapter_manifest", {})
	var profile: Dictionary = manifest.get("controller_profile", {})
	_check(
		bool(start_result.get("ok", false))
		and String(start_result.get("controller_policy_id", ""))
		== BALANCED_WAVE_POLICY_ID
		and String(start_result.get("controller_runtime_version", ""))
		== BALANCED_WAVE_RUNTIME_VERSION
		and String(manifest.get("schema_version", ""))
		== "sporespore_godot_jolt_adapter_manifest_v14"
		and String(manifest.get("controller_policy_id", ""))
		== BALANCED_WAVE_POLICY_ID
		and String(profile.get("policy_id", "")) == BALANCED_WAVE_POLICY_ID
		and (profile.get("branch_surfaces", []) as Array).is_empty(),
		"explicit balanced-wave policy, runtime, profile, and branch-free identity are frozen",
	)
	_check(
		String(start_result.get("controller_profile_sha256", "")).begins_with("sha256:")
		and String(start_result.get("controller_profile_sha256", "")).length() == 71
		and not bool(start_result.get("actuation_authority", true))
		and int(start_result.get("world_build_count", -1)) == 0
		and not bool(start_result.get("physical_acceptance_authority", true)),
		"the adapter exposes a profile digest and starts with zero authority",
	)

	var shadow: Dictionary = summary.get("sdk_shadow_summary", {})
	if not bool(shadow.get("ok", false)):
		print("BALANCED_WAVE_BW1_FAILURE ", JSON.stringify(shadow))
	_check(
		bool(shadow.get("ok", false))
		and bool(shadow.get("balanced_wave_shadow_valid", false))
		and not bool(shadow.get("candidate35_shadow_parity_ok", true))
		and String(shadow.get("controller_policy_id", ""))
		== BALANCED_WAVE_POLICY_ID
		and String(shadow.get("controller_runtime_version", ""))
		== BALANCED_WAVE_RUNTIME_VERSION,
		"all balanced-wave shadow steps retain the selected controller identity",
	)
	_check(
		int(shadow.get("step_count", -1)) == EXPECTED_EXPOSURE_STEPS
		and int(shadow.get("validated_balanced_wave_command_count", -1))
		== EXPECTED_COMMANDS
		and int(shadow.get("compared_actuator_command_count", -1)) == 0
		and int(shadow.get("mismatch_count", -1)) == 0
		and int(shadow.get("safe_no_actuation_count", -1)) == 0,
		"all 1,514 steps emit 12,112 ordered, finite, bounded base commands",
	)
	_check(
		int(shadow.get("balanced_wave_step_receipt_count", -1))
		== EXPECTED_EXPOSURE_STEPS
		and String(
			shadow.get("balanced_wave_first_step_receipt_sha256", "")
		).begins_with("sha256:")
		and String(
			shadow.get("balanced_wave_first_step_receipt_sha256", "")
		).length() == 71
		and String(
			shadow.get("balanced_wave_last_step_receipt_sha256", "")
		).begins_with("sha256:")
		and String(
			shadow.get("balanced_wave_last_step_receipt_sha256", "")
		).length() == 71,
		"every balanced-wave step exposes a typed receipt digest",
	)

	var stability: Dictionary = shadow.get("stability_shadow_summary", {})
	_check(
		bool(stability.get("ok", false))
		and int(stability.get("attempt_count", -1)) == EXPECTED_EXPOSURE_STEPS
		and (
			int(stability.get("available_count", -1))
			+ int(stability.get("unavailable_count", -1))
			== EXPECTED_EXPOSURE_STEPS
		)
		and int(stability.get("mismatch_count", -1)) == 0,
		"stability observations reconcile exactly with zero oracle mismatch",
	)
	var mapping: Dictionary = shadow.get("joint_mapping_shadow_summary", {})
	_check(
		bool(mapping.get("ok", false))
		and int(mapping.get("attempt_count", -1)) == EXPECTED_EXPOSURE_STEPS
		and (
			int(mapping.get("available_count", -1))
			+ int(mapping.get("unavailable_count", -1))
			+ int(mapping.get("infeasible_count", -1))
			== EXPECTED_EXPOSURE_STEPS
		)
		and int(mapping.get("compared_actuator_count", -1))
		== int(mapping.get("available_count", -1)) * 8
		and int(mapping.get("mismatch_count", -1)) == 0,
		"joint-mapping availability partitions and ordered comparisons reconcile exactly",
	)
	var contribution: Dictionary = shadow.get(
		"stability_contribution_shadow_summary",
		{},
	)
	_check(
		bool(contribution.get("ok", false))
		and int(contribution.get("attempt_count", -1)) == EXPECTED_EXPOSURE_STEPS
		and (
			int(contribution.get("available_count", -1))
			+ int(contribution.get("upstream_infeasible_count", -1))
			+ int(contribution.get("unavailable_count", -1))
			== EXPECTED_EXPOSURE_STEPS
		)
		and int(contribution.get("influence_output_count", -1)) == EXPECTED_COMMANDS
		and int(contribution.get("mismatch_count", -1)) == 0
		and int(contribution.get("limiter_mismatch_count", -1)) == 0
		and int(contribution.get("inactive_zero_mismatch_count", -1)) == 0,
		"stability contributions reconcile to 12,112 bounded outputs",
	)

	var overlay: Dictionary = shadow.get("stability_overlay_summary", {})
	_check(
		int(shadow.get("native_actuation_application_count", -1)) == 0
		and int(shadow.get("native_safe_disable_application_count", -1)) == 0
		and int(overlay.get("application_step_count", -1)) == 0
		and int(overlay.get("motor_write_count", -1)) == 0
		and int(overlay.get("direct_body_write_count", -1)) == 0
		and int(summary.get("direct_torso_force_command_count", -1)) == 0
		and int(summary.get("direct_torso_impulse_command_count", -1)) == 0
		and int(summary.get("direct_torso_velocity_command_count", -1)) == 0
		and int(summary.get("direct_torso_transform_command_count", -1)) == 0,
		"shadow performs zero native motor, force, impulse, velocity, or transform writes",
	)
	_check(
		not bool(shadow.get("actuation_authority", true))
		and not bool(shadow.get("physical_acceptance_authority", true))
		and not bool(stability.get("physical_balance_recovery", true))
		and not bool(contribution.get("locomotion_robustness", true))
		and not bool(contribution.get("cross_engine_portable", true))
		and not bool(contribution.get("completed_sdk", true)),
		"BW1 retains every physical, robustness, cross-engine, and SDK-completion nonclaim",
	)
	print(
		"BALANCED_WAVE_BW1_RECEIPT ",
		JSON.stringify(
			{
				"schema_version": "sporespore_balanced_wave_bw1_shadow_receipt_v1",
				"ok": _failed == 0,
				"world_build_count": int(summary.get("world_build_count", 0)),
				"source_controller_policy_id":
				String(shadow.get("controller_policy_id", "")),
				"controller_profile_sha256":
				String(shadow.get("controller_profile_sha256", "")),
				"step_count": int(shadow.get("step_count", 0)),
				"validated_command_count":
				int(shadow.get("validated_balanced_wave_command_count", 0)),
				"step_receipt_count":
				int(shadow.get("balanced_wave_step_receipt_count", 0)),
				"stability_attempt_count": int(stability.get("attempt_count", 0)),
				"mapping_attempt_count": int(mapping.get("attempt_count", 0)),
				"contribution_attempt_count":
				int(contribution.get("attempt_count", 0)),
				"native_motor_write_count":
				int(shadow.get("native_actuation_application_count", 0)),
				"physical_acceptance_authority": false,
			},
			"",
			false,
			true,
		),
	)
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print(
		"\nSDK Godot/Jolt balanced-wave BW1 summary: %d passed, %d failed"
		% [_passed, _failed]
	)
	quit(0 if _failed == 0 else 1)
