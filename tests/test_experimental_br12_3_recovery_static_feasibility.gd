extends SceneTree

const AnalyzerScript := preload("res://scripts/lab/mechanics/recovery_feasibility_analyzer.gd")
const FactoryScript := preload("res://scripts/lab/mechanics/br12_pose_recovery_fixture_factory.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR12.3 conservative recovery feasibility ===")
	var profile := FactoryScript.profile()
	var capabilities := FactoryScript.capabilities()
	var baseline := AnalyzerScript.evaluate(profile, 0, "prone", capabilities)
	_check(bool(baseline.get("ok", false)), "complete static feasibility report builds")
	var report: Dictionary = baseline["report"]
	_check(
		bool(report["feasible"]) and String(report["reason"]).is_empty(),
		"baseline phase is feasible"
	)
	var minima: Dictionary = report["diagnostics"]["minimum_margins"]
	_check(
		(
			float(minima["torque_reserve_fraction"]) >= 0.2
			and float(minima["power_reserve_fraction"]) >= 0.0
			and float(minima["structural_reserve_fraction"]) >= 0.1
			and float(minima["friction_reserve_fraction"]) >= 0.0
		),
		"torque, power, structural, and friction reserves remain explicit"
	)
	_check(
		(
			bool(report["evaluation_before_actuation"])
			and int(report["actuation_operation_count"]) == 0
			and not bool(report["getting_up_established"])
			and not bool(report["automatic_creature_guidance_allowed"])
		),
		"positive feasibility remains pre-actuation and proves no get-up"
	)
	var weak_torque := capabilities.duplicate(true)
	weak_torque["joint_capacities"]["front_hip"]["maximum_active_torque_nm"] = 11.0
	_check_reason(profile, weak_torque, "RECOVERY_STATIC_TORQUE_INSUFFICIENT")
	var weak_power := capabilities.duplicate(true)
	weak_power["joint_capacities"]["rear_hip"]["maximum_power_w"] = 3.0
	_check_reason(profile, weak_power, "RECOVERY_POWER_INSUFFICIENT")
	var weak_structure := capabilities.duplicate(true)
	weak_structure["joint_capacities"]["rear_hip"]["structural_torque_nm"] = 12.5
	_check_reason(profile, weak_structure, "RECOVERY_STRUCTURAL_MARGIN_INSUFFICIENT")
	var weak_friction := capabilities.duplicate(true)
	weak_friction["contact_friction_coefficients"]["front_pad"] = 0.3
	_check_reason(profile, weak_friction, "RECOVERY_FRICTION_INSUFFICIENT")
	var unreachable := capabilities.duplicate(true)
	unreachable["reachable_contact_roles"] = ["rear_pad"]
	_check_reason(profile, unreachable, "RECOVERY_CONTACT_UNREACHABLE")
	var missing_capacity := capabilities.duplicate(true)
	missing_capacity["joint_capacities"].erase("rear_hip")
	_check_reason(profile, missing_capacity, "RECOVERY_JOINT_CAPACITY_MISSING")
	var missing_anatomy := capabilities.duplicate(true)
	missing_anatomy["available_joint_roles"] = ["front_hip"]
	_check_reason(profile, missing_anatomy, "RECOVERY_REQUIRED_JOINT_ROLE_MISSING")
	var assisted := capabilities.duplicate(true)
	assisted["external_assistance_enabled"] = true
	_check(
		not bool(AnalyzerScript.evaluate(profile, 0, "prone", assisted).get("ok", true)),
		"external assistance cannot enter a feasibility report"
	)
	var guided := capabilities.duplicate(true)
	guided["automatic_creature_guidance_enabled"] = true
	_check(
		not bool(AnalyzerScript.evaluate(profile, 0, "prone", guided).get("ok", true)),
		"automatic guidance cannot enter a feasibility report"
	)
	var nonfinite := capabilities.duplicate(true)
	nonfinite["joint_capacities"]["front_hip"]["maximum_power_w"] = NAN
	_check_reason(profile, nonfinite, "RECOVERY_JOINT_CAPACITY_MISSING")
	_check(
		not bool(AnalyzerScript.evaluate(profile, 2, "prone", capabilities).get("ok", true)),
		"unknown phase index fails before evaluation"
	)
	_finish()


func _check_reason(profile: Dictionary, capabilities: Dictionary, expected: String) -> void:
	var result := AnalyzerScript.evaluate(profile, 0, "prone", capabilities)
	var report: Dictionary = result.get("report", {})
	_check(
		(
			bool(result.get("ok", false))
			and not bool(report.get("feasible", true))
			and String(report.get("reason", "")) == expected
			and int(report.get("actuation_operation_count", -1)) == 0
		),
		"obviously infeasible phase rejects before actuation: %s" % expected
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
