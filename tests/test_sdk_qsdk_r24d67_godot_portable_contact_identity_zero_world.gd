extends SceneTree
# gdlint: disable=max-line-length

## Pure R67 controls for the native Godot shape-pair identity -> portable
## protocol identity seam. The exact production projector and portable core
## collector run, but no Node, RID, model, world, or solver step is created.

const WorldScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
)
const RouteScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
)
const RecoveryRuntimeScript := preload(
	"res://sdk/adapters/godot/gdscript/recovery_runtime.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const MARKER := "QSDK_R24D67_GODOT_PORTABLE_CONTACT_IDENTITY_ZERO_WORLD "
const OBSERVED_RAW_ID := "rear_left_distal:0|floor:0"
const OBSERVED_RAW_UTF8_HEX := "726561725f6c6566745f64697374616c3a307c666c6f6f723a30"
const OBSERVED_PORTABLE_ID := (
	"godot_contact_"
	+ "726561725f6c6566745f64697374616c3a307c666c6f6f723a30"
)
const CORE_REFUSAL := (
	"state_frame_invalid:IDENTITY_INVALID:engine_contact_id:"
	+ OBSERVED_RAW_ID
)


func _initialize() -> void:
	var receipt := _run()
	print(MARKER, JsonTransportScript.stringify(receipt))
	quit(0 if bool(receipt.get("ok", false)) else 1)


func _run() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D67_ZERO_WORLD_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D67_ZERO_WORLD_EXTENSION_INSTANTIATION_FAILED")
	var context := RouteScript.prepare_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return _failure("QSDK_R24D67_ZERO_WORLD_CONTEXT_FAILED", context)
	var fixture := RouteScript.zero_world_fixture_v1(sdk, context)
	if not bool(fixture.get("ok", false)):
		return _failure("QSDK_R24D67_ZERO_WORLD_FIXTURE_FAILED", fixture)

	var empty_projection := WorldScript.native_contact_identity_projection_v2([])
	var empty_projection_exact: bool = (
		bool(empty_projection.get("ok", false))
		and int(empty_projection.get("raw_contact_point_identity_count", -1)) == 0
		and int(empty_projection.get("unique_raw_shape_pair_identity_count", -1)) == 0
		and int(empty_projection.get("duplicate_raw_shape_pair_identity_count", -1)) == 0
		and int(empty_projection.get("portable_engine_contact_identity_count", -1)) == 0
		and empty_projection.get("engine_contact_ids", ["unexpected"]) == []
		and empty_projection.get("raw_to_portable_identity_pairs", ["unexpected"]) == []
		and _zero_world_receipt(empty_projection)
	)

	var observed_projection := WorldScript.native_contact_identity_projection_v2(
		[OBSERVED_RAW_ID]
	)
	var observed_projection_exact: bool = (
		bool(observed_projection.get("ok", false))
		and String(observed_projection.get("schema_version", ""))
		== "sporespore_qsdk_r24d67_godot_contact_identity_projection_v2"
		and String(observed_projection.get("method_id", ""))
		== "godot_utf8_hex_portable_contact_identity_v1"
		and observed_projection.get("engine_contact_ids", [])
		== [OBSERVED_PORTABLE_ID]
		and int(observed_projection.get("raw_contact_point_identity_count", -1)) == 1
		and int(observed_projection.get("unique_raw_shape_pair_identity_count", -1)) == 1
		and int(observed_projection.get("duplicate_raw_shape_pair_identity_count", -1)) == 0
		and int(observed_projection.get("portable_engine_contact_identity_count", -1)) == 1
		and int(observed_projection.get("portable_identity_collision_count", -1)) == 0
		and bool(observed_projection.get("stable_first_observation_order_preserved", false))
		and bool(observed_projection.get("lossless_raw_identity_embedded", false))
		and not bool(observed_projection.get("hash_or_truncation_used", true))
		and _observed_mapping_exact(observed_projection)
		and _zero_world_receipt(observed_projection)
	)

	var historical_projection := WorldScript.native_contact_identity_projection_v1(
		[OBSERVED_RAW_ID]
	)
	var historical_mismatch_reproduced: bool = (
		bool(historical_projection.get("ok", false))
		and historical_projection.get("engine_contact_ids", []) == [OBSERVED_RAW_ID]
		and not WorldScript.portable_identity_grammar_valid_v1(OBSERVED_RAW_ID)
	)

	var raw_bound := _rebind_contact_identity(sdk, fixture, OBSERVED_RAW_ID)
	var raw_collection := RecoveryRuntimeScript.collect_native_v3(
		sdk,
		RouteScript.collection_request_v1(
			context,
			raw_bound,
			"candidate_command",
			"confirm_prone",
		),
	)
	var raw_core_refusal_exact := _is_observed_identity_refusal(raw_collection)

	var projected_bound := _rebind_contact_identity(sdk, fixture, OBSERVED_PORTABLE_ID)
	var projected_collection := RecoveryRuntimeScript.collect_native_v3(
		sdk,
		RouteScript.collection_request_v1(
			context,
			projected_bound,
			"candidate_command",
			"confirm_prone",
		),
	)
	var projected_core_acceptance_exact := _collection_supported(projected_collection)

	# These first two raw strings collide under common punctuation-to-underscore
	# sanitizers. Exact UTF-8 hex must keep them distinct and stable.
	var collision_tricky_raw := [
		"shape:a|floor:0",
		"shape_a_floor_0",
		"shape:a|floor:0",
		"shape_a|floor:0",
	]
	var stable_projection := WorldScript.native_contact_identity_projection_v2(
		collision_tricky_raw
	)
	var expected_order := [
		_portable_id("shape:a|floor:0"),
		_portable_id("shape_a_floor_0"),
		_portable_id("shape_a|floor:0"),
	]
	var collision_and_order_control_exact: bool = (
		bool(stable_projection.get("ok", false))
		and int(stable_projection.get("raw_contact_point_identity_count", -1)) == 4
		and int(stable_projection.get("unique_raw_shape_pair_identity_count", -1)) == 3
		and int(stable_projection.get("duplicate_raw_shape_pair_identity_count", -1)) == 1
		and int(stable_projection.get("portable_engine_contact_identity_count", -1)) == 3
		and int(stable_projection.get("portable_identity_collision_count", -1)) == 0
		and stable_projection.get("engine_contact_ids", []) == expected_order
		and expected_order[0] != expected_order[1]
		and expected_order[0] != expected_order[2]
		and expected_order[1] != expected_order[2]
		and bool(stable_projection.get("stable_first_observation_order_preserved", false))
		and _zero_world_receipt(stable_projection)
	)
	var utf8_projection := WorldScript.portable_contact_identity_v1(
		"shape_µ:0|floor:0"
	)
	var utf8_projection_exact: bool = (
		bool(utf8_projection.get("ok", false))
		and String(utf8_projection.get("raw_utf8_hex", ""))
		== "73686170655fc2b53a307c666c6f6f723a30"
		and String(utf8_projection.get("portable_engine_contact_id", ""))
		== "godot_contact_73686170655fc2b53a307c666c6f6f723a30"
		and bool(utf8_projection.get("portable_identity_grammar_valid", false))
		and bool(utf8_projection.get("lossless_raw_identity_embedded", false))
		and not bool(utf8_projection.get("hash_or_truncation_used", true))
		and _zero_world_receipt(utf8_projection)
	)

	var mutations := [
		{
			"id": "non_string_identity",
			"raw": [7],
			"failure_code": "QSDK_R24D67_CONTACT_ID_TYPE_INVALID",
		},
		{
			"id": "empty_identity",
			"raw": [""],
			"failure_code": "QSDK_R24D67_CONTACT_ID_EMPTY",
		},
		{
			"id": "whitespace_identity",
			"raw": ["   "],
			"failure_code": "QSDK_R24D67_CONTACT_ID_EMPTY",
		},
	]
	var mutation_ids: Array = []
	var mutation_rejection_count := 0
	for mutation_value in mutations:
		var mutation: Dictionary = mutation_value
		var mutation_result := WorldScript.native_contact_identity_projection_v2(
			mutation["raw"]
		)
		mutation_ids.append(String(mutation["id"]))
		mutation_rejection_count += int(
			not bool(mutation_result.get("ok", true))
			and String(mutation_result.get("failure_code", ""))
			== String(mutation["failure_code"])
			and _zero_world_receipt(mutation_result)
		)

	var ok: bool = (
		empty_projection_exact
		and observed_projection_exact
		and historical_mismatch_reproduced
		and raw_core_refusal_exact
		and projected_core_acceptance_exact
		and collision_and_order_control_exact
		and utf8_projection_exact
		and mutation_rejection_count == mutations.size()
	)
	return {
		"schema_version": "sporespore_qsdk_r24d67_godot_portable_contact_identity_zero_world_v1",
		"gate_id": "QSDK-R24D67",
		"ok": ok,
		"failure_code": "" if ok else "QSDK_R24D67_PORTABLE_CONTACT_IDENTITY_INVALID",
		"empty_projection_control_count": int(empty_projection_exact),
		"empty_projection": empty_projection,
		"observed_raw_engine_contact_id": OBSERVED_RAW_ID,
		"observed_raw_utf8_hex": OBSERVED_RAW_UTF8_HEX,
		"observed_portable_engine_contact_id": OBSERVED_PORTABLE_ID,
		"observed_projection_exact_count": int(observed_projection_exact),
		"observed_projection": observed_projection,
		"historical_mismatch_reproduction_count": int(historical_mismatch_reproduced),
		"raw_core_refusal_count": int(raw_core_refusal_exact),
		"raw_core_refusal_reason": raw_collection.get("refusal_reason"),
		"projected_core_acceptance_count": int(projected_core_acceptance_exact),
		"collision_tricky_control_count": int(collision_and_order_control_exact),
		"collision_tricky_projection": stable_projection,
		"utf8_projection_control_count": int(utf8_projection_exact),
		"utf8_projection": utf8_projection,
		"mutation_ids": mutation_ids,
		"mutation_rejection_count": mutation_rejection_count,
		"threshold_changed": false,
		"controller_changed": false,
		"evaluator_changed": false,
		"native_physics_changed": false,
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


static func _observed_mapping_exact(projection: Dictionary) -> bool:
	var pairs_value: Variant = projection.get("raw_to_portable_identity_pairs")
	if not pairs_value is Array or (pairs_value as Array).size() != 1:
		return false
	var mapping_value: Variant = (pairs_value as Array)[0]
	if not mapping_value is Dictionary:
		return false
	var mapping: Dictionary = mapping_value
	return (
		String(mapping.get("raw_engine_contact_id", "")) == OBSERVED_RAW_ID
		and String(mapping.get("raw_utf8_hex", "")) == OBSERVED_RAW_UTF8_HEX
		and String(mapping.get("portable_engine_contact_id", "")) == OBSERVED_PORTABLE_ID
		and bool(mapping.get("lossless_raw_identity_embedded", false))
	)


static func _portable_id(raw_id: String) -> String:
	var receipt := WorldScript.portable_contact_identity_v1(raw_id)
	return String(receipt.get("portable_engine_contact_id", ""))


static func _collection_supported(collection: Dictionary) -> bool:
	return (
		String(collection.get("support_status", "")) == "supported_exact"
		and collection.get("refusal_reason", "unexpected") == null
		and bool(collection.get("supplied_native_post_step_observation_validated", false))
		and _zero_world_receipt(collection)
	)


static func _is_observed_identity_refusal(collection: Dictionary) -> bool:
	return (
		String(collection.get("support_status", "")) == "invalid_observation"
		and String(collection.get("refusal_reason", "")) == CORE_REFUSAL
		and _zero_world_receipt(collection)
	)


static func _zero_world_receipt(receipt: Dictionary) -> bool:
	return (
		int(receipt.get("model_construction_count", -1)) == 0
		and int(receipt.get("world_attempt_count", -1)) == 0
		and int(receipt.get("world_build_count", -1)) == 0
		and int(receipt.get("solver_step_count", -1)) == 0
		and not bool(receipt.get("physics_state_modified", true))
	)


static func _rebind_contact_identity(
	sdk: Object,
	fixture: Dictionary,
	engine_contact_id: String,
) -> Dictionary:
	var observation: Dictionary = (fixture["observation_v2"] as Dictionary).duplicate(true)
	observation["state"]["ordered_contact_observations"][0]["provenance"]["engine_contact_ids"] = [
		engine_contact_id
	]
	var observation_base := observation.duplicate(true)
	observation_base.erase("schema_version")
	observation_base.erase("energy_balance")
	var binding: Dictionary = (fixture["source_binding"] as Dictionary).duplicate(true)
	binding["observation_base_sha256"] = _sha256(sdk, observation_base)
	binding["ledger_sha256"] = _sha256(sdk, observation["energy_balance"])
	binding["portable_observation_sha256"] = _sha256(sdk, observation)
	binding.erase("source_chain_sha256")
	binding["source_chain_sha256"] = _sha256(sdk, binding)
	return {
		"observation_v2": observation,
		"observation_v3": (fixture["observation_v3"] as Dictionary).duplicate(true),
		"source_binding": binding,
	}


static func _sha256(sdk: Object, value: Variant) -> String:
	var receipt := RecoveryRuntimeScript.canonicalize(sdk, value)
	return String(receipt.get("sha256", ""))


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d67_godot_portable_contact_identity_zero_world_v1",
		"gate_id": "QSDK-R24D67",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
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
