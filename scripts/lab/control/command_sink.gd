class_name LabCommandSink
extends RefCounted

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

var tick := -1
var sealed := false
var sealed_sha256 := ""
var _builders: Array = []
var _sealed_values: Array = []


func _init(for_tick := -1) -> void:
	tick = for_tick


func submit(intent: RefCounted) -> bool:
	if sealed or intent == null or not intent.has_method("to_value_dictionary"):
		return false
	var value: Dictionary = intent.call("to_value_dictionary")
	if int(value.get("tick", -2)) != tick:
		return false
	_builders.append(intent)
	return true


func seal() -> Array:
	if sealed:
		return _sealed_values
	for intent in _builders:
		_sealed_values.append(
			FrozenValueScript.snapshot(intent.call("to_value_dictionary")))
	_builders.clear()
	_sealed_values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) > int(b["priority"])
		return String(a["intent_id"]) < String(b["intent_id"]))
	_sealed_values.make_read_only()
	sealed_sha256 = CanonicalJsonScript.sha256(_sealed_values)
	sealed = true
	return _sealed_values
