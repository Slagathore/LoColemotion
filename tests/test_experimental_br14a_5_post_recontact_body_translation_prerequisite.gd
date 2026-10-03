extends SceneTree
# gdlint: disable=max-line-length

## BR14A.5 all-seed post-recontact body-translation prerequisite.
##
## Candidate 9's real targeted foot placement and long-horizon recovery are
## retained. A delayed four-contact endpoint controller then advances the
## whole-system COM and torso along declared +X with bounded foot slip. Final
## placement retention is measured and fails the old target tolerance, so this
## remains narrower than a complete locomotor step.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_post_recontact_body_translation_candidate.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")

const PHYSICS_HZ := 120
const EXPECTED_BY_SEED := {
	14001:
	{
		"release": 725,
		"recontact": 733,
		"damping_ticks": 1567,
		"translation_start": 1333,
		"translation_ticks": 967,
		"com_x": 0.014894,
		"com_z": -0.000780,
		"torso_x": 0.016732,
		"torso_z": -0.000880,
		"maximum_foot_slip": 0.002480,
		"final_foot_displacement": 0.039057,
		"final_foot_error": 0.050115,
		"final_height": 0.398493,
		"final_tilt": 0.014473,
		"final_speed": 0.000100,
		"anchor": 0.001996,
		"hinge": 0.008591,
		"torque": 29.303101,
	},
	14002:
	{
		"release": 724,
		"recontact": 732,
		"damping_ticks": 1568,
		"translation_start": 1332,
		"translation_ticks": 968,
		"com_x": 0.021223,
		"com_z": -0.001722,
		"torso_x": 0.023756,
		"torso_z": -0.001934,
		"maximum_foot_slip": 0.003760,
		"final_foot_displacement": 0.042853,
		"final_foot_error": 0.048978,
		"final_height": 0.401199,
		"final_tilt": 0.009991,
		"final_speed": 0.000097,
		"anchor": 0.000857,
		"hinge": 0.008005,
		"torque": 12.550373,
	},
	14003:
	{
		"release": 725,
		"recontact": 733,
		"damping_ticks": 1567,
		"translation_start": 1333,
		"translation_ticks": 967,
		"com_x": 0.019155,
		"com_z": -0.000055,
		"torso_x": 0.021402,
		"torso_z": -0.000042,
		"maximum_foot_slip": 0.003469,
		"final_foot_displacement": 0.050522,
		"final_foot_error": 0.061828,
		"final_height": 0.403542,
		"final_tilt": 0.003485,
		"final_speed": 0.000129,
		"anchor": 0.000987,
		"hinge": 0.008717,
		"torque": 14.524849,
	},
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.5 post-recontact body-translation prerequisite ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var experiment_result := ExperimentScript.compile(ExperimentScript.configuration())
	_check(
		bool(profile_result.get("ok", false)) and bool(experiment_result.get("ok", false)),
		"exact profile and tenth-candidate translation contract seal"
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
		var com_translation: Vector3 = summary["post_recontact_body_translation_com_displacement_world_m"]
		var torso_translation: Vector3 = summary["post_recontact_body_translation_torso_displacement_world_m"]
		print(
			(
				(
					"  seed=%d release=%d recontact=%d translation=%d/%d "
					+ "com=(%.6f,%.6f) torso=(%.6f,%.6f) slip=%.6f "
					+ "final_foot=%.6f/error=%.6f final_h=%.6f tilt=%.6f "
					+ "speed=%.6f anchor=%.6f hinge=%.6f torque=%.6f"
				)
				% [
					seed,
					int(summary["contact_release_first_tick"]),
					int(summary["semantic_release_recontact_tick"]),
					int(summary["post_recontact_body_translation_start_tick"]),
					int(summary["post_recontact_body_translation_command_tick_count"]),
					com_translation.x,
					com_translation.z,
					torso_translation.x,
					torso_translation.z,
					float(summary["maximum_post_recontact_body_translation_foot_slip_m"]),
					float(summary["semantic_relocation_final_horizontal_displacement_m"]),
					float(summary["semantic_relocation_final_horizontal_target_error_m"]),
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
		"all three fresh body-translation worlds return complete summaries"
	)
	if summaries.size() != (experiment["active_seed_set"] as Array).size():
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return

	var complete := true
	var exact_fixture := true
	var source_prerequisites := true
	var exact_timeline := true
	var exact_translation := true
	var directed_translation := true
	var bounded_slip := true
	var final_placement_not_retained := true
	var final_recovery := true
	var contact_integrity := true
	var geometry_intact := true
	var receipts_complete := true
	var structure_and_allocator_intact := true
	var measurement_boundary := true
	var summary_boundaries := true
	for summary in summaries:
		var expected: Dictionary = EXPECTED_BY_SEED[int(summary["seed"])]
		var com_translation: Vector3 = summary["post_recontact_body_translation_com_displacement_world_m"]
		var torso_translation: Vector3 = summary["post_recontact_body_translation_torso_displacement_world_m"]
		complete = (
			complete
			and bool(summary["fixture_complete"])
			and String(summary["fixture_failure_code"]).is_empty()
			and int(summary["executed_ticks"]) == int(experiment["trial_ticks"])
		)
		exact_fixture = exact_fixture and _exact_fixture(summary)
		source_prerequisites = (
			source_prerequisites
			and bool(summary["bounded_targeted_relocation_recontact_observed"])
			and bool(summary["long_horizon_targeted_relocation_recovery_observed"])
			and int(summary["semantic_relocated_contact_creation_count"]) == 1
		)
		exact_timeline = (
			exact_timeline
			and int(summary["contact_release_first_tick"]) == int(expected["release"])
			and int(summary["semantic_release_recontact_tick"]) == int(expected["recontact"])
			and (
				int(summary["semantic_joint_damping_command_tick_count"])
				== int(expected["damping_ticks"])
			)
			and (
				int(summary["post_recontact_body_translation_start_tick"])
				== int(expected["translation_start"])
			)
			and (
				int(summary["post_recontact_body_translation_command_tick_count"])
				== int(expected["translation_ticks"])
			)
		)
		exact_translation = (
			exact_translation
			and _near(com_translation.x, expected["com_x"])
			and _near(com_translation.z, expected["com_z"])
			and _near(torso_translation.x, expected["torso_x"])
			and _near(torso_translation.z, expected["torso_z"])
			and _near(
				summary["maximum_post_recontact_body_translation_foot_slip_m"],
				expected["maximum_foot_slip"]
			)
		)
		directed_translation = (
			directed_translation
			and com_translation.x >= float(experiment["minimum_post_recontact_com_translation_m"])
			and (
				torso_translation.x
				>= float(experiment["minimum_post_recontact_torso_translation_m"])
			)
			and absf(com_translation.z) <= 0.003
			and absf(torso_translation.z) <= 0.003
			and bool(summary["bounded_post_recontact_body_translation_observed"])
		)
		for slip_value in (
			(summary["post_recontact_body_translation_foot_slip_m_by_limb"] as Dictionary).values()
		):
			bounded_slip = (
				bounded_slip
				and float(slip_value) <= float(experiment["maximum_post_recontact_foot_slip_m"])
			)
		final_placement_not_retained = (
			final_placement_not_retained
			and _near(
				summary["semantic_relocation_final_horizontal_displacement_m"],
				expected["final_foot_displacement"]
			)
			and _near(
				summary["semantic_relocation_final_horizontal_target_error_m"],
				expected["final_foot_error"]
			)
			and float(summary["semantic_relocation_final_horizontal_target_error_m"]) > 0.010
		)
		final_recovery = (
			final_recovery
			and _near(summary["final_torso_height_m"], expected["final_height"])
			and _near(summary["final_tilt_rad"], expected["final_tilt"])
			and _near(summary["final_full_speed_rad_s"], expected["final_speed"])
			and (
				float(summary["final_torso_height_m"])
				>= float(experiment["minimum_long_horizon_torso_height_m"])
			)
			and (
				float(summary["final_tilt_rad"])
				<= float(experiment["maximum_long_horizon_torso_tilt_rad"])
			)
			and (
				float(summary["final_full_speed_rad_s"])
				<= float(experiment["maximum_long_horizon_torso_speed_rad_s"])
			)
		)
		contact_integrity = (
			contact_integrity
			and bool(summary["final_all_four_contacts"])
			and int(summary["torso_contact_ticks"]) == 0
		)
		geometry_intact = (
			geometry_intact
			and _near(summary["maximum_anchor_error_m"], expected["anchor"])
			and _near(summary["maximum_hinge_axis_error_rad"], expected["hinge"])
			and (
				float(summary["maximum_anchor_error_m"])
				<= float(experiment["maximum_anchor_error_m"])
			)
			and (
				float(summary["maximum_hinge_axis_error_rad"])
				<= float(experiment["maximum_hinge_axis_error_rad"])
			)
		)
		receipts_complete = (
			receipts_complete
			and bool(summary["all_receipts_complete"])
			and float(summary["maximum_pairing_residual_nm"]) <= 1.0e-9
			and int(summary["active_command_count"]) == 12 * int(summary["executed_ticks"])
		)
		structure_and_allocator_intact = (
			structure_and_allocator_intact
			and _near(summary["maximum_applied_torque_nm"], expected["torque"])
			and int(summary["structural_saturation_count"]) == 0
			and int(summary["support_allocator_infeasible_count"]) == 0
		)
		measurement_boundary = (
			measurement_boundary
			and not bool(summary["per_contact_commands_are_measurements"])
			and not bool(summary["per_foot_measured_load_allocation_available"])
			and not bool(summary["contact_presence_is_bearing_measurement"])
			and int(summary["root_controller_force_or_torque_operation_count"]) == 0
		)
		summary_boundaries = summary_boundaries and _summary_boundary_valid(summary)

	_check(complete, "every seed reaches the exact 2300-tick horizon")
	_check(exact_fixture, "all seeds retain the unscaffolded nine-body boundary")
	_check(
		source_prerequisites, "targeted recontact and long-horizon recovery remain prerequisites"
	)
	_check(exact_timeline, "release, recontact, damping, and translation timelines remain pinned")
	_check(exact_translation, "COM, torso, and worst-slip witnesses match the pinned table")
	_check(
		directed_translation, "every seed advances COM and torso along declared positive world X"
	)
	_check(bounded_slip, "every foot remains inside the translation-phase slip envelope")
	_check(
		final_placement_not_retained,
		"final foot-placement error remains explicit and blocks a complete-step claim"
	)
	_check(final_recovery, "every seed finishes upright and dynamically quiet")
	_check(contact_integrity, "all seeds finish on four ordinary contacts without torso contact")
	_check(geometry_intact, "all joint geometry remains inside the exact pinned envelopes")
	_check(receipts_complete, "every actuator command is paired and receipt-complete")
	_check(structure_and_allocator_intact, "structure and allocator histories remain intact")
	_check(measurement_boundary, "translation observations grant no root force or load measurement")
	_check(
		(
			String(experiment["candidate_result"])
			== "positive_bounded_post_recontact_body_translation_prerequisite"
		),
		"positive claim remains bounded to post-recontact body translation"
	)
	_check(summary_boundaries, "every summary retains complete-step and walking nonclaims")

	var forged_translation := summaries[0].duplicate(true)
	forged_translation["bounded_post_recontact_body_translation_observed"] = false
	_check(
		not _summary_boundary_valid(forged_translation), "forged translation witness fails closed"
	)
	var forged_step := summaries[0].duplicate(true)
	forged_step["locomotor_step_established"] = true
	_check(not _summary_boundary_valid(forged_step), "forged complete locomotor step fails closed")
	var forged_walk := summaries[0].duplicate(true)
	forged_walk["step_gait_or_walking_established"] = true
	_check(not _summary_boundary_valid(forged_walk), "forged walking claim fails closed")
	var mutated := ExperimentScript.configuration()
	mutated["post_recontact_body_translation_offset_world_m"] = [0.031, 0.0, 0.0]
	_check(
		not bool(ExperimentScript.compile(mutated).get("ok", false)),
		"post-seal translation target mutation fails closed"
	)
	Engine.physics_ticks_per_second = original_hz
	_finish()


static func _near(actual: Variant, expected: Variant) -> bool:
	return absf(float(actual) - float(expected)) <= 1.0e-6


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


static func _summary_boundary_valid(summary: Dictionary) -> bool:
	return (
		bool(summary.get("bounded_targeted_relocation_recontact_observed", false))
		and bool(summary.get("long_horizon_targeted_relocation_recovery_observed", false))
		and bool(summary.get("bounded_post_recontact_body_translation_observed", false))
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
