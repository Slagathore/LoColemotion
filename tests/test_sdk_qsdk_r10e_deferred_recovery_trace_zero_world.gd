extends SceneTree
# gdlint: disable=max-line-length

## Zero-world controls for the QSDK-R10E deferred recovery trace observer.
## This test constructs no Node, model, fixture, physics world, or native route.

const DeferredTraceScript := preload(
	"res://sdk/adapters/godot/gdscript/deferred_recovery_trace_v1.gd"
)

const PASS_MARKER := "QSDK_R10E_DEFERRED_RECOVERY_TRACE_ZERO_WORLD_PASS"

var _failures: Array[String] = []


func _init() -> void:
	_positive_materialization_control()
	_refusal_controls()
	if _failures.is_empty():
		print(PASS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _positive_materialization_control() -> void:
	var prepared := DeferredTraceScript.prepare(_trace_options())
	_check(bool(prepared.get("ok", false)), "positive prepare")
	if not bool(prepared.get("ok", false)):
		return
	var buffer: Variant = prepared.get("buffer", null)
	for semantic_step in range(3):
		var before_failure := (
			DeferredTraceScript
			. capture_before_solver_step(
				buffer,
				_sample_result(semantic_step),
				_step_result(semantic_step),
				_application_result(semantic_step),
				semantic_step,
				_contacts(semantic_step % 2 == 0),
			)
		)
		_check(before_failure.is_empty(), "positive before capture %d" % semantic_step)
		var after_failure := (
			DeferredTraceScript
			. capture_after_solver_step(
				buffer,
				semantic_step,
				Vector3(0.01 * semantic_step, 0.44, -0.02 * semantic_step),
				Quaternion(Vector3.UP, 0.001 * semantic_step),
				Vector3(0.2, 0.0, 0.01),
				Vector3(0.0, 0.02, 0.0),
				0.01 + 0.001 * semantic_step,
				false,
				_contacts(semantic_step % 2 != 0),
			)
		)
		_check(after_failure.is_empty(), "positive after capture %d" % semantic_step)
	var materialized := DeferredTraceScript.materialize_after_final_solver_step(buffer, 3)
	_check(bool(materialized.get("ok", false)), "positive materialization")
	if not bool(materialized.get("ok", false)):
		return
	var rows: Array = materialized.get("rows", [])
	var instrumentation: Dictionary = (
		materialized
		. get(
			"observer_instrumentation_receipt",
			{},
		)
	)
	_check(rows.size() == 3, "one materialized row per capture")
	_check(int(instrumentation.get("capture_buffer_capacity", -1)) == 2872, "fixed capacity")
	_check(int(instrumentation.get("captured_row_count", -1)) == 3, "captured count")
	_check(int(instrumentation.get("live_raw_before_capture_count", -1)) == 3, "before count")
	_check(int(instrumentation.get("live_raw_after_capture_count", -1)) == 3, "after count")
	_check(
		int(instrumentation.get("live_nested_row_materialization_count", -1)) == 0, "no live rows"
	)
	_check(
		int(instrumentation.get("live_trace_row_deep_duplicate_count", -1)) == 0,
		"no live duplicates"
	)
	_check(
		int(instrumentation.get("live_trace_json_or_hash_count", -1)) == 0, "no live JSON or hash"
	)
	_check(
		int(instrumentation.get("live_quaternion_projection_receipt_count", -1)) == 0,
		"no live projections"
	)
	_check(int(instrumentation.get("post_solver_materialized_row_count", -1)) == 3, "post rows")
	_check(
		int(instrumentation.get("post_solver_projection_receipt_count", -1)) == 3,
		"post projections"
	)
	_check(
		bool(instrumentation.get("captured_row_count_matches_trace_row_count", false)),
		"capture match"
	)
	_check(
		bool(
			(
				instrumentation
				. get(
					"post_solver_materialized_row_count_matches_trace_row_count",
					false,
				)
			)
		),
		"materialized match",
	)
	_check(
		bool(
			(
				instrumentation
				. get(
					"post_solver_projection_receipt_count_matches_trace_row_count",
					false,
				)
			)
		),
		"projection match",
	)
	_check(
		int(instrumentation.get("additional_solver_step_during_materialization_count", -1)) == 0,
		"no solver step"
	)
	_check(not bool(instrumentation.get("physics_state_modified", true)), "observer is read only")
	for row_index in range(rows.size()):
		var row: Dictionary = rows[row_index]
		_check(int(row.get("semantic_step", -1)) == row_index, "row order %d" % row_index)
		_check(
			String(row.get("schema_version", "")) == DeferredTraceScript.TRACE_ROW_SCHEMA,
			"row schema %d" % row_index,
		)
		_check(
			bool(row.get("post_physics_observation_complete", false)), "complete row %d" % row_index
		)
		_check(
			not bool(row.get("observer_physics_state_modified", true)),
			"read-only row %d" % row_index
		)


func _refusal_controls() -> void:
	var extra_options := _trace_options()
	extra_options["undeclared"] = true
	_check(
		(
			String(DeferredTraceScript.prepare(extra_options).get("failure_code", ""))
			== "QSDK_R10E_DEFERRED_TRACE_OPTION_KEYS_INVALID"
		),
		"extra option refused",
	)
	var wrong_policy := _trace_options()
	wrong_policy["policy_id"] = "qsdk_r10d_supported_start_phase_robust_push_recovery_trace_v1"
	_check(
		(
			String(DeferredTraceScript.prepare(wrong_policy).get("failure_code", ""))
			== "QSDK_R10E_DEFERRED_TRACE_POLICY_RECEIPT_MISMATCH"
		),
		"historical policy refused",
	)
	var noncontiguous: Variant = _prepared_buffer()
	_check(
		(
			(
				DeferredTraceScript
				. capture_before_solver_step(
					noncontiguous,
					_sample_result(1),
					_step_result(1),
					_application_result(1),
					1,
					_contacts(true),
				)
			)
			== "QSDK_R10E_DEFERRED_TRACE_SEMANTIC_STEP_NONCONTIGUOUS"
		),
		"noncontiguous step refused",
	)
	var missing_after: Variant = _prepared_buffer()
	_check(
		(
			DeferredTraceScript
			. capture_before_solver_step(
				missing_after,
				_sample_result(0),
				_step_result(0),
				_application_result(0),
				0,
				_contacts(true),
			)
			. is_empty()
		),
		"missing-after setup",
	)
	_check(
		(
			(
				DeferredTraceScript
				. capture_before_solver_step(
					missing_after,
					_sample_result(0),
					_step_result(0),
					_application_result(0),
					0,
					_contacts(true),
				)
			)
			== "QSDK_R10E_DEFERRED_TRACE_POST_CAPTURE_MISSING"
		),
		"second before capture refused",
	)
	var missing_before: Variant = _prepared_buffer()
	_check(
		(
			(
				DeferredTraceScript
				. capture_after_solver_step(
					missing_before,
					0,
					Vector3.ZERO,
					Quaternion.IDENTITY,
					Vector3.ZERO,
					Vector3.ZERO,
					0.0,
					false,
					_contacts(true),
				)
			)
			== "QSDK_R10E_DEFERRED_TRACE_PRE_CAPTURE_MISSING"
		),
		"after without before refused",
	)
	var bad_contacts := _contacts(true)
	bad_contacts.erase("front_left")
	var invalid_contacts_buffer: Variant = _prepared_buffer()
	_check(
		(
			(
				DeferredTraceScript
				. capture_before_solver_step(
					invalid_contacts_buffer,
					_sample_result(0),
					_step_result(0),
					_application_result(0),
					0,
					bad_contacts,
				)
			)
			== "QSDK_R10E_DEFERRED_TRACE_PRE_CONTACTS_INVALID"
		),
		"missing contact refused",
	)
	var changed_axis_buffer: Variant = _prepared_buffer()
	_capture_complete_row(changed_axis_buffer, 0)
	var changed_sample := _sample_result(1)
	changed_sample["request"]["state"]["task_frame"]["lateral_axis_world_unit"]["z"] = -1.0
	_check(
		(
			(
				DeferredTraceScript
				. capture_before_solver_step(
					changed_axis_buffer,
					changed_sample,
					_step_result(1),
					_application_result(1),
					1,
					_contacts(true),
				)
			)
			== "QSDK_R10E_DEFERRED_TRACE_TASK_AXES_INVALID_OR_CHANGED"
		),
		"changed task axis refused",
	)
	var count_mismatch_buffer: Variant = _prepared_buffer()
	_capture_complete_row(count_mismatch_buffer, 0)
	_check(
		(
			String(
				(
					DeferredTraceScript
					. materialize_after_final_solver_step(
						count_mismatch_buffer,
						2,
					)
					. get("failure_code", "")
				)
			)
			== "QSDK_R10E_DEFERRED_TRACE_CAPTURE_COUNT_MISMATCH"
		),
		"materialization count mismatch refused",
	)
	var nonfinite_buffer: Variant = _prepared_buffer()
	_check(
		(
			DeferredTraceScript
			. capture_before_solver_step(
				nonfinite_buffer,
				_sample_result(0),
				_step_result(0),
				_application_result(0),
				0,
				_contacts(true),
			)
			. is_empty()
		),
		"nonfinite setup",
	)
	_check(
		(
			(
				DeferredTraceScript
				. capture_after_solver_step(
					nonfinite_buffer,
					0,
					Vector3(NAN, 0.0, 0.0),
					Quaternion.IDENTITY,
					Vector3.ZERO,
					Vector3.ZERO,
					0.0,
					false,
					_contacts(true),
				)
			)
			== "QSDK_R10E_DEFERRED_TRACE_POST_STATE_INVALID"
		),
		"nonfinite state refused",
	)


func _capture_complete_row(buffer: Variant, semantic_step: int) -> void:
	var before_failure := (
		DeferredTraceScript
		. capture_before_solver_step(
			buffer,
			_sample_result(semantic_step),
			_step_result(semantic_step),
			_application_result(semantic_step),
			semantic_step,
			_contacts(true),
		)
	)
	_check(before_failure.is_empty(), "helper before capture")
	if not before_failure.is_empty():
		return
	_check(
		(
			DeferredTraceScript
			. capture_after_solver_step(
				buffer,
				semantic_step,
				Vector3(0.0, 0.44, 0.0),
				Quaternion.IDENTITY,
				Vector3(0.2, 0.0, 0.0),
				Vector3.ZERO,
				0.01,
				false,
				_contacts(false),
			)
			. is_empty()
		),
		"helper after capture",
	)


func _prepared_buffer() -> Variant:
	var prepared := DeferredTraceScript.prepare(_trace_options())
	_check(bool(prepared.get("ok", false)), "refusal prepare")
	return prepared.get("buffer", null)


static func _trace_options() -> Dictionary:
	return {
		"cell_id": "synthetic_s0",
		"enabled": true,
		"maximum_controller_step_count": 2872,
		"minimum_controller_step_count": 2152,
		"policy_id": DeferredTraceScript.TRACE_POLICY_ID,
		"push_marker_semantic_step": 900,
		"sampling_phase": DeferredTraceScript.TRACE_SAMPLING_PHASE,
		"trace_row_schema_version": DeferredTraceScript.TRACE_ROW_SCHEMA,
	}


static func _sample_result(semantic_step: int) -> Dictionary:
	return {
		"ok": true,
		"request":
		{
			"state":
			{
				"semantic_step": semantic_step,
				"task_frame":
				{
					"forward_axis_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
					"lateral_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
				},
			},
			"command":
			{
				"valid_from_step": semantic_step,
				"valid_through_step": semantic_step,
			},
		},
	}


static func _step_result(semantic_step: int) -> Dictionary:
	var commands: Array = []
	commands.resize(8)
	return {
		"ok": true,
		"semantic_step": semantic_step,
		"native_output": {"actuation": {"ordered_commands": commands}},
	}


static func _application_result(semantic_step: int) -> Dictionary:
	return {
		"ok": true,
		"semantic_step": semantic_step,
		"applied_command_count": 8,
	}


static func _contacts(value: bool) -> Dictionary:
	return {
		"front_left": value,
		"front_right": not value,
		"rear_left": not value,
		"rear_right": value,
	}


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
