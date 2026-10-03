class_name SporeQsdkR10fL15CollectionContextV1
extends RefCounted
# gdlint: disable=max-line-length

## Capture the expected identity from a validated prepared context, never from
## an observation or failed packet. This is not qualification authority itself.
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const SCHEMA := "sporespore_qsdk_r10f_l15_prepared_collection_context_v1"
const INTERNAL_ARM_KIND := "candidate_command"
const IDENTITY_KEYS := [
	"task_id",
	"semantics_id",
	"actuator_profile_id",
	"descriptor",
	"morphology_context",
	"adapter_capability",
	"runtime_binding",
	"arm_kind",
]


static func capture_prepared_v1(sdk: Object, context: Dictionary) -> Dictionary:
	var result := {
		"schema_version": SCHEMA,
		"ledger_scope":
		{
			"subsystem": "recovery",
			"engine_scope": "godot_jolt",
			"authority_mode": "zero_world_prepared_expected_context_capture",
			"question_class": "development",
		},
		"ok": false,
		"failure_code": "L15_COLLECTION_CONTEXT_INVALID",
		"source_context": null,
		"expected_identity": null,
		"source_is_prepared_context_not_observation": true,
		"production_request_identity_projection_checked": false,
		"collection_request_constructor_call_count": 0,
		"compiled_collection_call_count": 0,
		"portable_recovery_advance_call_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"scene_tree_insertion_count": 0,
		"native_physics_read_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"official_context_qualification": false,
		"physical_worker_context_installed": false,
		"physical_execution_authorized": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if sdk == null:
		result["failure_code"] = "L15_COLLECTION_CONTEXT_SDK_MISSING"
		return result
	for key in [
		"model_construction_count", "world_attempt_count", "world_build_count", "solver_step_count"
	]:
		if typeof(context.get(key)) != TYPE_INT or context[key] != 0:
			result["failure_code"] = "L15_COLLECTION_CONTEXT_COUNTER:" + key
			return result
	for key in ["physics_state_modified", "physical_acceptance_authority", "release_authority"]:
		if typeof(context.get(key)) != TYPE_BOOL or context[key] != false:
			result["failure_code"] = "L15_COLLECTION_CONTEXT_AUTHORITY:" + key
			return result
	if (
		(
			context.get("schema_version")
			!= "sporespore_qsdk_r24d172_godot_initializer_retention_recovery_behavior_context_v18"
		)
		or context.get("recovery_controller_id") != Route.RECOVERY_CONTROLLER_V6_ID
		or not Route.contiguous_boundary_recovery_behavior_context_binding_exact_v1(sdk, context)
	):
		return result
	var expected := {
		"task_id": Route.TASK_ID,
		"semantics_id": Route.SEMANTICS_ID,
		"actuator_profile_id": Route.ACTUATOR_PROFILE_ID,
		"descriptor": Route.exact_base_descriptor_v1(),
		"morphology_context": context["morphology_context"].duplicate(true),
		"adapter_capability": context["capability"].duplicate(true),
		"runtime_binding": context["runtime_binding"].duplicate(true),
		"arm_kind": INTERNAL_ARM_KIND,
	}
	# Empty observation containers exercise only the actual request constructor's
	# identity projection. This request is never serialized or sent to a collector.
	var request := Route.collection_request_v1(
		context, {"observation_v2": {}, "source_binding": {}}, INTERNAL_ARM_KIND, "confirm_prone"
	)
	result["collection_request_constructor_call_count"] = 1
	var actual := {}
	for key in IDENTITY_KEYS:
		actual[key] = request[key]
	if Transport.stringify(actual) != Transport.stringify(expected):
		result["failure_code"] = "L15_COLLECTION_CONTEXT_REQUEST_PROJECTION"
		return result
	result["source_context"] = snapshot_v1(context)
	result["expected_identity"] = snapshot_v1(expected)
	result["production_request_identity_projection_checked"] = true
	result["ok"] = true
	result["failure_code"] = null
	return result


static func snapshot_v1(value: Dictionary) -> Dictionary:
	var raw := Transport.stringify(value)
	return {
		"utf8_text": raw,
		"utf8_byte_length": raw.to_utf8_buffer().size(),
		"raw_sha256": "sha256:" + raw.sha256_text(),
	}
