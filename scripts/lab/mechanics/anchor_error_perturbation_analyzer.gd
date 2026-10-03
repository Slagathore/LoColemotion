class_name LabAnchorErrorPerturbationAnalyzer
extends RefCounted

## L2.7 deterministic anchor-observability boundary analyzer.

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const FrozenValueScript := preload("res://scripts/lab/frozen_value.gd")

const CONFIGURATION_SCHEMA_VERSION := "anchor_error_perturbation_configuration_v1"
const RESULT_SCHEMA_VERSION := "anchor_error_perturbation_analysis_v1"
const REQUIRED_FIELDS: Array[String] = [
	"schema_version",
	"experiment_id",
	"anchor_tolerance_m",
	"perturbations_m",
	"gravity_enabled",
	"contact_enabled",
	"built_in_motor_enabled",
	"limit_enabled",
	"active_torque_enabled",
	"passive_torque_enabled",
]
const CLAIM_BOUNDARY := (
	"Exact synthetic same-epoch joint-observer anchor perturbations only; this "
	+ "establishes failure signatures and channel availability, not physical joint "
	+ "strength, load bearing, standing, bracing, recovery, gait, or walking."
)


static func build(configuration: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var keys: Array = configuration.keys()
	keys.sort()
	var expected: Array = REQUIRED_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		errors.append("ANCHOR_PERTURBATION_FIELD_SET_MISMATCH")
	if String(configuration.get("schema_version", "")) != CONFIGURATION_SCHEMA_VERSION:
		errors.append("ANCHOR_PERTURBATION_SCHEMA_UNSUPPORTED")
	if not _stable_id(String(configuration.get("experiment_id", ""))):
		errors.append("ANCHOR_PERTURBATION_EXPERIMENT_ID_INVALID")
	var tolerance := float(configuration.get("anchor_tolerance_m", NAN))
	if not is_finite(tolerance) or tolerance <= 0.0 or tolerance > 0.05:
		errors.append("ANCHOR_PERTURBATION_TOLERANCE_INVALID")
	var perturbations_value: Variant = configuration.get("perturbations_m")
	var perturbations: Array = perturbations_value if perturbations_value is Array else []
	if perturbations.size() != 4:
		errors.append("ANCHOR_PERTURBATION_GRID_SIZE_INVALID")
	else:
		var previous := -1.0
		var below_count := 0
		var above_count := 0
		for value in perturbations:
			if not _finite_number(value) or float(value) < 0.0 or float(value) <= previous:
				errors.append("ANCHOR_PERTURBATION_GRID_INVALID")
				break
			previous = float(value)
			if float(value) <= tolerance:
				below_count += 1
			else:
				above_count += 1
		if below_count < 2 or above_count < 2:
			errors.append("ANCHOR_PERTURBATION_GRID_DOES_NOT_BRACKET_TOLERANCE")
	for flag in [
		"gravity_enabled",
		"contact_enabled",
		"built_in_motor_enabled",
		"limit_enabled",
		"active_torque_enabled",
		"passive_torque_enabled",
	]:
		if configuration.get(flag) != false:
			errors.append("%s_FORBIDDEN" % flag.to_upper())
	if not errors.is_empty():
		return {
			"ok": false,
			"failure_code": "ANCHOR_PERTURBATION_CONFIGURATION_INVALID",
			"errors": errors,
		}
	var payload := configuration.duplicate(true)
	payload["expected_sample_count"] = perturbations.size()
	payload["claim_boundary"] = CLAIM_BOUNDARY
	payload["configuration_sha256"] = CanonicalJsonScript.sha256(configuration)
	return {"ok": true, "contract": FrozenValueScript.snapshot(payload)}


static func analyze(contract: Dictionary, samples: Array) -> Dictionary:
	var check := _verify_contract(contract)
	if not bool(check.get("ok", false)):
		return check
	if samples.size() != int(contract["expected_sample_count"]):
		return _failure("ANCHOR_PERTURBATION_SAMPLE_COUNT_MISMATCH")
	var tolerance := float(contract["anchor_tolerance_m"])
	var perturbations: Array = contract["perturbations_m"]
	var valid_count := 0
	var rejected_count := 0
	var largest_valid_error := 0.0
	var smallest_rejected_error := INF
	var first_rejected_index := -1
	var signatures: Array = []
	for index in samples.size():
		var value: Variant = samples[index]
		if not value is Dictionary:
			return _failure("ANCHOR_PERTURBATION_SAMPLE_INVALID")
		var sample: Dictionary = value
		if int(sample.get("index", -1)) != index:
			return _failure("ANCHOR_PERTURBATION_INDEX_MISMATCH")
		var perturbation := float(sample.get("perturbation_m", NAN))
		var predicted_error := float(sample.get("predicted_anchor_error_m", NAN))
		if (
			not is_finite(perturbation)
			or not is_finite(predicted_error)
			or absf(perturbation - float(perturbations[index])) > 1.0e-12
			or absf(predicted_error - perturbation) > 1.0e-12
		):
			return _failure("ANCHOR_PERTURBATION_TRACE_MISMATCH")
		if (
			float(sample.get("active_torque_nm", NAN)) != 0.0
			or float(sample.get("passive_torque_nm", NAN)) != 0.0
			or int(sample.get("command_count", -1)) != 0
		):
			return _failure("ANCHOR_PERTURBATION_HIDDEN_TORQUE_OR_COMMAND")
		var should_be_valid := perturbation <= tolerance
		var observation_valid := bool(sample.get("observation_valid", false))
		var geometry_available := bool(sample.get("geometry_available", false))
		var angle_available := bool(sample.get("angle_available", false))
		var rate_available := bool(sample.get("rate_available", false))
		var reasons_value: Variant = sample.get("invalid_reasons")
		if not reasons_value is Array:
			return _failure("ANCHOR_PERTURBATION_REASONS_INVALID")
		var reasons: Array = reasons_value
		var observed_error_value: Variant = sample.get("observed_anchor_error_m")
		if should_be_valid:
			if (
				not observation_valid
				or not geometry_available
				or not angle_available
				or not rate_available
				or not _finite_number(observed_error_value)
				or absf(float(observed_error_value) - perturbation) > 1.0e-9
				or reasons.has("ANCHOR_MISMATCH")
			):
				return _failure("ANCHOR_PERTURBATION_VALID_CASE_SIGNATURE_MISMATCH")
			valid_count += 1
			largest_valid_error = maxf(largest_valid_error, perturbation)
			signatures.append("valid")
		else:
			if (
				observation_valid
				or geometry_available
				or angle_available
				or rate_available
				or observed_error_value != null
				or not reasons.has("ANCHOR_MISMATCH")
				or not reasons.has("JOINT_GEOMETRY_UNAVAILABLE")
			):
				return _failure("ANCHOR_PERTURBATION_REJECTION_SIGNATURE_MISMATCH")
			rejected_count += 1
			smallest_rejected_error = minf(smallest_rejected_error, perturbation)
			if first_rejected_index < 0:
				first_rejected_index = index
			signatures.append("anchor_mismatch_fail_closed")
	var acceptance_failures: Array[String] = []
	if valid_count < 2 or rejected_count < 2:
		acceptance_failures.append("ANCHOR_PERTURBATION_BRACKETING_INCOMPLETE")
	if largest_valid_error > tolerance:
		acceptance_failures.append("ANCHOR_PERTURBATION_FALSE_ACCEPT")
	if smallest_rejected_error <= tolerance:
		acceptance_failures.append("ANCHOR_PERTURBATION_FALSE_REJECT")
	if first_rejected_index != valid_count:
		acceptance_failures.append("ANCHOR_PERTURBATION_BOUNDARY_NONMONOTONIC")
	var result := {
		"schema_version": RESULT_SCHEMA_VERSION,
		"experiment_id": contract["experiment_id"],
		"configuration_sha256": contract["configuration_sha256"],
		"anchor_tolerance_m": tolerance,
		"sample_count": samples.size(),
		"valid_count": valid_count,
		"rejected_count": rejected_count,
		"largest_valid_error_m": largest_valid_error,
		"smallest_rejected_error_m": smallest_rejected_error,
		"first_rejected_index": first_rejected_index,
		"case_signatures": signatures,
		"rejected_numeric_anchor_channel_policy": "null",
		"dependent_channel_policy": "unavailable_not_zero",
		"active_torque_nm": 0.0,
		"passive_torque_nm": 0.0,
		"command_count": 0,
		"accepted": acceptance_failures.is_empty(),
		"acceptance_failures": acceptance_failures,
		"claim_boundary": contract["claim_boundary"],
	}
	result["result_sha256"] = CanonicalJsonScript.sha256(result)
	return {"ok": true, "result": FrozenValueScript.snapshot(result)}


static func _verify_contract(contract: Dictionary) -> Dictionary:
	var configuration: Dictionary = {}
	for field in REQUIRED_FIELDS:
		if not contract.has(field):
			return _failure("ANCHOR_PERTURBATION_CONTRACT_INCOMPLETE")
		configuration[field] = contract[field]
	var rebuilt := build(configuration)
	if not bool(rebuilt.get("ok", false)):
		return _failure("ANCHOR_PERTURBATION_CONTRACT_INVALID", rebuilt)
	if (
		CanonicalJsonScript.stringify(rebuilt["contract"])
		!= CanonicalJsonScript.stringify(contract)
	):
		return _failure("ANCHOR_PERTURBATION_CONTRACT_DIGEST_MISMATCH")
	return {"ok": true}


static func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _stable_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[A-Za-z][A-Za-z0-9._-]{0,159}$")
	return expression.search(value) != null


static func _failure(code: String, details: Variant = null) -> Dictionary:
	return {"ok": false, "failure_code": code, "details": details}
