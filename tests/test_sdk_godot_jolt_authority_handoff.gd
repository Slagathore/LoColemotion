extends SceneTree

## One same-world Candidate 35 run where legacy GDScript establishes the
## warmup, then the native SDK exclusively commands all eight hinge motors for
## the complete registered evidence horizon. Legacy calculations remain a
## non-actuating parity observer during that horizon.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const GaitClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")

const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "godot_jolt_authority_handoff_reference",
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
const SDK_AUTHORITY_OPTIONS := {
	"enabled": true,
	"descriptor": DESCRIPTOR,
	"comparison_tolerance": GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
	"authority_scope": "evidence_handoff",
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK Godot/Jolt Candidate 35 native authority handoff ===")
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
			{},
			SDK_AUTHORITY_OPTIONS,
		)
	)
	var authority: Dictionary = summary.get("sdk_authority_summary", {})
	if (
		not bool(summary.get("physical_wave_gait_walking_observed", false))
		or not bool(authority.get("ok", false))
	):
		print(
			"SDK_AUTHORITY_FAILURE_DIAGNOSTIC ",
			{
				"failure_code": summary.get("failure_code", ""),
				"walking_gates": summary.get("walking_gate_receipts", {}),
				"authority_failure_code": summary.get("sdk_authority_failure_code", ""),
				"last_application": summary.get("sdk_authority_last_application_result", {}),
				"maximum_anchor_error_m": summary.get("maximum_anchor_error_m", NAN),
				"maximum_hinge_axis_error_rad":
				summary.get("maximum_hinge_axis_error_rad", NAN),
				"authority": authority,
			},
		)
	_check(int(summary.get("world_build_count", 0)) == 1, "one private Jolt world executes")
	_check(
		bool(summary.get("sdk_authority_enabled", false))
		and String(summary.get("sdk_authority_scope", ""))
		== "evidence_handoff",
		"the report identifies the bounded native-authority handoff",
	)
	var start_result: Dictionary = summary.get("sdk_authority_start_result", {})
	_check(
		bool(start_result.get("ok", false))
		and bool(start_result.get("actuation_authority", false))
		and not bool(start_result.get("physical_acceptance_authority", true)),
		"the adapter receives motor authority without inventing physical acceptance",
	)
	var authority_steps := int(authority.get("step_count", 0))
	_check(
		bool(authority.get("ok", false)) and authority_steps >= 1080,
		"native authority spans the complete same-world evidence gait",
	)
	_check(
		int(authority.get("compared_actuator_command_count", -1)) == authority_steps * 8
		and int(authority.get("native_actuation_application_count", -1)) == authority_steps * 8,
		"every native evidence frame compares and applies all eight commands",
	)
	_check(
		int(summary.get("legacy_evidence_actuation_application_count", -1)) == 0,
		"legacy GDScript applies no motor command during native authority",
	)
	_check(
		int(authority.get("mismatch_count", -1)) == 0
		and int(authority.get("safe_no_actuation_count", -1)) == 0
		and int(authority.get("native_safe_disable_application_count", -1)) == 0
		and int(authority.get("maximum_absolute_phase_error_steps", -1)) == 0,
		"native authority has exact phase and no parity, safety, or disable failure",
	)
	var manifest: Dictionary = authority.get("adapter_manifest", {})
	_check(
		String(manifest.get("execution_mode", "")) == "native_authority_with_legacy_observer"
		and bool(manifest.get("actuation_authority", false))
		and not bool(manifest.get("shadow_mode", true))
		and is_equal_approx(
			float(manifest.get("dynamic_mapping_comparison_tolerance", NAN)),
			GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
		),
		"the capability hash distinguishes native authority from shadow mode",
	)
	_check(
		bool(
			(summary.get("walking_gate_receipts", {}) as Dictionary).get(
				"native_sdk_exclusive_evidence_actuation",
				false,
			)
		)
		and bool(summary.get("physical_wave_gait_walking_observed", false)),
		"native-exclusive evidence actuation and every physical walking gate pass together",
	)
	_check(
		not bool(summary.get("formal_milestone_acceptance_authorized", true))
		and not bool(summary.get("encyclopedia_admission_authorized", true)),
		"the development handoff run grants no formal or knowledge authority",
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
	print("\nSDK Godot/Jolt authority summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
