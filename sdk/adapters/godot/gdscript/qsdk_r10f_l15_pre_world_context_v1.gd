class_name SporeQsdkR10fL15PreWorldContextV1
extends RefCounted
# gdlint: disable=max-line-length

## Compare the current prepared context with a separately supplied launch binding.
## The caller must establish that binding's qualification origin; this is not it.
const Context := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_context_v1.gd")
const LENGTH_ENV := "SPORESPORE_GODOT_RECOVERY_L15_CONTEXT_UTF8_BYTE_LENGTH"
const SHA_ENV := "SPORESPORE_GODOT_RECOVERY_L15_CONTEXT_RAW_SHA256"


static func launch_binding_v1(length_text: String, digest: String) -> Dictionary:
	if not length_text.is_valid_int():
		return {}
	var byte_length := length_text.to_int()
	if byte_length <= 0 or str(byte_length) != length_text or not _digest_valid_v1(digest):
		return {}
	return {"utf8_byte_length": byte_length, "raw_sha256": digest}


static func compare_prepared_v1(
	sdk: Object, context: Dictionary, expected_binding: Dictionary
) -> Dictionary:
	var result := {
		"schema_version": "sporespore_qsdk_r10f_l15_pre_world_context_comparison_v1",
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "prepared_context_comparison_before_world",
			"question_class": "development",
		},
		"ok": false,
		"failure_code": "L15_PRE_WORLD_EXPECTED_BINDING_INVALID",
		"expected_capture_binding": expected_binding.duplicate(true),
		"observed_capture": null,
		"prepared_context_capture_failure_code": null,
		"expected_capture_binding_matched": false,
		"context_capture_call_count": 0,
		"observation_or_failed_packet_used_as_expected_context": false,
		"expected_binding_origin_authenticated_here": false,
		"official_context_qualification": false,
		"compiled_collection_call_count": 0,
		"portable_recovery_advance_call_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_physics_read_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if (
		expected_binding.size() != 2
		or typeof(expected_binding.get("utf8_byte_length")) != TYPE_INT
		or expected_binding["utf8_byte_length"] <= 0
		or typeof(expected_binding.get("raw_sha256")) != TYPE_STRING
		or not _digest_valid_v1(expected_binding["raw_sha256"])
	):
		return result
	result["context_capture_call_count"] = 1
	var captured := Context.capture_prepared_v1(sdk, context)
	if captured.get("ok") != true:
		result["failure_code"] = "L15_PRE_WORLD_PREPARED_CONTEXT_INVALID"
		result["prepared_context_capture_failure_code"] = captured.get("failure_code")
		return result
	var observed := Context.snapshot_v1(captured)
	result["observed_capture"] = observed
	if (
		observed["utf8_byte_length"] != expected_binding["utf8_byte_length"]
		or observed["raw_sha256"] != expected_binding["raw_sha256"]
	):
		result["failure_code"] = "L15_PRE_WORLD_PREPARED_CONTEXT_MISMATCH"
		return result
	result["expected_capture_binding_matched"] = true
	result["ok"] = true
	result["failure_code"] = null
	return result


static func _digest_valid_v1(value: String) -> bool:
	if value.length() != 71 or not value.begins_with("sha256:"):
		return false
	for index in range(7, value.length()):
		if not value.substr(index, 1) in "0123456789abcdef":
			return false
	return true
