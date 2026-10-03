extends SceneTree
# gdlint: disable=max-line-length

## Development-only BR14A.5 fifth-candidate probe.
##
## The exact selected cell performs no commanded preload. Candidate 4's event
## gate remains authoritative while the vertical-first path and blended swing
## servo test whether a still-contacting relative-pose limb can enter
## free-space control without destabilizing the fixture.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const Candidate5Script := preload(
	"res://scripts/lab/mechanics/canonical_spatial_blended_lift_contact_candidate.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 120
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var candidate5_result := Candidate5Script.compile(Candidate5Script.configuration())
	if not bool(profile_result.get("ok", false)) or not bool(candidate5_result.get("ok", false)):
		printerr("seal failure profile=", profile_result, " candidate5=", candidate5_result)
		Engine.physics_ticks_per_second = original_hz
		quit(1)
		return
	var profile: Dictionary = profile_result["profile"]
	var experiment: Dictionary = candidate5_result["experiment"]
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
				"ok=%s failure=%s seed=%d executed=%d checks=%d pass=%d pause=%d "
				+ "unload=%d/%d max_unload=%d swing=%d/%d max_swing=%d clear=%d "
				+ "allocator=%d infeasible=%d reserve=%.6f "
				+ "final_h=%.6f tilt=%.6f speed=%.6f margins=%.6f/%.6f "
				+ "anchor=%.6f hinge=%.6f torque=%.6f sat=%d reasons=%s"
			)
			% [
				str(result.get("ok", false)),
				String(summary["fixture_failure_code"]),
				seed,
				int(summary["executed_ticks"]),
				int(summary["predictive_feasibility_check_count"]),
				int(summary["predictive_feasibility_pass_count"]),
				int(summary["predictive_feasibility_pause_count"]),
				int(summary["swing_unload_progress_ticks"]),
				int(summary["swing_unload_required_ticks"]),
				int(summary["maximum_swing_unload_progress_ticks"]),
				int(summary["swing_path_progress_ticks"]),
				int(summary["swing_path_required_ticks"]),
				int(summary["maximum_swing_path_progress_ticks"]),
				int(summary["swing_clear_ticks_before_disturbance"]),
				int(summary["support_allocator_command_count"]),
				int(summary["support_allocator_infeasible_count"]),
				float(summary["minimum_support_allocator_normal_reserve_n"]),
				float(summary["final_torso_height_m"]),
				float(summary["final_tilt_rad"]),
				float(summary["final_full_speed_rad_s"]),
				float(summary["final_com_margin_m"]),
				float(summary["final_capture_margin_m"]),
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
