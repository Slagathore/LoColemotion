extends SceneTree

## BR13.0 exact profile, pose observation, and successful phase order.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_get_up_profile.gd")
const PoseScript := preload("res://scripts/lab/mechanics/quadruped_recovery_pose_observer.gd")
const SupervisorScript := preload("res://scripts/lab/mechanics/recovery_phase_supervisor.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Experimental BR13.0 constrained get-up phase order ===")
	var profile_result := ProfileScript.compile(_profile())
	_check(bool(profile_result.get("ok", false)), "one exact symmetry-collapsed profile seals")
	if not bool(profile_result.get("ok", false)):
		_finish()
		return
	var profile: Dictionary = profile_result["profile"]
	_check(
		String(profile["positive_claim"]) == "constrained_planar_get_up",
		"profile exposes only the bounded positive claim"
	)
	_check(
		String(profile["start_pose"]) == "prone" and String(profile["terminal_pose"]) == "stance",
		"profile pins one start and one terminal pose"
	)
	_check(
		(
			(profile["represented_limb_pairs"] as Array).size() == 2
			and bool(profile["matched_zero_command_control_required"])
		),
		"mirrored-pair collapse and matched control remain explicit"
	)

	var pose_configuration := _pose_configuration()
	_check(bool(PoseScript.build(pose_configuration).get("ok", false)), "pose observer seals")
	var prone := PoseScript.observe(
		pose_configuration, _pose_input(0, 0.20, true, false, false, 0.0, 0.0)
	)
	_check(
		String(prone["observation"]["state"]) == "PRONE",
		"ventral low support is observed as canonical quadruped prone"
	)
	var transition := PoseScript.observe(
		pose_configuration, _pose_input(1, 0.58, false, true, true, 0.30, 0.20)
	)
	_check(
		String(transition["observation"]["state"]) == "TRANSITION",
		"partial unstable rise remains transition rather than guessed stance"
	)
	var stance := PoseScript.observe(
		pose_configuration, _pose_input(2, 0.82, false, true, true, 0.01, 0.01)
	)
	_check(
		String(stance["observation"]["state"]) == "STANCE",
		"high stable two-pair support is observed as stance"
	)
	var bad_sensor_input := _pose_input(3, 0.20, true, false, false, 0.0, 0.0)
	bad_sensor_input["sensor_valid"] = false
	var unknown := PoseScript.observe(pose_configuration, bad_sensor_input)
	_check(
		String(unknown["observation"]["state"]) == "UNKNOWN",
		"unavailable pose evidence remains unknown"
	)

	var supervisor = SupervisorScript.new()
	_check(
		bool(supervisor.configure(_supervisor_configuration()).get("ok", false)),
		"observation-only recovery supervisor configures"
	)
	var phases: Array[String] = []
	phases.append(String(supervisor.observe(_phase_input(0, "PRONE", 0.20))["phase"]))
	phases.append(String(supervisor.observe(_phase_input(1, "PRONE", 0.20))["phase"]))
	var contact_input := _phase_input(2, "TRANSITION", 0.30)
	contact_input["front_pair_bearing"] = true
	contact_input["rear_pair_bearing"] = true
	contact_input["recovery_controller_active"] = true
	phases.append(String(supervisor.observe(contact_input)["phase"]))
	var rise_input := contact_input.duplicate(true)
	rise_input["tick"] = 3
	rise_input["height_ratio"] = 0.82
	phases.append(String(supervisor.observe(rise_input)["phase"]))
	var handoff_input := _phase_input(4, "STANCE", 0.82)
	handoff_input["front_pair_bearing"] = true
	handoff_input["rear_pair_bearing"] = true
	handoff_input["stance_controller_active"] = true
	phases.append(String(supervisor.observe(handoff_input)["phase"]))
	var dwell_input := handoff_input.duplicate(true)
	dwell_input["tick"] = 5
	phases.append(String(supervisor.observe(dwell_input)["phase"]))
	dwell_input["tick"] = 6
	var complete: Dictionary = supervisor.observe(dwell_input)
	phases.append(String(complete["phase"]))
	_check(
		(
			phases
			== [
				"CONFIRM_PRONE",
				"ESTABLISH_DISTAL_CONTACT",
				"RAISE_BODY",
				"STANCE_HANDOFF",
				"STANCE_DWELL",
				"STANCE_DWELL",
				"COMPLETE",
			]
		),
		"every successful phase follows the preregistered order"
	)
	_check(
		not bool(complete["recovery_controller_may_be_active"]),
		"completed stance leaves the recovery controller inactive"
	)
	_check(
		(
			bool(complete["stance_controller_may_be_active"])
			and not bool(complete["force_authority"])
			and not bool(complete["torque_authority"])
		),
		"stance handoff retains controller separation and no supervisor actuation"
	)
	_check(
		not bool(complete["automatic_creature_guidance_allowed"]),
		"phase success grants no automatic creature guidance"
	)
	_finish()


static func _profile() -> Dictionary:
	return {
		"schema_version": "canonical_get_up_profile_v1",
		"profile_id": "canonical_symmetry_collapsed_quadruped_prone_v1",
		"start_pose": "prone",
		"terminal_pose": "stance",
		"recovery_plane": "sagittal_xy",
		"represented_limb_pairs": ["front_pair", "rear_pair"],
		"legal_intermediate_contact_roles":
		["ventral_body", "front_pair_distal", "rear_pair_distal"],
		"steady_stance_contact_roles": ["front_pair_distal", "rear_pair_distal"],
		"forbidden_contact_roles": ["head", "dorsal_body"],
		"guide_locked_dofs": ["out_of_plane_translation_z", "roll_x", "yaw_y"],
		"ordinary_unilateral_ground_contacts": true,
		"matched_zero_command_control_required": true,
		"seed_set": [13001, 13002, 13003],
		"positive_claim": "constrained_planar_get_up",
		"morphology_generalization_allowed": false,
		"free_3d_recovery_claim_allowed": false,
		"gait_claim_allowed": false,
		"walking_claim_allowed": false,
		"automatic_creature_guidance_allowed": false,
	}


static func _pose_configuration() -> Dictionary:
	return {
		"schema_version": "quadruped_recovery_pose_configuration_v1",
		"prone_height_ratio_max": 0.35,
		"stance_height_ratio_min": 0.75,
		"stable_linear_speed_m_s": 0.05,
		"stable_angular_speed_rad_s": 0.05,
		"automatic_creature_guidance_allowed": false,
	}


static func _pose_input(
	tick: int,
	height_ratio: float,
	ventral: bool,
	front: bool,
	rear: bool,
	linear_speed: float,
	angular_speed: float
) -> Dictionary:
	return {
		"schema_version": "quadruped_recovery_pose_observation_v1",
		"tick": tick,
		"torso_height_m": height_ratio,
		"reference_stance_height_m": 1.0,
		"linear_speed_m_s": linear_speed,
		"angular_speed_rad_s": angular_speed,
		"ventral_contact": ventral,
		"front_pair_bearing": front,
		"rear_pair_bearing": rear,
		"forbidden_contact_roles": [],
		"sensor_valid": true,
	}


static func _supervisor_configuration() -> Dictionary:
	return {
		"schema_version": "recovery_phase_supervisor_v1",
		"supervisor_id": "br13_canonical_prone_get_up",
		"prone_confirm_ticks": 2,
		"stance_dwell_ticks": 3,
		"rise_height_ratio_min": 0.75,
		"phase_timeout_ticks":
		{
			"CONFIRM_PRONE": 10,
			"ESTABLISH_DISTAL_CONTACT": 10,
			"RAISE_BODY": 10,
			"STANCE_HANDOFF": 10,
			"STANCE_DWELL": 10,
		},
		"automatic_creature_guidance_allowed": false,
	}


static func _phase_input(tick: int, pose: String, height_ratio: float) -> Dictionary:
	return {
		"schema_version": "recovery_phase_observation_v1",
		"tick": tick,
		"pose_state": pose,
		"height_ratio": height_ratio,
		"front_pair_bearing": false,
		"rear_pair_bearing": false,
		"energy_gate_passed": true,
		"actuator_reserve_passed": true,
		"forbidden_contact_observed": false,
		"recovery_controller_active": false,
		"stance_controller_active": false,
	}


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
