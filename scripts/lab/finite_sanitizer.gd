class_name FiniteSanitizer
extends RefCounted

## Deterministically walks a value tree before it crosses a serialization,
## sealing, or physics-mutation boundary. The returned paths are JSON Pointers
## so a terminal record can identify the exact invalid value without trying to
## serialize that value itself.

const MAX_EXACT_JSON_INTEGER := 9007199254740991
const MIN_EXACT_JSON_INTEGER := -9007199254740991


static func inspect(value: Variant) -> Dictionary:
	var failures: Array[Dictionary] = []
	_walk(value, "", failures)
	return {
		"ok": failures.is_empty(),
		"failures": failures,
	}


static func sanitize(value: Variant, source_id := "unknown") -> Dictionary:
	var availability: Dictionary = {}
	var failures: Array[Dictionary] = []
	var sanitized: Variant = _sanitize_walk(
		value,
		"",
		source_id,
		availability,
		failures)
	availability.make_read_only()
	failures.make_read_only()
	return {
		"ok": failures.is_empty(),
		"value": sanitized,
		"availability": availability,
		"failures": failures,
		"first_failure": {} if failures.is_empty() else failures[0],
	}


static func is_finite_tree(value: Variant) -> bool:
	return bool(inspect(value)["ok"])


static func first_failure(value: Variant) -> Dictionary:
	var report := inspect(value)
	var failures: Array = report["failures"]
	return {} if failures.is_empty() else failures[0]


static func assert_finite(value: Variant, label := "value") -> void:
	var report := inspect(value)
	assert(
		bool(report["ok"]),
		"%s contains an invalid value: %s" % [label, str(first_failure(value))])


static func _walk(value: Variant, path: String, failures: Array[Dictionary]) -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME:
			return

		TYPE_INT:
			var integer := int(value)
			if (
				integer < MIN_EXACT_JSON_INTEGER
				or integer > MAX_EXACT_JSON_INTEGER
			):
				_append_failure(
					failures,
					path,
					"INTEGER_OUT_OF_JSON_EXACT_RANGE",
					TYPE_INT)

		TYPE_FLOAT:
			if not is_finite(float(value)):
				_append_failure(failures, path, "NONFINITE_FLOAT", TYPE_FLOAT)

		TYPE_VECTOR2:
			var vector: Vector2 = value
			_walk(vector.x, _child_path(path, "x"), failures)
			_walk(vector.y, _child_path(path, "y"), failures)

		TYPE_VECTOR3:
			var vector: Vector3 = value
			_walk(vector.x, _child_path(path, "x"), failures)
			_walk(vector.y, _child_path(path, "y"), failures)
			_walk(vector.z, _child_path(path, "z"), failures)

		TYPE_VECTOR4:
			var vector: Vector4 = value
			_walk(vector.x, _child_path(path, "x"), failures)
			_walk(vector.y, _child_path(path, "y"), failures)
			_walk(vector.z, _child_path(path, "z"), failures)
			_walk(vector.w, _child_path(path, "w"), failures)

		TYPE_QUATERNION:
			var quaternion: Quaternion = value
			_walk(quaternion.x, _child_path(path, "x"), failures)
			_walk(quaternion.y, _child_path(path, "y"), failures)
			_walk(quaternion.z, _child_path(path, "z"), failures)
			_walk(quaternion.w, _child_path(path, "w"), failures)

		TYPE_COLOR:
			var color: Color = value
			_walk(color.r, _child_path(path, "r"), failures)
			_walk(color.g, _child_path(path, "g"), failures)
			_walk(color.b, _child_path(path, "b"), failures)
			_walk(color.a, _child_path(path, "a"), failures)

		TYPE_BASIS:
			var basis: Basis = value
			_walk(basis.x, _child_path(path, "x"), failures)
			_walk(basis.y, _child_path(path, "y"), failures)
			_walk(basis.z, _child_path(path, "z"), failures)

		TYPE_TRANSFORM3D:
			var transform: Transform3D = value
			_walk(transform.basis, _child_path(path, "basis"), failures)
			_walk(transform.origin, _child_path(path, "origin"), failures)

		TYPE_ARRAY:
			var array: Array = value
			for index in range(array.size()):
				_walk(array[index], _child_path(path, str(index)), failures)

		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			var entries: Array[Dictionary] = []
			for key in dictionary.keys():
				if not _is_stable_key(key):
					_append_failure(
						failures,
						path,
						"UNSTABLE_DICTIONARY_KEY",
						typeof(key))
					continue
				entries.append({
					"key": key,
					"sort_key": _key_text(key),
				})
			entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return String(a["sort_key"]) < String(b["sort_key"]))
			var previous_key := ""
			var have_previous := false
			for entry in entries:
				var key_text := String(entry["sort_key"])
				if have_previous and key_text == previous_key:
					_append_failure(
						failures,
						_child_path(path, key_text),
						"CANONICAL_KEY_COLLISION",
						TYPE_DICTIONARY)
					continue
				have_previous = true
				previous_key = key_text
				_walk(
					dictionary[entry["key"]],
					_child_path(path, key_text),
					failures)

		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, \
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, \
		TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			_walk(Array(value), path, failures)

		_:
			_append_failure(
				failures,
				path,
				"UNSUPPORTED_VALUE_TYPE",
				typeof(value))


static func _sanitize_walk(
		value: Variant,
		path: String,
		source_id: String,
		availability: Dictionary,
		failures: Array[Dictionary]) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return value

		TYPE_INT:
			var integer := int(value)
			if (
				integer >= MIN_EXACT_JSON_INTEGER
				and integer <= MAX_EXACT_JSON_INTEGER
			):
				return integer
			_append_sanitized_failure(
				failures,
				availability,
				path,
				"INTEGER_OUT_OF_JSON_EXACT_RANGE",
				TYPE_INT,
				source_id)
			return null

		TYPE_STRING_NAME:
			return String(value)

		TYPE_FLOAT:
			var number := float(value)
			if is_finite(number):
				return 0.0 if number == 0.0 else number
			var reason := _nonfinite_reason(number)
			_append_sanitized_failure(
				failures,
				availability,
				path,
				reason,
				TYPE_FLOAT,
				source_id)
			return null

		TYPE_VECTOR2:
			var vector: Vector2 = value
			return [
				_sanitize_walk(
					vector.x, _child_path(path, "0"), source_id,
					availability, failures),
				_sanitize_walk(
					vector.y, _child_path(path, "1"), source_id,
					availability, failures),
			]

		TYPE_VECTOR3:
			var vector: Vector3 = value
			return [
				_sanitize_walk(
					vector.x, _child_path(path, "0"), source_id,
					availability, failures),
				_sanitize_walk(
					vector.y, _child_path(path, "1"), source_id,
					availability, failures),
				_sanitize_walk(
					vector.z, _child_path(path, "2"), source_id,
					availability, failures),
			]

		TYPE_VECTOR4:
			var vector: Vector4 = value
			return [
				_sanitize_walk(
					vector.x, _child_path(path, "0"), source_id,
					availability, failures),
				_sanitize_walk(
					vector.y, _child_path(path, "1"), source_id,
					availability, failures),
				_sanitize_walk(
					vector.z, _child_path(path, "2"), source_id,
					availability, failures),
				_sanitize_walk(
					vector.w, _child_path(path, "3"), source_id,
					availability, failures),
			]

		TYPE_QUATERNION:
			var quaternion: Quaternion = value
			return [
				_sanitize_walk(
					quaternion.x, _child_path(path, "0"), source_id,
					availability, failures),
				_sanitize_walk(
					quaternion.y, _child_path(path, "1"), source_id,
					availability, failures),
				_sanitize_walk(
					quaternion.z, _child_path(path, "2"), source_id,
					availability, failures),
				_sanitize_walk(
					quaternion.w, _child_path(path, "3"), source_id,
					availability, failures),
			]

		TYPE_COLOR:
			var color: Color = value
			return [
				_sanitize_walk(
					color.r, _child_path(path, "0"), source_id,
					availability, failures),
				_sanitize_walk(
					color.g, _child_path(path, "1"), source_id,
					availability, failures),
				_sanitize_walk(
					color.b, _child_path(path, "2"), source_id,
					availability, failures),
				_sanitize_walk(
					color.a, _child_path(path, "3"), source_id,
					availability, failures),
			]

		TYPE_BASIS:
			var basis: Basis = value
			return [
				_sanitize_walk(
					basis.x, _child_path(path, "0"), source_id,
					availability, failures),
				_sanitize_walk(
					basis.y, _child_path(path, "1"), source_id,
					availability, failures),
				_sanitize_walk(
					basis.z, _child_path(path, "2"), source_id,
					availability, failures),
			]

		TYPE_TRANSFORM3D:
			var transform: Transform3D = value
			return {
				"basis": _sanitize_walk(
					transform.basis, _child_path(path, "basis"), source_id,
					availability, failures),
				"origin": _sanitize_walk(
					transform.origin, _child_path(path, "origin"), source_id,
					availability, failures),
			}

		TYPE_ARRAY:
			var source: Array = value
			var result: Array = []
			result.resize(source.size())
			for index in range(source.size()):
				result[index] = _sanitize_walk(
					source[index],
					_child_path(path, str(index)),
					source_id,
					availability,
					failures)
			return result

		TYPE_DICTIONARY:
			var source: Dictionary = value
			var entries: Array[Dictionary] = []
			for key in source.keys():
				if not _is_stable_key(key):
					_append_sanitized_failure(
						failures,
						availability,
						path,
						"UNSTABLE_DICTIONARY_KEY",
						typeof(key),
						source_id)
					continue
				entries.append({
					"key": key,
					"sort_key": _key_text(key),
				})
			entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return String(a["sort_key"]) < String(b["sort_key"]))
			var result: Dictionary = {}
			for entry in entries:
				var key_text := String(entry["sort_key"])
				var child_path := _child_path(path, key_text)
				if result.has(key_text):
					_append_sanitized_failure(
						failures,
						availability,
						child_path,
						"CANONICAL_KEY_COLLISION",
						TYPE_DICTIONARY,
						source_id)
					result[key_text] = null
					continue
				result[key_text] = _sanitize_walk(
					source[entry["key"]],
					child_path,
					source_id,
					availability,
					failures)
			return result

		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, \
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
		TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, \
		TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return _sanitize_walk(
				Array(value),
				path,
				source_id,
				availability,
				failures)

		_:
			_append_sanitized_failure(
				failures,
				availability,
				path,
				"UNSUPPORTED_VALUE_TYPE",
				typeof(value),
				source_id)
			return null


static func _append_sanitized_failure(
		failures: Array[Dictionary],
		availability: Dictionary,
		path: String,
		reason: String,
		variant_type: int,
		source_id: String) -> void:
	var failure := {
		"path": path,
		"code": "NONFINITE_FLOAT" if reason in [
			"NAN",
			"POS_INF",
			"NEG_INF",
		] else reason,
		"reason": reason,
		"variant_type": type_string(variant_type),
		"source_id": source_id,
	}
	failures.append(failure)
	availability[path] = {
		"status": "invalid",
		"reason": reason,
		"source_id": source_id,
	}


static func _nonfinite_reason(value: float) -> String:
	if is_nan(value):
		return "NAN"
	return "POS_INF" if value > 0.0 else "NEG_INF"


static func _append_failure(
		failures: Array[Dictionary],
		path: String,
		code: String,
		variant_type: int) -> void:
	failures.append({
		"path": path,
		"code": code,
		"variant_type": type_string(variant_type),
	})


static func _child_path(parent: String, segment: String) -> String:
	return "%s/%s" % [parent, _escape_pointer_segment(segment)]


static func _escape_pointer_segment(segment: String) -> String:
	return segment.replace("~", "~0").replace("/", "~1")


static func _key_text(key: Variant) -> String:
	return str(key) if typeof(key) == TYPE_INT else String(key)


static func _is_stable_key(key: Variant) -> bool:
	return typeof(key) in [
		TYPE_STRING,
		TYPE_STRING_NAME,
		TYPE_INT,
	]
