extends SceneTree
# gdlint: disable=max-line-length

## BR14A.1 prephysical conservative ordinary-contact feasibility only.
##
## All per-contact values are commands. No measured allocation, actuator
## feasibility, dynamics, physical stance/recovery, or walking is claimed.

const OracleScript := preload("res://scripts/lab/mechanics/spatial_contact_feasibility_oracle.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.1 spatial contact feasibility ===")
	_test_single_contact_unilateral_and_friction()
	_test_two_contact_moment()
	_test_containment()
	_finish()


func _test_single_contact_unilateral_and_friction() -> void:
	print("- one contact supports bounded push but never pulling")
	var vertical := _analyze(_request([0, 10, 0, 0, 0, 0], [_contact("center", 0.0, 10.0)]))
	_check(bool(vertical.get("ok", false)), "strict one-contact request analyzes")
	var vertical_report: Dictionary = vertical["report"]
	_check(
		bool(vertical_report["feasible"]),
		"10 N upward request is feasible at the declared 10 N normal capacity"
	)
	_check(
		(
			absf(float(vertical_report["residual_norm"])) <= 1.0e-3
			and (
				absf(float(vertical_report["contact_commands"][0]["normal_command_n"]) - 10.0)
				<= 1.0e-3
			)
		),
		"vertical allocation closes within the declared tolerance using a nonnegative command"
	)
	var pulling := _analyze(_request([0, -1, 0, 0, 0, 0], [_contact("center", 0.0, 10.0)]))
	_check(not bool(pulling["report"]["feasible"]), "negative normal request cannot pull on ground")
	var friction_ok := _analyze(_request([4, 10, 0, 0, 0, 0], [_contact("center", 0.0, 12.0)]))
	_check(bool(friction_ok["report"]["feasible"]), "4 N shear fits inside mu=0.5 at 10 N normal")
	_check(
		float(friction_ok["report"]["contact_commands"][0]["friction_utilization"]) <= 1.0 + 1.0e-6,
		"feasible shear command stays inside the conservative pyramid"
	)
	var friction_bad := _analyze(_request([6, 10, 0, 0, 0, 0], [_contact("center", 0.0, 12.0)]))
	_check(not bool(friction_bad["report"]["feasible"]), "6 N shear exceeds mu=0.5 at 10 N normal")
	var cone_only := _analyze(_request([3.5, 10, 3.5, 0, 0, 0], [_contact("center", 0.0, 12.0)]))
	_check(
		not bool(cone_only["report"]["feasible"]),
		"diagonal shear inside the circular cone can remain outside the conservative pyramid"
	)
	_check(
		(
			bool(vertical_report["per_contact_values_are_commands_not_measurements"])
			and not bool(vertical_report["exact_coulomb_cone_completeness_established"])
			and not bool(vertical_report["actuator_reachability_or_capacity_established"])
		),
		"allocation remains a conservative command screen, not a measurement or actuator proof"
	)


func _test_two_contact_moment() -> void:
	print("- two contacts realize bounded pitch moment and reject excess")
	var contacts := [_contact("left", -1.0, 20.0), _contact("right", 1.0, 20.0)]
	var bounded := _analyze(_request([0, 20, 0, 0, 0, 10], contacts))
	_check(bool(bounded["report"]["feasible"]), "20 N support plus 10 Nm pitch moment is feasible")
	var commands: Array = bounded["report"]["contact_commands"]
	_check(
		(
			float(commands[0]["normal_command_n"]) < float(commands[1]["normal_command_n"])
			and (
				absf(
					(
						float(commands[0]["normal_command_n"])
						+ float(commands[1]["normal_command_n"])
						- 20.0
					)
				)
				<= 1.0e-2
			)
		),
		"rightward moment shifts commanded normal support rightward"
	)
	_check(
		(
			float(commands[0]["capacity_utilization"]) <= 1.0 + 1.0e-6
			and float(commands[1]["capacity_utilization"]) <= 1.0 + 1.0e-6
		),
		"both contact commands respect declared normal caps"
	)
	var excessive := _analyze(_request([0, 20, 0, 0, 0, 30], contacts))
	_check(
		not bool(excessive["report"]["feasible"]),
		"30 Nm moment is impossible at 20 N total support"
	)
	_check(
		(
			not bool(bounded["report"]["dynamic_controllability_established"])
			and not bool(bounded["report"]["canonical_morphology_selected"])
			and not bool(bounded["report"]["physical_stance_or_recovery_established"])
			and not bool(bounded["report"]["step_gait_or_walking_established"])
			and not bool(bounded["report"]["automatic_creature_guidance_allowed"])
		),
		"feasible command establishes no physical capability, morphology, or guidance"
	)


func _test_containment() -> void:
	print("- frame, capacity, digest, and claim boundaries fail closed")
	var base := _request([0, 10, 0, 0, 0, 0], [_contact("center", 0.0, 10.0)])
	var left_handed := base.duplicate(true)
	left_handed["contacts"][0]["tangent_v_world"] = [0, 0, 1]
	_check(
		not bool(OracleScript.compile(left_handed).get("ok", true)),
		"left-handed contact frame is rejected"
	)
	var hidden_pull := base.duplicate(true)
	hidden_pull["contacts"][0]["ordinary_unilateral_contact"] = false
	_check(
		not bool(OracleScript.compile(hidden_pull).get("ok", true)),
		"nonordinary contact authority is rejected"
	)
	var invalid_capacity := base.duplicate(true)
	invalid_capacity["contacts"][0]["normal_capacity_n"] = 0.0
	_check(
		not bool(OracleScript.compile(invalid_capacity).get("ok", true)),
		"zero normal capacity is rejected"
	)
	var split_centroid := base.duplicate(true)
	split_centroid["contacts"][0]["center_of_mass_world_m"] = [1, 0, 0]
	_check(
		not bool(OracleScript.compile(split_centroid).get("ok", true)),
		"contacts cannot inject independent center-of-mass frames"
	)
	var invalid_centroid := base.duplicate(true)
	invalid_centroid["center_of_mass_world_m"] = [0, NAN, 0]
	_check(
		not bool(OracleScript.compile(invalid_centroid).get("ok", true)),
		"nonfinite shared whole-system center of mass is rejected"
	)
	var invalid_friction := base.duplicate(true)
	invalid_friction["contacts"][0]["friction_coefficient"] = NAN
	_check(
		not bool(OracleScript.compile(invalid_friction).get("ok", true)),
		"nonfinite friction is rejected"
	)
	var broader_claim := base.duplicate(true)
	broader_claim["claim_boundary"] = "This proves free-3D standing and walking."
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
	mutated["desired_wrench_world"][1] = 9.0
	_check(
		not bool(OracleScript.analyze(mutated).get("ok", true)),
		"post-seal desired-wrench mutation fails closed"
	)


func _request(desired: Array, contacts: Array) -> Dictionary:
	return {
		"schema_version": OracleScript.SCHEMA_VERSION,
		"analysis_id": "br14a.prephysical.contact_screen",
		"reference_frame": "centroidal_world",
		"center_of_mass_world_m": [0, 0, 0],
		"characteristic_length_m": 1.0,
		"desired_wrench_world": desired,
		"contacts": contacts,
		"residual_tolerance": 1.0e-3,
		"maximum_iterations": 12000,
		"claim_boundary": OracleScript.CLAIM_BOUNDARY,
		"automatic_creature_guidance_allowed": false,
	}


func _contact(contact_id: String, x: float, capacity: float) -> Dictionary:
	return {
		"contact_id": contact_id,
		"point_world_m": [x, 0.0, 0],
		"normal_world": [0, 1, 0],
		"tangent_u_world": [1, 0, 0],
		"tangent_v_world": [0, 0, -1],
		"friction_coefficient": 0.5,
		"normal_capacity_n": capacity,
		"ordinary_unilateral_contact": true,
	}


func _analyze(request: Dictionary) -> Dictionary:
	var compiled := OracleScript.compile(request)
	if not bool(compiled.get("ok", false)):
		return compiled
	return OracleScript.analyze(compiled["request"])


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
