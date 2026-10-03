extends SceneTree
# gdlint: disable=max-line-length

## BR7.4 digest, assistance, measurement, and claim-boundary containment.

const AnalyzerScript := preload("res://scripts/lab/mechanics/planar_stance_analyzer.gd")

const CONFIGURATION := {
	"schema_version": "planar_stance_configuration_v1",
	"physics_hz": 60,
	"static_measure_start_tick": 60,
	"disturbance_tick": 140,
	"support_loss_tick": 300,
	"post_loss_ticks": 30,
	"baseline_height_m": 0.70,
	"root_mass_kg": 2.0,
	"link_mass_kg": 0.5,
	"link_length_m": 0.40,
	"foot_radius_m": 0.055,
	"hip_half_span_m": 0.35,
	"friction_coefficient": 0.8,
	"height_position_gain_n_m": 250.0,
	"height_velocity_gain_n_s_m": 45.0,
	"pitch_position_gain_nm_rad": 2.0,
	"pitch_velocity_gain_nm_s_rad": 0.10,
	"joint_position_gain_nm_rad": 5.0,
	"joint_velocity_gain_nm_s_rad": 0.20,
	"maximum_contact_normal_n": 80.0,
	"controller_feasibility_reserve_fraction": 0.90,
	"pitch_impulse_n_m_s": 0.03,
	"recovery_pitch_error_rad": 0.025,
	"recovery_pitch_rate_rad_s": 0.10,
	"recovery_height_error_m": 0.02,
	"recovery_dwell_ticks": 12,
	"maximum_static_height_error_m": 0.02,
	"maximum_static_pitch_error_rad": 0.03,
	"maximum_static_support_error_n": 2.0,
	"minimum_contact_fraction": 0.98,
	"maximum_realized_vertical_wrench_residual_n": 3.0,
	"maximum_realized_pitch_wrench_residual_nm": 3.0,
	"minimum_pitch_excursion_rad": 0.01,
	"maximum_pitch_excursion_rad": 0.03,
	"maximum_disturbance_recovery_ticks": 60,
	"maximum_pairing_residual_nm": 1.0e-9,
	"maximum_applied_torque_nm": 75.0,
	"out_of_plane_planar_guide_enabled": true,
	"built_in_motors_enabled": false,
	"joint_limits_enabled": false,
	"passive_tissues_enabled": false,
	"controller_root_force_enabled": false,
	"foot_pin_enabled": false,
	"per_foot_load_sensor_enabled": false,
	"automatic_creature_guidance_enabled": false,
	"free_3d_standing_claim_enabled": false,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR7.4 planar stance containment ===")
	var built := AnalyzerScript.build(CONFIGURATION)
	_check(bool(built.get("ok", false)), "exact planar stance contract seals")
	if not bool(built.get("ok", false)):
		printerr("  build_failure=", built)
		_finish()
		return
	var contract: Dictionary = built["contract"]
	var boundary := String(contract["claim_boundary"])
	_check(
		(
			boundary.contains("explicit unpowered out-of-plane guide")
			and boundary.contains("Commanded left/right loads are not measurements")
			and boundary.contains("no free 3D standing")
		),
		"verbatim claim boundary names the scaffold, command semantics, and non-claim"
	)

	var mutated_contract := contract.duplicate(true)
	mutated_contract["baseline_height_m"] = 0.71
	_check(
		(
			String(
				AnalyzerScript.analyze(mutated_contract, _valid_summary()).get("failure_code", "")
			)
			== "PLANAR_STANCE_CONTRACT_DIGEST_MISMATCH"
		),
		"post-seal contract mutation fails the digest boundary"
	)

	var root_assisted := CONFIGURATION.duplicate(true)
	root_assisted["controller_root_force_enabled"] = true
	var pinned := CONFIGURATION.duplicate(true)
	pinned["foot_pin_enabled"] = true
	var hidden_guide := CONFIGURATION.duplicate(true)
	hidden_guide["out_of_plane_planar_guide_enabled"] = false
	_check(
		(
			not bool(AnalyzerScript.build(root_assisted).get("ok", true))
			and not bool(AnalyzerScript.build(pinned).get("ok", true))
			and not bool(AnalyzerScript.build(hidden_guide).get("ok", true))
		),
		"root force, foot pinning, and an undeclared scaffold state fail closed"
	)

	var valid := AnalyzerScript.analyze(contract, _valid_summary())
	_check(
		bool(valid.get("ok", false)) and bool(valid.get("accepted", false)),
		"a fully bounded synthetic summary satisfies the sealed analyzer"
	)
	var exclusions: Array = valid["does_not_establish"]
	_check(
		(
			exclusions.has("free_3d_standing")
			and exclusions.has("per_foot_measured_load_allocation")
			and exclusions.has("walking")
			and exclusions.has("automatic_creature_guidance")
		),
		"accepted analysis preserves standing, allocation, walking, and guidance exclusions"
	)

	var rescued := _valid_summary()
	rescued["root_rescue_operation_count"] = 1
	_check(
		not bool(AnalyzerScript.analyze(contract, rescued)["accepted"]),
		"a root-rescued run cannot pass as planar stance evidence"
	)
	var false_sensor := _valid_summary()
	false_sensor["per_foot_measured_load_allocation_available"] = true
	_check(
		not bool(AnalyzerScript.analyze(contract, false_sensor)["accepted"]),
		"commanded support shares cannot be forged into measured per-foot loads"
	)
	var missing_event := _valid_summary()
	missing_event["support_loss_event_count"] = 0
	_check(
		not bool(AnalyzerScript.analyze(contract, missing_event)["accepted"]),
		"support removal without exactly one loss event is rejected"
	)
	var wrong_sign := _valid_summary()
	wrong_sign["signed_pitch_excursion_rad"] = -0.012
	_check(
		not bool(AnalyzerScript.analyze(contract, wrong_sign)["accepted"]),
		"wrong-sign pitch response is rejected"
	)
	var preloss_infeasible := _valid_summary()
	preloss_infeasible["allocator_infeasible_before_loss_count"] = 1
	_check(
		not bool(AnalyzerScript.analyze(contract, preloss_infeasible)["accepted"]),
		"pre-loss wrench infeasibility cannot be hidden by later recovery"
	)
	var malformed := _valid_summary()
	malformed.erase("planar_guide_exact")
	_check(
		(
			String(AnalyzerScript.analyze(contract, malformed).get("failure_code", ""))
			== "PLANAR_STANCE_SUMMARY_BOOL_MISSING:planar_guide_exact"
		),
		"missing integrity fields fail before acceptance evaluation"
	)
	_finish()


static func _valid_summary() -> Dictionary:
	return {
		"fixture_complete": true,
		"executed_ticks": 301,
		"planar_guide_exact": true,
		"hinges_exact": true,
		"all_receipts_complete": true,
		"maximum_pairing_residual_nm": 0.0,
		"maximum_requested_torque_nm": 4.3,
		"maximum_applied_torque_nm": 4.3,
		"actuator_saturation_count": 0,
		"allocator_infeasible_before_loss_count": 0,
		"allocation_maximum_force_residual_n": 0.0,
		"allocation_maximum_moment_residual_nm": 0.0,
		"controller_wrench_saturation_count": 0,
		"static_maximum_height_error_m": 0.001,
		"static_maximum_pitch_error_rad": 0.001,
		"static_maximum_vertical_velocity_m_s": 0.001,
		"static_maximum_pitch_rate_rad_s": 0.001,
		"static_maximum_support_error_n": 0.01,
		"static_maximum_realized_vertical_wrench_residual_n": 0.01,
		"static_maximum_realized_pitch_wrench_residual_nm": 0.01,
		"left_contact_fraction": 1.0,
		"right_contact_fraction": 1.0,
		"disturbance_operation_count": 1,
		"maximum_pitch_excursion_rad": 0.012,
		"signed_pitch_excursion_rad": 0.012,
		"disturbance_recovered": true,
		"disturbance_recovery_ticks": 25,
		"support_loss_event_count": 1,
		"support_loss_event_tick": 301,
		"support_loss_response": "DECLARE_INFEASIBLE_STOP",
		"controlled_stop": true,
		"last_infeasible_reasons": ["PITCH_MOMENT_RESIDUAL"],
		"last_infeasible_tick": 301,
		"last_infeasible_desired_vertical_n": 39.2,
		"last_infeasible_desired_moment_nm": 0.0,
		"last_infeasible_root_height_m": 0.70,
		"last_infeasible_root_pitch_rad": 0.0,
		"last_infeasible_root_vertical_velocity_m_s": 0.0,
		"last_infeasible_root_pitch_rate_rad_s": 0.0,
		"root_rescue_operation_count": 0,
		"foot_pin_operation_count": 0,
		"passive_operation_count": 0,
		"per_contact_commands_are_measurements": false,
		"per_foot_measured_load_allocation_available": false,
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
