extends SceneTree
const Shared := preload("res://tests/test_development_v32_walking_policy.gd")
const Facade := Shared.Facade
const Profile := preload("res://sdk/adapters/godot/gdscript/development_recovery_candidate_profile_v1.gd")
const Route := Profile.WalkingPolicy.R10O
const Stance := Profile.WalkingPolicy.FiniteRoute.StanceEntry
const Cycle := preload("res://sdk/adapters/godot/gdscript/development_recovery_cycle_stop_v1.gd")
const PROFILE := "res://sdk/development/recovery_candidates/r10o-v55-initialized-brake-integrated-v2.json"
const Transport := Shared.Transport
class Worker:
	extends "res://sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd"
	func _initialize() -> void:
		pass

var checks: Dictionary = {}
var result: Dictionary = {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var reference := {"resource": PROFILE, "raw_sha256": "sha256:" + FileAccess.get_sha256(PROFILE)}
	var selection := Profile.load_v1(reference)
	checks["actual_candidate_profile"] = not selection.is_empty()
	var crossed := reference.duplicate(true)
	crossed.raw_sha256 = "sha256:" + "0".repeat(64)
	checks["crossed_profile_digest_refuses"] = Profile.load_v1(crossed).is_empty()
	var worker := Worker.new()
	if not selection.is_empty():
		worker._candidate_selection = selection
		worker._seed = 40741
		var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
		worker._entry_runtime = JSON.parse_string(FileAccess.get_file_as_string(profile.runtime_binding))
		checks["actual_worker_runtime_preflight"] = worker._load_runtime_extension_v1()
		if checks.actual_worker_runtime_preflight:
			result["runtime_preflight"] = worker._entry_walking_runtime_preflight
			checks["runtime_preflight_declared_phase"] = worker._entry_walking_runtime_preflight.initial_gait_steps.values().all(func(v): return v == 241)
			var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
			var fixture: Dictionary = sdk.decode_exact_json_v1(FileAccess.get_file_as_string(args[0])).fixtures[0]
			_check_selection(sdk, worker, selection)
			for variant in [
				{"label": "resume", "id": Route.ID, "segment": "walking_resume", "native": Route.POLICY},
				{"label": "matched", "id": Route.ID, "segment": "matched_continuation", "native": Route.POLICY},
				{"label": "ramp", "id": Route.ENTRY_ALIAS, "segment": "matched_continuation", "native": Stance.FLEXED_NATIVE_ID},
				{"label": "hold", "id": Route.HOLD_ALIAS, "segment": "matched_continuation", "native": Profile.WalkingPolicy.STARTUP_VELOCITY_POLICY_ID}]:
				_check_native(sdk, fixture, variant)
			sdk = null
	worker.free()
	var ok := checks.values().all(func(v): return v == true)
	var out := FileAccess.open(args[1], FileAccess.WRITE)
	out.store_string(Transport.stringify({"ok": ok, "checks": checks, "result": result,
		"world_build_count": 0, "solver_step_count": 0, "physical_execution_authorized": false,
		"physical_acceptance_authority": false, "release_authority": false,
		"scope": "Actual candidate selection, worker runtime preflight, four native facade starts and production motor ledgers on synthetic or exposed sources. Full recovery publication and launch safety integration remain pending."}))
	out.close()
	print("R10O_ROUTE_SELECTION ", checks.size(), " checks; ok=", ok)
	quit(0 if ok else 1)

func _check_selection(sdk: Object, worker: Worker, selection: Dictionary) -> void:
	checks["worker_physical_entry_closed"] = not worker._authorized_seed_binding_v1("40741", "unqualified", "sha256:" + "0".repeat(64))
	checks["worker_selects_r10o"] = worker._r10o_selected_v1() and worker._stance_entry_selected_v1() and worker._hold_route_selected_v1()
	for segment in ["walking_resume", "matched_continuation"]:
		checks[segment + "_entry_start_policy"] = Profile.walking_entry_id_v1(selection, segment) == Route.ENTRY and worker._walking_start_profile_id_v1(segment) == Route.START and worker._walking_policy_id_v1(segment) == Route.ID
		checks[segment + "_full_startup_ramp"] = worker._walking_gait_amplitude_v1(segment, 1) == 0.0 and absf(worker._walking_gait_amplitude_v1(segment, 73) - 0.5994550408719347) < 1e-15 and worker._walking_phase_progression_mode_v1(segment, 1) == "contact_gated"
	checks["task_native_identity_matches_runtime"] = Route.native_identity_consistent_v1()
	var original_runtime: String = Route.task.controller_composition.native_runtime_sha256
	Route.task.controller_composition.native_runtime_sha256 = "crossed"
	checks["crossed_task_runtime_refuses"] = Profile.WalkingPolicy.binding_v1(Route.ID, "walking_resume").is_empty()
	Route.task.controller_composition.native_runtime_sha256 = original_runtime
	checks["prefix_policy_and_start_preserved"] = worker._walking_policy_id_v1("walking_prefix").is_empty() and worker._walking_start_profile_id_v1("walking_prefix").is_empty()
	checks["separate_preparation_aliases"] = worker._walking_policy_id_v1(Stance.SEGMENT) == Route.ENTRY_ALIAS and worker._walking_policy_id_v1(Stance.HOLD_SEGMENT) == Route.HOLD_ALIAS
	checks["preparation_commands_stationary"] = worker._walking_gait_amplitude_v1(Stance.SEGMENT, 1) == 0.0 and worker._walking_gait_amplitude_v1(Stance.HOLD_SEGMENT, 1) == 0.0
	checks["cycle_selection"] = Cycle.selected_policy_v1(Route.ID) and Cycle.selected_entry_v1(Route.ENTRY) and Cycle.retention_schema_v1(Route.ID) == "sporespore_r10o_godot_cycle_stop_retention_v1"
	checks["distinct_task_retention"] = Stance.retention_schema_v1(Route.ID) == "sporespore_r10o_stance_entry_retention_v1" and Stance.task_path_for_v1(Route.ID) == Route.TASK_PATH
	for seed_value in [40741, 40743]:
		var expected := 241 if seed_value == 40741 else 243
		var phases := Facade.initial_gait_steps_v1(seed_value, "walking_prefix", "", Route.PREFIX_PROFILE)
		checks["declared_prefix_" + str(seed_value)] = phases.size() == 4 and phases.values().all(func(v): return v == expected)
	var second_preflight := Facade.portable_session_preflight_v1(sdk, 40743, true, Route.PREFIX_PROFILE)
	result["phase_243_runtime_preflight"] = second_preflight
	checks["actual_phase_243_preflight"] = second_preflight.get("ok") == true and second_preflight.initial_gait_steps.values().all(func(v): return v == 243)
	var refused_preflight := Facade.portable_session_preflight_v1(sdk, 40442, true, Route.PREFIX_PROFILE)
	result["unknown_seed_preflight_refusal"] = refused_preflight
	checks["unknown_seed_preflight_refuses"] = refused_preflight.get("ok") == false and refused_preflight.get("failure_code") == "R10O_PREFIX_PHASE_SELECTION_INVALID"
	checks["old_seed_modulo_preserved"] = Facade.initial_gait_steps_v1(40741, "walking_prefix").values().all(func(v): return v == 61)
	checks["prefix_profile_refusals"] = Facade.initial_gait_steps_v1(40442, "walking_prefix", "", Route.PREFIX_PROFILE).is_empty() and Facade.initial_gait_steps_v1(40741, "walking_resume", "", Route.PREFIX_PROFILE).is_empty() and Facade.initial_gait_steps_v1(40741, "walking_prefix", Route.START, Route.PREFIX_PROFILE).is_empty()
	for key in ["walking_entry_profile_id", "walking_start_profile_id", "walking_policy_id", "walking_policy_contract_sha256", "runtime_sha256"]:
		var changed: Dictionary = selection.diagnostic_schedule.duplicate(true)
		changed[key] = "crossed"
		checks["route_refuses_" + key] = not Profile.WalkingPolicy.schedule_valid_v1(changed)

func _check_native(sdk: Object, fixture: Dictionary, variant: Dictionary) -> void:
	var facade := Facade.new()
	var floor := Facade.RecoveryWorld.create_floor_v1()
	var model: String = "r10o-route-selection-" + variant.label
	facade._binding = {"floor": floor, "model_instance_id": model}
	var frame: Dictionary = fixture.state.task_frame
	var axes := {"lateral": Vector3(frame.lateral_axis_world_unit.x, frame.lateral_axis_world_unit.y, frame.lateral_axis_world_unit.z), "forward": Vector3(frame.forward_axis_world_unit.x, frame.forward_axis_world_unit.y, frame.forward_axis_world_unit.z), "legacy_yaw_rad": frame.reference_yaw_rad}
	var phases := Profile.WalkingStart.normal_initial_gait_steps_v1(Route.START)
	var material: Dictionary = Facade.MaterialProfiles.resolve(Facade.MATERIAL_PROFILE_ID).profile
	var started := facade._start_adapter_from_frame_v1(axes, Vector3.ZERO, phases, material, true, variant.id, variant.segment)
	checks[variant.label + "_actual_facade_start"] = started.get("ok") == true
	var retained := {"start": started}
	if started.get("ok") == true:
		checks[variant.label + "_native_identity"] = started.controller_policy_id == variant.native
		checks[variant.label + "_stationary_hold_selection"] = facade._adapter._development_stationary_hold == (variant.label == "hold")
		checks[variant.label + "_shutdown"] = facade._adapter.shutdown().get("ok") == true
	facade._adapter = null
	var floor_source := Facade.SdkAdapterScript.DevelopmentFloor.capture_v1(sdk, floor, "r10f-l13-zero-world-" + variant.segment) if variant.label != "ramp" else {}
	var ledger := Shared.Prior._walking_ledger_production_fixture_v2(sdk, 900, "walking_resume", variant.segment,
		Stance.PHASE if variant.label in ["ramp", "hold"] else "fresh_selected_policy_walking_resume" if variant.label == "resume" else "matched_no_kick_continuation",
		model, variant.id, true, floor_source, fixture if variant.label != "ramp" else {})
	checks[variant.label + "_production_motor_ledger"] = ledger.get("ok") == true
	retained["ledger"] = ledger
	result[variant.label] = retained
	floor.free()
