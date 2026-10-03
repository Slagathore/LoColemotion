extends SceneTree
# gdlint: disable=max-line-length

## BR14A.5 all-seed long-horizon targeted relocation/recovery prerequisite.
##
## This is still narrower than a locomotor step. One selected foot moves to a
## new ordinary contact and the exact system recovers, but there is no body
## translation target, second foot transition, repeated stepping, or gait.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_targeted_relocation_recovery_candidate.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")

const PHYSICS_HZ := 120
const EXPECTED_BY_SEED := {
	14001:
	{
		"release": 725,
		"recontact": 733,
		"displacement": 0.021375,
		"target_error": 0.001594,
		"swing_rate_norm": 4.026535,
		"all_limb": true,
		"damping_ticks": 967,
		"final_height": 0.397865,
		"final_tilt": 0.019160,
		"final_speed": 0.010973,
		"anchor": 0.001996,
		"hinge": 0.008591,
		"torque": 29.303101,
	},
	14002:
	{
		"release": 724,
		"recontact": 732,
		"displacement": 0.026687,
		"target_error": 0.006687,
		"swing_rate_norm": 3.420490,
		"all_limb": false,
		"damping_ticks": 968,
		"final_height": 0.400649,
		"final_tilt": 0.023190,
		"final_speed": 0.025664,
		"anchor": 0.000857,
		"hinge": 0.008005,
		"torque": 12.550373,
	},
	14003:
	{
		"release": 725,
		"recontact": 733,
		"displacement": 0.021483,
		"target_error": 0.002285,
		"swing_rate_norm": 3.366267,
		"all_limb": false,
		"damping_ticks": 967,
		"final_height": 0.402710,
		"final_tilt": 0.016102,
		"final_speed": 0.004032,
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
	print("=== Experimental BR14A.5 long-horizon targeted relocation recovery prerequisite ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var experiment_result := ExperimentScript.compile(ExperimentScript.configuration())
	_check(
		bool(profile_result.get("ok", false)) and bool(experiment_result.get("ok", false)),
		"exact profile and ninth-candidate recovery contract seal"
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
					"  seed=%d release=%d recontact=%d rate_norm=%.6f all_limb=%s "
					+ "damping=%d/%.6f displacement=%.6f target_error=%.6f "
					+ "final_h=%.6f tilt=%.6f speed=%.6f anchor=%.6f hinge=%.6f "
					+ "torque=%.6f"
				)
				% [
					seed,
					int(summary["contact_release_first_tick"]),
					int(summary["semantic_release_recontact_tick"]),
					float(summary["semantic_swing_joint_rate_norm_at_damping_start_rad_s"]),
					str(summary["semantic_all_limb_damping_latched"]),
					int(summary["semantic_joint_damping_command_tick_count"]),
					float(summary["maximum_semantic_joint_damping_command_nm"]),
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
		"all three fresh long-horizon physical worlds return complete summaries"
	)
	if summaries.size() != (experiment["active_seed_set"] as Array).size():
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return

	var complete := true
	var exact_fixture := true
	var handoff_ready := true
	var semantic_release := true
	var exact_witnesses := true
	var adaptive_witnesses := true
	var damping_complete := true
	var recovery_observed := true
	var recovery_envelope := true
	var contact_integrity := true
	var geometry_intact := true
	var receipts_complete := true
	var structure_and_allocator_intact := true
	var legacy_suppressed := true
	var measurement_boundary := true
	var summary_boundaries := true
	for summary in summaries:
		var expected: Dictionary = EXPECTED_BY_SEED[int(summary["seed"])]
		complete = (
			complete
			and bool(summary["fixture_complete"])
			and String(summary["fixture_failure_code"]).is_empty()
			and int(summary["executed_ticks"]) == int(experiment["trial_ticks"])
		)
		exact_fixture = exact_fixture and _exact_fixture(summary)
		handoff_ready = (
			handoff_ready
			and bool(summary["three_contact_entry_established"])
			and (
				float(summary["lift_entry_com_margin_m"])
				>= float(experiment["minimum_lift_entry_dynamic_margin_m"])
			)
			and (
				float(summary["lift_entry_capture_margin_m"])
				>= float(experiment["minimum_lift_entry_dynamic_margin_m"])
			)
		)
		semantic_release = (
			semantic_release
			and bool(summary["contact_release_latched"])
			and not bool(summary["contact_release_semantic_contact_present_at_latch"])
			and (
				int(summary["longest_semantic_contact_absent_dwell_ticks"])
				>= int(experiment["minimum_semantic_absence_dwell_ticks"])
			)
		)
		exact_witnesses = (
			exact_witnesses
			and int(summary["contact_release_first_tick"]) == int(expected["release"])
			and int(summary["semantic_release_recontact_tick"]) == int(expected["recontact"])
			and _near(
				summary["semantic_relocation_horizontal_displacement_m"], expected["displacement"]
			)
			and _near(
				summary["semantic_relocation_horizontal_target_error_m"], expected["target_error"]
			)
		)
		adaptive_witnesses = (
			adaptive_witnesses
			and _near(
				summary["semantic_swing_joint_rate_norm_at_damping_start_rad_s"],
				expected["swing_rate_norm"]
			)
			and bool(summary["semantic_all_limb_damping_latched"]) == bool(expected["all_limb"])
		)
		damping_complete = (
			damping_complete
			and int(summary["semantic_joint_damping_first_tick"]) == int(expected["recontact"])
			and (
				int(summary["semantic_joint_damping_command_tick_count"])
				== int(expected["damping_ticks"])
			)
			and _near(summary["maximum_semantic_joint_damping_command_nm"], 0.5)
		)
		recovery_observed = (
			recovery_observed
			and bool(summary["bounded_targeted_relocation_recontact_observed"])
			and bool(summary["long_horizon_targeted_relocation_recovery_observed"])
		)
		recovery_envelope = (
			recovery_envelope
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
			and int(summary["semantic_relocated_contact_creation_count"]) == 1
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
		legacy_suppressed = (
			legacy_suppressed
			and int(summary["swing_path_progress_ticks"]) == 0
			and int(summary["maximum_swing_path_progress_ticks"]) == 0
			and int(summary["disturbance_operation_count"]) == 0
			and int(summary["first_touch_tick"]) < 0
			and int(summary["new_contact_creation_count"]) == 0
		)
		measurement_boundary = (
			measurement_boundary
			and not bool(summary["per_contact_commands_are_measurements"])
			and not bool(summary["per_foot_measured_load_allocation_available"])
			and not bool(summary["contact_presence_is_bearing_measurement"])
			and not bool(summary["semantic_release_or_gap_is_load_measurement"])
		)
		summary_boundaries = summary_boundaries and _summary_boundary_valid(summary, experiment)

	_check(complete, "every seed reaches the exact 1700-tick horizon")
	_check(exact_fixture, "all seeds retain the unscaffolded nine-body boundary")
	_check(handoff_ready, "all seeds establish the measured lift-entry handoff")
	_check(semantic_release, "all seeds sustain the required engine-observed contact absence")
	_check(
		exact_witnesses,
		"release, relocated recontact, displacement, and target error remain pinned"
	)
	_check(adaptive_witnesses, "measured swing-rate norm selects the exact sealed damping scope")
	_check(
		damping_complete, "bounded joint damping starts at recontact and remains receipt-visible"
	)
	_check(
		recovery_observed, "every seed establishes the dedicated long-horizon recovery prerequisite"
	)
	_check(recovery_envelope, "all final height, tilt, and speed witnesses match the pinned table")
	_check(contact_integrity, "all seeds finish on four ordinary contacts without torso contact")
	_check(geometry_intact, "all joint geometry remains inside the exact pinned envelopes")
	_check(receipts_complete, "every actuator command is paired and receipt-complete")
	_check(structure_and_allocator_intact, "structure and allocator histories remain intact")
	_check(
		legacy_suppressed,
		"legacy step path, disturbance, and protective-contact accounting stay suppressed"
	)
	_check(measurement_boundary, "contact and controller observations remain non-load measurements")
	_check(
		(
			(
				String(experiment["candidate_result"])
				== "positive_long_horizon_targeted_relocation_recovery_prerequisite"
			)
			and (experiment["active_seed_set"] as Array) == [14001, 14002, 14003]
			and (experiment["expected_all_limb_damping_seed_set"] as Array) == [14001]
		),
		"positive prerequisite is pinned to the complete seed set and adaptive branch"
	)
	_check(
		summary_boundaries, "every summary retains the narrow recovery claim and broader nonclaims"
	)
	var forged_branch := summaries[0].duplicate(true)
	forged_branch["semantic_all_limb_damping_latched"] = false
	_check(
		not _summary_boundary_valid(forged_branch, experiment),
		"forged adaptive branch fails closed"
	)
	var forged_recovery := summaries[0].duplicate(true)
	forged_recovery["long_horizon_targeted_relocation_recovery_observed"] = false
	_check(
		not _summary_boundary_valid(forged_recovery, experiment),
		"forged recovery witness fails closed"
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


static func _summary_boundary_valid(summary: Dictionary, experiment: Dictionary) -> bool:
	var expected_all_limb := (
		float(summary.get("semantic_swing_joint_rate_norm_at_damping_start_rad_s", -INF))
		>= float(experiment["semantic_all_limb_damping_activation_rate_rad_s"])
	)
	return (
		bool(summary.get("bounded_targeted_relocation_recontact_observed", false))
		and bool(summary.get("long_horizon_targeted_relocation_recovery_observed", false))
		and (
			bool(summary.get("semantic_all_limb_damping_latched", not expected_all_limb))
			== expected_all_limb
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
