extends SceneTree
# gdlint: disable=max-line-length
# gdlint: disable=max-returns
# gdlint: disable=max-file-lines

## G1 development-only torso-mass probe. A declared cell varies only torso
## mass in the normalized physical fixture. Each preregistered evidence family
## fixes one controller configuration across the complete mass grid. Walking
## failure is a measured outcome, not a test-harness failure.

const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const FIXTURE_AXIS_TORSO_MASS := "torso_mass"
const FIXTURE_AXIS_SYMMETRIC_UPPER_MASS := "symmetric_upper_mass"
const FIXTURE_AXIS_IDS := [
	FIXTURE_AXIS_TORSO_MASS,
	FIXTURE_AXIS_SYMMETRIC_UPPER_MASS,
]
const DECLARED_TORSO_MASS_CELLS_KG := [
	2.40,
	2.70,
	3.00,
	3.05,
	3.10,
	3.15,
	3.20,
	3.25,
	3.30,
	3.40,
	3.60,
]
const DECLARED_SYMMETRIC_UPPER_MASS_CELLS_KG := [
	0.2000,
	0.2125,
	0.2250,
	0.2500,
	0.2625,
	0.2750,
	0.2875,
	0.3000,
]
const REFERENCE_TORSO_MASS_KG := 3.00
const REFERENCE_UPPER_MASS_KG := 0.25
const EXPECTED_REFERENCE_FIXTURE_DIGEST := "sha256:18361994a68e2a9a150aa539aff39679ba4b6e892092e26d218b08f6e12e9c3b"
const EXPECTED_LOCKED_S2B_CONTROLLER_DIGEST := "sha256:7478184503ca25fe591675afdee7366615e885763ecb0ed0e57e0bf82a3445cc"
const CONTROLLER_FAMILY_TM1 := "tm1_contact_gated"
const CONTROLLER_FAMILY_TM2 := "tm2_exact_reference"
const CONTROLLER_FAMILY_TC1_GAIN_005 := "tc1_gain_005"
const CONTROLLER_FAMILY_TC1_GAIN_010 := "tc1_gain_010"
const CONTROLLER_FAMILY_TC1_GAIN_015 := "tc1_gain_015"
const CONTROLLER_FAMILY_TC1_GAIN_020 := "tc1_gain_020"
const CONTROLLER_FAMILY_TC1_GAIN_025 := "tc1_gain_025"
const CONTROLLER_FAMILY_TC2 := "tc2_linear_mass_adaptive"
const CONTROLLER_FAMILY_S1_A := "s1_path_a"
const CONTROLLER_FAMILY_S1_B := "s1_path_b"
const CONTROLLER_FAMILY_S1_C := "s1_path_c"
const CONTROLLER_FAMILY_S1_D := "s1_path_d"
const CONTROLLER_FAMILY_S2_A := "s2_gated_path_a"
const CONTROLLER_FAMILY_S2_B := "s2_gated_path_b"
const CONTROLLER_FAMILY_S2_C := "s2_gated_path_c"
const CONTROLLER_FAMILY_S2_D := "s2_gated_path_d"
const CONTROLLER_FAMILY_UM2_A := "um2_adaptive_actuator_a"
const CONTROLLER_FAMILY_UM2_B := "um2_adaptive_actuator_b"
const CONTROLLER_FAMILY_UM2_C := "um2_adaptive_actuator_c"
const CONTROLLER_FAMILY_UM3_A := "um3_joint_specific_actuator_a"
const CONTROLLER_FAMILY_UM3_B := "um3_joint_specific_actuator_b"
const CONTROLLER_FAMILY_UM3_C := "um3_joint_specific_actuator_c"
const CONTROLLER_FAMILY_UM4_A := "um4_bidirectional_knee_attenuation_a"
const CONTROLLER_FAMILY_UM4_B := "um4_bidirectional_knee_attenuation_b"
const CONTROLLER_FAMILY_UM4_C := "um4_bidirectional_knee_attenuation_c"
const CONTROLLER_FAMILY_UM5_A := "um5_bidirectional_dual_attenuation_a"
const CONTROLLER_FAMILY_UM5_B := "um5_bidirectional_dual_attenuation_b"
const CONTROLLER_FAMILY_UM5_C := "um5_bidirectional_dual_attenuation_c"
const CONTROLLER_FAMILY_UM6_A := "um6_heavy_knee_trajectory_a"
const CONTROLLER_FAMILY_UM6_B := "um6_heavy_knee_trajectory_b"
const CONTROLLER_FAMILY_UM6_C := "um6_heavy_knee_trajectory_c"
const CONTROLLER_FAMILY_UM7_A := "um7_heavy_swing_timing_a"
const CONTROLLER_FAMILY_UM7_B := "um7_heavy_swing_timing_b"
const CONTROLLER_FAMILY_UM7_C := "um7_heavy_swing_timing_c"
const CONTROLLER_FAMILY_UM8_A := "um8_contact_loaded_knee_rate_a"
const CONTROLLER_FAMILY_UM8_B := "um8_contact_loaded_knee_rate_b"
const CONTROLLER_FAMILY_UM8_C := "um8_contact_loaded_knee_rate_c"
const CONTROLLER_FAMILY_UM9_A := "um9_post_release_loaded_knee_rate_a"
const CONTROLLER_FAMILY_UM9_B := "um9_post_release_loaded_knee_rate_b"
const CONTROLLER_FAMILY_UM9_C := "um9_post_release_loaded_knee_rate_c"
const CONTROLLER_FAMILY_UM10_A := "um10_release_gate_notch_a"
const CONTROLLER_FAMILY_UM10_B := "um10_release_gate_notch_b"
const CONTROLLER_FAMILY_UM10_C := "um10_release_gate_notch_c"
const CONTROLLER_FAMILY_IDS := [
	CONTROLLER_FAMILY_TM1,
	CONTROLLER_FAMILY_TM2,
	CONTROLLER_FAMILY_TC1_GAIN_005,
	CONTROLLER_FAMILY_TC1_GAIN_010,
	CONTROLLER_FAMILY_TC1_GAIN_015,
	CONTROLLER_FAMILY_TC1_GAIN_020,
	CONTROLLER_FAMILY_TC1_GAIN_025,
	CONTROLLER_FAMILY_TC2,
	CONTROLLER_FAMILY_S1_A,
	CONTROLLER_FAMILY_S1_B,
	CONTROLLER_FAMILY_S1_C,
	CONTROLLER_FAMILY_S1_D,
	CONTROLLER_FAMILY_S2_A,
	CONTROLLER_FAMILY_S2_B,
	CONTROLLER_FAMILY_S2_C,
	CONTROLLER_FAMILY_S2_D,
	CONTROLLER_FAMILY_UM2_A,
	CONTROLLER_FAMILY_UM2_B,
	CONTROLLER_FAMILY_UM2_C,
	CONTROLLER_FAMILY_UM3_A,
	CONTROLLER_FAMILY_UM3_B,
	CONTROLLER_FAMILY_UM3_C,
	CONTROLLER_FAMILY_UM4_A,
	CONTROLLER_FAMILY_UM4_B,
	CONTROLLER_FAMILY_UM4_C,
	CONTROLLER_FAMILY_UM5_A,
	CONTROLLER_FAMILY_UM5_B,
	CONTROLLER_FAMILY_UM5_C,
	CONTROLLER_FAMILY_UM6_A,
	CONTROLLER_FAMILY_UM6_B,
	CONTROLLER_FAMILY_UM6_C,
	CONTROLLER_FAMILY_UM7_A,
	CONTROLLER_FAMILY_UM7_B,
	CONTROLLER_FAMILY_UM7_C,
	CONTROLLER_FAMILY_UM8_A,
	CONTROLLER_FAMILY_UM8_B,
	CONTROLLER_FAMILY_UM8_C,
	CONTROLLER_FAMILY_UM9_A,
	CONTROLLER_FAMILY_UM9_B,
	CONTROLLER_FAMILY_UM9_C,
	CONTROLLER_FAMILY_UM10_A,
	CONTROLLER_FAMILY_UM10_B,
	CONTROLLER_FAMILY_UM10_C,
]
const TM1_REQUESTED_ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 96,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.5,
}
const TM2_REQUESTED_ROBUSTNESS_OPTIONS := {}
const TM2_NORMALIZED_ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": false,
	"maximum_contact_gate_hold_ticks": 48,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const S2_REQUESTED_ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 96,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Experimental BR14A.7 native-controller single-mass-axis probe ===")
	var user_args := OS.get_cmdline_user_args()
	if user_args.is_empty():
		_check(
			true,
			"mass-axis probing remains explicit campaign-only without a supplied cell",
		)
		_finish()
		return
	_check(
		user_args.size() == 2 or user_args.size() == 3,
		"one mass cell, one controller family, and an optional variation axis are supplied",
	)
	if user_args.size() != 2 and user_args.size() != 3:
		_finish()
		return
	var requested_mass_kg := String(user_args[0]).to_float()
	var controller_family_id := String(user_args[1])
	var fixture_variation_axis := (
		String(user_args[2]) if user_args.size() == 3 else FIXTURE_AXIS_TORSO_MASS
	)
	var declared_axis_and_mass := (
		FIXTURE_AXIS_IDS.has(fixture_variation_axis)
		and _is_declared_mass(fixture_variation_axis, requested_mass_kg)
	)
	_check(
		declared_axis_and_mass,
		"requested mass belongs to the axis-specific preregistered cell grid",
	)
	if not declared_axis_and_mass:
		_finish()
		return
	_check(
		(
			CONTROLLER_FAMILY_IDS.has(controller_family_id)
			and (
				(
					controller_family_id == CONTROLLER_FAMILY_S2_B
					or _is_upper_mass_adaptive_controller_family(controller_family_id)
				)
				if fixture_variation_axis == FIXTURE_AXIS_SYMMETRIC_UPPER_MASS
				else not _is_upper_mass_adaptive_controller_family(controller_family_id)
			)
		),
		"controller evidence family and mass-axis pairing are explicitly preregistered",
	)
	if (
		not CONTROLLER_FAMILY_IDS.has(controller_family_id)
		or (
			fixture_variation_axis == FIXTURE_AXIS_SYMMETRIC_UPPER_MASS
			and (
				controller_family_id != CONTROLLER_FAMILY_S2_B
				and not _is_upper_mass_adaptive_controller_family(controller_family_id)
			)
		)
		or (
			fixture_variation_axis == FIXTURE_AXIS_TORSO_MASS
			and _is_upper_mass_adaptive_controller_family(controller_family_id)
		)
	):
		_finish()
		return
	var controller_family_configuration := _controller_family_configuration(
		controller_family_id,
		requested_mass_kg,
	)
	var requested_robustness_options: Dictionary = controller_family_configuration["requested"]
	var expected_normalized_robustness_options: Dictionary = controller_family_configuration["normalized"]
	var requested_path_steering_options: Dictionary = controller_family_configuration["path_steering"]
	var requested_actuator_impulse_options: Dictionary = controller_family_configuration["actuator"]
	var requested_motor_velocity_options: Dictionary = controller_family_configuration.get(
		"motor_velocity", {}
	)
	var expected_normalized_motor_velocity_options := {
		"mass_adaptive_motor_velocity_enabled":
		bool(requested_motor_velocity_options.get("mass_adaptive_motor_velocity_enabled", false)),
		"motor_velocity_policy_id":
		String(requested_motor_velocity_options.get("motor_velocity_policy_id", "none")),
		"activation_predicate_id":
		(
			"release_gate_notched_contact_loaded_swing_knee"
			if (
				int(
					(
						requested_motor_velocity_options
						. get(
							"contact_loaded_swing_knee_full_speed_override_phase_tick",
							-1,
						)
					)
				)
				>= 0
			)
			else (
				"phase_windowed_contact_loaded_swing_knee"
				if (
					int(
						(
							requested_motor_velocity_options
							. get(
								"contact_loaded_swing_knee_activation_start_phase_tick",
								0,
							)
						)
					)
					> 0
				)
				else "contact_loaded_swing_knee"
			)
		),
		"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s":
		float(
			(
				requested_motor_velocity_options
				. get(
					"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s",
					3.5,
				)
			)
		),
		"contact_loaded_swing_knee_activation_start_phase_tick":
		int(
			(
				requested_motor_velocity_options
				. get(
					"contact_loaded_swing_knee_activation_start_phase_tick",
					0,
				)
			)
		),
		"contact_loaded_swing_knee_full_speed_override_phase_tick":
		int(
			(
				requested_motor_velocity_options
				. get(
					"contact_loaded_swing_knee_full_speed_override_phase_tick",
					-1,
				)
			)
		),
	}
	var requested_knee_flexion_scale := float(
		controller_family_configuration.get("knee_flexion_scale", 1.75)
	)
	var requested_swing_ticks := int(controller_family_configuration.get("swing_ticks", 72))
	var controller_policy_receipt := _controller_policy_receipt(controller_family_id)
	var controller_policy_digest := (
		CanonicalJsonScript.sha256(controller_policy_receipt)
		if (
			controller_family_id == CONTROLLER_FAMILY_TC2
			or _is_upper_mass_adaptive_controller_family(controller_family_id)
		)
		else "none"
	)
	if controller_family_id == CONTROLLER_FAMILY_TC2:
		_check(
			(
				(
					String(controller_policy_receipt.get("schema_version", ""))
					== "sporespore_linear_mass_adaptive_lateral_steering_policy_v1"
				)
				and is_equal_approx(
					float(controller_policy_receipt.get("slope_per_m_per_kg", NAN)),
					1.0 / 3.0,
				)
				and String(controller_policy_digest).begins_with("sha256:")
				and String(controller_policy_digest).length() == 71
			),
			"mass-adaptive steering policy receipt is exact and canonically digested",
		)
	var um2_policy_exact := true
	if _is_um2_controller_family(controller_family_id):
		um2_policy_exact = (
			(
				String(controller_policy_receipt.get("schema_version", ""))
				== "sporespore_upper_mass_adaptive_actuator_policy_v1"
			)
			and float(controller_policy_receipt.get("minimum_impulse_scale", NAN)) == 0.80
			and float(controller_policy_receipt.get("maximum_impulse_scale", NAN)) == 1.25
			and String(controller_policy_digest).begins_with("sha256:")
			and String(controller_policy_digest).length() == 71
		)
		if not um2_policy_exact:
			printerr("  invalid_um2_policy_receipt=", controller_policy_receipt)
	var um3_policy_exact := true
	if _is_um3_controller_family(controller_family_id):
		um3_policy_exact = (
			(
				String(controller_policy_receipt.get("schema_version", ""))
				== "sporespore_upper_mass_joint_specific_actuator_policy_v1"
			)
			and float(controller_policy_receipt.get("minimum_impulse_scale", NAN)) == 0.80
			and float(controller_policy_receipt.get("maximum_impulse_scale", NAN)) == 1.25
			and float(controller_policy_receipt.get("knee_exponent", NAN)) == 0.0
			and float(controller_policy_receipt.get("fixed_knee_impulse_scale", NAN)) == 1.0
			and controller_policy_receipt.get("affected_joint_roles", []) == ["hip_pitch"]
			and String(controller_policy_digest).begins_with("sha256:")
			and String(controller_policy_digest).length() == 71
		)
		if not um3_policy_exact:
			printerr("  invalid_um3_policy_receipt=", controller_policy_receipt)
	var um4_policy_exact := true
	if _is_um4_controller_family(controller_family_id):
		um4_policy_exact = (
			(
				String(controller_policy_receipt.get("schema_version", ""))
				== "sporespore_upper_mass_bidirectional_knee_attenuation_policy_v1"
			)
			and float(controller_policy_receipt.get("hip_exponent", NAN)) == 0.5
			and (
				float(controller_policy_receipt.get("knee_exponent", NAN))
				== _um4_knee_exponent(controller_family_id)
			)
			and float(controller_policy_receipt.get("minimum_impulse_scale", NAN)) == 0.80
			and float(controller_policy_receipt.get("maximum_hip_impulse_scale", NAN)) == 1.25
			and float(controller_policy_receipt.get("maximum_knee_impulse_scale", NAN)) == 1.0
			and (
				controller_policy_receipt.get("affected_joint_roles", [])
				== ["hip_pitch", "knee_pitch"]
			)
			and (
				String(controller_policy_receipt.get("mass_ratio_formula", ""))
				== "(upper_mass_kg + 0.18) / (0.25 + 0.18)"
			)
			and (
				String(controller_policy_receipt.get("hip_scale_formula", ""))
				== "clamp(pow(mass_ratio, 0.5), 0.80, 1.25)"
			)
			and (
				String(controller_policy_receipt.get("knee_attenuation_ratio_formula", ""))
				== "min(mass_ratio, 1.0 / mass_ratio)"
			)
			and (
				String(controller_policy_receipt.get("knee_scale_formula", ""))
				== "clamp(pow(knee_attenuation_ratio, knee_exponent), 0.80, 1.0)"
			)
			and String(controller_policy_digest).begins_with("sha256:")
			and String(controller_policy_digest).length() == 71
		)
		if not um4_policy_exact:
			printerr("  invalid_um4_policy_receipt=", controller_policy_receipt)
	var um5_policy_exact := true
	if _is_um5_controller_family(controller_family_id):
		um5_policy_exact = (
			(
				String(controller_policy_receipt.get("schema_version", ""))
				== "sporespore_upper_mass_bidirectional_dual_attenuation_policy_v1"
			)
			and (
				float(controller_policy_receipt.get("hip_exponent", NAN))
				== _um5_hip_exponent(controller_family_id)
			)
			and float(controller_policy_receipt.get("knee_exponent", NAN)) == 0.5
			and float(controller_policy_receipt.get("minimum_impulse_scale", NAN)) == 0.80
			and float(controller_policy_receipt.get("maximum_impulse_scale", NAN)) == 1.0
			and (
				controller_policy_receipt.get("affected_joint_roles", [])
				== ["hip_pitch", "knee_pitch"]
			)
			and (
				String(controller_policy_receipt.get("mass_ratio_formula", ""))
				== "(upper_mass_kg + 0.18) / (0.25 + 0.18)"
			)
			and (
				String(controller_policy_receipt.get("attenuation_ratio_formula", ""))
				== "min(mass_ratio, 1.0 / mass_ratio)"
			)
			and (
				String(controller_policy_receipt.get("hip_scale_formula", ""))
				== "clamp(pow(attenuation_ratio, hip_exponent), 0.80, 1.0)"
			)
			and (
				String(controller_policy_receipt.get("knee_scale_formula", ""))
				== "clamp(pow(attenuation_ratio, 0.5), 0.80, 1.0)"
			)
			and String(controller_policy_digest).begins_with("sha256:")
			and String(controller_policy_digest).length() == 71
		)
		if not um5_policy_exact:
			printerr("  invalid_um5_policy_receipt=", controller_policy_receipt)
	var um6_policy_exact := true
	if _is_um6_controller_family(controller_family_id):
		um6_policy_exact = (
			(
				String(controller_policy_receipt.get("schema_version", ""))
				== "sporespore_upper_mass_heavy_knee_trajectory_policy_v1"
			)
			and float(controller_policy_receipt.get("hip_exponent", NAN)) == 1.0
			and float(controller_policy_receipt.get("knee_exponent", NAN)) == 0.5
			and float(controller_policy_receipt.get("reference_upper_mass_kg", NAN)) == 0.25
			and float(controller_policy_receipt.get("fixed_distal_mass_kg", NAN)) == 0.18
			and float(controller_policy_receipt.get("minimum_impulse_scale", NAN)) == 0.80
			and float(controller_policy_receipt.get("maximum_impulse_scale", NAN)) == 1.0
			and float(controller_policy_receipt.get("hip_base_max_impulse_nms", NAN)) == 0.055
			and float(controller_policy_receipt.get("knee_base_max_impulse_nms", NAN)) == 0.045
			and float(controller_policy_receipt.get("knee_motor_impulse_scale", NAN)) == 10.0
			and float(controller_policy_receipt.get("light_side_knee_flexion_scale", NAN)) == 1.75
			and (
				float(controller_policy_receipt.get("heavy_endpoint_knee_flexion_scale", NAN))
				== _um6_endpoint_knee_flexion_scale(controller_family_id)
			)
			and float(controller_policy_receipt.get("heavy_ramp_start_upper_mass_kg", NAN)) == 0.25
			and float(controller_policy_receipt.get("heavy_ramp_end_upper_mass_kg", NAN)) == 0.30
			and float(controller_policy_receipt.get("contact_clearance_assist_rad", NAN)) == 0.40
			and (
				controller_policy_receipt.get("actuator_affected_joint_roles", [])
				== ["hip_pitch", "knee_pitch"]
			)
			and (
				controller_policy_receipt.get("trajectory_affected_joint_roles", [])
				== ["knee_pitch"]
			)
			and (
				String(controller_policy_receipt.get("mass_ratio_formula", ""))
				== "(upper_mass_kg + 0.18) / (0.25 + 0.18)"
			)
			and (
				String(controller_policy_receipt.get("attenuation_ratio_formula", ""))
				== "min(mass_ratio, 1.0 / mass_ratio)"
			)
			and (
				String(controller_policy_receipt.get("hip_scale_formula", ""))
				== "clamp(pow(attenuation_ratio, 1.0), 0.80, 1.0)"
			)
			and (
				String(controller_policy_receipt.get("knee_scale_formula", ""))
				== "clamp(pow(attenuation_ratio, 0.5), 0.80, 1.0)"
			)
			and (
				String(controller_policy_receipt.get("heavy_fraction_formula", ""))
				== "clamp((upper_mass_kg - 0.25) / (0.30 - 0.25), 0.0, 1.0)"
			)
			and (
				String(controller_policy_receipt.get("knee_flexion_scale_formula", ""))
				== "lerp(1.75, heavy_endpoint_knee_flexion_scale, heavy_fraction)"
			)
			and String(controller_policy_digest).begins_with("sha256:")
			and String(controller_policy_digest).length() == 71
		)
		if not um6_policy_exact:
			printerr("  invalid_um6_policy_receipt=", controller_policy_receipt)
	var um7_policy_exact := true
	if _is_um7_controller_family(controller_family_id):
		um7_policy_exact = (
			(
				String(controller_policy_receipt.get("schema_version", ""))
				== "sporespore_upper_mass_heavy_swing_timing_policy_v1"
			)
			and float(controller_policy_receipt.get("hip_exponent", NAN)) == 1.0
			and float(controller_policy_receipt.get("knee_exponent", NAN)) == 0.5
			and float(controller_policy_receipt.get("reference_upper_mass_kg", NAN)) == 0.25
			and float(controller_policy_receipt.get("fixed_distal_mass_kg", NAN)) == 0.18
			and float(controller_policy_receipt.get("minimum_impulse_scale", NAN)) == 0.80
			and float(controller_policy_receipt.get("maximum_impulse_scale", NAN)) == 1.0
			and float(controller_policy_receipt.get("light_side_knee_flexion_scale", NAN)) == 1.75
			and (
				float(controller_policy_receipt.get("heavy_endpoint_knee_flexion_scale", NAN))
				== 1.30
			)
			and int(controller_policy_receipt.get("light_side_swing_ticks", -1)) == 72
			and (
				int(controller_policy_receipt.get("heavy_endpoint_swing_ticks", -1))
				== _um7_endpoint_swing_ticks(controller_family_id)
			)
			and (
				String(controller_policy_receipt.get("heavy_fraction_formula", ""))
				== "clamp((upper_mass_kg - 0.25) / (0.30 - 0.25), 0.0, 1.0)"
			)
			and (
				String(controller_policy_receipt.get("knee_flexion_scale_formula", ""))
				== "lerp(1.75, 1.30, heavy_fraction)"
			)
			and (
				String(controller_policy_receipt.get("swing_ticks_formula", ""))
				== "round(lerp(72, heavy_endpoint_swing_ticks, heavy_fraction))"
			)
			and (
				String(controller_policy_receipt.get("release_gate_tick_formula", ""))
				== "floor(realized_swing_ticks * 3 / 4)"
			)
			and (
				String(controller_policy_receipt.get("recontact_gate_tick_formula", ""))
				== "realized_swing_ticks + floor((360 - realized_swing_ticks) / 4)"
			)
			and String(controller_policy_digest).begins_with("sha256:")
			and String(controller_policy_digest).length() == 71
		)
		if not um7_policy_exact:
			printerr("  invalid_um7_policy_receipt=", controller_policy_receipt)
	var um8_policy_exact := true
	if _is_um8_controller_family(controller_family_id):
		um8_policy_exact = (
			(
				String(controller_policy_receipt.get("schema_version", ""))
				== "sporespore_upper_mass_contact_loaded_swing_knee_rate_policy_v1"
			)
			and float(controller_policy_receipt.get("hip_exponent", NAN)) == 1.0
			and float(controller_policy_receipt.get("knee_exponent", NAN)) == 0.5
			and float(controller_policy_receipt.get("reference_upper_mass_kg", NAN)) == 0.25
			and float(controller_policy_receipt.get("fixed_distal_mass_kg", NAN)) == 0.18
			and float(controller_policy_receipt.get("minimum_impulse_scale", NAN)) == 0.80
			and float(controller_policy_receipt.get("maximum_impulse_scale", NAN)) == 1.0
			and float(controller_policy_receipt.get("reference_knee_flexion_scale", NAN)) == 1.75
			and (
				float(controller_policy_receipt.get("heavy_endpoint_knee_flexion_scale", NAN))
				== 1.30
			)
			and int(controller_policy_receipt.get("reference_swing_ticks", -1)) == 72
			and int(controller_policy_receipt.get("heavy_endpoint_swing_ticks", -1)) == 60
			and float(controller_policy_receipt.get("reference_speed_rad_s", NAN)) == 3.5
			and (
				float(controller_policy_receipt.get("heavy_endpoint_speed_rad_s", NAN))
				== _um8_endpoint_speed_rad_s(controller_family_id)
			)
			and (
				String(controller_policy_receipt.get("activation_predicate_id", ""))
				== "contact_loaded_swing_knee"
			)
			and (
				controller_policy_receipt.get("activation_predicate_conditions", [])
				== [
					"joint_role == knee_pitch",
					"local_phase_tick < realized_swing_ticks",
					"foot_bears_floor == true",
					"upper_mass_kg > 0.250",
				]
			)
			and (
				String(controller_policy_receipt.get("heavy_fraction_formula", ""))
				== "clamp((upper_mass_kg - 0.25) / (0.30 - 0.25), 0.0, 1.0)"
			)
			and (
				String(controller_policy_receipt.get("knee_flexion_scale_formula", ""))
				== "lerp(1.75, 1.30, heavy_fraction)"
			)
			and (
				String(controller_policy_receipt.get("swing_ticks_formula", ""))
				== "round(lerp(72, 60, heavy_fraction))"
			)
			and (
				String(controller_policy_receipt.get("speed_formula", ""))
				== "lerp(3.5, heavy_endpoint_speed_rad_s, heavy_fraction)"
			)
			and String(controller_policy_digest).begins_with("sha256:")
			and String(controller_policy_digest).length() == 71
		)
		if not um8_policy_exact:
			printerr("  invalid_um8_policy_receipt=", controller_policy_receipt)
	var um9_policy_exact := true
	if _is_um9_controller_family(controller_family_id):
		um9_policy_exact = (
			(
				String(controller_policy_receipt.get("schema_version", ""))
				== "sporespore_upper_mass_post_release_loaded_knee_rate_policy_v1"
			)
			and float(controller_policy_receipt.get("hip_exponent", NAN)) == 1.0
			and float(controller_policy_receipt.get("knee_exponent", NAN)) == 0.5
			and float(controller_policy_receipt.get("reference_upper_mass_kg", NAN)) == 0.25
			and float(controller_policy_receipt.get("fixed_distal_mass_kg", NAN)) == 0.18
			and float(controller_policy_receipt.get("minimum_impulse_scale", NAN)) == 0.80
			and float(controller_policy_receipt.get("maximum_impulse_scale", NAN)) == 1.0
			and float(controller_policy_receipt.get("reference_knee_flexion_scale", NAN)) == 1.75
			and (
				float(controller_policy_receipt.get("heavy_endpoint_knee_flexion_scale", NAN))
				== 1.30
			)
			and int(controller_policy_receipt.get("reference_swing_ticks", -1)) == 72
			and int(controller_policy_receipt.get("heavy_endpoint_swing_ticks", -1)) == 60
			and float(controller_policy_receipt.get("reference_speed_rad_s", NAN)) == 3.5
			and float(controller_policy_receipt.get("heavy_endpoint_speed_rad_s", NAN)) == 2.5
			and (
				int(controller_policy_receipt.get("activation_start_offset_ticks", -1))
				== _um9_activation_start_offset_ticks(controller_family_id)
			)
			and (
				String(controller_policy_receipt.get("activation_predicate_id", ""))
				== "phase_windowed_contact_loaded_swing_knee"
			)
			and (
				controller_policy_receipt.get("activation_predicate_conditions", [])
				== [
					"joint_role == knee_pitch",
					"local_phase_tick >= activation_start_phase_tick",
					"local_phase_tick < realized_swing_ticks",
					"foot_bears_floor == true",
					"upper_mass_kg > 0.250",
				]
			)
			and (
				String(controller_policy_receipt.get("activation_start_phase_tick_formula", ""))
				== "floor(realized_swing_ticks * 3 / 4) + activation_start_offset_ticks"
			)
			and (
				String(controller_policy_receipt.get("heavy_fraction_formula", ""))
				== "clamp((upper_mass_kg - 0.25) / (0.30 - 0.25), 0.0, 1.0)"
			)
			and (
				String(controller_policy_receipt.get("knee_flexion_scale_formula", ""))
				== "lerp(1.75, 1.30, heavy_fraction)"
			)
			and (
				String(controller_policy_receipt.get("swing_ticks_formula", ""))
				== "round(lerp(72, 60, heavy_fraction))"
			)
			and (
				String(controller_policy_receipt.get("speed_formula", ""))
				== "lerp(3.5, 2.5, heavy_fraction)"
			)
			and String(controller_policy_digest).begins_with("sha256:")
			and String(controller_policy_digest).length() == 71
		)
		if not um9_policy_exact:
			printerr("  invalid_um9_policy_receipt=", controller_policy_receipt)
	var um10_policy_exact := true
	if _is_um10_controller_family(controller_family_id):
		um10_policy_exact = (
			(
				String(controller_policy_receipt.get("schema_version", ""))
				== "sporespore_upper_mass_release_gate_notch_policy_v1"
			)
			and float(controller_policy_receipt.get("hip_exponent", NAN)) == 1.0
			and float(controller_policy_receipt.get("knee_exponent", NAN)) == 0.5
			and float(controller_policy_receipt.get("reference_upper_mass_kg", NAN)) == 0.25
			and float(controller_policy_receipt.get("fixed_distal_mass_kg", NAN)) == 0.18
			and float(controller_policy_receipt.get("minimum_impulse_scale", NAN)) == 0.80
			and float(controller_policy_receipt.get("maximum_impulse_scale", NAN)) == 1.0
			and float(controller_policy_receipt.get("reference_knee_flexion_scale", NAN)) == 1.75
			and (
				float(controller_policy_receipt.get("heavy_endpoint_knee_flexion_scale", NAN))
				== 1.30
			)
			and int(controller_policy_receipt.get("reference_swing_ticks", -1)) == 72
			and int(controller_policy_receipt.get("heavy_endpoint_swing_ticks", -1)) == 60
			and float(controller_policy_receipt.get("reference_speed_rad_s", NAN)) == 3.5
			and float(controller_policy_receipt.get("heavy_endpoint_speed_rad_s", NAN)) == 2.5
			and int(controller_policy_receipt.get("post_release_start_offset_ticks", -1)) == 1
			and (
				int(controller_policy_receipt.get("pre_release_lead_ticks", -1))
				== _um10_pre_release_lead_ticks(controller_family_id)
			)
			and (
				String(controller_policy_receipt.get("activation_predicate_id", ""))
				== "release_gate_notched_contact_loaded_swing_knee"
			)
			and (
				controller_policy_receipt.get("activation_predicate_conditions", [])
				== [
					"joint_role == knee_pitch",
					"local_phase_tick >= pre_release_start_phase_tick",
					"local_phase_tick < realized_swing_ticks",
					"local_phase_tick != release_gate_tick",
					"foot_bears_floor == true",
					"upper_mass_kg > 0.250",
				]
			)
			and (
				String(controller_policy_receipt.get("pre_release_start_phase_tick_formula", ""))
				== "floor(realized_swing_ticks * 3 / 4) - pre_release_lead_ticks"
			)
			and (
				String(controller_policy_receipt.get("release_gate_tick_formula", ""))
				== "floor(realized_swing_ticks * 3 / 4)"
			)
			and (
				String(controller_policy_receipt.get("heavy_fraction_formula", ""))
				== "clamp((upper_mass_kg - 0.25) / (0.30 - 0.25), 0.0, 1.0)"
			)
			and (
				String(controller_policy_receipt.get("knee_flexion_scale_formula", ""))
				== "lerp(1.75, 1.30, heavy_fraction)"
			)
			and (
				String(controller_policy_receipt.get("swing_ticks_formula", ""))
				== "round(lerp(72, 60, heavy_fraction))"
			)
			and (
				String(controller_policy_receipt.get("speed_formula", ""))
				== "lerp(3.5, 2.5, heavy_fraction)"
			)
			and String(controller_policy_digest).begins_with("sha256:")
			and String(controller_policy_digest).length() == 71
		)
		if not um10_policy_exact:
			printerr("  invalid_um10_policy_receipt=", controller_policy_receipt)

	var reference_request := FixtureSpecScript.reference_spec()
	var reference_result := FixtureSpecScript.compile(reference_request)
	_check(bool(reference_result.get("ok", false)), "reference fixture compiles before variation")
	if not bool(reference_result.get("ok", false)):
		_finish()
		return
	var requested_fixture := reference_request.duplicate(true)
	_set_mass_axis(requested_fixture, fixture_variation_axis, requested_mass_kg)
	var requested_result := FixtureSpecScript.compile(requested_fixture)
	_check(
		bool(requested_result.get("ok", false)),
		"mass-only fixture compiles before world construction",
	)
	if not bool(requested_result.get("ok", false)):
		printerr("  fixture_compile_failure=", requested_result)
		_finish()
		return
	var normalized_fixture: Dictionary = requested_result["fixture_spec"]
	var requested_fixture_digest := String(requested_result["fixture_spec_sha256"])
	var reference_mass_kg := (
		REFERENCE_TORSO_MASS_KG
		if fixture_variation_axis == FIXTURE_AXIS_TORSO_MASS
		else REFERENCE_UPPER_MASS_KG
	)
	_check(
		(
			int(requested_result.get("world_build_count", -1)) == 0
			and is_equal_approx(
				_fixture_axis_mass(normalized_fixture, fixture_variation_axis),
				requested_mass_kg,
			)
			and (
				requested_fixture_digest == EXPECTED_REFERENCE_FIXTURE_DIGEST
				if is_equal_approx(requested_mass_kg, reference_mass_kg)
				else requested_fixture_digest != EXPECTED_REFERENCE_FIXTURE_DIGEST
			)
		),
		"normalized fixture changes only the requested mass identity before physics",
	)

	var summary := await (
		WaveGaitScript
		. new()
		. run(
			self,
			-1.0,
			10.0,
			requested_knee_flexion_scale,
			"lateral",
			requested_swing_ticks,
			0.40,
			"all",
			112,
			false,
			{},
			requested_robustness_options,
			normalized_fixture,
			requested_path_steering_options,
			requested_actuator_impulse_options,
			requested_motor_velocity_options,
		)
	)
	_check(
		(
			String(summary.get("schema_version", ""))
			== "physical_wave_gait_quadruped_development_summary_v1"
		),
		"physical world returns a complete walking summary even when a cell does not walk",
	)
	_check(
		(
			int(summary.get("world_build_count", -1)) == 1
			and int(summary.get("world_reset_count", -1)) == 0
			and int(summary.get("body_count", 0)) == 9
			and int(summary.get("limb_count", 0)) == 4
		),
		"one continuous nine-body four-limb world executes without reset",
	)
	var realized_fixture: Dictionary = summary.get("fixture_spec", {})
	_check(
		(
			String(summary.get("fixture_spec_sha256", "")) == requested_fixture_digest
			and is_equal_approx(
				_fixture_axis_mass(realized_fixture, fixture_variation_axis),
				requested_mass_kg,
			)
			and _only_mass_axis_differs(
				reference_result["fixture_spec"],
				realized_fixture,
				fixture_variation_axis,
				requested_mass_kg,
			)
		),
		"realized fixture receipt preserves every non-mass physical field",
	)
	var controller_configuration: Dictionary = summary.get("controller_configuration", {})
	var maximum_motor_speed_by_joint_role: Dictionary = summary.get(
		"maximum_motor_target_speed_by_joint_role_rad_s", {}
	)
	var expected_speed_cap_active := (
		(
			_is_um8_controller_family(controller_family_id)
			or _is_um9_controller_family(controller_family_id)
			or _is_um10_controller_family(controller_family_id)
		)
		and requested_mass_kg > REFERENCE_UPPER_MASS_KG
	)
	var speed_cap_activation_count := int(
		summary.get("contact_loaded_swing_knee_speed_cap_activation_count", -1)
	)
	var maximum_contact_loaded_knee_target_speed_rad_s := float(
		summary.get("maximum_contact_loaded_swing_knee_target_speed_rad_s", NAN)
	)
	var motor_velocity_receipts_exact := (
		maximum_motor_speed_by_joint_role.has("hip_pitch")
		and maximum_motor_speed_by_joint_role.has("knee_pitch")
		and float(maximum_motor_speed_by_joint_role.get("hip_pitch", NAN)) > 0.0
		and float(maximum_motor_speed_by_joint_role.get("hip_pitch", NAN)) <= 3.5
		and float(maximum_motor_speed_by_joint_role.get("knee_pitch", NAN)) > 0.0
		and float(maximum_motor_speed_by_joint_role.get("knee_pitch", NAN)) <= 3.5
	)
	if expected_speed_cap_active:
		motor_velocity_receipts_exact = (
			motor_velocity_receipts_exact
			and speed_cap_activation_count > 0
			and maximum_contact_loaded_knee_target_speed_rad_s > 0.0
			and (
				maximum_contact_loaded_knee_target_speed_rad_s
				<= (
					float(
						expected_normalized_motor_velocity_options["contact_loaded_swing_knee_maximum_motor_target_speed_rad_s"]
					)
					+ 0.0000001
				)
			)
		)
	else:
		motor_velocity_receipts_exact = (
			motor_velocity_receipts_exact
			and speed_cap_activation_count == 0
			and maximum_contact_loaded_knee_target_speed_rad_s == 0.0
		)
	var gate_receipts_exact := (
		_nonnegative_limb_integer_receipt_exact(
			summary.get("contact_gate_release_hold_tick_count_by_limb", {})
		)
		and _nonnegative_limb_integer_receipt_exact(
			summary.get("contact_gate_recontact_hold_tick_count_by_limb", {})
		)
		and _nonnegative_limb_integer_receipt_exact(
			summary.get("contact_gate_timeout_count_by_limb", {})
		)
		and _nonnegative_limb_integer_receipt_exact(
			summary.get("contact_gate_phase_sync_hold_tick_count_by_limb", {})
		)
		and _nonnegative_limb_integer_receipt_exact(
			summary.get("evidence_gait_advance_ticks_by_limb", {})
		)
	)
	_check(
		(
			(
				String(controller_configuration.get("schema_version", ""))
				== "sporespore_physical_wave_gait_controller_configuration_v1"
			)
			and float(controller_configuration.get("motor_direction_sign", NAN)) == -1.0
			and float(controller_configuration.get("knee_motor_impulse_scale", NAN)) == 10.0
			and (
				float(controller_configuration.get("knee_flexion_scale", NAN))
				== requested_knee_flexion_scale
			)
			and String(controller_configuration.get("gait_phase_order_id", "")) == "lateral"
			and int(controller_configuration.get("swing_ticks", -1)) == requested_swing_ticks
			and float(controller_configuration.get("contact_clearance_assist_rad", NAN)) == 0.40
			and (
				String(controller_configuration.get("contact_clearance_assist_limb_id", ""))
				== "all"
			)
			and int(controller_configuration.get("evidence_boundary_alignment_ticks", -1)) == 112
			and (
				controller_configuration.get("robustness_options", {})
				== expected_normalized_robustness_options
			)
			and (
				(
					controller_configuration.get("path_steering_options", {})
					== requested_path_steering_options
				)
				if not requested_path_steering_options.is_empty()
				else not controller_configuration.has("path_steering_options")
			)
			and (
				(
					(
						controller_configuration.get("actuator_impulse_options", {})
						== requested_actuator_impulse_options
					)
					and (
						summary.get("actuator_impulse_options", {})
						== requested_actuator_impulse_options
					)
					and is_equal_approx(
						float(summary.get("realized_hip_max_impulse_nms", NAN)),
						0.055 * _requested_hip_impulse_scale(requested_actuator_impulse_options),
					)
					and is_equal_approx(
						float(summary.get("realized_knee_max_impulse_nms", NAN)),
						(
							0.045
							* 10.0
							* _requested_knee_impulse_scale(requested_actuator_impulse_options)
						),
					)
				)
				if not requested_actuator_impulse_options.is_empty()
				else (
					not controller_configuration.has("actuator_impulse_options")
					and is_equal_approx(
						float(summary.get("realized_hip_max_impulse_nms", NAN)),
						0.055,
					)
					and is_equal_approx(
						float(summary.get("realized_knee_max_impulse_nms", NAN)),
						0.45,
					)
				)
			)
			and (
				(
					(
						controller_configuration.get("motor_velocity_options", {})
						== expected_normalized_motor_velocity_options
					)
					and (
						summary.get("motor_velocity_options", {})
						== expected_normalized_motor_velocity_options
					)
				)
				if not requested_motor_velocity_options.is_empty()
				else (
					not controller_configuration.has("motor_velocity_options")
					and (
						summary.get("motor_velocity_options", {})
						== expected_normalized_motor_velocity_options
					)
				)
			)
			and (
				(
					String(summary.get("controller_configuration_sha256", ""))
					== EXPECTED_LOCKED_S2B_CONTROLLER_DIGEST
				)
				if controller_family_id == CONTROLLER_FAMILY_S2_B
				else (
					String(summary.get("controller_configuration_sha256", "")).begins_with(
						"sha256:"
					)
					and String(summary.get("controller_configuration_sha256", "")).length() == 71
				)
			)
			and um2_policy_exact
			and um3_policy_exact
			and um4_policy_exact
			and um5_policy_exact
			and um6_policy_exact
			and um7_policy_exact
			and um8_policy_exact
			and um9_policy_exact
			and um10_policy_exact
			and motor_velocity_receipts_exact
			and gate_receipts_exact
			and _maximum_anchor_error_context_exact(summary)
		),
		"every mass cell uses the exact declared controller and actuator configuration",
	)
	if (
		controller_family_id.begins_with("s1_path_")
		or controller_family_id.begins_with("s2_gated_path_")
		or _is_upper_mass_adaptive_controller_family(controller_family_id)
	):
		var path_receipts: Array = summary.get("path_steering_update_receipts", [])
		var executed_ticks := int(summary.get("executed_ticks", 0))
		var expected_path_receipt_count := 0
		if executed_ticks > 240:
			expected_path_receipt_count = ((executed_ticks - 1 - 240) / 90) + 1
		var path_receipts_exact: bool = (
			summary.get("path_steering_options", {}) == requested_path_steering_options
			and path_receipts.size() == expected_path_receipt_count
		)
		for receipt_index in range(path_receipts.size()):
			var receipt: Dictionary = path_receipts[receipt_index]
			var receipt_tick := int(receipt.get("tick", -1))
			path_receipts_exact = (
				path_receipts_exact
				and receipt_tick == 240 + receipt_index * 90
				and int(receipt.get("gait_tick", -1)) == receipt_index * 90
				and is_finite(float(receipt.get("cross_track_error_m", NAN)))
				and is_finite(float(receipt.get("measured_yaw_error_rad", NAN)))
				and is_finite(float(receipt.get("desired_heading_error_rad", NAN)))
				and is_finite(float(receipt.get("yaw_tracking_error_rad", NAN)))
				and absf(float(receipt.get("steering_fraction", INF))) <= 0.20
			)
		_check(
			path_receipts_exact,
			"phase-bounded path steering updates exactly once per declared gait quarter",
		)
	_check(
		(
			String(summary.get("physics_engine", "")) == "Jolt Physics"
			and int(summary.get("physics_hz", 0)) == 120
			and int(summary.get("solver_velocity_steps", 0)) == 20
			and int(summary.get("solver_position_steps", 0)) == 6
		),
		"every mass cell uses the preregistered solver-6 physics environment",
	)
	_check(
		(
			int(summary.get("direct_torso_force_command_count", -1)) == 0
			and int(summary.get("direct_torso_impulse_command_count", -1)) == 0
			and int(summary.get("direct_torso_velocity_command_count", -1)) == 0
			and int(summary.get("direct_torso_transform_command_count", -1)) == 0
		),
		"mass probing grants no direct torso locomotor command",
	)
	var walking_gates: Dictionary = summary.get("walking_gate_receipts", {})
	_check(
		(
			walking_gates.size() >= 20
			and walking_gates.has("one_continuous_world")
			and walking_gates.has("every_limb_two_contact_cycles")
			and walking_gates.has("minimum_evidence_forward_translation")
			and walking_gates.has("bounded_anchor_error")
			and walking_gates.has("terminal_four_contact_recovery")
		),
		"unchanged walking gates remain complete for pass or failure diagnosis",
	)
	var walking_observed := bool(summary.get("physical_wave_gait_walking_observed", false))
	_check(
		(
			bool(summary.get("ok", false)) == walking_observed
			and (
				String(summary.get("failure_code", "")).is_empty()
				if walking_observed
				else (
					String(summary.get("failure_code", ""))
					== "PHYSICAL_WAVE_GAIT_WALKING_NOT_ESTABLISHED"
				)
			)
		),
		"walking outcome and failure code remain internally consistent",
	)
	_check(
		(
			not bool(summary.get("formal_milestone_acceptance_authorized", true))
			and not bool(summary.get("encyclopedia_admission_authorized", true))
			and not bool(summary.get("automatic_creature_guidance_allowed", true))
		),
		"mass-cell observation grants no promotion, knowledge, or guidance authority",
	)
	var actuator_mass_ratio := (
		(requested_mass_kg + 0.18) / (REFERENCE_UPPER_MASS_KG + 0.18)
		if _is_upper_mass_adaptive_controller_family(controller_family_id)
		else 1.0
	)
	var hip_actuator_exponent := (
		_upper_mass_actuator_exponent(controller_family_id)
		if _is_upper_mass_adaptive_controller_family(controller_family_id)
		else 0.0
	)
	var knee_actuator_exponent := (
		hip_actuator_exponent
		if _is_um2_controller_family(controller_family_id)
		else (
			_um4_knee_exponent(controller_family_id)
			if _is_um4_controller_family(controller_family_id)
			else (
				0.5
				if (
					_is_um5_controller_family(controller_family_id)
					or _is_um6_controller_family(controller_family_id)
					or _is_um7_controller_family(controller_family_id)
					or _is_um8_controller_family(controller_family_id)
					or _is_um9_controller_family(controller_family_id)
					or _is_um10_controller_family(controller_family_id)
				)
				else 0.0
			)
		)
	)
	var knee_attenuation_ratio := (
		minf(actuator_mass_ratio, 1.0 / actuator_mass_ratio)
		if (
			_is_um4_controller_family(controller_family_id)
			or _is_um5_controller_family(controller_family_id)
			or _is_um6_controller_family(controller_family_id)
			or _is_um7_controller_family(controller_family_id)
			or _is_um8_controller_family(controller_family_id)
			or _is_um9_controller_family(controller_family_id)
			or _is_um10_controller_family(controller_family_id)
		)
		else 1.0
	)
	var realized_actuator_options: Dictionary = summary.get("actuator_impulse_options", {})
	var realized_hip_scale := _requested_hip_impulse_scale(realized_actuator_options)
	var realized_knee_scale := _requested_knee_impulse_scale(realized_actuator_options)
	var heavy_fraction := (
		_um6_heavy_fraction(requested_mass_kg)
		if (
			_is_um6_controller_family(controller_family_id)
			or _is_um7_controller_family(controller_family_id)
			or _is_um8_controller_family(controller_family_id)
			or _is_um9_controller_family(controller_family_id)
			or _is_um10_controller_family(controller_family_id)
		)
		else 0.0
	)
	var endpoint_knee_flexion_scale := (
		_um6_endpoint_knee_flexion_scale(controller_family_id)
		if _is_um6_controller_family(controller_family_id)
		else (
			1.30
			if (
				_is_um7_controller_family(controller_family_id)
				or _is_um8_controller_family(controller_family_id)
				or _is_um9_controller_family(controller_family_id)
				or _is_um10_controller_family(controller_family_id)
			)
			else 1.75
		)
	)
	var endpoint_swing_ticks := (
		_um7_endpoint_swing_ticks(controller_family_id)
		if _is_um7_controller_family(controller_family_id)
		else (
			60
			if (
				_is_um8_controller_family(controller_family_id)
				or _is_um9_controller_family(controller_family_id)
				or _is_um10_controller_family(controller_family_id)
			)
			else 72
		)
	)
	var endpoint_contact_loaded_knee_speed_rad_s := (
		_um8_endpoint_speed_rad_s(controller_family_id)
		if _is_um8_controller_family(controller_family_id)
		else (
			2.5
			if (
				_is_um9_controller_family(controller_family_id)
				or _is_um10_controller_family(controller_family_id)
			)
			else 3.5
		)
	)
	var configured_contact_loaded_knee_speed_rad_s := float(
		expected_normalized_motor_velocity_options["contact_loaded_swing_knee_maximum_motor_target_speed_rad_s"]
	)
	var activation_start_phase_tick := int(
		(
			expected_normalized_motor_velocity_options
			. get(
				"contact_loaded_swing_knee_activation_start_phase_tick",
				0,
			)
		)
	)
	var activation_start_offset_ticks := (
		_um9_activation_start_offset_ticks(controller_family_id)
		if _is_um9_controller_family(controller_family_id)
		else 0
	)
	var full_speed_override_phase_tick := int(
		(
			expected_normalized_motor_velocity_options
			. get(
				"contact_loaded_swing_knee_full_speed_override_phase_tick",
				-1,
			)
		)
	)
	var pre_release_lead_ticks := (
		_um10_pre_release_lead_ticks(controller_family_id)
		if _is_um10_controller_family(controller_family_id)
		else 0
	)
	var release_gate_tick := (requested_swing_ticks * 3) / 4
	var recontact_gate_tick := requested_swing_ticks + (360 - requested_swing_ticks) / 4
	var anchor_context: Dictionary = summary.get("maximum_anchor_error_context", {})
	print(
		(
			(
				"MASS_AXIS_RESULT variation_axis=%s mass_kg=%.6f controller_family=%s "
				+ "policy_digest=%s walking=%s fixture_digest=%s "
				+ "controller_digest=%s cycles=%s evidence=%s final=%s "
				+ "yaw=%.9f tilt=%.9f mass_ratio=%.12f exponent=%.6f "
				+ "actuator_scale=%.9f hip_exponent=%.6f knee_exponent=%.6f "
				+ "attenuation_ratio=%.12f knee_attenuation_ratio=%.12f "
				+ "hip_scale=%.9f knee_scale=%.9f "
				+ "heavy_fraction=%.9f endpoint_knee_flexion_scale=%.9f "
				+ "knee_flexion_scale=%.9f "
				+ "endpoint_swing_ticks=%d swing_ticks=%d "
				+ "release_gate_tick=%d recontact_gate_tick=%d "
				+ "endpoint_contact_loaded_knee_speed=%.9f "
				+ "contact_loaded_knee_speed=%.9f speed_cap_activations=%d "
				+ "activation_start_phase_tick=%d activation_start_offset_ticks=%d "
				+ "full_speed_override_phase_tick=%d pre_release_lead_ticks=%d "
				+ "max_contact_loaded_knee_command_speed=%.9f "
				+ "max_hip_command_speed=%.9f max_knee_command_speed=%.9f "
				+ "hip_impulse=%.9f knee_impulse=%.9f anchor=%.9f "
				+ "anchor_joint=%s anchor_tick=%d anchor_gait_tick=%d "
				+ "anchor_local_phase_tick=%d anchor_swing=%s anchor_contact=%s "
				+ "anchor_target=%.9f anchor_motor_velocity=%.9f "
				+ "anchor_measured_angle=%.9f anchor_measured_rate=%.9f "
				+ "hinge=%.9f gate_release_holds=%s gate_recontact_holds=%s "
				+ "gate_timeouts=%s gate_sync_holds=%s evidence_gait_advance=%s "
				+ "gates=%s"
			)
			% [
				fixture_variation_axis,
				requested_mass_kg,
				controller_family_id,
				controller_policy_digest,
				str(walking_observed).to_lower(),
				requested_fixture_digest,
				String(summary.get("controller_configuration_sha256", "")),
				str(summary.get("contact_cycle_count_by_limb", {})),
				str(summary.get("evidence_torso_displacement_world_m", Vector3.ZERO)),
				str(summary.get("final_torso_displacement_world_m", Vector3.ZERO)),
				float(summary.get("final_yaw_drift_rad", NAN)),
				float(summary.get("maximum_tilt_rad", NAN)),
				actuator_mass_ratio,
				hip_actuator_exponent,
				realized_hip_scale,
				hip_actuator_exponent,
				knee_actuator_exponent,
				knee_attenuation_ratio,
				knee_attenuation_ratio,
				realized_hip_scale,
				realized_knee_scale,
				heavy_fraction,
				endpoint_knee_flexion_scale,
				requested_knee_flexion_scale,
				endpoint_swing_ticks,
				requested_swing_ticks,
				release_gate_tick,
				recontact_gate_tick,
				endpoint_contact_loaded_knee_speed_rad_s,
				configured_contact_loaded_knee_speed_rad_s,
				speed_cap_activation_count,
				activation_start_phase_tick,
				activation_start_offset_ticks,
				full_speed_override_phase_tick,
				pre_release_lead_ticks,
				maximum_contact_loaded_knee_target_speed_rad_s,
				float(maximum_motor_speed_by_joint_role.get("hip_pitch", NAN)),
				float(maximum_motor_speed_by_joint_role.get("knee_pitch", NAN)),
				float(summary.get("realized_hip_max_impulse_nms", NAN)),
				float(summary.get("realized_knee_max_impulse_nms", NAN)),
				float(summary.get("maximum_anchor_error_m", NAN)),
				String(summary.get("maximum_anchor_error_joint_id", "")),
				int(summary.get("maximum_anchor_error_tick", -1)),
				int(anchor_context.get("gait_tick", -1)),
				int(anchor_context.get("local_phase_tick", -1)),
				str(bool(anchor_context.get("swing_phase", false))).to_lower(),
				str(bool(anchor_context.get("foot_bears_floor", false))).to_lower(),
				float(anchor_context.get("target_angle_rad", NAN)),
				float(anchor_context.get("target_velocity_rad_s", NAN)),
				float(anchor_context.get("measured_angle_rad", NAN)),
				float(anchor_context.get("measured_rate_rad_s", NAN)),
				float(summary.get("maximum_hinge_axis_error_rad", NAN)),
				str(summary.get("contact_gate_release_hold_tick_count_by_limb", {})),
				str(summary.get("contact_gate_recontact_hold_tick_count_by_limb", {})),
				str(summary.get("contact_gate_timeout_count_by_limb", {})),
				str(summary.get("contact_gate_phase_sync_hold_tick_count_by_limb", {})),
				str(summary.get("evidence_gait_advance_ticks_by_limb", {})),
				str(walking_gates),
			]
		)
	)
	_finish()


static func _is_declared_mass(fixture_variation_axis: String, requested_mass_kg: float) -> bool:
	if not is_finite(requested_mass_kg):
		return false
	var declared_cells: Array = (
		DECLARED_TORSO_MASS_CELLS_KG
		if fixture_variation_axis == FIXTURE_AXIS_TORSO_MASS
		else DECLARED_SYMMETRIC_UPPER_MASS_CELLS_KG
	)
	for mass_value in declared_cells:
		if is_equal_approx(float(mass_value), requested_mass_kg):
			return true
	return false


static func _set_mass_axis(
	fixture: Dictionary,
	fixture_variation_axis: String,
	requested_mass_kg: float,
) -> void:
	if fixture_variation_axis == FIXTURE_AXIS_TORSO_MASS:
		(fixture["torso"] as Dictionary)["mass_kg"] = requested_mass_kg
		return
	for limb_value in fixture["limbs"]:
		var limb: Dictionary = limb_value
		limb["upper_mass_kg"] = requested_mass_kg


static func _fixture_axis_mass(fixture: Dictionary, fixture_variation_axis: String) -> float:
	if fixture_variation_axis == FIXTURE_AXIS_TORSO_MASS:
		return float((fixture.get("torso", {}) as Dictionary).get("mass_kg", NAN))
	var limbs: Array = fixture.get("limbs", [])
	if limbs.size() != 4:
		return NAN
	var first_mass := float((limbs[0] as Dictionary).get("upper_mass_kg", NAN))
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		if not is_equal_approx(float(limb.get("upper_mass_kg", NAN)), first_mass):
			return NAN
	return first_mass


static func _controller_family_configuration(
	controller_family_id: String,
	requested_mass_kg: float,
) -> Dictionary:
	if controller_family_id == CONTROLLER_FAMILY_TM1:
		return {
			"requested": TM1_REQUESTED_ROBUSTNESS_OPTIONS,
			"normalized": TM1_REQUESTED_ROBUSTNESS_OPTIONS,
			"path_steering": {},
			"actuator": {},
		}
	if controller_family_id == CONTROLLER_FAMILY_TM2:
		return {
			"requested": TM2_REQUESTED_ROBUSTNESS_OPTIONS,
			"normalized": TM2_NORMALIZED_ROBUSTNESS_OPTIONS,
			"path_steering": {},
			"actuator": {},
		}
	if _is_um2_controller_family(controller_family_id):
		var actuator_impulse_scale := _um2_actuator_impulse_scale(
			controller_family_id,
			requested_mass_kg,
		)
		return {
			"requested": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"normalized": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"path_steering":
			{
				"phase_bounded_path_steering_enabled": true,
				"cross_track_heading_gain_rad_per_m": 0.5,
				"yaw_error_stride_gain_per_rad": 1.0,
				"steering_update_interval_ticks": 90,
				"maximum_desired_heading_error_rad": 0.25,
				"maximum_steering_fraction": 0.20,
			},
			"actuator":
			{
				"mass_adaptive_actuator_enabled": true,
				"actuator_policy_id": controller_family_id,
				"actuator_impulse_scale": actuator_impulse_scale,
			},
		}
	if _is_um3_controller_family(controller_family_id):
		var hip_impulse_scale := _um3_hip_impulse_scale(
			controller_family_id,
			requested_mass_kg,
		)
		return {
			"requested": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"normalized": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"path_steering":
			{
				"phase_bounded_path_steering_enabled": true,
				"cross_track_heading_gain_rad_per_m": 0.5,
				"yaw_error_stride_gain_per_rad": 1.0,
				"steering_update_interval_ticks": 90,
				"maximum_desired_heading_error_rad": 0.25,
				"maximum_steering_fraction": 0.20,
			},
			"actuator":
			{
				"mass_adaptive_actuator_enabled": true,
				"actuator_policy_id": controller_family_id,
				"hip_impulse_scale": hip_impulse_scale,
				"knee_impulse_scale": 1.0,
			},
		}
	if _is_um4_controller_family(controller_family_id):
		var mass_ratio := (requested_mass_kg + 0.18) / (REFERENCE_UPPER_MASS_KG + 0.18)
		var hip_impulse_scale := clampf(pow(mass_ratio, 0.5), 0.80, 1.25)
		var knee_attenuation_ratio := minf(mass_ratio, 1.0 / mass_ratio)
		var knee_impulse_scale := clampf(
			pow(knee_attenuation_ratio, _um4_knee_exponent(controller_family_id)),
			0.80,
			1.0,
		)
		return {
			"requested": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"normalized": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"path_steering":
			{
				"phase_bounded_path_steering_enabled": true,
				"cross_track_heading_gain_rad_per_m": 0.5,
				"yaw_error_stride_gain_per_rad": 1.0,
				"steering_update_interval_ticks": 90,
				"maximum_desired_heading_error_rad": 0.25,
				"maximum_steering_fraction": 0.20,
			},
			"actuator":
			{
				"mass_adaptive_actuator_enabled": true,
				"actuator_policy_id": controller_family_id,
				"hip_impulse_scale": hip_impulse_scale,
				"knee_impulse_scale": knee_impulse_scale,
			},
		}
	if _is_um5_controller_family(controller_family_id):
		var mass_ratio := (requested_mass_kg + 0.18) / (REFERENCE_UPPER_MASS_KG + 0.18)
		var attenuation_ratio := minf(mass_ratio, 1.0 / mass_ratio)
		var hip_impulse_scale := clampf(
			pow(attenuation_ratio, _um5_hip_exponent(controller_family_id)),
			0.80,
			1.0,
		)
		var knee_impulse_scale := clampf(pow(attenuation_ratio, 0.5), 0.80, 1.0)
		return {
			"requested": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"normalized": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"path_steering":
			{
				"phase_bounded_path_steering_enabled": true,
				"cross_track_heading_gain_rad_per_m": 0.5,
				"yaw_error_stride_gain_per_rad": 1.0,
				"steering_update_interval_ticks": 90,
				"maximum_desired_heading_error_rad": 0.25,
				"maximum_steering_fraction": 0.20,
			},
			"actuator":
			{
				"mass_adaptive_actuator_enabled": true,
				"actuator_policy_id": controller_family_id,
				"hip_impulse_scale": hip_impulse_scale,
				"knee_impulse_scale": knee_impulse_scale,
			},
		}
	if _is_um6_controller_family(controller_family_id):
		var mass_ratio := (requested_mass_kg + 0.18) / (REFERENCE_UPPER_MASS_KG + 0.18)
		var attenuation_ratio := minf(mass_ratio, 1.0 / mass_ratio)
		var hip_impulse_scale := clampf(pow(attenuation_ratio, 1.0), 0.80, 1.0)
		var knee_impulse_scale := clampf(pow(attenuation_ratio, 0.5), 0.80, 1.0)
		var heavy_fraction := _um6_heavy_fraction(requested_mass_kg)
		var knee_flexion_scale := lerpf(
			1.75,
			_um6_endpoint_knee_flexion_scale(controller_family_id),
			heavy_fraction,
		)
		return {
			"requested": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"normalized": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"path_steering":
			{
				"phase_bounded_path_steering_enabled": true,
				"cross_track_heading_gain_rad_per_m": 0.5,
				"yaw_error_stride_gain_per_rad": 1.0,
				"steering_update_interval_ticks": 90,
				"maximum_desired_heading_error_rad": 0.25,
				"maximum_steering_fraction": 0.20,
			},
			"actuator":
			{
				"mass_adaptive_actuator_enabled": true,
				"actuator_policy_id": controller_family_id,
				"hip_impulse_scale": hip_impulse_scale,
				"knee_impulse_scale": knee_impulse_scale,
			},
			"knee_flexion_scale": knee_flexion_scale,
		}
	if _is_um7_controller_family(controller_family_id):
		var mass_ratio := (requested_mass_kg + 0.18) / (REFERENCE_UPPER_MASS_KG + 0.18)
		var attenuation_ratio := minf(mass_ratio, 1.0 / mass_ratio)
		var hip_impulse_scale := clampf(pow(attenuation_ratio, 1.0), 0.80, 1.0)
		var knee_impulse_scale := clampf(pow(attenuation_ratio, 0.5), 0.80, 1.0)
		var heavy_fraction := _um6_heavy_fraction(requested_mass_kg)
		var knee_flexion_scale := lerpf(1.75, 1.30, heavy_fraction)
		var swing_ticks := roundi(
			lerpf(
				72.0,
				float(_um7_endpoint_swing_ticks(controller_family_id)),
				heavy_fraction,
			)
		)
		return {
			"requested": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"normalized": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"path_steering":
			{
				"phase_bounded_path_steering_enabled": true,
				"cross_track_heading_gain_rad_per_m": 0.5,
				"yaw_error_stride_gain_per_rad": 1.0,
				"steering_update_interval_ticks": 90,
				"maximum_desired_heading_error_rad": 0.25,
				"maximum_steering_fraction": 0.20,
			},
			"actuator":
			{
				"mass_adaptive_actuator_enabled": true,
				"actuator_policy_id": controller_family_id,
				"hip_impulse_scale": hip_impulse_scale,
				"knee_impulse_scale": knee_impulse_scale,
			},
			"knee_flexion_scale": knee_flexion_scale,
			"swing_ticks": swing_ticks,
		}
	if _is_um8_controller_family(controller_family_id):
		var mass_ratio := (requested_mass_kg + 0.18) / (REFERENCE_UPPER_MASS_KG + 0.18)
		var attenuation_ratio := minf(mass_ratio, 1.0 / mass_ratio)
		var hip_impulse_scale := clampf(pow(attenuation_ratio, 1.0), 0.80, 1.0)
		var knee_impulse_scale := clampf(pow(attenuation_ratio, 0.5), 0.80, 1.0)
		var heavy_fraction := _um6_heavy_fraction(requested_mass_kg)
		var knee_flexion_scale := lerpf(1.75, 1.30, heavy_fraction)
		var swing_ticks := roundi(lerpf(72.0, 60.0, heavy_fraction))
		var motor_velocity_options := {}
		if requested_mass_kg > REFERENCE_UPPER_MASS_KG:
			motor_velocity_options = {
				"mass_adaptive_motor_velocity_enabled": true,
				"motor_velocity_policy_id": controller_family_id,
				"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s":
				lerpf(
					3.5,
					_um8_endpoint_speed_rad_s(controller_family_id),
					heavy_fraction,
				),
			}
		return {
			"requested": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"normalized": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"path_steering":
			{
				"phase_bounded_path_steering_enabled": true,
				"cross_track_heading_gain_rad_per_m": 0.5,
				"yaw_error_stride_gain_per_rad": 1.0,
				"steering_update_interval_ticks": 90,
				"maximum_desired_heading_error_rad": 0.25,
				"maximum_steering_fraction": 0.20,
			},
			"actuator":
			{
				"mass_adaptive_actuator_enabled": true,
				"actuator_policy_id": controller_family_id,
				"hip_impulse_scale": hip_impulse_scale,
				"knee_impulse_scale": knee_impulse_scale,
			},
			"motor_velocity": motor_velocity_options,
			"knee_flexion_scale": knee_flexion_scale,
			"swing_ticks": swing_ticks,
		}
	if _is_um9_controller_family(controller_family_id):
		var mass_ratio := (requested_mass_kg + 0.18) / (REFERENCE_UPPER_MASS_KG + 0.18)
		var attenuation_ratio := minf(mass_ratio, 1.0 / mass_ratio)
		var hip_impulse_scale := clampf(pow(attenuation_ratio, 1.0), 0.80, 1.0)
		var knee_impulse_scale := clampf(pow(attenuation_ratio, 0.5), 0.80, 1.0)
		var heavy_fraction := _um6_heavy_fraction(requested_mass_kg)
		var knee_flexion_scale := lerpf(1.75, 1.30, heavy_fraction)
		var swing_ticks := roundi(lerpf(72.0, 60.0, heavy_fraction))
		var release_gate_tick := (swing_ticks * 3) / 4
		var activation_start_phase_tick := (
			release_gate_tick + _um9_activation_start_offset_ticks(controller_family_id)
		)
		var motor_velocity_options := {}
		if requested_mass_kg > REFERENCE_UPPER_MASS_KG:
			motor_velocity_options = {
				"mass_adaptive_motor_velocity_enabled": true,
				"motor_velocity_policy_id": controller_family_id,
				"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s":
				lerpf(3.5, 2.5, heavy_fraction),
				"contact_loaded_swing_knee_activation_start_phase_tick":
				activation_start_phase_tick,
			}
		return {
			"requested": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"normalized": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"path_steering":
			{
				"phase_bounded_path_steering_enabled": true,
				"cross_track_heading_gain_rad_per_m": 0.5,
				"yaw_error_stride_gain_per_rad": 1.0,
				"steering_update_interval_ticks": 90,
				"maximum_desired_heading_error_rad": 0.25,
				"maximum_steering_fraction": 0.20,
			},
			"actuator":
			{
				"mass_adaptive_actuator_enabled": true,
				"actuator_policy_id": controller_family_id,
				"hip_impulse_scale": hip_impulse_scale,
				"knee_impulse_scale": knee_impulse_scale,
			},
			"motor_velocity": motor_velocity_options,
			"knee_flexion_scale": knee_flexion_scale,
			"swing_ticks": swing_ticks,
		}
	if _is_um10_controller_family(controller_family_id):
		var mass_ratio := (requested_mass_kg + 0.18) / (REFERENCE_UPPER_MASS_KG + 0.18)
		var attenuation_ratio := minf(mass_ratio, 1.0 / mass_ratio)
		var hip_impulse_scale := clampf(pow(attenuation_ratio, 1.0), 0.80, 1.0)
		var knee_impulse_scale := clampf(pow(attenuation_ratio, 0.5), 0.80, 1.0)
		var heavy_fraction := _um6_heavy_fraction(requested_mass_kg)
		var knee_flexion_scale := lerpf(1.75, 1.30, heavy_fraction)
		var swing_ticks := roundi(lerpf(72.0, 60.0, heavy_fraction))
		var release_gate_tick := (swing_ticks * 3) / 4
		var pre_release_start_phase_tick := (
			release_gate_tick - _um10_pre_release_lead_ticks(controller_family_id)
		)
		var motor_velocity_options := {}
		if requested_mass_kg > REFERENCE_UPPER_MASS_KG:
			motor_velocity_options = {
				"mass_adaptive_motor_velocity_enabled": true,
				"motor_velocity_policy_id": controller_family_id,
				"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s":
				lerpf(3.5, 2.5, heavy_fraction),
				"contact_loaded_swing_knee_activation_start_phase_tick":
				pre_release_start_phase_tick,
				"contact_loaded_swing_knee_full_speed_override_phase_tick": release_gate_tick,
			}
		return {
			"requested": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"normalized": S2_REQUESTED_ROBUSTNESS_OPTIONS,
			"path_steering":
			{
				"phase_bounded_path_steering_enabled": true,
				"cross_track_heading_gain_rad_per_m": 0.5,
				"yaw_error_stride_gain_per_rad": 1.0,
				"steering_update_interval_ticks": 90,
				"maximum_desired_heading_error_rad": 0.25,
				"maximum_steering_fraction": 0.20,
			},
			"actuator":
			{
				"mass_adaptive_actuator_enabled": true,
				"actuator_policy_id": controller_family_id,
				"hip_impulse_scale": hip_impulse_scale,
				"knee_impulse_scale": knee_impulse_scale,
			},
			"motor_velocity": motor_velocity_options,
			"knee_flexion_scale": knee_flexion_scale,
			"swing_ticks": swing_ticks,
		}
	if (
		controller_family_id.begins_with("s1_path_")
		or controller_family_id.begins_with("s2_gated_path_")
	):
		var gain_pair: Array = {
			CONTROLLER_FAMILY_S1_A: [0.5, 0.5],
			CONTROLLER_FAMILY_S1_B: [0.5, 1.0],
			CONTROLLER_FAMILY_S1_C: [1.0, 0.5],
			CONTROLLER_FAMILY_S1_D: [1.0, 1.0],
			CONTROLLER_FAMILY_S2_A: [0.5, 0.5],
			CONTROLLER_FAMILY_S2_B: [0.5, 1.0],
			CONTROLLER_FAMILY_S2_C: [1.0, 0.5],
			CONTROLLER_FAMILY_S2_D: [1.0, 1.0],
		}[controller_family_id]
		var contact_gated: bool = controller_family_id.begins_with("s2_gated_path_")
		var robustness_options: Dictionary = (
			S2_REQUESTED_ROBUSTNESS_OPTIONS if contact_gated else TM2_REQUESTED_ROBUSTNESS_OPTIONS
		)
		var normalized_robustness_options: Dictionary = (
			S2_REQUESTED_ROBUSTNESS_OPTIONS if contact_gated else TM2_NORMALIZED_ROBUSTNESS_OPTIONS
		)
		return {
			"requested": robustness_options,
			"normalized": normalized_robustness_options,
			"path_steering":
			{
				"phase_bounded_path_steering_enabled": true,
				"cross_track_heading_gain_rad_per_m": float(gain_pair[0]),
				"yaw_error_stride_gain_per_rad": float(gain_pair[1]),
				"steering_update_interval_ticks": 90,
				"maximum_desired_heading_error_rad": 0.25,
				"maximum_steering_fraction": 0.20,
			},
			"actuator": {},
		}
	if controller_family_id == CONTROLLER_FAMILY_TC2:
		var adaptive_gain_per_m := clampf((requested_mass_kg - 3.0) / 3.0, 0.0, 0.25)
		var adaptive_normalized := {
			"contact_gated_phase_progression": false,
			"maximum_contact_gate_hold_ticks": 48,
			"maximum_contact_gated_phase_skew_ticks": 12,
			"lateral_stride_steering_gain_per_m": adaptive_gain_per_m,
		}
		return {
			"requested": adaptive_normalized,
			"normalized": adaptive_normalized,
			"path_steering": {},
			"actuator": {},
		}
	var lateral_gain_per_m: float = float(
		(
			{
				CONTROLLER_FAMILY_TC1_GAIN_005: 0.05,
				CONTROLLER_FAMILY_TC1_GAIN_010: 0.10,
				CONTROLLER_FAMILY_TC1_GAIN_015: 0.15,
				CONTROLLER_FAMILY_TC1_GAIN_020: 0.20,
				CONTROLLER_FAMILY_TC1_GAIN_025: 0.25,
			}
			. get(controller_family_id, NAN)
		)
	)
	var normalized := {
		"contact_gated_phase_progression": false,
		"maximum_contact_gate_hold_ticks": 48,
		"maximum_contact_gated_phase_skew_ticks": 12,
		"lateral_stride_steering_gain_per_m": lateral_gain_per_m,
	}
	return {
		"requested": normalized,
		"normalized": normalized,
		"path_steering": {},
		"actuator": {},
	}


static func _controller_policy_receipt(controller_family_id: String) -> Dictionary:
	if controller_family_id == CONTROLLER_FAMILY_TC2:
		return {
			"schema_version": "sporespore_linear_mass_adaptive_lateral_steering_policy_v1",
			"controller_family_id": CONTROLLER_FAMILY_TC2,
			"lower_selection_mass_kg": 3.0,
			"lower_selection_gain_per_m": 0.0,
			"upper_selection_mass_kg": 3.3,
			"upper_selection_gain_per_m": 0.10,
			"slope_per_m_per_kg": 1.0 / 3.0,
			"minimum_gain_per_m": 0.0,
			"maximum_gain_per_m": 0.25,
			"formula": "clamp((torso_mass_kg - 3.0) / 3.0, 0.0, 0.25)",
		}
	if _is_um2_controller_family(controller_family_id):
		return {
			"schema_version": "sporespore_upper_mass_adaptive_actuator_policy_v1",
			"controller_family_id": controller_family_id,
			"reference_upper_mass_kg": 0.25,
			"fixed_distal_mass_kg": 0.18,
			"exponent": _um2_exponent(controller_family_id),
			"minimum_impulse_scale": 0.80,
			"maximum_impulse_scale": 1.25,
			"affected_joint_roles": ["hip_pitch", "knee_pitch"],
			"hip_base_max_impulse_nms": 0.055,
			"knee_base_max_impulse_nms": 0.045,
			"knee_motor_impulse_scale": 10.0,
			"mass_ratio_formula": "(upper_mass_kg + 0.18) / (0.25 + 0.18)",
			"scale_formula": "clamp(pow(mass_ratio, exponent), 0.80, 1.25)",
		}
	if _is_um3_controller_family(controller_family_id):
		return {
			"schema_version": "sporespore_upper_mass_joint_specific_actuator_policy_v1",
			"controller_family_id": controller_family_id,
			"reference_upper_mass_kg": 0.25,
			"fixed_distal_mass_kg": 0.18,
			"hip_exponent": _um3_hip_exponent(controller_family_id),
			"knee_exponent": 0.0,
			"minimum_impulse_scale": 0.80,
			"maximum_impulse_scale": 1.25,
			"affected_joint_roles": ["hip_pitch"],
			"fixed_joint_roles": ["knee_pitch"],
			"hip_base_max_impulse_nms": 0.055,
			"knee_base_max_impulse_nms": 0.045,
			"knee_motor_impulse_scale": 10.0,
			"fixed_knee_impulse_scale": 1.0,
			"mass_ratio_formula": "(upper_mass_kg + 0.18) / (0.25 + 0.18)",
			"hip_scale_formula": "clamp(pow(mass_ratio, hip_exponent), 0.80, 1.25)",
			"knee_scale_formula": "1.0",
		}
	if _is_um4_controller_family(controller_family_id):
		return {
			"schema_version": "sporespore_upper_mass_bidirectional_knee_attenuation_policy_v1",
			"controller_family_id": controller_family_id,
			"reference_upper_mass_kg": 0.25,
			"fixed_distal_mass_kg": 0.18,
			"hip_exponent": 0.5,
			"knee_exponent": _um4_knee_exponent(controller_family_id),
			"minimum_impulse_scale": 0.80,
			"maximum_hip_impulse_scale": 1.25,
			"maximum_knee_impulse_scale": 1.0,
			"affected_joint_roles": ["hip_pitch", "knee_pitch"],
			"hip_base_max_impulse_nms": 0.055,
			"knee_base_max_impulse_nms": 0.045,
			"knee_motor_impulse_scale": 10.0,
			"mass_ratio_formula": "(upper_mass_kg + 0.18) / (0.25 + 0.18)",
			"hip_scale_formula": "clamp(pow(mass_ratio, 0.5), 0.80, 1.25)",
			"knee_attenuation_ratio_formula": "min(mass_ratio, 1.0 / mass_ratio)",
			"knee_scale_formula": "clamp(pow(knee_attenuation_ratio, knee_exponent), 0.80, 1.0)",
		}
	if _is_um5_controller_family(controller_family_id):
		return {
			"schema_version": "sporespore_upper_mass_bidirectional_dual_attenuation_policy_v1",
			"controller_family_id": controller_family_id,
			"reference_upper_mass_kg": 0.25,
			"fixed_distal_mass_kg": 0.18,
			"hip_exponent": _um5_hip_exponent(controller_family_id),
			"knee_exponent": 0.5,
			"minimum_impulse_scale": 0.80,
			"maximum_impulse_scale": 1.0,
			"affected_joint_roles": ["hip_pitch", "knee_pitch"],
			"hip_base_max_impulse_nms": 0.055,
			"knee_base_max_impulse_nms": 0.045,
			"knee_motor_impulse_scale": 10.0,
			"mass_ratio_formula": "(upper_mass_kg + 0.18) / (0.25 + 0.18)",
			"attenuation_ratio_formula": "min(mass_ratio, 1.0 / mass_ratio)",
			"hip_scale_formula": "clamp(pow(attenuation_ratio, hip_exponent), 0.80, 1.0)",
			"knee_scale_formula": "clamp(pow(attenuation_ratio, 0.5), 0.80, 1.0)",
		}
	if _is_um6_controller_family(controller_family_id):
		return {
			"schema_version": "sporespore_upper_mass_heavy_knee_trajectory_policy_v1",
			"controller_family_id": controller_family_id,
			"reference_upper_mass_kg": 0.25,
			"fixed_distal_mass_kg": 0.18,
			"hip_exponent": 1.0,
			"knee_exponent": 0.5,
			"minimum_impulse_scale": 0.80,
			"maximum_impulse_scale": 1.0,
			"actuator_affected_joint_roles": ["hip_pitch", "knee_pitch"],
			"trajectory_affected_joint_roles": ["knee_pitch"],
			"hip_base_max_impulse_nms": 0.055,
			"knee_base_max_impulse_nms": 0.045,
			"knee_motor_impulse_scale": 10.0,
			"light_side_knee_flexion_scale": 1.75,
			"heavy_endpoint_knee_flexion_scale":
			_um6_endpoint_knee_flexion_scale(controller_family_id),
			"heavy_ramp_start_upper_mass_kg": 0.25,
			"heavy_ramp_end_upper_mass_kg": 0.30,
			"contact_clearance_assist_rad": 0.40,
			"mass_ratio_formula": "(upper_mass_kg + 0.18) / (0.25 + 0.18)",
			"attenuation_ratio_formula": "min(mass_ratio, 1.0 / mass_ratio)",
			"hip_scale_formula": "clamp(pow(attenuation_ratio, 1.0), 0.80, 1.0)",
			"knee_scale_formula": "clamp(pow(attenuation_ratio, 0.5), 0.80, 1.0)",
			"heavy_fraction_formula": "clamp((upper_mass_kg - 0.25) / (0.30 - 0.25), 0.0, 1.0)",
			"knee_flexion_scale_formula":
			"lerp(1.75, heavy_endpoint_knee_flexion_scale, heavy_fraction)",
		}
	if _is_um8_controller_family(controller_family_id):
		return {
			"schema_version": "sporespore_upper_mass_contact_loaded_swing_knee_rate_policy_v1",
			"controller_family_id": controller_family_id,
			"reference_upper_mass_kg": 0.25,
			"fixed_distal_mass_kg": 0.18,
			"hip_exponent": 1.0,
			"knee_exponent": 0.5,
			"minimum_impulse_scale": 0.80,
			"maximum_impulse_scale": 1.0,
			"reference_knee_flexion_scale": 1.75,
			"heavy_endpoint_knee_flexion_scale": 1.30,
			"reference_swing_ticks": 72,
			"heavy_endpoint_swing_ticks": 60,
			"reference_speed_rad_s": 3.5,
			"heavy_endpoint_speed_rad_s": _um8_endpoint_speed_rad_s(controller_family_id),
			"activation_predicate_id": "contact_loaded_swing_knee",
			"activation_predicate_conditions":
			[
				"joint_role == knee_pitch",
				"local_phase_tick < realized_swing_ticks",
				"foot_bears_floor == true",
				"upper_mass_kg > 0.250",
			],
			"heavy_ramp_start_upper_mass_kg": 0.25,
			"heavy_ramp_end_upper_mass_kg": 0.30,
			"contact_clearance_assist_rad": 0.40,
			"mass_ratio_formula": "(upper_mass_kg + 0.18) / (0.25 + 0.18)",
			"attenuation_ratio_formula": "min(mass_ratio, 1.0 / mass_ratio)",
			"hip_scale_formula": "clamp(pow(attenuation_ratio, 1.0), 0.80, 1.0)",
			"knee_scale_formula": "clamp(pow(attenuation_ratio, 0.5), 0.80, 1.0)",
			"heavy_fraction_formula": "clamp((upper_mass_kg - 0.25) / (0.30 - 0.25), 0.0, 1.0)",
			"knee_flexion_scale_formula": "lerp(1.75, 1.30, heavy_fraction)",
			"swing_ticks_formula": "round(lerp(72, 60, heavy_fraction))",
			"speed_formula": "lerp(3.5, heavy_endpoint_speed_rad_s, heavy_fraction)",
		}
	if _is_um9_controller_family(controller_family_id):
		return {
			"schema_version": "sporespore_upper_mass_post_release_loaded_knee_rate_policy_v1",
			"controller_family_id": controller_family_id,
			"reference_upper_mass_kg": 0.25,
			"fixed_distal_mass_kg": 0.18,
			"hip_exponent": 1.0,
			"knee_exponent": 0.5,
			"minimum_impulse_scale": 0.80,
			"maximum_impulse_scale": 1.0,
			"reference_knee_flexion_scale": 1.75,
			"heavy_endpoint_knee_flexion_scale": 1.30,
			"reference_swing_ticks": 72,
			"heavy_endpoint_swing_ticks": 60,
			"reference_speed_rad_s": 3.5,
			"heavy_endpoint_speed_rad_s": 2.5,
			"activation_start_offset_ticks":
			_um9_activation_start_offset_ticks(controller_family_id),
			"activation_predicate_id": "phase_windowed_contact_loaded_swing_knee",
			"activation_predicate_conditions":
			[
				"joint_role == knee_pitch",
				"local_phase_tick >= activation_start_phase_tick",
				"local_phase_tick < realized_swing_ticks",
				"foot_bears_floor == true",
				"upper_mass_kg > 0.250",
			],
			"heavy_ramp_start_upper_mass_kg": 0.25,
			"heavy_ramp_end_upper_mass_kg": 0.30,
			"contact_clearance_assist_rad": 0.40,
			"mass_ratio_formula": "(upper_mass_kg + 0.18) / (0.25 + 0.18)",
			"attenuation_ratio_formula": "min(mass_ratio, 1.0 / mass_ratio)",
			"hip_scale_formula": "clamp(pow(attenuation_ratio, 1.0), 0.80, 1.0)",
			"knee_scale_formula": "clamp(pow(attenuation_ratio, 0.5), 0.80, 1.0)",
			"heavy_fraction_formula": "clamp((upper_mass_kg - 0.25) / (0.30 - 0.25), 0.0, 1.0)",
			"knee_flexion_scale_formula": "lerp(1.75, 1.30, heavy_fraction)",
			"swing_ticks_formula": "round(lerp(72, 60, heavy_fraction))",
			"activation_start_phase_tick_formula":
			"floor(realized_swing_ticks * 3 / 4) + activation_start_offset_ticks",
			"speed_formula": "lerp(3.5, 2.5, heavy_fraction)",
		}
	if _is_um10_controller_family(controller_family_id):
		return {
			"schema_version": "sporespore_upper_mass_release_gate_notch_policy_v1",
			"controller_family_id": controller_family_id,
			"reference_upper_mass_kg": 0.25,
			"fixed_distal_mass_kg": 0.18,
			"hip_exponent": 1.0,
			"knee_exponent": 0.5,
			"minimum_impulse_scale": 0.80,
			"maximum_impulse_scale": 1.0,
			"reference_knee_flexion_scale": 1.75,
			"heavy_endpoint_knee_flexion_scale": 1.30,
			"reference_swing_ticks": 72,
			"heavy_endpoint_swing_ticks": 60,
			"reference_speed_rad_s": 3.5,
			"heavy_endpoint_speed_rad_s": 2.5,
			"post_release_start_offset_ticks": 1,
			"pre_release_lead_ticks": _um10_pre_release_lead_ticks(controller_family_id),
			"activation_predicate_id": "release_gate_notched_contact_loaded_swing_knee",
			"activation_predicate_conditions":
			[
				"joint_role == knee_pitch",
				"local_phase_tick >= pre_release_start_phase_tick",
				"local_phase_tick < realized_swing_ticks",
				"local_phase_tick != release_gate_tick",
				"foot_bears_floor == true",
				"upper_mass_kg > 0.250",
			],
			"heavy_ramp_start_upper_mass_kg": 0.25,
			"heavy_ramp_end_upper_mass_kg": 0.30,
			"contact_clearance_assist_rad": 0.40,
			"mass_ratio_formula": "(upper_mass_kg + 0.18) / (0.25 + 0.18)",
			"attenuation_ratio_formula": "min(mass_ratio, 1.0 / mass_ratio)",
			"hip_scale_formula": "clamp(pow(attenuation_ratio, 1.0), 0.80, 1.0)",
			"knee_scale_formula": "clamp(pow(attenuation_ratio, 0.5), 0.80, 1.0)",
			"heavy_fraction_formula": "clamp((upper_mass_kg - 0.25) / (0.30 - 0.25), 0.0, 1.0)",
			"knee_flexion_scale_formula": "lerp(1.75, 1.30, heavy_fraction)",
			"swing_ticks_formula": "round(lerp(72, 60, heavy_fraction))",
			"pre_release_start_phase_tick_formula":
			"floor(realized_swing_ticks * 3 / 4) - pre_release_lead_ticks",
			"release_gate_tick_formula": "floor(realized_swing_ticks * 3 / 4)",
			"speed_formula": "lerp(3.5, 2.5, heavy_fraction)",
		}
	if not _is_um7_controller_family(controller_family_id):
		return {}
	return {
		"schema_version": "sporespore_upper_mass_heavy_swing_timing_policy_v1",
		"controller_family_id": controller_family_id,
		"reference_upper_mass_kg": 0.25,
		"fixed_distal_mass_kg": 0.18,
		"hip_exponent": 1.0,
		"knee_exponent": 0.5,
		"minimum_impulse_scale": 0.80,
		"maximum_impulse_scale": 1.0,
		"light_side_knee_flexion_scale": 1.75,
		"heavy_endpoint_knee_flexion_scale": 1.30,
		"light_side_swing_ticks": 72,
		"heavy_endpoint_swing_ticks": _um7_endpoint_swing_ticks(controller_family_id),
		"heavy_ramp_start_upper_mass_kg": 0.25,
		"heavy_ramp_end_upper_mass_kg": 0.30,
		"contact_clearance_assist_rad": 0.40,
		"mass_ratio_formula": "(upper_mass_kg + 0.18) / (0.25 + 0.18)",
		"attenuation_ratio_formula": "min(mass_ratio, 1.0 / mass_ratio)",
		"hip_scale_formula": "clamp(pow(attenuation_ratio, 1.0), 0.80, 1.0)",
		"knee_scale_formula": "clamp(pow(attenuation_ratio, 0.5), 0.80, 1.0)",
		"heavy_fraction_formula": "clamp((upper_mass_kg - 0.25) / (0.30 - 0.25), 0.0, 1.0)",
		"knee_flexion_scale_formula": "lerp(1.75, 1.30, heavy_fraction)",
		"swing_ticks_formula": "round(lerp(72, heavy_endpoint_swing_ticks, heavy_fraction))",
		"release_gate_tick_formula": "floor(realized_swing_ticks * 3 / 4)",
		"recontact_gate_tick_formula":
		"realized_swing_ticks + floor((360 - realized_swing_ticks) / 4)",
	}


static func _is_um2_controller_family(controller_family_id: String) -> bool:
	return (
		[
			CONTROLLER_FAMILY_UM2_A,
			CONTROLLER_FAMILY_UM2_B,
			CONTROLLER_FAMILY_UM2_C,
		]
		. has(controller_family_id)
	)


static func _is_um3_controller_family(controller_family_id: String) -> bool:
	return (
		[
			CONTROLLER_FAMILY_UM3_A,
			CONTROLLER_FAMILY_UM3_B,
			CONTROLLER_FAMILY_UM3_C,
		]
		. has(controller_family_id)
	)


static func _is_um4_controller_family(controller_family_id: String) -> bool:
	return (
		[
			CONTROLLER_FAMILY_UM4_A,
			CONTROLLER_FAMILY_UM4_B,
			CONTROLLER_FAMILY_UM4_C,
		]
		. has(controller_family_id)
	)


static func _is_um5_controller_family(controller_family_id: String) -> bool:
	return (
		[
			CONTROLLER_FAMILY_UM5_A,
			CONTROLLER_FAMILY_UM5_B,
			CONTROLLER_FAMILY_UM5_C,
		]
		. has(controller_family_id)
	)


static func _is_um6_controller_family(controller_family_id: String) -> bool:
	return (
		[
			CONTROLLER_FAMILY_UM6_A,
			CONTROLLER_FAMILY_UM6_B,
			CONTROLLER_FAMILY_UM6_C,
		]
		. has(controller_family_id)
	)


static func _is_um7_controller_family(controller_family_id: String) -> bool:
	return (
		[
			CONTROLLER_FAMILY_UM7_A,
			CONTROLLER_FAMILY_UM7_B,
			CONTROLLER_FAMILY_UM7_C,
		]
		. has(controller_family_id)
	)


static func _is_um8_controller_family(controller_family_id: String) -> bool:
	return (
		[
			CONTROLLER_FAMILY_UM8_A,
			CONTROLLER_FAMILY_UM8_B,
			CONTROLLER_FAMILY_UM8_C,
		]
		. has(controller_family_id)
	)


static func _is_um9_controller_family(controller_family_id: String) -> bool:
	return (
		[
			CONTROLLER_FAMILY_UM9_A,
			CONTROLLER_FAMILY_UM9_B,
			CONTROLLER_FAMILY_UM9_C,
		]
		. has(controller_family_id)
	)


static func _is_um10_controller_family(controller_family_id: String) -> bool:
	return (
		[
			CONTROLLER_FAMILY_UM10_A,
			CONTROLLER_FAMILY_UM10_B,
			CONTROLLER_FAMILY_UM10_C,
		]
		. has(controller_family_id)
	)


static func _is_upper_mass_adaptive_controller_family(controller_family_id: String) -> bool:
	return (
		_is_um2_controller_family(controller_family_id)
		or _is_um3_controller_family(controller_family_id)
		or _is_um4_controller_family(controller_family_id)
		or _is_um5_controller_family(controller_family_id)
		or _is_um6_controller_family(controller_family_id)
		or _is_um7_controller_family(controller_family_id)
		or _is_um8_controller_family(controller_family_id)
		or _is_um9_controller_family(controller_family_id)
		or _is_um10_controller_family(controller_family_id)
	)


static func _um2_exponent(controller_family_id: String) -> float:
	return float(
		(
			{
				CONTROLLER_FAMILY_UM2_A: 0.5,
				CONTROLLER_FAMILY_UM2_B: 1.0,
				CONTROLLER_FAMILY_UM2_C: 1.5,
			}
			. get(controller_family_id, NAN)
		)
	)


static func _um3_hip_exponent(controller_family_id: String) -> float:
	return float(
		(
			{
				CONTROLLER_FAMILY_UM3_A: 0.5,
				CONTROLLER_FAMILY_UM3_B: 1.0,
				CONTROLLER_FAMILY_UM3_C: 1.5,
			}
			. get(controller_family_id, NAN)
		)
	)


static func _upper_mass_actuator_exponent(controller_family_id: String) -> float:
	if _is_um4_controller_family(controller_family_id):
		return 0.5
	if _is_um5_controller_family(controller_family_id):
		return _um5_hip_exponent(controller_family_id)
	if (
		_is_um6_controller_family(controller_family_id)
		or _is_um7_controller_family(controller_family_id)
		or _is_um8_controller_family(controller_family_id)
		or _is_um9_controller_family(controller_family_id)
		or _is_um10_controller_family(controller_family_id)
	):
		return 1.0
	return (
		_um2_exponent(controller_family_id)
		if _is_um2_controller_family(controller_family_id)
		else _um3_hip_exponent(controller_family_id)
	)


static func _um5_hip_exponent(controller_family_id: String) -> float:
	return float(
		(
			{
				CONTROLLER_FAMILY_UM5_A: 0.5,
				CONTROLLER_FAMILY_UM5_B: 1.0,
				CONTROLLER_FAMILY_UM5_C: 1.5,
			}
			. get(controller_family_id, NAN)
		)
	)


static func _um4_knee_exponent(controller_family_id: String) -> float:
	return float(
		(
			{
				CONTROLLER_FAMILY_UM4_A: 0.5,
				CONTROLLER_FAMILY_UM4_B: 1.0,
				CONTROLLER_FAMILY_UM4_C: 1.5,
			}
			. get(controller_family_id, NAN)
		)
	)


static func _um6_endpoint_knee_flexion_scale(controller_family_id: String) -> float:
	return float(
		(
			{
				CONTROLLER_FAMILY_UM6_A: 1.60,
				CONTROLLER_FAMILY_UM6_B: 1.45,
				CONTROLLER_FAMILY_UM6_C: 1.30,
			}
			. get(controller_family_id, NAN)
		)
	)


static func _um6_heavy_fraction(requested_upper_mass_kg: float) -> float:
	return clampf(
		(requested_upper_mass_kg - REFERENCE_UPPER_MASS_KG) / (0.30 - REFERENCE_UPPER_MASS_KG),
		0.0,
		1.0,
	)


static func _um7_endpoint_swing_ticks(controller_family_id: String) -> int:
	return int(
		(
			{
				CONTROLLER_FAMILY_UM7_A: 68,
				CONTROLLER_FAMILY_UM7_B: 64,
				CONTROLLER_FAMILY_UM7_C: 60,
			}
			. get(controller_family_id, -1)
		)
	)


static func _um8_endpoint_speed_rad_s(controller_family_id: String) -> float:
	return float(
		(
			{
				CONTROLLER_FAMILY_UM8_A: 2.50,
				CONTROLLER_FAMILY_UM8_B: 1.50,
				CONTROLLER_FAMILY_UM8_C: 0.75,
			}
			. get(controller_family_id, NAN)
		)
	)


static func _um9_activation_start_offset_ticks(controller_family_id: String) -> int:
	return int(
		(
			{
				CONTROLLER_FAMILY_UM9_A: 1,
				CONTROLLER_FAMILY_UM9_B: 3,
				CONTROLLER_FAMILY_UM9_C: 6,
			}
			. get(controller_family_id, -1)
		)
	)


static func _um10_pre_release_lead_ticks(controller_family_id: String) -> int:
	return int(
		(
			{
				CONTROLLER_FAMILY_UM10_A: 4,
				CONTROLLER_FAMILY_UM10_B: 6,
				CONTROLLER_FAMILY_UM10_C: 9,
			}
			. get(controller_family_id, -1)
		)
	)


static func _um2_actuator_impulse_scale(
	controller_family_id: String,
	requested_upper_mass_kg: float,
) -> float:
	var mass_ratio := (requested_upper_mass_kg + 0.18) / (0.25 + 0.18)
	return clampf(pow(mass_ratio, _um2_exponent(controller_family_id)), 0.80, 1.25)


static func _um3_hip_impulse_scale(
	controller_family_id: String,
	requested_upper_mass_kg: float,
) -> float:
	var mass_ratio := (requested_upper_mass_kg + 0.18) / (0.25 + 0.18)
	return clampf(pow(mass_ratio, _um3_hip_exponent(controller_family_id)), 0.80, 1.25)


static func _requested_hip_impulse_scale(actuator_options: Dictionary) -> float:
	if actuator_options.has("hip_impulse_scale"):
		return float(actuator_options["hip_impulse_scale"])
	return float(actuator_options.get("actuator_impulse_scale", 1.0))


static func _requested_knee_impulse_scale(actuator_options: Dictionary) -> float:
	if actuator_options.has("knee_impulse_scale"):
		return float(actuator_options["knee_impulse_scale"])
	return float(actuator_options.get("actuator_impulse_scale", 1.0))


static func _maximum_anchor_error_context_exact(summary: Dictionary) -> bool:
	var context: Dictionary = summary.get("maximum_anchor_error_context", {})
	var local_phase_tick := int(context.get("local_phase_tick", -1))
	return (
		not context.is_empty()
		and (
			String(context.get("joint_id", ""))
			== String(summary.get("maximum_anchor_error_joint_id", ""))
		)
		and int(context.get("tick", -1)) == int(summary.get("maximum_anchor_error_tick", -1))
		and ["hip_pitch", "knee_pitch"].has(String(context.get("joint_role", "")))
		and local_phase_tick >= 0
		and local_phase_tick < 360
		and int(context.get("gait_tick", -1)) >= 0
		and is_finite(float(context.get("gait_amplitude", NAN)))
		and is_finite(float(context.get("target_angle_rad", NAN)))
		and is_finite(float(context.get("target_velocity_rad_s", NAN)))
		and is_finite(float(context.get("maximum_target_speed_rad_s", NAN)))
		and typeof(context.get("contact_loaded_speed_cap_active", null)) == TYPE_BOOL
		and int(context.get("contact_loaded_speed_cap_activation_start_phase_tick", -1)) >= 0
		and (int(context.get("contact_loaded_speed_cap_full_speed_override_phase_tick", -2)) >= -1)
		and is_finite(float(context.get("measured_angle_rad", NAN)))
		and is_finite(float(context.get("measured_rate_rad_s", NAN)))
		and typeof(context.get("swing_phase", null)) == TYPE_BOOL
		and typeof(context.get("foot_bears_floor", null)) == TYPE_BOOL
	)


static func _nonnegative_limb_integer_receipt_exact(receipt_value: Variant) -> bool:
	if typeof(receipt_value) != TYPE_DICTIONARY:
		return false
	var receipt: Dictionary = receipt_value
	var expected_limb_ids := ["front_left", "front_right", "rear_left", "rear_right"]
	if receipt.size() != expected_limb_ids.size():
		return false
	for limb_id in expected_limb_ids:
		if not receipt.has(limb_id) or typeof(receipt[limb_id]) != TYPE_INT:
			return false
		if int(receipt[limb_id]) < 0:
			return false
	return true


static func _only_mass_axis_differs(
	reference_fixture: Dictionary,
	realized_fixture: Dictionary,
	fixture_variation_axis: String,
	requested_mass_kg: float,
) -> bool:
	var expected := reference_fixture.duplicate(true)
	_set_mass_axis(expected, fixture_variation_axis, requested_mass_kg)
	return expected == realized_fixture


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
