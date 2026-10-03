extends SceneTree
const HoldReplay := preload("res://sdk/adapters/godot/gdscript/r10aa_stance_entry_replay_v1.gd")
const Shared := preload("res://tests/test_development_v32_walking_policy.gd")
const Facade := Shared.Facade
const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Route := Profile.WalkingPolicy.R10AA
const Stance := Profile.WalkingPolicy.FiniteRoute.StanceEntry
const Cycle := preload("res://sdk/adapters/godot/gdscript/development_recovery_cycle_stop_v1.gd")
const Transport := Shared.Transport
class Worker:
	extends "res://sdk/adapters/godot/gdscript/r10aa_route_worker_v1.gd"
	func _initialize() -> void: pass
var checks: Dictionary = {}
var result: Dictionary = {}
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2: quit(1); return
	var worker := Worker.new()
	worker._candidate_selection = {"diagnostic_schedule": {"walking_policy_id": Route.ID},
		"worker_selection": {"extension": "res://sdk/adapters/godot/development_candidate_runtimes/r10aa-partial-load-seeking-core-v1.gdextension"}}
	worker._seed = 51008
	worker._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development/recovery_candidates/r10aa-partial-load-seeking-core-v1.runtime.json"))
	checks.actual_worker_runtime_preflight = worker._load_runtime_extension_v1()
	if not checks.actual_worker_runtime_preflight: worker.free(); quit(2); return
	result.runtime_preflight = worker._entry_walking_runtime_preflight
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var fixture: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0])).fixtures[0]
	checks.worker_selected = worker._r10k_selected_v1() and worker._stance_entry_selected_v1() and worker._hold_route_selected_v1()
	checks.post_hold_distinct_segment = worker._walking_segment_valid_v1(Route.POST_HOLD_SEGMENT) and Route.POST_HOLD_SEGMENT not in worker._entry_segments_v1()
	checks.post_hold_policy = worker._walking_policy_id_v1(Route.POST_HOLD_SEGMENT) == Route.POST_HOLD_ALIAS
	checks.post_hold_frame = worker._walking_frame_id_v1(Route.POST_HOLD_SEGMENT) == "" and worker._walking_start_profile_id_v1(Route.POST_HOLD_SEGMENT) == "" and worker._walking_contact_profile_id_v1(Route.POST_HOLD_SEGMENT) == ""
	checks.post_hold_schedule = worker._walking_gait_amplitude_v1(Route.POST_HOLD_SEGMENT, 1) == 0.0 and worker._walking_session_step_limit_v1(Route.POST_HOLD_SEGMENT) == 240 and worker._walking_phase_progression_mode_v1(Route.POST_HOLD_SEGMENT, 1) == "contact_gated"
	checks.post_hold_ownership = worker._walking_owner_for_phase_v1("post_recovery_stationary_settling") == "stance" and worker._walking_facade_evaluation_segment_v1(Route.POST_HOLD_SEGMENT) == "matched_continuation"
	checks.post_hold_not_walking_cycles = not Cycle.selected_policy_v1(Route.POST_HOLD_ALIAS) and not Profile.WalkingPolicy.FiniteRoute.segment_selected_v1(Route.ID, Route.POST_HOLD_SEGMENT)
	var phases := Route.post_hold_gait_steps_v1("walking_resume", "", "")
	checks.post_hold_initial_six = phases.size() == 4 and phases.values().all(func(v): return v == 6)
	checks.post_hold_crossed_initial_profiles = Route.post_hold_gait_steps_v1("walking_prefix", "", "").is_empty() and Route.post_hold_gait_steps_v1("walking_resume", Route.START, "").is_empty() and Route.post_hold_gait_steps_v1("walking_resume", "", Route.PREFIX_PROFILE).is_empty()
	checks.post_hold_alias_crossings = Profile.WalkingPolicy.binding_v1(Route.POST_HOLD_ALIAS, Stance.HOLD_SEGMENT).is_empty() and Profile.WalkingPolicy.binding_v1(Route.HOLD_ALIAS, Route.POST_HOLD_SEGMENT).is_empty() and Profile.WalkingPolicy.binding_v1(Route.ID, Route.POST_HOLD_SEGMENT).is_empty()
	checks.post_hold_alias_native = Profile.WalkingPolicy.binding_v1(Route.POST_HOLD_ALIAS, Route.POST_HOLD_SEGMENT).get("policy_id") == Profile.WalkingPolicy.STARTUP_VELOCITY_POLICY_ID
	for seed in [51008]:
		var expected: int = {51008:248}[seed]
		var prefix := Facade.initial_gait_steps_v1(seed, "walking_prefix", "", Route.PREFIX_PROFILE)
		checks["prefix_" + str(seed)] = prefix.size() == 4 and prefix.values().all(func(v): return v == expected)
	checks.launch_authority_still_refused = not worker._authorized_seed_binding_v1("51008", "test", "sha256:" + "0".repeat(64))
	checks.prefix_unknown_refused = Facade.initial_gait_steps_v1(41046, "walking_prefix", "", Route.PREFIX_PROFILE).is_empty()
	checks.old_prefix_modulo_preserved = Facade.initial_gait_steps_v1(41345, "walking_prefix").values().all(func(v): return v == 41345 % 360)
	checks.prefix_crossed_segment_refused = Facade.initial_gait_steps_v1(51008, "walking_resume", "", Route.PREFIX_PROFILE).is_empty()
	checks.prefix_crossed_start_refused = Facade.initial_gait_steps_v1(51008, "walking_prefix", Route.START, Route.PREFIX_PROFILE).is_empty()
	checks.task_native_identity = Route.native_identity_consistent_v1()
	checks.kicked_budget = Profile.WalkingPolicy.FiniteRoute.task_boundary_v1({"arm_id":"kick_passive_recovery_resume", "solver_step_count":3752}, {}, Route.ID).role_and_budget_valid
	checks.kicked_over_budget_refused = not Profile.WalkingPolicy.FiniteRoute.task_boundary_v1({"arm_id":"kick_passive_recovery_resume", "solver_step_count":3753}, {}, Route.ID).role_and_budget_valid
	checks.baseline_budget_unchanged = Profile.WalkingPolicy.FiniteRoute.task_boundary_v1({"arm_id":"matched_no_kick_continuation", "solver_step_count":2553}, {}, Route.ID).maximum_role_solver_steps == 2552
	for variant in [
		{"label":"resume", "id":Route.ID, "segment":"walking_resume", "native":Route.POLICY},
		{"label":"ramp", "id":Route.ENTRY_ALIAS, "segment":"matched_continuation", "native":Stance.FLEXED_NATIVE_ID},
		{"label":"hold", "id":Route.HOLD_ALIAS, "segment":"matched_continuation", "native":Profile.WalkingPolicy.STARTUP_VELOCITY_POLICY_ID},
		{"label":"post_hold", "id":Route.POST_HOLD_ALIAS, "segment":Route.POST_HOLD_SEGMENT, "native":Profile.WalkingPolicy.STARTUP_VELOCITY_POLICY_ID}]:
		_check_native(sdk, fixture, variant)
	if result.get("post_hold", {}).get("ledger", {}).get("ok") == true:
		_check_hold_replay(sdk, result.post_hold.ledger, worker)
	worker.free()
	sdk = null
	var ok := checks.values().all(func(v): return v == true)
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	output.store_string(Transport.stringify({"ok":ok, "checks":checks, "result":result, "world_build_count":0, "solver_step_count":0, "physical_route_qualified":false, "physical_acceptance_authority":false, "release_authority":false}))
	output.close()
	print("R10AA_HOLD_ROUTE_INTERFACE ", checks.size(), " checks; ok=", ok)
	quit(0 if ok else 1)

func _check_native(sdk: Object, fixture: Dictionary, variant: Dictionary) -> void:
	var facade := Facade.new()
	var floor := Facade.RecoveryWorld.create_floor_v1()
	var model: String = "r10aa-route-selection-" + variant.label
	facade._binding = {"floor": floor, "model_instance_id": model}
	var frame: Dictionary = fixture.state.task_frame
	var axes := {"lateral": Vector3(frame.lateral_axis_world_unit.x, frame.lateral_axis_world_unit.y, frame.lateral_axis_world_unit.z), "forward": Vector3(frame.forward_axis_world_unit.x, frame.forward_axis_world_unit.y, frame.forward_axis_world_unit.z), "legacy_yaw_rad": frame.reference_yaw_rad}
	var phases := Route.post_hold_gait_steps_v1("walking_resume", "", "") if variant.label == "post_hold" else Profile.WalkingStart.normal_initial_gait_steps_v1(Route.START)
	var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID).profile
	var started := facade._start_adapter_from_frame_v1(axes, Vector3.ZERO, phases, material, true, variant.id, variant.segment)
	checks[variant.label + "_actual_facade_start"] = started.get("ok") == true
	var retained := {"start": started}
	if started.get("ok") == true:
		checks[variant.label + "_native_identity"] = started.controller_policy_id == variant.native
		checks[variant.label + "_stationary_hold_selection"] = facade._adapter._development_stationary_hold == (variant.label in ["hold", "post_hold"])
		checks[variant.label + "_shutdown"] = facade._adapter.shutdown().get("ok") == true
	facade._adapter = null
	var facade_segment: String = "matched_continuation" if variant.label == "post_hold" else variant.segment
	var floor_source := Facade.SdkAdapterScript.DevelopmentFloor.capture_v1(sdk, floor, "r10f-l13-zero-world-" + facade_segment) if variant.label != "ramp" else {}
	var ledger := Shared.Prior._walking_ledger_production_fixture_v2(sdk, 900, "walking_resume", facade_segment,
		"post_recovery_stationary_settling" if variant.label == "post_hold" else Stance.PHASE if variant.label in ["ramp", "hold"] else "fresh_selected_policy_walking_resume" if variant.label == "resume" else "matched_no_kick_continuation",
		model, variant.id, true, floor_source, fixture if variant.label != "ramp" else {})
	checks[variant.label + "_production_motor_ledger"] = ledger.get("ok") == true
	retained["ledger"] = ledger
	result[variant.label] = retained
	floor.free()

func _check_hold_replay(sdk: Object, ledger: Dictionary, worker: Worker) -> void:
	var replay := HoldReplay
	var step := {"ok": true, "session_id": ledger.session_id, "segment_id": "walking_resume", "session_local_step": 1, "global_semantic_step": 900}
	for key in ["sample_receipt", "portable_step_receipt", "walking_actuation_handoff_receipt", "authority_application_receipt", "motor_population_readback", "ledger_application_intent"]: step[key] = ledger[key]
	var digest: String = replay._sha(sdk, step)
	var row := {"segment_id": Route.POST_HOLD_SEGMENT, "full_step_receipt_sha256": digest, "step": step}
	var trace := {"global_semantic_step": 900, "walking_session_local_step": 1, "walking_session_id": ledger.session_id, "application_intent_sha256": replay._sha(sdk, ledger.ledger_application_intent)}
	var binding := Profile.WalkingPolicy.binding_v1(Route.POST_HOLD_ALIAS, Route.POST_HOLD_SEGMENT)
	var start := {"selected_policy_id": binding.policy_id, "selected_policy_digest": binding.policy_digest,
		"controller_profile_sha256": Route.post_hold_contract.native_profile_sha256,
		"global_start_step": 899, "development_walking_policy_id": Route.POST_HOLD_ALIAS,
		"initial_gait_steps": Route.post_hold_gait_steps_v1("walking_resume", "", ""),
		"task_frame_lateral_axis_world_host_real": [0.0,0.0,1.0]}
	var session := {"session_id": ledger.session_id, "evaluation_segment_id": Route.POST_HOLD_SEGMENT, "start_receipt": start,
		"step_receipt_sha256s": [digest], "walking_actuation_handoff_receipt": ledger.walking_actuation_handoff_receipt}
	var descriptor := Facade.RecoveryRoute.exact_base_descriptor_v1()
	var checked := replay.neutral_command_v1(sdk, row, trace, session, descriptor, {}, Route.ID)
	checks.post_hold_cold_native_replay = checked.get("ok") == true
	result.post_hold_cold_replay = checked
	checks.post_hold_actual_request_initial_six = step.sample_receipt.request.memory.ordered_limb_memory.all(func(v): return v.gait_step == 6)
	worker._sdk = sdk
	checks.worker_retains_stationary_command = worker._retain_development_walking_source_v1(Route.POST_HOLD_SEGMENT, step, digest).get("ok") == true and worker._post_recovery_hold_control_rows.size() == 1
	var moving := step.duplicate(true)
	moving.sample_receipt.request.command.desired_planar_velocity_task_m_s.x = 0.01
	checks.worker_refuses_moving_hold = worker._retain_development_walking_source_v1(Route.POST_HOLD_SEGMENT, moving, replay._sha(sdk,moving)).get("ok") == false and worker._post_recovery_hold_control_rows.size() == 1
	for defect in ["initial_phase", "session_alias", "source_clock", "nonzero_velocity", "memory_counter", "missing_floor", "missing_body", "native_response", "motor_application"]:
		var bad_row := row.duplicate(true)
		var bad_session := session.duplicate(true)
		match defect:
			"initial_phase": bad_session.start_receipt.initial_gait_steps.front_left = 105
			"session_alias": bad_session.start_receipt.development_walking_policy_id = Route.HOLD_ALIAS
			"source_clock": bad_row.step.global_semantic_step = 901
			"nonzero_velocity": bad_row.step.sample_receipt.request.command.desired_planar_velocity_task_m_s.x = 0.01
			"memory_counter": bad_row.step.sample_receipt.request.memory.ordered_limb_memory[0].gait_step = 7
			"missing_floor": bad_row.step.sample_receipt.request.erase("floor_reference")
			"missing_body": bad_row.step.sample_receipt.request.erase("measured_body_frame")
			"native_response": bad_row.step.portable_step_receipt.native_step_transport_verification.raw_native_response_sha256 = "sha256:" + "0".repeat(64)
			"motor_application": bad_row.step.authority_application_receipt.ordered_applications[0].host_applied_target_velocity_rad_s += 0.01
		# Rebind the outer digest so the inner source/command check must reject it.
		bad_row.full_step_receipt_sha256 = replay._sha(sdk,bad_row.step)
		bad_session.step_receipt_sha256s[0] = bad_row.full_step_receipt_sha256
		var refused := replay.neutral_command_v1(sdk,bad_row,trace,bad_session,descriptor,{},Route.ID)
		checks["post_hold_cold_refuses_"+defect] = refused.get("ok") == false
		result["post_hold_refusal_"+defect] = refused
	worker._sdk = null
