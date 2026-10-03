extends SceneTree

## Experimental BR4/L2.2 unloaded PD tracking.
##
## Positive, negative, and zero target steps run in isolated free-floating
## worlds. The controller is pure; all paired torques cross the BR1 command and
## execution-receipt seam.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const PdControllerScript := preload("res://scripts/lab/mechanics/joint_pd_controller.gd")
const PdAnalyzerScript := preload("res://scripts/lab/mechanics/unloaded_pd_step_analyzer.gd")
const PdRigScript := preload("res://scripts/lab/rigs/free_hinge_pd_rig.gd")

const PHYSICS_HZ := 120
const SAMPLE_TICKS := 300
const TARGET_ANGLE_RAD := 0.25
const NATURAL_FREQUENCY_RAD_S := 8.0
const DAMPING_RATIO := 1.0
const PARENT_MASS_KG := 2.0
const PARENT_SIZE_M := Vector3(0.5, 0.4, 0.2)
const CHILD_MASS_KG := 1.0
const CHILD_SIZE_M := Vector3(0.3, 0.2, 0.2)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR4/L2.2 unloaded PD step ===")
	var original_ticks := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = PHYSICS_HZ
	var positive_build: Dictionary = PdAnalyzerScript.build(
		_trial_configuration("positive_step", TARGET_ANGLE_RAD)
	)
	var negative_build: Dictionary = PdAnalyzerScript.build(
		_trial_configuration("negative_step", -TARGET_ANGLE_RAD)
	)
	var zero_build: Dictionary = PdAnalyzerScript.build(_trial_configuration("zero_control", 0.0))
	_check(
		(
			bool(positive_build.get("ok", false))
			and bool(negative_build.get("ok", false))
			and bool(zero_build.get("ok", false))
		),
		"positive, negative, and zero PD trials seal into exact contracts"
	)
	_test_configuration_refusals()
	if (
		not bool(positive_build.get("ok", false))
		or not bool(negative_build.get("ok", false))
		or not bool(zero_build.get("ok", false))
	):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var contract: Dictionary = positive_build["contract"]
	var controller_build: Dictionary = PdControllerScript.compile(
		_controller_configuration(contract)
	)
	var actuator_build: Dictionary = ActuatorSpecScript.compile(_actuator_configuration())
	_check(
		bool(controller_build.get("ok", false)) and bool(actuator_build.get("ok", false)),
		"analytic reflected-inertia gains compile with an explicit lab actuator"
	)
	_test_controller_refusals(contract)
	if not bool(controller_build.get("ok", false)) or not bool(actuator_build.get("ok", false)):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var rig = PdRigScript.new()
	var positive: Dictionary = await rig.run(
		self, positive_build["contract"], controller_build["controller"], actuator_build["spec"]
	)
	var negative: Dictionary = await rig.run(
		self, negative_build["contract"], controller_build["controller"], actuator_build["spec"]
	)
	var zero: Dictionary = await rig.run(
		self, zero_build["contract"], controller_build["controller"], actuator_build["spec"]
	)
	_print_result("positive", positive)
	_print_result("negative", negative)
	_print_result("zero", zero)
	_check(
		(
			bool(positive.get("fixture_complete", false))
			and bool(negative.get("fixture_complete", false))
			and bool(zero.get("fixture_complete", false))
		),
		"all fresh-world PD fixtures retain complete joint, command, and receipt evidence"
	)
	_check(
		(
			bool(positive.get("analysis_ok", false))
			and bool(negative.get("analysis_ok", false))
			and bool(zero.get("analysis_ok", false))
		),
		"all PD traces satisfy their digest-bound analyzer contracts"
	)
	if not (
		bool(positive.get("analysis_ok", false))
		and bool(negative.get("analysis_ok", false))
		and bool(zero.get("analysis_ok", false))
	):
		Engine.physics_ticks_per_second = original_ticks
		_finish()
		return
	var positive_result: Dictionary = positive["result"]
	var negative_result: Dictionary = negative["result"]
	var zero_result: Dictionary = zero["result"]
	_check(
		(
			bool(positive_result["accepted"])
			and bool(negative_result["accepted"])
			and bool(zero_result["accepted"])
		),
		"positive, negative, and zero-control cells satisfy all L2.2 gates"
	)
	_check(
		(
			int(positive_result["rise_tick_90_percent"]) >= 0
			and int(negative_result["rise_tick_90_percent"]) >= 0
			and int(positive_result["settling_tick"]) >= 0
			and int(negative_result["settling_tick"]) >= 0
		),
		"both nonzero steps reach ninety-percent rise and remain settled"
	)
	_check(
		(
			float(positive_result["overshoot_fraction"]) <= 0.05
			and float(negative_result["overshoot_fraction"]) <= 0.05
		),
		"critical-damping fixture keeps both directional overshoots below five percent"
	)
	_check(
		(
			(
				absf(
					(
						float(positive_result["final_angle_rad"])
						+ float(negative_result["final_angle_rad"])
					)
				)
				<= 5.0e-4
			)
			and (
				absf(
					(
						float(positive_result["final_rate_rad_s"])
						+ float(negative_result["final_rate_rad_s"])
					)
				)
				<= 5.0e-4
			)
		),
		"positive and negative PD responses mirror in final angle and rate"
	)
	_check(
		(
			float(positive_result["max_controller_identity_error"]) <= 1.0e-9
			and float(negative_result["max_controller_identity_error"]) <= 1.0e-9
			and not bool(positive_result["active_envelope_saturated"])
			and not bool(negative_result["active_envelope_saturated"])
		),
		"recorded P, D, requested, and actuator torques agree without hidden saturation"
	)
	_check(
		(
			float(positive_result["max_total_axis_angular_momentum_abs_n_m_s"]) <= 1.0e-4
			and float(negative_result["max_total_axis_angular_momentum_abs_n_m_s"]) <= 1.0e-4
			and float(positive_result["max_pairing_residual_nm"]) <= 1.0e-9
			and float(negative_result["max_pairing_residual_nm"]) <= 1.0e-9
		),
		"free-floating pair conserves angular momentum under exact paired torques"
	)
	_check(
		(
			bool(positive_result["all_execution_receipts_complete"])
			and bool(negative_result["all_execution_receipts_complete"])
			and bool(zero_result["all_execution_receipts_complete"])
		),
		"every transition has two hash-linked call-returned execution receipts"
	)
	_check(
		(
			absf(float(zero_result["final_angle_rad"])) <= 1.0e-5
			and absf(float(zero_result["final_rate_rad_s"])) <= 1.0e-5
		),
		"zero target produces no commanded or observed joint motion"
	)
	_check(
		(
			bool(positive["motor_disabled"])
			and bool(positive["limit_disabled"])
			and bool(positive["gravity_disabled"])
			and bool(positive["contact_disabled"])
		),
		"live fixture confirms motor, limit, gravity, damping, and contact exclusions"
	)
	_test_analyzer_refusals(positive_build["contract"], positive["samples"])
	_check(
		(
			String(positive_result["claim_boundary"])
			== (
				"Exact gravity-off, contact-free, coaxial free-hinge unloaded PD fixture only; "
				+ "no load-bearing, standing, bracing, recovery, gait, or walking claim."
			)
		),
		"L2.2 result carries the exact unloaded non-claim boundary"
	)
	Engine.physics_ticks_per_second = original_ticks
	_finish()


func _test_configuration_refusals() -> void:
	var hidden_motor := _trial_configuration("hidden_motor", TARGET_ANGLE_RAD)
	hidden_motor["built_in_motor_enabled"] = true
	var hidden_gravity := _trial_configuration("hidden_gravity", TARGET_ANGLE_RAD)
	hidden_gravity["gravity_enabled"] = true
	var oversized_target := _trial_configuration("oversized", 0.75)
	var unknown := _trial_configuration("unknown", TARGET_ANGLE_RAD)
	unknown["root_reaction_torque_nm"] = 1.0
	_check(
		(
			not bool(PdAnalyzerScript.build(hidden_motor).get("ok", true))
			and not bool(PdAnalyzerScript.build(hidden_gravity).get("ok", true))
			and not bool(PdAnalyzerScript.build(oversized_target).get("ok", true))
			and not bool(PdAnalyzerScript.build(unknown).get("ok", true))
		),
		"PD contract rejects hidden motor/gravity, oversized targets, and root reaction fields"
	)


func _test_controller_refusals(contract: Dictionary) -> void:
	var bad_gain := _controller_configuration(contract)
	bad_gain["kd_nm_s_per_rad"] = -1.0
	var unknown := _controller_configuration(contract)
	unknown["integral_gain"] = 1.0
	var build: Dictionary = PdControllerScript.compile(_controller_configuration(contract))
	var out_of_domain := {
		"schema_version": "joint_pd_controller_input_v1",
		"tick": 0,
		"target_angle_rad": 0.25,
		"measured_angle_rad": -1.0,
		"measured_rate_rad_s": 0.0,
	}
	var extra_input := out_of_domain.duplicate(true)
	extra_input["direct_torque_nm"] = 1.0
	_check(
		(
			not bool(PdControllerScript.compile(bad_gain).get("ok", true))
			and not bool(PdControllerScript.compile(unknown).get("ok", true))
			and not bool(
				PdControllerScript.resolve(build["controller"], out_of_domain).get("ok", true)
			)
			and not bool(
				PdControllerScript.resolve(build["controller"], extra_input).get("ok", true)
			)
		),
		"PD resolver rejects invalid gains, unknown fields, and observations outside its domain"
	)
	var nominal_input := {
		"schema_version": "joint_pd_controller_input_v1",
		"tick": 0,
		"target_angle_rad": 0.25,
		"measured_angle_rad": 0.0,
		"measured_rate_rad_s": 0.0,
	}
	var nominal: Dictionary = PdControllerScript.resolve(build["controller"], nominal_input)
	nominal_input["target_angle_rad"] = -0.25
	_check(
		bool(nominal.get("ok", false)) and float(nominal["resolution"]["target_angle_rad"]) == 0.25,
		"sealed PD resolution is detached from later mutable input changes"
	)


func _test_analyzer_refusals(contract: Dictionary, source_samples: Array) -> void:
	var changed_contract := contract.duplicate(true)
	changed_contract["target_angle_rad"] = 0.2
	var changed_result: Dictionary = PdAnalyzerScript.analyze(changed_contract, source_samples)
	var short_samples := source_samples.duplicate(true)
	short_samples.pop_back()
	var short_result: Dictionary = PdAnalyzerScript.analyze(contract, short_samples)
	var nonfinite := source_samples.duplicate(true)
	(nonfinite[4] as Dictionary)["measured_rate_after_rad_s"] = NAN
	var nonfinite_result: Dictionary = PdAnalyzerScript.analyze(contract, nonfinite)
	var forged_target := source_samples.duplicate(true)
	(forged_target[3] as Dictionary)["target_angle_rad"] = 0.2
	var forged_result: Dictionary = PdAnalyzerScript.analyze(contract, forged_target)
	_check(
		(
			String(changed_result.get("failure_code", "")) == "UNLOADED_PD_CONTRACT_DIGEST_MISMATCH"
			and String(short_result.get("failure_code", "")) == "UNLOADED_PD_SAMPLE_COUNT_MISMATCH"
			and String(nonfinite_result.get("failure_code", "")) == "UNLOADED_PD_SAMPLE_NONFINITE"
			and String(forged_result.get("failure_code", "")) == "UNLOADED_PD_TARGET_TRACE_MISMATCH"
		),
		"digest mutation, missing sample, nonfinite data, and forged target all fail closed"
	)
	var missing_receipt := source_samples.duplicate(true)
	(missing_receipt[5] as Dictionary)["receipt_count"] = 1
	var receipt_result: Dictionary = PdAnalyzerScript.analyze(contract, missing_receipt)
	_check(
		(
			bool(receipt_result.get("ok", false))
			and not bool(receipt_result["result"]["accepted"])
			and (receipt_result["result"]["acceptance_failures"] as Array).has(
				"EXECUTION_RECEIPT_INCOMPLETE"
			)
		),
		"missing paired receipt makes a structurally complete PD trace non-acceptable"
	)


static func _trial_configuration(trial_id: String, target_angle_rad: float) -> Dictionary:
	return {
		"schema_version": "unloaded_pd_step_configuration_v1",
		"trial_id": trial_id,
		"physics_hz": PHYSICS_HZ,
		"sample_ticks": SAMPLE_TICKS,
		"target_angle_rad": target_angle_rad,
		"parent_mass_kg": PARENT_MASS_KG,
		"parent_size_m": PARENT_SIZE_M,
		"child_mass_kg": CHILD_MASS_KG,
		"child_size_m": CHILD_SIZE_M,
		"natural_frequency_rad_s": NATURAL_FREQUENCY_RAD_S,
		"damping_ratio": DAMPING_RATIO,
		"gravity_enabled": false,
		"linear_damp_s_inv": 0.0,
		"angular_damp_s_inv": 0.0,
		"contact_enabled": false,
		"built_in_motor_enabled": false,
		"limit_enabled": false,
	}


static func _controller_configuration(contract: Dictionary) -> Dictionary:
	return {
		"schema_version": "joint_pd_controller_configuration_v1",
		"controller_id": "l2_2_reflected_inertia_pd",
		"kp_nm_per_rad": float(contract["kp_nm_per_rad"]),
		"kd_nm_s_per_rad": float(contract["kd_nm_s_per_rad"]),
		"max_abs_position_error_rad": 0.6,
		"max_abs_rate_rad_s": 10.0,
	}


static func _actuator_configuration() -> Dictionary:
	return {
		"schema_version": "actuator_spec_v1",
		"actuator_id": "l2_2_explicit_lab_motor",
		"enabled": true,
		"max_isometric_torque_nm": 2.0,
		"no_load_speed_rad_s": 100.0,
		"max_positive_power_w": 0.0,
		"max_absorption_power_w": 0.0,
		"max_eccentric_multiplier": 1.25,
		"activation_time_s": 0.0011,
		# L2.2 isolates PD tracking from activation decay. The explicit dyno
		# drive begins energized and retains that capacity over this 2.5 s cell;
		# L2.4 separately exercises activation and envelope limits.
		"deactivation_time_s": 100.0,
		"max_torque_rate_nm_s": 1000.0,
		"structural_torque_limit_nm": 3.0,
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
				"  %s accepted=%s final=%.7frad rate=%.7frad/s rise=%d settle=%d "
				+ "overshoot=%.4f%% momentum=%.9fNms failures=%s"
			)
			% [
				label,
				str(bool(result["accepted"])),
				float(result["final_angle_rad"]),
				float(result["final_rate_rad_s"]),
				int(result["rise_tick_90_percent"]),
				int(result["settling_tick"]),
				100.0 * float(result["overshoot_fraction"]),
				float(result["max_total_axis_angular_momentum_abs_n_m_s"]),
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
