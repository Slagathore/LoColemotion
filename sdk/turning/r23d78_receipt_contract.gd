class_name R23D78ReceiptContract
extends RefCounted

const ARTIFACT_SCHEMA := "sporespore_content_addressed_artifact_receipt_v1"


static func _exact_nonnegative_integer(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number >= 0.0 and number == float(int(number))


static func validate_retention_receipt(receipt: Variant, expected: Dictionary) -> Array[String]:
	if typeof(receipt) != TYPE_DICTIONARY:
		return ["R23D78_RECEIPT_NOT_OBJECT"]
	var value: Dictionary = receipt
	var failures: Array[String] = []
	for field: String in [
		"schema_version",
		"stage_id",
		"cell_id",
		"engine_id",
		"campaign_seed",
		"profile_id",
		"host_mapping_id",
	]:
		if value.get(field) != expected.get(field):
			failures.append("R23D78_%s_MISMATCH" % field.to_upper())
	var top_level: Variant = value.get("row_count")
	var summary: Variant = value.get("trace_summary")
	var nested: Variant = summary.get("row_count") if typeof(summary) == TYPE_DICTIONARY else null
	if not _exact_nonnegative_integer(top_level):
		failures.append("R23D78_TOP_LEVEL_ROW_COUNT_NOT_INTEGER")
	elif int(top_level) != int(expected["row_count"]):
		failures.append("R23D78_TOP_LEVEL_ROW_COUNT_UNEXPECTED")
	if not _exact_nonnegative_integer(nested):
		failures.append("R23D78_NESTED_ROW_COUNT_NOT_INTEGER")
	elif int(nested) != int(expected["row_count"]):
		failures.append("R23D78_NESTED_ROW_COUNT_UNEXPECTED")
	if _exact_nonnegative_integer(top_level) and _exact_nonnegative_integer(nested):
		if int(top_level) != int(nested):
			failures.append("R23D78_ROW_COUNT_PROJECTIONS_DIVERGED")
	if not bool(value.get("retained_before_terminal_entry", false)):
		failures.append("R23D78_RETAINED_BEFORE_TERMINAL_INVALID")
	if int(value.get("world_attempt_count", -1)) != 0:
		failures.append("R23D78_WORLD_ATTEMPT_COUNT_INVALID")
	if int(value.get("world_build_count", -1)) != 0:
		failures.append("R23D78_WORLD_BUILD_COUNT_INVALID")
	if bool(value.get("physical_acceptance_authority", true)):
		failures.append("R23D78_PHYSICAL_AUTHORITY_INVALID")
	var artifact: Variant = value.get("trace_artifact")
	if typeof(artifact) != TYPE_DICTIONARY:
		failures.append("R23D78_TRACE_ARTIFACT_NOT_OBJECT")
	else:
		if String(artifact.get("schema_version", "")) != ARTIFACT_SCHEMA:
			failures.append("R23D78_TRACE_ARTIFACT_SCHEMA_MISMATCH")
		if bool(artifact.get("test_only", false)) != bool(expected["test_only"]):
			failures.append("R23D78_TRACE_ARTIFACT_TEST_ONLY_MISMATCH")
		if typeof(summary) == TYPE_DICTIONARY:
			if artifact.get("sha256") != summary.get("raw_sha256"):
				failures.append("R23D78_TRACE_ARTIFACT_SHA_MISMATCH")
			if int(artifact.get("byte_length", -1)) != int(summary.get("byte_length", -2)):
				failures.append("R23D78_TRACE_ARTIFACT_LENGTH_MISMATCH")
	return failures
