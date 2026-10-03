extends SceneTree

## Zero-world diagnosis of the consumed QSDK-R10B-L2 baseline trace.
##
## This script reads only the retained worker stdout marker and replays the
## trace validators over serialized rows. It never constructs a model or
## physics world, inserts a scene node, reads native state, or steps a solver.

const RecoveryScript := preload("res://scripts/lab/gait/qsdk_r10b_bounded_upright_push_recovery.gd")
const ProjectionScript := preload(
	"res://sdk/adapters/godot/gdscript/quaternion_scalar_projection_v1.gd"
)

const CELL_MARKER := "QSDK_R10B_PHYSICAL_CELL "
const PASS_MARKER := "QSDK_R10B_L2_RETAINED_TRACE_DIAGNOSIS "
const EXPECTED_CELL_ID := "baseline_s50300"
const EXPECTED_TRACE_ROW_COUNT := 2640
const TRACE_ROW_SCHEMA := "sporespore_qsdk_r10b_bounded_upright_push_recovery_trace_row_v2"
const TRACE_SAMPLING_PHASE := "post_physics_for_applied_semantic_step"
const PUSH_MARKER_STEP := 540
const EXPECTED_LIMB_ORDER := ["front_left", "front_right", "rear_left", "rear_right"]
const VECTOR_TOLERANCE := 1.0e-12
const QUATERNION_NORM_TOLERANCE := 1.0e-9
const RECEIPT_STATIC_FIELDS := [
	"schema_version",
	"ok",
	"support_status",
	"refusal_reason",
	"projection_method_id",
	"qualified_precedent_gate_id",
	"qualified_precedent_contract_sha256",
	"reconstructed_component_index",
	"core_norm_squared_tolerance",
	"within_core_unit_contract",
	"model_construction_count",
	"world_attempt_count",
	"world_build_count",
	"native_readback_count",
	"solver_step_count",
	"physics_state_modified",
	"physical_acceptance_authority",
	"release_authority",
]


func _initialize() -> void:
	var result := _run()
	print(PASS_MARKER, JSON.stringify(result, "", true, true))
	quit(0 if bool(result.get("ok", false)) else 1)


func _run() -> Dictionary:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		return _failure("QSDK_R10B_L2_DIAGNOSIS_ARGUMENT_INVALID")
	var stdout_path := String(arguments[0])
	var handle := FileAccess.open(stdout_path, FileAccess.READ)
	if handle == null:
		return _failure("QSDK_R10B_L2_DIAGNOSIS_STDOUT_UNREADABLE")
	var raw := handle.get_as_text()
	handle.close()
	var marker_offset := raw.find(CELL_MARKER)
	if marker_offset < 0 or raw.find(CELL_MARKER, marker_offset + CELL_MARKER.length()) >= 0:
		return _failure("QSDK_R10B_L2_DIAGNOSIS_MARKER_COUNT_INVALID")
	var payload_start := marker_offset + CELL_MARKER.length()
	var payload_end := raw.find("\n", payload_start)
	if payload_end < 0:
		payload_end = raw.length()
	var parsed: Variant = JSON.parse_string(raw.substr(payload_start, payload_end - payload_start))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _failure("QSDK_R10B_L2_DIAGNOSIS_MARKER_JSON_INVALID")
	var cell: Dictionary = parsed
	var trace_value: Variant = cell.get("sdk_physical_trace", null)
	if typeof(trace_value) != TYPE_DICTIONARY:
		return _failure("QSDK_R10B_L2_DIAGNOSIS_TRACE_INVALID")
	var rows_value: Variant = (trace_value as Dictionary).get("rows", null)
	if typeof(rows_value) != TYPE_ARRAY:
		return _failure("QSDK_R10B_L2_DIAGNOSIS_ROWS_INVALID")
	var rows: Array = rows_value

	var row_not_object_count := 0
	var row_header_failure_count := 0
	var vector_shape_failure_count := 0
	var nonfinite_kinematics_count := 0
	var negative_tilt_count := 0
	var task_axis_unit_failure_count := 0
	var task_axis_exported_scalar_unit_failure_count := 0
	var task_axis_orthogonality_failure_count := 0
	var task_axis_exported_scalar_orthogonality_failure_count := 0
	var task_frame_approximate_change_count := 0
	var task_frame_exact_change_count := 0
	var contact_object_failure_count := 0
	var contact_value_failure_count := 0
	var orientation_validation_failure_count := 0
	var projection_receipt_not_object_count := 0
	var projection_receipt_key_set_failure_count := 0
	var projection_receipt_static_field_failure_count := 0
	var projection_receipt_exact_failure_count := 0
	var projection_receipt_numeric_recomputation_failure_count := 0
	var projection_receipt_dictionary_only_equality_failure_count := 0
	var row_orientation_projection_link_failure_count := 0
	var source_orientation_invalid_count := 0
	var source_orientation_length_contract_failure_count := 0
	var projected_orientation_invalid_count := 0
	var projected_orientation_length_contract_failure_count := 0
	var maximum_source_orientation_norm_delta := 0.0
	var maximum_projected_orientation_norm_delta := 0.0
	var maximum_task_axis_host_norm_delta := 0.0
	var maximum_task_axis_exported_scalar_norm_delta := 0.0
	var maximum_task_axis_host_dot_absolute := 0.0
	var maximum_task_axis_exported_scalar_dot_absolute := 0.0
	var receipt_field_mismatch_counts: Dictionary = {}
	var first_orientation_failure: Dictionary = {}
	var first_receipt_difference: Dictionary = {}
	var maximum_receipt_numeric_difference: Dictionary = {}
	var first_task_axis_host_unit_failure: Dictionary = {}
	var first_forward: Variant = null
	var first_lateral: Variant = null

	for index in range(rows.size()):
		if typeof(rows[index]) != TYPE_DICTIONARY:
			row_not_object_count += 1
			continue
		var row: Dictionary = rows[index]
		if not _header_matches(row, index):
			row_header_failure_count += 1

		var position := _numeric_array(row.get("torso_position_world_m", null), 3)
		var linear_velocity := _numeric_array(row.get("torso_linear_velocity_world_m_s", null), 3)
		var angular_velocity := _numeric_array(
			row.get("torso_angular_velocity_world_rad_s", null), 3
		)
		var forward := _numeric_array(row.get("task_frame_forward_axis_world_unit", null), 3)
		var lateral := _numeric_array(row.get("task_frame_lateral_axis_world_unit", null), 3)
		var tilt_value: Variant = row.get("torso_tilt_rad", null)
		var vectors_shaped := (
			position.size() == 3
			and linear_velocity.size() == 3
			and angular_velocity.size() == 3
			and forward.size() == 3
			and lateral.size() == 3
			and typeof(tilt_value) in [TYPE_FLOAT, TYPE_INT]
		)
		if not vectors_shaped:
			vector_shape_failure_count += 1
		else:
			var tilt := float(tilt_value)
			if not (
				_array_all_finite(position)
				and _array_all_finite(linear_velocity)
				and _array_all_finite(angular_velocity)
				and _array_all_finite(forward)
				and _array_all_finite(lateral)
				and is_finite(tilt)
			):
				nonfinite_kinematics_count += 1
			if is_finite(tilt) and tilt < 0.0:
				negative_tilt_count += 1
			var forward_vector := Vector3(float(forward[0]), float(forward[1]), float(forward[2]))
			var lateral_vector := Vector3(float(lateral[0]), float(lateral[1]), float(lateral[2]))
			var forward_host_norm_delta := absf(forward_vector.length() - 1.0)
			var lateral_host_norm_delta := absf(lateral_vector.length() - 1.0)
			var forward_scalar_norm_delta := _scalar_norm_delta(forward)
			var lateral_scalar_norm_delta := _scalar_norm_delta(lateral)
			var host_dot_absolute := absf(forward_vector.dot(lateral_vector))
			var scalar_dot_absolute := _scalar_dot_absolute(forward, lateral)
			maximum_task_axis_host_norm_delta = maxf(
				maximum_task_axis_host_norm_delta,
				maxf(forward_host_norm_delta, lateral_host_norm_delta),
			)
			maximum_task_axis_exported_scalar_norm_delta = maxf(
				maximum_task_axis_exported_scalar_norm_delta,
				maxf(forward_scalar_norm_delta, lateral_scalar_norm_delta),
			)
			maximum_task_axis_host_dot_absolute = maxf(
				maximum_task_axis_host_dot_absolute, host_dot_absolute
			)
			maximum_task_axis_exported_scalar_dot_absolute = maxf(
				maximum_task_axis_exported_scalar_dot_absolute, scalar_dot_absolute
			)
			if (
				forward_host_norm_delta > VECTOR_TOLERANCE
				or lateral_host_norm_delta > VECTOR_TOLERANCE
			):
				task_axis_unit_failure_count += 1
				if first_task_axis_host_unit_failure.is_empty():
					first_task_axis_host_unit_failure = {
						"row_index": index,
						"forward_axis": forward.duplicate(),
						"lateral_axis": lateral.duplicate(),
						"forward_host_norm_delta": forward_host_norm_delta,
						"lateral_host_norm_delta": lateral_host_norm_delta,
						"forward_exported_scalar_norm_delta": forward_scalar_norm_delta,
						"lateral_exported_scalar_norm_delta": lateral_scalar_norm_delta,
					}
			if (
				forward_scalar_norm_delta > VECTOR_TOLERANCE
				or lateral_scalar_norm_delta > VECTOR_TOLERANCE
			):
				task_axis_exported_scalar_unit_failure_count += 1
			if host_dot_absolute > VECTOR_TOLERANCE:
				task_axis_orthogonality_failure_count += 1
			if scalar_dot_absolute > VECTOR_TOLERANCE:
				task_axis_exported_scalar_orthogonality_failure_count += 1
			if first_forward == null:
				first_forward = forward.duplicate()
				first_lateral = lateral.duplicate()
			else:
				var first_forward_vector := Vector3(
					float(first_forward[0]), float(first_forward[1]), float(first_forward[2])
				)
				var first_lateral_vector := Vector3(
					float(first_lateral[0]), float(first_lateral[1]), float(first_lateral[2])
				)
				if (
					not forward_vector.is_equal_approx(first_forward_vector)
					or not lateral_vector.is_equal_approx(first_lateral_vector)
				):
					task_frame_approximate_change_count += 1
				if forward != first_forward or lateral != first_lateral:
					task_frame_exact_change_count += 1

		for contact_field in ["ordered_foot_contacts_before", "ordered_foot_contacts_after"]:
			var contacts_value: Variant = row.get(String(contact_field), null)
			if typeof(contacts_value) != TYPE_DICTIONARY:
				contact_object_failure_count += 1
			elif not _exact_boolean_limb_contacts(contacts_value as Dictionary):
				contact_value_failure_count += 1

		var orientation_value: Variant = row.get("torso_orientation_xyzw", null)
		var projection_value: Variant = row.get("torso_orientation_projection", null)
		var validation := (
			RecoveryScript
			. validate_trace_orientation_projection(
				orientation_value,
				projection_value,
			)
		)
		if not bool(validation.get("ok", false)):
			orientation_validation_failure_count += 1
			if first_orientation_failure.is_empty():
				first_orientation_failure = {
					"row_index": index,
					"validation": validation.duplicate(true),
				}

		if typeof(projection_value) != TYPE_DICTIONARY:
			projection_receipt_not_object_count += 1
			continue
		var actual: Dictionary = projection_value
		var expected := ProjectionScript.project_components_to_unit_scalar_v1(
			actual.get("source_orientation_xyzw", null)
		)
		if not bool(expected.get("ok", false)):
			source_orientation_invalid_count += 1
		var source_diagnostic := ProjectionScript.diagnose_orientation_xyzw_v1(
			actual.get("source_orientation_xyzw", null)
		)
		if not bool(source_diagnostic.get("ok", false)):
			source_orientation_invalid_count += 1
		else:
			var source_norm_delta := float(source_diagnostic.get("norm_delta", INF))
			maximum_source_orientation_norm_delta = maxf(
				maximum_source_orientation_norm_delta, source_norm_delta
			)
			if source_norm_delta > QUATERNION_NORM_TOLERANCE:
				source_orientation_length_contract_failure_count += 1

		var projected_diagnostic := ProjectionScript.diagnose_orientation_xyzw_v1(orientation_value)
		if not bool(projected_diagnostic.get("ok", false)):
			projected_orientation_invalid_count += 1
		else:
			var projected_norm_delta := float(projected_diagnostic.get("norm_delta", INF))
			maximum_projected_orientation_norm_delta = maxf(
				maximum_projected_orientation_norm_delta, projected_norm_delta
			)
			if projected_norm_delta > QUATERNION_NORM_TOLERANCE:
				projected_orientation_length_contract_failure_count += 1

		if actual.keys().size() != expected.keys().size() or not _same_key_set(actual, expected):
			projection_receipt_key_set_failure_count += 1
		if not _static_receipt_fields_match(actual, expected):
			projection_receipt_static_field_failure_count += 1
		if actual.get("orientation_xyzw", null) != orientation_value:
			row_orientation_projection_link_failure_count += 1
		if actual != expected:
			projection_receipt_exact_failure_count += 1
			var difference := _first_projection_receipt_difference(actual, expected)
			if first_receipt_difference.is_empty():
				first_receipt_difference = difference.duplicate(true)
				first_receipt_difference["row_index"] = index
			if _difference_is_numeric(difference):
				projection_receipt_numeric_recomputation_failure_count += 1
			else:
				projection_receipt_dictionary_only_equality_failure_count += 1
			_record_receipt_differences(
				actual,
				expected,
				index,
				receipt_field_mismatch_counts,
				maximum_receipt_numeric_difference,
			)

	var generic_validation := (
		RecoveryScript
		. _validate_trace_rows(
			rows,
			String(cell.get("cell_id", "")),
		)
	)
	var other_row_contract_failure_total := (
		row_not_object_count
		+ row_header_failure_count
		+ vector_shape_failure_count
		+ nonfinite_kinematics_count
		+ negative_tilt_count
		+ task_axis_orthogonality_failure_count
		+ task_axis_exported_scalar_unit_failure_count
		+ task_axis_exported_scalar_orthogonality_failure_count
		+ task_frame_approximate_change_count
		+ contact_object_failure_count
		+ contact_value_failure_count
	)
	var diagnosis_established := (
		rows.size() == EXPECTED_TRACE_ROW_COUNT
		and String(cell.get("cell_id", "")) == EXPECTED_CELL_ID
		and not bool(generic_validation.get("ok", true))
		and (
			String(generic_validation.get("failure_code", ""))
			== "QSDK_R10B_TRACE_ROW_KINEMATICS_INVALID"
		)
		and other_row_contract_failure_total == 0
		and task_axis_unit_failure_count == EXPECTED_TRACE_ROW_COUNT
		and task_frame_exact_change_count == 0
		and orientation_validation_failure_count == EXPECTED_TRACE_ROW_COUNT
		and projection_receipt_not_object_count == 0
		and projection_receipt_key_set_failure_count == 0
		and projection_receipt_static_field_failure_count == 0
		and projection_receipt_exact_failure_count == EXPECTED_TRACE_ROW_COUNT
		and projection_receipt_numeric_recomputation_failure_count > 0
		and (
			(
				projection_receipt_numeric_recomputation_failure_count
				+ projection_receipt_dictionary_only_equality_failure_count
			)
			== EXPECTED_TRACE_ROW_COUNT
		)
		and row_orientation_projection_link_failure_count == 0
		and source_orientation_invalid_count == 0
		and projected_orientation_invalid_count == 0
		and source_orientation_length_contract_failure_count > 0
		and projected_orientation_length_contract_failure_count == 0
		and maximum_projected_orientation_norm_delta <= QUATERNION_NORM_TOLERANCE
		and root.get_child_count() == 0
	)
	return {
		"schema_version": "sporespore_qsdk_r10b_l2_retained_trace_diagnosis_v1",
		"gate_id": "QSDK-R10B",
		"repair_id": "QSDK-R10B-L2",
		"ok": diagnosis_established,
		"failure_code": "" if diagnosis_established else "QSDK_R10B_L2_DIAGNOSIS_NOT_ESTABLISHED",
		"retained_cell_id": String(cell.get("cell_id", "")),
		"retained_trace_row_count": rows.size(),
		"generic_trace_validation_failure_code": String(generic_validation.get("failure_code", "")),
		"row_not_object_count": row_not_object_count,
		"row_header_failure_count": row_header_failure_count,
		"vector_shape_failure_count": vector_shape_failure_count,
		"nonfinite_kinematics_count": nonfinite_kinematics_count,
		"negative_tilt_count": negative_tilt_count,
		"task_axis_unit_failure_count": task_axis_unit_failure_count,
		"task_axis_exported_scalar_unit_failure_count":
		task_axis_exported_scalar_unit_failure_count,
		"task_axis_orthogonality_failure_count": task_axis_orthogonality_failure_count,
		"task_axis_exported_scalar_orthogonality_failure_count":
		task_axis_exported_scalar_orthogonality_failure_count,
		"task_frame_approximate_change_count": task_frame_approximate_change_count,
		"task_frame_exact_change_count": task_frame_exact_change_count,
		"contact_object_failure_count": contact_object_failure_count,
		"contact_value_failure_count": contact_value_failure_count,
		"other_row_contract_failure_total": other_row_contract_failure_total,
		"orientation_validation_failure_count": orientation_validation_failure_count,
		"projection_receipt_not_object_count": projection_receipt_not_object_count,
		"projection_receipt_key_set_failure_count": projection_receipt_key_set_failure_count,
		"projection_receipt_static_field_failure_count":
		projection_receipt_static_field_failure_count,
		"projection_receipt_exact_failure_count": projection_receipt_exact_failure_count,
		"projection_receipt_numeric_recomputation_failure_count":
		projection_receipt_numeric_recomputation_failure_count,
		"projection_receipt_dictionary_only_equality_failure_count":
		projection_receipt_dictionary_only_equality_failure_count,
		"row_orientation_projection_link_failure_count":
		row_orientation_projection_link_failure_count,
		"source_orientation_invalid_count": source_orientation_invalid_count,
		"source_orientation_length_contract_failure_count":
		source_orientation_length_contract_failure_count,
		"projected_orientation_invalid_count": projected_orientation_invalid_count,
		"projected_orientation_length_contract_failure_count":
		projected_orientation_length_contract_failure_count,
		"maximum_source_orientation_norm_delta": maximum_source_orientation_norm_delta,
		"maximum_projected_orientation_norm_delta": maximum_projected_orientation_norm_delta,
		"maximum_task_axis_host_norm_delta": maximum_task_axis_host_norm_delta,
		"maximum_task_axis_exported_scalar_norm_delta":
		maximum_task_axis_exported_scalar_norm_delta,
		"maximum_task_axis_host_dot_absolute": maximum_task_axis_host_dot_absolute,
		"maximum_task_axis_exported_scalar_dot_absolute":
		maximum_task_axis_exported_scalar_dot_absolute,
		"first_task_axis_host_unit_failure": first_task_axis_host_unit_failure,
		"projection_receipt_field_mismatch_counts": receipt_field_mismatch_counts,
		"first_orientation_failure": first_orientation_failure,
		"first_projection_receipt_difference": first_receipt_difference,
		"maximum_projection_receipt_numeric_difference": maximum_receipt_numeric_difference,
		"scene_tree_child_count": root.get_child_count(),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


func _header_matches(row: Dictionary, index: int) -> bool:
	return (
		String(row.get("schema_version", "")) == TRACE_ROW_SCHEMA
		and String(row.get("cell_id", "")) == EXPECTED_CELL_ID
		and int(row.get("semantic_step", -1)) == index
		and String(row.get("sampling_phase", "")) == TRACE_SAMPLING_PHASE
		and int(row.get("push_marker_semantic_step", -1)) == PUSH_MARKER_STEP
		and int(row.get("validated_portable_command_count", -1)) == 8
		and int(row.get("native_actuation_application_count", -1)) == 8
		and bool(row.get("post_physics_observation_complete", false))
		and not bool(row.get("observer_physics_state_modified", true))
		and typeof(row.get("torso_ground_contact")) == TYPE_BOOL
	)


func _numeric_array(value: Variant, expected_size: int) -> Array:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != expected_size:
		return []
	var result: Array = []
	for component in value as Array:
		if typeof(component) not in [TYPE_FLOAT, TYPE_INT]:
			return []
		result.append(float(component))
	return result


func _array_all_finite(values: Array) -> bool:
	for value in values:
		if not is_finite(float(value)):
			return false
	return true


func _scalar_norm_delta(values: Array) -> float:
	var norm_squared := 0.0
	for value in values:
		norm_squared += float(value) * float(value)
	return absf(sqrt(norm_squared) - 1.0)


func _scalar_dot_absolute(left: Array, right: Array) -> float:
	var dot := 0.0
	for index in range(left.size()):
		dot += float(left[index]) * float(right[index])
	return absf(dot)


func _exact_boolean_limb_contacts(contacts: Dictionary) -> bool:
	if contacts.size() != EXPECTED_LIMB_ORDER.size():
		return false
	for limb_id_value in EXPECTED_LIMB_ORDER:
		var limb_id := String(limb_id_value)
		if not contacts.has(limb_id) or typeof(contacts[limb_id]) != TYPE_BOOL:
			return false
	return true


func _same_key_set(actual: Dictionary, expected: Dictionary) -> bool:
	for key in expected:
		if not actual.has(key):
			return false
	for key in actual:
		if not expected.has(key):
			return false
	return true


func _static_receipt_fields_match(actual: Dictionary, expected: Dictionary) -> bool:
	for field_value in RECEIPT_STATIC_FIELDS:
		var field := String(field_value)
		if not actual.has(field) or actual[field] != expected.get(field, null):
			return false
	return true


func _first_projection_receipt_difference(actual: Dictionary, expected: Dictionary) -> Dictionary:
	if actual.keys().size() != expected.keys().size():
		return {
			"kind": "key_count_mismatch",
			"actual_key_count": actual.keys().size(),
			"expected_key_count": expected.keys().size(),
		}
	for key_value in expected.keys():
		var key := String(key_value)
		if not actual.has(key):
			return {"kind": "missing_key", "key": key}
		if actual[key] != expected[key]:
			return _value_difference(key, actual[key], expected[key])
	if actual != expected:
		return {"kind": "dictionary_equality_mismatch_without_field_mismatch"}
	return {"kind": "none"}


func _value_difference(key: String, actual: Variant, expected: Variant) -> Dictionary:
	if typeof(actual) == TYPE_ARRAY and typeof(expected) == TYPE_ARRAY:
		var actual_array: Array = actual
		var expected_array: Array = expected
		if actual_array.size() != expected_array.size():
			return {
				"kind": "array_size_mismatch",
				"key": key,
				"actual_size": actual_array.size(),
				"expected_size": expected_array.size(),
			}
		for component_index in range(actual_array.size()):
			if actual_array[component_index] != expected_array[component_index]:
				var result := {
					"kind": "array_component_mismatch",
					"key": key,
					"component_index": component_index,
					"actual_type": typeof(actual_array[component_index]),
					"expected_type": typeof(expected_array[component_index]),
					"actual": actual_array[component_index],
					"expected": expected_array[component_index],
				}
				if (
					typeof(actual_array[component_index]) in [TYPE_FLOAT, TYPE_INT]
					and typeof(expected_array[component_index]) in [TYPE_FLOAT, TYPE_INT]
				):
					result["absolute_delta"] = absf(
						(
							float(actual_array[component_index])
							- float(expected_array[component_index])
						)
					)
				return result
	var result := {
		"kind": "value_mismatch",
		"key": key,
		"actual_type": typeof(actual),
		"expected_type": typeof(expected),
		"actual": actual,
		"expected": expected,
	}
	if typeof(actual) in [TYPE_FLOAT, TYPE_INT] and typeof(expected) in [TYPE_FLOAT, TYPE_INT]:
		result["absolute_delta"] = absf(float(actual) - float(expected))
	return result


func _difference_is_numeric(difference: Dictionary) -> bool:
	return difference.has("absolute_delta") and is_finite(float(difference["absolute_delta"]))


func _record_receipt_differences(
	actual: Dictionary,
	expected: Dictionary,
	row_index: int,
	field_counts: Dictionary,
	maximum_numeric: Dictionary,
) -> void:
	for key_value in expected.keys():
		var key := String(key_value)
		if not actual.has(key) or actual[key] == expected[key]:
			continue
		field_counts[key] = int(field_counts.get(key, 0)) + 1
		var difference := _value_difference(key, actual[key], expected[key])
		if not _difference_is_numeric(difference):
			continue
		var absolute_delta := float(difference["absolute_delta"])
		if maximum_numeric.is_empty() or absolute_delta > float(maximum_numeric["absolute_delta"]):
			maximum_numeric.clear()
			maximum_numeric.merge(difference, true)
			maximum_numeric["row_index"] = row_index


func _failure(code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10b_l2_retained_trace_diagnosis_v1",
		"gate_id": "QSDK-R10B",
		"repair_id": "QSDK-R10B-L2",
		"ok": false,
		"failure_code": code,
		"scene_tree_child_count": root.get_child_count(),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
