class_name SporeQsdkR10fL15CollectionTransportV1
extends RefCounted
# gdlint: disable=max-line-length

## Pure byte retention around one collection call. This module never calls the
## SDK, a controller or a physics surface. The runtime owns the single ABI call.
## Digests below identify UTF-8 transport bytes, not re-canonicalized JSON trees.
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const SCHEMA := "sporespore_qsdk_r10f_l15_collection_transport_retention_v1"
const REQUEST_SCHEMA := "sporespore_recovery_native_collection_request_v3"
const SOURCE_ROLES := ["source_application", "source_memory", "bound_observation"]


static func prepare_v1(request: Dictionary, source_links: Dictionary) -> Dictionary:
	var receipt := _empty_receipt_v1()
	if not _json_source_v1(request):
		return precollection_refusal_v1(receipt, "L15_COLLECTION_REQUEST_NOT_FINITE_JSON")
	# This is the only request serialization. The runtime sends this stored
	# string verbatim; neither success nor refusal causes a reconstruction call.
	receipt["request"] = bytes_v1(Transport.stringify(request))
	receipt["request_serialization_call_count"] = 1
	var source_failure := _retain_source_links_v1(receipt, source_links)
	if not source_failure.is_empty():
		return precollection_refusal_v1(receipt, source_failure)
	if request.get("schema_version") != REQUEST_SCHEMA:
		return precollection_refusal_v1(receipt, "COLLECTION_REQUEST_V3_SCHEMA_INVALID")
	return {"ok": true, "receipt": receipt}


## A route identity/shape refusal before request construction is not an empty
## serialized request or a compiled response. Retain only its actual sources.
static func route_not_called_v1(code: String, source_links: Dictionary) -> Dictionary:
	var receipt := _empty_receipt_v1()
	var source_failure := _retain_source_links_v1(receipt, source_links)
	return precollection_refusal_v1(receipt, code if source_failure.is_empty() else source_failure)["receipt"]


static func _retain_source_links_v1(receipt: Dictionary, source_links: Dictionary) -> String:
	if source_links.size() != SOURCE_ROLES.size():
		return "L15_COLLECTION_SOURCE_LINKS_INVALID"
	for role in SOURCE_ROLES:
		var value: Variant = source_links.get(role)
		if not (value is Dictionary) or not _json_source_v1(value, 0, true):
			return "L15_COLLECTION_SOURCE_LINK_INVALID:%s" % role
		receipt["source_links"][role] = bytes_v1(Transport.stringify(value))
	return ""


static func precollection_refusal_v1(receipt: Dictionary, code: String) -> Dictionary:
	receipt["stage"] = "precollection_refused"
	receipt["transport_failure_code"] = code
	return {"ok": false, "failure_code": code, "receipt": receipt}


static func complete_v1(receipt: Dictionary, raw_response: String) -> Dictionary:
	receipt["compiled_collection_call_count"] = 1
	receipt["response"] = bytes_v1(raw_response)
	receipt["response_json_parse_call_count"] = 1
	var parser := JSON.new()
	var parse_error := parser.parse(raw_response)
	var envelope: Variant = parser.data
	var code := ""
	if parse_error != OK:
		code = "ABI_RESPONSE_JSON_INVALID"
	elif not (envelope is Dictionary):
		code = "ABI_RESPONSE_NOT_DICTIONARY"
	elif typeof(envelope.get("ok")) != TYPE_BOOL:
		code = "ABI_RESPONSE_OK_FLAG_INVALID"
	elif envelope["ok"] and not (envelope.get("value") is Dictionary):
		code = "ABI_VALUE_NOT_DICTIONARY"
	elif (
		not envelope["ok"]
		and (
			typeof(envelope.get("failure_code")) != TYPE_STRING
			or envelope["failure_code"].is_empty()
			or typeof(envelope.get("detail", "")) != TYPE_STRING
		)
	):
		code = "ABI_REFUSAL_SHAPE_INVALID"
	if not code.is_empty():
		receipt["stage"] = "compiled_response_malformed"
		receipt["transport_failure_code"] = code
		return {"ok": false, "failure_code": code, "receipt": receipt}
	receipt["stage"] = "compiled_response_decoded"
	return {"ok": true, "receipt": receipt, "parsed_envelope": envelope}


static func bytes_v1(value: String) -> Dictionary:
	return {
		"utf8_text": value,
		"utf8_byte_length": value.to_utf8_buffer().size(),
		"raw_sha256": "sha256:" + value.sha256_text(),
	}


static func _empty_receipt_v1() -> Dictionary:
	return {
		"schema_version": SCHEMA,
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "development_exact_collection_transport_retention",
			"question_class": "development"
		},
		"stage": "prepared_not_called",
		"transport_id": Transport.TRANSPORT_ID,
		"transport_failure_code": null,
		"request": null,
		"response": null,
		"source_links": {},
		"decoded_collection": null,
		"decoded_collection_is_legacy_godot_view": true,
		"raw_and_decoded_numeric_identity_claimed": false,
		"request_serialization_call_count": 0,
		"compiled_collection_call_count": 0,
		"response_json_parse_call_count": 0,
		"additional_collection_call_count": 0,
		"additional_controller_advance_count": 0,
		"additional_native_physics_read_count": 0,
		"additional_solver_step_count": 0,
		"retention_is_reconstruction": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _json_source_v1(value: Variant, depth: int = 0, source_link: bool = false) -> bool:
	# Portable requests stay finite JSON. Raw source links also keep the existing
	# finite-Vector3 transport form. No cyclic/unsupported input is repaired.
	if depth > 128:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_VECTOR3:
			# Existing raw epoch/source receipts contain finite Godot vectors.
			# Keep their exact existing transport representation in source links;
			# never convert them into invented portable request measurements.
			return source_link and value.is_finite()
		TYPE_ARRAY:
			for entry in value:
				if not _json_source_v1(entry, depth + 1, source_link):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if (
					typeof(key) != TYPE_STRING
					or not _json_source_v1(value[key], depth + 1, source_link)
				):
					return false
			return true
	return false
