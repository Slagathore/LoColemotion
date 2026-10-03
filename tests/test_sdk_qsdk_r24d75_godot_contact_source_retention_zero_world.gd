extends SceneTree
# gdlint: disable=max-line-length

## Complete pure-data branch population for the production R75 contact-source
## retention seam. No model, world, RID, or solver step exists.

const WorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const RuntimeScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_runtime.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D75_GODOT_CONTACT_SOURCE_RETENTION_ZERO_WORLD "
const RETENTION_SCHEMA := (
	"sporespore_qsdk_r24d75_godot_contact_source_retention_v1"
)
const FAILURE_CODE := "QSDK_R24D75_WORLD_CONTACT_SOURCE_RETENTION_INVALID"
const EXPECTED_STEP := 7


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var receipt := _evaluate()
	print(MARKER, JsonTransportScript.stringify(receipt))
	quit(0 if bool(receipt.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D75_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D75_EXTENSION_INSTANTIATION_FAILED")

	var populated_contact := _contact_receipt(8)
	var populated := WorldScript.retain_contact_source_receipt_v1(
		sdk, populated_contact
	)
	var zero_contact := _contact_receipt(0)
	var zero := WorldScript.retain_contact_source_receipt_v1(sdk, zero_contact)
	var populated_source: Dictionary = populated.get("contact_source_receipt", {})
	var zero_source: Dictionary = zero.get("contact_source_receipt", {})
	var populated_digest_exact := (
		String(populated.get("contact_source_sha256", ""))
		== _canonical_sha256(sdk, populated_source)
	)
	var zero_digest_exact := (
		String(zero.get("contact_source_sha256", ""))
		== _canonical_sha256(sdk, zero_source)
	)

	var original_source: Dictionary = populated_contact["source_receipt"]
	var original_contract: Dictionary = original_source[
		"solved_contact_telemetry_contract"
	]
	original_contract["exact_contact_point_count"] = 99
	var retained_contract: Dictionary = populated_source[
		"solved_contact_telemetry_contract"
	]
	var deep_copy_isolated := int(retained_contract["exact_contact_point_count"]) == 8

	var mutations: Array = []
	mutations.append({"first": "contact_receipt_dictionary", "value": null})
	mutations.append({"first": "source_receipt_dictionary", "value": {}})
	var wrong_source_schema := _contact_receipt(8)
	(wrong_source_schema["source_receipt"] as Dictionary)["schema_version"] = "wrong"
	mutations.append({"first": "source_schema_exact", "value": wrong_source_schema})
	var missing_contract := _contact_receipt(8)
	(missing_contract["source_receipt"] as Dictionary).erase(
		"solved_contact_telemetry_contract"
	)
	mutations.append({"first": "solved_contract_dictionary", "value": missing_contract})
	var wrong_contract_schema := _contact_receipt(8)
	_contract(wrong_contract_schema)["schema_version"] = "wrong"
	mutations.append(
		{"first": "solved_contract_schema_exact", "value": wrong_contract_schema}
	)
	var contract_not_ok := _contact_receipt(8)
	_contract(contract_not_ok)["ok"] = false
	mutations.append({"first": "solved_contract_ok_true", "value": contract_not_ok})
	var classifier_not_int := _contact_receipt(8)
	_contract(classifier_not_int)["exact_contact_point_count"] = 8.0
	mutations.append(
		{"first": "exact_contact_point_count_int", "value": classifier_not_int}
	)
	var classifier_negative := _contact_receipt(8)
	_contract(classifier_negative)["exact_contact_point_count"] = -1
	mutations.append(
		{
			"first": "exact_contact_point_count_nonnegative",
			"value": classifier_negative,
		}
	)

	var exact_rejection_count := 0
	for mutation_value in mutations:
		var mutation: Dictionary = mutation_value
		var result := WorldScript.retain_contact_source_receipt_v1(
			sdk, mutation["value"]
		)
		exact_rejection_count += int(_rejected(result, String(mutation["first"])))

	var positives_exact := (
		bool(populated.get("ok", false))
		and String(populated.get("schema_version", "")) == RETENTION_SCHEMA
		and int(populated.get("exact_contact_point_count", -1)) == 8
		and int(retained_contract.get("exact_contact_point_count", -1)) == 8
		and bool(zero.get("ok", false))
		and String(zero.get("schema_version", "")) == RETENTION_SCHEMA
		and int(zero.get("exact_contact_point_count", -1)) == 0
		and int(
			(zero_source["solved_contact_telemetry_contract"] as Dictionary).get(
				"exact_contact_point_count", -1
			)
		) == 0
	)
	var exact := (
		positives_exact
		and populated_digest_exact
		and zero_digest_exact
		and deep_copy_isolated
		and mutations.size() == 8
		and exact_rejection_count == mutations.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d75_godot_contact_source_retention_zero_world_v1",
		"gate_id": "QSDK-R24D75",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D75_CONTACT_SOURCE_RETENTION_CONJUNCTION_INVALID",
		"retained_populated_count": int(bool(populated.get("ok", false))),
		"retained_zero_count": int(bool(zero.get("ok", false))),
		"populated_exact_contact_point_count": int(
			populated.get("exact_contact_point_count", -1)
		),
		"zero_exact_contact_point_count": int(zero.get("exact_contact_point_count", -1)),
		"canonical_digest_recompute_count": (
			int(populated_digest_exact) + int(zero_digest_exact)
		),
		"deep_copy_isolation_count": int(deep_copy_isolated),
		"mutation_population_count": mutations.size(),
		"exact_mutation_rejection_count": exact_rejection_count,
		"native_runtime_observation_collection_executed": false,
		"held_out_cell_access_count": 0,
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


static func _contact_receipt(point_count: int) -> Dictionary:
	var telemetry := _base_telemetry(point_count)
	var solved_contract := WorldScript.native_solved_contact_telemetry_contract_v1(
		telemetry, EXPECTED_STEP
	)
	return {
		"source_receipt": {
			"schema_version": WorldScript.SOLVED_CONTACT_SOURCE_SCHEMA,
			"semantic_step": EXPECTED_STEP,
			"native_space_step_sequence": EXPECTED_STEP,
			"solved_contact_telemetry_contract": solved_contract,
			"ordered_contact_samples": [],
			"ordered_contact_identity_projections": [],
			"source_measurement": true,
		},
	}


static func _base_telemetry(point_count: int) -> Dictionary:
	var manifold_count := 0 if point_count == 0 else 3
	return {
		"schema": "sporespore.godot_jolt_solved_contact_telemetry.v1",
		"profile_id": "godot_4_7_jolt_sporespore_solved_contact_telemetry_v1",
		"capture_space_step_sequence": EXPECTED_STEP,
		"read_space_step_sequence": EXPECTED_STEP,
		"captured_during_active_step": true,
		"snapshot_is_current_space_step": true,
		"reported_manifold_count": manifold_count,
		"reported_contact_point_count": point_count,
		"exact_manifold_count": manifold_count,
		"exact_contact_point_count": point_count,
		"missing_manifold_count": 0,
		"ccd_only_manifold_count": 0,
		"point_count_mismatch_count": 0,
		"nonfinite_impulse_count": 0,
		"complete": true,
	}


static func _contract(contact_receipt: Dictionary) -> Dictionary:
	var source: Dictionary = contact_receipt["source_receipt"]
	return source["solved_contact_telemetry_contract"]


static func _canonical_sha256(sdk: Object, value: Variant) -> String:
	return String(RuntimeScript.canonicalize(sdk, value).get("sha256", ""))


static func _rejected(result: Dictionary, first_invariant: String) -> bool:
	var detail: Dictionary = result.get("detail", {})
	return (
		not bool(result.get("ok", true))
		and String(result.get("failure_code", "")) == FAILURE_CODE
		and String(detail.get("schema_version", "")) == RETENTION_SCHEMA
		and String(detail.get("first_failed_invariant_id", "")) == first_invariant
	)


static func _failure(code: String) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d75_godot_contact_source_retention_zero_world_v1",
		"gate_id": "QSDK-R24D75",
		"ok": false,
		"failure_code": code,
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
