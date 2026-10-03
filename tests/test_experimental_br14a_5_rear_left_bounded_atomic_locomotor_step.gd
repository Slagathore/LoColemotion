extends SceneTree
# gdlint: disable=max-line-length

## BR14A.5 exact all-seed rear-left diagonal atomic-step commissioning.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_rear_left_bounded_atomic_locomotor_step.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")

const PHYSICS_HZ := 120
const EXPECTED_BY_SEED := {
	14001:
	{
		"release": 725,
		"recontact": 737,
		"recontact_move": 0.017026,
		"recontact_error": 0.007978,
		"foot_x": 0.024373,
		"foot_z": -0.038748,
		"foot_move": 0.045776,
		"foot_error": 0.038753,
		"com_x": 0.016776,
		"com_z": 0.000285,
		"torso_x": 0.018870,
		"torso_z": 0.000320,
		"slip": 0.002696,
		"height": 0.402813,
		"tilt": 0.016676,
		"speed": 0.000031,
	},
	14002:
	{
		"release": 724,
		"recontact": 736,
		"recontact_move": 0.016636,
		"recontact_error": 0.008886,
		"foot_x": 0.028902,
		"foot_z": -0.038274,
		"foot_move": 0.047961,
		"foot_error": 0.038473,
		"com_x": 0.013366,
		"com_z": 0.000304,
		"torso_x": 0.015079,
		"torso_z": 0.000339,
		"slip": 0.002081,
		"height": 0.402871,
		"tilt": 0.006252,
		"speed": 0.004926,
	},
	14003:
	{
		"release": 725,
		"recontact": 737,
		"recontact_move": 0.016582,
		"recontact_error": 0.008435,
		"foot_x": 0.053598,
		"foot_z": -0.024342,
		"foot_move": 0.058866,
		"foot_error": 0.037555,
		"com_x": 0.014334,
		"com_z": -0.001331,
		"torso_x": 0.016067,
		"torso_z": -0.001523,
		"slip": 0.002360,
		"height": 0.402036,
		"tilt": 0.045314,
		"speed": 0.000067,
	},
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Experimental BR14A.5 rear-left bounded atomic locomotor step ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var experiment_result := ExperimentScript.compile(ExperimentScript.configuration())
	_check(
		bool(profile_result.get("ok", false)) and bool(experiment_result.get("ok", false)),
		"exact profile and rear-left atomic-step contracts seal",
	)
	if not bool(profile_result.get("ok", false)) or not bool(experiment_result.get("ok", false)):
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return

	var profile: Dictionary = profile_result["profile"]
	var experiment: Dictionary = experiment_result["experiment"]
	var summaries: Array[Dictionary] = []
	for seed in experiment["exact_seed_set"]:
		var result := await RigScript.new().run_centroidal_contact_trial(
			self, profile, experiment, int(seed), true
		)
		if result.has("summary"):
			summaries.append(result["summary"])
		else:
			printerr("  seed=", seed, " result=", result)
	_check(summaries.size() == 3, "all three fresh rear-left worlds return summaries")

	var exact_horizon := summaries.size() == 3
	var exact_fixture := summaries.size() == 3
	var exact_timeline_and_witnesses := summaries.size() == 3
	var real_airborne_relocation := summaries.size() == 3
	var prerequisites := summaries.size() == 3
	var feedback_override_receipt := summaries.size() == 3
	var yaw_receipt := summaries.size() == 3
	var directed_translation := summaries.size() == 3
	var quiet_supported_finish := summaries.size() == 3
	var geometry_and_receipts := summaries.size() == 3
	var atomic_predicate := summaries.size() == 3
	var claim_boundaries := summaries.size() == 3
	for summary in summaries:
		var expected: Dictionary = EXPECTED_BY_SEED[int(summary["seed"])]
		var foot: Vector3 = summary["semantic_relocation_final_horizontal_displacement_world_m"]
		var com: Vector3 = summary["post_recontact_body_translation_com_displacement_world_m"]
		var torso: Vector3 = summary["post_recontact_body_translation_torso_displacement_world_m"]
		print(
			(
				(
					"  seed=%d recontact=%d move=%.6f error=%.6f "
					+ "foot=(%.6f,%.6f)/%.6f com=(%.6f,%.6f) "
					+ "torso=(%.6f,%.6f) slip=%.6f speed=%.6f atomic=%s"
				)
				% [
					int(summary["seed"]),
					int(summary["semantic_release_recontact_tick"]),
					float(summary["semantic_relocation_horizontal_displacement_m"]),
					float(summary["semantic_relocation_horizontal_target_error_m"]),
					foot.x,
					foot.z,
					foot.length(),
					com.x,
					com.z,
					torso.x,
					torso.z,
					float(summary["maximum_post_recontact_body_translation_foot_slip_m"]),
					float(summary["final_full_speed_rad_s"]),
					str(summary["bounded_atomic_locomotor_step_observed"]),
				]
			)
		)
		exact_horizon = (
			exact_horizon
			and bool(summary["fixture_complete"])
			and String(summary["fixture_failure_code"]).is_empty()
			and int(summary["executed_ticks"]) == 2300
		)
		exact_fixture = exact_fixture and _exact_fixture(summary)
		exact_timeline_and_witnesses = (
			exact_timeline_and_witnesses
			and int(summary["contact_release_first_tick"]) == int(expected["release"])
			and int(summary["semantic_release_recontact_tick"]) == int(expected["recontact"])
			and _near(
				summary["semantic_relocation_horizontal_displacement_m"], expected["recontact_move"]
			)
			and _near(
				summary["semantic_relocation_horizontal_target_error_m"],
				expected["recontact_error"]
			)
			and _near(foot.x, expected["foot_x"])
			and _near(foot.z, expected["foot_z"])
			and _near(foot.length(), expected["foot_move"])
			and _near(
				summary["semantic_relocation_final_horizontal_target_error_m"],
				expected["foot_error"]
			)
			and _near(com.x, expected["com_x"])
			and _near(com.z, expected["com_z"])
			and _near(torso.x, expected["torso_x"])
			and _near(torso.z, expected["torso_z"])
			and _near(
				summary["maximum_post_recontact_body_translation_foot_slip_m"], expected["slip"]
			)
		)
		real_airborne_relocation = (
			real_airborne_relocation
			and (
				float(summary["semantic_relocation_horizontal_displacement_m"])
				>= float(experiment["minimum_semantic_relocation_horizontal_displacement_m"])
			)
			and (
				float(summary["semantic_relocation_horizontal_target_error_m"])
				<= float(experiment["maximum_semantic_relocation_horizontal_target_error_m"])
			)
			and (
				int(summary["semantic_release_recontact_tick"])
				> int(summary["contact_release_first_tick"])
			)
		)
		prerequisites = (
			prerequisites
			and bool(summary["bounded_targeted_relocation_recontact_observed"])
			and bool(summary["long_horizon_targeted_relocation_recovery_observed"])
			and bool(summary["bounded_post_recontact_body_translation_observed"])
		)
		feedback_override_receipt = (
			feedback_override_receipt
			and int(summary["post_recontact_attitude_velocity_feedback_override_tick_count"]) == 300
		)
		yaw_receipt = (
			yaw_receipt
			and int(summary["post_recontact_yaw_damping_command_tick_count"]) > 900
			and (
				float(summary["maximum_post_recontact_yaw_damping_moment_nm"])
				<= float(experiment["maximum_post_recontact_yaw_damping_moment_nm"]) + 1.0e-6
			)
			and (
				float(summary["maximum_post_recontact_yaw_damping_endpoint_force_n"])
				<= float(experiment["maximum_post_recontact_yaw_damping_endpoint_force_n"]) + 1.0e-6
			)
		)
		directed_translation = (
			directed_translation
			and com.x >= float(experiment["minimum_post_recontact_com_translation_m"])
			and torso.x >= float(experiment["minimum_post_recontact_torso_translation_m"])
			and absf(com.z) <= float(experiment["maximum_atomic_lateral_translation_m"])
			and absf(torso.z) <= float(experiment["maximum_atomic_lateral_translation_m"])
			and (
				float(summary["maximum_post_recontact_body_translation_foot_slip_m"])
				<= float(experiment["maximum_post_recontact_foot_slip_m"])
			)
		)
		quiet_supported_finish = (
			quiet_supported_finish
			and _near(summary["final_torso_height_m"], expected["height"])
			and _near(summary["final_tilt_rad"], expected["tilt"])
			and _near(summary["final_full_speed_rad_s"], expected["speed"])
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
			atomic_predicate and bool(summary["bounded_atomic_locomotor_step_observed"])
		)
		claim_boundaries = claim_boundaries and _summary_boundary_valid(summary)

	_check(exact_horizon, "all exact programs complete the 2300-tick horizon")
	_check(exact_fixture, "all seeds retain the unscaffolded nine-body fixture")
	_check(exact_timeline_and_witnesses, "all exact movement witnesses match the pinned table")
	_check(real_airborne_relocation, "rear-left touchdown follows bounded airborne relocation")
	_check(prerequisites, "targeted recontact, recovery, and body translation remain mandatory")
	_check(feedback_override_receipt, "each seed executes the exact 300-tick feedback override")
	_check(yaw_receipt, "ground-mediated yaw commands remain inside both declared caps")
	_check(directed_translation, "COM and torso advance with bounded lateral drift and foot slip")
	_check(quiet_supported_finish, "every seed finishes quiet, upright, and on four contacts")
	_check(geometry_and_receipts, "geometry, receipts, structure, and allocator remain intact")
	_check(atomic_predicate, "all exact seeds establish one rear-left atomic locomotor step")
	_check(claim_boundaries, "all gait, walking, guidance, and knowledge nonclaims remain false")

	var mutated := ExperimentScript.configuration()
	mutated["minimum_semantic_relocation_horizontal_displacement_m"] = 0.013
	_check(
		not bool(ExperimentScript.compile(mutated).get("ok", false)),
		"post-seal touchdown-threshold weakening fails closed",
	)
	var forged := summaries[0].duplicate(true)
	forged["step_gait_or_walking_established"] = true
	_check(not _summary_boundary_valid(forged), "forged gait witness fails closed")
	_check(
		(
			bool(experiment["locomotor_step_claim_allowed"])
			and not bool(experiment["step_gait_or_walking_claim_allowed"])
		),
		"atomic-step authority is enabled while gait and walking remain disabled",
	)

	Engine.physics_ticks_per_second = original_hz
	_finish()


static func _near(actual: Variant, expected: Variant) -> bool:
	return absf(float(actual) - float(expected)) <= 2.0e-6


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
		and not bool(summary.get("step_gait_or_walking_established", true))
		and not bool(summary.get("automatic_creature_guidance_allowed", true))
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
