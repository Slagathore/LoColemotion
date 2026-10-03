extends SceneTree

const SchemaValidatorScript := preload("res://scripts/lab/schema_validator.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab JSON Schema negation regression ===")
	var schema := {
		"not": {
			"const": "forbidden",
		},
	}
	_check(
		SchemaValidatorScript.validate(schema, "allowed")["ok"],
		"`not` accepts a value that does not match its child schema")
	var forbidden: Dictionary = SchemaValidatorScript.validate(
		schema, "forbidden")
	_check(
		not bool(forbidden["ok"]),
		"`not` rejects a value that matches its child schema")
	_check(
		_has_code(forbidden, "NOT_FAILED"),
		"negation failure is explicit and machine-readable")

	var object_schema := {
		"type": "object",
		"properties": {
			"mode": {
				"type": "string",
			},
		},
		"not": {
			"type": "object",
			"required": ["mode"],
			"properties": {
				"mode": {
					"const": "secret_assist",
				},
			},
		},
	}
	_check(
		SchemaValidatorScript.validate(
			object_schema, {"mode": "measured"})["ok"],
		"nested negation permits an ordinary registered mode")
	_check(
		not bool(SchemaValidatorScript.validate(
			object_schema, {"mode": "secret_assist"})["ok"]),
		"nested negation cannot silently admit a forbidden assist")

	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


static func _has_code(result: Dictionary, code: String) -> bool:
	for error_value in result.get("errors", []):
		if (
			error_value is Dictionary
			and String(error_value.get("code", "")) == code
		):
			return true
	return false
