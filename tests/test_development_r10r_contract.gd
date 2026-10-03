extends "res://sdk/trace_analysis/development_recovery_candidate_replay.gd"
# gdlint: disable=max-line-length

func _input_arguments_v1() -> PackedStringArray:
	return PackedStringArray([OS.get_cmdline_user_args()[0]])

func _check_candidate_stance(sdk: Object, context: Dictionary, checks: Dictionary) -> void:
	var id: String = _candidate_selection["post_kick_controller_id"]
	var stance_profile := Replay.Canonical.Route.DevelopmentStanceProfile.profile_for_recovery_v1(id)
	var compatibility: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/r10r_compatibility_fixture_contract_v1.json"))
	var fixture_binding: Dictionary = compatibility.compiled_fixtures
	checks["original_fixture_bytes"] = "sha256:" + FileAccess.get_sha256(fixture_binding.path) == fixture_binding.raw_sha256
	if not checks["original_fixture_bytes"]: return
	var count := 0
	for line in FileAccess.get_file_as_string(compatibility["compiled_fixtures"]["path"]).split("\n"):
		if not line.begins_with("CANDIDATE_STANCE_CONTROL_FIXTURE "):
			continue
		var fixture: Dictionary = sdk.decode_exact_json_v1(line.trim_prefix("CANDIDATE_STANCE_CONTROL_FIXTURE ").strip_edges())
		var request: Dictionary = fixture["request"]
		var key := "stance_" + str(count) + "_"
		count += 1
		var actual := Replay.Runtime.plan_stance_control_v4(sdk, request)
		checks[key + "actual_dll_matches_compiled"] = Replay.Runtime.canonicalize(sdk, actual).get("sha256") == Replay.Runtime.canonicalize(sdk, fixture["expected"]).get("sha256")
		if not actual.has("control_receipt"):
			continue
		checks[key + "real_binding_check"] = Replay.Canonical.Route.stance_observation_binding_receipt_valid_v1(sdk, actual,
			request["collection"], request["handoff_or_stance_step"], request["portable_step_observation_v3"],
			request["energy_partition_authority"], request["development_progression"])
		var surface := Replay.Canonical.Route.zero_world_command_surface_v1(context)
		checks[key + "uninserted_hinge_surface"] = surface.get("ok") == true
		if surface.get("ok") != true:
			continue
		var positions: Dictionary = surface["position_by_joint_id"]
		var velocities := {}
		for joint in request["collection"]["observation"]["state"]["ordered_joint_observations"]:
			positions[joint["joint_id"]] = joint["position_rad"]
			velocities[joint["joint_id"]] = joint["velocity_rad_s"]
		var control: Dictionary = actual["control_receipt"]
		var crossed := Replay.Canonical.Route.apply_behavior_control_solver_coupled_native_constraint_motor_v11(
			sdk, control, surface["joint_by_actuator_id"], positions, true, "sporespore_exact_s169_prone_to_standing_controller_v14")
		checks[key + "crossed_selection_refused"] = crossed.get("ok") == false
		for joint in surface["ordered_joints"]:
			checks[key + "refusal_before_write_" + joint.name] = not joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
		var applied := Replay.Canonical.Route.apply_behavior_control_solver_coupled_native_constraint_motor_v11(
			sdk, control, surface["joint_by_actuator_id"], positions, true, id)
		checks[key + "real_applier"] = applied.get("ok") == true
		if applied.get("ok") == true:
			checks[key + "owner_propagated"] = applied.get("stance_controller_id") == control["controller_id"] and applied.get("recovery_controller_id") == null
			checks[key + "no_solver_steps"] = applied.get("solver_step_count") == 0 and applied.get("zero_world_host_surface") == true
			for intent in applied["ordered_intents"]:
				if stance_profile.has("reference_ramp"):
					# Rust tests cover the trajectory at every clock. This boundary
					# checks translation of the exact exported position command into
					# a motor velocity, without inventing a second trajectory policy.
					var expected_commands: Array = fixture["expected"]["control_receipt"]["ordered_commands"]
					var matching: Array = expected_commands.filter(func(command): return command["joint_id"] == intent["joint_id"])
					checks[key + "bound_reference_command_" + intent["joint_id"]] = matching.size() == 1
					if matching.size() != 1:
						continue
					var bound: Dictionary = matching[0]
					var interval := float(request["collection"]["observation"]["outer_step_duration_s"])
					var expected := clampf((float(bound["target_position_rad"]) - float(positions[intent["joint_id"]])) / interval,
						-float(bound["maximum_target_speed_rad_s"]), float(bound["maximum_target_speed_rad_s"]))
					checks[key + "compiled_reference_velocity_" + intent["joint_id"]] = absf(intent["canonical_target_velocity_rad_s"] - expected) < 1e-10
					continue
				var goal := 0.0
				if stance_profile.get("geometry_rule_id") == "two_link_sagittal_endpoint_under_hip_v1":
					var fraction := float(request["collection"]["descriptor"]["upper_length_fraction"])
					var knee := float(stance_profile["target_knee_angle_rad"])
					var hip := -atan2((1.0-fraction)*sin(knee), fraction+(1.0-fraction)*cos(knee))
					goal = knee if String(intent["joint_id"]).ends_with("_knee") else hip
				var raw_speed := (goal-float(positions[intent["joint_id"]])) / float(stance_profile["response_time_s"])
				if stance_profile.has("measured_velocity_damping_gain"):
					raw_speed -= float(stance_profile["measured_velocity_damping_gain"]) * float(velocities[intent["joint_id"]])
				var expected := clampf(raw_speed, -0.75, 0.75)
				# Only transport rounding is tolerated, not a changed motor speed.
				checks[key + "measured_error_velocity_" + intent["joint_id"]] = absf(intent["canonical_target_velocity_rad_s"] - expected) < 1e-10
		for joint in surface["ordered_joints"]:
			joint.free()
	var selected_stance := Replay.Canonical.Route.DevelopmentStanceProfile.for_recovery_v1(id)
	checks["candidate_stance_fixture_population"] = count == (0 if selected_stance == Replay.Canonical.Route.STANCE_CONTROLLER_ID else 6)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_candidate_selection = CandidateProfile.load_v1({"resource": args[0], "raw_sha256": args[1]})
	var checks := {"profile_loaded": not _candidate_selection.is_empty()}
	if not checks["profile_loaded"]:
		print("DEVELOPMENT_RECOVERY_CANDIDATE_CONTRACT ", Transport.stringify({"ok": false, "checks": checks}))
		quit(1)
		return
	if GDExtensionManager.is_extension_loaded(OLD):
		GDExtensionManager.unload_extension(OLD)
	checks["runtime_load"] = GDExtensionManager.load_extension(_selection_v1()["extension"]) == GDExtensionManager.LOAD_STATUS_OK
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var id: String = _candidate_selection["post_kick_controller_id"]
	var context := Replay.Canonical.Route.prepare_development_candidate_context_v1(sdk, id)
	checks["exact_context"] = Replay.Canonical.Route.development_candidate_context_binding_exact_v1(sdk, context, id)
	checks["old_context_refuses_candidate"] = not Replay.Canonical.Route.rate_limited_recovery_context_binding_exact_v1(sdk, context)
	checks["crossed_controller_refused"] = not Replay.Canonical.Route.development_candidate_context_binding_exact_v1(sdk, context, "unknown")
	for key in ["physical_world_construction_authorized", "recovery_behavior_evaluation_authorized", "finite_behavior_pair_selected"]:
		var changed := context.duplicate(true)
		changed[key] = true
		checks["authority_refused_" + key] = not Replay.Canonical.Route.development_candidate_context_binding_exact_v1(sdk, changed, id)
	var fixed := CandidateProfile.contract_v1()
	var declaration := {"development_execution_mode": fixed["single_mode"], "comparative_authority": false,
		"baseline_reused": false, "children": [{"role": fixed["single_role"]}]}
	checks["single_kick_allowed"] = CandidateProfile.roles_valid_v1(declaration)
	for key in ["comparative_authority", "baseline_reused"]:
		var changed := declaration.duplicate(true)
		changed[key] = true
		checks["single_refuses_" + key] = not CandidateProfile.roles_valid_v1(changed)
	declaration["development_execution_mode"] = fixed["paired_mode"]
	checks["pair_refuses_missing_baseline"] = not CandidateProfile.roles_valid_v1(declaration)
	declaration["children"].push_front({"role": "matched_no_kick_continuation"})
	checks["fresh_pair_allowed"] = CandidateProfile.roles_valid_v1(declaration)
	for reference in [{}, {"resource": args[0], "raw_sha256": "sha256:" + "0".repeat(64)},
		{"resource": "res://sdk/development/recovery_candidates/../unknown.json", "raw_sha256": args[1]}]:
		checks["profile_refusal_" + str(reference)] = CandidateProfile.load_v1(reference).is_empty()
	var owner := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd")
	checks["future_identity_is_data_not_shared_schema"] = owner.profile_v1("sporespore_exact_s169_prone_to_standing_controller_v9")["application_schema"] != owner.profile_v1("sporespore_exact_s169_prone_to_standing_controller_v10")["application_schema"]
	_check_candidate_stance(sdk, context, checks)
	sdk = null
	print("DEVELOPMENT_RECOVERY_CANDIDATE_CONTRACT ", Transport.stringify({"ok": not checks.values().has(false),
		"checks": checks, "world_build_count": 0, "solver_step_count": 0, "physical_acceptance_authority": false, "release_authority": false}))
	quit(0 if not checks.values().has(false) else 1)
