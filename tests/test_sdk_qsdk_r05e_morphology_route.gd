extends "res://tests/test_sdk_qsdk_independent_morphology_v2.gd"

## Shared R05E exact-point route and worker-side authorization interlock.
##
## The two executable specializations below this file provide either the
## single development ghost contract or the twelve-cell held-out contract.

const ExactSpecScript := preload(
	"res://scripts/lab/gait/qsdk_r05e_exact_finite_morphology_spec.gd"
)
const R05E_ATTEMPT_PATH_ENV := "SPORESPORE_QSDK_R05E_ATTEMPT"
const R05E_ATTEMPT_TOKEN_ENV := "SPORESPORE_QSDK_R05E_TOKEN"
const R05E_ATTEMPT_SCHEMA := "sporespore_qsdk_r05e_morphology_attempt_v1"
const R05D_DESIGN_SHA256 := "sha256:3b75b7609b638470ee947326f71018d082beb4a2c2909e78dae77d3b50250a6c"


func _compile_campaign_generation(generator_index: int) -> Dictionary:
	return ExactSpecScript.compile_generation(generator_index)


func _verify_campaign_generation(
	generator_index: int,
	expected_generator_receipt_sha256: String,
	expected_proportion_spec_sha256: String,
) -> Dictionary:
	return ExactSpecScript.verify_generation(
		generator_index,
		expected_generator_receipt_sha256,
		expected_proportion_spec_sha256,
	)


func _physical_authorization(
	cell: Dictionary,
	seed: int,
	authorization_preflight: bool,
) -> Dictionary:
	var attempt_path := OS.get_environment(R05E_ATTEMPT_PATH_ENV)
	var attempt_token := OS.get_environment(R05E_ATTEMPT_TOKEN_ENV)
	if attempt_path.is_empty() or attempt_token.is_empty() or not FileAccess.file_exists(attempt_path):
		return _authorization_failure("QSDK_R05E_PHYSICAL_AUTHORIZATION_REQUIRED")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(attempt_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _authorization_failure("QSDK_R05E_PHYSICAL_AUTHORIZATION_NOT_OBJECT")
	var attempt: Dictionary = parsed
	var campaign := _campaign_contract()
	if not _attempt_json_types_are_exact(attempt):
		return _authorization_failure("QSDK_R05E_PHYSICAL_AUTHORIZATION_INVALID_TYPES")
	var operation_lock: Dictionary = attempt["operation_lock"]
	var authority_path: String = attempt["execution_authority_path"]
	var authority_sha256: String = attempt["execution_authority_sha256"]
	var expected_preflight_flag := authorization_preflight
	var expected_physical_flag := not authorization_preflight
	var expected_lock_role := (
		"preflight"
		if authorization_preflight
		else (
			"physical_development"
			if String(campaign["campaign_role"]) == "development_route_ghost"
			else "physical"
		)
	)
	var exact: bool = (
		attempt["schema_version"] == R05E_ATTEMPT_SCHEMA
		and attempt["authorization_token"] == attempt_token
		and attempt["campaign_id"] == String(campaign["campaign_id"])
		and attempt["gate_id"] == String(campaign["gate_id"])
		and attempt["campaign_role"] == String(campaign["campaign_role"])
		and attempt["generator_index"] == int(cell.get("generator_index", -2))
		and attempt["morphology_id"] == String(cell.get("morphology_id", ""))
		and attempt["campaign_seed"] == seed
		and _is_lower_hex(attempt["source_commit"], 40)
		and attempt["r05d_design_sha256"] == R05D_DESIGN_SHA256
		and attempt["preregistration_sha256"]
		== "sha256:" + FileAccess.get_sha256(String(campaign["preregistration_path"])).to_lower()
		and attempt["synthetic_authorization_preflight"] == expected_preflight_flag
		and attempt["supervisor_physical_authorized"] == expected_physical_flag
		and attempt["maximum_world_attempt_count"] == (0 if authorization_preflight else 1)
		and attempt["maximum_world_build_count"] == (0 if authorization_preflight else 1)
		and attempt["world_attempt_count_before_worker"] == 0
		and attempt["world_build_count_before_worker"] == 0
		and not attempt["same_identity_rerun_permitted"]
		and not attempt["physical_acceptance_authority"]
		and operation_lock["schema_version"]
		== "sporespore_locomotion_operation_lock_receipt_v1"
		and operation_lock["acquired"]
		and operation_lock["role"] == expected_lock_role
	)
	if authorization_preflight:
		exact = exact and authority_path.is_empty() and authority_sha256.is_empty()
	else:
		exact = (
			exact
			and not authority_path.is_empty()
			and FileAccess.file_exists(authority_path)
			and _is_prefixed_sha256(authority_sha256)
			and "sha256:" + FileAccess.get_sha256(authority_path).to_lower() == authority_sha256
		)
	if not exact:
		return _authorization_failure("QSDK_R05E_PHYSICAL_AUTHORIZATION_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"required": true,
		"campaign_role": String(campaign["campaign_role"]),
		"generator_index": int(cell["generator_index"]),
		"morphology_id": String(cell["morphology_id"]),
		"campaign_seed": seed,
		"source_commit": String(attempt["source_commit"]),
		"attempt_path": attempt_path,
		"authorization_preflight": authorization_preflight,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _attempt_json_types_are_exact(attempt: Dictionary) -> bool:
	var expected_keys := [
		"schema_version",
		"authorization_token",
		"campaign_id",
		"gate_id",
		"campaign_role",
		"generator_index",
		"morphology_id",
		"campaign_seed",
		"source_commit",
		"r05d_design_sha256",
		"preregistration_sha256",
		"execution_authority_path",
		"execution_authority_sha256",
		"synthetic_authorization_preflight",
		"supervisor_physical_authorized",
		"maximum_world_attempt_count",
		"maximum_world_build_count",
		"world_attempt_count_before_worker",
		"world_build_count_before_worker",
		"same_identity_rerun_permitted",
		"operation_lock",
		"physical_acceptance_authority",
	]
	if attempt.size() != expected_keys.size():
		return false
	for key in expected_keys:
		if not attempt.has(key):
			return false
	for key in [
		"schema_version",
		"authorization_token",
		"campaign_id",
		"gate_id",
		"campaign_role",
		"morphology_id",
		"source_commit",
		"r05d_design_sha256",
		"preregistration_sha256",
		"execution_authority_path",
		"execution_authority_sha256",
	]:
		if typeof(attempt[key]) != TYPE_STRING:
			return false
	for key in [
		"generator_index",
		"campaign_seed",
		"maximum_world_attempt_count",
		"maximum_world_build_count",
		"world_attempt_count_before_worker",
		"world_build_count_before_worker",
	]:
		if (
			typeof(attempt[key]) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(attempt[key]))
			or floor(float(attempt[key])) != float(attempt[key])
		):
			return false
	for key in [
		"synthetic_authorization_preflight",
		"supervisor_physical_authorized",
		"same_identity_rerun_permitted",
		"physical_acceptance_authority",
	]:
		if typeof(attempt[key]) != TYPE_BOOL:
			return false
	if typeof(attempt["operation_lock"]) != TYPE_DICTIONARY:
		return false
	var operation_lock: Dictionary = attempt["operation_lock"]
	return (
		operation_lock.has("schema_version")
		and typeof(operation_lock["schema_version"]) == TYPE_STRING
		and operation_lock.has("acquired")
		and typeof(operation_lock["acquired"]) == TYPE_BOOL
		and operation_lock.has("role")
		and typeof(operation_lock["role"]) == TYPE_STRING
	)


func _authorization_failure(code: String) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"required": true,
		"world_build_count": 0,
		"physical_acceptance_authority": false,
	}


func _is_lower_hex(value: String, expected_length: int) -> bool:
	if value.length() != expected_length:
		return false
	for codepoint in value.to_ascii_buffer():
		var is_digit := codepoint >= 48 and codepoint <= 57
		var is_lower_hex_letter := codepoint >= 97 and codepoint <= 102
		if not is_digit and not is_lower_hex_letter:
			return false
	return true


func _is_prefixed_sha256(value: String) -> bool:
	return value.begins_with("sha256:") and _is_lower_hex(value.trim_prefix("sha256:"), 64)
