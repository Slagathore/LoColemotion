class_name LabSdkGodotJoltLiveFixtureActuatorCapBinding
extends RefCounted
# gdlint: disable=max-returns
# gdlint: disable=max-line-length

## One-time binding of portable actuator impulse caps to fixture-created Godot
## hinge joints.
##
## This component is deliberately separate from controller stepping. It first
## validates the complete compiled-actuator-to-host-joint surface without
## writing anything, then writes all eight limits, and finally performs an
## ordered readback. It never inserts a node into a SceneTree, advances
## physics, or grants physical acceptance authority.

const POLICY_ID := "sporespore_godot_jolt_live_fixture_compiled_actuator_cap_binding_v1"
const FIXTURE_COMPOSITION_SCHEMA_VERSION := "sporespore_godot_jolt_fixture_joint_composition_v1"
const RECEIPT_SCHEMA_VERSION := "sporespore_godot_jolt_live_fixture_actuator_cap_binding_receipt_v1"
const VALIDATION_SCHEMA_VERSION := "sporespore_godot_jolt_live_fixture_actuator_cap_validation_receipt_v1"
const EXPECTED_ACTUATOR_COUNT := 8
const EXPECTED_LIMB_COUNT := 4
const MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS := 1.0e-6

var _binding_completed := false
var _binding_receipt: Dictionary = {}


func bind_compiled_actuator_caps(
	morphology: Dictionary,
	joint_state_by_joint_id: Dictionary,
	readback_tolerance_nms: float,
	policy_id: String = POLICY_ID,
) -> Dictionary:
	if _binding_completed:
		return _failure("LIVE_FIXTURE_CAP_BINDING_ALREADY_COMPLETED")
	var inspection := _inspect_surface(
		morphology,
		joint_state_by_joint_id,
		readback_tolerance_nms,
		policy_id,
		false,
	)
	if not bool(inspection.get("ok", false)):
		return inspection
	var pending: Array = inspection["pending_bindings"]
	for pending_value in pending:
		var binding: Dictionary = pending_value
		var joint: HingeJoint3D = binding["joint"]
		(
			joint
			. set_param(
				HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,
				float(binding["declared_maximum_impulse_nms"]),
			)
		)
	var validation := _inspect_surface(
		morphology,
		joint_state_by_joint_id,
		readback_tolerance_nms,
		policy_id,
		true,
	)
	if not bool(validation.get("ok", false)):
		_zero_motor_targets(pending)
		return _failure(
			(
				"LIVE_FIXTURE_CAP_BINDING_READBACK_INVALID:%s"
				% String(validation.get("failure_code", "UNKNOWN"))
			),
			{"validation": validation},
		)
	var ordered_bindings: Array = validation["ordered_bindings"]
	var prebinding_by_actuator: Dictionary = {}
	var prebinding_mismatch_count := 0
	var maximum_prebinding_error_nms := 0.0
	for pending_value in pending:
		var binding: Dictionary = pending_value
		prebinding_by_actuator[String(binding["actuator_id"])] = float(
			binding["prebinding_maximum_impulse_readback_nms"]
		)
		var prebinding_error := float(binding["prebinding_readback_error_nms"])
		maximum_prebinding_error_nms = maxf(
			maximum_prebinding_error_nms,
			prebinding_error,
		)
		prebinding_mismatch_count += int(prebinding_error > readback_tolerance_nms)
	for binding_value in ordered_bindings:
		var binding: Dictionary = binding_value
		binding["prebinding_maximum_impulse_readback_nms"] = float(
			prebinding_by_actuator[String(binding["actuator_id"])]
		)
		binding["prebinding_readback_error_nms"] = absf(
			(
				float(binding["prebinding_maximum_impulse_readback_nms"])
				- float(binding["declared_maximum_impulse_nms"])
			)
		)
	_binding_completed = true
	_binding_receipt = {
		"schema_version": RECEIPT_SCHEMA_VERSION,
		"ok": true,
		"failure_code": "",
		"policy_id": POLICY_ID,
		"fixture_composition_schema_version": FIXTURE_COMPOSITION_SCHEMA_VERSION,
		"ordered_actuator_ids": (inspection["ordered_actuator_ids"] as Array).duplicate(),
		"ordered_bindings": ordered_bindings,
		"validated_actuator_count": ordered_bindings.size(),
		"validated_limb_count": int(inspection["validated_limb_count"]),
		"unique_host_joint_object_count": int(inspection["unique_host_joint_object_count"]),
		"prebinding_mismatch_count": prebinding_mismatch_count,
		"maximum_prebinding_readback_error_nms": maximum_prebinding_error_nms,
		"write_count": ordered_bindings.size(),
		"readback_count": ordered_bindings.size(),
		"readback_tolerance_nms": readback_tolerance_nms,
		"maximum_postbinding_readback_error_nms": float(validation["maximum_readback_error_nms"]),
		"all_fixture_composition_markers_valid": true,
		"all_host_joint_names_valid": true,
		"all_postbinding_readbacks_match": true,
		"scene_tree_insertion_count": int(inspection["scene_tree_insertion_count"]),
		"configured_parameter_readback_only": true,
		"measured_motor_torque_available": false,
		"measured_motor_impulse_available": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
	return _binding_receipt.duplicate(true)


func validate_bound_actuator_caps(
	morphology: Dictionary,
	joint_state_by_joint_id: Dictionary,
	readback_tolerance_nms: float,
	policy_id: String = POLICY_ID,
) -> Dictionary:
	if not _binding_completed:
		return _failure("LIVE_FIXTURE_CAP_VALIDATION_BEFORE_BINDING")
	var inspection := _inspect_surface(
		morphology,
		joint_state_by_joint_id,
		readback_tolerance_nms,
		policy_id,
		true,
	)
	if not bool(inspection.get("ok", false)):
		return inspection
	return {
		"schema_version": VALIDATION_SCHEMA_VERSION,
		"ok": true,
		"failure_code": "",
		"policy_id": POLICY_ID,
		"fixture_composition_schema_version": FIXTURE_COMPOSITION_SCHEMA_VERSION,
		"validated_actuator_count": int(inspection["validated_actuator_count"]),
		"validated_limb_count": int(inspection["validated_limb_count"]),
		"unique_host_joint_object_count": int(inspection["unique_host_joint_object_count"]),
		"readback_tolerance_nms": readback_tolerance_nms,
		"maximum_readback_error_nms": float(inspection["maximum_readback_error_nms"]),
		"scene_tree_insertion_count": int(inspection["scene_tree_insertion_count"]),
		"configured_parameter_readback_only": true,
		"measured_motor_torque_available": false,
		"measured_motor_impulse_available": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


func binding_receipt() -> Dictionary:
	return _binding_receipt.duplicate(true)


static func _inspect_surface(
	morphology: Dictionary,
	joint_state_by_joint_id: Dictionary,
	readback_tolerance_nms: float,
	policy_id: String,
	require_readback_match: bool,
) -> Dictionary:
	if policy_id != POLICY_ID:
		return _failure("LIVE_FIXTURE_CAP_BINDING_POLICY_INVALID")
	if (
		not is_finite(readback_tolerance_nms)
		or readback_tolerance_nms < 0.0
		or readback_tolerance_nms > MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS
	):
		return _failure("LIVE_FIXTURE_CAP_BINDING_TOLERANCE_INVALID")
	var ordered_actuator_ids: Array = morphology.get("ordered_actuator_ids", [])
	var ordered_limb_ids: Array = morphology.get("ordered_limb_ids", [])
	var morphology_spec: Dictionary = morphology.get("morphology_spec", {})
	var actuator_values: Array = morphology_spec.get("actuators", [])
	if (
		ordered_actuator_ids.size() != EXPECTED_ACTUATOR_COUNT
		or actuator_values.size() != EXPECTED_ACTUATOR_COUNT
		or ordered_limb_ids.size() != EXPECTED_LIMB_COUNT
		or joint_state_by_joint_id.size() != EXPECTED_ACTUATOR_COUNT
	):
		return _failure("LIVE_FIXTURE_CAP_BINDING_CARDINALITY_INVALID")
	var actuator_by_id: Dictionary = {}
	for actuator_value in actuator_values:
		if typeof(actuator_value) != TYPE_DICTIONARY:
			return _failure("LIVE_FIXTURE_CAP_BINDING_ACTUATOR_SPEC_INVALID")
		var actuator: Dictionary = actuator_value
		var actuator_id := String(actuator.get("actuator_id", ""))
		if actuator_id.is_empty() or actuator_by_id.has(actuator_id):
			return _failure("LIVE_FIXTURE_CAP_BINDING_ACTUATOR_ID_INVALID")
		actuator_by_id[actuator_id] = actuator
	var pending_bindings: Array = []
	var ordered_bindings: Array = []
	var observed_joint_ids: Dictionary = {}
	var observed_instance_ids: Dictionary = {}
	var observed_limb_ids: Dictionary = {}
	var maximum_readback_error_nms := 0.0
	var scene_tree_insertion_count := 0
	for actuator_index in range(ordered_actuator_ids.size()):
		var actuator_id := String(ordered_actuator_ids[actuator_index])
		if not actuator_by_id.has(actuator_id):
			return _failure("LIVE_FIXTURE_CAP_BINDING_ACTUATOR_ORDER_INVALID:%s" % actuator_id)
		var actuator: Dictionary = actuator_by_id[actuator_id]
		var portable_joint_id := String(actuator.get("joint_id", ""))
		var declared_cap := float(actuator.get("maximum_impulse_nms", NAN))
		var identity := _expected_host_identity(portable_joint_id)
		var host_joint_id := String(identity.get("host_joint_id", ""))
		if (
			portable_joint_id.is_empty()
			or host_joint_id.is_empty()
			or observed_joint_ids.has(host_joint_id)
			or not bool(identity.get("ok", false))
			or not is_finite(declared_cap)
			or declared_cap <= 0.0
			or not joint_state_by_joint_id.has(host_joint_id)
		):
			return _failure(
				"LIVE_FIXTURE_CAP_BINDING_MAPPING_INVALID:%s" % actuator_id,
				{
					"actuator_id": actuator_id,
					"portable_joint_id": portable_joint_id,
					"host_joint_id": host_joint_id,
					"joint_id_already_observed": observed_joint_ids.has(host_joint_id),
					"host_identity": identity,
					"declared_maximum_impulse_nms": declared_cap,
					"host_joint_state_present": joint_state_by_joint_id.has(host_joint_id),
				},
			)
		var state_value: Variant = joint_state_by_joint_id[host_joint_id]
		if typeof(state_value) != TYPE_DICTIONARY:
			return _failure("LIVE_FIXTURE_CAP_BINDING_JOINT_STATE_INVALID:%s" % actuator_id)
		var state: Dictionary = state_value
		var joint_value: Variant = state.get("joint")
		if not (joint_value is HingeJoint3D):
			return _failure("LIVE_FIXTURE_CAP_BINDING_HOST_JOINT_INVALID:%s" % actuator_id)
		var joint: HingeJoint3D = joint_value
		var instance_id := joint.get_instance_id()
		if observed_instance_ids.has(instance_id):
			return _failure("LIVE_FIXTURE_CAP_BINDING_DUPLICATE_HOST_OBJECT:%s" % actuator_id)
		if (
			String(joint.name) != String(identity["host_joint_name"])
			or not joint.has_meta("lab_joint_id")
			or String(joint.get_meta("lab_joint_id")) != host_joint_id
			or not joint.has_meta("sporespore_fixture_joint_composition_schema_version")
			or (
				String(joint.get_meta("sporespore_fixture_joint_composition_schema_version"))
				!= FIXTURE_COMPOSITION_SCHEMA_VERSION
			)
		):
			return _failure("LIVE_FIXTURE_CAP_BINDING_FIXTURE_IDENTITY_INVALID:%s" % actuator_id)
		var readback := float(joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE))
		var readback_error := absf(readback - declared_cap)
		if not is_finite(readback) or not is_finite(readback_error):
			return _failure("LIVE_FIXTURE_CAP_BINDING_READBACK_NONFINITE:%s" % actuator_id)
		if require_readback_match and readback_error > readback_tolerance_nms:
			return _failure(
				"LIVE_FIXTURE_CAP_BINDING_READBACK_MISMATCH:%s" % actuator_id,
				{
					"actuator_id": actuator_id,
					"joint_id": portable_joint_id,
					"host_joint_id": host_joint_id,
					"declared_maximum_impulse_nms": declared_cap,
					"motor_maximum_impulse_readback_nms": readback,
					"readback_error_nms": readback_error,
					"readback_tolerance_nms": readback_tolerance_nms,
				},
			)
		maximum_readback_error_nms = maxf(maximum_readback_error_nms, readback_error)
		scene_tree_insertion_count += int(joint.is_inside_tree())
		observed_joint_ids[host_joint_id] = true
		observed_instance_ids[instance_id] = true
		observed_limb_ids[String(identity["limb_id"])] = true
		(
			pending_bindings
			. append(
				{
					"actuator_id": actuator_id,
					"joint_id": portable_joint_id,
					"host_joint_id": host_joint_id,
					"limb_id": String(identity["limb_id"]),
					"joint_role": String(identity["joint_role"]),
					"host_joint_name": String(identity["host_joint_name"]),
					"joint": joint,
					"declared_maximum_impulse_nms": declared_cap,
					"prebinding_maximum_impulse_readback_nms": readback,
					"prebinding_readback_error_nms": readback_error,
				}
			)
		)
		(
			ordered_bindings
			. append(
				{
					"actuator_id": actuator_id,
					"joint_id": portable_joint_id,
					"host_joint_id": host_joint_id,
					"limb_id": String(identity["limb_id"]),
					"joint_role": String(identity["joint_role"]),
					"host_joint_name": String(identity["host_joint_name"]),
					"declared_maximum_impulse_nms": declared_cap,
					"motor_maximum_impulse_readback_nms": readback,
					"readback_error_nms": readback_error,
					"readback_matches": readback_error <= readback_tolerance_nms,
				}
			)
		)
	if (
		observed_joint_ids.size() != EXPECTED_ACTUATOR_COUNT
		or observed_instance_ids.size() != EXPECTED_ACTUATOR_COUNT
		or observed_limb_ids.size() != EXPECTED_LIMB_COUNT
	):
		return _failure("LIVE_FIXTURE_CAP_BINDING_COVERAGE_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"ordered_actuator_ids": ordered_actuator_ids.duplicate(),
		"pending_bindings": pending_bindings,
		"ordered_bindings": ordered_bindings,
		"validated_actuator_count": observed_joint_ids.size(),
		"validated_limb_count": observed_limb_ids.size(),
		"unique_host_joint_object_count": observed_instance_ids.size(),
		"maximum_readback_error_nms": maximum_readback_error_nms,
		"scene_tree_insertion_count": scene_tree_insertion_count,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _expected_host_identity(portable_joint_id: String) -> Dictionary:
	var host_role := (
		"hip"
		if portable_joint_id.ends_with("_hip")
		else ("knee" if portable_joint_id.ends_with("_knee") else "")
	)
	var limb_id := (
		portable_joint_id.trim_suffix("_%s" % host_role) if not host_role.is_empty() else ""
	)
	var portable_role := "%s_pitch" % host_role if not host_role.is_empty() else ""
	if limb_id.is_empty() or host_role.is_empty():
		return {"ok": false}
	return {
		"ok": true,
		"limb_id": limb_id,
		"joint_role": portable_role,
		"host_joint_id": "%s.%s" % [limb_id, portable_role],
		"host_joint_name": "wave_gait_%s_%s" % [limb_id, host_role],
	}


static func _zero_motor_targets(pending_bindings: Array) -> void:
	for binding_value in pending_bindings:
		if typeof(binding_value) != TYPE_DICTIONARY:
			continue
		var binding: Dictionary = binding_value
		var joint_value: Variant = binding.get("joint")
		if joint_value is HingeJoint3D:
			var joint: HingeJoint3D = joint_value
			joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.0)


static func _failure(code: String, detail: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"failure_code": code,
		"detail": detail.duplicate(true),
		"configured_parameter_readback_only": true,
		"measured_motor_torque_available": false,
		"measured_motor_impulse_available": false,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}
