extends SceneTree
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## G3 one-world nonuniform-proportion physical probe.
##
## No-argument and policy-receipt modes construct no physics world. The
## campaign runner supplies one preregistered campaign, morphology, role, and
## repetition per isolated process. Three-argument G3-GP1 calls remain accepted
## so the already sealed GP1 evidence can be reproduced byte-for-byte.

const ProportionSpecScript := preload(
	"res://scripts/lab/gait/physical_quadruped_proportion_spec.gd"
)
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const ClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")
const WaveGaitScript := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FeatureReceiptScript := preload(
	"res://scripts/lab/gait/morphology_feature_receipt.gd"
)
const CoverageReceiptScript := preload(
	"res://scripts/lab/gait/morphology_coverage_receipt.gd"
)
const DynamicSupportReceiptScript := preload(
	"res://scripts/lab/mechanics/dynamic_support_diagnostic_receipt.gd"
)

const CAMPAIGN_GP1 := "G3-GP1"
const CAMPAIGN_GP2 := "G3-GP2"
const CAMPAIGN_GP3 := "G3-GP3"
const CAMPAIGN_GP4 := "G3-GP4"
const CAMPAIGN_GP5 := "G3-GP5"
const CAMPAIGN_GQ1 := "G4-GQ1"
const CAMPAIGN_GQ2 := "G4-GQ2"
const CAMPAIGN_GQ3 := "G4-GQ3"
const CAMPAIGN_GQ4 := "G4-GQ4"
const CAMPAIGN_GQ5 := "G4-GQ5"
const CAMPAIGN_GQ6 := "G4-GQ6"
const CAMPAIGN_GQ7 := "G4-GQ7"
const CAMPAIGN_GQ8 := "G4-GQ8"
const CAMPAIGN_GQ9 := "G4-GQ9"
const CAMPAIGN_GQ10 := "G4-GQ10"
const CAMPAIGN_GQ11 := "G4-GQ11"
const CAMPAIGN_GQ12 := "G4-GQ12"
const CAMPAIGN_GQ13 := "G4-GQ13"
const CAMPAIGN_GQ14 := "G4-GQ14"
const CAMPAIGN_GQ15 := "G4-GQ15"
const SDK_NATIVE_AUTHORITY_ARGUMENT := "sdk-native-authority"
const SDK_BW2_AUTHORITY_ARGUMENTS := {
	"balanced-wave-bw2-a":
	{
		"candidate_id": "BW2-A",
		"policy_id": "sporespore_balanced_wave_v1",
		"policy_digest": "sha256:d1ce56ba1a74f843700559e1b240c3a5a4ea33c31d7a14d874fdd2c6ebfb2fd9",
	},
	"balanced-wave-bw2-b":
	{
		"candidate_id": "BW2-B",
		"policy_id": "sporespore_balanced_wave_bw2_b_v1",
		"policy_digest": "sha256:0ab4fa4c4e37441b26bdd00d23926e4511892201150bf61554c5b1362edf7913",
	},
	"balanced-wave-bw2-c":
	{
		"candidate_id": "BW2-C",
		"policy_id": "sporespore_balanced_wave_bw2_c_v1",
		"policy_digest": "sha256:367e944b33384d8685d746dca0a864cfa33ca013846636236512641456d51ad3",
	},
	"balanced-wave-bw2r-a":
	{
		"candidate_id": "BW2R-A",
		"policy_id": "sporespore_balanced_wave_bw2r_a_v1",
		"policy_digest": "sha256:4ffb7abd947f60287b81c9105fb99b2964355d0e16e13b64bc8b18d9fcec6343",
	},
	"balanced-wave-bw2r-b":
	{
		"candidate_id": "BW2R-B",
		"policy_id": "sporespore_balanced_wave_bw2r_b_v1",
		"policy_digest": "sha256:44e8bfd0e4e1227db56ace8c58fc62fa6dd6bfc0d1cb993367510214272da144",
	},
	"balanced-wave-bw2r-c":
	{
		"candidate_id": "BW2R-C",
		"policy_id": "sporespore_balanced_wave_bw2r_c_v1",
		"policy_digest": "sha256:709aacc898e62a0c1902a04a201006f5501934562cabec4b68c1613811ae0ad0",
	},
	"balanced-wave-bw4r-a":
	{
		"candidate_id": "BW4R-A",
		"policy_id": "sporespore_balanced_wave_bw4r_a_v1",
		"policy_digest": "sha256:40dc551e99fea518df68c35d49e3d7d9605484e25cb385f938b3568ddcab2cf4",
	},
	"balanced-wave-bw4r-b":
	{
		"candidate_id": "BW4R-B",
		"policy_id": "sporespore_balanced_wave_bw4r_b_v1",
		"policy_digest": "sha256:2496dc6da6dea17cfc7ffee0027234fa7a2a0f4eea8bc463a68db9a9d105bae7",
	},
	"balanced-wave-bw5r-a":
	{
		"candidate_id": "BW5R-A",
		"policy_id": "sporespore_balanced_wave_bw5r_a_v1",
		"policy_digest": "sha256:6001dd2b5926908a1bad16d17e49e233cbfb1dfa7eb360bdfe8e4df147b245ac",
	},
	"balanced-wave-bw5r-b":
	{
		"candidate_id": "BW5R-B",
		"policy_id": "sporespore_balanced_wave_bw5r_b_v1",
		"policy_digest": "sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f",
	},
	"balanced-wave-bw5r-c":
	{
		"candidate_id": "BW5R-C",
		"policy_id": "sporespore_balanced_wave_bw5r_c_v1",
		"policy_digest": "sha256:c067ece936a53edb9cc9d667a68274451e4db67b762ab262bf42e8efe88d742d",
	},
}
const SDK_COMPARISON_TOLERANCE := 2.5e-7
const SDK_BW2_COMPARISON_TOLERANCE := 2.0e-8
const SDK_BW2_FEEDBACK_POLICY_ID := "p5i3c_support_centroid_tilt_feedback_v1"
const SDK_BW2_MATERIAL_PROFILE_ID := "godot_jolt_legacy_mu180_d3d5cd1_v1"
const SDK_MAXIMUM_POSITION_MAPPING_ERROR_RAD := 2.0e-8
const SDK_MAXIMUM_VELOCITY_MAPPING_ERROR_RAD_S := 2.5e-7
const SDK_MAXIMUM_SPEED_LIMIT_MAPPING_ERROR_RAD_S := 1.0e-12
const SDK_MAXIMUM_STEERING_MAPPING_ERROR := 2.0e-8
const REFERENCE_CONTROLLER_SHA256 := "sha256:9c6d7962e81da4d1831ac0a99999db46cd87ce3271600e0f8bb5a72beaed4ef6"
const GP3_CONTROLLER_SHA256 := "sha256:7e505e23b8c0967bf2702de3aa711986deca9cc5862284e6646e9a9bc7a61172"
const ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 96,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const GQ6_ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const GQ7_ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const GQ8_ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const GQ9_ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const GQ10_ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const GQ11_ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const GQ12_ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const GQ13_ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const GQ14_ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const GQ15_ROBUSTNESS_OPTIONS := {
	"contact_gated_phase_progression": true,
	"maximum_contact_gate_hold_ticks": 120,
	"maximum_contact_gated_phase_skew_ticks": 12,
	"lateral_stride_steering_gain_per_m": 0.0,
}
const PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.5,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.20,
}
const GP3_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.20,
}
const GQ2_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.20,
}
const GQ3_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"yaw_error_stride_gain_per_rad": 1.3,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.20,
}
const GQ4_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.20,
}
const GQ5_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.20,
}
const GQ6_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.25,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.40,
}
const GQ7_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.25,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.40,
}
const GQ8_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.30,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.40,
}
const GQ9_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.35,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.40,
}
const GQ10_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.35,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.40,
}
const GQ11_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.35,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.40,
}
const GQ12_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.35,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.40,
}
const GQ13_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.35,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.40,
}
const GQ14_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.25,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.40,
}
const GQ15_PATH_STEERING_OPTIONS := {
	"phase_bounded_path_steering_enabled": true,
	"cross_track_heading_gain_rad_per_m": 0.75,
	"cross_track_velocity_heading_gain_rad_per_m_s": 0.25,
	"yaw_error_stride_gain_per_rad": 1.0,
	"steering_update_interval_ticks": 90,
	"maximum_desired_heading_error_rad": 0.25,
	"maximum_steering_fraction": 0.40,
}
const GP3_ACTUATOR_IMPULSE_OPTIONS := {
	"mass_adaptive_actuator_enabled": true,
	"actuator_policy_id": "g3_gp3_global_actuator_margin_v1",
	"actuator_impulse_scale": 1.015,
}
const GP4_SOLVER_POLICY_OPTIONS := {
	"solver_policy_id": "jolt_120hz_20v_7p_v1",
	"physics_engine": "Jolt Physics",
	"physics_hz": 120,
	"solver_velocity_steps": 20,
	"solver_position_steps": 7,
}
const GP5_MOTOR_VELOCITY_OPTIONS := {
	"mass_adaptive_motor_velocity_enabled": true,
	"motor_velocity_policy_id": "g3_gp5_morphology_interaction_anchor_guard_v1",
	"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s": 3.5,
	"anchor_error_guard_enabled": true,
	"morphology_interaction_score": 0.0,
	"anchor_error_guard_activation_fraction": 0.90,
	"anchor_error_guard_maximum_motor_target_speed_rad_s": 2.5,
}

var _passed := 0
var _failed := 0
var _sdk_bw2_candidate_id := "BW2-A"
var _sdk_bw2_policy_id := "sporespore_balanced_wave_v1"
var _sdk_bw2_policy_digest := (
	"sha256:d1ce56ba1a74f843700559e1b240c3a5a4ea33c31d7a14d874fdd2c6ebfb2fd9"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Experimental BR14A.11 G3 nonuniform wave gait ===")
	var user_args := OS.get_cmdline_user_args()
	if user_args.is_empty():
		_check(
			true,
			"nonuniform-proportion probing remains campaign-only without a supplied cell",
		)
		_finish()
		return
	var policy_receipt_requested := (
		(user_args.size() == 1 or user_args.size() == 2)
		and String(user_args[0]) == "policy-receipt"
	)
	if policy_receipt_requested:
		var receipt_campaign := String(user_args[1]) if user_args.size() == 2 else CAMPAIGN_GP1
		var receipt_campaign_exact := _campaign_supported(receipt_campaign)
		_check(
			receipt_campaign_exact,
			"policy receipt names a supported preregistered G3 campaign",
		)
		if not receipt_campaign_exact:
			_finish()
			return
		var policy := _formula_policy(receipt_campaign)
		var policy_digest := CanonicalJsonScript.sha256(policy)
		_check(
			String(policy["campaign_id"]) == receipt_campaign,
			"policy receipt retains the requested preregistered G3 campaign",
		)
		_check(
			policy_digest.begins_with("sha256:") and policy_digest.length() == 71,
			"formula-complete G3 policy seals without constructing a world",
		)
		print(
			(
				"NONUNIFORM_PROPORTION_POLICY_RECEIPT campaign=%s policy_digest=%s"
				% [receipt_campaign, policy_digest]
			)
		)
		_finish()
		return

	var legacy_gp1_arguments := user_args.size() == 3
	var sdk_native_authority_enabled := (
		user_args.size() == 5
		and String(user_args[0]) == CAMPAIGN_GQ15
		and String(user_args[4]) == SDK_NATIVE_AUTHORITY_ARGUMENT
	)
	var sdk_bw2_authority_argument := (
		String(user_args[4]) if user_args.size() == 5 else ""
	)
	var sdk_bw2_authority_enabled := (
		user_args.size() == 5
		and String(user_args[0]) == CAMPAIGN_GQ15
		and SDK_BW2_AUTHORITY_ARGUMENTS.has(sdk_bw2_authority_argument)
	)
	if sdk_bw2_authority_enabled:
		var selected_bw2: Dictionary = SDK_BW2_AUTHORITY_ARGUMENTS[sdk_bw2_authority_argument]
		_sdk_bw2_candidate_id = String(selected_bw2["candidate_id"])
		_sdk_bw2_policy_id = String(selected_bw2["policy_id"])
		_sdk_bw2_policy_digest = String(selected_bw2["policy_digest"])
	var arguments_exact := (
		legacy_gp1_arguments
		or user_args.size() == 4
		or sdk_native_authority_enabled
		or sdk_bw2_authority_enabled
	)
	var argument_offset := 0 if legacy_gp1_arguments else 1
	var campaign_id := (
		CAMPAIGN_GP1 if legacy_gp1_arguments else (String(user_args[0]) if arguments_exact else "")
	)
	var campaign_exact := _campaign_supported(campaign_id)
	var morphology_id := (
		String(user_args[argument_offset]) if arguments_exact and campaign_exact else ""
	)
	var campaign_role := (
		String(user_args[argument_offset + 1]) if arguments_exact and campaign_exact else ""
	)
	var repetition := (
		String(user_args[argument_offset + 2]).to_int()
		if arguments_exact and campaign_exact
		else -1
	)
	var declared := (
		ProportionSpecScript.declared_cell(morphology_id, campaign_role, campaign_id)
		if arguments_exact and campaign_exact
		else {}
	)
	var generation_result: Dictionary = (
		(
			ProportionSpecScript.gq15_generation_for_morphology(morphology_id, campaign_role)
			if campaign_id == CAMPAIGN_GQ15
			else (
				ProportionSpecScript.gq14_generation_for_morphology(morphology_id, campaign_role)
				if campaign_id == CAMPAIGN_GQ14
				else (
					ProportionSpecScript.gq13_generation_for_morphology(morphology_id, campaign_role)
					if campaign_id == CAMPAIGN_GQ13
					else (
						ProportionSpecScript.gq12_generation_for_morphology(morphology_id, campaign_role)
						if campaign_id == CAMPAIGN_GQ12
						else (
							ProportionSpecScript.gq11_generation_for_morphology(
								morphology_id,
								campaign_role,
							)
							if campaign_id == CAMPAIGN_GQ11
							else (
								(
									ProportionSpecScript
									. gq10_generation_for_morphology(
										morphology_id,
										campaign_role,
									)
								)
								if campaign_id == CAMPAIGN_GQ10
								else (
									(
										ProportionSpecScript
										. gq9_generation_for_morphology(
											morphology_id,
											campaign_role,
										)
									)
									if campaign_id == CAMPAIGN_GQ9
									else (
										(
											ProportionSpecScript
											. gq8_generation_for_morphology(
												morphology_id,
												campaign_role,
											)
										)
										if campaign_id == CAMPAIGN_GQ8
										else (
											(
												ProportionSpecScript
												. gq7_generation_for_morphology(
													morphology_id,
													campaign_role,
												)
											)
											if campaign_id == CAMPAIGN_GQ7
											else (
												(
													ProportionSpecScript
													. gq6_generation_for_morphology(
														morphology_id,
														campaign_role,
													)
												)
												if campaign_id == CAMPAIGN_GQ6
												else (
													(
														ProportionSpecScript
														. gq5_generation_for_morphology(
															morphology_id,
															campaign_role,
														)
													)
													if campaign_id == CAMPAIGN_GQ5
													else (
														(
															ProportionSpecScript
															. gq4_generation_for_morphology(
																morphology_id,
																campaign_role,
															)
														)
														if campaign_id == CAMPAIGN_GQ4
														else (
															(
																ProportionSpecScript
																. gq3_generation_for_morphology(
																	morphology_id,
																	campaign_role,
																)
															)
															if campaign_id == CAMPAIGN_GQ3
															else (
																(
																	ProportionSpecScript
																	. gq2_generation_for_morphology(
																		morphology_id,
																		campaign_role,
																	)
																)
																if campaign_id == CAMPAIGN_GQ2
																else (
																	ProportionSpecScript
																	. gq1_generation_for_morphology(
																		morphology_id,
																		campaign_role,
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
		if (
			(
				campaign_id == CAMPAIGN_GQ1
				or campaign_id == CAMPAIGN_GQ2
				or campaign_id == CAMPAIGN_GQ3
				or campaign_id == CAMPAIGN_GQ4
				or campaign_id == CAMPAIGN_GQ5
				or campaign_id == CAMPAIGN_GQ6
				or campaign_id == CAMPAIGN_GQ7
				or campaign_id == CAMPAIGN_GQ8
				or campaign_id == CAMPAIGN_GQ9
				or campaign_id == CAMPAIGN_GQ10
				or campaign_id == CAMPAIGN_GQ11
				or campaign_id == CAMPAIGN_GQ12
				or campaign_id == CAMPAIGN_GQ13
				or campaign_id == CAMPAIGN_GQ14
				or campaign_id == CAMPAIGN_GQ15
			)
			and arguments_exact
		)
		else {}
	)
	var generation_exact := (
		(
			campaign_id != CAMPAIGN_GQ1
			and campaign_id != CAMPAIGN_GQ2
			and campaign_id != CAMPAIGN_GQ3
			and campaign_id != CAMPAIGN_GQ4
			and campaign_id != CAMPAIGN_GQ5
			and campaign_id != CAMPAIGN_GQ6
			and campaign_id != CAMPAIGN_GQ7
			and campaign_id != CAMPAIGN_GQ8
			and campaign_id != CAMPAIGN_GQ9
			and campaign_id != CAMPAIGN_GQ10
			and campaign_id != CAMPAIGN_GQ11
			and campaign_id != CAMPAIGN_GQ12
			and campaign_id != CAMPAIGN_GQ13
			and campaign_id != CAMPAIGN_GQ14
			and campaign_id != CAMPAIGN_GQ15
		)
		or (
			bool(generation_result.get("ok", false))
			and int(generation_result.get("world_build_count", -1)) == 0
			and (generation_result.get("proportion_spec", {}) as Dictionary) == declared
		)
	)
	var declared_cell_exact := (
		arguments_exact
		and campaign_exact
		and (campaign_role == "selection" or campaign_role == "heldout")
		and (
			(campaign_role == "selection" and repetition == 0)
			or (campaign_role == "heldout" and repetition >= 1 and repetition <= 3)
		)
		and not declared.is_empty()
		and generation_exact
	)
	_check(
		declared_cell_exact,
		"campaign, morphology, role, and repetition match the preregistered grid",
	)
	if not declared_cell_exact:
		_finish()
		return

	var policy := _formula_policy(campaign_id)
	var policy_digest := CanonicalJsonScript.sha256(policy)
	var generation_digest := String(generation_result.get("generator_receipt_sha256", "none"))
	var path_steering_options := _path_steering_options(campaign_id, declared)
	var actuator_impulse_options := _actuator_impulse_options(campaign_id)
	var motor_velocity_options := _motor_velocity_options(campaign_id, declared)
	var solver_policy_options := _solver_policy_options(campaign_id)
	var solver_policy_result := WaveGaitScript.compile_solver_policy_options(solver_policy_options)
	var expected_solver_policy_options: Dictionary = (
		solver_policy_result
		. get(
			"solver_policy_options",
			{},
		)
	)
	var solver_policy_digest := String(
		solver_policy_result.get("solver_policy_configuration_sha256", "")
	)
	var robustness_options := _robustness_options(campaign_id)
	var expected_controller_digest := _expected_controller_sha256(
		campaign_id,
		motor_velocity_options,
		path_steering_options,
	)
	var clock_result := (
		ClockSpecScript.compile(ClockSpecScript.gq15_clock())
		if campaign_id == CAMPAIGN_GQ15
		else (
			ClockSpecScript.compile(ClockSpecScript.gq14_clock())
			if campaign_id == CAMPAIGN_GQ14
			else (
				ClockSpecScript.compile(ClockSpecScript.gq13_clock())
				if campaign_id == CAMPAIGN_GQ13
				else (
					ClockSpecScript.compile(ClockSpecScript.gq12_clock())
					if campaign_id == CAMPAIGN_GQ12
					else (
						ClockSpecScript.compile(ClockSpecScript.gq11_clock())
						if campaign_id == CAMPAIGN_GQ11
						else (
							ClockSpecScript.compile(ClockSpecScript.gq10_clock())
							if campaign_id == CAMPAIGN_GQ10
							else (
								ClockSpecScript.compile(ClockSpecScript.gq9_clock())
								if campaign_id == CAMPAIGN_GQ9
								else (
									ClockSpecScript.compile(ClockSpecScript.gq8_clock())
									if campaign_id == CAMPAIGN_GQ8
									else (
										ClockSpecScript.compile(ClockSpecScript.gq7_clock())
										if campaign_id == CAMPAIGN_GQ7
										else (
											ClockSpecScript.compile(ClockSpecScript.gq6_clock())
											if campaign_id == CAMPAIGN_GQ6
											else ClockSpecScript.dynamic_similarity_clock(1.0)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	)
	var gait_clock: Dictionary = clock_result.get("gait_clock_options", {})
	var gait_clock_digest := CanonicalJsonScript.sha256(gait_clock)
	_check(
		(
			policy_digest.begins_with("sha256:")
			and policy_digest.length() == 71
			and gait_clock_digest.begins_with("sha256:")
			and gait_clock_digest.length() == 71
			and bool(solver_policy_result.get("ok", false))
			and solver_policy_digest.begins_with("sha256:")
			and solver_policy_digest.length() == 71
		),
		"formula policy and fixed unit gait-clock digests seal before the world",
	)

	var compiled := ProportionSpecScript.compile(declared)
	var feature_result: Dictionary = {}
	var coverage_result: Dictionary = {}
	var feature_coverage_exact := (
		campaign_id != CAMPAIGN_GQ13
		and campaign_id != CAMPAIGN_GQ14
		and campaign_id != CAMPAIGN_GQ15
	)
	if (
		bool(compiled.get("ok", false))
		and campaign_id in [CAMPAIGN_GQ13, CAMPAIGN_GQ14, CAMPAIGN_GQ15]
	):
		feature_result = FeatureReceiptScript.compile(
			generation_result,
			compiled,
			expected_controller_digest,
			gait_clock,
			expected_solver_policy_options,
		)
		var cohort_feature_results := (
			_gq15_candidate35_cohort_feature_results()
			if campaign_id == CAMPAIGN_GQ15
			else (
				_gq14_candidate34_cohort_feature_results()
				if campaign_id == CAMPAIGN_GQ14
				else _gq13_candidate33_cohort_feature_results()
			)
		)
		if campaign_id == CAMPAIGN_GQ15:
			coverage_result = CoverageReceiptScript.compile_gq15(
				cohort_feature_results,
				feature_result,
			)
		else:
			coverage_result = (
				CoverageReceiptScript.compile_gq14(cohort_feature_results, feature_result)
				if campaign_id == CAMPAIGN_GQ14
				else CoverageReceiptScript.compile(cohort_feature_results, feature_result)
			)
		feature_coverage_exact = (
			_gq15_feature_coverage_exact(
				feature_result,
				coverage_result,
				generation_digest,
				String(compiled.get("fixture_spec_sha256", "")),
				expected_controller_digest,
			)
			if campaign_id == CAMPAIGN_GQ15
			else (
				_gq14_feature_coverage_exact(
					feature_result,
					coverage_result,
					generation_digest,
					String(compiled.get("fixture_spec_sha256", "")),
					expected_controller_digest,
				)
				if campaign_id == CAMPAIGN_GQ14
				else _gq13_feature_coverage_exact(
					feature_result,
					coverage_result,
					generation_digest,
					String(compiled.get("fixture_spec_sha256", "")),
					expected_controller_digest,
				)
			)
		)
	_check(
		(
			bool(compiled.get("ok", false))
			and int(compiled.get("world_build_count", -1)) == 0
			and feature_coverage_exact
		),
		"the declared morphology, static screen, and report-only receipts compile before world construction",
	)
	if not bool(compiled.get("ok", false)) or not feature_coverage_exact:
		print(
			"NONUNIFORM_PROPORTION_COMPILE_FAILURE ",
			{
				"proportion": compiled,
				"feature": feature_result,
				"coverage": coverage_result,
			},
		)
		_finish()
		return
	var fixture_spec: Dictionary = compiled["fixture_spec"]
	var parameter_digest := String(compiled["proportion_spec_sha256"])
	var fixture_digest := String(compiled["fixture_spec_sha256"])
	var static_digest := String(compiled["static_screen_sha256"])
	_check(
		(compiled["proportion_spec"] as Dictionary) == declared,
		"the normalized parameter receipt exactly matches the declared cell",
	)
	_check(
		_fixture_formula_exact(declared, fixture_spec),
		"the compiled fixture matches every preregistered proportion formula",
	)
	_check(
		_static_screen_exact(compiled),
		"floor, anchor, overlap, clearance, motor, and support screens all pass",
	)
	var reference_fixture_result := FixtureSpecScript.compile(FixtureSpecScript.reference_spec())
	_check(
		(
			fixture_digest == String(reference_fixture_result["fixture_spec_sha256"])
			if (
				morphology_id == "reference"
				or morphology_id == "gp2_reference"
				or morphology_id == "gp3_reference"
				or morphology_id == "gp4_reference"
				or morphology_id == "gp5_reference"
			)
			else fixture_digest != String(reference_fixture_result["fixture_spec_sha256"])
		),
		"reference identity or nonreference fixture distinction is exact",
	)
	_check(
		_unit_clock_exact(gait_clock, campaign_id),
		"the exact GS3 unit-scale timing and gains are retained for every shape",
	)

	var thresholds := _evidence_thresholds(fixture_spec, campaign_id)
	var compiled_thresholds := WaveGaitScript.compile_evidence_threshold_options(thresholds)
	var dynamic_support_options: Dictionary = {}
	var dynamic_support_options_result := {
		"ok": campaign_id not in [CAMPAIGN_GQ13, CAMPAIGN_GQ14, CAMPAIGN_GQ15],
		"world_build_count": 0,
	}
	if campaign_id in [CAMPAIGN_GQ13, CAMPAIGN_GQ14, CAMPAIGN_GQ15]:
		dynamic_support_options = (
			_gq15_dynamic_support_options(
				feature_result,
				coverage_result,
				generation_digest,
				fixture_digest,
				expected_controller_digest,
				gait_clock_digest,
				solver_policy_digest,
				float(thresholds["maximum_lateral_drift_m"]),
			)
			if campaign_id == CAMPAIGN_GQ15
			else (
				_gq14_dynamic_support_options(
					feature_result,
					coverage_result,
					generation_digest,
					fixture_digest,
					expected_controller_digest,
					gait_clock_digest,
					solver_policy_digest,
					float(thresholds["maximum_lateral_drift_m"]),
				)
				if campaign_id == CAMPAIGN_GQ14
				else _gq13_dynamic_support_options(
					feature_result,
					coverage_result,
					generation_digest,
					fixture_digest,
					expected_controller_digest,
					gait_clock_digest,
					solver_policy_digest,
					float(thresholds["maximum_lateral_drift_m"]),
				)
			)
		)
		dynamic_support_options_result = (
			WaveGaitScript
			. _normalize_dynamic_support_diagnostic_options(dynamic_support_options)
		)
	_check(
		(
			bool(compiled_thresholds.get("ok", false))
			and int(compiled_thresholds.get("world_build_count", -1)) == 0
			and (
				(compiled_thresholds.get("evidence_threshold_options", {}) as Dictionary)
				== thresholds
			)
			and bool(dynamic_support_options_result.get("ok", false))
			and int(dynamic_support_options_result.get("world_build_count", -1)) == 0
		),
		"fixture-derived thresholds and optional diagnostic source seals compile before the world",
	)
	if (
		not bool(compiled_thresholds.get("ok", false))
		or not bool(dynamic_support_options_result.get("ok", false))
	):
		print(
			"NONUNIFORM_PROPORTION_THRESHOLD_FAILURE ",
			{
				"thresholds": compiled_thresholds,
				"dynamic_support_options": dynamic_support_options_result,
			},
		)
		_finish()
		return
	var requested_perturbation := _requested_perturbation(campaign_role, repetition)
	_check(
		_requested_perturbation_exact(requested_perturbation, campaign_role, repetition),
		"the cell requests exactly the preregistered repetition perturbation",
	)
	var requested_sdk_authority_options: Dictionary = {}
	if sdk_native_authority_enabled or sdk_bw2_authority_enabled:
		var sdk_descriptor := {
			"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
			"morphology_id": morphology_id,
			"torso_length_scale": float(declared["torso_length_scale"]),
			"torso_width_scale": float(declared["torso_width_scale"]),
			"upper_length_fraction": float(declared["upper_length_fraction"]),
			"hip_span_scale": float(declared["hip_span_scale"]),
			"foot_radius_scale": float(declared["foot_radius_scale"]),
			"front_limb_mass_scale": float(declared["front_limb_mass_scale"]),
		}
		requested_sdk_authority_options = (
			{
				"enabled": true,
				"descriptor": sdk_descriptor,
				"comparison_tolerance": SDK_BW2_COMPARISON_TOLERANCE,
				"authority_scope": "stability_contribution_overlay",
				"stability_policy_id": SDK_BW2_FEEDBACK_POLICY_ID,
				"material_profile_id": SDK_BW2_MATERIAL_PROFILE_ID,
				"controller_policy_id": _sdk_bw2_policy_id,
			}
			if sdk_bw2_authority_enabled
			else {
				"enabled": true,
				"descriptor": sdk_descriptor,
				"comparison_tolerance": SDK_COMPARISON_TOLERANCE,
				"authority_scope": "post_settle_full",
			}
		)
		var sdk_authority_options_result := WaveGaitScript._normalize_sdk_authority_options(
			requested_sdk_authority_options
		)
		var sdk_preworld_exact := (
			bool(sdk_authority_options_result.get("ok", false))
			and int(sdk_authority_options_result.get("world_build_count", -1)) == 0
			and (
				(
					sdk_authority_options_result.get("sdk_authority_options", {})
					as Dictionary
				)
				== requested_sdk_authority_options
			)
		)
		_check(
			sdk_preworld_exact,
			"the GQ15 descriptor and native-authority options compile exactly before the world",
		)
		if not sdk_preworld_exact:
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
			int(gait_clock["swing_ticks"]),
			0.40,
			"all",
			int(gait_clock["evidence_boundary_alignment_ticks"]),
			false,
			requested_perturbation,
			robustness_options,
			fixture_spec,
			path_steering_options,
			actuator_impulse_options,
			motor_velocity_options,
			thresholds,
			gait_clock,
			solver_policy_options,
			dynamic_support_options,
			{},
			requested_sdk_authority_options,
		)
	)
	var world_executed := int(summary.get("world_build_count", 0)) == 1
	_check(world_executed, "one private physical world returns a complete summary")
	if not world_executed:
		print("NONUNIFORM_PROPORTION_WORLD_FAILURE ", summary)
		_finish()
		return
	_print_physical_diagnostics(summary)

	var controller_digest := String(summary.get("controller_configuration_sha256", ""))
	var threshold_digest := String(summary.get("evidence_threshold_configuration_sha256", ""))
	_check(
		(
			String(summary.get("fixture_spec_sha256", "")) == fixture_digest
			and (summary.get("fixture_spec", {}) as Dictionary) == fixture_spec
			and is_equal_approx(
				float(summary.get("fixture_view_scale", NAN)),
				float(declared["torso_length_scale"]),
			)
		),
		"the physical world preserves the compiled fixture and presentation receipt",
	)
	_check(
		(
			(summary.get("evidence_threshold_options", {}) as Dictionary) == thresholds
			and (
				threshold_digest
				== String(compiled_thresholds["evidence_threshold_configuration_sha256"])
			)
		),
		"the realized normalized-threshold receipt and digest are exact",
	)
	_check(
		(
			_controller_receipt_exact(
				summary,
				gait_clock,
				campaign_id,
				motor_velocity_options,
				path_steering_options,
			)
			and controller_digest == expected_controller_digest
		),
		"one campaign-pinned unit controller is byte-identical across morphologies",
	)
	_check(
		_perturbation_receipt_exact(
			summary.get("initial_perturbation", {}),
			campaign_role,
			repetition,
		),
		"the realized initial perturbation exactly matches the campaign receipt",
	)
	_check(
		(
			int(summary.get("body_count", 0)) == 9
			and int(summary.get("limb_count", 0)) == 4
			and int(summary.get("world_reset_count", -1)) == 0
			and int(summary.get("cycle_ticks", -1)) == 360
			and int(summary.get("swing_ticks", -1)) == 72
		),
		"nine free bodies retain the four-limb topology and fixed unit gait period",
	)
	_check(
		(
			int(summary.get("direct_torso_force_command_count", -1)) == 0
			and int(summary.get("direct_torso_impulse_command_count", -1)) == 0
			and int(summary.get("direct_torso_velocity_command_count", -1)) == 0
			and int(summary.get("direct_torso_transform_command_count", -1)) == 0
		),
		"no root force, impulse, velocity, transform, freeze, or teleport command appears",
	)
	_check(
		_realized_impulses_exact(summary, campaign_id),
		"realized hip and knee motor ceilings match the campaign-wide actuator policy",
	)
	_check(
		(
			String(summary.get("physics_engine", "")) == "Jolt Physics"
			and int(summary.get("physics_hz", -1)) == 120
			and int(summary.get("solver_velocity_steps", -1)) == 20
			and (
				int(summary.get("solver_position_steps", -1))
				== int(expected_solver_policy_options["solver_position_steps"])
			)
			and (
				(summary.get("solver_policy_options", {}) as Dictionary)
				== expected_solver_policy_options
			)
			and (
				(summary.get("realized_solver_policy_options", {}) as Dictionary)
				== expected_solver_policy_options
			)
			and (
				String(summary.get("solver_policy_configuration_sha256", ""))
				== solver_policy_digest
			)
		),
		"pinned Jolt solver settings execute in the isolated world",
	)
	_check(
		(
			_outcome_is_complete(summary)
			if sdk_bw2_authority_enabled
			else _all_true(summary.get("walking_gate_receipts", {}))
		),
		(
			"every walking gate returns a complete scored outcome"
			if sdk_bw2_authority_enabled
			else "every topology, contact, movement, recovery, and structural gate passes"
		),
	)
	_check(
		sdk_bw2_authority_enabled or _contact_progression_exact(summary, campaign_id),
		(
			"contact progression is retained as a scored outcome"
			if sdk_bw2_authority_enabled
			else "every limb completes the evidence horizon, two cycles, and zero gate timeouts"
		),
	)
	_check(
		sdk_bw2_authority_enabled or _normalized_metric_bounds_exact(summary, thresholds),
		(
			"normalized metric bounds are retained as scored outcomes"
			if sdk_bw2_authority_enabled
			else "measured movement and structure satisfy the fixture-derived bounds"
		),
	)
	_check(
		_summary_receipts_finite(summary),
		"all reported movement and structural measurements are finite",
	)
	_check(
		(
			_outcome_is_complete(summary)
			if sdk_bw2_authority_enabled
			else (
				bool(summary.get("physical_wave_gait_walking_observed", false))
				and bool(summary.get("ok", false))
				and String(summary.get("failure_code", "")).is_empty()
			)
		),
		(
			"one-world walking or nonwalking result is complete for BW2 selection"
			if sdk_bw2_authority_enabled
			else "one-world physical walking is established for this declared morphology cell"
		),
	)
	_check(
		(
			not bool(summary.get("formal_milestone_acceptance_authorized", true))
			and not bool(summary.get("encyclopedia_admission_authorized", true))
			and not bool(summary.get("automatic_creature_guidance_allowed", true))
			and not bool(compiled.get("formal_milestone_acceptance_authorized", true))
			and not bool(compiled.get("encyclopedia_admission_authorized", true))
			and not bool(compiled.get("automatic_creature_guidance_allowed", true))
			and (
				(
					campaign_id != CAMPAIGN_GQ13
					and campaign_id != CAMPAIGN_GQ14
					and campaign_id != CAMPAIGN_GQ15
				)
				or (
					(
						_gq15_feature_coverage_exact(
							feature_result,
							coverage_result,
							generation_digest,
							fixture_digest,
							expected_controller_digest,
						)
						if campaign_id == CAMPAIGN_GQ15
						else (
							_gq14_feature_coverage_exact(
								feature_result,
								coverage_result,
								generation_digest,
								fixture_digest,
								expected_controller_digest,
							)
							if campaign_id == CAMPAIGN_GQ14
							else _gq13_feature_coverage_exact(
								feature_result,
								coverage_result,
								generation_digest,
								fixture_digest,
								expected_controller_digest,
							)
						)
					)
					and (
						_gq15_dynamic_support_output_exact(
							summary,
							dynamic_support_options,
						)
						if campaign_id == CAMPAIGN_GQ15
						else (
							_gq14_dynamic_support_output_exact(
								summary,
								dynamic_support_options,
							)
							if campaign_id == CAMPAIGN_GQ14
							else _gq13_dynamic_support_output_exact(
								summary,
								dynamic_support_options,
							)
						)
					)
				)
			)
		),
		"the result retains report-only diagnostic integrity and all formal nonclaims",
	)
	var sdk_native_authority_ok := not sdk_native_authority_enabled
	var sdk_authority: Dictionary = summary.get("sdk_authority_summary", {})
	if sdk_native_authority_enabled:
		var phase_offset_receipt: Dictionary = sdk_authority.get(
			"phase_offset_synchronization_receipt",
			{},
		)
		var expected_phase_offset := int(requested_perturbation.get("gait_phase_offset_ticks", 0))
		var sdk_start_exact := (
			bool(summary.get("sdk_authority_enabled", false))
			and String(summary.get("sdk_authority_scope", "")) == "post_settle_full"
			and int(summary.get("sdk_adapter_start_tick", -1)) == 240
			and int(summary.get("sdk_phase_offset_activation_tick", -1)) == 600
			and bool(phase_offset_receipt.get("scheduled", false))
			and int(phase_offset_receipt.get("requested_offset_ticks", -99))
			== expected_phase_offset
			and int(phase_offset_receipt.get("activation_semantic_step", -1)) == 360
			and int(phase_offset_receipt.get("application_count", -1)) == 1
			and int(phase_offset_receipt.get("synchronized_limb_count", -1)) == 4
		)
		var sdk_steps := int(sdk_authority.get("step_count", -1))
		var sdk_step_count_exact := (
			bool(sdk_authority.get("ok", false))
			and sdk_steps
			== int(summary.get("executed_ticks", 0))
			- int(summary.get("sdk_adapter_start_tick", 0))
		)
		var sdk_commands_exact := (
			int(sdk_authority.get("compared_actuator_command_count", -1)) == sdk_steps * 8
			and int(sdk_authority.get("native_actuation_application_count", -1))
			== sdk_steps * 8
			and int(summary.get("legacy_post_settle_actuation_application_count", -1)) == 0
			and int(summary.get("legacy_evidence_actuation_application_count", -1)) == 0
		)
		var sdk_failures_zero := (
			int(sdk_authority.get("mismatch_count", -1)) == 0
			and int(sdk_authority.get("safe_no_actuation_count", -1)) == 0
			and int(sdk_authority.get("native_safe_disable_application_count", -1)) == 0
			and int(sdk_authority.get("maximum_absolute_phase_error_steps", -1)) == 0
		)
		var sdk_numeric_bounds_exact := (
			float(sdk_authority.get("maximum_absolute_target_position_error_rad", INF))
			<= SDK_MAXIMUM_POSITION_MAPPING_ERROR_RAD
			and (
				float(
					sdk_authority.get(
						"maximum_absolute_target_velocity_error_rad_s",
						INF,
					)
				)
				<= SDK_MAXIMUM_VELOCITY_MAPPING_ERROR_RAD_S
			)
			and (
				float(
					sdk_authority.get(
						"maximum_absolute_speed_limit_error_rad_s",
						INF,
					)
				)
				<= SDK_MAXIMUM_SPEED_LIMIT_MAPPING_ERROR_RAD_S
			)
			and float(sdk_authority.get("maximum_absolute_steering_error", INF))
			<= SDK_MAXIMUM_STEERING_MAPPING_ERROR
			and is_equal_approx(
				float(sdk_authority.get("comparison_tolerance", NAN)),
				SDK_COMPARISON_TOLERANCE,
			)
		)
		var sdk_manifest: Dictionary = sdk_authority.get("adapter_manifest", {})
		var sdk_manifest_exact := (
			String(sdk_manifest.get("schema_version", ""))
			== "sporespore_godot_jolt_adapter_manifest_v14"
			and String(sdk_manifest.get("adapter_id", "")) == "godot_jolt_gdextension_v1"
			and String(sdk_manifest.get("candidate35_runtime_version", ""))
			== "sporespore_candidate35_runtime_v2"
			and String(sdk_manifest.get("physics_engine", "")) == "Jolt Physics"
			and bool(sdk_manifest.get("actuation_authority", false))
			and String(sdk_manifest.get("execution_mode", ""))
			== "native_authority_with_legacy_observer"
			and (sdk_manifest.get("phase_progression_modes", []) as Array)
			== ["clocked", "contact_gated"]
			and String(sdk_manifest.get("actuator_model", ""))
			== "hinge_target_velocity_with_impulse_cap"
			and (
				(sdk_manifest.get("actuator_capabilities", {}) as Dictionary)
				== {
					"position_target": "adapter_pd_to_velocity",
					"velocity_target": "native_hinge_motor",
					"effort_target": "unavailable",
					"impulse_limit": "native_per_step_cap",
					"saturation": "core_then_host",
					"rate_limit": "core_only",
				}
			)
			and String(sdk_manifest.get("contact_quality", "")) == "qualified_bearing"
			and not bool(sdk_manifest.get("normal_load_available", true))
			and (
				(sdk_manifest.get("contact_capabilities", {}) as Dictionary)
				== {
					"presence": "qualified",
					"bears_support": "qualified",
					"point": "host_observer_only",
					"normal": "host_observer_only",
					"relative_velocity": "host_observer_only",
					"raw_impulse": "host_observer_only",
					"normal_load": "unavailable",
					"persistence": "per_step_engine_contact_id",
					"friction": "manifest_material_only",
					"contact_site_shape_model": "one_semantic_shape_per_contact_site",
					"multi_shape_contact_sites_supported": false,
				}
			)
			and (
				(sdk_manifest.get("phase_offset_synchronization", {}) as Dictionary)
				== {
					"supported": true,
					"minimum_offset_ticks": -3,
					"maximum_offset_ticks": 3,
					"application_mode": "one_time_before_scheduled_sample",
				}
			)
		)
		var sdk_walking_gates_exact := (
			bool(
				(summary.get("walking_gate_receipts", {}) as Dictionary).get(
					"native_sdk_exclusive_post_settle_actuation",
					false,
				)
			)
			and _all_true(summary.get("walking_gate_receipts", {}))
			and bool(summary.get("physical_wave_gait_walking_observed", false))
		)
		_check(
			sdk_start_exact,
			"native authority and the one-time phase synchronization start at frozen ticks",
		)
		_check(
			sdk_step_count_exact,
			"native step count spans every post-settle physics tick",
		)
		_check(
			sdk_commands_exact,
			"all eight commands are compared and natively applied with zero legacy authority",
		)
		_check(
			sdk_failures_zero,
			"native parity, safety, disable, and phase failure counts remain zero",
		)
		_check(
			sdk_numeric_bounds_exact,
			"every host-mapping signal remains inside its preregistered ceiling",
		)
		_check(
			sdk_manifest_exact,
			"the native manifest freezes exact actuation, phase, and contact capabilities",
		)
		_check(
			sdk_walking_gates_exact,
			"native-exclusive authority and every existing physical walking gate pass together",
		)
		sdk_native_authority_ok = (
			sdk_start_exact
			and sdk_step_count_exact
			and sdk_commands_exact
			and sdk_failures_zero
			and sdk_numeric_bounds_exact
			and sdk_manifest_exact
			and sdk_walking_gates_exact
		)
	var sdk_bw2_authority_ok := not sdk_bw2_authority_enabled
	if sdk_bw2_authority_enabled:
		sdk_bw2_authority_ok = _bw2_authority_integrity(summary, sdk_authority)
		_check(
			sdk_bw2_authority_ok,
			(
				"%s portable base, bounded stability overlay, and typed receipts are exact"
				% _sdk_bw2_candidate_id
			),
		)

	var evidence: Vector3 = summary.get("evidence_torso_displacement_world_m", Vector3.ZERO)
	var final: Vector3 = summary.get("final_torso_displacement_world_m", Vector3.ZERO)
	var static_screen: Dictionary = compiled["static_screen"]
	var result_line := (
		(
			"NONUNIFORM_PROPORTION_RESULT campaign=%s morphology=%s role=%s repetition=%d "
			+ "policy_digest=%s parameter_digest=%s fixture_digest=%s "
			+ "static_digest=%s controller_digest=%s threshold_digest=%s "
			+ "interaction_score=%.9f generator_digest=%s "
			+ "walking=%s evidence=(%.6f,%.6f,%.6f) final=(%.6f,%.6f,%.6f)"
		)
		% [
			campaign_id,
			morphology_id,
			campaign_role,
			repetition,
			policy_digest,
			parameter_digest,
			fixture_digest,
			static_digest,
			controller_digest,
			threshold_digest,
			_morphology_interaction_score(declared),
			generation_digest,
			str(bool(summary.get("physical_wave_gait_walking_observed", false))).to_lower(),
			evidence.x,
			evidence.y,
			evidence.z,
			final.x,
			final.y,
			final.z,
		]
	)
	if campaign_id in [CAMPAIGN_GQ13, CAMPAIGN_GQ14, CAMPAIGN_GQ15]:
		var coverage_receipt: Dictionary = coverage_result.get("coverage_receipt", {})
		result_line += (
			(
				" feature_digest=%s coverage_digest=%s coverage_status=%s "
				+ "dynamic_support_digest=%s dynamic_support_samples=%d"
			)
			% [
				String(feature_result.get("feature_receipt_sha256", "")),
				String(coverage_result.get("coverage_receipt_sha256", "")),
				String(coverage_receipt.get("status", "")),
				String(summary.get("dynamic_support_receipt_sha256", "")),
				int(summary.get("dynamic_support_trace_sample_count", -1)),
			]
		)
	result_line += (
		" anchor=%.9f hinge=%.9f height=%.9f support_margin=%.9f"
		% [
			float(summary.get("maximum_anchor_error_m", NAN)),
			float(summary.get("maximum_hinge_axis_error_rad", NAN)),
			float(summary.get("minimum_torso_height_m", NAN)),
			float(static_screen["minimum_support_polygon_margin_m"]),
		]
	)
	if sdk_native_authority_enabled:
		result_line += (
			(
				" sdk_native_authority=true sdk_ok=%s sdk_steps=%d "
				+ "sdk_compared_commands=%d sdk_native_commands=%d "
				+ "sdk_legacy_post_settle=%d sdk_legacy_evidence=%d "
				+ "sdk_mismatches=%d sdk_safe_no_actuation=%d sdk_safe_disables=%d "
				+ "sdk_phase_error_steps=%d sdk_position_error_rad=%.17f "
				+ "sdk_velocity_error_rad_s=%.17f sdk_speed_limit_error_rad_s=%.17f "
				+ "sdk_steering_error=%.17f sdk_capability_hash=%s"
			)
			% [
				str(sdk_native_authority_ok).to_lower(),
				int(sdk_authority.get("step_count", -1)),
				int(sdk_authority.get("compared_actuator_command_count", -1)),
				int(sdk_authority.get("native_actuation_application_count", -1)),
				int(summary.get("legacy_post_settle_actuation_application_count", -1)),
				int(summary.get("legacy_evidence_actuation_application_count", -1)),
				int(sdk_authority.get("mismatch_count", -1)),
				int(sdk_authority.get("safe_no_actuation_count", -1)),
				int(sdk_authority.get("native_safe_disable_application_count", -1)),
				int(sdk_authority.get("maximum_absolute_phase_error_steps", -1)),
				float(sdk_authority.get("maximum_absolute_target_position_error_rad", INF)),
				float(
					sdk_authority.get(
						"maximum_absolute_target_velocity_error_rad_s",
						INF,
					)
				),
				float(sdk_authority.get("maximum_absolute_speed_limit_error_rad_s", INF)),
				float(sdk_authority.get("maximum_absolute_steering_error", INF)),
				String(sdk_authority.get("adapter_capability_sha256", "")),
			]
		)
	if sdk_bw2_authority_enabled:
		var bw2_overlay: Dictionary = sdk_authority.get("stability_overlay_summary", {})
		var bw2_contribution: Dictionary = sdk_authority.get(
			"stability_contribution_shadow_summary",
			{},
		)
		var bw2_receipt := {
			"schema_version": "sporespore_balanced_wave_bw2_counterexample_cell_receipt_v1",
			"ok": sdk_bw2_authority_ok,
			"candidate_id": _sdk_bw2_candidate_id,
			"candidate_policy_digest": _sdk_bw2_policy_digest,
			"policy_id": _sdk_bw2_policy_id,
			"morphology_id": morphology_id,
			"campaign_role": campaign_role,
			"repetition": repetition,
			"generation_receipt_sha256": generation_digest,
			"proportion_spec_sha256": parameter_digest,
			"fixture_spec_sha256": fixture_digest,
			"static_screen_sha256": static_digest,
			"legacy_scaffold_controller_sha256": controller_digest,
			"evidence_threshold_configuration_sha256": threshold_digest,
			"world_build_count": int(summary.get("world_build_count", -1)),
			"walking_observed":
			bool(summary.get("physical_wave_gait_walking_observed", false)),
			"walking_gate_receipts":
			(summary.get("walking_gate_receipts", {}) as Dictionary).duplicate(true),
			"failure_code": String(summary.get("failure_code", "")),
			"step_count": int(sdk_authority.get("step_count", -1)),
			"validated_balanced_wave_command_count":
			int(sdk_authority.get("validated_balanced_wave_command_count", -1)),
			"steering_feedback_update_count":
			int(sdk_authority.get("steering_feedback_update_count", -1)),
			"steering_filter_application_count":
			int(sdk_authority.get("steering_filter_application_count", -1)),
			"steering_saturation_count":
			int(sdk_authority.get("steering_saturation_count", -1)),
			"steering_slew_limited_count":
			int(sdk_authority.get("steering_slew_limited_count", -1)),
			"maximum_absolute_requested_steering_fraction":
			float(sdk_authority.get("maximum_absolute_requested_steering_fraction", INF)),
			"maximum_absolute_filtered_steering_fraction":
			float(sdk_authority.get("maximum_absolute_filtered_steering_fraction", INF)),
			"maximum_absolute_steering_delta_per_step":
			float(sdk_authority.get("maximum_absolute_steering_delta_per_step", INF)),
			"cumulative_absolute_cross_track_error_m_s":
			float(sdk_authority.get("cumulative_absolute_cross_track_error_m_s", INF)),
			"minimum_cross_track_error_m":
			float(sdk_authority.get("minimum_cross_track_error_m", INF)),
			"maximum_cross_track_error_m":
			float(sdk_authority.get("maximum_cross_track_error_m", INF)),
			"native_motor_write_count":
			int(sdk_authority.get("native_actuation_application_count", -1)),
			"base_command_source": String(bw2_overlay.get("base_command_source", "")),
			"portable_controller_base_application_count":
			int(bw2_overlay.get("portable_controller_base_application_count", -1)),
			"nonzero_stability_application_count":
			int(bw2_overlay.get("nonzero_effective_application_count", -1)),
			"stability_contribution_shadow_summary": bw2_contribution.duplicate(true),
			"joint_mapping_shadow_summary":
			(
				sdk_authority.get("joint_mapping_shadow_summary", {})
				as Dictionary
			).duplicate(true),
			"controller_profile_sha256":
			String(sdk_authority.get("controller_profile_sha256", "")),
			"adapter_capability_sha256":
			String(sdk_authority.get("adapter_capability_sha256", "")),
			"maximum_tilt_rad": float(summary.get("maximum_tilt_rad", INF)),
			"minimum_torso_height_m": float(summary.get("minimum_torso_height_m", -INF)),
			"maximum_anchor_error_m": float(summary.get("maximum_anchor_error_m", INF)),
			"maximum_hinge_axis_error_rad":
			float(summary.get("maximum_hinge_axis_error_rad", INF)),
			"final_torso_displacement_world_m":
			_vector_dictionary(summary.get("final_torso_displacement_world_m", Vector3.ZERO)),
			"evidence_task_frame_forward_displacement_m":
			float(summary.get("evidence_task_frame_forward_displacement_m", NAN)),
			"final_task_frame_forward_displacement_m":
			float(summary.get("final_task_frame_forward_displacement_m", NAN)),
			"final_task_frame_lateral_displacement_m":
			float(summary.get("final_task_frame_lateral_displacement_m", NAN)),
			"task_frame_forward_axis_world_unit":
			_vector_dictionary(
				summary.get("task_frame_forward_axis_world_unit", Vector3.INF)
			),
			"task_frame_lateral_axis_world_unit":
			_vector_dictionary(
				summary.get("task_frame_lateral_axis_world_unit", Vector3.INF)
			),
			"direct_body_write_count": _direct_body_write_count(summary),
			"development_data_only": true,
			"walking_acceptance": false,
			"arbitrary_quadruped_coverage": false,
			"continuous_full_volume_coverage": false,
			"material_robustness": false,
			"cross_engine_c6": false,
			"completed_engine_neutral_sdk": false,
			"physical_acceptance_authority": false,
		}
		print(
			"BALANCED_WAVE_BW2_COUNTEREXAMPLE_CELL_RECEIPT ",
			JSON.stringify(bw2_receipt, "", true, true),
		)
	print(result_line)
	_finish()


static func _formula_policy(campaign_id: String = CAMPAIGN_GP1) -> Dictionary:
	if campaign_id == CAMPAIGN_GQ15:
		return _gq15_formula_policy()
	var is_gp2 := campaign_id == CAMPAIGN_GP2
	var is_gp3 := campaign_id == CAMPAIGN_GP3
	var is_gp4 := campaign_id == CAMPAIGN_GP4
	var is_gp5 := campaign_id == CAMPAIGN_GP5
	var is_gq1 := campaign_id == CAMPAIGN_GQ1
	var is_gq2 := campaign_id == CAMPAIGN_GQ2
	var is_gq3 := campaign_id == CAMPAIGN_GQ3
	var is_gq4 := campaign_id == CAMPAIGN_GQ4
	var is_gq5 := campaign_id == CAMPAIGN_GQ5
	var is_gq6 := campaign_id == CAMPAIGN_GQ6
	var is_gq7 := campaign_id == CAMPAIGN_GQ7
	var is_gq8 := campaign_id == CAMPAIGN_GQ8
	var is_gq9 := campaign_id == CAMPAIGN_GQ9
	var is_gq10 := campaign_id == CAMPAIGN_GQ10
	var is_gq11 := campaign_id == CAMPAIGN_GQ11
	var is_gq12 := campaign_id == CAMPAIGN_GQ12
	var is_gq13 := campaign_id == CAMPAIGN_GQ13
	var is_gq14 := campaign_id == CAMPAIGN_GQ14
	var uses_gp3_controller := (
		is_gp3
		or is_gp4
		or is_gp5
		or is_gq1
		or is_gq2
		or is_gq3
		or is_gq4
		or is_gq5
		or is_gq6
		or is_gq7
		or is_gq8
		or is_gq9
		or is_gq10
		or is_gq11
		or is_gq12
		or is_gq13
		or is_gq14
	)
	var selection_cells: Array
	var held_out_cells: Array
	if is_gq14:
		selection_cells = ProportionSpecScript.gq14_selection_cells()
		held_out_cells = ProportionSpecScript.gq14_held_out_cells()
	elif is_gq13:
		selection_cells = ProportionSpecScript.gq13_selection_cells()
		held_out_cells = ProportionSpecScript.gq13_held_out_cells()
	elif is_gq12:
		selection_cells = ProportionSpecScript.gq12_selection_cells()
		held_out_cells = ProportionSpecScript.gq12_held_out_cells()
	elif is_gq11:
		selection_cells = ProportionSpecScript.gq11_selection_cells()
		held_out_cells = ProportionSpecScript.gq11_held_out_cells()
	elif is_gq10:
		selection_cells = ProportionSpecScript.gq10_selection_cells()
		held_out_cells = ProportionSpecScript.gq10_held_out_cells()
	elif is_gq9:
		selection_cells = ProportionSpecScript.gq9_selection_cells()
		held_out_cells = ProportionSpecScript.gq9_held_out_cells()
	elif is_gq8:
		selection_cells = ProportionSpecScript.gq8_selection_cells()
		held_out_cells = ProportionSpecScript.gq8_held_out_cells()
	elif is_gq7:
		selection_cells = ProportionSpecScript.gq7_selection_cells()
		held_out_cells = ProportionSpecScript.gq7_held_out_cells()
	elif is_gq6:
		selection_cells = ProportionSpecScript.gq6_selection_cells()
		held_out_cells = ProportionSpecScript.gq6_held_out_cells()
	elif is_gq5:
		selection_cells = ProportionSpecScript.gq5_selection_cells()
		held_out_cells = ProportionSpecScript.gq5_held_out_cells()
	elif is_gq4:
		selection_cells = ProportionSpecScript.gq4_selection_cells()
		held_out_cells = ProportionSpecScript.gq4_held_out_cells()
	elif is_gq3:
		selection_cells = ProportionSpecScript.gq3_selection_cells()
		held_out_cells = ProportionSpecScript.gq3_held_out_cells()
	elif is_gq2:
		selection_cells = ProportionSpecScript.gq2_selection_cells()
		held_out_cells = ProportionSpecScript.gq2_held_out_cells()
	elif is_gq1:
		selection_cells = ProportionSpecScript.gq1_selection_cells()
		held_out_cells = ProportionSpecScript.gq1_held_out_cells()
	elif is_gp5:
		selection_cells = ProportionSpecScript.gp5_selection_cells()
		held_out_cells = ProportionSpecScript.gp5_held_out_cells()
	elif is_gp4:
		selection_cells = ProportionSpecScript.gp4_selection_cells()
		held_out_cells = ProportionSpecScript.gp4_held_out_cells()
	elif is_gp3:
		selection_cells = ProportionSpecScript.gp3_selection_cells()
		held_out_cells = ProportionSpecScript.gp3_held_out_cells()
	elif is_gp2:
		selection_cells = ProportionSpecScript.gp2_selection_cells()
		held_out_cells = ProportionSpecScript.gp2_held_out_cells()
	else:
		selection_cells = ProportionSpecScript.selection_cells()
		held_out_cells = ProportionSpecScript.held_out_cells()
	var policy := {
		"schema_version":
		(
			"sporespore_g4_gq14_candidate34_support_sets_policy_v1"
			if is_gq14
			else (
				"sporespore_g4_gq13_candidate33_diagnostic_receipts_policy_v1"
				if is_gq13
				else (
					"sporespore_g4_gq12_dual_geometry_velocity_feedback_policy_v1"
					if is_gq12
					else (
						"sporespore_g4_gq11_contact_and_lateral_margin_velocity_feedback_policy_v1"
						if is_gq11
						else (
							"sporespore_g4_gq10_perturbation_margin_velocity_feedback_policy_v1"
							if is_gq10
							else (
								"sporespore_g4_gq9_high_fallback_velocity_feedback_policy_v1"
								if is_gq9
								else (
									"sporespore_g4_gq8_boosted_velocity_feedback_policy_v1"
									if is_gq8
									else (
										"sporespore_g4_gq7_smooth_high_interaction_velocity_feedback_policy_v1"
										if is_gq7
										else (
											"sporespore_g4_gq6_morphology_adaptive_velocity_feedback_policy_v1"
											if is_gq6
											else (
												"sporespore_g4_gq5_score_first_foot_hip_yaw_generated_morphology_policy_v1"
												if is_gq5
												else (
													"sporespore_g4_gq4_score_foot_hip_yaw_generated_morphology_policy_v1"
													if is_gq4
													else (
														"sporespore_g4_gq3_foot_aware_yaw_generated_morphology_policy_v1"
														if is_gq3
														else (
															"sporespore_g4_gq2_complementary_path_generated_morphology_policy_v1"
															if is_gq2
															else (
																"sporespore_g4_gq1_generated_morphology_policy_v1"
																if is_gq1
																else (
																	"sporespore_g3_gp5_morphology_adaptive_nonuniform_proportion_policy_v1"
																	if is_gp5
																	else (
																		"sporespore_g3_gp4_solver_policy_nonuniform_proportion_policy_v1"
																		if is_gp4
																		else (
																			"sporespore_g3_gp3_global_controller_nonuniform_proportion_policy_v1"
																			if is_gp3
																			else (
																				"sporespore_g3_gp2_narrower_nonuniform_proportion_policy_v1"
																				if is_gp2
																				else "sporespore_g3_gp1_nonuniform_proportion_policy_v1"
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		),
		"campaign_id": campaign_id,
		"compiler_schema_version": ProportionSpecScript.SCHEMA_VERSION,
		"compiler_policy_id": ProportionSpecScript.POLICY_ID,
		"selection_cells": selection_cells,
		"held_out_cells": held_out_cells,
		"held_out_repetitions": [1, 2, 3],
		"torso_size_policy": "[0.50*L,0.12,0.32*W]",
		"hip_offset_policy": "[sign*0.20*H,-0.05,sign*0.18*H]",
		"upper_length_policy": "0.35*U",
		"lower_length_policy": "0.35*(1-U)",
		"foot_radius_policy": "0.04*F",
		"initial_torso_height_policy": "0.05+0.35+0.04*F",
		"front_mass_policy": "reference*M",
		"rear_mass_policy": "reference*(2-M)",
		"clock_policy_id":
		(
			ClockSpecScript.GQ14_POLICY_ID
			if is_gq14
			else (
				ClockSpecScript.GQ13_POLICY_ID
				if is_gq13
				else (
					ClockSpecScript.GQ12_POLICY_ID
					if is_gq12
					else (
						ClockSpecScript.GQ11_POLICY_ID
						if is_gq11
						else (
							ClockSpecScript.GQ10_POLICY_ID
							if is_gq10
							else (
								ClockSpecScript.GQ9_POLICY_ID
								if is_gq9
								else (
									ClockSpecScript.GQ8_POLICY_ID
									if is_gq8
									else (
										ClockSpecScript.GQ7_POLICY_ID
										if is_gq7
										else (
											ClockSpecScript.GQ6_POLICY_ID
											if is_gq6
											else ClockSpecScript.DYNAMIC_SIMILARITY_POLICY_ID
										)
									)
								)
							)
						)
					)
				)
			)
		),
		"clock_scale": 1.0,
		"evidence_threshold_policy_id": "nonuniform_dimensionless_thresholds_v1",
		"expected_assertions_per_cell": 25,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
		"automatic_creature_guidance_allowed": false,
	}
	if (
		not is_gp5
		and not is_gq1
		and not is_gq2
		and not is_gq3
		and not is_gq4
		and not is_gq5
		and not is_gq6
		and not is_gq7
		and not is_gq8
		and not is_gq9
		and not is_gq10
		and not is_gq11
		and not is_gq12
		and not is_gq13
		and not is_gq14
	):
		policy["controller_sha256"] = _expected_controller_sha256(campaign_id)
	if uses_gp3_controller:
		if (
			is_gq2
			or is_gq3
			or is_gq4
			or is_gq5
			or is_gq6
			or is_gq7
			or is_gq8
			or is_gq9
			or is_gq10
			or is_gq11
			or is_gq12
			or is_gq13
			or is_gq14
		):
			policy["path_steering_options_score_half_or_above_template"] = (
				GQ14_PATH_STEERING_OPTIONS
				if is_gq14
				else (
					GQ13_PATH_STEERING_OPTIONS
					if is_gq13
					else (
						GQ12_PATH_STEERING_OPTIONS
						if is_gq12
						else (
							GQ11_PATH_STEERING_OPTIONS
							if is_gq11
							else (
								GQ10_PATH_STEERING_OPTIONS
								if is_gq10
								else (
									GQ9_PATH_STEERING_OPTIONS
									if is_gq9
									else (
										GQ8_PATH_STEERING_OPTIONS
										if is_gq8
										else (
											GQ7_PATH_STEERING_OPTIONS
											if is_gq7
											else (
												GQ6_PATH_STEERING_OPTIONS
												if is_gq6
												else (
													GQ5_PATH_STEERING_OPTIONS
													if is_gq5
													else (
														GQ4_PATH_STEERING_OPTIONS
														if is_gq4
														else (
															GQ3_PATH_STEERING_OPTIONS
															if is_gq3
															else GQ2_PATH_STEERING_OPTIONS
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
			policy["path_cross_track_gain_derivation_id"] = ("interaction_score_half_threshold_v1")
			policy["path_cross_track_gain_formula"] = ("1.0 if morphology_interaction_score<0.5 else 0.75")
			if is_gq14:
				policy["path_yaw_gain_derivation_id"] = ("small_foot_score_first_length_hip_piecewise_v1")
				policy["path_yaw_gain_formula"] = (
					"1.3 if F<0.985 and S>=0.9 else (1.1 if F<0.985 else "
					+ "(1.0 if S<0.5 or F>1.025 else (1.3 if F>1.01 else "
					+ "(1.1 if abs(H-1.0)>=0.02 and L>1.02 else 1.0))))"
				)
				policy["path_velocity_gain_derivation_id"] = (
					"max_long_wide_long_large_foot_score_short_narrow_v9"
				)
				policy["path_velocity_gain_formula"] = (
					"0.25+0.05*max(clamp((L-1)/0.07,0,1)*clamp((W-1)/0.06,0,1),"
					+ "clamp((L-1)/0.05,0,1)*clamp((F-1.01)/0.02,0,1)) if Y>1 else "
					+ "(0.275+0.075*clamp((L-1)/0.01,0,1)*clamp((1.01-F)/0.01,0,1) "
					+ "if S<0.15 and W<=1 else (0.40 if S<0.15 else "
					+ "(0.75 if S<0.5 and W<=1 else (0.25 if S<0.5 else "
					+ "(0.25-0.05*clamp((S-0.5)/0.5,0,1) if W>1 and L<1 else "
					+ "(0.35+0.10*clamp((1-S)/0.40,0,1) if W<=1 and L<0.95 "
					+ "else 0.35))))))"
				)
			elif is_gq13:
				policy["path_yaw_gain_derivation_id"] = ("small_foot_score_first_length_hip_piecewise_v1")
				policy["path_yaw_gain_formula"] = (
					"1.3 if F<0.985 and S>=0.9 else (1.1 if F<0.985 else "
					+ "(1.0 if S<0.5 or F>1.025 else (1.3 if F>1.01 else "
					+ "(1.1 if abs(H-1.0)>=0.02 and L>1.02 else 1.0))))"
				)
				policy["path_velocity_gain_derivation_id"] = ("dual_smooth_long_small_foot_long_wide_mid_narrow_075_v8")
				policy["path_velocity_gain_formula"] = (
					"0.25+0.05*clamp((L-1)/0.07,0,1)*clamp((W-1)/0.06,0,1) "
					+ "if Y>1 else (0.275+0.075*clamp((L-1)/0.01,0,1)"
					+ "*clamp((1.01-F)/0.01,0,1) if S<0.15 and W<=1 else "
					+ "(0.35 if S<0.15 else (0.75 if S<0.5 and W<=1 else "
					+ "(0.25 if S<0.5 else "
					+ "(0.25-0.05*clamp((S-0.5)/0.5,0,1) if W>1 and L<1 else 0.35)))))"
				)
			elif is_gq12:
				policy["path_yaw_gain_derivation_id"] = ("small_foot_score_first_length_hip_piecewise_v1")
				policy["path_yaw_gain_formula"] = (
					"1.3 if F<0.985 and S>=0.9 else (1.1 if F<0.985 else "
					+ "(1.0 if S<0.5 or F>1.025 else (1.3 if F>1.01 else "
					+ "(1.1 if abs(H-1.0)>=0.02 and L>1.02 else 1.0))))"
				)
				policy["path_velocity_gain_derivation_id"] = ("dual_smooth_long_small_foot_and_long_wide_v7")
				policy["path_velocity_gain_formula"] = (
					"0.25+0.05*clamp((L-1)/0.07,0,1)*clamp((W-1)/0.06,0,1) "
					+ "if Y>1 else (0.275+0.075*clamp((L-1)/0.01,0,1)"
					+ "*clamp((1.01-F)/0.01,0,1) if S<0.15 and W<=1 else "
					+ "(0.35 if S<0.15 else (0.70 if S<0.5 and W<=1 else "
					+ "(0.25 if S<0.5 else "
					+ "(0.25-0.05*clamp((S-0.5)/0.5,0,1) if W>1 and L<1 else 0.35)))))"
				)
			elif is_gq11:
				policy["path_yaw_gain_derivation_id"] = ("small_foot_score_first_length_hip_piecewise_v1")
				policy["path_yaw_gain_formula"] = (
					"1.3 if F<0.985 and S>=0.9 else (1.1 if F<0.985 else "
					+ "(1.0 if S<0.5 or F>1.025 else (1.3 if F>1.01 else "
					+ "(1.1 if abs(H-1.0)>=0.02 and L>1.02 else 1.0))))"
				)
				policy["path_velocity_gain_derivation_id"] = ("yaw025_low_narrow_midpoint0275_v6")
				policy["path_velocity_gain_formula"] = (
					"0.25 if Y>1 else (0.275 if S<0.15 and W<=1 else "
					+ "(0.35 if S<0.15 else (0.70 if S<0.5 and W<=1 else "
					+ "(0.25 if S<0.5 else "
					+ "(0.25-0.05*clamp((S-0.5)/0.5,0,1) if W>1 and L<1 else 0.35)))))"
				)
			elif is_gq10:
				policy["path_yaw_gain_derivation_id"] = ("small_foot_score_first_length_hip_piecewise_v1")
				policy["path_yaw_gain_formula"] = (
					"1.3 if F<0.985 and S>=0.9 else (1.1 if F<0.985 else "
					+ "(1.0 if S<0.5 or F>1.025 else (1.3 if F>1.01 else "
					+ "(1.1 if abs(H-1.0)>=0.02 and L>1.02 else 1.0))))"
				)
				policy["path_velocity_gain_derivation_id"] = ("yaw_score_width_length_perturbation_margin_v4")
				policy["path_velocity_gain_formula"] = (
					"0.20 if Y>1 else (0.25 if S<0.15 and W<=1 else "
					+ "(0.35 if S<0.15 else (0.70 if S<0.5 and W<=1 else "
					+ "(0.25 if S<0.5 else "
					+ "(0.25-0.05*clamp((S-0.5)/0.5,0,1) if W>1 and L<1 else 0.35)))))"
				)
			elif is_gq9:
				policy["path_yaw_gain_derivation_id"] = ("small_foot_score_first_length_hip_piecewise_v1")
				policy["path_yaw_gain_formula"] = (
					"1.3 if F<0.985 and S>=0.9 else (1.1 if F<0.985 else "
					+ "(1.0 if S<0.5 or F>1.025 else (1.3 if F>1.01 else "
					+ "(1.1 if abs(H-1.0)>=0.02 and L>1.02 else 1.0))))"
				)
				policy["path_velocity_gain_derivation_id"] = ("yaw_score_width_length_boosted_high_fallback_v3")
				policy["path_velocity_gain_formula"] = (
					"0.20 if Y>1 else (0.25 if S<0.15 and W<=1 else "
					+ "(0.30 if S<0.15 else (0.60 if S<0.5 and W<=1 else "
					+ "(0.25 if S<0.5 else "
					+ "(0.25-0.05*clamp((S-0.5)/0.5,0,1) if W>1 and L<1 else 0.35)))))"
				)
			elif is_gq8:
				policy["path_yaw_gain_derivation_id"] = ("small_foot_score_first_length_hip_piecewise_v1")
				policy["path_yaw_gain_formula"] = (
					"1.3 if F<0.985 and S>=0.9 else (1.1 if F<0.985 else "
					+ "(1.0 if S<0.5 or F>1.025 else (1.3 if F>1.01 else "
					+ "(1.1 if abs(H-1.0)>=0.02 and L>1.02 else 1.0))))"
				)
				policy["path_velocity_gain_derivation_id"] = ("yaw_score_width_length_boosted_mid_narrow_v2")
				policy["path_velocity_gain_formula"] = (
					"0.20 if Y>1 else (0.25 if S<0.15 and W<=1 else "
					+ "(0.30 if S<0.15 else (0.60 if S<0.5 and W<=1 else "
					+ "(0.25 if S<0.5 else "
					+ "(0.25-0.05*clamp((S-0.5)/0.5,0,1) if W>1 and L<1 else 0.30)))))"
				)
			elif is_gq7:
				policy["path_yaw_gain_derivation_id"] = ("small_foot_score_first_length_hip_piecewise_v1")
				policy["path_yaw_gain_formula"] = (
					"1.3 if F<0.985 and S>=0.9 else (1.1 if F<0.985 else "
					+ "(1.0 if S<0.5 or F>1.025 else (1.3 if F>1.01 else "
					+ "(1.1 if abs(H-1.0)>=0.02 and L>1.02 else 1.0))))"
				)
				policy["path_velocity_gain_derivation_id"] = ("yaw_score_width_length_smooth_high_interaction_v1")
				policy["path_velocity_gain_formula"] = (
					"0.20 if Y>1 else (0.20 if S<0.15 and W<=1 else "
					+ "(0.25 if S<0.15 else (0.30 if S<0.5 and W<=1 else "
					+ "(0.20 if S<0.5 else "
					+ "(0.25-0.05*clamp((S-0.5)/0.5,0,1) if W>1 and L<1 else 0.25)))))"
				)
			elif is_gq6:
				policy["path_yaw_gain_derivation_id"] = ("small_foot_score_first_length_hip_piecewise_v1")
				policy["path_yaw_gain_formula"] = (
					"1.3 if F<0.985 and S>=0.9 else (1.1 if F<0.985 else "
					+ "(1.0 if S<0.5 or F>1.025 else (1.3 if F>1.01 else "
					+ "(1.1 if abs(H-1.0)>=0.02 and L>1.02 else 1.0))))"
				)
				policy["path_velocity_gain_derivation_id"] = ("yaw_score_width_length_piecewise_v1")
				policy["path_velocity_gain_formula"] = (
					"0.20 if Y>1 else (0.20 if S<0.15 and W<=1 else "
					+ "(0.25 if S<0.15 else (0.30 if S<0.5 and W<=1 else "
					+ "(0.20 if S<0.5 else (0.20 if W>1 and L<1 else 0.25)))))"
				)
			elif is_gq5:
				policy["path_yaw_gain_derivation_id"] = ("score_first_foot_radius_hip_span_piecewise_v1")
				policy["path_yaw_gain_formula"] = (
					"1.0 if S<0.5 or F>1.025 else (1.3 if F>1.01 else "
					+ "(1.25 if abs(H-1.0)>=0.02 else 1.0))"
				)
			elif is_gq4:
				policy["path_yaw_gain_derivation_id"] = ("score_foot_radius_hip_span_piecewise_v1")
				policy["path_yaw_gain_formula"] = (
					"1.0 if F>1.025 else (1.3 if F>1.01 else "
					+ "(1.25 if S>=0.5 and abs(H-1.0)>=0.02 else 1.0))"
				)
			elif is_gq3:
				policy["path_yaw_gain_derivation_id"] = ("foot_radius_scale_1p025_threshold_v1")
				policy["path_yaw_gain_formula"] = ("1.3 if foot_radius_scale<=1.025 else 1.0")
		else:
			policy["path_steering_options"] = _path_steering_options(campaign_id)
		policy["actuator_impulse_options"] = GP3_ACTUATOR_IMPULSE_OPTIONS
	if (
		is_gp5
		or is_gq1
		or is_gq2
		or is_gq3
		or is_gq4
		or is_gq5
		or is_gq6
		or is_gq7
		or is_gq8
		or is_gq9
		or is_gq10
		or is_gq11
		or is_gq12
		or is_gq13
		or is_gq14
	):
		var held_out_motor_options := GP5_MOTOR_VELOCITY_OPTIONS.duplicate(true)
		held_out_motor_options["morphology_interaction_score"] = 1.0
		policy["controller_configuration_derivation_id"] = ("gp3_base_plus_morphology_interaction_score_v1")
		policy["motor_velocity_options_score_zero_template"] = GP5_MOTOR_VELOCITY_OPTIONS
		policy["morphology_interaction_score_policy_id"] = ("clamped_pairwise_normalized_absolute_deviation_sum_v1")
		policy["morphology_interaction_score_formula"] = ("clamp(sum(i<j,abs(di)*abs(dj)),0,1)")
		if (
			is_gq6
			or is_gq7
			or is_gq8
			or is_gq9
			or is_gq10
			or is_gq11
			or is_gq12
			or is_gq13
			or is_gq14
		):
			policy["motor_anchor_guard_derivation_id"] = ("interaction_score_half_threshold_strong_guard_v1")
			policy["motor_anchor_guard_formula"] = ("[0.80,2.0] if morphology_interaction_score>=0.5 else [0.90,2.5]")
		if is_gq14:
			policy["motor_anchor_guard_override_derivation_id"] = (
				"high_score_long_narrow_physical_feature_override_v1"
			)
			policy["motor_anchor_guard_override_formula"] = (
				"[0.70,1.75] if S>=0.5 and L>1.04 and W<0.95 else base"
			)
		if is_gp5:
			policy["selection_controller_sha256"] = _expected_controller_sha256(
				CAMPAIGN_GP5,
				GP5_MOTOR_VELOCITY_OPTIONS,
			)
			policy["held_out_controller_sha256"] = _expected_controller_sha256(
				CAMPAIGN_GP5,
				held_out_motor_options,
			)
	if (
		is_gq1
		or is_gq2
		or is_gq3
		or is_gq4
		or is_gq5
		or is_gq6
		or is_gq7
		or is_gq8
		or is_gq9
		or is_gq10
		or is_gq11
		or is_gq12
		or is_gq13
		or is_gq14
	):
		var generation_receipts: Array = []
		var selection_indices: Array = (
			ProportionSpecScript.GQ14_SELECTION_INDICES
			if is_gq14
			else (
				ProportionSpecScript.GQ13_SELECTION_INDICES
				if is_gq13
				else (
					ProportionSpecScript.GQ12_SELECTION_INDICES
					if is_gq12
					else (
						ProportionSpecScript.GQ11_SELECTION_INDICES
						if is_gq11
						else (
							ProportionSpecScript.GQ10_SELECTION_INDICES
							if is_gq10
							else (
								ProportionSpecScript.GQ9_SELECTION_INDICES
								if is_gq9
								else (
									ProportionSpecScript.GQ8_SELECTION_INDICES
									if is_gq8
									else (
										ProportionSpecScript.GQ7_SELECTION_INDICES
										if is_gq7
										else (
											ProportionSpecScript.GQ6_SELECTION_INDICES
											if is_gq6
											else (
												ProportionSpecScript.GQ5_SELECTION_INDICES
												if is_gq5
												else (
													ProportionSpecScript.GQ4_SELECTION_INDICES
													if is_gq4
													else (
														ProportionSpecScript.GQ3_SELECTION_INDICES
														if is_gq3
														else ProportionSpecScript.GQ1_SELECTION_INDICES
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
		if is_gq2:
			selection_indices = ProportionSpecScript.GQ2_SELECTION_INDICES
		var held_out_indices: Array = (
			ProportionSpecScript.GQ14_HELD_OUT_INDICES
			if is_gq14
			else (
				ProportionSpecScript.GQ13_HELD_OUT_INDICES
				if is_gq13
				else (
					ProportionSpecScript.GQ12_HELD_OUT_INDICES
					if is_gq12
					else (
						ProportionSpecScript.GQ11_HELD_OUT_INDICES
						if is_gq11
						else (
							ProportionSpecScript.GQ10_HELD_OUT_INDICES
							if is_gq10
							else (
								ProportionSpecScript.GQ9_HELD_OUT_INDICES
								if is_gq9
								else (
									ProportionSpecScript.GQ8_HELD_OUT_INDICES
									if is_gq8
									else (
										ProportionSpecScript.GQ7_HELD_OUT_INDICES
										if is_gq7
										else (
											ProportionSpecScript.GQ6_HELD_OUT_INDICES
											if is_gq6
											else (
												ProportionSpecScript.GQ5_HELD_OUT_INDICES
												if is_gq5
												else (
													ProportionSpecScript.GQ4_HELD_OUT_INDICES
													if is_gq4
													else (
														ProportionSpecScript.GQ3_HELD_OUT_INDICES
														if is_gq3
														else ProportionSpecScript.GQ1_HELD_OUT_INDICES
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
		if is_gq2:
			held_out_indices = ProportionSpecScript.GQ2_HELD_OUT_INDICES
		for generator_index in selection_indices + held_out_indices:
			var generation_result := (
				ProportionSpecScript.compile_gq14_generation(generator_index)
				if is_gq14
				else (
					ProportionSpecScript.compile_gq13_generation(generator_index)
					if is_gq13
					else (
						ProportionSpecScript.compile_gq12_generation(generator_index)
						if is_gq12
						else (
							ProportionSpecScript.compile_gq11_generation(generator_index)
							if is_gq11
							else (
								ProportionSpecScript.compile_gq10_generation(generator_index)
								if is_gq10
								else (
									ProportionSpecScript.compile_gq9_generation(generator_index)
									if is_gq9
									else (
										ProportionSpecScript.compile_gq8_generation(generator_index)
										if is_gq8
										else (
											ProportionSpecScript.compile_gq7_generation(generator_index)
											if is_gq7
											else (
												ProportionSpecScript.compile_gq6_generation(generator_index)
												if is_gq6
												else (
													ProportionSpecScript.compile_gq5_generation(
														generator_index
													)
													if is_gq5
													else (
														ProportionSpecScript.compile_gq4_generation(
															generator_index
														)
														if is_gq4
														else (
															ProportionSpecScript.compile_gq3_generation(
																generator_index
															)
															if is_gq3
															else (
																ProportionSpecScript.compile_gq2_generation(
																	generator_index
																)
																if is_gq2
																else (
																	ProportionSpecScript
																	. compile_gq1_generation(
																		generator_index
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
			(
				generation_receipts
				. append(
					{
						"generator_receipt": generation_result.get("generator_receipt", {}),
						"generator_receipt_sha256":
						String(generation_result.get("generator_receipt_sha256", "")),
					}
				)
			)
		if is_gq14:
			policy["generator_policy_id"] = ProportionSpecScript.GQ14_GENERATOR_POLICY_ID
			policy["generator_schema_version"] = (
				ProportionSpecScript.GQ14_GENERATOR_SCHEMA_VERSION
			)
		elif is_gq13:
			policy["generator_policy_id"] = ProportionSpecScript.GQ13_GENERATOR_POLICY_ID
			policy["generator_schema_version"] = (
				ProportionSpecScript.GQ13_GENERATOR_SCHEMA_VERSION
			)
		elif is_gq12:
			policy["generator_policy_id"] = ProportionSpecScript.GQ12_GENERATOR_POLICY_ID
			policy["generator_schema_version"] = (
				ProportionSpecScript.GQ12_GENERATOR_SCHEMA_VERSION
			)
		elif is_gq11:
			policy["generator_policy_id"] = ProportionSpecScript.GQ11_GENERATOR_POLICY_ID
			policy["generator_schema_version"] = (
				ProportionSpecScript.GQ11_GENERATOR_SCHEMA_VERSION
			)
		elif is_gq10:
			policy["generator_policy_id"] = ProportionSpecScript.GQ10_GENERATOR_POLICY_ID
			policy["generator_schema_version"] = (
				ProportionSpecScript.GQ10_GENERATOR_SCHEMA_VERSION
			)
		elif is_gq9:
			policy["generator_policy_id"] = ProportionSpecScript.GQ9_GENERATOR_POLICY_ID
			policy["generator_schema_version"] = (
				ProportionSpecScript.GQ9_GENERATOR_SCHEMA_VERSION
			)
		elif is_gq8:
			policy["generator_policy_id"] = ProportionSpecScript.GQ8_GENERATOR_POLICY_ID
			policy["generator_schema_version"] = (
				ProportionSpecScript.GQ8_GENERATOR_SCHEMA_VERSION
			)
		elif is_gq7:
			policy["generator_policy_id"] = ProportionSpecScript.GQ7_GENERATOR_POLICY_ID
			policy["generator_schema_version"] = (
				ProportionSpecScript.GQ7_GENERATOR_SCHEMA_VERSION
			)
		elif is_gq6:
			policy["generator_policy_id"] = ProportionSpecScript.GQ6_GENERATOR_POLICY_ID
			policy["generator_schema_version"] = (
				ProportionSpecScript.GQ6_GENERATOR_SCHEMA_VERSION
			)
		elif is_gq5:
			policy["generator_policy_id"] = ProportionSpecScript.GQ5_GENERATOR_POLICY_ID
			policy["generator_schema_version"] = (
				ProportionSpecScript.GQ5_GENERATOR_SCHEMA_VERSION
			)
		elif is_gq4:
			policy["generator_policy_id"] = ProportionSpecScript.GQ4_GENERATOR_POLICY_ID
			policy["generator_schema_version"] = (
				ProportionSpecScript.GQ4_GENERATOR_SCHEMA_VERSION
			)
		elif is_gq3:
			policy["generator_policy_id"] = ProportionSpecScript.GQ3_GENERATOR_POLICY_ID
			policy["generator_schema_version"] = (
				ProportionSpecScript.GQ3_GENERATOR_SCHEMA_VERSION
			)
		elif is_gq2:
			policy["generator_policy_id"] = ProportionSpecScript.GQ2_GENERATOR_POLICY_ID
			policy["generator_schema_version"] = (
				ProportionSpecScript.GQ2_GENERATOR_SCHEMA_VERSION
			)
		else:
			policy["generator_policy_id"] = ProportionSpecScript.GQ1_GENERATOR_POLICY_ID
			policy["generator_schema_version"] = (
				ProportionSpecScript.GQ1_GENERATOR_SCHEMA_VERSION
			)
		policy["selection_generator_indices"] = selection_indices
		policy["held_out_generator_indices"] = held_out_indices
		policy["generator_axis_bases"] = ProportionSpecScript.GQ1_AXIS_BASES
		policy["generator_axis_intervals"] = ProportionSpecScript.GQ1_AXIS_INTERVALS
		policy["generator_receipts"] = generation_receipts
	if (
		is_gp4
		or is_gq6
		or is_gq7
		or is_gq8
		or is_gq9
		or is_gq10
		or is_gq11
		or is_gq12
		or is_gq13
		or is_gq14
	):
		var solver_result := WaveGaitScript.compile_solver_policy_options(GP4_SOLVER_POLICY_OPTIONS)
		policy["solver_policy_options"] = GP4_SOLVER_POLICY_OPTIONS
		policy["solver_policy_sha256"] = String(
			solver_result.get("solver_policy_configuration_sha256", "")
		)
	if (
		is_gq6
		or is_gq7
		or is_gq8
		or is_gq9
		or is_gq10
		or is_gq11
		or is_gq12
		or is_gq13
		or is_gq14
	):
		var clock_options := (
			ClockSpecScript.gq14_clock()
			if is_gq14
			else (
				ClockSpecScript.gq13_clock()
				if is_gq13
				else (
					ClockSpecScript.gq12_clock()
					if is_gq12
					else (
						ClockSpecScript.gq11_clock()
						if is_gq11
						else (
							ClockSpecScript.gq10_clock()
							if is_gq10
							else (
								ClockSpecScript.gq9_clock()
								if is_gq9
								else (
									ClockSpecScript.gq8_clock()
									if is_gq8
									else (
										ClockSpecScript.gq7_clock()
										if is_gq7
										else ClockSpecScript.gq6_clock()
									)
								)
							)
						)
					)
				)
			)
		)
		var clock_result := ClockSpecScript.compile(clock_options)
		policy["clock_options"] = clock_options
		policy["clock_sha256"] = CanonicalJsonScript.sha256(
			clock_result.get("gait_clock_options", {})
		)
		policy["robustness_options"] = (
			GQ14_ROBUSTNESS_OPTIONS
			if is_gq14
			else (
				GQ13_ROBUSTNESS_OPTIONS
				if is_gq13
				else (
					GQ12_ROBUSTNESS_OPTIONS
					if is_gq12
					else (
						GQ11_ROBUSTNESS_OPTIONS
						if is_gq11
						else (
							GQ10_ROBUSTNESS_OPTIONS
							if is_gq10
							else (
								GQ9_ROBUSTNESS_OPTIONS
								if is_gq9
								else (
									GQ8_ROBUSTNESS_OPTIONS
									if is_gq8
									else (
										GQ7_ROBUSTNESS_OPTIONS
										if is_gq7
										else GQ6_ROBUSTNESS_OPTIONS
									)
								)
							)
						)
					)
				)
			)
		)
		policy["evidence_threshold_formula_overrides"] = {
			"minimum_foot_relocation_m": "0.0238*torso_length_m",
			"maximum_anchor_error_m": "0.14*upper_leg_length_m",
		}
	if is_gq14:
		policy["feature_schema_version"] = FeatureReceiptScript.SCHEMA_VERSION
		policy["feature_policy_id"] = FeatureReceiptScript.GQ14_POLICY_ID
		policy["coverage_schema_version"] = CoverageReceiptScript.GQ14_SCHEMA_VERSION
		policy["coverage_policy_id"] = CoverageReceiptScript.GQ14_POLICY_ID
		policy["coverage_claim_level"] = CoverageReceiptScript.GQ14_CLAIM_LEVEL
		policy["candidate34_source_sha256"] = (
			CoverageReceiptScript.CANDIDATE34_SOURCE_SHA256
		)
		policy["dynamic_support_schema_version"] = (
			DynamicSupportReceiptScript.GQ14_SCHEMA_VERSION
		)
		policy["dynamic_support_policy_id"] = (
			DynamicSupportReceiptScript.GQ14_POLICY_ID
		)
		policy["dynamic_support_sample_schema_version"] = (
			DynamicSupportReceiptScript.GQ14_SAMPLE_SCHEMA_VERSION
		)
		policy["report_schema_version"] = (
			"sporespore_br14a_nonuniform_proportion_probe_report_v19"
		)
	elif is_gq13:
		policy["feature_schema_version"] = FeatureReceiptScript.SCHEMA_VERSION
		policy["feature_policy_id"] = FeatureReceiptScript.POLICY_ID
		policy["coverage_schema_version"] = CoverageReceiptScript.SCHEMA_VERSION
		policy["coverage_policy_id"] = CoverageReceiptScript.POLICY_ID
		policy["coverage_claim_level"] = CoverageReceiptScript.CLAIM_LEVEL
		policy["candidate33_source_sha256"] = CoverageReceiptScript.CANDIDATE33_SOURCE_SHA256
		policy["dynamic_support_schema_version"] = (
			"sporespore_dynamic_support_diagnostic_receipt_v1"
		)
		policy["dynamic_support_policy_id"] = (
			"g4_gq13_read_only_dynamic_support_trace_v1"
		)
		policy["report_schema_version"] = (
			"sporespore_br14a_nonuniform_proportion_probe_report_v18"
		)
	return policy


static func _gq15_formula_policy() -> Dictionary:
	# Candidate 35 is a frozen, additive successor to Candidate 34. Building its
	# receipt from the prior campaign keeps every unchanged formula byte-exact,
	# while the mutations below enumerate the complete GQ15 delta.
	var policy := _formula_policy(CAMPAIGN_GQ14)
	var clock_options := ClockSpecScript.gq15_clock()
	var clock_result := ClockSpecScript.compile(clock_options)
	var generation_receipts: Array = []
	for generator_index in (
		ProportionSpecScript.GQ15_SELECTION_INDICES
		+ ProportionSpecScript.GQ15_HELD_OUT_INDICES
	):
		var generation_result := ProportionSpecScript.compile_gq15_generation(
			int(generator_index)
		)
		generation_receipts.append(
			{
				"generator_receipt": generation_result.get("generator_receipt", {}),
				"generator_receipt_sha256":
				String(generation_result.get("generator_receipt_sha256", "")),
			}
		)
	policy["schema_version"] = "sporespore_g4_gq15_candidate35_opened_matrix_policy_v1"
	policy["campaign_id"] = CAMPAIGN_GQ15
	policy["selection_cells"] = ProportionSpecScript.gq15_selection_cells()
	policy["held_out_cells"] = ProportionSpecScript.gq15_held_out_cells()
	policy["clock_policy_id"] = ClockSpecScript.GQ15_POLICY_ID
	policy["path_steering_options_score_half_or_above_template"] = (
		GQ15_PATH_STEERING_OPTIONS
	)
	policy["path_velocity_gain_derivation_id"] = (
		"candidate35_short_wide_interaction_band_plus_candidate34_v10"
	)
	policy["path_velocity_gain_formula"] = (
		"candidate34 precedence; else 0.25+0.025*clamp((S-0.5)/0.5,0,1)"
		+ "+0.025*clamp((S-0.5)/0.5,0,1)*clamp((W-1.02)/0.04,0,1)"
		+ " if S>=0.5 and L<1 and W>1; else candidate34"
	)
	policy["motor_anchor_guard_override_derivation_id"] = (
		"candidate35_union_long_narrow_or_nonneutral_width_v2"
	)
	policy["motor_anchor_guard_override_formula"] = (
		"[0.70,1.75] if S>=0.5 and L>1.04 and (W<0.95 or W>1.0) else base"
	)
	policy["generator_policy_id"] = ProportionSpecScript.GQ15_GENERATOR_POLICY_ID
	policy["generator_schema_version"] = ProportionSpecScript.GQ15_GENERATOR_SCHEMA_VERSION
	policy["selection_generator_indices"] = ProportionSpecScript.GQ15_SELECTION_INDICES
	policy["held_out_generator_indices"] = ProportionSpecScript.GQ15_HELD_OUT_INDICES
	policy["generator_receipts"] = generation_receipts
	policy["clock_options"] = clock_options
	policy["clock_sha256"] = CanonicalJsonScript.sha256(
		clock_result.get("gait_clock_options", {})
	)
	policy["robustness_options"] = GQ15_ROBUSTNESS_OPTIONS
	policy["feature_policy_id"] = FeatureReceiptScript.GQ15_POLICY_ID
	policy["coverage_schema_version"] = CoverageReceiptScript.GQ15_SCHEMA_VERSION
	policy["coverage_policy_id"] = CoverageReceiptScript.GQ15_POLICY_ID
	policy["coverage_claim_level"] = CoverageReceiptScript.GQ15_CLAIM_LEVEL
	policy.erase("candidate34_source_sha256")
	policy["candidate35_source_sha256"] = CoverageReceiptScript.CANDIDATE35_SOURCE_SHA256
	policy["dynamic_support_schema_version"] = (
		DynamicSupportReceiptScript.GQ15_SCHEMA_VERSION
	)
	policy["dynamic_support_policy_id"] = DynamicSupportReceiptScript.GQ15_POLICY_ID
	policy["dynamic_support_sample_schema_version"] = (
		DynamicSupportReceiptScript.GQ15_SAMPLE_SCHEMA_VERSION
	)
	policy["report_schema_version"] = "sporespore_br14a_nonuniform_proportion_probe_report_v20"
	return policy


static func _candidate33_controller_sha256(
	declared: Dictionary,
	gait_clock: Dictionary,
	robustness_options: Dictionary,
) -> String:
	var motor_result := WaveGaitScript._normalize_motor_velocity_options(
		_motor_velocity_options(CAMPAIGN_GQ13, declared),
		int(gait_clock.get("cycle_ticks", 360)),
	)
	if not bool(motor_result.get("ok", false)):
		return ""
	var controller := WaveGaitScript._controller_configuration(
		-1.0,
		10.0,
		1.75,
		"lateral",
		WaveGaitScript._resolve_gait_phase_order("lateral"),
		int(gait_clock["swing_ticks"]),
		0.40,
		"all",
		int(gait_clock["evidence_boundary_alignment_ticks"]),
		robustness_options,
		_path_steering_options(CAMPAIGN_GQ13, declared),
		GP3_ACTUATOR_IMPULSE_OPTIONS,
		motor_result["motor_velocity_options"],
		gait_clock,
	)
	return CanonicalJsonScript.sha256(controller)


static func _candidate34_controller_sha256(
	declared: Dictionary,
	gait_clock: Dictionary,
	robustness_options: Dictionary,
) -> String:
	var motor_result := WaveGaitScript._normalize_motor_velocity_options(
		_motor_velocity_options(CAMPAIGN_GQ14, declared),
		int(gait_clock.get("cycle_ticks", 360)),
	)
	if not bool(motor_result.get("ok", false)):
		return ""
	var controller := WaveGaitScript._controller_configuration(
		-1.0,
		10.0,
		1.75,
		"lateral",
		WaveGaitScript._resolve_gait_phase_order("lateral"),
		int(gait_clock["swing_ticks"]),
		0.40,
		"all",
		int(gait_clock["evidence_boundary_alignment_ticks"]),
		robustness_options,
		_path_steering_options(CAMPAIGN_GQ14, declared),
		GP3_ACTUATOR_IMPULSE_OPTIONS,
		motor_result["motor_velocity_options"],
		gait_clock,
	)
	return CanonicalJsonScript.sha256(controller)


static func _candidate35_controller_sha256(
	declared: Dictionary,
	gait_clock: Dictionary,
	robustness_options: Dictionary,
) -> String:
	var motor_result := WaveGaitScript._normalize_motor_velocity_options(
		_motor_velocity_options(CAMPAIGN_GQ15, declared),
		int(gait_clock.get("cycle_ticks", 360)),
	)
	if not bool(motor_result.get("ok", false)):
		return ""
	var controller := WaveGaitScript._controller_configuration(
		-1.0,
		10.0,
		1.75,
		"lateral",
		WaveGaitScript._resolve_gait_phase_order("lateral"),
		int(gait_clock["swing_ticks"]),
		0.40,
		"all",
		int(gait_clock["evidence_boundary_alignment_ticks"]),
		robustness_options,
		_path_steering_options(CAMPAIGN_GQ15, declared),
		GP3_ACTUATOR_IMPULSE_OPTIONS,
		motor_result["motor_velocity_options"],
		gait_clock,
	)
	return CanonicalJsonScript.sha256(controller)


static func _gq13_candidate33_cohort_feature_results() -> Array:
	var clock_result := ClockSpecScript.compile(ClockSpecScript.gq11_clock())
	var solver_result := WaveGaitScript.compile_solver_policy_options(GP4_SOLVER_POLICY_OPTIONS)
	if not bool(clock_result.get("ok", false)) or not bool(solver_result.get("ok", false)):
		return []
	var gait_clock: Dictionary = clock_result["gait_clock_options"]
	var solver_options: Dictionary = solver_result["solver_policy_options"]
	var results: Array = []
	var ordered_indices: Array = (
		ProportionSpecScript.GQ11_SELECTION_INDICES
		+ ProportionSpecScript.GQ11_HELD_OUT_INDICES
	)
	for generator_index_value in ordered_indices:
		var generation_result := ProportionSpecScript.compile_gq11_generation(
			int(generator_index_value)
		)
		if not bool(generation_result.get("ok", false)):
			return []
		var declared: Dictionary = generation_result["proportion_spec"]
		var proportion_result := ProportionSpecScript.compile(declared)
		if not bool(proportion_result.get("ok", false)):
			return []
		var controller_digest := _candidate33_controller_sha256(
			declared,
			gait_clock,
			GQ11_ROBUSTNESS_OPTIONS,
		)
		var feature_result := FeatureReceiptScript.compile(
			generation_result,
			proportion_result,
			controller_digest,
			gait_clock,
			solver_options,
		)
		if not bool(feature_result.get("ok", false)):
			return []
		results.append(feature_result)
	return results


static func _gq14_candidate34_cohort_feature_results() -> Array:
	var solver_result := WaveGaitScript.compile_solver_policy_options(
		GP4_SOLVER_POLICY_OPTIONS
	)
	if not bool(solver_result.get("ok", false)):
		return []
	var solver_options: Dictionary = solver_result["solver_policy_options"]
	var results: Array = []
	var cohort_profiles := [
		{
			"indices":
			(
				ProportionSpecScript.GQ11_SELECTION_INDICES
				+ ProportionSpecScript.GQ11_HELD_OUT_INDICES
			),
			"clock": ClockSpecScript.gq11_clock(),
			"robustness": GQ11_ROBUSTNESS_OPTIONS,
			"compile_generation": Callable(
				ProportionSpecScript,
				"compile_gq11_generation",
			),
		},
		{
			"indices": ProportionSpecScript.GQ13_SELECTION_INDICES,
			"clock": ClockSpecScript.gq13_clock(),
			"robustness": GQ13_ROBUSTNESS_OPTIONS,
			"compile_generation": Callable(
				ProportionSpecScript,
				"compile_gq13_generation",
			),
		},
	]
	for profile_value in cohort_profiles:
		var profile: Dictionary = profile_value
		var clock_result := ClockSpecScript.compile(profile["clock"])
		if not bool(clock_result.get("ok", false)):
			return []
		var gait_clock: Dictionary = clock_result["gait_clock_options"]
		var compile_generation: Callable = profile["compile_generation"]
		for generator_index_value in profile["indices"]:
			var generation_result: Dictionary = compile_generation.call(
				int(generator_index_value)
			)
			if not bool(generation_result.get("ok", false)):
				return []
			var declared: Dictionary = generation_result["proportion_spec"]
			var proportion_result := ProportionSpecScript.compile(declared)
			if not bool(proportion_result.get("ok", false)):
				return []
			var controller_digest := _candidate34_controller_sha256(
				declared,
				gait_clock,
				profile["robustness"],
			)
			var feature_result := FeatureReceiptScript.compile(
				generation_result,
				proportion_result,
				controller_digest,
				gait_clock,
				solver_options,
			)
			if not bool(feature_result.get("ok", false)):
				return []
			results.append(feature_result)
	return results


static func _gq15_candidate35_cohort_feature_results() -> Array:
	var solver_result := WaveGaitScript.compile_solver_policy_options(
		GP4_SOLVER_POLICY_OPTIONS
	)
	if not bool(solver_result.get("ok", false)):
		return []
	var solver_options: Dictionary = solver_result["solver_policy_options"]
	var results: Array = []
	var cohort_profiles := [
		{
			"indices":
			(
				ProportionSpecScript.GQ11_SELECTION_INDICES
				+ ProportionSpecScript.GQ11_HELD_OUT_INDICES
			),
			"clock": ClockSpecScript.gq11_clock(),
			"robustness": GQ11_ROBUSTNESS_OPTIONS,
			"compile_generation": Callable(
				ProportionSpecScript,
				"compile_gq11_generation",
			),
		},
		{
			"indices": ProportionSpecScript.GQ12_SELECTION_INDICES,
			"clock": ClockSpecScript.gq12_clock(),
			"robustness": GQ12_ROBUSTNESS_OPTIONS,
			"compile_generation": Callable(
				ProportionSpecScript,
				"compile_gq12_generation",
			),
		},
		{
			"indices": ProportionSpecScript.GQ13_SELECTION_INDICES,
			"clock": ClockSpecScript.gq13_clock(),
			"robustness": GQ13_ROBUSTNESS_OPTIONS,
			"compile_generation": Callable(
				ProportionSpecScript,
				"compile_gq13_generation",
			),
		},
		{
			"indices": ProportionSpecScript.GQ14_SELECTION_INDICES,
			"clock": ClockSpecScript.gq14_clock(),
			"robustness": GQ14_ROBUSTNESS_OPTIONS,
			"compile_generation": Callable(
				ProportionSpecScript,
				"compile_gq14_generation",
			),
		},
	]
	for profile_value in cohort_profiles:
		var profile: Dictionary = profile_value
		var clock_result := ClockSpecScript.compile(profile["clock"])
		if not bool(clock_result.get("ok", false)):
			return []
		var gait_clock: Dictionary = clock_result["gait_clock_options"]
		var compile_generation: Callable = profile["compile_generation"]
		for generator_index_value in profile["indices"]:
			var generation_result: Dictionary = compile_generation.call(
				int(generator_index_value)
			)
			if not bool(generation_result.get("ok", false)):
				return []
			var declared: Dictionary = generation_result["proportion_spec"]
			var proportion_result := ProportionSpecScript.compile(declared)
			if not bool(proportion_result.get("ok", false)):
				return []
			var controller_digest := _candidate35_controller_sha256(
				declared,
				gait_clock,
				profile["robustness"],
			)
			var feature_result := FeatureReceiptScript.compile(
				generation_result,
				proportion_result,
				controller_digest,
				gait_clock,
				solver_options,
			)
			if not bool(feature_result.get("ok", false)):
				return []
			results.append(feature_result)
	return results


static func _gq13_feature_coverage_exact(
	feature_result: Dictionary,
	coverage_result: Dictionary,
	generation_digest: String,
	fixture_digest: String,
	expected_controller_digest: String,
) -> bool:
	if (
		not bool(feature_result.get("ok", false))
		or int(feature_result.get("world_build_count", -1)) != 0
		or not bool(coverage_result.get("ok", false))
		or int(coverage_result.get("world_build_count", -1)) != 0
	):
		return false
	var feature_receipt: Dictionary = feature_result.get("feature_receipt", {})
	var coverage_receipt: Dictionary = coverage_result.get("coverage_receipt", {})
	var feature_digest := String(feature_result.get("feature_receipt_sha256", ""))
	var coverage_digest := String(coverage_result.get("coverage_receipt_sha256", ""))
	var source_digests: Dictionary = feature_receipt.get("source_digests", {})
	return (
		String(feature_receipt.get("schema_version", "")) == FeatureReceiptScript.SCHEMA_VERSION
		and String(feature_receipt.get("policy_id", "")) == FeatureReceiptScript.POLICY_ID
		and String(feature_receipt.get("campaign_id", "")) == CAMPAIGN_GQ13
		and feature_digest == CanonicalJsonScript.sha256(feature_receipt)
		and String(source_digests.get("generator_receipt_sha256", "")) == generation_digest
		and String(source_digests.get("fixture_spec_sha256", "")) == fixture_digest
		and (
			String(source_digests.get("controller_configuration_sha256", ""))
			== expected_controller_digest
		)
		and (
			String(feature_receipt.get("policy_response", ""))
			== "REPORT_ONLY_NO_CONTROLLER_OR_ACCEPTANCE_AUTHORITY"
		)
		and not bool(feature_receipt.get("formal_milestone_acceptance_authorized", true))
		and not bool(feature_receipt.get("encyclopedia_admission_authorized", true))
		and not bool(feature_receipt.get("automatic_creature_guidance_allowed", true))
		and (
			String(coverage_receipt.get("schema_version", ""))
			== CoverageReceiptScript.SCHEMA_VERSION
		)
		and String(coverage_receipt.get("policy_id", "")) == CoverageReceiptScript.POLICY_ID
		and coverage_digest == CanonicalJsonScript.sha256(coverage_receipt)
		and String(coverage_receipt.get("query_feature_receipt_sha256", "")) == feature_digest
		and (
			String(coverage_receipt.get("status", ""))
			in ["SUPPORTED", "EDGE", "OUT_OF_DISTRIBUTION"]
		)
		and (
			String(coverage_receipt.get("policy_response", ""))
			== CoverageReceiptScript.POLICY_RESPONSE
		)
		and not bool(coverage_receipt.get("controller_branch_authority", true))
		and not bool(coverage_receipt.get("physical_acceptance_authority", true))
		and not bool(coverage_receipt.get("formal_milestone_acceptance_authorized", true))
		and not bool(coverage_receipt.get("encyclopedia_admission_authorized", true))
		and not bool(coverage_receipt.get("automatic_creature_guidance_allowed", true))
	)


static func _gq14_feature_coverage_exact(
	feature_result: Dictionary,
	coverage_result: Dictionary,
	generation_digest: String,
	fixture_digest: String,
	expected_controller_digest: String,
) -> bool:
	if (
		not bool(feature_result.get("ok", false))
		or int(feature_result.get("world_build_count", -1)) != 0
		or not bool(coverage_result.get("ok", false))
		or int(coverage_result.get("world_build_count", -1)) != 0
	):
		return false
	var feature_receipt: Dictionary = feature_result.get("feature_receipt", {})
	var coverage_receipt: Dictionary = coverage_result.get("coverage_receipt", {})
	var feature_digest := String(feature_result.get("feature_receipt_sha256", ""))
	var coverage_digest := String(coverage_result.get("coverage_receipt_sha256", ""))
	var source_digests: Dictionary = feature_receipt.get("source_digests", {})
	return (
		String(feature_receipt.get("schema_version", ""))
		== FeatureReceiptScript.SCHEMA_VERSION
		and String(feature_receipt.get("policy_id", ""))
		== FeatureReceiptScript.GQ14_POLICY_ID
		and String(feature_receipt.get("campaign_id", "")) == CAMPAIGN_GQ14
		and feature_digest == CanonicalJsonScript.sha256(feature_receipt)
		and String(source_digests.get("generator_receipt_sha256", ""))
		== generation_digest
		and String(source_digests.get("fixture_spec_sha256", "")) == fixture_digest
		and String(source_digests.get("controller_configuration_sha256", ""))
		== expected_controller_digest
		and String(feature_receipt.get("policy_response", ""))
		== "REPORT_ONLY_NO_CONTROLLER_OR_ACCEPTANCE_AUTHORITY"
		and not bool(feature_receipt.get("formal_milestone_acceptance_authorized", true))
		and not bool(feature_receipt.get("encyclopedia_admission_authorized", true))
		and not bool(feature_receipt.get("automatic_creature_guidance_allowed", true))
		and String(coverage_receipt.get("schema_version", ""))
		== CoverageReceiptScript.GQ14_SCHEMA_VERSION
		and String(coverage_receipt.get("policy_id", ""))
		== CoverageReceiptScript.GQ14_POLICY_ID
		and String(coverage_receipt.get("claim_level", ""))
		== CoverageReceiptScript.GQ14_CLAIM_LEVEL
		and String(coverage_receipt.get("candidate34_source_sha256", ""))
		== CoverageReceiptScript.CANDIDATE34_SOURCE_SHA256
		and (
			coverage_receipt.get("ordered_cohort_member_ids", []) as Array
		) == CoverageReceiptScript.GQ14_COHORT_IDS
		and coverage_digest == CanonicalJsonScript.sha256(coverage_receipt)
		and String(coverage_receipt.get("query_feature_receipt_sha256", ""))
		== feature_digest
		and String(coverage_receipt.get("status", ""))
		in ["SUPPORTED", "EDGE", "OUT_OF_DISTRIBUTION"]
		and String(coverage_receipt.get("policy_response", ""))
		== CoverageReceiptScript.POLICY_RESPONSE
		and not bool(coverage_receipt.get("controller_branch_authority", true))
		and not bool(coverage_receipt.get("physical_acceptance_authority", true))
		and not bool(coverage_receipt.get("formal_milestone_acceptance_authorized", true))
		and not bool(coverage_receipt.get("encyclopedia_admission_authorized", true))
		and not bool(coverage_receipt.get("automatic_creature_guidance_allowed", true))
	)


static func _gq15_feature_coverage_exact(
	feature_result: Dictionary,
	coverage_result: Dictionary,
	generation_digest: String,
	fixture_digest: String,
	expected_controller_digest: String,
) -> bool:
	if (
		not bool(feature_result.get("ok", false))
		or int(feature_result.get("world_build_count", -1)) != 0
		or not bool(coverage_result.get("ok", false))
		or int(coverage_result.get("world_build_count", -1)) != 0
	):
		return false
	var feature_receipt: Dictionary = feature_result.get("feature_receipt", {})
	var coverage_receipt: Dictionary = coverage_result.get("coverage_receipt", {})
	var feature_digest := String(feature_result.get("feature_receipt_sha256", ""))
	var coverage_digest := String(coverage_result.get("coverage_receipt_sha256", ""))
	var source_digests: Dictionary = feature_receipt.get("source_digests", {})
	return (
		String(feature_receipt.get("schema_version", ""))
		== FeatureReceiptScript.SCHEMA_VERSION
		and String(feature_receipt.get("policy_id", ""))
		== FeatureReceiptScript.GQ15_POLICY_ID
		and String(feature_receipt.get("campaign_id", "")) == CAMPAIGN_GQ15
		and feature_digest == CanonicalJsonScript.sha256(feature_receipt)
		and String(source_digests.get("generator_receipt_sha256", ""))
		== generation_digest
		and String(source_digests.get("fixture_spec_sha256", "")) == fixture_digest
		and String(source_digests.get("controller_configuration_sha256", ""))
		== expected_controller_digest
		and String(feature_receipt.get("policy_response", ""))
		== "REPORT_ONLY_NO_CONTROLLER_OR_ACCEPTANCE_AUTHORITY"
		and not bool(feature_receipt.get("formal_milestone_acceptance_authorized", true))
		and not bool(feature_receipt.get("encyclopedia_admission_authorized", true))
		and not bool(feature_receipt.get("automatic_creature_guidance_allowed", true))
		and String(coverage_receipt.get("schema_version", ""))
		== CoverageReceiptScript.GQ15_SCHEMA_VERSION
		and String(coverage_receipt.get("policy_id", ""))
		== CoverageReceiptScript.GQ15_POLICY_ID
		and String(coverage_receipt.get("claim_level", ""))
		== CoverageReceiptScript.GQ15_CLAIM_LEVEL
		and String(coverage_receipt.get("candidate35_source_sha256", ""))
		== CoverageReceiptScript.CANDIDATE35_SOURCE_SHA256
		and (
			coverage_receipt.get("ordered_cohort_member_ids", []) as Array
		) == CoverageReceiptScript.GQ15_COHORT_IDS
		and coverage_digest == CanonicalJsonScript.sha256(coverage_receipt)
		and String(coverage_receipt.get("query_feature_receipt_sha256", ""))
		== feature_digest
		and String(coverage_receipt.get("status", ""))
		in ["SUPPORTED", "EDGE", "OUT_OF_DISTRIBUTION"]
		and String(coverage_receipt.get("policy_response", ""))
		== CoverageReceiptScript.POLICY_RESPONSE
		and not bool(coverage_receipt.get("controller_branch_authority", true))
		and not bool(coverage_receipt.get("physical_acceptance_authority", true))
		and not bool(coverage_receipt.get("formal_milestone_acceptance_authorized", true))
		and not bool(coverage_receipt.get("encyclopedia_admission_authorized", true))
		and not bool(coverage_receipt.get("automatic_creature_guidance_allowed", true))
	)


static func _sha256_resource(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return "sha256:%s" % FileAccess.get_sha256(path)


static func _gq13_dynamic_support_options(
	feature_result: Dictionary,
	coverage_result: Dictionary,
	generation_digest: String,
	fixture_digest: String,
	expected_controller_digest: String,
	gait_clock_digest: String,
	solver_policy_digest: String,
	lateral_limit_m: float,
) -> Dictionary:
	return {
		"enabled": true,
		"lateral_limit_m": lateral_limit_m,
		"source_digests":
		{
			"feature_receipt_sha256":
			String(feature_result.get("feature_receipt_sha256", "")),
			"coverage_receipt_sha256":
			String(coverage_result.get("coverage_receipt_sha256", "")),
			"generator_receipt_sha256": generation_digest,
			"fixture_spec_sha256": fixture_digest,
			"controller_configuration_sha256": expected_controller_digest,
			"gait_clock_configuration_sha256": gait_clock_digest,
			"solver_policy_configuration_sha256": solver_policy_digest,
			"proportion_spec_source_sha256":
			_sha256_resource(
				"res://scripts/lab/gait/physical_quadruped_proportion_spec.gd"
			),
			"fixture_spec_source_sha256":
			_sha256_resource(
				"res://scripts/lab/gait/physical_quadruped_fixture_spec.gd"
			),
			"gait_clock_source_sha256":
			_sha256_resource("res://scripts/lab/gait/physical_gait_clock_spec.gd"),
			"feature_receipt_source_sha256":
			_sha256_resource("res://scripts/lab/gait/morphology_feature_receipt.gd"),
			"coverage_receipt_source_sha256":
			_sha256_resource("res://scripts/lab/gait/morphology_coverage_receipt.gd"),
			"dynamic_support_observer_source_sha256":
			_sha256_resource(
				"res://scripts/lab/mechanics/spatial_dynamic_support_observer.gd"
			),
			"dynamic_support_receipt_source_sha256":
			_sha256_resource(
				"res://scripts/lab/mechanics/dynamic_support_diagnostic_receipt.gd"
			),
			"physical_wave_gait_source_sha256":
			_sha256_resource(
				"res://scripts/lab/gait/physical_wave_gait_quadruped.gd"
			),
			"campaign_harness_source_sha256":
			_sha256_resource(
				"res://tests/test_experimental_br14a_11_physical_wave_gait_nonuniform_proportion_probe.gd"
			),
		},
	}


static func _gq14_dynamic_support_options(
	feature_result: Dictionary,
	coverage_result: Dictionary,
	generation_digest: String,
	fixture_digest: String,
	expected_controller_digest: String,
	gait_clock_digest: String,
	solver_policy_digest: String,
	lateral_limit_m: float,
) -> Dictionary:
	var options := _gq13_dynamic_support_options(
		feature_result,
		coverage_result,
		generation_digest,
		fixture_digest,
		expected_controller_digest,
		gait_clock_digest,
		solver_policy_digest,
		lateral_limit_m,
	)
	options["receipt_schema_version"] = DynamicSupportReceiptScript.GQ14_SCHEMA_VERSION
	options["policy_id"] = DynamicSupportReceiptScript.GQ14_POLICY_ID
	options["sample_schema_version"] = (
		DynamicSupportReceiptScript.GQ14_SAMPLE_SCHEMA_VERSION
	)
	return options


static func _gq15_dynamic_support_options(
	feature_result: Dictionary,
	coverage_result: Dictionary,
	generation_digest: String,
	fixture_digest: String,
	expected_controller_digest: String,
	gait_clock_digest: String,
	solver_policy_digest: String,
	lateral_limit_m: float,
) -> Dictionary:
	var options := _gq13_dynamic_support_options(
		feature_result,
		coverage_result,
		generation_digest,
		fixture_digest,
		expected_controller_digest,
		gait_clock_digest,
		solver_policy_digest,
		lateral_limit_m,
	)
	options["receipt_schema_version"] = DynamicSupportReceiptScript.GQ15_SCHEMA_VERSION
	options["policy_id"] = DynamicSupportReceiptScript.GQ15_POLICY_ID
	options["sample_schema_version"] = (
		DynamicSupportReceiptScript.GQ15_SAMPLE_SCHEMA_VERSION
	)
	return options


static func _gq13_dynamic_support_output_exact(
	summary: Dictionary,
	dynamic_support_options: Dictionary,
) -> bool:
	if (
		not bool(summary.get("dynamic_support_diagnostic_enabled", false))
		or not bool(summary.get("dynamic_support_diagnostic_ok", false))
		or not String(summary.get("dynamic_support_diagnostic_failure_code", "")).is_empty()
	):
		return false
	var receipt: Dictionary = summary.get("dynamic_support_receipt", {})
	var receipt_digest := String(summary.get("dynamic_support_receipt_sha256", ""))
	var sample_count := int(summary.get("dynamic_support_trace_sample_count", -1))
	return (
		String(receipt.get("schema_version", "")) == "sporespore_dynamic_support_diagnostic_receipt_v1"
		and String(receipt.get("policy_id", "")) == "g4_gq13_read_only_dynamic_support_trace_v1"
		and receipt_digest == CanonicalJsonScript.sha256(receipt)
		and sample_count > 0
		and int(receipt.get("sample_count_dimensionless", -1)) == sample_count
		and (
			(receipt.get("source_digests", {}) as Dictionary)
			== (dynamic_support_options.get("source_digests", {}) as Dictionary)
		)
		and (
			String(receipt.get("policy_response", ""))
			== "REPORT_ONLY_NO_CONTROLLER_OR_ACCEPTANCE_AUTHORITY"
		)
		and not bool(receipt.get("contact_presence_is_bearing_measurement", true))
		and not bool(receipt.get("articulated_capture_guarantee_available", true))
		and not bool(receipt.get("controller_authority", true))
		and not bool(receipt.get("walker_predicate_authority", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
		and not bool(receipt.get("formal_milestone_acceptance_authorized", true))
		and not bool(receipt.get("encyclopedia_admission_authorized", true))
		and not bool(receipt.get("automatic_creature_guidance_allowed", true))
	)


static func _gq14_dynamic_support_output_exact(
	summary: Dictionary,
	dynamic_support_options: Dictionary,
) -> bool:
	if (
		not bool(summary.get("dynamic_support_diagnostic_enabled", false))
		or not bool(summary.get("dynamic_support_diagnostic_ok", false))
		or not String(summary.get("dynamic_support_diagnostic_failure_code", "")).is_empty()
	):
		return false
	var receipt: Dictionary = summary.get("dynamic_support_receipt", {})
	var receipt_digest := String(summary.get("dynamic_support_receipt_sha256", ""))
	var sample_count := int(summary.get("dynamic_support_trace_sample_count", -1))
	var dimension_counts: Dictionary = receipt.get(
		"support_geometry_sample_count_by_dimension",
		{},
	)
	return (
		String(receipt.get("schema_version", ""))
		== DynamicSupportReceiptScript.GQ14_SCHEMA_VERSION
		and String(receipt.get("policy_id", ""))
		== DynamicSupportReceiptScript.GQ14_POLICY_ID
		and receipt_digest == CanonicalJsonScript.sha256(receipt)
		and sample_count > 0
		and int(receipt.get("sample_count_dimensionless", -1)) == sample_count
		and int(dimension_counts.get("0", -1)) >= 0
		and int(dimension_counts.get("1", -1)) >= 0
		and int(dimension_counts.get("2", -1)) >= 0
		and (
			int(dimension_counts.get("0", 0))
			+ int(dimension_counts.get("1", 0))
			+ int(dimension_counts.get("2", 0))
			== sample_count
		)
		and (
			(receipt.get("source_digests", {}) as Dictionary)
			== (dynamic_support_options.get("source_digests", {}) as Dictionary)
		)
		and String(receipt.get("policy_response", ""))
		== "REPORT_ONLY_NO_CONTROLLER_OR_ACCEPTANCE_AUTHORITY"
		and not bool(receipt.get("contact_presence_is_bearing_measurement", true))
		and not bool(receipt.get("articulated_capture_guarantee_available", true))
		and not bool(receipt.get("controller_authority", true))
		and not bool(receipt.get("walker_predicate_authority", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
		and not bool(receipt.get("formal_milestone_acceptance_authorized", true))
		and not bool(receipt.get("encyclopedia_admission_authorized", true))
		and not bool(receipt.get("automatic_creature_guidance_allowed", true))
	)


static func _gq15_dynamic_support_output_exact(
	summary: Dictionary,
	dynamic_support_options: Dictionary,
) -> bool:
	if (
		not bool(summary.get("dynamic_support_diagnostic_enabled", false))
		or not bool(summary.get("dynamic_support_diagnostic_ok", false))
		or not String(summary.get("dynamic_support_diagnostic_failure_code", "")).is_empty()
	):
		return false
	var receipt: Dictionary = summary.get("dynamic_support_receipt", {})
	var receipt_digest := String(summary.get("dynamic_support_receipt_sha256", ""))
	var sample_count := int(summary.get("dynamic_support_trace_sample_count", -1))
	var dimension_counts: Dictionary = receipt.get(
		"support_geometry_sample_count_by_dimension",
		{},
	)
	return (
		String(receipt.get("schema_version", ""))
		== DynamicSupportReceiptScript.GQ15_SCHEMA_VERSION
		and String(receipt.get("policy_id", ""))
		== DynamicSupportReceiptScript.GQ15_POLICY_ID
		and receipt_digest == CanonicalJsonScript.sha256(receipt)
		and sample_count > 0
		and int(receipt.get("sample_count_dimensionless", -1)) == sample_count
		and int(dimension_counts.get("0", -1)) >= 0
		and int(dimension_counts.get("1", -1)) >= 0
		and int(dimension_counts.get("2", -1)) >= 0
		and (
			int(dimension_counts.get("0", 0))
			+ int(dimension_counts.get("1", 0))
			+ int(dimension_counts.get("2", 0))
			== sample_count
		)
		and (
			(receipt.get("source_digests", {}) as Dictionary)
			== (dynamic_support_options.get("source_digests", {}) as Dictionary)
		)
		and String(receipt.get("policy_response", ""))
		== "REPORT_ONLY_NO_CONTROLLER_OR_ACCEPTANCE_AUTHORITY"
		and not bool(receipt.get("contact_presence_is_bearing_measurement", true))
		and not bool(receipt.get("articulated_capture_guarantee_available", true))
		and not bool(receipt.get("controller_authority", true))
		and not bool(receipt.get("walker_predicate_authority", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
		and not bool(receipt.get("formal_milestone_acceptance_authorized", true))
		and not bool(receipt.get("encyclopedia_admission_authorized", true))
		and not bool(receipt.get("automatic_creature_guidance_allowed", true))
	)


static func _campaign_supported(campaign_id: String) -> bool:
	return (
		campaign_id == CAMPAIGN_GP1
		or campaign_id == CAMPAIGN_GP2
		or campaign_id == CAMPAIGN_GP3
		or campaign_id == CAMPAIGN_GP4
		or campaign_id == CAMPAIGN_GP5
		or campaign_id == CAMPAIGN_GQ1
		or campaign_id == CAMPAIGN_GQ2
		or campaign_id == CAMPAIGN_GQ3
		or campaign_id == CAMPAIGN_GQ4
		or campaign_id == CAMPAIGN_GQ5
		or campaign_id == CAMPAIGN_GQ6
		or campaign_id == CAMPAIGN_GQ7
		or campaign_id == CAMPAIGN_GQ8
		or campaign_id == CAMPAIGN_GQ9
		or campaign_id == CAMPAIGN_GQ10
		or campaign_id == CAMPAIGN_GQ11
		or campaign_id == CAMPAIGN_GQ12
		or campaign_id == CAMPAIGN_GQ13
		or campaign_id == CAMPAIGN_GQ14
		or campaign_id == CAMPAIGN_GQ15
	)


static func _robustness_options(campaign_id: String) -> Dictionary:
	return (
		GQ15_ROBUSTNESS_OPTIONS.duplicate(true)
		if campaign_id == CAMPAIGN_GQ15
		else (
			GQ14_ROBUSTNESS_OPTIONS.duplicate(true)
			if campaign_id == CAMPAIGN_GQ14
			else (
				GQ13_ROBUSTNESS_OPTIONS.duplicate(true)
				if campaign_id == CAMPAIGN_GQ13
				else (
					GQ12_ROBUSTNESS_OPTIONS.duplicate(true)
					if campaign_id == CAMPAIGN_GQ12
					else (
						GQ11_ROBUSTNESS_OPTIONS.duplicate(true)
						if campaign_id == CAMPAIGN_GQ11
						else (
							GQ10_ROBUSTNESS_OPTIONS.duplicate(true)
							if campaign_id == CAMPAIGN_GQ10
							else (
								GQ9_ROBUSTNESS_OPTIONS.duplicate(true)
								if campaign_id == CAMPAIGN_GQ9
								else (
									GQ8_ROBUSTNESS_OPTIONS.duplicate(true)
									if campaign_id == CAMPAIGN_GQ8
									else (
										GQ7_ROBUSTNESS_OPTIONS.duplicate(true)
										if campaign_id == CAMPAIGN_GQ7
										else (
											GQ6_ROBUSTNESS_OPTIONS.duplicate(true)
											if campaign_id == CAMPAIGN_GQ6
											else ROBUSTNESS_OPTIONS.duplicate(true)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	)


static func _path_steering_options(
	campaign_id: String,
	declared: Dictionary = {},
) -> Dictionary:
	if (
		campaign_id == CAMPAIGN_GQ6
		or campaign_id == CAMPAIGN_GQ7
		or campaign_id == CAMPAIGN_GQ8
		or campaign_id == CAMPAIGN_GQ9
		or campaign_id == CAMPAIGN_GQ10
		or campaign_id == CAMPAIGN_GQ11
		or campaign_id == CAMPAIGN_GQ12
		or campaign_id == CAMPAIGN_GQ13
		or campaign_id == CAMPAIGN_GQ14
		or campaign_id == CAMPAIGN_GQ15
	):
		var score := 1.0 if declared.is_empty() else _morphology_interaction_score(declared)
		var torso_length_scale := (
			1.0 if declared.is_empty() else float(declared["torso_length_scale"])
		)
		var torso_width_scale := (
			1.0 if declared.is_empty() else float(declared["torso_width_scale"])
		)
		var hip_span_scale := 1.0 if declared.is_empty() else float(declared["hip_span_scale"])
		var foot_radius_scale := (
			1.0 if declared.is_empty() else float(declared["foot_radius_scale"])
		)
		var yaw_gain := (
			_gq14_yaw_gain_per_rad(
				score,
				torso_length_scale,
				foot_radius_scale,
				hip_span_scale,
			)
			if campaign_id in [CAMPAIGN_GQ14, CAMPAIGN_GQ15]
			else (
				_gq13_yaw_gain_per_rad(
					score,
					torso_length_scale,
					foot_radius_scale,
					hip_span_scale,
				)
				if campaign_id == CAMPAIGN_GQ13
				else (
					_gq12_yaw_gain_per_rad(
						score,
						torso_length_scale,
						foot_radius_scale,
						hip_span_scale,
					)
					if campaign_id == CAMPAIGN_GQ12
					else (
						_gq11_yaw_gain_per_rad(
							score,
							torso_length_scale,
							foot_radius_scale,
							hip_span_scale,
						)
						if campaign_id == CAMPAIGN_GQ11
						else (
							_gq10_yaw_gain_per_rad(
								score,
								torso_length_scale,
								foot_radius_scale,
								hip_span_scale,
							)
							if campaign_id == CAMPAIGN_GQ10
							else (
								_gq9_yaw_gain_per_rad(
									score,
									torso_length_scale,
									foot_radius_scale,
									hip_span_scale,
								)
								if campaign_id == CAMPAIGN_GQ9
								else (
									_gq8_yaw_gain_per_rad(
										score,
										torso_length_scale,
										foot_radius_scale,
										hip_span_scale,
									)
									if campaign_id == CAMPAIGN_GQ8
									else (
										_gq7_yaw_gain_per_rad(
											score,
											torso_length_scale,
											foot_radius_scale,
											hip_span_scale,
										)
										if campaign_id == CAMPAIGN_GQ7
										else _gq6_yaw_gain_per_rad(
											score,
											torso_length_scale,
											foot_radius_scale,
											hip_span_scale,
										)
									)
								)
							)
						)
					)
				)
			)
		)
		var options := (
			GQ15_PATH_STEERING_OPTIONS.duplicate(true)
			if campaign_id == CAMPAIGN_GQ15
			else (
				GQ14_PATH_STEERING_OPTIONS.duplicate(true)
				if campaign_id == CAMPAIGN_GQ14
				else (
					GQ13_PATH_STEERING_OPTIONS.duplicate(true)
					if campaign_id == CAMPAIGN_GQ13
					else (
						GQ12_PATH_STEERING_OPTIONS.duplicate(true)
						if campaign_id == CAMPAIGN_GQ12
						else (
							GQ11_PATH_STEERING_OPTIONS.duplicate(true)
							if campaign_id == CAMPAIGN_GQ11
							else (
								GQ10_PATH_STEERING_OPTIONS.duplicate(true)
								if campaign_id == CAMPAIGN_GQ10
								else (
									GQ9_PATH_STEERING_OPTIONS.duplicate(true)
									if campaign_id == CAMPAIGN_GQ9
									else (
										GQ8_PATH_STEERING_OPTIONS.duplicate(true)
										if campaign_id == CAMPAIGN_GQ8
										else (
											GQ7_PATH_STEERING_OPTIONS.duplicate(true)
											if campaign_id == CAMPAIGN_GQ7
											else GQ6_PATH_STEERING_OPTIONS.duplicate(true)
										)
									)
								)
							)
						)
					)
				)
			)
		)
		options["cross_track_heading_gain_rad_per_m"] = (
			_gq14_cross_track_gain_per_m(score)
			if campaign_id in [CAMPAIGN_GQ14, CAMPAIGN_GQ15]
			else (
				_gq13_cross_track_gain_per_m(score)
				if campaign_id == CAMPAIGN_GQ13
				else (
					_gq12_cross_track_gain_per_m(score)
					if campaign_id == CAMPAIGN_GQ12
					else (
						_gq11_cross_track_gain_per_m(score)
						if campaign_id == CAMPAIGN_GQ11
						else (
							_gq10_cross_track_gain_per_m(score)
							if campaign_id == CAMPAIGN_GQ10
							else (
								_gq9_cross_track_gain_per_m(score)
								if campaign_id == CAMPAIGN_GQ9
								else (
									_gq8_cross_track_gain_per_m(score)
									if campaign_id == CAMPAIGN_GQ8
									else (
										_gq7_cross_track_gain_per_m(score)
										if campaign_id == CAMPAIGN_GQ7
										else _gq6_cross_track_gain_per_m(score)
									)
								)
							)
						)
					)
				)
			)
		)
		options["yaw_error_stride_gain_per_rad"] = yaw_gain
		options["cross_track_velocity_heading_gain_rad_per_m_s"] = (
			_gq12_velocity_gain_rad_per_m_s(
				score,
				torso_length_scale,
				torso_width_scale,
				foot_radius_scale,
				yaw_gain,
			)
			if campaign_id == CAMPAIGN_GQ12
			else (
				_gq11_velocity_gain_rad_per_m_s(
					score,
					torso_length_scale,
					torso_width_scale,
					yaw_gain,
				)
				if campaign_id == CAMPAIGN_GQ11
				else (
					_gq10_velocity_gain_rad_per_m_s(
						score,
						torso_length_scale,
						torso_width_scale,
						yaw_gain,
					)
					if campaign_id == CAMPAIGN_GQ10
					else (
						_gq9_velocity_gain_rad_per_m_s(
							score,
							torso_length_scale,
							torso_width_scale,
							yaw_gain,
						)
						if campaign_id == CAMPAIGN_GQ9
						else (
							_gq8_velocity_gain_rad_per_m_s(
								score,
								torso_length_scale,
								torso_width_scale,
								yaw_gain,
							)
							if campaign_id == CAMPAIGN_GQ8
							else (
								_gq7_velocity_gain_rad_per_m_s(
									score,
									torso_length_scale,
									torso_width_scale,
									yaw_gain,
								)
								if campaign_id == CAMPAIGN_GQ7
								else _gq6_velocity_gain_rad_per_m_s(
									score,
									torso_length_scale,
									torso_width_scale,
									yaw_gain,
								)
							)
						)
					)
				)
			)
		)
		if campaign_id == CAMPAIGN_GQ15:
			options["cross_track_velocity_heading_gain_rad_per_m_s"] = (
				_gq15_velocity_gain_rad_per_m_s(
					score,
					torso_length_scale,
					torso_width_scale,
					foot_radius_scale,
					yaw_gain,
				)
			)
		elif campaign_id == CAMPAIGN_GQ14:
			options["cross_track_velocity_heading_gain_rad_per_m_s"] = (
				_gq14_velocity_gain_rad_per_m_s(
					score,
					torso_length_scale,
					torso_width_scale,
					foot_radius_scale,
					yaw_gain,
				)
			)
		elif campaign_id == CAMPAIGN_GQ13:
			options["cross_track_velocity_heading_gain_rad_per_m_s"] = (
				_gq13_velocity_gain_rad_per_m_s(
					score,
					torso_length_scale,
					torso_width_scale,
					foot_radius_scale,
					yaw_gain,
				)
			)
		return options
	if (
		campaign_id == CAMPAIGN_GQ2
		or campaign_id == CAMPAIGN_GQ3
		or campaign_id == CAMPAIGN_GQ4
		or campaign_id == CAMPAIGN_GQ5
		or campaign_id == CAMPAIGN_GQ6
		or campaign_id == CAMPAIGN_GQ7
		or campaign_id == CAMPAIGN_GQ8
		or campaign_id == CAMPAIGN_GQ9
		or campaign_id == CAMPAIGN_GQ10
		or campaign_id == CAMPAIGN_GQ11
		or campaign_id == CAMPAIGN_GQ12
	):
		var options := (
			GQ5_PATH_STEERING_OPTIONS.duplicate(true)
			if campaign_id == CAMPAIGN_GQ5
			else (
				GQ4_PATH_STEERING_OPTIONS.duplicate(true)
				if campaign_id == CAMPAIGN_GQ4
				else (
					GQ3_PATH_STEERING_OPTIONS.duplicate(true)
					if campaign_id == CAMPAIGN_GQ3
					else GQ2_PATH_STEERING_OPTIONS.duplicate(true)
				)
			)
		)
		var score := 1.0 if declared.is_empty() else _morphology_interaction_score(declared)
		options["cross_track_heading_gain_rad_per_m"] = 1.0 if score < 0.5 else 0.75
		if campaign_id == CAMPAIGN_GQ5 or campaign_id == CAMPAIGN_GQ4:
			var foot_radius_scale := (
				1.0 if declared.is_empty() else float(declared["foot_radius_scale"])
			)
			var hip_span_scale := 1.0 if declared.is_empty() else float(declared["hip_span_scale"])
			options["yaw_error_stride_gain_per_rad"] = (
				_gq5_yaw_gain_per_rad(score, foot_radius_scale, hip_span_scale)
				if campaign_id == CAMPAIGN_GQ5
				else _gq4_yaw_gain_per_rad(score, foot_radius_scale, hip_span_scale)
			)
		elif campaign_id == CAMPAIGN_GQ3:
			options["yaw_error_stride_gain_per_rad"] = (
				1.3
				if (declared.is_empty() or float(declared["foot_radius_scale"]) <= 1.025)
				else 1.0
			)
		return options
	if (
		campaign_id == CAMPAIGN_GP3
		or campaign_id == CAMPAIGN_GP4
		or campaign_id == CAMPAIGN_GP5
		or campaign_id == CAMPAIGN_GQ1
		or campaign_id == CAMPAIGN_GQ2
		or campaign_id == CAMPAIGN_GQ3
		or campaign_id == CAMPAIGN_GQ4
		or campaign_id == CAMPAIGN_GQ5
		or campaign_id == CAMPAIGN_GQ7
		or campaign_id == CAMPAIGN_GQ8
		or campaign_id == CAMPAIGN_GQ9
		or campaign_id == CAMPAIGN_GQ10
		or campaign_id == CAMPAIGN_GQ11
		or campaign_id == CAMPAIGN_GQ12
	):
		return GP3_PATH_STEERING_OPTIONS.duplicate(true)
	return PATH_STEERING_OPTIONS.duplicate(true)


static func _gq4_yaw_gain_per_rad(
	morphology_interaction_score: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	if foot_radius_scale > 1.025:
		return 1.0
	if foot_radius_scale > 1.01:
		return 1.3
	if morphology_interaction_score >= 0.5 and absf(hip_span_scale - 1.0) >= 0.02:
		return 1.25
	return 1.0


static func _gq5_yaw_gain_per_rad(
	morphology_interaction_score: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	if morphology_interaction_score < 0.5 or foot_radius_scale > 1.025:
		return 1.0
	if foot_radius_scale > 1.01:
		return 1.3
	if absf(hip_span_scale - 1.0) >= 0.02:
		return 1.25
	return 1.0


static func _gq6_cross_track_gain_per_m(morphology_interaction_score: float) -> float:
	return 1.0 if morphology_interaction_score < 0.5 else 0.75


static func _gq6_yaw_gain_per_rad(
	morphology_interaction_score: float,
	torso_length_scale: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	if foot_radius_scale < 0.985:
		return 1.3 if morphology_interaction_score >= 0.9 else 1.1
	if morphology_interaction_score < 0.5 or foot_radius_scale > 1.025:
		return 1.0
	if foot_radius_scale > 1.01:
		return 1.3
	if absf(hip_span_scale - 1.0) >= 0.02:
		return 1.1 if torso_length_scale > 1.02 else 1.0
	return 1.0


static func _gq6_velocity_gain_rad_per_m_s(
	morphology_interaction_score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	yaw_gain_per_rad: float,
) -> float:
	if yaw_gain_per_rad > 1.0:
		return 0.20
	if morphology_interaction_score < 0.15:
		return 0.20 if torso_width_scale <= 1.0 else 0.25
	if morphology_interaction_score < 0.5:
		return 0.30 if torso_width_scale <= 1.0 else 0.20
	return 0.20 if torso_width_scale > 1.0 and torso_length_scale < 1.0 else 0.25


static func _gq7_cross_track_gain_per_m(morphology_interaction_score: float) -> float:
	return 1.0 if morphology_interaction_score < 0.5 else 0.75


static func _gq7_yaw_gain_per_rad(
	morphology_interaction_score: float,
	torso_length_scale: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	if foot_radius_scale < 0.985:
		return 1.3 if morphology_interaction_score >= 0.9 else 1.1
	if morphology_interaction_score < 0.5 or foot_radius_scale > 1.025:
		return 1.0
	if foot_radius_scale > 1.01:
		return 1.3
	if absf(hip_span_scale - 1.0) >= 0.02:
		return 1.1 if torso_length_scale > 1.02 else 1.0
	return 1.0


static func _gq7_velocity_gain_rad_per_m_s(
	morphology_interaction_score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	yaw_gain_per_rad: float,
) -> float:
	if yaw_gain_per_rad > 1.0:
		return 0.20
	if morphology_interaction_score < 0.15:
		return 0.20 if torso_width_scale <= 1.0 else 0.25
	if morphology_interaction_score < 0.5:
		return 0.30 if torso_width_scale <= 1.0 else 0.20
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((morphology_interaction_score - 0.5) / 0.5, 0.0, 1.0)
	return 0.25


static func _gq8_cross_track_gain_per_m(morphology_interaction_score: float) -> float:
	return 1.0 if morphology_interaction_score < 0.5 else 0.75


static func _gq8_yaw_gain_per_rad(
	morphology_interaction_score: float,
	torso_length_scale: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	if foot_radius_scale < 0.985:
		return 1.3 if morphology_interaction_score >= 0.9 else 1.1
	if morphology_interaction_score < 0.5 or foot_radius_scale > 1.025:
		return 1.0
	if foot_radius_scale > 1.01:
		return 1.3
	if absf(hip_span_scale - 1.0) >= 0.02:
		return 1.1 if torso_length_scale > 1.02 else 1.0
	return 1.0


static func _gq8_velocity_gain_rad_per_m_s(
	morphology_interaction_score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	yaw_gain_per_rad: float,
) -> float:
	if yaw_gain_per_rad > 1.0:
		return 0.20
	if morphology_interaction_score < 0.15:
		return 0.25 if torso_width_scale <= 1.0 else 0.30
	if morphology_interaction_score < 0.5:
		return 0.60 if torso_width_scale <= 1.0 else 0.25
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((morphology_interaction_score - 0.5) / 0.5, 0.0, 1.0)
	return 0.30


static func _gq9_cross_track_gain_per_m(morphology_interaction_score: float) -> float:
	return 1.0 if morphology_interaction_score < 0.5 else 0.75


static func _gq9_yaw_gain_per_rad(
	morphology_interaction_score: float,
	torso_length_scale: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	if foot_radius_scale < 0.985:
		return 1.3 if morphology_interaction_score >= 0.9 else 1.1
	if morphology_interaction_score < 0.5 or foot_radius_scale > 1.025:
		return 1.0
	if foot_radius_scale > 1.01:
		return 1.3
	if absf(hip_span_scale - 1.0) >= 0.02:
		return 1.1 if torso_length_scale > 1.02 else 1.0
	return 1.0


static func _gq9_velocity_gain_rad_per_m_s(
	morphology_interaction_score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	yaw_gain_per_rad: float,
) -> float:
	if yaw_gain_per_rad > 1.0:
		return 0.20
	if morphology_interaction_score < 0.15:
		return 0.25 if torso_width_scale <= 1.0 else 0.30
	if morphology_interaction_score < 0.5:
		return 0.60 if torso_width_scale <= 1.0 else 0.25
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((morphology_interaction_score - 0.5) / 0.5, 0.0, 1.0)
	return 0.35


static func _gq10_cross_track_gain_per_m(morphology_interaction_score: float) -> float:
	return 1.0 if morphology_interaction_score < 0.5 else 0.75


static func _gq10_yaw_gain_per_rad(
	morphology_interaction_score: float,
	torso_length_scale: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	if foot_radius_scale < 0.985:
		return 1.3 if morphology_interaction_score >= 0.9 else 1.1
	if morphology_interaction_score < 0.5 or foot_radius_scale > 1.025:
		return 1.0
	if foot_radius_scale > 1.01:
		return 1.3
	if absf(hip_span_scale - 1.0) >= 0.02:
		return 1.1 if torso_length_scale > 1.02 else 1.0
	return 1.0


static func _gq10_velocity_gain_rad_per_m_s(
	morphology_interaction_score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	yaw_gain_per_rad: float,
) -> float:
	if yaw_gain_per_rad > 1.0:
		return 0.20
	if morphology_interaction_score < 0.15:
		return 0.25 if torso_width_scale <= 1.0 else 0.35
	if morphology_interaction_score < 0.5:
		return 0.70 if torso_width_scale <= 1.0 else 0.25
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((morphology_interaction_score - 0.5) / 0.5, 0.0, 1.0)
	return 0.35


static func _gq11_cross_track_gain_per_m(morphology_interaction_score: float) -> float:
	return 1.0 if morphology_interaction_score < 0.5 else 0.75


static func _gq11_yaw_gain_per_rad(
	morphology_interaction_score: float,
	torso_length_scale: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	if foot_radius_scale < 0.985:
		return 1.3 if morphology_interaction_score >= 0.9 else 1.1
	if morphology_interaction_score < 0.5 or foot_radius_scale > 1.025:
		return 1.0
	if foot_radius_scale > 1.01:
		return 1.3
	if absf(hip_span_scale - 1.0) >= 0.02:
		return 1.1 if torso_length_scale > 1.02 else 1.0
	return 1.0


static func _gq11_velocity_gain_rad_per_m_s(
	morphology_interaction_score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	yaw_gain_per_rad: float,
) -> float:
	if yaw_gain_per_rad > 1.0:
		return 0.25
	if morphology_interaction_score < 0.15:
		return 0.275 if torso_width_scale <= 1.0 else 0.35
	if morphology_interaction_score < 0.5:
		return 0.70 if torso_width_scale <= 1.0 else 0.25
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((morphology_interaction_score - 0.5) / 0.5, 0.0, 1.0)
	return 0.35


static func _gq12_cross_track_gain_per_m(morphology_interaction_score: float) -> float:
	return 1.0 if morphology_interaction_score < 0.5 else 0.75


static func _gq12_yaw_gain_per_rad(
	morphology_interaction_score: float,
	torso_length_scale: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	if foot_radius_scale < 0.985:
		return 1.3 if morphology_interaction_score >= 0.9 else 1.1
	if morphology_interaction_score < 0.5 or foot_radius_scale > 1.025:
		return 1.0
	if foot_radius_scale > 1.01:
		return 1.3
	if absf(hip_span_scale - 1.0) >= 0.02:
		return 1.1 if torso_length_scale > 1.02 else 1.0
	return 1.0


static func _gq12_velocity_gain_rad_per_m_s(
	morphology_interaction_score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	foot_radius_scale: float,
	yaw_gain_per_rad: float,
) -> float:
	if yaw_gain_per_rad > 1.0:
		var long_wide_gain_fraction := (
			clampf((torso_length_scale - 1.0) / 0.07, 0.0, 1.0)
			* clampf((torso_width_scale - 1.0) / 0.06, 0.0, 1.0)
		)
		return 0.25 + 0.05 * long_wide_gain_fraction
	if morphology_interaction_score < 0.15:
		if torso_width_scale <= 1.0:
			var long_small_foot_gain_fraction := (
				clampf((torso_length_scale - 1.0) / 0.01, 0.0, 1.0)
				* clampf((1.01 - foot_radius_scale) / 0.01, 0.0, 1.0)
			)
			return 0.275 + 0.075 * long_small_foot_gain_fraction
		return 0.35
	if morphology_interaction_score < 0.5:
		return 0.70 if torso_width_scale <= 1.0 else 0.25
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((morphology_interaction_score - 0.5) / 0.5, 0.0, 1.0)
	return 0.35


static func _gq13_cross_track_gain_per_m(morphology_interaction_score: float) -> float:
	return 1.0 if morphology_interaction_score < 0.5 else 0.75


static func _gq13_yaw_gain_per_rad(
	morphology_interaction_score: float,
	torso_length_scale: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	return _gq12_yaw_gain_per_rad(
		morphology_interaction_score,
		torso_length_scale,
		foot_radius_scale,
		hip_span_scale,
	)


static func _gq13_velocity_gain_rad_per_m_s(
	morphology_interaction_score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	foot_radius_scale: float,
	yaw_gain_per_rad: float,
) -> float:
	if yaw_gain_per_rad > 1.0:
		var long_wide_gain_fraction := (
			clampf((torso_length_scale - 1.0) / 0.07, 0.0, 1.0)
			* clampf((torso_width_scale - 1.0) / 0.06, 0.0, 1.0)
		)
		return 0.25 + 0.05 * long_wide_gain_fraction
	if morphology_interaction_score < 0.15:
		if torso_width_scale <= 1.0:
			var long_small_foot_gain_fraction := (
				clampf((torso_length_scale - 1.0) / 0.01, 0.0, 1.0)
				* clampf((1.01 - foot_radius_scale) / 0.01, 0.0, 1.0)
			)
			return 0.275 + 0.075 * long_small_foot_gain_fraction
		return 0.35
	if morphology_interaction_score < 0.5:
		return 0.75 if torso_width_scale <= 1.0 else 0.25
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf((morphology_interaction_score - 0.5) / 0.5, 0.0, 1.0)
	return 0.35


static func _gq14_cross_track_gain_per_m(morphology_interaction_score: float) -> float:
	return _gq13_cross_track_gain_per_m(morphology_interaction_score)


static func _gq14_yaw_gain_per_rad(
	morphology_interaction_score: float,
	torso_length_scale: float,
	foot_radius_scale: float,
	hip_span_scale: float,
) -> float:
	return _gq13_yaw_gain_per_rad(
		morphology_interaction_score,
		torso_length_scale,
		foot_radius_scale,
		hip_span_scale,
	)


static func _gq14_velocity_gain_rad_per_m_s(
	morphology_interaction_score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	foot_radius_scale: float,
	yaw_gain_per_rad: float,
) -> float:
	if yaw_gain_per_rad > 1.0:
		var long_wide_gain_fraction := (
			clampf((torso_length_scale - 1.0) / 0.07, 0.0, 1.0)
			* clampf((torso_width_scale - 1.0) / 0.06, 0.0, 1.0)
		)
		var long_large_foot_gain_fraction := (
			clampf((torso_length_scale - 1.0) / 0.05, 0.0, 1.0)
			* clampf((foot_radius_scale - 1.01) / 0.02, 0.0, 1.0)
		)
		return 0.25 + 0.05 * maxf(
			long_wide_gain_fraction,
			long_large_foot_gain_fraction,
		)
	if morphology_interaction_score < 0.15:
		if torso_width_scale <= 1.0:
			var long_small_foot_gain_fraction := (
				clampf((torso_length_scale - 1.0) / 0.01, 0.0, 1.0)
				* clampf((1.01 - foot_radius_scale) / 0.01, 0.0, 1.0)
			)
			return 0.275 + 0.075 * long_small_foot_gain_fraction
		return 0.40
	if morphology_interaction_score < 0.5:
		return 0.75 if torso_width_scale <= 1.0 else 0.25
	if torso_width_scale > 1.0 and torso_length_scale < 1.0:
		return 0.25 - 0.05 * clampf(
			(morphology_interaction_score - 0.5) / 0.5,
			0.0,
			1.0,
		)
	if torso_width_scale <= 1.0 and torso_length_scale < 0.95:
		return 0.35 + 0.10 * clampf(
			(1.0 - morphology_interaction_score) / 0.40,
			0.0,
			1.0,
		)
	return 0.35


static func _gq15_velocity_gain_rad_per_m_s(
	morphology_interaction_score: float,
	torso_length_scale: float,
	torso_width_scale: float,
	foot_radius_scale: float,
	yaw_gain_per_rad: float,
) -> float:
	if (
		yaw_gain_per_rad <= 1.0
		and morphology_interaction_score >= 0.5
		and torso_length_scale < 1.0
		and torso_width_scale > 1.0
	):
		var interaction_fraction := clampf(
			(morphology_interaction_score - 0.5) / 0.5,
			0.0,
			1.0,
		)
		var wide_fraction := clampf((torso_width_scale - 1.02) / 0.04, 0.0, 1.0)
		return (
			0.25
			+ 0.025 * interaction_fraction
			+ 0.025 * interaction_fraction * wide_fraction
		)
	return _gq14_velocity_gain_rad_per_m_s(
		morphology_interaction_score,
		torso_length_scale,
		torso_width_scale,
		foot_radius_scale,
		yaw_gain_per_rad,
	)


static func _actuator_impulse_options(campaign_id: String) -> Dictionary:
	if (
		campaign_id == CAMPAIGN_GP3
		or campaign_id == CAMPAIGN_GP4
		or campaign_id == CAMPAIGN_GP5
		or campaign_id == CAMPAIGN_GQ1
		or campaign_id == CAMPAIGN_GQ2
		or campaign_id == CAMPAIGN_GQ3
		or campaign_id == CAMPAIGN_GQ4
		or campaign_id == CAMPAIGN_GQ5
		or campaign_id == CAMPAIGN_GQ6
		or campaign_id == CAMPAIGN_GQ7
		or campaign_id == CAMPAIGN_GQ8
		or campaign_id == CAMPAIGN_GQ9
		or campaign_id == CAMPAIGN_GQ10
		or campaign_id == CAMPAIGN_GQ11
		or campaign_id == CAMPAIGN_GQ12
		or campaign_id == CAMPAIGN_GQ13
		or campaign_id == CAMPAIGN_GQ14
		or campaign_id == CAMPAIGN_GQ15
	):
		return GP3_ACTUATOR_IMPULSE_OPTIONS.duplicate(true)
	return {}


static func _motor_velocity_options(campaign_id: String, declared: Dictionary) -> Dictionary:
	if (
		campaign_id != CAMPAIGN_GP5
		and campaign_id != CAMPAIGN_GQ1
		and campaign_id != CAMPAIGN_GQ2
		and campaign_id != CAMPAIGN_GQ3
		and campaign_id != CAMPAIGN_GQ4
		and campaign_id != CAMPAIGN_GQ5
		and campaign_id != CAMPAIGN_GQ6
		and campaign_id != CAMPAIGN_GQ7
		and campaign_id != CAMPAIGN_GQ8
		and campaign_id != CAMPAIGN_GQ9
		and campaign_id != CAMPAIGN_GQ10
		and campaign_id != CAMPAIGN_GQ11
		and campaign_id != CAMPAIGN_GQ12
		and campaign_id != CAMPAIGN_GQ13
		and campaign_id != CAMPAIGN_GQ14
		and campaign_id != CAMPAIGN_GQ15
	):
		return {}
	var options := GP5_MOTOR_VELOCITY_OPTIONS.duplicate(true)
	var score := _morphology_interaction_score(declared)
	options["morphology_interaction_score"] = score
	if (
		campaign_id == CAMPAIGN_GQ6
		or campaign_id == CAMPAIGN_GQ7
		or campaign_id == CAMPAIGN_GQ8
		or campaign_id == CAMPAIGN_GQ9
		or campaign_id == CAMPAIGN_GQ10
		or campaign_id == CAMPAIGN_GQ11
		or campaign_id == CAMPAIGN_GQ12
		or campaign_id == CAMPAIGN_GQ13
		or campaign_id == CAMPAIGN_GQ14
		or campaign_id == CAMPAIGN_GQ15
	):
		var guard := (
			_gq15_motor_guard_values(score, declared)
			if campaign_id == CAMPAIGN_GQ15
			else (
				_gq14_motor_guard_values(score, declared)
				if campaign_id == CAMPAIGN_GQ14
				else (
					_gq13_motor_guard_values(score)
					if campaign_id == CAMPAIGN_GQ13
					else (
						_gq12_motor_guard_values(score)
						if campaign_id == CAMPAIGN_GQ12
						else (
							_gq11_motor_guard_values(score)
							if campaign_id == CAMPAIGN_GQ11
							else (
								_gq10_motor_guard_values(score)
								if campaign_id == CAMPAIGN_GQ10
								else (
									_gq9_motor_guard_values(score)
									if campaign_id == CAMPAIGN_GQ9
									else (
										_gq8_motor_guard_values(score)
										if campaign_id == CAMPAIGN_GQ8
										else (
											_gq7_motor_guard_values(score)
											if campaign_id == CAMPAIGN_GQ7
											else _gq6_motor_guard_values(score)
										)
									)
								)
							)
						)
					)
				)
			)
		)
		options["anchor_error_guard_activation_fraction"] = float(guard[0])
		options["anchor_error_guard_maximum_motor_target_speed_rad_s"] = float(guard[1])
	return options


static func _gq6_motor_guard_values(morphology_interaction_score: float) -> Array:
	return [0.80, 2.0] if morphology_interaction_score >= 0.5 else [0.90, 2.5]


static func _gq7_motor_guard_values(morphology_interaction_score: float) -> Array:
	return [0.80, 2.0] if morphology_interaction_score >= 0.5 else [0.90, 2.5]


static func _gq8_motor_guard_values(morphology_interaction_score: float) -> Array:
	return [0.80, 2.0] if morphology_interaction_score >= 0.5 else [0.90, 2.5]


static func _gq9_motor_guard_values(morphology_interaction_score: float) -> Array:
	return [0.80, 2.0] if morphology_interaction_score >= 0.5 else [0.90, 2.5]


static func _gq10_motor_guard_values(morphology_interaction_score: float) -> Array:
	return [0.80, 2.0] if morphology_interaction_score >= 0.5 else [0.90, 2.5]


static func _gq11_motor_guard_values(morphology_interaction_score: float) -> Array:
	return [0.80, 2.0] if morphology_interaction_score >= 0.5 else [0.90, 2.5]


static func _gq12_motor_guard_values(morphology_interaction_score: float) -> Array:
	return [0.80, 2.0] if morphology_interaction_score >= 0.5 else [0.90, 2.5]


static func _gq13_motor_guard_values(morphology_interaction_score: float) -> Array:
	return [0.80, 2.0] if morphology_interaction_score >= 0.5 else [0.90, 2.5]


static func _gq14_motor_guard_values(
	morphology_interaction_score: float,
	declared: Dictionary,
) -> Array:
	if (
		morphology_interaction_score >= 0.5
		and float(declared["torso_length_scale"]) > 1.04
		and float(declared["torso_width_scale"]) < 0.95
	):
		return [0.70, 1.75]
	return [0.80, 2.0] if morphology_interaction_score >= 0.5 else [0.90, 2.5]


static func _gq15_motor_guard_values(
	morphology_interaction_score: float,
	declared: Dictionary,
) -> Array:
	var torso_length_scale := float(declared["torso_length_scale"])
	var torso_width_scale := float(declared["torso_width_scale"])
	if (
		morphology_interaction_score >= 0.5
		and torso_length_scale > 1.04
		and (torso_width_scale < 0.95 or torso_width_scale > 1.0)
	):
		return [0.70, 1.75]
	return [0.80, 2.0] if morphology_interaction_score >= 0.5 else [0.90, 2.5]


static func _morphology_interaction_score(declared: Dictionary) -> float:
	var normalized_absolute_deviations := [
		absf((float(declared["torso_length_scale"]) - 1.0) / 0.10),
		absf((float(declared["torso_width_scale"]) - 1.0) / 0.10),
		absf((float(declared["upper_length_fraction"]) - (18.0 / 35.0)) / 0.05),
		absf((float(declared["hip_span_scale"]) - 1.0) / 0.10),
		absf((float(declared["foot_radius_scale"]) - 1.0) / 0.10),
		absf((float(declared["front_limb_mass_scale"]) - 1.0) / 0.10),
	]
	var pairwise_product_sum := 0.0
	for first_index in range(normalized_absolute_deviations.size()):
		for second_index in range(first_index + 1, normalized_absolute_deviations.size()):
			pairwise_product_sum += (
				float(normalized_absolute_deviations[first_index])
				* float(normalized_absolute_deviations[second_index])
			)
	return clampf(pairwise_product_sum, 0.0, 1.0)


static func _solver_policy_options(campaign_id: String) -> Dictionary:
	if (
		campaign_id == CAMPAIGN_GP4
		or campaign_id == CAMPAIGN_GQ6
		or campaign_id == CAMPAIGN_GQ7
		or campaign_id == CAMPAIGN_GQ8
		or campaign_id == CAMPAIGN_GQ9
		or campaign_id == CAMPAIGN_GQ10
		or campaign_id == CAMPAIGN_GQ11
		or campaign_id == CAMPAIGN_GQ12
		or campaign_id == CAMPAIGN_GQ13
		or campaign_id == CAMPAIGN_GQ14
		or campaign_id == CAMPAIGN_GQ15
	):
		return GP4_SOLVER_POLICY_OPTIONS.duplicate(true)
	return {}


static func _expected_controller_sha256(
	campaign_id: String,
	requested_motor_velocity_options: Dictionary = {},
	requested_path_steering_options: Dictionary = {},
) -> String:
	if (
		campaign_id == CAMPAIGN_GP5
		or campaign_id == CAMPAIGN_GQ1
		or campaign_id == CAMPAIGN_GQ2
		or campaign_id == CAMPAIGN_GQ3
		or campaign_id == CAMPAIGN_GQ4
		or campaign_id == CAMPAIGN_GQ5
		or campaign_id == CAMPAIGN_GQ6
		or campaign_id == CAMPAIGN_GQ7
		or campaign_id == CAMPAIGN_GQ8
		or campaign_id == CAMPAIGN_GQ9
		or campaign_id == CAMPAIGN_GQ10
		or campaign_id == CAMPAIGN_GQ11
		or campaign_id == CAMPAIGN_GQ12
		or campaign_id == CAMPAIGN_GQ13
		or campaign_id == CAMPAIGN_GQ14
		or campaign_id == CAMPAIGN_GQ15
	):
		var motor_options := (
			requested_motor_velocity_options
			if not requested_motor_velocity_options.is_empty()
			else GP5_MOTOR_VELOCITY_OPTIONS
		)
		var motor_result := WaveGaitScript._normalize_motor_velocity_options(motor_options, 360)
		var clock_result := (
			ClockSpecScript.compile(ClockSpecScript.gq15_clock())
			if campaign_id == CAMPAIGN_GQ15
			else (
				ClockSpecScript.compile(ClockSpecScript.gq14_clock())
				if campaign_id == CAMPAIGN_GQ14
				else (
					ClockSpecScript.compile(ClockSpecScript.gq13_clock())
					if campaign_id == CAMPAIGN_GQ13
					else (
						ClockSpecScript.compile(ClockSpecScript.gq12_clock())
						if campaign_id == CAMPAIGN_GQ12
						else (
							ClockSpecScript.compile(ClockSpecScript.gq11_clock())
							if campaign_id == CAMPAIGN_GQ11
							else (
								ClockSpecScript.compile(ClockSpecScript.gq10_clock())
								if campaign_id == CAMPAIGN_GQ10
								else (
									ClockSpecScript.compile(ClockSpecScript.gq9_clock())
									if campaign_id == CAMPAIGN_GQ9
									else (
										ClockSpecScript.compile(ClockSpecScript.gq8_clock())
										if campaign_id == CAMPAIGN_GQ8
										else (
											ClockSpecScript.compile(ClockSpecScript.gq7_clock())
											if campaign_id == CAMPAIGN_GQ7
											else (
												ClockSpecScript.compile(ClockSpecScript.gq6_clock())
												if campaign_id == CAMPAIGN_GQ6
												else ClockSpecScript.dynamic_similarity_clock(1.0)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
		if not bool(motor_result.get("ok", false)) or not bool(clock_result.get("ok", false)):
			return ""
		var clock: Dictionary = clock_result["gait_clock_options"]
		var path_options := (
			requested_path_steering_options
			if not requested_path_steering_options.is_empty()
			else _path_steering_options(campaign_id)
		)
		var controller := (
			WaveGaitScript
			. _controller_configuration(
				-1.0,
				10.0,
				1.75,
				"lateral",
				WaveGaitScript._resolve_gait_phase_order("lateral"),
				int(clock["swing_ticks"]),
				0.40,
				"all",
				int(clock["evidence_boundary_alignment_ticks"]),
				_robustness_options(campaign_id),
				path_options,
				GP3_ACTUATOR_IMPULSE_OPTIONS,
				motor_result["motor_velocity_options"],
				clock,
			)
		)
		return CanonicalJsonScript.sha256(controller)
	return (
		GP3_CONTROLLER_SHA256
		if campaign_id == CAMPAIGN_GP3 or campaign_id == CAMPAIGN_GP4
		else REFERENCE_CONTROLLER_SHA256
	)


static func _evidence_thresholds(
	fixture: Dictionary,
	campaign_id: String = CAMPAIGN_GP1,
) -> Dictionary:
	var torso: Dictionary = fixture["torso"]
	var torso_size: Array = torso["size_m"]
	var initial_center: Array = torso["initial_center_m"]
	var first_limb: Dictionary = (fixture["limbs"] as Array)[0]
	return {
		"evidence_threshold_policy_id": "nonuniform_dimensionless_thresholds_v1",
		"minimum_foot_relocation_m":
		(
			(
				0.0238
				if (
					campaign_id == CAMPAIGN_GQ6
					or campaign_id == CAMPAIGN_GQ7
					or campaign_id == CAMPAIGN_GQ8
					or campaign_id == CAMPAIGN_GQ9
					or campaign_id == CAMPAIGN_GQ10
					or campaign_id == CAMPAIGN_GQ11
					or campaign_id == CAMPAIGN_GQ12
					or campaign_id == CAMPAIGN_GQ13
					or campaign_id == CAMPAIGN_GQ14
					or campaign_id == CAMPAIGN_GQ15
				)
				else 0.024
			)
			* float(torso_size[0])
		),
		"minimum_evidence_torso_advance_m": 0.080 * float(torso_size[0]),
		"minimum_final_torso_advance_m": 0.060 * float(torso_size[0]),
		"maximum_lateral_drift_m": 0.3125 * float(torso_size[2]),
		"maximum_yaw_drift_rad": 0.45,
		"maximum_tilt_rad": 0.60,
		"minimum_torso_height_m": (25.0 / 44.0) * float(initial_center[1]),
		"maximum_anchor_error_m":
		(
			(
				0.14
				if (
					campaign_id == CAMPAIGN_GQ6
					or campaign_id == CAMPAIGN_GQ7
					or campaign_id == CAMPAIGN_GQ8
					or campaign_id == CAMPAIGN_GQ9
					or campaign_id == CAMPAIGN_GQ10
					or campaign_id == CAMPAIGN_GQ11
					or campaign_id == CAMPAIGN_GQ12
					or campaign_id == CAMPAIGN_GQ13
					or campaign_id == CAMPAIGN_GQ14
					or campaign_id == CAMPAIGN_GQ15
				)
				else (5.0 / 36.0)
			)
			* float(first_limb["upper_length_m"])
		),
		"maximum_hinge_axis_error_rad": 0.20,
	}


static func _requested_perturbation(role: String, repetition: int) -> Dictionary:
	if role == "selection" or repetition == 1:
		return {}
	if repetition == 2:
		return {
			"campaign_seed": 15302,
			"fixture_vertical_clearance_m": 0.0007,
			"fixture_yaw_rad": 0.003,
			"initial_linear_velocity_world_m_s": Vector3(0.002, 0.0, 0.001),
			"initial_torso_angular_velocity_world_rad_s": Vector3(0.002, 0.0, 0.001),
			"gait_phase_offset_ticks": 1,
		}
	return {
		"campaign_seed": 15303,
		"fixture_vertical_clearance_m": 0.0014,
		"fixture_yaw_rad": -0.006,
		"initial_linear_velocity_world_m_s": Vector3(0.004, 0.0, -0.002),
		"initial_torso_angular_velocity_world_rad_s": Vector3(0.003, -0.002, 0.002),
		"gait_phase_offset_ticks": -2,
	}


static func _requested_perturbation_exact(
	requested: Dictionary,
	role: String,
	repetition: int,
) -> bool:
	return requested == _requested_perturbation(role, repetition)


static func _fixture_formula_exact(parameters: Dictionary, fixture: Dictionary) -> bool:
	var torso: Dictionary = fixture["torso"]
	var torso_size: Array = torso["size_m"]
	var center: Array = torso["initial_center_m"]
	if (
		not is_equal_approx(float(torso["mass_kg"]), 3.0)
		or not is_equal_approx(float(torso_size[0]), 0.50 * float(parameters["torso_length_scale"]))
		or not is_equal_approx(float(torso_size[1]), 0.12)
		or not is_equal_approx(float(torso_size[2]), 0.32 * float(parameters["torso_width_scale"]))
		or not is_equal_approx(
			float(center[1]), 0.40 + 0.04 * float(parameters["foot_radius_scale"])
		)
	):
		return false
	var upper_total := 0.0
	var distal_total := 0.0
	for limb_value in fixture["limbs"]:
		var limb: Dictionary = limb_value
		var limb_id := String(limb["limb_id"])
		var offset: Array = limb["hip_offset_from_torso_center_m"]
		var x_sign := 1.0 if limb_id.begins_with("front_") else -1.0
		var z_sign := -1.0 if limb_id.ends_with("_left") else 1.0
		var mass_scale := (
			float(parameters["front_limb_mass_scale"])
			if limb_id.begins_with("front_")
			else 2.0 - float(parameters["front_limb_mass_scale"])
		)
		if (
			not is_equal_approx(
				float(offset[0]), x_sign * 0.20 * float(parameters["hip_span_scale"])
			)
			or not is_equal_approx(
				float(offset[2]), z_sign * 0.18 * float(parameters["hip_span_scale"])
			)
			or not is_equal_approx(
				float(limb["upper_length_m"]),
				0.35 * float(parameters["upper_length_fraction"]),
			)
			or not is_equal_approx(
				float(limb["lower_length_m"]),
				0.35 * (1.0 - float(parameters["upper_length_fraction"])),
			)
			or not is_equal_approx(
				float(limb["foot_radius_m"]), 0.04 * float(parameters["foot_radius_scale"])
			)
			or not is_equal_approx(float(limb["upper_mass_kg"]), 0.25 * mass_scale)
			or not is_equal_approx(float(limb["distal_mass_kg"]), 0.18 * mass_scale)
		):
			return false
		upper_total += float(limb["upper_mass_kg"])
		distal_total += float(limb["distal_mass_kg"])
	return (
		is_equal_approx(upper_total, 1.0)
		and is_equal_approx(distal_total, 0.72)
		and (
			(fixture["contact_material"] as Dictionary)
			== (FixtureSpecScript.reference_spec()["contact_material"] as Dictionary)
		)
		and (
			(fixture["body_dynamics"] as Dictionary)
			== (FixtureSpecScript.reference_spec()["body_dynamics"] as Dictionary)
		)
		and (
			(fixture["joint_limits"] as Dictionary)
			== (FixtureSpecScript.reference_spec()["joint_limits"] as Dictionary)
		)
		and (
			(fixture["motor_impulses"] as Dictionary)
			== (FixtureSpecScript.reference_spec()["motor_impulses"] as Dictionary)
		)
	)


static func _static_screen_exact(compiled: Dictionary) -> bool:
	var static_screen: Dictionary = compiled.get("static_screen", {})
	return (
		bool(static_screen.get("passed", false))
		and int(static_screen.get("world_build_count", -1)) == 0
		and _all_true(static_screen.get("predicates", {}))
		and float(static_screen.get("foot_floor_error_m", INF)) <= 1.0e-9
		and float(static_screen.get("minimum_nonadjacent_clearance_m", -INF)) >= 0.0
		and float(static_screen.get("maximum_connected_attachment_overlap_m", INF)) <= 0.012
		and float(static_screen.get("minimum_support_polygon_margin_m", -INF)) > 0.002
		and String(compiled.get("static_screen_sha256", "")).length() == 71
	)


static func _unit_clock_exact(
	clock: Dictionary,
	campaign_id: String = CAMPAIGN_GP1,
) -> bool:
	var uses_four_cycle_clock := (
		campaign_id == CAMPAIGN_GQ6
		or campaign_id == CAMPAIGN_GQ7
		or campaign_id == CAMPAIGN_GQ8
		or campaign_id == CAMPAIGN_GQ9
		or campaign_id == CAMPAIGN_GQ10
		or campaign_id == CAMPAIGN_GQ11
		or campaign_id == CAMPAIGN_GQ12
		or campaign_id == CAMPAIGN_GQ13
		or campaign_id == CAMPAIGN_GQ14
		or campaign_id == CAMPAIGN_GQ15
	)
	return (
		(
			String(clock.get("policy_id", ""))
			== (
				ClockSpecScript.GQ15_POLICY_ID
				if campaign_id == CAMPAIGN_GQ15
				else (
					ClockSpecScript.GQ14_POLICY_ID
					if campaign_id == CAMPAIGN_GQ14
					else (
						ClockSpecScript.GQ13_POLICY_ID
						if campaign_id == CAMPAIGN_GQ13
						else (
							ClockSpecScript.GQ12_POLICY_ID
							if campaign_id == CAMPAIGN_GQ12
							else (
								ClockSpecScript.GQ11_POLICY_ID
								if campaign_id == CAMPAIGN_GQ11
								else (
									ClockSpecScript.GQ10_POLICY_ID
									if campaign_id == CAMPAIGN_GQ10
									else (
										ClockSpecScript.GQ9_POLICY_ID
										if campaign_id == CAMPAIGN_GQ9
										else (
											ClockSpecScript.GQ8_POLICY_ID
											if campaign_id == CAMPAIGN_GQ8
											else (
												ClockSpecScript.GQ7_POLICY_ID
												if campaign_id == CAMPAIGN_GQ7
												else (
													ClockSpecScript.GQ6_POLICY_ID
													if campaign_id == CAMPAIGN_GQ6
													else ClockSpecScript.DYNAMIC_SIMILARITY_POLICY_ID
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
		and float(clock.get("uniform_scale", NAN)) == 1.0
		and int(clock.get("cycle_ticks", -1)) == 360
		and int(clock.get("swing_ticks", -1)) == 72
		and int(clock.get("settle_ticks", -1)) == 240
		and int(clock.get("terminal_settle_ticks", -1)) == 240
		and int(clock.get("evidence_cycles", -1)) == (4 if uses_four_cycle_clock else 3)
		and int(clock.get("evidence_boundary_alignment_ticks", -1)) == 112
		and int(clock.get("maximum_contact_gated_evidence_extension_ticks", -1)) == 720
		and (
			int(clock.get("maximum_contact_gate_hold_ticks", -1))
			== (120 if uses_four_cycle_clock else 96)
		)
		and int(clock.get("maximum_contact_gated_phase_skew_ticks", -1)) == 12
		and int(clock.get("steering_update_interval_ticks", -1)) == 90
		and int(clock.get("minimum_airborne_dwell_ticks", -1)) == 3
		and float(clock.get("motor_position_gain_per_s", NAN)) == 8.0
		and float(clock.get("maximum_motor_target_speed_rad_s", NAN)) == 3.5
		and float(clock.get("motor_rate_damping", NAN)) == 0.65
	)


static func _controller_receipt_exact(
	summary: Dictionary,
	clock: Dictionary,
	campaign_id: String,
	requested_motor_velocity_options: Dictionary,
	requested_path_steering_options: Dictionary,
) -> bool:
	var controller: Dictionary = summary.get("controller_configuration", {})
	var expected_path := requested_path_steering_options
	var expected_actuator := _actuator_impulse_options(campaign_id)
	var actuator_exact := not controller.has("actuator_impulse_options")
	if (
		campaign_id == CAMPAIGN_GP3
		or campaign_id == CAMPAIGN_GP4
		or campaign_id == CAMPAIGN_GP5
		or campaign_id == CAMPAIGN_GQ1
		or campaign_id == CAMPAIGN_GQ2
		or campaign_id == CAMPAIGN_GQ3
		or campaign_id == CAMPAIGN_GQ4
		or campaign_id == CAMPAIGN_GQ5
		or campaign_id == CAMPAIGN_GQ6
		or campaign_id == CAMPAIGN_GQ7
		or campaign_id == CAMPAIGN_GQ8
		or campaign_id == CAMPAIGN_GQ9
		or campaign_id == CAMPAIGN_GQ10
		or campaign_id == CAMPAIGN_GQ11
		or campaign_id == CAMPAIGN_GQ12
		or campaign_id == CAMPAIGN_GQ13
		or campaign_id == CAMPAIGN_GQ14
		or campaign_id == CAMPAIGN_GQ15
	):
		actuator_exact = (
			(controller.get("actuator_impulse_options", {}) as Dictionary) == expected_actuator
			and (summary.get("actuator_impulse_options", {}) as Dictionary) == expected_actuator
		)
	var motor_exact := (
		not controller.has("motor_velocity_options") and not summary.has("motor_velocity_options")
	)
	if (
		campaign_id == CAMPAIGN_GP5
		or campaign_id == CAMPAIGN_GQ1
		or campaign_id == CAMPAIGN_GQ2
		or campaign_id == CAMPAIGN_GQ3
		or campaign_id == CAMPAIGN_GQ4
		or campaign_id == CAMPAIGN_GQ5
		or campaign_id == CAMPAIGN_GQ6
		or campaign_id == CAMPAIGN_GQ7
		or campaign_id == CAMPAIGN_GQ8
		or campaign_id == CAMPAIGN_GQ9
		or campaign_id == CAMPAIGN_GQ10
		or campaign_id == CAMPAIGN_GQ11
		or campaign_id == CAMPAIGN_GQ12
		or campaign_id == CAMPAIGN_GQ13
		or campaign_id == CAMPAIGN_GQ14
		or campaign_id == CAMPAIGN_GQ15
	):
		var motor_result := (
			WaveGaitScript
			. _normalize_motor_velocity_options(
				requested_motor_velocity_options,
				int(clock["cycle_ticks"]),
			)
		)
		if not bool(motor_result.get("ok", false)):
			return false
		var expected_motor: Dictionary = motor_result["motor_velocity_options"]
		motor_exact = (
			(controller.get("motor_velocity_options", {}) as Dictionary) == expected_motor
			and (summary.get("motor_velocity_options", {}) as Dictionary) == expected_motor
		)
	return (
		(
			String(controller.get("schema_version", ""))
			== "sporespore_physical_wave_gait_controller_configuration_v1"
		)
		and float(controller.get("motor_direction_sign", NAN)) == -1.0
		and float(controller.get("knee_motor_impulse_scale", NAN)) == 10.0
		and float(controller.get("knee_flexion_scale", NAN)) == 1.75
		and String(controller.get("gait_phase_order_id", "")) == "lateral"
		and float(controller.get("contact_clearance_assist_rad", NAN)) == 0.40
		and (
			(controller.get("robustness_options", {}) as Dictionary)
			== _robustness_options(campaign_id)
		)
		and (controller.get("path_steering_options", {}) as Dictionary) == expected_path
		and (controller.get("gait_clock_options", {}) as Dictionary) == clock
		and actuator_exact
		and motor_exact
	)


static func _perturbation_receipt_exact(
	receipt_value: Variant,
	role: String,
	repetition: int,
) -> bool:
	if typeof(receipt_value) != TYPE_DICTIONARY:
		return false
	var receipt: Dictionary = receipt_value
	var expected := _requested_perturbation(role, repetition)
	if expected.is_empty():
		return (
			int(receipt.get("campaign_seed", -1)) == 0
			and float(receipt.get("fixture_vertical_clearance_m", NAN)) == 0.0
			and float(receipt.get("fixture_yaw_rad", NAN)) == 0.0
			and (
				(receipt.get("initial_linear_velocity_world_m_s", Vector3.INF) as Vector3)
				. is_zero_approx()
			)
			and (
				(receipt.get("initial_torso_angular_velocity_world_rad_s", Vector3.INF) as Vector3)
				. is_zero_approx()
			)
			and int(receipt.get("gait_phase_offset_ticks", -99)) == 0
		)
	return (
		int(receipt.get("campaign_seed", -1)) == int(expected["campaign_seed"])
		and is_equal_approx(
			float(receipt.get("fixture_vertical_clearance_m", NAN)),
			float(expected["fixture_vertical_clearance_m"]),
		)
		and is_equal_approx(
			float(receipt.get("fixture_yaw_rad", NAN)),
			float(expected["fixture_yaw_rad"]),
		)
		and (
			(receipt.get("initial_linear_velocity_world_m_s", Vector3.INF) as Vector3)
			. is_equal_approx(expected["initial_linear_velocity_world_m_s"])
		)
		and (
			(receipt.get("initial_torso_angular_velocity_world_rad_s", Vector3.INF) as Vector3)
			. is_equal_approx(expected["initial_torso_angular_velocity_world_rad_s"])
		)
		and (
			int(receipt.get("gait_phase_offset_ticks", -99))
			== int(expected["gait_phase_offset_ticks"])
		)
	)


static func _realized_impulses_exact(summary: Dictionary, campaign_id: String) -> bool:
	var uses_gp3_controller := (
		campaign_id == CAMPAIGN_GP3
		or campaign_id == CAMPAIGN_GP4
		or campaign_id == CAMPAIGN_GP5
		or campaign_id == CAMPAIGN_GQ1
		or campaign_id == CAMPAIGN_GQ2
		or campaign_id == CAMPAIGN_GQ3
		or campaign_id == CAMPAIGN_GQ4
		or campaign_id == CAMPAIGN_GQ5
		or campaign_id == CAMPAIGN_GQ6
		or campaign_id == CAMPAIGN_GQ7
		or campaign_id == CAMPAIGN_GQ8
		or campaign_id == CAMPAIGN_GQ9
		or campaign_id == CAMPAIGN_GQ10
		or campaign_id == CAMPAIGN_GQ11
		or campaign_id == CAMPAIGN_GQ12
		or campaign_id == CAMPAIGN_GQ13
		or campaign_id == CAMPAIGN_GQ14
		or campaign_id == CAMPAIGN_GQ15
	)
	var expected_hip_impulse := 0.055825 if uses_gp3_controller else 0.055
	var expected_knee_impulse := 0.456750 if uses_gp3_controller else 0.45
	return (
		is_equal_approx(
			float(summary.get("realized_hip_max_impulse_nms", NAN)),
			expected_hip_impulse,
		)
		and is_equal_approx(
			float(summary.get("realized_knee_max_impulse_nms", NAN)),
			expected_knee_impulse,
		)
	)


static func _contact_progression_exact(
	summary: Dictionary,
	campaign_id: String = CAMPAIGN_GP1,
) -> bool:
	var cycles: Dictionary = summary.get("contact_cycle_count_by_limb", {})
	var timeouts: Dictionary = summary.get("contact_gate_timeout_count_by_limb", {})
	var advance: Dictionary = summary.get("evidence_gait_advance_ticks_by_limb", {})
	var expected_advance := (
		1440
		if (
			campaign_id == CAMPAIGN_GQ6
			or campaign_id == CAMPAIGN_GQ7
			or campaign_id == CAMPAIGN_GQ8
			or campaign_id == CAMPAIGN_GQ9
			or campaign_id == CAMPAIGN_GQ10
			or campaign_id == CAMPAIGN_GQ11
			or campaign_id == CAMPAIGN_GQ12
			or campaign_id == CAMPAIGN_GQ13
			or campaign_id == CAMPAIGN_GQ14
			or campaign_id == CAMPAIGN_GQ15
		)
		else 1080
	)
	for limb_id in ["front_left", "front_right", "rear_left", "rear_right"]:
		if (
			int(cycles.get(limb_id, 0)) < 2
			or int(timeouts.get(limb_id, -1)) != 0
			or int(advance.get(limb_id, -1)) != expected_advance
		):
			return false
	return true


static func _normalized_metric_bounds_exact(summary: Dictionary, thresholds: Dictionary) -> bool:
	var evidence: Vector3 = summary.get("evidence_torso_displacement_world_m", Vector3.INF)
	var final: Vector3 = summary.get("final_torso_displacement_world_m", Vector3.INF)
	var relocation: Dictionary = summary.get("minimum_cycle_relocation_by_limb_m", {})
	for limb_id in ["front_left", "front_right", "rear_left", "rear_right"]:
		if (
			not is_finite(float(relocation.get(limb_id, NAN)))
			or float(relocation.get(limb_id, NAN)) < float(thresholds["minimum_foot_relocation_m"])
		):
			return false
	return (
		evidence.x >= float(thresholds["minimum_evidence_torso_advance_m"])
		and final.x >= float(thresholds["minimum_final_torso_advance_m"])
		and absf(final.z) <= float(thresholds["maximum_lateral_drift_m"])
		and (
			absf(float(summary.get("final_yaw_drift_rad", INF)))
			<= float(thresholds["maximum_yaw_drift_rad"])
		)
		and float(summary.get("maximum_tilt_rad", INF)) <= float(thresholds["maximum_tilt_rad"])
		and (
			float(summary.get("minimum_torso_height_m", -INF))
			>= float(thresholds["minimum_torso_height_m"])
		)
		and (
			float(summary.get("maximum_anchor_error_m", INF))
			<= float(thresholds["maximum_anchor_error_m"])
		)
		and (
			float(summary.get("maximum_hinge_axis_error_rad", INF))
			<= float(thresholds["maximum_hinge_axis_error_rad"])
		)
	)


static func _summary_receipts_finite(summary: Dictionary) -> bool:
	var evidence: Vector3 = summary.get("evidence_torso_displacement_world_m", Vector3.INF)
	var final: Vector3 = summary.get("final_torso_displacement_world_m", Vector3.INF)
	return (
		evidence.is_finite()
		and final.is_finite()
		and is_finite(float(summary.get("maximum_anchor_error_m", NAN)))
		and is_finite(float(summary.get("maximum_hinge_axis_error_rad", NAN)))
		and is_finite(float(summary.get("minimum_torso_height_m", NAN)))
	)


static func _outcome_is_complete(summary: Dictionary) -> bool:
	return (
		summary.has("physical_wave_gait_walking_observed")
		and typeof(summary.get("physical_wave_gait_walking_observed")) == TYPE_BOOL
		and typeof(summary.get("failure_code", "")) == TYPE_STRING
	)


static func _direct_body_write_count(summary: Dictionary) -> int:
	return (
		int(summary.get("direct_torso_force_command_count", -1))
		+ int(summary.get("direct_torso_impulse_command_count", -1))
		+ int(summary.get("direct_torso_velocity_command_count", -1))
		+ int(summary.get("direct_torso_transform_command_count", -1))
	)


static func _vector_dictionary(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _bw2_authority_integrity(
	summary: Dictionary,
	sdk_authority: Dictionary,
) -> bool:
	var expected_step_count := 1514
	var expected_command_count := expected_step_count * 8
	var overlay: Dictionary = sdk_authority.get("stability_overlay_summary", {})
	var contribution: Dictionary = sdk_authority.get(
		"stability_contribution_shadow_summary",
		{},
	)
	var mapping: Dictionary = sdk_authority.get("joint_mapping_shadow_summary", {})
	var manifest: Dictionary = sdk_authority.get("adapter_manifest", {})
	var physical_overlay: Dictionary = (
		(manifest.get("stability_v3", {}) as Dictionary).get("physical_overlay", {})
	)
	return (
		_outcome_is_complete(summary)
		and bool(summary.get("sdk_authority_enabled", false))
		and String(summary.get("sdk_authority_scope", ""))
		== "stability_contribution_overlay"
		and String(summary.get("sdk_authority_failure_code", "")).is_empty()
		and _direct_body_write_count(summary) == 0
		and bool(sdk_authority.get("ok", false))
		and String(sdk_authority.get("controller_policy_id", "")) == _sdk_bw2_policy_id
		and String(sdk_authority.get("controller_runtime_version", ""))
		== "sporespore_balanced_wave_runtime_v1"
		and bool(sdk_authority.get("balanced_wave_shadow_valid", false))
		and not bool(sdk_authority.get("candidate35_shadow_parity_ok", true))
		and int(sdk_authority.get("step_count", -1)) == expected_step_count
		and int(sdk_authority.get("validated_balanced_wave_command_count", -1))
		== expected_command_count
		and int(sdk_authority.get("balanced_wave_step_receipt_count", -1))
		== expected_step_count
		and int(sdk_authority.get("native_actuation_application_count", -1))
		== expected_command_count
		and int(sdk_authority.get("safe_no_actuation_count", -1)) == 0
		and int(sdk_authority.get("mismatch_count", -1)) == 0
		and (sdk_authority.get("failure_codes", []) as Array).is_empty()
		and int(summary.get("legacy_sdk_overlay_base_application_count", -1))
		== expected_command_count
		and bool(overlay.get("ok", false))
		and String(overlay.get("base_command_source", ""))
		== "portable_controller_ordered_commands"
		and int(overlay.get("portable_controller_base_application_count", -1))
		== expected_command_count
		and int(overlay.get("application_step_count", -1)) == expected_step_count
		and int(overlay.get("motor_write_count", -1)) == expected_command_count
		and int(overlay.get("nonzero_effective_application_count", 0)) > 0
		and int(overlay.get("failure_count", -1)) == 0
		and int(overlay.get("direct_body_write_count", -1)) == 0
		and bool(contribution.get("ok", false))
		and int(contribution.get("attempt_count", -1)) == expected_step_count
		and (
			int(contribution.get("available_count", -1))
			+ int(contribution.get("upstream_infeasible_count", -1))
			+ int(contribution.get("unavailable_count", -1))
			== expected_step_count
		)
		and int(contribution.get("fallback_zero_output_count", -1))
		== (
			int(contribution.get("upstream_infeasible_count", -2))
			+ int(contribution.get("unavailable_count", -2))
		) * 8
		and int(contribution.get("nonzero_active_command_count", 0)) > 0
		and int(contribution.get("mismatch_count", -1)) == 0
		and int(contribution.get("untyped_count", -1)) == 0
		and int(mapping.get("attempt_count", -1)) == expected_step_count
		and (
			int(mapping.get("available_count", -1))
			+ int(mapping.get("infeasible_count", -1))
			+ int(mapping.get("unavailable_count", -1))
			== expected_step_count
		)
		and int(mapping.get("mismatch_count", -1)) == 0
		and String(manifest.get("execution_mode", ""))
		== "portable_balanced_wave_base_with_stability_overlay"
		and String(physical_overlay.get("base_command", ""))
		== "portable_balanced_wave_ordered_command"
	)


static func _print_physical_diagnostics(summary: Dictionary) -> void:
	print(
		"NONUNIFORM_PROPORTION_PHYSICAL_DIAGNOSTIC",
		" walking_gates=",
		summary.get("walking_gate_receipts", {}),
		" relocation_by_limb_m=",
		summary.get("minimum_cycle_relocation_by_limb_m", {}),
		" contact_cycles=",
		summary.get("contact_cycle_count_by_limb", {}),
		" contact_timeouts=",
		summary.get("contact_gate_timeout_count_by_limb", {}),
		" evidence_advance_ticks=",
		summary.get("evidence_gait_advance_ticks_by_limb", {}),
		" final_yaw_rad=",
		float(summary.get("final_yaw_drift_rad", NAN)),
		" maximum_tilt_rad=",
		float(summary.get("maximum_tilt_rad", NAN)),
		" minimum_torso_height_m=",
		float(summary.get("minimum_torso_height_m", NAN)),
		" maximum_anchor_error_m=",
		float(summary.get("maximum_anchor_error_m", NAN)),
		" maximum_hinge_axis_error_rad=",
		float(summary.get("maximum_hinge_axis_error_rad", NAN)),
		" dynamic_support_failure_code=",
		String(summary.get("dynamic_support_diagnostic_failure_code", "")),
	)


static func _all_true(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	for receipt_value in (value as Dictionary).values():
		if typeof(receipt_value) != TYPE_BOOL or not bool(receipt_value):
			return false
	return not (value as Dictionary).is_empty()


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
