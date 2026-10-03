extends SceneTree

## No-world C0/C1 conformance for the real Godot 4.7 GDExtension. Every call
## crosses GDScript -> godot-rust -> the checked-in C ABI -> portable core.

const EXTENSION_PATH := (
	"res://sdk/adapters/godot/sporespore_locomotion.gdextension"
)
const CLASS_NAME := "SporeLocomotionSdk"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SDK Godot 4.7 GDExtension C0/C1 conformance ===")
	var extension_resource := load(EXTENSION_PATH)
	_check(extension_resource != null, "the checked-in GDExtension resource loads")
	_check(ClassDB.class_exists(CLASS_NAME), "the native SDK class is registered")
	if not ClassDB.class_exists(CLASS_NAME):
		_finish()
		return
	var api: Object = ClassDB.instantiate(CLASS_NAME)
	_check(api != null, "the native SDK class instantiates")
	if api == null:
		_finish()
		return
	_check(String(api.call("version")) == "0.1.0", "native SDK version is exact")
	_check(
		String(api.call("candidate35_runtime_version"))
		== "sporespore_candidate35_runtime_v2",
		"Candidate 35 runtime identity remains exact",
	)
	_check(
		String(api.call("balanced_wave_runtime_version"))
		== "sporespore_balanced_wave_runtime_v1",
		"balanced-wave runtime identity crosses GDExtension",
	)

	var descriptor := _reference_descriptor("godot_adapter_reference")
	var compile_envelope := _call_input(api, "compile_bounded_quadruped_json", descriptor)
	_check(bool(compile_envelope.get("ok", false)), "descriptor compiles across GDExtension")
	if not bool(compile_envelope.get("ok", false)):
		_finish()
		return
	var compiled: Dictionary = compile_envelope["value"]
	var morphology: Dictionary = compiled["morphology"]
	_check(
		(morphology["ordered_body_ids"] as Array).size() == 9
		and (morphology["ordered_joint_ids"] as Array).size() == 8
		and (morphology["ordered_actuator_ids"] as Array).size() == 8,
		"native compile returns the exact GQ15 topology cardinalities",
	)
	_check(
		int(compiled.get("world_build_count", -1)) == 0
		and not bool(compiled.get("physical_acceptance_authority", true)),
		"native compile carries no world or physical authority",
	)
	var stability_envelope := _call_input(
		api,
		"observe_stability_v2_json",
		_stability_request(descriptor, morphology),
	)
	if not bool(stability_envelope.get("ok", false)):
		print("  stability envelope: ", JSON.stringify(stability_envelope))
	_check(
		bool(stability_envelope.get("ok", false)),
		"stability v2 observation crosses GDExtension",
	)
	if bool(stability_envelope.get("ok", false)):
		var stability_observation: Dictionary = stability_envelope["value"]
		_check(
			String(stability_observation.get("schema_version", ""))
			== "sporespore_support_observation_v2"
			and String(stability_observation.get("support_geometry_kind", "")) == "polygon"
			and int(stability_observation.get("support_geometry_dimension", -1)) == 2
			and float(stability_observation.get("center_of_mass_margin_m", -INF)) > 0.0,
			"native stability observation retains polygon and signed-margin semantics",
		)
		_check(
			not bool(stability_observation.get("physics_state_modified", true))
			and not bool(
				stability_observation.get("physical_acceptance_authority", true)
			)
			and not bool(
				stability_observation.get(
					"per_foot_measured_load_allocation_available",
					true,
				)
			),
			"native stability observation preserves no-world authority boundaries",
		)
	var scheduled_limb_gait_steps: Array = []
	for limb_id_value in morphology["ordered_limb_ids"]:
		scheduled_limb_gait_steps.append(
			{
				"limb_id": String(limb_id_value),
				"gait_step": 54,
			}
		)
	var scheduled_plan_envelope := _call_input(
		api,
		"plan_scheduled_load_transfer_v1_json",
		{
			"schema_version":
			"sporespore_plan_scheduled_load_transfer_request_v1",
			"descriptor": descriptor,
			"request":
			{
				"schema_version":
				"sporespore_scheduled_load_transfer_request_v1",
				"policy_id":
				"sporespore_scheduled_load_transfer_bw9l_d_v1",
				"gait_amplitude": 1.0,
				"cycle_steps": 360,
				"swing_steps": 72,
				"characterized_friction_coefficient": 1.0,
				"maximum_normal_force_n":
				float(morphology.get("total_mass_kg", 0.0)) * 9.8,
				"feasibility_tolerance": 1.0e-5,
				"ordered_limb_gait_steps": scheduled_limb_gait_steps,
				"stability_state":
				(_stability_request(descriptor, morphology)["state"] as Dictionary),
			},
		},
	)
	_check(
		bool(scheduled_plan_envelope.get("ok", false)),
		"scheduler-aware load-transfer plan crosses GDExtension",
	)
	if bool(scheduled_plan_envelope.get("ok", false)):
		var scheduled_plan: Dictionary = scheduled_plan_envelope["value"]
		_check(
			String(scheduled_plan.get("schema_version", ""))
			== "sporespore_scheduled_load_transfer_receipt_v1"
			and bool(scheduled_plan.get("active", false))
			and String(scheduled_plan.get("scheduled_limb_id", ""))
			== "rear_left"
			and int(scheduled_plan.get("morphology_branch_surface_count", -1))
			== 0
			and not bool(scheduled_plan.get("physics_state_modified", true))
			and not bool(
				scheduled_plan.get("physical_acceptance_authority", true)
			),
			"portable load-transfer receipt is active, branch-free, and non-authoritative",
		)
	var scheduled_plan_v2_request := {
		"schema_version":
		"sporespore_plan_scheduled_load_transfer_request_v2",
		"descriptor": descriptor,
		"request":
		{
			"schema_version":
			"sporespore_scheduled_load_transfer_request_v2",
			"policy_id":
			"sporespore_scheduled_load_transfer_bw10f_d_v2",
			"gait_amplitude": 1.0,
			"cycle_steps": 360,
			"swing_steps": 72,
			"characterized_friction_coefficient": 1.0,
			"maximum_normal_force_n":
			float(morphology.get("total_mass_kg", 0.0)) * 9.8,
			"feasibility_tolerance": 1.0e-5,
			"ordered_limb_gait_steps": scheduled_limb_gait_steps,
			"stability_state":
			(_stability_request(descriptor, morphology)["state"] as Dictionary),
		},
	}
	var scheduled_plan_v2_envelope := _call_input(
		api,
		"plan_scheduled_load_transfer_v2_json",
		scheduled_plan_v2_request,
	)
	_check(
		bool(scheduled_plan_v2_envelope.get("ok", false)),
		"typed fail-zero load-transfer plan crosses GDExtension",
	)
	if bool(scheduled_plan_v2_envelope.get("ok", false)):
		var scheduled_plan_v2: Dictionary = scheduled_plan_v2_envelope["value"]
		_check(
			String(scheduled_plan_v2.get("schema_version", ""))
			== "sporespore_scheduled_load_transfer_receipt_v2"
			and String(scheduled_plan_v2.get("planning_availability", ""))
			== "available"
			and not bool(scheduled_plan_v2.get("fail_zero_required", true))
			and bool(scheduled_plan_v2.get("active", false))
			and int(
				scheduled_plan_v2.get("morphology_branch_surface_count", -1)
			)
			== 0
			and not bool(
				scheduled_plan_v2.get("physical_acceptance_authority", true)
			),
			"v2 available receipt is branch-free and non-authoritative",
		)
	var unavailable_v2_request: Dictionary = scheduled_plan_v2_request.duplicate(true)
	var unavailable_state: Dictionary = unavailable_v2_request["request"][
		"stability_state"
	]
	var unavailable_contacts: Array = unavailable_state[
		"ordered_support_contacts"
	]
	(unavailable_contacts[0] as Dictionary)["bears_support"] = false
	(unavailable_contacts[1] as Dictionary)["bears_support"] = false
	var unavailable_v2_envelope := _call_input(
		api,
		"plan_scheduled_load_transfer_v2_json",
		unavailable_v2_request,
	)
	_check(
		bool(unavailable_v2_envelope.get("ok", false)),
		"v2 planner receipts two-contact unavailability instead of failing transport",
	)
	if bool(unavailable_v2_envelope.get("ok", false)):
		var unavailable_v2: Dictionary = unavailable_v2_envelope["value"]
		_check(
			String(unavailable_v2.get("planning_availability", ""))
			== "observation_unavailable"
			and bool(unavailable_v2.get("fail_zero_required", false))
			and unavailable_v2.get("centroidal_request") == null
			and unavailable_v2.get("centroidal_command") == null
			and (
				unavailable_v2.get("ordered_safe_zero_actuator_ids", []) as Array
			)
			== (morphology.get("ordered_actuator_ids", []) as Array),
			"v2 unavailable receipt names every ordered actuator safe-zero",
		)
	var centroidal_envelope := _call_input(
		api,
		"command_centroidal_support_v2_json",
		_centroidal_request(morphology),
	)
	_check(
		bool(centroidal_envelope.get("ok", false))
		and bool(
			(centroidal_envelope.get("value", {}) as Dictionary).get(
				"feasible",
				false,
			)
		),
		"centroidal support command crosses GDExtension",
	)
	if bool(centroidal_envelope.get("ok", false)):
		var centroidal_command: Dictionary = centroidal_envelope["value"]
		for contact_value in centroidal_command["ordered_support_contact_commands"]:
			var contact: Dictionary = contact_value
			contact["joint_task_force_delta_world_n"] = {
				"x": 2.0,
				"y": 0.0,
				"z": 0.0,
			}
		var joint_map_envelope := _call_input(
			api,
			"map_endpoint_force_to_joint_v2_json",
			_joint_map_request(descriptor, morphology, centroidal_command),
		)
		if not bool(joint_map_envelope.get("ok", false)):
			print("  joint-map envelope: ", JSON.stringify(joint_map_envelope))
		_check(
			bool(joint_map_envelope.get("ok", false)),
			"endpoint-force joint map crosses GDExtension",
		)
		if bool(joint_map_envelope.get("ok", false)):
			var joint_map: Dictionary = joint_map_envelope["value"]
			var mapped: Array = joint_map["ordered_generalized_joint_torque_commands"]
			_check(
				mapped.size() == 8
				and is_equal_approx(
					float((mapped[0] as Dictionary)["generalized_torque_command_nm"]),
					1.0,
				)
				and is_equal_approx(
					float((mapped[1] as Dictionary)["generalized_torque_command_nm"]),
					0.5,
				),
				"native J-transpose map preserves exact order and analytic torque",
			)
			_check(
				bool(joint_map.get("endpoint_force_map_available", false))
				and not bool(joint_map.get("measured_joint_torque_available", true))
				and not bool(joint_map.get("actuator_response_characterized", true))
				and not bool(joint_map.get("adapter_actuation_applied", true))
				and not bool(joint_map.get("physics_state_modified", true))
				and not bool(joint_map.get("physical_acceptance_authority", true)),
				"native J-transpose map preserves mapping and authority nonclaims",
			)

		var partial_centroidal_request := _centroidal_request(morphology)
		partial_centroidal_request["semantic_step"] = 12
		var partial_contacts: Array = []
		var partial_point_sum := Vector3.ZERO
		for contact_value in partial_centroidal_request["support_contacts"]:
			var contact: Dictionary = contact_value
			if String(contact["contact_id"]) != "front_right_foot":
				partial_contacts.append(contact)
				var point: Dictionary = contact["point_world_m"]
				partial_point_sum += Vector3(
					float(point["x"]),
					float(point["y"]),
					float(point["z"]),
				)
		partial_centroidal_request["support_contacts"] = partial_contacts
		var partial_support_centroid := partial_point_sum / float(
			partial_contacts.size()
		)
		partial_centroidal_request["center_of_mass_world_m"] = {
			"x": partial_support_centroid.x,
			"y": 0.4,
			"z": partial_support_centroid.z,
		}
		partial_centroidal_request["target_center_of_mass_world_m"] = {
			"x": partial_support_centroid.x,
			"y": 0.4,
			"z": partial_support_centroid.z,
		}
		var partial_centroidal_envelope := _call_input(
			api,
			"command_centroidal_support_v2_json",
			partial_centroidal_request,
		)
		_check(
			bool(partial_centroidal_envelope.get("ok", false))
			and bool(
				(
					partial_centroidal_envelope.get("value", {}) as Dictionary
				).get("feasible", false)
			),
			"three-contact centroidal fixture is feasible across GDExtension",
		)
		if bool(partial_centroidal_envelope.get("ok", false)):
			var partial_command: Dictionary = partial_centroidal_envelope["value"]
			for contact_value in partial_command["ordered_support_contact_commands"]:
				var contact: Dictionary = contact_value
				contact["joint_task_force_delta_world_n"] = {
					"x": 2.0,
					"y": 0.0,
					"z": 0.0,
				}
			var v3_envelope := _call_input(
				api,
				"map_endpoint_force_to_joint_v3_json",
				_joint_map_request_v3(
					descriptor,
					morphology,
					partial_command,
				),
			)
			if not bool(v3_envelope.get("ok", false)):
				print("  partial joint-map envelope: ", JSON.stringify(v3_envelope))
			_check(
				bool(v3_envelope.get("ok", false)),
				"partial-support joint map v3 crosses GDExtension",
			)
			if bool(v3_envelope.get("ok", false)):
				var v3_receipt: Dictionary = v3_envelope["value"]
				var inactive_exact := true
				for mapped_value in v3_receipt[
					"ordered_generalized_joint_torque_commands"
				]:
					var mapped_command: Dictionary = mapped_value
					if not bool(mapped_command["active_support_contact"]):
						var force: Dictionary = mapped_command[
							"endpoint_task_force_command_world_n"
						]
						inactive_exact = (
							inactive_exact
							and String(mapped_command["mapping_mode"])
							== "inactive_contact_zero"
							and float(mapped_command["generalized_torque_command_nm"]) == 0.0
							and float(force["x"]) == 0.0
							and float(force["y"]) == 0.0
							and float(force["z"]) == 0.0
							and bool(mapped_command["inactive_contact_forced_zero"])
						)
				_check(
					int(v3_receipt["active_actuator_count"]) == 6
					and int(v3_receipt["inactive_actuator_count"]) == 2
					and inactive_exact
					and not bool(v3_receipt["adapter_actuation_applied"])
					and not bool(v3_receipt["physics_state_modified"])
					and not bool(v3_receipt["physical_acceptance_authority"]),
					"partial-support v3 retains six active, two exact-zero, and no authority",
				)

	var profile_envelope := _call_input(api, "candidate35_profile_json", descriptor)
	_check(bool(profile_envelope.get("ok", false)), "Candidate 35 profile crosses GDExtension")
	if bool(profile_envelope.get("ok", false)):
		var profile: Dictionary = profile_envelope["value"]
		_check(
			float(profile.get("morphology_interaction_score", NAN)) == 0.0
			and (
				float(profile.get("cross_track_velocity_heading_gain_rad_per_m_s", NAN))
				== 0.275
			)
			and float(profile.get("anchor_error_guard_activation_fraction", NAN)) == 0.90
			and (
				float(profile.get("anchor_error_guard_maximum_motor_target_speed_rad_s", NAN))
				== 2.5
			)
			and (
				float(
					profile.get(
						"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s",
						NAN,
					)
				)
				== 3.5
			),
			"native profile distinguishes the anchor guard from contact-loaded speed",
		)

	var memory_envelope := _call_no_input(api, "candidate35_initial_memory_json")
	_check(bool(memory_envelope.get("ok", false)), "initial controller memory crosses GDExtension")
	var request := _step_request(
		descriptor,
		memory_envelope.get("value", {}),
		morphology,
	)
	var step_envelope := _call_input(api, "candidate35_step_json", request)
	if not bool(step_envelope.get("ok", false)):
		print("  dynamic-step envelope: ", JSON.stringify(step_envelope))
	_check(bool(step_envelope.get("ok", false)), "one pure controller step crosses GDExtension")
	if bool(step_envelope.get("ok", false)):
		var output: Dictionary = step_envelope["value"]
		var actuation: Dictionary = output["actuation"]
		_check(
			not bool(actuation.get("safe_no_actuation", true))
			and (actuation["ordered_commands"] as Array).size() == 8,
			"valid native step emits eight ordered actuator commands",
		)
		_check(
			int(actuation.get("world_build_count", -1)) == 0
			and not bool(actuation.get("physical_acceptance_authority", true)),
			"native controller step carries no physical acceptance authority",
		)

	var invalid_state: Dictionary = request["state"]
	var invalid_joints: Array = invalid_state["ordered_joint_observations"]
	var invalid_joint: Dictionary = invalid_joints[0]
	invalid_joint["velocity_rad_s"] = null
	var invalid_mask: Dictionary = invalid_joint["validity"]
	invalid_mask["velocity"] = false
	var safe_envelope := _call_input(api, "candidate35_step_json", request)
	if not bool(safe_envelope.get("ok", false)):
		print("  safe-step envelope: ", JSON.stringify(safe_envelope))
	_check(bool(safe_envelope.get("ok", false)), "invalid dynamic input returns a typed step envelope")
	if bool(safe_envelope.get("ok", false)):
		var safe_actuation: Dictionary = (safe_envelope["value"] as Dictionary)["actuation"]
		var all_zero := true
		for command_value in safe_actuation["ordered_commands"]:
			var command: Dictionary = command_value
			all_zero = all_zero and float(command["target_velocity_rad_s"]) == 0.0
		_check(
			bool(safe_actuation.get("safe_no_actuation", false))
			and all_zero,
			"missing joint velocity fails closed to eight zero-velocity commands",
		)

	var balanced_profile_envelope := _call_input(
		api,
		"balanced_wave_profile_json",
		descriptor,
	)
	_check(
		bool(balanced_profile_envelope.get("ok", false)),
		"balanced-wave profile crosses GDExtension",
	)
	if bool(balanced_profile_envelope.get("ok", false)):
		var balanced_profile: Dictionary = balanced_profile_envelope["value"]
		_check(
			String(balanced_profile.get("schema_version", ""))
			== "sporespore_balanced_wave_profile_v1"
			and String(balanced_profile.get("policy_id", ""))
			== "sporespore_balanced_wave_v1"
			and float(
				balanced_profile.get("cross_track_heading_gain_rad_per_m", NAN)
			)
			== 1.0
			and float(
				balanced_profile.get(
					"cross_track_velocity_heading_gain_rad_per_m_s",
					NAN,
				)
			)
			== 0.30
			and float(
				balanced_profile.get(
					"contact_loaded_swing_knee_maximum_motor_target_speed_rad_s",
					NAN,
				)
			)
			== 3.25
			and float(
				balanced_profile.get(
					"anchor_error_guard_activation_fraction",
					NAN,
				)
			)
			== 0.85
			and float(
				balanced_profile.get(
					"anchor_error_guard_maximum_motor_target_speed_rad_s",
					NAN,
				)
			)
			== 2.25
			and (balanced_profile.get("branch_surfaces", []) as Array).is_empty(),
			"balanced-wave reference profile is exact and branch-free",
		)
	var balanced_memory_envelope := _call_no_input(
		api,
		"balanced_wave_initial_memory_json",
	)
	_check(
		bool(balanced_memory_envelope.get("ok", false))
		and String(
			(
				balanced_memory_envelope.get("value", {}) as Dictionary
			).get("schema_version", "")
		)
		== "sporespore_balanced_wave_memory_v1",
		"balanced-wave memory identity crosses GDExtension",
	)
	var persistent_memory_envelope := _call_input(
		api,
		"balanced_wave_policy_initial_memory_json",
		{
			"schema_version":
			"sporespore_balanced_wave_policy_initial_memory_request_v1",
			"policy_id":
			"sporespore_balanced_wave_r23d29_two_swing_persistent_predictive_stability_guarded_steering_v1",
			"descriptor": descriptor,
		},
	)
	var persistent_memory: Dictionary = persistent_memory_envelope.get("value", {})
	_check(
		bool(persistent_memory_envelope.get("ok", false))
		and String(persistent_memory.get("schema_version", ""))
		== "sporespore_balanced_wave_persistent_predictive_guard_memory_v1"
		and int(persistent_memory.get("steering_guard_floor_hold_steps_remaining", -1)) == 0,
		"named stateful balanced-wave memory crosses GDExtension",
	)
	var balanced_request := _step_request(
		descriptor,
		balanced_memory_envelope.get("value", {}),
		morphology,
	)
	balanced_request["schema_version"] = "sporespore_balanced_wave_step_request_v1"
	var balanced_step_envelope := _call_input(
		api,
		"balanced_wave_step_json",
		balanced_request,
	)
	if not bool(balanced_step_envelope.get("ok", false)):
		print("  balanced step envelope: ", JSON.stringify(balanced_step_envelope))
	_check(
		bool(balanced_step_envelope.get("ok", false)),
		"one balanced-wave controller step crosses GDExtension",
	)
	if bool(balanced_step_envelope.get("ok", false)):
		var balanced_output: Dictionary = balanced_step_envelope["value"]
		var balanced_actuation: Dictionary = balanced_output["actuation"]
		var balanced_receipt: Dictionary = balanced_actuation["receipt"]
		_check(
			String(balanced_output.get("schema_version", ""))
			== "sporespore_balanced_wave_runtime_v1"
			and String(balanced_receipt.get("policy_id", ""))
			== "sporespore_balanced_wave_v1"
			and not bool(balanced_actuation.get("safe_no_actuation", true))
			and (balanced_actuation["ordered_commands"] as Array).size() == 8
			and String(
				(balanced_output["next_memory"] as Dictionary).get(
					"schema_version",
					"",
				)
			)
			== "sporespore_balanced_wave_memory_v1",
			"balanced-wave step preserves distinct policy, runtime, memory, and order",
		)
	var mixed_request := balanced_request.duplicate(true)
	mixed_request["memory"] = memory_envelope.get("value", {})
	var mixed_envelope := _call_input(api, "balanced_wave_step_json", mixed_request)
	_check(
		bool(mixed_envelope.get("ok", false))
		and bool(
			(
				(
					mixed_envelope.get("value", {}) as Dictionary
				).get("actuation", {}) as Dictionary
			).get("safe_no_actuation", false)
		),
		"balanced-wave runtime rejects Candidate 35 memory with typed zero authority",
	)

	var certificate_envelope := _call_no_input(api, "gq15_domain_certificate_json")
	_check(bool(certificate_envelope.get("ok", false)), "domain certificate crosses GDExtension")
	if bool(certificate_envelope.get("ok", false)):
		var certificate: Dictionary = certificate_envelope["value"]
		_check(
			bool(certificate.get("compiler_defined_at_every_domain_point", false))
			and not bool(certificate.get("controller_continuous_over_complete_domain", true))
			and not bool(
				certificate.get(
					"continuous_full_volume_physical_locomotion_validated",
					true,
				)
			),
			"native certificate preserves the negative universal-physics boundary",
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


func _step_request(
	descriptor: Dictionary,
	memory: Dictionary,
	morphology: Dictionary,
) -> Dictionary:
	var joints: Array = []
	for joint_id_value in morphology["ordered_joint_ids"]:
		joints.append(
			{
				"joint_id": String(joint_id_value),
				"position_rad": 0.0,
				"velocity_rad_s": 0.0,
				"anchor_error_m": 0.0,
				"validity":
				{
					"position": true,
					"velocity": true,
					"anchor_error": true,
				},
			}
		)
	var contacts: Array = []
	for contact_id_value in morphology["ordered_contact_site_ids"]:
		var contact_id := String(contact_id_value)
		contacts.append(
			{
				"contact_site_id": contact_id,
				"presence": true,
				"bears_support": true,
				"normal_load_n": null,
				"provenance":
				{
					"adapter_id": "godot_adapter_test",
					"engine_contact_ids": ["%s_engine" % contact_id],
					"aggregation_rule_id": "qualified_bearing_only",
					"quality": "qualified_bearing",
				},
			}
		)
	return {
		"schema_version": "sporespore_candidate35_step_request_v1",
		"descriptor": descriptor,
		"memory": memory,
		"state":
		{
			"schema_version": "sporespore_state_frame_v1",
			"semantic_step": 0,
			"sample_time_s": 0.0,
			"base_pose_world":
			{
				"position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
				"orientation_xyzw":
				{
					"x": 0.0,
					"y": 0.0,
					"z": 0.0,
					"w": 1.0,
				},
			},
			"base_twist_world":
			{
				"linear_velocity_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
				"angular_velocity_rad_s": {"x": 0.0, "y": 0.0, "z": 0.0},
			},
			"ordered_joint_observations": joints,
			"ordered_contact_observations": contacts,
			"previous_applied_actuation": null,
			"gravity_world_m_s2": {"x": 0.0, "y": -9.81, "z": 0.0},
			"task_frame":
			{
				"origin_world_m": {"x": 0.0, "y": 0.0, "z": 0.0},
				"forward_axis_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
				"lateral_axis_world_unit": {"x": 0.0, "y": 0.0, "z": 1.0},
				"up_axis_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
				"reference_yaw_rad": 0.0,
			},
			"adapter_capability_sha256":
			"sha256:3333333333333333333333333333333333333333333333333333333333333333",
		},
		"command":
		{
			"schema_version": "sporespore_motion_command_v2",
			"command_id": "godot_adapter_walk",
			"desired_planar_velocity_task_m_s": {"x": 0.2, "y": 0.0, "z": 0.0},
			"desired_heading_rad": 0.0,
			"desired_yaw_rate_rad_s": null,
			"gait_family_id": "lateral_wave",
			"speed_class": "walk",
			"gait_amplitude": 1.0,
			"phase_progression_mode": "contact_gated",
			"valid_from_step": 0,
			"valid_through_step": 0,
			"authority": "test_fixture",
		},
	}


func _stability_request(descriptor: Dictionary, morphology: Dictionary) -> Dictionary:
	var bodies: Array = []
	for body_id_value in morphology["ordered_body_ids"]:
		bodies.append(
			{
				"body_id": String(body_id_value),
				"pose_world":
				{
					"position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
					"orientation_xyzw":
					{
						"x": 0.0,
						"y": 0.0,
						"z": 0.0,
						"w": 1.0,
					},
				},
				"twist_world":
				{
					"linear_velocity_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
					"angular_velocity_rad_s": {"x": 0.0, "y": 0.0, "z": 0.0},
				},
			}
		)
	var contacts: Array = []
	for contact_id_value in morphology["ordered_contact_site_ids"]:
		var contact_id := String(contact_id_value)
		contacts.append(
			{
				"contact_site_id": contact_id,
				"presence": true,
				"bears_support": true,
				"point_world_m":
				{
					"x": 0.5 if contact_id.begins_with("front") else -0.5,
					"y": 0.0,
					"z": 0.5 if contact_id.contains("left") else -0.5,
				},
				"normal_world_unit": {"x": 0.0, "y": 1.0, "z": 0.0},
				"surface_relative_velocity_world_m_s":
				{"x": 0.0, "y": 0.0, "z": 0.0},
				"material_id": "fixture_material",
				"adapter_id": "godot_adapter_test",
				"engine_contact_ids": ["%s_engine" % contact_id],
			}
		)
	return {
		"schema_version": "sporespore_observe_stability_request_v2",
		"descriptor": descriptor,
		"state":
		{
			"schema_version": "sporespore_stability_state_v2",
			"semantic_step": 0,
			"ordered_body_states": bodies,
			"ordered_support_contacts": contacts,
			"gravity_world_m_s2": {"x": 0.0, "y": -9.81, "z": 0.0},
			"support_plane_forward_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
			"adapter_capability_sha256":
			"sha256:4444444444444444444444444444444444444444444444444444444444444444",
		},
	}


func _centroidal_request(morphology: Dictionary) -> Dictionary:
	var contacts: Array = []
	for contact_id_value in morphology["ordered_contact_site_ids"]:
		var contact_id := String(contact_id_value)
		contacts.append(
			{
				"contact_id": contact_id,
				"point_world_m":
				{
					"x": 0.22 if contact_id.begins_with("front") else -0.22,
					"y": 0.0,
					"z": -0.22 if contact_id.contains("left") else 0.22,
				},
				"preferred_normal_force_n": 0.0,
			}
		)
	return {
		"schema_version": "sporespore_centroidal_support_request_v2",
		"semantic_step": 11,
		"whole_system_mass_kg": 8.0,
		"gravity_world_m_s2": {"x": 0.0, "y": -9.8, "z": 0.0},
		"support_plane_forward_world_unit": {"x": 1.0, "y": 0.0, "z": 0.0},
		"center_of_mass_world_m": {"x": 0.0, "y": 0.4, "z": 0.0},
		"center_of_mass_velocity_world_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
		"target_center_of_mass_world_m": {"x": 0.0, "y": 0.4, "z": 0.0},
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


func _joint_map_request(
	descriptor: Dictionary,
	morphology: Dictionary,
	centroidal_command: Dictionary,
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
			"semantic_step": 11,
			"centroidal_command": centroidal_command,
			"ordered_actuator_kinematics": kinematics,
		},
	}


func _joint_map_request_v3(
	descriptor: Dictionary,
	morphology: Dictionary,
	centroidal_command: Dictionary,
) -> Dictionary:
	var request := _joint_map_request(descriptor, morphology, centroidal_command)
	request["schema_version"] = "sporespore_map_endpoint_force_to_joint_request_v3"
	var inner: Dictionary = request["request"]
	inner["schema_version"] = "sporespore_endpoint_force_joint_map_request_v3"
	inner["semantic_step"] = 12
	return request


func _call_input(api: Object, method: StringName, value: Dictionary) -> Dictionary:
	var response := String(api.call(method, JSON.stringify(value)))
	var parsed: Variant = JSON.parse_string(response)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _call_no_input(api: Object, method: StringName) -> Dictionary:
	var response := String(api.call(method))
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
	print("\nSDK Godot-adapter summary: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
