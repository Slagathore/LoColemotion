extends SceneTree
# gdlint: disable=max-line-length

## Development-only BR14A.5 contact-state lift probe.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const Candidate6Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_contact_state_lift_candidate.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 120
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var candidate_result := Candidate6Script.compile(Candidate6Script.configuration())
	if not bool(profile_result.get("ok", false)) or not bool(candidate_result.get("ok", false)):
		printerr("seal failure profile=", profile_result, " candidate6=", candidate_result)
		Engine.physics_ticks_per_second = original_hz
		quit(1)
		return
	var profile: Dictionary = profile_result["profile"]
	var experiment: Dictionary = candidate_result["experiment"]
	var seed := int(experiment["rejection_witness_seed"])
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
				"ok=%s failure=%s seed=%d executed=%d release=%s first=%d dwell=%d "
				+ "gap=%.6f manifold_at_latch=%s commit=%d recontact=%d "
				+ "semantic_absent=%d first_absent=%d max_gap=%.6f "
				+ "pass=%d pause=%d path=%d/%d max_path=%d clear=%d touch=%d "
				+ "disturbance=%d final_h=%.6f tilt=%.6f speed=%.6f "
				+ "anchor=%.6f hinge=%.6f torque=%.6f sat=%d reasons=%s"
			)
			% [
				str(result.get("ok", false)),
				String(summary["fixture_failure_code"]),
				seed,
				int(summary["executed_ticks"]),
				str(summary["contact_release_latched"]),
				int(summary["contact_release_first_tick"]),
				int(summary["longest_contact_release_dwell_ticks"]),
				float(summary["contact_release_gap_m"]),
				str(summary["contact_release_semantic_contact_present_at_latch"]),
				int(summary["contact_release_commit_tick_count"]),
				int(summary["post_release_contact_tick_count"]),
				int(summary["semantic_contact_absent_tick_count_after_lift"]),
				int(summary["first_semantic_contact_absent_tick"]),
				float(summary["maximum_swing_geometric_gap_m"]),
				int(summary["predictive_feasibility_pass_count"]),
				int(summary["predictive_feasibility_pause_count"]),
				int(summary["swing_path_progress_ticks"]),
				int(summary["swing_path_required_ticks"]),
				int(summary["maximum_swing_path_progress_ticks"]),
				int(summary["swing_clear_ticks_before_disturbance"]),
				int(summary["first_touch_tick"]),
				int(summary["disturbance_operation_count"]),
				float(summary["final_torso_height_m"]),
				float(summary["final_tilt_rad"]),
				float(summary["final_full_speed_rad_s"]),
				float(summary["maximum_anchor_error_m"]),
				float(summary["maximum_hinge_axis_error_rad"]),
				float(summary["maximum_applied_torque_nm"]),
				int(summary["structural_saturation_count"]),
				str(summary["last_predictive_infeasibility_reasons"]),
			]
		)
	)
	Engine.physics_ticks_per_second = original_hz
	quit(0)
