class_name LabPhysicalWaveGaitQuadrupedBw30nFixedHorizon
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=max-returns
# gdlint: disable=function-arguments-number

## Development-only continuously scheduled physical quadruped.
##
## The torso and eight leg bodies are ordinary RigidBody3D nodes. Eight
## HingeJoint3D motors provide the only locomotor authority. No force, impulse,
## velocity, position, transform, freeze, or teleport command is applied to the
## torso after fixture release.

const BW30N_FIXED_HORIZON_POLICY_ID := "fixed_post_sdk_observation_horizon_v1"
const BW30N_FIXED_HORIZON_POLICY_SHA256 := (
	"sha256:3b76314d6d0726746644f4c66ae67da01364a353d199562f3ed9843be349d912"
)
const BW30N_FIXED_HORIZON_OBSERVATION_COUNT := 1514

const SemanticContactRigidBodyScript := preload(
	"res://scripts/lab/mechanics/semantic_contact_rigid_body.gd"
)
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FixtureSpecScript := preload("res://scripts/lab/gait/physical_quadruped_fixture_spec.gd")
const GaitClockSpecScript := preload("res://scripts/lab/gait/physical_gait_clock_spec.gd")
const DynamicSupportObserverScript := preload(
	"res://scripts/lab/mechanics/spatial_dynamic_support_observer.gd"
)
const DynamicSupportReceiptScript := preload(
	"res://scripts/lab/mechanics/dynamic_support_diagnostic_receipt.gd"
)
const SdkGodotJoltAdapterScript := preload("res://scripts/lab/gait/sdk_godot_jolt_adapter.gd")
const SdkGodotJoltMaterialProfilesScript := preload(
	"res://scripts/lab/gait/sdk_godot_jolt_material_profiles.gd"
)

const PHYSICS_HZ := 120
const LIMB_ORDER := ["rear_left", "front_left", "rear_right", "front_right"]
const GAIT_PHASE_ORDERS := {
	"lateral": ["rear_left", "front_left", "rear_right", "front_right"],
	"diagonal": ["rear_left", "front_right", "rear_right", "front_left"],
	"alternating": ["rear_left", "front_right", "front_left", "rear_right"],
}
const MOTOR_POSITION_GAIN_PER_S := 8.0
const MOTOR_RATE_DAMPING := 0.65
const MAXIMUM_MOTOR_TARGET_SPEED_RAD_S := 3.5
const HIP_FORWARD_TARGET_RAD := 0.30
const HIP_REAR_TARGET_RAD := -0.30
const KNEE_SWING_FLEXION_RAD := 0.82
const SETTLE_TICKS := 240
const CYCLE_TICKS := 360
const SWING_TICKS := 72
const WARMUP_CYCLES := 1
const EVIDENCE_BOUNDARY_ALIGNMENT_TICKS := 112
const EVIDENCE_CYCLES := 3
const COOLDOWN_CYCLES := 1
const TERMINAL_SETTLE_TICKS := 240
const MINIMUM_AIRBORNE_DWELL_TICKS := 3
const MINIMUM_FOOT_RELOCATION_M := 0.012
const MINIMUM_EVIDENCE_TORSO_ADVANCE_M := 0.040
const MINIMUM_FINAL_TORSO_ADVANCE_M := 0.030
const MAXIMUM_LATERAL_DRIFT_M := 0.10
const MAXIMUM_YAW_DRIFT_RAD := 0.45
const MAXIMUM_TILT_RAD := 0.60
const MINIMUM_TORSO_HEIGHT_M := 0.25
const MAXIMUM_ANCHOR_ERROR_M := 0.025
const MAXIMUM_HINGE_AXIS_ERROR_RAD := 0.20
const MAXIMUM_INITIAL_VERTICAL_CLEARANCE_M := 0.002
const MAXIMUM_INITIAL_YAW_PERTURBATION_RAD := 0.010
const MAXIMUM_INITIAL_LINEAR_SPEED_M_S := 0.008
const MAXIMUM_INITIAL_TORSO_ANGULAR_SPEED_RAD_S := 0.008
const MAXIMUM_INITIAL_GAIT_PHASE_OFFSET_TICKS := 3
const INITIAL_PERTURBATION_KEYS := [
	"campaign_seed",
	"fixture_vertical_clearance_m",
	"fixture_yaw_rad",
	"initial_linear_velocity_world_m_s",
	"initial_torso_angular_velocity_world_rad_s",
	"gait_phase_offset_ticks",
]
const ROBUSTNESS_OPTION_KEYS := [
	"contact_gated_phase_progression",
	"maximum_contact_gate_hold_ticks",
	"maximum_contact_gated_phase_skew_ticks",
	"lateral_stride_steering_gain_per_m",
]
const PATH_STEERING_OPTION_KEYS := [
	"phase_bounded_path_steering_enabled",
	"cross_track_heading_gain_rad_per_m",
	"yaw_error_stride_gain_per_rad",
	"steering_update_interval_ticks",
	"maximum_desired_heading_error_rad",
	"maximum_steering_fraction",
]
const OPTIONAL_PATH_STEERING_OPTION_KEYS := [
	"cross_track_velocity_heading_gain_rad_per_m_s",
]
const ACTUATOR_IMPULSE_OPTION_KEYS := [
	"mass_adaptive_actuator_enabled",
	"actuator_policy_id",
	"actuator_impulse_scale",
	"hip_impulse_scale",
	"knee_impulse_scale",
]
const MOTOR_VELOCITY_OPTION_KEYS := [
	"mass_adaptive_motor_velocity_enabled",
	"motor_velocity_policy_id",
	"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s",
	"contact_loaded_swing_knee_activation_start_phase_tick",
	"contact_loaded_swing_knee_full_speed_override_phase_tick",
	"anchor_error_guard_enabled",
	"morphology_interaction_score",
	"anchor_error_guard_activation_fraction",
	"anchor_error_guard_maximum_motor_target_speed_rad_s",
]
const REQUIRED_MOTOR_VELOCITY_OPTION_KEYS := [
	"mass_adaptive_motor_velocity_enabled",
	"motor_velocity_policy_id",
	"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s",
]
const EVIDENCE_THRESHOLD_OPTION_KEYS := [
	"evidence_threshold_policy_id",
	"minimum_foot_relocation_m",
	"minimum_evidence_torso_advance_m",
	"minimum_final_torso_advance_m",
	"maximum_lateral_drift_m",
	"maximum_yaw_drift_rad",
	"maximum_tilt_rad",
	"minimum_torso_height_m",
	"maximum_anchor_error_m",
	"maximum_hinge_axis_error_rad",
]
const EVIDENCE_THRESHOLD_POLICY_IDS := [
	"reference_metric_thresholds_v1",
	"uniform_scale_dimensionless_thresholds_v1",
	"nonuniform_dimensionless_thresholds_v1",
]
const SOLVER_POLICY_OPTION_KEYS := [
	"solver_policy_id",
	"physics_engine",
	"physics_hz",
	"solver_velocity_steps",
	"solver_position_steps",
]
const DYNAMIC_SUPPORT_DIAGNOSTIC_OPTION_KEYS := [
	"enabled",
	"lateral_limit_m",
	"source_digests",
]
const DYNAMIC_SUPPORT_DIAGNOSTIC_VERSIONED_OPTION_KEYS := [
	"enabled",
	"lateral_limit_m",
	"source_digests",
	"receipt_schema_version",
	"policy_id",
	"sample_schema_version",
]
const SDK_SHADOW_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
]
const SDK_SHADOW_EXTENDED_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"stability_policy_id",
]
const SDK_SHADOW_MATERIAL_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"stability_policy_id",
	"material_profile_id",
]
const SDK_SHADOW_CONTROLLER_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"stability_policy_id",
	"controller_policy_id",
]
const SDK_SHADOW_CONTROLLER_MATERIAL_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"stability_policy_id",
	"material_profile_id",
	"controller_policy_id",
]
const SDK_AUTHORITY_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
]
const SDK_AUTHORITY_EXTENDED_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
	"stability_policy_id",
]
const SDK_AUTHORITY_MATERIAL_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
	"stability_policy_id",
	"material_profile_id",
]
const SDK_AUTHORITY_CONTROLLER_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
	"stability_policy_id",
	"controller_policy_id",
]
const SDK_AUTHORITY_CONTROLLER_MATERIAL_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
	"stability_policy_id",
	"material_profile_id",
	"controller_policy_id",
]
const SDK_AUTHORITY_CONTROLLER_MATERIAL_SCALE_OPTION_KEYS := [
	"enabled",
	"descriptor",
	"comparison_tolerance",
	"authority_scope",
	"stability_policy_id",
	"material_profile_id",
	"controller_policy_id",
	"stability_influence_global_scale",
]
const ENVIRONMENT_CHALLENGE_OPTION_KEYS := [
	"challenge_profile_id",
	"terrain_profile_id",
	"terrain_tile_length_m",
	"terrain_tile_count",
	"terrain_origin_x_m",
	"terrain_heights_m",
	"push_profile_id",
	"push_step_from_sdk_start",
	"push_impulse_task_n_s",
	"observation_fault_profile_id",
	"observation_noise_period_steps",
	"base_position_noise_amplitude_m",
	"base_linear_velocity_noise_amplitude_m_s",
	"joint_position_noise_amplitude_rad",
	"joint_velocity_noise_amplitude_rad_s",
	"stability_body_position_noise_amplitude_m",
	"stability_body_velocity_noise_amplitude_m_s",
	"support_point_noise_amplitude_m",
]
const EVIDENCE_ACQUISITION_OPTION_KEYS := [
	"policy_id",
	"enabled",
	"maximum_acquisition_ticks",
	"minimum_all_support_dwell_ticks",
]
const FLAT_TERRAIN_PROFILE_ID := "flat_v1"
const ROUGH_TERRAIN_PROFILE_ID := "rough_height_strip_v1"
const NO_PUSH_PROFILE_ID := "none"
const LATERAL_PUSH_PROFILE_ID := "lateral_impulse_v1"
const NO_OBSERVATION_FAULT_PROFILE_ID := "none"
const DETERMINISTIC_OBSERVATION_NOISE_PROFILE_ID := "deterministic_additive_v1"
const MAXIMUM_ROUGH_TERRAIN_ABSOLUTE_HEIGHT_M := 0.025
const MAXIMUM_EXTERNAL_PUSH_IMPULSE_N_S := 0.40
const MAXIMUM_OBSERVATION_POSITION_NOISE_M := 0.010
const MAXIMUM_OBSERVATION_LINEAR_VELOCITY_NOISE_M_S := 0.10
const MAXIMUM_OBSERVATION_JOINT_POSITION_NOISE_RAD := 0.020
const MAXIMUM_OBSERVATION_JOINT_VELOCITY_NOISE_RAD_S := 0.10
const SDK_P5I3B_STABILITY_POLICY_ID := "p5i3b_weight_support_shadow_v1"
const SDK_P5I3C_STABILITY_POLICY_ID := "p5i3c_support_centroid_tilt_feedback_v1"
const SDK_BW9L_A_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw9l_a_v1"
const SDK_BW9L_B_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw9l_b_v1"
const SDK_BW9L_C_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw9l_c_v1"
const SDK_BW9L_D_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw9l_d_v1"
const SDK_BW10F_A_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw10f_a_v2"
const SDK_BW10F_B_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw10f_b_v2"
const SDK_BW10F_C_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw10f_c_v2"
const SDK_BW10F_D_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw10f_d_v2"
const SDK_BW11R_A_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw11r_a_v3"
const SDK_BW11R_B_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw11r_b_v3"
const SDK_BW11R_C_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw11r_c_v3"
const SDK_BW11R_D_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw11r_d_v3"
const SDK_BW13P_A_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_a_v3"
const SDK_BW13P_B_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_b_v3"
const SDK_BW13P_C_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_c_v3"
const SDK_BW13P_D_STABILITY_POLICY_ID := "sporespore_scheduled_load_transfer_bw13p_d_v3"
const SDK_BW13P_STABILITY_POLICY_IDS := [
	SDK_BW13P_A_STABILITY_POLICY_ID,
	SDK_BW13P_B_STABILITY_POLICY_ID,
	SDK_BW13P_C_STABILITY_POLICY_ID,
	SDK_BW13P_D_STABILITY_POLICY_ID,
]
const SDK_STABILITY_FEEDBACK_AUTHORITY_POLICY_IDS := [
	SDK_P5I3C_STABILITY_POLICY_ID,
	SDK_BW9L_A_STABILITY_POLICY_ID,
	SDK_BW9L_B_STABILITY_POLICY_ID,
	SDK_BW9L_C_STABILITY_POLICY_ID,
	SDK_BW9L_D_STABILITY_POLICY_ID,
	SDK_BW10F_A_STABILITY_POLICY_ID,
	SDK_BW10F_B_STABILITY_POLICY_ID,
	SDK_BW10F_C_STABILITY_POLICY_ID,
	SDK_BW10F_D_STABILITY_POLICY_ID,
	SDK_BW11R_A_STABILITY_POLICY_ID,
	SDK_BW11R_B_STABILITY_POLICY_ID,
	SDK_BW11R_C_STABILITY_POLICY_ID,
	SDK_BW11R_D_STABILITY_POLICY_ID,
	SDK_BW13P_A_STABILITY_POLICY_ID,
	SDK_BW13P_B_STABILITY_POLICY_ID,
	SDK_BW13P_C_STABILITY_POLICY_ID,
	SDK_BW13P_D_STABILITY_POLICY_ID,
]
const SDK_CANDIDATE35_POLICY_ID := "g4_gq15_candidate35_v5"
const SDK_BALANCED_WAVE_POLICY_ID := "sporespore_balanced_wave_v1"
const SDK_BALANCED_WAVE_BW2_B_POLICY_ID := "sporespore_balanced_wave_bw2_b_v1"
const SDK_BALANCED_WAVE_BW2_C_POLICY_ID := "sporespore_balanced_wave_bw2_c_v1"
const SDK_BALANCED_WAVE_BW2R_A_POLICY_ID := "sporespore_balanced_wave_bw2r_a_v1"
const SDK_BALANCED_WAVE_BW2R_B_POLICY_ID := "sporespore_balanced_wave_bw2r_b_v1"
const SDK_BALANCED_WAVE_BW2R_C_POLICY_ID := "sporespore_balanced_wave_bw2r_c_v1"
const SDK_BALANCED_WAVE_BW4R_A_POLICY_ID := "sporespore_balanced_wave_bw4r_a_v1"
const SDK_BALANCED_WAVE_BW4R_B_POLICY_ID := "sporespore_balanced_wave_bw4r_b_v1"
const SDK_BALANCED_WAVE_BW5R_A_POLICY_ID := "sporespore_balanced_wave_bw5r_a_v1"
const SDK_BALANCED_WAVE_BW5R_B_POLICY_ID := "sporespore_balanced_wave_bw5r_b_v1"
const SDK_BALANCED_WAVE_BW5R_C_POLICY_ID := "sporespore_balanced_wave_bw5r_c_v1"
const SDK_BALANCED_WAVE_BW7D_A_POLICY_ID := "sporespore_balanced_wave_bw7d_a_v1"
const SDK_BALANCED_WAVE_BW7D_B_POLICY_ID := "sporespore_balanced_wave_bw7d_b_v1"
const SDK_BALANCED_WAVE_BW7D_C_POLICY_ID := "sporespore_balanced_wave_bw7d_c_v1"
const SDK_BALANCED_WAVE_BW7D_D_POLICY_ID := "sporespore_balanced_wave_bw7d_d_v1"
const SDK_BALANCED_WAVE_BW8U_A_POLICY_ID := "sporespore_balanced_wave_bw8u_a_v1"
const SDK_BALANCED_WAVE_BW8U_B_POLICY_ID := "sporespore_balanced_wave_bw8u_b_v1"
const SDK_BALANCED_WAVE_BW8U_C_POLICY_ID := "sporespore_balanced_wave_bw8u_c_v1"
const SDK_BALANCED_WAVE_BW8U_D_POLICY_ID := "sporespore_balanced_wave_bw8u_d_v1"
const SDK_BALANCED_WAVE_BW14V_B_POLICY_ID := "sporespore_balanced_wave_bw14v_b_v1"
const SDK_BALANCED_WAVE_BW15F_B_POLICY_ID := "sporespore_balanced_wave_bw15f_b_v1"
const SDK_BALANCED_WAVE_BW15F_C_POLICY_ID := "sporespore_balanced_wave_bw15f_c_v1"
const SDK_BALANCED_WAVE_BW15F_D_POLICY_ID := "sporespore_balanced_wave_bw15f_d_v1"
const SDK_BALANCED_WAVE_BW21L_B_POLICY_ID := "sporespore_balanced_wave_bw21l_b_v1"
const SDK_BALANCED_WAVE_BW21L_C_POLICY_ID := "sporespore_balanced_wave_bw21l_c_v1"
const SDK_BALANCED_WAVE_BW21L_D_POLICY_ID := "sporespore_balanced_wave_bw21l_d_v1"
const SDK_BALANCED_WAVE_BW23Y_B_POLICY_ID := "sporespore_balanced_wave_bw23y_b_v1"
const SDK_BALANCED_WAVE_BW34Y_A_POLICY_ID := "sporespore_balanced_wave_bw34y_a_v1"
const LEGACY_EVIDENCE_ACQUISITION_POLICY_ID := "legacy_exact_boundary_v1"
const BOUNDED_EVIDENCE_ACQUISITION_POLICY_ID := "bounded_all_support_acquisition_v1"
const SDK_P5I3C_FIXED_EXPOSURE_STEP_COUNT := 1514
const DEFAULT_SOLVER_POLICY_ID := "jolt_120hz_20v_6p_v1"
const GP4_SOLVER_POLICY_ID := "jolt_120hz_20v_7p_v1"
const ALLOWED_SOLVER_POLICY_OPTIONS := {
	DEFAULT_SOLVER_POLICY_ID:
	{
		"solver_policy_id": DEFAULT_SOLVER_POLICY_ID,
		"physics_engine": "Jolt Physics",
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 6,
	},
	GP4_SOLVER_POLICY_ID:
	{
		"solver_policy_id": GP4_SOLVER_POLICY_ID,
		"physics_engine": "Jolt Physics",
		"physics_hz": 120,
		"solver_velocity_steps": 20,
		"solver_position_steps": 7,
	},
}
const MINIMUM_ACTUATOR_IMPULSE_SCALE := 0.80
const MAXIMUM_ACTUATOR_IMPULSE_SCALE := 1.25
const MINIMUM_MOTOR_TARGET_SPEED_RAD_S := 0.25
const DEFAULT_MAXIMUM_CONTACT_GATE_HOLD_TICKS := 48
const MAXIMUM_CONTACT_GATE_HOLD_LIMIT_TICKS := 120
const DEFAULT_MAXIMUM_CONTACT_GATED_PHASE_SKEW_TICKS := 12
const MAXIMUM_CONTACT_GATED_PHASE_SKEW_LIMIT_TICKS := 90
const MAXIMUM_CONTACT_GATED_EVIDENCE_EXTENSION_TICKS := 720
const DEFAULT_LATERAL_STRIDE_STEERING_GAIN_PER_M := 0.0
const MAXIMUM_LATERAL_STRIDE_STEERING_GAIN_PER_M := 2.0
const MAXIMUM_LATERAL_STRIDE_STEERING_FRACTION := 0.40


func run(
	tree: SceneTree,
	motor_direction_sign: float = -1.0,
	knee_motor_impulse_scale: float = 10.0,
	knee_flexion_scale: float = 1.75,
	gait_phase_order_id: String = "lateral",
	swing_ticks: int = SWING_TICKS,
	contact_clearance_assist_rad: float = 0.40,
	contact_clearance_assist_limb_id: String = "all",
	evidence_boundary_alignment_ticks: int = EVIDENCE_BOUNDARY_ALIGNMENT_TICKS,
	visible_demo: bool = false,
	requested_initial_perturbation: Dictionary = {},
	requested_robustness_options: Dictionary = {},
	requested_fixture_spec: Dictionary = {},
	requested_path_steering_options: Dictionary = {},
	requested_actuator_impulse_options: Dictionary = {},
	requested_motor_velocity_options: Dictionary = {},
	requested_evidence_threshold_options: Dictionary = {},
	requested_gait_clock_options: Dictionary = {},
	requested_solver_policy_options: Dictionary = {},
	requested_dynamic_support_diagnostic_options: Dictionary = {},
	requested_sdk_shadow_options: Dictionary = {},
	requested_sdk_authority_options: Dictionary = {},
	requested_environment_challenge_options: Dictionary = {},
	requested_evidence_acquisition_options: Dictionary = {},
	preflight_before_world: bool = false,
	requested_fixed_observation_horizon_options: Dictionary = {},
) -> Dictionary:
	if contact_clearance_assist_rad < 0.0:
		return {
			"ok": false,
			"failure_code": "INVALID_CONTACT_CLEARANCE_ASSIST",
			"contact_clearance_assist_rad": contact_clearance_assist_rad,
		}
	if (
		contact_clearance_assist_limb_id != "all"
		and not LIMB_ORDER.has(contact_clearance_assist_limb_id)
	):
		return {
			"ok": false,
			"failure_code": "UNKNOWN_CONTACT_CLEARANCE_ASSIST_LIMB",
			"contact_clearance_assist_limb_id": contact_clearance_assist_limb_id,
		}
	var fixed_horizon_enabled := not requested_fixed_observation_horizon_options.is_empty()
	if fixed_horizon_enabled:
		var fixed_horizon_keys := requested_fixed_observation_horizon_options.keys()
		fixed_horizon_keys.sort()
		var expected_fixed_horizon_keys := [
			"candidate_specific_horizon_extension_count",
			"exact_post_sdk_observation_count",
			"first_post_sdk_observation_index",
			"last_post_sdk_observation_index",
			"policy_id",
			"policy_sha256",
		]
		expected_fixed_horizon_keys.sort()
		if (
			fixed_horizon_keys != expected_fixed_horizon_keys
			or String(requested_fixed_observation_horizon_options.get("policy_id", ""))
			!= BW30N_FIXED_HORIZON_POLICY_ID
			or String(requested_fixed_observation_horizon_options.get("policy_sha256", ""))
			!= BW30N_FIXED_HORIZON_POLICY_SHA256
			or int(
				requested_fixed_observation_horizon_options.get(
					"exact_post_sdk_observation_count", -1
				)
			)
			!= BW30N_FIXED_HORIZON_OBSERVATION_COUNT
			or int(
				requested_fixed_observation_horizon_options.get(
					"first_post_sdk_observation_index", -1
				)
			)
			!= 0
			or int(
				requested_fixed_observation_horizon_options.get(
					"last_post_sdk_observation_index", -1
				)
			)
			!= BW30N_FIXED_HORIZON_OBSERVATION_COUNT - 1
			or int(
				requested_fixed_observation_horizon_options.get(
					"candidate_specific_horizon_extension_count", -1
				)
			)
			!= 0
		):
			return {
				"ok": false,
				"failure_code": "BW30N_FIXED_OBSERVATION_HORIZON_INVALID",
			}
	var gait_clock_result := GaitClockSpecScript.compile(requested_gait_clock_options)
	if not bool(gait_clock_result.get("ok", false)):
		return gait_clock_result
	var gait_clock_options: Dictionary = gait_clock_result["gait_clock_options"]
	var physics_hz := int(gait_clock_options["physics_hz"])
	var cycle_ticks := int(gait_clock_options["cycle_ticks"])
	var settle_ticks := int(gait_clock_options["settle_ticks"])
	var terminal_settle_ticks := int(gait_clock_options["terminal_settle_ticks"])
	var warmup_cycles := int(gait_clock_options["warmup_cycles"])
	var evidence_cycles := int(gait_clock_options["evidence_cycles"])
	var cooldown_cycles := int(gait_clock_options["cooldown_cycles"])
	var maximum_contact_gated_evidence_extension_ticks := int(
		gait_clock_options["maximum_contact_gated_evidence_extension_ticks"]
	)
	var minimum_airborne_dwell_ticks := int(gait_clock_options["minimum_airborne_dwell_ticks"])
	var motor_position_gain_per_s := float(gait_clock_options["motor_position_gain_per_s"])
	var motor_rate_damping := float(gait_clock_options["motor_rate_damping"])
	var controller_maximum_motor_target_speed_rad_s := float(
		gait_clock_options["maximum_motor_target_speed_rad_s"]
	)
	if evidence_boundary_alignment_ticks < 0 or evidence_boundary_alignment_ticks >= cycle_ticks:
		return {
			"ok": false,
			"failure_code": "INVALID_EVIDENCE_BOUNDARY_ALIGNMENT_TICKS",
			"evidence_boundary_alignment_ticks": evidence_boundary_alignment_ticks,
		}
	if swing_ticks < 1 or swing_ticks > cycle_ticks / LIMB_ORDER.size():
		return {
			"ok": false,
			"failure_code": "INVALID_SWING_TICKS",
			"swing_ticks": swing_ticks,
		}
	var gait_phase_order := _resolve_gait_phase_order(gait_phase_order_id)
	if gait_phase_order.is_empty():
		return {
			"ok": false,
			"failure_code": "UNKNOWN_GAIT_PHASE_ORDER",
			"gait_phase_order_id": gait_phase_order_id,
		}
	var perturbation_result := _normalize_initial_perturbation(requested_initial_perturbation)
	if not bool(perturbation_result.get("ok", false)):
		return perturbation_result
	var initial_perturbation: Dictionary = perturbation_result["initial_perturbation"]
	var robustness_result := _normalize_robustness_options(requested_robustness_options)
	if not bool(robustness_result.get("ok", false)):
		return robustness_result
	var robustness_options: Dictionary = robustness_result["robustness_options"]
	var path_steering_result := _normalize_path_steering_options(
		requested_path_steering_options,
		cycle_ticks,
	)
	if not bool(path_steering_result.get("ok", false)):
		return path_steering_result
	var path_steering_options: Dictionary = path_steering_result["path_steering_options"]
	var actuator_impulse_result := _normalize_actuator_impulse_options(
		requested_actuator_impulse_options
	)
	if not bool(actuator_impulse_result.get("ok", false)):
		return actuator_impulse_result
	var actuator_impulse_options: Dictionary = actuator_impulse_result["actuator_impulse_options"]
	var motor_velocity_result := _normalize_motor_velocity_options(
		requested_motor_velocity_options,
		cycle_ticks,
	)
	if not bool(motor_velocity_result.get("ok", false)):
		return motor_velocity_result
	var motor_velocity_options: Dictionary = motor_velocity_result["motor_velocity_options"]
	var evidence_threshold_result := compile_evidence_threshold_options(
		requested_evidence_threshold_options
	)
	if not bool(evidence_threshold_result.get("ok", false)):
		return evidence_threshold_result
	var evidence_threshold_options: Dictionary = evidence_threshold_result["evidence_threshold_options"]
	var evidence_threshold_configuration_sha256 := String(
		evidence_threshold_result["evidence_threshold_configuration_sha256"]
	)
	var solver_policy_result := compile_solver_policy_options(requested_solver_policy_options)
	if not bool(solver_policy_result.get("ok", false)):
		return solver_policy_result
	var solver_policy_options: Dictionary = solver_policy_result["solver_policy_options"]
	var solver_policy_configuration_sha256 := String(
		solver_policy_result["solver_policy_configuration_sha256"]
	)
	var dynamic_support_options_result := _normalize_dynamic_support_diagnostic_options(
		requested_dynamic_support_diagnostic_options
	)
	if not bool(dynamic_support_options_result.get("ok", false)):
		return dynamic_support_options_result
	var dynamic_support_options: Dictionary = dynamic_support_options_result["dynamic_support_diagnostic_options"]
	var sdk_shadow_options_result := _normalize_sdk_shadow_options(requested_sdk_shadow_options)
	if not bool(sdk_shadow_options_result.get("ok", false)):
		return sdk_shadow_options_result
	var sdk_shadow_options: Dictionary = sdk_shadow_options_result["sdk_shadow_options"]
	var sdk_shadow_enabled := bool(sdk_shadow_options["enabled"])
	var sdk_authority_options_result := _normalize_sdk_authority_options(
		requested_sdk_authority_options
	)
	if not bool(sdk_authority_options_result.get("ok", false)):
		return sdk_authority_options_result
	var sdk_authority_options: Dictionary = sdk_authority_options_result["sdk_authority_options"]
	var environment_challenge_result := compile_environment_challenge_options(
		requested_environment_challenge_options
	)
	if not bool(environment_challenge_result.get("ok", false)):
		return environment_challenge_result
	var environment_challenge_options: Dictionary = environment_challenge_result["environment_challenge_options"]
	var environment_challenge_configuration_sha256 := String(
		environment_challenge_result["environment_challenge_configuration_sha256"]
	)
	var evidence_acquisition_result := compile_evidence_acquisition_options(
		requested_evidence_acquisition_options,
		int(gait_clock_options["maximum_contact_gated_phase_skew_ticks"]),
		minimum_airborne_dwell_ticks,
	)
	if not bool(evidence_acquisition_result.get("ok", false)):
		return evidence_acquisition_result
	var evidence_acquisition_options: Dictionary = evidence_acquisition_result["evidence_acquisition_options"]
	var evidence_acquisition_configuration_sha256 := String(
		evidence_acquisition_result["evidence_acquisition_configuration_sha256"]
	)
	var sdk_authority_enabled := bool(sdk_authority_options["enabled"])
	var sdk_authority_scope := String(sdk_authority_options["authority_scope"])
	if sdk_shadow_enabled and sdk_authority_enabled:
		return {
			"ok": false,
			"failure_code": "SDK_ADAPTER_EXECUTION_MODES_MUTUALLY_EXCLUSIVE",
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	var sdk_adapter_enabled := sdk_shadow_enabled or sdk_authority_enabled
	var sdk_adapter_options := (
		sdk_authority_options if sdk_authority_enabled else sdk_shadow_options
	)
	var sdk_execution_mode_plan := compile_sdk_execution_mode_plan(
		sdk_adapter_enabled,
		sdk_authority_enabled,
		sdk_authority_scope,
		String(sdk_adapter_options.get("stability_policy_id", "")),
		int(initial_perturbation.get("gait_phase_offset_ticks", 0)),
	)
	if not bool(sdk_execution_mode_plan.get("ok", false)):
		return sdk_execution_mode_plan
	var sdk_full_post_settle_authority_enabled := bool(
		sdk_execution_mode_plan["full_post_settle_authority_enabled"],
	)
	var sdk_stability_overlay_enabled := bool(
		sdk_execution_mode_plan["stability_contribution_overlay_enabled"],
	)
	var sdk_full_authority_stability_contribution_enabled := bool(
		sdk_execution_mode_plan["full_authority_stability_contribution_enabled"],
	)
	var sdk_p5i3c_fixed_exposure_enabled := bool(
		sdk_execution_mode_plan["fixed_exposure_enabled"],
	)
	var hip_impulse_scale := 1.0
	var knee_impulse_scale := 1.0
	if actuator_impulse_options.has("actuator_impulse_scale"):
		hip_impulse_scale = float(actuator_impulse_options["actuator_impulse_scale"])
		knee_impulse_scale = hip_impulse_scale
	else:
		hip_impulse_scale = float(actuator_impulse_options["hip_impulse_scale"])
		knee_impulse_scale = float(actuator_impulse_options["knee_impulse_scale"])
	if (
		bool(path_steering_options["phase_bounded_path_steering_enabled"])
		and float(robustness_options["lateral_stride_steering_gain_per_m"]) > 0.0
	):
		return {
			"ok": false,
			"failure_code": "CONFLICTING_LATERAL_STEERING_CONTROLLERS",
			"world_build_count": 0,
		}
	if (
		String(gait_clock_options["policy_id"]) == GaitClockSpecScript.DYNAMIC_SIMILARITY_POLICY_ID
		and (
			swing_ticks != int(gait_clock_options["swing_ticks"])
			or (
				evidence_boundary_alignment_ticks
				!= int(gait_clock_options["evidence_boundary_alignment_ticks"])
			)
			or (
				int(robustness_options["maximum_contact_gate_hold_ticks"])
				!= int(gait_clock_options["maximum_contact_gate_hold_ticks"])
			)
			or (
				int(robustness_options["maximum_contact_gated_phase_skew_ticks"])
				!= int(gait_clock_options["maximum_contact_gated_phase_skew_ticks"])
			)
			or (
				int(path_steering_options["steering_update_interval_ticks"])
				!= int(gait_clock_options["steering_update_interval_ticks"])
			)
		)
	):
		return {
			"ok": false,
			"failure_code": "DYNAMIC_GAIT_CLOCK_RECEIPT_MISMATCH",
			"world_build_count": 0,
		}
	var fixture_spec_result := FixtureSpecScript.compile(requested_fixture_spec)
	if not bool(fixture_spec_result.get("ok", false)):
		return fixture_spec_result
	var fixture_spec: Dictionary = fixture_spec_result["fixture_spec"]
	var fixture_spec_sha256 := String(fixture_spec_result["fixture_spec_sha256"])
	var controller_configuration := _controller_configuration(
		motor_direction_sign,
		knee_motor_impulse_scale,
		knee_flexion_scale,
		gait_phase_order_id,
		gait_phase_order,
		swing_ticks,
		contact_clearance_assist_rad,
		contact_clearance_assist_limb_id,
		evidence_boundary_alignment_ticks,
		robustness_options,
		path_steering_options,
		actuator_impulse_options,
		motor_velocity_options,
		gait_clock_options,
	)
	var controller_configuration_sha256 := CanonicalJsonScript.sha256(controller_configuration)
	if sdk_adapter_enabled:
		var sdk_shadow_configuration_failure := _sdk_shadow_configuration_failure(
			motor_direction_sign,
			knee_flexion_scale,
			gait_phase_order_id,
			swing_ticks,
			contact_clearance_assist_rad,
			contact_clearance_assist_limb_id,
			initial_perturbation,
			robustness_options,
			path_steering_options,
			gait_clock_options,
			sdk_full_post_settle_authority_enabled,
			sdk_p5i3c_fixed_exposure_enabled,
		)
		if not sdk_shadow_configuration_failure.is_empty():
			return {
				"ok": false,
				"failure_code": sdk_shadow_configuration_failure,
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
	var original_hz := Engine.physics_ticks_per_second
	var physics_engine := String(ProjectSettings.get_setting("physics/3d/physics_engine", ""))
	var solver_velocity_steps := int(
		ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/velocity_steps", -1)
	)
	var solver_position_steps := int(
		ProjectSettings.get_setting("physics/jolt_physics_3d/simulation/position_steps", -1)
	)
	var realized_solver_policy_options := {
		"solver_policy_id": String(solver_policy_options["solver_policy_id"]),
		"physics_engine": physics_engine,
		"physics_hz": physics_hz,
		"solver_velocity_steps": solver_velocity_steps,
		"solver_position_steps": solver_position_steps,
	}
	var solver_policy_realized := realized_solver_policy_options == solver_policy_options
	if not solver_policy_realized:
		Engine.physics_ticks_per_second = original_hz
		return {
			"ok": false,
			"failure_code": "REALIZED_SOLVER_POLICY_MISMATCH",
			"solver_policy_options": solver_policy_options.duplicate(true),
			"realized_solver_policy_options": realized_solver_policy_options.duplicate(true),
			"solver_policy_configuration_sha256": solver_policy_configuration_sha256,
			"world_build_count": 0,
		}
	var sdk_material_profile: Dictionary = {}
	var sdk_material_profile_sha256 := ""
	if sdk_adapter_enabled:
		var material_profile_result := (
			SdkGodotJoltMaterialProfilesScript
			. validate_for_fixture(
				String(
					(
						sdk_adapter_options
						. get(
							"material_profile_id",
							SdkGodotJoltMaterialProfilesScript.LEGACY_PROFILE_ID,
						)
					)
				),
				fixture_spec["contact_material"],
				realized_solver_policy_options,
			)
		)
		if not bool(material_profile_result.get("ok", false)):
			Engine.physics_ticks_per_second = original_hz
			return {
				"ok": false,
				"failure_code":
				(
					"SDK_MATERIAL_PROFILE_INVALID:%s"
					% String(material_profile_result.get("failure_code", ""))
				),
				"failure_detail": String(material_profile_result.get("failure_detail", "")),
				"world_build_count": 0,
				"physical_acceptance_authority": false,
			}
		sdk_material_profile = (material_profile_result["profile"] as Dictionary).duplicate(true)
		sdk_material_profile_sha256 = String(material_profile_result["profile_sha256"])
	var sdk_transport_execution_receipt := {
		"ok": not sdk_adapter_enabled,
		"failure_code": "",
		"transport_execution_version": "",
		"transport_execution_contract": {},
		"transport_execution_contract_sha256": "",
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	if sdk_adapter_enabled:
		sdk_transport_execution_receipt = (
			SdkGodotJoltAdapterScript.preflight_transport_execution()
		)
		if not bool(sdk_transport_execution_receipt.get("ok", false)):
			Engine.physics_ticks_per_second = original_hz
			return {
				"ok": false,
				"failure_code":
				(
					"SDK_TRANSPORT_PREFLIGHT_FAILED:%s"
					% String(sdk_transport_execution_receipt.get("failure_code", ""))
				),
				"sdk_transport_execution_receipt":
				sdk_transport_execution_receipt.duplicate(true),
				"world_build_count": 0,
				"scene_tree_insertion_count": 0,
				"physics_state_modified": false,
				"physical_acceptance_authority": false,
			}
	if preflight_before_world:
		return {
			"ok": true,
			"failure_code": "",
			"schema_version": "physical_wave_gait_pre_world_entrypoint_preflight_v1",
			"entrypoint_control_flow_complete": true,
			"declared_controller_policy_id":
			String(sdk_authority_options.get("controller_policy_id", "")),
			"declared_stability_policy_id":
			String(sdk_authority_options.get("stability_policy_id", "")),
			"authority_scope": String(sdk_authority_options.get("authority_scope", "")),
			"sdk_execution_mode_plan": sdk_execution_mode_plan.duplicate(true),
			"fixture_spec_sha256": fixture_spec_sha256,
			"controller_configuration_sha256": controller_configuration_sha256,
			"solver_policy_configuration_sha256": solver_policy_configuration_sha256,
			"material_profile_sha256": sdk_material_profile_sha256,
			"sdk_transport_execution_receipt":
			sdk_transport_execution_receipt.duplicate(true),
			"actual_world_build_count": 0,
			"scene_tree_insertion_count": 0,
			"physics_state_modified": false,
			"locomotion_outcome_exposed": false,
			"physical_acceptance_authority": false,
		}
	Engine.physics_ticks_per_second = physics_hz
	var fixture := await _build_fixture(
		tree,
		knee_motor_impulse_scale,
		hip_impulse_scale,
		knee_impulse_scale,
		visible_demo,
		initial_perturbation,
		fixture_spec,
		environment_challenge_options,
	)
	if not bool(fixture.get("ok", false)):
		Engine.physics_ticks_per_second = original_hz
		return fixture
	var cleanup_node: Node = fixture["cleanup_node"]
	var floor: StaticBody3D = fixture["floor"]
	var torso: RigidBody3D = fixture["torso"]
	var limbs: Array = fixture["limbs"]
	var bodies: Array = fixture["bodies"]
	var joint_state_by_joint_id: Dictionary = {}
	for limb_value in limbs:
		var mapped_limb: Dictionary = limb_value
		for state_value in mapped_limb["joint_states"]:
			var mapped_state: Dictionary = state_value
			joint_state_by_joint_id[String(mapped_state["joint_id"])] = mapped_state
	var initial_torso_position := torso.global_position
	var initial_torso_orientation := torso.global_basis.get_rotation_quaternion().normalized()
	var initial_yaw_rad := _yaw_rad(torso)
	var initial_lateral_axis_world := torso.global_transform.basis.z
	initial_lateral_axis_world.y = 0.0
	initial_lateral_axis_world = initial_lateral_axis_world.normalized()
	var initial_forward_axis_world := Vector3.UP.cross(initial_lateral_axis_world).normalized()
	var push_impulse_task := FixtureSpecScript.vector3_from_array(
		environment_challenge_options["push_impulse_task_n_s"]
	)
	var push_impulse_world := (
		initial_forward_axis_world * push_impulse_task.x
		+ Vector3.UP * push_impulse_task.y
		+ initial_lateral_axis_world * push_impulse_task.z
	)
	var dynamic_support_diagnostic_enabled := bool(dynamic_support_options["enabled"])
	var sdk_adapter: RefCounted
	var sdk_adapter_start_result := {
		"ok": not sdk_adapter_enabled,
		"failure_code": "",
		"world_build_count": 0,
	}
	if sdk_adapter_enabled:
		sdk_adapter = SdkGodotJoltAdapterScript.new()
	var sdk_authority_failure_code := ""
	var sdk_authority_last_application_result: Dictionary = {}
	var legacy_evidence_actuation_application_count := 0
	var legacy_post_settle_actuation_application_count := 0
	var legacy_sdk_overlay_base_application_count := 0
	var dynamic_support_trace: Array = []
	var dynamic_support_sample_failure_code := ""
	var dynamic_support_body_by_id: Dictionary = {}
	if dynamic_support_diagnostic_enabled:
		for body_value in bodies:
			var diagnostic_body: RigidBody3D = body_value
			dynamic_support_body_by_id[String(diagnostic_body.name)] = diagnostic_body
	var contact_gated_phase_progression := bool(
		robustness_options["contact_gated_phase_progression"]
	)
	var maximum_contact_gate_hold_ticks := int(
		robustness_options["maximum_contact_gate_hold_ticks"]
	)
	var maximum_contact_gated_phase_skew_ticks := int(
		robustness_options["maximum_contact_gated_phase_skew_ticks"]
	)
	var lateral_stride_steering_gain_per_m := float(
		robustness_options["lateral_stride_steering_gain_per_m"]
	)
	var phase_bounded_path_steering_enabled := bool(
		path_steering_options["phase_bounded_path_steering_enabled"]
	)
	var cross_track_heading_gain_rad_per_m := float(
		path_steering_options["cross_track_heading_gain_rad_per_m"]
	)
	var cross_track_velocity_heading_gain_rad_per_m_s := float(
		path_steering_options.get("cross_track_velocity_heading_gain_rad_per_m_s", 0.0)
	)
	var yaw_error_stride_gain_per_rad := float(
		path_steering_options["yaw_error_stride_gain_per_rad"]
	)
	var steering_update_interval_ticks := int(
		path_steering_options["steering_update_interval_ticks"]
	)
	var maximum_desired_heading_error_rad := float(
		path_steering_options["maximum_desired_heading_error_rad"]
	)
	var maximum_steering_fraction := float(path_steering_options["maximum_steering_fraction"])
	var evidence_start_tick := (
		settle_ticks + warmup_cycles * cycle_ticks + evidence_boundary_alignment_ticks
	)
	var sdk_adapter_start_tick := (
		settle_ticks if sdk_full_post_settle_authority_enabled else evidence_start_tick
	)
	var sdk_phase_offset_activation_tick := settle_ticks + warmup_cycles * cycle_ticks
	var sdk_phase_offset_activation_semantic_step := sdk_phase_offset_activation_tick - settle_ticks
	var nominal_evidence_end_tick := evidence_start_tick + evidence_cycles * cycle_ticks
	var maximum_evidence_end_tick := (
		nominal_evidence_end_tick
		+ (maximum_contact_gated_evidence_extension_ticks if contact_gated_phase_progression else 0)
	)
	var evidence_end_tick := -1 if contact_gated_phase_progression else nominal_evidence_end_tick
	var cooldown_end_tick := (
		-1 if contact_gated_phase_progression else evidence_end_tick + cooldown_cycles * cycle_ticks
	)
	var maximum_total_ticks := (
		maximum_evidence_end_tick + cooldown_cycles * cycle_ticks + terminal_settle_ticks
	)
	if fixed_horizon_enabled:
		maximum_total_ticks = settle_ticks + BW30N_FIXED_HORIZON_OBSERVATION_COUNT
	var evidence_start_torso_position := Vector3(INF, INF, INF)
	var evidence_end_torso_position := Vector3(INF, INF, INF)
	var contact_state_by_limb: Dictionary = {}
	var contact_cycle_count_by_limb: Dictionary = {}
	var rejected_short_contact_cycle_count_by_limb: Dictionary = {}
	var maximum_cycle_relocation_by_limb_m: Dictionary = {}
	var minimum_cycle_relocation_by_limb_m: Dictionary = {}
	var maximum_foot_center_height_by_limb_m: Dictionary = {}
	var contact_absent_tick_count_by_limb: Dictionary = {}
	var longest_contact_absent_dwell_by_limb_ticks: Dictionary = {}
	var current_contact_absent_dwell_by_limb_ticks: Dictionary = {}
	var contact_transition_receipts_by_limb: Dictionary = {}
	var contact_clearance_assist_tick_count_by_limb: Dictionary = {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var limb_id := String(limb["limb_id"])
		contact_state_by_limb[limb_id] = {
			"bearing": _foot_bears_floor(limb, floor),
			"airborne": false,
			"release_tick": -1,
			"release_position": Vector3(INF, INF, INF),
			"airborne_dwell_ticks": 0,
		}
		contact_cycle_count_by_limb[limb_id] = 0
		rejected_short_contact_cycle_count_by_limb[limb_id] = 0
		maximum_cycle_relocation_by_limb_m[limb_id] = 0.0
		minimum_cycle_relocation_by_limb_m[limb_id] = INF
		maximum_foot_center_height_by_limb_m[limb_id] = 0.0
		contact_absent_tick_count_by_limb[limb_id] = 0
		longest_contact_absent_dwell_by_limb_ticks[limb_id] = 0
		current_contact_absent_dwell_by_limb_ticks[limb_id] = 0
		contact_transition_receipts_by_limb[limb_id] = []
		contact_clearance_assist_tick_count_by_limb[limb_id] = 0
	var motor_command_count := 0
	var maximum_motor_target_speed_rad_s := 0.0
	var maximum_motor_target_speed_by_joint_role_rad_s := {
		"hip_pitch": 0.0,
		"knee_pitch": 0.0,
	}
	var contact_loaded_swing_knee_speed_cap_activation_count := 0
	var maximum_contact_loaded_swing_knee_target_speed_rad_s := 0.0
	var anchor_error_guard_activation_count := 0
	var maximum_anchor_error_guard_input_m := 0.0
	var maximum_anchor_error_guard_progress := 0.0
	var minimum_anchor_error_guard_speed_limit_rad_s := INF
	var maximum_anchor_error_guarded_target_speed_rad_s := 0.0
	var maximum_measured_joint_speed_rad_s := 0.0
	var maximum_anchor_error_m := 0.0
	var maximum_anchor_error_joint_id := ""
	var maximum_anchor_error_tick := -1
	var maximum_anchor_error_context := {}
	var latest_motor_command_context_by_joint_id := {}
	var maximum_hinge_axis_error_rad := 0.0
	var maximum_hinge_axis_error_joint_id := ""
	var maximum_hinge_axis_error_tick := -1
	var maximum_tilt_rad := 0.0
	var minimum_torso_height_m := INF
	var torso_contact_ticks := 0
	var direct_torso_force_command_count := 0
	var direct_torso_impulse_command_count := 0
	var direct_torso_velocity_command_count := 0
	var direct_torso_transform_command_count := 0
	var external_push_application_count := 0
	var external_push_receipt := {}
	var external_push_pre_linear_velocity_world_m_s := Vector3.ZERO
	var observation_fault_application_count := 0
	var observation_fault_base_and_stability_count := 0
	var maximum_observation_fault_component := 0.0
	var lateral_stride_steering_target_adjustment_count := 0
	var maximum_absolute_lateral_stride_steering_fraction := 0.0
	var held_path_steering_fraction := 0.0
	var path_steering_update_receipts: Array = []
	var maximum_absolute_path_cross_track_error_m := 0.0
	var maximum_absolute_path_yaw_tracking_error_rad := 0.0
	var first_torso_contact_tick := -1
	var initial_all_four_contacts := false
	var evidence_all_four_contacts_at_start := false
	var evidence_start_bearing_contact_by_limb: Dictionary = {}
	var evidence_boundary_contact_trace: Array = []
	var evidence_support_acquisition_trace: Array = []
	var evidence_support_acquisition_dwell_ticks := 0
	var evidence_support_acquisition_passed := false
	var evidence_support_acquisition_tick := -1
	var evidence_support_acquisition_timed_out := false
	var evidence_support_acquisition_enabled := bool(evidence_acquisition_options["enabled"])
	var maximum_evidence_support_acquisition_ticks := int(
		evidence_acquisition_options["maximum_acquisition_ticks"]
	)
	var minimum_all_support_acquisition_dwell_ticks := int(
		evidence_acquisition_options["minimum_all_support_dwell_ticks"]
	)
	var terminal_all_four_contacts := false
	var executed_ticks := 0
	var evidence_start_gait_tick := -1
	var evidence_end_gait_tick := -1
	var gated_gait_tick_by_limb: Dictionary = {}
	var evidence_start_gait_tick_by_limb: Dictionary = {}
	var evidence_end_gait_tick_by_limb: Dictionary = {}
	var contact_gated_evidence_horizon_timeout := false
	var current_contact_gate_hold_ticks_by_limb: Dictionary = {}
	var current_contact_gate_transition_dwell_ticks_by_limb: Dictionary = {}
	var contact_gate_hold_tick_count_by_limb: Dictionary = {}
	var contact_gate_release_hold_tick_count_by_limb: Dictionary = {}
	var contact_gate_recontact_hold_tick_count_by_limb: Dictionary = {}
	var contact_gate_timeout_count_by_limb: Dictionary = {}
	var contact_gate_timeout_receipts_by_limb: Dictionary = {}
	var contact_gate_phase_sync_hold_tick_count_by_limb: Dictionary = {}
	for limb_id_value in LIMB_ORDER:
		var limb_id := String(limb_id_value)
		gated_gait_tick_by_limb[limb_id] = 0
		evidence_start_gait_tick_by_limb[limb_id] = -1
		evidence_end_gait_tick_by_limb[limb_id] = -1
		current_contact_gate_hold_ticks_by_limb[limb_id] = 0
		current_contact_gate_transition_dwell_ticks_by_limb[limb_id] = 0
		contact_gate_hold_tick_count_by_limb[limb_id] = 0
		contact_gate_release_hold_tick_count_by_limb[limb_id] = 0
		contact_gate_recontact_hold_tick_count_by_limb[limb_id] = 0
		contact_gate_timeout_count_by_limb[limb_id] = 0
		contact_gate_timeout_receipts_by_limb[limb_id] = []
		contact_gate_phase_sync_hold_tick_count_by_limb[limb_id] = 0
	for tick in range(maximum_total_ticks):
		if (
			external_push_application_count == 1
			and int(external_push_receipt.get("tick", -2)) + 1 == tick
			and not bool(external_push_receipt.get("effect_sampled", false))
		):
			var observed_velocity_delta := (
				torso.linear_velocity - external_push_pre_linear_velocity_world_m_s
			)
			external_push_receipt["effect_sampled"] = true
			external_push_receipt["observed_next_tick_velocity_delta_world_m_s"] = (observed_velocity_delta)
			external_push_receipt["observed_next_tick_velocity_delta_magnitude_m_s"] = (
				observed_velocity_delta.length()
			)
		var push_tick := (
			sdk_adapter_start_tick + int(environment_challenge_options["push_step_from_sdk_start"])
		)
		if (
			String(environment_challenge_options["push_profile_id"]) != NO_PUSH_PROFILE_ID
			and tick == push_tick
		):
			external_push_pre_linear_velocity_world_m_s = torso.linear_velocity
			torso.apply_central_impulse(push_impulse_world)
			external_push_application_count += 1
			external_push_receipt = {
				"profile_id": String(environment_challenge_options["push_profile_id"]),
				"tick": tick,
				"step_from_sdk_start":
				int(environment_challenge_options["push_step_from_sdk_start"]),
				"impulse_task_n_s": push_impulse_task,
				"impulse_world_n_s": push_impulse_world,
				"application_count": external_push_application_count,
				"controller_command": false,
				"effect_sampled": false,
			}
		if tick >= evidence_start_tick - 16 and tick <= evidence_start_tick + 16:
			var boundary_bearing_contact_by_limb := _bearing_contact_by_limb(limbs, floor)
			(
				evidence_boundary_contact_trace
				. append(
					{
						"tick": tick,
						"tick_from_nominal_evidence_start": tick - evidence_start_tick,
						"bearing_contact_by_limb": boundary_bearing_contact_by_limb,
						"all_feet_bear_floor":
						_all_dictionary_values_true(boundary_bearing_contact_by_limb),
					}
				)
			)
		if (
			evidence_support_acquisition_enabled
			and tick >= evidence_start_tick
			and (tick <= evidence_start_tick + maximum_evidence_support_acquisition_ticks)
		):
			var acquisition_bearing_by_limb := _bearing_contact_by_limb(limbs, floor)
			var all_support := _all_dictionary_values_true(acquisition_bearing_by_limb)
			evidence_support_acquisition_dwell_ticks = (
				evidence_support_acquisition_dwell_ticks + 1 if all_support else 0
			)
			(
				evidence_support_acquisition_trace
				. append(
					{
						"tick": tick,
						"tick_from_nominal_evidence_start": tick - evidence_start_tick,
						"bearing_contact_by_limb": acquisition_bearing_by_limb,
						"all_feet_bear_floor": all_support,
						"consecutive_all_support_dwell_ticks":
						evidence_support_acquisition_dwell_ticks,
					}
				)
			)
			if (
				not evidence_support_acquisition_passed
				and (
					evidence_support_acquisition_dwell_ticks
					>= minimum_all_support_acquisition_dwell_ticks
				)
			):
				evidence_support_acquisition_passed = true
				evidence_support_acquisition_tick = tick
			if (
				tick == evidence_start_tick + maximum_evidence_support_acquisition_ticks
				and not evidence_support_acquisition_passed
			):
				evidence_support_acquisition_timed_out = true
		if tick == evidence_start_tick:
			evidence_start_torso_position = torso.global_position
			evidence_start_bearing_contact_by_limb = _bearing_contact_by_limb(limbs, floor)
			evidence_all_four_contacts_at_start = _all_dictionary_values_true(
				evidence_start_bearing_contact_by_limb
			)
			if not evidence_support_acquisition_enabled:
				evidence_support_acquisition_passed = evidence_all_four_contacts_at_start
				evidence_support_acquisition_tick = (
					tick if evidence_all_four_contacts_at_start else -1
				)
				evidence_support_acquisition_timed_out = (not evidence_all_four_contacts_at_start)
			evidence_start_gait_tick = maxi(tick - settle_ticks, 0)
			for limb_id_value in LIMB_ORDER:
				var gait_limb_id := String(limb_id_value)
				gated_gait_tick_by_limb[gait_limb_id] = evidence_start_gait_tick
				evidence_start_gait_tick_by_limb[gait_limb_id] = evidence_start_gait_tick
				current_contact_gate_hold_ticks_by_limb[gait_limb_id] = 0
				current_contact_gate_transition_dwell_ticks_by_limb[gait_limb_id] = 0
			for limb_value in limbs:
				var limb: Dictionary = limb_value
				var limb_id := String(limb["limb_id"])
				var state: Dictionary = contact_state_by_limb[limb_id]
				state["bearing"] = _foot_bears_floor(limb, floor)
				state["airborne"] = false
				state["release_tick"] = -1
				state["release_position"] = Vector3(INF, INF, INF)
				state["airborne_dwell_ticks"] = 0
		if tick == evidence_end_tick:
			evidence_end_torso_position = torso.global_position
		var amplitude_evidence_end_tick := (
			evidence_end_tick if evidence_end_tick >= 0 else maximum_evidence_end_tick
		)
		var amplitude_cooldown_end_tick := (
			cooldown_end_tick
			if cooldown_end_tick >= 0
			else maximum_evidence_end_tick + cooldown_cycles * cycle_ticks
		)
		var gait_amplitude := _gait_amplitude(
			tick,
			amplitude_evidence_end_tick,
			amplitude_cooldown_end_tick,
			settle_ticks,
			warmup_cycles,
			cooldown_cycles,
			cycle_ticks,
		)
		var ungated_gait_tick := maxi(tick - settle_ticks, 0)
		var sdk_phase_progression_mode := (
			"contact_gated"
			if (tick >= evidence_start_tick and (evidence_end_tick < 0 or tick < evidence_end_tick))
			else "clocked"
		)
		var sdk_adapter_window_active := (
			sdk_adapter_enabled
			and tick >= sdk_adapter_start_tick
			and (
				(
					sdk_p5i3c_fixed_exposure_enabled
					and tick < sdk_adapter_start_tick + SDK_P5I3C_FIXED_EXPOSURE_STEP_COUNT
				)
				or (
					not sdk_p5i3c_fixed_exposure_enabled
					and (
						sdk_full_post_settle_authority_enabled
						or (evidence_end_tick < 0 or tick < evidence_end_tick)
					)
				)
			)
		)
		if sdk_adapter_enabled and tick == sdk_adapter_start_tick:
			var sdk_initial_gait_step_by_limb := _sdk_initial_gait_steps(
				gated_gait_tick_by_limb,
				int(initial_perturbation["gait_phase_offset_ticks"]),
				sdk_p5i3c_fixed_exposure_enabled,
			)
			sdk_adapter_start_result = (
				sdk_adapter
				. start(
					sdk_adapter_options["descriptor"],
					sdk_initial_gait_step_by_limb,
					held_path_steering_fraction,
					initial_torso_position,
					initial_lateral_axis_world,
					initial_yaw_rad,
					physics_hz,
					realized_solver_policy_options,
					float(sdk_adapter_options["comparison_tolerance"]),
					sdk_phase_progression_mode,
					sdk_authority_enabled,
					(
						int(initial_perturbation["gait_phase_offset_ticks"])
						if sdk_full_post_settle_authority_enabled
						else 0
					),
					(
						sdk_phase_offset_activation_semantic_step
						if sdk_full_post_settle_authority_enabled
						else -1
					),
					sdk_authority_scope if sdk_authority_enabled else "shadow",
					String(sdk_adapter_options["stability_policy_id"]),
					sdk_material_profile,
					String(
						(
							sdk_adapter_options
							. get(
								"controller_policy_id",
								SDK_CANDIDATE35_POLICY_ID,
							)
						)
					),
					float(
						sdk_adapter_options.get(
							"stability_influence_global_scale",
							-1.0,
						)
					),
				)
			)
		var sdk_adapter_sample_result: Dictionary = {}
		if sdk_adapter_window_active and bool(sdk_adapter_start_result.get("ok", false)):
			sdk_adapter_sample_result = (
				sdk_adapter
				. sample(
					ungated_gait_tick,
					gait_amplitude,
					sdk_phase_progression_mode,
					torso,
					limbs,
					floor,
					environment_challenge_options,
				)
			)
			var observation_fault_receipt: Dictionary = sdk_adapter_sample_result.get(
				"observation_fault_receipt", {}
			)
			if bool(observation_fault_receipt.get("applied", false)):
				observation_fault_application_count += 1
				if (
					bool(observation_fault_receipt.get("base_state_faulted", false))
					and bool(
						(
							observation_fault_receipt
							. get(
								"stability_state_faulted",
								false,
							)
						)
					)
				):
					observation_fault_base_and_stability_count += 1
				maximum_observation_fault_component = maxf(
					maximum_observation_fault_component,
					float(
						(
							observation_fault_receipt
							. get(
								"maximum_absolute_applied_component",
								0.0,
							)
						)
					),
				)
		if (
			phase_bounded_path_steering_enabled
			and tick >= settle_ticks
			and ungated_gait_tick % steering_update_interval_ticks == 0
		):
			var path_displacement_world := torso.global_position - initial_torso_position
			var cross_track_error_m := path_displacement_world.dot(initial_lateral_axis_world)
			var cross_track_velocity_m_s := torso.linear_velocity.dot(initial_lateral_axis_world)
			var measured_yaw_error_rad := _wrap_angle(_yaw_rad(torso) - initial_yaw_rad)
			var desired_heading_error_rad := clampf(
				(
					-cross_track_heading_gain_rad_per_m * cross_track_error_m
					- (cross_track_velocity_heading_gain_rad_per_m_s * cross_track_velocity_m_s)
				),
				-maximum_desired_heading_error_rad,
				maximum_desired_heading_error_rad
			)
			var yaw_tracking_error_rad := _wrap_angle(
				measured_yaw_error_rad - desired_heading_error_rad
			)
			held_path_steering_fraction = clampf(
				yaw_error_stride_gain_per_rad * yaw_tracking_error_rad,
				-maximum_steering_fraction,
				maximum_steering_fraction
			)
			maximum_absolute_path_cross_track_error_m = maxf(
				maximum_absolute_path_cross_track_error_m, absf(cross_track_error_m)
			)
			maximum_absolute_path_yaw_tracking_error_rad = maxf(
				maximum_absolute_path_yaw_tracking_error_rad, absf(yaw_tracking_error_rad)
			)
			var steering_receipt := {
				"tick": tick,
				"gait_tick": ungated_gait_tick,
				"cross_track_error_m": cross_track_error_m,
				"measured_yaw_error_rad": measured_yaw_error_rad,
				"desired_heading_error_rad": desired_heading_error_rad,
				"yaw_tracking_error_rad": yaw_tracking_error_rad,
				"steering_fraction": held_path_steering_fraction,
			}
			if path_steering_options.has("cross_track_velocity_heading_gain_rad_per_m_s"):
				steering_receipt["cross_track_velocity_m_s"] = cross_track_velocity_m_s
			path_steering_update_receipts.append(steering_receipt)
		for limb_value in limbs:
			var limb: Dictionary = limb_value
			var limb_id := String(limb["limb_id"])
			var gait_tick := ungated_gait_tick
			if contact_gated_phase_progression and tick >= evidence_start_tick:
				gait_tick = int(gated_gait_tick_by_limb[limb_id])
			if tick >= settle_ticks + warmup_cycles * cycle_ticks:
				gait_tick += int(initial_perturbation["gait_phase_offset_ticks"])
			var phase_index := gait_phase_order.find(limb_id)
			var phase_offset_ticks := phase_index * (cycle_ticks / gait_phase_order.size())
			var local_phase_tick := posmod(gait_tick - phase_offset_ticks, cycle_ticks)
			var targets := _gait_joint_targets(
				local_phase_tick,
				gait_amplitude,
				knee_flexion_scale,
				swing_ticks,
				cycle_ticks,
			)
			var foot_bears_floor := _foot_bears_floor(limb, floor)
			if phase_bounded_path_steering_enabled or lateral_stride_steering_gain_per_m > 0.0:
				var lateral_stride_steering_fraction := held_path_steering_fraction
				if not phase_bounded_path_steering_enabled:
					var lateral_error_m := torso.global_position.z - initial_torso_position.z
					lateral_stride_steering_fraction = clampf(
						lateral_stride_steering_gain_per_m * lateral_error_m,
						-MAXIMUM_LATERAL_STRIDE_STEERING_FRACTION,
						MAXIMUM_LATERAL_STRIDE_STEERING_FRACTION
					)
				maximum_absolute_lateral_stride_steering_fraction = maxf(
					maximum_absolute_lateral_stride_steering_fraction,
					absf(lateral_stride_steering_fraction)
				)
				if not is_zero_approx(lateral_stride_steering_fraction):
					lateral_stride_steering_target_adjustment_count += 1
				var lateral_side_sign := 1.0 if limb_id.ends_with("_right") else -1.0
				targets["hip_target_rad"] = (
					float(targets["hip_target_rad"])
					* (1.0 + lateral_side_sign * lateral_stride_steering_fraction)
				)
			if (
				local_phase_tick < swing_ticks
				and gait_amplitude > 0.0
				and contact_clearance_assist_rad > 0.0
				and (
					contact_clearance_assist_limb_id == "all"
					or contact_clearance_assist_limb_id == limb_id
				)
				and foot_bears_floor
			):
				targets["knee_target_rad"] = (
					float(targets["knee_target_rad"])
					+ gait_amplitude * contact_clearance_assist_rad
				)
				contact_clearance_assist_tick_count_by_limb[limb_id] = (
					int(contact_clearance_assist_tick_count_by_limb[limb_id]) + 1
				)
			for state_value in limb["joint_states"]:
				var state: Dictionary = state_value
				var joint_role := String(state["role"])
				var target_angle_rad := (
					float(targets["hip_target_rad"])
					if joint_role == "hip_pitch"
					else float(targets["knee_target_rad"])
				)
				var maximum_target_speed_rad_s := controller_maximum_motor_target_speed_rad_s
				var contact_loaded_speed_cap_active := (
					bool(motor_velocity_options["mass_adaptive_motor_velocity_enabled"])
					and (
						float(
							motor_velocity_options["contact_loaded_swing_knee_maximum_motor_target_speed_rad_s"]
						)
						< controller_maximum_motor_target_speed_rad_s
					)
					and joint_role == "knee_pitch"
					and (
						local_phase_tick
						>= int(
							motor_velocity_options["contact_loaded_swing_knee_activation_start_phase_tick"]
						)
					)
					and local_phase_tick < swing_ticks
					and (
						local_phase_tick
						!= int(
							motor_velocity_options["contact_loaded_swing_knee_full_speed_override_phase_tick"]
						)
					)
					and foot_bears_floor
				)
				if contact_loaded_speed_cap_active:
					maximum_target_speed_rad_s = float(
						motor_velocity_options["contact_loaded_swing_knee_maximum_motor_target_speed_rad_s"]
					)
					contact_loaded_swing_knee_speed_cap_activation_count += 1
				var anchor_error_before_command_m := float(
					_joint_geometry_receipt(state)["anchor_error_m"]
				)
				var anchor_error_guard_threshold_m := (
					float(evidence_threshold_options["maximum_anchor_error_m"])
					* float(motor_velocity_options["anchor_error_guard_activation_fraction"])
				)
				var anchor_error_guard_progress := clampf(
					(
						(
							(
								anchor_error_before_command_m
								/ float(evidence_threshold_options["maximum_anchor_error_m"])
							)
							- float(
								motor_velocity_options["anchor_error_guard_activation_fraction"]
							)
						)
						/ (
							1.0
							- float(
								motor_velocity_options["anchor_error_guard_activation_fraction"]
							)
						)
					),
					0.0,
					1.0,
				)
				var anchor_error_guard_speed_limit_rad_s := lerpf(
					controller_maximum_motor_target_speed_rad_s,
					float(
						motor_velocity_options["anchor_error_guard_maximum_motor_target_speed_rad_s"]
					),
					(
						anchor_error_guard_progress
						* float(motor_velocity_options["morphology_interaction_score"])
					),
				)
				var anchor_error_guard_active := (
					bool(motor_velocity_options["anchor_error_guard_enabled"])
					and (anchor_error_guard_speed_limit_rad_s < maximum_target_speed_rad_s)
					and joint_role == "knee_pitch"
					and local_phase_tick < swing_ticks
					and foot_bears_floor
					and anchor_error_before_command_m > anchor_error_guard_threshold_m
				)
				if anchor_error_guard_active:
					maximum_target_speed_rad_s = anchor_error_guard_speed_limit_rad_s
					anchor_error_guard_activation_count += 1
					maximum_anchor_error_guard_input_m = maxf(
						maximum_anchor_error_guard_input_m,
						anchor_error_before_command_m,
					)
					maximum_anchor_error_guard_progress = maxf(
						maximum_anchor_error_guard_progress,
						anchor_error_guard_progress,
					)
					minimum_anchor_error_guard_speed_limit_rad_s = minf(
						minimum_anchor_error_guard_speed_limit_rad_s,
						anchor_error_guard_speed_limit_rad_s,
					)
				var native_authority_window_active := (
					sdk_authority_enabled
					and not sdk_stability_overlay_enabled
					and bool(sdk_adapter_start_result.get("ok", false))
					and sdk_adapter_window_active
				)
				var motor_receipt := _command_hinge_motor(
					state,
					target_angle_rad,
					motor_direction_sign,
					motor_position_gain_per_s,
					motor_rate_damping,
					maximum_target_speed_rad_s,
					not native_authority_window_active,
				)
				if (
					bool(motor_receipt.get("actuation_applied", false))
					and tick >= evidence_start_tick
					and (evidence_end_tick < 0 or tick < evidence_end_tick)
				):
					legacy_evidence_actuation_application_count += 1
				if bool(motor_receipt.get("actuation_applied", false)) and tick >= settle_ticks:
					legacy_post_settle_actuation_application_count += 1
				if (
					bool(motor_receipt.get("actuation_applied", false))
					and sdk_stability_overlay_enabled
					and sdk_adapter_window_active
				):
					legacy_sdk_overlay_base_application_count += 1
				var joint_id := String(state["joint_id"])
				latest_motor_command_context_by_joint_id[joint_id] = {
					"tick": tick,
					"joint_id": joint_id,
					"joint_role": joint_role,
					"limb_id": limb_id,
					"gait_tick": gait_tick,
					"local_phase_tick": local_phase_tick,
					"swing_phase": local_phase_tick < swing_ticks,
					"gait_amplitude": gait_amplitude,
					"target_angle_rad": target_angle_rad,
					"target_velocity_rad_s": float(motor_receipt["target_velocity_rad_s"]),
					"maximum_target_speed_rad_s": maximum_target_speed_rad_s,
					"contact_loaded_speed_cap_active": contact_loaded_speed_cap_active,
					"contact_loaded_speed_cap_activation_start_phase_tick":
					int(
						motor_velocity_options["contact_loaded_swing_knee_activation_start_phase_tick"]
					),
					"contact_loaded_speed_cap_full_speed_override_phase_tick":
					int(
						motor_velocity_options["contact_loaded_swing_knee_full_speed_override_phase_tick"]
					),
					"anchor_error_before_command_m": anchor_error_before_command_m,
					"anchor_error_guard_threshold_m": anchor_error_guard_threshold_m,
					"anchor_error_guard_progress": anchor_error_guard_progress,
					"anchor_error_guard_speed_limit_rad_s": anchor_error_guard_speed_limit_rad_s,
					"anchor_error_guard_active": anchor_error_guard_active,
					"measured_angle_rad": float(motor_receipt["measured_angle_rad"]),
					"measured_rate_rad_s": float(motor_receipt["measured_rate_rad_s"]),
					"foot_bears_floor": foot_bears_floor,
				}
				motor_command_count += 1
				maximum_motor_target_speed_rad_s = maxf(
					maximum_motor_target_speed_rad_s,
					absf(float(motor_receipt["target_velocity_rad_s"]))
				)
				maximum_motor_target_speed_by_joint_role_rad_s[joint_role] = maxf(
					float(maximum_motor_target_speed_by_joint_role_rad_s[joint_role]),
					absf(float(motor_receipt["target_velocity_rad_s"])),
				)
				if contact_loaded_speed_cap_active:
					maximum_contact_loaded_swing_knee_target_speed_rad_s = maxf(
						maximum_contact_loaded_swing_knee_target_speed_rad_s,
						absf(float(motor_receipt["target_velocity_rad_s"])),
					)
				if anchor_error_guard_active:
					maximum_anchor_error_guarded_target_speed_rad_s = maxf(
						maximum_anchor_error_guarded_target_speed_rad_s,
						absf(float(motor_receipt["target_velocity_rad_s"])),
					)
				maximum_measured_joint_speed_rad_s = maxf(
					maximum_measured_joint_speed_rad_s,
					absf(float(motor_receipt["measured_rate_rad_s"]))
				)
		if sdk_adapter_window_active and bool(sdk_adapter_start_result.get("ok", false)):
			var sdk_legacy_gait_step_by_limb := {}
			var sdk_effective_phase_offset_ticks := _sdk_effective_phase_offset_ticks(
				int(initial_perturbation["gait_phase_offset_ticks"]),
				sdk_p5i3c_fixed_exposure_enabled,
				sdk_full_post_settle_authority_enabled,
				tick,
				sdk_phase_offset_activation_tick,
			)
			for sdk_limb_id_value in LIMB_ORDER:
				var sdk_limb_id := String(sdk_limb_id_value)
				var sdk_base_gait_step := (
					int(gated_gait_tick_by_limb[sdk_limb_id])
					if tick >= evidence_start_tick
					else ungated_gait_tick
				)
				sdk_legacy_gait_step_by_limb[sdk_limb_id] = (
					sdk_base_gait_step + sdk_effective_phase_offset_ticks
				)
			var sdk_adapter_step_result: Dictionary = (
				sdk_adapter
				. step(
					sdk_adapter_sample_result,
					ungated_gait_tick,
					latest_motor_command_context_by_joint_id,
					sdk_legacy_gait_step_by_limb,
					held_path_steering_fraction,
					(
						path_steering_update_receipts[-1]
						if not path_steering_update_receipts.is_empty()
						else {}
					),
				)
			)
			if sdk_authority_enabled:
				sdk_authority_last_application_result = (
					(
						sdk_adapter
						. apply_stability_contribution(
							sdk_adapter_step_result,
							latest_motor_command_context_by_joint_id,
							joint_state_by_joint_id,
						)
					)
					if (
						sdk_stability_overlay_enabled
						or sdk_full_authority_stability_contribution_enabled
					)
					else (
						sdk_adapter
						. apply_authority(
							sdk_adapter_step_result,
							joint_state_by_joint_id,
						)
					)
				)
				if (
					sdk_authority_failure_code.is_empty()
					and not bool(sdk_authority_last_application_result.get("ok", false))
				):
					sdk_authority_failure_code = String(
						(
							sdk_authority_last_application_result
							. get(
								"failure_code",
								"SDK_AUTHORITY_APPLICATION_FAILED",
							)
						)
					)
		await tree.physics_frame
		executed_ticks = tick + 1
		if contact_gated_phase_progression and tick >= evidence_start_tick:
			var evidence_window_still_active := evidence_end_tick < 0 or tick < evidence_end_tick
			var minimum_gated_gait_tick := _minimum_dictionary_integer(gated_gait_tick_by_limb)
			for limb_value in limbs:
				var gated_limb: Dictionary = limb_value
				var gated_limb_id := String(gated_limb["limb_id"])
				var gait_advance_ticks := (
					int(gated_gait_tick_by_limb[gated_limb_id])
					- int(evidence_start_gait_tick_by_limb[gated_limb_id])
				)
				if (
					evidence_window_still_active
					and tick >= evidence_start_tick
					and gait_advance_ticks >= evidence_cycles * cycle_ticks
				):
					continue
				if not evidence_window_still_active:
					gated_gait_tick_by_limb[gated_limb_id] = (
						int(gated_gait_tick_by_limb[gated_limb_id]) + 1
					)
					continue
				var gated_phase_index := gait_phase_order.find(gated_limb_id)
				var commanded_gait_tick := (
					int(gated_gait_tick_by_limb[gated_limb_id])
					+ int(initial_perturbation["gait_phase_offset_ticks"])
				)
				var gate_receipt := _contact_gated_limb_phase_receipt(
					gated_limb,
					floor,
					gated_phase_index,
					commanded_gait_tick,
					swing_ticks,
					cycle_ticks,
				)
				var gate_active := bool(gate_receipt.get("gate_active", false))
				var contact_satisfied := bool(gate_receipt.get("contact_satisfied", false))
				if gate_active and contact_satisfied:
					current_contact_gate_transition_dwell_ticks_by_limb[gated_limb_id] = (
						int(current_contact_gate_transition_dwell_ticks_by_limb[gated_limb_id]) + 1
					)
				elif gate_active:
					current_contact_gate_transition_dwell_ticks_by_limb[gated_limb_id] = 0
				else:
					current_contact_gate_transition_dwell_ticks_by_limb[gated_limb_id] = 0
				var hold_phase := (
					gate_active
					and (
						not contact_satisfied
						or (
							int(current_contact_gate_transition_dwell_ticks_by_limb[gated_limb_id])
							< minimum_airborne_dwell_ticks
						)
					)
				)
				if (
					hold_phase
					and (
						int(current_contact_gate_hold_ticks_by_limb[gated_limb_id])
						< maximum_contact_gate_hold_ticks
					)
				):
					var hold_reason := String(gate_receipt["hold_reason"])
					current_contact_gate_hold_ticks_by_limb[gated_limb_id] = (
						int(current_contact_gate_hold_ticks_by_limb[gated_limb_id]) + 1
					)
					contact_gate_hold_tick_count_by_limb[gated_limb_id] = (
						int(contact_gate_hold_tick_count_by_limb[gated_limb_id]) + 1
					)
					if hold_reason == "await_release":
						contact_gate_release_hold_tick_count_by_limb[gated_limb_id] = (
							int(contact_gate_release_hold_tick_count_by_limb[gated_limb_id]) + 1
						)
					else:
						contact_gate_recontact_hold_tick_count_by_limb[gated_limb_id] = (
							int(contact_gate_recontact_hold_tick_count_by_limb[gated_limb_id]) + 1
						)
				else:
					if hold_phase:
						contact_gate_timeout_count_by_limb[gated_limb_id] = (
							int(contact_gate_timeout_count_by_limb[gated_limb_id]) + 1
						)
						(
							(contact_gate_timeout_receipts_by_limb[gated_limb_id] as Array)
							. append(
								{
									"tick": tick,
									"limb_id": gated_limb_id,
									"hold_reason": String(gate_receipt.get("hold_reason", "")),
									"local_phase_tick":
									int(gate_receipt.get("local_phase_tick", -1)),
									"contact_satisfied": contact_satisfied,
									"foot_bears_floor": _foot_bears_floor(gated_limb, floor),
									"maximum_hold_ticks": maximum_contact_gate_hold_ticks,
									"gated_gait_tick": int(gated_gait_tick_by_limb[gated_limb_id]),
									"commanded_gait_tick": commanded_gait_tick,
								}
							)
						)
					var current_gated_gait_tick := int(gated_gait_tick_by_limb[gated_limb_id])
					var phase_lead_ticks := current_gated_gait_tick - minimum_gated_gait_tick
					if (
						phase_lead_ticks > 0
						and phase_lead_ticks >= maximum_contact_gated_phase_skew_ticks
					):
						contact_gate_phase_sync_hold_tick_count_by_limb[gated_limb_id] = (
							int(contact_gate_phase_sync_hold_tick_count_by_limb[gated_limb_id]) + 1
						)
					else:
						gated_gait_tick_by_limb[gated_limb_id] = current_gated_gait_tick + 1
					current_contact_gate_hold_ticks_by_limb[gated_limb_id] = 0
					current_contact_gate_transition_dwell_ticks_by_limb[gated_limb_id] = 0
			if evidence_end_tick < 0 and tick >= evidence_start_tick:
				var evidence_gait_advance_ticks := _minimum_dictionary_difference(
					gated_gait_tick_by_limb, evidence_start_gait_tick_by_limb
				)
				if evidence_gait_advance_ticks >= evidence_cycles * cycle_ticks:
					evidence_end_tick = tick + 1
					evidence_end_gait_tick = evidence_start_gait_tick + evidence_gait_advance_ticks
					evidence_end_gait_tick_by_limb = gated_gait_tick_by_limb.duplicate(true)
					cooldown_end_tick = evidence_end_tick + cooldown_cycles * cycle_ticks
					evidence_end_torso_position = torso.global_position
				elif tick + 1 >= maximum_evidence_end_tick:
					contact_gated_evidence_horizon_timeout = true
					evidence_end_tick = tick + 1
					evidence_end_gait_tick = evidence_start_gait_tick + evidence_gait_advance_ticks
					evidence_end_gait_tick_by_limb = gated_gait_tick_by_limb.duplicate(true)
					cooldown_end_tick = evidence_end_tick + cooldown_cycles * cycle_ticks
					evidence_end_torso_position = torso.global_position
		if tick == settle_ticks - 1:
			initial_all_four_contacts = _all_feet_bear_floor(limbs, floor)
		if tick >= evidence_start_tick and (evidence_end_tick < 0 or tick < evidence_end_tick):
			_update_contact_cycle_receipts(
				tick,
				limbs,
				floor,
				contact_state_by_limb,
				contact_cycle_count_by_limb,
				rejected_short_contact_cycle_count_by_limb,
				maximum_cycle_relocation_by_limb_m,
				minimum_cycle_relocation_by_limb_m,
				contact_transition_receipts_by_limb,
				minimum_airborne_dwell_ticks,
				MINIMUM_FOOT_RELOCATION_M,
			)
			for limb_value in limbs:
				var limb: Dictionary = limb_value
				var limb_id := String(limb["limb_id"])
				var foot: RigidBody3D = limb["foot"]
				maximum_foot_center_height_by_limb_m[limb_id] = maxf(
					float(maximum_foot_center_height_by_limb_m[limb_id]), foot.global_position.y
				)
				if _foot_bears_floor(limb, floor):
					current_contact_absent_dwell_by_limb_ticks[limb_id] = 0
				else:
					contact_absent_tick_count_by_limb[limb_id] = (
						int(contact_absent_tick_count_by_limb[limb_id]) + 1
					)
					current_contact_absent_dwell_by_limb_ticks[limb_id] = (
						int(current_contact_absent_dwell_by_limb_ticks[limb_id]) + 1
					)
					longest_contact_absent_dwell_by_limb_ticks[limb_id] = maxi(
						int(longest_contact_absent_dwell_by_limb_ticks[limb_id]),
						int(current_contact_absent_dwell_by_limb_ticks[limb_id])
					)
		var torso_tilt_rad := _tilt_rad(torso)
		maximum_tilt_rad = maxf(maximum_tilt_rad, torso_tilt_rad)
		minimum_torso_height_m = minf(minimum_torso_height_m, torso.global_position.y)
		if _body_bears_floor(torso, "torso", floor):
			torso_contact_ticks += 1
			if first_torso_contact_tick < 0:
				first_torso_contact_tick = tick
		for limb_value in limbs:
			var limb: Dictionary = limb_value
			for state_value in limb["joint_states"]:
				var joint_state: Dictionary = state_value
				var geometry := _joint_geometry_receipt(state_value)
				var anchor_error_m := float(geometry["anchor_error_m"])
				if anchor_error_m > maximum_anchor_error_m:
					maximum_anchor_error_m = anchor_error_m
					maximum_anchor_error_joint_id = String(joint_state["joint_id"])
					maximum_anchor_error_tick = tick
					maximum_anchor_error_context = (
						latest_motor_command_context_by_joint_id
						. get(maximum_anchor_error_joint_id, {})
						. duplicate(true)
					)
				var hinge_axis_error_rad := float(geometry["hinge_axis_error_rad"])
				if hinge_axis_error_rad > maximum_hinge_axis_error_rad:
					maximum_hinge_axis_error_rad = hinge_axis_error_rad
					maximum_hinge_axis_error_joint_id = String(joint_state["joint_id"])
					maximum_hinge_axis_error_tick = tick
		if (
			dynamic_support_diagnostic_enabled
			and dynamic_support_sample_failure_code.is_empty()
			and tick >= settle_ticks - 1
		):
			var active_semantic_contact_ids: Array = []
			var support_point_by_semantic_contact_id: Dictionary = {}
			var floor_plane_height_m := (
				floor.global_position.y + 0.05 * float(fixture["fixture_view_scale"])
			)
			for contact_limb_id_value in DynamicSupportReceiptScript.ORDERED_CONTACT_IDS:
				var contact_limb_id := String(contact_limb_id_value)
				var contact_limb := _limb_by_id(limbs, contact_limb_id)
				if not contact_limb.is_empty() and _foot_bears_floor(contact_limb, floor):
					var contact_foot: RigidBody3D = contact_limb["foot"]
					active_semantic_contact_ids.append(contact_limb_id)
					support_point_by_semantic_contact_id[contact_limb_id] = Vector3(
						contact_foot.global_position.x,
						floor_plane_height_m,
						contact_foot.global_position.z,
					)
			var ordered_support_points_world: Array[Vector3] = []
			for polygon_contact_id_value in (
				DynamicSupportReceiptScript.ORDERED_SUPPORT_POLYGON_CONTACT_IDS
			):
				var polygon_contact_id := String(polygon_contact_id_value)
				if support_point_by_semantic_contact_id.has(polygon_contact_id):
					ordered_support_points_world.append(
						support_point_by_semantic_contact_id[polygon_contact_id]
					)
			var observer_result := (
				DynamicSupportObserverScript
				. observe(
					dynamic_support_body_by_id,
					ordered_support_points_world,
					float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)),
				)
			)
			var sample_result := (
				(
					DynamicSupportReceiptScript
					. compile_sample_gq15(
						tick,
						_dynamic_support_phase_id(
							tick,
							settle_ticks,
							evidence_start_tick,
							evidence_end_tick,
							cooldown_end_tick,
						),
						active_semantic_contact_ids,
						observer_result,
						(torso.global_position - initial_torso_position).dot(
							initial_lateral_axis_world
						),
					)
				)
				if (
					String(dynamic_support_options.get("receipt_schema_version", ""))
					== DynamicSupportReceiptScript.GQ15_SCHEMA_VERSION
				)
				else (
					(
						DynamicSupportReceiptScript
						. compile_sample_gq14(
							tick,
							_dynamic_support_phase_id(
								tick,
								settle_ticks,
								evidence_start_tick,
								evidence_end_tick,
								cooldown_end_tick,
							),
							active_semantic_contact_ids,
							observer_result,
							(torso.global_position - initial_torso_position).dot(
								initial_lateral_axis_world
							),
						)
					)
					if (
						String(dynamic_support_options.get("receipt_schema_version", ""))
						== DynamicSupportReceiptScript.GQ14_SCHEMA_VERSION
					)
					else (
						DynamicSupportReceiptScript
						. compile_sample(
							tick,
							_dynamic_support_phase_id(
								tick,
								settle_ticks,
								evidence_start_tick,
								evidence_end_tick,
								cooldown_end_tick,
							),
							active_semantic_contact_ids,
							observer_result,
							(torso.global_position - initial_torso_position).dot(
								initial_lateral_axis_world
							),
						)
					)
				)
			)
			if bool(sample_result.get("ok", false)):
				dynamic_support_trace.append(
					(sample_result["sample"] as Dictionary).duplicate(true)
				)
			else:
				dynamic_support_sample_failure_code = String(
					sample_result.get("failure_code", "DYNAMIC_SUPPORT_SAMPLE_UNKNOWN_FAILURE")
				)
		var run_end_tick := (
			cooldown_end_tick + terminal_settle_ticks if cooldown_end_tick >= 0 else -1
		)
		if tick % 120 == 0 or tick + 1 == run_end_tick:
			print(
				(
					(
						"    wave_tick=%d torso=%s tilt=%.6f contacts=%s cycles=%s "
						+ "joint_angles=%s foot_heights=%s "
						+ "motor_speed=%.6f anchor=%.6f hinge=%.6f"
					)
					% [
						tick,
						str(torso.global_position),
						torso_tilt_rad,
						str(_bearing_contact_by_limb(limbs, floor)),
						str(contact_cycle_count_by_limb),
						str(_joint_angles_by_limb(limbs)),
						str(_foot_heights_by_limb(limbs)),
						maximum_motor_target_speed_rad_s,
						maximum_anchor_error_m,
						maximum_hinge_axis_error_rad,
					]
				)
			)
		if not fixed_horizon_enabled and run_end_tick >= 0 and tick + 1 >= run_end_tick:
			break
	if not evidence_start_torso_position.is_finite():
		evidence_start_torso_position = initial_torso_position
	if not evidence_end_torso_position.is_finite():
		evidence_end_torso_position = torso.global_position
	terminal_all_four_contacts = _all_feet_bear_floor(limbs, floor)
	var contact_observer_callback_count_by_limb := _contact_observer_callback_count_by_limb(limbs)
	var every_contact_observer_executed := true
	for limb_id_value in LIMB_ORDER:
		every_contact_observer_executed = (
			every_contact_observer_executed
			and int(contact_observer_callback_count_by_limb[String(limb_id_value)]) > 0
		)
	var evidence_torso_displacement := evidence_end_torso_position - evidence_start_torso_position
	var final_torso_displacement := torso.global_position - evidence_start_torso_position
	var evidence_task_frame_forward_displacement_m := evidence_torso_displacement.dot(
		initial_forward_axis_world
	)
	var final_task_frame_forward_displacement_m := final_torso_displacement.dot(
		initial_forward_axis_world
	)
	var final_task_frame_lateral_displacement_m := final_torso_displacement.dot(
		initial_lateral_axis_world
	)
	var final_yaw_drift_rad := absf(_wrap_angle(_yaw_rad(torso) - initial_yaw_rad))
	var evidence_gait_advance_ticks_by_limb: Dictionary = {}
	var every_limb_completed_evidence_gait_horizon := true
	for limb_id_value in LIMB_ORDER:
		var gait_limb_id := String(limb_id_value)
		var gait_advance_ticks := (
			(
				int(evidence_end_gait_tick_by_limb[gait_limb_id])
				- int(evidence_start_gait_tick_by_limb[gait_limb_id])
			)
			if contact_gated_phase_progression
			else evidence_cycles * cycle_ticks
		)
		evidence_gait_advance_ticks_by_limb[gait_limb_id] = gait_advance_ticks
		every_limb_completed_evidence_gait_horizon = (
			every_limb_completed_evidence_gait_horizon
			and gait_advance_ticks == evidence_cycles * cycle_ticks
		)
	var every_limb_two_cycles := true
	var every_limb_relocated := true
	for limb_id_value in LIMB_ORDER:
		var limb_id := String(limb_id_value)
		every_limb_two_cycles = (
			every_limb_two_cycles and int(contact_cycle_count_by_limb[limb_id]) >= 2
		)
		every_limb_relocated = (
			every_limb_relocated
			and is_finite(float(minimum_cycle_relocation_by_limb_m[limb_id]))
			and (
				float(minimum_cycle_relocation_by_limb_m[limb_id])
				>= float(evidence_threshold_options["minimum_foot_relocation_m"])
			)
		)
	var sdk_adapter_execution_summary: Dictionary = {}
	var sdk_adapter_shutdown_receipt := {
		"schema_version": "sporespore_godot_jolt_adapter_shutdown_receipt_v1",
		"ok": not sdk_adapter_enabled,
		"failure_code": "",
		"explicit_shutdown_completed": not sdk_adapter_enabled,
		"native_controller_session_destroy_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	if sdk_adapter_enabled:
		sdk_adapter_execution_summary = sdk_adapter.summary()
		sdk_adapter_shutdown_receipt = sdk_adapter.shutdown()
		sdk_adapter = null
	var walking_gate_receipts := {
		"one_continuous_world": true,
		"no_world_reset": true,
		"fixture_spec_compiled_before_world_creation": true,
		"initial_perturbation_within_declared_envelope": true,
		"contact_gating_completed_without_timeout":
		_sum_dictionary_integers(contact_gate_timeout_count_by_limb) == 0,
		"contact_gated_evidence_horizon_completed": not contact_gated_evidence_horizon_timeout,
		"every_limb_completed_evidence_gait_horizon": every_limb_completed_evidence_gait_horizon,
		"pinned_jolt_solver_settings": solver_policy_realized,
		"no_torso_force_or_impulse_or_velocity_or_transform_command":
		(
			direct_torso_force_command_count == 0
			and direct_torso_impulse_command_count == 0
			and direct_torso_velocity_command_count == 0
			and direct_torso_transform_command_count == 0
		),
		"bounded_joint_only_lateral_stride_steering":
		(
			maximum_absolute_lateral_stride_steering_fraction
			<= MAXIMUM_LATERAL_STRIDE_STEERING_FRACTION
		),
		"initial_four_contact_stance": initial_all_four_contacts,
		"every_contact_observer_executed": every_contact_observer_executed,
		"every_limb_two_contact_cycles": every_limb_two_cycles,
		"every_limb_forward_relocation": every_limb_relocated,
		"minimum_evidence_forward_translation":
		(
			evidence_task_frame_forward_displacement_m
			>= float(evidence_threshold_options["minimum_evidence_torso_advance_m"])
		),
		"minimum_final_forward_translation":
		(
			final_task_frame_forward_displacement_m
			>= float(evidence_threshold_options["minimum_final_torso_advance_m"])
		),
		"bounded_lateral_drift":
		(
			absf(final_task_frame_lateral_displacement_m)
			<= float(evidence_threshold_options["maximum_lateral_drift_m"])
		),
		"bounded_yaw_drift":
		final_yaw_drift_rad <= float(evidence_threshold_options["maximum_yaw_drift_rad"]),
		"bounded_tilt": maximum_tilt_rad <= float(evidence_threshold_options["maximum_tilt_rad"]),
		"bounded_torso_height":
		minimum_torso_height_m >= float(evidence_threshold_options["minimum_torso_height_m"]),
		"zero_torso_contact": torso_contact_ticks == 0,
		"terminal_four_contact_recovery": terminal_all_four_contacts,
		"bounded_anchor_error":
		maximum_anchor_error_m <= float(evidence_threshold_options["maximum_anchor_error_m"]),
		"bounded_hinge_axis_error":
		(
			maximum_hinge_axis_error_rad
			<= float(evidence_threshold_options["maximum_hinge_axis_error_rad"])
		),
	}
	if evidence_support_acquisition_enabled:
		walking_gate_receipts["evidence_support_acquisition"] = (
			evidence_support_acquisition_passed and not evidence_support_acquisition_timed_out
		)
	else:
		walking_gate_receipts["evidence_four_contact_stance"] = (evidence_all_four_contacts_at_start)
	if sdk_adapter_enabled:
		walking_gate_receipts["explicit_sdk_controller_session_shutdown"] = (
			bool(sdk_adapter_shutdown_receipt.get("ok", false))
			and bool(sdk_adapter_shutdown_receipt.get("explicit_shutdown_completed", false))
			and int(
				sdk_adapter_shutdown_receipt.get(
					"native_controller_session_destroy_count",
					-1,
				)
			)
			== (
				1
				if bool(
					sdk_adapter_shutdown_receipt.get(
						"native_controller_session_required",
						false,
					)
				)
				else 0
			)
		)
	if sdk_authority_enabled:
		var sdk_authority_step_count := int(sdk_adapter_execution_summary.get("step_count", 0))
		var sdk_native_application_gate := (
			bool(sdk_adapter_start_result.get("ok", false))
			and bool(sdk_adapter_execution_summary.get("actuation_authority", false))
			and sdk_authority_failure_code.is_empty()
			and sdk_authority_step_count > 0
			and (
				int(
					(
						sdk_adapter_execution_summary
						. get(
							"native_actuation_application_count",
							-1,
						)
					)
				)
				== sdk_authority_step_count * 8
			)
		)
		if sdk_stability_overlay_enabled:
			var overlay_summary: Dictionary = (
				sdk_adapter_execution_summary
				. get(
					"stability_overlay_summary",
					{},
				)
			)
			walking_gate_receipts["sdk_stability_overlay_evidence_actuation"] = (
				sdk_native_application_gate
				and bool(
					(
						sdk_adapter_execution_summary
						. get(
							"stability_overlay_runtime_ok",
							false,
						)
					)
				)
				and sdk_authority_step_count == SDK_P5I3C_FIXED_EXPOSURE_STEP_COUNT
				and legacy_sdk_overlay_base_application_count == sdk_authority_step_count * 8
				and bool(overlay_summary.get("ok", false))
				and (
					int(overlay_summary.get("application_step_count", -1))
					== sdk_authority_step_count
				)
				and (
					int(overlay_summary.get("motor_write_count", -1))
					== sdk_authority_step_count * 8
				)
				and int(overlay_summary.get("failure_count", -1)) == 0
			)
		elif sdk_full_post_settle_authority_enabled:
			var native_sdk_exclusive_authority_gate := (
				sdk_native_application_gate
				and bool(sdk_adapter_execution_summary.get("ok", false))
				and legacy_evidence_actuation_application_count == 0
				and legacy_post_settle_actuation_application_count == 0
				and sdk_authority_step_count == executed_ticks - settle_ticks
			)
			walking_gate_receipts["native_sdk_exclusive_post_settle_actuation"] = (native_sdk_exclusive_authority_gate)
		else:
			walking_gate_receipts["native_sdk_exclusive_evidence_actuation"] = (
				sdk_native_application_gate
				and bool(sdk_adapter_execution_summary.get("ok", false))
				and legacy_evidence_actuation_application_count == 0
			)
	var walking_observed := true
	for receipt_value in walking_gate_receipts.values():
		walking_observed = walking_observed and bool(receipt_value)
	var dynamic_support_receipt_result := {
		"ok": not dynamic_support_diagnostic_enabled,
		"failure_code": "",
		"world_build_count": 0,
	}
	if dynamic_support_diagnostic_enabled:
		if not dynamic_support_sample_failure_code.is_empty():
			dynamic_support_receipt_result = {
				"ok": false,
				"failure_code": dynamic_support_sample_failure_code,
				"world_build_count": 0,
			}
		else:
			var dynamic_support_metadata := {
				"contact_progression_timeout": contact_gated_evidence_horizon_timeout,
				"evidence_extension_ticks": maxi(evidence_end_tick - nominal_evidence_end_tick, 0),
				"maximum_anchor_error_tick": maximum_anchor_error_tick,
				"final_support_contact_state": _bearing_contact_by_limb(limbs, floor),
				"lateral_limit_m": float(dynamic_support_options["lateral_limit_m"]),
				"source_digests":
				(dynamic_support_options["source_digests"] as Dictionary).duplicate(true),
			}
			dynamic_support_receipt_result = (
				(
					DynamicSupportReceiptScript
					. compile_gq15(
						dynamic_support_trace,
						dynamic_support_metadata,
					)
				)
				if (
					String(dynamic_support_options.get("receipt_schema_version", ""))
					== DynamicSupportReceiptScript.GQ15_SCHEMA_VERSION
				)
				else (
					(
						DynamicSupportReceiptScript
						. compile_gq14(
							dynamic_support_trace,
							dynamic_support_metadata,
						)
					)
					if (
						String(dynamic_support_options.get("receipt_schema_version", ""))
						== DynamicSupportReceiptScript.GQ14_SCHEMA_VERSION
					)
					else (
						DynamicSupportReceiptScript
						. compile(
							dynamic_support_trace,
							dynamic_support_metadata,
						)
					)
				)
			)
	var summary := {
		"ok": walking_observed,
		"failure_code": "" if walking_observed else "PHYSICAL_WAVE_GAIT_WALKING_NOT_ESTABLISHED",
		"schema_version": "physical_wave_gait_quadruped_development_summary_v1",
		"fixture_spec": fixture_spec.duplicate(true),
		"fixture_spec_sha256": fixture_spec_sha256,
		"fixture_view_scale": float(fixture["fixture_view_scale"]),
		"controller_configuration": controller_configuration.duplicate(true),
		"controller_configuration_sha256": controller_configuration_sha256,
		"evidence_threshold_options": evidence_threshold_options.duplicate(true),
		"evidence_threshold_configuration_sha256": evidence_threshold_configuration_sha256,
		"evidence_acquisition_options": evidence_acquisition_options.duplicate(true),
		"evidence_acquisition_configuration_sha256": evidence_acquisition_configuration_sha256,
		"solver_policy_options": solver_policy_options.duplicate(true),
		"realized_solver_policy_options": realized_solver_policy_options.duplicate(true),
		"solver_policy_configuration_sha256": solver_policy_configuration_sha256,
		"physics_hz": physics_hz,
		"physics_engine": physics_engine,
		"solver_velocity_steps": solver_velocity_steps,
		"solver_position_steps": solver_position_steps,
		"world_build_count": 1,
		"world_reset_count": 0,
		"motor_direction_sign": motor_direction_sign,
		"knee_motor_impulse_scale": knee_motor_impulse_scale,
		"knee_flexion_scale": knee_flexion_scale,
		"contact_clearance_assist_rad": contact_clearance_assist_rad,
		"contact_clearance_assist_limb_id": contact_clearance_assist_limb_id,
		"gait_phase_order_id": gait_phase_order_id,
		"gait_phase_order": gait_phase_order.duplicate(),
		"body_count": bodies.size(),
		"limb_count": limbs.size(),
		"executed_ticks": executed_ticks,
		"terminal_horizon_policy_id": (
			BW30N_FIXED_HORIZON_POLICY_ID if fixed_horizon_enabled else ""
		),
		"terminal_horizon_policy_sha256": (
			BW30N_FIXED_HORIZON_POLICY_SHA256 if fixed_horizon_enabled else ""
		),
		"post_sdk_observation_count": (
			executed_ticks - settle_ticks if fixed_horizon_enabled else 0
		),
		"first_post_sdk_observation_index": 0 if fixed_horizon_enabled else -1,
		"last_post_sdk_observation_index": (
			executed_ticks - settle_ticks - 1 if fixed_horizon_enabled else -1
		),
		"candidate_specific_horizon_extension_count": 0 if fixed_horizon_enabled else -1,
		"cycle_ticks": cycle_ticks,
		"swing_ticks": swing_ticks,
		"evidence_boundary_alignment_ticks": evidence_boundary_alignment_ticks,
		"gait_clock_options": gait_clock_options.duplicate(true),
		"initial_perturbation": initial_perturbation.duplicate(true),
		"robustness_options": robustness_options.duplicate(true),
		"path_steering_options": path_steering_options.duplicate(true),
		"actuator_impulse_options": actuator_impulse_options.duplicate(true),
		"motor_velocity_options": motor_velocity_options.duplicate(true),
		"realized_hip_max_impulse_nms": float(fixture["realized_hip_max_impulse_nms"]),
		"realized_knee_max_impulse_nms": float(fixture["realized_knee_max_impulse_nms"]),
		"nominal_evidence_end_tick": nominal_evidence_end_tick,
		"maximum_evidence_end_tick": maximum_evidence_end_tick,
		"evidence_extension_ticks": evidence_end_tick - nominal_evidence_end_tick,
		"evidence_start_gait_tick": evidence_start_gait_tick,
		"evidence_start_gait_tick_by_limb": evidence_start_gait_tick_by_limb.duplicate(true),
		"evidence_end_gait_tick":
		(
			evidence_end_gait_tick
			if contact_gated_phase_progression
			else evidence_start_gait_tick + evidence_cycles * cycle_ticks
		),
		"evidence_gait_advance_ticks":
		(
			evidence_end_gait_tick - evidence_start_gait_tick
			if contact_gated_phase_progression
			else evidence_cycles * cycle_ticks
		),
		"evidence_end_gait_tick_by_limb": evidence_end_gait_tick_by_limb.duplicate(true),
		"evidence_gait_advance_ticks_by_limb": evidence_gait_advance_ticks_by_limb.duplicate(true),
		"contact_gated_evidence_horizon_timeout": contact_gated_evidence_horizon_timeout,
		"contact_gate_hold_tick_count_by_limb":
		contact_gate_hold_tick_count_by_limb.duplicate(true),
		"contact_gate_release_hold_tick_count_by_limb":
		contact_gate_release_hold_tick_count_by_limb.duplicate(true),
		"contact_gate_recontact_hold_tick_count_by_limb":
		contact_gate_recontact_hold_tick_count_by_limb.duplicate(true),
		"contact_gate_timeout_count_by_limb": contact_gate_timeout_count_by_limb.duplicate(true),
		"contact_gate_timeout_receipts_by_limb":
		contact_gate_timeout_receipts_by_limb.duplicate(true),
		"contact_gate_phase_sync_hold_tick_count_by_limb":
		contact_gate_phase_sync_hold_tick_count_by_limb.duplicate(true),
		"initial_linear_velocity_body_initialization_count":
		int(fixture["initial_linear_velocity_body_initialization_count"]),
		"initial_torso_angular_velocity_initialization_count":
		int(fixture["initial_torso_angular_velocity_initialization_count"]),
		"evidence_start_tick": evidence_start_tick,
		"evidence_end_tick": evidence_end_tick,
		"contact_cycle_count_by_limb": contact_cycle_count_by_limb.duplicate(true),
		"rejected_short_contact_cycle_count_by_limb":
		rejected_short_contact_cycle_count_by_limb.duplicate(true),
		"maximum_cycle_relocation_by_limb_m": maximum_cycle_relocation_by_limb_m.duplicate(true),
		"minimum_cycle_relocation_by_limb_m": minimum_cycle_relocation_by_limb_m.duplicate(true),
		"maximum_foot_center_height_by_limb_m":
		maximum_foot_center_height_by_limb_m.duplicate(true),
		"contact_absent_tick_count_by_limb": contact_absent_tick_count_by_limb.duplicate(true),
		"longest_contact_absent_dwell_by_limb_ticks":
		longest_contact_absent_dwell_by_limb_ticks.duplicate(true),
		"contact_transition_receipts_by_limb": contact_transition_receipts_by_limb.duplicate(true),
		"contact_clearance_assist_tick_count_by_limb":
		contact_clearance_assist_tick_count_by_limb.duplicate(true),
		"initial_torso_position_world_m": initial_torso_position,
		"initial_torso_orientation_xyzw":
		{
			"x": initial_torso_orientation.x,
			"y": initial_torso_orientation.y,
			"z": initial_torso_orientation.z,
			"w": initial_torso_orientation.w,
		},
		"evidence_start_torso_position_world_m": evidence_start_torso_position,
		"evidence_end_torso_position_world_m": evidence_end_torso_position,
		"final_torso_position_world_m": torso.global_position,
		"final_torso_orientation_xyzw":
		{
			"x": torso.global_basis.get_rotation_quaternion().normalized().x,
			"y": torso.global_basis.get_rotation_quaternion().normalized().y,
			"z": torso.global_basis.get_rotation_quaternion().normalized().z,
			"w": torso.global_basis.get_rotation_quaternion().normalized().w,
		},
		"evidence_torso_displacement_world_m": evidence_torso_displacement,
		"final_torso_displacement_world_m": final_torso_displacement,
		"evidence_task_frame_forward_displacement_m": evidence_task_frame_forward_displacement_m,
		"final_task_frame_forward_displacement_m": final_task_frame_forward_displacement_m,
		"final_task_frame_lateral_displacement_m": final_task_frame_lateral_displacement_m,
		"task_frame_forward_axis_world_unit": initial_forward_axis_world,
		"task_frame_lateral_axis_world_unit": initial_lateral_axis_world,
		"final_yaw_drift_rad": final_yaw_drift_rad,
		"maximum_tilt_rad": maximum_tilt_rad,
		"minimum_torso_height_m": minimum_torso_height_m,
		"final_torso_height_m": torso.global_position.y,
		"torso_contact_ticks": torso_contact_ticks,
		"first_torso_contact_tick": first_torso_contact_tick,
		"initial_all_four_contacts": initial_all_four_contacts,
		"evidence_all_four_contacts_at_start": evidence_all_four_contacts_at_start,
		"evidence_start_bearing_contact_by_limb":
		evidence_start_bearing_contact_by_limb.duplicate(true),
		"evidence_boundary_contact_trace": evidence_boundary_contact_trace.duplicate(true),
		"evidence_support_acquisition_receipt":
		{
			"schema_version": "sporespore_evidence_support_acquisition_receipt_v1",
			"policy_id": String(evidence_acquisition_options["policy_id"]),
			"enabled": evidence_support_acquisition_enabled,
			"nominal_evidence_start_tick": evidence_start_tick,
			"maximum_acquisition_ticks": maximum_evidence_support_acquisition_ticks,
			"minimum_all_support_dwell_ticks": minimum_all_support_acquisition_dwell_ticks,
			"acquired": evidence_support_acquisition_passed,
			"acquisition_tick": evidence_support_acquisition_tick,
			"acquisition_tick_from_nominal_start":
			(
				evidence_support_acquisition_tick - evidence_start_tick
				if evidence_support_acquisition_tick >= 0
				else -1
			),
			"timed_out": evidence_support_acquisition_timed_out,
			"controller_parameter": false,
			"walking_claim_authorized": false,
		},
		"evidence_support_acquisition_trace": evidence_support_acquisition_trace.duplicate(true),
		"terminal_all_four_contacts": terminal_all_four_contacts,
		"terminal_bearing_contact_by_limb": _bearing_contact_by_limb(limbs, floor),
		"contact_observer_callback_count_by_limb": contact_observer_callback_count_by_limb,
		"motor_command_count": motor_command_count,
		"legacy_evidence_actuation_application_count": legacy_evidence_actuation_application_count,
		"legacy_post_settle_actuation_application_count":
		legacy_post_settle_actuation_application_count,
		"legacy_sdk_overlay_base_application_count": legacy_sdk_overlay_base_application_count,
		"sdk_execution_mode_plan": sdk_execution_mode_plan.duplicate(true),
		"sdk_p5i3c_fixed_exposure_enabled": sdk_p5i3c_fixed_exposure_enabled,
		"sdk_p5i3c_fixed_exposure_step_count":
		SDK_P5I3C_FIXED_EXPOSURE_STEP_COUNT if sdk_p5i3c_fixed_exposure_enabled else 0,
		"maximum_motor_target_speed_rad_s": maximum_motor_target_speed_rad_s,
		"maximum_motor_target_speed_by_joint_role_rad_s":
		maximum_motor_target_speed_by_joint_role_rad_s.duplicate(true),
		"contact_loaded_swing_knee_speed_cap_activation_count":
		contact_loaded_swing_knee_speed_cap_activation_count,
		"maximum_contact_loaded_swing_knee_target_speed_rad_s":
		maximum_contact_loaded_swing_knee_target_speed_rad_s,
		"anchor_error_guard_activation_count": anchor_error_guard_activation_count,
		"maximum_anchor_error_guard_input_m": maximum_anchor_error_guard_input_m,
		"maximum_anchor_error_guard_progress": maximum_anchor_error_guard_progress,
		"minimum_anchor_error_guard_speed_limit_rad_s":
		(
			minimum_anchor_error_guard_speed_limit_rad_s
			if is_finite(minimum_anchor_error_guard_speed_limit_rad_s)
			else controller_maximum_motor_target_speed_rad_s
		),
		"maximum_anchor_error_guarded_target_speed_rad_s":
		maximum_anchor_error_guarded_target_speed_rad_s,
		"maximum_measured_joint_speed_rad_s": maximum_measured_joint_speed_rad_s,
		"maximum_anchor_error_m": maximum_anchor_error_m,
		"maximum_anchor_error_joint_id": maximum_anchor_error_joint_id,
		"maximum_anchor_error_tick": maximum_anchor_error_tick,
		"maximum_anchor_error_context": maximum_anchor_error_context.duplicate(true),
		"maximum_hinge_axis_error_rad": maximum_hinge_axis_error_rad,
		"maximum_hinge_axis_error_joint_id": maximum_hinge_axis_error_joint_id,
		"maximum_hinge_axis_error_tick": maximum_hinge_axis_error_tick,
		"direct_torso_force_command_count": direct_torso_force_command_count,
		"direct_torso_impulse_command_count": direct_torso_impulse_command_count,
		"direct_torso_velocity_command_count": direct_torso_velocity_command_count,
		"direct_torso_transform_command_count": direct_torso_transform_command_count,
		"environment_challenge_options": environment_challenge_options.duplicate(true),
		"environment_challenge_configuration_sha256": environment_challenge_configuration_sha256,
		"terrain_profile_id": String(environment_challenge_options["terrain_profile_id"]),
		"terrain_shape_count": int(fixture["terrain_shape_count"]),
		"external_push_application_count": external_push_application_count,
		"external_push_receipt": external_push_receipt.duplicate(true),
		"observation_fault_application_count": observation_fault_application_count,
		"observation_fault_base_and_stability_count": observation_fault_base_and_stability_count,
		"maximum_observation_fault_component": maximum_observation_fault_component,
		"lateral_stride_steering_target_adjustment_count":
		lateral_stride_steering_target_adjustment_count,
		"maximum_absolute_lateral_stride_steering_fraction":
		maximum_absolute_lateral_stride_steering_fraction,
		"path_steering_update_receipts": path_steering_update_receipts.duplicate(true),
		"maximum_absolute_path_cross_track_error_m": maximum_absolute_path_cross_track_error_m,
		"maximum_absolute_path_yaw_tracking_error_rad":
		maximum_absolute_path_yaw_tracking_error_rad,
		"walking_gate_receipts": walking_gate_receipts,
		"physical_wave_gait_walking_observed": walking_observed,
		"formal_milestone_acceptance_authorized": false,
		"encyclopedia_admission_authorized": false,
		"automatic_creature_guidance_allowed": false,
	}
	if dynamic_support_diagnostic_enabled:
		summary["dynamic_support_diagnostic_enabled"] = true
		summary["dynamic_support_diagnostic_ok"] = bool(
			dynamic_support_receipt_result.get("ok", false)
		)
		summary["dynamic_support_diagnostic_failure_code"] = String(
			dynamic_support_receipt_result.get("failure_code", "")
		)
		summary["dynamic_support_trace_sample_count"] = dynamic_support_trace.size()
		summary["dynamic_support_receipt"] = (
			(dynamic_support_receipt_result.get("dynamic_support_receipt", {}) as Dictionary)
			. duplicate(true)
		)
		summary["dynamic_support_receipt_sha256"] = String(
			dynamic_support_receipt_result.get("dynamic_support_receipt_sha256", "")
		)
	if sdk_adapter_enabled:
		summary["sdk_material_profile"] = sdk_material_profile.duplicate(true)
		summary["sdk_material_profile_sha256"] = sdk_material_profile_sha256
		summary["sdk_transport_execution_receipt"] = (
			sdk_transport_execution_receipt.duplicate(true)
		)
		summary["sdk_adapter_shutdown_receipt"] = (
			sdk_adapter_shutdown_receipt.duplicate(true)
		)
	if sdk_shadow_enabled:
		summary["sdk_shadow_enabled"] = true
		summary["sdk_shadow_options"] = sdk_shadow_options.duplicate(true)
		summary["sdk_shadow_start_result"] = sdk_adapter_start_result.duplicate(true)
		summary["sdk_shadow_summary"] = sdk_adapter_execution_summary.duplicate(true)
	if sdk_authority_enabled:
		summary["sdk_authority_enabled"] = true
		summary["sdk_authority_scope"] = sdk_authority_scope
		summary["sdk_full_authority_stability_contribution_enabled"] = (
			sdk_full_authority_stability_contribution_enabled
		)
		summary["sdk_adapter_start_tick"] = sdk_adapter_start_tick
		summary["sdk_phase_offset_activation_tick"] = sdk_phase_offset_activation_tick
		summary["sdk_authority_options"] = sdk_authority_options.duplicate(true)
		summary["sdk_authority_start_result"] = sdk_adapter_start_result.duplicate(true)
		summary["sdk_authority_failure_code"] = sdk_authority_failure_code
		summary["sdk_authority_last_application_result"] = (
			sdk_authority_last_application_result.duplicate(true)
		)
		summary["sdk_authority_summary"] = sdk_adapter_execution_summary.duplicate(true)
	cleanup_node.queue_free()
	await tree.physics_frame
	await tree.process_frame
	Engine.physics_ticks_per_second = original_hz
	return summary


static func _normalize_sdk_shadow_options(requested: Dictionary) -> Dictionary:
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"sdk_shadow_options":
			{
				"enabled": false,
				"descriptor": {},
				"comparison_tolerance": 1.0e-9,
				"stability_policy_id": SDK_P5I3B_STABILITY_POLICY_ID,
			},
			"world_build_count": 0,
		}
	var uses_extended_options := _has_exact_keys(
		requested,
		SDK_SHADOW_EXTENDED_OPTION_KEYS,
	)
	var uses_material_options := _has_exact_keys(
		requested,
		SDK_SHADOW_MATERIAL_OPTION_KEYS,
	)
	var uses_controller_options := _has_exact_keys(
		requested,
		SDK_SHADOW_CONTROLLER_OPTION_KEYS,
	)
	var uses_controller_material_options := _has_exact_keys(
		requested,
		SDK_SHADOW_CONTROLLER_MATERIAL_OPTION_KEYS,
	)
	if (
		not uses_controller_material_options
		and not uses_controller_options
		and not uses_material_options
		and not uses_extended_options
		and not _has_exact_keys(requested, SDK_SHADOW_OPTION_KEYS)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_SHADOW_OPTION_KEYS",
			"world_build_count": 0,
		}
	var enabled_value: Variant = requested["enabled"]
	var descriptor_value: Variant = requested["descriptor"]
	var tolerance_value: Variant = requested["comparison_tolerance"]
	var stability_policy_value: Variant = (
		requested
		. get(
			"stability_policy_id",
			SDK_P5I3B_STABILITY_POLICY_ID,
		)
	)
	var material_profile_value: Variant = (
		requested
		. get(
			"material_profile_id",
			SdkGodotJoltMaterialProfilesScript.LEGACY_PROFILE_ID,
		)
	)
	var controller_policy_value: Variant = (
		requested
		. get(
			"controller_policy_id",
			SDK_CANDIDATE35_POLICY_ID,
		)
	)
	if (
		typeof(enabled_value) != TYPE_BOOL
		or typeof(descriptor_value) != TYPE_DICTIONARY
		or typeof(stability_policy_value) != TYPE_STRING
		or typeof(material_profile_value) != TYPE_STRING
		or typeof(controller_policy_value) != TYPE_STRING
		or (typeof(tolerance_value) != TYPE_FLOAT and typeof(tolerance_value) != TYPE_INT)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_SHADOW_OPTION_TYPE",
			"world_build_count": 0,
		}
	var tolerance := float(tolerance_value)
	if (
		not bool(enabled_value)
		or (descriptor_value as Dictionary).is_empty()
		or not is_finite(tolerance)
		or tolerance < 0.0
		or tolerance > 1.0e-6
		or not (
			[
				SDK_P5I3B_STABILITY_POLICY_ID,
				SDK_P5I3C_STABILITY_POLICY_ID,
				SDK_BW9L_A_STABILITY_POLICY_ID,
				SDK_BW9L_B_STABILITY_POLICY_ID,
				SDK_BW9L_C_STABILITY_POLICY_ID,
				SDK_BW9L_D_STABILITY_POLICY_ID,
				SDK_BW10F_A_STABILITY_POLICY_ID,
				SDK_BW10F_B_STABILITY_POLICY_ID,
				SDK_BW10F_C_STABILITY_POLICY_ID,
				SDK_BW10F_D_STABILITY_POLICY_ID,
				SDK_BW11R_A_STABILITY_POLICY_ID,
				SDK_BW11R_B_STABILITY_POLICY_ID,
				SDK_BW11R_C_STABILITY_POLICY_ID,
				SDK_BW11R_D_STABILITY_POLICY_ID,
				SDK_BW13P_A_STABILITY_POLICY_ID,
				SDK_BW13P_B_STABILITY_POLICY_ID,
				SDK_BW13P_C_STABILITY_POLICY_ID,
				SDK_BW13P_D_STABILITY_POLICY_ID,
			]
			. has(String(stability_policy_value))
		)
		or not (
			[
				SDK_CANDIDATE35_POLICY_ID,
				SDK_BALANCED_WAVE_POLICY_ID,
				SDK_BALANCED_WAVE_BW2_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW2_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW2R_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW2R_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW2R_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW4R_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW4R_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW5R_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW5R_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW5R_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW14V_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW15F_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW15F_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW15F_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW21L_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW21L_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW21L_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW23Y_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW34Y_A_POLICY_ID,
			]
			. has(String(controller_policy_value))
		)
		or String(material_profile_value).is_empty()
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_SHADOW_OPTION_VALUE",
			"world_build_count": 0,
		}
	var normalized_options := {
		"enabled": true,
		"descriptor": (descriptor_value as Dictionary).duplicate(true),
		"comparison_tolerance": tolerance,
		"stability_policy_id": String(stability_policy_value),
	}
	if uses_controller_options or uses_controller_material_options:
		normalized_options["controller_policy_id"] = String(controller_policy_value)
	if uses_material_options or uses_controller_material_options:
		normalized_options["material_profile_id"] = String(material_profile_value)
	return {
		"ok": true,
		"failure_code": "",
		"sdk_shadow_options": normalized_options,
		"world_build_count": 0,
	}


static func _normalize_sdk_authority_options(requested: Dictionary) -> Dictionary:
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"sdk_authority_options":
			{
				"enabled": false,
				"descriptor": {},
				"comparison_tolerance": 1.0e-9,
				"authority_scope": "evidence_handoff",
				"stability_policy_id": SDK_P5I3B_STABILITY_POLICY_ID,
			},
			"world_build_count": 0,
		}
	var uses_extended_options := _has_exact_keys(
		requested,
		SDK_AUTHORITY_EXTENDED_OPTION_KEYS,
	)
	var uses_material_options := _has_exact_keys(
		requested,
		SDK_AUTHORITY_MATERIAL_OPTION_KEYS,
	)
	var uses_controller_options := _has_exact_keys(
		requested,
		SDK_AUTHORITY_CONTROLLER_OPTION_KEYS,
	)
	var uses_controller_material_options := _has_exact_keys(
		requested,
		SDK_AUTHORITY_CONTROLLER_MATERIAL_OPTION_KEYS,
	)
	var uses_controller_material_scale_options := _has_exact_keys(
		requested,
		SDK_AUTHORITY_CONTROLLER_MATERIAL_SCALE_OPTION_KEYS,
	)
	if (
		not uses_controller_material_scale_options
		and not uses_controller_material_options
		and not uses_controller_options
		and not uses_material_options
		and not uses_extended_options
		and not _has_exact_keys(requested, SDK_AUTHORITY_OPTION_KEYS)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_AUTHORITY_OPTION_KEYS",
			"world_build_count": 0,
		}
	var enabled_value: Variant = requested["enabled"]
	var descriptor_value: Variant = requested["descriptor"]
	var tolerance_value: Variant = requested["comparison_tolerance"]
	var authority_scope_value: Variant = requested["authority_scope"]
	var stability_policy_value: Variant = (
		requested
		. get(
			"stability_policy_id",
			SDK_P5I3B_STABILITY_POLICY_ID,
		)
	)
	var material_profile_value: Variant = (
		requested
		. get(
			"material_profile_id",
			SdkGodotJoltMaterialProfilesScript.LEGACY_PROFILE_ID,
		)
	)
	var controller_policy_value: Variant = (
		requested
		. get(
			"controller_policy_id",
			SDK_CANDIDATE35_POLICY_ID,
		)
	)
	var stability_influence_global_scale_value: Variant = (
		requested.get("stability_influence_global_scale", -1.0)
	)
	if (
		typeof(enabled_value) != TYPE_BOOL
		or typeof(descriptor_value) != TYPE_DICTIONARY
		or typeof(authority_scope_value) != TYPE_STRING
		or typeof(stability_policy_value) != TYPE_STRING
		or typeof(material_profile_value) != TYPE_STRING
		or typeof(controller_policy_value) != TYPE_STRING
		or (
			typeof(stability_influence_global_scale_value) != TYPE_FLOAT
			and typeof(stability_influence_global_scale_value) != TYPE_INT
		)
		or (typeof(tolerance_value) != TYPE_FLOAT and typeof(tolerance_value) != TYPE_INT)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_AUTHORITY_OPTION_TYPE",
			"world_build_count": 0,
		}
	var tolerance := float(tolerance_value)
	var stability_influence_global_scale := float(
		stability_influence_global_scale_value
	)
	if (
		not bool(enabled_value)
		or (descriptor_value as Dictionary).is_empty()
		or not is_finite(tolerance)
		or tolerance < 0.0
		or tolerance > 1.0e-6
		or not (
			[
				"evidence_handoff",
				"post_settle_full",
				"stability_contribution_overlay",
			]
			. has(String(authority_scope_value))
		)
		or not (
			[
				SDK_P5I3B_STABILITY_POLICY_ID,
				SDK_P5I3C_STABILITY_POLICY_ID,
				SDK_BW9L_A_STABILITY_POLICY_ID,
				SDK_BW9L_B_STABILITY_POLICY_ID,
				SDK_BW9L_C_STABILITY_POLICY_ID,
				SDK_BW9L_D_STABILITY_POLICY_ID,
				SDK_BW10F_A_STABILITY_POLICY_ID,
				SDK_BW10F_B_STABILITY_POLICY_ID,
				SDK_BW10F_C_STABILITY_POLICY_ID,
				SDK_BW10F_D_STABILITY_POLICY_ID,
				SDK_BW11R_A_STABILITY_POLICY_ID,
				SDK_BW11R_B_STABILITY_POLICY_ID,
				SDK_BW11R_C_STABILITY_POLICY_ID,
				SDK_BW11R_D_STABILITY_POLICY_ID,
				SDK_BW13P_A_STABILITY_POLICY_ID,
				SDK_BW13P_B_STABILITY_POLICY_ID,
				SDK_BW13P_C_STABILITY_POLICY_ID,
				SDK_BW13P_D_STABILITY_POLICY_ID,
			]
			. has(String(stability_policy_value))
		)
		or (
			String(authority_scope_value) == "stability_contribution_overlay"
			and not SDK_STABILITY_FEEDBACK_AUTHORITY_POLICY_IDS.has(String(stability_policy_value))
		)
		or not (
			[
				SDK_CANDIDATE35_POLICY_ID,
				SDK_BALANCED_WAVE_POLICY_ID,
				SDK_BALANCED_WAVE_BW2_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW2_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW2R_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW2R_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW2R_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW4R_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW4R_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW5R_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW5R_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW5R_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW7D_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_A_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW8U_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW14V_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW15F_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW15F_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW15F_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW21L_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW21L_C_POLICY_ID,
				SDK_BALANCED_WAVE_BW21L_D_POLICY_ID,
				SDK_BALANCED_WAVE_BW23Y_B_POLICY_ID,
				SDK_BALANCED_WAVE_BW34Y_A_POLICY_ID,
			]
			. has(String(controller_policy_value))
		)
		or String(material_profile_value).is_empty()
		or not is_finite(stability_influence_global_scale)
		or (
			uses_controller_material_scale_options
			and (
				stability_influence_global_scale < 0.0
				or stability_influence_global_scale > 1.0
				or String(authority_scope_value) != "post_settle_full"
				or not SDK_BW13P_STABILITY_POLICY_IDS.has(
					String(stability_policy_value)
				)
			)
		)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SDK_AUTHORITY_OPTION_VALUE",
			"world_build_count": 0,
		}
	var normalized_options := {
		"enabled": true,
		"descriptor": (descriptor_value as Dictionary).duplicate(true),
		"comparison_tolerance": tolerance,
		"authority_scope": String(authority_scope_value),
		"stability_policy_id": String(stability_policy_value),
	}
	if (
		uses_controller_options
		or uses_controller_material_options
		or uses_controller_material_scale_options
	):
		normalized_options["controller_policy_id"] = String(controller_policy_value)
	if (
		uses_material_options
		or uses_controller_material_options
		or uses_controller_material_scale_options
	):
		normalized_options["material_profile_id"] = String(material_profile_value)
	if uses_controller_material_scale_options:
		normalized_options["stability_influence_global_scale"] = (
			stability_influence_global_scale
		)
	return {
		"ok": true,
		"failure_code": "",
		"sdk_authority_options": normalized_options,
		"world_build_count": 0,
	}


static func _sdk_shadow_configuration_failure(
	motor_direction_sign: float,
	knee_flexion_scale: float,
	gait_phase_order_id: String,
	swing_ticks: int,
	contact_clearance_assist_rad: float,
	contact_clearance_assist_limb_id: String,
	initial_perturbation: Dictionary,
	robustness_options: Dictionary,
	path_steering_options: Dictionary,
	gait_clock_options: Dictionary,
	sdk_full_post_settle_authority_enabled: bool,
	sdk_p5i3c_fixed_exposure_enabled: bool,
) -> String:
	if (
		not is_equal_approx(motor_direction_sign, -1.0)
		or not is_equal_approx(knee_flexion_scale, 1.75)
		or gait_phase_order_id != "lateral"
		or swing_ticks != 72
		or not is_equal_approx(contact_clearance_assist_rad, 0.40)
		or contact_clearance_assist_limb_id != "all"
	):
		return "SDK_SHADOW_UNSUPPORTED_CONTROLLER_CONFIGURATION"
	if (
		int(initial_perturbation.get("gait_phase_offset_ticks", 0)) != 0
		and not (sdk_full_post_settle_authority_enabled or sdk_p5i3c_fixed_exposure_enabled)
	):
		return "SDK_SHADOW_PHASE_OFFSET_NOT_YET_SUPPORTED"
	if (
		not bool(robustness_options.get("contact_gated_phase_progression", false))
		or int(robustness_options.get("maximum_contact_gate_hold_ticks", -1)) != 120
		or int(robustness_options.get("maximum_contact_gated_phase_skew_ticks", -1)) != 12
		or not is_zero_approx(
			float(robustness_options.get("lateral_stride_steering_gain_per_m", NAN))
		)
	):
		return "SDK_SHADOW_UNSUPPORTED_CONTACT_CLOCK"
	if (
		not bool(path_steering_options.get("phase_bounded_path_steering_enabled", false))
		or not is_equal_approx(
			float(path_steering_options.get("maximum_desired_heading_error_rad", NAN)),
			0.25,
		)
		or not is_equal_approx(
			float(path_steering_options.get("maximum_steering_fraction", NAN)),
			0.40,
		)
		or int(path_steering_options.get("steering_update_interval_ticks", -1)) != 90
	):
		return "SDK_SHADOW_UNSUPPORTED_STEERING_CLOCK"
	if (
		int(gait_clock_options.get("physics_hz", -1)) != 120
		or int(gait_clock_options.get("cycle_ticks", -1)) != 360
		or int(gait_clock_options.get("swing_ticks", -1)) != 72
		or int(gait_clock_options.get("minimum_airborne_dwell_ticks", -1)) != 3
		or not is_equal_approx(
			float(gait_clock_options.get("motor_position_gain_per_s", NAN)),
			8.0,
		)
		or not is_equal_approx(
			float(gait_clock_options.get("motor_rate_damping", NAN)),
			0.65,
		)
		or not is_equal_approx(
			float(gait_clock_options.get("maximum_motor_target_speed_rad_s", NAN)),
			3.5,
		)
	):
		return "SDK_SHADOW_UNSUPPORTED_GAIT_CLOCK"
	return ""


static func _normalize_dynamic_support_diagnostic_options(requested: Dictionary) -> Dictionary:
	if requested.is_empty():
		return {
			"ok": true,
			"dynamic_support_diagnostic_options":
			{
				"enabled": false,
				"lateral_limit_m": 1.0,
				"source_digests": {},
				"receipt_schema_version": "",
				"policy_id": "",
				"sample_schema_version": "",
			},
			"world_build_count": 0,
		}
	var is_versioned_profile := _has_exact_keys(
		requested,
		DYNAMIC_SUPPORT_DIAGNOSTIC_VERSIONED_OPTION_KEYS,
	)
	if (
		not is_versioned_profile
		and not _has_exact_keys(requested, DYNAMIC_SUPPORT_DIAGNOSTIC_OPTION_KEYS)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_DYNAMIC_SUPPORT_DIAGNOSTIC_OPTION_KEYS",
			"world_build_count": 0,
		}
	if (
		is_versioned_profile
		and (not (
			(
				(
					String(requested.get("receipt_schema_version", ""))
					== DynamicSupportReceiptScript.GQ14_SCHEMA_VERSION
				)
				and (
					String(requested.get("policy_id", ""))
					== DynamicSupportReceiptScript.GQ14_POLICY_ID
				)
				and (
					String(requested.get("sample_schema_version", ""))
					== DynamicSupportReceiptScript.GQ14_SAMPLE_SCHEMA_VERSION
				)
			)
			or (
				(
					String(requested.get("receipt_schema_version", ""))
					== DynamicSupportReceiptScript.GQ15_SCHEMA_VERSION
				)
				and (
					String(requested.get("policy_id", ""))
					== DynamicSupportReceiptScript.GQ15_POLICY_ID
				)
				and (
					String(requested.get("sample_schema_version", ""))
					== DynamicSupportReceiptScript.GQ15_SAMPLE_SCHEMA_VERSION
				)
			)
		))
	):
		return {
			"ok": false,
			"failure_code": "INVALID_DYNAMIC_SUPPORT_DIAGNOSTIC_PROFILE_IDENTITY",
			"world_build_count": 0,
		}
	if typeof(requested["enabled"]) != TYPE_BOOL or not bool(requested["enabled"]):
		return {
			"ok": false,
			"failure_code": "DYNAMIC_SUPPORT_DIAGNOSTIC_MUST_BE_ENABLED",
			"world_build_count": 0,
		}
	var lateral_limit_value: Variant = requested["lateral_limit_m"]
	if (
		(typeof(lateral_limit_value) != TYPE_FLOAT and typeof(lateral_limit_value) != TYPE_INT)
		or not is_finite(float(lateral_limit_value))
		or float(lateral_limit_value) <= 0.0
	):
		return {
			"ok": false,
			"failure_code": "INVALID_DYNAMIC_SUPPORT_LATERAL_LIMIT",
			"world_build_count": 0,
		}
	if not requested["source_digests"] is Dictionary:
		return {
			"ok": false,
			"failure_code": "INVALID_DYNAMIC_SUPPORT_SOURCE_DIGESTS",
			"world_build_count": 0,
		}
	var source_digests: Dictionary = requested["source_digests"]
	if source_digests.is_empty():
		return {
			"ok": false,
			"failure_code": "EMPTY_DYNAMIC_SUPPORT_SOURCE_DIGESTS",
			"world_build_count": 0,
		}
	for digest_value in source_digests.values():
		if (
			typeof(digest_value) != TYPE_STRING
			or not String(digest_value).begins_with("sha256:")
			or String(digest_value).length() != 71
		):
			return {
				"ok": false,
				"failure_code": "INVALID_DYNAMIC_SUPPORT_SOURCE_DIGEST",
				"world_build_count": 0,
			}
	return {
		"ok": true,
		"dynamic_support_diagnostic_options":
		{
			"enabled": true,
			"lateral_limit_m": float(lateral_limit_value),
			"source_digests": source_digests.duplicate(true),
			"receipt_schema_version": String(requested.get("receipt_schema_version", "")),
			"policy_id": String(requested.get("policy_id", "")),
			"sample_schema_version": String(requested.get("sample_schema_version", "")),
		},
		"world_build_count": 0,
	}


static func _dynamic_support_phase_id(
	tick: int,
	settle_ticks: int,
	evidence_start_tick: int,
	evidence_end_tick: int,
	cooldown_end_tick: int,
) -> String:
	if tick == settle_ticks - 1:
		return "SETTLE_BOUNDARY"
	if tick < evidence_start_tick:
		return "WARMUP"
	if evidence_end_tick < 0 or tick < evidence_end_tick:
		return "EVIDENCE"
	if cooldown_end_tick < 0 or tick < cooldown_end_tick:
		return "COOLDOWN"
	return "TERMINAL_SETTLE"


static func _limb_by_id(limbs: Array, limb_id: String) -> Dictionary:
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		if String(limb.get("limb_id", "")) == limb_id:
			return limb
	return {}


static func _has_exact_keys(source: Dictionary, expected: Array) -> bool:
	if source.size() != expected.size():
		return false
	for key in expected:
		if not source.has(key):
			return false
	return true


static func _sdk_initial_gait_steps(
	base_gait_step_by_limb: Dictionary,
	phase_offset_ticks: int,
	fixed_exposure_enabled: bool,
) -> Dictionary:
	var result := base_gait_step_by_limb.duplicate(true)
	if fixed_exposure_enabled:
		for limb_id_value in LIMB_ORDER:
			var limb_id := String(limb_id_value)
			result[limb_id] = int(result[limb_id]) + phase_offset_ticks
	return result


## Resolves the same mutually exclusive SDK route used by the physical loop.
## This function is public so zero-world launch gates can test production
## control-flow identity instead of reconstructing the booleans independently.
static func compile_sdk_execution_mode_plan(
	sdk_adapter_enabled: bool,
	sdk_authority_enabled: bool,
	sdk_authority_scope: String,
	stability_policy_id: String,
	phase_offset_ticks: int,
) -> Dictionary:
	if (
		absi(phase_offset_ticks) > MAXIMUM_INITIAL_GAIT_PHASE_OFFSET_TICKS
		or (
			sdk_authority_enabled
			and not [
				"evidence_handoff",
				"post_settle_full",
				"stability_contribution_overlay",
			].has(sdk_authority_scope)
		)
	):
		return {
			"schema_version": "sporespore_sdk_execution_mode_plan_v1",
			"ok": false,
			"failure_code": "SDK_EXECUTION_MODE_PLAN_INPUT_INVALID",
			"actual_world_build_count": 0,
			"physics_state_modified": false,
			"physical_acceptance_authority": false,
		}
	var full_post_settle := (
		sdk_adapter_enabled
		and sdk_authority_enabled
		and sdk_authority_scope == "post_settle_full"
	)
	var contribution_overlay := (
		sdk_adapter_enabled
		and sdk_authority_enabled
		and sdk_authority_scope == "stability_contribution_overlay"
	)
	var feedback_policy := (
		sdk_adapter_enabled
		and SDK_STABILITY_FEEDBACK_AUTHORITY_POLICY_IDS.has(stability_policy_id)
	)
	## The fixed-exposure path is the legacy-base overlay experiment. A full
	## post-settle authority campaign must never inherit its initial-memory,
	## time-window, or legacy-write semantics merely because both routes use
	## the same stability policy.
	var fixed_exposure := feedback_policy and not full_post_settle
	var full_authority_contribution := (
		full_post_settle
		and SDK_BW13P_STABILITY_POLICY_IDS.has(stability_policy_id)
	)
	var route_count := (
		int(full_post_settle)
		+ int(contribution_overlay)
		+ int(
			sdk_adapter_enabled
			and sdk_authority_enabled
			and sdk_authority_scope == "evidence_handoff"
		)
	)
	var exact := (
		not sdk_authority_enabled
		or route_count == 1
	)
	var zero_base_initial_gait_steps := {
		"front_left": 0,
		"front_right": 0,
		"rear_left": 0,
		"rear_right": 0,
	}
	var resolved_zero_base_initial_gait_steps := _sdk_initial_gait_steps(
		zero_base_initial_gait_steps,
		phase_offset_ticks,
		fixed_exposure,
	)
	return {
		"schema_version": "sporespore_sdk_execution_mode_plan_v1",
		"ok": exact,
		"failure_code": "" if exact else "SDK_EXECUTION_MODE_PLAN_ROUTE_AMBIGUOUS",
		"sdk_adapter_enabled": sdk_adapter_enabled,
		"sdk_authority_enabled": sdk_authority_enabled,
		"authority_scope": sdk_authority_scope,
		"stability_policy_id": stability_policy_id,
		"requested_phase_offset_ticks": phase_offset_ticks,
		"zero_base_initial_gait_steps":
		resolved_zero_base_initial_gait_steps,
		"initial_phase_offset_ticks":
		phase_offset_ticks if fixed_exposure else 0,
		"full_post_settle_authority_enabled": full_post_settle,
		"stability_contribution_overlay_enabled": contribution_overlay,
		"stability_feedback_policy": feedback_policy,
		"fixed_exposure_enabled": fixed_exposure,
		"full_authority_stability_contribution_enabled":
		full_authority_contribution,
		"phase_offset_application_mode":
		(
			"scheduled_once_at_warmup_boundary"
			if full_post_settle
			else (
				"baked_once_into_initial_memory"
				if fixed_exposure
				else "not_applicable"
			)
		),
		"legacy_base_motor_writes_allowed":
		contribution_overlay or fixed_exposure,
		"exclusive_native_post_settle_motor_writes_required":
		full_post_settle,
		"actual_world_build_count": 0,
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"physical_acceptance_authority": false,
	}


static func _sdk_effective_phase_offset_ticks(
	phase_offset_ticks: int,
	fixed_exposure_enabled: bool,
	full_post_settle_authority_enabled: bool,
	tick: int,
	activation_tick: int,
) -> int:
	if fixed_exposure_enabled or (full_post_settle_authority_enabled and tick >= activation_tick):
		return phase_offset_ticks
	return 0


static func _controller_configuration(
	motor_direction_sign: float,
	knee_motor_impulse_scale: float,
	knee_flexion_scale: float,
	gait_phase_order_id: String,
	gait_phase_order: Array,
	swing_ticks: int,
	contact_clearance_assist_rad: float,
	contact_clearance_assist_limb_id: String,
	evidence_boundary_alignment_ticks: int,
	robustness_options: Dictionary,
	path_steering_options: Dictionary,
	actuator_impulse_options: Dictionary,
	motor_velocity_options: Dictionary,
	gait_clock_options: Dictionary,
) -> Dictionary:
	var configuration := {
		"schema_version": "sporespore_physical_wave_gait_controller_configuration_v1",
		"physics_hz": int(gait_clock_options["physics_hz"]),
		"motor_direction_sign": motor_direction_sign,
		"knee_motor_impulse_scale": knee_motor_impulse_scale,
		"knee_flexion_scale": knee_flexion_scale,
		"motor_position_gain_per_s": float(gait_clock_options["motor_position_gain_per_s"]),
		"motor_rate_damping": float(gait_clock_options["motor_rate_damping"]),
		"maximum_motor_target_speed_rad_s":
		float(gait_clock_options["maximum_motor_target_speed_rad_s"]),
		"hip_forward_target_rad": HIP_FORWARD_TARGET_RAD,
		"hip_rear_target_rad": HIP_REAR_TARGET_RAD,
		"knee_swing_flexion_rad": KNEE_SWING_FLEXION_RAD,
		"gait_phase_order_id": gait_phase_order_id,
		"gait_phase_order": gait_phase_order.duplicate(),
		"cycle_ticks": int(gait_clock_options["cycle_ticks"]),
		"swing_ticks": swing_ticks,
		"settle_ticks": int(gait_clock_options["settle_ticks"]),
		"warmup_cycles": int(gait_clock_options["warmup_cycles"]),
		"evidence_cycles": int(gait_clock_options["evidence_cycles"]),
		"cooldown_cycles": int(gait_clock_options["cooldown_cycles"]),
		"terminal_settle_ticks": int(gait_clock_options["terminal_settle_ticks"]),
		"evidence_boundary_alignment_ticks": evidence_boundary_alignment_ticks,
		"contact_clearance_assist_rad": contact_clearance_assist_rad,
		"contact_clearance_assist_limb_id": contact_clearance_assist_limb_id,
		"robustness_options": robustness_options.duplicate(true),
		"morphology_adaptive_policy_established": false,
		"automatic_creature_guidance_allowed": false,
	}
	if bool(path_steering_options["phase_bounded_path_steering_enabled"]):
		configuration["path_steering_options"] = path_steering_options.duplicate(true)
	if bool(actuator_impulse_options["mass_adaptive_actuator_enabled"]):
		configuration["actuator_impulse_options"] = actuator_impulse_options.duplicate(true)
	if bool(motor_velocity_options["mass_adaptive_motor_velocity_enabled"]):
		configuration["motor_velocity_options"] = motor_velocity_options.duplicate(true)
	if String(gait_clock_options["policy_id"]) != GaitClockSpecScript.REFERENCE_POLICY_ID:
		configuration["gait_clock_options"] = gait_clock_options.duplicate(true)
	return configuration


static func compile_evidence_threshold_options(requested: Dictionary = {}) -> Dictionary:
	var normalized_result := _normalize_evidence_threshold_options(requested)
	if not bool(normalized_result.get("ok", false)):
		return normalized_result
	var evidence_threshold_options: Dictionary = normalized_result["evidence_threshold_options"]
	return {
		"ok": true,
		"failure_code": "",
		"evidence_threshold_options": evidence_threshold_options.duplicate(true),
		"evidence_threshold_configuration_sha256":
		CanonicalJsonScript.sha256(evidence_threshold_options),
		"world_build_count": 0,
	}


static func compile_solver_policy_options(requested: Dictionary = {}) -> Dictionary:
	var candidate := requested.duplicate(true)
	if candidate.is_empty():
		candidate = (
			(ALLOWED_SOLVER_POLICY_OPTIONS[DEFAULT_SOLVER_POLICY_ID] as Dictionary).duplicate(true)
		)
	for key_value in candidate.keys():
		var requested_key := String(key_value)
		if not SOLVER_POLICY_OPTION_KEYS.has(requested_key):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_SOLVER_POLICY_OPTION",
				"unknown_field": requested_key,
				"world_build_count": 0,
			}
	for required_key in SOLVER_POLICY_OPTION_KEYS:
		if not candidate.has(required_key):
			return {
				"ok": false,
				"failure_code": "MISSING_SOLVER_POLICY_OPTION",
				"missing_field": required_key,
				"world_build_count": 0,
			}
	if (
		typeof(candidate["solver_policy_id"]) != TYPE_STRING
		or typeof(candidate["physics_engine"]) != TYPE_STRING
		or typeof(candidate["physics_hz"]) != TYPE_INT
		or typeof(candidate["solver_velocity_steps"]) != TYPE_INT
		or typeof(candidate["solver_position_steps"]) != TYPE_INT
	):
		return {
			"ok": false,
			"failure_code": "INVALID_SOLVER_POLICY_OPTION_TYPE",
			"world_build_count": 0,
		}
	var policy_id := String(candidate["solver_policy_id"])
	if not ALLOWED_SOLVER_POLICY_OPTIONS.has(policy_id):
		return {
			"ok": false,
			"failure_code": "UNKNOWN_SOLVER_POLICY_ID",
			"solver_policy_id": policy_id,
			"world_build_count": 0,
		}
	var normalized: Dictionary = (ALLOWED_SOLVER_POLICY_OPTIONS[policy_id] as Dictionary).duplicate(
		true
	)
	if candidate != normalized:
		return {
			"ok": false,
			"failure_code": "SOLVER_POLICY_RECEIPT_MISMATCH",
			"solver_policy_id": policy_id,
			"world_build_count": 0,
		}
	return {
		"ok": true,
		"failure_code": "",
		"solver_policy_options": normalized.duplicate(true),
		"solver_policy_configuration_sha256": CanonicalJsonScript.sha256(normalized),
		"world_build_count": 0,
	}


static func compile_seeded_initial_perturbation(campaign_seed: int) -> Dictionary:
	if campaign_seed <= 0:
		return {
			"ok": false,
			"failure_code": "INVALID_INITIAL_PERTURBATION_SEED",
			"campaign_seed": campaign_seed,
		}
	var rng := RandomNumberGenerator.new()
	rng.seed = campaign_seed
	return _normalize_initial_perturbation(
		{
			"campaign_seed": campaign_seed,
			"fixture_vertical_clearance_m":
			rng.randf_range(0.0, MAXIMUM_INITIAL_VERTICAL_CLEARANCE_M * 0.50),
			"fixture_yaw_rad":
			rng.randf_range(
				-MAXIMUM_INITIAL_YAW_PERTURBATION_RAD * 0.75,
				MAXIMUM_INITIAL_YAW_PERTURBATION_RAD * 0.75
			),
			"initial_linear_velocity_world_m_s":
			Vector3(rng.randf_range(-0.004, 0.004), 0.0, rng.randf_range(-0.004, 0.004)),
			"initial_torso_angular_velocity_world_rad_s":
			Vector3(
				rng.randf_range(-0.002, 0.002),
				rng.randf_range(-0.004, 0.004),
				rng.randf_range(-0.002, 0.002)
			),
			"gait_phase_offset_ticks":
			rng.randi_range(
				-MAXIMUM_INITIAL_GAIT_PHASE_OFFSET_TICKS, MAXIMUM_INITIAL_GAIT_PHASE_OFFSET_TICKS
			),
		}
	)


static func _normalize_initial_perturbation(requested: Dictionary) -> Dictionary:
	for key_value in requested.keys():
		var requested_key := String(key_value)
		if not INITIAL_PERTURBATION_KEYS.has(requested_key):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_INITIAL_PERTURBATION_FIELD",
				"unknown_field": requested_key,
			}
	var campaign_seed := int(requested.get("campaign_seed", 0))
	var vertical_clearance_m := float(requested.get("fixture_vertical_clearance_m", 0.0))
	var fixture_yaw_rad := float(requested.get("fixture_yaw_rad", 0.0))
	var linear_velocity_value: Variant = requested.get(
		"initial_linear_velocity_world_m_s", Vector3.ZERO
	)
	var torso_angular_velocity_value: Variant = requested.get(
		"initial_torso_angular_velocity_world_rad_s", Vector3.ZERO
	)
	var gait_phase_offset_ticks := int(requested.get("gait_phase_offset_ticks", 0))
	if (
		typeof(linear_velocity_value) != TYPE_VECTOR3
		or typeof(torso_angular_velocity_value) != TYPE_VECTOR3
	):
		return {
			"ok": false,
			"failure_code": "INVALID_INITIAL_PERTURBATION_VECTOR",
		}
	var linear_velocity: Vector3 = linear_velocity_value
	var torso_angular_velocity: Vector3 = torso_angular_velocity_value
	if campaign_seed < 0:
		return {
			"ok": false,
			"failure_code": "INVALID_INITIAL_PERTURBATION_SEED",
			"campaign_seed": campaign_seed,
		}
	if (
		not is_finite(vertical_clearance_m)
		or vertical_clearance_m < 0.0
		or vertical_clearance_m > MAXIMUM_INITIAL_VERTICAL_CLEARANCE_M
	):
		return {
			"ok": false,
			"failure_code": "INITIAL_VERTICAL_CLEARANCE_OUT_OF_BOUNDS",
			"fixture_vertical_clearance_m": vertical_clearance_m,
		}
	if (
		not is_finite(fixture_yaw_rad)
		or absf(fixture_yaw_rad) > MAXIMUM_INITIAL_YAW_PERTURBATION_RAD
	):
		return {
			"ok": false,
			"failure_code": "INITIAL_YAW_PERTURBATION_OUT_OF_BOUNDS",
			"fixture_yaw_rad": fixture_yaw_rad,
		}
	if (
		not linear_velocity.is_finite()
		or absf(linear_velocity.y) > 1.0e-9
		or linear_velocity.length() > MAXIMUM_INITIAL_LINEAR_SPEED_M_S
	):
		return {
			"ok": false,
			"failure_code": "INITIAL_LINEAR_VELOCITY_OUT_OF_BOUNDS",
			"initial_linear_velocity_world_m_s": linear_velocity,
		}
	if (
		not torso_angular_velocity.is_finite()
		or torso_angular_velocity.length() > MAXIMUM_INITIAL_TORSO_ANGULAR_SPEED_RAD_S
	):
		return {
			"ok": false,
			"failure_code": "INITIAL_TORSO_ANGULAR_VELOCITY_OUT_OF_BOUNDS",
			"initial_torso_angular_velocity_world_rad_s": torso_angular_velocity,
		}
	if absi(gait_phase_offset_ticks) > MAXIMUM_INITIAL_GAIT_PHASE_OFFSET_TICKS:
		return {
			"ok": false,
			"failure_code": "INITIAL_GAIT_PHASE_OFFSET_OUT_OF_BOUNDS",
			"gait_phase_offset_ticks": gait_phase_offset_ticks,
		}
	return {
		"ok": true,
		"failure_code": "",
		"initial_perturbation":
		{
			"campaign_seed": campaign_seed,
			"fixture_vertical_clearance_m": vertical_clearance_m,
			"fixture_yaw_rad": fixture_yaw_rad,
			"initial_linear_velocity_world_m_s": linear_velocity,
			"initial_torso_angular_velocity_world_rad_s": torso_angular_velocity,
			"gait_phase_offset_ticks": gait_phase_offset_ticks,
		},
	}


static func compile_environment_challenge_options(requested: Dictionary) -> Dictionary:
	var defaults := {
		"challenge_profile_id": "none_v1",
		"terrain_profile_id": FLAT_TERRAIN_PROFILE_ID,
		"terrain_tile_length_m": 20.0,
		"terrain_tile_count": 1,
		"terrain_origin_x_m": -10.0,
		"terrain_heights_m": [0.0],
		"push_profile_id": NO_PUSH_PROFILE_ID,
		"push_step_from_sdk_start": -1,
		"push_impulse_task_n_s": [0.0, 0.0, 0.0],
		"observation_fault_profile_id": NO_OBSERVATION_FAULT_PROFILE_ID,
		"observation_noise_period_steps": 120,
		"base_position_noise_amplitude_m": 0.0,
		"base_linear_velocity_noise_amplitude_m_s": 0.0,
		"joint_position_noise_amplitude_rad": 0.0,
		"joint_velocity_noise_amplitude_rad_s": 0.0,
		"stability_body_position_noise_amplitude_m": 0.0,
		"stability_body_velocity_noise_amplitude_m_s": 0.0,
		"support_point_noise_amplitude_m": 0.0,
	}
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"environment_challenge_options": defaults,
			"environment_challenge_configuration_sha256": CanonicalJsonScript.sha256(defaults),
			"world_build_count": 0,
			"physical_acceptance_authority": false,
		}
	for key_value in requested.keys():
		var requested_key := String(key_value)
		if not ENVIRONMENT_CHALLENGE_OPTION_KEYS.has(requested_key):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_ENVIRONMENT_CHALLENGE_OPTION",
				"unknown_field": requested_key,
				"world_build_count": 0,
			}
	for required_key in ENVIRONMENT_CHALLENGE_OPTION_KEYS:
		if not requested.has(required_key):
			return {
				"ok": false,
				"failure_code": "MISSING_ENVIRONMENT_CHALLENGE_OPTION",
				"missing_field": required_key,
				"world_build_count": 0,
			}
	var profile_id_fields := [
		"challenge_profile_id",
		"terrain_profile_id",
		"push_profile_id",
		"observation_fault_profile_id",
	]
	for profile_id_field in profile_id_fields:
		if typeof(requested[profile_id_field]) != TYPE_STRING:
			return {
				"ok": false,
				"failure_code": "INVALID_ENVIRONMENT_CHALLENGE_PROFILE_ID_TYPE",
				"profile_id_field": profile_id_field,
				"world_build_count": 0,
			}
	var challenge_profile_id := String(requested["challenge_profile_id"])
	var terrain_profile_id := String(requested["terrain_profile_id"])
	var push_profile_id := String(requested["push_profile_id"])
	var observation_fault_profile_id := String(requested["observation_fault_profile_id"])
	if (
		challenge_profile_id.is_empty()
		or not [FLAT_TERRAIN_PROFILE_ID, ROUGH_TERRAIN_PROFILE_ID].has(terrain_profile_id)
		or not [NO_PUSH_PROFILE_ID, LATERAL_PUSH_PROFILE_ID].has(push_profile_id)
		or not (
			[
				NO_OBSERVATION_FAULT_PROFILE_ID,
				DETERMINISTIC_OBSERVATION_NOISE_PROFILE_ID,
			]
			. has(observation_fault_profile_id)
		)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_ENVIRONMENT_CHALLENGE_PROFILE_ID",
			"world_build_count": 0,
		}
	var tile_length_value: Variant = requested["terrain_tile_length_m"]
	var tile_count_value: Variant = requested["terrain_tile_count"]
	var terrain_origin_x_value: Variant = requested["terrain_origin_x_m"]
	var terrain_heights_value: Variant = requested["terrain_heights_m"]
	if (
		(typeof(tile_length_value) != TYPE_FLOAT and typeof(tile_length_value) != TYPE_INT)
		or (typeof(tile_count_value) != TYPE_FLOAT and typeof(tile_count_value) != TYPE_INT)
		or (
			typeof(terrain_origin_x_value) != TYPE_FLOAT
			and typeof(terrain_origin_x_value) != TYPE_INT
		)
		or typeof(terrain_heights_value) != TYPE_ARRAY
	):
		return {
			"ok": false,
			"failure_code": "INVALID_ENVIRONMENT_TERRAIN_GEOMETRY_TYPE",
			"world_build_count": 0,
		}
	var tile_length_m := float(tile_length_value)
	var tile_count := int(tile_count_value)
	var terrain_origin_x_m := float(terrain_origin_x_value)
	if (
		not is_finite(tile_length_m)
		or tile_length_m <= 0.0
		or tile_length_m > 20.0
		or not is_finite(float(tile_count_value))
		or float(tile_count_value) != floorf(float(tile_count_value))
		or tile_count < 1
		or tile_count > 256
		or not is_finite(terrain_origin_x_m)
	):
		return {
			"ok": false,
			"failure_code": "INVALID_ENVIRONMENT_TERRAIN_GEOMETRY",
			"world_build_count": 0,
		}
	var terrain_heights: Array = terrain_heights_value
	if terrain_heights.is_empty() or terrain_heights.size() > 64:
		return {
			"ok": false,
			"failure_code": "INVALID_ENVIRONMENT_TERRAIN_HEIGHT_COUNT",
			"world_build_count": 0,
		}
	var normalized_heights: Array = []
	var distinct_height_tokens := {}
	for height_value in terrain_heights:
		if typeof(height_value) != TYPE_FLOAT and typeof(height_value) != TYPE_INT:
			return {
				"ok": false,
				"failure_code": "INVALID_ENVIRONMENT_TERRAIN_HEIGHT",
				"world_build_count": 0,
			}
		var height_m := float(height_value)
		if not is_finite(height_m) or absf(height_m) > MAXIMUM_ROUGH_TERRAIN_ABSOLUTE_HEIGHT_M:
			return {
				"ok": false,
				"failure_code": "ENVIRONMENT_TERRAIN_HEIGHT_OUT_OF_BOUNDS",
				"world_build_count": 0,
			}
		normalized_heights.append(height_m)
		distinct_height_tokens[str(height_m)] = true
	if (
		terrain_profile_id == FLAT_TERRAIN_PROFILE_ID
		and (
			tile_count != 1 or normalized_heights.size() != 1 or float(normalized_heights[0]) != 0.0
		)
	):
		return {
			"ok": false,
			"failure_code": "FLAT_TERRAIN_PROFILE_NOT_FLAT",
			"world_build_count": 0,
		}
	if (
		terrain_profile_id == ROUGH_TERRAIN_PROFILE_ID
		and (tile_count < 8 or normalized_heights.size() < 3 or distinct_height_tokens.size() < 3)
	):
		return {
			"ok": false,
			"failure_code": "ROUGH_TERRAIN_PROFILE_NOT_ROUGH",
			"world_build_count": 0,
		}
	var push_step_value: Variant = requested["push_step_from_sdk_start"]
	if typeof(push_step_value) != TYPE_FLOAT and typeof(push_step_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_EXTERNAL_PUSH_STEP_TYPE",
			"world_build_count": 0,
		}
	var push_step_float := float(push_step_value)
	if not is_finite(push_step_float) or push_step_float != floorf(push_step_float):
		return {
			"ok": false,
			"failure_code": "INVALID_EXTERNAL_PUSH_STEP",
			"world_build_count": 0,
		}
	var push_step := int(push_step_float)
	var push_value: Variant = requested["push_impulse_task_n_s"]
	if typeof(push_value) != TYPE_ARRAY or (push_value as Array).size() != 3:
		return {
			"ok": false,
			"failure_code": "INVALID_EXTERNAL_PUSH_VECTOR",
			"world_build_count": 0,
		}
	var push_components: Array = []
	for component_value in push_value:
		if typeof(component_value) != TYPE_FLOAT and typeof(component_value) != TYPE_INT:
			return {
				"ok": false,
				"failure_code": "INVALID_EXTERNAL_PUSH_COMPONENT",
				"world_build_count": 0,
			}
		var component := float(component_value)
		if not is_finite(component):
			return {
				"ok": false,
				"failure_code": "NONFINITE_EXTERNAL_PUSH_COMPONENT",
				"world_build_count": 0,
			}
		push_components.append(component)
	var push_vector := FixtureSpecScript.vector3_from_array(push_components)
	if (
		push_vector.length() > MAXIMUM_EXTERNAL_PUSH_IMPULSE_N_S
		or (
			push_profile_id == NO_PUSH_PROFILE_ID
			and (push_step != -1 or not push_vector.is_zero_approx())
		)
		or (
			push_profile_id == LATERAL_PUSH_PROFILE_ID
			and (
				push_step < 1
				or push_step >= SDK_P5I3C_FIXED_EXPOSURE_STEP_COUNT
				or absf(push_vector.x) > 1.0e-12
				or absf(push_vector.y) > 1.0e-12
				or absf(push_vector.z) <= 1.0e-12
			)
		)
	):
		return {
			"ok": false,
			"failure_code": "EXTERNAL_PUSH_PROFILE_MISMATCH",
			"world_build_count": 0,
		}
	var noise_period_value: Variant = requested["observation_noise_period_steps"]
	if typeof(noise_period_value) != TYPE_FLOAT and typeof(noise_period_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_OBSERVATION_NOISE_PERIOD_TYPE",
			"world_build_count": 0,
		}
	var noise_period_float := float(noise_period_value)
	if not is_finite(noise_period_float) or noise_period_float != floorf(noise_period_float):
		return {
			"ok": false,
			"failure_code": "INVALID_OBSERVATION_NOISE_PERIOD",
			"world_build_count": 0,
		}
	var noise_period_steps := int(noise_period_float)
	var amplitude_fields := [
		"base_position_noise_amplitude_m",
		"base_linear_velocity_noise_amplitude_m_s",
		"joint_position_noise_amplitude_rad",
		"joint_velocity_noise_amplitude_rad_s",
		"stability_body_position_noise_amplitude_m",
		"stability_body_velocity_noise_amplitude_m_s",
		"support_point_noise_amplitude_m",
	]
	var amplitude_limits := [
		MAXIMUM_OBSERVATION_POSITION_NOISE_M,
		MAXIMUM_OBSERVATION_LINEAR_VELOCITY_NOISE_M_S,
		MAXIMUM_OBSERVATION_JOINT_POSITION_NOISE_RAD,
		MAXIMUM_OBSERVATION_JOINT_VELOCITY_NOISE_RAD_S,
		MAXIMUM_OBSERVATION_POSITION_NOISE_M,
		MAXIMUM_OBSERVATION_LINEAR_VELOCITY_NOISE_M_S,
		MAXIMUM_OBSERVATION_POSITION_NOISE_M,
	]
	var normalized_amplitudes := {}
	var nonzero_amplitude_count := 0
	for field_index in range(amplitude_fields.size()):
		var field := String(amplitude_fields[field_index])
		var requested_amplitude: Variant = requested[field]
		if typeof(requested_amplitude) != TYPE_FLOAT and typeof(requested_amplitude) != TYPE_INT:
			return {
				"ok": false,
				"failure_code": "OBSERVATION_NOISE_AMPLITUDE_INVALID",
				"amplitude_field": field,
				"world_build_count": 0,
			}
		var value := float(requested_amplitude)
		if not is_finite(value) or value < 0.0 or value > float(amplitude_limits[field_index]):
			return {
				"ok": false,
				"failure_code": "OBSERVATION_NOISE_AMPLITUDE_OUT_OF_BOUNDS",
				"amplitude_field": field,
				"world_build_count": 0,
			}
		normalized_amplitudes[field] = value
		if value > 0.0:
			nonzero_amplitude_count += 1
	if (
		noise_period_steps < 8
		or noise_period_steps > 600
		or (
			observation_fault_profile_id == NO_OBSERVATION_FAULT_PROFILE_ID
			and nonzero_amplitude_count != 0
		)
		or (
			observation_fault_profile_id == DETERMINISTIC_OBSERVATION_NOISE_PROFILE_ID
			and nonzero_amplitude_count == 0
		)
	):
		return {
			"ok": false,
			"failure_code": "OBSERVATION_FAULT_PROFILE_MISMATCH",
			"world_build_count": 0,
		}
	var normalized := {
		"challenge_profile_id": challenge_profile_id,
		"terrain_profile_id": terrain_profile_id,
		"terrain_tile_length_m": tile_length_m,
		"terrain_tile_count": tile_count,
		"terrain_origin_x_m": terrain_origin_x_m,
		"terrain_heights_m": normalized_heights,
		"push_profile_id": push_profile_id,
		"push_step_from_sdk_start": push_step,
		"push_impulse_task_n_s": push_components,
		"observation_fault_profile_id": observation_fault_profile_id,
		"observation_noise_period_steps": noise_period_steps,
	}
	for amplitude_field in amplitude_fields:
		normalized[amplitude_field] = float(normalized_amplitudes[amplitude_field])
	return {
		"ok": true,
		"failure_code": "",
		"environment_challenge_options": normalized,
		"environment_challenge_configuration_sha256": CanonicalJsonScript.sha256(normalized),
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


static func _normalize_actuator_impulse_options(requested: Dictionary) -> Dictionary:
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"actuator_impulse_options":
			{
				"mass_adaptive_actuator_enabled": false,
				"actuator_policy_id": "none",
				"actuator_impulse_scale": 1.0,
			},
		}
	for key_value in requested.keys():
		var requested_key := String(key_value)
		if not ACTUATOR_IMPULSE_OPTION_KEYS.has(requested_key):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_ACTUATOR_IMPULSE_OPTION",
				"unknown_field": requested_key,
				"world_build_count": 0,
			}
	for required_key in ["mass_adaptive_actuator_enabled", "actuator_policy_id"]:
		if not requested.has(required_key):
			return {
				"ok": false,
				"failure_code": "MISSING_ACTUATOR_IMPULSE_OPTION",
				"missing_field": required_key,
				"world_build_count": 0,
			}
	if (
		typeof(requested["mass_adaptive_actuator_enabled"]) != TYPE_BOOL
		or not bool(requested["mass_adaptive_actuator_enabled"])
	):
		return {
			"ok": false,
			"failure_code": "INVALID_ACTUATOR_IMPULSE_MODE",
			"world_build_count": 0,
		}
	var actuator_policy_id := String(requested["actuator_policy_id"])
	if actuator_policy_id.is_empty():
		return {
			"ok": false,
			"failure_code": "INVALID_ACTUATOR_POLICY_ID",
			"world_build_count": 0,
		}
	var has_common_scale := requested.has("actuator_impulse_scale")
	var has_hip_scale := requested.has("hip_impulse_scale")
	var has_knee_scale := requested.has("knee_impulse_scale")
	if has_common_scale and (has_hip_scale or has_knee_scale):
		return {
			"ok": false,
			"failure_code": "CONFLICTING_ACTUATOR_IMPULSE_SCALE_MODES",
			"world_build_count": 0,
		}
	if not has_common_scale and not (has_hip_scale and has_knee_scale):
		return {
			"ok": false,
			"failure_code": "MISSING_ACTUATOR_IMPULSE_SCALE_MODE",
			"world_build_count": 0,
		}
	var requested_scale_fields: Array = (
		["actuator_impulse_scale"]
		if has_common_scale
		else ["hip_impulse_scale", "knee_impulse_scale"]
	)
	var normalized_scales := {}
	for scale_field in requested_scale_fields:
		var scale_value: Variant = requested[scale_field]
		if typeof(scale_value) != TYPE_FLOAT and typeof(scale_value) != TYPE_INT:
			return {
				"ok": false,
				"failure_code": "INVALID_ACTUATOR_IMPULSE_SCALE",
				"scale_field": scale_field,
				"world_build_count": 0,
			}
		var impulse_scale := float(scale_value)
		if (
			not is_finite(impulse_scale)
			or impulse_scale < MINIMUM_ACTUATOR_IMPULSE_SCALE
			or impulse_scale > MAXIMUM_ACTUATOR_IMPULSE_SCALE
		):
			return {
				"ok": false,
				"failure_code": "ACTUATOR_IMPULSE_SCALE_OUT_OF_BOUNDS",
				"scale_field": scale_field,
				"actuator_impulse_scale": impulse_scale,
				"world_build_count": 0,
			}
		normalized_scales[scale_field] = impulse_scale
	if not has_common_scale:
		return {
			"ok": true,
			"failure_code": "",
			"actuator_impulse_options":
			{
				"mass_adaptive_actuator_enabled": true,
				"actuator_policy_id": actuator_policy_id,
				"hip_impulse_scale": float(normalized_scales["hip_impulse_scale"]),
				"knee_impulse_scale": float(normalized_scales["knee_impulse_scale"]),
			},
		}
	var actuator_impulse_scale := float(normalized_scales["actuator_impulse_scale"])
	return {
		"ok": true,
		"failure_code": "",
		"actuator_impulse_options":
		{
			"mass_adaptive_actuator_enabled": true,
			"actuator_policy_id": actuator_policy_id,
			"actuator_impulse_scale": actuator_impulse_scale,
		},
	}


static func _normalize_motor_velocity_options(
	requested: Dictionary,
	cycle_ticks: int = CYCLE_TICKS,
) -> Dictionary:
	var default_options := {
		"mass_adaptive_motor_velocity_enabled": false,
		"motor_velocity_policy_id": "none",
		"activation_predicate_id": "contact_loaded_swing_knee",
		"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s":
		MAXIMUM_MOTOR_TARGET_SPEED_RAD_S,
		"contact_loaded_swing_knee_activation_start_phase_tick": 0,
		"contact_loaded_swing_knee_full_speed_override_phase_tick": -1,
		"anchor_error_guard_enabled": false,
		"morphology_interaction_score": 0.0,
		"anchor_error_guard_activation_fraction": 0.90,
		"anchor_error_guard_maximum_motor_target_speed_rad_s": MAXIMUM_MOTOR_TARGET_SPEED_RAD_S,
	}
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"motor_velocity_options": default_options,
		}
	for key_value in requested.keys():
		var requested_key := String(key_value)
		if not MOTOR_VELOCITY_OPTION_KEYS.has(requested_key):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_MOTOR_VELOCITY_OPTION",
				"unknown_field": requested_key,
				"world_build_count": 0,
			}
	for required_key in REQUIRED_MOTOR_VELOCITY_OPTION_KEYS:
		if not requested.has(required_key):
			return {
				"ok": false,
				"failure_code": "MISSING_MOTOR_VELOCITY_OPTION",
				"missing_field": required_key,
				"world_build_count": 0,
			}
	if (
		typeof(requested["mass_adaptive_motor_velocity_enabled"]) != TYPE_BOOL
		or not bool(requested["mass_adaptive_motor_velocity_enabled"])
	):
		return {
			"ok": false,
			"failure_code": "INVALID_MOTOR_VELOCITY_MODE",
			"world_build_count": 0,
		}
	var policy_id := String(requested["motor_velocity_policy_id"])
	if policy_id.is_empty():
		return {
			"ok": false,
			"failure_code": "INVALID_MOTOR_VELOCITY_POLICY_ID",
			"world_build_count": 0,
		}
	var speed_value: Variant = requested["contact_loaded_swing_knee_maximum_motor_target_speed_rad_s"]
	if typeof(speed_value) != TYPE_FLOAT and typeof(speed_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_MOTOR_TARGET_SPEED",
			"world_build_count": 0,
		}
	var maximum_target_speed_rad_s := float(speed_value)
	if (
		not is_finite(maximum_target_speed_rad_s)
		or maximum_target_speed_rad_s < MINIMUM_MOTOR_TARGET_SPEED_RAD_S
		or maximum_target_speed_rad_s > MAXIMUM_MOTOR_TARGET_SPEED_RAD_S
	):
		return {
			"ok": false,
			"failure_code": "MOTOR_TARGET_SPEED_OUT_OF_BOUNDS",
			"maximum_motor_target_speed_rad_s": maximum_target_speed_rad_s,
			"world_build_count": 0,
		}
	var activation_start_value: Variant = (
		requested
		. get(
			"contact_loaded_swing_knee_activation_start_phase_tick",
			0,
		)
	)
	if typeof(activation_start_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_MOTOR_VELOCITY_ACTIVATION_START_PHASE_TICK",
			"world_build_count": 0,
		}
	var activation_start_phase_tick := int(activation_start_value)
	if activation_start_phase_tick < 0 or activation_start_phase_tick >= cycle_ticks:
		return {
			"ok": false,
			"failure_code": "MOTOR_VELOCITY_ACTIVATION_START_PHASE_TICK_OUT_OF_BOUNDS",
			"activation_start_phase_tick": activation_start_phase_tick,
			"world_build_count": 0,
		}
	var full_speed_override_value: Variant = (
		requested
		. get(
			"contact_loaded_swing_knee_full_speed_override_phase_tick",
			-1,
		)
	)
	if typeof(full_speed_override_value) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_MOTOR_VELOCITY_FULL_SPEED_OVERRIDE_PHASE_TICK",
			"world_build_count": 0,
		}
	var full_speed_override_phase_tick := int(full_speed_override_value)
	if full_speed_override_phase_tick < -1 or full_speed_override_phase_tick >= cycle_ticks:
		return {
			"ok": false,
			"failure_code": "MOTOR_VELOCITY_FULL_SPEED_OVERRIDE_PHASE_TICK_OUT_OF_BOUNDS",
			"full_speed_override_phase_tick": full_speed_override_phase_tick,
			"world_build_count": 0,
		}
	var anchor_guard_enabled_value: Variant = requested.get("anchor_error_guard_enabled", false)
	if typeof(anchor_guard_enabled_value) != TYPE_BOOL:
		return {
			"ok": false,
			"failure_code": "INVALID_ANCHOR_ERROR_GUARD_MODE",
			"world_build_count": 0,
		}
	var anchor_guard_enabled := bool(anchor_guard_enabled_value)
	var morphology_interaction_score_value: Variant = (
		requested
		. get(
			"morphology_interaction_score",
			0.0,
		)
	)
	if (
		typeof(morphology_interaction_score_value) != TYPE_FLOAT
		and typeof(morphology_interaction_score_value) != TYPE_INT
	):
		return {
			"ok": false,
			"failure_code": "INVALID_MORPHOLOGY_INTERACTION_SCORE",
			"world_build_count": 0,
		}
	var morphology_interaction_score := float(morphology_interaction_score_value)
	if (
		not is_finite(morphology_interaction_score)
		or morphology_interaction_score < 0.0
		or morphology_interaction_score > 1.0
	):
		return {
			"ok": false,
			"failure_code": "MORPHOLOGY_INTERACTION_SCORE_OUT_OF_BOUNDS",
			"morphology_interaction_score": morphology_interaction_score,
			"world_build_count": 0,
		}
	var anchor_guard_fraction_value: Variant = (
		requested
		. get(
			"anchor_error_guard_activation_fraction",
			0.90,
		)
	)
	if (
		typeof(anchor_guard_fraction_value) != TYPE_FLOAT
		and typeof(anchor_guard_fraction_value) != TYPE_INT
	):
		return {
			"ok": false,
			"failure_code": "INVALID_ANCHOR_ERROR_GUARD_ACTIVATION_FRACTION",
			"world_build_count": 0,
		}
	var anchor_guard_activation_fraction := float(anchor_guard_fraction_value)
	if (
		not is_finite(anchor_guard_activation_fraction)
		or anchor_guard_activation_fraction < 0.50
		or anchor_guard_activation_fraction >= 1.0
	):
		return {
			"ok": false,
			"failure_code": "ANCHOR_ERROR_GUARD_ACTIVATION_FRACTION_OUT_OF_BOUNDS",
			"anchor_error_guard_activation_fraction": anchor_guard_activation_fraction,
			"world_build_count": 0,
		}
	var anchor_guard_speed_value: Variant = (
		requested
		. get(
			"anchor_error_guard_maximum_motor_target_speed_rad_s",
			MAXIMUM_MOTOR_TARGET_SPEED_RAD_S,
		)
	)
	if (
		typeof(anchor_guard_speed_value) != TYPE_FLOAT
		and typeof(anchor_guard_speed_value) != TYPE_INT
	):
		return {
			"ok": false,
			"failure_code": "INVALID_ANCHOR_ERROR_GUARD_MOTOR_TARGET_SPEED",
			"world_build_count": 0,
		}
	var anchor_guard_maximum_target_speed_rad_s := float(anchor_guard_speed_value)
	if (
		not is_finite(anchor_guard_maximum_target_speed_rad_s)
		or anchor_guard_maximum_target_speed_rad_s < MINIMUM_MOTOR_TARGET_SPEED_RAD_S
		or anchor_guard_maximum_target_speed_rad_s > MAXIMUM_MOTOR_TARGET_SPEED_RAD_S
	):
		return {
			"ok": false,
			"failure_code": "ANCHOR_ERROR_GUARD_MOTOR_TARGET_SPEED_OUT_OF_BOUNDS",
			"maximum_motor_target_speed_rad_s": anchor_guard_maximum_target_speed_rad_s,
			"world_build_count": 0,
		}
	var activation_predicate_id := (
		"morphology_interaction_anchor_guarded_contact_loaded_swing_knee"
		if anchor_guard_enabled
		else (
			"release_gate_notched_contact_loaded_swing_knee"
			if full_speed_override_phase_tick >= 0
			else (
				"phase_windowed_contact_loaded_swing_knee"
				if activation_start_phase_tick > 0
				else "contact_loaded_swing_knee"
			)
		)
	)
	return {
		"ok": true,
		"failure_code": "",
		"motor_velocity_options":
		{
			"mass_adaptive_motor_velocity_enabled": true,
			"motor_velocity_policy_id": policy_id,
			"activation_predicate_id": activation_predicate_id,
			"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s":
			maximum_target_speed_rad_s,
			"contact_loaded_swing_knee_activation_start_phase_tick": activation_start_phase_tick,
			"contact_loaded_swing_knee_full_speed_override_phase_tick":
			full_speed_override_phase_tick,
			"anchor_error_guard_enabled": anchor_guard_enabled,
			"morphology_interaction_score": morphology_interaction_score,
			"anchor_error_guard_activation_fraction": anchor_guard_activation_fraction,
			"anchor_error_guard_maximum_motor_target_speed_rad_s":
			anchor_guard_maximum_target_speed_rad_s,
		},
	}


static func _normalize_evidence_threshold_options(requested: Dictionary) -> Dictionary:
	var default_options := {
		"evidence_threshold_policy_id": "reference_metric_thresholds_v1",
		"minimum_foot_relocation_m": MINIMUM_FOOT_RELOCATION_M,
		"minimum_evidence_torso_advance_m": MINIMUM_EVIDENCE_TORSO_ADVANCE_M,
		"minimum_final_torso_advance_m": MINIMUM_FINAL_TORSO_ADVANCE_M,
		"maximum_lateral_drift_m": MAXIMUM_LATERAL_DRIFT_M,
		"maximum_yaw_drift_rad": MAXIMUM_YAW_DRIFT_RAD,
		"maximum_tilt_rad": MAXIMUM_TILT_RAD,
		"minimum_torso_height_m": MINIMUM_TORSO_HEIGHT_M,
		"maximum_anchor_error_m": MAXIMUM_ANCHOR_ERROR_M,
		"maximum_hinge_axis_error_rad": MAXIMUM_HINGE_AXIS_ERROR_RAD,
	}
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"evidence_threshold_options": default_options,
		}
	for key_value in requested.keys():
		var requested_key := String(key_value)
		if not EVIDENCE_THRESHOLD_OPTION_KEYS.has(requested_key):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_EVIDENCE_THRESHOLD_OPTION",
				"unknown_field": requested_key,
				"world_build_count": 0,
			}
	for required_key in EVIDENCE_THRESHOLD_OPTION_KEYS:
		if not requested.has(required_key):
			return {
				"ok": false,
				"failure_code": "MISSING_EVIDENCE_THRESHOLD_OPTION",
				"missing_field": required_key,
				"world_build_count": 0,
			}
	if typeof(requested["evidence_threshold_policy_id"]) != TYPE_STRING:
		return {
			"ok": false,
			"failure_code": "INVALID_EVIDENCE_THRESHOLD_POLICY_ID",
			"world_build_count": 0,
		}
	var policy_id := String(requested["evidence_threshold_policy_id"])
	if not EVIDENCE_THRESHOLD_POLICY_IDS.has(policy_id):
		return {
			"ok": false,
			"failure_code": "UNKNOWN_EVIDENCE_THRESHOLD_POLICY_ID",
			"evidence_threshold_policy_id": policy_id,
			"world_build_count": 0,
		}
	var normalized := {"evidence_threshold_policy_id": policy_id}
	for key_value in EVIDENCE_THRESHOLD_OPTION_KEYS:
		var key := String(key_value)
		if key == "evidence_threshold_policy_id":
			continue
		var value: Variant = requested[key]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			return {
				"ok": false,
				"failure_code": "INVALID_EVIDENCE_THRESHOLD_VALUE",
				"threshold_field": key,
				"world_build_count": 0,
			}
		var threshold := float(value)
		if not is_finite(threshold) or threshold <= 0.0:
			return {
				"ok": false,
				"failure_code": "EVIDENCE_THRESHOLD_OUT_OF_BOUNDS",
				"threshold_field": key,
				"threshold_value": threshold,
				"world_build_count": 0,
			}
		normalized[key] = threshold
	return {
		"ok": true,
		"failure_code": "",
		"evidence_threshold_options": normalized,
	}


static func _normalize_path_steering_options(
	requested: Dictionary,
	cycle_ticks: int = CYCLE_TICKS,
) -> Dictionary:
	if requested.is_empty():
		return {
			"ok": true,
			"failure_code": "",
			"path_steering_options":
			{
				"phase_bounded_path_steering_enabled": false,
				"cross_track_heading_gain_rad_per_m": 0.0,
				"yaw_error_stride_gain_per_rad": 0.0,
				"steering_update_interval_ticks": 90,
				"maximum_desired_heading_error_rad": 0.25,
				"maximum_steering_fraction": 0.20,
			},
		}
	for key_value in requested.keys():
		var requested_key := String(key_value)
		if (
			not PATH_STEERING_OPTION_KEYS.has(requested_key)
			and not OPTIONAL_PATH_STEERING_OPTION_KEYS.has(requested_key)
		):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_PATH_STEERING_OPTION",
				"unknown_field": requested_key,
				"world_build_count": 0,
			}
	for required_key in PATH_STEERING_OPTION_KEYS:
		if not requested.has(required_key):
			return {
				"ok": false,
				"failure_code": "MISSING_PATH_STEERING_OPTION",
				"missing_field": required_key,
				"world_build_count": 0,
			}
	if (
		typeof(requested["phase_bounded_path_steering_enabled"]) != TYPE_BOOL
		or not bool(requested["phase_bounded_path_steering_enabled"])
	):
		return {
			"ok": false,
			"failure_code": "INVALID_PATH_STEERING_MODE",
			"world_build_count": 0,
		}
	var numeric_keys := [
		"cross_track_heading_gain_rad_per_m",
		"yaw_error_stride_gain_per_rad",
		"maximum_desired_heading_error_rad",
		"maximum_steering_fraction",
	]
	if requested.has("cross_track_velocity_heading_gain_rad_per_m_s"):
		numeric_keys.append("cross_track_velocity_heading_gain_rad_per_m_s")
	var numeric_values: Dictionary = {}
	for numeric_key in numeric_keys:
		var numeric_value: Variant = requested[numeric_key]
		if typeof(numeric_value) != TYPE_FLOAT and typeof(numeric_value) != TYPE_INT:
			return {
				"ok": false,
				"failure_code": "INVALID_PATH_STEERING_NUMERIC_FIELD",
				"field": numeric_key,
				"world_build_count": 0,
			}
		var normalized_value: float = float(numeric_value)
		if not is_finite(normalized_value) or normalized_value <= 0.0:
			return {
				"ok": false,
				"failure_code": "INVALID_PATH_STEERING_NUMERIC_FIELD",
				"field": numeric_key,
				"world_build_count": 0,
			}
		numeric_values[numeric_key] = normalized_value
	if (
		float(numeric_values["cross_track_heading_gain_rad_per_m"]) > 4.0
		or float(numeric_values["yaw_error_stride_gain_per_rad"]) > 4.0
		or float(numeric_values["maximum_desired_heading_error_rad"]) > 0.50
		or (
			float(numeric_values["maximum_steering_fraction"])
			> MAXIMUM_LATERAL_STRIDE_STEERING_FRACTION
		)
		or (
			numeric_values.has("cross_track_velocity_heading_gain_rad_per_m_s")
			and float(numeric_values["cross_track_velocity_heading_gain_rad_per_m_s"]) > 1.0
		)
	):
		return {
			"ok": false,
			"failure_code": "PATH_STEERING_BOUND_EXCEEDED",
			"world_build_count": 0,
		}
	if typeof(requested["steering_update_interval_ticks"]) != TYPE_INT:
		return {
			"ok": false,
			"failure_code": "INVALID_PATH_STEERING_UPDATE_INTERVAL",
			"world_build_count": 0,
		}
	var update_interval_ticks := int(requested["steering_update_interval_ticks"])
	if (
		update_interval_ticks < 1
		or update_interval_ticks > cycle_ticks
		or cycle_ticks % update_interval_ticks != 0
	):
		return {
			"ok": false,
			"failure_code": "INVALID_PATH_STEERING_UPDATE_INTERVAL",
			"world_build_count": 0,
		}
	var normalized_options := {
		"phase_bounded_path_steering_enabled": true,
		"cross_track_heading_gain_rad_per_m":
		float(numeric_values["cross_track_heading_gain_rad_per_m"]),
		"yaw_error_stride_gain_per_rad": float(numeric_values["yaw_error_stride_gain_per_rad"]),
		"steering_update_interval_ticks": update_interval_ticks,
		"maximum_desired_heading_error_rad":
		float(numeric_values["maximum_desired_heading_error_rad"]),
		"maximum_steering_fraction": float(numeric_values["maximum_steering_fraction"]),
	}
	if numeric_values.has("cross_track_velocity_heading_gain_rad_per_m_s"):
		normalized_options["cross_track_velocity_heading_gain_rad_per_m_s"] = float(
			numeric_values["cross_track_velocity_heading_gain_rad_per_m_s"]
		)
	return {
		"ok": true,
		"failure_code": "",
		"path_steering_options": normalized_options,
	}


static func compile_evidence_acquisition_options(
	requested: Dictionary,
	maximum_contact_gated_phase_skew_ticks: int = 12,
	minimum_airborne_dwell_ticks: int = 3,
) -> Dictionary:
	var source := (
		{
			"policy_id": LEGACY_EVIDENCE_ACQUISITION_POLICY_ID,
			"enabled": false,
			"maximum_acquisition_ticks": 0,
			"minimum_all_support_dwell_ticks": 1,
		}
		if requested.is_empty()
		else requested.duplicate(true)
	)
	if not _has_exact_keys(source, EVIDENCE_ACQUISITION_OPTION_KEYS):
		return {
			"ok": false,
			"failure_code": "INVALID_EVIDENCE_ACQUISITION_OPTION_KEYS",
			"world_build_count": 0,
		}
	if (
		typeof(source["policy_id"]) != TYPE_STRING
		or typeof(source["enabled"]) != TYPE_BOOL
		or typeof(source["maximum_acquisition_ticks"]) != TYPE_INT
		or typeof(source["minimum_all_support_dwell_ticks"]) != TYPE_INT
	):
		return {
			"ok": false,
			"failure_code": "INVALID_EVIDENCE_ACQUISITION_OPTION_TYPE",
			"world_build_count": 0,
		}
	var policy_id := String(source["policy_id"])
	var enabled := bool(source["enabled"])
	var maximum_acquisition_ticks := int(source["maximum_acquisition_ticks"])
	var minimum_all_support_dwell_ticks := int(source["minimum_all_support_dwell_ticks"])
	var exact_legacy := (
		policy_id == LEGACY_EVIDENCE_ACQUISITION_POLICY_ID
		and not enabled
		and maximum_acquisition_ticks == 0
		and minimum_all_support_dwell_ticks == 1
	)
	var exact_bounded := (
		policy_id == BOUNDED_EVIDENCE_ACQUISITION_POLICY_ID
		and enabled
		and maximum_contact_gated_phase_skew_ticks >= 0
		and minimum_airborne_dwell_ticks >= 1
		and minimum_all_support_dwell_ticks == minimum_airborne_dwell_ticks
		and (
			maximum_acquisition_ticks
			== maximum_contact_gated_phase_skew_ticks + minimum_airborne_dwell_ticks
		)
	)
	if not exact_legacy and not exact_bounded:
		return {
			"ok": false,
			"failure_code": "EVIDENCE_ACQUISITION_POLICY_RECEIPT_MISMATCH",
			"world_build_count": 0,
		}
	var normalized := {
		"policy_id": policy_id,
		"enabled": enabled,
		"maximum_acquisition_ticks": maximum_acquisition_ticks,
		"minimum_all_support_dwell_ticks": minimum_all_support_dwell_ticks,
	}
	return {
		"ok": true,
		"failure_code": "",
		"evidence_acquisition_options": normalized,
		"evidence_acquisition_configuration_sha256": CanonicalJsonScript.sha256(normalized),
		"derivation":
		(
			"legacy exact-boundary assertion"
			if exact_legacy
			else "maximum phase skew plus minimum airborne dwell"
		),
		"world_build_count": 0,
	}


static func _normalize_robustness_options(requested: Dictionary) -> Dictionary:
	for key_value in requested.keys():
		var requested_key := String(key_value)
		if not ROBUSTNESS_OPTION_KEYS.has(requested_key):
			return {
				"ok": false,
				"failure_code": "UNKNOWN_WALKING_ROBUSTNESS_OPTION",
				"unknown_field": requested_key,
			}
	var contact_gating_value: Variant = requested.get("contact_gated_phase_progression", false)
	if typeof(contact_gating_value) != TYPE_BOOL:
		return {
			"ok": false,
			"failure_code": "INVALID_CONTACT_GATING_MODE",
		}
	var maximum_hold_ticks := int(
		requested.get("maximum_contact_gate_hold_ticks", DEFAULT_MAXIMUM_CONTACT_GATE_HOLD_TICKS)
	)
	if maximum_hold_ticks < 1 or maximum_hold_ticks > MAXIMUM_CONTACT_GATE_HOLD_LIMIT_TICKS:
		return {
			"ok": false,
			"failure_code": "INVALID_MAXIMUM_CONTACT_GATE_HOLD_TICKS",
			"maximum_contact_gate_hold_ticks": maximum_hold_ticks,
		}
	var maximum_phase_skew_ticks := int(
		requested.get(
			"maximum_contact_gated_phase_skew_ticks", DEFAULT_MAXIMUM_CONTACT_GATED_PHASE_SKEW_TICKS
		)
	)
	if (
		maximum_phase_skew_ticks < 0
		or maximum_phase_skew_ticks > MAXIMUM_CONTACT_GATED_PHASE_SKEW_LIMIT_TICKS
	):
		return {
			"ok": false,
			"failure_code": "INVALID_MAXIMUM_CONTACT_GATED_PHASE_SKEW_TICKS",
			"maximum_contact_gated_phase_skew_ticks": maximum_phase_skew_ticks,
		}
	var lateral_steering_gain_value: Variant = requested.get(
		"lateral_stride_steering_gain_per_m", DEFAULT_LATERAL_STRIDE_STEERING_GAIN_PER_M
	)
	if (
		typeof(lateral_steering_gain_value) != TYPE_FLOAT
		and typeof(lateral_steering_gain_value) != TYPE_INT
	):
		return {
			"ok": false,
			"failure_code": "INVALID_LATERAL_STRIDE_STEERING_GAIN",
		}
	var lateral_steering_gain_per_m := float(lateral_steering_gain_value)
	if (
		not is_finite(lateral_steering_gain_per_m)
		or lateral_steering_gain_per_m < 0.0
		or lateral_steering_gain_per_m > MAXIMUM_LATERAL_STRIDE_STEERING_GAIN_PER_M
	):
		return {
			"ok": false,
			"failure_code": "INVALID_LATERAL_STRIDE_STEERING_GAIN",
			"lateral_stride_steering_gain_per_m": lateral_steering_gain_per_m,
		}
	return {
		"ok": true,
		"failure_code": "",
		"robustness_options":
		{
			"contact_gated_phase_progression": bool(contact_gating_value),
			"maximum_contact_gate_hold_ticks": maximum_hold_ticks,
			"maximum_contact_gated_phase_skew_ticks": maximum_phase_skew_ticks,
			"lateral_stride_steering_gain_per_m": lateral_steering_gain_per_m,
		},
	}


static func _contact_gated_limb_phase_receipt(
	limb: Dictionary,
	floor: StaticBody3D,
	phase_index: int,
	gait_tick: int,
	swing_ticks: int,
	cycle_ticks: int = CYCLE_TICKS,
) -> Dictionary:
	var release_gate_phase_tick := (swing_ticks * 3) / 4
	var recontact_gate_phase_tick := swing_ticks + (cycle_ticks - swing_ticks) / 4
	var phase_offset_ticks := phase_index * (cycle_ticks / LIMB_ORDER.size())
	var local_phase_tick := posmod(gait_tick - phase_offset_ticks, cycle_ticks)
	if local_phase_tick == release_gate_phase_tick:
		return {
			"gate_active": true,
			"contact_satisfied": not _foot_bears_floor(limb, floor),
			"hold_reason": "await_release",
			"limb_id": String(limb["limb_id"]),
			"local_phase_tick": local_phase_tick,
		}
	if local_phase_tick == recontact_gate_phase_tick:
		return {
			"gate_active": true,
			"contact_satisfied": _foot_bears_floor(limb, floor),
			"hold_reason": "await_recontact",
			"limb_id": String(limb["limb_id"]),
			"local_phase_tick": local_phase_tick,
		}
	return {
		"gate_active": false,
		"contact_satisfied": false,
		"hold_reason": "",
		"limb_id": "",
		"local_phase_tick": -1,
	}


static func _sum_dictionary_integers(values: Dictionary) -> int:
	var total := 0
	for value in values.values():
		total += int(value)
	return total


static func _all_dictionary_values_true(values: Dictionary) -> bool:
	if values.is_empty():
		return false
	for value in values.values():
		if not bool(value):
			return false
	return true


static func _minimum_dictionary_difference(current: Dictionary, initial: Dictionary) -> int:
	var minimum_difference := 0x7FFFFFFF
	for limb_id_value in LIMB_ORDER:
		var limb_id := String(limb_id_value)
		minimum_difference = mini(minimum_difference, int(current[limb_id]) - int(initial[limb_id]))
	return minimum_difference


static func _minimum_dictionary_integer(values: Dictionary) -> int:
	var minimum_value := 0x7FFFFFFF
	for value in values.values():
		minimum_value = mini(minimum_value, int(value))
	return minimum_value


static func _build_fixture(
	tree: SceneTree,
	knee_motor_impulse_scale: float,
	hip_impulse_scale: float,
	knee_impulse_scale: float,
	visible_demo: bool = false,
	initial_perturbation: Dictionary = {},
	fixture_spec: Dictionary = {},
	environment_challenge_options: Dictionary = {},
) -> Dictionary:
	var torso_spec: Dictionary = fixture_spec["torso"]
	var limb_specs: Array = fixture_spec["limbs"]
	var joint_limits: Dictionary = fixture_spec["joint_limits"]
	var motor_impulses: Dictionary = fixture_spec["motor_impulses"]
	var contact_material: Dictionary = fixture_spec["contact_material"]
	var body_dynamics: Dictionary = fixture_spec["body_dynamics"]
	var collision_margin_m := float(fixture_spec["collision_margin_m"])
	var realized_hip_max_impulse_nms := (
		float(motor_impulses["hip_max_impulse_nms"]) * hip_impulse_scale
	)
	var realized_knee_max_impulse_nms := (
		float(motor_impulses["knee_base_max_impulse_nms"])
		* knee_motor_impulse_scale
		* knee_impulse_scale
	)
	var torso_initial_center_m := FixtureSpecScript.vector3_from_array(
		torso_spec["initial_center_m"]
	)
	var torso_size_m := FixtureSpecScript.vector3_from_array(torso_spec["size_m"])
	var reference_torso_size_m := FixtureSpecScript.vector3_from_array(
		(FixtureSpecScript.reference_spec()["torso"] as Dictionary)["size_m"]
	)
	var fixture_view_scale := torso_size_m.x / reference_torso_size_m.x
	var fixture_vertical_clearance_m := float(
		initial_perturbation.get("fixture_vertical_clearance_m", 0.0)
	)
	var fixture_yaw_rad := float(initial_perturbation.get("fixture_yaw_rad", 0.0))
	var initial_linear_velocity_world_m_s: Vector3 = initial_perturbation.get(
		"initial_linear_velocity_world_m_s", Vector3.ZERO
	)
	var initial_torso_angular_velocity_world_rad_s: Vector3 = initial_perturbation.get(
		"initial_torso_angular_velocity_world_rad_s", Vector3.ZERO
	)
	var vertical_offset := Vector3.UP * fixture_vertical_clearance_m
	var viewport := SubViewport.new()
	viewport.name = "PhysicalWaveGaitQuadrupedViewport"
	viewport.size = Vector2i(1280, 720) if visible_demo else Vector2i(1, 1)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if visible_demo else SubViewport.UPDATE_DISABLED
	)
	var cleanup_node: Node = viewport
	if visible_demo:
		var viewport_container := SubViewportContainer.new()
		viewport_container.name = "PhysicalWaveGaitQuadrupedDemo"
		viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		viewport_container.stretch = true
		tree.root.add_child(viewport_container)
		viewport_container.add_child(viewport)
		_add_demo_overlay(viewport_container)
		cleanup_node = viewport_container
	else:
		tree.root.add_child(viewport)
	var world := Node3D.new()
	world.name = "PhysicalWaveGaitQuadrupedWorld"
	world.rotation.y = fixture_yaw_rad
	viewport.add_child(world)
	if visible_demo:
		_add_demo_environment(world, fixture_view_scale)
	var floor := StaticBody3D.new()
	floor.name = "wave_gait_floor"
	floor.set_meta("lab_body_id", "floor")
	floor.collision_layer = 1
	floor.collision_mask = 0
	floor.position = Vector3.ZERO
	var terrain_profile_id := String(
		environment_challenge_options.get("terrain_profile_id", FLAT_TERRAIN_PROFILE_ID)
	)
	var terrain_shape_count := 0
	if terrain_profile_id == ROUGH_TERRAIN_PROFILE_ID:
		var tile_length_m := float(environment_challenge_options["terrain_tile_length_m"])
		var tile_count := int(environment_challenge_options["terrain_tile_count"])
		var terrain_origin_x_m := float(environment_challenge_options["terrain_origin_x_m"])
		var terrain_heights: Array = environment_challenge_options["terrain_heights_m"]
		for tile_index in range(tile_count):
			var tile_height_m := float(terrain_heights[tile_index % terrain_heights.size()])
			var tile_shape_node := CollisionShape3D.new()
			tile_shape_node.name = "rough_tile_%03d" % tile_index
			var tile_shape := BoxShape3D.new()
			tile_shape.size = Vector3(tile_length_m, 0.1, 20.0)
			tile_shape.margin = collision_margin_m
			tile_shape_node.position = Vector3(
				terrain_origin_x_m + (float(tile_index) + 0.5) * tile_length_m,
				-0.05 + tile_height_m,
				0.0,
			)
			tile_shape_node.shape = tile_shape
			floor.add_child(tile_shape_node)
			if visible_demo:
				_add_box_visual(
					floor,
					tile_shape.size,
					Color("273043"),
					tile_shape_node.position,
				)
			terrain_shape_count += 1
	else:
		floor.position = Vector3(0.0, -0.05 * fixture_view_scale, 0.0)
		var floor_shape_node := CollisionShape3D.new()
		var floor_shape := BoxShape3D.new()
		floor_shape.size = Vector3(20.0, 0.1, 20.0) * fixture_view_scale
		floor_shape.margin = collision_margin_m
		floor_shape_node.shape = floor_shape
		floor.add_child(floor_shape_node)
		if visible_demo:
			_add_box_visual(floor, floor_shape.size, Color("273043"))
		terrain_shape_count = 1
	floor.physics_material_override = _physics_material(contact_material)
	world.add_child(floor)
	var torso := _rigid_body(
		"wave_gait_torso",
		float(torso_spec["mass_kg"]),
		torso_initial_center_m + vertical_offset,
		true,
		contact_material,
		body_dynamics
	)
	var torso_shape_node := CollisionShape3D.new()
	var torso_shape := BoxShape3D.new()
	torso_shape.size = torso_size_m
	torso_shape.margin = collision_margin_m
	torso_shape_node.shape = torso_shape
	torso_shape_node.set_meta("lab_shape_id", "torso")
	torso.add_child(torso_shape_node)
	if visible_demo:
		_add_box_visual(torso, torso_shape.size, Color("ff9f1c"))
	world.add_child(torso)
	var limbs: Array = []
	var bodies: Array = [torso]
	var joint_nodes: Array = []
	for limb_spec_value in limb_specs:
		var limb_spec: Dictionary = limb_spec_value
		var limb_id := String(limb_spec["limb_id"])
		var hip_world := (
			torso_initial_center_m
			+ FixtureSpecScript.vector3_from_array(limb_spec["hip_offset_from_torso_center_m"])
			+ vertical_offset
		)
		var upper_length_m := float(limb_spec["upper_length_m"])
		var lower_length_m := float(limb_spec["lower_length_m"])
		var upper_cross_section: Array = limb_spec["upper_cross_section_m"]
		var knee_world := hip_world + Vector3.DOWN * upper_length_m
		var foot_world := knee_world + Vector3.DOWN * lower_length_m
		var upper := _rigid_body(
			"wave_gait_%s_upper" % limb_id,
			float(limb_spec["upper_mass_kg"]),
			hip_world.lerp(knee_world, 0.5),
			false,
			contact_material,
			body_dynamics
		)
		var upper_shape_node := CollisionShape3D.new()
		var upper_shape := BoxShape3D.new()
		upper_shape.size = Vector3(
			float(upper_cross_section[0]), upper_length_m, float(upper_cross_section[1])
		)
		upper_shape.margin = collision_margin_m
		upper_shape_node.shape = upper_shape
		upper.add_child(upper_shape_node)
		if visible_demo:
			var upper_color := Color("3a86ff") if limb_id.ends_with("left") else Color("2ec4b6")
			_add_box_visual(upper, upper_shape.size, upper_color)
		var foot := _rigid_body(
			"wave_gait_%s_foot" % limb_id,
			float(limb_spec["distal_mass_kg"]),
			foot_world,
			true,
			contact_material,
			body_dynamics
		)
		var foot_shape_node := CollisionShape3D.new()
		var foot_shape := SphereShape3D.new()
		foot_shape.radius = float(limb_spec["foot_radius_m"])
		foot_shape.margin = collision_margin_m
		foot_shape_node.shape = foot_shape
		foot_shape_node.set_meta("lab_shape_id", "foot")
		foot.add_child(foot_shape_node)
		if visible_demo:
			var foot_color := Color("90beff") if limb_id.ends_with("left") else Color("8ce3d8")
			_add_sphere_visual(foot, foot_shape.radius, foot_color)
		world.add_child(upper)
		world.add_child(foot)
		bodies.append(upper)
		bodies.append(foot)
		var hip_joint := _hinge_joint(
			"wave_gait_%s_hip" % limb_id,
			hip_world,
			float(joint_limits["hip_lower_rad"]),
			float(joint_limits["hip_upper_rad"]),
			realized_hip_max_impulse_nms,
			float(joint_limits["bias"]),
			float(joint_limits["relaxation"])
		)
		var knee_joint := _hinge_joint(
			"wave_gait_%s_knee" % limb_id,
			knee_world,
			float(joint_limits["knee_lower_rad"]),
			float(joint_limits["knee_upper_rad"]),
			realized_knee_max_impulse_nms,
			float(joint_limits["bias"]),
			float(joint_limits["relaxation"])
		)
		world.add_child(hip_joint)
		world.add_child(knee_joint)
		joint_nodes.append(hip_joint)
		joint_nodes.append(knee_joint)
		(
			limbs
			. append(
				{
					"limb_id": limb_id,
					"upper": upper,
					"foot": foot,
					"hip_joint": hip_joint,
					"knee_joint": knee_joint,
					"joint_states":
					[
						{
							"joint_id": "%s.hip_pitch" % limb_id,
							"role": "hip_pitch",
							"parent": torso,
							"child": upper,
							"joint": hip_joint,
							"pivot_world_initial": world.to_global(hip_world),
						},
						{
							"joint_id": "%s.knee_pitch" % limb_id,
							"role": "knee_pitch",
							"parent": upper,
							"child": foot,
							"joint": knee_joint,
							"pivot_world_initial": world.to_global(knee_world),
						},
					],
				}
			)
		)
	await tree.process_frame
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var hip_joint: HingeJoint3D = limb["hip_joint"]
		var knee_joint: HingeJoint3D = limb["knee_joint"]
		hip_joint.node_a = hip_joint.get_path_to(torso)
		hip_joint.node_b = hip_joint.get_path_to(limb["upper"])
		knee_joint.node_a = knee_joint.get_path_to(limb["upper"])
		knee_joint.node_b = knee_joint.get_path_to(limb["foot"])
	await tree.physics_frame
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		for state_value in limb["joint_states"]:
			var state: Dictionary = state_value
			var parent: RigidBody3D = state["parent"]
			var child: RigidBody3D = state["child"]
			var pivot_world: Vector3 = state["pivot_world_initial"]
			state["rest_relative_basis"] = (
				(parent.global_basis.inverse() * child.global_basis).orthonormalized()
			)
			state["axis_parent_local"] = (parent.global_basis.inverse() * Vector3.BACK).normalized()
			state["axis_child_local"] = (child.global_basis.inverse() * Vector3.BACK).normalized()
			state["anchor_parent_local"] = parent.to_local(pivot_world)
			state["anchor_child_local"] = child.to_local(pivot_world)
	var initial_linear_velocity_body_initialization_count := 0
	var initial_torso_angular_velocity_initialization_count := 0
	for body_value in bodies:
		var body: RigidBody3D = body_value
		body.freeze = false
		body.sleeping = false
	if not initial_linear_velocity_world_m_s.is_zero_approx():
		for body_value in bodies:
			var initialized_body: RigidBody3D = body_value
			initialized_body.linear_velocity = initial_linear_velocity_world_m_s
			initial_linear_velocity_body_initialization_count += 1
	if not initial_torso_angular_velocity_world_rad_s.is_zero_approx():
		torso.angular_velocity = initial_torso_angular_velocity_world_rad_s
		initial_torso_angular_velocity_initialization_count = 1
	await tree.physics_frame
	return {
		"ok": true,
		"viewport": viewport,
		"cleanup_node": cleanup_node,
		"world": world,
		"floor": floor,
		"torso": torso,
		"limbs": limbs,
		"bodies": bodies,
		"joint_nodes": joint_nodes,
		"terrain_shape_count": terrain_shape_count,
		"fixture_view_scale": fixture_view_scale,
		"realized_hip_max_impulse_nms": realized_hip_max_impulse_nms,
		"realized_knee_max_impulse_nms": realized_knee_max_impulse_nms,
		"initial_linear_velocity_body_initialization_count":
		initial_linear_velocity_body_initialization_count,
		"initial_torso_angular_velocity_initialization_count":
		initial_torso_angular_velocity_initialization_count,
	}


static func _add_demo_overlay(parent: Control) -> void:
	var panel := ColorRect.new()
	panel.name = "EvidenceBoundaryLabelBackground"
	panel.position = Vector2(18.0, 18.0)
	panel.size = Vector2(590.0, 92.0)
	panel.color = Color(0.025, 0.035, 0.06, 0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var label := Label.new()
	label.name = "EvidenceBoundaryLabel"
	label.position = Vector2(16.0, 10.0)
	label.text = (
		"SporeSpore physical quadruped — best development candidate\n"
		+ "8 hinge motors • 9 free rigid bodies • no root force or teleport\n"
		+ "Development walking pass • exact multi-seed certification is still pending"
	)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("f4f7ff"))
	panel.add_child(label)


static func _add_demo_environment(world: Node3D, fixture_view_scale: float) -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "DemoWorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b132b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d7e3fc")
	environment.ambient_light_energy = 0.75
	environment_node.environment = environment
	world.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.name = "DemoKeyLight"
	light.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	world.add_child(light)
	var camera := Camera3D.new()
	camera.name = "DemoCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.7 * fixture_view_scale
	camera.position = Vector3(0.58, 0.88, 1.72) * fixture_view_scale
	camera.look_at_from_position(
		camera.position, Vector3(0.58, 0.24, 0.0) * fixture_view_scale, Vector3.UP
	)
	camera.current = true
	world.add_child(camera)


static func _add_box_visual(
	body: CollisionObject3D,
	size_m: Vector3,
	color: Color,
	local_position: Vector3 = Vector3.ZERO,
) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_m
	mesh.material = _demo_material(color)
	visual.mesh = mesh
	visual.position = local_position
	body.add_child(visual)


static func _add_sphere_visual(body: CollisionObject3D, radius_m: float, color: Color) -> void:
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius_m
	mesh.height = radius_m * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	mesh.material = _demo_material(color)
	visual.mesh = mesh
	body.add_child(visual)


static func _demo_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.05
	material.roughness = 0.72
	return material


static func _rigid_body(
	body_name: String,
	mass_kg: float,
	position_world_m: Vector3,
	monitor_contacts: bool,
	contact_material: Dictionary,
	body_dynamics: Dictionary
) -> RigidBody3D:
	var body: RigidBody3D
	if monitor_contacts:
		body = SemanticContactRigidBodyScript.new()
	else:
		body = RigidBody3D.new()
	body.name = body_name
	body.mass = mass_kg
	body.position = position_world_m
	body.freeze = true
	body.can_sleep = bool(body_dynamics["can_sleep"])
	body.continuous_cd = bool(body_dynamics["continuous_collision_detection"])
	body.linear_damp = float(body_dynamics["linear_damp"])
	body.angular_damp = float(body_dynamics["angular_damp"])
	body.collision_layer = int(body_dynamics["collision_layer"])
	body.collision_mask = int(body_dynamics["collision_mask"])
	body.contact_monitor = monitor_contacts
	body.max_contacts_reported = (
		int(body_dynamics["maximum_reported_contacts"]) if monitor_contacts else 0
	)
	body.physics_material_override = _physics_material(contact_material)
	return body


static func _physics_material(configuration: Dictionary) -> PhysicsMaterial:
	var material := PhysicsMaterial.new()
	material.friction = float(configuration["friction"])
	material.rough = bool(configuration["rough"])
	material.bounce = float(configuration["bounce"])
	material.absorbent = bool(configuration["absorbent"])
	return material


static func _hinge_joint(
	joint_name: String,
	pivot_world_m: Vector3,
	lower_limit_rad: float,
	upper_limit_rad: float,
	maximum_motor_impulse_nms: float,
	limit_bias: float,
	limit_relaxation: float
) -> HingeJoint3D:
	var joint := HingeJoint3D.new()
	joint.name = joint_name
	joint.position = pivot_world_m
	joint.basis = Basis(Vector3.DOWN, Vector3.RIGHT, Vector3.BACK)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, lower_limit_rad)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, upper_limit_rad)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_BIAS, limit_bias)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_RELAXATION, limit_relaxation)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, maximum_motor_impulse_nms)
	return joint


static func _gait_amplitude(
	tick: int,
	evidence_end_tick: int,
	cooldown_end_tick: int,
	settle_ticks: int = SETTLE_TICKS,
	warmup_cycles: int = WARMUP_CYCLES,
	cooldown_cycles: int = COOLDOWN_CYCLES,
	cycle_ticks: int = CYCLE_TICKS,
) -> float:
	if tick < settle_ticks:
		return 0.0
	if tick < settle_ticks + warmup_cycles * cycle_ticks:
		return _smoothstep(
			clampf(
				float(tick - settle_ticks) / float(warmup_cycles * cycle_ticks),
				0.0,
				1.0,
			)
		)
	if tick < evidence_end_tick:
		return 1.0
	if tick < cooldown_end_tick:
		return (
			1.0
			- _smoothstep(
				clampf(
					float(tick - evidence_end_tick) / float(cooldown_cycles * cycle_ticks),
					0.0,
					1.0,
				)
			)
		)
	return 0.0


static func _resolve_gait_phase_order(gait_phase_order_id: String) -> Array:
	if GAIT_PHASE_ORDERS.has(gait_phase_order_id):
		return (GAIT_PHASE_ORDERS[gait_phase_order_id] as Array).duplicate()
	var requested_order: Array = Array(gait_phase_order_id.split(",", false))
	if requested_order.size() != LIMB_ORDER.size():
		return []
	for limb_id_value in LIMB_ORDER:
		if requested_order.count(String(limb_id_value)) != 1:
			return []
	return requested_order


static func _gait_joint_targets(
	local_phase_tick: int,
	amplitude: float,
	knee_flexion_scale: float,
	swing_ticks: int,
	cycle_ticks: int = CYCLE_TICKS,
) -> Dictionary:
	var hip_target_rad: float
	var knee_target_rad := 0.0
	if local_phase_tick < swing_ticks:
		var swing_fraction := clampf(float(local_phase_tick) / float(swing_ticks), 0.0, 1.0)
		hip_target_rad = lerpf(
			HIP_REAR_TARGET_RAD, HIP_FORWARD_TARGET_RAD, _smoothstep(swing_fraction)
		)
		knee_target_rad = KNEE_SWING_FLEXION_RAD * knee_flexion_scale * sin(PI * swing_fraction)
	else:
		var stance_fraction := clampf(
			float(local_phase_tick - swing_ticks) / float(cycle_ticks - swing_ticks),
			0.0,
			1.0,
		)
		hip_target_rad = lerpf(
			HIP_FORWARD_TARGET_RAD, HIP_REAR_TARGET_RAD, _smoothstep(stance_fraction)
		)
	return {
		"hip_target_rad": amplitude * hip_target_rad,
		"knee_target_rad": amplitude * knee_target_rad,
	}


static func _command_hinge_motor(
	state: Dictionary,
	target_angle_rad: float,
	motor_direction_sign: float,
	motor_position_gain_per_s: float = MOTOR_POSITION_GAIN_PER_S,
	motor_rate_damping: float = MOTOR_RATE_DAMPING,
	maximum_target_speed_rad_s: float = MAXIMUM_MOTOR_TARGET_SPEED_RAD_S,
	apply_actuation: bool = true,
) -> Dictionary:
	var joint: HingeJoint3D = state["joint"]
	var measured_angle_rad := _joint_angle_rad(state)
	var measured_rate_rad_s := _joint_rate_rad_s(state)
	var target_velocity_rad_s := clampf(
		(
			motor_position_gain_per_s * (target_angle_rad - measured_angle_rad)
			- motor_rate_damping * measured_rate_rad_s
		),
		-maximum_target_speed_rad_s,
		maximum_target_speed_rad_s,
	)
	target_velocity_rad_s *= motor_direction_sign
	if apply_actuation:
		joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, target_velocity_rad_s)
	return {
		"target_velocity_rad_s": target_velocity_rad_s,
		"maximum_target_speed_rad_s": maximum_target_speed_rad_s,
		"measured_angle_rad": measured_angle_rad,
		"measured_rate_rad_s": measured_rate_rad_s,
		"actuation_applied": apply_actuation,
	}


static func _joint_angle_rad(state: Dictionary) -> float:
	var parent: RigidBody3D = state["parent"]
	var child: RigidBody3D = state["child"]
	var rest_relative: Basis = state["rest_relative_basis"]
	var current_relative := (parent.global_basis.inverse() * child.global_basis).orthonormalized()
	var delta := (current_relative * rest_relative.inverse()).orthonormalized()
	var rotation := delta.get_rotation_quaternion()
	var angle_rad := rotation.get_angle()
	if angle_rad <= 1.0e-9:
		return 0.0
	var axis_parent_local: Vector3 = state["axis_parent_local"]
	return angle_rad * signf(rotation.get_axis().dot(axis_parent_local))


static func _joint_rate_rad_s(state: Dictionary) -> float:
	var parent: RigidBody3D = state["parent"]
	var child: RigidBody3D = state["child"]
	var axis_world := (parent.global_basis * (state["axis_parent_local"] as Vector3)).normalized()
	return (child.angular_velocity - parent.angular_velocity).dot(axis_world)


static func _joint_geometry_receipt(state: Dictionary) -> Dictionary:
	var parent: RigidBody3D = state["parent"]
	var child: RigidBody3D = state["child"]
	var parent_anchor := parent.to_global(state["anchor_parent_local"])
	var child_anchor := child.to_global(state["anchor_child_local"])
	var parent_axis := (parent.global_basis * (state["axis_parent_local"] as Vector3)).normalized()
	var child_axis := (child.global_basis * (state["axis_child_local"] as Vector3)).normalized()
	return {
		"anchor_error_m": parent_anchor.distance_to(child_anchor),
		"hinge_axis_error_rad": acos(clampf(absf(parent_axis.dot(child_axis)), 0.0, 1.0)),
	}


static func _update_contact_cycle_receipts(
	tick: int,
	limbs: Array,
	floor: StaticBody3D,
	contact_state_by_limb: Dictionary,
	contact_cycle_count_by_limb: Dictionary,
	rejected_short_contact_cycle_count_by_limb: Dictionary,
	maximum_cycle_relocation_by_limb_m: Dictionary,
	minimum_cycle_relocation_by_limb_m: Dictionary,
	contact_transition_receipts_by_limb: Dictionary,
	minimum_airborne_dwell_ticks: int = MINIMUM_AIRBORNE_DWELL_TICKS,
	minimum_foot_relocation_m: float = MINIMUM_FOOT_RELOCATION_M,
) -> void:
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var limb_id := String(limb["limb_id"])
		var foot: RigidBody3D = limb["foot"]
		var contact_now := _foot_bears_floor(limb, floor)
		var state: Dictionary = contact_state_by_limb[limb_id]
		if not bool(state["airborne"]):
			if bool(state["bearing"]) and not contact_now:
				state["airborne"] = true
				state["bearing"] = false
				state["release_tick"] = tick
				state["release_position"] = foot.global_position
				state["airborne_dwell_ticks"] = 1
				(
					(contact_transition_receipts_by_limb[limb_id] as Array)
					. append(
						{
							"event": "release",
							"tick": tick,
							"foot_position_world_m": foot.global_position,
						}
					)
				)
			else:
				state["bearing"] = contact_now
			continue
		if not contact_now:
			state["airborne_dwell_ticks"] = int(state["airborne_dwell_ticks"]) + 1
			continue
		var airborne_dwell_ticks := int(state["airborne_dwell_ticks"])
		var release_position: Vector3 = state["release_position"]
		var forward_relocation_m := foot.global_position.x - release_position.x
		var accepted := (
			airborne_dwell_ticks >= minimum_airborne_dwell_ticks
			and forward_relocation_m >= minimum_foot_relocation_m
		)
		(
			(contact_transition_receipts_by_limb[limb_id] as Array)
			. append(
				{
					"event": "recontact",
					"tick": tick,
					"airborne_dwell_ticks": airborne_dwell_ticks,
					"forward_relocation_m": forward_relocation_m,
					"accepted": accepted,
					"foot_position_world_m": foot.global_position,
				}
			)
		)
		if accepted:
			contact_cycle_count_by_limb[limb_id] = int(contact_cycle_count_by_limb[limb_id]) + 1
			maximum_cycle_relocation_by_limb_m[limb_id] = maxf(
				float(maximum_cycle_relocation_by_limb_m[limb_id]), forward_relocation_m
			)
			minimum_cycle_relocation_by_limb_m[limb_id] = minf(
				float(minimum_cycle_relocation_by_limb_m[limb_id]), forward_relocation_m
			)
		else:
			rejected_short_contact_cycle_count_by_limb[limb_id] = (
				int(rejected_short_contact_cycle_count_by_limb[limb_id]) + 1
			)
		state["airborne"] = false
		state["bearing"] = true
		state["release_tick"] = -1
		state["release_position"] = Vector3(INF, INF, INF)
		state["airborne_dwell_ticks"] = 0


static func _foot_bears_floor(limb: Dictionary, floor: StaticBody3D) -> bool:
	var foot: RigidBody3D = limb["foot"]
	return _body_bears_floor(foot, "foot", floor)


static func _body_bears_floor(
	body: RigidBody3D, semantic_shape_id: String, floor: StaticBody3D
) -> bool:
	if (
		floor.has_meta("lab_body_id")
		and body.has_method("has_semantic_contact")
		and body.get("semantic_contact_callback_count") != null
		and int(body.get("semantic_contact_callback_count")) > 0
	):
		return bool(
			body.call(
				"has_semantic_contact", semantic_shape_id, String(floor.get_meta("lab_body_id"))
			)
		)
	return floor in body.get_colliding_bodies()


static func _all_feet_bear_floor(limbs: Array, floor: StaticBody3D) -> bool:
	for limb_value in limbs:
		if not _foot_bears_floor(limb_value, floor):
			return false
	return true


static func _bearing_contact_by_limb(limbs: Array, floor: StaticBody3D) -> Dictionary:
	var result := {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		result[String(limb["limb_id"])] = _foot_bears_floor(limb, floor)
	return result


static func _contact_observer_callback_count_by_limb(limbs: Array) -> Dictionary:
	var result := {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var foot: RigidBody3D = limb["foot"]
		result[String(limb["limb_id"])] = int(foot.get("semantic_contact_callback_count"))
	return result


static func _joint_angles_by_limb(limbs: Array) -> Dictionary:
	var result := {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var angles := {}
		for state_value in limb["joint_states"]:
			var state: Dictionary = state_value
			angles[String(state["role"])] = _joint_angle_rad(state)
		result[String(limb["limb_id"])] = angles
	return result


static func _foot_heights_by_limb(limbs: Array) -> Dictionary:
	var result := {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var foot: RigidBody3D = limb["foot"]
		result[String(limb["limb_id"])] = foot.global_position.y
	return result


static func _tilt_rad(torso: RigidBody3D) -> float:
	return acos(clampf(torso.global_basis.y.normalized().dot(Vector3.UP), -1.0, 1.0))


static func _yaw_rad(torso: RigidBody3D) -> float:
	var forward := -torso.global_basis.z.normalized()
	return atan2(forward.x, -forward.z)


static func _wrap_angle(angle_rad: float) -> float:
	return fposmod(angle_rad + PI, TAU) - PI


static func _smoothstep(value: float) -> float:
	var bounded := clampf(value, 0.0, 1.0)
	return bounded * bounded * (3.0 - 2.0 * bounded)
