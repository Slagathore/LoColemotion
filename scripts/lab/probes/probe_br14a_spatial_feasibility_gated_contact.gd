extends SceneTree
# gdlint: disable=max-line-length

## Development-only candidate-4 physical probe. This remains outside tests/
## and cannot commission BR14A.5.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_feasibility_gated_contact_candidate.gd"
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
	var result := await rig.run_centroidal_contact_trial(self, profile, experiment, seed, true)
	print("=== BR14A feasibility-gated contact development probe ===")
	print("  ok=", result.get("ok", false))
	if result.has("summary"):
		var summary: Dictionary = result["summary"]
		for field in [
			"fixture_failure_code",
			"executed_ticks",
			"predictive_feasibility_gate_used",
			"predictive_feasibility_check_count",
			"predictive_feasibility_pass_count",
			"predictive_feasibility_pause_count",
			"predictive_feasibility_retreat_tick_count",
			"predictive_gate_retreating",
			"predictive_abort_hold_tick_count",
			"predictive_release_dwell_ticks",
			"longest_predictive_release_dwell_ticks",
			"swing_path_progress_ticks",
			"swing_path_required_ticks",
			"swing_path_complete",
			"minimum_predictive_normal_reserve_n",
			"last_predictive_feasibility_passed",
			"last_predictive_infeasibility_reasons",
			"swing_clear_ticks_before_disturbance",
			"disturbance_operation_count",
			"first_touch_tick",
			"minimum_three_contact_com_margin_m",
			"minimum_three_contact_capture_margin_m",
			"support_allocator_used",
			"support_allocator_command_count",
			"support_allocator_infeasible_count",
			"minimum_support_allocator_authority_scale",
			"minimum_support_allocator_normal_reserve_n",
			"last_support_allocator_infeasibility_reasons",
			"maximum_applied_torque_nm",
			"actuator_saturation_count",
			"structural_saturation_count",
			"maximum_anchor_error_m",
			"maximum_hinge_axis_error_rad",
			"final_torso_height_m",
			"final_tilt_rad",
			"final_full_speed_rad_s",
		]:
			print("  ", field, "=", summary.get(field))
	Engine.physics_ticks_per_second = original_hz
	quit(0 if bool(result.get("ok", false)) else 1)
