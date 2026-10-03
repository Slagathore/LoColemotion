extends SceneTree
# gdlint: disable=max-line-length

## BR14A.5 all-seed bounded targeted relocation/recontact prerequisite.
##
## This is narrower than a locomotor step. The foot is intentionally moved to
## a new ordinary floor point, but the legacy step path and disturbance remain
## suppressed and long-horizon recovery is not claimed.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_targeted_relocation_recontact_candidate.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")

const PHYSICS_HZ := 120
const EXPECTED_BY_SEED := {
	14001:
	{
		"release": 725,
		"gap": 0.030413,
		"recontact": 733,
		"displacement": 0.021375,
		"target_error": 0.001594,
	},
	14002:
	{
		"release": 724,
		"gap": 0.029404,
		"recontact": 732,
		"displacement": 0.026687,
		"target_error": 0.006687,
	},
	14003:
	{
		"release": 725,
		"gap": 0.032196,
		"recontact": 733,
		"displacement": 0.021483,
		"target_error": 0.002285,
	},
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.5 bounded targeted relocation/recontact prerequisite ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var experiment_result := ExperimentScript.compile(ExperimentScript.configuration())
	_check(
		bool(profile_result.get("ok", false)) and bool(experiment_result.get("ok", false)),
		"exact profile and eighth-candidate prerequisite contract seal"
	)
	if not bool(profile_result.get("ok", false)) or not bool(experiment_result.get("ok", false)):
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var profile: Dictionary = profile_result["profile"]
	var experiment: Dictionary = experiment_result["experiment"]
	var summaries: Array[Dictionary] = []
	var worlds_complete := true
	for seed_value in experiment["active_seed_set"]:
		var seed := int(seed_value)
		var rig = RigScript.new()
		var result := await rig.run_centroidal_contact_trial(self, profile, experiment, seed, true)
		worlds_complete = (
			worlds_complete and bool(result.get("ok", false)) and result.has("summary")
		)
		if not result.has("summary"):
			printerr("  seed=", seed, " result=", result)
			continue
		var summary: Dictionary = result["summary"]
		summaries.append(summary)
		print(
			(
				(
					"  seed=%d release=%d gap=%.6f absent=%d recontact=%d "
					+ "displacement=%.6f target_error=%.6f final_h=%.6f "
					+ "tilt=%.6f speed=%.6f anchor=%.6f hinge=%.6f torque=%.6f"
				)
				% [
					seed,
					int(summary["contact_release_first_tick"]),
					float(summary["contact_release_gap_m"]),
					int(summary["longest_semantic_contact_absent_dwell_ticks"]),
					int(summary["semantic_release_recontact_tick"]),
					float(summary["semantic_relocation_horizontal_displacement_m"]),
					float(summary["semantic_relocation_horizontal_target_error_m"]),
					float(summary["final_torso_height_m"]),
					float(summary["final_tilt_rad"]),
					float(summary["final_full_speed_rad_s"]),
					float(summary["maximum_anchor_error_m"]),
					float(summary["maximum_hinge_axis_error_rad"]),
					float(summary["maximum_applied_torque_nm"]),
				]
			)
		)
	_check(
		worlds_complete and summaries.size() == (experiment["active_seed_set"] as Array).size(),
		"all three fresh physical worlds return complete summaries"
	)
	if summaries.size() != (experiment["active_seed_set"] as Array).size():
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	_check(_all_complete(summaries, experiment), "every seed reaches the exact 781-tick horizon")
	_check(_all_exact_fixture(summaries), "all seeds retain the unscaffolded nine-body boundary")
	_check(
		_all_handoff_ready(summaries, experiment),
		"all seeds establish the measured lift-entry handoff"
	)
	_check(
		_all_semantic_release(summaries, experiment),
		"all seeds sustain the required engine-observed contact absence"
	)
	_check(
		_all_exact_relocation_witnesses(summaries),
		"release, recontact, displacement, and target-error witnesses match the pinned table"
	)
	_check(
		_all_targeted_recontact(summaries, experiment),
		"every seed creates the bounded targeted ordinary recontact"
	)
	_check(
		_all_post_recontact_observation(summaries, experiment),
		"every seed retains the required post-recontact observation window"
	)
	_check(
		_all_contacts_and_noncollapse(summaries, experiment),
		"all seeds end with four ordinary contacts and bounded noncollapse"
	)
	_check(
		_all_no_legacy_step_or_disturbance(summaries),
		"legacy step progress, disturbance, and protective-contact accounting remain suppressed"
	)
	_check(
		_all_semantic_contact_accounting(summaries),
		"the relocated semantic contact is counted separately from the legacy touchdown path"
	)
	_check(_all_geometry_intact(summaries, experiment), "all joint geometry remains inside bounds")
	_check(
		_all_receipts_complete(summaries), "every actuator command is paired and receipt-complete"
	)
	_check(
		_all_structure_intact(summaries, experiment), "no seed crosses the structural torque guard"
	)
	_check(
		_all_allocator_commands_feasible(summaries),
		"every physically applied three-support allocator command is feasible"
	)
	_check(
		_all_measurement_boundaries_intact(summaries),
		"contact topology, displacement, and target error remain non-load observations"
	)
	_check(
		(
			(
				String(experiment["candidate_result"])
				== "positive_bounded_targeted_relocation_recontact_prerequisite"
			)
			and bool(experiment["full_seed_success_required"])
			and (experiment["active_seed_set"] as Array) == [14001, 14002, 14003]
		),
		"positive prerequisite is pinned to the complete preregistered seed set"
	)
	_check(
		_all_summary_boundaries_valid(summaries, experiment),
		"every summary retains the bounded claim and broader nonclaims"
	)
	var forged_target := summaries[0].duplicate(true)
	forged_target["semantic_relocation_horizontal_target_error_m"] = (
		float(experiment["maximum_semantic_relocation_horizontal_target_error_m"]) + 0.001
	)
	_check(
		not _summary_boundary_valid(forged_target, experiment),
		"forged out-of-tolerance targeted contact fails closed"
	)
	var forged_recovery := summaries[0].duplicate(true)
	forged_recovery["free_3d_recovery_established"] = true
	_check(
		not _summary_boundary_valid(forged_recovery, experiment),
		"forged long-horizon recovery fails closed"
	)
	var forged_step := summaries[0].duplicate(true)
	forged_step["locomotor_step_established"] = true
	_check(
		not _summary_boundary_valid(forged_step, experiment),
		"forged complete locomotor step fails closed"
	)
	var forged_walk := summaries[0].duplicate(true)
	forged_walk["step_gait_or_walking_established"] = true
	_check(
		not _summary_boundary_valid(forged_walk, experiment), "forged walking claim fails closed"
	)
	Engine.physics_ticks_per_second = original_hz
	_finish()


static func _all_complete(summaries: Array[Dictionary], experiment: Dictionary) -> bool:
	for summary in summaries:
		if (
			not bool(summary["fixture_complete"])
			or not String(summary["fixture_failure_code"]).is_empty()
			or int(summary["executed_ticks"]) != int(experiment["trial_ticks"])
		):
			return false
	return true


static func _all_exact_fixture(summaries: Array[Dictionary]) -> bool:
	for summary in summaries:
		if not _exact_fixture(summary):
			return false
	return true


static func _all_handoff_ready(summaries: Array[Dictionary], experiment: Dictionary) -> bool:
	for summary in summaries:
		if (
			not bool(summary["three_contact_entry_established"])
			or (
				float(summary["lift_entry_com_margin_m"])
				< float(experiment["minimum_lift_entry_dynamic_margin_m"])
			)
			or (
				float(summary["lift_entry_capture_margin_m"])
				< float(experiment["minimum_lift_entry_dynamic_margin_m"])
			)
		):
			return false
	return true


static func _all_semantic_release(summaries: Array[Dictionary], experiment: Dictionary) -> bool:
	for summary in summaries:
		if (
			not bool(summary["contact_release_latched"])
			or bool(summary["contact_release_semantic_contact_present_at_latch"])
			or (
				int(summary["longest_semantic_contact_absent_dwell_ticks"])
				< int(experiment["minimum_semantic_absence_dwell_ticks"])
			)
			or (
				float(summary["contact_release_gap_m"])
				< float(experiment["minimum_semantic_release_gap_m"])
			)
		):
			return false
	return true


static func _all_exact_relocation_witnesses(summaries: Array[Dictionary]) -> bool:
	for summary in summaries:
		var expected: Dictionary = EXPECTED_BY_SEED[int(summary["seed"])]
		if (
			int(summary["contact_release_first_tick"]) != int(expected["release"])
			or absf(float(summary["contact_release_gap_m"]) - float(expected["gap"])) > 1.0e-6
			or int(summary["semantic_release_recontact_tick"]) != int(expected["recontact"])
			or (
				absf(
					(
						float(summary["semantic_relocation_horizontal_displacement_m"])
						- float(expected["displacement"])
					)
				)
				> 1.0e-6
			)
			or (
				absf(
					(
						float(summary["semantic_relocation_horizontal_target_error_m"])
						- float(expected["target_error"])
					)
				)
				> 1.0e-6
			)
		):
			return false
	return true


static func _all_targeted_recontact(summaries: Array[Dictionary], experiment: Dictionary) -> bool:
	for summary in summaries:
		if (
			not bool(summary["bounded_targeted_relocation_recontact_observed"])
			or (
				float(summary["semantic_relocation_horizontal_displacement_m"])
				< float(experiment["minimum_semantic_relocation_horizontal_displacement_m"])
			)
			or (
				float(summary["semantic_relocation_horizontal_target_error_m"])
				> float(experiment["maximum_semantic_relocation_horizontal_target_error_m"])
			)
		):
			return false
	return true


static func _all_post_recontact_observation(
	summaries: Array[Dictionary], experiment: Dictionary
) -> bool:
	for summary in summaries:
		if (
			int(summary["executed_ticks"]) - int(summary["semantic_release_recontact_tick"])
			< int(experiment["minimum_post_recontact_observation_ticks"])
		):
			return false
	return true


static func _all_contacts_and_noncollapse(
	summaries: Array[Dictionary], experiment: Dictionary
) -> bool:
	for summary in summaries:
		if (
			not bool(summary["final_all_four_contacts"])
			or int(summary["torso_contact_ticks"]) != 0
			or (
				float(summary["final_torso_height_m"])
				< float(experiment["minimum_bounded_torso_height_m"])
			)
			or (
				float(summary["final_tilt_rad"])
				> float(experiment["maximum_bounded_torso_tilt_rad"])
			)
		):
			return false
	return true


static func _all_no_legacy_step_or_disturbance(summaries: Array[Dictionary]) -> bool:
	for summary in summaries:
		if (
			int(summary["swing_path_progress_ticks"]) != 0
			or int(summary["maximum_swing_path_progress_ticks"]) != 0
			or int(summary["disturbance_operation_count"]) != 0
			or int(summary["first_touch_tick"]) >= 0
			or int(summary["new_contact_creation_count"]) != 0
		):
			return false
	return true


static func _all_semantic_contact_accounting(summaries: Array[Dictionary]) -> bool:
	for summary in summaries:
		if int(summary["semantic_relocated_contact_creation_count"]) != 1:
			return false
	return true


static func _all_geometry_intact(summaries: Array[Dictionary], experiment: Dictionary) -> bool:
	for summary in summaries:
		if (
			float(summary["maximum_anchor_error_m"]) > float(experiment["maximum_anchor_error_m"])
			or (
				float(summary["maximum_hinge_axis_error_rad"])
				> float(experiment["maximum_hinge_axis_error_rad"])
			)
		):
			return false
	return true


static func _all_receipts_complete(summaries: Array[Dictionary]) -> bool:
	for summary in summaries:
		if (
			not bool(summary["all_receipts_complete"])
			or float(summary["maximum_pairing_residual_nm"]) > 1.0e-9
			or int(summary["active_command_count"]) != 12 * int(summary["executed_ticks"])
		):
			return false
	return true


static func _all_structure_intact(summaries: Array[Dictionary], experiment: Dictionary) -> bool:
	for summary in summaries:
		if (
			int(summary["structural_saturation_count"]) != 0
			or (
				float(summary["maximum_applied_torque_nm"])
				> float(experiment["maximum_structural_torque_nm"])
			)
		):
			return false
	return true


static func _all_allocator_commands_feasible(summaries: Array[Dictionary]) -> bool:
	for summary in summaries:
		if (
			not bool(summary["support_allocator_used"])
			or int(summary["support_allocator_command_count"]) <= 0
			or int(summary["support_allocator_infeasible_count"]) != 0
			or float(summary["minimum_support_allocator_normal_reserve_n"]) <= 0.0
		):
			return false
	return true


static func _all_measurement_boundaries_intact(summaries: Array[Dictionary]) -> bool:
	for summary in summaries:
		if (
			bool(summary["per_contact_commands_are_measurements"])
			or bool(summary["per_foot_measured_load_allocation_available"])
			or bool(summary["contact_presence_is_bearing_measurement"])
			or bool(summary["semantic_release_or_gap_is_load_measurement"])
		):
			return false
	return true


static func _all_summary_boundaries_valid(
	summaries: Array[Dictionary], experiment: Dictionary
) -> bool:
	for summary in summaries:
		if not _summary_boundary_valid(summary, experiment):
			return false
	return true


static func _exact_fixture(summary: Dictionary) -> bool:
	return (
		int(summary["body_count"]) == 9
		and int(summary["physical_limb_count"]) == 4
		and int(summary["actuated_dof_count"]) == 12
		and int(summary["joint_node_count"]) == 8
		and int(summary["static_body_count"]) == 1
		and int(summary["world_anchor_count"]) == 0
		and int(summary["root_pin_count"]) == 0
		and int(summary["rail_count"]) == 0
		and int(summary["guide_count"]) == 0
		and int(summary["gimbal_count"]) == 0
		and int(summary["built_in_joint_motor_count"]) == 0
		and int(summary["joint_spring_count"]) == 0
		and int(summary["freeze_operation_count_after_release"]) == 0
		and int(summary["root_controller_force_or_torque_operation_count"]) == 0
		and int(summary["foot_pin_operation_count"]) == 0
		and int(summary["pose_teleport_operation_count"]) == 0
	)


static func _summary_boundary_valid(summary: Dictionary, experiment: Dictionary) -> bool:
	return (
		bool(summary.get("bounded_targeted_relocation_recontact_observed", false))
		and int(summary.get("semantic_relocated_contact_creation_count", 0)) == 1
		and (
			float(summary.get("semantic_relocation_horizontal_displacement_m", 0.0))
			>= float(experiment["minimum_semantic_relocation_horizontal_displacement_m"])
		)
		and (
			float(summary.get("semantic_relocation_horizontal_target_error_m", INF))
			<= float(experiment["maximum_semantic_relocation_horizontal_target_error_m"])
		)
		and not bool(summary.get("new_protective_contact_established", true))
		and not bool(summary.get("locomotor_step_established", true))
		and not bool(summary.get("free_3d_recovery_established", true))
		and not bool(summary.get("step_gait_or_walking_established", true))
		and not bool(summary.get("automatic_creature_guidance_allowed", true))
		and not bool(summary.get("contact_presence_is_bearing_measurement", true))
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
