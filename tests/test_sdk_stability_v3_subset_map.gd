extends SceneTree

## Independent no-world oracle for Locomotion Semantics v3 partial-support
## mapping. The expected torques are recomputed here from the documented
## virtual-work equation rather than imported from Rust output.

const EXTENSION_PATH := (
	"res://sdk/adapters/godot/sporespore_locomotion.gdextension"
)
const CLASS_NAME := "SporeLocomotionSdk"
const TORQUE_TOLERANCE_NM := 1.0e-6

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK stability v3 partial-support oracle ===")
	var extension_resource := load(EXTENSION_PATH)
	var api: Object = null
	if ClassDB.class_exists(CLASS_NAME):
		api = ClassDB.instantiate(CLASS_NAME)
	_check(
		extension_resource != null and api != null,
		"the real Godot GDExtension loads and instantiates",
	)
	if api == null:
		_finish()
		return

	var descriptor := _reference_descriptor("stability_v3_subset_map")
	var compile_envelope := _call_input(
		api,
		"compile_bounded_quadruped_json",
		descriptor,
	)
	var morphology: Dictionary = compile_envelope.get("value", {}).get(
		"morphology",
		{},
	)
	_check(
		bool(compile_envelope.get("ok", false))
		and (morphology.get("ordered_actuator_ids", []) as Array).size() == 8,
		"the fixture compiles to eight ordered actuators",
	)
	if morphology.is_empty():
		_finish()
		return

	var partial_request := _centroidal_request(morphology, "front_right_foot", 21)
	var partial_command_envelope := _call_input(
		api,
		"command_centroidal_support_v2_json",
		partial_request,
	)
	var partial_command: Dictionary = partial_command_envelope.get("value", {})
	_check(
		bool(partial_command_envelope.get("ok", false))
		and bool(partial_command.get("feasible", false))
		and (
			partial_command.get("ordered_support_contact_commands", []) as Array
		).size()
		== 3,
		"the independent three-contact centroidal fixture is feasible",
	)
	_replace_task_forces(partial_command, Vector3(2.0, 0.0, 0.0))
	var partial_map_request := _map_request_v3(
		descriptor,
		morphology,
		partial_command,
		21,
	)
	var partial_envelope := _call_input(
		api,
		"map_endpoint_force_to_joint_v3_json",
		partial_map_request,
	)
	var partial_receipt: Dictionary = partial_envelope.get("value", {})
	_check(
		bool(partial_envelope.get("ok", false)),
		"the v3 operation crosses the real C ABI and Godot boundary",
	)
	var partial_mapped: Array = partial_receipt.get(
		"ordered_generalized_joint_torque_commands",
		[],
	)
	_check(
		String(partial_receipt.get("schema_version", ""))
		== "sporespore_endpoint_force_joint_map_receipt_v3"
		and int(partial_receipt.get("active_actuator_count", -1)) == 6
		and int(partial_receipt.get("inactive_actuator_count", -1)) == 2
		and (
			partial_receipt.get("ordered_active_support_contact_ids", []) as Array
		)
		== [
			"front_left_foot",
			"rear_left_foot",
			"rear_right_foot",
		],
		"the receipt preserves active-contact order and the six-two partition",
	)
	var mapped_ids: Array[String] = []
	for mapped_value in partial_mapped:
		mapped_ids.append(String((mapped_value as Dictionary)["actuator_id"]))
	_check(
		mapped_ids == _string_array(morphology["ordered_actuator_ids"]),
		"the v3 receipt preserves exact compiled actuator order",
	)

	var command_by_contact := _command_by_contact(partial_command)
	var kinematics_by_actuator := _kinematics_by_actuator(partial_map_request)
	var active_oracle_exact := true
	var inactive_zero_exact := true
	for mapped_value in partial_mapped:
		var mapped: Dictionary = mapped_value
		var actuator_id := String(mapped["actuator_id"])
		var contact_id := String(mapped["contact_site_id"])
		if bool(mapped["active_support_contact"]):
			var kinematics: Dictionary = kinematics_by_actuator[actuator_id]
			var contact_command: Dictionary = command_by_contact[contact_id]
			var axis := _dict_vector(kinematics["joint_axis_world_unit"])
			var anchor := _dict_vector(kinematics["joint_anchor_world_m"])
			var endpoint := _dict_vector(kinematics["endpoint_world_m"])
			var force := _dict_vector(
				contact_command["joint_task_force_delta_world_n"]
			)
			var expected_torque := axis.cross(endpoint - anchor).dot(force)
			active_oracle_exact = (
				active_oracle_exact
				and String(mapped["mapping_mode"]) == "support_command"
				and not bool(mapped["inactive_contact_forced_zero"])
				and absf(
					float(mapped["generalized_torque_command_nm"])
					- expected_torque
				)
				<= TORQUE_TOLERANCE_NM
			)
		else:
			var force := _dict_vector(
				mapped["endpoint_task_force_command_world_n"]
			)
			inactive_zero_exact = (
				inactive_zero_exact
				and contact_id == "front_right_foot"
				and String(mapped["mapping_mode"]) == "inactive_contact_zero"
				and bool(mapped["inactive_contact_forced_zero"])
				and force == Vector3.ZERO
				and float(mapped["generalized_torque_command_nm"]) == 0.0
			)
	_check(
		active_oracle_exact,
		"all active torques match the independent virtual-work oracle",
	)
	_check(
		inactive_zero_exact,
		"both swing-limb actuator contributions are explicit exact zero",
	)
	_check(
		bool(partial_receipt.get("endpoint_force_map_available", false))
		and bool(partial_receipt.get("partial_support_mapping_available", false))
		and bool(
			partial_receipt.get("inactive_contact_commands_forced_zero", false)
		)
		and not bool(
			partial_receipt.get("measured_joint_torque_available", true)
		)
		and not bool(partial_receipt.get("actuator_response_characterized", true))
		and not bool(partial_receipt.get("adapter_actuation_applied", true))
		and not bool(partial_receipt.get("physics_state_modified", true))
		and not bool(partial_receipt.get("physical_acceptance_authority", true)),
		"the v3 receipt preserves every portable authority nonclaim",
	)

	var translated_request: Dictionary = partial_map_request.duplicate(true)
	var translated_inner: Dictionary = translated_request["request"]
	var offset := Vector3(7.0, -3.0, 11.0)
	for kinematics_value in translated_inner["ordered_actuator_kinematics"]:
		var kinematics: Dictionary = kinematics_value
		kinematics["joint_anchor_world_m"] = _vector_dict(
			_dict_vector(kinematics["joint_anchor_world_m"]) + offset
		)
		kinematics["endpoint_world_m"] = _vector_dict(
			_dict_vector(kinematics["endpoint_world_m"]) + offset
		)
	var translated_envelope := _call_input(
		api,
		"map_endpoint_force_to_joint_v3_json",
		translated_request,
	)
	_check(
		bool(translated_envelope.get("ok", false))
		and _torques_match(
			partial_mapped,
			(
				translated_envelope.get("value", {}) as Dictionary
			).get("ordered_generalized_joint_torque_commands", []),
		),
		"common translation leaves active torques and inactive zeros unchanged",
	)

	var full_request := _centroidal_request(morphology, "", 22)
	var full_command_envelope := _call_input(
		api,
		"command_centroidal_support_v2_json",
		full_request,
	)
	var full_command: Dictionary = full_command_envelope.get("value", {})
	_replace_task_forces(full_command, Vector3(2.0, 0.0, 0.0))
	var v2_map_request := _map_request_v2(
		descriptor,
		morphology,
		full_command,
		22,
	)
	var v3_map_request: Dictionary = v2_map_request.duplicate(true)
	v3_map_request["schema_version"] = (
		"sporespore_map_endpoint_force_to_joint_request_v3"
	)
	(v3_map_request["request"] as Dictionary)["schema_version"] = (
		"sporespore_endpoint_force_joint_map_request_v3"
	)
	var v2_envelope := _call_input(
		api,
		"map_endpoint_force_to_joint_v2_json",
		v2_map_request,
	)
	var v3_full_envelope := _call_input(
		api,
		"map_endpoint_force_to_joint_v3_json",
		v3_map_request,
	)
	var v2_mapped: Array = (
		v2_envelope.get("value", {}) as Dictionary
	).get("ordered_generalized_joint_torque_commands", [])
	var v3_full_mapped: Array = (
		v3_full_envelope.get("value", {}) as Dictionary
	).get("ordered_generalized_joint_torque_commands", [])
	_check(
		bool(full_command_envelope.get("ok", false))
		and bool(v2_envelope.get("ok", false))
		and bool(v3_full_envelope.get("ok", false))
		and _torques_match(v2_mapped, v3_full_mapped)
		and int(
			(
				v3_full_envelope.get("value", {}) as Dictionary
			).get("inactive_actuator_count", -1)
		)
		== 0,
		"full-support v3 is numerically equivalent to the retained v2 map",
	)

	var malformed_request: Dictionary = partial_map_request.duplicate(true)
	var malformed_inner: Dictionary = malformed_request["request"]
	var malformed_command: Dictionary = malformed_inner["centroidal_command"]
	var malformed_contacts: Array = malformed_command[
		"ordered_support_contact_commands"
	]
	(malformed_contacts[0] as Dictionary)["contact_id"] = "unknown_contact"
	var malformed_envelope := _call_input(
		api,
		"map_endpoint_force_to_joint_v3_json",
		malformed_request,
	)
	_check(
		not bool(malformed_envelope.get("ok", true))
		and String(malformed_envelope.get("failure_code", ""))
		== "REFERENCE_INVALID"
		and String(malformed_envelope.get("detail", "")).begins_with(
			"endpoint_force_v3_active_contact_not_compiled:"
		),
		"an unknown active contact fails closed with a typed reference error",
	)
	print(
		"SDK_STABILITY_V3_SUBSET_MAP_RECEIPT ",
		JSON.stringify(
			{
				"schema_version":
				"sporespore_stability_v3_subset_map_receipt_v1",
				"ok": _failed == 0,
				"partial_support_receipt": partial_receipt,
				"full_support_v2_receipt": v2_envelope.get("value", {}),
				"full_support_v3_receipt": v3_full_envelope.get("value", {}),
				"malformed_active_contact_outcome": malformed_envelope,
				"independent_active_torque_oracle_exact": active_oracle_exact,
				"inactive_contact_commands_exact_zero": inactive_zero_exact,
				"common_translation_invariant":
					bool(translated_envelope.get("ok", false))
					and _torques_match(
						partial_mapped,
						(
							translated_envelope.get("value", {}) as Dictionary
						).get(
							"ordered_generalized_joint_torque_commands",
							[],
						),
					),
				"full_support_v2_v3_equivalent":
					bool(v2_envelope.get("ok", false))
					and bool(v3_full_envelope.get("ok", false))
					and _torques_match(v2_mapped, v3_full_mapped),
				"adapter_actuation_applied": false,
				"physics_state_modified": false,
				"physical_balance_recovery": false,
				"locomotion": false,
				"friction_material_robustness": false,
				"cross_engine_c6": false,
				"physical_acceptance_authority": false,
				"completed_engine_neutral_sdk": false,
			}
		),
	)
	_finish()


func _reference_descriptor(morphology_id: String) -> Dictionary:
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


func _centroidal_request(
	morphology: Dictionary,
	inactive_contact_id: String,
	semantic_step: int,
) -> Dictionary:
	var contacts: Array = []
	var point_sum := Vector3.ZERO
	for contact_id_value in morphology["ordered_contact_site_ids"]:
		var contact_id := String(contact_id_value)
		if contact_id == inactive_contact_id:
			continue
		var point := Vector3(
			-0.22 if contact_id.begins_with("front") else 0.22,
			0.0,
			-0.22 if contact_id.contains("left") else 0.22,
		)
		point_sum += point
		contacts.append(
			{
				"contact_id": contact_id,
				"point_world_m": _vector_dict(point),
				"preferred_normal_force_n": 0.0,
			}
		)
	var support_centroid := point_sum / float(contacts.size())
	var center_of_mass := Vector3(
		support_centroid.x,
		0.4,
		support_centroid.z,
	)
	return {
		"schema_version": "sporespore_centroidal_support_request_v2",
		"semantic_step": semantic_step,
		"whole_system_mass_kg": 8.0,
		"gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
		"support_plane_forward_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
		"center_of_mass_world_m": _vector_dict(center_of_mass),
		"center_of_mass_velocity_world_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
		"target_center_of_mass_world_m": _vector_dict(center_of_mass),
		"torso_roll_rad": 0.0,
		"torso_pitch_rad": 0.0,
		"torso_roll_rate_rad_s": 0.0,
		"torso_pitch_rate_rad_s": 0.0,
		"horizontal_position_gain_n_per_m": 0.0,
		"horizontal_velocity_gain_ns_per_m": 0.0,
		"vertical_position_gain_n_per_m": 0.0,
		"vertical_velocity_gain_ns_per_m": 0.0,
		"roll_position_gain_nm_per_rad": 0.0,
		"roll_velocity_gain_nm_s_per_rad": 0.0,
		"pitch_position_gain_nm_per_rad": 0.0,
		"pitch_velocity_gain_nm_s_per_rad": 0.0,
		"maximum_horizontal_force_n": 0.0,
		"maximum_vertical_correction_n": 0.0,
		"maximum_roll_pitch_moment_nm": 0.0,
		"declared_supported_weight_fraction": 1.0,
		"characterized_friction_coefficient": 0.6,
		"minimum_normal_force_n": 0.0,
		"maximum_normal_force_n": 39.2,
		"nominal_support_count": 4,
		"feasibility_tolerance": 1.0e-5,
		"support_contacts": contacts,
	}


func _map_request_v2(
	descriptor: Dictionary,
	morphology: Dictionary,
	centroidal_command: Dictionary,
	semantic_step: int,
) -> Dictionary:
	var actuator_by_id: Dictionary = {}
	for actuator_value in (morphology["morphology_spec"] as Dictionary)["actuators"]:
		var actuator: Dictionary = actuator_value
		actuator_by_id[String(actuator["actuator_id"])] = actuator
	var kinematics: Array = []
	for actuator_id_value in morphology["ordered_actuator_ids"]:
		var actuator_id := String(actuator_id_value)
		var actuator: Dictionary = actuator_by_id[actuator_id]
		var mapped_limb: Dictionary = {}
		for limb_value in (morphology["morphology_spec"] as Dictionary)["limbs"]:
			var limb: Dictionary = limb_value
			if (limb["ordered_joint_ids"] as Array).has(String(actuator["joint_id"])):
				mapped_limb = limb
				break
		var joint_index := (mapped_limb["ordered_joint_ids"] as Array).find(
			String(actuator["joint_id"])
		)
		kinematics.append(
			{
				"actuator_id": actuator_id,
				"contact_site_id": String(
					(mapped_limb["ordered_contact_site_ids"] as Array)[0]
				),
				"joint_anchor_world_m":
				{"x": 0.0, "y": -0.25 * float(joint_index), "z": 0.0},
				"joint_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
				"endpoint_world_m": {"x": 0.0, "y": -0.5, "z": 0.0},
			}
		)
	return {
		"schema_version": "sporespore_map_endpoint_force_to_joint_request_v2",
		"descriptor": descriptor,
		"request":
		{
			"schema_version": "sporespore_endpoint_force_joint_map_request_v2",
			"semantic_step": semantic_step,
			"centroidal_command": centroidal_command,
			"ordered_actuator_kinematics": kinematics,
		},
	}


func _map_request_v3(
	descriptor: Dictionary,
	morphology: Dictionary,
	centroidal_command: Dictionary,
	semantic_step: int,
) -> Dictionary:
	var request := _map_request_v2(
		descriptor,
		morphology,
		centroidal_command,
		semantic_step,
	)
	request["schema_version"] = "sporespore_map_endpoint_force_to_joint_request_v3"
	var inner: Dictionary = request["request"]
	inner["schema_version"] = "sporespore_endpoint_force_joint_map_request_v3"
	return request


func _replace_task_forces(command: Dictionary, force: Vector3) -> void:
	for contact_value in command.get("ordered_support_contact_commands", []):
		var contact: Dictionary = contact_value
		contact["joint_task_force_delta_world_n"] = _vector_dict(force)


func _command_by_contact(command: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for contact_value in command["ordered_support_contact_commands"]:
		var contact: Dictionary = contact_value
		result[String(contact["contact_id"])] = contact
	return result


func _kinematics_by_actuator(request: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var inner: Dictionary = request["request"]
	for kinematics_value in inner["ordered_actuator_kinematics"]:
		var kinematics: Dictionary = kinematics_value
		result[String(kinematics["actuator_id"])] = kinematics
	return result


func _torques_match(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for index in first.size():
		var first_command: Dictionary = first[index]
		var second_command: Dictionary = second[index]
		if (
			String(first_command["actuator_id"]) != String(second_command["actuator_id"])
			or absf(
				float(first_command["generalized_torque_command_nm"])
				- float(second_command["generalized_torque_command_nm"])
			)
			> TORQUE_TOLERANCE_NM
		):
			return false
	return true


func _dict_vector(value: Dictionary) -> Vector3:
	return Vector3(
		float(value.get("x", NAN)),
		float(value.get("y", NAN)),
		float(value.get("z", NAN)),
	)


func _vector_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result


func _call_input(api: Object, method: StringName, value: Dictionary) -> Dictionary:
	var response := String(api.call(method, JSON.stringify(value)))
	var parsed: Variant = JSON.parse_string(response)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % label)


func _finish() -> void:
	print(
		"\nSDK stability v3 subset-map summary: %d passed, %d failed"
		% [_passed, _failed]
	)
	quit(0 if _failed == 0 else 1)
