extends SceneTree

## Experimental BR4/L2.6 two-joint fixed/free-root chain.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const AnalyzerScript := preload("res://scripts/lab/mechanics/two_link_chain_analyzer.gd")
const RigScript := preload("res://scripts/lab/rigs/two_link_chain_rig.gd")

const PHYSICS_HZ := 120
const PULSE_TICKS := 24
const COAST_TICKS := 24

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR4/L2.6 two-link chain ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var fixed_build: Dictionary = AnalyzerScript.build(_configuration("fixed_root", "fixed"))
	var free_build: Dictionary = AnalyzerScript.build(_configuration("free_root", "free"))
	_check(
		bool(fixed_build.get("ok", false)) and bool(free_build.get("ok", false)),
		"fixed-root and free-root chain contracts seal"
	)
	_test_configuration_refusals()
	var actuator_build: Dictionary = ActuatorSpecScript.compile(_actuator_configuration())
	_check(bool(actuator_build.get("ok", false)), "two-joint explicit actuator compiles")
	if (
		not bool(fixed_build.get("ok", false))
		or not bool(free_build.get("ok", false))
		or not bool(actuator_build.get("ok", false))
	):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var rig = RigScript.new()
	var fixed: Dictionary = await rig.run(self, fixed_build["contract"], actuator_build["spec"])
	var free: Dictionary = await rig.run(self, free_build["contract"], actuator_build["spec"])
	_print_result("fixed", fixed)
	_print_result("free", free)
	_check(
		bool(fixed["fixture_complete"]) and bool(free["fixture_complete"]),
		"both two-joint fixtures retain complete commands, receipts, and observations"
	)
	_check(
		bool(fixed["analysis_ok"]) and bool(free["analysis_ok"]),
		"both two-joint traces satisfy their digest-bound analyzers"
	)
	if not bool(fixed["analysis_ok"]) or not bool(free["analysis_ok"]):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var f: Dictionary = fixed["result"]
	var r: Dictionary = free["result"]
	_check(
		bool(f["accepted"]) and bool(r["accepted"]),
		"fixed and free variants satisfy every L2.6 gate"
	)
	_check(
		(
			float(f["max_joint_1_abs_angle_rad"]) >= 0.01
			and float(f["max_joint_2_abs_angle_rad"]) >= 0.01
			and float(r["max_joint_1_abs_angle_rad"]) >= 0.01
			and float(r["max_joint_2_abs_angle_rad"]) >= 0.01
		),
		"both joints respond in both root modes"
	)
	_check(
		(
			float(f["final_root_displacement_m"]) <= 1.0e-6
			and float(r["final_root_displacement_m"]) >= 1.0e-5
		),
		"fixed scaffold stays fixed while the unassisted free root reacts"
	)
	_check(
		(
			float(r["max_total_axis_angular_momentum_abs_n_m_s"]) <= 2.0e-4
			and float(r["max_system_com_displacement_m"]) <= 2.0e-4
		),
		"free chain conserves total angular momentum and system center of mass"
	)
	_check(
		(
			bool(f["all_execution_receipts_complete"])
			and bool(r["all_execution_receipts_complete"])
			and float(f["max_pairing_residual_nm"]) <= 1.0e-9
			and float(r["max_pairing_residual_nm"]) <= 1.0e-9
		),
		"both joint pairs produce four exact hash-linked receipts per transition"
	)
	_check(
		(
			int(f["root_assistance_operation_count"]) == 0
			and int(r["root_assistance_operation_count"]) == 0
			and String(r["root_operation_class"]) == "joint_1_pair_reaction"
		),
		"free-root motion uses only the joint-1 paired reaction, never root assistance"
	)
	_check(
		(
			bool(fixed["root_frozen"])
			and not bool(free["root_frozen"])
			and bool(fixed["motors_disabled"])
			and bool(free["motors_disabled"])
			and bool(fixed["limits_disabled"])
			and bool(free["limits_disabled"])
		),
		"live fixtures expose root mode and exclude built-in motors and limits"
	)
	_test_analyzer_refusals(free_build["contract"], free["samples"])
	_check(
		(
			String(r["claim_boundary"])
			== (
				"Exact gravity-off, contact-free planar two-joint chain fixtures only; the "
				+ "fixed-root case has an explicit frozen scaffold and the free-root case uses "
				+ "only paired internal torques. This proves no contact load bearing, standing, "
				+ "bracing, recovery, gait, or walking."
			)
		),
		"L2.6 result carries the exact root-mode and non-claim boundary"
	)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_configuration_refusals() -> void:
	var hidden_root := _configuration("hidden_root", "free")
	hidden_root["root_assistance_enabled"] = true
	var hidden_motor := _configuration("hidden_motor", "free")
	hidden_motor["built_in_motors_enabled"] = true
	var invalid_mode := _configuration("invalid_mode", "floatingish")
	var unknown := _configuration("unknown", "free")
	unknown["root_torque_nm"] = 1.0
	_check(
		(
			not bool(AnalyzerScript.build(hidden_root).get("ok", true))
			and not bool(AnalyzerScript.build(hidden_motor).get("ok", true))
			and not bool(AnalyzerScript.build(invalid_mode).get("ok", true))
			and not bool(AnalyzerScript.build(unknown).get("ok", true))
		),
		"chain contract rejects root assistance, hidden motors, unknown mode, and root torque"
	)


func _test_analyzer_refusals(contract: Dictionary, source_samples: Array) -> void:
	var mutated := contract.duplicate(true)
	mutated["root_mode"] = "fixed"
	var mutated_result: Dictionary = AnalyzerScript.analyze(mutated, source_samples)
	var short := source_samples.duplicate(true)
	short.pop_back()
	var short_result: Dictionary = AnalyzerScript.analyze(contract, short)
	var assisted := source_samples.duplicate(true)
	(assisted[2] as Dictionary)["root_assistance_operation_count"] = 1
	var assisted_result: Dictionary = AnalyzerScript.analyze(contract, assisted)
	_check(
		(
			String(mutated_result.get("failure_code", "")) == "TWO_LINK_CONTRACT_DIGEST_MISMATCH"
			and String(short_result.get("failure_code", "")) == "TWO_LINK_SAMPLE_COUNT_MISMATCH"
			and (
				String(assisted_result.get("failure_code", ""))
				== "TWO_LINK_ROOT_ASSISTANCE_OR_CLASSIFICATION_INVALID"
			)
		),
		"mutated root mode, missing transition, and forged root assistance fail closed"
	)


static func _configuration(trial_id: String, root_mode: String) -> Dictionary:
	return {
		"schema_version": "two_link_chain_configuration_v1",
		"trial_id": trial_id,
		"root_mode": root_mode,
		"physics_hz": PHYSICS_HZ,
		"pulse_ticks": PULSE_TICKS,
		"coast_ticks": COAST_TICKS,
		"joint_1_torque_nm": 0.02,
		"joint_2_torque_nm": -0.015,
		"root_mass_kg": 1.5,
		"root_size_m": Vector3(0.15, 0.15, 0.12),
		"link_1_mass_kg": 1.0,
		"link_1_size_m": Vector3(0.4, 0.08, 0.08),
		"link_2_mass_kg": 0.7,
		"link_2_size_m": Vector3(0.3, 0.07, 0.07),
		"gravity_enabled": false,
		"contact_enabled": false,
		"built_in_motors_enabled": false,
		"limits_enabled": false,
		"root_assistance_enabled": false,
	}


static func _actuator_configuration() -> Dictionary:
	return {
		"schema_version": "actuator_spec_v1",
		"actuator_id": "l2_6_two_link_explicit_motor",
		"enabled": true,
		"max_isometric_torque_nm": 1.0,
		"no_load_speed_rad_s": 100.0,
		"max_positive_power_w": 0.0,
		"max_absorption_power_w": 0.0,
		"max_eccentric_multiplier": 1.25,
		"activation_time_s": 0.0011,
		"deactivation_time_s": 100.0,
		"max_torque_rate_nm_s": 1000.0,
		"structural_torque_limit_nm": 2.0,
		"tear_dwell_s": 0.05,
		"capacity_source": "explicit_lab",
		"muscle_pcsa_m2": 0.0,
		"specific_tension_pa": 0.0,
		"moment_arm_m": 0.0,
	}


static func _print_result(label: String, trial: Dictionary) -> void:
	if not bool(trial.get("analysis_ok", false)):
		print("  %s analysis_failure=%s" % [label, str(trial.get("analysis_failure", {}))])
		return
	var result: Dictionary = trial["result"]
	print(
		(
			(
				"  %s accepted=%s q1=%.5frad q2=%.5frad root=%.7fm "
				+ "L=%.8fNms com=%.8fm failures=%s"
			)
			% [
				label,
				str(bool(result["accepted"])),
				float(result["max_joint_1_abs_angle_rad"]),
				float(result["max_joint_2_abs_angle_rad"]),
				float(result["final_root_displacement_m"]),
				float(result["max_total_axis_angular_momentum_abs_n_m_s"]),
				float(result["max_system_com_displacement_m"]),
				str(result["acceptance_failures"]),
			]
		)
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
