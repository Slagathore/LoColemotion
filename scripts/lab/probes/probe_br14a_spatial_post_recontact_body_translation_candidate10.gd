extends SceneTree
# gdlint: disable=max-line-length

## BR14A.5 post-recontact body-translation development probe.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const Candidate10Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_post_recontact_body_translation_candidate.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 120
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var candidate_result := Candidate10Script.compile(Candidate10Script.configuration())
	if not bool(profile_result.get("ok", false)) or not bool(candidate_result.get("ok", false)):
		printerr("seal failure profile=", profile_result, " candidate10=", candidate_result)
		Engine.physics_ticks_per_second = original_hz
		quit(1)
		return
	var seed := 14001
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		seed = int(user_args[0])
	var rig = RigScript.new()
	var result := await rig.run_centroidal_contact_trial(
		self, profile_result["profile"], candidate_result["experiment"], seed, true
	)
	if not result.has("summary"):
		printerr("trial returned no summary seed=", seed, " result=", result)
		Engine.physics_ticks_per_second = original_hz
		quit(1)
		return
	var summary: Dictionary = result["summary"]
	print(
		(
			(
				"ok=%s failure=%s seed=%d executed=%d recontact=%d translation_start=%d "
				+ "translation_ticks=%d initial_com=%s final_com=%s net_com=%s "
				+ "phase_com=%s net_torso=%s phase_torso=%s foot_slip=%s max_slip=%.6f "
				+ "final_foot_displacement=%.6f final_foot_error=%.6f "
				+ "final_h=%.6f tilt=%.6f speed=%.6f all4=%s torso_contact=%d "
				+ "anchor=%.6f hinge=%.6f torque=%.6f structure_sat=%d "
				+ "allocator_infeasible=%d recovery=%s translation=%s"
			)
			% [
				str(result.get("ok", false)),
				String(summary["fixture_failure_code"]),
				seed,
				int(summary["executed_ticks"]),
				int(summary["semantic_release_recontact_tick"]),
				int(summary["post_recontact_body_translation_start_tick"]),
				int(summary["post_recontact_body_translation_command_tick_count"]),
				str(summary["initial_whole_system_center_of_mass_world_m"]),
				str(summary["final_whole_system_center_of_mass_world_m"]),
				str(summary["whole_system_com_horizontal_displacement_world_m"]),
				str(summary["post_recontact_body_translation_com_displacement_world_m"]),
				str(summary["torso_horizontal_displacement_world_m"]),
				str(summary["post_recontact_body_translation_torso_displacement_world_m"]),
				str(summary["post_recontact_body_translation_foot_slip_m_by_limb"]),
				float(summary["maximum_post_recontact_body_translation_foot_slip_m"]),
				float(summary["semantic_relocation_final_horizontal_displacement_m"]),
				float(summary["semantic_relocation_final_horizontal_target_error_m"]),
				float(summary["final_torso_height_m"]),
				float(summary["final_tilt_rad"]),
				float(summary["final_full_speed_rad_s"]),
				str(summary["final_all_four_contacts"]),
				int(summary["torso_contact_ticks"]),
				float(summary["maximum_anchor_error_m"]),
				float(summary["maximum_hinge_axis_error_rad"]),
				float(summary["maximum_applied_torque_nm"]),
				int(summary["structural_saturation_count"]),
				int(summary["support_allocator_infeasible_count"]),
				str(summary["long_horizon_targeted_relocation_recovery_observed"]),
				str(summary["bounded_post_recontact_body_translation_observed"]),
			]
		)
	)
	Engine.physics_ticks_per_second = original_hz
	quit(0)
