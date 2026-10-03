extends SceneTree

## Zero-world L3 validation against the exact consumed L2 retained trace.
##
## The historical cell remains invalid and is never re-evaluated as behavior
## evidence. This script exercises only the prospective representation
## validators over retained JSON numbers. It does not construct a model or
## world, insert a scene node, read native state, or step a solver.

const RecoveryScript := preload("res://scripts/lab/gait/qsdk_r10b_bounded_upright_push_recovery.gd")
const ExportedScalarValidationScript := preload(
	"res://sdk/adapters/godot/gdscript/exported_scalar_validation_v1.gd"
)

const CELL_MARKER := "QSDK_R10B_PHYSICAL_CELL "
const PASS_MARKER := "QSDK_R10B_L3_RETAINED_TRACE_VALIDATION "
const EXPECTED_CELL_ID := "baseline_s50300"
const EXPECTED_ROW_COUNT := 2640
const CONSUMED_L2_ROW_SCHEMA := "sporespore_qsdk_r10b_bounded_upright_push_recovery_trace_row_v2"


func _initialize() -> void:
	var result := _run()
	print(PASS_MARKER, JSON.stringify(result, "", true, true))
	quit(0 if bool(result.get("ok", false)) else 1)


func _run() -> Dictionary:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		return _failure("QSDK_R10B_L3_RETAINED_TRACE_ARGUMENT_INVALID")
	var handle := FileAccess.open(String(arguments[0]), FileAccess.READ)
	if handle == null:
		return _failure("QSDK_R10B_L3_RETAINED_TRACE_UNREADABLE")
	var raw := handle.get_as_text()
	handle.close()
	var marker_offset := raw.find(CELL_MARKER)
	if marker_offset < 0 or raw.find(CELL_MARKER, marker_offset + CELL_MARKER.length()) >= 0:
		return _failure("QSDK_R10B_L3_RETAINED_TRACE_MARKER_COUNT_INVALID")
	var payload_start := marker_offset + CELL_MARKER.length()
	var payload_end := raw.find("\n", payload_start)
	if payload_end < 0:
		payload_end = raw.length()
	var parsed: Variant = JSON.parse_string(raw.substr(payload_start, payload_end - payload_start))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _failure("QSDK_R10B_L3_RETAINED_TRACE_MARKER_JSON_INVALID")
	var cell: Dictionary = parsed
	var evaluation_value: Variant = cell.get("evaluation", null)
	var trace_value: Variant = cell.get("sdk_physical_trace", null)
	if typeof(evaluation_value) != TYPE_DICTIONARY or typeof(trace_value) != TYPE_DICTIONARY:
		return _failure("QSDK_R10B_L3_RETAINED_TRACE_CELL_SHAPE_INVALID")
	var evaluation: Dictionary = evaluation_value
	var trace: Dictionary = trace_value
	var rows_value: Variant = trace.get("rows", null)
	if typeof(rows_value) != TYPE_ARRAY:
		return _failure("QSDK_R10B_L3_RETAINED_TRACE_ROWS_INVALID")
	var rows: Array = rows_value
	if rows.size() != EXPECTED_ROW_COUNT:
		return _failure("QSDK_R10B_L3_RETAINED_TRACE_ROW_COUNT_INVALID")

	var projection_receipt_acceptance_count := 0
	var exported_axis_acceptance_count := 0
	var maximum_projection_receipt_absolute_delta := 0.0
	var maximum_projection_receipt_allowance := 0.0
	var maximum_exported_axis_norm_delta := 0.0
	var first_forward: Array = []
	var first_lateral: Array = []
	var task_frame_exact_change_count := 0
	for index in range(rows.size()):
		if typeof(rows[index]) != TYPE_DICTIONARY:
			return _failure("QSDK_R10B_L3_RETAINED_TRACE_ROW_NOT_OBJECT")
		var row: Dictionary = rows[index]
		if (
			String(row.get("schema_version", "")) != CONSUMED_L2_ROW_SCHEMA
			or String(row.get("cell_id", "")) != EXPECTED_CELL_ID
			or int(row.get("semantic_step", -1)) != index
		):
			return _failure("QSDK_R10B_L3_RETAINED_TRACE_ROW_IDENTITY_INVALID")
		var orientation_validation := (
			RecoveryScript
			. validate_trace_orientation_projection(
				row.get("torso_orientation_xyzw", null),
				row.get("torso_orientation_projection", null),
			)
		)
		if not bool(orientation_validation.get("ok", false)):
			return _failure(
				"QSDK_R10B_L3_RETAINED_TRACE_PROJECTION_REFUSED",
				{"row_index": index, "validation": orientation_validation},
			)
		projection_receipt_acceptance_count += 1
		maximum_projection_receipt_absolute_delta = maxf(
			maximum_projection_receipt_absolute_delta,
			float(orientation_validation["projection_receipt_maximum_absolute_delta"]),
		)
		maximum_projection_receipt_allowance = maxf(
			maximum_projection_receipt_allowance,
			float(orientation_validation["projection_receipt_maximum_representation_allowance"]),
		)

		var forward := ExportedScalarValidationScript.finite_components_v1(
			row.get("task_frame_forward_axis_world_unit", null), 3
		)
		var lateral := ExportedScalarValidationScript.finite_components_v1(
			row.get("task_frame_lateral_axis_world_unit", null), 3
		)
		if forward.size() != 3 or lateral.size() != 3:
			return _failure("QSDK_R10B_L3_RETAINED_TRACE_AXIS_SHAPE_INVALID")
		var forward_norm_delta := ExportedScalarValidationScript.norm_delta_v1(forward)
		var lateral_norm_delta := ExportedScalarValidationScript.norm_delta_v1(lateral)
		var dot_absolute := ExportedScalarValidationScript.dot_absolute_v1(forward, lateral)
		if (
			forward_norm_delta > RecoveryScript.VECTOR_TOLERANCE
			or lateral_norm_delta > RecoveryScript.VECTOR_TOLERANCE
			or dot_absolute > RecoveryScript.VECTOR_TOLERANCE
		):
			return _failure(
				"QSDK_R10B_L3_RETAINED_TRACE_AXIS_REFUSED",
				{
					"row_index": index,
					"forward_norm_delta": forward_norm_delta,
					"lateral_norm_delta": lateral_norm_delta,
					"dot_absolute": dot_absolute,
				},
			)
		exported_axis_acceptance_count += 1
		maximum_exported_axis_norm_delta = maxf(
			maximum_exported_axis_norm_delta,
			maxf(forward_norm_delta, lateral_norm_delta),
		)
		if index == 0:
			first_forward = forward.duplicate()
			first_lateral = lateral.duplicate()
		elif forward != first_forward or lateral != first_lateral:
			task_frame_exact_change_count += 1

	var full_trace_reclassification := RecoveryScript._validate_trace_rows(rows, EXPECTED_CELL_ID)
	var historical_cell_remains_invalid := (
		typeof(cell.get("evidence_valid")) == TYPE_BOOL
		and not bool(cell.get("evidence_valid", true))
		and typeof(cell.get("outcome_complete")) == TYPE_BOOL
		and not bool(cell.get("outcome_complete", true))
		and typeof(cell.get("behavior_passed")) == TYPE_BOOL
		and not bool(cell.get("behavior_passed", true))
		and not bool(evaluation.get("ok", true))
		and (String(evaluation.get("failure_code", "")) == "QSDK_R10B_TRACE_ROW_KINEMATICS_INVALID")
		and not bool(full_trace_reclassification.get("ok", true))
		and (
			String(full_trace_reclassification.get("failure_code", ""))
			== "QSDK_R10B_TRACE_ROW_HEADER_INVALID"
		)
	)
	var ok := (
		projection_receipt_acceptance_count == EXPECTED_ROW_COUNT
		and exported_axis_acceptance_count == EXPECTED_ROW_COUNT
		and task_frame_exact_change_count == 0
		and maximum_projection_receipt_absolute_delta <= maximum_projection_receipt_allowance
		and maximum_exported_axis_norm_delta <= RecoveryScript.VECTOR_TOLERANCE
		and historical_cell_remains_invalid
		and root.get_child_count() == 0
	)
	return {
		"schema_version": "sporespore_qsdk_r10b_l3_retained_trace_validation_v1",
		"gate_id": "QSDK-R10B",
		"repair_id": "QSDK-R10B-L3",
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R10B_L3_RETAINED_TRACE_VALIDATION_FAILED",
		"retained_cell_id": String(cell.get("cell_id", "")),
		"retained_l2_trace_row_count": rows.size(),
		"projection_receipt_acceptance_count": projection_receipt_acceptance_count,
		"exported_axis_acceptance_count": exported_axis_acceptance_count,
		"maximum_projection_receipt_absolute_delta": maximum_projection_receipt_absolute_delta,
		"maximum_projection_receipt_allowance": maximum_projection_receipt_allowance,
		"maximum_exported_axis_norm_delta": maximum_exported_axis_norm_delta,
		"task_frame_exact_change_count": task_frame_exact_change_count,
		"historical_full_trace_reclassification_refusal_count":
		int(not bool(full_trace_reclassification.get("ok", true))),
		"historical_full_trace_reclassification_failure_code":
		String(full_trace_reclassification.get("failure_code", "")),
		"historical_cell_remains_invalid": historical_cell_remains_invalid,
		"behavior_reclassification_count": 0,
		"scene_tree_child_count": root.get_child_count(),
		"scene_tree_insertion_count": root.get_child_count(),
		"locomotion_outcome_exposure_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10b_l3_retained_trace_validation_v1",
		"gate_id": "QSDK-R10B",
		"repair_id": "QSDK-R10B-L3",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"behavior_reclassification_count": 0,
		"scene_tree_child_count": root.get_child_count(),
		"scene_tree_insertion_count": root.get_child_count(),
		"locomotion_outcome_exposure_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
