extends "res://tests/test_development_rearward_fold_native.gd"
# gdlint: disable=max-line-length

## Reuse only the uninserted-hinge test helpers, not V7 results or runtime.
func _run() -> void:
	var result := _evaluate()
	print("DEVELOPMENT_RATE_LIMITED_RECOVERY_NATIVE ", Json.stringify(result))
	quit(0 if result.get("ok") == true else 1)


func _evaluate() -> Dictionary:
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://sdk/development_rate_limited_recovery_runtime_binding_v1.json"))
	for path in ["res://" + binding["local_build_path"], binding["runtime"]["path"]]:
		if "sha256:" + FileAccess.get_sha256(path) != binding["runtime"]["raw_sha256"]:
			return {"ok": false, "failure_code": "V8_RUNTIME_DRIFT"}
	for source in binding["source_files"]:
		if "sha256:" + FileAccess.get_sha256("res://" + source["path"]) != source["raw_sha256"]:
			return {"ok": false, "failure_code": "V8_SOURCE_DRIFT", "path": source["path"]}
	var fixture_path: String = binding["compiled_fixtures"]["path"]
	if "sha256:" + FileAccess.get_sha256(fixture_path) != binding["compiled_fixtures"]["raw_sha256"]:
		return {"ok": false, "failure_code": "V8_FIXTURE_DRIFT"}
	if GDExtensionManager.is_extension_loaded(OLD) and GDExtensionManager.unload_extension(OLD) != GDExtensionManager.LOAD_STATUS_OK:
		return {"ok": false, "failure_code": "OLD_RUNTIME_UNLOAD"}
	if GDExtensionManager.load_extension("res://sdk/adapters/godot/development_rate_limited_recovery_runtime/runtime.gdextension") != GDExtensionManager.LOAD_STATUS_OK:
		return {"ok": false, "failure_code": "V8_RUNTIME_LOAD"}
	var sdk: Object = ClassDB.instantiate("SporeLocomotionSdk")
	var fixtures := []
	for line in FileAccess.get_file_as_string(fixture_path).split("\n"):
		if line.begins_with("RATE_LIMITED_RECOVERY_CONTROL_FIXTURE "):
			fixtures.append(sdk.decode_exact_json_v1(line.trim_prefix("RATE_LIMITED_RECOVERY_CONTROL_FIXTURE ").strip_edges()))
	if fixtures.size() != 6:
		return {"ok": false, "failure_code": "V8_FIXTURE_POPULATION"}
	var context := Route.prepare_complete_energy_context_v18(sdk, Route.RECOVERY_CONTROLLER_V6_ID)
	if context.get("ok") != true:
		return {"ok": false, "failure_code": "NATIVE_CONTEXT", "detail": context}
	var surface := Route.zero_world_command_surface_v1(context)
	if surface.get("ok") != true:
		return {"ok": false, "failure_code": "UNINSERTED_SURFACE", "detail": surface}
	var model := {"complete_energy_profile_selected": true,
		"solver_coupled_complete_energy_profile_selected": true,
		"discrete_staging_complete_energy_profile_selected": true,
		"joint_by_actuator_id": surface["joint_by_actuator_id"]}
	var positions: Dictionary = surface["position_by_joint_id"]
	var checks := {}
	var applications := []
	for index in range(fixtures.size()):
		var request: Dictionary = fixtures[index]["request"]
		var exact: Dictionary = sdk.decode_exact_json_v1(sdk.recovery_plan_control_v1_json(Json.stringify(request)))
		checks["compiled_plan_matches_rust_%d" % index] = Json.stringify(exact.get("value")) == Json.stringify(fixtures[index]["expected"])
		if index >= 2:
			continue # Remaining native-shaped inputs are portability checks, not other-engine physics.
		var control := Runtime.plan_control_v1(sdk, request)
		var before := _motors(surface)
		var v6_refusal := Route.apply_behavior_control_route_aware_discrete_staging_v2(sdk, control, model, positions, true)
		var v7_refusal := Route.apply_rearward_fold_control_v1(sdk, control, model, positions, true)
		checks["old_entrypoints_refuse_v8_without_writes_%d" % index] = v6_refusal.get("ok") == false and v7_refusal.get("ok") == false and _motors(surface) == before
		var applied := Route.apply_rate_limited_recovery_control_v1(sdk, control, model, positions, true)
		applications.append(applied)
		checks["actual_v8_native_identity_%d" % index] = applied.get("ok") == true and applied.get("portable_recovery_controller_id") == Route.RECOVERY_CONTROLLER_V8_ID
		checks["native_target_speed_four_in_both_phases_%d" % index] = _direction_matches(applied, _motors(surface), [0, 2, 4, 6], -4.0) and _direction_matches(applied, _motors(surface), [1, 3, 5, 7], 4.0)
		checks["native_route_and_impulse_partition_unchanged_%d" % index] = applied.get("pre_solver_direct_body_impulse_write_count") == 0 and applied.get("partition_rule_id") == Route.R144_PARTITION_RULE_ID and applied.get("energy_route_id") == Route.R148_COMPLETE_ENERGY_ROUTE_ID
		var active := _motors(surface)
		var crossed := control.duplicate(true)
		crossed["command_sha256"] = "sha256:" + "0".repeat(64)
		checks["forged_digest_refuses_without_writes_%d" % index] = Route.apply_rate_limited_recovery_control_v1(sdk, crossed, model, positions, true).get("ok") == false and _motors(surface) == active
		for owner in [Route.RECOVERY_CONTROLLER_V6_ID, Route.RECOVERY_CONTROLLER_V7_ID]:
			var old_request := request.duplicate(true)
			old_request["controller_id"] = owner
			old_request["collection"]["observation"]["controller_ownership"]["recovery_controller_id"] = owner
			var old_control := Runtime.plan_control_v1(sdk, old_request)
			checks["v8_refuses_old_controller_%s_%d" % [owner, index]] = Route.apply_rate_limited_recovery_control_v1(sdk, old_control, model, positions, true).get("ok") == false and _motors(surface) == active
			var old_applied := Route.apply_behavior_control_route_aware_discrete_staging_v2(sdk, old_control, model, positions, true, owner)
			checks["old_native_controller_still_works_%s_%d" % [owner, index]] = old_applied.get("ok") == true and old_applied.get("portable_recovery_controller_id") == owner
			active = _motors(surface)
	var passive_request: Dictionary = fixtures[0]["request"].duplicate(true)
	passive_request["collection"]["phase"] = "confirm_prone"
	var disabled := Route.apply_rate_limited_recovery_control_v1(sdk, Runtime.plan_control_v1(sdk, passive_request), model, positions, true)
	checks["compiled_confirmation_disables_native_motors"] = disabled.get("ok") == true and disabled.get("no_actuation_requested") == true and _motors(surface).all(func(motor): return motor["enabled"] == false and motor["velocity"] == 0.0)
	Route.free_zero_world_command_surface_v1(surface)
	var candidate_context := Route.prepare_rate_limited_recovery_context_v1(sdk)
	checks["v8_context_retains_exact_ancestry_and_refuses_v7_entry"] = Route.rate_limited_recovery_context_binding_exact_v1(sdk, candidate_context) and not Route.rearward_fold_context_binding_exact_v1(sdk, candidate_context)
	checks["v8_context_cannot_construct_world"] = candidate_context.get("physical_world_construction_authorized") == false and not Route._discrete_staging_live_context_binding_exact_v1(sdk, candidate_context)
	var refused := 0
	for key in ["recovery_controller_id", "source_native_context_sha256", "capability_sha256", "portable_controller_changed", "physical_acceptance_authority", "release_authority"]:
		var crossed := candidate_context.duplicate(true)
		crossed[key] = "crossed"
		if not Route.rate_limited_recovery_context_binding_exact_v1(sdk, crossed) and Route.advance_rate_limited_recovery_control_v1(sdk, crossed, {}, {}, {}).get("ok") == false:
			refused += 1
	checks["six_crossed_contexts_refuse_before_collection"] = refused == 6
	return {"ok": checks.values().all(func(value): return value == true), "checks": checks,
		"applications": applications, "runtime": binding["runtime"], "synthetic_observations_only": true,
		"uninserted_hinge_count": 8, "world_build_count": 0, "solver_step_count": 0,
		"physical_acceptance_authority": false, "release_authority": false}
