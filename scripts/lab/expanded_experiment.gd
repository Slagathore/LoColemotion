class_name ExpandedExperiment
extends RefCounted

## Immutable, fully defaulted and validated experiment produced only after the
## compiler has resolved precedence and observer capabilities.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FiniteSanitizerScript := preload("res://scripts/lab/finite_sanitizer.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

var _value: Dictionary
var _applied_overrides: Array
var _canonical_text := ""
var _expanded_spec_sha256 := ""


func _init(value: Dictionary = {}, applied_overrides: Array = []) -> void:
	var report := FiniteSanitizerScript.inspect(value)
	assert(
		bool(report["ok"]),
		"Expanded experiment contains invalid values: %s" % str(report["failures"]))
	_value = FrozenValueScript.snapshot(value)
	_applied_overrides = FrozenValueScript.snapshot(applied_overrides)
	_canonical_text = CanonicalJsonScript.stringify(_value)
	_expanded_spec_sha256 = CanonicalJsonScript.sha256(_value)


func value() -> Dictionary:
	return _value


func applied_overrides() -> Array:
	return _applied_overrides


func canonical_text() -> String:
	return _canonical_text


func expanded_spec_sha256() -> String:
	return _expanded_spec_sha256


func assert_integrity() -> bool:
	return (
		_value.is_read_only()
		and _applied_overrides.is_read_only()
		and CanonicalJsonScript.stringify(_value) == _canonical_text
		and CanonicalJsonScript.sha256(_value) == _expanded_spec_sha256)
