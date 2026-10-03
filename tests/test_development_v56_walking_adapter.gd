extends SceneTree
## Real adapter and native sessions on three exposed measurements, with no world.
const Shared := preload("res://tests/test_development_v32_walking_policy.gd")
const Facade := Shared.Facade
const Adapter := Facade.SdkAdapterScript
const Body := Adapter.DevelopmentMeasuredBody
const Transport := Shared.Transport
const PROFILE := "res://sdk/development/recovery_candidates/r10s-extended-preparation-core-v1.json"
const POLICY := "sporespore_balanced_wave_recovery_extended_preparation_v1"
var checks: Dictionary = {}
var results: Dictionary = {}
var braking_results: Array = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var component: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
	var probe := Shared.RuntimeProbe.new()
	probe.profile_path = PROFILE
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(component.runtime_binding))
	checks["bound_runtime"] = probe._load_runtime_extension_v1()
	if checks.bound_runtime:
		var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
		var inputs: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
		var fixtures: Array = inputs.fixtures
		for policy in [POLICY, Adapter.DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID, Adapter.DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID, Adapter.DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID, Adapter.DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID, Adapter.DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID, Adapter.DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID]:
			_check_policy(sdk, fixtures, policy)
		for fixture in inputs.braking_fixtures:
			_check_braking_input(sdk, fixture)
		sdk = null
	probe.free()
	var ok := checks.values().all(func(v): return v == true)
	var out := FileAccess.open(args[1], FileAccess.WRITE)
	out.store_string(Transport.stringify({"ok": ok, "checks": checks, "results": results, "braking_results": braking_results,
		"world_build_count": 0, "solver_step_count": 0, "full_route_registered": false,
		"input_scope": "Three exposed V50 measurements across seven policies and eight R10M startup/stopping inputs through V56. No new physical trajectory or cross-engine behavioral equivalence is claimed.",
		"physical_acceptance_authority": false, "release_authority": false}))
	out.close()
	print("V56_WALKING_ADAPTER ", checks.size(), " checks; ok=", ok)
	quit(0 if ok else 1)

func _check_policy(sdk: Object, fixtures: Array, policy: String) -> void:
	var label := "v56" if policy == POLICY else "v55" if policy == Adapter.DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID else "v54" if policy == Adapter.DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID else "v53" if policy == Adapter.DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID else "v52" if policy == Adapter.DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID else "v51" if policy == Adapter.DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID else "v50"
	var policy_binding := Shared.Policy.binding_v1(policy, "walking_resume")
	var policy_path: String = Shared.Policy.EXTENDED_PREPARATION_PATH if policy == POLICY else Shared.Policy.INITIALIZED_BRAKE_PATH if policy == Adapter.DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID else Shared.Policy.ZERO_BRAKE_PATH if policy == Adapter.DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID else Shared.Policy.BOUNDED_STOP_PATH if policy == Adapter.DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID else Shared.Policy.EXTENDED_TRANSFER_PATH if policy == Adapter.DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID else Shared.Policy.JOINT_HEIGHT_PATH if policy == Adapter.DEVELOPMENT_JOINT_FEASIBLE_HEIGHT_POLICY_ID else Shared.Policy.STARTUP_VELOCITY_PATH
	checks[label + "_exact_selected_contract_digest"] = policy_binding.get("policy_id") == policy and policy_binding.get("policy_digest") == "sha256:" + FileAccess.get_sha256(policy_path)
	var adapter := Adapter.new()
	var steps := {"front_left": 90, "front_right": 90, "rear_left": 90, "rear_right": 90}
	var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID).profile
	var frame: Dictionary = fixtures[0].state.task_frame
	var lateral := Vector3(frame.lateral_axis_world_unit.x, frame.lateral_axis_world_unit.y, frame.lateral_axis_world_unit.z)
	var started := adapter.start(Facade.RecoveryRoute.exact_base_descriptor_v1(), steps, 0.0,
		Vector3.ZERO, lateral, frame.reference_yaw_rad, Facade.PHYSICS_HZ, Facade.SOLVER_POLICY.duplicate(true),
		Adapter.DEFAULT_TOLERANCE, "contact_gated", true, 0, -1, "post_settle_full",
		Adapter.P5I3B_WEIGHT_SUPPORT_POLICY_ID, material, policy, -1.0, false,
		Adapter.FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID, true)
	checks[label + "_actual_start"] = started.get("ok") == true
	results[label] = {"descriptor": adapter._descriptor.duplicate(true), "native_profile": adapter._controller_profile.duplicate(true), "start": started, "steps": [], "refusals": []}
	if not checks[label + "_actual_start"]:
		return
	checks[label + "_initial_policy_and_clocks"] = adapter._memory.schema_version == adapter._expected_balanced_wave_memory_version(policy) and adapter._memory.ordered_limb_memory.all(func(v): return v.gait_step == 90)
	checks[label + "_missing_floor_refuses"] = adapter._controller_step_request(adapter._memory, fixtures[0].state, fixtures[0].command).is_empty()
	var floor := Facade.RecoveryWorld.create_floor_v1()
	var model := "v56-zero-world-adapter-" + label
	var source := Adapter.DevelopmentFloor.capture_v1(sdk, floor, model)
	checks[label + "_actual_floor_binding"] = adapter.bind_development_floor_source_v1(source, model).get("ok") == true
	checks[label + "_crossed_model_refuses"] = adapter.bind_development_floor_source_v1(source, "crossed").get("ok") == false
	checks[label + "_v3_request_selection"] = adapter._controller_step_request_schema_version() == "sporespore_balanced_wave_policy_session_step_request_v3"
	var memory: Dictionary = adapter._memory.duplicate(true)
	for index in range(fixtures.size()):
		var fixture: Dictionary = fixtures[index]
		var state: Dictionary = fixture.state.duplicate(true)
		state.adapter_capability_sha256 = adapter._adapter_capability_sha256
		var stability := {"semantic_step": state.semantic_step, "adapter_capability_sha256": state.adapter_capability_sha256, "ordered_body_states": fixture.measured_body_frame.ordered_body_states.duplicate(true)}
		var request := adapter._controller_step_request(memory.duplicate(true), state, fixture.command)
		request.measured_body_frame = Body.project_v1(state, stability)
		if index == 0:
			for corruption in ["missing_bodies", "body_clock", "memory_schema"]:
				var changed := request.duplicate(true)
				match corruption:
					"missing_bodies": changed.erase("measured_body_frame")
					"body_clock": changed.measured_body_frame.semantic_step += 1
					"memory_schema": changed.memory.schema_version = "unknown"
				var refused := adapter._call_balanced_wave_session_step_with_transport_verification(changed, index + 1)
				results[label].refusals.append({"mutation": corruption, "response": refused})
				checks[label + "_refuses_" + corruption] = refused.get("ok") == false
		var response := adapter._call_balanced_wave_session_step_with_transport_verification(request, index + 1)
		results[label].steps.append({"request": request, "request_raw": JSON.stringify(request, "", true, true), "response": response})
		checks[label + "_native_step_" + str(index + 1)] = response.get("ok") == true
		if response.get("ok") != true:
			break
		var value: Dictionary = response.value
		checks[label + "_transport_and_memory_" + str(index + 1)] = value.next_memory.schema_version == adapter._expected_balanced_wave_memory_version(policy) and response.native_step_transport_verification.controller_receipt_schema_version == adapter._balanced_wave_expected_controller_receipt_schema() and value.actuation.ordered_commands.size() == 8 and value.actuation.safe_no_actuation == false
		var transfer: Dictionary = value.actuation.receipt.recovery_support_plane.measured_support_transfer
		checks[label + "_reference_range_receipt_" + str(index + 1)] = transfer.get("maximum_absolute_reference_bias_rad") == 0.30 if policy in [POLICY, Adapter.DEVELOPMENT_INITIALIZED_ZERO_BRAKE_POLICY_ID, Adapter.DEVELOPMENT_ZERO_VELOCITY_BRAKE_POLICY_ID, Adapter.DEVELOPMENT_BOUNDED_STOP_VELOCITY_POLICY_ID, Adapter.DEVELOPMENT_EXTENDED_SUPPORT_TRANSFER_POLICY_ID] else not transfer.has("maximum_absolute_reference_bias_rad")
		checks[label + "_preparation_limit_receipt_" + str(index + 1)] = transfer.get("maximum_preparation_commands") == 360 if policy == POLICY else not transfer.has("maximum_preparation_commands")
		memory = value.next_memory.duplicate(true)
	checks[label + "_shutdown"] = adapter.shutdown().get("ok") == true
	checks[label + "_post_shutdown_binding_refuses"] = adapter.bind_development_floor_source_v1(source, model).get("ok") == false
	# Exercise shared production selection and motor-ledger validation as well as the adapter.
	var facade := Facade.new()
	facade._binding = {"floor": floor, "model_instance_id": model}
	var forward := Vector3(frame.forward_axis_world_unit.x, frame.forward_axis_world_unit.y, frame.forward_axis_world_unit.z)
	var facade_start := facade._start_adapter_from_frame_v1({"lateral": lateral, "forward": forward, "legacy_yaw_rad": frame.reference_yaw_rad}, Vector3.ZERO, steps, material, true, policy, "walking_resume")
	checks[label + "_production_facade_start"] = facade_start.get("ok") == true
	results[label]["facade_start"] = facade_start
	if facade_start.get("ok") == true:
		checks[label + "_production_facade_shutdown"] = facade._adapter.shutdown().get("ok") == true
	facade._adapter = null
	var ledger_source := Adapter.DevelopmentFloor.capture_v1(sdk, floor, "r10f-l13-zero-world-walking_resume")
	var ledger := Shared.Prior._walking_ledger_production_fixture_v2(sdk, 900, "walking_resume", "walking_resume", "walking_resume", "v56-adapter-ledger-" + label, policy, true, ledger_source, fixtures[0])
	checks[label + "_production_motor_application_and_ledger"] = ledger.get("ok") == true
	results[label]["motor_ledger"] = ledger
	checks[label + "_prefix_selection_refuses"] = Shared.Policy.binding_v1(policy, "walking_prefix").is_empty()
	floor.free()

func _check_braking_input(sdk: Object, fixture: Dictionary) -> void:
	var label: String = fixture.label
	var original: Dictionary = fixture.request
	var frame: Dictionary = original.state.task_frame
	var adapter := Adapter.new()
	var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID).profile
	var lateral := Vector3(frame.lateral_axis_world_unit.x, frame.lateral_axis_world_unit.y, frame.lateral_axis_world_unit.z)
	var started := adapter.start(Facade.RecoveryRoute.exact_base_descriptor_v1(),
		{"front_left": 90, "front_right": 90, "rear_left": 90, "rear_right": 90}, 0.0,
		Vector3.ZERO, lateral, frame.reference_yaw_rad, Facade.PHYSICS_HZ, Facade.SOLVER_POLICY.duplicate(true),
		Adapter.DEFAULT_TOLERANCE, "contact_gated", true, 0, -1, "post_settle_full",
		Adapter.P5I3B_WEIGHT_SUPPORT_POLICY_ID, material, POLICY, -1.0, false,
		Adapter.FIXED_INITIAL_TASK_FRAME_ORIGIN_POLICY_ID, true)
	checks[label + "_start"] = started.get("ok") == true
	if started.get("ok") != true:
		return
	var floor := Facade.RecoveryWorld.create_floor_v1()
	var model := "v56-braking-input-" + label
	var source := Adapter.DevelopmentFloor.capture_v1(sdk, floor, model)
	checks[label + "_floor"] = adapter.bind_development_floor_source_v1(source, model).get("ok") == true
	var state: Dictionary = original.state.duplicate(true)
	state.adapter_capability_sha256 = adapter._adapter_capability_sha256
	var stability := {"semantic_step": state.semantic_step, "adapter_capability_sha256": state.adapter_capability_sha256,
		"ordered_body_states": original.measured_body_frame.ordered_body_states.duplicate(true)}
	var request := adapter._controller_step_request(original.memory.duplicate(true), state, original.command)
	request.measured_body_frame = Body.project_v1(state, stability)
	# This is a copied-input computation against a fresh, detached floor. Its
	# provenance must match the copied memory; no historical record is changed.
	if request.memory.get("floor_reference_sha256") != null:
		var digest: Dictionary = sdk.decode_exact_json_v1(sdk.canonicalize_json(Transport.stringify({"schema_version": "sporespore_canonical_json_request_v1", "value": request.floor_reference})))
		request.memory.floor_reference_sha256 = digest.value.sha256
	var response := adapter._call_balanced_wave_session_step_with_transport_verification(request, int(state.semantic_step))
	braking_results.append({"label": label, "descriptor": adapter._descriptor.duplicate(true),
		"request_raw": JSON.stringify(request, "", true, true), "response": response,
		"expected_response_sha256": fixture.expected_response_sha256})
	checks[label + "_response"] = response.get("ok") == true
	if response.get("ok") == true:
		checks[label + "_exact_component_commands"] = response.value.actuation.ordered_commands == fixture.expected_commands
		var pose: Dictionary = response.value.actuation.receipt.recovery_support_plane.anchored_body_pose
		if original.memory.last_semantic_step == null:
			checks[label + "_exact_native_initialization"] = pose.has("zero_amplitude_velocity_guard") and not pose.has("zero_amplitude_motor_brake") and response.value.actuation.ordered_commands.all(func(c): return abs(c.target_velocity_rad_s) <= 0.25)
		else:
			var guard: Dictionary = pose.zero_amplitude_motor_brake
			checks[label + "_exact_native_braking"] = not pose.has("zero_amplitude_velocity_guard") and guard.ordered_commands.size() == 8 and guard.ordered_commands.all(func(c): return c.held_target_velocity_rad_s == 0.0) and guard.zero_applied_impulse_claim == false
		braking_results[-1]["motor_braking"] = _check_motor_braking(sdk, adapter, response, int(state.semantic_step), label)
	checks[label + "_shutdown"] = adapter.shutdown().get("ok") == true
	floor.free()

func _check_motor_braking(sdk: Object, adapter: RefCounted, response: Dictionary, step: int, label: String) -> Dictionary:
	# These detached joints are parameter containers. No bodies or physics world
	# are constructed, and nothing is added to the SceneTree.
	var cap_binding := Facade.walking_host_cap_projection_binding_v1(sdk)
	var caps: Dictionary = cap_binding.selected_host_cap_by_actuator_id
	var morphology: Dictionary = adapter.compiled_morphology_for_conformance().morphology
	var joints: Array[HingeJoint3D] = []
	var legacy: Dictionary = {}
	var recovery: Dictionary = {}
	for index in range(morphology.ordered_actuator_ids.size()):
		var actuator: String = morphology.ordered_actuator_ids[index]
		var joint := HingeJoint3D.new()
		joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, float(caps[actuator]))
		legacy[adapter._legacy_joint_id_for_actuator(actuator)] = {"joint": joint}
		recovery[Facade.JOINT_IDS[index]] = joint
		joints.append(joint)
	var facade := Facade.new()
	facade._binding = {"joint_nodes": recovery}
	var configuration := facade.configure_all_motors_v1(true, step, "v56_detached_brake_application")
	var before := facade.motor_population_readback_v1(step, true, "v56_before_application")
	# Sentinels prove the production writer updates the joint parameters.
	# Readbacks use Godot's binary32 motor storage for nonrepresentable targets.
	for index in range(joints.size()):
		joints[index].set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, 0.125 if index % 2 == 0 else -0.125)
	var sentinels := facade.motor_population_readback_v1(step, true, "v56_nonzero_sentinels")
	var applied: Dictionary = adapter.apply_authority({"ok": true, "semantic_step": step, "native_output": response.value}, legacy, true, caps)
	var after := facade.motor_population_readback_v1(step, true, "v56_after_application")
	checks[label + "_production_motor_application"] = configuration.get("ok") == true and before.get("ok") == true and applied.get("ok") == true and applied.get("applied_command_count") == 8 and after.get("ok") == true and sentinels.get("ok") == true and sentinels.ordered_joint_readbacks.all(func(c): return abs(c.motor_target_velocity_rad_s) == 0.125)
	var exact: bool = after.get("motor_enabled_count") == 8
	if before.get("ok") == true and after.get("ok") == true:
		for index in range(joints.size()):
			var old: Dictionary = before.ordered_joint_readbacks[index]
			var current: Dictionary = after.ordered_joint_readbacks[index]
			exact = exact and current.actuator_id == old.actuator_id and current.motor_enabled == true and current.motor_target_velocity_rad_s == float(PackedFloat32Array([response.value.actuation.ordered_commands[index].target_velocity_rad_s])[0]) and current.motor_target_velocity_rad_s != sentinels.ordered_joint_readbacks[index].motor_target_velocity_rad_s and current.motor_maximum_impulse_nms == old.motor_maximum_impulse_nms and current.motor_maximum_impulse_nms == float(caps[current.actuator_id])
	checks[label + "_enabled_expected_targets_and_original_caps"] = exact
	joints[0].set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, false)
	var disabled := facade.motor_population_readback_v1(step, true, "v56_disabled_motor_control")
	checks[label + "_disabled_motor_readback_refuses"] = disabled.get("ok") == false
	joints[0].set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)
	joints[0].set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 0.0)
	var invalid_cap := facade.motor_population_readback_v1(step, true, "v56_invalid_cap_control")
	checks[label + "_invalid_cap_readback_refuses"] = invalid_cap.get("ok") == false
	for joint in joints:
		joint.free()
	return {"cap_binding": cap_binding, "configuration": configuration, "before": before, "sentinels": sentinels, "application": applied, "after": after,
		"negative_controls": {"disabled_motor": disabled, "zero_impulse_cap": invalid_cap},
		"detached_hinge_parameter_container_count": joints.size(), "scene_tree_insertion_count": 0,
		"world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}
