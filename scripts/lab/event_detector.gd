class_name LabEventDetector
extends RefCounted

## Deterministic event ordering. Hash-map iteration order is never evidence.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const FAMILY_PRIORITY := {
	"NONFINITE_DETECTED": 0,
	"UNAUTHORIZED_INTERVENTION": 0,
	"ABORT": 0,
	"CONTACT_BEGIN": 10,
	"CONTACT_END": 10,
	"SUPPORT_STATE_CHANGE": 20,
	"SATURATION_BEGIN": 30,
	"SATURATION_END": 30,
	"LIMIT_HIT": 30,
	"ALLOCATOR_INFEASIBLE": 40,
	"MODE_TRANSITION": 50,
	"RECOVERY_PHASE_BEGIN": 50,
	"RECOVERY_SUCCESS": 50,
	"RECOVERY_FAILURE": 50,
	"PROMOTION_DECISION": 60,
}

var _run_id := ""
var _next_sequence := 0
var _pending: Array = []


func _init(run_id := "") -> void:
	_run_id = run_id


func queue(
		frame_id: int,
		event: String,
		evidence: Dictionary = {},
		subject_id := "",
		detector_local_ordinal := 0,
		fields: Dictionary = {}) -> bool:
	if frame_id < 0 or not FAMILY_PRIORITY.has(event):
		return false
	var builder := fields.duplicate(true)
	builder["schema"] = "sporespore.lab.event.v1"
	builder["run_id"] = _run_id
	builder["frame_id"] = frame_id
	builder["event"] = event
	builder["subject_id"] = subject_id
	builder["detector_local_ordinal"] = detector_local_ordinal
	builder["evidence"] = evidence
	_pending.append(builder)
	return true


func commit_frame(frame_id: int) -> Array:
	var selected: Array = []
	var retained: Array = []
	for event in _pending:
		if int(event["frame_id"]) == frame_id:
			selected.append(event)
		else:
			retained.append(event)
	_pending = retained
	selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(FAMILY_PRIORITY[a["event"]])
		var pb := int(FAMILY_PRIORITY[b["event"]])
		if pa != pb:
			return pa < pb
		if String(a["subject_id"]) != String(b["subject_id"]):
			return String(a["subject_id"]) < String(b["subject_id"])
		return int(a["detector_local_ordinal"]) < int(b["detector_local_ordinal"]))
	var result: Array = []
	for event in selected:
		event["event_sequence"] = _next_sequence
		_next_sequence += 1
		result.append(FrozenValueScript.snapshot(
			CanonicalJsonScript.normalize(event)))
	result.make_read_only()
	return result
