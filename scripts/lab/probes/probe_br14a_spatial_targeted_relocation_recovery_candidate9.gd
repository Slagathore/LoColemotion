extends SceneTree
# gdlint: disable=max-line-length

## BR14A.5 long-horizon targeted relocation/recontact recovery probe.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const Candidate9Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_targeted_relocation_recovery_candidate.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 120
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var candidate_result := Candidate9Script.compile(Candidate9Script.configuration())
	if not bool(profile_result.get("ok", false)) or not bool(candidate_result.get("ok", false)):
		printerr("seal failure profile=", profile_result, " candidate9=", candidate_result)
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
				"ok=%s failure=%s seed=%d executed=%d release=%d recontact=%d "
				+ "swing_rate_norm=%.6f all_limb=%s damping_ticks=%d damping_max=%.6f "
				+ "displacement=%.6f target_error=%.6f final_h=%.6f tilt=%.6f "
				+ "speed=%.6f all4=%s torso_contact=%d anchor=%.6f hinge=%.6f "
				+ "torque=%.6f structure_sat=%d allocator_infeasible=%d recovery=%s"
			)
			% [
				str(result.get("ok", false)),
				String(summary["fixture_failure_code"]),
				seed,
				int(summary["executed_ticks"]),
				int(summary["contact_release_first_tick"]),
				int(summary["semantic_release_recontact_tick"]),
				float(summary["semantic_swing_joint_rate_norm_at_damping_start_rad_s"]),
				str(summary["semantic_all_limb_damping_latched"]),
				int(summary["semantic_joint_damping_command_tick_count"]),
				float(summary["maximum_semantic_joint_damping_command_nm"]),
				float(summary["semantic_relocation_horizontal_displacement_m"]),
				float(summary["semantic_relocation_horizontal_target_error_m"]),
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
			]
		)
	)
	Engine.physics_ticks_per_second = original_hz
	quit(0)
