extends SceneTree
# gdlint: disable=max-line-length

## Exact public-profile resolution through the real GDExtension followed by
## eight unparented HingeJoint3D writes/readbacks. No object enters a SceneTree
## and no physics world or solver step exists.

const BindingScript := preload(
	"res://sdk/adapters/godot/gdscript/actuator_cap_profile_binding.gd"
)
const JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const EXTENSION_PATH := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const CLASS_NAME := "SporeLocomotionSdk"
const EXPECTED_MUTATION_REJECTION_COUNT := 17


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := _evaluate()
	print(
		"QSDK_R23D61_GODOT_ACTUATOR_CAP_PROFILE_ZERO_WORLD ",
		JsonTransportScript.stringify(result),
	)
	quit(0 if bool(result.get("ok", false)) else 1)


static func _evaluate() -> Dictionary:
	var extension_resource := load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(CLASS_NAME):
		return _failure("QSDK_R23D61_GODOT_EXTENSION_UNAVAILABLE")
	var api: Object = ClassDB.instantiate(CLASS_NAME)
	if api == null:
		return _failure("QSDK_R23D61_GODOT_EXTENSION_INSTANTIATION_FAILED")
	var receipt_result := _resolve(api, _descriptor(), BindingScript.PROFILE_ID)
	if not bool(receipt_result.get("ok", false)):
		return _failure("QSDK_R23D61_GODOT_PROFILE_RESOLUTION_FAILED", receipt_result)
	var receipt: Dictionary = receipt_result["receipt"]

	var surface := _surface()
	var binding: Dictionary = BindingScript.new().bind_profile(
		receipt,
		surface["joint_by_actuator_id"],
		BindingScript.MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS,
	)
	if not bool(binding.get("ok", false)):
		_free_surface(surface)
		return _failure(
			"QSDK_R23D61_GODOT_BINDING_FAILED",
			{
				"binding": binding.duplicate(true),
				"resolution_receipt": receipt.duplicate(true),
			},
		)

	var mutation_ids := [
		"wrong_receipt_schema",
		"wrong_profile_id",
		"wrong_support_status",
		"wrong_profile_sha256",
		"wrong_semantics",
		"swapped_actuator_order",
		"zero_cap",
		"mutated_bound_profile_field",
		"inflated_world_count",
		"inflated_claim_authority",
		"missing_host_joint",
		"extra_host_joint",
		"duplicate_host_joint",
		"wrong_host_joint_type",
		"postwrite_readback_rollback",
		"excessive_tolerance",
		"duplicate_binding",
	]
	var mutation_results: Dictionary = {}
	var mutation_rejection_count := 0
	for mutation_id_value in mutation_ids:
		var mutation_id := String(mutation_id_value)
		var rejected := _mutation_rejected(receipt, mutation_id)
		mutation_results[mutation_id] = rejected
		mutation_rejection_count += int(rejected)

	var out_of_domain_result := _resolve(
		api,
		_reference_descriptor("valid_out_of_domain"),
		BindingScript.PROFILE_ID,
	)
	var unsupported_result := _resolve(api, _descriptor(), "unknown_profile")
	var refusal_receipts_rejected := (
		bool(out_of_domain_result.get("ok", false))
		and String(
			(out_of_domain_result["receipt"] as Dictionary).get("support_status", "")
		)
		== "out_of_domain_morphology"
		and _receipt_rejected_without_write(out_of_domain_result["receipt"])
		and bool(unsupported_result.get("ok", false))
		and String(
			(unsupported_result["receipt"] as Dictionary).get("support_status", "")
		)
		== "unsupported_profile"
		and _receipt_rejected_without_write(unsupported_result["receipt"])
	)

	var exact := (
		String(Engine.get_version_info().get("string", "")) == "4.7-stable (official)"
		and String(binding.get("schema_version", ""))
		== BindingScript.BINDING_RECEIPT_SCHEMA_VERSION
		and String(binding.get("profile_id", "")) == BindingScript.PROFILE_ID
		and String(binding.get("profile_sha256", "")) == BindingScript.PROFILE_SHA256
		and int(binding.get("validated_actuator_count", -1)) == 8
		and int(binding.get("unique_host_joint_object_count", -1)) == 8
		and int(binding.get("write_count", -1)) == 8
		and int(binding.get("readback_count", -1)) == 8
		and float(binding.get("maximum_readback_error_nms", INF))
		<= BindingScript.MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS
		and bool(binding.get("host_configuration_modified", false))
		and int(binding.get("scene_tree_insertion_count", -1)) == 0
		and int(binding.get("world_build_count", -1)) == 0
		and int(binding.get("solver_step_count", -1)) == 0
		and not bool(binding.get("physics_state_modified", true))
		and mutation_rejection_count == EXPECTED_MUTATION_REJECTION_COUNT
		and refusal_receipts_rejected
	)
	var result := {
		"schema_version": "sporespore_qsdk_r23d61_godot_actuator_cap_profile_zero_world_v1",
		"ok": exact,
		"failure_code": "" if exact else "QSDK_R23D61_GODOT_ZERO_WORLD_INVALID",
		"question_class": "non_physical_source_conformance",
		"runtime_api_version": String(Engine.get_version_info().get("string", "")),
		"profile_id": BindingScript.PROFILE_ID,
		"profile_sha256": BindingScript.PROFILE_SHA256,
		"binding_receipt": binding.duplicate(true),
		"validated_actuator_count": int(binding.get("validated_actuator_count", -1)),
		"mutation_rejection_count": mutation_rejection_count,
		"mutation_results": mutation_results,
		"out_of_domain_and_unsupported_receipts_rejected": refusal_receipts_rejected,
		"host_object_creation_count": 8,
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_declared": false,
		"physical_campaign_opened": false,
		"turning_claimed": false,
		"prone_to_standing_claimed": false,
		"cross_engine_equivalence_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	_free_surface(surface)
	return result


static func _resolve(api: Object, descriptor: Dictionary, profile_id: String) -> Dictionary:
	var request := {
		"schema_version": "sporespore_actuator_cap_profile_request_v1",
		"profile_id": profile_id,
		"descriptor": descriptor,
	}
	var raw := String(
		api.call(
			"resolve_actuator_cap_profile_v1_json",
			JsonTransportScript.stringify(request),
		)
	)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary) or not bool(parsed.get("ok", false)):
		return {"ok": false, "raw": raw}
	return {"ok": true, "receipt": (parsed["value"] as Dictionary).duplicate(true)}


static func _descriptor() -> Dictionary:
	return {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": "qsdk_r05_generated_s169",
		"torso_length_scale": 1.0041015625,
		"torso_width_scale": 1.0031893004115227,
		"upper_length_fraction": 0.5219571428571428,
		"hip_span_scale": 0.9856413994169096,
		"foot_radius_scale": 0.9987180691209617,
		"front_limb_mass_scale": 0.975022758306782,
	}


static func _reference_descriptor(morphology_id: String) -> Dictionary:
	return {
		"schema_version": "sporespore_bounded_quadruped_descriptor_v1",
		"morphology_id": morphology_id,
		"torso_length_scale": 1.0,
		"torso_width_scale": 1.0,
		"upper_length_fraction": 18.0 / 35.0,
		"hip_span_scale": 1.0,
		"foot_radius_scale": 1.0,
		"front_limb_mass_scale": 1.0,
	}


static func _surface() -> Dictionary:
	var joint_by_actuator_id: Dictionary = {}
	var ordered_joints: Array[HingeJoint3D] = []
	for index in range(BindingScript.ORDERED_ACTUATOR_IDS.size()):
		var actuator_id := String(BindingScript.ORDERED_ACTUATOR_IDS[index])
		var joint := HingeJoint3D.new()
		joint.name = actuator_id
		joint.set_param(
			HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,
			0.125 + float(index) * 0.001,
		)
		joint_by_actuator_id[actuator_id] = joint
		ordered_joints.append(joint)
	return {
		"joint_by_actuator_id": joint_by_actuator_id,
		"ordered_joints": ordered_joints,
	}


static func _caps(surface: Dictionary) -> Array:
	var caps: Array = []
	for joint_value in surface["ordered_joints"]:
		var joint: HingeJoint3D = joint_value
		caps.append(float(joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE)))
	return caps


static func _mutation_rejected(receipt: Dictionary, mutation_id: String) -> bool:
	var candidate := receipt.duplicate(true)
	var surface := _surface()
	var before := _caps(surface)
	var joints: Dictionary = surface["joint_by_actuator_id"]
	var tolerance := BindingScript.MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS
	var binder: RefCounted = BindingScript.new()
	var extra_joint: HingeJoint3D
	match mutation_id:
		"wrong_receipt_schema":
			candidate["schema_version"] = "mutated"
		"wrong_profile_id":
			candidate["requested_profile_id"] = "mutated"
		"wrong_support_status":
			candidate["support_status"] = "out_of_domain_morphology"
		"wrong_profile_sha256":
			candidate["profile_sha256"] = "sha256:mutated"
		"wrong_semantics":
			(candidate["profile"] as Dictionary)["semantics"]["semantics_id"] = "mutated"
		"swapped_actuator_order":
			var caps: Array = (candidate["profile"] as Dictionary)["ordered_caps"]
			var first: Variant = caps[0]
			caps[0] = caps[1]
			caps[1] = first
		"zero_cap":
			var caps: Array = (candidate["profile"] as Dictionary)["ordered_caps"]
			(caps[0] as Dictionary)["maximum_outer_step_impulse_nms"] = 0.0
		"mutated_bound_profile_field":
			var caps: Array = (candidate["profile"] as Dictionary)["ordered_caps"]
			(caps[4] as Dictionary)["maximum_outer_step_impulse_binary64_hex"] = (
				"0x3facdd051a8b389c"
			)
		"inflated_world_count":
			candidate["world_build_count"] = 1
		"inflated_claim_authority":
			(candidate["profile"] as Dictionary)["claim_boundary"]["cross_engine_equivalence"] = true
		"missing_host_joint":
			joints.erase(BindingScript.ORDERED_ACTUATOR_IDS[0])
		"extra_host_joint":
			extra_joint = HingeJoint3D.new()
			joints["unexpected_motor"] = extra_joint
		"duplicate_host_joint":
			joints[BindingScript.ORDERED_ACTUATOR_IDS[1]] = joints[
				BindingScript.ORDERED_ACTUATOR_IDS[0]
			]
		"wrong_host_joint_type":
			joints[BindingScript.ORDERED_ACTUATOR_IDS[0]] = RefCounted.new()
		"postwrite_readback_rollback":
			tolerance = 1.0e-15
		"excessive_tolerance":
			tolerance = BindingScript.MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS * 2.0
		"duplicate_binding":
			var first_result: Dictionary = binder.bind_profile(candidate, joints, tolerance)
			var after_first := _caps(surface)
			var second_result: Dictionary = binder.bind_profile(candidate, joints, tolerance)
			var duplicate_rejected := (
				bool(first_result.get("ok", false))
				and not bool(second_result.get("ok", true))
				and _caps(surface) == after_first
			)
			_free_surface(surface)
			return duplicate_rejected
	var result: Dictionary = binder.bind_profile(candidate, joints, tolerance)
	var rejected := not bool(result.get("ok", true)) and _caps(surface) == before
	if mutation_id == "postwrite_readback_rollback":
		rejected = (
			rejected
			and String(result.get("failure_code", ""))
			== "QSDK_R23D61_GODOT_POSTWRITE_READBACK_INVALID"
			and bool(result.get("host_configuration_modified", false))
			and bool(result.get("host_configuration_restored", false))
			and int(result.get("rollback_count", -1)) == 8
		)
	if is_instance_valid(extra_joint):
		extra_joint.free()
	_free_surface(surface)
	return rejected


static func _receipt_rejected_without_write(receipt: Dictionary) -> bool:
	var surface := _surface()
	var before := _caps(surface)
	var result: Dictionary = BindingScript.new().bind_profile(
		receipt,
		surface["joint_by_actuator_id"],
	)
	var rejected := not bool(result.get("ok", true)) and _caps(surface) == before
	_free_surface(surface)
	return rejected


static func _free_surface(surface: Dictionary) -> void:
	for joint_value in surface.get("ordered_joints", []):
		if joint_value is HingeJoint3D and is_instance_valid(joint_value):
			joint_value.free()


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": "sporespore_qsdk_r23d61_godot_actuator_cap_profile_zero_world_v1",
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"question_class": "non_physical_source_conformance",
		"scene_tree_insertion_count": 0,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physics_state_modified": false,
		"physical_question_declared": false,
		"physical_campaign_opened": false,
		"turning_claimed": false,
		"prone_to_standing_claimed": false,
		"cross_engine_equivalence_claimed": false,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
