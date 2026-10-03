extends SceneTree
# gdlint: disable=max-line-length

const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Facade := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const Replay := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_replay_v1.gd")

class Probe:
	extends "res://sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd"
	func _initialize() -> void:
		pass

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var selection := Profile.load_v1({"resource": args[0], "raw_sha256": args[1]})
	var checks := {"profile_loaded": not selection.is_empty()}
	if selection.is_empty():
		_finish(checks, {})
		return
	var id := Profile.walking_start_id_v1(selection, "walking_resume")
	var policy_id := Profile.WalkingPolicy.selected_id_v1(selection, "walking_resume")
	var contact_start := Profile.WalkingEntry.Startup.contact_gated_selected_v1(Profile.walking_entry_id_v1(selection, "walking_resume"))
	var declared: Dictionary = Profile.WalkingStart.contract_for_v1(id)["initial_gait_steps"].duplicate(true)
	# Project declaration counts only. Never normalize retained native values.
	for limb in declared:
		declared[limb] = int(declared[limb])
	var offset := int(declared["front_left"])
	var phase_order := ["rear_left", "front_left", "rear_right", "front_right"]
	var first_limb: String = phase_order[offset / 90]
	var recontact_limb: String = phase_order[(offset / 90 + 3) % 4]
	var probe := Probe.new()
	probe._candidate_selection = selection
	checks["actual_worker_selects_resume_only"] = probe._walking_start_profile_id_v1("walking_resume") == id and probe._walking_start_profile_id_v1("walking_prefix").is_empty()
	var phases := Facade.initial_gait_steps_v1(40200, "walking_resume", id)
	checks["normal_plan_and_facade_match"] = phases == Profile.WalkingStart.normal_initial_gait_steps_v1(id) and phases.size() == 4 and phases == declared
	checks["prefix_and_legacy_remain_seeded"] = Facade.initial_gait_steps_v1(40200, "walking_prefix").values().all(func(v): return v == 240) and Facade.initial_gait_steps_v1(40200, "walking_resume").values().all(func(v): return v == 240)
	checks["crossed_segment_refuses"] = Facade.initial_gait_steps_v1(40200, "walking_prefix", id).is_empty()
	checks["unknown_profile_refuses"] = Facade.initial_gait_steps_v1(40200, "walking_resume", "unknown").is_empty()
	checks["negative_seed_refuses"] = Facade.initial_gait_steps_v1(-1, "walking_resume", id).is_empty()
	for bad in [false, 0, "unknown"]:
		var schedule: Dictionary = selection["diagnostic_schedule"].duplicate(true)
		schedule["walking_start_profile_id"] = bad
		checks["selector_refuses_" + str(bad)] = not Profile.WalkingStart.schedule_valid_v1(schedule)
	var crossed: Dictionary = selection["diagnostic_schedule"].duplicate(true)
	crossed["walking_entry_profile_id"] = ""
	checks["crossed_warmup_refuses"] = not Profile.WalkingStart.schedule_valid_v1(crossed)
	if offset != 0:
		var old_contact: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Profile.WalkingEntry.Startup.CONTACT_CONTRACT_PATH))
		for changed_entry in ["", false, 90, old_contact["profile_id"]]:
			var changed: Dictionary = selection["diagnostic_schedule"].duplicate(true)
			changed["walking_entry_profile_id"] = changed_entry
			checks["rotated_pair_refuses_" + str(changed_entry)] = not Profile.WalkingStart.schedule_valid_v1(changed)
		var wrong_start: Dictionary = selection["diagnostic_schedule"].duplicate(true)
		wrong_start["walking_start_profile_id"] = Profile.WalkingStart._contact_contract["profile_id"]
		checks["rotated_entry_refuses_zero_start"] = not Profile.WalkingStart.schedule_valid_v1(wrong_start)
	probe._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(selection["worker_selection"]["binding"]))
	checks["runtime_loaded"] = probe._load_runtime_extension_v1()
	var result := {"normal_plan": Profile.WalkingStart.Launcher.compile_sdk_execution_mode_plan(true, true, "post_settle_full",
		Profile.WalkingStart.Launcher.SDK_P5I3B_STABILITY_POLICY_ID, 0), "contract_phases": declared}
	if checks["runtime_loaded"]:
		var facade := Facade.new()
		var detached_floor: StaticBody3D = null
		if Profile.WalkingPolicy.floor_selected_v1(policy_id):
			detached_floor = Facade.RecoveryWorld.create_floor_v1()
			facade._binding = {"floor": detached_floor, "model_instance_id": "synthetic-start-floor"}
		var frame := Facade.DevelopmentWalkingFrame.frame_v1(Basis.IDENTITY, "walking_resume", Profile.walking_frame_id_v1(selection, "walking_resume"))
		var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID)["profile"]
		checks["actual_adapter_start"] = facade._start_adapter_from_frame_v1(frame, Vector3.ZERO, phases, material, true, policy_id).get("ok") == true
		if checks["actual_adapter_start"]:
			var adapter: RefCounted = facade._adapter
			var first_request := {}
			var first_output := {}
			var count := 0
			checks["actual_mode_transitions"] = true
			checks["all_native_commands_valid"] = true
			checks["contact_start_has_no_memory_transition"] = true
			checks["contact_start_gate_holds_from_first_cycle"] = not contact_start
			checks["contact_start_recontact_holds_from_first_cycle"] = not contact_start
			checks["first_scheduled_swing_matches_declared_limb"] = false
			for local_step in range(1, 451):
				var mode := probe._walking_phase_progression_mode_v1("walking_resume", local_step)
				var before := Transport.stringify(adapter._memory)
				if adapter._configure_phase_progression_mode(mode).get("ok") != true:
					checks["actual_mode_transitions"] = false
					break
				if contact_start:
					checks["contact_start_has_no_memory_transition"] = checks["contact_start_has_no_memory_transition"] and mode == "contact_gated" and Transport.stringify(adapter._memory) == before
				# Synthetic observations only. The real initializer, adapter mode
				# transition and compiled policy execute; no physical outcome is predicted.
				var state: Dictionary = adapter._perfect_synthetic_controller_state_frame(local_step, adapter._compiled["morphology"])
				if contact_start:
					# Explicit synthetic absent contact exercises the selected
					# existing recontact guard, not a forecast of V30's trajectory.
					for contact in state["ordered_contact_observations"]:
						var absent_limb := recontact_limb if policy_id.is_empty() else first_limb
						# V43 safely refuses permanent missing stance support. This
						# startup-success fixture uses a finite synthetic loss window;
						# its separate native gate still requires the timeout checks.
						var loss_window: bool = policy_id not in [Profile.WalkingPolicy.PROGRESSION_POLICY_ID, Profile.WalkingPolicy.POSTURE_POLICY_ID] or local_step <= 150
						if contact["contact_site_id"] == absent_limb + "_foot" and (policy_id.is_empty() or local_step > 60) and loss_window:
							contact["presence"] = false
							contact["bears_support"] = false
							contact["provenance"]["engine_contact_ids"] = []
				var command: Dictionary = adapter._perfect_synthetic_motion_command(local_step, mode)
				command["gait_amplitude"] = probe._walking_gait_amplitude_v1("walking_resume", local_step)
				var request: Dictionary = adapter._controller_step_request(adapter._memory.duplicate(true), state, command)
				var response: Dictionary = adapter._call_balanced_wave_session_step_with_transport_verification(request, local_step)
				if response.get("ok") != true or response.get("value", {}).get("actuation", {}).get("safe_no_actuation") != false:
					checks["all_native_commands_valid"] = false
					break
				if local_step == 1:
					first_request = request.duplicate(true)
					first_output = response["value"].duplicate(true)
				if local_step == 2:
					var correct := true
					if Profile.WalkingPolicy.contract_for_v1(policy_id).has("stance_support_mode_id"):
						# Support knees may bend without a swing. Verify the explicit
						# wave fraction, not the combined support/swing target.
						var support: Dictionary = response["value"]["actuation"]["receipt"]["recovery_support_plane"]
						correct = support["ordered_limb_proposals"].size() == 4
						for limb in support["ordered_limb_proposals"]:
							var first: bool = limb["limb_id"] == first_limb
							correct = correct and (limb["walking_knee_fraction"] > 0.0 if first else limb["walking_knee_fraction"] == 0.0)
					else:
						for motor in response["value"]["actuation"]["ordered_commands"]:
							if String(motor["actuator_id"]).ends_with("_knee_motor"):
								var first: bool = motor["actuator_id"] == first_limb + "_knee_motor"
								correct = correct and (motor["requested_target_position_rad"] > 0.0 if first else motor["requested_target_position_rad"] == 0.0)
					checks["first_scheduled_swing_matches_declared_limb"] = correct
				adapter._memory = response["value"]["next_memory"].duplicate(true)
				if contact_start and local_step == 56:
					for limb in adapter._memory["ordered_limb_memory"]:
						if limb["limb_id"] == first_limb:
							checks["contact_start_gate_holds_from_first_cycle"] = limb["gait_step"] == offset + 54 and limb["release_hold_step_count"] > 0
						if policy_id.is_empty() and limb["limb_id"] == recontact_limb:
							checks["contact_start_recontact_holds_from_first_cycle"] = limb["gait_step"] == offset + 54 and limb["recontact_hold_step_count"] > 0
				if not policy_id.is_empty():
					for limb in adapter._memory["ordered_limb_memory"]:
						if limb["limb_id"] == first_limb and limb["recontact_hold_step_count"] > 0 and limb["gait_step"] == offset + 72:
							checks["contact_start_recontact_holds_from_first_cycle"] = true
				count += 1
			checks["450_native_command_steps"] = count == 450
			checks["first_native_memory_matches_declared_phase"] = first_request.get("memory", {}).get("ordered_limb_memory", []).all(func(limb): return limb["gait_step"] == declared[limb["limb_id"]])
			checks["first_targets_still_zero"] = first_output.get("actuation", {}).get("ordered_commands", []).all(func(command): return command["requested_target_position_rad"] == 0.0 and command["clamped_target_position_rad"] == 0.0)
			var report := {"seed": 40200, "retained_arm": {"walking_sessions": [{"evaluation_segment_id": "walking_resume", "session_id": "synthetic-start",
				"start_receipt": {"session_id": "synthetic-start", "initial_gait_steps": phases, "gait_phase_seed": 40200, "development_walking_start_profile_id": id}}]},
				"development_walking_entry": {"rows": [{"session_id": "synthetic-start", "session_local_step": 1, "request": first_request}]}}
			checks["reader_verifies_first_real_request"] = Profile.WalkingStart.validate_report_v1(report, id).get("ok") == true
			checks["legacy_reader_refuses_selected_start"] = Profile.WalkingStart.validate_report_v1(report, "").get("ok") == false
			for corruption in ["phase", "seed", "missing_first", "memory_phase", "duplicate_limb", "selector"]:
				var changed := report.duplicate(true)
				var start: Dictionary = changed["retained_arm"]["walking_sessions"][0]["start_receipt"]
				var rows: Array = changed["development_walking_entry"]["rows"]
				match corruption:
					"phase": start["initial_gait_steps"]["front_left"] = 240
					"seed": start["gait_phase_seed"] = 0
					"missing_first": rows.clear()
					"memory_phase": rows[0]["request"]["memory"]["ordered_limb_memory"][0]["gait_step"] = 240
					"duplicate_limb": rows[0]["request"]["memory"]["ordered_limb_memory"][1]["limb_id"] = rows[0]["request"]["memory"]["ordered_limb_memory"][0]["limb_id"]
					"selector": start["development_walking_start_profile_id"] = ""
				checks["reader_refuses_" + corruption] = Profile.WalkingStart.validate_report_v1(changed, id).get("ok") == false
			checks["zero_resume_negative_valid"] = Profile.WalkingStart.validate_report_v1({"seed": 40200, "retained_arm": {"walking_sessions": []}}, id).get("validated_resume_sessions") == 0
			result = {"command_probe_steps": count, "initial_gait_steps": phases, "first_native_memory": first_request.get("memory"),
				"terminal_native_memory": adapter._memory.duplicate(true), "synthetic_observations_only": true}
			checks["actual_shutdown"] = adapter.shutdown().get("ok") == true
		facade._adapter = null
		if detached_floor != null:
			detached_floor.free()
	probe.free()
	_finish(checks, result)

func _finish(checks: Dictionary, result: Dictionary) -> void:
	print("DEVELOPMENT_WALKING_START_CHECKS ", Transport.stringify({"ok": not checks.values().has(false), "checks": checks,
		"result": result, "world_build_count": 0, "solver_step_count": 0, "native_physics_read_count": 0, "physical_acceptance_authority": false}))
	quit(0 if not checks.values().has(false) else 1)
