extends SceneTree

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FiniteSanitizerScript := preload("res://scripts/lab/finite_sanitizer.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab canonical JSON tests ===")
	_test_recursive_key_order_is_canonical()
	_test_math_values_and_float_policy()
	_test_bytes_and_hash_identity()
	_test_hash_survives_json_number_type_erasure()
	_test_out_of_range_integer_is_caught_before_encoding()
	_test_nonfinite_paths_are_inspectable()
	_test_terminal_sanitization_never_serializes_bad_values()
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _test_recursive_key_order_is_canonical() -> void:
	print("- recursively canonicalizes dictionary insertion order")
	var first := {
		"z": 3,
		"nested": {
			"b": 2,
			"a": 1,
		},
		"a": 0,
	}
	var second: Dictionary = {}
	second["a"] = 0
	second["nested"] = {}
	second["nested"]["a"] = 1
	second["nested"]["b"] = 2
	second["z"] = 3
	var first_text := CanonicalJsonScript.stringify(first)
	var second_text := CanonicalJsonScript.stringify(second)
	_check(first_text == second_text, "insertion order cannot change canonical bytes")
	_check(
		first_text == "{\"a\":0,\"nested\":{\"a\":1,\"b\":2},\"z\":3}",
		"canonical object keys are lexical at every depth")


func _test_math_values_and_float_policy() -> void:
	print("- normalizes math values and signed zero")
	var negative_zero := -0.0
	var with_negative_zero := {
		"position": Vector3(1.25, negative_zero, -2.5),
		"transform": Transform3D(Basis.IDENTITY, Vector3(3.0, 4.0, 5.0)),
	}
	var with_positive_zero := {
		"position": Vector3(1.25, 0.0, -2.5),
		"transform": Transform3D(Basis.IDENTITY, Vector3(3.0, 4.0, 5.0)),
	}
	var text := CanonicalJsonScript.stringify(with_negative_zero)
	var parsed = JSON.parse_string(text)
	_check(text == CanonicalJsonScript.stringify(with_positive_zero),
		"negative and positive zero have one canonical representation")
	_check(parsed is Dictionary and parsed["position"].size() == 3,
		"Vector3 becomes a three-component JSON array")
	_check(
		parsed["transform"].has("basis")
			and parsed["transform"].has("origin"),
		"Transform3D records basis and origin explicitly")


func _test_bytes_and_hash_identity() -> void:
	print("- hashes exactly the emitted UTF-8 bytes")
	var value := {"experiment": "L0", "seed": 42, "dt_s": 1.0 / 60.0}
	var text := CanonicalJsonScript.stringify(value)
	var bytes := CanonicalJsonScript.encode(value)
	var digest := CanonicalJsonScript.sha256(value)
	_check(bytes == text.to_utf8_buffer(), "encode returns canonical UTF-8 bytes")
	_check(
		digest == "sha256:%s" % text.sha256_text(),
		"sha256 identity is computed from canonical text")
	_check(
		digest.length() == 71 and digest.begins_with("sha256:"),
		"digest uses the manifest sha256:<hex> format")
	_check(
		digest != CanonicalJsonScript.sha256({"experiment": "L0", "seed": 43, "dt_s": 1.0 / 60.0}),
		"a scientific value change changes the digest")


func _test_hash_survives_json_number_type_erasure() -> void:
	print("- preserves record hash across JSON parse number-type erasure")
	var original := {
		"integer": 7,
		"integral_float": 7.0,
		"negative_zero": -0.0,
		"fraction": 1.0 / 3.0,
		"tiny_nonzero": 9.689124226570129e-20,
		"large_fraction": 1234567890123.25,
		"huge_nonintegral": 123456789012345.5,
		"format_boundaries": [
			0.0000009999999999999999,
			0.000001000000000000001,
			99999999999999.9,
			100000000000000.1,
		],
		"position_m": Vector3(2.0, -3.5, 0.0),
		"transform": Transform3D(
			Basis.from_euler(Vector3(0.0, 0.25, 0.0)),
			Vector3(1.0, 2.5, -4.0)),
	}
	var canonical_text := CanonicalJsonScript.stringify(original)
	var parsed: Variant = JSON.parse_string(canonical_text)
	var reparsed_text := CanonicalJsonScript.stringify(parsed)
	_check(parsed != null, "mixed numeric canonical JSON parses successfully")
	if (
		float(parsed["tiny_nonzero"]) == 0.0
		or not is_equal_approx(
			float(parsed["large_fraction"]),
			1234567890123.25)
	):
		printerr(
			"    magnitudes tiny=",
			parsed["tiny_nonzero"],
			" large=",
			parsed["large_fraction"])
	_check(
		float(parsed["tiny_nonzero"]) != 0.0
			and is_equal_approx(
				float(parsed["large_fraction"]),
				1234567890123.25)
			and is_equal_approx(
				float(parsed["huge_nonintegral"]),
				123456789012345.5),
		"normalization retains tiny and large nonintegral magnitudes")
	if canonical_text != reparsed_text:
		printerr("    before: ", canonical_text)
		printerr("    after:  ", reparsed_text)
	_check(
		CanonicalJsonScript.sha256(original)
			== CanonicalJsonScript.sha256(parsed),
		"record hash is identical before write and after JSON parse")
	_check(
		CanonicalJsonScript.stringify({"value": 9})
			== CanonicalJsonScript.stringify({"value": 9.0}),
		"exact integral floats and ints share one canonical representation")
	_check(
		CanonicalJsonScript.stringify({"value": -0.0})
			== CanonicalJsonScript.stringify({"value": 0}),
		"signed zero canonicalizes identically to integer zero")


func _test_out_of_range_integer_is_caught_before_encoding() -> void:
	print("- catches integers that JSON cannot round-trip exactly")
	var value := {"unsafe_counter": 9007199254740992}
	var inspection := FiniteSanitizerScript.inspect(value)
	var terminal := FiniteSanitizerScript.sanitize(value, "counter")
	_check(not bool(inspection["ok"]),
		"pre-serialization inspection rejects an inexact JSON integer")
	_check(
		inspection["failures"][0]["code"]
			== "INTEGER_OUT_OF_JSON_EXACT_RANGE",
		"integer-range failure has a stable code")
	_check(
		terminal["value"]["unsafe_counter"] == null
			and terminal["availability"]["/unsafe_counter"]["reason"]
				== "INTEGER_OUT_OF_JSON_EXACT_RANGE",
		"terminal evidence nulls the unsafe integer and records its reason")


func _test_nonfinite_paths_are_inspectable() -> void:
	print("- reports invalid leaf paths without serializing NaN/Inf")
	var report := FiniteSanitizerScript.inspect({
		"frames": [
			{"velocity": Vector3.ZERO},
			{"velocity": Vector3(0.0, INF, 0.0)},
		],
	})
	var failures: Array = report["failures"]
	_check(not bool(report["ok"]) and failures.size() == 1,
		"one non-finite component produces one deterministic failure")
	_check(
		String(failures[0]["path"]) == "/frames/1/velocity/y",
		"failure path identifies the exact vector component")
	_check(
		String(failures[0]["code"]) == "NONFINITE_FLOAT",
		"failure code distinguishes non-finite data")


func _test_terminal_sanitization_never_serializes_bad_values() -> void:
	print("- terminal sanitizer replaces bad leaves before canonical encoding")
	var report := FiniteSanitizerScript.sanitize({
		"scalar": NAN,
		"velocity": Vector3(-INF, 2.0, INF),
	}, "observer.root")
	var sanitized: Dictionary = report["value"]
	var text := CanonicalJsonScript.stringify(sanitized)
	_check(not bool(report["ok"]) and report["failures"].size() == 3,
		"sanitizer reports every non-finite component")
	_check(
		sanitized["scalar"] == null
			and sanitized["velocity"][0] == null
			and sanitized["velocity"][2] == null,
		"raw NaN and infinities are replaced by null")
	_check(
		report["availability"]["/scalar"]["reason"] == "NAN"
			and report["availability"]["/velocity/0"]["reason"] == "NEG_INF"
			and report["availability"]["/velocity/2"]["reason"] == "POS_INF",
		"availability preserves exact reason and JSON-pointer location")
	_check(
		not text.contains("nan") and not text.contains("inf"),
		"canonical terminal evidence contains no non-finite token")
