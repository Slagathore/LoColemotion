extends SceneTree
# gdlint: disable=max-line-length

## Development-only candidate-3 physical probe. This remains outside tests/
## and cannot commission BR14A.5.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_wrench_contact_candidate.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 120
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var experiment_result := ExperimentScript.compile(ExperimentScript.configuration())
	if not bool(profile_result.get("ok", false)) or not bool(experiment_result.get("ok", false)):
		printerr("profile=", profile_result, " experiment=", experiment_result)
		Engine.physics_ticks_per_second = original_hz
		quit(1)
		return
	var profile: Dictionary = profile_result["profile"]
	var experiment: Dictionary = experiment_result["experiment"]
	var seed := int((experiment["active_seed_set"] as Array)[0])
	var rig = RigScript.new()
	var result := await rig.run_centroidal_contact_trial(self, profile, experiment, seed, true, 980)
	print("=== BR14A spatial-wrench contact development probe ===")
	print("  ok=", result.get("ok", false))
	if result.has("summary"):
		var summary: Dictionary = result["summary"]
		for field in [
			"fixture_failure_code",
			"executed_ticks",
			"swing_clear_ticks_before_disturbance",
			"first_touch_tick",
			"first_touch_target_error_m",
			"post_touch_contact_fraction",
			"longest_recovery_dwell_ticks",
			"final_torso_height_m",
			"final_tilt_rad",
			"final_full_speed_rad_s",
			"lift_entry_com_margin_m",
			"lift_entry_capture_margin_m",
			"minimum_three_contact_com_margin_m",
			"minimum_three_contact_capture_margin_m",
			"support_allocator_used",
			"support_allocator_command_count",
			"support_allocator_solve_attempt_count",
			"support_allocator_infeasible_count",
			"minimum_support_allocator_authority_scale",
			"last_support_allocator_authority_scale",
			"maximum_support_allocator_force_residual_n",
			"maximum_support_allocator_moment_residual_nm",
			"minimum_support_allocator_normal_reserve_n",
			"minimum_support_allocator_friction_reserve_n",
			"last_support_allocator_infeasibility_reasons",
			"last_support_allocator_contact_commands",
			"maximum_applied_torque_nm",
			"actuator_saturation_count",
			"structural_saturation_count",
			"maximum_anchor_error_m",
			"maximum_hinge_axis_error_rad",
		]:
			print("  ", field, "=", summary.get(field))
		print("  support_contact_fractions=", summary.get("support_contact_fractions"))
	Engine.physics_ticks_per_second = original_hz
	quit(0 if bool(result.get("ok", false)) else 1)
