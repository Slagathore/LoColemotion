class_name LabJointAngleStream
extends RefCounted

## Stateful owner for one hinge's unwrapped coordinate.
##
## LabJointState is intentionally a pure sampler and cannot prove that a
## segment identifier has never been accepted before.  This owner supplies the
## missing lifetime invariant: the first accepted sample registers the segment
## exactly once, subsequent samples use only the internally held predecessor,
## and any lineage failure closes the active segment.  Recovery requires a new
## initialization witness and a never-before-accepted segment id.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const JointStateScript := preload(
	"res://scripts/lab/mechanics/joint_state.gd")

const RESULT_SCHEMA_VERSION := "joint_angle_stream_operation_v1"

var _seen_segment_keys: Dictionary = {}
var _previous_state: Dictionary = {}
var _active_segment_key := ""
var _active_segment_id := -1


func start_segment(
		binding: Dictionary,
		parent_sample: Dictionary,
		child_sample: Dictionary,
		initialization_witness: Dictionary) -> Dictionary:
	var segment_id := int(initialization_witness.get(
		"unwrap_segment_id", -1))
	var segment_key := _segment_key(
		binding, parent_sample, segment_id)
	if segment_id < 0 or segment_key.is_empty():
		return _failure("SEGMENT_IDENTITY_INVALID", null)
	if _seen_segment_keys.has(segment_key):
		return _failure("UNWRAP_SEGMENT_REUSE", null)

	var state: Dictionary = JointStateScript.sample(
		binding,
		parent_sample,
		child_sample,
		{},
		{
			"unwrap_segment_id": segment_id,
			"initialization_witness": initialization_witness,
		})
	if not bool(state.get("unwrapped_angle_available", false)) \
			or not bool(state.get("complete", false)):
		return _failure("SEGMENT_INITIALIZATION_REJECTED", state)

	_seen_segment_keys[segment_key] = true
	_previous_state = state
	_active_segment_key = segment_key
	_active_segment_id = segment_id
	return _success("SEGMENT_INITIALIZED", state)


func advance(
		binding: Dictionary,
		parent_sample: Dictionary,
		child_sample: Dictionary) -> Dictionary:
	if _active_segment_key.is_empty() or _previous_state.is_empty():
		return _failure("NO_ACTIVE_UNWRAP_SEGMENT", null)
	var expected_key := _segment_key(
		binding, parent_sample, _active_segment_id)
	if expected_key != _active_segment_key:
		return _failure("ACTIVE_SEGMENT_IDENTITY_MISMATCH", null)
	var state: Dictionary = JointStateScript.sample(
		binding,
		parent_sample,
		child_sample,
		_previous_state,
		{"unwrap_segment_id": _active_segment_id})
	_previous_state = state
	if not bool(state.get("unwrapped_angle_available", false)) \
			or not bool(state.get("complete", false)):
		_active_segment_key = ""
		_active_segment_id = -1
		return _failure("ACTIVE_SEGMENT_LINEAGE_LOST", state)
	return _success("SEGMENT_ADVANCED", state)


func active() -> bool:
	return not _active_segment_key.is_empty()


func previous_state() -> Dictionary:
	return _previous_state


func accepted_segment_count() -> int:
	return _seen_segment_keys.size()


func _segment_key(
		binding: Dictionary,
		sample: Dictionary,
		segment_id: int) -> String:
	var joint_id := String(binding.get("joint_id", ""))
	var run_id := String(sample.get("run_id", ""))
	var capture_stream_id := String(sample.get("capture_stream_id", ""))
	if joint_id.is_empty() or run_id.is_empty() \
			or capture_stream_id.is_empty() or segment_id < 0:
		return ""
	return "%s|%s|%s|%d" % [
		run_id, capture_stream_id, joint_id, segment_id]


func _success(code: String, state: Dictionary) -> Dictionary:
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": true,
		"code": code,
		"active": active(),
		"active_segment_id": _active_segment_id,
		"accepted_segment_count": accepted_segment_count(),
		"state": state,
	})


func _failure(code: String, state: Variant) -> Dictionary:
	return FrozenValueScript.snapshot({
		"schema_version": RESULT_SCHEMA_VERSION,
		"ok": false,
		"code": code,
		"active": active(),
		"active_segment_id": (
			_active_segment_id if _active_segment_id >= 0 else null),
		"accepted_segment_count": accepted_segment_count(),
		"state": state,
	})
