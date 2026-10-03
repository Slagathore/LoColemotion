extends SceneTree
# gdlint: disable=max-line-length

## BR14A.0 prephysical spatial rank only.
##
## These are pure linear-algebra fixtures. They select no canonical
## morphology and prove no unilateral feasibility, actuation, dynamics,
## standing, recovery, step, gait, walking, repair, or guidance.

const OracleScript := preload("res://scripts/lab/mechanics/spatial_wrench_rank_oracle.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.0 prephysical spatial-wrench rank ===")
	_test_contact_column_geometry()
	_test_four_contact_geometric_span()
	_test_full_synthetic_span()
	_test_planar_deficiency()
	_test_scaffold_dependency()
	_test_request_containment()
	_finish()


func _test_contact_column_geometry() -> void:
	print("- contact geometry maps unit forces into centroidal wrench columns")
	var result := OracleScript.contact_force_column(
		"front_right.normal", "front_right", Vector3(1.0, -0.5, 2.0), Vector3.ZERO, Vector3.UP
	)
	_check(bool(result.get("ok", false)), "finite unit contact direction compiles")
	var column: Dictionary = result["column"]
	_check(
		_near_array(column["wrench_per_unit"], [0.0, 1.0, 0.0, -2.0, 0.0, 1.0]),
		"r cross f produces the exact centroidal moment"
	)
	var nonunit := OracleScript.contact_force_column(
		"bad.normal", "bad", Vector3.ZERO, Vector3.ZERO, Vector3(0.0, 2.0, 0.0)
	)
	_check(not bool(nonunit.get("ok", true)), "non-unit contact directions fail closed")


func _test_four_contact_geometric_span() -> void:
	print("- four abstract floor contacts produce a six-rank geometric upper bound")
	var columns: Array = []
	var contact_index := 0
	for point in [
		Vector3(-1.0, -0.5, -1.0),
		Vector3(-1.0, -0.5, 1.0),
		Vector3(1.0, -0.5, -1.0),
		Vector3(1.0, -0.5, 1.0),
	]:
		var contact_id := "abstract_contact_%d" % contact_index
		for direction_index in range(3):
			var direction: Vector3 = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD][direction_index]
			var column := OracleScript.contact_force_column(
				"%s.direction_%d" % [contact_id, direction_index],
				contact_id,
				point,
				Vector3.ZERO,
				direction
			)
			columns.append(column["column"])
		contact_index += 1
	var compiled := OracleScript.compile(_request(columns))
	_check(bool(compiled.get("ok", false)), "twelve geometry-derived contact columns seal")
	var analyzed := OracleScript.analyze(compiled["request"])
	_check(bool(analyzed.get("ok", false)), "abstract contact map analyzes")
	var report: Dictionary = analyzed["report"]
	_check(
		(
			int(report["ordinary_contact_column_count"]) == 12
			and int(report["ordinary_contact_linearized_rank"]) == 6
		),
		"noncollinear contact geometry spans all six linearized wrench axes"
	)
	_check(
		(
			bool(report["all_required_axes_structurally_spanned_without_scaffold"])
			and not bool(report["unilateral_or_friction_feasibility_established"])
		),
		"geometric span remains explicitly weaker than feasible support"
	)


func _test_full_synthetic_span() -> void:
	print("- exact six-axis analytic columns expose a full structural upper bound")
	var compiled := OracleScript.compile(_request(_unit_columns("actuator_analytic")))
	_check(bool(compiled.get("ok", false)), "strict six-axis request seals")
	var analyzed := OracleScript.analyze(compiled["request"])
	_check(bool(analyzed.get("ok", false)), "sealed request analyzes")
	var report: Dictionary = analyzed["report"]
	_check(
		(
			int(report["non_scaffold_linearized_rank"]) == 6
			and int(report["actuator_analytic_rank"]) == 6
		),
		"independent nondimensionalized columns have rank six"
	)
	_check(
		bool(report["all_required_axes_structurally_spanned_without_scaffold"]),
		"all declared required axes lie in the non-scaffold linear span"
	)
	_check(
		(
			bool(report["rank_is_nondimensionalized_linear_upper_bound"])
			and not bool(report["unilateral_or_friction_feasibility_established"])
			and not bool(report["actuator_reachability_or_capacity_established"])
			and not bool(report["dynamic_controllability_established"])
		),
		"rank remains an upper bound rather than physical feasibility"
	)
	_check(
		(
			not bool(report["canonical_morphology_selected"])
			and not bool(report["physical_stance_or_recovery_established"])
			and not bool(report["step_gait_or_walking_established"])
			and not bool(report["automatic_creature_guidance_allowed"])
		),
		"report selects no morphology and grants no capability or guidance"
	)


func _test_planar_deficiency() -> void:
	print("- planar columns name the exact missing spatial axes")
	var planar_columns := [
		_column("planar.fx", "ordinary_contact_linearization", [1, 0, 0, 0, 0, 0]),
		_column("planar.fy", "ordinary_contact_linearization", [0, 1, 0, 0, 0, 0]),
		_column("planar.mz", "actuator_analytic", [0, 0, 0, 0, 0, 1]),
	]
	var request := _request(planar_columns)
	request["required_axes"] = ["force_x", "force_y", "moment_z"]
	request["intentionally_omitted_axes"] = ["force_z", "moment_x", "moment_y"]
	var compiled := OracleScript.compile(request)
	var analyzed := OracleScript.analyze(compiled["request"])
	var report: Dictionary = analyzed["report"]
	_check(int(report["non_scaffold_linearized_rank"]) == 3, "planar map has rank three")
	_check(
		bool(report["all_required_axes_structurally_spanned_without_scaffold"]),
		"declared planar task axes are structurally spanned"
	)
	_check(
		(
			_axis(report, "force_z")["intentionally_omitted"]
			and not _axis(report, "force_z")["structurally_spanned_without_scaffold"]
			and _axis(report, "moment_x")["intentionally_omitted"]
			and _axis(report, "moment_y")["intentionally_omitted"]
		),
		"out-of-plane force, roll, and pitch remain explicit omissions"
	)


func _test_scaffold_dependency() -> void:
	print("- scaffold columns cannot silently satisfy a required spatial axis")
	var columns := _unit_columns("actuator_analytic")
	columns.remove_at(3)
	columns.append(_column("guide.mx", "scaffold", [0, 0, 0, 1, 0, 0]))
	var compiled := OracleScript.compile(_request(columns))
	var analyzed := OracleScript.analyze(compiled["request"])
	var report: Dictionary = analyzed["report"]
	_check(int(report["all_linearized_rank"]) == 6, "guide restores all-column rank to six")
	_check(
		int(report["non_scaffold_linearized_rank"]) == 5,
		"non-scaffold rank preserves the missing roll authority"
	)
	var roll: Dictionary = _axis(report, "moment_x")
	_check(
		(
			not bool(roll["structurally_spanned_without_scaffold"])
			and bool(roll["structurally_spanned_with_scaffold"])
			and bool(roll["scaffold_dependent"])
			and bool(report["any_required_axis_scaffold_dependent"])
			and not bool(report["all_required_axes_structurally_spanned_without_scaffold"])
		),
		"required roll axis is named scaffold-dependent and cannot pass"
	)


func _test_request_containment() -> void:
	print("- request and claim boundaries fail closed")
	var base := _request(_unit_columns("actuator_analytic"))
	var duplicate_axis := base.duplicate(true)
	duplicate_axis["intentionally_omitted_axes"] = ["force_x"]
	_check(
		not bool(OracleScript.compile(duplicate_axis).get("ok", true)),
		"required and omitted axis overlap is rejected"
	)
	var incomplete_partition := base.duplicate(true)
	incomplete_partition["required_axes"].erase("moment_z")
	_check(
		not bool(OracleScript.compile(incomplete_partition).get("ok", true)),
		"an unclassified spatial axis is rejected"
	)
	var broader_claim := base.duplicate(true)
	broader_claim["claim_boundary"] = "This proves a walking morphology."
	_check(
		not bool(OracleScript.compile(broader_claim).get("ok", true)),
		"broader physical claim cannot enter the oracle"
	)
	var guidance := base.duplicate(true)
	guidance["automatic_creature_guidance_allowed"] = true
	_check(
		not bool(OracleScript.compile(guidance).get("ok", true)),
		"automatic creature guidance cannot enter the request"
	)
	var nonfinite := base.duplicate(true)
	nonfinite["columns"][0]["wrench_per_unit"][0] = NAN
	_check(
		not bool(OracleScript.compile(nonfinite).get("ok", true)), "nonfinite column fails closed"
	)
	var duplicate_column := base.duplicate(true)
	duplicate_column["columns"][1]["column_id"] = duplicate_column["columns"][0]["column_id"]
	_check(
		not bool(OracleScript.compile(duplicate_column).get("ok", true)),
		"duplicate column identity fails closed"
	)
	var compiled := OracleScript.compile(base)
	var mutated: Dictionary = (compiled["request"] as Dictionary).duplicate(true)
	mutated["columns"][0]["wrench_per_unit"][0] = 0.5
	_check(
		not bool(OracleScript.analyze(mutated).get("ok", true)),
		"post-seal column mutation fails the configuration digest"
	)
	var zero_column := base.duplicate(true)
	zero_column["columns"][0]["wrench_per_unit"] = [0, 0, 0, 0, 0, 0]
	_check(
		not bool(OracleScript.compile(zero_column).get("ok", true)),
		"zero columns cannot inflate declared controllability"
	)


func _request(columns: Array) -> Dictionary:
	return {
		"schema_version": OracleScript.SCHEMA_VERSION,
		"analysis_id": "br14a.prephysical.synthetic",
		"reference_frame": "centroidal_world",
		"characteristic_length_m": 0.5,
		"rank_tolerance": 1.0e-9,
		"axis_residual_tolerance": 1.0e-7,
		"columns": columns,
		"required_axes": OracleScript.AXES.duplicate(),
		"intentionally_omitted_axes": [],
		"claim_boundary": OracleScript.CLAIM_BOUNDARY,
		"automatic_creature_guidance_allowed": false,
	}


func _unit_columns(source_kind: String) -> Array:
	var columns: Array = []
	for index in range(6):
		var vector := [0, 0, 0, 0, 0, 0]
		vector[index] = 1
		columns.append(_column("axis.%d" % index, source_kind, vector))
	return columns


func _column(column_id: String, source_kind: String, wrench: Array) -> Dictionary:
	return {
		"column_id": column_id,
		"source_kind": source_kind,
		"source_id": "synthetic_source",
		"wrench_per_unit": wrench,
	}


func _axis(report: Dictionary, axis_name: String) -> Dictionary:
	for value in report["axis_results"]:
		var result: Dictionary = value
		if String(result["axis"]) == axis_name:
			return result
	return {}


func _near_array(actual: Array, expected: Array, tolerance := 1.0e-8) -> bool:
	if actual.size() != expected.size():
		return false
	for index in range(actual.size()):
		if absf(float(actual[index]) - float(expected[index])) > tolerance:
			return false
	return true


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
