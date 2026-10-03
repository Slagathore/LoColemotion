extends SceneTree
# gdlint: disable=max-line-length

## BR14A.2 prephysical J-transpose and full-activation actuator screen only.
##
## Inputs are declared contact commands and incomplete bias terms. The result
## cannot establish reach, collisions, dynamics, physical support, or walking.

const ActuatorSpecScript := preload("res://scripts/lab/mechanics/actuator_spec.gd")
const OracleScript := preload("res://scripts/lab/mechanics/spatial_actuator_load_oracle.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.2 spatial actuator-load screen ===")
	_test_j_transpose_and_capacity()
	_test_speed_power_structure_and_limits()
	_test_containment()
	_finish()


func _test_j_transpose_and_capacity() -> void:
	print("- contact command maps to the exact revolute generalized load")
	var baseline := _analyze(_request())
	_check(bool(baseline.get("ok", false)), "strict actuator-load request analyzes")
	var report: Dictionary = baseline["report"]
	var joint: Dictionary = report["joint_reports"][0]
	_check(
		(
			_close(float(joint["contact_generalized_load_nm"]), 10.0)
			and _close(float(joint["required_active_torque_nm"]), -10.0)
		),
		"axis dot r-cross-f produces the exact opposing actuator command"
	)
	_check(
		(
			bool(report["screen_passed"])
			and bool(joint["actuator_envelope_passed"])
			and bool(joint["structural_cap_passed"])
			and bool(joint["joint_limit_passed"])
		),
		"bounded command fits the full-activation envelope, structure, and joint range"
	)
	_check(
		(
			_close(float(joint["full_activation_lower_bound_nm"]), -20.0)
			and _close(float(joint["full_activation_upper_bound_nm"]), 20.0)
			and _close(float(joint["directional_capacity_utilization"]), 0.5)
		),
		"full-activation isometric capacity and utilization remain explicit"
	)
	var with_bias := _request()
	with_bias["joints"][0]["declared_bias_torque_nm"] = 5.0
	var biased: Dictionary = _analyze(with_bias)["report"]["joint_reports"][0]
	_check(
		(
			_close(float(biased["required_active_torque_nm"]), -15.0)
			and not bool(biased["declared_bias_is_complete"])
		),
		"declared analytic bias participates without being relabeled complete dynamics"
	)
	var mirrored := _request()
	mirrored["contacts"][0]["force_command_world_n"] = [0, -10, 0]
	var mirrored_joint: Dictionary = _analyze(mirrored)["report"]["joint_reports"][0]
	_check(
		(
			_close(float(mirrored_joint["contact_generalized_load_nm"]), -10.0)
			and _close(float(mirrored_joint["required_active_torque_nm"]), 10.0)
		),
		"mirrored contact command reverses generalized load and actuator direction"
	)
	var chain := _request()
	var proximal: Dictionary = chain["joints"][0].duplicate(true)
	proximal["joint_id"] = "right_shoulder"
	proximal["pivot_world_m"] = [0.5, 0, 0]
	proximal["actuator_spec"] = _spec(20.0, 100.0, 100.0, 30.0, true, "right_shoulder_actuator")
	chain["joints"].append(proximal)
	var chain_report: Dictionary = _analyze(chain)["report"]
	_check(
		(
			int(chain_report["joint_count"]) == 2
			and _close(float(chain_report["joint_reports"][1]["contact_generalized_load_nm"]), 5.0)
		),
		"one distal contact can load multiple declared ancestor joints"
	)
	_check(
		(
			bool(report["j_transpose_geometry_applied"])
			and bool(report["full_activation_upper_bound_only"])
			and not bool(report["contact_commands_are_measurements"])
			and not bool(report["contact_feasibility_established_by_this_oracle"])
			and not bool(report["declared_bias_terms_complete"])
		),
		"positive result remains an upper-bound command screen rather than load measurement"
	)


func _test_speed_power_structure_and_limits() -> void:
	print("- torque-speed-power, structure, and joint-range refusals remain distinct")
	var weak := _request()
	weak["joints"][0]["actuator_spec"] = _spec(5.0, 100.0, 100.0, 30.0, true)
	var weak_report: Dictionary = _analyze(weak)["report"]
	_check(
		(
			not bool(weak_report["screen_passed"])
			and not bool(weak_report["joint_reports"][0]["actuator_envelope_passed"])
		),
		"insufficient isometric torque rejects the requested contact command"
	)
	var positive_power := _request()
	positive_power["joints"][0]["angular_rate_rad_s"] = -2.0
	positive_power["joints"][0]["actuator_spec"] = _spec(20.0, 4.0, 100.0, 30.0, true)
	var positive_report: Dictionary = _analyze(positive_power)["report"]["joint_reports"][0]
	_check(
		(
			not bool(positive_report["actuator_envelope_passed"])
			and String(positive_report["work_regime"]) == "positive_work"
			and bool(positive_report["power_cap_is_active_bound"])
		),
		"positive-work power cap rejects an otherwise sufficient isometric actuator"
	)
	var absorption := _request()
	absorption["joints"][0]["angular_rate_rad_s"] = 2.0
	absorption["joints"][0]["actuator_spec"] = _spec(20.0, 100.0, 4.0, 30.0, true)
	var absorption_report: Dictionary = _analyze(absorption)["report"]["joint_reports"][0]
	_check(
		(
			not bool(absorption_report["actuator_envelope_passed"])
			and String(absorption_report["work_regime"]) == "negative_work"
			and bool(absorption_report["power_cap_is_active_bound"])
		),
		"absorption-power cap rejects excessive negative work"
	)
	var weak_structure := _request()
	weak_structure["joints"][0]["actuator_spec"] = _spec(20.0, 100.0, 100.0, 8.0, true)
	var structure_report: Dictionary = _analyze(weak_structure)["report"]["joint_reports"][0]
	_check(
		(
			bool(structure_report["actuator_envelope_passed"])
			and not bool(structure_report["structural_cap_passed"])
		),
		"structural torque cap can reject a command that fits the active envelope"
	)
	var near_limit := _request()
	near_limit["joints"][0]["angle_rad"] = 0.95
	var limit_report: Dictionary = _analyze(near_limit)["report"]["joint_reports"][0]
	_check(
		(
			not bool(limit_report["joint_limit_passed"])
			and float(limit_report["minimum_joint_limit_margin_rad"]) < 0.1
		),
		"declared pose too near a joint stop fails the margin screen"
	)
	var disabled := _request()
	disabled["joints"][0]["actuator_spec"] = _spec(20.0, 100.0, 100.0, 30.0, false)
	var disabled_report: Dictionary = _analyze(disabled)["report"]
	_check(
		(
			not bool(disabled_report["screen_passed"])
			and not bool(disabled_report["joint_reports"][0]["directional_capacity_available"])
		),
		"disabled actuator cannot manufacture active capacity"
	)


func _test_containment() -> void:
	print("- topology, provenance, digest, and claim boundaries fail closed")
	var base := _request()
	var measured := base.duplicate(true)
	measured["contacts"][0]["command_not_measurement"] = false
	_check(
		not bool(OracleScript.compile(measured).get("ok", true)),
		"contact command cannot be relabeled a measured load"
	)
	var nonunit := base.duplicate(true)
	nonunit["joints"][0]["axis_world"] = [0, 0, 2]
	_check(
		not bool(OracleScript.compile(nonunit).get("ok", true)), "non-unit joint axis is rejected"
	)
	var unknown_contact := base.duplicate(true)
	unknown_contact["joints"][0]["downstream_contact_ids"] = ["missing_pad"]
	_check(
		not bool(OracleScript.compile(unknown_contact).get("ok", true)),
		"joint cannot cite an unknown downstream contact"
	)
	var unassigned := base.duplicate(true)
	unassigned["contacts"].append(_contact("unused_pad", [-1, 0, 0], [0, 1, 0]))
	_check(
		not bool(OracleScript.compile(unassigned).get("ok", true)),
		"every declared contact command must enter at least one joint map"
	)
	var duplicate_joint := base.duplicate(true)
	duplicate_joint["joints"].append(duplicate_joint["joints"][0].duplicate(true))
	duplicate_joint["joints"][1]["actuator_spec"] = _spec(
		20.0, 100.0, 100.0, 30.0, true, "other_actuator"
	)
	_check(
		not bool(OracleScript.compile(duplicate_joint).get("ok", true)),
		"duplicate joint identity is rejected"
	)
	var duplicate_actuator := base.duplicate(true)
	var second_joint: Dictionary = duplicate_actuator["joints"][0].duplicate(true)
	second_joint["joint_id"] = "other_joint"
	duplicate_actuator["joints"].append(second_joint)
	_check(
		not bool(OracleScript.compile(duplicate_actuator).get("ok", true)),
		"one actuator identity cannot be silently reused across joints"
	)
	var forged_spec := base.duplicate(true)
	forged_spec["joints"][0]["actuator_spec"]["max_isometric_torque_nm"] = 200.0
	_check(
		not bool(OracleScript.compile(forged_spec).get("ok", true)),
		"mutated BR4 actuator spec fails its source digest"
	)
	var complete_bias := base.duplicate(true)
	complete_bias["joints"][0]["bias_torque_source"] = "complete_inverse_dynamics"
	_check(
		not bool(OracleScript.compile(complete_bias).get("ok", true)),
		"incomplete declared bias cannot be promoted by relabeling"
	)
	var broader_claim := base.duplicate(true)
	broader_claim["claim_boundary"] = "This proves a spatial creature can stand and walk."
	_check(
		not bool(OracleScript.compile(broader_claim).get("ok", true)),
		"broader physical claim is rejected"
	)
	var guidance := base.duplicate(true)
	guidance["automatic_creature_guidance_allowed"] = true
	_check(
		not bool(OracleScript.compile(guidance).get("ok", true)),
		"automatic creature guidance is rejected"
	)
	var compiled := OracleScript.compile(base)
	var mutated: Dictionary = (compiled["request"] as Dictionary).duplicate(true)
	mutated["contacts"][0]["force_command_world_n"][1] = 9.0
	_check(
		not bool(OracleScript.analyze(mutated).get("ok", true)),
		"post-seal contact-command mutation fails closed"
	)
	var report: Dictionary = _analyze(base)["report"]
	_check(
		(
			not bool(report["complete_rigid_body_inverse_dynamics_established"])
			and not bool(report["activation_or_torque_rate_feasibility_established"])
			and not bool(report["inverse_kinematic_reach_established"])
			and not bool(report["collision_clearance_established"])
			and not bool(report["canonical_morphology_selected"])
			and not bool(report["physical_stance_or_recovery_established"])
			and not bool(report["step_gait_or_walking_established"])
			and not bool(report["automatic_creature_guidance_allowed"])
		),
		"report grants no morphology, reach, dynamics, physical capability, walking, or guidance"
	)


func _request() -> Dictionary:
	return {
		"schema_version": OracleScript.SCHEMA_VERSION,
		"analysis_id": "br14a.prephysical.actuator_load",
		"reference_frame": "centroidal_world",
		"minimum_joint_limit_margin_rad": 0.1,
		"contacts": [_contact("right_pad", [1, 0, 0], [0, 10, 0])],
		"joints":
		[
			{
				"joint_id": "right_hip",
				"axis_world": [0, 0, 1],
				"pivot_world_m": [0, 0, 0],
				"angular_rate_rad_s": 0.0,
				"angle_rad": 0.0,
				"minimum_angle_rad": -1.0,
				"maximum_angle_rad": 1.0,
				"downstream_contact_ids": ["right_pad"],
				"declared_bias_torque_nm": 0.0,
				"bias_torque_source": OracleScript.BIAS_SOURCE,
				"full_activation_assumed": true,
				"actuator_spec": _spec(20.0, 100.0, 100.0, 30.0, true),
			}
		],
		"claim_boundary": OracleScript.CLAIM_BOUNDARY,
		"automatic_creature_guidance_allowed": false,
	}


func _contact(contact_id: String, point: Array, force: Array) -> Dictionary:
	return {
		"contact_id": contact_id,
		"point_world_m": point,
		"force_command_world_n": force,
		"command_not_measurement": true,
	}


func _spec(
	max_torque: float,
	positive_power: float,
	absorption_power: float,
	structural_torque: float,
	enabled: bool,
	actuator_id: String = "right_hip_actuator"
) -> Dictionary:
	var compiled := (
		ActuatorSpecScript
		. compile(
			{
				"schema_version": ActuatorSpecScript.SCHEMA_VERSION,
				"actuator_id": actuator_id,
				"enabled": enabled,
				"max_isometric_torque_nm": max_torque,
				"no_load_speed_rad_s": 10.0,
				"max_positive_power_w": positive_power,
				"max_absorption_power_w": absorption_power,
				"max_eccentric_multiplier": 1.5,
				"activation_time_s": 0.05,
				"deactivation_time_s": 0.08,
				"max_torque_rate_nm_s": 1000.0,
				"structural_torque_limit_nm": structural_torque,
				"tear_dwell_s": 0.1,
				"capacity_source": "explicit_lab",
				"muscle_pcsa_m2": 0.0,
				"specific_tension_pa": 0.0,
				"moment_arm_m": 0.0,
			}
		)
	)
	return compiled["spec"]


func _analyze(request: Dictionary) -> Dictionary:
	var compiled := OracleScript.compile(request)
	if not bool(compiled.get("ok", false)):
		return compiled
	return OracleScript.analyze(compiled["request"])


func _close(left: float, right: float, tolerance: float = 1.0e-8) -> bool:
	return absf(left - right) <= tolerance


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
