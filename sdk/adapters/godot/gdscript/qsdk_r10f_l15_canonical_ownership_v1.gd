class_name SporeQsdkR10fL15CanonicalOwnershipV1
extends RefCounted
# gdlint: disable=max-line-length

## Pure, opt-in metadata mapping. The orchestration label and every physical
## field stay unchanged. The canonical owner is a separately named field used
## only after the complete mapping has been validated by the observation reader.
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Contract := preload("res://sdk/adapters/godot/gdscript/recovery_interface_contract_v1.gd")
const LEGACY_APPLICATION_SCHEMA := "sporespore_qsdk_r10f_no_actuation_route_aware_discrete_staging_application_intent_v1"
const APPLICATION_SCHEMA := "sporespore_qsdk_r10f_l15_no_actuation_route_aware_discrete_staging_application_intent_v2"
const MAPPING_SCHEMA := "sporespore_qsdk_r10f_l15_canonical_ownership_mapping_v1"
const RECOVERY_CONTROLLER_ID = Contract.RECOVERY_CONTROLLER_ID
const REARWARD_CONTROLLER_ID := "sporespore_exact_s169_prone_to_standing_controller_v7"
const RATE_LIMITED_CONTROLLER_ID := "sporespore_exact_s169_prone_to_standing_controller_v8"


## Single shared selection for producers, worker and reader. Defaults keep the
## original closed V6 alphabet and bytes; V7 has distinct prospective schemas.
static func profile_v1(controller_id: String = RECOVERY_CONTROLLER_ID) -> Dictionary:
	if controller_id == RATE_LIMITED_CONTROLLER_ID:
		return {"controller_id": controller_id, "owner": "recovery_v8",
			"source_schema": "sporespore_development_rate_limited_recovery_no_actuation_source_v1",
			"application_schema": "sporespore_development_rate_limited_recovery_no_actuation_application_v1",
			"mapping_schema": "sporespore_development_rate_limited_recovery_canonical_ownership_mapping_v1"}
	if controller_id == RECOVERY_CONTROLLER_ID:
		return {"controller_id": controller_id, "owner": "recovery_v6",
			"source_schema": LEGACY_APPLICATION_SCHEMA, "application_schema": APPLICATION_SCHEMA,
			"mapping_schema": MAPPING_SCHEMA}
	if controller_id == REARWARD_CONTROLLER_ID:
		return {"controller_id": controller_id, "owner": "recovery_v7",
			"source_schema": "sporespore_development_rearward_fold_no_actuation_source_v1",
			"application_schema": "sporespore_development_rearward_fold_no_actuation_application_v1",
			"mapping_schema": "sporespore_development_rearward_fold_canonical_ownership_mapping_v1"}
	if candidate_id_valid_v1(controller_id):
		# Identity is data, including in the schema discriminator. A V9 mapping
		# cannot be read as V10 even when both use the same orchestration owner.
		var prefix := "sporespore_development_candidate_" + controller_id
		return {"controller_id": controller_id, "owner": "recovery_candidate",
			"source_schema": prefix + "_no_actuation_source_v1",
			"application_schema": prefix + "_no_actuation_application_v1",
			"mapping_schema": prefix + "_canonical_ownership_mapping_v1"}
	return {}


static func candidate_id_valid_v1(controller_id: String) -> bool:
	if controller_id == "sporespore_exact_s169_partial_native_reference_controller_v29": return true
	if controller_id == "sporespore_exact_s169_partial_direct_neutral_controller_v21": return true
	if controller_id == "sporespore_exact_s169_partial_pose_geometry_controller_v22": return true
	if controller_id == "sporespore_exact_s169_partial_load_seeking_controller_v23": return true
	if controller_id == "sporespore_exact_s169_partial_downward_rise_controller_v24": return true
	if controller_id == "sporespore_exact_s169_partial_concurrent_load_rise_controller_v25": return true
	if controller_id == "sporespore_exact_s169_partial_hip_recenter_controller_v26": return true
	if controller_id == "sporespore_exact_s169_partial_support_anchored_controller_v27": return true
	if controller_id == "sporespore_exact_s169_partial_progressive_headroom_controller_v28": return true
	var pattern := RegEx.new()
	pattern.compile("^sporespore_exact_s169_prone_to_standing_controller_v(9|[1-9][0-9]+)$")
	return pattern.search(controller_id) != null


static func build_v1(
	sdk: Object, source_application: Dictionary, source_memory: Dictionary,
	expected_controller_id: String = RECOVERY_CONTROLLER_ID
) -> Dictionary:
	var profile := profile_v1(expected_controller_id)
	if profile.is_empty():
		return _failure_v1("DEVELOPMENT_RECOVERY_OWNER_PROFILE_UNKNOWN")
	for key in [
		"semantic_step",
		"phase",
		"command_sha256",
		"owner_source_receipt_sha256",
		"owner_source_receipt",
		"motor_population_readback",
		"motor_population_readback_sha256",
		"zero_command",
		"external_intervention_receipt_sha256",
		"external_intervention_application_count",
	]:
		if not source_application.has(key):
			return _failure_v1("QSDK_R10F_L15_CANONICAL_OWNER_SOURCE_FIELD_MISSING:%s" % key)
	for key in [
		"ok",
		"no_actuation_requested",
		"native_joint_motors_disabled",
		"structural_zero_actuator_work",
		"zero_command",
		"fallback_controller_active",
		"physical_acceptance_authority",
		"release_authority"
	]:
		if typeof(source_application.get(key)) != TYPE_BOOL:
			return _failure_v1("QSDK_R10F_L15_CANONICAL_OWNER_SOURCE_FLAG_KIND:%s" % key)
	var owner: Variant = source_application.get("controller_owner")
	var controller_id: Variant = source_application.get("recovery_controller_id")
	if (
		sdk == null
		or source_application.get("schema_version") != profile["source_schema"]
		or source_application.get("ok") != true
		or typeof(owner) != TYPE_STRING
		or owner not in ["none", profile["owner"]]
		or (owner == "none" and controller_id != null)
		or (owner == profile["owner"] and controller_id != expected_controller_id)
		or source_application.get("no_actuation_requested") != true
		or source_application.get("native_joint_motors_disabled") != true
		or source_application.get("structural_zero_actuator_work") != true
		or source_application.get("motor_enabled_count") != 0
		or source_application.get("stance_controller_id") != null
		or source_application.get("fallback_controller_active") != false
		or source_application.get("physical_acceptance_authority") != false
		or source_application.get("release_authority") != false
		or typeof(source_application["semantic_step"]) != TYPE_INT
		or source_application["semantic_step"] <= 1
		or typeof(source_application["phase"]) != TYPE_STRING
		or source_application["phase"].is_empty()
		or not (source_application["owner_source_receipt"] is Dictionary)
		or not (source_application["motor_population_readback"] is Dictionary)
		or (owner == profile["owner"] and source_memory.is_empty())
		or (
			not source_memory.is_empty()
			and source_memory.get("phase") != source_application.get("phase")
		)
	):
		return _failure_v1("QSDK_R10F_L15_CANONICAL_OWNER_SOURCE_INVALID")
	for key in [
		"motor_enabled_count",
		"pre_solver_direct_body_impulse_write_count",
		"body_impulse_write_count",
		"adapter_side_discrete_staging_event_count",
		"handoff_event_count"
	]:
		if typeof(source_application.get(key)) != TYPE_INT or source_application.get(key) != 0:
			return _failure_v1("QSDK_R10F_L15_CANONICAL_OWNER_NONZERO_ACTUATION:%s" % key)
	if (
		(
			_sha256_v1(sdk, source_application["owner_source_receipt"])
			!= source_application["owner_source_receipt_sha256"]
		)
		or (
			_sha256_v1(sdk, source_application["motor_population_readback"])
			!= source_application["motor_population_readback_sha256"]
		)
	):
		return _failure_v1("QSDK_R10F_L15_CANONICAL_OWNER_NESTED_SOURCE_DIGEST_INVALID")
	# Recompute the actual v1 producer's command binding. A fresh outer mapping
	# hash cannot make a stale or fabricated source command digest valid.
	var source_command := {
		"schema_version": "sporespore_qsdk_r10f_no_actuation_command_binding_v1",
		"global_semantic_step": source_application["semantic_step"],
		"phase": source_application["phase"],
		"controller_owner": owner,
		"recovery_controller_id": controller_id,
		"zero_command": source_application["zero_command"],
		"owner_source_receipt_sha256": source_application["owner_source_receipt_sha256"],
		"motor_population_readback_sha256": source_application["motor_population_readback_sha256"],
		"external_intervention_receipt_sha256":
		source_application["external_intervention_receipt_sha256"],
		"external_intervention_application_count":
		source_application["external_intervention_application_count"],
	}
	if (
		_sha256_v1(sdk, source_command) != source_application["command_sha256"]
		or (
			source_application.get("command_id")
			!= (
				"qsdk_r10f_no_actuation:%s:%s:%d"
				% [owner, source_application["phase"], source_application["semantic_step"]]
			)
		)
	):
		return _failure_v1("QSDK_R10F_L15_CANONICAL_OWNER_SOURCE_COMMAND_BINDING_INVALID")
	var canonical_owner: String = (Contract.NO_ACTUATION_MAPPING[owner]
		if expected_controller_id == RECOVERY_CONTROLLER_ID else ("none" if owner == "none" else "recovery"))
	var source_sha := _sha256_v1(sdk, source_application)
	var memory_sha := _sha256_v1(sdk, source_memory)
	if source_sha.is_empty() or memory_sha.is_empty():
		return _failure_v1("QSDK_R10F_L15_CANONICAL_OWNER_SOURCE_DIGEST_INVALID")
	var mapping := {
		"schema_version": profile["mapping_schema"],
		"ledger_scope": _scope_v1("development_canonical_ownership_mapping"),
		"orchestration_controller_owner": owner,
		"canonical_controller_owner": canonical_owner,
		"recovery_controller_id": controller_id,
		"global_semantic_step": source_application["semantic_step"],
		"phase": source_application["phase"],
		"source_application": source_application.duplicate(true),
		"source_application_sha256": source_sha,
		"source_memory": source_memory.duplicate(true),
		"source_memory_sha256": memory_sha,
		"source_owner_receipt_sha256": source_application["owner_source_receipt_sha256"],
		"physical_command_fields_changed": false,
		"controller_memory_changed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	var mapping_sha := _sha256_v1(sdk, mapping)
	var command_binding := {
		"schema_version": "sporespore_qsdk_r10f_l15_no_actuation_command_binding_v2",
		"source_command_sha256": source_application["command_sha256"],
		"canonical_ownership_mapping_sha256": mapping_sha,
	}
	var command_sha := _sha256_v1(sdk, command_binding)
	if mapping_sha.is_empty() or command_sha.is_empty():
		return _failure_v1("QSDK_R10F_L15_CANONICAL_OWNER_MAPPING_DIGEST_INVALID")
	# The receipt binds the source application, not itself: no circular hash.
	# Validation rebuilds the complete prospective application from these exact
	# inputs, so no physical field or extra unbound metadata can be substituted.
	var application := source_application.duplicate(true)
	application["schema_version"] = profile["application_schema"]
	application["canonical_controller_owner"] = canonical_owner
	application["canonical_ownership_mapping"] = mapping
	application["canonical_ownership_mapping_sha256"] = mapping_sha
	application["command_sha256"] = command_sha
	# The portable step reader requires lowercase/digit/underscore IDs. The
	# unchanged v1 source uses colons; collection accepts those but V6 step does
	# not. Derive prospective metadata from this mapping's exact command digest,
	# while retaining the complete original ID inside source_application.
	application["command_id"] = "qsdk_r10f_l15_no_actuation_" + command_sha.trim_prefix("sha256:")
	return application


static func validate_v1(
	sdk: Object, application: Dictionary, expected_source_memory: Variant = null,
	expected_controller_id: String = RECOVERY_CONTROLLER_ID
) -> Dictionary:
	var profile := profile_v1(expected_controller_id)
	if profile.is_empty():
		return _failure_v1("DEVELOPMENT_RECOVERY_OWNER_PROFILE_UNKNOWN")
	var mapping_value: Variant = application.get("canonical_ownership_mapping")
	if application.get("schema_version") != profile["application_schema"] or not (mapping_value is Dictionary):
		return _failure_v1("QSDK_R10F_L15_CANONICAL_OWNER_MAPPING_MISSING")
	var mapping: Dictionary = mapping_value
	var source_value: Variant = mapping.get("source_application")
	var memory_value: Variant = mapping.get("source_memory")
	if not (source_value is Dictionary) or not (memory_value is Dictionary):
		return _failure_v1("QSDK_R10F_L15_CANONICAL_OWNER_MAPPING_SOURCE_SHAPE")
	if expected_source_memory != null and not same_value_v1(memory_value, expected_source_memory):
		return _failure_v1("QSDK_R10F_L15_CANONICAL_OWNER_MEMORY_SOURCE_MISMATCH")
	var rebuilt := build_v1(sdk, source_value, memory_value, expected_controller_id)
	if rebuilt.get("ok") != true or not same_value_v1(application, rebuilt):
		return _failure_v1("QSDK_R10F_L15_CANONICAL_OWNER_APPLICATION_SOURCE_MISMATCH")
	return {
		"schema_version": "sporespore_qsdk_r10f_l15_canonical_ownership_validation_v1",
		"ledger_scope": _scope_v1("development_canonical_ownership_validation"),
		"ok": true,
		"canonical_controller_owner": application["canonical_controller_owner"],
		"canonical_ownership_mapping_sha256": application["canonical_ownership_mapping_sha256"],
		"external_source_memory_checked": expected_source_memory != null,
		"model_construction_count": 0,
		"world_build_count": 0,
		"native_physics_read_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func same_value_v1(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if left is Dictionary:
		if left.size() != right.size():
			return false
		for key in left:
			if not right.has(key) or not same_value_v1(left[key], right[key]):
				return false
		return true
	if left is Array:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not same_value_v1(left[index], right[index]):
				return false
		return true
	return left == right


static func _sha256_v1(sdk: Object, value: Variant) -> String:
	var digest: Variant = Runtime.canonicalize(sdk, value).get("sha256")
	if typeof(digest) != TYPE_STRING or not digest.begins_with("sha256:") or digest.length() != 71:
		return ""
	return digest


static func _scope_v1(authority_mode: String) -> Dictionary:
	return {
		"subsystem": "recovery",
		"engine_scope": "godot_jolt",
		"authority_mode": authority_mode,
		"question_class": "development"
	}


static func _failure_v1(code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r10f_l15_canonical_ownership_failure_v1",
		"ledger_scope": _scope_v1("development_canonical_ownership_refusal"),
		"ok": false,
		"failure_code": code,
		"model_construction_count": 0,
		"world_build_count": 0,
		"native_physics_read_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
