extends SceneTree
# gdlint: disable=max-line-length

## BR14A.4 first existing-contact spatial disturbance-arrest experiment.
##
## Active and control worlds establish the same stance and receive the same
## roll impulse. Only post-disturbance relative-pose feedback differs.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_arrest_experiment.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_arrest_rig.gd")

const PHYSICS_HZ := 120

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.4 existing-contact roll arrest ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var experiment_result := ExperimentScript.compile(ExperimentScript.configuration())
	_check(
		bool(profile_result.get("ok", false)) and bool(experiment_result.get("ok", false)),
		"exact spatial profile and preregistered arrest experiment seal"
	)
	if not bool(profile_result.get("ok", false)) or not bool(experiment_result.get("ok", false)):
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var profile: Dictionary = profile_result["profile"]
	var experiment: Dictionary = experiment_result["experiment"]
	var rig = RigScript.new()
	var active_summaries: Array = []
	var control_summaries: Array = []
	var all_complete := true
	for seed_value in experiment["active_seed_set"]:
		var seed := int(seed_value)
		var active := await rig.run_arrest_trial(self, profile, experiment, seed, true)
		var control := await rig.run_arrest_trial(self, profile, experiment, seed, false)
		if not bool(active.get("ok", false)) or not bool(control.get("ok", false)):
			printerr("  seed=", seed, " active=", active, " control=", control)
			all_complete = false
			break
		active_summaries.append(active["summary"])
		control_summaries.append(control["summary"])
		print(
			(
				(
					"  seed=%d active_recovery=%d active_area=%.6f active_peak=%.6f "
					+ "active_final_h=%.6f control_recovery=%d control_area=%.6f "
					+ "control_final_h=%.6f"
				)
				% [
					seed,
					int(active["summary"]["recovery_completion_ticks"]),
					float(active["summary"]["post_axis_speed_area_rad"]),
					float(active["summary"]["peak_post_axis_speed_rad_s"]),
					float(active["summary"]["final_torso_height_m"]),
					int(control["summary"]["recovery_completion_ticks"]),
					float(control["summary"]["post_axis_speed_area_rad"]),
					float(control["summary"]["final_torso_height_m"]),
				]
			)
		)
	_check(all_complete, "all active/control arrest worlds return summaries")
	if not all_complete:
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var exact_fixture := true
	var matched_preconditions := true
	var exact_disturbance := true
	var active_arrest := true
	var causal_control := true
	var response_separation := true
	var existing_contacts := true
	var receipts := true
	var geometry_and_structure := true
	var nonclaims := true
	for index in range(active_summaries.size()):
		var active: Dictionary = active_summaries[index]
		var control: Dictionary = control_summaries[index]
		exact_fixture = (
			exact_fixture
			and int(active["body_count"]) == 9
			and int(active["physical_limb_count"]) == 4
			and int(active["actuated_dof_count"]) == 12
			and int(active["joint_node_count"]) == 8
			and int(active["static_body_count"]) == 1
			and int(active["world_anchor_count"]) == 0
			and int(active["root_pin_count"]) == 0
			and int(active["rail_count"]) == 0
			and int(active["guide_count"]) == 0
			and int(active["gimbal_count"]) == 0
			and int(active["built_in_joint_motor_count"]) == 0
			and int(active["joint_spring_count"]) == 0
			and int(active["freeze_operation_count_after_release"]) == 0
			and int(active["root_controller_force_or_torque_operation_count"]) == 0
			and int(active["foot_pin_operation_count"]) == 0
			and int(active["pose_teleport_operation_count"]) == 0
		)
		matched_preconditions = (
			matched_preconditions
			and bool(active["pre_disturbance_all_feet_bearing"])
			and bool(control["pre_disturbance_all_feet_bearing"])
			and (
				float(active["pre_disturbance_height_error_m"])
				<= float(experiment["pre_disturbance_height_error_limit_m"])
			)
			and (
				float(active["pre_disturbance_tilt_rad"])
				<= float(experiment["pre_disturbance_tilt_limit_rad"])
			)
			and (
				absf(
					(
						float(active["pre_disturbance_height_error_m"])
						- float(control["pre_disturbance_height_error_m"])
					)
				)
				<= 1.0e-5
			)
			and (
				absf(
					(
						float(active["pre_disturbance_tilt_rad"])
						- float(control["pre_disturbance_tilt_rad"])
					)
				)
				<= 1.0e-5
			)
		)
		exact_disturbance = (
			exact_disturbance
			and int(active["disturbance_operation_count"]) == 1
			and int(control["disturbance_operation_count"]) == 1
			and not bool(active["disturbance_is_controller_operation"])
			and (
				float(active["disturbance_torque_impulse_nms"])
				== float(experiment["disturbance_torque_impulse_nms"])
			)
			and (
				float(active["peak_post_axis_speed_rad_s"])
				>= float(experiment["minimum_observed_peak_axis_speed_rad_s"])
			)
		)
		active_arrest = (
			active_arrest
			and bool(active["recovery_dwell_observed"])
			and (
				int(active["recovery_completion_ticks"])
				<= int(experiment["maximum_recovery_ticks"])
			)
			and (
				float(active["final_height_error_m"])
				<= float(experiment["recovery_height_error_limit_m"])
			)
			and float(active["final_tilt_rad"]) <= float(experiment["recovery_tilt_limit_rad"])
			and (
				float(active["final_axis_speed_rad_s"])
				<= float(experiment["recovery_axis_speed_limit_rad_s"])
			)
			and (
				float(active["final_full_speed_rad_s"])
				<= float(experiment["recovery_full_speed_limit_rad_s"])
			)
			and int(active["torso_contact_ticks"]) == 0
		)
		causal_control = (
			causal_control
			and int(control["active_command_count"]) == 12 * int(control["trial_ticks"])
			and (
				not bool(control["recovery_dwell_observed"])
				or (
					float(control["final_height_error_m"])
					> float(experiment["recovery_height_error_limit_m"])
				)
			)
		)
		response_separation = (
			response_separation
			and (
				float(active["post_axis_speed_area_rad"])
				< float(control["post_axis_speed_area_rad"])
			)
			and float(active["final_torso_height_m"]) > float(control["final_torso_height_m"])
		)
		for fraction_value in active["post_contact_fractions"].values():
			existing_contacts = (
				existing_contacts
				and (
					float(fraction_value)
					>= float(experiment["minimum_post_disturbance_contact_fraction"])
				)
			)
		existing_contacts = (
			existing_contacts
			and int(active["ordinary_existing_contact_count"]) == 4
			and int(active["new_contact_creation_count"]) == 0
		)
		receipts = (
			receipts
			and bool(active["all_receipts_complete"])
			and bool(control["all_receipts_complete"])
			and float(active["maximum_pairing_residual_nm"]) <= 1.0e-9
			and int(active["active_command_count"]) == 12 * int(active["trial_ticks"])
		)
		geometry_and_structure = (
			geometry_and_structure
			and (
				float(active["maximum_anchor_error_m"])
				<= float(experiment["maximum_anchor_error_m"])
			)
			and (
				float(active["maximum_hinge_axis_error_rad"])
				<= float(experiment["maximum_hinge_axis_error_rad"])
			)
			and (
				float(active["maximum_applied_torque_nm"])
				<= float(experiment["maximum_structural_torque_nm"])
			)
			and int(active["structural_saturation_count"]) == 0
		)
		nonclaims = (
			nonclaims
			and _summary_boundary_valid(active)
			and not bool(active["per_contact_commands_are_measurements"])
			and not bool(active["per_foot_measured_load_allocation_available"])
		)
	_check(exact_fixture, "arrest fixture retains the exact unscaffolded nine-body boundary")
	_check(matched_preconditions, "active and control worlds enter disturbance from matched stance")
	_check(exact_disturbance, "both worlds receive one identical noncontroller roll impulse")
	_check(active_arrest, "every active seed arrests and redwells inside the preregistered window")
	_check(causal_control, "feedback-withdrawal controls do not satisfy the active arrest claim")
	_check(response_separation, "active feedback reduces roll-rate area and preserves more height")
	_check(existing_contacts, "active arrest uses only the four preexisting ordinary foot contacts")
	_check(receipts, "all active and feedforward-only joint commands remain receipt-complete")
	_check(
		geometry_and_structure,
		"joint geometry and applied torque remain inside preregistered structural envelopes"
	)
	_check(
		nonclaims, "commissioning summaries preserve all recovery, walking, and guidance nonclaims"
	)
	var forged_walk: Dictionary = (active_summaries[0] as Dictionary).duplicate(true)
	forged_walk["step_gait_or_walking_established"] = true
	_check(not _summary_boundary_valid(forged_walk), "forged walking claim fails closed")
	var forged_contact: Dictionary = (active_summaries[0] as Dictionary).duplicate(true)
	forged_contact["new_contact_creation_count"] = 1
	_check(not _summary_boundary_valid(forged_contact), "forged new-contact brace fails closed")
	Engine.physics_ticks_per_second = original_hz
	_finish()


static func _summary_boundary_valid(summary: Dictionary) -> bool:
	return (
		not bool(summary.get("existing_contact_spatial_arrest_established", true))
		and not bool(summary.get("new_contact_bracing_established", true))
		and not bool(summary.get("free_3d_recovery_established", true))
		and not bool(summary.get("step_gait_or_walking_established", true))
		and not bool(summary.get("automatic_creature_guidance_allowed", true))
		and int(summary.get("new_contact_creation_count", -1)) == 0
		and int(summary.get("world_anchor_count", -1)) == 0
		and int(summary.get("guide_count", -1)) == 0
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
