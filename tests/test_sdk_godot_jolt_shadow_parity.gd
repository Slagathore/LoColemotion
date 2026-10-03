extends SceneTree

## One same-world Candidate 35 reference run with the native SDK in output-only
## shadow mode. The legacy GDScript controller retains all actuation authority.

const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const GaitClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")
const AdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")

const DESCRIPTOR := {
	"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
	"morphology_id": "godot_jolt_shadow_reference",
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
# The pure Rust/GDScript C1 oracle remains frozen at 1e-9. This physical C2
# mapping crosses Godot's binary32 real_t geometry boundary. A diagnostic run
# measured maxima of 2.0618e-9 rad position, 1.649443e-8 rad/s velocity after
# the controller's 8x gain, and 6.87268e-9 steering. The comparator ceiling is
# therefore frozen just above the observed velocity floor; the signal-specific
# assertions below remain tighter.
const CORE_C1_COMPARISON_TOLERANCE := 1.0e-9
const GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE := 2.0e-8
const MAXIMUM_POSITION_MAPPING_ERROR_RAD := 2.5e-9
const MAXIMUM_VELOCITY_MAPPING_ERROR_RAD_S := 2.0e-8
const MAXIMUM_STEERING_MAPPING_ERROR := 1.0e-8
const EXPECTED_CONTRIBUTION_ATTEMPTS := 1514
const EXPECTED_FULL_SUPPORT_ATTEMPTS := 821
const EXPECTED_PARTIAL_SUPPORT_ATTEMPTS := 627
const EXPECTED_UPSTREAM_INFEASIBLE_ATTEMPTS := 66
const EXPECTED_V3_AVAILABLE_ATTEMPTS := 1448
const EXPECTED_ORDERED_V3_COMMANDS := 11584
const EXPECTED_ACTIVE_SUPPORT_COMMANDS := 10330
const EXPECTED_INACTIVE_CONTACT_COMMANDS := 1254
const EXPECTED_INFLUENCE_OUTPUTS := 12112
const EXPECTED_FALLBACK_ZERO_OUTPUTS := 528
const MAPPING_TORQUE_TOLERANCE_NM := 5.0e-5
const LIMITER_RECONSTRUCTION_TOLERANCE := 5.0e-8
const SDK_SHADOW_OPTIONS := {
	"enabled": true,
	"descriptor": DESCRIPTOR,
	"comparison_tolerance": GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK Godot/Jolt Candidate 35 physical shadow parity ===")
	# These runtime settings are applied before the private fixture world exists.
	# The physical runner then verifies the exact realized 20/7 receipt.
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
	_check(
		bool(summary.get("physical_wave_gait_walking_observed", false)),
		"the unchanged legacy controller retains its physical walking gates",
	)
	_check(
		bool(summary.get("sdk_shadow_enabled", false)),
		"the report identifies native SDK shadow mode",
	)
	var start_result: Dictionary = summary.get("sdk_shadow_start_result", {})
	_check(
		bool(start_result.get("ok", false))
		and int(start_result.get("world_build_count", -1)) == 0
		and not bool(start_result.get("physical_acceptance_authority", true)),
		"the native adapter starts with no world or acceptance authority",
	)
	var shadow: Dictionary = summary.get("sdk_shadow_summary", {})
	if (
		not bool(summary.get("physical_wave_gait_walking_observed", false))
		or not bool(shadow.get("ok", false))
	):
		print(
			"SDK_SHADOW_FAILURE_DIAGNOSTIC ",
			{
				"legacy_failure_code": summary.get("failure_code", ""),
				"legacy_walking_gates": summary.get("walking_gate_receipts", {}),
				"maximum_anchor_error_m": summary.get("maximum_anchor_error_m", NAN),
				"maximum_hinge_axis_error_rad":
				summary.get("maximum_hinge_axis_error_rad", NAN),
				"shadow": shadow,
			},
		)
	var shadow_steps := int(shadow.get("step_count", 0))
	_check(
		bool(shadow.get("ok", false)) and shadow_steps >= 1080,
		"the SDK remains in parity for the complete same-world evidence gait",
	)
	_check(
		int(shadow.get("compared_actuator_command_count", -1)) == shadow_steps * 8,
		"every evidence step compares all eight ordered actuator commands",
	)
	_check(
		int(shadow.get("mismatch_count", -1)) == 0
		and int(shadow.get("safe_no_actuation_count", -1)) == 0,
		"the native controller has no dynamic parity or capability failures",
	)
	_check(
		(
			float(shadow.get("maximum_absolute_target_position_error_rad", INF))
			<= MAXIMUM_POSITION_MAPPING_ERROR_RAD
		)
		and (
			float(shadow.get("maximum_absolute_target_velocity_error_rad_s", INF))
			<= MAXIMUM_VELOCITY_MAPPING_ERROR_RAD_S
		)
		and (
			float(shadow.get("maximum_absolute_speed_limit_error_rad_s", INF))
			<= CORE_C1_COMPARISON_TOLERANCE
		),
		"target position, motor velocity, and speed-limit deltas stay within frozen bounds",
	)
	_check(
		int(shadow.get("maximum_absolute_phase_error_steps", -1)) == 0
		and (
			float(shadow.get("maximum_absolute_steering_error", INF))
			<= MAXIMUM_STEERING_MAPPING_ERROR
		),
		"contact-gated phase is exact and held path steering stays within its frozen bound",
	)
	_check(
		int(shadow.get("native_actuation_application_count", -1)) == 0
		and not bool(shadow.get("physical_acceptance_authority", true)),
		"shadow mode applies no native actuation and grants no physical authority",
	)
	var stability_shadow: Dictionary = shadow.get("stability_shadow_summary", {})
	if not bool(stability_shadow.get("ok", false)):
		print("SDK_STABILITY_SHADOW_FAILURE_DIAGNOSTIC ", stability_shadow)
	_check(
		bool(stability_shadow.get("ok", false))
		and int(stability_shadow.get("attempt_count", -1)) == shadow_steps
		and int(stability_shadow.get("available_count", -1)) == shadow_steps
		and int(stability_shadow.get("unavailable_count", -1)) == 0,
		"every same-world evidence step emits an available stability-v2 observation",
	)
	_check(
		int(stability_shadow.get("mismatch_count", -1)) == 0
		and (stability_shadow.get("failure_codes", []) as Array).is_empty(),
		"native and legacy stability observers have zero same-world mismatches",
	)
	var stability_errors: Dictionary = stability_shadow.get(
		"maximum_absolute_error_by_field",
		{},
	)
	var every_stability_error_bounded := not stability_errors.is_empty()
	for error_value in stability_errors.values():
		every_stability_error_bounded = (
			every_stability_error_bounded
			and float(error_value)
			<= float(stability_shadow["comparison_absolute_tolerance"])
		)
	_check(
		every_stability_error_bounded,
		"every portable stability signal stays inside the frozen shadow tolerance",
	)
	_check(
		not bool(stability_shadow.get("adapter_actuation_applied", true))
		and not bool(stability_shadow.get("physics_state_modified", true))
		and not bool(stability_shadow.get("physical_balance_recovery", true))
		and not bool(stability_shadow.get("physical_acceptance_authority", true)),
		"stability shadow retains zero actuation, recovery, and acceptance authority",
	)
	var mapping_shadow: Dictionary = shadow.get("joint_mapping_shadow_summary", {})
	if not bool(mapping_shadow.get("ok", false)):
		print("SDK_JOINT_MAPPING_SHADOW_FAILURE_DIAGNOSTIC ", mapping_shadow)
	_check(
		bool(mapping_shadow.get("ok", false))
		and int(mapping_shadow.get("attempt_count", 0)) > 0
		and int(mapping_shadow.get("available_count", 0)) > 0
		and (
			int(mapping_shadow.get("attempt_count", -1))
			== int(mapping_shadow.get("available_count", -2))
			+ int(mapping_shadow.get("unavailable_count", -2))
			+ int(mapping_shadow.get("infeasible_count", -2))
		),
		"the full gait records typed available, unavailable, and infeasible mapping outcomes",
	)
	_check(
		int(mapping_shadow.get("mismatch_count", -1)) == 0
		and (mapping_shadow.get("failure_codes", []) as Array).is_empty()
		and (
			int(mapping_shadow.get("compared_actuator_count", -1))
			== int(mapping_shadow.get("available_count", -1)) * 8
		),
		"every available map compares all eight actuators with zero mismatches",
	)
	_check(
		(
			float(mapping_shadow.get("maximum_absolute_torque_error_nm", INF))
			<= float(mapping_shadow.get("comparison_absolute_tolerance_nm", -INF))
		)
		and (
			float(mapping_shadow.get("maximum_absolute_commanded_torque_nm", 0.0))
			> float(mapping_shadow.get("nonzero_torque_threshold_nm", INF))
		),
		"live generalized torques are nonzero and remain inside the frozen oracle tolerance",
	)
	_check(
		not bool(mapping_shadow.get("actuator_response_characterized", true))
		and not bool(mapping_shadow.get("adapter_actuation_applied", true))
		and not bool(mapping_shadow.get("physics_state_modified", true))
		and not bool(mapping_shadow.get("physical_balance_recovery", true))
		and not bool(mapping_shadow.get("physical_acceptance_authority", true)),
		"mapping shadow retains zero host response, actuation, recovery, and authority claims",
	)
	var contribution: Dictionary = shadow.get(
		"stability_contribution_shadow_summary",
		{},
	)
	if not bool(contribution.get("ok", false)):
		print("SDK_STABILITY_CONTRIBUTION_FAILURE_DIAGNOSTIC ", contribution)
	_check(
		bool(contribution.get("ok", false))
		and int(contribution.get("attempt_count", -1))
		== EXPECTED_CONTRIBUTION_ATTEMPTS
		and int(contribution.get("full_support_attempt_count", -1))
		== EXPECTED_FULL_SUPPORT_ATTEMPTS
		and int(contribution.get("partial_support_attempt_count", -1))
		== EXPECTED_PARTIAL_SUPPORT_ATTEMPTS
		and int(contribution.get("available_count", -1))
		== EXPECTED_V3_AVAILABLE_ATTEMPTS
		and int(contribution.get("upstream_infeasible_count", -1))
		== EXPECTED_UPSTREAM_INFEASIBLE_ATTEMPTS
		and int(contribution.get("unavailable_count", -1)) == 0
		and int(contribution.get("untyped_count", -1)) == 0,
		"the frozen live attempt partition matches the retained P5I.1 segment",
	)
	_check(
		int(contribution.get("ordered_v3_command_count", -1))
		== EXPECTED_ORDERED_V3_COMMANDS
		and int(contribution.get("active_support_command_count", -1))
		== EXPECTED_ACTIVE_SUPPORT_COMMANDS
		and int(contribution.get("inactive_contact_command_count", -1))
		== EXPECTED_INACTIVE_CONTACT_COMMANDS
		and int(contribution.get("influence_output_count", -1))
		== EXPECTED_INFLUENCE_OUTPUTS
		and int(contribution.get("fallback_zero_output_count", -1))
		== EXPECTED_FALLBACK_ZERO_OUTPUTS,
		"all v3 commands and influence outputs match the frozen exact counts",
	)
	_check(
		int(mapping_shadow.get("available_count", -1))
		== EXPECTED_FULL_SUPPORT_ATTEMPTS
		and int(mapping_shadow.get("unavailable_count", -1))
		== EXPECTED_PARTIAL_SUPPORT_ATTEMPTS
		and int(mapping_shadow.get("infeasible_count", -1))
		== EXPECTED_UPSTREAM_INFEASIBLE_ATTEMPTS
		and int(contribution.get("full_v3_v2_compared_actuator_count", -1))
		== EXPECTED_FULL_SUPPORT_ATTEMPTS * 8,
		"v2 remains frozen while every full-support v3 actuator is compared",
	)
	_check(
		(
			float(
				contribution.get(
					"maximum_full_v3_v2_torque_error_nm",
					INF,
				)
			)
			<= MAPPING_TORQUE_TOLERANCE_NM
		)
		and (
			float(
				contribution.get(
					"maximum_active_oracle_torque_error_nm",
					INF,
				)
			)
			<= MAPPING_TORQUE_TOLERANCE_NM
		)
		and (
			is_finite(
				float(
					contribution.get(
						"maximum_absolute_commanded_torque_nm",
						NAN,
					)
				)
			)
		)
		and (
			float(
				contribution.get(
					"maximum_absolute_profile_input_torque_nm",
					INF,
				)
			)
			<= 0.2805286655276139
		)
		and (
			float(
				contribution.get(
					"maximum_absolute_commanded_torque_nm",
					0.0,
				)
			)
			> 1.0e-6
		)
		and int(contribution.get("profile_input_clamped_count", 0)) > 0
		and int(contribution.get("profile_conversion_failure_count", -1)) == 0,
		"raw v3 torque agrees with both comparators and its profile input is safely bounded",
	)
	_check(
		int(contribution.get("inactive_zero_mismatch_count", -1)) == 0
		and int(contribution.get("fallback_zero_output_count", -1))
		== EXPECTED_FALLBACK_ZERO_OUTPUTS
		and int(contribution.get("mismatch_count", -1)) == 0
		and (contribution.get("failure_codes", []) as Array).is_empty(),
		"inactive contacts and infeasible steps use explicit immediate fail-zero transitions",
	)
	_check(
		(
			float(
				contribution.get(
					"maximum_absolute_proposed_velocity_rad_s",
					INF,
				)
			)
			<= 0.07013216211209337
		)
		and (
			float(
				contribution.get(
					"maximum_absolute_applied_velocity_rad_s",
					INF,
				)
			)
			<= 0.075
		)
		and (
			float(
				contribution.get(
					"maximum_absolute_host_delta_rad_s",
					INF,
				)
			)
			<= 0.075
		)
		and int(contribution.get("magnitude_saturated_output_count", -1)) == 0,
		"proposed, bounded, and host contributions stay inside the frozen response envelope",
	)
	_check(
		int(contribution.get("nonzero_active_command_count", 0)) > 0
		and int(contribution.get("slew_limited_output_count", 0)) > 0
		and int(contribution.get("limiter_mismatch_count", -1)) == 0
		and (
			float(
				contribution.get(
					"maximum_limiter_reconstruction_error",
					INF,
				)
			)
			<= LIMITER_RECONSTRUCTION_TOLERANCE
		),
		"the live path is nontrivial and matches the independent stateful limiter reconstruction",
	)
	_check(
		String(contribution.get("schema_version", ""))
		== "sporespore_godot_jolt_stability_contribution_shadow_summary_v1"
		and not bool(contribution.get("adapter_actuation_applied", true))
		and not bool(contribution.get("physics_state_modified", true))
		and not bool(contribution.get("physical_balance_recovery", true))
		and not bool(contribution.get("locomotion_robustness", true))
		and not bool(contribution.get("cross_engine_portable", true))
		and not bool(contribution.get("physical_acceptance_authority", true))
		and not bool(contribution.get("completed_sdk", true)),
		"the contribution shadow retains every physical and completed-SDK nonclaim",
	)
	var manifest: Dictionary = shadow.get("adapter_manifest", {})
	var stability_manifest: Dictionary = manifest.get("stability_v2", {})
	var stability_v3_manifest: Dictionary = manifest.get("stability_v3", {})
	var contribution_manifest: Dictionary = stability_v3_manifest.get(
		"contribution_shadow",
		{},
	)
	var material_manifest: Dictionary = stability_manifest.get(
		"material_characterization",
		{},
	)
	var motor_response_manifest: Dictionary = stability_manifest.get(
		"host_motor_response_characterization",
		{},
	)
	var positive_velocity_map := (
		AdapterScript
		. characterized_host_velocity_delta_for_generalized_torque(
			0.2805286655276139,
		)
	)
	var negative_velocity_map := (
		AdapterScript
		. characterized_host_velocity_delta_for_generalized_torque(
			-0.2805286655276139,
		)
	)
	var excessive_velocity_map := (
		AdapterScript
		. characterized_host_velocity_delta_for_generalized_torque(
			0.2805286655276139 + 1.0e-6,
		)
	)
	var nonfinite_velocity_map := (
		AdapterScript
		. characterized_host_velocity_delta_for_generalized_torque(NAN)
	)
	_check(
		String(manifest.get("schema_version", ""))
		== "sporespore_godot_jolt_adapter_manifest_v14"
		and String(manifest.get("physics_engine", "")) == "Jolt Physics"
		and int(manifest.get("physics_hz", -1)) == 120
		and int(manifest.get("solver_velocity_steps", -1)) == 20
		and int(manifest.get("solver_position_steps", -1)) == 7
		and String(manifest.get("contact_quality", "")) == "qualified_bearing"
		and not bool(manifest.get("normal_load_available", true))
		and String(manifest.get("core_numeric_precision", "")) == "ieee754_binary64"
		and (
			String(manifest.get("host_geometry_numeric_precision", ""))
			== "godot_real_t_binary32"
		)
		and is_equal_approx(
			float(manifest.get("dynamic_mapping_comparison_tolerance", NAN)),
			GODOT_REAL_T_MAPPING_COMPARISON_TOLERANCE,
		)
		and String(stability_manifest.get("state_emission", ""))
		== "ordered_body_and_qualified_contact_state"
		and (
			String(stability_manifest.get("actuator_mapping", ""))
			== "portable_j_transpose_with_characterized_host_velocity_profile_shadow"
		)
		and (
			String(stability_manifest.get("partial_support_mapping", ""))
			== "typed_unavailable_v2"
		)
		and (
			String(stability_v3_manifest.get("partial_support_mapping", ""))
			== "portable_v3_exact_zero_shadow"
		)
		and (
			String(contribution_manifest.get("mapping_operation", ""))
			== "map_endpoint_force_to_joint_v3_json"
		)
		and (
			String(contribution_manifest.get("influence_operation", ""))
			== "bound_stability_influence_v2_json"
		)
		and (
			String(contribution_manifest.get("profile_input_policy", ""))
			== "clamp_raw_v3_torque_to_characterized_p5i2_envelope"
		)
		and absf(
			float(
				contribution_manifest.get(
					"maximum_velocity_delta_slew_per_step_rad_s",
					NAN,
				)
			)
			- 0.010
		)
		<= 1.0e-15
		and is_equal_approx(
			float(material_manifest.get("controller_friction_coefficient", NAN)),
			1.0,
		)
		and not bool(material_manifest.get("locomotion_robustness", true))
		and (
			String(motor_response_manifest.get("schema_version", ""))
			== "sporespore_godot_jolt_motor_response_profile_v1"
		)
		and (
			String(motor_response_manifest.get("source_commit", ""))
			== "c816ab36e4b696d8e8073fac88e6570242909609"
		)
		and (
			String(motor_response_manifest.get("report_sha256", ""))
			== "aec35f9c954a7d05755b43b2aa8474d81715aa7c71982d4209eb87fa40557729"
		)
		and absf(
			float(
				motor_response_manifest.get(
					"conservative_velocity_per_torque_rad_s_per_nm",
					NAN,
				)
			)
			- 0.24999998477941607
		)
		<= 1.0e-15
		and not bool(motor_response_manifest.get("stability_influence_applied", true))
		and not bool(motor_response_manifest.get("cross_engine_portable", true))
		and bool(positive_velocity_map.get("ok", false))
		and bool(negative_velocity_map.get("ok", false))
		and absf(
			float(positive_velocity_map.get("canonical_velocity_delta_rad_s", NAN))
			- 0.07013216211209337
		)
		<= 1.0e-15
		and absf(
			float(positive_velocity_map.get("host_target_velocity_delta_rad_s", NAN))
			+ 0.07013216211209337
		)
		<= 1.0e-15
		and absf(
			float(negative_velocity_map.get("canonical_velocity_delta_rad_s", NAN))
			+ 0.07013216211209337
		)
		<= 1.0e-15
		and not bool(excessive_velocity_map.get("ok", true))
		and not bool(nonfinite_velocity_map.get("ok", true))
		and not bool(positive_velocity_map.get("adapter_actuation_applied", true))
		and not bool(positive_velocity_map.get("physics_state_modified", true))
		and not bool(stability_manifest.get("actuation_authority", true)),
		"the manifest freezes Jolt, material, motor-response, and shadow-only mapping semantics",
	)
	print(
		"SDK_STABILITY_SHADOW_RECEIPT ",
		JSON.stringify(
			{
				"schema_version":
				"sporespore_godot_jolt_stability_contribution_shadow_receipt_v1",
				"ok":
				(
					_failed == 0
					and bool(stability_shadow.get("ok", false))
					and bool(contribution.get("ok", false))
					and bool(summary.get("physical_wave_gait_walking_observed", false))
				),
				"world_build_count": int(summary.get("world_build_count", -1)),
				"legacy_candidate35_walking_gates_passed":
				bool(summary.get("physical_wave_gait_walking_observed", false)),
				"candidate35_shadow_step_count": shadow_steps,
				"candidate35_compared_actuator_command_count":
				int(shadow.get("compared_actuator_command_count", -1)),
				"candidate35_mismatch_count": int(shadow.get("mismatch_count", -1)),
				"candidate35_native_actuation_application_count":
				int(shadow.get("native_actuation_application_count", -1)),
				"stability_shadow": stability_shadow,
				"joint_mapping_shadow": mapping_shadow,
				"stability_contribution_shadow": contribution,
				"adapter_manifest": manifest,
				"adapter_capability_sha256":
				String(shadow.get("adapter_capability_sha256", "")),
				"stability_adapter_actuation_applied": false,
				"stability_physics_state_modified": false,
				"physical_balance_recovery": false,
				"friction_material_robustness": false,
				"physical_acceptance_authority": false,
			},
			"",
			true,
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
	print("\nSDK Godot/Jolt shadow summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
