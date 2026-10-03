extends SceneTree

## Read-only production CLI for LabL0ReplicateComparator.
##
## Formal use always requires a detached production attestation. There is no
## test trust-root argument and no receipt creation path here. The
## --require-attestation flag is accepted so callers can state the formal
## policy explicitly, but production attestation is already the safe default.
##
## Exit codes:
##   0 = exact replicate match and every requested policy passed
##   2 = valid bundles diverged, or one failed the requested promotion policy
##   3 = a bundle/attestation was invalid
##   4 = CLI configuration was invalid

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const ComparatorScript := preload(
	"res://scripts/lab/l0_replicate_comparator.gd")
const PublicationAttestationScript := preload(
	"res://scripts/lab/publication_attestation.gd")

const RESULT_MARKER := "REPLICATE_COMPARISON result="
const VERDICT_MARKER := "REPLICATE_COMPARISON verdict="
const EXIT_PASS := 0
const EXIT_MISMATCH := 2
const EXIT_INVALID := 3
const EXIT_CONFIG := 4


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parsed := _parse_arguments(OS.get_cmdline_user_args())
	if not parsed["ok"]:
		_finish(
			{
				"ok": false,
				"comparator_id": ComparatorScript.COMPARATOR_ID,
				"cli_error": parsed["error"],
				"usage": (
					"--left-bundle <path> --right-bundle <path> "
					+ "[--require-attestation] [--require-promotion]"),
			},
			"invalid",
			EXIT_CONFIG)
		return

	var left_path := String(parsed["left_bundle"])
	var right_path := String(parsed["right_bundle"])
	var validator_options := {
		"attestation_requirement": "required",
	}
	var result: Dictionary = ComparatorScript.compare(
		left_path,
		right_path,
		validator_options)

	# Verify directly as well as through the validator option. This makes the
	# CLI fail closed during integration transitions and documents that the
	# formal command uses the fixed production trust root.
	var left_attestation := PublicationAttestationScript.verify_production(
		ProjectSettings.globalize_path(left_path).replace("\\", "/"))
	var right_attestation := PublicationAttestationScript.verify_production(
		ProjectSettings.globalize_path(right_path).replace("\\", "/"))
	result["cli_policy"] = {
		"attestation_requirement": "required",
		"attestation_trust_mode": "production",
		"require_promotion": bool(parsed["require_promotion"]),
	}
	result["production_attestation"] = {
		"left": left_attestation,
		"right": right_attestation,
		"pass": (
			bool(left_attestation.get("ok", false))
			and bool(right_attestation.get("ok", false))),
	}

	var validations_pass := (
		bool(result.get("left_validation", {}).get("ok", false))
		and bool(result.get("right_validation", {}).get("ok", false))
		and bool(result.get("left_validation", {}).get(
			"can_finalize", false))
		and bool(result.get("right_validation", {}).get(
			"can_finalize", false)))
	var post_validations: Dictionary = result.get(
		"post_read_validations", {})
	var post_validations_pass := (
		bool(post_validations.get("left", {}).get("ok", false))
		and bool(post_validations.get("right", {}).get("ok", false))
		and bool(post_validations.get("left", {}).get(
			"can_finalize", false))
		and bool(post_validations.get("right", {}).get(
			"can_finalize", false)))
	var witness_unchanged := not _has_mismatch_code(
		result.get("mismatches", []),
		"BUNDLE_CHANGED_DURING_COMPARISON")
	var attestations_pass := bool(
		result["production_attestation"]["pass"])
	if (
		not validations_pass
		or not post_validations_pass
		or not witness_unchanged
		or not attestations_pass
	):
		result["ok"] = false
		_finish(result, "invalid", EXIT_INVALID)
		return

	var promotion_pass := (
		bool(result["left_validation"].get("can_promote", false))
		and bool(result["right_validation"].get("can_promote", false)))
	result["cli_policy"]["promotion_pass"] = promotion_pass
	if bool(parsed["require_promotion"]) and not promotion_pass:
		result["ok"] = false
		_finish(result, "mismatch", EXIT_MISMATCH)
		return
	if not bool(result.get("ok", false)):
		_finish(result, "mismatch", EXIT_MISMATCH)
		return
	_finish(result, "pass", EXIT_PASS)


static func _parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var result := {
		"ok": false,
		"left_bundle": "",
		"right_bundle": "",
		"require_attestation": true,
		"require_promotion": false,
	}
	var index := 0
	while index < arguments.size():
		var argument := String(arguments[index])
		if argument == "--require-attestation":
			result["require_attestation"] = true
			index += 1
			continue
		if argument == "--require-promotion":
			result["require_promotion"] = true
			index += 1
			continue
		if argument.begins_with("--left-bundle="):
			if not String(result["left_bundle"]).is_empty():
				return _parse_failure("--left-bundle was supplied more than once")
			result["left_bundle"] = argument.trim_prefix("--left-bundle=")
			index += 1
			continue
		if argument.begins_with("--right-bundle="):
			if not String(result["right_bundle"]).is_empty():
				return _parse_failure("--right-bundle was supplied more than once")
			result["right_bundle"] = argument.trim_prefix("--right-bundle=")
			index += 1
			continue
		if argument in ["--left-bundle", "--right-bundle"]:
			if index + 1 >= arguments.size():
				return _parse_failure("%s requires a path" % argument)
			var value := String(arguments[index + 1]).strip_edges()
			if value.is_empty() or value.begins_with("--"):
				return _parse_failure("%s requires a non-empty path" % argument)
			var key := (
				"left_bundle"
				if argument == "--left-bundle"
				else "right_bundle")
			if not String(result[key]).is_empty():
				return _parse_failure("%s was supplied more than once" % argument)
			result[key] = value
			index += 2
			continue
		return _parse_failure("unknown argument: %s" % argument)
	if String(result["left_bundle"]).strip_edges().is_empty():
		return _parse_failure("--left-bundle is required")
	if String(result["right_bundle"]).strip_edges().is_empty():
		return _parse_failure("--right-bundle is required")
	result["ok"] = true
	return result


static func _parse_failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}


static func _has_mismatch_code(mismatches: Array, code: String) -> bool:
	for raw in mismatches:
		if typeof(raw) == TYPE_DICTIONARY \
				and String((raw as Dictionary).get("code", "")) == code:
			return true
	return false


func _finish(result: Dictionary, verdict: String, exit_code: int) -> void:
	print("%s%s" % [RESULT_MARKER, CanonicalJsonScript.stringify(result)])
	print("%s%s" % [VERDICT_MARKER, verdict])
	quit(exit_code)
