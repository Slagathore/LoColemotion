extends SceneTree
# gdlint: disable=max-line-length

## Analytic commissioning for the pure centroidal-support command allocator.

const ControllerScript := preload(
	"res://scripts/lab/mechanics/spatial_centroidal_support_controller.gd"
)

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR14A.5 centroidal support controller ===")
	var request := _request()
	var result := ControllerScript.command(request)
	_check(bool(result.get("ok", false)), "valid three-contact command compiles")
	if not bool(result.get("ok", false)):
		printerr(result)
		_finish()
		return
	var command: Dictionary = result["command"]
	_check(bool(command["feasible"]), "COM-inside three-contact allocation is feasible")
	_check(
		(command["force_residual_n"] as Vector3).length() <= 1.0e-6,
		"allocated external force closes exactly"
	)
	_check(
		(command["roll_pitch_moment_residual_nm"] as Vector2).length() <= 1.0e-6,
		"allocated roll/pitch moment closes exactly"
	)
	var normal_sum := 0.0
	var task_vertical_sum := 0.0
	var all_commands_not_measurements := true
	for contact_value in command["support_contact_commands"].values():
		var contact: Dictionary = contact_value
		normal_sum += float(contact["normal_force_command_n"])
		task_vertical_sum += (contact["joint_task_force_delta_world_n"] as Vector3).y
		all_commands_not_measurements = (
			all_commands_not_measurements and bool(contact["command_not_measurement"])
		)
	_check(
		absf(normal_sum - 78.4) <= 1.0e-5,
		"three support normals carry the declared whole-system weight command"
	)
	_check(
		absf(task_vertical_sum + 19.6) <= 1.0e-5,
		"endpoint task deltas oppose the one-contact nominal support deficit"
	)
	_check(
		(
			all_commands_not_measurements
			and bool(command["per_contact_values_are_commands_not_measurements"])
			and not bool(command["per_foot_measured_load_allocation_available"])
			and not bool(command["physics_state_modified"])
		),
		"allocator grants no measurement or physics-write authority"
	)

	var moving_request := request.duplicate(true)
	moving_request["center_of_mass_velocity_world_m_s"] = Vector3(-0.2, 0.0, 0.1)
	var moving := ControllerScript.command(moving_request)
	_check(
		(
			bool(moving.get("ok", false))
			and ((moving["command"]["desired_external_force_world_n"] as Vector3).x > 0.0)
			and ((moving["command"]["desired_external_force_world_n"] as Vector3).z < 0.0)
		),
		"COM-velocity feedback commands the opposing horizontal correction"
	)

	var partial_support_request := request.duplicate(true)
	partial_support_request["declared_supported_weight_fraction"] = 0.75
	var partial_support := ControllerScript.command(partial_support_request)
	_check(
		(
			bool(partial_support.get("ok", false))
			and bool(partial_support["command"]["feasible"])
			and (
				absf(
					(
						(partial_support["command"]["desired_external_force_world_n"] as Vector3).y
						- 58.8
					)
				)
				<= 1.0e-5
			)
		),
		"declared three-of-four preload commands exactly 75 percent body weight"
	)

	var preferred_request := request.duplicate(true)
	preferred_request["center_of_mass_world_m"] = Vector3(0.0, 0.38625, 0.0)
	preferred_request["target_center_of_mass_world_m"] = Vector3(0.0, 0.38625, 0.0)
	preferred_request["support_contacts"] = [
		{
			"contact_id": "front_left.foot",
			"point_world_m": Vector3(-0.22, 0.0, -0.22),
			"preferred_normal_force_n": 24.6,
		},
		{
			"contact_id": "rear_left.foot",
			"point_world_m": Vector3(0.22, 0.0, -0.22),
			"preferred_normal_force_n": 14.6,
		},
		{
			"contact_id": "rear_right.foot",
			"point_world_m": Vector3(0.22, 0.0, 0.22),
			"preferred_normal_force_n": 24.6,
		},
		{
			"contact_id": "front_right.foot",
			"point_world_m": Vector3(-0.22, 0.0, 0.22),
			"preferred_normal_force_n": 14.6,
		},
	]
	var preferred := ControllerScript.command(preferred_request)
	var maximum_preference_error_n := 0.0
	if bool(preferred.get("ok", false)):
		for contact_value in preferred["command"]["support_contact_commands"].values():
			var contact: Dictionary = contact_value
			for requested_value in preferred_request["support_contacts"]:
				var requested_contact: Dictionary = requested_value
				if String(requested_contact["contact_id"]) == String(contact["contact_id"]):
					maximum_preference_error_n = maxf(
						maximum_preference_error_n,
						absf(
							(
								float(contact["normal_force_command_n"])
								- float(requested_contact["preferred_normal_force_n"])
							)
						)
					)
	_check(
		(
			bool(preferred.get("ok", false))
			and bool(preferred["command"]["feasible"])
			and maximum_preference_error_n <= 1.0e-5
		),
		"four-contact nullspace preserves an already wrench-consistent preferred load split"
	)
	var invalid_preference := preferred_request.duplicate(true)
	invalid_preference["support_contacts"][0]["preferred_normal_force_n"] = -1.0
	_check(
		not bool(ControllerScript.command(invalid_preference).get("ok", false)),
		"negative preferred contact load fails closed"
	)

	var outside_request := request.duplicate(true)
	outside_request["center_of_mass_world_m"] = Vector3(-0.20, 0.38625, 0.20)
	outside_request["target_center_of_mass_world_m"] = Vector3(-0.20, 0.38625, 0.20)
	var outside := ControllerScript.command(outside_request)
	_check(
		bool(outside.get("ok", false)) and not bool(outside["command"]["feasible"]),
		"COM outside the three-contact triangle produces an infeasible normal allocation"
	)

	var friction_request := request.duplicate(true)
	friction_request["target_center_of_mass_world_m"] = Vector3(1.0, 0.38625, -0.09)
	friction_request["maximum_horizontal_force_n"] = 200.0
	friction_request["horizontal_position_gain_n_per_m"] = 1000.0
	var friction := ControllerScript.command(friction_request)
	_check(
		bool(friction.get("ok", false)) and not bool(friction["command"]["feasible"]),
		"friction-exceeding horizontal request is explicitly infeasible"
	)

	var rank_deficient := request.duplicate(true)
	rank_deficient["support_contacts"] = [
		{"contact_id": "a", "point_world_m": Vector3(-0.2, 0.0, 0.0)},
		{"contact_id": "b", "point_world_m": Vector3(0.0, 0.0, 0.0)},
		{"contact_id": "c", "point_world_m": Vector3(0.2, 0.0, 0.0)},
	]
	_check(
		not bool(ControllerScript.command(rank_deficient).get("ok", false)),
		"rank-deficient support geometry fails closed"
	)

	var two_contacts := request.duplicate(true)
	two_contacts["support_contacts"] = (request["support_contacts"] as Array).slice(0, 2)
	_check(
		not bool(ControllerScript.command(two_contacts).get("ok", false)),
		"fewer than three support contacts fail closed"
	)
	_finish()


static func _request() -> Dictionary:
	return {
		"schema_version": ControllerScript.REQUEST_SCHEMA_VERSION,
		"tick": 0,
		"whole_system_mass_kg": 8.0,
		"gravity_m_s2": 9.8,
		"center_of_mass_world_m": Vector3(0.09, 0.38625, -0.09),
		"center_of_mass_velocity_world_m_s": Vector3.ZERO,
		"target_center_of_mass_world_m": Vector3(0.09, 0.38625, -0.09),
		"torso_roll_rad": 0.0,
		"torso_pitch_rad": 0.0,
		"torso_roll_rate_rad_s": 0.0,
		"torso_pitch_rate_rad_s": 0.0,
		"horizontal_position_gain_n_per_m": 160.0,
		"horizontal_velocity_gain_ns_per_m": 24.0,
		"vertical_position_gain_n_per_m": 200.0,
		"vertical_velocity_gain_ns_per_m": 30.0,
		"roll_position_gain_nm_per_rad": 30.0,
		"roll_velocity_gain_nm_s_per_rad": 4.0,
		"pitch_position_gain_nm_per_rad": 30.0,
		"pitch_velocity_gain_nm_s_per_rad": 4.0,
		"maximum_horizontal_force_n": 30.0,
		"maximum_vertical_correction_n": 20.0,
		"maximum_roll_pitch_moment_nm": 6.0,
		"declared_supported_weight_fraction": 1.0,
		"friction_coefficient": 0.60,
		"minimum_normal_force_n": 0.0,
		"maximum_normal_force_n": 39.2,
		"nominal_support_count": 4,
		"feasibility_tolerance": 1.0e-5,
		"support_contacts":
		[
			{"contact_id": "front_left.foot", "point_world_m": Vector3(-0.22, 0.0, -0.22)},
			{"contact_id": "rear_left.foot", "point_world_m": Vector3(0.22, 0.0, -0.22)},
			{"contact_id": "rear_right.foot", "point_world_m": Vector3(0.22, 0.0, 0.22)},
		],
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
