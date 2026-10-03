extends SceneTree

## Read-only command-line boundary for an independently validated run bundle.
##
## This exists so PowerShell operators never have to reimplement the GDScript
## schema, semantic-recomputation, source-state, or publication-attestation
## policy. The complete machine result is emitted as one canonical JSON line.

const BundleValidatorScript := preload(
	"res://scripts/lab/run_bundle_validator.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const EXIT_PASS := 0
const EXIT_NOT_PROMOTABLE := 2
const EXIT_INVALID := 3
const EXIT_CONFIGURATION_ERROR := 4


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed := _parse_arguments(OS.get_cmdline_user_args())
	if not bool(parsed.get("ok", false)):
		printerr(
			"BUNDLE_VALIDATION configuration_error=%s"
			% String(parsed.get("error", "unknown")))
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var arguments: Dictionary = parsed["arguments"]
	var options := {
		"allow_partial": bool(arguments["allow_partial"]),
		"attestation_requirement": (
			"required"
			if bool(arguments["require_attestation"])
			else "structural"),
	}
	var test_root := String(arguments["attestation_test_root"])
	if not test_root.is_empty():
		options["attestation_test_root"] = test_root
	var result: Dictionary = BundleValidatorScript.validate_bundle(
		String(arguments["bundle"]), options)
	print(
		"BUNDLE_VALIDATION result=%s"
		% CanonicalJsonScript.stringify(result))
	if not bool(result.get("ok", false)) \
			or not bool(result.get("can_finalize", false)):
		printerr("BUNDLE_VALIDATION verdict=invalid")
		quit(EXIT_INVALID)
		return
	if bool(arguments["require_promotion"]) \
			and not bool(result.get("can_promote", false)):
		print("BUNDLE_VALIDATION verdict=not_promotable")
		quit(EXIT_NOT_PROMOTABLE)
		return
	print(
		"BUNDLE_VALIDATION verdict=pass can_promote=%s"
		% str(bool(result.get("can_promote", false))).to_lower())
	quit(EXIT_PASS)


static func _parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var parsed := {
		"bundle": "",
		"require_attestation": false,
		"require_promotion": false,
		"allow_partial": false,
		"attestation_test_root": "",
	}
	var seen: Dictionary = {}
	var index := 0
	while index < arguments.size():
		var argument := String(arguments[index])
		if argument in [
			"--allow-partial",
			"--require-attestation",
			"--require-promotion",
		]:
			if seen.has(argument):
				return _parse_failure("duplicate argument: %s" % argument)
			seen[argument] = true
			parsed[argument.trim_prefix("--").replace("-", "_")] = true
			index += 1
			continue
		if argument in ["--bundle", "--attestation-test-root"]:
			if seen.has(argument):
				return _parse_failure("duplicate argument: %s" % argument)
			if index + 1 >= arguments.size():
				return _parse_failure("missing value for %s" % argument)
			seen[argument] = true
			var value := String(arguments[index + 1])
			if value.is_empty():
				return _parse_failure("empty value for %s" % argument)
			parsed[argument.trim_prefix("--").replace("-", "_")] = value
			index += 2
			continue
		return _parse_failure("unknown argument: %s" % argument)
	if String(parsed["bundle"]).is_empty():
		return _parse_failure("--bundle is required")
	if bool(parsed["require_promotion"]) \
			and not bool(parsed["require_attestation"]):
		return _parse_failure(
			"--require-promotion also requires --require-attestation")
	return {"ok": true, "arguments": parsed}


static func _parse_failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
