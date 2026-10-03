extends SceneTree
# gdlint: disable=max-line-length

## BR7.3 live two-leg planar height/pitch control and support-loss event.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const AnalyzerScript := preload("res://scripts/lab/mechanics/planar_stance_analyzer.gd")
const RigScript := preload("res://scripts/lab/rigs/planar_two_leg_stance_rig.gd")

const PHYSICS_HZ := 60
const CONFIGURATION := {
	"schema_version": "planar_stance_configuration_v1",
	"physics_hz": PHYSICS_HZ,
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
const ACTUATOR_CONFIGURATION := {
	"schema_version": "actuator_spec_v1",
	"actuator_id": "br7_planar_stance_actuator",
	"enabled": true,
	"max_isometric_torque_nm": 60.0,
	"no_load_speed_rad_s": 1000.0,
	"max_positive_power_w": 0.0,
	"max_absorption_power_w": 0.0,
	"max_eccentric_multiplier": 1.25,
	"activation_time_s": 0.0011,
	"deactivation_time_s": 100.0,
	"max_torque_rate_nm_s": 12000.0,
	"structural_torque_limit_nm": 75.0,
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
	print("=== Experimental BR7.3 live planar two-leg stance ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var built := AnalyzerScript.build(CONFIGURATION)
	var actuator := ActuatorSpecScript.compile(ACTUATOR_CONFIGURATION)
	_check(
		bool(built.get("ok", false)) and bool(actuator.get("ok", false)),
		"digest-bound planar stance and finite actuator contracts seal"
	)
	if not bool(built.get("ok", false)) or not bool(actuator.get("ok", false)):
		printerr("  stance_contract=", built, " actuator_failure=", actuator)
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var rig = RigScript.new()
	var run: Dictionary = await rig.run(self, built["contract"], actuator["spec"])
	_check(bool(run.get("ok", false)), "live planar fixture returns a complete summary")
	if not bool(run.get("ok", false)):
		printerr("  rig_failure=", run)
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var summary: Dictionary = run["summary"]
	print("  summary=", summary)
	var analysis := AnalyzerScript.analyze(built["contract"], summary)
	_check(
		bool(analysis.get("ok", false)) and bool(analysis.get("accepted", false)),
		"digest-bound BR7 analyzer accepts the exact live run"
	)
	if not bool(analysis.get("ok", false)) or not bool(analysis.get("accepted", false)):
		printerr("  analysis_failure=", analysis)
	_check(
		(
			bool(summary["fixture_complete"])
			and bool(summary["planar_guide_exact"])
			and bool(summary["hinges_exact"])
			and bool(summary["all_receipts_complete"])
		),
		"planar guide, four passive hinges, command receipts, and fixture remain exact"
	)
	_check(
		(
			int(summary["allocator_infeasible_before_loss_count"]) == 0
			and float(summary["allocation_maximum_force_residual_n"]) <= 1.0e-7
			and float(summary["allocation_maximum_moment_residual_nm"]) <= 1.0e-7
		),
		"every pre-loss desired planar wrench is arithmetically feasible and exact"
	)
	_check(
		(
			float(summary["left_contact_fraction"]) >= 0.98
			and float(summary["right_contact_fraction"]) >= 0.98
		),
		"both ordinary distal contacts remain bearing during the static window"
	)
	_check(
		(
			(
				float(summary["static_maximum_height_error_m"])
				<= float(CONFIGURATION["maximum_static_height_error_m"])
			)
			and (
				float(summary["static_maximum_pitch_error_rad"])
				<= float(CONFIGURATION["maximum_static_pitch_error_rad"])
			)
			and (
				float(summary["static_maximum_support_error_n"])
				<= float(CONFIGURATION["maximum_static_support_error_n"])
			)
		),
		"physical static height, pitch, and aggregate support stay bounded"
	)
	_check(
		(
			(
				float(summary["static_maximum_realized_vertical_wrench_residual_n"])
				<= float(CONFIGURATION["maximum_realized_vertical_wrench_residual_n"])
			)
			and (
				float(summary["static_maximum_realized_pitch_wrench_residual_nm"])
				<= float(CONFIGURATION["maximum_realized_pitch_wrench_residual_nm"])
			)
		),
		"momentum-derived realized planar wrench stays inside the calibrated fixture bound"
	)
	_check(
		(
			int(summary["disturbance_operation_count"]) == 1
			and float(summary["maximum_pitch_excursion_rad"]) >= 0.01
			and float(summary["signed_pitch_excursion_rad"]) > 0.0
			and bool(summary["disturbance_recovered"])
		),
		"declared positive pitch impulse produces the predicted sign and bounded recovery"
	)
	_check(
		(
			int(summary["support_loss_event_count"]) == 1
			and String(summary["support_loss_response"]) == "DECLARE_INFEASIBLE_STOP"
			and bool(summary["controlled_stop"])
		),
		"right support removal emits one event and stops on infeasible single support"
	)
	_check(
		(
			int(summary["root_rescue_operation_count"]) == 0
			and int(summary["foot_pin_operation_count"]) == 0
			and int(summary["passive_operation_count"]) == 0
			and not bool(summary["per_contact_commands_are_measurements"])
			and not bool(summary["per_foot_measured_load_allocation_available"])
		),
		"no root rescue, foot pin, passive capacity, or false measured-load claim exists"
	)
	_check(
		(
			float(summary["maximum_pairing_residual_nm"]) <= 1.0e-9
			and float(summary["maximum_applied_torque_nm"]) <= 75.0
		),
		"all four actuators remain paired and inside the structural envelope"
	)
	var exclusions: Array = analysis.get("does_not_establish", [])
	_check(
		(
			bool(analysis.get("out_of_plane_scaffold_present", false))
			and exclusions.has("free_3d_standing")
			and exclusions.has("bracing")
			and exclusions.has("walking")
			and exclusions.has("automatic_creature_guidance")
		),
		"positive planar result remains fenced from free 3D standing and locomotion"
	)
	Engine.physics_ticks_per_second = original_ticks
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
