extends SceneTree

## BR13.3 adversarial containment for the prephysical get-up boundary.

const ProfileScript := preload("res://scripts/lab/mechanics/canonical_get_up_profile.gd")
const PoseScript := preload("res://scripts/lab/mechanics/quadruped_recovery_pose_observer.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Experimental BR13.3 canonical get-up containment ===")
	var baseline := _profile()
	var built := ProfileScript.compile(baseline)
	_check(bool(built.get("ok", false)), "exact bounded profile seals")
	if not bool(built.get("ok", false)):
		_finish()
		return
	var profile: Dictionary = built["profile"]
	_check(
		String(profile["claim_boundary"]) == ProfileScript.CLAIM_BOUNDARY,
		"verbatim claim boundary travels with the profile"
	)
	_check(
		(
			not bool(profile["physical_execution_authorized"])
			and not bool(profile["morphology_generalization_allowed"])
		),
		"profile commissioning authorizes neither execution nor transfer"
	)
	_check(
		(
			not bool(profile["free_3d_recovery_claim_allowed"])
			and not bool(profile["gait_claim_allowed"])
			and not bool(profile["walking_claim_allowed"])
			and not bool(profile["automatic_creature_guidance_allowed"])
		),
		"free 3D, gait, walking, and guidance claims remain false"
	)

	_check_rejected(_mutated(baseline, "positive_claim", "getting_up"), "broader claim")
	_check_rejected(
		_mutated(baseline, "morphology_generalization_allowed", true), "morphology generalization"
	)
	_check_rejected(_mutated(baseline, "free_3d_recovery_claim_allowed", true), "free 3D recovery")
	_check_rejected(
		_mutated(baseline, "automatic_creature_guidance_allowed", true), "automatic guidance"
	)
	_check_rejected(
		_mutated(baseline, "matched_zero_command_control_required", false),
		"missing matched control"
	)
	_check_rejected(
		_mutated(baseline, "ordinary_unilateral_ground_contacts", false),
		"nonordinary contact authority"
	)
	_check_rejected(
		_mutated(baseline, "guide_locked_dofs", ["out_of_plane_translation_z"]),
		"hidden scaffold weakening"
	)
	_check_rejected(
		_mutated(baseline, "represented_limb_pairs", ["front_pair", "rear_pair", "tail_pair"]),
		"undeclared anatomy"
	)
	_check_rejected(
		_mutated(
			baseline,
			"legal_intermediate_contact_roles",
			["ventral_body", "front_pair_distal", "rear_pair_distal", "head"]
		),
		"forbidden head contact"
	)
	_check_rejected(_mutated(baseline, "seed_set", [13001, 13001]), "duplicate seed")
	var hidden := baseline.duplicate(true)
	hidden["root_rescue_allowed"] = true
	_check_rejected(hidden, "hidden root rescue field")

	var pose_configuration := _pose_configuration()
	var forbidden_observation := _pose_input()
	forbidden_observation["forbidden_contact_roles"] = ["head"]
	var forbidden := PoseScript.observe(pose_configuration, forbidden_observation)
	_check(
		String(forbidden["observation"]["state"]) == "UNKNOWN",
		"forbidden contact cannot be interpreted as prone or stance"
	)
	_check(
		(
			not bool(forbidden["observation"]["force_authority"])
			and not bool(forbidden["observation"]["automatic_creature_guidance_allowed"])
		),
		"observer retains no mutation or guidance authority"
	)
	_finish()


func _check_rejected(value: Dictionary, label: String) -> void:
	_check(not bool(ProfileScript.compile(value).get("ok", true)), "%s fails closed" % label)


static func _mutated(source: Dictionary, field: String, value: Variant) -> Dictionary:
	var result := source.duplicate(true)
	result[field] = value
	return result


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


static func _pose_input() -> Dictionary:
	return {
		"schema_version": "quadruped_recovery_pose_observation_v1",
		"tick": 0,
		"torso_height_m": 0.2,
		"reference_stance_height_m": 1.0,
		"linear_speed_m_s": 0.0,
		"angular_speed_rad_s": 0.0,
		"ventral_contact": true,
		"front_pair_bearing": false,
		"rear_pair_bearing": false,
		"forbidden_contact_roles": [],
		"sensor_valid": true,
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
