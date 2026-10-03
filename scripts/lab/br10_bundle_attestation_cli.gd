extends SceneTree

## BR10 machine boundary for the existing generic bundle-publication receipt.
##
## The capsule family has its own inner manifest and metrics schemas, but its
## outer manifest/checksums pair deliberately uses the already-audited generic
## publication domain. The final campaign report uses a distinct BR10 report
## domain and never calls this CLI.

const AttestationScript := preload("res://scripts/lab/publication_attestation.gd")
const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")

const EXIT_PASS := 0
const EXIT_NOT_PROMOTABLE := 2
const EXIT_INVALID := 3
const EXIT_CONFIGURATION_ERROR := 4


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed := parse_arguments(OS.get_cmdline_user_args())
	if not bool(parsed.get("ok", false)):
		printerr(
			(
				"BR10_BUNDLE_ATTESTATION configuration_error=%s"
				% String(parsed.get("error", "unknown"))
			)
		)
		quit(EXIT_CONFIGURATION_ERROR)
		return
	var arguments: Dictionary = parsed["arguments"]
	var mode := String(arguments["mode"])
	var bundle := String(arguments["bundle"])
	var test_root := String(arguments["attestation_test_root"])
	var result: Dictionary
	if mode == "attest":
		result = (
			AttestationScript.attest_production(bundle)
			if test_root.is_empty()
			else AttestationScript.attest_with_test_trust_root(
				bundle, test_root, String(arguments["attested_utc"])
			)
		)
	else:
		result = (
			AttestationScript.verify_production(bundle)
			if test_root.is_empty()
			else AttestationScript.verify_with_test_trust_root(bundle, test_root)
		)
	print("BR10_BUNDLE_ATTESTATION result=%s" % CanonicalJsonScript.stringify(result))
	if not bool(result.get("ok", false)):
		printerr("BR10_BUNDLE_ATTESTATION verdict=invalid")
		quit(EXIT_INVALID)
		return
	var can_promote := String(result.get("trust_mode", "")) == "production"
	if bool(arguments["require_promotion"]) and not can_promote:
		print(
			(
				"BR10_BUNDLE_ATTESTATION verdict=not_promotable mode=%s trust_mode=%s can_promote=false"
				% [mode, String(result.get("trust_mode", ""))]
			)
		)
		quit(EXIT_NOT_PROMOTABLE)
		return
	print(
		(
			"BR10_BUNDLE_ATTESTATION verdict=pass mode=%s trust_mode=%s can_promote=%s"
			% [
				mode,
				String(result.get("trust_mode", "")),
				str(can_promote).to_lower(),
			]
		)
	)
	quit(EXIT_PASS)


static func parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var parsed := {
		"mode": "",
		"bundle": "",
		"attestation_test_root": "",
		"attested_utc": "",
		"require_promotion": false,
	}
	var seen: Dictionary = {}
	var index := 0
	while index < arguments.size():
		var argument := String(arguments[index])
		if argument == "--require-promotion":
			if seen.has(argument):
				return _parse_failure("duplicate argument: %s" % argument)
			seen[argument] = true
			parsed["require_promotion"] = true
			index += 1
			continue
		if (
			argument
			in [
				"--mode",
				"--bundle",
				"--attestation-test-root",
				"--attested-utc",
			]
		):
			if seen.has(argument):
				return _parse_failure("duplicate argument: %s" % argument)
			if index + 1 >= arguments.size():
				return _parse_failure("missing value for %s" % argument)
			var value := String(arguments[index + 1])
			if value.is_empty():
				return _parse_failure("empty value for %s" % argument)
			seen[argument] = true
			parsed[argument.trim_prefix("--").replace("-", "_")] = value
			index += 2
			continue
		return _parse_failure("unknown argument: %s" % argument)
	if String(parsed["mode"]) not in ["attest", "verify"]:
		return _parse_failure("--mode must be attest or verify")
	if String(parsed["bundle"]).is_empty():
		return _parse_failure("--bundle is required")
	if (
		not String(parsed["attested_utc"]).is_empty()
		and (
			String(parsed["mode"]) != "attest" or String(parsed["attestation_test_root"]).is_empty()
		)
	):
		return _parse_failure("--attested-utc is allowed only for test-root attestation")
	return {"ok": true, "arguments": parsed}


static func _parse_failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}
