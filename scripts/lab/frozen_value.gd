class_name FrozenValue
extends RefCounted

## Creates a detached, recursively read-only value snapshot. Runtime object
## identity is forbidden across this boundary; stable IDs must be recorded
## instead.


static func snapshot(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var copy: Dictionary = {}
			for key in source.keys():
				assert(
					_is_stable_key(key),
					"Unstable dictionary key crossed a sealed value boundary")
				copy[key] = snapshot(source[key])
			copy.make_read_only()
			return copy

		TYPE_ARRAY:
			var source: Array = value
			var copy: Array = []
			copy.resize(source.size())
			for index in range(source.size()):
				copy[index] = snapshot(source[index])
			copy.make_read_only()
			return copy

		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, \
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, \
		TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return snapshot(Array(value))

		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, \
		TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_VECTOR3, \
		TYPE_VECTOR4, TYPE_QUATERNION, TYPE_COLOR, TYPE_BASIS, \
		TYPE_TRANSFORM3D:
			# Scalars and Godot math value types copy by value.
			return value

		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			assert(false, "Runtime object crossed a sealed value boundary")
			return null

		_:
			assert(
				false,
				"Unsupported Variant type crossed a sealed value boundary: %s"
					% type_string(typeof(value)))
			return null


static func _is_stable_key(key: Variant) -> bool:
	return typeof(key) in [
		TYPE_STRING,
		TYPE_STRING_NAME,
		TYPE_INT,
	]
