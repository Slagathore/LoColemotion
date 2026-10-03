extends SceneTree
# gdlint: disable=max-line-length

## BR14A.5 early-stop rejection witness for the third free-3D
## new-protective-contact controller candidate.
##
## Candidate 3 adds a real whole-system wrench allocator, a preferred
## four-to-three contact transition, and an actually executed
## vertical-then-horizontal swing path. The first required seed still fails
## closed at physical swing-contact loss: even with every feedback authority
## projected to zero, the current three-contact geometry would require one
## contact normal above its pinned capacity.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_wrench_contact_candidate.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd")

const PHYSICS_HZ := 120

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.5 spatial-wrench candidate rejection ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var experiment_result := ExperimentScript.compile(ExperimentScript.configuration())
	_check(
		bool(profile_result.get("ok", false)) and bool(experiment_result.get("ok", false)),
		"exact spatial profile and third-candidate rejection contract seal"
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
		"physical run fails closed with a diagnostic summary"
	)
	if not result.has("summary"):
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var summary: Dictionary = result["summary"]
	print(
		(
			(
				"  seed=%d executed=%d failure=%s allocator=%d attempts=%d "
				+ "authority=%.2f reserve=%.6f com_min=%.6f capture_min=%.6f "
				+ "anchor=%.6f hinge=%.6f torque=%.6f"
			)
			% [
				seed,
				int(summary["executed_ticks"]),
				String(summary["fixture_failure_code"]),
				int(summary["support_allocator_command_count"]),
				int(summary["support_allocator_solve_attempt_count"]),
				float(summary["last_support_allocator_authority_scale"]),
				float(summary["minimum_support_allocator_normal_reserve_n"]),
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
			String(summary["fixture_failure_code"]) == "SPATIAL_CENTROIDAL_ALLOCATOR_INFEASIBLE"
			and int(summary["executed_ticks"]) > int(experiment["lift_start_tick"])
			and int(summary["executed_ticks"]) < int(experiment["disturbance_tick"])
		),
		"allocator refuses the pre-disturbance swing-contact transition"
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
			String(experiment["swing_lift_path_policy"]) == "vertical_then_horizontal_smoothstep_v1"
			and int(experiment["vertical_lift_complete_tick"]) == 780
		),
		"candidate executes its sealed staged-clearance path"
	)
	_check(
		(
			bool(summary["support_allocator_used"])
			and int(summary["support_allocator_command_count"]) > 0
			and int(summary["support_allocator_infeasible_count"]) == 1
			and float(summary["last_support_allocator_authority_scale"]) < 0.0
		),
		"whole-system allocator exhausts the sealed authority projection and fails closed"
	)
	_check(
		(
			float(summary["maximum_support_allocator_force_residual_n"]) <= 1.0e-5
			and float(summary["maximum_support_allocator_moment_residual_nm"]) <= 1.0e-5
		),
		"every solved allocator command closes its requested force and roll-pitch moment"
	)
	var infeasibility_reasons: Array = summary["last_support_allocator_infeasibility_reasons"]
	_check(
		(
			"NORMAL_ABOVE_MAXIMUM:rear_right.foot" in infeasibility_reasons
			and float(summary["minimum_support_allocator_normal_reserve_n"]) < 0.0
		),
		"zero-feedback three-contact equilibrium exceeds the rear-right normal cap"
	)
	var rear_right_command: Dictionary = summary["last_support_allocator_contact_commands"]["rear_right.foot"]
	_check(
		(
			(
				float(rear_right_command["normal_force_command_n"])
				> float(profile["contact_normal_capacity_n"])
			)
			and bool(rear_right_command["command_not_measurement"])
		),
		"rejected rear-right value is an over-cap command, never a measured foot load"
	)
	_check(
		(
			float(summary["minimum_three_contact_capture_margin_m"])
			< float(experiment["minimum_three_contact_capture_margin_m"])
		),
		"tick-scheduled lift loses the preregistered dynamic capture margin before clearance"
	)
	_check(
		(
			int(summary["swing_clear_ticks_before_disturbance"]) == 0
			and int(summary["disturbance_operation_count"]) == 0
			and int(summary["new_contact_creation_count"]) == 0
		),
		"rejection precedes clearance evidence, disturbance, and any new contact"
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
		"rejection occurs without crossing the structural torque guard"
	)
	_check(
		(
			not bool(summary["per_contact_commands_are_measurements"])
			and not bool(summary["per_foot_measured_load_allocation_available"])
			and not bool(summary["contact_presence_is_bearing_measurement"])
		),
		"allocator commands grant no per-foot load or bearing measurement"
	)
	_check(
		(
			(
				String(experiment["candidate_result"])
				== "candidate_rejected_contact_transition_wrench_infeasible"
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
