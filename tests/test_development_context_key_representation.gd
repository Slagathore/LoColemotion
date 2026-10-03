extends SceneTree

const Cache := preload("res://sdk/adapters/godot/gdscript/development_exact_context_cache_v1.gd")


func _initialize() -> void:
	var bits := PackedByteArray()
	bits.resize(8)
	bits.encode_s64(0, -9223372036854775807 - 1)
	var negative_zero := bits.decode_double(0)
	var literal_pair := [0.0, -0.0]
	var literal_bits: Array = []
	for value in literal_pair:
		bits.encode_double(0, value)
		literal_bits.append(bits.hex_encode())
	var zero_keys := [
		Cache.exact_key_v1({"value": 0.0}).hex_encode(),
		Cache.exact_key_v1({"value": negative_zero}).hex_encode()
	]
	var nul := "a" + String.chr(0) + "b"
	var codepoints: Array = []
	for index in range(nul.length()):
		codepoints.append(nul.unicode_at(index))
	print(
		"CONTEXT_KEY_REPRESENTATION ",
		(
			JSON
			. stringify(
				{
					"literal_pair_binary64_le": literal_bits,
					"runtime_signed_zero_keys": zero_keys,
					"runtime_signed_zero_distinct": zero_keys[0] != zero_keys[1],
					"nul_codepoints": codepoints,
					"nul_utf32_hex": nul.to_utf32_buffer().hex_encode(),
					"world_build_count": 0,
					"solver_step_count": 0,
				}
			)
		)
	)
	quit()
