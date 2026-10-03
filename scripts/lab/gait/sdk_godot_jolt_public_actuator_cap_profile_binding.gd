class_name LabSdkGodotJoltPublicActuatorCapProfileBinding
extends RefCounted
# gdlint: disable=max-line-length
# gdlint: disable=max-returns

## Resolves the R23D61 public profile through the real Godot GDExtension and
## binds it to the exact eight unparented hinge objects later inserted by the
## physical fixture route.
##
## Resolution, complete host mapping, all writes, every configured-parameter
## readback, and the physical-binding projection finish before any object is
## parented or any solver step can occur. This component creates no body,
## SceneTree, model, or physics world and grants no physical authority.

const PublicBindingScript := preload(
	"res://sdk/adapters/godot/gdscript/actuator_cap_profile_binding.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)

const POLICY_ID := "sporespore_godot_jolt_public_actuator_cap_profile_binding_v1"
const ROUTE_RECEIPT_SCHEMA_VERSION := (
	"sporespore_godot_jolt_public_actuator_cap_profile_route_v1"
)
const PHYSICAL_BINDING_SCHEMA_VERSION := (
	"sporespore_qsdk_r23d62_physical_actuator_cap_binding_v1"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const EXTENSION_CLASS_NAME := "SporeLocomotionSdk"
const PROFILE_ID := PublicBindingScript.PROFILE_ID
const PROFILE_SHA256 := PublicBindingScript.PROFILE_SHA256
const HOST_MAPPING_ID := PublicBindingScript.HOST_MAPPING_ID
const PORTABLE_SEMANTICS_ID := PublicBindingScript.SEMANTICS_ID
const EXPECTED_ACTUATOR_COUNT := 8

const ORDERED_ACTUATOR_IDS := PublicBindingScript.ORDERED_ACTUATOR_IDS
const ORDERED_JOINT_IDS := PublicBindingScript.ORDERED_JOINT_IDS
const ORDERED_CAPS_NMS := PublicBindingScript.ORDERED_CAPS_NMS
const ORDERED_HOST_JOINT_IDS := [
	"front_left.hip_pitch",
	"front_left.knee_pitch",
	"front_right.hip_pitch",
	"front_right.knee_pitch",
	"rear_left.hip_pitch",
	"rear_left.knee_pitch",
	"rear_right.hip_pitch",
	"rear_right.knee_pitch",
]


func resolve_bind_and_project(
	descriptor: Dictionary,
	joint_state_by_joint_id: Dictionary,
	readback_tolerance_nms: float,
	profile_id: String = PROFILE_ID,
	policy_id: String = POLICY_ID,
) -> Dictionary:
	if (
		policy_id != POLICY_ID
		or profile_id != PROFILE_ID
		or descriptor.is_empty()
		or joint_state_by_joint_id.size() != EXPECTED_ACTUATOR_COUNT
		or not is_finite(readback_tolerance_nms)
		or readback_tolerance_nms < 0.0
		or readback_tolerance_nms
		> PublicBindingScript.MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS
	):
		return _failure("PUBLIC_ACTUATOR_CAP_ROUTE_INPUT_INVALID")
	var resolution_result := _resolve_public_profile(descriptor, profile_id)
	if not bool(resolution_result.get("ok", false)):
		return _failure(
			String(
				resolution_result.get(
					"failure_code",
					"PUBLIC_ACTUATOR_CAP_ROUTE_RESOLUTION_FAILED",
				)
			),
			resolution_result,
		)
	var resolution: Dictionary = resolution_result["resolution_receipt"]
	if String(resolution.get("support_status", "")) != "supported_exact":
		return _failure(
			"PUBLIC_ACTUATOR_CAP_ROUTE_PROFILE_NOT_EXACTLY_SUPPORTED",
			{"resolution_receipt": resolution.duplicate(true)},
		)
	var host_surface := _host_joint_surface(joint_state_by_joint_id)
	if not bool(host_surface.get("ok", false)):
		return host_surface
	var host_joint_by_actuator_id: Dictionary = host_surface[
		"host_joint_by_actuator_id"
	]
	var host_mapping: Dictionary = PublicBindingScript.new().bind_profile(
		resolution,
		host_joint_by_actuator_id,
		readback_tolerance_nms,
	)
	if not bool(host_mapping.get("ok", false)):
		return _failure(
			String(
				host_mapping.get(
					"failure_code",
					"PUBLIC_ACTUATOR_CAP_ROUTE_BINDING_FAILED",
				)
			),
			{
				"resolution_receipt": resolution.duplicate(true),
				"host_mapping_receipt": host_mapping.duplicate(true),
			},
		)
	host_mapping["all_postbinding_readbacks_match"] = true
	host_mapping["configured_parameter_readback_only"] = true
	var physical_binding := _physical_binding_receipt(host_mapping)
	if not bool(physical_binding.get("ok", false)):
		return _failure(
			String(
				physical_binding.get(
					"failure_code",
					"PUBLIC_ACTUATOR_CAP_ROUTE_PHYSICAL_PROJECTION_FAILED",
				)
			),
			{
				"resolution_receipt": resolution.duplicate(true),
				"host_mapping_receipt": host_mapping.duplicate(true),
				"physical_binding_receipt": physical_binding.duplicate(true),
			},
		)
	var override_by_actuator_id: Dictionary = {}
	for index in range(ORDERED_ACTUATOR_IDS.size()):
		override_by_actuator_id[String(ORDERED_ACTUATOR_IDS[index])] = float(
			ORDERED_CAPS_NMS[index]
		)
	return {
		"schema_version": ROUTE_RECEIPT_SCHEMA_VERSION,
		"ok": true,
		"failure_code": "",
		"policy_id": POLICY_ID,
		"profile_id": PROFILE_ID,
		"profile_sha256": PROFILE_SHA256,
		"host_mapping_id": HOST_MAPPING_ID,
		"actuator_cap_profile_resolution_receipt": resolution.duplicate(true),
		"actuator_cap_profile_host_mapping_receipt": host_mapping.duplicate(true),
		"actuator_cap_profile_physical_binding_receipt": (
			physical_binding.duplicate(true)
		),
		"maximum_impulse_override_by_actuator_id": (
			override_by_actuator_id.duplicate(true)
		),
		"validated_actuator_count": EXPECTED_ACTUATOR_COUNT,
		"write_count": int(host_mapping.get("write_count", -1)),
		"readback_count": int(host_mapping.get("readback_count", -1)),
		"scene_tree_insertion_count": int(
			host_surface.get("scene_tree_insertion_count", -1)
		),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _resolve_public_profile(
	descriptor: Dictionary,
	profile_id: String,
) -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(EXTENSION_CLASS_NAME):
		return _failure("PUBLIC_ACTUATOR_CAP_ROUTE_EXTENSION_UNAVAILABLE")
	var api: Object = ClassDB.instantiate(EXTENSION_CLASS_NAME)
	if api == null:
		return _failure("PUBLIC_ACTUATOR_CAP_ROUTE_EXTENSION_INSTANTIATION_FAILED")
	var request := {
		"schema_version": "sporespore_actuator_cap_profile_request_v1",
		"profile_id": profile_id,
		"descriptor": descriptor.duplicate(true),
	}
	var raw := String(
		api.call(
			"resolve_actuator_cap_profile_v1_json",
			JsonTransportScript.stringify(request),
		)
	)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary) or not bool(parsed.get("ok", false)):
		return _failure(
			"PUBLIC_ACTUATOR_CAP_ROUTE_RESOLUTION_TRANSPORT_INVALID",
			{"raw": raw},
		)
	var value: Variant = parsed.get("value")
	if not (value is Dictionary):
		return _failure("PUBLIC_ACTUATOR_CAP_ROUTE_RESOLUTION_RECEIPT_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"resolution_receipt": (value as Dictionary).duplicate(true),
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _host_joint_surface(
	joint_state_by_joint_id: Dictionary,
) -> Dictionary:
	var host_joint_by_actuator_id: Dictionary = {}
	var observed_instance_ids: Dictionary = {}
	var scene_tree_insertion_count := 0
	for index in range(ORDERED_ACTUATOR_IDS.size()):
		var host_joint_id := String(ORDERED_HOST_JOINT_IDS[index])
		if not joint_state_by_joint_id.has(host_joint_id):
			return _failure(
				"PUBLIC_ACTUATOR_CAP_ROUTE_HOST_JOINT_MISSING:%s" % host_joint_id
			)
		var state_value: Variant = joint_state_by_joint_id[host_joint_id]
		if not (state_value is Dictionary):
			return _failure(
				"PUBLIC_ACTUATOR_CAP_ROUTE_HOST_STATE_INVALID:%s" % host_joint_id
			)
		var joint_value: Variant = (state_value as Dictionary).get("joint")
		if not (joint_value is HingeJoint3D):
			return _failure(
				"PUBLIC_ACTUATOR_CAP_ROUTE_HOST_OBJECT_INVALID:%s" % host_joint_id
			)
		var joint: HingeJoint3D = joint_value
		var instance_id := int(joint.get_instance_id())
		if observed_instance_ids.has(instance_id):
			return _failure("PUBLIC_ACTUATOR_CAP_ROUTE_HOST_OBJECT_DUPLICATE")
		if (
			joint.get_parent() != null
			or joint.is_inside_tree()
			or not joint.has_meta("lab_joint_id")
			or String(joint.get_meta("lab_joint_id")) != host_joint_id
		):
			return _failure(
				"PUBLIC_ACTUATOR_CAP_ROUTE_HOST_OBJECT_NOT_PREWORLD:%s"
				% host_joint_id
			)
		observed_instance_ids[instance_id] = true
		scene_tree_insertion_count += int(joint.is_inside_tree())
		host_joint_by_actuator_id[String(ORDERED_ACTUATOR_IDS[index])] = joint
	if (
		host_joint_by_actuator_id.size() != EXPECTED_ACTUATOR_COUNT
		or observed_instance_ids.size() != EXPECTED_ACTUATOR_COUNT
		or scene_tree_insertion_count != 0
	):
		return _failure("PUBLIC_ACTUATOR_CAP_ROUTE_HOST_SURFACE_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"host_joint_by_actuator_id": host_joint_by_actuator_id,
		"unique_host_joint_object_count": observed_instance_ids.size(),
		"scene_tree_insertion_count": scene_tree_insertion_count,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _physical_binding_receipt(host_mapping: Dictionary) -> Dictionary:
	var mapping_values: Variant = host_mapping.get("ordered_bindings")
	if not (mapping_values is Array) or (mapping_values as Array).size() != 8:
		return _failure("PUBLIC_ACTUATOR_CAP_ROUTE_MAPPING_CARDINALITY_INVALID")
	var ordered_bindings: Array = []
	var all_readbacks_match := true
	for index in range(ORDERED_ACTUATOR_IDS.size()):
		var mapping_value: Variant = (mapping_values as Array)[index]
		if not (mapping_value is Dictionary):
			return _failure(
				"PUBLIC_ACTUATOR_CAP_ROUTE_MAPPING_ROW_INVALID:%d" % index
			)
		var mapping: Dictionary = mapping_value
		var declared := float(
			mapping.get("declared_maximum_outer_step_impulse_nms", NAN)
		)
		var readback := float(
			mapping.get("godot_maximum_impulse_readback_nms", NAN)
		)
		var error := absf(readback - declared)
		var matches := (
			is_finite(declared)
			and is_finite(readback)
			and is_finite(error)
			and String(mapping.get("actuator_id", ""))
			== String(ORDERED_ACTUATOR_IDS[index])
			and String(mapping.get("joint_id", "")) == String(ORDERED_JOINT_IDS[index])
			and declared == float(ORDERED_CAPS_NMS[index])
			and error
			<= PublicBindingScript.MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS
		)
		all_readbacks_match = all_readbacks_match and matches
		ordered_bindings.append(
			{
				"profile_actuator_id": String(ORDERED_ACTUATOR_IDS[index]),
				"trace_actuator_id": String(ORDERED_ACTUATOR_IDS[index]),
				"joint_id": String(ORDERED_JOINT_IDS[index]),
				"declared_maximum_outer_step_impulse_nms": declared,
				"host_readback_outer_step_impulse_nms": readback,
				"readback_error_nms": error,
				"readback_matches": matches,
			}
		)
	if not all_readbacks_match:
		return _failure("PUBLIC_ACTUATOR_CAP_ROUTE_PHYSICAL_READBACK_INVALID")
	var host_mapping_sha256 := (
		"sha256:" + JsonTransportScript.stringify(host_mapping).sha256_text()
	)
	return {
		"schema_version": PHYSICAL_BINDING_SCHEMA_VERSION,
		"ok": true,
		"failure_code": "",
		"engine_id": "godot_jolt",
		"profile_id": PROFILE_ID,
		"profile_sha256": PROFILE_SHA256,
		"host_mapping_id": HOST_MAPPING_ID,
		"host_mapping_receipt_sha256": host_mapping_sha256,
		"completed_before_first_solver_step": true,
		"solver_step_count_at_binding": 0,
		"validated_actuator_count": EXPECTED_ACTUATOR_COUNT,
		"write_count": EXPECTED_ACTUATOR_COUNT,
		"readback_count": EXPECTED_ACTUATOR_COUNT,
		"all_readbacks_match": true,
		"ordered_bindings": ordered_bindings,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": ROUTE_RECEIPT_SCHEMA_VERSION,
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"actuator_cap_profile_resolution_receipt": {},
		"actuator_cap_profile_host_mapping_receipt": {},
		"actuator_cap_profile_physical_binding_receipt": {},
		"maximum_impulse_override_by_actuator_id": {},
		"host_configuration_modified": false,
		"host_configuration_restored": true,
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
