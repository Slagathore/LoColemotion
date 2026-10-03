class_name ExecutionReceiptSink
extends RefCounted

## Append-only proof of executor calls. A plan is not treated as applied until a
## receipt with the same source hash and operation ID exists.

const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

var _run_id := ""
var _application_sequence := 0
var _call_ordinal := 0
var _receipts: Array = []


func _init(run_id := "") -> void:
	_run_id = run_id


func next_call_ordinal() -> int:
	var result := _call_ordinal
	_call_ordinal += 1
	return result


func append_call_returned(fields: Dictionary) -> Dictionary:
	return _append(fields, "call_returned", null)


func append_call_failed(fields: Dictionary, failure_code: String) -> Dictionary:
	return _append(fields, "call_failed", failure_code)


func values() -> Array:
	var result := _receipts.duplicate()
	result.make_read_only()
	return result


func _append(fields: Dictionary, status: String, failure_code: Variant) -> Dictionary:
	var builder := fields.duplicate(true)
	builder["schema"] = "sporespore.lab.application.v1"
	builder["run_id"] = _run_id
	builder["application_sequence"] = _application_sequence
	builder["status"] = status
	builder["failure_code"] = failure_code
	# Receipts are evidence values, not engine-call argument objects. Normalize
	# math variants now so schema validation sees the same exact array shape
	# that canonical JSON will write.
	var sealed: Dictionary = FrozenValueScript.snapshot(
		CanonicalJsonScript.normalize(builder))
	_receipts.append(sealed)
	_application_sequence += 1
	return sealed
