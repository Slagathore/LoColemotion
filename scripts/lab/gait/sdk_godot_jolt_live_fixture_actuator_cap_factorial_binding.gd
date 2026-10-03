class_name LabSdkGodotJoltLiveFixtureActuatorCapFactorialBinding
extends RefCounted
# gdlint: disable=max-returns
# gdlint: disable=max-line-length

## Prospective R23D58 one-time cap-source factorial binding.
##
## Each fresh fixture supplies two prospectively named cap sources:
##
## - the SDK-compiled portable cap carried by the morphology; and
## - the exact configured cap read from the newly composed legacy fixture.
##
## Hip and knee source selection are crossed into a complete 2 x 2 design.
## The component validates the complete eight-joint identity surface before
## its first write, performs exactly one write and one readback per actuator,
## and never constructs or advances a physics world by itself.

const POLICY_ID := "sporespore_godot_jolt_live_fixture_cap_source_factorial_binding_v1"
const FIXTURE_COMPOSITION_SCHEMA_VERSION := "sporespore_godot_jolt_fixture_joint_composition_v1"
const RECEIPT_SCHEMA_VERSION := "sporespore_godot_jolt_live_fixture_cap_source_factorial_binding_receipt_v1"
const VALIDATION_SCHEMA_VERSION := "sporespore_godot_jolt_live_fixture_cap_source_factorial_validation_receipt_v1"

const CAP_SOURCE_PORTABLE_COMPILED := "portable_compiled_morphology"
const CAP_SOURCE_FIXTURE_PREBINDING := "fixture_realized_prebinding"

const PROFILE_PORTABLE_HIP_PORTABLE_KNEE := "portable_hip__portable_knee"
const PROFILE_PORTABLE_HIP_FIXTURE_KNEE := "portable_hip__fixture_knee"
const PROFILE_FIXTURE_HIP_PORTABLE_KNEE := "fixture_hip__portable_knee"
const PROFILE_FIXTURE_HIP_FIXTURE_KNEE := "fixture_hip__fixture_knee"

const ORDERED_PROFILE_IDS := [
	PROFILE_PORTABLE_HIP_PORTABLE_KNEE,
	PROFILE_PORTABLE_HIP_FIXTURE_KNEE,
	PROFILE_FIXTURE_HIP_PORTABLE_KNEE,
	PROFILE_FIXTURE_HIP_FIXTURE_KNEE,
]

const PROFILE_DEFINITIONS := {
	PROFILE_PORTABLE_HIP_PORTABLE_KNEE: {
		"hip_cap_source": CAP_SOURCE_PORTABLE_COMPILED,
		"knee_cap_source": CAP_SOURCE_PORTABLE_COMPILED,
	},
	PROFILE_PORTABLE_HIP_FIXTURE_KNEE: {
		"hip_cap_source": CAP_SOURCE_PORTABLE_COMPILED,
		"knee_cap_source": CAP_SOURCE_FIXTURE_PREBINDING,
	},
	PROFILE_FIXTURE_HIP_PORTABLE_KNEE: {
		"hip_cap_source": CAP_SOURCE_FIXTURE_PREBINDING,
		"knee_cap_source": CAP_SOURCE_PORTABLE_COMPILED,
	},
	PROFILE_FIXTURE_HIP_FIXTURE_KNEE: {
		"hip_cap_source": CAP_SOURCE_FIXTURE_PREBINDING,
		"knee_cap_source": CAP_SOURCE_FIXTURE_PREBINDING,
	},
}

const EXPECTED_ACTUATOR_COUNT := 8
const EXPECTED_LIMB_COUNT := 4
const MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS := 1.0e-6

var _binding_completed := false
var _binding_receipt: Dictionary = {}
var _bound_instance_id_by_host_joint_id: Dictionary = {}


func preflight_profile(
	morphology: Dictionary,
	joint_state_by_joint_id: Dictionary,
	readback_tolerance_nms: float,
	profile_id: String,
	policy_id: String = POLICY_ID,
) -> Dictionary:
	var inspection := _inspect_unbound_surface(
		morphology,
		joint_state_by_joint_id,
		readback_tolerance_nms,
		profile_id,
		policy_id,
	)
	if not bool(inspection.get("ok", false)):
		return inspection
	return _public_preflight_projection(inspection)


func bind_profile(
	morphology: Dictionary,
	joint_state_by_joint_id: Dictionary,
	readback_tolerance_nms: float,
	profile_id: String,
	policy_id: String = POLICY_ID,
) -> Dictionary:
	if _binding_completed:
		return _failure("LIVE_FIXTURE_CAP_FACTORIAL_BINDING_ALREADY_COMPLETED")
	var inspection := _inspect_unbound_surface(
		morphology,
		joint_state_by_joint_id,
		readback_tolerance_nms,
		profile_id,
		policy_id,
	)
	if not bool(inspection.get("ok", false)):
		return inspection
	var pending: Array = inspection["pending_bindings"]
	for pending_value in pending:
		var binding: Dictionary = pending_value
		var joint: HingeJoint3D = binding["joint"]
		joint.set_param(
			HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE,
			float(binding["selected_maximum_impulse_nms"]),
		)
	var validation := _inspect_written_bindings(pending, readback_tolerance_nms)
	if not bool(validation.get("ok", false)):
		_zero_motor_targets(pending)
		return _failure(
			"LIVE_FIXTURE_CAP_FACTORIAL_BINDING_READBACK_INVALID:%s"
			% String(validation.get("failure_code", "UNKNOWN")),
			{"validation": validation},
		)
	var definition: Dictionary = inspection["profile_definition"]
	_binding_completed = true
	_bound_instance_id_by_host_joint_id.clear()
	for pending_value in pending:
		var pending_binding: Dictionary = pending_value
		var pending_joint: HingeJoint3D = pending_binding["joint"]
		_bound_instance_id_by_host_joint_id[String(pending_binding["host_joint_id"])] = (
			pending_joint.get_instance_id()
		)
	_binding_receipt = {
		"schema_version": RECEIPT_SCHEMA_VERSION,
		"ok": true,
		"failure_code": "",
		"policy_id": POLICY_ID,
		"profile_id": profile_id,
		"hip_cap_source": String(definition["hip_cap_source"]),
		"knee_cap_source": String(definition["knee_cap_source"]),
		"factorial_design": "two_by_two_hip_source_x_knee_source",
		"fixture_composition_schema_version": FIXTURE_COMPOSITION_SCHEMA_VERSION,
		"ordered_actuator_ids": (inspection["ordered_actuator_ids"] as Array).duplicate(),
		"ordered_bindings": (validation["ordered_bindings"] as Array).duplicate(true),
		"validated_actuator_count": int(validation["validated_actuator_count"]),
		"validated_limb_count": int(inspection["validated_limb_count"]),
		"unique_host_joint_object_count": int(inspection["unique_host_joint_object_count"]),
		"portable_fixture_distinct_actuator_count": int(
			inspection["portable_fixture_distinct_actuator_count"]
		),
		"maximum_portable_fixture_absolute_delta_nms": float(
			inspection["maximum_portable_fixture_absolute_delta_nms"]
		),
		"write_count": int(validation["validated_actuator_count"]),
		"readback_count": int(validation["validated_actuator_count"]),
		"readback_tolerance_nms": readback_tolerance_nms,
		"maximum_postbinding_readback_error_nms": float(
			validation["maximum_readback_error_nms"]
		),
		"all_fixture_composition_markers_valid": true,
		"all_host_joint_names_valid": true,
		"all_postbinding_readbacks_match": true,
		"complete_surface_validated_before_first_write": true,
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


func validate_bound_profile(
	joint_state_by_joint_id: Dictionary,
	readback_tolerance_nms: float,
	profile_id: String,
	policy_id: String = POLICY_ID,
) -> Dictionary:
	if not _binding_completed:
		return _failure("LIVE_FIXTURE_CAP_FACTORIAL_VALIDATION_BEFORE_BINDING")
	if policy_id != POLICY_ID:
		return _failure("LIVE_FIXTURE_CAP_FACTORIAL_POLICY_INVALID")
	if profile_id != String(_binding_receipt.get("profile_id", "")):
		return _failure("LIVE_FIXTURE_CAP_FACTORIAL_PROFILE_CHANGED")
	if not _tolerance_valid(readback_tolerance_nms):
		return _failure("LIVE_FIXTURE_CAP_FACTORIAL_TOLERANCE_INVALID")
	if joint_state_by_joint_id.size() != EXPECTED_ACTUATOR_COUNT:
		return _failure("LIVE_FIXTURE_CAP_FACTORIAL_CARDINALITY_INVALID")
	var expected_bindings: Array = _binding_receipt.get("ordered_bindings", [])
	var pending: Array = []
	var observed_host_ids: Dictionary = {}
	for expected_value in expected_bindings:
		if typeof(expected_value) != TYPE_DICTIONARY:
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_RECEIPT_BINDING_INVALID")
		var expected: Dictionary = expected_value
		var host_joint_id := String(expected.get("host_joint_id", ""))
		if (
			host_joint_id.is_empty()
			or observed_host_ids.has(host_joint_id)
			or not joint_state_by_joint_id.has(host_joint_id)
			or not _bound_instance_id_by_host_joint_id.has(host_joint_id)
		):
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_BOUND_IDENTITY_INVALID")
		var state_value: Variant = joint_state_by_joint_id[host_joint_id]
		if typeof(state_value) != TYPE_DICTIONARY:
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_BOUND_STATE_INVALID")
		var joint_value: Variant = (state_value as Dictionary).get("joint")
		if not (joint_value is HingeJoint3D):
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_BOUND_JOINT_INVALID")
		var joint: HingeJoint3D = joint_value
		if joint.get_instance_id() != int(_bound_instance_id_by_host_joint_id[host_joint_id]):
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_BOUND_OBJECT_CHANGED")
		var pending_binding := expected.duplicate(true)
		pending_binding["joint"] = joint
		pending.append(pending_binding)
		observed_host_ids[host_joint_id] = true
	var validation := _inspect_written_bindings(pending, readback_tolerance_nms)
	if not bool(validation.get("ok", false)):
		return validation
	return {
		"schema_version": VALIDATION_SCHEMA_VERSION,
		"ok": true,
		"failure_code": "",
		"policy_id": POLICY_ID,
		"profile_id": profile_id,
		"validated_actuator_count": int(validation["validated_actuator_count"]),
		"readback_count": int(validation["validated_actuator_count"]),
		"readback_tolerance_nms": readback_tolerance_nms,
		"maximum_readback_error_nms": float(validation["maximum_readback_error_nms"]),
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


static func profile_definition(profile_id: String) -> Dictionary:
	if not PROFILE_DEFINITIONS.has(profile_id):
		return {}
	return (PROFILE_DEFINITIONS[profile_id] as Dictionary).duplicate(true)


static func _inspect_unbound_surface(
	morphology: Dictionary,
	joint_state_by_joint_id: Dictionary,
	readback_tolerance_nms: float,
	profile_id: String,
	policy_id: String,
) -> Dictionary:
	if policy_id != POLICY_ID:
		return _failure("LIVE_FIXTURE_CAP_FACTORIAL_POLICY_INVALID")
	if not _tolerance_valid(readback_tolerance_nms):
		return _failure("LIVE_FIXTURE_CAP_FACTORIAL_TOLERANCE_INVALID")
	var definition := profile_definition(profile_id)
	if definition.is_empty():
		return _failure("LIVE_FIXTURE_CAP_FACTORIAL_PROFILE_INVALID")
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
		return _failure("LIVE_FIXTURE_CAP_FACTORIAL_CARDINALITY_INVALID")
	var actuator_by_id: Dictionary = {}
	for actuator_value in actuator_values:
		if typeof(actuator_value) != TYPE_DICTIONARY:
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_ACTUATOR_SPEC_INVALID")
		var actuator: Dictionary = actuator_value
		var actuator_id := String(actuator.get("actuator_id", ""))
		if actuator_id.is_empty() or actuator_by_id.has(actuator_id):
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_ACTUATOR_ID_INVALID")
		actuator_by_id[actuator_id] = actuator
	var pending_bindings: Array = []
	var observed_joint_ids: Dictionary = {}
	var observed_instance_ids: Dictionary = {}
	var observed_limb_ids: Dictionary = {}
	var distinct_count := 0
	var maximum_delta := 0.0
	var scene_tree_insertion_count := 0
	for actuator_id_value in ordered_actuator_ids:
		var actuator_id := String(actuator_id_value)
		if not actuator_by_id.has(actuator_id):
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_ACTUATOR_ORDER_INVALID:%s" % actuator_id)
		var actuator: Dictionary = actuator_by_id[actuator_id]
		var portable_joint_id := String(actuator.get("joint_id", ""))
		var portable_cap := float(actuator.get("maximum_impulse_nms", NAN))
		var identity := _expected_host_identity(portable_joint_id)
		var host_joint_id := String(identity.get("host_joint_id", ""))
		if (
			portable_joint_id.is_empty()
			or not bool(identity.get("ok", false))
			or host_joint_id.is_empty()
			or observed_joint_ids.has(host_joint_id)
			or not is_finite(portable_cap)
			or portable_cap <= 0.0
			or not joint_state_by_joint_id.has(host_joint_id)
		):
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_MAPPING_INVALID:%s" % actuator_id)
		var state_value: Variant = joint_state_by_joint_id[host_joint_id]
		if typeof(state_value) != TYPE_DICTIONARY:
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_JOINT_STATE_INVALID:%s" % actuator_id)
		var joint_value: Variant = (state_value as Dictionary).get("joint")
		if not (joint_value is HingeJoint3D):
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_HOST_JOINT_INVALID:%s" % actuator_id)
		var joint: HingeJoint3D = joint_value
		var instance_id := joint.get_instance_id()
		if observed_instance_ids.has(instance_id):
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_DUPLICATE_HOST_OBJECT:%s" % actuator_id)
		if (
			String(joint.name) != String(identity["host_joint_name"])
			or not joint.has_meta("lab_joint_id")
			or String(joint.get_meta("lab_joint_id")) != host_joint_id
			or not joint.has_meta("sporespore_fixture_joint_composition_schema_version")
			or String(joint.get_meta("sporespore_fixture_joint_composition_schema_version"))
			!= FIXTURE_COMPOSITION_SCHEMA_VERSION
		):
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_FIXTURE_IDENTITY_INVALID:%s" % actuator_id)
		var fixture_cap := float(joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE))
		if not is_finite(fixture_cap) or fixture_cap <= 0.0:
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_PREBINDING_CAP_INVALID:%s" % actuator_id)
		var joint_role := String(identity["joint_role"])
		var selected_source := (
			String(definition["hip_cap_source"])
			if joint_role == "hip_pitch"
			else String(definition["knee_cap_source"])
		)
		var selected_cap := (
			portable_cap if selected_source == CAP_SOURCE_PORTABLE_COMPILED else fixture_cap
		)
		var source_delta := absf(portable_cap - fixture_cap)
		distinct_count += int(source_delta > readback_tolerance_nms)
		maximum_delta = maxf(maximum_delta, source_delta)
		scene_tree_insertion_count += int(joint.is_inside_tree())
		observed_joint_ids[host_joint_id] = true
		observed_instance_ids[instance_id] = true
		observed_limb_ids[String(identity["limb_id"])] = true
		pending_bindings.append(
			{
				"actuator_id": actuator_id,
				"joint_id": portable_joint_id,
				"host_joint_id": host_joint_id,
				"limb_id": String(identity["limb_id"]),
				"joint_role": joint_role,
				"host_joint_name": String(identity["host_joint_name"]),
				"selected_cap_source": selected_source,
				"portable_compiled_maximum_impulse_nms": portable_cap,
				"fixture_prebinding_maximum_impulse_nms": fixture_cap,
				"portable_fixture_absolute_delta_nms": source_delta,
				"selected_maximum_impulse_nms": selected_cap,
				"joint": joint,
			}
		)
	if (
		observed_joint_ids.size() != EXPECTED_ACTUATOR_COUNT
		or observed_instance_ids.size() != EXPECTED_ACTUATOR_COUNT
		or observed_limb_ids.size() != EXPECTED_LIMB_COUNT
	):
		return _failure("LIVE_FIXTURE_CAP_FACTORIAL_COVERAGE_INVALID")
	return {
		"ok": true,
		"failure_code": "",
		"profile_id": profile_id,
		"profile_definition": definition,
		"ordered_actuator_ids": ordered_actuator_ids.duplicate(),
		"pending_bindings": pending_bindings,
		"validated_actuator_count": observed_joint_ids.size(),
		"validated_limb_count": observed_limb_ids.size(),
		"unique_host_joint_object_count": observed_instance_ids.size(),
		"portable_fixture_distinct_actuator_count": distinct_count,
		"maximum_portable_fixture_absolute_delta_nms": maximum_delta,
		"scene_tree_insertion_count": scene_tree_insertion_count,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _inspect_written_bindings(
	pending_bindings: Array,
	readback_tolerance_nms: float,
) -> Dictionary:
	if not _tolerance_valid(readback_tolerance_nms):
		return _failure("LIVE_FIXTURE_CAP_FACTORIAL_TOLERANCE_INVALID")
	if pending_bindings.size() != EXPECTED_ACTUATOR_COUNT:
		return _failure("LIVE_FIXTURE_CAP_FACTORIAL_WRITTEN_CARDINALITY_INVALID")
	var ordered_bindings: Array = []
	var maximum_error := 0.0
	for pending_value in pending_bindings:
		if typeof(pending_value) != TYPE_DICTIONARY:
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_PENDING_BINDING_INVALID")
		var pending: Dictionary = pending_value
		var joint_value: Variant = pending.get("joint")
		if not (joint_value is HingeJoint3D):
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_PENDING_JOINT_INVALID")
		var joint: HingeJoint3D = joint_value
		var selected_cap := float(pending.get("selected_maximum_impulse_nms", NAN))
		var readback := float(joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE))
		var error := absf(readback - selected_cap)
		if not is_finite(selected_cap) or not is_finite(readback) or not is_finite(error):
			return _failure("LIVE_FIXTURE_CAP_FACTORIAL_READBACK_NONFINITE")
		if error > readback_tolerance_nms:
			return _failure(
				"LIVE_FIXTURE_CAP_FACTORIAL_READBACK_MISMATCH:%s"
				% String(pending.get("actuator_id", "")),
				{
					"actuator_id": pending.get("actuator_id"),
					"selected_maximum_impulse_nms": selected_cap,
					"motor_maximum_impulse_readback_nms": readback,
					"readback_error_nms": error,
					"readback_tolerance_nms": readback_tolerance_nms,
				},
			)
		maximum_error = maxf(maximum_error, error)
		var projected := pending.duplicate(true)
		projected.erase("joint")
		projected["motor_maximum_impulse_readback_nms"] = readback
		projected["readback_error_nms"] = error
		projected["readback_matches"] = true
		ordered_bindings.append(projected)
	return {
		"ok": true,
		"failure_code": "",
		"ordered_bindings": ordered_bindings,
		"validated_actuator_count": ordered_bindings.size(),
		"maximum_readback_error_nms": maximum_error,
		"model_construction_count": 0,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"physics_state_modified": false,
		"physical_acceptance_authority": false,
	}


static func _public_preflight_projection(inspection: Dictionary) -> Dictionary:
	var ordered_bindings: Array = []
	for pending_value in inspection.get("pending_bindings", []):
		var projected: Dictionary = (pending_value as Dictionary).duplicate(true)
		projected.erase("joint")
		ordered_bindings.append(projected)
	return {
		"schema_version": "sporespore_godot_jolt_live_fixture_cap_source_factorial_preflight_v1",
		"ok": true,
		"failure_code": "",
		"policy_id": POLICY_ID,
		"profile_id": String(inspection["profile_id"]),
		"profile_definition": (inspection["profile_definition"] as Dictionary).duplicate(true),
		"ordered_bindings": ordered_bindings,
		"validated_actuator_count": int(inspection["validated_actuator_count"]),
		"validated_limb_count": int(inspection["validated_limb_count"]),
		"unique_host_joint_object_count": int(inspection["unique_host_joint_object_count"]),
		"portable_fixture_distinct_actuator_count": int(
			inspection["portable_fixture_distinct_actuator_count"]
		),
		"maximum_portable_fixture_absolute_delta_nms": float(
			inspection["maximum_portable_fixture_absolute_delta_nms"]
		),
		"scene_tree_insertion_count": int(inspection["scene_tree_insertion_count"]),
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
	if limb_id.is_empty() or host_role.is_empty():
		return {"ok": false}
	return {
		"ok": true,
		"limb_id": limb_id,
		"joint_role": "%s_pitch" % host_role,
		"host_joint_id": "%s.%s_pitch" % [limb_id, host_role],
		"host_joint_name": "wave_gait_%s_%s" % [limb_id, host_role],
	}


static func _tolerance_valid(value: float) -> bool:
	return is_finite(value) and value >= 0.0 and value <= MAXIMUM_ALLOWED_READBACK_TOLERANCE_NMS


static func _zero_motor_targets(pending_bindings: Array) -> void:
	for pending_value in pending_bindings:
		if typeof(pending_value) != TYPE_DICTIONARY:
			continue
		var joint_value: Variant = (pending_value as Dictionary).get("joint")
		if joint_value is HingeJoint3D:
			(joint_value as HingeJoint3D).set_param(
				HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY,
				0.0,
			)


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
