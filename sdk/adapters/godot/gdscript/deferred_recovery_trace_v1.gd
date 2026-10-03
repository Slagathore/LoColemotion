class_name QsdkDeferredRecoveryTraceV1
extends RefCounted
# gdlint: disable=max-file-lines
# gdlint: disable=max-line-length
# gdlint: disable=function-arguments-number

## Forward-versioned QSDK-R10E recovery trace observer.
##
## The live solver interval writes only primitive scalar values into storage
## allocated before the first solver step. Rich row dictionaries, deep copies,
## JSON/hashes, and quaternion projection receipts are deliberately deferred
## until the caller declares that the final solver step has completed.

const QuaternionScalarProjectionScript := preload(
	"res://sdk/adapters/godot/gdscript/quaternion_scalar_projection_v1.gd"
)

const TRACE_POLICY_ID := "qsdk_r10e_observer_minimized_upright_push_recovery_trace_v1"
const TRACE_ROW_SCHEMA := "sporespore_qsdk_r10e_observer_minimized_upright_push_recovery_trace_row_v1"
const INSTRUMENTATION_RECEIPT_SCHEMA := "sporespore_qsdk_r10e_deferred_recovery_trace_observer_instrumentation_v1"
const TRACE_SAMPLING_PHASE := "post_physics_for_applied_semantic_step"
const MINIMUM_CONTROLLER_STEP_COUNT := 2152
const MAXIMUM_CONTROLLER_STEP_COUNT := 2872
const PUSH_MARKER_SEMANTIC_STEP := 900
const LIMB_ORDER := ["front_left", "front_right", "rear_left", "rear_right"]
const VECTOR_COMPONENT_KEYS := ["x", "y", "z"]
const VECTOR_COMPONENT_COUNT := 3
const QUATERNION_COMPONENT_COUNT := 4


class CaptureBuffer:
	extends RefCounted
	var cell_id := ""
	var capacity := 0
	var declared_minimum_row_count := 0
	var push_marker_semantic_step := -1
	var captured_row_count := 0
	var pending_row_index := -1
	var failed := false
	var failure_code := ""
	var materialization_completed := false
	var constant_task_axes_initialized := false

	var semantic_steps := PackedInt32Array()
	var validated_portable_command_counts := PackedInt32Array()
	var native_actuation_application_counts := PackedInt32Array()
	var constant_task_axes_world_unit := PackedFloat64Array()
	var ordered_foot_contacts_before := PackedByteArray()
	var ordered_foot_contacts_after := PackedByteArray()
	var torso_positions_world_m := PackedFloat64Array()
	var raw_torso_orientations_xyzw := PackedFloat64Array()
	var torso_linear_velocities_world_m_s := PackedFloat64Array()
	var torso_angular_velocities_world_rad_s := PackedFloat64Array()
	var torso_tilts_rad := PackedFloat64Array()
	var torso_ground_contacts := PackedByteArray()

	# These counters are part of the empirical receipt. The four prohibited
	# live counters never increment anywhere in this module.
	var live_raw_before_capture_count := 0
	var live_raw_after_capture_count := 0
	var live_nested_row_materialization_count := 0
	var live_trace_row_deep_duplicate_count := 0
	var live_trace_json_or_hash_count := 0
	var live_quaternion_projection_receipt_count := 0
	var post_solver_materialized_row_count := 0
	var post_solver_projection_receipt_count := 0

	func _init(
		requested_cell_id: String,
		requested_capacity: int,
		requested_minimum_row_count: int,
		requested_push_marker_semantic_step: int,
	) -> void:
		cell_id = requested_cell_id
		capacity = requested_capacity
		declared_minimum_row_count = requested_minimum_row_count
		push_marker_semantic_step = requested_push_marker_semantic_step
		semantic_steps.resize(capacity)
		validated_portable_command_counts.resize(capacity)
		native_actuation_application_counts.resize(capacity)
		constant_task_axes_world_unit.resize(VECTOR_COMPONENT_COUNT * 2)
		ordered_foot_contacts_before.resize(capacity * LIMB_ORDER.size())
		ordered_foot_contacts_after.resize(capacity * LIMB_ORDER.size())
		torso_positions_world_m.resize(capacity * VECTOR_COMPONENT_COUNT)
		raw_torso_orientations_xyzw.resize(capacity * QUATERNION_COMPONENT_COUNT)
		torso_linear_velocities_world_m_s.resize(capacity * VECTOR_COMPONENT_COUNT)
		torso_angular_velocities_world_rad_s.resize(capacity * VECTOR_COMPONENT_COUNT)
		torso_tilts_rad.resize(capacity)
		torso_ground_contacts.resize(capacity)


static func prepare(trace_options: Dictionary) -> Dictionary:
	var expected_keys := [
		"cell_id",
		"enabled",
		"maximum_controller_step_count",
		"minimum_controller_step_count",
		"policy_id",
		"push_marker_semantic_step",
		"sampling_phase",
		"trace_row_schema_version",
	]
	if not _has_exact_keys(trace_options, expected_keys):
		return _failure("QSDK_R10E_DEFERRED_TRACE_OPTION_KEYS_INVALID")
	if (
		typeof(trace_options["cell_id"]) != TYPE_STRING
		or typeof(trace_options["enabled"]) != TYPE_BOOL
		or typeof(trace_options["maximum_controller_step_count"]) != TYPE_INT
		or typeof(trace_options["minimum_controller_step_count"]) != TYPE_INT
		or typeof(trace_options["policy_id"]) != TYPE_STRING
		or typeof(trace_options["push_marker_semantic_step"]) != TYPE_INT
		or typeof(trace_options["sampling_phase"]) != TYPE_STRING
		or typeof(trace_options["trace_row_schema_version"]) != TYPE_STRING
	):
		return _failure("QSDK_R10E_DEFERRED_TRACE_OPTION_TYPE_INVALID")
	if (
		String(trace_options["cell_id"]).is_empty()
		or not bool(trace_options["enabled"])
		or String(trace_options["policy_id"]) != TRACE_POLICY_ID
		or String(trace_options["trace_row_schema_version"]) != TRACE_ROW_SCHEMA
		or String(trace_options["sampling_phase"]) != TRACE_SAMPLING_PHASE
		or int(trace_options["minimum_controller_step_count"]) != MINIMUM_CONTROLLER_STEP_COUNT
		or int(trace_options["maximum_controller_step_count"]) != MAXIMUM_CONTROLLER_STEP_COUNT
		or int(trace_options["push_marker_semantic_step"]) != PUSH_MARKER_SEMANTIC_STEP
	):
		return _failure("QSDK_R10E_DEFERRED_TRACE_POLICY_RECEIPT_MISMATCH")
	var buffer := (
		CaptureBuffer
		. new(
			String(trace_options["cell_id"]),
			int(trace_options["maximum_controller_step_count"]),
			int(trace_options["minimum_controller_step_count"]),
			int(trace_options["push_marker_semantic_step"]),
		)
	)
	return {
		"ok": true,
		"failure_code": "",
		"buffer": buffer,
		"capture_buffer_preallocated": true,
		"capture_buffer_capacity": buffer.capacity,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func capture_before_solver_step(
	buffer: CaptureBuffer,
	sample_result: Dictionary,
	step_result: Dictionary,
	authority_application_result: Dictionary,
	semantic_step: int,
	ordered_foot_contacts_before: Dictionary,
) -> String:
	if buffer == null:
		return "QSDK_R10E_DEFERRED_TRACE_BUFFER_MISSING"
	if buffer.failed:
		return buffer.failure_code
	if buffer.materialization_completed:
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_CAPTURE_AFTER_MATERIALIZATION")
	if buffer.pending_row_index >= 0:
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_POST_CAPTURE_MISSING")
	if semantic_step != buffer.captured_row_count:
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_SEMANTIC_STEP_NONCONTIGUOUS")
	if semantic_step < 0 or semantic_step >= buffer.capacity:
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_CAPACITY_EXCEEDED")
	if (
		not bool(sample_result.get("ok", false))
		or not bool(step_result.get("ok", false))
		or not bool(authority_application_result.get("ok", false))
	):
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_UPSTREAM_INVALID")
	var request_value: Variant = sample_result.get("request", null)
	if typeof(request_value) != TYPE_DICTIONARY:
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_REQUEST_INVALID")
	var request: Dictionary = request_value
	var state_value: Variant = request.get("state", null)
	var command_value: Variant = request.get("command", null)
	if typeof(state_value) != TYPE_DICTIONARY or typeof(command_value) != TYPE_DICTIONARY:
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_REQUEST_FIELDS_INVALID")
	var state: Dictionary = state_value
	var command: Dictionary = command_value
	if (
		int(state.get("semantic_step", -1)) != semantic_step
		or int(command.get("valid_from_step", -1)) != semantic_step
		or int(command.get("valid_through_step", -1)) != semantic_step
		or int(step_result.get("semantic_step", -1)) != semantic_step
		or int(authority_application_result.get("semantic_step", -1)) != semantic_step
	):
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_STEP_MISMATCH")
	var native_output_value: Variant = step_result.get("native_output", null)
	if typeof(native_output_value) != TYPE_DICTIONARY:
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_NATIVE_OUTPUT_INVALID")
	var actuation_value: Variant = (native_output_value as Dictionary).get("actuation", null)
	if typeof(actuation_value) != TYPE_DICTIONARY:
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_ACTUATION_INVALID")
	var commands_value: Variant = (actuation_value as Dictionary).get("ordered_commands", null)
	var applied_command_count := int(authority_application_result.get("applied_command_count", -1))
	if (
		typeof(commands_value) != TYPE_ARRAY
		or (commands_value as Array).size() != 8
		or applied_command_count != 8
	):
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_APPLICATION_COUNT_INVALID")
	if not _exact_boolean_contacts(ordered_foot_contacts_before):
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_PRE_CONTACTS_INVALID")
	var task_frame_value: Variant = state.get("task_frame", null)
	if typeof(task_frame_value) != TYPE_DICTIONARY:
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_TASK_FRAME_INVALID")
	var task_frame: Dictionary = task_frame_value
	var forward_value: Variant = task_frame.get("forward_axis_world_unit", null)
	var lateral_value: Variant = task_frame.get("lateral_axis_world_unit", null)
	if not _capture_constant_task_axes(buffer, forward_value, lateral_value):
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_TASK_AXES_INVALID_OR_CHANGED")

	var row_index := buffer.captured_row_count
	buffer.semantic_steps[row_index] = semantic_step
	buffer.validated_portable_command_counts[row_index] = (commands_value as Array).size()
	buffer.native_actuation_application_counts[row_index] = applied_command_count
	_store_contacts(
		buffer.ordered_foot_contacts_before,
		row_index,
		ordered_foot_contacts_before,
	)
	buffer.pending_row_index = row_index
	buffer.live_raw_before_capture_count += 1
	return ""


static func capture_after_solver_step(
	buffer: CaptureBuffer,
	semantic_step: int,
	torso_position_world_m: Vector3,
	raw_torso_orientation: Quaternion,
	torso_linear_velocity_world_m_s: Vector3,
	torso_angular_velocity_world_rad_s: Vector3,
	torso_tilt_rad: float,
	torso_ground_contact: bool,
	ordered_foot_contacts_after: Dictionary,
) -> String:
	if buffer == null:
		return "QSDK_R10E_DEFERRED_TRACE_BUFFER_MISSING"
	if buffer.failed:
		return buffer.failure_code
	if buffer.materialization_completed:
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_CAPTURE_AFTER_MATERIALIZATION")
	var row_index := buffer.pending_row_index
	if row_index < 0 or row_index != buffer.captured_row_count:
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_PRE_CAPTURE_MISSING")
	if semantic_step != int(buffer.semantic_steps[row_index]):
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_POST_STEP_MISMATCH")
	if (
		not torso_position_world_m.is_finite()
		or not torso_linear_velocity_world_m_s.is_finite()
		or not torso_angular_velocity_world_rad_s.is_finite()
		or not is_finite(raw_torso_orientation.x)
		or not is_finite(raw_torso_orientation.y)
		or not is_finite(raw_torso_orientation.z)
		or not is_finite(raw_torso_orientation.w)
		or not is_finite(torso_tilt_rad)
		or torso_tilt_rad < 0.0
	):
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_POST_STATE_INVALID")
	if not _exact_boolean_contacts(ordered_foot_contacts_after):
		return _fail_buffer(buffer, "QSDK_R10E_DEFERRED_TRACE_POST_CONTACTS_INVALID")

	_store_vector3(buffer.torso_positions_world_m, row_index, torso_position_world_m)
	_store_quaternion(
		buffer.raw_torso_orientations_xyzw,
		row_index,
		raw_torso_orientation,
	)
	_store_vector3(
		buffer.torso_linear_velocities_world_m_s,
		row_index,
		torso_linear_velocity_world_m_s,
	)
	_store_vector3(
		buffer.torso_angular_velocities_world_rad_s,
		row_index,
		torso_angular_velocity_world_rad_s,
	)
	buffer.torso_tilts_rad[row_index] = torso_tilt_rad
	buffer.torso_ground_contacts[row_index] = 1 if torso_ground_contact else 0
	_store_contacts(
		buffer.ordered_foot_contacts_after,
		row_index,
		ordered_foot_contacts_after,
	)
	buffer.live_raw_after_capture_count += 1
	buffer.captured_row_count += 1
	buffer.pending_row_index = -1
	return ""


static func has_pending_after_capture(buffer: CaptureBuffer) -> bool:
	return buffer != null and not buffer.failed and buffer.pending_row_index >= 0


static func materialize_after_final_solver_step(
	buffer: CaptureBuffer,
	expected_sdk_step_count: int,
) -> Dictionary:
	if buffer == null:
		return _failure("QSDK_R10E_DEFERRED_TRACE_BUFFER_MISSING")
	if buffer.failed:
		return _failure(buffer.failure_code)
	if buffer.materialization_completed:
		return _failure("QSDK_R10E_DEFERRED_TRACE_ALREADY_MATERIALIZED")
	if buffer.pending_row_index >= 0:
		return _failure("QSDK_R10E_DEFERRED_TRACE_POST_CAPTURE_MISSING")
	if (
		expected_sdk_step_count < 0
		or expected_sdk_step_count != buffer.captured_row_count
		or expected_sdk_step_count > buffer.capacity
	):
		return _failure("QSDK_R10E_DEFERRED_TRACE_CAPTURE_COUNT_MISMATCH")
	var rows: Array[Dictionary] = []
	rows.resize(buffer.captured_row_count)
	for row_index in range(buffer.captured_row_count):
		var raw_orientation := _load_quaternion(
			buffer.raw_torso_orientations_xyzw,
			row_index,
		)
		var orientation_projection := (
			QuaternionScalarProjectionScript.project_quaternion_to_unit_scalar_v1(raw_orientation)
		)
		if not bool(orientation_projection.get("ok", false)):
			return _failure("QSDK_R10E_DEFERRED_TRACE_QUATERNION_PROJECTION_REFUSED")
		var orientation: Array = orientation_projection["orientation_xyzw"]
		rows[row_index] = {
			"schema_version": TRACE_ROW_SCHEMA,
			"cell_id": buffer.cell_id,
			"semantic_step": int(buffer.semantic_steps[row_index]),
			"sampling_phase": TRACE_SAMPLING_PHASE,
			"push_marker_semantic_step": buffer.push_marker_semantic_step,
			"task_frame_forward_axis_world_unit": _task_axis_array(buffer, 0),
			"task_frame_lateral_axis_world_unit": _task_axis_array(buffer, 1),
			"ordered_foot_contacts_before":
			_contacts_dictionary(
				buffer.ordered_foot_contacts_before,
				row_index,
			),
			"ordered_foot_contacts_after":
			_contacts_dictionary(
				buffer.ordered_foot_contacts_after,
				row_index,
			),
			"validated_portable_command_count":
			int(buffer.validated_portable_command_counts[row_index]),
			"native_actuation_application_count":
			int(buffer.native_actuation_application_counts[row_index]),
			"torso_position_world_m":
			_vector3_array(
				buffer.torso_positions_world_m,
				row_index,
			),
			"torso_orientation_xyzw": orientation.duplicate(),
			"torso_orientation_projection": orientation_projection.duplicate(true),
			"torso_linear_velocity_world_m_s":
			_vector3_array(
				buffer.torso_linear_velocities_world_m_s,
				row_index,
			),
			"torso_angular_velocity_world_rad_s":
			_vector3_array(
				buffer.torso_angular_velocities_world_rad_s,
				row_index,
			),
			"torso_tilt_rad": float(buffer.torso_tilts_rad[row_index]),
			"torso_ground_contact": bool(buffer.torso_ground_contacts[row_index]),
			"post_physics_observation_complete": true,
			"observer_physics_state_modified": false,
		}
		buffer.post_solver_materialized_row_count += 1
		buffer.post_solver_projection_receipt_count += 1
	buffer.materialization_completed = true
	var instrumentation_receipt := _instrumentation_receipt(buffer, rows.size())
	return {
		"ok": true,
		"failure_code": "",
		"rows": rows,
		"observer_instrumentation_receipt": instrumentation_receipt,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _instrumentation_receipt(buffer: CaptureBuffer, trace_row_count: int) -> Dictionary:
	return {
		"schema_version": INSTRUMENTATION_RECEIPT_SCHEMA,
		"trace_policy_id": TRACE_POLICY_ID,
		"trace_row_schema": TRACE_ROW_SCHEMA,
		"capture_buffer_preallocated": true,
		"capture_buffer_capacity": buffer.capacity,
		"captured_row_count": buffer.captured_row_count,
		"live_raw_before_capture_count": buffer.live_raw_before_capture_count,
		"live_raw_after_capture_count": buffer.live_raw_after_capture_count,
		"live_nested_row_materialization_count": buffer.live_nested_row_materialization_count,
		"live_trace_row_deep_duplicate_count": buffer.live_trace_row_deep_duplicate_count,
		"live_trace_json_or_hash_count": buffer.live_trace_json_or_hash_count,
		"live_quaternion_projection_receipt_count": buffer.live_quaternion_projection_receipt_count,
		"post_solver_materialized_row_count": buffer.post_solver_materialized_row_count,
		"post_solver_projection_receipt_count": buffer.post_solver_projection_receipt_count,
		"trace_row_count": trace_row_count,
		"captured_row_count_matches_trace_row_count": buffer.captured_row_count == trace_row_count,
		"post_solver_materialized_row_count_matches_trace_row_count":
		buffer.post_solver_materialized_row_count == trace_row_count,
		"post_solver_projection_receipt_count_matches_trace_row_count":
		buffer.post_solver_projection_receipt_count == trace_row_count,
		"materialization_after_final_solver_step_declared_by_caller": true,
		"additional_solver_step_during_materialization_count": 0,
		"downsampled_row_count": 0,
		"missing_measurement_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _capture_constant_task_axes(
	buffer: CaptureBuffer,
	forward_value: Variant,
	lateral_value: Variant,
) -> bool:
	if typeof(forward_value) != TYPE_DICTIONARY or typeof(lateral_value) != TYPE_DICTIONARY:
		return false
	var forward: Dictionary = forward_value
	var lateral: Dictionary = lateral_value
	if not _has_exact_keys(forward, VECTOR_COMPONENT_KEYS):
		return false
	if not _has_exact_keys(lateral, VECTOR_COMPONENT_KEYS):
		return false
	for component_index in range(VECTOR_COMPONENT_COUNT):
		var component_key := String(VECTOR_COMPONENT_KEYS[component_index])
		var forward_value_component: Variant = forward[component_key]
		var lateral_value_component: Variant = lateral[component_key]
		if (
			not _is_numeric_scalar(forward_value_component)
			or not _is_numeric_scalar(lateral_value_component)
			or not is_finite(float(forward_value_component))
			or not is_finite(float(lateral_value_component))
		):
			return false
		var forward_component := float(forward_value_component)
		var lateral_component := float(lateral_value_component)
		if buffer.constant_task_axes_initialized:
			if (
				forward_component != float(buffer.constant_task_axes_world_unit[component_index])
				or (
					lateral_component
					!= float(
						buffer.constant_task_axes_world_unit[
							VECTOR_COMPONENT_COUNT + component_index
						]
					)
				)
			):
				return false
		else:
			buffer.constant_task_axes_world_unit[component_index] = forward_component
			buffer.constant_task_axes_world_unit[VECTOR_COMPONENT_COUNT + component_index] = lateral_component
	buffer.constant_task_axes_initialized = true
	return true


static func _store_contacts(
	destination: PackedByteArray,
	row_index: int,
	contacts: Dictionary,
) -> void:
	var base_index := row_index * LIMB_ORDER.size()
	for limb_index in range(LIMB_ORDER.size()):
		destination[base_index + limb_index] = 1 if bool(contacts[LIMB_ORDER[limb_index]]) else 0


static func _store_vector3(destination: PackedFloat64Array, row_index: int, value: Vector3) -> void:
	var base_index := row_index * VECTOR_COMPONENT_COUNT
	destination[base_index] = value.x
	destination[base_index + 1] = value.y
	destination[base_index + 2] = value.z


static func _store_quaternion(
	destination: PackedFloat64Array,
	row_index: int,
	value: Quaternion,
) -> void:
	var base_index := row_index * QUATERNION_COMPONENT_COUNT
	destination[base_index] = value.x
	destination[base_index + 1] = value.y
	destination[base_index + 2] = value.z
	destination[base_index + 3] = value.w


static func _load_quaternion(source: PackedFloat64Array, row_index: int) -> Quaternion:
	var base_index := row_index * QUATERNION_COMPONENT_COUNT
	return Quaternion(
		float(source[base_index]),
		float(source[base_index + 1]),
		float(source[base_index + 2]),
		float(source[base_index + 3]),
	)


static func _task_axis_array(buffer: CaptureBuffer, axis_index: int) -> Array:
	var base_index := axis_index * VECTOR_COMPONENT_COUNT
	return [
		float(buffer.constant_task_axes_world_unit[base_index]),
		float(buffer.constant_task_axes_world_unit[base_index + 1]),
		float(buffer.constant_task_axes_world_unit[base_index + 2]),
	]


static func _vector3_array(source: PackedFloat64Array, row_index: int) -> Array:
	var base_index := row_index * VECTOR_COMPONENT_COUNT
	return [
		float(source[base_index]),
		float(source[base_index + 1]),
		float(source[base_index + 2]),
	]


static func _contacts_dictionary(source: PackedByteArray, row_index: int) -> Dictionary:
	var base_index := row_index * LIMB_ORDER.size()
	var contacts := {}
	for limb_index in range(LIMB_ORDER.size()):
		contacts[LIMB_ORDER[limb_index]] = bool(source[base_index + limb_index])
	return contacts


static func _exact_boolean_contacts(contacts: Dictionary) -> bool:
	if not _has_exact_keys(contacts, LIMB_ORDER):
		return false
	for limb_id_value in LIMB_ORDER:
		if typeof(contacts[String(limb_id_value)]) != TYPE_BOOL:
			return false
	return true


static func _is_numeric_scalar(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


static func _has_exact_keys(values: Dictionary, expected_keys: Array) -> bool:
	if values.size() != expected_keys.size():
		return false
	for key_value in expected_keys:
		if not values.has(String(key_value)):
			return false
	return true


static func _fail_buffer(buffer: CaptureBuffer, code: String) -> String:
	buffer.failed = true
	buffer.failure_code = code
	return code


static func _failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"native_readback_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
