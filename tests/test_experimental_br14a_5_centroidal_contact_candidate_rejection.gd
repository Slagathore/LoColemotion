extends SceneTree
# gdlint: disable=max-line-length

## BR14A.5 early-stop rejection witness for the second free-3D
## new-protective-contact controller candidate.
##
## The resolved-rate swing map is a real improvement: the exact candidate
## clears the selected foot, survives to the matched disturbance, and creates
## one provisional ordinary-floor retouch. The same first-seed run still fails
## dynamic support, target quality, sustained contact, joint geometry, and
## recovery. Since the sealed candidate required every seed to pass, this one
## witness rejects only this exact controller candidate.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_centroidal_contact_candidate.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")

const PHYSICS_HZ := 120

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.5 centroidal-contact candidate rejection ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var experiment_result := ExperimentScript.compile(ExperimentScript.configuration())
	_check(
		bool(profile_result.get("ok", false)) and bool(experiment_result.get("ok", false)),
		"exact spatial profile and second-candidate rejection contract seal"
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
		not bool(result.get("ok", true)) and result.has("summary"),
		"full-horizon run fails closed with a diagnostic summary"
	)
	if not result.has("summary"):
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var summary: Dictionary = result["summary"]
	print(
		(
			(
				"  seed=%d executed=%d failure=%s clear=%d touch=%d error=%.6f "
				+ "post_contact=%.6f dwell=%d com_min=%.6f capture_min=%.6f "
				+ "anchor=%.6f hinge=%.6f torque=%.6f"
			)
			% [
				seed,
				int(summary["executed_ticks"]),
				String(summary["fixture_failure_code"]),
				int(summary["swing_clear_ticks_before_disturbance"]),
				int(summary["first_touch_tick"]),
				float(summary["first_touch_target_error_m"]),
				float(summary["post_touch_contact_fraction"]),
				int(summary["longest_recovery_dwell_ticks"]),
				float(summary["minimum_three_contact_com_margin_m"]),
				float(summary["minimum_three_contact_capture_margin_m"]),
				float(summary["maximum_anchor_error_m"]),
				float(summary["maximum_hinge_axis_error_rad"]),
				float(summary["maximum_applied_torque_nm"]),
			]
		)
	)
	_check(
		(
			String(summary["fixture_failure_code"]) == "SPATIAL_DYNAMIC_SUPPORT_COM_HEIGHT_INVALID"
			and int(summary["executed_ticks"]) > int(experiment["touchdown_deadline_tick"])
			and int(summary["executed_ticks"]) < int(experiment["trial_ticks"])
		),
		"observer rejects the later inverted COM/support state before the planned horizon"
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
		"measured lift-entry dynamic-support gate is genuinely established"
	)
	_check(
		(
			int(summary["swing_clear_ticks_before_disturbance"])
			>= int(experiment["minimum_pre_disturbance_clear_ticks"])
		),
		"resolved-rate candidate physically clears the selected foot before disturbance"
	)
	_check(
		(
			int(summary["disturbance_operation_count"]) == 1
			and not bool(summary["disturbance_is_controller_operation"])
		),
		"one declared noncontroller roll impulse is applied"
	)
	_check(
		(
			bool(summary["touchdown_before_deadline"])
			and int(summary["new_contact_creation_count"]) == 1
		),
		"candidate creates one provisional ordinary-floor retouch before deadline"
	)
	_check(
		(
			float(summary["first_touch_target_error_m"])
			> float(experiment["maximum_touchdown_target_error_m"])
		),
		"provisional retouch fails the preregistered target-error gate"
	)
	_check(
		(
			float(summary["post_touch_contact_fraction"])
			< float(experiment["minimum_post_touch_contact_fraction"])
		),
		"provisional retouch fails the sustained-contact gate"
	)
	_check(
		(
			(
				float(summary["minimum_three_contact_com_margin_m"])
				< float(experiment["minimum_three_contact_com_margin_m"])
			)
			and (
				float(summary["minimum_three_contact_capture_margin_m"])
				< float(experiment["minimum_three_contact_capture_margin_m"])
			)
		),
		"candidate fails both preregistered dynamic-support margins"
	)
	_check(
		(
			float(summary["maximum_anchor_error_m"]) > float(experiment["maximum_anchor_error_m"])
			and (
				float(summary["maximum_hinge_axis_error_rad"])
				> float(experiment["maximum_hinge_axis_error_rad"])
			)
		),
		"candidate fails both preregistered joint-geometry gates"
	)
	_check(
		not bool(summary["recovery_dwell_observed"]),
		"candidate fails the preregistered recovery-dwell gate"
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
			not bool(summary["support_allocator_used"])
			and int(summary["support_controller_command_count"]) > 0
			and not bool(summary["per_contact_commands_are_measurements"])
			and not bool(summary["per_foot_measured_load_allocation_available"])
		),
		"endpoint controller is not mislabeled as allocator or load measurement"
	)
	_check(
		(
			int(summary["structural_saturation_count"]) == 0
			and (
				float(summary["maximum_applied_torque_nm"])
				<= float(experiment["maximum_structural_torque_nm"]) + 1.0e-6
			)
		),
		"rejection occurs without crossing the structural torque guard"
	)
	_check(
		(
			(
				String(experiment["candidate_result"])
				== "candidate_rejected_dynamic_support_geometry_recovery_no_overlap"
			)
			and bool(experiment["full_seed_success_required"])
			and seed == int(experiment["active_seed_set"][0])
		),
		"sealed first-seed witness rejects only the exact all-seed candidate"
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
