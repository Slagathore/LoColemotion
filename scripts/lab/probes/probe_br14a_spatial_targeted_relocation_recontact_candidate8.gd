extends SceneTree
# gdlint: disable=max-line-length

## BR14A.5 bounded targeted relocation/recontact prerequisite probe.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const Candidate8Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_targeted_relocation_recontact_candidate.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 120
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var candidate_result := Candidate8Script.compile(Candidate8Script.configuration())
	if not bool(profile_result.get("ok", false)) or not bool(candidate_result.get("ok", false)):
		printerr("seal failure profile=", profile_result, " candidate8=", candidate_result)
		Engine.physics_ticks_per_second = original_hz
		quit(1)
		return
	var profile: Dictionary = profile_result["profile"]
	var experiment: Dictionary = candidate_result["experiment"]
	var seed := 14003
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		seed = int(user_args[0])
	var rig = RigScript.new()
	var result := await rig.run_centroidal_contact_trial(self, profile, experiment, seed, true)
	if not result.has("summary"):
		printerr("trial returned no summary seed=", seed, " result=", result)
		Engine.physics_ticks_per_second = original_hz
		quit(1)
		return
	var summary: Dictionary = result["summary"]
	print(
		(
			(
				"ok=%s failure=%s seed=%d executed=%d release=%d gap=%.6f "
				+ "absent=%d recontact=%d displacement=%.6f target_error=%.6f "
				+ "post_observation=%d final_h=%.6f tilt=%.6f speed=%.6f "
				+ "all4=%s torso_contact=%d anchor=%.6f hinge=%.6f torque=%.6f "
				+ "allocator_infeasible=%d"
			)
			% [
				str(result.get("ok", false)),
				String(summary["fixture_failure_code"]),
				seed,
				int(summary["executed_ticks"]),
				int(summary["contact_release_first_tick"]),
				float(summary["contact_release_gap_m"]),
				int(summary["longest_semantic_contact_absent_dwell_ticks"]),
				int(summary["semantic_release_recontact_tick"]),
				float(summary["semantic_relocation_horizontal_displacement_m"]),
				float(summary["semantic_relocation_horizontal_target_error_m"]),
				int(summary["executed_ticks"]) - int(summary["semantic_release_recontact_tick"]),
				float(summary["final_torso_height_m"]),
				float(summary["final_tilt_rad"]),
				float(summary["final_full_speed_rad_s"]),
				str(summary["final_all_four_contacts"]),
				int(summary["torso_contact_ticks"]),
				float(summary["maximum_anchor_error_m"]),
				float(summary["maximum_hinge_axis_error_rad"]),
				float(summary["maximum_applied_torque_nm"]),
				int(summary["support_allocator_infeasible_count"]),
			]
		)
	)
	Engine.physics_ticks_per_second = original_hz
	quit(0)
