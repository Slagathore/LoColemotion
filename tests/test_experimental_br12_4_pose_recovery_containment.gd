extends SceneTree

const AnalyzerScript := preload("res://scripts/lab/mechanics/recovery_feasibility_analyzer.gd")
const ClassifierScript := preload("res://scripts/lab/mechanics/pose_classifier.gd")
const FactoryScript := preload("res://scripts/lab/mechanics/br12_pose_recovery_fixture_factory.gd")
const OracleScript := preload("res://scripts/lab/mechanics/labeled_box_pose_oracle.gd")
const ProfileScript := preload("res://scripts/lab/mechanics/recovery_profile.gd")
const RegistryScript := preload("res://scripts/lab/mechanics/body_region_contact_role_registry.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR12.4 pose/recovery containment ===")
	var classifier := FactoryScript.classifier_configuration()
	var profile := FactoryScript.profile()
	var capabilities := FactoryScript.capabilities()
	var role_config := FactoryScript.role_configuration()
	var classified := _classify(classifier, FactoryScript.box_state("prone"))
	var classification: Dictionary = classified["classification"]
	var evaluated := AnalyzerScript.evaluate(profile, 0, "prone", capabilities)
	var report: Dictionary = evaluated["report"]
	_check(
		String(classification["pose"]) == "prone" and bool(report["feasible"]),
		"bounded positive classifier and feasibility fixtures pass"
	)
	_check(
		(
			not bool(classification["recovery_actuation_authorized"])
			and not bool(classification["automatic_creature_guidance_allowed"])
			and int(report["actuation_operation_count"]) == 0
			and not bool(report["getting_up_established"])
		),
		"positive outputs retain the observation-only, no-get-up boundary"
	)
	var hidden_pose_claim := classifier.duplicate(true)
	hidden_pose_claim["getting_up_established"] = true
	_check(
		not bool(ClassifierScript.build_configuration(hidden_pose_claim).get("ok", true)),
		"hidden get-up classifier claim fails closed"
	)
	var hidden_profile_controller := profile.duplicate(true)
	hidden_profile_controller["controller_enabled"] = true
	_check(
		not bool(ProfileScript.compile(hidden_profile_controller).get("ok", true)),
		"hidden recovery controller field fails closed"
	)
	var guided_role_registry := role_config.duplicate(true)
	guided_role_registry["automatic_creature_guidance_enabled"] = true
	_check(
		not bool(RegistryScript.build_configuration(guided_role_registry).get("ok", true)),
		"semantic role registry cannot authorize guidance"
	)
	var claimed_contact := role_config.duplicate(true)
	claimed_contact["contact_creation_authority"] = true
	_check(
		not bool(RegistryScript.build_configuration(claimed_contact).get("ok", true)),
		"semantic role registry cannot create recovery support"
	)
	var unknown_schema_observation := (
		(OracleScript.observe(FactoryScript.box_state("prone"))["observation"] as Dictionary)
		. duplicate(true)
	)
	unknown_schema_observation["schema_version"] = "creature_pose_truth_v99"
	var unknown_schema := ClassifierScript.classify(classifier, unknown_schema_observation)
	_check(
		(
			String((unknown_schema["classification"] as Dictionary)["pose"]) == "unknown"
			and not bool((unknown_schema["classification"] as Dictionary)["sensor_valid"])
		),
		"unknown observation schema fails to UNKNOWN without permissive fallback"
	)
	var ambiguous := _classify(classifier, FactoryScript.box_state("ambiguous_prone_left"))
	_check(
		String((ambiguous["classification"] as Dictionary)["pose"]) == "unknown",
		"ambiguous pose cannot be promoted to a recovery start pose"
	)
	var missing_roles := ProfileScript.match_roles(profile, "prone", ["front_hip"], ["front_pad"])
	_check(
		not bool((missing_roles["match"] as Dictionary)["feasible"]),
		"missing anatomy remains a named infeasible result"
	)
	var underpowered := capabilities.duplicate(true)
	underpowered["joint_capacities"]["front_hip"]["maximum_active_torque_nm"] = 5.0
	var rejected := AnalyzerScript.evaluate(profile, 0, "prone", underpowered)
	_check(
		(
			not bool((rejected["report"] as Dictionary)["feasible"])
			and int((rejected["report"] as Dictionary)["actuation_operation_count"]) == 0
		),
		"underpowered phase cannot execute before rejection"
	)
	var assisted := capabilities.duplicate(true)
	assisted["external_assistance_enabled"] = true
	_check(
		not bool(AnalyzerScript.evaluate(profile, 0, "prone", assisted).get("ok", true)),
		"root or scaffold assistance cannot hide inside feasibility"
	)
	var guided := capabilities.duplicate(true)
	guided["automatic_creature_guidance_enabled"] = true
	_check(
		not bool(AnalyzerScript.evaluate(profile, 0, "prone", guided).get("ok", true)),
		"feasibility cannot unlock automatic creature guidance"
	)
	_check(
		(
			not report.has("controller_command")
			and not report.has("desired_wrench")
			and not report.has("joint_targets_rad")
		),
		"feasibility report exposes no command or wrench channel"
	)
	_check(
		(
			String(report["schema_version"]) == "recovery_static_feasibility_report_v1"
			and not bool(report["getting_up_established"])
		),
		"BR12 conclusion remains feasibility-only rather than getting up"
	)
	_finish()


func _classify(config: Dictionary, state: Dictionary) -> Dictionary:
	var observed := OracleScript.observe(state)
	if not bool(observed.get("ok", false)):
		return observed
	return ClassifierScript.classify(config, observed["observation"])


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
