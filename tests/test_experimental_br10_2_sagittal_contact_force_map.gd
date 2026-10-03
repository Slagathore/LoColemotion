extends SceneTree
# gdlint: disable=max-line-length

## BR10.2 strict sagittal contact-force J-transpose commissioning.

const BodyWrenchScript := preload("res://scripts/lab/mechanics/body_wrench.gd")
const SagittalMapScript := preload("res://scripts/lab/mechanics/sagittal_contact_force_map.gd")
const VerticalMapScript := preload("res://scripts/lab/mechanics/force_to_joint_map.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR10.2 sagittal contact-force map ===")
	var request := _request()
	var mapped := SagittalMapScript.map(request)
	_check(bool(mapped.get("ok", false)), "strict finite sagittal force request seals")
	if not bool(mapped.get("ok", false)):
		printerr("  map_failure=", mapped)
		_finish()
		return
	var mapping: Dictionary = mapped["mapping"]
	var q1 := float(request["joint_1_angle_rad"])
	var q2 := float(request["joint_2_angle_rad"])
	var q12 := q1 + q2
	var l1 := float(request["link_1_length_m"])
	var l2 := float(request["link_2_length_m"])
	var tangent := float(request["tangent_force_n"])
	var normal := float(request["normal_force_n"])
	var expected_jx1 := l1 * cos(q1) + l2 * cos(q12)
	var expected_jx2 := l2 * cos(q12)
	var expected_jy1 := l1 * sin(q1) + l2 * sin(q12)
	var expected_jy2 := l2 * sin(q12)
	_check(
		(
			_close(float(mapping["joint_1_tangent_jacobian_m"]), expected_jx1)
			and _close(float(mapping["joint_2_tangent_jacobian_m"]), expected_jx2)
			and _close(float(mapping["joint_1_normal_jacobian_m"]), expected_jy1)
			and _close(float(mapping["joint_2_normal_jacobian_m"]), expected_jy2)
		),
		"reported sagittal Jacobian matches the analytic endpoint derivatives"
	)
	_check(
		(
			_close(
				float(mapping["joint_1_contact_generalized_nm"]),
				expected_jx1 * tangent + expected_jy1 * normal
			)
			and _close(
				float(mapping["joint_2_contact_generalized_nm"]),
				expected_jx2 * tangent + expected_jy2 * normal
			)
		),
		"J-transpose combines commanded tangent and normal force exactly"
	)

	# Vector2 storage is single precision in this runtime, so use a finite-
	# difference step large enough to stay above float cancellation.
	var epsilon := 1.0e-3
	var base_endpoint := _endpoint(q1, q2, l1, l2)
	var q1_endpoint := _endpoint(q1 + epsilon, q2, l1, l2)
	var q2_endpoint := _endpoint(q1, q2 + epsilon, l1, l2)
	var force := Vector2(tangent, normal)
	var virtual_q1 := force.dot((q1_endpoint - base_endpoint) / epsilon)
	var virtual_q2 := force.dot((q2_endpoint - base_endpoint) / epsilon)
	_check(
		(
			absf(virtual_q1 - float(mapping["joint_1_contact_generalized_nm"])) <= 2.0e-2
			and absf(virtual_q2 - float(mapping["joint_2_contact_generalized_nm"])) <= 2.0e-2
		),
		"finite-difference virtual work agrees with both generalized forces"
	)

	var mirrored_request := request.duplicate(true)
	mirrored_request["tangent_force_n"] = -tangent
	var mirrored: Dictionary = SagittalMapScript.map(mirrored_request)["mapping"]
	_check(
		(
			_close(
				(
					float(mapping["joint_1_contact_generalized_nm"])
					- float(mirrored["joint_1_contact_generalized_nm"])
				),
				2.0 * expected_jx1 * tangent
			)
			and _close(
				(
					float(mapping["joint_2_contact_generalized_nm"])
					- float(mirrored["joint_2_contact_generalized_nm"])
				),
				2.0 * expected_jx2 * tangent
			)
		),
		"mirrored tangent command changes only the tangent generalized component"
	)
	_check(
		(
			_close(
				float(mapping["joint_1_link_gravity_nm"]),
				float(mirrored["joint_1_link_gravity_nm"])
			)
			and _close(
				float(mapping["joint_2_link_gravity_nm"]),
				float(mirrored["joint_2_link_gravity_nm"])
			)
		),
		"link-gravity terms remain independent of commanded contact force"
	)

	var zero_tangent_request := request.duplicate(true)
	zero_tangent_request["tangent_force_n"] = 0.0
	var zero_tangent: Dictionary = SagittalMapScript.map(zero_tangent_request)["mapping"]
	var body_wrench := (
		BodyWrenchScript
		. compile(
			{
				"schema_version": "body_wrench_v1",
				"wrench_id": "br10.vertical_parity",
				"source_id": "br10.map_test",
				"frame_id": "world",
				"application_point_world_m": [0.0, 0.0, 0.0],
				"force_world_n": [0.0, normal, 0.0],
				"moment_world_nm": [0.0, 0.0, 0.0],
			}
		)
	)
	var vertical := (
		VerticalMapScript
		. map(
			{
				"schema_version": "two_link_force_map_request_v1",
				"joint_1_angle_rad": q1,
				"joint_2_angle_rad": q2,
				"link_1_length_m": l1,
				"link_2_length_m": l2,
				"carriage_mass_kg": request["carriage_mass_kg"],
				"link_1_mass_kg": request["link_1_mass_kg"],
				"link_2_mass_kg": request["link_2_mass_kg"],
				"gravity_m_s2": request["gravity_m_s2"],
				"wrench": body_wrench["wrench"],
			}
		)
	)
	_check(
		(
			bool(body_wrench.get("ok", false))
			and bool(vertical.get("ok", false))
			and _close(
				float(zero_tangent["joint_1_feedforward_nm"]),
				float(vertical["mapping"]["joint_1_feedforward_nm"])
			)
			and _close(
				float(zero_tangent["joint_2_feedforward_nm"]),
				float(vertical["mapping"]["joint_2_feedforward_nm"])
			)
		),
		"zero-tangent result exactly preserves the accepted vertical-only map"
	)
	_check(
		(
			String(mapping["request_sha256"]).begins_with("sha256:")
			and not bool(mapping["commanded_force_is_measured_contact_load"])
			and not bool(mapping["per_foot_measurement_established"])
		),
		"digest and measurement non-claims travel with every mapping"
	)

	var missing := request.duplicate(true)
	missing.erase("normal_force_n")
	_check(
		(
			String(SagittalMapScript.map(missing).get("failure_code", ""))
			== "SAGITTAL_FORCE_MAP_FIELD_SET_MISMATCH"
		),
		"missing unilateral normal authority fails closed"
	)
	var extra := request.duplicate(true)
	extra["hidden_assist"] = true
	_check(
		(
			String(SagittalMapScript.map(extra).get("failure_code", ""))
			== "SAGITTAL_FORCE_MAP_FIELD_SET_MISMATCH"
		),
		"extra hidden field fails closed"
	)
	var wrong_schema := request.duplicate(true)
	wrong_schema["schema_version"] = "sagittal_contact_force_map_request_v2"
	_check(
		(
			String(SagittalMapScript.map(wrong_schema).get("failure_code", ""))
			== "SAGITTAL_FORCE_MAP_SCHEMA_UNSUPPORTED"
		),
		"unrecognized schema fails closed"
	)
	var nonfinite := request.duplicate(true)
	nonfinite["tangent_force_n"] = NAN
	_check(
		String(SagittalMapScript.map(nonfinite).get("failure_code", "")).begins_with(
			"SAGITTAL_FORCE_MAP_NONFINITE_OR_NONNUMERIC:"
		),
		"nonfinite tangent force fails closed"
	)
	var nonnumeric := request.duplicate(true)
	nonnumeric["normal_force_n"] = "20"
	_check(
		String(SagittalMapScript.map(nonnumeric).get("failure_code", "")).begins_with(
			"SAGITTAL_FORCE_MAP_NONFINITE_OR_NONNUMERIC:"
		),
		"numeric-looking string fails closed"
	)
	var negative_normal := request.duplicate(true)
	negative_normal["normal_force_n"] = -0.01
	_check(
		(
			String(SagittalMapScript.map(negative_normal).get("failure_code", ""))
			== "SAGITTAL_FORCE_MAP_UNILATERAL_NORMAL_INVALID"
		),
		"negative normal command fails the unilateral boundary"
	)
	var zero_length := request.duplicate(true)
	zero_length["link_2_length_m"] = 0.0
	_check(
		String(SagittalMapScript.map(zero_length).get("failure_code", "")).begins_with(
			"SAGITTAL_FORCE_MAP_POSITIVE_VALUE_INVALID:"
		),
		"degenerate linkage fails closed"
	)

	var tangent_wrench: Dictionary = body_wrench["wrench"].duplicate(true)
	tangent_wrench["force_world_n"] = [1.0, normal, 0.0]
	var legacy_rejection := (
		VerticalMapScript
		. map(
			{
				"schema_version": "two_link_force_map_request_v1",
				"joint_1_angle_rad": q1,
				"joint_2_angle_rad": q2,
				"link_1_length_m": l1,
				"link_2_length_m": l2,
				"carriage_mass_kg": request["carriage_mass_kg"],
				"link_1_mass_kg": request["link_1_mass_kg"],
				"link_2_mass_kg": request["link_2_mass_kg"],
				"gravity_m_s2": request["gravity_m_s2"],
				"wrench": tangent_wrench,
			}
		)
	)
	_check(
		String(legacy_rejection.get("failure_code", "")) == "FORCE_MAP_V1_VERTICAL_FORCE_ONLY",
		"accepted vertical-only mapper remains strict and unmodified"
	)
	_finish()


static func _request() -> Dictionary:
	return {
		"schema_version": "sagittal_contact_force_map_request_v1",
		"joint_1_angle_rad": 0.62,
		"joint_2_angle_rad": -1.17,
		"link_1_length_m": 0.40,
		"link_2_length_m": 0.35,
		"carriage_mass_kg": 3.0,
		"link_1_mass_kg": 0.25,
		"link_2_mass_kg": 0.25,
		"gravity_m_s2": 9.8,
		"tangent_force_n": 5.0,
		"normal_force_n": 24.0,
	}


static func _endpoint(q1: float, q2: float, l1: float, l2: float) -> Vector2:
	return Vector2(l1 * sin(q1) + l2 * sin(q1 + q2), -l1 * cos(q1) - l2 * cos(q1 + q2))


static func _close(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= 1.0e-9


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
