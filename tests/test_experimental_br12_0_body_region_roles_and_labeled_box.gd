extends SceneTree

const FactoryScript := preload("res://scripts/lab/mechanics/br12_pose_recovery_fixture_factory.gd")
const OracleScript := preload("res://scripts/lab/mechanics/labeled_box_pose_oracle.gd")
const RegistryScript := preload("res://scripts/lab/mechanics/body_region_contact_role_registry.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR12.0 semantic body roles and labeled-box oracle ===")
	var config := FactoryScript.role_configuration()
	var compiled := RegistryScript.build_configuration(config)
	_check(bool(compiled.get("ok", false)), "strict semantic body-region registry seals")
	_check(
		String((compiled["configuration"] as Dictionary)["configuration_sha256"]).begins_with(
			"sha256:"
		),
		"registry carries one canonical configuration digest"
	)
	var observed := RegistryScript.observe_roles(config, ["ventral_body", "front_pad", "rear_pad"])
	_check(bool(observed.get("ok", false)), "known observed recovery roles classify")
	var roles: Array = observed.get("observed_roles", [])
	_check(
		(
			roles.size() == 3
			and String((roles[0] as Dictionary)["role_id"]) == "front_pad"
			and String((roles[1] as Dictionary)["role_id"]) == "rear_pad"
			and String((roles[2] as Dictionary)["role_id"]) == "ventral_body"
		),
		"observed roles are unique and deterministically ordered"
	)
	_check(
		(
			bool((roles[2] as Dictionary)["may_bear_recovery_load"])
			and not bool((roles[2] as Dictionary)["allowed_steady_stance"])
		),
		"ventral body may be temporary recovery support without becoming stance evidence"
	)
	_check(
		(
			not bool(observed["contact_creation_authority"])
			and not bool(observed["automatic_creature_guidance_allowed"])
		),
		"role observation grants no contact creation or guidance authority"
	)
	_check(
		not bool(RegistryScript.observe_roles(config, ["unknown_region"]).get("ok", true)),
		"unknown observed role fails closed"
	)
	_check(
		not bool(RegistryScript.observe_roles(config, ["front_pad", "front_pad"]).get("ok", true)),
		"duplicate observed role fails closed"
	)
	var guided := config.duplicate(true)
	guided["automatic_creature_guidance_enabled"] = true
	_check(
		not bool(RegistryScript.build_configuration(guided).get("ok", true)),
		"registry cannot grant automatic guidance"
	)
	var contact_authority := config.duplicate(true)
	contact_authority["contact_creation_authority"] = true
	_check(
		not bool(RegistryScript.build_configuration(contact_authority).get("ok", true)),
		"registry cannot manufacture contact authority"
	)
	for pose in ["upright", "prone", "supine", "left_side", "right_side"]:
		var oracle := OracleScript.observe(FactoryScript.box_state(pose))
		_check(bool(oracle.get("ok", false)), "labeled box observes canonical %s basis" % pose)
	var prone := OracleScript.observe(FactoryScript.box_state("prone"))["observation"] as Dictionary
	_check(
		(prone["anatomical_forward_world"] as Vector3).dot(Vector3.UP) < -0.99999,
		"authored -Z forward axis points down in the prone sign oracle"
	)
	var supine := (
		OracleScript.observe(FactoryScript.box_state("supine"))["observation"] as Dictionary
	)
	_check(
		(supine["anatomical_forward_world"] as Vector3).dot(Vector3.UP) > 0.99999,
		"authored -Z forward axis points up in the supine sign oracle"
	)
	var scaled := FactoryScript.box_state("upright")
	scaled["basis"] = Basis.from_scale(Vector3(1.0, 2.0, 1.0))
	_check(
		not bool(OracleScript.observe(scaled).get("ok", true)),
		"scaled non-orthonormal basis fails before axis classification"
	)
	var hidden := FactoryScript.box_state("upright")
	hidden["claimed_pose"] = "upright"
	_check(
		not bool(OracleScript.observe(hidden).get("ok", true)),
		"caller-supplied pose label cannot enter oracle evidence"
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
