extends SceneTree
# gdlint: disable=max-line-length

## BR14A.5 exact all-seed bounded atomic locomotor-step commissioning.
##
## This reuses Candidate10's unchanged physical controller and separates a
## complete support-to-support locomotor cycle from accurate foothold targeting.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_bounded_atomic_locomotor_step.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")

const PHYSICS_HZ := 120
const EXPECTED_BY_SEED := {
	14001:
	{
		"release": 725,
		"recontact": 733,
		"translation_start": 1333,
		"translation_ticks": 967,
		"com_x": 0.014894,
		"com_z": -0.000780,
		"torso_x": 0.016732,
		"torso_z": -0.000880,
		"maximum_foot_slip": 0.002480,
		"final_foot_x": -0.014650,
		"final_foot_z": 0.036205,
		"final_foot_displacement": 0.039057,
		"final_foot_error": 0.050115,
		"final_height": 0.398493,
		"final_tilt": 0.014473,
		"final_speed": 0.000100,
	},
	14002:
	{
		"release": 724,
		"recontact": 732,
		"translation_start": 1332,
		"translation_ticks": 968,
		"com_x": 0.021223,
		"com_z": -0.001722,
		"torso_x": 0.023756,
		"torso_z": -0.001934,
		"maximum_foot_slip": 0.003760,
		"final_foot_x": -0.004062,
		"final_foot_z": 0.042660,
		"final_foot_displacement": 0.042853,
		"final_foot_error": 0.048978,
		"final_height": 0.401199,
		"final_tilt": 0.009991,
		"final_speed": 0.000097,
	},
	14003:
	{
		"release": 725,
		"recontact": 733,
		"translation_start": 1333,
		"translation_ticks": 967,
		"com_x": 0.019155,
		"com_z": -0.000055,
		"torso_x": 0.021402,
		"torso_z": -0.000042,
		"maximum_foot_slip": 0.003469,
		"final_foot_x": -0.021755,
		"final_foot_z": 0.045599,
		"final_foot_displacement": 0.050522,
		"final_foot_error": 0.061828,
		"final_height": 0.403542,
		"final_tilt": 0.003485,
		"final_speed": 0.000129,
	},
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Experimental BR14A.5 bounded atomic locomotor step ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ

	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var experiment_result := ExperimentScript.compile(ExperimentScript.configuration())
	_check(
		bool(profile_result.get("ok", false)) and bool(experiment_result.get("ok", false)),
		"exact profile and atomic-step contracts seal",
	)
	if not bool(profile_result.get("ok", false)) or not bool(experiment_result.get("ok", false)):
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return

	var profile: Dictionary = profile_result["profile"]
	var experiment: Dictionary = experiment_result["experiment"]
	var summaries: Array[Dictionary] = []
	for seed in [14001, 14002, 14003]:
		var rig = RigScript.new()
		var result := await rig.run_centroidal_contact_trial(self, profile, experiment, seed, true)
		if not result.has("summary"):
			printerr("  seed=", seed, " result=", result)
			continue
		var summary: Dictionary = result["summary"]
		summaries.append(summary)
		var com_translation: Vector3 = summary["post_recontact_body_translation_com_displacement_world_m"]
		var torso_translation: Vector3 = summary["post_recontact_body_translation_torso_displacement_world_m"]
		var final_foot_translation: Vector3 = summary["semantic_relocation_final_horizontal_displacement_world_m"]
		print(
			(
				(
					"  seed=%d release=%d recontact=%d translation=%d/%d "
					+ "foot=(%.6f,%.6f)/%.6f target_error=%.6f "
					+ "com=(%.6f,%.6f) torso=(%.6f,%.6f) slip=%.6f "
					+ "h=%.6f tilt=%.6f speed=%.6f atomic=%s"
				)
				% [
					seed,
					int(summary["contact_release_first_tick"]),
					int(summary["semantic_release_recontact_tick"]),
					int(summary["post_recontact_body_translation_start_tick"]),
					int(summary["post_recontact_body_translation_command_tick_count"]),
					final_foot_translation.x,
					final_foot_translation.z,
					float(summary["semantic_relocation_final_horizontal_displacement_m"]),
					float(summary["semantic_relocation_final_horizontal_target_error_m"]),
					com_translation.x,
					com_translation.z,
					torso_translation.x,
					torso_translation.z,
					float(summary["maximum_post_recontact_body_translation_foot_slip_m"]),
					float(summary["final_torso_height_m"]),
					float(summary["final_tilt_rad"]),
					float(summary["final_full_speed_rad_s"]),
					str(summary["bounded_atomic_locomotor_step_observed"]),
				]
			)
		)

	_check(summaries.size() == 3, "all three fresh atomic-step worlds return summaries")

	var exact_horizon := summaries.size() == 3
	var exact_fixture := summaries.size() == 3
	var prerequisites := summaries.size() == 3
	var exact_timeline := summaries.size() == 3
	var exact_witnesses := summaries.size() == 3
	var final_foot_vector_pinned := summaries.size() == 3
	var bounded_final_relocation := summaries.size() == 3
	var directed_body_translation := summaries.size() == 3
	var bounded_translation_slip := summaries.size() == 3
	var quiet_supported_finish := summaries.size() == 3
	var geometry_and_receipts := summaries.size() == 3
	var atomic_predicate := summaries.size() == 3
	var claim_boundaries := summaries.size() == 3
	for summary in summaries:
		var expected: Dictionary = EXPECTED_BY_SEED[int(summary["seed"])]
		var com_translation: Vector3 = summary["post_recontact_body_translation_com_displacement_world_m"]
		var torso_translation: Vector3 = summary["post_recontact_body_translation_torso_displacement_world_m"]
		var final_foot_translation: Vector3 = summary["semantic_relocation_final_horizontal_displacement_world_m"]
		exact_horizon = (
			exact_horizon
			and bool(summary["fixture_complete"])
			and String(summary["fixture_failure_code"]).is_empty()
			and int(summary["executed_ticks"]) == int(experiment["trial_ticks"])
		)
		exact_fixture = exact_fixture and _exact_fixture(summary)
		prerequisites = (
			prerequisites
			and bool(summary["bounded_targeted_relocation_recontact_observed"])
			and bool(summary["long_horizon_targeted_relocation_recovery_observed"])
			and bool(summary["bounded_post_recontact_body_translation_observed"])
		)
		exact_timeline = (
			exact_timeline
			and int(summary["contact_release_first_tick"]) == int(expected["release"])
			and int(summary["semantic_release_recontact_tick"]) == int(expected["recontact"])
			and (
				int(summary["post_recontact_body_translation_start_tick"])
				== int(expected["translation_start"])
			)
			and (
				int(summary["post_recontact_body_translation_command_tick_count"])
				== int(expected["translation_ticks"])
			)
			and (
				(
					int(summary["post_recontact_body_translation_start_tick"])
					- int(summary["semantic_release_recontact_tick"])
				)
				>= int(experiment["minimum_atomic_settling_delay_ticks"])
			)
		)
		exact_witnesses = (
			exact_witnesses
			and _near(com_translation.x, expected["com_x"])
			and _near(com_translation.z, expected["com_z"])
			and _near(torso_translation.x, expected["torso_x"])
			and _near(torso_translation.z, expected["torso_z"])
			and _near(
				summary["maximum_post_recontact_body_translation_foot_slip_m"],
				expected["maximum_foot_slip"],
			)
			and _near(
				summary["semantic_relocation_final_horizontal_displacement_m"],
				expected["final_foot_displacement"],
			)
			and _near(
				summary["semantic_relocation_final_horizontal_target_error_m"],
				expected["final_foot_error"],
			)
		)
		final_foot_vector_pinned = (
			final_foot_vector_pinned
			and _near(final_foot_translation.x, expected["final_foot_x"])
			and _near(final_foot_translation.z, expected["final_foot_z"])
		)
		bounded_final_relocation = (
			bounded_final_relocation
			and (
				final_foot_translation.length()
				>= float(experiment["minimum_atomic_final_foot_relocation_m"])
			)
			and (
				final_foot_translation.length()
				<= float(experiment["maximum_atomic_final_foot_relocation_m"])
			)
			and (
				float(summary["semantic_relocation_final_horizontal_target_error_m"])
				<= float(experiment["maximum_atomic_final_foothold_target_error_m"])
			)
		)
		directed_body_translation = (
			directed_body_translation
			and com_translation.x >= float(experiment["minimum_post_recontact_com_translation_m"])
			and (
				torso_translation.x
				>= float(experiment["minimum_post_recontact_torso_translation_m"])
			)
			and absf(com_translation.z) <= float(experiment["maximum_atomic_lateral_translation_m"])
			and (
				absf(torso_translation.z)
				<= float(experiment["maximum_atomic_lateral_translation_m"])
			)
		)
		for slip_value in (
			(summary["post_recontact_body_translation_foot_slip_m_by_limb"] as Dictionary).values()
		):
			bounded_translation_slip = (
				bounded_translation_slip
				and float(slip_value) <= float(experiment["maximum_post_recontact_foot_slip_m"])
			)
		quiet_supported_finish = (
			quiet_supported_finish
			and _near(summary["final_torso_height_m"], expected["final_height"])
			and _near(summary["final_tilt_rad"], expected["final_tilt"])
			and _near(summary["final_full_speed_rad_s"], expected["final_speed"])
			and bool(summary["final_all_four_contacts"])
			and int(summary["torso_contact_ticks"]) == 0
		)
		geometry_and_receipts = (
			geometry_and_receipts
			and bool(summary["all_receipts_complete"])
			and int(summary["structural_saturation_count"]) == 0
			and int(summary["support_allocator_infeasible_count"]) == 0
			and (
				float(summary["maximum_anchor_error_m"])
				<= float(experiment["maximum_anchor_error_m"])
			)
			and (
				float(summary["maximum_hinge_axis_error_rad"])
				<= float(experiment["maximum_hinge_axis_error_rad"])
			)
		)
		atomic_predicate = (
			atomic_predicate
			and bool(summary["bounded_atomic_locomotor_step_observed"])
			and bool(summary["locomotor_step_established"])
		)
		claim_boundaries = claim_boundaries and _summary_boundary_valid(summary)

	_check(exact_horizon, "every seed reaches the exact 2300-tick horizon")
	_check(exact_fixture, "all seeds retain the unscaffolded nine-body fixture")
	_check(prerequisites, "targeted recontact, recovery, and body translation remain mandatory")
	_check(exact_timeline, "release, recontact, settling, and translation timelines remain pinned")
	_check(exact_witnesses, "all scalar movement witnesses match the pinned table")
	_check(final_foot_vector_pinned, "final moved-foot displacement vectors match the pinned table")
	_check(bounded_final_relocation, "the moved foot finishes in the declared relocation envelope")
	_check(directed_body_translation, "COM and torso advance along declared positive world X")
	_check(bounded_translation_slip, "every foot remains in the planted translation-slip envelope")
	_check(quiet_supported_finish, "every seed finishes quiet, upright, and on four contacts")
	_check(geometry_and_receipts, "geometry, receipts, structure, and allocator remain intact")
	_check(atomic_predicate, "all exact seeds establish one bounded atomic locomotor step")
	_check(claim_boundaries, "atomic-step summaries preserve every gait and guidance nonclaim")
	_check(
		String(experiment["candidate_result"]) == "positive_bounded_atomic_locomotor_step",
		"positive claim is exactly one bounded atomic locomotor step",
	)
	_check(
		(
			bool(experiment["locomotor_step_claim_allowed"])
			and not bool(experiment["step_gait_or_walking_claim_allowed"])
		),
		"step authority is enabled while gait and walking authority remain disabled",
	)

	var forged_atomic := summaries[0].duplicate(true)
	forged_atomic["bounded_atomic_locomotor_step_observed"] = false
	_check(not _summary_boundary_valid(forged_atomic), "forged atomic-step witness fails closed")
	var forged_walk := summaries[0].duplicate(true)
	forged_walk["step_gait_or_walking_established"] = true
	_check(not _summary_boundary_valid(forged_walk), "forged walking witness fails closed")
	var mutated := ExperimentScript.configuration()
	mutated["maximum_atomic_final_foothold_target_error_m"] = 0.066
	_check(
		not bool(ExperimentScript.compile(mutated).get("ok", false)),
		"post-seal foothold-error widening fails closed",
	)
	var stripped_authority := ExperimentScript.configuration()
	stripped_authority["locomotor_step_claim_allowed"] = false
	_check(
		not bool(ExperimentScript.compile(stripped_authority).get("ok", false)),
		"post-seal atomic-step authority removal fails closed",
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
		and bool(summary.get("bounded_atomic_locomotor_step_observed", false))
		and bool(summary.get("locomotor_step_established", false))
		and not bool(summary.get("new_protective_contact_established", true))
		and not bool(summary.get("free_3d_recovery_established", true))
		and not bool(summary.get("step_gait_or_walking_established", true))
		and not bool(summary.get("automatic_creature_guidance_allowed", true))
		and not bool(summary.get("contact_presence_is_bearing_measurement", true))
		and not bool(summary.get("per_foot_measured_load_allocation_available", true))
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
