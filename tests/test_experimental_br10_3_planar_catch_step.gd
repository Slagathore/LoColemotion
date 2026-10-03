extends SceneTree
# gdlint: disable=max-line-length

## BR10.3 live planar new-bearing-contact catch commissioning.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const AnalyzerScript := preload("res://scripts/lab/mechanics/reachable_catch_step_analyzer.gd")
const RigScript := preload("res://scripts/lab/rigs/reachable_catch_step_rig.gd")

const PHYSICS_HZ := 120
const ACTUATOR_CONFIGURATION := {
	"schema_version": "actuator_spec_v1",
	"actuator_id": "br10_planar_catch_actuator",
	"enabled": true,
	"max_isometric_torque_nm": 75.0,
	"no_load_speed_rad_s": 50.0,
	"max_positive_power_w": 0.0,
	"max_absorption_power_w": 0.0,
	"max_eccentric_multiplier": 1.25,
	"activation_time_s": 0.0011,
	"deactivation_time_s": 100.0,
	"max_torque_rate_nm_s": 10000.0,
	"structural_torque_limit_nm": 85.0,
	"tear_dwell_s": 0.05,
	"capacity_source": "explicit_lab",
	"muscle_pcsa_m2": 0.0,
	"specific_tension_pa": 0.0,
	"moment_arm_m": 0.0,
}

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR10.3 live planar reachable catch ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var actuator := ActuatorSpecScript.compile(ACTUATOR_CONFIGURATION)
	_check(bool(actuator.get("ok", false)), "finite four-joint catch actuator seals")
	if not bool(actuator.get("ok", false)):
		printerr("  actuator_failure=", actuator)
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var built := AnalyzerScript.build(_configuration(String(actuator["spec"]["spec_sha256"])))
	_check(bool(built.get("ok", false)), "digest-bound paired BR10 catch contract seals")
	if not bool(built.get("ok", false)):
		printerr("  analyzer_build_failure=", built)
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var configuration: Dictionary = built["contract"]
	var rig = RigScript.new()
	var active: Dictionary = await rig.run_trial(self, configuration, actuator["spec"], true)
	_check(bool(active.get("ok", false)), "active catch world returns one summary")
	if not bool(active.get("ok", false)):
		printerr("  active_failure=", active)
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var catch_summary: Dictionary = active["summary"]
	print("  active=", catch_summary)
	var control: Dictionary = await rig.run_trial(self, configuration, actuator["spec"], false)
	_check(bool(control.get("ok", false)), "matched no-catch control returns one summary")
	if not bool(control.get("ok", false)):
		printerr("  control_failure=", control)
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var control_summary: Dictionary = control["summary"]
	print("  control=", control_summary)
	var analysis := AnalyzerScript.analyze(configuration, catch_summary, control_summary)
	_check(
		bool(analysis.get("ok", false)) and bool(analysis.get("accepted", false)),
		"digest-bound BR10 analyzer accepts the exact paired live evidence"
	)
	if not bool(analysis.get("ok", false)) or not bool(analysis.get("accepted", false)):
		printerr("  analysis_failure=", analysis)
	_check(
		bool(catch_summary["fixture_complete"]) and bool(control_summary["fixture_complete"]),
		"both paired worlds execute their complete declared horizons"
	)
	_check(
		(
			bool(catch_summary["planner_selected"])
			and int(catch_summary["catch_plan_count"]) == 1
			and int(catch_summary["first_catch_command_tick"]) == 121
			and String(catch_summary["selected_candidate_id"]) == "forward_catch"
		),
		"post-observation planner selects one support-expanding catch target"
	)
	_check(
		(
			int(catch_summary["initial_right_contact_count"]) == 0
			and int(catch_summary["first_touch_tick"]) > 121
			and int(catch_summary["first_load_tick"]) > int(catch_summary["first_touch_tick"])
			and int(catch_summary["first_bearing_tick"]) > int(catch_summary["first_load_tick"])
			and String(catch_summary["final_phase"]) == "BEARING"
		),
		"previously unloaded limb creates ordered new TOUCH, LOAD, and BEARING evidence"
	)
	_check(
		(
			int(catch_summary["first_touch_tick"]) <= int(catch_summary["predicted_contact_tick"])
			and float(catch_summary["measured_support_improvement_m"]) >= 0.15
			and (
				float(catch_summary["support_interval_after_m"])
				> float(catch_summary["support_interval_before_m"])
			)
		),
		"measured contact meets the conservative clock and expands the support interval"
	)
	_check(
		(
			float(catch_summary["touchdown_approach_speed_m_s"]) <= 0.50
			and float(catch_summary["peak_predicted_local_normal_load_n"]) <= 100.0
			and int(catch_summary["non_distal_contact_count"]) == 0
		),
		"semantic distal touchdown stays inside the preregistered impact envelope"
	)
	_check(
		(
			int(catch_summary["stance_return_tick"]) > int(catch_summary["first_bearing_tick"])
			and absf(float(catch_summary["final_pitch_rad"])) <= 0.025
			and absf(float(catch_summary["final_pitch_rate_rad_s"])) <= 0.08
			and float(catch_summary["final_height_error_m"]) <= 0.025
		),
		"new bearing contact returns the scaffolded body to the declared stance dwell"
	)
	_check(
		(
			int(control_summary["catch_plan_count"]) == 0
			and (
				int(control_summary["first_touch_tick"])
				> int(catch_summary["predicted_contact_tick"])
			)
			and float(control_summary["touchdown_approach_speed_m_s"]) > 10.0
			and float(control_summary["peak_predicted_local_normal_load_n"]) > 100.0
			and int(control_summary["stance_return_tick"]) < 0
		),
		"no-catch control reaches only a late unbounded crash contact and never returns"
	)
	_check(
		(
			float(catch_summary["maximum_pairing_residual_nm"]) <= 1.0e-9
			and int(catch_summary["actuator_saturation_count"]) == 0
			and (
				float(catch_summary["maximum_normal_load_rate_n_s"])
				<= float(configuration["maximum_normal_load_rate_n_s"]) + 1.0e-7
			)
			and int(catch_summary["post_stance_bearing_loss_count"]) == 0
			and bool(catch_summary["all_receipts_complete"])
			and bool(catch_summary["contact_capacity_complete"])
		),
		"catch retains paired finite actuation, complete receipts, and contact capacity"
	)
	_check(
		(
			bool(catch_summary["planar_guide_exact"])
			and bool(catch_summary["hinges_exact"])
			and not bool(catch_summary["target_arrival_used_for_phase_transition"])
			and not bool(catch_summary["local_load_is_generalized_per_foot_allocation"])
		),
		"material planar scaffold and observation-only phase/load boundaries remain explicit"
	)
	_check(
		(
			int(catch_summary["root_rescue_operation_count"]) == 0
			and int(catch_summary["foot_pin_operation_count"]) == 0
			and int(catch_summary["pose_teleport_operation_count"]) == 0
			and int(catch_summary["automatic_creature_guidance_operation_count"]) == 0
			and not bool(catch_summary["free_3d_stance_established"])
		),
		"catch contains no root rescue, pin, teleport, guidance, or free-3D claim"
	)
	Engine.physics_ticks_per_second = original_hz
	_finish()


static func _configuration(actuator_sha: String) -> Dictionary:
	var configuration := {
		"schema_version": "reachable_catch_step_experiment_configuration_v1",
		"physics_hz": PHYSICS_HZ,
		"disturbance_tick": 120,
		"catch_start_tick": 121,
		"catch_ramp_ticks": 50,
		"trial_end_tick": 600,
		"baseline_height_m": 0.70,
		"root_height_m": 0.70,
		"root_mass_kg": 6.0,
		"link_mass_kg": 0.25,
		"link_length_m": 0.40,
		"foot_radius_m": 0.055,
		"initial_q1_rad": 1.000,
		"initial_q2_rad": -1.486,
		"target_q1_rad": 0.880,
		"target_q2_rad": -0.901,
		"joint_position_gain_nm_rad": 8.0,
		"joint_velocity_gain_nm_s_rad": 1.2,
		"height_position_gain_n_m": 600.0,
		"height_velocity_gain_n_s_m": 100.0,
		"pitch_position_gain_nm_rad": 20.0,
		"pitch_velocity_gain_nm_s_rad": 10.0,
		"handoff_pitch_position_gain_nm_rad": 2.0,
		"handoff_pitch_velocity_gain_nm_s_rad": 0.10,
		"handoff_joint_position_gain_nm_rad": 25.0,
		"handoff_joint_velocity_gain_nm_s_rad": 4.0,
		"horizontal_position_gain_n_m": 40.0,
		"horizontal_velocity_gain_n_s_m": 30.0,
		"horizontal_friction_reserve_fraction": 0.70,
		"maximum_contact_normal_n": 120.0,
		"minimum_bearing_command_n": 3.0,
		"maximum_normal_load_rate_n_s": 1200.0,
		"friction_coefficient": 1.0,
		"pitch_impulse_n_m_s": 0.005,
		"reaction_deadline_s": 0.55,
		"declared_path_clearance_m": 0.08,
		"catch_path_lift_m": 0.04,
		"catch_target_penetration_m": 0.01,
		"planner_joint_speed_bounds_rad_s": [1.8, 1.8],
		"contact_confirm_ticks": 1,
		"load_confirm_ticks": 1,
		"bearing_confirm_ticks": 3,
		"load_enter_n": 0.5,
		"bearing_enter_n": 1.0,
		"maximum_separating_speed_m_s": 0.05,
		"stance_pitch_tolerance_rad": 0.025,
		"stance_pitch_rate_tolerance_rad_s": 0.08,
		"stance_height_tolerance_m": 0.025,
		"stance_dwell_ticks": 15,
		"actuator_spec_sha256": actuator_sha,
		"planner_configuration":
		{
			"schema_version": "reachable_catch_step_planner_configuration_v1",
			"planner_id": "br10_live_planar_catch",
			"physics_hz": PHYSICS_HZ,
			"actuation_latency_s": 0.03,
			"touchdown_confirm_ticks": 3,
			"minimum_swing_clearance_m": 0.025,
			"minimum_support_improvement_m": 0.15,
			"maximum_candidate_distance_m": 0.90,
			"deadline_reserve_s": 0.05,
			"score_time_weight": 1.0,
			"score_support_weight": 1.0,
			"root_assist_allowed": false,
			"foot_pin_allowed": false,
			"pose_teleport_allowed": false,
			"automatic_creature_guidance_allowed": false,
		},
		"maximum_touchdown_approach_speed_m_s": 0.50,
		"maximum_predicted_local_normal_load_n": 100.0,
		"minimum_measured_support_improvement_m": 0.15,
		"maximum_support_prediction_error_m": 0.08,
		"maximum_pairing_residual_nm": 1.0e-9,
		"maximum_applied_torque_nm": 75.0,
		"maximum_horizontal_position_error_m": 0.05,
		"maximum_horizontal_speed_m_s": 0.20,
		"maximum_commanded_tangent_n": 10.0,
		"maximum_pitch_excursion_rad": 0.35,
		"maximum_height_error_m": 0.01,
		"minimum_post_stance_samples": 200,
		"maximum_post_stance_pitch_error_rad": 0.025,
		"maximum_post_stance_pitch_rate_rad_s": 0.08,
		"maximum_post_stance_height_error_m": 0.002,
		"maximum_final_pitch_error_rad": 0.025,
		"maximum_final_pitch_rate_rad_s": 0.08,
		"maximum_final_height_error_m": 0.002,
		"minimum_control_touchdown_approach_speed_m_s": 10.0,
		"minimum_control_predicted_local_normal_load_n": 100.0,
		"minimum_control_pitch_excursion_rad": 2.50,
		"out_of_plane_planar_guide_enabled": true,
		"preparation_root_freeze_enabled": true,
		"built_in_motors_enabled": false,
		"joint_limits_enabled": false,
		"passive_tissues_enabled": false,
		"controller_root_force_enabled": false,
		"foot_pin_enabled": false,
		"pose_teleport_enabled": false,
		"per_foot_load_sensor_enabled": false,
		"automatic_creature_guidance_enabled": false,
		"free_3d_stance_claim_enabled": false,
		"articulated_limb_generality_claim_enabled": false,
		"fall_arrest_claim_enabled": false,
		"getting_up_claim_enabled": false,
		"gait_claim_enabled": false,
		"walking_claim_enabled": false,
		"scaffold_constrained_planar_catch_claim_enabled": true,
	}
	return configuration


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
