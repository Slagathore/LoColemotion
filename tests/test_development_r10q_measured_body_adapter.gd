extends SceneTree
const Shared := preload("res://tests/test_development_v32_walking_policy.gd")
const Facade := Shared.Facade
const Body := preload("res://sdk/adapters/godot/gdscript/development_recovery_measured_body_source_v1.gd")
const Cycle := preload("res://sdk/adapters/godot/gdscript/development_recovery_cycle_stop_v1.gd")
const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Transport := Shared.Transport
const EntryFixture := preload("res://tests/test_development_recovery_walking_entry.gd")

var policy_id: String = Cycle.STARTUP_POLICY
var entry_id: String = Cycle.STARTUP_ENTRY
var evaluation_segment := "walking_resume"
var selected_candidate_profile: Dictionary = {}

func _initialize() -> void:
	var profile_path := "res://sdk/development/recovery_candidates/v50-startup-reference-velocity-integrated-v1.json"
	var explicit_profile_path := ""
	var args: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--candidate-profile="):
			if not explicit_profile_path.is_empty():
				push_error("MEASURED_BODY_DUPLICATE_CANDIDATE")
				quit(1)
				return
			explicit_profile_path = argument.trim_prefix("--candidate-profile=")
		elif argument.begins_with("--r10q-segment="):
			policy_id = Profile.WalkingPolicy.R10Q.ID
			entry_id = Profile.WalkingPolicy.R10Q.ENTRY
			evaluation_segment = argument.trim_prefix("--r10q-segment=")
		elif argument.begins_with("--r10n-segment="):
			policy_id = Profile.WalkingPolicy.R10N.ID
			entry_id = Profile.WalkingPolicy.R10N.ENTRY
			evaluation_segment = argument.trim_prefix("--r10n-segment=")
		elif argument.begins_with("--r10m-segment="):
			policy_id = Profile.WalkingPolicy.R10M.ID
			entry_id = Profile.WalkingPolicy.R10M.ENTRY
			evaluation_segment = argument.trim_prefix("--r10m-segment=")
		elif argument.begins_with("--r10l-segment="):
			policy_id = Profile.WalkingPolicy.R10L.ID
			entry_id = Profile.WalkingPolicy.R10L.ENTRY
			evaluation_segment = argument.trim_prefix("--r10l-segment=")
		elif argument.begins_with("--r10k-segment="):
			policy_id = Profile.WalkingPolicy.R10K.ID
			entry_id = Profile.WalkingPolicy.R10K.ENTRY
			evaluation_segment = argument.trim_prefix("--r10k-segment=")
		elif argument.begins_with("--r10j-segment="):
			policy_id = Profile.WalkingPolicy.FiniteRoute.StanceEntry.HOLD_ID
			entry_id = Profile.WalkingPolicy.FiniteRoute.StanceEntry.HOLD_ENTRY
			evaluation_segment = argument.trim_prefix("--r10j-segment=")
			profile_path = "res://sdk/development/recovery_candidates/r10j-v50-settled-hold-integrated-v2.json"
		elif argument.begins_with("--r10i-segment="):
			policy_id = Profile.WalkingPolicy.FiniteRoute.StanceEntry.FLEXED_ID
			entry_id = Profile.WalkingPolicy.FiniteRoute.StanceEntry.FLEXED_ENTRY
			evaluation_segment = argument.trim_prefix("--r10i-segment=")
			profile_path = "res://sdk/development/recovery_candidates/r10i-v50-flexed-entry-integrated-v4.json"
		elif argument.begins_with("--r10h-segment="):
			policy_id = Profile.WalkingPolicy.FiniteRoute.StanceEntry.ID
			entry_id = Profile.WalkingPolicy.FiniteRoute.StanceEntry.ENTRY
			evaluation_segment = argument.trim_prefix("--r10h-segment=")
			profile_path = "res://sdk/development/recovery_candidates/r10h-v50-stance-entry-integrated-v3.json"
		elif argument.begins_with("--r10g-segment="):
			policy_id = Profile.WalkingPolicy.FiniteRoute.ID
			entry_id = Profile.WalkingPolicy.FiniteRoute.ENTRY
			evaluation_segment = argument.trim_prefix("--r10g-segment=")
			profile_path = "res://sdk/development/recovery_candidates/r10g-v50-finite-cycle-integrated-v3.json"
		else:
			args.append(argument)
	if policy_id in [Profile.WalkingPolicy.R10K.ID, Profile.WalkingPolicy.R10L.ID, Profile.WalkingPolicy.R10M.ID, Profile.WalkingPolicy.R10N.ID, Profile.WalkingPolicy.R10Q.ID] and explicit_profile_path.is_empty():
		push_error("R10K_MEASURED_BODY_EXPLICIT_CANDIDATE_REQUIRED")
		quit(1)
		return
	if not explicit_profile_path.is_empty():
		profile_path = explicit_profile_path
	var selection := Profile.load_v1({"resource": profile_path, "raw_sha256": "sha256:" + FileAccess.get_sha256(profile_path)})
	selected_candidate_profile = selection.get("candidate_profile", {})
	var checks := {"profile": not selection.is_empty()}
	var component: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	var probe := Shared.RuntimeProbe.new()
	probe.profile_path = profile_path
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(component.runtime_binding))
	checks["runtime"] = probe._load_runtime_extension_v1()
	if not checks["runtime"]:
		probe.free()
		_finish(checks, {})
		return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	if args.size() != 1:
		checks["arguments"] = false
		probe.free()
		_finish(checks, {})
		return
	var fixture: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0]))
	if fixture.has("reader_cases"):
		var results := {}
		for name in fixture["reader_cases"]:
			results[name] = Shared.Entry.validate_report_v1(sdk, fixture["reader_cases"][name], entry_id, "", policy_id)
		print("V50_BODY_COLD_READER ", Transport.stringify(results))
		probe.free()
		quit(0)
		return
	var floor: StaticBody3D = Facade.RecoveryWorld.create_floor_v1()
	var ledger_source := Facade.SdkAdapterScript.DevelopmentFloor.capture_v1(sdk, floor, "r10f-l13-zero-world-" + evaluation_segment)
	var ledger := Shared.Prior._walking_ledger_production_fixture_v2(sdk, 900, "walking_resume", evaluation_segment, evaluation_segment, "v50-measured-body-ledger", policy_id, true, ledger_source, fixture)
	checks["real_step_motor_application_and_ledger"] = ledger.get("ok") == true
	var facade := Facade.new()
	facade._binding = {"floor": floor, "model_instance_id": "v50-zero-world-body"}
	var frame: Dictionary = fixture["state"]["task_frame"]
	var lateral := Vector3(frame.lateral_axis_world_unit.x, frame.lateral_axis_world_unit.y, frame.lateral_axis_world_unit.z)
	var forward := Vector3(frame.forward_axis_world_unit.x, frame.forward_axis_world_unit.y, frame.forward_axis_world_unit.z)
	var start_id := Profile.walking_start_id_v1(selection, "walking_resume")
	var phases := Facade.initial_gait_steps_v1(40200, "walking_resume", start_id)
	var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID).profile
	var started := facade._start_adapter_from_frame_v1({"lateral": lateral, "forward": forward, "legacy_yaw_rad": frame.reference_yaw_rad}, Vector3.ZERO, phases, material, true, policy_id, evaluation_segment)
	checks["actual_adapter_start"] = started.get("ok") == true
	var result := {"start": started, "ledger": ledger}
	if checks["actual_adapter_start"]:
		var adapter: RefCounted = facade._adapter
		var state: Dictionary = fixture["state"].duplicate(true)
		state["adapter_capability_sha256"] = adapter._adapter_capability_sha256
		var bodies: Array = fixture["measured_body_frame"]["ordered_body_states"].duplicate(true)
		var stability := {"semantic_step": state.semantic_step, "adapter_capability_sha256": state.adapter_capability_sha256, "ordered_body_states": bodies}
		var measured := Body.project_v1(state, stability)
		checks["project_exact_body_population"] = measured.get("ordered_body_states") == bodies
		var crossed := stability.duplicate(true)
		crossed["semantic_step"] += 1
		checks["crossed_clock_refuses"] = Body.project_v1(state, crossed).is_empty()
		crossed = stability.duplicate(true)
		crossed["ordered_body_states"][0]["twist_world"]["linear_velocity_m_s"]["x"] += 0.1
		checks["crossed_torso_refuses"] = Body.project_v1(state, crossed).is_empty()
		checks["actual_initial_memory_clocks"] = adapter._memory["ordered_limb_memory"].all(func(limb): return limb["gait_step"] == 90)
		var request: Dictionary = adapter._controller_step_request(adapter._memory.duplicate(true), state, fixture["command"])
		request["measured_body_frame"] = measured
		checks["v3_request"] = request.get("schema_version") == "sporespore_balanced_wave_policy_session_step_request_v3"
		var response: Dictionary = adapter._call_balanced_wave_session_step_with_transport_verification(request, 1)
		checks["actual_native_v3_transport"] = response.get("ok") == true
		result["response"] = response
		result["request"] = request
		_start_and_entry_checks(selection, phases, request, checks, sdk, adapter)
		if response.get("ok") == true and fixture.has("post_native_source"):
			var source: Dictionary = fixture["post_native_source"].duplicate(true)
			source["model_instance_id"] = "v50-zero-world-body"
			var trace: Dictionary = source["precommand_trace"]
			trace["walking_session_id"] = "v50-synthetic-reader-session"
			trace["walking_segment_id"] = evaluation_segment
			var global_step: int = int(trace["global_semantic_step"])
			var full_sha := "sha256:" + Transport.stringify({"request": request, "output": response["value"]}).sha256_text()
			var applications := []
			for motor in response["value"]["actuation"]["ordered_commands"]:
				applications.append({"actuator_id": motor["actuator_id"], "host_applied_target_velocity_rad_s": motor["target_velocity_rad_s"]})
			var retained := Shared.Entry.retain_step_v1({"ok": true, "session_id": trace["walking_session_id"], "global_semantic_step": global_step, "session_local_step": 1,
				"sample_receipt": {"request": request, "development_floor_source": adapter._development_floor_source, "stability_shadow": {"stability_state": stability}},
				"portable_step_receipt": {"native_output": response["value"], "native_step_transport_verification": response["native_step_transport_verification"]},
				"authority_application_receipt": {"ordered_applications": applications}}, entry_id, full_sha, false)
			checks["actual_entry_retention"] = retained.get("ok") == true
			if retained.get("ok") == true:
				var advanced := Cycle.advance_v1(Cycle.initial_v1(), retained["row"], source)
				checks["first_cycle_observation"] = advanced.get("ok") == true
				if advanced.get("ok") == true:
					var policy := Shared.Policy.binding_v1(policy_id, "walking_resume")
					var session := {"session_id": trace["walking_session_id"], "evaluation_segment_id": evaluation_segment, "step_receipt_sha256s": [full_sha],
						"start_receipt": {"model_instance_id": source["model_instance_id"], "development_walking_policy_id": policy_id, "selected_policy_id": policy["policy_id"],
						"selected_policy_digest": policy["policy_digest"], "development_floor_source": adapter._development_floor_source.duplicate(true)}}
					var report := {"configuration": {"base_descriptor": adapter._descriptor.duplicate(true)},
						"retained_arm": {"model_instance_id": source["model_instance_id"], "body_population_instance_sha256": source["body_population_instance_sha256"], "walking_sessions": [session], "trace_rows": [trace]},
						"development_walking_entry": Shared.Entry.retention_v1([retained["row"]], entry_id),
						"development_cycle_stop": {"schema_version": Cycle.retention_schema_v1(policy_id), "rows": [{"session_local_step": 1, "full_step_receipt_sha256": full_sha, "post_native_source": source, "advance_receipt": advanced}], "final_memory": advanced["next_memory"], "physical_acceptance_authority": false, "release_authority": false},
						"fixture_scope": "Synthetic combination of the explicitly selected native walking interface call and an unchanged V44 post-step native observation. No physical or causal trajectory is claimed."}
					result["report"] = report
					result["reader"] = Shared.Entry.validate_report_v1(sdk, report, entry_id, "", policy_id)
					checks["same_process_complete_reader"] = result["reader"].get("ok") == true

		checks["shutdown"] = adapter.shutdown().get("ok") == true
		facade._adapter = null
	floor.free()
	probe.free()
	_finish(checks, result)

func _start_and_entry_checks(selection: Dictionary, phases: Dictionary, request: Dictionary, checks: Dictionary, sdk: Object, adapter: RefCounted) -> void:
	var id := Profile.walking_start_id_v1(selection, "walking_resume")
	var worker := EntryFixture.Probe.new()
	if Profile.WalkingPolicy.FiniteRoute.selected_v1(policy_id):
		checks["route_native_identity_unchanged"] = Profile.WalkingPolicy.binding_v1(policy_id, evaluation_segment).get("policy_id") == (Profile.WalkingPolicy.R10Q.POLICY if policy_id == Profile.WalkingPolicy.R10Q.ID else Profile.WalkingPolicy.R10N.POLICY if policy_id == Profile.WalkingPolicy.R10N.ID else Profile.WalkingPolicy.R10M.POLICY if policy_id == Profile.WalkingPolicy.R10M.ID else Profile.WalkingPolicy.R10L.POLICY if policy_id == Profile.WalkingPolicy.R10L.ID else Profile.WalkingPolicy.R10K.POLICY if policy_id == Profile.WalkingPolicy.R10K.ID else Cycle.STARTUP_POLICY)
		checks["route_prefix_and_old_baseline_unchanged"] = Profile.WalkingPolicy.binding_v1(policy_id, "walking_prefix").is_empty() and Profile.WalkingPolicy.binding_v1(Cycle.STARTUP_POLICY, "matched_continuation").is_empty()
		checks["route_both_post_interaction_owners"] = Profile.WalkingPolicy.owner_for_phase_v1("matched_no_kick_continuation", policy_id) == "stance" and Profile.WalkingPolicy.owner_for_phase_v1("fresh_selected_policy_walking_resume", policy_id) == "stance"
		checks["route_both_post_interaction_selection"] = Profile.walking_start_id_v1(selection, "matched_continuation") == id and Profile.WalkingPolicy.selected_id_v1(selection, "matched_continuation") == policy_id
	worker._candidate_selection = selection
	checks["start_normal_plan"] = phases == Profile.WalkingStart.normal_initial_gait_steps_v1(id) and phases.values().all(func(v): return v == 90)
	checks["worker_resume_only"] = worker._walking_start_profile_id_v1("walking_resume") == id and worker._walking_start_profile_id_v1("walking_prefix").is_empty()
	checks["seeded_legacy_start"] = Facade.initial_gait_steps_v1(40200, "walking_prefix").values().all(func(v): return v == 240) and Facade.initial_gait_steps_v1(40200, "walking_resume").values().all(func(v): return v == 240)
	checks["start_selection_refusals"] = Facade.initial_gait_steps_v1(40200, "walking_prefix", id).is_empty() and Facade.initial_gait_steps_v1(-1, "walking_resume", id).is_empty() and Facade.initial_gait_steps_v1(40200, "walking_resume", "unknown").is_empty()
	var startup := {"seed": 40200, "retained_arm": {"walking_sessions": [{"evaluation_segment_id": evaluation_segment, "session_id": "synthetic-start", "start_receipt": {"session_id": "synthetic-start", "initial_gait_steps": phases, "gait_phase_seed": 40200, "development_walking_start_profile_id": id}}]}, "development_walking_entry": {"rows": [{"session_id": "synthetic-start", "session_local_step": 1, "request": request.duplicate(true)}]}}
	checks["start_reader_actual_request"] = Profile.WalkingStart.validate_report_v1(startup, id).get("ok") == true
	checks["start_reader_legacy_refusal"] = Profile.WalkingStart.validate_report_v1(startup, "").get("ok") == false
	for corruption in ["phase", "seed", "missing_first", "memory_phase", "duplicate_limb", "selector"]:
		var changed := startup.duplicate(true)
		var start: Dictionary = changed["retained_arm"]["walking_sessions"][0]["start_receipt"]
		var rows: Array = changed["development_walking_entry"]["rows"]
		match corruption:
			"phase": start["initial_gait_steps"]["front_left"] = 240
			"seed": start["gait_phase_seed"] = 0
			"missing_first": rows.clear()
			"memory_phase": rows[0]["request"]["memory"]["ordered_limb_memory"][0]["gait_step"] = 240
			"duplicate_limb": rows[0]["request"]["memory"]["ordered_limb_memory"][1]["limb_id"] = rows[0]["request"]["memory"]["ordered_limb_memory"][0]["limb_id"]
			"selector": start["development_walking_start_profile_id"] = ""
		checks["start_reader_refuses_" + corruption] = Profile.WalkingStart.validate_report_v1(changed, id).get("ok") == false
	checks["start_zero_resume_valid_negative"] = Profile.WalkingStart.validate_report_v1({"seed": 40200, "retained_arm": {"walking_sessions": []}}, id).get("validated_resume_sessions") == 0
	checks["complete_72_command_ramp"] = true
	for n in range(1, 74):
		var u := minf(float(n - 1) / 72.0, 1.0)
		var expected := 0.5994550408719347 * (u * u * (3.0 - 2.0 * u))
		checks["complete_72_command_ramp"] = checks["complete_72_command_ramp"] and absf(worker._walking_gait_amplitude_v1("walking_resume", n) - expected) < 1e-15
	var entry_fixture := EntryFixture.new()
	entry_fixture._clocked_boundary_probe(worker, sdk, adapter, checks)
	entry_fixture.free()
	worker._cycle_stop_memory["cycle_end_command"] = 1011 # Explicit synthetic schedule boundary; never evidence.
	checks["stop_changes_resume_command_only"] = worker._walking_gait_amplitude_v1("walking_resume", 1012) == 0.0 and worker._walking_gait_amplitude_v1("walking_prefix", 12) == 1.0
	checks["stop_keeps_contact_gated_mode"] = worker._walking_phase_progression_mode_v1("walking_resume", 1012) == "contact_gated"
	worker.free()

func _finish(checks: Dictionary, result: Dictionary) -> void:
	print("V50_MEASURED_BODY_ADAPTER ", Transport.stringify({"ok": not checks.values().has(false), "checks": checks, "result": result, "candidate_profile": selected_candidate_profile,
		"synthetic_inputs_only": true, "world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	quit(0 if not checks.values().has(false) else 1)
