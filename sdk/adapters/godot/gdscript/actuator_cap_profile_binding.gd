class_name SporeActuatorCapProfileBinding
extends RefCounted

## Fail-closed, zero-world binding of a resolved public actuator-cap profile.
##
## All receipt, order, cap, and host-object checks complete before the first
## write. The eight HingeJoint3D values must be unparented and outside the
## SceneTree. A readback mismatch rolls every written value back.

const RECEIPT_SCHEMA_VERSION := "sporespore_actuator_cap_profile_receipt_v1"
const PROFILE_SCHEMA_VERSION := "sporespore_actuator_cap_profile_v1"
const BINDING_RECEIPT_SCHEMA_VERSION := (
	"sporespore_godot_actuator_cap_profile_binding_receipt_v1"
)
const PROFILE_ID := "sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1"
const PROFILE_SHA256 := (
	"sha256:b65d41e3f30c42e0a8207f1385fe00daa8f03975f4e266a0bd0867970f674964"
)
const DESCRIPTOR_SHA256 := (
	"sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0"
)
const MORPHOLOGY_SPEC_SHA256 := (
	"sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e"
)
const SEMANTICS_ID := "sporespore_outer_control_step_angular_impulse_budget_120hz_v1"
const HOST_MAPPING_ID := "sporespore_godot_hinge_maximum_impulse_cap_mapping_v1"
const MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS := 2.5e-7
const SEMANTIC_DURATION_JSON_TRANSPORT_TOLERANCE_S := 6.938893903907228e-18

const ORDERED_ACTUATOR_IDS := [
	"front_left_hip_motor",
	"front_left_knee_motor",
	"front_right_hip_motor",
	"front_right_knee_motor",
	"rear_left_hip_motor",
	"rear_left_knee_motor",
	"rear_right_hip_motor",
	"rear_right_knee_motor",
]
const ORDERED_JOINT_IDS := [
	"front_left_hip",
	"front_left_knee",
	"front_right_hip",
	"front_right_knee",
	"rear_left_hip",
	"rear_left_knee",
	"rear_right_hip",
	"rear_right_knee",
]
const ORDERED_CAPS_NMS := [
	0.05362625170687301,
	0.4567500054836273,
	0.05362625170687301,
	0.4567500054836273,
	0.05637374829312699,
	0.4567500054836273,
	0.05637374829312699,
	0.4567500054836273,
]
const ORDERED_BASE_CAPS_NMS := [
	0.05362625170687301,
	0.04387602412380519,
	0.05362625170687301,
	0.04387602412380519,
	0.056373748293126996,
	0.046123975876194816,
	0.056373748293126996,
	0.046123975876194816,
]
const ORDERED_BASE_CAPS_BINARY64_HEX := [
	"0x3fab74e66a937fb7",
	"0x3fa676eb1161687e",
	"0x3fab74e66a937fb7",
	"0x3fa676eb1161687e",
	"0x3facdd051a8b389c",
	"0x3fa79d8fcfe64597",
	"0x3facdd051a8b389c",
	"0x3fa79d8fcfe64597",
]
const ORDERED_CAPS_BINARY64_HEX := [
	"0x3fab74e66a937fb7",
	"0x3fdd3b6460000000",
	"0x3fab74e66a937fb7",
	"0x3fdd3b6460000000",
	"0x3facdd051a8b389b",
	"0x3fdd3b6460000000",
	"0x3facdd051a8b389b",
	"0x3fdd3b6460000000",
]
const ORDERED_ULP_DISTANCES := [
	"0",
	"15415674031478658",
	"0",
	"15415674031478658",
	"1",
	"15091710041897577",
	"1",
	"15091710041897577",
]

var _bound := false


func bind_profile(
	resolution_receipt: Dictionary,
	host_joint_by_actuator_id: Dictionary,
	readback_tolerance_nms: float = MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS,
) -> Dictionary:
	if _bound:
		return _failure("QSDK_R23D61_GODOT_DUPLICATE_BINDING_REJECTED")
	var preflight := _preflight(
		resolution_receipt,
		host_joint_by_actuator_id,
		readback_tolerance_nms,
	)
	if not bool(preflight.get("ok", false)):
		return preflight

	var bindings: Array = preflight["ordered_bindings"]
	var write_count := 0
	for binding_value in bindings:
		var binding: Dictionary = binding_value
		var joint: HingeJoint3D = binding["joint"]
		joint.set_param(
			HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,
			float(binding["declared_maximum_impulse_nms"]),
		)
		write_count += 1

	var ordered_receipts: Array = []
	var maximum_readback_error_nms := 0.0
	for binding_value in bindings:
		var binding: Dictionary = binding_value
		var joint: HingeJoint3D = binding["joint"]
		var readback := float(
			joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE)
		)
		var error := absf(
			readback - float(binding["declared_maximum_impulse_nms"])
		)
		if not is_finite(readback) or error > readback_tolerance_nms:
			var rollback_count := _rollback(bindings)
			var failure := _failure(
				"QSDK_R23D61_GODOT_POSTWRITE_READBACK_INVALID",
				{
					"write_count": write_count,
					"rollback_count": rollback_count,
					"host_configuration_restored": rollback_count == bindings.size(),
				},
			)
			failure["host_configuration_modified"] = true
			failure["host_configuration_restored"] = (
				rollback_count == bindings.size()
			)
			failure["write_count"] = write_count
			failure["rollback_count"] = rollback_count
			return failure
		maximum_readback_error_nms = maxf(maximum_readback_error_nms, error)
		ordered_receipts.append(
			{
				"actuator_id": String(binding["actuator_id"]),
				"joint_id": String(binding["joint_id"]),
				"declared_maximum_outer_step_impulse_nms": float(
					binding["declared_maximum_impulse_nms"]
				),
				"godot_maximum_impulse_readback_nms": readback,
				"readback_error_nms": error,
				"host_instance_id": int(joint.get_instance_id()),
			}
		)

	_bound = true
	return {
		"schema_version": BINDING_RECEIPT_SCHEMA_VERSION,
		"ok": true,
		"failure_code": "",
		"host_mapping_id": HOST_MAPPING_ID,
		"profile_id": PROFILE_ID,
		"profile_sha256": PROFILE_SHA256,
		"portable_semantics_id": SEMANTICS_ID,
		"host_parameter": "HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE",
		"ordered_bindings": ordered_receipts,
		"validated_actuator_count": bindings.size(),
		"unique_host_joint_object_count": bindings.size(),
		"host_object_creation_count": 0,
		"write_count": write_count,
		"readback_count": ordered_receipts.size(),
		"rollback_count": 0,
		"readback_tolerance_nms": readback_tolerance_nms,
		"maximum_readback_error_nms": maximum_readback_error_nms,
		"numeric_adequacy": {
			"kind": "configured_parameter_readback_tolerance_not_physical_margin",
			"source": "inherited_godot_4_7_hinge_parameter_round_trip_gate",
			"applies_only_to": "unparented_hinge_configuration_write_readback",
			"population_claim": false,
			"physical_claim": false,
		},
		"host_configuration_modified": true,
		"host_configuration_restored": false,
		"all_host_objects_unparented": true,
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"turning_claimed": false,
		"prone_to_standing_claimed": false,
		"cross_engine_equivalence_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


func _preflight(
	receipt: Dictionary,
	host_joint_by_actuator_id: Dictionary,
	readback_tolerance_nms: float,
) -> Dictionary:
	if (
		not is_finite(readback_tolerance_nms)
		or readback_tolerance_nms <= 0.0
		or readback_tolerance_nms > MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS
	):
		return _failure("QSDK_R23D61_GODOT_READBACK_TOLERANCE_INVALID")
	if not _keys_exact(
		receipt,
		[
			"schema_version",
			"requested_profile_id",
			"supported_profile_ids",
			"support_status",
			"refusal_reason",
			"descriptor_sha256",
			"morphology_spec_sha256",
			"profile",
			"profile_sha256",
			"world_build_count",
			"physics_state_modified",
			"physical_acceptance_authority",
			"release_authority",
		],
	):
		return _failure("QSDK_R23D61_GODOT_RECEIPT_FIELDS_INVALID")
	if String(receipt.get("schema_version", "")) != RECEIPT_SCHEMA_VERSION:
		return _failure("QSDK_R23D61_GODOT_RECEIPT_SCHEMA_INVALID")
	if (
		String(receipt.get("requested_profile_id", "")) != PROFILE_ID
		or receipt.get("supported_profile_ids", []) != [PROFILE_ID]
		or String(receipt.get("support_status", "")) != "supported_exact"
		or receipt.get("refusal_reason", "unexpected") != null
	):
		return _failure("QSDK_R23D61_GODOT_PROFILE_SUPPORT_INVALID")
	if (
		String(receipt.get("descriptor_sha256", "")) != DESCRIPTOR_SHA256
		or String(receipt.get("morphology_spec_sha256", ""))
		!= MORPHOLOGY_SPEC_SHA256
		or String(receipt.get("profile_sha256", "")) != PROFILE_SHA256
	):
		return _failure("QSDK_R23D61_GODOT_PROFILE_IDENTITY_INVALID")
	if (
		int(receipt.get("world_build_count", -1)) != 0
		or bool(receipt.get("physics_state_modified", true))
		or bool(receipt.get("physical_acceptance_authority", true))
		or bool(receipt.get("release_authority", true))
	):
		return _failure("QSDK_R23D61_GODOT_PROFILE_AUTHORITY_INVALID")
	var profile_value: Variant = receipt.get("profile")
	if not (profile_value is Dictionary):
		return _failure("QSDK_R23D61_GODOT_PROFILE_MISSING")
	var profile: Dictionary = profile_value
	if not _keys_exact(
		profile,
		[
			"schema_version",
			"profile_id",
			"supported_morphology_id",
			"supported_descriptor_sha256",
			"supported_morphology_spec_sha256",
			"semantics",
			"ordered_caps",
			"provenance",
			"claim_boundary",
		],
	):
		return _failure("QSDK_R23D61_GODOT_PROFILE_FIELDS_INVALID")
	if (
		String(profile.get("schema_version", "")) != PROFILE_SCHEMA_VERSION
		or String(profile.get("profile_id", "")) != PROFILE_ID
		or String(profile.get("supported_morphology_id", ""))
		!= "qsdk_r05_generated_s169"
		or String(profile.get("supported_descriptor_sha256", ""))
		!= DESCRIPTOR_SHA256
		or String(profile.get("supported_morphology_spec_sha256", ""))
		!= MORPHOLOGY_SPEC_SHA256
	):
		return _failure("QSDK_R23D61_GODOT_PROFILE_SURFACE_INVALID")
	var semantics_value: Variant = profile.get("semantics")
	if not (semantics_value is Dictionary):
		return _failure("QSDK_R23D61_GODOT_PROFILE_SEMANTICS_MISSING")
	var semantics: Dictionary = semantics_value
	if not _keys_exact(
		semantics,
		[
			"semantics_id",
			"quantity",
			"unit",
			"outer_step_hz",
			"outer_step_duration_s",
			"host_mapping_rule",
			"solver_iteration_multiplier_in_canonical_budget",
		],
	):
		return _failure("QSDK_R23D61_GODOT_PROFILE_SEMANTICS_FIELDS_INVALID")
	if (
		String(semantics.get("semantics_id", "")) != SEMANTICS_ID
		or String(semantics.get("quantity", ""))
		!= "maximum_angular_impulse_per_complete_outer_control_step"
		or String(semantics.get("unit", "")) != "newton_meter_second"
		or int(semantics.get("outer_step_hz", -1)) != 120
		or absf(
			float(semantics.get("outer_step_duration_s", NAN)) - 1.0 / 120.0
		)
		> SEMANTIC_DURATION_JSON_TRANSPORT_TOLERANCE_S
		or String(semantics.get("host_mapping_rule", ""))
		!= "preserve_maximum_outer_step_angular_impulse_exactly"
		or bool(
			semantics.get("solver_iteration_multiplier_in_canonical_budget", true)
		)
	):
		return _failure(
			"QSDK_R23D61_GODOT_PROFILE_SEMANTICS_INVALID",
			{
				"observed_semantics": semantics.duplicate(true),
				"duration_delta_s": absf(
					float(semantics.get("outer_step_duration_s", NAN)) - 1.0 / 120.0
				),
				"semantics_id_match": String(semantics.get("semantics_id", ""))
				== SEMANTICS_ID,
				"quantity_match": String(semantics.get("quantity", ""))
				== "maximum_angular_impulse_per_complete_outer_control_step",
				"unit_match": String(semantics.get("unit", ""))
				== "newton_meter_second",
				"outer_step_hz_match": int(semantics.get("outer_step_hz", -1)) == 120,
				"host_mapping_rule_match": String(
					semantics.get("host_mapping_rule", "")
				)
				== "preserve_maximum_outer_step_angular_impulse_exactly",
				"solver_multiplier_false": not bool(
					semantics.get("solver_iteration_multiplier_in_canonical_budget", true)
				),
			},
		)
	var boundary_value: Variant = profile.get("claim_boundary")
	if not (boundary_value is Dictionary):
		return _failure("QSDK_R23D61_GODOT_CLAIM_BOUNDARY_MISSING")
	var boundary: Dictionary = boundary_value
	if not _keys_exact(
		boundary,
		[
			"exact_scope_profile_publication",
			"arbitrary_morphology_support",
			"physical_question_declared",
			"physical_world_opened",
			"three_engine_turning",
			"prone_to_standing",
			"cross_engine_equivalence",
			"physical_acceptance_authority",
			"release_authority",
		],
	):
		return _failure("QSDK_R23D61_GODOT_PROFILE_CLAIM_FIELDS_INVALID")
	if (
		not bool(boundary.get("exact_scope_profile_publication", false))
		or bool(boundary.get("arbitrary_morphology_support", true))
		or bool(boundary.get("physical_question_declared", true))
		or bool(boundary.get("physical_world_opened", true))
		or bool(boundary.get("three_engine_turning", true))
		or bool(boundary.get("prone_to_standing", true))
		or bool(boundary.get("cross_engine_equivalence", true))
		or bool(boundary.get("physical_acceptance_authority", true))
		or bool(boundary.get("release_authority", true))
	):
		return _failure("QSDK_R23D61_GODOT_PROFILE_CLAIM_BOUNDARY_INVALID")
	var provenance_value: Variant = profile.get("provenance")
	if not (provenance_value is Dictionary):
		return _failure("QSDK_R23D61_GODOT_PROFILE_PROVENANCE_MISSING")
	var provenance: Dictionary = provenance_value
	if not _keys_exact(
		provenance,
		[
			"r23d58_zero_world_contract_path",
			"r23d58_zero_world_contract_raw_sha256",
			"r23d58_physical_source_commit",
			"r23d59_selection_closure_path",
			"r23d59_selection_closure_raw_sha256",
			"r23d59_selection_source_commit",
			"r23d60_validation_closure_path",
			"r23d60_validation_closure_raw_sha256",
			"r23d60_validation_source_commit",
			"selected_predecessor_profile_id",
			"fixture_comparator_was_public_sdk_semantics",
			"fixture_behavior_silently_applied",
			"historical_result_reinterpreted",
		],
	):
		return _failure("QSDK_R23D61_GODOT_PROFILE_PROVENANCE_FIELDS_INVALID")
	if (
		String(provenance.get("r23d58_zero_world_contract_path", ""))
		!= "sdk/turning/r23d58_godot_terminal_trace_cap_factorial_zero_world_v1.json"
		or String(provenance.get("r23d58_zero_world_contract_raw_sha256", ""))
		!= "sha256:b1d5615048c624e506dd4b89a3abac41dd07c41e90a9b814bae6cbb5913961ad"
		or String(provenance.get("r23d58_physical_source_commit", ""))
		!= "ecfc191bcc97ea53b089e9862a5d0b5a7a8ad6b5"
		or String(provenance.get("r23d59_selection_closure_path", ""))
		!= "sdk/turning/r23d59_godot_knee_source_finite_decision_closure_v1.json"
		or String(provenance.get("r23d59_selection_closure_raw_sha256", ""))
		!= "sha256:cbce64d87d18dbd819f8afd759943f4bbe7c066d32da3d4c4f567fc7b4422cc8"
		or String(provenance.get("r23d59_selection_source_commit", ""))
		!= "22020d397ea4ce952a67051a843c22b388f0f78b"
		or String(provenance.get("r23d60_validation_closure_path", ""))
		!= "sdk/turning/r23d60_godot_fixture_knee_held_out_turning_validation_closure_v1.json"
		or String(provenance.get("r23d60_validation_closure_raw_sha256", ""))
		!= "sha256:910fd0ba2369a889430c1228f2eaea1146cf26005c4ac51f353803869d709fd8"
		or String(provenance.get("r23d60_validation_source_commit", ""))
		!= "3d884af6dc0a15aa9bd2cde15de4535a24bb44a2"
		or String(provenance.get("selected_predecessor_profile_id", ""))
		!= "portable_hip__fixture_knee"
		or bool(provenance.get("fixture_comparator_was_public_sdk_semantics", true))
		or bool(provenance.get("fixture_behavior_silently_applied", true))
		or bool(provenance.get("historical_result_reinterpreted", true))
	):
		return _failure("QSDK_R23D61_GODOT_PROFILE_PROVENANCE_INVALID")
	var ordered_caps_value: Variant = profile.get("ordered_caps")
	if not (ordered_caps_value is Array):
		return _failure("QSDK_R23D61_GODOT_PROFILE_CAPS_MISSING")
	var ordered_caps: Array = ordered_caps_value
	if ordered_caps.size() != ORDERED_CAPS_NMS.size():
		return _failure("QSDK_R23D61_GODOT_PROFILE_CARDINALITY_INVALID")
	if host_joint_by_actuator_id.size() != ORDERED_ACTUATOR_IDS.size():
		return _failure("QSDK_R23D61_GODOT_HOST_CARDINALITY_INVALID")

	var unique_instance_ids: Dictionary = {}
	var ordered_bindings: Array = []
	for index in range(ORDERED_ACTUATOR_IDS.size()):
		var item_value: Variant = ordered_caps[index]
		if not (item_value is Dictionary):
			return _failure("QSDK_R23D61_GODOT_PROFILE_CAP_ENTRY_INVALID")
		var item: Dictionary = item_value
		if not _keys_exact(
			item,
			[
				"actuator_id",
				"joint_id",
				"source",
				"base_compiled_maximum_impulse_nms",
				"base_compiled_maximum_impulse_binary64_hex",
				"maximum_outer_step_impulse_nms",
				"maximum_outer_step_impulse_binary64_hex",
				"differs_from_base_compiled_morphology",
				"base_to_profile_binary64_ulp_distance",
			],
		):
			return _failure("QSDK_R23D61_GODOT_PROFILE_CAP_FIELDS_INVALID")
		var actuator_id := String(item.get("actuator_id", ""))
		var cap_value: Variant = item.get("maximum_outer_step_impulse_nms")
		if (
			actuator_id != ORDERED_ACTUATOR_IDS[index]
			or String(item.get("joint_id", "")) != ORDERED_JOINT_IDS[index]
			or String(item.get("source", ""))
			!= (
				"r23d60_selected_portable_hip_explicit_publication"
				if index % 2 == 0
				else "r23d60_selected_fixture_knee_explicit_publication"
			)
			or float(item.get("base_compiled_maximum_impulse_nms", NAN))
			!= float(ORDERED_BASE_CAPS_NMS[index])
			or String(item.get("base_compiled_maximum_impulse_binary64_hex", ""))
			!= ORDERED_BASE_CAPS_BINARY64_HEX[index]
			or typeof(cap_value) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(cap_value))
			or float(cap_value) != float(ORDERED_CAPS_NMS[index])
			or String(item.get("maximum_outer_step_impulse_binary64_hex", ""))
			!= ORDERED_CAPS_BINARY64_HEX[index]
			or bool(item.get("differs_from_base_compiled_morphology", false))
			!= (index not in [0, 2])
			or String(item.get("base_to_profile_binary64_ulp_distance", ""))
			!= ORDERED_ULP_DISTANCES[index]
		):
			return _failure("QSDK_R23D61_GODOT_PROFILE_ORDER_OR_CAP_INVALID")
		if not host_joint_by_actuator_id.has(actuator_id):
			return _failure("QSDK_R23D61_GODOT_HOST_JOINT_MISSING")
		var joint_value: Variant = host_joint_by_actuator_id[actuator_id]
		if not (joint_value is HingeJoint3D):
			return _failure("QSDK_R23D61_GODOT_HOST_JOINT_TYPE_INVALID")
		var joint: HingeJoint3D = joint_value
		if joint.get_parent() != null or joint.is_inside_tree():
			return _failure("QSDK_R23D61_GODOT_HOST_JOINT_NOT_ZERO_WORLD")
		var instance_id := int(joint.get_instance_id())
		if unique_instance_ids.has(instance_id):
			return _failure("QSDK_R23D61_GODOT_HOST_JOINT_DUPLICATE")
		unique_instance_ids[instance_id] = true
		var before := float(
			joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE)
		)
		if not is_finite(before):
			return _failure("QSDK_R23D61_GODOT_HOST_PREBINDING_NONFINITE")
		ordered_bindings.append(
			{
				"actuator_id": actuator_id,
				"joint_id": ORDERED_JOINT_IDS[index],
				"declared_maximum_impulse_nms": float(cap_value),
				"prebinding_maximum_impulse_nms": before,
				"joint": joint,
			}
		)
	return {"ok": true, "ordered_bindings": ordered_bindings}


static func _keys_exact(value: Dictionary, expected_keys: Array) -> bool:
	if value.size() != expected_keys.size():
		return false
	for key_value in expected_keys:
		if not value.has(String(key_value)):
			return false
	return true


static func _rollback(bindings: Array) -> int:
	var rollback_count := 0
	for binding_value in bindings:
		var binding: Dictionary = binding_value
		var joint: HingeJoint3D = binding["joint"]
		joint.set_param(
			HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,
			float(binding["prebinding_maximum_impulse_nms"]),
		)
		var restored := float(
			joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE)
		)
		if restored == float(binding["prebinding_maximum_impulse_nms"]):
			rollback_count += 1
	return rollback_count


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": BINDING_RECEIPT_SCHEMA_VERSION,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"host_configuration_modified": false,
		"host_configuration_restored": true,
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"locomotion_outcome_exposed": false,
		"turning_claimed": false,
		"prone_to_standing_claimed": false,
		"cross_engine_equivalence_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
