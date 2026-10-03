extends RefCounted
# gdlint: disable=max-line-length

## Godot/Jolt binding surface for the portable recovery runtime.
##
## Native host code owns post-step sampling. This wrapper crosses the compiled
## Rust ABI only after a complete observation has been assembled. The wrapper
## never invents a missing measurement, constructs a world, or steps physics;
## a separately qualified native route must own those physical responsibilities.

const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const CollectionTransportL15 := preload(
	"res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_collection_transport_v1.gd"
)

const DEVELOPMENT_PROFILE_SCHEMA := "sporespore_recovery_development_profile_v1"
const INITIALIZE_REQUEST_V1_SCHEMA := "sporespore_recovery_initialize_request_v1"
const INITIALIZE_REQUEST_V2_SCHEMA := "sporespore_recovery_initialize_request_v2"
const STEP_REQUEST_V1_SCHEMA := "sporespore_recovery_step_request_v1"
const STEP_REQUEST_V2_SCHEMA := "sporespore_recovery_step_request_v2"
const STEP_REQUEST_V3_SCHEMA := "sporespore_recovery_step_request_v3"
const STEP_REQUEST_V4_SCHEMA := "sporespore_recovery_step_request_v4"
const STEP_REQUEST_V5_SCHEMA := "sporespore_recovery_step_request_v5"
const PASSIVE_ENTRY_REQUEST_V1_SCHEMA := "sporespore_recovery_passive_entry_request_v1"
const EVALUATION_REQUEST_V1_SCHEMA := "sporespore_recovery_evaluation_request_v1"
const EVALUATION_REQUEST_V2_SCHEMA := "sporespore_recovery_evaluation_request_v2"
const EVALUATION_REQUEST_V3_SCHEMA := "sporespore_recovery_evaluation_request_v3"
const EVALUATION_REQUEST_V4_SCHEMA := "sporespore_recovery_evaluation_request_v4"
const EVALUATION_REQUEST_V5_SCHEMA := "sporespore_recovery_evaluation_request_v5"
const ENERGY_AGGREGATION_REQUEST_V2_SCHEMA := (
	"sporespore_recovery_energy_balance_aggregation_request_v2"
)
const ENERGY_AGGREGATION_REQUEST_V3_SCHEMA := (
	"sporespore_recovery_energy_balance_aggregation_request_v3"
)
const ENERGY_EVALUATION_REQUEST_V2_SCHEMA := (
	"sporespore_recovery_energy_balance_evaluation_request_v2"
)
const ENERGY_EVALUATION_REQUEST_V3_SCHEMA := (
	"sporespore_recovery_energy_balance_evaluation_request_v3"
)
const ENERGY_MIGRATION_REQUEST_V1_SCHEMA := (
	"sporespore_recovery_energy_balance_migration_request_v1"
)
const COLLECTION_REQUEST_V1_SCHEMA := "sporespore_recovery_native_collection_request_v1"
const COLLECTION_REQUEST_V2_SCHEMA := "sporespore_recovery_native_collection_request_v2"
const COLLECTION_REQUEST_V3_SCHEMA := "sporespore_recovery_native_collection_request_v3"
const CONTROL_REQUEST_V1_SCHEMA := "sporespore_recovery_control_request_v1"
const CONTROL_REQUEST_V2_SCHEMA := "sporespore_recovery_control_request_v2"
const CONTROL_REQUEST_V3_SCHEMA := "sporespore_recovery_control_request_v3"
const STANCE_CONTROL_REQUEST_V1_SCHEMA := "sporespore_recovery_stance_control_request_v1"
const STANCE_CONTROL_REQUEST_V2_SCHEMA := "sporespore_recovery_stance_control_request_v2"
const STANCE_CONTROL_REQUEST_V3_SCHEMA := "sporespore_recovery_stance_control_request_v3"
const STANCE_CONTROL_REQUEST_V4_SCHEMA := "sporespore_recovery_stance_control_request_v4"
const CANONICAL_JSON_REQUEST_SCHEMA := "sporespore_canonical_json_request_v1"
const RECOVERY_MORPHOLOGY_DESCRIPTOR_SCHEMA := (
	"sporespore_recovery_morphology_descriptor_v1"
)
const ACTUATOR_CAP_PROFILE_REQUEST_SCHEMA := (
	"sporespore_actuator_cap_profile_request_v1"
)


static func canonicalize(sdk: Object, value: Variant) -> Dictionary:
	return _decode_envelope(
		sdk.canonicalize_json(
			JsonTransportScript.stringify(
				{
					"schema_version": CANONICAL_JSON_REQUEST_SCHEMA,
					"value": value,
				}
			)
		)
	)


static func compile_recovery_morphology_v1(
	sdk: Object,
	descriptor: Dictionary,
) -> Dictionary:
	if not _schema_exact(descriptor, RECOVERY_MORPHOLOGY_DESCRIPTOR_SCHEMA):
		return _local_failure("RECOVERY_MORPHOLOGY_DESCRIPTOR_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.compile_recovery_morphology_v1_json(JsonTransportScript.stringify(descriptor))
	)


static func resolve_actuator_cap_profile_v1(
	sdk: Object,
	profile_id: String,
	descriptor: Dictionary,
) -> Dictionary:
	if profile_id.is_empty():
		return _local_failure("ACTUATOR_CAP_PROFILE_ID_INVALID")
	return _decode_envelope(
		sdk.resolve_actuator_cap_profile_v1_json(
			JsonTransportScript.stringify(
				{
					"schema_version": ACTUATOR_CAP_PROFILE_REQUEST_SCHEMA,
					"profile_id": profile_id,
					"descriptor": descriptor,
				}
			)
		)
	)


static func development_profile_v1(sdk: Object) -> Dictionary:
	return _decode_envelope(sdk.recovery_development_profile_v1_json())


static func initialize_v1(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, INITIALIZE_REQUEST_V1_SCHEMA):
		return _local_failure("INITIALIZE_REQUEST_V1_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_initialize_v1_json(JsonTransportScript.stringify(request))
	)


static func initialize_v2(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, INITIALIZE_REQUEST_V2_SCHEMA):
		return _local_failure("INITIALIZE_REQUEST_V2_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_initialize_v2_json(JsonTransportScript.stringify(request))
	)


static func step_v1(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, STEP_REQUEST_V1_SCHEMA):
		return _local_failure("STEP_REQUEST_V1_SCHEMA_INVALID")
	return _decode_envelope(sdk.recovery_step_v1_json(JsonTransportScript.stringify(request)))


static func step_v2(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, STEP_REQUEST_V2_SCHEMA):
		return _local_failure("STEP_REQUEST_V2_SCHEMA_INVALID")
	return _decode_envelope(sdk.recovery_step_v2_json(JsonTransportScript.stringify(request)))


static func step_v3(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, STEP_REQUEST_V3_SCHEMA):
		return _local_failure("STEP_REQUEST_V3_SCHEMA_INVALID")
	return _decode_envelope(sdk.recovery_step_v3_json(JsonTransportScript.stringify(request)))


static func step_v4(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, STEP_REQUEST_V4_SCHEMA):
		return _local_failure("STEP_REQUEST_V4_SCHEMA_INVALID")
	return _decode_envelope(sdk.recovery_step_v4_json(JsonTransportScript.stringify(request)))


static func step_v5(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, STEP_REQUEST_V5_SCHEMA):
		return _local_failure("STEP_REQUEST_V5_SCHEMA_INVALID")
	return _decode_envelope(sdk.recovery_step_v5_json(JsonTransportScript.stringify(request)))


## Additive development boundary. An older pinned adapter is not silently
## substituted with the historical step API or a GDScript classifier.
static func collect_passive_native_v1(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, "sporespore_recovery_passive_native_collection_request_v1"):
		return _local_failure("PASSIVE_NATIVE_COLLECTION_SCHEMA_INVALID")
	if sdk == null or not sdk.has_method("recovery_collect_passive_native_v1_json"):
		return _local_failure("PASSIVE_NATIVE_COLLECTION_RUNTIME_UNAVAILABLE")
	return _decode_passive_envelope_v1(
		sdk, sdk.recovery_collect_passive_native_v1_json(JsonTransportScript.stringify(request))
	)


static func passive_entry_step_v1(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, PASSIVE_ENTRY_REQUEST_V1_SCHEMA):
		return _local_failure("PASSIVE_ENTRY_REQUEST_V1_SCHEMA_INVALID")
	if sdk == null or not sdk.has_method("recovery_passive_entry_step_v1_json"):
		return _local_failure("PASSIVE_ENTRY_RUNTIME_UNAVAILABLE")
	return _decode_passive_envelope_v1(
		sdk, sdk.recovery_passive_entry_step_v1_json(JsonTransportScript.stringify(request))
	)


static func _decode_passive_envelope_v1(sdk: Object, raw: String) -> Dictionary:
	if not sdk.has_method("decode_passive_recovery_response_v1"):
		return _local_failure("PASSIVE_EXACT_DECODER_UNAVAILABLE")
	var parsed: Variant = sdk.decode_passive_recovery_response_v1(raw)
	if parsed == null:
		# Error envelopes contain no authoritative numeric state to carry.
		var legacy: Variant = JSON.parse_string(raw)
		if legacy is Dictionary and legacy.get("ok") == false:
			return _decode_envelope_value_v1(legacy)
		return _local_failure("PASSIVE_EXACT_RESPONSE_INVALID")
	return _decode_envelope_value_v1(parsed)


static func evaluate_trace_v1(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, EVALUATION_REQUEST_V1_SCHEMA):
		return _local_failure("EVALUATION_REQUEST_V1_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_evaluate_trace_v1_json(JsonTransportScript.stringify(request))
	)


static func evaluate_trace_v2(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, EVALUATION_REQUEST_V2_SCHEMA):
		return _local_failure("EVALUATION_REQUEST_V2_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_evaluate_trace_v2_json(JsonTransportScript.stringify(request))
	)


static func evaluate_trace_v3(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, EVALUATION_REQUEST_V3_SCHEMA):
		return _local_failure("EVALUATION_REQUEST_V3_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_evaluate_trace_v3_json(JsonTransportScript.stringify(request))
	)


static func evaluate_trace_v4(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, EVALUATION_REQUEST_V4_SCHEMA):
		return _local_failure("EVALUATION_REQUEST_V4_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_evaluate_trace_v4_json(JsonTransportScript.stringify(request))
	)


static func evaluate_trace_v5(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, EVALUATION_REQUEST_V5_SCHEMA):
		return _local_failure("EVALUATION_REQUEST_V5_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_evaluate_trace_v5_json(JsonTransportScript.stringify(request))
	)


static func aggregate_energy_v2(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, ENERGY_AGGREGATION_REQUEST_V2_SCHEMA):
		return _local_failure("ENERGY_AGGREGATION_REQUEST_V2_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_energy_balance_aggregate_v2_json(JsonTransportScript.stringify(request))
	)


static func aggregate_energy_v3(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, ENERGY_AGGREGATION_REQUEST_V3_SCHEMA):
		return _local_failure("ENERGY_AGGREGATION_REQUEST_V3_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_energy_balance_aggregate_v3_json(JsonTransportScript.stringify(request))
	)


static func evaluate_energy_v2(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, ENERGY_EVALUATION_REQUEST_V2_SCHEMA):
		return _local_failure("ENERGY_EVALUATION_REQUEST_V2_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_energy_balance_evaluate_v2_json(JsonTransportScript.stringify(request))
	)


static func evaluate_energy_v3(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, ENERGY_EVALUATION_REQUEST_V3_SCHEMA):
		return _local_failure("ENERGY_EVALUATION_REQUEST_V3_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_energy_balance_evaluate_v3_json(JsonTransportScript.stringify(request))
	)


static func migrate_energy_v1(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, ENERGY_MIGRATION_REQUEST_V1_SCHEMA):
		return _local_failure("ENERGY_MIGRATION_REQUEST_V1_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_energy_balance_migrate_v1_json(JsonTransportScript.stringify(request))
	)


static func collect_native_v1(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, COLLECTION_REQUEST_V1_SCHEMA):
		return _local_failure("COLLECTION_REQUEST_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_collect_native_v1_json(JsonTransportScript.stringify(request))
	)


static func collect_native_v2(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, COLLECTION_REQUEST_V2_SCHEMA):
		return _local_failure("COLLECTION_REQUEST_V2_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_collect_native_v2_json(JsonTransportScript.stringify(request))
	)


static func collect_native_v3(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, COLLECTION_REQUEST_V3_SCHEMA):
		return _local_failure("COLLECTION_REQUEST_V3_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_collect_native_v3_json(JsonTransportScript.stringify(request))
	)


## Explicit opt-in: legacy collection callers keep their original return shape.
## This returns both the decoded collection and the exact transport receipt.
## The actual route/worker must carry the receipt onward if collection refuses.
static func collect_native_v3_l15_v1(
	sdk: Object, request: Dictionary, source_application: Dictionary,
	source_memory: Dictionary, bound_observation: Dictionary
) -> Dictionary:
	var prepared := CollectionTransportL15.prepare_v1(request, {
		"source_application": source_application,
		"source_memory": source_memory,
		"bound_observation": bound_observation,
	})
	var captured: Dictionary = prepared
	if prepared.get("ok") == true:
		if sdk == null or not sdk.has_method("recovery_collect_native_v3_json"):
			captured = CollectionTransportL15.precollection_refusal_v1(
				prepared["receipt"], "L15_COLLECTION_SDK_METHOD_UNAVAILABLE"
			)
		else:
			var exact_request: String = prepared["receipt"]["request"]["utf8_text"]
			var raw_response: String = sdk.recovery_collect_native_v3_json(exact_request)
			captured = CollectionTransportL15.complete_v1(prepared["receipt"], raw_response)
	var collection: Dictionary = (
		_decode_envelope_value_v1(captured["parsed_envelope"])
		if captured.get("ok") == true
		else _local_failure(captured["failure_code"])
	)
	var retention: Dictionary = captured["receipt"]
	retention["decoded_collection"] = collection.duplicate(true)
	return {"collection": collection, "collection_transport_retention": retention}


static func plan_control_v1(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, CONTROL_REQUEST_V1_SCHEMA):
		return _local_failure("CONTROL_REQUEST_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_plan_control_v1_json(JsonTransportScript.stringify(request))
	)


static func plan_control_v2(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, CONTROL_REQUEST_V2_SCHEMA):
		return _local_failure("CONTROL_REQUEST_V2_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_plan_control_v2_json(JsonTransportScript.stringify(request))
	)


static func plan_control_v3(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, CONTROL_REQUEST_V3_SCHEMA):
		return _local_failure("CONTROL_REQUEST_V3_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_plan_control_v3_json(JsonTransportScript.stringify(request))
	)


static func plan_stance_control_v1(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, STANCE_CONTROL_REQUEST_V1_SCHEMA):
		return _local_failure("STANCE_CONTROL_REQUEST_V1_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_plan_stance_control_v1_json(JsonTransportScript.stringify(request))
	)


static func plan_stance_control_v2(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, STANCE_CONTROL_REQUEST_V2_SCHEMA):
		return _local_failure("STANCE_CONTROL_REQUEST_V2_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_plan_stance_control_v2_json(JsonTransportScript.stringify(request))
	)


static func plan_stance_control_v3(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, STANCE_CONTROL_REQUEST_V3_SCHEMA):
		return _local_failure("STANCE_CONTROL_REQUEST_V3_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_plan_stance_control_v3_json(JsonTransportScript.stringify(request))
	)


static func plan_stance_control_v4(sdk: Object, request: Dictionary) -> Dictionary:
	if not _schema_exact(request, STANCE_CONTROL_REQUEST_V4_SCHEMA):
		return _local_failure("STANCE_CONTROL_REQUEST_V4_SCHEMA_INVALID")
	return _decode_envelope(
		sdk.recovery_plan_stance_control_v4_json(JsonTransportScript.stringify(request))
	)


static func zero_world_surface_receipt_v1(sdk: Object) -> Dictionary:
	var profile := development_profile_v1(sdk)
	var profile_valid := (
		String(profile.get("schema_version", "")) == DEVELOPMENT_PROFILE_SCHEMA
		and bool(profile.get("physical_execution_authorized", true)) == false
		and bool(profile.get("physical_acceptance_authority", true)) == false
		and bool(profile.get("release_authority", true)) == false
	)
	return {
		"schema_version": "sporespore_godot_recovery_runtime_zero_world_surface_receipt_v1",
		"ok": profile_valid,
		"profile_schema_valid": profile_valid,
		"collection_method": "SporeLocomotionSdk.recovery_collect_native_v1_json",
		"controller_method": "SporeLocomotionSdk.recovery_plan_control_v1_json",
		"native_runtime_observation_collection_executed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _schema_exact(request: Dictionary, expected: String) -> bool:
	return String(request.get("schema_version", "")) == expected


static func _decode_envelope(raw: String) -> Dictionary:
	return _decode_envelope_value_v1(JSON.parse_string(raw))


static func _decode_envelope_value_v1(parsed: Variant) -> Dictionary:
	if not (parsed is Dictionary):
		return _local_failure("ABI_RESPONSE_NOT_DICTIONARY")
	var envelope: Dictionary = parsed
	if not bool(envelope.get("ok", false)):
		return _local_failure(
			String(envelope.get("failure_code", "ABI_RESPONSE_FAILURE")),
			String(envelope.get("detail", ""))
		)
	var value: Variant = envelope.get("value")
	if not (value is Dictionary):
		return _local_failure("ABI_VALUE_NOT_DICTIONARY")
	return value


static func _local_failure(code: String, detail: String = "") -> Dictionary:
	return {
		"schema_version": "sporespore_godot_recovery_runtime_local_failure_v1",
		"ok": false,
		"failure_code": code,
		"detail": detail,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
