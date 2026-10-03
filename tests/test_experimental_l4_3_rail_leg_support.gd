extends SceneTree
# gdlint: disable=max-line-length

## BR6A/L4.3 two-link vertical-carriage support, crouch/rise, and recovery.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const AnalyzerScript := preload(
	"res://scripts/lab/mechanics/rail_leg_support_analyzer.gd"
)
const BodyWrenchScript := preload("res://scripts/lab/mechanics/body_wrench.gd")
const ForceMapScript := preload("res://scripts/lab/mechanics/force_to_joint_map.gd")
const RigScript := preload("res://scripts/lab/rigs/rail_leg_rig.gd")
const VerticalAllocatorScript := preload(
	"res://scripts/lab/mechanics/vertical_load_allocator.gd"
)

const PHYSICS_HZ := 60
const CONFIGURATION := {
	"schema_version": "rail_leg_support_configuration_v1",
	"physics_hz": PHYSICS_HZ,
	"settle_ticks": 90,
	"crouch_ramp_ticks": 60,
	"crouch_hold_ticks": 30,
	"rise_ramp_ticks": 60,
	"rise_hold_ticks": 30,
	"recovery_ticks": 150,
	"baseline_height_m": 0.70,
	"crouch_height_m": 0.60,
	"carriage_mass_kg": 2.0,
	"link_1_mass_kg": 0.5,
	"link_2_mass_kg": 0.5,
	"link_1_length_m": 0.40,
	"link_2_length_m": 0.40,
	"foot_radius_m": 0.055,
	"downward_impulse_ns": 1.5,
	"height_position_gain_n_m": 250.0,
	"height_velocity_gain_n_s_m": 45.0,
	"joint_position_gain_nm_rad": 80.0,
	"joint_velocity_gain_nm_s_rad": 8.0,
	"minimum_load_n": 0.0,
	"maximum_load_n": 80.0,
	"maximum_load_rate_n_s": 1200.0,
	"maximum_static_height_error_m": 0.004,
	"maximum_static_velocity_m_s": 0.03,
	"maximum_static_support_error_n": 0.5,
	"minimum_contact_fraction": 0.99,
	"minimum_crouch_depth_m": 0.08,
	"maximum_final_height_error_m": 0.015,
	"minimum_rise_potential_gain_j": 1.5,
	"minimum_rise_active_work_j": 0.5,
	"minimum_impulse_drop_m": 0.005,
	"maximum_recovery_height_error_m": 0.02,
	"maximum_recovery_velocity_m_s": 0.08,
	"recovery_dwell_ticks": 12,
	"built_in_motors_enabled": false,
	"joint_limits_enabled": false,
	"passive_tissues_enabled": false,
	"controller_root_force_enabled": false,
	"foot_pin_enabled": false,
}
const ACTUATOR_CONFIGURATION := {
	"schema_version": "actuator_spec_v1",
	"actuator_id": "l4_3_explicit_rail_leg_actuator",
	"enabled": true,
	"max_isometric_torque_nm": 50.0,
	"no_load_speed_rad_s": 1000.0,
	"max_positive_power_w": 0.0,
	"max_absorption_power_w": 0.0,
	"max_eccentric_multiplier": 1.25,
	"activation_time_s": 0.0011,
	"deactivation_time_s": 100.0,
	"max_torque_rate_nm_s": 10000.0,
	"structural_torque_limit_nm": 60.0,
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
	print("=== Experimental BR6A/L4.3 rail-leg vertical support ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var built := AnalyzerScript.build(CONFIGURATION)
	var actuator := ActuatorSpecScript.compile(ACTUATOR_CONFIGURATION)
	_check(
		bool(built.get("ok", false)) and bool(actuator.get("ok", false)),
		"strict rail-leg and finite actuator contracts seal"
	)
	if not bool(built.get("ok", false)) or not bool(actuator.get("ok", false)):
		printerr("  contract_build=", built, " actuator_build=", actuator)
	_test_contract_and_module_refusals()
	if not bool(built.get("ok", false)) or not bool(actuator.get("ok", false)):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var feasible := AnalyzerScript.preflight_height(
		built["contract"], actuator["spec"], float(CONFIGURATION["baseline_height_m"])
	)
	var unreachable := AnalyzerScript.preflight_height(
		built["contract"], actuator["spec"], 1.2
	)
	var weak_configuration := ACTUATOR_CONFIGURATION.duplicate(true)
	weak_configuration["actuator_id"] = "l4_3_weak_control"
	weak_configuration["max_isometric_torque_nm"] = 0.1
	weak_configuration["structural_torque_limit_nm"] = 0.2
	var weak := ActuatorSpecScript.compile(weak_configuration)
	var insufficient := AnalyzerScript.preflight_height(
		built["contract"], weak["spec"], float(CONFIGURATION["baseline_height_m"])
	)
	_check(
		bool(feasible["feasible"]) and String(feasible["reason"]) == "FEASIBLE",
		"declared baseline height is reachable inside the finite actuator envelope"
	)
	_check(
		not bool(unreachable["feasible"])
			and String(unreachable["reason"]) == "HEIGHT_TARGET_UNREACHABLE"
			and not bool(insufficient["feasible"])
			and String(insufficient["reason"]) == "ACTUATOR_STATIC_TORQUE_INFEASIBLE",
		"unreachable geometry and insufficient actuator fail before physics execution"
	)
	print(
		"  preflight height=%.3fm peak_tau=%.5f/%.5fNm"
		% [
			float(feasible["target_height_m"]),
			float(feasible["required_peak_torque_nm"]),
			float(feasible["available_isometric_torque_nm"]),
		]
	)
	var rig = RigScript.new()
	var run: Dictionary = await rig.run(self, built["contract"], actuator["spec"])
	_check(bool(run.get("ok", false)), "live rail-leg run retains complete physics and receipt data")
	if not bool(run.get("ok", false)):
		printerr("  rig_failure=", run)
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var summary: Dictionary = run["summary"]
	_print_summary(summary)
	var analysis := AnalyzerScript.analyze(built["contract"], summary)
	_check(bool(analysis.get("ok", false)), "digest-bound L4.3 analyzer accepts the exact run")
	if not bool(analysis.get("ok", false)):
		printerr("  analysis_failure=", analysis)
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	_check(bool(analysis["accepted"]), "L4.3 static, crouch/rise, and disturbance gates pass")
	_check(
		float(summary["static_maximum_support_error_n"]) <= 0.5
			and float(summary["static_maximum_height_error_m"]) <= 0.004
			and float(summary["contact_fraction"]) >= 0.99,
		"ordinary distal contact carries the declared static load at controlled height"
	)
	_check(
		float(summary["crouch_depth_m"]) >= 0.08
			and float(summary["rise_potential_energy_gain_j"]) >= 1.5
			and float(summary["rise_active_work_j"]) >= 0.5,
		"legal paired joint work crouches and restores gravitational potential"
	)
	_check(
		float(summary["impulse_maximum_drop_m"]) >= 0.005
			and bool(summary["impulse_recovered"]),
		"the declared downward impulse produces a real drop followed by bounded recovery"
	)
	_check(
		int(summary["root_rescue_operation_count"]) == 0
			and int(summary["passive_operation_count"]) == 0
			and int(summary["foot_pin_operation_count"]) == 0
			and int(summary["disturbance_operation_count"]) == 1,
		"only the declared disturbance touches the carriage; no root rescue or foot pin exists"
	)
	_check(
		bool(summary["rail_contract_exact"])
			and bool(summary["hinges_exact"])
			and not bool(summary["per_foot_allocation_available"]),
		"rail reaction is explicit, motors/limits stay off, and load remains aggregate"
	)
	_test_analyzer_refusals(built["contract"], summary)
	var exclusions: Array = analysis["does_not_establish"]
	_check(
		exclusions.has("free_root_standing")
			and exclusions.has("bracing")
			and exclusions.has("walking")
			and exclusions.has("automatic_creature_guidance"),
		"rail support is fenced from standing, bracing, walking, and guidance"
	)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_contract_and_module_refusals() -> void:
	var assisted := CONFIGURATION.duplicate(true)
	assisted["controller_root_force_enabled"] = true
	var pinned := CONFIGURATION.duplicate(true)
	pinned["foot_pin_enabled"] = true
	var unequal := CONFIGURATION.duplicate(true)
	unequal["link_2_length_m"] = 0.35
	_check(
		not bool(AnalyzerScript.build(assisted).get("ok", true))
			and not bool(AnalyzerScript.build(pinned).get("ok", true))
			and not bool(AnalyzerScript.build(unequal).get("ok", true)),
		"contract rejects root force, foot pinning, and undeclared asymmetric IK"
	)
	var wrench := BodyWrenchScript.compile(
		{
			"schema_version": "body_wrench_v1",
			"wrench_id": "module.check",
			"source_id": "module.check",
			"frame_id": "world",
			"application_point_world_m": [0.0, 0.0, 0.0],
			"force_world_n": [0.0, 29.4, 0.0],
			"moment_world_nm": [0.0, 0.0, 0.0],
		}
	)
	var allocation := VerticalAllocatorScript.allocate(
		{
			"schema_version": "vertical_load_allocation_request_v1",
			"tick": 0,
			"mass_kg": 3.0,
			"gravity_m_s2": 9.8,
			"height_error_m": 1.0,
			"vertical_velocity_m_s": 0.0,
			"position_gain_n_m": 250.0,
			"velocity_gain_n_s_m": 45.0,
			"minimum_load_n": 0.0,
			"maximum_load_n": 80.0,
			"previous_load_n": 29.4,
			"maximum_load_rate_n_s": 1200.0,
			"step_s": 1.0 / 60.0,
		}
	)
	_check(
		bool(wrench.get("ok", false))
			and bool(allocation.get("ok", false))
			and bool((allocation["allocation"] as Dictionary)["saturated"])
			and bool((allocation["allocation"] as Dictionary)["anti_windup_active"])
			and not bool((allocation["allocation"] as Dictionary)["integrator_present"]),
		"wrench and allocator expose finite saturation with no hidden integrator"
	)
	var invalid_wrench: Dictionary = wrench["wrench"].duplicate(true)
	invalid_wrench["moment_world_nm"] = [0.0, 0.0, 1.0]
	var invalid_map := ForceMapScript.map(
		{
			"schema_version": "two_link_force_map_request_v1",
			"joint_1_angle_rad": 0.5,
			"joint_2_angle_rad": -1.0,
			"link_1_length_m": 0.4,
			"link_2_length_m": 0.4,
			"carriage_mass_kg": 2.0,
			"link_1_mass_kg": 0.5,
			"link_2_mass_kg": 0.5,
			"gravity_m_s2": 9.8,
			"wrench": invalid_wrench,
		}
	)
	_check(
		String(invalid_map.get("failure_code", "")) == "FORCE_MAP_V1_VERTICAL_FORCE_ONLY",
		"V1 force map refuses an undeclared moment instead of silently dropping it"
	)


func _test_analyzer_refusals(contract: Dictionary, summary: Dictionary) -> void:
	var mutated := contract.duplicate(true)
	mutated["baseline_height_m"] = 0.71
	var digest_failure := AnalyzerScript.analyze(mutated, summary)
	var rescued := summary.duplicate(true)
	rescued["root_rescue_operation_count"] = 1
	var rescued_analysis := AnalyzerScript.analyze(contract, rescued)
	var allocated := summary.duplicate(true)
	allocated["per_foot_allocation_available"] = true
	var allocated_analysis := AnalyzerScript.analyze(contract, allocated)
	_check(
		String(digest_failure.get("failure_code", "")) == "RAIL_LEG_CONTRACT_DIGEST_MISMATCH"
			and not bool(rescued_analysis.get("accepted", true))
			and not bool(allocated_analysis.get("accepted", true)),
		"digest mutation, forged root rescue, and false per-foot allocation fail closed"
	)


static func _print_summary(summary: Dictionary) -> void:
	print(
		(
			"  static height_err=%.6fm vy=%.6fm/s support_err=%.5fN contact=%.3f "
			+ "crouch=%.5fm rise_PE=%.5fJ rise_work=%.5fJ impulse_drop=%.5fm "
			+ "recovered=%s/%dt rail_tangent_max=%.5fN torque=%.4f/%.4fNm sat=%d/%d"
		)
		% [
			float(summary["static_maximum_height_error_m"]),
			float(summary["static_maximum_velocity_m_s"]),
			float(summary["static_maximum_support_error_n"]),
			float(summary["contact_fraction"]),
			float(summary["crouch_depth_m"]),
			float(summary["rise_potential_energy_gain_j"]),
			float(summary["rise_active_work_j"]),
			float(summary["impulse_maximum_drop_m"]),
			str(bool(summary["impulse_recovered"])),
			int(summary["impulse_recovery_ticks"]),
			float(summary["maximum_rail_tangential_load_n"]),
			float(summary["maximum_requested_torque_nm"]),
			float(summary["maximum_applied_torque_nm"]),
			int(summary["actuator_saturation_count"]),
			int(summary["allocator_saturation_count"]),
		]
	)


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
