extends SceneTree
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BR11.2 paired impulse, momentum, severity-proxy, and energy-accounting oracle.

const AnalyzerScript := preload("res://scripts/lab/mechanics/controlled_fall_arrest_analyzer.gd")
const PhysicalTestScript := preload(
	"res://tests/test_experimental_br11_3_planar_controlled_fall_arrest.gd"
)

const ACTUATOR_SHA := "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR11.2 impulse and momentum accounting ===")
	var built := AnalyzerScript.build(PhysicalTestScript._configuration(ACTUATOR_SHA))
	_check(bool(built.get("ok", false)), "digest-bound paired accounting contract seals")
	if not bool(built.get("ok", false)):
		printerr("  build_failure=", built)
		_finish()
		return
	var contract: Dictionary = built["contract"]
	var valid := AnalyzerScript.analyze(contract, _valid_active(contract), _valid_control(contract))
	_check(
		bool(valid.get("ok", false)) and bool(valid.get("accepted", false)),
		"strict synthetic active/control evidence satisfies the complete oracle"
	)
	_check(
		(
			is_equal_approx(float(valid["active_to_control_severity_ratio"]), 5.0 / 6.0)
			and is_equal_approx(float(valid["active_to_control_core_speed_ratio"]), 0.8)
			and is_equal_approx(float(valid["active_to_control_core_load_ratio"]), 0.9375)
			and is_equal_approx(float(valid["active_to_control_linear_momentum_ratio"]), 0.85)
		),
		"paired ratios derive from the declared whole-system and local-witness channels"
	)
	_check(
		(
			String(valid["severity_proxy"]) == "pre_core_whole_system_kinetic_energy_j"
			and is_equal_approx(float(valid["active_to_initial_angular_momentum_ratio"]), 5.0)
		),
		"angular momentum stays explicit without being miscast as a universal reduction gate"
	)

	var missing_angular := _valid_active(contract)
	missing_angular["pre_core_angular_momentum_about_com_world_n_m_s"] = null
	_check(
		(
			String(
				AnalyzerScript.analyze(contract, missing_angular, _valid_control(contract)).get(
					"failure_code", ""
				)
			)
			== (
				"CONTROLLED_FALL_SUMMARY_VECTOR_NONFINITE:"
				+ "pre_core_angular_momentum_about_com_world_n_m_s"
			)
		),
		"missing centroidal angular momentum fails closed"
	)
	var unavailable_angular := _valid_active(contract)
	unavailable_angular["angular_momentum_available"] = false
	_check(
		(
			String(
				AnalyzerScript.analyze(contract, unavailable_angular, _valid_control(contract)).get(
					"failure_code", ""
				)
			)
			== "CONTROLLED_FALL_SUMMARY_INTEGRITY_FAILED"
		),
		"an explicitly unavailable angular channel cannot support BR11"
	)
	var false_allocation := _valid_active(contract)
	false_allocation["local_core_load_is_generalized_allocation"] = true
	_check(
		not bool(
			AnalyzerScript.analyze(contract, false_allocation, _valid_control(contract)).get(
				"ok", false
			)
		),
		"a local predicted contact witness cannot become generalized load allocation"
	)
	var false_injury_model := _valid_active(contract)
	false_injury_model["severity_proxy_is_injury_model"] = true
	_check(
		not bool(
			AnalyzerScript.analyze(contract, false_injury_model, _valid_control(contract)).get(
				"ok", false
			)
		),
		"the kinetic severity proxy cannot be forged into an injury model"
	)
	var nonfinite_impulse := _valid_active(contract)
	nonfinite_impulse["reconstructed_external_impulse_world_n_s"] = [NAN, 100.0, 0.0]
	_check(
		not bool(
			AnalyzerScript.analyze(contract, nonfinite_impulse, _valid_control(contract)).get(
				"ok", false
			)
		),
		"nonfinite reconstructed external impulse fails before comparison"
	)
	var residual := _valid_active(contract)
	residual["energy_accounting_residual_j"] = 0.01
	_check(
		not bool(
			AnalyzerScript.analyze(contract, residual, _valid_control(contract)).get(
				"accepted", true
			)
		),
		"an energy-accounting residual above the sealed tolerance is rejected"
	)
	var generated_contact_energy := _valid_active(contract)
	generated_contact_energy["contact_dissipation_j"] = -0.01
	_check(
		not bool(
			(
				AnalyzerScript
				. analyze(contract, generated_contact_energy, _valid_control(contract))
				. get("accepted", true)
			)
		),
		"the declared dissipative contact account cannot silently generate energy"
	)
	var late_protection := _valid_active(contract)
	late_protection["first_protective_contact_tick"] = 38
	late_protection["protective_before_core"] = false
	_check(
		not bool(
			AnalyzerScript.analyze(contract, late_protection, _valid_control(contract)).get(
				"accepted", true
			)
		),
		"protective contact after semantic core impact is not fall arrest"
	)
	var missing_core := _valid_active(contract)
	missing_core["first_core_contact_tick"] = -1
	_check(
		not bool(
			AnalyzerScript.analyze(contract, missing_core, _valid_control(contract)).get(
				"accepted", true
			)
		),
		"an active trial without an observed core impact cannot claim reduced core severity"
	)
	for field in [
		"pre_core_total_kinetic_energy_j",
		"core_approach_speed_m_s",
		"peak_predicted_local_core_load_n",
	]:
		var unimproved := _valid_active(contract)
		unimproved[field] = _valid_control(contract)[field]
		_check(
			not bool(
				AnalyzerScript.analyze(contract, unimproved, _valid_control(contract)).get(
					"accepted", true
				)
			),
			"unimproved %s is rejected" % field
		)
	var unimproved_momentum := _valid_active(contract)
	unimproved_momentum["pre_core_linear_momentum_world_n_s"] = [0.0, -10.0, 0.0]
	_check(
		not bool(
			AnalyzerScript.analyze(contract, unimproved_momentum, _valid_control(contract)).get(
				"accepted", true
			)
		),
		"unimproved pre-core whole-system linear momentum is rejected"
	)
	var mismatched_start := _valid_active(contract)
	mismatched_start["initial_linear_momentum_world_n_s"] = [0.1, -10.0, 0.0]
	_check(
		not bool(
			AnalyzerScript.analyze(contract, mismatched_start, _valid_control(contract)).get(
				"accepted", true
			)
		),
		"the paired comparison cannot begin from different mechanical states"
	)
	var zero_active_torque := _valid_active(contract)
	zero_active_torque["maximum_applied_torque_nm"] = 0.0
	_check(
		not bool(
			AnalyzerScript.analyze(contract, zero_active_torque, _valid_control(contract)).get(
				"accepted", true
			)
		),
		"an allegedly active arrest with zero applied hinge torque is rejected"
	)
	var powered_control := _valid_control(contract)
	powered_control["actuator_work_j"] = 0.1
	_check(
		not bool(
			AnalyzerScript.analyze(contract, _valid_active(contract), powered_control).get(
				"accepted", true
			)
		),
		"the zero-command control cannot hide actuator work"
	)
	var unstable_terminal := _valid_active(contract)
	unstable_terminal["final_linear_speed_m_s"] = 0.16
	_check(
		not bool(
			AnalyzerScript.analyze(contract, unstable_terminal, _valid_control(contract)).get(
				"accepted", true
			)
		),
		"a nominal FALLEN label cannot override excessive terminal motion"
	)
	var no_fallen_transition := _valid_active(contract)
	no_fallen_transition["fallen_transition_tick"] = -1
	_check(
		not bool(
			AnalyzerScript.analyze(contract, no_fallen_transition, _valid_control(contract)).get(
				"accepted", true
			)
		),
		"stable fallen evidence requires an observed supervisor transition"
	)
	_finish()


static func _common(contract: Dictionary, arrest_enabled: bool) -> Dictionary:
	return {
		"schema_version": "controlled_fall_arrest_summary_v1",
		"configuration_sha256": contract["configuration_sha256"],
		"actuator_spec_sha256": contract["actuator_spec_sha256"],
		"arrest_enabled": arrest_enabled,
		"fixture_complete": true,
		"fixture_failure_code": "",
		"executed_ticks": 480,
		"planar_guide_exact": true,
		"hinge_exact": true,
		"all_receipts_complete": true,
		"angular_momentum_available": true,
		"protective_role_registered": true,
		"core_role_registered": true,
		"first_protective_contact_tick": 39,
		"first_core_contact_tick": 34,
		"protective_before_core": false,
		"initial_linear_momentum_world_n_s": [0.0, -10.0, 0.0],
		"pre_core_linear_momentum_world_n_s": [0.0, -10.0, 0.0],
		"initial_angular_momentum_about_com_world_n_m_s": [0.0, 0.0, -0.2],
		"pre_core_angular_momentum_about_com_world_n_m_s": [0.0, 0.0, -0.2],
		"initial_total_kinetic_energy_j": 10.0,
		"pre_core_total_kinetic_energy_j": 60.0,
		"core_approach_speed_m_s": 5.0,
		"peak_predicted_local_core_load_n": 1600.0,
		"reconstructed_external_impulse_world_n_s": [0.0, 275.0, 0.0],
		"initial_mechanical_energy_j": 80.0,
		"final_mechanical_energy_j": 10.0,
		"actuator_work_j": 0.0,
		"contact_dissipation_j": 70.0,
		"energy_accounting_residual_j": 0.0,
		"final_supervisor_phase": "FALLEN",
		"fallen_transition_tick": 80,
		"stable_fallen_observed": true,
		"upright_recovery_observed": false,
		"final_linear_speed_m_s": 0.05,
		"final_angular_speed_rad_s": 0.05,
		"maximum_applied_torque_nm": 0.0,
		"maximum_pairing_residual_nm": 0.0,
		"actuator_saturation_count": 0,
		"root_rescue_operation_count": 0,
		"foot_pin_operation_count": 0,
		"pose_teleport_operation_count": 0,
		"automatic_creature_guidance_operation_count": 0,
		"local_core_load_is_generalized_allocation": false,
		"severity_proxy_is_injury_model": false,
	}


static func _valid_active(contract: Dictionary) -> Dictionary:
	var summary := _common(contract, true)
	summary["first_protective_contact_tick"] = 30
	summary["first_core_contact_tick"] = 37
	summary["protective_before_core"] = true
	summary["pre_core_linear_momentum_world_n_s"] = [0.0, -8.5, 0.0]
	summary["pre_core_angular_momentum_about_com_world_n_m_s"] = [0.0, 0.0, 1.0]
	summary["pre_core_total_kinetic_energy_j"] = 50.0
	summary["core_approach_speed_m_s"] = 4.0
	summary["peak_predicted_local_core_load_n"] = 1500.0
	summary["actuator_work_j"] = 0.3
	summary["contact_dissipation_j"] = 70.3
	summary["fallen_transition_tick"] = 120
	summary["maximum_applied_torque_nm"] = 40.0
	summary["actuator_saturation_count"] = 40
	return summary


static func _valid_control(contract: Dictionary) -> Dictionary:
	return _common(contract, false)


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
