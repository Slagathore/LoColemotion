extends SceneTree

const FactoryScript := preload("res://scripts/lab/mechanics/br12_pose_recovery_fixture_factory.gd")
const ProfileScript := preload("res://scripts/lab/mechanics/recovery_profile.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR12.2 anatomy-role recovery profile ===")
	var profile := FactoryScript.profile()
	var compiled := ProfileScript.compile(profile)
	_check(bool(compiled.get("ok", false)), "strict role-based recovery profile seals")
	_check(
		String((compiled["profile"] as Dictionary)["configuration_sha256"]).begins_with("sha256:"),
		"profile binds exact authored anatomy and phase data"
	)
	_check(
		(
			not bool(compiled["actuation_authority"])
			and not bool(compiled["automatic_creature_guidance_allowed"])
		),
		"compiled recovery profile remains planning data only"
	)
	var match := ProfileScript.match_roles(
		profile, "prone", ["front_hip", "rear_hip"], ["front_pad", "rear_pad"]
	)
	_check(
		bool(match.get("ok", false)) and bool((match["match"] as Dictionary)["feasible"]),
		"declared prone anatomy matches by semantic roles"
	)
	var missing_joint := ProfileScript.match_roles(
		profile, "prone", ["front_hip"], ["front_pad", "rear_pad"]
	)
	_check(
		(
			not bool((missing_joint["match"] as Dictionary)["feasible"])
			and (
				String((missing_joint["match"] as Dictionary)["reason"])
				== "RECOVERY_REQUIRED_JOINT_ROLE_MISSING"
			)
			and (missing_joint["match"] as Dictionary)["missing_joint_roles"] == ["rear_hip"]
		),
		"missing anatomy returns one named joint-role infeasibility"
	)
	var missing_contact := ProfileScript.match_roles(
		profile, "prone", ["front_hip", "rear_hip"], ["front_pad"]
	)
	_check(
		(
			not bool((missing_contact["match"] as Dictionary)["feasible"])
			and (
				String((missing_contact["match"] as Dictionary)["reason"])
				== "RECOVERY_CANDIDATE_CONTACT_ROLE_MISSING"
			)
		),
		"missing candidate support returns a named contact-role infeasibility"
	)
	var wrong_pose := ProfileScript.match_roles(
		profile, "supine", ["front_hip", "rear_hip"], ["front_pad", "rear_pad"]
	)
	_check(
		(
			not bool((wrong_pose["match"] as Dictionary)["feasible"])
			and (
				String((wrong_pose["match"] as Dictionary)["reason"])
				== "RECOVERY_START_POSE_UNSUPPORTED"
			)
		),
		"one prone profile cannot silently generalize to supine"
	)
	var duplicate_role := profile.duplicate(true)
	duplicate_role["required_joint_roles"] = ["front_hip", "front_hip"]
	_check(
		not bool(ProfileScript.compile(duplicate_role).get("ok", true)),
		"duplicate anatomy role fails closed"
	)
	var conflict := profile.duplicate(true)
	conflict["forbidden_contact_roles"] = ["front_pad"]
	_check(
		not bool(ProfileScript.compile(conflict).get("ok", true)),
		"candidate and forbidden contact-role overlap fails closed"
	)
	var undeclared_phase_contact := profile.duplicate(true)
	undeclared_phase_contact["phases"][0]["required_contact_roles"] = ["left_knee_pad"]
	_check(
		not bool(ProfileScript.compile(undeclared_phase_contact).get("ok", true)),
		"phase cannot use an undeclared contact role"
	)
	var guided := profile.duplicate(true)
	guided["automatic_creature_guidance_enabled"] = true
	_check(
		not bool(ProfileScript.compile(guided).get("ok", true)),
		"profile cannot authorize automatic creature guidance"
	)
	var actuating := profile.duplicate(true)
	actuating["actuation_authority"] = true
	_check(
		not bool(ProfileScript.compile(actuating).get("ok", true)),
		"profile cannot grant itself actuation authority"
	)
	var hidden_indices := profile.duplicate(true)
	hidden_indices["leg_indices"] = [0, 1]
	_check(
		not bool(ProfileScript.compile(hidden_indices).get("ok", true)),
		"hard-coded limb indices cannot bypass semantic roles"
	)
	_finish()


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
