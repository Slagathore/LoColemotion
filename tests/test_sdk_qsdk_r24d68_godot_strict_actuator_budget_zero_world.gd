extends SceneTree
# gdlint: disable=max-line-length

## Prospective R68 controls for the exact S169 Godot/Jolt host-cap projection
## and the strict in-run/core actuator-budget predicate. No model, world, RID,
## solver step, or native runtime observation collection is created.

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
const MARKER := "QSDK_R24D68_GODOT_STRICT_ACTUATOR_BUDGET_ZERO_WORLD "
const ACTUATOR_ID := "rear_left_hip_motor"
const CAP_NMS := 0.05637374829312699
const UPWARD_BINARY32_NMS := 0.05637374892830849
const GUARDED_BINARY32_NMS := 0.05637374520301819
const CORE_REFUSAL := "published_actuator_budget_exceeded:rear_left_hip_motor"
const V2_SCHEMA := "sporespore_qsdk_r24d68_godot_native_motor_telemetry_contract_v2"
const DIAGNOSTIC_SCHEMA := "sporespore_qsdk_r24d68_strict_actuator_budget_diagnostic_v1"


func _initialize() -> void:
	var receipt := _run()
	print(MARKER, JsonTransportScript.stringify(receipt))
	quit(0 if bool(receipt.get("ok", false)) else 1)


func _run() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R24D68_ZERO_WORLD_EXTENSION_UNAVAILABLE")
	var sdk: Object = ClassDB.instantiate(CLASS_NAME)
	if sdk == null:
		return _failure("QSDK_R24D68_ZERO_WORLD_EXTENSION_INSTANTIATION_FAILED")
	var context := RouteScript.prepare_context_v1(sdk)
	if not bool(context.get("ok", false)):
		return _failure("QSDK_R24D68_ZERO_WORLD_CONTEXT_FAILED", context)
	var fixture := RouteScript.zero_world_fixture_v1(sdk, context)
	if not bool(fixture.get("ok", false)):
		return _failure("QSDK_R24D68_ZERO_WORLD_FIXTURE_FAILED", fixture)

	var surface := RouteScript.zero_world_command_surface_v1(context)
	if not bool(surface.get("ok", false)):
		return _failure("QSDK_R24D68_ZERO_WORLD_COMMAND_SURFACE_FAILED", surface)
	var guard_receipt: Dictionary = (
		surface.get("strict_host_cap_guard_receipt", {}) as Dictionary
	).duplicate(true)
	var host_projection_counts := _host_projection_counts(guard_receipt)
	RouteScript.free_zero_world_command_surface_v1(surface)

	var adjacent_lower_nms := _rear_hip_cap_adjacent_binary64_v1(-1)
	var adjacent_upper_nms := _rear_hip_cap_adjacent_binary64_v1(1)
	if not (
		_rear_hip_cap_adjacent_binary64_v1(0) == CAP_NMS
		and adjacent_lower_nms < CAP_NMS
		and adjacent_upper_nms > CAP_NMS
	):
		return _failure("QSDK_R24D68_ZERO_WORLD_BINARY64_BOUNDARY_CONSTRUCTION_FAILED")
	var boundary_cases := [
		{"id": "positive_adjacent_lower", "value": adjacent_lower_nms, "accepted": true},
		{"id": "positive_equality", "value": CAP_NMS, "accepted": true},
		{"id": "negative_adjacent_lower", "value": -adjacent_lower_nms, "accepted": true},
		{"id": "negative_equality", "value": -CAP_NMS, "accepted": true},
		{"id": "positive_adjacent_upper", "value": adjacent_upper_nms, "accepted": false},
		{"id": "negative_adjacent_upper", "value": -adjacent_upper_nms, "accepted": false},
		{"id": "positive_upward_binary32", "value": UPWARD_BINARY32_NMS, "accepted": false},
		{"id": "negative_upward_binary32", "value": -UPWARD_BINARY32_NMS, "accepted": false},
	]
	var ordered_case_receipts: Array = []
	var native_core_agreement_count := 0
	var exact_diagnostic_count := 0
	var native_acceptance_count := 0
	var native_rejection_count := 0
	var core_acceptance_count := 0
	var core_rejection_count := 0
	var r67_like_rejection_diagnostic: Dictionary = {}
	for case_value in boundary_cases:
		var case: Dictionary = case_value
		var measured := float(case["value"])
		var expected_acceptance := bool(case["accepted"])
		var telemetry := _base_telemetry()
		telemetry["signed_motor_impulse_nms"] = measured
		var native_result := WorldScript.native_motor_telemetry_contract_v2(
			telemetry,
			ACTUATOR_ID,
			CAP_NMS,
			false,
			-1,
			NAN,
		)
		var native_accepted := bool(native_result.get("ok", false))
		var diagnostic := _diagnostic(native_result)
		var diagnostic_exact := _diagnostic_exact(
			diagnostic,
			measured,
			expected_acceptance,
		)
		var rebound := _rebind_impulse(sdk, fixture, measured)
		var core_result := RecoveryRuntimeScript.collect_native_v3(
			sdk,
			RouteScript.collection_request_v1(
				context,
				rebound,
				"candidate_command",
				"confirm_prone",
			),
		)
		var core_accepted := _collection_supported(core_result)
		var core_result_exact := (
			core_accepted
			if expected_acceptance
			else _is_budget_refusal(core_result)
		)
		var native_result_exact := (
			(
				native_accepted
				and String(native_result.get("schema_version", "")) == V2_SCHEMA
			)
			if expected_acceptance
			else (
				not native_accepted
				and String(native_result.get("failure_code", ""))
				== "QSDK_R24D68_WORLD_STRICT_ACTUATOR_BUDGET_EXCEEDED:%s" % ACTUATOR_ID
			)
		)
		native_acceptance_count += int(native_accepted)
		native_rejection_count += int(not native_accepted)
		core_acceptance_count += int(core_accepted)
		core_rejection_count += int(not core_accepted and core_result_exact)
		exact_diagnostic_count += int(diagnostic_exact)
		native_core_agreement_count += int(
			native_result_exact
			and core_result_exact
			and native_accepted == core_accepted
		)
		if String(case["id"]) == "positive_upward_binary32":
			r67_like_rejection_diagnostic = diagnostic.duplicate(true)
		ordered_case_receipts.append(
			{
				"case_id": String(case["id"]),
				"signed_motor_impulse_nms": measured,
				"expected_acceptance": expected_acceptance,
				"native_v2_accepted": native_accepted,
				"core_accepted": core_accepted,
				"core_refusal_reason": core_result.get("refusal_reason"),
				"diagnostic": diagnostic,
			}
		)

	var nonfinite_telemetry := _base_telemetry()
	nonfinite_telemetry["signed_motor_impulse_nms"] = NAN
	var nonfinite_result := WorldScript.native_motor_telemetry_contract_v2(
		nonfinite_telemetry, ACTUATOR_ID, CAP_NMS, false, -1, NAN
	)
	var nonfinite_diagnostic := _diagnostic(nonfinite_result)
	var nonfinite_value: Variant = nonfinite_diagnostic.get("signed_motor_impulse_nms")
	var nonfinite_rejection_exact := (
		not bool(nonfinite_result.get("ok", true))
		and String(nonfinite_result.get("failure_code", ""))
		== "QSDK_R24D68_WORLD_STRICT_ACTUATOR_BUDGET_EXCEEDED:%s" % ACTUATOR_ID
		and nonfinite_value is Dictionary
		and String((nonfinite_value as Dictionary).get("classification", "")) == "nan"
		and not bool(nonfinite_diagnostic.get("native_v2_strict_budget_decision", true))
		and _zero_world_receipt(nonfinite_result)
	)

	var unknown_projection := WorldScript.strict_host_impulse_cap_projection_v1(
		"unknown_motor", CAP_NMS
	)
	var mutated_cap_projection := WorldScript.strict_host_impulse_cap_projection_v1(
		ACTUATOR_ID, adjacent_upper_nms
	)
	var unknown_telemetry := WorldScript.native_motor_telemetry_contract_v2(
		_base_telemetry(), "unknown_motor", CAP_NMS, false, -1, NAN
	)
	var mutated_cap_telemetry := WorldScript.native_motor_telemetry_contract_v2(
		_base_telemetry(), ACTUATOR_ID, adjacent_upper_nms, false, -1, NAN
	)
	var identity_mutated_core := RecoveryRuntimeScript.collect_native_v3(
		sdk,
		RouteScript.collection_request_v1(
			context,
			_rebind_impulse(sdk, fixture, 0.0, "unknown_motor"),
			"candidate_command",
			"confirm_prone",
		),
	)
	var order_mutated_core := RecoveryRuntimeScript.collect_native_v3(
		sdk,
		RouteScript.collection_request_v1(
			context,
			_rebind_swapped_impulse_order(sdk, fixture),
			"candidate_command",
			"confirm_prone",
		),
	)
	var identity_order_mutation_rejection_count := 0
	for mutation_result in [
		unknown_projection,
		mutated_cap_projection,
		unknown_telemetry,
		mutated_cap_telemetry,
	]:
		identity_order_mutation_rejection_count += int(
			not bool((mutation_result as Dictionary).get("ok", true))
			and _zero_world_receipt(mutation_result)
		)
	identity_order_mutation_rejection_count += int(
		_invalid_collection(identity_mutated_core)
	)
	identity_order_mutation_rejection_count += int(
		_invalid_collection(order_mutated_core)
	)

	var agreement_positive := WorldScript.strict_actuator_budget_decision_agreement_v1(
		true, true
	)
	var disagreement_mutation := WorldScript.strict_actuator_budget_decision_agreement_v1(
		true, false
	)
	var disagreement_mutation_rejection_count := int(
		bool(agreement_positive.get("ok", false))
		and not bool(disagreement_mutation.get("ok", true))
		and String(disagreement_mutation.get("failure_code", ""))
		== "QSDK_R24D68_STRICT_ACTUATOR_BUDGET_DECISION_DISAGREEMENT"
		and _zero_world_receipt(agreement_positive)
		and _zero_world_receipt(disagreement_mutation)
	)

	var exact := (
		int(host_projection_counts.get("exact_projection_count", -1)) == 8
		and int(host_projection_counts.get("rear_floor_guard_count", -1)) == 2
		and int(host_projection_counts.get("host_cap_not_above_published_count", -1)) == 8
		and boundary_cases.size() == 8
		and native_acceptance_count == 4
		and native_rejection_count == 4
		and core_acceptance_count == 4
		and core_rejection_count == 4
		and exact_diagnostic_count == boundary_cases.size()
		and native_core_agreement_count == boundary_cases.size()
		and nonfinite_rejection_exact
		and identity_order_mutation_rejection_count == 6
		and disagreement_mutation_rejection_count == 1
		and _r67_like_diagnostic_exact(r67_like_rejection_diagnostic)
	)
	return {
		"schema_version": "sporespore_qsdk_r24d68_godot_strict_actuator_budget_zero_world_v1",
		"gate_id": "QSDK-R24D68",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R24D68_STRICT_ACTUATOR_BUDGET_ZERO_WORLD_INVALID",
		"host_projection_control_count": int(host_projection_counts.get("exact_projection_count", 0)),
		"rear_binary32_floor_guard_count": int(host_projection_counts.get("rear_floor_guard_count", 0)),
		"host_cap_not_above_published_count": int(host_projection_counts.get("host_cap_not_above_published_count", 0)),
		"strict_boundary_case_count": boundary_cases.size(),
		"native_acceptance_count": native_acceptance_count,
		"native_rejection_count": native_rejection_count,
		"core_acceptance_count": core_acceptance_count,
		"core_rejection_count": core_rejection_count,
		"exact_diagnostic_count": exact_diagnostic_count,
		"native_core_agreement_count": native_core_agreement_count,
		"nonfinite_rejection_count": int(nonfinite_rejection_exact),
		"identity_order_mutation_rejection_count": identity_order_mutation_rejection_count,
		"disagreement_mutation_rejection_count": disagreement_mutation_rejection_count,
		"ordered_boundary_case_receipts": ordered_case_receipts,
		"r67_like_upward_binary32_rejection_diagnostic": r67_like_rejection_diagnostic,
		"strict_host_cap_guard_receipt": guard_receipt,
		"threshold_changed": false,
		"margin_changed": false,
		"controller_changed": false,
		"evaluator_changed": false,
		"published_cap_changed": false,
		"raw_measurement_clamped": false,
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


## Decode the exact adjacent IEEE-754 binary64 values from their little-endian
## bit patterns. GDScript decimal literals can shorten the upper neighbor back
## onto CAP_NMS, so the mutation boundary must not depend on literal parsing.
static func _rear_hip_cap_adjacent_binary64_v1(direction: int) -> float:
	if direction == -1:
		return PackedByteArray([0x9a, 0x38, 0x8b, 0x1a, 0x05, 0xdd, 0xac, 0x3f]).decode_double(0)
	if direction == 0:
		return PackedByteArray([0x9b, 0x38, 0x8b, 0x1a, 0x05, 0xdd, 0xac, 0x3f]).decode_double(0)
	if direction == 1:
		return PackedByteArray([0x9c, 0x38, 0x8b, 0x1a, 0x05, 0xdd, 0xac, 0x3f]).decode_double(0)
	return NAN


static func _base_telemetry() -> Dictionary:
	return {
		"schema": "sporespore.godot_jolt_hinge_motor_telemetry.v2",
		"telemetry_sequence": 1,
		"capture_space_step_sequence": 1,
		"read_space_step_sequence": 1,
		"captured_during_active_step": true,
		"snapshot_is_current_space_step": true,
		"solver_step_s": 1.0 / 120.0,
		"motor_state": "velocity",
		"target_angular_velocity_rad_s": 1.0,
		"min_torque_limit_nm": 0.0,
		"max_torque_limit_nm": 0.0,
		"signed_motor_impulse_nms": 0.0,
		"positive_motor_work_j": 0.0,
		"absorbed_motor_work_j": 0.0,
		"net_motor_work_j": 0.0,
	}


static func _diagnostic(result: Dictionary) -> Dictionary:
	if bool(result.get("ok", false)):
		return (result.get("strict_actuator_budget_diagnostic", {}) as Dictionary).duplicate(true)
	var detail: Dictionary = result.get("detail", {})
	return (detail.get("strict_actuator_budget_diagnostic", {}) as Dictionary).duplicate(true)


static func _diagnostic_exact(
	diagnostic: Dictionary,
	measured: float,
	expected_acceptance: bool,
) -> bool:
	var agreement: Dictionary = diagnostic.get("decision_agreement_receipt", {})
	return (
		String(diagnostic.get("schema_version", "")) == DIAGNOSTIC_SCHEMA
		and String(diagnostic.get("actuator_id", "")) == ACTUATOR_ID
		and float(diagnostic.get("signed_motor_impulse_nms", NAN)) == measured
		and float(diagnostic.get("absolute_motor_impulse_nms", NAN)) == absf(measured)
		and float(diagnostic.get("published_maximum_outer_step_impulse_nms", NAN)) == CAP_NMS
		and float(diagnostic.get("absolute_budget_delta_nms", NAN)) == absf(measured) - CAP_NMS
		and float(diagnostic.get("effective_tolerance_nms", NAN)) == 0.0
		and bool(diagnostic.get("legacy_v1_budget_predicate_decision", false))
		and bool(diagnostic.get("native_v2_strict_budget_decision", not expected_acceptance)) == expected_acceptance
		and bool(diagnostic.get("projected_core_strict_budget_decision", not expected_acceptance)) == expected_acceptance
		and bool(diagnostic.get("native_core_budget_decisions_agree", false))
		and not bool(diagnostic.get("raw_measurement_modified", true))
		and not bool(diagnostic.get("published_cap_changed", true))
		and bool(agreement.get("ok", false))
		and _zero_world_receipt(agreement)
	)


static func _host_projection_counts(guard_receipt: Dictionary) -> Dictionary:
	var values: Variant = guard_receipt.get("ordered_bindings")
	if not values is Array or (values as Array).size() != 8:
		return {}
	var exact_projection_count := 0
	var rear_floor_guard_count := 0
	var host_cap_not_above_published_count := 0
	for index in range(8):
		var value: Dictionary = (values as Array)[index]
		var projection := WorldScript.strict_host_impulse_cap_projection_v1(
			String(value.get("actuator_id", "")),
			float(value.get("published_maximum_outer_step_impulse_nms", NAN)),
		)
		var is_rear_hip := index in [4, 6]
		var exact := (
			bool(projection.get("ok", false))
			and int(value.get("actuator_index", -1)) == index
			and value == projection.merged(
				{
					"legacy_profile_binding_readback_nms": value.get("legacy_profile_binding_readback_nms"),
					"guarded_host_readback_nms": value.get("guarded_host_readback_nms"),
				},
				true,
			)
			and float(value.get("guarded_host_readback_nms", NAN))
			== float(value.get("configured_host_maximum_impulse_nms", NAN))
			and bool(value.get("binary32_floor_guard_applied", false)) == is_rear_hip
		)
		if is_rear_hip:
			exact = (
				exact
				and float(value.get("nearest_binary32_cap_nms", NAN)) == UPWARD_BINARY32_NMS
				and float(value.get("configured_host_maximum_impulse_nms", NAN)) == GUARDED_BINARY32_NMS
				and String(value.get("configured_host_cap_binary32_hex", "")) == "0x3d66e828"
				and float(value.get("legacy_profile_binding_readback_nms", NAN)) == UPWARD_BINARY32_NMS
			)
		exact_projection_count += int(exact)
		rear_floor_guard_count += int(
			is_rear_hip and bool(value.get("binary32_floor_guard_applied", false))
		)
		host_cap_not_above_published_count += int(
			float(value.get("guarded_host_readback_nms", INF))
			<= float(value.get("published_maximum_outer_step_impulse_nms", -INF))
		)
	return {
		"exact_projection_count": exact_projection_count,
		"rear_floor_guard_count": rear_floor_guard_count,
		"host_cap_not_above_published_count": host_cap_not_above_published_count,
	}


static func _r67_like_diagnostic_exact(diagnostic: Dictionary) -> bool:
	return (
		float(diagnostic.get("signed_motor_impulse_nms", NAN)) == UPWARD_BINARY32_NMS
		and float(diagnostic.get("absolute_budget_delta_nms", NAN))
		== UPWARD_BINARY32_NMS - CAP_NMS
		and bool(diagnostic.get("legacy_v1_budget_predicate_decision", false))
		and not bool(diagnostic.get("native_v2_strict_budget_decision", true))
		and not bool(diagnostic.get("projected_core_strict_budget_decision", true))
		and bool(diagnostic.get("native_core_budget_decisions_agree", false))
		and not bool(diagnostic.get("raw_measurement_modified", true))
	)


static func _collection_supported(collection: Dictionary) -> bool:
	return (
		String(collection.get("support_status", "")) == "supported_exact"
		and collection.get("refusal_reason", "unexpected") == null
		and bool(collection.get("supplied_native_post_step_observation_validated", false))
		and _zero_world_receipt(collection)
	)


static func _is_budget_refusal(collection: Dictionary) -> bool:
	return (
		String(collection.get("support_status", "")) == "invalid_observation"
		and String(collection.get("refusal_reason", "")) == CORE_REFUSAL
		and _zero_world_receipt(collection)
	)


static func _invalid_collection(collection: Dictionary) -> bool:
	return (
		String(collection.get("support_status", "")) != "supported_exact"
		and not String(collection.get("support_status", "")).is_empty()
		and collection.get("refusal_reason") != null
		and _zero_world_receipt(collection)
	)


static func _rebind_impulse(
	sdk: Object,
	fixture: Dictionary,
	impulse_nms: float,
	actuator_id_override: String = "",
) -> Dictionary:
	var observation: Dictionary = (fixture["observation_v2"] as Dictionary).duplicate(true)
	observation["applied_actuation"]["ordered_applied_impulses"][4]["applied_angular_impulse_nms"] = impulse_nms
	if not actuator_id_override.is_empty():
		observation["applied_actuation"]["ordered_applied_impulses"][4]["actuator_id"] = actuator_id_override
	return _rebind_observation(sdk, fixture, observation)


static func _rebind_swapped_impulse_order(sdk: Object, fixture: Dictionary) -> Dictionary:
	var observation: Dictionary = (fixture["observation_v2"] as Dictionary).duplicate(true)
	var impulses: Array = observation["applied_actuation"]["ordered_applied_impulses"]
	var temporary: Variant = impulses[0]
	impulses[0] = impulses[4]
	impulses[4] = temporary
	return _rebind_observation(sdk, fixture, observation)


static func _rebind_observation(
	sdk: Object,
	fixture: Dictionary,
	observation: Dictionary,
) -> Dictionary:
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


static func _zero_world_receipt(receipt: Dictionary) -> bool:
	return (
		int(receipt.get("model_construction_count", -1)) == 0
		and int(receipt.get("world_attempt_count", -1)) == 0
		and int(receipt.get("world_build_count", -1)) == 0
		and int(receipt.get("solver_step_count", -1)) == 0
		and not bool(receipt.get("physics_state_modified", true))
	)


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r24d68_godot_strict_actuator_budget_zero_world_v1",
		"gate_id": "QSDK-R24D68",
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
