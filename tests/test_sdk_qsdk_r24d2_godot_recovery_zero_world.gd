extends SceneTree
# gdlint: disable=max-line-length

const CapabilityScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_capability.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D2_GODOT_RECOVERY_ZERO_WORLD "


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D2_GODOT_EXTENSION_UNAVAILABLE")
	var api: Object = ClassDB.instantiate(CLASS_NAME)
	if api == null:
		return _failure("QSDK_R24D2_GODOT_EXTENSION_INSTANTIATION_FAILED")
	var capability := CapabilityScript.capability_v1()
	var local_validation := CapabilityScript.validate_capability_v1(capability)
	if not bool(local_validation.get("ok", false)):
		return _failure("QSDK_R24D2_GODOT_CAPABILITY_INVALID", local_validation)

	var native_api_checks := {
		"direct_state_transform": ClassDB.class_has_method(
			"PhysicsDirectBodyState3D", "get_transform"
		),
		"direct_state_linear_velocity": ClassDB.class_has_method(
			"PhysicsDirectBodyState3D", "get_linear_velocity"
		),
		"direct_state_angular_velocity": ClassDB.class_has_method(
			"PhysicsDirectBodyState3D", "get_angular_velocity"
		),
		"direct_state_center_of_mass": ClassDB.class_has_method(
			"PhysicsDirectBodyState3D", "get_center_of_mass"
		),
		"direct_state_contact_count": ClassDB.class_has_method(
			"PhysicsDirectBodyState3D", "get_contact_count"
		),
		"direct_state_contact_position": ClassDB.class_has_method(
			"PhysicsDirectBodyState3D", "get_contact_local_position"
		),
		"direct_state_contact_normal": ClassDB.class_has_method(
			"PhysicsDirectBodyState3D", "get_contact_local_normal"
		),
		"direct_state_contact_impulse": ClassDB.class_has_method(
			"PhysicsDirectBodyState3D", "get_contact_impulse"
		),
		"direct_space_cast_motion": ClassDB.class_has_method(
			"PhysicsDirectSpaceState3D", "cast_motion"
		),
		"hinge_parameter_readback": ClassDB.class_has_method(
			"HingeJoint3D", "get_param"
		),
	}
	var native_api_reachable := true
	for value in native_api_checks.values():
		native_api_reachable = native_api_reachable and bool(value)

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
	var result := _call(api, "recovery_initialize_v1_json", request)
	if not bool(result.get("ok", false)):
		return _failure("QSDK_R24D2_GODOT_INITIALIZATION_TRANSPORT_FAILED", result)
	var receipt: Dictionary = result["receipt"]

	var promoted := capability.duplicate(true)
	for index in [5, 8]:
		(promoted["ordered_channels"][index] as Dictionary)["support"] = "supported_measured"
		(promoted["ordered_channels"][index] as Dictionary)["source_measurement_only"] = true
	var promoted_validation := CapabilityScript.validate_capability_v1(promoted)

	var missing := capability.duplicate(true)
	missing["ordered_channels"].pop_back()
	var missing_validation := CapabilityScript.validate_capability_v1(missing)

	var synthesized := capability.duplicate(true)
	(synthesized["ordered_channels"][3] as Dictionary)["synthesized_when_missing"] = true
	var synthesized_validation := CapabilityScript.validate_capability_v1(synthesized)

	var exact: bool = (
		String(Engine.get_version_info().get("string", "")) == "4.7-stable (official)"
		and native_api_reachable
		and int(local_validation.get("required_channel_count", -1)) == 10
		and int(local_validation.get("supported_channel_count", -1)) == 8
		and int(local_validation.get("unsupported_channel_count", -1)) == 2
		and local_validation.get("unsupported_channels", [])
		== CapabilityScript.UNSUPPORTED_CHANNELS
		and String(receipt.get("support_status", "")) == "unsupported_capability"
		and String(receipt.get("refusal_reason", "")).begins_with(
			"required_channel_unsupported:AppliedActuationReceipts"
		)
		and receipt.get("memory") == null
		and not bool(receipt.get("controller_implemented", true))
		and not bool(receipt.get("physical_threshold_authority", true))
		and not bool(receipt.get("physical_question_opened", true))
		and int(receipt.get("model_construction_count", -1)) == 0
		and int(receipt.get("world_attempt_count", -1)) == 0
		and int(receipt.get("world_build_count", -1)) == 0
		and int(receipt.get("solver_step_count", -1)) == 0
		and not bool(receipt.get("physics_state_modified", true))
		and not bool(receipt.get("prone_to_standing_claimed", true))
		and not bool(receipt.get("physical_acceptance_authority", true))
		and not bool(receipt.get("release_authority", true))
		and not bool(promoted_validation.get("ok", true))
		and not bool(missing_validation.get("ok", true))
		and not bool(synthesized_validation.get("ok", true))
	)
	return {
		"schema_version": "sporespore_qsdk_r24d2_godot_recovery_zero_world_v1",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D2_GODOT_ZERO_WORLD_INVALID",
		"question_class": "non_physical_source_conformance",
		"runtime_api_version": String(Engine.get_version_info().get("string", "")),
		"adapter_id": CapabilityScript.ADAPTER_ID,
		"mapping_id": CapabilityScript.MAPPING_ID,
		"native_api_checks": native_api_checks,
		"native_api_reachable": native_api_reachable,
		"required_channel_count": 10,
		"supported_channel_count": 8,
		"unsupported_channel_count": 2,
		"unsupported_channels": CapabilityScript.UNSUPPORTED_CHANNELS.duplicate(),
		"typed_refusal_status": String(receipt.get("support_status", "")),
		"typed_refusal_reason": String(receipt.get("refusal_reason", "")),
		"false_promotion_rejected": not bool(promoted_validation.get("ok", true)),
		"missing_channel_rejected": not bool(missing_validation.get("ok", true)),
		"synthesized_channel_rejected": not bool(synthesized_validation.get("ok", true)),
		"native_runtime_observation_collection_executed": false,
		"controller_implemented": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_declared": false,
		"physical_campaign_opened": false,
		"prone_to_standing_claimed": false,
		"cross_engine_equivalence_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


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
		"schema_version": "sporespore_qsdk_r24d2_godot_recovery_zero_world_v1",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"question_class": "non_physical_source_conformance",
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_declared": false,
		"physical_campaign_opened": false,
		"prone_to_standing_claimed": false,
		"cross_engine_equivalence_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
