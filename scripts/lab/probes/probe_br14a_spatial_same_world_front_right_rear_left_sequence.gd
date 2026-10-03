extends SceneTree
# gdlint: disable=max-line-length

## BR14A.5 development probe for front-right then rear-left in one physics world.
##
## A positive probe remains development evidence until an exact sealed contract
## and complete all-seed test establish the same-world sequence.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const FrontRightStepScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_bounded_atomic_locomotor_step.gd"
)
const RearLeftStepScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_rear_left_bounded_atomic_locomotor_step.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 120
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var front_right_result := FrontRightStepScript.compile(FrontRightStepScript.configuration())
	var rear_left_result := RearLeftStepScript.compile(RearLeftStepScript.configuration())
	if (
		not bool(profile_result.get("ok", false))
		or not bool(front_right_result.get("ok", false))
		or not bool(rear_left_result.get("ok", false))
	):
		printerr(
			(
				"seal failure profile=%s front_right=%s rear_left=%s"
				% [profile_result, front_right_result, rear_left_result]
			)
		)
		Engine.physics_ticks_per_second = original_hz
		quit(1)
		return
	var seed := 14001
	var second_development_tick_limit := -1
	var continuation_policy_overrides: Dictionary = {}
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		seed = int(user_args[0])
	if user_args.size() >= 2:
		second_development_tick_limit = int(user_args[1])
	if user_args.size() >= 3:
		continuation_policy_overrides["contact_release_vertical_force_ramp_ticks"] = int(
			user_args[2]
		)
	if user_args.size() >= 4:
		continuation_policy_overrides["contact_release_vertical_force_ramp_initial_fraction"] = (float(
			user_args[3]
		))
	if user_args.size() >= 5:
		continuation_policy_overrides["semantic_recontact_swing_pose_reference_blend_fraction"] = float(
			user_args[4]
		)
	if user_args.size() >= 6:
		continuation_policy_overrides["gait_airborne_body_advance_m"] = float(user_args[5])
	var result := await RigScript.new().run_same_world_atomic_step_sequence(
		self,
		profile_result["profile"],
		front_right_result["experiment"],
		rear_left_result["experiment"],
		seed,
		second_development_tick_limit,
		continuation_policy_overrides
	)
	if not result.has("first_summary") or not result.has("second_summary"):
		printerr("sequence returned incomplete result seed=", seed, " result=", result)
		Engine.physics_ticks_per_second = original_hz
		quit(1)
		return
	var first: Dictionary = result["first_summary"]
	var second: Dictionary = result["second_summary"]
	print(
		(
			(
				"ok=%s failure=%s seed=%d same_world=%s sequence=%s "
				+ "first_release=%d first_recontact=%d first_atomic=%s "
				+ "second_release_local=%d second_recontact_local=%d "
				+ "second_release_global=%d second_recontact_global=%d second_atomic=%s "
				+ "second_release_gap=%.6f "
				+ "cumulative_com=%s cumulative_torso=%s "
				+ "cumulative_phase_com=%s cumulative_phase_torso=%s "
				+ "second_phase_com=%s second_phase_torso=%s "
				+ "second_initial_margin=%.6f second_centroid_margin=%.6f "
				+ "second_readiness_fraction=%.6f second_readiness_shift=%.6f "
				+ "second_recontact_recovery=%s second_recontact_commands=%d "
				+ "second_vertical_commands=%d second_vertical_force=%.6f "
				+ "second_translation_ready=%s second_translation_ready_tick=%d "
				+ "second_translation_ready_dwell=%d "
				+ "second_pose_rebase_count=%d second_pose_rebase_tick=%d "
				+ "second_translation_three_support_commands=%d "
				+ "second_translation_command_end=%d "
				+ "second_stabilization_start=%d second_stabilization_commands=%d "
				+ "second_stabilization_start_h=%.6f second_stabilization_target_h=%.6f "
				+ "second_posture_commands=%d second_posture_updates=%d "
				+ "second_posture_max_rate=%.6f second_posture_max_rotation=%.6f "
				+ "second_posture_latched=%s second_posture_latch_tick=%d "
				+ "second_posture_ready_dwell=%d "
				+ "second_posture_damping_commands=%d second_posture_damping_torque=%.6f "
				+ "second_posture_damping_rate=%.6f "
				+ "second_posture_limb_ticks=%s second_posture_joint_rotation=%s "
				+ "second_early_posture=%s/%d/%s/%s/%d/%.6f/%.6f/%.6f/%d/%d/%d/%.6f/%.6f/%.6f/%.6f/%s "
				+ "second_translation_target_scale=%.6f "
				+ "second_targeted_recontact=%s second_long_recovery=%s "
				+ "second_bounded_translation=%s "
				+ "second_final_foot=%s second_final_foot_move=%.6f "
				+ "second_final_foot_error=%.6f second_translation_slip=%.6f "
				+ "second_translation_slip_by_limb=%s "
				+ "second_translation_gates=%s second_atomic_gates=%s "
				+ "second_release_foot_v=%s second_release_lower_v=%s "
				+ "second_release_lower_omega=%s second_release_torso_v=%s "
				+ "second_release_torso_omega=%s "
				+ "second_recontact_move=%.6f second_recontact_error=%.6f "
				+ "second_recontact_foot_v=%s second_recontact_lower_v=%s "
				+ "second_recontact_lower_omega=%s second_recontact_torso_v=%s "
				+ "second_recontact_torso_omega=%s "
				+ "second_precontact_tick=%d second_precontact_foot_v=%s "
				+ "second_precontact_lower_v=%s second_precontact_lower_omega=%s "
				+ "second_precontact_torso_v=%s second_precontact_torso_omega=%s "
				+ "second_absent_dwell=%d second_swing_progress=%d/%d "
				+ "second_disturbances=%d second_damping=%d/%.6f "
				+ "second_damping_start_h=%.6f second_damping_start_tilt=%.6f "
				+ "second_damping_start_omega=%s second_damping_start_swing_rate=%.6f "
				+ "second_damping_start_joint_rates=%s "
				+ "second_ok=%s second_fixture=%s second_fixture_failure=%s "
				+ "second_ticks=%d second_handoff_tick=%d "
				+ "second_active_handoff_margin=%.6f second_active_lift_margin=%.6f "
				+ "second_active_lift_timing=%d/%d "
				+ "second_active_relocation_timing=%d/%d/%d "
				+ "second_active_release_force=%.6f "
				+ "second_active_release_height=%.6f second_active_min_gap=%.6f "
				+ "second_active_live_horizontal_release=%s "
				+ "second_active_horizontal_release_force=%.6f "
				+ "second_release_task_force=%.6f/%.6f "
				+ "second_release_reaction_comp=%s/%s/%d/%.6f/%.6f "
				+ "second_active_release_velocity_preservation=%d/%.6f "
				+ "second_active_initial_horizontal_velocity=%.6f/%d/%.6f "
				+ "second_active_joint_damping=%.6f/%.6f "
				+ "second_active_recontact_pose_rebase=%s/%d/%d "
				+ "second_active_recontact_swing_hold=%d/%d "
				+ "second_active_recontact_horizontal_damping=%s/%d/%.6f/%.6f/%d/%.6f/%.6f "
				+ "second_active_four_contact_attitude=%s/%d "
				+ "second_active_recovery_attitude=%s/%d/%.6f/%.6f/%.6f "
				+ "second_active_translation_start=%d/%d/%s "
				+ "second_first_relocation_command=%d/%s/%s/%s "
				+ "second_lift_com_margin=%.6f second_lift_capture_margin=%.6f "
				+ "second_h=%.6f second_tilt=%.6f second_speed=%.6f second_omega=%s "
				+ "second_all4=%s second_contacts=%s second_first_contact_loss=%d/%s "
				+ "second_torso_contact=%d "
				+ "second_anchor=%.6f second_hinge=%.6f second_torque=%.6f "
				+ "second_structure_sat=%d second_allocator_infeasible=%d "
				+ "second_allocator_authority=%.6f second_allocator_reasons=%s "
				+ "second_allocator_force_residual=%.6f "
				+ "second_allocator_moment_residual=%.6f "
				+ "second_allocator_normal_reserve=%.6f "
				+ "second_allocator_friction_reserve=%.6f"
			)
			% [
				str(result.get("ok", false)),
				String(result.get("failure_code", "")),
				seed,
				str(result["same_world_receipt"]),
				str(result["same_world_sequential_atomic_steps_observed"]),
				int(first["contact_release_first_tick"]),
				int(first["semantic_release_recontact_tick"]),
				str(first["bounded_atomic_locomotor_step_observed"]),
				int(second["contact_release_first_tick"]),
				int(second["semantic_release_recontact_tick"]),
				int(result["second_release_global_tick"]),
				int(result["second_recontact_global_tick"]),
				str(second["bounded_atomic_locomotor_step_observed"]),
				float(second["contact_release_gap_m"]),
				str(result["cumulative_com_translation_world_m"]),
				str(result["cumulative_torso_translation_world_m"]),
				str(result["cumulative_post_recontact_com_translation_world_m"]),
				str(result["cumulative_post_recontact_torso_translation_world_m"]),
				str(second["post_recontact_body_translation_com_displacement_world_m"]),
				str(second["post_recontact_body_translation_torso_displacement_world_m"]),
				float(second["continuation_initial_dynamic_margin_m"]),
				float(second["continuation_support_centroid_margin_m"]),
				float(second["continuation_readiness_target_fraction"]),
				float(second["continuation_readiness_target_displacement_m"]),
				str(second["continuation_recontact_support_recovery_active"]),
				int(second["continuation_recontact_support_recovery_command_ticks"]),
				int(second["continuation_recontact_vertical_support_command_ticks"]),
				float(second["maximum_continuation_recontact_vertical_support_force_n"]),
				str(second["continuation_body_translation_recovery_latched"]),
				int(second["continuation_body_translation_recovery_latch_tick"]),
				int(second["maximum_continuation_body_translation_recovery_dwell_ticks"]),
				int(second["continuation_joint_pose_reference_rebase_count"]),
				int(second["continuation_joint_pose_reference_rebase_tick"]),
				int(second["continuation_body_translation_three_support_command_ticks"]),
				int(second["continuation_body_translation_command_end_tick"]),
				int(second["continuation_post_translation_stabilization_start_tick"]),
				int(second["continuation_post_translation_stabilization_command_ticks"]),
				float(second["continuation_post_translation_stabilization_start_torso_height_m"]),
				float(second["continuation_post_translation_stabilization_target_torso_height_m"]),
				int(second["continuation_contact_consistent_posture_command_ticks"]),
				int(second["continuation_contact_consistent_posture_joint_reference_update_count"]),
				float(
					second["continuation_contact_consistent_posture_maximum_joint_reference_rate_rad_s"]
				),
				float(
					second["continuation_contact_consistent_posture_maximum_accumulated_joint_rotation_rad"]
				),
				str(second["continuation_contact_consistent_posture_recovery_latched"]),
				int(second["continuation_contact_consistent_posture_recovery_latch_tick"]),
				int(second["maximum_continuation_contact_consistent_posture_recovery_dwell_ticks"]),
				int(second["continuation_posture_settle_joint_damping_command_ticks"]),
				float(second["maximum_continuation_posture_settle_joint_damping_torque_nm"]),
				float(second["maximum_continuation_posture_settle_joint_rate_rad_s"]),
				str(second["continuation_contact_consistent_posture_command_ticks_by_limb"]),
				str(
					second["continuation_contact_consistent_posture_accumulated_rotation_by_joint_rad"]
				),
				str(second["active_early_contact_consistent_posture_recovery_enabled"]),
				int(second["active_early_contact_consistent_posture_recovery_duration_ticks"]),
				String(second["active_early_contact_consistent_posture_recovery_limb_scope"]),
				str(second["active_early_contact_consistent_posture_attitude_reference_enabled"]),
				int(
					second["active_early_contact_consistent_posture_attitude_reference_duration_ticks"]
				),
				float(second["active_early_contact_consistent_posture_maximum_endpoint_speed_m_s"]),
				float(second["active_early_contact_consistent_posture_reference_rate_scale"]),
				float(
					second["active_early_contact_consistent_posture_maximum_accumulated_joint_rotation_rad"]
				),
				int(second["continuation_early_contact_consistent_posture_first_tick"]),
				int(second["continuation_early_contact_consistent_posture_command_ticks"]),
				int(
					second["continuation_early_contact_consistent_posture_joint_reference_update_count"]
				),
				float(
					second["continuation_early_contact_consistent_posture_maximum_joint_reference_rate_rad_s"]
				),
				float(
					second["continuation_early_contact_consistent_posture_maximum_accumulated_joint_rotation_rad"]
				),
				float(
					second["continuation_early_contact_consistent_posture_maximum_desired_body_angular_speed_rad_s"]
				),
				float(
					second["continuation_early_contact_consistent_posture_maximum_relative_endpoint_speed_m_s"]
				),
				str(second["continuation_early_contact_consistent_posture_command_ticks_by_limb"]),
				float(second["continuation_body_translation_target_scale"]),
				str(second["bounded_targeted_relocation_recontact_observed"]),
				str(second["long_horizon_targeted_relocation_recovery_observed"]),
				str(second["bounded_post_recontact_body_translation_observed"]),
				str(second["semantic_relocation_final_horizontal_displacement_world_m"]),
				float(second["semantic_relocation_final_horizontal_displacement_m"]),
				float(second["semantic_relocation_final_horizontal_target_error_m"]),
				float(second["maximum_post_recontact_body_translation_foot_slip_m"]),
				str(second["post_recontact_body_translation_foot_slip_m_by_limb"]),
				str(second["post_recontact_body_translation_gate_receipts"]),
				str(second["atomic_step_gate_receipts"]),
				str(second["contact_release_foot_velocity_world_m_s"]),
				str(second["contact_release_lower_linear_velocity_world_m_s"]),
				str(second["contact_release_lower_angular_velocity_world_rad_s"]),
				str(second["contact_release_torso_linear_velocity_world_m_s"]),
				str(second["contact_release_torso_angular_velocity_world_rad_s"]),
				float(second["semantic_relocation_horizontal_displacement_m"]),
				float(second["semantic_relocation_horizontal_target_error_m"]),
				str(second["semantic_release_recontact_foot_velocity_world_m_s"]),
				str(second["semantic_release_recontact_lower_linear_velocity_world_m_s"]),
				str(second["semantic_release_recontact_lower_angular_velocity_world_rad_s"]),
				str(second["semantic_release_recontact_torso_linear_velocity_world_m_s"]),
				str(second["semantic_release_recontact_torso_angular_velocity_world_rad_s"]),
				int(second["last_semantic_airborne_tick"]),
				str(second["last_semantic_airborne_foot_velocity_world_m_s"]),
				str(second["last_semantic_airborne_lower_linear_velocity_world_m_s"]),
				str(second["last_semantic_airborne_lower_angular_velocity_world_rad_s"]),
				str(second["last_semantic_airborne_torso_linear_velocity_world_m_s"]),
				str(second["last_semantic_airborne_torso_angular_velocity_world_rad_s"]),
				int(second["longest_semantic_contact_absent_dwell_ticks"]),
				int(second["swing_path_progress_ticks"]),
				int(second["maximum_swing_path_progress_ticks"]),
				int(second["disturbance_operation_count"]),
				int(second["semantic_joint_damping_command_tick_count"]),
				float(second["maximum_semantic_joint_damping_command_nm"]),
				float(second["semantic_joint_damping_start_torso_height_m"]),
				float(second["semantic_joint_damping_start_torso_tilt_rad"]),
				str(second["semantic_joint_damping_start_torso_angular_velocity_world_rad_s"]),
				float(second["semantic_swing_joint_rate_norm_at_damping_start_rad_s"]),
				str(second["semantic_joint_rates_at_damping_start_rad_s"]),
				str(result.get("ok", false)),
				str(second["fixture_complete"]),
				String(second["fixture_failure_code"]),
				int(second["executed_ticks"]),
				int(second["three_contact_entry_tick"]),
				float(second["active_minimum_three_contact_handoff_margin_m"]),
				float(second["active_minimum_lift_entry_dynamic_margin_m"]),
				int(second["active_lift_start_tick"]),
				int(second["active_lift_complete_tick"]),
				int(second["active_semantic_relocation_lift_ticks"]),
				int(second["active_semantic_relocation_lower_ticks"]),
				int(second["active_maximum_semantic_recontact_latency_ticks"]),
				float(second["active_maximum_contact_release_task_force_n"]),
				float(second["active_contact_release_target_height_m"]),
				float(second["active_minimum_semantic_release_gap_m"]),
				str(second["active_contact_release_live_horizontal_position_task"]),
				float(second["active_maximum_contact_release_horizontal_damping_force_n"]),
				float(second["maximum_contact_release_horizontal_task_force_n"]),
				float(second["maximum_contact_release_vertical_task_force_n"]),
				str(second["active_contact_release_reaction_compensation_enabled"]),
				String(second["active_contact_release_reaction_compensation_endpoint_direction"]),
				int(second["contact_release_reaction_compensation_command_ticks"]),
				float(second["maximum_contact_release_reaction_compensation_total_force_n"]),
				float(second["maximum_contact_release_reaction_compensation_force_per_support_n"]),
				int(second["active_semantic_relocation_release_velocity_preservation_ticks"]),
				float(second["active_semantic_relocation_release_velocity_preservation_scale"]),
				float(second["active_semantic_relocation_initial_horizontal_target_velocity_m_s"]),
				int(second["active_semantic_relocation_initial_horizontal_target_velocity_ticks"]),
				float(second["active_maximum_semantic_relocation_task_force_n"]),
				float(second["active_semantic_joint_rate_damping_nm_s_per_rad"]),
				float(second["active_maximum_semantic_joint_damping_torque_nm"]),
				str(second["active_rebase_all_joint_pose_references_at_semantic_recontact"]),
				int(second["continuation_semantic_recontact_pose_rebase_count"]),
				int(second["continuation_semantic_recontact_pose_rebase_tick"]),
				int(second["active_semantic_recontact_swing_task_hold_ticks"]),
				int(second["continuation_semantic_recontact_swing_task_command_ticks"]),
				str(second["active_post_recontact_swing_horizontal_damping_enabled"]),
				int(second["active_post_recontact_swing_horizontal_damping_ticks"]),
				float(second["active_post_recontact_swing_horizontal_velocity_gain_ns_per_m"]),
				float(second["active_maximum_post_recontact_swing_horizontal_damping_force_n"]),
				int(second["continuation_recontact_swing_horizontal_damping_command_ticks"]),
				float(second["maximum_continuation_recontact_swing_horizontal_speed_m_s"]),
				float(second["maximum_continuation_recontact_swing_horizontal_damping_force_n"]),
				str(second["active_readmit_recontacted_limb_to_attitude_control"]),
				int(second["continuation_four_contact_attitude_command_ticks"]),
				str(second["active_continuation_recontact_attitude_recovery_enabled"]),
				int(second["continuation_recontact_attitude_recovery_command_ticks"]),
				float(second["maximum_continuation_recontact_roll_pitch_moment_nm"]),
				float(second["maximum_continuation_recontact_yaw_moment_nm"]),
				float(second["maximum_continuation_recontact_yaw_endpoint_force_n"]),
				int(second["active_post_recontact_body_translation_delay_ticks"]),
				int(second["active_minimum_atomic_settling_delay_ticks"]),
				str(second["active_start_body_translation_without_recovery_dwell"]),
				int(second["first_semantic_relocation_command_tick"]),
				str(second["first_semantic_relocation_target_world_m"]),
				str(second["first_semantic_relocation_target_velocity_world_m_s"]),
				str(second["first_semantic_relocation_task_force_world_n"]),
				float(second["lift_entry_com_margin_m"]),
				float(second["lift_entry_capture_margin_m"]),
				float(second["final_torso_height_m"]),
				float(second["final_tilt_rad"]),
				float(second["final_full_speed_rad_s"]),
				str(second["final_torso_angular_velocity_world_rad_s"]),
				str(second["final_all_four_contacts"]),
				str(second["final_bearing_contact_by_limb"]),
				int(second["first_post_recontact_bearing_contact_loss_tick"]),
				str(second["first_post_recontact_bearing_contact_loss_limb_ids"]),
				int(second["torso_contact_ticks"]),
				float(second["maximum_anchor_error_m"]),
				float(second["maximum_hinge_axis_error_rad"]),
				float(second["maximum_applied_torque_nm"]),
				int(second["structural_saturation_count"]),
				int(second["support_allocator_infeasible_count"]),
				float(second["last_support_allocator_authority_scale"]),
				str(second["last_support_allocator_infeasibility_reasons"]),
				float(second["maximum_support_allocator_force_residual_n"]),
				float(second["maximum_support_allocator_moment_residual_nm"]),
				float(second["minimum_support_allocator_normal_reserve_n"]),
				float(second["minimum_support_allocator_friction_reserve_n"]),
			]
		)
	)
	print(
		(
			(
				"release_ramp configured=%d/%.6f commands=%d "
				+ "force_limit_first_last_latch=%.6f/%.6f/%.6f"
			)
			% [
				int(second["active_contact_release_vertical_force_ramp_ticks"]),
				float(second["active_contact_release_vertical_force_ramp_initial_fraction"]),
				int(second["contact_release_vertical_force_ramp_command_ticks"]),
				float(second["first_contact_release_vertical_force_limit_n"]),
				float(second["last_contact_release_vertical_force_limit_n"]),
				float(second["contact_release_vertical_force_limit_at_latch_n"]),
			]
		)
	)
	print(
		(
			(
				"swing_pose_blend configured=%.6f count=%d tick=%d "
				+ "maximum_preblend_applied_rad=%.6f/%.6f"
			)
			% [
				float(second["active_semantic_recontact_swing_pose_reference_blend_fraction"]),
				int(second["continuation_semantic_recontact_swing_pose_blend_count"]),
				int(second["continuation_semantic_recontact_swing_pose_blend_tick"]),
				float(
					second["continuation_semantic_recontact_swing_pose_maximum_preblend_error_rad"]
				),
				float(
					second["continuation_semantic_recontact_swing_pose_maximum_applied_blend_rad"]
				),
			]
		)
	)
	print(
		(
			(
				"gait_airborne_advance configured=%.6f/%d commands=%d ticks=%d/%d "
				+ "maximum_target=%.6f com_start=%s com_last=%s com_displacement=%s"
			)
			% [
				float(second["active_gait_airborne_body_advance_m"]),
				int(second["active_gait_airborne_body_advance_ramp_ticks"]),
				int(second["continuation_gait_airborne_body_advance_command_ticks"]),
				int(second["continuation_gait_airborne_body_advance_first_tick"]),
				int(second["continuation_gait_airborne_body_advance_last_tick"]),
				float(second["maximum_continuation_gait_airborne_body_advance_target_m"]),
				str(second["continuation_gait_airborne_body_advance_start_com_world_m"]),
				str(second["continuation_gait_airborne_body_advance_last_com_world_m"]),
				str(second["continuation_gait_airborne_body_advance_com_displacement_world_m"]),
			]
		)
	)
	Engine.physics_ticks_per_second = original_hz
	quit(0 if bool(result["same_world_sequential_atomic_steps_observed"]) else 2)
