extends SceneTree
# gdlint: disable=max-line-length

## BR14A.4R positive four-contact handoff-readiness recovery commissioning.
##
## Each active/control pair shares the first acquisition and deliberate
## readiness-loss cycle. Only the active member receives the second
## acquisition target. No foot target changes and no contact is removed.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_readiness_recovery_experiment.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_readiness_recovery_rig.gd")

const PHYSICS_HZ := 120

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.4R four-contact readiness recovery ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var experiment_result := ExperimentScript.compile(ExperimentScript.configuration())
	_check(
		bool(profile_result.get("ok", false)) and bool(experiment_result.get("ok", false)),
		"exact spatial profile and readiness-recovery experiment seal"
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
		var active := await rig.run_readiness_recovery_trial(self, profile, experiment, seed, true)
		var control := await rig.run_readiness_recovery_trial(
			self, profile, experiment, seed, false
		)
		if not bool(active.get("ok", false)) or not bool(control.get("ok", false)):
			printerr("  seed=", seed, " active=", active, " control=", control)
			all_complete = false
			break
		active_summaries.append(active["summary"])
		control_summaries.append(control["summary"])
		print(
			(
				(
					"  seed=%d active_dwell=%d/%d/%d active_final=%.6f/%.6f "
					+ "control_dwell=%d/%d/%d control_final=%.6f/%.6f "
					+ "active_max_h=%.6f tilt=%.6f speed=%.6f/%.6f "
					+ "anchor=%.6f hinge=%.6f torque=%.6f"
				)
				% [
					seed,
					int(active["summary"]["longest_first_ready_dwell_ticks"]),
					int(active["summary"]["longest_readiness_loss_dwell_ticks"]),
					int(active["summary"]["longest_second_ready_dwell_ticks"]),
					float(active["summary"]["final_com_margin_m"]),
					float(active["summary"]["final_capture_margin_m"]),
					int(control["summary"]["longest_first_ready_dwell_ticks"]),
					int(control["summary"]["longest_readiness_loss_dwell_ticks"]),
					int(control["summary"]["longest_second_ready_dwell_ticks"]),
					float(control["summary"]["final_com_margin_m"]),
					float(control["summary"]["final_capture_margin_m"]),
					float(active["summary"]["maximum_height_error_m"]),
					float(active["summary"]["maximum_tilt_rad"]),
					float(active["summary"]["maximum_linear_speed_m_s"]),
					float(active["summary"]["maximum_angular_speed_rad_s"]),
					float(active["summary"]["maximum_anchor_error_m"]),
					float(active["summary"]["maximum_hinge_axis_error_rad"]),
					float(active["summary"]["maximum_applied_torque_nm"]),
				]
			)
		)
	_check(all_complete, "all active/control readiness worlds return complete summaries")
	if not all_complete:
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return

	var exact_fixture := true
	var matched_first_cycle := true
	var first_acquisition := true
	var deliberate_loss := true
	var active_reacquisition := true
	var causal_control := true
	var response_separation := true
	var contacts_retained := true
	var stance_envelope := true
	var geometry_and_structure := true
	var receipts := true
	var instrumentation_boundary := true
	var summary_nonclaims := true
	for index in range(active_summaries.size()):
		var active: Dictionary = active_summaries[index]
		var control: Dictionary = control_summaries[index]
		exact_fixture = (
			exact_fixture
			and _exact_fixture(active)
			and _exact_fixture(control)
			and int(active["executed_ticks"]) == int(experiment["trial_ticks"])
			and int(control["executed_ticks"]) == int(experiment["trial_ticks"])
		)
		matched_first_cycle = (
			matched_first_cycle
			and (
				int(active["longest_first_ready_dwell_ticks"])
				== int(control["longest_first_ready_dwell_ticks"])
			)
			and (
				int(active["longest_readiness_loss_dwell_ticks"])
				== int(control["longest_readiness_loss_dwell_ticks"])
			)
			and (
				absf(
					(
						float(active["minimum_first_ready_margin_m"])
						- float(control["minimum_first_ready_margin_m"])
					)
				)
				<= 1.0e-6
			)
			and (
				absf(
					float(active["maximum_loss_margin_m"]) - float(control["maximum_loss_margin_m"])
				)
				<= 1.0e-6
			)
		)
		first_acquisition = (
			first_acquisition
			and bool(active["first_readiness_acquired"])
			and bool(control["first_readiness_acquired"])
			and (
				int(active["longest_first_ready_dwell_ticks"])
				>= int(experiment["readiness_dwell_ticks_required"])
			)
		)
		deliberate_loss = (
			deliberate_loss
			and bool(active["readiness_loss_established"])
			and bool(control["readiness_loss_established"])
			and (
				int(active["longest_readiness_loss_dwell_ticks"])
				>= int(experiment["readiness_loss_dwell_ticks_required"])
			)
		)
		active_reacquisition = (
			active_reacquisition
			and bool(active["second_readiness_reacquired"])
			and (
				int(active["longest_second_ready_dwell_ticks"])
				>= int(experiment["readiness_dwell_ticks_required"])
			)
			and float(active["final_com_margin_m"]) >= float(experiment["minimum_ready_margin_m"])
			and (
				float(active["final_capture_margin_m"])
				>= float(experiment["minimum_ready_margin_m"])
			)
		)
		causal_control = (
			causal_control
			and not bool(control["second_readiness_reacquired"])
			and int(control["longest_second_ready_dwell_ticks"]) == 0
			and float(control["final_com_margin_m"]) <= float(experiment["maximum_loss_margin_m"])
			and (
				float(control["final_capture_margin_m"])
				<= float(experiment["maximum_loss_margin_m"])
			)
		)
		response_separation = (
			response_separation
			and (float(active["final_com_margin_m"]) > float(control["final_com_margin_m"]) + 0.025)
			and (
				float(active["final_capture_margin_m"])
				> float(control["final_capture_margin_m"]) + 0.025
			)
		)
		for fraction_value in active["contact_fractions"].values():
			contacts_retained = (
				contacts_retained
				and float(fraction_value) >= float(experiment["minimum_contact_fraction"])
			)
		contacts_retained = (
			contacts_retained
			and int(active["ordinary_existing_contact_count"]) == 4
			and int(active["new_contact_creation_count"]) == 0
			and int(active["torso_contact_ticks"]) == 0
		)
		stance_envelope = (
			stance_envelope
			and float(active["maximum_height_error_m"]) <= float(experiment["height_error_limit_m"])
			and float(active["maximum_tilt_rad"]) <= float(experiment["tilt_limit_rad"])
			and (
				float(active["final_linear_speed_m_s"])
				<= float(experiment["final_linear_speed_limit_m_s"])
			)
			and (
				float(active["final_angular_speed_rad_s"])
				<= float(experiment["final_angular_speed_limit_rad_s"])
			)
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
		receipts = (
			receipts
			and bool(active["all_receipts_complete"])
			and bool(control["all_receipts_complete"])
			and float(active["maximum_pairing_residual_nm"]) <= 1.0e-9
			and int(active["active_command_count"]) == 12 * int(active["executed_ticks"])
			and int(control["active_command_count"]) == 12 * int(control["executed_ticks"])
		)
		instrumentation_boundary = (
			instrumentation_boundary
			and not bool(active["observer_values_are_contact_load_measurements"])
			and not bool(active["per_contact_commands_are_measurements"])
			and not bool(active["per_foot_measured_load_allocation_available"])
			and not bool(active["contact_presence_is_bearing_measurement"])
		)
		summary_nonclaims = (
			summary_nonclaims
			and _summary_boundary_valid(active)
			and _summary_boundary_valid(control)
		)

	_check(exact_fixture, "readiness cycle retains the exact unscaffolded nine-body boundary")
	_check(matched_first_cycle, "active and control worlds share an identical first cycle")
	_check(first_acquisition, "every active/control pair first acquires the declared handoff")
	_check(deliberate_loss, "every pair deliberately leaves the declared readiness envelope")
	_check(active_reacquisition, "every active seed reacquires and dwells in handoff readiness")
	_check(causal_control, "withheld-target controls do not passively reacquire readiness")
	_check(response_separation, "active reacquisition produces a material final margin separation")
	_check(contacts_retained, "all four ordinary contacts remain present without torso contact")
	_check(
		stance_envelope,
		"active cycles retain source pose bounds and finish inside the static speed envelope"
	)
	_check(
		geometry_and_structure,
		"active joint geometry and applied torque remain inside source envelopes"
	)
	_check(receipts, "every active/control joint command is paired and receipt-complete")
	_check(
		instrumentation_boundary,
		"observer and contact-presence values grant no measured load or bearing claim"
	)
	_check(summary_nonclaims, "summaries preserve all protective-contact and locomotion nonclaims")
	_check(
		(
			(
				String(experiment["positive_claim"])
				== "four_contact_front_right_handoff_readiness_reacquired_in_commissioning"
			)
			and not bool(experiment["formal_milestone_acceptance_authorized"])
			and not bool(experiment["locomotor_step_claim_allowed"])
		),
		"positive claim remains bounded to four-contact readiness reacquisition"
	)
	var forged_step: Dictionary = (active_summaries[0] as Dictionary).duplicate(true)
	forged_step["locomotor_step_established"] = true
	_check(not _summary_boundary_valid(forged_step), "forged locomotor-step claim fails closed")
	var forged_positive: Dictionary = (active_summaries[0] as Dictionary).duplicate(true)
	forged_positive["four_contact_readiness_recovery_established"] = true
	_check(
		not _summary_boundary_valid(forged_positive), "forged per-run establishment fails closed"
	)
	Engine.physics_ticks_per_second = original_hz
	_finish()


static func _exact_fixture(summary: Dictionary) -> bool:
	return (
		bool(summary["fixture_complete"])
		and String(summary["fixture_failure_code"]).is_empty()
		and int(summary["body_count"]) == 9
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
		not bool(summary.get("four_contact_readiness_recovery_established", true))
		and not bool(summary.get("new_protective_contact_established", true))
		and not bool(summary.get("articulated_three_contact_bearing_established", true))
		and not bool(summary.get("locomotor_step_established", true))
		and not bool(summary.get("free_3d_recovery_established", true))
		and not bool(summary.get("step_gait_or_walking_established", true))
		and not bool(summary.get("automatic_creature_guidance_allowed", true))
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
