class_name LabCanonicalSpatialCentroidalContactRig
extends "res://scripts/lab/rigs/canonical_spatial_protective_contact_rig.gd"
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BR14A.5 second-candidate rejection fixture for a measured-state controller.
##
## The rig preserves the exact physical construction used by BR14A.3-BR14A.5
## candidate 1. New authority is limited to a read-only dynamic support
## observer, bounded stance-endpoint commands, and a damped-least-squares
## swing map feeding the existing receipt-backed equal/opposite joint-torque
## path. It does not measure or allocate physical contact load.

const DynamicSupportObserverScript := preload(
	"res://scripts/lab/mechanics/spatial_dynamic_support_observer.gd"
)
const CentroidalSupportControllerScript := preload(
	"res://scripts/lab/mechanics/spatial_centroidal_support_controller.gd"
)
const WHOLE_SYSTEM_ALLOCATOR_CONTROLLER_ID := "whole_system_allocator_joint_task_delta_v1"
const FEASIBILITY_GATED_ALLOCATOR_CONTROLLER_ID := "predictive_feasibility_gated_whole_system_allocator_v1"
const UNLOAD_THEN_LIFT_ALLOCATOR_CONTROLLER_ID := "predictive_unload_then_lift_allocator_v1"
const CONTACT_STATE_LIFT_ALLOCATOR_CONTROLLER_ID := "predictive_contact_state_lift_allocator_v1"
const SEMANTIC_RELEASE_RECONTACT_ALLOCATOR_CONTROLLER_ID := "predictive_semantic_release_recontact_allocator_v1"
const SEMANTIC_RELOCATION_RECONTACT_CONTROLLER_ID := "measured_semantic_relocation_recontact_v1"
const SEMANTIC_RECONTACT_JOINT_DAMPING_CONTROLLER_ID := "measured_semantic_recontact_joint_damping_v1"
const POST_RECONTACT_BODY_TRANSLATION_CONTROLLER_ID := "post_recontact_body_translation_v1"
const DEFAULT_SAME_WORLD_CONTINUATION_POLICY := {
	"readiness_target_margin_m": 0.047,
	"maximum_readiness_target_shift_m": 0.060,
	"hold_bounded_readiness_target_during_airborne_phase": true,
	"resume_support_after_semantic_recontact": true,
	"minimum_continuation_semantic_relocation_m": 0.0130,
	"maximum_continuation_semantic_relocation_target_error_m": 0.0125,
	"maximum_continuation_translation_foot_slip_m": 0.0140,
	"minimum_continuation_final_foot_relocation_m": 0.0300,
	"minimum_continuation_three_contact_handoff_margin_m": 0.0190,
	"minimum_continuation_lift_entry_dynamic_margin_m": 0.0190,
	"semantic_relocation_lift_ticks": 6,
	"semantic_relocation_lower_ticks": 10,
	"maximum_semantic_recontact_latency_ticks": 20,
	"maximum_contact_release_task_force_n": 20.0,
	"contact_release_vertical_force_ramp_ticks": 0,
	"contact_release_vertical_force_ramp_initial_fraction": 1.0,
	"gait_airborne_body_advance_m": 0.0,
	"gait_airborne_body_advance_ramp_ticks": 8,
	"minimum_semantic_release_gap_m": 0.002,
	"contact_release_target_height_offset_m": 0.030,
	"contact_release_live_horizontal_position_task": true,
	"maximum_contact_release_horizontal_damping_force_n": 4.0,
	"contact_release_reaction_compensation_enabled": false,
	"contact_release_reaction_compensation_endpoint_direction": "down",
	"maximum_contact_release_reaction_compensation_force_per_support_n": 7.0,
	"semantic_relocation_release_velocity_preservation_ticks": 0,
	"semantic_relocation_release_velocity_preservation_scale": 0.0,
	"semantic_relocation_initial_horizontal_target_velocity_m_s": 0.34,
	"semantic_relocation_initial_horizontal_target_velocity_ticks": 2,
	"maximum_semantic_relocation_task_force_n": 24.0,
	"semantic_joint_rate_damping_nm_s_per_rad": 0.20,
	"maximum_semantic_joint_damping_torque_nm": 0.5,
	"rebase_all_joint_pose_references_at_semantic_recontact": false,
	"semantic_recontact_swing_pose_reference_blend_fraction": 0.0,
	"semantic_recontact_swing_task_hold_ticks": 0,
	"post_recontact_swing_horizontal_damping_enabled": false,
	"post_recontact_swing_horizontal_damping_ticks": 20,
	"post_recontact_swing_horizontal_velocity_gain_ns_per_m": 20.0,
	"maximum_post_recontact_swing_horizontal_damping_force_n": 4.0,
	"readmit_recontacted_limb_to_attitude_control": false,
	"continuation_recontact_attitude_recovery_enabled": false,
	"continuation_recontact_attitude_position_gain_nm_per_rad": 40.0,
	"continuation_recontact_attitude_velocity_gain_nm_s_per_rad": 8.0,
	"maximum_continuation_recontact_roll_pitch_moment_nm": 5.0,
	"continuation_recontact_yaw_velocity_gain_nm_s_per_rad": 2.0,
	"maximum_continuation_recontact_yaw_moment_nm": 1.0,
	"maximum_continuation_recontact_yaw_endpoint_force_n": 2.0,
	"early_contact_consistent_posture_recovery_enabled": true,
	"early_contact_consistent_posture_recovery_duration_ticks": 240,
	"early_contact_consistent_posture_recovery_limb_scope": "all_bearing",
	"early_contact_consistent_posture_attitude_reference_enabled": true,
	"early_contact_consistent_posture_attitude_reference_duration_ticks": 240,
	"early_contact_consistent_posture_maximum_endpoint_speed_m_s": 0.025,
	"early_contact_consistent_posture_reference_rate_scale": 1.00,
	"early_contact_consistent_posture_maximum_accumulated_joint_rotation_rad": 0.22,
	"minimum_body_translation_recovery_torso_height_m": 0.37,
	"maximum_body_translation_recovery_tilt_rad": 0.08,
	"maximum_body_translation_recovery_angular_speed_rad_s": 0.15,
	"minimum_body_translation_recovery_dwell_ticks": 60,
	"continuation_trial_extension_ticks": 1900,
	"continuation_body_translation_start_delay_ticks": 600,
	"start_body_translation_without_recovery_dwell": false,
	"rebase_joint_pose_reference_at_body_translation_handoff": true,
	"exclude_recontacted_limb_from_body_translation_support": true,
	"body_translation_command_ticks": 900,
	"body_translation_target_scale": 0.60,
	"post_translation_stabilization_enabled": true,
	"post_translation_stabilization_ramp_ticks": 240,
	"contact_consistent_posture_recovery_enabled": true,
	"contact_consistent_posture_position_gain_per_s": 1.50,
	"contact_consistent_posture_dls_damping_m": 0.030,
	"contact_consistent_posture_maximum_endpoint_speed_m_s": 0.025,
	"contact_consistent_posture_maximum_joint_reference_rate_rad_s": 0.25,
	"contact_consistent_posture_maximum_accumulated_joint_rotation_rad": 0.22,
	"contact_consistent_posture_height_deadband_m": 0.007,
	"contact_consistent_posture_target_height_margin_m": 0.010,
	"contact_consistent_posture_horizontal_position_gain_per_s": 0.80,
	"contact_consistent_posture_horizontal_velocity_damping": 0.20,
	"contact_consistent_posture_maximum_horizontal_speed_m_s": 0.020,
	"contact_consistent_posture_attitude_position_gain_per_s": 0.80,
	"contact_consistent_posture_attitude_velocity_damping": 0.20,
	"contact_consistent_posture_maximum_attitude_speed_rad_s": 0.120,
	"contact_consistent_posture_maximum_twist_endpoint_speed_m_s": 0.050,
	"contact_consistent_posture_latch_horizontal_error_m": 0.004,
	"contact_consistent_posture_latch_tilt_rad": 0.045,
	"contact_consistent_posture_latch_dwell_ticks": 20,
	"posture_settle_joint_damping_gain_nm_s_per_rad": 0.50,
	"posture_settle_maximum_joint_damping_torque_nm": 1.00,
}


func run_same_world_atomic_step_sequence(
	tree: SceneTree,
	profile: Dictionary,
	first_experiment: Dictionary,
	second_experiment: Dictionary,
	seed: int,
	second_development_tick_limit: int = -1,
	continuation_policy_overrides: Dictionary = {}
) -> Dictionary:
	if (
		String(first_experiment.get("swing_limb_id", "")) != "front_right"
		or String(second_experiment.get("swing_limb_id", "")) != "rear_left"
		or not bool(first_experiment.get("locomotor_step_claim_allowed", false))
		or not bool(second_experiment.get("locomotor_step_claim_allowed", false))
	):
		return {
			"ok": false,
			"failure_code": "SPATIAL_CENTROIDAL_ATOMIC_STEP_SEQUENCE_CONTRACT_INVALID",
		}
	var active_continuation_policy := DEFAULT_SAME_WORLD_CONTINUATION_POLICY.duplicate(true)
	for override_key: Variant in continuation_policy_overrides:
		if not active_continuation_policy.has(override_key):
			return {
				"ok": false,
				"failure_code": "SPATIAL_CENTROIDAL_CONTINUATION_POLICY_OVERRIDE_INVALID",
				"invalid_override_key": override_key,
			}
		active_continuation_policy[override_key] = continuation_policy_overrides[override_key]
	var first_result := await run_centroidal_contact_trial(
		tree, profile, first_experiment, seed, true, -1, {}, true, {}
	)
	if not first_result.has("summary") or not first_result.has("fixture"):
		return {
			"ok": false,
			"failure_code": "SPATIAL_CENTROIDAL_FIRST_ATOMIC_STEP_RESULT_INCOMPLETE",
			"first_result": first_result,
		}
	var first_summary: Dictionary = first_result["summary"]
	var fixture: Dictionary = first_result["fixture"]
	var first_step_passed := (
		bool(first_result.get("ok", false))
		and bool(first_summary.get("bounded_atomic_locomotor_step_observed", false))
		and bool(first_summary.get("locomotor_step_established", false))
	)
	if not first_step_passed:
		await _release_preserved_fixture(tree, fixture)
		return {
			"ok": false,
			"failure_code": "SPATIAL_CENTROIDAL_FIRST_ATOMIC_STEP_NOT_ESTABLISHED",
			"first_summary": first_summary,
		}
	var preserved_viewport: SubViewport = fixture["viewport"]
	var preserved_world: Node3D = fixture["world"]
	var preserved_torso: RigidBody3D = fixture["torso"]
	var viewport_instance_id := preserved_viewport.get_instance_id()
	var world_instance_id := preserved_world.get_instance_id()
	var torso_instance_id := preserved_torso.get_instance_id()
	var second_result := await run_centroidal_contact_trial(
		tree,
		profile,
		second_experiment,
		seed,
		true,
		second_development_tick_limit,
		fixture,
		false,
		active_continuation_policy
	)
	if not second_result.has("summary"):
		await _release_preserved_fixture(tree, fixture)
		return {
			"ok": false,
			"failure_code": "SPATIAL_CENTROIDAL_SECOND_ATOMIC_STEP_RESULT_INCOMPLETE",
			"first_summary": first_summary,
			"second_result": second_result,
		}
	var second_summary: Dictionary = second_result["summary"]
	var same_world_receipt := (
		int(first_summary["viewport_instance_id"]) == viewport_instance_id
		and int(first_summary["world_instance_id"]) == world_instance_id
		and int(first_summary["torso_instance_id"]) == torso_instance_id
		and int(second_summary["viewport_instance_id"]) == viewport_instance_id
		and int(second_summary["world_instance_id"]) == world_instance_id
		and int(second_summary["torso_instance_id"]) == torso_instance_id
		and not bool(first_summary["fixture_reused"])
		and bool(first_summary["fixture_preserved"])
		and bool(second_summary["fixture_reused"])
		and not bool(second_summary["fixture_preserved"])
	)
	var first_executed_ticks := int(first_summary["executed_ticks"])
	var second_release_global_tick := (
		first_executed_ticks + int(second_summary["contact_release_first_tick"])
	)
	var second_recontact_global_tick := (
		first_executed_ticks + int(second_summary["semantic_release_recontact_tick"])
	)
	var cumulative_com_translation: Vector3 = (
		first_summary["whole_system_com_horizontal_displacement_world_m"]
		+ second_summary["whole_system_com_horizontal_displacement_world_m"]
	)
	var cumulative_torso_translation: Vector3 = (
		first_summary["torso_horizontal_displacement_world_m"]
		+ second_summary["torso_horizontal_displacement_world_m"]
	)
	var cumulative_post_recontact_com_translation: Vector3 = (
		first_summary["post_recontact_body_translation_com_displacement_world_m"]
		+ second_summary["post_recontact_body_translation_com_displacement_world_m"]
	)
	var cumulative_post_recontact_torso_translation: Vector3 = (
		first_summary["post_recontact_body_translation_torso_displacement_world_m"]
		+ second_summary["post_recontact_body_translation_torso_displacement_world_m"]
	)
	var second_step_passed := (
		bool(second_result.get("ok", false))
		and bool(second_summary.get("bounded_atomic_locomotor_step_observed", false))
		and bool(second_summary.get("locomotor_step_established", false))
	)
	var sequence_observed := (
		first_step_passed
		and second_step_passed
		and same_world_receipt
		and second_release_global_tick > first_executed_ticks
		and second_recontact_global_tick > second_release_global_tick
	)
	return {
		"ok": bool(first_result.get("ok", false)) and bool(second_result.get("ok", false)),
		"failure_code":
		(
			""
			if sequence_observed
			else "SPATIAL_CENTROIDAL_SAME_WORLD_ATOMIC_STEP_SEQUENCE_NOT_ESTABLISHED"
		),
		"seed": seed,
		"phase_count": 2,
		"continuation_boundary_count": 1,
		"controller_timeline_restart_count": 1,
		"world_state_reset_count": 0,
		"world_build_count": 1,
		"continuation_policy": active_continuation_policy.duplicate(true),
		"same_world_receipt": same_world_receipt,
		"same_world_sequential_atomic_steps_observed": sequence_observed,
		"first_summary": first_summary,
		"second_summary": second_summary,
		"second_release_global_tick": second_release_global_tick,
		"second_recontact_global_tick": second_recontact_global_tick,
		"cumulative_com_translation_world_m": cumulative_com_translation,
		"cumulative_torso_translation_world_m": cumulative_torso_translation,
		"cumulative_post_recontact_com_translation_world_m":
		cumulative_post_recontact_com_translation,
		"cumulative_post_recontact_torso_translation_world_m":
		cumulative_post_recontact_torso_translation,
		"step_gait_or_walking_established": false,
		"automatic_creature_guidance_allowed": false,
	}


func run_centroidal_contact_trial(
	tree: SceneTree,
	profile: Dictionary,
	experiment: Dictionary,
	seed: int,
	touchdown_enabled: bool,
	development_tick_limit: int = -1,
	existing_fixture: Dictionary = {},
	preserve_fixture: bool = false,
	continuation_policy: Dictionary = {}
) -> Dictionary:
	var fixture_reused := not existing_fixture.is_empty()
	var viewport: SubViewport
	var world: Node3D
	var floor: StaticBody3D
	var torso: RigidBody3D
	var body_by_id: Dictionary
	var limbs: Array
	var joint_nodes: Array
	if fixture_reused:
		viewport = existing_fixture.get("viewport") as SubViewport
		world = existing_fixture.get("world") as Node3D
		floor = existing_fixture.get("floor") as StaticBody3D
		torso = existing_fixture.get("torso") as RigidBody3D
		body_by_id = existing_fixture.get("body_by_id", {})
		limbs = existing_fixture.get("limbs", [])
		joint_nodes = existing_fixture.get("joint_nodes", [])
		var fixture_identity_valid := (
			is_instance_valid(viewport)
			and is_instance_valid(world)
			and is_instance_valid(floor)
			and is_instance_valid(torso)
			and String(existing_fixture.get("profile_id", "")) == String(profile["profile_id"])
			and int(existing_fixture.get("seed", -1)) == seed
			and body_by_id.size() == 9
			and limbs.size() == 4
			and joint_nodes.size() == 8
		)
		if not fixture_identity_valid:
			return {
				"ok": false,
				"failure_code": "SPATIAL_CENTROIDAL_CONTINUATION_FIXTURE_INVALID",
			}
		if (
			not continuation_policy.has("readiness_target_margin_m")
			or not continuation_policy.has("maximum_readiness_target_shift_m")
			or not continuation_policy.has("hold_bounded_readiness_target_during_airborne_phase")
			or not continuation_policy.has("resume_support_after_semantic_recontact")
			or not continuation_policy.has("minimum_continuation_semantic_relocation_m")
			or not continuation_policy.has(
				"maximum_continuation_semantic_relocation_target_error_m"
			)
			or not continuation_policy.has("maximum_continuation_translation_foot_slip_m")
			or not continuation_policy.has("minimum_continuation_final_foot_relocation_m")
			or not continuation_policy.has("minimum_continuation_three_contact_handoff_margin_m")
			or not continuation_policy.has("minimum_continuation_lift_entry_dynamic_margin_m")
			or not continuation_policy.has("semantic_relocation_lift_ticks")
			or not continuation_policy.has("semantic_relocation_lower_ticks")
			or not continuation_policy.has("maximum_semantic_recontact_latency_ticks")
			or not continuation_policy.has("maximum_contact_release_task_force_n")
			or not continuation_policy.has("contact_release_vertical_force_ramp_ticks")
			or not continuation_policy.has("contact_release_vertical_force_ramp_initial_fraction")
			or not continuation_policy.has("gait_airborne_body_advance_m")
			or not continuation_policy.has("gait_airborne_body_advance_ramp_ticks")
			or not continuation_policy.has("minimum_semantic_release_gap_m")
			or not continuation_policy.has("contact_release_target_height_offset_m")
			or not continuation_policy.has("contact_release_live_horizontal_position_task")
			or not continuation_policy.has("maximum_contact_release_horizontal_damping_force_n")
			or not continuation_policy.has("contact_release_reaction_compensation_enabled")
			or not continuation_policy.has(
				"contact_release_reaction_compensation_endpoint_direction"
			)
			or not continuation_policy.has(
				"maximum_contact_release_reaction_compensation_force_per_support_n"
			)
			or not continuation_policy.has(
				"semantic_relocation_release_velocity_preservation_ticks"
			)
			or not continuation_policy.has(
				"semantic_relocation_release_velocity_preservation_scale"
			)
			or not continuation_policy.has(
				"semantic_relocation_initial_horizontal_target_velocity_m_s"
			)
			or not continuation_policy.has(
				"semantic_relocation_initial_horizontal_target_velocity_ticks"
			)
			or not continuation_policy.has("maximum_semantic_relocation_task_force_n")
			or not continuation_policy.has("semantic_joint_rate_damping_nm_s_per_rad")
			or not continuation_policy.has("maximum_semantic_joint_damping_torque_nm")
			or not continuation_policy.has("rebase_all_joint_pose_references_at_semantic_recontact")
			or not continuation_policy.has("semantic_recontact_swing_pose_reference_blend_fraction")
			or not continuation_policy.has("semantic_recontact_swing_task_hold_ticks")
			or not continuation_policy.has("post_recontact_swing_horizontal_damping_enabled")
			or not continuation_policy.has("post_recontact_swing_horizontal_damping_ticks")
			or not continuation_policy.has("post_recontact_swing_horizontal_velocity_gain_ns_per_m")
			or not continuation_policy.has(
				"maximum_post_recontact_swing_horizontal_damping_force_n"
			)
			or not continuation_policy.has("readmit_recontacted_limb_to_attitude_control")
			or not continuation_policy.has("continuation_recontact_attitude_recovery_enabled")
			or not continuation_policy.has(
				"continuation_recontact_attitude_position_gain_nm_per_rad"
			)
			or not continuation_policy.has(
				"continuation_recontact_attitude_velocity_gain_nm_s_per_rad"
			)
			or not continuation_policy.has("maximum_continuation_recontact_roll_pitch_moment_nm")
			or not continuation_policy.has("continuation_recontact_yaw_velocity_gain_nm_s_per_rad")
			or not continuation_policy.has("maximum_continuation_recontact_yaw_moment_nm")
			or not continuation_policy.has("maximum_continuation_recontact_yaw_endpoint_force_n")
			or not continuation_policy.has("early_contact_consistent_posture_recovery_enabled")
			or not continuation_policy.has(
				"early_contact_consistent_posture_recovery_duration_ticks"
			)
			or not continuation_policy.has("early_contact_consistent_posture_recovery_limb_scope")
			or not continuation_policy.has(
				"early_contact_consistent_posture_attitude_reference_enabled"
			)
			or not continuation_policy.has(
				"early_contact_consistent_posture_attitude_reference_duration_ticks"
			)
			or not continuation_policy.has(
				"early_contact_consistent_posture_maximum_endpoint_speed_m_s"
			)
			or not continuation_policy.has("early_contact_consistent_posture_reference_rate_scale")
			or not continuation_policy.has(
				"early_contact_consistent_posture_maximum_accumulated_joint_rotation_rad"
			)
			or not continuation_policy.has("minimum_body_translation_recovery_torso_height_m")
			or not continuation_policy.has("maximum_body_translation_recovery_tilt_rad")
			or not continuation_policy.has("maximum_body_translation_recovery_angular_speed_rad_s")
			or not continuation_policy.has("minimum_body_translation_recovery_dwell_ticks")
			or not continuation_policy.has("continuation_trial_extension_ticks")
			or not continuation_policy.has("continuation_body_translation_start_delay_ticks")
			or not continuation_policy.has("start_body_translation_without_recovery_dwell")
			or not continuation_policy.has(
				"rebase_joint_pose_reference_at_body_translation_handoff"
			)
			or not continuation_policy.has("exclude_recontacted_limb_from_body_translation_support")
			or not continuation_policy.has("body_translation_command_ticks")
			or not continuation_policy.has("body_translation_target_scale")
			or not continuation_policy.has("post_translation_stabilization_enabled")
			or not continuation_policy.has("post_translation_stabilization_ramp_ticks")
			or not continuation_policy.has("contact_consistent_posture_recovery_enabled")
			or not continuation_policy.has("contact_consistent_posture_position_gain_per_s")
			or not continuation_policy.has("contact_consistent_posture_dls_damping_m")
			or not continuation_policy.has("contact_consistent_posture_maximum_endpoint_speed_m_s")
			or not continuation_policy.has(
				"contact_consistent_posture_maximum_joint_reference_rate_rad_s"
			)
			or not continuation_policy.has(
				"contact_consistent_posture_maximum_accumulated_joint_rotation_rad"
			)
			or not continuation_policy.has("contact_consistent_posture_height_deadband_m")
			or not continuation_policy.has("contact_consistent_posture_target_height_margin_m")
			or not continuation_policy.has(
				"contact_consistent_posture_horizontal_position_gain_per_s"
			)
			or not continuation_policy.has("contact_consistent_posture_horizontal_velocity_damping")
			or not continuation_policy.has(
				"contact_consistent_posture_maximum_horizontal_speed_m_s"
			)
			or not continuation_policy.has(
				"contact_consistent_posture_attitude_position_gain_per_s"
			)
			or not continuation_policy.has("contact_consistent_posture_attitude_velocity_damping")
			or not continuation_policy.has(
				"contact_consistent_posture_maximum_attitude_speed_rad_s"
			)
			or not continuation_policy.has(
				"contact_consistent_posture_maximum_twist_endpoint_speed_m_s"
			)
			or not continuation_policy.has("contact_consistent_posture_latch_horizontal_error_m")
			or not continuation_policy.has("contact_consistent_posture_latch_tilt_rad")
			or not continuation_policy.has("contact_consistent_posture_latch_dwell_ticks")
			or not continuation_policy.has("posture_settle_joint_damping_gain_nm_s_per_rad")
			or not continuation_policy.has("posture_settle_maximum_joint_damping_torque_nm")
			or int(continuation_policy.get("contact_release_vertical_force_ramp_ticks", -1)) < 0
			or (
				float(
					continuation_policy.get(
						"contact_release_vertical_force_ramp_initial_fraction", -1.0
					)
				)
				< 0.0
			)
			or (
				float(
					continuation_policy.get(
						"contact_release_vertical_force_ramp_initial_fraction", 2.0
					)
				)
				> 1.0
			)
			or (
				float(
					continuation_policy.get(
						"semantic_recontact_swing_pose_reference_blend_fraction", -1.0
					)
				)
				< 0.0
			)
			or (
				float(
					continuation_policy.get(
						"semantic_recontact_swing_pose_reference_blend_fraction", 2.0
					)
				)
				> 1.0
			)
			or float(continuation_policy.get("gait_airborne_body_advance_m", -1.0)) < 0.0
			or float(continuation_policy.get("gait_airborne_body_advance_m", 1.0)) > 0.015
			or int(continuation_policy.get("gait_airborne_body_advance_ramp_ticks", 0)) <= 0
			or (
				String(
					continuation_policy.get(
						"contact_release_reaction_compensation_endpoint_direction", ""
					)
				)
				!= "down"
			)
			or (
				float(
					continuation_policy.get(
						"maximum_contact_release_reaction_compensation_force_per_support_n", 0.0
					)
				)
				<= 0.0
			)
			or (
				int(
					continuation_policy.get(
						"early_contact_consistent_posture_recovery_duration_ticks", 0
					)
				)
				<= 0
			)
			or (
				int(continuation_policy.get("post_recontact_swing_horizontal_damping_ticks", 0))
				<= 0
			)
			or (
				float(
					continuation_policy.get(
						"post_recontact_swing_horizontal_velocity_gain_ns_per_m", 0.0
					)
				)
				<= 0.0
			)
			or (
				float(
					continuation_policy.get(
						"maximum_post_recontact_swing_horizontal_damping_force_n", 0.0
					)
				)
				<= 0.0
			)
			or (
				String(
					continuation_policy.get(
						"early_contact_consistent_posture_recovery_limb_scope", ""
					)
				)
				!= "all_bearing"
			)
		):
			return {
				"ok": false,
				"failure_code": "SPATIAL_CENTROIDAL_CONTINUATION_POLICY_INVALID",
			}
	else:
		viewport = SubViewport.new()
		viewport.name = (
			"BR14A_Centroidal_%d_%s"
			% [seed, "active" if touchdown_enabled else "hold_clear_control"]
		)
		viewport.size = Vector2i(1, 1)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		tree.root.add_child(viewport)
		world = Node3D.new()
		world.name = "BR14ACanonicalSpatialCentroidalContactWorld"
		floor = _build_floor(float(profile["contact_friction_coefficient"]))
		torso = _build_torso(profile["torso"])
		body_by_id = {TORSO_ID: torso}
		limbs = []
		joint_nodes = []
		for limb_value in profile["limbs"]:
			var limb := _build_limb(limb_value, float(profile["contact_friction_coefficient"]))
			torso.add_collision_exception_with(limb["upper"])
			(limb["upper"] as RigidBody3D).add_collision_exception_with(torso)
			limbs.append(limb)
			body_by_id[String(limb["upper_id"])] = limb["upper"]
			body_by_id[String(limb["lower_id"])] = limb["lower"]
			joint_nodes.append(limb["hip_joint"])
			joint_nodes.append(limb["knee_joint"])
		for node in [torso, floor]:
			world.add_child(node)
		for limb_value in limbs:
			var limb: Dictionary = limb_value
			for node in [
				limb["upper"],
				limb["lower"],
				limb["hip_joint"],
				limb["knee_joint"],
			]:
				world.add_child(node)
		viewport.add_child(world)
		for limb_value in limbs:
			var limb: Dictionary = limb_value
			var hip: Generic6DOFJoint3D = limb["hip_joint"]
			var knee: HingeJoint3D = limb["knee_joint"]
			hip.node_a = hip.get_path_to(torso)
			hip.node_b = hip.get_path_to(limb["upper"])
			knee.node_a = knee.get_path_to(limb["upper"])
			knee.node_b = knee.get_path_to(limb["lower"])
		await tree.process_frame
		await tree.physics_frame
		_capture_rest_state(torso, limbs)
		for body_value in body_by_id.values():
			var body: RigidBody3D = body_value
			body.freeze = false
			body.sleeping = false
		var seed_perturbation := float((seed % 3) - 1) * 0.008
		torso.angular_velocity = Vector3(seed_perturbation, 0.0, -0.5 * seed_perturbation)
		await tree.physics_frame
	var swing_limb: Dictionary = {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		if String(limb["limb_id"]) == String(experiment["swing_limb_id"]):
			swing_limb = limb
	if swing_limb.is_empty():
		if not fixture_reused or not preserve_fixture:
			viewport.queue_free()
		return {"ok": false, "failure_code": "SPATIAL_CENTROIDAL_SWING_LIMB_MISSING"}
	var receipt_sink = ReceiptSinkScript.new(
		"br14a_centroidal_%d_%s" % [seed, "active" if touchdown_enabled else "control"]
	)
	var trial_ticks := int(experiment["trial_ticks"])
	if fixture_reused:
		trial_ticks += int(continuation_policy["continuation_trial_extension_ticks"])
	var executed_tick_limit := (
		trial_ticks if development_tick_limit < 0 else mini(trial_ticks, development_tick_limit)
	)
	var shift_start_tick := int(experiment["weight_shift_start_tick"])
	var shift_complete_tick := int(experiment["weight_shift_complete_tick"])
	var lift_start_tick := int(experiment["lift_start_tick"])
	var lift_complete_tick := int(experiment["lift_complete_tick"])
	var disturbance_tick := int(experiment["disturbance_tick"])
	var landing_start_tick := int(experiment["landing_start_tick"])
	var landing_alignment_complete_tick := int(experiment["landing_alignment_complete_tick"])
	var landing_complete_tick := int(experiment["landing_target_complete_tick"])
	var touchdown_deadline_tick := int(experiment["touchdown_deadline_tick"])
	var recenter_start_tick := int(experiment["support_recenter_start_tick"])
	var recenter_complete_tick := int(experiment["support_recenter_complete_tick"])
	var step_s := 1.0 / float(profile["physics_hz"])
	var feasibility_gated_swing := (
		String(experiment["centroidal_controller_id"])
		in [
			FEASIBILITY_GATED_ALLOCATOR_CONTROLLER_ID,
			UNLOAD_THEN_LIFT_ALLOCATOR_CONTROLLER_ID,
			CONTACT_STATE_LIFT_ALLOCATOR_CONTROLLER_ID,
			SEMANTIC_RELEASE_RECONTACT_ALLOCATOR_CONTROLLER_ID,
			SEMANTIC_RELOCATION_RECONTACT_CONTROLLER_ID,
			SEMANTIC_RECONTACT_JOINT_DAMPING_CONTROLLER_ID,
			POST_RECONTACT_BODY_TRANSLATION_CONTROLLER_ID,
		]
	)
	var unload_then_lift_enabled := (
		String(experiment["centroidal_controller_id"])
		in [
			UNLOAD_THEN_LIFT_ALLOCATOR_CONTROLLER_ID,
			CONTACT_STATE_LIFT_ALLOCATOR_CONTROLLER_ID,
			SEMANTIC_RELEASE_RECONTACT_ALLOCATOR_CONTROLLER_ID,
			SEMANTIC_RELOCATION_RECONTACT_CONTROLLER_ID,
			SEMANTIC_RECONTACT_JOINT_DAMPING_CONTROLLER_ID,
			POST_RECONTACT_BODY_TRANSLATION_CONTROLLER_ID,
		]
	)
	var contact_state_lift_enabled := (
		String(experiment["centroidal_controller_id"]) == CONTACT_STATE_LIFT_ALLOCATOR_CONTROLLER_ID
	)
	var semantic_release_recontact_enabled := (
		String(experiment["centroidal_controller_id"])
		in [
			SEMANTIC_RELEASE_RECONTACT_ALLOCATOR_CONTROLLER_ID,
			SEMANTIC_RELOCATION_RECONTACT_CONTROLLER_ID,
			SEMANTIC_RECONTACT_JOINT_DAMPING_CONTROLLER_ID,
			POST_RECONTACT_BODY_TRANSLATION_CONTROLLER_ID,
		]
	)
	var semantic_relocation_recontact_enabled := (
		String(experiment["centroidal_controller_id"])
		in [
			SEMANTIC_RELOCATION_RECONTACT_CONTROLLER_ID,
			SEMANTIC_RECONTACT_JOINT_DAMPING_CONTROLLER_ID,
			POST_RECONTACT_BODY_TRANSLATION_CONTROLLER_ID,
		]
	)
	var semantic_recontact_joint_damping_enabled := (
		String(experiment["centroidal_controller_id"])
		in [
			SEMANTIC_RECONTACT_JOINT_DAMPING_CONTROLLER_ID,
			POST_RECONTACT_BODY_TRANSLATION_CONTROLLER_ID,
		]
	)
	var post_recontact_body_translation_enabled := (
		String(experiment["centroidal_controller_id"])
		== POST_RECONTACT_BODY_TRANSLATION_CONTROLLER_ID
	)
	var minimum_semantic_relocation_m := float(
		experiment.get("minimum_semantic_relocation_horizontal_displacement_m", 0.0)
	)
	var minimum_semantic_release_gap_m := float(
		experiment.get("minimum_semantic_release_gap_m", 0.0)
	)
	var maximum_semantic_relocation_target_error_m := float(
		experiment.get("maximum_semantic_relocation_horizontal_target_error_m", INF)
	)
	var maximum_translation_foot_slip_m := float(
		experiment.get("maximum_post_recontact_foot_slip_m", INF)
	)
	var minimum_final_foot_relocation_m := float(
		experiment.get("minimum_atomic_final_foot_relocation_m", 0.0)
	)
	var minimum_three_contact_handoff_margin_m := float(
		experiment.get("minimum_three_contact_handoff_margin_m", -INF)
	)
	var minimum_lift_entry_dynamic_margin_m := float(
		experiment.get("minimum_lift_entry_dynamic_margin_m", -INF)
	)
	var semantic_relocation_lift_ticks := int(experiment.get("semantic_relocation_lift_ticks", 0))
	var semantic_relocation_lower_ticks := int(experiment.get("semantic_relocation_lower_ticks", 0))
	var maximum_semantic_recontact_latency_ticks := int(
		experiment.get("maximum_semantic_recontact_latency_ticks", 0)
	)
	var maximum_contact_release_task_force_n := float(
		experiment.get("maximum_contact_release_task_force_n", 0.0)
	)
	var contact_release_vertical_force_ramp_ticks := 0
	var contact_release_vertical_force_ramp_initial_fraction := 1.0
	var gait_airborne_body_advance_m := 0.0
	var gait_airborne_body_advance_ramp_ticks := 1
	var active_maximum_semantic_relocation_task_force_n := float(
		experiment.get("maximum_semantic_relocation_task_force_n", 0.0)
	)
	var active_post_recontact_body_translation_delay_ticks := int(
		experiment.get("post_recontact_body_translation_delay_ticks", 0)
	)
	var active_minimum_atomic_settling_delay_ticks := int(
		experiment.get("minimum_atomic_settling_delay_ticks", 0)
	)
	if fixture_reused:
		active_post_recontact_body_translation_delay_ticks = int(
			continuation_policy["continuation_body_translation_start_delay_ticks"]
		)
		active_minimum_atomic_settling_delay_ticks = (active_post_recontact_body_translation_delay_ticks)
	var active_semantic_joint_rate_damping_nm_s_per_rad := float(
		experiment.get("semantic_joint_rate_damping_nm_s_per_rad", 0.0)
	)
	var active_maximum_semantic_joint_damping_torque_nm := float(
		experiment.get("maximum_semantic_joint_damping_torque_nm", 0.0)
	)
	if fixture_reused:
		minimum_semantic_release_gap_m = float(
			continuation_policy["minimum_semantic_release_gap_m"]
		)
		minimum_semantic_relocation_m = float(
			continuation_policy["minimum_continuation_semantic_relocation_m"]
		)
		maximum_semantic_relocation_target_error_m = float(
			continuation_policy["maximum_continuation_semantic_relocation_target_error_m"]
		)
		maximum_translation_foot_slip_m = float(
			continuation_policy["maximum_continuation_translation_foot_slip_m"]
		)
		minimum_final_foot_relocation_m = float(
			continuation_policy["minimum_continuation_final_foot_relocation_m"]
		)
		minimum_three_contact_handoff_margin_m = float(
			continuation_policy["minimum_continuation_three_contact_handoff_margin_m"]
		)
		minimum_lift_entry_dynamic_margin_m = float(
			continuation_policy["minimum_continuation_lift_entry_dynamic_margin_m"]
		)
		semantic_relocation_lift_ticks = int(continuation_policy["semantic_relocation_lift_ticks"])
		semantic_relocation_lower_ticks = int(
			continuation_policy["semantic_relocation_lower_ticks"]
		)
		maximum_semantic_recontact_latency_ticks = int(
			continuation_policy["maximum_semantic_recontact_latency_ticks"]
		)
		maximum_contact_release_task_force_n = float(
			continuation_policy["maximum_contact_release_task_force_n"]
		)
		contact_release_vertical_force_ramp_ticks = int(
			continuation_policy["contact_release_vertical_force_ramp_ticks"]
		)
		contact_release_vertical_force_ramp_initial_fraction = float(
			continuation_policy["contact_release_vertical_force_ramp_initial_fraction"]
		)
		gait_airborne_body_advance_m = float(continuation_policy["gait_airborne_body_advance_m"])
		gait_airborne_body_advance_ramp_ticks = int(
			continuation_policy["gait_airborne_body_advance_ramp_ticks"]
		)
		active_maximum_semantic_relocation_task_force_n = float(
			continuation_policy["maximum_semantic_relocation_task_force_n"]
		)
		active_semantic_joint_rate_damping_nm_s_per_rad = float(
			continuation_policy["semantic_joint_rate_damping_nm_s_per_rad"]
		)
		active_maximum_semantic_joint_damping_torque_nm = float(
			continuation_policy["maximum_semantic_joint_damping_torque_nm"]
		)
	var hybrid_release_enabled := contact_state_lift_enabled or semantic_release_recontact_enabled
	var swing_unload_required_ticks := (
		int(experiment["pre_lift_unload_progress_ticks"])
		if unload_then_lift_enabled
		else int(experiment["support_authority_ramp_ticks"])
	)
	var declared_initial_target := _vector3(experiment["initial_foot_center_world_m"])
	var initial_target := (
		_foot_center_world(swing_limb) if fixture_reused else declared_initial_target
	)
	var contact_release_target_height_m := float(
		experiment.get("contact_release_target_height_m", initial_target.y)
	)
	if fixture_reused:
		contact_release_target_height_m = (
			initial_target.y + float(continuation_policy["contact_release_target_height_offset_m"])
		)
	var contact_release_live_horizontal_position_task := (
		fixture_reused
		and bool(continuation_policy.get("contact_release_live_horizontal_position_task", false))
	)
	var maximum_contact_release_horizontal_damping_force_n := (
		float(continuation_policy.get("maximum_contact_release_horizontal_damping_force_n", 0.0))
		if fixture_reused
		else 0.0
	)
	var semantic_relocation_release_velocity_preservation_ticks := (
		int(continuation_policy.get("semantic_relocation_release_velocity_preservation_ticks", 0))
		if fixture_reused
		else 0
	)
	var semantic_relocation_release_velocity_preservation_scale := (
		clampf(
			float(
				continuation_policy.get(
					"semantic_relocation_release_velocity_preservation_scale", 0.0
				)
			),
			0.0,
			1.0
		)
		if fixture_reused
		else 0.0
	)
	var semantic_relocation_initial_horizontal_target_velocity_m_s := (
		maxf(
			float(
				continuation_policy.get(
					"semantic_relocation_initial_horizontal_target_velocity_m_s", 0.0
				)
			),
			0.0
		)
		if fixture_reused
		else 0.0
	)
	var semantic_relocation_initial_horizontal_target_velocity_ticks := (
		maxi(
			int(
				continuation_policy.get(
					"semantic_relocation_initial_horizontal_target_velocity_ticks", 0
				)
			),
			0
		)
		if fixture_reused
		else 0
	)
	var continuation_target_rebase := initial_target - declared_initial_target
	var clear_target := (
		_vector3(experiment["clear_foot_target_world_m"]) + continuation_target_rebase
	)
	var landing_target := (
		_vector3(experiment["landing_foot_target_world_m"]) + continuation_target_rebase
	)
	var disturbance_axis := _vector3(experiment["disturbance_axis_world"]).normalized()

	var initial_three_points := _support_points_world(
		limbs, String(experiment["swing_limb_id"]), false
	)
	var initial_dynamic := DynamicSupportObserverScript.observe(
		body_by_id, initial_three_points, float(profile["gravity_m_s2"])
	)
	if not bool(initial_dynamic.get("ok", false)):
		viewport.queue_free()
		return initial_dynamic
	var initial_center_of_mass: Vector3 = initial_dynamic["center_of_mass_world_m"]
	var initial_torso_center_world_m := torso.global_position
	var continuation_post_translation_stabilization_target_torso_height_m := (
		initial_torso_center_world_m.y
	)
	if fixture_reused:
		continuation_post_translation_stabilization_target_torso_height_m = (
			maxf(
				(
					float(profile["torso"]["center_world_m"][1])
					- float(experiment["recovery_height_error_limit_m"])
				),
				float(experiment["minimum_long_horizon_torso_height_m"])
			)
			+ float(continuation_policy["contact_consistent_posture_target_height_margin_m"])
		)
	var triangle_incenter := _triangle_incenter_world(initial_three_points)
	var full_triangle_target_center_of_mass := Vector3(
		triangle_incenter.x, initial_center_of_mass.y, triangle_incenter.z
	)
	var continuation_readiness_target_fraction := float(
		experiment["triangle_incenter_target_fraction"]
	)
	var continuation_readiness_target_margin_m := NAN
	var continuation_initial_dynamic_margin_m := NAN
	var continuation_support_centroid_margin_m := NAN
	var triangle_target_center_of_mass := initial_center_of_mass.lerp(
		full_triangle_target_center_of_mass, continuation_readiness_target_fraction
	)
	if fixture_reused:
		continuation_initial_dynamic_margin_m = minf(
			float(initial_dynamic["center_of_mass_margin_m"]),
			float(initial_dynamic["linearized_capture_margin_m"])
		)
		continuation_support_centroid_margin_m = float(initial_dynamic["support_centroid_margin_m"])
		continuation_readiness_target_margin_m = float(
			continuation_policy["readiness_target_margin_m"]
		)
		var available_margin_m := (
			continuation_support_centroid_margin_m - continuation_initial_dynamic_margin_m
		)
		continuation_readiness_target_fraction = 0.0
		if available_margin_m > 1.0e-9:
			continuation_readiness_target_fraction = clampf(
				(
					(continuation_readiness_target_margin_m - continuation_initial_dynamic_margin_m)
					/ available_margin_m
				),
				0.0,
				1.0
			)
		var support_centroid: Vector3 = initial_dynamic["support_centroid_world_m"]
		var bounded_readiness_target := initial_center_of_mass.lerp(
			Vector3(support_centroid.x, initial_center_of_mass.y, support_centroid.z),
			continuation_readiness_target_fraction
		)
		var readiness_shift := Vector2(
			bounded_readiness_target.x - initial_center_of_mass.x,
			bounded_readiness_target.z - initial_center_of_mass.z
		)
		var maximum_readiness_target_shift_m := float(
			continuation_policy["maximum_readiness_target_shift_m"]
		)
		if readiness_shift.length() > maximum_readiness_target_shift_m:
			readiness_shift *= maximum_readiness_target_shift_m / readiness_shift.length()
			bounded_readiness_target.x = initial_center_of_mass.x + readiness_shift.x
			bounded_readiness_target.z = initial_center_of_mass.z + readiness_shift.y
		triangle_target_center_of_mass = bounded_readiness_target
	var continuation_readiness_target_displacement_m := (
		Vector2(
			triangle_target_center_of_mass.x - initial_center_of_mass.x,
			triangle_target_center_of_mass.z - initial_center_of_mass.z
		)
		. length()
	)
	var support_relative_world_by_limb: Dictionary = {}
	for limb_value in limbs:
		var support_limb: Dictionary = limb_value
		support_relative_world_by_limb[String(support_limb["limb_id"])] = (
			_foot_center_world(support_limb) - torso.global_position
		)

	var fixture_complete := true
	var fixture_failure_code := ""
	var all_receipts_complete := true
	var maximum_pairing_residual_nm := 0.0
	var maximum_applied_torque_nm := 0.0
	var structural_saturation_count := 0
	var actuator_saturation_count := 0
	var active_command_count := 0
	var disturbance_operation_count := 0
	var torso_contact_ticks := 0
	var support_controller_command_count := 0
	var maximum_commanded_support_endpoint_force_n := 0.0
	var support_allocator_used := false
	var support_allocator_engaged := false
	var support_allocator_command_count := 0
	var support_allocator_solve_attempt_count := 0
	var support_allocator_infeasible_count := 0
	var minimum_support_allocator_authority_scale := 1.0
	var last_support_allocator_authority_scale := 1.0
	var maximum_support_allocator_force_residual_n := 0.0
	var maximum_support_allocator_moment_residual_nm := 0.0
	var minimum_support_allocator_normal_reserve_n := INF
	var minimum_support_allocator_friction_reserve_n := INF
	var last_support_allocator_infeasibility_reasons: Array = []
	var last_support_allocator_contact_commands: Dictionary = {}
	var predictive_feasibility_gate_used := false
	var predictive_feasibility_check_count := 0
	var predictive_feasibility_pass_count := 0
	var predictive_feasibility_pause_count := 0
	var predictive_feasibility_retreat_tick_count := 0
	var predictive_gate_retreating := false
	var predictive_abort_hold_tick_count := 0
	var predictive_release_dwell_ticks := 0
	var longest_predictive_release_dwell_ticks := 0
	var swing_path_progress_ticks := 0
	var maximum_swing_path_progress_ticks := 0
	var swing_unload_progress_ticks := 0
	var maximum_swing_unload_progress_ticks := 0
	var contact_release_latched := false
	var contact_release_first_tick := -1
	var contact_release_dwell_ticks := 0
	var longest_contact_release_dwell_ticks := 0
	var post_release_contact_tick_count := 0
	var contact_release_gap_m := NAN
	var contact_release_position_world_m := Vector3(INF, INF, INF)
	var contact_release_foot_velocity_world_m_s := Vector3(INF, INF, INF)
	var contact_release_lower_linear_velocity_world_m_s := Vector3(INF, INF, INF)
	var contact_release_lower_angular_velocity_world_rad_s := Vector3(INF, INF, INF)
	var contact_release_torso_linear_velocity_world_m_s := Vector3(INF, INF, INF)
	var contact_release_torso_angular_velocity_world_rad_s := Vector3(INF, INF, INF)
	var maximum_contact_release_horizontal_task_force_n := 0.0
	var maximum_contact_release_vertical_task_force_n := 0.0
	var contact_release_vertical_force_ramp_command_ticks := 0
	var first_contact_release_vertical_force_limit_n := NAN
	var last_contact_release_vertical_force_limit_n := NAN
	var contact_release_vertical_force_limit_at_latch_n := NAN
	var contact_release_reaction_compensation_command_ticks := 0
	var maximum_contact_release_reaction_compensation_total_force_n := 0.0
	var maximum_contact_release_reaction_compensation_force_per_support_n := 0.0
	var first_semantic_relocation_command_tick := -1
	var first_semantic_relocation_target_world_m := Vector3(INF, INF, INF)
	var first_semantic_relocation_target_velocity_world_m_s := Vector3(INF, INF, INF)
	var first_semantic_relocation_task_force_world_n := Vector3(INF, INF, INF)
	var contact_release_semantic_contact_present_at_latch := false
	var contact_release_commit_tick_count := 0
	var maximum_swing_geometric_gap_m := -INF
	var semantic_contact_absent_tick_count_after_lift := 0
	var first_semantic_contact_absent_tick := -1
	var current_semantic_contact_absent_dwell_ticks := 0
	var longest_semantic_contact_absent_dwell_ticks := 0
	var semantic_release_recontact_tick := -1
	var semantic_release_recontact_position_world_m := Vector3(INF, INF, INF)
	var semantic_release_recontact_foot_velocity_world_m_s := Vector3(INF, INF, INF)
	var semantic_release_recontact_lower_linear_velocity_world_m_s := Vector3(INF, INF, INF)
	var semantic_release_recontact_lower_angular_velocity_world_rad_s := Vector3(INF, INF, INF)
	var semantic_release_recontact_torso_linear_velocity_world_m_s := Vector3(INF, INF, INF)
	var semantic_release_recontact_torso_angular_velocity_world_rad_s := Vector3(INF, INF, INF)
	var first_post_recontact_bearing_contact_loss_tick := -1
	var first_post_recontact_bearing_contact_loss_limb_ids: Array[String] = []
	var last_semantic_airborne_tick := -1
	var last_semantic_airborne_foot_velocity_world_m_s := Vector3(INF, INF, INF)
	var last_semantic_airborne_lower_linear_velocity_world_m_s := Vector3(INF, INF, INF)
	var last_semantic_airborne_lower_angular_velocity_world_rad_s := Vector3(INF, INF, INF)
	var last_semantic_airborne_torso_linear_velocity_world_m_s := Vector3(INF, INF, INF)
	var last_semantic_airborne_torso_angular_velocity_world_rad_s := Vector3(INF, INF, INF)
	var semantic_release_commit_tick_count := 0
	var continuation_semantic_recontact_swing_task_command_ticks := 0
	var continuation_recontact_swing_horizontal_damping_command_ticks := 0
	var maximum_continuation_recontact_swing_horizontal_speed_m_s := 0.0
	var maximum_continuation_recontact_swing_horizontal_damping_force_n := 0.0
	var continuation_recontact_support_recovery_active := false
	var continuation_recontact_support_recovery_command_ticks := 0
	var continuation_recontact_vertical_support_command_ticks := 0
	var maximum_continuation_recontact_vertical_support_force_n := 0.0
	var continuation_body_translation_recovery_dwell_ticks := 0
	var maximum_continuation_body_translation_recovery_dwell_ticks := 0
	var continuation_body_translation_recovery_latched := false
	var continuation_body_translation_recovery_latch_tick := -1
	var continuation_joint_pose_reference_rebase_count := 0
	var continuation_joint_pose_reference_rebase_tick := -1
	var continuation_semantic_recontact_pose_rebase_count := 0
	var continuation_semantic_recontact_pose_rebase_tick := -1
	var continuation_semantic_recontact_swing_pose_blend_count := 0
	var continuation_semantic_recontact_swing_pose_blend_tick := -1
	var continuation_semantic_recontact_swing_pose_maximum_preblend_error_rad := 0.0
	var continuation_semantic_recontact_swing_pose_maximum_applied_blend_rad := 0.0
	var continuation_gait_airborne_body_advance_command_ticks := 0
	var continuation_gait_airborne_body_advance_first_tick := -1
	var continuation_gait_airborne_body_advance_last_tick := -1
	var maximum_continuation_gait_airborne_body_advance_target_m := 0.0
	var continuation_gait_airborne_body_advance_start_com_world_m := Vector3(INF, INF, INF)
	var continuation_gait_airborne_body_advance_last_com_world_m := Vector3(INF, INF, INF)
	var continuation_body_translation_three_support_command_ticks := 0
	var continuation_post_translation_stabilization_start_tick := -1
	var continuation_post_translation_stabilization_start_torso_height_m := NAN
	var continuation_post_translation_stabilization_command_ticks := 0
	var continuation_contact_consistent_posture_command_ticks := 0
	var continuation_contact_consistent_posture_joint_reference_update_count := 0
	var continuation_contact_consistent_posture_maximum_joint_reference_rate_rad_s := 0.0
	var continuation_contact_consistent_posture_maximum_accumulated_joint_rotation_rad := 0.0
	var continuation_contact_consistent_posture_accumulated_rotation_by_joint_rad: Dictionary = {}
	var continuation_contact_consistent_posture_command_ticks_by_limb: Dictionary = {}
	var continuation_early_contact_consistent_posture_first_tick := -1
	var continuation_early_contact_consistent_posture_command_ticks := 0
	var continuation_early_contact_consistent_posture_joint_reference_update_count := 0
	var continuation_early_contact_consistent_posture_maximum_joint_reference_rate_rad_s := 0.0
	var continuation_early_contact_consistent_posture_maximum_accumulated_joint_rotation_rad := 0.0
	var continuation_early_contact_consistent_posture_maximum_desired_body_angular_speed_rad_s := 0.0
	var continuation_early_contact_consistent_posture_maximum_relative_endpoint_speed_m_s := 0.0
	var continuation_early_contact_consistent_posture_command_ticks_by_limb: Dictionary = {}
	var continuation_contact_consistent_posture_recovery_latched := false
	var continuation_contact_consistent_posture_recovery_latch_tick := -1
	var continuation_contact_consistent_posture_recovery_dwell_ticks := 0
	var maximum_continuation_contact_consistent_posture_recovery_dwell_ticks := 0
	var continuation_posture_settle_joint_damping_command_ticks := 0
	var maximum_continuation_posture_settle_joint_damping_torque_nm := 0.0
	var maximum_continuation_posture_settle_joint_rate_rad_s := 0.0
	var semantic_joint_damping_first_tick := -1
	var semantic_joint_damping_command_tick_count := 0
	var maximum_semantic_joint_damping_command_nm := 0.0
	var maximum_semantic_post_recontact_joint_rate_rad_s := 0.0
	var semantic_joint_damping_start_torso_height_m := NAN
	var semantic_joint_damping_start_torso_tilt_rad := NAN
	var semantic_joint_damping_start_torso_angular_velocity_world_rad_s := Vector3(INF, INF, INF)
	var semantic_joint_rates_at_damping_start_rad_s: Dictionary = {}
	var semantic_swing_joint_rate_norm_at_damping_start_rad_s := NAN
	var semantic_all_limb_damping_latched := false
	var post_recontact_body_translation_start_tick := -1
	var post_recontact_body_translation_command_tick_count := 0
	var post_recontact_body_translation_start_com_world_m := Vector3(INF, INF, INF)
	var post_recontact_body_translation_start_torso_world_m := Vector3(INF, INF, INF)
	var post_recontact_body_translation_target_com_world_m := Vector3(INF, INF, INF)
	var post_recontact_body_translation_start_foot_world_by_limb: Dictionary = {}
	var post_recontact_body_translation_support_relative_world_by_limb: Dictionary = {}
	var post_recontact_yaw_damping_command_tick_count := 0
	var maximum_post_recontact_yaw_damping_moment_nm := 0.0
	var maximum_post_recontact_yaw_damping_endpoint_force_n := 0.0
	var post_recontact_attitude_velocity_feedback_override_tick_count := 0
	var continuation_four_contact_attitude_command_ticks := 0
	var continuation_recontact_attitude_recovery_command_ticks := 0
	var maximum_continuation_recontact_roll_pitch_moment_nm := 0.0
	var maximum_continuation_recontact_yaw_moment_nm := 0.0
	var maximum_continuation_recontact_yaw_endpoint_force_n := 0.0
	var maximum_post_recontact_body_translation_target_error_m := 0.0
	var minimum_predictive_normal_reserve_n := INF
	var last_predictive_feasibility_passed := false
	var last_predictive_infeasibility_reasons: Array = []
	var maximum_anchor_error_m := 0.0
	var maximum_hinge_axis_error_rad := 0.0
	var maximum_swing_tracking_error_m := 0.0
	var maximum_tilt_rad := 0.0
	var support_state_observations_complete := true
	var lift_entry_com_margin_m := NAN
	var lift_entry_capture_margin_m := NAN
	var final_three_contact_com_margin_m := NAN
	var final_three_contact_capture_margin_m := NAN
	var minimum_three_contact_com_margin_m := INF
	var minimum_three_contact_capture_margin_m := INF
	var minimum_three_contact_dynamic_margin_m := INF
	var swing_clear_ticks_before_disturbance := 0
	var swing_contact_seen_after_clear := false
	var previous_swing_contact := _foot_shape_contacts_floor(swing_limb)
	var first_touch_tick := -1
	var first_touch_target_error_m := INF
	var post_touch_contact_ticks := 0
	var post_touch_samples := 0
	var recovery_dwell_ticks := 0
	var longest_recovery_dwell_ticks := 0
	var support_contact_ticks: Dictionary = {}
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		if String(limb["limb_id"]) != String(experiment["swing_limb_id"]):
			support_contact_ticks[String(limb["contact_id"])] = 0
	var lift_origin_world := initial_target
	var previous_swing_target := initial_target
	var three_contact_entry_established := false
	var three_contact_entry_tick := -1
	var three_contact_hold_target := triangle_target_center_of_mass
	var lift_entry_pitch_reference_rad := 0.0
	var lift_entry_roll_reference_rad := 0.0
	var executed_ticks := 0

	for tick in range(executed_tick_limit):
		var three_support_points := _support_points_world(
			limbs, String(experiment["swing_limb_id"]), false
		)
		var three_state := DynamicSupportObserverScript.observe(
			body_by_id, three_support_points, float(profile["gravity_m_s2"])
		)
		if not bool(three_state.get("ok", false)):
			fixture_complete = false
			support_state_observations_complete = false
			fixture_failure_code = String(
				three_state.get(
					"failure_code", "SPATIAL_CENTROIDAL_THREE_SUPPORT_OBSERVATION_FAILED"
				)
			)
			break
		var current_com_margin_m := float(three_state["center_of_mass_margin_m"])
		var current_capture_margin_m := float(three_state["linearized_capture_margin_m"])
		final_three_contact_com_margin_m = current_com_margin_m
		final_three_contact_capture_margin_m = current_capture_margin_m
		var swing_contact_before_command := _foot_shape_contacts_floor(swing_limb)
		var swing_geometric_gap_m := _foot_center_world(swing_limb).y - initial_target.y
		if hybrid_release_enabled and tick >= lift_start_tick:
			maximum_swing_geometric_gap_m = maxf(
				maximum_swing_geometric_gap_m, swing_geometric_gap_m
			)
			if not swing_contact_before_command:
				semantic_contact_absent_tick_count_after_lift += 1
				current_semantic_contact_absent_dwell_ticks += 1
				longest_semantic_contact_absent_dwell_ticks = maxi(
					longest_semantic_contact_absent_dwell_ticks,
					current_semantic_contact_absent_dwell_ticks
				)
				if contact_release_latched:
					last_semantic_airborne_tick = tick
					var airborne_lower: RigidBody3D = swing_limb["lower"]
					var airborne_foot_position := _foot_center_world(swing_limb)
					var airborne_foot_relative_to_lower := (
						airborne_foot_position - airborne_lower.global_position
					)
					last_semantic_airborne_foot_velocity_world_m_s = (
						airborne_lower.linear_velocity
						+ airborne_lower.angular_velocity.cross(airborne_foot_relative_to_lower)
					)
					last_semantic_airborne_lower_linear_velocity_world_m_s = (
						airborne_lower.linear_velocity
					)
					last_semantic_airborne_lower_angular_velocity_world_rad_s = (
						airborne_lower.angular_velocity
					)
					last_semantic_airborne_torso_linear_velocity_world_m_s = (torso.linear_velocity)
					last_semantic_airborne_torso_angular_velocity_world_rad_s = (
						torso.angular_velocity
					)
				if first_semantic_contact_absent_tick < 0:
					first_semantic_contact_absent_tick = tick
			else:
				if (
					semantic_release_recontact_enabled
					and contact_release_latched
					and semantic_release_recontact_tick < 0
					and current_semantic_contact_absent_dwell_ticks > 0
				):
					semantic_release_recontact_tick = tick
					semantic_release_recontact_position_world_m = _foot_center_world(swing_limb)
					var semantic_recontact_lower: RigidBody3D = swing_limb["lower"]
					var semantic_recontact_foot_relative_to_lower: Vector3 = (
						semantic_release_recontact_position_world_m
						- semantic_recontact_lower.global_position
					)
					semantic_release_recontact_foot_velocity_world_m_s = (
						semantic_recontact_lower.linear_velocity
						+ semantic_recontact_lower.angular_velocity.cross(
							semantic_recontact_foot_relative_to_lower
						)
					)
					semantic_release_recontact_lower_linear_velocity_world_m_s = (
						semantic_recontact_lower.linear_velocity
					)
					semantic_release_recontact_lower_angular_velocity_world_rad_s = (
						semantic_recontact_lower.angular_velocity
					)
					semantic_release_recontact_torso_linear_velocity_world_m_s = (
						torso.linear_velocity
					)
					semantic_release_recontact_torso_angular_velocity_world_rad_s = (
						torso.angular_velocity
					)
					if (
						fixture_reused
						and bool(
							continuation_policy["rebase_all_joint_pose_references_at_semantic_recontact"]
						)
					):
						_rebase_joint_pose_references(torso, limbs)
						continuation_semantic_recontact_pose_rebase_count += 1
						continuation_semantic_recontact_pose_rebase_tick = tick
					var swing_pose_reference_blend_fraction := (
						float(
							continuation_policy.get(
								"semantic_recontact_swing_pose_reference_blend_fraction", 0.0
							)
						)
						if fixture_reused
						else 0.0
					)
					if fixture_reused and swing_pose_reference_blend_fraction > 0.0:
						var swing_pose_blend := _blend_limb_joint_pose_references(
							torso, swing_limb, swing_pose_reference_blend_fraction
						)
						continuation_semantic_recontact_swing_pose_blend_count += int(
							swing_pose_blend["joint_reference_blend_count"]
						)
						continuation_semantic_recontact_swing_pose_blend_tick = tick
						continuation_semantic_recontact_swing_pose_maximum_preblend_error_rad = (float(
							swing_pose_blend["maximum_preblend_error_rad"]
						))
						continuation_semantic_recontact_swing_pose_maximum_applied_blend_rad = (float(
							swing_pose_blend["maximum_applied_blend_rad"]
						))
				current_semantic_contact_absent_dwell_ticks = 0
			if not contact_release_latched:
				var release_observation_qualifies := not swing_contact_before_command
				if contact_state_lift_enabled:
					release_observation_qualifies = (
						release_observation_qualifies
						or (
							swing_geometric_gap_m
							>= float(experiment["contact_release_minimum_geometric_gap_m"])
						)
					)
				if release_observation_qualifies:
					contact_release_dwell_ticks += 1
					longest_contact_release_dwell_ticks = maxi(
						longest_contact_release_dwell_ticks, contact_release_dwell_ticks
					)
					if (
						contact_release_dwell_ticks
						>= int(experiment["contact_release_dwell_ticks_required"])
					):
						contact_release_latched = true
						contact_release_first_tick = tick - contact_release_dwell_ticks + 1
						contact_release_gap_m = swing_geometric_gap_m
						contact_release_position_world_m = _foot_center_world(swing_limb)
						var contact_release_lower: RigidBody3D = swing_limb["lower"]
						var contact_release_foot_relative_to_lower: Vector3 = (
							contact_release_position_world_m - contact_release_lower.global_position
						)
						contact_release_foot_velocity_world_m_s = (
							contact_release_lower.linear_velocity
							+ contact_release_lower.angular_velocity.cross(
								contact_release_foot_relative_to_lower
							)
						)
						contact_release_lower_linear_velocity_world_m_s = (
							contact_release_lower.linear_velocity
						)
						contact_release_lower_angular_velocity_world_rad_s = (
							contact_release_lower.angular_velocity
						)
						contact_release_torso_linear_velocity_world_m_s = torso.linear_velocity
						contact_release_torso_angular_velocity_world_rad_s = torso.angular_velocity
						contact_release_semantic_contact_present_at_latch = (swing_contact_before_command)
						contact_release_vertical_force_limit_at_latch_n = (last_contact_release_vertical_force_limit_n)
						lift_origin_world = _foot_center_world(swing_limb)
						previous_swing_target = lift_origin_world
				else:
					contact_release_dwell_ticks = 0
			elif swing_contact_before_command:
				post_release_contact_tick_count += 1
		var contact_release_commit_active := (
			contact_state_lift_enabled
			and contact_release_latched
			and (tick - contact_release_first_tick < int(experiment["post_release_commit_ticks"]))
		)
		if contact_release_commit_active:
			contact_release_commit_tick_count += 1
		var semantic_release_commit_active := (
			semantic_release_recontact_enabled
			and tick >= lift_start_tick
			and tick - lift_start_tick < int(experiment["semantic_release_commit_ticks"])
			and (not semantic_relocation_recontact_enabled or semantic_release_recontact_tick < 0)
		)
		if semantic_release_commit_active:
			semantic_release_commit_tick_count += 1
		var continuation_semantic_recontact_swing_task_active := (
			fixture_reused
			and semantic_release_recontact_tick >= 0
			and (
				tick - semantic_release_recontact_tick
				< int(continuation_policy["semantic_recontact_swing_task_hold_ticks"])
			)
		)
		if (
			not three_contact_entry_established
			and tick >= shift_complete_tick
			and current_com_margin_m >= minimum_three_contact_handoff_margin_m
			and current_capture_margin_m >= minimum_three_contact_handoff_margin_m
		):
			three_contact_hold_target = triangle_target_center_of_mass
			three_contact_entry_established = true
			three_contact_entry_tick = tick
		if tick == lift_start_tick:
			lift_entry_com_margin_m = current_com_margin_m
			lift_entry_capture_margin_m = current_capture_margin_m
			lift_entry_pitch_reference_rad = _signed_pitch_rad(torso)
			lift_entry_roll_reference_rad = _signed_roll_rad(torso)
			if (
				not three_contact_entry_established
				or current_com_margin_m < minimum_lift_entry_dynamic_margin_m
				or current_capture_margin_m < minimum_lift_entry_dynamic_margin_m
			):
				fixture_complete = false
				fixture_failure_code = "SPATIAL_CENTROIDAL_LIFT_ENTRY_NOT_ESTABLISHED"
				break
		if tick >= lift_start_tick and first_touch_tick < 0:
			minimum_three_contact_com_margin_m = minf(
				minimum_three_contact_com_margin_m, current_com_margin_m
			)
			minimum_three_contact_capture_margin_m = minf(
				minimum_three_contact_capture_margin_m, current_capture_margin_m
			)
			minimum_three_contact_dynamic_margin_m = minf(
				minimum_three_contact_dynamic_margin_m,
				minf(current_com_margin_m, current_capture_margin_m)
			)

		var swing_path_progress_for_command := swing_path_progress_ticks
		if (
			feasibility_gated_swing
			and tick >= lift_start_tick
			and swing_path_progress_ticks < lift_complete_tick - lift_start_tick
		):
			predictive_feasibility_gate_used = true
			predictive_feasibility_check_count += 1
			var predictive_result := _predict_three_contact_wrench_feasibility(
				profile, experiment, tick, three_state, limbs
			)
			if not bool(predictive_result.get("ok", false)):
				fixture_complete = false
				fixture_failure_code = String(
					predictive_result.get(
						"failure_code", "SPATIAL_PREDICTIVE_FEASIBILITY_CHECK_FAILED"
					)
				)
				break
			var predictive_command: Dictionary = predictive_result["command"]
			minimum_predictive_normal_reserve_n = minf(
				minimum_predictive_normal_reserve_n,
				float(predictive_command["minimum_normal_reserve_n"])
			)
			var predictive_reasons: Array = (
				(predictive_command["infeasibility_reasons"] as Array).duplicate(true)
			)
			var handoff_margin_m := minimum_three_contact_handoff_margin_m
			if current_com_margin_m < handoff_margin_m:
				predictive_reasons.append("COM_HANDOFF_MARGIN_BELOW_MINIMUM")
			if current_capture_margin_m < handoff_margin_m:
				predictive_reasons.append("CAPTURE_HANDOFF_MARGIN_BELOW_MINIMUM")
			if (
				absf(torso.global_position.y - float(profile["torso"]["center_world_m"][1]))
				> float(experiment["recovery_height_error_limit_m"])
			):
				predictive_reasons.append("TORSO_HEIGHT_OUTSIDE_PROVEN_STANCE_ENVELOPE")
			var attitude_deviation_rad := (
				Vector2(
					_signed_roll_rad(torso) - lift_entry_roll_reference_rad,
					_signed_pitch_rad(torso) - lift_entry_pitch_reference_rad
				)
				. length()
			)
			if attitude_deviation_rad > float(experiment["maximum_swing_attitude_deviation_rad"]):
				predictive_reasons.append("TORSO_ATTITUDE_OUTSIDE_SWING_ENVELOPE")
			if not predictive_reasons.is_empty() and not predictive_gate_retreating:
				predictive_gate_retreating = true
			if predictive_gate_retreating and predictive_reasons.is_empty():
				var release_margin_m := float(
					experiment["support_authority_release_capture_margin_m"]
				)
				if (
					current_com_margin_m >= release_margin_m
					and current_capture_margin_m >= release_margin_m
				):
					predictive_release_dwell_ticks += 1
					longest_predictive_release_dwell_ticks = maxi(
						longest_predictive_release_dwell_ticks, predictive_release_dwell_ticks
					)
					if (
						predictive_release_dwell_ticks
						>= int(experiment["feasibility_release_dwell_ticks_required"])
					):
						predictive_gate_retreating = false
						predictive_release_dwell_ticks = 0
					else:
						predictive_reasons.append("PREDICTIVE_GATE_RELEASE_DWELL_INCOMPLETE")
				else:
					predictive_release_dwell_ticks = 0
					predictive_reasons.append("PREDICTIVE_GATE_HYSTERESIS_NOT_RELEASED")
			elif not predictive_reasons.is_empty():
				predictive_release_dwell_ticks = 0
			last_predictive_feasibility_passed = (
				predictive_reasons.is_empty() and not predictive_gate_retreating
			)
			last_predictive_infeasibility_reasons = predictive_reasons
			if last_predictive_feasibility_passed:
				predictive_feasibility_pass_count += 1
				if (tick - lift_start_tick) % int(experiment["swing_progress_stride_ticks"]) == 0:
					if (
						unload_then_lift_enabled
						and (swing_unload_progress_ticks < swing_unload_required_ticks)
					):
						swing_unload_progress_ticks += 1
						maximum_swing_unload_progress_ticks = maxi(
							maximum_swing_unload_progress_ticks, swing_unload_progress_ticks
						)
					elif hybrid_release_enabled and not contact_release_latched:
						pass
					else:
						swing_path_progress_ticks += 1
						maximum_swing_path_progress_ticks = maxi(
							maximum_swing_path_progress_ticks, swing_path_progress_ticks
						)
			else:
				predictive_feasibility_pause_count += 1
				if contact_release_commit_active:
					swing_path_progress_ticks = maxi(swing_path_progress_ticks, 1)
					maximum_swing_path_progress_ticks = maxi(
						maximum_swing_path_progress_ticks, swing_path_progress_ticks
					)
				elif semantic_release_commit_active:
					pass
				elif unload_then_lift_enabled and swing_path_progress_ticks == 0:
					var previous_unload_progress_ticks := swing_unload_progress_ticks
					swing_unload_progress_ticks = maxi(
						0,
						(
							swing_unload_progress_ticks
							- int(experiment["infeasible_retreat_progress_ticks"])
						)
					)
					predictive_feasibility_retreat_tick_count += (
						previous_unload_progress_ticks - swing_unload_progress_ticks
					)
				else:
					var previous_progress_ticks := swing_path_progress_ticks
					swing_path_progress_ticks = maxi(
						0,
						(
							swing_path_progress_ticks
							- int(experiment["infeasible_retreat_progress_ticks"])
						)
					)
					predictive_feasibility_retreat_tick_count += (
						previous_progress_ticks - swing_path_progress_ticks
					)

		var predictive_abort_hold := (
			feasibility_gated_swing
			and predictive_gate_retreating
			and swing_path_progress_ticks == 0
			and not contact_release_commit_active
			and not semantic_release_commit_active
		)
		if predictive_abort_hold:
			predictive_abort_hold_tick_count += 1

		for limb_value in limbs:
			var geometry := _joint_geometry_diagnostics(torso, limb_value)
			maximum_anchor_error_m = maxf(
				maximum_anchor_error_m, float(geometry["maximum_anchor_error_m"])
			)
			maximum_hinge_axis_error_rad = maxf(
				maximum_hinge_axis_error_rad, float(geometry["maximum_axis_error_rad"])
			)
		maximum_tilt_rad = maxf(maximum_tilt_rad, _tilt(torso))

		var swing_target := initial_target
		var unload_stage_complete := (
			not unload_then_lift_enabled
			or swing_unload_progress_ticks >= swing_unload_required_ticks
		)
		var swing_active := (
			tick >= lift_start_tick
			and unload_stage_complete
			and (
				not unload_then_lift_enabled
				or (
					hybrid_release_enabled
					and not contact_release_latched
					and not predictive_abort_hold
				)
				or (semantic_release_recontact_enabled and semantic_release_commit_active)
				or continuation_semantic_recontact_swing_task_active
				or swing_path_progress_ticks > 0
			)
			and (not predictive_abort_hold or continuation_semantic_recontact_swing_task_active)
		)
		var swing_path_tick := tick
		if feasibility_gated_swing:
			swing_path_tick = lift_start_tick + swing_path_progress_for_command
		var swing_path_complete := (
			not feasibility_gated_swing
			or swing_path_progress_ticks >= lift_complete_tick - lift_start_tick
		)
		if tick == lift_start_tick:
			lift_origin_world = _foot_center_world(swing_limb)
			previous_swing_target = lift_origin_world
		if tick >= lift_start_tick and swing_path_tick < lift_complete_tick:
			if (
				String(experiment["swing_lift_path_policy"])
				in [
					"vertical_then_horizontal_smoothstep_v1",
					"feasibility_gated_vertical_then_horizontal_smoothstep_v1",
				]
			):
				var vertical_clear_target := Vector3(
					lift_origin_world.x, clear_target.y, lift_origin_world.z
				)
				if swing_path_tick < int(experiment["vertical_lift_complete_tick"]):
					swing_target = lift_origin_world.lerp(
						vertical_clear_target,
						_smoothstep(
							(
								float(swing_path_tick - lift_start_tick)
								/ float(
									int(experiment["vertical_lift_complete_tick"]) - lift_start_tick
								)
							)
						)
					)
				else:
					swing_target = vertical_clear_target.lerp(
						clear_target,
						_smoothstep(
							(
								float(
									swing_path_tick - int(experiment["vertical_lift_complete_tick"])
								)
								/ float(
									(
										lift_complete_tick
										- int(experiment["vertical_lift_complete_tick"])
									)
								)
							)
						)
					)
			else:
				swing_target = lift_origin_world.lerp(
					clear_target,
					_smoothstep(
						(
							float(swing_path_tick - lift_start_tick)
							/ float(lift_complete_tick - lift_start_tick)
						)
					)
				)
		elif tick >= lift_start_tick and swing_path_complete:
			swing_target = clear_target
		if hybrid_release_enabled and tick >= lift_start_tick and not contact_release_latched:
			swing_target = Vector3(
				lift_origin_world.x, contact_release_target_height_m, lift_origin_world.z
			)
		if (
			semantic_relocation_recontact_enabled
			and contact_release_latched
			and semantic_release_commit_active
		):
			var relocation_clear_target := (
				lift_origin_world + _vector3(experiment["semantic_relocation_clear_offset_m"])
			)
			var relocation_landing_target := Vector3(
				relocation_clear_target.x, initial_target.y, relocation_clear_target.z
			)
			var relocation_elapsed_ticks := tick - contact_release_first_tick
			if relocation_elapsed_ticks < semantic_relocation_lift_ticks:
				swing_target = lift_origin_world.lerp(
					relocation_clear_target,
					_smoothstep(
						clampf(
							float(relocation_elapsed_ticks) / float(semantic_relocation_lift_ticks),
							0.0,
							1.0
						)
					)
				)
			else:
				swing_target = relocation_clear_target.lerp(
					relocation_landing_target,
					_smoothstep(
						clampf(
							(
								float(relocation_elapsed_ticks - semantic_relocation_lift_ticks)
								/ float(semantic_relocation_lower_ticks)
							),
							0.0,
							1.0
						)
					)
				)
		if continuation_semantic_recontact_swing_task_active:
			var held_relocation_offset := _vector3(experiment["semantic_relocation_clear_offset_m"])
			swing_target = Vector3(
				lift_origin_world.x + held_relocation_offset.x,
				initial_target.y,
				lift_origin_world.z + held_relocation_offset.z
			)
		if (
			touchdown_enabled
			and tick >= landing_start_tick
			and (
				not feasibility_gated_swing
				or (swing_path_complete and disturbance_operation_count > 0)
			)
		):
			var aligned_target := Vector3(landing_target.x, clear_target.y, landing_target.z)
			if tick < landing_alignment_complete_tick:
				swing_target = clear_target.lerp(
					aligned_target,
					_smoothstep(
						(
							float(tick - landing_start_tick)
							/ float(landing_alignment_complete_tick - landing_start_tick)
						)
					)
				)
			else:
				swing_target = aligned_target.lerp(
					landing_target,
					_smoothstep(
						clampf(
							(
								float(tick - landing_alignment_complete_tick)
								/ float(landing_complete_tick - landing_alignment_complete_tick)
							),
							0.0,
							1.0
						)
					)
				)
			if first_touch_tick >= 0:
				swing_target.y = landing_target.y - float(experiment["post_touch_press_depth_m"])
		var swing_target_velocity := (swing_target - previous_swing_target) / step_s
		if continuation_semantic_recontact_swing_task_active:
			swing_target_velocity = Vector3.ZERO
		if hybrid_release_enabled and not contact_release_latched:
			swing_target_velocity = (
				Vector3.UP * float(experiment["contact_release_target_velocity_m_s"])
			)
			if contact_release_live_horizontal_position_task:
				var release_foot_position := _foot_center_world(swing_limb)
				swing_target.x = release_foot_position.x
				swing_target.z = release_foot_position.z
		elif (
			contact_state_lift_enabled
			and contact_release_latched
			and (
				swing_path_progress_ticks
				<= int(experiment["post_release_velocity_hold_path_ticks"])
			)
		):
			swing_target_velocity.y = maxf(
				swing_target_velocity.y,
				float(experiment["post_release_minimum_upward_velocity_m_s"])
			)
		elif (
			semantic_relocation_recontact_enabled
			and contact_release_latched
			and (
				tick - contact_release_first_tick
				< int(experiment["semantic_relocation_upward_velocity_hold_ticks"])
			)
		):
			swing_target_velocity.y = maxf(
				swing_target_velocity.y,
				float(experiment["semantic_relocation_minimum_upward_velocity_m_s"])
			)
		if (
			semantic_relocation_recontact_enabled
			and contact_release_latched
			and semantic_relocation_release_velocity_preservation_ticks > 0
		):
			var preservation_elapsed_ticks := tick - contact_release_first_tick
			if preservation_elapsed_ticks < semantic_relocation_release_velocity_preservation_ticks:
				var preservation_fraction := _smoothstep(
					clampf(
						(
							float(preservation_elapsed_ticks)
							/ float(semantic_relocation_release_velocity_preservation_ticks)
						),
						0.0,
						1.0
					)
				)
				var minimum_relocation_upward_velocity := float(
					experiment["semantic_relocation_minimum_upward_velocity_m_s"]
				)
				var scaled_release_upward_velocity := lerpf(
					minimum_relocation_upward_velocity,
					maxf(
						contact_release_foot_velocity_world_m_s.y,
						minimum_relocation_upward_velocity
					),
					semantic_relocation_release_velocity_preservation_scale
				)
				swing_target_velocity.y = maxf(
					swing_target_velocity.y,
					lerpf(
						scaled_release_upward_velocity,
						minimum_relocation_upward_velocity,
						preservation_fraction
					)
				)
		if (
			semantic_relocation_recontact_enabled
			and contact_release_latched
			and (
				tick - contact_release_first_tick
				< semantic_relocation_initial_horizontal_target_velocity_ticks
			)
		):
			var relocation_offset := _vector3(experiment["semantic_relocation_clear_offset_m"])
			var horizontal_relocation_direction := (
				Vector2(relocation_offset.x, relocation_offset.z).normalized()
			)
			if not horizontal_relocation_direction.is_zero_approx():
				var horizontal_target_velocity := Vector2(
					swing_target_velocity.x, swing_target_velocity.z
				)
				var directed_target_velocity := horizontal_target_velocity.dot(
					horizontal_relocation_direction
				)
				if (
					directed_target_velocity
					< semantic_relocation_initial_horizontal_target_velocity_m_s
				):
					horizontal_target_velocity += (
						horizontal_relocation_direction
						* (
							semantic_relocation_initial_horizontal_target_velocity_m_s
							- directed_target_velocity
						)
					)
					swing_target_velocity.x = horizontal_target_velocity.x
					swing_target_velocity.z = horizontal_target_velocity.y
		previous_swing_target = swing_target
		var swing_torque_overrides: Dictionary = {}
		var contact_release_reaction_force_world_n := Vector3.ZERO
		if swing_active:
			var active_contact_release_vertical_force_limit_n := maximum_contact_release_task_force_n
			if (
				fixture_reused
				and not contact_release_latched
				and tick >= lift_start_tick
				and contact_release_vertical_force_ramp_ticks > 0
			):
				var release_force_ramp_progress := _smoothstep(
					clampf(
						(
							float(tick - lift_start_tick)
							/ float(contact_release_vertical_force_ramp_ticks)
						),
						0.0,
						1.0
					)
				)
				active_contact_release_vertical_force_limit_n *= lerpf(
					contact_release_vertical_force_ramp_initial_fraction,
					1.0,
					release_force_ramp_progress
				)
			if (
				fixture_reused
				and not contact_release_latched
				and contact_release_vertical_force_ramp_ticks > 0
			):
				contact_release_vertical_force_ramp_command_ticks += 1
				if is_nan(first_contact_release_vertical_force_limit_n):
					first_contact_release_vertical_force_limit_n = (active_contact_release_vertical_force_limit_n)
				last_contact_release_vertical_force_limit_n = (active_contact_release_vertical_force_limit_n)
			maximum_swing_tracking_error_m = maxf(
				maximum_swing_tracking_error_m,
				_foot_center_world(swing_limb).distance_to(swing_target)
			)
			var swing_servo: Dictionary
			if (
				semantic_relocation_recontact_enabled
				and contact_release_latched
				and (
					semantic_release_commit_active
					or continuation_semantic_recontact_swing_task_active
				)
			):
				swing_servo = _task_space_joint_torques(
					swing_limb,
					torso,
					swing_target,
					swing_target_velocity,
					float(experiment["semantic_relocation_position_gain_n_per_m"]),
					float(experiment["semantic_relocation_velocity_gain_ns_per_m"]),
					active_maximum_semantic_relocation_task_force_n
				)
			elif semantic_release_recontact_enabled and not contact_release_latched:
				if contact_release_live_horizontal_position_task:
					swing_servo = _axis_bounded_task_space_joint_torques(
						swing_limb,
						torso,
						swing_target,
						swing_target_velocity,
						float(experiment["contact_release_position_gain_n_per_m"]),
						float(experiment["contact_release_velocity_gain_ns_per_m"]),
						maximum_contact_release_horizontal_damping_force_n,
						active_contact_release_vertical_force_limit_n
					)
				else:
					swing_servo = _task_space_joint_torques(
						swing_limb,
						torso,
						swing_target,
						swing_target_velocity,
						float(experiment["contact_release_position_gain_n_per_m"]),
						float(experiment["contact_release_velocity_gain_ns_per_m"]),
						active_contact_release_vertical_force_limit_n
					)
			elif contact_state_lift_enabled and not contact_release_latched:
				swing_servo = _task_space_joint_torques(
					swing_limb,
					torso,
					swing_target,
					swing_target_velocity,
					float(experiment["contact_release_position_gain_n_per_m"]),
					float(experiment["contact_release_velocity_gain_ns_per_m"]),
					float(experiment["maximum_contact_release_task_force_n"])
				)
			else:
				swing_servo = _resolved_rate_swing_joint_torques(
					swing_limb,
					torso,
					swing_target,
					swing_target_velocity,
					float(experiment["swing_task_position_gain_per_s"]),
					float(experiment["swing_dls_damping_m"]),
					float(experiment["maximum_swing_endpoint_speed_m_s"]),
					float(experiment["maximum_swing_joint_speed_rad_s"]),
					float(experiment["swing_joint_velocity_gain_nm_s_per_rad"]),
					float(experiment["maximum_swing_joint_torque_nm"])
				)
			if (
				semantic_relocation_recontact_enabled
				and contact_release_latched
				and semantic_release_commit_active
				and first_semantic_relocation_command_tick < 0
			):
				first_semantic_relocation_command_tick = tick
				first_semantic_relocation_target_world_m = swing_target
				first_semantic_relocation_target_velocity_world_m_s = swing_target_velocity
				var first_command_lower: RigidBody3D = swing_limb["lower"]
				var first_command_foot := _foot_center_world(swing_limb)
				var first_command_foot_velocity := (
					first_command_lower.linear_velocity
					+ first_command_lower.angular_velocity.cross(
						first_command_foot - first_command_lower.global_position
					)
				)
				first_semantic_relocation_task_force_world_n = (
					(
						float(experiment["semantic_relocation_position_gain_n_per_m"])
						* (swing_target - first_command_foot)
					)
					- (
						float(experiment["semantic_relocation_velocity_gain_ns_per_m"])
						* (first_command_foot_velocity - swing_target_velocity)
					)
				)
				var first_command_force_limit := float(
					active_maximum_semantic_relocation_task_force_n
				)
				if (
					first_semantic_relocation_task_force_world_n.length()
					> first_command_force_limit
				):
					first_semantic_relocation_task_force_world_n *= (
						first_command_force_limit
						/ first_semantic_relocation_task_force_world_n.length()
					)
			if swing_servo.has("task_force_world_n"):
				var applied_release_task_force: Vector3 = swing_servo["task_force_world_n"]
				maximum_contact_release_horizontal_task_force_n = maxf(
					maximum_contact_release_horizontal_task_force_n,
					Vector2(applied_release_task_force.x, applied_release_task_force.z).length()
				)
				maximum_contact_release_vertical_task_force_n = maxf(
					maximum_contact_release_vertical_task_force_n,
					absf(applied_release_task_force.y)
				)
				if (
					fixture_reused
					and not contact_release_latched
					and bool(continuation_policy["contact_release_reaction_compensation_enabled"])
				):
					contact_release_reaction_force_world_n = applied_release_task_force
			if not bool(swing_servo.get("ok", false)):
				fixture_complete = false
				fixture_failure_code = String(
					swing_servo.get("failure_code", "SPATIAL_CENTROIDAL_SWING_SERVO_FAILED")
				)
				break
			swing_torque_overrides = swing_servo["joint_torque_overrides"]
			if continuation_semantic_recontact_swing_task_active:
				continuation_semantic_recontact_swing_task_command_ticks += 1

		var joint_torque_additions: Dictionary = {}
		if (
			fixture_reused
			and bool(continuation_policy["post_recontact_swing_horizontal_damping_enabled"])
			and semantic_release_recontact_tick >= 0
			and (
				tick - semantic_release_recontact_tick
				< int(continuation_policy["post_recontact_swing_horizontal_damping_ticks"])
			)
			and _foot_shape_contacts_floor(swing_limb)
			and not (floor in torso.get_colliding_bodies())
		):
			var planted_swing_lower: RigidBody3D = swing_limb["lower"]
			var planted_swing_foot := _foot_center_world(swing_limb)
			var planted_swing_foot_velocity := (
				planted_swing_lower.linear_velocity
				+ planted_swing_lower.angular_velocity.cross(
					planted_swing_foot - planted_swing_lower.global_position
				)
			)
			var planted_swing_horizontal_velocity := Vector3(
				planted_swing_foot_velocity.x, 0.0, planted_swing_foot_velocity.z
			)
			var planted_swing_horizontal_damping_force := (
				-float(
					continuation_policy["post_recontact_swing_horizontal_velocity_gain_ns_per_m"]
				)
				* planted_swing_horizontal_velocity
			)
			var planted_swing_horizontal_damping_force_limit := float(
				continuation_policy["maximum_post_recontact_swing_horizontal_damping_force_n"]
			)
			if (
				planted_swing_horizontal_damping_force.length()
				> planted_swing_horizontal_damping_force_limit
			):
				planted_swing_horizontal_damping_force *= (
					planted_swing_horizontal_damping_force_limit
					/ planted_swing_horizontal_damping_force.length()
				)
			_merge_torque_additions(
				joint_torque_additions,
				_joint_torques_for_endpoint_force(
					swing_limb, torso, planted_swing_horizontal_damping_force
				)
			)
			continuation_recontact_swing_horizontal_damping_command_ticks += 1
			maximum_continuation_recontact_swing_horizontal_speed_m_s = maxf(
				maximum_continuation_recontact_swing_horizontal_speed_m_s,
				planted_swing_horizontal_velocity.length()
			)
			maximum_continuation_recontact_swing_horizontal_damping_force_n = maxf(
				maximum_continuation_recontact_swing_horizontal_damping_force_n,
				planted_swing_horizontal_damping_force.length()
			)
		if contact_release_reaction_force_world_n.y > 0.0:
			var release_compensation_support_limbs: Array = []
			for release_support_limb_value in limbs:
				var release_support_limb: Dictionary = release_support_limb_value
				if String(release_support_limb["limb_id"]) == String(experiment["swing_limb_id"]):
					continue
				if _foot_shape_contacts_floor(release_support_limb):
					release_compensation_support_limbs.append(release_support_limb)
			if not release_compensation_support_limbs.is_empty():
				var release_compensation_force_per_support_n := minf(
					(
						contact_release_reaction_force_world_n.y
						/ float(release_compensation_support_limbs.size())
					),
					float(
						continuation_policy["maximum_contact_release_reaction_compensation_force_per_support_n"]
					)
				)
				for release_support_limb_value in release_compensation_support_limbs:
					var release_support_limb: Dictionary = release_support_limb_value
					_merge_torque_additions(
						joint_torque_additions,
						_joint_torques_for_endpoint_force(
							release_support_limb,
							torso,
							Vector3.DOWN * release_compensation_force_per_support_n
						)
					)
				contact_release_reaction_compensation_command_ticks += 1
				maximum_contact_release_reaction_compensation_force_per_support_n = maxf(
					maximum_contact_release_reaction_compensation_force_per_support_n,
					release_compensation_force_per_support_n
				)
				maximum_contact_release_reaction_compensation_total_force_n = maxf(
					maximum_contact_release_reaction_compensation_total_force_n,
					(
						release_compensation_force_per_support_n
						* float(release_compensation_support_limbs.size())
					)
				)
		var post_recontact_body_translation_delay_elapsed := (
			post_recontact_body_translation_enabled
			and semantic_release_recontact_tick >= 0
			and (
				tick
				>= (
					semantic_release_recontact_tick
					+ active_post_recontact_body_translation_delay_ticks
				)
			)
		)
		var continuation_body_translation_recovery_ready := (
			fixture_reused
			and post_recontact_body_translation_delay_elapsed
			and (
				torso.global_position.y
				>= float(continuation_policy["minimum_body_translation_recovery_torso_height_m"])
			)
			and (
				_tilt(torso)
				<= float(continuation_policy["maximum_body_translation_recovery_tilt_rad"])
			)
			and (
				torso.angular_velocity.length()
				<= float(
					continuation_policy["maximum_body_translation_recovery_angular_speed_rad_s"]
				)
			)
			and _all_feet_bearing(floor, limbs)
			and not (floor in torso.get_colliding_bodies())
		)
		if continuation_body_translation_recovery_ready:
			continuation_body_translation_recovery_dwell_ticks += 1
			maximum_continuation_body_translation_recovery_dwell_ticks = maxi(
				maximum_continuation_body_translation_recovery_dwell_ticks,
				continuation_body_translation_recovery_dwell_ticks
			)
		else:
			continuation_body_translation_recovery_dwell_ticks = 0
		if (
			fixture_reused
			and bool(continuation_policy["start_body_translation_without_recovery_dwell"])
			and post_recontact_body_translation_delay_elapsed
			and not continuation_body_translation_recovery_latched
			and (
				torso.global_position.y
				>= float(continuation_policy["minimum_body_translation_recovery_torso_height_m"])
			)
			and (
				_tilt(torso)
				<= float(continuation_policy["maximum_body_translation_recovery_tilt_rad"])
			)
			and _all_feet_bearing(floor, limbs)
			and not (floor in torso.get_colliding_bodies())
		):
			continuation_body_translation_recovery_latched = true
			continuation_body_translation_recovery_latch_tick = tick
			if bool(continuation_policy["rebase_joint_pose_reference_at_body_translation_handoff"]):
				_rebase_joint_pose_references(torso, limbs)
				continuation_joint_pose_reference_rebase_count += 1
				continuation_joint_pose_reference_rebase_tick = tick
		if (
			fixture_reused
			and not continuation_body_translation_recovery_latched
			and (
				continuation_body_translation_recovery_dwell_ticks
				>= int(continuation_policy["minimum_body_translation_recovery_dwell_ticks"])
			)
		):
			continuation_body_translation_recovery_latched = true
			continuation_body_translation_recovery_latch_tick = tick
			if bool(continuation_policy["rebase_joint_pose_reference_at_body_translation_handoff"]):
				_rebase_joint_pose_references(torso, limbs)
				continuation_joint_pose_reference_rebase_count += 1
				continuation_joint_pose_reference_rebase_tick = tick
		var continuation_body_translation_command_active := (
			fixture_reused
			and continuation_body_translation_recovery_latched
			and (
				tick
				< (
					continuation_body_translation_recovery_latch_tick
					+ int(continuation_policy["body_translation_command_ticks"])
				)
			)
		)
		var continuation_post_translation_stabilization_active := (
			fixture_reused
			and continuation_body_translation_recovery_latched
			and bool(continuation_policy["post_translation_stabilization_enabled"])
			and not continuation_body_translation_command_active
		)
		var post_recontact_body_translation_command_active := (
			post_recontact_body_translation_delay_elapsed
			and (not fixture_reused or continuation_body_translation_command_active)
		)
		var post_recontact_body_translation_authority_active := (
			post_recontact_body_translation_delay_elapsed
			and (
				not fixture_reused
				or continuation_body_translation_command_active
				or continuation_post_translation_stabilization_active
			)
		)
		continuation_recontact_support_recovery_active = (
			fixture_reused
			and bool(continuation_policy["resume_support_after_semantic_recontact"])
			and semantic_release_recontact_tick >= 0
			and tick > semantic_release_recontact_tick
		)
		if continuation_recontact_support_recovery_active:
			continuation_recontact_support_recovery_command_ticks += 1
		if (
			continuation_recontact_support_recovery_active
			and predictive_abort_hold
			and not post_recontact_body_translation_authority_active
			and not continuation_body_translation_recovery_latched
		):
			var continuation_measured_com: Vector3 = three_state["center_of_mass_world_m"]
			var continuation_measured_com_velocity: Vector3 = three_state["center_of_mass_velocity_world_m_s"]
			var continuation_vertical_feedback_force_n := clampf(
				(
					(
						float(experiment["vertical_position_gain_n_per_m"])
						* (initial_center_of_mass.y - continuation_measured_com.y)
					)
					- (
						float(experiment["vertical_velocity_gain_ns_per_m"])
						* continuation_measured_com_velocity.y
					)
				),
				-float(experiment["maximum_vertical_correction_n"]),
				float(experiment["maximum_vertical_correction_n"])
			)
			var continuation_total_weight_n := (
				float(profile["whole_system_mass_kg"]) * float(profile["gravity_m_s2"])
			)
			var continuation_normal_delta_n := (
				continuation_total_weight_n
				* (
					float(experiment["three_contact_commanded_normal_load_fraction"])
					- float(experiment["four_contact_commanded_normal_load_fraction"])
				)
			)
			var continuation_vertical_support_force_n := (
				continuation_normal_delta_n + continuation_vertical_feedback_force_n / 3.0
			)
			for continuation_limb_value in limbs:
				var continuation_limb: Dictionary = continuation_limb_value
				if String(continuation_limb["limb_id"]) == String(experiment["swing_limb_id"]):
					continue
				_merge_torque_additions(
					joint_torque_additions,
					_joint_torques_for_endpoint_force(
						continuation_limb, torso, Vector3.UP * continuation_vertical_support_force_n
					)
				)
			continuation_recontact_vertical_support_command_ticks += 1
			maximum_continuation_recontact_vertical_support_force_n = maxf(
				maximum_continuation_recontact_vertical_support_force_n,
				absf(continuation_vertical_support_force_n)
			)
		if (
			continuation_recontact_support_recovery_active
			and predictive_abort_hold
			and not post_recontact_body_translation_authority_active
			and not continuation_body_translation_recovery_latched
			and bool(continuation_policy["continuation_recontact_attitude_recovery_enabled"])
			and _all_feet_bearing(floor, limbs)
			and not (floor in torso.get_colliding_bodies())
		):
			var continuation_attitude_position_gain := float(
				continuation_policy["continuation_recontact_attitude_position_gain_nm_per_rad"]
			)
			var continuation_attitude_velocity_gain := float(
				continuation_policy["continuation_recontact_attitude_velocity_gain_nm_s_per_rad"]
			)
			var continuation_attitude_moment_limit := float(
				continuation_policy["maximum_continuation_recontact_roll_pitch_moment_nm"]
			)
			var continuation_roll_moment_nm := clampf(
				(
					(
						continuation_attitude_position_gain
						* (lift_entry_roll_reference_rad - _signed_roll_rad(torso))
					)
					- (
						continuation_attitude_velocity_gain
						* torso.angular_velocity.dot(Vector3.RIGHT)
					)
				),
				-continuation_attitude_moment_limit,
				continuation_attitude_moment_limit
			)
			var continuation_pitch_moment_nm := clampf(
				(
					(
						continuation_attitude_position_gain
						* (lift_entry_pitch_reference_rad - _signed_pitch_rad(torso))
					)
					- continuation_attitude_velocity_gain * torso.angular_velocity.dot(Vector3.BACK)
				),
				-continuation_attitude_moment_limit,
				continuation_attitude_moment_limit
			)
			_merge_torque_additions(
				joint_torque_additions,
				_support_body_axis_torque_additions(
					limbs, "", torso, continuation_roll_moment_nm, "hip_abduction", Vector3.RIGHT
				)
			)
			_merge_torque_additions(
				joint_torque_additions,
				_support_body_axis_torque_additions(
					limbs, "", torso, continuation_pitch_moment_nm, "hip_pitch", Vector3.BACK
				)
			)
			var continuation_yaw_moment_limit := float(
				continuation_policy["maximum_continuation_recontact_yaw_moment_nm"]
			)
			var continuation_yaw_moment_nm := clampf(
				(
					-float(
						continuation_policy["continuation_recontact_yaw_velocity_gain_nm_s_per_rad"]
					)
					* torso.angular_velocity.dot(Vector3.UP)
				),
				-continuation_yaw_moment_limit,
				continuation_yaw_moment_limit
			)
			var continuation_yaw_damping := _ground_mediated_yaw_damping_additions(
				limbs,
				floor,
				torso,
				continuation_yaw_moment_nm,
				float(continuation_policy["maximum_continuation_recontact_yaw_endpoint_force_n"])
			)
			_merge_torque_additions(
				joint_torque_additions, continuation_yaw_damping["joint_torque_additions"]
			)
			continuation_recontact_attitude_recovery_command_ticks += 1
			maximum_continuation_recontact_roll_pitch_moment_nm = maxf(
				maximum_continuation_recontact_roll_pitch_moment_nm,
				maxf(absf(continuation_roll_moment_nm), absf(continuation_pitch_moment_nm))
			)
			maximum_continuation_recontact_yaw_moment_nm = maxf(
				maximum_continuation_recontact_yaw_moment_nm, absf(continuation_yaw_moment_nm)
			)
			maximum_continuation_recontact_yaw_endpoint_force_n = maxf(
				maximum_continuation_recontact_yaw_endpoint_force_n,
				float(continuation_yaw_damping["maximum_endpoint_force_n"])
			)
		if continuation_post_translation_stabilization_active:
			if continuation_post_translation_stabilization_start_tick < 0:
				continuation_post_translation_stabilization_start_tick = tick
				continuation_post_translation_stabilization_start_torso_height_m = (
					torso.global_position.y
				)
			continuation_post_translation_stabilization_command_ticks += 1
		if (
			tick >= shift_start_tick
			and (not predictive_abort_hold or post_recontact_body_translation_authority_active)
		):
			var shift_fraction := 1.0
			if tick < shift_complete_tick:
				shift_fraction = _smoothstep(
					float(tick - shift_start_tick) / float(shift_complete_tick - shift_start_tick)
				)
			var target_center_of_mass := initial_center_of_mass.lerp(
				triangle_target_center_of_mass, shift_fraction
			)
			var continuation_gait_airborne_body_advance_offset_world_m := Vector3.ZERO
			if (
				fixture_reused
				and contact_release_latched
				and gait_airborne_body_advance_m > 0.0
				and tick < recenter_complete_tick
			):
				var declared_body_translation_offset := _vector3(
					experiment["post_recontact_body_translation_offset_world_m"]
				)
				declared_body_translation_offset.y = 0.0
				if not declared_body_translation_offset.is_zero_approx():
					var gait_advance_fraction := _smoothstep(
						clampf(
							(
								float(tick - contact_release_first_tick)
								/ float(gait_airborne_body_advance_ramp_ticks)
							),
							0.0,
							1.0
						)
					)
					continuation_gait_airborne_body_advance_offset_world_m = (
						declared_body_translation_offset.normalized()
						* gait_airborne_body_advance_m
						* gait_advance_fraction
					)
					if not continuation_gait_airborne_body_advance_offset_world_m.is_zero_approx():
						if continuation_gait_airborne_body_advance_first_tick < 0:
							continuation_gait_airborne_body_advance_first_tick = tick
						continuation_gait_airborne_body_advance_last_tick = tick
						continuation_gait_airborne_body_advance_command_ticks += 1
						maximum_continuation_gait_airborne_body_advance_target_m = maxf(
							maximum_continuation_gait_airborne_body_advance_target_m,
							continuation_gait_airborne_body_advance_offset_world_m.length()
						)
			if three_contact_entry_established:
				target_center_of_mass = (
					three_contact_hold_target
					+ continuation_gait_airborne_body_advance_offset_world_m
				)
			if (
				feasibility_gated_swing
				and tick >= lift_start_tick
				and (
					not fixture_reused
					or not bool(
						continuation_policy["hold_bounded_readiness_target_during_airborne_phase"]
					)
				)
			):
				var live_triangle_incenter := _triangle_incenter_world(three_support_points)
				target_center_of_mass = Vector3(
					live_triangle_incenter.x, initial_center_of_mass.y, live_triangle_incenter.z
				)
			var swing_contact_now := _foot_shape_contacts_floor(swing_limb)
			if (
				(
					String(experiment["centroidal_controller_id"])
					in [
						WHOLE_SYSTEM_ALLOCATOR_CONTROLLER_ID,
						FEASIBILITY_GATED_ALLOCATOR_CONTROLLER_ID,
						UNLOAD_THEN_LIFT_ALLOCATOR_CONTROLLER_ID,
						CONTACT_STATE_LIFT_ALLOCATOR_CONTROLLER_ID,
						SEMANTIC_RELEASE_RECONTACT_ALLOCATOR_CONTROLLER_ID,
						SEMANTIC_RELOCATION_RECONTACT_CONTROLLER_ID,
						SEMANTIC_RECONTACT_JOINT_DAMPING_CONTROLLER_ID,
						POST_RECONTACT_BODY_TRANSLATION_CONTROLLER_ID,
					]
				)
				and tick >= lift_start_tick
			):
				support_allocator_engaged = true
			if (
				touchdown_enabled
				and first_touch_tick >= 0
				and swing_contact_now
				and tick >= recenter_start_tick
			):
				var four_points := _support_points_world(
					limbs, String(experiment["swing_limb_id"]), true
				)
				var four_state := DynamicSupportObserverScript.observe(
					body_by_id, four_points, float(profile["gravity_m_s2"])
				)
				if not bool(four_state.get("ok", false)):
					fixture_complete = false
					support_state_observations_complete = false
					fixture_failure_code = String(
						four_state.get(
							"failure_code", "SPATIAL_CENTROIDAL_FOUR_SUPPORT_OBSERVATION_FAILED"
						)
					)
					break
				var four_centroid: Vector3 = four_state["support_centroid_world_m"]
				var four_target := Vector3(
					four_centroid.x, initial_center_of_mass.y, four_centroid.z
				)
				target_center_of_mass = (
					(
						three_contact_hold_target
						+ continuation_gait_airborne_body_advance_offset_world_m
					)
					. lerp(
						four_target,
						_smoothstep(
							clampf(
								(
									float(tick - recenter_start_tick)
									/ float(recenter_complete_tick - recenter_start_tick)
								),
								0.0,
								1.0
							)
						)
					)
				)
			var measured_com: Vector3 = three_state["center_of_mass_world_m"]
			var measured_com_velocity: Vector3 = three_state["center_of_mass_velocity_world_m_s"]
			if not continuation_gait_airborne_body_advance_offset_world_m.is_zero_approx():
				if continuation_gait_airborne_body_advance_start_com_world_m.is_finite() == false:
					continuation_gait_airborne_body_advance_start_com_world_m = measured_com
				continuation_gait_airborne_body_advance_last_com_world_m = measured_com
			if post_recontact_body_translation_authority_active:
				if post_recontact_body_translation_start_tick < 0:
					post_recontact_body_translation_start_tick = tick
					post_recontact_body_translation_start_com_world_m = measured_com
					post_recontact_body_translation_start_torso_world_m = torso.global_position
					for translation_limb_value in limbs:
						var translation_limb: Dictionary = translation_limb_value
						post_recontact_body_translation_start_foot_world_by_limb[String(translation_limb["limb_id"])] = _foot_center_world(
							translation_limb
						)
						post_recontact_body_translation_support_relative_world_by_limb[String(translation_limb["limb_id"])] = (
							_foot_center_world(translation_limb) - torso.global_position
						)
				var translation_fraction := _smoothstep(
					clampf(
						(
							float(tick - post_recontact_body_translation_start_tick)
							/ float(experiment["post_recontact_body_translation_ramp_ticks"])
						),
						0.0,
						1.0
					)
				)
				var body_translation_offset_world_m := _vector3(
					experiment["post_recontact_body_translation_offset_world_m"]
				)
				if fixture_reused:
					body_translation_offset_world_m *= float(
						continuation_policy["body_translation_target_scale"]
					)
				post_recontact_body_translation_target_com_world_m = (
					post_recontact_body_translation_start_com_world_m
					+ body_translation_offset_world_m * translation_fraction
				)
				target_center_of_mass = post_recontact_body_translation_target_com_world_m
				if post_recontact_body_translation_command_active:
					post_recontact_body_translation_command_tick_count += 1
					maximum_post_recontact_body_translation_target_error_m = maxf(
						maximum_post_recontact_body_translation_target_error_m,
						(
							Vector2(
								target_center_of_mass.x - measured_com.x,
								target_center_of_mass.z - measured_com.z
							)
							. length()
						)
					)
			var airborne_authority_fraction := 0.0
			if tick >= lift_start_tick:
				var authority_progress_ticks := (
					(
						swing_unload_progress_ticks
						if unload_then_lift_enabled
						else swing_path_progress_for_command
					)
					if feasibility_gated_swing
					else tick - lift_start_tick
				)
				var authority_time_fraction := _smoothstep(
					clampf(
						(
							float(authority_progress_ticks)
							/ float(int(experiment["support_authority_ramp_ticks"]))
						),
						0.0,
						1.0
					)
				)
				var full_authority_margin := float(
					experiment["support_authority_full_capture_margin_m"]
				)
				var release_authority_margin := float(
					experiment["support_authority_release_capture_margin_m"]
				)
				var capture_risk_fraction := clampf(
					(
						(release_authority_margin - current_capture_margin_m)
						/ (release_authority_margin - full_authority_margin)
					),
					0.0,
					1.0
				)
				airborne_authority_fraction = (
					authority_time_fraction * _smoothstep(capture_risk_fraction)
				)
			var active_horizontal_position_gain := lerpf(
				float(experiment["horizontal_position_gain_n_per_m"]),
				float(experiment["airborne_horizontal_position_gain_n_per_m"]),
				airborne_authority_fraction
			)
			var active_horizontal_velocity_gain := lerpf(
				float(experiment["horizontal_velocity_gain_ns_per_m"]),
				float(experiment["airborne_horizontal_velocity_gain_ns_per_m"]),
				airborne_authority_fraction
			)
			var active_maximum_horizontal_force := lerpf(
				float(experiment["maximum_horizontal_force_n"]),
				float(experiment["airborne_maximum_horizontal_force_n"]),
				airborne_authority_fraction
			)
			var active_maximum_support_shift := lerpf(
				float(experiment["maximum_support_horizontal_shift_m"]),
				float(experiment["airborne_maximum_support_horizontal_shift_m"]),
				airborne_authority_fraction
			)
			var active_maximum_endpoint_force := lerpf(
				float(experiment["maximum_support_endpoint_force_n"]),
				float(experiment["airborne_maximum_support_endpoint_force_n"]),
				airborne_authority_fraction
			)
			if post_recontact_body_translation_authority_active:
				active_horizontal_position_gain = float(
					experiment["post_recontact_body_translation_position_gain_n_per_m"]
				)
				active_horizontal_velocity_gain = float(
					experiment["post_recontact_body_translation_velocity_gain_ns_per_m"]
				)
				active_maximum_horizontal_force = float(
					experiment["maximum_post_recontact_body_translation_horizontal_force_n"]
				)
				active_maximum_support_shift = float(
					experiment["maximum_post_recontact_body_translation_support_shift_m"]
				)
				active_maximum_endpoint_force = float(
					experiment["maximum_post_recontact_body_translation_endpoint_force_n"]
				)
			var desired_horizontal_force := Vector3(
				(
					active_horizontal_position_gain * (target_center_of_mass.x - measured_com.x)
					- active_horizontal_velocity_gain * measured_com_velocity.x
				),
				0.0,
				(
					active_horizontal_position_gain * (target_center_of_mass.z - measured_com.z)
					- active_horizontal_velocity_gain * measured_com_velocity.z
				)
			)
			if desired_horizontal_force.length() > active_maximum_horizontal_force:
				desired_horizontal_force *= (
					active_maximum_horizontal_force / desired_horizontal_force.length()
				)
			var base_horizontal_force := Vector3(
				(
					(
						float(experiment["horizontal_position_gain_n_per_m"])
						* (target_center_of_mass.x - measured_com.x)
					)
					- (
						float(experiment["horizontal_velocity_gain_ns_per_m"])
						* measured_com_velocity.x
					)
				),
				0.0,
				(
					(
						float(experiment["horizontal_position_gain_n_per_m"])
						* (target_center_of_mass.z - measured_com.z)
					)
					- (
						float(experiment["horizontal_velocity_gain_ns_per_m"])
						* measured_com_velocity.z
					)
				)
			)
			if post_recontact_body_translation_authority_active:
				base_horizontal_force = desired_horizontal_force
			var base_maximum_horizontal_force := (
				active_maximum_horizontal_force
				if post_recontact_body_translation_authority_active
				else float(experiment["maximum_horizontal_force_n"])
			)
			if base_horizontal_force.length() > base_maximum_horizontal_force:
				base_horizontal_force *= (
					base_maximum_horizontal_force / base_horizontal_force.length()
				)
			var continuation_body_translation_three_support_active := (
				fixture_reused
				and post_recontact_body_translation_authority_active
				and bool(
					continuation_policy["exclude_recontacted_limb_from_body_translation_support"]
				)
			)
			if (
				continuation_body_translation_three_support_active
				and post_recontact_body_translation_command_active
			):
				continuation_body_translation_three_support_command_ticks += 1
			var support_count := (
				3.0
				if continuation_body_translation_three_support_active
				else (4.0 if post_recontact_body_translation_authority_active else 3.0)
			)
			var endpoint_gain := (
				float(experiment["post_recontact_body_translation_endpoint_position_gain_n_per_m"])
				if post_recontact_body_translation_authority_active
				else float(experiment["support_endpoint_position_gain_n_per_m"])
			)
			var body_shift_reference := (
				post_recontact_body_translation_start_com_world_m
				if post_recontact_body_translation_authority_active
				else initial_center_of_mass
			)
			var desired_body_shift := target_center_of_mass - body_shift_reference
			desired_body_shift.y = 0.0
			desired_body_shift += desired_horizontal_force / (support_count * endpoint_gain)
			var base_desired_body_shift := target_center_of_mass - body_shift_reference
			base_desired_body_shift.y = 0.0
			base_desired_body_shift += (base_horizontal_force / (support_count * endpoint_gain))
			var horizontal_shift := Vector2(desired_body_shift.x, desired_body_shift.z)
			if horizontal_shift.length() > active_maximum_support_shift:
				horizontal_shift *= (active_maximum_support_shift / horizontal_shift.length())
				desired_body_shift.x = horizontal_shift.x
				desired_body_shift.z = horizontal_shift.y
			var base_horizontal_shift := Vector2(
				base_desired_body_shift.x, base_desired_body_shift.z
			)
			var base_maximum_support_shift := (
				active_maximum_support_shift
				if post_recontact_body_translation_authority_active
				else float(experiment["maximum_support_horizontal_shift_m"])
			)
			if base_horizontal_shift.length() > base_maximum_support_shift:
				base_horizontal_shift *= (
					base_maximum_support_shift / base_horizontal_shift.length()
				)
				base_desired_body_shift.x = base_horizontal_shift.x
				base_desired_body_shift.z = base_horizontal_shift.y
			var vertical_position_reference_m := (
				post_recontact_body_translation_start_com_world_m.y
				if post_recontact_body_translation_authority_active
				else initial_center_of_mass.y
			)
			var vertical_position_measurement_m := measured_com.y
			var vertical_velocity_measurement_m_s := measured_com_velocity.y
			if continuation_post_translation_stabilization_active:
				var post_translation_stabilization_fraction := _smoothstep(
					clampf(
						(
							float(tick - continuation_post_translation_stabilization_start_tick)
							/ float(
								maxi(
									int(
										continuation_policy["post_translation_stabilization_ramp_ticks"]
									),
									1
								)
							)
						),
						0.0,
						1.0
					)
				)
				vertical_position_reference_m = lerpf(
					continuation_post_translation_stabilization_start_torso_height_m,
					continuation_post_translation_stabilization_target_torso_height_m,
					post_translation_stabilization_fraction
				)
				vertical_position_measurement_m = torso.global_position.y
				vertical_velocity_measurement_m_s = torso.linear_velocity.y
			var vertical_feedback_force := clampf(
				(
					(
						float(experiment["vertical_position_gain_n_per_m"])
						* (vertical_position_reference_m - vertical_position_measurement_m)
					)
					- (
						float(experiment["vertical_velocity_gain_ns_per_m"])
						* vertical_velocity_measurement_m_s
					)
				),
				-float(experiment["maximum_vertical_correction_n"]),
				float(experiment["maximum_vertical_correction_n"])
			)
			var unload_fraction := 0.0
			if tick >= lift_start_tick:
				var unload_progress_ticks := (
					(
						swing_unload_progress_ticks
						if unload_then_lift_enabled
						else swing_path_progress_for_command
					)
					if feasibility_gated_swing
					else tick - lift_start_tick
				)
				unload_fraction = _smoothstep(
					clampf(
						(
							float(unload_progress_ticks)
							/ float(int(experiment["support_authority_ramp_ticks"]))
						),
						0.0,
						1.0
					)
				)
				if hybrid_release_enabled:
					unload_fraction = 1.0
			if post_recontact_body_translation_authority_active:
				unload_fraction = 0.0
			if first_touch_tick >= 0 and tick >= recenter_start_tick:
				unload_fraction *= (
					1.0
					- _smoothstep(
						clampf(
							(
								float(tick - recenter_start_tick)
								/ float(recenter_complete_tick - recenter_start_tick)
							),
							0.0,
							1.0
						)
					)
				)
			if tick < lift_start_tick:
				desired_body_shift.y = -(vertical_feedback_force / (support_count * endpoint_gain))
			else:
				desired_body_shift.y = (
					float(experiment["three_contact_vertical_support_shift_m"]) * unload_fraction
					+ vertical_feedback_force / (support_count * endpoint_gain)
				)
			base_desired_body_shift.y = desired_body_shift.y
			var torso_roll := _signed_roll_rad(torso)
			var attitude_excluded_limb_id := String(experiment["swing_limb_id"])
			if (
				fixture_reused
				and bool(continuation_policy["readmit_recontacted_limb_to_attitude_control"])
				and semantic_release_recontact_tick >= 0
				and _all_feet_bearing(floor, limbs)
			):
				attitude_excluded_limb_id = ""
				continuation_four_contact_attitude_command_ticks += 1
			var whole_system_allocator_active := (
				support_allocator_engaged
				and not predictive_abort_hold
				and not post_recontact_body_translation_authority_active
			)
			var active_roll_position_gain := lerpf(
				float(experiment["roll_position_gain_nm_per_rad"]),
				float(experiment["airborne_roll_position_gain_nm_per_rad"]),
				unload_fraction
			)
			var active_roll_velocity_gain := lerpf(
				float(experiment["roll_velocity_gain_nm_s_per_rad"]),
				float(experiment["airborne_roll_velocity_gain_nm_s_per_rad"]),
				unload_fraction
			)
			var post_recontact_age_ticks := tick - semantic_release_recontact_tick
			var declared_attitude_velocity_feedback_override_active := (
				semantic_release_recontact_tick >= 0
				and (
					post_recontact_age_ticks
					>= int(
						experiment.get(
							"post_recontact_attitude_velocity_feedback_override_delay_ticks", 0
						)
					)
				)
				and (
					not experiment.has(
						"post_recontact_attitude_velocity_feedback_override_duration_ticks"
					)
					or (
						post_recontact_age_ticks
						< (
							int(
								(
									experiment
									. get(
										"post_recontact_attitude_velocity_feedback_override_delay_ticks",
										0
									)
								)
							)
							+ int(
								experiment["post_recontact_attitude_velocity_feedback_override_duration_ticks"]
							)
						)
					)
				)
			)
			if (
				declared_attitude_velocity_feedback_override_active
				and experiment.has("post_recontact_roll_velocity_gain_nm_s_per_rad")
			):
				active_roll_velocity_gain = float(
					experiment["post_recontact_roll_velocity_gain_nm_s_per_rad"]
				)
				post_recontact_attitude_velocity_feedback_override_tick_count += 1
			var desired_roll_torque := clampf(
				(
					-active_roll_position_gain * torso_roll
					- active_roll_velocity_gain * torso.angular_velocity.dot(Vector3.RIGHT)
				),
				-float(experiment["maximum_roll_pitch_moment_nm"]),
				float(experiment["maximum_roll_pitch_moment_nm"])
			)
			if not whole_system_allocator_active:
				_merge_torque_additions(
					joint_torque_additions,
					_support_body_axis_torque_additions(
						limbs,
						attitude_excluded_limb_id,
						torso,
						desired_roll_torque,
						"hip_abduction",
						Vector3.RIGHT
					)
				)
			var torso_pitch := _signed_pitch_rad(torso)
			var active_pitch_position_gain := lerpf(
				float(experiment["pitch_position_gain_nm_per_rad"]),
				float(experiment["airborne_pitch_position_gain_nm_per_rad"]),
				unload_fraction
			)
			var active_pitch_velocity_gain := lerpf(
				float(experiment["pitch_velocity_gain_nm_s_per_rad"]),
				float(experiment["airborne_pitch_velocity_gain_nm_s_per_rad"]),
				unload_fraction
			)
			if (
				declared_attitude_velocity_feedback_override_active
				and experiment.has("post_recontact_pitch_velocity_gain_nm_s_per_rad")
			):
				active_pitch_velocity_gain = float(
					experiment["post_recontact_pitch_velocity_gain_nm_s_per_rad"]
				)
			var desired_pitch_torque := clampf(
				(
					active_pitch_position_gain * (lift_entry_pitch_reference_rad - torso_pitch)
					- active_pitch_velocity_gain * torso.angular_velocity.dot(Vector3.BACK)
				),
				-float(experiment["maximum_roll_pitch_moment_nm"]),
				float(experiment["maximum_roll_pitch_moment_nm"])
			)
			if not whole_system_allocator_active:
				_merge_torque_additions(
					joint_torque_additions,
					_support_body_axis_torque_additions(
						limbs,
						attitude_excluded_limb_id,
						torso,
						desired_pitch_torque,
						"hip_pitch",
						Vector3.BACK
					)
				)
			if (
				bool(experiment.get("post_recontact_yaw_rate_damping_enabled", false))
				and semantic_release_recontact_tick >= 0
			):
				var desired_yaw_damping_moment_nm := clampf(
					(
						-float(experiment["post_recontact_yaw_rate_gain_nm_s_per_rad"])
						* torso.angular_velocity.dot(Vector3.UP)
					),
					-float(experiment["maximum_post_recontact_yaw_damping_moment_nm"]),
					float(experiment["maximum_post_recontact_yaw_damping_moment_nm"])
				)
				var yaw_damping_result := _ground_mediated_yaw_damping_additions(
					limbs,
					floor,
					torso,
					desired_yaw_damping_moment_nm,
					float(experiment["maximum_post_recontact_yaw_damping_endpoint_force_n"])
				)
				_merge_torque_additions(
					joint_torque_additions, yaw_damping_result["joint_torque_additions"]
				)
				post_recontact_yaw_damping_command_tick_count += 1
				maximum_post_recontact_yaw_damping_moment_nm = maxf(
					maximum_post_recontact_yaw_damping_moment_nm,
					absf(desired_yaw_damping_moment_nm)
				)
				maximum_post_recontact_yaw_damping_endpoint_force_n = maxf(
					maximum_post_recontact_yaw_damping_endpoint_force_n,
					float(yaw_damping_result["maximum_endpoint_force_n"])
				)
			for limb_value in limbs:
				var support_limb: Dictionary = limb_value
				var support_limb_id := String(support_limb["limb_id"])
				if (
					support_limb_id == String(experiment["swing_limb_id"])
					and (
						not post_recontact_body_translation_authority_active
						or continuation_body_translation_three_support_active
					)
				):
					continue
				var active_support_relative_world: Vector3 = support_relative_world_by_limb[support_limb_id]
				if post_recontact_body_translation_authority_active:
					active_support_relative_world = (post_recontact_body_translation_support_relative_world_by_limb[support_limb_id])
				var support_target := (
					torso.global_position + active_support_relative_world - base_desired_body_shift
				)
				var active_support_endpoint_position_gain := (
					float(
						experiment["post_recontact_body_translation_endpoint_position_gain_n_per_m"]
					)
					if post_recontact_body_translation_authority_active
					else float(experiment["support_endpoint_position_gain_n_per_m"])
				)
				var active_support_endpoint_velocity_gain := (
					float(
						experiment["post_recontact_body_translation_endpoint_velocity_gain_ns_per_m"]
					)
					if post_recontact_body_translation_authority_active
					else float(experiment["support_endpoint_velocity_gain_ns_per_m"])
				)
				var active_support_endpoint_force_cap := (
					active_maximum_endpoint_force
					if post_recontact_body_translation_authority_active
					else float(experiment["maximum_support_endpoint_force_n"])
				)
				var support_result := _task_space_joint_torques(
					support_limb,
					torso,
					support_target,
					torso.linear_velocity,
					active_support_endpoint_position_gain,
					active_support_endpoint_velocity_gain,
					active_support_endpoint_force_cap
				)
				_merge_torque_additions(
					joint_torque_additions, support_result["joint_torque_overrides"]
				)
				var total_weight_n := (
					float(profile["whole_system_mass_kg"]) * float(profile["gravity_m_s2"])
				)
				var commanded_normal_delta_n := (
					total_weight_n
					* unload_fraction
					* (
						float(experiment["three_contact_commanded_normal_load_fraction"])
						- float(experiment["four_contact_commanded_normal_load_fraction"])
					)
				)
				if not whole_system_allocator_active:
					_merge_torque_additions(
						joint_torque_additions,
						_normal_load_feedforward_additions(support_limb, commanded_normal_delta_n)
					)
				if airborne_authority_fraction > 0.0 and not whole_system_allocator_active:
					var additional_body_shift := desired_body_shift - base_desired_body_shift
					additional_body_shift.y = 0.0
					var additional_endpoint_force := -endpoint_gain * additional_body_shift
					var maximum_additional_endpoint_force := maxf(
						0.0,
						(
							active_maximum_endpoint_force
							- float(experiment["maximum_support_endpoint_force_n"])
						)
					)
					if additional_endpoint_force.length() > maximum_additional_endpoint_force:
						additional_endpoint_force *= (
							maximum_additional_endpoint_force / additional_endpoint_force.length()
						)
					var risk_additions := _joint_torques_for_endpoint_force(
						support_limb, torso, additional_endpoint_force
					)
					risk_additions.erase("%s.knee_pitch" % support_limb_id)
					_merge_torque_additions(joint_torque_additions, risk_additions)
				maximum_commanded_support_endpoint_force_n = maxf(
					maximum_commanded_support_endpoint_force_n, active_maximum_endpoint_force
				)
			if whole_system_allocator_active:
				support_allocator_used = true
				var total_allocator_weight_n := (
					float(profile["whole_system_mass_kg"]) * float(profile["gravity_m_s2"])
				)
				var nominal_four_contact_normal_n := total_allocator_weight_n / 4.0
				var commanded_swing_support_enabled := (
					swing_contact_now
					and not (
						hybrid_release_enabled and tick >= lift_start_tick and first_touch_tick < 0
					)
				)
				var allocator_support_contacts := _support_contact_records(
					limbs, String(experiment["swing_limb_id"]), commanded_swing_support_enabled
				)
				var swing_preferred_normal_n := (
					nominal_four_contact_normal_n * (1.0 - unload_fraction)
					if commanded_swing_support_enabled
					else 0.0
				)
				var stance_preferred_normal_n := (
					(total_allocator_weight_n - swing_preferred_normal_n) / 3.0
				)
				for contact_value in allocator_support_contacts:
					var contact: Dictionary = contact_value
					contact["preferred_normal_force_n"] = (
						swing_preferred_normal_n
						if String(contact["contact_id"]) == String(experiment["swing_contact_id"])
						else stance_preferred_normal_n
					)
				var allocator_request := {
					"schema_version": CentroidalSupportControllerScript.REQUEST_SCHEMA_VERSION,
					"tick": tick,
					"whole_system_mass_kg": float(profile["whole_system_mass_kg"]),
					"gravity_m_s2": float(profile["gravity_m_s2"]),
					"center_of_mass_world_m": measured_com,
					"center_of_mass_velocity_world_m_s": measured_com_velocity,
					"target_center_of_mass_world_m": target_center_of_mass,
					"torso_roll_rad": torso_roll - lift_entry_roll_reference_rad,
					"torso_pitch_rad": torso_pitch - lift_entry_pitch_reference_rad,
					"torso_roll_rate_rad_s": torso.angular_velocity.dot(Vector3.RIGHT),
					"torso_pitch_rate_rad_s": torso.angular_velocity.dot(Vector3.BACK),
					"horizontal_position_gain_n_per_m": active_horizontal_position_gain,
					"horizontal_velocity_gain_ns_per_m": active_horizontal_velocity_gain,
					"vertical_position_gain_n_per_m": 0.0,
					"vertical_velocity_gain_ns_per_m": 0.0,
					"roll_position_gain_nm_per_rad": active_roll_position_gain,
					"roll_velocity_gain_nm_s_per_rad": active_roll_velocity_gain,
					"pitch_position_gain_nm_per_rad": active_pitch_position_gain,
					"pitch_velocity_gain_nm_s_per_rad": active_pitch_velocity_gain,
					"maximum_horizontal_force_n": active_maximum_horizontal_force,
					"maximum_vertical_correction_n": 0.0,
					"maximum_roll_pitch_moment_nm":
					float(experiment["maximum_roll_pitch_moment_nm"]),
					"declared_supported_weight_fraction": 1.0,
					"friction_coefficient": float(profile["contact_friction_coefficient"]),
					"minimum_normal_force_n": 0.0,
					"maximum_normal_force_n": float(profile["contact_normal_capacity_n"]),
					"nominal_support_count": 4,
					"feasibility_tolerance": 1.0e-5,
					"support_contacts": allocator_support_contacts,
				}
				var allocator_result: Dictionary = {}
				var allocator_command: Dictionary = {}
				var selected_authority_scale := -1.0
				for authority_scale in [1.0, 0.75, 0.50, 0.25, 0.0]:
					var scaled_request := allocator_request.duplicate(true)
					for gain_field in [
						"horizontal_position_gain_n_per_m",
						"horizontal_velocity_gain_ns_per_m",
						"roll_position_gain_nm_per_rad",
						"roll_velocity_gain_nm_s_per_rad",
						"pitch_position_gain_nm_per_rad",
						"pitch_velocity_gain_nm_s_per_rad",
						"maximum_horizontal_force_n",
						"maximum_roll_pitch_moment_nm",
					]:
						scaled_request[gain_field] = (
							float(scaled_request[gain_field]) * float(authority_scale)
						)
					allocator_result = CentroidalSupportControllerScript.command(scaled_request)
					support_allocator_solve_attempt_count += 1
					if not bool(allocator_result.get("ok", false)):
						break
					allocator_command = allocator_result["command"]
					if bool(allocator_command["feasible"]):
						selected_authority_scale = float(authority_scale)
						break
				support_allocator_command_count += 1
				if not bool(allocator_result.get("ok", false)):
					fixture_complete = false
					fixture_failure_code = String(
						allocator_result.get("failure_code", "SPATIAL_CENTROIDAL_ALLOCATOR_FAILED")
					)
					break
				last_support_allocator_authority_scale = selected_authority_scale
				minimum_support_allocator_authority_scale = minf(
					minimum_support_allocator_authority_scale, maxf(selected_authority_scale, 0.0)
				)
				last_support_allocator_infeasibility_reasons = (
					(allocator_command["infeasibility_reasons"] as Array).duplicate(true)
				)
				last_support_allocator_contact_commands = (
					(allocator_command["support_contact_commands"] as Dictionary).duplicate(true)
				)
				maximum_support_allocator_force_residual_n = maxf(
					maximum_support_allocator_force_residual_n,
					(allocator_command["force_residual_n"] as Vector3).length()
				)
				maximum_support_allocator_moment_residual_nm = maxf(
					maximum_support_allocator_moment_residual_nm,
					(allocator_command["roll_pitch_moment_residual_nm"] as Vector2).length()
				)
				minimum_support_allocator_normal_reserve_n = minf(
					minimum_support_allocator_normal_reserve_n,
					float(allocator_command["minimum_normal_reserve_n"])
				)
				minimum_support_allocator_friction_reserve_n = minf(
					minimum_support_allocator_friction_reserve_n,
					float(allocator_command["minimum_friction_reserve_n"])
				)
				if selected_authority_scale < 0.0:
					support_allocator_infeasible_count += 1
					fixture_complete = false
					fixture_failure_code = "SPATIAL_CENTROIDAL_ALLOCATOR_INFEASIBLE"
					break
				for contact_value in allocator_command["support_contact_commands"].values():
					var contact_command: Dictionary = contact_value
					var contact_limb := _limb_for_contact(
						limbs, String(contact_command["contact_id"])
					)
					if contact_limb.is_empty():
						fixture_complete = false
						fixture_failure_code = "SPATIAL_CENTROIDAL_ALLOCATOR_CONTACT_LIMB_MISSING"
						break
					_merge_torque_additions(
						joint_torque_additions,
						_joint_torques_for_endpoint_force(
							contact_limb, torso, contact_command["joint_task_force_delta_world_n"]
						)
					)
				if not fixture_complete:
					break
			support_controller_command_count += 1

		if (
			semantic_recontact_joint_damping_enabled
			and semantic_release_recontact_tick >= 0
			and (
				tick - semantic_release_recontact_tick
				< int(experiment["semantic_joint_damping_ticks"])
			)
		):
			var damping_limbs := limbs
			var damping_scope := String(experiment["semantic_joint_damping_limb_scope"])
			if damping_scope == "adaptive_swing_rate_norm_v1":
				if semantic_joint_damping_first_tick < 0:
					var swing_rate_observation := _relative_joint_rate_damping_additions(
						[swing_limb], torso, 0.0, 0.0
					)
					var swing_rate_square_sum := 0.0
					for rate_value in (
						(swing_rate_observation["joint_rates_by_id_rad_s"] as Dictionary).values()
					):
						var joint_rate := float(rate_value)
						swing_rate_square_sum += joint_rate * joint_rate
					semantic_swing_joint_rate_norm_at_damping_start_rad_s = sqrt(
						swing_rate_square_sum
					)
					semantic_all_limb_damping_latched = (
						semantic_swing_joint_rate_norm_at_damping_start_rad_s
						>= float(experiment["semantic_all_limb_damping_activation_rate_rad_s"])
					)
				if not semantic_all_limb_damping_latched:
					damping_limbs = [swing_limb]
			elif damping_scope == "swing_limb_only":
				damping_limbs = [swing_limb]
			var damping_result := _relative_joint_rate_damping_additions(
				damping_limbs,
				torso,
				active_semantic_joint_rate_damping_nm_s_per_rad,
				active_maximum_semantic_joint_damping_torque_nm
			)
			_merge_torque_additions(
				joint_torque_additions, damping_result["joint_torque_additions"]
			)
			if semantic_joint_damping_first_tick < 0:
				semantic_joint_damping_first_tick = tick
				semantic_joint_damping_start_torso_height_m = torso.global_position.y
				semantic_joint_damping_start_torso_tilt_rad = _tilt(torso)
				semantic_joint_damping_start_torso_angular_velocity_world_rad_s = (
					torso.angular_velocity
				)
				semantic_joint_rates_at_damping_start_rad_s = (
					(damping_result["joint_rates_by_id_rad_s"] as Dictionary).duplicate(true)
				)
			semantic_joint_damping_command_tick_count += 1
			maximum_semantic_joint_damping_command_nm = maxf(
				maximum_semantic_joint_damping_command_nm,
				float(damping_result["maximum_damping_command_nm"])
			)
			maximum_semantic_post_recontact_joint_rate_rad_s = maxf(
				maximum_semantic_post_recontact_joint_rate_rad_s,
				float(damping_result["maximum_joint_rate_rad_s"])
			)

		var early_contact_consistent_posture_active := (
			fixture_reused
			and bool(continuation_policy["early_contact_consistent_posture_recovery_enabled"])
			and semantic_release_recontact_tick >= 0
			and tick > semantic_release_recontact_tick
			and (
				tick
				<= (
					semantic_release_recontact_tick
					+ int(
						continuation_policy["early_contact_consistent_posture_recovery_duration_ticks"]
					)
				)
			)
			and not continuation_body_translation_recovery_latched
			and _all_feet_bearing(floor, limbs)
			and not (floor in torso.get_colliding_bodies())
		)
		if early_contact_consistent_posture_active:
			if continuation_early_contact_consistent_posture_first_tick < 0:
				continuation_early_contact_consistent_posture_first_tick = tick
			var early_posture_height_error_m := maxf(
				0.0,
				(
					continuation_post_translation_stabilization_target_torso_height_m
					- torso.global_position.y
					- float(continuation_policy["contact_consistent_posture_height_deadband_m"])
				)
			)
			var early_posture_endpoint_speed_m_s := minf(
				float(
					continuation_policy["early_contact_consistent_posture_maximum_endpoint_speed_m_s"]
				),
				(
					float(continuation_policy["contact_consistent_posture_position_gain_per_s"])
					* early_posture_height_error_m
				)
			)
			var early_posture_reference_rate_scale := float(
				continuation_policy["early_contact_consistent_posture_reference_rate_scale"]
			)
			early_posture_endpoint_speed_m_s *= early_posture_reference_rate_scale
			var early_posture_desired_body_angular_velocity_world_rad_s := Vector3.ZERO
			if (
				bool(
					continuation_policy["early_contact_consistent_posture_attitude_reference_enabled"]
				)
				and (
					tick - semantic_release_recontact_tick
					<= int(
						continuation_policy["early_contact_consistent_posture_attitude_reference_duration_ticks"]
					)
				)
			):
				early_posture_desired_body_angular_velocity_world_rad_s = (
					(
						Vector3.RIGHT
						* (
							(
								-float(
									continuation_policy["contact_consistent_posture_attitude_position_gain_per_s"]
								)
								* _signed_roll_rad(torso)
							)
							- (
								float(
									continuation_policy["contact_consistent_posture_attitude_velocity_damping"]
								)
								* torso.angular_velocity.dot(Vector3.RIGHT)
							)
						)
					)
					+ (
						Vector3.BACK
						* (
							(
								-float(
									continuation_policy["contact_consistent_posture_attitude_position_gain_per_s"]
								)
								* _signed_pitch_rad(torso)
							)
							- (
								float(
									continuation_policy["contact_consistent_posture_attitude_velocity_damping"]
								)
								* torso.angular_velocity.dot(Vector3.BACK)
							)
						)
					)
				)
				var early_posture_maximum_attitude_speed_rad_s := float(
					continuation_policy["contact_consistent_posture_maximum_attitude_speed_rad_s"]
				)
				if (
					early_posture_desired_body_angular_velocity_world_rad_s.length()
					> early_posture_maximum_attitude_speed_rad_s
				):
					early_posture_desired_body_angular_velocity_world_rad_s *= (
						early_posture_maximum_attitude_speed_rad_s
						/ early_posture_desired_body_angular_velocity_world_rad_s.length()
					)
				early_posture_desired_body_angular_velocity_world_rad_s *= (early_posture_reference_rate_scale)
			continuation_early_contact_consistent_posture_maximum_desired_body_angular_speed_rad_s = maxf(
				continuation_early_contact_consistent_posture_maximum_desired_body_angular_speed_rad_s,
				early_posture_desired_body_angular_velocity_world_rad_s.length()
			)
			var early_posture_reference_updated := false
			if (
				early_posture_endpoint_speed_m_s > 0.0
				or not early_posture_desired_body_angular_velocity_world_rad_s.is_zero_approx()
			):
				for early_posture_limb_value in limbs:
					var early_posture_limb: Dictionary = early_posture_limb_value
					if not _foot_shape_contacts_floor(early_posture_limb):
						continue
					var early_posture_relative_endpoint_velocity_world_m_s := (
						Vector3.DOWN * early_posture_endpoint_speed_m_s
						- early_posture_desired_body_angular_velocity_world_rad_s.cross(
							_foot_center_world(early_posture_limb) - torso.global_position
						)
					)
					var early_posture_maximum_twist_endpoint_speed_m_s := float(
						continuation_policy["contact_consistent_posture_maximum_twist_endpoint_speed_m_s"]
					)
					early_posture_maximum_twist_endpoint_speed_m_s *= (early_posture_reference_rate_scale)
					if (
						early_posture_relative_endpoint_velocity_world_m_s.length()
						> early_posture_maximum_twist_endpoint_speed_m_s
					):
						early_posture_relative_endpoint_velocity_world_m_s *= (
							early_posture_maximum_twist_endpoint_speed_m_s
							/ early_posture_relative_endpoint_velocity_world_m_s.length()
						)
					continuation_early_contact_consistent_posture_maximum_relative_endpoint_speed_m_s = maxf(
						continuation_early_contact_consistent_posture_maximum_relative_endpoint_speed_m_s,
						early_posture_relative_endpoint_velocity_world_m_s.length()
					)
					var early_posture_step := _contact_consistent_posture_reference_step(
						early_posture_limb,
						torso,
						early_posture_relative_endpoint_velocity_world_m_s,
						step_s,
						float(continuation_policy["contact_consistent_posture_dls_damping_m"]),
						(
							float(
								continuation_policy["contact_consistent_posture_maximum_joint_reference_rate_rad_s"]
							)
							* early_posture_reference_rate_scale
						),
						float(
							continuation_policy["early_contact_consistent_posture_maximum_accumulated_joint_rotation_rad"]
						),
						continuation_contact_consistent_posture_accumulated_rotation_by_joint_rad
					)
					if not bool(early_posture_step.get("ok", false)):
						fixture_complete = false
						fixture_failure_code = String(
							early_posture_step.get(
								"failure_code",
								"SPATIAL_CENTROIDAL_EARLY_CONTACT_CONSISTENT_POSTURE_FAILED"
							)
						)
						break
					var early_posture_update_count := int(
						early_posture_step["joint_reference_update_count"]
					)
					continuation_contact_consistent_posture_joint_reference_update_count += (early_posture_update_count)
					continuation_early_contact_consistent_posture_joint_reference_update_count += (early_posture_update_count)
					continuation_contact_consistent_posture_maximum_joint_reference_rate_rad_s = maxf(
						continuation_contact_consistent_posture_maximum_joint_reference_rate_rad_s,
						float(early_posture_step["maximum_joint_reference_rate_rad_s"])
					)
					continuation_early_contact_consistent_posture_maximum_joint_reference_rate_rad_s = maxf(
						continuation_early_contact_consistent_posture_maximum_joint_reference_rate_rad_s,
						float(early_posture_step["maximum_joint_reference_rate_rad_s"])
					)
					continuation_contact_consistent_posture_maximum_accumulated_joint_rotation_rad = maxf(
						continuation_contact_consistent_posture_maximum_accumulated_joint_rotation_rad,
						float(early_posture_step["maximum_accumulated_joint_rotation_rad"])
					)
					continuation_early_contact_consistent_posture_maximum_accumulated_joint_rotation_rad = maxf(
						continuation_early_contact_consistent_posture_maximum_accumulated_joint_rotation_rad,
						float(early_posture_step["maximum_accumulated_joint_rotation_rad"])
					)
					if early_posture_update_count > 0:
						early_posture_reference_updated = true
						var early_posture_limb_id := String(early_posture_limb["limb_id"])
						continuation_contact_consistent_posture_command_ticks_by_limb[early_posture_limb_id] = (
							int(
								continuation_contact_consistent_posture_command_ticks_by_limb.get(
									early_posture_limb_id, 0
								)
							)
							+ 1
						)
						continuation_early_contact_consistent_posture_command_ticks_by_limb[early_posture_limb_id] = (
							int(
								(
									continuation_early_contact_consistent_posture_command_ticks_by_limb
									. get(early_posture_limb_id, 0)
								)
							)
							+ 1
						)
				if not fixture_complete:
					break
			if early_posture_reference_updated:
				continuation_contact_consistent_posture_command_ticks += 1
				continuation_early_contact_consistent_posture_command_ticks += 1

		if (
			not continuation_post_translation_stabilization_active
			or not _all_feet_bearing(floor, limbs)
			or (floor in torso.get_colliding_bodies())
		):
			continuation_contact_consistent_posture_recovery_dwell_ticks = 0
		if (
			continuation_post_translation_stabilization_active
			and bool(continuation_policy["contact_consistent_posture_recovery_enabled"])
			and _all_feet_bearing(floor, limbs)
			and not (floor in torso.get_colliding_bodies())
		):
			var posture_translation_offset_world_m := _vector3(
				experiment["post_recontact_body_translation_offset_world_m"]
			)
			posture_translation_offset_world_m *= float(
				continuation_policy["body_translation_target_scale"]
			)
			var posture_target_torso_world_m := (
				post_recontact_body_translation_start_torso_world_m
				+ posture_translation_offset_world_m
			)
			var posture_horizontal_error_world_m := Vector3(
				posture_target_torso_world_m.x - torso.global_position.x,
				0.0,
				posture_target_torso_world_m.z - torso.global_position.z
			)
			var posture_recovery_ready := (
				(
					torso.global_position.y
					>= (
						continuation_post_translation_stabilization_target_torso_height_m
						- float(continuation_policy["contact_consistent_posture_height_deadband_m"])
					)
				)
				and (
					posture_horizontal_error_world_m.length()
					<= float(
						continuation_policy["contact_consistent_posture_latch_horizontal_error_m"]
					)
				)
				and (
					_tilt(torso)
					<= float(continuation_policy["contact_consistent_posture_latch_tilt_rad"])
				)
			)
			if (
				posture_recovery_ready
				and not continuation_contact_consistent_posture_recovery_latched
			):
				continuation_contact_consistent_posture_recovery_dwell_ticks += 1
				maximum_continuation_contact_consistent_posture_recovery_dwell_ticks = maxi(
					maximum_continuation_contact_consistent_posture_recovery_dwell_ticks,
					continuation_contact_consistent_posture_recovery_dwell_ticks
				)
			else:
				continuation_contact_consistent_posture_recovery_dwell_ticks = 0
			if (
				not continuation_contact_consistent_posture_recovery_latched
				and (
					continuation_contact_consistent_posture_recovery_dwell_ticks
					>= int(continuation_policy["contact_consistent_posture_latch_dwell_ticks"])
				)
			):
				continuation_contact_consistent_posture_recovery_latched = true
				continuation_contact_consistent_posture_recovery_latch_tick = tick
			var posture_height_error_m := maxf(
				0.0,
				(
					continuation_post_translation_stabilization_target_torso_height_m
					- torso.global_position.y
					- float(continuation_policy["contact_consistent_posture_height_deadband_m"])
				)
			)
			var posture_endpoint_speed_m_s := minf(
				float(continuation_policy["contact_consistent_posture_maximum_endpoint_speed_m_s"]),
				(
					float(continuation_policy["contact_consistent_posture_position_gain_per_s"])
					* posture_height_error_m
				)
			)
			var posture_desired_horizontal_body_velocity_world_m_s := (
				(
					float(
						continuation_policy["contact_consistent_posture_horizontal_position_gain_per_s"]
					)
					* posture_horizontal_error_world_m
				)
				- (
					float(
						continuation_policy["contact_consistent_posture_horizontal_velocity_damping"]
					)
					* Vector3(torso.linear_velocity.x, 0.0, torso.linear_velocity.z)
				)
			)
			var posture_maximum_horizontal_speed_m_s := float(
				continuation_policy["contact_consistent_posture_maximum_horizontal_speed_m_s"]
			)
			if (
				posture_desired_horizontal_body_velocity_world_m_s.length()
				> posture_maximum_horizontal_speed_m_s
			):
				posture_desired_horizontal_body_velocity_world_m_s *= (
					posture_maximum_horizontal_speed_m_s
					/ posture_desired_horizontal_body_velocity_world_m_s.length()
				)
			var posture_desired_body_velocity_world_m_s := (
				posture_desired_horizontal_body_velocity_world_m_s
				+ Vector3.UP * posture_endpoint_speed_m_s
			)
			var posture_desired_body_angular_velocity_world_rad_s := (
				(
					Vector3.RIGHT
					* (
						(
							-float(
								continuation_policy["contact_consistent_posture_attitude_position_gain_per_s"]
							)
							* _signed_roll_rad(torso)
						)
						- (
							float(
								continuation_policy["contact_consistent_posture_attitude_velocity_damping"]
							)
							* torso.angular_velocity.dot(Vector3.RIGHT)
						)
					)
				)
				+ (
					Vector3.BACK
					* (
						(
							-float(
								continuation_policy["contact_consistent_posture_attitude_position_gain_per_s"]
							)
							* _signed_pitch_rad(torso)
						)
						- (
							float(
								continuation_policy["contact_consistent_posture_attitude_velocity_damping"]
							)
							* torso.angular_velocity.dot(Vector3.BACK)
						)
					)
				)
			)
			var posture_maximum_attitude_speed_rad_s := float(
				continuation_policy["contact_consistent_posture_maximum_attitude_speed_rad_s"]
			)
			if (
				posture_desired_body_angular_velocity_world_rad_s.length()
				> posture_maximum_attitude_speed_rad_s
			):
				posture_desired_body_angular_velocity_world_rad_s *= (
					posture_maximum_attitude_speed_rad_s
					/ posture_desired_body_angular_velocity_world_rad_s.length()
				)
			var posture_reference_updated := false
			if not continuation_contact_consistent_posture_recovery_latched:
				for posture_limb_value in limbs:
					var posture_limb: Dictionary = posture_limb_value
					if not _foot_shape_contacts_floor(posture_limb):
						continue
					var posture_relative_endpoint_velocity_world_m_s := (
						-posture_desired_body_velocity_world_m_s
						- posture_desired_body_angular_velocity_world_rad_s.cross(
							_foot_center_world(posture_limb) - torso.global_position
						)
					)
					var posture_maximum_twist_endpoint_speed_m_s := float(
						continuation_policy["contact_consistent_posture_maximum_twist_endpoint_speed_m_s"]
					)
					if (
						posture_relative_endpoint_velocity_world_m_s.length()
						> posture_maximum_twist_endpoint_speed_m_s
					):
						posture_relative_endpoint_velocity_world_m_s *= (
							posture_maximum_twist_endpoint_speed_m_s
							/ posture_relative_endpoint_velocity_world_m_s.length()
						)
					var posture_step := _contact_consistent_posture_reference_step(
						posture_limb,
						torso,
						posture_relative_endpoint_velocity_world_m_s,
						step_s,
						float(continuation_policy["contact_consistent_posture_dls_damping_m"]),
						float(
							continuation_policy["contact_consistent_posture_maximum_joint_reference_rate_rad_s"]
						),
						float(
							continuation_policy["contact_consistent_posture_maximum_accumulated_joint_rotation_rad"]
						),
						continuation_contact_consistent_posture_accumulated_rotation_by_joint_rad
					)
					if not bool(posture_step.get("ok", false)):
						fixture_complete = false
						fixture_failure_code = String(
							posture_step.get(
								"failure_code",
								"SPATIAL_CENTROIDAL_CONTACT_CONSISTENT_POSTURE_FAILED"
							)
						)
						break
					var posture_update_count := int(posture_step["joint_reference_update_count"])
					if posture_update_count > 0:
						posture_reference_updated = true
						var posture_limb_id := String(posture_limb["limb_id"])
						continuation_contact_consistent_posture_command_ticks_by_limb[posture_limb_id] = (
							int(
								continuation_contact_consistent_posture_command_ticks_by_limb.get(
									posture_limb_id, 0
								)
							)
							+ 1
						)
					continuation_contact_consistent_posture_joint_reference_update_count += (posture_update_count)
					continuation_contact_consistent_posture_maximum_joint_reference_rate_rad_s = maxf(
						continuation_contact_consistent_posture_maximum_joint_reference_rate_rad_s,
						float(posture_step["maximum_joint_reference_rate_rad_s"])
					)
					continuation_contact_consistent_posture_maximum_accumulated_joint_rotation_rad = maxf(
						continuation_contact_consistent_posture_maximum_accumulated_joint_rotation_rad,
						float(posture_step["maximum_accumulated_joint_rotation_rad"])
					)
				if not fixture_complete:
					break
			if posture_reference_updated:
				continuation_contact_consistent_posture_command_ticks += 1

		if (
			continuation_post_translation_stabilization_active
			and continuation_contact_consistent_posture_recovery_latched
		):
			var posture_settle_damping := _relative_joint_rate_damping_additions(
				limbs,
				torso,
				float(continuation_policy["posture_settle_joint_damping_gain_nm_s_per_rad"]),
				float(continuation_policy["posture_settle_maximum_joint_damping_torque_nm"])
			)
			_merge_torque_additions(
				joint_torque_additions, posture_settle_damping["joint_torque_additions"]
			)
			continuation_posture_settle_joint_damping_command_ticks += 1
			maximum_continuation_posture_settle_joint_damping_torque_nm = maxf(
				maximum_continuation_posture_settle_joint_damping_torque_nm,
				float(posture_settle_damping["maximum_damping_command_nm"])
			)
			maximum_continuation_posture_settle_joint_rate_rad_s = maxf(
				maximum_continuation_posture_settle_joint_rate_rad_s,
				float(posture_settle_damping["maximum_joint_rate_rad_s"])
			)

		var swing_override_blend_fraction := 1.0
		if unload_then_lift_enabled:
			if (
				semantic_relocation_recontact_enabled
				and contact_release_latched
				and (
					semantic_release_commit_active
					or continuation_semantic_recontact_swing_task_active
				)
			):
				swing_override_blend_fraction = 1.0
			elif semantic_release_recontact_enabled and not contact_release_latched:
				swing_override_blend_fraction = 1.0
			elif contact_state_lift_enabled and not contact_release_latched:
				swing_override_blend_fraction = _smoothstep(
					clampf(
						(
							float(tick - lift_start_tick + 1)
							/ float(experiment["contact_release_blend_ticks"])
						),
						0.0,
						1.0
					)
				)
			else:
				swing_override_blend_fraction = _smoothstep(
					clampf(
						(
							float(swing_path_progress_ticks)
							/ float(experiment["swing_servo_blend_progress_ticks"])
						),
						0.0,
						1.0
					)
				)
		var command_result := _command_tick(
			tick,
			limbs,
			body_by_id,
			profile,
			experiment,
			receipt_sink,
			true,
			step_s,
			true,
			swing_torque_overrides,
			joint_torque_additions,
			swing_override_blend_fraction
		)
		if not bool(command_result.get("ok", false)):
			fixture_complete = false
			fixture_failure_code = String(
				command_result.get("failure_code", "SPATIAL_CENTROIDAL_ACTUATION_FAILED")
			)
			break
		all_receipts_complete = (
			all_receipts_complete and bool(command_result["receipts_complete"])
		)
		maximum_pairing_residual_nm = maxf(
			maximum_pairing_residual_nm, float(command_result["maximum_pairing_residual_nm"])
		)
		maximum_applied_torque_nm = maxf(
			maximum_applied_torque_nm, float(command_result["maximum_applied_torque_nm"])
		)
		structural_saturation_count += int(command_result["structural_saturation_count"])
		actuator_saturation_count += int(command_result["actuator_saturation_count"])
		active_command_count += int(command_result["active_command_count"])
		if tick == disturbance_tick and (not feasibility_gated_swing or swing_path_complete):
			torso.apply_torque_impulse(
				disturbance_axis * float(experiment["disturbance_torque_impulse_nms"])
			)
			disturbance_operation_count += 1
		await tree.physics_frame
		executed_ticks = tick + 1

		var swing_foot_position := _foot_center_world(swing_limb)
		var swing_contact := _foot_shape_contacts_floor(swing_limb)
		if (
			fixture_reused
			and semantic_release_recontact_tick >= 0
			and first_post_recontact_bearing_contact_loss_tick < 0
		):
			for contact_loss_limb_value in limbs:
				var contact_loss_limb: Dictionary = contact_loss_limb_value
				if not _foot_shape_contacts_floor(contact_loss_limb):
					first_post_recontact_bearing_contact_loss_limb_ids.append(
						String(contact_loss_limb["limb_id"])
					)
			if not first_post_recontact_bearing_contact_loss_limb_ids.is_empty():
				first_post_recontact_bearing_contact_loss_tick = tick
		if floor in torso.get_colliding_bodies():
			torso_contact_ticks += 1
		var swing_path_ready_for_clear_accounting := (
			swing_path_complete if feasibility_gated_swing else tick >= lift_complete_tick
		)
		if (
			swing_path_ready_for_clear_accounting
			and tick < disturbance_tick
			and not swing_contact
			and swing_foot_position.y >= float(experiment["minimum_clear_height_m"])
		):
			swing_clear_ticks_before_disturbance += 1
		if swing_path_ready_for_clear_accounting and not swing_contact:
			swing_contact_seen_after_clear = true
		if (
			touchdown_enabled
			and tick >= landing_start_tick
			and (not feasibility_gated_swing or disturbance_operation_count > 0)
			and first_touch_tick < 0
			and swing_contact_seen_after_clear
			and swing_contact
			and not previous_swing_contact
		):
			first_touch_tick = tick
			first_touch_target_error_m = swing_foot_position.distance_to(landing_target)
		if first_touch_tick >= 0 and tick >= first_touch_tick:
			post_touch_samples += 1
			if swing_contact:
				post_touch_contact_ticks += 1
		for limb_value in limbs:
			var support_limb: Dictionary = limb_value
			if String(support_limb["limb_id"]) == String(experiment["swing_limb_id"]):
				continue
			if _foot_shape_contacts_floor(support_limb):
				var contact_id := String(support_limb["contact_id"])
				support_contact_ticks[contact_id] = int(support_contact_ticks[contact_id]) + 1
		var all_four_contacts := _all_feet_bearing(floor, limbs)
		var recovered := (
			first_touch_tick >= 0
			and all_four_contacts
			and not (floor in torso.get_colliding_bodies())
			and (
				absf(torso.global_position.y - float(profile["torso"]["center_world_m"][1]))
				<= float(experiment["recovery_height_error_limit_m"])
			)
			and _tilt(torso) <= float(experiment["recovery_tilt_limit_rad"])
			and (
				torso.angular_velocity.length()
				<= float(experiment["recovery_full_speed_limit_rad_s"])
			)
		)
		if recovered:
			recovery_dwell_ticks += 1
			longest_recovery_dwell_ticks = maxi(longest_recovery_dwell_ticks, recovery_dwell_ticks)
		else:
			recovery_dwell_ticks = 0
		previous_swing_contact = swing_contact
		if (
			(
				touchdown_enabled
				and (
					tick
					in [
						shift_start_tick,
						shift_complete_tick,
						lift_start_tick,
						lift_complete_tick,
						disturbance_tick,
						landing_start_tick,
						landing_complete_tick,
						touchdown_deadline_tick,
						recenter_complete_tick,
						executed_tick_limit - 1,
					]
				)
			)
			or (
				touchdown_enabled
				and tick >= lift_start_tick
				and tick <= lift_complete_tick
				and (tick - lift_start_tick) % 40 == 0
			)
			or (
				fixture_reused
				and semantic_release_recontact_tick >= 0
				and tick > semantic_release_recontact_tick
				and (tick - semantic_release_recontact_tick) % 120 == 0
			)
		):
			print(
				(
					(
						"    tick=%d foot=%s contact=%s torso_h=%.6f tilt=%.6f "
						+ "roll=%.6f pitch=%.6f "
						+ "speed=%.6f com_margin=%.6f capture_margin=%.6f "
						+ "anchor=%.6f hinge=%.6f"
					)
					% [
						tick,
						swing_foot_position,
						str(swing_contact),
						torso.global_position.y,
						_tilt(torso),
						_signed_roll_rad(torso),
						_signed_pitch_rad(torso),
						torso.angular_velocity.length(),
						current_com_margin_m,
						current_capture_margin_m,
						maximum_anchor_error_m,
						maximum_hinge_axis_error_rad,
					]
				)
			)

	var support_contact_fractions: Dictionary = {}
	for contact_id in support_contact_ticks:
		support_contact_fractions[contact_id] = (
			float(support_contact_ticks[contact_id]) / float(maxi(executed_ticks, 1))
		)
	var final_bearing_contact_by_limb: Dictionary = {}
	for final_contact_limb_value in limbs:
		var final_contact_limb: Dictionary = final_contact_limb_value
		final_bearing_contact_by_limb[String(final_contact_limb["limb_id"])] = (_foot_shape_contacts_floor(
			final_contact_limb
		))
	var semantic_relocation_horizontal_displacement_m := NAN
	var semantic_relocation_horizontal_target_error_m := NAN
	var semantic_relocation_final_horizontal_displacement_world_m := Vector3(INF, 0.0, INF)
	var semantic_relocation_final_horizontal_displacement_m := NAN
	var semantic_relocation_final_horizontal_target_error_m := NAN
	var final_dynamic := DynamicSupportObserverScript.observe(
		body_by_id,
		_support_points_world(limbs, String(experiment["swing_limb_id"]), false),
		float(profile["gravity_m_s2"])
	)
	var final_center_of_mass_world_m := Vector3(INF, INF, INF)
	if bool(final_dynamic.get("ok", false)):
		final_center_of_mass_world_m = final_dynamic["center_of_mass_world_m"]
	var torso_horizontal_displacement_world_m := Vector3(
		torso.global_position.x - initial_torso_center_world_m.x,
		0.0,
		torso.global_position.z - initial_torso_center_world_m.z
	)
	var whole_system_com_horizontal_displacement_world_m := Vector3(
		final_center_of_mass_world_m.x - initial_center_of_mass.x,
		0.0,
		final_center_of_mass_world_m.z - initial_center_of_mass.z
	)
	var post_recontact_body_translation_com_displacement_world_m := Vector3(INF, 0.0, INF)
	var post_recontact_body_translation_torso_displacement_world_m := Vector3(INF, 0.0, INF)
	var post_recontact_body_translation_foot_slip_m_by_limb: Dictionary = {}
	var maximum_post_recontact_body_translation_foot_slip_m := INF
	if post_recontact_body_translation_start_tick >= 0:
		post_recontact_body_translation_com_displacement_world_m = Vector3(
			final_center_of_mass_world_m.x - post_recontact_body_translation_start_com_world_m.x,
			0.0,
			final_center_of_mass_world_m.z - post_recontact_body_translation_start_com_world_m.z
		)
		post_recontact_body_translation_torso_displacement_world_m = Vector3(
			torso.global_position.x - post_recontact_body_translation_start_torso_world_m.x,
			0.0,
			torso.global_position.z - post_recontact_body_translation_start_torso_world_m.z
		)
		maximum_post_recontact_body_translation_foot_slip_m = 0.0
		for translation_limb_value in limbs:
			var translation_limb: Dictionary = translation_limb_value
			var translation_limb_id := String(translation_limb["limb_id"])
			var start_foot: Vector3 = post_recontact_body_translation_start_foot_world_by_limb[translation_limb_id]
			var final_foot := _foot_center_world(translation_limb)
			var foot_slip_m := (
				Vector2(final_foot.x - start_foot.x, final_foot.z - start_foot.z).length()
			)
			post_recontact_body_translation_foot_slip_m_by_limb[translation_limb_id] = foot_slip_m
			maximum_post_recontact_body_translation_foot_slip_m = maxf(
				maximum_post_recontact_body_translation_foot_slip_m, foot_slip_m
			)
	if contact_release_latched and semantic_release_recontact_tick >= 0:
		var declared_relocation_offset := _vector3(
			experiment.get("semantic_relocation_clear_offset_m", [0.0, 0.0, 0.0])
		)
		semantic_relocation_horizontal_displacement_m = (
			Vector2(
				semantic_release_recontact_position_world_m.x - contact_release_position_world_m.x,
				semantic_release_recontact_position_world_m.z - contact_release_position_world_m.z
			)
			. length()
		)
		semantic_relocation_horizontal_target_error_m = (
			Vector2(
				(
					semantic_release_recontact_position_world_m.x
					- (contact_release_position_world_m.x + declared_relocation_offset.x)
				),
				(
					semantic_release_recontact_position_world_m.z
					- (contact_release_position_world_m.z + declared_relocation_offset.z)
				)
			)
			. length()
		)
		var final_swing_foot_position := _foot_center_world(swing_limb)
		semantic_relocation_final_horizontal_displacement_world_m = Vector3(
			final_swing_foot_position.x - contact_release_position_world_m.x,
			0.0,
			final_swing_foot_position.z - contact_release_position_world_m.z
		)
		semantic_relocation_final_horizontal_displacement_m = (
			semantic_relocation_final_horizontal_displacement_world_m.length()
		)
		semantic_relocation_final_horizontal_target_error_m = (
			Vector2(
				(
					final_swing_foot_position.x
					- (contact_release_position_world_m.x + declared_relocation_offset.x)
				),
				(
					final_swing_foot_position.z
					- (contact_release_position_world_m.z + declared_relocation_offset.z)
				)
			)
			. length()
		)
	var bounded_targeted_relocation_recontact_observed := (
		semantic_relocation_recontact_enabled
		and contact_release_latched
		and semantic_release_recontact_tick > contact_release_first_tick
		and (
			longest_semantic_contact_absent_dwell_ticks
			>= int(experiment["minimum_semantic_absence_dwell_ticks"])
		)
		and (
			semantic_release_recontact_tick - contact_release_first_tick
			<= maximum_semantic_recontact_latency_ticks
		)
		and (semantic_relocation_horizontal_displacement_m >= minimum_semantic_relocation_m)
		and (
			semantic_relocation_horizontal_target_error_m
			<= maximum_semantic_relocation_target_error_m
		)
		and (
			executed_ticks - semantic_release_recontact_tick
			>= int(experiment["minimum_post_recontact_observation_ticks"])
		)
		and _all_feet_bearing(floor, limbs)
		and not (floor in torso.get_colliding_bodies())
		and torso.global_position.y >= float(experiment["minimum_bounded_torso_height_m"])
		and _tilt(torso) <= float(experiment["maximum_bounded_torso_tilt_rad"])
		and maximum_anchor_error_m <= float(experiment["maximum_anchor_error_m"])
		and maximum_hinge_axis_error_rad <= float(experiment["maximum_hinge_axis_error_rad"])
		and swing_path_progress_ticks == 0
		and maximum_swing_path_progress_ticks == 0
		and disturbance_operation_count == 0
	)
	var long_horizon_targeted_relocation_recovery_observed := (
		semantic_recontact_joint_damping_enabled
		and bounded_targeted_relocation_recontact_observed
		and executed_ticks == trial_ticks
		and (
			executed_ticks - semantic_release_recontact_tick
			>= int(experiment["minimum_post_recontact_recovery_observation_ticks"])
		)
		and (
			semantic_joint_damping_command_tick_count
			>= int(experiment["minimum_semantic_joint_damping_command_ticks"])
		)
		and (
			maximum_semantic_joint_damping_command_nm
			<= active_maximum_semantic_joint_damping_torque_nm + 1.0e-9
		)
		and torso.global_position.y >= float(experiment["minimum_long_horizon_torso_height_m"])
		and _tilt(torso) <= float(experiment["maximum_long_horizon_torso_tilt_rad"])
		and (
			torso.angular_velocity.length()
			<= float(experiment["maximum_long_horizon_torso_speed_rad_s"])
		)
		and _all_feet_bearing(floor, limbs)
		and torso_contact_ticks == 0
		and maximum_anchor_error_m <= float(experiment["maximum_anchor_error_m"])
		and maximum_hinge_axis_error_rad <= float(experiment["maximum_hinge_axis_error_rad"])
		and all_receipts_complete
		and structural_saturation_count == 0
		and support_allocator_infeasible_count == 0
	)
	var bounded_post_recontact_body_translation_observed := false
	var post_recontact_body_translation_gate_receipts := {
		"long_horizon_recovery": long_horizon_targeted_relocation_recovery_observed,
		"translation_started": post_recontact_body_translation_start_tick >= 0,
		"minimum_com_translation": false,
		"minimum_torso_translation": false,
		"minimum_command_ticks": false,
		"maximum_foot_slip": false,
	}
	if post_recontact_body_translation_enabled:
		var declared_translation_offset := _vector3(
			experiment["post_recontact_body_translation_offset_world_m"]
		)
		var declared_translation_direction := (
			Vector2(declared_translation_offset.x, declared_translation_offset.z).normalized()
		)
		var measured_com_translation := Vector2(
			post_recontact_body_translation_com_displacement_world_m.x,
			post_recontact_body_translation_com_displacement_world_m.z
		)
		var measured_torso_translation := Vector2(
			post_recontact_body_translation_torso_displacement_world_m.x,
			post_recontact_body_translation_torso_displacement_world_m.z
		)
		post_recontact_body_translation_gate_receipts["minimum_com_translation"] = (
			measured_com_translation.dot(declared_translation_direction)
			>= float(experiment["minimum_post_recontact_com_translation_m"])
		)
		post_recontact_body_translation_gate_receipts["minimum_torso_translation"] = (
			measured_torso_translation.dot(declared_translation_direction)
			>= float(experiment["minimum_post_recontact_torso_translation_m"])
		)
		post_recontact_body_translation_gate_receipts["minimum_command_ticks"] = (
			post_recontact_body_translation_command_tick_count
			>= int(experiment["minimum_post_recontact_body_translation_command_ticks"])
		)
		post_recontact_body_translation_gate_receipts["maximum_foot_slip"] = (
			maximum_post_recontact_body_translation_foot_slip_m <= maximum_translation_foot_slip_m
		)
		bounded_post_recontact_body_translation_observed = (
			long_horizon_targeted_relocation_recovery_observed
			and post_recontact_body_translation_start_tick >= 0
			and (
				post_recontact_body_translation_command_tick_count
				>= int(experiment["minimum_post_recontact_body_translation_command_ticks"])
			)
			and (
				measured_com_translation.dot(declared_translation_direction)
				>= float(experiment["minimum_post_recontact_com_translation_m"])
			)
			and (
				measured_torso_translation.dot(declared_translation_direction)
				>= float(experiment["minimum_post_recontact_torso_translation_m"])
			)
			and (
				maximum_post_recontact_body_translation_foot_slip_m
				<= maximum_translation_foot_slip_m
			)
		)
	var bounded_atomic_locomotor_step_observed := false
	var atomic_step_claim_enabled := (
		bool(experiment.get("locomotor_step_claim_allowed", false))
		and (
			String(experiment.get("atomic_step_policy_id", ""))
			== "single_relocation_then_directed_body_translation_v1"
		)
	)
	var atomic_step_gate_receipts := {}
	if atomic_step_claim_enabled:
		atomic_step_gate_receipts = {
			"bounded_body_translation": bounded_post_recontact_body_translation_observed,
			"minimum_final_foot_relocation":
			semantic_relocation_final_horizontal_displacement_m >= minimum_final_foot_relocation_m,
			"maximum_final_foot_relocation":
			(
				semantic_relocation_final_horizontal_displacement_m
				<= float(experiment["maximum_atomic_final_foot_relocation_m"])
			),
			"maximum_final_foothold_target_error":
			(
				semantic_relocation_final_horizontal_target_error_m
				<= float(experiment["maximum_atomic_final_foothold_target_error_m"])
			),
			"minimum_settling_delay":
			(
				post_recontact_body_translation_start_tick - semantic_release_recontact_tick
				>= active_minimum_atomic_settling_delay_ticks
			),
			"maximum_lateral_com_translation":
			(
				absf(post_recontact_body_translation_com_displacement_world_m.z)
				<= float(experiment["maximum_atomic_lateral_translation_m"])
			),
			"maximum_lateral_torso_translation":
			(
				absf(post_recontact_body_translation_torso_displacement_world_m.z)
				<= float(experiment["maximum_atomic_lateral_translation_m"])
			),
		}
		bounded_atomic_locomotor_step_observed = (
			bounded_post_recontact_body_translation_observed
			and (
				semantic_relocation_final_horizontal_displacement_m
				>= minimum_final_foot_relocation_m
			)
			and (
				semantic_relocation_final_horizontal_displacement_m
				<= float(experiment["maximum_atomic_final_foot_relocation_m"])
			)
			and (
				semantic_relocation_final_horizontal_target_error_m
				<= float(experiment["maximum_atomic_final_foothold_target_error_m"])
			)
			and (
				post_recontact_body_translation_start_tick - semantic_release_recontact_tick
				>= active_minimum_atomic_settling_delay_ticks
			)
			and (
				absf(post_recontact_body_translation_com_displacement_world_m.z)
				<= float(experiment["maximum_atomic_lateral_translation_m"])
			)
			and (
				absf(post_recontact_body_translation_torso_displacement_world_m.z)
				<= float(experiment["maximum_atomic_lateral_translation_m"])
			)
		)
	var summary := {
		"schema_version": "canonical_spatial_centroidal_contact_candidate_summary_v1",
		"profile_id": profile["profile_id"],
		"profile_sha256": profile["profile_sha256"],
		"experiment_id": experiment["experiment_id"],
		"experiment_sha256": experiment["experiment_sha256"],
		"candidate_status": experiment["candidate_status"],
		"behavior_state": experiment["behavior_state"],
		"seed": seed,
		"touchdown_enabled": touchdown_enabled,
		"fixture_reused": fixture_reused,
		"fixture_preserved": preserve_fixture,
		"viewport_instance_id": viewport.get_instance_id(),
		"world_instance_id": world.get_instance_id(),
		"torso_instance_id": torso.get_instance_id(),
		"continuation_target_rebase_world_m": continuation_target_rebase,
		"continuation_policy": continuation_policy.duplicate(true),
		"active_minimum_semantic_release_gap_m": minimum_semantic_release_gap_m,
		"active_contact_release_target_height_m": contact_release_target_height_m,
		"active_contact_release_live_horizontal_position_task":
		contact_release_live_horizontal_position_task,
		"active_maximum_contact_release_horizontal_damping_force_n":
		maximum_contact_release_horizontal_damping_force_n,
		"active_semantic_relocation_release_velocity_preservation_ticks":
		semantic_relocation_release_velocity_preservation_ticks,
		"active_semantic_relocation_release_velocity_preservation_scale":
		semantic_relocation_release_velocity_preservation_scale,
		"active_semantic_relocation_initial_horizontal_target_velocity_m_s":
		semantic_relocation_initial_horizontal_target_velocity_m_s,
		"active_semantic_relocation_initial_horizontal_target_velocity_ticks":
		semantic_relocation_initial_horizontal_target_velocity_ticks,
		"active_maximum_semantic_relocation_task_force_n":
		active_maximum_semantic_relocation_task_force_n,
		"active_semantic_joint_rate_damping_nm_s_per_rad":
		active_semantic_joint_rate_damping_nm_s_per_rad,
		"active_maximum_semantic_joint_damping_torque_nm":
		active_maximum_semantic_joint_damping_torque_nm,
		"active_rebase_all_joint_pose_references_at_semantic_recontact":
		bool(
			continuation_policy.get("rebase_all_joint_pose_references_at_semantic_recontact", false)
		),
		"active_semantic_recontact_swing_pose_reference_blend_fraction":
		float(
			continuation_policy.get("semantic_recontact_swing_pose_reference_blend_fraction", 0.0)
		),
		"active_semantic_recontact_swing_task_hold_ticks":
		int(continuation_policy.get("semantic_recontact_swing_task_hold_ticks", 0)),
		"active_post_recontact_swing_horizontal_damping_enabled":
		bool(continuation_policy.get("post_recontact_swing_horizontal_damping_enabled", false)),
		"active_post_recontact_swing_horizontal_damping_ticks":
		int(continuation_policy.get("post_recontact_swing_horizontal_damping_ticks", 0)),
		"active_post_recontact_swing_horizontal_velocity_gain_ns_per_m":
		float(
			continuation_policy.get("post_recontact_swing_horizontal_velocity_gain_ns_per_m", 0.0)
		),
		"active_maximum_post_recontact_swing_horizontal_damping_force_n":
		float(
			continuation_policy.get("maximum_post_recontact_swing_horizontal_damping_force_n", 0.0)
		),
		"active_readmit_recontacted_limb_to_attitude_control":
		bool(continuation_policy.get("readmit_recontacted_limb_to_attitude_control", false)),
		"active_continuation_recontact_attitude_recovery_enabled":
		bool(continuation_policy.get("continuation_recontact_attitude_recovery_enabled", false)),
		"active_post_recontact_body_translation_delay_ticks":
		active_post_recontact_body_translation_delay_ticks,
		"active_minimum_atomic_settling_delay_ticks": active_minimum_atomic_settling_delay_ticks,
		"active_start_body_translation_without_recovery_dwell":
		bool(continuation_policy.get("start_body_translation_without_recovery_dwell", false)),
		"maximum_contact_release_horizontal_task_force_n":
		maximum_contact_release_horizontal_task_force_n,
		"maximum_contact_release_vertical_task_force_n":
		maximum_contact_release_vertical_task_force_n,
		"active_contact_release_vertical_force_ramp_ticks":
		contact_release_vertical_force_ramp_ticks,
		"active_contact_release_vertical_force_ramp_initial_fraction":
		contact_release_vertical_force_ramp_initial_fraction,
		"active_gait_airborne_body_advance_m": gait_airborne_body_advance_m,
		"active_gait_airborne_body_advance_ramp_ticks": gait_airborne_body_advance_ramp_ticks,
		"contact_release_vertical_force_ramp_command_ticks":
		contact_release_vertical_force_ramp_command_ticks,
		"first_contact_release_vertical_force_limit_n":
		first_contact_release_vertical_force_limit_n,
		"last_contact_release_vertical_force_limit_n": last_contact_release_vertical_force_limit_n,
		"contact_release_vertical_force_limit_at_latch_n":
		contact_release_vertical_force_limit_at_latch_n,
		"active_contact_release_reaction_compensation_enabled":
		bool(continuation_policy.get("contact_release_reaction_compensation_enabled", false)),
		"active_contact_release_reaction_compensation_endpoint_direction":
		String(
			continuation_policy.get("contact_release_reaction_compensation_endpoint_direction", "")
		),
		"contact_release_reaction_compensation_command_ticks":
		contact_release_reaction_compensation_command_ticks,
		"maximum_contact_release_reaction_compensation_total_force_n":
		maximum_contact_release_reaction_compensation_total_force_n,
		"maximum_contact_release_reaction_compensation_force_per_support_n":
		maximum_contact_release_reaction_compensation_force_per_support_n,
		"first_semantic_relocation_command_tick": first_semantic_relocation_command_tick,
		"first_semantic_relocation_target_world_m": first_semantic_relocation_target_world_m,
		"first_semantic_relocation_target_velocity_world_m_s":
		first_semantic_relocation_target_velocity_world_m_s,
		"first_semantic_relocation_task_force_world_n":
		first_semantic_relocation_task_force_world_n,
		"active_minimum_semantic_relocation_m": minimum_semantic_relocation_m,
		"active_maximum_semantic_relocation_target_error_m":
		maximum_semantic_relocation_target_error_m,
		"active_maximum_translation_foot_slip_m": maximum_translation_foot_slip_m,
		"active_minimum_final_foot_relocation_m": minimum_final_foot_relocation_m,
		"active_minimum_three_contact_handoff_margin_m": minimum_three_contact_handoff_margin_m,
		"active_minimum_lift_entry_dynamic_margin_m": minimum_lift_entry_dynamic_margin_m,
		"active_lift_start_tick": lift_start_tick,
		"active_lift_complete_tick": lift_complete_tick,
		"active_semantic_relocation_lift_ticks": semantic_relocation_lift_ticks,
		"active_semantic_relocation_lower_ticks": semantic_relocation_lower_ticks,
		"active_maximum_semantic_recontact_latency_ticks": maximum_semantic_recontact_latency_ticks,
		"active_maximum_contact_release_task_force_n": maximum_contact_release_task_force_n,
		"continuation_initial_dynamic_margin_m": continuation_initial_dynamic_margin_m,
		"continuation_support_centroid_margin_m": continuation_support_centroid_margin_m,
		"continuation_readiness_target_fraction": continuation_readiness_target_fraction,
		"continuation_readiness_target_margin_m": continuation_readiness_target_margin_m,
		"continuation_readiness_target_displacement_m":
		continuation_readiness_target_displacement_m,
		"continuation_recontact_support_recovery_active":
		continuation_recontact_support_recovery_active,
		"continuation_recontact_support_recovery_command_ticks":
		continuation_recontact_support_recovery_command_ticks,
		"continuation_recontact_vertical_support_command_ticks":
		continuation_recontact_vertical_support_command_ticks,
		"maximum_continuation_recontact_vertical_support_force_n":
		maximum_continuation_recontact_vertical_support_force_n,
		"continuation_body_translation_recovery_latched":
		continuation_body_translation_recovery_latched,
		"continuation_body_translation_recovery_latch_tick":
		continuation_body_translation_recovery_latch_tick,
		"maximum_continuation_body_translation_recovery_dwell_ticks":
		maximum_continuation_body_translation_recovery_dwell_ticks,
		"continuation_joint_pose_reference_rebase_count":
		continuation_joint_pose_reference_rebase_count,
		"continuation_joint_pose_reference_rebase_tick":
		continuation_joint_pose_reference_rebase_tick,
		"continuation_semantic_recontact_pose_rebase_count":
		continuation_semantic_recontact_pose_rebase_count,
		"continuation_semantic_recontact_pose_rebase_tick":
		continuation_semantic_recontact_pose_rebase_tick,
		"continuation_semantic_recontact_swing_pose_blend_count":
		continuation_semantic_recontact_swing_pose_blend_count,
		"continuation_semantic_recontact_swing_pose_blend_tick":
		continuation_semantic_recontact_swing_pose_blend_tick,
		"continuation_semantic_recontact_swing_pose_maximum_preblend_error_rad":
		continuation_semantic_recontact_swing_pose_maximum_preblend_error_rad,
		"continuation_semantic_recontact_swing_pose_maximum_applied_blend_rad":
		continuation_semantic_recontact_swing_pose_maximum_applied_blend_rad,
		"continuation_gait_airborne_body_advance_command_ticks":
		continuation_gait_airborne_body_advance_command_ticks,
		"continuation_gait_airborne_body_advance_first_tick":
		continuation_gait_airborne_body_advance_first_tick,
		"continuation_gait_airborne_body_advance_last_tick":
		continuation_gait_airborne_body_advance_last_tick,
		"maximum_continuation_gait_airborne_body_advance_target_m":
		maximum_continuation_gait_airborne_body_advance_target_m,
		"continuation_gait_airborne_body_advance_start_com_world_m":
		continuation_gait_airborne_body_advance_start_com_world_m,
		"continuation_gait_airborne_body_advance_last_com_world_m":
		continuation_gait_airborne_body_advance_last_com_world_m,
		"continuation_gait_airborne_body_advance_com_displacement_world_m":
		(
			(
				continuation_gait_airborne_body_advance_last_com_world_m
				- continuation_gait_airborne_body_advance_start_com_world_m
			)
			if (
				continuation_gait_airborne_body_advance_start_com_world_m.is_finite()
				and continuation_gait_airborne_body_advance_last_com_world_m.is_finite()
			)
			else Vector3(INF, INF, INF)
		),
		"continuation_semantic_recontact_swing_task_command_ticks":
		continuation_semantic_recontact_swing_task_command_ticks,
		"continuation_recontact_swing_horizontal_damping_command_ticks":
		continuation_recontact_swing_horizontal_damping_command_ticks,
		"maximum_continuation_recontact_swing_horizontal_speed_m_s":
		maximum_continuation_recontact_swing_horizontal_speed_m_s,
		"maximum_continuation_recontact_swing_horizontal_damping_force_n":
		maximum_continuation_recontact_swing_horizontal_damping_force_n,
		"continuation_four_contact_attitude_command_ticks":
		continuation_four_contact_attitude_command_ticks,
		"continuation_recontact_attitude_recovery_command_ticks":
		continuation_recontact_attitude_recovery_command_ticks,
		"maximum_continuation_recontact_roll_pitch_moment_nm":
		maximum_continuation_recontact_roll_pitch_moment_nm,
		"maximum_continuation_recontact_yaw_moment_nm":
		maximum_continuation_recontact_yaw_moment_nm,
		"maximum_continuation_recontact_yaw_endpoint_force_n":
		maximum_continuation_recontact_yaw_endpoint_force_n,
		"continuation_body_translation_three_support_command_ticks":
		continuation_body_translation_three_support_command_ticks,
		"continuation_body_translation_command_end_tick":
		(
			(
				continuation_body_translation_recovery_latch_tick
				+ int(continuation_policy.get("body_translation_command_ticks", 0))
			)
			if continuation_body_translation_recovery_latched
			else -1
		),
		"continuation_post_translation_stabilization_start_tick":
		continuation_post_translation_stabilization_start_tick,
		"continuation_post_translation_stabilization_start_torso_height_m":
		continuation_post_translation_stabilization_start_torso_height_m,
		"continuation_post_translation_stabilization_target_torso_height_m":
		continuation_post_translation_stabilization_target_torso_height_m,
		"continuation_post_translation_stabilization_command_ticks":
		continuation_post_translation_stabilization_command_ticks,
		"continuation_contact_consistent_posture_command_ticks":
		continuation_contact_consistent_posture_command_ticks,
		"continuation_contact_consistent_posture_joint_reference_update_count":
		continuation_contact_consistent_posture_joint_reference_update_count,
		"continuation_contact_consistent_posture_maximum_joint_reference_rate_rad_s":
		continuation_contact_consistent_posture_maximum_joint_reference_rate_rad_s,
		"continuation_contact_consistent_posture_maximum_accumulated_joint_rotation_rad":
		continuation_contact_consistent_posture_maximum_accumulated_joint_rotation_rad,
		"continuation_contact_consistent_posture_accumulated_rotation_by_joint_rad":
		continuation_contact_consistent_posture_accumulated_rotation_by_joint_rad.duplicate(true),
		"continuation_contact_consistent_posture_command_ticks_by_limb":
		continuation_contact_consistent_posture_command_ticks_by_limb.duplicate(true),
		"active_early_contact_consistent_posture_recovery_enabled":
		bool(continuation_policy.get("early_contact_consistent_posture_recovery_enabled", false)),
		"active_early_contact_consistent_posture_recovery_duration_ticks":
		int(continuation_policy.get("early_contact_consistent_posture_recovery_duration_ticks", 0)),
		"active_early_contact_consistent_posture_recovery_limb_scope":
		String(continuation_policy.get("early_contact_consistent_posture_recovery_limb_scope", "")),
		"active_early_contact_consistent_posture_attitude_reference_enabled":
		bool(
			continuation_policy.get(
				"early_contact_consistent_posture_attitude_reference_enabled", false
			)
		),
		"active_early_contact_consistent_posture_attitude_reference_duration_ticks":
		int(
			continuation_policy.get(
				"early_contact_consistent_posture_attitude_reference_duration_ticks", 0
			)
		),
		"active_early_contact_consistent_posture_maximum_endpoint_speed_m_s":
		float(
			continuation_policy.get(
				"early_contact_consistent_posture_maximum_endpoint_speed_m_s", 0.0
			)
		),
		"active_early_contact_consistent_posture_reference_rate_scale":
		float(
			continuation_policy.get("early_contact_consistent_posture_reference_rate_scale", 0.0)
		),
		"active_early_contact_consistent_posture_maximum_accumulated_joint_rotation_rad":
		float(
			continuation_policy.get(
				"early_contact_consistent_posture_maximum_accumulated_joint_rotation_rad", 0.0
			)
		),
		"continuation_early_contact_consistent_posture_first_tick":
		continuation_early_contact_consistent_posture_first_tick,
		"continuation_early_contact_consistent_posture_command_ticks":
		continuation_early_contact_consistent_posture_command_ticks,
		"continuation_early_contact_consistent_posture_joint_reference_update_count":
		continuation_early_contact_consistent_posture_joint_reference_update_count,
		"continuation_early_contact_consistent_posture_maximum_joint_reference_rate_rad_s":
		continuation_early_contact_consistent_posture_maximum_joint_reference_rate_rad_s,
		"continuation_early_contact_consistent_posture_maximum_accumulated_joint_rotation_rad":
		continuation_early_contact_consistent_posture_maximum_accumulated_joint_rotation_rad,
		"continuation_early_contact_consistent_posture_maximum_desired_body_angular_speed_rad_s":
		continuation_early_contact_consistent_posture_maximum_desired_body_angular_speed_rad_s,
		"continuation_early_contact_consistent_posture_maximum_relative_endpoint_speed_m_s":
		continuation_early_contact_consistent_posture_maximum_relative_endpoint_speed_m_s,
		"continuation_early_contact_consistent_posture_command_ticks_by_limb":
		continuation_early_contact_consistent_posture_command_ticks_by_limb.duplicate(true),
		"continuation_contact_consistent_posture_recovery_latched":
		continuation_contact_consistent_posture_recovery_latched,
		"continuation_contact_consistent_posture_recovery_latch_tick":
		continuation_contact_consistent_posture_recovery_latch_tick,
		"maximum_continuation_contact_consistent_posture_recovery_dwell_ticks":
		maximum_continuation_contact_consistent_posture_recovery_dwell_ticks,
		"continuation_posture_settle_joint_damping_command_ticks":
		continuation_posture_settle_joint_damping_command_ticks,
		"maximum_continuation_posture_settle_joint_damping_torque_nm":
		maximum_continuation_posture_settle_joint_damping_torque_nm,
		"maximum_continuation_posture_settle_joint_rate_rad_s":
		maximum_continuation_posture_settle_joint_rate_rad_s,
		"continuation_body_translation_target_scale":
		float(continuation_policy.get("body_translation_target_scale", 1.0)),
		"fixture_complete": fixture_complete,
		"fixture_failure_code": fixture_failure_code,
		"trial_ticks": trial_ticks,
		"executed_ticks": executed_ticks,
		"development_tick_limit_used": development_tick_limit >= 0,
		"disturbance_tick": disturbance_tick,
		"touchdown_deadline_tick": touchdown_deadline_tick,
		"disturbance_operation_count": disturbance_operation_count,
		"disturbance_is_controller_operation": false,
		"swing_limb_id": experiment["swing_limb_id"],
		"swing_contact_id": experiment["swing_contact_id"],
		"triangle_target_center_of_mass_world_m": triangle_target_center_of_mass,
		"initial_torso_center_world_m": initial_torso_center_world_m,
		"final_torso_center_world_m": torso.global_position,
		"torso_horizontal_displacement_world_m": torso_horizontal_displacement_world_m,
		"torso_horizontal_displacement_m": torso_horizontal_displacement_world_m.length(),
		"initial_whole_system_center_of_mass_world_m": initial_center_of_mass,
		"final_whole_system_center_of_mass_world_m": final_center_of_mass_world_m,
		"whole_system_com_horizontal_displacement_world_m":
		whole_system_com_horizontal_displacement_world_m,
		"whole_system_com_horizontal_displacement_m":
		whole_system_com_horizontal_displacement_world_m.length(),
		"three_contact_entry_established": three_contact_entry_established,
		"three_contact_entry_tick": three_contact_entry_tick,
		"three_contact_hold_target_world_m": three_contact_hold_target,
		"swing_clear_ticks_before_disturbance": swing_clear_ticks_before_disturbance,
		"first_touch_tick": first_touch_tick,
		"touchdown_before_deadline":
		first_touch_tick >= 0 and first_touch_tick <= touchdown_deadline_tick,
		"first_touch_target_error_m": first_touch_target_error_m,
		"post_touch_contact_fraction":
		float(post_touch_contact_ticks) / float(maxi(post_touch_samples, 1)),
		"support_contact_fractions": support_contact_fractions,
		"longest_recovery_dwell_ticks": longest_recovery_dwell_ticks,
		"recovery_dwell_observed":
		longest_recovery_dwell_ticks >= int(experiment["recovery_dwell_ticks_required"]),
		"final_swing_foot_center_world_m": _foot_center_world(swing_limb),
		"final_torso_height_m": torso.global_position.y,
		"final_height_error_m":
		absf(torso.global_position.y - float(profile["torso"]["center_world_m"][1])),
		"final_tilt_rad": _tilt(torso),
		"final_full_speed_rad_s": torso.angular_velocity.length(),
		"final_torso_angular_velocity_world_rad_s": torso.angular_velocity,
		"final_all_four_contacts": _all_feet_bearing(floor, limbs),
		"final_bearing_contact_by_limb": final_bearing_contact_by_limb,
		"first_post_recontact_bearing_contact_loss_tick":
		first_post_recontact_bearing_contact_loss_tick,
		"first_post_recontact_bearing_contact_loss_limb_ids":
		first_post_recontact_bearing_contact_loss_limb_ids.duplicate(),
		"torso_contact_ticks": torso_contact_ticks,
		"maximum_tilt_rad": maximum_tilt_rad,
		"maximum_swing_tracking_error_m": maximum_swing_tracking_error_m,
		"support_state_observations_complete": support_state_observations_complete,
		"lift_entry_com_margin_m": lift_entry_com_margin_m,
		"lift_entry_capture_margin_m": lift_entry_capture_margin_m,
		"final_com_margin_m": final_three_contact_com_margin_m,
		"final_capture_margin_m": final_three_contact_capture_margin_m,
		"minimum_three_contact_com_margin_m": minimum_three_contact_com_margin_m,
		"minimum_three_contact_capture_margin_m": minimum_three_contact_capture_margin_m,
		"minimum_three_contact_dynamic_margin_m": minimum_three_contact_dynamic_margin_m,
		"support_controller_command_count": support_controller_command_count,
		"support_allocator_used": support_allocator_used,
		"support_allocator_command_count": support_allocator_command_count,
		"support_allocator_solve_attempt_count": support_allocator_solve_attempt_count,
		"support_allocator_infeasible_count": support_allocator_infeasible_count,
		"minimum_support_allocator_authority_scale": minimum_support_allocator_authority_scale,
		"last_support_allocator_authority_scale": last_support_allocator_authority_scale,
		"maximum_support_allocator_force_residual_n": maximum_support_allocator_force_residual_n,
		"maximum_support_allocator_moment_residual_nm":
		maximum_support_allocator_moment_residual_nm,
		"minimum_support_allocator_normal_reserve_n": minimum_support_allocator_normal_reserve_n,
		"minimum_support_allocator_friction_reserve_n":
		minimum_support_allocator_friction_reserve_n,
		"last_support_allocator_infeasibility_reasons":
		last_support_allocator_infeasibility_reasons,
		"last_support_allocator_contact_commands": last_support_allocator_contact_commands,
		"predictive_feasibility_gate_used": predictive_feasibility_gate_used,
		"predictive_feasibility_check_count": predictive_feasibility_check_count,
		"predictive_feasibility_pass_count": predictive_feasibility_pass_count,
		"predictive_feasibility_pause_count": predictive_feasibility_pause_count,
		"predictive_feasibility_retreat_tick_count": predictive_feasibility_retreat_tick_count,
		"predictive_gate_retreating": predictive_gate_retreating,
		"predictive_abort_hold_tick_count": predictive_abort_hold_tick_count,
		"predictive_release_dwell_ticks": predictive_release_dwell_ticks,
		"longest_predictive_release_dwell_ticks": longest_predictive_release_dwell_ticks,
		"swing_path_progress_ticks": swing_path_progress_ticks,
		"maximum_swing_path_progress_ticks": maximum_swing_path_progress_ticks,
		"swing_unload_progress_ticks": swing_unload_progress_ticks,
		"maximum_swing_unload_progress_ticks": maximum_swing_unload_progress_ticks,
		"swing_unload_required_ticks": swing_unload_required_ticks,
		"contact_release_latched": contact_release_latched,
		"contact_release_first_tick": contact_release_first_tick,
		"contact_release_dwell_ticks": contact_release_dwell_ticks,
		"longest_contact_release_dwell_ticks": longest_contact_release_dwell_ticks,
		"post_release_contact_tick_count": post_release_contact_tick_count,
		"contact_release_gap_m": contact_release_gap_m,
		"contact_release_position_world_m": contact_release_position_world_m,
		"contact_release_foot_velocity_world_m_s": contact_release_foot_velocity_world_m_s,
		"contact_release_lower_linear_velocity_world_m_s":
		contact_release_lower_linear_velocity_world_m_s,
		"contact_release_lower_angular_velocity_world_rad_s":
		contact_release_lower_angular_velocity_world_rad_s,
		"contact_release_torso_linear_velocity_world_m_s":
		contact_release_torso_linear_velocity_world_m_s,
		"contact_release_torso_angular_velocity_world_rad_s":
		contact_release_torso_angular_velocity_world_rad_s,
		"contact_release_semantic_contact_present_at_latch":
		contact_release_semantic_contact_present_at_latch,
		"contact_release_commit_tick_count": contact_release_commit_tick_count,
		"semantic_release_commit_tick_count": semantic_release_commit_tick_count,
		"maximum_swing_geometric_gap_m": maximum_swing_geometric_gap_m,
		"semantic_contact_absent_tick_count_after_lift":
		semantic_contact_absent_tick_count_after_lift,
		"first_semantic_contact_absent_tick": first_semantic_contact_absent_tick,
		"longest_semantic_contact_absent_dwell_ticks": longest_semantic_contact_absent_dwell_ticks,
		"semantic_release_recontact_tick": semantic_release_recontact_tick,
		"semantic_release_recontact_position_world_m": semantic_release_recontact_position_world_m,
		"semantic_release_recontact_foot_velocity_world_m_s":
		semantic_release_recontact_foot_velocity_world_m_s,
		"semantic_release_recontact_lower_linear_velocity_world_m_s":
		semantic_release_recontact_lower_linear_velocity_world_m_s,
		"semantic_release_recontact_lower_angular_velocity_world_rad_s":
		semantic_release_recontact_lower_angular_velocity_world_rad_s,
		"semantic_release_recontact_torso_linear_velocity_world_m_s":
		semantic_release_recontact_torso_linear_velocity_world_m_s,
		"semantic_release_recontact_torso_angular_velocity_world_rad_s":
		semantic_release_recontact_torso_angular_velocity_world_rad_s,
		"last_semantic_airborne_tick": last_semantic_airborne_tick,
		"last_semantic_airborne_foot_velocity_world_m_s":
		last_semantic_airborne_foot_velocity_world_m_s,
		"last_semantic_airborne_lower_linear_velocity_world_m_s":
		last_semantic_airborne_lower_linear_velocity_world_m_s,
		"last_semantic_airborne_lower_angular_velocity_world_rad_s":
		last_semantic_airborne_lower_angular_velocity_world_rad_s,
		"last_semantic_airborne_torso_linear_velocity_world_m_s":
		last_semantic_airborne_torso_linear_velocity_world_m_s,
		"last_semantic_airborne_torso_angular_velocity_world_rad_s":
		last_semantic_airborne_torso_angular_velocity_world_rad_s,
		"semantic_joint_damping_first_tick": semantic_joint_damping_first_tick,
		"semantic_joint_damping_command_tick_count": semantic_joint_damping_command_tick_count,
		"maximum_semantic_joint_damping_command_nm": maximum_semantic_joint_damping_command_nm,
		"maximum_semantic_post_recontact_joint_rate_rad_s":
		maximum_semantic_post_recontact_joint_rate_rad_s,
		"semantic_joint_damping_start_torso_height_m": semantic_joint_damping_start_torso_height_m,
		"semantic_joint_damping_start_torso_tilt_rad": semantic_joint_damping_start_torso_tilt_rad,
		"semantic_joint_damping_start_torso_angular_velocity_world_rad_s":
		semantic_joint_damping_start_torso_angular_velocity_world_rad_s,
		"semantic_joint_rates_at_damping_start_rad_s": semantic_joint_rates_at_damping_start_rad_s,
		"semantic_swing_joint_rate_norm_at_damping_start_rad_s":
		semantic_swing_joint_rate_norm_at_damping_start_rad_s,
		"semantic_all_limb_damping_latched": semantic_all_limb_damping_latched,
		"post_recontact_body_translation_start_tick": post_recontact_body_translation_start_tick,
		"post_recontact_body_translation_command_tick_count":
		post_recontact_body_translation_command_tick_count,
		"post_recontact_body_translation_start_com_world_m":
		post_recontact_body_translation_start_com_world_m,
		"post_recontact_body_translation_start_torso_world_m":
		post_recontact_body_translation_start_torso_world_m,
		"post_recontact_body_translation_target_com_world_m":
		post_recontact_body_translation_target_com_world_m,
		"post_recontact_yaw_damping_command_tick_count":
		post_recontact_yaw_damping_command_tick_count,
		"maximum_post_recontact_yaw_damping_moment_nm":
		maximum_post_recontact_yaw_damping_moment_nm,
		"maximum_post_recontact_yaw_damping_endpoint_force_n":
		maximum_post_recontact_yaw_damping_endpoint_force_n,
		"post_recontact_attitude_velocity_feedback_override_tick_count":
		post_recontact_attitude_velocity_feedback_override_tick_count,
		"post_recontact_body_translation_com_displacement_world_m":
		post_recontact_body_translation_com_displacement_world_m,
		"post_recontact_body_translation_torso_displacement_world_m":
		post_recontact_body_translation_torso_displacement_world_m,
		"post_recontact_body_translation_foot_slip_m_by_limb":
		post_recontact_body_translation_foot_slip_m_by_limb,
		"maximum_post_recontact_body_translation_foot_slip_m":
		maximum_post_recontact_body_translation_foot_slip_m,
		"maximum_post_recontact_body_translation_target_error_m":
		maximum_post_recontact_body_translation_target_error_m,
		"semantic_relocation_horizontal_displacement_m":
		semantic_relocation_horizontal_displacement_m,
		"semantic_relocation_horizontal_target_error_m":
		semantic_relocation_horizontal_target_error_m,
		"semantic_relocation_final_horizontal_displacement_world_m":
		semantic_relocation_final_horizontal_displacement_world_m,
		"semantic_relocation_final_horizontal_displacement_m":
		semantic_relocation_final_horizontal_displacement_m,
		"semantic_relocation_final_horizontal_target_error_m":
		semantic_relocation_final_horizontal_target_error_m,
		"semantic_relocated_contact_creation_count":
		1 if bounded_targeted_relocation_recontact_observed else 0,
		"bounded_targeted_relocation_recontact_observed":
		bounded_targeted_relocation_recontact_observed,
		"long_horizon_targeted_relocation_recovery_observed":
		long_horizon_targeted_relocation_recovery_observed,
		"bounded_post_recontact_body_translation_observed":
		bounded_post_recontact_body_translation_observed,
		"post_recontact_body_translation_gate_receipts":
		post_recontact_body_translation_gate_receipts.duplicate(true),
		"atomic_step_gate_receipts": atomic_step_gate_receipts.duplicate(true),
		"bounded_atomic_locomotor_step_observed": bounded_atomic_locomotor_step_observed,
		"bounded_semantic_release_recontact_observed":
		(
			semantic_release_recontact_enabled
			and contact_release_latched
			and (
				longest_semantic_contact_absent_dwell_ticks
				>= int(experiment["minimum_semantic_absence_dwell_ticks"])
			)
			and contact_release_gap_m >= minimum_semantic_release_gap_m
			and contact_release_first_tick <= int(experiment["maximum_semantic_release_tick"])
			and semantic_release_recontact_tick > contact_release_first_tick
			and (
				semantic_release_recontact_tick - contact_release_first_tick
				<= maximum_semantic_recontact_latency_ticks
			)
		),
		"semantic_release_or_gap_is_load_measurement": false,
		"swing_path_required_ticks": lift_complete_tick - lift_start_tick,
		"swing_path_complete":
		(
			not feasibility_gated_swing
			or swing_path_progress_ticks >= lift_complete_tick - lift_start_tick
		),
		"minimum_predictive_normal_reserve_n": minimum_predictive_normal_reserve_n,
		"last_predictive_feasibility_passed": last_predictive_feasibility_passed,
		"last_predictive_infeasibility_reasons": last_predictive_infeasibility_reasons,
		"predictive_preflight_values_are_commands_not_measurements": true,
		"maximum_commanded_support_endpoint_force_n": maximum_commanded_support_endpoint_force_n,
		"body_count": body_by_id.size(),
		"physical_limb_count": limbs.size(),
		"actuated_dof_count": 12,
		"joint_node_count": joint_nodes.size(),
		"static_body_count": 1,
		"ordinary_preexisting_contact_count": 3,
		"new_contact_creation_count": 1 if first_touch_tick >= 0 else 0,
		"world_anchor_count": 0,
		"root_pin_count": 0,
		"rail_count": 0,
		"guide_count": 0,
		"gimbal_count": 0,
		"built_in_joint_motor_count": 0,
		"joint_spring_count": 0,
		"freeze_operation_count_after_release": 0,
		"root_controller_force_or_torque_operation_count": 0,
		"foot_pin_operation_count": 0,
		"pose_teleport_operation_count": 0,
		"active_command_count": active_command_count,
		"all_receipts_complete": all_receipts_complete,
		"maximum_pairing_residual_nm": maximum_pairing_residual_nm,
		"maximum_applied_torque_nm": maximum_applied_torque_nm,
		"actuator_saturation_count": actuator_saturation_count,
		"structural_saturation_count": structural_saturation_count,
		"maximum_anchor_error_m": maximum_anchor_error_m,
		"maximum_hinge_axis_error_rad": maximum_hinge_axis_error_rad,
		"dynamic_capture_is_articulated_guarantee": false,
		"per_contact_commands_are_measurements": false,
		"per_foot_measured_load_allocation_available": false,
		"contact_presence_is_bearing_measurement": false,
		"new_protective_contact_established": false,
		"locomotor_step_established": bounded_atomic_locomotor_step_observed,
		"free_3d_recovery_established": false,
		"step_gait_or_walking_established": false,
		"automatic_creature_guidance_allowed": false,
	}
	if preserve_fixture:
		return {
			"ok": fixture_complete,
			"summary": summary,
			"fixture":
			{
				"profile_id": profile["profile_id"],
				"seed": seed,
				"viewport": viewport,
				"world": world,
				"floor": floor,
				"torso": torso,
				"body_by_id": body_by_id,
				"limbs": limbs,
				"joint_nodes": joint_nodes,
			},
		}
	viewport.queue_free()
	await tree.physics_frame
	await tree.process_frame
	return {"ok": fixture_complete, "summary": summary}


static func _rebase_joint_pose_references(torso: RigidBody3D, limbs: Array) -> void:
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var upper: RigidBody3D = limb["upper"]
		var lower: RigidBody3D = limb["lower"]
		for state_value in limb["joint_states"]:
			var state: Dictionary = state_value
			var parent: RigidBody3D = torso if String(state["parent_id"]) == TORSO_ID else upper
			var child: RigidBody3D = (
				upper if String(state["child_id"]) == String(limb["upper_id"]) else lower
			)
			state["desired_relative_basis"] = parent.global_basis.inverse() * child.global_basis


static func _blend_limb_joint_pose_references(
	torso: RigidBody3D, limb: Dictionary, blend_fraction: float
) -> Dictionary:
	var upper: RigidBody3D = limb["upper"]
	var lower: RigidBody3D = limb["lower"]
	var joint_reference_blend_count := 0
	var maximum_preblend_error_rad := 0.0
	var maximum_applied_blend_rad := 0.0
	var bounded_blend_fraction := clampf(blend_fraction, 0.0, 1.0)
	for state_value in limb["joint_states"]:
		var state: Dictionary = state_value
		var parent: RigidBody3D = torso if String(state["parent_id"]) == TORSO_ID else upper
		var child: RigidBody3D = (
			upper if String(state["child_id"]) == String(limb["upper_id"]) else lower
		)
		var desired_relative: Basis = state["desired_relative_basis"]
		var live_relative := (parent.global_basis.inverse() * child.global_basis).orthonormalized()
		var desired_rotation := desired_relative.get_rotation_quaternion()
		var live_rotation := live_relative.get_rotation_quaternion()
		var preblend_error_rad := desired_rotation.angle_to(live_rotation)
		var blended_rotation := desired_rotation.slerp(live_rotation, bounded_blend_fraction)
		var applied_blend_rad := desired_rotation.angle_to(blended_rotation)
		state["desired_relative_basis"] = Basis(blended_rotation).orthonormalized()
		joint_reference_blend_count += 1
		maximum_preblend_error_rad = maxf(maximum_preblend_error_rad, preblend_error_rad)
		maximum_applied_blend_rad = maxf(maximum_applied_blend_rad, applied_blend_rad)
	return {
		"joint_reference_blend_count": joint_reference_blend_count,
		"maximum_preblend_error_rad": maximum_preblend_error_rad,
		"maximum_applied_blend_rad": maximum_applied_blend_rad,
	}


static func _contact_consistent_posture_reference_step(
	limb: Dictionary,
	torso: RigidBody3D,
	desired_relative_endpoint_velocity_world_m_s: Vector3,
	step_s: float,
	damping_m: float,
	maximum_joint_reference_rate_rad_s: float,
	maximum_accumulated_joint_rotation_rad: float,
	accumulated_rotation_by_joint_rad: Dictionary
) -> Dictionary:
	var upper: RigidBody3D = limb["upper"]
	var foot := _foot_center_world(limb)
	var columns: Array[Vector3] = []
	var states: Array[Dictionary] = []
	for state_value in limb["joint_states"]:
		var state: Dictionary = state_value
		var parent: RigidBody3D = torso
		if String(state["role"]) == "knee_pitch":
			parent = upper
		var axis_world := (parent.global_basis * _vector3(state["axis_parent_local"])).normalized()
		var pivot := parent.to_global(state["anchor_parent_local"])
		columns.append(axis_world.cross(foot - pivot))
		states.append(state)
	if columns.size() != 3:
		return {
			"ok": false,
			"failure_code": "SPATIAL_CENTROIDAL_POSTURE_JACOBIAN_RANK_INVALID",
		}
	var jacobian := Basis(columns[0], columns[1], columns[2])
	var damped_gram := jacobian * jacobian.transposed()
	var damping_square := damping_m * damping_m
	damped_gram.x.x += damping_square
	damped_gram.y.y += damping_square
	damped_gram.z.z += damping_square
	if absf(damped_gram.determinant()) <= 1.0e-10:
		return {
			"ok": false,
			"failure_code": "SPATIAL_CENTROIDAL_POSTURE_DLS_SINGULAR",
		}
	var desired_joint_rates := (
		jacobian.transposed()
		* (damped_gram.inverse() * desired_relative_endpoint_velocity_world_m_s)
	)
	var joint_reference_update_count := 0
	var maximum_joint_reference_rate := 0.0
	var maximum_accumulated_rotation := 0.0
	for index in range(3):
		var state: Dictionary = states[index]
		var joint_id := String(state["joint_id"])
		var desired_rate := clampf(
			desired_joint_rates[index],
			-maximum_joint_reference_rate_rad_s,
			maximum_joint_reference_rate_rad_s
		)
		var previous_accumulated_rotation := float(
			accumulated_rotation_by_joint_rad.get(joint_id, 0.0)
		)
		var next_accumulated_rotation := clampf(
			previous_accumulated_rotation + desired_rate * step_s,
			-maximum_accumulated_joint_rotation_rad,
			maximum_accumulated_joint_rotation_rad
		)
		var applied_rotation := next_accumulated_rotation - previous_accumulated_rotation
		accumulated_rotation_by_joint_rad[joint_id] = next_accumulated_rotation
		maximum_joint_reference_rate = maxf(maximum_joint_reference_rate, absf(desired_rate))
		maximum_accumulated_rotation = maxf(
			maximum_accumulated_rotation, absf(next_accumulated_rotation)
		)
		if absf(applied_rotation) <= 1.0e-12:
			continue
		var axis_parent_local := _vector3(state["axis_parent_local"]).normalized()
		var desired_relative: Basis = state["desired_relative_basis"]
		state["desired_relative_basis"] = (
			(Basis(axis_parent_local, applied_rotation) * desired_relative).orthonormalized()
		)
		joint_reference_update_count += 1
	return {
		"ok": true,
		"joint_reference_update_count": joint_reference_update_count,
		"maximum_joint_reference_rate_rad_s": maximum_joint_reference_rate,
		"maximum_accumulated_joint_rotation_rad": maximum_accumulated_rotation,
		"desired_joint_rates_rad_s": desired_joint_rates,
	}


func _release_preserved_fixture(tree: SceneTree, fixture: Dictionary) -> void:
	var viewport := fixture.get("viewport") as SubViewport
	if is_instance_valid(viewport) and not viewport.is_queued_for_deletion():
		viewport.queue_free()
		await tree.physics_frame
		await tree.process_frame


static func _axis_bounded_task_space_joint_torques(
	limb: Dictionary,
	torso: RigidBody3D,
	target: Vector3,
	target_velocity: Vector3,
	position_gain_n_per_m: float,
	velocity_gain_ns_per_m: float,
	maximum_horizontal_force_n: float,
	maximum_vertical_force_n: float
) -> Dictionary:
	var upper: RigidBody3D = limb["upper"]
	var lower: RigidBody3D = limb["lower"]
	var foot := _foot_center_world(limb)
	var foot_relative_to_lower := foot - lower.global_position
	var foot_velocity := (
		lower.linear_velocity + lower.angular_velocity.cross(foot_relative_to_lower)
	)
	var task_force := (
		position_gain_n_per_m * (target - foot)
		- velocity_gain_ns_per_m * (foot_velocity - target_velocity)
	)
	var horizontal_force := Vector2(task_force.x, task_force.z)
	if horizontal_force.length() > maximum_horizontal_force_n:
		horizontal_force *= maximum_horizontal_force_n / horizontal_force.length()
	task_force.x = horizontal_force.x
	task_force.y = clampf(task_force.y, -maximum_vertical_force_n, maximum_vertical_force_n)
	task_force.z = horizontal_force.y
	var overrides: Dictionary = {}
	for state_value in limb["joint_states"]:
		var state: Dictionary = state_value
		var parent: RigidBody3D = torso
		if String(state["role"]) == "knee_pitch":
			parent = upper
		var axis_world := (parent.global_basis * _vector3(state["axis_parent_local"])).normalized()
		var pivot := parent.to_global(state["anchor_parent_local"])
		var linear_jacobian_column := axis_world.cross(foot - pivot)
		overrides[String(state["joint_id"])] = linear_jacobian_column.dot(task_force)
	return {
		"ok": true,
		"joint_torque_overrides": overrides,
		"task_force_world_n": task_force,
	}


static func _predict_three_contact_wrench_feasibility(
	profile: Dictionary, experiment: Dictionary, tick: int, three_state: Dictionary, limbs: Array
) -> Dictionary:
	var total_weight_n := float(profile["whole_system_mass_kg"]) * float(profile["gravity_m_s2"])
	var contacts := _support_contact_records(limbs, String(experiment["swing_limb_id"]), false)
	for contact_value in contacts:
		var contact: Dictionary = contact_value
		contact["preferred_normal_force_n"] = total_weight_n / 3.0
	var center_of_mass: Vector3 = three_state["center_of_mass_world_m"]
	return (
		CentroidalSupportControllerScript
		. command(
			{
				"schema_version": CentroidalSupportControllerScript.REQUEST_SCHEMA_VERSION,
				"tick": tick,
				"whole_system_mass_kg": float(profile["whole_system_mass_kg"]),
				"gravity_m_s2": float(profile["gravity_m_s2"]),
				"center_of_mass_world_m": center_of_mass,
				"center_of_mass_velocity_world_m_s": Vector3.ZERO,
				"target_center_of_mass_world_m": center_of_mass,
				"torso_roll_rad": 0.0,
				"torso_pitch_rad": 0.0,
				"torso_roll_rate_rad_s": 0.0,
				"torso_pitch_rate_rad_s": 0.0,
				"horizontal_position_gain_n_per_m": 0.0,
				"horizontal_velocity_gain_ns_per_m": 0.0,
				"vertical_position_gain_n_per_m": 0.0,
				"vertical_velocity_gain_ns_per_m": 0.0,
				"roll_position_gain_nm_per_rad": 0.0,
				"roll_velocity_gain_nm_s_per_rad": 0.0,
				"pitch_position_gain_nm_per_rad": 0.0,
				"pitch_velocity_gain_nm_s_per_rad": 0.0,
				"maximum_horizontal_force_n": 0.0,
				"maximum_vertical_correction_n": 0.0,
				"maximum_roll_pitch_moment_nm": 0.0,
				"declared_supported_weight_fraction": 1.0,
				"friction_coefficient": float(profile["contact_friction_coefficient"]),
				"minimum_normal_force_n": 0.0,
				"maximum_normal_force_n": float(profile["contact_normal_capacity_n"]),
				"nominal_support_count": 4,
				"feasibility_tolerance": 1.0e-5,
				"support_contacts": contacts,
			}
		)
	)


static func _support_points_world(
	limbs: Array, swing_limb_id: String, include_swing: bool
) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for limb_value in _ordered_support_limbs(limbs):
		var limb: Dictionary = limb_value
		if String(limb["limb_id"]) == swing_limb_id and not include_swing:
			continue
		points.append(_foot_contact_point_world(limb))
	return points


static func _support_contact_records(
	limbs: Array, swing_limb_id: String, include_swing: bool
) -> Array:
	var contacts: Array = []
	for limb_value in _ordered_support_limbs(limbs):
		var limb: Dictionary = limb_value
		if String(limb["limb_id"]) == swing_limb_id and not include_swing:
			continue
		(
			contacts
			. append(
				{
					"contact_id": limb["contact_id"],
					"point_world_m": _foot_contact_point_world(limb),
				}
			)
		)
	return contacts


static func _ordered_support_limbs(limbs: Array) -> Array:
	var ordered: Array = []
	for limb_id in ["front_left", "rear_left", "rear_right", "front_right"]:
		for limb_value in limbs:
			var limb: Dictionary = limb_value
			if String(limb["limb_id"]) == limb_id:
				ordered.append(limb)
				break
	return ordered


static func _foot_contact_point_world(limb: Dictionary) -> Vector3:
	return _foot_center_world(limb) - Vector3.UP * float(limb["configuration"]["foot_radius_m"])


static func _triangle_incenter_world(points: Array[Vector3]) -> Vector3:
	assert(points.size() == 3)
	var opposite_a := points[1].distance_to(points[2])
	var opposite_b := points[0].distance_to(points[2])
	var opposite_c := points[0].distance_to(points[1])
	var perimeter := opposite_a + opposite_b + opposite_c
	return (opposite_a * points[0] + opposite_b * points[1] + opposite_c * points[2]) / perimeter


static func _limb_for_contact(limbs: Array, contact_id: String) -> Dictionary:
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		if String(limb["contact_id"]) == contact_id:
			return limb
	return {}


static func _joint_torques_for_endpoint_force(
	limb: Dictionary, torso: RigidBody3D, endpoint_force_world_n: Vector3
) -> Dictionary:
	var upper: RigidBody3D = limb["upper"]
	var foot := _foot_center_world(limb)
	var mapped: Dictionary = {}
	for state_value in limb["joint_states"]:
		var state: Dictionary = state_value
		var parent: RigidBody3D = torso if String(state["role"]) != "knee_pitch" else upper
		var axis_world := (parent.global_basis * _vector3(state["axis_parent_local"])).normalized()
		var pivot := parent.to_global(state["anchor_parent_local"])
		mapped[String(state["joint_id"])] = (axis_world.cross(foot - pivot).dot(
			endpoint_force_world_n
		))
	return mapped


static func _resolved_rate_swing_joint_torques(
	limb: Dictionary,
	torso: RigidBody3D,
	target_world_m: Vector3,
	target_velocity_world_m_s: Vector3,
	position_gain_per_s: float,
	damping_m: float,
	maximum_endpoint_speed_m_s: float,
	maximum_joint_speed_rad_s: float,
	joint_velocity_gain_nm_s_per_rad: float,
	maximum_joint_torque_nm: float
) -> Dictionary:
	var upper: RigidBody3D = limb["upper"]
	var foot := _foot_center_world(limb)
	var columns: Array[Vector3] = []
	var measured_rates: Array[float] = []
	var joint_ids: Array[String] = []
	for state_value in limb["joint_states"]:
		var state: Dictionary = state_value
		var parent: RigidBody3D = torso
		var child: RigidBody3D = upper
		if String(state["role"]) == "knee_pitch":
			parent = upper
			child = limb["lower"]
		var axis_world := (parent.global_basis * _vector3(state["axis_parent_local"])).normalized()
		var pivot := parent.to_global(state["anchor_parent_local"])
		columns.append(axis_world.cross(foot - pivot))
		measured_rates.append((child.angular_velocity - parent.angular_velocity).dot(axis_world))
		joint_ids.append(String(state["joint_id"]))
	if columns.size() != 3:
		return {
			"ok": false,
			"failure_code": "SPATIAL_CENTROIDAL_SWING_JACOBIAN_RANK_INVALID",
		}
	var jacobian := Basis(columns[0], columns[1], columns[2])
	var desired_relative_endpoint_velocity := (
		target_velocity_world_m_s
		- torso.linear_velocity
		+ position_gain_per_s * (target_world_m - foot)
	)
	if desired_relative_endpoint_velocity.length() > maximum_endpoint_speed_m_s:
		desired_relative_endpoint_velocity *= (
			maximum_endpoint_speed_m_s / desired_relative_endpoint_velocity.length()
		)
	var damped_gram := jacobian * jacobian.transposed()
	var damping_square := damping_m * damping_m
	damped_gram.x.x += damping_square
	damped_gram.y.y += damping_square
	damped_gram.z.z += damping_square
	if absf(damped_gram.determinant()) <= 1.0e-10:
		return {
			"ok": false,
			"failure_code": "SPATIAL_CENTROIDAL_SWING_DLS_SINGULAR",
		}
	var desired_joint_rates := (
		jacobian.transposed() * (damped_gram.inverse() * desired_relative_endpoint_velocity)
	)
	var overrides: Dictionary = {}
	for index in range(3):
		var desired_rate := clampf(
			desired_joint_rates[index], -maximum_joint_speed_rad_s, maximum_joint_speed_rad_s
		)
		overrides[joint_ids[index]] = clampf(
			joint_velocity_gain_nm_s_per_rad * (desired_rate - measured_rates[index]),
			-maximum_joint_torque_nm,
			maximum_joint_torque_nm
		)
	return {
		"ok": true,
		"joint_torque_overrides": overrides,
		"desired_relative_endpoint_velocity_world_m_s": desired_relative_endpoint_velocity,
		"desired_joint_rates_rad_s": desired_joint_rates,
	}


static func _relative_joint_rate_damping_additions(
	limbs: Array, torso: RigidBody3D, damping_gain_nm_s_per_rad: float, maximum_torque_nm: float
) -> Dictionary:
	var additions: Dictionary = {}
	var joint_rates_by_id_rad_s: Dictionary = {}
	var maximum_joint_rate_rad_s := 0.0
	var maximum_damping_command_nm := 0.0
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		var upper: RigidBody3D = limb["upper"]
		for state_value in limb["joint_states"]:
			var state: Dictionary = state_value
			var parent: RigidBody3D = torso
			var child: RigidBody3D = upper
			if String(state["role"]) == "knee_pitch":
				parent = upper
				child = limb["lower"]
			var axis_world := (
				(parent.global_basis * _vector3(state["axis_parent_local"])).normalized()
			)
			var joint_rate_rad_s := (child.angular_velocity - parent.angular_velocity).dot(
				axis_world
			)
			var damping_command_nm := clampf(
				-damping_gain_nm_s_per_rad * joint_rate_rad_s, -maximum_torque_nm, maximum_torque_nm
			)
			additions[String(state["joint_id"])] = damping_command_nm
			joint_rates_by_id_rad_s[String(state["joint_id"])] = joint_rate_rad_s
			maximum_joint_rate_rad_s = maxf(maximum_joint_rate_rad_s, absf(joint_rate_rad_s))
			maximum_damping_command_nm = maxf(maximum_damping_command_nm, absf(damping_command_nm))
	return {
		"joint_torque_additions": additions,
		"joint_rates_by_id_rad_s": joint_rates_by_id_rad_s,
		"maximum_joint_rate_rad_s": maximum_joint_rate_rad_s,
		"maximum_damping_command_nm": maximum_damping_command_nm,
	}


static func _support_body_axis_torque_additions(
	limbs: Array,
	swing_limb_id: String,
	torso: RigidBody3D,
	desired_torso_torque_nm: float,
	joint_role: String,
	world_axis: Vector3
) -> Dictionary:
	var support_axes: Array[Dictionary] = []
	var projection_square_sum := 0.0
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		if String(limb["limb_id"]) == swing_limb_id:
			continue
		for state_value in limb["joint_states"]:
			var state: Dictionary = state_value
			if String(state["role"]) != joint_role:
				continue
			var axis := (torso.global_basis * _vector3(state["axis_parent_local"])).normalized()
			var projection := axis.dot(world_axis)
			(
				support_axes
				. append(
					{
						"joint_id": String(state["joint_id"]),
						"projection": projection,
					}
				)
			)
			projection_square_sum += projection * projection
	var additions: Dictionary = {}
	if projection_square_sum <= 1.0e-9:
		return additions
	for support_axis in support_axes:
		additions[String(support_axis["joint_id"])] = (
			-desired_torso_torque_nm * float(support_axis["projection"]) / projection_square_sum
		)
	return additions


static func _ground_mediated_yaw_damping_additions(
	limbs: Array,
	floor: StaticBody3D,
	torso: RigidBody3D,
	desired_torso_yaw_moment_nm: float,
	maximum_endpoint_force_n: float
) -> Dictionary:
	var contacting_limbs: Array[Dictionary] = []
	var horizontal_radius_square_sum := 0.0
	for limb_value in limbs:
		var limb: Dictionary = limb_value
		if not _foot_shape_contacts_floor(limb):
			continue
		var horizontal_radius := _foot_center_world(limb) - torso.global_position
		horizontal_radius.y = 0.0
		(
			contacting_limbs
			. append(
				{
					"limb": limb,
					"horizontal_radius": horizontal_radius,
				}
			)
		)
		horizontal_radius_square_sum += horizontal_radius.length_squared()
	var additions: Dictionary = {}
	var maximum_observed_endpoint_force_n := 0.0
	if horizontal_radius_square_sum <= 1.0e-9 or floor == null:
		return {
			"joint_torque_additions": additions,
			"maximum_endpoint_force_n": maximum_observed_endpoint_force_n,
		}
	for contact_record in contacting_limbs:
		var radius: Vector3 = contact_record["horizontal_radius"]
		var endpoint_force := (
			Vector3.UP.cross(radius) * (-desired_torso_yaw_moment_nm / horizontal_radius_square_sum)
		)
		if endpoint_force.length() > maximum_endpoint_force_n:
			endpoint_force *= maximum_endpoint_force_n / endpoint_force.length()
		maximum_observed_endpoint_force_n = maxf(
			maximum_observed_endpoint_force_n, endpoint_force.length()
		)
		_merge_torque_additions(
			additions,
			_joint_torques_for_endpoint_force(contact_record["limb"], torso, endpoint_force)
		)
	return {
		"joint_torque_additions": additions,
		"maximum_endpoint_force_n": maximum_observed_endpoint_force_n,
	}


static func _signed_pitch_rad(torso: RigidBody3D) -> float:
	var up := torso.global_basis.y.normalized()
	return atan2(-up.x, up.y)


static func _normal_load_feedforward_additions(
	limb: Dictionary, commanded_normal_delta_n: float
) -> Dictionary:
	var contact := _vector3(limb["configuration"]["contact_point_world_m"])
	var additions: Dictionary = {}
	for state_value in limb["joint_states"]:
		var state: Dictionary = state_value
		var axis := _vector3(state["axis_world_initial"])
		var pivot := _vector3(state["pivot_world_initial"])
		additions[String(state["joint_id"])] = axis.dot(
			(contact - pivot).cross(Vector3.UP * commanded_normal_delta_n)
		)
	return additions
