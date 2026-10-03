extends SceneTree
# gdlint: disable=max-line-length

const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Facade := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd")
const Launcher := preload("res://scripts/lab/gait/physical_wave_gait_quadruped.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

class Probe:
	extends "res://sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd"
	func _initialize() -> void:
		pass

class SamplerCapture:
	extends "res://scripts/lab/gait/sdk_godot_jolt_adapter.gd"
	func sample(local_step: int, amplitude: float, phase_mode: String, _torso: RigidBody3D, _limbs: Array, _floor: StaticBody3D, _faults: Dictionary = {}, _heading: Dictionary = {}) -> Dictionary:
		return {"local_step": local_step, "amplitude": amplitude, "phase_mode": phase_mode}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var selection := Profile.load_v1({"resource": args[0], "raw_sha256": args[1]})
	var checks := {"profile_loaded": not selection.is_empty()}
	if selection.is_empty():
		_finish(checks, [])
		return
	var probe := Probe.new()
	probe._candidate_selection = selection
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(selection["worker_selection"]["binding"]))
	checks["runtime_loaded"] = probe._load_runtime_extension_v1()
	if not checks["runtime_loaded"]:
		probe.free()
		_finish(checks, [])
		return
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var fixture: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[2]))
	if args.size() > 3 and args[3] == "independent-reader":
		var results := {}
		for key in fixture:
			results[key] = Profile.WalkingEntry.validate_report_v1(sdk, fixture[key], Profile.walking_entry_id_v1(selection, "walking_resume"), "", Profile.WalkingPolicy.selected_id_v1(selection, "walking_resume"))
		print("DEVELOPMENT_WALKING_ENTRY_REPLAY ", Transport.stringify(results))
		sdk = null
		probe.free()
		quit(0)
		return
	var native: Dictionary = fixture["native_state"]
	var q: Dictionary = native["base_pose_world"]["orientation_xyzw"]
	var basis := Basis(Quaternion(q["x"], q["y"], q["z"], q["w"]))
	var frame := Facade.DevelopmentWalkingFrame.frame_v1(basis, "walking_resume", "anatomical_plus_x_horizontal_resume_v1")
	var p: Dictionary = native["base_pose_world"]["position_m"]
	var ramp_open := Launcher._gait_amplitude(Launcher.SETTLE_TICKS, 10000, 11000)
	checks["normal_launcher_ramp_opens_zero"] = ramp_open == 0.0
	checks["normal_launcher_ramp_one_cycle"] = Launcher.WARMUP_CYCLES == 1 and Launcher.CYCLE_TICKS == 360
	checks["normal_launcher_ramp_reaches_one"] = Launcher._gait_amplitude(Launcher.SETTLE_TICKS + Launcher.CYCLE_TICKS, 10000, 11000) == 1.0
	var results := []
	for amplitude in [1.0, ramp_open]:
		var facade := Facade.new()
		var detached_floor: StaticBody3D = null
		if Profile.WalkingPolicy.floor_selected_v1(probe._walking_policy_id_v1("walking_resume")):
			detached_floor = Facade.RecoveryWorld.create_floor_v1()
			facade._binding = {"floor": detached_floor, "model_instance_id": "synthetic-entry-floor"}
		var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID)["profile"]
		var started := facade._start_adapter_from_frame_v1(frame, Vector3(p["x"], p["y"], p["z"]),
			Facade.initial_gait_steps_v1(40200, "walking_resume"), material, true, probe._walking_policy_id_v1("walking_resume"))
		checks["native_session_" + str(amplitude)] = started.get("ok") == true
		if started.get("ok") == true:
			var adapter: RefCounted = facade._adapter
			# This is explicitly a reconstructed command-level input. We have the
			# native standing measurements, but not the original walking sampler's
			# complete per-step request. Synthetic contact provenance stays labeled.
			var state: Dictionary = adapter._perfect_synthetic_controller_state_frame(1, adapter._compiled["morphology"])
			state["ordered_joint_observations"] = native["ordered_joint_observations"].duplicate(true)
			state["base_pose_world"]["position_m"] = p.duplicate(true)
			state["base_pose_world"]["orientation_xyzw"] = adapter._canonical_orientation_xyzw(basis)["orientation_xyzw"]
			state["base_twist_world"] = native["base_twist_world"].duplicate(true)
			var command: Dictionary = adapter._perfect_synthetic_motion_command(1, "contact_gated")
			command["gait_amplitude"] = amplitude
			var request: Dictionary = adapter._controller_step_request(adapter._memory.duplicate(true), state, command)
			var response: Dictionary = adapter._call_input(adapter._controller_step_method(), request)
			checks["native_step_" + str(amplitude)] = response.get("ok") == true and response.get("value", {}).get("actuation", {}).get("safe_no_actuation") == false
			results.append({"gait_amplitude": amplitude, "input": request, "output": response})
			if amplitude == 0.0 and not Profile.walking_entry_id_v1(selection, "walking_resume").is_empty():
				results[-1]["retention_probe"] = _retention_probe(probe, sdk, adapter, checks)
			checks["shutdown_" + str(amplitude)] = adapter.shutdown().get("ok") == true
		facade._adapter = null
		if detached_floor != null:
			detached_floor.free()
	sdk = null
	probe.free()
	_finish(checks, results)

func _retention_probe(probe: Probe, sdk: Object, adapter: RefCounted, checks: Dictionary) -> Dictionary:
	# This tier tests the selected ramp using synthetic contact provenance.
	# The separately selected contact tier exercises its actual worker hook,
	# live shape binding and callback-to-request/stability integration.
	probe._candidate_selection = probe._candidate_selection.duplicate(true)
	probe._candidate_selection.get("diagnostic_schedule", {}).erase("walking_contact_profile_id")
	var id := Profile.walking_entry_id_v1(probe._candidate_selection, "walking_resume")
	checks["ramp_matches_established_function_all_warmup_steps"] = true
	var ramp_steps := 72 if Profile.WalkingEntry.Startup.selected_v1(id) else 360
	var maximum := Profile.WalkingEntry.Startup.maximum_amplitude_v1(id)
	checks["selected_ramp_duration_uses_existing_swing_or_cycle"] = Launcher.SWING_TICKS == 72 and Launcher.CYCLE_TICKS == 360
	checks["historical_amplitude_profiles_unchanged"] = true
	for local_step in range(1, 362):
		var expected := maximum * Launcher._gait_amplitude(Launcher.SETTLE_TICKS + local_step - 1, 10000, 11000,
			Launcher.SETTLE_TICKS, 1, Launcher.COOLDOWN_CYCLES, ramp_steps)
		if probe._walking_gait_amplitude_v1("walking_resume", local_step) != expected:
			checks["ramp_matches_established_function_all_warmup_steps"] = false
		for old_id in [Profile.WalkingEntry._contract["profile_id"], Profile.WalkingEntry._clocked_contract["profile_id"]]:
			checks["historical_amplitude_profiles_unchanged"] = checks["historical_amplitude_profiles_unchanged"] and Profile.WalkingEntry.amplitude_v1(local_step, old_id) == Launcher._gait_amplitude(Launcher.SETTLE_TICKS + local_step - 1, 10000, 11000)
	checks["selected_first_and_full_amplitude_boundaries"] = probe._walking_gait_amplitude_v1("walking_resume", 1) == 0.0 and probe._walking_gait_amplitude_v1("walking_resume", ramp_steps) < maximum and probe._walking_gait_amplitude_v1("walking_resume", ramp_steps + 1) == maximum
	checks["historical_first_swing_unit_amplitude_unchanged"] = Profile.WalkingEntry.amplitude_v1(73, Profile.WalkingEntry.Startup.contract["profile_id"]) == 1.0
	checks["prefix_and_old_profiles_unchanged"] = probe._walking_gait_amplitude_v1("walking_prefix", 1) == 1.0 and Profile.WalkingEntry.amplitude_v1(1) == 1.0
	var report := {"configuration": {"base_descriptor": adapter._descriptor.duplicate(true)},
		"retained_arm": {"trace_rows": [], "walking_sessions": [{"session_id": "synthetic-entry", "step_receipt_sha256s": []}]}}
	var policy_id := probe._walking_policy_id_v1("walking_resume")
	if not policy_id.is_empty():
		var session: Dictionary = report["retained_arm"]["walking_sessions"][0]
		session["evaluation_segment_id"] = "walking_resume"
		session["start_receipt"] = {"development_walking_policy_id": policy_id, "selected_policy_id": policy_id,
			"selected_policy_digest": Profile.WalkingPolicy.binding_v1(policy_id, "walking_resume")["policy_digest"]}
		if Profile.WalkingPolicy.floor_selected_v1(policy_id):
			report["retained_arm"]["model_instance_id"] = "synthetic-entry-floor"
			session["start_receipt"]["model_instance_id"] = "synthetic-entry-floor"
			session["start_receipt"]["development_floor_source"] = adapter._development_floor_source.duplicate(true)
	var memory: Dictionary = adapter._memory.duplicate(true)
	probe._sdk = sdk
	var contact_start := Profile.WalkingEntry.Startup.contact_gated_selected_v1(id)
	# The longer synthetic retention probe crosses the seeded clock's first
	# blocked release gate; the separate startup test verifies real zero startup.
	var sample_count := 100 if contact_start else 2
	checks["retained_contact_gate_exercised"] = not contact_start
	checks["retained_commands_respect_selected_joint_bound"] = true
	checks["actual_adapter_preserves_strict_memory_chain"] = true
	for local_step in range(1, sample_count + 1):
		if contact_start:
			adapter._memory = memory.duplicate(true)
			var before := Transport.stringify(adapter._memory)
			checks["actual_adapter_preserves_strict_memory_chain"] = checks["actual_adapter_preserves_strict_memory_chain"] and adapter._configure_phase_progression_mode("contact_gated").get("ok") == true and Transport.stringify(adapter._memory) == before
		var state: Dictionary = adapter._perfect_synthetic_controller_state_frame(local_step, adapter._compiled["morphology"])
		var command: Dictionary = adapter._perfect_synthetic_motion_command(local_step, probe._walking_phase_progression_mode_v1("walking_resume", local_step))
		command["gait_amplitude"] = probe._walking_gait_amplitude_v1("walking_resume", local_step)
		var request: Dictionary = adapter._controller_step_request(memory.duplicate(true), state, command)
		var response: Dictionary = adapter._call_balanced_wave_session_step_with_transport_verification(request, local_step)
		checks["retention_native_step_" + str(local_step)] = response.get("ok") == true
		if response.get("ok") != true:
			break
		if contact_start:
			for limb in response["value"]["next_memory"]["ordered_limb_memory"]:
				if limb["release_hold_step_count"] > 0:
					checks["retained_contact_gate_exercised"] = true
			for motor in response["value"]["actuation"]["ordered_commands"]:
				if String(motor["actuator_id"]).ends_with("_knee_motor"):
					checks["retained_commands_respect_selected_joint_bound"] = checks["retained_commands_respect_selected_joint_bound"] and motor["position_saturated"] == false and motor["requested_target_position_rad"] <= 1.1
		var applications := []
		# Synthetic motor applications and bodies are explicitly not observations.
		# The command request/output and retention/reader calls are real interfaces.
		for output_command in response["value"]["actuation"]["ordered_commands"]:
			applications.append({"actuator_id": output_command["actuator_id"],
				"host_applied_target_velocity_rad_s": output_command["target_velocity_rad_s"]})
		var step := {"ok": true, "session_id": "synthetic-entry", "global_semantic_step": 805 + local_step,
			"session_local_step": local_step, "sample_receipt": {"request": request,
				"stability_shadow": {"stability_state": adapter._perfect_synthetic_stability_state(local_step, adapter._compiled["morphology"])}},
			"portable_step_receipt": {"native_output": response["value"], "native_step_transport_verification": response["native_step_transport_verification"]},
			"authority_application_receipt": {"ordered_applications": applications}}
		if Profile.WalkingPolicy.floor_selected_v1(policy_id):
			step["sample_receipt"]["development_floor_source"] = adapter._development_floor_source.duplicate(true)
		var digest: String = probe._canonical_sha256_v1(step)
		var retained := probe._retain_development_walking_source_v1("walking_resume", step, digest)
		checks["actual_worker_retains_" + str(local_step)] = retained.get("ok") == true
		report["retained_arm"]["trace_rows"].append({"walking_segment_id": "walking_resume", "walking_session_id": "synthetic-entry",
			"walking_session_local_step": local_step, "global_semantic_step": 805 + local_step})
		report["retained_arm"]["walking_sessions"][0]["step_receipt_sha256s"].append(digest)
		memory = response["value"]["next_memory"].duplicate(true)
	probe._attach_entry_retention_v1(report)
	probe._sdk = null
	checks["actual_worker_publishes_retention"] = report.get("development_walking_entry", {}).get("sample_count") == sample_count
	var replay := Profile.WalkingEntry.validate_report_v1(sdk, report, id, "", policy_id)
	checks["same_process_pure_replay"] = replay.get("ok") == true
	report["zero_world_replay_diagnostic"] = replay
	checks["old_reader_refuses_transplant"] = Profile.WalkingEntry.validate_report_v1(sdk, report, "").get("ok") == false
	_clocked_boundary_probe(probe, sdk, adapter, checks)
	return report

func _clocked_boundary_probe(probe: Probe, sdk: Object, adapter: RefCounted, checks: Dictionary) -> void:
	var id := Profile.WalkingEntry._clocked_contract["profile_id"] as String
	var selected: bool = Profile.WalkingEntry.Startup.phase_family_id_v1(Profile.walking_entry_id_v1(probe._candidate_selection, "walking_resume")) == id
	checks["historical_and_prefix_phase_modes_unchanged"] = true
	checks["selected_phase_mode_boundary"] = true
	checks["actual_facade_sampler_receives_selected_mode"] = true
	var capture := Facade.new()
	capture._adapter = SamplerCapture.new()
	capture._binding = {"torso": null, "limbs": [], "floor": null}
	for local_step in [1, 359, 360, 361, 362, 450]:
		var expected := "clocked" if selected and local_step <= 360 else "contact_gated"
		var mode := probe._walking_phase_progression_mode_v1("walking_resume", local_step)
		checks["selected_phase_mode_boundary"] = checks["selected_phase_mode_boundary"] and mode == expected
		checks["historical_and_prefix_phase_modes_unchanged"] = checks["historical_and_prefix_phase_modes_unchanged"] and probe._walking_phase_progression_mode_v1("walking_prefix", local_step) == "contact_gated" and Profile.WalkingEntry.phase_mode_v1(local_step) == "contact_gated" and Profile.WalkingEntry.phase_mode_v1(local_step, Profile.WalkingEntry._contract["profile_id"]) == "contact_gated"
		var amplitude := probe._walking_gait_amplitude_v1("walking_resume", local_step)
		checks["actual_facade_sampler_receives_selected_mode"] = checks["actual_facade_sampler_receives_selected_mode"] and capture._sample_walking_input_v1(local_step, amplitude, mode) == {"local_step": local_step, "amplitude": amplitude, "phase_mode": expected}
	capture._adapter = null
	if not selected:
		return
	# All-support synthetic inputs deliberately obstruct release gates. These
	# 450 pure native commands prove schedule/memory behavior, not physical gait.
	var memory: Dictionary = adapter._memory.duplicate(true)
	checks["native_warmup_and_mode_switch_without_memory_reset"] = true
	checks["native_contact_gate_active_after_warmup"] = false
	checks["selected_joint_bound_in_actual_native_commands"] = true
	for local_step in range(1, 451):
		var state: Dictionary = adapter._perfect_synthetic_controller_state_frame(local_step, adapter._compiled["morphology"])
		var mode := probe._walking_phase_progression_mode_v1("walking_resume", local_step)
		var command: Dictionary = adapter._perfect_synthetic_motion_command(local_step, mode)
		command["gait_amplitude"] = probe._walking_gait_amplitude_v1("walking_resume", local_step)
		var request := {"schema_version": "sporespore_balanced_wave_policy_step_request_v1", "descriptor": adapter._descriptor,
			"policy_id": "sporespore_balanced_wave_bw5r_b_v1", "memory": memory, "state": state, "command": command}
		var response: Dictionary = sdk.decode_exact_json_v1(sdk.balanced_wave_policy_step_json(Transport.stringify(request)))
		if response.get("ok") != true or response["value"]["actuation"]["safe_no_actuation"] != false:
			checks["native_warmup_and_mode_switch_without_memory_reset"] = false
			break
		memory = response["value"]["next_memory"].duplicate(true)
		if Profile.WalkingEntry.Startup.limited_selected_v1(Profile.walking_entry_id_v1(probe._candidate_selection, "walking_resume")):
			for motor in response["value"]["actuation"]["ordered_commands"]:
				if String(motor["actuator_id"]).ends_with("_knee_motor"):
					checks["selected_joint_bound_in_actual_native_commands"] = checks["selected_joint_bound_in_actual_native_commands"] and motor["position_saturated"] == false and motor["requested_target_position_rad"] <= 1.1
		if local_step <= 361:
			for limb in memory["ordered_limb_memory"]:
				checks["native_warmup_and_mode_switch_without_memory_reset"] = checks["native_warmup_and_mode_switch_without_memory_reset"] and limb["gait_step"] == 240 + local_step - 1 and limb["release_hold_step_count"] == 0 and limb["recontact_hold_step_count"] == 0
		if local_step == 450:
			var front_right: Dictionary = memory["ordered_limb_memory"][3]
			checks["native_contact_gate_active_after_warmup"] = front_right["gait_step"] == 684 and front_right["release_hold_step_count"] > 0 and memory["phase_progression_mode"] == "contact_gated"

func _finish(checks: Dictionary, results: Array) -> void:
	var ok := not checks.values().has(false)
	print("DEVELOPMENT_WALKING_ENTRY_PROBE ", Transport.stringify({"ok": ok, "checks": checks, "cases": results,
		"input_kind": "reconstructed_from_retained_standing_with_synthetic_contact_provenance",
		"exact_original_walking_request_replayed": false, "physical_outcome_predicted": false,
		"model_construction_count": 0, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}))
	quit(0 if ok else 1)
