class_name CanonicalJson
extends RefCounted

## Canonical JSON policy:
## - dictionary keys are recursively sorted after scalar-key normalization;
## - StringName and integer keys become JSON object-key strings;
## - math values become explicit arrays/objects in a fixed component order;
## - negative zero is normalized to positive zero;
## - floats use a documented 14-significant-digit normalization policy before
##   Godot's full-precision writer emits the normalized value;
## - non-finite and unsupported values are rejected before bytes are produced.

const FiniteSanitizerScript := preload("res://scripts/lab/finite_sanitizer.gd")
const MAX_EXACT_JSON_INTEGER := 9007199254740991
const MIN_EXACT_JSON_INTEGER := -9007199254740991


static func stringify(value: Variant) -> String:
	var report := FiniteSanitizerScript.inspect(value)
	assert(
		bool(report["ok"]),
		"Canonical JSON rejected invalid input: %s" % str(report["failures"]))
	var normalized: Variant = normalize(value)
	return JSON.stringify(normalized, "", true, true)


static func encode(value: Variant) -> PackedByteArray:
	return stringify(value).to_utf8_buffer()


static func sha256(value: Variant) -> String:
	return "sha256:%s" % stringify(value).sha256_text()


static func normalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return value

		TYPE_INT:
			var integer := int(value)
			assert(
				integer >= MIN_EXACT_JSON_INTEGER
					and integer <= MAX_EXACT_JSON_INTEGER,
				"Canonical JSON rejected an integer outside the exact JSON range")
			return integer

		TYPE_STRING_NAME:
			return String(value)

		TYPE_FLOAT:
			var number := float(value)
			assert(is_finite(number), "Canonical JSON rejected a non-finite float")
			# Godot's JSON reader does not promise to preserve whether a JSON
			# number originated as int or integral float. Within IEEE-754's
			# exact integer range they therefore share one canonical integer
			# representation, including both signs of zero.
			if (
				number >= float(MIN_EXACT_JSON_INTEGER)
				and number <= float(MAX_EXACT_JSON_INTEGER)
				and number == floor(number)
			):
				return int(number)
			# Godot 4.7's full-precision writer can choose an adjacent final
			# decimal digit after its own output is parsed (for example ...129
			# becomes ...128). String.num() has a documented default policy of
			# at most 14 significant digits, but decimal notation underflows
			# very small magnitudes to "0". Use Godot's scientific formatter at
			# the extremes, then parse exactly once. Re-normalizing a parsed
			# record follows the same branch and is therefore idempotent.
			var magnitude := absf(number)
			var normalized_text := (
				String.num_scientific(number)
				if magnitude < 1.0e-6 or magnitude >= 1.0e14
				else String.num(number))
			var quantized := normalized_text.to_float()
			if (
				quantized >= float(MIN_EXACT_JSON_INTEGER)
				and quantized <= float(MAX_EXACT_JSON_INTEGER)
				and quantized == floor(quantized)
			):
				return int(quantized)
			return quantized

		TYPE_VECTOR2:
			var vector: Vector2 = value
			return [normalize(vector.x), normalize(vector.y)]

		TYPE_VECTOR3:
			var vector: Vector3 = value
			return [
				normalize(vector.x),
				normalize(vector.y),
				normalize(vector.z),
			]

		TYPE_VECTOR4:
			var vector: Vector4 = value
			return [
				normalize(vector.x),
				normalize(vector.y),
				normalize(vector.z),
				normalize(vector.w),
			]

		TYPE_QUATERNION:
			var quaternion: Quaternion = value
			return [
				normalize(quaternion.x),
				normalize(quaternion.y),
				normalize(quaternion.z),
				normalize(quaternion.w),
			]

		TYPE_COLOR:
			var color: Color = value
			return [
				normalize(color.r),
				normalize(color.g),
				normalize(color.b),
				normalize(color.a),
			]

		TYPE_BASIS:
			var basis: Basis = value
			return [
				normalize(basis.x),
				normalize(basis.y),
				normalize(basis.z),
			]

		TYPE_TRANSFORM3D:
			var transform: Transform3D = value
			return {
				"basis": normalize(transform.basis),
				"origin": normalize(transform.origin),
			}

		TYPE_ARRAY:
			var source: Array = value
			var result: Array = []
			result.resize(source.size())
			for index in range(source.size()):
				result[index] = normalize(source[index])
			return result

		TYPE_DICTIONARY:
			var source: Dictionary = value
			var sortable_entries: Array[Dictionary] = []
			for key in source.keys():
				assert(
					_is_stable_key(key),
					"Canonical JSON rejected an unstable dictionary key")
				sortable_entries.append({
					"key": key,
					"json_key": _key_text(key),
				})
			sortable_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return String(a["json_key"]) < String(b["json_key"]))
			var result: Dictionary = {}
			for entry in sortable_entries:
				var json_key := String(entry["json_key"])
				assert(
					not result.has(json_key),
					"Canonical JSON key collision after scalar-key normalization: %s"
						% json_key)
				result[json_key] = normalize(source[entry["key"]])
			return result

		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, \
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, \
		TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return normalize(Array(value))

		_:
			assert(
				false,
				"Canonical JSON rejected unsupported Variant type: %s"
					% type_string(typeof(value)))
			return null


static func _key_text(key: Variant) -> String:
	return str(key) if typeof(key) == TYPE_INT else String(key)


static func _is_stable_key(key: Variant) -> bool:
	return typeof(key) in [
		TYPE_STRING,
		TYPE_STRING_NAME,
		TYPE_INT,
	]
