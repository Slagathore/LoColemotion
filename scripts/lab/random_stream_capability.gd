class_name RandomStreamCapability
extends RefCounted

## A draw-only capability around exactly one named deterministic stream.
## Controller-facing code receives this object, never the generator or a seed
## setter, so unrelated random concerns cannot shift each other's sequences.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

var _stream_id: StringName = &""
var _seed_sha256 := ""
var _draw_count := 0
var _generator: RandomNumberGenerator

var stream_id: StringName:
	get:
		return _stream_id

var seed_sha256: String:
	get:
		return _seed_sha256

var draw_count: int:
	get:
		return _draw_count


static func create(p_stream_id: StringName, p_seed: int):
	assert(not String(p_stream_id).is_empty(), "Random stream ID must not be empty")
	var capability := RandomStreamCapability.new()
	capability._stream_id = p_stream_id
	capability._seed_sha256 = CanonicalJsonScript.sha256({
		"seed": p_seed,
		"stream_id": String(p_stream_id),
	})
	capability._generator = RandomNumberGenerator.new()
	capability._generator.seed = p_seed
	return capability


static func derive_seed(root_seed: int, p_stream_id: StringName) -> int:
	assert(not String(p_stream_id).is_empty(), "Random stream ID must not be empty")
	var digest := CanonicalJsonScript.sha256({
		"root_seed": root_seed,
		"stream_id": String(p_stream_id),
	})
	# Thirteen hex digits retain 52 deterministic bits and stay inside JSON's
	# exact IEEE-754 integer range. The complete digest remains the provenance
	# identity.
	return digest.substr("sha256:".length(), 13).hex_to_int()


func randf() -> float:
	_assert_configured()
	_draw_count += 1
	return _generator.randf()


func randf_range(from: float, to: float) -> float:
	_assert_configured()
	_draw_count += 1
	return _generator.randf_range(from, to)


func randi() -> int:
	_assert_configured()
	_draw_count += 1
	return _generator.randi()


func randi_range(from: int, to: int) -> int:
	_assert_configured()
	_draw_count += 1
	return _generator.randi_range(from, to)


func randfn(mean := 0.0, deviation := 1.0) -> float:
	_assert_configured()
	_draw_count += 1
	return _generator.randfn(mean, deviation)


func manifest_entry() -> Dictionary:
	_assert_configured()
	return {
		"stream_id": String(_stream_id),
		"seed_sha256": _seed_sha256,
		"draw_count": _draw_count,
		"consumed": _draw_count > 0,
	}


func _assert_configured() -> void:
	assert(_generator != null, "Random stream capability was not configured")
