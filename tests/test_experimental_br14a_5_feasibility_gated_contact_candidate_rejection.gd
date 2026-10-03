extends SceneTree
# gdlint: disable=max-line-length

## BR14A.5 full-horizon rejection witness for the fourth free-3D
## new-protective-contact controller candidate.
##
## Candidate 4 makes swing progression conditional on a zero-feedback
## three-contact wrench check plus measured COM, capture, height, and attitude
## readiness. The first required seed aborts and returns near stance without
## crossing an infeasible transition, but it never re-arms or clears the foot.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_feasibility_gated_contact_candidate.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")

const PHYSICS_HZ := 120

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.5 feasibility-gated candidate rejection ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var experiment_result := ExperimentScript.compile(ExperimentScript.configuration())
	_check(
		bool(profile_result.get("ok", false)) and bool(experiment_result.get("ok", false)),
		"exact spatial profile and fourth-candidate rejection contract seal"
	)
	if not bool(profile_result.get("ok", false)) or not bool(experiment_result.get("ok", false)):
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var profile: Dictionary = profile_result["profile"]
	var experiment: Dictionary = experiment_result["experiment"]
	var seed := int(experiment["rejection_witness_seed"])
	var rig = RigScript.new()
	var result := await rig.run_centroidal_contact_trial(self, profile, experiment, seed, true)
	_check(
		bool(result.get("ok", false)) and result.has("summary"),
		"full-horizon safe-abort fixture completes with a diagnostic summary"
	)
	if not result.has("summary"):
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var summary: Dictionary = result["summary"]
	print(
		(
			(
				"  seed=%d executed=%d checks=%d pass=%d pause=%d retreat=%d "
				+ "progress=%d/%d clear=%d disturbance=%d "
				+ "final_h=%.6f tilt=%.6f speed=%.6f anchor=%.6f hinge=%.6f"
			)
			% [
				seed,
				int(summary["executed_ticks"]),
				int(summary["predictive_feasibility_check_count"]),
				int(summary["predictive_feasibility_pass_count"]),
				int(summary["predictive_feasibility_pause_count"]),
				int(summary["predictive_feasibility_retreat_tick_count"]),
				int(summary["swing_path_progress_ticks"]),
				int(summary["swing_path_required_ticks"]),
				int(summary["swing_clear_ticks_before_disturbance"]),
				int(summary["disturbance_operation_count"]),
				float(summary["final_torso_height_m"]),
				float(summary["final_tilt_rad"]),
				float(summary["final_full_speed_rad_s"]),
				float(summary["maximum_anchor_error_m"]),
				float(summary["maximum_hinge_axis_error_rad"]),
			]
		)
	)
	_check(
		(
			bool(summary["fixture_complete"])
			and String(summary["fixture_failure_code"]).is_empty()
			and int(summary["executed_ticks"]) == int(experiment["trial_ticks"])
		),
		"safe-abort execution reaches the complete sealed horizon without fixture refusal"
	)
	_check(_exact_fixture(summary), "candidate retains the unscaffolded nine-body boundary")
	_check(
		(
			bool(summary["three_contact_entry_established"])
			and (
				float(summary["lift_entry_com_margin_m"])
				>= float(experiment["minimum_lift_entry_dynamic_margin_m"])
			)
			and (
				float(summary["lift_entry_capture_margin_m"])
				>= float(experiment["minimum_lift_entry_dynamic_margin_m"])
			)
		),
		"measured lift-entry support gate is genuinely established"
	)
	_check(
		(
			bool(summary["predictive_feasibility_gate_used"])
			and int(summary["predictive_feasibility_check_count"]) > 0
			and int(summary["predictive_feasibility_pass_count"]) > 0
			and int(summary["predictive_feasibility_pause_count"]) > 0
			and int(summary["predictive_feasibility_retreat_tick_count"]) > 0
		),
		"predictive gate both advances and actively retreats the event path"
	)
	_check(
		(
			bool(summary["predictive_gate_retreating"])
			and int(summary["predictive_abort_hold_tick_count"]) > 0
			and int(summary["swing_path_progress_ticks"]) == 0
			and not bool(summary["swing_path_complete"])
		),
		"candidate safely stalls at zero progress rather than crossing the rejected transition"
	)
	_check(
		(
			(
				"TORSO_ATTITUDE_OUTSIDE_SWING_ENVELOPE"
				in (summary["last_predictive_infeasibility_reasons"] as Array)
			)
			and not bool(summary["last_predictive_feasibility_passed"])
		),
		"sealed readiness envelope remains fail-closed at the full horizon"
	)
	_check(
		(
			int(summary["swing_clear_ticks_before_disturbance"]) == 0
			and int(summary["disturbance_operation_count"]) == 0
			and int(summary["first_touch_tick"]) < 0
			and int(summary["new_contact_creation_count"]) == 0
		),
		"no clearance causes the disturbance and touchdown phases to remain suppressed"
	)
	_check(
		(
			bool(summary["support_allocator_used"])
			and int(summary["support_allocator_command_count"]) > 0
			and int(summary["support_allocator_infeasible_count"]) == 0
			and float(summary["minimum_support_allocator_normal_reserve_n"]) > 0.0
		),
		"every physically applied allocator command remains feasible"
	)
	_check(
		(
			(
				float(summary["final_height_error_m"])
				<= float(experiment["recovery_height_error_limit_m"])
			)
			and float(summary["final_tilt_rad"]) <= float(experiment["recovery_tilt_limit_rad"])
			and (
				float(summary["final_full_speed_rad_s"])
				<= float(experiment["recovery_full_speed_limit_rad_s"])
			)
		),
		"safe abort returns near the declared four-contact stance envelope"
	)
	_check(
		(
			float(summary["maximum_anchor_error_m"]) <= float(experiment["maximum_anchor_error_m"])
			and (
				float(summary["maximum_hinge_axis_error_rad"])
				<= float(experiment["maximum_hinge_axis_error_rad"])
			)
		),
		"safe-abort joint geometry remains inside both preregistered envelopes"
	)
	_check(
		(
			bool(summary["all_receipts_complete"])
			and float(summary["maximum_pairing_residual_nm"]) <= 1.0e-9
			and int(summary["active_command_count"]) == 12 * int(summary["executed_ticks"])
		),
		"every executed actuator command remains paired and receipt-complete"
	)
	_check(
		(
			int(summary["structural_saturation_count"]) == 0
			and (
				float(summary["maximum_applied_torque_nm"])
				<= float(experiment["maximum_structural_torque_nm"]) + 1.0e-6
			)
		),
		"safe abort never crosses the structural torque guard"
	)
	_check(
		(
			bool(summary["predictive_preflight_values_are_commands_not_measurements"])
			and not bool(summary["per_contact_commands_are_measurements"])
			and not bool(summary["per_foot_measured_load_allocation_available"])
			and not bool(summary["contact_presence_is_bearing_measurement"])
		),
		"preflight and allocator values grant no load or bearing measurement"
	)
	_check(
		(
			(
				String(experiment["candidate_result"])
				== "candidate_rejected_safe_abort_no_clearance_rearm"
			)
			and bool(experiment["full_seed_success_required"])
			and seed == int(experiment["active_seed_set"][0])
		),
		"sealed first-seed witness rejects only the exact all-seed state machine"
	)
	_check(_summary_boundary_valid(summary), "summary retains every broader non-claim")
	var forged_positive := summary.duplicate(true)
	forged_positive["new_protective_contact_established"] = true
	_check(
		not _summary_boundary_valid(forged_positive),
		"forged positive BR14A.5 establishment fails closed"
	)
	Engine.physics_ticks_per_second = original_hz
	_finish()


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
		not bool(summary.get("new_protective_contact_established", true))
		and not bool(summary.get("locomotor_step_established", true))
		and not bool(summary.get("free_3d_recovery_established", true))
		and not bool(summary.get("step_gait_or_walking_established", true))
		and not bool(summary.get("automatic_creature_guidance_allowed", true))
		and not bool(summary.get("dynamic_capture_is_articulated_guarantee", true))
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
