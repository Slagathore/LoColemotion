extends SceneTree
# gdlint: disable=max-line-length

## BR9.4 digest, assistance, causal, measurement, and claim containment.

const AnalyzerScript := preload("res://scripts/lab/mechanics/existing_contact_brace_analyzer.gd")

const CONFIGURATION := {
	"schema_version": "existing_contact_brace_experiment_configuration_v1",
	"physics_hz": 60,
	"disturbance_tick": 120,
	"evaluation_delay_ticks": 30,
	"trial_end_tick": 240,
	"baseline_height_m": 0.70,
	"root_mass_kg": 2.0,
	"link_mass_kg": 0.5,
	"link_length_m": 0.40,
	"foot_radius_m": 0.055,
	"hip_half_span_m": 0.35,
	"friction_coefficient": 0.8,
	"height_position_gain_n_m": 250.0,
	"height_velocity_gain_n_s_m": 45.0,
	"prebrace_pitch_position_gain_nm_rad": 2.0,
	"prebrace_pitch_velocity_gain_nm_s_rad": 0.10,
	"joint_position_gain_nm_rad": 5.0,
	"joint_velocity_gain_nm_s_rad": 0.20,
	"maximum_contact_normal_n": 80.0,
	"pitch_impulse_n_m_s": 0.05,
	"brace_configuration":
	{
		"schema_version": "existing_contact_brace_configuration_v1",
		"angular_momentum_gain_s_inv": 40.0,
		"pitch_rate_gain_nm_s_rad": 0.50,
		"reserve_fraction": 0.10,
		"max_normal_load_rate_n_s": 240.0,
		"max_tangent_load_rate_n_s": 240.0,
		"stable_angular_momentum_abs_kg_m2_s": 0.01,
		"stable_pitch_error_abs_rad": 0.025,
		"stable_pitch_rate_abs_rad_s": 0.08,
		"stable_dwell_ticks": 12,
		"feasibility_tolerance": 1.0e-8,
	},
	"actuator_spec_sha256":
	"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
	"minimum_existing_contact_fraction": 0.98,
	"maximum_controlled_evaluation_momentum_abs_kg_m2_s": 0.005,
	"maximum_controlled_momentum_area_ratio": 0.25,
	"maximum_controlled_pitch_excursion_ratio": 0.50,
	"maximum_controlled_height_error_m": 0.01,
	"maximum_command_moment_residual_nm": 1.0e-7,
	"maximum_realized_moment_residual_nm": 5.0,
	"maximum_pairing_residual_nm": 1.0e-9,
	"maximum_applied_torque_nm": 75.0,
	"out_of_plane_planar_guide_enabled": true,
	"built_in_motors_enabled": false,
	"joint_limits_enabled": false,
	"passive_tissues_enabled": false,
	"controller_root_force_enabled": false,
	"foot_pin_enabled": false,
	"new_support_contact_enabled": false,
	"per_foot_load_sensor_enabled": false,
	"automatic_creature_guidance_enabled": false,
	"free_3d_bracing_claim_enabled": false,
	"catch_step_claim_enabled": false,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR9.4 existing-contact brace containment ===")
	var built := AnalyzerScript.build(CONFIGURATION)
	_check(bool(built.get("ok", false)), "exact paired BR9 contract seals")
	if not bool(built.get("ok", false)):
		printerr("  build_failure=", built)
		_finish()
		return
	var contract: Dictionary = built["contract"]
	var boundary := String(contract["claim_boundary"])
	_check(
		(
			boundary.contains("exact BR7 sagittal scaffold")
			and boundary.contains("Commanded left/right shares are not measurements")
			and boundary.contains("no new-contact catch step")
		),
		"verbatim boundary names the scaffold, command semantics, and downstream exclusion"
	)

	var mutated_contract := contract.duplicate(true)
	mutated_contract["maximum_controlled_momentum_area_ratio"] = 0.99
	_check(
		(
			String(
				(
					AnalyzerScript
					. analyze(mutated_contract, _valid_control(contract), _valid_brace(contract))
					. get("failure_code", "")
				)
			)
			== "EXISTING_CONTACT_BRACE_CONTRACT_DIGEST_MISMATCH"
		),
		"post-seal acceptance-threshold mutation fails the digest boundary"
	)
	var missing := CONFIGURATION.duplicate(true)
	missing.erase("disturbance_tick")
	_check(
		(
			String(AnalyzerScript.build(missing).get("failure_code", ""))
			== "EXISTING_CONTACT_BRACE_CONFIGURATION_FIELD_SET_MISMATCH"
		),
		"missing causal timing authority fails closed"
	)
	for forbidden_field in [
		"built_in_motors_enabled",
		"controller_root_force_enabled",
		"foot_pin_enabled",
		"new_support_contact_enabled",
		"per_foot_load_sensor_enabled",
		"automatic_creature_guidance_enabled",
		"free_3d_bracing_claim_enabled",
		"catch_step_claim_enabled",
	]:
		var forged := CONFIGURATION.duplicate(true)
		forged[forbidden_field] = true
		_check(
			(
				String(AnalyzerScript.build(forged).get("failure_code", ""))
				== "EXISTING_CONTACT_BRACE_FORBIDDEN_ASSIST_OR_CLAIM:%s" % forbidden_field
			),
			"forbidden %s fails closed" % forbidden_field
		)

	var accepted := AnalyzerScript.analyze(
		contract, _valid_control(contract), _valid_brace(contract)
	)
	_check(
		bool(accepted.get("ok", false)) and bool(accepted.get("accepted", false)),
		"a fully bounded synthetic pair satisfies the sealed analyzer"
	)
	var late := _valid_brace(contract)
	late["first_brace_command_tick"] = int(contract["expected_first_brace_command_tick"]) + 1
	_check(
		not bool(AnalyzerScript.analyze(contract, _valid_control(contract), late)["accepted"]),
		"a brace beginning after the first post-impulse observation is rejected"
	)
	var weak := _valid_brace(contract)
	weak["angular_momentum_abs_area_kg_m2"] = 0.006
	_check(
		not bool(AnalyzerScript.analyze(contract, _valid_control(contract), weak)["accepted"]),
		"a physical result outside the sealed improvement ratio cannot pass"
	)
	var contact_loss := _valid_brace(contract)
	contact_loss["right_existing_contact_fraction"] = 0.90
	_check(
		not bool(
			AnalyzerScript.analyze(contract, _valid_control(contract), contact_loss)["accepted"]
		),
		"loss of an original support contact cannot pass as existing-contact bracing"
	)
	var rescued := _valid_brace(contract)
	rescued["root_rescue_operation_count"] = 1
	_check(
		not bool(AnalyzerScript.analyze(contract, _valid_control(contract), rescued)["accepted"]),
		"root rescue cannot pass as articulated contact redistribution"
	)
	var false_sensor := _valid_brace(contract)
	false_sensor["per_foot_measured_load_allocation_available"] = true
	_check(
		not bool(
			AnalyzerScript.analyze(contract, _valid_control(contract), false_sensor)["accepted"]
		),
		"commanded contact shares cannot be forged into measured per-foot loads"
	)
	var wrong_actuator := _valid_brace(contract)
	wrong_actuator["actuator_spec_sha256"] = ("sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
	_check(
		(
			String(
				AnalyzerScript.analyze(contract, _valid_control(contract), wrong_actuator).get(
					"failure_code", ""
				)
			)
			== "EXISTING_CONTACT_BRACE_SUMMARY_ACTUATOR_DIGEST_MISMATCH"
		),
		"an unbound actuator specification fails before acceptance evaluation"
	)
	var exclusions: Array = accepted["does_not_establish"]
	_check(
		(
			exclusions.has("new_contact_catch_step")
			and exclusions.has("free_3d_bracing")
			and exclusions.has("fall_arrest")
			and exclusions.has("getting_up")
			and exclusions.has("walking")
			and exclusions.has("automatic_creature_guidance")
		),
		"accepted analysis preserves every downstream physical and guidance non-claim"
	)
	_check(
		(
			(accepted["milestone_cells"] as Array) == ["BR9.0", "BR9.1", "BR9.2", "BR9.3"]
			and String(accepted["integrity_cell"]) == "BR9.4"
		),
		"integrity containment cannot substitute for a physical milestone cell"
	)
	_finish()


static func _common(contract: Dictionary, brace_enabled: bool) -> Dictionary:
	return {
		"schema_version": "existing_contact_brace_fixture_summary_v1",
		"configuration_sha256": contract["configuration_sha256"],
		"actuator_spec_sha256": contract["actuator_spec_sha256"],
		"fixture_complete": true,
		"brace_enabled": brace_enabled,
		"executed_ticks": 240,
		"planar_guide_exact": true,
		"hinges_exact": true,
		"all_receipts_complete": true,
		"disturbance_operation_count": 1,
		"first_brace_command_tick": -1,
		"brace_command_count": 0,
		"stabilize_handoff_tick": -1,
		"command_handoff_state": "NO_BRACE_CONTROL",
		"controller_rate_limited_count": 0,
		"maximum_command_moment_residual_nm": 0.0,
		"maximum_realized_moment_residual_nm": 0.0,
		"maximum_normal_load_rate_n_s": 0.0,
		"maximum_tangent_load_rate_n_s": 0.0,
		"maximum_pairing_residual_nm": 0.0,
		"maximum_applied_torque_nm": 5.0,
		"actuator_saturation_count": 0,
		"post_impulse_angular_momentum_z_kg_m2_s": 0.059,
		"evaluation_angular_momentum_z_kg_m2_s": 0.015,
		"final_angular_momentum_z_kg_m2_s": 0.001,
		"angular_momentum_abs_area_kg_m2": 0.014,
		"maximum_pitch_excursion_rad": 0.020,
		"signed_pitch_excursion_rad": 0.020,
		"maximum_height_error_m": 0.001,
		"left_existing_contact_fraction": 1.0,
		"right_existing_contact_fraction": 1.0,
		"post_disturbance_sample_count": 120,
		"last_left_command_normal_n": 19.6,
		"last_right_command_normal_n": 19.6,
		"last_controller_failure": {},
		"root_rescue_operation_count": 0,
		"foot_pin_operation_count": 0,
		"new_support_contact_operation_count": 0,
		"per_contact_commands_are_measurements": false,
		"per_foot_measured_load_allocation_available": false,
		"automatic_creature_guidance_operation_count": 0,
	}


static func _valid_control(contract: Dictionary) -> Dictionary:
	return _common(contract, false)


static func _valid_brace(contract: Dictionary) -> Dictionary:
	var summary := _common(contract, true)
	summary["first_brace_command_tick"] = 121
	summary["brace_command_count"] = 119
	summary["stabilize_handoff_tick"] = 133
	summary["command_handoff_state"] = "STABILIZE"
	summary["maximum_realized_moment_residual_nm"] = 1.0
	summary["maximum_normal_load_rate_n_s"] = 220.0
	summary["evaluation_angular_momentum_z_kg_m2_s"] = -0.001
	summary["final_angular_momentum_z_kg_m2_s"] = -0.0002
	summary["angular_momentum_abs_area_kg_m2"] = 0.002
	summary["maximum_pitch_excursion_rad"] = 0.005
	summary["signed_pitch_excursion_rad"] = 0.005
	return summary


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
