extends SceneTree
# The retained command is real; the counter-boundary substitution is synthetic.
# This probe creates no body, world, physics query, motor application or step.
# gdlint: disable=max-line-length
const Shared := preload("res://tests/test_development_v32_walking_policy.gd")
const PROFILE := "res://sdk/development/recovery_candidates/v43-support-progression-integrated-v1.json"
const POLICY := "sporespore_balanced_wave_recovery_support_progression_v1"
const RECEIPT := "sporespore_recovery_support_progression_controller_step_receipt_v1"
const GENERIC := "sporespore_controller_step_receipt_v2"
const ERROR := "GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_RECEIPT_SCHEMA_MISMATCH"

func _initialize() -> void:
	var probe := Shared.RuntimeProbe.new()
	probe.profile_path = PROFILE
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(profile.runtime_binding))
	var checks := {"exact_runtime": probe._load_runtime_extension_v1()}
	if not checks.exact_runtime:
		probe.free()
		_finish(checks, {})
		return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var input: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	var created: Dictionary = JSON.parse_string(sdk.balanced_wave_policy_session_create_json(JSON.stringify({
		"schema_version": "sporespore_balanced_wave_policy_session_create_request_v1", "descriptor": input.descriptor, "policy_id": POLICY}, "", true, true)))
	checks.session_created = created.get("ok") == true
	var request: Dictionary = input.request
	var step := int(request.state.semantic_step)
	var normal_raw: String = sdk.balanced_wave_policy_session_step_json(JSON.stringify(request, "", true, true))
	var normal_check: Dictionary = JSON.parse_string(sdk.balanced_wave_native_step_transport_verification_json(normal_raw, POLICY, RECEIPT, step))
	checks.normal_raw_exact = "sha256:" + normal_raw.sha256_text() == input.raw_native_response_sha256
	checks.normal_transport_passes = normal_check.get("ok") == true
	var substituted := request.duplicate(true)
	substituted.memory.support_progression.held_steps = 120
	var stopped_raw: String = sdk.balanced_wave_policy_session_step_json(JSON.stringify(substituted, "", true, true))
	var stopped: Dictionary = sdk.decode_exact_json_v1(stopped_raw)
	var value: Dictionary = stopped.value
	checks.native_safe_refusal = stopped.ok == true and value.actuation.safe_no_actuation == true
	checks.generic_error_schema = value.actuation.receipt.schema_version == GENERIC
	checks.hold_timeout_reason = String(value.actuation.receipt.controller_error).contains("support_progression_hold_timeout")
	checks.memory_unchanged = _same_json_value(value.next_memory, substituted.memory)
	checks.eight_zero_commands = value.actuation.ordered_commands.size() == 8
	for command in value.actuation.ordered_commands:
		checks.eight_zero_commands = checks.eight_zero_commands and command.target_velocity_rad_s == 0
	var strict: Dictionary = JSON.parse_string(sdk.balanced_wave_native_step_transport_verification_json(stopped_raw, POLICY, RECEIPT, step))
	checks.normal_schema_rejects_refusal = strict.get("ok") == false and strict.get("failure_code") == ERROR
	# Diagnostic integrity check only: this is NOT a production acceptance path.
	var generic: Dictionary = JSON.parse_string(sdk.balanced_wave_native_step_transport_verification_json(stopped_raw, POLICY, GENERIC, step))
	checks.generic_digest_and_identity_verify = generic.get("ok") == true
	var wrong_policy: Dictionary = JSON.parse_string(sdk.balanced_wave_native_step_transport_verification_json(stopped_raw, "crossed-policy", GENERIC, step))
	var wrong_step: Dictionary = JSON.parse_string(sdk.balanced_wave_native_step_transport_verification_json(stopped_raw, POLICY, GENERIC, step + 1))
	var corrupt_raw := stopped_raw.replace("support_progression_hold_timeout", "corrupted_progression_hold_timeout")
	var corrupt: Dictionary = JSON.parse_string(sdk.balanced_wave_native_step_transport_verification_json(corrupt_raw, POLICY, GENERIC, step))
	checks.wrong_policy_refuses = wrong_policy.get("failure_code") == "GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_POLICY_MISMATCH"
	checks.wrong_step_refuses = wrong_step.get("failure_code") == "GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_ACTUATION_STEP_MISMATCH"
	checks.changed_error_without_digest_refuses = corrupt.get("failure_code") == "GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_RECEIPT_DIGEST_MISMATCH"
	var adapter := Shared.Facade.SdkAdapterScript.new()
	adapter._api = sdk
	adapter._controller_policy_id = POLICY
	var normal_adapter: Dictionary = adapter._call_balanced_wave_session_step_with_transport_verification(request, step)
	var stopped_adapter: Dictionary = adapter._call_balanced_wave_session_step_with_transport_verification(substituted, step)
	checks.actual_adapter_normal_passes = normal_adapter.get("ok") == true
	checks.actual_adapter_refusal_is_transport_invalid = stopped_adapter.get("ok") == false and stopped_adapter.get("detail") == ERROR
	checks.actual_adapter_discards_failed_raw = not stopped_adapter.has("raw_native_response") and not stopped_adapter.has("value")
	checks.session_destroyed = JSON.parse_string(sdk.balanced_wave_policy_session_destroy_json()).get("ok") == true
	adapter._api = null
	probe.free()
	_finish(checks, {"normal_raw_response": normal_raw, "synthetic_request": substituted,
		"synthetic_raw_response": stopped_raw, "normal_verification": normal_check,
		"strict_refusal_verification": strict, "diagnostic_generic_verification": generic,
		"actual_adapter_refusal": stopped_adapter, "local_semantic_step": step,
		"substitution": "Only incoming memory.support_progression.held_steps 119 -> 120; not the missing physical command 177."})

func _finish(checks: Dictionary, result: Dictionary) -> void:
	print("V43_SAFE_STOP_TRANSPORT ", Shared.Transport.stringify({"ok": not checks.values().has(false),
		"checks": checks, "result": result, "world_build_count": 0, "solver_step_count": 0,
		"native_physics_read_count": 0, "physical_acceptance_authority": false, "release_authority": false,
		"original_failed_request_reconstructed": false, "original_hidden_error_proven": false}))
	quit(0 if not checks.values().has(false) else 1)

func _same_json_value(left: Variant, right: Variant) -> bool:
	# The request transport writes integral 0, while native f64 fields return
	# 0.0. Compare JSON values recursively, with exact numbers and no tolerance;
	# whole-Dictionary equality also distinguishes these nested Variant types.
	if typeof(left) == TYPE_DICTIONARY and typeof(right) == TYPE_DICTIONARY:
		if left.size() != right.size():
			return false
		for key in left:
			if not right.has(key) or not _same_json_value(left[key], right[key]):
				return false
		return true
	if typeof(left) == TYPE_ARRAY and typeof(right) == TYPE_ARRAY:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not _same_json_value(left[index], right[index]):
				return false
		return true
	if typeof(left) != typeof(right):
		if not (typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]):
			return false
		# Refuse a numeric conversion beyond binary64's exact integer range.
		if abs(left) > 9007199254740991 or abs(right) > 9007199254740991:
			return false
	return left == right
