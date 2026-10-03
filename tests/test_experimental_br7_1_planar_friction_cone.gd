extends SceneTree

## BR7.1 friction-cone and unilateral infeasibility controls.

const AllocatorScript := preload("res://scripts/lab/mechanics/planar_contact_allocator.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR7.1 planar friction-cone rejection ===")
	var inside := AllocatorScript.allocate(_request(20.0, 100.0, 0.0, true, true))
	var inside_value: Dictionary = inside["allocation"]
	_check(
		(
			bool(inside_value["feasible"])
			and absf(float(inside_value["left"]["tangent_force_n"]) - 10.0) <= 1.0e-12
			and absf(float(inside_value["right"]["tangent_force_n"]) - 10.0) <= 1.0e-12
		),
		"feasible horizontal force is distributed with the normal load"
	)
	_check(
		(
			absf(float(inside_value["left"]["friction_utilization"]) - 1.0 / 3.0) <= 1.0e-12
			and absf(float(inside_value["right"]["friction_utilization"]) - 1.0 / 3.0) <= 1.0e-12
		),
		"per-contact friction utilization is explicit"
	)

	var outside := AllocatorScript.allocate(_request(70.0, 100.0, 0.0, true, true))
	var outside_value: Dictionary = outside["allocation"]
	_check(
		(
			not bool(outside_value["feasible"])
			and outside_value["infeasibility_reasons"].has("LEFT_FRICTION_CONE_VIOLATION")
			and outside_value["infeasibility_reasons"].has("RIGHT_FRICTION_CONE_VIOLATION")
		),
		"two-contact request outside both Coulomb cones is rejected"
	)

	var single_exact := AllocatorScript.allocate(_request(10.0, 50.0, -25.0, true, false))
	var single_value: Dictionary = single_exact["allocation"]
	_check(
		(
			bool(single_value["feasible"])
			and absf(float(single_value["left"]["normal_force_n"]) - 50.0) <= 1.0e-12
			and absf(float(single_value["left"]["tangent_force_n"]) - 10.0) <= 1.0e-12
		),
		"one declared bearing support can realize only its exact point moment"
	)

	var single_wrong_moment := AllocatorScript.allocate(_request(0.0, 50.0, 0.0, true, false))
	_check(
		(
			not bool(single_wrong_moment["allocation"]["feasible"])
			and single_wrong_moment["allocation"]["infeasibility_reasons"].has(
				"PITCH_MOMENT_RESIDUAL"
			)
		),
		"single support rejects an independently requested pitch moment"
	)

	var no_support := AllocatorScript.allocate(_request(0.0, 50.0, 0.0, false, false))
	_check(
		(
			not bool(no_support["allocation"]["feasible"])
			and no_support["allocation"]["infeasibility_reasons"].has("NO_BEARING_SUPPORT")
		),
		"zero bearing supports cannot synthesize a wrench"
	)

	var pulling := AllocatorScript.allocate(_request(0.0, -1.0, 0.0, true, true))
	_check(
		(
			not bool(pulling["allocation"]["feasible"])
			and pulling["allocation"]["infeasibility_reasons"].has("PULLING_TOTAL_NORMAL_REQUEST")
		),
		"negative total normal load fails the unilateral contract"
	)

	var zero_normal_shear := AllocatorScript.allocate(_request(1.0, 0.0, 0.0, true, true))
	_check(
		(
			not bool(zero_normal_shear["allocation"]["feasible"])
			and zero_normal_shear["allocation"]["infeasibility_reasons"].has(
				"HORIZONTAL_FORCE_WITHOUT_NORMAL_SUPPORT"
			)
		),
		"horizontal force without normal support is rejected"
	)
	_finish()


static func _request(
	horizontal: float, vertical: float, moment: float, left_bearing: bool, right_bearing: bool
) -> Dictionary:
	return {
		"schema_version": "planar_contact_allocation_request_v1",
		"tick": 0,
		"desired_force_x_n": horizontal,
		"desired_force_y_n": vertical,
		"desired_moment_z_nm": moment,
		"left_support_x_m": -0.5,
		"right_support_x_m": 0.5,
		"left_bearing": left_bearing,
		"right_bearing": right_bearing,
		"friction_coefficient": 0.6,
		"minimum_normal_n": 0.0,
		"maximum_normal_n": 120.0,
		"feasibility_tolerance": 1.0e-9,
	}


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
