extends SceneTree
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length

## BR13.4 digest-bound paired live Godot/Jolt canonical prone-to-stance campaign.

const AnalyzerScript := preload("res://scripts/lab/mechanics/canonical_planar_get_up_analyzer.gd")
const RigScript := preload("res://scripts/lab/rigs/canonical_planar_get_up_rig.gd")

const PHYSICS_HZ := 120

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR13.4 live canonical planar get-up ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var contract_result := AnalyzerScript.build(_contract_source())
	_check(bool(contract_result.get("ok", false)), "digest-bound live get-up contract seals")
	if not bool(contract_result.get("ok", false)):
		printerr("  contract_failure=", contract_result)
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var contract: Dictionary = contract_result["contract"]
	var rig = RigScript.new()
	var active_summaries: Array = []
	var control_summaries: Array = []
	var all_worlds_complete := true
	for seed_value in contract["seeds"]:
		var seed := int(seed_value)
		var active_result := await rig.run_trial(self, contract, seed, true)
		var control_result := await rig.run_trial(self, contract, seed, false)
		if not bool(active_result.get("ok", false)):
			printerr("  active_failure_seed_", seed, "=", active_result)
			all_worlds_complete = false
		if not bool(control_result.get("ok", false)):
			printerr("  control_failure_seed_", seed, "=", control_result)
			all_worlds_complete = false
		if not all_worlds_complete:
			break
		var active_summary: Dictionary = active_result["summary"]
		var control_summary: Dictionary = control_result["summary"]
		active_summaries.append(active_summary)
		control_summaries.append(control_summary)
		print(
			(
				(
					"  seed=%d active_phase=%s active_gain_m=%.9f active_work_j=%.9f "
					+ "control_phase=%s control_gain_m=%.9f"
				)
				% [
					seed,
					String(active_summary["final_supervisor_phase"]),
					float(active_summary["com_height_gain_m"]),
					float(active_summary["actuator_positive_work_j"]),
					String(control_summary["final_supervisor_phase"]),
					float(control_summary["com_height_gain_m"]),
				]
			)
		)
	_check(all_worlds_complete, "all three active/control Godot/Jolt pairs return summaries")
	if not all_worlds_complete:
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var analysis := AnalyzerScript.analyze(contract, active_summaries, control_summaries)
	_check(
		bool(analysis.get("ok", false)),
		"strict paired campaign analyzer accepts the evidence shape"
	)
	_check(
		bool(analysis.get("accepted", false)), "all three paired live cells meet the sealed claim"
	)
	if not bool(analysis.get("accepted", false)):
		printerr("  analysis=", analysis)
	var all_exact := true
	var all_initially_prone := true
	var all_active_complete := true
	var all_controls_fail := true
	var all_com_gates := true
	var all_energy_gates := true
	var all_guide_gates := true
	var all_handoffs_exclusive := true
	var all_receipts_complete := true
	var all_hidden_operations_zero := true
	var all_nonclaims_preserved := true
	for index in active_summaries.size():
		var active: Dictionary = active_summaries[index]
		var control: Dictionary = control_summaries[index]
		all_exact = (
			all_exact
			and bool(active["fixture_complete"])
			and bool(control["fixture_complete"])
			and bool(active["planar_guide_exact"])
			and bool(active["front_hinge_exact"])
			and bool(active["rear_hinge_exact"])
		)
		all_initially_prone = (
			all_initially_prone
			and String(active["initial_pose_state"]) == "PRONE"
			and String(control["initial_pose_state"]) == "PRONE"
		)
		all_active_complete = (
			all_active_complete
			and bool(active["complete_observed"])
			and String(active["final_supervisor_phase"]) == "COMPLETE"
			and String(active["final_pose_state"]) == "STANCE"
		)
		all_controls_fail = (
			all_controls_fail
			and not bool(control["complete_observed"])
			and String(control["final_supervisor_phase"]) == "FAILED"
			and String(control["final_pose_state"]) == "PRONE"
		)
		all_com_gates = (
			all_com_gates
			and float(active["com_height_gain_m"]) >= 0.35
			and float(control["com_height_gain_m"]) <= 0.01
		)
		all_energy_gates = (
			all_energy_gates
			and bool(active["energy_reconciliation_accepted"])
			and float(active["actuator_positive_work_j"]) > 0.0
			and float(active["inferred_contact_dissipation_j"]) >= 0.0
			and absf(float(active["energy_balance_residual_j"])) <= 0.01
		)
		all_guide_gates = (
			all_guide_gates
			and absf(float(active["inferred_guide_linear_impulse_z_n_s"])) <= 1.0e-6
			and absf(float(active["inferred_guide_work_j"])) <= 1.0e-9
			and float(active["maximum_out_of_plane_drift_m"]) <= 1.0e-6
		)
		all_handoffs_exclusive = (
			all_handoffs_exclusive
			and int(active["recovery_command_after_handoff_count"]) == 0
			and int(active["stance_command_during_dwell_count"]) > 0
		)
		all_receipts_complete = (
			all_receipts_complete
			and bool(active["all_receipts_complete"])
			and float(active["maximum_pairing_residual_nm"]) <= 1.0e-9
			and int(active["recovery_command_count"]) > 0
			and int(active["stance_command_count"]) > 0
		)
		all_hidden_operations_zero = (
			all_hidden_operations_zero
			and int(active["root_rescue_operation_count"]) == 0
			and int(active["foot_pin_operation_count"]) == 0
			and int(active["pose_teleport_operation_count"]) == 0
			and int(active["automatic_creature_guidance_operation_count"]) == 0
		)
		all_nonclaims_preserved = (
			all_nonclaims_preserved
			and not bool(active["free_3d_recovery_established"])
			and not bool(active["morphology_transfer_established"])
			and not bool(active["gait_established"])
			and not bool(active["walking_established"])
		)
	_check(all_exact, "all paired worlds preserve exact guide, passive hinges, and fixtures")
	_check(all_initially_prone, "every active/control pair begins in observed semantic prone")
	_check(all_active_complete, "every active seed completes recovery and stable stance dwell")
	_check(all_controls_fail, "every same-state zero-command control remains prone")
	_check(all_com_gates, "active COM rise clears 0.35 m while controls clear no rise gate")
	_check(all_energy_gates, "transition-integrated actuator work closes every energy ledger")
	_check(all_guide_gates, "material guide impulse, drift, and work remain inside sealed bounds")
	_check(all_handoffs_exclusive, "recovery-to-stance controller handoff is exclusive")
	_check(all_receipts_complete, "finite paired actuation is command- and receipt-complete")
	_check(all_hidden_operations_zero, "no root rescue, foot pin, teleport, or guidance occurs")
	_check(all_nonclaims_preserved, "get-up evidence cannot become free recovery or walking")
	_check(
		_rejected(
			AnalyzerScript.analyze(
				contract,
				_mutated_summary_set(active_summaries, "phase_trace", ["CONFIRM_PRONE"]),
				control_summaries
			)
		),
		"truncated recovery sequence fails closed"
	)
	_check(
		_rejected(
			AnalyzerScript.analyze(
				contract,
				_mutated_summary_set(active_summaries, "walking_established", true),
				control_summaries
			)
		),
		"forged walking conclusion fails closed"
	)
	_check(
		_rejected(
			AnalyzerScript.analyze(
				contract,
				_mutated_summary_set(active_summaries, "inferred_guide_linear_impulse_z_n_s", 1.0),
				control_summaries
			)
		),
		"material undeclared guide impulse fails closed"
	)
	_check(
		_rejected(
			AnalyzerScript.analyze(
				contract,
				_mutated_summary_set(active_summaries, "energy_balance_residual_j", 1.0),
				control_summaries
			)
		),
		"unclosed energy ledger fails closed"
	)
	_check(
		_rejected(
			AnalyzerScript.analyze(
				contract,
				_mutated_summary_set(active_summaries, "recovery_command_after_handoff_count", 1),
				control_summaries
			)
		),
		"overlapping recovery controller after handoff fails closed"
	)
	_check(
		_rejected(
			AnalyzerScript.analyze(
				contract,
				active_summaries,
				_mutated_summary_set(control_summaries, "recovery_enabled", true)
			)
		),
		"active command substitution into a control fails closed"
	)
	var tampered_contract := contract.duplicate(true)
	tampered_contract["maximum_energy_residual_j"] = 2.0
	_check(
		_rejected(AnalyzerScript.analyze(tampered_contract, active_summaries, control_summaries)),
		"post-seal contract mutation fails digest verification"
	)
	Engine.physics_ticks_per_second = original_hz
	_finish()


static func _contract_source() -> Dictionary:
	return {
		"schema_version": "canonical_planar_get_up_contract_v1",
		"profile_configuration": _profile_configuration(),
		"actuator_configuration": _actuator_configuration(),
		"rig_configuration": _rig_configuration(),
		"seeds": [13001, 13002, 13003],
		"minimum_active_com_height_gain_m": 0.35,
		"maximum_control_com_height_gain_m": 0.01,
		"maximum_energy_residual_j": 0.01,
		"maximum_abs_guide_linear_impulse_z_n_s": 1.0e-6,
		"maximum_out_of_plane_drift_m": 1.0e-6,
		"maximum_roll_yaw_rad": 1.0e-6,
		"maximum_final_linear_speed_m_s": 0.10,
		"maximum_final_angular_speed_rad_s": 0.10,
		"maximum_root_pitch_rad": 0.05,
		"maximum_pairing_residual_nm": 1.0e-9,
		"maximum_applied_torque_nm": 60.0,
		"constrained_planar_get_up_claim_enabled": true,
		"free_3d_recovery_claim_enabled": false,
		"morphology_transfer_claim_enabled": false,
		"gait_claim_enabled": false,
		"walking_claim_enabled": false,
		"automatic_creature_guidance_enabled": false,
	}


static func _profile_configuration() -> Dictionary:
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


static func _rig_configuration() -> Dictionary:
	return {
		"physics_hz": PHYSICS_HZ,
		"trial_ticks": 720,
		"gravity_m_s2": 9.8,
		"root_mass_kg": 6.0,
		"root_size_m": [0.60, 0.16, 0.20],
		"initial_root_height_m": 0.085,
		"reference_stance_height_m": 0.51,
		"hip_half_span_m": 0.22,
		"limb_pair_mass_kg": 1.0,
		"limb_length_m": 0.45,
		"limb_width_m": 0.025,
		"limb_depth_m": 0.08,
		"foot_radius_m": 0.06,
		"initial_splay_angle_rad": 1.5152,
		"floor_friction": 0.60,
		"seed_initial_velocity_m_s": 0.005,
		"joint_position_gain_nm_rad": 80.0,
		"joint_velocity_gain_nm_s_rad": 12.0,
		"pose_configuration":
		{
			"schema_version": "quadruped_recovery_pose_configuration_v1",
			"prone_height_ratio_max": 0.35,
			"stance_height_ratio_min": 0.82,
			"stable_linear_speed_m_s": 0.10,
			"stable_angular_speed_rad_s": 0.10,
			"automatic_creature_guidance_allowed": false,
		},
		"supervisor_configuration":
		{
			"schema_version": "recovery_phase_supervisor_v1",
			"supervisor_id": "br13_live_canonical_get_up",
			"prone_confirm_ticks": 12,
			"stance_dwell_ticks": 30,
			"rise_height_ratio_min": 0.75,
			"phase_timeout_ticks":
			{
				"CONFIRM_PRONE": 60,
				"ESTABLISH_DISTAL_CONTACT": 60,
				"RAISE_BODY": 420,
				"STANCE_HANDOFF": 180,
				"STANCE_DWELL": 180,
			},
			"automatic_creature_guidance_allowed": false,
		},
		"energy_configuration":
		{
			"schema_version": "recovery_energy_ledger_v1",
			"total_mass_kg": 8.0,
			"gravity_m_s2": 9.8,
			"minimum_height_gain_m": 0.30,
			"minimum_torque_reserve_fraction": 0.20,
			"minimum_power_reserve_fraction": 0.20,
			"minimum_structural_reserve_fraction": 0.20,
			"maximum_abs_inferred_guide_work_j": 0.05,
			"maximum_energy_balance_residual_j": 0.05,
			"automatic_creature_guidance_allowed": false,
		},
		"energy_preflight":
		{
			"schema_version": "recovery_energy_preflight_v1",
			"start_com_height_m": 0.082,
			"target_com_height_m": 0.454,
			"available_positive_work_j": 160.0,
			"required_peak_torque_nm": 20.0,
			"available_peak_torque_nm": 60.0,
			"required_peak_power_w": 100.0,
			"available_peak_power_w": 500.0,
			"required_structural_torque_nm": 30.0,
			"available_structural_torque_nm": 80.0,
		},
	}


static func _actuator_configuration() -> Dictionary:
	return {
		"schema_version": "actuator_spec_v1",
		"actuator_id": "br13_symmetry_collapsed_limb_pair",
		"enabled": true,
		"max_isometric_torque_nm": 60.0,
		"no_load_speed_rad_s": 30.0,
		"max_positive_power_w": 500.0,
		"max_absorption_power_w": 800.0,
		"max_eccentric_multiplier": 1.5,
		"activation_time_s": 0.005,
		"deactivation_time_s": 0.050,
		"max_torque_rate_nm_s": 8000.0,
		"structural_torque_limit_nm": 80.0,
		"tear_dwell_s": 0.05,
		"capacity_source": "explicit_lab",
		"muscle_pcsa_m2": 0.0,
		"specific_tension_pa": 0.0,
		"moment_arm_m": 0.0,
	}


static func _mutated_summary_set(summaries: Array, field: String, value: Variant) -> Array:
	var result := summaries.duplicate(true)
	(result[0] as Dictionary)[field] = value
	return result


static func _rejected(result: Dictionary) -> bool:
	return not bool(result.get("ok", false)) or not bool(result.get("accepted", false))


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
