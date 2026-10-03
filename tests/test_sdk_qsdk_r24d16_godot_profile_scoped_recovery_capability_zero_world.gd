extends SceneTree
# gdlint: disable=max-line-length

const ProfileCapabilityScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd"
)
const StockCapabilityScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_capability.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D16_GODOT_PROFILE_CAPABILITY_ZERO_WORLD "


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var expected_profile := _expected_profile()
	if expected_profile not in ["instrumented", "stock"]:
		return _failure("QSDK_R24D16_EXPECTED_PROFILE_INVALID")
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D16_GODOT_EXTENSION_UNAVAILABLE")
	var api: Object = ClassDB.instantiate(CLASS_NAME)
	if api == null:
		return _failure("QSDK_R24D16_GODOT_EXTENSION_INSTANTIATION_FAILED")

	var profile_receipt := ProfileCapabilityScript.profile_receipt_v1()
	var runtime: Dictionary = profile_receipt.get("runtime_identity", {})
	var capability: Dictionary = profile_receipt.get("capability", {})
	var validation: Dictionary = profile_receipt.get("validation", {})
	var stock_capability: Dictionary = StockCapabilityScript.capability_v1()
	if not bool(validation.get("ok", false)):
		return _failure("QSDK_R24D16_PROFILE_CAPABILITY_INVALID", validation)

	var request := {
		"schema_version": "sporespore_recovery_initialize_request_v1",
		"task_id": "sporespore_canonical_ventral_prone_to_four_foot_stance_v1",
		"semantics_id": "sporespore_qsdk_r24d2_portable_recovery_semantics_v1",
		"actuator_profile_id": "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1",
		"threshold_profile_id": "sporespore_qsdk_r24d2_synthetic_zero_world_canary_thresholds_v1",
		"descriptor": _descriptor(),
		"adapter_capability": capability,
		"arm_kind": "candidate_command",
	}
	var call_result := _call(api, "recovery_initialize_v1_json", request)
	if not bool(call_result.get("ok", false)):
		return _failure("QSDK_R24D16_INITIALIZATION_TRANSPORT_FAILED", call_result)
	var core_receipt: Dictionary = call_result["receipt"]

	var mutations := _mutation_results(capability)
	var rejected_mutations := 0
	for mutation in mutations.values():
		if not bool((mutation as Dictionary).get("ok", true)):
			rejected_mutations += 1

	var profile_selected := bool(runtime.get("instrumented_profile_selected", false))
	var profile_specific_exact := false
	if expected_profile == "instrumented":
		profile_specific_exact = (
			profile_selected
			and String(profile_receipt.get("profile_id", ""))
			== ProfileCapabilityScript.INSTRUMENTED_PROFILE_ID
			and bool(runtime.get("running_executable_is_pair_member", false))
			and bool(runtime.get("exact_binary_pair_match", false))
			and bool(runtime.get("telemetry_class_registered", false))
			and bool(runtime.get("telemetry_method_registered", false))
			and String((runtime["console_binary"] as Dictionary).get("raw_sha256", ""))
			== ProfileCapabilityScript.EXPECTED_CONSOLE_RAW_SHA256
			and int((runtime["console_binary"] as Dictionary).get("byte_length", -1))
			== ProfileCapabilityScript.EXPECTED_CONSOLE_BYTE_LENGTH
			and String((runtime["engine_binary"] as Dictionary).get("raw_sha256", ""))
			== ProfileCapabilityScript.EXPECTED_ENGINE_RAW_SHA256
			and int((runtime["engine_binary"] as Dictionary).get("byte_length", -1))
			== ProfileCapabilityScript.EXPECTED_ENGINE_BYTE_LENGTH
			and capability != stock_capability
			and int(validation.get("required_channel_count", -1)) == 10
			and int(validation.get("supported_channel_count", -1)) == 10
			and int(validation.get("unsupported_channel_count", -1)) == 0
			and String(core_receipt.get("support_status", "")) == "supported_exact"
			and core_receipt.get("refusal_reason") == null
			and core_receipt.get("memory") != null
		)
	else:
		profile_specific_exact = (
			not profile_selected
			and String(profile_receipt.get("profile_id", ""))
			== ProfileCapabilityScript.FALLBACK_PROFILE_ID
			and capability == stock_capability
			and int(validation.get("required_channel_count", -1)) == 10
			and int(validation.get("supported_channel_count", -1)) == 8
			and int(validation.get("unsupported_channel_count", -1)) == 2
			and validation.get("unsupported_channels", [])
			== StockCapabilityScript.UNSUPPORTED_CHANNELS
			and String(core_receipt.get("support_status", "")) == "unsupported_capability"
			and String(core_receipt.get("refusal_reason", "")).begins_with(
				"required_channel_unsupported:AppliedActuationReceipts"
			)
			and core_receipt.get("memory") == null
		)

	var exact := (
		profile_specific_exact
		and rejected_mutations == mutations.size()
		and not bool(profile_receipt.get("stock_mapping_rewritten", true))
		and not bool(profile_receipt.get("numerical_accuracy_accepted", true))
		and not bool(profile_receipt.get("native_observation_collection_executed", true))
		and not bool(profile_receipt.get("controller_implemented", true))
		and not bool(core_receipt.get("controller_implemented", true))
		and not bool(core_receipt.get("physical_threshold_authority", true))
		and not bool(core_receipt.get("physical_question_opened", true))
		and int(core_receipt.get("model_construction_count", -1)) == 0
		and int(core_receipt.get("world_attempt_count", -1)) == 0
		and int(core_receipt.get("world_build_count", -1)) == 0
		and int(core_receipt.get("solver_step_count", -1)) == 0
		and not bool(core_receipt.get("physics_state_modified", true))
		and not bool(core_receipt.get("prone_to_standing_claimed", true))
		and not bool(core_receipt.get("physical_acceptance_authority", true))
		and not bool(core_receipt.get("release_authority", true))
	)
	return {
		"schema_version": "sporespore_qsdk_r24d16_godot_profile_capability_zero_world_v1",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D16_ZERO_WORLD_INVALID",
		"gate_id": "QSDK-R24D16",
		"question_class": "non_physical_source_conformance",
		"expected_profile": expected_profile,
		"observed_profile_id": String(profile_receipt.get("profile_id", "")),
		"instrumented_profile_selected": profile_selected,
		"runtime_api_version": String(runtime.get("runtime_api_version", "")),
		"running_executable_path": String(runtime.get("running_executable_path", "")),
		"running_executable_is_pair_member": bool(runtime.get("running_executable_is_pair_member", false)),
		"console_binary": (runtime.get("console_binary", {}) as Dictionary).duplicate(true),
		"engine_binary": (runtime.get("engine_binary", {}) as Dictionary).duplicate(true),
		"exact_binary_pair_match": bool(runtime.get("exact_binary_pair_match", false)),
		"telemetry_class_registered": bool(runtime.get("telemetry_class_registered", false)),
		"telemetry_method_registered": bool(runtime.get("telemetry_method_registered", false)),
		"profile_validation_ok": bool(validation.get("ok", false)),
		"required_channel_count": int(validation.get("required_channel_count", -1)),
		"supported_channel_count": int(validation.get("supported_channel_count", -1)),
		"unsupported_channel_count": int(validation.get("unsupported_channel_count", -1)),
		"unsupported_channels": (validation.get("unsupported_channels", []) as Array).duplicate(),
		"stock_fallback_exact": capability == stock_capability,
		"core_support_status": String(core_receipt.get("support_status", "")),
		"core_refusal_reason": core_receipt.get("refusal_reason"),
		"core_memory_present": core_receipt.get("memory") != null,
		"mutation_count": mutations.size(),
		"mutation_rejection_count": rejected_mutations,
		"missing_channel_rejected": not bool((mutations["missing_channel"] as Dictionary).get("ok", true)),
		"synthesized_channel_rejected": not bool((mutations["synthesized_channel"] as Dictionary).get("ok", true)),
		"wrong_support_rejected": not bool((mutations["wrong_support"] as Dictionary).get("ok", true)),
		"empty_mapping_rejected": not bool((mutations["empty_mapping"] as Dictionary).get("ok", true)),
		"native_observation_collection_executed": false,
		"controller_implemented": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_declared": false,
		"physical_campaign_opened": false,
		"numerical_accuracy_accepted": false,
		"prone_to_standing_claimed": false,
		"cross_engine_equivalence_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _mutation_results(capability: Dictionary) -> Dictionary:
	var missing := capability.duplicate(true)
	missing["ordered_channels"].pop_back()
	var synthesized := capability.duplicate(true)
	(synthesized["ordered_channels"][3] as Dictionary)["synthesized_when_missing"] = true
	var wrong_support := capability.duplicate(true)
	var expected_supported := bool(
		ProfileCapabilityScript.runtime_identity_v1().get("instrumented_profile_selected", false)
	)
	(wrong_support["ordered_channels"][5] as Dictionary)["support"] = (
		"unsupported" if expected_supported else "supported_measured"
	)
	(wrong_support["ordered_channels"][5] as Dictionary)["source_measurement_only"] = not expected_supported
	var empty_mapping := capability.duplicate(true)
	(empty_mapping["ordered_channels"][2] as Dictionary)["mapping_rule_id"] = ""
	return {
		"missing_channel": ProfileCapabilityScript.validate_capability_v1(missing),
		"synthesized_channel": ProfileCapabilityScript.validate_capability_v1(synthesized),
		"wrong_support": ProfileCapabilityScript.validate_capability_v1(wrong_support),
		"empty_mapping": ProfileCapabilityScript.validate_capability_v1(empty_mapping),
	}


static func _expected_profile() -> String:
	for argument in OS.get_cmdline_user_args():
		if String(argument).begins_with("--expected_profile="):
			return String(argument).trim_prefix("--expected_profile=")
	return ""


static func _call(api: Object, method: String, request: Dictionary) -> Dictionary:
	var raw := String(api.call(method, JsonTransportScript.stringify(request)))
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary) or not bool(parsed.get("ok", false)):
		return {"ok": false, "raw": raw}
	return {"ok": true, "receipt": (parsed["value"] as Dictionary).duplicate(true)}


static func _descriptor() -> Dictionary:
	return {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": "qsdk_r05_generated_s169",
		"torso_length_scale": 1.0041015625,
		"torso_width_scale": 1.0031893004115227,
		"upper_length_fraction": 0.5219571428571428,
		"hip_span_scale": 0.9856413994169096,
		"foot_radius_scale": 0.9987180691209617,
		"front_limb_mass_scale": 0.975022758306782,
	}


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d16_godot_profile_capability_zero_world_v1",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"gate_id": "QSDK-R24D16",
		"question_class": "non_physical_source_conformance",
		"native_observation_collection_executed": false,
		"controller_implemented": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_declared": false,
		"physical_campaign_opened": false,
		"numerical_accuracy_accepted": false,
		"prone_to_standing_claimed": false,
		"cross_engine_equivalence_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
