extends SceneTree
# gdlint: disable=max-line-length

## Zero-world production-decoder regression for the exact R71 contact
## provenance shape that R73 exposed after its first native step.

const RouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
)
const RuntimeScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_runtime.gd"
)
const NativeWorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D74_GODOT_CONTACT_PROVENANCE_SCHEMA_ZERO_WORLD "
const SOURCE_KIND := "native_post_solve_contact_constraint_lambda"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(MARKER, JsonTransportScript.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D74_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D74_EXTENSION_INSTANTIATION_FAILED")
	var context := RouteScript.prepare_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return _failure("QSDK_R24D74_CONTEXT_FAILED", context)
	var bound := RouteScript.zero_world_fixture_v1(sdk, context)
	if not bool(bound.get("ok", false)):
		return _failure("QSDK_R24D74_BASE_FIXTURE_FAILED", bound)

	var exact_request := RouteScript.collection_request_v1(
		context, bound, "candidate_command", "establish_distal_support"
	)
	_add_exact_source_provenance(exact_request)
	if not _rebind_request(sdk, exact_request):
		return _failure("QSDK_R24D74_EXACT_REBIND_FAILED")
	var exact_receipt := RuntimeScript.collect_native_v3(sdk, exact_request)

	var missing_kind := exact_request.duplicate(true)
	_remove_contact_field(missing_kind, "impulse_source_kind")
	if not _rebind_request(sdk, missing_kind):
		return _failure("QSDK_R24D74_MISSING_KIND_REBIND_FAILED")
	var missing_kind_receipt := RuntimeScript.collect_native_v3(sdk, missing_kind)

	var missing_profile := exact_request.duplicate(true)
	_remove_contact_field(missing_profile, "impulse_source_profile_id")
	if not _rebind_request(sdk, missing_profile):
		return _failure("QSDK_R24D74_MISSING_PROFILE_REBIND_FAILED")
	var missing_profile_receipt := RuntimeScript.collect_native_v3(sdk, missing_profile)

	var unknown := exact_request.duplicate(true)
	var unknown_contacts: Array = (
		(unknown["observation"] as Dictionary)["state"] as Dictionary
	)["ordered_contact_observations"]
	(unknown_contacts[0]["provenance"] as Dictionary)["unqualified_source_hint"] = true
	if not _rebind_request(sdk, unknown):
		return _failure("QSDK_R24D74_UNKNOWN_REBIND_FAILED")
	var unknown_receipt := RuntimeScript.collect_native_v3(sdk, unknown)

	var exact := (
		String(exact_receipt.get("support_status", "")) == "supported_exact"
		and bool(exact_receipt.get("supplied_native_post_step_observation_validated", false))
		and String(missing_kind_receipt.get("support_status", "")) == "invalid_observation"
		and String(missing_kind_receipt.get("refusal_reason", "")).contains(
			"incomplete_impulse_source_provenance"
		)
		and String(missing_profile_receipt.get("support_status", "")) == "invalid_observation"
		and String(missing_profile_receipt.get("refusal_reason", "")).contains(
			"incomplete_impulse_source_provenance"
		)
		and String(unknown_receipt.get("failure_code", "")) == "SCHEMA_INVALID"
	)
	return {
		"schema_version": "sporespore_qsdk_r24d74_godot_contact_provenance_schema_zero_world_v1",
		"gate_id": "QSDK-R24D74",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D74_CONJUNCTION_INVALID",
		"exact_impulse_source_profile_id": NativeWorldScript.SOLVED_CONTACT_TELEMETRY_PROFILE_ID,
		"exact_impulse_source_kind": SOURCE_KIND,
		"production_decoder_positive_count": int(
			String(exact_receipt.get("support_status", "")) == "supported_exact"
		),
		"missing_half_mutation_count": 2,
		"missing_half_mutation_rejection_count": (
			int(String(missing_kind_receipt.get("support_status", "")) == "invalid_observation")
			+ int(String(missing_profile_receipt.get("support_status", "")) == "invalid_observation")
		),
		"missing_kind_support_status": String(
			missing_kind_receipt.get("support_status", "")
		),
		"missing_kind_refusal_reason": String(
			missing_kind_receipt.get("refusal_reason", "")
		),
		"missing_profile_support_status": String(
			missing_profile_receipt.get("support_status", "")
		),
		"missing_profile_refusal_reason": String(
			missing_profile_receipt.get("refusal_reason", "")
		),
		"unknown_field_failure_code": String(unknown_receipt.get("failure_code", "")),
		"unknown_field_mutation_rejection_count": int(
			String(unknown_receipt.get("failure_code", "")) == "SCHEMA_INVALID"
		),
		"native_runtime_observation_collection_executed": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _add_exact_source_provenance(request: Dictionary) -> void:
	var contacts: Array = (
		(request["observation"] as Dictionary)["state"] as Dictionary
	)["ordered_contact_observations"]
	for contact_value in contacts:
		var provenance: Dictionary = (contact_value as Dictionary)["provenance"]
		provenance["impulse_source_profile_id"] = (
			NativeWorldScript.SOLVED_CONTACT_TELEMETRY_PROFILE_ID
		)
		provenance["impulse_source_kind"] = SOURCE_KIND


static func _remove_contact_field(request: Dictionary, field: String) -> void:
	var contacts: Array = (
		(request["observation"] as Dictionary)["state"] as Dictionary
	)["ordered_contact_observations"]
	(contacts[0]["provenance"] as Dictionary).erase(field)


static func _rebind_request(sdk: Object, request: Dictionary) -> bool:
	var observation: Dictionary = request["observation"]
	var observation_base := observation.duplicate(true)
	observation_base.erase("schema_version")
	observation_base.erase("energy_balance")
	var binding: Dictionary = request["observation_source_binding"]
	binding["observation_base_sha256"] = RouteScript._sha256(sdk, observation_base)
	binding["ledger_sha256"] = RouteScript._sha256(sdk, observation["energy_balance"])
	binding["portable_observation_sha256"] = RouteScript._sha256(sdk, observation)
	binding.erase("source_chain_sha256")
	binding["source_chain_sha256"] = RouteScript._sha256(sdk, binding)
	return (
		String(binding["observation_base_sha256"]).begins_with("sha256:")
		and String(binding["ledger_sha256"]).begins_with("sha256:")
		and String(binding["portable_observation_sha256"]).begins_with("sha256:")
		and String(binding["source_chain_sha256"]).begins_with("sha256:")
	)


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d74_godot_contact_provenance_schema_zero_world_v1",
		"gate_id": "QSDK-R24D74",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_opened": false,
		"prone_to_standing_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
