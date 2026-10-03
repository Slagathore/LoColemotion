extends SceneTree

## Development-only BR14A.4R readiness-cycle probe.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_readiness_recovery_experiment.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_readiness_recovery_rig.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 120
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var experiment_result := ExperimentScript.compile(ExperimentScript.configuration())
	if not bool(profile_result.get("ok", false)) or not bool(experiment_result.get("ok", false)):
		printerr("seal failure profile=", profile_result, " experiment=", experiment_result)
		Engine.physics_ticks_per_second = original_hz
		quit(1)
		return
	var rig = RigScript.new()
	var profile: Dictionary = profile_result["profile"]
	var experiment: Dictionary = experiment_result["experiment"]
	var run_all := "--all" in OS.get_cmdline_user_args()
	var seed_values: Array = (
		experiment["active_seed_set"]
		if run_all
		else [int((experiment["active_seed_set"] as Array)[0])]
	)
	var enabled_values: Array = (
		[true, false] if run_all else [not ("--control" in OS.get_cmdline_user_args())]
	)
	for seed_value in seed_values:
		var seed := int(seed_value)
		for enabled in enabled_values:
			var result := await rig.run_readiness_recovery_trial(
				self, profile, experiment, seed, enabled
			)
			if not bool(result.get("ok", false)):
				printerr("trial failure seed=", seed, " enabled=", enabled, " result=", result)
				Engine.physics_ticks_per_second = original_hz
				quit(1)
				return
			var summary: Dictionary = result["summary"]
			print(
				(
					(
						"seed=%d active=%s first=%s loss=%s second=%s "
						+ "dwell=%d/%d/%d margins=%.6f/%.6f/%.6f "
						+ "final=%.6f/%.6f h=%.6f tilt=%.6f speed=%.6f/%.6f "
						+ "anchor=%.6f hinge=%.6f torque=%.6f sat=%d"
					)
					% [
						seed,
						str(enabled),
						str(summary["first_readiness_acquired"]),
						str(summary["readiness_loss_established"]),
						str(summary["second_readiness_reacquired"]),
						int(summary["longest_first_ready_dwell_ticks"]),
						int(summary["longest_readiness_loss_dwell_ticks"]),
						int(summary["longest_second_ready_dwell_ticks"]),
						float(summary["minimum_first_ready_margin_m"]),
						float(summary["maximum_loss_margin_m"]),
						float(summary["minimum_second_ready_margin_m"]),
						float(summary["final_com_margin_m"]),
						float(summary["final_capture_margin_m"]),
						float(summary["final_height_error_m"]),
						float(summary["final_tilt_rad"]),
						float(summary["final_linear_speed_m_s"]),
						float(summary["final_angular_speed_rad_s"]),
						float(summary["maximum_anchor_error_m"]),
						float(summary["maximum_hinge_axis_error_rad"]),
						float(summary["maximum_applied_torque_nm"]),
						int(summary["structural_saturation_count"]),
					]
				)
			)
	Engine.physics_ticks_per_second = original_hz
	quit(0)
