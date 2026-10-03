extends SceneTree
# gdlint: disable=max-line-length

## BR14A.3 first actual free-3D stance experiment.
##
## The active body must dwell on four ordinary contacts without any
## world-connected scaffold. The zero-command twin must not be relabeled as
## active evidence. Passing remains commissioning, not formal acceptance.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd")
const ExperimentScript := preload(
	"res://scripts/lab/mechanics/canonical_spatial_stance_experiment.gd"
)
const RigScript := preload("res://scripts/lab/rigs/canonical_spatial_stance_rig.gd")

const PHYSICS_HZ := 120

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.3 free-3D static stance ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var profile_result := ProfileScript.compile(ProfileScript.configuration())
	var experiment_result := ExperimentScript.compile(ExperimentScript.configuration())
	_check(
		bool(profile_result.get("ok", false)) and bool(experiment_result.get("ok", false)),
		"exact selected spatial profile and preregistered physical experiment seal"
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
		var active := await rig.run_trial(self, profile, experiment, seed, true)
		var control := await rig.run_trial(self, profile, experiment, seed, false)
		if not bool(active.get("ok", false)) or not bool(control.get("ok", false)):
			printerr("  seed=", seed, " active=", active, " control=", control)
			all_complete = false
			break
		active_summaries.append(active["summary"])
		control_summaries.append(control["summary"])
		print(
			(
				(
					"  seed=%d active_dwell=%d active_height=%.6f active_tilt=%.6f "
					+ "control_dwell=%d control_height=%.6f control_tilt=%.6f"
				)
				% [
					seed,
					int(active["summary"]["longest_stable_dwell_ticks"]),
					float(active["summary"]["final_torso_height_m"]),
					float(active["summary"]["final_tilt_rad"]),
					int(control["summary"]["longest_stable_dwell_ticks"]),
					float(control["summary"]["final_torso_height_m"]),
					float(control["summary"]["final_tilt_rad"]),
				]
			)
		)
		print(
			(
				(
					"    active_anchor=%.6f axis=%.6f torque=%.6f sat=%d receipts=%s "
					+ "commands=%d contacts=%s"
				)
				% [
					float(active["summary"]["maximum_anchor_error_m"]),
					float(active["summary"]["maximum_hinge_axis_error_rad"]),
					float(active["summary"]["maximum_applied_torque_nm"]),
					int(active["summary"]["actuator_saturation_count"]),
					str(active["summary"]["all_receipts_complete"]),
					int(active["summary"]["active_command_count"]),
					str(active["summary"]["contact_fractions"]),
				]
			)
		)
	_check(all_complete, "all active/control free-3D worlds return summaries")
	if not all_complete:
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var exact_fixture := true
	var active_stance := true
	var controls_not_active := true
	var receipts := true
	var geometry := true
	var bounded_actuation := true
	var contacts := true
	var nonclaims := true
	for index in range(active_summaries.size()):
		var active: Dictionary = active_summaries[index]
		var control: Dictionary = control_summaries[index]
		exact_fixture = (
			exact_fixture
			and int(active["body_count"]) == 9
			and int(active["physical_limb_count"]) == 4
			and int(active["actuated_dof_count"]) == 12
			and int(active["joint_node_count"]) == 8
			and int(active["static_body_count"]) == 1
			and bool(active["only_static_body_is_ordinary_floor"])
			and int(active["world_anchor_count"]) == 0
			and int(active["root_pin_count"]) == 0
			and int(active["rail_count"]) == 0
			and int(active["guide_count"]) == 0
			and int(active["gimbal_count"]) == 0
			and int(active["built_in_joint_motor_count"]) == 0
			and int(active["joint_spring_count"]) == 0
			and int(active["freeze_operation_count_after_release"]) == 0
			and String(active["experiment_id"]) == String(experiment["experiment_id"])
			and String(active["experiment_sha256"]) == String(experiment["experiment_sha256"])
			and String(active["controller_id"]) == String(experiment["controller_id"])
		)
		active_stance = (
			active_stance
			and bool(active["stance_dwell_observed"])
			and int(active["longest_stable_dwell_ticks"]) >= int(active["dwell_ticks_required"])
			and float(active["final_height_error_m"]) <= float(experiment["height_error_limit_m"])
			and float(active["final_tilt_rad"]) <= float(experiment["tilt_limit_rad"])
			and (
				float(active["final_linear_speed_m_s"])
				<= float(experiment["linear_speed_limit_m_s"])
			)
			and (
				float(active["final_angular_speed_rad_s"])
				<= float(experiment["angular_speed_limit_rad_s"])
			)
			and int(active["torso_contact_ticks"]) == 0
		)
		controls_not_active = (
			controls_not_active
			and int(control["active_command_count"]) == 0
			and not bool(control["stance_dwell_observed"])
		)
		receipts = (
			receipts
			and bool(active["all_receipts_complete"])
			and float(active["maximum_pairing_residual_nm"]) <= 1.0e-9
			and int(active["active_command_count"]) == 12 * int(active["trial_ticks"])
		)
		geometry = (
			geometry
			and (
				float(active["maximum_anchor_error_m"])
				<= float(experiment["maximum_anchor_error_m"])
			)
			and (
				float(active["maximum_hinge_axis_error_rad"])
				<= float(experiment["maximum_hinge_axis_error_rad"])
			)
		)
		bounded_actuation = (
			bounded_actuation
			and (
				float(active["maximum_applied_torque_nm"])
				<= float(experiment["maximum_structural_torque_nm"])
			)
			and int(active["structural_saturation_count"]) == 0
		)
		for fraction_value in active["contact_fractions"].values():
			contacts = (
				contacts and float(fraction_value) >= float(experiment["minimum_contact_fraction"])
			)
		nonclaims = (
			nonclaims
			and not bool(active["per_contact_commands_are_measurements"])
			and not bool(active["per_foot_measured_load_allocation_available"])
			and not bool(active["free_3d_static_stance_established"])
			and not bool(active["free_3d_recovery_established"])
			and not bool(active["step_gait_or_walking_established"])
			and not bool(active["automatic_creature_guidance_allowed"])
		)
	_check(
		exact_fixture, "selected nine-body fixture has no world-connected scaffold or hidden motor"
	)
	_check(active_stance, "every active seed completes the bounded four-contact stance dwell")
	_check(
		controls_not_active, "every zero-command twin remains causally distinct from active stance"
	)
	_check(receipts, "all twelve paired torque commands per tick are receipt-complete")
	_check(geometry, "joint anchors and hinge axes remain inside strict geometry envelopes")
	_check(
		bounded_actuation,
		"applied torques remain inside the BR4 structural envelope without structural clamp"
	)
	_check(contacts, "all four semantic distal bodies retain ordinary floor contact")
	_check(
		_nonclaim_boundary(active_summaries),
		"commissioning summaries cannot self-promote the physical stance claim"
	)
	_check(
		nonclaims,
		"physical stance fixture establishes no recovery, step, gait, walking, or guidance"
	)
	var forged: Dictionary = (active_summaries[0] as Dictionary).duplicate(true)
	forged["step_gait_or_walking_established"] = true
	_check(
		not _summary_boundary_valid(forged), "forged walking conclusion fails the summary boundary"
	)
	var scaffolded: Dictionary = (active_summaries[0] as Dictionary).duplicate(true)
	scaffolded["guide_count"] = 1
	_check(
		not _summary_boundary_valid(scaffolded), "forged guide injection fails the summary boundary"
	)
	Engine.physics_ticks_per_second = original_hz
	_finish()


static func _nonclaim_boundary(summaries: Array) -> bool:
	for summary_value in summaries:
		if not _summary_boundary_valid(summary_value):
			return false
	return true


static func _summary_boundary_valid(summary: Dictionary) -> bool:
	return (
		not bool(summary.get("free_3d_static_stance_established", true))
		and not bool(summary.get("free_3d_recovery_established", true))
		and not bool(summary.get("step_gait_or_walking_established", true))
		and not bool(summary.get("automatic_creature_guidance_allowed", true))
		and int(summary.get("world_anchor_count", -1)) == 0
		and int(summary.get("root_pin_count", -1)) == 0
		and int(summary.get("rail_count", -1)) == 0
		and int(summary.get("guide_count", -1)) == 0
		and int(summary.get("gimbal_count", -1)) == 0
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
