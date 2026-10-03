extends SceneTree

## BR13.2 static reserve preflight and dynamic energy-ledger containment.

const EnergyScript := preload("res://scripts/lab/mechanics/recovery_energy_ledger.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	print("=== Experimental BR13.2 recovery energy gate ===")
	var configuration := _configuration()
	_check(bool(EnergyScript.build(configuration).get("ok", false)), "energy ledger seals")
	var feasible := EnergyScript.preflight(configuration, _preflight())
	_check(bool(feasible.get("ok", false)), "finite preflight evaluates")
	_check(bool(feasible["report"]["feasible"]), "declared actuator envelope is feasible")
	_check(
		is_equal_approx(float(feasible["report"]["required_potential_gain_j"]), 49.0),
		"required potential gain is mass times gravity times height"
	)
	_check(
		(
			float(feasible["report"]["torque_reserve_fraction"]) == 0.5
			and float(feasible["report"]["power_reserve_fraction"]) == 0.5
			and float(feasible["report"]["structural_reserve_fraction"]) == 0.5
		),
		"torque, power, and structure retain explicit reserves"
	)
	_check(
		(
			not bool(feasible["report"]["actuation_authority"])
			and not bool(feasible["report"]["automatic_creature_guidance_allowed"])
		),
		"feasibility report grants no actuation or guidance"
	)

	var underworked := _preflight()
	underworked["available_positive_work_j"] = 48.0
	var underworked_report: Dictionary = (
		EnergyScript.preflight(configuration, underworked)["report"]
	)
	_check(not bool(underworked_report["feasible"]), "underpowered work budget rejects")
	_check(
		"RECOVERY_POSITIVE_WORK_CAPACITY_INSUFFICIENT" in underworked_report["failure_codes"],
		"underpowered rejection names the positive-work constraint"
	)

	var under_torque := _preflight()
	under_torque["available_peak_torque_nm"] = 24.0
	var torque_report: Dictionary = EnergyScript.preflight(configuration, under_torque)["report"]
	_check(not bool(torque_report["feasible"]), "insufficient torque reserve rejects")
	_check(
		"RECOVERY_TORQUE_RESERVE_INSUFFICIENT" in torque_report["failure_codes"],
		"torque reserve has a stable failure code"
	)

	var reconciled := EnergyScript.reconcile(configuration, _trace())
	_check(bool(reconciled.get("ok", false)), "finite trace reconciles")
	_check(bool(reconciled["report"]["accepted"]), "balanced raised-body trace is accepted")
	_check(
		absf(float(reconciled["report"]["energy_balance_residual_j"])) <= 1.0e-9,
		"actuator, guide, contact, and mechanical energy close exactly"
	)
	_check(
		(
			not bool(reconciled["report"]["guide_work_is_measured"])
			and bool(reconciled["report"]["guide_work_is_residual_inferred"])
		),
		"guide work remains explicitly residual-inferred"
	)
	_check(
		(
			not bool(reconciled["report"]["free_3d_recovery_established"])
			and not bool(reconciled["report"]["automatic_creature_guidance_allowed"])
		),
		"energy closure establishes neither free 3D recovery nor guidance"
	)

	var guide_assisted := _trace()
	guide_assisted["inferred_guide_work_j"] = 0.20
	guide_assisted["reported_contact_dissipation_j"] = 6.20
	var guide_report: Dictionary = EnergyScript.reconcile(configuration, guide_assisted)["report"]
	_check(not bool(guide_report["accepted"]), "material positive guide work rejects")
	_check(
		"RECOVERY_GUIDE_WORK_BOUND_EXCEEDED" in guide_report["failure_codes"],
		"guide assistance has a stable failure code"
	)

	var unexplained := _trace()
	unexplained["reported_contact_dissipation_j"] = 0.0
	var residual_report: Dictionary = EnergyScript.reconcile(configuration, unexplained)["report"]
	_check(not bool(residual_report["accepted"]), "unexplained energy residual rejects")
	_check(
		"RECOVERY_ENERGY_BALANCE_RESIDUAL_EXCEEDED" in residual_report["failure_codes"],
		"energy residual has a stable failure code"
	)

	var external_lift := _trace()
	external_lift["actuator_positive_work_j"] = 40.0
	external_lift["actuator_absorbed_work_j"] = 0.0
	external_lift["known_external_work_j"] = 10.0
	external_lift["inferred_guide_work_j"] = 0.0
	external_lift["reported_contact_dissipation_j"] = 1.0
	var external_report: Dictionary = EnergyScript.reconcile(configuration, external_lift)["report"]
	_check(
		not bool(external_report["accepted"]),
		"external lift cannot substitute for positive actuator work"
	)
	_check(
		"RECOVERY_POTENTIAL_GAIN_NOT_COVERED_BY_ACTUATION" in external_report["failure_codes"],
		"external-work substitution names the actuator-work failure"
	)
	_finish()


static func _configuration() -> Dictionary:
	return {
		"schema_version": "recovery_energy_ledger_v1",
		"total_mass_kg": 10.0,
		"gravity_m_s2": 9.8,
		"minimum_height_gain_m": 0.40,
		"minimum_torque_reserve_fraction": 0.20,
		"minimum_power_reserve_fraction": 0.20,
		"minimum_structural_reserve_fraction": 0.20,
		"maximum_abs_inferred_guide_work_j": 0.05,
		"maximum_energy_balance_residual_j": 0.01,
		"automatic_creature_guidance_allowed": false,
	}


static func _preflight() -> Dictionary:
	return {
		"schema_version": "recovery_energy_preflight_v1",
		"start_com_height_m": 0.20,
		"target_com_height_m": 0.70,
		"available_positive_work_j": 100.0,
		"required_peak_torque_nm": 20.0,
		"available_peak_torque_nm": 40.0,
		"required_peak_power_w": 50.0,
		"available_peak_power_w": 100.0,
		"required_structural_torque_nm": 30.0,
		"available_structural_torque_nm": 60.0,
	}


static func _trace() -> Dictionary:
	return {
		"schema_version": "recovery_energy_trace_v1",
		"initial_com_height_m": 0.20,
		"final_com_height_m": 0.70,
		"initial_kinetic_energy_j": 0.0,
		"final_kinetic_energy_j": 0.0,
		"actuator_positive_work_j": 60.0,
		"actuator_absorbed_work_j": 5.0,
		"known_external_work_j": 0.0,
		"inferred_guide_work_j": 0.01,
		"reported_contact_dissipation_j": 6.01,
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
