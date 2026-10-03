class_name LabControlContext
extends RefCounted

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")
const RandomStreamCapabilityScript := preload("res://scripts/lab/random_stream_capability.gd")

var _expanded_experiment: Dictionary = {}
var _expanded_spec_sha256 := ""
var _rng_streams: Dictionary = {}


func _init(expanded: Dictionary = {}, stream_seeds: Dictionary = {}) -> void:
	_expanded_experiment = FrozenValueScript.snapshot(expanded)
	_expanded_spec_sha256 = CanonicalJsonScript.sha256(_expanded_experiment)
	for stream_id in stream_seeds.keys():
		_rng_streams[String(stream_id)] = RandomStreamCapabilityScript.create(
			StringName(stream_id), int(stream_seeds[stream_id]))
	_rng_streams.make_read_only()


func expanded_experiment() -> Dictionary:
	return _expanded_experiment


func expanded_spec_sha256() -> String:
	return _expanded_spec_sha256


func rng(stream_id: StringName) -> RefCounted:
	return _rng_streams.get(String(stream_id))


func rng_manifest_values() -> Dictionary:
	var result: Dictionary = {}
	for stream_id in _rng_streams.keys():
		var capability: RefCounted = _rng_streams[stream_id]
		result[stream_id] = capability.call("manifest_entry")
	return FrozenValueScript.snapshot(result)


func spec_is_unchanged() -> bool:
	return (
		_expanded_experiment.is_read_only()
		and CanonicalJsonScript.sha256(_expanded_experiment) == _expanded_spec_sha256)
