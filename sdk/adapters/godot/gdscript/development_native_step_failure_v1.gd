extends RefCounted
# gdlint: disable=max-line-length

## Failure-only evidence. This module never returns an actuation value, calls a
## controller, applies a motor, advances memory, or reclassifies a physical run.
const CONTRACT_PATH := "res://sdk/development/recovery_native_step_failure_contract_v1.json"
static var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))

static func bytes_v1(raw: String) -> Dictionary:
	return {"utf8_text": raw, "utf8_byte_length": raw.to_utf8_buffer().size(), "raw_sha256": "sha256:" + raw.sha256_text()}

static func _dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

static func _sha256(value: Variant) -> bool:
	if not value is String or value.length() != 71 or not value.begins_with("sha256:"):
		return false
	for index in range(7, 71):
		if "0123456789abcdef".find(value.substr(index, 1)) < 0:
			return false
	return true

static func same_json_v1(left: Variant, right: Variant) -> bool:
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size():
			return false
		for key in left:
			if not right.has(key) or not same_json_v1(left[key], right[key]):
				return false
		return true
	if left is Array and right is Array:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not same_json_v1(left[index], right[index]):
				return false
		return true
	if typeof(left) != typeof(right):
		if not (typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]):
			return false
		if abs(left) > 9007199254740991 or abs(right) > 9007199254740991:
			return false
	return left == right

static func capture_v1(sdk: Object, request_raw: String, response_raw: String,
	initial_verification_raw: String, policy_id: String, normal_receipt_schema: String,
	semantic_step: int, compiled_morphology: Dictionary) -> Dictionary:
	# Copy exact strings first. Never replace malformed output with a projection.
	var record := {"schema_version": contract.failure_record_schema,
		"ledger_scope": contract.ledger_scope.duplicate(true),
		"expected_policy_id": policy_id, "expected_normal_receipt_schema": normal_receipt_schema,
		"compiled_morphology_spec_sha256": compiled_morphology.get("morphology_spec_sha256", ""),
		"semantic_step": semantic_step,
		"request": bytes_v1(request_raw), "response": bytes_v1(response_raw),
		"initial_transport_verification": bytes_v1(initial_verification_raw),
		"classification": contract.invalid_classification,
		"verified_zero_actuation_refusal": false,
		"reported_native_controller_error": "", "reported_native_failure_codes": [],
		"refusal_transport_verification": {}, "checks": {},
		"controller_reinvoked": false, "adapter_clock_advanced": false,
		"adapter_memory_advanced": false, "motor_application_permitted": false,
		"complete_route_proven": false, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
	if sdk != null:
		var request := _dictionary(sdk.decode_exact_json_v1(request_raw))
		var envelope := _dictionary(sdk.decode_exact_json_v1(response_raw))
		var output := _dictionary(envelope.get("value"))
		var actuation := _dictionary(output.get("actuation"))
		var receipt := _dictionary(actuation.get("receipt"))
		var state := _dictionary(request.get("state"))
		var command := _dictionary(request.get("command"))
		var verification := _dictionary(JSON.parse_string(sdk.balanced_wave_native_step_transport_verification_json(
			response_raw, policy_id, contract.generic_controller_receipt_schema, semantic_step)))
		var verified := _dictionary(verification.get("value"))
		record.refusal_transport_verification = verification
		var error_value: Variant = receipt.get("controller_error")
		var codes_value: Variant = actuation.get("failure_codes")
		var consistent_error: bool = error_value is String and not error_value.is_empty() and codes_value is Array and not codes_value.is_empty()
		if consistent_error:
			for code in codes_value:
				consistent_error = consistent_error and code is String and not String(code).is_empty()
			consistent_error = consistent_error and String(error_value).begins_with(String(codes_value[0]) + ":")
		if error_value is String:
			record.reported_native_controller_error = error_value
		if codes_value is Array:
			record.reported_native_failure_codes = codes_value.duplicate(true)
		var commands_value: Variant = actuation.get("ordered_commands")
		var ids_value: Variant = compiled_morphology.get("ordered_actuator_ids")
		var zero_commands: bool = commands_value is Array and ids_value is Array and not ids_value.is_empty() and commands_value.size() == ids_value.size()
		if zero_commands:
			for index in range(ids_value.size()):
				var motor := _dictionary(commands_value[index])
				zero_commands = zero_commands and motor.get("actuator_id") == ids_value[index] and motor.get("mode") == "position_velocity" and motor.get("valid_through_step") == semantic_step
				for field in ["target_velocity_rad_s", "residual_contribution_rad_s", "safety_contribution_rad_s"]:
					var velocity: Variant = motor.get(field)
					zero_commands = zero_commands and typeof(velocity) in [TYPE_INT, TYPE_FLOAT] and velocity == 0
		var checks := {
			"native_receipt_and_raw_response_verified": verification.get("ok") == true and verified.get("ok") == true and verified.get("policy_id") == policy_id and verified.get("semantic_step") == semantic_step and verified.get("raw_native_response_sha256") == record.response.raw_sha256 and verified.get("raw_native_response_byte_length") == record.response.utf8_byte_length,
			"output_schemas_exact": output.get("schema_version") == "sporespore_balanced_wave_runtime_v1" and actuation.get("schema_version") == "sporespore_actuation_frame_v1",
			"request_step_and_command_bound": request.get("schema_version") in ["sporespore_balanced_wave_policy_session_step_request_v1", "sporespore_balanced_wave_policy_session_step_request_v2", "sporespore_balanced_wave_policy_session_step_request_v3"] and state.get("semantic_step") == semantic_step and command.get("command_id") is String and not String(command.get("command_id")).is_empty() and receipt.get("command_id") == command.get("command_id") and command.get("valid_from_step") == semantic_step and command.get("valid_through_step") == semantic_step,
			"compiled_morphology_bound": _sha256(compiled_morphology.get("morphology_spec_sha256")) and receipt.get("morphology_spec_sha256") == compiled_morphology.get("morphology_spec_sha256"),
			"adapter_capability_bound": _sha256(state.get("adapter_capability_sha256")) and receipt.get("adapter_capability_sha256") == state.get("adapter_capability_sha256"),
			"explicit_safe_refusal": actuation.get("safe_no_actuation") is bool and actuation.get("safe_no_actuation") == true and consistent_error,
			"ordered_compiled_commands_zero": zero_commands,
			"incoming_memory_unchanged": request.get("memory") is Dictionary and output.get("next_memory") is Dictionary and same_json_v1(request.memory, output.next_memory)}
		record.checks = checks
		if not checks.values().has(false):
			record.classification = contract.verified_refusal_classification
			record.verified_zero_actuation_refusal = true
	return {"ok": false,
		"failure_code": contract.verified_refusal_failure_code if record.verified_zero_actuation_refusal else contract.invalid_failure_code,
		"detail": record.reported_native_controller_error if record.verified_zero_actuation_refusal else "Native failure retained; refusal invariants did not all verify.",
		"development_native_step_failure": record,
		"native_step_transport_verification": _dictionary(JSON.parse_string(initial_verification_raw))}

static func retained_valid_v1(sdk: Object, record: Dictionary, policy_id: String,
	normal_receipt_schema: String, semantic_step: int, compiled_morphology: Dictionary) -> bool:
	for field in ["request", "response", "initial_transport_verification"]:
		var binding := _dictionary(record.get(field))
		if not binding.get("utf8_text") is String or not same_json_v1(binding, bytes_v1(binding.utf8_text)):
			return false
	var recreated := capture_v1(sdk, record.request.utf8_text, record.response.utf8_text,
		record.initial_transport_verification.utf8_text, policy_id, normal_receipt_schema,
		semantic_step, compiled_morphology)
	return same_json_v1(record, recreated.development_native_step_failure)
