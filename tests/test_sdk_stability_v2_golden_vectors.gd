extends SceneTree

## Independent GDScript oracle for the portable Semantics v2 stability port.
##
## The checked-in JSON is consumed by this Godot test and the Rust core tests.
## The existing mechanics modules remain the support/controller oracle. The
## J-transpose cell evaluates its independent one-line virtual-work identity.

const StaticObserver := preload(
	"res://scripts/lab/mechanics/spatial_support_margin_observer.gd"
)
const DynamicObserver := preload(
	"res://scripts/lab/mechanics/spatial_dynamic_support_observer.gd"
)
const CentroidalController := preload(
	"res://scripts/lab/mechanics/spatial_centroidal_support_controller.gd"
)
const GOLDEN_PATH := "res://sdk/conformance/golden/stability_v2_gdscript_oracle_v1.json"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== SDK stability v2 GDScript golden-vector oracle ===")
	var golden := _load_golden()
	_check(
		String(golden.get("schema_version", ""))
		== "sporespore_stability_v2_gdscript_oracle_v1",
		"golden schema is exact"
	)
	var fixture := Node3D.new()
	fixture.name = "SdkStabilityV2GoldenFixture"
	root.add_child(fixture)
	var body_by_id := {}
	var observer_fixture: Dictionary = golden["observer_fixture"]
	for body_value in observer_fixture["bodies"]:
		var body_record: Dictionary = body_value
		var body := RigidBody3D.new()
		body.name = String(body_record["body_id"])
		body.mass = float(body_record["mass_kg"])
		body.position = _vector3(body_record["position_world_m"])
		body.linear_velocity = _vector3(body_record["linear_velocity_world_m_s"])
		body.freeze = true
		fixture.add_child(body)
		body_by_id[String(body_record["body_id"])] = body
	await process_frame

	var support_points: Array[Vector3] = []
	for point in observer_fixture["support_points_world_m"]:
		support_points.append(_vector3(point))
	var expected_observer: Dictionary = observer_fixture["expected"]
	var comparison_tolerances: Dictionary = golden["comparison_tolerances"]
	var vector_tolerance := float(comparison_tolerances["godot_binary32_vector_absolute"])
	var force_tolerance := float(comparison_tolerances["godot_binary32_force_absolute"])
	var static_observed := StaticObserver.observe(body_by_id, support_points)
	var dynamic_observed := DynamicObserver.observe(
		body_by_id,
		support_points,
		float(observer_fixture["gravity_m_s2"])
	)
	_check(bool(static_observed.get("ok", false)), "static support oracle observes")
	_check(bool(dynamic_observed.get("ok", false)), "dynamic support oracle observes")
	if bool(static_observed.get("ok", false)) and bool(dynamic_observed.get("ok", false)):
		_check(
			absf(
				float(static_observed["whole_system_mass_kg"])
				- float(expected_observer["whole_system_mass_kg"])
			)
			<= 1.0e-12,
			"whole-system mass matches golden"
		)
		_check(
			(static_observed["center_of_mass_world_m"] as Vector3).distance_to(
				_vector3(expected_observer["center_of_mass_world_m"])
			)
			<= 1.0e-12,
			"static whole-system COM matches golden"
		)
		_check(
			(dynamic_observed["center_of_mass_velocity_world_m_s"] as Vector3).distance_to(
				_vector3(expected_observer["center_of_mass_velocity_world_m_s"])
			)
			<= 1.0e-12,
			"whole-system COM velocity matches golden"
		)
		_check(
			absf(
				float(static_observed["minimum_signed_margin_m"])
				- float(expected_observer["minimum_signed_static_margin_m"])
			)
			<= vector_tolerance,
			"static support margin matches golden"
		)
		_check(
			absf(
				float(dynamic_observed["linearized_natural_frequency_rad_s"])
				- float(expected_observer["linearized_natural_frequency_rad_s"])
			)
			<= vector_tolerance,
			"linearized natural frequency matches golden"
		)
		_check(
			(dynamic_observed["linearized_capture_point_world_m"] as Vector3).distance_to(
				_vector3(expected_observer["linearized_capture_point_world_m"])
			)
			<= vector_tolerance,
			"linearized capture point matches golden"
		)
		_check(
			absf(
				float(dynamic_observed["linearized_capture_margin_m"])
				- float(expected_observer["linearized_capture_margin_m"])
			)
			<= vector_tolerance,
			"dynamic support margin matches golden"
		)
		_check(
			(dynamic_observed["support_centroid_world_m"] as Vector3).distance_to(
				_vector3(expected_observer["support_centroid_world_m"])
			)
			<= 1.0e-12,
			"support centroid matches golden"
		)

	var centroidal_fixture: Dictionary = golden["centroidal_fixture"]
	var request: Dictionary = centroidal_fixture["request"].duplicate(true)
	for field in [
		"center_of_mass_world_m",
		"center_of_mass_velocity_world_m_s",
		"target_center_of_mass_world_m",
	]:
		request[field] = _vector3(request[field])
	for contact_value in request["support_contacts"]:
		var contact: Dictionary = contact_value
		contact["point_world_m"] = _vector3(contact["point_world_m"])
	var controlled := CentroidalController.command(request)
	_check(bool(controlled.get("ok", false)), "centroidal oracle commands")
	if bool(controlled.get("ok", false)):
		var command: Dictionary = controlled["command"]
		var expected_command: Dictionary = centroidal_fixture["expected"]
		var normal_sum := 0.0
		var task_vertical_sum := 0.0
		for contact_value in command["support_contact_commands"].values():
			var contact: Dictionary = contact_value
			normal_sum += float(contact["normal_force_command_n"])
			task_vertical_sum += (contact["joint_task_force_delta_world_n"] as Vector3).y
		_check(
			bool(command["feasible"]) == bool(expected_command["feasible"]),
			"centroidal feasibility matches golden"
		)
		_check(
			absf(
				(command["desired_external_force_world_n"] as Vector3).y
				- float(expected_command["desired_vertical_force_n"])
			)
			<= force_tolerance,
			"desired vertical force matches golden"
		)
		_check(
			absf(normal_sum - float(expected_command["normal_force_sum_n"])) <= force_tolerance,
			"normal-force sum matches golden"
		)
		_check(
			absf(
				task_vertical_sum
				- float(expected_command["joint_task_vertical_delta_sum_n"])
			)
			<= force_tolerance,
			"joint-task vertical delta sum matches golden"
		)
		_check(
			(command["force_residual_n"] as Vector3).length()
			<= float(expected_command["maximum_force_residual_n"]),
			"force residual respects golden ceiling"
		)
		_check(
			(command["roll_pitch_moment_residual_nm"] as Vector2).length()
			<= float(expected_command["maximum_roll_pitch_moment_residual_nm"]),
			"roll/pitch residual respects golden ceiling"
		)

	var joint_map_fixture: Dictionary = golden["joint_map_fixture"]
	var joint_axis := _vector3(joint_map_fixture["joint_axis_world_unit"])
	var joint_anchor := _vector3(joint_map_fixture["joint_anchor_world_m"])
	var endpoint := _vector3(joint_map_fixture["endpoint_world_m"])
	var endpoint_force := _vector3(
		joint_map_fixture["endpoint_task_force_command_world_n"]
	)
	var jacobian_column := joint_axis.cross(endpoint - joint_anchor)
	var generalized_torque_nm := jacobian_column.dot(endpoint_force)
	var expected_joint_map: Dictionary = joint_map_fixture["expected"]
	_check(
		jacobian_column.distance_to(
			_vector3(expected_joint_map["linear_jacobian_column_world_m"])
		)
		<= vector_tolerance,
		"J-transpose linear column matches golden"
	)
	_check(
		absf(
			generalized_torque_nm
			- float(expected_joint_map["generalized_torque_command_nm"])
		)
		<= force_tolerance,
		"virtual-work generalized torque matches golden"
	)

	var nonclaims: Dictionary = golden["required_nonclaims"]
	_check(
		(
			bool(dynamic_observed["linearized_capture_model_only"])
			== bool(nonclaims["linearized_capture_model_only"])
			and bool(dynamic_observed["articulated_capture_guarantee_available"])
			== bool(nonclaims["articulated_capture_guarantee_available"])
			and bool(dynamic_observed["per_foot_measured_load_allocation_available"])
			== bool(nonclaims["per_foot_measured_load_allocation_available"])
			and bool(dynamic_observed["contact_presence_is_bearing_measurement"])
			== bool(nonclaims["contact_presence_is_bearing_measurement"])
			and bool(dynamic_observed["physics_state_modified"])
			== bool(nonclaims["physics_state_modified"])
		),
		"observer nonclaims remain exact"
	)
	if bool(controlled.get("ok", false)):
		var command: Dictionary = controlled["command"]
		_check(
			(
				bool(command["per_contact_values_are_commands_not_measurements"])
				== bool(nonclaims["per_contact_values_are_commands_not_measurements"])
				and bool(command["per_foot_measured_load_allocation_available"])
				== bool(nonclaims["per_foot_measured_load_allocation_available"])
				and bool(command["physics_state_modified"])
				== bool(nonclaims["physics_state_modified"])
			),
			"controller nonclaims remain exact"
		)
	_check(
		(
			not bool(nonclaims["measured_joint_torque_available"])
			and not bool(nonclaims["actuator_response_characterized"])
			and not bool(nonclaims["adapter_actuation_applied"])
		),
		"J-transpose oracle retains mapping and actuation nonclaims"
	)

	fixture.queue_free()
	await process_frame
	print("SDK stability v2 golden summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _load_golden() -> Dictionary:
	var file := FileAccess.open(GOLDEN_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _vector3(value: Variant) -> Vector3:
	var raw: Array = value
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		printerr("  [FAIL] ", label)
