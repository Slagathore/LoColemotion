extends SceneTree

## BR7.0 exact two-contact vertical-load and pitch-moment arithmetic.

const AllocatorScript := preload("res://scripts/lab/mechanics/planar_contact_allocator.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR7.0 planar contact allocation ===")
	var symmetric := AllocatorScript.allocate(_request(98.0, 0.0, 0.0))
	_check(bool(symmetric.get("ok", false)), "strict allocator request is accepted")
	var symmetric_value: Dictionary = symmetric["allocation"]
	_check(
		(
			bool(symmetric_value["feasible"])
			and absf(float(symmetric_value["left"]["normal_force_n"]) - 49.0) <= 1.0e-12
			and absf(float(symmetric_value["right"]["normal_force_n"]) - 49.0) <= 1.0e-12
		),
		"zero moment splits vertical load exactly and symmetrically"
	)
	_check(_residual_zero(symmetric_value), "symmetric force and moment residuals are zero")

	var positive := AllocatorScript.allocate(_request(100.0, 20.0, 0.0))
	var positive_value: Dictionary = positive["allocation"]
	_check(
		(
			bool(positive_value["feasible"])
			and absf(float(positive_value["left"]["normal_force_n"]) - 30.0) <= 1.0e-12
			and absf(float(positive_value["right"]["normal_force_n"]) - 70.0) <= 1.0e-12
		),
		"positive pitch moment shifts exact load to the right support"
	)
	_check(_residual_zero(positive_value), "positive-moment allocation preserves the exact wrench")

	var negative := AllocatorScript.allocate(_request(100.0, -20.0, 0.0))
	var negative_value: Dictionary = negative["allocation"]
	_check(
		(
			bool(negative_value["feasible"])
			and absf(float(negative_value["left"]["normal_force_n"]) - 70.0) <= 1.0e-12
			and absf(float(negative_value["right"]["normal_force_n"]) - 30.0) <= 1.0e-12
		),
		"negative pitch moment mirrors the load split"
	)

	var impossible := AllocatorScript.allocate(_request(100.0, 60.0, 0.0))
	var impossible_value: Dictionary = impossible["allocation"]
	_check(
		(
			not bool(impossible_value["feasible"])
			and impossible_value["infeasibility_reasons"].has("LEFT_NORMAL_BELOW_MINIMUM")
		),
		"a moment requiring a pulling contact is rejected without clamping"
	)
	_check(
		(
			not bool(impossible_value["allocator_clamped"])
			and bool(impossible_value["per_contact_values_are_commands_not_measurements"])
		),
		"allocator refuses to disguise infeasibility or call commands measurements"
	)

	var malformed := _request(98.0, 0.0, 0.0)
	malformed.erase("right_bearing")
	_check(
		(
			String(AllocatorScript.allocate(malformed).get("failure_code", ""))
			== "PLANAR_ALLOCATOR_FIELD_SET_MISMATCH"
		),
		"strict field-set mismatch fails closed"
	)
	_finish()


static func _request(vertical: float, moment: float, horizontal: float) -> Dictionary:
	return {
		"schema_version": "planar_contact_allocation_request_v1",
		"tick": 0,
		"desired_force_x_n": horizontal,
		"desired_force_y_n": vertical,
		"desired_moment_z_nm": moment,
		"left_support_x_m": -0.5,
		"right_support_x_m": 0.5,
		"left_bearing": true,
		"right_bearing": true,
		"friction_coefficient": 0.6,
		"minimum_normal_n": 0.0,
		"maximum_normal_n": 120.0,
		"feasibility_tolerance": 1.0e-9,
	}


static func _residual_zero(allocation: Dictionary) -> bool:
	var residual: Array = allocation["force_residual_n"]
	return (
		absf(float(residual[0])) <= 1.0e-12
		and absf(float(residual[1])) <= 1.0e-12
		and absf(float(allocation["moment_residual_z_nm"])) <= 1.0e-12
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
