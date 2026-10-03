extends SceneTree
# gdlint: disable=max-line-length

## BR11.3 paired live planar protective-fall experiment.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const AnalyzerScript := preload("res://scripts/lab/mechanics/controlled_fall_arrest_analyzer.gd")
const ControllerScript := preload("res://scripts/lab/mechanics/fall_arrest_controller.gd")
const RigScript := preload("res://scripts/lab/rigs/controlled_fall_arrest_rig.gd")

const PHYSICS_HZ := 120

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR11.3 live planar controlled fall arrest ===")
	var original_hz := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var actuator := ActuatorSpecScript.compile(_actuator_configuration())
	var controller := ControllerScript.compile(_controller_configuration())
	_check(
		bool(actuator.get("ok", false)) and bool(controller.get("ok", false)),
		"finite protective hinge actuator and pure controller seal"
	)
	if not bool(actuator.get("ok", false)) or not bool(controller.get("ok", false)):
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var built := AnalyzerScript.build(_configuration(String(actuator["spec"]["spec_sha256"])))
	_check(bool(built.get("ok", false)), "digest-bound paired BR11 contract seals")
	if not bool(built.get("ok", false)):
		printerr("  analyzer_build_failure=", built)
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var contract: Dictionary = built["contract"]
	var rig = RigScript.new()
	var active := await rig.run_trial(
		self, contract, controller["controller"], actuator["spec"], true
	)
	_check(bool(active.get("ok", false)), "active protective-fall world returns one summary")
	if not bool(active.get("ok", false)):
		printerr("  active_failure=", active)
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var active_summary: Dictionary = active["summary"]
	print("  active=", active_summary)
	var control := await rig.run_trial(
		self, contract, controller["controller"], actuator["spec"], false
	)
	_check(bool(control.get("ok", false)), "matched zero-request fall returns one summary")
	if not bool(control.get("ok", false)):
		printerr("  control_failure=", control)
		Engine.physics_ticks_per_second = original_hz
		_finish()
		return
	var control_summary: Dictionary = control["summary"]
	print("  control=", control_summary)
	var analysis := AnalyzerScript.analyze(contract, active_summary, control_summary)
	_check(
		bool(analysis.get("ok", false)) and bool(analysis.get("accepted", false)),
		"digest-bound analyzer accepts the exact paired BR11 evidence"
	)
	if not bool(analysis.get("accepted", false)):
		printerr("  analysis_failure=", analysis)
	_check(
		(
			bool(active_summary["fixture_complete"])
			and bool(control_summary["fixture_complete"])
			and int(active_summary["executed_ticks"]) == int(contract["trial_ticks"])
			and int(control_summary["executed_ticks"]) == int(contract["trial_ticks"])
		),
		"both worlds execute the complete declared horizon"
	)
	_check(
		(
			int(active_summary["first_protective_contact_tick"]) >= 0
			and bool(active_summary["protective_before_core"])
			and (
				int(active_summary["first_protective_contact_tick"])
				< int(active_summary["first_core_contact_tick"])
			)
		),
		"active finite hinge creates semantic protective contact before core impact"
	)
	_check(
		(
			(
				float(analysis["active_to_control_severity_ratio"])
				<= float(contract["maximum_active_to_control_severity_ratio"])
			)
			and (
				float(analysis["active_to_control_core_speed_ratio"])
				<= float(contract["maximum_active_to_control_core_speed_ratio"])
			)
			and (
				float(analysis["active_to_control_core_load_ratio"])
				<= float(contract["maximum_active_to_control_core_load_ratio"])
			)
		),
		"active world reduces the declared kinetic proxy, core speed, and local load witness"
	)
	_check(
		(
			bool(active_summary["angular_momentum_available"])
			and bool(control_summary["angular_momentum_available"])
			and (
				float(analysis["active_to_control_linear_momentum_ratio"])
				<= float(contract["maximum_active_to_control_linear_momentum_ratio"])
			)
		),
		"centroidal angular momentum remains available while pre-core linear momentum falls"
	)
	_check(
		(
			_vector3(active_summary["reconstructed_external_impulse_world_n_s"]).is_finite()
			and _vector3(control_summary["reconstructed_external_impulse_world_n_s"]).is_finite()
			and (
				absf(float(active_summary["energy_accounting_residual_j"]))
				<= float(contract["maximum_energy_accounting_residual_j"])
			)
			and (
				absf(float(control_summary["energy_accounting_residual_j"]))
				<= float(contract["maximum_energy_accounting_residual_j"])
			)
		),
		"whole-system external impulse and mechanical-energy accounts remain finite"
	)
	_check(
		(
			String(active_summary["final_supervisor_phase"]) == "FALLEN"
			and String(control_summary["final_supervisor_phase"]) == "FALLEN"
			and bool(active_summary["stable_fallen_observed"])
			and bool(control_summary["stable_fallen_observed"])
			and not bool(active_summary["upright_recovery_observed"])
		),
		"both worlds terminate in an observed stable fallen state without upright recovery"
	)
	_check(
		(
			bool(active_summary["all_receipts_complete"])
			and float(active_summary["maximum_pairing_residual_nm"]) <= 1.0e-9
			and int(active_summary["root_rescue_operation_count"]) == 0
			and int(active_summary["foot_pin_operation_count"]) == 0
			and int(active_summary["pose_teleport_operation_count"]) == 0
		),
		"active commands remain paired, receipted, and free of rescue, pins, or teleports"
	)
	_check(
		(
			bool(active_summary["planar_guide_exact"])
			and bool(active_summary["hinge_exact"])
			and not bool(active_summary["local_core_load_is_generalized_allocation"])
			and not bool(active_summary["severity_proxy_is_injury_model"])
		),
		"material scaffold and measurement/severity non-claims remain explicit"
	)
	Engine.physics_ticks_per_second = original_hz
	_finish()


static func _configuration(actuator_sha: String) -> Dictionary:
	return {
		"schema_version": "controlled_fall_arrest_configuration_v1",
		"actuator_spec_sha256": actuator_sha,
		"physics_hz": PHYSICS_HZ,
		"trial_ticks": 480,
		"fall_arrest_start_tick": 1,
		"fallen_confirm_ticks": 20,
		"torso_mass_kg": 6.0,
		"torso_size_m": [0.50, 0.30, 0.20],
		"protective_mass_kg": 0.8,
		"protective_length_m": 0.90,
		"protective_width_m": 0.10,
		"initial_torso_position_m": [0.0, 1.10, 0.0],
		"initial_torso_angle_rad": -0.45,
		"initial_protective_relative_angle_rad": 0.70,
		"initial_linear_velocity_m_s": [0.0, -1.50, 0.0],
		"initial_angular_velocity_rad_s": -1.0,
		"floor_friction": 1.0,
		"target_relative_angle_rad": -1.20,
		"controller_kp_nm_per_rad": 45.0,
		"controller_kd_nm_s_per_rad": 10.0,
		"maximum_abs_angle_error_rad": 3.2,
		"maximum_abs_rate_rad_s": 40.0,
		"maximum_active_to_control_severity_ratio": 0.95,
		"maximum_active_to_control_core_speed_ratio": 0.97,
		"maximum_active_to_control_core_load_ratio": 0.95,
		"maximum_active_to_control_linear_momentum_ratio": 0.95,
		"maximum_energy_accounting_residual_j": 1.0e-7,
		"stable_linear_speed_m_s": 0.15,
		"stable_angular_speed_rad_s": 0.15,
		"maximum_pairing_residual_nm": 1.0e-9,
		"maximum_applied_torque_nm": 45.0,
		"out_of_plane_planar_guide_enabled": true,
		"built_in_motor_enabled": false,
		"joint_limit_enabled": false,
		"controller_root_force_enabled": false,
		"foot_pin_enabled": false,
		"pose_teleport_enabled": false,
		"per_body_load_allocation_enabled": false,
		"injury_claim_enabled": false,
		"upright_recovery_claim_enabled": false,
		"free_3d_claim_enabled": false,
		"getting_up_claim_enabled": false,
		"gait_claim_enabled": false,
		"walking_claim_enabled": false,
		"automatic_creature_guidance_enabled": false,
		"scaffold_constrained_planar_fall_arrest_claim_enabled": true,
	}


static func _controller_configuration() -> Dictionary:
	return {
		"schema_version": "fall_arrest_controller_configuration_v1",
		"controller_id": "br11_planar_protective_pd",
		"target_relative_angle_rad": -1.20,
		"kp_nm_per_rad": 45.0,
		"kd_nm_s_per_rad": 10.0,
		"maximum_abs_angle_error_rad": 3.2,
		"maximum_abs_rate_rad_s": 40.0,
		"automatic_creature_guidance_allowed": false,
	}


static func _actuator_configuration() -> Dictionary:
	return {
		"schema_version": "actuator_spec_v1",
		"actuator_id": "br11_explicit_protective_hinge",
		"enabled": true,
		"max_isometric_torque_nm": 40.0,
		"no_load_speed_rad_s": 40.0,
		"max_positive_power_w": 200.0,
		"max_absorption_power_w": 400.0,
		"max_eccentric_multiplier": 1.5,
		"activation_time_s": 0.002,
		"deactivation_time_s": 0.050,
		"max_torque_rate_nm_s": 5000.0,
		"structural_torque_limit_nm": 45.0,
		"tear_dwell_s": 0.05,
		"capacity_source": "explicit_lab",
		"muscle_pcsa_m2": 0.0,
		"specific_tension_pa": 0.0,
		"moment_arm_m": 0.0,
	}


static func _vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var raw: Array = value
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


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
