extends SceneTree
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BR10.4 digest, causal, assistance, measurement, and claim containment.

const AnalyzerScript := preload("res://scripts/lab/mechanics/reachable_catch_step_analyzer.gd")
const PhysicalTestScript := preload("res://tests/test_experimental_br10_3_planar_catch_step.gd")

const ACTUATOR_SHA := "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR10.4 reachable-catch containment ===")
	var configuration: Dictionary = PhysicalTestScript._configuration(ACTUATOR_SHA)
	var built := AnalyzerScript.build(configuration)
	_check(bool(built.get("ok", false)), "exact paired BR10 contract seals")
	if not bool(built.get("ok", false)):
		printerr("  build_failure=", built)
		_finish()
		return
	var contract: Dictionary = built["contract"]
	var boundary := String(contract["claim_boundary"])
	_check(
		(
			boundary.contains("exact inherited BR7 sagittal scaffold")
			and boundary.contains("Commanded contact-force shares are not measured per-foot loads")
			and boundary.contains("no per-foot measured load allocation")
			and boundary.contains("no per-foot measured load allocation")
		),
		"verbatim boundary names the scaffold, command semantics, and downstream exclusions"
	)

	var accepted := AnalyzerScript.analyze(
		contract, _valid_active(contract), _valid_control(contract)
	)
	_check(
		bool(accepted.get("ok", false)) and bool(accepted.get("accepted", false)),
		"a fully bounded synthetic pair satisfies the sealed analyzer"
	)
	var mutated_contract := contract.duplicate(true)
	mutated_contract["maximum_final_pitch_error_rad"] = 1.0
	_check(
		(
			String(
				(
					AnalyzerScript
					. analyze(mutated_contract, _valid_active(contract), _valid_control(contract))
					. get("failure_code", "")
				)
			)
			== "REACHABLE_CATCH_CONTRACT_DIGEST_MISMATCH"
		),
		"post-seal acceptance-threshold mutation fails the digest boundary"
	)
	var missing := configuration.duplicate(true)
	missing.erase("reaction_deadline_s")
	_check(
		(
			String(AnalyzerScript.build(missing).get("failure_code", ""))
			== "REACHABLE_CATCH_CONFIGURATION_FIELD_SET_MISMATCH"
		),
		"missing causal deadline authority fails closed"
	)
	var extra := configuration.duplicate(true)
	extra["hidden_root_assist"] = true
	_check(
		(
			String(AnalyzerScript.build(extra).get("failure_code", ""))
			== "REACHABLE_CATCH_CONFIGURATION_FIELD_SET_MISMATCH"
		),
		"extra hidden assistance field fails closed"
	)
	for forbidden_field in [
		"built_in_motors_enabled",
		"joint_limits_enabled",
		"passive_tissues_enabled",
		"controller_root_force_enabled",
		"foot_pin_enabled",
		"pose_teleport_enabled",
		"per_foot_load_sensor_enabled",
		"automatic_creature_guidance_enabled",
		"free_3d_stance_claim_enabled",
		"articulated_limb_generality_claim_enabled",
		"fall_arrest_claim_enabled",
		"getting_up_claim_enabled",
		"gait_claim_enabled",
		"walking_claim_enabled",
	]:
		var forged := configuration.duplicate(true)
		forged[forbidden_field] = true
		_check(
			(
				String(AnalyzerScript.build(forged).get("failure_code", ""))
				== "REACHABLE_CATCH_FORBIDDEN_ASSIST_OR_CLAIM:%s" % forbidden_field
			),
			"forbidden %s fails closed" % forbidden_field
		)
	var no_positive_scope := configuration.duplicate(true)
	no_positive_scope["scaffold_constrained_planar_catch_claim_enabled"] = false
	_check(
		(
			String(AnalyzerScript.build(no_positive_scope).get("failure_code", ""))
			== "REACHABLE_CATCH_REQUIRED_BOUNDARY_DISABLED"
		),
		"the analyzer cannot silently erase or broaden its exact positive claim"
	)

	var wrong_digest := _valid_active(contract)
	wrong_digest["actuator_spec_sha256"] = ("sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
	_check(
		(
			String(
				AnalyzerScript.analyze(contract, wrong_digest, _valid_control(contract)).get(
					"failure_code", ""
				)
			)
			== "REACHABLE_CATCH_SUMMARY_ACTUATOR_DIGEST_MISMATCH"
		),
		"an unbound actuator specification fails before acceptance evaluation"
	)
	var late_command := _valid_active(contract)
	late_command["first_catch_command_tick"] = 122
	_check(
		not bool(
			AnalyzerScript.analyze(contract, late_command, _valid_control(contract))["accepted"]
		),
		"a catch beginning after the first post-disturbance observation is rejected"
	)
	var skipped_phase := _valid_active(contract)
	skipped_phase["first_load_tick"] = int(skipped_phase["first_touch_tick"])
	_check(
		not bool(
			AnalyzerScript.analyze(contract, skipped_phase, _valid_control(contract))["accepted"]
		),
		"LOAD cannot be forged onto the first TOUCH tick"
	)
	var target_authority := _valid_active(contract)
	target_authority["target_arrival_used_for_phase_transition"] = true
	_check(
		not bool(
			AnalyzerScript.analyze(contract, target_authority, _valid_control(contract))["accepted"]
		),
		"target arrival cannot substitute for observed contact authority"
	)
	var false_sensor := _valid_active(contract)
	false_sensor["local_load_is_generalized_per_foot_allocation"] = true
	_check(
		not bool(
			AnalyzerScript.analyze(contract, false_sensor, _valid_control(contract))["accepted"]
		),
		"local contact observation cannot be forged into generalized per-foot allocation"
	)
	var rescued := _valid_active(contract)
	rescued["root_rescue_operation_count"] = 1
	_check(
		not bool(AnalyzerScript.analyze(contract, rescued, _valid_control(contract))["accepted"]),
		"root rescue cannot pass as articulated catch recovery"
	)
	var pinned := _valid_active(contract)
	pinned["foot_pin_operation_count"] = 1
	_check(
		not bool(AnalyzerScript.analyze(contract, pinned, _valid_control(contract))["accepted"]),
		"a hidden foot pin cannot pass as ordinary contact"
	)
	var lost_after_stance := _valid_active(contract)
	lost_after_stance["post_stance_bearing_loss_count"] = 1
	_check(
		not bool(
			(
				AnalyzerScript
				. analyze(contract, lost_after_stance, _valid_control(contract))["accepted"]
			)
		),
		"a transient dwell followed by bearing loss cannot pass the full horizon"
	)
	var excessive_rate := _valid_active(contract)
	excessive_rate["maximum_normal_load_rate_n_s"] = 1200.1
	_check(
		not bool(
			AnalyzerScript.analyze(contract, excessive_rate, _valid_control(contract))["accepted"]
		),
		"a commanded normal-load slew above the sealed rate cannot pass"
	)
	var support_mismatch := _valid_active(contract)
	support_mismatch["planner_support_improvement_m"] = 0.40
	_check(
		not bool(
			AnalyzerScript.analyze(contract, support_mismatch, _valid_control(contract))["accepted"]
		),
		"planner support prediction must remain near the measured contact geometry"
	)
	var unstable_handoff := _valid_active(contract)
	unstable_handoff["maximum_post_stance_pitch_rate_rad_s"] = 0.09
	_check(
		not bool(
			AnalyzerScript.analyze(contract, unstable_handoff, _valid_control(contract))["accepted"]
		),
		"post-stance re-excitation outside the sealed rate cannot pass"
	)
	var soft_control := _valid_control(contract)
	soft_control["touchdown_approach_speed_m_s"] = 1.0
	_check(
		not bool(
			AnalyzerScript.analyze(contract, _valid_active(contract), soft_control)["accepted"]
		),
		"an insufficiently discriminating no-catch control cannot support the claim"
	)
	var exclusions: Array = accepted["does_not_establish"]
	_check(
		(
			exclusions.has("per_foot_measured_load_allocation")
			and exclusions.has("free_3d_standing")
			and exclusions.has("free_3d_bracing")
			and exclusions.has("generalized_fall_arrest")
			and exclusions.has("getting_up")
			and exclusions.has("walking")
			and exclusions.has("automatic_creature_guidance")
		),
		"accepted analysis preserves every downstream physical and guidance non-claim"
	)
	_check(
		(
			(accepted["milestone_cells"] as Array) == ["BR10.0", "BR10.1", "BR10.2", "BR10.3"]
			and String(accepted["integrity_cell"]) == "BR10.4"
		),
		"integrity containment cannot substitute for a physical milestone cell"
	)
	_finish()


static func _common(contract: Dictionary, catch_enabled: bool) -> Dictionary:
	return {
		"schema_version": "reachable_catch_step_summary_v1",
		"configuration_sha256": contract["configuration_sha256"],
		"actuator_spec_sha256": contract["actuator_spec_sha256"],
		"catch_enabled": catch_enabled,
		"fixture_complete": true,
		"fixture_failure_code": "",
		"executed_ticks": 600,
		"planar_guide_exact": true,
		"hinges_exact": true,
		"all_receipts_complete": true,
		"contact_capacity_complete": true,
		"disturbance_operation_count": 1,
		"root_release_operation_count": 1,
		"left_bearing_at_release": true,
		"preparation_root_freeze_released": true,
		"catch_plan_count": 0,
		"catch_command_count": 0,
		"first_catch_command_tick": -1,
		"planner_selected": false,
		"planner_failure_code": "",
		"selected_candidate_id": "",
		"predicted_contact_tick": -1,
		"predicted_reach_time_s": -1.0,
		"planner_support_improvement_m": 0.0,
		"first_touch_tick": 278,
		"first_load_tick": 279,
		"first_bearing_tick": 280,
		"final_phase": "SEARCH",
		"phase_trace": [],
		"stance_return_tick": -1,
		"stance_world_hold_active": false,
		"stance_world_hold_command_count": 0,
		"stabilize_handoff_command_count": 0,
		"touchdown_approach_speed_m_s": 19.0,
		"peak_predicted_local_normal_load_n": 290.0,
		"initial_right_contact_count": 0,
		"non_distal_contact_count": 0,
		"support_interval_before_m": 0.11,
		"support_interval_after_m": 1.0,
		"measured_support_improvement_m": 0.89,
		"maximum_horizontal_position_error_m": 0.0,
		"maximum_horizontal_speed_m_s": 0.0,
		"maximum_commanded_tangent_n": 0.0,
		"maximum_applied_torque_nm": 60.0,
		"maximum_pairing_residual_nm": 0.0,
		"actuator_saturation_count": 100,
		"allocator_clamp_count": 0,
		"maximum_normal_load_rate_n_s": 0.0,
		"post_impulse_pitch_rate_rad_s": -0.13,
		"pitch_at_first_bearing_rad": -2.5,
		"maximum_pitch_excursion_rad": 3.0,
		"maximum_height_error_m": 0.18,
		"post_stance_sample_count": 0,
		"post_stance_bearing_loss_count": 0,
		"maximum_post_stance_pitch_error_rad": 0.0,
		"maximum_post_stance_pitch_rate_rad_s": 0.0,
		"maximum_post_stance_height_error_m": 0.0,
		"normal_load_rate_is_bearing_command_only": true,
		"final_pitch_rad": 2.5,
		"final_pitch_rate_rad_s": -20.0,
		"final_height_error_m": 0.05,
		"target_arrival_used_for_phase_transition": false,
		"local_load_is_generalized_per_foot_allocation": false,
		"root_rescue_operation_count": 0,
		"foot_pin_operation_count": 0,
		"pose_teleport_operation_count": 0,
		"automatic_creature_guidance_operation_count": 0,
		"per_contact_commands_are_measurements": false,
		"free_3d_stance_established": false,
	}


static func _valid_active(contract: Dictionary) -> Dictionary:
	var summary := _common(contract, true)
	summary["catch_plan_count"] = 1
	summary["catch_command_count"] = 479
	summary["first_catch_command_tick"] = 121
	summary["planner_selected"] = true
	summary["selected_candidate_id"] = "forward_catch"
	summary["predicted_contact_tick"] = 167
	summary["predicted_reach_time_s"] = 0.38
	summary["planner_support_improvement_m"] = 0.245
	summary["first_touch_tick"] = 167
	summary["first_load_tick"] = 168
	summary["first_bearing_tick"] = 169
	summary["final_phase"] = "BEARING"
	summary["phase_trace"] = ["TOUCH", "LOAD", "BEARING"]
	summary["stance_return_tick"] = 353
	summary["stance_world_hold_active"] = true
	summary["stance_world_hold_command_count"] = 247
	summary["stabilize_handoff_command_count"] = 247
	summary["touchdown_approach_speed_m_s"] = 0.43
	summary["peak_predicted_local_normal_load_n"] = 22.0
	summary["support_interval_after_m"] = 0.30
	summary["measured_support_improvement_m"] = 0.19
	summary["maximum_horizontal_position_error_m"] = 0.034
	summary["maximum_horizontal_speed_m_s"] = 0.16
	summary["maximum_commanded_tangent_n"] = 5.0
	summary["maximum_applied_torque_nm"] = 16.0
	summary["actuator_saturation_count"] = 0
	summary["allocator_clamp_count"] = 6
	summary["maximum_normal_load_rate_n_s"] = 1200.0
	summary["pitch_at_first_bearing_rad"] = -0.30
	summary["maximum_pitch_excursion_rad"] = 0.33
	summary["maximum_height_error_m"] = 0.0065
	summary["post_stance_sample_count"] = 247
	summary["maximum_post_stance_pitch_error_rad"] = 0.021
	summary["maximum_post_stance_pitch_rate_rad_s"] = 0.032
	summary["maximum_post_stance_height_error_m"] = 0.0006
	summary["final_pitch_rad"] = -0.014
	summary["final_pitch_rate_rad_s"] = -0.001
	summary["final_height_error_m"] = 0.00002
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
