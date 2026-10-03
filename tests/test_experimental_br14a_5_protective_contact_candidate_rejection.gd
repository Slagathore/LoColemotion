extends SceneTree
# gdlint: disable=max-line-length

## BR14A.5 early-stop rejection witness for the first free-3D
## new-protective-contact controller candidate.
##
## A useful partial event is deliberately not promoted into a pass: the exact
## candidate can clear and retouch the front-right foot, but it does not keep
## geometry, sustained-contact quality, and recovery inside the preregistered
## envelopes. One exact seed is sufficient to reject a candidate that was
## required to pass every seed.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_protective_contact_experiment.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_protective_contact_rig.gd")

const PHYSICS_HZ := 120

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.5 protective-contact candidate rejection ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var experiment_result := ExperimentScript.compile(ExperimentScript.configuration())
	_check(
		bool(profile_result.get("ok", false)) and bool(experiment_result.get("ok", false)),
		"exact spatial profile and candidate-rejection contract seal"
	)
	if not bool(profile_result.get("ok", false)) or not bool(experiment_result.get("ok", false)):
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var profile: Dictionary = profile_result["profile"]
	var experiment: Dictionary = experiment_result["experiment"]
	var seed := int(experiment["rejection_witness_seed"])
	var rig = RigScript.new()
	var active := await rig.run_protective_contact_trial(self, profile, experiment, seed, true)
	var control := await rig.run_protective_contact_trial(self, profile, experiment, seed, false)
	var worlds_complete := bool(active.get("ok", false)) and bool(control.get("ok", false))
	_check(worlds_complete, "active and matched hold-clear candidate worlds complete")
	if not worlds_complete:
		printerr("  active=", active, " control=", control)
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var active_summary: Dictionary = active["summary"]
	var control_summary: Dictionary = control["summary"]
	print(
		(
			(
				"  seed=%d clear=%d active_touch=%d error=%.6f post_contact=%.6f "
				+ "control_touch=%d dwell=%d final_h=%.6f tilt=%.6f "
				+ "anchor=%.6f hinge=%.6f torque=%.6f "
				+ "margin_lift=%.6f margin_disturbance=%.6f margin_min=%.6f"
			)
			% [
				seed,
				int(active_summary["swing_clear_ticks_before_disturbance"]),
				int(active_summary["first_touch_tick"]),
				float(active_summary["first_touch_target_error_m"]),
				float(active_summary["post_touch_contact_fraction"]),
				int(control_summary["first_touch_tick"]),
				int(active_summary["longest_recovery_dwell_ticks"]),
				float(active_summary["final_torso_height_m"]),
				float(active_summary["final_tilt_rad"]),
				float(active_summary["maximum_anchor_error_m"]),
				float(active_summary["maximum_hinge_axis_error_rad"]),
				float(active_summary["maximum_applied_torque_nm"]),
				float(active_summary["support_margin_at_lift_start_m"]),
				float(active_summary["support_margin_at_disturbance_m"]),
				float(active_summary["minimum_three_contact_support_margin_m"]),
			]
		)
	)
	_check(_exact_fixture(active_summary), "candidate retains the unscaffolded nine-body boundary")
	_check(
		(
			int(active_summary["swing_clear_ticks_before_disturbance"])
			>= int(experiment["minimum_pre_disturbance_clear_ticks"])
		),
		"candidate physically clears the swing foot before disturbance"
	)
	_check(
		(
			int(active_summary["disturbance_operation_count"]) == 1
			and int(control_summary["disturbance_operation_count"]) == 1
			and not bool(active_summary["disturbance_is_controller_operation"])
		),
		"both worlds receive one matched noncontroller roll impulse"
	)
	_check(
		(
			bool(active_summary["touchdown_before_deadline"])
			and int(active_summary["new_contact_creation_count"]) == 1
			and (
				float(active_summary["first_touch_target_error_m"])
				<= float(experiment["maximum_touchdown_target_error_m"])
			)
		),
		"active candidate creates a provisional targeted ordinary-floor contact"
	)
	_check(
		int(control_summary["first_touch_tick"]) > int(active_summary["first_touch_tick"]),
		"commanded touchdown precedes matched hold-clear incidental collapse"
	)
	var supports_retained := true
	for fraction_value in active_summary["support_contact_fractions"].values():
		supports_retained = supports_retained and float(fraction_value) >= 0.90
	_check(supports_retained, "three declared support feet retain at least 90 percent contact")
	_check(
		(
			bool(active_summary["all_receipts_complete"])
			and bool(control_summary["all_receipts_complete"])
			and float(active_summary["maximum_pairing_residual_nm"]) <= 1.0e-9
			and (
				int(active_summary["active_command_count"])
				== 12 * int(active_summary["trial_ticks"])
			)
		),
		"all candidate commands remain paired and receipt-complete"
	)
	var sustained_contact_failed := (
		float(active_summary["post_touch_contact_fraction"])
		< float(experiment["minimum_post_touch_contact_fraction"])
	)
	var recovery_failed := not bool(active_summary["recovery_dwell_observed"])
	var geometry_failed := (
		(
			float(active_summary["maximum_anchor_error_m"])
			> float(experiment["maximum_anchor_error_m"])
		)
		or (
			float(active_summary["maximum_hinge_axis_error_rad"])
			> float(experiment["maximum_hinge_axis_error_rad"])
		)
	)
	_check(
		sustained_contact_failed,
		"provisional touch fails the preregistered sustained-contact quality gate"
	)
	_check(recovery_failed, "candidate fails the preregistered recovery-dwell gate")
	_check(geometry_failed, "candidate fails at least one preregistered geometry gate")
	_check(
		(
			(
				String(experiment["candidate_result"])
				== "candidate_rejected_no_clearance_quality_recovery_overlap"
			)
			and bool(experiment["full_seed_success_required"])
			and (int(experiment["rejection_witness_seed"]) == int(experiment["active_seed_set"][0]))
		),
		"sealed first-seed witness rejects the all-seed candidate without accepting BR14A.5"
	)
	_check(_summary_boundary_valid(active_summary), "summary retains every broader non-claim")
	var forged_positive := active_summary.duplicate(true)
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
		and int(summary["ordinary_preexisting_contact_count"]) == 3
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
		and bool(summary["support_margin_observations_complete"])
		and is_finite(float(summary["support_margin_at_lift_start_m"]))
		and is_finite(float(summary["support_margin_at_disturbance_m"]))
		and is_finite(float(summary["minimum_three_contact_support_margin_m"]))
		and not bool(summary["support_margin_is_load_allocation"])
	)


static func _summary_boundary_valid(summary: Dictionary) -> bool:
	return (
		not bool(summary.get("new_protective_contact_established", true))
		and not bool(summary.get("locomotor_step_established", true))
		and not bool(summary.get("free_3d_recovery_established", true))
		and not bool(summary.get("step_gait_or_walking_established", true))
		and not bool(summary.get("automatic_creature_guidance_allowed", true))
		and not bool(summary.get("contact_presence_is_bearing_measurement", true))
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
