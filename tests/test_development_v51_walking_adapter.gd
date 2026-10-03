extends SceneTree
## Real adapter and native sessions on three exposed measurements, with no world.
const Shared := preload("res://tests/test_development_v32_walking_policy.gd")
const Facade := Shared.Facade
const Adapter := Facade.SdkAdapterScript
const Body := Adapter.DevelopmentMeasuredBody
const Transport := Shared.Transport
const PROFILE := "res://sdk/development/recovery_candidates/r10k-partial-fall-control-core-v1.json"
const POLICY := "sporespore_balanced_wave_recovery_joint_feasible_height_v1"
var checks: Dictionary = {}
var results: Dictionary = {}

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
		var fixtures: Array = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0])).fixtures
		for policy in [POLICY, Adapter.DEVELOPMENT_STARTUP_VELOCITY_POLICY_ID]:
			_check_policy(sdk, fixtures, policy)
		sdk = null
	probe.free()
	var ok := checks.values().all(func(v): return v == true)
	var out := FileAccess.open(args[1], FileAccess.WRITE)
	out.store_string(Transport.stringify({"ok": ok, "checks": checks, "results": results,
		"world_build_count": 0, "solver_step_count": 0, "full_route_registered": false,
		"input_scope": "Three exposed MuJoCo V50 measurements, applied to fresh Godot native sessions. No new trajectory or cross-engine behavioral equivalence is claimed.",
		"physical_acceptance_authority": false, "release_authority": false}))
	out.close()
	print("V51_WALKING_ADAPTER ", checks.size(), " checks; ok=", ok)
	quit(0 if ok else 1)

func _check_policy(sdk: Object, fixtures: Array, policy: String) -> void:
	var label := "v51" if policy == POLICY else "v50"
	var policy_binding := Shared.Policy.binding_v1(policy, "walking_resume")
	var policy_path: String = Shared.Policy.JOINT_HEIGHT_PATH if policy == POLICY else Shared.Policy.STARTUP_VELOCITY_PATH
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
	var model := "v51-zero-world-adapter-" + label
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
	var ledger := Shared.Prior._walking_ledger_production_fixture_v2(sdk, 900, "walking_resume", "walking_resume", "walking_resume", "v51-adapter-ledger-" + label, policy, true, ledger_source, fixtures[0])
	checks[label + "_production_motor_application_and_ledger"] = ledger.get("ok") == true
	results[label]["motor_ledger"] = ledger
	checks[label + "_prefix_selection_refuses"] = Shared.Policy.binding_v1(policy, "walking_prefix").is_empty()
	floor.free()
