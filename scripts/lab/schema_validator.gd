class_name LabSchemaValidator
extends RefCounted

## Deliberately small JSON Schema 2020-12 evaluator for lab-owned schemas.
##
## Supporting a declared subset here keeps validation available in headless
## Godot without a third-party dependency. Unsupported schema keywords are
## rejected when a schema is loaded, so they can never be silently ignored.

const SCHEMA_ROOT := "res://data/lab/schemas"
const SUPPORTED_KEYWORDS: Array[String] = [
	"$schema",
	"$id",
	"$defs",
	"$ref",
	"title",
	"description",
	"type",
	"required",
	"properties",
	"additionalProperties",
	"items",
	"minItems",
	"maxItems",
	"uniqueItems",
	"minProperties",
	"maxProperties",
	"enum",
	"const",
	"minimum",
	"maximum",
	"exclusiveMinimum",
	"exclusiveMaximum",
	"minLength",
	"maxLength",
	"pattern",
	"format",
	"allOf",
	"anyOf",
	"oneOf",
	"not",
]


static func validate_file(schema_path: String, value: Variant) -> Dictionary:
	var loaded := load_schema(schema_path)
	if not loaded["ok"]:
		return loaded
	var unsupported: Array = []
	_find_unsupported_keywords(loaded["schema"], "#", unsupported)
	if not unsupported.is_empty():
		return {
			"ok": false,
			"errors": unsupported,
			"schema_path": schema_path,
		}
	var result := validate(loaded["schema"], value)
	result["schema_path"] = schema_path
	return result


static func validate_named(schema_file: String, value: Variant) -> Dictionary:
	if schema_file.contains("/") or schema_file.contains("\\"):
		return _failure("/", "SCHEMA_PATH_INVALID", "Named schemas cannot contain a path separator.")
	var normalized := schema_file
	if not normalized.ends_with(".schema.json"):
		normalized += ".schema.json"
	return validate_file(SCHEMA_ROOT.path_join(normalized), value)


static func load_schema(schema_path: String) -> Dictionary:
	if not FileAccess.file_exists(schema_path):
		return _failure("/", "SCHEMA_FILE_MISSING", "Schema file does not exist: %s" % schema_path)
	var file := FileAccess.open(schema_path, FileAccess.READ)
	if file == null:
		return _failure("/", "SCHEMA_OPEN_FAILED", "Could not open schema: %s" % schema_path)
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		return _failure(
			"/",
			"SCHEMA_JSON_INVALID",
			"Schema JSON parse failed at line %d: %s" % [
				parser.get_error_line(),
				parser.get_error_message(),
			])
	if typeof(parser.data) != TYPE_DICTIONARY:
		return _failure("/", "SCHEMA_ROOT_INVALID", "Schema root must be an object.")
	return {"ok": true, "errors": [], "schema": parser.data}


static func validate(schema: Dictionary, value: Variant) -> Dictionary:
	var errors: Array = []
	_validate_node(schema, schema, value, "", errors)
	if errors.is_empty():
		_validate_lab_semantics(schema, value, errors)
	return {"ok": errors.is_empty(), "errors": errors}


static func format_errors(result: Dictionary) -> String:
	var lines: Array[String] = []
	for error_value in result.get("errors", []):
		var error: Dictionary = error_value
		lines.append("%s %s: %s" % [
			error.get("path", "/"),
			error.get("code", "SCHEMA_INVALID"),
			error.get("message", "validation failed"),
		])
	return "\n".join(lines)


static func _validate_node(
		root_schema: Dictionary,
		schema_value: Variant,
		value: Variant,
		path: String,
		errors: Array) -> void:
	if typeof(schema_value) == TYPE_BOOL:
		if not schema_value:
			_add_error(errors, path, "FALSE_SCHEMA", "Value is rejected by a false schema.")
		return
	if typeof(schema_value) != TYPE_DICTIONARY:
		_add_error(errors, path, "SCHEMA_NODE_INVALID", "Schema node must be an object or boolean.")
		return
	var schema: Dictionary = schema_value

	if schema.has("$ref"):
		var resolved := _resolve_local_ref(root_schema, String(schema["$ref"]))
		if not resolved["ok"]:
			_add_error(errors, path, "REF_UNRESOLVED", resolved["message"])
			return
		_validate_node(root_schema, resolved["schema"], value, path, errors)
		return

	for child_schema in schema.get("allOf", []):
		_validate_node(root_schema, child_schema, value, path, errors)

	if schema.has("anyOf"):
		var any_valid := false
		for child_schema in schema["anyOf"]:
			var child_errors: Array = []
			_validate_node(root_schema, child_schema, value, path, child_errors)
			if child_errors.is_empty():
				any_valid = true
				break
		if not any_valid:
			_add_error(errors, path, "ANY_OF_FAILED", "Value did not match any allowed schema.")

	if schema.has("oneOf"):
		var match_count := 0
		for child_schema in schema["oneOf"]:
			var child_errors: Array = []
			_validate_node(root_schema, child_schema, value, path, child_errors)
			if child_errors.is_empty():
				match_count += 1
		if match_count != 1:
			_add_error(
				errors,
				path,
				"ONE_OF_FAILED",
				"Value matched %d schemas; exactly one is required." % match_count)

	if schema.has("not"):
		var not_errors: Array = []
		_validate_node(root_schema, schema["not"], value, path, not_errors)
		if not_errors.is_empty():
			_add_error(errors, path, "NOT_FAILED", "Value matched a forbidden schema.")

	if schema.has("type") and not _matches_type(value, schema["type"]):
		_add_error(
			errors,
			path,
			"TYPE_MISMATCH",
			"Expected %s, received %s." % [
				JSON.stringify(schema["type"]),
				type_string(typeof(value)),
			])
		return

	if schema.has("const") and value != schema["const"]:
		_add_error(errors, path, "CONST_MISMATCH", "Value does not match the required constant.")
	if schema.has("enum") and not _array_contains_deep(schema["enum"], value):
		_add_error(errors, path, "ENUM_MISMATCH", "Value is not in the allowed registry.")

	if typeof(value) == TYPE_DICTIONARY:
		_validate_object(root_schema, schema, value, path, errors)
	elif typeof(value) == TYPE_ARRAY:
		_validate_array(root_schema, schema, value, path, errors)
	elif typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		_validate_string(schema, String(value), path, errors)
	elif _is_number(value):
		_validate_number(schema, float(value), path, errors)


static func _validate_object(
		root_schema: Dictionary,
		schema: Dictionary,
		value: Dictionary,
		path: String,
		errors: Array) -> void:
	for required_value in schema.get("required", []):
		var required_key := String(required_value)
		if not value.has(required_key):
			_add_error(
				errors,
				_join_pointer(path, required_key),
				"REQUIRED_MISSING",
				"Required property is missing.")

	var property_count := value.size()
	if schema.has("minProperties") and property_count < int(schema["minProperties"]):
		_add_error(errors, path, "MIN_PROPERTIES", "Object has too few properties.")
	if schema.has("maxProperties") and property_count > int(schema["maxProperties"]):
		_add_error(errors, path, "MAX_PROPERTIES", "Object has too many properties.")

	var properties: Dictionary = schema.get("properties", {})
	var additional: Variant = schema.get("additionalProperties", true)
	var keys := value.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for key_value in keys:
		if typeof(key_value) != TYPE_STRING and typeof(key_value) != TYPE_STRING_NAME:
			_add_error(errors, path, "OBJECT_KEY_INVALID", "JSON object keys must be strings.")
			continue
		var key := String(key_value)
		var child_path := _join_pointer(path, key)
		if properties.has(key):
			_validate_node(root_schema, properties[key], value[key_value], child_path, errors)
		elif typeof(additional) == TYPE_BOOL:
			if not additional:
				_add_error(errors, child_path, "UNKNOWN_PROPERTY", "Unknown property is forbidden.")
		else:
			_validate_node(root_schema, additional, value[key_value], child_path, errors)


static func _validate_array(
		root_schema: Dictionary,
		schema: Dictionary,
		value: Array,
		path: String,
		errors: Array) -> void:
	if schema.has("minItems") and value.size() < int(schema["minItems"]):
		_add_error(errors, path, "MIN_ITEMS", "Array has too few items.")
	if schema.has("maxItems") and value.size() > int(schema["maxItems"]):
		_add_error(errors, path, "MAX_ITEMS", "Array has too many items.")
	if schema.get("uniqueItems", false):
		for i in value.size():
			for j in range(i + 1, value.size()):
				if value[i] == value[j]:
					_add_error(errors, _join_pointer(path, str(j)), "ITEM_NOT_UNIQUE", "Array item is duplicated.")
	if schema.has("items"):
		for index in value.size():
			_validate_node(
				root_schema,
				schema["items"],
				value[index],
				_join_pointer(path, str(index)),
				errors)


static func _validate_string(schema: Dictionary, value: String, path: String, errors: Array) -> void:
	if schema.has("minLength") and value.length() < int(schema["minLength"]):
		_add_error(errors, path, "MIN_LENGTH", "String is shorter than allowed.")
	if schema.has("maxLength") and value.length() > int(schema["maxLength"]):
		_add_error(errors, path, "MAX_LENGTH", "String is longer than allowed.")
	if schema.has("pattern"):
		var regex := RegEx.new()
		var compile_error := regex.compile(String(schema["pattern"]))
		if compile_error != OK:
			_add_error(errors, path, "SCHEMA_PATTERN_INVALID", "Schema regular expression is invalid.")
		elif regex.search(value) == null:
			_add_error(errors, path, "PATTERN_MISMATCH", "String does not match the required pattern.")
	if schema.get("format", "") == "date-time":
		var date_regex := RegEx.new()
		date_regex.compile(
			"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?Z$")
		if date_regex.search(value) == null:
			_add_error(errors, path, "FORMAT_DATE_TIME", "Expected a UTC RFC 3339 date-time.")


static func _validate_number(schema: Dictionary, value: float, path: String, errors: Array) -> void:
	if not is_finite(value):
		_add_error(errors, path, "NUMBER_NONFINITE", "JSON evidence cannot contain NaN or infinity.")
		return
	if schema.has("minimum") and value < float(schema["minimum"]):
		_add_error(errors, path, "MINIMUM", "Number is below the inclusive minimum.")
	if schema.has("maximum") and value > float(schema["maximum"]):
		_add_error(errors, path, "MAXIMUM", "Number is above the inclusive maximum.")
	if schema.has("exclusiveMinimum") and value <= float(schema["exclusiveMinimum"]):
		_add_error(errors, path, "EXCLUSIVE_MINIMUM", "Number is below the exclusive minimum.")
	if schema.has("exclusiveMaximum") and value >= float(schema["exclusiveMaximum"]):
		_add_error(errors, path, "EXCLUSIVE_MAXIMUM", "Number is above the exclusive maximum.")


static func _matches_type(value: Variant, expected: Variant) -> bool:
	if typeof(expected) == TYPE_ARRAY:
		for candidate in expected:
			if _matches_type(value, candidate):
				return true
		return false
	var name := String(expected)
	match name:
		"null":
			return typeof(value) == TYPE_NIL
		"boolean":
			return typeof(value) == TYPE_BOOL
		"object":
			return typeof(value) == TYPE_DICTIONARY
		"array":
			return typeof(value) == TYPE_ARRAY
		"string":
			return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME
		"number":
			return _is_number(value) and is_finite(float(value))
		"integer":
			if typeof(value) == TYPE_INT:
				return true
			return typeof(value) == TYPE_FLOAT and is_finite(value) and floor(value) == value
		_:
			return false


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _array_contains_deep(values: Array, needle: Variant) -> bool:
	for value in values:
		if value == needle:
			return true
	return false


static func _resolve_local_ref(root_schema: Dictionary, reference: String) -> Dictionary:
	if not reference.begins_with("#/"):
		return {"ok": false, "message": "Only local JSON Pointer references are supported: %s" % reference}
	var current: Variant = root_schema
	for encoded_segment in reference.substr(2).split("/"):
		var segment := String(encoded_segment).replace("~1", "/").replace("~0", "~")
		if typeof(current) != TYPE_DICTIONARY or not current.has(segment):
			return {"ok": false, "message": "Schema reference does not resolve: %s" % reference}
		current = current[segment]
	return {"ok": true, "schema": current}


static func _find_unsupported_keywords(value: Variant, path: String, errors: Array) -> void:
	if typeof(value) == TYPE_ARRAY:
		for index in value.size():
			_find_unsupported_keywords(value[index], "%s/%d" % [path, index], errors)
		return
	if typeof(value) != TYPE_DICTIONARY:
		return
	var dictionary: Dictionary = value
	for key_value in dictionary:
		var key := String(key_value)
		var child_path := "%s/%s" % [path, key]
		var is_property_name := path.ends_with("/properties") or path.ends_with("/$defs")
		if not is_property_name and not key in SUPPORTED_KEYWORDS:
			_add_error(
				errors,
				child_path,
				"UNSUPPORTED_SCHEMA_KEYWORD",
				"Validator does not implement this schema keyword.")
		_find_unsupported_keywords(dictionary[key_value], child_path, errors)


static func _validate_lab_semantics(schema: Dictionary, value: Variant, errors: Array) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	var schema_id := String(schema.get("$id", ""))
	if schema_id.ends_with("/frame_v1.schema.json"):
		_validate_availability(value, errors)
		_validate_frame_coherence(value, errors)


static func _validate_availability(frame: Dictionary, errors: Array) -> void:
	var availability: Dictionary = frame.get("availability", {})
	for pointer_value in availability:
		var pointer := String(pointer_value)
		if not pointer.begins_with("/"):
			continue
		if typeof(availability[pointer_value]) != TYPE_DICTIONARY:
			continue
		var descriptor: Dictionary = availability[pointer_value]
		var status := String(descriptor.get("status", ""))
		if status != "unavailable" and status != "invalid":
			continue
		var resolved := _resolve_data_pointer(frame, pointer)
		if resolved["found"] and resolved["value"] != null:
			_add_error(
				errors,
				"/availability/%s" % _escape_pointer(pointer),
				"UNAVAILABLE_HAS_VALUE",
				"Unavailable or invalid data must be null, never a numeric placeholder.")


static func _validate_frame_coherence(frame: Dictionary, errors: Array) -> void:
	if typeof(frame.get("bodies")) != TYPE_DICTIONARY \
			or typeof(frame.get("contacts")) != TYPE_ARRAY \
			or typeof(frame.get("availability")) != TYPE_DICTIONARY:
		return
	var bodies: Dictionary = frame["bodies"]
	var contacts: Array = frame["contacts"]
	var availability: Dictionary = frame["availability"]
	if int(availability.get("captured_body_count", -1)) != bodies.size():
		_add_error(
			errors,
			"/availability/captured_body_count",
			"FRAME_COHERENCE",
			"captured_body_count must equal the body map size.")
	if int(availability.get("contact_count", -1)) != contacts.size():
		_add_error(
			errors,
			"/availability/contact_count",
			"FRAME_COHERENCE",
			"contact_count must equal the contacts array size.")
	if typeof(availability.get("required_body_ids")) == TYPE_ARRAY:
		for required_id_value in availability["required_body_ids"]:
			var required_id := String(required_id_value)
			if not bodies.has(required_id):
				_add_error(
					errors,
					"/availability/required_body_ids",
					"FRAME_COHERENCE",
					"Required body is absent from the same sealed frame: %s" % required_id)
	var frame_step := int(frame.get("physics_step_id", -1))
	var frame_epoch := int(frame.get("capture_epoch", -1))
	var frame_phase := String(frame.get("sample_phase", ""))
	for body_key_value in bodies:
		if typeof(bodies[body_key_value]) != TYPE_DICTIONARY:
			continue
		var body_key := String(body_key_value)
		var body: Dictionary = bodies[body_key_value]
		if String(body.get("body_id", "")) != body_key \
				or int(body.get("physics_step_id", -2)) != frame_step \
				or int(body.get("capture_epoch", -2)) != frame_epoch \
				or String(body.get("sample_phase", "")) != frame_phase:
			_add_error(
				errors,
				"/bodies/%s" % _escape_pointer(body_key),
				"FRAME_COHERENCE",
				"Body identity, step, epoch, and phase must match its containing frame.")
	for contact_index in contacts.size():
		if typeof(contacts[contact_index]) != TYPE_DICTIONARY:
			continue
		var contact: Dictionary = contacts[contact_index]
		if int(contact.get("physics_step_id", -2)) != frame_step \
				or int(contact.get("capture_epoch", -2)) != frame_epoch \
				or String(contact.get("sample_phase", "")) != frame_phase:
			_add_error(
				errors,
				"/contacts/%d" % contact_index,
				"FRAME_COHERENCE",
				"Contact step, epoch, and phase must match its containing frame.")
	if bool(frame.get("finite", false)):
		var invalid_reasons: Variant = availability.get("invalid_reasons", [])
		if typeof(invalid_reasons) == TYPE_ARRAY and not invalid_reasons.is_empty():
			_add_error(
				errors,
				"/finite",
				"FRAME_COHERENCE",
				"A finite frame cannot retain invalid_reasons.")
		for body_value in bodies.values():
			if typeof(body_value) == TYPE_DICTIONARY and not bool(body_value.get("finite", false)):
				_add_error(
					errors,
					"/finite",
					"FRAME_COHERENCE",
					"A finite frame cannot contain a non-finite body sample.")
		for contact_value in contacts:
			if typeof(contact_value) == TYPE_DICTIONARY and not bool(contact_value.get("finite", false)):
				_add_error(
					errors,
					"/finite",
					"FRAME_COHERENCE",
					"A finite frame cannot contain a non-finite contact sample.")


static func _resolve_data_pointer(root: Variant, pointer: String) -> Dictionary:
	if pointer == "":
		return {"found": true, "value": root}
	if not pointer.begins_with("/"):
		return {"found": false, "value": null}
	var current: Variant = root
	for encoded_segment in pointer.substr(1).split("/"):
		var segment := String(encoded_segment).replace("~1", "/").replace("~0", "~")
		if typeof(current) == TYPE_DICTIONARY:
			if not current.has(segment):
				return {"found": false, "value": null}
			current = current[segment]
		elif typeof(current) == TYPE_ARRAY and segment.is_valid_int():
			var index := int(segment)
			if index < 0 or index >= current.size():
				return {"found": false, "value": null}
			current = current[index]
		else:
			return {"found": false, "value": null}
	return {"found": true, "value": current}


static func _join_pointer(parent: String, segment: String) -> String:
	return "%s/%s" % [parent, _escape_pointer(segment)]


static func _escape_pointer(segment: String) -> String:
	return segment.replace("~", "~0").replace("/", "~1")


static func _add_error(errors: Array, path: String, code: String, message: String) -> void:
	errors.append({
		"path": path if not path.is_empty() else "/",
		"code": code,
		"message": message,
	})


static func _failure(path: String, code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"errors": [{"path": path, "code": code, "message": message}],
	}
