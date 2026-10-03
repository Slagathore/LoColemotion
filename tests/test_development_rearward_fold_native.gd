extends SceneTree
# gdlint: disable=max-line-length

## Actual compiled planning and production motor application on eight hinges
## outside any scene/world. Supplied observations are synthetic, not physics.
const Route := preload("res://sdk/adapters/godot/gdscript/recovery_native_route_v1.gd")
const Runtime := preload("res://sdk/adapters/godot/gdscript/recovery_runtime.gd")
const Json := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")
const BINDING := "res://sdk/development_rearward_fold_runtime_binding_v1.json"
const EXTENSION := "res://sdk/adapters/godot/development_rearward_fold_runtime/runtime.gdextension"
const OLD := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const EntryFixtures := preload("res://tests/test_development_passive_entry_worker_hooks.gd")
const EntryStage := preload("res://sdk/adapters/godot/gdscript/development_passive_entry_stage_v1.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var result := _evaluate()
	print("DEVELOPMENT_REARWARD_FOLD_NATIVE ", Json.stringify(result))
	quit(0 if result.get("ok") == true else 1)

func _evaluate() -> Dictionary:
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BINDING))
	for path in ["res://" + binding["local_build_path"], binding["runtime"]["path"]]:
		if "sha256:" + FileAccess.get_sha256(path) != binding["runtime"]["raw_sha256"]:
			return {"ok": false, "failure_code": "CANDIDATE_RUNTIME_DRIFT"}
	for source in binding["source_files"]:
		if "sha256:" + FileAccess.get_sha256("res://" + source["path"]) != source["raw_sha256"]:
			return {"ok": false, "failure_code": "CANDIDATE_SOURCE_DRIFT", "path": source["path"]}
	if GDExtensionManager.is_extension_loaded(OLD) and GDExtensionManager.unload_extension(OLD) != GDExtensionManager.LOAD_STATUS_OK:
		return {"ok": false, "failure_code": "OLD_RUNTIME_UNLOAD"}
	if GDExtensionManager.load_extension(EXTENSION) != GDExtensionManager.LOAD_STATUS_OK:
		return {"ok": false, "failure_code": "CANDIDATE_RUNTIME_LOAD"}
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		return {"ok": false, "failure_code": "FIXTURE_PATH"}
	var fixtures := []
	for line in FileAccess.get_file_as_string(args[0]).split("\n"):
		if line.begins_with("REARWARD_FOLD_CONTROL_FIXTURE "):
			fixtures.append(sdk.decode_exact_json_v1(line.trim_prefix("REARWARD_FOLD_CONTROL_FIXTURE ").strip_edges()))
	if fixtures.size() != 3:
		return {"ok": false, "failure_code": "FIXTURE_POPULATION"}
	var request: Dictionary = fixtures[0]["request"]
	var control := Runtime.plan_control_v1(sdk, request)
	var exact_response: Dictionary = sdk.decode_exact_json_v1(sdk.recovery_plan_control_v1_json(Json.stringify(request)))
	var old_request := request.duplicate(true)
	old_request["controller_id"] = Route.RECOVERY_CONTROLLER_V6_ID
	old_request["collection"]["observation"]["controller_ownership"]["recovery_controller_id"] = Route.RECOVERY_CONTROLLER_V6_ID
	var old_control := Runtime.plan_control_v1(sdk, old_request)
	var context := Route.prepare_complete_energy_context_v18(sdk, Route.RECOVERY_CONTROLLER_V6_ID)
	if context.get("ok") != true:
		return {"ok": false, "failure_code": "NATIVE_CONTEXT", "context": context}
	var surface := Route.zero_world_command_surface_v1(context)
	if surface.get("ok") != true:
		return {"ok": false, "failure_code": "UNINSERTED_HINGE_SURFACE", "surface": surface}
	var model := {"complete_energy_profile_selected": true,
		"solver_coupled_complete_energy_profile_selected": true,
		"discrete_staging_complete_energy_profile_selected": true,
		"joint_by_actuator_id": surface["joint_by_actuator_id"]}
	var positions: Dictionary = surface["position_by_joint_id"]
	var initial := _motors(surface)
	var old_refusal := Route.apply_behavior_control_route_aware_discrete_staging_v2(sdk, control, model, positions, true)
	var crossed_refusal := Route.apply_rearward_fold_control_v1(sdk, old_control, model, positions, true)
	var checks := {
		"actual_godot_json_matches_actual_dll_and_rust": Json.stringify(exact_response.get("value")) == Json.stringify(fixtures[0]["expected"]),
		# The old public wrapper intentionally uses Godot JSON's all-float
		# number projection. Check that separately; do not alter source bytes.
		"legacy_wrapper_matches_its_declared_numeric_projection": Json.stringify(control) == Json.stringify(JSON.parse_string(Json.stringify(fixtures[0]["expected"]))),
		"old_entrypoint_refuses_v7_before_writes": old_refusal.get("ok") == false and _motors(surface) == initial,
		"new_entrypoint_refuses_v6_before_writes": crossed_refusal.get("ok") == false and _motors(surface) == initial,
	}
	var applied := Route.apply_rearward_fold_control_v1(sdk, control, model, positions, true)
	checks["actual_v7_native_application"] = applied.get("ok") == true
	checks["v7_identity_retained"] = applied.get("portable_recovery_controller_id") == Route.RECOVERY_CONTROLLER_V7_ID and applied.get("recovery_controller_id") == Route.RECOVERY_CONTROLLER_V7_ID
	checks["eight_native_motors_no_direct_body_impulses"] = applied.get("motor_enabled_count") == 8 and applied.get("pre_solver_direct_body_impulse_write_count") == 0
	checks["unchanged_energy_partition_and_route"] = applied.get("energy_route_id") == Route.R148_COMPLETE_ENERGY_ROUTE_ID and applied.get("partition_rule_id") == Route.R144_PARTITION_RULE_ID
	var active_state := _motors(surface)
	checks["all_four_hips_request_rearward_motion"] = _direction_matches(applied, active_state, [0, 2, 4, 6], -8.0)
	checks["all_four_knees_request_positive_motion"] = _direction_matches(applied, active_state, [1, 3, 5, 7], 8.0)
	var altered := control.duplicate(true)
	altered["command_sha256"] = "sha256:" + "0".repeat(64)
	var invalid := Route.apply_rearward_fold_control_v1(sdk, altered, model, positions, true)
	checks["crossed_command_digest_refuses_before_writes"] = invalid.get("ok") == false and _motors(surface) == active_state
	var passive_request := request.duplicate(true)
	passive_request["collection"]["phase"] = "confirm_prone"
	var passive := Runtime.plan_control_v1(sdk, passive_request)
	var disabled := Route.apply_rearward_fold_control_v1(sdk, passive, model, positions, true)
	checks["compiled_confirmation_disables_all_motors"] = disabled.get("ok") == true and disabled.get("motor_enabled_count") == 0 and disabled.get("no_actuation_requested") == true
	checks["disabled_native_readback"] = _motors(surface).all(func(motor): return motor["enabled"] == false and motor["velocity"] == 0.0)
	var old_applied := Route.apply_behavior_control_route_aware_discrete_staging_v2(sdk, old_control, model, positions, true)
	checks["old_v6_application_still_works_and_keeps_identity"] = old_applied.get("ok") == true and old_applied.get("portable_recovery_controller_id") == Route.RECOVERY_CONTROLLER_V6_ID
	checks["old_v6_front_targets_unchanged"] = _direction_matches(old_applied, _motors(surface), [0, 2], 8.0) and _direction_matches(old_applied, _motors(surface), [1, 3], -8.0)
	Route.free_zero_world_command_surface_v1(surface)
	var candidate_context := Route.prepare_rearward_fold_context_v1(sdk)
	checks["candidate_context_exact_and_separate_from_old_context"] = Route.rearward_fold_context_binding_exact_v1(sdk, candidate_context) and not Route.contiguous_boundary_recovery_behavior_context_binding_exact_v1(sdk, candidate_context)
	checks["candidate_context_cannot_construct_world"] = candidate_context.get("physical_world_construction_authorized") == false and not Route._discrete_staging_live_context_binding_exact_v1(sdk, candidate_context)
	var context_refusals := 0
	for key in ["recovery_controller_id", "capability_sha256", "source_native_context_sha256", "portable_controller_changed", "physical_acceptance_authority", "release_authority"]:
		var crossed := candidate_context.duplicate(true)
		crossed[key] = "crossed"
		if not Route.rearward_fold_context_binding_exact_v1(sdk, crossed) and Route.advance_rearward_fold_control_v1(sdk, crossed, {}, {}, {}).get("ok") == false:
			context_refusals += 1
	checks["six_crossed_contexts_refuse_before_collection"] = context_refusals == 6
	var continuation := _supplied_observation_continuation(sdk, candidate_context)
	checks["actual_compiled_confirmation_reaches_v7_support_command"] = continuation.get("ok") == true
	return {"ok": checks.values().all(func(value): return value == true), "checks": checks,
		"candidate_application": applied, "disabled_application": disabled,
		"synthetic_canonical_continuation": continuation,
		"old_application": old_applied, "runtime": binding["runtime"],
		"synthetic_native_shaped_observations_only": true, "uninserted_hinge_count": 8,
		"world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}

func _motors(surface: Dictionary) -> Array:
	var result := []
	for joint in surface["ordered_joints"]:
		result.append({"enabled": joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR),
			"velocity": joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY),
			"cap": joint.get_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE)})
	return result

func _direction_matches(application: Dictionary, motors: Array, indexes: Array, canonical_speed: float) -> bool:
	if not (application.get("ordered_intents") is Array) or application["ordered_intents"].size() != 8:
		return false
	for index in indexes:
		var intent: Dictionary = application["ordered_intents"][index]
		# These exact saturated test commands require no rounding. Godot's
		# existing joint-coordinate projection is -1, not a new controller rule.
		if (intent.get("canonical_target_velocity_rad_s") != canonical_speed
			or intent.get("host_velocity_sign") != -1.0
			or intent.get("godot_projected_target_velocity_rad_s") != -canonical_speed
			or motors[index]["velocity"] != -canonical_speed or not motors[index]["enabled"]):
			return false
	return true

func _supplied_observation_continuation(sdk: Object, context: Dictionary) -> Dictionary:
	var fixtures := EntryFixtures.new()
	var result := _continue_with_supplied_observations(sdk, context, fixtures)
	fixtures.free()
	return result

func _continue_with_supplied_observations(sdk: Object, context: Dictionary, fixtures: SceneTree) -> Dictionary:
	var fixture: Dictionary = fixtures._initial_entry_fixture(sdk, context)
	if fixture.get("ok") != true:
		return {"ok": false, "failure_code": "INITIAL_ENTRY_FIXTURE", "detail": fixture}
	var memory := {}
	var last_advance := {}
	var threshold_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/recovery/r24d17_native_recovery_runtime_and_physical_profile_contract_v1.json"))
	var confirm_steps := 0
	for threshold in threshold_contract["threshold_profile"]["thresholds"]:
		if threshold["threshold_id"] == "entry_prone_confirm_steps":
			confirm_steps = int(threshold["value"])
	if confirm_steps != 12:
		return {"ok": false, "failure_code": "UNCHANGED_CONFIRMATION_THRESHOLD"}
	var advance_calls := 0
	for step in range(273, 273 + confirm_steps):
		# These are explicitly synthetic source applications, not worker output
		# or altered historical receipts. Real composers bind them to supplied
		# zero-impulse observations before compiled collection and stepping.
		var application := {"schema_version": "sporespore_synthetic_rearward_fold_application_v1",
			"synthetic_test_fixture": true, "ok": true, "semantic_step": step,
			"phase": "controller_free_descent_to_measured_prone" if step == 273 else "confirm_prone",
			"controller_owner": "none" if step == 273 else "recovery",
			"recovery_controller_id": null if step == 273 else Route.RECOVERY_CONTROLLER_V7_ID,
			"stance_controller_id": null, "handoff_event_count": 0, "fallback_controller_active": false,
			"command_id": "synthetic_rearward_fold_%d" % step,
			"command_sha256": Runtime.canonicalize(sdk, {"synthetic_empty_command_at_step": step})["sha256"],
			"zero_command": false, "no_actuation_requested": true}
		var projected: Dictionary = fixtures._project(sdk, context, fixture, application, step, true)
		if projected.get("ok") != true:
			return {"ok": false, "failure_code": "SOURCE_PROJECTION", "step": step, "detail": projected}
		var bound: Dictionary = projected["epoch"]["bound_epoch_observations"]
		if step == 273:
			var entered := EntryStage.advance_v1(sdk, context, EntryFixtures.Sources.Prior.ATTEMPT_ID, 240, bound)
			if entered.get("ok") != true or not (entered.get("entry_receipt", {}).get("canonical_memory") is Dictionary):
				return {"ok": false, "failure_code": "COMPILED_ENTRY", "detail": entered}
			memory = entered["entry_receipt"]["canonical_memory"]
		else:
			last_advance = Route.advance_rearward_fold_control_v1(sdk, context, bound, memory, application)
			advance_calls += 1
			if last_advance.get("ok") != true:
				return {"ok": false, "failure_code": "COMPILED_ADVANCE", "step": step, "detail": last_advance}
			memory = last_advance["next_memory"]
		fixture = projected["fixture_after"]
	var control: Dictionary = last_advance.get("control_receipt", {})
	var targets := []
	for command in control.get("ordered_commands", []):
		targets.append(command["target_position_rad"])
	return {"ok": memory.get("phase") == "establish_distal_support" and memory.get("prone_confirm_steps_observed") == confirm_steps and control.get("controller_id") == Route.RECOVERY_CONTROLLER_V7_ID and targets == [-0.6, 1.05, -0.6, 1.05, -0.6, 1.05, -0.6, 1.05],
		"entry_call_count": 1, "canonical_advance_call_count": advance_calls,
		"unchanged_required_prone_samples": confirm_steps,
		"final_memory": memory, "final_control": control,
		"last_collection_transport": last_advance.get("collection_transport_retention", {}),
		"worker_or_scheduler_exercised": false,
		"synthetic_observations_and_application_sources_only": true,
		"world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
