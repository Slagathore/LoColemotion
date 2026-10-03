extends SceneTree
# gdlint: disable=max-line-length

## BR9.3 paired live Godot/Jolt trial: no-brace control versus the exact
## existing-contact brace controller on the inherited BR7 planar scaffold.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const AnalyzerScript := preload("res://scripts/lab/mechanics/existing_contact_brace_analyzer.gd")
const RigScript := preload("res://scripts/lab/rigs/existing_contact_brace_rig.gd")

const PHYSICS_HZ := 60
const CONFIGURATION := {
	"schema_version": "existing_contact_brace_experiment_configuration_v1",
	"physics_hz": PHYSICS_HZ,
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
	"sha256:0000000000000000000000000000000000000000000000000000000000000000",
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
const ACTUATOR_CONFIGURATION := {
	"schema_version": "actuator_spec_v1",
	"actuator_id": "br9_existing_contact_brace_actuator",
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
	print("=== Experimental BR9.3 live existing-contact brace ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var actuator := ActuatorSpecScript.compile(ACTUATOR_CONFIGURATION)
	_check(bool(actuator.get("ok", false)), "finite BR9 actuator contract seals")
	if not bool(actuator.get("ok", false)):
		printerr("  actuator_failure=", actuator)
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var configuration := CONFIGURATION.duplicate(true)
	configuration["actuator_spec_sha256"] = String(actuator["spec"]["spec_sha256"])
	var built := AnalyzerScript.build(configuration)
	_check(bool(built.get("ok", false)), "digest-bound paired BR9 experiment contract seals")
	if not bool(built.get("ok", false)):
		printerr("  analyzer_build_failure=", built)
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var contract: Dictionary = built["contract"]
	var rig = RigScript.new()
	var baseline_run: Dictionary = await rig.run_trial(self, contract, actuator["spec"], false)
	var controlled_run: Dictionary = await rig.run_trial(self, contract, actuator["spec"], true)
	_check(
		bool(baseline_run.get("ok", false)) and bool(controlled_run.get("ok", false)),
		"fresh no-brace and existing-contact-brace worlds return complete summaries"
	)
	if not bool(baseline_run.get("ok", false)) or not bool(controlled_run.get("ok", false)):
		printerr("  baseline_failure=", baseline_run, " controlled_failure=", controlled_run)
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var baseline: Dictionary = baseline_run["summary"]
	var controlled: Dictionary = controlled_run["summary"]
	print("  baseline=", baseline)
	print("  controlled=", controlled)
	var analysis := AnalyzerScript.analyze(contract, baseline, controlled)
	_check(
		bool(analysis.get("ok", false)) and bool(analysis.get("accepted", false)),
		"sealed analyzer accepts the exact paired physical result at the bounded claim scope"
	)
	if not bool(analysis.get("accepted", false)):
		printerr("  analysis_failure=", analysis)
	_check(
		(
			bool(baseline["fixture_complete"])
			and bool(controlled["fixture_complete"])
			and bool(baseline["planar_guide_exact"])
			and bool(controlled["planar_guide_exact"])
			and bool(baseline["hinges_exact"])
			and bool(controlled["hinges_exact"])
			and bool(baseline["all_receipts_complete"])
			and bool(controlled["all_receipts_complete"])
		),
		"both fixtures retain the exact guide, four passive hinges, and receipt chain"
	)
	_check(
		(
			int(baseline["disturbance_operation_count"]) == 1
			and int(controlled["disturbance_operation_count"]) == 1
			and float(baseline["post_impulse_angular_momentum_z_kg_m2_s"]) > 0.0
			and float(controlled["post_impulse_angular_momentum_z_kg_m2_s"]) > 0.0
		),
		"both worlds receive one same-sign declared pitch impulse"
	)
	_check(
		(
			int(baseline["brace_command_count"]) == 0
			and int(baseline["first_brace_command_tick"]) == -1
			and int(controlled["brace_command_count"]) > 0
			and (
				int(controlled["first_brace_command_tick"]) == int(contract["disturbance_tick"]) + 1
			)
		),
		"the controller activates only on the first post-impulse observation"
	)
	_check(
		(
			(
				absf(float(controlled["evaluation_angular_momentum_z_kg_m2_s"]))
				< absf(float(baseline["evaluation_angular_momentum_z_kg_m2_s"]))
			)
			and (
				float(controlled["angular_momentum_abs_area_kg_m2"])
				< float(baseline["angular_momentum_abs_area_kg_m2"])
			)
		),
		"legal existing-contact redistribution reduces measured tip momentum versus control"
	)
	_check(
		(
			(
				float(controlled["maximum_pitch_excursion_rad"])
				< float(baseline["maximum_pitch_excursion_rad"])
			)
			and float(controlled["maximum_height_error_m"]) <= 0.06
		),
		"the controlled world reduces pitch excursion while retaining bounded height"
	)
	_check(
		(
			float(controlled["left_existing_contact_fraction"]) >= 0.98
			and float(controlled["right_existing_contact_fraction"]) >= 0.98
			and int(controlled["new_support_contact_operation_count"]) == 0
		),
		"both original distal contacts remain bearing and no new support is commanded"
	)
	_check(
		(
			(
				float(controlled["maximum_normal_load_rate_n_s"])
				<= float(contract["brace_configuration"]["max_normal_load_rate_n_s"]) + 1.0e-6
			)
			and (
				float(controlled["maximum_tangent_load_rate_n_s"])
				<= float(contract["brace_configuration"]["max_tangent_load_rate_n_s"]) + 1.0e-6
			)
			and float(controlled["maximum_command_moment_residual_nm"]) >= 0.0
			and float(controlled["maximum_realized_moment_residual_nm"]) <= 5.0
		),
		"load-rate ceilings and desired/achieved physical wrench residual remain bounded and reported"
	)
	_check(
		(
			int(controlled["stabilize_handoff_tick"]) > int(controlled["first_brace_command_tick"])
			and String(controlled["command_handoff_state"]) == "STABILIZE"
		),
		"STABILIZE handoff occurs only after the controller's complete stable dwell"
	)
	_check(
		(
			float(controlled["maximum_pairing_residual_nm"]) <= 1.0e-9
			and float(controlled["maximum_applied_torque_nm"]) <= 75.0
			and int(controlled["actuator_saturation_count"]) == 0
		),
		"all physical brace commands remain paired and inside the finite actuator envelope"
	)
	_check(
		(
			int(controlled["root_rescue_operation_count"]) == 0
			and int(controlled["foot_pin_operation_count"]) == 0
			and int(controlled["automatic_creature_guidance_operation_count"]) == 0
			and not bool(controlled["per_contact_commands_are_measurements"])
			and not bool(controlled["per_foot_measured_load_allocation_available"])
		),
		"no root rescue, foot pin, false measurement, or guidance channel exists"
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
