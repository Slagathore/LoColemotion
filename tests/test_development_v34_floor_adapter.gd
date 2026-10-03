extends SceneTree
# gdlint: disable=max-line-length

const Shared := preload("res://tests/test_development_v32_walking_policy.gd")
const Facade := Shared.Facade
const Floor := Facade.SdkAdapterScript.DevelopmentFloor
const Entry := Shared.Entry
const Transport := Shared.Transport
const COMPONENT := "res://sdk/development/recovery_candidates/v34-floor-support-v1.json"
const MODEL := "r10f-l13-zero-world-walking_resume"

func _component_profile_path_v1() -> String:
	return COMPONENT

func _selected_policy_id_v1() -> String:
	return Floor.POLICY_ID

func _additional_ledger_checks_v1(_sdk: Object, _ledger: Dictionary, _legacy: Dictionary) -> Dictionary:
	return {}

func _synthetic_sequence_state_v1(adapter: RefCounted, step: int) -> Dictionary:
	return adapter._perfect_synthetic_controller_state_frame(step, adapter._compiled.morphology)

func _initialize() -> void:
	var component_path := _component_profile_path_v1()
	var selected_policy := _selected_policy_id_v1()
	var probe := Shared.RuntimeProbe.new()
	probe.profile_path = component_path
	var component: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(component_path))
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(component.runtime_binding))
	var checks := {"exact_runtime_preflight": probe._load_runtime_extension_v1()}
	if not checks.exact_runtime_preflight:
		_finish(checks, {})
		probe.free()
		return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var args := OS.get_cmdline_user_args()
	if args.size() == 1:
		var input: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
		var results := {}
		for name in input:
			results[name] = Entry.validate_report_v1(sdk, input[name].report, Entry._contract.profile_id, "", input[name].policy_id)
		print("V34_FLOOR_READER ", Transport.stringify(results))
		probe.free()
		quit(0)
		return
	var parent := Node3D.new()
	parent.name = "detached_floor_parent"
	var floor: StaticBody3D = Facade.RecoveryWorld.create_floor_v1()
	parent.add_child(floor)
	var shape: CollisionShape3D = floor.get_child(0)
	var source := Floor.capture_v1(sdk, floor, MODEL)
	checks.actual_floor_factory_and_reader = source.get("ok") == true and Floor.verify_v1(sdk, source, MODEL)
	var variants := {"authored": source.duplicate(true)}
	parent.position = Vector3(2.0, 1.0, -3.0)
	shape.position = Vector3(0.25, 0.125, -0.5)
	variants.translated = Floor.capture_v1(sdk, floor, MODEL)
	checks.parent_and_shape_translation = Floor.verify_v1(sdk, variants.translated, MODEL) and variants.translated.floor_reference.height_world_m != source.floor_reference.height_world_m
	parent.rotation.x = 0.1
	checks.tilt_refuses = Floor.capture_v1(sdk, floor, MODEL).get("ok") == false
	parent.rotation = Vector3.ZERO
	parent.scale = Vector3(2, 1, 1)
	checks.scale_refuses = Floor.capture_v1(sdk, floor, MODEL).get("ok") == false
	parent.scale = Vector3.ONE
	floor.top_level = true
	variants.top_level = Floor.capture_v1(sdk, floor, MODEL)
	checks.top_level_ignores_parent = Floor.verify_v1(sdk, variants.top_level, MODEL) and variants.top_level.geometry.transform_chain_shape_to_root.size() == 2
	floor.top_level = false
	parent.position = Vector3.ZERO
	shape.position = Vector3.ZERO
	shape.disabled = true
	checks.disabled_shape_refuses = Floor.capture_v1(sdk, floor, MODEL).get("ok") == false
	shape.disabled = false
	floor.constant_linear_velocity = Vector3.RIGHT
	checks.moving_surface_refuses = Floor.capture_v1(sdk, floor, MODEL).get("ok") == false
	floor.constant_linear_velocity = Vector3.ZERO
	checks.missing_source_refuses = Floor.capture_v1(sdk, null, MODEL).get("ok") == false
	checks.crossed_model_refuses = not Floor.verify_v1(sdk, source, "different-model")
	var rehashed := source.duplicate(true)
	rehashed.geometry.top_world_y_m += 0.125
	rehashed.floor_reference = Floor.reference_v1(sdk, rehashed.geometry)
	checks.consistently_rehashed_wrong_plane_refuses = not Floor.verify_v1(sdk, rehashed, MODEL)
	var legacy := Shared.Prior._walking_ledger_production_fixture_v2(sdk, 900, "walking_resume", "walking_resume", "walking_resume", "v34-floor-legacy", "", true)
	var ledger := Shared.Prior._walking_ledger_production_fixture_v2(sdk, 900, "walking_resume", "walking_resume", "walking_resume", "v34-floor-new", selected_policy, true, source)
	checks.legacy_real_motor_ledger = legacy.get("ok") == true
	checks.new_real_motor_ledger = ledger.get("ok") == true
	checks.merge(_additional_ledger_checks_v1(sdk, ledger, legacy))
	var facade := Facade.new()
	facade._binding = {"floor": floor, "model_instance_id": MODEL}
	var frame := Facade.DevelopmentWalkingFrame.frame_v1(Basis.IDENTITY, "walking_resume", "anatomical_plus_x_horizontal_resume_v1")
	var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID).profile
	var phases := {"front_left": 90, "front_right": 90, "rear_left": 90, "rear_right": 90}
	var started := facade._start_adapter_from_frame_v1(frame, Vector3.ZERO, phases, material, true, selected_policy)
	checks.actual_facade_source_binding = started.get("ok") == true
	var report := {}
	if started.get("ok") == true:
		var adapter: RefCounted = facade._adapter
		checks.unchanged_source_rebind = facade._bind_current_floor_v1().get("ok") == true
		floor.position.y += 0.125
		checks.live_source_change_refuses = facade._bind_current_floor_v1().get("ok") == false
		floor.position.y -= 0.125
		# Restore exact stored binary32 transform, not accumulated arithmetic.
		floor.position = Vector3(0, -0.05, 0)
		var selected := Shared.Policy.binding_v1(selected_policy, "walking_resume")
		var session := {"session_id": "v34-floor-sequence", "evaluation_segment_id": "walking_resume", "step_receipt_sha256s": [],
			"start_receipt": {"model_instance_id": MODEL, "development_walking_policy_id": selected_policy, "selected_policy_id": selected_policy,
				"selected_policy_digest": selected.policy_digest, "development_floor_source": source.duplicate(true)}}
		var rows := []
		var trace := []
		for step in range(1, 201):
			var state: Dictionary = _synthetic_sequence_state_v1(adapter, step)
			var command: Dictionary = adapter._perfect_synthetic_motion_command(step, "contact_gated")
			command.gait_amplitude = Entry.amplitude_v1(step, Entry._contract.profile_id)
			var request: Dictionary = adapter._controller_step_request(adapter._memory.duplicate(true), state, command)
			var response: Dictionary = adapter._call_balanced_wave_session_step_with_transport_verification(request, step)
			if response.get("ok") != true:
				checks.native_sequence = false
				break
			var output: Dictionary = response.value
			adapter._memory = output.next_memory.duplicate(true)
			var applications := []
			for motor in output.actuation.ordered_commands:
				applications.append({"actuator_id": motor.actuator_id, "host_applied_target_velocity_rad_s": motor.target_velocity_rad_s})
			var full_sha := "sha256:" + Transport.stringify({"request": request, "output": output}).sha256_text()
			var retained := Entry.retain_step_v1({"ok": true, "session_id": session.session_id, "global_semantic_step": 900 + step, "session_local_step": step,
				"sample_receipt": {"request": request, "development_floor_source": source, "stability_shadow": {"stability_state": {"ordered_body_states": [{}, {}, {}, {}, {}, {}, {}, {}, {}]}}},
				"portable_step_receipt": {"native_output": output, "native_step_transport_verification": response.native_step_transport_verification},
				"authority_application_receipt": {"ordered_applications": applications}}, Entry._contract.profile_id, full_sha)
			if retained.get("ok") != true:
				checks.actual_retention = false
				break
			rows.append(retained.row)
			session.step_receipt_sha256s.append(full_sha)
			trace.append({"walking_segment_id": "walking_resume", "walking_session_id": session.session_id, "walking_session_local_step": step, "global_semantic_step": 900 + step})
		checks.complete_200_command_population = rows.size() == 200
		var edge_state: Dictionary = adapter._perfect_synthetic_controller_state_frame(201, adapter._compiled.morphology)
		edge_state.base_pose_world.position_m.x = 10.0
		checks.finite_floor_edge_refuses_before_native = adapter._controller_step_request(adapter._memory, edge_state, {}).is_empty()
		report = {"configuration": {"base_descriptor": Facade.RecoveryRoute.exact_base_descriptor_v1()},
			"retained_arm": {"model_instance_id": MODEL, "walking_sessions": [session], "trace_rows": trace},
			"development_walking_entry": Entry.retention_v1(rows, Entry._contract.profile_id)}
		checks.same_process_reader = Entry.validate_report_v1(sdk, report, Entry._contract.profile_id, "", selected_policy).get("ok") == true
		checks.adapter_shutdown = adapter.shutdown().get("ok") == true
		facade._adapter = null
	parent.free()
	probe.free()
	_finish(checks, {"report": report, "sources": variants, "legacy_fixture": legacy, "floor_fixture": ledger, "adapter_start": started})

func _finish(checks: Dictionary, result: Dictionary) -> void:
	print("V34_FLOOR_PRODUCER ", Transport.stringify({"ok": not checks.values().has(false), "checks": checks, "result": result,
		"detached_floor_body_count": 1, "detached_floor_collision_shape_count": 1, "scene_tree_insertion_count": 0,
		"world_build_count": 0, "solver_step_count": 0, "synthetic_controller_states": true, "physical_acceptance_authority": false, "release_authority": false}))
	quit(0 if not checks.values().has(false) else 1)
